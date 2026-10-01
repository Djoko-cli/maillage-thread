import AppKit
import ImageIO
import MaillageCoeur
import SwiftUI
import UniformTypeIdentifiers

/// Images de la vue par pieces rendues par l'app elle-meme, en mode demo (`--args -demo -captures
/// <dossier>`), pour la relecture (spec de la vue par pieces, section 10) : 2D, envol, 3D, zooms,
/// pieces isolees, survol. Sans fenetre ni capture d'ecran ; l'app quitte ensuite.
@MainActor
enum CapturesPieces {
    /// Contenu d'une fenetre de 1440 x 900, en 2x.
    static let taille = CGSize(width: 1440, height: 900)

    /// Ecrit les images dans `dossier` ; rend leurs noms.
    @discardableResult
    static func ecrire(dans dossier: String, surveillance s: Surveillance) -> [String] {
        try? FileManager.default.createDirectory(atPath: dossier, withIntermediateDirectories: true)
        guard let r = s.reseau else { return [] }
        let palette = Palette(sombre: true)
        let marges = (FenetrePieces.margeHaut(scinde: r.estScinde, sondeRetenue: false, sansPieces: false),
                      FenetrePieces.margeBas(fiche: false, courbes: false))
        func piece(_ scene: ScenePieces, _ nom: String) -> Int {
            scene.pieces.firstIndex { $0.nom == .maison(nom) } ?? 0
        }
        let cas: [(String, (MoteurPieces, ScenePieces) -> Void)] = [
            ("01-2d", { _, _ in }),
            ("02-envol-30", { m, _ in m.poserBascule(0.3) }),
            ("03-envol-55", { m, _ in m.poserBascule(0.55) }),
            ("04-envol-80", { m, _ in m.poserBascule(0.8) }),
            ("05-3d", { m, _ in m.poserBascule(1) }),
            ("06-3d-tournee", { m, _ in
                m.poserBascule(1)
                m.poserAzimut(-1.9)
            }),
            ("07-2d-zoom-salon", { m, sc in m.poserZoom(echelle: 2.2, vers: m.centrePiece(piece(sc, "Salon"))) }),
            ("08-2d-mi-distance", { m, _ in m.poserZoom(echelle: 0.5, vers: nil) }),
            ("09-2d-loin", { m, _ in m.poserZoom(echelle: 0.36, vers: nil) }),
            ("10-3d-isolee-salon", { m, sc in
                m.poserBascule(1)
                m.poserIsolement(piece(sc, "Salon"))
            }),
            ("11-2d-isolee-chambre", { m, sc in m.poserIsolement(piece(sc, "Chambre")) }),
            ("12-2d-survol", { m, _ in m.poserSurvol("9A28601B74FF90A7") }),
        ]
        var noms: [String] = []
        for (nom, preparer) in cas {
            let m = MoteurPieces()
            m.fige = true
            m.marges = marges
            m.poserTaille(taille)
            let e = EntreeScene(surveillance: s, reseau: r, places: m.places)
            m.installerMaintenant(e)
            m.poserTaille(taille)
            preparer(m, e.scene)
            // Deux passages : le premier pose les noms, le second les dessine a leur place.
            var image: CGImage?
            for _ in 0..<2 {
                let rendu = ImageRenderer(content: VueCapture(moteur: m, palette: palette).frame(width: taille.width,
                                                                                                height: taille.height))
                rendu.scale = 2
                image = rendu.cgImage
            }
            guard let image else { continue }
            ecrire(image, vers: (dossier as NSString).appendingPathComponent(nom + ".png"))
            noms.append(nom)
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

/// La vue d'une capture : le fond, la scene, le fil et la ligne de niveau, sans horloge ni geste.
struct VueCapture: View {
    let moteur: MoteurPieces
    let palette: Palette

    var body: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(gradient: palette.fond, center: UnitPoint(x: 0.3, y: 0.35), startRadius: 0, endRadius: 900)
            Canvas { ctx, taille in moteur.image(&ctx, taille: taille, echelle: 2, palette: palette) }
            VStack(alignment: .leading) {
                FilPieces(moteur: moteur, capture: true)
                    .padding(.top, 56)
                Spacer()
                LigneNiveauVue(ligne: moteur.ligneNiveau)
            }
            .padding(FenetrePieces.bord)
        }
        .environment(\.colorScheme, .dark)
    }
}
