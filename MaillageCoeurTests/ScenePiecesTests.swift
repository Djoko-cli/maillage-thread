import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : etages, pieces et noeuds")
struct ScenePiecesTests {
    static let partition = "46CBEBCD"

    /// Petit reseau : l'Apple TV (chef, BBR primaire) et le HomePod, routeurs de bordure ; quatre
    /// appareils. Avec la sonde : le routeur 3 est l'appareil E...04 (un appareil qui route), E...02
    /// est l'enfant de l'Apple TV, E...03 celui du HomePod ; E...05 n'a pas de parent connu.
    static func graphe(sonde: Bool) throws -> GrapheReseau {
        var b = Banc()
        let omr = "fd00:5555:6666::/64"
        b.routeur("Apple TV", partition: partition, role: .chef, primaire: true, lien: "fe80::1", omr: omr,
                  xa: "E0000000000000A1")
        b.routeur("HomePod", partition: partition, lien: "fe80::2", omr: omr, xa: "E0000000000000A2")
        for k in 2...5 {
            b.appareil(String(format: "E00000000000000%d", k), noeud: k, adresses: ["fd00:5555:6666:0:b00::\(k)"])
        }
        let i = Instantane(annonces: b.annonces)
        let r = try #require(i.reseaux.first)
        let apps = i.appareils.map { AppareilAffiche(id: $0.id, nom: $0.id, partition: $0.partition, etat: .joignable) }
        guard sonde else { return GrapheReseau(reseau: r, appareils: apps) }
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: partition)
        c.routeurs(Route64(sequence: 0, routes: (1...3).map {
            RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1)
        }), chef: 1)
        c.identite("E0000000000000A1", routeur: 1)
        c.identite("E0000000000000A2", routeur: 2)
        c.identite("E000000000000004", routeur: 3)
        c.marquer(1, bordure: true, bbrPrincipal: true)
        c.marquer(2, bordure: true)
        c.lien(1, 2, sortante: 3, entrante: 2)
        c.lien(1, 3, sortante: 2, entrante: 2)
        c.enfant(EnfantMaillage(rloc16: 0x0401, extMac: "E000000000000002", qualite: 3, source: .tableEnfants))
        c.enfant(EnfantMaillage(rloc16: 0x0801, extMac: "E000000000000003", qualite: 2, source: .tableEnfants))
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        return GrapheReseau(reseau: r, appareils: apps, maillage: m)
    }

    static let libelles = ["Apple TV": "Apple TV 👑", "HomePod": "HomePod", "E000000000000002": "Lampe salon",
                           "E000000000000003": "Capteur", "E000000000000004": "Prise", "E000000000000005": "Bouton"]

    static func noms(_ s: ScenePieces, etage e: Int) -> [ScenePieces.NomPiece] {
        s.etages[e].pieces.map { s.pieces[$0].nom }
    }

    static func piece(_ s: ScenePieces, _ nom: ScenePieces.NomPiece) throws -> ScenePieces.Piece {
        try #require(s.pieces.first { $0.nom == nom })
    }

    /// Zones : une piece dans deux zones va dans la premiere ; une zone sans piece montree n'est pas un
    /// etage ; les pieces hors zone forment « Autres pieces » ; une piece sans noeud n'est pas montree.
    @Test func zones() throws {
        let g = try Self.graphe(sonde: false)
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre", "E000000000000002": "Bureau",
                      "E000000000000003": "Garage", "E000000000000004": "Salon", "E000000000000005": "Chambre"]
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Chambre"]),
                     ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau"]),
                     ZoneMaison(nom: "Grenier", pieces: ["Débarras"])]
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                            piecesMaison: true)
        #expect(s.etages.map(\.nom) == [.zone("Rez-de-chaussée"), .zone("Étage"), .autresPieces])
        #expect(Self.noms(s, etage: 0) == [.maison("Chambre"), .maison("Salon")], "Chambre : la premiere zone")
        #expect(Self.noms(s, etage: 1) == [.maison("Bureau")])
        #expect(Self.noms(s, etage: 2) == [.maison("Garage")])
        #expect(!s.pieces.contains { $0.nom == .maison("Cuisine") || $0.nom == .maison("Débarras") })
        #expect(try Self.piece(s, .maison("Salon")).noeuds == ["Apple TV", "E000000000000004"])
        #expect(s.etages.map(\.id) == ["zone:Rez-de-chaussée", "zone:Étage", "autres-pieces"])
        #expect(!s.sansPiecesMaison)
    }

    /// Maison sans zones, ou fichier d'avant les zones (le champ manque : nil) : un seul plateau.
    @Test func sansZones() throws {
        let g = try Self.graphe(sonde: false)
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre"]
        for zones in [nil, []] as [[ZoneMaison]?] {
            let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                                piecesMaison: true)
            #expect(s.etages.map(\.nom) == [.maison])
            #expect(Self.noms(s, etage: 0) == [.maison("Chambre"), .maison("Salon"), .sansPiece])
        }
        let ancien = """
        {"version": 1, "date": "2026-09-28T10:00:00Z", "statut": "ok", "accessoires": [{"nom": "Lampe", "piece": "Salon"}]}
        """
        let n = try NomsMaison.lire(Data(ancien.utf8))
        #expect(n.zones == nil)
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: n.zones, chefs: [],
                            piecesMaison: true)
        #expect(s.etages.map(\.nom) == [.maison])
    }

    /// « Sans piece » : les noeuds que Maison ne place pas, sur le plateau du bas, celui de l'ordre
    /// garde s'il y en a un ; une cle inconnue de l'ordre garde est ignoree.
    @Test func sansPieceSurLePlateauDuBas() throws {
        let g = try Self.graphe(sonde: false)
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre"]
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre"])]
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                            piecesMaison: true)
        #expect(Self.noms(s, etage: 0) == [.maison("Salon"), .sansPiece])
        #expect(try Self.piece(s, .sansPiece).noeuds == ["E000000000000005", "E000000000000003", "E000000000000002",
                                                          "E000000000000004"], "par libelle")
        let inverse = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                                  piecesMaison: true, ordreEtages: ["zone:Étage", "inconnu", "zone:Rez-de-chaussée"])
        #expect(inverse.etages.map(\.nom) == [.zone("Étage"), .zone("Rez-de-chaussée")])
        #expect(Self.noms(inverse, etage: 0) == [.maison("Chambre"), .sansPiece])
        #expect(try Self.piece(inverse, .sansPiece).etage == 0)
    }

    /// Pas encore de pieces de Maison : un plateau « Maison », une carte par routeur avec ses enfants
    /// (vus par la sonde) ; sans parent connu, « Sans piece ». Sans sonde, aucun parent : chaque
    /// routeur seul dans sa carte.
    @Test func groupementParRouteur() throws {
        let s = ScenePieces(graphe: try Self.graphe(sonde: true), libelles: Self.libelles, piecesNoeuds: [:], zones: nil,
                            chefs: [], piecesMaison: false)
        #expect(s.sansPiecesMaison)
        #expect(s.etages.map(\.nom) == [.maison])
        #expect(try Self.piece(s, .routeur("Apple TV")).noeuds == ["Apple TV", "E000000000000002"])
        #expect(try Self.piece(s, .routeur("HomePod")).noeuds == ["HomePod", "E000000000000003"])
        #expect(try Self.piece(s, .routeur("E000000000000004")).noeuds == ["E000000000000004"], "appareil qui route")
        #expect(try Self.piece(s, .sansPiece).noeuds == ["E000000000000005"])
        let sans = ScenePieces(graphe: try Self.graphe(sonde: false), libelles: Self.libelles, piecesNoeuds: [:],
                               zones: nil, chefs: [], piecesMaison: false)
        #expect(try Self.piece(sans, .routeur("Apple TV")).noeuds == ["Apple TV"])
        #expect(try Self.piece(sans, .sansPiece).noeuds.count == 4)
    }

    /// Lignes d'une carte : le chef, les routeurs de bordure, les autres routeurs, puis les autres
    /// noeuds, par libelle ; rayons 15 (centre), 13, 8 et 7.
    @Test func lignesEtRayons() throws {
        let g = try Self.graphe(sonde: true)
        let tous = Dictionary(uniqueKeysWithValues: g.noeuds.map { ($0.id, "Salon") })
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: tous, zones: nil, chefs: ["HomePod"],
                            piecesMaison: true)
        #expect(try Self.piece(s, .maison("Salon")).noeuds
                == ["HomePod", "Apple TV", "E000000000000004", "E000000000000005", "E000000000000003", "E000000000000002"])
        #expect(s.noeud("HomePod")?.rang == 0 && s.noeud("HomePod")?.rayon == 13)
        #expect(s.noeud("Apple TV")?.rang == 1 && s.noeud("Apple TV")?.rayon == 15)
        #expect(s.noeud("E000000000000004")?.rang == 2 && s.noeud("E000000000000004")?.rayon == 8)
        #expect(s.noeud("E000000000000002")?.rang == 3 && s.noeud("E000000000000002")?.rayon == 7)
        #expect(s.noeud("E000000000000002")?.libelle == "Lampe salon")
        #expect(s.liens == g.liens)
    }

    /// Teintes : FNV-1a 32 bits du nom, modulo 8 ; dans un etage, la suivante libre si elle est prise
    /// (Chambre, Salle de bain et Cellier donnent 3) ; d'un etage a l'autre, pas de conflit.
    @Test func teintes() throws {
        #expect(ScenePieces.fnv1a("") == 0x811C_9DC5)
        #expect(ScenePieces.fnv1a("a") == 0xE40C_292C)
        #expect(ScenePieces.fnv1a("foobar") == 0xBF9C_F968)
        let g = try Self.graphe(sonde: false)
        let pieces = ["Apple TV": "Salle de bain", "HomePod": "Chambre", "E000000000000002": "Cellier",
                      "E000000000000003": "Salon", "E000000000000004": "Chambre", "E000000000000005": "Salon"]
        let zones = [ZoneMaison(nom: "Étage", pieces: ["Salle de bain", "Chambre", "Cellier"]),
                     ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"])]
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                            piecesMaison: true)
        #expect(try Self.piece(s, .maison("Cellier")).teinte == 3, "premier par nom")
        #expect(try Self.piece(s, .maison("Chambre")).teinte == 4)
        #expect(try Self.piece(s, .maison("Salle de bain")).teinte == 5)
        #expect(try Self.piece(s, .maison("Salon")).teinte == 2)
        #expect(ScenePieces.teintes.count == 8 && ScenePieces.teintes[0] == 0x3B82F5)
    }
}
