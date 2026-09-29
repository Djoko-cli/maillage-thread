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
    @Environment(DossierNoms.self) private var nomsMaison
    @Environment(\.colorScheme) private var apparence
    /// `--args -selection <id>` : fiche ouverte au lancement (captures d'ecran).
    @State private var selection: String? = UserDefaults.standard.string(forKey: "selection")
    @State private var survol: String?
    @State private var zoom: CGFloat = 1
    @State private var zoomEnCours: CGFloat = 1
    @State private var decalage: CGSize = .zero
    @State private var decalageEnCours: CGSize = .zero
    @State private var aRenommer: NoeudChoisi?
    @State private var memoire = MemoirePlacement()

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
                LigneTournee()
                if let r = surveillance.reseau, r.estScinde {
                    BandeauScission(reseau: r)
                }
                Spacer()
                if let r = surveillance.reseau, selection == nil {
                    LegendeLiens(sonde: surveillance.maillageAffiche(pour: r) != nil, ancien: surveillance.maillageAncien)
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
        .task {
            // Batteries de Maison a jour tant que le graphe est ouvert.
            while !Task.isCancelled {
                nomsMaison.rafraichirSiAncien()
                try? await Task.sleep(for: .seconds(3600))
            }
        }
        .fenetreDeLApp()
    }

    private func graphe(_ r: Reseau, _ palette: Palette) -> some View {
        let affiches = surveillance.appareilsAffiches(pour: r)
        let maillage = surveillance.maillageAffiche(pour: r)
        let disposition = Disposition(reseau: r, appareils: affiches, maillage: maillage)
        let parId = Dictionary(affiches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let nomsRouteurs = Dictionary(r.routeurs.map { ($0.instance, surveillance.nom($0)) }, uniquingKeysWith: { a, _ in a })
        let libelles = GrapheCanvas.libelles(disposition: disposition, reseau: r, appareils: parId,
                                             nomsRouteurs: nomsRouteurs, maillage: maillage)
        return GeometryReader { geo in
            let projection = Projection(cadre: disposition.cadre, taille: geo.size,
                                        marges: (haut: r.estScinde ? 110 : 70, bas: selection == nil ? 30 : 190, cotes: 60),
                                        zoom: zoom * zoomEnCours,
                                        decalage: CGSize(width: decalage.width + decalageEnCours.width,
                                                         height: decalage.height + decalageEnCours.height))
            // Libelles places pour le dessin et le clic ; recalcules seulement si la
            // disposition, l'echelle ou les noms changent (le decalage les deplace).
            let placement = memoire.placement(disposition, libelles: libelles, echelle: projection.echelle)
                .decale(projection.origine)
            GrapheCanvas(disposition: disposition, appareils: parId, nomsRouteurs: nomsRouteurs, maillage: maillage,
                         libelles: libelles, placement: placement, projection: projection, selection: selection,
                         survol: survol, palette: palette)
                .contentShape(Rectangle())
                // Clic, double clic et survol : le point (8 pt autour) ou tout le libelle.
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): survol = placement.cible(a: p)
                    case .ended: survol = nil
                    }
                }
                .onTapGesture(count: 2) { p in
                    selection = placement.cible(a: p)
                    zoom = 1
                    decalage = .zero
                }
                .simultaneousGesture(SpatialTapGesture().onEnded { v in
                    selection = placement.cible(a: v.location)
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
    @Environment(SondeMaillage.self) private var sonde
    @Environment(DossierNoms.self) private var nomsMaison
    @Environment(\.openWindow) private var openWindow
    @State private var appareilsIP = false

    /// Rafraichir lance aussi le passeur des noms de Maison, en mode direct, et seulement si un
    /// dossier des noms est choisi : sans dossier, le passeur passerait au premier plan a chaque
    /// clic pour en demander un (« Rafraichir depuis Maison », lui, le demande s'il manque).
    static func lancePasseur(mode: Surveillance.Mode, dossierChoisi: Bool) -> Bool {
        mode == .direct && dossierChoisi
    }

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
                // Pendant une tournee : le reseau et les noms, sans seconde tournee.
                Button {
                    surveillance.rafraichir()
                    sonde.rafraichir()
                    if Self.lancePasseur(mode: surveillance.mode, dossierChoisi: nomsMaison.dossier != nil) {
                        nomsMaison.lancerPasseur()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .help("Rafraîchir : réseau, tournée de la sonde et noms de Maison")
            }
        }
    }
}

/// Ligne de la tournee en cours, centree sous la barre d'outils : la barre garde sa largeur,
/// son bouton rafraichir ne bouge pas sous le pointeur. Rien hors tournee. Vue a part : seule
/// elle se redessine a chaque pas de la tournee, pas la fenetre du graphe.
struct LigneTournee: View {
    @Environment(SondeMaillage.self) private var sonde

    var body: some View {
        if let a = sonde.avancement, let debut = sonde.debutTournee {
            IndicateurTournee(avancement: a, debut: debut)
        }
    }
}

/// Tournee de la sonde en cours : un petit indicateur de progression et « Balayage des
/// routeurs muets · 24/48 · 0:42 », la duree a jour chaque seconde.
struct IndicateurTournee: View {
    let avancement: AvancementTournee
    let debut: Date

    var body: some View {
        HStack(spacing: 8) {
            if avancement.total > 0 {
                ProgressView(value: Double(avancement.fait), total: Double(avancement.total))
                    .progressViewStyle(.circular)
            } else {
                ProgressView()
            }
            TimelineView(.periodic(from: debut, by: 1)) { contexte in
                Text(TexteTournee.barre(avancement, debut: debut, maintenant: contexte.date))
                    .monospacedDigit()
            }
        }
        .controlSize(.small)
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Bandeau ambre d'un reseau scinde : depuis quand (ou quand ce fut constate : au
/// lancement, a la decouverte ou au retour du reseau), et qui est a part.
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

/// Legende des liens du graphe (en bas a gauche, cachee sous une fiche) : avec
/// la sonde, traits pleins (lien radio, colore par la qualite) et pointilles
/// (rattachement suppose) ; « ancien » si la sonde ne repond plus.
struct LegendeLiens: View {
    var sonde = false
    var ancien = false

    var body: some View {
        HStack(spacing: 8) {
            if sonde {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 1))
                    p.addLine(to: CGPoint(x: 22, y: 1))
                }
                .stroke(Palette(sombre: true).lienSonde(3),
                        style: StrokeStyle(lineWidth: GrapheCanvas.epaisseurLienSonde(.radio, qualite: 3), lineCap: .round))
                .frame(width: 22, height: 2)
                .accessibilityHidden(true)
                Text("lien radio (qualité)")
            }
            Path { p in
                p.move(to: CGPoint(x: 0, y: 1))
                p.addLine(to: CGPoint(x: 22, y: 1))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            .frame(width: 22, height: 2)
            .accessibilityHidden(true)
            Text(sonde ? "rattachement supposé" : "rattachement, pas un lien radio")
            if ancien {
                Text("· relevé de la sonde ancien").foregroundStyle(.orange)
            }
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
