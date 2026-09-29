import AppKit
import MaillageCoeur
import SwiftUI

/// Tailles des textes du graphe, mesurees hors du Canvas avec les memes `Text` que le
/// dessin (`GrapheCanvas.texteLibelle`, `texteTitre`, `iconePastille`, `textePastille`).
/// SwiftUI les met en page comme le Canvas, a l'echelle d'ecran 1 : arrondies au point
/// entier superieur. Le Canvas arrondit au pixel de son ecran (le demi-point en 2x) :
/// la taille mesuree couvre donc le texte dessine, a moins d'un point pres, a toute
/// echelle (`LibellesGrapheTests.tailleMesureeCommeDessinee`). Une taille par texte, gardee.
@MainActor
final class MesureTextes {
    private enum Nature: Hashable {
        case libelle(Disposition.Genre), titre, icone, valeur
    }

    private struct Cle: Hashable {
        var texte: String
        var nature: Nature
    }

    private var hote: NSHostingController<AnyView>?
    private var tailles: [Cle: CGSize] = [:]

    /// Place d'un libelle, en semi-gras : elle ne change pas au survol ni a la selection.
    func libelle(_ texte: String, genre: Disposition.Genre) -> CGSize {
        mesurer(Cle(texte: texte, nature: .libelle(genre == .appareil ? .appareil : .routeur))) {
            GrapheCanvas.texteLibelle(texte, genre: genre, fort: true)
        }
    }

    func titre(_ texte: String) -> CGSize {
        mesurer(Cle(texte: texte, nature: .titre)) { GrapheCanvas.texteTitre(texte) }
    }

    /// Capsule de la pastille d'une batterie faible.
    func pastille(_ valeur: String) -> CGSize {
        GrapheCanvas.taillePastille(icone: mesurer(Cle(texte: "", nature: .icone)) { GrapheCanvas.iconePastille },
                                    valeur: mesurer(Cle(texte: valeur, nature: .valeur)) {
                                        GrapheCanvas.textePastille(valeur)
                                    })
    }

    private func mesurer(_ cle: Cle, _ texte: () -> Text) -> CGSize {
        if let t = tailles[cle] { return t }
        let hote = self.hote ?? NSHostingController(rootView: AnyView(EmptyView()))
        self.hote = hote
        hote.rootView = AnyView(texte().environment(\.displayScale, 1))
        let t = hote.sizeThatFits(in: GrapheCanvas.propositionTexte)
        tailles[cle] = t
        return t
    }
}

/// Placement des libelles d'une disposition, recalcule seulement quand la disposition,
/// l'echelle ou les textes changent : ni au survol, ni pendant un glisser. L'echelle suit
/// le zoom (borne, meme pendant un pincement) et la taille de la fenetre, et aussi la
/// selection quand la hauteur limite : la fiche ouverte reserve le bas de la vue (marge
/// de 30 a 190 pt). Coordonnees de la vue, l'origine du plan en (0, 0) :
/// `decale(projection.origine)` les pose dans la vue, sans rien recalculer.
@MainActor
final class MemoirePlacement {
    private struct Cle: Equatable {
        var disposition: Disposition
        var libelles: [String: GrapheCanvas.Libelle]
        var titres: [String]
        var echelle: CGFloat
    }

    private let mesure = MesureTextes()
    private var cle: Cle?
    private var dernier = PlacementLibelles(noeuds: [], obstacles: [])
    /// Nombre de placements calcules (tests).
    private(set) var calculs = 0

    func placement(_ disposition: Disposition, libelles: [String: GrapheCanvas.Libelle],
                   echelle: CGFloat) -> PlacementLibelles {
        let titres = disposition.zones.map(GrapheCanvas.titre)
        let c = Cle(disposition: disposition, libelles: libelles, titres: titres, echelle: echelle)
        if c == cle { return dernier }
        dernier = calculer(disposition, libelles: libelles, titres: titres, echelle: echelle)
        cle = c
        calculs += 1
        return dernier
    }

    /// Noeuds (point dessine, libelle mesure) et titres des zones, a l'echelle.
    private func calculer(_ disposition: Disposition, libelles: [String: GrapheCanvas.Libelle], titres: [String],
                          echelle: CGFloat) -> PlacementLibelles {
        let centres = Dictionary(disposition.zones.map { ($0.id, $0.centre) }, uniquingKeysWith: { a, _ in a })
        func vue(_ p: Point2D) -> CGPoint { CGPoint(x: p.x * echelle, y: p.y * echelle) }
        let noeuds = disposition.noeuds.map { n in
            let l = libelles[n.id] ?? GrapheCanvas.Libelle(texte: n.id)
            return PlacementLibelles.Noeud(id: n.id, genre: n.genre, centre: vue(n.position),
                                           rayon: GrapheCanvas.rayonPoint(n.rayon, echelle: echelle),
                                           centreZone: vue(centres[n.zone] ?? n.position),
                                           texte: mesure.libelle(l.texte, genre: n.genre),
                                           pastille: l.pastille.map(mesure.pastille))
        }
        // Titre d'une zone : centre sur son cercle, le bas a `ancreTitre`, comme au dessin.
        let obstacles = zip(disposition.zones, titres).map { z, titre in
            let taille = mesure.titre(titre)
            let ancre = GrapheCanvas.ancreTitre(centre: vue(z.centre), rayon: z.rayon * echelle)
            return CGRect(x: ancre.x - taille.width / 2, y: ancre.y - taille.height, width: taille.width,
                          height: taille.height)
        }
        return PlacementLibelles(noeuds: noeuds, obstacles: obstacles)
    }
}
