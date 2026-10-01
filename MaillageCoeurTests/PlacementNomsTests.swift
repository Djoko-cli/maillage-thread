import CoreGraphics
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : placement des noms et zoom semantique")
struct PlacementNomsTests {
    static let cadre = CGSize(width: 800, height: 600)

    static func noeud(_ id: String, largeur: CGFloat = 80) -> Etiquette {
        Etiquette(.noeud(id), taille: CGSize(width: largeur, height: 15))
    }

    static func pastille(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 7) -> CGRect {
        CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
    }

    /// Paires de noms poses (hors noms d'etage) qui se chevauchent a 2 px pres.
    static func chevauchements(_ e: [Etiquette]) -> Int {
        let poses = e.filter { $0.vu && !$0.fixe }
        var n = 0
        for i in poses.indices {
            for j in poses.indices where j > i && PlacementNoms.chevauche(poses[i].rect, poses[j].rect) { n += 1 }
        }
        return n
    }

    /// Quarante noms serres : aucun chevauchement entre noms poses, ni avec une pastille ; tous dans le
    /// cadre ; ceux qui ne trouvent pas de place sont masques et comptes, pas ceux d'un objet hors de
    /// la vue.
    @Test func sansChevauchementDansLeCadre() {
        var e = (0..<40).map { Self.noeud("n\($0)", largeur: 60 + CGFloat($0 % 5) * 10) }
        let ancres: [CGRect?] = (0..<40).map { Self.pastille(380 + CGFloat($0 % 8) * 12, 280 + CGFloat($0 / 8) * 12) }
        let obstacles = ancres.compactMap { $0 }
        _ = PlacementNoms.placer(&e, ancres: ancres, obstacles: obstacles, cadre: Self.cadre, dt: 0)
        #expect(Self.chevauchements(e) == 0)
        let poses = e.filter(\.vu)
        #expect(!poses.isEmpty)
        #expect(poses.allSatisfy { PlacementNoms.dansCadre($0.rect, Self.cadre) })
        #expect(poses.allSatisfy { p in !obstacles.contains { PlacementNoms.chevauche(p.rect, $0) } })
        #expect(PlacementNoms.masques(e, ancres: ancres, cadre: Self.cadre) == 40 - poses.count)
        var hors = [Self.noeud("loin")]
        let loin: [CGRect?] = [Self.pastille(2000, 300)]
        _ = PlacementNoms.placer(&hors, ancres: loin, obstacles: [], cadre: Self.cadre, dt: 0)
        #expect(!hors[0].vu && PlacementNoms.masques(hors, ancres: loin, cadre: Self.cadre) == 0, "hors de la vue")
    }

    /// Priorites : a place egale, la plus forte (le plus petit nombre) passe d'abord et prend la
    /// premiere place ; un nom d'etage (fixe) se pose meme sur un obstacle.
    @Test func prioritesRespectees() {
        var faible = Self.noeud("faible")
        faible.prio = 7
        var fort = Self.noeud("fort")
        fort.prio = 2
        var e = [faible, fort, Etiquette(.etage(0), taille: CGSize(width: 300, height: 15))]
        let a = Self.pastille(300, 300), b = Self.pastille(600, 500)
        _ = PlacementNoms.placer(&e, ancres: [a, a, CGRect(x: 600, y: 520, width: 0, height: 0)], obstacles: [a, b],
                                 cadre: Self.cadre, dt: 0)
        #expect(e[1].place == 0, "le plus fort a droite")
        #expect(e[0].vu && e[0].place == 1, "le plus faible a gauche")
        #expect(e[2].vu && e[2].place == 0 && PlacementNoms.chevauche(e[2].rect, b), "etage : pose sur la pastille")
    }

    /// Stabilite : un nom deplace par un obstacle garde sa nouvelle place tant qu'elle est libre ; il
    /// ne revient a sa place preferee qu'apres l'avoir trouvee libre 0,5 s.
    @Test func stabilite() {
        var e = [Self.noeud("n")]
        let a = Self.pastille(400, 300)
        let droite = PlacementNoms.rect(e[0].taille, a, Candidats.appareil[0])
        _ = PlacementNoms.placer(&e, ancres: [a], obstacles: [droite], cadre: Self.cadre, dt: 0.1)
        #expect(e[0].place == 1, "a gauche : la droite est prise")
        for _ in 0..<4 {
            _ = PlacementNoms.placer(&e, ancres: [a], obstacles: [], cadre: Self.cadre, dt: 0.1)
            #expect(e[0].place == 1, "moins de 0,5 s : il reste")
        }
        _ = PlacementNoms.placer(&e, ancres: [a], obstacles: [], cadre: Self.cadre, dt: 0.1)
        #expect(e[0].place == 0, "0,5 s : il rejoint sa place")
        #expect(e[0].envie == 0)
    }

    /// Trait de rappel des le deuxieme anneau ; un nom immobile d'une image a l'autre.
    @Test func traitsEtImmobilite() {
        var e = [Self.noeud("n")]
        let a = Self.pastille(400, 300)
        let premier = Candidats.appareil.prefix(8).map { PlacementNoms.rect(e[0].taille, a, $0) }
        let traits = PlacementNoms.placer(&e, ancres: [a], obstacles: premier, cadre: Self.cadre, dt: 0)
        #expect(e[0].vu && e[0].place >= 8)
        #expect(traits.count == 1)
        _ = PlacementNoms.placer(&e, ancres: [a], obstacles: premier, cadre: Self.cadre, dt: 0.1)
        #expect(e[0].immobile)
    }

    /// Seuils du zoom semantique : sous 0,42 les pieces seules, jusqu'a 0,6 les routeurs en plus, puis
    /// tous ; le survol montre toujours le nom survole ; en piece isolee, tous les noms de la piece.
    @Test func seuilsDuZoomSemantique() throws {
        #expect(NiveauZoom(echelle: 0.41) == .pieces)
        #expect(NiveauZoom(echelle: 0.42) == .routeurs)
        #expect(NiveauZoom(echelle: 0.59) == .routeurs)
        #expect(NiveauZoom(echelle: 0.6) == .tous)
        let g = try ScenePiecesTests.graphe(sonde: true)
        let s = ScenePieces(graphe: g, libelles: ScenePiecesTests.libelles, piecesNoeuds: ["Apple TV": "Salon"], zones: nil,
                            chefs: ["Apple TV"], piecesMaison: true)
        var e = s.noeuds.map { Etiquette(.noeud($0.id), taille: CGSize(width: 50, height: 15)) }
        e.append(Etiquette(.piece(0), taille: CGSize(width: 90, height: 20)))
        func voulus(_ niveau: NiveauZoom, survol: String? = nil) -> Set<String> {
            PlacementNoms.regler(&e, scene: s, niveau: niveau, survol: survol, selection: nil, focus: nil, isolee: false,
                                 fk: Array(repeating: 0, count: s.pieces.count), s: 0, t: 0)
            return Set(e.compactMap { l in
                if case .noeud(let id) = l.genre, l.voulu { return id }
                return nil
            })
        }
        #expect(voulus(.pieces).isEmpty)
        #expect(voulus(.routeurs) == ["Apple TV", "HomePod", "E000000000000004"])
        #expect(voulus(.tous).count == s.noeuds.count)
        #expect(voulus(.pieces, survol: "E000000000000005") == ["E000000000000005"])
        #expect(e.last?.voulu == true, "les pieces toujours")
        #expect(e.first { $0.genre == .noeud("Apple TV") }?.prio == 5, "chef")
        #expect(e.first { $0.genre == .noeud("E000000000000005") }?.prio == 2, "survole")
        let salon = try #require(s.pieces.firstIndex { $0.nom == .maison("Salon") })
        var fk = Array(repeating: 0.0, count: s.pieces.count)
        fk[salon] = 1
        PlacementNoms.regler(&e, scene: s, niveau: .pieces, survol: nil, selection: nil, focus: salon, isolee: true, fk: fk,
                             s: 1, t: 0)
        #expect(e.filter(\.voulu).count == 1 + 1, "l'Apple TV, seul noeud du salon, et le nom de la piece")
    }

    /// Temps de calcul, en Release, dans une fenetre ordinaire (noms espaces) : le placement de 150 noms
    /// tient sous 2 ms (moyenne de 20 images).
    @Test(.enabled(if: Compilation.optimisee, "mesure en Release (outils/mesurer.sh)"))
    func tempsDePlacement() {
        var e = (0..<150).map { Self.noeud("n\($0)", largeur: 60 + CGFloat($0 % 7) * 12) }
        let ancres: [CGRect?] = (0..<150).map { Self.pastille(60 + CGFloat($0 % 15) * 90, 60 + CGFloat($0 / 15) * 80) }
        let obstacles = ancres.compactMap { $0 }
        let cadre = CGSize(width: 1440, height: 900)
        _ = PlacementNoms.placer(&e, ancres: ancres, obstacles: obstacles, cadre: cadre, dt: 0)
        let debut = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<20 { _ = PlacementNoms.placer(&e, ancres: ancres, obstacles: obstacles, cadre: cadre, dt: 1.0 / 60) }
        let ms = Double(DispatchTime.now().uptimeNanoseconds - debut) / 20 / 1e6
        print("mesure : placement de 150 noms en \(ms) ms, \(e.count { $0.vu }) poses")
        #expect(ms < 2, "\(ms) ms")
    }

    /// Temps de calcul, en Release, au pire cas mesure : 150 noms tres serres (leurs pastilles a 12 px
    /// les unes des autres, au milieu de la fenetre). La plupart ne trouvent pas de place, et chacun
    /// essaie alors ses 40 candidats contre tout ce qui est pose. Le placement tient sous 4 ms
    /// (moyenne de 20 images) : sans effet visible, une image disposant de 16,7 ms (spec, section 10).
    @Test(.enabled(if: Compilation.optimisee, "mesure en Release (outils/mesurer.sh)"))
    func tempsDePlacementSerre() {
        var e = (0..<150).map { Self.noeud("n\($0)", largeur: 60 + CGFloat($0 % 7) * 12) }
        let ancres: [CGRect?] = (0..<150).map { Self.pastille(620 + CGFloat($0 % 15) * 12, 390 + CGFloat($0 / 15) * 12) }
        let obstacles = ancres.compactMap { $0 }
        let cadre = CGSize(width: 1440, height: 900)
        _ = PlacementNoms.placer(&e, ancres: ancres, obstacles: obstacles, cadre: cadre, dt: 0)
        let debut = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<20 { _ = PlacementNoms.placer(&e, ancres: ancres, obstacles: obstacles, cadre: cadre, dt: 1.0 / 60) }
        let ms = Double(DispatchTime.now().uptimeNanoseconds - debut) / 20 / 1e6
        print("mesure : placement de 150 noms tres serres en \(ms) ms, \(e.count { $0.vu }) poses")
        #expect(ms < 4, "\(ms) ms")
        #expect(Self.chevauchements(e) == 0)
    }
}
