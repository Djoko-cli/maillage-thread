import Foundation
@testable import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Journal et historique de la sonde dans l'app")
struct JournalMaillageTests {
    /// Un appareil Matter du releve de la demo : son ExtMac est son nom d'hote.
    static let appareil = "56B1E064401F74EF"

    static func dossier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("maillage-\(UUID().uuidString)")
    }

    /// Mode direct sans ecoute, avec les 12 premiers releves de la panne rejouee (instantane,
    /// appareils) ; journal et historique dans `dossier`.
    static func surveillance(_ mode: Surveillance.Mode = .direct, dossier: URL?) -> Surveillance {
        let s = Surveillance(mode: mode, dossier: dossier)
        for a in ScenarioPanne.releves.prefix(12) { s.integrer(a) }
        return s
    }

    /// Maillage de la partition principale (valeurs inventees) : les routeurs 1 (chef) et 5, qui ne
    /// sont pas dans l'instantane ; l'appareil, enfant de `parent`.
    static func maillage(_ s: Surveillance, _ date: Date, parent: Int) throws -> Maillage {
        var c = ConstructionMaillage(date: date, partition: try #require(s.reseau?.principale?.id))
        c.routeurs(Route64(sequence: 1, routes: [1, 5].map { RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1) }),
                   chef: 1)
        c.lien(1, 5, sortante: 3, entrante: 2)
        c.enfant(EnfantMaillage(rloc16: UInt16(parent) << 10 | 2, extMac: Self.appareil, qualite: 3, source: .tableEnfants))
        c.signal(SignalSonde(routeur: 1, rssi: -61))
        return c.maillage()
    }

    /// Changement de parent de l'appareil : au journal (en memoire et sur disque), sous son id et son
    /// nom du graphe, avec le nom des deux routeurs ; chaque tournee a son releve dans
    /// `maillage-AAAA-MM.jsonl`, relu par un nouveau lancement.
    @Test func journalEtHistoriqueSurDisque() async throws {
        let dossier = Self.dossier()
        defer { try? FileManager.default.removeItem(at: dossier) }
        let s = Self.surveillance(dossier: dossier)
        // Des secondes entieres : le fichier garde les dates a la milliseconde.
        let t = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down) - 600)
        s.recevoir(try Self.maillage(s, t, parent: 1), a: t.addingTimeInterval(1))
        s.recevoir(try Self.maillage(s, t.addingTimeInterval(300), parent: 5), a: t.addingTimeInterval(301))
        let e = try #require(s.evenements.last)
        #expect(e.type == .parentChange)
        let a = try #require(s.appareil(Self.appareil))
        #expect(e.sujet == Sujet(id: Self.appareil, nom: s.nom(a)))
        #expect(e.avant == String(localized: "Routeur · \("0400")") && e.apres == String(localized: "Routeur · \("1400")"))
        #expect(try JournalFichiers(dossier: dossier.appendingPathComponent("Journal")).lire().last == e)
        #expect(s.historique.map(\.date) == [t, t.addingTimeInterval(300)])
        let fichier = dossier.appendingPathComponent(HistoriqueFichiers(dossier: dossier).nomFichier(t.addingTimeInterval(300)))
        #expect(FileManager.default.fileExists(atPath: fichier.path))
        let relu = Surveillance(mode: .direct, dossier: dossier)
        await relu.chargerHistorique()
        #expect(relu.historique == s.historique)
    }

    /// Appareil vu deux fois (le balayage ancien d'un routeur muet, et la table de son nouveau
    /// parent) : le journal le nomme comme l'appareil, sous son nouveau parent, meme si le graphe
    /// donne son id a l'entree du balayage (le premier RLOC16).
    @Test func appareilVuDeuxFois() throws {
        let s = Self.surveillance(dossier: nil)
        let t = Date()
        s.recevoir(try Self.maillage(s, t, parent: 1), a: t)
        var c = ConstructionMaillage(date: t.addingTimeInterval(300), partition: try #require(s.reseau?.principale?.id))
        c.routeurs(Route64(sequence: 1, routes: [1, 5].map { RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1) }),
                   chef: 1)
        c.muet(1)
        c.enfant(EnfantMaillage(rloc16: 0x0405, extMac: Self.appareil, source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x1402, extMac: Self.appareil, qualite: 2, source: .tableEnfants))
        s.recevoir(c.maillage(), a: t.addingTimeInterval(300))
        let e = try #require(s.evenements.last)
        #expect(e.type == .parentChange && e.sujet?.id == Self.appareil)
        #expect(e.apres == String(localized: "Routeur · \("1400")"))
    }

    /// Demo : ni releve en memoire, ni fichier, meme avec un dossier ; le journal du maillage reste
    /// en memoire. Direct sans dossier : l'historique en memoire seulement.
    @Test func rienSurDisqueEnDemo() throws {
        let dossier = Self.dossier()
        defer { try? FileManager.default.removeItem(at: dossier) }
        let demo = Self.surveillance(.demo, dossier: dossier)
        let t = Date()
        demo.recevoir(try Self.maillage(demo, t, parent: 1), a: t)
        demo.recevoir(try Self.maillage(demo, t.addingTimeInterval(300), parent: 5), a: t.addingTimeInterval(300))
        #expect(demo.historique.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: dossier.path))
        #expect(demo.evenements.last?.type == .parentChange)
        let memoire = Self.surveillance(dossier: nil)
        memoire.recevoir(try Self.maillage(memoire, t, parent: 1), a: t)
        #expect(memoire.historique.count == 1)
    }

    /// Sonde oubliee : le maillage suivant est un point de depart (pas de « a change de parent »
    /// calcule par-dessus l'oubli) ; l'historique en memoire reste.
    @Test func oubliRepartDeZero() throws {
        let s = Self.surveillance(dossier: nil)
        let t = Date()
        s.recevoir(try Self.maillage(s, t, parent: 1), a: t)
        s.oublierMaillage()
        let avant = s.evenements.count
        s.recevoir(try Self.maillage(s, t.addingTimeInterval(300), parent: 5), a: t.addingTimeInterval(300))
        #expect(s.evenements.count == avant, "point de depart")
        #expect(s.historique.count == 2)
    }

    /// L'historique en memoire garde 30 jours, comptes depuis la reception du dernier maillage.
    @Test func trenteJoursEnMemoire() throws {
        let s = Self.surveillance(dossier: nil)
        let t = Date()
        let vieux = t.addingTimeInterval(-Surveillance.dureeHistorique - 60)
        s.recevoir(try Self.maillage(s, vieux, parent: 1), a: vieux)
        s.recevoir(try Self.maillage(s, t, parent: 1), a: t)
        #expect(s.historique.map(\.date) == [t])
    }
}
