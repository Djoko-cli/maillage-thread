import Foundation

/// Protocole USB de la sonde, v1 (spec de la sonde, section 3) : une commande
/// texte par ligne vers la sonde ; en retour, des lignes machine RS (0x1E),
/// JSON compact en ASCII, LF, 4096 octets au plus, `v` et `t` en tete.
public enum ProtocoleSonde {
    public static let separateur: UInt8 = 0x1E
    public static let longueurMax = 4096
    /// `bonjour.produit` d'une sonde : tout autre port est refuse.
    public static let produit = "sonde-maillage"
}

/// Reponse a `bonjour`.
public struct Bonjour: Hashable, Sendable, Codable {
    public let produit: String
    public let version: String
    /// Nom de la sonde, garde par la carte (« SONDE-01 » par defaut) ; firmware 1.0.1 et suivants.
    public let nom: String?
    public let mac: String?
    public let appairee: Bool
    /// Code d'appairage manuel : toujours (firmware 1.0.1 et suivants), avant seulement tant
    /// que la sonde n'etait pas dans Maison.
    public let code: String?
    /// Charge du QR code Matter (« MT:... »), comme `code`.
    public let qr: String?

    public var estSonde: Bool { produit == ProtocoleSonde.produit }
}

/// Parent de la sonde, tel qu'elle le voit.
public struct ParentSonde: Hashable, Sendable, Codable {
    public let rloc16: String
    public let ext: String
    public let lqIn: Int
    public let lqOut: Int
    public let rssi: Int
}

/// Reponse a `etat`.
public struct EtatSonde: Hashable, Sendable, Codable {
    public let role: String
    public let rloc16: String
    /// ExtMac de la sonde (firmware 1.0.0 et suivants) : la sonde se retrouve dans l'instantane.
    public let ext: String?
    public let mode: String?
    public let parent: ParentSonde?
    public let partition: String?
    /// Identifiant de routeur du chef.
    public let chef: Int?
    public let canal: Int?
    /// Prefixe du reseau maille, 16 hexa.
    public let prefixeMaille: String?
    public let xp: String?
    public let suspendue: Bool

    /// Attachee au reseau : enfant, routeur ou chef.
    public var estAttachee: Bool { ["child", "router", "leader"].contains(role) && partition != nil && chef != nil }
    public var rloc16Valeur: UInt16? { UInt16(rloc16, radix: 16) }
}

/// Voisin entendu par la sonde (son parent, pour un MED).
public struct VoisinSonde: Hashable, Sendable, Codable {
    public let rloc16: String
    public let ext: String
    public let rssi: Int
    public let lqi: Int
    public let routeur: Bool
}

/// Reponse a `diag` : les TLV en hexa, ou l'erreur (`delai`, `suspendue`, `occupee`, `envoi`...).
public struct ResultatDiag: Hashable, Sendable, Codable {
    public let id: Int
    public let cible: String
    public let ok: Bool
    public let ms: Int?
    public let code: String?
    public let tlv: String?
    public let erreur: String?

    public init(id: Int, cible: String, ok: Bool, ms: Int? = nil, code: String? = nil, tlv: String? = nil,
                erreur: String? = nil) {
        self.id = id
        self.cible = cible
        self.ok = ok
        self.ms = ms
        self.code = code
        self.tlv = tlv
        self.erreur = erreur
    }

    /// TLV decodees d'une reponse reussie.
    public var reponse: ReponseDiagnostic? { ok ? tlv.flatMap { ReponseDiagnostic(hexa: $0) } : nil }
}

/// Message d'une ligne machine.
public enum MessageSonde: Hashable, Sendable {
    case bonjour(Bonjour)
    case etat(EtatSonde)
    case voisins([VoisinSonde])
    case diag(ResultatDiag)
    case erreur(String)
    /// Type inconnu (version plus recente de la sonde) : ignore.
    case inconnu(String)

    private struct Entete: Decodable {
        let v: Int
        let t: String
    }

    private struct Voisins: Decodable {
        let liste: [VoisinSonde]
    }

    private struct Erreur: Decodable {
        let erreur: String
    }

    /// JSON d'une ligne machine, sans RS ni LF ; nil si illisible ou d'une autre version.
    public static func lire(_ json: Data) -> MessageSonde? {
        let d = JSONDecoder()
        guard let e = try? d.decode(Entete.self, from: json), e.v == 1 else { return nil }
        switch e.t {
        case "bonjour": return (try? d.decode(Bonjour.self, from: json)).map { .bonjour($0) }
        case "etat": return (try? d.decode(EtatSonde.self, from: json)).map { .etat($0) }
        case "voisins": return (try? d.decode(Voisins.self, from: json)).map { .voisins($0.liste) }
        case "diag": return (try? d.decode(ResultatDiag.self, from: json)).map { .diag($0) }
        case "erreur": return (try? d.decode(Erreur.self, from: json)).map { .erreur($0.erreur) }
        default: return .inconnu(e.t)
        }
    }
}

/// Commande envoyee a la sonde.
public enum CommandeSonde: Hashable, Sendable {
    case bonjour
    case etat
    case voisins
    /// `diag <RLOC16> <t,t,...> <id> [<delai ms>]`
    case diag(cible: UInt16, tlv: [UInt8], id: Int, delaiMs: Int?)

    /// Ligne a envoyer, fin de ligne comprise.
    public var ligne: String {
        switch self {
        case .bonjour: return "bonjour\n"
        case .etat: return "etat\n"
        case .voisins: return "voisins\n"
        case .diag(let cible, let tlv, let id, let delai):
            var l = String(format: "diag %04X ", cible) + tlv.map(String.init).joined(separator: ",") + " \(id)"
            if let delai { l += " \(delai)" }
            return l + "\n"
        }
    }
}

/// Decoupe le flux USB en lignes machine (RS ... LF), sans le RS ; le reste
/// (journaux de la pile, lignes humaines) est ignore, comme une ligne trop longue.
/// La ligne machine commence au dernier RS de la ligne, comme dans le pont Halo : ce qui le
/// precede (queue d'un journal sans fin de ligne, invite, ligne machine coupee) est abandonne.
public struct DecoupeurLignes: Sendable {
    private var tampon: [UInt8] = []
    private var tropLongue = false

    public init() {}

    public mutating func ajouter(_ d: Data) -> [Data] {
        var lignes: [Data] = []
        for o in d {
            if o == ProtocoleSonde.separateur {
                // Le JSON est de l'ASCII imprimable, sans RS : un RS ouvre toujours une ligne machine.
                tampon.removeAll(keepingCapacity: true)
                tampon.append(o)
                tropLongue = false
            } else if o == 0x0A {
                if !tropLongue, tampon.first == ProtocoleSonde.separateur {
                    var l = tampon.dropFirst()
                    if l.last == 0x0D { l = l.dropLast() }
                    lignes.append(Data(l))
                }
                tampon.removeAll(keepingCapacity: true)
                tropLongue = false
            } else if tampon.count < ProtocoleSonde.longueurMax {
                tampon.append(o)
            } else {
                tropLongue = true
            }
        }
        return lignes
    }
}
