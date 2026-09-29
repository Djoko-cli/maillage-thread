import Foundation

/// Point du plan du graphe (unites libres ; y vers le bas, comme a l'ecran).
public struct Point2D: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public func distance(_ p: Point2D) -> Double { hypot(x - p.x, y - p.y) }
}

/// Etat d'un appareil tel que le graphe le montre.
public enum EtatAffiche: String, Hashable, Sendable {
    case joignable, partitionCoupee, sansAdresse, disparu, inconnu
}

/// Appareil a dessiner : nom deja choisi, partition courante ou derniere connue.
public struct AppareilAffiche: Hashable, Sendable, Identifiable {
    public var id: String
    public var nom: String
    public var piece: String?
    public var partition: String?
    public var etat: EtatAffiche
    public var endormi: Bool
    /// Batterie selon Maison, pour un appareil qui en a une.
    public var batterie: BatterieMaison?

    public init(id: String, nom: String, piece: String? = nil, partition: String?, etat: EtatAffiche,
                endormi: Bool = false, batterie: BatterieMaison? = nil) {
        self.id = id
        self.nom = nom
        self.piece = piece
        self.partition = partition
        self.etat = etat
        self.endormi = endormi
        self.batterie = batterie
    }
}

/// Disposition stable du graphe d'un reseau : memes noeuds, memes positions.
/// Une zone par partition (la principale au centre, les autres en colonne a sa
/// droite) ; dans une zone : le centre (chef, sinon BBR primaire), les autres
/// routeurs sur un anneau interieur, les appareils sur un anneau exterieur
/// (tries par piece puis par nom), et un lien de chaque noeud vers le centre
/// (rattachement, pas un lien radio). Les appareils sans partition connue vont
/// dans une zone sans centre, sous la principale.
///
/// Avec la sonde, dans sa partition : les appareils qui routent et les routeurs
/// inconnus rejoignent l'anneau interieur, les enfants se rangent pres de leur
/// parent, et les liens sont ceux de la sonde (radio entre routeurs, enfant vers
/// parent) ; un noeud sans lien connu garde son rattachement. Un seul noeud par
/// routeur : l'annonce candidate d'un routeur de bordure non identifie n'est pas
/// dessinee a part, ce routeur la porte (`MaillageAffiche.annoncesCandidates`) ; le
/// centre reste le centre, candidat ou non.
public struct Disposition: Hashable, Sendable {
    public enum Genre: String, Hashable, Sendable {
        case centre, routeur, appareil
    }

    public struct Zone: Hashable, Sendable, Identifiable {
        /// Identifiant de la partition ; "" pour les appareils sans partition connue.
        public var id: String
        public var centre: Point2D
        public var rayon: Double
        public var principale: Bool
        /// Prefixes attribues a la partition.
        public var prefixes: [PrefixeIPv6]
        /// Prefixes partages de la partition (`Partition.prefixesPartages`).
        public var prefixesPartages: [PrefixeIPv6]

        /// Prefixes du titre : ceux de la partition, plus les partages qu'elle
        /// revendique sans les avoir eus ; tries.
        public var prefixesTitre: [PrefixeIPv6] { Set(prefixes + prefixesPartages).sorted() }
    }

    public struct Noeud: Hashable, Sendable, Identifiable {
        /// Instance du routeur ou identifiant de l'appareil.
        public var id: String
        public var genre: Genre
        public var zone: String
        public var position: Point2D
        public var rayon: Double
    }

    public struct Lien: Hashable, Sendable {
        public enum Genre: String, Hashable, Sendable {
            /// Pointille vers le centre : rattachement suppose, pas un lien radio.
            case rattachement
            /// Lien radio entre deux routeurs, vu par la sonde.
            case radio
            /// De l'enfant vers son parent, vu par la sonde.
            case parent
        }

        public var de: String
        public var vers: String
        public var genre: Genre = .rattachement
        /// De 0 a 3 ; nil : inconnue.
        public var qualite: Int?
    }

    public static let rayonInterieur = 90.0
    public static let rayonExterieurMin = 170.0
    /// Arc minimal entre deux appareils voisins sur l'anneau.
    public static let arcAppareil = 36.0
    public static let marge = 40.0
    public static let ecart = 60.0
    public static let rayonZoneSeule = 60.0

    public private(set) var zones: [Zone] = []
    public private(set) var noeuds: [Noeud] = []
    public private(set) var liens: [Lien] = []

    public init(reseau: Reseau, appareils: [AppareilAffiche], maillage: MaillageAffiche? = nil) {
        let connues = Set(reseau.partitions.map(\.id))
        let parZone = Dictionary(grouping: appareils) { a in
            a.partition.flatMap { connues.contains($0) ? $0 : nil } ?? ""
        }
        func tries(_ l: [AppareilAffiche]) -> [AppareilAffiche] {
            l.sorted { ($0.piece ?? "\u{10FFFF}", $0.nom, $0.id) < ($1.piece ?? "\u{10FFFF}", $1.nom, $1.id) }
        }
        func rayonAppareils(_ n: Int) -> Double {
            max(Self.rayonExterieurMin, Double(n) * Self.arcAppareil / (2 * .pi))
        }
        func rayonZone(_ routeurs: Int, _ apps: Int) -> Double {
            if apps == 0 { return routeurs <= 1 ? Self.rayonZoneSeule : Self.rayonInterieur + Self.marge }
            return rayonAppareils(apps) + Self.marge
        }

        // Anneaux de chaque zone : routeurs (hors centre) a l'interieur, appareils a l'exterieur.
        struct Anneaux {
            var interieur: [(id: String, genre: Genre, rayon: Double)] = []
            var exterieur: [String] = []
            var sonde: MaillageAffiche?
        }
        let anneaux = reseau.partitions.map { p -> Anneaux in
            let apps = tries(parZone[p.id] ?? [])
            var a = Anneaux()
            let sonde = maillage.flatMap { $0.partition == p.id ? $0 : nil }
            a.interieur = p.routeurs.dropFirst().filter { sonde?.annoncesCandidates.contains($0.instance) != true }
                .map { ($0.instance, Genre.routeur, 15.0) }
            guard let m = sonde else {
                a.exterieur = apps.map(\.id)
                return a
            }
            a.sonde = m
            let routeurs = m.idsRouteurs
            a.interieur += apps.filter { routeurs.contains($0.id) }.map { ($0.id, Genre.appareil, 9.0) }
            a.interieur += m.inconnus.filter { $0.genre == .routeur }.map { ($0.id, Genre.routeur, 12.0) }
            a.exterieur = apps.filter { !routeurs.contains($0.id) }.map(\.id) + m.inconnus.filter { $0.genre == .enfant }.map(\.id)
            return a
        }

        // Rayons, puis centres : la principale en (0, 0), les autres en colonne a droite.
        let rayons = zip(reseau.partitions, anneaux).map { rayonZone($0.routeurs.count, $1.exterieur.count) }
        let r0 = rayons.first ?? Self.rayonZoneSeule
        let secondaires = Array(rayons.dropFirst())
        var y = -(secondaires.reduce(0) { $0 + 2 * $1 } + Self.ecart * Double(max(secondaires.count - 1, 0))) / 2
        var centres = [Point2D(0, 0)]
        for r in secondaires {
            centres.append(Point2D(r0 + Self.ecart + r, y + r))
            y += 2 * r + Self.ecart
        }

        for (k, p) in reseau.partitions.enumerated() {
            let centre = centres[k]
            zones.append(Zone(id: p.id, centre: centre, rayon: rayons[k], principale: p.estPrincipale, prefixes: p.prefixes,
                              prefixesPartages: p.prefixesPartages))
            guard let premier = p.routeurs.first else { continue }
            noeuds.append(Noeud(id: premier.instance, genre: .centre, zone: p.id, position: centre, rayon: 22))
            let a = anneaux[k]
            var positions = [premier.instance: centre]
            for (i, r) in a.interieur.enumerated() {
                let pos = Self.surAnneau(centre, Self.rayonInterieur, i, a.interieur.count)
                positions[r.id] = pos
                noeuds.append(Noeud(id: r.id, genre: r.genre, zone: p.id, position: pos, rayon: r.rayon))
            }
            // Avec la sonde, chaque enfant pres de son parent : par angle du parent, puis dans l'ordre des appareils.
            var exterieur = a.exterieur
            if let m = a.sonde {
                // Les enfants du centre en fin d'anneau : ils ne se melent pas a ceux du premier routeur.
                func angle(_ id: String) -> Double {
                    guard let pere = m.parent(de: id), let pos = positions[pere] else { return 10 }
                    if pere == premier.instance { return 3 * .pi / 2 }
                    let t = atan2(pos.y - centre.y, pos.x - centre.x)
                    return t < -.pi / 2 ? t + 2 * .pi : t
                }
                let rang = Dictionary(exterieur.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
                exterieur.sort { (angle($0), rang[$0] ?? 0) < (angle($1), rang[$1] ?? 0) }
            }
            for (j, id) in exterieur.enumerated() {
                let pos = Self.surAnneau(centre, rayonAppareils(exterieur.count), j, exterieur.count)
                positions[id] = pos
                noeuds.append(Noeud(id: id, genre: .appareil, zone: p.id, position: pos, rayon: 7))
            }
            // Liens : ceux de la sonde entre noeuds de la zone ; le rattachement au centre pour les autres.
            var relies: Set<String> = [premier.instance]
            for l in a.sonde?.liens ?? [] where positions[l.de] != nil && positions[l.vers] != nil {
                liens.append(Lien(de: l.de, vers: l.vers, genre: l.genre == .radio ? .radio : .parent, qualite: l.qualite))
                relies.insert(l.de)
                relies.insert(l.vers)
            }
            for id in a.interieur.map(\.id) + exterieur where !relies.contains(id) {
                liens.append(Lien(de: id, vers: premier.instance))
            }
        }

        // Appareils sans partition connue : sous la principale, sans centre.
        let orphelins = tries(parZone[""] ?? [])
        if !orphelins.isEmpty {
            let rAnneau = max(Self.rayonZoneSeule, Double(orphelins.count) * Self.arcAppareil / (2 * .pi))
            let rayon = rAnneau + Self.marge
            let centre = Point2D(0, r0 + Self.ecart + rayon)
            zones.append(Zone(id: "", centre: centre, rayon: rayon, principale: false, prefixes: [], prefixesPartages: []))
            for (j, a) in orphelins.enumerated() {
                noeuds.append(Noeud(id: a.id, genre: .appareil, zone: "",
                                    position: Self.surAnneau(centre, rAnneau, j, orphelins.count), rayon: 7))
            }
        }
    }

    /// i-eme de n positions sur un cercle, en partant du haut, dans le sens horaire.
    static func surAnneau(_ c: Point2D, _ r: Double, _ i: Int, _ n: Int) -> Point2D {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(max(n, 1))
        return Point2D(c.x + r * cos(angle), c.y + r * sin(angle))
    }

    /// Rectangle qui contient toutes les zones.
    public var cadre: (min: Point2D, max: Point2D) {
        guard !zones.isEmpty else { return (Point2D(-100, -100), Point2D(100, 100)) }
        return (Point2D(zones.map { $0.centre.x - $0.rayon }.min()!, zones.map { $0.centre.y - $0.rayon }.min()!),
                Point2D(zones.map { $0.centre.x + $0.rayon }.max()!, zones.map { $0.centre.y + $0.rayon }.max()!))
    }

    public func noeud(_ id: String) -> Noeud? { noeuds.first { $0.id == id } }

    /// Noeud le plus proche d'un point, s'il est a moins de son rayon (+ tolerance).
    public func noeud(a p: Point2D, tolerance: Double = 6) -> Noeud? {
        noeuds.filter { $0.position.distance(p) <= $0.rayon + tolerance }
            .min { $0.position.distance(p) < $1.position.distance(p) }
    }
}
