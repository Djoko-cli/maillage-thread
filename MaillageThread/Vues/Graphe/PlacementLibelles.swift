import CoreGraphics
import Foundation
import MaillageCoeur

/// Place des libelles du graphe, en coordonnees de la vue : une seule source de
/// verite pour le dessin (`GrapheCanvas`) et pour le clic et le survol (`cible(a:)`).
///
/// Chaque libelle essaie d'abord la place d'aujourd'hui : vers l'exterieur de sa zone
/// (a droite ou a gauche sur les cotes, au-dessus ou au-dessous en haut et en bas ;
/// sous le centre). Puis les autres places autour de son point (droite, gauche,
/// dessous, dessus, diagonales), les plus proches de l'exterieur d'abord. Il prend la
/// premiere qui ne recoupe ni un libelle deja pose, ni un point, ni un obstacle (titres
/// des zones), ni un trait deja trace, a `jeu` pres.
///
/// Sinon, il est ecarte vers l'exterieur de la zone, de `pas` en `pas`, tout droit ou de
/// biais (jusqu'a 75 degres), et relie a son point par un trait fin ; son nom reste
/// entier. Il prend la plus proche place libre dont le trait ne traverse ni un libelle,
/// ni un autre point, ni un obstacle. S'il n'y en a pas (vue tres dezoomee), il prend la
/// premiere place libre de la direction dont le trait traverse le moins. Une place libre
/// existe toujours : assez loin, le libelle sort de la boite qui contient tout ce qu'il
/// doit eviter.
///
/// Ordre de pose : les centres, les routeurs, puis les appareils, chacun par
/// identifiant ; meme entree, meme sortie, quel que soit l'ordre d'arrivee.
struct PlacementLibelles: Equatable {
    /// Noeud a etiqueter.
    struct Noeud: Equatable {
        var id: String
        var genre: Disposition.Genre
        /// Centre et rayon du point dessine.
        var centre: CGPoint
        var rayon: CGFloat
        /// Centre de sa zone : le libelle part vers l'exterieur.
        var centreZone: CGPoint
        /// Place du texte, en semi-gras : survol et selection compris.
        var texte: CGSize
        /// Pastille de batterie, s'il y en a une.
        var pastille: CGSize?
    }

    /// Cote du point ou se tient le libelle. Il dit aussi l'agencement : texte puis
    /// pastille a droite, pastille puis texte a gauche ; pastille au-dessus du texte en
    /// haut, au-dessous en bas (la pastille au bout, du cote oppose au point).
    enum Sens: Equatable {
        case droite, gauche, dessus, dessous
    }

    /// Trait fin d'un libelle ecarte : du bord de son point au bord du libelle.
    struct Trait: Equatable {
        var depart: CGPoint
        var arrivee: CGPoint
    }

    /// Place d'un libelle.
    struct Place: Equatable {
        /// Tout le libelle, texte et pastille : ce qu'aucun autre ne recoupe, et sa zone de clic.
        var cadre: CGRect
        /// Place du texte (semi-gras), dans le cadre.
        var texte: CGRect
        /// Place de la pastille, dans le cadre.
        var pastille: CGRect?
        var sens: Sens
        /// Trait fin vers le point, pour un libelle ecarte.
        var trait: Trait?

        /// Libelle ecarte de son point, relie par un trait fin.
        var ecarte: Bool { trait != nil }

        /// Fond discret sous le libelle (texte et pastille), a coins arrondis de `rayonFond` :
        /// le cadre, `margeFond` autour.
        var fond: CGRect {
            cadre.insetBy(dx: -PlacementLibelles.margeFond.width, dy: -PlacementLibelles.margeFond.height)
        }
    }

    /// Ecart minimal entre un libelle et un autre, un point ou un obstacle.
    static let jeu: CGFloat = 2
    /// Pas de l'ecartement vers l'exterieur.
    static let pas: CGFloat = 4
    /// Marge de clic et de survol autour du point dessine, en points de la vue.
    static let margeClic: CGFloat = 8
    /// Entre le texte et sa pastille : cote a cote, l'un sur l'autre.
    static let ecartPastille = (cote: CGFloat(5), dessus: CGFloat(3))
    /// Fond d'un libelle : marge autour de son cadre, rayon de ses coins (arrondi circulaire).
    /// La marge ne depasse pas `jeu` et le rayon vaut au moins la marge : le fond reste a moins
    /// de `jeu` de son cadre ; il touche au plus un autre libelle ou un point, sans le couvrir.
    static let margeFond = CGSize(width: 2, height: 1)
    static let rayonFond: CGFloat = 4

    /// Noeuds, dans l'ordre de pose.
    private(set) var noeuds: [Noeud] = []
    /// Place du libelle de chaque noeud.
    private(set) var places: [String: Place] = [:]
    /// Obstacles evites (titres des zones).
    private(set) var obstacles: [CGRect] = []

    init(noeuds entree: [Noeud], obstacles: [CGRect]) {
        self.obstacles = obstacles
        func rang(_ g: Disposition.Genre) -> Int {
            switch g {
            case .centre: 0
            case .routeur: 1
            case .appareil: 2
            }
        }
        var vus: Set<String> = []
        noeuds = entree.enumerated()
            .sorted { (rang($0.element.genre), $0.element.id, $0.offset) < (rang($1.element.genre), $1.element.id, $1.offset) }
            .map(\.element)
            .filter { vus.insert($0.id).inserted }

        // Tout ce qu'un libelle doit eviter tient dans `boite` (jeu compris) : un libelle
        // qui en sort est libre.
        var poses: [CGRect] = []
        var traits: [Trait] = []
        var boite = CGRect.null
        for n in entree {
            boite = boite.union(CGRect(x: n.centre.x - n.rayon, y: n.centre.y - n.rayon, width: 2 * n.rayon,
                                       height: 2 * n.rayon).insetBy(dx: -Self.jeu, dy: -Self.jeu))
        }
        for o in obstacles {
            boite = boite.union(o.insetBy(dx: -Self.jeu, dy: -Self.jeu))
        }
        // Cadre qui ne recoupe ni un libelle pose, ni un obstacle, ni un point, ni un trait.
        func libre(_ r: CGRect) -> Bool {
            let large = r.insetBy(dx: -Self.jeu, dy: -Self.jeu)
            return !poses.contains { Self.recoupe(r, $0) } && !obstacles.contains { Self.recoupe(r, $0) }
                && !entree.contains { Self.distance($0.centre, r) < $0.rayon + Self.jeu }
                && !traits.contains { Self.coupe($0.depart, $0.arrivee, large) }
        }
        // Le trait `t` passe dans un cadre (libelle pose, obstacle), ou sur un autre point que `n`.
        func traverse(_ t: Trait, _ r: CGRect) -> Bool {
            Self.coupe(t.depart, t.arrivee, r.insetBy(dx: -Self.jeu, dy: -Self.jeu))
        }
        func traverse(_ t: Trait, _ m: Noeud, de n: Noeud) -> Bool {
            m.id != n.id && Self.distance(m.centre, t.depart, t.arrivee) < m.rayon + Self.jeu
        }
        func degage(_ n: Noeud, _ t: Trait) -> Bool {
            !poses.contains { traverse(t, $0) } && !obstacles.contains { traverse(t, $0) }
                && !entree.contains { traverse(t, $0, de: n) }
        }
        func croisements(_ n: Noeud, _ t: Trait) -> Int {
            poses.count { traverse(t, $0) } + obstacles.count { traverse(t, $0) } + entree.count { traverse(t, $0, de: n) }
        }
        // Libelle ecarte de `n`, vers l'exterieur : tout droit, ou de biais de 15 en 15 degres
        // jusqu'a 75 (il s'eloigne toujours de sa zone).
        func ecarter(_ n: Noeud, _ direction: (angle: CGFloat, vecteur: CGPoint)) -> Place {
            struct Voie {
                var vecteur: CGPoint
                var emplacement: Emplacement
                var base: CGFloat
                var ouverte = true
            }
            var voies = [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5].map { j -> Voie in
                let angle = direction.angle + CGFloat(j) * .pi / 12
                let u = j == 0 ? direction.vecteur : CGPoint(x: cos(angle), y: sin(angle))
                let e = j == 0 ? Self.regle(n, direction.angle) : Self.cote(angle)
                return Voie(vecteur: u, emplacement: e, base: n.rayon + e.ecart(n))
            }
            // Libelle au k-ieme pas d'une voie, et son trait (du bord du point au bord du libelle).
            func place(_ v: Voie, _ k: Int) -> (place: Place, trait: Trait) {
                let d = v.base + CGFloat(k) * Self.pas
                let a = CGPoint(x: n.centre.x + v.vecteur.x * d, y: n.centre.y + v.vecteur.y * d)
                var p = Self.agencer(n, v.emplacement.sens, ancre: a, unite: v.emplacement.unite)
                let t = Trait(depart: CGPoint(x: n.centre.x + v.vecteur.x * n.rayon, y: n.centre.y + v.vecteur.y * n.rayon),
                              arrivee: a)
                p.trait = t
                return (p, t)
            }
            // Au-dela de `loin`, un libelle est hors de `boite`, donc libre : sur chaque voie,
            // il y a une place libre au plus tard a `kMax`.
            let blocs = [Sens.droite, .dessus].map { Self.taille(n, $0) }
            let loin = [CGPoint(x: boite.minX, y: boite.minY), CGPoint(x: boite.maxX, y: boite.minY),
                        CGPoint(x: boite.minX, y: boite.maxY), CGPoint(x: boite.maxX, y: boite.maxY)]
                .map { hypot($0.x - n.centre.x, $0.y - n.centre.y) }.max()!
                + blocs.map { hypot($0.width, $0.height) }.max()!
            let kMax = loin.isFinite ? max(1, Int(min((loin / Self.pas).rounded(.up), 1e6)) + 1) : 1
            // La plus proche place libre dont le trait ne traverse rien (a egale distance, la
            // plus droite). Un trait qui traverse traverse encore plus loin : sa voie se ferme.
            for k in 1...kMax {
                for i in voies.indices where voies[i].ouverte {
                    let (p, t) = place(voies[i], k)
                    guard degage(n, t) else {
                        voies[i].ouverte = false
                        continue
                    }
                    if libre(p.cadre) { return p }
                }
                if !voies.contains(where: \.ouverte) { break }
            }
            // Sinon, la premiere place libre de chaque voie (libre au plus tard a `kMax`) ; celle
            // dont le trait traverse le moins, puis la plus proche, puis la plus droite.
            var choix: (croise: Int, distance: CGFloat, rang: Int, place: Place)?
            for (rang, v) in voies.enumerated() {
                var k = 1
                while k < kMax && !libre(place(v, k).place.cadre) { k += 1 }
                let (p, t) = place(v, k)
                let cle = (croisements(n, t), v.base + CGFloat(k) * Self.pas, rang)
                if choix.map({ cle < ($0.croise, $0.distance, $0.rang) }) ?? true {
                    choix = (cle.0, cle.1, cle.2, p)
                }
            }
            return choix?.place ?? place(voies[0], kMax).place
        }

        for n in noeuds {
            let direction = Self.direction(n)
            let place = Self.candidats(n, direction).lazy
                .map { Self.agencer(n, $0.sens, ancre: $0.ancre(n), unite: $0.unite) }
                .first { libre($0.cadre) } ?? ecarter(n, direction)
            places[n.id] = place
            poses.append(place.cadre)
            boite = boite.union(place.cadre.insetBy(dx: -Self.jeu, dy: -Self.jeu))
            if let t = place.trait {
                traits.append(t)
                boite = boite.union(CGRect(x: min(t.depart.x, t.arrivee.x), y: min(t.depart.y, t.arrivee.y),
                                           width: abs(t.arrivee.x - t.depart.x), height: abs(t.arrivee.y - t.depart.y))
                    .insetBy(dx: -Self.jeu, dy: -Self.jeu))
            }
        }
    }

    /// Noeud sous le point `p` de la vue : son point (avec `margeClic` autour du rayon
    /// dessine) ou tout son libelle. Si plusieurs zones le contiennent, le plus proche du
    /// curseur l'emporte (distance au point dessine ou au libelle, puis au centre du point).
    func cible(a p: CGPoint) -> String? {
        var choix: (id: String, distance: CGFloat, auCentre: CGFloat)?
        for n in noeuds {
            let auCentre = hypot(p.x - n.centre.x, p.y - n.centre.y)
            var distance: CGFloat? = auCentre <= n.rayon + Self.margeClic ? max(0, auCentre - n.rayon) : nil
            if let c = places[n.id]?.cadre, c.minX <= p.x, p.x <= c.maxX, c.minY <= p.y, p.y <= c.maxY {
                distance = 0
            }
            guard let distance else { continue }
            if choix.map({ (distance, auCentre) < ($0.distance, $0.auCentre) }) ?? true {
                choix = (n.id, distance, auCentre)
            }
        }
        return choix?.id
    }

    /// Le meme placement, deplace de `v` (glisser, origine du plan dans la vue) : rien
    /// n'est recalcule.
    func decale(_ v: CGPoint) -> PlacementLibelles {
        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + v.x, y: p.y + v.y) }
        func rect(_ r: CGRect) -> CGRect { r.offsetBy(dx: v.x, dy: v.y) }
        var d = self
        d.noeuds = noeuds.map { n in
            var n = n
            n.centre = point(n.centre)
            n.centreZone = point(n.centreZone)
            return n
        }
        d.places = places.mapValues { p in
            Place(cadre: rect(p.cadre), texte: rect(p.texte), pastille: p.pastille.map(rect), sens: p.sens,
                  trait: p.trait.map { Trait(depart: point($0.depart), arrivee: point($0.arrivee)) })
        }
        d.obstacles = obstacles.map(rect)
        return d
    }

    // MARK: - Places autour du point

    /// Direction de l'exterieur de la zone, du centre de la zone vers le point (angle et
    /// vecteur unitaire) ; vers le bas pour un centre ; vers la droite pour un point au
    /// centre de sa zone (comme `atan2(0, 0)`).
    private static func direction(_ n: Noeud) -> (angle: CGFloat, vecteur: CGPoint) {
        if n.genre == .centre { return (.pi / 2, CGPoint(x: 0, y: 1)) }
        let dx = n.centre.x - n.centreZone.x
        let dy = n.centre.y - n.centreZone.y
        let l = hypot(dx, dy)
        guard l > 0 else { return (0, CGPoint(x: 1, y: 0)) }
        return (atan2(dy, dx), CGPoint(x: dx / l, y: dy / l))
    }

    /// Places autour d'un point : le cote du libelle, sa direction depuis le point, et le
    /// point du cadre du libelle pose a son ancre (en unites du cadre).
    private enum Emplacement: CaseIterable {
        case droite, gauche, dessous, dessus, basDroite, basGauche, hautDroite, hautGauche

        var sens: Sens {
            switch self {
            case .droite, .basDroite, .hautDroite: .droite
            case .gauche, .basGauche, .hautGauche: .gauche
            case .dessous: .dessous
            case .dessus: .dessus
            }
        }

        var angle: CGFloat {
            switch self {
            case .droite: 0
            case .basDroite: .pi / 4
            case .dessous: .pi / 2
            case .basGauche: 3 * .pi / 4
            case .gauche: .pi
            case .hautGauche: -3 * .pi / 4
            case .dessus: -.pi / 2
            case .hautDroite: -.pi / 4
            }
        }

        var unite: CGPoint {
            switch self {
            case .droite: CGPoint(x: 0, y: 0.5)
            case .gauche: CGPoint(x: 1, y: 0.5)
            case .dessous: CGPoint(x: 0.5, y: 0)
            case .dessus: CGPoint(x: 0.5, y: 1)
            case .basDroite: CGPoint(x: 0, y: 0)
            case .basGauche: CGPoint(x: 1, y: 0)
            case .hautDroite: CGPoint(x: 0, y: 1)
            case .hautGauche: CGPoint(x: 1, y: 1)
            }
        }

        /// Ecart au bord du point : 4 pt sur les cotes et sous un centre, 3 pt dessus et
        /// dessous (comme aujourd'hui), 3 pt en diagonale.
        func ecart(_ n: Noeud) -> CGFloat {
            switch self {
            case .droite, .gauche: 4
            case .dessous: n.genre == .centre ? 4 : 3
            case .dessus, .basDroite, .basGauche, .hautDroite, .hautGauche: 3
            }
        }

        /// Ancre du libelle : sur l'axe, a `ecart` du bord du point ; en diagonale, le coin
        /// du cadre a `ecart` du bord du point.
        func ancre(_ n: Noeud) -> CGPoint {
            let d = n.rayon + ecart(n)
            let k = d / CGFloat(2).squareRoot()
            let c = n.centre
            switch self {
            case .droite: return CGPoint(x: c.x + d, y: c.y)
            case .gauche: return CGPoint(x: c.x - d, y: c.y)
            case .dessous: return CGPoint(x: c.x, y: c.y + d)
            case .dessus: return CGPoint(x: c.x, y: c.y - d)
            case .basDroite: return CGPoint(x: c.x + k, y: c.y + k)
            case .basGauche: return CGPoint(x: c.x - k, y: c.y + k)
            case .hautDroite: return CGPoint(x: c.x + k, y: c.y - k)
            case .hautGauche: return CGPoint(x: c.x - k, y: c.y - k)
            }
        }
    }

    /// Regle d'aujourd'hui : sous un centre ; sinon selon la direction de l'exterieur.
    private static func regle(_ n: Noeud, _ angle: CGFloat) -> Emplacement {
        n.genre == .centre ? .dessous : cote(angle)
    }

    /// Cote d'un libelle pose dans une direction : a droite ou a gauche quand elle est
    /// franche, au-dessus ou au-dessous sinon.
    private static func cote(_ angle: CGFloat) -> Emplacement {
        if cos(angle) > 0.35 { return .droite }
        if cos(angle) < -0.35 { return .gauche }
        return sin(angle) < 0 ? .dessus : .dessous
    }

    /// La place d'aujourd'hui, puis les autres, les plus proches de l'exterieur d'abord
    /// (a egalite, dans l'ordre droite, gauche, dessous, dessus, diagonales).
    private static func candidats(_ n: Noeud, _ direction: (angle: CGFloat, vecteur: CGPoint)) -> [Emplacement] {
        let premier = regle(n, direction.angle)
        func ecartAngle(_ e: Emplacement) -> CGFloat { abs(remainder(e.angle - direction.angle, 2 * .pi)) }
        let autres = Emplacement.allCases.enumerated()
            .filter { $0.element != premier }
            .sorted { (ecartAngle($0.element), $0.offset) < (ecartAngle($1.element), $1.offset) }
            .map(\.element)
        return [premier] + autres
    }

    /// Taille du libelle (texte et pastille) selon son agencement.
    private static func taille(_ n: Noeud, _ sens: Sens) -> CGSize {
        let t = n.texte
        guard let p = n.pastille else { return t }
        switch sens {
        case .droite, .gauche:
            return CGSize(width: t.width + ecartPastille.cote + p.width, height: max(t.height, p.height))
        case .dessus, .dessous:
            return CGSize(width: max(t.width, p.width), height: t.height + ecartPastille.dessus + p.height)
        }
    }

    /// Libelle pose avec le point `unite` de son cadre (0 a 1 sur chaque axe) en `ancre`.
    private static func agencer(_ n: Noeud, _ sens: Sens, ancre a: CGPoint, unite u: CGPoint) -> Place {
        let taille = taille(n, sens)
        let cadre = CGRect(x: a.x - u.x * taille.width, y: a.y - u.y * taille.height, width: taille.width,
                           height: taille.height)
        let t = n.texte
        guard let p = n.pastille else { return Place(cadre: cadre, texte: cadre, pastille: nil, sens: sens) }
        // Texte et pastille, depuis le coin du cadre.
        func dans(_ x: CGFloat, _ y: CGFloat, _ s: CGSize) -> CGRect {
            CGRect(x: cadre.minX + x, y: cadre.minY + y, width: s.width, height: s.height)
        }
        let (l, h) = (taille.width, taille.height)
        switch sens {
        case .droite:
            return Place(cadre: cadre, texte: dans(0, (h - t.height) / 2, t),
                         pastille: dans(t.width + ecartPastille.cote, (h - p.height) / 2, p), sens: sens)
        case .gauche:
            return Place(cadre: cadre, texte: dans(p.width + ecartPastille.cote, (h - t.height) / 2, t),
                         pastille: dans(0, (h - p.height) / 2, p), sens: sens)
        case .dessus:
            return Place(cadre: cadre, texte: dans((l - t.width) / 2, p.height + ecartPastille.dessus, t),
                         pastille: dans((l - p.width) / 2, 0, p), sens: sens)
        case .dessous:
            return Place(cadre: cadre, texte: dans((l - t.width) / 2, 0, t),
                         pastille: dans((l - p.width) / 2, t.height + ecartPastille.dessus, p), sens: sens)
        }
    }

    // MARK: - Geometrie

    /// Deux cadres a moins de `jeu` l'un de l'autre.
    private static func recoupe(_ a: CGRect, _ b: CGRect) -> Bool {
        a.minX < b.maxX + jeu && b.minX - jeu < a.maxX && a.minY < b.maxY + jeu && b.minY - jeu < a.maxY
    }

    /// Distance d'un point a un cadre (0 dedans).
    private static func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
    }

    /// Distance d'un point au segment [a, b].
    private static func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let d = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let l2 = d.x * d.x + d.y * d.y
        let t = l2 > 0 ? min(max(((p.x - a.x) * d.x + (p.y - a.y) * d.y) / l2, 0), 1) : 0
        return hypot(p.x - (a.x + t * d.x), p.y - (a.y + t * d.y))
    }

    /// Le segment [a, b] passe dans le cadre (le longer ou le toucher en un point ne compte
    /// pas) : decoupage de Liang et Barsky.
    private static func coupe(_ a: CGPoint, _ b: CGPoint, _ r: CGRect) -> Bool {
        var t0: CGFloat = 0
        var t1: CGFloat = 1
        let d = CGPoint(x: b.x - a.x, y: b.y - a.y)
        for (p, q) in [(-d.x, a.x - r.minX), (d.x, r.maxX - a.x), (-d.y, a.y - r.minY), (d.y, r.maxY - a.y)] {
            if p == 0 {
                if q <= 0 { return false }
            } else if p < 0 {
                t0 = max(t0, q / p)
            } else {
                t1 = min(t1, q / p)
            }
        }
        return t0 < t1
    }
}
