import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Graphe : projection du plan vers la vue")
struct GrapheTests {
    @Test func projection() {
        let cadre = (min: Point2D(-210, -210), max: Point2D(390, 470))
        let p = Projection(cadre: cadre, taille: CGSize(width: 1000, height: 800),
                           marges: (haut: 70, bas: 30, cotes: 60))
        // Place libre : 880 x 700 pour un cadre de 600 x 680 : la hauteur decide.
        #expect(abs(p.echelle - 700.0 / 680.0) < 1e-9)
        let centre = p.vue(Point2D(90, 130))
        #expect(abs(centre.x - 500) < 1e-9 && abs(centre.y - 420) < 1e-9, "centre du cadre au centre de la place libre")
        let q = p.plan(p.vue(Point2D(12, -34)))
        #expect(abs(q.x - 12) < 1e-9 && abs(q.y + 34) < 1e-9)
        let zoom = Projection(cadre: cadre, taille: CGSize(width: 1000, height: 800),
                              marges: (haut: 70, bas: 30, cotes: 60), zoom: 2, decalage: CGSize(width: 10, height: -5))
        #expect(abs(zoom.echelle - 2 * p.echelle) < 1e-9)
        let c2 = zoom.vue(Point2D(90, 130))
        #expect(abs(c2.x - 510) < 1e-9 && abs(c2.y - 415) < 1e-9)
    }
}
