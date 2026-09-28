import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Alertes : une scission n'est notifiee qu'une fois")
struct AlertesTests {
    static let t = Date(timeIntervalSince1970: 1_790_000_000)
    static let xp = "4B5D376D942B480E"
    static let voisin = "1122334455667788"

    /// Scission d'un reseau en ces partitions (details : partition -> routeurs, comme `detailsPartitions`).
    static func scission(_ partitions: [String], constate: Bool, reseau: String = xp) -> Evenement {
        Evenement(date: t, type: .reseauScinde, reseau: reseau, sujet: Sujet(id: reseau, nom: reseau),
                  apres: String(partitions.count), constate: constate,
                  details: Dictionary(uniqueKeysWithValues: partitions.map { ($0, "routeurs de \($0)") }))
    }

    @Test func signature() {
        #expect(Alertes.signature(Self.scission(["E6A6AD72", "7C6A2A68"], constate: true))
                == "4B5D376D942B480E|7C6A2A68,E6A6AD72", "reseau, puis ses partitions triees")
    }

    /// Une scission constatee (lancement, ouverture de session) deja notifiee ne l'est pas de nouveau.
    @Test func constateeDejaNotifiee() {
        var a = Alertes()
        a.scissionsNotifiees = ["4B5D376D942B480E|7C6A2A68,E6A6AD72"]
        #expect(a.traiter([Self.scission(["7C6A2A68", "E6A6AD72"], constate: true)]).isEmpty)
        #expect(a.scissionsNotifiees == ["4B5D376D942B480E|7C6A2A68,E6A6AD72"])
    }

    /// Une scission constatee d'une nouvelle forme (autre signature) notifie, et est retenue.
    @Test func nouvelleSignature() {
        var a = Alertes()
        a.scissionsNotifiees = ["4B5D376D942B480E|7C6A2A68,E6A6AD72"]
        let e = Self.scission(["7C6A2A68", "682A6A7C"], constate: true)
        #expect(a.traiter([e]).map(\.categorie) == [.scission])
        #expect(a.scissionsNotifiees == ["4B5D376D942B480E|7C6A2A68,E6A6AD72", "4B5D376D942B480E|682A6A7C,7C6A2A68"])
        #expect(a.traiter([e]).isEmpty, "trouvee de nouveau (lancement suivant) : pas de seconde notification")
    }

    /// Une scission observee notifie toujours, et est retenue : le lancement suivant ne la notifie pas.
    @Test func observeeToujoursNotifiee() {
        var a = Alertes()
        a.scissionsNotifiees = ["4B5D376D942B480E|7C6A2A68,E6A6AD72"]
        #expect(a.traiter([Self.scission(["7C6A2A68", "E6A6AD72"], constate: false)]).map(\.categorie) == [.scission],
                "observee : notifiee meme si deja connue")
        #expect(a.traiter([Self.scission(["7C6A2A68", "682A6A7C"], constate: false)]).map(\.categorie) == [.scission])
        #expect(a.scissionsNotifiees.contains("4B5D376D942B480E|682A6A7C,7C6A2A68"))
        #expect(a.traiter([Self.scission(["7C6A2A68", "682A6A7C"], constate: true)]).isEmpty)
    }

    /// Une reunion efface les signatures de son reseau, et seulement les siennes.
    @Test func reunion() {
        var a = Alertes()
        a.scissionsNotifiees = ["4B5D376D942B480E|7C6A2A68,E6A6AD72", "4B5D376D942B480E|682A6A7C,7C6A2A68",
                                "1122334455667788|BBBBBBBB,CCCCCCCC"]
        let reuni = Evenement(date: Self.t, type: .reseauReuni, reseau: Self.xp, sujet: Sujet(id: Self.xp, nom: Self.xp),
                              avant: "2", apres: "1")
        #expect(a.traiter([reuni]).map(\.categorie) == [.informations], "notification inchangee")
        #expect(a.scissionsNotifiees == ["1122334455667788|BBBBBBBB,CCCCCCCC"])
        #expect(a.traiter([Self.scission(["7C6A2A68", "E6A6AD72"], constate: true)]).map(\.categorie) == [.scission],
                "scinde de nouveau apres la reunion : notifie")
        #expect(a.traiter([Self.scission(["BBBBBBBB", "CCCCCCCC"], constate: true, reseau: Self.voisin)]).isEmpty,
                "l'autre reseau garde la sienne")
    }
}
