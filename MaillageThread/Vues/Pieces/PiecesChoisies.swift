import Foundation
import MaillageCoeur
import SwiftUI

/// Pieces choisies pour les routeurs de bordure que Maison ne place pas (« Placer dans une piece… »,
/// dans la fiche du routeur ; precision 24 du plan 4b) : sous l'instance de l'annonce, par maison,
/// dans `pieces-routeurs.json`, a cote des places des pieces ; en memoire seulement en demo et sous
/// les tests. Le calcul est dans le coeur (`PiecesRouteurs`).
@MainActor
@Observable
final class PiecesChoisies {
    private(set) var choix: PiecesRouteurs
    @ObservationIgnored private let fichier: URL?

    /// `fichier` : `pieces-routeurs.json` (`fichier(demo:sousTests:)`) ; nil : ni lu ni ecrit.
    init(fichier: URL?) {
        self.fichier = fichier
        choix = fichier.map(PiecesRouteurs.lire) ?? PiecesRouteurs()
    }

    /// A cote des places des pieces ; ni en demo ni sous les tests.
    static func fichier(demo: Bool, sousTests: Bool) -> URL? {
        demo || sousTests ? nil : Surveillance.dossierParDefaut.appendingPathComponent("pieces-routeurs.json")
    }

    /// Place un routeur (son instance) dans une piece de la maison ; nil : d'apres son nom.
    func choisir(_ piece: String?, routeur: String, domicile: String) {
        choix.choisir(piece, routeur: routeur, domicile: domicile)
        guard let fichier else { return }
        do {
            try choix.ecrire(dans: fichier)
        } catch {
            MoteurPieces.journal.error("pieces des routeurs non ecrites : \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension PiecesChoisies {
    /// Pieces proposees par « Placer dans une piece… » pour un noeud : celles de la maison, par nom,
    /// pour un routeur de bordure que Maison ne place pas ; nil pour un autre noeud, ou si Maison n'a
    /// encore aucune piece.
    static func pieces(aPlacer id: String, dans surveillance: Surveillance) -> [String]? {
        guard surveillance.instantane?.routeur(id) != nil else { return nil }
        let maison = surveillance.noms.maison
        guard LibellesNoeuds.pieceDeMaison(routeur: id, maison: maison) == nil else { return nil }
        let pieces = PiecesRouteurs.pieces(de: maison).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return pieces.isEmpty ? nil : pieces
    }
}

/// « Placer dans une piece… », dans la fiche d'un routeur de bordure que Maison ne place pas : « D'apres
/// son nom » (la regle du nom), puis les pieces de la maison ; le choix en cours est coche.
struct MenuPlacerRouteur: View {
    let routeur: String
    let pieces: [String]
    let domicile: String
    let choisies: PiecesChoisies

    var body: some View {
        Menu("Placer dans une pièce…") {
            Picker("Placer dans une pièce…", selection: Binding(
                get: { choisies.choix.choix(routeur: routeur, domicile: domicile) },
                set: { choisies.choisir($0, routeur: routeur, domicile: domicile) })) {
                Text("D'après son nom").tag(String?.none)
                ForEach(pieces, id: \.self) { Text(verbatim: $0).tag(String?.some($0)) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .fixedSize()
    }
}
