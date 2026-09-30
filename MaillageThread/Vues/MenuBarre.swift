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
    @Environment(NomsInternes.self) private var nomsMaison
    @Environment(SondeMaillage.self) private var sonde
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    /// Fenetre du menu, pour le fermer apres « Reglages… ».
    @State private var fenetreMenu = RefFenetre()

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
            // Actions : comme les articles d'un menu natif (texte en couleur primaire, taille standard,
            // surlignees au survol) ; la marge negative aligne leur texte sur le reste du menu.
            VStack(alignment: .leading, spacing: 0) {
                Button("Ouvrir le graphe") { ouvrir("graphe") }
                Button("Journal…") { ouvrir("journal") }
                if surveillance.mode == .direct {
                    // Une demande pendant un releve serait ignoree.
                    Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                        .disabled(nomsMaison.releveEnCours)
                    if let p = nomsMaison.probleme {
                        Text(p).font(.caption).foregroundStyle(.red).padding(.horizontal, 8)
                    }
                }
                Button("Réglages…") { ouvrirReglages() }
                Button("Quitter Maillage Thread") { NSApp.terminate(nil) }
            }
            .buttonStyle(ActionMenu())
            .padding(.horizontal, -8)
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
        .background(FenetreHote { fenetreMenu.fenetre = $0 })
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
        } else if let t = Self.ligneSonde(sonde.etat, nom: sonde.nomEtat, derniere: sonde.derniereTournee,
                                          avancement: sonde.avancement, maintenant: Date()) {
            Text(t).font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Ligne de la sonde, sous le nom donne (celui de la sonde retenue quand l'etat la concerne,
    /// `SondeMaillage.nomEtat`), sinon « Sonde » ; pendant une tournee, son etape et son
    /// compteur. Rien tant qu'aucune sonde n'est choisie.
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

    /// Le menu se ferme quand une autre fenetre de l'app prend la main : c'est le cas du graphe et
    /// du journal, pas des reglages, que `openSettings` montre sans leur donner la main (verifie
    /// avec Djoko le 30/09, dans les deux ordres). On ferme donc le menu nous-memes.
    private func ouvrirReglages() {
        openSettings()
        NSApp.activate()
        fenetreMenu.fenetre?.close()
    }
}

/// Fenetre du menu de la barre, retenue sans la garder en vie.
@MainActor
final class RefFenetre {
    weak var fenetre: NSWindow?
}

/// Donne la fenetre qui porte la vue, des qu'elle y est posee.
private struct FenetreHote: NSViewRepresentable {
    let surFenetre: (NSWindow?) -> Void

    func makeNSView(context: Context) -> Vue { Vue(surFenetre: surFenetre) }
    func updateNSView(_ nsView: Vue, context: Context) {}

    final class Vue: NSView {
        let surFenetre: (NSWindow?) -> Void

        init(surFenetre: @escaping (NSWindow?) -> Void) {
            self.surFenetre = surFenetre
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            surFenetre(window)
        }
    }
}

/// Action du menu de la barre, a la maniere d'un article de menu natif : texte en couleur
/// primaire et en taille standard, sur toute la largeur, surligne a la couleur d'accent au survol.
private struct ActionMenu: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LigneAction(configuration: configuration)
    }

    private struct LigneAction: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var active
        @State private var survol = false

        var body: some View {
            let surligne = survol && active
            configuration.label
                .font(.body)
                .foregroundStyle(surligne ? AnyShapeStyle(Color.white) : AnyShapeStyle(active ? .primary : .secondary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 5).fill(surligne ? Color.accentColor : .clear))
                .contentShape(Rectangle())
                .onHover { survol = $0 }
                .opacity(configuration.isPressed ? 0.85 : 1)
        }
    }
}
