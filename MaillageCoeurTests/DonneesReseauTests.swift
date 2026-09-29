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

    // Ordre des serveurs BBR : celui d'OpenThread (Manager::IsBackboneRouterPreferredTo), le chef mis a part.
    // Un Server (stable) de BBR : 0x0D, 9 octets = RLOC16 (2), puis les donnees de serveur (7) :
    // sequence (1), delai de reenregistrement (2), delai MLR (4).

    /// Deux serveurs BBR d'un meme service, E400 (sequence 0x10) puis B400 (sequence 0x57) : la sequence
    /// la plus haute passe avant l'ordre du document.
    @Test func bbrSequenceLaPlusHaute() throws {
        let service: [UInt8] = [
            0x0B, 25,                                  // Service (stable), 25 octets
            0x80,                                      // T = 1 (numero d'entreprise Thread omis), identifiant 0
            1, 0x01,                                   // donnees de service : 1 octet, 01 (BBR)
            0x0D, 9, 0xE4, 0x00,                       // Server (stable), 9 octets : RLOC16 E400
            0x10, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x10, reenregistrement 5 s, delai MLR 3600 s
            0x0D, 9, 0xB4, 0x00,                       // Server (stable), 9 octets : RLOC16 B400
            0x57, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x57, memes delais
        ]
        let d = try #require(DonneesReseau(service))
        #expect(d.bbr == [0xB400, 0xE400])
    }

    /// Deux serveurs BBR de meme sequence, 5000 puis AC00 : le RLOC16 le plus haut d'abord.
    @Test func bbrMemeSequence() throws {
        let service: [UInt8] = [
            0x0B, 25,                                  // Service (stable), 25 octets
            0x80,                                      // T = 1, identifiant 0
            1, 0x01,                                   // donnees de service : 1 octet, 01 (BBR)
            0x0D, 9, 0x50, 0x00,                       // Server (stable), 9 octets : RLOC16 5000
            0x22, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x22, reenregistrement 5 s, delai MLR 3600 s
            0x0D, 9, 0xAC, 0x00,                       // Server (stable), 9 octets : RLOC16 AC00
            0x22, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x22 aussi, memes delais
        ]
        let d = try #require(DonneesReseau(service))
        #expect(d.bbr == [0xAC00, 0x5000])
    }

    /// Sequence comparee simplement, sans arithmetique de serie : 0xFF passe avant 0x01.
    @Test func bbrSequenceComparaisonSimple() throws {
        let service: [UInt8] = [
            0x0B, 25,                                  // Service (stable), 25 octets
            0x80,                                      // T = 1, identifiant 0
            1, 0x01,                                   // donnees de service : 1 octet, 01 (BBR)
            0x0D, 9, 0xAC, 0x00,                       // Server (stable), 9 octets : RLOC16 AC00
            0x01, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x01, reenregistrement 5 s, delai MLR 3600 s
            0x0D, 9, 0x50, 0x00,                       // Server (stable), 9 octets : RLOC16 5000
            0xFF, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0xFF, memes delais
        ]
        let d = try #require(DonneesReseau(service))
        #expect(d.bbr == [0x5000, 0xAC00])
    }

    /// Serveurs BBR aux donnees trop courtes (moins de 7 octets) : ignores, meme avec la sequence la plus haute.
    @Test func bbrDonneesTropCourtes() throws {
        let service: [UInt8] = [
            0x0B, 28,                                  // Service (stable), 28 octets
            0x80,                                      // T = 1, identifiant 0
            1, 0x01,                                   // donnees de service : 1 octet, 01 (BBR)
            0x0D, 8, 0xE4, 0x00,                       // Server (stable), 8 octets : RLOC16 E400
            0x99, 0x00, 0x05, 0x00, 0x00, 0x0E,        //   6 octets de donnees : sequence 0x99, delai MLR coupe
            0x0D, 2, 0xCC, 0x00,                       // Server (stable), 2 octets : RLOC16 CC00, sans donnees
            0x0D, 9, 0xB4, 0x00,                       // Server (stable), 9 octets : RLOC16 B400
            0x57, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   7 octets de donnees, le minimum : sequence 0x57
        ]
        let d = try #require(DonneesReseau(service))
        #expect(d.bbr == [0xB400])
    }

    /// Deux TLV Service BBR, un serveur chacune : tous les serveurs comptent avant le tri.
    @Test func bbrPlusieursServices() throws {
        let services: [UInt8] = [
            0x0B, 14,                                  // Service (stable), 14 octets
            0x80,                                      // T = 1, identifiant 0
            1, 0x01,                                   // donnees de service : 1 octet, 01 (BBR)
            0x0D, 9, 0xAC, 0x00,                       // Server (stable), 9 octets : RLOC16 AC00
            0x05, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x05, reenregistrement 5 s, delai MLR 3600 s
            0x0B, 14,                                  // Service (stable), 14 octets
            0x81,                                      // T = 1, identifiant 1
            1, 0x01,                                   // donnees de service : 1 octet, 01 (BBR)
            0x0D, 9, 0x50, 0x00,                       // Server (stable), 9 octets : RLOC16 5000
            0x09, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x09, memes delais
        ]
        let d = try #require(DonneesReseau(services))
        #expect(d.bbr == [0x5000, 0xAC00])
    }
}
