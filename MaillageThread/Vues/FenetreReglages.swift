import AppKit
import MaillageCoeur
import SwiftUI
import UniformTypeIdentifiers

/// Reglages : notifications par categorie, ouverture a la connexion, diagnostic et capture.
struct FenetreReglages: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(OuvertureSession.self) private var ouverture
    @AppStorage(Notifications.cle(.scission)) private var scission = CategorieAlerte.scission.parDefaut
    @AppStorage(Notifications.cle(.routeurDisparu)) private var routeurDisparu = CategorieAlerte.routeurDisparu.parDefaut
    @AppStorage(Notifications.cle(.pertes)) private var pertes = CategorieAlerte.pertes.parDefaut
    @AppStorage(Notifications.cle(.informations)) private var informations = CategorieAlerte.informations.parDefaut
    @State private var messageCapture: String?

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Réseau scindé", isOn: $scission)
                Toggle("Routeur de bordure disparu", isOn: $routeurDisparu)
                Toggle("Au moins 3 appareils perdus en 10 min (une notification groupée)", isOn: $pertes)
                Toggle("Autres changements", isOn: $informations)
            }
            Section("Ouverture") {
                Toggle("Ouvrir à la connexion", isOn: Binding(get: { ouverture.active }, set: { ouverture.basculer($0) }))
                if ouverture.approbationRequise {
                    Button("Approuver dans Réglages Système…") { ouverture.ouvrirReglagesSysteme() }
                }
                if let e = ouverture.erreur {
                    Text(e).foregroundStyle(.red)
                }
            }
            Section("Diagnostic") {
                LabeledContent("Écoute", value: etatEcoute)
                LabeledContent("Dernier relevé",
                               value: surveillance.dernierReleve?.date.formatted(date: .abbreviated, time: .standard) ?? "—")
                if let a = surveillance.dernierReleve {
                    LabeledContent("Services vus", value: "_meshcop._udp \(a.routeurs.count) · _matter._tcp \(a.matter.count) · _hap._udp \(a.hap.count)")
                    LabeledContent("Préfixes du Mac", value: a.prefixesLocaux.joined(separator: ", "))
                }
                LabeledContent("Table de routage", value: routes)
                if let e = surveillance.erreurJournal {
                    LabeledContent("Journal", value: e)
                }
                HStack {
                    Button("Enregistrer une capture…") { enregistrerCapture() }
                        .disabled(surveillance.dernierReleve == nil)
                    Button("Afficher le journal dans le Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [Surveillance.dossierParDefaut.appendingPathComponent("Journal")])
                    }
                    .disabled(surveillance.mode == .demo)
                }
                if let messageCapture {
                    Text(messageCapture).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
    }

    private var etatEcoute: String {
        switch surveillance.etatEcoute {
        case .demarrage: String(localized: "démarrage")
        case .active: String(localized: "active")
        case .reseauLocalRefuse: String(localized: "accès au réseau local refusé")
        case .demo: String(localized: "mode démo")
        case .erreur(let m): m
        }
    }

    private var routes: String {
        switch surveillance.routesLisibles {
        case true?: String(localized: "lue")
        case false?: String(localized: "illisible : préfixes tirés des adresses")
        case nil: "—"
        }
    }

    private func enregistrerCapture() {
        let donnees: Data
        do {
            guard let d = try surveillance.captureJSON() else { return }
            donnees = d
        } catch {
            messageCapture = error.localizedDescription
            return
        }
        let panneau = NSSavePanel()
        panneau.allowedContentTypes = [.json]
        panneau.nameFieldStringValue = "capture-maillage.json"
        guard panneau.runModal() == .OK, let url = panneau.url else { return }
        do {
            try donnees.write(to: url, options: .atomic)
            messageCapture = String(localized: "Capture enregistrée : \(url.lastPathComponent)")
        } catch {
            messageCapture = error.localizedDescription
        }
    }
}
