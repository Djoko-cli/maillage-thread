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
    @Environment(SondeMaillage.self) private var sonde
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
            Section("Sonde") {
                if surveillance.mode == .demo {
                    Text("Mode démo : pas de sonde.").foregroundStyle(.secondary)
                } else {
                    Picker("Port", selection: Binding(
                        get: { sonde.ports.first { $0.serie != nil && $0.serie == sonde.serie }?.chemin ?? "" },
                        set: { c in if let p = sonde.ports.first(where: { $0.chemin == c }) { sonde.choisir(p) } })) {
                        Text("—").tag("")
                        ForEach(sonde.ports) { p in
                            Text(verbatim: Self.libellePort(p, serieRetenue: sonde.serie, nom: sonde.nom)).tag(p.chemin)
                        }
                    }
                    LabeledContent("État", value: Self.texteEtatSonde(sonde.etat, nom: sonde.nomEtat))
                    if case .connectee(let b) = sonde.etat {
                        LabeledContent("Firmware", value: b.version)
                        let qr = b.qr.flatMap { $0.isEmpty ? nil : $0 }
                        let code = b.code.flatMap { $0.isEmpty ? nil : $0 }
                        if qr != nil || code != nil {
                            CodeMatterSonde(qr: qr, code: code, appairee: b.appairee)
                        }
                    }
                    if let e = sonde.etatSonde {
                        LabeledContent("Partition", value: e.partition ?? "—")
                        if e.suspendue {
                            Text("Sonde suspendue dans Maison (interrupteur « Sonde maillage » éteint) : pas de relevé.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    if let a = sonde.avancement, let debut = sonde.debutTournee {
                        TimelineView(.periodic(from: debut, by: 1)) { contexte in
                            LabeledContent("Tournée", value: TexteTournee.reglages(a, debut: debut, maintenant: contexte.date))
                        }
                    } else if let d = sonde.derniereTournee {
                        LabeledContent("Dernier relevé", value: d.formatted(date: .omitted, time: .standard))
                    }
                    if let e = sonde.erreurTournee {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }
                    if sonde.serie != nil {
                        Button("Oublier la sonde") { sonde.oublier() }
                    }
                    Text("Seul le port choisi est ouvert. Le pont Halo est aussi un ESP32-C6 : ne le choisissez pas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        // Etat de l'ouverture a la connexion relu a chaque ouverture (Reglages Systeme).
        .onAppear { ouverture.actualiser() }
    }

    /// Libelle d'un port dans le choix : la sonde retenue sous son nom seul ; tout autre port,
    /// ou la sonde retenue sans nom connu (firmware 1.0.0), sous son nom de port et son numero
    /// de serie USB (la MAC d'un C6), qui seul distingue la sonde du pont Halo avant la
    /// premiere connexion.
    static func libellePort(_ p: PortUSB, serieRetenue: String?, nom: String?) -> String {
        if let nom, let serie = p.serie, serie == serieRetenue { return nom }
        return p.libelle
    }

    /// Etat de la sonde, precede du nom de la sonde retenue quand il la concerne
    /// (« SONDE-01 · connectée ») ; seul pour un autre port choisi ou sans nom connu.
    static func texteEtatSonde(_ e: SondeMaillage.Etat, nom: String?) -> String {
        let texte = switch e {
        case .sansSonde: String(localized: "aucune sonde choisie")
        case .absente: String(localized: "absente (débranchée ?)")
        case .connexion: String(localized: "connexion…")
        case .connectee: String(localized: "connectée")
        case .refusee(let m): String(localized: "refusée : \(m)")
        case .erreur(let m): String(localized: "erreur : \(m)")
        }
        guard let nom else { return texte }
        return String(localized: "\(nom) · \(texte)")
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

/// Code Matter de la sonde (Reglages › Sonde), meme quand elle est dans Maison : le QR code,
/// agrandi sans lissage, noir sur blanc (marge blanche comprise, lisible en mode sombre), et le
/// code d'appairage mis en forme.
struct CodeMatterSonde: View {
    let qr: String?
    let code: String?
    let appairee: Bool
    /// QR code forme une fois par charge, et non a chaque rendu des Reglages.
    @State private var image: CGImage?

    var body: some View {
        HStack(spacing: 16) {
            if qr != nil {
                // Place reservee des la construction : la section ne saute pas quand l'image arrive.
                ZStack {
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.none)
                    }
                }
                .frame(width: 120, height: 120)
                .padding(8)
                .background(.white, in: .rect(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Code Matter de la sonde").font(.caption).foregroundStyle(.secondary)
                if let code {
                    Text(verbatim: CodeMatter.formater(code))
                        .font(.title3.monospacedDigit())
                        .textSelection(.enabled)
                }
                if !appairee {
                    Text("Dans Maison : + › Ajouter un accessoire › Plus d'options, puis ce code.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task(id: qr) { image = qr.flatMap(CodeMatter.imageQR) }
    }
}
