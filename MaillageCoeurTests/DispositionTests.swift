import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Disposition du graphe")
struct DispositionTests {
    static let instantane = Instantane(annonces: Releve20260928.annonces)

    static func affiches(_ i: Instantane) -> [AppareilAffiche] {
        i.appareils.map {
            AppareilAffiche(id: $0.id, nom: $0.id, partition: $0.partition,
                            etat: $0.etat == .sansAdresse ? .sansAdresse : .joignable, endormi: $0.endormi)
        }
    }

    @Test func releveReel() throws {
        let r = try #require(Self.instantane.reseaux.first)
        let d = Disposition(reseau: r, appareils: Self.affiches(Self.instantane))
        #expect(d.zones.map(\.id) == ["73586B68", "E2E79FFC", ""])
        let principale = d.zones[0]
        #expect(principale.centre == Point2D(0, 0))
        #expect(principale.rayon == 210, "22 appareils : anneau de 170, plus la marge")
        #expect(principale.principale)
        #expect(d.zones[1].centre == Point2D(330, 0), "210 + 60 + 60, centree a la hauteur de la principale")
        #expect(d.zones[1].rayon == 60)
        #expect(d.zones[2].centre == Point2D(0, 370), "sous la principale : 210 + 60 + 100")

        let atv = try #require(d.noeud("Apple TV 4K"))
        #expect(atv.genre == .centre)
        #expect(atv.position == Point2D(0, 0))
        let homepods = d.noeuds.filter { $0.genre == .routeur }
        #expect(homepods.count == 4)
        #expect(homepods.allSatisfy { abs($0.position.distance(Point2D(0, 0)) - 90) < 1e-9 })
        #expect(abs(homepods[0].position.x) < 1e-9 && abs(homepods[0].position.y + 90) < 1e-9, "le premier en haut")
        #expect(d.noeud("Aqara HubM100 #DFEB")?.position == Point2D(330, 0))
        let dansPrincipale = d.noeuds.filter { $0.genre == .appareil && $0.zone == "73586B68" }
        #expect(dansPrincipale.count == 22)
        #expect(dansPrincipale.allSatisfy { abs($0.position.distance(Point2D(0, 0)) - 170) < 1e-9 })
        #expect(d.noeuds.filter { $0.zone == "" }.map(\.id).sorted() == ["1E5019DAC2638F92", "724CC16B32D8F820"])
        #expect(d.liens.count == 26, "4 routeurs et 22 appareils vers l'Apple TV")
        #expect(d.liens.allSatisfy { $0.vers == "Apple TV 4K" })
        #expect(d.cadre.min == Point2D(-210, -210))
        #expect(d.cadre.max == Point2D(390, 470))
    }

    @Test func stable() throws {
        let r = try #require(Self.instantane.reseaux.first)
        let apps = Self.affiches(Self.instantane)
        let d1 = Disposition(reseau: r, appareils: apps)
        #expect(Disposition(reseau: r, appareils: apps.reversed()) == d1, "l'ordre d'arrivee ne compte pas")
        // Un appareil disparu reste a sa place.
        var avecDisparu = apps
        let i = try #require(avecDisparu.firstIndex { $0.id == "56B1E064401F74EF" })
        avecDisparu[i].etat = .disparu
        #expect(Disposition(reseau: r, appareils: avecDisparu).noeud("56B1E064401F74EF") == d1.noeud("56B1E064401F74EF"))
    }

    @Test func triParPieceEtNom() throws {
        var b = Banc()
        b.routeur("Chef", role: .chef, lien: "fe80::1")
        let r = try #require(Instantane(annonces: b.annonces).reseaux.first)
        let apps = [
            AppareilAffiche(id: "3", nom: "Zeta", piece: nil, partition: "73586B68", etat: .joignable),
            AppareilAffiche(id: "2", nom: "Beta", piece: "Salon", partition: "73586B68", etat: .joignable),
            AppareilAffiche(id: "1", nom: "Alpha", piece: "Salon", partition: "73586B68", etat: .joignable),
            AppareilAffiche(id: "4", nom: "Gamma", piece: "Bureau", partition: "73586B68", etat: .joignable),
        ]
        let d = Disposition(reseau: r, appareils: apps)
        let ordre = d.noeuds.filter { $0.genre == .appareil }.map(\.id)
        #expect(ordre == ["4", "1", "2", "3"], "Bureau, puis Salon (Alpha, Beta), puis sans piece")
        #expect(d.zones.first?.rayon == 210)
    }

    @Test func clic() throws {
        let r = try #require(Self.instantane.reseaux.first)
        let d = Disposition(reseau: r, appareils: Self.affiches(Self.instantane))
        #expect(d.noeud(a: Point2D(3, 4))?.id == "Apple TV 4K")
        #expect(d.noeud(a: Point2D(1000, 1000)) == nil)
        let halo = try #require(d.noeud("56B1E064401F74EF"))
        #expect(d.noeud(a: Point2D(halo.position.x + 5, halo.position.y))?.id == "56B1E064401F74EF")
    }
}
