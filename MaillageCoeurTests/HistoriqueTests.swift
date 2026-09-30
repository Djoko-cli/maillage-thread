import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Historique du maillage : releves et fichiers mensuels")
struct HistoriqueTests {
    static func date(_ texte: String) -> Date {
        try! Date(texte, strategy: .iso8601)
    }

    static func dossier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("historique-\(UUID().uuidString)")
    }

    /// Petit maillage (valeurs inventees) : le chef 0 et le routeur 1, muet, sans ExtMac ; la sonde
    /// 0001 sous 0 ; un enfant balaye sous 1 ; un enfant de table sans ExtMac ; deux signaux.
    static func maillage(_ date: Date) -> Maillage {
        var c = ConstructionMaillage(date: date, partition: "0000000A")
        c.routeurs(Route64(sequence: 1, routes: [RouteRouteur(idRouteur: 0, qualiteSortante: 3, qualiteEntrante: 2, cout: 1),
                                                 RouteRouteur(idRouteur: 1, qualiteSortante: 0, qualiteEntrante: 0, cout: 1)]),
                   chef: 0)
        c.identite("E0000000000000A0", routeur: 0)
        c.muet(1)
        c.lien(0, 1, sortante: 3, entrante: 2)
        c.enfant(EnfantMaillage(rloc16: 0x0001, extMac: "E0000000000000B1", qualite: 3, source: .sonde))
        c.enfant(EnfantMaillage(rloc16: 0x0402, extMac: "E0000000000000B2", source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x0003, qualite: 2, source: .tableEnfants))
        c.signal(SignalSonde(routeur: 0, rssi: -60))
        c.signal(SignalSonde(routeur: 1, rssi: -75))
        return c.maillage()
    }

    /// Une ligne par tournee, en tableaux : routeurs, liens, enfants identifies (pas celui sans
    /// ExtMac), signaux, parent de la sonde. Relue a l'identique.
    @Test func ligneDUnReleve() throws {
        let r = ReleveMaillage(Self.maillage(Self.date("2026-09-30T10:00:00Z")))
        let json = String(decoding: try CodageJSON.encodeur().encode(r), as: UTF8.self)
        #expect(json == #"{"date":"2026-09-30T10:00:00.000Z","enfants":[["E0000000000000B1",0,3],["E0000000000000B2",1,null]],"liens":[[0,1,3,2]],"parentSonde":0,"partition":"0000000A","routeurs":[[0,"E0000000000000A0"],[1,null]],"signaux":[[0,-60],[1,-75]]}"#)
        #expect(try CodageJSON.decodeur().decode(ReleveMaillage.self, from: Data(json.utf8)) == r)
        #expect(r.cle(routeur: 0) == "E0000000000000A0")
        #expect(r.cle(routeur: 1) == "rloc:0400", "sans ExtMac : son RLOC16")
    }

    /// Un enfant vu deux fois (il a change de parent) : l'entree fraiche (table d'un routeur qui
    /// repond) passe avant celle du balayage d'un routeur muet, qui peut dater de 30 minutes.
    @Test func enfantVuDeuxFois() {
        var c = ConstructionMaillage(date: Self.date("2026-09-30T10:00:00Z"), partition: "0000000A")
        c.enfant(EnfantMaillage(rloc16: 0x0402, extMac: "E0000000000000B2", source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x0805, extMac: "E0000000000000B2", qualite: 2, source: .tableEnfants))
        let m = c.maillage()
        #expect(m.enfantsIdentifies["E0000000000000B2"]?.parent == 2)
        #expect(ReleveMaillage(m).enfants == [ReleveMaillage.Enfant(extMac: "E0000000000000B2", parent: 2, qualite: 2)])
    }

    /// Tournee de la capture, avec des voisins : 7 routeurs et 10 enfants identifies tiennent en
    /// moins de 700 octets ; avec 20 enfants (26 octets chacun), en moins de 1 Ko.
    @Test func tailleDUneLigne() async throws {
        let voisins = [VoisinSonde(rloc16: "E400", ext: "E0000000000000E4", rssi: -72, lqi: 3, routeur: true),
                       VoisinSonde(rloc16: "CC00", ext: "E0000000000000CC", rssi: -80, lqi: 3, routeur: true)]
        let (m, _) = try #require(try await Tournee.complete(try SondeRejouee.capture(voisins: voisins),
                                                               memoire: MemoireTournee(), maintenant: Self.date("2026-09-30T10:00:00Z")))
        let r = ReleveMaillage(m)
        #expect(r.routeurs.count == 7 && r.liens.count == 7)
        #expect(r.enfants.count == 10, "balayes sous AC00, et les enfants des tables qui ont donne leur identite")
        let octets = try CodageJSON.encodeur().encode(r).count
        #expect(octets < 700, "\(octets) octets")
        var vingt = r.enfants
        for n in 0..<10 { vingt.append(ReleveMaillage.Enfant(extMac: String(format: "E0000000000001%02X", n), parent: 24, qualite: 3)) }
        let grand = ReleveMaillage(date: r.date, partition: r.partition, routeurs: r.routeurs, liens: r.liens, enfants: vingt,
                                   signaux: r.signaux, parentSonde: r.parentSonde)
        #expect(try CodageJSON.encodeur().encode(grand).count < 1024)
    }

    /// Fichiers `maillage-AAAA-MM.jsonl` du dossier de l'app : un releve par ligne, au mois de sa
    /// date (calendrier local) ; relus depuis une date, du plus ancien au plus recent, sans ligne
    /// illisible ; purges 90 jours apres la fin de leur mois ; les autres fichiers du dossier (le
    /// journal, les identites) ne sont ni lus ni purges.
    @Test func fichiersMensuels() throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        let h = HistoriqueFichiers(dossier: d, calendrier: JournalTests.calendrier)
        #expect(try h.lire(depuis: .distantPast).isEmpty, "dossier absent")
        let septembre = ReleveMaillage(Self.maillage(Self.date("2026-09-20T10:00:00Z")))
        let fin = ReleveMaillage(Self.maillage(Self.date("2026-09-30T21:00:00Z")))
        let octobre = ReleveMaillage(Self.maillage(Self.date("2026-10-02T10:00:00Z")))
        for r in [fin, septembre, octobre] { try h.ajouter(r) }
        let f = try FileHandle(forWritingTo: d.appendingPathComponent("maillage-2026-09.jsonl"))
        try f.seekToEnd()
        try f.write(contentsOf: Data("{pas du json\n".utf8))
        try f.close()
        try JournalFichiers(dossier: d, calendrier: JournalTests.calendrier)
            .ajouter([Evenement(date: Self.date("2026-09-10T00:00:00Z"), type: .veille)])
        try Data("{}".utf8).write(to: d.appendingPathComponent("identites-routeurs.json"))
        // 30/09 21:00 UTC = 01/10 01:00 a Asia/Tbilisi : fichier d'octobre.
        #expect(h.nomFichier(fin.date) == "maillage-2026-10.jsonl")
        #expect(try h.lire(depuis: .distantPast) == [septembre, fin, octobre])
        #expect(try h.lire(depuis: Self.date("2026-09-25T00:00:00Z")) == [fin, octobre])
        let supprimes = try h.purger(maintenant: Self.date("2027-01-05T12:00:00Z"))
        #expect(supprimes == ["maillage-2026-09.jsonl"], "septembre fini depuis 96 jours ; le journal reste")
        #expect(try h.lire(depuis: .distantPast) == [fin, octobre])
        let restants = try FileManager.default.contentsOfDirectory(atPath: d.path).sorted()
        #expect(restants == ["identites-routeurs.json", "journal-2026-09.jsonl", "maillage-2026-10.jsonl"])
    }
}
