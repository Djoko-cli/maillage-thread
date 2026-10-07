import Foundation

/// Qualite du lien d'un enfant vers son parent, tiree de ses compteurs MAC (TLV 9) entre deux releves (spec de la sonde
/// tout-en-un, section 2.3) : le taux d'echec, les echecs d'envoi sur les envois (Δ `ifOutErrors` / Δ
/// `ifOutUcastPkts`). C'est le lien vu du cote de l'enfant : sous un routeur Apple, qui ne repond pas au diagnostic, la
/// seule mesure possible ; la qualite vue par le parent reste inconnue.
public enum QualiteCompteurs {
    /// Trames envoyees entre deux releves, au moins : en deca, la qualite reste inconnue.
    public static let tramesMin: UInt32 = 50

    /// Qualite d'un taux d'echec : moins de 1 %, bonne (3) ; de 1 a 5 %, moyenne (2) ; au-dela, faible (1).
    public static func qualite(taux: Double) -> Int {
        taux < 0.01 ? 3 : taux <= 0.05 ? 2 : 1
    }

    /// Le taux d'echec entre deux releves, et sa qualite ; nil si moins de `tramesMin` trames sont parties entre les
    /// deux, ou si un compteur a baisse (l'appareil a redemarre : le releve repart de zero).
    public static func mesure(avant: CompteursMac, apres: CompteursMac) -> (qualite: Int, taux: Double)? {
        guard apres.unicastEmis >= avant.unicastEmis, apres.erreursEmises >= avant.erreursEmises else { return nil }
        let envois = apres.unicastEmis - avant.unicastEmis
        guard envois >= tramesMin else { return nil }
        let taux = Double(apres.erreursEmises - avant.erreursEmises) / Double(envois)
        return (qualite(taux: taux), taux)
    }
}
