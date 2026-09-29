import Foundation

/// Types de TLV du diagnostic reseau Thread (`DIAG_GET`) utilises par la sonde.
public enum TypeTLV {
    public static let extMac: UInt8 = 0
    public static let address16: UInt8 = 1
    public static let mode: UInt8 = 2
    public static let route64: UInt8 = 5
    public static let donneesChef: UInt8 = 6
    public static let donneesReseau: UInt8 = 7
    public static let adresses: UInt8 = 8
    public static let tableEnfants: UInt8 = 16
    public static let version: UInt8 = 24
    public static let fabricant: UInt8 = 25
    public static let modele: UInt8 = 26
    public static let versionLogicielle: UInt8 = 27
    public static let pile: UInt8 = 28
}

/// Mode d'un noeud Thread (TLV Mode, octet de mode d'une Child Table).
public struct ModeThread: Hashable, Sendable, Codable {
    public let brut: UInt8

    public init(brut: UInt8) { self.brut = brut }

    /// R : recepteur actif au repos. Faux : appareil endormi, qui ne recoit qu'a son reveil.
    public var recepteurActif: Bool { brut & 0x08 != 0 }
    /// D : appareil Thread complet (il peut devenir routeur).
    public var appareilComplet: Bool { brut & 0x02 != 0 }
    /// N : donnees reseau completes.
    public var donneesCompletes: Bool { brut & 0x01 != 0 }
    public var endormi: Bool { !recepteurActif }
}

/// Un routeur tel que le voit celui qui repond (entree de la TLV Route64).
public struct RouteRouteur: Hashable, Sendable, Codable {
    public let idRouteur: Int
    /// Qualite du lien de celui qui repond vers ce routeur, de 0 (pas voisin) a 3.
    public let qualiteSortante: Int
    /// Qualite du lien de ce routeur vers celui qui repond, de 0 a 3.
    public let qualiteEntrante: Int
    /// Cout de la route (0 : pas de route).
    public let cout: Int

    /// Voisin radio direct : une qualite non nulle dans un sens au moins.
    public var estVoisin: Bool { qualiteSortante > 0 || qualiteEntrante > 0 }
}

/// TLV Route64 : les routeurs actifs de la partition.
public struct Route64: Hashable, Sendable, Codable {
    public let sequence: UInt8
    /// Par identifiant de routeur croissant.
    public let routes: [RouteRouteur]

    public var routeurs: [Int] { routes.map(\.idRouteur) }
    public func route(vers id: Int) -> RouteRouteur? { routes.first { $0.idRouteur == id } }
}

/// TLV Leader Data.
public struct DonneesChef: Hashable, Sendable, Codable {
    /// Identifiant de partition, 8 hexa majuscules.
    public let partition: String
    public let poids: UInt8
    public let version: UInt8
    public let versionStable: UInt8
    public let idChef: Int
}

/// Entree d'une Child Table : un enfant du routeur qui repond.
public struct EntreeEnfant: Hashable, Sendable, Codable {
    public let idEnfant: Int
    /// Qualite du lien de l'enfant vers son parent, de 0 a 3.
    public let qualite: Int
    /// Delai de supervision de l'enfant, en secondes (2^(t-4)).
    public let delai: Int
    public let mode: ModeThread

    /// RLOC16 de l'enfant : identifiant de routeur du parent, puis son numero.
    public func rloc16(parent: UInt16) -> UInt16 { (parent & 0xFC00) | UInt16(idEnfant) }
}

/// Reponse a un `DIAG_GET` : les TLV reconnues, decodees ; les autres ignorees.
/// Une chaine vide (fabricant, modele...) vaut nil.
public struct ReponseDiagnostic: Hashable, Sendable {
    public private(set) var extMac: String?
    public private(set) var rloc16: UInt16?
    public private(set) var mode: ModeThread?
    public private(set) var route64: Route64?
    public private(set) var chef: DonneesChef?
    /// Network Data brutes (TLV 7), decodees par `DonneesReseau`.
    public private(set) var donneesReseau: [UInt8]?
    public private(set) var adresses: [AdresseIPv6] = []
    public private(set) var enfants: [EntreeEnfant]?
    public private(set) var version: Int?
    public private(set) var fabricant: String?
    public private(set) var modele: String?
    public private(set) var versionLogicielle: String?
    public private(set) var pile: String?

    /// TLV en hexa, telles que la sonde les transmet ; nil si l'hexa ou une TLV est tronque.
    public init?(hexa: String) {
        guard let d = Data(hexa: hexa) else { return nil }
        let o = [UInt8](d)
        var i = 0
        while i < o.count {
            guard i + 2 <= o.count, i + 2 + Int(o[i + 1]) <= o.count else { return nil }
            let t = o[i], v = Array(o[(i + 2)..<(i + 2 + Int(o[i + 1]))])
            i += 2 + v.count
            switch t {
            case TypeTLV.extMac where v.count == 8: extMac = Data(v).hexa
            case TypeTLV.address16 where v.count == 2: rloc16 = UInt16(v[0]) << 8 | UInt16(v[1])
            case TypeTLV.mode where v.count == 1: mode = ModeThread(brut: v[0])
            case TypeTLV.route64: route64 = Self.route64(v)
            case TypeTLV.donneesChef where v.count == 8:
                chef = DonneesChef(partition: Data(v[0..<4]).hexa, poids: v[4], version: v[5], versionStable: v[6],
                                   idChef: Int(v[7]))
            case TypeTLV.donneesReseau: donneesReseau = v
            case TypeTLV.adresses:
                adresses = stride(from: 0, to: v.count - 15, by: 16).compactMap { AdresseIPv6(octets: Array(v[$0..<($0 + 16)])) }
            case TypeTLV.tableEnfants: enfants = Self.enfants(v)
            case TypeTLV.version where v.count == 2: version = Int(v[0]) << 8 | Int(v[1])
            case TypeTLV.fabricant: fabricant = Self.texte(v)
            case TypeTLV.modele: modele = Self.texte(v)
            case TypeTLV.versionLogicielle: versionLogicielle = Self.texte(v)
            case TypeTLV.pile: pile = Self.texte(v)
            default: break
            }
        }
    }

    /// Octet de sequence, masque de 64 bits des routeurs actifs, puis un octet par
    /// routeur : qualite sortante (2 bits), entrante (2 bits), cout (4 bits).
    static func route64(_ v: [UInt8]) -> Route64? {
        guard v.count >= 9 else { return nil }
        let masque = v[1...8].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        let ids = (0..<64).filter { masque & (UInt64(1) << (63 - $0)) != 0 }
        guard v.count >= 9 + ids.count else { return nil }
        let routes = ids.enumerated().map { k, id in
            let b = v[9 + k]
            return RouteRouteur(idRouteur: id, qualiteSortante: Int(b >> 6), qualiteEntrante: Int((b >> 4) & 3),
                                cout: Int(b & 0x0F))
        }
        return Route64(sequence: v[0], routes: routes)
    }

    /// Trois octets par enfant : delai (5 bits), qualite (2 bits), numero (9 bits), mode.
    static func enfants(_ v: [UInt8]) -> [EntreeEnfant] {
        stride(from: 0, to: v.count - 2, by: 3).map { k in
            let x = Int(v[k]) << 8 | Int(v[k + 1])
            let t = x >> 11
            return EntreeEnfant(idEnfant: x & 0x1FF, qualite: (x >> 9) & 3, delai: t >= 4 ? 1 << (t - 4) : 0,
                                mode: ModeThread(brut: v[k + 2]))
        }
    }

    static func texte(_ v: [UInt8]) -> String? {
        let s = String(decoding: v, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return s.isEmpty ? nil : s
    }
}
