import MaillageCoeur
import SwiftUI

/// Ce que la vue par pieces montre d'un reseau, tire de la surveillance (spec de la vue par pieces,
/// section 2) : la scene, le libelle et l'apparence de chaque noeud, et la maison de ses places
/// gardees ; avec ce dont la scene est faite, construit une fois avec elle a chaque rendu (le graphe,
/// le maillage rapproche, les chefs, les appareils), que la fiche et « Placer dans une piece… » lisent
/// ici, sans rien reconstruire : ils voient les memes noeuds, les memes cles et les memes chefs que la
/// scene.
struct EntreeScene: Equatable {
    var scene: ScenePieces
    var libelles: [String: LibellesNoeuds.Libelle]
    var apparences: [String: DessinNoeud.Apparence]
    /// Domicile de Maison ("" sans nom) : la cle de ses places gardees.
    var domicile: String
    /// Noeuds et liens du reseau.
    var graphe: GrapheReseau
    /// Maillage de la sonde rapproche du reseau ; nil sans sonde, ou s'il est perime.
    var maillage: MaillageAffiche?
    /// Noeuds couronnes (le chef de chaque partition, celui du maillage de la sonde) : ceux des
    /// libelles ; la couronne suit ceux-ci partout ou elle parait.
    var chefs: Set<String>
    /// Appareils affiches, par id.
    var appareils: [String: AppareilAffiche]

    /// `places` : les places gardees, dont l'ordre des etages de la maison et ses choix de niveau ; `choix` :
    /// les pieces choisies pour les noeuds que Maison ne place pas, routeurs de bordure (sous leur instance)
    /// et autres noeuds (sous leur ExtMac, precision 27).
    @MainActor
    init(surveillance: Surveillance, reseau r: Reseau, places: PlacesGardees, choix: PiecesRouteurs = PiecesRouteurs()) {
        let affiches = surveillance.appareilsAffiches(pour: r)
        let maillage = surveillance.maillageAffiche(pour: r)
        let graphe = GrapheReseau(reseau: r, appareils: affiches, maillage: maillage)
        let parId = Dictionary(affiches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let chefs = LibellesNoeuds.chefs(reseau: r, maillage: surveillance.maillage, affiche: maillage)
        let libelles = LibellesNoeuds.libelles(graphe: graphe, appareils: parId,
                                               nomsRouteurs: surveillance.nomsRouteurs(pour: r), maillage: maillage,
                                               chefs: chefs)
        let maison = surveillance.noms.maison
        let domicile = maison?.domicile ?? ""
        let pieces = LibellesNoeuds.pieces(reseau: r, appareils: affiches, maison: maison,
                                           nomsRouteurs: surveillance.nomsRouteurs(pour: r), choix: choix,
                                           graphe: graphe)
        let scene = ScenePieces(graphe: graphe, libelles: libelles.mapValues(\.texte), piecesNoeuds: pieces,
                                zones: maison?.zones, chefs: chefs,
                                piecesMaison: maison?.accessoires.contains { $0.piece?.isEmpty == false } == true,
                                ordreEtages: places.maison(domicile).ordreEtages, aCote: places.maison(domicile).aCote)
        let principale = r.partitions.first(where: \.estPrincipale)?.id
        self.scene = scene
        self.libelles = libelles
        self.domicile = domicile
        self.graphe = graphe
        self.maillage = maillage
        self.chefs = chefs
        appareils = parId
        apparences = Dictionary(scene.noeuds.map { n in
            (n.id, DessinNoeud.apparence(n, etat: parId[n.id]?.etat, principale: n.partition == principale))
        }, uniquingKeysWith: { a, _ in a })
    }

    /// Egalite de ce que la vue dessine : la scene, les libelles, les apparences et le domicile. Ce dont
    /// la scene est faite n'y entre pas : un maillage recu plus tard, qui ne change rien a la scene, ne
    /// la fait pas reposer par le moteur (`MoteurPieces.recevoir`).
    static func == (a: EntreeScene, b: EntreeScene) -> Bool {
        a.scene == b.scene && a.libelles == b.libelles && a.apparences == b.apparences && a.domicile == b.domicile
    }

    /// Ce qui oblige a recalculer la disposition (spec, section 4.3 ; polissage C, section 4).
    struct CleDisposition: Equatable {
        /// Etage -> piece -> ses noeuds et leurs noms.
        var pieces: [String: [String: [String]]] = [:]
        /// La place de chaque plateau dans la vue de reference du cout : l'etage principal de son niveau, et
        /// son rang dans le niveau.
        var niveaux: [String: String] = [:]
    }

    /// Les etages, leurs pieces, les noeuds de chacune et leurs noms, et les niveaux tels que les voit le cout :
    /// qui partage le niveau de qui, dans quel ordre. L'ordre des niveaux, une zone dans ou hors de la maison,
    /// ou l'etat d'un noeud, non.
    var cleDisposition: CleDisposition {
        var c = CleDisposition()
        for e in scene.etages {
            for i in e.pieces {
                let p = scene.pieces[i]
                c.pieces[e.id, default: [:]][p.id] = p.noeuds.map { id in
                    [id, libelles[id]?.texte ?? "", libelles[id]?.pastille ?? ""].joined(separator: "|")
                }
            }
        }
        for l in scene.niveaux.liste {
            for (k, cle) in l.enumerated() { c.niveaux[cle] = l[0] + "#" + String(k) }
        }
        return c
    }
}
