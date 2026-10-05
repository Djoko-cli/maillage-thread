import AppKit
import CoreGraphics
import Foundation
import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

/// La molette et Echap (polissage D, section 3), le menu du clic droit a la fin de l'envol, et l'ordre des etages
/// fondu dans l'ordre garde (section 4).
@MainActor
@Suite("Vue par pieces : molette, Echap, menu apres l'envol, ordre garde")
struct MoletteEtEchapTests {
    /// La molette au-dessus d'un element pose sur la vue (la fiche, la legende, la ligne des capsules, la colonne du
    /// haut) n'est pas prise : la vue ne zoome pas ; au-dessus de la scene, elle zoome. Pendant un vol, elle est prise et
    /// ignoree, comme avant.
    @Test func moletteAuDessusDesElements() throws {
        let (m, e) = try MoteurPiecesTests.moteur()
        m.cadresInterface = ["fiche": CGRect(x: 16, y: 500, width: 600, height: 280),
                             "legende": CGRect(x: 16, y: 300, width: 400, height: 190),
                             "ligne": CGRect(x: 80, y: 0, width: 1100, height: 52),
                             "colonne": CGRect(x: 16, y: 62, width: 300, height: 40)]
        for p in [CGPoint(x: 100, y: 600), CGPoint(x: 20, y: 489), CGPoint(x: 600, y: 10), CGPoint(x: 315, y: 101)] {
            #expect(m.surInterface(p) && !m.molette(-3, precis: false, en: p) && !m.vueTouchee, "\(p)")
        }
        #expect(!m.surInterface(CGPoint(x: 900, y: 400)) && !m.surInterface(CGPoint(x: 616, y: 500)))
        #expect(m.molette(-3, precis: false, en: CGPoint(x: 900, y: 400)) && m.vueTouchee, "au-dessus de la scene")
        let v = MoteurPiecesTests.moteur(e)
        v.cliquer(try MoteurPiecesTests.pointDePiece(v, try MoteurPiecesTests.indice(e, "Salon")))
        #expect(v.enMouvement && v.molette(-3, precis: false, en: CGPoint(x: 900, y: 400)), "pendant un vol : prise")
    }

    /// Echap (section 3), dans cet ordre : une fiche ouverte se ferme, sans rien d'autre ; sinon la vue remonte d'un
    /// cran ; sinon, a la vue d'ensemble sans zoom ni fiche, Echap n'est pas pris. Zoomee, Echap la ramene.
    @Test func echapDansLesTroisCas() throws {
        let (m, e) = try MoteurPiecesTests.moteur()
        let salon = try MoteurPiecesTests.indice(e, "Salon")
        m.poserIsolement(salon)
        m.selection = "Apple TV 4K"
        #expect(m.sortir() && m.selection == nil && m.estIsolee, "la fiche d'abord")
        #expect(m.sortir() && !m.estIsolee && m.isolement == .maison, "puis la vue remonte")
        let n = MoteurPiecesTests.moteur(e)
        #expect(!n.sortir() && n.sansIsolement && !n.vueTouchee, "a la vue d'ensemble : pas pris")
        n.poserZoom(echelle: 1, vers: nil)
        #expect(n.sortir() && !n.vueTouchee, "zoomee : la vue d'ensemble")
        n.basculer(troisD: true)
        #expect(!n.sortir(), "pendant l'envol, rien a faire")
    }

    /// Le chemin des evenements du moniteur, dans la vraie fenetre : Echap y est pris s'il a a faire, sinon il suit son
    /// chemin ; un Echap d'une autre fenetre n'est jamais pris ; la molette au-dessus de la legende ne zoome pas,
    /// au-dessus de la scene si. Le point de la molette est celui de la vue, depuis son coin haut gauche.
    @Test(.timeLimit(.minutes(1))) func evenementsDeLaFenetre() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let (fenetre, moteur) = try FenetrePiecesTests.fenetre(demo, taille: CGSize(width: 1100, height: 760), preferences: p)
        defer { FenetrePiecesTests.fermer(fenetre) }
        try await MoteurPiecesTests.attendre {
            moteur.pret && moteur.cadresInterface["legende"] != nil && !moteur.margesEnRoute && moteur.vue != nil
        }
        #expect(moteur.fenetre === fenetre)
        func echap(_ w: NSWindow) throws -> NSEvent {
            try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                          windowNumber: w.windowNumber, context: nil, characters: "\u{1B}",
                                          charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53))
        }
        moteur.selection = "Apple TV 4K"
        #expect(moteur.prendre(try echap(fenetre)) && moteur.selection == nil, "la fiche se ferme")
        #expect(!moteur.prendre(try echap(fenetre)), "a la vue d'ensemble, Echap suit son chemin")
        let autre = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: 200, height: 200), styleMask: [.titled],
                             backing: .buffered, defer: false)
        autre.isReleasedWhenClosed = false
        moteur.selection = "Apple TV 4K"
        #expect(!moteur.prendre(try echap(autre)) && moteur.selection != nil, "une autre fenetre")
        moteur.selection = nil
        // La molette, en un point de la vue (depuis le haut), au-dessus de la legende puis de la scene : l'evenement lu
        // porte le point de la fenetre, que le moteur ramene a la vue.
        let vue = try #require(moteur.vue)
        func molette(en q: CGPoint) -> MoteurPieces.EvenementVue {
            let dansFenetre = vue.convert(CGPoint(x: q.x, y: vue.isFlipped ? q.y : vue.bounds.height - q.y), to: nil)
            return MoteurPieces.EvenementVue(.molette(dy: -40, precis: true, position: dansFenetre))
        }
        let legende = try #require(moteur.cadresInterface["legende"])
        let surLegende = CGPoint(x: legende.midX, y: legende.midY)
        let dansFenetre = vue.convert(CGPoint(x: surLegende.x, y: vue.isFlipped ? surLegende.y : vue.bounds.height - surLegende.y), to: nil)
        let retour = VuePieces.point(dansFenetre, dans: vue)
        #expect(abs(retour.x - surLegende.x) < 1e-6 && abs(retour.y - surLegende.y) < 1e-6, "le point de la vue")
        #expect(abs(dansFenetre.y - (fenetre.contentView?.bounds.height ?? 0) + surLegende.y) < 1, "la fenetre compte depuis le bas")
        #expect(!moteur.prendre(molette(en: surLegende)) && !moteur.vueTouchee, "au-dessus de la legende : pas de zoom")
        let scene = CGPoint(x: 900, y: 300)
        #expect(!moteur.surInterface(scene))
        #expect(moteur.prendre(molette(en: scene)) && moteur.vueTouchee, "au-dessus de la scene : le zoom")
        #expect(!moteur.prendre(MoteurPieces.EvenementVue(.option(true))), "⌥ suit son chemin")
    }

    /// Le menu du clic droit revient des la fin de l'envol ou de son fondu (section 4), sans mouvement du pointeur :
    /// le pointeur immobile sur le fond reprend le menu du fond.
    @Test(.timeLimit(.minutes(1)), arguments: [false, true]) func menuALaFinDeLEnvol(reduire: Bool) async throws {
        let (m, _) = try MoteurPiecesTests.moteur()
        m.reduire = reduire
        let fond = CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3)
        m.survoler(fond)
        #expect(m.cibleMenu == .fond)
        m.basculer(troisD: true)
        #expect(m.enMouvement && m.cibleMenu == .aucune)
        try await MoteurPiecesTests.attendre {
            MoteurPiecesTests.dessiner(m)
            return !m.enMouvement
        }
        #expect(!m.enMouvement && m.t == 1)
        try await MoteurPiecesTests.attendre { m.cibleMenu == .fond }
        #expect(m.cibleMenu == .fond, "le menu du fond, sous le pointeur immobile")
    }

    /// « Monter d'un etage » avec un etage absent de la scene (section 4) : il garde son rang relatif dans l'ordre garde,
    /// juste apres celui qui le precedait.
    @Test func unEtageAbsentGardeSonRang() throws {
        let base = try MoteurPiecesTests.quatrePlateaux()
        var places = PlacesGardees()
        let rdc = IsolementTests.rdc, jardin = IsolementTests.jardin, etage = IsolementTests.etage
        let combles = IsolementTests.combles
        places.ordonner([rdc, "zone:Grange", jardin, etage, combles], domicile: base.domicile)
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try places.ecrire(dans: url)
        let e = try MoteurPiecesTests.quatrePlateaux(places)
        let m = MoteurPiecesTests.moteur(e, fichier: url)
        #expect(e.scene.etages.map(\.id) == [rdc, jardin, etage, combles])
        m.deplacerEtage(rdc, de: 1)
        #expect(m.places.maison(base.domicile).ordreEtages == [jardin, rdc, "zone:Grange", etage, combles])
        #expect(PlacesGardees.lire(url).maison(base.domicile).ordreEtages == [jardin, rdc, "zone:Grange", etage, combles])
    }
}
