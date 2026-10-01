import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : piece des routeurs que Maison ne place pas")
struct PiecesRouteursTests {
    /// Pieces d'une maison inventee.
    static let pieces = ["Bureau", "Chambre", "Chambre d'amis", "Entrée", "Salle de bain", "Salon"]

    static func fichier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("routeurs-\(UUID().uuidString)/pieces-routeurs.json")
    }

    /// D'apres le nom : en mots entiers, sans egard a la casse ni aux accents.
    @Test(arguments: [
        ("HomePod mini chambre", "Chambre"),
        ("HomePod mini bureau", "Bureau"),
        ("HOMEPOD ENTREE", "Entrée"),
        ("Apple TV (salon)", "Salon"),
        ("HomePod-salle-de-bain", "Salle de bain"),
    ])
    func dApresLeNom(nom: String, attendue: String) {
        #expect(PiecesRouteurs.piece(nom: nom, parmi: Self.pieces) == attendue)
    }

    /// Rien sans piece dans le nom : un mot entier, pas un bout de mot (« Salons », « Bureautique ») ;
    /// les mots de la piece doivent se suivre.
    @Test(arguments: ["HomePod Palier", "HomePod Avant", "Apple TV", "HomePod Salons", "Bureautique",
                      "HomePod salle, bain"])
    func sansPieceDansLeNom(nom: String) {
        #expect(PiecesRouteurs.piece(nom: nom, parmi: Self.pieces) == nil)
    }

    /// Le nom de piece le plus long gagne ; a egalite de longueur entre deux pieces, aucune.
    @Test func plusLongueOuAucune() {
        #expect(PiecesRouteurs.piece(nom: "HomePod chambre d'amis", parmi: Self.pieces) == "Chambre d'amis")
        #expect(PiecesRouteurs.piece(nom: "HomePod bureau entrée", parmi: Self.pieces) == nil, "Bureau et Entrée : 6 lettres")
        #expect(PiecesRouteurs.piece(nom: "HomePod salon chambre", parmi: Self.pieces) == "Chambre")
        #expect(PiecesRouteurs.piece(nom: "HomePod entree", parmi: ["Entrée", "Entree"]) == nil, "deux pieces, meme nom")
        #expect(PiecesRouteurs.piece(nom: "HomePod", parmi: []) == nil)
    }

    /// Le choix passe avant le nom ; un choix dont la piece n'est plus dans Maison ne compte pas ; nil
    /// revient a la regle du nom. Par maison.
    @Test func choixAvantLeNom() {
        var p = PiecesRouteurs()
        #expect(p.piece(routeur: "HomePod mini chambre", nom: "HomePod mini chambre", parmi: Self.pieces,
                        domicile: "Maison") == "Chambre")
        p.choisir("Salon", routeur: "HomePod mini chambre", domicile: "Maison")
        #expect(p.piece(routeur: "HomePod mini chambre", nom: "HomePod mini chambre", parmi: Self.pieces,
                        domicile: "Maison") == "Salon")
        #expect(p.piece(routeur: "HomePod mini chambre", nom: "HomePod mini chambre", parmi: Self.pieces,
                        domicile: "Chalet") == "Chambre", "une autre maison")
        #expect(p.piece(routeur: "HomePod mini chambre", nom: "HomePod mini chambre", parmi: ["Chambre"],
                        domicile: "Maison") == "Chambre", "le salon n'est plus dans Maison")
        p.choisir(nil, routeur: "HomePod mini chambre", domicile: "Maison")
        #expect(p == PiecesRouteurs())
    }

    /// Pieces de Maison : celles des accessoires et celles des zones, sans doublon ni nom vide.
    @Test func piecesDeLaMaison() {
        let maison = NomsMaison(date: Date(timeIntervalSince1970: 1_790_000_000), accessoires: [
            AccessoireMaison(nom: "Lampe", piece: "Salon"), AccessoireMaison(nom: "Prise", piece: ""),
            AccessoireMaison(nom: "Pont"),
        ], zones: [ZoneMaison(nom: "Étage", pieces: ["Chambre", "Salon"])])
        #expect(PiecesRouteurs.pieces(de: maison) == ["Chambre", "Salon"])
        #expect(PiecesRouteurs.pieces(de: nil).isEmpty)
    }

    /// Aller-retour sur disque ; un fichier absent, illisible ou d'une version plus recente donne des
    /// choix vides.
    @Test func allerRetour() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var p = PiecesRouteurs()
        p.choisir("Salon", routeur: "HomePod Palier", domicile: "Maison")
        p.choisir("Bureau", routeur: "Apple TV", domicile: "")
        try p.ecrire(dans: url)
        #expect(PiecesRouteurs.lire(url) == p)
        #expect(PiecesRouteurs.lire(url).choix(routeur: "HomePod Palier", domicile: "Maison") == "Salon")
        #expect(PiecesRouteurs.lire(url.appendingPathExtension("absent")) == PiecesRouteurs())
        try Data(#"{"version":2,"maisons":{}}"#.utf8).write(to: url)
        #expect(PiecesRouteurs.lire(url) == PiecesRouteurs())
        try Data("pas du json".utf8).write(to: url)
        #expect(PiecesRouteurs.lire(url) == PiecesRouteurs())
    }
}
