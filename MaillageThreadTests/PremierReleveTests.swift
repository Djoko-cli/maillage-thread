import Foundation
import Testing
@testable import MaillageThread

@MainActor
@Suite("Recenseur : moment du premier releve")
struct PremierReleveTests {
    /// Premier releve : jamais avant 10 s ; des que l'ecoute est prete et qu'un
    /// routeur de bordure est liste ; au plus tard 60 s apres le demarrage.
    @Test func momentDuPremierReleve() {
        func du(_ secondes: Int, _ etat: Recenseur.Etat, routeur: Bool) -> Bool {
            Recenseur.premierReleveDu(depuis: .seconds(secondes), etat: etat, routeurVu: routeur)
        }
        #expect(!du(5, .actif, routeur: true), "jamais avant la mise en route")
        #expect(du(10, .actif, routeur: true), "ecoute prete et routeur vu")
        #expect(!du(10, .actif, routeur: false), "aucun routeur vu : on attend")
        #expect(!du(10, .demarrage, routeur: true), "un navigateur n'est pas encore pret")
        #expect(!du(30, .reseauLocalRefuse, routeur: false), "invite ou refus : on attend")
        #expect(!du(59, .erreur("reseau coupe"), routeur: true))
        #expect(du(60, .demarrage, routeur: false), "au plus tard 60 s apres le demarrage")
        #expect(du(60, .reseauLocalRefuse, routeur: false))
        #expect(Recenseur.miseEnRoute == .seconds(10))
        #expect(Recenseur.attenteMax == .seconds(60))
    }
}
