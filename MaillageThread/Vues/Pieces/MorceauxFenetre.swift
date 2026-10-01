import MaillageCoeur
import SwiftUI

// Morceaux de la fenetre de la vue par pieces, repris de celle du graphe : barre d'outils, ligne de
// la tournee, bandeau de scission, legende des liens, ecran d'attente, appareils IP, « Renommer… ».

/// Noeud choisi pour une feuille (surnom).
struct NoeudChoisi: Identifiable {
    let id: String
}

/// Barre d'outils flottante : reseau, appareils IP, journal, rafraichir.
struct BarreOutils: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(SondeMaillage.self) private var sonde
    @Environment(NomsInternes.self) private var nomsMaison
    @Environment(\.openWindow) private var openWindow
    @State private var appareilsIP = false

    /// Rafraichir lance aussi le passeur des noms de Maison, en mode direct seulement (sauf
    /// pendant un releve, qui ignore la demande).
    static func lancePasseur(mode: Surveillance.Mode) -> Bool {
        mode == .direct
    }

    /// Aide du bouton rafraichir : ce qu'il lancera vraiment. Le reseau toujours ; une tournee
    /// si la sonde est connectee et libre (`SondeMaillage.tourneeAuRafraichir`) ; les noms de
    /// Maison si le passeur sera lance (`lancePasseur`).
    static func aideRafraichir(tournee: Bool, passeur: Bool) -> String {
        switch (tournee, passeur) {
        case (true, true): String(localized: "Rafraîchir : réseau, tournée de la sonde et noms de Maison")
        case (true, false): String(localized: "Rafraîchir : réseau et tournée de la sonde")
        case (false, true): String(localized: "Rafraîchir : réseau et noms de Maison")
        case (false, false): String(localized: "Rafraîchir : réseau")
        }
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
                    if Self.lancePasseur(mode: surveillance.mode) {
                        nomsMaison.lancerPasseur()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .help(Self.aideRafraichir(tournee: sonde.tourneeAuRafraichir,
                                          passeur: Self.lancePasseur(mode: surveillance.mode)))
            }
        }
    }
}

/// Ligne de la tournee en cours, centree sous la barre d'outils (et le bandeau d'un reseau
/// scinde) : la barre garde sa largeur, son bouton rafraichir ne bouge pas sous le pointeur.
/// Rien hors tournee. Vue a part : seule elle se redessine a chaque pas de la tournee, pas la
/// fenetre de la vue.
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
            // Largeur de la plus longue etape, compteur et duree compris : la capsule ne change
            // pas de taille d'une etape a l'autre (texte cale a gauche).
            ZStack(alignment: .leading) {
                ForEach(AvancementTournee.Etape.allCases, id: \.self) { e in
                    Text(TexteTournee.gabaritBarre(e)).hidden()
                }
                TimelineView(.periodic(from: debut, by: 1)) { contexte in
                    Text(TexteTournee.barre(avancement, debut: debut, maintenant: contexte.date))
                }
            }
            .monospacedDigit()
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

/// Legende des liens (en bas a gauche, cachee sous une fiche) : avec la sonde,
/// traits pleins (lien radio, colore par la qualite) et pointilles (rattachement
/// suppose) ; « ancien » si la sonde ne repond plus.
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
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
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
