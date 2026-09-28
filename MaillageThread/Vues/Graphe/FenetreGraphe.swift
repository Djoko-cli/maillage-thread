import MaillageCoeur
import SwiftUI

/// Noeud choisi pour une feuille (surnom).
struct NoeudChoisi: Identifiable {
    let id: String
}

/// Fenetre du graphe : le graphe occupe toute la fenetre ; barre d'outils,
/// bandeau d'alerte, legende des pointilles et fiche flottent par-dessus, en verre.
struct FenetreGraphe: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.colorScheme) private var apparence
    /// `--args -selection <id>` : fiche ouverte au lancement (captures d'ecran).
    @State private var selection: String? = UserDefaults.standard.string(forKey: "selection")
    @State private var survol: String?
    @State private var zoom: CGFloat = 1
    @State private var zoomEnCours: CGFloat = 1
    @State private var decalage: CGSize = .zero
    @State private var decalageEnCours: CGSize = .zero
    @State private var aRenommer: NoeudChoisi?

    var body: some View {
        let palette = Palette(sombre: apparence == .dark)
        ZStack {
            RadialGradient(gradient: palette.fond, center: UnitPoint(x: 0.3, y: 0.35), startRadius: 0, endRadius: 900)
                .ignoresSafeArea()
            if let r = surveillance.reseau {
                graphe(r, palette)
            } else {
                EtatVide()
            }
            VStack(spacing: 10) {
                BarreOutils()
                if let r = surveillance.reseau, r.estScinde {
                    BandeauScission(reseau: r)
                }
                Spacer()
                if surveillance.reseau != nil && selection == nil {
                    LegendeLiens()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let selection {
                    FicheNoeud(id: selection, aRenommer: $aRenommer) { self.selection = nil }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 820, minHeight: 560)
        .sheet(item: $aRenommer) { FeuilleRenommer(id: $0.id) }
        .fenetreDeLApp()
    }

    private func graphe(_ r: Reseau, _ palette: Palette) -> some View {
        let affiches = surveillance.appareilsAffiches(pour: r)
        let disposition = Disposition(reseau: r, appareils: affiches)
        let parId = Dictionary(affiches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let nomsRouteurs = Dictionary(r.routeurs.map { ($0.instance, surveillance.nom($0)) }, uniquingKeysWith: { a, _ in a })
        return GeometryReader { geo in
            let projection = Projection(cadre: disposition.cadre, taille: geo.size,
                                        marges: (haut: r.estScinde ? 110 : 70, bas: selection == nil ? 30 : 190, cotes: 60),
                                        zoom: zoom * zoomEnCours,
                                        decalage: CGSize(width: decalage.width + decalageEnCours.width,
                                                         height: decalage.height + decalageEnCours.height))
            GrapheCanvas(disposition: disposition, reseau: r, appareils: parId, nomsRouteurs: nomsRouteurs,
                         projection: projection, selection: selection, survol: survol, palette: palette)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): survol = disposition.noeud(a: projection.plan(p))?.id
                    case .ended: survol = nil
                    }
                }
                .onTapGesture(count: 2) {
                    zoom = 1
                    decalage = .zero
                }
                .simultaneousGesture(SpatialTapGesture().onEnded { v in
                    selection = disposition.noeud(a: projection.plan(v.location))?.id
                })
                .gesture(MagnifyGesture()
                    .onChanged { zoomEnCours = $0.magnification }
                    .onEnded { v in
                        zoom = min(max(zoom * v.magnification, 0.4), 5)
                        zoomEnCours = 1
                    })
                .simultaneousGesture(DragGesture(minimumDistance: 4)
                    .onChanged { decalageEnCours = $0.translation }
                    .onEnded { v in
                        decalage.width += v.translation.width
                        decalage.height += v.translation.height
                        decalageEnCours = .zero
                    })
        }
    }
}

/// Barre d'outils flottante : reseau, appareils IP, journal, rafraichir.
struct BarreOutils: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.openWindow) private var openWindow
    @State private var appareilsIP = false

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 6) {
                Menu {
                    ForEach(surveillance.instantane?.reseaux ?? []) { r in
                        Button(r.nom) { surveillance.reseauChoisi = r.id }
                    }
                } label: {
                    Text(surveillance.reseau?.nom ?? String(localized: "Aucun réseau Thread"))
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .fixedSize()
                Button {
                    appareilsIP = true
                } label: {
                    Text("Appareils IP · \(surveillance.instantane?.appareilsIP.count ?? 0)")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $appareilsIP) { ListeAppareilsIP() }
                Button("Journal") {
                    openWindow(id: "journal")
                }
                .buttonStyle(.glass)
                Button {
                    surveillance.rafraichir()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .help("Rafraîchir")
            }
        }
    }
}

/// Bandeau ambre d'un reseau scinde : depuis quand (ou constate au lancement), et qui est a part.
struct BandeauScission: View {
    @Environment(Surveillance.self) private var surveillance
    let reseau: Reseau

    var body: some View {
        Label(texte, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(.orange.opacity(0.35)), in: .capsule)
    }

    private var texte: String {
        let n = reseau.partitions.count
        let aPart = reseau.partitions.dropFirst().flatMap(\.routeurs).map { surveillance.nom($0) }.joined(separator: ", ")
        guard let e = surveillance.derniereScission(reseau) else {
            return String(localized: "Réseau scindé en \(n) partitions · à part : \(aPart)")
        }
        let quand = e.date.formatted(date: .abbreviated, time: .shortened)
        if e.constate {
            return String(localized: "Réseau scindé en \(n) partitions, constaté le \(quand) · à part : \(aPart)")
        }
        return String(localized: "Réseau scindé en \(n) partitions depuis le \(quand) · à part : \(aPart)")
    }
}

/// Legende des pointilles du graphe (en bas a gauche, cachee sous une fiche).
struct LegendeLiens: View {
    var body: some View {
        HStack(spacing: 8) {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 1))
                p.addLine(to: CGPoint(x: 22, y: 1))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            .frame(width: 22, height: 2)
            .accessibilityHidden(true)
            Text("rattachement, pas un lien radio")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Ecran d'attente ou d'erreur, quand il n'y a pas de reseau a dessiner.
struct EtatVide: View {
    @Environment(Surveillance.self) private var surveillance

    var body: some View {
        if surveillance.etatEcoute == .reseauLocalRefuse {
            ContentUnavailableView {
                Label("Accès au réseau local refusé", systemImage: "network.slash")
            } description: {
                Text("Autorisez Maillage Thread dans Réglages Système › Confidentialité et sécurité › Réseau local.")
            } actions: {
                Button("Ouvrir les Réglages Système") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else if surveillance.instantane != nil {
            ContentUnavailableView("Aucun réseau Thread visible sur ce réseau local",
                                   systemImage: "point.3.connected.trianglepath.dotted")
        } else {
            ProgressView("Écoute du réseau local…")
        }
    }
}

/// Appareils du reseau local, hors Thread.
struct ListeAppareilsIP: View {
    @Environment(Surveillance.self) private var surveillance

    var body: some View {
        let appareils = surveillance.instantane?.appareilsIP ?? []
        VStack(alignment: .leading, spacing: 10) {
            Text("Appareils du réseau local (hors Thread)").font(.headline)
            if appareils.isEmpty {
                Text("Aucun").foregroundStyle(.secondary)
            }
            ForEach(appareils) { a in
                VStack(alignment: .leading, spacing: 2) {
                    Text(surveillance.nom(a))
                    Text((a.adresses.map(\.description) + a.adressesIPv4).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .frame(width: 380, alignment: .leading)
    }
}

/// Surnom d'un noeud : reste sur ce Mac, passe avant le nom de Maison.
struct FeuilleRenommer: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.dismiss) private var fermer
    let id: String
    @State private var texte = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Renommer « \(id) »").font(.headline)
            TextField("Surnom", text: $texte)
            Text("Le surnom reste sur ce Mac et passe avant le nom de Maison.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Retirer le surnom") {
                    surveillance.renommer(id, en: nil)
                    fermer()
                }
                Spacer()
                Button("Annuler", role: .cancel) { fermer() }
                Button("Enregistrer") {
                    surveillance.renommer(id, en: texte)
                    fermer()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear { texte = surveillance.noms.surnoms[id] ?? "" }
    }
}
