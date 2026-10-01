import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : disposition des pieces")
struct DispositionPiecesTests {
    /// Paires de cartes d'un meme etage qui se recouvrent, ecarts `gap` et `lab` compris (a 1e-6 pres).
    static func recouvrements(_ s: ScenePieces, _ c: [CartesPieces.Carte], _ d: DispositionPieces) -> [String] {
        var r: [String] = []
        for e in s.etages {
            for (k, a) in e.pieces.enumerated() {
                for b in e.pieces[(k + 1)...] {
                    let dx = d.positions[b].x - d.positions[a].x, dz = d.positions[b].y - d.positions[a].y
                    let px = (c[a].largeur + c[b].largeur) / 2 + DispositionPieces.gap - abs(dx)
                    let pz = (c[a].profondeur + c[b].profondeur) / 2 + DispositionPieces.gap + DispositionPieces.lab - abs(dz)
                    if px > 1e-6 && pz > 1e-6 { r.append("\(s.pieces[a].id) / \(s.pieces[b].id)") }
                }
            }
        }
        return r
    }

    /// Maison inventee : 8 pieces, 30 appareils, 4 routeurs ; aucun recouvrement, chaque carte dans son
    /// plateau, et le cout retenu au plus celui du depart.
    @Test func aucunRecouvrement() {
        let (s, c) = MaisonInventee.scene(pieces: 8, appareils: 30, routeurs: 4)
        let d = DispositionPieces(scene: s, cartes: c)
        #expect(Self.recouvrements(s, c, d) == [])
        #expect(d.rayons.count == s.etages.count)
        for (i, p) in s.pieces.enumerated() {
            let coin = SIMD2(abs(d.positions[i].x) + c[i].largeur / 2, abs(d.positions[i].y) + c[i].profondeur / 2)
            #expect((coin.x * coin.x + coin.y * coin.y).squareRoot() <= d.rayons[p.etage], "\(p.id) dans son plateau")
        }
        #expect(d.cout <= d.coutDepart)
        #expect(d.coups > 0 && d.coups <= DispositionPieces.budget)
    }

    /// Memes entrees, meme disposition.
    @Test func deterministe() {
        let (s, c) = MaisonInventee.scene(pieces: 6, appareils: 20, routeurs: 3)
        let a = DispositionPieces(scene: s, cartes: c)
        let b = DispositionPieces(scene: s, cartes: c)
        #expect(a == b)
    }

    /// Une piece fixee ne bouge pas, et sert d'obstacle : les autres se placent sans la recouvrir, ni
    /// se recouvrir entre elles. Tout fixe : aucune optimisation.
    @Test func pieceFixee() {
        let (s, c) = MaisonInventee.scene(pieces: 6, appareils: 20, routeurs: 3)
        let place = SIMD2(4.5, -3.0)
        let d = DispositionPieces(scene: s, cartes: c, fixees: [0: place])
        #expect(d.positions[0] == place)
        #expect(Self.recouvrements(s, c, d) == [])
        let toutes = Dictionary(uniqueKeysWithValues: d.positions.enumerated().map { ($0, $1) })
        let figee = DispositionPieces(scene: s, cartes: c, fixees: toutes)
        #expect(figee.positions == d.positions)
        #expect(figee.coups == 0)
    }

    /// Budget : au plus `budget` coups ; le resultat reste sans recouvrement, et au plus le cout du depart.
    @Test func budget() {
        let (s, c) = MaisonInventee.scene(pieces: 8, appareils: 30, routeurs: 4)
        let d = DispositionPieces(scene: s, cartes: c, budget: 40)
        #expect(d.coups == 40)
        #expect(Self.recouvrements(s, c, d) == [])
        #expect(d.cout <= d.coutDepart)
    }

    /// Plateaux cote a cote en 2D : `esp` entre les bords de deux voisins, la rangee centree sur x = 0.
    @Test func centres2D() {
        let x = DispositionPieces.centres2D(rayons: [10, 4, 6])
        #expect(abs((x[1] - 4) - (x[0] + 10) - DispositionPieces.esp) < 1e-9)
        #expect(abs((x[2] - 6) - (x[1] + 4) - DispositionPieces.esp) < 1e-9)
        #expect(abs((x[0] - 10) + (x[2] + 6)) < 1e-9)
        #expect(DispositionPieces.centres2D(rayons: [7]) == [0])
    }

    /// Temps de calcul, en Release : sur une grande maison inventee (20 pieces, 100 appareils, 6
    /// routeurs de bordure), la disposition tient sous 1 s.
    @Test(.enabled(if: Compilation.optimisee, "mesure en Release (outils/mesurer.sh)"))
    func tempsGrandeMaison() {
        let (s, c) = MaisonInventee.scene(pieces: 20, appareils: 100, routeurs: 6)
        #expect(s.pieces.count == 20 && s.noeuds.count == 106)
        let debut = DispatchTime.now().uptimeNanoseconds
        let d = DispositionPieces(scene: s, cartes: c)
        let secondes = Double(DispatchTime.now().uptimeNanoseconds - debut) / 1e9
        print("mesure : disposition de la grande maison en \(secondes) s, \(d.coups) coups")
        #expect(secondes < 1, "\(secondes) s pour \(d.coups) coups")
        #expect(Self.recouvrements(s, c, d) == [])
    }

    /// Longueur traversee (Liang-Barsky) et croisements stricts.
    @Test func geometrie() {
        let r = DispositionPieces.Rect(x0: 0, x1: 2, z0: 0, z1: 1)
        #expect(abs(DispositionPieces.dedans(SIMD2(-1, 0.5), SIMD2(3, 0.5), r) - 2) < 1e-12)
        #expect(DispositionPieces.dedans(SIMD2(-1, 2), SIMD2(3, 2), r) == 0)
        #expect(abs(DispositionPieces.dedans(SIMD2(1, 0.5), SIMD2(1, 3), r) - 0.5) < 1e-12)
        #expect(DispositionPieces.croise(SIMD2(0, 0), SIMD2(2, 2), SIMD2(0, 2), SIMD2(2, 0)))
        #expect(!DispositionPieces.croise(SIMD2(0, 0), SIMD2(1, 1), SIMD2(1, 1), SIMD2(2, 0)), "bout commun")
        #expect(!DispositionPieces.croise(SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1), SIMD2(1, 1)))
    }
}
