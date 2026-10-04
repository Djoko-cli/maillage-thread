import AppKit
import Foundation
import MaillageCoeur
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
        for k in maison.accessoires.indices where maison.accessoires[k].nom == nom { maison.accessoires[k].piece = piece }
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

    /// Le moteur de la demo, fige (sans horloge : les etats se posent a la main), une image dessinee.
    static func moteur(troisD: Bool = false) throws -> (MoteurPieces, EntreeScene) {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces(troisD: troisD)
        m.marges = (84, 50)
        m.poserTaille(MoteurPiecesTests.taille)
        m.installerMaintenant(e)
        m.fige = true
        if troisD { m.poserBascule(1) }
        MoteurPiecesTests.dessiner(m)
        return (m, e)
    }

    /// La place d'un noeud dans le monde, a l'image.
    static func monde(_ m: MoteurPieces, _ id: String) throws -> SIMD3<Double> {
        try #require(m.projetee?.centresNoeuds[id])
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
        #expect(tr.debut >= instant && tr.debut - instant < 1 && m.doitContinuer(tr.debut + 0.5))
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

    /// « Reduire les animations » : la nouvelle disposition est posee tout de suite, sans transition, sans fondu.
    @Test func reduire() throws {
        let (m, _) = try Self.moteur()
        m.reduire = true
        let e2 = try Self.demo("Prise salon", dans: "Cuisine")
        m.installerMaintenant(e2)
        #expect(m.transition == nil && m.posesAffichees == PosesScene() && m.glissementPlateaux == nil)
        MoteurPiecesTests.dessiner(m)
        let f = try #require(MoteurPiecesTests.moteur(e2).projetee?.centresNoeuds[Self.prise])
        #expect(simd_distance(try Self.monde(m, Self.prise), f) < 1e-9)
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

    /// Par l'horloge : la cuisine isolee, qu'une nouvelle disposition deplace de plus de 20 unites (l'ampoule de l'entree placee dans la cuisine), glisse, et la vue la
    /// suit, a mi-temps (sa place a l'image, de sa pose affichee) comme au bout ; l'horloge tourne pendant le glissement,
    /// meme sans plateau qui glisse.
    @Test func parLHorloge() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPiecesTests.moteur(e)
        let cuisine = try MoteurPiecesTests.indice(e, "Cuisine")
        m.installerMaintenant(try Self.demo("Ampoule entrée", dans: "Cuisine"))
        let g = try #require(m.glissementPlateaux)
        #expect(g.duree2D == TransitionScene.duree && g.duree3D == TransitionScene.duree, "les plateaux glissent en 0,9 s")
        let arrivee = try #require(m.entree)
        let apres = try #require(MoteurPiecesTests.moteur(arrivee).centrePiece(cuisine))
        // Les plateaux poses tout de suite : seul le glissement de la disposition fait tourner l'horloge ; puis la cuisine
        // isolee, a sa place affichee, celle d'avant.
        m.poserTaille(MoteurPiecesTests.taille)
        m.poserIsolement(cuisine)
        let avant = try #require(m.centrePiece(cuisine))
        #expect(m.glissementPlateaux == nil && m.transition != nil && simd_distance(m.orbite.cible, avant) < 1e-6)
        #expect(simd_distance(avant, apres) > 20)
        #expect(m.doitContinuer(MoteurPieces.maintenant() + 0.7), "l'horloge tourne pendant le glissement")
        m.reculerTransition(de: 0.45)
        MoteurPiecesTests.dessiner(m)
        let pose = try #require(m.posesAffichees.pieces["piece:Cuisine"])
        let plateaux = Dictionary(uniqueKeysWithValues: arrivee.scene.etages.enumerated().map { ($1.id, $0) })
        let mi = try #require(PosesScene.centre(pose.ancres, geometrie: m.geometrie, plateaux: plateaux, t: 0))
        let d = simd_distance(avant, apres)
        #expect(simd_distance(mi, avant) > 0.25 * d && simd_distance(mi, apres) > 0.25 * d, "la cuisine en route")
        #expect(simd_distance(SIMD2(m.orbite.cible.x, m.orbite.cible.z), SIMD2(mi.x, mi.z)) < 1e-6, "la vue la suit")
        m.reculerTransition(de: 1)
        MoteurPiecesTests.dessiner(m)
        #expect(m.transition == nil && m.posesAffichees == PosesScene())
        #expect(simd_distance(m.orbite.cible, apres) < 1e-6, "au bout, la vue sur la cuisine")
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
        m.relacher(CGPoint(x: p.x + 10, y: p.y))
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
        try await MoteurPiecesTests.attendre { m.entree?.scene.pieces.first { $0.nom == .maison("Entrée") }?.noeuds.count == 1 }
        let tr = try #require(m.transition, "les autres pieces glissent")
        #expect(tr.arrivee.pieces["piece:Salon"] == nil && tr.depart.pieces["piece:Salon"] == nil, "le salon, deja a sa place")
        let i = try MoteurPiecesTests.indice(try #require(m.entree), "Salon")
        #expect(simd_distance(m.positions[i], place) < 1e-9)
    }

    /// La grille est rechoisie quand une nouvelle disposition change les rayons sans changer les niveaux (polissage D,
    /// section 4) : a la vue d'ensemble 2D, avec l'hysteresis ; zoomee, elle attend, comme un redimensionnement.
    @Test func grilleRechoisieQuandLesRayonsChangent() throws {
        let e1 = try MoteurPiecesTests.quatrePlateaux()
        let e2 = try IsolementTests.sceneQuiArrive(e1, places: PlacesGardees()) { zones in
            // Le bureau et la chambre d'amis quittent les combles pour l'etage : leurs rayons changent, pas les niveaux.
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
        // Une vue ou la grille en place pour les premiers rayons ne tient plus pour les seconds, meme avec l'hysteresis.
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
        // Et une vue ou le choix, sans la grille en place, changerait, mais ou elle reste a moins de 5 % : elle reste.
        let (garde, enPlace) = try #require(tailles.lazy.compactMap { t -> (CGSize, Int)? in
            let zone = CGSize(width: t.width, height: t.height - 84 - 50)
            guard let c = GeometrieMaison.colonnes(rayons: r1, taille: zone), GeometrieMaison.colonnes(rayons: r3, taille: zone) != c,
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
