import AppKit
import Foundation
@testable import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : la fenetre")
struct FenetrePiecesTests {
    /// Ce qui est entre les chevrons de la premiere `nom<…>` d'un type imprime, chevrons imbriques
    /// compris ; nil sans `nom<` ni chevron fermant.
    static func entreChevrons(_ nom: String, dans type: String) -> Substring? {
        guard let ouverture = type.range(of: nom + "<") else { return nil }
        var profondeur = 1
        var i = ouverture.upperBound
        while i < type.endIndex {
            switch type[i] {
            case "<": profondeur += 1
            case ">":
                profondeur -= 1
                if profondeur == 0 { return type[ouverture.upperBound..<i] }
            default: break
            }
            i = type.index(after: i)
        }
        return nil
    }

    /// La scene de la fenetre, comme la construit `FenetrePieces` a chaque rendu ; nil sans reseau.
    static func entree(_ s: Surveillance) -> EntreeScene? {
        s.reseau.map { EntreeScene(surveillance: s, reseau: $0, places: PlacesGardees()) }
    }

    /// « Ancien » (6 min) et « perime » (15 min) ne dependent que de l'heure, que rien n'observe : la
    /// fenetre est une `TimelineView` qui se redessine chaque minute (`FenetrePieces.horloge`), avec
    /// dedans tout ce qui lit l'heure (le bas de la fenetre et sa pastille d'un releve ancien, la scene,
    /// la fiche).
    @Test func redessinChaqueMinute() throws {
        let horloge = String(reflecting: type(of: FenetrePieces.horloge))
        let corps = String(reflecting: FenetrePieces.Body.self)
        let dedans = try #require(Self.entreChevrons("TimelineView", dans: corps), "le corps est une TimelineView")
        #expect(dedans.hasPrefix(horloge), "sur l'horloge")
        for vue in ["LigneDuBas", "VuePieces", "FicheNoeud"] {
            #expect(dedans.contains(vue), "\(vue) est dans la TimelineView, pas a cote")
        }
        let recu = Date(timeIntervalSince1970: 1_790_000_000)
        let redessins = FenetrePieces.horloge.entries(from: recu, mode: .normal).prefix(20).filter { $0 >= recu }
        #expect(zip(redessins, redessins.dropFirst()).allSatisfy { $1.timeIntervalSince($0) <= 60 })
    }

    /// La marge du haut de la vue d'ensemble suit la hauteur mesuree du haut de la fenetre (la ligne des
    /// capsules, la tournee, les bandeaux, le fil) : son bas, arrondi, et l'espacement ; un bandeau ou la
    /// ligne de la tournee la font grandir. La fiche la plus haute de la demo, avec la ligne de niveau,
    /// tient dans la marge du bas ; avec les courbes de l'historique, dans la marge du bas avec courbes.
    @Test(.timeLimit(.minutes(1))) func marges() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        let sonde = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in SondeMaillageTests.canalRetenu(journal) })
        let noms = NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let sansReseau = Surveillance(mode: .direct, dossier: nil)
        func haut(_ s: Surveillance, sansPieces: Bool) -> CGFloat {
            let vue = HautPieces(moteur: MoteurPieces(), troisD: .constant(true), sansPieces: sansPieces)
            return NSHostingView(rootView: vue.environment(s).environment(sonde).environment(noms)).fittingSize.height
        }
        #expect(FenetrePieces.margeHaut(bas: 57.2) == 58 + FenetrePieces.espacement, "le bas arrondi, et l'espacement")
        #expect(demo.reseau?.estScinde == true, "la demo : reseau scinde, bandeau affiche")
        let seul = haut(sansReseau, sansPieces: false)
        let scinde = haut(demo, sansPieces: false)
        #expect(seul > 2 * CadreFeux.defaut.milieu, "la ligne des capsules, puis le fil")
        #expect(scinde > seul, "le bandeau de scission")
        #expect(haut(demo, sansPieces: true) > scinde, "le bandeau d'une maison sans pieces")
        await sonde.connecter(SondeMaillageTests.port, choisi: true)
        await journal.attendre(SondeMaillageTests.listeRetenue)
        await SondeMaillageTests.attendre { sonde.avancement != nil }
        #expect(haut(demo, sansPieces: false) > scinde, "la ligne de la tournee")
        #expect(FenetrePieces.margeHaut(bas: haut(demo, sansPieces: false)) > FenetrePieces.margeHaut(bas: scinde))
        await sonde.oublier()
        var fiche: CGFloat = 0
        let sansRouteurs = Surveillance(mode: .demo, dossier: nil)
        sansRouteurs.demarrer()
        sansRouteurs.noms.maison = NomsSceneTests.maisonSansRouteurs(sansRouteurs)
        #expect(PiecesChoisies.placement("Apple TV 4K", dans: sansRouteurs, entree: try #require(Self.entree(sansRouteurs)))
                != nil, "avec « Placer dans une pièce… »")
        for (s, id) in [(demo, "Apple TV 4K"), (demo, "3A5DFAFCAB581AAF"), (demo, "rloc:041F"), (demo, "7AF0B6D5006CF95F"),
                        (sansRouteurs, "Apple TV 4K")] {
            let entree = Self.entree(s)
            let v = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                LigneNiveauVue(ligne: .lisibles)
                FicheNoeud(id: id, entree: entree, instant: Date(), aRenommer: .constant(nil)) {}
            }
            let hote = NSHostingView(rootView: v.environment(s).environment(PiecesChoisies(fichier: nil)))
            fiche = max(fiche, hote.fittingSize.height + FenetrePieces.bord)
        }
        #expect(fiche <= FenetrePieces.margeBas(fiche: true, courbes: false), "\(fiche)")
        let historique = try CourbesFicheTests.surveillance()
        #expect(FicheNoeud.courbesVisibles(dans: historique))
        let entreeHistorique = Self.entree(historique)
        let courbes = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
            LigneNiveauVue(ligne: .lisibles)
            FicheNoeud(id: JournalMaillageTests.appareil, entree: entreeHistorique, instant: Date(),
                       aRenommer: .constant(nil)) {}
        }
        let avecCourbes = NSHostingView(rootView: courbes.environment(historique)).fittingSize.height + FenetrePieces.bord
        #expect(avecCourbes <= FenetrePieces.margeBas(fiche: true, courbes: true), "\(avecCourbes)")
    }

    /// Taille minimale de la fenetre : 820 x 680 pt.
    @Test func tailleMinimale() throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let s = Surveillance(mode: .direct, dossier: nil)
        let vue = FenetrePieces(fichierPlaces: nil)
            .environment(s)
            .environment(NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit))
            .environment(SondeMaillage(preferences: p, actif: false))
        #expect(FenetrePieces.tailleMinimale == CGSize(width: 820, height: 680))
        #expect(NSHostingView(rootView: vue).fittingSize == FenetrePieces.tailleMinimale)
    }

    /// La fiche et les bandeaux du haut glissent avec un fondu, en 0,3 s, sur la courbe de la maquette
    /// (`cubic-bezier(.2, .8, .2, 1)`) : la fiche depuis le bas, un bandeau depuis le haut ; avec
    /// « Reduire les animations », un fondu simple.
    @Test func apparitions() {
        #expect(Apparition.pour(.bottom, reduire: false) == .glisse(.bottom))
        #expect(Apparition.pour(.top, reduire: false) == .glisse(.top))
        #expect(Apparition.pour(.bottom, reduire: true) == .fondu)
        #expect(Apparition.pour(.top, reduire: true) == .fondu)
        #expect(Apparition.duree == 0.3)
        #expect(Apparition.courbe(0) == 0 && Apparition.courbe(1) == 1)
        #expect(abs(Apparition.courbe(0.5) - 0.946) < 0.002, "\(Apparition.courbe(0.5))")
        let points = stride(from: 0.0, through: 1, by: 0.05).map(Apparition.courbe)
        #expect(zip(points, points.dropFirst()).allSatisfy { $0 < $1 }, "croissante")
    }

    /// La pastille du chef : sur la fiche d'un noeud couronne, et seulement lui, les memes que la scene
    /// (`EntreeScene.chefs`) : un routeur de bordure (le chef de la demo), un routeur que la sonde seule
    /// connait (le chef de son maillage). La fiche d'un chef a la pastille en plus : elle est plus haute
    /// ou plus large que sans couronne ; celle d'un autre noeud ne change pas.
    @Test func pastilleDuChef() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        for n in e.scene.noeuds {
            #expect(FicheNoeud.couronne(n.id, entree: e) == n.chef, "\(n.id)")
        }
        #expect(FicheNoeud.couronne("Apple TV 4K", entree: e))
        #expect(!FicheNoeud.couronne("Apple TV 4K", entree: nil))
        let (s, _) = try NomsSceneTests.demoAvecRouteurThread()
        let m = try #require(s.maillage)
        let routeurs = m.routeurs.map { r in
            var r = r
            r.chef = r.id == 45
            return r
        }
        s.recevoir(Maillage(date: m.date, partition: m.partition, routeurs: routeurs, liens: m.liens, enfants: m.enfants,
                            signaux: m.signaux), a: s.maintenant)
        let thread = try #require(Self.entree(s))
        #expect(thread.chefs == ["Apple TV 4K", "rloc:B400"], "le chef de la partition, et celui du maillage")
        for n in thread.scene.noeuds {
            #expect(FicheNoeud.couronne(n.id, entree: thread) == n.chef, "\(n.id)")
        }
        func taille(_ id: String, _ e: EntreeScene) -> CGSize {
            let fiche = FicheNoeud(id: id, entree: e, instant: Date(), aRenommer: .constant(nil)) {}
            return NSHostingView(rootView: fiche.environment(s).environment(PiecesChoisies(fichier: nil))).fittingSize
        }
        var sansCouronne = thread
        sansCouronne.chefs = []
        for id in ["Apple TV 4K", "rloc:B400"] {
            let avec = taille(id, thread)
            let sans = taille(id, sansCouronne)
            #expect(avec != sans && avec.width >= sans.width && avec.height >= sans.height, "\(id) : \(avec), \(sans)")
        }
        #expect(taille("HomePod Avant", thread) == taille("HomePod Avant", sansCouronne))
    }

    /// Ligne de niveau : pieces seules, routeurs, noms masques (un, plusieurs), piece isolee.
    @Test func ligneDeNiveau() {
        #expect(LigneNiveauVue.texte(.pieces) == String(localized: "Vue d'ensemble : les pièces"))
        #expect(LigneNiveauVue.texte(.routeurs) == String(localized: "Mi-distance : les pièces et les routeurs"))
        #expect(LigneNiveauVue.texte(.masques(1)) == String(localized: "1 nom masqué faute de place : rapprochez-vous (molette)"))
        #expect(LigneNiveauVue.texte(.masques(3))
                == String(localized: "\(3) noms masqués faute de place : rapprochez-vous (molette)"))
        #expect(LigneNiveauVue.texte(.isolee("Salon")).contains("Salon"))
        #expect(LigneNiveauVue.texte(.lisibles) == String(localized: "Tous les noms sont lisibles"))
    }

    /// Sans barre de titre : le contenu couvre toute la fenetre, la barre de titre est transparente et le
    /// titre masque ; il reste celui de la fenetre. Les trois boutons restent : la capsule de gauche
    /// commence apres eux, centree sur eux ; sous macOS 27, a leur place de `CadreFeux.defaut`.
    @Test func fenetreSansBarreDeTitre() throws {
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
                               defer: false)
        fenetre.isReleasedWhenClosed = false
        fenetre.title = "Maillage Thread"
        FenetrePieces.sansBarreDeTitre(fenetre)
        #expect(fenetre.styleMask.contains(.fullSizeContentView))
        #expect(fenetre.titlebarAppearsTransparent)
        #expect(fenetre.titleVisibility == .hidden)
        #expect(fenetre.title == "Maillage Thread")
        let feux = try #require(CadreFeux(fenetre: fenetre))
        let agrandir = try #require(fenetre.standardWindowButton(.zoomButton))
        #expect(feux.droite == agrandir.convert(agrandir.bounds, to: nil).maxX)
        #expect(feux == CadreFeux.defaut)
        FenetrePieces.sansBarreDeTitre(nil)
    }

    /// La bande du haut : un clic, glisse, deplace la fenetre ; un double-clic fait ce que dit le reglage
    /// du Mac (agrandir, reduire ou rien ; « Remplir », sans API publique, agrandit). Elle agit aussi dans
    /// une fenetre inactive, et seule : AppKit ne deplace pas la fenetre a sa place.
    @Test func bandeDeLaFenetre() throws {
        #expect(ActionDoubleClic.cle == "AppleActionOnDoubleClick")
        #expect(ActionDoubleClic(reglage: "Maximize") == .agrandir)
        #expect(ActionDoubleClic(reglage: "Fill") == .agrandir)
        #expect(ActionDoubleClic(reglage: nil) == .agrandir)
        #expect(ActionDoubleClic(reglage: "Minimize") == .reduire)
        #expect(ActionDoubleClic(reglage: "None") == .rien)
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled],
                               backing: .buffered, defer: false)
        fenetre.isReleasedWhenClosed = false
        let bande = BandeFenetre.Vue(frame: NSRect(x: 0, y: 0, width: 200, height: 32))
        fenetre.contentView?.addSubview(bande)
        var glissers = 0
        var doubles = 0
        bande.glisser = { f, _ in if f === fenetre { glissers += 1 } }
        bande.doubleCliquer = { f in if f === fenetre { doubles += 1 } }
        func clic(_ n: Int) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 20, y: 10), modifierFlags: [],
                                            timestamp: 0, windowNumber: fenetre.windowNumber, context: nil,
                                            eventNumber: 0, clickCount: n, pressure: 1))
        }
        bande.mouseDown(with: try clic(1))
        #expect(glissers == 1 && doubles == 0, "un clic : la fenetre suit le glisser")
        bande.mouseDown(with: try clic(2))
        #expect(glissers == 1 && doubles == 1, "le second clic : le double-clic")
        #expect(bande.acceptsFirstMouse(for: nil))
        #expect(!bande.mouseDownCanMoveWindow)
    }

    /// Sur la ligne des trois boutons, la bande, et elle seule, recoit les clics entre les deux capsules :
    /// ni les capsules, ni la scene dessous.
    @Test func bandeEntreLesCapsules() throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let sonde = SondeMaillage(preferences: p, actif: false)
        let noms = NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit)
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
                               defer: false)
        fenetre.isReleasedWhenClosed = false
        let vue = ZStack(alignment: .topLeading) {
            Color.black.onTapGesture {}
            HautPieces(moteur: MoteurPieces(), troisD: .constant(true))
        }
        let hote = NSHostingView(rootView: vue.ignoresSafeArea().environment(s).environment(sonde).environment(noms))
        fenetre.contentView = hote
        FenetrePieces.sansBarreDeTitre(fenetre)
        hote.layoutSubtreeIfNeeded()
        fenetre.layoutIfNeeded()
        let cadre = try #require(hote.superview)
        func sous(_ x: CGFloat, _ y: CGFloat) -> NSView? { cadre.hitTest(NSPoint(x: x, y: fenetre.frame.height - y)) }
        let milieu = CadreFeux.defaut.milieu
        #expect(sous(500, milieu) is BandeFenetre.Vue, "entre les capsules")
        #expect(sous(500, 2) !== hote, "au bord du haut : le cadre de la fenetre")
        #expect(!(sous(CadreFeux.defaut.droite + HautPieces.ecartFeux + 20, milieu) is BandeFenetre.Vue), "la capsule de gauche")
        #expect(!(sous(1000 - HautPieces.bordDroit - 20, milieu) is BandeFenetre.Vue), "la capsule de droite")
        #expect(!(sous(500, 200) is BandeFenetre.Vue), "la scene")
    }

    /// La fenetre reste sombre, meme quand le Mac est en clair : sa barre, ses menus, sa fiche et ses
    /// feuilles en apparence sombre.
    @Test func fenetreToujoursSombre() {
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled],
                               backing: .buffered, defer: true)
        fenetre.isReleasedWhenClosed = false
        fenetre.appearance = NSAppearance(named: .aqua)
        FenetrePieces.assombrir(fenetre)
        #expect(fenetre.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        FenetrePieces.assombrir(nil)
    }

    /// « Placer dans une piece… » : pour un routeur de bordure que Maison ne place pas seulement, les
    /// pieces de la maison, par nom ; le choix se garde sur disque, ou en memoire sans fichier (demo).
    @Test func placerUnRouteur() throws {
        let (s, _, e) = try NomsSceneTests.demo()
        #expect(PiecesChoisies.placement("HomePod Palier", dans: s, entree: e) == nil, "Maison le place au salon")
        s.noms.maison = NomsSceneTests.maisonSansRouteurs(s)
        let entree = try #require(Self.entree(s))
        let pieces = try #require(PiecesChoisies.placement("HomePod Palier", dans: s, entree: entree)?.pieces)
        #expect(pieces == ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain", "Salon"])
        #expect(PiecesChoisies.placement("56B1E064401F74EF", dans: s, entree: entree) == nil, "un appareil")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("routeurs-\(UUID().uuidString)/pieces-routeurs.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let choisies = PiecesChoisies(fichier: url)
        choisies.choisir("Salon", .routeur("HomePod Palier"), domicile: "Maison (démo)")
        #expect(PiecesChoisies(fichier: url).choix.choix(routeur: "HomePod Palier", domicile: "Maison (démo)") == "Salon")
        let memoire = PiecesChoisies(fichier: nil)
        memoire.choisir("Salon", .routeur("HomePod Palier"), domicile: "")
        #expect(memoire.choix.choix(routeur: "HomePod Palier", domicile: "") == "Salon")
        #expect(PiecesChoisies.fichier(demo: true, sousTests: false) == nil)
        #expect(PiecesChoisies.fichier(demo: false, sousTests: true) == nil)
        #expect(PiecesChoisies.fichier(demo: false, sousTests: false)
                == Surveillance.dossierParDefaut.appendingPathComponent("pieces-routeurs.json"))
    }

    /// « Placer dans une piece… » pour un noeud que Maison ne place pas et dont l'ExtMac est connue
    /// (precision 27) : propose pour l'appareil que la sonde seule connait et pour l'annonce sans
    /// accessoire, pas pour un noeud sans ExtMac ni pour un appareil que Maison place. Premier article :
    /// « Sans piece » pour un appareil, « D'apres son nom » pour un routeur de bordure ; puis les pieces.
    /// Le choix se garde sous l'ExtMac, dans le fichier des routeurs, sans perdre les leurs ; « Sans
    /// piece » l'efface.
    @Test func placerUnAppareil() throws {
        let (s, _) = try NomsSceneTests.demoAvecInconnus()
        let e = try #require(Self.entree(s))
        let pieces = ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain",
                      "Salon"]
        let appareil = try #require(PiecesChoisies.placement("rloc:041F", dans: s, entree: e))
        #expect(appareil == PiecesChoisies.Placement(cle: .appareil("E0000000000000FF"), pieces: pieces))
        #expect(PiecesChoisies.placement("1E5019DAC2638F92", dans: s, entree: e)?.cle == .appareil("1E5019DAC2638F92"))
        #expect(PiecesChoisies.placement("rloc:0420", dans: s, entree: e) == nil, "sans ExtMac")
        #expect(PiecesChoisies.placement("56B1E064401F74EF", dans: s, entree: e) == nil, "Maison le place au bureau")
        let routeur = try #require(PiecesChoisies.placement("HomePod Palier", dans: s, entree: e))
        #expect(routeur == PiecesChoisies.Placement(cle: .routeur("HomePod Palier"), pieces: pieces))
        #expect(MenuPlacer.articles(appareil).first
                == MenuPlacer.Article(texte: String(localized: "Sans pièce"), piece: nil))
        #expect(MenuPlacer.articles(routeur).first
                == MenuPlacer.Article(texte: String(localized: "D'après son nom"), piece: nil))
        #expect(Array(MenuPlacer.articles(appareil).dropFirst())
                == pieces.map { MenuPlacer.Article(texte: $0, piece: $0) })
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("appareils-\(UUID().uuidString)/pieces-routeurs.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let domicile = "Maison (démo)"
        let choisies = PiecesChoisies(fichier: url)
        choisies.choisir("Salon", .routeur("HomePod Palier"), domicile: domicile)
        choisies.choisir("Cuisine", appareil.cle, domicile: domicile)
        let relu = PiecesChoisies(fichier: url)
        #expect(relu.pieceChoisie(.appareil("E0000000000000FF"), domicile: domicile) == "Cuisine")
        #expect(relu.choix.choix(appareil: "E0000000000000FF", domicile: domicile) == "Cuisine")
        #expect(relu.pieceChoisie(.routeur("HomePod Palier"), domicile: domicile) == "Salon")
        relu.choisir(nil, appareil.cle, domicile: domicile)
        #expect(PiecesChoisies(fichier: url).pieceChoisie(appareil.cle, domicile: domicile) == nil, "Sans piece")
        #expect(PiecesChoisies(fichier: url).choix.choix(routeur: "HomePod Palier", domicile: domicile) == "Salon")
    }

    /// Un routeur Thread qui n'est pas de bordure, connu de la sonde seule, se place sous son ExtMac
    /// (precision 27), « Sans piece » en tete du menu. Dans une maison sans pieces (ni d'accessoire, ni
    /// de zone), aucun noeud n'a de menu, appareil ou routeur.
    @Test func placerUnRouteurThread() throws {
        let (s, _) = try NomsSceneTests.demoAvecRouteurThread()
        let e = try #require(Self.entree(s))
        let noeud = try #require(e.graphe.noeud("rloc:B400"))
        #expect(noeud.inconnu && noeud.routeur && !noeud.bordure)
        let routeur = try #require(PiecesChoisies.placement("rloc:B400", dans: s, entree: e))
        #expect(routeur.cle == .appareil("E0000000000000F1"))
        #expect(MenuPlacer.articles(routeur).first == MenuPlacer.Article(texte: String(localized: "Sans pièce"), piece: nil))
        s.noms.maison?.zones = nil
        for k in s.noms.maison?.accessoires.indices ?? 0..<0 { s.noms.maison?.accessoires[k].piece = nil }
        let sansPieces = try #require(Self.entree(s))
        for id in ["rloc:B400", "rloc:041F", "1E5019DAC2638F92", "HomePod Palier"] {
            #expect(PiecesChoisies.placement(id, dans: s, entree: sansPieces) == nil, "\(id)")
        }
    }

    /// « Placer dans une piece… » lit le graphe de la scene du meme rendu (`EntreeScene`), et n'en
    /// reconstruit pas : apres l'oubli de la sonde, la scene deja construite garde « rloc:041F », que la
    /// sonde seule connait, et son menu ; la scene suivante ne l'a plus, ni le menu.
    @Test func menuDeLaScene() throws {
        let (s, _) = try NomsSceneTests.demoAvecInconnus()
        let e = try #require(Self.entree(s))
        s.oublierMaillage()
        #expect(PiecesChoisies.placement("rloc:041F", dans: s, entree: e)?.cle == .appareil("E0000000000000FF"))
        let suivante = try #require(Self.entree(s))
        #expect(suivante.maillage == nil && suivante.graphe.noeud("rloc:041F") == nil)
        #expect(PiecesChoisies.placement("rloc:041F", dans: s, entree: suivante) == nil)
    }

    /// Un choix perime (sa piece n'est plus dans Maison) ne compte plus : la scene l'ignore, et la
    /// selection du menu rend nil, le premier article (« Sans piece » pour un appareil, « D'apres son
    /// nom » pour un routeur), au lieu d'une piece que le menu n'a pas et qui ne cocherait rien. Le
    /// choix reste dans le fichier : il compte de nouveau si la piece revient.
    @Test func choixPerimeNonCoche() throws {
        let (s, _) = try NomsSceneTests.demoAvecInconnus()
        let e = try #require(Self.entree(s))
        let domicile = "Maison (démo)"
        let choisies = PiecesChoisies(fichier: nil)
        for id in ["rloc:041F", "HomePod Palier"] {
            let placement = try #require(PiecesChoisies.placement(id, dans: s, entree: e), "\(id)")
            let menu = MenuPlacer(placement: placement, domicile: domicile, choisies: choisies)
            #expect(menu.selection.wrappedValue == nil, "\(id) : aucun choix")
            menu.selection.wrappedValue = "Cuisine"
            #expect(choisies.pieceChoisie(placement.cle, domicile: domicile) == "Cuisine", "\(id) : le choix est garde")
            #expect(menu.selection.wrappedValue == "Cuisine", "\(id) : une piece du menu est cochee")
            // Cuisine n'est plus dans Maison.
            let sansCuisine = PiecesChoisies.Placement(cle: placement.cle, pieces: placement.pieces.filter { $0 != "Cuisine" })
            let perime = MenuPlacer(placement: sansCuisine, domicile: domicile, choisies: choisies)
            #expect(perime.selection.wrappedValue == nil, "\(id) : choix perime")
            #expect(choisies.pieceChoisie(placement.cle, domicile: domicile) == "Cuisine", "\(id) : le choix reste")
            #expect(menu.selection.wrappedValue == "Cuisine", "\(id) : la piece revient, le choix compte de nouveau")
        }
    }

    /// Les images de la demo : les douze de la vue par pieces, puis la fiche du chef, avec sa pastille, et
    /// la legende repliee. La fiche est celle d'un noeud couronne de la demo.
    @Test func imagesDeDemo() throws {
        #expect(CapturesPieces.cas.map(\.nom) == [
            "01-2d", "02-envol-30", "03-envol-55", "04-envol-80", "05-3d", "06-3d-tournee", "07-2d-zoom-salon",
            "08-2d-mi-distance", "09-2d-loin", "10-3d-isolee-salon", "11-2d-isolee-chambre", "12-2d-survol",
            "13-2d-fiche-du-chef", "14-2d-legende-repliee",
        ])
        #expect(CapturesPieces.cas.filter(\.legendeRepliee).map(\.nom) == ["14-2d-legende-repliee"])
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces()
        try #require(CapturesPieces.cas.first { $0.nom == "13-2d-fiche-du-chef" }).poser(m, e.scene)
        let choisi = try #require(m.selection)
        #expect(FicheNoeud.couronne(choisi, entree: e))
    }

    /// Places des pieces : a cote des identites des routeurs, ni en demo ni sous les tests.
    @Test func fichierDesPlaces() {
        #expect(FenetrePieces.fichierPlaces(demo: true, sousTests: false) == nil)
        #expect(FenetrePieces.fichierPlaces(demo: false, sousTests: true) == nil)
        #expect(FenetrePieces.fichierPlaces(demo: false, sousTests: false)?.lastPathComponent == "positions-pieces.json")
        #expect(FenetrePieces.fichierPlaces(demo: false, sousTests: false)?.deletingLastPathComponent()
                == Surveillance.dossierParDefaut)
    }
}
