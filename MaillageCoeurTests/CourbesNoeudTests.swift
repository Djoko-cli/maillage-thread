import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Courbes d'un noeud tirees de l'historique")
struct CourbesNoeudTests {
    /// Debut d'un pas de 30 min et de 2 h.
    static let t0 = Date(timeIntervalSince1970: 1_790_006_400)
    static let a0 = "E0000000000000A0"
    static let a1 = "E0000000000000A1"
    static let b1 = "E0000000000000B1"

    /// Releve a `minutes` de t0 (valeurs inventees) : les routeurs 0 (a0) et 1 (sans ExtMac si
    /// `sansExt1`, sinon a1) et leur lien, de qualite `q` de 0 vers 1 et 3 de 1 vers 0 ; l'enfant
    /// b1 sous `parent` ; la sonde sous `parentSonde`, qui entend le routeur 0 a `rssi`.
    static func releve(_ minutes: Double, q: Int = 3, parent: Int = 0, qualiteEnfant: Int? = 3, parentSonde: Int = 0,
                       rssi: Int = -60, sansExt1: Bool = false) -> ReleveMaillage {
        ReleveMaillage(date: t0.addingTimeInterval(minutes * 60), partition: "0000000A",
                       routeurs: [.init(id: 0, extMac: a0), .init(id: 1, extMac: sansExt1 ? nil : a1)],
                       liens: [LienRadio(a: 0, b: 1, qualiteAB: q, qualiteBA: 3)],
                       enfants: [.init(extMac: b1, parent: parent, qualite: qualiteEnfant)],
                       signaux: [SignalSonde(routeur: 0, rssi: rssi)], parentSonde: parentSonde)
    }

    static func minutes(_ m: Double) -> Date { t0.addingTimeInterval(m * 60) }

    /// Routeur : la qualite de son lien avec chaque voisin (la moins bonne des deux sens) et le
    /// signal que la sonde en recoit, a chaque releve de la periode.
    @Test func routeur() {
        let releves = [Self.releve(0, q: 3, rssi: -60), Self.releve(5, q: 2, rssi: -65), Self.releve(10, q: 1, rssi: -70)]
        let c = CourbesNoeud(cle: Self.a0, releves: releves, periode: .jour, fin: Self.minutes(15))
        #expect(c.liens == [CourbeLien(id: Self.a1, points: [PointCourbe(date: Self.minutes(0), valeur: 3, troncon: 0),
                                                             PointCourbe(date: Self.minutes(5), valeur: 2, troncon: 0),
                                                             PointCourbe(date: Self.minutes(10), valeur: 1, troncon: 0)])])
        #expect(c.signal.map(\.valeur) == [-60, -65, -70])
        #expect(c.parents.isEmpty)
        #expect(c.debut == Self.minutes(15).addingTimeInterval(-24 * 3600))
        #expect(CourbesNoeud(cle: Self.a1, releves: releves, periode: .jour, fin: Self.minutes(15)).signal.isEmpty,
                "la sonde n'entend pas le routeur 1")
    }

    /// Enfant : la qualite du lien vers son parent, quel qu'il soit (inconnue sous un routeur muet :
    /// pas de point), et ses changements de parent, a la date du premier releve sous le nouveau.
    @Test func enfant() {
        let releves = [Self.releve(0), Self.releve(5), Self.releve(10, parent: 1, qualiteEnfant: 2),
                       Self.releve(15, parent: 1, qualiteEnfant: nil)]
        let c = CourbesNoeud(cle: Self.b1, releves: releves, periode: .jour, fin: Self.minutes(20))
        #expect(c.liens.map(\.id) == [CourbesNoeud.cleParent])
        #expect(c.liens.first?.points.map(\.valeur) == [3, 3, 2])
        #expect(c.parents == [ChangementParent(date: Self.minutes(10), parent: Self.a1)])
        #expect(c.signal.isEmpty)
        #expect(!c.estVide)
        #expect(CourbesNoeud(cle: "E0000000000000FF", releves: releves, periode: .jour, fin: Self.minutes(20)).estVide)
    }

    /// Changements de parent de la sonde (sur la courbe du signal d'un routeur) ; un routeur sans
    /// ExtMac se suit par son RLOC16.
    @Test func sondeEtRouteurSansExtMac() {
        let releves = [Self.releve(0, parentSonde: 0, sansExt1: true), Self.releve(5, parentSonde: 0, sansExt1: true),
                       Self.releve(10, parentSonde: 1, sansExt1: true)]
        let c = CourbesNoeud(cle: Self.a0, releves: releves, periode: .jour, fin: Self.minutes(15))
        #expect(c.parentsSonde == [ChangementParent(date: Self.minutes(10), parent: "rloc:0400")])
        #expect(c.liens.map(\.id) == ["rloc:0400"])
        let r1 = CourbesNoeud(cle: "rloc:0400", releves: releves, periode: .jour, fin: Self.minutes(15))
        #expect(r1.liens.map(\.id) == [Self.a0])
    }

    /// 7 j : la moyenne de chaque pas de 30 min ; un trou de plus de trois pas ouvre un troncon.
    /// 24 h : chaque releve ; un trou de plus de 20 min ouvre un troncon. Hors periode : rien.
    @Test func pasEtTroncons() {
        let semaine = [0.0, 5, 10, 15, 20, 25].enumerated().map { Self.releve($1, q: $0 < 3 ? 3 : 2) }
            + [Self.releve(210, q: 3)]
        let c = CourbesNoeud(cle: Self.a0, releves: semaine, periode: .semaine, fin: Self.minutes(240))
        #expect(c.liens.first?.points == [PointCourbe(date: Self.minutes(0), valeur: 2.5, troncon: 0),
                                          PointCourbe(date: Self.minutes(210), valeur: 3, troncon: 1)])
        let jour = [Self.releve(0), Self.releve(5), Self.releve(30), Self.releve(35)]
        let d = CourbesNoeud(cle: Self.a0, releves: jour, periode: .jour, fin: Self.minutes(40))
        #expect(d.signal.map(\.troncon) == [0, 0, 1, 1])
        let tard = CourbesNoeud(cle: Self.a0, releves: jour, periode: .jour, fin: Self.minutes(20 + 24 * 60))
        #expect(tard.signal.map(\.date) == [Self.minutes(30), Self.minutes(35)], "24 h avant la fin")
    }
}
