import AppKit
import Foundation
@testable import MaillageCoeur
import simd
import SwiftUI
import Testing
@testable import MaillageThread

/// Le glissement d'une disposition a l'autre, dans le moteur (polissage D, section 1) : une nouvelle disposition glisse
/// au lieu de sauter, de la pose affichee, en 0,9 s ; les liens suivent ; une autre disposition en route repart de la
/// pose affichee ; la vue suit la piece isolee ; une piece qu'on glisse n'est pas animee ; « Reduire les animations » ;
/// la grille rechoisie quand les rayons changent (section 4).
@MainActor
@Suite("Vue par pieces : glissement d'une disposition a l'autre")
struct GlissementTests {
    /// La Prise salon de la demo (un appareil du salon, au rez-de-chaussee).
    static let prise = "7AF0B6D5006CF95F"

    /// La demo, l'accessoire `nom` place dans la piece `piece` (« Placer dans une piece… », ou Maison).
    static func demo(_ nom: String, dans piece: String) throws -> EntreeScene {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        for k in maison.accessoires.indices where maison.accessoires[k].nom == nom {
            maison.accessoires[k].piece = piece
        }
        s.noms.maison = maison
        return EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
    }

    /// La demo, chaque accessoire de `deplacer` place dans sa piece.
    static func demo(_ deplacer: [String: String]) throws -> EntreeScene {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        for k in maison.accessoires.indices {
            if let p = deplacer[maison.accessoires[k].nom] { maison.accessoires[k].piece = p }
        }
        s.noms.maison = maison
        return EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
    }

    /// La demo, l'accessoire `nom` renomme `nouveau`.
    static func demo(_ nom: String, nom nouveau: String) throws -> EntreeScene {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        for k in maison.accessoires.indices where maison.accessoires[k].nom == nom { maison.accessoires[k].nom = nouveau }
        s.noms.maison = maison
        return EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
    }

    /// Le noeud que la sonde seule connait, dans la demo : un enfant du maillage sans appareil, de « Sans pièce ».
    static let inconnu = "rloc:041F"

    /// La demo sans cet enfant du maillage de la sonde : ce noeud quitte la scene ; `deplacer` : chaque accessoire
    /// de la liste place dans sa piece, comme `demo(_:)`.
    static func demoSansInconnu(_ deplacer: [String: String] = [:]) throws -> EntreeScene {
        let (s, r, _) = try NomsSceneTests.demo()
        let m = try #require(s.maillage)
        s.recevoir(Maillage(date: m.date, partition: m.partition, routeurs: m.routeurs, liens: m.liens,
                            enfants: m.enfants.filter { $0.rloc16 != 0x041F }, signaux: m.signaux), a: s.maintenant)
        var maison = try #require(s.noms.maison)
        for k in maison.accessoires.indices {
            if let p = deplacer[maison.accessoires[k].nom] { maison.accessoires[k].piece = p }
        }
        s.noms.maison = maison
        return EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
    }

    /// Le moteur de la demo, fige (sans horloge : les etats se posent a la main), une image dessinee.
    static func moteur(troisD: Bool = false) throws -> (MoteurPieces, EntreeScene) {
        let (_, _, e) = try NomsSceneTests.demo()
        return (moteur(e, troisD: troisD), e)
    }

    /// Un moteur sur la scene `e`, fige, une image dessinee ; en 3D, a la bascule finie.
    static func moteur(_ e: EntreeScene, troisD: Bool, taille: CGSize = MoteurPiecesTests.taille) -> MoteurPieces {
        let m = MoteurPieces(troisD: troisD)
        m.marges = (84, 50)
        m.poserTaille(taille)
        m.installerMaintenant(e)
        m.fige = true
        if troisD { m.poserBascule(1) }
        MoteurPiecesTests.dessiner(m, taille: taille)
        return m
    }

    /// La place d'un noeud dans le monde, a l'image.
    static func monde(_ m: MoteurPieces, _ id: String) throws -> SIMD3<Double> {
        try #require(m.projetee?.centresNoeuds[id])
    }

    /// Le dessin des pastilles qui s'effacent (`apparencesParties`), lu dans le moteur : il est prive, et ne se voit
    /// qu'au dessin.
    static func apparencesParties(_ m: MoteurPieces) throws -> [String: DessinNoeud.Apparence] {
        let c = Mirror(reflecting: m).children.first { $0.label == "apparencesParties" }
        return try #require(c?.value as? [String: DessinNoeud.Apparence], "apparencesParties : renomme ?")
    }

    /// Une image du moteur, dessinee hors fenetre, et ce qu'elle montre de la pastille `id` : son opacite dans la scene
    /// projetee, et le pixel de son centre (la moyenne des neuf pixels du milieu, en RVBA de 8 bits). Dessinee, elle
    /// rend le pixel plus opaque et plus clair ; sautee par le rendu, le fond reste.
    static func pastille(_ m: MoteurPieces, _ id: String) throws -> (opacite: Double, pixel: [Double]) {
        let taille = MoteurPiecesTests.taille
        let rendu = ImageRenderer(content: Canvas { ctx, t in
            m.image(&ctx, taille: t, echelle: 1, palette: Palette(sombre: true))
        }.frame(width: taille.width, height: taille.height))
        rendu.scale = 1
        let image = try #require(rendu.cgImage)
        #expect(image.width == Int(taille.width) && image.height == Int(taille.height))
        var octets = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let espace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let ctx = try #require(CGContext(data: &octets, width: image.width, height: image.height, bitsPerComponent: 8,
                                         bytesPerRow: image.width * 4, space: espace,
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let disque = try #require(m.projetee?.disques.first { $0.noeud == id }, "la pastille \(id) est projetee")
        let x = Int(disque.centre.x.rounded()), y = Int(disque.centre.y.rounded())
        #expect(x > 1 && y > 1 && x < image.width - 1 && y < image.height - 1, "le centre est dans l'image")
        var pixel = [Double](repeating: 0, count: 4)
        for j in -1...1 {
            for i in -1...1 {
                for c in 0..<4 { pixel[c] += Double(octets[((y + j) * image.width + x + i) * 4 + c]) / 9 }
            }
        }
        return (disque.opacite, pixel)
    }

    /// L'ecart de deux pixels : la somme des ecarts de leurs quatre canaux.
    static func ecart(_ a: [Double], _ b: [Double]) -> Double {
        zip(a, b).reduce(0) { $0 + abs($1.0 - $1.1) }
    }

    /// La Prise salon placee dans la cuisine, en 2D, ou dans la chambre, a l'etage, en 3D : elle part de sa place
    /// affichee, sans saut ; a mi-temps, elle est en route, sur le segment de ses deux places quand les plateaux ne
    /// bougent pas ; a la fin, a sa nouvelle place. Les liens suivent sa pastille. La transition dure 0,9 s, et
    /// l'horloge tourne pendant ce temps.
    @Test(arguments: [false, true]) func nouvelleDispositionQuiGlisse(troisD: Bool) throws {
        let (m, _) = try Self.moteur(troisD: troisD)
        let avant = try Self.monde(m, Self.prise)
        let e2 = try Self.demo("Prise salon", dans: troisD ? "Chambre" : "Cuisine")
        let instant = MoteurPieces.maintenant()
        m.installerMaintenant(e2)
        let tr = try #require(m.transition)
        #expect(tr.debut >= instant && tr.debut - instant < 1)
        #expect(tr.depart.noeuds[Self.prise] != nil && tr.arrivee.noeuds[Self.prise] != nil)
        MoteurPiecesTests.dessiner(m)
        #expect(simd_distance(try Self.monde(m, Self.prise), avant) < 1e-9, "pas de saut")
        m.poserTransition(1)
        MoteurPiecesTests.dessiner(m)
        let apres = try Self.monde(m, Self.prise)
        let f = try #require(MoteurPiecesTests.moteur(e2).projetee?.centresNoeuds[Self.prise])
        if troisD {
            #expect(apres.y - avant.y > 4, "d'un etage a l'autre")
        } else {
            #expect(simd_distance(apres, f) < 1e-9, "sa place dans la nouvelle disposition")
        }
        #expect(simd_distance(apres, avant) > 3)
        m.poserTransition(0.5)
        MoteurPiecesTests.dessiner(m)
        let mi = try Self.monde(m, Self.prise)
        let d = simd_distance(avant, apres)
        #expect(simd_distance(mi, avant) > 0.25 * d && simd_distance(mi, apres) > 0.25 * d, "en route")
        let disque = try #require(m.projetee?.disques.first { $0.noeud == Self.prise })
        let p = try #require(m.projetee)
        #expect((p.liensEnfants + p.liensRouteurs).contains { $0.a == disque.centre || $0.b == disque.centre },
                "un lien suit sa pastille")
    }

    /// L'horloge ne tourne que pendant la transition : sans rotation lente, sans plateau qui glisse (poses tout de
    /// suite), et passee la fenetre de 0,6 s d'activite qui suit toute scene posee (`reveiller`) et qui la ferait
    /// tourner de toute facon, `doitContinuer` est vrai pour la seule transition, et faux des qu'elle est finie.
    @Test(arguments: [false, true]) func horlogeDeLaTransition(troisD: Bool) throws {
        let (m, _) = try Self.moteur(troisD: troisD)
        m.rotation = false
        m.installerMaintenant(try Self.demo("Prise salon", dans: troisD ? "Chambre" : "Cuisine"))
        m.poserTaille(MoteurPiecesTests.taille)
        #expect(m.transition != nil && m.glissementPlateaux == nil)
        #expect(m.doitContinuer(MoteurPieces.maintenant() + 0.7), "l'horloge tourne pendant la transition")
        m.fige = false
        m.reculerTransition(de: 1)
        MoteurPiecesTests.dessiner(m)
        #expect(m.transition == nil)
        // Au repos, l'horloge s'arrete, sauf pour le fondu d'un nom qui finit (selon la langue, un nom est encore a
        // quelques milliemes de son terme).
        let fondu = m.etiquettes.contains { $0.envie > 0 }
        #expect(fondu || !m.doitContinuer(MoteurPieces.maintenant() + 0.7), "au repos, l'horloge s'arrete")
    }

    /// « Reduire les animations » : la nouvelle disposition est posee tout de suite, sans transition, sans fondu, et
    /// sans glissement de plateaux : l'ampoule de l'entree placee dans la cuisine en fait glisser quand « Reduire » est
    /// decoche. Un glissement en route quand « Reduire » se coche, puis une autre disposition : les poses en route
    /// sont remises a zero, la nouvelle disposition est posee.
    @Test func reduire() throws {
        let plateaux = try Self.demo("Ampoule entrée", dans: "Cuisine")
        let (n, _) = try Self.moteur()
        n.installerMaintenant(plateaux)
        #expect(n.transition != nil && n.glissementPlateaux != nil, "sans « Reduire », cette disposition glisse")
        let (m, _) = try Self.moteur()
        m.reduire = true
        let e2 = try Self.demo("Prise salon", dans: "Cuisine")
        m.installerMaintenant(e2)
        #expect(m.transition == nil && m.posesAffichees == PosesScene() && m.glissementPlateaux == nil)
        MoteurPiecesTests.dessiner(m)
        let f = try #require(MoteurPiecesTests.moteur(e2).projetee?.centresNoeuds[Self.prise])
        #expect(simd_distance(try Self.monde(m, Self.prise), f) < 1e-9)
        let (r, _) = try Self.moteur()
        r.reduire = true
        r.installerMaintenant(plateaux)
        #expect(r.transition == nil && r.glissementPlateaux == nil, "les plateaux aussi sont poses tout de suite")
        // « Reduire » se coche pendant un glissement : la disposition suivante ne le reprend pas, elle est posee.
        let (g, _) = try Self.moteur()
        g.installerMaintenant(e2)
        g.poserTransition(0.5)
        #expect(g.transition != nil && g.posesAffichees != PosesScene(), "un glissement en route")
        g.reduire = true
        let e3 = try Self.demo("Prise salon", dans: "Entrée")
        g.installerMaintenant(e3)
        #expect(g.transition == nil && g.posesAffichees == PosesScene(), "les poses en route sont remises a zero")
        MoteurPiecesTests.dessiner(g)
        let arrivee = try #require(MoteurPiecesTests.moteur(e3).projetee?.centresNoeuds[Self.prise])
        #expect(simd_distance(try Self.monde(g, Self.prise), arrivee) < 1e-9, "posee a sa nouvelle place")
    }

    /// Une nouvelle disposition pendant un glissement repart de la pose affichee, sans saut ; une disposition qui ne
    /// change rien laisse le glissement en cours.
    @Test func interruption() throws {
        let (m, e) = try Self.moteur()
        let e2 = try Self.demo("Prise salon", dans: "Cuisine")
        m.installerMaintenant(e2)
        let premiere = try #require(m.transition)
        m.installerMaintenant(e2)
        #expect(m.transition == premiere, "la meme disposition : le glissement continue")
        m.poserTransition(0.5)
        MoteurPiecesTests.dessiner(m)
        let mi = try Self.monde(m, Self.prise)
        m.installerMaintenant(try Self.demo("Prise salon", dans: "Entrée"))
        #expect(m.transition != premiere)
        MoteurPiecesTests.dessiner(m)
        #expect(simd_distance(try Self.monde(m, Self.prise), mi) < 1e-9, "pas de saut")
        m.installerMaintenant(e)
        MoteurPiecesTests.dessiner(m)
        #expect(simd_distance(try Self.monde(m, Self.prise), mi) < 1e-9, "pas de saut, encore")
    }

    /// Par l'horloge : la cuisine isolee, qu'une nouvelle disposition deplace de plus de 10 unites (l'ampoule de
    /// l'entree placee dans la cuisine), glisse, et la vue la suit, en route (sa place a l'image, de sa pose affichee)
    /// comme au bout ; l'horloge tourne pendant le glissement, meme sans plateau qui glisse. Temps reel, sans borne
    /// haute : le glissement est avance de 0,3 s a l'instant ou l'image se dessine (borne basse), et sa place en route
    /// se juge d'apres l'instant mesure de cette image, quelle que soit la charge du Mac.
    @Test func parLHorloge() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPiecesTests.moteur(e)
        let cuisine = try MoteurPiecesTests.indice(e, "Cuisine")
        m.installerMaintenant(try Self.demo("Ampoule entrée", dans: "Cuisine"))
        let g = try #require(m.glissementPlateaux)
        #expect(g.duree2D == TransitionScene.duree && g.duree3D == TransitionScene.duree,
                "les plateaux glissent en 0,9 s")
        let arrivee = try #require(m.entree)
        let apres = try #require(MoteurPiecesTests.moteur(arrivee).centrePiece(cuisine))
        // Les plateaux poses tout de suite : seul le glissement de la disposition fait tourner l'horloge ; puis la
        // cuisine isolee, a sa place affichee, celle d'avant.
        m.poserTaille(MoteurPiecesTests.taille)
        m.poserIsolement(cuisine)
        let avant = try #require(m.centrePiece(cuisine))
        #expect(m.glissementPlateaux == nil && m.transition != nil && simd_distance(m.orbite.cible, avant) < 1e-6)
        #expect(simd_distance(avant, apres) > 10)
        #expect(m.doitContinuer(MoteurPieces.maintenant() + 0.7), "l'horloge tourne pendant le glissement")
        // 0,3 s ecoulees a cet instant, et l'image juste apres : sa pose est entre les deux instants mesures.
        let debut0 = try #require(m.transition).debut
        m.reculerTransition(de: MoteurPieces.maintenant() - debut0 + 0.3)
        let debut = try #require(m.transition).debut
        let avantImage = MoteurPieces.maintenant()
        MoteurPiecesTests.dessiner(m)
        let apresImage = MoteurPieces.maintenant()
        let qMin = (avantImage - debut) / TransitionScene.duree, qMax = (apresImage - debut) / TransitionScene.duree
        #expect(qMin >= 0.3 / TransitionScene.duree - 1e-9, "borne basse : 0,3 s au moins")
        if qMax < 1 {
            let pose = try #require(m.posesAffichees.pieces["piece:Cuisine"], "la cuisine glisse encore")
            let plateaux = Dictionary(uniqueKeysWithValues: arrivee.scene.etages.enumerated().map { ($1.id, $0) })
            let mi = try #require(PosesScene.centre(pose.ancres, geometrie: m.geometrie, plateaux: plateaux, t: 0))
            let trajet = SIMD2(apres.x - avant.x, apres.z - avant.z), parcouru = SIMD2(mi.x - avant.x, mi.z - avant.z)
            let f = simd_dot(parcouru, trajet) / simd_dot(trajet, trajet)
            #expect(simd_length(parcouru - trajet * f) < 1e-6, "la cuisine, sur le segment de ses deux places")
            #expect(f >= CameraScene.rampe(qMin) - 1e-6 && f <= CameraScene.rampe(qMax) + 1e-6, "en route, a l'heure")
            let vue = SIMD2(m.orbite.cible.x, m.orbite.cible.z)
            #expect(simd_distance(vue, SIMD2(mi.x, mi.z)) < 1e-6, "la vue la suit")
        }
        m.reculerTransition(de: 1)
        MoteurPiecesTests.dessiner(m)
        #expect(m.transition == nil && m.posesAffichees == PosesScene())
        #expect(simd_distance(m.orbite.cible, apres) < 1e-6, "au bout, la vue sur la cuisine")
    }

    /// La duree du glissement, vue de l'horloge du moteur, des deux cotes de 0,9 s : a 0,86 s il glisse encore (si
    /// l'image est tombee avant 0,9 s, l'instant mesure le dit : pas de borne haute sur le temps reel), a 0,92 s il est
    /// fini (borne basse : 0,92 s au moins se sont ecoulees).
    @Test func dureeVueDuMoteur() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let e2 = try Self.demo("Prise salon", dans: "Cuisine")
        for (ecoule, fini) in [(0.86, false), (0.92, true)] {
            let m = MoteurPiecesTests.moteur(e)
            m.installerMaintenant(e2)
            let debut0 = try #require(m.transition).debut
            m.reculerTransition(de: MoteurPieces.maintenant() - debut0 + ecoule)
            let debut = try #require(m.transition).debut
            MoteurPiecesTests.dessiner(m)
            if fini {
                #expect(m.transition == nil, "\(ecoule) s : fini")
            } else if MoteurPieces.maintenant() - debut < 0.9 {
                #expect(m.transition != nil, "\(ecoule) s : il glisse encore")
            }
        }
    }

    /// La pastille d'un partant : un noeud qui quitte la scene (ici celui que la sonde seule connait) s'efface en
    /// 0,3 s, a sa place, avec le dessin qu'il avait ; tant qu'il est a demi efface, son disque est projete et dessine,
    /// de moins en moins opaque (le pixel de son centre le montre : sautee par le rendu, elle ne change plus rien) ;
    /// une autre disposition qui arrive pendant le fondu le reprend tel quel ; une fois efface, plus rien n'est garde.
    @Test func pastilleQuiPart() throws {
        let (m, e1) = try Self.moteur()
        let id = Self.inconnu
        let avant = try #require(e1.apparences[id])
        let e2 = try Self.demoSansInconnu()
        #expect(e1.scene.noeuds.contains { $0.id == id } && !e2.scene.noeuds.contains { $0.id == id })
        m.installerMaintenant(e2)
        let tr = try #require(m.transition)
        #expect(tr.depart.noeuds[id] != nil && tr.arrivee.noeuds[id] == nil, "il s'efface, a sa place")
        #expect(try Self.apparencesParties(m)[id] == avant, "son dessin d'avant est garde")
        // Le fondu dure 0,3 s des 0,9 s du glissement : a 1/20, 1/10, 3/20 et 2/10 de celui-ci, la pastille est a 85,
        // 70, 55 et 40 %.
        func image(_ q: Double) throws -> (opacite: Double, pixel: [Double]) {
            m.poserTransition(q)
            return try Self.pastille(m, id)
        }
        let frames = try [0.05, 0.1, 0.15, 0.2].map(image)
        #expect(zip(frames, [0.85, 0.7, 0.55, 0.4]).allSatisfy { abs($0.opacite - $1) < 1e-6 }, "le fondu")
        #expect(try image(0.5).opacite == 0, "a la moitie du glissement, elle est effacee")
        // Dessinee, la pastille change le pixel de son centre a chaque image, d'autant plus que l'opacite change ;
        // sautee, il ne change que de quelques points (un lien qui s'efface a cote). Ces images sont proches : le fond
        // ne bouge pas.
        let ecarts = zip(frames, frames.dropFirst()).map { Self.ecart($0.pixel, $1.pixel) }
        #expect(ecarts.allSatisfy { $0 > 30 }, "dessinee, de moins en moins opaque : \(ecarts)")
        let a = frames[1]
        // Une autre disposition arrive a 1/10 : la pastille continue de s'effacer, du meme dessin, de son opacite.
        m.poserTransition(0.1)
        m.installerMaintenant(try Self.demoSansInconnu(["Prise salon": "Cuisine"]))
        let reprise = try Self.pastille(m, id)
        #expect(abs(reprise.opacite - 0.7) < 1e-6, "elle repart de son opacite du moment")
        #expect(Self.ecart(reprise.pixel, a.pixel) < 40, "toujours dessinee, du meme dessin")
        #expect(try Self.apparencesParties(m)[id] == avant, "son dessin d'avant est toujours garde")
        // Au bout : plus de pastille, plus de dessin garde.
        m.fige = false
        m.reculerTransition(de: 1)
        MoteurPiecesTests.dessiner(m)
        #expect(m.transition == nil && m.projetee?.disques.contains { $0.noeud == id } == false)
        #expect(try Self.apparencesParties(m).isEmpty, "fini : plus rien d'efface a garder")
    }

    /// Un vol de camera et une disposition qui glisse (polissage D, section 1). Un vol qui part pendant le glissement
    /// vise la cuisine la ou elle est affichee, et finit sur son arrivee, que `suivre` lui retend a chaque image. Une
    /// disposition qui arrive pendant un vol attend sa fin (comme pendant tout mouvement), puis glisse de la pose
    /// affichee, sans saut, la vue sur la cuisine. Temps reel : le vol dure 1,3 s, les vues sont jugees apres 1,4 s
    /// (borne basse).
    @Test func volEtGlissement() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let e2 = try Self.demo("Ampoule entrée", dans: "Cuisine")
        let cuisine = try MoteurPiecesTests.indice(e, "Cuisine")
        // Le vol part en plein glissement.
        let apres = MoteurPiecesTests.moteur(e)
        let depart = try #require(apres.centrePiece(cuisine))
        apres.installerMaintenant(e2)
        apres.reculerTransition(de: 0.3)
        MoteurPiecesTests.dessiner(apres)
        let enRoute = try #require(apres.centrePiece(cuisine))
        apres.isoler(cuisine)
        #expect(apres.enMouvement && apres.transition != nil, "le vol part, le glissement continue")
        // La disposition arrive pendant le vol.
        let avant = MoteurPiecesTests.moteur(e)
        avant.isoler(cuisine)
        avant.installerMaintenant(e2)
        #expect(avant.enMouvement && avant.entree == e && avant.transition == nil, "elle attend la fin du vol")
        Thread.sleep(forTimeInterval: 1.4)
        MoteurPiecesTests.dessiner(apres)
        MoteurPiecesTests.dessiner(avant)
        #expect(!apres.enMouvement && apres.transition == nil, "le vol et le glissement sont finis")
        let fin = try #require(apres.centrePiece(cuisine))
        #expect(simd_distance(fin, depart) > 1 && simd_distance(fin, enRoute) > 1, "la cuisine a glisse jusqu'au bout")
        #expect(simd_distance(apres.orbite.cible, fin) < 1e-6, "le vol finit sur la cuisine, la ou elle est arrivee")
        #expect(!avant.enMouvement && avant.entree == e2 && avant.transition != nil, "posee a la fin, elle glisse")
        let posee = try #require(avant.centrePiece(cuisine))
        #expect(simd_distance(posee, depart) < 1e-9, "de la pose affichee, sans saut")
        #expect(simd_distance(avant.orbite.cible, depart) < 1e-6, "la vue est sur la cuisine")
        avant.reculerTransition(de: 1)
        MoteurPiecesTests.dessiner(avant)
        #expect(avant.transition == nil)
        let arrivee = try #require(avant.centrePiece(cuisine))
        #expect(simd_distance(arrivee, depart) > 1, "la cuisine a glisse")
        #expect(simd_distance(avant.orbite.cible, arrivee) < 1e-6, "la vue l'a suivie jusqu'au bout")
    }

    /// Une piece qu'on prend en route est posee a sa place, ses noeuds avec elle, et suit le pointeur ; une piece
    /// glissee par Djoko n'est pas animee a son relachement, quand la disposition suivante arrive : elle y est fixee,
    /// deja a sa place ; les autres glissent.
    @Test(.timeLimit(.minutes(1))) func pieceGlissee() async throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPiecesTests.moteur(e)
        m.installerMaintenant(try Self.demo("Prise salon", dans: "Cuisine"))
        let cuisine = try MoteurPiecesTests.indice(try #require(m.entree), "Cuisine")
        #expect(m.transition?.arrivee.pieces["piece:Cuisine"] != nil)
        MoteurPiecesTests.dessiner(m)
        let p = try MoteurPiecesTests.pointDePiece(m, cuisine)
        m.glisser(p, depart: p)
        #expect(m.transition?.arrivee.pieces["piece:Cuisine"] == nil && m.posesAffichees.pieces["piece:Cuisine"] == nil)
        #expect(m.transition?.arrivee.noeuds[Self.prise] == nil, "ses noeuds avec elle")
        #expect(m.transition?.arrivee.pieces["piece:Salon"] != nil, "les autres glissent encore")
        m.glisser(CGPoint(x: p.x + 10, y: p.y), depart: p)
        let version = m.versionScene
        m.relacher(CGPoint(x: p.x + 10, y: p.y))
        #expect(m.versionScene == version, "glisser une piece ne relance pas le calcul : aucune scene ne bouge")
        // Glisser le salon pendant qu'une autre disposition arrive : elle attend le relachement, puis se calcule, le
        // salon fixe.
        try await MoteurPiecesTests.attendre {
            MoteurPiecesTests.dessiner(m)
            return m.transition == nil
        }
        let salon = try MoteurPiecesTests.indice(try #require(m.entree), "Salon")
        MoteurPiecesTests.dessiner(m)
        let q = try MoteurPiecesTests.pointDePiece(m, salon)
        m.glisser(q, depart: q)
        m.glisser(CGPoint(x: q.x + 60, y: q.y + 20), depart: q)
        m.recevoir(try Self.demo(["Prise salon": "Cuisine", "Ampoule entrée": "Cuisine"]))
        let place = m.positions[salon]
        m.relacher(CGPoint(x: q.x + 60, y: q.y + 20))
        try await MoteurPiecesTests.attendre {
            m.entree?.scene.pieces.first { $0.nom == .maison("Entrée") }?.noeuds.count == 1
        }
        let tr = try #require(m.transition, "les autres pieces glissent")
        #expect(tr.arrivee.pieces["piece:Salon"] == nil && tr.depart.pieces["piece:Salon"] == nil,
                "le salon, deja a sa place")
        let i = try MoteurPiecesTests.indice(try #require(m.entree), "Salon")
        #expect(simd_distance(m.positions[i], place) < 1e-9)
    }

    /// En 3D, une piece en route d'un etage a l'autre, prise par Djoko : elle est posee a sa place d'arrivee, et le
    /// pointeur la suit a la hauteur de cette place (pas a celle ou elle etait en route : prise avant d'etre posee, la
    /// hauteur serait celle d'entre deux etages, et la piece fuirait sous le pointeur).
    @Test func pieceGlisseeEnTroisD() throws {
        let e1 = try MoteurPiecesTests.quatrePlateaux()
        let e2 = try IsolementTests.sceneQuiArrive(e1, places: PlacesGardees()) { zones in
            // Le bureau quitte les combles pour l'etage.
            zones[3].pieces.removeAll { $0 == "Bureau" }
            zones[2].pieces += ["Bureau"]
        }
        let m = Self.moteur(e1, troisD: true)
        m.installerMaintenant(e2)
        m.poserTransition(0.5)
        MoteurPiecesTests.dessiner(m)
        let bureau = try MoteurPiecesTests.indice(e2, "Bureau")
        let enRoute = try #require(m.centrePiece(bureau)).y
        let p = try MoteurPiecesTests.pointDePiece(m, bureau)
        m.glisser(p, depart: p)
        let pose = try #require(m.centrePiece(bureau)).y
        #expect(abs(pose - enRoute) > 1, "en route, la piece est entre deux etages ; posee, a l'etage d'arrivee")
        let q = CGPoint(x: p.x + 20, y: p.y + 8)
        let projection = ProjectionScene(m.orbite, cadre: m.cadre)
        let a = try #require(projection.sol(p, hauteur: pose)), b = try #require(projection.sol(q, hauteur: pose))
        let place = m.positions[bureau]
        m.glisser(q, depart: p)
        #expect(simd_distance(m.positions[bureau], place + SIMD2(b.x - a.x, b.z - a.z)) < 1e-9,
                "elle suit le pointeur depuis sa place, a sa hauteur d'arrivee")
    }

    /// La grille est rechoisie quand une nouvelle disposition change les rayons sans changer les niveaux (polissage D,
    /// section 4) : a la vue d'ensemble 2D, avec l'hysteresis ; zoomee, en 3D ou piece isolee, elle attend, comme un
    /// redimensionnement ; le meme releve, partout, ne change rien.
    @Test func grilleRechoisieQuandLesRayonsChangent() throws {
        let e1 = try MoteurPiecesTests.quatrePlateaux()
        let e2 = try IsolementTests.sceneQuiArrive(e1, places: PlacesGardees()) { zones in
            // Le bureau et la chambre d'amis quittent les combles pour l'etage : les rayons changent, pas les niveaux.
            zones[3].pieces.removeAll { $0 == "Bureau" || $0 == "Chambre d'amis" }
            zones[2].pieces += ["Bureau", "Chambre d'amis"]
        }
        let e3 = try IsolementTests.sceneQuiArrive(e1, places: PlacesGardees()) { zones in
            // L'entree quitte le jardin pour le rez-de-chaussee : un petit changement des rayons.
            zones[1].pieces.removeAll { $0 == "Entrée" }
            zones[0].pieces += ["Entrée"]
        }
        let r1 = MoteurPiecesTests.moteur(e1).geometrie.rayons, r2 = MoteurPiecesTests.moteur(e2).geometrie.rayons
        let r3 = MoteurPiecesTests.moteur(e3).geometrie.rayons
        #expect(r1 != r2 && r1 != r3 && e1.scene.niveaux == e2.scene.niveaux && e1.scene.niveaux == e3.scene.niveaux)
        // Une vue ou la grille en place pour les premiers rayons ne tient plus pour les seconds, meme avec
        // l'hysteresis.
        let tailles = stride(from: 650.0, through: 1600, by: 50).flatMap { h in
            stride(from: 820.0, through: 2400, by: 20).map { CGSize(width: $0, height: h) }
        }
        let (taille, c1) = try #require(tailles.lazy.compactMap { t -> (CGSize, Int)? in
            let zone = CGSize(width: t.width, height: t.height - 84 - 50)
            guard let c1 = GeometrieMaison.colonnes(rayons: r1, taille: zone),
                  GeometrieMaison.colonnes(rayons: r2, taille: zone, enPlace: c1) != c1 else { return nil }
            return (t, c1)
        }.first, "une vue ou la grille change")
        let m = MoteurPiecesTests.moteur(e1, taille: taille)
        #expect(m.colonnes == c1)
        m.installerMaintenant(e2)
        let c2 = GeometrieMaison.colonnes(rayons: r2, taille: m.zoneVisible, enPlace: c1)
        #expect(m.colonnes == c2 && m.colonnes != c1 && m.geometrieVisee.colonnes == c2 && m.grilleEnAttente == nil)
        let z = MoteurPiecesTests.moteur(e1, taille: taille)
        z.poserZoom(echelle: 1, vers: nil)
        z.installerMaintenant(e2)
        #expect(z.colonnes == c1 && z.grilleEnAttente == PolitiqueGrille.redimensionnement, "zoomee : elle attend")
        // Le meme releve, la vue zoomee : rien ne change, rien n'attend.
        let zr = MoteurPiecesTests.moteur(e1, taille: taille)
        zr.poserZoom(echelle: 1, vers: nil)
        zr.installerMaintenant(e1)
        #expect(zr.colonnes == c1 && zr.grilleEnAttente == nil && zr.transition == nil,
                "zoomee, les memes rayons : rien")
        // En 3D, la vue d'ensemble n'est pas la vue d'ensemble 2D : elle attend aussi ; et une piece isolee.
        let t3 = Self.moteur(e1, troisD: true, taille: taille)
        #expect(t3.t == 1 && t3.colonnes == c1)
        t3.installerMaintenant(e2)
        #expect(t3.colonnes == c1 && t3.grilleEnAttente == PolitiqueGrille.redimensionnement, "en 3D : elle attend")
        let isolee = MoteurPiecesTests.moteur(e1, taille: taille)
        isolee.poserIsolement(try MoteurPiecesTests.indice(e1, "Salon"))
        isolee.installerMaintenant(e2)
        #expect(isolee.colonnes == c1 && isolee.grilleEnAttente == PolitiqueGrille.redimensionnement,
                "isolee : elle attend")
        // Et une vue ou le choix, sans la grille en place, changerait, mais ou elle reste a moins de 5 % : elle reste.
        let (garde, enPlace) = try #require(tailles.lazy.compactMap { t -> (CGSize, Int)? in
            let zone = CGSize(width: t.width, height: t.height - 84 - 50)
            guard let c = GeometrieMaison.colonnes(rayons: r1, taille: zone),
                  GeometrieMaison.colonnes(rayons: r3, taille: zone) != c,
                  GeometrieMaison.colonnes(rayons: r3, taille: zone, enPlace: c) == c else { return nil }
            return (t, c)
        }.first, "une vue ou l'hysteresis garde la grille")
        let h = MoteurPiecesTests.moteur(e1, taille: garde)
        h.installerMaintenant(e3)
        #expect(h.colonnes == enPlace, "l'hysteresis la garde")
        let p = MoteurPiecesTests.moteur(e1, taille: taille)
        p.installerMaintenant(e1)
        #expect(p.colonnes == c1 && p.grilleEnAttente == nil && p.transition == nil && p.glissementPlateaux == nil,
                "les memes rayons : rien")
    }
}
