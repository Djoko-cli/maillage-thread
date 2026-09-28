import HomeKit
import SwiftUI

/// Passeur des noms de Maison : app iOS lancee sur le Mac (« concue pour
/// iPad »), seule forme qui ait HomeKit avec une equipe gratuite. Elle lit
/// Maison, ecrit `noms.json` dans le dossier choisi une fois, puis se ferme.
@main
struct PasseurApp: App {
    @State private var passeur = Passeur()

    var body: some Scene {
        WindowGroup {
            VuePasseur()
                .environment(passeur)
        }
    }
}

struct VuePasseur: View {
    @Environment(Passeur.self) private var passeur
    @State private var choisir = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Passeur Noms").font(.title2.bold())
            Text(passeur.etat).multilineTextAlignment(.center)
            if passeur.dossierManquant {
                Button("Choisir le dossier des noms…") { choisir = true }
                    .buttonStyle(.borderedProminent)
            } else if let dossier = passeur.dossierUtilise {
                Text("Dossier : \(dossier)").font(.caption).foregroundStyle(.secondary)
                Button("Changer de dossier…") {
                    passeur.suspendreFermeture()
                    choisir = true
                }
                if let n = passeur.fermetureDans {
                    Text("Fermeture dans \(n) s").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Choisis un dossier hors iCloud et hors du dépôt, par exemple « Maillage Thread » dans ton dossier personnel. Maillage Thread lira noms.json dans ce même dossier.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(minWidth: 420)
        .fileImporter(isPresented: $choisir, allowedContentTypes: [.folder]) { passeur.dossierChoisi($0) }
        .onChange(of: choisir) { _, ouvert in
            if !ouvert { passeur.reprendreFermeture() }
        }
        .task { passeur.demarrer() }
    }
}

@MainActor
@Observable
final class Passeur: NSObject, HMHomeManagerDelegate {
    static let cleDossier = "dossierNoms"
    static let fichier = "noms.json"

    private(set) var etat = "Lecture de Maison…"
    private(set) var dossierManquant = false
    /// Dossier ou `noms.json` a ete ecrit (chemin affiche).
    private(set) var dossierUtilise: String?
    /// Secondes avant la fermeture, apres une ecriture reussie.
    private(set) var fermetureDans: Int?
    @ObservationIgnored private var gestionnaire: HMHomeManager?
    /// Releve en attente d'un dossier.
    @ObservationIgnored private var enAttente: NomsMaison?
    /// Dernier releve ecrit : reecrit ailleurs si l'on change de dossier.
    @ObservationIgnored private var dernier: NomsMaison?
    @ObservationIgnored private var compteARebours: Task<Void, Never>?
    /// Maison a donne ses domiciles : avant `homeManagerDidUpdateHomes`, la
    /// liste est vide (HMHomeManager.h).
    @ObservationIgnored private var maisonChargee = false
    /// Delai de secours : sans reponse de Maison, le dire plutot qu'attendre sans fin.
    static let delaiMaison: Duration = .seconds(30)

    func demarrer() {
        guard gestionnaire == nil else { return }
        let g = HMHomeManager()
        g.delegate = self
        gestionnaire = g
        Task { [weak self] in
            try? await Task.sleep(for: Self.delaiMaison)
            // Rien d'ecrit ni en attente d'un dossier : Maison n'a pas repondu.
            guard let self, self.dernier == nil, self.enAttente == nil else { return }
            self.ecrire(NomsMaison(date: .now, statut: .erreur, message: "Maison n'a pas répondu"))
        }
    }

    // HomeKit ne dit pas sur quel fil il appelle son delegue : passer par l'acteur principal.
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.maisonChargee = true
            self.relever(manager)
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        Task { @MainActor in self.autorisation(status) }
    }

    /// Acces refuse : fichier « refuse ». Acces accorde : releve, des que Maison
    /// a donne ses domiciles (sinon `homeManagerDidUpdateHomes` le fera). L'ordre
    /// des deux rappels ne compte pas.
    private func autorisation(_ s: HMHomeManagerAuthorizationStatus) {
        if s.contains(.authorized) {
            if maisonChargee, let g = gestionnaire { relever(g) }
        } else if s.contains(.determined) {
            ecrire(NomsMaison(date: .now, statut: .refuse,
                              message: "Accès à Maison refusé : Réglages Système › Confidentialité et sécurité › Maison."))
        }
    }

    private func relever(_ manager: HMHomeManager) {
        guard manager.authorizationStatus.contains(.authorized) else {
            // Au relancement apres un refus, le statut peut ne jamais etre annonce comme un changement.
            autorisation(manager.authorizationStatus)
            return
        }
        guard !manager.homes.isEmpty else {
            // Jamais un « ok » vide : il effacerait les noms gardes par l'app.
            ecrire(NomsMaison(date: .now, statut: .erreur, message: "Aucun domicile dans Maison"))
            return
        }
        let accessoires = manager.homes.flatMap(\.accessories).map { a in
            AccessoireMaison(nom: a.name, piece: a.room?.name, fabricant: a.manufacturer, modele: a.model,
                             categorie: a.category.localizedDescription,
                             noeudMatter: AccessoireMaison.noeud(a.matterNodeID),
                             pont: a.category.categoryType == HMAccessoryCategoryTypeBridge ? true : nil)
        }.sorted { $0.nom < $1.nom }
        let domicile = manager.homes.map(\.name).joined(separator: " + ")
        ecrire(NomsMaison(date: .now, statut: .ok, domicile: domicile.isEmpty ? nil : domicile, accessoires: accessoires))
    }

    func dossierChoisi(_ r: Result<URL, any Error>) {
        guard case .success(let url) = r else { return }
        let acces = url.startAccessingSecurityScopedResource()
        defer { if acces { url.stopAccessingSecurityScopedResource() } }
        guard let signet = try? url.bookmarkData() else {
            etat = "Ce dossier n'est pas utilisable."
            return
        }
        UserDefaults.standard.set(signet, forKey: Self.cleDossier)
        dossierManquant = false
        if let n = enAttente ?? dernier { ecrire(n) }
    }

    /// Dossier du signet ; `perime` : a renouveler (dossier deplace ou renomme).
    private func dossier() -> (url: URL, perime: Bool)? {
        guard let signet = UserDefaults.standard.data(forKey: Self.cleDossier) else { return nil }
        var perime = false
        guard let url = try? URL(resolvingBookmarkData: signet, options: [], relativeTo: nil,
                                 bookmarkDataIsStale: &perime) else { return nil }
        return (url, perime)
    }

    /// Ecrit `noms.json` dans le dossier choisi, puis ferme l'app 10 s plus tard.
    private func ecrire(_ n: NomsMaison) {
        guard let (dossier, perime) = dossier() else {
            enAttente = n
            dossierManquant = true
            etat = "\(n.accessoires.count) accessoires lus. Choisis le dossier où écrire noms.json."
            return
        }
        let acces = dossier.startAccessingSecurityScopedResource()
        defer { if acces { dossier.stopAccessingSecurityScopedResource() } }
        // Un signet perime se renouvelle pendant que l'acces est ouvert.
        if perime, let nouveau = try? dossier.bookmarkData() {
            UserDefaults.standard.set(nouveau, forKey: Self.cleDossier)
        }
        do {
            try n.donnees().write(to: dossier.appendingPathComponent(Self.fichier), options: .atomic)
            enAttente = nil
            dernier = n
            dossierUtilise = dossier.path(percentEncoded: false)
            etat = n.statut == .ok
                ? "\(n.accessoires.count) accessoires écrits dans \(Self.fichier)."
                : (n.message ?? "Accès à Maison refusé.")
            reprendreFermeture()
        } catch {
            enAttente = n
            dossierManquant = true
            etat = "Écriture impossible : \(error.localizedDescription)"
        }
    }

    /// Le compte a rebours s'arrete pendant le choix d'un autre dossier.
    func suspendreFermeture() {
        compteARebours?.cancel()
        compteARebours = nil
        fermetureDans = nil
    }

    /// Ferme l'app 10 s apres la derniere ecriture reussie.
    func reprendreFermeture() {
        guard dernier != nil, !dossierManquant else { return }
        compteARebours?.cancel()
        compteARebours = Task { [weak self] in
            for n in stride(from: 10, to: 0, by: -1) {
                self?.fermetureDans = n
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            exit(0)
        }
    }
}
