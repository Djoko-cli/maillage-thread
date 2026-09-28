import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Noms de Maison : dossier du passeur")
struct DossierNomsTests {
    static let date = Date(timeIntervalSince1970: 1_790_000_000)

    static func noms(_ statut: StatutPasseur = .ok, nom: String = "Halo") -> NomsMaison {
        NomsMaison(date: date, statut: statut, message: statut == .ok ? nil : "Accès refusé",
                   accessoires: statut == .ok ? [AccessoireMaison(nom: nom, noeudMatter: "00000000000002E9")] : [])
    }

    /// Un releve reussi remplace les noms ; un echec du passeur les garde et dit pourquoi.
    @Test func echecGardeLesNoms() {
        let ancien = Self.noms(nom: "Halo")
        let (garde, probleme) = DossierNoms.retenir(Self.noms(.refuse), ancien: ancien)
        #expect(garde == ancien)
        #expect(probleme == "Accès refusé")
        let (neuf, rien) = DossierNoms.retenir(Self.noms(nom: "Pont"), ancien: ancien)
        #expect(neuf?.accessoires.first?.nom == "Pont")
        #expect(rien == nil)
    }

    /// Au-dela de 7 jours, le profil gratuit du passeur a expire.
    @Test func ancien() {
        #expect(!DossierNoms.estAncien(Self.noms(), maintenant: Self.date + 6 * 86_400))
        #expect(DossierNoms.estAncien(Self.noms(), maintenant: Self.date + 8 * 86_400))
    }

    @Test func lectureDansUnDossier() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("noms-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        guard case .failure(.absent) = DossierNoms.lire(dans: dossier) else {
            Issue.record("sans noms.json : absent")
            return
        }
        try Self.noms().donnees().write(to: dossier.appendingPathComponent(DossierNoms.fichier))
        #expect(try DossierNoms.lire(dans: dossier).get() == Self.noms())
        try Data("pas du json".utf8).write(to: dossier.appendingPathComponent(DossierNoms.fichier))
        guard case .failure(.illisible) = DossierNoms.lire(dans: dossier) else {
            Issue.record("fichier abime : illisible")
            return
        }
    }

    /// Les derniers noms retenus sont gardes dans le dossier de l'app et relus au lancement.
    @Test func memoireDesNoms() throws {
        let domaine = "maillage-tests-noms"
        let preferences = try #require(UserDefaults(suiteName: domaine))
        defer { preferences.removePersistentDomain(forName: domaine) }
        let cache = FileManager.default.temporaryDirectory
            .appendingPathComponent("noms-\(UUID().uuidString)").appendingPathComponent("noms-maison.json")
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }

        let d = DossierNoms(preferences: preferences, cache: cache)
        #expect(d.noms == nil)
        var recus: [NomsMaison?] = []
        d.surNoms = { recus.append($0) }
        d.integrer(Self.noms())
        d.integrer(Self.noms(.refuse))
        #expect(d.noms == Self.noms(), "l'echec n'efface pas les noms")
        #expect(d.probleme == "Accès refusé")
        #expect(recus == [Self.noms()], "un seul changement")
        #expect(DossierNoms(preferences: preferences, cache: cache).noms == Self.noms(), "relus au lancement")
    }
}
