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
        #expect(d.zones.map(\.id) == ["7C6A2A68", "E6A6AD72", ""])
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
        #expect(d.noeud("Aqara HubM100 #80E0")?.position == Point2D(330, 0))
        let dansPrincipale = d.noeuds.filter { $0.genre == .appareil && $0.zone == "7C6A2A68" }
        #expect(dansPrincipale.count == 22)
        #expect(dansPrincipale.allSatisfy { abs($0.position.distance(Point2D(0, 0)) - 170) < 1e-9 })
        #expect(d.noeuds.filter { $0.zone == "" }.map(\.id).sorted() == ["1EA39E8E72FC9ADA", "72FBDA00C4A43024"])
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
        let i = try #require(avecDisparu.firstIndex { $0.id == "561F9A6463953778" })
        avecDisparu[i].etat = .disparu
        #expect(Disposition(reseau: r, appareils: avecDisparu).noeud("561F9A6463953778") == d1.noeud("561F9A6463953778"))
    }

    @Test func triParPieceEtNom() throws {
        var b = Banc()
        b.routeur("Chef", role: .chef, lien: "fe80::1")
        let r = try #require(Instantane(annonces: b.annonces).reseaux.first)
        let apps = [
            AppareilAffiche(id: "3", nom: "Zeta", piece: nil, partition: "7C6A2A68", etat: .joignable),
            AppareilAffiche(id: "2", nom: "Beta", piece: "Salon", partition: "7C6A2A68", etat: .joignable),
            AppareilAffiche(id: "1", nom: "Alpha", piece: "Salon", partition: "7C6A2A68", etat: .joignable),
            AppareilAffiche(id: "4", nom: "Gamma", piece: "Bureau", partition: "7C6A2A68", etat: .joignable),
        ]
        let d = Disposition(reseau: r, appareils: apps)
        let ordre = d.noeuds.filter { $0.genre == .appareil }.map(\.id)
        #expect(ordre == ["4", "1", "2", "3"], "Bureau, puis Salon (Alpha, Beta), puis sans piece")
        #expect(d.zones.first?.rayon == 210)
    }

    /// Titre d'une zone : les prefixes de la partition, plus un prefixe partage
    /// qu'elle revendique sans l'avoir eu (capture de 12:28).
    @Test func prefixesPartagesDansLesTitres() throws {
        let i = Instantane(annonces: try Captures.annonces("capture-1228.json"))
        let d = Disposition(reseau: try #require(i.reseaux.first), appareils: Self.affiches(i))
        let fd2d = try #require(PrefixeIPv6("fd2d:3b27:72b8::/64"))
        try #require(d.zones.map(\.id) == ["7C6A2A68", "682A6A7C", ""])
        #expect(d.zones[0].prefixes == [fd2d])
        #expect(d.zones[0].prefixesPartages == [fd2d])
        #expect(d.zones[0].prefixesTitre == [fd2d])
        #expect(d.zones[1].prefixes.isEmpty)
        #expect(d.zones[1].prefixesPartages == [fd2d])
        #expect(d.zones[1].prefixesTitre == [fd2d], "revendique sans l'avoir eu")
        #expect(d.zones[2].prefixesTitre.isEmpty)
        // 02:15 : rien de partage, le titre garde les prefixes de la partition.
        let d0 = Disposition(reseau: try #require(Self.instantane.reseaux.first), appareils: Self.affiches(Self.instantane))
        #expect(d0.zones.allSatisfy { $0.prefixesPartages.isEmpty && $0.prefixesTitre == $0.prefixes })
        #expect(d0.zones.first?.prefixesTitre.map(\.description) == ["fd2d:3b27:72b8::/64"])
    }

    @Test func clic() throws {
        let r = try #require(Self.instantane.reseaux.first)
        let d = Disposition(reseau: r, appareils: Self.affiches(Self.instantane))
        #expect(d.noeud(a: Point2D(3, 4))?.id == "Apple TV 4K")
        #expect(d.noeud(a: Point2D(1000, 1000)) == nil)
        let halo = try #require(d.noeud("561F9A6463953778"))
        #expect(d.noeud(a: Point2D(halo.position.x + 5, halo.position.y))?.id == "561F9A6463953778")
    }
}
