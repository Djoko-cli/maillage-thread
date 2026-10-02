import AppKit
import MaillageCoeur
import SwiftUI

/// Fenetre de la vue par pieces (spec de la vue par pieces, sections 1 et 7 ; polissage B, section 1) :
/// sans barre de titre (le style de sa scene, `.hiddenTitleBar`, dans `MaillageThreadApp`), la scene occupe
/// toute la fenetre, jusque sous ses trois boutons ; en haut, les deux capsules du bandeau, la bande qui
/// deplace la fenetre, la ligne de la tournee, les bandeaux et le fil (`HautPieces`) ; en bas, la pile : la
/// legende et la ligne de niveau, puis la fiche. Elle reste sombre, comme la maquette, meme quand le Mac est en
/// clair (precision 15 du plan 4b).
struct FenetrePieces: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(NomsInternes.self) private var nomsMaison
    @Environment(\.accessibilityReduceMotion) private var reduire
    /// Le mode 2D ou 3D, garde d'un lancement a l'autre.
    @AppStorage(FenetrePieces.cleMode) private var troisD = false
    @State private var moteur: MoteurPieces
    @State private var piecesChoisies: PiecesChoisies
    @State private var aRenommer: NoeudChoisi?
    /// Les trois boutons de la fenetre, lus sur elle : la capsule de gauche commence apres eux.
    @State private var feux = CadreFeux.defaut
    /// Marge du haut de la vue d'ensemble, d'apres la hauteur mesuree du haut de la fenetre.
    @State private var margeHautMesuree = FenetrePieces.margeHautInitiale
    /// Hauteur mesuree de la rangee du bas (la legende et la ligne de niveau), la legende ouverte ; nil, repliee.
    @State private var hauteurLegende: CGFloat?
    /// La derniere hauteur mesuree de la rangee, la legende ouverte : elle decide du repli faute de place, la legende
    /// repliee comprise.
    @State private var legendeOuverteMesuree: CGFloat?
    /// Hauteur mesuree de la pile du bas (la rangee, puis la fiche), une fiche ouverte ; nil sans fiche.
    @State private var hauteurPile: CGFloat?
    /// Hauteur mesuree de la fiche ; la derniere reste a sa fermeture, et vaut pour la suivante jusqu'a sa mesure.
    @State private var hauteurFiche: CGFloat?
    /// Hauteur mesuree de la vue.
    @State private var hauteurVue: CGFloat?
    /// Djoko a rouvert, sous une fiche, la legende repliee faute de place : elle reste ouverte jusqu'a la fermeture de
    /// cette fiche. Une ouverture faite sans fiche n'y compte pas : le drapeau tombe a chaque ouverture et a chaque
    /// fermeture de fiche (`onChange` plus bas).
    @State private var legendeRouverte = false

    /// Preference du mode 2D ou 3D.
    static let cleMode = "vuePieces3D"
    /// Taille minimale de la fenetre (polissage B, section 3) : avec la fiche et ses courbes, la scene
    /// garde environ 230 pt de haut (88 pour 820 x 560, tri du sous-projet A, n° 11).
    static let tailleMinimale = CGSize(width: 820, height: 680)
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

    /// Marge du haut de la vue d'ensemble (pt) : le bas de ce qui est pose en haut de la fenetre, mesure
    /// (`HautPieces` : la ligne des capsules, la place de la tournee tant qu'une sonde est retenue, les
    /// bandeaux presents, le fil), puis l'espacement. Elle remplace les valeurs fixes du plan 4b
    /// (precision 21).
    static func margeHaut(bas: CGFloat) -> CGFloat {
        ceil(bas) + espacement
    }

    /// Avant la premiere mesure : la ligne des capsules, l'espacement et le fil.
    static let margeHautInitiale = margeHaut(bas: 2 * CadreFeux.defaut.milieu + espacement + 16)

    /// Marge du bas de la vue d'ensemble (pt), comme celle du haut : la hauteur mesuree de ce qui est pose en bas,
    /// la pile (de haut en bas, la rangee de la legende et de la ligne de niveau, puis la fiche), le bord et
    /// l'espacement ; la vue d'ensemble se cadre au-dessus de tout cela (decisions de Djoko du 01/10 pour la legende
    /// ouverte, du 02/10 pour la fiche, qui remplacent les 190 et 360 pt fixes de la fiche). Sans rien a garder
    /// (nil : la legende repliee, ou sans entree, et pas de fiche), 30 pt : la legende repliee et la ligne de
    /// niveau debordent un peu sur la vue.
    static func margeBas(pile: CGFloat?) -> CGFloat {
        guard let pile else { return 30 }
        return max(30, bord + ceil(pile) + espacement)
    }

    /// Hauteur de scene en dessous de laquelle la legende ouverte se replie d'elle-meme sous une fiche (pt) : les
    /// 230 pt environ que la spec de B garde a la scene dans la plus petite fenetre, avec la fiche et ses courbes
    /// (section 3) ; la legende ne la fait pas descendre plus bas. Mesure sur la demo, sous la fiche de l'Apple TV 4K
    /// et sous la plus haute : dans la fenetre par defaut (1100 x 760), la legende ouverte laisse 291 et 256 pt a la
    /// scene, et reste ouverte ; dans la plus petite (820 x 712, dont 680 sous la barre de titre cachee), elle
    /// laisserait 205 et 176 pt : repliee, la scene y retrouve 402 et 373 pt.
    static let sceneMinimale: CGFloat = 230

    /// La legende se replie d'elle-meme sous une fiche ouverte (verification du 02/10) si, ouverte au-dessus d'elle,
    /// elle ne laissait a la scene que moins de `sceneMinimale` pt, dans une vue de `hauteur` pt, sous la marge du
    /// haut. `legende` : la hauteur de sa rangee ouverte, la derniere mesuree ; `fiche` : celle de la fiche ; nil, pas
    /// encore mesurees : elle ne se replie pas. Le repli garde (la preference) n'y est pour rien.
    static func repliDePlace(hauteur: CGFloat, margeHaut: CGFloat, legende: CGFloat?, fiche: CGFloat?) -> Bool {
        guard let legende, let fiche else { return false }
        return hauteur - margeHaut - margeBas(pile: legende + espacement + fiche) < sceneMinimale
    }

    var body: some View {
        let palette = Palette(sombre: true)
        // Redessin chaque minute (`horloge`) : la scene et la fiche lisent l'heure, que rien n'observe. La
        // fiche la recoit (`instant`) : sinon SwiftUI la sauterait, ses entrees n'ayant pas change. La
        // scene est construite une fois par rendu : la legende, la fiche et son menu la lisent.
        TimelineView(Self.horloge) { contexte in
            let entree = surveillance.reseau.map {
                EntreeScene(surveillance: surveillance, reseau: $0, places: moteur.places, choix: piecesChoisies.choix)
            }
            let fiche = moteur.selection != nil
            // Sous une fiche, la legende se replie d'elle-meme si la place manque, sauf si Djoko l'a rouverte.
            let repliDePlace = fiche && !legendeRouverte && hauteurVue.map {
                Self.repliDePlace(hauteur: $0, margeHaut: margeHautMesuree, legende: legendeOuverteMesuree,
                                  fiche: hauteurFiche)
            } == true
            ZStack {
                RadialGradient(gradient: palette.fond, center: UnitPoint(x: 0.3, y: 0.35), startRadius: 0, endRadius: 900)
                if let entree {
                    VuePieces(moteur: moteur, entree: entree, palette: palette,
                              marges: (margeHautMesuree, Self.margeBas(pile: hauteurPile ?? hauteurLegende)))
                    if !moteur.pret {
                        ProgressView().controlSize(.small)
                    }
                } else {
                    EtatVide()
                }
                HautPieces(moteur: moteur, troisD: $troisD, sansPieces: entree?.scene.sansPiecesMaison == true,
                           feux: feux)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(VuePieces.espace)).maxY } action: {
                        margeHautMesuree = Self.margeHaut(bas: $0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: Self.espacement) {
                    Spacer()
                    // La pile du bas, de haut en bas : la rangee de la legende et de la ligne de niveau, puis la fiche ;
                    // la legende reste au-dessus d'une fiche ouverte (verification du 02/10). La fiche glisse depuis le
                    // bas a l'ouverture et a la fermeture, et la rangee glisse avec elle. Avec « Reduire les
                    // animations », la fiche se fond (sa transition porte son fondu) et la rangee prend sa place d'un
                    // coup : aucune animation de conteneur. D'un noeud a l'autre, le contenu de la fiche change sur
                    // place.
                    VStack(alignment: .leading, spacing: Self.espacement) {
                        LigneDuBas(moteur: moteur, entree: entree, ancien: surveillance.maillageAncien,
                                   repliDePlace: repliDePlace, rouvrir: { legendeRouverte = true }) { h in
                            hauteurLegende = h
                            if let h { legendeOuverteMesuree = h }
                        }
                        if let selection = moteur.selection {
                            FicheNoeud(id: selection, entree: entree, instant: surveillance.maintenant(a: contexte.date),
                                       aRenommer: $aRenommer, choisir: { moteur.selection = $0 }) {
                                moteur.selection = nil
                            }
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hauteurFiche = $0 }
                            .obstacle("fiche", moteur)
                            .transition(Apparition.pour(.bottom, reduire: reduire).transitionAnimee)
                        }
                    }
                    // Sa hauteur, une fiche ouverte : la marge du bas (sans fiche, celle de la rangee).
                    .onGeometryChange(for: CGFloat?.self) { fiche ? $0.size.height : nil } action: { hauteurPile = $0 }
                }
                .animation(Apparition.animationDuConteneur(.bottom, reduire: reduire), value: moteur.selection == nil)
                // En bas a gauche : la pile prend toute la largeur, sinon le `ZStack` centre la rangee du bas.
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Self.bord)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hauteurVue = $0 }
            .coordinateSpace(.named(VuePieces.espace))
            .ignoresSafeArea()
        }
        .frame(minWidth: Self.tailleMinimale.width, minHeight: Self.tailleMinimale.height)
        .environment(piecesChoisies)
        .environment(\.colorScheme, .dark)
        .background(SondeFenetre { fenetre in
            Self.assombrir(fenetre)
            // Hors de la mise a jour de la vue en cours.
            if let fenetre, let c = CadreFeux(fenetre: fenetre) {
                Task { @MainActor in feux = c }
            }
        })
        .sheet(item: $aRenommer) { FeuilleRenommer(id: $0.id) }
        .onChange(of: reduire, initial: true) { _, r in moteur.reduire = r }
        // La fiche parait ou se ferme : la legende reprend son repli garde, et un « rouvert » anterieur ne vaut plus.
        .onChange(of: moteur.selection == nil) { _, _ in
            legendeRouverte = false
        }
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
        // Le premier clic agit aussi dans une fenetre inactive (verification du 02/10) : il active la fenetre et
        // isole la piece, ouvre la fiche ou commence un glisser ; sinon AppKit le garde pour activer la fenetre.
        .allowsWindowActivationEvents(true)
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

/// Capsule de droite du haut de la fenetre : l'interrupteur 2D / 3D, puis « Rotation lente », en 3D
/// seulement (coupee par « Reduire les animations »).
struct CommandesVue: View {
    let moteur: MoteurPieces
    @Binding var troisD: Bool

    var body: some View {
        HStack(spacing: 5) {
            SelecteurVue(troisD: Binding(get: { moteur.troisD }, set: { v in
                moteur.basculer(troisD: v)
                troisD = v
            }))
            if moteur.troisD {
                Toggle("Rotation lente", isOn: Binding(get: { moteur.rotation && !moteur.reduire },
                                                       set: { _ in moteur.basculerRotation() }))
                    .toggleStyle(StyleBasculeCapsule())
                    .disabled(moteur.reduire)
                    .help(moteur.reduire ? String(localized: "Coupée par « Réduire les animations »") : "")
            }
        }
    }
}

/// Bandeau d'une maison dont Maison n'a encore donne aucune piece (spec, section 2.3).
struct BandeauSansPieces: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(NomsInternes.self) private var nomsMaison

    var body: some View {
        HStack(spacing: 8) {
            Label("Pas encore de pièces de Maison : lance le passeur", systemImage: "house")
            Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                .buttonStyle(StyleBoutonCapsule(taille: 10))
                .disabled(surveillance.mode == .demo)
        }
        .piluleDuHaut()
    }
}

/// Fil, sous la capsule de gauche : « Maison », puis « › Salon » en piece isolee ; « Maison » y
/// ramene. Une capture le dessine sans bouton.
struct FilPieces: View {
    @Environment(\.capturePieces) private var capture
    let moteur: MoteurPieces

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

/// Bas a gauche de la fenetre, au-dessus de la fiche quand elle est ouverte : la legende, la ligne de niveau, et
/// la pastille d'un releve de la sonde ancien. La ligne de niveau s'aligne sur la derniere ligne de la legende.
/// Elle garde le repli de la legende, d'un lancement a l'autre, et donne sa hauteur quand la legende est ouverte
/// (nil, repliee) : la marge du bas de la vue d'ensemble (`FenetrePieces.margeBas`).
struct LigneDuBas: View {
    @Environment(\.accessibilityReduceMotion) private var reduire
    let moteur: MoteurPieces
    let entree: EntreeScene?
    var ancien = false
    /// Legende repliee ou ouverte, imposee (captures) : la preference n'est alors ni ecrite, ni suivie.
    var legendeForcee: Bool?
    /// Repli faute de place, sous une fiche, dans une fenetre trop basse (`FenetrePieces.repliDePlace`) : la legende
    /// se replie sans toucher a la preference ; l'ouvrir d'un clic le leve (`rouvrir`).
    var repliDePlace = false
    var rouvrir: () -> Void = {}
    /// Hauteur de la ligne, la legende ouverte ; nil, repliee.
    var surHauteurOuverte: (CGFloat?) -> Void = { _ in }
    @AppStorage(LegendePieces.cleRepliee) private var repliee = false

    var body: some View {
        // Des reperes « ailleurs » sont poses dans une piece isolee (lue avec elle : `isolee`).
        let ailleurs = moteur.isolee != nil && !moteur.textes.ailleurs.isEmpty
        let rubriques = entree.map { LegendePieces.rubriques(LegendePieces.Lecture($0, ailleurs: ailleurs)) } ?? []
        let estRepliee = legendeForcee ?? (repliee || repliDePlace)
        let ouverte = !rubriques.isEmpty && !estRepliee
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            if !rubriques.isEmpty {
                LegendePieces(rubriques: rubriques, repliee: Binding(get: { estRepliee }, set: { r in
                    guard legendeForcee == nil else { return }
                    // Un clic : le recadrage qui suit prend la duree de la legende ; l'ouvrir leve son repli faute de
                    // place, sans rien ecrire de plus que le choix de Djoko.
                    moteur.legendeBasculee()
                    if !r { rouvrir() }
                    repliee = r
                }))
                .obstacle("legende", moteur)
            }
            LigneNiveauVue(ligne: moteur.ligneNiveau)
                .obstacle("niveau", moteur)
            if ancien {
                PastilleAncien()
                    .obstacle("ancien", moteur)
            }
        }
        // La ligne de niveau et la pastille glissent avec la legende qui s'ouvre ou se replie ; avec « Reduire les
        // animations », elles prennent leur place d'un coup.
        .animation(Apparition.animationDuConteneurLegende(reduire: reduire), value: estRepliee)
        .onGeometryChange(for: CGFloat?.self) { ouverte ? $0.size.height : nil } action: { surHauteurOuverte($0) }
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
