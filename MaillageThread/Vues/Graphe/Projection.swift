import CoreGraphics
import MaillageCoeur

/// Passage du plan de la disposition a la vue : le cadre des zones tient dans
/// la place libre (hors marges), puis zoom et decalage de l'utilisateur.
struct Projection: Equatable {
    let echelle: CGFloat
    /// Point de la vue ou tombe l'origine du plan.
    let origine: CGPoint

    init(cadre: (min: Point2D, max: Point2D), taille: CGSize, marges: (haut: CGFloat, bas: CGFloat, cotes: CGFloat),
         zoom: CGFloat = 1, decalage: CGSize = .zero) {
        let largeur = max(taille.width - 2 * marges.cotes, 1)
        let hauteur = max(taille.height - marges.haut - marges.bas, 1)
        let l = max(cadre.max.x - cadre.min.x, 1)
        let h = max(cadre.max.y - cadre.min.y, 1)
        echelle = min(largeur / l, hauteur / h) * zoom
        let centreVue = CGPoint(x: marges.cotes + largeur / 2 + decalage.width,
                                y: marges.haut + hauteur / 2 + decalage.height)
        let centrePlan = CGPoint(x: (cadre.min.x + cadre.max.x) / 2, y: (cadre.min.y + cadre.max.y) / 2)
        origine = CGPoint(x: centreVue.x - centrePlan.x * echelle, y: centreVue.y - centrePlan.y * echelle)
    }

    func vue(_ p: Point2D) -> CGPoint {
        CGPoint(x: origine.x + p.x * echelle, y: origine.y + p.y * echelle)
    }

    func plan(_ v: CGPoint) -> Point2D {
        Point2D((v.x - origine.x) / echelle, (v.y - origine.y) / echelle)
    }
}
