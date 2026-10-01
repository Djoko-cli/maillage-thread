import Foundation

/// Piece d'un routeur de bordure que Maison ne place pas (precisions 23 et 24 du plan 4b) : HomeKit
/// ne donne a une app tierce ni les HomePod ni l'Apple TV, leur annonce n'a donc pas d'accessoire de
/// Maison. Un routeur qui en a un garde sa piece ; pour les autres, dans cet ordre :
/// - **le choix** (« Placer dans une piece… », dans la fiche du routeur), garde par maison
///   (`domicile`) sous l'instance de l'annonce, dans `pieces-routeurs.json` ; un choix dont la piece
///   n'est plus dans Maison ne compte pas ;
/// - **le nom** du routeur, celui qu'affiche l'app (son surnom, sinon son annonce) : la piece de
///   Maison dont le nom y figure, en mots entiers, sans egard a la casse ni aux accents ; le nom de
///   piece le plus long gagne ; si deux pieces ont cette longueur, aucune.
public struct PiecesRouteurs: Hashable, Sendable, Codable {
    public static let versionActuelle = 1

    public var version = PiecesRouteurs.versionActuelle
    /// Par domicile ("" : maison sans nom) : instance de l'annonce -> piece choisie.
    public var maisons: [String: [String: String]] = [:]

    public init() {}

    /// Vide si le fichier manque, est illisible, ou d'une version plus recente.
    public static func lire(_ url: URL) -> PiecesRouteurs {
        guard let d = try? Data(contentsOf: url), let p = try? JSONDecoder().decode(PiecesRouteurs.self, from: d),
              p.version <= versionActuelle else { return PiecesRouteurs() }
        return p
    }

    public func ecrire(dans url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try e.encode(self).write(to: url, options: .atomic)
    }

    /// Piece choisie pour un routeur (son instance) ; nil : la regle du nom.
    public func choix(routeur: String, domicile: String) -> String? {
        maisons[domicile]?[routeur]
    }

    /// Garde le choix d'une piece pour un routeur ; nil revient a la regle du nom.
    public mutating func choisir(_ piece: String?, routeur: String, domicile: String) {
        maisons[domicile, default: [:]][routeur] = piece
        if maisons[domicile]?.isEmpty == true { maisons[domicile] = nil }
    }

    /// Piece d'un routeur que Maison ne place pas : son choix, s'il est encore une piece de la maison,
    /// sinon d'apres son nom ; nil : « Sans piece ».
    public func piece(routeur: String, nom: String, parmi pieces: [String], domicile: String) -> String? {
        if let c = choix(routeur: routeur, domicile: domicile), pieces.contains(c) { return c }
        return Self.piece(nom: nom, parmi: pieces)
    }

    /// Piece d'apres un nom : celle dont les mots se suivent dans les siens ; la plus longue (en
    /// caracteres, sans casse ni accents) ; nil sans piece, ou a egalite entre deux pieces.
    public static func piece(nom: String, parmi pieces: [String]) -> String? {
        let motsNom = mots(nom)
        var meilleure: (piece: String, longueur: Int)?
        var egalite = false
        for p in pieces {
            let m = mots(p)
            guard !m.isEmpty, contient(motsNom, m) else { continue }
            let longueur = m.joined(separator: " ").count
            if let b = meilleure, b.longueur > longueur { continue }
            if let b = meilleure, b.longueur == longueur {
                if b.piece != p { egalite = true }
                continue
            }
            meilleure = (p, longueur)
            egalite = false
        }
        return egalite ? nil : meilleure?.piece
    }

    /// Pieces de Maison : celles des accessoires et celles des zones, sans doublon, par nom.
    public static func pieces(de maison: NomsMaison?) -> [String] {
        guard let maison else { return [] }
        var toutes = Set(maison.accessoires.compactMap(\.piece))
        for z in maison.zones ?? [] { toutes.formUnion(z.pieces) }
        return toutes.filter { !$0.isEmpty }.sorted()
    }

    /// Mots d'un nom : suites de lettres ou de chiffres, sans casse ni accents (« Chambre d'amis » :
    /// chambre, d, amis).
    static func mots(_ s: String) -> [String] {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// Les mots `m` se suivent dans `nom`.
    private static func contient(_ nom: [String], _ m: [String]) -> Bool {
        guard m.count <= nom.count else { return false }
        return (0...(nom.count - m.count)).contains { Array(nom[$0..<($0 + m.count)]) == m }
    }
}
