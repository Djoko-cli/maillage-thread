import MaillageCoeur
import SwiftUI

/// App de la barre des menus : ecoute le reseau local en permanence, tient
/// le journal, notifie ; graphe et journal dans leurs fenetres.
/// `--args -demo` : rejoue la panne du 27/09, sans rien ecrire ni notifier.
@main
struct MaillageThreadApp: App {
    @State private var surveillance: Surveillance
    @State private var ouverture: OuvertureSession
    @State private var nomsMaison: DossierNoms
    private let notifications = Notifications()
    private static let demo = CommandLine.arguments.contains("-demo")
    /// Le graphe s'ouvre au lancement en mode demo et au tout premier lancement
    /// (jamais a l'ouverture de session ensuite).
    private let ouvrirGraphe: Bool
    static let clePremierGraphe = "grapheDejaOuvert"

    init() {
        let s = Surveillance(mode: Self.demo ? .demo : .direct, dossier: Self.demo ? nil : Surveillance.dossierParDefaut)
        let o = OuvertureSession()
        // Sans memoire en demo et sous tests : ni les vraies preferences ni le vrai signet.
        let d = DossierNoms(cache: Self.demo || Surveillance.sousTests
                            ? nil : Surveillance.dossierParDefaut.appendingPathComponent("noms-maison.json"))
        _surveillance = State(initialValue: s)
        _ouverture = State(initialValue: o)
        _nomsMaison = State(initialValue: d)
        let premier = !UserDefaults.standard.bool(forKey: Self.clePremierGraphe)
        ouvrirGraphe = !Surveillance.sousTests && (Self.demo || premier)
        guard !Surveillance.sousTests else { return }
        if !Self.demo {
            UserDefaults.standard.set(true, forKey: Self.clePremierGraphe)
            let n = notifications
            s.surAlertes = { n.presenter($0) }
            n.demanderAutorisation()
            o.proposerAuPremierLancement()
            d.surNoms = { [weak s] m in s?.noms.maison = m }
            d.demarrer()
        }
        s.demarrer()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarre()
                .environment(surveillance)
                .environment(ouverture)
                .environment(nomsMaison)
        } label: {
            IconeBarre(ouvrirGraphe: ouvrirGraphe)
                .environment(surveillance)
        }
        .menuBarExtraStyle(.window)

        Window("Maillage Thread", id: "graphe") {
            FenetreGraphe()
                .environment(surveillance)
                .environment(nomsMaison)
        }
        .defaultSize(width: 1100, height: 760)
        .defaultLaunchBehavior(.suppressed)

        Window("Journal", id: "journal") {
            FenetreJournal()
                .environment(surveillance)
        }
        .defaultSize(width: 720, height: 560)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            FenetreReglages()
                .environment(surveillance)
                .environment(ouverture)
                .environment(nomsMaison)
        }
    }
}
