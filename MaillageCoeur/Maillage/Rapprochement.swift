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
    /// Routeur de bordure non identifie : instances des annonces de sa partition qu'aucun
    /// routeur n'a reprises et qui peuvent etre la sienne, dans l'ordre de la partition ; vide
    /// sinon. Est ecartee l'annonce dont le `xa` et l'ExtMac du routeur sont connus tous deux et
    /// differents, ou dont le `xa` est l'ExtMac connue d'un autre routeur (une annonce en double
    /// de celui-ci).
    public let candidats: [String]
    /// Reconnu par elimination : seul routeur de bordure non identifie de la partition pour
    /// une seule annonce non reprise.
    public let deduit: Bool

    public init(id: String, rloc16: UInt16, genre: Genre, reconnu: Bool, bordure: Bool, candidats: [String] = [],
                deduit: Bool = false) {
        self.id = id
        self.rloc16 = rloc16
        self.genre = genre
        self.reconnu = reconnu
        self.bordure = bordure
        self.candidats = candidats
        self.deduit = deduit
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
    /// Annonces candidates d'au moins un routeur de bordure non identifie : ce routeur les porte,
    /// elles ne sont pas des noeuds a part (le centre de la partition excepte, voir `GrapheReseau`).
    public let annoncesCandidates: Set<String>

    /// Rapproche le maillage des routeurs de bordure de sa partition et des appareils :
    /// - routeur de bordure : son ExtMac est le `xa` de son annonce ;
    /// - autre routeur ou enfant : son ExtMac est l'hote de l'appareil ; a defaut
    ///   (enfant), une adresse commune ;
    /// - BBR principal des Network Data, encore non identifie : l'annonce dont `sb` dit BBR
    ///   primaire ; chef du maillage, routeur de bordure encore non identifie : l'annonce dont
    ///   le role (bits 9-10 de `sb`, Thread 1.4) est chef ; chacune seulement s'il ne reste
    ///   qu'une annonce de ce role ;
    /// - par elimination : le seul routeur de bordure non identifie est la seule annonce
    ///   de la partition qu'aucun routeur n'a reprise ;
    /// - sinon "rloc:XXXX", inconnu de l'instantane ; un routeur de bordure y garde ses
    ///   candidats, les annonces non reprises qui peuvent etre la sienne.
    /// Ces quatre dernieres regles ecartent une annonce dont le `xa` et l'ExtMac du routeur sont
    /// connus tous deux et differents, ou dont le `xa` est l'ExtMac connue d'un autre routeur.
    /// Un enfant vu deux fois (meme ExtMac, precision 26 du plan 4b) ne donne qu'un noeud et un
    /// lien : ceux de l'entree que retient `Maillage.enfantsIdentifies` ; l'autre est ecartee.
    public init(maillage: Maillage, reseau: Reseau, appareils: [Appareil]) {
        partition = maillage.partition
        date = maillage.date
        let bordures = reseau.partitions.first { $0.id == maillage.partition }?.routeurs ?? []
        let parId = Dictionary(appareils.map { ($0.id.uppercased(), $0) }, uniquingKeysWith: { a, _ in a })
        func rloc(_ r: UInt16) -> String { String(format: "rloc:%04X", r) }

        // Routeurs reconnus par leur ExtMac (id de noeud, par identifiant de routeur) : le `xa`
        // d'une annonce, sinon l'hote d'un appareil.
        var reconnus: [Int: String] = [:]
        var pris: Set<String> = []
        for r in maillage.routeurs {
            var id: String?
            if let ext = r.extMac, let br = bordures.first(where: { $0.adresseEtendue == ext }) {
                id = br.instance
            } else if let ext = r.extMac, let a = parId[ext] {
                id = a.id
            }
            if let i = id, pris.contains(i) { id = nil }
            if let i = id {
                pris.insert(i)
                reconnus[r.id] = i
            }
        }
        // Une annonce peut etre celle d'un routeur si l'ExtMac de l'un ou le `xa` de l'autre manque
        // (connus tous deux, ils sont differents : la regle du `xa` les aurait rapproches), et si son
        // `xa` n'est pas l'ExtMac connue d'un autre routeur (une annonce en double de celui-ci).
        let extMacs = Set(maillage.routeurs.compactMap(\.extMac))
        func possible(_ r: RouteurMaillage, _ a: RouteurBordure) -> Bool {
            guard let xa = a.adresseEtendue else { return true }
            return r.extMac == nil && !extMacs.contains(xa)
        }
        // Routeur d'un role (BBR principal, chef), encore non identifie : l'annonce de ce role dans
        // la partition, seulement s'il n'en reste qu'une (un cache perime peut en garder une autre,
        // avec le meme `pt`) et si elle peut etre la sienne.
        func rapprocher(_ r: RouteurMaillage?, _ annonces: [RouteurBordure]) {
            let libres = annonces.filter { !pris.contains($0.instance) }
            guard let r, reconnus[r.id] == nil, libres.count == 1, let a = libres.first, possible(r, a) else { return }
            reconnus[r.id] = a.instance
            pris.insert(a.instance)
        }
        // BBR principal des Network Data : l'annonce dont `sb` dit BBR primaire. Chef du maillage,
        // routeur de bordure : l'annonce de role chef (Thread 1.4, bits 9-10 de `sb`).
        rapprocher(maillage.routeurs.first(where: \.bbrPrincipal), bordures.filter { $0.etat?.bbrPrimaire == true })
        rapprocher(maillage.routeurs.first(where: { $0.chef && $0.bordure }), bordures.filter { $0.role == .chef })
        // Annonces qu'aucun routeur n'a reprises ; routeurs de bordure non identifies.
        let restantes = bordures.filter { !pris.contains($0.instance) }
        let nonIdentifies = maillage.routeurs.filter { $0.bordure && reconnus[$0.id] == nil }
        var deduit: Int?
        if nonIdentifies.count == 1, restantes.count == 1, let r = nonIdentifies.first, let a = restantes.first,
           possible(r, a) {
            reconnus[r.id] = a.instance
            pris.insert(a.instance)
            deduit = r.id
        }
        var routeurs: [Int: NoeudSonde] = [:]
        for r in maillage.routeurs {
            let id = reconnus[r.id]
            let candidats = id == nil && r.bordure
                ? restantes.filter { !pris.contains($0.instance) && possible(r, $0) }.map(\.instance) : []
            routeurs[r.id] = NoeudSonde(id: id ?? rloc(r.rloc16), rloc16: r.rloc16, genre: .routeur, reconnu: id != nil,
                                        bordure: r.bordure, candidats: candidats, deduit: deduit == r.id)
        }

        // Un enfant vu deux fois (il a change de parent, et l'ancienne entree du balayage d'un routeur
        // muet peut rester 30 minutes) n'est qu'un noeud : l'entree que retient
        // `Maillage.enfantsIdentifies` (la sonde, puis une table, puis le balayage) ; l'autre est
        // ecartee, sans noeud ni lien.
        let retenus = maillage.enfantsIdentifies
        var enfants: [UInt16: NoeudSonde] = [:]
        for e in maillage.enfants {
            if let x = e.extMac, retenus[x] != e { continue }
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
        annoncesCandidates = Set(routeurs.values.flatMap(\.candidats))
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
