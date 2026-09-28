import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Textes des evenements et des notifications")
struct TexteEvenementTests {
    static func demo() -> Surveillance {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        return s
    }

    @Test func textes() {
        let t = ScenarioPanne.date(4, 14)
        for type in TypeEvenement.allCases {
            let e = Evenement(date: t, type: type, sujet: Sujet(id: "x", nom: "Nuki Ultra"), avant: "chef", apres: "routeur",
                              periode: type == .veille ? DateInterval(start: t, end: t.addingTimeInterval(60)) : nil)
            #expect(!TexteEvenement.titre(e).isEmpty, "\(type)")
        }
        let s = Self.demo()
        guard case .pertes(let pertes)? = s.lignesJournal.first else { return }
        let titre = TexteEvenement.titre(LigneJournal.pertes(pertes))
        #expect(titre.contains("5"))
        #expect(titre.contains(TexteEvenement.heure(ScenarioPanne.date(4, 20))))
        let scission = s.evenements.first { $0.type == .reseauScinde }!
        #expect(TexteEvenement.isoles(scission) == "Aqara HubM100 #80E0")
        let notification = TexteEvenement.notification(AlerteAEnvoyer(categorie: .pertes, identifiant: "p", evenements: pertes))
        #expect(notification.corps.contains("Prise bureau"))
        #expect(Notifications.active(.scission, preferences: UserDefaults(suiteName: "vide-\(UUID())")!))
        #expect(!Notifications.active(.informations, preferences: UserDefaults(suiteName: "vide-\(UUID())")!))
    }

    /// Point de depart d'un reseau vu apres le lancement : le reseau est nomme.
    @Test func departDUnReseau() {
        let t = ScenarioPanne.date(4, 14)
        let lancement = Evenement(date: t, type: .surveillanceDemarree, details: ["routeurs": "6", "appareils": "24"])
        let reseau = Evenement(date: t, type: .surveillanceDemarree, reseau: "1122334455667788",
                               sujet: Sujet(id: "1122334455667788", nom: "Voisin"),
                               details: ["routeurs": "2", "appareils": "1"])
        let titre = TexteEvenement.titre(reseau)
        #expect(titre.contains("Voisin"), "le reseau est nomme")
        #expect(titre.contains("2") && titre.contains("1"))
        #expect(!TexteEvenement.titre(lancement).contains("Voisin"))
        #expect(TexteEvenement.titre(lancement).contains("24"), "le texte du lancement ne change pas")
    }
}
