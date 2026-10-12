import Foundation
import Testing
@testable import MaillageCoeur

/// Appareils qui n'annoncent plus d'adresse, verifies par la sonde (12/10) : derniere adresse gardee par le suivi,
/// demandee a la sonde, appareils trouves portes par le maillage, rapprochement par la derniere adresse.
@Suite("Adresse non annoncee, verifiee par la sonde")
struct AdresseVerifieeTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    static let omr = "fd00:aaaa:bbbb:1::/64"
    static let partition = "0000AAAA"
    static let a1 = "0000000000000001"
    static let a2 = "0000000000000002"
    static let a3 = "0000000000000003"

    static func adresse(_ n: Int) -> String { "fd00:aaaa:bbbb:1::\(n)" }

    /// Un chef qui publie le prefixe OMR, trois appareils avec leur adresse, un appareil sans adresse des le depart.
    static func banc(_ date: Date) -> Banc {
        var b = Banc(date: date)
        b.routeur("Chef", partition: partition, role: .chef, primaire: true, lien: "fe80::1", omr: omr,
                  xa: "E1000000000000A1")
        b.appareil(a1, noeud: 1, adresses: [adresse(1), "fe80::11"])
        b.appareil(a2, noeud: 2, adresses: [adresse(2)])
        b.appareil(a3, noeud: 3, adresses: [adresse(3)])
        b.appareil("Jamais-Adresse", noeud: 4, adresses: [])
        return b
    }

    /// Le suivi apres le depart, puis `a1` sans adresse et `a2` disparu, au-dela du sursis de 2 min.
    static func suiviApresPerte() -> Suivi {
        var s = Suivi()
        _ = s.integrer(banc(t0).annonces)
        var b = banc(t0 + 60)
        b.adresses[a1 + ".local"] = []
        b.retirer(a2)
        _ = s.integrer(b.annonces)
        b.date = t0 + 200
        _ = s.integrer(b.annonces)
        return s
    }

    /// La derniere adresse sur le prefixe OMR de chaque appareil est gardee, et mise a jour a chaque instantane ou il
    /// en a une ; perdue par Bonjour, elle reste.
    @Test func derniereAdresseGardee() throws {
        var s = Suivi()
        _ = s.integrer(Self.banc(Self.t0).annonces)
        #expect(s.dernieresAdresses[Self.a1] == AdresseIPv6(Self.adresse(1)), "l'adresse OMR, pas la lien-local")
        #expect(s.dernieresAdresses["Jamais-Adresse"] == nil)
        var b = Self.banc(Self.t0 + 60)
        b.adresses[Self.a1 + ".local"] = [Self.adresse(0x21)]
        _ = s.integrer(b.annonces)
        #expect(s.dernieresAdresses[Self.a1] == AdresseIPv6(Self.adresse(0x21)), "mise a jour")
        let perdu = Self.suiviApresPerte()
        #expect(perdu.instantane?.appareil(Self.a1)?.etat == .sansAdresse)
        #expect(perdu.disparus[Self.a2] != nil)
        #expect(perdu.dernieresAdresses[Self.a1] == AdresseIPv6(Self.adresse(1)), "gardee sans adresse")
        #expect(perdu.dernieresAdresses[Self.a2] == AdresseIPv6(Self.adresse(2)), "gardee disparu")
    }

    /// Les appareils a resoudre : ceux qui annoncent leur adresse, puis l'appareil sans adresse et le disparu, avec
    /// leur derniere adresse et leur derniere partition ; pas un appareil qui n'a jamais eu d'adresse OMR.
    @Test func sansAdresseEtDisparuDemandes() throws {
        let s = Self.suiviApresPerte()
        let p = Self.partition
        #expect(AppareilAResoudre.depuis(s) == [
            AppareilAResoudre(id: Self.a1, partition: p, adresse: try #require(AdresseIPv6(Self.adresse(1)))),
            AppareilAResoudre(id: Self.a2, partition: p, adresse: try #require(AdresseIPv6(Self.adresse(2)))),
            AppareilAResoudre(id: Self.a3, partition: p, adresse: try #require(AdresseIPv6(Self.adresse(3)))),
        ])
        let i = try #require(s.instantane)
        #expect(AppareilAResoudre.depuis(i).map(\.id) == [Self.a3], "l'instantane seul : ceux qui l'annoncent")
        #expect(AppareilAResoudre.depuis(Suivi()).isEmpty, "aucun sans instantane")
    }

    /// Le maillage porte les appareils trouves par la resolution (la memoire de la tournee), quel que soit leur
    /// parent, avec leur date ; pas l'introuvable. Ils ne sont pas gardes sur disque : relu, le maillage n'en a aucun.
    @Test func resolusDansLeMaillage() async throws {
        let sonde = try TourneeTests.sondeResolue()
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: TourneeTests.appareils))
        #expect(m.resolus == mem.resolutions.mapValues(\.date))
        #expect(m.resolus["E000000000000004"] == Self.t0, "sous le 20, qui repond : trouve aussi")
        #expect(m.resolus["E00000000000000C"] == nil, "introuvable")
        let relu = try CodageJSON.decodeur().decode(Maillage.self, from: try CodageJSON.encodeur().encode(m))
        #expect(relu.resolus.isEmpty && relu.enfants == m.enfants && relu.resolution == m.resolution)
    }

    /// Un enfant resolu qui n'a l'adresse annoncee d'aucun appareil est rapproche de l'appareil dont c'est la
    /// derniere adresse (un accessoire HomeKit, dont l'hote n'est pas l'ExtMac) ; sans elle, il reste inconnu.
    @Test func rapprocheParSaDerniereAdresse() async throws {
        let sonde = try TourneeTests.sondeResolue()
        let (m, _) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                             appareils: TourneeTests.appareils))
        var b = Banc()
        b.routeur("Apple TV", partition: "46CBEBCD", primaire: true, lien: "fe80::1", omr: "fd00:aaaa:bbbb:1::/64",
                  xa: "E0000000000000A1")
        b.appareil("Prise-HomeKit", noeud: 1, adresses: [])
        let i = Instantane(annonces: b.annonces)
        let r = try #require(i.reseaux.first)
        let sans = MaillageAffiche(maillage: m, reseau: r, appareils: i.appareils)
        #expect(sans.enfants[0xAE01]?.id == "rloc:AE01")
        let avec = MaillageAffiche(maillage: m, reseau: r, appareils: i.appareils,
                                   dernieresAdresses: ["Prise-HomeKit": TourneeTests.omr(0x50)])
        #expect(avec.enfants[0xAE01]?.id == "Prise-HomeKit")
        #expect(avec.parent(de: "Prise-HomeKit") == avec.routeurs[43]?.id)
    }
}
