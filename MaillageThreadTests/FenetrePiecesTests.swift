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

    /// La vraie fenetre de la vue par pieces, hors ecran, de `taille` pt, sur la surveillance `s`, avec les
    /// preferences `p` (jamais celles de l'app) et « Reduire les animations » impose ; et son moteur (l'etat
    /// `moteur` de la vue). La vue couvre toute la fenetre, de `taille` pt comme dans l'app (`setContentSize`
    /// ajouterait la barre de titre), faite comme celle de l'app (`sansBarreDeTitre`). `sonde` : la sonde de la vue
    /// (sinon une sonde inactive, sans sonde retenue). A retirer par `fermer`.
    static func fenetre(_ s: Surveillance, taille: CGSize, preferences p: UserDefaults,
                        reduire: Bool = false, sonde: SondeMaillage? = nil) throws -> (NSWindow, MoteurPieces) {
        let vue = FenetrePieces(fichierPlaces: nil)
        let etat = try #require(Mirror(reflecting: vue).children.first { $0.label == "_moteur" }?.value)
        let moteur = try #require(Mirror(reflecting: etat).descendant("_value") as? MoteurPieces)
        let fenetre = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: taille.width, height: taille.height),
                               styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered,
                               defer: false)
        fenetre.isReleasedWhenClosed = false
        Self.sansBarreDeTitre(fenetre)
        fenetre.contentView = NSHostingView(rootView: vue
            .environment(s)
            .environment(NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit))
            .environment(sonde ?? SondeMaillage(preferences: p, actif: false))
            .environment(\._accessibilityReduceMotion, reduire)
            .defaultAppStorage(p))
        fenetre.setFrame(NSRect(origin: fenetre.frame.origin, size: taille), display: false)
        fenetre.orderFrontRegardless()
        return (fenetre, moteur)
    }

    static func fermer(_ fenetre: NSWindow) {
        fenetre.orderOut(nil)
        fenetre.contentView = nil
    }

    /// Un clic de la souris sur le point `p` de la vue (en points, depuis le haut), envoye a la fenetre : le vrai
    /// chemin d'un clic, par `sendEvent`, jusqu'au geste ou au bouton de SwiftUI.
    static func cliquer(_ fenetre: NSWindow, en p: CGPoint) async throws {
        let dansFenetre = NSPoint(x: p.x, y: fenetre.frame.height - p.y)
        for (genre, pression) in [(NSEvent.EventType.leftMouseDown, Float(1)), (.leftMouseUp, Float(0))] {
            let evenement = try #require(NSEvent.mouseEvent(with: genre, location: dansFenetre, modifierFlags: [],
                                                            timestamp: ProcessInfo.processInfo.systemUptime,
                                                            windowNumber: fenetre.windowNumber, context: nil,
                                                            eventNumber: 0, clickCount: 1, pressure: pression))
            fenetre.sendEvent(evenement)
            if genre == .leftMouseDown { try await Task.sleep(for: .milliseconds(10)) }
        }
    }

    /// Duree du recadrage de la vue (les marges en route, `margesEnRoute`) : du premier echantillon ou elles le sont au
    /// premier ou elles ne le sont plus ; nil si elles ne partent pas, ou ne s'arretent pas, en 2 s.
    static func dureeDuRecadrage(_ moteur: MoteurPieces) async throws -> Double? {
        let t0 = ProcessInfo.processInfo.systemUptime
        var debut: Double?
        while ProcessInfo.processInfo.systemUptime - t0 < 2 {
            let t = ProcessInfo.processInfo.systemUptime - t0
            if moteur.margesEnRoute {
                if debut == nil { debut = t }
            } else if let debut {
                return t - debut
            }
            try await Task.sleep(for: .milliseconds(3))
        }
        return nil
    }

    /// Le premier clic sur une piece agit aussi dans une fenetre inactive (verification du 02/10) : sans
    /// `allowsWindowActivationEvents`, AppKit le gardait pour activer la fenetre, et la piece ne s'isolait pas (le
    /// diagnostic l'a reproduit : 0 fois sur 4). Un clic envoye a la vraie fenetre, hors ecran et jamais cle, au
    /// milieu du salon.
    @Test(.timeLimit(.minutes(1))) func premierClicDansUneFenetreInactive() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let (fenetre, moteur) = try Self.fenetre(demo, taille: CGSize(width: 1100, height: 760), preferences: p)
        defer { Self.fermer(fenetre) }
        // La vue en place : la disposition posee, la legende mesuree, les marges arrivees.
        try await MoteurPiecesTests.attendre {
            moteur.pret && moteur.projetee != nil && moteur.cadresInterface["legende"] != nil && !moteur.margesEnRoute
        }
        try await Task.sleep(for: .milliseconds(500))
        let salon = try MoteurPiecesTests.indice(try #require(moteur.entree), "Salon")
        // Un point du salon ou un clic l'isole : sur sa boite, loin des pastilles, des noms et de l'interface.
        let ancre = try #require(moteur.projetee?.ancresPieces[salon])
        let points = stride(from: 0.9, through: 0.1, by: -0.1).flatMap { fy in
            stride(from: 0.9, through: 0.1, by: -0.1).map { fx in
                CGPoint(x: ancre.minX + ancre.width * fx, y: ancre.minY + ancre.height * fy)
            }
        }
        let point = try #require(points.first { p in
            moteur.pieceSous(p) == salon && moteur.noeudSous(p) == nil
                && !moteur.cadresInterface.values.contains { $0.insetBy(dx: -4, dy: -4).contains(p) }
        })
        #expect(moteur.focus == nil && !fenetre.isKeyWindow, "une fenetre inactive, sans piece isolee")
        try await Self.cliquer(fenetre, en: point)
        try await MoteurPiecesTests.attendre { moteur.focus != nil }
        #expect(moteur.focus == salon && moteur.estIsolee, "le premier clic isole la piece (focus \(String(describing: moteur.focus)))")
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
    /// ligne de la tournee la font grandir. Celle du bas, mesuree elle aussi : `margeDuBasMesuree`.
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
    }

    /// Ce qui est pose en bas de la vraie fenetre : la pile, de haut en bas la rangee de la legende et de la ligne de
    /// niveau, puis la fiche ; son haut, le plus haut des cadres de ses elements (nil avant qu'ils soient poses).
    static func hautDeLaPile(_ moteur: MoteurPieces) -> CGFloat? {
        ["legende", "niveau", "ancien", "fiche"].compactMap { moteur.cadresInterface[$0] }.map(\.minY).min()
    }

    /// La marge du bas suit la hauteur mesuree de tout ce qui est pose en bas (verification du 02/10, comme la marge
    /// du haut suit le bandeau ; elle remplace les 190 et 360 pt fixes de la fiche) : dans la vraie fenetre, fiche
    /// fermee ou ouverte, legende ouverte ou repliee, la vue d'ensemble se cadre juste au-dessus de la pile (a
    /// l'espacement pres), sauf la legende repliee sans fiche, qui deborde un peu sur la vue (30 pt, la marge
    /// d'avant). La fiche la plus haute de la demo, et une fiche avec les courbes de l'historique, y tiennent aussi.
    @Test(.timeLimit(.minutes(2))) func margeDuBasMesuree() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let taille = CGSize(width: 1100, height: 760)
        // La vue se cadre juste au-dessus de la pile (le bas de son cadre, a l'espacement pres).
        func auDessusDeLaPile(_ moteur: MoteurPieces, _ taille: CGSize, _ cas: String) async throws {
            try await MoteurPiecesTests.attendre {
                Self.hautDeLaPile(moteur).map { abs((taille.height - moteur.marges.bas) - ($0 - FenetrePieces.espacement)) < 1 } == true
            }
            let haut = try #require(Self.hautDeLaPile(moteur), "\(cas) : la pile du bas")
            #expect(abs((taille.height - moteur.marges.bas) - (haut - FenetrePieces.espacement)) < 1,
                    "\(cas) : la vue finit a \(taille.height - moteur.marges.bas), la pile commence a \(haut)")
        }
        for repliee in [false, true] {
            // La preference, avant la fenetre : `@AppStorage` la lit a l'ouverture.
            p.set(repliee, forKey: LegendePieces.cleRepliee)
            let (fenetre, moteur) = try Self.fenetre(demo, taille: taille, preferences: p)
            defer { Self.fermer(fenetre) }
            try await MoteurPiecesTests.attendre { moteur.cadresInterface["legende"] != nil && moteur.pret }
            if repliee {
                try await MoteurPiecesTests.attendre { moteur.marges.bas == 30 && moteur.cadresInterface["fiche"] == nil }
                #expect(moteur.marges.bas == 30, "legende repliee, sans fiche : la marge d'avant")
            } else {
                try await auDessusDeLaPile(moteur, taille, "legende ouverte, sans fiche")
            }
            for id in ["Apple TV 4K", "3A5DFAFCAB581AAF"] {
                moteur.selection = id
                try await MoteurPiecesTests.attendre { moteur.cadresInterface["fiche"] != nil }
                try await auDessusDeLaPile(moteur, taille, "legende \(repliee ? "repliee" : "ouverte"), fiche de \(id)")
            }
        }
        // Une fiche avec les courbes de l'historique, dans une grande fenetre (la legende y reste ouverte).
        p.set(false, forKey: LegendePieces.cleRepliee)
        let historique = try CourbesFicheTests.surveillance()
        #expect(FicheNoeud.courbesVisibles(dans: historique))
        let grande = CGSize(width: 1400, height: 1100)
        let (autre, m) = try Self.fenetre(historique, taille: grande, preferences: p)
        defer { Self.fermer(autre) }
        try await MoteurPiecesTests.attendre { m.cadresInterface["legende"] != nil && m.pret }
        m.selection = JournalMaillageTests.appareil
        try await MoteurPiecesTests.attendre { m.cadresInterface["fiche"].map { $0.height > 250 } == true }
        let fiche = try #require(m.cadresInterface["fiche"])
        #expect(fiche.height > 250, "la fiche et ses courbes : \(fiche.height) pt")
        try await auDessusDeLaPile(m, grande, "fiche avec courbes")
    }

    /// La legende reste visible quand une fiche est ouverte (verification du 02/10) : elle monte au-dessus de la fiche
    /// au lieu de disparaitre. De haut en bas : la rangee de la legende et de la ligne de niveau, puis la fiche ; la vue
    /// d'ensemble se cadre au-dessus de tout cela. A la fermeture, la fiche part et la legende redescend.
    @Test(.timeLimit(.minutes(1))) func legendeAuDessusDeLaFiche() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set(false, forKey: LegendePieces.cleRepliee)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let taille = CGSize(width: 1100, height: 760)
        let (fenetre, moteur) = try Self.fenetre(demo, taille: taille, preferences: p)
        defer { Self.fermer(fenetre) }
        try await MoteurPiecesTests.attendre { moteur.cadresInterface["legende"] != nil }
        let ouverte = try #require(moteur.cadresInterface["legende"])
        moteur.selection = "Apple TV 4K"
        // La fiche arrivee : son cadre suit son glissement, puis s'arrete au bas de la vue.
        try await MoteurPiecesTests.attendre {
            moteur.cadresInterface["fiche"].map { abs($0.maxY - (taille.height - FenetrePieces.bord)) < 0.5 } == true
        }
        let legende = try #require(moteur.cadresInterface["legende"], "la legende reste")
        let niveau = try #require(moteur.cadresInterface["niveau"])
        let fiche = try #require(moteur.cadresInterface["fiche"])
        #expect(legende.size == ouverte.size, "ouverte, comme sans fiche : \(legende.size), \(ouverte.size)")
        #expect(legende.maxY <= fiche.minY - FenetrePieces.espacement + 0.5 && niveau.maxY <= fiche.minY,
                "la rangee au-dessus de la fiche : \(legende), \(niveau), \(fiche)")
        #expect(abs(fiche.maxY - (taille.height - FenetrePieces.bord)) < 0.5, "la fiche en bas : \(fiche)")
        try await MoteurPiecesTests.attendre { !moteur.margesEnRoute && taille.height - moteur.marges.bas <= legende.minY }
        #expect(moteur.cadre.maxY <= legende.minY, "la vue au-dessus de la legende : \(moteur.cadre)")
        moteur.selection = nil
        try await MoteurPiecesTests.attendre { moteur.cadresInterface["fiche"] == nil }
        let revenue = try #require(moteur.cadresInterface["legende"])
        #expect(abs(revenue.maxY - (taille.height - FenetrePieces.bord)) < 0.5, "la legende redescendue : \(revenue)")
    }

    /// Dans une petite fenetre, la legende se replie d'elle-meme tant qu'une fiche est ouverte, si, ouverte, elle ne
    /// laissait a la scene que moins de 230 pt (`FenetrePieces.sceneMinimale`) ; elle se rouvre a la fermeture de la
    /// fiche. Elle ne se replie que si c'est necessaire : pas dans la fenetre par defaut avec une fiche de la demo.
    /// Son repli garde (la preference) ne change pas, et une legende repliee par Djoko reste repliee. La plus petite
    /// fenetre (`tailleMinimale`) : la vue y fait 732 pt de haut, barre de titre de 52 pt comprise.
    @Test(.timeLimit(.minutes(2))) func repliDeLaLegendeFauteDePlace() async throws {
        // Le seuil.
        let m = FenetrePieces.sceneMinimale
        #expect(m == 230)
        let marge = FenetrePieces.margeBas(pile: 220 + FenetrePieces.espacement + 150)
        #expect(!FenetrePieces.repliDePlace(hauteur: 98 + marge + m, margeHaut: 98, legende: 220, fiche: 150), "230 pt : assez")
        #expect(FenetrePieces.repliDePlace(hauteur: 98 + marge + m - 1, margeHaut: 98, legende: 220, fiche: 150), "229 pt : repliee")
        #expect(!FenetrePieces.repliDePlace(hauteur: 300, margeHaut: 98, legende: nil, fiche: 150), "legende jamais mesuree ouverte")
        #expect(!FenetrePieces.repliDePlace(hauteur: 300, margeHaut: 98, legende: 220, fiche: nil), "fiche pas encore mesuree")
        // Dans la vraie fenetre.
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        func essai(_ s: Surveillance, _ taille: CGSize, _ id: String, repliee: Bool) async throws -> (ficheOuverte: CGFloat, apres: CGFloat) {
            p.set(repliee, forKey: LegendePieces.cleRepliee)
            let (fenetre, moteur) = try Self.fenetre(s, taille: taille, preferences: p)
            defer { Self.fermer(fenetre) }
            try await MoteurPiecesTests.attendre { moteur.cadresInterface["legende"] != nil && moteur.pret }
            try await Task.sleep(for: .milliseconds(200))
            moteur.selection = id
            try await MoteurPiecesTests.attendre { moteur.cadresInterface["fiche"] != nil }
            try await Task.sleep(for: .milliseconds(400))
            let ouverte = try #require(moteur.cadresInterface["legende"], "la legende reste, repliee ou non").height
            moteur.selection = nil
            try await MoteurPiecesTests.attendre { moteur.cadresInterface["fiche"] == nil }
            try await Task.sleep(for: .milliseconds(400))
            let apres = try #require(moteur.cadresInterface["legende"]).height
            #expect(p.bool(forKey: LegendePieces.cleRepliee) == repliee, "\(id), \(taille) : le repli garde ne change pas")
            return (ouverte, apres)
        }
        let petite = FenetrePieces.tailleMinimale
        let defaut = CGSize(width: 1100, height: 760)
        // Petite fenetre, fiche de la demo : repliee faute de place, puis rouverte.
        let (sousPetite, apresPetite) = try await essai(demo, petite, "Apple TV 4K", repliee: false)
        #expect(sousPetite < 40 && apresPetite > 150, "820 x 680 : repliee sous la fiche (\(sousPetite)), rouverte ensuite (\(apresPetite))")
        // Fenetre par defaut, fiche de la demo : la place suffit, elle reste ouverte.
        let (sousDefaut, _) = try await essai(demo, defaut, "Apple TV 4K", repliee: false)
        #expect(sousDefaut > 150, "1100 x 760 : ouverte au-dessus de la fiche (\(sousDefaut))")
        // Fenetre par defaut, fiche avec ses courbes : repliee.
        let historique = try CourbesFicheTests.surveillance()
        let (sousCourbes, apresCourbes) = try await essai(historique, defaut, JournalMaillageTests.appareil, repliee: false)
        #expect(sousCourbes < 40 && apresCourbes > 100, "fiche avec courbes : repliee (\(sousCourbes)), rouverte (\(apresCourbes))")
        // Repliee par Djoko : elle le reste.
        let (sousGardee, apresGardee) = try await essai(demo, petite, "Apple TV 4K", repliee: true)
        #expect(sousGardee < 40 && apresGardee < 40, "repliee par Djoko : elle le reste (\(sousGardee), \(apresGardee))")
    }

    /// Une legende que Djoko ouvre a la main, sans fiche, n'empeche pas son repli faute de place sous la fiche qui
    /// parait ensuite : seul compte un « rouvert » fait sous une fiche (`FenetrePieces.legendeRouverte`), et la fiche
    /// qui parait efface le drapeau. Dans la plus petite fenetre, la legende, repliee par la preference, est ouverte
    /// d'un vrai clic sur son etiquette ; la fiche de l'Apple TV 4K ouverte, elle se replie quand meme.
    @Test(.timeLimit(.minutes(2))) func ouvertureManuelleSansFicheLaisseLeRepliAutomatique() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set(true, forKey: LegendePieces.cleRepliee)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let (fenetre, moteur) = try Self.fenetre(demo, taille: FenetrePieces.tailleMinimale, preferences: p)
        defer { Self.fermer(fenetre) }
        try await MoteurPiecesTests.attendre { moteur.cadresInterface["legende"] != nil && moteur.pret }
        try await Task.sleep(for: .milliseconds(500))
        let etiquette = try #require(moteur.cadresInterface["legende"])
        try await Self.cliquer(fenetre, en: CGPoint(x: etiquette.midX, y: etiquette.midY))
        try await MoteurPiecesTests.attendre { (moteur.cadresInterface["legende"]?.height ?? 0) > 150 }
        #expect((moteur.cadresInterface["legende"]?.height ?? 0) > 150, "ouverte d'un clic")
        moteur.selection = "Apple TV 4K"
        try await Task.sleep(for: .milliseconds(1000))
        #expect((moteur.cadresInterface["legende"]?.height ?? 999) < 40,
                "sous la fiche, dans la plus petite fenetre, la legende se replie : scene de \(moteur.cadre.height) pt")
    }

    /// Taille minimale du contenu de la fenetre : 820 x 680 pt, sous la barre de titre cachee (la fenetre, elle, fait
    /// 732 pt de haut au moins, avec la barre d'outils invisible).
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
    /// (1100 pt de large) comme a la taille minimale. Sous une fiche, elle reste au bord, au-dessus de la fiche
    /// (verification du 02/10), la legende ouverte ou repliee faute de place ; la fiche fermee, la rangee revient a
    /// sa place. La marge du bas suit la hauteur mesuree de la rangee, puis de la rangee et de la fiche. Les
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
        let (fenetre, moteur) = try Self.fenetre(demo, taille: taille, preferences: p)
        defer { Self.fermer(fenetre) }
        func cadre(_ cle: String) throws -> CGRect { try #require(moteur.cadresInterface[cle], "le cadre « \(cle) »") }
        let cas = "fenetre de \(Int(taille.width)) pt"

        // Fiche fermee : la legende au bord, puis la ligne de niveau, puis la pastille.
        try await MoteurPiecesTests.attendre { ["legende", "niveau", "ancien"].allSatisfy { moteur.cadresInterface[$0] != nil } }
        // La hauteur de la vue, mise en page : la fenetre ne descend pas sous sa taille minimale, 680 pt sous la barre
        // de titre, soit 732 pt en tout.
        let hauteur = fenetre.frame.height
        #expect(hauteur >= taille.height)
        let legende = try cadre("legende")
        let niveau = try cadre("niveau")
        let ancien = try cadre("ancien")
        #expect(legende.minX == FenetrePieces.bord, "\(cas) : la legende est au bord gauche (x = \(legende.minX))")
        #expect(niveau.minX >= legende.maxX && ancien.minX >= niveau.maxX, "\(cas) : la ligne de niveau, puis la pastille, a droite de la legende")
        // La marge du bas : la pile mesuree (son haut, le plus haut des cadres), le bord et l'espacement, a l'arrondi pres.
        func margeDeLaPile() throws -> CGFloat {
            FenetrePieces.margeBas(pile: hauteur - FenetrePieces.bord - (try #require(Self.hautDeLaPile(moteur))))
        }
        let ouverte = try margeDeLaPile()
        try await MoteurPiecesTests.attendre { abs(moteur.marges.bas - ouverte) <= 1 }
        #expect(abs(moteur.marges.bas - ouverte) <= 1, "\(cas) : la marge du bas suit la legende ouverte (\(moteur.marges.bas), \(ouverte), \(moteur.cadresInterface))")

        // Fiche ouverte : la rangee reste au bord, au-dessus de la fiche.
        moteur.selection = "Apple TV 4K"
        try await MoteurPiecesTests.attendre {
            moteur.cadresInterface["fiche"].map { f in moteur.cadresInterface["niveau"].map { $0.maxY <= f.minY } == true } == true
        }
        let fiche = try cadre("fiche")
        let legendeSurFiche = try cadre("legende")
        let niveauSurFiche = try cadre("niveau")
        let ancienSurFiche = try cadre("ancien")
        #expect(legendeSurFiche.minX == FenetrePieces.bord, "\(cas) : la legende reste au bord (x = \(legendeSurFiche.minX))")
        #expect(niveauSurFiche.minX >= legendeSurFiche.maxX && ancienSurFiche.minX >= niveauSurFiche.maxX,
                "\(cas) : la ligne de niveau, puis la pastille, a droite de la legende")
        #expect([legendeSurFiche, niveauSurFiche, ancienSurFiche].allSatisfy { $0.maxY <= fiche.minY },
                "\(cas) : la rangee au-dessus de la fiche")
        #expect(fiche.minX == FenetrePieces.bord && fiche.width == taille.width - 2 * FenetrePieces.bord, "\(cas) : la fiche, \(fiche)")
        let surFiche = try margeDeLaPile()
        try await MoteurPiecesTests.attendre { abs(moteur.marges.bas - surFiche) <= 1 }
        #expect(abs(moteur.marges.bas - surFiche) <= 1, "\(cas) : la marge du bas suit la rangee et la fiche (\(moteur.marges.bas), \(surFiche))")

        // Fiche fermee : la rangee revient a sa place, et la marge.
        moteur.selection = nil
        try await MoteurPiecesTests.attendre {
            moteur.cadresInterface["fiche"] == nil && moteur.cadresInterface["legende"]?.size == legende.size
        }
        let legendeRevenue = try cadre("legende")
        #expect(legendeRevenue == legende, "\(cas) : la legende est revenue a sa place (\(legendeRevenue))")
        try await MoteurPiecesTests.attendre { abs(moteur.marges.bas - ouverte) <= 1 }
        #expect(abs(moteur.marges.bas - ouverte) <= 1, "\(cas) : la marge du bas est revenue a celle de la legende ouverte")
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
    /// qui se decale autour d'eux (la rangee du bas, qui monte au-dessus de la fiche, le fil sous un bandeau) prend
    /// sa place sans animation : celle du conteneur est nulle. Sans le reglage, rien ne change : cela glisse avec
    /// l'element, sur la courbe de la maquette.
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

    /// L'ouverture et le repli de la legende sont un peu plus lents que la fiche (verification du 02/10 : Djoko
    /// trouvait l'ouverture « un poil trop fugace ») : 0,45 s au lieu de 0,3 s, sur la meme courbe, pour la legende
    /// et pour ce qui se decale avec elle (la ligne de niveau, la pastille) ; avec « Reduire les animations », un
    /// fondu de 0,45 s, et rien ne glisse. La fiche et les bandeaux restent a 0,3 s. Le recadrage qui accompagne la
    /// legende prend sa duree (`MoteurPiecesTests.margesQuiGlissentAvecLaLegende`) ; apres un vrai clic dans la
    /// vraie fenetre, `recadrageDeLaLegendeApresUnClic` le mesure.
    @Test func dureeDeLaLegende() {
        let courbe = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.45)
        #expect(Apparition.dureeLegende == 0.45)
        #expect(Apparition.duree == 0.3, "la fiche et les bandeaux")
        #expect(Apparition.animationLegende(reduire: false) == courbe)
        #expect(Apparition.animationLegende(reduire: true) == .easeInOut(duration: 0.45))
        #expect(Apparition.animationDuConteneurLegende(reduire: false) == courbe)
        #expect(Apparition.animationDuConteneurLegende(reduire: true) == nil, "avec le reglage, rien ne se decale en glissant")
    }

    /// Un vrai clic sur l'etiquette de la legende (son en-tete, ouverte), dans la vraie fenetre, recadre la vue en
    /// 0,45 s (`Apparition.dureeLegende`), pour son repli comme pour son ouverture, avec le reglage (un fondu de cette
    /// duree) comme sans ; la fiche, elle, la recadre en 0,3 s. `dureeDeLaLegende` ne garde que les fonctions : ici,
    /// le clic passe par la legende (`LigneDuBas`), qui annonce sa duree au moteur (`legendeBasculee`), puis par le
    /// recadrage lui-meme. La transition de la legende (`Apparition.transitionLegende`) ne s'observe pas par la
    /// geometrie : ce test ne la garde pas.
    @Test(.timeLimit(.minutes(2)), arguments: [false, true])
    func recadrageDeLaLegendeApresUnClic(reduire: Bool) async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set(false, forKey: LegendePieces.cleRepliee)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let (fenetre, moteur) = try Self.fenetre(demo, taille: CGSize(width: 1100, height: 760), preferences: p,
                                                 reduire: reduire)
        defer { Self.fermer(fenetre) }
        try await MoteurPiecesTests.attendre { moteur.cadresInterface["legende"] != nil && moteur.pret && !moteur.margesEnRoute }
        try await Task.sleep(for: .milliseconds(600))
        // Ouverte : un clic sur son en-tete la replie.
        var legende = try #require(moteur.cadresInterface["legende"])
        try await Self.cliquer(fenetre, en: CGPoint(x: legende.minX + 40, y: legende.minY + 16))
        let repli = try #require(try await Self.dureeDuRecadrage(moteur))
        #expect(abs(repli - Apparition.dureeLegende) < 0.07, "repli par clic : \(repli) s")
        try await Task.sleep(for: .milliseconds(600))
        // Repliee : un clic sur son etiquette l'ouvre.
        legende = try #require(moteur.cadresInterface["legende"])
        try await Self.cliquer(fenetre, en: CGPoint(x: legende.midX, y: legende.midY))
        let ouverture = try #require(try await Self.dureeDuRecadrage(moteur))
        #expect(abs(ouverture - Apparition.dureeLegende) < 0.07, "ouverture par clic : \(ouverture) s")
        try await Task.sleep(for: .milliseconds(600))
        // La fiche, elle, garde ses 0,3 s.
        moteur.selection = "Apple TV 4K"
        let fiche = try #require(try await Self.dureeDuRecadrage(moteur))
        #expect(abs(fiche - Apparition.duree) < 0.07, "fiche : \(fiche) s")
    }

    /// Avec « Reduire les animations », la rangee du bas prend sa place d'un coup quand la fiche parait : l'animation
    /// du conteneur de la pile du bas est nulle (spec de B, sections 1 et 3 : « un simple fondu »), et ce qui part de
    /// la rangee dans la meme mise a jour que la fiche part sans delai ; sans le reglage, cela glisse avec la fiche,
    /// et part apres l'animation du conteneur (0,3 s). Cela se voit de l'exterieur : un element retire reste dans
    /// l'arbre le temps de son animation de retrait, et son `onDisappear` (qui vide son cadre dans `cadresInterface`)
    /// en donne la duree. Ici, la pastille d'un releve ancien, que le releve suivant rend non ancien dans la meme mise
    /// a jour que la fiche.
    @Test(.timeLimit(.minutes(2)), arguments: [true, false])
    func rangeeDuBasPrendSaPlaceAvecReduire(reduire: Bool) async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set(false, forKey: LegendePieces.cleRepliee)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let maillage = try #require(demo.maillage)
        demo.recevoir(maillage, a: demo.maintenant.addingTimeInterval(-7 * 60))
        #expect(demo.maillageAncien)
        let (fenetre, moteur) = try Self.fenetre(demo, taille: CGSize(width: 1100, height: 760), preferences: p,
                                                 reduire: reduire)
        defer { Self.fermer(fenetre) }
        try await MoteurPiecesTests.attendre {
            ["legende", "niveau", "ancien"].allSatisfy { moteur.cadresInterface[$0] != nil } && moteur.pret && !moteur.margesEnRoute
        }
        try await Task.sleep(for: .milliseconds(400))
        // Dans la meme mise a jour : la fiche parait, le releve n'est plus ancien (sa pastille part).
        let t0 = ProcessInfo.processInfo.systemUptime
        moteur.selection = "Apple TV 4K"
        demo.recevoir(maillage, a: demo.maintenant)
        var delai = 1.5
        while ProcessInfo.processInfo.systemUptime - t0 < 1.5 {
            if moteur.cadresInterface["ancien"] == nil {
                delai = ProcessInfo.processInfo.systemUptime - t0
                break
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        if reduire {
            #expect(delai < 0.15, "avec le reglage, la pastille part d'un coup (\(delai) s)")
        } else {
            #expect(delai > 0.25, "sans le reglage, elle part avec l'animation du conteneur (\(delai) s)")
        }
    }

    /// Dans la vraie fenetre, avec « Reduire les animations », la legende reste a sa place dans la rangee, au-dessus
    /// de la fiche, quand celle-ci parait, et la vue se recadre par un fondu (le moteur), pas en glissant. Avant la
    /// verification du 02/10, la legende se retirait sous la fiche, et son depart, d'un coup, montrait que la pile du
    /// bas n'avait pas d'animation de conteneur ; elle reste desormais, et son depart ne dit donc plus rien de ce
    /// cablage. Que rien ne glisse dans la rangee du bas est garde par `rangeeDuBasPrendSaPlaceAvecReduire`, qui mesure
    /// le depart d'un de ses elements ; les fonctions, par `reduireLesAnimationsSansGlissement` et `dureeDeLaLegende`.
    @Test(.timeLimit(.minutes(1)))
    func legendeResteAuDessusDeLaFicheAvecReduire() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set(false, forKey: LegendePieces.cleRepliee)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        demo.recevoir(try #require(demo.maillage), a: demo.maintenant.addingTimeInterval(-7 * 60))
        let taille = CGSize(width: 1100, height: 760)
        let (fenetre, moteur) = try Self.fenetre(demo, taille: taille, preferences: p, reduire: true)
        defer { Self.fermer(fenetre) }
        try await MoteurPiecesTests.attendre {
            ["legende", "niveau", "ancien"].allSatisfy { moteur.cadresInterface[$0] != nil } && moteur.pret && !moteur.margesEnRoute
        }
        #expect(moteur.reduire, "le reglage atteint la fenetre")
        let legende = try #require(moteur.cadresInterface["legende"], "la legende est ouverte")

        // La fiche parait : la legende reste, au-dessus d'elle, et la vue se recadre par un fondu.
        moteur.selection = "Apple TV 4K"
        try await MoteurPiecesTests.attendre { moteur.cadresInterface["fiche"] != nil && moteur.margesEnRoute }
        #expect(moteur.margesEnRoute && moteur.margesEnFondu, "la vue se recadre par un fondu")
        let fiche = try #require(moteur.cadresInterface["fiche"])
        let reste = try #require(moteur.cadresInterface["legende"], "la legende reste")
        #expect(reste.size == legende.size && reste.minX == legende.minX && reste.maxY <= fiche.minY,
                "la legende, ouverte, au-dessus de la fiche : \(reste), \(fiche)")
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

    /// Une fenetre faite comme celle de l'app (releves dans l'app, en demo, les 02/10) : le contenu sous la barre de
    /// titre, la barre transparente, le titre masque (`.windowStyle(.hiddenTitleBar)`) ; et une barre d'outils vide,
    /// du style automatique que choisit SwiftUI (releve : `toolbarStyle` 0), sans fond (le `.toolbar` de
    /// `FenetrePieces`), qui abaisse les trois boutons. Les tests montent leur fenetre a la main, sans la scene de
    /// l'app : SwiftUI n'y pose pas la barre d'outils.
    static func sansBarreDeTitre(_ fenetre: NSWindow) {
        fenetre.styleMask.insert(.fullSizeContentView)
        fenetre.titlebarAppearsTransparent = true
        fenetre.titleVisibility = .hidden
        fenetre.toolbar = NSToolbar(identifier: "graphe-test")
        fenetre.toolbarStyle = .automatic
    }

    /// Sans barre de titre (polissage B, section 1) : la scene du graphe, et elle seule, porte le style
    /// `.hiddenTitleBar`. SwiftUI pose alors lui-meme la barre de titre transparente et le titre masque, et les
    /// garde a chaque mise a jour de la fenetre ; le crochet d'AppKit d'avant, pose une fois, etait defait par
    /// SwiftUI (diagnostic du 02/10 : barre opaque des 0,285 s). Le titre « Maillage Thread » reste celui de la
    /// fenetre (Mission Control, menu Fenetre). Les trois boutons restent : la capsule de gauche commence apres
    /// eux, centree sur eux. La vue pose une barre d'outils vide et invisible (reverification du 02/10 : de l'air en
    /// haut, comme dans Plans), qui abaisse les boutons : dans une fenetre ainsi faite, sous macOS 27, a leur place
    /// de `CadreFeux.defaut`, le milieu a 26 pt du haut.
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
        #expect(CadreFeux.defaut == CadreFeux(droite: 79, milieu: 26), "les boutons abaisses : \(CadreFeux.defaut)")
        // La vue pose la barre d'outils : vide, un espace souple seul, sans fond, et cachee en plein ecran (sauf au
        // survol du haut) ; la scene la porte, et SwiftUI la garde.
        let corps = String(reflecting: FenetrePieces.Body.self)
        let barre = try #require(corps.range(of: "ToolbarSpacer"), "une barre d'outils vide")
        #expect(corps[barre.upperBound...].components(separatedBy: "ToolbarAppearanceModifier").count - 1 == 2,
                "sans fond, et au survol seulement en plein ecran")
        #expect(corps.contains("SuiviFenetre"), "les boutons suivis, et le plein ecran")
    }

    /// De l'air en haut (reverification du 02/10) : dans la vraie fenetre, faite comme celle de l'app, la ligne des
    /// capsules suit les trois boutons abaisses par la barre d'outils invisible : centree sur eux, a 26 pt du haut,
    /// la capsule de gauche juste apres eux, le haut des capsules a 12 pt environ du bord. La marge du haut mesuree
    /// suit la nouvelle hauteur : le bas de la colonne sous la capsule de gauche, et l'espacement.
    @Test(.timeLimit(.minutes(1))) func deLAirEnHaut() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let (fenetre, moteur) = try Self.fenetre(demo, taille: CGSize(width: 1100, height: 760), preferences: p)
        defer { Self.fermer(fenetre) }
        try await MoteurPiecesTests.attendre {
            moteur.pret && moteur.cadresInterface["ligne"] != nil && moteur.cadresInterface["colonne"] != nil
                && !moteur.margesEnRoute
        }
        try await Task.sleep(for: .milliseconds(300))
        let feux = try #require(CadreFeux(fenetre: fenetre))
        #expect(feux == CadreFeux.defaut, "les boutons abaisses : \(feux)")
        let ligne = try #require(moteur.cadresInterface["ligne"])
        let colonne = try #require(moteur.cadresInterface["colonne"])
        #expect(abs(ligne.midY - feux.milieu) < 0.5 && ligne.minY == 0, "la ligne centree sur les boutons : \(ligne)")
        #expect(ligne.minX == feux.droite + HautPieces.ecartFeux, "la capsule de gauche apres les boutons : \(ligne)")
        let capsule = NSHostingView(rootView: BarreOutils().capsuleDeVerre()
            .environment(demo)
            .environment(SondeMaillage(preferences: p, actif: false))
            .environment(NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit))).fittingSize.height
        let hautDesCapsules = feux.milieu - capsule / 2
        #expect(hautDesCapsules >= 10 && hautDesCapsules <= 13, "le haut des capsules : \(hautDesCapsules) pt")
        #expect(moteur.marges.haut == FenetrePieces.margeHaut(bas: colonne.maxY), "la marge du haut : \(moteur.marges.haut)")
        #expect(moteur.marges.haut >= FenetrePieces.margeHautInitiale, "la marge suit la nouvelle hauteur")
        #expect(FenetrePieces.margeHautInitiale == FenetrePieces.margeHaut(bas: 2 * 26 + FenetrePieces.espacement + 16))
    }

    /// La colonne de gauche au bord, et la tournee sans place reservee (ronde finale du 02/10). Sous la ligne des
    /// capsules, la ligne de la tournee, le bandeau de scission et le fil « Maison » vont contre le bord gauche de la
    /// fenetre, a la marge de la legende et de la ligne de niveau, que la tournee soit la ou non. Quand la tournee
    /// finit, sa ligne disparait, et le bandeau et le fil remontent (la colonne, dont le haut ne bouge pas, perd la
    /// hauteur de la ligne et un espacement). La scene, elle, ne bouge pas : la marge du haut compte toujours la place
    /// d'une ligne de tournee tant qu'une sonde est retenue, et ne change ni a la fin de la tournee, ni pendant que la
    /// colonne se reajuste (sinon, la vue d'ensemble se recadrerait a chaque tournee, toutes les 5 minutes).
    @Test(.timeLimit(.minutes(1))) func tourneeSansPlaceReservee() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        let canal = SondeMaillageTests.canalRetenu(journal)
        let sonde = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        #expect(demo.reseau?.estScinde == true, "la demo : le bandeau de scission, dans la colonne")
        let (fenetre, moteur) = try Self.fenetre(demo, taille: CGSize(width: 1100, height: 760), preferences: p,
                                                 sonde: sonde)
        defer { Self.fermer(fenetre) }
        func colonne() throws -> CGRect { try #require(moteur.cadresInterface["colonne"], "la colonne") }
        func stable() async throws {
            try await MoteurPiecesTests.attendre { moteur.pret && moteur.cadresInterface["colonne"] != nil && !moteur.margesEnRoute }
            try await Task.sleep(for: .milliseconds(400))
        }
        try await stable()
        let sansSonde = try colonne()
        #expect(sansSonde.minX == FenetrePieces.bord, "sans sonde, au bord : \(sansSonde)")
        // Une sonde retenue, en tournee : la ligne de la tournee parait en haut de la colonne.
        await sonde.connecter(SondeMaillageTests.port, choisi: true)
        await journal.attendre(SondeMaillageTests.listeRetenue)
        await SondeMaillageTests.attendre { sonde.avancement != nil }
        try await stable()
        let pendant = try colonne()
        let margePendant = moteur.marges.haut
        #expect(pendant.minX == FenetrePieces.bord, "pendant la tournee, au bord : \(pendant)")
        #expect(margePendant == FenetrePieces.margeHaut(bas: pendant.maxY), "la marge : le bas de la colonne")
        // La tournee finit : la marge ne bouge a aucun moment, et la vue d'ensemble ne se recadre pas.
        canal.emettre(CanalRejoue.reseauMinimal(SondeMaillageTests.listeRetenue + "\n"))
        await SondeMaillageTests.attendre { !sonde.tourneeEnCours }
        var marges: Set<CGFloat> = []
        var recadree = false
        let t0 = ProcessInfo.processInfo.systemUptime
        while ProcessInfo.processInfo.systemUptime - t0 < 0.8 {
            marges.insert(moteur.marges.haut)
            recadree = recadree || moteur.margesEnRoute
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(marges == [margePendant], "la marge du haut, stable : \(marges)")
        #expect(!recadree, "la scene ne se recadre pas")
        let apres = try colonne()
        let ligne = NSHostingView(rootView: IndicateurTournee(avancement: AvancementTournee(etape: .etatSonde, fait: 0, total: 1),
                                                             debut: nil)).fittingSize.height
        #expect(apres.minX == FenetrePieces.bord, "apres la tournee, au bord : \(apres)")
        #expect(apres.minY == pendant.minY, "le haut de la colonne ne bouge pas")
        #expect(abs(pendant.height - apres.height - (ligne + FenetrePieces.espacement)) < 0.5,
                "le bandeau et le fil remontent de la ligne de la tournee : \(pendant.height) -> \(apres.height)")
        // La sonde oubliee : la marge ne compte plus de ligne de tournee.
        await sonde.oublier()
        try await MoteurPiecesTests.attendre { moteur.marges.haut < margePendant && !moteur.margesEnRoute }
        let oubliee = try colonne()
        #expect(moteur.marges.haut == FenetrePieces.margeHaut(bas: oubliee.maxY), "sans sonde : \(moteur.marges.haut)")
    }

    /// Le vrai plein ecran (reverification du 02/10 : le bouton vert ne faisait qu'agrandir la fenetre) : SwiftUI pose
    /// a la fenetre d'une app de la barre des menus `fullScreenAuxiliary` ou `fullScreenNone` (releve dans l'app, en
    /// demo), et la vue le remplace par `fullScreenPrimary`, a chaque fois. En plein ecran (ronde finale du 02/10), la
    /// barre d'outils invisible se retire : revelee au survol du haut, elle faisait une bande claire sur les capsules.
    /// Elle revient a la sortie, et les boutons avec elle. La capsule de gauche garde sa place, apres les boutons : ceux
    /// que le survol du haut fait paraitre ne la recouvrent pas.
    @Test(.timeLimit(.minutes(1))) func pleinEcran() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let (fenetre, moteur) = try Self.fenetre(demo, taille: CGSize(width: 1100, height: 760), preferences: p)
        defer { Self.fermer(fenetre) }
        try await MoteurPiecesTests.attendre { moteur.pret && moteur.cadresInterface["ligne"] != nil }
        func primaire() -> Bool {
            let c = fenetre.collectionBehavior
            return c.contains(.fullScreenPrimary) && !c.contains(.fullScreenAuxiliary) && !c.contains(.fullScreenNone)
        }
        try await MoteurPiecesTests.attendre { primaire() }
        #expect(primaire(), "le plein ecran : 0x\(String(fenetre.collectionBehavior.rawValue, radix: 16))")
        // Ce que fait SwiftUI a chaque mise a jour des tailles de la fenetre : la vue le defait aussitot.
        for autre in [NSWindow.CollectionBehavior.fullScreenAuxiliary, .fullScreenNone] {
            fenetre.collectionBehavior = fenetre.collectionBehavior.subtracting(.fullScreenPrimary).union(autre)
            try await MoteurPiecesTests.attendre { primaire() }
            #expect(primaire(), "remis apres \(autre.rawValue) : 0x\(String(fenetre.collectionBehavior.rawValue, radix: 16))")
        }
        let apres = CadreFeux.defaut.droite + HautPieces.ecartFeux
        let barre = try #require(fenetre.toolbar)
        #expect(moteur.cadresInterface["ligne"]?.minX == apres)
        #expect(barre.isVisible, "hors plein ecran, la barre d'outils invisible abaisse les boutons")
        NotificationCenter.default.post(name: NSWindow.willEnterFullScreenNotification, object: fenetre)
        try await Task.sleep(for: .milliseconds(300))
        #expect(!barre.isVisible, "en plein ecran, la barre d'outils se retire")
        #expect(moteur.cadresInterface["ligne"]?.minX == apres, "en plein ecran, la capsule garde sa place")
        #expect(moteur.cadresInterface["ligne"]?.midY == CadreFeux.defaut.milieu, "a la meme hauteur")
        NotificationCenter.default.post(name: NSWindow.didExitFullScreenNotification, object: fenetre)
        try await MoteurPiecesTests.attendre { barre.isVisible }
        #expect(barre.isVisible, "a la sortie, la barre d'outils revient")
        try await Task.sleep(for: .milliseconds(300))
        #expect(CadreFeux(fenetre: fenetre) == CadreFeux.defaut, "et les boutons abaisses avec elle")
        #expect(moteur.cadresInterface["ligne"]?.minX == apres, "a la sortie, apres les boutons")
        #expect(moteur.cadresInterface["ligne"]?.midY == CadreFeux.defaut.milieu)
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

    /// La fenetre reste sombre, meme quand le Mac est en clair : sa barre, ses menus, sa fiche et ses feuilles, et en
    /// plein ecran la barre de titre que le survol du haut fait paraitre (ronde finale du 02/10 : une bande blanche sur
    /// un Mac en clair). SwiftUI pose l'apparence de la fenetre a chaque mise a jour, d'apres la preference de la vue :
    /// l'apparence sombre posee par AppKit etait aussitot defaite (releve dans l'app, en demo). La vue demande donc
    /// l'apparence sombre a SwiftUI (`preferredColorScheme`).
    @Test func fenetreToujoursSombre() {
        let corps = String(reflecting: FenetrePieces.Body.self)
        #expect(corps.contains("PreferredColorSchemeKey"), "la vue demande l'apparence sombre a SwiftUI")
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
