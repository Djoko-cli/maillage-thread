import AppKit
import Foundation
import Testing
@testable import MaillageThread

@MainActor
@Suite("Barre des menus : icone")
struct MenuTests {
    @Test func icone() {
        #expect(IconeBarre.image(alerte: false).isTemplate)
        #expect(!IconeBarre.image(alerte: true).isTemplate, "orange : pas une image modele")
    }

    /// « Ouvrir le graphe » et « Journal… » ferment le menu, comme « Reglages… » (01b0a42) : l'app inactive, le menu
    /// restait ouvert (reverification du 02/10). Les deux boutons passent par `MenuBarre.ouvrir` : la fenetre demandee
    /// s'ouvre, puis celle du menu, ici une fenetre hors ecran, se ferme. (Les boutons ne se pressent pas d'un test :
    /// SwiftUI n'y construit pas leur accessibilite.)
    @Test(arguments: ["graphe", "journal"]) func ouvrirUneFenetreFermeLeMenu(_ id: String) {
        let menu = NSPanel(contentRect: NSRect(x: -6000, y: -6000, width: 320, height: 200), styleMask: [.borderless],
                           backing: .buffered, defer: false)
        menu.isReleasedWhenClosed = false
        menu.orderFrontRegardless()
        defer { menu.orderOut(nil) }
        var ouvertes: [String] = []
        #expect(menu.isVisible)
        MenuBarre.ouvrir(id, par: { ouvertes.append($0) }, menu: menu)
        #expect(ouvertes == [id], "la fenetre demandee")
        #expect(!menu.isVisible, "le menu se ferme")
    }
}
