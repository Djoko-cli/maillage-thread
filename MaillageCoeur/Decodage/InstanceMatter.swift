import Foundation

/// Instance `_matter._tcp` : un appareil sur une fabrique, nommee
/// "<fabrique>-<noeud>" (16 hexa chacun).
public struct InstanceMatter: Hashable, Comparable, Sendable {
    /// Identifiant compresse de la fabrique, 16 hexa majuscules.
    public let fabrique: String
    /// Identifiant du noeud sur cette fabrique, 16 hexa majuscules.
    public let noeud: String

    public init?(instance: String) {
        let m = instance.split(separator: "-", omittingEmptySubsequences: false)
        guard m.count == 2, m.allSatisfy({ $0.count == 16 && $0.allSatisfy(\.isHexDigit) }) else { return nil }
        fabrique = m[0].uppercased()
        noeud = m[1].uppercased()
    }

    public var nom: String { "\(fabrique)-\(noeud)" }

    public static func < (a: InstanceMatter, b: InstanceMatter) -> Bool {
        (a.fabrique, a.noeud) < (b.fabrique, b.noeud)
    }
}

/// Proprietes Matter annoncees dans le TXT d'une instance operationnelle.
public struct ProprietesMatter: Hashable, Sendable {
    /// `SII` : intervalle de repos (ms).
    public let sii: Int?
    /// `SAI` : intervalle actif (ms).
    public let sai: Int?
    /// `ICD` : mode de l'appareil a faible consommation (0 SIT, 1 LIT).
    public let icd: Int?

    public init(txt: ChampsTXT) {
        sii = txt.entier("sii")
        sai = txt.entier("sai")
        icd = txt.entier("icd")
    }

    /// Endormi (appareil a faible consommation) : ICD annonce, ou repos d'au
    /// moins 5 s. SII seul ne suffit pas : presque tous les appareils Thread
    /// l'annoncent (le pont Halo, alimente, annonce 2000 ; releve du 28/09).
    public var endormi: Bool { icd != nil || (sii ?? 0) >= 5000 }
}
