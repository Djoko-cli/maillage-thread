import AppKit
import Foundation
@testable import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Courbes de l'historique dans la fiche")
struct CourbesFicheTests {
    /// Deux tournees (`JournalMaillageTests`) : l'appareil passe du routeur 1 au routeur 5.
    static func surveillance() throws -> Surveillance {
        let s = JournalMaillageTests.surveillance(dossier: nil)
        let t = Date().addingTimeInterval(-600)
        s.recevoir(try JournalMaillageTests.maillage(s, t, parent: 1), a: t)
        s.recevoir(try JournalMaillageTests.maillage(s, t.addingTimeInterval(300), parent: 5), a: t.addingTimeInterval(300))
        return s
    }

    /// Cle d'un noeud dans l'historique : l'ExtMac d'un appareil (son hote), "rloc:0400" pour un
    /// routeur sans ExtMac, le `xa` d'un routeur de bordure de l'instantane ; et le nom d'une cle.
    @Test func clesEtNoms() throws {
        let s = try Self.surveillance()
        let id = JournalMaillageTests.appareil
        #expect(s.cleHistorique(noeud: id) == id)
        #expect(s.cleHistorique(noeud: "rloc:0400") == "rloc:0400")
        let br = try #require(s.instantane?.routeurs.first { $0.adresseEtendue != nil })
        #expect(s.cleHistorique(noeud: br.instance) == br.adresseEtendue)
        #expect(s.cleHistorique(noeud: "instance:inconnue") == nil)
        #expect(s.cleHistorique(noeud: "ＤＥＡＤＢＥＥＦ00000001") == nil, "hexadecimaux pleine chasse : pas une ExtMac")
        let xa = try #require(br.adresseEtendue)
        let noms = s.nomsHistorique([id, "rloc:1400", xa, "E0000000000000FF"])
        #expect(noms[id] == s.nom(try #require(s.appareil(id))))
        #expect(noms["rloc:1400"] == String(localized: "Routeur · \("1400")"))
        #expect(noms[xa] == s.nom(br))
        #expect(noms["E0000000000000FF"] == "E0000000000000FF", "inconnue : la cle")
        #expect(CourbesFiche.nomLien(CourbesNoeud.cleParent, noms) == String(localized: "Parent"))
    }

    /// Courbes de l'appareil : la qualite vers son parent et son changement de parent ; du
    /// routeur 1 (sans ExtMac) : son lien avec le 5, et le signal vu par la sonde.
    @Test func courbes() throws {
        let s = try Self.surveillance()
        let c = try #require(s.courbes(noeud: JournalMaillageTests.appareil, periode: .jour, fin: Date()))
        #expect(c.liens.map(\.id) == [CourbesNoeud.cleParent])
        #expect(c.liens.first?.points.count == 2)
        #expect(c.parents.map(\.parent) == ["rloc:1400"])
        let r = try #require(s.courbes(noeud: "rloc:0400", periode: .jour, fin: Date()))
        #expect(r.liens.map(\.id) == ["rloc:1400"])
        #expect(r.signal.map(\.valeur) == [-61, -61])
    }

    /// La fiche montre les courbes des qu'il y a un historique (jamais en demo), et la vue lui
    /// garde plus de place en bas : la marge du bas suit la pile mesuree, plus haute avec les courbes (elle
    /// remplace les 190 et 360 pt fixes) ; pour un noeud sans historique, une ligne de texte.
    @Test func ficheEtMarge() throws {
        let s = try Self.surveillance()
        #expect(FicheNoeud.courbesVisibles(dans: s))
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        #expect(!FicheNoeud.courbesVisibles(dans: demo))
        let entree = FenetrePiecesTests.entree(s)
        func pile(_ id: String) -> CGFloat {
            let v = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                LigneDuBas(moteur: MoteurPieces(), entree: entree, legendeForcee: true)
                FicheNoeud(id: id, entree: entree, instant: Date(), aRenommer: .constant(nil)) {}
            }.frame(width: 1100 - 2 * FenetrePieces.bord)
            return NSHostingView(rootView: v.environment(s).environment(PiecesChoisies(fichier: nil))).fittingSize.height
        }
        let avecCourbes = pile(JournalMaillageTests.appareil)
        let sansCourbes = pile("instance:inconnue")
        #expect(FenetrePieces.margeBas(pile: avecCourbes) > FenetrePieces.margeBas(pile: sansCourbes) + 100,
                "\(avecCourbes) \(sansCourbes)")
        let avec = NSHostingView(rootView: CourbesFiche(id: JournalMaillageTests.appareil, instant: Date()).environment(s)).fittingSize
        let sans = NSHostingView(rootView: CourbesFiche(id: "instance:inconnue", instant: Date()).environment(s)).fittingSize
        #expect(avec.height > sans.height + 100, "\(avec) \(sans)")
    }

    /// Un troncon d'un seul point est dessine en point : une ligne en demande deux (ajout du
    /// controleur, relecture de la tache 9).
    @Test func tronconsDUnPoint() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let points = [PointCourbe(date: t, valeur: 1, troncon: 0),
                      PointCourbe(date: t.addingTimeInterval(300), valeur: 2, troncon: 0),
                      PointCourbe(date: t.addingTimeInterval(3600), valeur: 3, troncon: 1)]
        #expect(CourbesFiche.tronconsSeuls(points) == [1])
        #expect(CourbesFiche.tronconsSeuls([]).isEmpty)
    }
}
