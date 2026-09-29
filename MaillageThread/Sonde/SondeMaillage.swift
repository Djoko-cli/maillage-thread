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
    static let periode: Duration = .seconds(300)

    private(set) var etat: Etat = .sansSonde
    /// Ports Espressif branches (la sonde, ou un autre C6 comme le pont Halo).
    private(set) var ports: [PortUSB] = []
    private(set) var serie: String?
    private(set) var etatSonde: EtatSonde?
    private(set) var derniereTournee: Date?
    private(set) var tourneeEnCours = false
    /// Derniere erreur d'une tournee (la liaison reste ouverte).
    private(set) var erreurTournee: String?
    /// Appele a chaque nouveau maillage.
    @ObservationIgnored var surMaillage: ((Maillage) -> Void)?

    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let actif: Bool
    @ObservationIgnored private let ouvrirCanal: (String) -> any CanalSonde
    @ObservationIgnored private var sonde: SondeUSB?
    @ObservationIgnored private var memoire = MemoireTournee()
    @ObservationIgnored private var boucle: Task<Void, Never>?
    @ObservationIgnored private var surveillantPorts: PortsUSB?

    /// `actif` faux (mode demo, tests) : ni port, ni preferences lues.
    init(preferences: UserDefaults = .standard, actif: Bool,
         ouvrirCanal: @escaping (String) -> any CanalSonde = { CanalSerie(liaison: LiaisonSerie(chemin: $0)) }) {
        self.preferences = preferences
        self.actif = actif
        self.ouvrirCanal = ouvrirCanal
        serie = actif ? preferences.string(forKey: Self.cleSerie) : nil
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
    func choisir(_ port: PortUSB) {
        guard actif else { return }
        Task { await connecter(port, choisi: true) }
    }

    /// Oublie la sonde retenue et ferme la liaison.
    func oublier() {
        preferences.removeObject(forKey: Self.cleSerie)
        serie = nil
        deconnecter(.sansSonde)
    }

    /// Tournee tout de suite (bouton rafraichir).
    func rafraichir() {
        guard sonde != nil else { return }
        lancerBoucle()
    }

    /// Ports branches : la sonde retenue revient, ou s'en va.
    func portsChanges(_ liste: [PortUSB]) {
        ports = liste.filter(\.estEspressif)
        guard let serie else { return }
        if let p = ports.first(where: { $0.serie == serie }) {
            if sonde == nil && etat != .connexion { Task { await connecter(p, choisi: false) } }
        } else if sonde != nil || etat != .absente {
            deconnecter(.absente)
        }
    }

    func connecter(_ port: PortUSB, choisi: Bool) async {
        deconnecter(.connexion)
        let s = SondeUSB(canal: ouvrirCanal(port.chemin))
        do {
            try await s.demarrer { [weak self] in
                Task { @MainActor in self?.liaisonFermee(s) }
            }
            let b = try await s.bonjour()
            guard b.estSonde else {
                await s.fermer()
                etat = .refusee(String(localized: "\(port.libelle) n'est pas une sonde (« \(b.produit) »)"))
                return
            }
            sonde = s
            etat = .connectee(b)
            if choisi, let serieUSB = port.serie {
                preferences.set(serieUSB, forKey: Self.cleSerie)
                serie = serieUSB
            }
            lancerBoucle()
        } catch {
            await s.fermer()
            etat = choisi ? .refusee(error.localizedDescription) : .erreur(error.localizedDescription)
        }
    }

    private func liaisonFermee(_ s: SondeUSB) {
        guard sonde === s else { return }
        deconnecter(.absente)
    }

    private func deconnecter(_ nouveau: Etat) {
        boucle?.cancel()
        boucle = nil
        if let s = sonde { Task { await s.fermer() } }
        sonde = nil
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

    /// Etat de la sonde, puis une tournee ; le maillage part a la surveillance.
    func uneTournee() async {
        guard let sonde, !tourneeEnCours else { return }
        tourneeEnCours = true
        defer { tourneeEnCours = false }
        do {
            etatSonde = try await sonde.etat()
            if let r = try await Tournee.executer(sonde, memoire: memoire, maintenant: Date()) {
                memoire = r.memoire
                derniereTournee = r.maillage.date
                surMaillage?(r.maillage)
            }
            erreurTournee = nil
        } catch SondeUSB.Erreur.fermee {
            // La liaison est fermee : `liaisonFermee` s'en occupe.
        } catch {
            erreurTournee = error.localizedDescription
        }
    }
}
