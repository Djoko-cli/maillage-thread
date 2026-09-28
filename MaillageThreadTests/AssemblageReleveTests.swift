import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

/// Parties pures du recenseur : assemblage du releve, cibles gardees.
@Suite("Recenseur : releve assemble (instances resolues, cibles gardees)")
struct AssemblageReleveTests {
    typealias Cible = ResolveurDNSSD.Cible
    typealias Listee = Recenseur.InstanceListee

    static let date = Date(timeIntervalSince1970: 1_790_000_000)
    static let routeur = "_meshcop._udp"
    static let matter = "_matter._tcp"
    static let hap = "_hap._udp"

    /// TXT brut : chaque chaine precedee de sa longueur.
    static func txt(_ chaines: String...) -> Data {
        Data(chaines.flatMap { [UInt8($0.utf8.count)] + Array($0.utf8) })
    }

    static func releve(_ vues: [Listee], _ cibles: [String: Cible]) -> Annonces {
        Recenseur.assembler(vues: vues, cibles: cibles, adresses: [:], routes: [], prefixesLocaux: [], date: date)
    }

    @Test func instanceListeeNonResolueAbsente() {
        let vues = [Listee(type: Self.routeur, instance: "Apple TV 4K", txt: Self.txt("nn=MyHome1520326503")),
                    Listee(type: Self.matter, instance: "309BEA1CCA0C1569-00000000F8EDDF49", txt: Data()),
                    Listee(type: Self.hap, instance: "Eve Door 4A3B", txt: Self.txt("md=Eve Door"))]
        let a = Self.releve(vues, [:])
        #expect(a.routeurs.isEmpty, "routeur liste sans cible : resolu de nouveau au releve suivant")
        #expect(a.matter.isEmpty, "instance Matter listee sans cible : jamais publiee sans hote")
        #expect(a.hap.isEmpty)
    }

    @Test func instanceResolue() {
        let brut = Self.txt("nn=MyHome1520326503", "tv=1.4.0")
        let vues = [Listee(type: Self.routeur, instance: "Apple TV 4K", txt: brut),
                    Listee(type: Self.routeur, instance: "HomePod Droit", txt: Data()),
                    Listee(type: Self.matter, instance: "309BEA1CCA0C1569-00000000F8EDDF49", txt: Data()),
                    Listee(type: Self.matter, instance: "20A842B5C3C38A0D-00000000F8EDDF49", txt: Data())]
        let pont = Cible(hote: "561F9A6463953778.local", port: 5540, txt: Data())
        let cibles = [
            Recenseur.cle(Self.routeur, "Apple TV 4K"): Cible(hote: "Apple-TV-4K.local", port: 49153, txt: Data()),
            Recenseur.cle(Self.matter, "309BEA1CCA0C1569-00000000F8EDDF49"): pont,
            Recenseur.cle(Self.matter, "20A842B5C3C38A0D-00000000F8EDDF49"): pont,
        ]
        let adresses = ["Apple-TV-4K.local": ["fe80::4e:ff54:91ca:c791"]]
        let routes = [RouteIPv6(prefixe: "fd2d:3b27:72b8::/64", passerelle: "fe80::4e:ff54:91ca:c791", interface: "en0")]
        let a = Recenseur.assembler(vues: vues, cibles: cibles, adresses: adresses, routes: routes,
                                    prefixesLocaux: ["fd4b:5d37:6d94:480e::/64"], date: Self.date)
        #expect(a.routeurs == [AnnonceService(instance: "Apple TV 4K", hote: "Apple-TV-4K.local", port: 49153,
                                              txt: ChampsTXT(brut: brut))], "HomePod Droit : pas encore de cible")
        #expect(a.matter.map(\.instance) == ["20A842B5C3C38A0D-00000000F8EDDF49", "309BEA1CCA0C1569-00000000F8EDDF49"],
                "triees par instance")
        #expect(a.matter.allSatisfy { $0.hote == "561F9A6463953778.local" && $0.port == 5540 })
        #expect(a.hap.isEmpty)
        #expect(a.date == Self.date)
        #expect(a.adresses == adresses)
        #expect(a.routes == routes)
        #expect(a.prefixesLocaux == ["fd4b:5d37:6d94:480e::/64"])
    }

    @Test func txtDeSecours() {
        let navigateur = Self.txt("SII=5000")
        let resolu = Self.txt("SII=300", "SAI=300")
        let vues = [Listee(type: Self.matter, instance: "A", txt: Data()),
                    Listee(type: Self.matter, instance: "B", txt: navigateur)]
        let cibles = [Recenseur.cle(Self.matter, "A"): Cible(hote: "A.local", port: 5540, txt: resolu),
                      Recenseur.cle(Self.matter, "B"): Cible(hote: "B.local", port: 5540, txt: resolu)]
        let a = Self.releve(vues, cibles)
        #expect(a.matter.first { $0.instance == "A" }?.txt == ChampsTXT(brut: resolu), "TXT du navigateur vide : celui de la cible")
        #expect(a.matter.first { $0.instance == "B" }?.txt == ChampsTXT(brut: navigateur), "TXT du navigateur d'abord")
    }

    @Test func ciblesGardees() {
        let atv = Recenseur.cle(Self.routeur, "Apple TV 4K")
        let homePod = Recenseur.cle(Self.routeur, "HomePod Droit")
        let ancienne = Cible(hote: "Apple-TV-4K.local", port: 49153, txt: Data())
        let autre = Cible(hote: "HomePod-Droit.local", port: 49153, txt: Data())
        let cibles = [atv: ancienne, homePod: autre]
        let listees: Set = [atv, homePod]

        // Tout resoudre de nouveau (rafraichir) : un echec garde la cible precedente.
        let echec = Recenseur.retenir(cibles: cibles, resolues: [:], listees: listees)
        #expect(echec == cibles)
        let vues = [Listee(type: Self.routeur, instance: "Apple TV 4K", txt: Data()),
                    Listee(type: Self.routeur, instance: "HomePod Droit", txt: Data())]
        #expect(Self.releve(vues, echec).routeurs.map(\.hote) == ["Apple-TV-4K.local", "HomePod-Droit.local"],
                "toujours dans le releve, avec leur hote")

        // Une reussite remplace la cible.
        let nouvelle = Cible(hote: "Apple-TV-4K-2.local", port: 49154, txt: Data())
        #expect(Recenseur.retenir(cibles: cibles, resolues: [atv: nouvelle], listees: listees)
                == [atv: nouvelle, homePod: autre])

        // Une instance qui n'est plus listee perd sa cible.
        #expect(Recenseur.retenir(cibles: cibles, resolues: [:], listees: [atv]) == [atv: ancienne])
    }
}
