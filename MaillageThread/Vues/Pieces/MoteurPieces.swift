import AppKit
import MaillageCoeur
import os
import QuartzCore
import SwiftUI
import simd

/// Ligne de niveau, en haut a gauche de la vue, sous le fil (spec de la vue par pieces, section 6 ; polissage C,
/// section 5.1).
enum LigneNiveau: Equatable {
    case isolee(String)
    case etageIsole(String)
    case pieces
    case routeurs
    case masques(Int)
    case lisibles
}

/// Cible d'un clic droit : le nom ou le disque d'un plateau, par sa cle, ou le fond (spec, section 7 ; polissage C,
/// section 1.3). Jamais un indice : une scene qui s'installe pendant que le menu est ouvert peut ranger autrement ses
/// plateaux.
enum CibleMenu: Equatable {
    case aucune
    case etage(String)
    case fond
}

/// Ce que vise un clic, du plus fort au plus faible (polissage C, section 5.1) : un appareil, une piece (son bloc ou
/// son nom), le nom d'un etage, son disque (en 3D, le plus proche sur le rayon), le fond.
enum CibleClic: Equatable {
    case appareil(String)
    case piece(Int)
    case nomEtage(Int)
    case disque(Int)
    case fond
}

/// Le fil (polissage C, section 5.3) : « Maison », puis l'etage isole, ou l'etage et la piece isolee ; chaque cran
/// au-dessus du dernier mene a son niveau. Une maison d'un seul plateau n'a pas de cran « etage ».
struct Fil: Equatable {
    struct Cran: Equatable {
        var nom: String
        var etage: Int
    }

    var etage: Cran?
    var piece: String?
}

/// Le menu du clic droit sur le nom ou le disque d'un plateau (polissage C, section 1.3) : son nom, en tete ; « Monter
/// d'un etage » et « Descendre d'un etage », actifs pour un etage hors du haut et du bas de la pile ; « Au meme niveau
/// que », les autres niveaux, chacun nomme par son etage principal, celui de la zone coche ; « Hors de la maison » et
/// « Sur son propre niveau », pour une zone a cote.
struct MenuEtage: Equatable {
    /// Un niveau, designe par la cle de son etage principal (`principal`), jamais par son rang, qui perimerait.
    struct Niveau: Equatable {
        var principal: String
        var nom: String
        var coche: Bool
    }

    var nom: String
    var monter: Bool
    var descendre: Bool
    var niveaux: [Niveau]
    var aCote: Bool
    var dehors: Bool
}

/// Le curseur au-dessus de la vue : une main sur ce qui se clique (polissage C, maquette) ; en 3D, une main ouverte tant
/// que ⌥ est tenue, une main fermee pendant ⌥ + glisser (section 6).
enum Curseur: Equatable {
    case fleche
    case main
    case mainOuverte
    case mainFermee
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
    /// Nom de la piece isolee ; nil sinon.
    private(set) var isolee: String?
    /// Ce que montre la vue, et sa provenance (polissage C, section 5) ; le fil qui le dit.
    private(set) var isolement = Isolement.maison
    private(set) var fil = Fil()
    private(set) var curseurForme = Curseur.fleche
    var selection: String?
    private(set) var ligneNiveau = LigneNiveau.lisibles
    private(set) var cibleMenu = CibleMenu.aucune
    /// Version de la scene la plus recente (`sceneRecente`), observee : elle change avec elle, a chaque scene
    /// recue, en calcul ou posee. Le menu du clic droit la lit (`menuEtage`) : rouvert sur la meme cible apres un
    /// choix, il suit la scene de ce choix, que SwiftUI ne voit pas (relecture finale, Important 1).
    private(set) var versionScene = 0
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
    @ObservationIgnored private(set) var entree: EntreeScene? {
        didSet { versionScene &+= 1 }
    }
    /// Scene recue pendant un mouvement ou un glisser : appliquee a sa fin.
    @ObservationIgnored private var attente: EntreeScene? {
        didSet { versionScene &+= 1 }
    }
    /// Scene dont la disposition se calcule : `entree` reste affichee jusqu'a la fin du calcul.
    @ObservationIgnored private var enCalcul: EntreeScene? {
        didSet { versionScene &+= 1 }
    }
    @ObservationIgnored private var calcul: Task<Void, Never>?
    @ObservationIgnored private var cleCalculee: EntreeScene.CleDisposition?
    @ObservationIgnored private var placesCalculees: [String: SIMD2<Double>] = [:]
    @ObservationIgnored private var rayonsCalcules: [String: Double] = [:]
    @ObservationIgnored private var cartesCalculees: [String: CartesPieces.Carte] = [:]
    @ObservationIgnored private(set) var cartes: [CartesPieces.Carte] = []
    @ObservationIgnored private(set) var positions: [SIMD2<Double>] = []
    /// La geometrie de l'image ; elle rejoint la geometrie visee (`geometrieVisee`) quand les plateaux glissent.
    @ObservationIgnored private(set) var geometrie = GeometrieMaison(rayons: [])
    /// La geometrie de la scene, avec les rayons de sa disposition et la grille du reglage.
    @ObservationIgnored private(set) var geometrieVisee = GeometrieMaison(rayons: [])
    @ObservationIgnored private(set) var glissementPlateaux: GlissementPlateaux?
    /// Le glissement d'une disposition a l'autre (polissage D, section 1) : les pieces, les noeuds et les liens qui
    /// changent, de leur pose affichee a leur nouvelle pose ; nil au repos.
    @ObservationIgnored private(set) var transition: TransitionScene?
    /// Les poses de l'image, de ce qui est en transition : la scene projetee les prend, la camera les suit.
    @ObservationIgnored private(set) var posesAffichees = PosesScene()
    /// Le dessin des pastilles qui s'effacent, absentes de la scene : celui de la scene d'avant.
    @ObservationIgnored private var apparencesParties: [String: DessinNoeud.Apparence] = [:]
    /// La politique de la grille 2D (polissage C, section 3 ; dans le coeur depuis le polissage D, section 5) : le
    /// reglage « Etages en 2D », pose par la fenetre, les colonnes choisies, une demande qui attend la vue d'ensemble 2D.
    @ObservationIgnored private(set) var politique = PolitiqueGrille()
    var grille: Bool { politique.grille }
    var colonnes: Int? { politique.colonnes }
    var grilleEnAttente: GrilleEnAttente? { politique.attente }
    /// Ce que vise le vol en cours : son arrivee suit les plateaux qui glissent.
    @ObservationIgnored private var viseeVol: Visee?
    @ObservationIgnored private(set) var orbite = Orbite(cible: .zero, distance: 1000, azimut: 0, inclinaison: 0.0001, champ: 2)
    @ObservationIgnored private var taille = CGSize.zero
    /// Marges du haut (le haut de la fenetre, mesure) et du bas (la pile du bas, mesuree : la legende et la ligne
    /// de niveau, puis la fiche), posees par la vue : la place utile de la vue d'ensemble. Le cadre les rejoint en
    /// 0,3 s, sur la courbe de la fiche qui glisse (`Apparition`) : la vue se releve avec elle, au-dessus de la pile,
    /// ou descend sous un bandeau ; en 0,45 s quand la legende s'ouvre ou se replie (`legendeBasculee`) ; avec
    /// « Reduire les animations », par un fondu.
    @ObservationIgnored var marges: (haut: CGFloat, bas: CGFloat) = (0, 0)
    /// Marge du bas de la zone visible ou se choisit la grille (polissage C, section 3.3) : celle de la legende, ouverte
    /// ou repliee, sans la fiche, qui va et vient (`FenetrePieces.margeBasGrille`) ; nil : celle du cadre.
    @ObservationIgnored var basGrille: CGFloat?
    /// La zone visible de la derniere image : une autre recalcule la grille.
    @ObservationIgnored private var zoneGrille = CGSize.zero
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
    /// Part propre a chaque piece de l'isolement, gardee par cle (triage A, n° 9).
    @ObservationIgnored private(set) var fk: [String: Double] = [:]
    /// Isolement d'un etage (polissage C, section 5) : `se` general, `ek` propre a chaque plateau, par cle ; l'etage
    /// en vue (isole, celui de la piece isolee, ou qui l'etait, pendant le retour).
    @ObservationIgnored private(set) var se = 0.0
    @ObservationIgnored private var seCible = 0.0
    @ObservationIgnored private var seDepart = 0.0
    @ObservationIgnored private var seDebut = 0.0
    @ObservationIgnored private(set) var ek: [String: Double] = [:]
    @ObservationIgnored private(set) var etageEnVue: String?
    /// Disque cliquable et nom d'etage sous le pointeur.
    @ObservationIgnored private(set) var survolEtage: Int?
    @ObservationIgnored private(set) var survolNomEtage: Int?
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
        /// ⌥ + glisser en 3D : la vue glisse dans le plan de l'ecran, depuis l'orbite de l'appui.
        case ecran(Orbite)
    }

    /// ⌥ est tenue (le survol et le moniteur des touches la suivent) ; ce que le pointeur vise est cliquable.
    @ObservationIgnored private var optionTenue = false
    @ObservationIgnored private var surCliquable = false

    /// ⌥ + glisser en cours : la camera n'obeit qu'au pointeur. La maquette coupe alors ses controles : l'inertie de
    /// rotation et le zoom amorti attendent, la molette et le pincement sont ignores ; au relachement, tout reprend.
    private var deplaceDansLEcran: Bool {
        if case .ecran? = geste { true } else { false }
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

    /// Glissement des plateaux (polissage C, sections 1.3 et 3.5) : de `depart`, la geometrie de l'image a son debut,
    /// remise dans l'ordre des plateaux de la scene, vers la geometrie visee ; en 2D en `duree2D`, en 3D en
    /// `duree3D` (0 : sans glissement), en cubique entree-sortie.
    struct GlissementPlateaux {
        var depart: GeometrieMaison
        var debut: Double
        var duree2D: Double
        var duree3D: Double
    }

    /// Une grille voulue qui attend la vue d'ensemble 2D : la duree du glissement de ses plateaux, et si elle garde
    /// la grille en place tant qu'elle est a moins de 5 % du choix (un redimensionnement).
    typealias GrilleEnAttente = PolitiqueGrille.Demande

    /// Ce que vise un vol : la vue d'ensemble, une piece ou un etage (sa cle).
    private enum Visee {
        case ensemble
        case piece(String)
        case etage(String)
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

    /// `troisD` : le mode garde ; `fichierPlaces` : `positions-pieces.json` (nil : ni lu ni ecrit) ; `places` : sans
    /// fichier, les places de depart, en memoire (la demo et son choix de niveau).
    init(troisD: Bool = false, fichierPlaces: URL? = nil, selection: String? = nil, places depart: PlacesGardees? = nil) {
        self.troisD = troisD
        t = troisD ? 1 : 0
        self.fichierPlaces = fichierPlaces
        places = fichierPlaces.map(PlacesGardees.lire) ?? depart ?? PlacesGardees()
        self.selection = selection
    }

    static func maintenant() -> Double { CACurrentMediaTime() }

    var scene: ScenePieces? { entree?.scene }
    var aspect: Double { cadre.height > 0 ? Double(cadre.width / cadre.height) : 1.6 }
    /// Une piece est isolee (et non en train d'etre quittee).
    var estIsolee: Bool { focus != nil && sCible == 1 }
    var enMouvement: Bool { envol != nil || fondu != nil || vol != nil }
    /// La vue est a la vue d'ensemble : ni zoomee, ni deplacee, ni isolee, ni en mouvement.
    var aLaVueDEnsemble: Bool { pret && !vueTouchee && sansIsolement && !enMouvement }
    /// Ni piece ni etage isoles, ni en train d'etre quittes.
    var sansIsolement: Bool { isolement == .maison && focus == nil && etageEnVue == nil }
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
                         cle: EntreeScene.CleDisposition) {
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
        // Des niveaux changes (le menu du clic droit) : les plateaux glissent vers leur nouvelle place (polissage C,
        // section 1.3) ; a la vue d'ensemble 2D, la grille se recalcule, sinon elle l'attend.
        let anciens = entree?.scene.etages.map(\.id) ?? []
        let niveauxChanges = pret && entree?.scene.niveaux != scene.niveaux
        let ensemble = aLaVueDEnsemble && t == 0
        let image = geometrie
        // La pose affichee de la scene d'avant, et sa pose d'arrivee (polissage D, section 1).
        let avant = entree.map { PosesScene(scene: $0.scene, cartes: cartes, positions: positions) }
        let affichee = avant?.recouvertes(par: posesAffichees)
        let rayonsAvant = entree.map { Dictionary(zip($0.scene.etages.map(\.id), geometrieVisee.rayons).map { ($0, $1) },
                                                  uniquingKeysWith: { a, _ in a }) }
        let ancienne = entree
        entree = e
        // Un autre ordre des plateaux : le disque et le nom d'etage survoles, des indices, en designeraient
        // d'autres ; le prochain mouvement du pointeur les reprend.
        if scene.etages.map(\.id) != anciens {
            survolEtage = nil
            survolNomEtage = nil
        }
        cartes = scene.pieces.map { cartesCalculees[$0.id] ?? CartesPieces.carte([]) }
        positions = scene.pieces.map { placesCalculees[$0.id] ?? .zero }
        // Une nouvelle disposition glisse (polissage D, section 1) : de la pose affichee a la nouvelle, en 0,9 s ; une
        // disposition qui ne change rien laisse le glissement en cours. Avec « Reduire les animations », tout de suite.
        let arrivee = PosesScene(scene: scene, cartes: cartes, positions: positions)
        if pret, let affichee, let avant, arrivee != avant || transition == nil {
            transition = TransitionScene(de: affichee, vers: arrivee, a: Self.maintenant(), reduire: reduire)
            if let tr = transition {
                posesAffichees = tr.poses(a: tr.debut)
                apparencesParties = (ancienne?.apparences ?? [:]).merging(apparencesParties) { a, _ in a }
            } else {
                posesAffichees = PosesScene()
                apparencesParties = [:]
            }
        }
        // Les rayons changent sans les niveaux : la grille se rechoisit, a la vue d'ensemble 2D, avec l'hysteresis ;
        // sinon elle attend (polissage D, section 4).
        let rayonsChanges = pret && !niveauxChanges
            && Dictionary(zip(scene.etages.map(\.id), rayons(scene)).map { ($0, $1) }, uniquingKeysWith: { a, _ in a }) != rayonsAvant
        if grille && (!pret || (niveauxChanges && ensemble)) {
            politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: false)
        } else if niveauxChanges {
            politique.attendre(PolitiqueGrille.niveaux)
        } else if rayonsChanges && grille {
            if ensemble {
                politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: true)
            } else {
                politique.attendre(PolitiqueGrille.redimensionnement)
            }
        }
        let glisse = pret ? TransitionScene.duree : 0
        viser(geometriePour(scene), depuis: anciens, duree2D: niveauxChanges ? CameraScene.dureeCases : glisse,
              duree3D: niveauxChanges ? CameraScene.dureeNiveaux : glisse)
        // Les parts de l'isolement sont gardees par cle (triage A, n° 9) : un releve recu pendant un fondu ne remet pas
        // la piece a pleine taille. L'etage en vue suit ce que vise la vue (polissage C, section 5) : celui de la piece
        // isolee, qui a pu changer de zone. Une piece isolee qui disparait rend la maison, comme avant les etages :
        // l'etage est relache, comme a la bascule, et la vue d'ensemble se recadre (plus bas). Un etage isole qui
        // disparait rend aussi la maison.
        let clesPieces = Set(scene.pieces.map(\.id)), clesEtages = Set(scene.etages.map(\.id))
        fk = fk.filter { clesPieces.contains($0.key) }
        ek = ek.filter { clesEtages.contains($0.key) }
        isolement = isolement.recaler(pieces: clesPieces, etages: clesEtages)
        if let cle = ancienFocus, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            focus = i
            if case .piece = isolement, scene.etages.count > 1 { viserEtage(scene.etages[scene.pieces[i].etage].id) }
        } else if focus != nil {
            focus = nil
            s = 0
            sCible = 0
            isolee = nil
            if isolement == .maison {
                etageEnVue = nil
                se = 0
                seCible = 0
                ek = [:]
            }
        }
        if let k = etageEnVue, !clesEtages.contains(k) {
            etageEnVue = nil
            se = 0
            seCible = 0
        }
        textes = Self.textes(e, focus: focus)
        routeurs = Set(scene.noeuds.filter { $0.rang <= 2 }.map(\.id))
        teintes = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { ($0, scene.pieces[$0].teinte) })
        construireEtiquettes()
        majFil()
        if !pret {
            pret = true
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        } else if !vueTouchee && sansIsolement {
            recadrer()
        } else if niveauxChanges && glissementPlateaux == nil {
            // Des niveaux changes, avec « Reduire les animations » : les plateaux sont poses tout de suite
            // (section 1.3). La vue isolee ou zoomee suit ce qu'elle regarde, d'un coup, depuis sa place au depart du
            // glissement qu'il n'y a pas : comme le glissement le lui fait suivre image apres image (`suivre`), sans
            // « Reduire ».
            suivre(depuis: ancreCamera(dans: depart(image, anciens: anciens, vers: geometrie)))
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

    // MARK: Menu du clic droit (polissage C, section 1.3)

    /// La scene la plus recente : celle qui attend la fin d'un mouvement ou d'un geste, sinon celle du calcul en cours,
    /// sinon celle affichee. Apres un choix du menu, elle le porte avant la scene affichee.
    private var sceneRecente: EntreeScene? { attente ?? enCalcul ?? entree }

    /// Le menu du nom ou du disque du plateau `cle`, sur la scene la plus recente : ses coches et ses grises suivent le
    /// dernier choix, meme quand la scene de ce choix attend encore. Il lit la version de cette scene, observee : une
    /// vue qui le montre se refait quand elle change, meme si la cible du clic droit, elle, ne change pas.
    func menuEtage(_ cle: String) -> MenuEtage? {
        _ = versionScene
        guard let scene = sceneRecente?.scene, let niveau = scene.niveaux.niveau(cle) else { return nil }
        let n = scene.niveaux, estPrincipal = n.estPrincipal(cle)
        func nom(_ c: String) -> String {
            scene.etages.firstIndex { $0.id == c }.map { LibellesNoeuds.nom(scene.etages[$0].nom) } ?? c
        }
        let niveaux = n.liste.indices.filter { !(estPrincipal && $0 == niveau) }.map { i in
            MenuEtage.Niveau(principal: n.liste[i][0], nom: nom(n.liste[i][0]), coche: !estPrincipal && i == niveau)
        }
        return MenuEtage(nom: nom(cle), monter: estPrincipal && niveau < n.liste.count - 1,
                         descendre: estPrincipal && niveau > 0, niveaux: niveaux, aCote: !estPrincipal,
                         dehors: n.dehors(cle))
    }

    /// Un choix du menu, calcule sur la scene la plus recente et sur les choix gardes : le nouvel ordre des plateaux et
    /// les nouveaux choix de niveau, gardes ; la scene suivante les prend (`EntreeScene`), et les plateaux glissent vers
    /// leur nouvelle place. Sur la scene affichee, un choix fait pendant que la scene du precedent attend (un vol, le
    /// calcul de sa disposition) defaisait le precedent.
    private func ranger(_ operation: (Niveaux, [String: PlacesGardees.ACote]) -> Rangement?) {
        guard let e = sceneRecente, let r = operation(e.scene.niveaux, places.maison(e.domicile).aCote) else { return }
        places.ranger(r, domicile: e.domicile)
        enregistrer()
    }

    /// La cle du plateau `e` de la scene affichee, celle des noms et de la projection.
    private func cleEtage(_ e: Int) -> String? {
        guard let scene, scene.etages.indices.contains(e) else { return nil }
        return scene.etages[e].id
    }

    /// « Monter d'un etage » (+1) ou « Descendre d'un etage » (-1) : le niveau entier de l'etage `cle`, zones a cote
    /// comprises, change de place avec son voisin.
    func deplacerEtage(_ cle: String, de pas: Int) {
        ranger { $0.deplacer(cle, de: pas, choix: $1) }
    }

    /// La meme chose pour le plateau `e` de la scene affichee.
    func deplacerEtage(_ e: Int, de pas: Int) {
        if let cle = cleEtage(e) { deplacerEtage(cle, de: pas) }
    }

    func peutDeplacerEtage(_ e: Int, de pas: Int) -> Bool {
        cleEtage(e).flatMap(menuEtage).map { pas > 0 ? $0.monter : $0.descendre } ?? false
    }

    /// « Au meme niveau que » le niveau de l'etage principal `principal` (sa cle), dans la maison.
    func mettreAuNiveau(_ cle: String, de principal: String) {
        ranger { n, choix in n.niveau(principal).flatMap { n.rejoindre(cle, niveau: $0, choix: choix) } }
    }

    /// « Hors de la maison », coche ou non.
    func basculerDehors(_ cle: String) {
        ranger { $0.basculerDehors(cle, choix: $1) }
    }

    /// « Sur son propre niveau ».
    func mettreSurSonNiveau(_ cle: String) {
        ranger { $0.propreNiveau(cle, choix: $1) }
    }

    /// « Replacer les pieces automatiquement » : oublie les places gardees de la maison (pas l'ordre
    /// des etages) et recalcule la disposition de la scene la plus recente (celle qui attend la fin d'un
    /// mouvement ou d'un geste, sinon celle du calcul en cours, sinon celle affichee) ; l'ancienne reste
    /// affichee pendant ce temps.
    func replacerPieces() {
        guard let e = sceneRecente else { return }
        places.replacer(domicile: e.domicile)
        enregistrer()
        cleCalculee = nil
        enCalcul = nil
        appliquer(e)
    }

    // MARK: Plateaux

    /// La geometrie d'une scene : les rayons de sa disposition, ses niveaux, et la grille du reglage (en grille, les
    /// colonnes choisies, la rangee en attendant une vraie taille).
    private func geometriePour(_ scene: ScenePieces) -> GeometrieMaison {
        GeometrieMaison(rayons: rayons(scene),
                        plateaux: scene.etages.map {
                            GeometrieMaison.Plateau(niveau: $0.niveau, principal: $0.principal, dehors: $0.dehors)
                        },
                        colonnes: politique.colonnesDeLaGeometrie)
    }

    /// Les rayons des plateaux d'une scene, ceux de sa disposition : la grille se choisit sur eux.
    private func rayons(_ scene: ScenePieces) -> [Double] {
        scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge }
    }

    /// La zone visible ou se choisit la grille (polissage C, section 3.3, decision de Djoko du 03/10) : la vue moins la
    /// marge du haut et celle du bas, la legende ouverte ou repliee, sans la fiche (`basGrille`). La vue d'ensemble y est
    /// toujours la plus grande possible.
    var zoneVisible: CGSize {
        CGSize(width: taille.width, height: taille.height - marges.haut - (basGrille ?? marges.bas))
    }

    /// Pose la geometrie visee : tout de suite, ou en glissant (« Reduire les animations » : tout de suite) depuis la
    /// geometrie de l'image, remise dans l'ordre des plateaux de la scene (`anciens` : celui de l'image). Un
    /// glissement en cours repart de l'image, avec le temps qui lui restait s'il est plus long.
    private func viser(_ g: GeometrieMaison, depuis anciens: [String], duree2D: Double, duree3D: Double) {
        let now = Self.maintenant()
        var d2 = reduire ? 0 : duree2D
        var d3 = reduire ? 0 : duree3D
        if let gl = glissementPlateaux, !reduire {
            d2 = max(d2, gl.duree2D - (now - gl.debut))
            d3 = max(d3, gl.duree3D - (now - gl.debut))
        }
        geometrieVisee = g
        let depart = self.depart(geometrie, anciens: anciens, vers: g)
        // Rien ne bouge : pas de glissement (une nouvelle disposition aux memes plateaux).
        guard pret, d2 > 0 || d3 > 0, scene != nil, depart != g || glissementPlateaux != nil else {
            geometrie = g
            glissementPlateaux = nil
            return
        }
        geometrie = depart
        glissementPlateaux = GlissementPlateaux(depart: depart, debut: now, duree2D: d2, duree3D: d3)
        reveiller()
    }

    /// Le depart d'un glissement vers `g`, la geometrie de la scene : la geometrie `image`, remise dans l'ordre des
    /// plateaux de la scene (`anciens` : celui de l'image), chaque plateau a sa place d'avant, retrouvee par sa cle ;
    /// la boite, le pas, la sphere et le cadrage de l'image. Un plateau nouveau part de sa place d'arrivee.
    private func depart(_ image: GeometrieMaison, anciens: [String], vers g: GeometrieMaison) -> GeometrieMaison {
        var depart = g
        for (i, c) in (scene?.etages.map(\.id) ?? []).enumerated() {
            guard let j = anciens.firstIndex(of: c), j < image.centres2D.count else { continue }
            depart.centres2D[i] = image.centres2D[j]
            depart.centres3D[i] = image.centres3D[j]
        }
        depart.boite = image.boite
        depart.pasEtage = image.pasEtage
        depart.centreSphere = image.centreSphere
        depart.rayonSphere = image.rayonSphere
        depart.rayonCadre = image.rayonCadre
        return depart
    }

    /// La geometrie de l'image a l'instant `now` : en route vers la geometrie visee, ou elle.
    func geometrie(a now: Double) -> GeometrieMaison {
        guard let gl = glissementPlateaux else { return geometrieVisee }
        let q2 = gl.duree2D > 0 ? min(1, max(0, (now - gl.debut) / gl.duree2D)) : 1
        let q3 = gl.duree3D > 0 ? min(1, max(0, (now - gl.debut) / gl.duree3D)) : 1
        if q2 >= 1 && q3 >= 1 { return geometrieVisee }
        return gl.depart.vers(geometrieVisee, k2: CameraScene.rampe(q2), k3: CameraScene.rampe(q3))
    }

    /// Le reglage « Etages en 2D » (polissage C, section 3.1) : en grille ou en rangee. Il s'applique tout de suite a
    /// la vue ouverte, les plateaux glissant comme l'envol, en 2,6 s ; zoomee, isolee ou en 3D, au retour a la vue
    /// d'ensemble 2D.
    func reglerGrille(_ g: Bool) {
        guard politique.regler(g), pret else { return }
        demanderGrille(PolitiqueGrille.reglage)
    }

    /// La zone visible a change (polissage C, sections 3.3 et 3.5) : la taille de la vue, ou ses marges sans la fiche
    /// (la legende ouverte ou repliee, un bandeau). La premiere vraie zone pose la grille et cadre la vue d'ensemble,
    /// sans autre condition ; ensuite, la grille se recalcule a la vue d'ensemble 2D, avec l'hysteresis, et les plateaux
    /// glissent en 0,4 s ; zoomee, isolee ou en 3D, elle attend.
    private func zoneChangee() {
        guard pret, let scene else { return }
        if politique.sansVraieTaille {
            guard politique.premiereZone(rayons: rayons(scene), zone: zoneVisible) else { return }
            viser(geometriePour(scene), depuis: scene.etages.map(\.id), duree2D: 0, duree3D: 0)
            vueTouchee = false
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
            return
        }
        demanderGrille(PolitiqueGrille.redimensionnement)
    }

    /// Une grille voulue : posee a la vue d'ensemble 2D, ses plateaux glissant en `d.duree` ; sinon elle attend
    /// (`PolitiqueGrille`).
    private func demanderGrille(_ d: PolitiqueGrille.Demande) {
        guard let scene else { return }
        if politique.demander(d, ensemble2D: t == 0 && aLaVueDEnsemble, rayons: rayons(scene), zone: zoneVisible) {
            poserGeometrie(d.duree)
        }
    }

    /// Pose la grille d'une demande, puis sa geometrie.
    private func poserGrille(_ d: PolitiqueGrille.Demande) {
        guard let scene else { return }
        politique.poser(d, rayons: rayons(scene), zone: zoneVisible)
        poserGeometrie(d.duree)
    }

    /// La geometrie de la grille choisie : ses plateaux glissent en `duree`.
    private func poserGeometrie(_ duree: Double) {
        guard let scene else { return }
        let g = geometriePour(scene)
        guard g != geometrieVisee else { return }
        viser(g, depuis: scene.etages.map(\.id), duree2D: duree, duree3D: 0)
        if glissementPlateaux == nil && aLaVueDEnsemble { recadrer() }   // posee tout de suite : cadree tout de suite
    }

    /// Ce que la vue regarde : la piece isolee, l'etage isole, ou la cible de la vue d'ensemble ; dans la geometrie de
    /// l'image, ou dans `g`.
    private func ancreCamera(dans g: GeometrieMaison? = nil) -> SIMD3<Double> {
        let g = g ?? geometrie
        if let i = focus, let c = centrePiece(i, dans: g) { return c }
        if let k = etageEnVue, let e = scene?.etages.firstIndex(where: { $0.id == k }) { return g.centrePlateau(e, t) }
        return g.cible2D + (g.centreSphere - g.cible2D) * t
    }

    /// Les plateaux glissent : un vol rejoint l'arrivee de ce qu'il vise ; a la vue d'ensemble, elle se recadre ; sinon,
    /// la vue suit ce qu'elle regarde (`ancre0` : sa place a l'image d'avant).
    private func suivre(depuis ancre0: SIMD3<Double>) {
        if vol != nil {
            if let v = viseeVol, let fin = volVers(v) {
                vol?.oeil1 = fin.oeil1
                vol?.cible1 = fin.cible1
            }
        } else if envol == nil && fondu == nil {
            if aLaVueDEnsemble {
                recadrer()
            } else {
                orbite.cible += ancreCamera() - ancre0
            }
        }
    }

    /// Le vol vers ce que l'on vise, depuis la camera du moment.
    private func volVers(_ v: Visee) -> Vol? {
        switch v {
        case .ensemble: CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1)
        case .piece(let cle): scene?.pieces.firstIndex { $0.id == cle }.flatMap(volVersPiece)
        case .etage(let cle): scene?.etages.firstIndex { $0.id == cle }.map(volVersEtage)
        }
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
    /// les animations ») ; une piece isolee est relachee. Pas de menu du clic droit pendant l'envol, meme sous un
    /// pointeur immobile : sa cible tombe, et le survol ne la reprend qu'apres lui.
    func basculer(troisD v: Bool) {
        guard v != troisD else { return }
        troisD = v
        if cibleMenu != .aucune { cibleMenu = .aucune }
        focus = nil
        isolee = nil
        s = 0
        sCible = 0
        fk = [:]
        etageEnVue = nil
        se = 0
        seCible = 0
        ek = [:]
        isolement = .maison
        vol = nil
        zoomEnAttente = 0
        rotationEnAttente = .zero
        vueTouchee = false
        textes = entree.map { Self.textes($0, focus: nil) } ?? textes
        construireEtiquettes()
        majFil()
        // Vers la 2D, l'envol se pose sur la grille de la zone visible du moment (polissage C, section 3.5).
        if !v, let scene {
            politique.oublierAttente()
            politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: false)
            viser(geometriePour(scene), depuis: scene.etages.map(\.id), duree2D: 0, duree3D: 0)
        }
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
    /// autres s'estompent, ses reperes « ailleurs » apparaissent. Son etage est celui du fil : les disques des
    /// autres etages restent a 15 %, cliquables (polissage C, section 5.2). La provenance (section 5.4) : depuis la
    /// maison ou un etage isole, ce que l'on quitte ; d'une piece a une autre, elle reste, sauf vers une piece d'un
    /// autre etage : la maison.
    func isoler(_ i: Int) {
        guard let scene, i < scene.pieces.count, !(focus == i && sCible == 1) else { return }
        let piece = scene.pieces[i], etage = scene.etages[piece.etage].id
        isolement = isolement.isoler(piece: piece.id, etage: etage)
        focus = i
        isolee = textes.pieces[i]?.nom
        if sCible != 1 {
            sDepart = s
            sCible = 1
            sDebut = Self.maintenant()
        }
        if scene.etages.count > 1 { viserEtage(etage) }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        majFil()
        if let v = volVersPiece(i) { voler(v, visee: .piece(piece.id)) }
    }

    /// Isole un etage (polissage C, section 5.1) : un vol de 1,3 s cadre son plateau, bande de son nom comprise ; les
    /// autres plateaux s'estompent a 15 %, la sphere et « ⌂ Maison » s'effacent, la rotation lente s'arrete. Une
    /// piece isolee est relachee. Rien dans une maison d'un seul plateau, ni pendant l'envol.
    func allerEtage(_ e: Int) {
        guard let scene, scene.etages.count > 1, e < scene.etages.count, envol == nil, fondu == nil else { return }
        quitterPiece()
        let cle = scene.etages[e].id
        isolement = .etage(cle)
        viserEtage(cle)
        majFil()
        voler(volVersEtage(e), visee: .etage(cle))
    }

    /// Vol vers un etage isole.
    private func volVersEtage(_ e: Int) -> Vol {
        CameraScene.volVersEtage(orbite, geometrie, etage: e, aspect: aspect, u: t, troisD: t == 1)
    }

    /// L'isolement d'etage vise `cle` : son plateau reste net.
    private func viserEtage(_ cle: String) {
        etageEnVue = cle
        if seCible != 1 {
            seDepart = se
            seCible = 1
            seDebut = Self.maintenant()
        }
    }

    /// La piece isolee est relachee : son isolement redescend en 1,3 s.
    private func quitterPiece() {
        guard focus != nil, sCible != 0 else { return }
        sDepart = s
        sCible = 0
        sDebut = Self.maintenant()
        isolee = nil
        // Retour lance avant la premiere image de l'isolement : `s` est deja a 0, et l'horloge ne
        // finirait jamais ce retour.
        if s == 0 { finirRetour() }
    }

    /// L'etage isole est relache.
    private func quitterEtage() {
        guard seCible != 0 else { return }
        seDepart = se
        seCible = 0
        seDebut = Self.maintenant()
        if se == 0 { etageEnVue = nil }
    }

    /// Le fil de ce que montre la vue.
    private func majFil() {
        var f = Fil()
        if let scene {
            func cran(_ e: Int) -> Fil.Cran { Fil.Cran(nom: textes.etages[e] ?? "", etage: e) }
            switch isolement {
            case .maison:
                break
            case .etage(let cle):
                f.etage = scene.etages.firstIndex { $0.id == cle }.map(cran)
            case .piece(let cle, _):
                if let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
                    f.piece = textes.pieces[i]?.nom
                    if scene.etages.count > 1 { f.etage = cran(scene.pieces[i].etage) }
                }
            }
        }
        if f != fil { fil = f }
    }

    /// Vol vers une piece, a la hauteur de vue de la spec (section 7).
    private func volVersPiece(_ i: Int) -> Vol? {
        guard let c = centrePiece(i) else { return nil }
        return CameraScene.volVersPiece(orbite, centre: c, largeur: cartes[i].largeur, profondeur: cartes[i].profondeur,
                                        aspect: aspect, troisD: t == 1)
    }

    /// Retour a la maison (« Maison » dans le fil, double-clic, ou en remontant) : la piece et l'etage isoles sont
    /// relaches, le zoom et le deplacement annules, par un vol de 1,3 s qui part de la pose courante. « Reduire les
    /// animations » : tout de suite, ou par un fondu de 0,3 s (`enFondu`, le double-clic).
    func versMaison(enFondu: Bool = false) {
        guard isolement != .maison || focus != nil || etageEnVue != nil || vueTouchee else { return }
        quitterPiece()
        quitterEtage()
        isolement = .maison
        majFil()
        vueTouchee = false
        voler(CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1), visee: .ensemble,
              enFondu: enFondu)
    }

    /// Echap et le clic a cote remontent d'ou l'on vient (polissage C, section 5.4) : une piece ouverte depuis un etage
    /// isole, a l'etage de la piece ; une autre piece, ou un etage, a la maison. A la maison, Echap ramene une vue
    /// zoomee ou deplacee a la vue d'ensemble (`clavier`) ; le clic a cote ne fait rien. Rien pendant l'envol.
    func remonter(clavier: Bool = true) {
        guard envol == nil, fondu == nil else { return }
        var etageDeLaPiece: String?
        if case .piece(let cle, _) = isolement, let scene, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            etageDeLaPiece = scene.etages[scene.pieces[i].etage].id
        }
        switch isolement.remonter(etageDeLaPiece: etageDeLaPiece, plusieursPlateaux: (scene?.etages.count ?? 0) > 1,
                                  clavier: clavier) {
        case .etage(let cle):
            if let e = scene?.etages.firstIndex(where: { $0.id == cle }) { allerEtage(e) }
        case .maison:
            versMaison()
        case .rien:
            break
        }
    }

    /// Echap.
    func sortir() {
        remonter(clavier: true)
    }

    /// Fin du retour d'un isolement : plus de piece isolee, ni de reperes « ailleurs ».
    private func finirRetour() {
        focus = nil
        if let e = entree { textes = Self.textes(e, focus: nil) }
        construireEtiquettes()
    }

    /// Double-clic sur le fond ou sur un disque (precision 17 du plan 4b ; polissage C, section 5.4) : retour a la vue
    /// d'ensemble d'un geste, de partout. Le premier clic a deja agi seul ; le second relache ce qui reste isole et
    /// annule le zoom et le deplacement.
    func doubleCliquer() {
        versMaison(enFondu: true)
    }

    private func voler(_ v: Vol, visee: Visee, enFondu: Bool = false) {
        zoomEnAttente = 0
        rotationEnAttente = .zero
        viseeVol = nil
        if reduire && enFondu {
            fondu = Fondu(debut: Self.maintenant(), arrivee: t, orbite: v.orbite(1, depuis: orbite))
            vol = nil
        } else if reduire {
            orbite = v.orbite(1, depuis: orbite)
            vol = nil
        } else {
            vol = v
            viseeVol = visee
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
        // Taille ou marges changees : la vue d'ensemble se recadre, sauf si Djoko a zoome ou isole une piece ; une
        // nouvelle zone visible recalcule la grille (polissage C, sections 3.3 et 3.5).
        taille = nouvelle
        let changee = zoneVisible != zoneGrille
        zoneGrille = zoneVisible
        let now = Self.maintenant()
        let m = margesDuCadre(now)
        let voulu = CGRect(x: 0, y: m.haut, width: nouvelle.width, height: max(1, nouvelle.height - m.haut - m.bas))
        if voulu != cadre {
            cadre = voulu
            if aLaVueDEnsemble && !fige { recadrer() }
        }
        if changee && !fige { zoneChangee() }
        if !fige { avancer(now) }
        guard pret, let scene else { return }
        let parts = scene.pieces.map { fk[$0.id] ?? 0 }
        let etat = EtatAnime(t: t, s: s, fk: parts, focus: focus, survol: survol, selection: selection, se: se,
                             ek: scene.etages.map { ek[$0.id] ?? 0 }, survolEtage: survolEtage)
        let p = SceneProjetee(scene: scene, cartes: cartes, positions: positions, geometrie: geometrie, etat: etat,
                              orbite: orbite, cadre: cadre, poses: posesAffichees)
        PlacementNoms.regler(&etiquettes, scene: scene, niveau: p.niveau, survol: survol, selection: selection, focus: focus,
                             isolee: estIsolee, fk: parts, s: s, t: t, se: se, voiles: p.voilesEtages,
                             etageIsole: indiceEtageIsole, survolNomEtage: survolNomEtage)
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
                                             apparences: apparences, routeurs: routeurs,
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

    /// Le dessin des pastilles : celles de la scene, et celles qui s'effacent, de la scene d'avant.
    private var apparences: [String: DessinNoeud.Apparence] {
        let a = entree?.apparences ?? [:]
        return apparencesParties.isEmpty ? a : a.merging(apparencesParties) { x, _ in x }
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

    /// L'etage vise par l'isolement, dans la scene ; nil : la maison ou une piece.
    var indiceEtageIsole: Int? {
        guard case .etage(let cle) = isolement else { return nil }
        return scene?.etages.firstIndex { $0.id == cle }
    }

    private func ligne(_ niveau: NiveauZoom, ancres: [CGRect?]) -> LigneNiveau {
        if estIsolee, let nom = isolee { return .isolee(nom) }
        if let e = indiceEtageIsole, let nom = textes.etages[e] { return .etageIsole(nom) }
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
        if se != seCible {
            let r = min(1, max(0, (now - seDebut) / CameraScene.dureeVol))
            se = seDepart + (seCible - seDepart) * r
            if r >= 1 {
                se = seCible
                if se == 0 { etageEnVue = nil }
            }
        }
        // Les parts propres, par cle : celle de la piece isolee et celle de l'etage en vue tendent vers 1.
        if let scene {
            let piece = focus.flatMap { $0 < scene.pieces.count && sCible == 1 ? scene.pieces[$0].id : nil }
            func tendre(_ x: Double?, vers c: Double) -> Double {
                var f = x ?? 0
                f += (c - f) * min(1, dt * 3.5)
                return abs(c - f) < 1e-3 ? c : f
            }
            for p in scene.pieces { fk[p.id] = tendre(fk[p.id], vers: p.id == piece ? 1 : 0) }
            for e in scene.etages { ek[e.id] = tendre(ek[e.id], vers: e.id == etageEnVue ? 1 : 0) }
        }
        // Les plateaux et les pieces glissent ; la vue suit ce qu'elle regarde.
        if glissementPlateaux != nil || transition != nil {
            let ancre0 = ancreCamera()
            if glissementPlateaux != nil {
                geometrie = geometrie(a: now)
                if geometrie == geometrieVisee { glissementPlateaux = nil }
            }
            if let tr = transition {
                if tr.finie(a: now) {
                    finirTransition()
                } else {
                    posesAffichees = tr.poses(a: now)
                }
            }
            suivre(depuis: ancre0)
        }
        if let v = vol {
            let q = min(1, max(0, (now - debutVol) / CameraScene.dureeVol))
            orbite = v.orbite(q, depuis: orbite)
            if q >= 1 {
                vol = nil
                viseeVol = nil
            }
        } else if envol == nil && fondu == nil {
            controles()
        }
        // Une grille qui attendait la vue d'ensemble 2D s'y pose.
        if let g = politique.attente, t == 0, aLaVueDEnsemble { poserGrille(g) }
        if !occupe, let e = attente { appliquer(e) }
    }

    /// La rotation lente tourne (`Isolement.rotationLente`).
    private var rotationLente: Bool {
        Isolement.rotationLente(troisD: troisD, bascule: t, cochee: rotation, reduire: reduire, sansIsolement: sansIsolement)
    }

    /// Rotation lente, rotation amortie, zoom amorti ; rien pendant ⌥ + glisser : ce qui attend reprend au relachement.
    private func controles() {
        guard !deplaceDansLEcran else { return }
        if rotationLente && geste == nil {
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

    /// Fin du glissement d'une disposition : tout est pose.
    private func finirTransition() {
        transition = nil
        posesAffichees = PosesScene()
        apparencesParties = [:]
    }

    // MARK: Horloge

    func doitContinuer(_ now: Double) -> Bool {
        // Une scene qui attend la fin d'un glisser s'applique au relachement : pas d'image pour elle.
        if enMouvement || s != sCible || margesEnRoute || glissementPlateaux != nil || transition != nil
            || (attente != nil && geste == nil) {
            return true
        }
        if se != seCible || fk.values.contains(where: { $0 != 0 && $0 != 1 }) || ek.values.contains(where: { $0 != 0 && $0 != 1 }) {
            return true
        }
        if rotationLente { return true }
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

    /// Survol : le nom de l'appareil en semi-gras ; un disque cliquable s'eclaircit, le nom d'un etage se souligne ; la
    /// main sur ce qui se clique (polissage C, maquette). Rien pendant l'envol : ni clic, ni menu du clic droit.
    func survoler(_ p: CGPoint?, option: Bool = false) {
        curseur = p
        optionTenue = option
        let libre = envol == nil && fondu == nil
        let c = libre ? p.map(cibleClic(en:)) ?? .fond : .fond
        let n: String? = if case .appareil(let id) = c { id } else { nil }
        let disque: Int? = if case .disque(let e) = c, disqueCliquable(e) { e } else { nil }
        let nom: Int? = if case .nomEtage(let e) = c { e } else { nil }
        if n != survol || disque != survolEtage || nom != survolNomEtage {
            survol = n
            survolEtage = disque
            survolNomEtage = nom
            reveiller()
        }
        surCliquable = switch c {
        case .appareil, .piece: true
        case .nomEtage(let e): clicEtage(e, disque: false) != .rien
        case .disque(let e): disqueCliquable(e)
        case .fond: false
        }
        majCurseur()
        let cible = libre ? p.map(cible(en:)) ?? .aucune : .aucune
        if cible != cibleMenu { cibleMenu = cible }
    }

    /// ⌥ pressee ou relachee, le pointeur immobile (le moniteur des touches).
    func changerOption(_ option: Bool) {
        guard option != optionTenue else { return }
        optionTenue = option
        majCurseur()
    }

    /// Le curseur (polissage C, section 6) : une main fermee pendant ⌥ + glisser ; une main ouverte tant que ⌥ est
    /// tenue au-dessus de la vue en 3D ; sinon, une main sur ce qui se clique.
    private func majCurseur() {
        let forme: Curseur
        if case .ecran? = geste {
            forme = .mainFermee
        } else if optionTenue && curseur != nil && troisD && t == 1 && envol == nil && fondu == nil {
            forme = .mainOuverte
        } else {
            forme = surCliquable ? .main : .fleche
        }
        if forme != curseurForme { curseurForme = forme }
    }

    /// Ce que vise un clic en `p`, du plus fort au plus faible (polissage C, section 5.1).
    func cibleClic(en p: CGPoint) -> CibleClic {
        if let n = noeudSous(p) { return .appareil(n) }
        if let i = pieceSous(p) { return .piece(i) }
        if let e = nomEtageSous(p) { return .nomEtage(e) }
        if let e = disqueSous(p) { return .disque(e) }
        return .fond
    }

    /// Nom d'etage sous un point (`marge` points autour).
    func nomEtageSous(_ p: CGPoint, marge: CGFloat = 0) -> Int? {
        for l in etiquettes where l.vu && l.rect.insetBy(dx: -marge, dy: -marge).contains(p) {
            if case .etage(let e) = l.genre { return e }
        }
        return nil
    }

    /// Disque d'un plateau sous un point : en 3D, le plus proche sur le rayon, au point ou il le rencontre.
    func disqueSous(_ p: CGPoint) -> Int? {
        guard let projetee else { return nil }
        let proj = ProjectionScene(orbite, cadre: cadre)
        var meilleur: (etage: Int, profondeur: Double)?
        for pl in projetee.plateaux where pl.etage < geometrie.rayons.count && SceneProjetee.contient(pl.polygone, p) {
            let point = proj.sol(p, hauteur: geometrie.centrePlateau(pl.etage, t).y)
            let d = point.map { proj.profondeur($0) } ?? pl.profondeur
            if d < meilleur?.profondeur ?? .infinity { meilleur = (pl.etage, d) }
        }
        return meilleur?.etage
    }

    /// Un clic sur ce disque fait quelque chose (polissage C, section 5.4) : sauf celui de l'etage isole, entre ses
    /// pieces ; dans une maison d'un seul plateau, seulement depuis une piece isolee, pour remonter.
    func disqueCliquable(_ e: Int) -> Bool {
        clicEtage(e, disque: true) != .rien
    }

    /// Ce que fait un clic sur le nom ou le disque du plateau `e` (`Isolement.clicEtage`) : la regle du clic et de la
    /// main du pointeur.
    private func clicEtage(_ e: Int, disque: Bool) -> Isolement.ClicEtage {
        guard let scene, e < scene.etages.count else { return .rien }
        return isolement.clicEtage(scene.etages[e].id, disque: disque, plusieursPlateaux: scene.etages.count > 1,
                                   pieceIsolee: estIsolee)
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

    /// Clic droit (polissage C, section 1.3) : le nom d'un etage, a 2 points pres, ou son disque, hors des pieces et
    /// des appareils, par la cle de son plateau ; le fond, hors de tout cela ; rien sur une piece ou un appareil.
    func cible(en p: CGPoint) -> CibleMenu {
        if let e = nomEtageSous(p, marge: 2) { return cleEtage(e).map(CibleMenu.etage) ?? .aucune }
        if noeudSous(p) != nil || pieceSous(p) != nil { return .aucune }
        if let e = disqueSous(p) { return cleEtage(e).map(CibleMenu.etage) ?? .aucune }
        return .fond
    }

    /// Un glisser, a chaque deplacement du pointeur ; `option` : ⌥ tenue, lue a l'appui seulement (polissage C,
    /// section 6) : en 3D, la vue glisse alors dans le plan de l'ecran, depuis le fond, un disque ou une piece, qui ne
    /// bouge pas ; un vol en cours s'arrete, et pendant le geste la camera n'obeit qu'au pointeur (`deplaceDansLEcran`).
    /// Relacher ⌥ en route ne change rien. En 2D, ⌥ ne change rien.
    func glisser(_ p: CGPoint, depart d: CGPoint, option: Bool = false) {
        // Un geste reste d'un glisser annule (sans relachement), et celui-ci part d'ailleurs : il est clos.
        if geste != nil, d != departGeste { terminerGeste() }
        if geste == nil {
            bouge = false
            abandonApresGlisser = false
            precedent = d
            departGeste = d
            if option && troisD && t == 1 && envol == nil && fondu == nil {
                vol = nil
                viseeVol = nil
                geste = .ecran(orbite)
            } else if !estIsolee, !enMouvement, let scene, let i = projetee?.piece(sous: d), i < scene.pieces.count,
                      indiceEtageIsole.map({ $0 == scene.pieces[i].etage }) ?? true {
                // Les pieces de l'etage isole se glissent ; celles des autres etages se cliquent seulement. Une piece en
                // route vers sa place y est posee, avec ses noeuds : elle suit le pointeur depuis sa place.
                transition?.oublier(pieces: [scene.pieces[i].id], noeuds: Set(scene.pieces[i].noeuds))
                if let tr = transition { posesAffichees = tr.poses(a: Self.maintenant()) }
                geste = .piece(scene.pieces[i].id, hauteur: centrePiece(i)?.y ?? 0)
            } else {
                geste = .fond
            }
            majCurseur()
        }
        if !bouge && hypot(p.x - d.x, p.y - d.y) < 5 { return }
        bouge = true
        defer { precedent = p }
        guard !enMouvement, let geste else { return }
        let proj = ProjectionScene(orbite, cadre: cadre)
        switch geste {
        case .ecran(let o):
            orbite = CameraScene.deplacerDansLEcran(o, glisse: CGSize(width: p.x - d.x, height: p.y - d.y), cadre: cadre)
            vueTouchee = true
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

    /// Fin d'un glisser, ou clic. Deux clics sur le fond ou sur un disque, a moins de l'intervalle du double-clic
    /// de macOS et de 5 points : le second est un double-clic ; le premier a agi comme un clic simple. Une
    /// scene recue pendant le geste s'applique ensuite, avec la place gardee de la piece glissee.
    func relacher(_ p: CGPoint, a instant: Double = MoteurPieces.maintenant()) {
        let g = geste
        let clic = !bouge && !(g == nil && abandonApresGlisser)
        geste = nil
        bouge = false
        abandonApresGlisser = false
        majCurseur()
        if case .piece(let id, _)? = g, !clic {
            garder(id)
        } else if clic {
            let fond = switch cibleClic(en: p) {
            case .fond, .disque: true
            default: false
            }
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
        majCurseur()
    }

    /// Clic sans glisser, selon sa cible (polissage C, sections 5.1 et 5.4) : un appareil ou son nom ouvre sa fiche ;
    /// une piece ou son nom l'isole (en piece isolee, une autre piece y mene, meme pendant le vol) ; le nom ou le
    /// disque d'un etage l'isole ; a cote, la fiche se ferme et la vue remonte d'ou elle vient. Rien pendant l'envol.
    func cliquer(_ p: CGPoint) {
        guard envol == nil, fondu == nil else { return }
        switch cibleClic(en: p) {
        case .appareil(let n):
            selection = n
        case .piece(let i):
            if !(focus == i && sCible == 1) { isoler(i) }
        case .nomEtage(let e):
            cliquerEtage(e, disque: false)
        case .disque(let e):
            cliquerEtage(e, disque: true)
        case .fond:
            selection = nil
            remonter(clavier: false)
        }
    }

    /// Clic sur le nom ou le disque d'un etage : il l'isole ; son propre disque, l'etage isole, entre les pieces, ne
    /// fait rien. Maison d'un seul plateau : seulement depuis une piece isolee, pour remonter a la maison.
    private func cliquerEtage(_ e: Int, disque: Bool) {
        switch clicEtage(e, disque: disque) {
        case .isoler: allerEtage(e)
        case .maison: versMaison()
        case .rien: break
        }
    }

    /// La molette zoome, sauf pendant un vol et pendant ⌥ + glisser : elle est alors ignoree, non differee.
    func molette(_ dy: Double, precis: Bool) {
        guard !enMouvement, !deplaceDansLEcran else { return }
        zoomer(precis ? -dy * 0.004 : -dy * 0.08, en: curseur)
    }

    /// Le pincement zoome de son increment depuis le dernier `m`, sauf pendant un vol et pendant ⌥ + glisser : il est
    /// alors ignore, mais suivi, pour que celui qui continue apres ne saute pas de ce qu'il a fait pendant.
    func pincer(_ m: Double, en p: CGPoint) {
        let l = -log(max(0.05, m) / max(0.05, dernierPincement))
        dernierPincement = m
        guard !enMouvement, !deplaceDansLEcran else { return }
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
        moniteur = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown, .flagsChanged]) { [weak self] e in
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
            case .flagsChanged:
                // ⌥ et la main ouverte (polissage C, section 6) : l'evenement continue son chemin.
                let option = e.modifierFlags.contains(.option)
                MainActor.assumeIsolated { self.changerOption(option) }
                return e
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

    /// Une piece isolee, au bout de son vol ; `depuisEtage` : ouverte depuis son etage isole (sa provenance).
    func poserIsolement(_ i: Int, depuisEtage: Bool = false) {
        guard let scene, i < scene.pieces.count else { return }
        let etage = scene.etages[scene.pieces[i].etage].id
        isolement = .piece(scene.pieces[i].id, provenance: depuisEtage ? etage : nil)
        focus = i
        isolee = textes.pieces[i]?.nom
        s = 1
        sCible = 1
        fk[scene.pieces[i].id] = 1
        if scene.etages.count > 1 {
            etageEnVue = etage
            se = 1
            seCible = 1
            ek[etage] = 1
        }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        majFil()
        if let v = volVersPiece(i) { orbite = v.orbite(1, depuis: orbite) }
    }

    /// Un etage isole, au bout de son vol.
    func poserEtageIsole(_ e: Int) {
        guard let scene, scene.etages.count > 1, e < scene.etages.count else { return }
        let cle = scene.etages[e].id
        isolement = .etage(cle)
        etageEnVue = cle
        se = 1
        seCible = 1
        ek[cle] = 1
        majFil()
        orbite = volVersEtage(e).orbite(1, depuis: orbite)
    }

    func poserSurvol(_ id: String?) { survol = id }

    /// Le glissement d'une disposition, pose a `q` (de 0 a 1) de son temps, sans horloge : les poses des pieces et des
    /// noeuds, et les plateaux qui glissent avec eux.
    func poserTransition(_ q: Double) {
        guard let tr = transition else { return }
        posesAffichees = tr.poses(a: tr.debut + q * TransitionScene.duree)
        if let gl = glissementPlateaux { geometrie = geometrie(a: gl.debut + q * max(gl.duree2D, gl.duree3D)) }
    }

    /// Le glissement d'une disposition et celui des plateaux, commences `dt` secondes plus tot (tests) : l'image suivante
    /// les avance d'autant, par l'horloge.
    func reculerTransition(de dt: Double) {
        transition?.debut -= dt
        glissementPlateaux?.debut -= dt
    }

    func poserAzimut(_ decalage: Double) { orbite.azimut += decalage }

    func poserInclinaison(_ i: Double) { orbite.inclinaison = i }

    /// Centre du bloc d'une piece, dans le monde ; dans la geometrie de l'image, ou dans `g`.
    func centrePiece(_ i: Int, dans g: GeometrieMaison? = nil) -> SIMD3<Double>? {
        guard let scene, i < scene.pieces.count, i < positions.count else { return nil }
        let g = g ?? geometrie
        // En route (polissage D, section 1) : sa pose affichee.
        if let pose = posesAffichees.pieces[scene.pieces[i].id],
           let m = PosesScene.centre(pose.ancres, geometrie: g, plateaux: plateaux(scene), t: t) {
            return SIMD3(m.x, m.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, m.z)
        }
        let c = g.centrePlateau(scene.pieces[i].etage, t)
        return SIMD3(c.x + positions[i].x, c.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, c.z + positions[i].y)
    }

    /// L'indice de chaque plateau de la scene, par cle.
    private func plateaux(_ scene: ScenePieces) -> [String: Int] {
        Dictionary(scene.etages.indices.map { (scene.etages[$0].id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Zoom a l'echelle `k` (points par unite a la cible, divises par 24), vers le point `vers`.
    func poserZoom(echelle k: Double, vers a: SIMD3<Double>?) {
        let k0 = ProjectionScene(orbite, cadre: cadre).pxParUnite(orbite.cible) / CartesPieces.px
        let f = k0 / k
        if let a { orbite.cible = a + (orbite.cible - a) * f }
        orbite.distance *= f
        vueTouchee = true
    }

    /// Pose le cadre sans image, et la grille de cette zone visible, tout de suite (captures, tests).
    func poserTaille(_ nouvelle: CGSize) {
        taille = nouvelle
        zoneGrille = zoneVisible
        margesCadre = marges
        glissement = nil
        cadre = CGRect(x: 0, y: marges.haut, width: nouvelle.width,
                       height: max(1, nouvelle.height - marges.haut - marges.bas))
        guard pret, let scene else { return }
        politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: true)
        glissementPlateaux = nil
        politique.oublierAttente()
        geometrieVisee = geometriePour(scene)
        geometrie = geometrieVisee
        recadrer()
    }
}
