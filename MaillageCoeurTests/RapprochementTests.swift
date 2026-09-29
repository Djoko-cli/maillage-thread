import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Rapprochement du maillage et disposition avec la sonde")
struct RapprochementTests {
    static let omr = "fd00:5555:6666::/64"

    /// Partition 46CBEBCD : l'Apple TV (BBR principal), le HomePod du bureau (parent
    /// de la sonde, `xa` connu), un HomePod que la sonde ne reconnait pas ; les
    /// appareils de la capture par leur ExtMac, un appareil HomeKit reconnu par son
    /// adresse OMR, un appareil que la sonde ne voit pas.
    static func instantane() -> Instantane {
        var b = Banc()
        b.routeur("Apple TV", partition: "46CBEBCD", primaire: true, lien: "fe80::1", omr: omr, xa: "E0000000000000A1")
        b.routeur("HomePod bureau", partition: "46CBEBCD", lien: "fe80::2", omr: omr, xa: "E000000000000007")
        b.routeur("HomePod salon", partition: "46CBEBCD", lien: "fe80::3", omr: omr, xa: "E0000000000000A2")
        for (i, ext) in ["E000000000000002", "E000000000000003", "E000000000000004", "E000000000000005",
                         "E000000000000009", "E00000000000000A"].enumerated() {
            b.appareil(ext, noeud: i + 1, adresses: ["fd00:5555:6666:0:b00::\(i + 1)"])
        }
        b.appareil("Eve-HAP", noeud: 20, adresses: ["fd00:5555:6666:0:a00::9"])
        b.appareil("Absent", noeud: 21, adresses: ["fd00:5555:6666:0:b00::99"])
        return Instantane(annonces: b.annonces)
    }

    static func maillage() async throws -> Maillage {
        let sonde = try SondeRejouee.capture()
        return try #require(try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: .now)).maillage
    }

    static func affiches(_ i: Instantane) -> [AppareilAffiche] {
        i.appareils.map { AppareilAffiche(id: $0.id, nom: $0.id, partition: $0.partition, etat: .joignable) }
    }

    /// Routeurs : par `xa`, BBR principal, appareil qui route, inconnu ; enfants : par
    /// ExtMac, par adresse, inconnus ; liens radio et enfant-parent.
    @Test func rapprochement() async throws {
        let i = Self.instantane()
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await Self.maillage(), reseau: r, appareils: i.appareils)
        #expect(m.routeurs[43]?.id == "HomePod bureau", "par son xa")
        #expect(m.routeurs[45]?.id == "Apple TV", "BBR principal")
        #expect(m.routeurs[20]?.id == "E000000000000002", "appareil qui route")
        #expect(m.routeurs[24]?.id == "E000000000000003")
        #expect(m.routeurs[1] == NoeudSonde(id: "rloc:0400", rloc16: 0x0400, genre: .routeur, reconnu: false, bordure: true))
        #expect(m.enfants[0x5004]?.id == "E000000000000004")
        #expect(m.enfants[0x6003]?.id == "Eve-HAP", "par son adresse OMR")
        #expect(m.enfants[0x6002]?.id == "rloc:6002")
        #expect(m.enfants[0xAC09]?.id == "rloc:AC09", "la sonde, sans ExtMac (firmware d'essai)")
        #expect(m.inconnus.filter { $0.genre == .routeur }.map(\.id) == ["rloc:0400", "rloc:CC00", "rloc:E400"])
        #expect(m.inconnus.count == 12)
        #expect(m.liens.contains(LienAffiche(de: "E000000000000002", vers: "E000000000000003", genre: .radio, qualite: 3)))
        #expect(m.liens.contains(LienAffiche(de: "E000000000000004", vers: "E000000000000002", genre: .parent, qualite: 2)))
        #expect(m.liens.contains(LienAffiche(de: "E00000000000000A", vers: "HomePod bureau", genre: .parent, qualite: nil)))
        #expect(m.parent(de: "E000000000000005") == "E000000000000002")
        #expect(m.noeud("Apple TV")?.rloc16 == 0xB400)
    }

    /// Anneau interieur : routeurs de bordure hors centre, appareils qui routent,
    /// routeurs inconnus ; enfants pres de leur parent ; liens de la sonde, et le
    /// rattachement pour les noeuds qu'elle ne relie pas.
    @Test func disposition() async throws {
        let i = Self.instantane()
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await Self.maillage(), reseau: r, appareils: i.appareils)
        let d = Disposition(reseau: r, appareils: Self.affiches(i), maillage: m)
        #expect(d.noeud("Apple TV")?.genre == .centre)
        let interieur = d.noeuds.filter { abs($0.position.distance(Point2D(0, 0)) - Disposition.rayonInterieur) < 0.001 }
        #expect(interieur.map(\.id) == ["HomePod bureau", "HomePod salon", "E000000000000002", "E000000000000003",
                                        "rloc:0400", "rloc:CC00", "rloc:E400"])
        #expect(d.noeud("E000000000000002")?.genre == .appareil)
        #expect(d.noeud("E000000000000002")?.rayon == 9)
        #expect(d.noeud("rloc:0400")?.genre == .routeur)
        #expect(d.noeud("rloc:6002")?.genre == .appareil, "enfant inconnu : sur l'anneau exterieur")
        #expect(d.liens.filter { $0.genre == .radio }.count == 7)
        #expect(d.liens.contains(Disposition.Lien(de: "E000000000000004", vers: "E000000000000002", genre: .parent, qualite: 2)))
        #expect(d.liens.contains(Disposition.Lien(de: "HomePod salon", vers: "Apple TV")), "sans lien connu : rattachement")
        #expect(d.liens.contains(Disposition.Lien(de: "Absent", vers: "Apple TV")))
        #expect(!d.liens.contains { $0.de == "E000000000000004" && $0.genre == .rattachement })
        // Les deux enfants de 5000 (E...04 et E...05) cote a cote sur l'anneau exterieur.
        let exterieur = d.noeuds.filter { $0.genre == .appareil && !interieur.contains($0) }.map(\.id)
        let i4 = try #require(exterieur.firstIndex(of: "E000000000000004"))
        let i5 = try #require(exterieur.firstIndex(of: "E000000000000005"))
        #expect(abs(i4 - i5) == 1)
    }
}
