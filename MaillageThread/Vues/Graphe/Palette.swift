import MaillageCoeur
import SwiftUI

/// Couleurs du graphe, en mode sombre (fond profond) et clair (fond pale).
struct Palette {
    let sombre: Bool

    var fond: Gradient {
        sombre ? Gradient(colors: [Color(red: 0.12, green: 0.23, blue: 0.54), Color(red: 0.06, green: 0.09, blue: 0.16),
                                   Color(red: 0.01, green: 0.02, blue: 0.09)])
               : Gradient(colors: [Color(red: 0.86, green: 0.91, blue: 1.0), Color(red: 0.95, green: 0.96, blue: 0.99),
                                   Color.white])
    }

    var texte: Color { sombre ? Color(white: 0.9) : Color(white: 0.2) }
    var texteDiscret: Color { sombre ? Color(white: 0.7) : Color(white: 0.4) }
    var lien: Color { sombre ? Color.white.opacity(0.28) : Color.black.opacity(0.22) }
    var lienEclaire: Color { sombre ? Color.white.opacity(0.85) : Color.black.opacity(0.7) }
    var selection: Color { sombre ? .white : .black }
    /// Pastille d'une batterie faible : orange vif en halo, texte brun fonce.
    var batterieFaible: Color { Color(red: 1.0, green: 0.62, blue: 0.1) }
    var texteBatterieFaible: Color { Color(red: 0.25, green: 0.12, blue: 0.0) }

    /// La principale en bleu, les autres en ambre, les sans-partition en gris.
    func zone(_ z: Disposition.Zone) -> Color {
        if z.id.isEmpty { return .gray }
        return z.principale ? Color(red: 0.23, green: 0.51, blue: 0.96) : Color(red: 0.96, green: 0.62, blue: 0.04)
    }

    func routeur(principale: Bool) -> Color {
        principale ? Color(red: 0.38, green: 0.65, blue: 0.98) : Color(red: 0.98, green: 0.75, blue: 0.14)
    }

    func appareil(_ e: EtatAffiche) -> Color {
        switch e {
        case .joignable: Color(red: 0.29, green: 0.87, blue: 0.5)
        case .partitionCoupee: .orange
        case .sansAdresse, .disparu: Color(red: 0.97, green: 0.44, blue: 0.44)
        case .inconnu: .gray
        }
    }
}
