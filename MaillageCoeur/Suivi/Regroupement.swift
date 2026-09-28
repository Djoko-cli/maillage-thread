import Foundation

/// Ligne du journal affiche : un evenement, ou des pertes regroupees.
public enum LigneJournal: Hashable, Sendable, Identifiable {
    case evenement(Evenement)
    /// Au moins 2 pertes dans une meme fenetre de 10 min, de la plus ancienne a la plus recente.
    case pertes([Evenement])

    public var id: String {
        switch self {
        case .evenement(let e): e.id
        case .pertes(let l): "pertes-" + (l.first?.id ?? "")
        }
    }

    /// Date de l'evenement, ou de la plus recente des pertes.
    public var date: Date {
        switch self {
        case .evenement(let e): e.date
        case .pertes(let l): l.last?.date ?? .distantPast
        }
    }

    public var evenements: [Evenement] {
        switch self {
        case .evenement(let e): [e]
        case .pertes(let l): l
        }
    }

    public var gravite: Gravite { evenements.map(\.gravite).max() ?? .info }
}

/// Regroupement des pertes pour l'affichage (le journal garde chaque evenement).
public enum Regroupement {
    /// Fenetre de regroupement, comptee depuis la premiere perte.
    public static let fenetre: TimeInterval = 600

    /// Perte : un appareil joignable devient sans adresse, disparait, ou passe
    /// dans une partition coupee.
    public static func estPerte(_ e: Evenement) -> Bool {
        switch e.type {
        case .appareilDisparu, .appareilSansAdresse: true
        case .appareilChangePartition: e.details["coupee"] == "oui"
        default: false
        }
    }

    /// Lignes du journal, les plus recentes d'abord : les pertes survenues dans
    /// une meme fenetre de 10 min forment une seule ligne.
    public static func lignes(_ evenements: [Evenement]) -> [LigneJournal] {
        let tries = evenements.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element)
        var lignes: [LigneJournal] = []
        var groupe: [Evenement] = []
        func fermer() {
            if groupe.count >= 2 {
                lignes.append(.pertes(groupe))
            } else if let e = groupe.first {
                lignes.append(.evenement(e))
            }
            groupe = []
        }
        for e in tries {
            if estPerte(e) {
                if let premiere = groupe.first, e.date.timeIntervalSince(premiere.date) >= fenetre { fermer() }
                groupe.append(e)
            } else {
                lignes.append(.evenement(e))
            }
        }
        fermer()
        return lignes.enumerated().sorted { ($0.element.date, $0.offset) > ($1.element.date, $1.offset) }.map(\.element)
    }
}
