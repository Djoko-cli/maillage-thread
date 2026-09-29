import Foundation
import MaillageCoeur
import Observation

/// La sonde vue par l'app : port retenu (par son numero de serie USB),
/// connexion, tournee toutes les 5 minutes, dernier maillage. L'app n'ouvre
/// jamais un port qu'on ne lui a pas designe (spec de la sonde, section 3).
/// Liaison par l'USB, ou par le reseau Thread (contrat 1.0.2, comme le pont Halo) :
/// la cle se cree par l'USB et reste dans le trousseau ; par le reseau, la sonde
/// peut etre debranchee du Mac et alimentee ailleurs.
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

    /// Liaison avec la sonde retenue : son port USB, ou le reseau Thread.
    enum Liaison: String, Sendable {
        case usb
        case reseau
    }

    /// Numero de serie USB de la sonde retenue (l'adresse MAC du C6).
    static let cleSerie = "sondeSerieUSB"
    /// Nom de la sonde retenue, donne par la carte (`bonjour`).
    static let cleNom = "sondeNom"
    /// Nom d'hote SRP de la sonde retenue (sans `.local`), donne par la carte (`bonjour`, `cle`).
    static let cleHote = "sondeHote"
    /// Liaison choisie dans les Reglages (USB si absente).
    static let cleLiaison = "sondeLiaison"
    static let periode: Duration = .seconds(300)
    /// Reprises de la liaison reseau apres un echec : 1, 2, 5, 10 s, puis toutes les 30 s.
    static let delaisReprise: [Duration] = [.seconds(1), .seconds(2), .seconds(5), .seconds(10), .seconds(30)]

    private(set) var etat: Etat = .sansSonde
    /// Ports Espressif branches (la sonde, ou un autre C6 comme le pont Halo).
    private(set) var ports: [PortUSB] = []
    private(set) var serie: String?
    /// Nom de la sonde (« SONDE-01 »), mis a jour a chaque `bonjour` ; nil si le firmware
    /// n'en donne pas (1.0.0) ou sans sonde retenue.
    private(set) var nom: String?
    /// Numero de serie USB du port que l'etat concerne (connexion, connexion etablie, refus,
    /// erreur) ; nil sans sonde ou la sonde retenue absente.
    private(set) var serieEtat: String?
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
    private(set) var liaison: Liaison = .usb
    /// Nom d'hote SRP de la sonde retenue (sans `.local`) : l'acces reseau vise `<hote>.local`.
    private(set) var hote: String?
    /// Empreinte de la cle de ce Mac pour la sonde retenue (trousseau) ; nil sans cle.
    private(set) var empreinteAcces: String?
    /// « Autoriser l'accès réseau » en cours (cle demandee par l'USB).
    private(set) var autorisationEnCours = false
    /// Echec de la derniere autorisation ; nil apres une autorisation reussie.
    private(set) var erreurAutorisation: String?
    /// Appele a chaque nouveau maillage, avec l'heure de sa reception (fin de la
    /// tournee) : la fraicheur affichee se compte depuis.
    @ObservationIgnored var surMaillage: ((Maillage, Date) -> Void)?
    /// Appele au debut (vrai) et a la fin (faux) de chaque tournee : pendant une
    /// tournee, le maillage affiche n'est pas « ancien ».
    @ObservationIgnored var surTournee: ((Bool) -> Void)?

    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let actif: Bool
    @ObservationIgnored private let ouvrirCanal: (String) -> any CanalSonde
    /// Cles de l'acces reseau : en memoire par defaut, celui du Mac au lancement de l'app.
    @ObservationIgnored private let trousseau: any TrousseauCles
    /// Session reseau vers `<hote>.local` avec la cle : le canal pret, ou l'erreur.
    @ObservationIgnored private let ouvrirReseau: @MainActor (String, Data) async throws -> any CanalSonde
    @ObservationIgnored private let delaisReprise: [Duration]
    /// Echecs de la liaison reseau depuis la derniere connexion reussie.
    @ObservationIgnored private var essaisReprise = 0
    @ObservationIgnored private var reprise: Task<Void, Never>?
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

    /// `actif` faux (mode demo, tests) : ni port, ni preferences lues, ni trousseau.
    /// `trousseau` : en memoire par defaut (tests) ; l'app lui passe celui du Mac.
    init(preferences: UserDefaults = .standard, actif: Bool,
         ouvrirCanal: @escaping (String) -> any CanalSonde = { CanalSerie(liaison: LiaisonSerie(chemin: $0)) },
         trousseau: any TrousseauCles = TrousseauMemoire(),
         ouvrirReseau: @escaping @MainActor (String, Data) async throws -> any CanalSonde
             = { try await CanalReseau.connecter(hote: $0, cle: $1) },
         delaisReprise: [Duration] = SondeMaillage.delaisReprise,
         horloge: @escaping () -> Date = { Date() }) {
        self.preferences = preferences
        self.actif = actif
        self.ouvrirCanal = ouvrirCanal
        self.trousseau = trousseau
        self.ouvrirReseau = ouvrirReseau
        self.delaisReprise = delaisReprise
        self.horloge = horloge
        serie = actif ? preferences.string(forKey: Self.cleSerie) : nil
        nom = actif ? preferences.string(forKey: Self.cleNom) : nil
        guard actif else { return }
        liaison = preferences.string(forKey: Self.cleLiaison).flatMap(Liaison.init(rawValue:)) ?? .usb
        hote = preferences.string(forKey: Self.cleHote)
        empreinteAcces = hote.flatMap(empreinte(pour:))
    }

    /// Le reseau se choisit : nom d'hote connu, et cle de ce Mac pour lui.
    var reseauDisponible: Bool { hote != nil && empreinteAcces != nil }

    /// « Autoriser l'accès réseau » possible : la sonde retenue connectee par son port USB.
    var peutAutoriser: Bool {
        guard liaison == .usb, !autorisationEnCours, case .connectee = etat else { return false }
        return serie != nil && serieEtat == serie
    }

    /// Nom de la sonde retenue pour l'etat qui la concerne : absente, ou connexion, connexion
    /// etablie, refus ou erreur de son port ; nil pour un autre port choisi, ou sans sonde.
    var nomEtat: String? {
        switch etat {
        case .sansSonde: nil
        case .absente: nom
        case .connexion, .connectee, .refusee, .erreur: serie != nil && serieEtat == serie ? nom : nil
        }
    }

    /// `rafraichir` lancerait une tournee : sonde connectee, pas de tournee en cours.
    var tourneeAuRafraichir: Bool {
        if case .connectee = etat { !tourneeEnCours } else { false }
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
        if liaison == .reseau { lancerConnexionReseau() }
    }

    /// Choix d'un port dans les Reglages : retenu seulement s'il repond en sonde.
    /// Le port de la sonde deja connectee n'est pas rouvert.
    func choisir(_ port: PortUSB) {
        guard actif, liaison == .usb, port.chemin != cheminConnecte else { return }
        lancerConnexion(port, choisi: true)
    }

    /// Liaison choisie dans les Reglages. Le reseau exige une cle de ce Mac pour la sonde
    /// retenue : la liaison USB est fermee (le port libere), la session reseau ouverte. L'USB
    /// ferme la session reseau et reprend la sonde retenue si elle est branchee.
    func choisirLiaison(_ l: Liaison) {
        guard actif, l != liaison, l == .usb || reseauDisponible else { return }
        liaison = l
        preferences.set(l.rawValue, forKey: Self.cleLiaison)
        reprise?.cancel()
        essaisReprise = 0
        switch l {
        case .reseau:
            lancerConnexionReseau()
        case .usb:
            deconnecter(serie == nil ? .sansSonde : .absente)
            portsChanges(ports)
        }
    }

    /// Oublie la sonde retenue (numero de serie, nom, nom d'hote, cle de ce Mac pour elle :
    /// la sonde garde la sienne) et ferme la liaison ; retour a l'USB.
    func oublier() {
        preferences.removeObject(forKey: Self.cleSerie)
        serie = nil
        retenirNom(nil)
        if let hote { try? trousseau.oublier(nom: hote) }
        retenirHote(nil)
        liaison = .usb
        preferences.removeObject(forKey: Self.cleLiaison)
        erreurAutorisation = nil
        reprise?.cancel()
        deconnecter(.sansSonde)
    }

    /// Nom d'hote de la sonde retenue, garde a cote de son numero de serie ; l'empreinte de la
    /// cle de ce Mac pour lui est relue du trousseau.
    private func retenirHote(_ h: String?) {
        if let h {
            preferences.set(h, forKey: Self.cleHote)
        } else {
            preferences.removeObject(forKey: Self.cleHote)
        }
        hote = h
        empreinteAcces = h.flatMap(empreinte(pour:))
    }

    private func empreinte(pour nom: String) -> String? {
        trousseau.lister().first { $0.nom == nom }?.empreinte
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
        guard tourneeAuRafraichir else { return }
        lancerBoucle()
    }

    /// Ports branches : la sonde retenue revient, ou s'en va.
    /// Par le reseau, la sonde n'est jamais ouverte en USB, meme branchee.
    func portsChanges(_ liste: [PortUSB]) {
        ports = liste.filter(\.estEspressif)
        guard liaison == .usb, let serie else { return }
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
        deconnecter(.connexion, port: port)
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
                let autre = serieUSB != serie
                preferences.set(serieUSB, forKey: Self.cleSerie)
                serie = serieUSB
                // Le nom d'hote retenu etait celui d'une autre sonde.
                if autre { retenirHote(nil) }
            }
            // Le nom va avec la sonde retenue (un port sans numero de serie ne l'est pas).
            let retenue = port.serie != nil && port.serie == serie
            retenirNom(retenue ? b.nom : nil)
            // Son nom d'hote aussi, s'il est connu (nil tant que Matter ne l'a pas enregistre).
            if retenue, let h = b.hote, h != hote { retenirHote(h) }
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
        deconnecter(.connexion, port: port)
        let n = essai
        Task {
            guard n == essai else { return }
            await connecter(port, choisi: choisi)
        }
    }

    private func liaisonFermee(_ s: SondeUSB) {
        guard sonde === s else { return }
        guard liaison == .reseau else {
            deconnecter(.absente)
            return
        }
        // Veille sans reponse (sonde debranchee, redemarree), session perdue : reconnexion.
        deconnecter(.erreur(String(localized: "liaison réseau perdue")))
        serieEtat = serie
        planifierReprise()
    }

    // MARK: - Reseau

    /// Connexion par le reseau lancee sans l'attendre (Reglages, lancement) : la liaison en
    /// place est fermee et `etat` passe a `.connexion` tout de suite.
    private func lancerConnexionReseau() {
        deconnecter(.connexion)
        serieEtat = serie
        let n = essai
        Task {
            guard n == essai else { return }
            await connecterReseau()
        }
    }

    /// Connexion a la sonde retenue par le reseau Thread : cle du trousseau, session vers
    /// `<hote>.local:5480` (poignee de main H1), `bonjour`, puis tournees. Un echec est montre et
    /// la connexion reprise seule (1, 2, 5, 10 s, puis toutes les 30 s), sauf sans cle (il faut
    /// l'USB). Perimee par un `deconnecter`, elle ferme sa liaison et sort sans rien toucher.
    func connecterReseau() async {
        deconnecter(.connexion)
        serieEtat = serie
        let n = essai
        // La liaison USB en place est vraiment fermee : le port est libre.
        await fermetures?.value
        guard n == essai, liaison == .reseau else { return }
        var canal: (any CanalSonde)?
        do {
            guard let hote else { throw CleReseau.Erreur.sansNomDHote }
            let c = try await ouvrirReseau(hote, try await Self.lireCle(trousseau, hote))
            canal = c
            guard n == essai else {
                c.fermer()
                return
            }
            let s = SondeUSB(canal: c)
            enConnexion = s
            try await s.demarrer { [weak self] in
                Task { @MainActor in self?.liaisonFermee(s) }
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
                etat = .refusee(String(localized: "\(hote).local n'est pas une sonde (« \(b.produit) »)"))
                return
            }
            enConnexion = nil
            sonde = s
            etat = .connectee(b)
            essaisReprise = 0
            retenirNom(b.nom)
            lancerBoucle()
        } catch {
            // Session ouverte puis abandonnee (bonjour sans reponse...) : fermee ici.
            canal?.fermer()
            guard n == essai else { return }
            enConnexion = nil
            etat = .erreur(error.localizedDescription)
            // Sans cle, ou cle refusee : il faut l'USB ; le reste se reprend seul.
            if error is ErreurTrousseau || error is CleReseau.Erreur { return }
            if let e = error as? ErreurReseau, !e.repriseAutomatique { return }
            planifierReprise()
        }
    }

    /// Cle de ce Mac pour la sonde, lue hors de l'acteur principal : macOS peut d'abord demander
    /// l'autorisation d'acceder au trousseau (fenetre modale), sans figer le menu.
    private nonisolated static func lireCle(_ trousseau: any TrousseauCles, _ nom: String) async throws -> Data {
        try await Task.detached(priority: .userInitiated) { try trousseau.lire(nom: nom) }.value
    }

    /// Nouvel essai de la liaison reseau apres un delai croissant.
    private func planifierReprise() {
        let delai = delaisReprise[min(essaisReprise, delaisReprise.count - 1)]
        essaisReprise += 1
        let n = essai
        reprise?.cancel()
        reprise = Task { [weak self] in
            try? await Task.sleep(for: delai)
            guard !Task.isCancelled, let self, n == self.essai, self.liaison == .reseau else { return }
            await self.connecterReseau()
        }
    }

    // MARK: - Cle

    /// « Autoriser l'accès réseau » (Reglages, sonde retenue branchee en USB) : `bonjour` pour un
    /// nom d'hote a jour (sans lui, aucune cle n'est demandee), `cle nouvelle` par l'USB, cle
    /// verifiee puis rangee dans le trousseau sous ce nom. La carte remplace sa cle : une session
    /// reseau en cours (autre Mac) tombe.
    func autoriserAccesReseau() async {
        guard peutAutoriser, let s = sonde else { return }
        autorisationEnCours = true
        erreurAutorisation = nil
        defer { autorisationEnCours = false }
        do {
            let b = try await s.bonjour()
            if sonde === s {
                etat = .connectee(b)
                retenirNom(b.nom)
            }
            guard let nomHote = b.hote, !nomHote.isEmpty else { throw CleReseau.Erreur.sansNomDHote }
            let reponse = try await s.cleNouvelle(alea: CleReseau.alea())
            let c = try CleReseau.verifier(reponse).get()
            // La carte a adopte la cle : elle se range meme si la liaison s'est fermee depuis.
            let nom = c.hote ?? nomHote
            try trousseau.ranger(nom: nom, cle: c.cle, empreinte: c.empreinte)
            if let ancien = hote, ancien != nom { try? trousseau.oublier(nom: ancien) }
            retenirHote(nom)
        } catch {
            erreurAutorisation = error.localizedDescription
        }
    }

    /// Ferme sans attendre la liaison connectee et celle d'une connexion en
    /// cours, qui devient perimee ; `connecter` attend ces fermetures. `port` :
    /// celui que le nouvel etat concerne (connexion).
    private func deconnecter(_ nouveau: Etat, port: PortUSB? = nil) {
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
        serieEtat = port?.serie
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
