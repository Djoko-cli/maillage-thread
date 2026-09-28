import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Noms de Maison : dossier du passeur")
struct DossierNomsTests {
    static let date = Date(timeIntervalSince1970: 1_790_000_000)

    static func noms(_ statut: StatutPasseur = .ok, nom: String = "Halo", message: String? = nil) -> NomsMaison {
        NomsMaison(date: date, statut: statut, message: message,
                   accessoires: statut == .ok ? [AccessoireMaison(nom: nom, noeudMatter: "00000000000002E9")] : [])
    }

    /// Preferences jetables : un domaine unique, a effacer apres le test.
    static func preferences() throws -> (UserDefaults, String) {
        let domaine = "maillage-tests-noms-\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: domaine)), domaine)
    }

    /// Dossier temporaire unique, a effacer apres le test.
    static func dossierTemporaire() throws -> URL {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("noms-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        return dossier
    }

    static func signet(_ dossier: URL) throws -> Data {
        try dossier.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Textes de l'app, dans la langue de l'hote des tests.
    static let refus = String(localized: "Accès à Maison refusé au passeur : Réglages Système › Confidentialité et sécurité › Maison.")
    static let introuvable = String(localized: "Dossier des noms introuvable : choisis-le de nouveau (Réglages › Noms de Maison).")

    /// Un releve reussi remplace les noms ; un echec du passeur les garde et dit
    /// pourquoi, avec les textes de l'app : le message du passeur (en francais
    /// seulement) n'est que le detail d'une erreur.
    @Test func echecGardeLesNoms() {
        let ancien = Self.noms(nom: "Halo")
        let (garde, probleme) = DossierNoms.retenir(Self.noms(.refuse, message: "Accès refusé"), ancien: ancien)
        #expect(garde == ancien)
        #expect(probleme == Self.refus)
        let (_, indisponible) = DossierNoms.retenir(Self.noms(.indisponible, message: "Capacité absente"), ancien: ancien)
        #expect(indisponible == String(localized: "HomeKit indisponible pour le passeur."))
        let (gardeAussi, erreur) = DossierNoms.retenir(Self.noms(.erreur, message: "Aucun domicile dans Maison"), ancien: ancien)
        #expect(gardeAussi == ancien)
        #expect(erreur == String(localized: "Le passeur a échoué : \("Aucun domicile dans Maison")"))
        let (_, sansDetail) = DossierNoms.retenir(Self.noms(.erreur), ancien: nil)
        #expect(sansDetail == String(localized: "Le passeur a échoué."))
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
        let dossier = try Self.dossierTemporaire()
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
        d.integrer(Self.noms(.refuse, message: "Accès refusé"))
        #expect(d.noms == Self.noms(), "l'echec n'efface pas les noms")
        #expect(d.probleme == Self.refus)
        #expect(recus == [Self.noms()], "un seul changement")
        #expect(DossierNoms(preferences: preferences, cache: cache).noms == Self.noms(), "relus au lancement")
    }

    /// Un signet qui ne se resout plus : le probleme est dit, au lancement et a
    /// chaque lecture, et les derniers noms gardes restent.
    @Test func signetInvalide() throws {
        let (preferences, domaine) = try Self.preferences()
        defer { preferences.removePersistentDomain(forName: domaine) }
        let racine = try Self.dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: racine) }
        let cache = racine.appendingPathComponent("noms-maison.json")
        try Self.noms().donnees().write(to: cache)
        preferences.set(Data("pas un signet".utf8), forKey: DossierNoms.cleSignet)

        let d = DossierNoms(preferences: preferences, cache: cache)
        #expect(d.dossier == nil)
        #expect(d.probleme == Self.introuvable)
        #expect(d.noms == Self.noms(), "les noms gardes restent")
        d.lire()
        #expect(d.probleme == Self.introuvable, "dit encore a la lecture")
        #expect(d.noms == Self.noms())
    }

    /// Un dossier renomme : le signet le suit, il est renouvele, et les noms s'y lisent.
    @Test func dossierDeplace() throws {
        let (preferences, domaine) = try Self.preferences()
        defer { preferences.removePersistentDomain(forName: domaine) }
        let racine = try Self.dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: racine) }
        let avant = racine.appendingPathComponent("avant")
        let apres = racine.appendingPathComponent("apres")
        try FileManager.default.createDirectory(at: avant, withIntermediateDirectories: true)
        try Self.noms().donnees().write(to: avant.appendingPathComponent(DossierNoms.fichier))
        let signet = try Self.signet(avant)
        preferences.set(signet, forKey: DossierNoms.cleSignet)
        try FileManager.default.moveItem(at: avant, to: apres)

        let d = DossierNoms(preferences: preferences, cache: racine.appendingPathComponent("noms-maison.json"))
        #expect(d.dossier?.lastPathComponent == "apres")
        let renouvele = try #require(preferences.data(forKey: DossierNoms.cleSignet))
        #expect(renouvele != signet, "signet perime renouvele")
        var perime = true
        let url = try URL(resolvingBookmarkData: renouvele, options: .withSecurityScope, relativeTo: nil,
                          bookmarkDataIsStale: &perime)
        #expect(url.lastPathComponent == "apres")
        #expect(!perime)
        d.lire()
        #expect(d.noms == Self.noms())
        #expect(d.probleme == nil)
    }

    /// Sans acces au dossier, un noms.json absent veut dire un dossier
    /// inaccessible (le choisir de nouveau), pas un passeur a lancer.
    @Test func dossierInaccessible() {
        #expect(DossierNoms.problemeDeLecture(.absent, acces: false)
                == String(localized: "Dossier des noms inaccessible : choisis-le de nouveau (Réglages › Noms de Maison)."))
        #expect(DossierNoms.problemeDeLecture(.absent, acces: true) == DossierNoms.ErreurNoms.absent.errorDescription)
        #expect(DossierNoms.problemeDeLecture(.illisible("x"), acces: false)
                == DossierNoms.ErreurNoms.illisible("x").errorDescription)
    }

    /// Relance a l'ouverture du graphe : releve absent ou de plus de 15 min, et
    /// pas de demande dans les 15 dernieres minutes (pas de relance en boucle).
    @Test func aRafraichir() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(DossierNoms.aRafraichir(releve: nil, demande: nil, maintenant: t))
        #expect(!DossierNoms.aRafraichir(releve: t.addingTimeInterval(-14 * 60), demande: nil, maintenant: t))
        #expect(DossierNoms.aRafraichir(releve: t.addingTimeInterval(-16 * 60), demande: nil, maintenant: t))
        #expect(!DossierNoms.aRafraichir(releve: t.addingTimeInterval(-3600), demande: t.addingTimeInterval(-60),
                                         maintenant: t), "demande recente : le passeur ne s'est peut-etre pas lance")
        #expect(DossierNoms.aRafraichir(releve: t.addingTimeInterval(-3600), demande: t.addingTimeInterval(-16 * 60),
                                        maintenant: t))
    }

    /// La demande deposee avant de lancer le passeur se relit dans le dossier.
    @Test func demandeDeposee() throws {
        let dossier = try Self.dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        try DossierNoms.deposerDemande(dans: dossier, date: t)
        let lue = try DemandePasseur.lire(Data(contentsOf: dossier.appendingPathComponent(DemandePasseur.fichier)))
        #expect(lue == DemandePasseur(date: t))
    }

    /// Sans memoire (demo, tests) ou sans dossier : l'ouverture du graphe ne
    /// lance jamais le passeur, meme avec un releve ancien.
    @Test func doitRafraichir() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let ancien = t.addingTimeInterval(-3600)
        #expect(DossierNoms.doitRafraichir(memoire: true, dossier: true, releve: ancien, demande: nil, maintenant: t))
        #expect(!DossierNoms.doitRafraichir(memoire: false, dossier: true, releve: ancien, demande: nil, maintenant: t))
        #expect(!DossierNoms.doitRafraichir(memoire: true, dossier: false, releve: ancien, demande: nil, maintenant: t))
        #expect(!DossierNoms.doitRafraichir(memoire: true, dossier: true, releve: t, demande: nil, maintenant: t))
    }

    /// Mode demo (sans memoire) : ni preferences ni signet, meme valide.
    @Test func modeDemo() throws {
        let (preferences, domaine) = try Self.preferences()
        defer { preferences.removePersistentDomain(forName: domaine) }
        let dossier = try Self.dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }
        try Self.noms().donnees().write(to: dossier.appendingPathComponent(DossierNoms.fichier))
        preferences.set(try Self.signet(dossier), forKey: DossierNoms.cleSignet)

        let d = DossierNoms(preferences: preferences, cache: nil)
        #expect(d.dossier == nil, "le vrai dossier n'est pas montre en demo")
        d.lire()
        #expect(d.noms == nil)
        #expect(d.probleme == nil)
    }
}
