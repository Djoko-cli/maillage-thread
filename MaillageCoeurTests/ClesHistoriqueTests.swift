import Foundation
import Testing
@testable import MaillageCoeur

/// Cles des routeurs dans l'historique (verification du 05/10) : un routeur sans ExtMac dans un releve prend celle du
/// meme identifiant, dans la meme partition, au releve suivant le plus proche qui en a une, a defaut au precedent le
/// plus proche ; sinon "rloc:XXXX". Valeurs inventees.
@Suite("Cles des routeurs dans l'historique")
struct ClesHistoriqueTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_006_400)
    static let c1 = "E0000000000000C1"
    static let c2 = "E0000000000000C2"
    static let c3 = "E0000000000000C3"

    /// Releve `n` (a `n` fois 5 min de t0) de la partition `p` : les routeurs donnes, par identifiant, avec leur ExtMac
    /// ou nil.
    static func releve(_ n: Int, _ routeurs: [Int: String?], partition p: String = "0000000A") -> ReleveMaillage {
        ReleveMaillage(date: t0.addingTimeInterval(Double(n) * 300), partition: p,
                       routeurs: routeurs.keys.sorted().map { .init(id: $0, extMac: routeurs[$0] ?? nil) },
                       liens: [], enfants: [], signaux: [], parentSonde: nil)
    }

    /// Le releve lui-meme d'abord ; sans ExtMac, le suivant le plus proche qui en a une, puis le precedent le plus
    /// proche. L'identifiant 1 passe d'un routeur (c1) a un autre (c2) : chaque releve prend le plus proche, pas le
    /// premier ni le dernier de la liste.
    @Test func suivantPuisPrecedent() {
        let releves = [Self.releve(0, [1: nil]), Self.releve(1, [1: Self.c1]), Self.releve(2, [1: nil]),
                       Self.releve(3, [1: Self.c2]), Self.releve(4, [1: nil]), Self.releve(5, [1: nil])]
        let cles = ClesHistorique(releves: releves)
        #expect(releves.indices.map { cles.cle(releve: $0, routeur: 1) } == [Self.c1, Self.c1, Self.c2, Self.c2, Self.c2, Self.c2])
    }

    /// Jamais identifie : "rloc:XXXX", qu'il soit dans la liste des routeurs du releve ou seulement cite.
    @Test func jamaisIdentifie() {
        let releves = [Self.releve(0, [1: nil]), Self.releve(1, [0: Self.c1, 1: nil])]
        let cles = ClesHistorique(releves: releves)
        #expect(cles.cle(releve: 0, routeur: 1) == "rloc:0400" && cles.cle(releve: 1, routeur: 1) == "rloc:0400")
        #expect(cles.cle(releve: 0, routeur: 5) == "rloc:1400", "cite, hors de la liste")
        #expect(cles.cle(releve: 0, routeur: 0) == Self.c1, "cite au releve 0, identifie au suivant")
    }

    /// Le meme identifiant dans une autre partition est un autre routeur : son ExtMac ne compte pas, meme plus proche.
    @Test func autrePartition() {
        let releves = [Self.releve(0, [1: nil]), Self.releve(1, [1: Self.c1], partition: "0000000B"),
                       Self.releve(2, [1: nil]), Self.releve(3, [1: nil], partition: "0000000B"),
                       Self.releve(4, [1: Self.c2])]
        let cles = ClesHistorique(releves: releves)
        #expect(releves.indices.map { cles.cle(releve: $0, routeur: 1) } == [Self.c2, Self.c1, Self.c2, Self.c1, Self.c2])
        let seule = ClesHistorique(releves: [Self.releve(0, [1: nil]), Self.releve(1, [1: Self.c1], partition: "0000000B")])
        #expect(seule.cle(releve: 0, routeur: 1) == "rloc:0400")
    }

    /// Fonction totale : un identifiant hors de 0...62 rend "rloc:?", meme avec une ExtMac (donnees non conformes) ; un
    /// releve hors de la liste rend "rloc:XXXX".
    @Test func plage() {
        let releves = [Self.releve(0, [62: nil, 63: Self.c3, 64: Self.c3]), Self.releve(1, [63: nil, 64: nil])]
        let cles = ClesHistorique(releves: releves)
        for id in [63, 64, -1, 70000, 1 << 40] {
            #expect(cles.cle(releve: 0, routeur: id) == "rloc:?" && cles.cle(releve: 1, routeur: id) == "rloc:?", "\(id)")
        }
        #expect(cles.cle(releve: 0, routeur: 62) == "rloc:F800")
        #expect(cles.cle(releve: 0, routeur: 0) == "rloc:0000")
        #expect(cles.cle(releve: 2, routeur: 1) == "rloc:0400" && cles.cle(releve: -1, routeur: 1) == "rloc:0400")
        #expect(ClesHistorique(releves: []).cle(releve: 0, routeur: 1) == "rloc:0400")
    }

    /// Une ExtMac que tient un autre routeur du meme releve n'est pas prise (le routeur c1 a change d'identifiant ;
    /// l'ancien reste sans ExtMac) : deux routeurs d'un releve n'ont jamais la meme cle.
    @Test func extMacDejaPrise() {
        let releves = [Self.releve(0, [1: Self.c1]), Self.releve(1, [1: nil, 2: Self.c1])]
        let cles = ClesHistorique(releves: releves)
        #expect(cles.cle(releve: 1, routeur: 1) == "rloc:0400")
        #expect(cles.cle(releve: 1, routeur: 2) == Self.c1)
        #expect(cles.cle(releve: 0, routeur: 2) == "rloc:0800", "au releve 0, c1 est au routeur 1")
    }
}
