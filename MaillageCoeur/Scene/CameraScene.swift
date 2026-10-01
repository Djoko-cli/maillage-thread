import CoreGraphics
import Foundation
import simd

/// Camera en orbite autour de sa cible (spec de la vue par pieces, section 7) : distance, azimut
/// (autour de y, 0 quand l'oeil est du cote +z), inclinaison depuis la verticale, champ vertical en
/// degres. L'axe y monte.
public struct Orbite: Hashable, Sendable {
    public var cible: SIMD3<Double>
    public var distance: Double
    public var azimut: Double
    public var inclinaison: Double
    public var champ: Double

    public init(cible: SIMD3<Double>, distance: Double, azimut: Double, inclinaison: Double, champ: Double) {
        self.cible = cible
        self.distance = distance
        self.azimut = azimut
        self.inclinaison = inclinaison
        self.champ = champ
    }

    /// De la cible vers l'oeil : l'axe z de la camera (elle regarde vers -z).
    public var arriere: SIMD3<Double> {
        SIMD3(sin(inclinaison) * sin(azimut), cos(inclinaison), sin(inclinaison) * cos(azimut))
    }

    /// Axe x de la camera, defini meme a la verticale.
    public var droite: SIMD3<Double> { SIMD3(cos(azimut), 0, -sin(azimut)) }
    public var haut: SIMD3<Double> { simd_cross(arriere, droite) }
    public var oeil: SIMD3<Double> { cible + arriere * distance }

    /// Place l'oeil et la cible (vol de camera) ; l'azimut reste continu.
    public mutating func placer(oeil: SIMD3<Double>, cible c: SIMD3<Double>) {
        let v = oeil - c
        let d = simd_length(v)
        guard d > 1e-9 else { return }
        cible = c
        distance = d
        inclinaison = acos(min(1, max(-1, v.y / d)))
        if abs(v.x) + abs(v.z) > 1e-9 * d {
            let a = atan2(v.x, v.z)
            azimut = a + 2 * .pi * ((azimut - a) / (2 * .pi)).rounded()
        }
    }

    /// Distance a laquelle un champ vertical de `champ` degres couvre `hauteur` unites.
    public static func distance(pourHauteur hauteur: Double, champ: Double) -> Double {
        hauteur / (2 * tan(champ * .pi / 360))
    }
}

/// Projection d'une image : du monde a la camera par une matrice, puis perspective vers l'ecran
/// (points, origine en haut a gauche). Le cadre est la place utile de la vue : son centre est le
/// point principal, sa hauteur regle la focale. Plan proche a 0,5.
public struct ProjectionScene: Sendable {
    public static let proche = 0.5
    public let vue: simd_double4x4
    /// Points par unite a une profondeur de 1.
    public let focale: Double
    public let centre: CGPoint
    let droite, haut, arriere, oeil: SIMD3<Double>

    public init(_ o: Orbite, cadre: CGRect) {
        let x = o.droite, y = o.haut, z = o.arriere, e = o.oeil
        vue = simd_double4x4(rows: [
            SIMD4(x.x, x.y, x.z, -simd_dot(x, e)),
            SIMD4(y.x, y.y, y.z, -simd_dot(y, e)),
            SIMD4(z.x, z.y, z.z, -simd_dot(z, e)),
            SIMD4(0, 0, 0, 1),
        ])
        focale = Double(cadre.height) / 2 / tan(o.champ * .pi / 360)
        centre = CGPoint(x: cadre.midX, y: cadre.midY)
        droite = x
        haut = y
        arriere = z
        oeil = e
    }

    /// Coordonnees camera : x a droite, y en haut, z vers l'arriere (profondeur = -z).
    public func camera(_ p: SIMD3<Double>) -> SIMD3<Double> {
        let v = vue * SIMD4(p.x, p.y, p.z, 1)
        return SIMD3(v.x, v.y, v.z)
    }

    public func ecran(camera q: SIMD3<Double>) -> CGPoint {
        let d = -q.z
        return CGPoint(x: Double(centre.x) + q.x * focale / d, y: Double(centre.y) - q.y * focale / d)
    }

    /// Point de l'ecran, ou nil s'il est derriere le plan proche.
    public func ecran(_ p: SIMD3<Double>) -> CGPoint? {
        let q = camera(p)
        return -q.z >= Self.proche ? ecran(camera: q) : nil
    }

    public func profondeur(_ p: SIMD3<Double>) -> Double { -camera(p).z }

    /// Points de l'ecran par unite du monde, a la profondeur de `p`.
    public func pxParUnite(_ p: SIMD3<Double>) -> Double { focale / max(0.01, profondeur(p)) }

    /// Polygone plan du monde, coupe par le plan proche (Sutherland-Hodgman) ; nil s'il n'en reste rien.
    public func polygone(_ pts: [SIMD3<Double>]) -> [CGPoint]? {
        let q = pts.map(camera)
        var sortie: [SIMD3<Double>] = []
        sortie.reserveCapacity(q.count + 2)
        for i in q.indices {
            let a = q[i], b = q[(i + 1) % q.count]
            let da = -a.z - Self.proche, db = -b.z - Self.proche
            if da >= 0 { sortie.append(a) }
            if (da >= 0) != (db >= 0) { sortie.append(a + (b - a) * (da / (da - db))) }
        }
        return sortie.count >= 3 ? sortie.map { ecran(camera: $0) } : nil
    }

    /// Segment du monde coupe par le plan proche.
    public func segment(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> (CGPoint, CGPoint)? {
        var qa = camera(a), qb = camera(b)
        let da = -qa.z - Self.proche, db = -qb.z - Self.proche
        if da < 0 && db < 0 { return nil }
        if da < 0 {
            qa += (qb - qa) * (da / (da - db))
        } else if db < 0 {
            qb += (qa - qb) * (db / (db - da))
        }
        return (ecran(camera: qa), ecran(camera: qb))
    }

    /// Ligne brisee (fermee ou non), en morceaux devant le plan proche.
    public func polyligne(_ pts: [SIMD3<Double>], fermee: Bool) -> [[CGPoint]] {
        var morceaux: [[CGPoint]] = []
        var courant: [CGPoint] = []
        let n = fermee ? pts.count : pts.count - 1
        for i in 0..<max(0, n) {
            guard let (a, b) = segment(pts[i], pts[(i + 1) % pts.count]) else {
                if !courant.isEmpty { morceaux.append(courant) }
                courant = []
                continue
            }
            if let f = courant.last, abs(f.x - a.x) + abs(f.y - a.y) < 0.01 {
                courant.append(b)
            } else {
                if !courant.isEmpty { morceaux.append(courant) }
                courant = [a, b]
            }
        }
        if !courant.isEmpty { morceaux.append(courant) }
        return morceaux
    }

    /// Point du plan horizontal y = `hauteur` vise par un point de l'ecran ; nil s'il est derriere l'oeil.
    public func sol(_ point: CGPoint, hauteur h: Double) -> SIMD3<Double>? {
        let dir = droite * ((Double(point.x) - Double(centre.x)) / focale)
            + haut * ((Double(centre.y) - Double(point.y)) / focale) - arriere
        guard abs(dir.y) > 1e-12 else { return nil }
        let s = (h - oeil.y) / dir.y
        return s > 0 ? oeil + dir * s : nil
    }

    /// Affine qui envoie le disque unite sur l'ellipse, projetee, d'un disque horizontal (degrade d'un
    /// plateau) ; nil si un point cardinal est derriere l'oeil ou si l'ellipse est plate.
    public func disque(_ c: SIMD3<Double>, _ r: Double) -> CGAffineTransform? {
        guard let o = ecran(c), let xp = ecran(c + SIMD3(r, 0, 0)), let xm = ecran(c - SIMD3(r, 0, 0)),
              let zp = ecran(c + SIMD3(0, 0, r)), let zm = ecran(c - SIMD3(0, 0, r)) else { return nil }
        let m = CGAffineTransform(a: (xp.x - xm.x) / 2, b: (xp.y - xm.y) / 2, c: (zp.x - zm.x) / 2,
                                  d: (zp.y - zm.y) / 2, tx: o.x, ty: o.y)
        return abs(m.a * m.d - m.b * m.c) > 1e-3 ? m : nil
    }

    /// Contour exact d'une sphere en perspective : l'ellipse ou le cone tangent depuis l'oeil coupe le
    /// plan de l'image (un cercle seulement dans l'axe). Rend l'affine qui envoie le disque unite sur
    /// cette ellipse ; nil si l'oeil est dans la sphere ou trop pres d'elle.
    public func contourSphere(_ c: SIMD3<Double>, _ r: Double) -> CGAffineTransform? {
        let q = camera(c)
        let d = simd_length(q)
        guard d > r * 1.0001, -q.z > Self.proche else { return nil }
        let sinA = r / d, cosA = (1 - sinA * sinA).squareRoot()
        let cosT = -q.z / d, sinT = max(0, 1 - cosT * cosT).squareRoot()
        let den = cosT * cosT - sinA * sinA
        guard den > 1e-4 else { return nil }
        let decalage = focale * sinT * cosT / den, a = focale * sinA * cosA / den, b = focale * sinA / den.squareRoot()
        var u = SIMD2(q.x, -q.y)
        u = simd_length(u) > 1e-9 ? simd_normalize(u) : SIMD2(1, 0)
        return CGAffineTransform(a: u.x * a, b: u.y * a, c: -u.y * b, d: u.x * b,
                                 tx: Double(centre.x) + u.x * decalage, ty: Double(centre.y) + u.y * decalage)
    }
}

/// Geometrie de la maison pour la camera (spec, section 4.4) : plateaux cote a cote en 2D, empiles
/// en 3D, sphere de la maison, boite de cadrage de la 2D.
public struct GeometrieMaison: Hashable, Sendable {
    public static let hauteurBloc3D = 2.4
    /// Bande des noms d'etage au-dessus des plateaux, en 2D (34 px).
    public static let bandeNomsEtages = 34 / CartesPieces.px

    public let rayons: [Double]
    public let centres2D: [Double]
    /// Pas entre deux etages en 3D : 1,5 fois le plus grand rayon.
    public let pasEtage: Double
    public let centreSphere: SIMD3<Double>
    public let rayonSphere: Double
    public let boite: Boite
    public let cible2D: SIMD3<Double>

    public struct Boite: Hashable, Sendable {
        public var x0, x1, z0, z1: Double
    }

    public init(rayons: [Double]) {
        let r = rayons.isEmpty ? [DispositionPieces.marge] : rayons
        self.rayons = r
        centres2D = DispositionPieces.centres2D(rayons: r)
        let rmax = r.max() ?? 1
        pasEtage = 1.5 * rmax
        let yHaut = Double(r.count - 1) * pasEtage
        centreSphere = SIMD3(0, (yHaut + Self.hauteurBloc3D) / 2, 0)
        rayonSphere = hypot(rmax + 0.8, (yHaut + Self.hauteurBloc3D) / 2 + 1.4) + 0.4
        boite = Boite(x0: centres2D[0] - r[0], x1: centres2D[r.count - 1] + r[r.count - 1],
                      z0: -rmax - Self.bandeNomsEtages, z1: rmax)
        cible2D = SIMD3((boite.x0 + boite.x1) / 2, 0, (boite.z0 + boite.z1) / 2)
    }

    /// Centre du plateau `e` a l'avancement `u` de la bascule (0 : 2D, 1 : 3D).
    public func centrePlateau(_ e: Int, _ u: Double) -> SIMD3<Double> {
        let a = SIMD3(centres2D[e], 0, 0), b = SIMD3(0, Double(e) * pasEtage, 0)
        return a + (b - a) * u
    }

    /// Hauteur des blocs : 0,04 en 2D, 2,44 en 3D.
    public static func hauteurBloc(_ u: Double) -> Double { 0.04 + hauteurBloc3D * u }
}

/// Camera de la vue (spec, section 7) : vues d'ensemble, envol, vols, zoom vers le curseur, bornes.
public enum CameraScene {
    public static let champ2D = 2.0
    public static let champ3D = 40.0
    public static let inclinaison3D = 0.95
    public static let orbite3D = -0.75
    public static let dureeEnvol = 2.6
    public static let dureeVol = 1.3
    /// « Reduire les animations » : l'envol devient un fondu.
    public static let dureeFondu = 0.3
    /// Rotation lente : un tour en deux minutes.
    public static let dureeTour = 120.0

    /// Rampe de la maquette : cubique entree-sortie.
    public static func rampe(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    /// Hauteur de vue de la vue d'ensemble 2D, centree sur la boite de cadrage.
    public static func vue2D(_ g: GeometrieMaison, aspect: Double) -> Double {
        max((g.boite.z1 - g.boite.z0) * 1.1, (g.boite.x1 - g.boite.x0) * 1.05 / aspect)
    }

    /// Hauteur de vue de la vue d'ensemble 3D, centree sur la sphere.
    public static func vue3D(_ g: GeometrieMaison, aspect: Double) -> Double {
        2.4 * g.rayonSphere * max(1, 1 / aspect)
    }

    public static func vue(_ g: GeometrieMaison, aspect: Double, u: Double) -> Double {
        vue2D(g, aspect: aspect) + (vue3D(g, aspect: aspect) - vue2D(g, aspect: aspect)) * u
    }

    /// Champ a l'avancement u de la bascule : 2 + 38 u^1,6 degres.
    public static func champ(_ u: Double) -> Double { champ2D + (champ3D - champ2D) * pow(u, 1.6) }

    /// Pose canonique a l'avancement u de la bascule : vue d'ensemble 2D (u = 0), 3D (u = 1).
    public static func canonique(_ g: GeometrieMaison, aspect: Double, u: Double) -> Orbite {
        let f = champ(u)
        return Orbite(cible: g.cible2D + (g.centreSphere - g.cible2D) * u,
                      distance: Orbite.distance(pourHauteur: vue(g, aspect: aspect, u: u), champ: f),
                      azimut: orbite3D * u, inclinaison: 0.0001 + inclinaison3D * u, champ: f)
    }

    /// Bornes de la distance : de 3 unites de hauteur de vue a 3 fois la vue d'ensemble en 2D ; de 5
    /// unites a 2,5 fois la vue d'ensemble en 3D.
    public static func bornes(_ g: GeometrieMaison, aspect: Double, troisD: Bool, champ: Double) -> ClosedRange<Double> {
        if troisD {
            return 5...max(5, Orbite.distance(pourHauteur: vue3D(g, aspect: aspect) * 2.5, champ: champ))
        }
        let bas = Orbite.distance(pourHauteur: 3, champ: champ)
        return bas...max(bas, Orbite.distance(pourHauteur: vue2D(g, aspect: aspect) * 3, champ: champ))
    }

    /// Zoom d'un pas (`facteur` : log du rapport des distances), borne ; vers `ancre` si elle est donnee
    /// (le point du monde sous le curseur, qui reste sous le curseur).
    public static func zoomer(_ o: Orbite, facteur: Double, ancre: SIMD3<Double>?, bornes: ClosedRange<Double>) -> Orbite {
        var r = o
        let d = min(bornes.upperBound, max(bornes.lowerBound, o.distance * exp(facteur)))
        if let a = ancre { r.cible = a + (o.cible - a) * (d / o.distance) }
        r.distance = d
        return r
    }

    /// Direction de l'oeil pour un vol : celle de la camera en 3D, la verticale en 2D.
    public static func directionVue(_ o: Orbite, troisD: Bool) -> SIMD3<Double> {
        troisD ? o.arriere : simd_normalize(SIMD3(0, 1, 0.0001))
    }

    /// Vol vers une piece isolee : hauteur de vue max(largeur / aspect, profondeur) 1,3 1,8 + 6 unites.
    public static func volVersPiece(_ o: Orbite, centre: SIMD3<Double>, largeur: Double, profondeur: Double,
                                    aspect: Double, troisD: Bool) -> Vol {
        let d = Orbite.distance(pourHauteur: max(largeur / aspect, profondeur) * 1.3 * 1.8 + 6, champ: o.champ)
        return Vol(depuis: o, oeil: centre + directionVue(o, troisD: troisD) * d, cible: centre)
    }

    /// Vol de retour a la vue d'ensemble, a l'avancement u de la bascule.
    public static func volVersEnsemble(_ o: Orbite, _ g: GeometrieMaison, aspect: Double, u: Double, troisD: Bool) -> Vol {
        let c = g.cible2D + (g.centreSphere - g.cible2D) * u
        let d = Orbite.distance(pourHauteur: vue(g, aspect: aspect, u: u), champ: o.champ)
        return Vol(depuis: o, oeil: c + directionVue(o, troisD: troisD) * d, cible: c)
    }
}

/// Vol de camera (isolement d'une piece, retour a la maison) : oeil et cible interpoles, en rampe.
public struct Vol: Hashable, Sendable {
    public var oeil0, cible0, oeil1, cible1: SIMD3<Double>

    public init(depuis o: Orbite, oeil: SIMD3<Double>, cible: SIMD3<Double>) {
        oeil0 = o.oeil
        cible0 = o.cible
        oeil1 = oeil
        cible1 = cible
    }

    /// Camera a l'avancement q (0 a 1, en temps) du vol.
    public func orbite(_ q: Double, depuis o: Orbite) -> Orbite {
        let e = CameraScene.rampe(min(1, max(0, q)))
        var r = o
        r.placer(oeil: oeil0 + (oeil1 - oeil0) * e, cible: cible0 + (cible1 - cible0) * e)
        return r
    }
}

/// Envol entre la 2D et la 3D (spec, section 7) : 2,6 s en rampe cubique ; il part de la vue
/// courante, zoomee ou tournee, sans saut : l'ecart a la pose canonique s'efface pendant l'envol.
public struct Envol: Hashable, Sendable {
    public var depart: Double
    public var arrivee: Double
    public var ecartCible: SIMD3<Double>
    public var ecartLogDistance: Double
    public var ecartAzimut: Double
    public var ecartInclinaison: Double

    public init(depuis o: Orbite, t: Double, vers arrivee: Double, geometrie g: GeometrieMaison, aspect: Double) {
        let c = CameraScene.canonique(g, aspect: aspect, u: t)
        depart = t
        self.arrivee = arrivee
        ecartCible = o.cible - c.cible
        ecartLogDistance = log(o.distance / c.distance)
        ecartAzimut = remainder(o.azimut - c.azimut, 2 * .pi)
        ecartInclinaison = o.inclinaison - c.inclinaison
    }

    /// Avancement t de la bascule et camera, a l'avancement q (0 a 1, en temps) de l'envol.
    public func pose(_ q: Double, geometrie g: GeometrieMaison, aspect: Double) -> (t: Double, orbite: Orbite) {
        let e = CameraScene.rampe(min(1, max(0, q)))
        let t = depart + (arrivee - depart) * e
        var o = CameraScene.canonique(g, aspect: aspect, u: t)
        let r = 1 - e
        o.cible += ecartCible * r
        o.distance *= exp(ecartLogDistance * r)
        o.azimut += ecartAzimut * r
        o.inclinaison += ecartInclinaison * r
        return (t, o)
    }
}
