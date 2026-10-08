import AppKit
import MaillageCoeur
import Observation
import os

/// Chiffres du reseau affiche, pour la barre des menus.
struct ResumeReseau: Equatable {
    var nom: String
    var partitions: Int
    var routeurs: Int
    var appareils: Int
    /// Appareils Thread qui ne sont pas joignables (sans adresse, isoles, inconnus) ou disparus.
    var injoignables: Int
}

/// Modele de l'app : releves -> suivi -> journal et notifications ; maillages de la
/// sonde -> journal et historique ; noms ; etat lu par les vues.
@MainActor
@Observable
final class Surveillance {
    enum Mode: Equatable {
        /// Ecoute du reseau local, journal sur disque, notifications.
        case direct
        /// Panne du 27/09 rejouee, rien sur disque, pas de notification.
        case demo
    }

    enum EtatEcoute: Equatable {
        case demarrage, active, reseauLocalRefuse, demo
        case erreur(String)
    }

    let mode: Mode
    private(set) var etatEcoute: EtatEcoute
    private(set) var suivi = Suivi()
    /// Journal : evenements gardes (90 jours) puis ceux de la session, du plus ancien au plus recent.
    private(set) var evenements: [Evenement] = []
    private(set) var dernierReleve: Annonces?
    /// Date du premier releve vide recu alors qu'un instantane existe (le Mac
    /// n'entend plus rien : reseau local coupe, acces refuse) ; nil des qu'un
    /// releve non vide arrive.
    private(set) var rienVuDepuis: Date?
    private(set) var routesLisibles: Bool?
    private(set) var erreurJournal: String?
    var noms: ResolveurNoms
    /// Reseau affiche (`xp`) ; nil : le premier.
    var reseauChoisi: String?
    /// Dernier maillage de la sonde ; nil sans sonde.
    private(set) var maillage: Maillage?
    /// Reception du dernier maillage, a la fin de sa tournee : son age se compte
    /// depuis (le maillage, lui, est date du debut de sa tournee).
    private(set) var maillageRecu: Date?
    /// Une tournee de la sonde est en cours (`SondeMaillage.surTournee`) : le
    /// maillage affiche attend le suivant, il n'est pas « ancien ».
    var tourneeEnCours = false
    /// Historique de la sonde (spec de la sonde, section 6) : les releves des 30 derniers jours,
    /// du plus ancien au plus recent ; toujours vide en demo.
    private(set) var historique: [ReleveMaillage] = []
    /// Resolution des cles de l'historique (`ClesHistorique`), construite a la premiere demande et gardee jusqu'au
    /// prochain changement de l'historique : `recevoir` et `chargerHistorique` l'effacent (relecture, Mineur 3).
    @ObservationIgnored private var clesGardees: ClesHistorique?
    /// Nombre de resolutions construites : une par changement de l'historique au plus (lu par les tests).
    @ObservationIgnored private(set) var constructionsCles = 0

    /// Age du maillage de la sonde, depuis sa reception : frais jusqu'a 6 min (la
    /// tournee suivante part 5 min apres la fin de la precedente), et tant qu'une
    /// tournee est en cours ; ancien ensuite (la sonde ne repond plus) jusqu'a
    /// 15 min ; perime au-dela, tournee ou non (retour aux pointilles).
    enum Fraicheur: Equatable {
        case frais, ancien, perime
    }

    /// Branche sur les notifications (mode direct seulement).
    @ObservationIgnored var surAlertes: (([AlerteAEnvoyer]) -> Void)?
    @ObservationIgnored private let recenseur: Recenseur?
    @ObservationIgnored private let journal: JournalFichiers?
    @ObservationIgnored private let fichierSurnoms: URL?
    @ObservationIgnored private var alertes = Alertes()
    @ObservationIgnored private var suiviMaillage = SuiviMaillage()
    /// Historique sur disque : mode direct avec un dossier ; nil : nulle part (demo, tests).
    @ObservationIgnored private let fichiersHistorique: HistoriqueFichiers?
    /// Ou garder les scissions deja notifiees (`cleScissionsNotifiees`).
    @ObservationIgnored private let preferences: UserDefaults
    /// Scissions notifiees lues (au demarrage, en mode direct) : ecrites ensuite a
    /// chaque changement. Sinon (demo, surveillance pas demarree : tests), ni lues ni ecrites.
    @ObservationIgnored private var scissionsChargees = false
    /// Mois (annee, mois) de la derniere purge des fichiers ; nil : pas encore purges.
    @ObservationIgnored private var moisDernierePurge: DateComponents?
    @ObservationIgnored private var debutVeille: Date?
    @ObservationIgnored private var observateurs: [NSObjectProtocol] = []

    /// Signatures des scissions deja notifiees (`[String]`), d'un lancement a l'autre.
    static let cleScissionsNotifiees = "scissionsNotifiees"
    /// Historique garde en memoire : les courbes de la fiche vont jusqu'a 30 jours.
    static let dureeHistorique: TimeInterval = 30 * 24 * 3600
    /// Journal du Mac (Console, sous-systeme fr.djoko.maillage) : jamais de donnees du reseau.
    nonisolated static let journalMac = Logger(subsystem: "fr.djoko.maillage", category: "historique")

    /// Lance par les tests (heberges dans l'app) : ne rien ecouter ni ecrire.
    static var sousTests: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }

    /// Dossier de l'app : Application Support/Maillage Thread (dans le conteneur du bac a sable).
    static var dossierParDefaut: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Maillage Thread")
    }

    /// `dossier` : ou garder le journal, les surnoms et l'historique de la sonde (nil : nulle
    /// part) ; `preferences` : les scissions deja notifiees (mode direct, une fois demarree).
    init(mode: Mode, dossier: URL?, preferences: UserDefaults = .standard) {
        self.mode = mode
        self.preferences = preferences
        switch mode {
        case .direct:
            etatEcoute = .demarrage
            recenseur = Recenseur()
            journal = dossier.map { JournalFichiers(dossier: $0.appendingPathComponent("Journal")) }
            fichierSurnoms = dossier?.appendingPathComponent("surnoms.json")
            noms = ResolveurNoms(surnoms: fichierSurnoms.map(Surnoms.lire) ?? [:])
            fichiersHistorique = dossier.map { HistoriqueFichiers(dossier: $0) }
        case .demo:
            etatEcoute = .demo
            recenseur = nil
            journal = nil
            fichierSurnoms = nil
            noms = ResolveurNoms(maison: NomsDemo.maison)
            fichiersHistorique = nil
        }
    }

    func demarrer() {
        switch mode {
        case .demo:
            for a in ScenarioPanne.releves { integrer(a) }
            if let m = instantane.flatMap({ MaillageDemo.maillage($0, date: maintenant) }) {
                recevoir(m, a: maintenant)
            }
        case .direct:
            chargerScissionsNotifiees()
            chargerJournal()
            Task { [weak self] in await self?.chargerHistorique() }
            recenseur?.surReleve = { [weak self] a in self?.integrer(a) }
            recenseur?.surEtat = { [weak self] e in self?.noterEtat(e) }
            recenseur?.demarrer()
            observerVeille()
        }
    }

    /// Purge le journal (mois finis depuis plus de 90 jours) puis le lit. Une purge qui echoue
    /// (droits sur un vieux fichier) n'empeche pas la lecture. Sans dossier : rien.
    func chargerJournal() {
        guard let journal else { return }
        let maintenant = Date()
        moisDernierePurge = Calendar.current.dateComponents([.year, .month], from: maintenant)
        _ = try? journal.purger(maintenant: maintenant)
        do {
            evenements = try journal.lire()
        } catch {
            erreurJournal = error.localizedDescription
        }
    }

    /// Lit les scissions deja notifiees (au demarrage, mode direct) : un reseau
    /// qui reste scinde n'est pas notifie de nouveau a chaque lancement.
    func chargerScissionsNotifiees() {
        alertes.scissionsNotifiees = Set(preferences.stringArray(forKey: Self.cleScissionsNotifiees) ?? [])
        scissionsChargees = true
    }

    func arreter() {
        recenseur?.arreter()
        observateurs.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observateurs = []
    }

    /// Releve immediat.
    func rafraichir() {
        recenseur?.rafraichir()
    }

    /// Integre un releve : evenements, journal, notifications. Un releve vide ne
    /// change pas l'instantane (voir `Suivi`) : il est seulement note (`rienVuDepuis`).
    func integrer(_ a: Annonces) {
        dernierReleve = a
        routesLisibles = mode == .demo ? true : recenseur?.routesLisibles
        if !a.estVide {
            rienVuDepuis = nil
        } else if instantane != nil && rienVuDepuis == nil {
            rienVuDepuis = a.date
        }
        let nouveaux = suivi.integrer(a, noms: noms)
        ajouter(nouveaux)
    }

    /// Nouveau maillage de la sonde, recu a `date` (fin de sa tournee) : ses evenements vont au
    /// journal (changements de parent, routeurs Thread) ; en mode direct, son releve va a
    /// l'historique, en memoire et, avec un dossier, sur disque. Un echec d'ecriture est consigne
    /// dans le journal du Mac ; le releve reste en memoire.
    func recevoir(_ m: Maillage, a date: Date) {
        maillage = m
        maillageRecu = date
        ajouter(suiviMaillage.integrer(m, sujets: sujets(m)))
        guard mode == .direct else { return }
        let r = ReleveMaillage(m)
        let limite = date.addingTimeInterval(-Self.dureeHistorique)
        historique = historique.filter { $0.date >= limite } + [r]
        clesGardees = nil
        purgerSiNouveauMois(date)
        guard let f = fichiersHistorique else { return }
        do {
            try f.ajouter(r)
        } catch {
            Self.journalMac.error("releve de l'historique non ecrit : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Purge le journal et l'historique (mois finis depuis plus de 90 jours, comme au lancement)
    /// quand le mois de `date` n'est pas celui de la derniere purge : l'app de la barre des menus
    /// peut tourner des semaines sans etre relancee. Un echec est ignore : la purge reviendra au
    /// lancement suivant. Sans dossier (demo, tests) : rien.
    private func purgerSiNouveauMois(_ date: Date) {
        let mois = Calendar.current.dateComponents([.year, .month], from: date)
        guard mois != moisDernierePurge else { return }
        moisDernierePurge = mois
        _ = try? journal?.purger(maintenant: date)
        _ = try? fichiersHistorique?.purger(maintenant: date)
    }

    /// Relit les 30 derniers jours de l'historique, hors de l'acteur principal, apres avoir purge
    /// les mois finis depuis plus de 90 jours ; les releves recus entre-temps restent. Sans dossier
    /// (demo, tests) : rien.
    func chargerHistorique() async {
        guard let f = fichiersHistorique else { return }
        let maintenant = Date()
        moisDernierePurge = Calendar.current.dateComponents([.year, .month], from: maintenant)
        let debut = maintenant.addingTimeInterval(-Self.dureeHistorique)
        do {
            let lus = try await Task.detached(priority: .utility) {
                // Une purge qui echoue n'empeche pas la lecture.
                _ = try? f.purger(maintenant: maintenant)
                return try f.lire(depuis: debut)
            }.value
            // Les dates relues sont tronquees a la milliseconde (codage) : un releve recu pendant la
            // lecture, ecrit puis relu, garde jusqu'a 1 ms de moins que sa copie en memoire. Il n'est pas repris.
            let premier = (historique.first?.date ?? .distantFuture).addingTimeInterval(-0.001)
            historique = lus.filter { $0.date < premier } + historique
            clesGardees = nil
        } catch {
            Self.journalMac.error("historique illisible : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Rapprochement d'un maillage avec le reseau de sa partition (a defaut, le reseau affiche),
    /// frais ou non ; nil sans instantane.
    private func rapprochement(_ m: Maillage) -> MaillageAffiche? {
        guard let i = instantane,
              let r = i.reseaux.first(where: { r in r.partitions.contains { $0.id == m.partition } }) ?? reseau else {
            return nil
        }
        return MaillageAffiche(maillage: m, reseau: r, appareils: i.appareils + Array(suivi.disparus.values), trel: i.trel)
    }

    /// Noeuds d'un maillage pour le journal : leur id dans le graphe et leur nom affiche,
    /// d'apres le rapprochement avec le reseau de sa partition (a defaut, le reseau affiche). Un
    /// enfant identifie est d'abord l'appareil de meme ExtMac : vu deux fois (resolution ancienne,
    /// table), il n'a son id d'appareil qu'une fois dans le graphe.
    func sujets(_ m: Maillage) -> SujetsMaillage {
        let affiche = rapprochement(m)
        let appareils = (instantane?.appareils ?? []) + Array(suivi.disparus.values)
        func sujet(_ n: NoeudSonde?, rloc16: UInt16, genre: NoeudSonde.Genre, bordure: Bool) -> Sujet {
            let noeud = n ?? NoeudSonde(id: String(format: "rloc:%04X", rloc16), rloc16: rloc16, genre: genre,
                                        reconnu: false, bordure: bordure)
            return Sujet(id: noeud.id, nom: nomNoeud(noeud.id, maillage: affiche) ?? LibellesNoeuds.inconnu(noeud))
        }
        var s = SujetsMaillage()
        for r in m.routeurs {
            s.routeurs[r.id] = sujet(affiche?.routeurs[r.id], rloc16: r.rloc16, genre: .routeur, bordure: r.bordure)
        }
        for e in m.enfants {
            if let x = e.extMac, let a = appareils.first(where: { $0.id.uppercased() == x }) {
                s.enfants[e.rloc16] = Sujet(id: a.id, nom: nom(a))
            } else {
                s.enfants[e.rloc16] = sujet(affiche?.enfants[e.rloc16], rloc16: e.rloc16, genre: .enfant, bordure: false)
            }
        }
        return s
    }

    /// Appareils que la sonde doit resoudre (spec de la sonde tout-en-un, section 2.2) : ceux de l'instantane qui ont
    /// une adresse sur le prefixe OMR de leur partition, l'adresse nue ; aucun sans instantane.
    func appareilsAResoudre() -> [AppareilAResoudre] {
        instantane.map(AppareilAResoudre.depuis) ?? []
    }

    /// Sonde oubliee (`SondeMaillage.surOubli`) : son maillage part tout de suite, sans attendre
    /// qu'il soit perime ; le graphe revient aux pointilles. Son suivi aussi : le maillage suivant
    /// (une autre sonde, plus tard) est un point de depart, sans evenement. L'historique reste : il
    /// parle du reseau, pas de la sonde.
    func oublierMaillage() {
        maillage = nil
        maillageRecu = nil
        suiviMaillage = SuiviMaillage()
    }

    /// Veille du Mac (appele au reveil).
    func noterVeille(debut: Date, fin: Date) {
        ajouter(suivi.noterVeille(DateInterval(start: debut, end: max(fin, debut))))
    }

    /// Donne (ou retire, avec nil ou "") un surnom a un noeud.
    func renommer(_ id: String, en surnom: String?) {
        let s = surnom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        noms.surnoms[id] = s.isEmpty ? nil : s
        guard let fichierSurnoms else { return }
        do {
            try Surnoms.ecrire(noms.surnoms, dans: fichierSurnoms)
        } catch {
            erreurJournal = error.localizedDescription
        }
    }

    /// Dernier releve en JSON (option de capture).
    func captureJSON() throws -> Data? {
        try dernierReleve.map { try CodageJSON.encodeur(lisible: true).encode($0) }
    }

    private func ajouter(_ nouveaux: [Evenement]) {
        guard !nouveaux.isEmpty else { return }
        evenements.append(contentsOf: nouveaux)
        do {
            try journal?.ajouter(nouveaux)
        } catch {
            erreurJournal = error.localizedDescription
        }
        let notifiees = alertes.scissionsNotifiees
        let envoyer = alertes.traiter(nouveaux)
        if scissionsChargees && alertes.scissionsNotifiees != notifiees {
            preferences.set(alertes.scissionsNotifiees.sorted(), forKey: Self.cleScissionsNotifiees)
        }
        if mode == .direct && !envoyer.isEmpty { surAlertes?(envoyer) }
    }

    private func noterEtat(_ e: Recenseur.Etat) {
        switch e {
        case .demarrage: etatEcoute = .demarrage
        case .actif: etatEcoute = .active
        case .reseauLocalRefuse: etatEcoute = .reseauLocalRefuse
        case .erreur(let m): etatEcoute = .erreur(m)
        }
    }

    private func observerVeille() {
        let nc = NSWorkspace.shared.notificationCenter
        observateurs.append(nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.debutVeille = Date() }
        })
        observateurs.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let debut = self.debutVeille else { return }
                self.debutVeille = nil
                self.noterVeille(debut: debut, fin: Date())
                self.recenseur?.rafraichir()
            }
        })
    }

    // MARK: - Pour les vues

    var instantane: Instantane? { suivi.instantane }

    /// Reference a l'heure du Mac : la fraicheur du graphe et le maillage de la demo ; la fin de la
    /// panne rejouee en demo. La fiche passe par `maintenant(a:)`, a l'heure de sa fenetre.
    var maintenant: Date { maintenant(a: Date()) }

    /// Reference des durees a l'heure `horloge` (celle de la fenetre du graphe, que sa `TimelineView`
    /// avance chaque minute) : cette heure, ou la fin de la panne rejouee en demo.
    func maintenant(a horloge: Date) -> Date { mode == .demo ? (dernierReleve?.date ?? horloge) : horloge }

    var reseau: Reseau? {
        guard let i = instantane else { return nil }
        return reseauChoisi.flatMap { i.reseau($0) } ?? i.reseaux.first
    }

    var fabriqueApple: String? {
        guard let i = instantane else { return nil }
        return noms.fabriqueApple(appareils: i.appareils + i.appareilsIP + Array(suivi.disparus.values))
    }

    func nom(_ a: Appareil) -> String { noms.nom(appareil: a, fabriqueApple: fabriqueApple) }
    func nom(_ r: RouteurBordure) -> String { noms.nom(routeur: r) }

    /// Nom affiche de chaque routeur de bordure d'un reseau, par instance : libelles du graphe,
    /// fiche, candidats d'un routeur de bordure non identifie.
    func nomsRouteurs(pour r: Reseau) -> [String: String] {
        Dictionary(r.routeurs.map { ($0.instance, nom($0)) }, uniquingKeysWith: { a, _ in a })
    }

    /// La resolution des cles de l'historique, gardee (`clesGardees`).
    private var clesHistorique: ClesHistorique {
        if let c = clesGardees { return c }
        let c = ClesHistorique(releves: historique)
        clesGardees = c
        constructionsCles += 1
        return c
    }

    /// La resolution des cles de l'historique et l'indice du releve du maillage `m`, le dernier de l'historique (en mode
    /// direct, `recevoir` l'y ajoute) ; nil si tous les routeurs de `m` ont une ExtMac (rien a resoudre) ou si son releve
    /// n'est pas le dernier (demo : pas d'historique).
    private func resolution(_ m: Maillage) -> (cles: ClesHistorique, releve: Int)? {
        guard m.routeurs.contains(where: { $0.extMac == nil }), let dernier = historique.last,
              dernier.date == m.date, dernier.partition == m.partition else { return nil }
        return (clesHistorique, historique.count - 1)
    }

    /// Cle d'un routeur du dernier maillage dans l'historique, celle de ses courbes (verification du 05/10) : son
    /// ExtMac ; sans elle, celle que `ClesHistorique` donne au releve du maillage dans l'historique ; sinon "rloc:XXXX".
    private func cleHistorique(routeur r: RouteurMaillage, _ resolution: (cles: ClesHistorique, releve: Int)?) -> String {
        if let x = r.extMac { return x }
        guard let resolution else { return String(format: "rloc:%04X", r.rloc16) }
        return resolution.cles.cle(releve: resolution.releve, routeur: r.id)
    }

    /// Cle d'un noeud du graphe dans l'historique : pour un routeur du dernier maillage, sa cle
    /// (`cleHistorique(routeur:_:)` : son ExtMac, ou celle que l'historique lui connait, sinon "rloc:XXXX") ;
    /// pour un enfant, son ExtMac dans le dernier maillage ; sinon le `xa` de l'annonce
    /// d'un routeur de bordure, ou l'hote d'un appareil (l'ExtMac d'un appareil Matter, d'apres
    /// `GrapheReseau.extMac(hote:)`, comme la piece d'un noeud) ; nil si le noeud n'en a pas.
    func cleHistorique(noeud id: String) -> String? { cleHistorique(noeud: id, resoudre: true) }

    /// `resoudre` faux : un routeur sans ExtMac garde "rloc:XXXX", sans resolution (`evenements(de:)`, qui ne compare
    /// que l'ExtMac d'un enfant).
    private func cleHistorique(noeud id: String, resoudre: Bool) -> String? {
        if let m = maillage, let n = rapprochement(m)?.noeud(id) {
            switch n.genre {
            case .routeur:
                if let r = m.routeur(Int(n.rloc16 >> 10)) { return cleHistorique(routeur: r, resoudre ? resolution(m) : nil) }
            case .enfant:
                if let x = m.enfants.first(where: { $0.rloc16 == n.rloc16 })?.extMac { return x }
            }
        }
        if let xa = instantane?.routeur(id)?.adresseEtendue { return xa }
        return GrapheReseau.extMac(hote: id)
    }

    /// Noms de noeuds de l'historique, par cle : leur nom dans le graphe, si le dernier maillage
    /// ou l'instantane les connait ; la cle sinon. Un routeur du dernier maillage se reconnait a la cle
    /// de ses courbes (`cleHistorique(routeur:_:)`). Un enfant vu deux fois prend l'entree que retient
    /// le rapprochement (`Maillage.enfantsIdentifies`, precision 26 du plan 4b). Le rapprochement
    /// et la resolution des cles ne sont faits qu'une fois.
    func nomsHistorique(_ cles: Set<String>) -> [String: String] {
        let affiche = maillage.flatMap(rapprochement)
        let enfants = maillage?.enfantsIdentifies ?? [:]
        var routeurs: [(routeur: RouteurMaillage, cle: String)] = []
        if let m = maillage {
            let r = resolution(m)
            routeurs = m.routeurs.map { ($0, cleHistorique(routeur: $0, r)) }
        }
        func nomDe(_ cle: String) -> String {
            if let affiche {
                if let r = routeurs.first(where: { $0.cle == cle })?.routeur,
                   let n = affiche.routeurs[r.id], let x = nomNoeud(n.id, maillage: affiche) {
                    return x
                }
                if let e = enfants[cle], let n = affiche.enfants[e.rloc16], let x = nomNoeud(n.id, maillage: affiche) {
                    return x
                }
            }
            if let r = instantane?.routeurs.first(where: { $0.adresseEtendue == cle }) { return nom(r) }
            if let a = (instantane?.appareils ?? []).first(where: { $0.id.uppercased() == cle }) { return nom(a) }
            return cle
        }
        return Dictionary(uniqueKeysWithValues: cles.map { ($0, nomDe($0)) })
    }

    /// Courbes d'un noeud du graphe sur une periode qui finit a `fin` ; nil sans cle.
    func courbes(noeud id: String, periode: PeriodeCourbes, fin: Date) -> CourbesNoeud? {
        cleHistorique(noeud: id).map {
            CourbesNoeud(cle: $0, releves: historique, cles: clesHistorique, periode: periode, fin: fin)
        }
    }

    /// Nom affiche d'un noeud du graphe : routeur de bordure, appareil, ou noeud que seule la sonde
    /// connait (« Routeur · 5000 », candidats d'un routeur de bordure non identifie) ; nil s'il
    /// n'est nulle part.
    func nomNoeud(_ id: String, maillage m: MaillageAffiche?) -> String? {
        if let r = instantane?.routeur(id) { return nom(r) }
        if let a = appareil(id) { return nom(a) }
        guard let n = m?.noeud(id) else { return nil }
        let noms = Dictionary((instantane?.routeurs ?? []).map { ($0.instance, nom($0)) }, uniquingKeysWith: { a, _ in a })
        return LibellesNoeuds.inconnu(n, noms: noms)
    }
    func accessoire(_ a: Appareil) -> AccessoireMaison? { noms.accessoire(de: a, fabriqueApple: fabriqueApple) }

    /// Appareil par identifiant, present ou disparu.
    func appareil(_ id: String) -> Appareil? { instantane?.appareil(id) ?? suivi.disparus[id] }

    /// Appareils a dessiner pour un reseau : presents, puis disparus (a leur place).
    func appareilsAffiches(pour r: Reseau) -> [AppareilAffiche] {
        guard let i = instantane else { return [] }
        let premier = i.reseaux.first?.id == r.id
        func appartient(_ a: Appareil) -> Bool {
            if let x = a.idReseau { return x == r.id }
            // Derniere partition connue : l'appareil va au reseau qui la contient, et a lui seul.
            if let p = suivi.dernieresPartitions[a.id],
               let proprio = i.reseaux.first(where: { $0.partitions.contains { $0.id == p } }) {
                return proprio.id == r.id
            }
            return premier
        }
        func affiche(_ a: Appareil, _ etat: EtatAffiche) -> AppareilAffiche {
            let maison = accessoire(a)
            return AppareilAffiche(id: a.id, nom: nom(a), piece: maison?.piece,
                                   partition: a.partition ?? suivi.dernieresPartitions[a.id], etat: etat,
                                   endormi: a.endormi, batterie: maison?.batterie)
        }
        var liste = i.appareils.filter(appartient).map { a in
            let etat: EtatAffiche = switch a.etat {
            case .joignable: .joignable
            case .partitionCoupee: .partitionCoupee
            case .sansAdresse: .sansAdresse
            case .inconnu: .inconnu
            }
            return affiche(a, etat)
        }
        liste += suivi.disparus.values.filter(appartient).map { affiche($0, .disparu) }
        return liste
    }

    /// Fraicheur d'un maillage recu a `recu`.
    nonisolated static func fraicheur(_ recu: Date, maintenant: Date, tourneeEnCours: Bool = false) -> Fraicheur {
        let age = maintenant.timeIntervalSince(recu)
        if age > 15 * 60 { return .perime }
        return age <= 6 * 60 || tourneeEnCours ? .frais : .ancien
    }

    /// Fraicheur du maillage de la sonde a `maintenant` ; nil sans maillage.
    func fraicheurMaillage(a maintenant: Date) -> Fraicheur? {
        maillageRecu.map { Self.fraicheur($0, maintenant: maintenant, tourneeEnCours: tourneeEnCours) }
    }

    /// Maillage de la sonde rapproche d'un reseau ; nil sans sonde ou s'il est perime.
    func maillageAffiche(pour r: Reseau) -> MaillageAffiche? {
        guard let m = maillage, let i = instantane, fraicheurMaillage(a: maintenant) != .perime else {
            return nil
        }
        return MaillageAffiche(maillage: m, reseau: r, appareils: i.appareils + Array(suivi.disparus.values), trel: i.trel)
    }

    /// Le maillage affiche a ete recu il y a plus de 6 min, et aucune tournee n'est
    /// en cours : la sonde ne repond plus.
    var maillageAncien: Bool {
        fraicheurMaillage(a: maintenant) == .ancien
    }

    /// Chiffres du reseau affiche.
    var resume: ResumeReseau? {
        guard let i = instantane, let r = reseau else { return nil }
        let affiches = appareilsAffiches(pour: r)
        return ResumeReseau(nom: r.nom, partitions: r.partitions.count, routeurs: r.routeurs.count,
                            appareils: affiches.count,
                            injoignables: affiches.filter { $0.etat != .joignable }.count
                                + i.appareilsIP.filter { $0.etat != .joignable }.count)
    }

    /// Alerte en cours : un reseau scinde, ou un evenement grave dans l'heure.
    var alerte: Bool {
        if instantane?.reseaux.contains(where: \.estScinde) == true { return true }
        let recent = Date().addingTimeInterval(-3600)
        return evenements.reversed().prefix { $0.date >= recent }.contains { $0.gravite == .alerte }
    }

    var lignesJournal: [LigneJournal] { Regroupement.lignes(evenements) }

    /// Derniere scission du reseau (pour le bandeau : "depuis" ou "constate a").
    func derniereScission(_ r: Reseau) -> Evenement? {
        evenements.last { $0.type == .reseauScinde && $0.reseau == r.id }
    }

    /// 5 derniers evenements d'un noeud, du plus recent au plus ancien. Un evenement qui porte
    /// l'ExtMac d'un enfant (`details["extMac"]`) est le sien si c'est celle du noeud : l'id du
    /// sujet d'un enfant sans appareil (« rloc:XXXX ») change avec son parent. Sinon (evenement
    /// plus ancien, noeud sans ExtMac), l'id du sujet. Seuls les evenements d'un enfant portent une ExtMac : la cle
    /// d'un routeur n'a pas a etre resolue dans l'historique.
    func evenements(de id: String) -> [Evenement] {
        let ext = cleHistorique(noeud: id, resoudre: false)
        func concerne(_ e: Evenement) -> Bool {
            if let x = e.details["extMac"], let ext { return x == ext }
            return e.sujet?.id == id
        }
        return Array(evenements.reversed().filter(concerne).prefix(5))
    }
}
