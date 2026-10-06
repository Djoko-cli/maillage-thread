import Foundation
import ServiceManagement
import Testing
@testable import MaillageThread

/// L'etat de Thread Route, lu de ce que le systeme dit de ses deux plists : le sien et celui de
/// halo-routes, son ancien nom. Seulement la decision, sur des etats donnes : l'etat reel depend du Mac.
@Suite("Thread Route : son etat")
struct ThreadRouteTests {
    /// Les quatre cas : absent, a approuver, actif, ancien.
    @Test func quatreCas() {
        #expect(EtatThreadRoute.depuis(nouveau: .notRegistered, ancien: .notRegistered) == .absent)
        #expect(EtatThreadRoute.depuis(nouveau: .notFound, ancien: .notFound) == .absent)
        #expect(EtatThreadRoute.depuis(nouveau: .requiresApproval, ancien: .notRegistered) == .aApprouver,
                "desactive dans Reglages Systeme")
        #expect(EtatThreadRoute.depuis(nouveau: .enabled, ancien: .notRegistered) == .actif)
        #expect(EtatThreadRoute.depuis(nouveau: .notRegistered, ancien: .enabled) == .ancien, "halo-routes encore la")
        #expect(EtatThreadRoute.depuis(nouveau: .notRegistered, ancien: .requiresApproval) == .ancien)
    }

    /// Thread Route compte d'abord : un halo-routes reste n'y change rien.
    @Test func leNouveauDAbord() {
        #expect(EtatThreadRoute.depuis(nouveau: .enabled, ancien: .enabled) == .actif)
        #expect(EtatThreadRoute.depuis(nouveau: .requiresApproval, ancien: .enabled) == .aApprouver)
    }

    /// Les plists que lit l'app : ceux que posent l'installateur et l'ancien.
    @Test func plists() {
        #expect(EtatThreadRoute.plist.path == "/Library/LaunchDaemons/fr.djoko.thread.route.plist")
        #expect(EtatThreadRoute.plistAncien.path == "/Library/LaunchDaemons/fr.djoko.halo.routes.plist")
    }

    /// Ce que montrent les Reglages : un libelle par etat, et ce qu'il reste a faire, avec la commande de la
    /// copie de ce depot.
    @Test func libellesEtConsignes() {
        let tous: [EtatThreadRoute] = [.absent, .aApprouver, .actif, .ancien]
        #expect(Set(tous.map(\.libelle)).count == 4)
        #expect(EtatThreadRoute.actif.consigne == nil)
        #expect(EtatThreadRoute.absent.consigne?.contains("sh outils/thread-route/installer.sh") == true)
        #expect(EtatThreadRoute.ancien.consigne?.contains("sh outils/thread-route/installer.sh") == true)
        #expect(EtatThreadRoute.ancien.consigne != EtatThreadRoute.absent.consigne)
        let approuver = EtatThreadRoute.aApprouver.consigne
        #expect(approuver != nil && approuver?.contains("installer.sh") == false)
    }
}
