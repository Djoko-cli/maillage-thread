import AppKit
import Foundation
import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : la legende")
struct LegendePiecesTests {
    typealias Entree = LegendePieces.Entree
    typealias Lecture = LegendePieces.Lecture

    static func radio(_ qualite: Int?) -> ScenePieces.Lien {
        ScenePieces.Lien(de: "rloc:0400", vers: "rloc:5000", genre: .radio, qualite: qualite)
    }

    /// Une scene inventee par signe : chacune ne contient que lui, et la legende n'a que son entree. Un
    /// noeud que la sonde seule connait, routeur ou enfant, est « non identifie » ; un appareil d'etat
    /// inconnu, gris lui aussi, n'a pas d'entree.
    @Test func uneEntreeParSigne() {
        let cas: [(Lecture, Set<Entree>)] = [
            (Lecture(couleurs: ["Apple TV 4K": .routeur(principale: true)]), [.routeur]),
            (Lecture(couleurs: ["rloc:5000": .routeurInconnu], inconnus: ["rloc:5000"]), [.nonIdentifie]),
            (Lecture(couleurs: ["rloc:041F": .appareil(.inconnu)], inconnus: ["rloc:041F"]), [.nonIdentifie]),
            (Lecture(couleurs: ["Aqara": .routeur(principale: false)]), [.autrePartition]),
            (Lecture(chefs: ["Apple TV 4K"]), [.chef]),
            (Lecture(couleurs: ["E000000000000001": .appareil(.joignable)]), [.joignable]),
            (Lecture(couleurs: ["E000000000000002": .appareil(.partitionCoupee)]), [.partitionCoupee]),
            (Lecture(couleurs: ["E000000000000003": .appareil(.sansAdresse)]), [.sansAdresse]),
            (Lecture(couleurs: ["E000000000000004": .appareil(.disparu)]), [.disparu]),
            (Lecture(endormis: ["E000000000000005"]), [.endormi]),
            (Lecture(piles: ["E000000000000006"]), [.pile]),
            (Lecture(liens: [Self.radio(3)]), [.bonne]),
            (Lecture(liens: [Self.radio(2)]), [.moyenne]),
            (Lecture(liens: [Self.radio(1)]), [.faible]),
            (Lecture(liens: [Self.radio(nil)]), [.inconnue]),
            (Lecture(liens: [Self.radio(0)]), [.inconnue]),
            (Lecture(liens: [ScenePieces.Lien(de: "E000000000000001", vers: "rloc:5000", genre: .parent, qualite: 3)]),
             [.versParent]),
            (Lecture(liens: [ScenePieces.Lien(de: "E000000000000001", vers: "Apple TV 4K")]), [.rattachement]),
            (Lecture(ailleurs: true), [.ailleurs]),
            (Lecture(candidats: ["rloc:0400"]), [.candidats]),
            (Lecture(couleurs: ["E000000000000007": .appareil(.inconnu)]), []),
            (Lecture(), []),
        ]
        for (lecture, attendu) in cas {
            #expect(LegendePieces.entrees(lecture) == attendu, "\(attendu)")
        }
    }

    /// Les groupes dans l'ordre de la grille (routeurs, appareils, liens radio, autres), leurs entrees
    /// dans l'ordre de la spec ; un groupe sans entree disparait, et une scene vide n'a pas de legende.
    @Test func groupesEtOrdre() {
        let tout = Lecture(couleurs: ["a": .routeur(principale: true), "b": .routeur(principale: false),
                                      "c": .appareil(.joignable), "d": .appareil(.partitionCoupee),
                                      "e": .appareil(.sansAdresse), "f": .appareil(.disparu)],
                           inconnus: ["g"], chefs: ["a"], endormis: ["c"], piles: ["c"], candidats: ["g"],
                           liens: [Self.radio(3), Self.radio(2), Self.radio(1), Self.radio(nil),
                                   ScenePieces.Lien(de: "c", vers: "a", genre: .parent),
                                   ScenePieces.Lien(de: "d", vers: "a")],
                           ailleurs: true)
        #expect(LegendePieces.rubriques(tout) == LegendePieces.Groupe.allCases.map {
            LegendePieces.Rubrique(groupe: $0, entrees: $0.entrees)
        })
        #expect(Set(LegendePieces.Groupe.allCases.flatMap(\.entrees)) == Set(Entree.allCases), "chaque entree a son groupe")
        let sansLiens = Lecture(couleurs: ["c": .appareil(.joignable)], chefs: ["a"], ailleurs: true)
        #expect(LegendePieces.rubriques(sansLiens) == [
            LegendePieces.Rubrique(groupe: .routeurs, entrees: [.chef]),
            LegendePieces.Rubrique(groupe: .appareils, entrees: [.joignable]),
            LegendePieces.Rubrique(groupe: .autres, entrees: [.ailleurs]),
        ])
        #expect(LegendePieces.rubriques(Lecture()).isEmpty)
    }

    /// La scene de la demo, lue telle que la fenetre la dessine : avec la sonde, puis sans (plus de liens
    /// radio : le groupe disparait) ; une piece isolee qui pose des reperes « ailleurs ».
    @Test func legendeDeLaDemo() throws {
        let (s, _, e) = try NomsSceneTests.demo()
        let avec = LegendePieces.entrees(Lecture(e, ailleurs: false))
        #expect(avec == [.routeur, .nonIdentifie, .autrePartition, .chef, .joignable, .sansAdresse, .disparu, .endormi,
                         .pile, .bonne, .moyenne, .faible, .versParent, .rattachement])
        #expect(LegendePieces.entrees(Lecture(e, ailleurs: true)).contains(.ailleurs))
        s.oublierMaillage()
        let sans = try #require(FenetrePiecesTests.entree(s))
        #expect(sans.maillage == nil)
        let rubriques = LegendePieces.rubriques(Lecture(sans, ailleurs: false))
        #expect(rubriques.map(\.groupe) == [.routeurs, .appareils, .autres])
        #expect(rubriques.last?.entrees == [.rattachement])
    }

    /// Les signes de la legende reprennent ceux de la scene : la pastille d'une pile (« 12 % »), un
    /// routeur et ses deux candidats (« A ou B · 0400 »).
    @Test func exemples() {
        #expect(LegendePieces.exemplePile == String(localized: "\(12)\u{202F}%"))
        #expect(LegendePieces.exempleCandidats
                == String(localized: "\(["A", "B"].formatted(.list(type: .or))) · \("0400")"))
        #expect(LegendePieces.exempleAilleurs == String(localized: "→ Salon"))
    }

    /// Deux colonnes de meme largeur : la moitie d'un panneau de 440 pt, ou celle du groupe le plus large.
    @Test func colonnes() {
        #expect(GrilleLegende.largeurColonne([120, 150]) == 199)
        #expect(GrilleLegende.largeurColonne([251, 120]) == 251)
        #expect(GrilleLegende.largeurColonne([]) == 199)
    }

    /// Le repli est garde dans les preferences (`legendeRepliee`), par la ligne du bas : repliee, il ne
    /// reste que l'etiquette ; un etat impose (captures) passe avant, sans ecrire la preference.
    @Test func repliGarde() throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let (_, _, e) = try NomsSceneTests.demo()
        #expect(LegendePieces.cleRepliee == "legendeRepliee")
        func taille(_ v: LigneDuBas) -> CGSize {
            NSHostingView(rootView: v.defaultAppStorage(p)).fittingSize
        }
        let ouverte = taille(LigneDuBas(moteur: MoteurPieces(), entree: e))
        p.set(true, forKey: LegendePieces.cleRepliee)
        let repliee = taille(LigneDuBas(moteur: MoteurPieces(), entree: e))
        #expect(repliee.height < 40 && ouverte.height > 4 * repliee.height, "\(repliee) \(ouverte)")
        #expect(taille(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false)) == ouverte)
        p.set(false, forKey: LegendePieces.cleRepliee)
        #expect(taille(LigneDuBas(moteur: MoteurPieces(), entree: e)) == ouverte)
        #expect(taille(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: true)) == repliee)
        #expect(p.bool(forKey: LegendePieces.cleRepliee) == false, "l'etat impose n'ecrit rien")
        let tout = LegendePieces.Groupe.allCases.map { LegendePieces.Rubrique(groupe: $0, entrees: $0.entrees) }
        func legende(_ r: [LegendePieces.Rubrique]) -> CGSize {
            NSHostingView(rootView: LegendePieces(rubriques: r, repliee: .constant(false))).fittingSize
        }
        #expect(legende(tout).width >= GrilleLegende.largeurPanneau)
        #expect(legende([]) == .zero, "sans entree, pas de legende")
    }

    /// La marge du bas suit la hauteur mesuree de tout ce qui est pose en bas (decision de Djoko du 01/10 pour la
    /// legende ouverte, du 02/10 pour la fiche, comme la marge du haut suit le bandeau) : la pile, de haut en bas la
    /// rangee de la legende et de la ligne de niveau, puis la fiche ; le bord et l'espacement en plus. La legende
    /// repliee sans fiche : la marge d'avant, 30 pt. Les valeurs fixes de la fiche (190 et 360 pt) ne sont plus : la
    /// pile d'une fiche est mesuree, legende ouverte ou repliee au-dessus d'elle.
    @Test func margeDuBas() throws {
        let (s, _, e) = try NomsSceneTests.demo()
        func hauteur(_ v: some View) -> CGFloat {
            NSHostingView(rootView: v.environment(s).environment(PiecesChoisies(fichier: nil))).fittingSize.height
        }
        let h = hauteur(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false))
        #expect(h > 150, "la legende de la demo, ouverte : \(h)")
        #expect(FenetrePieces.margeBas(pile: h) == FenetrePieces.bord + ceil(h) + FenetrePieces.espacement)
        #expect(FenetrePieces.margeBas(pile: nil) == 30, "repliee, sans fiche")
        #expect(FenetrePieces.margeBas(pile: 2) == 30)
        for repliee in [false, true] {
            let rangee = hauteur(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: repliee))
            let pile = hauteur(VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: repliee)
                FicheNoeud(id: "Apple TV 4K", entree: e, instant: Date(), aRenommer: .constant(nil)) {}
            }.frame(width: 1100 - 2 * FenetrePieces.bord))
            #expect(pile > rangee + FenetrePieces.espacement + 80, "repliee : \(repliee) ; la fiche sous la rangee (\(pile) pt)")
            #expect(FenetrePieces.margeBas(pile: pile) == FenetrePieces.bord + ceil(pile) + FenetrePieces.espacement)
        }
    }

    /// La vue d'ensemble se cadre au-dessus de la legende ouverte : dans une fenetre de 1440 x 900, aucun
    /// bloc, aucune pastille ni aucun nom de piece de la demo ne descend sous son bord du haut, en 2D
    /// comme en 3D.
    @Test(arguments: [false, true]) func vueAuDessusDeLaLegende(_ troisD: Bool) throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let h = NSHostingView(rootView: LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false))
            .fittingSize.height
        let taille = CGSize(width: 1440, height: 900)
        let m = MoteurPieces(troisD: troisD)
        m.fige = true
        m.marges = (FenetrePieces.margeHaut(bas: 90), FenetrePieces.margeBas(pile: h))
        m.poserTaille(taille)
        m.installerMaintenant(e)
        m.poserTaille(taille)
        MoteurPiecesTests.dessiner(m, taille: taille)
        let haut = taille.height - FenetrePieces.bord - h
        let p = try #require(m.projetee)
        #expect(!p.blocs.isEmpty && !p.disques.isEmpty)
        #expect(p.blocs.allSatisfy { b in b.faces.allSatisfy { f in f.points.allSatisfy { $0.y <= haut } } })
        #expect(p.disques.allSatisfy { $0.centre.y + $0.rayon <= haut })
        #expect(p.ancresPieces.values.allSatisfy { $0.maxY <= haut })
    }

    /// « Releve de la sonde ancien » n'est plus dans la legende : c'est une pastille a cote de la ligne de
    /// niveau, quand le releve est ancien, la legende ouverte ou repliee (une fiche ouverte ne la cache plus).
    @Test func pastilleDuReleveAncien() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces()
        func largeur(_ v: LigneDuBas) -> CGFloat { NSHostingView(rootView: v).fittingSize.width }
        let ouverte = largeur(LigneDuBas(moteur: m, entree: e, legendeForcee: false))
        #expect(largeur(LigneDuBas(moteur: m, entree: e, ancien: true, legendeForcee: false)) > ouverte)
        let repliee = largeur(LigneDuBas(moteur: m, entree: e, legendeForcee: true))
        #expect(repliee < ouverte, "repliee : l'etiquette seule")
        #expect(largeur(LigneDuBas(moteur: m, entree: e, ancien: true, legendeForcee: true)) > repliee)
    }

    /// Les signes de la legende sont dessines comme dans la scene, par les memes fonctions que le rendu (verification
    /// du 02/10) : un routeur en sphere brillante, avec halo et reflet, bleue, ambre dans une autre partition, grise
    /// non identifie ; un appareil en pastille de la couleur de son etat, en anneau s'il a disparu : les apparences
    /// de `DessinNoeud` que portent les noeuds de la scene. Le chef porte sa couronne et l'endormi sa lune, dans un nom
    /// de noeud comme ceux de la scene ; la pile, sa pastille ; les liens, leur epaisseur, leur couleur et leur trait,
    /// avec l'opacite d'un lien au repos dans la scene. La legende les pose par `SigneLegende`, qui dessine par
    /// `DessinNoeud` et `RenduCanvas` : ses images sont celles de ces fonctions, avec ces parametres.
    @Test func signesCommeLaScene() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let (sThread, _) = try NomsSceneTests.demoAvecRouteurThread()
        let thread = try #require(FenetrePiecesTests.entree(sThread))
        var vues = Set<Entree>()
        for scene in [e, thread] {
            for n in scene.scene.noeuds {
                let a = try #require(scene.apparences[n.id])
                let entree: Entree? = switch a.couleur {
                case .routeur(principale: true): .routeur
                case .routeur(principale: false): .autrePartition
                case .routeurInconnu: .nonIdentifie
                case .appareil(.joignable): .joignable
                case .appareil(.partitionCoupee): .partitionCoupee
                case .appareil(.sansAdresse): .sansAdresse
                case .appareil(.disparu): .disparu
                case .appareil(.inconnu): nil
                }
                guard let entree else { continue }
                vues.insert(entree)
                // Le centre d'une partition a un plus grand halo (10) : la legende montre un routeur, au halo de 5.
                let attendue = n.genre == .centre ? DessinNoeud.Apparence(forme: .sphere(halo: 5), couleur: a.couleur) : a
                #expect(n.genre != .centre || a.forme == .sphere(halo: 10))
                let routeur = n.genre != .appareil
                #expect(LegendePieces.signe(entree)
                        == .noeud(attendue, rayon: routeur ? LegendePieces.rayonRouteur : LegendePieces.rayonAppareil),
                        "\(n.id) : la meme apparence que dans la scene")
            }
        }
        #expect(vues == [.routeur, .nonIdentifie, .autrePartition, .joignable, .sansAdresse, .disparu])
        for (entree, etat) in [(Entree.partitionCoupee, EtatAffiche.partitionCoupee)] {
            #expect(LegendePieces.signe(entree) == .noeud(DessinNoeud.apparenceAppareil(etat), rayon: LegendePieces.rayonAppareil))
        }
        // La couronne et la lune : celles des noms de la scene.
        let chef = try #require(e.chefs.first)
        #expect(LegendePieces.signe(.chef) == .nom("👑", routeur: true))
        #expect(try #require(e.libelles[chef]).texte.contains(" 👑"))
        #expect(LegendePieces.signe(.endormi) == .nom("☾", routeur: false))
        #expect(e.libelles.values.contains { $0.texte.contains(" ☾") })
        #expect(LegendePieces.signe(.candidats) == .nom(LegendePieces.exempleCandidats, routeur: true))
        #expect(LegendePieces.signe(.pile) == .pastille(LegendePieces.exemplePile))
        #expect(LegendePieces.signe(.ailleurs) == .ailleurs(LegendePieces.exempleAilleurs))
        // Les liens : radio par qualite, enfant -> parent, rattachement ; l'opacite d'un lien au repos dans la scene.
        #expect([Entree.bonne, .moyenne, .faible, .inconnue].map(LegendePieces.signe)
                == [.lienRadio(qualite: 3), .lienRadio(qualite: 2), .lienRadio(qualite: 1), .lienRadio(qualite: nil)])
        #expect(LegendePieces.signe(.versParent) == .lienEnfant(rattachement: false))
        #expect(LegendePieces.signe(.rattachement) == .lienEnfant(rattachement: true))
        let projetee = try #require(MoteurPiecesTests.moteur(e).projetee)
        #expect(!projetee.liensRouteurs.isEmpty && !projetee.liensEnfants.isEmpty)
        #expect(projetee.liensRouteurs.allSatisfy { $0.opacite == LegendePieces.opaciteLienRadio })
        #expect(projetee.liensEnfants.allSatisfy { !$0.eclaire && $0.opacite == LegendePieces.opaciteLienEnfant })
        // La legende pose ses signes par `SigneLegende`, qui dessine par les fonctions du rendu.
        #expect(String(reflecting: LegendePieces.Body.self).contains("SigneLegende"))
        let p = Palette(sombre: true)
        let cadre = CGRect(x: 20, y: 10, width: 14, height: 14)
        let routeur = DessinNoeud.apparenceRouteur(inconnu: false, principale: true)
        // Les pixels d'un dessin, en RVBA de 8 bits (le tampon brut d'une image a des octets de remplissage).
        func image(_ dessin: @escaping (inout GraphicsContext) -> Void) throws -> [UInt8] {
            let rendu = ImageRenderer(content: Canvas { ctx, _ in dessin(&ctx) }.frame(width: 60, height: 34))
            rendu.scale = 2
            let image = try #require(rendu.cgImage)
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let espace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let ctx = try #require(CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                                             bytesPerRow: image.width * 4, space: espace,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            #expect(pixels.contains { $0 > 0 }, "un dessin")
            return pixels
        }
        // La couronne et le symbole de la pastille d'une pile se chargent au premier rendu (et un `ImageRenderer` garde
        // son premier rendu) : un rendu a blanc de chacun d'abord.
        _ = try image { ctx in
            let couronne = ctx.resolve(RenduCanvas.texteNom("👑", routeur: true, fort: false, palette: p))
            RenduCanvas.dessinerNom(&ctx, couronne, dans: cadre, palette: p)
            DessinNoeud.dessinerPastille(&ctx, "12 %", gauche: .zero, palette: p)
        }
        // Chaque signe, et la fonction du rendu avec les parametres de la scene : les memes pixels, a un ou deux pixels
        // pres (le flou d'un halo peut varier d'un rendu a l'autre) ; un autre dessin en changerait des milliers.
        func memes(_ signe: LegendePieces.Signe, _ reference: @escaping (inout GraphicsContext) -> Void) throws {
            let legende = try image { SigneLegende.dessiner(signe, &$0, dans: cadre, echelle: 2, palette: p) }
            let scene = try image(reference)
            let ecarts = zip(legende, scene).filter { $0 != $1 }.count
            #expect(ecarts <= 8, "\(signe) : \(ecarts) octets differents")
        }
        try memes(.noeud(routeur, rayon: 7)) {
            DessinNoeud.dessiner(&$0, centre: CGPoint(x: 27, y: 17), rayon: 7, apparence: routeur, palette: p)
        }
        try memes(.lienRadio(qualite: 2)) {
            RenduCanvas.dessinerLienRadio(&$0, de: CGPoint(x: 21, y: 17), a: CGPoint(x: 33, y: 17), qualite: 2,
                                          opacite: LegendePieces.opaciteLienRadio, palette: p)
        }
        try memes(.lienEnfant(rattachement: true)) {
            RenduCanvas.dessinerLienEnfant(&$0, de: CGPoint(x: 21, y: 17), a: CGPoint(x: 33, y: 17), rattachement: true,
                                           opacite: LegendePieces.opaciteLienEnfant, eclaire: false, pixel: 0.5, palette: p)
        }
        try memes(.nom("👑", routeur: true)) { ctx in
            let couronne = ctx.resolve(RenduCanvas.texteNom("👑", routeur: true, fort: false, palette: p))
            RenduCanvas.dessinerNom(&ctx, couronne, dans: cadre, palette: p)
        }
        try memes(.pastille("12 %")) {
            DessinNoeud.dessinerPastille(&$0, "12 %", gauche: CGPoint(x: 20, y: 17), palette: p)
        }
    }

    /// Les noeuds de la legende ont la taille d'un noeud de la scene dans la vue d'ensemble (verification du 02/10) :
    /// celle de la demo a la taille des images (1440 x 900, en 2D), ramenee au plus a la hauteur d'une ligne de la
    /// legende. Un routeur de bordure y mesure 13 fois le zoom, un appareil 7 fois.
    @Test func tailleDesSignes() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        #expect(LegendePieces.hauteurLigne == NSHostingView(rootView: Text(verbatim: "joignable").font(.system(size: 11))).fittingSize.height)
        let h = NSHostingView(rootView: LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false)).fittingSize.height
        let taille = CapturesPieces.taille
        let m = MoteurPieces()
        m.fige = true
        m.marges = (FenetrePieces.margeHaut(bas: 88), FenetrePieces.margeBas(pile: h))
        m.poserTaille(taille)
        m.installerMaintenant(e)
        m.poserTaille(taille)
        MoteurPiecesTests.dessiner(m, taille: taille)
        let p = try #require(m.projetee)
        #expect(abs(p.echelle - LegendePieces.zoomVueDEnsemble) < 0.02, "le zoom de la vue d'ensemble : \(p.echelle)")
        func rayon(_ garder: (ScenePieces.Noeud) -> Bool) throws -> Double {
            let id = try #require(e.scene.noeuds.first(where: garder)?.id)
            return try #require(p.disques.first { $0.noeud == id }).rayon
        }
        let routeur = try rayon { $0.genre == .routeur && $0.bordure }
        let appareil = try rayon { $0.genre == .appareil && !$0.routeur }
        #expect(abs(LegendePieces.rayonRouteur - min(routeur, LegendePieces.hauteurLigne / 2)) < 0.15, "\(routeur)")
        #expect(abs(LegendePieces.rayonAppareil - min(appareil, LegendePieces.hauteurLigne / 2)) < 0.15, "\(appareil)")
        #expect(2 * LegendePieces.rayonRouteur <= LegendePieces.hauteurLigne && LegendePieces.rayonAppareil >= 3)
    }
}
