import AppKit
import MaillageCoeur
import SwiftUI

/// Icone de la barre des menus : orange quand il y a une alerte. Ouvre le
/// graphe au lancement quand on le lui demande (mode demo, premier lancement).
struct IconeBarre: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.openWindow) private var openWindow
    let ouvrirGraphe: Bool
    private static var grapheOuvert = false

    var body: some View {
        Image(nsImage: Self.image(alerte: surveillance.alerte))
            .task {
                guard ouvrirGraphe, !Self.grapheOuvert else { return }
                Self.grapheOuvert = true
                openWindow(id: "graphe")
                NSApp.activate()
            }
    }

    static func image(alerte: Bool) -> NSImage {
        let base = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted",
                           accessibilityDescription: "Maillage Thread") ?? NSImage()
        guard alerte, let orange = base.withSymbolConfiguration(.init(paletteColors: [.systemOrange])) else {
            base.isTemplate = true
            return base
        }
        orange.isTemplate = false
        return orange
    }
}

/// Contenu de la barre des menus : etat d'un coup d'oeil, 3 derniers
/// evenements, et les actions.
struct MenuBarre: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(OuvertureSession.self) private var ouverture
    @Environment(DossierNoms.self) private var nomsMaison
    @Environment(SondeMaillage.self) private var sonde
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            entete
            if surveillance.etatEcoute == .reseauLocalRefuse {
                Label("Accès au réseau local refusé", systemImage: "network.slash")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            Divider()
            ForEach(surveillance.lignesJournal.prefix(3)) { l in
                VStack(alignment: .leading, spacing: 1) {
                    Text(TexteEvenement.titre(l)).font(.callout).lineLimit(2)
                    Text(l.evenements.first.map(TexteEvenement.quand) ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            Group {
                Button("Ouvrir le graphe") { ouvrir("graphe") }
                Button("Journal…") { ouvrir("journal") }
                if surveillance.mode == .direct {
                    Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                    if let p = nomsMaison.probleme {
                        Text(p).font(.caption).foregroundStyle(.red)
                    }
                }
                Toggle("Ouvrir à la connexion", isOn: Binding(get: { ouverture.active }, set: { ouverture.basculer($0) }))
                    .toggleStyle(.checkbox)
                if ouverture.approbationRequise {
                    Button("Approuver dans Réglages Système…") { ouverture.ouvrirReglagesSysteme() }
                }
                Button("Réglages…") {
                    NSApp.activate()
                    openSettings()
                }
                Button("Quitter Maillage Thread") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
        // Etat de l'ouverture a la connexion relu a chaque ouverture du menu (Reglages Systeme).
        .onAppear { ouverture.actualiser() }
    }

    @ViewBuilder
    private var entete: some View {
        let alerte = surveillance.alerte
        HStack(spacing: 8) {
            if muet != nil {
                Image(systemName: "wifi.slash").foregroundStyle(.secondary)
            } else {
                Image(systemName: alerte ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(alerte ? .orange : .green)
            }
            Text(titre).font(.headline)
        }
        if let r = surveillance.resume {
            Text("\(r.nom) · partitions : \(r.partitions)").font(.caption).foregroundStyle(.secondary)
            Text("Routeurs : \(r.routeurs) · appareils : \(r.appareils) · injoignables : \(r.injoignables)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if surveillance.mode == .demo {
            Text("Mode démo : panne du 27/09 rejouée").font(.caption).foregroundStyle(.secondary)
        } else if let t = Self.ligneSonde(sonde.etat, nom: sonde.nom, derniere: sonde.derniereTournee,
                                          avancement: sonde.avancement, maintenant: Date()) {
            Text(t).font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Ligne de la sonde, sous son nom (« Sonde » tant qu'il n'est pas connu) ; pendant une
    /// tournee, son etape et son compteur. Rien tant qu'aucune sonde n'est choisie.
    static func ligneSonde(_ e: SondeMaillage.Etat, nom: String?, derniere: Date?, avancement: AvancementTournee?,
                           maintenant: Date) -> String? {
        let n = SondeMaillage.nomAffiche(nom)
        switch e {
        case .sansSonde: return nil
        case .absente: return String(localized: "\(n) : absente")
        case .connexion: return String(localized: "\(n) : connexion…")
        case .connectee:
            if let avancement { return TexteTournee.menu(avancement, nom: n) }
            guard let d = derniere else { return String(localized: "\(n) : connectée") }
            return String(localized: "\(n) : connectée · relevé \(FicheNoeud.relatif(d, maintenant))")
        case .refusee, .erreur: return String(localized: "\(n) : erreur (voir les Réglages)")
        }
    }

    /// Le Mac n'entend plus rien depuis cette date ; le resume montre le dernier etat connu.
    private var muet: Date? {
        surveillance.instantane == nil ? nil : surveillance.rienVuDepuis
    }

    private var titre: String {
        if surveillance.instantane == nil { return String(localized: "Écoute du réseau local…") }
        if let d = muet { return String(localized: "Rien de visible sur le réseau local depuis \(TexteEvenement.heure(d))") }
        guard let r = surveillance.reseau else { return String(localized: "Aucun réseau Thread visible") }
        if r.estScinde { return String(localized: "Réseau scindé") }
        return surveillance.alerte ? String(localized: "Alerte dans l'heure") : String(localized: "Réseau Thread normal")
    }

    private func ouvrir(_ id: String) {
        openWindow(id: id)
        NSApp.activate()
    }
}
