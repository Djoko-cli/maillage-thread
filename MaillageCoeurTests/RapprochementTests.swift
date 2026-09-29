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
        // Le tri range par angle du parent, non par nom : E...0A (enfant de "HomePod bureau", premier de l'anneau
        // interieur) passe avant E...04 (enfant de E...02), alors que l'ordre alphabetique dirait l'inverse.
        let iA = try #require(exterieur.firstIndex(of: "E00000000000000A"))
        #expect(iA < i4)
        // "Absent", que la sonde ne voit pas (aucun parent), est rejete en fin d'anneau.
        #expect(exterieur.last == "Absent")
    }

    /// Mini-maillage a la main, pour les branches du rangement des enfants que la capture n'atteint pas.
    /// Partition 46CBEBCD, centre "Centre" (routeur 1, RLOC16 0400, reconnu par son `xa`). Routeurs 2 a 6
    /// inconnus (0800 a 1800) : l'anneau interieur, en partant du haut dans le sens horaire, 0800 a -90 degres,
    /// 0C00 a -18, 1000 a 54, 1400 a 126, 1800 a 198 (dernier quart : `atan2` y rend -162). Routeur 7 (1C00)
    /// reconnu comme l'appareil E...0F, que la disposition n'affiche pas : sans place sur les anneaux.
    /// Un enfant par RLOC16 donne, sous le routeur `rloc16 >> 10` (0001 : le routeur 0, absent du maillage).
    /// Rend l'anneau exterieur, dans l'ordre de ses noeuds.
    static func exterieur(enfants: [UInt16]) throws -> [String] {
        var b = Banc()
        b.routeur("Centre", partition: "46CBEBCD", role: .chef, lien: "fe80::1", xa: "E0000000000000C1")
        b.appareil("E00000000000000F", noeud: 1, adresses: ["fd00:5555:6666:0:b00::f"])
        let i = Instantane(annonces: b.annonces)
        let r = try #require(i.reseaux.first)
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.routeurs(Route64(sequence: 0, routes: (1...7).map {
            RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1)
        }), chef: 1)
        c.identite("E0000000000000C1", routeur: 1)
        c.identite("E00000000000000F", routeur: 7)
        for rloc in enfants { c.enfant(EnfantMaillage(rloc16: rloc, source: .balayage)) }
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        let d = Disposition(reseau: r, appareils: [], maillage: m)
        #expect(m.routeurs[1]?.id == "Centre" && m.routeurs[7]?.id == "E00000000000000F")
        #expect(d.noeud("Centre")?.genre == .centre)
        #expect(d.noeuds.filter { $0.genre == .routeur }.map(\.id) == ["rloc:0800", "rloc:0C00", "rloc:1000", "rloc:1400", "rloc:1800"])
        return d.noeuds.filter { $0.genre == .appareil }.map(\.id)
    }

    /// Les enfants du centre (angle 3 pi / 2) passent apres ceux de tous les routeurs de l'anneau, dernier quart
    /// compris, et ne se melent pas a ceux du premier routeur (0800, en haut).
    @Test func enfantsDuCentreEnFinDAnneau() throws {
        let ordre = try Self.exterieur(enfants: [0x0401, 0x0801, 0x1401, 0x1801])
        #expect(ordre == ["rloc:0801", "rloc:1401", "rloc:1801", "rloc:0401"])
    }

    /// Parent du dernier quart de l'anneau (1800, a 198 degres) : le repli t + 2 pi ramene l'angle negatif de
    /// `atan2` (-162) a 198, donc apres les enfants de 1400 (126), et non avant ceux de 0C00 (-18).
    @Test func repliDeLAngleAuDernierQuartDeLAnneau() throws {
        let ordre = try Self.exterieur(enfants: [0x0C01, 0x1401, 0x1801])
        #expect(ordre == ["rloc:0C01", "rloc:1401", "rloc:1801"])
    }

    /// Enfant sans parent dans le maillage (0001 : le routeur 0 n'y est pas) : rejete en fin d'anneau.
    @Test func enfantSansParentEnFinDAnneau() throws {
        let ordre = try Self.exterieur(enfants: [0x0001, 0x0C01, 0x1401])
        #expect(ordre == ["rloc:0C01", "rloc:1401", "rloc:0001"])
    }

    /// Enfant dont le parent est connu mais sans place sur les anneaux (1C01 : le routeur 7, l'appareil E...0F
    /// que la disposition n'affiche pas) : rejete en fin d'anneau, comme celui qui n'a pas de parent.
    @Test func enfantDUnParentSansPlaceEnFinDAnneau() throws {
        let ordre = try Self.exterieur(enfants: [0x1C01, 0x0C01, 0x1401])
        #expect(ordre == ["rloc:0C01", "rloc:1401", "rloc:1C01"])
    }
}
