import AppKit
import ImageIO
import MaillageCoeur
import SwiftUI
import UniformTypeIdentifiers

/// Images de la vue par pieces rendues par l'app elle-meme, en mode demo (`--args -demo -captures
/// <dossier>`), pour la relecture (spec de la vue par pieces, section 10) : 2D, envol, 3D, zooms,
/// pieces isolees, survol, la fiche du chef, la legende repliee. Sans fenetre ni capture d'ecran ;
/// l'app quitte ensuite. `ImageRenderer` ne rend ni la fenetre ni le verre : le haut de la fenetre et la
/// fiche y sont dessines comme dans les maquettes (`capturePieces`), avec les trois boutons de la
/// fenetre a leur place (`FeuxDeCapture`).
@MainActor
enum CapturesPieces {
    /// Contenu d'une fenetre de 1440 x 900, en 2x.
    static let taille = CGSize(width: 1440, height: 900)

    /// Une image : son nom, l'etat a poser sur le moteur, et la legende repliee.
    struct Cas {
        var nom: String
        var poser: (MoteurPieces, ScenePieces) -> Void
        var legendeRepliee = false
    }

    /// Indice d'une piece de Maison de la scene (la premiere, sans elle).
    static func piece(_ scene: ScenePieces, _ nom: String) -> Int {
        scene.pieces.firstIndex { $0.nom == .maison(nom) } ?? 0
    }

    /// Les images, dans l'ordre : 2D, envol, 3D, zooms, pieces isolees, survol ; puis la fiche du chef de
    /// la demo, avec sa pastille, la vue relevee au-dessus d'elle ; et la legende repliee.
    static let cas: [Cas] = [
        Cas(nom: "01-2d") { _, _ in },
        Cas(nom: "02-envol-30") { m, _ in m.poserBascule(0.3) },
        Cas(nom: "03-envol-55") { m, _ in m.poserBascule(0.55) },
        Cas(nom: "04-envol-80") { m, _ in m.poserBascule(0.8) },
        Cas(nom: "05-3d") { m, _ in m.poserBascule(1) },
        Cas(nom: "06-3d-tournee") { m, _ in
            m.poserBascule(1)
            m.poserAzimut(-1.9)
        },
        Cas(nom: "07-2d-zoom-salon") { m, sc in m.poserZoom(echelle: 2.2, vers: m.centrePiece(piece(sc, "Salon"))) },
        Cas(nom: "08-2d-mi-distance") { m, _ in m.poserZoom(echelle: 0.5, vers: nil) },
        Cas(nom: "09-2d-loin") { m, _ in m.poserZoom(echelle: 0.36, vers: nil) },
        Cas(nom: "10-3d-isolee-salon") { m, sc in
            m.poserBascule(1)
            m.poserIsolement(piece(sc, "Salon"))
        },
        Cas(nom: "11-2d-isolee-chambre") { m, sc in m.poserIsolement(piece(sc, "Chambre")) },
        Cas(nom: "12-2d-survol") { m, _ in m.poserSurvol("9A28601B74FF90A7") },
        Cas(nom: "13-2d-fiche-du-chef") { m, _ in m.selection = "Apple TV 4K" },
        Cas(nom: "14-2d-legende-repliee", poser: { _, _ in }, legendeRepliee: true),
    ]

    /// Ecrit les images dans `dossier` ; rend leurs noms.
    @discardableResult
    static func ecrire(dans dossier: String, surveillance s: Surveillance, sonde: SondeMaillage,
                       nomsMaison: NomsInternes) -> [String] {
        try? FileManager.default.createDirectory(atPath: dossier, withIntermediateDirectories: true)
        guard let r = s.reseau else { return [] }
        let palette = Palette(sombre: true)
        // Hauteur d'une vue de la fenetre, rendue pour une capture, a la largeur `largeur` (sinon la sienne).
        func hauteur(_ vue: some View, largeur: CGFloat? = nil) -> CGFloat {
            NSHostingView(rootView: vue.frame(width: largeur).pourCapture(s, sonde, nomsMaison)).fittingSize.height
        }
        // Marge du haut : la hauteur du haut de la fenetre, mesuree comme dans la fenetre.
        let haut = hauteur(HautPieces(moteur: MoteurPieces(), troisD: .constant(false)))
        let marges = (FenetrePieces.margeHaut(bas: haut), FenetrePieces.margeBas(pile: nil))
        var noms: [String] = []
        for c in cas {
            let m = MoteurPieces()
            m.fige = true
            m.marges = marges
            m.poserTaille(taille)
            let e = EntreeScene(surveillance: s, reseau: r, places: m.places)
            m.installerMaintenant(e)
            // La vue d'ensemble se cadre au-dessus de la legende ouverte : la hauteur mesuree de la rangee du bas,
            // comme dans la fenetre ; repliee, la marge d'avant.
            let ouverte = hauteur(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false))
            if !c.legendeRepliee {
                m.marges.bas = FenetrePieces.margeBas(pile: ouverte)
            }
            m.poserTaille(taille)
            c.poser(m, e.scene)
            // La fiche : la legende reste au-dessus d'elle (repliee si la place manque, comme dans la fenetre), et la
            // vue se cadre au-dessus de la pile mesuree.
            var repliee = c.legendeRepliee
            if let id = m.selection {
                let largeur = taille.width - 2 * FenetrePieces.bord
                let fiche = hauteur(FicheNoeud(id: id, entree: e, instant: s.maintenant, aRenommer: .constant(nil)) {},
                                    largeur: largeur)
                repliee = repliee || FenetrePieces.repliDePlace(hauteur: taille.height, margeHaut: m.marges.haut,
                                                                legende: ouverte, fiche: fiche)
                let pile = hauteur(VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                    LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: repliee)
                    FicheNoeud(id: id, entree: e, instant: s.maintenant, aRenommer: .constant(nil)) {}
                }, largeur: largeur)
                m.marges.bas = FenetrePieces.margeBas(pile: pile)
                m.poserTaille(taille)
            }
            // Deux passages : le premier pose les noms, le second les dessine a leur place.
            var image: CGImage?
            for _ in 0..<2 {
                let rendu = ImageRenderer(content: VueCapture(moteur: m, palette: palette, legendeRepliee: repliee)
                    .frame(width: taille.width, height: taille.height)
                    .pourCapture(s, sonde, nomsMaison))
                rendu.scale = 2
                image = rendu.cgImage
            }
            guard let image else { continue }
            ecrire(image, vers: (dossier as NSString).appendingPathComponent(c.nom + ".png"))
            noms.append(c.nom)
        }
        return noms
    }

    static func ecrire(_ image: CGImage, vers chemin: String) {
        guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: chemin) as CFURL,
                                                         UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}

/// La vue d'une capture : le fond, la scene, le haut de la fenetre (avec ses trois boutons), la legende
/// (ouverte, ou repliee) et la ligne de niveau, puis, dessous, la fiche du noeud choisi ; sans horloge ni geste.
struct VueCapture: View {
    @Environment(Surveillance.self) private var surveillance
    let moteur: MoteurPieces
    let palette: Palette
    var legendeRepliee = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(gradient: palette.fond, center: UnitPoint(x: 0.3, y: 0.35), startRadius: 0, endRadius: 900)
            Canvas { ctx, taille in moteur.image(&ctx, taille: taille, echelle: 2, palette: palette) }
            HautPieces(moteur: moteur, troisD: .constant(moteur.troisD))
            FeuxDeCapture()
            VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                Spacer()
                LigneDuBas(moteur: moteur, entree: moteur.entree, legendeForcee: legendeRepliee)
                if let id = moteur.selection {
                    FicheNoeud(id: id, entree: moteur.entree, instant: surveillance.maintenant,
                               aRenommer: .constant(nil)) {}
                }
            }
            .padding(FenetrePieces.bord)
        }
        .coordinateSpace(.named(VuePieces.espace))
    }
}

extension View {
    /// Ce qu'une vue de la fenetre lit dans une capture : la surveillance, la sonde et les noms de la
    /// demo, l'apparence sombre, et le rendu de capture.
    func pourCapture(_ s: Surveillance, _ sonde: SondeMaillage, _ noms: NomsInternes) -> some View {
        environment(\.capturePieces, true)
            .environment(\.colorScheme, .dark)
            .environment(s)
            .environment(sonde)
            .environment(noms)
    }
}
