import Foundation
import MaillageCoeur
import UserNotifications

/// Notifications du systeme (le mode Concentration s'applique de lui-meme).
/// Une categorie se coupe dans les reglages ; une notification de meme
/// identifiant remplace la precedente (pertes groupees).
@MainActor
final class Notifications {
    static func cle(_ c: CategorieAlerte) -> String { "notification.\(c.rawValue)" }

    static func active(_ c: CategorieAlerte, preferences: UserDefaults = .standard) -> Bool {
        preferences.object(forKey: cle(c)) as? Bool ?? c.parDefaut
    }

    func demanderAutorisation() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func presenter(_ alertes: [AlerteAEnvoyer]) {
        for a in alertes where Self.active(a.categorie) {
            let (titre, corps) = TexteEvenement.notification(a)
            let contenu = UNMutableNotificationContent()
            contenu.title = titre
            contenu.body = corps
            if a.categorie != .informations { contenu.sound = .default }
            let requete = UNNotificationRequest(identifier: a.identifiant, content: contenu, trigger: nil)
            UNUserNotificationCenter.current().add(requete) { _ in }
        }
    }
}
