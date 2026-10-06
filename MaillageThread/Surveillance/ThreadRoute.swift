import Foundation
import ServiceManagement

/// Etat de Thread Route, le demon systeme qui garde la route du Mac vers le reseau Thread, et donc vers la sonde
/// par « Reseau Thread ». Sa source est dans le depot du pont Halo ; ce depot en garde une copie a l'identique
/// (`outils/thread-route`). Il s'installe par son installateur, avec le mot de passe administrateur : une app dans
/// le bac a sable ne peut pas l'inscrire elle-meme (essai du 06/10 : SMAppService y refuse un demon qui n'est pas
/// dans le bac a sable). L'app lit son etat aupres du systeme, ce que permet le bac a sable
/// (`SMAppService.statusForLegacyPlist`).
enum EtatThreadRoute: Equatable, Sendable {
    /// Ni Thread Route, ni halo-routes.
    case absent
    /// Installe, mais desactive dans Reglages Systeme (Ouverture et extensions).
    case aApprouver
    /// Installe et autorise : launchd le garde en marche.
    case actif
    /// halo-routes, son ancien nom, est encore installe : l'installateur le remplace.
    case ancien

    static let plist = URL(fileURLWithPath: "/Library/LaunchDaemons/fr.djoko.thread.route.plist")
    static let plistAncien = URL(fileURLWithPath: "/Library/LaunchDaemons/fr.djoko.halo.routes.plist")

    /// L'etat, a partir de ce que le systeme dit du plist de Thread Route et de celui de halo-routes.
    static func depuis(nouveau: SMAppService.Status, ancien: SMAppService.Status) -> EtatThreadRoute {
        switch nouveau {
        case .enabled: .actif
        case .requiresApproval: .aApprouver
        default: ancien == .enabled || ancien == .requiresApproval ? .ancien : .absent
        }
    }

    /// L'etat du moment, lu aupres du systeme. `statut` repond pour un plist : les tests y mettent une
    /// source simulee, pour ne jamais lire l'etat reel du Mac.
    static func lire(
        statut: (URL) -> SMAppService.Status = { SMAppService.statusForLegacyPlist(at: $0) }
    ) -> EtatThreadRoute {
        depuis(nouveau: statut(plist), ancien: statut(plistAncien))
    }

    /// Libelle de l'etat, dans les Reglages.
    var libelle: String {
        switch self {
        case .absent: String(localized: "Absent")
        case .aApprouver: String(localized: "Désactivé dans Réglages Système")
        case .actif: String(localized: "Actif")
        case .ancien: String(localized: "halo-routes, son ancien nom, est encore installé")
        }
    }

    /// Ce qu'il reste a faire ; rien quand il est actif.
    var consigne: String? {
        switch self {
        case .absent: String(localized: "Pour l'installer : sh outils/thread-route/installer.sh (mot de passe administrateur).")
        case .aApprouver: String(localized: "L'autoriser dans Réglages Système, Général, Ouverture et extensions.")
        case .actif: nil
        case .ancien: String(localized: "Pour le remplacer : sh outils/thread-route/installer.sh (mot de passe administrateur).")
        }
    }
}
