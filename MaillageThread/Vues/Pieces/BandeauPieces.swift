import AppKit
import MaillageCoeur
import SwiftUI

// Haut de la fenetre de la vue par pieces, sans barre de titre (polissage B, section 1 ; maquette du
// bandeau, carte C) : deux capsules de verre sur la ligne des trois boutons de la fenetre, le reseau a
// gauche (`BarreOutils`), la vue a droite (`CommandesVue`) ; entre elles, la bande qui deplace la
// fenetre ; sous la capsule de gauche, en plus petit, la tournee, les bandeaux et le fil.

extension EnvironmentValues {
    /// Rendu d'une capture (`CapturesPieces`, par `ImageRenderer`) : ni le verre, ni les vues d'AppKit
    /// n'y sont dessines ; les vues posent a leur place le dessin de la maquette.
    @Entry var capturePieces = false
}

/// Cadre des trois boutons de la fenetre (fermer, reduire, agrandir), dans l'espace de la vue, dont
/// l'origine est le coin haut gauche de la fenetre (le contenu la couvre en entier) : la capsule de
/// gauche commence juste apres eux, et se centre sur leur milieu.
struct CadreFeux: Equatable {
    /// Bord droit du bouton agrandir (pt, depuis le bord gauche).
    var droite: CGFloat
    /// Milieu des boutons (pt, depuis le haut).
    var milieu: CGFloat

    /// Celui d'une fenetre sans barre d'outils, mesure sous macOS 27 (barre de titre de 32 pt) : trois
    /// boutons de 14 pt, en x = 9, 32 et 55, de 9 a 23 pt du haut. Avant que la fenetre soit connue,
    /// et pour les captures, qui ne rendent pas la fenetre.
    static let defaut = CadreFeux(droite: 69, milieu: 16)

    init(droite: CGFloat, milieu: CGFloat) {
        self.droite = droite
        self.milieu = milieu
    }

    /// Lu sur la fenetre : les cadres des boutons fermer et agrandir, ramenes au coin haut gauche de la
    /// fenetre ; nil sans ces boutons.
    @MainActor
    init?(fenetre: NSWindow) {
        guard let fermer = fenetre.standardWindowButton(.closeButton),
              let agrandir = fenetre.standardWindowButton(.zoomButton) else { return nil }
        let f = fermer.convert(fermer.bounds, to: nil)
        let a = agrandir.convert(agrandir.bounds, to: nil)
        self.init(droite: a.maxX, milieu: fenetre.frame.height - f.midY)
    }
}

/// Ce que fait un double-clic sur la bande du haut : celui d'une barre de titre, selon le reglage du Mac
/// (Bureau et Dock, « Double-cliquer sur la barre de titre d'une fenetre pour »), lu dans
/// `AppleActionOnDoubleClick` : « Fill », « Maximize », « Minimize » ou « None ».
enum ActionDoubleClic: Equatable {
    /// Remplir l'ecran ou agrandir (« Fill », « Maximize », et le reglage absent) : `performZoom`.
    /// AppKit n'a pas d'API publique pour remplir ; le zoom d'une fenetre redimensionnable prend l'ecran.
    case agrandir
    case reduire
    case rien

    init(reglage: String?) {
        switch reglage {
        case "Minimize": self = .reduire
        case "None": self = .rien
        default: self = .agrandir
        }
    }

    static let cle = "AppleActionOnDoubleClick"

    /// Celle du Mac, lue a chaque double-clic : un reglage change s'applique tout de suite.
    static var duMac: ActionDoubleClic { ActionDoubleClic(reglage: UserDefaults.standard.string(forKey: cle)) }

    @MainActor
    func appliquer(_ fenetre: NSWindow) {
        switch self {
        case .agrandir: fenetre.performZoom(nil)
        case .reduire: fenetre.performMiniaturize(nil)
        case .rien: break
        }
    }
}

/// Bande vide du haut, entre les deux capsules : la glisser deplace la fenetre ; un double-clic y fait
/// ce que fait un double-clic sur une barre de titre (`ActionDoubleClic`). C'est une vue d'AppKit, posee
/// sur la scene : elle recoit ses clics avant elle, et les gestes de la scene (tourner, deplacer, le
/// double-clic qui recadre) ne s'y appliquent pas. `WindowDragGesture` deplacerait la fenetre, mais
/// sans le double-clic de la barre de titre. Une capture ne la dessine pas.
struct BandeFenetre: View {
    @Environment(\.capturePieces) private var capture

    var body: some View {
        if capture {
            Color.clear
        } else {
            Representation()
        }
    }

    struct Representation: NSViewRepresentable {
        func makeNSView(context: Context) -> Vue { Vue() }
        func updateNSView(_ nsView: Vue, context: Context) {}
    }

    final class Vue: NSView {
        /// Deplacer la fenetre au glisser ; l'action du double-clic. Remplacees par les tests.
        var glisser: @MainActor (NSWindow, NSEvent) -> Void = { $0.performDrag(with: $1) }
        var doubleCliquer: @MainActor (NSWindow) -> Void = { ActionDoubleClic.duMac.appliquer($0) }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            switch event.clickCount {
            case 1: glisser(window, event)
            case 2: doubleCliquer(window)
            default: break
            }
        }

        /// Comme une barre de titre : le premier clic agit aussi dans une fenetre inactive.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        /// La fenetre est deplacee ici (`performDrag`), et par elle seule.
        override var mouseDownCanMoveWindow: Bool { false }
    }
}

/// Haut de la fenetre, pose sur la scene : la ligne des capsules, centree sur les trois boutons de la
/// fenetre (le reseau juste apres eux, la vue contre le bord droit, la bande entre elles) ; sous la
/// capsule de gauche, alignes sur elle, la ligne de la tournee (sa place gardee tant qu'une sonde est
/// retenue), le bandeau de scission, celui d'une maison sans pieces, et le fil. Sa hauteur mesuree donne
/// la marge du haut de la vue d'ensemble (`FenetrePieces.margeHaut`).
struct HautPieces: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.accessibilityReduceMotion) private var reduire
    let moteur: MoteurPieces
    @Binding var troisD: Bool
    /// Maison n'a encore aucune piece : le bandeau du passeur.
    var sansPieces = false
    var feux = CadreFeux.defaut

    /// Ecart entre le bouton agrandir et la capsule de gauche, et entre la capsule de droite et le bord
    /// de la fenetre (pt) : ceux de la maquette (72 - 59, et 12).
    static let ecartFeux: CGFloat = 13
    static let bordDroit: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
            HStack(spacing: 0) {
                BarreOutils()
                    .capsuleDeVerre()
                BandeFenetre()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                CommandesVue(moteur: moteur, troisD: $troisD)
                    .capsuleDeVerre()
            }
            .frame(height: 2 * feux.milieu)
            .obstacle("ligne", moteur)
            // Un bandeau qui parait glisse depuis le haut, et repart de meme (fondu simple avec « Reduire
            // les animations ») ; ce qui est dessous descend avec lui.
            VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                LigneTournee()
                if let r = surveillance.reseau, r.estScinde {
                    BandeauScission(reseau: r)
                        .transition(apparition.transition)
                }
                if sansPieces {
                    BandeauSansPieces()
                        .transition(apparition.transition)
                }
                FilPieces(moteur: moteur)
            }
            .animation(apparition.animation, value: surveillance.reseau?.estScinde == true)
            .animation(apparition.animation, value: sansPieces)
            .obstacle("colonne", moteur)
        }
        .padding(.leading, feux.droite + Self.ecartFeux)
        .padding(.trailing, Self.bordDroit)
    }

    private var apparition: Apparition { Apparition.pour(.top, reduire: reduire) }
}

/// Bouton d'une capsule du haut (maquette du bandeau, `.b`) : texte de 11 pt (10 sous la capsule) blanc
/// a 0,92, marges de 3 x 9 pt, pastille blanche a 0,10 (0,20 enfoncee) au filet de 0,5 pt blanc a 0,16 ;
/// `allume` : la pastille blanche a 0,28 et le texte blanc, comme le segment choisi de 2D / 3D.
struct StyleBoutonCapsule: ButtonStyle {
    var taille: CGFloat = 11
    var allume = false

    func makeBody(configuration: Configuration) -> some View {
        Corps(etiquette: configuration.label, enfonce: configuration.isPressed, taille: taille, allume: allume)
    }

    private struct Corps<Etiquette: View>: View {
        @Environment(\.isEnabled) private var actif
        let etiquette: Etiquette
        let enfonce: Bool
        let taille: CGFloat
        let allume: Bool

        var body: some View {
            etiquette
                .font(.system(size: taille))
                .foregroundStyle(Color.white.opacity(allume ? 1 : 0.92))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(allume ? 0.28 : enfonce ? 0.2 : 0.1)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
                .contentShape(Capsule())
                .opacity(actif ? 1 : 0.45)
        }
    }
}

/// Bouton a deux etats d'une capsule du haut (« Rotation lente ») : celui de `StyleBoutonCapsule`,
/// allume quand il est actif.
struct StyleBasculeCapsule: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        .buttonStyle(StyleBoutonCapsule(allume: configuration.isOn))
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

/// Interrupteur 2D / 3D (maquette du bandeau, `.seg`) : deux segments de 11 pt blancs a 0,8, marges de
/// 3 x 10 pt, dans une pastille blanche a 0,08 au filet de 0,5 pt blanc a 0,16 ; le segment choisi sur
/// une pastille blanche a 0,28, en blanc. Pour VoiceOver, un choix « Vue » a deux segments.
struct SelecteurVue: View {
    @Binding var troisD: Bool

    var body: some View {
        HStack(spacing: 0) {
            segment("2D", choisi: !troisD) { troisD = false }
            segment("3D", choisi: troisD) { troisD = true }
        }
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
        .accessibilityRepresentation {
            Picker("Vue", selection: $troisD) {
                Text("2D").tag(false)
                Text("3D").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    private func segment(_ titre: LocalizedStringKey, choisi: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titre)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(choisi ? 1 : 0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(choisi ? 0.28 : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// Capsule de verre du haut (maquette du bandeau, `.verre` de la carte C) : 5 pt autour du contenu,
    /// du verre en capsule. Une capture, qui ne rend pas le verre, pose a sa place le fond de la
    /// maquette : rgba(40, 48, 72, 0,38), filet de 0,5 pt blanc a 0,22, ombre noire a 0,35.
    func capsuleDeVerre() -> some View {
        modifier(CapsuleDeVerre())
    }

    /// Ligne sous la capsule de gauche, en plus petit (maquette du bandeau, `.pilule`) : texte de 10 pt
    /// blanc a 0,75, marges de 3 x 10 pt, en capsule de verre, teintee pour un bandeau d'alerte. Une
    /// capture pose a sa place le fond de la maquette : rgba(40, 48, 72, 0,32) (ou la teinte), filet de
    /// 0,5 pt blanc a 0,16.
    func piluleDuHaut(teinte: Color? = nil) -> some View {
        modifier(PiluleDuHaut(teinte: teinte))
    }
}

/// Fond du verre dans une capture (capsules, fiche) : celui des maquettes.
let fondVerreCapture = Color(.sRGB, red: 40 / 255, green: 48 / 255, blue: 72 / 255)

private struct CapsuleDeVerre: ViewModifier {
    @Environment(\.capturePieces) private var capture

    func body(content: Content) -> some View {
        let c = content.padding(5)
        if capture {
            c.background(Capsule().fill(fondVerreCapture.opacity(0.38)).shadow(color: .black.opacity(0.35), radius: 9, y: 6))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
        } else {
            c.glassEffect(.regular, in: .capsule)
        }
    }
}

private struct PiluleDuHaut: ViewModifier {
    @Environment(\.capturePieces) private var capture
    let teinte: Color?

    func body(content: Content) -> some View {
        let c = content
            .font(.system(size: 10))
            .foregroundStyle(Color.white.opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
        if capture {
            c.background(Capsule().fill(teinte ?? fondVerreCapture.opacity(0.32)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
        } else {
            c.glassEffect(teinte.map { Glass.regular.tint($0) } ?? .regular, in: .capsule)
        }
    }
}

/// Les trois boutons de la fenetre, dessines dans une capture seulement (qui ne rend pas la fenetre) :
/// a leur place (`CadreFeux.defaut`), aux couleurs de la maquette.
struct FeuxDeCapture: View {
    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(Color(.sRGB, red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255))
            Circle().fill(Color(.sRGB, red: 0xFE / 255, green: 0xBC / 255, blue: 0x2E / 255))
            Circle().fill(Color(.sRGB, red: 0x28 / 255, green: 0xC8 / 255, blue: 0x40 / 255))
        }
        .frame(width: 3 * 14 + 2 * 9, height: 14)
        .offset(x: 9, y: CadreFeux.defaut.milieu - 7)
        .accessibilityHidden(true)
    }
}
