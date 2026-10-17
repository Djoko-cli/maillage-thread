import Foundation
import Testing
@testable import MaillageCoeur

/// L'export d'exemple anonymise (spec de Maillage IoT, section 4.1) : `docs/export-exemple/`, recopie dans les tests de
/// Maillage IoT. Un dossier de l'app invente, ecrit par les vrais ecrivains du coeur (ceux de l'app pour le dernier
/// maillage et les dernieres adresses, dont le format est prive : meme forme ici, relue par l'app dans
/// `ExportExempleLisibleTests`), avec au moins un exemplaire de chaque fichier et de chaque reglage repris, et un
/// historique et un journal d'avril 2026 (plus de 90 jours avant l'export). Valeurs inventees seulement, cles
/// comprises. Fichier absent : le test l'ecrit et echoue une fois ; le controler (controle d'anonymisation), puis
/// relancer.
@Suite("Export d'exemple pour Maillage IoT")
struct ExportExempleTests {
    static let dossier = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // MaillageCoeurTests
        .deletingLastPathComponent()  // racine du depot
        .appendingPathComponent("docs/export-exemple")

    static let fuseau = TimeZone(secondsFromGMT: 3600)!
    static var calendrier: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = fuseau
        return c
    }

    /// Une date en UTC.
    static func date(_ a: Int, _ m: Int, _ j: Int, _ h: Int, _ min: Int = 0) -> Date {
        var c = DateComponents(year: a, month: m, day: j, hour: h, minute: min)
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    static let dateExport = date(2026, 10, 17, 12)
    static let identifiant = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    static let partition = "0000000A"
    static let domicile = "Maison 1"

    /// Deux routeurs de bordure et trois appareils, sur la partition `0000000A`.
    static func instantane() -> Instantane {
        var b = Banc(date: date(2026, 10, 16, 8))
        b.locaux = ["fd00:0:0:1::/64"]
        for (k, xa) in ["0000000000000001", "0000000000000003"].enumerated() {
            b.routeur("Routeur \(k + 1)", partition: partition, primaire: k == 0, lien: "fe80::\(k + 1)",
                      omr: "fd00:0:0:1::/64", xp: "0000000000000000", nn: "Reseau-1", xa: xa)
        }
        for (k, id) in ["0000000000000002", "0000000000000004", "0000000000000005"].enumerated() {
            b.appareil(id, noeud: k + 1, fabriques: ["0000000000000F01"], adresses: ["fd00:0:0:1::\(k + 2)"])
        }
        return Instantane(annonces: b.annonces)
    }

    /// Le dernier maillage garde (`dernier-maillage.json` de l'app) : sa forme.
    struct MaillageGarde: Codable {
        var maillage: Maillage
        var recu: Date
    }

    /// Les dernieres adresses gardees (`dernieres-adresses.json` de l'app) : leur forme.
    struct AdressesGardees: Codable {
        var appareils: [String: Suivi.AdresseGardee]
    }

    /// Le domaine des UserDefaults de l'app : chaque reglage repris, et des cles hors contrat.
    static func domaine() -> [String: Any] { [
        "sondeSerieUSB": "00:00:00:00:00:01", "sondeNom": "SONDE-T1", "sondeHote": "sonde-t1", "sondeLiaison": "reseau",
        "scissionsNotifiees": ["0000000B"],
        "notification.scission": false, "notification.routeurDisparu": true, "notification.pertes": false,
        "notification.informations": true,
        "vuePieces3D": true, "etagesEnGrille": false, "legendeRepliee": true, "grapheDejaOuvert": true,
        "ouvertureSessionProposee": true, "AppleLanguages": ["fr"],
        // Hors contrat : Sparkle, fenetres, onglet des reglages, ancien dossier des noms.
        "SUHasLaunchedBefore": true, "SULastCheckTime": date(2026, 10, 16, 6), "reglages.onglet": "maison",
        "dossierNoms": Data([0x00, 0x01]), "NSWindow Frame graphe": "0 0 1100 760 0 0 1920 1080 ",
    ] }

    /// Ecrit le dossier de l'app invente dans `source`.
    static func ecrireSource(_ source: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        func url(_ nom: String) -> URL { source.appendingPathComponent(nom) }

        // Surnoms : chaque forme de cle (instance de routeur de bordure, appareil, `instance:`, `rloc:`).
        try Surnoms.ecrire(["Routeur 1": "Routeur A", "0000000000000002": "Prise 1", "instance:Routeur 2": "Routeur B",
                            "rloc:1400": "Routeur C"], dans: url("surnoms.json"))
        try Associations.ecrire(["0000000000000004": "00000000000000AA"], dans: url("associations.json"))
        try IdentitesGardees(partition: partition, identites: [0x0400: "0000000000000001", 0x1400: "0000000000000003"])
            .ecrire(dans: url("identites-routeurs.json"))

        let i = instantane()
        let m = try #require(MaillageDemo.maillage(i, date: date(2026, 10, 16, 8)))
        try CodageJSON.encodeur().encode(MaillageGarde(maillage: m, recu: date(2026, 10, 16, 8)))
            .write(to: url("dernier-maillage.json"))
        let adresse = try #require(AdresseIPv6("fd00:0:0:1::2"))
        try CodageJSON.encodeur().encode(AdressesGardees(appareils: [
            "0000000000000002": Suivi.AdresseGardee(adresse: adresse, partition: partition, annonce: date(2026, 10, 16, 8)),
        ])).write(to: url("dernieres-adresses.json"))

        let maison = NomsMaison(date: date(2026, 10, 16, 7), domicile: domicile, accessoires: [
            AccessoireMaison(nom: "Prise 1", piece: "Pièce 1", fabricant: "Fabricant 1", modele: "Modèle 1",
                             firmware: "1.0", categorie: "prise", noeudMatter: "0000000000000001",
                             batterie: nil, id: "00000000-0000-4000-8000-0000000000A1"),
            AccessoireMaison(nom: "Détecteur 1", piece: "Pièce 2", modele: "Modèle 2", noeudMatter: "00000000000000AA",
                             batterie: BatterieMaison(niveau: 80, charge: nil, alerte: false),
                             id: "00000000-0000-4000-8000-0000000000A2"),
            AccessoireMaison(nom: "Pont 1", piece: "Pièce 1", pont: true, id: "00000000-0000-4000-8000-0000000000A3"),
        ], zones: [ZoneMaison(nom: "Étage 1", pieces: ["Pièce 1", "Pièce 2"])])
        try maison.donnees().write(to: url("noms.json"))

        var pieces = PiecesRouteurs()
        pieces.choisir("Pièce 1", routeur: "Routeur 1", domicile: domicile)
        pieces.choisir("Pièce 2", appareil: "0000000000000002", domicile: domicile)
        try pieces.ecrire(dans: url("pieces-routeurs.json"))

        var places = PlacesGardees()
        places.garder(SIMD2(1.5, -2), piece: "piece:Pièce 1", etage: "zone:Étage 1", domicile: domicile)
        places.garder(SIMD2(-3, 0.5), piece: "piece:Pièce 2", etage: "zone:Étage 1", domicile: domicile)
        places.ordonner(["zone:Étage 1", "zone:Jardin"], domicile: domicile)
        places.maisons[domicile]?.aCote["zone:Jardin"] = PlacesGardees.ACote(etage: "zone:Étage 1", dehors: true)
        try places.ecrire(dans: url("positions-pieces.json"))

        // Historique : octobre (deux releves) et avril (plus de 90 jours avant l'export), groupes par le calendrier
        // de l'app (ici un fuseau invente, une heure apres UTC).
        let historique = HistoriqueFichiers(dossier: source, calendrier: calendrier)
        for d in [date(2026, 4, 10, 8), date(2026, 10, 15, 8), date(2026, 10, 16, 8)] {
            try historique.ajouter(ReleveMaillage(try #require(MaillageDemo.maillage(i, date: d))))
        }
        let journal = JournalFichiers(dossier: source.appendingPathComponent("Journal"), calendrier: calendrier)
        try journal.ajouter([
            Evenement(date: date(2026, 4, 10, 7), type: .surveillanceDemarree, constate: true),
            Evenement(date: date(2026, 10, 15, 7, 59), type: .surveillanceDemarree, constate: true),
            Evenement(date: date(2026, 10, 15, 8, 5), type: .appareilNouveau, reseau: "0000000000000000",
                      sujet: Sujet(id: "0000000000000002", nom: "Prise 1"), details: ["partition": partition]),
            Evenement(date: date(2026, 10, 16, 9), type: .routeurDisparu, reseau: "0000000000000000",
                      sujet: Sujet(id: "Routeur 2", nom: "Routeur B")),
        ])
    }

    /// Le dossier de l'app invente, exporte dans un dossier temporaire neuf : ses fichiers, par chemin relatif.
    static func exporter() throws -> [String: Data] {
        let racine = FileManager.default.temporaryDirectory.appendingPathComponent("export-exemple-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: racine) }
        let source = racine.appendingPathComponent("Maillage Thread")
        try ecrireSource(source)
        // Cites sans etre copies : `.DS_Store` et un fichier mis de cote (exclus), un fichier inconnu (hors contrat).
        for nom in [".DS_Store", "noms.illisible-20261001-120000.json", "inconnu.json"] {
            try Data("{}".utf8).write(to: source.appendingPathComponent(nom))
        }
        let destination = racine.appendingPathComponent("export")
        _ = try ExportReprise.exporter(app: .maillageThread, source: source,
                                       reglages: ContratExport.reglages(depuis: domaine(), app: .maillageThread),
                                       versionApp: "1.4.0", date: dateExport, identifiant: identifiant,
                                       vers: destination)
        return try contenu(destination)
    }

    static func contenu(_ dossier: URL) throws -> [String: Data] {
        let base = dossier.resolvingSymlinksInPath().standardizedFileURL
        var vus: [String: Data] = [:]
        let e = try #require(FileManager.default.enumerator(at: base, includingPropertiesForKeys: [.isRegularFileKey]))
        for case let url as URL in e where (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true {
            vus[String(url.standardizedFileURL.path.dropFirst(base.path.count + 1))] = try Data(contentsOf: url)
        }
        return vus
    }

    /// Deux exports de suite donnent les memes octets : l'exemple ne depend ni de l'heure ni d'un ordre de hasard.
    @Test func stable() throws {
        #expect(try Self.exporter() == Self.exporter())
    }

    /// L'exemple couvre tout l'inventaire : chaque fichier connu, chaque reglage repris, un mois de plus de 90 jours.
    @Test func couvreLInventaire() throws {
        let fichiers = try Self.exporter()
        for connu in ContratExport.fichiersConnus(de: .maillageThread) {
            #expect(fichiers.keys.contains { connu.correspond($0) }, "fichier absent de l'exemple : \(connu.modele)")
        }
        let (_, reglages) = try ContratExport.verifierDossierDonnees(fichiers)
        for r in ContratExport.reglagesConnus(de: .maillageThread) {
            #expect(reglages.valeurs[r.cle]?.type == r.type, "reglage absent de l'exemple : \(r.cle)")
        }
        let limite = ContratExport.Mois(annee: 2026, mois: 7)
        for prefixe in ["maillage-", "Journal/journal-"] {
            #expect(fichiers.keys.contains { $0.hasPrefix(prefixe) && (ContratExport.mois(de: $0).map { $0 < limite } ?? false) })
        }
    }

    /// Aucune valeur qui ressemble a une donnee reelle : seulement des formes inventees reconnaissables (identifiants
    /// de 16 chiffres hexadecimaux commencant par 13 zeros, ou `E` puis 13 zeros ; adresses `fd00:` et `fe80::<n>` ;
    /// adresses MAC `00:00:00:00:00:` ; aucun chemin `/Users/`).
    @Test func anonyme() throws {
        let texte = try Self.exporter().values.map { String(decoding: $0, as: UTF8.self) }.joined(separator: "\n")
        func tous(_ motif: String) throws -> [String] {
            let r = try NSRegularExpression(pattern: motif)
            return r.matches(in: texte, range: NSRange(texte.startIndex..., in: texte)).compactMap {
                Range($0.range, in: texte).map { String(texte[$0]) }
            }
        }
        #expect(try tous(#"(?<![0-9A-Fa-f])[0-9A-Fa-f]{16}(?![0-9A-Fa-f])"#)
            .filter { !$0.hasPrefix("0000000000000") && !$0.uppercased().hasPrefix("E0000000000000") } == [])
        // Au moins trois deux-points : une heure (`08:00:00`) n'en a que deux.
        #expect(try tous(#"(?i)\b[0-9a-f]{0,4}(:[0-9a-f]{0,4}){3,7}\b"#)
            .filter { !$0.lowercased().hasPrefix("fd00:") && !$0.hasPrefix("00:00:00:00:00:") } == [])
        #expect(try tous(#"(?i)fe80::[0-9a-f:]*"#).filter { $0.count > 8 } == [])
        #expect(!texte.contains("/Users/"))
    }

    @Test func egalALExempleDuDepot() throws {
        let calcule = try Self.exporter()
        guard FileManager.default.fileExists(atPath: Self.dossier.path) else {
            for (chemin, donnees) in calcule {
                let url = Self.dossier.appendingPathComponent(chemin)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try donnees.write(to: url)
            }
            Issue.record("export d'exemple absent : ecrit dans docs/export-exemple ; le controler, puis relancer")
            return
        }
        let garde = try Self.contenu(Self.dossier).filter { !$0.key.hasSuffix(".DS_Store") }
        #expect(Set(calcule.keys) == Set(garde.keys), "fichiers differents de docs/export-exemple")
        for (chemin, donnees) in calcule {
            #expect(garde[chemin] == donnees, "l'export d'exemple a change : \(chemin)")
        }
        _ = try ContratExport.verifierDossier(Self.dossier)
    }
}

extension ContratExport {
    /// `verifierDossier` sur des fichiers en memoire : ecrits dans un dossier temporaire, relus, effaces.
    static func verifierDossierDonnees(_ fichiers: [String: Data]) throws -> (Manifeste, Reglages) {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("verifier-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dossier) }
        for (chemin, donnees) in fichiers {
            let url = dossier.appendingPathComponent(chemin)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try donnees.write(to: url)
        }
        return try verifierDossier(dossier)
    }
}
