import CoreGraphics
import Foundation
import simd
import Testing
@testable import MaillageCoeur

@Suite("Scene : camera, envol, zoom")
struct CameraSceneTests {
    /// La maison de la maquette : deux plateaux, dans une fenetre de 1600 x 972.
    static let geometrie = GeometrieMaison(rayons: [15.2, 16.0])
    static let cadre = CGRect(x: 0, y: 0, width: 1600, height: 972)
    static let aspect = 1600.0 / 972

    static func proche(_ a: CGPoint, _ b: CGPoint, _ e: Double = 1e-6) -> Bool {
        abs(a.x - b.x) < e && abs(a.y - b.y) < e
    }

    /// Vue de dessus, a 10 unites, champ de 90 degres : 30 points par unite ; -z monte a l'ecran.
    /// Le point principal est le centre du cadre, meme decale. Derriere l'oeil : rien.
    @Test func projectionDePointsConnus() throws {
        let o = Orbite(cible: .zero, distance: 10, azimut: 0, inclinaison: 0, champ: 90)
        let p = ProjectionScene(o, cadre: CGRect(x: 0, y: 0, width: 800, height: 600))
        #expect(abs(p.focale - 300) < 1e-9)
        #expect(Self.proche(try #require(p.ecran(.zero)), CGPoint(x: 400, y: 300)))
        #expect(Self.proche(try #require(p.ecran(SIMD3(1, 0, 0))), CGPoint(x: 430, y: 300)))
        #expect(Self.proche(try #require(p.ecran(SIMD3(0, 0, -1))), CGPoint(x: 400, y: 270)))
        #expect(abs(p.pxParUnite(.zero) - 30) < 1e-9)
        #expect(p.ecran(SIMD3(0, 20, 0)) == nil)
        let decale = ProjectionScene(o, cadre: CGRect(x: 100, y: 50, width: 800, height: 600))
        #expect(Self.proche(try #require(decale.ecran(.zero)), CGPoint(x: 500, y: 350)))
        let sol = try #require(decale.sol(CGPoint(x: 530, y: 350), hauteur: 0))
        #expect(abs(sol.x - 1) < 1e-9 && abs(sol.z) < 1e-9)
    }

    /// Debut de l'envol : la vue d'ensemble 2D, la boite de cadrage dans le cadre, marges comprises ;
    /// fin : la sphere cadree, au centre, sur environ 2 / 2,4 de la hauteur.
    @Test func debutEtFinDeLEnvol() throws {
        let g = Self.geometrie
        let e = Envol(depuis: CameraScene.canonique(g, aspect: Self.aspect, u: 0), t: 0, vers: 1, geometrie: g,
                      aspect: Self.aspect)
        let (t0, o0) = e.pose(0, geometrie: g, aspect: Self.aspect)
        #expect(t0 == 0 && o0.champ == 2)
        let p0 = ProjectionScene(o0, cadre: Self.cadre)
        let coins = [SIMD3(g.boite.x0, 0, g.boite.z0), SIMD3(g.boite.x1, 0, g.boite.z1)].compactMap { p0.ecran($0) }
        #expect(coins.count == 2)
        let boite = CGRect(x: coins[0].x, y: coins[0].y, width: 0, height: 0).union(CGRect(origin: coins[1], size: .zero))
        #expect(Self.cadre.contains(boite))
        #expect(boite.width / 1600 > 0.9 || boite.height / 972 > 0.85, "la boite remplit le cadre : \(boite)")
        let (t1, o1) = e.pose(1, geometrie: g, aspect: Self.aspect)
        #expect(t1 == 1 && o1 == CameraScene.canonique(g, aspect: Self.aspect, u: 1))
        let m = try #require(ProjectionScene(o1, cadre: Self.cadre).contourSphere(g.centreSphere, g.rayonSphere))
        let ellipse = CGRect(x: -1, y: -1, width: 2, height: 2).applying(m)
        #expect(Self.cadre.contains(ellipse))
        #expect(ellipse.height / 972 > 0.8 && ellipse.height / 972 < 0.9, "\(ellipse)")
        #expect(abs(ellipse.midX - 800) < 1 && abs(ellipse.midY - 486) < 1)
        let (tm, _) = e.pose(0.5, geometrie: g, aspect: Self.aspect)
        #expect(abs(tm - 0.5) < 1e-12, "rampe cubique : la moitie a mi-temps")
    }

    /// L'envol part de la vue courante, zoomee ou tournee, sans saut, et finit sur la pose canonique.
    @Test func envolSansSaut() {
        let g = Self.geometrie
        var o = CameraScene.canonique(g, aspect: Self.aspect, u: 1)
        o.azimut += 1.3
        o.distance *= 0.6
        o.cible += SIMD3(2, 0, -1)
        let e = Envol(depuis: o, t: 1, vers: 0, geometrie: g, aspect: Self.aspect)
        let (t, debut) = e.pose(0, geometrie: g, aspect: Self.aspect)
        #expect(t == 1)
        #expect(simd_distance(debut.oeil, o.oeil) < 1e-9 && simd_distance(debut.cible, o.cible) < 1e-9)
        #expect(e.pose(1, geometrie: g, aspect: Self.aspect).orbite == CameraScene.canonique(g, aspect: Self.aspect, u: 0))
    }

    /// Le zoom vers le curseur garde le point sous le curseur, a moins de 1e-6 unite, en 2D comme en 3D.
    @Test func zoomVersLeCurseur() throws {
        let g = Self.geometrie
        for u in [0.0, 1.0] {
            let o = CameraScene.canonique(g, aspect: Self.aspect, u: u)
            let curseur = CGPoint(x: 420, y: 610)
            let ancre = try #require(ProjectionScene(o, cadre: Self.cadre).sol(curseur, hauteur: o.cible.y))
            let bornes = CameraScene.bornes(g, aspect: Self.aspect, troisD: u == 1, champ: o.champ)
            let z = CameraScene.zoomer(o, facteur: -0.4, ancre: ancre, bornes: bornes)
            #expect(z.distance < o.distance)
            let apres = try #require(ProjectionScene(z, cadre: Self.cadre).sol(curseur, hauteur: o.cible.y))
            #expect(simd_distance(apres, ancre) < 1e-6, "u = \(u) : \(simd_distance(apres, ancre))")
        }
    }

    /// Bornes du zoom : 3 unites de hauteur de vue a 3 fois la vue d'ensemble en 2D ; 5 unites de
    /// distance a 2,5 fois la vue d'ensemble en 3D.
    @Test func bornesDuZoom() {
        let g = Self.geometrie
        let o2 = CameraScene.canonique(g, aspect: Self.aspect, u: 0)
        let b2 = CameraScene.bornes(g, aspect: Self.aspect, troisD: false, champ: o2.champ)
        #expect(CameraScene.zoomer(o2, facteur: -20, ancre: nil, bornes: b2).distance
                == Orbite.distance(pourHauteur: 3, champ: 2))
        #expect(CameraScene.zoomer(o2, facteur: 20, ancre: nil, bornes: b2).distance
                == Orbite.distance(pourHauteur: CameraScene.vue2D(g, aspect: Self.aspect) * 3, champ: 2))
        let o3 = CameraScene.canonique(g, aspect: Self.aspect, u: 1)
        let b3 = CameraScene.bornes(g, aspect: Self.aspect, troisD: true, champ: o3.champ)
        #expect(CameraScene.zoomer(o3, facteur: -20, ancre: nil, bornes: b3).distance == 5)
        #expect(abs(CameraScene.zoomer(o3, facteur: 20, ancre: nil, bornes: b3).distance
                    - Orbite.distance(pourHauteur: CameraScene.vue3D(g, aspect: Self.aspect) * 2.5, champ: 40)) < 1e-9)
    }

    /// Vol vers une piece : la cible au centre de la piece, a la hauteur de vue
    /// max(largeur / aspect, profondeur) 1,3 1,8 + 6 ; il part de la camera, sans saut.
    @Test func volVersUnePiece() {
        let o = CameraScene.canonique(Self.geometrie, aspect: Self.aspect, u: 0)
        let centre = SIMD3(-12.0, 0.5, 3.0)
        let v = CameraScene.volVersPiece(o, centre: centre, largeur: 8.75, profondeur: 9.3, aspect: Self.aspect,
                                         troisD: false)
        let debut = v.orbite(0, depuis: o)
        #expect(simd_distance(debut.oeil, o.oeil) < 1e-9 && simd_distance(debut.cible, o.cible) < 1e-9)
        let fin = v.orbite(1, depuis: o)
        #expect(simd_distance(fin.cible, centre) < 1e-9)
        let attendue = Orbite.distance(pourHauteur: max(8.75 / Self.aspect, 9.3) * 1.3 * 1.8 + 6, champ: 2)
        #expect(abs(fin.distance - attendue) < 1e-6)
        #expect(fin.champ == o.champ)
    }

    /// Orbite sans NaN ni infini.
    static func finie(_ o: Orbite) -> Bool {
        [o.cible.x, o.cible.y, o.cible.z, o.distance, o.azimut, o.inclinaison, o.champ].allSatisfy(\.isFinite)
    }

    /// Un aspect nul, negatif, non fini ou minuscule (cadre vide pendant une mise en page) laisse la
    /// camera finie : vue d'ensemble, bornes, zoom, envol et vols.
    @Test(arguments: [0, -1, Double.nan, Double.infinity, 1e-9])
    func aspectDegenere(_ aspect: Double) {
        let g = Self.geometrie
        for u in [0.0, 1.0] {
            let o = CameraScene.canonique(g, aspect: aspect, u: u)
            #expect(Self.finie(o), "canonique, u = \(u)")
            let b = CameraScene.bornes(g, aspect: aspect, troisD: u == 1, champ: o.champ)
            #expect(b.lowerBound.isFinite && b.upperBound.isFinite, "bornes, u = \(u)")
            #expect(Self.finie(CameraScene.zoomer(o, facteur: -0.4, ancre: SIMD3(3, 0, -2), bornes: b)), "zoom, u = \(u)")
            #expect(Self.finie(CameraScene.zoomer(o, facteur: 0.4, ancre: nil, bornes: b)), "dezoom, u = \(u)")
            let e = Envol(depuis: o, t: u, vers: 1 - u, geometrie: g, aspect: aspect)
            for q in [0.0, 0.5, 1.0] {
                #expect(Self.finie(e.pose(q, geometrie: g, aspect: aspect).orbite), "envol, u = \(u), q = \(q)")
            }
            let piece = CameraScene.volVersPiece(o, centre: SIMD3(-12, 0.5, 3), largeur: 8.75, profondeur: 9.3,
                                                 aspect: aspect, troisD: u == 1)
            let ensemble = CameraScene.volVersEnsemble(o, g, aspect: aspect, u: u, troisD: u == 1)
            for q in [0.0, 0.5, 1.0] {
                #expect(Self.finie(piece.orbite(q, depuis: o)), "vol vers une piece, u = \(u), q = \(q)")
                #expect(Self.finie(ensemble.orbite(q, depuis: o)), "vol vers l'ensemble, u = \(u), q = \(q)")
            }
        }
    }

    /// Un facteur de zoom non fini laisse la camera inchangee.
    @Test func zoomNonFini() {
        let g = Self.geometrie
        let o = CameraScene.canonique(g, aspect: Self.aspect, u: 0)
        let b = CameraScene.bornes(g, aspect: Self.aspect, troisD: false, champ: o.champ)
        for f in [Double.nan, .infinity, -.infinity] {
            #expect(CameraScene.zoomer(o, facteur: f, ancre: SIMD3(3, 0, -2), bornes: b) == o, "facteur \(f)")
            #expect(CameraScene.zoomer(o, facteur: f, ancre: nil, bornes: b) == o, "facteur \(f)")
        }
    }

    /// Geometrie : plateaux empiles de 1,5 fois le plus grand rayon ; sphere et boite de la spec.
    @Test func geometrie() {
        let g = Self.geometrie
        #expect(g.pasEtage == 24)
        #expect(g.centreSphere == SIMD3(0, (24 + 2.4) / 2, 0))
        #expect(abs(g.rayonSphere - (hypot(16.8, 13.2 + 1.4) + 0.4)) < 1e-12)
        #expect(g.centrePlateau(1, 1) == SIMD3(0, 24, 0))
        #expect(g.centrePlateau(0, 0).x == g.centres2D[0])
        #expect(abs(g.boite.z0 - (-16 - 34.0 / 24)) < 1e-12 && g.boite.z1 == 16)
        #expect(GeometrieMaison.hauteurBloc(0) == 0.04 && abs(GeometrieMaison.hauteurBloc(1) - 2.44) < 1e-12)
    }
}
