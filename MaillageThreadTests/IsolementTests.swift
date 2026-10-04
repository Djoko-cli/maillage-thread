import AppKit
import Foundation
@testable import MaillageCoeur
import simd
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : etages isoles, provenance, clics et menu")
struct IsolementTests {
    static let rdc = "zone:Rez-de-chaussée", jardin = "zone:Jardin", etage = "zone:Étage", combles = "zone:Combles"

    /// La demo sur quatre plateaux (`MoteurPiecesTests.quatrePlateaux`), le jardin a cote du rez-de-chaussee, hors de
    /// la maison, gardes dans `fichier` ; son moteur, dispose, une premiere image dessinee.
    static func jardinDehors(_ fichier: URL, troisD: Bool = false) throws -> (MoteurPieces, EntreeScene) {
        let base = try MoteurPiecesTests.quatrePlateaux()
        var places = PlacesGardees()
        places.ranger(Rangement(ordre: [rdc, jardin, etage, combles], aCote: [jardin: PlacesGardees.ACote(etage: rdc, dehors: true)]),
                      domicile: base.domicile)
        try places.ecrire(dans: fichier)
        let e = try MoteurPiecesTests.quatrePlateaux(places)
        let m = MoteurPieces(troisD: troisD, fichierPlaces: fichier)
        m.marges = (84, 50)
        m.poserTaille(MoteurPiecesTests.taille)
        m.installerMaintenant(e)
        // La premiere image pose les noms, la seconde les garde a leur place.
        for _ in 0..<2 { MoteurPiecesTests.dessiner(m) }
        return (m, e)
    }

    static func indiceEtage(_ e: EntreeScene, _ cle: String) throws -> Int {
        try #require(e.scene.etages.firstIndex { $0.id == cle })
    }

    /// Le centre du nom d'un etage, pose.
    static func nomDEtage(_ m: MoteurPieces, _ e: Int) throws -> CGPoint {
        let l = try #require(m.etiquettes.first { $0.genre == .etage(e) && $0.vu })
        return CGPoint(x: l.rect.midX, y: l.rect.midY)
    }

    /// Un point du disque d'un etage, hors de ses pieces, de ses pastilles et des noms.
    static func pointDeDisque(_ m: MoteurPieces, _ e: Int) throws -> CGPoint {
        let pl = try #require(m.projetee?.plateaux.first { $0.etage == e })
        let b = SceneProjetee.boite(pl.polygone)
        let points = stride(from: 0.1, through: 0.9, by: 0.05).flatMap { fy in
            stride(from: 0.1, through: 0.9, by: 0.05).map { fx in CGPoint(x: b.minX + b.width * fx, y: b.minY + b.height * fy) }
        }
        return try #require(points.first { m.cibleClic(en: $0) == .disque(e) })
    }

    /// La cible du menu du clic droit sur le nom d'un etage, prise comme au clic droit.
    static func cibleDuNom(_ m: MoteurPieces, _ e: EntreeScene, _ cle: String) throws -> CibleMenu {
        m.cible(en: try nomDEtage(m, try indiceEtage(e, cle)))
    }

    /// Une scene qui arrive (polissage C, sections 1.3 et 5) : celle de `e`, la demo sur quatre plateaux, avec les places
    /// `places` ; les accessoires de chaque piece de `deplacer` passes dans une autre (elle n'a plus d'appareil, donc plus
    /// de place dans la scene) ; ses zones changees par `zones` (une piece passee d'une zone a une autre).
    static func sceneQuiArrive(_ e: EntreeScene, places: PlacesGardees, deplacer: [String: String] = [:],
                               zones changer: (inout [ZoneMaison]) -> Void = { _ in }) throws -> EntreeScene {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        // Les zones de `e`, dans son ordre, avec leurs pieces de Maison.
        var zones = e.scene.etages.compactMap { et -> ZoneMaison? in
            guard case .zone(let nom) = et.nom else { return nil }
            return ZoneMaison(nom: nom, pieces: et.pieces.compactMap { i -> String? in
                if case .maison(let p) = e.scene.pieces[i].nom { p } else { nil }
            })
        }
        changer(&zones)
        maison.zones = zones
        for k in maison.accessoires.indices {
            if let p = maison.accessoires[k].piece, let q = deplacer[p] { maison.accessoires[k].piece = q }
        }
        s.noms.maison = maison
        return EntreeScene(surveillance: s, reseau: r, places: places)
    }

    /// La provenance (polissage C, section 5.4) : maison, piece, Echap : la maison ; maison, etage, piece, Echap :
    /// l'etage, puis Echap : la maison, l'etage relache. D'une piece a une autre du meme etage, la provenance reste ; vers
    /// une piece d'un autre etage, elle devient la maison. Le clic a cote remonte de meme. Une piece d'un autre etage,
    /// ouverte depuis un etage isole : Echap remonte a l'etage de la piece, celui du fil (spec 5.4 precisee).
    @Test func provenance() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        let salon = try MoteurPiecesTests.indice(e, "Salon"), cuisine = try MoteurPiecesTests.indice(e, "Cuisine")
        let chambre = try MoteurPiecesTests.indice(e, "Chambre"), rdc = try Self.indiceEtage(e, Self.rdc)
        m.isoler(salon)
        #expect(m.isolement == .piece("piece:Salon", provenance: nil) && m.estIsolee)
        m.sortir()
        #expect(m.isolement == .maison && !m.estIsolee && m.sansIsolement, "maison, piece, Echap : la maison")
        m.allerEtage(rdc)
        #expect(m.isolement == .etage(Self.rdc))
        m.isoler(salon)
        #expect(m.isolement == .piece("piece:Salon", provenance: Self.rdc))
        m.isoler(cuisine)
        #expect(m.isolement == .piece("piece:Cuisine", provenance: Self.rdc), "une piece du meme etage : la provenance reste")
        m.sortir()
        #expect(m.isolement == .etage(Self.rdc) && !m.estIsolee, "maison, etage, piece, Echap : l'etage")
        m.sortir()
        #expect(m.isolement == .maison && m.sansIsolement, "puis Echap : la maison")
        m.allerEtage(rdc)
        m.isoler(salon)
        m.isoler(chambre)
        #expect(m.isolement == .piece("piece:Chambre", provenance: nil), "une piece d'un autre etage : la maison")
        m.remonter(clavier: false)
        #expect(m.isolement == .maison, "le clic a cote")
        let etage = try Self.indiceEtage(e, Self.etage)
        m.allerEtage(rdc)
        m.isoler(chambre)
        #expect(m.isolement == .piece("piece:Chambre", provenance: Self.rdc) && m.fil.etage?.etage == etage)
        m.sortir()
        #expect(m.isolement == .etage(Self.etage) && m.fil == Fil(etage: Fil.Cran(nom: "Étage", etage: etage), piece: nil),
                "une piece d'un autre etage, ouverte depuis un etage isole : Echap, l'etage de la piece")
    }

    /// Le fil (polissage C, section 5.3) : « Maison › Etage › Piece », meme pour une piece isolee depuis la vue
    /// d'ensemble ; « Maison › Etage » pour un etage isole ; « Maison » seul a la maison ; « Maison › Piece » dans une
    /// maison d'un seul plateau.
    @Test func fil() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        let salon = try MoteurPiecesTests.indice(e, "Salon"), rdc = try Self.indiceEtage(e, Self.rdc)
        let etage = try Self.indiceEtage(e, Self.etage)
        m.isoler(salon)
        #expect(m.fil == Fil(etage: Fil.Cran(nom: "Rez-de-chaussée", etage: rdc), piece: "Salon"))
        m.allerEtage(etage)
        #expect(m.fil == Fil(etage: Fil.Cran(nom: "Étage", etage: etage), piece: nil))
        m.versMaison()
        #expect(m.fil == Fil())
        let (s, r, _) = try NomsSceneTests.demo()
        s.noms.maison?.zones = nil
        let seul = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
        #expect(seul.scene.etages.count == 1)
        let n = MoteurPiecesTests.moteur(seul)
        n.isoler(try MoteurPiecesTests.indice(seul, "Salon"))
        #expect(n.fil == Fil(etage: nil, piece: "Salon"))
    }

    /// La priorite des clics (polissage C, section 5.1) : un appareil, une piece (son bloc ou son nom), le nom d'un
    /// etage, son disque, le fond. En 3D, vus d'assez haut pour que les disques se recouvrent a l'ecran : celui du
    /// niveau le plus haut, le plus proche sur le rayon ; un appareil ou une piece sous le nom d'un etage passe devant
    /// lui.
    @Test(arguments: [false, true]) func prioriteDesClics(troisD: Bool) throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url, troisD: troisD)
        if troisD {
            m.fige = true
            m.poserInclinaison(0.3)
            for _ in 0..<2 { MoteurPiecesTests.dessiner(m) }
        }
        let p = try #require(m.projetee)
        let pastille = try #require(p.disques.first { $0.opacite > 0.5 })
        #expect(m.cibleClic(en: pastille.centre) == .appareil(pastille.noeud))
        let nomPiece = try #require(m.etiquettes.first { if case .piece = $0.genre { $0.vu } else { false } })
        if case .piece(let i) = nomPiece.genre {
            #expect(m.cibleClic(en: CGPoint(x: nomPiece.rect.midX, y: nomPiece.rect.midY)) == .piece(i))
        }
        var nomsLibres = 0
        for k in e.scene.etages.indices {
            let q = try Self.nomDEtage(m, k)
            let attendu: CibleClic = if let n = m.noeudSous(q) { .appareil(n) } else if let i = m.pieceSous(q) {
                .piece(i)
            } else {
                .nomEtage(k)
            }
            #expect(m.cibleClic(en: q) == attendu, "le nom de l'etage \(k)")
            if attendu == .nomEtage(k) { nomsLibres += 1 }
        }
        #expect(troisD ? nomsLibres > 0 : nomsLibres == e.scene.etages.count, "\(nomsLibres) noms d'etage libres")
        #expect(m.cibleClic(en: CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3)) == .fond)
        var superposes = 0
        for x in stride(from: 10.0, to: MoteurPiecesTests.taille.width, by: 20) {
            for y in stride(from: 10.0, to: MoteurPiecesTests.taille.height, by: 20) {
                let q = CGPoint(x: x, y: y)
                guard case .disque(let k) = m.cibleClic(en: q) else { continue }
                let sous = p.plateaux.filter { SceneProjetee.contient($0.polygone, q) }.map(\.etage)
                #expect(sous.contains(k) && m.pieceSous(q) == nil && m.noeudSous(q) == nil && m.nomEtageSous(q) == nil)
                let haut = sous.map { m.geometrie.centrePlateau($0, m.t).y }.max() ?? 0
                #expect(m.geometrie.centrePlateau(k, m.t).y == haut, "le disque le plus haut, en \(q)")
                if sous.count > 1 { superposes += 1 }
            }
        }
        if troisD { #expect(superposes > 0, "des disques l'un sur l'autre a l'ecran") }
    }

    /// Clic sur le nom ou le disque d'un etage (polissage C, sections 5.1 et 5.4) : il l'isole ; son propre disque,
    /// entre les pieces, ne fait rien ; le disque d'un autre etage y mene ; le clic a cote ramene a la maison. En
    /// piece isolee, le disque de son etage isole cet etage. Un double-clic sur un disque ramene a la maison. Les clics
    /// visent la vue d'ensemble : le vol de chaque isolement ne commence qu'a l'image suivante. Au bout du vol, son propre
    /// disque ne fait toujours rien : aucun vol ne repart.
    @Test func cliquerUnEtage() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        let rdc = try Self.indiceEtage(e, Self.rdc), etage = try Self.indiceEtage(e, Self.etage)
        let nom = try Self.nomDEtage(m, etage), disqueEtage = try Self.pointDeDisque(m, etage)
        let disqueRdc = try Self.pointDeDisque(m, rdc), fond = CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3)
        m.cliquer(nom)
        #expect(m.isolement == .etage(Self.etage) && m.fil.etage?.etage == etage)
        m.cliquer(disqueEtage)
        #expect(m.isolement == .etage(Self.etage) && m.enMouvement, "son propre disque : rien")
        m.cliquer(disqueRdc)
        #expect(m.isolement == .etage(Self.rdc), "le disque d'un autre etage")
        m.cliquer(fond)
        #expect(m.isolement == .maison && m.sansIsolement, "le clic a cote")
        m.isoler(try MoteurPiecesTests.indice(e, "Salon"))
        m.cliquer(disqueRdc)
        #expect(m.isolement == .etage(Self.rdc), "depuis une piece, le disque de son etage l'isole")
        m.relacher(disqueEtage, a: 500)
        #expect(m.isolement == .etage(Self.etage))
        m.relacher(disqueEtage, a: 500.1)
        #expect(m.isolement == .maison, "le double-clic sur un disque : la maison")
        m.allerEtage(etage)
        m.fige = true
        MoteurPiecesTests.dessiner(m)
        #expect(m.ligneNiveau == .etageIsole("Étage"))
        #expect(LigneNiveauVue.texte(.etageIsole("Étage"))
                == String(localized: "Étage isolé : \("Étage") · clic sur une pièce ou un autre étage pour y aller, clic à côté ou Échap pour revenir"))
        // Au bout du vol : le clic sur son propre disque, plus haut, partait pendant un vol, qui ne prouvait rien.
        m.fige = false
        Thread.sleep(forTimeInterval: CameraScene.dureeVol + 0.1)
        MoteurPiecesTests.dessiner(m)
        #expect(!m.enMouvement && m.indiceEtageIsole == etage, "le vol est fini")
        m.cliquer(try Self.pointDeDisque(m, etage))
        #expect(m.isolement == .etage(Self.etage) && !m.enMouvement, "son propre disque, au bout du vol : rien")
    }

    /// Le survol d'un disque cliquable l'eclaircit, le nom d'un etage se souligne, et la main dit ce qui se clique ;
    /// le disque de l'etage isole ne se clique pas.
    @Test func survol() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        let etage = try Self.indiceEtage(e, Self.etage)
        let disque = try Self.pointDeDisque(m, etage)
        m.survoler(disque)
        #expect(m.survolEtage == etage && m.curseurForme == .main && m.cibleMenu == .etage(Self.etage))
        m.survoler(try Self.nomDEtage(m, etage))
        #expect(m.survolNomEtage == etage && m.survolEtage == nil && m.curseurForme == .main)
        m.survoler(CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3))
        #expect(m.survolEtage == nil && m.survolNomEtage == nil && m.curseurForme == .fleche && m.cibleMenu == .fond)
        m.allerEtage(etage)
        m.survoler(disque)
        #expect(m.survolEtage == nil && m.curseurForme == .fleche, "le disque de l'etage isole")
    }

    /// Le menu du clic droit (polissage C, section 1.3), article par article, sur le nom et sur le disque, par la cle de
    /// son plateau : le nom de la zone en tete ; « Monter » et « Descendre », grises en haut et en bas de la pile et pour
    /// une zone a cote ; « Au meme niveau que », les autres niveaux, chacun par la cle de son etage principal, coche celui
    /// de la zone ; « Hors de la maison » coche ; « Sur son propre niveau ». Rien sur une piece ; le fond ailleurs.
    @Test func menuDuClicDroit() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        for (k, et) in e.scene.etages.enumerated() {
            let nom = try Self.nomDEtage(m, k), disque = try Self.pointDeDisque(m, k)
            #expect(m.cible(en: nom) == .etage(et.id) && m.cible(en: disque) == .etage(et.id), "le nom et le disque de \(et.id)")
        }
        #expect(m.cible(en: try MoteurPiecesTests.pointDePiece(m, try MoteurPiecesTests.indice(e, "Salon"))) == .aucune)
        #expect(m.cible(en: CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3)) == .fond)
        typealias N = MenuEtage.Niveau
        #expect(m.menuEtage(Self.rdc) == MenuEtage(nom: "Rez-de-chaussée", monter: true, descendre: false,
                                                   niveaux: [N(niveau: Self.etage, nom: "Étage", coche: false),
                                                             N(niveau: Self.combles, nom: "Combles", coche: false)],
                                                   aCote: false, dehors: false))
        #expect(m.menuEtage(Self.jardin) == MenuEtage(nom: "Jardin", monter: false, descendre: false,
                                                      niveaux: [N(niveau: Self.rdc, nom: "Rez-de-chaussée", coche: true),
                                                                N(niveau: Self.etage, nom: "Étage", coche: false),
                                                                N(niveau: Self.combles, nom: "Combles", coche: false)],
                                                      aCote: true, dehors: true))
        #expect(m.menuEtage(Self.combles).map { !$0.monter && $0.descendre } == true)
        #expect(m.menuEtage(Self.etage).map { $0.monter && $0.descendre } == true)
        // Chaque choix est garde, dans le fichier ; la scene suivante le prend.
        func rangement() -> Rangement { PlacesGardees.lire(url).rangement(e.domicile) }
        m.basculerDehors(Self.jardin)
        #expect(rangement().aCote[Self.jardin] == PlacesGardees.ACote(etage: Self.rdc, dehors: false))
        m.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(m.places))
        m.deplacerEtage(Self.rdc, de: 1)
        #expect(rangement().ordre == [Self.etage, Self.rdc, Self.jardin, Self.combles], "le niveau entier, jardin compris")
        m.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(m.places))
        m.mettreAuNiveau(Self.combles, de: Self.etage)
        #expect(rangement().aCote[Self.combles] == PlacesGardees.ACote(etage: Self.etage), "a cote de l'etage, en bas")
        m.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(m.places))
        m.mettreSurSonNiveau(Self.jardin)
        #expect(rangement().aCote[Self.jardin] == nil)
        m.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(m.places))
        #expect(m.entree?.scene.niveaux.liste == [[Self.etage, Self.combles], [Self.rdc], [Self.jardin]])
    }

    /// Deux choix du menu de suite (relecture de la tache 5, Important 1) : « Sur son propre niveau » sur le jardin, puis
    /// « Monter d'un etage » sur le rez-de-chaussee, pendant que la scene du premier attend, le calcul de sa disposition
    /// ou la fin d'un vol. Le second se calcule sur la scene la plus recente et sur les choix gardes : il ne defait pas le
    /// premier. Le menu ouvert entre les deux suit le premier choix : le jardin n'est plus a cote.
    @Test(arguments: [false, true]) func deuxChoixPendantQuUneSceneAttend(pendantUnVol: Bool) throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        guard case .etage(let jardin) = try Self.cibleDuNom(m, e, Self.jardin),
              case .etage(let rdc) = try Self.cibleDuNom(m, e, Self.rdc) else {
            Issue.record("le nom d'un etage ouvre son menu")
            return
        }
        if pendantUnVol { m.allerEtage(try Self.indiceEtage(e, Self.combles)) }
        m.mettreSurSonNiveau(jardin)
        m.recevoir(try MoteurPiecesTests.quatrePlateaux(m.places))
        #expect(m.entree == e && m.enMouvement == pendantUnVol, "la scene du premier choix attend")
        #expect(m.menuEtage(jardin).map { !$0.aCote && $0.monter && $0.descendre } == true, "le menu suit le premier choix")
        m.deplacerEtage(rdc, de: 1)
        #expect(PlacesGardees.lire(url).rangement(e.domicile)
                == Rangement(ordre: [Self.jardin, Self.rdc, Self.etage, Self.combles], aCote: [:]), "les deux choix, gardes")
    }

    /// Un menu ouvert pendant qu'une scene s'installe (relecture de la tache 5, Important 1) : ses articles designent le
    /// plateau et le niveau par leur cle, et non par un indice qui perimerait. Le niveau : le menu des combles s'ouvre
    /// juste apres « Sur son propre niveau » sur le jardin, la scene de ce choix s'installe, puis « Au meme niveau que ›
    /// Etage » met les combles a cote de l'etage, et non du jardin, qui a pris son rang. Le plateau : le menu du jardin
    /// s'ouvre juste apres « Descendre d'un etage » sur l'etage, la scene de ce choix change l'ordre des plateaux, puis
    /// « Sur son propre niveau » vise toujours le jardin.
    @Test func menuOuvertPendantQuUneSceneSInstalle() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        func rangement() -> Rangement { PlacesGardees.lire(url).rangement(e.domicile) }
        guard case .etage(let jardin) = try Self.cibleDuNom(m, e, Self.jardin),
              case .etage(let combles) = try Self.cibleDuNom(m, e, Self.combles) else {
            Issue.record("le nom d'un etage ouvre son menu")
            return
        }
        m.mettreSurSonNiveau(jardin)
        let versEtage = try #require(m.menuEtage(combles)?.niveaux.first { $0.nom == "Étage" })
        m.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(m.places))
        m.mettreAuNiveau(combles, de: versEtage.niveau)
        #expect(rangement().aCote[Self.combles] == PlacesGardees.ACote(etage: Self.etage), "le niveau, par sa cle")
        let (n, _) = try Self.jardinDehors(url)
        guard case .etage(let jardinN) = try Self.cibleDuNom(n, e, Self.jardin),
              case .etage(let etageN) = try Self.cibleDuNom(n, e, Self.etage) else {
            Issue.record("le nom d'un etage ouvre son menu")
            return
        }
        n.deplacerEtage(etageN, de: -1)
        n.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(n.places))
        n.mettreSurSonNiveau(jardinN)
        #expect(rangement() == Rangement(ordre: [Self.etage, Self.rdc, Self.jardin, Self.combles], aCote: [:]),
                "le plateau, par sa cle")
    }

    /// Un etage isole (polissage C, section 5.1) : les autres plateaux a 15 %, la sphere effacee, la rotation lente
    /// arretee ; les pieces de l'etage isole se glissent, celles des autres etages seulement se cliquent ; seuls les
    /// noms des appareils de l'etage isole sont voulus, selon le zoom.
    @Test func etageIsole() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        m.reduire = true
        let etage = try Self.indiceEtage(e, Self.etage)
        let salon = try MoteurPiecesTests.indice(e, "Salon"), chambre = try MoteurPiecesTests.indice(e, "Chambre")
        let pointSalon = try MoteurPiecesTests.pointDePiece(m, salon), pointChambre = try MoteurPiecesTests.pointDePiece(m, chambre)
        m.allerEtage(etage)
        #expect(!m.sansIsolement && m.indiceEtageIsole == etage)
        for (i, d) in [(salon, pointSalon), (chambre, pointChambre)] {
            let avant = m.positions[i]
            m.glisser(d, depart: d)
            m.glisser(CGPoint(x: d.x + 40, y: d.y), depart: d)
            m.relacher(CGPoint(x: d.x + 40, y: d.y))
            #expect((m.positions[i] != avant) == (i == chambre), "piece \(i)")
        }
        let t = MoteurPieces(troisD: true)
        t.marges = (84, 50)
        t.poserTaille(MoteurPiecesTests.taille)
        t.installerMaintenant(e)
        t.poserEtageIsole(etage)
        t.fige = true
        MoteurPiecesTests.dessiner(t)
        let p = try #require(t.projetee)
        #expect(p.plateaux.allSatisfy { abs($0.opacite - ($0.etage == etage ? 1 : 0.15)) < 1e-9 })
        #expect(p.sphere == nil && t.ligneNiveau == .etageIsole("Étage"))
        t.poserZoom(echelle: 1, vers: t.geometrie.centrePlateau(etage, t.t))
        MoteurPiecesTests.dessiner(t)
        let voulus = t.etiquettes.compactMap { l -> String? in if case .noeud(let id) = l.genre, l.voulu { id } else { nil } }
        #expect(t.projetee?.niveau == .tous && !voulus.isEmpty, "\(voulus.count) noms voulus")
        #expect(voulus.allSatisfy { id in e.scene.noeud(id).map { e.scene.pieces[$0.piece].etage == etage } == true },
                "seuls les noms des appareils de l'etage isole : \(voulus)")
        t.fige = false
        let azimut = t.orbite.azimut
        MoteurPiecesTests.dessiner(t)
        MoteurPiecesTests.dessiner(t)
        #expect(t.orbite.azimut == azimut, "la rotation lente s'arrete")
    }

    /// Triage A, n° 8 : pendant le retour d'une piece isolee, les noms des appareils suivent l'etat d'arrivee, et la
    /// ligne de niveau suit le zoom, au lieu de dire « Tous les noms sont lisibles » sans nom affiche.
    @Test func numero8() throws {
        let (m, e) = try MoteurPiecesTests.moteur()
        m.fige = true
        m.poserIsolement(try MoteurPiecesTests.indice(e, "Salon"))
        MoteurPiecesTests.dessiner(m)
        #expect(m.ligneNiveau == .isolee("Salon"))
        m.versMaison()
        MoteurPiecesTests.dessiner(m)
        #expect(m.focus != nil && m.s == 1 && !m.estIsolee, "en plein retour")
        let voulus = m.etiquettes.filter { if case .noeud = $0.genre { $0.voulu } else { false } }
        #expect(!voulus.isEmpty, "les noms de la maison, selon le zoom")
        let p = try #require(m.projetee)
        let ancres = m.etiquettes.map { l -> CGRect? in if case .noeud(let id) = l.genre { p.ancresNoeuds[id] } else { nil } }
        let masques = PlacementNoms.masques(m.etiquettes, ancres: ancres, cadre: MoteurPiecesTests.taille)
        #expect(m.ligneNiveau == (masques > 0 ? .masques(masques) : .lisibles), "la ligne suit les noms voulus")
    }

    /// Triage A, n° 9 : avec « Reduire les animations », un releve recu pendant le fondu d'un isolement ne remet pas la
    /// piece a pleine taille : sa part de l'isolement, et celle de son etage, sont gardees par cle.
    @Test func numero9() throws {
        let (m, e) = try MoteurPiecesTests.moteur()
        m.reduire = true
        m.isoler(try MoteurPiecesTests.indice(e, "Salon"))
        MoteurPiecesTests.dessiner(m)
        MoteurPiecesTests.dessiner(m)
        let part = try #require(m.fk["piece:Salon"]), partEtage = try #require(m.ek["zone:Rez-de-chaussée"])
        #expect(part > 0 && part < 1 && partEtage > 0 && partEtage < 1, "en plein fondu : \(part), \(partEtage)")
        var autre = e
        autre.apparences["Apple TV 4K"] = DessinNoeud.Apparence(forme: .anneau, couleur: .appareil(.disparu))
        m.installerMaintenant(autre)
        #expect(m.entree == autre && m.fk["piece:Salon"] == part && m.ek["zone:Rez-de-chaussée"] == partEtage && m.estIsolee)
    }

    /// Une piece isolee qui disparait d'une scene qui arrive (relecture de la tache 5, Important 2) : ses appareils sont
    /// passes dans une autre piece. La vue revient a la maison, comme avant les etages : plus d'etage isole orphelin, la
    /// vue d'ensemble recadree, la sphere et la rotation lente de retour, « Maison » seul dans le fil. Une piece quittee
    /// pour un etage, qui disparait en route : l'etage reste isole.
    @Test func pieceIsoleeQuiDisparait() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url, troisD: true)
        m.poserIsolement(try MoteurPiecesTests.indice(e, "Cuisine"))
        MoteurPiecesTests.dessiner(m)
        #expect(m.estIsolee && m.etageEnVue == Self.rdc && !m.sansIsolement)
        let azimut = m.orbite.azimut
        let sans = try Self.sceneQuiArrive(e, places: m.places, deplacer: ["Cuisine": "Salon"])
        #expect(!sans.scene.pieces.contains { $0.id == "piece:Cuisine" } && sans.scene.etages.map(\.id) == e.scene.etages.map(\.id))
        m.installerMaintenant(sans)
        #expect(m.entree == sans && m.isolement == .maison && m.focus == nil && m.etageEnVue == nil && m.se == 0)
        #expect(m.sansIsolement && m.aLaVueDEnsemble && m.fil == Fil(), "la maison, sans etage isole orphelin")
        var ensemble = CameraScene.canonique(m.geometrie, aspect: m.aspect, u: 1)
        ensemble.azimut = m.orbite.azimut
        ensemble.inclinaison = m.orbite.inclinaison
        #expect(m.orbite == ensemble, "la vue d'ensemble, recadree")
        for _ in 0..<2 { MoteurPiecesTests.dessiner(m) }
        let p = try #require(m.projetee)
        #expect(p.voilesEtages.allSatisfy { $0 == 1 } && p.sphere != nil, "les plateaux nets, la sphere : \(p.voilesEtages)")
        #expect(m.orbite.azimut < azimut, "la rotation lente reprend")
        // « Reduire les animations » : pas de vol, une scene peut s'installer pendant que la cuisine se relache.
        let (n, _) = try Self.jardinDehors(url)
        n.reduire = true
        n.poserIsolement(try MoteurPiecesTests.indice(e, "Cuisine"))
        n.allerEtage(try Self.indiceEtage(e, Self.etage))
        #expect(n.focus != nil && !n.enMouvement && n.isolement == .etage(Self.etage), "la cuisine quittee pour l'etage, en route")
        n.installerMaintenant(sans)
        #expect(n.focus == nil && n.isolement == .etage(Self.etage) && n.etageEnVue == Self.etage && n.se == 1,
                "l'etage reste isole")
    }

    /// Une piece isolee qui change de zone dans une scene qui arrive (relecture de la tache 5, Important 2) : l'etage en
    /// vue suit le sien ; la piece, ses pastilles et son nouvel etage restent nets, les autres plateaux a 15 %.
    @Test func pieceIsoleeQuiChangeDEtage() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        m.poserIsolement(try MoteurPiecesTests.indice(e, "Cuisine"))
        MoteurPiecesTests.dessiner(m)
        #expect(m.etageEnVue == Self.rdc)
        let montee = try Self.sceneQuiArrive(e, places: m.places) { zones in
            for k in zones.indices { zones[k].pieces.removeAll { $0 == "Cuisine" } }
            if let k = zones.firstIndex(where: { $0.nom == "Étage" }) { zones[k].pieces.append("Cuisine") }
        }
        let cuisine = try MoteurPiecesTests.indice(montee, "Cuisine")
        let rdc = try Self.indiceEtage(montee, Self.rdc), etage = try Self.indiceEtage(montee, Self.etage)
        #expect(montee.scene.pieces[cuisine].etage == etage)
        m.installerMaintenant(montee)
        #expect(m.isolement == .piece("piece:Cuisine", provenance: nil) && m.focus == cuisine && m.etageEnVue == Self.etage)
        #expect(m.fil == Fil(etage: Fil.Cran(nom: "Étage", etage: etage), piece: "Cuisine"))
        // La part de l'etage en vue tend vers 1, image apres image (d'un dixieme de seconde au plus chacune).
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.1)
            MoteurPiecesTests.dessiner(m)
        }
        let p = try #require(m.projetee)
        #expect(p.voilesEtages[etage] > 0.99 && p.voilesEtages[rdc] < 0.2, "\(p.voilesEtages)")
        let pastilles = p.disques.filter { montee.scene.noeud($0.noeud)?.piece == cuisine }
        #expect(!pastilles.isEmpty && pastilles.allSatisfy { $0.opacite > 0.99 }, "la piece isolee, nette")
    }
}
