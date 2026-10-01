import Foundation

/// Places gardees de la vue par pieces (spec de la vue par pieces, section 2.4), dans
/// `positions-pieces.json` : par maison (`domicile` de Maison), l'ordre des etages et, par etage, la
/// place (x, z) de chaque piece deplacee, par rapport au centre du plateau, en unites. Une piece est
/// reconnue par la cle de son etage et la sienne : renommee, ou passee dans un autre etage, elle
/// perd sa place.
public struct PlacesGardees: Hashable, Sendable, Codable {
    public static let versionActuelle = 1
    /// Distance au centre de son plateau au-dela de laquelle une place gardee est ignoree (unites) : elle
    /// vient d'un fichier abime ou edite a la main, un glisser restant dans le plateau. Un plateau fait
    /// quelques dizaines d'unites (24 px chacune) ; la borne laisse deux ordres de grandeur de marge, et
    /// les carres des calculs (1e8) restent loin de tout debordement.
    public static let borne = 10_000.0

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

    /// Vide si le fichier manque, est illisible, ou d'une version plus recente (`FichiersGardes`).
    public static func lire(_ url: URL) -> PlacesGardees {
        FichiersGardes.lire(PlacesGardees.self, url, version: versionActuelle) ?? PlacesGardees()
    }

    /// Rien n'est ecrit sur un fichier d'une version plus recente ; un fichier illisible est d'abord mis
    /// de cote (`FichiersGardes`).
    public func ecrire(dans url: URL) throws {
        try FichiersGardes.ecrire(self, dans: url, version: Self.versionActuelle)
    }

    public func maison(_ domicile: String) -> Maison { maisons[domicile] ?? Maison() }

    /// Garde la place d'une piece deplacee : elle est desormais fixee. Une place non finie (camera
    /// degeneree pendant un glisser) est refusee : JSON ne l'ecrit pas, et `ecrire` echouerait ensuite
    /// a chaque appel.
    public mutating func garder(_ place: SIMD2<Double>, piece: String, etage: String, domicile: String) {
        guard place.x.isFinite, place.y.isFinite else { return }
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
    /// leur etage. Une place non finie, ou a plus de `borne` du centre, est ignoree : la piece est libre.
    public func fixees(_ scene: ScenePieces, domicile: String) -> [Int: SIMD2<Double>] {
        let m = maison(domicile)
        var r: [Int: SIMD2<Double>] = [:]
        for (i, p) in scene.pieces.enumerated() {
            if let place = m.etages[scene.etages[p.etage].id]?[p.id], place.x.isFinite, place.z.isFinite,
               hypot(place.x, place.z) <= Self.borne {
                r[i] = SIMD2(place.x, place.z)
            }
        }
        return r
    }
}
