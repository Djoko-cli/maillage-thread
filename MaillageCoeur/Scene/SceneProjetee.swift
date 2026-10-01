import CoreGraphics
import Foundation
import simd

/// Couleur sRGB, composantes de 0 a 1.
public struct Teinte: Hashable, Sendable {
    public var r, g, b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public init(hexa v: UInt32) {
        self.init(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255, b: Double(v & 0xFF) / 255)
    }

    /// Eclairee comme dans la maquette : la couleur passe en lineaire, y est multipliee par `k`, puis
    /// revient en sRGB.
    public func eclairee(_ k: Double) -> Teinte {
        func lineaire(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        func srgb(_ c: Double) -> Double {
            let c = min(1, max(0, c))
            return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
        }
        return Teinte(r: srgb(lineaire(r) * k), g: srgb(lineaire(g) * k), b: srgb(lineaire(b) * k))
    }
}

/// Etat anime de la vue, pose a chaque image : ce que la projection lit en plus de la scene.
public struct EtatAnime: Hashable, Sendable {
    /// Bascule, adoucie : 0 en 2D, 1 en 3D.
    public var t: Double
    /// Isolement general d'une piece : 0 a 1, lineaire (la projection l'adoucit).
    public var s: Double
    /// Part propre a chaque piece de l'isolement : 0 a 1.
    public var fk: [Double]
    /// Piece isolee (ou qui l'etait, pendant le retour).
    public var focus: Int?
    public var survol: String?
    public var selection: String?

    public init(t: Double = 0, s: Double = 0, fk: [Double], focus: Int? = nil, survol: String? = nil,
                selection: String? = nil) {
        self.t = t
        self.s = s
        self.fk = fk
        self.focus = focus
        self.survol = survol
        self.selection = selection
    }
}

/// Repere « ailleurs » d'un enfant de la piece isolee dont le parent est dans une autre piece.
public struct Ailleurs: Hashable, Sendable {
    public enum Sens: Hashable, Sendable {
        /// Parent au meme etage (↗), a un etage en dessous (↓), au-dessus (↑).
        case memeEtage, dessous, dessus
    }

    public var enfant: String
    public var parent: String
    public var piece: Int
    public var etage: Int
    public var sens: Sens
}

/// Ce que la camera rend au moteur `Canvas` (spec, section 9), en coordonnees de l'ecran : le contrat
/// entre la scene et le moteur. Couches, sans tri de profondeur global : plateaux et equateur, blocs
/// (du plus loin au plus proche, faces tournees vers l'oeil), liens enfant-parent (avec les
/// rattachements et les fils « ailleurs »), liens entre routeurs, pastilles, liseré de la sphere ;
/// puis les traits de rappel et les noms, que le moteur pose avec `PlacementNoms`.
public struct SceneProjetee: Sendable {
    public struct Plateau: Sendable {
        public var etage: Int
        public var polygone: [CGPoint]
        public var contour: [[CGPoint]]
        /// Envoie le disque unite sur l'ellipse du plateau (degrade radial) ; nil si degenere.
        public var disque: CGAffineTransform?
        public var opacite: Double
        public var profondeur: Double
    }

    public struct Equateur: Sendable {
        public var contour: [[CGPoint]]
        public var opacite: Double
        public var profondeur: Double
    }

    public struct Face: Sendable {
        public var points: [CGPoint]
        public var teinte: Teinte
    }

    public struct Bloc: Sendable {
        public var piece: Int
        /// Faces tournees vers l'oeil, eclairees.
        public var faces: [Face]
        public var aretes: [(CGPoint, CGPoint)]
        public var teinte: Teinte
        public var opaciteVerre: Double
        public var opaciteAretes: Double
        public var profondeur: Double
    }

    public struct Lien: Sendable {
        public var a, b: CGPoint
        public var genre: GrapheReseau.Lien.Genre
        public var qualite: Int?
        public var opacite: Double
        public var eclaire: Bool
    }

    public struct Fil: Sendable {
        public var a, b: CGPoint
        public var opacite: Double
    }

    public struct Disque: Sendable {
        public var noeud: String
        public var centre: CGPoint
        public var rayon: Double
        public var opacite: Double
        public var profondeur: Double
    }

    public struct Sphere: Sendable {
        /// Envoie le disque unite sur le contour exact de la sphere.
        public var transfo: CGAffineTransform
        public var force: Double
    }

    /// Eclairage des faces de la maquette : ambiante 2,2 et directionnelle 1,6 venant de
    /// (-10, 30, 14), sur un materiau de Lambert, (2,2 + 1,6 n.l) / pi ; faces +x, -x, +y, -y, +z, -z.
    public static let lambert: [Double] = {
        let l = simd_normalize(SIMD3<Double>(-10, 30, 14))
        let normales: [SIMD3<Double>] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]
        return normales.map { (2.2 + 1.6 * max(0, simd_dot($0, l))) / .pi }
    }()

    static let aretesBloc = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)]

    public var plateaux: [Plateau] = []
    public var equateur: Equateur?
    /// Du plus loin au plus proche.
    public var blocs: [Bloc] = []
    public var liensEnfants: [Lien] = []
    public var liensRouteurs: [Lien] = []
    public var fils: [Fil] = []
    /// Du plus loin au plus proche.
    public var disques: [Disque] = []
    public var sphere: Sphere?
    public var niveau: NiveauZoom = .tous
    /// Echelle k du zoom semantique : points par unite a la cible, divises par 24.
    public var echelle = 1.0
    public var ancresNoeuds: [String: CGRect] = [:]
    public var ancresPieces: [Int: CGRect] = [:]
    public var ancresEtages: [Int: CGRect] = [:]
    public var ancreMaison: CGRect?
    public var ancresAilleurs: [String: CGRect] = [:]
    /// Reperes « ailleurs » de la piece isolee.
    public var ailleurs: [Ailleurs] = []
    /// Centre de chaque noeud dans le monde.
    public var centresNoeuds: [String: SIMD3<Double>] = [:]

    public init() {}

    /// Pose la scene a l'etat `etat` et la projette par `orbite` dans `cadre` (la place utile de la
    /// vue). `positions` : centre de chaque piece dans son plateau (celles de la disposition, ou la
    /// piece qu'on glisse).
    public init(scene: ScenePieces, cartes: [CartesPieces.Carte], positions: [SIMD2<Double>], geometrie g: GeometrieMaison,
                etat: EtatAnime, orbite: Orbite, cadre: CGRect) {
        let proj = ProjectionScene(orbite, cadre: cadre)
        let t = etat.t
        let h = GeometrieMaison.hauteurBloc(t)
        let es = CameraScene.rampe(etat.s), fo = 1 - es
        let oeil = orbite.oeil

        // Plateaux : polygone exact de 128 points ; degrade par l'affine du disque.
        for e in g.rayons.indices {
            let c = g.centrePlateau(e, t), r = g.rayons[e]
            let pts = Self.cercle(c, r, 128)
            guard let poly = proj.polygone(pts) else { continue }
            plateaux.append(Plateau(etage: e, polygone: poly, contour: proj.polyligne(pts, fermee: true),
                                    disque: proj.disque(c, r), opacite: fo, profondeur: proj.profondeur(c)))
        }

        // Sphere de la maison : liseré et equateur, pendant l'envol et en 3D.
        let rs = g.rayonSphere * (0.8 + 0.2 * t)
        if 0.18 * t * fo > 0.002 {
            equateur = Equateur(contour: proj.polyligne(Self.cercle(g.centreSphere, rs, 192), fermee: true),
                                opacite: 0.18 * t * fo, profondeur: proj.profondeur(g.centreSphere))
        }
        let force = t * t * fo
        if force > 0.002, let m = proj.contourSphere(g.centreSphere, rs) {
            sphere = Sphere(transfo: m, force: force)
        }

        // Pieces : blocs de verre ; noeuds a mi-hauteur de leur bloc en 3D.
        var voiles = [Double](repeating: 1, count: scene.pieces.count)
        var mondes: [String: SIMD3<Double>] = [:]
        var centres = [SIMD3<Double>](repeating: .zero, count: scene.pieces.count)
        var echelles = [Double](repeating: 1, count: scene.pieces.count)
        for (i, pc) in scene.pieces.enumerated() where i < cartes.count && i < positions.count {
            let c = g.centrePlateau(pc.etage, t)
            let fe = CameraScene.rampe(i < etat.fk.count ? etat.fk[i] : 0)
            let voile = 1 - es * (1 - fe), f = 1 + 0.3 * fe
            voiles[i] = voile
            echelles[i] = f
            let vis = 1 - 0.85 * (1 - voile)
            let bx = c.x + positions[i].x, bz = c.z + positions[i].y
            let y0 = c.y + 0.02, y1 = y0 + h
            let x0 = bx - cartes[i].largeur * f / 2, x1 = bx + cartes[i].largeur * f / 2
            let z0 = bz - cartes[i].profondeur * f / 2, z1 = bz + cartes[i].profondeur * f / 2
            centres[i] = SIMD3(bx, (y0 + y1) / 2, bz)
            let k: [SIMD3<Double>] = [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1],
                                      [x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]]
            let teinte = Teinte(hexa: ScenePieces.teintes[pc.teinte % ScenePieces.teintes.count])
            var faces: [Face] = []
            func face(_ q: [Int], _ n: Int) {
                guard let p = proj.polygone(q.map { k[$0] }) else { return }
                faces.append(Face(points: p, teinte: teinte.eclairee(Self.lambert[n])))
            }
            if oeil.x > x1 { face([1, 2, 6, 5], 0) }
            if oeil.x < x0 { face([0, 4, 7, 3], 1) }
            if oeil.y > y1 { face([4, 5, 6, 7], 2) }
            if oeil.y < y0 { face([0, 3, 2, 1], 3) }
            if oeil.z > z1 { face([3, 7, 6, 2], 4) }
            if oeil.z < z0 { face([0, 1, 5, 4], 5) }
            let aretes = Self.aretesBloc.compactMap { proj.segment(k[$0.0], k[$0.1]) }
            blocs.append(Bloc(piece: i, faces: faces, aretes: aretes, teinte: teinte, opaciteVerre: vis * (0.13 + 0.05 * t),
                              opaciteAretes: vis * 0.75, profondeur: proj.profondeur(centres[i])))
            let coins = k.compactMap { proj.ecran($0) }
            if coins.count == 8 { ancresPieces[i] = Self.boite(coins) }
            for (r, id) in pc.noeuds.enumerated() where r < cartes[i].places.count {
                let l = cartes[i].places[r]
                mondes[id] = SIMD3(bx + l.x * f, c.y + 0.1 + 0.5 * h * t, bz + l.y * f)
            }
        }
        blocs.sort { $0.profondeur > $1.profondeur }
        centresNoeuds = mondes

        // Pastilles : le rayon suit l'echelle, sans depasser 1,1 fois le rayon naturel, 3 px au moins.
        for n in scene.noeuds {
            guard let p = mondes[n.id], let e = proj.ecran(p) else { continue }
            let r = min(n.rayon * 1.1, max(3, n.rayon * proj.pxParUnite(p) / CartesPieces.px))
            disques.append(Disque(noeud: n.id, centre: e, rayon: r, opacite: 1 - 0.8 * (1 - voiles[n.piece]),
                                  profondeur: proj.profondeur(p)))
            ancresNoeuds[n.id] = CGRect(x: Double(e.x) - r, y: Double(e.y) - r, width: 2 * r, height: 2 * r)
        }
        disques.sort { $0.profondeur > $1.profondeur }

        // Liens : estompes avec leurs pieces ; eclaires au survol (ou a la selection) d'un bout.
        for l in scene.liens {
            guard let a = mondes[l.de], let b = mondes[l.vers], let (pa, pb) = proj.segment(a, b),
                  let na = scene.noeud(l.de), let nb = scene.noeud(l.vers) else { continue }
            let poids = 1 - 0.85 * (1 - max(voiles[na.piece], voiles[nb.piece]))
            let eclaire = [l.de, l.vers].contains { $0 == etat.survol || $0 == etat.selection }
            if l.genre == .radio {
                liensRouteurs.append(Lien(a: pa, b: pb, genre: .radio, qualite: l.qualite, opacite: 0.95 * poids,
                                          eclaire: eclaire))
            } else {
                liensEnfants.append(Lien(a: pa, b: pb, genre: l.genre, qualite: l.qualite,
                                         opacite: eclaire ? 0.85 : 0.28 * poids, eclaire: eclaire))
            }
        }

        // Reperes « ailleurs » de la piece isolee : un fil vers le bord de la piece, du cote du parent.
        if let i = etat.focus, i < scene.pieces.count, i < cartes.count {
            let fe = CameraScene.rampe(i < etat.fk.count ? etat.fk[i] : 0)
            ailleurs = Self.reperes(scene, focus: i)
            for a in ailleurs {
                guard let e = mondes[a.enfant], let pp = mondes[a.parent] else { continue }
                var dir = pp - centres[i]
                dir.y = 0
                dir = simd_length_squared(dir) < 1e-6 ? SIMD3(1, 0, 0) : simd_normalize(dir)
                var m = centres[i] + dir * (max(cartes[i].largeur, cartes[i].profondeur) * echelles[i] / 2 + 2.6)
                m.y = e.y
                if let (pa, pb) = proj.segment(e, m) { fils.append(Fil(a: pa, b: pb, opacite: 0.8 * fe)) }
                if let q = proj.ecran(m) { ancresAilleurs[a.enfant] = CGRect(x: q.x - 3, y: q.y - 3, width: 6, height: 6) }
            }
        }

        // Zoom semantique, noms d'etage (au bord du plateau, en haut de l'ecran) et de la maison.
        echelle = proj.pxParUnite(orbite.cible) / CartesPieces.px
        niveau = NiveauZoom(echelle: echelle)
        var hh = orbite.haut
        hh.y = 0
        let hautHorizontal = simd_length_squared(hh) < 1e-8 ? SIMD3<Double>(0, 0, -1) : simd_normalize(hh)
        for e in g.rayons.indices {
            if let p = proj.ecran(g.centrePlateau(e, t) + hautHorizontal * g.rayons[e]) {
                ancresEtages[e] = CGRect(origin: p, size: .zero)
            }
        }
        ancreMaison = proj.ecran(g.centreSphere + orbite.haut * rs).map { CGRect(origin: $0, size: .zero) }
    }

    /// Reperes « ailleurs » d'une piece isolee : ses enfants dont le parent (vu par la sonde) est dans
    /// une autre piece, dans l'ordre de ses lignes.
    public static func reperes(_ scene: ScenePieces, focus i: Int) -> [Ailleurs] {
        let pc = scene.pieces[i]
        return pc.noeuds.compactMap { id in
            guard let parent = scene.liens.first(where: { $0.genre == .parent && $0.de == id })?.vers,
                  let np = scene.noeud(parent), np.piece != i else { return nil }
            let ep = scene.pieces[np.piece].etage
            return Ailleurs(enfant: id, parent: parent, piece: np.piece, etage: ep,
                            sens: ep == pc.etage ? .memeEtage : ep < pc.etage ? .dessous : .dessus)
        }
    }

    /// Piece sous un point de l'ecran : la plus proche dont une face le contient.
    public func piece(sous p: CGPoint) -> Int? {
        blocs.reversed().first { b in b.faces.contains { Self.contient($0.points, p) } }?.piece
    }

    /// Noeud sous un point de l'ecran : la pastille la plus proche, a `marge` points pres de son bord.
    public func noeud(sous p: CGPoint, marge: Double = 8) -> String? {
        var meilleur: (String, Double)?
        for d in disques where d.opacite > 0.5 {
            let e = hypot(Double(d.centre.x - p.x), Double(d.centre.y - p.y))
            if e <= d.rayon + marge, e < meilleur?.1 ?? .infinity { meilleur = (d.noeud, e) }
        }
        return meilleur?.0
    }

    /// Point dans un polygone (regle pair-impair).
    public static func contient(_ poly: [CGPoint], _ p: CGPoint) -> Bool {
        var dedans = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { dedans.toggle() }
            j = i
        }
        return dedans
    }

    static func cercle(_ c: SIMD3<Double>, _ r: Double, _ n: Int) -> [SIMD3<Double>] {
        (0..<n).map { i in
            let a = Double(i) / Double(n) * 2 * .pi
            return c + SIMD3(r * cos(a), 0, r * sin(a))
        }
    }

    /// Boite englobante de points de l'ecran.
    public static func boite(_ pts: [CGPoint]) -> CGRect {
        var x0 = CGFloat.infinity, y0 = CGFloat.infinity, x1 = -CGFloat.infinity, y1 = -CGFloat.infinity
        for p in pts {
            x0 = min(x0, p.x)
            y0 = min(y0, p.y)
            x1 = max(x1, p.x)
            y1 = max(y1, p.y)
        }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}
