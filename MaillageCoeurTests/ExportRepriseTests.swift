import Foundation
import Testing
@testable import MaillageCoeur

/// L'export pour Maillage IoT (spec de Maillage IoT, section 4.2) : un dossier que `ContratExport.verifierDossier`
/// relit sans erreur, une copie fidele des fichiers connus, les autres cites, et rien de change dans le dossier de
/// l'app. Valeurs inventees.
@Suite("Export pour Maillage IoT")
struct ExportRepriseTests {
    static let date = Date(timeIntervalSince1970: 1_792_000_000.75)
    static let identifiant = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    /// Un dossier temporaire neuf, supprime a la fin du test.
    final class Bac {
        let racine = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-reprise-\(UUID().uuidString)")
        var source: URL { racine.appendingPathComponent("Maillage Thread") }
        var destination: URL { racine.appendingPathComponent("Export") }

        init() throws {
            try FileManager.default.createDirectory(at: racine, withIntermediateDirectories: true)
        }

        deinit { try? FileManager.default.removeItem(at: racine) }

        func ecrire(_ chemin: String, _ texte: String) throws {
            let url = source.appendingPathComponent(chemin)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(texte.utf8).write(to: url)
        }

        /// Chemins relatifs et contenus de tous les fichiers sous `dossier`.
        func contenu(_ dossier: URL) throws -> [String: Data] {
            var vus: [String: Data] = [:]
            let e = try #require(FileManager.default.enumerator(at: dossier, includingPropertiesForKeys: nil))
            for case let url as URL in e where (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                let chemin = String(url.standardizedFileURL.path.dropFirst(dossier.standardizedFileURL.path.count + 1))
                vus[chemin] = try Data(contentsOf: url)
            }
            return vus
        }
    }

    static func reglages() -> ContratExport.Reglages {
        ContratExport.reglages(depuis: [
            "sondeNom": "SONDE-T1", "vuePieces3D": true, "scissionsNotifiees": ["0000000A"],
            "SUHasLaunchedBefore": true,
        ], app: .maillageThread)
    }

    /// Ce que l'export a mis de cote (la Corbeille dans l'app) : ici, note puis efface.
    final class MisDeCote: @unchecked Sendable {
        var urls: [URL] = []
        func mettre(_ url: URL) {
            urls.append(url)
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func exporter(_ bac: Bac, vers destination: URL? = nil, misDeCote: MisDeCote = MisDeCote()) throws
        -> ContratExport.Manifeste {
        try ExportReprise.exporter(app: .maillageThread, source: bac.source, reglages: reglages(), versionApp: "1.4.0",
                                   date: date, identifiant: identifiant, vers: destination ?? bac.destination,
                                   mettreDeCote: misDeCote.mettre)
    }

    @Test func exportRelisibleEtFidele() throws {
        let bac = try Bac()
        try bac.ecrire("surnoms.json", #"{"0000000000000001":"Prise 1"}"#)
        try bac.ecrire("maillage-2026-10.jsonl", "{}\n{}\n")
        try bac.ecrire("Journal/journal-2026-10.jsonl", "{}\n")
        try bac.ecrire("inconnu.txt", "x")
        try bac.ecrire(".DS_Store", "x")
        try bac.ecrire("noms.illisible-20261001-120000.json", "x")
        let avant = try bac.contenu(bac.source)

        let m = try Self.exporter(bac)

        let (relu, reglages) = try ContratExport.verifierDossier(bac.destination)
        #expect(relu == m)
        #expect(reglages == Self.reglages())
        #expect(m.app == .maillageThread && m.versionApp == "1.4.0" && m.identifiant == Self.identifiant)
        #expect(m.date == Date(timeIntervalSince1970: 1_792_000_000))
        // Les copies dans l'ordre (tri par chemin), puis reglages.json, ecrit en dernier.
        #expect(m.fichiers.map(\.chemin) == ["Journal/journal-2026-10.jsonl", "maillage-2026-10.jsonl", "surnoms.json",
                                             "reglages.json"])
        #expect(m.fichiersNonRepris == [
            .init(chemin: ".DS_Store", raison: .exclu), .init(chemin: "inconnu.txt", raison: .horsContrat),
            .init(chemin: "noms.illisible-20261001-120000.json", raison: .exclu),
        ])
        let copie = try bac.contenu(bac.destination)
        for chemin in ["surnoms.json", "maillage-2026-10.jsonl", "Journal/journal-2026-10.jsonl"] {
            #expect(copie[chemin] == avant[chemin])
        }
        #expect(Set(copie.keys) == ["manifeste.json", "reglages.json", "surnoms.json", "maillage-2026-10.jsonl",
                                    "Journal/journal-2026-10.jsonl"])
        // L'export ne change rien dans le dossier de l'app.
        #expect(try bac.contenu(bac.source) == avant)
    }

    @Test func sansDossierDeLAppSeulsLesReglages() throws {
        let bac = try Bac()
        let m = try Self.exporter(bac)
        #expect(m.fichiers.map(\.chemin) == ["reglages.json"])
        #expect(m.fichiersNonRepris.isEmpty)
        _ = try ContratExport.verifierDossier(bac.destination)
    }

    /// Le manifeste et les reglages d'un ancien export laisses a la racine du dossier de l'app sont ecartes par le
    /// contrat : ni copies ni cites.
    @Test func nomsReservesALaRacineEcartes() throws {
        let bac = try Bac()
        try bac.ecrire("manifeste.json", "{}")
        try bac.ecrire("reglages.json", "{}")
        try bac.ecrire("surnoms.json", "{}")
        let m = try Self.exporter(bac)
        #expect(m.fichiers.map(\.chemin) == ["surnoms.json", "reglages.json"])
        #expect(m.fichiersNonRepris.isEmpty)
        _ = try ContratExport.verifierDossier(bac.destination)
    }

    /// Un lien symbolique n'est jamais suivi : il est cite (hors contrat), meme sous un nom connu.
    @Test func lienSymboliqueCiteJamaisSuivi() throws {
        let bac = try Bac()
        try bac.ecrire("cible.json", "{}")
        try FileManager.default.createSymbolicLink(at: bac.source.appendingPathComponent("surnoms.json"),
                                                   withDestinationURL: bac.source.appendingPathComponent("cible.json"))
        let m = try Self.exporter(bac)
        #expect(m.fichiers.map(\.chemin) == ["reglages.json"])
        #expect(m.fichiersNonRepris == [.init(chemin: "cible.json", raison: .horsContrat),
                                        .init(chemin: "surnoms.json", raison: .horsContrat)])
        _ = try ContratExport.verifierDossier(bac.destination)
    }

    /// Un dossier deja la a la destination n'est jamais touche, ni mis de cote : c'est a l'app de le mettre a la
    /// Corbeille avant.
    @Test func destinationExistanteRefusee() throws {
        let bac = try Bac()
        try FileManager.default.createDirectory(at: bac.destination, withIntermediateDirectories: true)
        try Data("garde".utf8).write(to: bac.destination.appendingPathComponent("a.txt"))
        let misDeCote = MisDeCote()
        #expect(throws: ExportReprise.Erreur.destinationExistante) { try Self.exporter(bac, misDeCote: misDeCote) }
        #expect(try bac.contenu(bac.destination) == ["a.txt": Data("garde".utf8)])
        #expect(misDeCote.urls.isEmpty)
    }

    /// Un echec apres la creation du dossier d'export le met de cote, lui seul ; le dossier de l'app reste intact.
    @Test func echecMetDeCoteLeDossierCommence() throws {
        let bac = try Bac()
        try bac.ecrire("associations.json", "{}")
        try bac.ecrire("surnoms.json", "{}")
        let illisible = bac.source.appendingPathComponent("surnoms.json")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: illisible.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: illisible.path) }
        let misDeCote = MisDeCote()
        #expect(throws: (any Error).self) { try Self.exporter(bac, misDeCote: misDeCote) }
        #expect(misDeCote.urls == [bac.destination])
        #expect(!FileManager.default.fileExists(atPath: bac.destination.path))
        #expect(FileManager.default.fileExists(atPath: illisible.path))
    }

    /// Une destination qui recouvre le dossier de l'app est refusee avant toute ecriture.
    @Test func destinationDansLeDossierDeLAppRefusee() throws {
        let bac = try Bac()
        try bac.ecrire("surnoms.json", "{}")
        for d in [bac.source, bac.source.appendingPathComponent("Export"), bac.racine] {
            #expect(throws: ExportReprise.Erreur.destinationDansLeDossierDeLApp) { try Self.exporter(bac, vers: d) }
        }
        #expect(try bac.contenu(bac.source).keys.sorted() == ["surnoms.json"])
    }

    /// Les liens nommes comme le manifeste ou les reglages a la racine sont ecartes, comme les fichiers.
    @Test func liensAuxNomsReservesEcartes() throws {
        let bac = try Bac()
        try bac.ecrire("cible.json", "{}")
        let cible = bac.source.appendingPathComponent("cible.json")
        for nom in ["reglages.json", "Manifeste.json"] {
            try FileManager.default.createSymbolicLink(at: bac.source.appendingPathComponent(nom), withDestinationURL: cible)
        }
        let m = try Self.exporter(bac)
        #expect(m.fichiersNonRepris == [.init(chemin: "cible.json", raison: .horsContrat)])
        _ = try ContratExport.verifierDossier(bac.destination)
    }

    /// Un fichier inconnu dans un sous-dossier est cite ; un lien vers un dossier est cite, jamais parcouru.
    @Test func sousDossierInconnuEtLienVersUnDossier() throws {
        let bac = try Bac()
        try bac.ecrire("Journal/sous/x.json", "{}")
        try bac.ecrire("Journal/journal-2026-10.jsonl", "{}\n")
        try FileManager.default.createSymbolicLink(at: bac.source.appendingPathComponent("lien"),
                                                   withDestinationURL: bac.source.appendingPathComponent("Journal"))
        let m = try Self.exporter(bac)
        #expect(m.fichiers.map(\.chemin) == ["Journal/journal-2026-10.jsonl", "reglages.json"])
        #expect(m.fichiersNonRepris == [.init(chemin: "Journal/sous/x.json", raison: .horsContrat),
                                        .init(chemin: "lien", raison: .horsContrat)])
    }

    /// Un mois purge par l'app pendant l'export : la copie echoue sur un fichier absent, et l'export le reconnait.
    @Test func fichierAbsentReconnu() throws {
        let bac = try Bac()
        try FileManager.default.createDirectory(at: bac.source, withIntermediateDirectories: true)
        do {
            try ExportReprise.copier(bac.source.appendingPathComponent("maillage-2026-04.jsonl"),
                                     vers: bac.racine.appendingPathComponent("copie"))
            Issue.record("la copie d'un fichier absent a reussi")
        } catch {
            #expect(ExportReprise.estAbsent(error))
        }
    }

    /// L'app ne met a la Corbeille qu'un ancien export ou un dossier vide.
    @Test func remplacementSeulementDUnAncienExportOuDUnDossierVide() throws {
        let bac = try Bac()
        let fm = FileManager.default
        func dossier(_ nom: String, _ fichiers: [String]) throws -> URL {
            let d = bac.racine.appendingPathComponent(nom)
            try fm.createDirectory(at: d, withIntermediateDirectories: true)
            for f in fichiers { try Data().write(to: d.appendingPathComponent(f)) }
            return d
        }
        #expect(ExportReprise.peutRemplacer(bac.racine.appendingPathComponent("absent")))
        #expect(ExportReprise.peutRemplacer(try dossier("vide", [])))
        #expect(ExportReprise.peutRemplacer(try dossier("finder", [".DS_Store"])))
        #expect(ExportReprise.peutRemplacer(try dossier("ancien", ["manifeste.json", "surnoms.json"])))
        #expect(!ExportReprise.peutRemplacer(try dossier("autre", ["photo.jpg"])))
        let fichier = bac.racine.appendingPathComponent("fichier")
        try Data().write(to: fichier)
        #expect(!ExportReprise.peutRemplacer(fichier))
    }

    @Test func nomParDefautDuDossier() {
        var c = DateComponents(year: 2026, month: 10, day: 7, hour: 23, minute: 30)
        c.timeZone = TimeZone(secondsFromGMT: -5 * 3600)
        let date = Calendar(identifier: .gregorian).date(from: c)!
        #expect(ExportReprise.nomDossier(app: .maillageThread, date: date, fuseau: TimeZone(secondsFromGMT: -5 * 3600)!)
                == "Export Maillage Thread 2026-10-07")
    }
}
