import SwiftUI

/// Squelette : l'icone de la barre des menus et "Quitter". Les scenes
/// definitives (graphe, journal, reglages) arrivent a la tache 17.
@main
struct MaillageThreadApp: App {
    var body: some Scene {
        MenuBarExtra("Maillage Thread", systemImage: "point.3.connected.trianglepath.dotted") {
            Button("Quitter") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
