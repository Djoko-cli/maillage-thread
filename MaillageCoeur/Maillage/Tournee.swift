import Foundation

/// Ce que la tournee demande a la sonde : la liaison USB dans l'app, une sonde
/// rejouee dans les tests.
public protocol InterlocuteurSonde: Sendable {
    func etat() async throws -> EtatSonde
    /// `DIAG_GET` vers un RLOC16 : la reponse, ou l'echec (`delai`, `occupee`...).
    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag
}

/// Ce que la tournee retient d'une fois sur l'autre (spec de la sonde, section 4).
public struct MemoireTournee: Hashable, Sendable {
    /// Echecs de suite, par routeur : muet a partir de 2.
    public var echecs: [Int: Int] = [:]
    /// Derniere interrogation d'un routeur muet : une fois par heure.
    public var muetInterroge: [Int: Date] = [:]
    /// Pile (TLV 28), demandee une fois par routeur qui repond ; "" : aucune.
    public var piles: [Int: String] = [:]
    /// ExtMac des routeurs, par RLOC16 : parents successifs de la sonde, routeurs qui repondent.
    public var identites: [UInt16: String] = [:]
    /// Enfants des routeurs muets trouves au dernier balayage.
    public var balayes: [UInt16: EnfantMaillage] = [:]
    /// Enfants des tables deja identifies (ExtMac, adresses), par RLOC16 : revus a chaque balayage.
    public var identifies: [UInt16: EnfantMaillage] = [:]
    public var dernierBalayage: Date?
    /// Routeurs muets au dernier balayage : un autre ensemble relance le balayage.
    public var muetsBalayes: Set<Int> = []
    /// Routeurs qui ont repondu a la derniere tournee : Route64 de secours quand le chef est muet.
    public var repondants: [Int] = []
    /// Partition de ce qui est retenu : une autre remet tout a zero.
    public var partition: String?

    public init() {}

    public func estMuet(_ id: Int) -> Bool { (echecs[id] ?? 0) >= 2 }
}

/// Tournee de la sonde : liste des routeurs, routeurs qui repondent, roles,
/// puis balayage des enfants des routeurs muets.
public enum Tournee {
    public static let tlvChef: [UInt8] = [TypeTLV.route64, TypeTLV.donneesChef]
    public static let tlvRouteur: [UInt8] = [TypeTLV.extMac, TypeTLV.address16, TypeTLV.route64, TypeTLV.tableEnfants,
                                             TypeTLV.adresses, TypeTLV.version]
    public static let tlvPile: [UInt8] = [TypeTLV.fabricant, TypeTLV.modele, TypeTLV.versionLogicielle, TypeTLV.pile]
    public static let tlvReseau: [UInt8] = [TypeTLV.donneesReseau]
    public static let tlvBalayage: [UInt8] = [TypeTLV.extMac, TypeTLV.address16, TypeTLV.mode, TypeTLV.adresses]
    public static let tlvIdentite: [UInt8] = [TypeTLV.extMac, TypeTLV.adresses]
    public static let delaiRouteur = 6000
    public static let delaiBalayage = 8000
    /// Requetes en vol a la fois (la sonde en tient 8).
    public static let enVol = 8
    /// Delai d'un enfant : un endormi ne repond qu'a son reveil.
    public static let delaiEnfant = 8000
    /// Numeros d'enfant balayes sous un routeur muet : de 1 a 32, et 8 apres le dernier trouve.
    public static let numerosMax = 32
    public static let apresDernier = 8
    public static let periodeBalayage: TimeInterval = 30 * 60
    public static let periodeMuet: TimeInterval = 3600

    /// Une tournee, et le balayage s'il est du ; nil si la sonde n'est pas attachee,
    /// ou suspendue dans Maison (ses requetes echoueraient toutes : aucun routeur
    /// ne doit passer pour muet).
    public static func executer(_ sonde: some InterlocuteurSonde, memoire: MemoireTournee,
                                maintenant: Date) async throws -> (maillage: Maillage, memoire: MemoireTournee)? {
        var mem = memoire
        let etat = try await sonde.etat()
        guard etat.estAttachee, !etat.suspendue, let partition = etat.partition, let chef = etat.chef,
              let moi = etat.rloc16Valeur else { return nil }
        // Autre partition : les identifiants de routeur y sont redistribues, rien ne vaut plus.
        if let ancienne = mem.partition, ancienne != partition { mem = MemoireTournee() }
        mem.partition = partition
        var c = ConstructionMaillage(date: maintenant, partition: partition)
        if let p = etat.parent, let rp = UInt16(p.rloc16, radix: 16) {
            mem.identites[rp] = p.ext
            c.enfant(EnfantMaillage(rloc16: moi, extMac: etat.ext, qualite: p.lqOut, source: .sonde))
        }

        // 1. Liste des routeurs : Route64 du chef ; s'il est muet, d'un routeur qui a repondu.
        let secours = mem.repondants.filter { $0 != chef }
        var route64: Route64?
        for id in mem.estMuet(chef) ? secours + [chef] : [chef] + secours {
            if let r = try await sonde.diag(rloc16(id), tlvChef, delaiMs: delaiRouteur).reponse?.route64 {
                route64 = r
                break
            }
        }
        guard let route64 else { return (c.maillage(), mem) }
        c.routeurs(route64, chef: chef)

        // 2. Chaque routeur, en parallele, sauf un muet deja interroge dans l'heure.
        let aInterroger = route64.routeurs.filter { id in
            guard mem.estMuet(id), let quand = mem.muetInterroge[id] else { return true }
            return maintenant.timeIntervalSince(quand) >= periodeMuet
        }
        var repondants: [Int] = []
        for (id, r) in try await parallele(aInterroger, { try await sonde.diag(rloc16($0), tlvRouteur, delaiMs: delaiRouteur) }) {
            if let rep = r.reponse {
                c.reponse(rep, routeur: id)
                mem.echecs[id] = 0
                mem.muetInterroge[id] = nil
                if let ext = rep.extMac { mem.identites[rloc16(id)] = ext }
                repondants.append(id)
            } else {
                mem.echecs[id, default: 0] += 1
                if mem.estMuet(id) { mem.muetInterroge[id] = maintenant }
            }
        }
        mem.repondants = repondants
        let muets = Set(route64.routeurs).subtracting(repondants)
        for id in muets.sorted() {
            c.muet(id)
            if let ext = mem.identites[rloc16(id)] { c.identite(ext, routeur: id) }
        }

        // 3. Pile, une fois ; Network Data, a un routeur qui repond.
        for id in repondants where mem.piles[id] == nil {
            if let rep = try await sonde.diag(rloc16(id), tlvPile, delaiMs: delaiRouteur).reponse {
                mem.piles[id] = rep.pile ?? ""
            }
        }
        for id in repondants {
            c.pile(mem.piles[id].flatMap { $0.isEmpty ? nil : $0 }, routeur: id)
        }
        if let id = repondants.first,
           let brutes = try await sonde.diag(rloc16(id), tlvReseau, delaiMs: delaiRouteur).reponse?.donneesReseau,
           let d = DonneesReseau(brutes) {
            c.reseau(d)
        }

        // 4. Balayage des enfants des routeurs muets : toutes les 30 min, ou si les muets
        // changent. Les identites des enfants des tables sont alors revues aussi.
        let du = mem.dernierBalayage.map { maintenant.timeIntervalSince($0) >= periodeBalayage } ?? true
        if du || (!muets.isEmpty && muets != mem.muetsBalayes) {
            var trouves: [UInt16: EnfantMaillage] = [:]
            for m in muets.sorted() {
                for e in try await balayer(sonde, routeur: m, sauf: moi) { trouves[e.rloc16] = e }
            }
            mem.balayes = trouves
            mem.identifies = [:]
            mem.dernierBalayage = maintenant
            mem.muetsBalayes = muets
        }
        for e in mem.balayes.values.sorted(by: { $0.rloc16 < $1.rloc16 }) where muets.contains(e.parent) {
            c.enfant(e)
        }

        // 5. Enfants des tables encore inconnus : ExtMac et adresses, une fois.
        let aIdentifier = c.enfantsSansIdentite.filter { mem.identifies[$0] == nil }
        for (cible, r) in try await parallele(aIdentifier, { try await sonde.diag($0, tlvIdentite, delaiMs: delaiEnfant) }) {
            guard let rep = r.reponse else { continue }
            mem.identifies[cible] = EnfantMaillage(rloc16: cible, extMac: rep.extMac, adresses: rep.adresses, source: .tableEnfants)
        }
        for cible in c.enfantsSansIdentite {
            if let e = mem.identifies[cible] { c.enfant(e) }
        }
        return (c.maillage(), mem)
    }

    static func rloc16(_ routeur: Int) -> UInt16 { UInt16(routeur) << 10 }

    /// Enfants d'un routeur muet, numero par numero, 8 en vol : de 1 a 32, en
    /// s'arretant 8 numeros apres le dernier trouve (la sonde compte, sans etre interrogee).
    static func balayer(_ sonde: some InterlocuteurSonde, routeur m: Int, sauf moi: UInt16) async throws -> [EnfantMaillage] {
        var trouves: [EnfantMaillage] = []
        var dernier = moi >> 10 == UInt16(m) ? Int(moi & 0x1FF) : 0
        var debut = 1
        while debut <= min(numerosMax, dernier + apresDernier) {
            let fin = min(debut + enVol - 1, numerosMax, dernier + apresDernier)
            let cibles = (debut...fin).map { rloc16(m) | UInt16($0) }.filter { $0 != moi }
            for (cible, r) in try await parallele(cibles, { try await sonde.diag($0, tlvBalayage, delaiMs: delaiBalayage) }) {
                guard let rep = r.reponse else { continue }
                trouves.append(EnfantMaillage(rloc16: cible, extMac: rep.extMac, endormi: rep.mode?.endormi,
                                              adresses: rep.adresses, source: .balayage))
                dernier = max(dernier, Int(cible & 0x1FF))
            }
            debut = fin + 1
        }
        return trouves
    }

    /// Au plus `enVol` requetes a la fois ; resultats dans l'ordre des elements.
    static func parallele<E: Sendable>(_ elements: [E],
                                       _ requete: @escaping @Sendable (E) async throws -> ResultatDiag) async throws -> [(E, ResultatDiag)] {
        var resultats: [(Int, E, ResultatDiag)] = []
        try await withThrowingTaskGroup(of: (Int, E, ResultatDiag).self) { groupe in
            var suivant = 0
            func lancer() {
                let i = suivant
                suivant += 1
                let e = elements[i]
                groupe.addTask { (i, e, try await requete(e)) }
            }
            while suivant < min(enVol, elements.count) { lancer() }
            while let r = try await groupe.next() {
                resultats.append(r)
                if suivant < elements.count { lancer() }
            }
        }
        return resultats.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2) }
    }
}
