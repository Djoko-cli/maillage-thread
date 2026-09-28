import Foundation

/// Issue de la derniere lecture de Maison par le passeur.
public enum StatutPasseur: String, Codable, Hashable, Sendable {
    case ok
    /// L'utilisateur a refuse l'acces a Maison.
    case refuse
    /// HomeKit indisponible (capacite absente de la signature).
    case indisponible
    case erreur
}

/// Accessoire de Maison, tel que le passeur le releve.
public struct AccessoireMaison: Codable, Hashable, Sendable {
    public var nom: String
    public var piece: String?
    public var fabricant: String?
    public var modele: String?
    /// `HMAccessory.firmwareVersion` (absent des fichiers anciens).
    public var firmware: String?
    public var categorie: String?
    /// `HMAccessory.matterNodeID` en 16 hexa majuscules : son noeud sur la fabrique d'Apple.
    public var noeudMatter: String?
    /// Accessoire de categorie pont : il donne son nom au noeud qu'il partage
    /// avec les accessoires qu'il porte (absent des fichiers anciens).
    public var pont: Bool?

    public init(nom: String, piece: String? = nil, fabricant: String? = nil, modele: String? = nil,
                firmware: String? = nil, categorie: String? = nil, noeudMatter: String? = nil, pont: Bool? = nil) {
        self.nom = nom
        self.piece = piece
        self.fabricant = fabricant
        self.modele = modele
        self.firmware = firmware
        self.categorie = categorie
        self.noeudMatter = noeudMatter
        self.pont = pont
    }

    /// `matterNodeID` en 16 hexa majuscules ; nil pour un accessoire non Matter (absent ou 0).
    public static func noeud(_ id: UInt64?) -> String? {
        guard let id, id != 0 else { return nil }
        return String(format: "%016llX", id)
    }
}

/// Contrat du fichier `noms.json`, ecrit d'un coup par le passeur (Mac
/// Catalyst) dans le conteneur partage, lu par l'app.
public struct NomsMaison: Codable, Hashable, Sendable {
    public static let versionActuelle = 1

    public var version: Int
    public var date: Date
    public var statut: StatutPasseur
    public var message: String?
    public var domicile: String?
    public var accessoires: [AccessoireMaison]

    public init(version: Int = NomsMaison.versionActuelle, date: Date, statut: StatutPasseur = .ok,
                message: String? = nil, domicile: String? = nil, accessoires: [AccessoireMaison] = []) {
        self.version = version
        self.date = date
        self.statut = statut
        self.message = message
        self.domicile = domicile
        self.accessoires = accessoires
    }

    public enum Erreur: Error, Equatable {
        case versionTropRecente(Int)
    }

    /// Lit `noms.json` ; refuse une version plus recente que celle de l'app.
    public static func lire(_ donnees: Data) throws -> NomsMaison {
        let n = try CodageJSON.decodeur().decode(NomsMaison.self, from: donnees)
        guard n.version <= versionActuelle else { throw Erreur.versionTropRecente(n.version) }
        return n
    }

    public func donnees() throws -> Data {
        try CodageJSON.encodeur(lisible: true).encode(self)
    }
}
