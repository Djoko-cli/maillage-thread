import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Suivi : evenements du journal")
struct SuiviTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    static let a1 = "AAAA000000000001"
    static let a2 = "AAAA000000000002"

    /// Reseau de base : un chef, un routeur, deux appareils dans fd2d.
    static func banc(_ date: Date) -> Banc {
        var b = Banc(date: date)
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Second", lien: "fe80::2")
        b.route("fd2d:3b27:72b8::/64", via: "fe80::1")
        b.appareil(a1, noeud: 1, adresses: ["fd2d:3b27:72b8::11"])
        b.appareil(a2, noeud: 2, adresses: ["fd2d:3b27:72b8::12"], sii: 6000)
        return b
    }

    static func demarre() -> Suivi {
        var s = Suivi()
        _ = s.integrer(banc(t0).annonces)
        return s
    }

    @Test func lancement() {
        var s = Suivi()
        let ev = s.integrer(Self.banc(Self.t0).annonces)
        #expect(ev.map(\.type) == [.surveillanceDemarree])
        #expect(ev.first?.details == ["routeurs": "2", "appareils": "2"])
        #expect(ev.first?.gravite == .info)
        #expect(s.integrer(Self.banc(Self.t0 + 60).annonces).isEmpty, "rien n'a change")
        #expect(s.dernieresPartitions[Self.a1] == "7C6A2A68")
    }

    @Test func lancementSurUnReseauScinde() throws {
        var b = Self.banc(Self.t0)
        b.routeur("Isole", partition: "E6A6AD72", role: nil, primaire: true, lien: "fe80::3")
        var s = Suivi()
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.surveillanceDemarree, .reseauScinde])
        let scission = try #require(ev.last)
        #expect(scission.constate)
        #expect(scission.gravite == .alerte)
        #expect(scission.details["E6A6AD72"] == "Isole")
        #expect(scission.details["7C6A2A68"] == "Chef, Second")
    }

    @Test func disparitionConfirmeeApresDeuxMinutes() throws {
        var s = Self.demarre()
        var b = Self.banc(Self.t0 + 60)
        b.retirer(Self.a2)
        #expect(s.integrer(b.annonces).isEmpty, "absence constatee, pas encore retenue")
        b.date = Self.t0 + 120
        #expect(s.integrer(b.annonces).isEmpty, "60 s d'absence")
        b.date = Self.t0 + 180
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.appareilDisparu])
        let e = try #require(ev.first)
        #expect(e.date == Self.t0 + 60, "datee de la premiere absence")
        #expect(e.sujet == Sujet(id: Self.a2, nom: Self.a2))
        #expect(e.avant == "7C6A2A68")
        #expect(e.gravite == .attention)
        #expect(Array(s.disparus.keys) == [Self.a2])

        let retour = s.integrer(Self.banc(Self.t0 + 240).annonces)
        #expect(retour.map(\.type) == [.appareilRevenu])
        #expect(s.disparus.isEmpty)
    }

    @Test func retourAvantConfirmation() {
        var s = Self.demarre()
        var b = Self.banc(Self.t0 + 60)
        b.retirer(Self.a2)
        #expect(s.integrer(b.annonces).isEmpty)
        #expect(s.instantane?.appareil(Self.a2)?.etat == .joignable, "en sursis : toujours la")
        #expect(s.integrer(Self.banc(Self.t0 + 120).annonces).isEmpty)
        #expect(s.integrer(Self.banc(Self.t0 + 300).annonces).isEmpty, "le sursis a ete leve")
    }

    @Test func sansAdresse() throws {
        var s = Self.demarre()
        var b = Self.banc(Self.t0 + 60)
        b.adresses[Self.a2 + ".local"] = []
        #expect(s.integrer(b.annonces).isEmpty)
        b.date = Self.t0 + 180
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.appareilSansAdresse])
        #expect(ev.first?.date == Self.t0 + 60)
        #expect(s.instantane?.appareil(Self.a2)?.etat == .sansAdresse)
        #expect(s.dernieresPartitions[Self.a2] == "7C6A2A68", "derniere partition connue gardee")
        #expect(s.integrer(Self.banc(Self.t0 + 240).annonces).map(\.type) == [.appareilRevenu])
    }

    @Test func routeurs() throws {
        var s = Self.demarre()
        // Nouvelle adresse de lien du chef (redemarrage probable), la route suit.
        var b = Self.banc(Self.t0 + 60)
        b.adresses["Chef.local"] = ["fe80::a"]
        b.routes = [RouteIPv6(prefixe: "fd2d:3b27:72b8::/64", passerelle: "fe80::a")]
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.routeurNouvelleAdresseLien])
        #expect(ev.first?.avant == "fe80::1")
        #expect(ev.first?.apres == "fe80::a")

        // Le second disparait : alerte, datee de la premiere absence.
        b.routeurs.removeAll { $0.instance == "Second" }
        b.date = Self.t0 + 120
        #expect(s.integrer(b.annonces).isEmpty)
        b.date = Self.t0 + 240
        let d = s.integrer(b.annonces)
        #expect(d.map(\.type) == [.routeurDisparu])
        #expect(d.first?.gravite == .alerte)
        #expect(d.first?.date == Self.t0 + 120)

        // Il revient.
        var c = Self.banc(Self.t0 + 300)
        c.adresses["Chef.local"] = ["fe80::a"]
        c.routes = b.routes
        #expect(s.integrer(c.annonces).map(\.type) == [.routeurApparu])
    }

    @Test func roleEtChef() {
        var s = Self.demarre()
        var b = Banc(date: Self.t0 + 60)
        b.routeur("Chef", role: .routeur, primaire: true, lien: "fe80::1")
        b.routeur("Second", role: .chef, lien: "fe80::2")
        b.route("fd2d:3b27:72b8::/64", via: "fe80::1")
        b.appareil(Self.a1, noeud: 1, adresses: ["fd2d:3b27:72b8::11"])
        b.appareil(Self.a2, noeud: 2, adresses: ["fd2d:3b27:72b8::12"], sii: 6000)
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.chefChange, .routeurRoleChange, .routeurRoleChange])
        #expect(ev.first?.avant == "Chef")
        #expect(ev.first?.apres == "Second")
    }

    @Test func scissionEtReunion() throws {
        var s = Self.demarre()
        var b = Banc(date: Self.t0 + 60)
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Second", partition: "E6A6AD72", role: .chef, primaire: true, lien: "fe80::2")
        b.route("fd2d:3b27:72b8::/64", via: "fe80::1")
        b.appareil(Self.a1, noeud: 1, adresses: ["fd2d:3b27:72b8::11"])
        b.appareil(Self.a2, noeud: 2, adresses: ["fd2d:3b27:72b8::12"], sii: 6000)
        let ev = s.integrer(b.annonces)
        let scission = try #require(ev.first)
        #expect(scission.type == .reseauScinde)
        #expect(scission.avant == "1")
        #expect(scission.apres == "2")
        #expect(!scission.constate)
        #expect(scission.details["E6A6AD72"] == "Second")
        #expect(s.integrer(Self.banc(Self.t0 + 120).annonces).map(\.type) == [.reseauReuni, .routeurRoleChange],
                "le chef de la partition isolee redevient simple routeur")
    }

    @Test func changementDePartitionEtPrefixes() throws {
        var s = Self.demarre()
        var b = Banc(date: Self.t0 + 60)
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Second", role: .routeur, lien: "fe80::2")
        b.routeur("Isole", partition: "E6A6AD72", role: nil, primaire: true, lien: "fe80::3",
                  omr: "fd0d:eec8:5ef:1::/64")
        b.route("fd2d:3b27:72b8::/64", via: "fe80::1")
        b.appareil(Self.a1, noeud: 1, adresses: ["fd2d:3b27:72b8::11"])
        b.appareil(Self.a2, noeud: 2, adresses: ["fd0d:eec8:5ef:1::12"], sii: 6000)
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.reseauScinde, .routeurApparu, .prefixeNouveau, .appareilChangePartition])
        let change = try #require(ev.last)
        #expect(change.avant == "7C6A2A68")
        #expect(change.apres == "E6A6AD72")
        #expect(change.details["coupee"] == "oui")
        #expect(change.gravite == .attention)
        #expect(ev[2].sujet?.id == "fd0d:eec8:5ef:1::/64")
    }

    @Test func veilleDuMac() throws {
        var s = Self.demarre()
        let veille = DateInterval(start: Self.t0 + 60, end: Self.t0 + 6 * 3600)
        let v = s.noterVeille(veille)
        #expect(v.map(\.type) == [.veille])
        #expect(v.first?.date == veille.end)
        #expect(v.first?.periode == veille)

        var b = Self.banc(veille.end + 10)
        b.retirer(Self.a2)
        #expect(s.integrer(b.annonces).isEmpty)
        b.date = veille.end + 130
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.appareilDisparu])
        #expect(ev.first?.periode == veille, "pendant la veille, pas au reveil")

        // Loin du reveil : datation normale.
        var c = Self.banc(veille.end + 600)
        c.retirer(Self.a1)
        c.retirer(Self.a2)
        _ = s.integrer(c.annonces)
        c.date = veille.end + 720
        let tard = s.integrer(c.annonces)
        #expect(tard.map(\.type) == [.appareilDisparu])
        #expect(tard.first?.periode == nil)
        #expect(tard.first?.date == veille.end + 600)
    }

    @Test func formatJSON() throws {
        let e = Evenement(date: Self.t0, type: .reseauScinde, reseau: "4B5D376D942B480E",
                          sujet: Sujet(id: "4B5D376D942B480E", nom: "MyHome1520326503"), avant: "1", apres: "2",
                          periode: DateInterval(start: Self.t0 - 60, end: Self.t0), constate: true,
                          details: ["E6A6AD72": "Aqara HubM100 #80E0"])
        let json = try CodageJSON.encodeur().encode(e)
        #expect(try CodageJSON.decodeur().decode(Evenement.self, from: json) == e)
        let ancien = Data(#"{"date":"2026-09-27T00:14:00Z","type":"appareilDisparu"}"#.utf8)
        let lu = try CodageJSON.decodeur().decode(Evenement.self, from: ancien)
        #expect(lu.gravite == .attention && !lu.constate && lu.details.isEmpty, "champs manquants : valeurs par defaut")
        #expect(e.id == "1790000000000-reseauScinde-4B5D376D942B480E")
    }
}
