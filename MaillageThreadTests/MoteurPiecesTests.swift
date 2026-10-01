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
        return (moteur(e, fichier: fichier), e)
    }

    /// Un moteur sur la scene `e`, dispose, et une premiere image dessinee (hors fenetre).
    static func moteur(_ e: EntreeScene, fichier: URL? = nil) -> MoteurPieces {
        let m = MoteurPieces(fichierPlaces: fichier)
        m.marges = (84, 50)
        m.poserTaille(taille)
        m.installerMaintenant(e)
        dessiner(m)
        return m
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

    /// Disposition installee, premiere image : un nom par noeud, etage et piece, et « ⌂ Maison ».
    @Test func installerEtDessiner() throws {
        let (m, e) = try Self.moteur()
        #expect(m.pret)
        #expect(m.positions.count == e.scene.pieces.count && m.geometrie.rayons.count == 2)
        #expect(m.etiquettes.count == e.scene.noeuds.count + e.scene.etages.count + e.scene.pieces.count + 1)
        #expect(m.projetee?.blocs.count == e.scene.pieces.count)
        #expect(m.etiquettes.contains { $0.vu })
    }

    /// La ligne de niveau suit le zoom (precision 7 du plan 4b) : sous k = 0,42, les pieces seules ;
    /// jusqu'a 0,6, les pieces et les routeurs ; au-dela, les noms masques ou tous lisibles. Une piece
    /// isolee la remplace.
    @Test func ligneDeNiveauSelonLeZoom() throws {
        let (m, e) = try Self.moteur()
        m.fige = true
        func texte(_ k: Double) throws -> String {
            m.poserZoom(echelle: k, vers: nil)
            Self.dessiner(m)
            let p = try #require(m.projetee)
            #expect(abs(p.echelle - k) < 1e-6)
            return LigneNiveauVue.texte(m.ligneNiveau)
        }
        #expect(try texte(0.3) == String(localized: "Vue d'ensemble : les pièces"))
        #expect(try texte(0.4) == String(localized: "Vue d'ensemble : les pièces"))
        #expect(try texte(0.45) == String(localized: "Mi-distance : les pièces et les routeurs"))
        #expect(try texte(0.55) == String(localized: "Mi-distance : les pièces et les routeurs"))
        let loin = try texte(1)
        switch m.ligneNiveau {
        case .lisibles:
            #expect(loin == String(localized: "Tous les noms sont lisibles"))
        case .masques(1):
            #expect(loin == String(localized: "1 nom masqué faute de place : rapprochez-vous (molette)"))
        case .masques(let n):
            #expect(n > 1)
            #expect(loin == String(localized: "\(n) noms masqués faute de place : rapprochez-vous (molette)"))
        default:
            Issue.record("au-dela de 0,6 : les noms masques ou tous lisibles, pas \(m.ligneNiveau)")
        }
        m.poserIsolement(try Self.indice(e, "Salon"))
        Self.dessiner(m)
        let isolee = String(localized: "Pièce isolée : \("Salon") · clic sur une autre pièce pour y aller, clic à côté ou Échap pour revenir")
        #expect(LigneNiveauVue.texte(m.ligneNiveau) == isolee)
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

    /// Un releve recu pendant le glisser d'une piece (meme structure, un etat change) attend le
    /// relachement : la piece ne saute pas a son ancienne place, et la place gardee est celle du geste ;
    /// la scene s'applique ensuite, avec cette place.
    @Test func relevePendantUnGlisser() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.moteur(fichier: url)
        var autre = e
        autre.apparences["Apple TV 4K"] = DessinNoeud.Apparence(forme: .anneau, couleur: .appareil(.disparu))
        #expect(autre != e && autre.cleDisposition == e.cleDisposition)
        let cuisine = try Self.indice(e, "Cuisine")
        let avant = m.positions[cuisine]
        let depart = try Self.pointDePiece(m, cuisine)
        m.glisser(depart, depart: depart)
        m.glisser(CGPoint(x: depart.x + 30, y: depart.y), depart: depart)
        let pendant = m.positions[cuisine]
        #expect(pendant != avant)
        m.recevoir(autre)
        #expect(m.entree == e, "pendant le glisser, la scene attend")
        #expect(m.positions[cuisine] == pendant, "la piece ne revient pas a sa place d'avant le geste")
        m.glisser(CGPoint(x: depart.x + 60, y: depart.y), depart: depart)
        let fin = m.positions[cuisine]
        #expect(fin.x > pendant.x)
        m.relacher(CGPoint(x: depart.x + 60, y: depart.y))
        let gardee = PlacesGardees.lire(url).maison(e.domicile).etages["zone:Rez-de-chaussée"]?["piece:Cuisine"]
        #expect(gardee == PlacesGardees.Place(x: fin.x, z: fin.y), "la place gardee est celle du geste")
        #expect(m.entree == autre, "au relachement, la scene en attente s'applique")
        #expect(m.positions[cuisine] == fin, "avec la place du geste")
        // Glisser annule (sans relachement) : le geste suivant, parti d'ailleurs, le clot ; la piece garde
        // sa place, et la scene en attente s'applique a la fin de ce geste.
        let (n, _) = try Self.moteur()
        n.glisser(depart, depart: depart)
        n.glisser(CGPoint(x: depart.x + 30, y: depart.y), depart: depart)
        let annule = n.positions[cuisine]
        n.recevoir(autre)
        let fond = CGPoint(x: 5, y: Self.taille.height / 2)
        n.glisser(fond, depart: fond)
        #expect(n.entree == e && n.places.maison(e.domicile).etages["zone:Rez-de-chaussée"]?["piece:Cuisine"]
                == PlacesGardees.Place(x: annule.x, z: annule.y))
        n.relacher(fond)
        #expect(n.entree == autre && n.positions[cuisine] == annule)
    }

    /// Un releve qui change la structure (une piece de moins) pendant le glisser d'une piece : ni
    /// indice perime ni plantage, que sa disposition finisse pendant le geste ou soit lancee apres ; la
    /// scene s'applique au relachement, la piece glissee a la place du geste.
    @Test(.timeLimit(.minutes(1))) func releveQuiChangeLaStructurePendantUnGlisser() async throws {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        for k in maison.accessoires.indices where maison.accessoires[k].piece == "Chambre d'amis" {
            maison.accessoires[k].piece = "Chambre"
        }
        s.noms.maison = maison
        let autre = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
        // Disposition finie pendant le geste (`installerMaintenant` : comme un calcul qui se termine).
        let (m, e) = try Self.moteur()
        #expect(autre.scene.pieces.count == e.scene.pieces.count - 1)
        let sdb = try Self.indice(e, "Salle de bain")
        #expect(sdb >= autre.scene.pieces.count, "son indice n'existe plus dans la nouvelle scene")
        let depart = try Self.pointDePiece(m, sdb)
        m.glisser(depart, depart: depart)
        m.glisser(CGPoint(x: depart.x + 20, y: depart.y), depart: depart)
        m.installerMaintenant(autre)
        #expect(m.entree == e, "pendant le glisser, la scene attend")
        m.glisser(CGPoint(x: depart.x + 40, y: depart.y), depart: depart)
        let fin = m.positions[sdb]
        m.relacher(CGPoint(x: depart.x + 40, y: depart.y))
        #expect(m.entree == autre && m.positions.count == autre.scene.pieces.count)
        #expect(m.positions[try Self.indice(autre, "Salle de bain")] == fin)
        // Releve recu pendant le geste : sa disposition, lancee au relachement, garde la place du geste.
        let (n, _) = try Self.moteur()
        let depart2 = try Self.pointDePiece(n, sdb)
        n.glisser(depart2, depart: depart2)
        n.glisser(CGPoint(x: depart2.x + 20, y: depart2.y), depart: depart2)
        n.recevoir(autre)
        n.glisser(CGPoint(x: depart2.x + 40, y: depart2.y), depart: depart2)
        let fin2 = n.positions[sdb]
        n.relacher(CGPoint(x: depart2.x + 40, y: depart2.y))
        while n.entree != autre { try await Task.sleep(for: .milliseconds(10)) }
        #expect(n.positions[try Self.indice(autre, "Salle de bain")] == fin2)
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

    /// L'ordre des etages change pendant le calcul d'une disposition (la cle de la disposition l'ignore,
    /// la scene suivante range autrement ses pieces) : la disposition, gardee par cles d'apres la scene
    /// pour laquelle elle a ete calculee, ne prete a aucune piece la place ou la carte d'une autre, ni
    /// a un etage le rayon d'un autre. Trois etages : « Sans piece » reste sur celui du bas.
    @Test(.timeLimit(.minutes(1))) func ordreDesEtagesPendantUnCalcul() async throws {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        maison.zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Chambre d'amis"]),
                        ZoneMaison(nom: "Combles", pieces: ["Bureau", "Salle de bain"])]
        s.noms.maison = maison
        let e = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
        let m = Self.moteur(e)
        s.renommer("56B1E064401F74EF", en: "Pont du bureau, sous la lampe de l'écran")
        let autre = EntreeScene(surveillance: s, reseau: r, places: m.places)
        #expect(autre.cleDisposition != e.cleDisposition)
        m.recevoir(autre)
        m.deplacerEtage(1, de: 1)
        let inverse = EntreeScene(surveillance: s, reseau: r, places: m.places)
        #expect(inverse.cleDisposition == autre.cleDisposition)
        #expect(inverse.scene.etages.map(\.id) == ["zone:Rez-de-chaussée", "zone:Combles", "zone:Étage"])
        m.recevoir(inverse)
        #expect(m.entree == e, "l'ancienne disposition reste affichee pendant le calcul")
        while m.entree != inverse { try await Task.sleep(for: .milliseconds(10)) }
        // La meme disposition, calculee sur le fil principal pour la scene du calcul.
        let ref = Self.moteur(autre)
        for (i, p) in inverse.scene.pieces.enumerated() {
            let j = try #require(autre.scene.pieces.firstIndex { $0.id == p.id })
            #expect(m.positions[i] == ref.positions[j] && m.cartes[i] == ref.cartes[j], "\(p.id)")
        }
        for (k, et) in inverse.scene.etages.enumerated() {
            let l = try #require(autre.scene.etages.firstIndex { $0.id == et.id })
            #expect(m.geometrie.rayons[k] == ref.geometrie.rayons[l], "\(et.id)")
        }
    }

    /// Une piece lachee pendant le calcul d'une disposition garde la place du geste : le calcul est
    /// relance avec elle, et elle ne saute pas, a sa fin, a la place qu'il lui donnait.
    @Test(.timeLimit(.minutes(1))) func pieceLacheePendantUnCalcul() async throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (s, r, e) = try NomsSceneTests.demo()
        let m = Self.moteur(e, fichier: url)
        s.renommer("56B1E064401F74EF", en: "Pont du bureau, sous la lampe de l'écran")
        let autre = EntreeScene(surveillance: s, reseau: r, places: m.places)
        m.recevoir(autre)
        let cuisine = try Self.indice(e, "Cuisine")
        let depart = try Self.pointDePiece(m, cuisine)
        m.glisser(depart, depart: depart)
        m.glisser(CGPoint(x: depart.x + 40, y: depart.y), depart: depart)
        m.relacher(CGPoint(x: depart.x + 40, y: depart.y))
        let fin = m.positions[cuisine]
        #expect(m.entree == e, "le calcul n'est pas fini")
        while m.entree != autre { try await Task.sleep(for: .milliseconds(10)) }
        #expect(m.positions[try Self.indice(autre, "Cuisine")] == fin, "la piece garde la place du geste")
        let gardee = PlacesGardees.lire(url).maison(e.domicile).etages["zone:Rez-de-chaussée"]?["piece:Cuisine"]
        #expect(gardee == PlacesGardees.Place(x: fin.x, z: fin.y))
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
