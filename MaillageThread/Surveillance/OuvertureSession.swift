import Foundation
import Observation
import ServiceManagement

/// Ouverture a la connexion (SMAppService) : proposee une fois au premier
/// lancement, puis a la main dans le menu et les reglages.
@MainActor
@Observable
final class OuvertureSession {
    private(set) var etat: SMAppService.Status = SMAppService.mainApp.status
    private(set) var erreur: String?

    static let clePremierLancement = "ouvertureSessionProposee"

    var active: Bool { etat == .enabled }
    var approbationRequise: Bool { etat == .requiresApproval }

    func basculer(_ oui: Bool) {
        do {
            if oui {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            erreur = nil
        } catch {
            erreur = error.localizedDescription
        }
        etat = SMAppService.mainApp.status
    }

    /// Au premier lancement : ouvrir a la connexion (choix de la spec), une seule fois.
    func proposerAuPremierLancement(preferences: UserDefaults = .standard) {
        guard !preferences.bool(forKey: Self.clePremierLancement) else { return }
        preferences.set(true, forKey: Self.clePremierLancement)
        if etat == .notRegistered { basculer(true) }
    }

    func ouvrirReglagesSysteme() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
