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
    /// Fin du flux differee apres `fermer`, comme la liaison serie qui ferme le port sur sa file :
    /// d'ici la, les commandes ont encore leurs reponses.
    let fermetureDifferee: Duration?

    init(fermetureDifferee: Duration? = nil, repondre: @escaping @Sendable (String) -> [String]) {
        self.fermetureDifferee = fermetureDifferee
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
        guard let d = fermetureDifferee else {
            etat.withLock { $0.suite?.finish() }
            return
        }
        Task { [self] in
            try? await Task.sleep(for: d)
            etat.withLock { $0.suite?.finish() }
        }
    }

    var envoyes: [String] { etat.withLock { $0.envoyes } }

    static let bonjour = #"{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.0","mac":"A00000000001","appairee":true,"code":null,"qr":null}"#
    /// bonjour du firmware 1.0.1 : nom, code et QR code, meme appairee (valeurs inventees).
    static let bonjourNomme = #"{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.1","nom":"SONDE-01","mac":"A00000000001","appairee":true,"code":"12345678901","qr":"MT:ABCDEFGHIJ0123456789"}"#
    static let etatDetache = #"{"v":1,"t":"etat","role":"detached","rloc16":"FFFE","mode":"rn","parent":null,"partition":null,"chef":null,"canal":25,"prefixeMaille":null,"xp":null,"suspendue":false}"#

    static func diag(_ id: Int, _ cible: String, tlv: String) -> String {
        #"{"v":1,"t":"diag","id":\#(id),"cible":"\#(cible)","ms":40,"ok":true,"code":"2.04","tlv":"\#(tlv)"}"#
    }

    /// Ligne `routeurs` (firmware 1.0.2) : chaque routeur par son RLOC16, avec son ExtMac s'il
    /// est entendu (lien etabli, qualites 3) ; `suite` : d'autres lignes suivent.
    static func routeurs(_ table: [(rloc16: String, ext: String?)], suite: Bool) -> String {
        let liste = table.map { r in
            let id = (UInt16(r.rloc16, radix: 16) ?? 0) >> 10
            let lq = r.ext == nil ? 0 : 3
            return #"{"id":\#(id),"rloc16":"\#(r.rloc16)","ext":\#(r.ext.map { "\"\($0)\"" } ?? "null"),"lqIn":\#(lq),"lqOut":\#(lq),"age":4,"lien":\#(r.ext != nil)}"#
        }
        return #"{"v":1,"t":"routeurs","liste":[\#(liste.joined(separator: ","))],"suite":\#(suite)}"#
    }

    /// Sonde attachee (valeurs inventees) : enfant 0001 du routeur 0, qui est le chef.
    static let etatAttache = #"{"v":1,"t":"etat","role":"child","rloc16":"0001","mode":"rn","parent":null,"partition":"0000000A","chef":0,"canal":25,"prefixeMaille":"FD00000000000000","xp":null,"suspendue":false}"#

    /// Reseau d'un seul routeur, le chef 0, qui ne donne que sa Route64 : la tournee
    /// aboutit (maillage d'un routeur muet, sans enfant). `diag <cible> <tlv> <id> <ms>` :
    /// la Route64 a la demande de la liste des routeurs, `delai` a toute autre requete ;
    /// `routeurs` : le chef seul, parent de la sonde, donc sans ExtMac.
    static func reseauMinimal(_ ligne: String) -> [String] {
        switch ligne {
        case "bonjour\n": return [bonjour]
        case "etat\n": return [etatAttache]
        case "routeurs\n": return [routeurs([("0000", nil)], suite: false)]
        default: break
        }
        let mots = ligne.trimmingCharacters(in: .newlines).split(separator: " ").map(String.init)
        guard mots.count >= 4, mots[0] == "diag", let id = Int(mots[3]) else { return [] }
        if mots[1] == "0000" && mots[2] == "5,6" { return [diag(id, "0000", tlv: "050A01800000000000000001")] }
        return [#"{"v":1,"t":"diag","id":\#(id),"cible":"\#(mots[1])","ok":false,"erreur":"delai"}"#]
    }
}

/// Canal d'un port qui ne s'ouvre pas (tenu par une autre app, retire entre-temps).
struct CanalEnPanne: CanalSonde {
    struct Panne: Error {}

    func ouvrir() throws -> AsyncStream<Data> { throw Panne() }
    func envoyer(_ ligne: String) {}
    func fermer() {}
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

/// Chaque test borne a une minute : une attente sans fin echoue au lieu de bloquer la suite.
@Suite("Sonde USB : commandes et reponses", .timeLimit(.minutes(1)))
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

    /// Reponse tardive d'une connexion precedente, au meme id mais pour une autre cible (la carte
    /// finit ses requetes en vol apres une reconnexion USB) : ignoree, la requete attend la sienne.
    @Test(.timeLimit(.minutes(1))) func diagDUneAutreCibleIgnore() async throws {
        let canal = CanalRejoue { l in
            l.hasPrefix("diag 0400") ? [CanalRejoue.diag(1, "5000", tlv: "01025000"), CanalRejoue.diag(1, "0400", tlv: "01020400")] : []
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        let r = try await s.diag(0x0400, [1], delaiMs: 3000)
        #expect(r.cible == "0400")
        #expect(r.reponse?.rloc16 == 0x0400)
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

    /// `routeurs` sur deux lignes (la table coupee, `suite`) : les deux parties reunies, dans
    /// l'ordre ; puis une table d'une ligne (ExtMac inventees).
    @Test func routeursSurPlusieursLignes() async throws {
        let canal = CanalRejoue { l in
            guard l == "routeurs\n" else { return [] }
            return [CanalRejoue.routeurs([("0400", nil), ("AC00", nil)], suite: true),
                    CanalRejoue.routeurs([("E400", "E0000000000000E4")], suite: false)]
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        let table = try await s.routeurs()
        #expect(table.map(\.rloc16) == ["0400", "AC00", "E400"])
        #expect(table.map(\.ext) == [nil, nil, "E0000000000000E4"])
        #expect(canal.envoyes == ["routeurs\n"])
        #expect(try await s.routeurs().count == 3, "une nouvelle table, sans reste de la precedente")
    }

    /// La sonde n'a pas le verrou d'OpenThread (`occupee`) : pas de table, sans attendre le delai.
    @Test(.timeLimit(.minutes(1))) func routeursOccupee() async throws {
        let s = SondeUSB(canal: CanalRejoue { l in
            l == "routeurs\n" ? [#"{"v":1,"t":"routeurs","erreur":"occupee"}"#] : []
        })
        try await s.demarrer {}
        let debut = ContinuousClock.now
        await #expect(throws: SondeUSB.Erreur.sansReponse("routeurs")) { _ = try await s.routeurs() }
        #expect(ContinuousClock.now - debut < SondeUSB.delaiCommandeUSB)
    }

    /// Pas de fin de table dans le delai (la sonde s'arrete apres une ligne `suite`) : `routeurs`
    /// echoue en `sansReponse`, et la partie recue est abandonnee : la table suivante ne la
    /// reprend pas.
    @Test(.timeLimit(.minutes(1))) func routeursExpire() async throws {
        let appels = Mutex(0)
        let canal = CanalRejoue { l in
            guard l == "routeurs\n" else { return [] }
            let n = appels.withLock { a in
                a += 1
                return a
            }
            return n == 1 ? [CanalRejoue.routeurs([("0400", "E0000000000000D1")], suite: true)]
                          : [CanalRejoue.routeurs([("E400", "E0000000000000E4")], suite: false)]
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        await #expect(throws: SondeUSB.Erreur.sansReponse("routeurs")) { _ = try await s.routeurs() }
        #expect(try await s.routeurs().map(\.rloc16) == ["E400"])
    }

    /// Liaison fermee pendant l'attente de la table : l'attente est liberee.
    @Test(.timeLimit(.minutes(1))) func routeursFermeture() async throws {
        let canal = CanalRejoue { _ in [] }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        let requete = Task { try await s.routeurs() }
        try await Task.sleep(for: .milliseconds(50))
        canal.fermer()
        await #expect(throws: SondeUSB.Erreur.fermee) { _ = try await requete.value }
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

    /// L'echeance d'une requete deja servie n'expire pas la suivante : la premiere est servie
    /// tard (a 0,45 s, delai de 0,8 s), la seconde part aussitot et sa reponse arrive a 0,9 s,
    /// apres l'echeance de la premiere (0,8 s) et avant la sienne (1,25 s).
    @Test(.timeLimit(.minutes(1)), arguments: ["bonjour", "etat", "routeurs"])
    func echeanceDUneRequeteServie(_ commande: String) async throws {
        let canal = CanalRejoue { _ in [] }
        let s = SondeUSB(canal: canal, delaiCommande: .milliseconds(800))
        try await s.demarrer {}
        let reponse = switch commande {
        case "bonjour": CanalRejoue.bonjour
        case "etat": CanalRejoue.etatDetache
        default: CanalRejoue.routeurs([("0400", nil)], suite: false)
        }
        @Sendable func requete() async throws {
            switch commande {
            case "bonjour": _ = try await s.bonjour()
            case "etat": _ = try await s.etat()
            default: _ = try await s.routeurs()
            }
        }
        let premiere = Task { try await requete() }
        try await Task.sleep(for: .milliseconds(450))
        canal.emettre([reponse])
        try await premiere.value
        let seconde = Task { try await requete() }
        try await Task.sleep(for: .milliseconds(450))
        canal.emettre([reponse])
        try await seconde.value
        #expect(canal.envoyes == [commande + "\n", commande + "\n"])
    }
}

/// Chaque test borne a une minute : une attente sans fin echoue au lieu de bloquer la suite.
@MainActor
@Suite("Sonde dans l'app : port retenu, refus, fraicheur du maillage", .timeLimit(.minutes(1)))
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

    /// Demande de la liste des routeurs de la premiere tournee d'une connexion (id 1).
    static let listeRetenue = "diag 0000 5,6 1 6000"

    /// Canal du reseau minimal dont la liste des routeurs ne revient que quand le test la
    /// rend (`canal.emettre(CanalRejoue.reseauMinimal(listeRetenue + "\n"))`) : la tournee
    /// reste en cours. Les commandes sont notees au journal.
    static func canalRetenu(_ journal: JournalCanaux) -> CanalRejoue {
        CanalRejoue { l in
            journal.noter(l.trimmingCharacters(in: .newlines))
            return l.hasPrefix("diag 0000 5,6 ") ? [] : CanalRejoue.reseauMinimal(l)
        }
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
        await s.oublier()
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

    /// Aucune sonde retenue : un C6 branche est liste pour les Reglages, jamais ouvert
    /// (spec, section 3 : aucun port qu'on ne lui a pas designe).
    @Test func sansSondeRetenueAucunPortOuvert() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        var canaux = 0
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in
            canaux += 1
            return CanalRejoue { _ in [CanalRejoue.bonjour] }
        })
        s.portsChanges([Self.port])
        // Une connexion lancee passerait avant la suite du test (meme acteur, dans l'ordre).
        await Task.yield()
        #expect(s.ports == [Self.port])
        #expect(canaux == 0)
        #expect(s.etat == .sansSonde)
    }

    /// La sonde retenue (serie S) n'est pas branchee, un autre C6 l'est (serie H, le
    /// pont Halo par exemple) : il n'est jamais ouvert, la sonde est absente.
    @Test func autreC6JamaisOuvert() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        let autre = PortUSB(chemin: "/dev/cu.usbmodemFACTICE02", vid: 0x303A, pid: 0x1001, serie: "B0:00:00:00:00:02",
                            produit: "USB JTAG/serial debug unit")
        var canaux = 0
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in
            canaux += 1
            return CanalRejoue { _ in [CanalRejoue.bonjour] }
        })
        s.portsChanges([autre])
        await Task.yield()
        #expect(s.ports == [autre])
        #expect(canaux == 0)
        #expect(s.etat == .absente)
    }

    /// La sonde retenue absente, un autre port choisi dans les Reglages : un changement de ports
    /// pendant sa connexion (evenement IOKit) ne l'annule pas ; le port choisi est retenu.
    @Test(.timeLimit(.minutes(1))) func choixDUnAutrePortSansLaSondeRetenue() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        let autre = PortUSB(chemin: "/dev/cu.usbmodemFACTICE02", vid: 0x303A, pid: 0x1001, serie: "B0:00:00:00:00:02",
                            produit: nil)
        let journal = JournalCanaux()
        let canal = CanalTemoin("2", journal: journal, retenirBonjour: true)
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        s.portsChanges([autre])
        #expect(s.etat == .absente)
        s.choisir(autre)
        await journal.attendre("bonjour 2")
        s.portsChanges([autre])
        try #require(s.etat == .connexion, "choix annule : \(s.etat)")
        canal.libererBonjour()
        await Self.attendre { Self.connectee(s) }
        #expect(s.serie == "B0:00:00:00:00:02")
        #expect(journal.cycle == ["ouvrir 2"])
        await s.oublier()
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
        await s.oublier()
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
        await s.oublier()
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
        await s.oublier()
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
        await s.oublier()
    }

    /// Connexion automatique en echec (sonde qui demarre en plus de 3 s, port pas encore pret) :
    /// un nouvel essai quelques secondes apres, sans attendre l'evenement USB suivant.
    @Test(.timeLimit(.minutes(1))) func nouvelEssaiApresUneConnexionAutomatiqueEnEchec() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        var canaux = 0
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ -> any CanalSonde in
            canaux += 1
            return canaux == 1 ? CanalEnPanne() : CanalRejoue { CanalRejoue.reseauMinimal($0) }
        }, delaiNouvelEssai: .milliseconds(50))
        // Un seul evenement USB : le second canal vient du nouvel essai.
        s.portsChanges([Self.port])
        #expect(await SondeReseauTests.sonder { Self.connectee(s) }, "nouvel essai : \(s.etat)")
        #expect(canaux == 2)
        await s.oublier()
    }

    /// Un seul nouvel essai : en echec a son tour, la sonde reste en erreur jusqu'a l'evenement
    /// USB suivant. Un port choisi dans les Reglages, puis refuse, n'est pas essaye de nouveau.
    @Test(.timeLimit(.minutes(1))) func unSeulNouvelEssaiEtAucunPourUnChoix() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        var canaux = 0
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in
            canaux += 1
            return CanalEnPanne()
        }, delaiNouvelEssai: .milliseconds(20))
        s.portsChanges([Self.port])
        #expect(await SondeReseauTests.sonder { canaux == 2 }, "nouvel essai")
        try await Task.sleep(for: .milliseconds(200))
        #expect(canaux == 2, "un seul")
        guard case .erreur = s.etat else {
            Issue.record("etat \(s.etat)")
            return
        }
        await s.connecter(Self.port, choisi: true)
        guard case .refusee = s.etat else {
            Issue.record("etat \(s.etat)")
            return
        }
        try await Task.sleep(for: .milliseconds(200))
        #expect(canaux == 3, "aucun pour un port choisi")
        await s.oublier()
    }

    /// Reseau minimal dans une partition donnee ; la table des routeurs donne l'ExtMac du chef 0
    /// (muet : il ne rend que sa Route64) s'il est entendu (valeur inventee).
    static func canalIdentites(ext: String?, partition: String) -> CanalRejoue {
        CanalRejoue { l in
            switch l {
            case "etat\n": return [CanalRejoue.etatAttache.replacingOccurrences(of: "0000000A", with: partition)]
            case "routeurs\n": return [CanalRejoue.routeurs([("0000", ext)], suite: false)]
            default: return CanalRejoue.reseauMinimal(l)
            }
        }
    }

    /// Identites des routeurs gardees dans un fichier (ici temporaire) : relues au lancement
    /// suivant, ou le chef muet garde l'ExtMac que la sonde n'entend plus ; une autre partition
    /// les efface, dans le fichier aussi.
    @Test(.timeLimit(.minutes(1))) func identitesGardeesDUnLancementALAutre() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("maillage-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dossier) }
        let fichier = dossier.appendingPathComponent("identites-routeurs.json")
        /// Un lancement de l'app : une sonde, une tournee, son maillage.
        func lancement(ext: String?, partition: String = "0000000A") async -> Maillage? {
            let s = SondeMaillage(preferences: p, actif: true,
                                  ouvrirCanal: { _ in Self.canalIdentites(ext: ext, partition: partition) },
                                  fichierIdentites: fichier)
            var recu: Maillage?
            s.surMaillage = { m, _ in recu = m }
            await s.connecter(Self.port, choisi: true)
            await Self.attendre { s.derniereTournee != nil && !s.tourneeEnCours }
            await s.oublier()
            return recu
        }
        let m1 = await lancement(ext: "E0000000000000A0")
        #expect(m1?.routeur(0)?.extMac == "E0000000000000A0", "entendu par la sonde")
        #expect(IdentitesGardees.lire(fichier) == IdentitesGardees(partition: "0000000A", identites: [0x0000: "E0000000000000A0"]))
        let m2 = await lancement(ext: nil)
        #expect(m2?.routeur(0)?.extMac == "E0000000000000A0", "relue au lancement suivant")
        let m3 = await lancement(ext: nil, partition: "0000000B")
        #expect(m3?.routeur(0)?.extMac == nil, "autre partition")
        #expect(IdentitesGardees.lire(fichier) == IdentitesGardees(partition: "0000000B", identites: [:]))
    }

    /// Reseau minimal ou personne ne donne la liste des routeurs (tout `diag` echoue) : la
    /// tournee ne rend pas de maillage ; la table des routeurs donne l'ExtMac du chef 0 (inventee).
    static func canalSansListe() -> CanalRejoue {
        CanalRejoue { l in
            if l == "routeurs\n" { return [CanalRejoue.routeurs([("0000", "E0000000000000A0")], suite: false)] }
            let mots = l.trimmingCharacters(in: .newlines).split(separator: " ").map(String.init)
            if mots.first == "diag", mots.count >= 4, let id = Int(mots[3]) {
                return [#"{"v":1,"t":"diag","id":\#(id),"cible":"\#(mots[1])","ok":false,"erreur":"delai"}"#]
            }
            return CanalRejoue.reseauMinimal(l)
        }
    }

    /// Tournee sans liste des routeurs : pas de maillage, mais l'identite entendue est gardee,
    /// dans le fichier aussi (une sonde promenee ne perd rien).
    @Test(.timeLimit(.minutes(1))) func identitesGardeesSansListeDesRouteurs() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("maillage-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dossier) }
        let fichier = dossier.appendingPathComponent("identites-routeurs.json")
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in Self.canalSansListe() },
                              fichierIdentites: fichier)
        let (fins, fin) = AsyncStream.makeStream(of: Void.self)
        s.surTournee = { enCours in if !enCours { fin.yield() } }
        await s.connecter(Self.port, choisi: true)
        for await _ in fins { break }
        #expect(s.derniereTournee == nil, "pas de maillage")
        #expect(IdentitesGardees.lire(fichier) == IdentitesGardees(partition: "0000000A", identites: [0x0000: "E0000000000000A0"]))
        await s.oublier()
    }

    /// Fichier des identites reecrit seulement quand elles changent : efface apres la premiere
    /// tournee, il n'est pas recree par une tournee qui n'apprend rien de nouveau ; il l'est par
    /// celle ou le chef change d'ExtMac (valeurs inventees).
    @Test(.timeLimit(.minutes(1))) func fichierReecritSeulementSiChangement() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("maillage-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dossier) }
        let fichier = dossier.appendingPathComponent("identites-routeurs.json")
        let entendue = Mutex("E0000000000000A0")
        let canal = CanalRejoue { l in
            guard l == "routeurs\n" else { return CanalRejoue.reseauMinimal(l) }
            return [CanalRejoue.routeurs([("0000", entendue.withLock { $0 })], suite: false)]
        }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal }, fichierIdentites: fichier)
        let (fins, fin) = AsyncStream.makeStream(of: Void.self)
        s.surTournee = { enCours in if !enCours { fin.yield() } }
        var tournees = fins.makeAsyncIterator()
        await s.connecter(Self.port, choisi: true)
        _ = await tournees.next()
        #expect(IdentitesGardees.lire(fichier) != nil, "premiere tournee : ecrit")
        try FileManager.default.removeItem(at: fichier)
        s.rafraichir()
        _ = await tournees.next()
        #expect(!FileManager.default.fileExists(atPath: fichier.path), "rien de change : pas reecrit")
        entendue.withLock { $0 = "E0000000000000A1" }
        s.rafraichir()
        _ = await tournees.next()
        #expect(IdentitesGardees.lire(fichier) == IdentitesGardees(partition: "0000000A", identites: [0x0000: "E0000000000000A1"]))
        await s.oublier()
    }

    /// Ecriture du fichier des identites en echec (un fichier a la place de son dossier) : tracee,
    /// les identites restent en memoire et l'ecriture est retentee a la tournee suivante.
    @Test(.timeLimit(.minutes(1))) func ecritureDesIdentitesRetentee() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("maillage-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dossier) }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let bouchon = dossier.appendingPathComponent("Maillage Thread")
        try Data().write(to: bouchon)
        let fichier = bouchon.appendingPathComponent("identites-routeurs.json")
        let s = SondeMaillage(preferences: p, actif: true,
                              ouvrirCanal: { _ in Self.canalIdentites(ext: "E0000000000000A0", partition: "0000000A") },
                              fichierIdentites: fichier)
        let (fins, fin) = AsyncStream.makeStream(of: Void.self)
        s.surTournee = { enCours in if !enCours { fin.yield() } }
        var tournees = fins.makeAsyncIterator()
        await s.connecter(Self.port, choisi: true)
        _ = await tournees.next()
        #expect(IdentitesGardees.lire(fichier) == nil, "pas ecrit")
        try FileManager.default.removeItem(at: bouchon)
        s.rafraichir()
        _ = await tournees.next()
        #expect(IdentitesGardees.lire(fichier) == IdentitesGardees(partition: "0000000A", identites: [0x0000: "E0000000000000A0"]),
                "retentee, sans changement des identites")
        await s.oublier()
    }

    /// Fichier des identites : dans le dossier de l'app ; jamais en demo ni sous les tests (qui
    /// passent leur propre fichier, temporaire).
    @Test func fichierDesIdentites() {
        #expect(SondeMaillage.fichierIdentites(demo: true, sousTests: false) == nil)
        #expect(SondeMaillage.fichierIdentites(demo: false, sousTests: true) == nil)
        #expect(SondeMaillage.fichierIdentites(demo: true, sousTests: true) == nil)
        #expect(SondeMaillage.fichierIdentites(demo: false, sousTests: false)
                == Surveillance.dossierParDefaut.appendingPathComponent("identites-routeurs.json"))
    }

    /// En demo et sous tests : rien de lu.
    @Test func inactive() throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        p.set("SONDE-01", forKey: SondeMaillage.cleNom)
        let s = SondeMaillage(preferences: p, actif: false)
        #expect(s.serie == nil)
        #expect(s.nom == nil)
    }

    /// Nom donne par la carte (firmware 1.0.1) : retenu a cote du numero de serie, relu au
    /// lancement ; oublier la sonde l'oublie aussi.
    @Test func nomRetenu() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let canal = CanalRejoue { l in
            l == "bonjour\n" ? [CanalRejoue.bonjourNomme] : l == "etat\n" ? [CanalRejoue.etatDetache] : []
        }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        #expect(s.nom == nil)
        await s.connecter(Self.port, choisi: true)
        #expect(s.nom == "SONDE-01")
        #expect(p.string(forKey: SondeMaillage.cleNom) == "SONDE-01")
        #expect(SondeMaillage(preferences: p, actif: true).nom == "SONDE-01", "relu au lancement")
        await s.oublier()
        #expect(s.nom == nil)
        #expect(p.string(forKey: SondeMaillage.cleNom) == nil)
    }

    /// Port sans numero de serie : la sonde n'est pas retenue, son nom non plus (il resterait
    /// affiche sans sonde choisie apres un relancement).
    @Test func nomSansSerieNonRetenu() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let sansSerie = PortUSB(chemin: "/dev/cu.usbmodemFACTICE03", vid: 0x303A, pid: 0x1001, serie: nil, produit: nil)
        let canal = CanalRejoue { l in
            l == "bonjour\n" ? [CanalRejoue.bonjourNomme] : l == "etat\n" ? [CanalRejoue.etatDetache] : []
        }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        await s.connecter(sansSerie, choisi: true)
        #expect(Self.connectee(s))
        #expect(s.serie == nil)
        #expect(s.nom == nil)
        #expect(p.string(forKey: SondeMaillage.cleNom) == nil)
        await s.oublier()
    }

    /// Le nom de la sonde retenue va a l'etat qui la concerne (connectee, absente) ; pas au
    /// refus d'un autre port choisi, ni a la connexion d'un autre port, ni sans sonde.
    @Test(.timeLimit(.minutes(1))) func nomSeulementPourLaSondeRetenue() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let halo = #"{"v":1,"t":"bonjour","produit":"pont-halo","version":"0.4.0","mac":null,"appairee":true,"code":null,"qr":null}"#
        let pont = PortUSB(chemin: "/dev/cu.usbmodemFACTICE02", vid: 0x303A, pid: 0x1001, serie: "B0:00:00:00:00:02",
                           produit: nil)
        let troisieme = PortUSB(chemin: "/dev/cu.usbmodemFACTICE03", vid: 0x303A, pid: 0x1001, serie: "C0:00:00:00:00:03",
                                produit: nil)
        let journal = JournalCanaux()
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { chemin in
            if chemin == Self.port.chemin {
                return CanalRejoue { l in
                    l == "bonjour\n" ? [CanalRejoue.bonjourNomme] : l == "etat\n" ? [CanalRejoue.etatDetache] : []
                }
            }
            if chemin == pont.chemin { return CanalRejoue { _ in [halo] } }
            return CanalTemoin("3", journal: journal, retenirBonjour: true)
        })
        #expect(s.nomEtat == nil, "aucune sonde")
        await s.connecter(Self.port, choisi: true)
        #expect(s.nomEtat == "SONDE-01")
        await s.connecter(pont, choisi: true)
        guard case .refusee = s.etat else {
            Issue.record("etat \(s.etat)")
            return
        }
        #expect(s.nom == "SONDE-01", "la sonde reste retenue")
        #expect(s.nomEtat == nil, "refus d'un autre port")
        s.portsChanges([pont])
        #expect(s.etat == .absente)
        #expect(s.nomEtat == "SONDE-01", "la sonde retenue est absente")
        s.choisir(troisieme)
        await journal.attendre("bonjour 3")
        #expect(s.etat == .connexion)
        #expect(s.nomEtat == nil, "connexion d'un autre port")
        await s.oublier()
        #expect(s.nomEtat == nil)
    }

    /// La sonde retenue elle-meme, reprise au branchement (sans choix dans les Reglages) : son
    /// nom aussi pendant sa connexion, et apres une erreur de son port.
    @Test(.timeLimit(.minutes(1))) func nomDeLaSondeRetenueEnConnexionEtEnErreur() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        p.set("SONDE-01", forKey: SondeMaillage.cleNom)
        let journal = JournalCanaux()
        var canaux = 0
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ -> any CanalSonde in
            canaux += 1
            // D'abord un bonjour qui tarde (connexion en cours), puis un port qui ne s'ouvre pas.
            return canaux == 1 ? CanalTemoin("1", journal: journal, retenirBonjour: true) : CanalEnPanne()
        })
        s.portsChanges([Self.port])
        await journal.attendre("bonjour 1")
        #expect(s.etat == .connexion)
        #expect(s.nomEtat == "SONDE-01", "connexion de la sonde retenue")
        s.portsChanges([])
        s.portsChanges([Self.port])
        await Self.attendre { if case .erreur = s.etat { true } else { false } }
        #expect(s.nomEtat == "SONDE-01", "erreur de la sonde retenue")
        await s.oublier()
    }

    /// Le nom suit chaque bonjour : un firmware sans nom (1.0.0) l'efface.
    @Test func nomSuitLeBonjour() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        var canaux = 0
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in
            canaux += 1
            let b = canaux == 1 ? CanalRejoue.bonjourNomme : CanalRejoue.bonjour
            return CanalRejoue { l in l == "bonjour\n" ? [b] : l == "etat\n" ? [CanalRejoue.etatDetache] : [] }
        })
        await s.connecter(Self.port, choisi: true)
        #expect(s.nom == "SONDE-01")
        await s.connecter(Self.port, choisi: true)
        #expect(Self.connectee(s))
        #expect(s.nom == nil)
        #expect(p.string(forKey: SondeMaillage.cleNom) == nil)
        await s.oublier()
    }

    /// Pendant une tournee : son avancement (etape, fait, total) et l'heure de son debut ;
    /// l'un et l'autre remis a nil a sa fin.
    @Test(.timeLimit(.minutes(1))) func avancementPendantLaTournee() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        let horloge = HorlogeFactice(t0)
        let journal = JournalCanaux()
        let canal = Self.canalRetenu(journal)
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal }, horloge: { horloge.maintenant })
        #expect(s.avancement == nil && s.debutTournee == nil)
        await s.connecter(Self.port, choisi: true)
        await journal.attendre(Self.listeRetenue)
        await Self.attendre { s.avancement?.etape == .listeRouteurs }
        #expect(s.avancement == AvancementTournee(etape: .listeRouteurs, fait: 0, total: 1))
        #expect(s.debutTournee == t0)
        canal.emettre(CanalRejoue.reseauMinimal(Self.listeRetenue + "\n"))
        await Self.attendre { !s.tourneeEnCours }
        #expect(s.derniereTournee == t0)
        #expect(s.avancement == nil)
        #expect(s.debutTournee == nil)
        await s.oublier()
    }

    /// La liaison se ferme pendant une tournee (oubli, debranchement) : la tournee finit sans
    /// erreur a montrer, son avancement est remis a nil.
    @Test(.timeLimit(.minutes(1))) func avancementRemisANilALaFermeture() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in Self.canalRetenu(journal) })
        await s.connecter(Self.port, choisi: true)
        await journal.attendre(Self.listeRetenue)
        await Self.attendre { s.avancement != nil }
        await s.oublier()
        await Self.attendre { !s.tourneeEnCours }
        #expect(s.avancement == nil)
        #expect(s.debutTournee == nil)
        #expect(s.erreurTournee == nil)
    }

    /// « Oublier la sonde » efface son releve : etat de la sonde (partition, suspension), dernier
    /// releve et erreur de tournee ne restent pas apres elle.
    @Test(.timeLimit(.minutes(1))) func oublierEffaceLeReleve() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        // Une premiere tournee complete ; ensuite `etat` reste sans reponse (erreur de tournee a 3 s).
        let muette = Mutex(false)
        let canal = CanalRejoue { l in
            l == "etat\n" && muette.withLock({ $0 }) ? [] : CanalRejoue.reseauMinimal(l)
        }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        await s.connecter(Self.port, choisi: true)
        await Self.attendre { s.derniereTournee != nil && !s.tourneeEnCours }
        muette.withLock { $0 = true }
        s.rafraichir()
        await Self.attendre { s.erreurTournee != nil }
        #expect(s.etatSonde != nil && s.derniereTournee != nil)
        await s.oublier()
        #expect(s.etatSonde == nil)
        #expect(s.derniereTournee == nil)
        #expect(s.erreurTournee == nil)
    }

    /// « Oublier la sonde » retire aussi son maillage du graphe, branche comme dans l'app
    /// (`surOubli`) : retour aux pointilles tout de suite, sans attendre qu'il soit perime.
    @Test(.timeLimit(.minutes(1))) func oublierRetireLeMaillage() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let surveillance = Surveillance(mode: .direct, dossier: nil)
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in CanalRejoue { CanalRejoue.reseauMinimal($0) } })
        s.surMaillage = { m, recu in surveillance.recevoir(m, a: recu) }
        s.surOubli = { surveillance.oublierMaillage() }
        await s.connecter(Self.port, choisi: true)
        await Self.attendre { surveillance.maillage != nil }
        #expect(surveillance.fraicheurMaillage(a: Date()) == .frais)
        await s.oublier()
        #expect(surveillance.maillage == nil)
        #expect(surveillance.fraicheurMaillage(a: Date()) == nil)
    }

    /// « Oublier » pendant que la reponse a `etat` de la tournee est en route : arrivee apres
    /// l'oubli (avant la fin du flux), elle ne remet pas l'etat de la sonde.
    @Test(.timeLimit(.minutes(1))) func etatRecuApresLOubli() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        // `etat` ne repond que quand le test le rend.
        let canal = CanalRejoue { l in
            journal.noter(l.trimmingCharacters(in: .newlines))
            return l == "etat\n" ? [] : CanalRejoue.reseauMinimal(l)
        }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        await s.connecter(Self.port, choisi: true)
        await journal.attendre("etat")
        await s.oublier()
        canal.emettre([CanalRejoue.etatAttache])
        await Self.attendre { !s.tourneeEnCours }
        #expect(s.etatSonde == nil)
    }

    /// « Oublier » pendant une tournee : la liaison met un instant a se fermer et la tournee
    /// aboutit entre-temps ; ni dernier releve ni maillage ne reviennent apres l'oubli.
    @Test(.timeLimit(.minutes(1))) func tourneeFinieApresLOubli() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        let canal = CanalRejoue(fermetureDifferee: .seconds(2)) { l in
            journal.noter(l.trimmingCharacters(in: .newlines))
            return l.hasPrefix("diag 0000 5,6 ") ? [] : CanalRejoue.reseauMinimal(l)
        }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        var maillages = 0
        s.surMaillage = { _, _ in maillages += 1 }
        await s.connecter(Self.port, choisi: true)
        await journal.attendre(Self.listeRetenue)
        await s.oublier()
        canal.emettre(CanalRejoue.reseauMinimal(Self.listeRetenue + "\n"))
        await Self.attendre { !s.tourneeEnCours }
        #expect(maillages == 0)
        #expect(s.derniereTournee == nil)
        #expect(s.etatSonde == nil)
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
        await s.oublier()
    }

    /// Rafraichir pendant une tournee (bouton du graphe) : ni seconde tournee, ni boucle
    /// relancee (la tournee suivante partirait 5 min apres le clic, et non apres la fin de
    /// celle-ci). Hors tournee, une tournee part tout de suite.
    @Test(.timeLimit(.minutes(1))) func rafraichirPendantUneTournee() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        let canal = Self.canalRetenu(journal)
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        #expect(!s.tourneeAuRafraichir, "sans sonde connectee")
        await s.connecter(Self.port, choisi: true)
        await journal.attendre(Self.listeRetenue)
        #expect(s.tourneeEnCours)
        #expect(!s.tourneeAuRafraichir, "pendant une tournee")
        let boucle = try #require(s.boucle)
        s.rafraichir()
        await Task.yield()
        #expect(s.boucle == boucle, "boucle gardee")
        #expect(!boucle.isCancelled)
        #expect(canal.envoyes.filter { $0 == "etat\n" }.count == 2, "une seule tournee : etat, puis celui de la tournee")
        canal.emettre(CanalRejoue.reseauMinimal(Self.listeRetenue + "\n"))
        await Self.attendre { s.derniereTournee != nil && !s.tourneeEnCours }
        #expect(s.tourneeAuRafraichir, "connectee et libre")
        s.rafraichir()
        await Self.attendre { s.tourneeEnCours }
        #expect(s.boucle != boucle, "hors tournee : une tournee tout de suite")
        await s.oublier()
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
