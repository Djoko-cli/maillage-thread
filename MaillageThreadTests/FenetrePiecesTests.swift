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

    /// La rangee du bas (la legende, la ligne de niveau, la pastille d'un releve ancien) est en bas a gauche
    /// de la vraie fenetre, au bord (polissage B, section 2), et non au milieu : a la taille par defaut
    /// (1100 pt de large) comme a la taille minimale. Sous une fiche, la legende est cachee et la ligne de
    /// niveau est au bord ; la fiche fermee, la rangee revient a sa place. Les marges de la vue restent celles
    /// de la legende ouverte (sa hauteur mesuree, le bord et l'espacement), puis celles de la fiche. Les
    /// images de demo ne le montrent pas : `VueCapture` refait sa mise en page, alignee a gauche.
    @Test(.timeLimit(.minutes(1)), arguments: [CGSize(width: 1100, height: 760), CGSize(width: 820, height: 680)])
    func rangeeDuBasAGauche(_ taille: CGSize) async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set(false, forKey: LegendePieces.cleRepliee)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        // Un releve de la sonde ancien (plus de 6 min) : sa pastille est dans la rangee.
        demo.recevoir(try #require(demo.maillage), a: demo.maintenant.addingTimeInterval(-7 * 60))
        #expect(demo.maillageAncien)
        // La vraie fenetre, hors ecran, avec son moteur (l'etat `moteur` de la vue) et des preferences a part.
        let vue = FenetrePieces(fichierPlaces: nil)
        let etat = try #require(Mirror(reflecting: vue).children.first { $0.label == "_moteur" }?.value)
        let moteur = try #require(Mirror(reflecting: etat).descendant("_value") as? MoteurPieces)
        let fenetre = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: taille.width, height: taille.height),
                               styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered,
                               defer: false)
        fenetre.isReleasedWhenClosed = false
        defer {
            fenetre.orderOut(nil)
            fenetre.contentView = nil
        }
        fenetre.contentView = NSHostingView(rootView: vue
            .environment(demo)
            .environment(NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit))
            .environment(SondeMaillage(preferences: p, actif: false))
            .defaultAppStorage(p))
        fenetre.setContentSize(taille)
        fenetre.orderFrontRegardless()
        func cadre(_ cle: String) throws -> CGRect { try #require(moteur.cadresInterface[cle], "le cadre « \(cle) »") }
        let cas = "fenetre de \(Int(taille.width)) pt"

        // Fiche fermee : la legende au bord, puis la ligne de niveau, puis la pastille.
        try await MoteurPiecesTests.attendre { ["legende", "niveau", "ancien"].allSatisfy { moteur.cadresInterface[$0] != nil } }
        let legende = try cadre("legende")
        let niveau = try cadre("niveau")
        let ancien = try cadre("ancien")
        #expect(legende.minX == FenetrePieces.bord, "\(cas) : la legende est au bord gauche (x = \(legende.minX))")
        #expect(niveau.minX >= legende.maxX && ancien.minX >= niveau.maxX, "\(cas) : la ligne de niveau, puis la pastille, a droite de la legende")
        let ouverte = FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: legende.height)
        try await MoteurPiecesTests.attendre { moteur.marges.bas == ouverte }
        #expect(moteur.marges.bas == ouverte, "\(cas) : la marge du bas suit la legende ouverte")

        // Fiche ouverte : la legende est cachee, la ligne de niveau est au bord, sous la fiche.
        moteur.selection = "Apple TV 4K"
        try await MoteurPiecesTests.attendre { moteur.cadresInterface["fiche"] != nil && moteur.cadresInterface["legende"] == nil }
        let fiche = try cadre("fiche")
        let niveauSousFiche = try cadre("niveau")
        #expect(moteur.cadresInterface["legende"] == nil, "\(cas) : la legende est cachee sous la fiche")
        #expect(niveauSousFiche.minX == FenetrePieces.bord, "\(cas) : la ligne de niveau est au bord (x = \(niveauSousFiche.minX))")
        #expect(fiche.minX == FenetrePieces.bord && fiche.width == taille.width - 2 * FenetrePieces.bord, "\(cas) : la fiche, \(fiche)")
        let sousFiche = FenetrePieces.margeBas(fiche: true, courbes: false)
        try await MoteurPiecesTests.attendre { moteur.marges.bas == sousFiche }
        #expect(moteur.marges.bas == sousFiche, "\(cas) : la marge du bas suit la fiche")

        // Fiche fermee : la rangee revient a sa place, et la marge.
        moteur.selection = nil
        try await MoteurPiecesTests.attendre { moteur.cadresInterface["legende"] != nil && moteur.cadresInterface["fiche"] == nil }
        let legendeRevenue = try cadre("legende")
        #expect(legendeRevenue.minX == FenetrePieces.bord, "\(cas) : la legende est revenue au bord gauche (x = \(legendeRevenue.minX))")
        try await MoteurPiecesTests.attendre { moteur.marges.bas == ouverte }
        #expect(moteur.marges.bas == ouverte, "\(cas) : la marge du bas est revenue a celle de la legende ouverte")
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

    /// Avec « Reduire les animations », rien ne glisse (spec de B, sections 1 et 3 : « un simple fondu ») : la fiche
    /// et les bandeaux se fondent, chacun par sa transition, qui porte son propre fondu (`transitionAnimee`) ; ce
    /// qui se decale autour d'eux (la ligne de niveau et la pastille d'un releve ancien quand la legende se
    /// retire, le fil sous un bandeau) prend sa place sans animation : celle du conteneur est nulle. Sans le
    /// reglage, rien ne change : cela glisse avec l'element, sur la courbe de la maquette.
    @Test func reduireLesAnimationsSansGlissement() {
        let courbe = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.3)
        let fondu = Animation.easeInOut(duration: 0.3)
        #expect(courbe != fondu, "les deux se distinguent")
        for bord in [Edge.bottom, .top] {
            #expect(Apparition.animationDuConteneur(bord, reduire: false) == courbe, "\(bord) : sans le reglage, la courbe de la maquette")
            #expect(Apparition.pour(bord, reduire: false).animation == courbe, "\(bord) : l'element glisse sur la meme courbe")
            #expect(Apparition.animationDuConteneur(bord, reduire: true) == nil, "\(bord) : avec le reglage, rien ne se decale en glissant")
            #expect(Apparition.pour(bord, reduire: true).animation == fondu, "\(bord) : l'element se fond")
        }
    }

    /// Dans la vraie fenetre, avec « Reduire les animations », la rangee du bas prend sa place d'un coup quand la
    /// fiche parait : la legende, qui se retire alors, est partie des que la fiche est la, et non apres un fondu de
    /// 0,3 s, pendant lequel la ligne de niveau et la pastille glissaient avec la pile (l'animation du conteneur
    /// valait alors `easeInOut`). Les positions de la ligne de niveau ne le disent pas (SwiftUI en donne d'emblee
    /// la valeur finale) ; le retrait de la legende, si.
    @Test(.timeLimit(.minutes(1)))
    func rangeeDuBasPrendSaPlaceAvecReduire() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set(false, forKey: LegendePieces.cleRepliee)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        demo.recevoir(try #require(demo.maillage), a: demo.maintenant.addingTimeInterval(-7 * 60))
        let vue = FenetrePieces(fichierPlaces: nil)
        let etat = try #require(Mirror(reflecting: vue).children.first { $0.label == "_moteur" }?.value)
        let moteur = try #require(Mirror(reflecting: etat).descendant("_value") as? MoteurPieces)
        let fenetre = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: 1100, height: 760),
                               styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered,
                               defer: false)
        fenetre.isReleasedWhenClosed = false
        defer {
            fenetre.orderOut(nil)
            fenetre.contentView = nil
        }
        fenetre.contentView = NSHostingView(rootView: vue
            .environment(demo)
            .environment(NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit))
            .environment(SondeMaillage(preferences: p, actif: false))
            .environment(\._accessibilityReduceMotion, true)
            .defaultAppStorage(p))
        fenetre.setContentSize(CGSize(width: 1100, height: 760))
        fenetre.orderFrontRegardless()
        try await MoteurPiecesTests.attendre { ["legende", "niveau", "ancien"].allSatisfy { moteur.cadresInterface[$0] != nil } }
        #expect(moteur.reduire, "le reglage atteint la fenetre")
        #expect(moteur.cadresInterface["legende"] != nil, "la legende est ouverte")

        // La fiche parait : la legende est partie sans attendre un fondu (0,15 s au plus, contre 0,3 s).
        moteur.selection = "Apple TV 4K"
        try await MoteurPiecesTests.attendre { moteur.cadresInterface["fiche"] != nil }
        let debut = ProcessInfo.processInfo.systemUptime
        try await MoteurPiecesTests.attendre {
            moteur.cadresInterface["legende"] == nil || ProcessInfo.processInfo.systemUptime - debut > 0.15
        }
        #expect(moteur.cadresInterface["legende"] == nil, "la legende se retire d'un coup, sans fondu")
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

    /// La pastille du chef tient sur une ligne dans la fiche d'un routeur de bordure couronne, a la largeur
    /// par defaut de la fenetre (1100 pt, `MaillageThreadApp`) comme a sa largeur minimale : les colonnes de
    /// la fiche se serrent, et une pastille qui prend la largeur qu'on lui laisse passait a la ligne. Mesure
    /// sur la fiche d'« Apple TV 4K » avec les courbes de l'historique (comme avec une sonde), ou la colonne
    /// de la couronne est la plus haute : la couronne y ajoute sa pastille et son espacement, `uneLigne`
    /// dans une fenetre assez large pour que tout tienne sur une ligne ; une deuxieme ligne en ajouterait
    /// davantage.
    @Test func pastilleDuChefSurUneLigne() throws {
        let s = try CourbesFicheTests.surveillance()
        let id = "Apple TV 4K"
        let avec = try #require(Self.entree(s))
        #expect(s.instantane?.routeur(id) != nil && FicheNoeud.couronne(id, entree: avec), "un routeur de bordure couronne")
        var sans = avec
        sans.chefs = []
        // Ce que la couronne ajoute a la hauteur de la fiche dans une fenetre de `fenetre` pt de large : la fiche
        // est posee avec le bord de chaque cote (`FenetrePieces`).
        func ajout(fenetre: CGFloat) -> CGFloat {
            func hauteur(_ e: EntreeScene) -> CGFloat {
                let fiche = FicheNoeud(id: id, entree: e, instant: Date(), aRenommer: .constant(nil)) {}
                return NSHostingView(rootView: fiche.frame(width: fenetre - 2 * FenetrePieces.bord)
                    .environment(s).environment(PiecesChoisies(fichier: nil))).fittingSize.height
            }
            return hauteur(avec) - hauteur(sans)
        }
        let pastille = NSHostingView(rootView: PastilleChef()).fittingSize.height
        let uneLigne = ajout(fenetre: 3000)
        #expect(uneLigne >= pastille && uneLigne < 2 * pastille, "sur une ligne : \(uneLigne) pt pour une pastille de \(pastille)")
        for fenetre in [1100, FenetrePieces.tailleMinimale.width] {
            let plus = ajout(fenetre: fenetre)
            #expect(plus > 0, "fenetre de \(Int(fenetre)) pt : la couronne agrandit la fiche, dont sa colonne est la plus haute")
            #expect(plus <= uneLigne + 0.5, "fenetre de \(Int(fenetre)) pt : la couronne ajoute \(plus) pt, plus que \(uneLigne) : la pastille passe a la ligne")
        }
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

    /// Une fenetre faite comme celle que pose `.windowStyle(.hiddenTitleBar)` (releve dans l'app, en demo, le
    /// 02/10) : le contenu sous la barre de titre, la barre transparente, le titre masque. Les tests montent
    /// leur fenetre a la main, sans la scene de l'app.
    static func sansBarreDeTitre(_ fenetre: NSWindow) {
        fenetre.styleMask.insert(.fullSizeContentView)
        fenetre.titlebarAppearsTransparent = true
        fenetre.titleVisibility = .hidden
    }

    /// Sans barre de titre (polissage B, section 1) : la scene du graphe, et elle seule, porte le style
    /// `.hiddenTitleBar`. SwiftUI pose alors lui-meme la barre de titre transparente et le titre masque, et les
    /// garde a chaque mise a jour de la fenetre ; le crochet d'AppKit d'avant, pose une fois, etait defait par
    /// SwiftUI (diagnostic du 02/10 : barre opaque des 0,285 s). Le titre « Maillage Thread » reste celui de la
    /// fenetre (Mission Control, menu Fenetre). Les trois boutons restent : la capsule de gauche commence apres
    /// eux, centree sur eux ; dans une fenetre ainsi faite, sous macOS 27, a leur place de `CadreFeux.defaut`.
    @Test func fenetreSansBarreDeTitre() throws {
        let scenes = String(reflecting: MaillageThreadApp.Body.self)
        let graphe = try #require(scenes.range(of: "FenetrePieces"), "la scene du graphe")
        let journal = try #require(scenes.range(of: "FenetreJournal"), "la scene du journal")
        #expect(scenes[graphe.upperBound..<journal.lowerBound].contains("HiddenTitleBarWindowStyle"),
                "le graphe sans barre de titre")
        #expect(!scenes[journal.upperBound...].contains("HiddenTitleBarWindowStyle"), "le journal garde la sienne")
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
                               defer: false)
        fenetre.isReleasedWhenClosed = false
        fenetre.title = "Maillage Thread"
        Self.sansBarreDeTitre(fenetre)
        #expect(fenetre.title == "Maillage Thread")
        let feux = try #require(CadreFeux(fenetre: fenetre))
        let agrandir = try #require(fenetre.standardWindowButton(.zoomButton))
        #expect(feux.droite == agrandir.convert(agrandir.bounds, to: nil).maxX)
        #expect(feux == CadreFeux.defaut)
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
        Self.sansBarreDeTitre(fenetre)
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

    /// La premiere sous-vue de ce type, dans `racine` ou plus bas.
    static func sousVue<T: NSView>(_ type: T.Type, dans racine: NSView) -> T? {
        if let trouvee = racine as? T { return trouvee }
        for sous in racine.subviews {
            if let trouvee = sousVue(type, dans: sous) { return trouvee }
        }
        return nil
    }

    /// Chaque capsule du haut garde la largeur de son contenu (spec de B, section 1 : « Chaque capsule prend la
    /// taille de son contenu ») : la bande vide entre elles prend la place qui reste, meme a la taille minimale de
    /// la fenetre, en 2D comme en 3D (ou « Rotation lente » s'ajoute a la capsule de droite). Sans cela, les deux
    /// capsules et la bande se partageaient la place, et la capsule du reseau tronquait ses boutons (« Appareil… »,
    /// « A… »). Tout tient : la bande commence au bord de la capsule de gauche, finit au bord de celle de droite, et
    /// n'est pas vide.
    @Test(arguments: [false, true])
    func capsulesALeurLargeurIdeale(troisD: Bool) throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let sonde = SondeMaillage(preferences: p, actif: false)
        let noms = NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit)
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let moteur = MoteurPieces(troisD: troisD)
        func hote(_ vue: some View) -> NSHostingView<AnyView> {
            NSHostingView(rootView: AnyView(vue.environment(s).environment(sonde).environment(noms)))
        }
        // La largeur de chaque capsule seule : celle de son contenu.
        let gauche = hote(BarreOutils().capsuleDeVerre()).fittingSize.width
        let droite = hote(CommandesVue(moteur: moteur, troisD: .constant(troisD)).capsuleDeVerre()).fittingSize.width
        // Le haut de la fenetre a sa taille minimale, comme `FenetrePieces` le pose.
        let largeur = FenetrePieces.tailleMinimale.width
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: largeur, height: 200),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
                               defer: false)
        fenetre.isReleasedWhenClosed = false
        defer { fenetre.contentView = nil }
        let haut = hote(HautPieces(moteur: moteur, troisD: .constant(troisD))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading))
        fenetre.contentView = haut
        Self.sansBarreDeTitre(fenetre)
        haut.layoutSubtreeIfNeeded()
        fenetre.layoutIfNeeded()
        let bande = try #require(Self.sousVue(BandeFenetre.Vue.self, dans: haut), "la bande")
        let cadre = bande.convert(bande.bounds, to: haut)
        let cas = "3D : \(troisD), fenetre de \(Int(largeur)) pt, capsules de \(gauche) et \(droite) pt"
        #expect(abs(cadre.minX - (CadreFeux.defaut.droite + HautPieces.ecartFeux + gauche)) < 1,
                "\(cas) : la bande commence au bord de la capsule du reseau (x = \(cadre.minX))")
        #expect(abs(cadre.maxX - (largeur - HautPieces.bordDroit - droite)) < 1,
                "\(cas) : la bande finit au bord de la capsule de la vue (x = \(cadre.maxX))")
        #expect(cadre.width > 0, "\(cas) : la bande n'est pas vide (\(cadre.width) pt)")
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
