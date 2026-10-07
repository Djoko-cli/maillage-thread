import Foundation

/// Appareil Matter ou HomeKit sur Thread que l'app connait, a resoudre par la sonde (spec de la sonde tout-en-un,
/// section 2.2) : son adresse sur le prefixe OMR de sa partition.
public struct AppareilAResoudre: Hashable, Sendable {
    /// Identifiant de l'appareil dans l'instantane : son hote, l'ExtMac d'un appareil Matter.
    public let id: String
    public let partition: String
    /// Son adresse sur le prefixe OMR de sa partition, sans zone (`AdresseIPv6`) : la sonde n'accepte que l'adresse nue.
    public let adresse: AdresseIPv6

    public init(id: String, partition: String, adresse: AdresseIPv6) {
        self.id = id
        self.partition = partition
        self.adresse = adresse
    }

    /// Les appareils Thread d'un instantane qui ont une partition et une adresse sur son prefixe OMR, par identifiant.
    /// La tournee garde ceux de la partition de la sonde : la resolution ne traverse pas les partitions.
    public static func depuis(_ i: Instantane) -> [AppareilAResoudre] {
        i.appareils.compactMap { a in
            guard a.genre == .thread, let p = a.partition, let prefixe = a.prefixe,
                  let adresse = a.adresses.first(where: prefixe.contient) else { return nil }
            return AppareilAResoudre(id: a.id, partition: p, adresse: adresse)
        }.sorted { $0.id < $1.id }
    }
}

/// Parent d'un appareil trouve par la resolution d'adresse (spec de la sonde tout-en-un, section 2.2), garde en memoire
/// de la tournee jusqu'a la resolution complete suivante (30 min).
public struct ResolutionAppareil: Hashable, Sendable {
    /// RLOC16 rendu par la sonde : celui du parent (un routeur Apple repond pour son enfant avec le sien), ou celui de
    /// l'enfant (un routeur tiers repond avec celui de l'enfant).
    public let rloc16: UInt16
    /// ML-EID de l'appareil, quand le cache de la sonde le donne : ses compteurs MAC se demandent la (le diagnostic
    /// n'est accepte que sur les adresses internes du reseau). Jamais dans l'historique.
    public let mleid: AdresseIPv6?
    /// L'adresse resolue (sur le prefixe OMR de la partition).
    public let adresse: AdresseIPv6
    public let date: Date
    /// Qualite tiree des compteurs MAC a cette resolution (`QualiteCompteurs`), et le taux d'echec ; nil : inconnue.
    public var qualite: Int?
    public var echecs: Double?

    public init(rloc16: UInt16, mleid: AdresseIPv6?, adresse: AdresseIPv6, date: Date, qualite: Int? = nil,
                echecs: Double? = nil) {
        self.rloc16 = rloc16
        self.mleid = mleid
        self.adresse = adresse
        self.date = date
        self.qualite = qualite
        self.echecs = echecs
    }

    /// Identifiant de routeur du parent : le RLOC16 rendu, sans ses 10 bits de poids faible.
    public var parent: Int { Int(rloc16 >> 10) }
}
