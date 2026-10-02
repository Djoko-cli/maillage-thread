import AppKit
import MaillageCoeur
import os
import QuartzCore
import SwiftUI
import simd

/// Ligne de niveau, en bas a gauche de la vue (spec de la vue par pieces, section 6).
enum LigneNiveau: Equatable {
    case isolee(String)
    case pieces
    case routeurs
    case masques(Int)
    case lisibles
}

/// Cible d'un clic droit : un nom d'etage, ou le fond (spec, section 7).
enum CibleMenu: Equatable {
    case aucune
    case etage(Int)
    case fond
}

/// Moteur de la vue par pieces (spec, sections 4 a 7) : la scene recue et sa disposition, calculee
/// hors du fil principal ; la camera et ses animations (envol, vols, isolement, rotation lente,
/// amortis) ; les gestes ; les places gardees ; et chaque image du `Canvas`. SwiftUI n'observe que ce
/// que les vues autour lisent (mode, rotation, horloge, piece isolee, selection, ligne de niveau,
/// menu, places) : le reste change a chaque image sans relancer leur corps.
@MainActor
@Observable
final class MoteurPieces {
    /// Mode vise : 3D ou 2D (l'envol peut etre en cours).
    private(set) var troisD: Bool
    var rotation = true
    /// Horloge en marche : seulement pendant un mouvement, et 0,6 s apres.
    private(set) var anime = true
    /// Nom de la piece isolee (le fil) ; nil sinon.
    private(set) var isolee: String?
    var selection: String?
    private(set) var ligneNiveau = LigneNiveau.lisibles
    private(set) var cibleMenu = CibleMenu.aucune
    private(set) var places: PlacesGardees
    /// La premiere disposition est calculee.
    private(set) var pret = false
    /// « Reduire les animations » (accessibilite de macOS).
    var reduire = false {
        didSet { reveiller() }
    }

    nonisolated static let journal = Logger(subsystem: "fr.djoko.maillage", category: "pieces")

    // MARK: Etat non observe

    @ObservationIgnored private let fichierPlaces: URL?
    /// Scene affichee, posee sur sa disposition.
    @ObservationIgnored private(set) var entree: EntreeScene?
    /// Scene recue pendant un mouvement ou un glisser : appliquee a sa fin.
    @ObservationIgnored private var attente: EntreeScene?
    /// Scene dont la disposition se calcule : `entree` reste affichee jusqu'a la fin du calcul.
    @ObservationIgnored private var enCalcul: EntreeScene?
    @ObservationIgnored private var calcul: Task<Void, Never>?
    @ObservationIgnored private var cleCalculee: [String: [String: [String]]]?
    @ObservationIgnored private var placesCalculees: [String: SIMD2<Double>] = [:]
    @ObservationIgnored private var rayonsCalcules: [String: Double] = [:]
    @ObservationIgnored private var cartesCalculees: [String: CartesPieces.Carte] = [:]
    @ObservationIgnored private(set) var cartes: [CartesPieces.Carte] = []
    @ObservationIgnored private(set) var positions: [SIMD2<Double>] = []
    @ObservationIgnored private(set) var geometrie = GeometrieMaison(rayons: [])
    @ObservationIgnored private(set) var orbite = Orbite(cible: .zero, distance: 1000, azimut: 0, inclinaison: 0.0001, champ: 2)
    @ObservationIgnored private var taille = CGSize.zero
    /// Marges du haut (le haut de la fenetre, mesure) et du bas (la pile du bas, mesuree : la legende et la ligne
    /// de niveau, puis la fiche), posees par la vue : la place utile de la vue d'ensemble. Le cadre les rejoint en
    /// 0,3 s, sur la courbe de la fiche qui glisse (`Apparition`) : la vue se releve avec elle, au-dessus de la pile,
    /// ou descend sous un bandeau ; en 0,45 s quand la legende s'ouvre ou se replie (`legendeBasculee`) ; avec
    /// « Reduire les animations », par un fondu.
    @ObservationIgnored var marges: (haut: CGFloat, bas: CGFloat) = (0, 0)
    /// Marges du cadre, et leur glissement en cours vers `marges`.
    @ObservationIgnored private var margesCadre: (haut: CGFloat, bas: CGFloat)?
    @ObservationIgnored private var glissement: GlissementMarges?
    /// Duree du prochain glissement des marges : celle de la legende, qui vient de s'ouvrir ou de se replier
    /// (`legendeBasculee`) ; nil, celle de la fiche et des bandeaux.
    @ObservationIgnored private var dureeAnnoncee: Double?
    /// Opacite de la scene pendant le fondu des marges (« Reduire les animations ») ; 1 sinon.
    @ObservationIgnored private(set) var opaciteMarges = 1.0
    @ObservationIgnored private(set) var cadre = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// Bascule adoucie : 0 en 2D, 1 en 3D.
    @ObservationIgnored private(set) var t: Double
    @ObservationIgnored private var envol: Envol?
    @ObservationIgnored private var debutEnvol = 0.0
    /// « Reduire les animations » : l'envol, et le retour a la vue d'ensemble par double-clic, sont un
    /// fondu ; la camera saute a mi-chemin.
    @ObservationIgnored private var fondu: Fondu?
    @ObservationIgnored private var opaciteFondu = 1.0
    /// Isolement : `s` general, `fk` propre a chaque piece.
    @ObservationIgnored private(set) var s = 0.0
    @ObservationIgnored private var sCible = 0.0
    @ObservationIgnored private var sDepart = 0.0
    @ObservationIgnored private var sDebut = 0.0
    @ObservationIgnored private(set) var focus: Int?
    @ObservationIgnored private(set) var fk: [Double] = []
    @ObservationIgnored private var vol: Vol?
    @ObservationIgnored private var debutVol = 0.0
    @ObservationIgnored private(set) var survol: String?
    @ObservationIgnored private var curseur: CGPoint?
    @ObservationIgnored private var zoomEnAttente = 0.0
    @ObservationIgnored private var ancreZoom: SIMD3<Double>?
    @ObservationIgnored private var dernierPincement = 1.0
    @ObservationIgnored private var rotationEnAttente = SIMD2<Double>.zero
    @ObservationIgnored private var geste: Geste?
    /// Point de depart du geste en cours : un glisser qui part d'ailleurs en commence un autre.
    @ObservationIgnored private var departGeste = CGPoint.zero
    @ObservationIgnored private var bouge = false
    /// Le dernier geste, qui avait bouge, a ete clos par `abandonnerGeste` : si son relachement arrive
    /// encore (SwiftUI peut remettre l'etat du geste a zero avant d'appeler `onEnded`), ce n'est pas un
    /// clic.
    @ObservationIgnored private var abandonApresGlisser = false
    @ObservationIgnored private var precedent = CGPoint.zero
    @ObservationIgnored private var derniereActivite = 0.0
    @ObservationIgnored private var instant: Double?
    @ObservationIgnored private var dt = 0.0
    /// Djoko a zoome ou deplace la vue : un redimensionnement ne la recadre plus.
    @ObservationIgnored private(set) var vueTouchee = false
    @ObservationIgnored private(set) var etiquettes: [Etiquette] = []
    @ObservationIgnored private(set) var textes = TextesScene()
    /// Noeuds routeurs (leur nom en 12 points) et teinte de chaque piece, pour le dessin.
    @ObservationIgnored private var routeurs: Set<String> = []
    @ObservationIgnored private var teintes: [Int: Int] = [:]
    @ObservationIgnored private(set) var projetee: SceneProjetee?
    @ObservationIgnored private var traits: [PlacementNoms.Trait] = []
    /// Cles des pieces et des etages de la scene des noms : un nom garde son etat d'une scene a l'autre.
    @ObservationIgnored private var clesPieces: [String] = []
    @ObservationIgnored private var clesEtages: [String] = []
    @ObservationIgnored private let cache = CacheTextes()
    @ObservationIgnored private let mesure = MesureNoms()
    /// Ce qui est pose sur la vue (barre, fil, ligne de niveau, legende, fiche), par element : les noms
    /// l'evitent.
    @ObservationIgnored var cadresInterface: [String: CGRect] = [:]
    /// Fenetre de la vue : la molette et Echap ne valent que pour elle.
    @ObservationIgnored weak var fenetre: NSWindow?
    @ObservationIgnored private var moniteur: Any?
    /// Captures : l'etat est pose a la main, l'horloge n'avance pas.
    @ObservationIgnored var fige = false

    /// Dernier clic sur le fond (instant, point) : un second, assez pres et assez tot, est un double-clic.
    @ObservationIgnored private var clicFond: (instant: Double, point: CGPoint)?

    private enum Geste {
        case fond
        /// Une piece qu'on glisse (son identifiant, jamais un indice qui perimerait), sur le plan
        /// horizontal y = `hauteur`.
        case piece(String, hauteur: Double)
    }

    /// Glissement des marges du cadre, de `depart` a `arrivee`, depuis `debut`, en `duree` ; `fondu` : avec
    /// « Reduire les animations », un fondu par le fond, les marges sautant a mi-chemin.
    private struct GlissementMarges {
        var depart: (haut: CGFloat, bas: CGFloat)
        var arrivee: (haut: CGFloat, bas: CGFloat)
        var debut: Double
        var duree: Double
        var fondu: Bool
    }

    /// Fondu de 0,3 s par le fond (« Reduire les animations ») : la scene s'efface, la camera saute a
    /// mi-chemin, la scene revient.
    private struct Fondu {
        var debut: Double
        /// Avancement de la bascule vise : 0 en 2D, 1 en 3D (le meme pour un retour a la vue d'ensemble).
        var arrivee: Double
        /// Camera a mi-chemin : la fin du vol (retour a la vue d'ensemble) ; nil : la vue d'ensemble du
        /// mode vise (bascule).
        var orbite: Orbite?
        var saute = false
    }

    /// `troisD` : le mode garde ; `fichierPlaces` : `positions-pieces.json` (nil : ni lu ni ecrit).
    init(troisD: Bool = false, fichierPlaces: URL? = nil, selection: String? = nil) {
        self.troisD = troisD
        t = troisD ? 1 : 0
        self.fichierPlaces = fichierPlaces
        places = fichierPlaces.map(PlacesGardees.lire) ?? PlacesGardees()
        self.selection = selection
    }

    static func maintenant() -> Double { CACurrentMediaTime() }

    var scene: ScenePieces? { entree?.scene }
    var aspect: Double { cadre.height > 0 ? Double(cadre.width / cadre.height) : 1.6 }
    /// Une piece est isolee (et non en train d'etre quittee).
    var estIsolee: Bool { focus != nil && sCible == 1 }
    var enMouvement: Bool { envol != nil || fondu != nil || vol != nil }
    /// Un mouvement, ou un glisser en cours (spec, sections 5 et 7) : une scene recue attend sa fin.
    var occupe: Bool { enMouvement || geste != nil }

    // MARK: Scene et disposition

    /// Nouvelle scene : appliquee tout de suite, ou a la fin du mouvement en cours (envol, vol, fondu)
    /// ou du glisser. Si ses etages, ses pieces, ses noeuds ou leurs noms changent, la disposition est
    /// recalculee hors du fil principal ; l'ancienne reste affichee pendant ce temps.
    func recevoir(_ e: EntreeScene) {
        if occupe {
            attente = e
            return
        }
        appliquer(e)
    }

    private func appliquer(_ e: EntreeScene) {
        attente = nil
        let cle = e.cleDisposition
        if cle == cleCalculee {
            calcul?.cancel()
            enCalcul = nil
            installer(e)
            return
        }
        // Meme structure que la disposition en calcul : elle vaudra pour cette scene.
        if enCalcul?.cleDisposition == cle {
            enCalcul = e
            return
        }
        calculer(e)
    }

    /// Lance le calcul de la disposition d'une scene, hors du fil principal, avec les places gardees
    /// du moment ; un calcul en cours est abandonne.
    private func calculer(_ e: EntreeScene) {
        calcul?.cancel()
        enCalcul = e
        let cle = e.cleDisposition
        let cartes = cartesPour(e)
        let fixees = places.fixees(e.scene, domicile: e.domicile)
        let scene = e.scene
        calcul = Task { [weak self] in
            let d = await Task.detached(priority: .userInitiated) {
                DispositionPieces(scene: scene, cartes: cartes, fixees: fixees)
            }.value
            guard !Task.isCancelled, let self else { return }
            self.retenir(d, scene: scene, cartes: cartes, cle: cle)
        }
    }

    /// La meme chose, sur le fil principal (captures, tests).
    func installerMaintenant(_ e: EntreeScene) {
        calcul?.cancel()
        let cartes = cartesPour(e)
        let d = DispositionPieces(scene: e.scene, cartes: cartes, fixees: places.fixees(e.scene, domicile: e.domicile))
        enCalcul = e
        retenir(d, scene: e.scene, cartes: cartes, cle: e.cleDisposition)
    }

    /// Cartes des pieces d'une scene, d'apres les noms mesures des noeuds.
    private func cartesPour(_ e: EntreeScene) -> [CartesPieces.Carte] {
        var largeurs: [String: Double] = [:]
        for n in e.scene.noeuds {
            guard let l = e.libelles[n.id] else { continue }
            largeurs[n.id] = mesure.noeud(l, routeur: n.rang <= 2).width
        }
        return CartesPieces.cartes(e.scene, largeurs: largeurs)
    }

    /// Une disposition calculee pour `scene` : gardee par cles (piece, etage), d'apres cette scene, dont
    /// elle suit les indices (une scene plus recente de meme structure peut ranger ses etages, donc ses
    /// pieces, dans un autre ordre) ; puis posee avec la derniere scene de cette structure, si une scene
    /// d'une autre structure ne l'a pas depassee ; a la fin du mouvement ou du glisser en cours, s'il y
    /// en a un.
    private func retenir(_ d: DispositionPieces, scene: ScenePieces, cartes: [CartesPieces.Carte],
                         cle: [String: [String: [String]]]) {
        guard let e = enCalcul, e.cleDisposition == cle else { return }
        placesCalculees = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { (scene.pieces[$0].id, d.positions[$0]) })
        rayonsCalcules = Dictionary(scene.etages.indices.map { (scene.etages[$0].id, d.rayons[$0]) },
                                    uniquingKeysWith: { a, _ in a })
        cartesCalculees = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { (scene.pieces[$0].id, cartes[$0]) })
        cleCalculee = cle
        enCalcul = nil
        if occupe {
            if attente == nil { attente = e }
            return
        }
        installer(e)
    }

    /// Pose une scene sur la disposition gardee : positions et rayons retrouves par cles, noms,
    /// piece isolee.
    private func installer(_ e: EntreeScene) {
        let scene = e.scene
        let ancienFocus = focus.flatMap { $0 < clesPieces.count ? clesPieces[$0] : nil }
        entree = e
        cartes = scene.pieces.map { cartesCalculees[$0.id] ?? CartesPieces.carte([]) }
        positions = scene.pieces.map { placesCalculees[$0.id] ?? .zero }
        geometrie = GeometrieMaison(rayons: scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge })
        fk = Array(repeating: 0, count: scene.pieces.count)
        if let cle = ancienFocus, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            focus = i
            fk[i] = 1
        } else if focus != nil {
            focus = nil
            s = 0
            sCible = 0
            isolee = nil
        }
        textes = Self.textes(e, focus: focus)
        routeurs = Set(scene.noeuds.filter { $0.rang <= 2 }.map(\.id))
        teintes = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { ($0, scene.pieces[$0].teinte) })
        construireEtiquettes()
        if !pret {
            pret = true
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        } else if !vueTouchee && focus == nil {
            recadrer()
        }
        reveiller()
    }

    /// Textes des noms : libelles, pieces (nom, compte), etages, maison, reperes « ailleurs ».
    static func textes(_ e: EntreeScene, focus: Int?) -> TextesScene {
        var t = TextesScene()
        t.noeuds = e.libelles
        for (i, p) in e.scene.pieces.enumerated() {
            t.pieces[i] = TextesScene.Piece(nom: LibellesNoeuds.nom(p.nom, libelles: e.libelles),
                                            compte: LibellesNoeuds.compte(p.noeuds.count))
        }
        for (i, et) in e.scene.etages.enumerated() { t.etages[i] = LibellesNoeuds.nom(et.nom) }
        t.maison = String(localized: "⌂ Maison")
        if let f = focus {
            for a in SceneProjetee.reperes(e.scene, focus: f) {
                t.ailleurs[a.enfant] = LibellesNoeuds.ailleurs(a, scene: e.scene, libelles: e.libelles)
            }
        }
        return t
    }

    /// Cle d'un nom, qui ne depend pas des indices de la scene.
    private func cle(_ g: Etiquette.Genre) -> String {
        switch g {
        case .noeud(let id): "n:" + id
        case .piece(let i): "p:" + (i < clesPieces.count ? clesPieces[i] : "")
        case .etage(let i): "e:" + (i < clesEtages.count ? clesEtages[i] : "")
        case .maison: "m"
        case .ailleurs(let id): "a:" + id
        }
    }

    /// Noms de la scene, dans l'ordre de la maquette (appareils, etages, pieces, maison, reperes) ;
    /// chacun garde son etat de placement d'une scene a l'autre.
    private func construireEtiquettes() {
        guard let scene else { return }
        var anciennes: [String: Etiquette] = [:]
        for l in etiquettes { anciennes[cle(l.genre)] = l }
        clesPieces = scene.pieces.map(\.id)
        clesEtages = scene.etages.map(\.id)
        var l: [Etiquette] = []
        func ajouter(_ genre: Etiquette.Genre, _ taille: CGSize) {
            var e = Etiquette(genre, taille: taille)
            if let a = anciennes[cle(genre)] {
                e.place = a.place
                e.envie = a.envie
                e.vu = a.vu
                e.rect = a.rect
                e.rectAvant = a.rectAvant
            }
            l.append(e)
        }
        for n in scene.noeuds {
            ajouter(.noeud(n.id), mesure.noeud(textes.noeuds[n.id] ?? LibellesNoeuds.Libelle(texte: n.id), routeur: n.rang <= 2))
        }
        for i in scene.etages.indices { ajouter(.etage(i), mesure.etage(textes.etages[i] ?? "")) }
        for i in scene.pieces.indices {
            let t = textes.pieces[i] ?? TextesScene.Piece(nom: "", compte: "")
            ajouter(.piece(i), mesure.piece(nom: t.nom, compte: t.compte))
        }
        ajouter(.maison, mesure.maison(textes.maison))
        for (id, texte) in textes.ailleurs.sorted(by: { $0.key < $1.key }) { ajouter(.ailleurs(id), mesure.ailleurs(texte)) }
        etiquettes = l
    }

    // MARK: Places gardees et ordre des etages

    private func enregistrer() {
        guard let fichierPlaces else { return }
        do {
            try places.ecrire(dans: fichierPlaces)
        } catch {
            Self.journal.error("places des pieces non ecrites : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Garde la place d'une piece qu'on vient de glisser : elle est desormais fixee. Un calcul en cours
    /// ne la connait pas : il est relance avec elle (sinon, a sa fin, la piece sauterait a la place
    /// qu'il lui donne). Une place non finie (camera degeneree) n'est pas gardee.
    private func garder(_ id: String) {
        guard let e = entree, let i = e.scene.pieces.firstIndex(where: { $0.id == id }), i < positions.count,
              positions[i].x.isFinite, positions[i].y.isFinite else { return }
        let p = e.scene.pieces[i]
        places.garder(positions[i], piece: p.id, etage: e.scene.etages[p.etage].id, domicile: e.domicile)
        placesCalculees[p.id] = positions[i]
        enregistrer()
        if let c = enCalcul { calculer(c) }
    }

    /// « Monter d'un etage » (+1) ou « Descendre d'un etage » (-1) : echange l'etage avec son voisin,
    /// et garde l'ordre.
    func deplacerEtage(_ i: Int, de pas: Int) {
        guard let e = entree else { return }
        var ordre = e.scene.etages.map(\.id)
        let j = i + pas
        guard ordre.indices.contains(i), ordre.indices.contains(j) else { return }
        ordre.swapAt(i, j)
        places.ordonner(ordre, domicile: e.domicile)
        enregistrer()
    }

    func peutDeplacerEtage(_ i: Int, de pas: Int) -> Bool {
        guard let n = scene?.etages.count else { return false }
        return (0..<n).contains(i) && (0..<n).contains(i + pas)
    }

    /// « Replacer les pieces automatiquement » : oublie les places gardees de la maison (pas l'ordre
    /// des etages) et recalcule la disposition de la scene la plus recente (celle qui attend la fin d'un
    /// mouvement ou d'un geste, sinon celle du calcul en cours, sinon celle affichee) ; l'ancienne reste
    /// affichee pendant ce temps.
    func replacerPieces() {
        guard let e = attente ?? enCalcul ?? entree else { return }
        places.replacer(domicile: e.domicile)
        enregistrer()
        cleCalculee = nil
        enCalcul = nil
        appliquer(e)
    }

    // MARK: Camera

    /// Cadre la vue d'ensemble a l'avancement courant, en gardant l'orbite en 3D.
    func recadrer() {
        var c = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        if t == 1 {
            c.azimut = orbite.azimut
            c.inclinaison = orbite.inclinaison
        }
        orbite = c
    }

    /// Bascule 2D / 3D : un envol de 2,6 s depuis la vue courante (un fondu de 0,3 s si « Reduire
    /// les animations ») ; une piece isolee est relachee.
    func basculer(troisD v: Bool) {
        guard v != troisD else { return }
        troisD = v
        focus = nil
        isolee = nil
        s = 0
        sCible = 0
        fk = fk.map { _ in 0 }
        vol = nil
        zoomEnAttente = 0
        rotationEnAttente = .zero
        vueTouchee = false
        textes = entree.map { Self.textes($0, focus: nil) } ?? textes
        construireEtiquettes()
        let arrivee = v ? 1.0 : 0.0
        if reduire {
            fondu = Fondu(debut: Self.maintenant(), arrivee: arrivee)
        } else {
            envol = Envol(depuis: orbite, t: t, vers: arrivee, geometrie: geometrie, aspect: aspect)
            debutEnvol = Self.maintenant()
        }
        reveiller()
    }

    /// Isole une piece : la camera y vole en 1,3 s (tout de suite si « Reduire les animations »), les
    /// autres s'estompent, ses reperes « ailleurs » apparaissent.
    func isoler(_ i: Int) {
        guard let scene, i < scene.pieces.count, !(focus == i && sCible == 1) else { return }
        focus = i
        isolee = textes.pieces[i]?.nom
        if sCible != 1 {
            sDepart = s
            sCible = 1
            sDebut = Self.maintenant()
        }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        if let v = volVersPiece(i) { voler(v) }
    }

    /// Vol vers une piece, a la hauteur de vue de la spec (section 7).
    private func volVersPiece(_ i: Int) -> Vol? {
        guard let c = centrePiece(i) else { return nil }
        return CameraScene.volVersPiece(orbite, centre: c, largeur: cartes[i].largeur, profondeur: cartes[i].profondeur,
                                        aspect: aspect, troisD: t == 1)
    }

    /// Retour a la vue d'ensemble (clic a cote, Echap, « Maison » dans le fil, double-clic sur le fond) :
    /// la piece isolee est relachee, le zoom et le deplacement annules, par un vol de 1,3 s. « Reduire
    /// les animations » : tout de suite, ou par un fondu de 0,3 s (`enFondu`, le double-clic).
    func sortir(enFondu: Bool = false) {
        if focus != nil, sCible != 0 {
            sDepart = s
            sCible = 0
            sDebut = Self.maintenant()
            isolee = nil
            // Retour lance avant la premiere image de l'isolement : `s` est deja a 0, et l'horloge ne
            // finirait jamais ce retour.
            if s == 0 { finirRetour() }
        } else if !vueTouchee {
            return
        }
        vueTouchee = false
        voler(CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1), enFondu: enFondu)
    }

    /// Fin du retour d'un isolement : plus de piece isolee, ni de reperes « ailleurs ».
    private func finirRetour() {
        focus = nil
        if let e = entree { textes = Self.textes(e, focus: nil) }
        construireEtiquettes()
    }

    /// Double-clic sur le fond (precision 17 du plan 4b) : retour a la vue d'ensemble d'un geste. Le
    /// premier clic a deja ferme la fiche et relache la piece isolee (clic a cote) ; le second annule le
    /// zoom et le deplacement.
    func doubleCliquer() {
        sortir(enFondu: true)
    }

    private func voler(_ v: Vol, enFondu: Bool = false) {
        zoomEnAttente = 0
        rotationEnAttente = .zero
        if reduire && enFondu {
            fondu = Fondu(debut: Self.maintenant(), arrivee: t, orbite: v.orbite(1, depuis: orbite))
            vol = nil
        } else if reduire {
            orbite = v.orbite(1, depuis: orbite)
            vol = nil
        } else {
            vol = v
            debutVol = Self.maintenant()
        }
        reveiller()
    }

    func basculerRotation() {
        rotation.toggle()
        reveiller()
    }

    // MARK: Image

    /// Une image du `Canvas` : avance l'etat, projette la scene, place les noms, dessine.
    func image(_ ctx: inout GraphicsContext, taille nouvelle: CGSize, echelle: Double, palette: Palette) {
        // Taille ou marges changees : la vue d'ensemble se recadre, sauf si Djoko a zoome ou isole une piece.
        taille = nouvelle
        let now = Self.maintenant()
        let m = margesDuCadre(now)
        let voulu = CGRect(x: 0, y: m.haut, width: nouvelle.width, height: max(1, nouvelle.height - m.haut - m.bas))
        if voulu != cadre {
            cadre = voulu
            if pret && !enMouvement && !vueTouchee && focus == nil && !fige { recadrer() }
        }
        if !fige { avancer(now) }
        guard pret, let scene else { return }
        let etat = EtatAnime(t: t, s: s, fk: fk, focus: focus, survol: survol, selection: selection)
        let p = SceneProjetee(scene: scene, cartes: cartes, positions: positions, geometrie: geometrie, etat: etat,
                              orbite: orbite, cadre: cadre)
        PlacementNoms.regler(&etiquettes, scene: scene, niveau: p.niveau, survol: survol, selection: selection, focus: focus,
                             isolee: estIsolee, fk: fk, s: s, t: t)
        let ancres: [CGRect?] = etiquettes.map { l in
            switch l.genre {
            case .noeud(let id): p.ancresNoeuds[id]
            case .piece(let i): p.ancresPieces[i]
            case .etage(let i): p.ancresEtages[i]
            case .maison: p.ancreMaison
            case .ailleurs(let id): p.ancresAilleurs[id]
            }
        }
        var obstacles = p.disques.filter { $0.opacite > 0.5 }.map { d in
            CGRect(x: Double(d.centre.x) - d.rayon, y: Double(d.centre.y) - d.rayon, width: 2 * d.rayon, height: 2 * d.rayon)
        }
        obstacles += cadresInterface.values.map { $0.insetBy(dx: -4, dy: -4) }
        traits = PlacementNoms.placer(&etiquettes, ancres: ancres, obstacles: obstacles, cadre: taille, dt: dt)
        projetee = p
        var g = ctx
        g.opacity = opaciteFondu * opaciteMarges
        RenduCanvas.dessiner(&g, ImagePieces(projetee: p, etiquettes: etiquettes, traits: traits, textes: textes,
                                             apparences: entree?.apparences ?? [:], routeurs: routeurs,
                                             teintesPieces: teintes, selection: selection, echelle: echelle),
                             palette: palette, cache: cache)
        let nouvelle = ligne(p.niveau, ancres: ancres)
        if nouvelle != ligneNiveau {
            // Hors du rendu, sauf pour une capture (rendue d'un trait).
            if fige {
                ligneNiveau = nouvelle
            } else {
                Task { @MainActor [weak self] in self?.ligneNiveau = nouvelle }
            }
        }
        if !fige && !doitContinuer(now) { endormir() }
    }

    /// Marges du cadre a l'instant `now` : les marges visees, ou en route vers elles quand elles changent, pendant
    /// 0,3 s, ou 0,45 s quand la legende s'ouvre ou se replie (`legendeBasculee`) ; avec « Reduire les animations »,
    /// par un fondu de cette duree (la scene s'efface, les marges sautent a mi-chemin, la scene revient :
    /// `opaciteMarges`) ; tout de suite avant la premiere disposition et pour une capture.
    func margesDuCadre(_ now: Double) -> (haut: CGFloat, bas: CGFloat) {
        let actuelles = margesCadre ?? marges
        let visees = glissement?.arrivee ?? actuelles
        if marges.haut != visees.haut || marges.bas != visees.bas {
            if pret, !fige, margesCadre != nil {
                glissement = GlissementMarges(depart: actuelles, arrivee: marges, debut: now,
                                              duree: dureeAnnoncee ?? Apparition.duree, fondu: reduire)
                // Le glissement demande des images : l'horloge repart, hors du rendu.
                if !anime { Task { @MainActor [weak self] in self?.reveiller() } }
            } else {
                glissement = nil
            }
            dureeAnnoncee = nil
        }
        guard let g = glissement else {
            margesCadre = marges
            opaciteMarges = 1
            return marges
        }
        let q = min(1, max(0, (now - g.debut) / g.duree))
        let m: (haut: CGFloat, bas: CGFloat)
        if g.fondu {
            m = q < 0.5 ? g.depart : g.arrivee
            opaciteMarges = abs(1 - 2 * q)
        } else {
            let e = CGFloat(Apparition.courbe(q))
            m = (haut: g.depart.haut + (g.arrivee.haut - g.depart.haut) * e,
                 bas: g.depart.bas + (g.arrivee.bas - g.depart.bas) * e)
        }
        if q >= 1 {
            glissement = nil
            opaciteMarges = 1
        }
        margesCadre = m
        return m
    }

    /// Les marges du cadre sont en route.
    var margesEnRoute: Bool { glissement != nil }

    /// Les marges du cadre sont en route par un fondu (« Reduire les animations »).
    var margesEnFondu: Bool { glissement?.fondu == true }

    /// La legende s'ouvre ou se replie, d'un clic : le recadrage qui l'accompagne (le prochain changement des
    /// marges) prend sa duree, 0,45 s (`Apparition.dureeLegende`), au lieu des 0,3 s de la fiche et des bandeaux.
    func legendeBasculee() {
        dureeAnnoncee = Apparition.dureeLegende
    }

    private func ligne(_ niveau: NiveauZoom, ancres: [CGRect?]) -> LigneNiveau {
        if estIsolee, let nom = isolee { return .isolee(nom) }
        switch niveau {
        case .pieces: return .pieces
        case .routeurs: return .routeurs
        case .tous:
            let n = PlacementNoms.masques(etiquettes, ancres: ancres, cadre: taille)
            return n > 0 ? .masques(n) : .lisibles
        }
    }

    private func avancer(_ now: Double) {
        dt = instant.map { min(0.1, max(0, now - $0)) } ?? 0
        instant = now
        if let e = envol {
            let q = min(1, max(0, (now - debutEnvol) / CameraScene.dureeEnvol))
            (t, orbite) = e.pose(q, geometrie: geometrie, aspect: aspect)
            if q >= 1 {
                envol = nil
                t = e.arrivee
            }
        }
        if let f = fondu {
            let q = min(1, max(0, (now - f.debut) / CameraScene.dureeFondu))
            if q >= 0.5 && !f.saute {
                t = f.arrivee
                orbite = f.orbite ?? CameraScene.canonique(geometrie, aspect: aspect, u: t)
                fondu?.saute = true
            }
            opaciteFondu = abs(1 - 2 * q)
            if q >= 1 {
                fondu = nil
                opaciteFondu = 1
            }
        }
        if s != sCible {
            let r = min(1, max(0, (now - sDebut) / CameraScene.dureeVol))
            s = sDepart + (sCible - sDepart) * r
            if r >= 1 {
                s = sCible
                if s == 0 { finirRetour() }
            }
        }
        for i in fk.indices {
            let c: Double = focus == i && sCible == 1 ? 1 : 0
            fk[i] += (c - fk[i]) * min(1, dt * 3.5)
            if abs(c - fk[i]) < 1e-3 { fk[i] = c }
        }
        if let v = vol {
            let q = min(1, max(0, (now - debutVol) / CameraScene.dureeVol))
            orbite = v.orbite(q, depuis: orbite)
            if q >= 1 { vol = nil }
        } else if envol == nil && fondu == nil {
            controles()
        }
        if !occupe, let e = attente { appliquer(e) }
    }

    /// Rotation lente, rotation amortie, zoom amorti.
    private func controles() {
        if troisD && t == 1 && rotation && !reduire && focus == nil && geste == nil {
            orbite.azimut -= 2 * .pi / CameraScene.dureeTour * dt
        }
        if rotationEnAttente != .zero {
            let pas = rotationEnAttente * (1 - pow(0.95, 60 * dt))
            orbite.azimut += pas.x
            orbite.inclinaison = min(1.45, max(0.15, orbite.inclinaison + pas.y))
            rotationEnAttente -= pas
            if simd_length(rotationEnAttente) < 1e-5 { rotationEnAttente = .zero }
        }
        if zoomEnAttente != 0 {
            var pas = zoomEnAttente * (1 - exp(-dt * 16))
            if abs(zoomEnAttente) < 0.002 { pas = zoomEnAttente }
            let bornes = CameraScene.bornes(geometrie, aspect: aspect, troisD: t == 1, champ: orbite.champ)
            orbite = CameraScene.zoomer(orbite, facteur: pas, ancre: ancreZoom, bornes: bornes)
            zoomEnAttente -= pas
            if orbite.distance <= bornes.lowerBound || orbite.distance >= bornes.upperBound { zoomEnAttente = 0 }
        }
    }

    // MARK: Horloge

    func doitContinuer(_ now: Double) -> Bool {
        // Une scene qui attend la fin d'un glisser s'applique au relachement : pas d'image pour elle.
        if enMouvement || s != sCible || margesEnRoute || (attente != nil && geste == nil) { return true }
        if fk.contains(where: { $0 != 0 && $0 != 1 }) { return true }
        if troisD && t == 1 && rotation && !reduire && focus == nil { return true }
        if zoomEnAttente != 0 || rotationEnAttente != .zero || (geste != nil && bouge) { return true }
        if now - derniereActivite < 0.6 { return true }
        return etiquettes.contains { $0.envie > 0 }
    }

    /// Arrete l'horloge apres l'image (pas pendant le rendu).
    private func endormir() {
        guard anime else { return }
        Task { @MainActor [weak self] in
            guard let self, !self.doitContinuer(Self.maintenant()) else { return }
            self.anime = false
        }
    }

    func reveiller() {
        derniereActivite = Self.maintenant()
        if !anime {
            // Pas de temps nul a la premiere image : sinon le zoom amorti ferait un bond.
            instant = nil
            anime = true
        }
    }

    // MARK: Souris et clavier

    /// Noeud sous un point : sa pastille, a 8 points pres, sinon son nom.
    func noeudSous(_ p: CGPoint) -> String? {
        if let n = projetee?.noeud(sous: p, marge: 8) { return n }
        for l in etiquettes where l.vu && l.rect.contains(p) {
            if case .noeud(let id) = l.genre { return id }
        }
        return nil
    }

    func survoler(_ p: CGPoint?) {
        curseur = p
        let n = p.flatMap(noeudSous)
        if n != survol {
            survol = n
            reveiller()
        }
        let cible = p.map(cible(en:)) ?? .aucune
        if cible != cibleMenu { cibleMenu = cible }
    }

    /// Piece sous un point : son nom (le nom et le compte de ses appareils), sinon sa boite, la plus proche
    /// (verification du 02/10 : en 3D, les boites sont petites, et l'on clique volontiers sur le nom). Le nom,
    /// dessine par-dessus les boites, l'emporte sur celle d'une autre piece qu'il recouvre.
    func pieceSous(_ p: CGPoint) -> Int? {
        for l in etiquettes where l.vu && l.rect.contains(p) {
            if case .piece(let i) = l.genre { return i }
        }
        return projetee?.piece(sous: p)
    }

    /// Clic droit : un nom d'etage, ou le fond (ni piece, ni son nom, ni noeud).
    func cible(en p: CGPoint) -> CibleMenu {
        for l in etiquettes where l.vu && l.rect.insetBy(dx: -2, dy: -2).contains(p) {
            if case .etage(let i) = l.genre { return .etage(i) }
        }
        if noeudSous(p) == nil && pieceSous(p) == nil { return .fond }
        return .aucune
    }

    func glisser(_ p: CGPoint, depart d: CGPoint) {
        // Un geste reste d'un glisser annule (sans relachement), et celui-ci part d'ailleurs : il est clos.
        if geste != nil, d != departGeste { terminerGeste() }
        if geste == nil {
            bouge = false
            abandonApresGlisser = false
            precedent = d
            departGeste = d
            if !estIsolee, !enMouvement, let scene, let i = projetee?.piece(sous: d), i < scene.pieces.count,
               let c = centrePiece(i) {
                geste = .piece(scene.pieces[i].id, hauteur: c.y)
            } else {
                geste = .fond
            }
        }
        if !bouge && hypot(p.x - d.x, p.y - d.y) < 5 { return }
        bouge = true
        defer { precedent = p }
        guard !enMouvement, let geste else { return }
        let proj = ProjectionScene(orbite, cadre: cadre)
        switch geste {
        case .piece(let id, let h):
            guard let scene, let i = scene.pieces.firstIndex(where: { $0.id == id }), i < positions.count,
                  i < cartes.count, scene.pieces[i].etage < geometrie.rayons.count,
                  let a = proj.sol(precedent, hauteur: h), let b = proj.sol(p, hauteur: h) else { return }
            var pos = positions[i] + SIMD2(b.x - a.x, b.z - a.z)
            let r = max(0, geometrie.rayons[scene.pieces[i].etage] - 0.5 * hypot(cartes[i].largeur, cartes[i].profondeur))
            if simd_length(pos) > r { pos = simd_length(pos) > 0 ? simd_normalize(pos) * r : .zero }
            positions[i] = pos
        case .fond:
            if t == 0 {
                if let a = proj.sol(precedent, hauteur: orbite.cible.y), let b = proj.sol(p, hauteur: orbite.cible.y) {
                    orbite.cible += a - b
                    vueTouchee = true
                }
            } else {
                let h = max(1, Double(taille.height))
                rotationEnAttente.x -= 2 * .pi * Double(p.x - precedent.x) / h
                rotationEnAttente.y -= 2 * .pi * Double(p.y - precedent.y) / h
            }
        }
        reveiller()
    }

    /// Fin d'un glisser, ou clic. Deux clics sur le fond, a moins de l'intervalle du double-clic de
    /// macOS et de 5 points : le second est un double-clic ; le premier a agi comme un clic simple. Une
    /// scene recue pendant le geste s'applique ensuite, avec la place gardee de la piece glissee.
    func relacher(_ p: CGPoint, a instant: Double = MoteurPieces.maintenant()) {
        let g = geste
        let clic = !bouge && !(g == nil && abandonApresGlisser)
        geste = nil
        bouge = false
        abandonApresGlisser = false
        if case .piece(let id, _)? = g, !clic {
            garder(id)
        } else if clic {
            let fond = noeudSous(p) == nil && pieceSous(p) == nil
            if fond, let c = clicFond, instant - c.instant <= NSEvent.doubleClickInterval,
               hypot(p.x - c.point.x, p.y - c.point.y) <= 5 {
                clicFond = nil
                if envol == nil, fondu == nil { doubleCliquer() }
            } else {
                clicFond = fond ? (instant, p) : nil
                cliquer(p)
            }
        }
        if !occupe, let e = attente { appliquer(e) }
        reveiller()
    }

    /// Geste annule : SwiftUI remet l'etat du geste a zero sans appeler `onEnded` (la vue quitte la
    /// fenetre pendant le geste, ou le geste est interrompu). Il est clos sans clic, la piece glissee
    /// garde sa place, et la scene en attente s'applique. Apres un relachement, plus de geste : rien.
    func abandonnerGeste() {
        guard geste != nil else { return }
        abandonApresGlisser = bouge
        terminerGeste()
        if !occupe, let e = attente { appliquer(e) }
        reveiller()
    }

    /// Clot un geste reste ouvert (glisser annule, sans relachement) : la piece glissee garde sa place,
    /// sans clic. Depuis `glisser`, la scene en attente s'applique a la fin du geste suivant (sinon les
    /// indices de la projection, qui a servi a le commencer, periment) ; depuis `abandonnerGeste`, elle
    /// s'applique tout de suite apres, sauf pendant un mouvement.
    private func terminerGeste() {
        if case .piece(let id, _)? = geste, bouge { garder(id) }
        geste = nil
        bouge = false
    }

    /// Clic sans glisser : un appareil ou son nom ouvre sa fiche ; une piece ou son nom l'isole (en piece isolee,
    /// une autre piece y mene, meme pendant le vol) ; a cote des pieces, la fiche se ferme et la vue revient a la
    /// maison. Rien pendant l'envol.
    func cliquer(_ p: CGPoint) {
        guard envol == nil, fondu == nil else { return }
        if let n = noeudSous(p) {
            selection = n
            return
        }
        let i = pieceSous(p)
        if focus != nil {
            if let i {
                if i != focus || sCible == 0 { isoler(i) }
            } else {
                selection = nil
                sortir()
            }
        } else if let i {
            isoler(i)
        } else {
            selection = nil
        }
    }

    func molette(_ dy: Double, precis: Bool) {
        guard !enMouvement else { return }
        zoomer(precis ? -dy * 0.004 : -dy * 0.08, en: curseur)
    }

    func pincer(_ m: Double, en p: CGPoint) {
        guard !enMouvement else { return }
        let l = -log(max(0.05, m) / max(0.05, dernierPincement))
        dernierPincement = m
        zoomer(l, en: p)
    }

    func finPincement() { dernierPincement = 1 }

    /// Zoom amorti ; en 2D, vers le point sous le curseur.
    private func zoomer(_ l: Double, en p: CGPoint?) {
        ancreZoom = nil
        if t == 0, let p { ancreZoom = ProjectionScene(orbite, cadre: cadre).sol(p, hauteur: orbite.cible.y) }
        zoomEnAttente += l
        vueTouchee = true
        reveiller()
    }

    /// Molette et Echap, dans la fenetre de la vue seulement : un moniteur local (SwiftUI n'a pas
    /// d'evenement de molette brut).
    func ecouter() {
        guard moniteur == nil else { return }
        moniteur = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak self] e in
            guard let self else { return e }
            let pourMoi = MainActor.assumeIsolated { e.window != nil && e.window === self.fenetre }
            guard pourMoi else { return e }
            switch e.type {
            case .scrollWheel:
                let dy = Double(e.scrollingDeltaY), precis = e.hasPreciseScrollingDeltas
                MainActor.assumeIsolated { self.molette(dy, precis: precis) }
                return nil
            case .keyDown where e.keyCode == 53:
                MainActor.assumeIsolated { self.sortir() }
                return nil
            default:
                return e
            }
        }
    }

    func arreterEcoute() {
        if let m = moniteur { NSEvent.removeMonitor(m) }
        moniteur = nil
    }

    // MARK: Etats poses a la main (captures, tests)

    func poserBascule(_ q: Double) {
        t = CameraScene.rampe(q)
        troisD = q > 0
        orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
    }

    func poserIsolement(_ i: Int) {
        guard let scene, i < scene.pieces.count else { return }
        focus = i
        isolee = textes.pieces[i]?.nom
        s = 1
        sCible = 1
        fk[i] = 1
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        if let v = volVersPiece(i) { orbite = v.orbite(1, depuis: orbite) }
    }

    func poserSurvol(_ id: String?) { survol = id }

    func poserAzimut(_ decalage: Double) { orbite.azimut += decalage }

    /// Centre du bloc d'une piece, dans le monde.
    func centrePiece(_ i: Int) -> SIMD3<Double>? {
        guard let scene, i < scene.pieces.count, i < positions.count else { return nil }
        let c = geometrie.centrePlateau(scene.pieces[i].etage, t)
        return SIMD3(c.x + positions[i].x, c.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, c.z + positions[i].y)
    }

    /// Zoom a l'echelle `k` (points par unite a la cible, divises par 24), vers le point `vers`.
    func poserZoom(echelle k: Double, vers a: SIMD3<Double>?) {
        let k0 = ProjectionScene(orbite, cadre: cadre).pxParUnite(orbite.cible) / CartesPieces.px
        let f = k0 / k
        if let a { orbite.cible = a + (orbite.cible - a) * f }
        orbite.distance *= f
        vueTouchee = true
    }

    /// Pose le cadre sans image (captures, tests).
    func poserTaille(_ nouvelle: CGSize) {
        taille = nouvelle
        margesCadre = marges
        glissement = nil
        cadre = CGRect(x: 0, y: marges.haut, width: nouvelle.width,
                       height: max(1, nouvelle.height - marges.haut - marges.bas))
        if pret { recadrer() }
    }
}
