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
}
