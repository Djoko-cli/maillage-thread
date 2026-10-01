import AppKit
import MaillageCoeur
import SwiftUI

/// Fenetre de la vue par pieces (spec de la vue par pieces, sections 1 et 7) : la scene occupe toute
/// la fenetre ; la barre d'outils (avec 2D / 3D et « Rotation lente »), les bandeaux, la ligne de la
/// tournee et le fil flottent en haut ; la ligne de niveau, la legende et la fiche en bas. Elle reste
/// sombre, comme la maquette, meme quand le Mac est en clair (precision 15 du plan 4b).
struct FenetrePieces: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(NomsInternes.self) private var nomsMaison
    @Environment(SondeMaillage.self) private var sonde
    @Environment(\.accessibilityReduceMotion) private var reduire
    /// Le mode 2D ou 3D, garde d'un lancement a l'autre.
    @AppStorage(FenetrePieces.cleMode) private var troisD = false
    @State private var moteur: MoteurPieces
    @State private var piecesChoisies: PiecesChoisies
    @State private var aRenommer: NoeudChoisi?

    /// Preference du mode 2D ou 3D.
    static let cleMode = "vuePieces3D"
    /// Bord des elements poses sur la vue, et ecart entre eux (pt).
    static let bord: CGFloat = 16
    static let espacement: CGFloat = 10

    /// `fichierPlaces` : `positions-pieces.json` (`fichierPlaces(demo:sousTests:)`) ; `fichierPieces` :
    /// `pieces-routeurs.json` (`PiecesChoisies.fichier(demo:sousTests:)`) ; nil : ni lu ni ecrit.
    /// `--args -selection <id>` : fiche ouverte au lancement (captures d'ecran).
    init(fichierPlaces: URL?, fichierPieces: URL? = nil) {
        _moteur = State(initialValue: MoteurPieces(troisD: UserDefaults.standard.bool(forKey: Self.cleMode),
                                                   fichierPlaces: fichierPlaces,
                                                   selection: UserDefaults.standard.string(forKey: "selection")))
        _piecesChoisies = State(initialValue: PiecesChoisies(fichier: fichierPieces))
    }

    /// La fenetre reste sombre : barre, menus, fiche et feuilles en apparence sombre, quelle que soit
    /// celle du Mac.
    static func assombrir(_ fenetre: NSWindow?) {
        fenetre?.appearance = NSAppearance(named: .darkAqua)
    }

    /// Places des pieces, a cote des identites des routeurs ; ni en demo ni sous les tests.
    static func fichierPlaces(demo: Bool, sousTests: Bool) -> URL? {
        demo || sousTests ? nil : Surveillance.dossierParDefaut.appendingPathComponent("positions-pieces.json")
    }

    /// Redessin de la fenetre au debut de chaque minute. « Ancien » (6 min) et « perime » (15 min)
    /// ne dependent que de l'heure (`Surveillance.maintenant`), que rien n'observe : quand la sonde
    /// se tait, aucun evenement ne redessine la vue ; l'etat parait avec une minute de retard au
    /// plus, et le redessin n'a lieu que dans cette fenetre, tant qu'elle est ouverte.
    static let horloge = EveryMinuteTimelineSchedule()

    /// Marge du haut de la vue d'ensemble (pt) : la barre d'outils et le fil, puis une ligne de 40 pt
    /// pour le bandeau d'un reseau scinde, une pour la tournee tant qu'une sonde est retenue (rien ne
    /// bouge au debut ni a la fin d'une tournee), et 44 pt pour le bandeau d'une maison sans pieces.
    static func margeHaut(scinde: Bool, sondeRetenue: Bool, sansPieces: Bool) -> CGFloat {
        72 + (scinde ? 40 : 0) + (sondeRetenue ? 40 : 0) + (sansPieces ? 44 : 0)
    }

    /// Marge du bas de la vue d'ensemble (pt) : la legende et la ligne de niveau (elles debordent un
    /// peu sur la vue, comme la legende du graphe d'avant), ou la fiche ouverte, plus haute avec les
    /// courbes de l'historique (plan 3b) : la vue ne bouge pas d'un noeud a l'autre.
    static func margeBas(fiche: Bool, courbes: Bool) -> CGFloat {
        guard fiche else { return 30 }
        return courbes ? 360 : 190
    }

    var body: some View {
        let palette = Palette(sombre: true)
        // Redessin chaque minute (`horloge`) : la scene et la fiche lisent l'heure, que rien n'observe. La
        // fiche la recoit (`instant`) : sinon SwiftUI la sauterait, ses entrees n'ayant pas change.
        TimelineView(Self.horloge) { contexte in
            let entree = surveillance.reseau.map {
                EntreeScene(surveillance: surveillance, reseau: $0, places: moteur.places, choix: piecesChoisies.choix)
            }
            ZStack {
                RadialGradient(gradient: palette.fond, center: UnitPoint(x: 0.3, y: 0.35), startRadius: 0, endRadius: 900)
                    .ignoresSafeArea()
                if let r = surveillance.reseau, let entree {
                    VuePieces(moteur: moteur, entree: entree, palette: palette,
                              marges: (Self.margeHaut(scinde: r.estScinde, sondeRetenue: sonde.serie != nil,
                                                      sansPieces: entree.scene.sansPiecesMaison),
                                       Self.margeBas(fiche: moteur.selection != nil,
                                                     courbes: FicheNoeud.courbesVisibles(dans: surveillance))))
                    if !moteur.pret {
                        ProgressView().controlSize(.small)
                    }
                } else {
                    EtatVide()
                }
                VStack(alignment: .leading, spacing: Self.espacement) {
                    EnTetePieces(moteur: moteur, troisD: $troisD, sansPieces: entree?.scene.sansPiecesMaison == true)
                        .frame(maxWidth: .infinity)
                        .obstacle("en-tete", moteur)
                    FilPieces(moteur: moteur)
                        .obstacle("fil", moteur)
                    Spacer()
                    if moteur.selection == nil {
                        HStack(alignment: .center, spacing: 12) {
                            if let r = surveillance.reseau {
                                LegendeLiens(sonde: surveillance.maillageAffiche(pour: r) != nil,
                                             ancien: surveillance.maillageAncien)
                                    .obstacle("legende", moteur)
                            }
                            LigneNiveauVue(ligne: moteur.ligneNiveau)
                                .obstacle("niveau", moteur)
                        }
                    } else {
                        LigneNiveauVue(ligne: moteur.ligneNiveau)
                            .obstacle("niveau", moteur)
                    }
                    if let selection = moteur.selection {
                        FicheNoeud(id: selection, instant: surveillance.maintenant(a: contexte.date),
                                   aRenommer: $aRenommer, choisir: { moteur.selection = $0 }) {
                            moteur.selection = nil
                        }
                        .obstacle("fiche", moteur)
                    }
                }
                .padding(Self.bord)
            }
            .coordinateSpace(.named(VuePieces.espace))
        }
        .frame(minWidth: 820, minHeight: 560)
        .environment(piecesChoisies)
        .environment(\.colorScheme, .dark)
        .background(SondeFenetre { Self.assombrir($0) })
        .sheet(item: $aRenommer) { FeuilleRenommer(id: $0.id) }
        .onChange(of: reduire, initial: true) { _, r in moteur.reduire = r }
        .task {
            // Batteries de Maison a jour tant que la vue est ouverte.
            while !Task.isCancelled {
                nomsMaison.rafraichirSiAncien()
                try? await Task.sleep(for: .seconds(3600))
            }
        }
        .fenetreDeLApp()
    }
}

extension View {
    /// Cadre de cet element de l'interface, dans l'espace de la vue : les noms de la scene l'evitent ;
    /// retire quand l'element disparait.
    func obstacle(_ cle: String, _ moteur: MoteurPieces) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(VuePieces.espace)) } action: { r in
            moteur.cadresInterface[cle] = r
            moteur.reveiller()
        }
        .onDisappear { moteur.cadresInterface[cle] = nil }
    }
}

/// La scene : un `Canvas` redessine a chaque image pendant un mouvement (`MoteurPieces.anime`), plus
/// du tout au repos ; gestes, molette, clics droits.
struct VuePieces: View {
    let moteur: MoteurPieces
    let entree: EntreeScene
    let palette: Palette
    let marges: (haut: CGFloat, bas: CGFloat)
    @Environment(\.displayScale) private var echelle
    /// Un glisser est en cours. SwiftUI le remet a faux a la fin du geste, meme annule (sans `onEnded`) :
    /// le moteur clot alors un geste qui serait reste ouvert.
    @GestureState private var glisse = false

    /// Espace de coordonnees de la vue et de ce qui est pose dessus.
    nonisolated static let espace = "pieces"

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !moteur.anime)) { contexte in
            Canvas { ctx, taille in
                _ = contexte.date
                moteur.marges = marges
                moteur.image(&ctx, taille: taille, echelle: echelle, palette: palette)
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let p): moteur.survoler(p)
            case .ended: moteur.survoler(nil)
            }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .updating($glisse) { _, g, _ in g = true }
            .onChanged { moteur.glisser($0.location, depart: $0.startLocation) }
            .onEnded { moteur.relacher($0.location) })
        .simultaneousGesture(MagnifyGesture()
            .onChanged { moteur.pincer($0.magnification, en: $0.startLocation) }
            .onEnded { _ in moteur.finPincement() })
        .contextMenu { MenuPieces(moteur: moteur) }
        .background(SondeFenetre { moteur.fenetre = $0 })
        .onChange(of: glisse) { _, g in
            if !g { moteur.abandonnerGeste() }
        }
        .onChange(of: entree, initial: true) { _, e in moteur.recevoir(e) }
        .onAppear { moteur.ecouter() }
        .onDisappear {
            moteur.arreterEcoute()
            // La vue quitte la fenetre pendant un geste : ni `onEnded`, ni peut-etre le changement ci-dessus.
            moteur.abandonnerGeste()
        }
    }
}

/// Clics droits : sur un nom d'etage, « Monter d'un etage » et « Descendre d'un etage » ; sur le fond,
/// « Replacer les pieces automatiquement ».
struct MenuPieces: View {
    let moteur: MoteurPieces

    var body: some View {
        switch moteur.cibleMenu {
        case .etage(let i):
            Button("Monter d'un étage") { moteur.deplacerEtage(i, de: 1) }
                .disabled(!moteur.peutDeplacerEtage(i, de: 1))
            Button("Descendre d'un étage") { moteur.deplacerEtage(i, de: -1) }
                .disabled(!moteur.peutDeplacerEtage(i, de: -1))
        case .fond:
            Button("Replacer les pièces automatiquement") { moteur.replacerPieces() }
        case .aucune:
            EmptyView()
        }
    }
}

/// Haut de la fenetre, pose sur la vue : barre d'outils et commandes de la vue, bandeau d'un reseau
/// scinde, ligne de la tournee (sa place est gardee tant qu'une sonde est retenue :
/// `FenetrePieces.margeHaut`), bandeau d'une maison sans pieces.
struct EnTetePieces: View {
    @Environment(Surveillance.self) private var surveillance
    let moteur: MoteurPieces
    @Binding var troisD: Bool
    /// Maison n'a encore aucune piece : le bandeau du passeur.
    var sansPieces = false

    var body: some View {
        VStack(spacing: FenetrePieces.espacement) {
            HStack(spacing: 6) {
                BarreOutils()
                CommandesVue(moteur: moteur, troisD: $troisD)
            }
            if let r = surveillance.reseau, r.estScinde {
                BandeauScission(reseau: r)
            }
            LigneTournee()
            if sansPieces {
                BandeauSansPieces()
            }
        }
    }
}

/// Interrupteur 2D / 3D, puis « Rotation lente », en 3D seulement (coupee par « Reduire les
/// animations »).
struct CommandesVue: View {
    let moteur: MoteurPieces
    @Binding var troisD: Bool

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 6) {
                Picker("Vue", selection: Binding(get: { moteur.troisD }, set: { v in
                    moteur.basculer(troisD: v)
                    troisD = v
                })) {
                    Text("2D").tag(false)
                    Text("3D").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                if moteur.troisD {
                    Toggle("Rotation lente", isOn: Binding(get: { moteur.rotation && !moteur.reduire },
                                                           set: { _ in moteur.basculerRotation() }))
                        .toggleStyle(.button)
                        .buttonStyle(.glass)
                        .disabled(moteur.reduire)
                        .help(moteur.reduire ? String(localized: "Coupée par « Réduire les animations »") : "")
                }
            }
        }
    }
}

/// Bandeau d'une maison dont Maison n'a encore donne aucune piece (spec, section 2.3).
struct BandeauSansPieces: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(NomsInternes.self) private var nomsMaison

    var body: some View {
        HStack(spacing: 10) {
            Label("Pas encore de pièces de Maison : lance le passeur", systemImage: "house")
            Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                .buttonStyle(.glass)
                .disabled(surveillance.mode == .demo)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Fil, en haut a gauche : « Maison », puis « › Salon » en piece isolee ; « Maison » y ramene.
/// `capture` : sans bouton (une capture ne dessine pas les controles d'AppKit).
struct FilPieces: View {
    let moteur: MoteurPieces
    var capture = false

    var body: some View {
        HStack(spacing: 4) {
            if let piece = moteur.isolee {
                if capture {
                    Text("Maison").foregroundStyle(.link)
                } else {
                    Button("Maison") { moteur.sortir() }
                        .buttonStyle(.link)
                }
                Text(verbatim: "› " + piece)
            } else {
                Text("Maison")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.primary.opacity(0.9))
    }
}

/// Ligne de niveau, en bas a gauche : pieces seules, routeurs, noms masques, piece isolee.
struct LigneNiveauVue: View {
    let ligne: LigneNiveau

    var body: some View {
        Text(Self.texte(ligne))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    static func texte(_ l: LigneNiveau) -> String {
        switch l {
        case .isolee(let nom):
            String(localized: "Pièce isolée : \(nom) · clic sur une autre pièce pour y aller, clic à côté ou Échap pour revenir")
        case .pieces: String(localized: "Vue d'ensemble : les pièces")
        case .routeurs: String(localized: "Mi-distance : les pièces et les routeurs")
        case .masques(1): String(localized: "1 nom masqué faute de place : rapprochez-vous (molette)")
        case .masques(let n): String(localized: "\(n) noms masqués faute de place : rapprochez-vous (molette)")
        case .lisibles: String(localized: "Tous les noms sont lisibles")
        }
    }
}

/// Rapporte la fenetre qui porte la vue (la molette et Echap ne valent que pour elle).
struct SondeFenetre: NSViewRepresentable {
    let rapporter: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView { Sonde(rapporter) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Sonde: NSView {
        let rapporter: (NSWindow?) -> Void

        init(_ rapporter: @escaping (NSWindow?) -> Void) {
            self.rapporter = rapporter
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            rapporter(window)
        }
    }
}
