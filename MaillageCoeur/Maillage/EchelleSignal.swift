import Foundation

/// Le signal vu par la sonde, dans la fiche (polissage D, section 4.3) : son echelle, toujours visible, meme pour un
/// seul point ou des valeurs toutes egales ; le releve sous le pointeur et son etiquette.
public enum EchelleSignal {
    /// Un releve ne compte au survol qu'a moins de 2 % de la duree de la periode du pointeur.
    public static let portee = 0.02

    /// Le domaine vertical (dBm) : du minimum moins 5 dB, arrondi a la dizaine inferieure, au maximum plus 5 dB, arrondi
    /// a la dizaine superieure ; au moins 10 dB. Nil sans valeur.
    public static func domaine(_ valeurs: [Double]) -> ClosedRange<Double>? {
        guard let bas = valeurs.min(), let haut = valeurs.max() else { return nil }
        return ((bas - 5) / 10).rounded(.down) * 10 ... ((haut + 5) / 10).rounded(.up) * 10
    }

    /// Les graduations : chaque dizaine du domaine, du bas vers le haut.
    public static func graduations(_ d: ClosedRange<Double>) -> [Double] {
        stride(from: (d.lowerBound / 10).rounded(.up) * 10, through: d.upperBound, by: 10).map { $0 }
    }

    /// Le releve le plus proche de `date` dans le temps, a moins de 2 % de la duree de `periode` ; nil s'il n'y en a pas
    /// (un trou de la courbe). A egale distance, le plus ancien.
    public static func plusProche(_ points: [PointCourbe], de date: Date, periode: PeriodeCourbes) -> PointCourbe? {
        let portee = Self.portee * periode.duree
        return points.filter { abs($0.date.timeIntervalSince(date)) < portee }
            .min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    /// L'etiquette d'un releve : sa valeur arrondie au dBm, avec le vrai signe moins, puis son heure, au format de
    /// `locale`, dans le fuseau `fuseau` : « −67 dBm · 14:32 » ; en 7 j et 30 j, le jour aussi.
    public static func etiquette(_ p: PointCourbe, periode: PeriodeCourbes, locale: Locale, fuseau: TimeZone) -> String {
        let v = Int(p.valeur.rounded())
        let valeur = (v < 0 ? "\u{2212}" : "") + String(abs(v))
        var style = Date.FormatStyle(locale: locale, timeZone: fuseau).hour().minute()
        if periode != .jour { style = style.day().month(.abbreviated) }
        return valeur + " dBm · " + p.date.formatted(style)
    }

    /// L'etiquette se pose a gauche du trait dans la moitie droite du graphe (`debut` a `fin`), a droite sinon : elle
    /// reste dans le cadre.
    public static func aGauche(_ date: Date, debut: Date, fin: Date) -> Bool {
        let duree = fin.timeIntervalSince(debut)
        return duree > 0 && date.timeIntervalSince(debut) / duree > 0.5
    }
}
