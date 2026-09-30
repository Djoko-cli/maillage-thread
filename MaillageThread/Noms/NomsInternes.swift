import AppKit
import Foundation
import MaillageCoeur
import Observation

/// Noms de Maison, releves par le passeur (app iOS lancee sur le Mac) et gardes dans le
/// conteneur de l'app (`noms.json`), sans dossier a choisir. Un releve : une ecoute TCP sur
/// 127.0.0.1 (`EcouteReleve`) et un jeton a usage unique ; le passeur, ouvert sans activation
/// avec l'URL `maillage-passeur://releve?port=<port>&jeton=<jeton>`, lit Maison, envoie le
/// releve (`EnvoiPasseur`) et se ferme.
/// Le dernier releve valide est garde : un echec ne l'efface jamais, il se dit dans `probleme`.
@MainActor
@Observable
final class NomsInternes {
    /// Ouvre le passeur avec cette cible (son URL) ; nil s'il est ouvert, sinon le probleme a montrer.
    typealias Lanceur = @MainActor (_ cible: EnvoiPasseur.Cible) async -> String?

    /// Fin d'un releve.
    enum Fin: Equatable {
        /// Le JSON du passeur, de la longueur annoncee, a decoder.
        case recu(Data)
        case jetonFaux
        case longueurFausse
        /// Connexion coupee par une erreur avant la fin de la trame : la trame n'est pas en cause.
        case interrompu
        /// Aucun releve dans le delai.
        case delai
        /// Passeur introuvable ou lancement refuse : le probleme a montrer.
        case lancement(String)
        /// Ecoute impossible : la cause.
        case ecoute(String)
    }

    nonisolated static let fichier = "noms.json"
    nonisolated static let idPasseur = "fr.djoko.maillage.passeur"
    /// Profil gratuit du passeur : 7 jours ; au-dela, il faut le recompiler.
    nonisolated static let validite: TimeInterval = 7 * 24 * 3600
    /// Plus recent, un releve suffit : l'ouverture du graphe ne relance pas le passeur.
    nonisolated static let fraicheur: TimeInterval = 15 * 60
    /// Attente d'un releve : le premier lancement attend la reponse a la demande d'acces a Maison.
    nonisolated static let delaiParDefaut: Duration = .seconds(120)

    /// Dernier releve valide.
    private(set) var noms: NomsMaison?
    /// Dernier probleme : releve refuse, illisible ou interrompu, rien dans le delai, passeur
    /// introuvable ou qui ne se lance pas, acces a Maison refuse, ecriture impossible.
    private(set) var probleme: String?
    /// Une ecoute est ouverte : le passeur est lance, ou va l'etre.
    private(set) var releveEnCours = false
    /// Appele a chaque changement des noms retenus.
    @ObservationIgnored var surNoms: ((NomsMaison?) -> Void)?
    /// Derniere demande de releve.
    @ObservationIgnored private(set) var derniereDemande: Date?

    @ObservationIgnored private let cache: URL?
    @ObservationIgnored private let delai: Duration
    @ObservationIgnored private let lanceur: Lanceur
    @ObservationIgnored private var ecoute: EcouteReleve?
    @ObservationIgnored private var minuterie: Task<Void, Never>?

    /// `cache` : le `noms.json` de l'app ; nil (mode demo, tests) : aucun releve lu, ecrit ni
    /// demande. `lanceur` : le vrai passeur par defaut, un faux dans les tests.
    init(cache: URL?, delai: Duration = NomsInternes.delaiParDefaut,
         lanceur: @escaping Lanceur = NomsInternes.lancerPasseurDuMac) {
        self.cache = cache
        self.delai = delai
        self.lanceur = lanceur
        noms = cache.flatMap { try? NomsMaison.lire(Data(contentsOf: $0)) }
    }

    /// `noms.json` dans le dossier de l'app, a cote de `identites-routeurs.json` ; nil en demo et
    /// sous les tests.
    static func fichierCache(demo: Bool, sousTests: Bool) -> URL? {
        demo || sousTests ? nil : Surveillance.dossierParDefaut.appendingPathComponent(fichier)
    }

    /// Donne les noms gardes.
    func demarrer() {
        surNoms?(noms)
    }

    /// Demande un releve : ouvre l'ecoute, puis lance le passeur avec son port et un jeton neuf.
    /// Une seule ecoute a la fois : une demande pendant un releve est ignoree. Jamais sans memoire.
    func lancerPasseur() {
        guard cache != nil, ecoute == nil else { return }
        derniereDemande = .now
        let e = EcouteReleve(jeton: EnvoiPasseur.nouveauJeton())
        ecoute = e
        releveEnCours = true
        minuterie = Task { [weak self, delai] in
            try? await Task.sleep(for: delai)
            guard !Task.isCancelled else { return }
            // Sans NomsInternes, personne ne finira ce releve : on ferme l'ecoute, que seul
            // `fermer()` libere (la fermeture donnee a `ouvrir` la retient, et elle la garde).
            guard let self else { e.fermer(); return }
            self.finir(e, .delai)
        }
        e.ouvrir { [weak self] evenement in
            self?.surEcoute(e, evenement)
        }
    }

    private func surEcoute(_ e: EcouteReleve, _ evenement: EcouteReleve.Evenement) {
        guard ecoute === e else { return }
        switch evenement {
        case .prete(let port):
            let cible = EnvoiPasseur.Cible(port: port, jeton: e.jeton)
            Task { [weak self] in
                guard let self, let p = await self.lanceur(cible) else { return }
                self.finir(e, .lancement(p))
            }
        case .fin(let fin):
            finir(e, fin)
        }
    }

    /// Ferme l'ecoute et retient l'issue du releve (sauf s'il est deja fini).
    private func finir(_ e: EcouteReleve, _ fin: Fin) {
        guard ecoute === e else { return }
        ecoute = nil
        e.fermer()
        minuterie?.cancel()
        minuterie = nil
        releveEnCours = false
        switch fin {
        case .recu(let json):
            do {
                integrer(try NomsMaison.lire(json))
            } catch {
                probleme = String(localized: "Relevé de Maison illisible : \(error.localizedDescription)")
            }
        case .jetonFaux: probleme = String(localized: "Relevé de Maison refusé : jeton faux.")
        case .longueurFausse: probleme = String(localized: "Relevé de Maison illisible : longueur fausse.")
        case .interrompu:
            probleme = String(localized: "Relevé de Maison interrompu : la connexion avec Passeur Noms a été coupée.")
        case .delai: probleme = String(localized: "Passeur Noms n'a rien envoyé en 2 minutes.")
        case .lancement(let p): probleme = p
        case .ecoute(let cause): probleme = String(localized: "Écoute du relevé impossible : \(cause)")
        }
    }

    /// Retient un releve recu : les noms s'il est reussi, sinon le probleme ; les noms retenus
    /// sont ecrits dans le conteneur, d'un coup (ecriture atomique).
    func integrer(_ n: NomsMaison) {
        let (garde, p) = Self.retenir(n, ancien: noms)
        probleme = p
        guard garde != noms else { return }
        noms = garde
        if let garde, let cache {
            do {
                try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
                try garde.donnees().write(to: cache, options: .atomic)
            } catch {
                probleme = error.localizedDescription
            }
        }
        surNoms?(garde)
    }

    /// Lanceur reel : Passeur Noms, installe par outils/passeur.sh, ouvert sans activation avec
    /// l'URL de la cible (port et jeton). Pas d'arguments de lancement : macOS retire ceux d'une
    /// app du bac a sable (verifie le 30/09, le passeur n'a recu que le chemin de son executable).
    static func lancerPasseurDuMac(_ cible: EnvoiPasseur.Cible) async -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: idPasseur) else {
            return String(localized: "Passeur Noms introuvable : lance outils/passeur.sh.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        do {
            _ = try await NSWorkspace.shared.open([cible.url], withApplicationAt: url, configuration: configuration)
            return nil
        } catch {
            // Cause la plus probable apres quelques jours : le profil gratuit a expire.
            return String(localized: "\(error.localizedDescription) (profil de 7 jours expiré ? relance outils/passeur.sh)")
        }
    }

    /// A l'ouverture du graphe, puis toutes les heures tant qu'il reste ouvert :
    /// relance le passeur si le dernier releve a plus de 15 min. Jamais sans
    /// memoire (mode demo, tests).
    func rafraichirSiAncien(maintenant: Date = .now) {
        guard Self.doitRafraichir(memoire: cache != nil, releve: noms?.date, demande: derniereDemande,
                                  maintenant: maintenant) else { return }
        lancerPasseur()
    }

    nonisolated static func doitRafraichir(memoire: Bool, releve: Date?, demande: Date?, maintenant: Date) -> Bool {
        memoire && aRafraichir(releve: releve, demande: demande, maintenant: maintenant)
    }

    /// Releve absent ou de plus de 15 min, et pas de demande dans les 15
    /// dernieres minutes : un passeur qui ne se lance pas n'est pas relance en boucle.
    nonisolated static func aRafraichir(releve: Date?, demande: Date?, maintenant: Date) -> Bool {
        func ancien(_ d: Date?) -> Bool { d.map { maintenant.timeIntervalSince($0) > fraicheur } ?? true }
        return ancien(releve) && ancien(demande)
    }

    /// Un releve reussi remplace les noms ; un echec les garde et dit pourquoi,
    /// avec les textes de l'app : le message du passeur (en francais seulement)
    /// n'est que le detail d'une erreur.
    nonisolated static func retenir(_ nouveau: NomsMaison, ancien: NomsMaison?) -> (NomsMaison?, String?) {
        switch nouveau.statut {
        case .ok: (nouveau, nil)
        case .refuse:
            (ancien, String(localized: "Accès à Maison refusé au passeur : Réglages Système › Confidentialité et sécurité › Maison."))
        case .indisponible: (ancien, String(localized: "HomeKit indisponible pour le passeur."))
        case .erreur:
            (ancien, nouveau.message.map { String(localized: "Le passeur a échoué : \($0)") }
                ?? String(localized: "Le passeur a échoué."))
        }
    }

    /// Noms de plus de 7 jours : le profil gratuit du passeur a expire.
    nonisolated static func estAncien(_ n: NomsMaison, maintenant: Date) -> Bool {
        maintenant.timeIntervalSince(n.date) > validite
    }
}
