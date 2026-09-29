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
}
