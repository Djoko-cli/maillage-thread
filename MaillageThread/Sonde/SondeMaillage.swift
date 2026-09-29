import Foundation
import MaillageCoeur
import Observation

/// La sonde vue par l'app : port retenu (par son numero de serie USB),
/// connexion, tournee toutes les 5 minutes, dernier maillage. L'app n'ouvre
/// jamais un port qu'on ne lui a pas designe (spec de la sonde, section 3).
@MainActor
@Observable
final class SondeMaillage {
    enum Etat: Equatable {
        /// Aucune sonde choisie dans les Reglages.
        case sansSonde
        /// La sonde retenue n'est pas branchee.
        case absente
        case connexion
        case connectee(Bonjour)
        /// Le port choisi n'est pas une sonde, ou ne repond pas.
        case refusee(String)
        case erreur(String)
    }

    /// Numero de serie USB de la sonde retenue (l'adresse MAC du C6).
    static let cleSerie = "sondeSerieUSB"
    /// Nom de la sonde retenue, donne par la carte (`bonjour`).
    static let cleNom = "sondeNom"
    static let periode: Duration = .seconds(300)

    private(set) var etat: Etat = .sansSonde
    /// Ports Espressif branches (la sonde, ou un autre C6 comme le pont Halo).
    private(set) var ports: [PortUSB] = []
    private(set) var serie: String?
    /// Nom de la sonde (« SONDE-01 »), mis a jour a chaque `bonjour` ; nil si le firmware
    /// n'en donne pas (1.0.0) ou sans sonde retenue.
    private(set) var nom: String?
    private(set) var etatSonde: EtatSonde?
    /// Reception du dernier maillage (fin de sa tournee).
    private(set) var derniereTournee: Date?
    private(set) var tourneeEnCours = false
    /// Avancement de la tournee en cours ; nil hors tournee.
    private(set) var avancement: AvancementTournee?
    /// Debut de la tournee en cours ; nil hors tournee.
    private(set) var debutTournee: Date?
    /// Derniere erreur d'une tournee (la liaison reste ouverte).
    private(set) var erreurTournee: String?
    /// Appele a chaque nouveau maillage, avec l'heure de sa reception (fin de la
    /// tournee) : la fraicheur affichee se compte depuis.
    @ObservationIgnored var surMaillage: ((Maillage, Date) -> Void)?
    /// Appele au debut (vrai) et a la fin (faux) de chaque tournee : pendant une
    /// tournee, le maillage affiche n'est pas « ancien ».
    @ObservationIgnored var surTournee: ((Bool) -> Void)?

    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let actif: Bool
    @ObservationIgnored private let ouvrirCanal: (String) -> any CanalSonde
    /// Heure du debut de la tournee et de la reception du maillage (injectee par les tests).
    @ObservationIgnored private let horloge: () -> Date
    @ObservationIgnored private var sonde: SondeUSB?
    /// Chemin du port de `sonde` (nil sans sonde connectee).
    @ObservationIgnored private var cheminConnecte: String?
    /// Liaison d'une connexion en cours, avant sa verification : `deconnecter`
    /// la ferme aussi.
    @ObservationIgnored private var enConnexion: SondeUSB?
    /// Numero d'essai, incremente par `deconnecter` : une connexion dont le
    /// numero a change est perimee et ne touche plus a rien.
    @ObservationIgnored private var essai = 0
    /// Fermetures lancees par `deconnecter`, chainees : une connexion attend
    /// qu'elles soient finies (ports vraiment fermes) avant d'ouvrir un port.
    @ObservationIgnored private var fermetures: Task<Void, Never>?
    @ObservationIgnored private var memoire = MemoireTournee()
    /// Boucle des tournees (lue par les tests).
    @ObservationIgnored private(set) var boucle: Task<Void, Never>?
    @ObservationIgnored private var surveillantPorts: PortsUSB?

    /// `actif` faux (mode demo, tests) : ni port, ni preferences lues.
    init(preferences: UserDefaults = .standard, actif: Bool,
         ouvrirCanal: @escaping (String) -> any CanalSonde = { CanalSerie(liaison: LiaisonSerie(chemin: $0)) },
         horloge: @escaping () -> Date = { Date() }) {
        self.preferences = preferences
        self.actif = actif
        self.ouvrirCanal = ouvrirCanal
        self.horloge = horloge
        serie = actif ? preferences.string(forKey: Self.cleSerie) : nil
        nom = actif ? preferences.string(forKey: Self.cleNom) : nil
    }

    /// Nom montre pour la sonde : le sien, sinon « Sonde ».
    static func nomAffiche(_ nom: String?) -> String {
        nom ?? String(localized: "Sonde")
    }

    /// Suit les ports ; reprend la sonde retenue des qu'elle est branchee.
    func demarrer() {
        guard actif, surveillantPorts == nil else { return }
        let p = PortsUSB()
        p.changement = { [weak self] l in self?.portsChanges(l) }
        p.demarrer()
        surveillantPorts = p
        portsChanges(PortsUSB.lister())
    }

    /// Choix d'un port dans les Reglages : retenu seulement s'il repond en sonde.
    /// Le port de la sonde deja connectee n'est pas rouvert.
    func choisir(_ port: PortUSB) {
        guard actif, port.chemin != cheminConnecte else { return }
        lancerConnexion(port, choisi: true)
    }

    /// Oublie la sonde retenue (numero de serie et nom) et ferme la liaison.
    func oublier() {
        preferences.removeObject(forKey: Self.cleSerie)
        serie = nil
        retenirNom(nil)
        deconnecter(.sansSonde)
    }

    /// Nom donne par le dernier `bonjour` : retenu a cote du numero de serie, efface si le
    /// firmware n'en donne pas.
    private func retenirNom(_ n: String?) {
        if let n {
            preferences.set(n, forKey: Self.cleNom)
        } else {
            preferences.removeObject(forKey: Self.cleNom)
        }
        nom = n
    }

    /// Tournee tout de suite (bouton rafraichir) ; rien pendant une tournee : relancer la
    /// boucle ne ferait que repousser la suivante de 5 min apres ce clic.
    func rafraichir() {
        guard sonde != nil, !tourneeEnCours else { return }
        lancerBoucle()
    }

    /// Ports branches : la sonde retenue revient, ou s'en va.
    func portsChanges(_ liste: [PortUSB]) {
        ports = liste.filter(\.estEspressif)
        guard let serie else { return }
        if let p = ports.first(where: { $0.serie == serie }) {
            // `lancerConnexion` passe tout de suite a `.connexion` : un second appel n'en lance pas d'autre.
            if sonde == nil && etat != .connexion { lancerConnexion(p, choisi: false) }
        } else if sonde != nil || etat != .absente {
            deconnecter(.absente)
        }
    }

    /// Connexion au port : ferme la liaison en place et attend qu'elle le soit
    /// vraiment, ouvre le port, le garde s'il repond en sonde. Perimee par un
    /// `deconnecter` pendant une attente, elle ferme sa liaison (en l'attendant)
    /// et sort sans toucher a l'etat, a la sonde, ni au numero de serie retenu.
    func connecter(_ port: PortUSB, choisi: Bool) async {
        deconnecter(.connexion)
        let n = essai
        // Tant que l'ancienne liaison tient le port, TIOCEXCL refuse de le rouvrir.
        await fermetures?.value
        guard n == essai else { return }
        let s = SondeUSB(canal: ouvrirCanal(port.chemin))
        enConnexion = s
        do {
            try await s.demarrer { [weak self] in
                Task { @MainActor in self?.liaisonFermee(s) }
            }
            guard n == essai else {
                await s.fermer()
                return
            }
            let b = try await s.bonjour()
            guard n == essai else {
                await s.fermer()
                return
            }
            guard b.estSonde else {
                await s.fermer()
                guard n == essai else { return }
                enConnexion = nil
                etat = .refusee(String(localized: "\(port.libelle) n'est pas une sonde (« \(b.produit) »)"))
                return
            }
            enConnexion = nil
            sonde = s
            cheminConnecte = port.chemin
            etat = .connectee(b)
            if choisi, let serieUSB = port.serie {
                preferences.set(serieUSB, forKey: Self.cleSerie)
                serie = serieUSB
            }
            // Le nom va avec la sonde retenue (un port sans numero de serie ne l'est pas).
            retenirNom(port.serie != nil && port.serie == serie ? b.nom : nil)
            lancerBoucle()
        } catch {
            await s.fermer()
            guard n == essai else { return }
            enConnexion = nil
            etat = choisi ? .refusee(error.localizedDescription) : .erreur(error.localizedDescription)
        }
    }

    /// Connexion lancee sans l'attendre (Reglages, ports) : la liaison en place
    /// est fermee et `etat` passe a `.connexion` tout de suite ; un `deconnecter`
    /// d'ici au depart de la tache (oublier, autre choix, port retire) l'annule.
    private func lancerConnexion(_ port: PortUSB, choisi: Bool) {
        deconnecter(.connexion)
        let n = essai
        Task {
            guard n == essai else { return }
            await connecter(port, choisi: choisi)
        }
    }

    private func liaisonFermee(_ s: SondeUSB) {
        guard sonde === s else { return }
        deconnecter(.absente)
    }

    /// Ferme sans attendre la liaison connectee et celle d'une connexion en
    /// cours, qui devient perimee ; `connecter` attend ces fermetures.
    private func deconnecter(_ nouveau: Etat) {
        essai += 1
        boucle?.cancel()
        boucle = nil
        for s in [sonde, enConnexion].compactMap({ $0 }) {
            let precedentes = fermetures
            fermetures = Task {
                await s.fermer()
                await precedentes?.value
            }
        }
        sonde = nil
        enConnexion = nil
        cheminConnecte = nil
        etat = nouveau
    }

    private func lancerBoucle() {
        boucle?.cancel()
        boucle = Task { [weak self] in
            while !Task.isCancelled {
                await self?.uneTournee()
                try? await Task.sleep(for: Self.periode)
            }
        }
    }

    /// Etat de la sonde, puis une tournee ; le maillage part a la surveillance,
    /// avec l'heure de sa reception (la fin de la tournee), entre les signaux de
    /// debut et de fin de la tournee. L'avancement et l'heure du debut sont exposes
    /// pendant la tournee, remis a nil a sa fin (erreur et liaison fermee comprises).
    func uneTournee() async {
        guard let sonde, !tourneeEnCours else { return }
        tourneeEnCours = true
        debutTournee = horloge()
        surTournee?(true)
        // L'avancement vient de la tache de la tournee : il passe sur le MainActor dans
        // l'ordre, et tout est lu avant la remise a nil.
        let (flux, suite) = AsyncStream.makeStream(of: AvancementTournee.self)
        let lecture = Task { @MainActor [weak self] in
            for await a in flux { self?.avancement = a }
        }
        await executerTournee(sonde) { suite.yield($0) }
        suite.finish()
        await lecture.value
        avancement = nil
        debutTournee = nil
        tourneeEnCours = false
        surTournee?(false)
    }

    /// Corps de `uneTournee` : ses erreurs sont retenues ici, sauf la liaison fermee (`liaisonFermee`).
    private func executerTournee(_ sonde: SondeUSB, suivi: @escaping @Sendable (AvancementTournee) -> Void) async {
        do {
            etatSonde = try await sonde.etat()
            if let r = try await Tournee.executer(sonde, memoire: memoire, maintenant: horloge(), avancement: suivi) {
                memoire = r.memoire
                let recu = horloge()
                derniereTournee = recu
                surMaillage?(r.maillage, recu)
            }
            erreurTournee = nil
        } catch SondeUSB.Erreur.fermee {
            // La liaison est fermee : `liaisonFermee` s'en occupe.
        } catch {
            erreurTournee = error.localizedDescription
        }
    }
}
