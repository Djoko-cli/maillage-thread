import AppKit
import Foundation
import MaillageCoeur
import Synchronization
import SwiftUI
import Testing
@testable import MaillageThread

/// Canal dont chaque reponse n'arrive qu'apres `delai` : par le reseau, celle qui repond au
/// renvoi de 4 s du canal reseau.
final class CanalLent: CanalSonde {
    let delai: Duration
    private let repondre: @Sendable (String) -> [String]
    private let suite = Mutex<AsyncStream<Data>.Continuation?>(nil)

    init(delai: Duration, repondre: @escaping @Sendable (String) -> [String]) {
        self.delai = delai
        self.repondre = repondre
    }

    func ouvrir() throws -> AsyncStream<Data> {
        let (flux, s) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .unbounded)
        suite.withLock { $0 = s }
        return flux
    }

    func envoyer(_ ligne: String) {
        let lignes = repondre(ligne), delai = delai
        Task { [self] in
            try? await Task.sleep(for: delai)
            suite.withLock { s in
                for l in lignes { s?.yield(Data(l.utf8)) }
            }
        }
    }

    func fermer() {
        suite.withLock { s in
            s?.finish()
            s = nil
        }
    }
}

/// Ouvertures de la liaison reseau demandees par `SondeMaillage` : nom d'hote et cle, et le
/// canal rendu (ou l'erreur) a chaque essai. Aucun trafic reseau.
@MainActor
final class ReseauFactice {
    private(set) var appels: [(hote: String, cle: Data)] = []
    /// Reponse de chaque essai, dans l'ordre ; au-dela, la derniere.
    var reponses: [Result<any CanalSonde, any Error>]

    init(_ reponses: [Result<any CanalSonde, any Error>]) {
        self.reponses = reponses
    }

    func ouvrir(_ hote: String, _ cle: Data) throws -> any CanalSonde {
        appels.append((hote, cle))
        let r = reponses.count > 1 ? reponses.removeFirst() : reponses[0]
        return try r.get()
    }
}

/// Acces a la sonde par le reseau Thread dans l'app : cle par l'USB, choix de la liaison,
/// connexion et reprise. Trousseau en memoire, reseau factice.
@MainActor
@Suite("Sonde par le reseau Thread : cle, liaison, reprise")
struct SondeReseauTests {
    static let hote = "0123456789ABCDEF"
    static let port = SondeMaillageTests.port

    /// bonjour du firmware 1.0.2 (valeurs inventees), avec ou sans nom d'hote.
    static func bonjour(hote: String? = SondeReseauTests.hote) -> String {
        let h = hote.map { "\"\($0)\"" } ?? "null"
        return #"{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.2","nom":"SONDE-01","mac":"A00000000001","appairee":true,"code":"12345678901","qr":"MT:ABCDEFGHIJ0123456789","hote":\#(h)}"#
    }

    /// Reponses d'une sonde 1.0.2 : bonjour, etat (detachee : tournee sans requete), cle nouvelle.
    static func reponses(bonjour: String = SondeReseauTests.bonjour(), cle: @escaping @Sendable (Int) -> [String]
                         = { [CleReseauTests.reponse($0)] }) -> @Sendable (String) -> [String] {
        { l in
            if l == "bonjour\n" { return [bonjour] }
            if l == "etat\n" { return [CanalRejoue.etatDetache] }
            if l.hasPrefix("cle nouvelle ") {
                return cle(Int(l.trimmingCharacters(in: .newlines).split(separator: " ").last ?? "") ?? 0)
            }
            return []
        }
    }

    static func sonde(bonjour: String = SondeReseauTests.bonjour(), cle: @escaping @Sendable (Int) -> [String]
                      = { [CleReseauTests.reponse($0)] }) -> CanalRejoue {
        CanalRejoue(repondre: reponses(bonjour: bonjour, cle: cle))
    }

    static func sondeMaillage(_ p: UserDefaults, usb: @escaping (String) -> any CanalSonde = { _ in sonde() },
                              trousseau: any TrousseauCles, reseau: ReseauFactice? = nil,
                              delais: [Duration] = [.milliseconds(20)]) -> SondeMaillage {
        SondeMaillage(preferences: p, actif: true, ouvrirCanal: usb, trousseau: trousseau,
                      ouvrirReseau: { h, c in
                          guard let reseau else { throw ErreurReseau.autre("pas de reseau dans ce test") }
                          return try reseau.ouvrir(h, c)
                      },
                      delaisReprise: delais)
    }

    /// Sonde retenue avec sa cle, prete pour le reseau (comme apres « Autoriser l'acces reseau »).
    static func prete(_ p: UserDefaults, liaison: SondeMaillage.Liaison) throws -> TrousseauMemoire {
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        p.set("SONDE-01", forKey: SondeMaillage.cleNom)
        p.set(hote, forKey: SondeMaillage.cleHote)
        p.set(liaison.rawValue, forKey: SondeMaillage.cleLiaison)
        let t = TrousseauMemoire()
        try t.ranger(nom: hote, cle: VecteursH1.psk, empreinte: "630DCD29")
        return t
    }

    /// Connectee par l'USB, la sonde retenue donne son nom d'hote ; « Autoriser » cree la cle,
    /// la verifie et la range dans le trousseau sous ce nom. Rien de la cle dans les preferences.
    @Test func autoriser() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = TrousseauMemoire()
        let s = Self.sondeMaillage(p, trousseau: t)
        await s.connecter(Self.port, choisi: true)
        #expect(s.hote == Self.hote)
        #expect(p.string(forKey: SondeMaillage.cleHote) == Self.hote)
        #expect(s.empreinteAcces == nil && !s.reseauDisponible)
        #expect(s.peutAutoriser)
        await s.autoriserAccesReseau()
        #expect(s.erreurAutorisation == nil)
        #expect(try t.lire(nom: Self.hote) == VecteursH1.psk)
        #expect(s.empreinteAcces == "630DCD29")
        #expect(s.reseauDisponible)
        #expect(!s.autorisationEnCours)
        let valeurs = (p.persistentDomain(forName: domaine) ?? [:]).values.map { "\($0)" }
        #expect(!valeurs.contains { $0.contains(CleReseauTests.hexaCle) }, "cle hors des preferences")
        s.oublier()
    }

    /// Sans nom d'hote (Matter ne l'a pas encore enregistre), aucune cle n'est demandee.
    @Test func autoriserSansNomDHote() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = TrousseauMemoire()
        let canal = Self.sonde(bonjour: Self.bonjour(hote: nil))
        let s = Self.sondeMaillage(p, usb: { _ in canal }, trousseau: t)
        await s.connecter(Self.port, choisi: true)
        await s.autoriserAccesReseau()
        #expect(s.erreurAutorisation == CleReseau.Erreur.sansNomDHote.localizedDescription)
        #expect(!canal.envoyes.contains { $0.hasPrefix("cle") })
        #expect(t.lister().isEmpty)
        s.oublier()
    }

    /// Empreinte fausse, ou refus d'un firmware sans acces reseau : rien n'est range.
    @Test func autoriserEnEchec() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = TrousseauMemoire()
        var canaux = 0
        let s = Self.sondeMaillage(p, usb: { _ in
            canaux += 1
            return canaux == 1
                ? Self.sonde(cle: { [CleReseauTests.reponse($0, empreinte: "00000000")] })
                : Self.sonde(cle: { _ in [#"{"v":1,"t":"erreur","erreur":"commande inconnue"}"#] })
        }, trousseau: t)
        await s.connecter(Self.port, choisi: true)
        await s.autoriserAccesReseau()
        #expect(s.erreurAutorisation == CleReseau.Erreur.empreinteIncoherente.localizedDescription)
        await s.connecter(Self.port, choisi: true)
        await s.autoriserAccesReseau()
        #expect(s.erreurAutorisation == SondeUSB.Erreur.refusee("commande inconnue").localizedDescription)
        #expect(t.lister().isEmpty)
        #expect(s.empreinteAcces == nil)
        s.oublier()
    }

    /// Sans cle pour la sonde retenue, le reseau ne se choisit pas.
    @Test func reseauSansCle() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let reseau = ReseauFactice([.success(Self.sonde())])
        let s = Self.sondeMaillage(p, trousseau: TrousseauMemoire(), reseau: reseau)
        await s.connecter(Self.port, choisi: true)
        s.choisirLiaison(.reseau)
        #expect(s.liaison == .usb)
        #expect(Self.connecteeParUSB(s))
        await Task.yield()
        #expect(reseau.appels.isEmpty)
        s.oublier()
    }

    static func connecteeParUSB(_ s: SondeMaillage) -> Bool {
        s.liaison == .usb && SondeMaillageTests.connectee(s)
    }

    /// Attend une condition qui n'est pas observable (canal, reseau factice), au plus `delai` ;
    /// rend la condition.
    static func sonder(delai: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
        let fin = ContinuousClock.now + delai
        while ContinuousClock.now < fin {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }

    /// Choisir le reseau : le port USB est ferme, la session part vers le nom d'hote avec la
    /// cle du trousseau, la tournee commence ; la sonde branchee n'est plus ouverte en USB.
    @Test(.timeLimit(.minutes(1))) func choisirLeReseau() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = try Self.prete(p, liaison: .usb)
        let journal = JournalCanaux()
        var canaux = 0
        let distante = Self.sonde()
        let reseau = ReseauFactice([.success(distante)])
        let s = Self.sondeMaillage(p, usb: { _ in
            canaux += 1
            return CanalTemoin("\(canaux)", journal: journal)
        }, trousseau: t, reseau: reseau)
        await s.connecter(Self.port, choisi: true)
        #expect(Self.connecteeParUSB(s))
        #expect(s.reseauDisponible)
        s.choisirLiaison(.reseau)
        #expect(s.liaison == .reseau)
        #expect(p.string(forKey: SondeMaillage.cleLiaison) == SondeMaillage.Liaison.reseau.rawValue)
        await SondeMaillageTests.attendre { SondeMaillageTests.connectee(s) }
        #expect(journal.cycle == ["ouvrir 1", "fermer 1", "fin 1"], "port USB ferme")
        let hotes = reseau.appels.map { $0.hote }
        #expect(hotes == [Self.hote])
        #expect(reseau.appels.first?.cle == VecteursH1.psk)
        #expect(await Self.sonder { distante.envoyes.contains("etat\n") }, "tournee par le reseau")
        #expect(s.nomEtat == "SONDE-01")
        s.portsChanges([Self.port])
        await Task.yield()
        #expect(canaux == 1, "branchee, la sonde n'est pas ouverte en USB")
        s.oublier()
    }

    /// Au lancement, liaison reseau retenue : nom d'hote et empreinte relus ; connexion par le reseau.
    @Test func reseauAuLancement() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = try Self.prete(p, liaison: .reseau)
        let reseau = ReseauFactice([.success(Self.sonde())])
        var canaux = 0
        let s = Self.sondeMaillage(p, usb: { _ in
            canaux += 1
            return Self.sonde()
        }, trousseau: t, reseau: reseau)
        #expect(s.liaison == .reseau && s.hote == Self.hote && s.empreinteAcces == "630DCD29")
        await s.connecterReseau()
        #expect(SondeMaillageTests.connectee(s))
        #expect(canaux == 0, "aucun port ouvert")
        #expect(reseau.appels.count == 1)
        s.oublier()
    }

    /// Echec de la session (sonde muette, pas de route) : erreur montree, reprise seule.
    @Test(.timeLimit(.minutes(1))) func repriseApresEchec() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = try Self.prete(p, liaison: .reseau)
        let reseau = ReseauFactice([.failure(ErreurReseau.aucunDefi), .failure(ErreurReseau.pasDeRoute), .success(Self.sonde())])
        let s = Self.sondeMaillage(p, trousseau: t, reseau: reseau, delais: [.milliseconds(50)])
        await s.connecterReseau()
        #expect(s.etat == .erreur(ErreurReseau.aucunDefi.localizedDescription))
        #expect(s.nomEtat == "SONDE-01")
        await SondeMaillageTests.attendre { SondeMaillageTests.connectee(s) }
        #expect(reseau.appels.count == 3)
        s.oublier()
    }

    /// Cle absente du trousseau : erreur, sans reprise (il faut l'USB).
    @Test func cleAbsente() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        _ = try Self.prete(p, liaison: .reseau)
        let reseau = ReseauFactice([.success(Self.sonde())])
        let s = Self.sondeMaillage(p, trousseau: TrousseauMemoire(), reseau: reseau)
        await s.connecterReseau()
        #expect(s.etat == .erreur(ErreurTrousseau.absente(Self.hote).localizedDescription))
        try await Task.sleep(for: .milliseconds(100))
        #expect(reseau.appels.isEmpty)
        s.oublier()
    }

    /// Liaison reseau perdue (canal ferme : veille sans reponse, session perdue) : reconnexion.
    @Test(.timeLimit(.minutes(1))) func liaisonPerdue() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = try Self.prete(p, liaison: .reseau)
        let premiere = Self.sonde()
        let reseau = ReseauFactice([.success(premiere), .success(Self.sonde())])
        let s = Self.sondeMaillage(p, trousseau: t, reseau: reseau)
        await s.connecterReseau()
        #expect(SondeMaillageTests.connectee(s))
        premiere.fermer()
        #expect(await Self.sonder { reseau.appels.count == 2 && SondeMaillageTests.connectee(s) })
        s.oublier()
    }

    /// Session perdue (chemin perdu, veille sans reponse) : sa cause est montree, comme dans Halo
    /// (« Connexion réseau perdue : <cause> ») ; ici par le vrai canal, sur la carte simulee.
    @Test(.timeLimit(.minutes(1))) func causeDeLaPerteMontree() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = try Self.prete(p, liaison: .reseau)
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: CanalReseauTests.sonde)
        let connexions = ConnexionsSimulees()
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in Self.sonde() }, trousseau: t,
                              ouvrirReseau: { h, c in
                                  try await CanalReseau.connecter(hote: h, cle: c, reglages: CanalReseauTests.rapides(),
                                                                  reglagesTransport: TransportUDPTests.rapides()) { hh, pp in
                                      let x = ConnexionSimulee(hote: hh, port: pp, carte: carte)
                                      connexions.ajouter(x)
                                      return x
                                  }
                              },
                              delaisReprise: [.seconds(60)])
        await s.connecterReseau()
        #expect(SondeMaillageTests.connectee(s))
        connexions.toutes.last?.echouer(.pasDeRoute)
        await SondeMaillageTests.attendre { if case .erreur = s.etat { true } else { false } }
        #expect(s.etat == .erreur(TransportUDP.raisonPerte(.pasDeRoute)))
        s.oublier()
    }

    /// Une activite est tenue pendant une session reseau (App Nap retarderait la veille et les
    /// tournees), relachee a sa fin ; rien de tel en USB.
    @Test(.timeLimit(.minutes(1))) func activitePendantLaSessionReseau() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = try Self.prete(p, liaison: .usb)
        let premiere = Self.sonde()
        let s = Self.sondeMaillage(p, trousseau: t, reseau: ReseauFactice([.success(premiere), .failure(ErreurReseau.aucunDefi)]),
                                   delais: [.seconds(60)])
        await s.connecter(Self.port, choisi: true)
        #expect(!s.activiteTenue, "pas en USB")
        s.choisirLiaison(.reseau)
        await SondeMaillageTests.attendre { SondeMaillageTests.connectee(s) }
        #expect(s.activiteTenue)
        premiere.fermer()
        await SondeMaillageTests.attendre { if case .erreur = s.etat { true } else { false } }
        #expect(!s.activiteTenue, "session perdue")
        s.oublier()
        #expect(!s.activiteTenue)
    }

    /// Retour a l'USB : la session reseau est fermee, la sonde branchee reprise par son port.
    @Test(.timeLimit(.minutes(1))) func retourALUSB() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = try Self.prete(p, liaison: .reseau)
        let journal = JournalCanaux()
        let distante = CanalTemoin("reseau", journal: journal)
        let reseau = ReseauFactice([.success(distante)])
        let s = Self.sondeMaillage(p, usb: { _ in CanalTemoin("usb", journal: journal) }, trousseau: t, reseau: reseau)
        s.portsChanges([Self.port])
        await Task.yield()
        #expect(!journal.cycle.contains("ouvrir usb"))
        await s.connecterReseau()
        #expect(SondeMaillageTests.connectee(s))
        s.choisirLiaison(.usb)
        #expect(p.string(forKey: SondeMaillage.cleLiaison) == SondeMaillage.Liaison.usb.rawValue)
        await SondeMaillageTests.attendre { Self.connecteeParUSB(s) }
        #expect(journal.cycle == ["ouvrir reseau", "fermer reseau", "fin reseau", "ouvrir usb"])
        s.oublier()
    }

    /// Reglages › Sonde : etat de l'acces reseau (les attentes reprennent les cles du code :
    /// elles suivent la langue de l'hote).
    @Test func texteAccesReseau() {
        #expect(FenetreReglages.texteAccesReseau(empreinte: nil) == String(localized: "non autorisé"))
        #expect(FenetreReglages.texteAccesReseau(empreinte: "630DCD29") == String(localized: "autorisé · clé \("630DCD29")"))
        #expect(FenetreReglages.texteHote(Self.hote) == "0123456789ABCDEF.local")
        #expect(FenetreReglages.texteHote(nil) == "—")
    }

    /// Reglages › Sonde : le bloc de l'acces reseau se dessine (etat, bouton, explication).
    @Test func vueAccesReseau() throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let s = Self.sondeMaillage(p, trousseau: try Self.prete(p, liaison: .usb))
        let vue = NSHostingView(rootView: Form { AccesReseauSonde() }.formStyle(.grouped).environment(s))
        #expect(vue.fittingSize.height > 0)
    }

    /// Par le reseau, `bonjour` et `etat` attendent au-dela du renvoi de 4 s du canal : la
    /// reponse a ce renvoi (ici a 4,2 s) aboutit.
    @Test(.timeLimit(.minutes(1))) func delaiDeCommandeParLeReseau() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = try Self.prete(p, liaison: .reseau)
        let lent = CanalLent(delai: .milliseconds(4200), repondre: Self.reponses())
        let s = Self.sondeMaillage(p, trousseau: t, reseau: ReseauFactice([.success(lent)]), delais: [.seconds(60)])
        await s.connecterReseau()
        #expect(SondeMaillageTests.connectee(s), "bonjour a 4,2 s : \(s.etat)")
        #expect(await Self.sonder(delai: .seconds(10)) { s.etatSonde != nil }, "etat de la tournee a 4,2 s")
        s.oublier()
    }

    /// En USB, rien ne change : 3 s, puis « ne répond pas ».
    @Test(.timeLimit(.minutes(1))) func delaiDeCommandeEnUSB() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let lent = CanalLent(delai: .milliseconds(4200), repondre: Self.reponses())
        let s = Self.sondeMaillage(p, usb: { _ in lent }, trousseau: TrousseauMemoire())
        let debut = ContinuousClock.now
        await s.connecter(Self.port, choisi: true)
        #expect(s.etat == .refusee(SondeUSB.Erreur.sansReponse("bonjour").localizedDescription))
        #expect(ContinuousClock.now - debut < .seconds(4), "abandon a 3 s")
        s.oublier()
    }

    /// Oublier la sonde : la cle de ce Mac part avec elle ; retour a l'USB.
    @Test func oublier() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let t = try Self.prete(p, liaison: .reseau)
        let s = Self.sondeMaillage(p, trousseau: t, reseau: ReseauFactice([.success(Self.sonde())]))
        await s.connecterReseau()
        s.oublier()
        #expect(s.etat == .sansSonde)
        #expect(t.lister().isEmpty)
        #expect(s.hote == nil && s.empreinteAcces == nil && s.liaison == .usb)
        #expect(p.string(forKey: SondeMaillage.cleHote) == nil)
        #expect(p.string(forKey: SondeMaillage.cleLiaison) == nil)
    }
}
