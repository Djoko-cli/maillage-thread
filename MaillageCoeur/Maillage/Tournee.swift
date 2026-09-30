import Foundation

/// Ce que la tournee demande a la sonde : la liaison USB dans l'app, une sonde
/// rejouee dans les tests.
public protocol InterlocuteurSonde: Sendable {
    func etat() async throws -> EtatSonde
    /// Table des routeurs de la sonde (`routeurs`, lignes `suite` reunies) : tous les routeurs
    /// de la partition par leur RLOC16, l'ExtMac de ceux qu'elle entend. Requete locale, sans
    /// delai reseau.
    func routeurs() async throws -> [RouteurSonde]
    /// `DIAG_GET` vers un RLOC16 : la reponse, ou l'echec (`delai`, `occupee`...).
    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag
}

/// Avancement d'une tournee : l'etape en cours, ses requetes revenues et le total prevu a
/// ce moment. Au cours d'une etape, `fait` monte de un a chaque requete revenue et le total
/// ne baisse jamais. Liste des routeurs : le chef et les secours, puis, s'il faut chercher,
/// tous les autres identifiants ; l'etape s'arrete a la premiere Route64, souvent avant son
/// total. Balayage : pour chaque routeur, les numeros jusqu'a 8 apres le dernier enfant
/// trouve ; le total grandit quand un enfant repond loin, et finit egal aux requetes envoyees.
public struct AvancementTournee: Hashable, Sendable {
    /// Etapes d'une tournee, dans l'ordre.
    public enum Etape: CaseIterable, Hashable, Sendable {
        /// `etat` de la sonde, puis sa table des routeurs (`routeurs`).
        case etatSonde
        /// Route64 : au chef, aux secours, puis recherche.
        case listeRouteurs
        /// Interrogation des routeurs.
        case routeurs
        /// Pile (une fois par routeur qui repond) et Network Data.
        case pileEtReseau
        /// Balayage des enfants des routeurs muets.
        case balayage
        /// Identite des enfants des tables.
        case identites
    }

    public let etape: Etape
    /// Requetes de l'etape revenues.
    public let fait: Int
    /// Requetes prevues pour l'etape a ce moment ; 0 : rien a faire.
    public let total: Int

    public init(etape: Etape, fait: Int, total: Int) {
        self.etape = etape
        self.fait = fait
        self.total = total
    }
}

/// Ce que la tournee retient d'une fois sur l'autre (spec de la sonde, section 4).
public struct MemoireTournee: Hashable, Sendable {
    /// Silences de suite (`delai`), par routeur : muet a partir de 2. Un refus de la sonde
    /// (`occupee`, `suspendue`...) n'en est pas un.
    public var echecs: [Int: Int] = [:]
    /// Derniere interrogation d'un routeur muet : une fois par heure.
    public var muetInterroge: [Int: Date] = [:]
    /// Routeurs qui ont repondu au moins une fois depuis le debut de cette memoire :
    /// un seul echec ne les fait pas balayer, il faut qu'ils soient muets.
    public var dejaRepondu: Set<Int> = []
    /// Pile (TLV 28), demandee une fois par routeur qui repond ; "" : aucune.
    public var piles: [Int: String] = [:]
    /// ExtMac des routeurs, par RLOC16 : parents successifs de la sonde, routeurs qui repondent,
    /// routeurs que la sonde entend (sa table des routeurs). Une ExtMac n'a qu'un RLOC16 (`retenir`).
    public var identites: [UInt16: String] = [:]
    /// Enfants des routeurs balayes, trouves au dernier balayage (un balayage dont la sonde a
    /// refuse toutes les requetes ne compte pas).
    public var balayes: [UInt16: EnfantMaillage] = [:]
    /// Enfants des tables identifies (ExtMac, adresses), par RLOC16 : gardes jusqu'a une nouvelle reponse.
    public var identifies: [UInt16: EnfantMaillage] = [:]
    /// Derniere demande d'identite a un enfant des tables, par RLOC16 : une par demi-heure
    /// au plus, qu'il ait repondu ou non.
    public var identiteDemandee: [UInt16: Date] = [:]
    public var dernierBalayage: Date?
    /// Routeurs balayes la derniere fois (muets, ou qui n'ont jamais repondu) : un autre
    /// ensemble relance le balayage.
    public var muetsBalayes: Set<Int> = []
    /// Routeurs qui ont repondu a la derniere tournee ou l'un a repondu : Route64 de
    /// secours quand le chef ne la donne pas.
    public var repondants: [Int] = []
    /// Dernieres Network Data lues : elles servent quand leur requete echoue ou n'est pas faite
    /// (aucun routeur ne repond) ; sinon les routeurs de bordure, le BBR principal et les
    /// candidats disparaitraient d'une tournee a l'autre.
    public var donneesReseau: DonneesReseau?
    /// Partition de ce qui est retenu : une autre remet tout a zero.
    public var partition: String?

    public init() {}

    public func estMuet(_ id: Int) -> Bool { (echecs[id] ?? 0) >= 2 }

    /// Retient l'ExtMac d'un routeur. Un routeur qui a change d'identifiant (redemarrage) perd
    /// l'ancienne paire : elle ne donne plus son ExtMac a l'identifiant libere.
    mutating func retenir(_ ext: String, rloc16: UInt16) {
        for (r, e) in identites where e == ext && r != rloc16 { identites[r] = nil }
        identites[rloc16] = ext
    }
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

    /// Une tournee, et le balayage s'il est du : le maillage et la memoire a garder. Pas de
    /// maillage si la sonde n'est pas attachee, ou suspendue dans Maison (ses requetes
    /// echoueraient toutes : aucun routeur ne doit passer pour muet ; memoire inchangee), ou si
    /// aucun routeur n'a donne la liste des routeurs (Route64) : la memoire rendue est alors
    /// celle d'avant (remise a zero dans une autre partition), avec les seules identites
    /// apprises par `etat` et la table des routeurs, qu'une sonde promenee garde ainsi.
    /// `avancement` est appele au debut de chaque etape atteinte, puis a chaque requete
    /// revenue (voir `AvancementTournee`), depuis la tache de la tournee.
    public static func executer(_ sonde: some InterlocuteurSonde, memoire: MemoireTournee, maintenant: Date,
                                avancement: (@Sendable (AvancementTournee) -> Void)? = nil)
        async throws -> (maillage: Maillage?, memoire: MemoireTournee) {
        func signaler(_ etape: AvancementTournee.Etape, _ fait: Int, _ total: Int) {
            avancement?(AvancementTournee(etape: etape, fait: fait, total: total))
        }
        var mem = memoire
        signaler(.etatSonde, 0, 2)
        let etat = try await sonde.etat()
        signaler(.etatSonde, 1, 2)
        guard etat.estAttachee, !etat.suspendue, let partition = etat.partition, let chef = etat.chef,
              let moi = etat.rloc16Valeur else { return (nil, memoire) }
        // Autre partition : les identifiants de routeur y sont redistribues, rien ne vaut plus.
        if let ancienne = mem.partition, ancienne != partition { mem = MemoireTournee() }
        mem.partition = partition
        // Table des routeurs de la sonde (requete locale, sans delai reseau) : ExtMac des routeurs
        // qu'elle entend. Sans table (firmware sans `routeurs`, sonde occupee), la tournee continue.
        let table = (try? await sonde.routeurs()) ?? []
        signaler(.etatSonde, 2, 2)
        var c = ConstructionMaillage(date: maintenant, partition: partition)
        if let p = etat.parent, let rp = UInt16(p.rloc16, radix: 16) {
            mem.retenir(p.ext, rloc16: rp)
            c.enfant(EnfantMaillage(rloc16: moi, extMac: etat.ext, qualite: p.lqOut, source: .sonde))
        }
        for r in table {
            if let ext = r.ext, let rloc = r.rloc16Valeur { mem.retenir(ext, rloc16: rloc) }
        }

        // 1. Liste des routeurs : Route64 du chef, puis des routeurs qui ont repondu a la
        // tournee precedente (avant le chef s'il est muet) ; sinon, des autres identifiants.
        let secours = mem.repondants.filter { $0 != chef }
        let essais = mem.estMuet(chef) ? secours + [chef] : [chef] + secours
        var route64: Route64?
        signaler(.listeRouteurs, 0, essais.count)
        for (n, id) in essais.enumerated() {
            let r = try await sonde.diag(rloc16(id), tlvChef, delaiMs: delaiRouteur)
            signaler(.listeRouteurs, n + 1, essais.count)
            if let r64 = r.reponse?.route64 {
                route64 = r64
                break
            }
        }
        if route64 == nil {
            route64 = try await chercherRoute64(sonde, sauf: essais) { faites, prevues in
                signaler(.listeRouteurs, essais.count + faites, essais.count + prevues)
            }
        }
        guard let route64 else { return (nil, mem) }
        c.routeurs(route64, chef: chef)
        // Paires des routeurs sortis de la liste (routeur disparu, identifiant libere) : oubliees.
        let liste = Set(route64.routeurs)
        mem.identites = mem.identites.filter { liste.contains(Int($0.key >> 10)) }

        // 2. Chaque routeur, en parallele, sauf un muet deja interroge dans l'heure.
        let aInterroger = route64.routeurs.filter { id in
            guard mem.estMuet(id), let quand = mem.muetInterroge[id] else { return true }
            return maintenant.timeIntervalSince(quand) >= periodeMuet
        }
        signaler(.routeurs, 0, aInterroger.count)
        var repondants: [Int] = []
        let reponsesRouteurs = try await parallele(aInterroger, {
            try await sonde.diag(rloc16($0), tlvRouteur, delaiMs: delaiRouteur)
        }, apresChacune: { n, _, _ in signaler(.routeurs, n, aInterroger.count) })
        // Reponse trop longue pour le reseau : le routeur a repondu. Sa requete est refaite une
        // fois, en deux moities de TLV, reunies ; une moitie encore trop longue (ou sans reponse)
        // est laissee : ce qu'on a est garde, sans echec.
        let aCouper = reponsesRouteurs.filter { $0.1.tropLong }.flatMap { r in moities(tlvRouteur).map { (r.0, $0) } }
        var reunies: [Int: String] = [:]
        if !aCouper.isEmpty {
            let total = aInterroger.count + aCouper.count
            signaler(.routeurs, aInterroger.count, total)
            let reponsesMoities = try await parallele(aCouper, {
                try await sonde.diag(rloc16($0.0), $0.1, delaiMs: delaiRouteur)
            }, apresChacune: { n, _, _ in signaler(.routeurs, aInterroger.count + n, total) })
            for ((id, _), r) in reponsesMoities {
                if let t = r.tlv, r.reponse != nil { reunies[id, default: ""] += t }
            }
        }
        var sansExtMac: [Int] = []
        for (id, r) in reponsesRouteurs {
            if let rep = r.tropLong ? ReponseDiagnostic(hexa: reunies[id] ?? "") : r.reponse {
                c.reponse(rep, routeur: id)
                mem.echecs[id] = 0
                mem.muetInterroge[id] = nil
                mem.dejaRepondu.insert(id)
                if let ext = rep.extMac {
                    mem.retenir(ext, rloc16: rloc16(id))
                } else {
                    sansExtMac.append(id)
                }
                repondants.append(id)
            } else if r.silence {
                // Seul un silence compte : un refus de la sonde ne dit rien du routeur.
                mem.echecs[id, default: 0] += 1
                if mem.estMuet(id) { mem.muetInterroge[id] = maintenant }
            }
        }
        // Personne n'a repondu (sonde occupee...) : les secours d'avant restent.
        if !repondants.isEmpty { mem.repondants = repondants }
        let muets = Set(route64.routeurs).subtracting(repondants)
        for id in muets.sorted() { c.muet(id) }
        // Muets, et repondants sans ExtMac (moitie d'un `trop_long` sans reponse...) : l'identite
        // connue, lue apres toutes les reponses (une ExtMac passee a un autre routeur a oublie sa
        // paire perimee).
        for id in muets.sorted() + sansExtMac {
            if let ext = mem.identites[rloc16(id)] { c.identite(ext, routeur: id) }
        }

        // 3. Pile, une fois ; Network Data, a un routeur qui repond.
        let sansPile = repondants.filter { mem.piles[$0] == nil }
        let totalPile = sansPile.count + (repondants.isEmpty ? 0 : 1)
        signaler(.pileEtReseau, 0, totalPile)
        for (n, id) in sansPile.enumerated() {
            let r = try await sonde.diag(rloc16(id), tlvPile, delaiMs: delaiRouteur)
            signaler(.pileEtReseau, n + 1, totalPile)
            if let rep = r.reponse { mem.piles[id] = rep.pile ?? "" }
        }
        for id in repondants {
            c.pile(mem.piles[id].flatMap { $0.isEmpty ? nil : $0 }, routeur: id)
        }
        var lues: DonneesReseau?
        if let id = repondants.first {
            let r = try await sonde.diag(rloc16(id), tlvReseau, delaiMs: delaiRouteur)
            signaler(.pileEtReseau, totalPile, totalPile)
            if let brutes = r.reponse?.donneesReseau { lues = DonneesReseau(brutes) }
        }
        if let d = lues {
            c.reseau(d)
            mem.donneesReseau = d
        } else if let d = mem.donneesReseau {
            // Requete en echec, ou aucun routeur qui reponde : les dernieres lues, pour les seuls
            // routeurs de la liste.
            c.reseau(d, seulementConnus: true)
        }

        // 4. Balayage des enfants des routeurs sans reponse qui sont muets (deux echecs de
        // suite) ou n'ont jamais repondu ; pas d'un routeur qui rate une seule tournee.
        // Toutes les 30 min, ou si cet ensemble change. Les enfants trouves restent
        // affiches sous leur parent tant qu'il ne repond pas.
        let aBalayer = muets.filter { mem.estMuet($0) || !mem.dejaRepondu.contains($0) }
        let du = mem.dernierBalayage.map { maintenant.timeIntervalSince($0) >= periodeBalayage } ?? true
        if du || (!aBalayer.isEmpty && aBalayer != mem.muetsBalayes) {
            let routeurs = aBalayer.sorted()
            // Total courant : les numeros prevus de chaque routeur a ce moment (voir `AvancementTournee`).
            var prevues = routeurs.map { numerosPrevus(routeur: $0, dernier: dernierConnu(routeur: $0, sauf: moi), sauf: moi) }
            var faitesAvant = 0
            signaler(.balayage, 0, prevues.reduce(0, +))
            var trouves: [UInt16: EnfantMaillage] = [:]
            var refuse = true
            for (i, m) in routeurs.enumerated() {
                var faites = 0
                let b = try await balayer(sonde, routeur: m, sauf: moi) { f, p in
                    faites = f
                    prevues[i] = p
                    signaler(.balayage, faitesAvant + f, prevues.reduce(0, +))
                }
                for e in b.enfants { trouves[e.rloc16] = e }
                refuse = refuse && b.refuse
                faitesAvant += faites
            }
            // Toutes ses requetes refusees par la sonde : il ne dit rien des enfants. Le precedent
            // reste, et le balayage est refait a la tournee suivante.
            if !refuse {
                mem.balayes = trouves
                mem.dernierBalayage = maintenant
                mem.muetsBalayes = aBalayer
            }
        } else {
            signaler(.balayage, 0, 0)
        }
        for e in mem.balayes.values.sorted(by: { $0.rloc16 < $1.rloc16 }) where muets.contains(e.parent) {
            c.enfant(e)
        }

        // 5. Enfants des tables : ExtMac et adresses, gardees jusqu'a une nouvelle reponse ;
        // demandees de nouveau apres 30 min, que l'enfant ait repondu ou non.
        // Endormis sous un routeur qui repond : interroges au plus une fois par demi-heure, la Child Table ne donnant pas leur ExtMac.
        let aIdentifier = c.enfantsSansIdentite.filter { cible in
            mem.identiteDemandee[cible].map { maintenant.timeIntervalSince($0) >= periodeBalayage } ?? true
        }
        for cible in aIdentifier { mem.identiteDemandee[cible] = maintenant }
        signaler(.identites, 0, aIdentifier.count)
        let identites = try await parallele(aIdentifier, {
            try await sonde.diag($0, tlvIdentite, delaiMs: delaiEnfant)
        }, apresChacune: { n, _, _ in signaler(.identites, n, aIdentifier.count) })
        for (cible, r) in identites {
            guard let rep = r.reponse else { continue }
            mem.identifies[cible] = EnfantMaillage(rloc16: cible, extMac: rep.extMac, adresses: rep.adresses, source: .tableEnfants)
        }
        for cible in c.enfantsSansIdentite {
            if let e = mem.identifies[cible] { c.enfant(e) }
        }
        return (c.maillage(), mem)
    }

    static func rloc16(_ routeur: Int) -> UInt16 { UInt16(routeur) << 10 }

    /// Une requete coupee en deux moities de TLV (reponse trop longue pour le reseau).
    static func moities(_ tlv: [UInt8]) -> [[UInt8]] {
        let milieu = tlv.count / 2
        return [Array(tlv[..<milieu]), Array(tlv[milieu...])].filter { !$0.isEmpty }
    }

    /// Route64 quand ni le chef ni les secours ne l'ont donnee (chef muet des le lancement) :
    /// les autres identifiants de routeur, de 0 a 62, par groupes de 8 dans l'ordre croissant ;
    /// au premier groupe ou l'un la donne, celle du plus petit. `suivi` : requetes revenues
    /// et prevues (tous ces identifiants), au debut puis a chaque requete revenue.
    static func chercherRoute64(_ sonde: some InterlocuteurSonde, sauf essayes: [Int],
                                suivi: (_ faites: Int, _ prevues: Int) -> Void = { _, _ in }) async throws -> Route64? {
        let ids = (0...62).filter { !essayes.contains($0) }
        suivi(0, ids.count)
        for debut in stride(from: 0, to: ids.count, by: enVol) {
            let groupe = Array(ids[debut..<min(debut + enVol, ids.count)])
            let resultats = try await parallele(groupe, {
                try await sonde.diag(rloc16($0), tlvChef, delaiMs: delaiRouteur)
            }, apresChacune: { n, _, _ in suivi(debut + n, ids.count) })
            for (_, r) in resultats {
                if let route64 = r.reponse?.route64 { return route64 }
            }
        }
        return nil
    }

    /// Dernier numero d'enfant connu sous un routeur avant son balayage : celui de la
    /// sonde si elle est son enfant (elle compte, sans etre interrogee).
    static func dernierConnu(routeur m: Int, sauf moi: UInt16) -> Int {
        moi >> 10 == UInt16(m) ? Int(moi & 0x1FF) : 0
    }

    /// Requetes prevues sous un routeur : de 1 a 8 numeros apres le dernier trouve (32 au
    /// plus), la sonde exceptee.
    static func numerosPrevus(routeur m: Int, dernier: Int, sauf moi: UInt16) -> Int {
        (1...min(numerosMax, dernier + apresDernier)).count(where: { rloc16(m) | UInt16($0) != moi })
    }

    /// Enfants d'un routeur muet, numero par numero, 8 en vol : de 1 a 32, en
    /// s'arretant 8 numeros apres le dernier trouve (la sonde compte, sans etre interrogee).
    /// `refuse` : la sonde a refuse toutes les requetes. `suivi` : requetes revenues et prevues
    /// sous ce routeur, a chaque requete revenue ; un enfant qui repond loin repousse la fin tout
    /// de suite.
    static func balayer(_ sonde: some InterlocuteurSonde, routeur m: Int, sauf moi: UInt16,
                        suivi: (_ faites: Int, _ prevues: Int) -> Void = { _, _ in }) async throws
        -> (enfants: [EnfantMaillage], refuse: Bool) {
        var trouves: [EnfantMaillage] = []
        var refuse = true
        var dernier = dernierConnu(routeur: m, sauf: moi)
        var debut = 1
        var faites = 0
        while debut <= min(numerosMax, dernier + apresDernier) {
            let fin = min(debut + enVol - 1, numerosMax, dernier + apresDernier)
            let cibles = (debut...fin).map { rloc16(m) | UInt16($0) }.filter { $0 != moi }
            let avant = faites
            let resultats = try await parallele(cibles, {
                try await sonde.diag($0, tlvBalayage, delaiMs: delaiBalayage)
            }, apresChacune: { n, cible, r in
                if r.reponse != nil { dernier = max(dernier, Int(cible & 0x1FF)) }
                suivi(avant + n, numerosPrevus(routeur: m, dernier: dernier, sauf: moi))
            })
            for (cible, r) in resultats {
                refuse = refuse && r.refus
                guard let rep = r.reponse else { continue }
                trouves.append(EnfantMaillage(rloc16: cible, extMac: rep.extMac, endormi: rep.mode?.endormi,
                                              adresses: rep.adresses, source: .balayage))
            }
            faites += cibles.count
            debut = fin + 1
        }
        return (trouves, refuse)
    }

    /// Au plus `enVol` requetes a la fois ; resultats dans l'ordre des elements.
    /// `apresChacune` : a chaque requete revenue, le nombre de revenues, l'element et son resultat.
    static func parallele<E: Sendable>(_ elements: [E],
                                       _ requete: @escaping @Sendable (E) async throws -> ResultatDiag,
                                       apresChacune: (_ faites: Int, _ element: E, _ resultat: ResultatDiag) -> Void = { _, _, _ in })
        async throws -> [(E, ResultatDiag)] {
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
                apresChacune(resultats.count, r.1, r.2)
                if suivant < elements.count { lancer() }
            }
        }
        return resultats.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2) }
    }
}

fileprivate extension ResultatDiag {
    /// Silence de la cible : la requete est partie, et rien n'est revenu a temps (`delai`).
    var silence: Bool { !ok && erreur == "delai" }

    /// Refus de la sonde (`occupee`, `suspendue`, `envoi...`) : la requete n'est pas partie. Ni
    /// reponse ni silence, il ne dit rien de la cible.
    var refus: Bool { !ok && !tropLong && !silence }
}
