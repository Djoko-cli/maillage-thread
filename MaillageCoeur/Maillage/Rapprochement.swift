import Foundation

/// Noeud de la sonde place dans le graphe.
public struct NoeudSonde: Hashable, Sendable, Identifiable {
    public enum Genre: String, Hashable, Sendable {
        case routeur, enfant
    }

    /// Id du noeud du graphe : instance du routeur de bordure, id de l'appareil, ou
    /// "rloc:B400" quand l'instantane ne le connait pas.
    public let id: String
    public let rloc16: UInt16
    public let genre: Genre
    /// Retrouve dans l'instantane.
    public let reconnu: Bool
    /// Routeur de bordure (Network Data).
    public let bordure: Bool

    public init(id: String, rloc16: UInt16, genre: Genre, reconnu: Bool, bordure: Bool) {
        self.id = id
        self.rloc16 = rloc16
        self.genre = genre
        self.reconnu = reconnu
        self.bordure = bordure
    }
}

/// Lien de la sonde entre deux noeuds du graphe.
public struct LienAffiche: Hashable, Sendable {
    public enum Genre: String, Hashable, Sendable {
        /// Entre deux routeurs voisins.
        case radio
        /// De l'enfant vers son parent.
        case parent
    }

    public let de: String
    public let vers: String
    public let genre: Genre
    /// De 0 a 3 ; nil : inconnue (parent muet).
    public let qualite: Int?
}

/// Maillage de la sonde rapproche de l'instantane (spec de la sonde, section 4) :
/// ce que le graphe dessine.
public struct MaillageAffiche: Hashable, Sendable {
    public let partition: String
    public let date: Date
    /// Routeurs, par identifiant de routeur.
    public let routeurs: [Int: NoeudSonde]
    /// Enfants, par RLOC16.
    public let enfants: [UInt16: NoeudSonde]
    public let liens: [LienAffiche]

    /// Rapproche le maillage des routeurs de bordure de sa partition et des appareils :
    /// - routeur de bordure : son ExtMac est le `xa` de son annonce ; a defaut, le
    ///   BBR principal des Network Data est celui dont `sb` le dit ;
    /// - autre routeur ou enfant : son ExtMac est l'hote de l'appareil ; a defaut
    ///   (enfant), une adresse commune ;
    /// - sinon "rloc:XXXX", inconnu de l'instantane.
    public init(maillage: Maillage, reseau: Reseau, appareils: [Appareil]) {
        partition = maillage.partition
        date = maillage.date
        let bordures = reseau.partitions.first { $0.id == maillage.partition }?.routeurs ?? []
        let parId = Dictionary(appareils.map { ($0.id.uppercased(), $0) }, uniquingKeysWith: { a, _ in a })
        func rloc(_ r: UInt16) -> String { String(format: "rloc:%04X", r) }

        var routeurs: [Int: NoeudSonde] = [:]
        var pris: Set<String> = []
        for r in maillage.routeurs {
            var id: String?
            if let ext = r.extMac, let br = bordures.first(where: { $0.adresseEtendue == ext }) {
                id = br.instance
            } else if r.bbrPrincipal, let br = bordures.first(where: { $0.etat?.bbrPrimaire == true }),
                      !maillage.routeurs.contains(where: { $0.extMac == br.adresseEtendue && $0.id != r.id }) {
                id = br.instance
            } else if let ext = r.extMac, let a = parId[ext] {
                id = a.id
            }
            if let i = id, pris.contains(i) { id = nil }
            if let i = id { pris.insert(i) }
            routeurs[r.id] = NoeudSonde(id: id ?? rloc(r.rloc16), rloc16: r.rloc16, genre: .routeur, reconnu: id != nil,
                                        bordure: r.bordure)
        }

        var enfants: [UInt16: NoeudSonde] = [:]
        for e in maillage.enfants {
            var id = e.extMac.flatMap { parId[$0]?.id }
            if id == nil, !e.adresses.isEmpty {
                let adresses = Set(e.adresses)
                id = appareils.first { !adresses.isDisjoint(with: $0.adresses) }?.id
            }
            if let i = id, pris.contains(i) { id = nil }
            if let i = id { pris.insert(i) }
            enfants[e.rloc16] = NoeudSonde(id: id ?? rloc(e.rloc16), rloc16: e.rloc16, genre: .enfant, reconnu: id != nil,
                                           bordure: false)
        }

        var liens = maillage.liens.compactMap { l -> LienAffiche? in
            guard let a = routeurs[l.a], let b = routeurs[l.b] else { return nil }
            return LienAffiche(de: a.id, vers: b.id, genre: .radio, qualite: l.qualite)
        }
        for e in maillage.enfants {
            guard let enfant = enfants[e.rloc16], let parent = routeurs[e.parent] else { continue }
            liens.append(LienAffiche(de: enfant.id, vers: parent.id, genre: .parent, qualite: e.qualite))
        }
        self.routeurs = routeurs
        self.enfants = enfants
        self.liens = liens
    }

    /// Noeud du graphe, routeur ou enfant.
    public func noeud(_ id: String) -> NoeudSonde? {
        routeurs.values.first { $0.id == id } ?? enfants.values.first { $0.id == id }
    }

    /// Noeuds que l'instantane n'a pas, a ajouter au graphe : routeurs, puis enfants, par RLOC16.
    public var inconnus: [NoeudSonde] {
        let r = routeurs.values.filter { !$0.reconnu }.sorted { $0.rloc16 < $1.rloc16 }
        let e = enfants.values.filter { !$0.reconnu }.sorted { $0.rloc16 < $1.rloc16 }
        return r + e
    }

    /// Parent d'un noeud enfant (id de noeud), s'il est connu.
    public func parent(de id: String) -> String? {
        liens.first { $0.genre == .parent && $0.de == id }?.vers
    }

    /// Ids des noeuds routeurs.
    public var idsRouteurs: Set<String> { Set(routeurs.values.map(\.id)) }
}
