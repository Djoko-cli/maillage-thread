import AppKit
import Foundation
import MaillageCoeur
import Observation

/// Noms de Maison ecrits par le passeur (`noms.json`) dans un dossier choisi
/// une fois (signet a portee de securite, garde dans les preferences). Les
/// derniers noms lus avec succes sont gardes dans le dossier de l'app : un
/// fichier d'echec du passeur (acces a Maison refuse) ne les efface pas.
@MainActor
@Observable
final class DossierNoms {
    enum ErreurNoms: LocalizedError {
        case absent
        case illisible(String)

        var errorDescription: String? {
            switch self {
            case .absent: String(localized: "Pas encore de noms.json dans ce dossier : lance le passeur.")
            case .illisible(let m): String(localized: "noms.json illisible : \(m)")
            }
        }
    }

    nonisolated static let cleSignet = "dossierNoms"
    nonisolated static let fichier = "noms.json"
    nonisolated static let idPasseur = "fr.djoko.maillage.passeur"
    /// Profil gratuit du passeur : 7 jours ; au-dela, il faut le recompiler.
    nonisolated static let validite: TimeInterval = 7 * 24 * 3600

    private(set) var dossier: URL?
    /// Derniers noms lus avec succes.
    private(set) var noms: NomsMaison?
    /// Dernier probleme : acces refuse par Maison, dossier introuvable ou
    /// inaccessible, fichier absent ou illisible, passeur introuvable ou qui ne
    /// se lance pas.
    private(set) var probleme: String?
    /// Appele a chaque changement des noms retenus.
    @ObservationIgnored var surNoms: ((NomsMaison?) -> Void)?

    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let cache: URL?
    @ObservationIgnored private var observateurs: [NSObjectProtocol] = []

    /// `cache` : ou garder les derniers noms ; nil (mode demo, tests) : ni
    /// memoire, ni preferences, ni signet.
    init(preferences: UserDefaults = .standard, cache: URL?) {
        self.preferences = preferences
        self.cache = cache
        noms = cache.flatMap { try? NomsMaison.lire(Data(contentsOf: $0)) }
        resoudre()
    }

    /// Donne les noms gardes, relit le dossier, puis le relit quand le passeur
    /// se ferme et quand l'app revient au premier plan.
    func demarrer() {
        surNoms?(noms)
        lire()
        observateurs.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let id = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                if id == Self.idPasseur { self?.lire() }
            }
        })
        observateurs.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lire() }
        })
    }

    /// Choix du dossier ou le passeur ecrit `noms.json` (jamais en mode demo).
    func choisir() {
        guard cache != nil else { return }
        let panneau = NSOpenPanel()
        panneau.canChooseDirectories = true
        panneau.canChooseFiles = false
        panneau.allowsMultipleSelection = false
        panneau.canCreateDirectories = true
        panneau.message = String(localized: "Dossier où le passeur écrit noms.json, hors iCloud et hors du dépôt (par exemple « Maillage Thread » dans ton dossier personnel).")
        NSApp.activate()
        guard panneau.runModal() == .OK, let url = panneau.url else { return }
        do {
            let signet = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            preferences.set(signet, forKey: Self.cleSignet)
            lire()
        } catch {
            probleme = error.localizedDescription
        }
    }

    /// Relit `noms.json` dans le dossier choisi. Le signet est resolu a chaque
    /// lecture : l'app, qui tourne des semaines, suit un dossier deplace ou un
    /// volume monte apres son lancement.
    func lire() {
        resoudre()
        guard let dossier else { return }
        // Lire meme sans acces ouvert : un dossier du conteneur n'en a pas besoin.
        let acces = dossier.startAccessingSecurityScopedResource()
        defer { if acces { dossier.stopAccessingSecurityScopedResource() } }
        switch Self.lire(dans: dossier) {
        case .success(let n): integrer(n)
        case .failure(let e): probleme = Self.problemeDeLecture(e, acces: acces)
        }
    }

    /// Retient un fichier lu : les noms s'il est reussi, sinon le probleme.
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

    /// Lance le passeur (installe par outils/passeur.sh) ; il ecrit puis se ferme.
    func lancerPasseur() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.idPasseur) else {
            probleme = String(localized: "Passeur Noms introuvable : lance outils/passeur.sh.")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, erreur in
            guard let erreur else { return }
            // Cause la plus probable apres quelques jours : le profil gratuit a expire.
            let m = String(localized: "\(erreur.localizedDescription) (profil de 7 jours expiré ? relance outils/passeur.sh)")
            Task { @MainActor in self?.probleme = m }
        }
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

    /// Echec de lecture : sans acces ouvert, un fichier absent veut dire un
    /// dossier inaccessible (le choisir de nouveau), pas un passeur a lancer.
    nonisolated static func problemeDeLecture(_ e: ErreurNoms, acces: Bool) -> String? {
        if case .absent = e, !acces {
            return String(localized: "Dossier des noms inaccessible : choisis-le de nouveau (Réglages › Noms de Maison).")
        }
        return e.errorDescription
    }

    /// Noms de plus de 7 jours : le profil gratuit du passeur a expire.
    nonisolated static func estAncien(_ n: NomsMaison, maintenant: Date) -> Bool {
        maintenant.timeIntervalSince(n.date) > validite
    }

    /// Lit `noms.json` dans un dossier deja accessible.
    nonisolated static func lire(dans dossier: URL) -> Result<NomsMaison, ErreurNoms> {
        guard let d = try? Data(contentsOf: dossier.appendingPathComponent(fichier)) else { return .failure(.absent) }
        do {
            return .success(try NomsMaison.lire(d))
        } catch {
            return .failure(.illisible(error.localizedDescription))
        }
    }

    /// Resout le signet du dossier. Introuvable : le probleme est dit. Perime
    /// (dossier deplace ou renomme) : il est renouvele pendant que l'acces est
    /// ouvert. Sans memoire (mode demo, tests), ni preferences ni signet.
    private func resoudre() {
        guard cache != nil, let signet = preferences.data(forKey: Self.cleSignet) else {
            dossier = nil
            return
        }
        var perime = false
        guard let url = try? URL(resolvingBookmarkData: signet, options: .withSecurityScope, relativeTo: nil,
                                 bookmarkDataIsStale: &perime) else {
            dossier = nil
            probleme = String(localized: "Dossier des noms introuvable : choisis-le de nouveau (Réglages › Noms de Maison).")
            return
        }
        if perime {
            let acces = url.startAccessingSecurityScopedResource()
            defer { if acces { url.stopAccessingSecurityScopedResource() } }
            if let nouveau = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                                                   relativeTo: nil) {
                preferences.set(nouveau, forKey: Self.cleSignet)
            }
        }
        dossier = url
    }
}
