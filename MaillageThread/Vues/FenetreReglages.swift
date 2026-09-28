import AppKit
import MaillageCoeur
import SwiftUI
import UniformTypeIdentifiers

/// Reglages : notifications par categorie, ouverture a la connexion, langue,
/// noms de Maison (dossier du passeur), diagnostic et capture.
struct FenetreReglages: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(OuvertureSession.self) private var ouverture
    @Environment(DossierNoms.self) private var nomsMaison
    @AppStorage(Notifications.cle(.scission)) private var scission = CategorieAlerte.scission.parDefaut
    @AppStorage(Notifications.cle(.routeurDisparu)) private var routeurDisparu = CategorieAlerte.routeurDisparu.parDefaut
    @AppStorage(Notifications.cle(.pertes)) private var pertes = CategorieAlerte.pertes.parDefaut
    @AppStorage(Notifications.cle(.informations)) private var informations = CategorieAlerte.informations.parDefaut
    @State private var messageCapture: String?
    @State private var langue = LangueApp.lire()
    @State private var messageLangue: String?

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
            Section {
                Picker("Langue", selection: $langue) {
                    Text("Celle du Mac").tag(LangueApp.systeme)
                    Text(verbatim: "Français").tag(LangueApp.francais)
                    Text(verbatim: "English").tag(LangueApp.anglais)
                }
                .onChange(of: langue) { _, l in LangueApp.ecrire(l) }
                if langue != LangueApp.auLancement {
                    HStack {
                        Text("La langue change au prochain lancement.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Relancer maintenant") {
                            Task {
                                do { try await LangueApp.relancer() } catch { messageLangue = error.localizedDescription }
                            }
                        }
                    }
                }
                if let messageLangue {
                    Text(messageLangue).foregroundStyle(.red)
                }
            }
            Section("Noms de Maison") {
                LabeledContent("Dossier des noms") {
                    HStack {
                        Text(nomsMaison.dossier?.path(percentEncoded: false) ?? "—")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choisir…") { nomsMaison.choisir() }
                            .disabled(surveillance.mode == .demo)
                    }
                }
                if let n = nomsMaison.noms {
                    LabeledContent("Noms lus",
                                   value: String(localized: "\(n.accessoires.count) accessoires · \(n.date.formatted(date: .abbreviated, time: .shortened))"))
                    if DossierNoms.estAncien(n, maintenant: .now) {
                        Text("Noms du \(n.date.formatted(date: .abbreviated, time: .omitted)) : relance outils/passeur.sh pour les rafraîchir.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let p = nomsMaison.probleme {
                    Text(p).font(.caption).foregroundStyle(.red)
                }
                Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                    .disabled(surveillance.mode == .demo)
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
        // Etat de l'ouverture a la connexion relu a chaque ouverture (Reglages Systeme).
        .onAppear { ouverture.actualiser() }
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
