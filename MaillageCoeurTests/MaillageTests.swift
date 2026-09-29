import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Maillage : construction depuis les reponses d'une tournee")
struct MaillageTests {
    static func reponse(_ id: Int) throws -> ReponseDiagnostic {
        try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(id)))
    }

    /// Tournee de la capture : Route64 du chef (6000), 5000 et 6000 qui repondent,
    /// les 5 routeurs de bordure muets, Network Data, balayage sous AC00, la sonde.
    static func tournee() throws -> Maillage {
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.routeurs(try #require(try reponse(204).route64), chef: 24)
        c.reponse(try reponse(104), routeur: 20)
        c.pile(try reponse(105).pile, routeur: 20)
        c.reponse(try reponse(106), routeur: 24)
        c.pile(try reponse(107).pile, routeur: 24)
        for id in [1, 43, 45, 51, 57] { c.muet(id) }
        let brutes = try #require(try reponse(206).donneesReseau)
        c.reseau(try #require(DonneesReseau(brutes)))
        for id in 503...508 {
            let r = try reponse(id)
            c.enfant(EnfantMaillage(rloc16: try #require(r.rloc16), extMac: r.extMac, endormi: r.mode?.endormi,
                                    source: .balayage))
        }
        c.enfant(EnfantMaillage(rloc16: 0xAC09, qualite: 3, source: .sonde))
        c.identite("E000000000000007", routeur: 43)
        c.identite("FFFFFFFFFFFFFFFF", routeur: 20)
        return c.maillage()
    }

    /// Routeurs : chef, bordures (Network Data), BBR principal, muets, identite de ceux qui repondent.
    @Test func routeurs() throws {
        let m = try Self.tournee()
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        #expect(m.chef?.id == 24)
        #expect(m.routeurs.filter(\.bordure).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m.routeurs.filter(\.bbrPrincipal).map(\.id) == [45])
        #expect(m.routeurs.filter(\.muet).map(\.id) == [1, 43, 45, 51, 57])
        let r = try #require(m.routeur(20))
        #expect(r.extMac == "E000000000000002", "sa propre reponse passe avant une identite apprise")
        #expect(r.version == 5)
        #expect(r.pile?.hasPrefix("SL-OPENTHREAD/2.5.1.0") == true)
        #expect(m.routeur(24)?.extMac == "E000000000000003")
        #expect(m.routeur(43)?.extMac == "E000000000000007", "muet : ExtMac apprise (parent de la sonde)")
        #expect(r.rloc16 == 0x5000)
    }

    /// Liens entre voisins seulement, vus par 5000 et 6000, qualite dans chaque sens.
    @Test func liens() throws {
        let m = try Self.tournee()
        #expect(m.liens.map { [$0.a, $0.b] } == [[1, 20], [1, 24], [20, 24], [20, 45], [20, 51], [24, 45], [24, 51]])
        let l = try #require(m.liens.first { $0.a == 20 && $0.b == 51 })
        #expect(l.qualiteAB == 1, "de 20 vers 51")
        #expect(l.qualiteBA == 2, "de 51 vers 20")
        #expect(l.qualite == 1)
        #expect(m.liens.first { $0.a == 20 && $0.b == 24 }?.qualite == 3)
        #expect(m.liens(de: 45).count == 2, "muet : ses liens viennent des autres")
    }

    /// Enfants : tables de 5000 et 6000, balayage sous AC00, la sonde.
    @Test func enfants() throws {
        let m = try Self.tournee()
        #expect(m.enfants.count == 13)
        let de20 = m.enfants(de: 20)
        #expect(de20.map(\.rloc16) == [0x5001, 0x5004])
        #expect(de20.allSatisfy { $0.source == .tableEnfants && $0.qualite != nil && $0.endormi == true })
        let de43 = m.enfants(de: 43)
        #expect(de43.map(\.rloc16) == [0xAC03, 0xAC04, 0xAC05, 0xAC06, 0xAC07, 0xAC08, 0xAC09])
        let ac04 = try #require(de43.first { $0.rloc16 == 0xAC04 })
        #expect(ac04.extMac == "E00000000000000A")
        #expect(ac04.qualite == nil, "sous un routeur muet")
        #expect(ac04.source == .balayage)
        #expect(de43.last?.source == .sonde)
        #expect(m.enfants(de: 24).count == 4)
    }

    /// Un enfant vu dans une table puis interroge : l'identite complete l'entree.
    @Test func fusion() throws {
        var c = ConstructionMaillage(date: .now, partition: "46CBEBCD")
        c.reponse(try Self.reponse(104), routeur: 20)
        #expect(c.enfantsSansIdentite == [0x5001, 0x5004])
        let adresse = try #require(AdresseIPv6("fd00:5555:6666:0:a00::7"))
        c.enfant(EnfantMaillage(rloc16: 0x5004, extMac: "E000000000000004", endormi: true, adresses: [adresse],
                                source: .balayage))
        #expect(c.enfantsSansIdentite == [0x5001])
        let e = try #require(c.maillage().enfants.first { $0.rloc16 == 0x5004 })
        #expect(e.extMac == "E000000000000004")
        #expect(e.adresses == [adresse])
        #expect(e.qualite == 2, "qualite de la table gardee")
        #expect(e.source == .tableEnfants)
    }

    // BBR principal, comme OpenThread : le chef s'il est parmi les serveurs BBR, meme avec une sequence
    // plus basse ; sinon le premier de `bbr`. Network Data construites a la main : un Service BBR et
    // deux Server (stable) de 9 octets = RLOC16 (2), sequence (1), reenregistrement 5 s, delai MLR 3600 s.

    /// B400 (sequence 0x57) puis 6000, le chef (sequence 0x10), dans l'ordre du document.
    static let bbrB400Puis6000: [UInt8] = [
        0x0B, 25,                                  // Service (stable), 25 octets
        0x80,                                      // T = 1 (numero d'entreprise Thread omis), identifiant 0
        1, 0x01,                                   // donnees de service : 1 octet, 01 (BBR)
        0x0D, 9, 0xB4, 0x00,                       // Server (stable), 9 octets : RLOC16 B400
        0x57, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x57, delais
        0x0D, 9, 0x60, 0x00,                       // Server (stable), 9 octets : RLOC16 6000
        0x10, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x10, memes delais
    ]

    /// E400 (sequence 0x10) puis B400 (sequence 0x57), dans l'ordre du document.
    static let bbrE400PuisB400: [UInt8] = [
        0x0B, 25,                                  // Service (stable), 25 octets
        0x80,                                      // T = 1 (numero d'entreprise Thread omis), identifiant 0
        1, 0x01,                                   // donnees de service : 1 octet, 01 (BBR)
        0x0D, 9, 0xE4, 0x00,                       // Server (stable), 9 octets : RLOC16 E400
        0x10, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x10, delais
        0x0D, 9, 0xB4, 0x00,                       // Server (stable), 9 octets : RLOC16 B400
        0x57, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,  //   sequence 0x57, memes delais
    ]

    /// Le chef (6000, routeur 24) est BBR avec une sequence plus basse que B400 (routeur 45) : c'est lui le principal.
    @Test func bbrPrincipalChef() throws {
        let d = try #require(DonneesReseau(Self.bbrB400Puis6000))
        #expect(d.bbr == [0xB400, 0x6000], "le chef n'est pas en tete de `bbr`")
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.routeurs(try #require(try Self.reponse(204).route64), chef: 24)
        c.reseau(d)
        let m = c.maillage()
        #expect(m.routeurs.filter(\.bbrPrincipal).map(\.id) == [24])
        #expect(m.routeur(45)?.bbrPrincipal == false)
    }

    /// Le chef (6000) n'est pas parmi les serveurs BBR : le principal est le premier de `bbr`, B400.
    @Test func bbrPrincipalSansLeChef() throws {
        let d = try #require(DonneesReseau(Self.bbrE400PuisB400))
        #expect(d.bbr == [0xB400, 0xE400])
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.routeurs(try #require(try Self.reponse(204).route64), chef: 24)
        c.reseau(d)
        let m = c.maillage()
        #expect(m.routeurs.filter(\.bbrPrincipal).map(\.id) == [45])
        #expect(m.routeur(57)?.bbrPrincipal == false)
    }

    /// Network Data d'une tournee precedente (`seulementConnus`) : pour les seuls routeurs de la
    /// liste ; un routeur qui n'y est plus n'est pas rajoute, et un serveur BBR qui n'y est plus ne
    /// compte pas (le principal est alors le premier des autres). Lues a la tournee, elles
    /// rajoutent le routeur, comme avant.
    @Test func reseauPrecedent() throws {
        // Prefix ::/0 : Has Route 5C00 (routeur 23, absent de la Route64) ; service BBR : 5C00
        // (sequence 0x60) puis B400 (sequence 0x57).
        let route: [UInt8] = [0x03, 7, 0x00, 0, 0x00, 3, 0x5C, 0x00, 0x00]
        let bbr: [UInt8] = [0x0B, 25, 0x80, 1, 0x01,
                            0x0D, 9, 0x5C, 0x00, 0x60, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10,
                            0x0D, 9, 0xB4, 0x00, 0x57, 0x00, 0x05, 0x00, 0x00, 0x0E, 0x10]
        let d = try #require(DonneesReseau(route + bbr))
        #expect(d.routeursDeBordure == [0x5C00] && d.bbr == [0x5C00, 0xB400])
        let route64 = try #require(try Self.reponse(204).route64)
        var precedent = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        precedent.routeurs(route64, chef: 24)
        precedent.reseau(d, seulementConnus: true)
        let m = precedent.maillage()
        #expect(m.routeur(23) == nil)
        #expect(m.routeurs.filter(\.bbrPrincipal).map(\.id) == [45])
        var lues = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        lues.routeurs(route64, chef: 24)
        lues.reseau(d)
        #expect(lues.maillage().routeur(23)?.bordure == true)
        #expect(lues.maillage().routeurs.filter(\.bbrPrincipal).map(\.id) == [23])
    }

    /// Chef pas encore connu (`routeurs(_:chef:)` pas encore appele) : le premier de `bbr`.
    @Test func bbrPrincipalChefInconnu() throws {
        let d = try #require(DonneesReseau(Self.bbrE400PuisB400))
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.reseau(d)
        #expect(c.maillage().routeurs.filter(\.bbrPrincipal).map(\.id) == [45])
    }
}
