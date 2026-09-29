import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Network Data : routeurs de bordure, BBR, OMR")
struct DonneesReseauTests {
    /// Network Data de la partition d'Apple, lues au routeur 5000 : les 5 routeurs
    /// de bordure (route fc00::/7, service SRP), B400 principal (BBR, OMR).
    @Test func partitionApple() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(206)))
        let brutes = try #require(r.donneesReseau)
        let d = try #require(DonneesReseau(brutes))
        #expect(d.routeursDeBordure == [0x0400, 0xAC00, 0xB400, 0xCC00, 0xE400])
        #expect(d.bbr == [0xB400])
        #expect(d.publientOMR == [0xB400])
    }

    /// Prefixe /64 publie par un routeur de bordure, route seule par un autre.
    @Test func construites() throws {
        // Prefix (stable) fd00:1:2:3::/64 : Border Router 4800 ; Prefix ::/0 : Has Route 5C00.
        let omr: [UInt8] = [0x03, 16, 0x00, 64, 0xFD, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00, 0x03,
                            0x04, 4, 0x48, 0x00, 0x00, 0x00]
        let route: [UInt8] = [0x03, 7, 0x00, 0, 0x00, 3, 0x5C, 0x00, 0x00]
        let d = try #require(DonneesReseau(omr + route))
        #expect(d.routeursDeBordure == [0x4800, 0x5C00])
        #expect(d.publientOMR == [0x4800])
        #expect(d.bbr.isEmpty)
    }

    @Test func tronquees() {
        #expect(DonneesReseau([0x03, 10, 0x00]) == nil)
        #expect(DonneesReseau([]) == DonneesReseau([0x10, 0]), "vides, ou TLV inconnue : rien")
    }
}
