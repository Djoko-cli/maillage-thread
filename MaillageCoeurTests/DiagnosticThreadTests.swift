import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Diagnostic Thread : TLV des reponses")
struct DiagnosticThreadTests {
    /// Routeur 5000 (EFR32) : identite, liens avec qualite et cout, enfants, adresses, version.
    @Test func routeurQuiRepond() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(104)))
        #expect(r.extMac == "E000000000000002")
        #expect(r.rloc16 == 0x5000)
        let route = try #require(r.route64)
        #expect(route.sequence == 186)
        #expect(route.routeurs == [1, 20, 24, 43, 45, 51, 57])
        #expect(route.route(vers: 24) == RouteRouteur(idRouteur: 24, qualiteSortante: 3, qualiteEntrante: 3, cout: 1))
        #expect(route.route(vers: 51) == RouteRouteur(idRouteur: 51, qualiteSortante: 1, qualiteEntrante: 2, cout: 3))
        #expect(route.route(vers: 43)?.estVoisin == false, "pas voisin : joint par une route de cout 3")
        let enfants = try #require(r.enfants)
        #expect(enfants.map(\.idEnfant) == [4, 1])
        #expect(enfants[0].qualite == 2)
        #expect(enfants[0].delai == 256)
        #expect(enfants[0].mode.endormi)
        #expect(enfants[0].rloc16(parent: 0x5000) == 0x5004)
        #expect(r.adresses.map(\.description).contains("fd00:1111:2222:c87:0:ff:fe00:5000"), "son RLOC")
        #expect(r.version == 5, "Thread 1.4")
        #expect(r.chef == nil)
        #expect(r.mode == nil)
    }

    /// TLV fabricant : 25 a 27 presentes mais vides (nil), 28 remplie.
    @Test func fabricantVide() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(105)))
        #expect(r.fabricant == nil)
        #expect(r.modele == nil)
        #expect(r.versionLogicielle == nil)
        #expect(r.pile == "SL-OPENTHREAD/2.5.1.0_GitHub-1fceb225b; EFR32; Sep 18 2024 19:39")
    }

    /// Chef (routeur 24) : Route64 et Leader Data.
    @Test func chef() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(101)))
        #expect(r.chef == DonneesChef(partition: "46CBEBCD", poids: 64, version: 108, versionStable: 186, idChef: 24))
        #expect(r.route64?.routeurs.count == 7)
        #expect(r.extMac == nil)
    }

    /// Enfant endormi interroge a son RLOC (5004) : ExtMac, adresses, mode.
    @Test func enfant() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(116)))
        #expect(r.extMac == "E000000000000004")
        let mode = try #require(r.mode)
        #expect(mode.endormi)
        #expect(!mode.appareilComplet)
        #expect(r.adresses.count == 4)
    }

    /// Reponse vide, hexa invalide, TLV tronquee ; chaine vide.
    @Test func casLimites() throws {
        let vide = try #require(ReponseDiagnostic(hexa: ""))
        #expect(vide.extMac == nil)
        #expect(vide.adresses.isEmpty)
        #expect(ReponseDiagnostic(hexa: "0G") == nil)
        #expect(ReponseDiagnostic(hexa: "0008AABB") == nil, "longueur annoncee 8, 2 octets presents")
        #expect(ReponseDiagnostic(hexa: "1900")?.fabricant == nil)
        #expect(ReponseDiagnostic(hexa: "1A03457665")?.modele == "Eve")
    }
}
