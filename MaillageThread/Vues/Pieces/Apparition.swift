import SwiftUI

/// Apparition d'un element pose sur la vue (polissage B ; maquette de la fiche, carte A) : la fiche
/// glisse depuis le bas, un bandeau du haut depuis le haut, avec un fondu, en 0,3 s, sur la courbe de
/// la maquette (`cubic-bezier(.2, .8, .2, 1)`) ; ils repartent de meme. Avec « Reduire les
/// animations », un fondu simple.
enum Apparition: Equatable {
    /// Glisse depuis ce bord, de 110 % de sa hauteur, avec un fondu.
    case glisse(Edge)
    case fondu

    static let duree = 0.3

    static func pour(_ bord: Edge, reduire: Bool) -> Apparition {
        reduire ? .fondu : .glisse(bord)
    }

    var transition: AnyTransition {
        switch self {
        case .glisse(let bord): AnyTransition(Glisse(bord: bord))
        case .fondu: .opacity
        }
    }

    var animation: Animation {
        switch self {
        case .glisse: .timingCurve(0.2, 0.8, 0.2, 1, duration: Self.duree)
        case .fondu: .easeInOut(duration: Self.duree)
        }
    }

    /// La courbe de la maquette, `cubic-bezier(.2, .8, .2, 1)` : l'avancement en fonction du temps, de 0
    /// a 1. Le moteur y fait glisser les marges de la vue avec la fiche et les bandeaux.
    static func courbe(_ temps: Double) -> Double {
        if temps <= 0 { return 0 }
        if temps >= 1 { return 1 }
        let x = temps
        func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
            3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * b + t * t * t
        }
        // L'abscisse croit avec t : on la resout par dichotomie.
        var bas = 0.0
        var haut = 1.0
        for _ in 0..<40 {
            let t = (bas + haut) / 2
            if bezier(t, 0.2, 0.2) < x { bas = t } else { haut = t }
        }
        return bezier((bas + haut) / 2, 0.8, 1)
    }
}

/// Glisse depuis un bord, de 110 % de sa hauteur, avec un fondu (maquette : `translateY(110%)`). Le
/// decalage ne touche que le dessin : la place de l'element, et l'obstacle qu'il fait aux noms, sont
/// ceux d'arrivee.
struct Glisse: Transition {
    let bord: Edge

    func body(content: Content, phase: TransitionPhase) -> some View {
        let hors = !phase.isIdentity
        let sens: CGFloat = bord == .top ? -1 : 1
        content
            .visualEffect { c, g in c.offset(y: hors ? sens * 1.1 * g.size.height : 0) }
            .opacity(hors ? 0 : 1)
    }
}
