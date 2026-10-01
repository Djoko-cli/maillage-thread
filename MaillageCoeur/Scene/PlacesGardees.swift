import Foundation

/// Places gardees de la vue par pieces (spec de la vue par pieces, section 2.4), dans
/// `positions-pieces.json` : par maison (`domicile` de Maison), l'ordre des etages et, par etage, la
/// place (x, z) de chaque piece deplacee, par rapport au centre du plateau, en unites. Une piece est
/// reconnue par la cle de son etage et la sienne : renommee, ou passee dans un autre etage, elle
/// perd sa place.
public struct PlacesGardees: Hashable, Sendable, Codable {
    public static let versionActuelle = 1

    public struct Place: Hashable, Sendable, Codable {
        public var x: Double
        public var z: Double

        public init(x: Double, z: Double) {
            self.x = x
            self.z = z
        }
    }

    public struct Maison: Hashable, Sendable, Codable {
        /// Cles des etages, du bas vers le haut.
        public var ordreEtages: [String] = []
        /// Cle d'etage -> cle de piece -> place.
        public var etages: [String: [String: Place]] = [:]

        public init(ordreEtages: [String] = [], etages: [String: [String: Place]] = [:]) {
            self.ordreEtages = ordreEtages
            self.etages = etages
        }
    }

    public var version = PlacesGardees.versionActuelle
    /// Par domicile ("" : maison sans nom).
    public var maisons: [String: Maison] = [:]

    public init() {}

    /// Vide si le fichier manque, est illisible, ou d'une version plus recente.
    public static func lire(_ url: URL) -> PlacesGardees {
        guard let d = try? Data(contentsOf: url), let p = try? JSONDecoder().decode(PlacesGardees.self, from: d),
              p.version <= versionActuelle else { return PlacesGardees() }
        return p
    }

    public func ecrire(dans url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try e.encode(self).write(to: url, options: .atomic)
    }

    public func maison(_ domicile: String) -> Maison { maisons[domicile] ?? Maison() }

    /// Garde la place d'une piece deplacee : elle est desormais fixee.
    public mutating func garder(_ place: SIMD2<Double>, piece: String, etage: String, domicile: String) {
        maisons[domicile, default: Maison()].etages[etage, default: [:]][piece] = Place(x: place.x, z: place.y)
    }

    /// Garde l'ordre des etages (cles, du bas vers le haut).
    public mutating func ordonner(_ etages: [String], domicile: String) {
        maisons[domicile, default: Maison()].ordreEtages = etages
    }

    /// « Replacer les pieces automatiquement » : oublie les places de la maison, garde l'ordre des etages.
    public mutating func replacer(domicile: String) {
        maisons[domicile]?.etages = [:]
    }

    /// Pieces fixees d'une scene : indice de piece -> place gardee, pour les pieces qui en ont une dans
    /// leur etage.
    public func fixees(_ scene: ScenePieces, domicile: String) -> [Int: SIMD2<Double>] {
        let m = maison(domicile)
        var r: [Int: SIMD2<Double>] = [:]
        for (i, p) in scene.pieces.enumerated() {
            if let place = m.etages[scene.etages[p.etage].id]?[p.id] { r[i] = SIMD2(place.x, place.z) }
        }
        return r
    }
}
