import Foundation
import MaillageCoeur

/// Textes de l'avancement d'une tournee : barre du graphe, Reglages › Sonde, menu.
enum TexteTournee {
    /// Libelle court d'une etape.
    static func etape(_ e: AvancementTournee.Etape) -> String {
        switch e {
        case .etatSonde: String(localized: "État de la sonde")
        case .listeRouteurs: String(localized: "Liste des routeurs")
        case .routeurs: String(localized: "Routeurs")
        case .pileEtReseau: String(localized: "Pile et Network Data")
        case .balayage: String(localized: "Balayage des routeurs muets")
        case .identites: String(localized: "Identité des enfants")
        }
    }

    /// « Balayage des routeurs muets · 24/48 » ; l'etape seule quand elle n'a rien a faire.
    static func avancement(_ a: AvancementTournee) -> String {
        guard a.total > 0 else { return etape(a.etape) }
        return String(localized: "\(etape(a.etape)) · \(a.fait)/\(a.total)")
    }

    /// Duree ecoulee : « 0:42 », « 1:02:03 » au-dela d'une heure.
    static func chrono(_ secondes: TimeInterval) -> String {
        let s = max(0, Int(secondes))
        if s >= 3600 { return String(format: "%ld:%02ld:%02ld", s / 3600, s / 60 % 60, s % 60) }
        return String(format: "%ld:%02ld", s / 60, s % 60)
    }

    /// Duree ecoulee en unites : « 42 s », « 1 min 30 s ».
    static func duree(_ secondes: TimeInterval) -> String {
        Duration.seconds(max(0, Int(secondes)))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }

    /// Barre du graphe : « Balayage des routeurs muets · 24/48 · 0:42 ».
    static func barre(_ a: AvancementTournee, debut: Date, maintenant: Date) -> String {
        String(localized: "\(avancement(a)) · \(chrono(maintenant.timeIntervalSince(debut)))")
    }

    /// Texte le plus large de la barre pour une etape (compteur a trois chiffres, duree de
    /// 99:59), invisible : il donne sa largeur fixe a la capsule de la tournee.
    static func gabaritBarre(_ e: AvancementTournee.Etape) -> String {
        String(localized: "\(avancement(AvancementTournee(etape: e, fait: 888, total: 888))) · \(chrono(99 * 60 + 59))")
    }

    /// Reglages › Sonde : « Balayage des routeurs muets · 24/48 · depuis 42 s ».
    static func reglages(_ a: AvancementTournee, debut: Date, maintenant: Date) -> String {
        String(localized: "\(avancement(a)) · depuis \(duree(maintenant.timeIntervalSince(debut)))")
    }

    /// Menu : « SONDE-01 : Balayage des routeurs muets 24/48… ».
    static func menu(_ a: AvancementTournee, nom: String) -> String {
        guard a.total > 0 else { return String(localized: "\(nom) : \(etape(a.etape))…") }
        return String(localized: "\(nom) : \(etape(a.etape)) \(a.fait)/\(a.total)…")
    }
}
