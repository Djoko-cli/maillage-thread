import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Rapprochement du maillage et disposition avec la sonde")
struct RapprochementTests {
    static let omr = "fd00:5555:6666::/64"

    /// Partition 46CBEBCD : l'Apple TV (BBR principal), le HomePod du bureau (parent
    /// de la sonde, `xa` connu), un HomePod que la sonde ne reconnait pas ; les
    /// appareils de la capture par leur ExtMac, un appareil HomeKit reconnu par son
    /// adresse OMR, un appareil que la sonde ne voit pas. `autres` : les routeurs de
    /// bordure apres l'Apple TV (nom, `xa` invente) ; `ailleurs` : ceux d'une autre partition
    /// du meme reseau, 73586B68.
    static func instantane(autres: [(nom: String, xa: String?)] = [("HomePod bureau", "E000000000000007"),
                                                                    ("HomePod salon", "E0000000000000A2")],
                           ailleurs: [(nom: String, xa: String?)] = []) -> Instantane {
        var b = Banc()
        b.routeur("Apple TV", partition: "46CBEBCD", primaire: true, lien: "fe80::1", omr: omr, xa: "E0000000000000A1")
        for (i, r) in autres.enumerated() {
            b.routeur(r.nom, partition: "46CBEBCD", lien: "fe80::\(i + 2)", omr: omr, xa: r.xa)
        }
        for (i, r) in ailleurs.enumerated() {
            b.routeur(r.nom, partition: "73586B68", lien: "fe80::\(i + 20)", xa: r.xa)
        }
        for (i, ext) in ["E000000000000002", "E000000000000003", "E000000000000004", "E000000000000005",
                         "E000000000000009", "E00000000000000A"].enumerated() {
            b.appareil(ext, noeud: i + 1, adresses: ["fd00:5555:6666:0:b00::\(i + 1)"])
        }
        b.appareil("Eve-HAP", noeud: 20, adresses: ["fd00:5555:6666:0:a00::9"])
        b.appareil("Absent", noeud: 21, adresses: ["fd00:5555:6666:0:b00::99"])
        return Instantane(annonces: b.annonces)
    }

    /// Maillage de la capture ; `entendus` : les routeurs que la sonde entend (RLOC16 -> ExtMac).
    static func maillage(entendus: [UInt16: String] = [:]) async throws -> Maillage {
        let sonde = try SondeRejouee.capture(table: SondeRejouee.table(entendus: entendus))
        return try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: .now)).maillage
    }

    /// Anneau interieur de la zone principale, dans l'ordre.
    static func interieur(_ d: Disposition) -> [String] {
        d.noeuds.filter { abs($0.position.distance(Point2D(0, 0)) - Disposition.rayonInterieur) < 0.001 }.map(\.id)
    }

    static func affiches(_ i: Instantane) -> [AppareilAffiche] {
        i.appareils.map { AppareilAffiche(id: $0.id, nom: $0.id, partition: $0.partition, etat: .joignable) }
    }

    /// Routeurs : par `xa`, BBR principal, appareil qui route, inconnu ; enfants : par
    /// ExtMac, par adresse, inconnus ; liens radio et enfant-parent. Trois routeurs de bordure
    /// non identifies pour une seule annonce non reprise, le HomePod du salon : chacun l'a pour
    /// seul candidat (sans elimination possible).
    @Test func rapprochement() async throws {
        let i = Self.instantane()
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await Self.maillage(), reseau: r, appareils: i.appareils)
        #expect(m.routeurs[43]?.id == "HomePod bureau", "par son xa")
        #expect(m.routeurs[45]?.id == "Apple TV", "BBR principal")
        #expect(m.routeurs[20]?.id == "E000000000000002", "appareil qui route")
        #expect(m.routeurs[24]?.id == "E000000000000003")
        #expect(m.routeurs[1] == NoeudSonde(id: "rloc:0400", rloc16: 0x0400, genre: .routeur, reconnu: false, bordure: true,
                                            candidats: ["HomePod salon"]))
        #expect(m.routeurs[51]?.candidats == ["HomePod salon"] && m.routeurs[57]?.candidats == ["HomePod salon"])
        #expect(m.routeurs[20]?.candidats == [], "pas un routeur de bordure")
        #expect(m.annoncesCandidates == ["HomePod salon"])
        #expect(m.routeurs.values.allSatisfy { !$0.deduit })
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
    /// rattachement pour les noeuds qu'elle ne relie pas. L'annonce du HomePod du salon,
    /// candidate des routeurs de bordure non identifies, n'est pas dessinee a part.
    @Test func disposition() async throws {
        let i = Self.instantane()
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await Self.maillage(), reseau: r, appareils: i.appareils)
        let d = Disposition(reseau: r, appareils: Self.affiches(i), maillage: m)
        #expect(d.noeud("Apple TV")?.genre == .centre)
        let interieur = Self.interieur(d)
        #expect(interieur == ["HomePod bureau", "E000000000000002", "E000000000000003", "rloc:0400", "rloc:CC00", "rloc:E400"])
        #expect(d.noeud("HomePod salon") == nil, "candidate : portee par les routeurs non identifies")
        #expect(d.noeud("E000000000000002")?.genre == .appareil)
        #expect(d.noeud("E000000000000002")?.rayon == 9)
        #expect(d.noeud("rloc:0400")?.genre == .routeur)
        #expect(d.noeud("rloc:6002")?.genre == .appareil, "enfant inconnu : sur l'anneau exterieur")
        #expect(d.liens.filter { $0.genre == .radio }.count == 7)
        #expect(d.liens.contains(Disposition.Lien(de: "E000000000000004", vers: "E000000000000002", genre: .parent, qualite: 2)))
        #expect(d.liens.contains(Disposition.Lien(de: "rloc:E400", vers: "Apple TV")), "sans lien connu : rattachement")
        #expect(d.liens.contains(Disposition.Lien(de: "Absent", vers: "Apple TV")))
        #expect(!d.liens.contains { $0.de == "E000000000000004" && $0.genre == .rattachement })
        // Les deux enfants de 5000 (E...04 et E...05) cote a cote sur l'anneau exterieur.
        let exterieur = d.noeuds.filter { $0.genre == .appareil && !interieur.contains($0.id) }.map(\.id)
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

    /// Elimination : la sonde entend CC00 et E400 (leur `xa`), son parent AC00 et le BBR principal
    /// B400 sont connus ; reste un seul routeur de bordure non identifie (0400) et une seule
    /// annonce non reprise (le HomePod palier) : c'est lui. Un seul noeud pour ce routeur.
    @Test func elimination() async throws {
        let i = Self.instantane(autres: [("HomePod bureau", "E000000000000007"), ("HomePod chambre", "E0000000000000E4"),
                                         ("HomePod palier", "E0000000000000D2"), ("HomePod salon", "E0000000000000CC")])
        let r = try #require(i.reseaux.first)
        let maillage = try await Self.maillage(entendus: [0xE400: "E0000000000000E4", 0xCC00: "E0000000000000CC"])
        let m = MaillageAffiche(maillage: maillage, reseau: r, appareils: i.appareils)
        #expect(m.routeurs[57]?.id == "HomePod chambre" && m.routeurs[51]?.id == "HomePod salon", "entendus : par leur xa")
        #expect(m.routeurs[1] == NoeudSonde(id: "HomePod palier", rloc16: 0x0400, genre: .routeur, reconnu: true, bordure: true,
                                            deduit: true))
        #expect(m.routeurs.values.filter(\.deduit).count == 1)
        #expect(m.annoncesCandidates.isEmpty)
        #expect(m.inconnus.filter { $0.genre == .routeur }.isEmpty)
        let d = Disposition(reseau: r, appareils: Self.affiches(i), maillage: m)
        #expect(Self.interieur(d) == ["HomePod bureau", "HomePod chambre", "HomePod palier", "HomePod salon",
                                      "E000000000000002", "E000000000000003"])
    }

    /// Deux routeurs de bordure non identifies (0400, CC00), deux annonces non reprises : pas
    /// d'elimination ; chacun a les deux pour candidates, qui ne sont plus dessinees a part.
    /// Un seul noeud par routeur : le centre et six sur l'anneau interieur, pour 7 routeurs.
    @Test func candidats() async throws {
        let i = Self.instantane(autres: [("HomePod bureau", "E000000000000007"), ("HomePod chambre", "E0000000000000E4"),
                                         ("HomePod avant", "E0000000000000D1"), ("HomePod palier", "E0000000000000D2")])
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await Self.maillage(entendus: [0xE400: "E0000000000000E4"]), reseau: r,
                                appareils: i.appareils)
        for id in [1, 51] {
            #expect(m.routeurs[id]?.reconnu == false && m.routeurs[id]?.deduit == false)
            #expect(m.routeurs[id]?.candidats == ["HomePod avant", "HomePod palier"])
        }
        #expect(m.annoncesCandidates == ["HomePod avant", "HomePod palier"])
        let d = Disposition(reseau: r, appareils: Self.affiches(i), maillage: m)
        #expect(Self.interieur(d) == ["HomePod bureau", "HomePod chambre", "E000000000000002", "E000000000000003",
                                      "rloc:0400", "rloc:CC00"])
        #expect(d.noeud("HomePod avant") == nil && d.noeud("HomePod palier") == nil)
        // Sans sonde, rien ne change : les annonces sont dessinees.
        let sans = Disposition(reseau: r, appareils: Self.affiches(i))
        #expect(Self.interieur(sans) == ["HomePod bureau", "HomePod chambre", "HomePod avant", "HomePod palier"])
    }

    /// Reseau scinde : les candidats ne viennent que de la partition de la sonde, et seules ses
    /// annonces candidates ne sont pas dessinees ; l'autre partition garde toutes les siennes, meme
    /// non reprises (ExtMac inventees).
    @Test func autrePartitionAvecCandidats() async throws {
        let i = Self.instantane(ailleurs: [("Aqara", "E0000000000000AA"), ("HomePod isole", "E0000000000000A9")])
        let r = try #require(i.reseaux.first)
        #expect(r.partitions.map(\.id) == ["46CBEBCD", "73586B68"])
        let m = MaillageAffiche(maillage: try await Self.maillage(), reseau: r, appareils: i.appareils)
        #expect(m.annoncesCandidates == ["HomePod salon"])
        #expect(m.routeurs[1]?.candidats == ["HomePod salon"])
        let d = Disposition(reseau: r, appareils: Self.affiches(i), maillage: m)
        #expect(d.noeud("HomePod salon") == nil)
        #expect(d.noeud("Aqara")?.zone == "73586B68" && d.noeud("HomePod isole")?.zone == "73586B68")
    }

    /// Network Data en echec a la seconde tournee : les routeurs de bordure restent connus (les
    /// dernieres lues), donc leurs candidats et le BBR principal aussi : l'affichage ne clignote pas.
    @Test func candidatsSansNetworkData() async throws {
        let i = Self.instantane()
        let r = try #require(i.reseaux.first)
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: .now))
        let (m2, _) = try #require(try await Tournee.complete(sonde.filtree { $0 != "5000|7" }, memoire: mem1,
                                                              maintenant: .now))
        let m = MaillageAffiche(maillage: m2, reseau: r, appareils: i.appareils)
        #expect(m.routeurs[1]?.candidats == ["HomePod salon"])
        #expect(m.routeurs[45]?.id == "Apple TV", "BBR principal")
        #expect(m.annoncesCandidates == ["HomePod salon"])
    }

    /// ExtMac connue d'un routeur de bordure qu'aucune annonce ne porte (0400, entendu) : une
    /// annonce qui a un autre `xa` n'est pas sa candidate, ni par elimination ; une annonce sans
    /// `xa` peut l'etre. Une annonce candidate de personne reste dessinee.
    @Test func candidatsSelonLExtMac() async throws {
        let entendus: [UInt16: String] = [0xE400: "E0000000000000E4", 0xCC00: "E0000000000000CC", 0x0400: "E0000000000000F0"]
        let avecXa = Self.instantane(autres: [("HomePod bureau", "E000000000000007"), ("HomePod chambre", "E0000000000000E4"),
                                              ("HomePod avant", "E0000000000000D1"), ("HomePod salon", "E0000000000000CC")])
        let r = try #require(avecXa.reseaux.first)
        let m = MaillageAffiche(maillage: try await Self.maillage(entendus: entendus), reseau: r, appareils: avecXa.appareils)
        #expect(m.routeurs[1] == NoeudSonde(id: "rloc:0400", rloc16: 0x0400, genre: .routeur, reconnu: false, bordure: true))
        #expect(m.annoncesCandidates.isEmpty)
        #expect(Disposition(reseau: r, appareils: Self.affiches(avecXa), maillage: m).noeud("HomePod avant") != nil)

        let sansXa = Self.instantane(autres: [("HomePod bureau", "E000000000000007"), ("HomePod chambre", "E0000000000000E4"),
                                              ("HomePod avant", nil), ("HomePod salon", "E0000000000000CC")])
        let r2 = try #require(sansXa.reseaux.first)
        let m2 = MaillageAffiche(maillage: try await Self.maillage(entendus: entendus), reseau: r2, appareils: sansXa.appareils)
        #expect(m2.routeurs[1]?.id == "HomePod avant" && m2.routeurs[1]?.deduit == true, "sans xa : possible, et seule")
    }

    /// Sans Network Data (aucun routeur qui reponde), aucun routeur n'est connu pour etre de
    /// bordure : ni candidats ni elimination, les annonces restent dessinees.
    @Test func sansRouteurDeBordureConnu() throws {
        var b = Banc()
        b.routeur("Centre", partition: "46CBEBCD", role: .chef, lien: "fe80::1", xa: "E0000000000000C1")
        b.routeur("HomePod avant", partition: "46CBEBCD", lien: "fe80::2", xa: "E0000000000000D1")
        let i = Instantane(annonces: b.annonces)
        let r = try #require(i.reseaux.first)
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.routeurs(Route64(sequence: 0, routes: (1...2).map { RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1) }),
                   chef: 1)
        c.identite("E0000000000000C1", routeur: 1)
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        #expect(m.routeurs[2] == NoeudSonde(id: "rloc:0800", rloc16: 0x0800, genre: .routeur, reconnu: false, bordure: false))
        #expect(m.annoncesCandidates.isEmpty)
        #expect(Disposition(reseau: r, appareils: [], maillage: m).noeud("HomePod avant") != nil)
    }

    /// Mini-maillage de deux routeurs de bordure sans ExtMac (0400, le chef, et 0800) ;
    /// `ext` : ExtMac connue du chef ; `chefBordure` : le chef est-il un routeur de bordure.
    static func deuxRouteurs(_ i: Instantane, ext: String? = nil, chefBordure: Bool = true) throws -> MaillageAffiche {
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.routeurs(Route64(sequence: 0, routes: (1...2).map { RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1) }),
                   chef: 1)
        if let ext { c.identite(ext, routeur: 1) }
        c.marquer(1, bordure: chefBordure)
        c.marquer(2, bordure: true)
        return MaillageAffiche(maillage: c.maillage(), reseau: try #require(i.reseaux.first), appareils: i.appareils)
    }

    /// Regle du chef, comme celle du BBR principal : le chef du maillage, routeur de bordure non
    /// identifie, est l'annonce de role chef de sa partition (Thread 1.4, bits 9-10 de `sb`) ; le
    /// dernier routeur l'est alors par elimination. Pas si l'ExtMac du chef, connue, n'est pas le
    /// `xa` de l'annonce, ni si le chef n'est pas un routeur de bordure.
    @Test func regleDuChef() throws {
        var b = Banc()
        b.routeur("Centre", partition: "46CBEBCD", role: .chef, lien: "fe80::1", xa: "E0000000000000C1")
        b.routeur("HomePod avant", partition: "46CBEBCD", lien: "fe80::2", xa: "E0000000000000D1")
        let i = Instantane(annonces: b.annonces)
        let m = try Self.deuxRouteurs(i)
        #expect(m.routeurs[1] == NoeudSonde(id: "Centre", rloc16: 0x0400, genre: .routeur, reconnu: true, bordure: true))
        #expect(m.routeurs[2]?.id == "HomePod avant" && m.routeurs[2]?.deduit == true)
        #expect(m.annoncesCandidates.isEmpty)
        #expect(try Self.deuxRouteurs(i, ext: "E0000000000000F0").routeurs[1]?.reconnu == false, "ExtMac et xa differents")
        #expect(try Self.deuxRouteurs(i, chefBordure: false).routeurs[1]?.reconnu == false, "chef hors des routeurs de bordure")
    }

    /// Deux annonces de role chef dans la partition (une perimee que le cache garde avec le meme
    /// `pt`) : la regle du chef ne choisit pas, ni l'elimination apres elle ; les deux routeurs
    /// restent « rloc: » avec les deux annonces pour candidates.
    @Test func regleDuChefSansDoublon() throws {
        var b = Banc()
        b.routeur("Alpha perime", partition: "46CBEBCD", role: .chef, lien: "fe80::1", xa: "E0000000000000C1")
        b.routeur("Zeta reel", partition: "46CBEBCD", role: .chef, lien: "fe80::2", xa: "E0000000000000C2")
        let m = try Self.deuxRouteurs(Instantane(annonces: b.annonces))
        for id in [1, 2] {
            #expect(m.routeurs[id]?.reconnu == false && m.routeurs[id]?.deduit == false)
            #expect(Set(m.routeurs[id]?.candidats ?? []) == ["Alpha perime", "Zeta reel"])
        }
        #expect(m.routeurs[1]?.id == "rloc:0400" && m.routeurs[2]?.id == "rloc:0800")
    }

    /// Reseau scinde : l'annonce de role chef de l'autre partition n'est pas le chef du maillage de
    /// la sonde (pas de fusion) ; il reste non identifie, et elle n'est la candidate de personne.
    @Test func regleDuChefEnReseauScinde() throws {
        var b = Banc()
        b.routeur("HomePod avant", partition: "46CBEBCD", lien: "fe80::1", xa: "E0000000000000D1")
        b.routeur("Chef ailleurs", partition: "73586B68", role: .chef, lien: "fe80::2", xa: "E0000000000000C1")
        let i = Instantane(annonces: b.annonces)
        #expect(i.reseaux.first?.partitions.count == 2)
        let m = try Self.deuxRouteurs(i)
        #expect(m.routeurs[1]?.id == "rloc:0400" && m.routeurs[1]?.candidats == ["HomePod avant"])
        #expect(!m.annoncesCandidates.contains("Chef ailleurs"))
        #expect(m.routeurs.values.allSatisfy { $0.id != "Chef ailleurs" })
    }

    /// Regle du BBR principal, gardee comme les autres : pas si l'ExtMac du BBR principal (connue,
    /// ici entendue) et le `xa` de l'annonce BBR primaire sont connus tous deux et differents ; pas
    /// non plus si deux annonces de la partition se disent BBR primaire (ExtMac inventees).
    @Test func regleDuBBRPrincipal() async throws {
        let i = Self.instantane()
        let r = try #require(i.reseaux.first)
        let entendu = MaillageAffiche(maillage: try await Self.maillage(entendus: [0xB400: "E0000000000000F0"]), reseau: r,
                                      appareils: i.appareils)
        #expect(entendu.routeurs[45] == NoeudSonde(id: "rloc:B400", rloc16: 0xB400, genre: .routeur, reconnu: false,
                                                   bordure: true))

        var b = Banc()
        b.routeur("Apple TV", partition: "46CBEBCD", primaire: true, lien: "fe80::1", omr: Self.omr, xa: "E0000000000000A1")
        b.routeur("Apple TV ancienne", partition: "46CBEBCD", primaire: true, lien: "fe80::2", omr: Self.omr,
                  xa: "E0000000000000A3")
        b.routeur("HomePod bureau", partition: "46CBEBCD", lien: "fe80::3", omr: Self.omr, xa: "E000000000000007")
        let deux = Instantane(annonces: b.annonces)
        let m = MaillageAffiche(maillage: try await Self.maillage(), reseau: try #require(deux.reseaux.first),
                                appareils: deux.appareils)
        #expect(m.routeurs[45]?.reconnu == false)
        #expect(Set(m.routeurs[45]?.candidats ?? []) == ["Apple TV", "Apple TV ancienne"])
    }

    /// Annonce en double (meme `xa` que celle d'un routeur reconnu, gardee par un cache perime) :
    /// c'est ce routeur, pas un autre ; elle n'est la candidate d'aucun routeur non identifie.
    @Test func annonceEnDouble() async throws {
        let i = Self.instantane(autres: [("HomePod bureau", "E000000000000007"), ("HomePod bureau (2)", "E000000000000007"),
                                         ("HomePod salon", "E0000000000000A2")])
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await Self.maillage(), reseau: r, appareils: i.appareils)
        #expect(m.routeurs[43]?.id == "HomePod bureau")
        #expect(m.routeurs[1]?.candidats == ["HomePod salon"])
        #expect(!m.annoncesCandidates.contains("HomePod bureau (2)"))
    }

    /// Le centre de la zone peut etre candidat (ici le premier par nom : annonces Thread 1.3, sans
    /// role) ; il reste dessine, au centre. L'autre annonce candidate, non.
    @Test func centreCandidat() throws {
        var b = Banc()
        b.routeur("Alpha", partition: "46CBEBCD", role: nil, lien: "fe80::1", xa: "E0000000000000C1")
        b.routeur("HomePod avant", partition: "46CBEBCD", role: nil, lien: "fe80::2", xa: "E0000000000000D1")
        let i = Instantane(annonces: b.annonces)
        let r = try #require(i.reseaux.first)
        let m = try Self.deuxRouteurs(i)
        #expect(m.routeurs[1]?.candidats == ["Alpha", "HomePod avant"] && m.routeurs[2]?.candidats == ["Alpha", "HomePod avant"])
        let d = Disposition(reseau: r, appareils: [], maillage: m)
        #expect(d.noeud("Alpha")?.genre == .centre)
        #expect(d.noeud("HomePod avant") == nil)
        #expect(Self.interieur(d) == ["rloc:0400", "rloc:0800"])
    }

    /// Mini-maillage a la main, pour les branches du rangement des enfants que la capture n'atteint pas.
    /// Partition 46CBEBCD, centre "Centre" (routeur 1, RLOC16 0400, reconnu par son `xa`). Routeurs 2 a 6
    /// inconnus (0800 a 1800) : l'anneau interieur, en partant du haut dans le sens horaire, 0800 a -90 degres,
    /// 0C00 a -18, 1000 a 54, 1400 a 126, 1800 a 198 (dernier quart : `atan2` y rend -162). Routeur 7 (1C00)
    /// reconnu comme l'appareil E...0F, que la disposition n'affiche pas : sans place sur les anneaux.
    /// Un enfant par RLOC16 donne, sous le routeur `rloc16 >> 10` (0001 : le routeur 0, absent du maillage).
    /// Rend la disposition.
    static func dispositionDeLaSonde(enfants: [UInt16]) throws -> Disposition {
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
        return d
    }

    /// Rend l'anneau exterieur de cette disposition, dans l'ordre de ses noeuds.
    static func exterieur(enfants: [UInt16]) throws -> [String] {
        try dispositionDeLaSonde(enfants: enfants).noeuds.filter { $0.genre == .appareil }.map(\.id)
    }

    /// Zone dont le centre est la seule annonce et sans appareil sur l'anneau exterieur, mais avec des routeurs de
    /// la sonde (les cinq inconnus) sur l'anneau interieur : son rayon compte cet anneau (90, plus la marge), et non
    /// le nombre d'annonces (une seule, ce qui donnait 60, moins que l'anneau). Tout noeud tient dans sa zone, son
    /// propre rayon compris. Avec des enfants sur l'anneau exterieur, c'est lui qui donne le rayon.
    @Test func rayonDeZoneAvecLAnneauInterieurDeLaSonde() throws {
        func toutDansSaZone(_ d: Disposition) throws {
            let zone = try #require(d.zones.first)
            for n in d.noeuds {
                #expect(n.position.distance(zone.centre) + n.rayon <= zone.rayon, "\(n.id) dans sa zone")
            }
        }
        let sansEnfants = try Self.dispositionDeLaSonde(enfants: [])
        #expect(try #require(sansEnfants.zones.first).rayon == Disposition.rayonInterieur + Disposition.marge)
        try toutDansSaZone(sansEnfants)
        let avecEnfants = try Self.dispositionDeLaSonde(enfants: [0x0801, 0x0C01])
        #expect(try #require(avecEnfants.zones.first).rayon == Disposition.rayonExterieurMin + Disposition.marge)
        try toutDansSaZone(avecEnfants)
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

    /// Le premier noeud de l'anneau est en haut, a -pi/2 ; `atan2` peut le rendre un ulp (ou moins) en dessous, et le
    /// repli ne doit pas l'envoyer en fin d'anneau avec le dernier quart. Celui-ci, des qu'il s'ecarte de la
    /// tolerance, est replie de 2 pi ; le reste n'est pas touche.
    @Test func repliDeLAngleALaFrontiereDuHaut() {
        let haut = -Double.pi / 2
        for t in [haut, haut.nextUp, haut.nextDown, haut - 1e-12, haut + 1e-12] {
            #expect(abs(Disposition.angleAnneau(t) - haut) < 1e-9, "\(t) reste en haut")
        }
        let dernierQuart = haut - 0.01
        #expect(Disposition.angleAnneau(dernierQuart) == dernierQuart + 2 * .pi)
        #expect(Disposition.angleAnneau(-Double.pi + 0.1) == -Double.pi + 0.1 + 2 * .pi)
        for t in [0.0, 1.0, Double.pi / 2, Double.pi] { #expect(Disposition.angleAnneau(t) == t) }
    }

    /// Enfant sans parent dans le maillage (0001 : le routeur 0 n'y est pas) : rejete en fin d'anneau, apres tous les
    /// autres, y compris ceux du dernier quart (1801, angle 3,46) et ceux du centre (0401 : 3 pi / 2, soit 4,71, la
    /// plus grande cle d'un parent connu). La sentinelle doit depasser toutes les cles.
    @Test func enfantSansParentEnFinDAnneau() throws {
        let ordre = try Self.exterieur(enfants: [0x0001, 0x0C01, 0x1401, 0x0401, 0x1801])
        #expect(ordre == ["rloc:0C01", "rloc:1401", "rloc:1801", "rloc:0401", "rloc:0001"])
    }

    /// Enfant dont le parent est connu mais sans place sur les anneaux (1C01 : le routeur 7, l'appareil E...0F
    /// que la disposition n'affiche pas) : rejete en fin d'anneau, comme celui qui n'a pas de parent.
    @Test func enfantDUnParentSansPlaceEnFinDAnneau() throws {
        let ordre = try Self.exterieur(enfants: [0x1C01, 0x0C01, 0x1401])
        #expect(ordre == ["rloc:0C01", "rloc:1401", "rloc:1C01"])
    }
}
