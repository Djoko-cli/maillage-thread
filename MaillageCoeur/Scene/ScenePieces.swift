import Foundation

/// Scene de la vue par pieces, sans geometrie (spec de la vue par pieces, section 2) : les
/// etages, les pieces qui ont au moins un noeud, les noeuds et les liens.
///
/// - Etages : les zones de Maison, dans leur ordre (le premier en bas) ; une piece dans plusieurs
///   zones va dans la premiere ; deux zones du meme nom n'en font qu'une, a la place de la premiere ;
///   les pieces hors zone forment « Autres pieces ». Sans zones (ou fichier d'avant les zones), un seul
///   plateau « Maison ». Un ordre garde passe avant.
/// - Niveaux (polissage C, section 1) : un plateau est un etage, ou une zone a cote d'un etage, dont elle
///   partage le niveau (`Niveaux`, d'apres les choix gardes). Les plateaux sont ranges niveau par niveau,
///   du bas vers le haut, et dans un niveau l'etage principal d'abord, puis ses zones a cote : l'ordre des
///   plateaux en 2D. Avec des etages seulement, c'est l'ordre garde.
/// - Pieces : celles de Maison (le champ `piece` de l'accessoire du noeud) ; un noeud sans piece va
///   dans « Sans piece », sur le plateau du bas. Sans aucune piece dans Maison, un seul plateau
///   « Maison » et une carte par routeur, avec ses enfants (parents vus par la sonde).
/// - Teinte d'une piece : dans chaque etage, les pieces rangees par nom prennent chacune la teinte
///   d'indice FNV-1a 32 bits de leur nom, modulo 8, ou la suivante libre dans l'etage. La carte d'un
///   routeur est rangee et teintee d'apres l'id du routeur, qui ne change pas avec son libelle.
/// - Noeuds d'une carte : le chef, les routeurs de bordure, les autres routeurs, les autres
///   noeuds ; par libelle dans chaque groupe. Rayon naturel : 15 px pour le centre d'une
///   partition, 13 pour un autre routeur de bordure, 8 pour un autre routeur, 7 sinon.
public struct ScenePieces: Hashable, Sendable {
    public enum NomEtage: Hashable, Sendable {
        /// Zone de Maison.
        case zone(String)
        /// Pieces hors de toute zone.
        case autresPieces
        /// Plateau unique : maison sans zones, ou sans pieces.
        case maison

        /// Cle de l'etage (ordre garde, places gardees).
        public var cle: String {
            switch self {
            case .zone(let n): "zone:" + n
            case .autresPieces: "autres-pieces"
            case .maison: "maison"
            }
        }
    }

    public enum NomPiece: Hashable, Sendable {
        /// Piece de Maison.
        case maison(String)
        /// Carte d'un routeur et de ses enfants (maison sans pieces), par l'id du routeur.
        case routeur(String)
        /// Noeuds sans piece.
        case sansPiece

        /// Cle de la piece (places gardees).
        public var cle: String {
            switch self {
            case .maison(let n): "piece:" + n
            case .routeur(let id): "routeur:" + id
            case .sansPiece: "sans-piece"
            }
        }
    }

    public struct Etage: Hashable, Sendable, Identifiable {
        public var nom: NomEtage
        /// Indices de ses pieces, par nom.
        public var pieces: [Int]
        /// Son niveau (0 en bas) ; un etage principal, ou une zone a cote de lui ; hors de la maison.
        public var niveau: Int
        public var principal: Bool
        public var dehors: Bool

        public var id: String { nom.cle }
    }

    public struct Piece: Hashable, Sendable, Identifiable {
        public var nom: NomPiece
        public var etage: Int
        /// Indice de sa teinte dans `ScenePieces.teintes`.
        public var teinte: Int
        /// Ses noeuds, dans l'ordre des lignes de sa carte.
        public var noeuds: [String]

        public var id: String { nom.cle }
    }

    public struct Noeud: Hashable, Sendable, Identifiable {
        public var id: String
        /// Nom affiche, avec la couronne, la lune et l'alerte ; deja coupe (`CartesPieces.couper`).
        public var libelle: String
        public var genre: GrapheReseau.Genre
        public var partition: String
        public var routeur: Bool
        public var bordure: Bool
        public var inconnu: Bool
        public var chef: Bool
        /// Rang dans sa carte : 0 chef, 1 routeur de bordure, 2 autre routeur, 3 autre noeud.
        public var rang: Int
        /// Rayon naturel de sa pastille (px).
        public var rayon: Double
        public var piece: Int
    }

    public typealias Lien = GrapheReseau.Lien

    /// Palette des pieces : 8 teintes (spec, section 2.2).
    public static let teintes: [UInt32] = [0x3B82F5, 0x22C55E, 0xF59E0B, 0x94A3B8, 0xA855F7, 0x06B6D4, 0xEC4899, 0x818CF8]
    /// Nom de la carte « Sans piece » pour le rang et la teinte : le meme dans toutes les langues.
    public static let nomSansPiece = "Sans pièce"

    public private(set) var etages: [Etage] = []
    public private(set) var pieces: [Piece] = []
    public private(set) var noeuds: [Noeud] = []
    public private(set) var liens: [Lien] = []
    /// Les niveaux de ses plateaux (polissage C, section 1).
    public private(set) var niveaux: Niveaux
    /// Maison n'a encore aucune piece : cartes par routeur, et le bandeau du passeur.
    public private(set) var sansPiecesMaison: Bool
    private var indices: [String: Int] = [:]

    /// `libelles` : nom affiche de chaque noeud (son id a defaut) ; `piecesNoeuds` : piece de Maison
    /// de chaque noeud qui en a une ; `zones` : celles de Maison (nil : fichier d'avant les zones) ;
    /// `chefs` : noeuds couronnes ; `piecesMaison` : Maison a au moins une piece ; `ordreEtages` :
    /// cles des etages dans l'ordre garde, du bas vers le haut ; `aCote` : les choix de niveau gardes.
    public init(graphe: GrapheReseau, libelles: [String: String], piecesNoeuds: [String: String],
                zones: [ZoneMaison]?, chefs: Set<String>, piecesMaison: Bool, ordreEtages: [String] = [],
                aCote: [String: PlacesGardees.ACote] = [:]) {
        sansPiecesMaison = !piecesMaison
        func libelle(_ id: String) -> String { libelles[id] ?? id }
        // Piece de chaque noeud.
        var nomPiece: [String: NomPiece] = [:]
        for n in graphe.noeuds {
            if piecesMaison {
                if let p = piecesNoeuds[n.id], !p.isEmpty {
                    nomPiece[n.id] = .maison(p)
                } else {
                    nomPiece[n.id] = .sansPiece
                }
            } else if n.routeur {
                nomPiece[n.id] = .routeur(n.id)
            } else if let p = graphe.parent(de: n.id), graphe.noeud(p)?.routeur == true {
                nomPiece[n.id] = .routeur(p)
            } else {
                nomPiece[n.id] = .sansPiece
            }
        }
        // Etages : les zones qui ont une piece montree, puis « Autres pieces » ; sinon « Maison ».
        let montrees = Set(nomPiece.values.compactMap { p -> String? in
            if case .maison(let n) = p { return n }
            return nil
        })
        var noms: [NomEtage] = []
        var etageDe: [String: Int] = [:]
        if piecesMaison, let zones, !zones.isEmpty {
            // Zones du meme nom (inattendu) : une seule, a la place de la premiere, avec les pieces de toutes.
            var fusionnees: [ZoneMaison] = []
            for z in zones {
                if let k = fusionnees.firstIndex(where: { $0.nom == z.nom }) {
                    fusionnees[k].pieces += z.pieces
                } else {
                    fusionnees.append(z)
                }
            }
            var restantes = montrees
            for z in fusionnees {
                let dedans = z.pieces.filter { restantes.contains($0) }
                guard !dedans.isEmpty else { continue }
                for p in dedans {
                    etageDe[p] = noms.count
                    restantes.remove(p)
                }
                noms.append(.zone(z.nom))
            }
            if !restantes.isEmpty {
                for p in restantes { etageDe[p] = noms.count }
                noms.append(.autresPieces)
            }
        }
        if noms.isEmpty { noms = [.maison] }
        // Ordre garde d'abord ; un etage qu'il ne connait pas garde son rang, au-dessus. Puis les niveaux :
        // chaque zone a cote rejoint son etage principal.
        let rang = Dictionary(ordreEtages.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let garde = noms.indices.sorted {
            (rang[noms[$0].cle] ?? Int.max, $0) < (rang[noms[$1].cle] ?? Int.max, $1)
        }
        let n = Niveaux(garde.map { noms[$0].cle }, aCote: aCote)
        let indiceNom = Dictionary(uniqueKeysWithValues: noms.indices.map { (noms[$0].cle, $0) })
        let ordre = n.plateaux.compactMap { indiceNom[$0] }
        let nouveau = Dictionary(uniqueKeysWithValues: ordre.enumerated().map { ($1, $0) })
        niveaux = n
        etages = ordre.map { i in
            let c = noms[i].cle
            return Etage(nom: noms[i], pieces: [], niveau: n.niveau(c) ?? 0, principal: n.estPrincipal(c),
                         dehors: n.dehors(c))
        }
        func etage(_ p: NomPiece) -> Int {
            if case .maison(let n) = p, let e = etageDe[n] { return nouveau[e] ?? 0 }
            return 0
        }
        // Carte d'un routeur : son id, stable, et non son libelle, que changent la couronne, ☾ et ⚠︎.
        func nomTri(_ p: NomPiece) -> String {
            switch p {
            case .maison(let n): n
            case .routeur(let id): id
            case .sansPiece: Self.nomSansPiece
            }
        }
        // Pieces, etage par etage, par nom ; teintes.
        let distinctes = Set(nomPiece.values)
        for e in etages.indices {
            let ici = distinctes.filter { etage($0) == e }.sorted { (nomTri($0), $0.cle) < (nomTri($1), $1.cle) }
            var prises = Set<Int>()
            for p in ici {
                var t = Int(Self.fnv1a(nomTri(p)) % 8)
                if prises.count < 8 {
                    while prises.contains(t) { t = (t + 1) % 8 }
                }
                prises.insert(t)
                etages[e].pieces.append(pieces.count)
                pieces.append(Piece(nom: p, etage: e, teinte: t, noeuds: []))
            }
        }
        let indicePiece = Dictionary(uniqueKeysWithValues: pieces.enumerated().map { ($1.nom, $0) })
        // Noeuds, puis les lignes de chaque carte.
        for n in graphe.noeuds {
            guard let p = nomPiece[n.id].flatMap({ indicePiece[$0] }) else { continue }
            let chef = chefs.contains(n.id)
            let rang = chef ? 0 : n.bordure ? 1 : n.routeur ? 2 : 3
            let rayon: Double = n.genre == .centre ? 15 : n.bordure ? 13 : n.routeur ? 8 : 7
            indices[n.id] = noeuds.count
            noeuds.append(Noeud(id: n.id, libelle: libelle(n.id), genre: n.genre, partition: n.partition,
                                routeur: n.routeur, bordure: n.bordure, inconnu: n.inconnu, chef: chef, rang: rang,
                                rayon: rayon, piece: p))
        }
        for i in pieces.indices {
            pieces[i].noeuds = noeuds.filter { $0.piece == i }
                .sorted { ($0.rang, $0.libelle, $0.id) < ($1.rang, $1.libelle, $1.id) }
                .map(\.id)
        }
        liens = graphe.liens
    }

    public func noeud(_ id: String) -> Noeud? { indices[id].map { noeuds[$0] } }

    /// Indice d'un noeud dans `noeuds`.
    public func indice(_ id: String) -> Int? { indices[id] }

    /// FNV-1a sur 32 bits, du nom en UTF-8.
    public static func fnv1a(_ nom: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for b in nom.utf8 {
            h ^= UInt32(b)
            h = h &* 16_777_619
        }
        return h
    }
}
