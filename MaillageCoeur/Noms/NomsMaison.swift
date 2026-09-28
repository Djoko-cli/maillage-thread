import Foundation

/// Issue de la derniere lecture de Maison par le passeur.
public enum StatutPasseur: String, Codable, Hashable, Sendable {
    case ok
    /// L'utilisateur a refuse l'acces a Maison.
    case refuse
    /// HomeKit indisponible : garde pour la compatibilite, le passeur ne
    /// l'ecrit pas aujourd'hui.
    case indisponible
    /// Echec du releve (aucun domicile, Maison sans reponse) ; `message` le detaille.
    case erreur
}

/// Batterie d'un accessoire de Maison : service Batterie de HomeKit, lu par le passeur.
public struct BatterieMaison: Codable, Hashable, Sendable {
    /// `HMCharacteristicTypeChargingState`.
    public enum Charge: String, Codable, Hashable, Sendable {
        case horsCharge
        case enCharge
        case nonRechargeable
    }

    /// Niveau, en %, a partir duquel la batterie est dite faible si
    /// l'accessoire ne le signale pas lui-meme.
    public static let seuilFaible = 20

    /// `HMCharacteristicTypeBatteryLevel`, de 0 a 100 ; absent quand
    /// l'accessoire ne donne que l'alerte.
    public var niveau: Int?
    public var charge: Charge?
    /// `HMCharacteristicTypeStatusLowBattery` : l'accessoire signale lui-meme
    /// sa batterie faible.
    public var alerte: Bool?

    public init(niveau: Int? = nil, charge: Charge? = nil, alerte: Bool? = nil) {
        self.niveau = niveau
        self.charge = charge
        self.alerte = alerte
    }

    private enum CodingKeys: String, CodingKey {
        case niveau, charge, alerte
    }

    /// Un etat de charge inconnu (ecrit par un passeur plus recent que l'app)
    /// est ignore, plutot que de rendre tout `noms.json` illisible.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        niveau = try c.decodeIfPresent(Int.self, forKey: .niveau)
        charge = (try? c.decodeIfPresent(Charge.self, forKey: .charge)) ?? nil
        alerte = try c.decodeIfPresent(Bool.self, forKey: .alerte)
    }

    /// Faible : l'accessoire le signale, ou son niveau est au plus au seuil.
    public var faible: Bool {
        alerte == true || niveau.map { $0 <= Self.seuilFaible } == true
    }

    /// Depuis les valeurs de HomeKit (NSNumber) : niveau de 0 a 100 ; charge
    /// 0 (hors charge), 1 (en charge) ou 2 (non rechargeable) ; alerte 0 ou 1.
    /// Une valeur hors de ces bornes est ignoree ; nil si aucune n'est lisible.
    public static func depuisHomeKit(niveau: Any?, charge: Any?, alerte: Any?) -> BatterieMaison? {
        func entier(_ v: Any?) -> Int? { (v as? NSNumber)?.intValue }
        var b = BatterieMaison()
        if let n = entier(niveau), (0...100).contains(n) { b.niveau = n }
        switch entier(charge) {
        case 0: b.charge = .horsCharge
        case 1: b.charge = .enCharge
        case 2: b.charge = .nonRechargeable
        default: break
        }
        switch entier(alerte) {
        case 0: b.alerte = false
        case 1: b.alerte = true
        default: break
        }
        return b == BatterieMaison() ? nil : b
    }
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
    /// Batterie, pour un accessoire qui en a une (absent des fichiers anciens).
    public var batterie: BatterieMaison?

    public init(nom: String, piece: String? = nil, fabricant: String? = nil, modele: String? = nil,
                firmware: String? = nil, categorie: String? = nil, noeudMatter: String? = nil, pont: Bool? = nil,
                batterie: BatterieMaison? = nil) {
        self.nom = nom
        self.piece = piece
        self.fabricant = fabricant
        self.modele = modele
        self.firmware = firmware
        self.categorie = categorie
        self.noeudMatter = noeudMatter
        self.pont = pont
        self.batterie = batterie
    }

    /// `matterNodeID` en 16 hexa majuscules ; nil pour un accessoire non Matter (absent ou 0).
    public static func noeud(_ id: UInt64?) -> String? {
        guard let id, id != 0 else { return nil }
        return String(format: "%016llX", id)
    }
}

/// Contrat du fichier `noms.json`, ecrit d'un coup par le passeur (app iOS
/// lancee sur le Mac) dans un dossier choisi une fois, sans App Group, et lu
/// par l'app.
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

/// Demande de l'app au passeur, deposee dans le dossier des noms avant de le
/// lancer en arriere-plan : il ecrit `noms.json`, retire la demande et se
/// ferme aussitot, sans compte a rebours. Lance a la main, il n'en trouve pas.
/// (Le passeur se croit toujours au premier plan : il ne peut pas le deviner.)
public struct DemandePasseur: Codable, Hashable, Sendable {
    public static let fichier = "passeur-demande.json"
    /// Au-dela, une demande est un reste (passeur qui ne s'est pas lance) : ignoree.
    public static let validite: TimeInterval = 120

    public var date: Date

    public init(date: Date) {
        self.date = date
    }

    public func estRecente(_ maintenant: Date) -> Bool {
        abs(maintenant.timeIntervalSince(date)) <= Self.validite
    }

    /// Pour le passeur, apres une ecriture reussie (acces au dossier ouvert) :
    /// retire la demande du dossier, quelle qu'elle soit ; vrai si elle est
    /// recente, donc s'il doit se fermer aussitot. Plus ancienne ou illisible,
    /// c'est un reste : le passeur a ete ouvert a la main.
    public static func consommer(dans dossier: URL, maintenant: Date) -> Bool {
        let url = dossier.appendingPathComponent(fichier)
        guard let donnees = try? Data(contentsOf: url) else { return false }
        try? FileManager.default.removeItem(at: url)
        return (try? lire(donnees))?.estRecente(maintenant) == true
    }

    public static func lire(_ donnees: Data) throws -> DemandePasseur {
        try CodageJSON.decodeur().decode(DemandePasseur.self, from: donnees)
    }

    public func donnees() throws -> Data {
        try CodageJSON.encodeur(lisible: true).encode(self)
    }
}
