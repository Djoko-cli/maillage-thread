import CoreGraphics
@testable import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

/// Cas et verifications communs aux tests des libelles du graphe.
enum CasLibelles {
    /// Noeud a etiqueter, en coordonnees de la vue.
    static func noeud(_ id: String, _ genre: Disposition.Genre = .appareil, x: CGFloat, y: CGFloat, rayon: CGFloat = 7,
                      zone: CGPoint = .zero, texte: CGSize = CGSize(width: 60, height: 13),
                      pastille: CGSize? = nil) -> PlacementLibelles.Noeud {
        PlacementLibelles.Noeud(id: id, genre: genre, centre: CGPoint(x: x, y: y), rayon: rayon, centreZone: zone,
                                texte: texte, pastille: pastille)
    }

    /// Libelles qui se recoupent, ou qui couvrent un point ou un obstacle ; vide si
    /// tout est lisible. (Recouper : partager une surface ; se toucher ne compte pas.)
    static func chevauchements(_ p: PlacementLibelles) -> [String] {
        func recoupe(_ a: CGRect, _ b: CGRect) -> Bool {
            a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
        }
        func surLePoint(_ r: CGRect, _ n: PlacementLibelles.Noeud) -> Bool {
            let dx = max(r.minX - n.centre.x, 0, n.centre.x - r.maxX)
            let dy = max(r.minY - n.centre.y, 0, n.centre.y - r.maxY)
            return hypot(dx, dy) < n.rayon
        }
        var defauts: [String] = []
        let places = p.noeuds.compactMap { n in p.places[n.id].map { (id: n.id, place: $0) } }
        for (i, a) in places.enumerated() {
            for b in places[(i + 1)...] where recoupe(a.place.cadre, b.place.cadre) {
                defauts.append("\(a.id) / \(b.id)")
            }
            for n in p.noeuds where surLePoint(a.place.cadre, n) {
                defauts.append("\(a.id) sur le point \(n.id)")
            }
            for (k, o) in p.obstacles.enumerated() where recoupe(a.place.cadre, o) {
                defauts.append("\(a.id) sur l'obstacle \(k)")
            }
            // Texte et pastille dans le cadre du libelle (la zone de clic), aux arrondis pres.
            let cadre = a.place.cadre.insetBy(dx: -1e-6, dy: -1e-6)
            if !cadre.contains(a.place.texte) || !(a.place.pastille.map(cadre.contains) ?? true) {
                defauts.append("\(a.id) deborde de son cadre")
            }
        }
        return defauts
    }

    /// Traits fins qui traversent un libelle, un autre point ou un obstacle (le segment est
    /// echantillonne tous les 0,25 pt : un point strictement dedans compte).
    static func traversees(_ p: PlacementLibelles) -> [String] {
        func dedans(_ q: CGPoint, _ r: CGRect) -> Bool {
            r.minX < q.x && q.x < r.maxX && r.minY < q.y && q.y < r.maxY
        }
        var defauts: [String] = []
        for n in p.noeuds {
            guard let t = p.places[n.id]?.trait else { continue }
            let pas = max(2, Int(hypot(t.arrivee.x - t.depart.x, t.arrivee.y - t.depart.y) / 0.25))
            let points = (0...pas).map { i in
                CGPoint(x: t.depart.x + (t.arrivee.x - t.depart.x) * CGFloat(i) / CGFloat(pas),
                        y: t.depart.y + (t.arrivee.y - t.depart.y) * CGFloat(i) / CGFloat(pas))
            }
            for m in p.noeuds where m.id != n.id {
                if let c = p.places[m.id]?.cadre, points.contains(where: { dedans($0, c) }) {
                    defauts.append("trait de \(n.id) sur le libelle de \(m.id)")
                }
                if points.contains(where: { hypot($0.x - m.centre.x, $0.y - m.centre.y) < m.rayon }) {
                    defauts.append("trait de \(n.id) sur le point \(m.id)")
                }
            }
            for (k, o) in p.obstacles.enumerated() where points.contains(where: { dedans($0, o) }) {
                defauts.append("trait de \(n.id) sur l'obstacle \(k)")
            }
        }
        return defauts
    }

    /// Fonds des libelles (`Place.fond`, coins arrondis de `rayonFond`) qui ne couvrent pas
    /// leur texte ou leur pastille, ou qui couvrent un autre texte, une autre pastille ou un
    /// point (les toucher ne compte pas) ; vide si tout va bien.
    static func defautsDesFonds(_ p: PlacementLibelles) -> [String] {
        let rho = PlacementLibelles.rayonFond
        // Un fond est l'ensemble des points a moins de `rho` de son rectangle interieur.
        func interieur(_ f: CGRect) -> CGRect { f.insetBy(dx: rho, dy: rho) }
        func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
            hypot(max(0, a.minX - b.maxX, b.minX - a.maxX), max(0, a.minY - b.maxY, b.minY - a.maxY))
        }
        func coins(_ r: CGRect) -> [CGRect] {
            [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.minX, y: r.maxY),
             CGPoint(x: r.maxX, y: r.maxY)].map { CGRect(origin: $0, size: .zero) }
        }
        var defauts: [String] = []
        let places = p.noeuds.compactMap { n in p.places[n.id].map { (id: n.id, place: $0) } }
        for a in places {
            let i = interieur(a.place.fond)
            let siens = [a.place.texte] + (a.place.pastille.map { [$0] } ?? [])
            if !siens.flatMap(coins).allSatisfy({ distance(i, $0) <= rho + 1e-9 }) {
                defauts.append("le fond de \(a.id) ne couvre pas son libelle")
            }
            for b in places where b.id != a.id {
                let autres = [b.place.texte] + (b.place.pastille.map { [$0] } ?? [])
                if autres.contains(where: { distance(i, $0) < rho - 1e-9 }) {
                    defauts.append("le fond de \(a.id) couvre le libelle de \(b.id)")
                }
            }
            for n in p.noeuds where distance(i, CGRect(origin: n.centre, size: .zero)) < rho + n.rayon - 1e-9 {
                defauts.append("le fond de \(a.id) couvre le point \(n.id)")
            }
        }
        // Fond d'un titre de zone : au plus son obstacle, avec la meme marge et les memes coins.
        for (k, o) in p.obstacles.enumerated() {
            let i = interieur(o.insetBy(dx: -PlacementLibelles.margeFond.width, dy: -PlacementLibelles.margeFond.height))
            for b in places {
                let autres = [b.place.texte] + (b.place.pastille.map { [$0] } ?? [])
                if autres.contains(where: { distance(i, $0) < rho - 1e-9 }) {
                    defauts.append("le fond du titre \(k) couvre le libelle de \(b.id)")
                }
            }
        }
        return defauts
    }

    /// Centre, quatre routeurs et quarante appareils aux noms longs sur un petit anneau
    /// (13 pt d'un appareil a l'autre : moins que la hauteur d'un libelle et son jeu).
    static let anneauDense: [PlacementLibelles.Noeud] = {
        var n = [noeud("centre", .centre, x: 0, y: 0, rayon: 11, texte: CGSize(width: 90, height: 13))]
        for i in 0..<4 {
            let a = -CGFloat.pi / 2 + 2 * .pi * CGFloat(i) / 4
            n.append(noeud("routeur-\(i)", .routeur, x: 45 * cos(a), y: 45 * sin(a), rayon: 7.5,
                           texte: CGSize(width: 120, height: 13)))
        }
        for i in 0..<40 {
            let a = -CGFloat.pi / 2 + 2 * .pi * CGFloat(i) / 40
            n.append(noeud(String(format: "appareil-%02d", i), x: 85 * cos(a), y: 85 * sin(a), rayon: 3.5,
                           texte: CGSize(width: 150 + CGFloat((i * 37) % 90), height: 13),
                           pastille: i % 5 == 0 ? CGSize(width: 46, height: 17) : nil))
        }
        return n
    }()

    /// Titre de la zone de l'anneau dense : au-dessus du cercle, comme au dessin.
    static let titreAnneau = CGRect(x: -110, y: -125 - 6 - 13, width: 220, height: 13)

    /// Zone clairsemee : chaque libelle a de la place.
    static let clairseme: [PlacementLibelles.Noeud] = [
        noeud("C", .centre, x: 0, y: 0, rayon: 22, texte: CGSize(width: 80, height: 13)),
        noeud("R-droite", .routeur, x: 90, y: 0, rayon: 15, texte: CGSize(width: 40, height: 13)),
        noeud("R-gauche", .routeur, x: -90, y: 0, rayon: 15, texte: CGSize(width: 40, height: 13)),
        noeud("R-haut", .routeur, x: 0, y: -90, rayon: 15, texte: CGSize(width: 40, height: 13)),
        noeud("A-bas", x: 0, y: 170, pastille: CGSize(width: 40, height: 17)),
        noeud("A-haut", x: 0, y: -170, pastille: CGSize(width: 40, height: 17)),
        noeud("A-droite", x: 170, y: 0, pastille: CGSize(width: 40, height: 17)),
        noeud("A-gauche", x: -170, y: 0, pastille: CGSize(width: 40, height: 17)),
        noeud("A-sans-pastille", x: 120, y: 120),
    ]
}

@Suite("Graphe : placement des libelles et zone de clic")
struct PlacementLibellesTests {
    typealias Place = PlacementLibelles.Place

    /// Un libelle qui a de la place garde celle d'aujourd'hui : vers l'exterieur de sa
    /// zone (a droite, a gauche, au-dessus, au-dessous ; sous le centre), la pastille au
    /// bout, du cote oppose au point.
    @Test func placeDAujourdhui() throws {
        let p = PlacementLibelles(noeuds: CasLibelles.clairseme, obstacles: [])
        #expect(CasLibelles.chevauchements(p).isEmpty)
        #expect(p.places.values.allSatisfy { !$0.ecarte && $0.trait == nil })
        // Sous le centre, a 4 pt.
        let c = try #require(p.places["C"])
        #expect(c.sens == .dessous)
        #expect(c.texte == CGRect(x: -40, y: 26, width: 80, height: 13))
        #expect(c.cadre == c.texte)
        // Routeurs : a droite et a gauche a 4 pt, au-dessus a 3 pt.
        #expect(p.places["R-droite"]?.texte == CGRect(x: 109, y: -6.5, width: 40, height: 13))
        #expect(p.places["R-droite"]?.sens == .droite)
        #expect(p.places["R-gauche"]?.texte == CGRect(x: -149, y: -6.5, width: 40, height: 13))
        #expect(p.places["R-gauche"]?.sens == .gauche)
        #expect(p.places["R-haut"]?.texte == CGRect(x: -20, y: -121, width: 40, height: 13))
        #expect(p.places["R-haut"]?.sens == .dessus)
        // Appareils avec pastille : dessous (texte puis pastille), dessus (pastille puis texte),
        // a droite (texte puis pastille, a 5 pt), a gauche (pastille puis texte).
        #expect(p.places["A-bas"] == Place(cadre: CGRect(x: -30, y: 180, width: 60, height: 33),
                                           texte: CGRect(x: -30, y: 180, width: 60, height: 13),
                                           pastille: CGRect(x: -20, y: 196, width: 40, height: 17), sens: .dessous))
        #expect(p.places["A-haut"] == Place(cadre: CGRect(x: -30, y: -213, width: 60, height: 33),
                                            texte: CGRect(x: -30, y: -193, width: 60, height: 13),
                                            pastille: CGRect(x: -20, y: -213, width: 40, height: 17), sens: .dessus))
        #expect(p.places["A-droite"] == Place(cadre: CGRect(x: 181, y: -8.5, width: 105, height: 17),
                                              texte: CGRect(x: 181, y: -6.5, width: 60, height: 13),
                                              pastille: CGRect(x: 246, y: -8.5, width: 40, height: 17), sens: .droite))
        #expect(p.places["A-gauche"] == Place(cadre: CGRect(x: -286, y: -8.5, width: 105, height: 17),
                                              texte: CGRect(x: -241, y: -6.5, width: 60, height: 13),
                                              pastille: CGRect(x: -286, y: -8.5, width: 40, height: 17), sens: .gauche))
        // En bas a droite (cos > 0,35) : a droite.
        #expect(p.places["A-sans-pastille"]?.texte == CGRect(x: 131, y: 113.5, width: 60, height: 13))
    }

    /// Quarante appareils aux noms longs sur un petit anneau : aucun libelle ne recoupe
    /// un autre, ni un point, ni le titre de la zone ; ceux qui n'ont pas de place pres
    /// de leur point sont ecartes vers l'exterieur et relies a leur point par un trait fin.
    @Test func anneauDense() {
        let p = PlacementLibelles(noeuds: CasLibelles.anneauDense, obstacles: [CasLibelles.titreAnneau])
        #expect(CasLibelles.chevauchements(p) == [])
        #expect(p.places.count == 45, "chaque noeud a son libelle, nom entier")
        let ecartes = p.noeuds.filter { p.places[$0.id]?.ecarte == true }
        #expect(!ecartes.isEmpty, "l'anneau est trop serre : des libelles sont ecartes")
        for n in ecartes {
            guard let place = p.places[n.id], let trait = place.trait else {
                Issue.record("\(n.id) ecarte sans trait")
                continue
            }
            // Le trait part du bord du point et arrive sur le bord du libelle, vers l'exterieur.
            #expect(abs(hypot(trait.depart.x - n.centre.x, trait.depart.y - n.centre.y) - n.rayon) < 1e-6)
            #expect(place.cadre.insetBy(dx: -1e-6, dy: -1e-6).contains(trait.arrivee)
                    && !place.cadre.insetBy(dx: 1e-6, dy: 1e-6).contains(trait.arrivee))
            // (Le centre d'une zone s'ecarte vers le bas, sous son point.)
            let exterieur = n.genre == .centre ? CGPoint(x: 0, y: 1)
                : CGPoint(x: n.centre.x - n.centreZone.x, y: n.centre.y - n.centreZone.y)
            let versLibelle = CGPoint(x: trait.arrivee.x - n.centre.x, y: trait.arrivee.y - n.centre.y)
            #expect(exterieur.x * versLibelle.x + exterieur.y * versLibelle.y > 0, "\(n.id) : vers l'exterieur")
        }
    }

    /// Deux points presque confondus : leurs libelles ne se recoupent pas, ne couvrent
    /// aucun des deux points, et le clic prend le plus proche.
    @Test func pointsPresqueConfondus() {
        let p = PlacementLibelles(noeuds: [
            CasLibelles.noeud("a", x: 100, y: 0, texte: CGSize(width: 160, height: 13)),
            CasLibelles.noeud("b", x: 100.4, y: 0.3, texte: CGSize(width: 160, height: 13),
                              pastille: CGSize(width: 46, height: 17)),
        ], obstacles: [])
        #expect(CasLibelles.chevauchements(p) == [])
        #expect(p.places["a"]?.sens == .droite && p.places["a"]?.ecarte == false, "le premier garde sa place")
        #expect(p.places["b"] != nil)
        #expect(p.cible(a: CGPoint(x: 100, y: 0)) == "a")
        #expect(p.cible(a: CGPoint(x: 100.4, y: 0.3)) == "b")
    }

    /// Plus aucune place autour du point : le libelle est ecarte vers l'exterieur de la
    /// zone, pas a pas (4 pt), jusqu'a la premiere place libre, et marque d'un trait fin.
    @Test func libelleEcarte() throws {
        // Point en (0, 0), zone centree dessous : l'exterieur est en haut.
        let obstacle = CGRect(x: -100, y: -100, width: 200, height: 200)
        let p = PlacementLibelles(noeuds: [CasLibelles.noeud("N", x: 0, y: 0, zone: CGPoint(x: 0, y: 50))],
                                  obstacles: [obstacle])
        let place = try #require(p.places["N"])
        #expect(place.ecarte)
        #expect(place.sens == .dessus)
        // Premiere place libre : 2 pt au-dessus de l'obstacle (le jeu), soit (0, -102).
        #expect(place.cadre == CGRect(x: -30, y: -115, width: 60, height: 13))
        #expect(place.trait == PlacementLibelles.Trait(depart: CGPoint(x: 0, y: -7), arrivee: CGPoint(x: 0, y: -102)))
        #expect(CasLibelles.chevauchements(p) == [])
        // Le libelle ecarte est cliquable ; le trait et l'obstacle, non.
        #expect(p.cible(a: CGPoint(x: 25, y: -108)) == "N")
        #expect(p.cible(a: CGPoint(x: 0, y: -60)) == nil)
    }

    /// Le trait fin d'un libelle ecarte ne traverse ni un autre libelle, ni un point, ni un
    /// titre : l'ecartement cherche aussi de biais (jusqu'a 75 degres de l'exterieur). Un
    /// libelle pose ensuite ne couvre pas un trait deja trace.
    @Test func traitDegage() throws {
        // « b » (en 0, 0 ; l'exterieur en bas) n'a plus de place autour de son point : un
        // titre au-dessus, un a droite, un a gauche, un dessous. Tout droit vers le bas (et
        // a 15 ou 30 degres), son trait couperait le titre du dessous : il part a 45 degres,
        // a la premiere place libre : rayon 7, ecart 4, puis 7 pas de 4 pt, soit 39 pt du centre.
        let titres = [CGRect(x: -100, y: -60, width: 200, height: 50), CGRect(x: 30, y: -3, width: 40, height: 20),
                      CGRect(x: -70, y: -3, width: 40, height: 20), CGRect(x: -6, y: 12, width: 12, height: 60)]
        let b = CasLibelles.noeud("b", x: 0, y: 0, zone: CGPoint(x: 0, y: -100))
        // « c » : seul, il garde sa place d'aujourd'hui (au-dessus) ; elle est sur le trait de « b ».
        let c = CasLibelles.noeud("c", x: 18, y: 40, zone: CGPoint(x: 18, y: 100), texte: CGSize(width: 10, height: 13))
        #expect(PlacementLibelles(noeuds: [c], obstacles: titres).places["c"]?.sens == .dessus)

        let p = PlacementLibelles(noeuds: [c, b], obstacles: titres)
        #expect(CasLibelles.chevauchements(p) == [])
        #expect(CasLibelles.traversees(p) == [], "aucun trait ne traverse un libelle, un point ou un titre")
        let trait = try #require(p.places["b"]?.trait)
        #expect(abs(atan2(trait.arrivee.y - trait.depart.y, trait.arrivee.x - trait.depart.x) - .pi / 4) < 1e-9)
        #expect(abs(hypot(trait.arrivee.x, trait.arrivee.y) - 39) < 1e-9)
        #expect(p.places["b"]?.sens == .droite)
        let placeC = try #require(p.places["c"])
        #expect(placeC.sens != .dessus && !placeC.ecarte, "c laisse sa place au trait, sans etre ecarte")
    }

    /// Fond discret de chaque libelle (texte et pastille) : le cadre, 2 pt de chaque cote et
    /// 1 pt dessus et dessous, coins arrondis de 4 pt. Il couvre son texte et sa pastille, et
    /// ne couvre ni un autre libelle, ni un point (au plus, il les touche), meme dense.
    @Test func fondDesLibelles() throws {
        let clairseme = PlacementLibelles(noeuds: CasLibelles.clairseme, obstacles: [])
        let a = try #require(clairseme.places["A-droite"])
        #expect(a.fond == CGRect(x: 179, y: -9.5, width: 109, height: 19))
        for p in [clairseme, PlacementLibelles(noeuds: CasLibelles.anneauDense, obstacles: [CasLibelles.titreAnneau])] {
            #expect(CasLibelles.defautsDesFonds(p) == [])
        }
    }

    /// Zone de clic et de survol : le point avec 8 pt autour du rayon dessine, plus tout
    /// le libelle (texte et pastille) ; rien ailleurs.
    @Test func clic() {
        let p = PlacementLibelles(noeuds: CasLibelles.clairseme, obstacles: [])
        #expect(p.cible(a: CGPoint(x: 170, y: 0)) == "A-droite", "sur le point")
        #expect(p.cible(a: CGPoint(x: 170 - 7 - 7.9, y: 0)) == "A-droite", "a 7,9 pt du point")
        #expect(p.cible(a: CGPoint(x: 170 - 7 - 8.5, y: 0)) == nil, "a 8,5 pt du point")
        #expect(p.cible(a: CGPoint(x: 240, y: 5)) == "A-droite", "au bout du texte")
        #expect(p.cible(a: CGPoint(x: 284, y: -8)) == "A-droite", "sur la pastille")
        #expect(p.cible(a: CGPoint(x: 290, y: 0)) == nil, "apres le libelle")
        #expect(p.cible(a: CGPoint(x: 0, y: 36)) == "C", "sur le libelle du centre")
        #expect(p.cible(a: CGPoint(x: 60, y: 60)) == nil, "entre les noeuds")
        #expect(p.cible(a: CGPoint(x: 0, y: -170 - 7 - 3 - 13 - 3 - 8)) == "A-haut", "sur la pastille au-dessus")
    }

    /// Zones de clic qui se recouvrent (le libelle de a passe dans la marge du point b) :
    /// le plus proche du curseur l'emporte.
    @Test func plusProcheDuCurseur() {
        let p = PlacementLibelles(noeuds: [
            CasLibelles.noeud("a", x: 0, y: 0),
            CasLibelles.noeud("b", x: 40, y: 18),
        ], obstacles: [])
        #expect(CasLibelles.chevauchements(p) == [])
        #expect(p.places["a"]?.cadre == CGRect(x: 11, y: -6.5, width: 60, height: 13))
        #expect(p.cible(a: CGPoint(x: 40, y: 5)) == "a", "sur le libelle de a, dans la marge de b")
        #expect(p.cible(a: CGPoint(x: 40, y: 9)) == "b", "hors du libelle de a, dans la marge de b")
    }

    /// Meme entree, meme sortie, quel que soit l'ordre d'arrivee des noeuds.
    @Test func deterministe() {
        let p1 = PlacementLibelles(noeuds: CasLibelles.anneauDense, obstacles: [CasLibelles.titreAnneau])
        let p2 = PlacementLibelles(noeuds: CasLibelles.anneauDense, obstacles: [CasLibelles.titreAnneau])
        let p3 = PlacementLibelles(noeuds: CasLibelles.anneauDense.reversed(), obstacles: [CasLibelles.titreAnneau])
        #expect(p1 == p2)
        #expect(p1 == p3, "l'ordre d'arrivee ne compte pas")
        // Ordre de pose : le centre, les routeurs, puis les appareils, chacun par identifiant.
        #expect(p1.noeuds.map(\.id).prefix(6) == ["centre", "routeur-0", "routeur-1", "routeur-2", "routeur-3",
                                                  "appareil-00"])
    }

    /// Un decalage (glisser) deplace tout d'un bloc, sans rien recalculer.
    @Test func decalage() {
        let p = PlacementLibelles(noeuds: CasLibelles.clairseme, obstacles: [CasLibelles.titreAnneau])
        let d = p.decale(CGPoint(x: 300, y: -40))
        #expect(d.places["A-droite"]?.cadre == p.places["A-droite"]?.cadre.offsetBy(dx: 300, dy: -40))
        #expect(d.obstacles == [CasLibelles.titreAnneau.offsetBy(dx: 300, dy: -40)])
        #expect(d.cible(a: CGPoint(x: 470, y: -40)) == "A-droite")
    }
}

/// Mesure des libelles hors du Canvas, placement de la demo, recalcul.
@MainActor
@Suite("Graphe : libelles mesures et places dans l'app")
struct LibellesGrapheTests {
    /// Tailles des textes telles que le Canvas les mesure pour les dessiner
    /// (`resolve` puis `measure`), a une echelle d'ecran donnee.
    static func taillesDessinees(_ textes: [Text], echelle: CGFloat) -> [CGSize] {
        final class Boite {
            var tailles: [CGSize] = []
        }
        let boite = Boite()
        let vue = Canvas { ctx, _ in
            boite.tailles = textes.map { ctx.resolve($0).measure(in: GrapheCanvas.propositionTexte) }
        }
        .frame(width: 4, height: 4)
        let rendu = ImageRenderer(content: vue)
        rendu.scale = echelle
        _ = rendu.cgImage
        return boite.tailles
    }

    /// Routeurs de bordure de la demo laisses sans identite : chacun porte les deux en candidats.
    nonisolated static let sansIdentite: Set<String> = ["HomePod Avant", "HomePod Palier"]

    /// Libelles de la demo : le vrai reseau (releve du 28/09), ses noms et son maillage ;
    /// `sansIdentite` : routeurs de bordure que ce maillage n'identifie pas.
    static func demo(sansIdentite: Set<String> = []) throws
        -> (disposition: Disposition, libelles: [String: GrapheCanvas.Libelle], scinde: Bool) {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        if !sansIdentite.isEmpty {
            let i = try #require(s.instantane)
            s.recevoir(try #require(MaillageDemo.maillage(i, date: s.maintenant, sansIdentite: sansIdentite)), a: s.maintenant)
        }
        let r = try #require(s.reseau)
        let affiches = s.appareilsAffiches(pour: r)
        let maillage = s.maillageAffiche(pour: r)
        let d = Disposition(reseau: r, appareils: affiches, maillage: maillage)
        let parId = Dictionary(affiches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let nomsRouteurs = s.nomsRouteurs(pour: r)
        let libelles = GrapheCanvas.libelles(disposition: d, reseau: r, appareils: parId, nomsRouteurs: nomsRouteurs,
                                             maillage: maillage)
        return (d, libelles, r.estScinde)
    }

    /// La taille mesuree hors du Canvas (celle du placement et du clic) couvre le texte
    /// que le Canvas dessine : egale a l'echelle 1, a moins d'un point pres (arrondi au
    /// pixel) en 2x et 3x ; meme hauteur. En graisse normale (hors survol), le texte
    /// dessine n'est jamais plus large que la place reservee (semi-gras).
    @Test func tailleMesureeCommeDessinee() {
        let mesure = MesureTextes()
        let noms = ["Détecteur de passage nord", "Détecteur de passage chaufferie côté cour ☾", "Apple TV 4K 👑",
                    "Eve Motion ☾ ⚠︎", "Halo", "Routeur de bordure · B400", "Non identifié · AC05", "客厅灯 Salon",
                    "Partition 73586B68 · fd19:961f:2db3::/64 (partagé)", "HomePod Avant ou HomePod Palier · 0400",
                    "HomePod salon\u{202F}? · CC00"]
        var textes: [Text] = []
        var normaux: [Text] = []
        var mesurees: [CGSize] = []
        for n in noms {
            for genre in [Disposition.Genre.routeur, .appareil] {
                textes.append(GrapheCanvas.texteLibelle(n, genre: genre, fort: true))
                normaux.append(GrapheCanvas.texteLibelle(n, genre: genre, fort: false))
                mesurees.append(mesure.libelle(n, genre: genre))
            }
            textes.append(GrapheCanvas.texteTitre(n))
            normaux.append(GrapheCanvas.texteTitre(n))
            mesurees.append(mesure.titre(n))
        }
        let valeurs = [String(localized: "\(12)\u{202F}%"), String(localized: "faible")]
        for echelle in [1.0, 2.0, 3.0] as [CGFloat] {
            let dessinees = Self.taillesDessinees(textes, echelle: echelle)
            let dessineesNormales = Self.taillesDessinees(normaux, echelle: echelle)
            #expect(dessinees.count == mesurees.count)
            for (k, (d, m)) in zip(dessinees, mesurees).enumerated() {
                #expect(d.width <= m.width && m.width - d.width < 1, "\(k) en \(echelle)x : \(d) dessine, \(m) mesure")
                #expect(d.height == m.height, "\(k) en \(echelle)x : \(d) dessine, \(m) mesure")
                if echelle == 1 { #expect(d == m) }
                #expect(dessineesNormales[k].width <= m.width)
            }
            // Pastille : icone et valeur, dans la capsule de `taillePastille`.
            for v in valeurs {
                let t = Self.taillesDessinees([GrapheCanvas.iconePastille, GrapheCanvas.textePastille(v)], echelle: echelle)
                let dessinee = GrapheCanvas.taillePastille(icone: t[0], valeur: t[1])
                let mesuree = mesure.pastille(v)
                #expect(dessinee.width <= mesuree.width && mesuree.width - dessinee.width < 2, "\(v) en \(echelle)x")
                #expect(dessinee.height == mesuree.height, "\(v) en \(echelle)x")
            }
        }
    }

    /// Disposition de la demo, a plusieurs zooms et tailles de fenetre : aucun libelle
    /// ne recoupe un autre, ni un point, ni un titre de zone ; de meme avec deux routeurs de
    /// bordure non identifies, dont les libelles portent leurs candidats (plus longs).
    @Test(arguments: [Set<String>(), LibellesGrapheTests.sansIdentite])
    func demoSansChevauchement(_ sansIdentite: Set<String>) throws {
        let demo = try Self.demo(sansIdentite: sansIdentite)
        let memoire = MemoirePlacement()
        for taille in [CGSize(width: 820, height: 560), CGSize(width: 1400, height: 900)] {
            for zoom in [0.4, 0.7, 1, 1.6, 2.5, 5] as [CGFloat] {
                let projection = Projection(cadre: demo.disposition.cadre, taille: taille,
                                            marges: (haut: demo.scinde ? 110 : 70, bas: 30, cotes: 60), zoom: zoom)
                let p = memoire.placement(demo.disposition, libelles: demo.libelles, echelle: projection.echelle)
                    .decale(projection.origine)
                #expect(CasLibelles.chevauchements(p) == [], "zoom \(zoom), fenetre \(taille)")
                #expect(CasLibelles.defautsDesFonds(p) == [], "zoom \(zoom), fenetre \(taille)")
                // Des le zoom 1, aucun trait fin ne traverse un libelle, un point ou un titre (plus
                // loin, l'ecartement choisit la direction ou il en traverse le moins).
                if zoom >= 1 { #expect(CasLibelles.traversees(p) == [], "zoom \(zoom), fenetre \(taille)") }
                #expect(p.places.count == Set(demo.disposition.noeuds.map(\.id)).count)
                #expect(p.obstacles.count == demo.disposition.zones.count, "un titre par zone")
            }
        }
        // Textes des libelles (deplaces du dessin) : la couronne du chef, la lune, la pastille.
        #expect(demo.libelles.values.contains { $0.texte.hasSuffix(" 👑") })
        #expect(demo.libelles.values.contains { $0.texte.hasSuffix(" ☾") })
        #expect(demo.libelles.values.contains { $0.pastille == String(localized: "\(12)\u{202F}%") })
        // Routeurs de bordure non identifies : un noeud chacun (routeurs 5 et 9 de la demo), avec
        // les deux candidats ; leurs annonces ne sont pas dessinees a part.
        let liste = ["HomePod Avant", "HomePod Palier"].formatted(.list(type: .or))
        let candidats = demo.libelles.values.filter { $0.texte.hasPrefix(liste) }.map(\.texte).sorted()
        if sansIdentite.isEmpty {
            #expect(candidats.isEmpty)
            #expect(demo.disposition.noeud("HomePod Avant") != nil)
        } else {
            #expect(candidats == [String(localized: "\(liste) · \("1400")"), String(localized: "\(liste) · \("2400")")])
            #expect(demo.disposition.noeud("HomePod Avant") == nil && demo.disposition.noeud("HomePod Palier") == nil)
        }
    }

    /// Meme entree, meme placement ; le clic trouve chaque noeud sur son point et sur son
    /// libelle, dans la demo, avec et sans routeurs de bordure non identifies.
    @Test(arguments: [Set<String>(), LibellesGrapheTests.sansIdentite])
    func demoDeterministeEtCliquable(_ sansIdentite: Set<String>) throws {
        let demo = try Self.demo(sansIdentite: sansIdentite)
        let a = MemoirePlacement().placement(demo.disposition, libelles: demo.libelles, echelle: 0.8)
        let b = MemoirePlacement().placement(demo.disposition, libelles: demo.libelles, echelle: 0.8)
        #expect(a == b)
        for n in a.noeuds {
            #expect(a.cible(a: n.centre) == n.id, "\(n.id) sur son point")
            let place = try #require(a.places[n.id])
            #expect(a.cible(a: CGPoint(x: place.texte.midX, y: place.texte.midY)) == n.id, "\(n.id) sur son libelle")
        }
    }

    /// Le placement se recalcule quand la disposition, l'echelle ou les noms changent ; pas au
    /// survol ni pendant un glisser (memes entrees). L'echelle suit le zoom et la fenetre, et
    /// aussi la selection quand la hauteur limite : la fiche ouverte reserve le bas de la vue.
    @Test func recalculSeulementSiBesoin() throws {
        let demo = try Self.demo()
        let memoire = MemoirePlacement()
        let p = memoire.placement(demo.disposition, libelles: demo.libelles, echelle: 1)
        #expect(memoire.placement(demo.disposition, libelles: demo.libelles, echelle: 1) == p)
        #expect(memoire.calculs == 1)
        _ = memoire.placement(demo.disposition, libelles: demo.libelles, echelle: 1.25)
        #expect(memoire.calculs == 2, "zoom")
        var renomme = demo.libelles
        let id = try #require(demo.libelles.keys.sorted().first)
        renomme[id]?.texte = "Un tout autre nom, bien plus long"
        _ = memoire.placement(demo.disposition, libelles: renomme, echelle: 1.25)
        #expect(memoire.calculs == 3, "noms")
        _ = memoire.placement(demo.disposition, libelles: renomme, echelle: 1.25)
        #expect(memoire.calculs == 3)
        // Une selection ouvre la fiche (marge basse de 30 a 190 pt) : si la hauteur limite,
        // l'echelle change, et le placement avec elle.
        let taille = CGSize(width: 1400, height: 700)
        let sansFiche = Projection(cadre: demo.disposition.cadre, taille: taille, marges: (haut: 110, bas: 30, cotes: 60))
        let avecFiche = Projection(cadre: demo.disposition.cadre, taille: taille, marges: (haut: 110, bas: 190, cotes: 60))
        #expect(avecFiche.echelle < sansFiche.echelle)
        _ = memoire.placement(demo.disposition, libelles: renomme, echelle: sansFiche.echelle)
        _ = memoire.placement(demo.disposition, libelles: renomme, echelle: avecFiche.echelle)
        #expect(memoire.calculs == 5, "la fiche ouverte change l'echelle : recalcul")
    }

    /// Ordre du dessin : les liens et les traits avant les fonds et les libelles, et avant
    /// les titres des zones (ni un lien ni un trait ne barre un texte) ; les fonds sous les
    /// points (ils ne rognent pas leurs halos), les titres et les traits aussi ; l'anneau de
    /// selection sur les fonds ; les libelles au-dessus de tout ; chaque couche une fois.
    @Test func ordreDesCouches() {
        let c = GrapheCanvas.couches
        func rang(_ x: GrapheCanvas.Couche) -> Int { c.firstIndex(of: x) ?? -1 }
        #expect(c.count == GrapheCanvas.Couche.allCases.count && Set(c) == Set(GrapheCanvas.Couche.allCases))
        #expect(rang(.liens) < rang(.fonds) && rang(.traits) < rang(.fonds))
        #expect(rang(.fonds) < rang(.points), "les fonds ne rognent pas les halos des points")
        #expect(rang(.liens) < rang(.titres) && rang(.traits) < rang(.titres) && rang(.titres) < rang(.points))
        #expect(rang(.traits) < rang(.points))
        #expect(rang(.fonds) < rang(.selection) && rang(.selection) < rang(.libelles))
        #expect(c.last == .libelles)
    }

    /// Pincement : le zoom est borne des la projection (de 0,4 a 5, comme a la fin du geste) ;
    /// au-dela des bornes, rien ne bouge, et le placement ne se recalcule pas a chaque image.
    @Test func zoomBorneEnPincement() throws {
        #expect(Projection.zoomBorne(0.1) == 0.4)
        #expect(Projection.zoomBorne(12) == 5)
        #expect(Projection.zoomBorne(1.3) == 1.3)
        let demo = try Self.demo()
        let memoire = MemoirePlacement()
        for zooms in [[5, 6, 8, 12], [0.4, 0.3, 0.2, 0.1]] as [[CGFloat]] {
            let projections = zooms.map {
                Projection(cadre: demo.disposition.cadre, taille: CGSize(width: 1400, height: 900),
                           marges: (haut: 110, bas: 30, cotes: 60), zoom: $0)
            }
            #expect(projections.allSatisfy { $0 == projections[0] }, "\(zooms)")
            for p in projections {
                _ = memoire.placement(demo.disposition, libelles: demo.libelles, echelle: p.echelle)
            }
        }
        #expect(memoire.calculs == 2, "un calcul par borne atteinte")
    }

    /// Mesurer pendant une mise a jour de SwiftUI (le corps de la fenetre du graphe) donne
    /// le meme placement qu'en dehors.
    @Test func mesureDansLeCorpsDUneVue() throws {
        let demo = try Self.demo()
        final class Boite {
            var placement: PlacementLibelles?
        }
        struct Vue: View {
            let memoire: MemoirePlacement
            let disposition: Disposition
            let libelles: [String: GrapheCanvas.Libelle]
            let boite: Boite

            var body: some View {
                let p = memoire.placement(disposition, libelles: libelles, echelle: 0.9)
                boite.placement = p
                return Color.clear.frame(width: 4, height: 4)
            }
        }
        let boite = Boite()
        _ = ImageRenderer(content: Vue(memoire: MemoirePlacement(), disposition: demo.disposition,
                                       libelles: demo.libelles, boite: boite)).cgImage
        let dehors = MemoirePlacement().placement(demo.disposition, libelles: demo.libelles, echelle: 0.9)
        #expect(boite.placement == dehors)
    }
}
