import Foundation
import Testing
@testable import MaillageCoeur

/// Le signal vu par la sonde, dans la fiche (polissage D, section 4.3) : le domaine et ses graduations, le releve sous
/// le pointeur, son etiquette, sans dependre de la langue ni du fuseau de la machine.
@Suite("Courbes : echelle et survol du signal")
struct EchelleSignalTests {
    /// Le domaine : un seul point (−67 donne −80 ... −60) ; des valeurs egales ; des valeurs etalees ; des valeurs deja
    /// sur une dizaine (−70 donne −80 ... −60, pas −70 ... −70). Toujours 10 dB au moins, et deux graduations au moins,
    /// sur les dizaines.
    @Test func domaine() throws {
        #expect(EchelleSignal.domaine([-67]) == -80 ... -60)
        #expect(EchelleSignal.domaine([-67, -67, -67]) == -80 ... -60)
        #expect(EchelleSignal.domaine([-91, -58]) == -100 ... -50)
        #expect(EchelleSignal.domaine([-70]) == -80 ... -60)
        #expect(EchelleSignal.domaine([-75]) == -80 ... -70, "a 5 dB d'une dizaine : elle-meme")
        #expect(EchelleSignal.domaine([-74.9]) == -80 ... -60)
        #expect(EchelleSignal.domaine([-65.1]) == -80 ... -60 && EchelleSignal.domaine([-64.9]) == -70 ... -50)
        #expect(EchelleSignal.domaine([]) == nil)
        #expect(EchelleSignal.graduations(-80 ... -60) == [-80, -70, -60])
        #expect(EchelleSignal.graduations(-100 ... -50) == [-100, -90, -80, -70, -60, -50])
        #expect(EchelleSignal.graduations(-80 ... -70) == [-80, -70])
        for v in stride(from: -100.0, through: -30, by: 0.7) {
            let d = try #require(EchelleSignal.domaine([v]))
            #expect(d.upperBound - d.lowerBound >= 10 && EchelleSignal.graduations(d).count >= 2 && d.contains(v), "\(v)")
        }
    }

    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    static func point(_ s: TimeInterval, _ v: Double = -67) -> PointCourbe {
        PointCourbe(date: t0.addingTimeInterval(s), valeur: v, troncon: 0)
    }

    /// Le releve sous le pointeur : le plus proche dans le temps ; a moins de 2 % de la periode, des deux cotes (sur
    /// 24 h, 1 728 s) ; au-dela, dans un trou, aucun ; sur 7 j, 2 % font 12 096 s.
    @Test func plusProche() {
        let points = [Self.point(0, -60), Self.point(600, -61), Self.point(9000, -62)]
        #expect(EchelleSignal.portee == 0.02)
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(200), periode: .jour) == points[0])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(400), periode: .jour) == points[1])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(-1727), periode: .jour) == points[0])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(-1729), periode: .jour) == nil)
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(600 + 1727), periode: .jour) == points[1])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(600 + 1729), periode: .jour) == nil, "un trou")
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(9000 - 1727), periode: .jour) == points[2])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(600 + 1729), periode: .semaine) == points[1])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(9000 + 12_095), periode: .semaine) == points[2])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(9000 + 12_097), periode: .semaine) == nil)
        #expect(EchelleSignal.plusProche([], de: Self.t0, periode: .mois) == nil)
    }

    /// L'etiquette, en francais et en anglais, a Paris : la valeur arrondie avec le vrai signe moins, puis l'heure ; en
    /// 7 j et 30 j, le jour aussi. Et sa place : a gauche du trait dans la moitie droite du graphe.
    @Test func etiquette() {
        let paris = TimeZone(identifier: "Europe/Paris")!
        let p = Self.point(0, -66.6)
        let fr = Locale(identifier: "fr_FR"), en = Locale(identifier: "en_US")
        #expect(EchelleSignal.etiquette(p, periode: .jour, locale: fr, fuseau: paris) == "\u{2212}67 dBm · 16:13")
        #expect(EchelleSignal.etiquette(p, periode: .jour, locale: en, fuseau: paris) == "\u{2212}67 dBm · 4:13\u{202F}PM")
        #expect(EchelleSignal.etiquette(p, periode: .semaine, locale: fr, fuseau: paris) == "\u{2212}67 dBm · 21 sept. à 16:13")
        #expect(EchelleSignal.etiquette(p, periode: .mois, locale: en, fuseau: paris) == "\u{2212}67 dBm · Sep 21 at 4:13\u{202F}PM")
        #expect(EchelleSignal.etiquette(Self.point(0, 3), periode: .jour, locale: fr, fuseau: paris) == "3 dBm · 16:13")
        let fin = Self.t0.addingTimeInterval(100)
        #expect(EchelleSignal.aGauche(Self.t0.addingTimeInterval(51), debut: Self.t0, fin: fin))
        #expect(!EchelleSignal.aGauche(Self.t0.addingTimeInterval(50), debut: Self.t0, fin: fin))
        #expect(!EchelleSignal.aGauche(Self.t0, debut: Self.t0, fin: Self.t0))
    }
}
