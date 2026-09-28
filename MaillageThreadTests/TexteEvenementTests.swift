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
        #expect(TexteEvenement.isoles(scission) == "Aqara HubM100 #DFEB")
        let notification = TexteEvenement.notification(AlerteAEnvoyer(categorie: .pertes, identifiant: "p", evenements: pertes))
        #expect(notification.corps.contains("Prise bureau"))
        #expect(Notifications.active(.scission, preferences: UserDefaults(suiteName: "vide-\(UUID())")!))
        #expect(!Notifications.active(.informations, preferences: UserDefaults(suiteName: "vide-\(UUID())")!))
    }
}
