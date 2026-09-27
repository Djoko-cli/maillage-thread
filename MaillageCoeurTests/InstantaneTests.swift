import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Calcul de l'instantane")
struct InstantaneTests {
    @Test func releveReel() throws {
        let i = Instantane(annonces: Releve20260928.annonces)
        #expect(i.reseaux.count == 1)
        let r = try #require(i.reseaux.first)
        #expect(r.id == "4B36A2B7FEFB200B")
        #expect(r.nom == "MyHome1482620090")
        #expect(r.estScinde)
        #expect(r.partitions.map(\.id) == ["73586B68", "E2E79FFC"])
        #expect(r.prefixeLocal?.description == "fd4b:36a2:b7fe:200b::/64")
        let p = try #require(r.principale)
        #expect(p.estPrincipale)
        #expect(p.routeurs.map(\.instance) == ["Apple TV 4K", "HomePod Avant", "HomePod Palier",
                                              "HomePod mini bureau", "HomePod mini chambre"])
        #expect(p.chef?.instance == "Apple TV 4K")
        #expect(p.bbrPrimaire?.instance == "Apple TV 4K")
        #expect(p.prefixes.map(\.description) == ["fd19:961f:2db3::/64"])
        #expect(p.appareils.count == 22)
        let coupee = r.partitions[1]
        #expect(!coupee.estPrincipale)
        #expect(coupee.routeurs.map(\.instance) == ["Aqara HubM100 #DFEB"])
        #expect(coupee.chef == nil, "role inconnu (Thread 1.3.0)")
        #expect(coupee.prefixes.map(\.description) == ["fd03:54f0:5de:1::/64"])
        #expect(coupee.appareils.isEmpty)

        #expect(i.appareils.count == 24)
        #expect(i.appareils.filter { $0.etat == .joignable }.count == 22)
        #expect(i.appareils.filter { $0.etat == .sansAdresse }.map(\.id) == ["1E5019DAC2638F92", "724CC16B32D8F820"])
        let halo = try #require(i.appareil("56B1E064401F74EF"))
        #expect(halo.fabriques == ["20D00941B54CEF76", "30FC8F95E0E1A385"])
        #expect(halo.genre == .thread)
        #expect(halo.partition == "73586B68")
        #expect(halo.idReseau == "4B36A2B7FEFB200B")
        #expect(halo.prefixe?.description == "fd19:961f:2db3::/64")
        #expect(!halo.endormi, "pont alimente : SII 2000")
        #expect(halo.servicesMatter.count == 2)
        #expect(i.appareil("1E5019DAC2638F92")?.endormi == true)
        #expect(i.appareilsIP.map(\.id) == ["54EF4497B8820000", "A013F03091F3", "C4299622387B", "C4E7AE91A29B"])
        #expect(i.appareilsIP.allSatisfy { $0.etat == .joignable && $0.genre == .ip })
        #expect(i.prefixesSansPartition.isEmpty)
        #expect(i.prefixes.map(\.description) == ["fd03:54f0:5de:1::/64", "fd19:961f:2db3::/64"])
    }

    @Test func sansTableDeRoutage() throws {
        // Bac a sable sans routes : fd19 par elimination (l'Aqara publie fd03 dans son TXT).
        var a = Releve20260928.annonces
        a.routes = []
        let i = Instantane(annonces: a)
        #expect(i.reseaux.first?.principale?.prefixes.map(\.description) == ["fd19:961f:2db3::/64"])
        #expect(i.appareils.filter { $0.etat == .joignable }.count == 22)
    }

    @Test func unePartitionPrendTousLesPrefixes() {
        var b = Banc()
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Second", lien: "fe80::2")
        b.appareil("AAAA000000000001", adresses: ["fd19:961f:2db3::11"])
        b.appareil("AAAA000000000002", noeud: 2, adresses: ["fd4f:9c:ed42::12"])
        let i = Instantane(annonces: b.annonces)
        #expect(i.reseaux.first?.partitions.count == 1)
        #expect(i.reseaux.first?.prefixes.map(\.description) == ["fd19:961f:2db3::/64", "fd4f:9c:ed42::/64"])
        #expect(i.appareils.allSatisfy { $0.etat == .joignable })
    }

    @Test func routeDuMac() {
        var b = Banc()
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Isole", partition: "E2E79FFC", role: nil, primaire: true, lien: "fe80::2")
        b.route("fd03:54f0:5de:1::/64", via: "fe80::2")
        b.route("fd19:961f:2db3::/64", via: "fe80::1")
        b.route("fd4b:36a2:b7fe:200b::/64", via: "fe80::1")   // prefixe local : ignore
        b.appareil("AAAA000000000001", adresses: ["fd03:54f0:5de:1::5"])
        b.appareil("AAAA000000000002", noeud: 2, adresses: ["fd19:961f:2db3::6"])
        b.appareil("AAAA000000000003", noeud: 3, adresses: ["fd19:961f:2db3::7"])
        let i = Instantane(annonces: b.annonces)
        #expect(i.reseaux.first?.partitions.map(\.id) == ["73586B68", "E2E79FFC"], "3 noeuds contre 2")
        #expect(i.appareil("AAAA000000000001")?.etat == .partitionCoupee)
        #expect(i.appareil("AAAA000000000001")?.partition == "E2E79FFC")
        #expect(i.appareil("AAAA000000000002")?.etat == .joignable)
    }

    @Test func prefixesSansPartition() {
        var b = Banc()
        b.routeur("Chef", role: .chef, lien: "fe80::1")
        b.routeur("Isole", partition: "E2E79FFC", role: nil, lien: "fe80::2")
        b.appareil("AAAA000000000001", adresses: ["fd03:54f0:5de:1::5"])
        b.appareil("AAAA000000000002", noeud: 2, adresses: ["fd19:961f:2db3::6"])
        let i = Instantane(annonces: b.annonces)
        #expect(i.prefixesSansPartition.map(\.description) == ["fd03:54f0:5de:1::/64", "fd19:961f:2db3::/64"])
        #expect(i.appareils.allSatisfy { $0.etat == .inconnu && $0.genre == .thread && $0.partition == nil })
    }

    @Test func principaleAEgalite() {
        var b = Banc()
        b.routeur("B", partition: "11111111", role: .routeur, lien: "fe80::1")
        b.routeur("A", partition: "22222222", role: .chef, lien: "fe80::2")
        let i = Instantane(annonces: b.annonces)
        #expect(i.reseaux.first?.partitions.map(\.id) == ["22222222", "11111111"], "a egalite : celle du chef")
    }

    @Test func centreDePartition() {
        var b = Banc()
        b.routeur("Zeta", role: nil, lien: "fe80::1")
        b.routeur("Beta", role: nil, primaire: true, lien: "fe80::2")
        b.routeur("Alpha", role: nil, lien: "fe80::3")
        let p = Instantane(annonces: b.annonces).reseaux.first?.principale
        #expect(p?.routeurs.map(\.instance) == ["Beta", "Alpha", "Zeta"], "sans chef connu : le BBR primaire au centre")
        #expect(p?.chef == nil)
    }

    @Test func hotesEtHAP() {
        var b = Banc()
        b.routeur("Chef", role: .chef, lien: "fe80::1")
        b.matter.append(AnnonceService(instance: "30FC8F95E0E1A385-0000000000000009"))
        b.hap.append(AnnonceService(instance: "Eve Door 4A3B", hote: "Eve-Door-4A3B.local",
                                    txt: ChampsTXT(["md": Data("Eve Door".utf8)])))
        b.adresses["Eve-Door-4A3B.local"] = ["fd19:961f:2db3::44"]
        let i = Instantane(annonces: b.annonces)
        #expect(i.appareil("instance:30FC8F95E0E1A385-0000000000000009")?.etat == .sansAdresse)
        let eve = i.appareil("Eve-Door-4A3B")
        #expect(eve?.hap?.modele == "Eve Door")
        #expect(eve?.etat == .joignable)
        #expect(Instantane.idAppareil(hote: "56B1E064401F74EF.local.", instance: "x") == "56B1E064401F74EF")
        #expect(Instantane.idAppareil(hote: "", instance: "x") == "instance:x")
    }
}
