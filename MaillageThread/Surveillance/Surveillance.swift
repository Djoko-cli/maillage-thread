import AppKit
import MaillageCoeur
import Observation

/// Chiffres du reseau affiche, pour la barre des menus.
struct ResumeReseau: Equatable {
    var nom: String
    var partitions: Int
    var routeurs: Int
    var appareils: Int
    /// Appareils Thread qui ne sont pas joignables (sans adresse, isoles, inconnus) ou disparus.
    var injoignables: Int
}

/// Modele de l'app : releves -> suivi -> journal et notifications ; noms ;
/// etat lu par les vues.
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
    /// Ou garder les scissions deja notifiees (`cleScissionsNotifiees`).
    @ObservationIgnored private let preferences: UserDefaults
    /// Scissions notifiees lues (au demarrage, en mode direct) : ecrites ensuite a
    /// chaque changement. Sinon (demo, surveillance pas demarree : tests), ni lues ni ecrites.
    @ObservationIgnored private var scissionsChargees = false
    @ObservationIgnored private var debutVeille: Date?
    @ObservationIgnored private var observateurs: [NSObjectProtocol] = []

    /// Signatures des scissions deja notifiees (`[String]`), d'un lancement a l'autre.
    static let cleScissionsNotifiees = "scissionsNotifiees"

    /// Lance par les tests (heberges dans l'app) : ne rien ecouter ni ecrire.
    static var sousTests: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }

    /// Dossier de l'app : Application Support/Maillage Thread (dans le conteneur du bac a sable).
    static var dossierParDefaut: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Maillage Thread")
    }

    /// `dossier` : ou garder le journal et les surnoms (nil : nulle part) ;
    /// `preferences` : les scissions deja notifiees (mode direct, une fois demarree).
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
        case .demo:
            etatEcoute = .demo
            recenseur = nil
            journal = nil
            fichierSurnoms = nil
            noms = ResolveurNoms(maison: NomsDemo.maison)
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
            if let journal {
                do {
                    try journal.purger(maintenant: Date())
                    evenements = try journal.lire()
                } catch {
                    erreurJournal = error.localizedDescription
                }
            }
            recenseur?.surReleve = { [weak self] a in self?.integrer(a) }
            recenseur?.surEtat = { [weak self] e in self?.noterEtat(e) }
            recenseur?.demarrer()
            observerVeille()
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

    /// Nouveau maillage de la sonde, recu a `date` (fin de sa tournee).
    func recevoir(_ m: Maillage, a date: Date) {
        maillage = m
        maillageRecu = date
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

    /// Reference des durees affichees ("vu il y a...") : la fin de la panne rejouee en demo.
    var maintenant: Date { mode == .demo ? (dernierReleve?.date ?? Date()) : Date() }

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
        return MaillageAffiche(maillage: m, reseau: r, appareils: i.appareils + Array(suivi.disparus.values))
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

    /// 5 derniers evenements d'un noeud, du plus recent au plus ancien.
    func evenements(de id: String) -> [Evenement] {
        Array(evenements.reversed().filter { $0.sujet?.id == id }.prefix(5))
    }
}
