import Foundation
import Synchronization
import Testing
@testable import MaillageCoeur

/// Avancements recus d'une tournee, dans l'ordre.
final class ReleveAvancement: Sendable {
    private let liste = Mutex<[AvancementTournee]>([])

    func noter(_ a: AvancementTournee) {
        liste.withLock { $0.append(a) }
    }

    var avancements: [AvancementTournee] { liste.withLock { $0 } }

    /// Etapes dans l'ordre ou elles commencent (une etape revenue apres une autre y serait deux fois).
    var etapes: [AvancementTournee.Etape] {
        avancements.map(\.etape).reduce(into: []) { if $0.last != $1 { $0.append($1) } }
    }

    func de(_ e: AvancementTournee.Etape) -> [AvancementTournee] { avancements.filter { $0.etape == e } }

    /// Compteurs croissants : `fait` monte de 0 ou 1 a chaque appel, le total ne baisse jamais.
    static func croissants(_ a: [AvancementTournee]) -> Bool {
        zip(a, a.dropFirst()).allSatisfy { p, s in (0...1).contains(s.fait - p.fait) && s.total >= p.total }
    }
}

/// Sonde rejouee : repond avec les TLV de la capture, echoue en `delai` pour le reste (ou en
/// `trop_long`, reponse de plus de 1100 octets par le reseau, pour `tropLongs`), et note ses
/// requetes.
struct SondeRejouee: InterlocuteurSonde {
    actor Registre {
        /// Requetes `diag`, "<cible>|<tlv,...>".
        var requetes: [String] = []
        /// Demandes de la table des routeurs (`routeurs`).
        var tables = 0
        func noter(_ r: String) { requetes.append(r) }
        func noterTable() { tables += 1 }
    }

    /// La sonde ne rend pas sa table (firmware sans `routeurs`, verrou d'OpenThread refuse).
    struct SansTable: Error {}

    let etatSonde: EtatSonde
    /// "<cible>|<tlv,...>" -> TLV hexa.
    let reponses: [String: String]
    /// Table des routeurs de la sonde ; nil : elle ne la rend pas.
    var table: [RouteurSonde]? = []
    /// "<cible>|<tlv,...>" dont la reponse est trop longue pour le reseau.
    var tropLongs: Set<String> = []
    let registre = Registre()

    func etat() async throws -> EtatSonde { etatSonde }

    func routeurs() async throws -> [RouteurSonde] {
        await registre.noterTable()
        guard let table else { throw SansTable() }
        return table
    }

    /// Table des 7 routeurs de la capture, telle qu'une sonde en FED la donne : tous par leur
    /// RLOC16 ; l'ExtMac des seuls routeurs `entendus` (RLOC16 -> ExtMac inventee).
    static func table(entendus: [UInt16: String] = [:]) -> [RouteurSonde] {
        [0x0400, 0x5000, 0x6000, 0xAC00, 0xB400, 0xCC00, 0xE400].map { (r: UInt16) in
            let ext = entendus[r]
            return RouteurSonde(id: Int(r >> 10), rloc16: String(format: "%04X", r), ext: ext, lqIn: ext == nil ? 0 : 3,
                                lqOut: ext == nil ? 0 : 3, age: 4, lien: ext != nil)
        }
    }

    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        let cle = String(format: "%04X|", cible) + tlv.map(String.init).joined(separator: ",")
        await registre.noter(cle)
        if tropLongs.contains(cle) {
            return ResultatDiag(id: 0, cible: String(format: "%04X", cible), ok: false, erreur: "trop_long")
        }
        guard let t = reponses[cle] else {
            return ResultatDiag(id: 0, cible: String(format: "%04X", cible), ok: false, ms: delaiMs, erreur: "delai")
        }
        return ResultatDiag(id: 0, cible: String(format: "%04X", cible), ok: true, ms: 50, code: "2.04", tlv: t)
    }

    /// Etat de la capture apres le changement de parent : AC09, enfant de AC00 (muet) ; `table` :
    /// celle des routeurs de la sonde, sans ExtMac par defaut (la capture vient d'une sonde en MED).
    static func capture(chef: Int = 24, reponsesEnPlus: [String: String] = [:],
                        table: [RouteurSonde]? = SondeRejouee.table(), tropLongs: Set<String> = []) throws -> SondeRejouee {
        let base = #"{"v":1,"t":"etat","role":"child","rloc16":"AC09","mode":"rn","parent":{"rloc16":"AC00","ext":"E000000000000007","lqIn":3,"lqOut":3,"rssi":-89},"partition":"46CBEBCD","chef":\#(chef),"canal":25,"prefixeMaille":"FD00111122220C87","xp":"A0A1A2A3A4A5A6A7","suspendue":false}"#
        guard case .etat(let e)? = MessageSonde.lire(Data(base.utf8)) else { throw CaptureSonde.ErreurCapture(id: 0) }
        var r: [String: String] = [
            "6000|5,6": try CaptureSonde.tlv(204),
            "5000|0,1,5,16,8,24": try CaptureSonde.tlv(104),
            "6000|0,1,5,16,8,24": try CaptureSonde.tlv(106),
            "5000|25,26,27,28": try CaptureSonde.tlv(105),
            "6000|25,26,27,28": try CaptureSonde.tlv(107),
            "5000|7": try CaptureSonde.tlv(206),
            "AC01|0,1,2,8": try CaptureSonde.tlv(411),
            "5004|0,8": try CaptureSonde.tlv(116),
            "5001|0,8": try CaptureSonde.tlv(117),
            "6003|0,8": try CaptureSonde.tlv(118),
        ]
        for (n, id) in zip(3...8, 503...508) { r[String(format: "AC%02X|0,1,2,8", n)] = try CaptureSonde.tlv(id) }
        r.merge(reponsesEnPlus) { _, b in b }
        return SondeRejouee(etatSonde: e, reponses: r, table: table, tropLongs: tropLongs)
    }

    /// La meme sonde, avec seulement les reponses dont la cle est gardee ; registre neuf.
    func filtree(_ garder: (String) -> Bool) -> SondeRejouee {
        SondeRejouee(etatSonde: etatSonde, reponses: reponses.filter { garder($0.key) }, table: table, tropLongs: tropLongs)
    }
}

extension Tournee {
    /// Tournee qui doit rendre un maillage (tests) : le maillage et la memoire ; nil sans maillage.
    static func complete(_ sonde: some InterlocuteurSonde, memoire: MemoireTournee, maintenant: Date,
                         avancement: (@Sendable (AvancementTournee) -> Void)? = nil)
        async throws -> (maillage: Maillage, memoire: MemoireTournee)? {
        let r = try await executer(sonde, memoire: memoire, maintenant: maintenant, avancement: avancement)
        return r.maillage.map { ($0, r.memoire) }
    }
}

@Suite("Tournee de la sonde")
struct TourneeTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    /// Premiere tournee : routeurs, roles, liens, enfants des tables et du balayage, memoire.
    @Test func premiere() async throws {
        let sonde = try SondeRejouee.capture()
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.partition == "46CBEBCD")
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        #expect(m.chef?.id == 24)
        #expect(m.routeurs.filter(\.muet).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m.routeurs.filter(\.bordure).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m.routeur(45)?.bbrPrincipal == true)
        #expect(m.routeur(43)?.extMac == "E000000000000007", "parent de la sonde")
        #expect(m.routeur(20)?.pile?.hasPrefix("SL-OPENTHREAD") == true)
        #expect(m.liens.count == 7)
        #expect(m.enfants(de: 43).map(\.rloc16) == [0xAC01, 0xAC03, 0xAC04, 0xAC05, 0xAC06, 0xAC07, 0xAC08, 0xAC09])
        #expect(m.enfants(de: 43).last?.source == .sonde)
        #expect(m.enfants.count == 14)
        let de20 = m.enfants(de: 20)
        #expect(de20.map(\.extMac) == ["E000000000000005", "E000000000000004"], "tables : identifies une fois")
        #expect(de20.first?.adresses.count == 4)
        #expect(m.enfants(de: 24).filter { $0.extMac == nil }.map(\.rloc16) == [0x6002, 0x6005, 0x6006], "sans reponse")
        #expect(mem.echecs[43] == 1)
        #expect(!mem.estMuet(43), "muet a partir de 2 echecs de suite")
        #expect(mem.repondants == [20, 24])
        #expect(mem.identites[0xAC00] == "E000000000000007")
        #expect(mem.identites[0x5000] == "E000000000000002")
        #expect(mem.dernierBalayage == Self.t0)
        #expect(mem.muetsBalayes == [1, 43, 45, 51, 57])
        let requetes = await sonde.registre.requetes
        #expect(requetes.filter { $0.hasSuffix("|0,1,2,8") }.count == 48, "AC00 : 1 a 17 sauf 9 ; les autres : 1 a 8")
        #expect(requetes.filter { $0.hasSuffix("|25,26,27,28") }.count == 2)
        #expect(requetes.filter { $0.hasSuffix("|0,8") }.count == 6, "les 6 enfants des tables")
        #expect(mem.identifies.count == 3)
    }

    /// Deuxieme tournee (5 min) : les muets le deviennent ; pas de nouveau balayage ;
    /// pile deja connue ; les enfants des tables sans reponse attendent 30 min.
    /// Troisieme (10 min) : les muets ne sont plus interroges.
    @Test func suivantes() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let avant2 = await sonde.registre.requetes.count
        let (m2, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 300))
        let requetes2 = await sonde.registre.requetes.dropFirst(avant2)
        #expect(requetes2.count == 9, "chef, 7 routeurs, Network Data ; pas 6002, 6005, 6006, demandes il y a 5 min")
        #expect(mem2.estMuet(43))
        #expect(mem2.muetInterroge[43] == Self.t0 + 300)
        #expect(m2.enfants(de: 43).count == 8, "enfants du balayage garde")

        let avant3 = await sonde.registre.requetes.count
        let (m3, _) = try #require(try await Tournee.complete(sonde, memoire: mem2, maintenant: Self.t0 + 600))
        let requetes3 = Array(await sonde.registre.requetes.dropFirst(avant3))
        #expect(requetes3.first == "6000|5,6", "la liste des routeurs d'abord")
        #expect(requetes3.sorted() == ["5000|0,1,5,16,8,24", "5000|7", "6000|0,1,5,16,8,24", "6000|5,6"],
                "en parallele : dans le desordre")
        #expect(m3.routeurs.filter(\.muet).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m3.enfants.count == 14)
    }

    /// Balayage de nouveau apres 30 min, et les 6 identites des enfants des tables
    /// redemandees parce que 30 min ont passe ; une seconde avant, ni l'un ni l'autre.
    @Test func balayageDu() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let avant = await sonde.registre.requetes.count
        let (_, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 1799))
        let pendant = await sonde.registre.requetes.count
        _ = try await Tournee.complete(sonde, memoire: mem2, maintenant: Self.t0 + 1800)
        let toutes = await sonde.registre.requetes
        let presque = toutes[avant..<pendant], requetes = toutes[pendant...]
        #expect(presque.filter { $0.hasSuffix("|0,1,2,8") || $0.hasSuffix("|0,8") }.isEmpty, "29 min 59 s : rien de du")
        #expect(requetes.filter { $0.hasSuffix("|0,1,2,8") }.count == 48)
        #expect(requetes.filter { $0.hasSuffix("|0,8") }.count == 6, "30 min ont passe : identites redemandees")
    }

    /// Chef muet : Route64 d'un routeur qui a repondu a la tournee precedente.
    @Test func chefMuet() async throws {
        let sonde = try SondeRejouee.capture(chef: 45, reponsesEnPlus: ["5000|5,6": try CaptureSonde.tlv(104)])
        var mem = MemoireTournee()
        mem.echecs[45] = 2
        mem.repondants = [20]
        let (m, _) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0))
        #expect(m.routeurs.count == 7)
        #expect(m.chef?.id == 45)
        #expect(await sonde.registre.requetes.first == "5000|5,6")
    }

    /// Chef muet des le lancement : memoire neuve, aucun secours connu. La Route64
    /// vient du premier groupe de 8 identifiants ou un routeur repond (16 a 23 : le 20).
    @Test func chefMuetSansSecours() async throws {
        let sonde = try SondeRejouee.capture(chef: 45, reponsesEnPlus: ["5000|5,6": try CaptureSonde.tlv(104)])
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        #expect(m.chef?.id == 45)
        let requetes = await sonde.registre.requetes
        #expect(requetes.first == "B400|5,6", "le chef d'abord")
        let attendues = ["B400|5,6"] + (0...23).map { String(format: "%04X|5,6", UInt16($0) << 10) }
        #expect(requetes.filter { $0.hasSuffix("|5,6") }.sorted() == attendues.sorted(), "puis 0 a 23 : arret au groupe du 20")
        #expect(mem.repondants == [20, 24])
    }

    /// Rien ne repond, sonde attachee : pas de maillage ; la memoire rendue n'a que la partition
    /// et l'identite du parent. La liste des routeurs est demandee au plus une fois a chaque
    /// identifiant.
    @Test func rienNeRepond() async throws {
        let sonde = try SondeRejouee.capture().filtree { _ in false }
        let r = try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0)
        #expect(r.maillage == nil)
        var attendue = MemoireTournee()
        attendue.partition = "46CBEBCD"
        attendue.identites = [0xAC00: "E000000000000007"]
        #expect(r.memoire == attendue)
        let requetes = await sonde.registre.requetes
        #expect(requetes.allSatisfy { $0.hasSuffix("|5,6") })
        #expect(requetes.count <= 63)
        #expect(Set(requetes).count == requetes.count, "une fois par identifiant")
    }

    /// Echec passager : le 20, qui repond d'habitude, rate une tournee. Muet dans ce
    /// maillage, mais pas balaye ; il l'est au second echec de suite.
    @Test func echecPassager() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let sans20 = sonde.filtree { !$0.hasPrefix("5000|") }
        let (m2, mem2) = try #require(try await Tournee.complete(sans20, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(await sans20.registre.requetes.filter { $0.hasSuffix("|0,1,2,8") }.isEmpty, "pas de balayage")
        #expect(mem2.dernierBalayage == Self.t0)
        #expect(mem2.muetsBalayes == [1, 43, 45, 51, 57])
        #expect(m2.routeur(20)?.muet == true)

        let (_, mem3) = try #require(try await Tournee.complete(sans20, memoire: mem2, maintenant: Self.t0 + 600))
        #expect(mem3.estMuet(20))
        #expect(mem3.muetsBalayes == [1, 20, 43, 45, 51, 57], "muet : balaye")
        #expect(await sans20.registre.requetes.contains("5001|0,1,2,8"))
    }

    /// TLV (hexa) d'une reponse dont le type est dans `types`, dans leur ordre : une moitie de
    /// la reponse entiere.
    static func garder(_ hexa: String, _ types: Set<UInt8>) throws -> String {
        let o = [UInt8](try #require(Data(hexa: hexa)))
        var i = 0, gardees: [UInt8] = []
        while i + 2 <= o.count {
            let fin = i + 2 + Int(o[i + 1])
            if types.contains(o[i]) { gardees += o[i..<fin] }
            i = fin
        }
        return Data(gardees).hexa
    }

    /// Reponse du routeur 20 trop longue pour le reseau (`trop_long` : plus de 1100 octets) : il a
    /// repondu. Sa requete est refaite une fois en deux moities de TLV, reunies : le maillage et
    /// la memoire sont ceux d'une reponse entiere ; ni echec, ni balayage de ses enfants.
    @Test func tropLongEnDeuxMoities() async throws {
        let (m0, mem0) = try #require(try await Tournee.complete(try SondeRejouee.capture(), memoire: MemoireTournee(),
                                                                  maintenant: Self.t0))
        let entiere = try CaptureSonde.tlv(104)
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["5000|0,1,5": try Self.garder(entiere, [0, 1, 5]),
                                                              "5000|16,8,24": try Self.garder(entiere, [16, 8, 24])],
                                             tropLongs: ["5000|0,1,5,16,8,24"])
        let releve = ReleveAvancement()
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               avancement: { releve.noter($0) }))
        #expect(m == m0)
        #expect(mem == mem0)
        #expect(m.routeur(20)?.muet == false)
        let routeurs = releve.de(.routeurs)
        #expect(ReleveAvancement.croissants(routeurs))
        #expect(routeurs.last == AvancementTournee(etape: .routeurs, fait: 9, total: 9), "7 routeurs, puis 2 moities")
        let requetes = await sonde.registre.requetes
        let de20 = requetes.filter { $0.hasPrefix("5000|") && $0 != "5000|7" && $0 != "5000|25,26,27,28" }
        #expect(de20.first == "5000|0,1,5,16,8,24", "la requete entiere d'abord")
        #expect(de20.dropFirst().sorted() == ["5000|0,1,5", "5000|16,8,24"], "puis ses moities, une seule fois, en parallele : dans le desordre")
        #expect(!requetes.contains("5001|0,1,2,8"), "pas de balayage de ses enfants")
    }

    /// Une moitie encore trop longue : ce qu'on a est garde (ExtMac, liens), sans nouveau
    /// decoupage, et le routeur n'est ni muet, ni en echec, ni balaye.
    @Test func tropLongUneMoitieTropLongue() async throws {
        let (m0, _) = try #require(try await Tournee.complete(try SondeRejouee.capture(), memoire: MemoireTournee(),
                                                               maintenant: Self.t0))
        let entiere = try CaptureSonde.tlv(104)
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["5000|0,1,5": try Self.garder(entiere, [0, 1, 5])],
                                             tropLongs: ["5000|0,1,5,16,8,24", "5000|16,8,24"])
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeur(20)?.muet == false)
        #expect(m.routeur(20)?.extMac == "E000000000000002")
        #expect(m.liens == m0.liens, "liens de sa Route64, dans la moitie gardee")
        #expect(m.enfants(de: 20).isEmpty, "table des enfants dans la moitie trop longue")
        #expect(mem.echecs[20] == 0)
        #expect(mem.repondants == [20, 24])
        #expect(!mem.muetsBalayes.contains(20))
        let requetes = await sonde.registre.requetes
        let de20 = requetes.filter { $0.hasPrefix("5000|0,1,5") || $0.hasPrefix("5000|16,8") }
        #expect(de20.first == "5000|0,1,5,16,8,24", "la requete entiere d'abord")
        #expect(de20.dropFirst().sorted() == ["5000|0,1,5", "5000|16,8,24"], "ses moities, pas de troisieme decoupage")
        #expect(!requetes.contains("5001|0,1,2,8"))
    }

    /// Un routeur qui repond sans son ExtMac (ici la moitie qui la porte reste sans reponse)
    /// garde l'identite connue d'une tournee precedente, comme un muet : il ne perd pas son nom.
    @Test func repondantSansExtMacGardeSonIdentite() async throws {
        let (_, mem1) = try #require(try await Tournee.complete(try SondeRejouee.capture(), memoire: MemoireTournee(),
                                                                 maintenant: Self.t0))
        #expect(mem1.identites[0x5000] == "E000000000000002")
        let entiere = try CaptureSonde.tlv(104)
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["5000|16,8,24": try Self.garder(entiere, [16, 8, 24])],
                                             tropLongs: ["5000|0,1,5,16,8,24"])
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(m.routeur(20)?.muet == false)
        #expect(m.routeur(20)?.extMac == "E000000000000002", "identite connue")
        #expect(m.enfants(de: 20).count == 2, "sa table des enfants, dans la moitie recue")
        #expect(mem.identites[0x5000] == "E000000000000002")
        #expect(mem.echecs[20] == 0)
    }

    /// L'identite connue d'un routeur qui repond sans ExtMac se lit apres toutes les reponses :
    /// si un routeur suivant repond avec cette ExtMac (elle a change de routeur), la paire perimee
    /// est oubliee et le premier ne la prend pas (valeurs de la capture ; paire perimee inventee).
    @Test func identiteConnueApresToutesLesReponses() async throws {
        var memoire = MemoireTournee()
        memoire.partition = "46CBEBCD"
        memoire.identites = [0x5000: "E000000000000003"]  // l'ExtMac du 24, perimee sous le 20
        let entiere = try CaptureSonde.tlv(104)
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["5000|16,8,24": try Self.garder(entiere, [16, 8, 24])],
                                             tropLongs: ["5000|0,1,5,16,8,24"])
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: memoire, maintenant: Self.t0))
        #expect(m.routeur(24)?.extMac == "E000000000000003")
        #expect(m.routeur(20)?.extMac == nil, "la paire perimee est oubliee avant d'etre lue")
        #expect(mem.identites[0x5000] == nil)
        #expect(mem.identites[0x6000] == "E000000000000003")
    }

    /// Aucun routeur ne repond a sa requete (sonde occupee...) : les secours de la
    /// tournee precedente restent.
    @Test func repondantsGardes() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let seulChef = sonde.filtree { $0 == "6000|5,6" }
        let (m2, mem2) = try #require(try await Tournee.complete(seulChef, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(m2.routeurs.filter(\.muet).count == 7)
        #expect(mem2.repondants == [20, 24])
    }

    /// Identites gardees : a 30 min, les enfants des tables ne repondent pas a la
    /// nouvelle demande ; celles de la premiere tournee restent.
    @Test func identitesGardees() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let endormis = sonde.filtree { !$0.hasSuffix("|0,8") }
        let (m2, mem2) = try #require(try await Tournee.complete(endormis, memoire: mem1, maintenant: Self.t0 + 1800))
        #expect(await endormis.registre.requetes.filter { $0.hasSuffix("|0,8") }.count == 6, "redemandees")
        #expect(m2.enfants(de: 20).map(\.extMac) == ["E000000000000005", "E000000000000004"])
        #expect(mem2.identifies.count == 3)
    }

    /// Table des routeurs de la sonde (FED) : les paires RLOC16 ↔ ExtMac des routeurs qu'elle
    /// entend sont retenues comme celle de son parent, et donnent leur ExtMac aux routeurs
    /// muets ; une demande par tournee. La sonde les entend ensuite moins (elle a bouge) : les
    /// paires restent (ExtMac inventees).
    @Test func routeursEntendus() async throws {
        let entendus: [UInt16: String] = [0xE400: "E0000000000000E4", 0xCC00: "E0000000000000CC"]
        let sonde = try SondeRejouee.capture(table: SondeRejouee.table(entendus: entendus))
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeur(57)?.extMac == "E0000000000000E4")
        #expect(m.routeur(51)?.extMac == "E0000000000000CC")
        #expect(m.routeur(1)?.extMac == nil, "pas entendu")
        #expect(m.routeur(43)?.extMac == "E000000000000007", "le parent, par etat")
        #expect(mem.identites[0xE400] == "E0000000000000E4" && mem.identites[0xCC00] == "E0000000000000CC")
        #expect(mem.identites[0xAC00] == "E000000000000007")
        #expect(await sonde.registre.tables == 1)

        let ailleurs = try SondeRejouee.capture(table: SondeRejouee.table(entendus: [0xE400: "E0000000000000E4"]))
        let (m2, mem2) = try #require(try await Tournee.complete(ailleurs, memoire: mem, maintenant: Self.t0 + 300))
        #expect(m2.routeur(51)?.extMac == "E0000000000000CC", "retenue d'une tournee a l'autre")
        #expect(mem2.identites[0xCC00] == "E0000000000000CC")
        #expect(await ailleurs.registre.tables == 1)
    }

    /// Pas de table (firmware sans `routeurs`, verrou d'OpenThread refuse) : la tournee continue,
    /// sans ces paires.
    @Test func sansTable() async throws {
        let sonde = try SondeRejouee.capture(table: nil)
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        #expect(mem.identites == [0xAC00: "E000000000000007", 0x5000: "E000000000000002", 0x6000: "E000000000000003"])
        #expect(await sonde.registre.tables == 1)
    }

    /// Une ExtMac n'a qu'un RLOC16 : un routeur qui a change d'identifiant (redemarrage) perd
    /// l'ancienne paire, qui ne donne plus son ExtMac a l'identifiant libere.
    @Test func identiteDeplacee() async throws {
        let sonde = try SondeRejouee.capture(table: SondeRejouee.table(entendus: [0xE400: "E0000000000000E4"]))
        var mem = MemoireTournee()
        mem.partition = "46CBEBCD"
        mem.identites[0x0400] = "E0000000000000E4"
        let (m, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0))
        #expect(mem2.identites[0x0400] == nil)
        #expect(mem2.identites[0xE400] == "E0000000000000E4")
        #expect(m.routeur(1)?.extMac == nil)
        #expect(m.routeur(57)?.extMac == "E0000000000000E4")
    }

    /// Pas de liste des routeurs (plus rien ne repond apres `etat`) : pas de maillage, mais la
    /// memoire rendue garde les identites apprises (parent, table des routeurs), pour qu'une sonde
    /// promenee les garde ; le reste est la memoire d'avant, aucun routeur ne passe pour muet.
    /// Dans une autre partition, elle est remise a zero, sauf ces identites (ExtMac inventee).
    @Test func identitesSansListe() async throws {
        let (_, mem1) = try #require(try await Tournee.complete(try SondeRejouee.capture(), memoire: MemoireTournee(),
                                                               maintenant: Self.t0))
        let muette = try SondeRejouee.capture(table: SondeRejouee.table(entendus: [0xE400: "E0000000000000E4"]))
            .filtree { _ in false }
        let r = try await Tournee.executer(muette, memoire: mem1, maintenant: Self.t0 + 300)
        #expect(r.maillage == nil)
        var attendue = mem1
        attendue.identites[0xE400] = "E0000000000000E4"
        #expect(r.memoire == attendue, "la memoire d'avant, plus le routeur entendu")

        var ailleurs = mem1
        ailleurs.partition = "73586B68"
        let r2 = try await Tournee.executer(muette, memoire: ailleurs, maintenant: Self.t0 + 300)
        #expect(r2.maillage == nil)
        var neuve = MemoireTournee()
        neuve.partition = "46CBEBCD"
        neuve.identites = [0xAC00: "E000000000000007", 0xE400: "E0000000000000E4"]
        #expect(r2.memoire == neuve)
    }

    /// Network Data en echec a la tournee suivante : les dernieres lues servent (routeurs de
    /// bordure, BBR principal) ; sinon, les routeurs de bordure et leurs candidats disparaitraient
    /// d'une tournee a l'autre. Sans Network Data deja lues, aucun routeur de bordure.
    @Test func reseauGarde() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(mem1.donneesReseau != nil)
        let sansReseau = sonde.filtree { $0 != "5000|7" }
        let (m2, mem2) = try #require(try await Tournee.complete(sansReseau, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(await sansReseau.registre.requetes.contains("5000|7"), "demandees, en echec")
        #expect(m2.routeurs.filter(\.bordure).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m2.routeur(45)?.bbrPrincipal == true)
        #expect(mem2.donneesReseau == mem1.donneesReseau)
        let (m3, _) = try #require(try await Tournee.complete(sansReseau, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m3.routeurs.filter(\.bordure).isEmpty)
    }

    /// Autre partition : les Network Data gardees de l'ancienne sont oubliees avec le reste de la
    /// memoire ; la requete echouant, aucun routeur n'est marque d'apres elles (ni routeur de
    /// bordure, ni BBR principal).
    @Test func autrePartitionOublieLesNetworkData() async throws {
        let anciennes = try #require(DonneesReseau(MaillageTests.bbrE400PuisB400))
        var mem = MemoireTournee()
        mem.partition = "73586B68"
        mem.donneesReseau = anciennes
        let sonde = try SondeRejouee.capture().filtree { $0 != "5000|7" }
        let (m, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0))
        #expect(mem2.partition == "46CBEBCD")
        #expect(mem2.donneesReseau == nil)
        #expect(!m.routeurs.contains { $0.bordure || $0.bbrPrincipal })
    }

    /// Paire d'un routeur sorti de la liste des routeurs (routeur disparu, identifiant libere) :
    /// oubliee des que la tournee a la Route64. Celle d'un routeur encore dans la liste reste,
    /// meme s'il n'est plus entendu (ExtMac inventees).
    @Test func pairesHorsDeLaListe() async throws {
        let sonde = try SondeRejouee.capture()
        var mem = MemoireTournee()
        mem.partition = "46CBEBCD"
        mem.identites = [0x0800: "E0000000000000EE", 0xE400: "E0000000000000E4"]
        let (m, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0))
        #expect(!m.routeurs.contains { $0.id == 2 }, "l'identifiant 2 n'est pas dans la Route64")
        #expect(mem2.identites[0x0800] == nil, "oubliee")
        #expect(mem2.identites[0xE400] == "E0000000000000E4", "le routeur 57 est dans la liste : gardee")
        #expect(m.routeur(57)?.extMac == "E0000000000000E4")
    }

    /// Autre partition (panne, fusion) : les identifiants de routeur y sont
    /// redistribues ; ce qui etait retenu de l'ancienne ne sert plus.
    @Test func autrePartition() async throws {
        let sonde = try SondeRejouee.capture()
        var mem = MemoireTournee()
        mem.partition = "73586B68"
        mem.identites[0xB400] = "E0000000000000EE"
        mem.echecs[20] = 2
        mem.muetInterroge[20] = Self.t0
        mem.dernierBalayage = Self.t0
        mem.muetsBalayes = [1, 43, 45, 51, 57]
        let (m, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0 + 60))
        #expect(mem2.partition == "46CBEBCD")
        #expect(m.routeur(45)?.extMac == nil, "B400 : pas l'ExtMac retenu dans l'autre partition")
        #expect(m.routeur(20)?.muet == false, "5000 interroge de nouveau")
        #expect(mem2.dernierBalayage == Self.t0 + 60, "balayage refait")
    }

    /// Sonde suspendue (interrupteur eteint dans Maison) : pas de tournee, aucune requete.
    @Test func suspendue() async throws {
        let base = #"{"v":1,"t":"etat","role":"child","rloc16":"AC09","mode":"rn","parent":null,"partition":"46CBEBCD","chef":24,"canal":25,"prefixeMaille":null,"xp":null,"suspendue":true}"#
        guard case .etat(let e)? = MessageSonde.lire(Data(base.utf8)) else {
            Issue.record("etat illisible")
            return
        }
        let sonde = SondeRejouee(etatSonde: e, reponses: [:])
        var mem = MemoireTournee()
        mem.echecs[20] = 1
        let r = try await Tournee.executer(sonde, memoire: mem, maintenant: Self.t0)
        #expect(r.maillage == nil)
        #expect(r.memoire == mem, "memoire inchangee")
        #expect(await sonde.registre.requetes.isEmpty)
        #expect(await sonde.registre.tables == 0, "ni la table des routeurs")
    }

    /// Avancement de la premiere tournee : les six etapes dans l'ordre, chacune annoncee a 0
    /// puis une requete a la fois jusqu'a son total, connu des son debut ici. Les totaux sont
    /// les requetes envoyees : `etat` et `routeurs` pour la sonde, 48 pour le balayage.
    @Test func avancementPremiere() async throws {
        let sonde = try SondeRejouee.capture()
        let releve = ReleveAvancement()
        _ = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                   avancement: { releve.noter($0) }))
        #expect(releve.etapes == AvancementTournee.Etape.allCases)
        let totaux: [AvancementTournee.Etape: Int] = [.etatSonde: 2, .listeRouteurs: 1, .routeurs: 7, .pileEtReseau: 3,
                                                       .balayage: 48, .identites: 6]
        for (etape, total) in totaux {
            let a = releve.de(etape)
            #expect(a.map(\.fait) == Array(0...total), "\(etape)")
            #expect(a.allSatisfy { $0.total == total }, "\(etape)")
        }
        let requetes = await sonde.registre.requetes
        #expect(requetes.count == totaux.values.reduce(0, +) - 2, "une requete diag par pas, hors etat et routeurs de la sonde")
        #expect(await sonde.registre.tables == 1)
        #expect(requetes.filter { $0.hasSuffix("|0,1,2,8") }.count == 48)
    }

    /// Deuxieme tournee (5 min) : la liste des routeurs s'arrete au chef, avant son total
    /// (le chef et un secours) ; piles connues : Network Data seules ; le balayage (pas du)
    /// et les identites (demandees il y a 5 min) sont annonces sans rien a faire.
    @Test func avancementSuivante() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let releve = ReleveAvancement()
        _ = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 300,
                                                   avancement: { releve.noter($0) }))
        #expect(releve.etapes == AvancementTournee.Etape.allCases)
        #expect(releve.de(.listeRouteurs) == [AvancementTournee(etape: .listeRouteurs, fait: 0, total: 2),
                                              AvancementTournee(etape: .listeRouteurs, fait: 1, total: 2)])
        #expect(releve.de(.pileEtReseau).last == AvancementTournee(etape: .pileEtReseau, fait: 1, total: 1))
        #expect(releve.de(.balayage) == [AvancementTournee(etape: .balayage, fait: 0, total: 0)])
        #expect(releve.de(.identites) == [AvancementTournee(etape: .identites, fait: 0, total: 0)])
        #expect(ReleveAvancement.croissants(releve.de(.routeurs)))
    }

    /// Chef muet des le lancement : le total de la liste des routeurs grandit quand la
    /// recherche commence (le chef, puis les 62 autres identifiants) ; elle s'arrete au
    /// groupe du 20, avant son total, apres 25 requetes.
    @Test func avancementRecherche() async throws {
        let sonde = try SondeRejouee.capture(chef: 45, reponsesEnPlus: ["5000|5,6": try CaptureSonde.tlv(104)])
        let releve = ReleveAvancement()
        _ = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                   avancement: { releve.noter($0) }))
        let liste = releve.de(.listeRouteurs)
        #expect(Array(liste.prefix(3)) == [AvancementTournee(etape: .listeRouteurs, fait: 0, total: 1),
                                           AvancementTournee(etape: .listeRouteurs, fait: 1, total: 1),
                                           AvancementTournee(etape: .listeRouteurs, fait: 1, total: 63)])
        #expect(liste.last == AvancementTournee(etape: .listeRouteurs, fait: 25, total: 63))
        #expect(ReleveAvancement.croissants(liste))
        #expect(await sonde.registre.requetes.filter { $0.hasSuffix("|5,6") }.count == 25)
    }

    /// Un enfant repond loin sous un routeur muet (le numero 8 du routeur 1) : le total du
    /// balayage grandit de 8 numeros sans jamais baisser, et finit sur les requetes envoyees.
    @Test func avancementBalayageQuiGrandit() async throws {
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["0408|0,1,2,8": try CaptureSonde.tlv(503)])
        let releve = ReleveAvancement()
        _ = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                   avancement: { releve.noter($0) }))
        let balayage = releve.de(.balayage)
        #expect(balayage.first == AvancementTournee(etape: .balayage, fait: 0, total: 48))
        #expect(balayage.last == AvancementTournee(etape: .balayage, fait: 56, total: 56))
        #expect(ReleveAvancement.croissants(balayage))
        #expect(await sonde.registre.requetes.filter { $0.hasSuffix("|0,1,2,8") }.count == 56)
    }

    /// Sonde pas encore dans le reseau.
    @Test func nonAttachee() async throws {
        let base = #"{"v":1,"t":"etat","role":"disabled","rloc16":"FFFE","mode":"rn","parent":null,"partition":null,"chef":null,"canal":11,"prefixeMaille":null,"xp":null,"suspendue":false}"#
        guard case .etat(let e)? = MessageSonde.lire(Data(base.utf8)) else {
            Issue.record("etat illisible")
            return
        }
        let sonde = SondeRejouee(etatSonde: e, reponses: [:])
        let releve = ReleveAvancement()
        let r = try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                           avancement: { releve.noter($0) })
        #expect(r.maillage == nil && r.memoire == MemoireTournee())
        #expect(await sonde.registre.tables == 0, "pas de table hors d'une partition")
        #expect(releve.avancements == [AvancementTournee(etape: .etatSonde, fait: 0, total: 2),
                                       AvancementTournee(etape: .etatSonde, fait: 1, total: 2)],
                "l'etape s'arrete avant son total")
    }
}
