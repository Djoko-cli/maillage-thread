import Foundation

/// Nom affiche d'un noeud, par priorite : surnom (donne dans l'app) > nom dans
/// Maison (noeud sur la fabrique d'Apple) > nom HomeKit (`_hap._udp`) > hote.
public struct ResolveurNoms: Hashable, Sendable {
    /// Identifiant de noeud (appareil ou instance de routeur) -> surnom.
    public var surnoms: [String: String]
    public var maison: NomsMaison?

    public init(surnoms: [String: String] = [:], maison: NomsMaison? = nil) {
        self.surnoms = surnoms
        self.maison = maison
    }

    /// Noeud a 0 : accessoire non Matter, il n'identifie personne.
    static let noeudNul = "0000000000000000"

    /// Fabrique d'Apple : celle dont les noeuds recouvrent le plus de
    /// `noeudMatter` de Maison (au moins un) ; a egalite, la plus petite.
    public func fabriqueApple(appareils: [Appareil]) -> String? {
        let connus = Set(maison?.accessoires.compactMap { $0.noeudMatter?.uppercased() } ?? []).subtracting([Self.noeudNul])
        guard !connus.isEmpty else { return nil }
        var scores: [String: Int] = [:]
        for a in appareils {
            for i in a.instances where connus.contains(i.noeud) { scores[i.fabrique, default: 0] += 1 }
        }
        return scores.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }

    /// Accessoire de Maison d'un appareil (par son noeud sur la fabrique d'Apple).
    /// Un pont porte plusieurs accessoires sur un seul noeud : le noeud prend
    /// le nom du pont (du premier par nom s'il y en a plusieurs), sinon du
    /// premier accessoire par nom ; l'ordre du fichier ne compte pas.
    public func accessoire(de a: Appareil, fabriqueApple f: String?) -> AccessoireMaison? {
        guard let f, let maison, let noeud = a.instances.first(where: { $0.fabrique == f })?.noeud,
              noeud != Self.noeudNul else { return nil }
        let candidats = maison.accessoires.filter { $0.noeudMatter?.uppercased() == noeud }
        return candidats.filter { $0.pont == true }.min { $0.nom < $1.nom } ?? candidats.min { $0.nom < $1.nom }
    }

    public func nom(appareil a: Appareil, fabriqueApple f: String?) -> String {
        if let s = surnoms[a.id], !s.isEmpty { return s }
        if let m = accessoire(de: a, fabriqueApple: f)?.nom, !m.isEmpty { return m }
        if let h = a.hap?.nom, !h.isEmpty { return h }
        return a.id
    }

    public func nom(routeur r: RouteurBordure) -> String {
        if let s = surnoms[r.instance], !s.isEmpty { return s }
        return r.instance
    }
}

/// Surnoms donnes dans l'app ("Renommer..."), gardes dans un fichier JSON.
public enum Surnoms {
    /// Vide si le fichier manque ou est illisible (`FichiersGardes`).
    public static func lire(_ url: URL) -> [String: String] {
        FichiersGardes.lire([String: String].self, url) ?? [:]
    }

    /// Un fichier illisible est d'abord mis de cote (`FichiersGardes`).
    public static func ecrire(_ surnoms: [String: String], dans url: URL) throws {
        try FichiersGardes.ecrire(surnoms, dans: url)
    }
}
