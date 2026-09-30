import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Journal : filtre des lignes")
struct JournalVueTests {
    @Test func filtreDuJournal() {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let lignes = s.lignesJournal
        #expect(FiltreJournal().appliquer(lignes).count == 6)
        #expect(FiltreJournal(famille: .appareils).appliquer(lignes).count == 1, "la ligne des pertes")
        #expect(FiltreJournal(famille: .prefixes).appliquer(lignes).count == 2)
        #expect(FiltreJournal(graviteMinimale: .alerte).appliquer(lignes).map { $0.evenements.first?.type }
                == [.reseauScinde])
        #expect(FiltreJournal(recherche: "prise bureau").appliquer(lignes).count == 1, "nom d'un appareil du groupe")
        #expect(FiltreJournal(recherche: "4B36A2B7FEFB200B").appliquer(lignes).isEmpty == false, "identifiant du reseau")
        #expect(FiltreJournal(recherche: "introuvable").appliquer(lignes).isEmpty)
        #expect(FamilleEvenement.reseau.contient(.veille))
        #expect(!FamilleEvenement.routeurs.contient(.appareilDisparu))
    }

    /// Les evenements du maillage de la sonde ont leur famille, « Maillage », et elle seule.
    @Test func familleMaillage() {
        for t in [TypeEvenement.parentChange, .sansParent, .routeurThreadApparu, .routeurThreadDisparu] {
            #expect(FamilleEvenement.allCases.filter { $0 != .toutes && $0.contient(t) } == [.maillage], "\(t)")
        }
    }
}
