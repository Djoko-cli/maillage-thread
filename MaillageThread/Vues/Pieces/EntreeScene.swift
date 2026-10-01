import MaillageCoeur
import SwiftUI

/// Ce que la vue par pieces montre d'un reseau, tire de la surveillance (spec de la vue par pieces,
/// section 2) : la scene, le libelle et l'apparence de chaque noeud, et la maison de ses places
/// gardees.
struct EntreeScene: Equatable {
    var scene: ScenePieces
    var libelles: [String: LibellesNoeuds.Libelle]
    var apparences: [String: DessinNoeud.Apparence]
    /// Domicile de Maison ("" sans nom) : la cle de ses places gardees.
    var domicile: String

    /// `places` : les places gardees, dont l'ordre des etages de la maison ; `choix` : les pieces
    /// choisies pour les routeurs de bordure que Maison ne place pas.
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
                                           nomsRouteurs: surveillance.nomsRouteurs(pour: r), choix: choix)
        let scene = ScenePieces(graphe: graphe, libelles: libelles.mapValues(\.texte), piecesNoeuds: pieces,
                                zones: maison?.zones, chefs: chefs,
                                piecesMaison: maison?.accessoires.contains { $0.piece?.isEmpty == false } == true,
                                ordreEtages: places.maison(domicile).ordreEtages)
        let principale = r.partitions.first(where: \.estPrincipale)?.id
        self.scene = scene
        self.libelles = libelles
        self.domicile = domicile
        apparences = Dictionary(scene.noeuds.map { n in
            (n.id, DessinNoeud.apparence(n, etat: parId[n.id]?.etat, principale: n.partition == principale))
        }, uniquingKeysWith: { a, _ in a })
    }

    /// Ce qui oblige a recalculer la disposition (spec, section 4.3) : les etages, leurs pieces, les
    /// noeuds de chacune et leurs noms. L'ordre des etages seul, ou l'etat d'un noeud, non.
    var cleDisposition: [String: [String: [String]]] {
        var c: [String: [String: [String]]] = [:]
        for e in scene.etages {
            for i in e.pieces {
                let p = scene.pieces[i]
                c[e.id, default: [:]][p.id] = p.noeuds.map { id in
                    [id, libelles[id]?.texte ?? "", libelles[id]?.pastille ?? ""].joined(separator: "|")
                }
            }
        }
        return c
    }
}
