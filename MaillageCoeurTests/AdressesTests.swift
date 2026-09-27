import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Adresses et prefixes IPv6")
struct AdressesTests {
    @Test func lectureEtEcriture() throws {
        let a = try #require(AdresseIPv6("fd2d:3b27:72b8:0000:2c97:f3e3:ac5e:9b25"))
        #expect(a.description == "fd2d:3b27:72b8:0:2c97:f3e3:ac5e:9b25", "un seul zero : pas de ::")
        #expect(AdresseIPv6("fe80::4e:ff54:91ca:c791%en0")?.description == "fe80::4e:ff54:91ca:c791", "zone ignoree")
        #expect(AdresseIPv6("192.168.1.19") == nil)
        #expect(AdresseIPv6("") == nil)
        #expect(AdresseIPv6(octets: [1, 2]) == nil)
        #expect(AdresseIPv6("fe80::4e:ff54:91ca:c791")?.estLienLocal == true)
        #expect(!a.estLienLocal)
        #expect(AdresseIPv6.estIPv4("192.168.1.19"))
        #expect(!AdresseIPv6.estIPv4("fe80::1"))
    }

    @Test func prefixes() throws {
        let p = try #require(PrefixeIPv6("fd2d:3b27:72b8::/64"))
        #expect(p.description == "fd2d:3b27:72b8::/64")
        #expect(PrefixeIPv6("fd2d:3b27:72b8::")?.description == "fd2d:3b27:72b8::/64")
        #expect(PrefixeIPv6("fd2d:3b27:72b8::/48") == nil)
        let dedans = try #require(AdresseIPv6("fd2d:3b27:72b8:0:2c97:f3e3:ac5e:9b25"))
        let dehors = try #require(AdresseIPv6("fd0d:eec8:5ef:1::5"))
        #expect(p.contient(dedans))
        #expect(!p.contient(dehors))
        #expect(dedans.prefixe == p)
        #expect(dehors.prefixe.description == "fd0d:eec8:5ef:1::/64")
    }

    @Test func champOMR() {
        // Aqara HubM100, releve du 28/09 : omr=40FD0DEEC805EF0001
        let omr = Data([0x40, 0xFD, 0x0D, 0xEE, 0xC8, 0x05, 0xEF, 0x00, 0x01])
        #expect(PrefixeIPv6(omr: omr)?.description == "fd0d:eec8:5ef:1::/64")
        #expect(PrefixeIPv6(omr: Data([0x30] + [UInt8](repeating: 0, count: 8))) == nil, "longueur 48 refusee")
        #expect(PrefixeIPv6(omr: Data([0x40, 0xFD])) == nil)
    }

    @Test func reseauLocalTireDuXP() {
        // xp=4B5D376D942B480E -> fd4b:5d37:6d94:480e::/64 (table de routage du Mac, 28/09)
        let xp: [UInt8] = [0x4B, 0x5D, 0x37, 0x6D, 0x94, 0x2B, 0x48, 0x0E]
        #expect(PrefixeIPv6(reseauLocalDe: xp)?.description == "fd4b:5d37:6d94:480e::/64")
        #expect(PrefixeIPv6(reseauLocalDe: [0x01]) == nil)
    }

    @Test func ordreEtJSON() throws {
        let a = try #require(PrefixeIPv6("fd0d:eec8:5ef:1::/64"))
        let b = try #require(PrefixeIPv6("fd2d:3b27:72b8::/64"))
        #expect([b, a].sorted() == [a, b])
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = .withoutEscapingSlashes
        let json = try encodeur.encode([a])
        #expect(String(decoding: json, as: UTF8.self) == "[\"fd0d:eec8:5ef:1::/64\"]")
        #expect(try JSONDecoder().decode([PrefixeIPv6].self, from: json) == [a])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([PrefixeIPv6].self, from: Data("[\"pas un prefixe\"]".utf8))
        }
    }
}
