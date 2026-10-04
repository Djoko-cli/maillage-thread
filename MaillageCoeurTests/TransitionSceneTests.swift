import CoreGraphics
import Foundation
import simd
import Testing
@testable import MaillageCoeur

/// Le glissement d'une disposition a l'autre (polissage D, section 1) : les poses par cle, en route en 0,9 s en
/// cubique entree-sortie, les fondus de 0,3 s, l'interruption sans saut, « Reduire les animations » ; et la scene
/// projetee qui les prend.
@Suite("Scene : transition d'une disposition a l'autre")
struct TransitionSceneTests {
    typealias A = PosesScene.Ancre

    /// Une piece « p », sur le plateau `plateau`, a `x`, de largeur `l`.
    static func piece(_ plateau: String = "a", x: Double, l: Double = 2) -> PosesScene.Piece {
        PosesScene.Piece(ancres: [A(plateau: plateau, place: SIMD2(x, 0))], taille: SIMD2(l, 2), teinte: 3)
    }

    static func noeud(_ plateau: String, x: Double) -> PosesScene.Noeud {
        PosesScene.Noeud(ancres: [A(plateau: plateau, place: SIMD2(x, 0))], decalage: SIMD2(0.5, -0.5), rayon: 7)
    }

    static func lien(_ de: String, _ vers: String) -> GrapheReseau.Lien {
        GrapheReseau.Lien(de: de, vers: vers, genre: .radio, qualite: 2)
    }

    /// Le centre d'une seule ancre posee, sa place sur x.
    static func x(_ p: PosesScene.Piece?) -> Double? {
        guard let p, p.ancres.count == 1 else { return nil }
        return p.ancres[0].place.x
    }

    /// Les poses a 0, au quart, a la moitie et a la fin du temps : 0, 6,25 % (la cubique, et non une droite ni une
    /// autre courbe symetrique), 50 % et 100 % du chemin, la taille de la carte avec ; finie a 0,9 s, pas avant ; a la
    /// fin, exactement l'arrivee.
    @Test func glissement() throws {
        var d = PosesScene(), a = PosesScene()
        d.pieces["p"] = Self.piece(x: 0, l: 2)
        a.pieces["p"] = Self.piece(x: 10, l: 4)
        let t = try #require(TransitionScene(de: d, vers: a, a: 100))
        #expect(TransitionScene.duree == 0.9 && TransitionScene.dureeFondu == 0.3)
        #expect(Self.x(t.poses(a: 100).pieces["p"]) == 0)
        #expect(abs((Self.x(t.poses(a: 100.225).pieces["p"]) ?? -1) - 0.625) < 1e-9, "6,25 % au quart du temps")
        #expect(abs((Self.x(t.poses(a: 100.45).pieces["p"]) ?? -1) - 5) < 1e-9)
        #expect(abs((t.poses(a: 100.45).pieces["p"]?.taille.x ?? -1) - 3) < 1e-9)
        #expect(abs((Self.x(t.poses(a: 100.675).pieces["p"]) ?? -1) - 9.375) < 1e-9, "93,75 % aux trois quarts")
        #expect(t.poses(a: 100.9).pieces["p"] == a.pieces["p"] && t.poses(a: 105).pieces["p"] == a.pieces["p"])
        #expect(t.poses(a: 99).pieces["p"] == d.pieces["p"], "avant le debut : le depart")
        #expect(!t.finie(a: 100.89) && t.finie(a: 100.9) && t.finie(a: 101))
    }

    /// Les fondus de 0,3 s : ce qui arrive, piece, noeud ou lien, apparait a sa place, de 0 a 1 ; ce qui part s'efface
    /// a sa derniere place, de 1 a 0. Puis la pose reste, jusqu'a la fin du glissement.
    @Test func fondus() throws {
        var d = PosesScene(), a = PosesScene()
        d.pieces["part"] = Self.piece(x: 1)
        a.pieces["arrive"] = Self.piece("b", x: 2)
        d.noeuds["n0"] = Self.noeud("a", x: 1)
        a.noeuds["n1"] = Self.noeud("b", x: 2)
        d.liens[PosesScene.cle(Self.lien("n0", "x"))] = PosesScene.Lien(Self.lien("n0", "x"))
        a.liens[PosesScene.cle(Self.lien("n1", "x"))] = PosesScene.Lien(Self.lien("n1", "x"))
        let t = try #require(TransitionScene(de: d, vers: a, a: 0))
        let parti = PosesScene.cle(Self.lien("n0", "x")), venu = PosesScene.cle(Self.lien("n1", "x"))
        for (instant, arrivee) in [(0.0, 0.0), (0.075, 0.25), (0.15, 0.5), (0.3, 1.0), (0.6, 1.0)] {
            let p = t.poses(a: instant)
            for o in [p.pieces["arrive"]?.opacite, p.noeuds["n1"]?.opacite, p.liens[venu]?.opacite] {
                #expect(abs((o ?? -1) - arrivee) < 1e-9, "a \(instant) s, ce qui arrive")
            }
            for o in [p.pieces["part"]?.opacite, p.noeuds["n0"]?.opacite, p.liens[parti]?.opacite] {
                #expect(abs((o ?? -1) - (1 - arrivee)) < 1e-9, "a \(instant) s, ce qui part")
            }
            #expect(Self.x(p.pieces["part"]) == 1 && Self.x(p.pieces["arrive"]) == 2, "a sa place")
            #expect(p.noeuds["n0"]?.ancres == d.noeuds["n0"]?.ancres && p.noeuds["n1"]?.ancres == a.noeuds["n1"]?.ancres)
        }
    }

    /// Rien ne change : pas de transition ; un lien deja la, ou la qualite seule change, non plus. « Reduire les
    /// animations » : jamais de transition, tout est immediat. La transition ne garde que ce qui change.
    @Test func ceQuiChange() throws {
        var d = PosesScene()
        d.pieces["p"] = Self.piece(x: 0)
        d.pieces["q"] = Self.piece(x: 5)
        d.liens["l"] = PosesScene.Lien(Self.lien("p", "q"))
        #expect(TransitionScene(de: d, vers: d, a: 0) == nil)
        var a = d
        a.liens["l"]?.qualite = 3
        #expect(TransitionScene(de: d, vers: a, a: 0) == nil, "la qualite d'un lien")
        a.pieces["q"] = Self.piece(x: 6)
        #expect(TransitionScene(de: d, vers: a, a: 0, reduire: true) == nil, "« Reduire les animations »")
        let t = try #require(TransitionScene(de: d, vers: a, a: 0))
        #expect(Set(t.depart.pieces.keys) == ["q"] && Set(t.arrivee.pieces.keys) == ["q"] && t.depart.liens.isEmpty)
        var s = d
        s.pieces["p"]?.opacite = 0.4
        let fondu = try #require(TransitionScene(de: s, vers: d, a: 0), "une opacite en route change aussi")
        #expect(abs((fondu.poses(a: 0.15).pieces["p"]?.opacite ?? -1) - 0.7) < 1e-9 && fondu.poses(a: 0.3).pieces["p"]?.opacite == 1)
    }

    /// Une nouvelle disposition pendant un glissement repart de la pose affichee, sans saut : a l'instant de
    /// l'interruption, les poses de la nouvelle transition sont celles qui etaient affichees, places et opacites, y
    /// compris ce qui apparaissait encore et ce qui s'effacait ; puis elles vont a la nouvelle arrivee.
    @Test func interruption() throws {
        var p0 = PosesScene(), p1 = PosesScene(), p2 = PosesScene()
        p0.pieces["p"] = Self.piece(x: 0)
        p0.pieces["part"] = Self.piece(x: 3)
        p1.pieces["p"] = Self.piece(x: 10)
        p1.pieces["arrive"] = Self.piece(x: 7)
        p2.pieces["p"] = Self.piece(x: -10)
        p2.pieces["arrive"] = Self.piece(x: 7)
        let t1 = try #require(TransitionScene(de: p0, vers: p1, a: 0))
        let affichee = p1.recouvertes(par: t1.poses(a: 0.1))
        let t2 = try #require(TransitionScene(de: affichee, vers: p2, a: 0.1))
        let avant = t1.poses(a: 0.1), apres = t2.poses(a: 0.1)
        for k in ["p", "part", "arrive"] {
            #expect(apres.pieces[k] == avant.pieces[k], "\(k) : pas de saut")
        }
        #expect(abs((avant.pieces["arrive"]?.opacite ?? -1) - 1.0 / 3) < 1e-9 && (Self.x(avant.pieces["p"]) ?? 0) > 0)
        #expect(t2.poses(a: 1).pieces["p"] == p2.pieces["p"] && t2.poses(a: 0.4).pieces["arrive"]?.opacite == 1)
        #expect(t2.poses(a: 0.4).pieces["part"]?.opacite == 0, "ce qui s'effacait finit de s'effacer")
        #expect(p1.recouvertes(par: PosesScene()) == p1)
    }

    /// Un noeud qui change de plateau va en ligne droite, d'un etage a l'autre, en 2D comme en 3D : ses ancres, melangees,
    /// donnent a chaque instant le point du segment entre ses deux places dans le monde.
    @Test(arguments: [0.0, 1.0]) func dUnPlateauALAutre(t: Double) throws {
        let g = GeometrieMaison(rayons: [5, 4])
        let plateaux = ["a": 0, "b": 1]
        let da = [A(plateau: "a", place: SIMD2(1, -2))], ab = [A(plateau: "b", place: SIMD2(-1, 3))]
        let w0 = try #require(PosesScene.centre(da, geometrie: g, plateaux: plateaux, t: t))
        let w1 = try #require(PosesScene.centre(ab, geometrie: g, plateaux: plateaux, t: t))
        #expect(simd_distance(w0, w1) > 4)
        if t == 1 { #expect(w1.y - w0.y > 4, "d'un etage a l'autre") }
        for e in [0.25, 0.5, 0.75] {
            let m = try #require(PosesScene.centre(PosesScene.melange(da, ab, e), geometrie: g, plateaux: plateaux, t: t))
            #expect(simd_distance(m, w0 + (w1 - w0) * e) < 1e-9, "a \(e) du chemin, sur le segment")
        }
    }

    /// Le melange : a 0 et a 1, exactement les ancres d'un cote ; deux ancres du meme plateau n'en font qu'une, a la
    /// moyenne ponderee ; une ancre sur un plateau absent ne compte pas, et sans aucune, pas de centre.
    @Test func melange() throws {
        let a = [A(plateau: "a", place: SIMD2(0, 0))], b = [A(plateau: "a", place: SIMD2(8, 4))]
        #expect(PosesScene.melange(a, b, 0) == a && PosesScene.melange(a, b, 1) == b)
        let m = PosesScene.melange(a, b, 0.25)
        #expect(m.count == 1 && m[0].plateau == "a" && abs(m[0].poids - 1) < 1e-12)
        #expect(simd_distance(m[0].place, SIMD2(2, 1)) < 1e-12)
        let deux = PosesScene.melange(a, [A(plateau: "b", place: SIMD2(8, 4))], 0.25)
        #expect(deux.map(\.plateau) == ["a", "b"] && abs(deux[0].poids - 0.75) < 1e-12 && abs(deux[1].poids - 0.25) < 1e-12)
        let g = GeometrieMaison(rayons: [5, 4])
        let seul = PosesScene.centre(deux, geometrie: g, plateaux: ["a": 0], t: 0)
        let centreA = try #require(PosesScene.centre(a, geometrie: g, plateaux: ["a": 0], t: 0))
        #expect(simd_distance(try #require(seul), centreA) < 1e-12, "le plateau absent ne compte pas")
        #expect(PosesScene.centre(deux, geometrie: g, plateaux: [:], t: 0) == nil)
        let c = PosesScene.centre(a, geometrie: g, plateaux: ["a": 1], t: 0)
        #expect(c == SIMD3(g.centres2D[1].x, 0, g.centres2D[1].y), "l'ancre suit son plateau, par sa cle")
    }

    /// Une piece qu'on prend pour la glisser, et ses noeuds : ils ne glissent plus.
    @Test func oublier() throws {
        var d = PosesScene(), a = PosesScene()
        d.pieces["p"] = Self.piece(x: 0)
        a.pieces["p"] = Self.piece(x: 4)
        d.noeuds["n"] = Self.noeud("a", x: 0)
        a.noeuds["n"] = Self.noeud("a", x: 4)
        d.pieces["q"] = Self.piece(x: 1)
        a.pieces["q"] = Self.piece(x: 2)
        var t = try #require(TransitionScene(de: d, vers: a, a: 0))
        t.oublier(pieces: ["p"], noeuds: ["n"])
        let p = t.poses(a: 0.45)
        #expect(p.pieces["p"] == nil && p.noeuds["n"] == nil && p.pieces["q"] != nil)
    }

    /// Les poses d'une scene posee : chaque piece a sa place, sur son plateau, de la taille de sa carte, opaque ; chaque
    /// noeud a sa place dans sa carte ; chaque lien.
    @Test func posesDUneScene() throws {
        let (s, c, d, _) = try SceneProjeteeTests.scene()
        let p = PosesScene(scene: s, cartes: c, positions: d.positions)
        #expect(p.pieces.count == s.pieces.count && p.noeuds.count == s.noeuds.count && p.liens.count == s.liens.count)
        let bureau = try SceneProjeteeTests.indice(s, "Bureau")
        let pose = try #require(p.pieces["piece:Bureau"])
        #expect(pose.ancres == [A(plateau: "zone:Étage", place: d.positions[bureau])] && pose.opacite == 1)
        #expect(pose.taille == SIMD2(c[bureau].largeur, c[bureau].profondeur) && pose.teinte == s.pieces[bureau].teinte)
        let r = try #require(s.pieces[bureau].noeuds.firstIndex(of: "E000000000000003"))
        let n = try #require(p.noeuds["E000000000000003"])
        #expect(n.ancres == pose.ancres && n.decalage == c[bureau].places[r] && n.rayon == 7)
    }

    /// La scene projetee prend les poses : posee, une pose ne change rien, au bit pres ; une piece et un noeud en route
    /// sont a leur pose ; un noeud qui change de piece, et d'etage, en ligne droite ; l'opacite d'un fondu.
    @Test func sceneProjeteeEnRoute() throws {
        let (s, c, d, g) = try SceneProjeteeTests.scene()
        let e = EtatAnime(t: 1, fk: Array(repeating: 0, count: s.pieces.count))
        let o = CameraScene.canonique(g, aspect: 1.5, u: 1)
        func projeter(_ poses: PosesScene, scene: ScenePieces? = nil, positions: [SIMD2<Double>]? = nil) -> SceneProjetee {
            SceneProjetee(scene: scene ?? s, cartes: c, positions: positions ?? d.positions, geometrie: g, etat: e, orbite: o,
                          cadre: SceneProjeteeTests.cadre, poses: poses)
        }
        let sans = projeter(PosesScene()), posee = projeter(PosesScene(scene: s, cartes: c, positions: d.positions))
        #expect(posee.centresNoeuds == sans.centresNoeuds && posee.ancresPieces == sans.ancresPieces)
        #expect(posee.disques.map(\.opacite) == sans.disques.map(\.opacite) && posee.fantomes.isEmpty)
        // Le bureau glisse de 2 sur x, ses noeuds avec lui ; E...03 passe au salon, a mi-chemin.
        let bureau = try SceneProjeteeTests.indice(s, "Bureau"), salon = try SceneProjeteeTests.indice(s, "Salon")
        let arrivee = PosesScene(scene: s, cartes: c, positions: d.positions)
        var depart = arrivee
        depart.pieces["piece:Bureau"]?.ancres[0].place.x -= 2
        depart.noeuds["E000000000000003"] = PosesScene.Noeud(ancres: [A(plateau: "zone:Rez-de-chaussée", place: d.positions[salon])],
                                                         decalage: .zero, rayon: 7)
        let t = try #require(TransitionScene(de: depart, vers: arrivee, a: 0))
        let mi = projeter(t.poses(a: 0.45))
        let ici = try #require(sans.ancresPieces[bureau]), la = try #require(mi.ancresPieces[bureau])
        #expect(ici != la, "le bureau, en route")
        let w0 = SIMD3(g.centrePlateau(0, 1).x + d.positions[salon].x, g.centrePlateau(0, 1).y + 0.1 + 1.22,
                       g.centrePlateau(0, 1).z + d.positions[salon].y)
        let w1 = try #require(sans.centresNoeuds["E000000000000003"])
        let w = try #require(mi.centresNoeuds["E000000000000003"])
        #expect(simd_distance(w, (w0 + w1) / 2) < 1e-9 && w1.y - w0.y > 4, "d'un etage a l'autre, en ligne droite")
        let e02 = try #require(mi.centresNoeuds["E000000000000002"]), e02Posee = try #require(sans.centresNoeuds["E000000000000002"])
        #expect(abs((e02Posee.x - e02.x) - 1) < 1e-9 && abs(e02Posee.z - e02.z) < 1e-9,
                "le bureau, a mi-chemin, 1 unite avant sa place ; un noeud du bureau suit sa piece")
        // Un fondu : la pastille et le bloc a l'opacite de la pose ; les liens aussi.
        var f = PosesScene()
        f.pieces["piece:Salon"] = arrivee.pieces["piece:Salon"]
        f.pieces["piece:Salon"]?.opacite = 0.5
        f.noeuds["HomePod"] = arrivee.noeuds["HomePod"]
        f.noeuds["HomePod"]?.opacite = 0.25
        let radio = try #require(s.liens.first { $0.genre == .radio })
        f.liens[PosesScene.cle(radio)] = PosesScene.Lien(radio, opacite: 0.5)
        let fondu = projeter(f)
        let blocSalon = try #require(fondu.blocs.first { $0.piece == salon }), blocSans = try #require(sans.blocs.first { $0.piece == salon })
        #expect(abs(blocSalon.opaciteVerre - blocSans.opaciteVerre * 0.5) < 1e-12 && abs(blocSalon.opaciteAretes - 0.375) < 1e-12)
        #expect(fondu.disques.first { $0.noeud == "HomePod" }?.opacite == 0.25)
        #expect(fondu.liensRouteurs.contains { abs($0.opacite - 0.475) < 1e-12 } && fondu.liensRouteurs.count == sans.liensRouteurs.count)
    }

    /// Ce qui s'efface, absent de la scene, se dessine a sa derniere place, a son opacite : une piece (son bloc, sans
    /// ancre de nom, et qui ne se clique pas), un noeud (sa pastille, sans nom, qui ne se clique pas), un lien entre les
    /// places de ses bouts. Un element sur un plateau absent ne se dessine pas.
    @Test func ceQuiSEfface() throws {
        let (s, c, d, g) = try SceneProjeteeTests.scene()
        let e = EtatAnime(t: 0, fk: Array(repeating: 0, count: s.pieces.count))
        let o = CameraScene.canonique(g, aspect: 1.5, u: 0)
        var f = PosesScene()
        f.pieces["piece:Garage"] = PosesScene.Piece(ancres: [A(plateau: "zone:Étage", place: SIMD2(0, 0))],
                                                    taille: SIMD2(3, 3), teinte: 2, opacite: 0.6)
        f.pieces["piece:Ailleurs"] = PosesScene.Piece(ancres: [A(plateau: "zone:Absente", place: .zero)],
                                                      taille: SIMD2(3, 3), teinte: 2, opacite: 0.6)
        f.noeuds["E000000000000009"] = PosesScene.Noeud(ancres: [A(plateau: "zone:Étage", place: SIMD2(0, 0))],
                                                        decalage: .zero, rayon: 7, opacite: 0.8)
        let parti = GrapheReseau.Lien(de: "E000000000000009", vers: "HomePod", genre: .radio, qualite: 1)
        f.liens[PosesScene.cle(parti)] = PosesScene.Lien(parti, opacite: 0.4)
        let sans = SceneProjetee(scene: s, cartes: c, positions: d.positions, geometrie: g, etat: e, orbite: o,
                                 cadre: SceneProjeteeTests.cadre)
        let p = SceneProjetee(scene: s, cartes: c, positions: d.positions, geometrie: g, etat: e, orbite: o,
                              cadre: SceneProjeteeTests.cadre, poses: f)
        let fantome = try #require(p.blocs.first { $0.piece == -1 })
        #expect(p.blocs.count == sans.blocs.count + 1 && abs(fantome.opaciteVerre - 0.6 * 0.13) < 1e-12)
        #expect(p.ancresPieces.count == sans.ancresPieces.count)
        let dessus = SceneProjetee.boite(fantome.faces[0].points)
        #expect(p.piece(sous: CGPoint(x: dessus.midX, y: dessus.midY)) != -1)
        let disque = try #require(p.disques.first { $0.noeud == "E000000000000009" })
        #expect(disque.opacite == 0.8 && p.fantomes == ["E000000000000009"] && p.ancresNoeuds["E000000000000009"] == nil)
        #expect(p.noeud(sous: disque.centre, marge: 0) != "E000000000000009")
        #expect(p.liensRouteurs.count == sans.liensRouteurs.count + 1 && p.liensRouteurs.contains { abs($0.opacite - 0.38) < 1e-12 })
    }
}
