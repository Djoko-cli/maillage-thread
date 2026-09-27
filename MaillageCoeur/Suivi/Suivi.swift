import Foundation

/// Suit le reseau de releve en releve et en tire les evenements du journal.
///
/// - Au premier releve : un seul point de depart (`surveillanceDemarree`), et
///   une scission deja la est notee comme constatee, sans autre comparaison.
/// - Ensuite : differences entre deux instantanes. Une absence (service ou
///   adresses) n'est retenue qu'apres 2 min (`MemoireAnnonces`) et datee de la
///   premiere absence.
/// - Apres une veille du Mac, ce qui est constate dans les 4 min qui suivent le
///   reveil est date de la veille (`periode`), jamais du reveil.
public struct Suivi: Sendable {
    public static let apresReveil: TimeInterval = 240

    public private(set) var instantane: Instantane?
    /// Appareils disparus depuis le lancement (dernier etat connu), jusqu'a leur retour.
    public private(set) var disparus: [String: Appareil] = [:]
    /// Derniere partition connue de chaque appareil (pour placer un appareil sans adresse ou disparu).
    public private(set) var dernieresPartitions: [String: String] = [:]
    private var memoire = MemoireAnnonces()
    private var derniereVeille: DateInterval?

    public init() {}

    /// Note une veille du Mac et rend son evenement.
    public mutating func noterVeille(_ periode: DateInterval) -> [Evenement] {
        derniereVeille = periode
        return [Evenement(date: periode.end, type: .veille, periode: periode)]
    }

    /// Integre un releve et rend les evenements qu'il fait apparaitre.
    public mutating func integrer(_ releve: Annonces, noms: ResolveurNoms = ResolveurNoms()) -> [Evenement] {
        let nouveau = Instantane(annonces: memoire.completer(releve))
        let date = releve.date
        var ev: [Evenement] = []
        if let ancien = instantane {
            let fabrique = noms.fabriqueApple(appareils: nouveau.appareils + nouveau.appareilsIP + ancien.appareils)
            ev += Self.evenementsReseaux(ancien, nouveau, date, noms)
            ev += evenementsRouteurs(ancien, nouveau, date, noms)
            ev += Self.evenementsPrefixes(ancien, nouveau, date)
            ev += evenementsAppareils(ancien, nouveau, date, noms, fabrique)
        } else {
            ev.append(Evenement(date: date, type: .surveillanceDemarree,
                                details: ["routeurs": String(nouveau.routeurs.count),
                                          "appareils": String(nouveau.appareils.count)]))
            for r in nouveau.reseaux where r.estScinde {
                ev.append(Evenement(date: date, type: .reseauScinde, reseau: r.id, sujet: Sujet(id: r.id, nom: r.nom),
                                    apres: String(r.partitions.count), constate: true,
                                    details: Self.detailsPartitions(r, noms)))
            }
        }
        instantane = nouveau
        for a in nouveau.appareils {
            if let p = a.partition { dernieresPartitions[a.id] = p }
        }
        return ev.map(dater)
    }

    /// Partition -> noms de ses routeurs, pour dire qui est isole.
    static func detailsPartitions(_ r: Reseau, _ noms: ResolveurNoms) -> [String: String] {
        Dictionary(r.partitions.map { ($0.id, $0.routeurs.map { noms.nom(routeur: $0) }.joined(separator: ", ")) },
                   uniquingKeysWith: { a, _ in a })
    }

    static func evenementsReseaux(_ ancien: Instantane, _ nouveau: Instantane, _ date: Date,
                                  _ noms: ResolveurNoms) -> [Evenement] {
        var ev: [Evenement] = []
        for r in nouveau.reseaux {
            guard let a = ancien.reseau(r.id) else { continue }
            let s = Sujet(id: r.id, nom: r.nom)
            if r.estScinde && r.partitions.count > a.partitions.count {
                ev.append(Evenement(date: date, type: .reseauScinde, reseau: r.id, sujet: s,
                                    avant: String(a.partitions.count), apres: String(r.partitions.count),
                                    details: detailsPartitions(r, noms)))
            } else if r.partitions.count < a.partitions.count {
                ev.append(Evenement(date: date, type: .reseauReuni, reseau: r.id, sujet: s,
                                    avant: String(a.partitions.count), apres: String(r.partitions.count)))
            }
            if let c1 = a.principale?.chef, let c2 = r.principale?.chef, c1.instance != c2.instance {
                ev.append(Evenement(date: date, type: .chefChange, reseau: r.id, sujet: s,
                                    avant: noms.nom(routeur: c1), apres: noms.nom(routeur: c2)))
            }
            if let b1 = a.principale?.bbrPrimaire, let b2 = r.principale?.bbrPrimaire, b1.instance != b2.instance {
                ev.append(Evenement(date: date, type: .bbrPrimaireChange, reseau: r.id, sujet: s,
                                    avant: noms.nom(routeur: b1), apres: noms.nom(routeur: b2)))
            }
            if let j1 = a.routeurs.compactMap(\.jeuActif).max(), let j2 = r.routeurs.compactMap(\.jeuActif).max(), j1 != j2 {
                ev.append(Evenement(date: date, type: .jeuActifChange, reseau: r.id, sujet: s,
                                    avant: j1.formatted(.iso8601), apres: j2.formatted(.iso8601)))
            }
        }
        return ev
    }

    private func evenementsRouteurs(_ ancien: Instantane, _ nouveau: Instantane, _ date: Date,
                                    _ noms: ResolveurNoms) -> [Evenement] {
        var ev: [Evenement] = []
        let anciens = Dictionary(ancien.routeurs.map { ($0.instance, $0) }, uniquingKeysWith: { a, _ in a })
        let nouveaux = Dictionary(nouveau.routeurs.map { ($0.instance, $0) }, uniquingKeysWith: { a, _ in a })
        for r in nouveau.routeurs {
            let s = Sujet(id: r.instance, nom: noms.nom(routeur: r))
            guard let a = anciens[r.instance] else {
                ev.append(Evenement(date: date, type: .routeurApparu, reseau: r.idReseau, sujet: s, apres: r.partition))
                continue
            }
            if let ra = a.role, let rn = r.role, ra != rn {
                ev.append(Evenement(date: date, type: .routeurRoleChange, reseau: r.idReseau, sujet: s,
                                    avant: ra.rawValue, apres: rn.rawValue))
            }
            let la = Set(a.adressesLien)
            let ln = Set(r.adressesLien)
            if !la.isEmpty && !ln.isEmpty && !ln.isSubset(of: la) {
                ev.append(Evenement(date: date, type: .routeurNouvelleAdresseLien, reseau: r.idReseau, sujet: s,
                                    avant: la.sorted().map(\.description).joined(separator: ", "),
                                    apres: ln.sorted().map(\.description).joined(separator: ", ")))
            }
        }
        for a in ancien.routeurs where nouveaux[a.instance] == nil {
            let debut = memoire.abandons[.init(famille: .routeur, instance: a.instance)] ?? date
            ev.append(Evenement(date: debut, type: .routeurDisparu, reseau: a.idReseau,
                                sujet: Sujet(id: a.instance, nom: noms.nom(routeur: a)), avant: a.partition))
        }
        return ev
    }

    static func evenementsPrefixes(_ ancien: Instantane, _ nouveau: Instantane, _ date: Date) -> [Evenement] {
        let pa = Set(ancien.prefixes)
        let pn = Set(nouveau.prefixes)
        func reseau(_ p: PrefixeIPv6, _ i: Instantane) -> String? { i.reseaux.first { $0.prefixes.contains(p) }?.id }
        return pn.subtracting(pa).sorted().map {
            Evenement(date: date, type: .prefixeNouveau, reseau: reseau($0, nouveau),
                      sujet: Sujet(id: $0.description, nom: $0.description))
        } + pa.subtracting(pn).sorted().map {
            Evenement(date: date, type: .prefixeRetire, reseau: reseau($0, ancien),
                      sujet: Sujet(id: $0.description, nom: $0.description))
        }
    }

    private mutating func evenementsAppareils(_ ancien: Instantane, _ nouveau: Instantane, _ date: Date,
                                              _ noms: ResolveurNoms, _ fabrique: String?) -> [Evenement] {
        var ev: [Evenement] = []
        let anciens = Dictionary(ancien.appareils.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let nouveaux = Dictionary(nouveau.appareils.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for n in nouveau.appareils {
            let s = Sujet(id: n.id, nom: noms.nom(appareil: n, fabriqueApple: fabrique))
            if let a = anciens[n.id] {
                if a.genre != .sansAdresse && n.genre == .sansAdresse {
                    let debut = n.hote.flatMap { memoire.adressesAbandonnees[$0] } ?? date
                    ev.append(Evenement(date: debut, type: .appareilSansAdresse, reseau: a.idReseau, sujet: s,
                                        avant: a.partition))
                } else if a.genre == .sansAdresse && n.genre != .sansAdresse {
                    ev.append(Evenement(date: date, type: .appareilRevenu, reseau: n.idReseau, sujet: s,
                                        apres: n.partition))
                } else if let p1 = a.partition, let p2 = n.partition, p1 != p2 {
                    let coupee = n.etat == .partitionCoupee
                    ev.append(Evenement(date: date, type: .appareilChangePartition, gravite: coupee ? .attention : .info,
                                        reseau: n.idReseau, sujet: s, avant: p1, apres: p2,
                                        details: coupee ? ["coupee": "oui"] : [:]))
                }
            } else if disparus[n.id] != nil {
                disparus[n.id] = nil
                ev.append(Evenement(date: date, type: .appareilRevenu, reseau: n.idReseau, sujet: s, apres: n.partition))
            } else {
                ev.append(Evenement(date: date, type: .appareilNouveau, reseau: n.idReseau, sujet: s, apres: n.partition))
            }
        }
        for a in ancien.appareils where nouveaux[a.id] == nil {
            var dates = a.servicesMatter.compactMap { memoire.abandons[.init(famille: .matter, instance: $0)] }
            if let h = a.hap, let d = memoire.abandons[.init(famille: .hap, instance: h.nom)] { dates.append(d) }
            ev.append(Evenement(date: dates.max() ?? date, type: .appareilDisparu, reseau: a.idReseau,
                                sujet: Sujet(id: a.id, nom: noms.nom(appareil: a, fabriqueApple: fabrique)),
                                avant: a.partition ?? dernieresPartitions[a.id]))
            disparus[a.id] = a
        }
        return ev
    }

    /// Ce qui est constate peu apres un reveil est date de la veille.
    private func dater(_ e: Evenement) -> Evenement {
        guard let v = derniereVeille, e.type != .veille, e.periode == nil,
              e.date >= v.end, e.date <= v.end.addingTimeInterval(Self.apresReveil) else { return e }
        var c = e
        c.periode = v
        return c
    }
}
