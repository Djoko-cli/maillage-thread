import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : places gardees")
struct PlacesGardeesTests {
    static func fichier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("positions-\(UUID().uuidString)/positions-pieces.json")
    }

    static func scene(zones: [ZoneMaison]) throws -> ScenePieces {
        ScenePieces(graphe: try ScenePiecesTests.graphe(sonde: false), libelles: ScenePiecesTests.libelles,
                    piecesNoeuds: ["Apple TV": "Salon", "HomePod": "Chambre"], zones: zones, chefs: [], piecesMaison: true)
    }

    /// Aller-retour sur disque : places et ordre des etages, par maison ; un fichier absent ou
    /// illisible donne des places vides.
    @Test func allerRetour() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var p = PlacesGardees()
        p.garder(SIMD2(1.5, -2.25), piece: "piece:Salon", etage: "zone:Rez-de-chaussée", domicile: "Maison")
        p.ordonner(["zone:Étage", "zone:Rez-de-chaussée"], domicile: "Maison")
        p.garder(SIMD2(3, 4), piece: "piece:Salon", etage: "maison", domicile: "Chalet")
        try p.ecrire(dans: url)
        let relu = PlacesGardees.lire(url)
        #expect(relu == p)
        #expect(relu.maison("Maison").ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
        #expect(relu.maison("Maison").etages["zone:Rez-de-chaussée"]?["piece:Salon"] == PlacesGardees.Place(x: 1.5, z: -2.25))
        #expect(PlacesGardees.lire(url.appendingPathExtension("absent")) == PlacesGardees())
        try Data("pas du json".utf8).write(to: url)
        #expect(PlacesGardees.lire(url) == PlacesGardees())
    }

    /// Pieces fixees : celles qui ont une place gardee dans leur etage. Renommee, ou passee dans un
    /// autre etage, une piece perd sa place ; les autres la gardent.
    @Test func pieceRenommeeOuDeplacee() throws {
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre"])]
        let s = try Self.scene(zones: zones)
        var p = PlacesGardees()
        p.garder(SIMD2(1, 2), piece: "piece:Salon", etage: "zone:Rez-de-chaussée", domicile: "")
        p.garder(SIMD2(3, 4), piece: "piece:Chambre", etage: "zone:Étage", domicile: "")
        let salon = try #require(s.pieces.firstIndex { $0.nom == .maison("Salon") })
        let chambre = try #require(s.pieces.firstIndex { $0.nom == .maison("Chambre") })
        #expect(p.fixees(s, domicile: "") == [salon: SIMD2(1, 2), chambre: SIMD2(3, 4)])
        #expect(p.fixees(s, domicile: "Autre").isEmpty)
        // La chambre passe au rez-de-chaussee : elle perd sa place, le salon garde la sienne.
        let deplacee = try Self.scene(zones: [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Chambre"])])
        let salon2 = try #require(deplacee.pieces.firstIndex { $0.nom == .maison("Salon") })
        #expect(p.fixees(deplacee, domicile: "") == [salon2: SIMD2(1, 2)])
    }

    /// Ordre des etages garde, puis « Replacer les pieces automatiquement » : les places partent,
    /// l'ordre reste.
    @Test func ordreDesEtagesEtReplacement() throws {
        var p = PlacesGardees()
        p.ordonner(["zone:Étage", "zone:Rez-de-chaussée"], domicile: "")
        p.garder(SIMD2(1, 2), piece: "piece:Salon", etage: "zone:Rez-de-chaussée", domicile: "")
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre"])]
        let s = ScenePieces(graphe: try ScenePiecesTests.graphe(sonde: false), libelles: [:],
                            piecesNoeuds: ["Apple TV": "Salon", "HomePod": "Chambre"], zones: zones, chefs: [],
                            piecesMaison: true, ordreEtages: p.maison("").ordreEtages)
        #expect(s.etages.map(\.id) == ["zone:Étage", "zone:Rez-de-chaussée"])
        p.replacer(domicile: "")
        #expect(p.maison("").etages.isEmpty)
        #expect(p.maison("").ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
    }
}
