import AppKit
import Foundation
import MaillageCoeur
import simd
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : moteur et rendu")
struct MoteurPiecesTests {
    static let taille = CGSize(width: 1200, height: 800)

    /// Un moteur sur la demo, dispose, et une premiere image dessinee (hors fenetre).
    static func moteur(fichier: URL? = nil) throws -> (MoteurPieces, EntreeScene) {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces(fichierPlaces: fichier)
        m.marges = (84, 50)
        m.poserTaille(taille)
        m.installerMaintenant(e)
        dessiner(m)
        return (m, e)
    }

    static func dessiner(_ m: MoteurPieces) {
        let rendu = ImageRenderer(content: Canvas { ctx, t in
            m.image(&ctx, taille: t, echelle: 1, palette: Palette(sombre: true))
        }.frame(width: taille.width, height: taille.height))
        _ = rendu.cgImage
    }

    static func fichier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pieces-\(UUID().uuidString)/positions-pieces.json")
    }

    /// Un point d'une piece, hors de ses pastilles et des noms : pres du coin bas droit de son dessus.
    static func pointDePiece(_ m: MoteurPieces, _ i: Int) throws -> CGPoint {
        let a = try #require(m.projetee?.ancresPieces[i])
        return CGPoint(x: a.maxX - 3, y: a.maxY - 3)
    }

    static func indice(_ e: EntreeScene, _ nom: String) throws -> Int {
        try #require(e.scene.pieces.firstIndex { $0.nom == .maison(nom) })
    }

    /// Disposition installee, premiere image : un nom par noeud, etage et piece, et « ⌂ Maison » ;
    /// la ligne de niveau suit le zoom.
    @Test func installerEtDessiner() throws {
        let (m, e) = try Self.moteur()
        #expect(m.pret)
        #expect(m.positions.count == e.scene.pieces.count && m.geometrie.rayons.count == 2)
        #expect(m.etiquettes.count == e.scene.noeuds.count + e.scene.etages.count + e.scene.pieces.count + 1)
        #expect(m.projetee?.blocs.count == e.scene.pieces.count)
        #expect(m.etiquettes.contains { $0.vu })
        m.fige = true
        Self.dessiner(m)
        #expect(m.ligneNiveau != .isolee(""))
    }

    /// Clic sur une piece : elle s'isole (le fil la nomme) ; sur un appareil : sa fiche ; a cote : la
    /// fiche se ferme et la vue revient a la maison.
    @Test func clics() throws {
        let (m, e) = try Self.moteur()
        let salon = try Self.indice(e, "Salon")
        m.cliquer(try Self.pointDePiece(m, salon))
        #expect(m.estIsolee && m.focus == salon && m.isolee == "Salon")
        let disque = try #require(m.projetee?.disques.first { $0.noeud == "Apple TV 4K" })
        m.cliquer(disque.centre)
        #expect(m.selection == "Apple TV 4K")
        m.cliquer(CGPoint(x: 5, y: Self.taille.height / 2))
        #expect(m.selection == nil && !m.estIsolee && m.isolee == nil)
    }

    /// Glisser une piece la deplace dans son etage, sans sortir du plateau ; au relachement, sa place
    /// est gardee sur disque.
    @Test func glisserUnePiece() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.moteur(fichier: url)
        let cuisine = try Self.indice(e, "Cuisine")
        let avant = m.positions[cuisine]
        let depart = try Self.pointDePiece(m, cuisine)
        m.glisser(depart, depart: depart)
        m.glisser(CGPoint(x: depart.x + 30, y: depart.y), depart: depart)
        m.glisser(CGPoint(x: depart.x + 5000, y: depart.y), depart: depart)
        m.relacher(CGPoint(x: depart.x + 5000, y: depart.y))
        let apres = m.positions[cuisine]
        #expect(apres.x > avant.x)
        let r = m.geometrie.rayons[e.scene.pieces[cuisine].etage]
            - 0.5 * hypot(m.cartes[cuisine].largeur, m.cartes[cuisine].profondeur)
        #expect(simd_length(apres) <= r + 1e-9, "borne au plateau")
        #expect(!m.estIsolee, "un glisser n'isole pas")
        let gardee = PlacesGardees.lire(url).maison(e.domicile).etages["zone:Rez-de-chaussée"]?["piece:Cuisine"]
        #expect(gardee == PlacesGardees.Place(x: apres.x, z: apres.y))
    }

    /// Clics droits : l'ordre des etages change et se garde ; « Replacer les pieces automatiquement »
    /// oublie les places, pas l'ordre.
    @Test func etagesEtReplacement() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.moteur(fichier: url)
        #expect(m.peutDeplacerEtage(0, de: 1) && !m.peutDeplacerEtage(1, de: 1) && !m.peutDeplacerEtage(0, de: -1))
        m.deplacerEtage(0, de: 1)
        #expect(m.places.maison(e.domicile).ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
        let depart = try Self.pointDePiece(m, 0)
        m.glisser(depart, depart: depart)
        m.glisser(CGPoint(x: depart.x + 20, y: depart.y), depart: depart)
        m.relacher(CGPoint(x: depart.x + 20, y: depart.y))
        #expect(!m.places.maison(e.domicile).etages.isEmpty)
        m.replacerPieces()
        #expect(m.places.maison(e.domicile).etages.isEmpty)
        #expect(PlacesGardees.lire(url).maison(e.domicile).ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
    }

    /// Bascule : un envol, ou un fondu si « Reduire les animations » ; une piece isolee est relachee.
    /// Une scene recue pendant le mouvement attend sa fin.
    @Test func basculeEtAttente() throws {
        let (m, e) = try Self.moteur()
        m.cliquer(try Self.pointDePiece(m, try Self.indice(e, "Salon")))
        m.basculer(troisD: true)
        #expect(m.troisD && m.enMouvement && m.focus == nil && m.isolee == nil)
        var autre = e
        autre.libelles["56B1E064401F74EF"] = LibellesNoeuds.Libelle(texte: "Pont Halo")
        m.recevoir(autre)
        #expect(m.entree == e, "pendant l'envol, la scene attend")
        let r = MoteurPieces(troisD: true)
        r.reduire = true
        r.marges = (84, 50)
        r.poserTaille(Self.taille)
        r.installerMaintenant(e)
        #expect(r.t == 1)
        r.basculer(troisD: false)
        #expect(!r.troisD && r.enMouvement)
    }

    /// Une scene qui change de noms : sa disposition se calcule hors du fil principal, et l'ancienne
    /// scene reste affichee pendant ce temps ; la nouvelle vient ensuite, avec ses cartes.
    @Test(.timeLimit(.minutes(1))) func nouvelleDisposition() async throws {
        let (m, e) = try Self.moteur()
        var autre = e
        autre.libelles["56B1E064401F74EF"] = LibellesNoeuds.Libelle(texte: "Pont du bureau, sous la lampe de l'écran")
        #expect(autre.cleDisposition != e.cleDisposition)
        m.recevoir(autre)
        #expect(m.entree == e, "l'ancienne disposition reste affichee")
        while m.entree != autre { try await Task.sleep(for: .milliseconds(10)) }
        let bureau = try Self.indice(autre, "Bureau")
        #expect(m.cartes[bureau].largeur > 0 && m.positions.count == autre.scene.pieces.count)
    }

    /// Zoom : la vue est touchee, un redimensionnement ne la recadre plus ; Echap y ramene.
    @Test func zoomEtRetour() throws {
        let (m, _) = try Self.moteur()
        let avant = m.orbite
        m.molette(-20, precis: false)
        #expect(m.vueTouchee)
        m.sortir()
        #expect(!m.vueTouchee && m.enMouvement)
        #expect(m.orbite == avant, "le vol part de la vue courante")
    }

    /// Double-clic sur le fond : retour a la vue d'ensemble d'un geste, zoom et deplacement annules, par
    /// le vol ; le premier clic a agi seul (clic a cote). Deux clics trop espaces, dans le temps ou sur
    /// l'ecran, ne sont que deux clics. « Reduire les animations » : un fondu, la camera ne saute qu'a
    /// mi-chemin.
    @Test func doubleClicSurLeFond() throws {
        let fond = CGPoint(x: 5, y: Self.taille.height / 2)
        let (m, e) = try Self.moteur()
        m.molette(-20, precis: false)
        m.relacher(fond, a: 100)
        #expect(m.vueTouchee, "un clic simple a cote ne recadre pas")
        m.relacher(fond, a: 100 + NSEvent.doubleClickInterval + 0.05)
        #expect(m.vueTouchee, "trop tard : un autre clic simple")
        m.relacher(CGPoint(x: fond.x + 8, y: fond.y), a: 100 + NSEvent.doubleClickInterval + 0.1)
        #expect(m.vueTouchee, "trop loin : un autre clic simple")
        m.relacher(CGPoint(x: fond.x + 8, y: fond.y), a: 100 + NSEvent.doubleClickInterval + 0.2)
        #expect(!m.vueTouchee && m.enMouvement, "double-clic : le vol vers la vue d'ensemble")
        // Piece isolee et fiche ouverte : le premier clic les ferme, le second ne relance rien.
        let (n, _) = try Self.moteur()
        n.cliquer(try Self.pointDePiece(n, try Self.indice(e, "Salon")))
        n.selection = "Apple TV 4K"
        n.relacher(fond, a: 200)
        #expect(n.selection == nil && !n.estIsolee && n.isolee == nil)
        n.relacher(fond, a: 200.1)
        #expect(!n.vueTouchee && !n.estIsolee)
        // « Reduire les animations » : un fondu depuis la vue courante.
        let (r, _) = try Self.moteur()
        r.reduire = true
        r.molette(-20, precis: false)
        let zoomee = r.orbite
        r.relacher(fond, a: 300)
        r.relacher(fond, a: 300.1)
        #expect(!r.vueTouchee && r.enMouvement)
        #expect(r.orbite == zoomee, "la camera ne saute qu'a mi-chemin du fondu")
    }

    /// Ordre des couches : plateaux et equateur, blocs, liens enfant -> parent, liens entre routeurs,
    /// pastilles, liseré de la sphere, traits, noms.
    @Test func ordreDesCouches() {
        #expect(RenduCanvas.couches == [.plateaux, .blocs, .liensEnfants, .liensRouteurs, .pastilles, .sphere, .traits, .noms])
        #expect(Set(RenduCanvas.couches) == Set(RenduCanvas.Couche.allCases))
    }
}
