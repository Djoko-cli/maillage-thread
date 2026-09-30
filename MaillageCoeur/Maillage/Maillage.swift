import Foundation

/// Routeur Thread vu par la sonde.
public struct RouteurMaillage: Hashable, Sendable, Identifiable {
    /// Identifiant de routeur, de 0 a 62 : son RLOC16 est `id << 10`.
    public let id: Int
    public var extMac: String?
    /// Publie un prefixe, une route ou le service SRP (Network Data).
    public var bordure = false
    public var bbrPrincipal = false
    public var chef = false
    /// N'a pas repondu a la tournee : ses liens et ses enfants ne viennent que des autres.
    public var muet = false
    public var version: Int?
    /// Version de la pile (TLV 28).
    public var pile: String?

    public init(id: Int) { self.id = id }

    public var rloc16: UInt16 { UInt16(id) << 10 }
}

/// Lien radio entre deux routeurs voisins (a < b), avec la qualite dans chaque
/// sens, de 0 a 3 ; nil : inconnue.
public struct LienRadio: Hashable, Sendable {
    public let a: Int
    public let b: Int
    /// Qualite du lien de a vers b.
    public var qualiteAB: Int?
    /// Qualite du lien de b vers a.
    public var qualiteBA: Int?

    /// La moins bonne des qualites connues.
    public var qualite: Int? { [qualiteAB, qualiteBA].compactMap { $0 }.min() }
}

/// D'ou vient un enfant.
public enum SourceEnfant: String, Hashable, Sendable {
    /// Child Table de son parent, un routeur qui repond.
    case tableEnfants
    /// Trouve par balayage sous un routeur muet.
    case balayage
    /// La sonde elle-meme.
    case sonde
}

/// Enfant d'un routeur (appareil endormi ou non, ou la sonde).
public struct EnfantMaillage: Hashable, Sendable, Identifiable {
    public let rloc16: UInt16
    public var extMac: String?
    /// Qualite du lien de l'enfant vers son parent, de 0 a 3 ; nil sous un routeur muet.
    public var qualite: Int?
    /// Delai d'expiration de l'enfant (Child Timeout), en secondes.
    public var delai: Int?
    public var endormi: Bool?
    /// Adresses donnees par l'enfant (TLV 8), pour le reconnaitre par son adresse OMR.
    public var adresses: [AdresseIPv6]
    public var source: SourceEnfant

    public init(rloc16: UInt16, extMac: String? = nil, qualite: Int? = nil, delai: Int? = nil, endormi: Bool? = nil,
                adresses: [AdresseIPv6] = [], source: SourceEnfant) {
        self.rloc16 = rloc16
        self.extMac = extMac
        self.qualite = qualite
        self.delai = delai
        self.endormi = endormi
        self.adresses = adresses
        self.source = source
    }

    public var id: UInt16 { rloc16 }
    /// Identifiant de routeur du parent.
    public var parent: Int { Int(rloc16 >> 10) }
}

/// Signal d'un routeur tel que la sonde l'entend a une tournee (spec de la sonde, section 6) :
/// son parent (`etat`) ou un routeur voisin (`voisins`).
public struct SignalSonde: Hashable, Sendable {
    /// Identifiant du routeur.
    public let routeur: Int
    /// RSSI moyen, en dBm.
    public let rssi: Int

    public init(routeur: Int, rssi: Int) {
        self.routeur = routeur
        self.rssi = rssi
    }
}

/// Le maillage d'une partition, tel qu'une tournee de la sonde le voit.
public struct Maillage: Hashable, Sendable {
    public let date: Date
    public let partition: String
    /// Par identifiant croissant.
    public let routeurs: [RouteurMaillage]
    /// Par (a, b) croissants.
    public let liens: [LienRadio]
    /// Par RLOC16 croissant.
    public let enfants: [EnfantMaillage]
    /// Signal des routeurs de la liste que la sonde entend, son parent compris, par identifiant
    /// croissant.
    public let signaux: [SignalSonde]
    /// Date du balayage dont viennent les enfants balayes de ce maillage
    /// (`MemoireTournee.dernierBalayage`) ; nil sans balayage.
    public var balayage: Date?

    public func routeur(_ id: Int) -> RouteurMaillage? { routeurs.first { $0.id == id } }
    public func liens(de id: Int) -> [LienRadio] { liens.filter { $0.a == id || $0.b == id } }
    public func enfants(de id: Int) -> [EnfantMaillage] { enfants.filter { $0.parent == id } }
    public var chef: RouteurMaillage? { routeurs.first(where: \.chef) }
    /// Identifiant de routeur du parent de la sonde.
    public var parentSonde: Int? { enfants.first { $0.source == .sonde }?.parent }

    /// Enfants identifies (ExtMac connue), un par ExtMac. Vu deux fois (il a change de parent),
    /// l'entree la plus fraiche l'emporte : la sonde (elle sait son parent), puis la table d'un
    /// routeur qui repond (l'ancien parent garde l'enfant jusqu'a son echeance), puis le balayage
    /// d'un routeur muet, qui peut dater de 30 minutes ; a egalite, la premiere par RLOC16.
    public var enfantsIdentifies: [String: EnfantMaillage] {
        func rang(_ s: SourceEnfant) -> Int {
            switch s {
            case .sonde: 0
            case .tableEnfants: 1
            case .balayage: 2
            }
        }
        var parExtMac: [String: EnfantMaillage] = [:]
        for e in enfants {
            guard let x = e.extMac else { continue }
            if let deja = parExtMac[x], rang(deja.source) <= rang(e.source) { continue }
            parExtMac[x] = e
        }
        return parExtMac
    }
}

/// Assemble un `Maillage` au fil des reponses d'une tournee.
public struct ConstructionMaillage: Sendable {
    private let date: Date
    private let partition: String
    private var routeurs: [Int: RouteurMaillage] = [:]
    private var liens: [Int: LienRadio] = [:]
    private var enfants: [UInt16: EnfantMaillage] = [:]
    private var signaux: [Int: SignalSonde] = [:]

    public init(date: Date, partition: String) {
        self.date = date
        self.partition = partition
    }

    /// Routeurs actifs de la partition (Route64 du chef, ou d'un routeur qui repond).
    public mutating func routeurs(_ r: Route64, chef: Int) {
        for id in r.routeurs where routeurs[id] == nil { routeurs[id] = RouteurMaillage(id: id) }
        routeurs[chef, default: RouteurMaillage(id: chef)].chef = true
    }

    /// Roles lus dans les Network Data. BBR principal, comme OpenThread : celui du chef s'il est
    /// parmi les serveurs, sinon le premier de `d.bbr` (de meme si le chef n'est pas encore connu).
    /// `seulementConnus` : Network Data d'une tournee precedente, pour les seuls routeurs deja dans
    /// le maillage (la liste des routeurs a pu changer depuis) ; un serveur BBR absent ne compte pas.
    public mutating func reseau(_ d: DonneesReseau, seulementConnus: Bool = false) {
        func pris(_ rloc: UInt16) -> Bool { !seulementConnus || routeurs[Int(rloc >> 10)] != nil }
        for rloc in d.routeursDeBordure where pris(rloc) {
            routeurs[Int(rloc >> 10), default: RouteurMaillage(id: Int(rloc >> 10))].bordure = true
        }
        let chef = routeurs.values.first(where: \.chef)?.rloc16
        let serveurs = d.bbr.filter(pris)
        if let principal = serveurs.first(where: { $0 == chef }) ?? serveurs.first {
            routeurs[Int(principal >> 10), default: RouteurMaillage(id: Int(principal >> 10))].bbrPrincipal = true
        }
    }

    /// Reponse d'un routeur : identite, version, ses liens (Route64) et ses enfants (Child Table).
    public mutating func reponse(_ r: ReponseDiagnostic, routeur id: Int) {
        var routeur = routeurs[id, default: RouteurMaillage(id: id)]
        routeur.extMac = r.extMac ?? routeur.extMac
        routeur.version = r.version ?? routeur.version
        routeur.muet = false
        routeurs[id] = routeur
        for route in r.route64?.routes ?? [] where route.idRouteur != id {
            if routeurs[route.idRouteur] == nil { routeurs[route.idRouteur] = RouteurMaillage(id: route.idRouteur) }
            guard route.estVoisin else { continue }
            lien(id, route.idRouteur, sortante: route.qualiteSortante, entrante: route.qualiteEntrante)
        }
        for e in r.enfants ?? [] {
            enfant(EnfantMaillage(rloc16: e.rloc16(parent: routeur.rloc16), qualite: e.qualite, delai: e.delai,
                                  endormi: e.mode.endormi, source: .tableEnfants))
        }
    }

    /// ExtMac apprise ailleurs (parent de la sonde, table des routeurs, tournee precedente) : pour
    /// un routeur qui ne la donne pas lui-meme, muet ou dont la reponse n'a pas l'ExtMac. Ne
    /// remplace jamais celle qu'il a donnee.
    public mutating func identite(_ ext: String, routeur id: Int) {
        var r = routeurs[id, default: RouteurMaillage(id: id)]
        r.extMac = r.extMac ?? ext
        routeurs[id] = r
    }

    public mutating func pile(_ p: String?, routeur id: Int) {
        routeurs[id, default: RouteurMaillage(id: id)].pile = p
    }

    /// Routeur qui n'a pas repondu.
    public mutating func muet(_ id: Int) {
        routeurs[id, default: RouteurMaillage(id: id)].muet = true
    }

    /// Enfant trouve (table, balayage, sonde) ; complete celui qui est deja connu.
    public mutating func enfant(_ e: EnfantMaillage) {
        guard var connu = enfants[e.rloc16] else {
            enfants[e.rloc16] = e
            return
        }
        connu.extMac = connu.extMac ?? e.extMac
        connu.qualite = connu.qualite ?? e.qualite
        connu.delai = connu.delai ?? e.delai
        connu.endormi = connu.endormi ?? e.endormi
        if connu.adresses.isEmpty { connu.adresses = e.adresses }
        if e.source == .sonde { connu.source = .sonde }
        enfants[e.rloc16] = connu
    }

    /// Signal d'un routeur entendu par la sonde ; le dernier donne pour un routeur l'emporte. Un
    /// RSSI positif ou nul est ignore (127 : RSSI invalide d'OpenThread, rien d'entendu encore).
    public mutating func signal(_ s: SignalSonde) {
        guard s.rssi < 0 else { return }
        signaux[s.routeur] = s
    }

    /// Roles poses a la main (maillage de demo).
    mutating func marquer(_ id: Int, bordure: Bool, bbrPrincipal: Bool = false) {
        var r = routeurs[id, default: RouteurMaillage(id: id)]
        r.bordure = bordure
        r.bbrPrincipal = bbrPrincipal
        routeurs[id] = r
    }

    /// Lien vu par `de` : qualite sortante (de -> vers) et entrante (vers -> de).
    /// Un lien est souvent lu aux deux bouts (chaque routeur qui repond le voit dans sa Route64). Les
    /// rapports ne sont pas fusionnes : le dernier remplace les deux sens du precedent (ni moyenne, ni
    /// meilleure, ni pire valeur). La tournee applique les reponses par identifiant croissant : quand les
    /// deux bouts repondent, celui de plus grand identifiant decide. Un lien lu par un seul bout garde
    /// ses deux sens, ranges de `a` vers `b` (le plus petit identifiant d'abord). Une entree de Route64
    /// sans qualite (pas voisin, `estVoisin` faux) n'est pas appliquee : elle ne remplace pas le rapport
    /// de l'autre bout.
    mutating func lien(_ de: Int, _ vers: Int, sortante: Int, entrante: Int) {
        let (a, b) = (min(de, vers), max(de, vers))
        var l = liens[a * 64 + b] ?? LienRadio(a: a, b: b)
        if de == a {
            l.qualiteAB = sortante
            l.qualiteBA = entrante
        } else {
            l.qualiteAB = entrante
            l.qualiteBA = sortante
        }
        liens[a * 64 + b] = l
    }

    /// Enfants des tables encore sans ExtMac, par RLOC16 : a identifier (la sonde exceptee).
    public var enfantsSansIdentite: [UInt16] {
        enfants.values.filter { $0.extMac == nil && $0.source != .sonde }.map(\.rloc16).sorted()
    }

    /// Le maillage ; les signaux des seuls routeurs de la liste.
    public func maillage() -> Maillage {
        Maillage(date: date, partition: partition,
                 routeurs: routeurs.values.sorted { $0.id < $1.id },
                 liens: liens.values.sorted { ($0.a, $0.b) < ($1.a, $1.b) },
                 enfants: enfants.values.sorted { $0.rloc16 < $1.rloc16 },
                 signaux: signaux.values.filter { routeurs[$0.routeur] != nil }.sorted { $0.routeur < $1.routeur })
    }
}
