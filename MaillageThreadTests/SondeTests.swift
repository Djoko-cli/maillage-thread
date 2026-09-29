import Foundation
import MaillageCoeur
import Observation
import Synchronization
import Testing
@testable import MaillageThread

/// Canal rejoue : chaque commande envoyee produit les lignes que `repondre` donne.
final class CanalRejoue: CanalSonde {
    private struct Etat {
        var suite: AsyncStream<Data>.Continuation?
        var envoyes: [String] = []
    }

    private let etat = Mutex(Etat())
    let repondre: @Sendable (String) -> [String]

    init(repondre: @escaping @Sendable (String) -> [String]) {
        self.repondre = repondre
    }

    func ouvrir() throws -> AsyncStream<Data> {
        let (flux, suite) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .unbounded)
        etat.withLock { $0.suite = suite }
        return flux
    }

    func envoyer(_ ligne: String) {
        let reponses = repondre(ligne)
        etat.withLock { e in
            e.envoyes.append(ligne)
            for r in reponses { e.suite?.yield(Data(r.utf8)) }
        }
    }

    /// Lignes spontanees de la sonde.
    func emettre(_ lignes: [String]) {
        etat.withLock { e in
            for r in lignes { e.suite?.yield(Data(r.utf8)) }
        }
    }

    func fermer() {
        etat.withLock { $0.suite?.finish() }
    }

    var envoyes: [String] { etat.withLock { $0.envoyes } }

    static let bonjour = #"{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.0","mac":"A00000000001","appairee":true,"code":null,"qr":null}"#
    static let etatDetache = #"{"v":1,"t":"etat","role":"detached","rloc16":"FFFE","mode":"rn","parent":null,"partition":null,"chef":null,"canal":25,"prefixeMaille":null,"xp":null,"suspendue":false}"#

    static func diag(_ id: Int, _ cible: String, tlv: String) -> String {
        #"{"v":1,"t":"diag","id":\#(id),"cible":"\#(cible)","ms":40,"ok":true,"code":"2.04","tlv":"\#(tlv)"}"#
    }

    /// Sonde attachee (valeurs inventees) : enfant 0001 du routeur 0, qui est le chef.
    static let etatAttache = #"{"v":1,"t":"etat","role":"child","rloc16":"0001","mode":"rn","parent":null,"partition":"0000000A","chef":0,"canal":25,"prefixeMaille":"FD00000000000000","xp":null,"suspendue":false}"#

    /// Reseau d'un seul routeur, le chef 0, qui ne donne que sa Route64 : la tournee
    /// aboutit (maillage d'un routeur muet, sans enfant). `diag <cible> <tlv> <id> <ms>` :
    /// la Route64 a la demande de la liste des routeurs, `delai` a toute autre requete.
    static func reseauMinimal(_ ligne: String) -> [String] {
        switch ligne {
        case "bonjour\n": return [bonjour]
        case "etat\n": return [etatAttache]
        default: break
        }
        let mots = ligne.trimmingCharacters(in: .newlines).split(separator: " ").map(String.init)
        guard mots.count >= 4, mots[0] == "diag", let id = Int(mots[3]) else { return [] }
        if mots[1] == "0000" && mots[2] == "5,6" { return [diag(id, "0000", tlv: "050A01800000000000000001")] }
        return [#"{"v":1,"t":"diag","id":\#(id),"cible":"\#(mots[1])","ok":false,"erreur":"delai"}"#]
    }
}

/// Horloge des tests, avancee a la main (ou par un canal, pendant une tournee).
final class HorlogeFactice: Sendable {
    private let t: Mutex<Date>

    init(_ debut: Date) {
        t = Mutex(debut)
    }

    var maintenant: Date { t.withLock { $0 } }

    func avancer(_ secondes: TimeInterval) {
        t.withLock { $0 += secondes }
    }
}

/// Journal commun a des canaux de test ; on peut y attendre une ligne.
final class JournalCanaux: Sendable {
    private struct Etat {
        var lignes: [String] = []
        var attentes: [(ligne: String, suite: CheckedContinuation<Void, Never>)] = []
    }

    private let etat = Mutex(Etat())

    func noter(_ ligne: String) {
        let prets = etat.withLock { e in
            e.lignes.append(ligne)
            let prets = e.attentes.filter { $0.ligne == ligne }.map(\.suite)
            e.attentes.removeAll { $0.ligne == ligne }
            return prets
        }
        for p in prets { p.resume() }
    }

    /// Rend la main une fois `ligne` notee (tout de suite si elle l'est deja).
    func attendre(_ ligne: String) async {
        await withCheckedContinuation { (suite: CheckedContinuation<Void, Never>) in
            let deja = etat.withLock { e in
                guard !e.lignes.contains(ligne) else { return true }
                e.attentes.append((ligne, suite))
                return false
            }
            if deja { suite.resume() }
        }
    }

    var lignes: [String] { etat.withLock { $0.lignes } }

    /// Ouvertures, fermetures et fins de flux, sans les commandes.
    var cycle: [String] {
        lignes.filter { l in ["ouvrir", "fermer", "fin"].contains(l.split(separator: " ").first.map(String.init)) }
    }
}

/// Canal de test de la connexion : note au journal ses ouvertures, sa fermeture,
/// la fin de son flux (le port vraiment ferme) et les commandes recues. Il peut
/// retenir la reponse a `bonjour`, et finir son flux en differe, comme la liaison
/// serie qui ferme le port sur sa file.
final class CanalTemoin: CanalSonde {
    let nom: String
    let journal: JournalCanaux
    let retenirBonjour: Bool
    let fermetureDifferee: Duration?
    private let suite = Mutex<AsyncStream<Data>.Continuation?>(nil)

    init(_ nom: String, journal: JournalCanaux, retenirBonjour: Bool = false, fermetureDifferee: Duration? = nil) {
        self.nom = nom
        self.journal = journal
        self.retenirBonjour = retenirBonjour
        self.fermetureDifferee = fermetureDifferee
    }

    func ouvrir() throws -> AsyncStream<Data> {
        let (flux, s) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .unbounded)
        suite.withLock { $0 = s }
        journal.noter("ouvrir \(nom)")
        return flux
    }

    func envoyer(_ ligne: String) {
        let commande = ligne.trimmingCharacters(in: .newlines)
        journal.noter("\(commande) \(nom)")
        switch commande {
        case "bonjour" where !retenirBonjour: repondre(CanalRejoue.bonjour)
        case "etat": repondre(CanalRejoue.etatDetache)
        default: break
        }
    }

    /// La reponse retenue a `bonjour` arrive enfin.
    func libererBonjour() {
        repondre(CanalRejoue.bonjour)
    }

    private func repondre(_ l: String) {
        suite.withLock { _ = $0?.yield(Data(l.utf8)) }
    }

    /// Une seule fermeture effective ; rien a fermer si le canal n'a pas ete ouvert.
    func fermer() {
        guard let s = suite.withLock({ s in
            defer { s = nil }
            return s
        }) else { return }
        journal.noter("fermer \(nom)")
        guard let d = fermetureDifferee else {
            journal.noter("fin \(nom)")
            s.finish()
            return
        }
        let journal = journal, nom = nom
        Task {
            try? await Task.sleep(for: d)
            journal.noter("fin \(nom)")
            s.finish()
        }
    }
}

@Suite("Sonde USB : commandes et reponses")
struct SondeUSBTests {
    /// bonjour et etat, dans l'ordre.
    @Test func bonjourEtat() async throws {
        let canal = CanalRejoue { l in
            l == "bonjour\n" ? [CanalRejoue.bonjour] : l == "etat\n" ? [CanalRejoue.etatDetache] : []
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        let b = try await s.bonjour()
        #expect(b.estSonde && b.version == "1.0.0")
        let e = try await s.etat()
        #expect(e.role == "detached" && !e.estAttachee)
        #expect(canal.envoyes == ["bonjour\n", "etat\n"])
    }

    /// Deux diag en vol : la seconde reponse arrive avant la premiere, chacune va a son id.
    @Test func diagDansLeDesordre() async throws {
        let canal = CanalRejoue { l in
            // La reponse a la premiere requete ne part qu'avec la seconde.
            l.hasPrefix("diag 0400") ? [CanalRejoue.diag(2, "0400", tlv: "01020400"), CanalRejoue.diag(1, "5000", tlv: "01025000")] : []
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        async let a = s.diag(0x5000, [1], delaiMs: 3000)
        try await Task.sleep(for: .milliseconds(50))
        async let b = s.diag(0x0400, [1], delaiMs: 3000)
        let (ra, rb) = try await (a, b)
        #expect(ra.reponse?.rloc16 == 0x5000)
        #expect(rb.reponse?.rloc16 == 0x0400)
        #expect(canal.envoyes == ["diag 5000 1 1 3000\n", "diag 0400 1 2 3000\n"])
    }

    /// Sans reponse de la sonde : `delai` apres le delai donne et la marge.
    @Test func delai() async throws {
        let s = SondeUSB(canal: CanalRejoue { _ in [] }, marge: .milliseconds(50))
        try await s.demarrer {}
        let r = try await s.diag(0x5000, [1], delaiMs: 0)
        #expect(!r.ok && r.erreur == "delai")
        await #expect(throws: SondeUSB.Erreur.sansReponse("bonjour")) { try await s.bonjour() }
    }

    /// Liaison fermee : les attentes sont liberees, les commandes suivantes refusees.
    @Test func fermeture() async throws {
        let canal = CanalRejoue { _ in [] }
        let s = SondeUSB(canal: canal)
        let fermee = Mutex(false)
        try await s.demarrer { fermee.withLock { $0 = true } }
        let requete = Task { try await s.diag(0x5000, [1], delaiMs: 30000) }
        try await Task.sleep(for: .milliseconds(50))
        canal.fermer()
        await #expect(throws: SondeUSB.Erreur.fermee) { _ = try await requete.value }
        await #expect(throws: SondeUSB.Erreur.fermee) { _ = try await s.etat() }
        try await Task.sleep(for: .milliseconds(50))
        #expect(fermee.withLock { $0 })
    }

    /// Un bonjour non demande : la sonde vient de redemarrer.
    @Test func bonjourSpontane() async throws {
        let canal = CanalRejoue { _ in [] }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        canal.emettre([CanalRejoue.bonjour])
        try await Task.sleep(for: .milliseconds(50))
        #expect(await s.bonjourSpontane?.version == "1.0.0")
    }

    /// fermer rend la main une fois le flux fini (le port vraiment ferme), meme
    /// quand le canal le finit en differe.
    @Test func fermerAttendLaFinDuFlux() async throws {
        let journal = JournalCanaux()
        let s = SondeUSB(canal: CanalTemoin("1", journal: journal, fermetureDifferee: .milliseconds(50)))
        try await s.demarrer {}
        await s.fermer()
        #expect(journal.cycle == ["ouvrir 1", "fermer 1", "fin 1"])
        #expect(await s.fermee)
    }

    /// Fermee avant d'avoir demarre (connexion abandonnee) : le canal ne s'ouvre plus.
    @Test func fermeeAvantDeDemarrer() async throws {
        let journal = JournalCanaux()
        let s = SondeUSB(canal: CanalTemoin("1", journal: journal))
        await s.fermer()
        await #expect(throws: SondeUSB.Erreur.fermee) { try await s.demarrer {} }
        #expect(journal.cycle.isEmpty)
    }
}

@MainActor
@Suite("Sonde dans l'app : port retenu, refus, fraicheur du maillage")
struct SondeMaillageTests {
    static func preferences() throws -> (UserDefaults, String) {
        let domaine = "fr.djoko.maillage.tests.sonde.\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: domaine)), domaine)
    }

    static let port = PortUSB(chemin: "/dev/cu.usbmodem11301", vid: 0x303A, pid: 0x1001, serie: "A0:00:00:00:00:01",
                              produit: "USB JTAG/serial debug unit")

    /// Attend, sans delai, que `condition` soit vraie : elle est relue a chaque
    /// changement observe de ce qu'elle lit.
    static func attendre(_ condition: () -> Bool) async {
        while !condition() {
            await withCheckedContinuation { (suite: CheckedContinuation<Void, Never>) in
                withObservationTracking { _ = condition() } onChange: { suite.resume() }
            }
        }
    }

    static func connectee(_ s: SondeMaillage) -> Bool {
        if case .connectee = s.etat { true } else { false }
    }

    /// Un port qui repond en sonde est retenu (numero de serie USB) ; oublier le retire.
    @Test func retenue() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let canal = CanalRejoue { l in l == "bonjour\n" ? [CanalRejoue.bonjour] : l == "etat\n" ? [CanalRejoue.etatDetache] : [] }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        await s.connecter(Self.port, choisi: true)
        guard case .connectee(let b) = s.etat else {
            Issue.record("etat \(s.etat)")
            return
        }
        #expect(b.version == "1.0.0")
        #expect(p.string(forKey: SondeMaillage.cleSerie) == "A0:00:00:00:00:01")
        s.oublier()
        #expect(s.etat == .sansSonde)
        #expect(p.string(forKey: SondeMaillage.cleSerie) == nil)
    }

    /// Un autre C6 (le pont Halo) n'est pas une sonde : refuse, rien de retenu.
    @Test func refusee() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let halo = #"{"v":1,"t":"bonjour","produit":"pont-halo","version":"0.4.0","mac":null,"appairee":true,"code":null,"qr":null}"#
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in CanalRejoue { _ in [halo] } })
        await s.connecter(Self.port, choisi: true)
        guard case .refusee(let m) = s.etat else {
            Issue.record("etat \(s.etat)")
            return
        }
        #expect(m.contains("pont-halo"))
        #expect(p.string(forKey: SondeMaillage.cleSerie) == nil)
    }

    /// La sonde retenue debranchee : absente.
    @Test func debranchee() throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in CanalRejoue { _ in [] } })
        s.portsChanges([])
        #expect(s.etat == .absente)
    }

    /// « Oublier » pendant la verification du port (bonjour encore sans reponse) :
    /// la connexion en cours est abandonnee et son port ferme ; rien n'est retenu.
    @Test func oublierPendantLaConnexion() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        let canal = CanalTemoin("1", journal: journal, retenirBonjour: true)
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        let connexion = Task { await s.connecter(Self.port, choisi: true) }
        await journal.attendre("bonjour 1")
        s.oublier()
        // La reponse arrive apres coup : elle ne change plus rien.
        canal.libererBonjour()
        await connexion.value
        #expect(s.etat == .sansSonde)
        #expect(s.serie == nil)
        #expect(p.string(forKey: SondeMaillage.cleSerie) == nil)
        #expect(journal.cycle == ["ouvrir 1", "fermer 1", "fin 1"])
    }

    /// Deux changements de ports de suite, la sonde retenue branchee : une seule connexion.
    @Test func deuxChangementsDePorts() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        let journal = JournalCanaux()
        var canaux = 0
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in
            canaux += 1
            return CanalTemoin("\(canaux)", journal: journal)
        })
        s.portsChanges([Self.port])
        s.portsChanges([Self.port])
        await Self.attendre { Self.connectee(s) }
        #expect(canaux == 1)
        #expect(journal.cycle == ["ouvrir 1"])
        s.oublier()
    }

    /// Choisir le port de la sonde deja connectee : rien n'est ferme ni rouvert.
    @Test func choisirLePortConnecte() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        var canaux = 0
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in
            canaux += 1
            return CanalTemoin("\(canaux)", journal: journal)
        })
        await s.connecter(Self.port, choisi: true)
        #expect(Self.connectee(s))
        s.choisir(Self.port)
        // Une connexion lancee par `choisir` passerait avant la suite du test
        // (meme acteur, dans l'ordre) et creerait son canal.
        await Task.yield()
        #expect(canaux == 1)
        #expect(Self.connectee(s))
        #expect(journal.cycle == ["ouvrir 1"])
        s.oublier()
    }

    /// Reconnexion : l'ancienne liaison est vraiment fermee (fin de son flux)
    /// avant que la nouvelle ne s'ouvre ; sinon le port serait encore tenu.
    @Test func reconnexion() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        var canaux = 0
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in
            canaux += 1
            // Fin du flux en differe, comme la liaison serie qui ferme le port sur sa file.
            return CanalTemoin("\(canaux)", journal: journal, fermetureDifferee: .milliseconds(50))
        })
        await s.connecter(Self.port, choisi: true)
        await s.connecter(Self.port, choisi: true)
        #expect(Self.connectee(s))
        #expect(journal.cycle == ["ouvrir 1", "fermer 1", "fin 1", "ouvrir 2"])
        s.oublier()
    }

    /// En demo et sous tests : rien de lu.
    @Test func inactive() throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        #expect(SondeMaillage(preferences: p, actif: false).serie == nil)
    }

    /// Age compte depuis la reception : frais jusqu'a 6 min, ancien jusqu'a 15, perime
    /// ensuite ; pendant une tournee, jamais ancien, mais perime apres 15 min.
    @Test func fraicheur() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(Surveillance.fraicheur(t, maintenant: t + 300) == .frais)
        #expect(Surveillance.fraicheur(t, maintenant: t + 7 * 60) == .ancien)
        #expect(Surveillance.fraicheur(t, maintenant: t + 16 * 60) == .perime)
        #expect(Surveillance.fraicheur(t, maintenant: t + 7 * 60, tourneeEnCours: true) == .frais)
        #expect(Surveillance.fraicheur(t, maintenant: t + 16 * 60, tourneeEnCours: true) == .perime)
    }

    /// Une tournee de 90 s : le maillage, date du debut de sa tournee, est recu a sa fin
    /// (debut, maillage, fin).
    @Test(.timeLimit(.minutes(1))) func tourneeRecueASaFin() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        let horloge = HorlogeFactice(t0)
        let canal = CanalRejoue { l in
            // La demande de la liste des routeurs « dure » 90 s.
            if l.hasPrefix("diag 0000 5,6 ") { horloge.avancer(90) }
            return CanalRejoue.reseauMinimal(l)
        }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal }, horloge: { horloge.maintenant })
        var suite: [String] = []
        var recus: [(date: Date, recu: Date)] = []
        s.surTournee = { suite.append($0 ? "debut" : "fin") }
        s.surMaillage = { m, recu in
            suite.append("maillage")
            recus.append((m.date, recu))
        }
        // La connexion lance la premiere tournee.
        await s.connecter(Self.port, choisi: true)
        await Self.attendre { s.derniereTournee != nil && !s.tourneeEnCours }
        #expect(suite == ["debut", "maillage", "fin"])
        #expect(recus.first?.date == t0)
        #expect(recus.first?.recu == t0 + 90)
        #expect(s.derniereTournee == t0 + 90)
        s.oublier()
    }

    /// Marche normale : une tournee de 90 s, la pause de 5 min, une tournee de 10 s, la
    /// pause, de nouveau 90 s. Chaque maillage est date du debut de sa tournee et recu a
    /// sa fin, comme dans l'app : il n'est jamais « ancien », ni perime.
    @Test func fraicheurEnMarcheNormale() {
        let s = Surveillance(mode: .direct, dossier: nil)
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        var tournees: [(debut: TimeInterval, fin: TimeInterval)] = []
        var t: TimeInterval = 0
        for duree in [90.0, 10, 90] {
            tournees.append((t, t + duree))
            t += duree + 300
        }
        var vues: [Surveillance.Fraicheur] = []
        for seconde in stride(from: 0, through: t, by: 1.0) {
            for tr in tournees {
                if seconde == tr.debut { s.tourneeEnCours = true }
                if seconde == tr.fin {
                    s.recevoir(ConstructionMaillage(date: t0 + tr.debut, partition: "0000000A").maillage(), a: t0 + seconde)
                    s.tourneeEnCours = false
                }
            }
            if let f = s.fraicheurMaillage(a: t0 + seconde) { vues.append(f) }
        }
        #expect(vues.count == Int(t - 90) + 1, "un maillage des la fin de la premiere tournee")
        #expect(vues.filter { $0 != .frais }.isEmpty)
    }

    /// Sans tournee (sonde muette, debranchee, ou tournee sans Route64) : ancien apres
    /// 6 min, perime apres 15 ; une tournee en cours ne retient pas un maillage perime.
    @Test func fraicheurSansTournee() {
        let s = Surveillance(mode: .direct, dossier: nil)
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(s.fraicheurMaillage(a: t0) == nil)
        // Tournee de 90 s : le maillage est recu a t0.
        s.recevoir(ConstructionMaillage(date: t0 - 90, partition: "0000000A").maillage(), a: t0)
        #expect(s.fraicheurMaillage(a: t0 + 6 * 60) == .frais)
        #expect(s.fraicheurMaillage(a: t0 + 6 * 60 + 1) == .ancien)
        #expect(s.fraicheurMaillage(a: t0 + 15 * 60) == .ancien)
        #expect(s.fraicheurMaillage(a: t0 + 15 * 60 + 1) == .perime)
        s.tourneeEnCours = true
        #expect(s.fraicheurMaillage(a: t0 + 6 * 60 + 1) == .frais)
        #expect(s.fraicheurMaillage(a: t0 + 15 * 60 + 1) == .perime)
    }
}
