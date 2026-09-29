import Foundation
import MaillageCoeur
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

    /// En demo et sous tests : rien de lu.
    @Test func inactive() throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        #expect(SondeMaillage(preferences: p, actif: false).serie == nil)
    }

    @Test func fraicheur() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(Surveillance.fraicheur(t, maintenant: t + 300) == .frais)
        #expect(Surveillance.fraicheur(t, maintenant: t + 7 * 60) == .ancien)
        #expect(Surveillance.fraicheur(t, maintenant: t + 16 * 60) == .perime)
    }
}
