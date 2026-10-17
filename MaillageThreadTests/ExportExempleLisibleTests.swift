import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

/// L'export d'exemple (`docs/export-exemple/`, ecrit par `ExportExempleTests` du coeur) se relit avec les lecteurs de
/// Maillage Thread lui-meme : chaque fichier a bien le format de l'app, pas seulement une forme plausible. L'app lit le
/// depot (elle n'y ecrit pas) : l'exemple est copie dans un dossier temporaire, ou les lecteurs peuvent ecrire.
/// Aucune lecture ne depend de la date du jour (fenetres de 30 jours, purge a 90 jours) : l'exemple reste lisible.
@MainActor
@Suite("Export d'exemple relu par Maillage Thread")
struct ExportExempleLisibleTests {
    nonisolated static let exemple = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // MaillageThreadTests
        .deletingLastPathComponent()  // racine du depot
        .appendingPathComponent("docs/export-exemple")

    /// Une copie de l'exemple, supprimee a la fin du test.
    final class Copie {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("export-exemple-\(UUID().uuidString)")

        init() throws {
            try FileManager.default.copyItem(at: ExportExempleLisibleTests.exemple, to: dossier)
        }

        deinit { try? FileManager.default.removeItem(at: dossier) }

        func url(_ chemin: String) -> URL { dossier.appendingPathComponent(chemin) }
    }

    @Test func manifesteEtReglagesRelus() throws {
        let (m, r) = try ContratExport.verifierDossier(Self.exemple)
        #expect(m.app == .maillageThread)
        #expect(r.valeurs["sondeNom"] == .texte("SONDE-T1"))
    }

    /// Surnoms, associations, dernier maillage et dernieres adresses : relus par la surveillance de l'app.
    @Test func relusParLaSurveillance() throws {
        let c = try Copie()
        let s = Surveillance(mode: .direct, dossier: c.dossier)
        #expect(s.noms.surnoms["0000000000000002"] == "Prise 1")
        #expect(s.noms.surnoms.count == 4)
        #expect(s.noms.associations == ["0000000000000004": "00000000000000AA"])
        s.chargerMaillageGarde()
        #expect(s.maillage?.partition == "0000000A")
        #expect(s.maillageRelu)
        let (manifeste, _) = try ContratExport.verifierDossier(Self.exemple)
        s.chargerAdressesGardees(maintenant: manifeste.date)
        #expect(s.suivi.dernieresAdresses["0000000000000002"] == AdresseIPv6("fd00:0:0:1::2"))
    }

    /// Historique et journal : tous les mois, avril compris, lus sans purge.
    @Test func historiqueEtJournalRelus() throws {
        let c = try Copie()
        let releves = try HistoriqueFichiers(dossier: c.dossier).lire(depuis: .distantPast)
        #expect(releves.count == 3)
        #expect(releves.allSatisfy { $0.partition == "0000000A" })
        let evenements = try JournalFichiers(dossier: c.url("Journal")).lire()
        #expect(evenements.map(\.type) == [.surveillanceDemarree, .surveillanceDemarree, .appareilNouveau,
                                           .routeurDisparu])
    }

    /// Releve de Maison, identites des routeurs, pieces choisies et places des pieces : relus par leurs lecteurs dans
    /// l'app.
    @Test func relusParLesAutresLecteurs() throws {
        let c = try Copie()
        let maison = try NomsMaison.lire(Data(contentsOf: c.url("noms.json")))
        #expect(maison.statut == .ok && maison.accessoires.count == 3 && maison.domicile == "Maison 1")
        let identites = try #require(IdentitesGardees.lire(c.url("identites-routeurs.json")))
        #expect(identites.identites[0x0400] == "0000000000000001")
        let pieces = PiecesChoisies(fichier: c.url("pieces-routeurs.json"))
        #expect(pieces.pieceChoisie(.routeur("Routeur 1"), domicile: "Maison 1") == "Pièce 1")
        #expect(pieces.pieceChoisie(.appareil("0000000000000002"), domicile: "Maison 1") == "Pièce 2")
        let places = PlacesGardees.lire(c.url("positions-pieces.json"))
        #expect(places.maison("Maison 1").etages["zone:Étage 1"]?.count == 2)
        #expect(places.maison("Maison 1").aCote["zone:Jardin"]?.dehors == true)
    }
}
