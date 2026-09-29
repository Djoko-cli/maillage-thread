import Foundation
import MaillageCoeur
import Synchronization
import Testing
@testable import MaillageThread

/// Lignes d'un canal, notees au fil de l'eau, puis `fin` a la fin du flux.
final class RecueilLignes: Sendable {
    private let lignes = Mutex<[String]>([])

    init(_ flux: AsyncStream<Data>) {
        Task { [self] in
            for await l in flux { noter(String(decoding: l, as: UTF8.self)) }
            noter("fin")
        }
    }

    private func noter(_ s: String) {
        lignes.withLock { $0.append(s) }
    }

    var liste: [String] { lignes.withLock { $0 } }
}

/// Canal reseau de la sonde (contrat 1.0.2) : rid, renvois, doublons, veille ; sur la carte
/// simulee, sans trafic reseau.
@Suite("Canal reseau de la sonde")
struct CanalReseauTests {
    static let hote = "0123456789ABCDEF"

    /// Renvois a 100 et 200 ms ; veille lointaine (hors des tests qui la visent).
    static func rapides(veille: Duration = .seconds(60), attenteVeille: Duration = .seconds(1)) -> CanalReseau.Reglages {
        var r = CanalReseau.Reglages()
        r.renvois = [.milliseconds(100), .milliseconds(200)]
        r.veille = veille
        r.attenteVeille = attenteVeille
        return r
    }

    static func canal(_ carte: CarteSimulee, reglages: CanalReseau.Reglages = rapides(),
                      connexions: ConnexionsSimulees? = nil) async throws -> CanalReseau {
        try await CanalReseau.connecter(hote: hote, cle: VecteursH1.psk, reglages: reglages,
                                        reglagesTransport: TransportUDPTests.rapides()) { h, p in
            let c = ConnexionSimulee(hote: h, port: p, carte: carte)
            connexions?.ajouter(c)
            return c
        }
    }

    /// `<rid> <commande>` -> rid et commande.
    static func decouper(_ charge: String) -> (rid: Int, commande: String)? {
        guard let espace = charge.firstIndex(of: " "), let rid = Int(charge[..<espace]) else { return nil }
        return (rid, String(charge[charge.index(after: espace)...]))
    }

    /// Une sonde du reseau minimal (`CanalRejoue.reseauMinimal`), chaque reponse precedee du rid.
    static func sonde(_ charge: String) -> [String] {
        guard let (rid, commande) = decouper(charge) else { return [] }
        return CanalRejoue.reseauMinimal(commande + "\n").map { "\(rid) \($0)" }
    }

    /// Chaque commande part en `<rid> <commande>`, rid croissants ; `SondeUSB` recoit les
    /// lignes JSON seules, comme par le canal serie ; la connexion vise `<hote>.local:5480`.
    @Test func ridEtLignesSeules() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        let connexions = ConnexionsSimulees()
        let s = SondeUSB(canal: try await Self.canal(carte, connexions: connexions))
        try await s.demarrer {}
        #expect(try await s.bonjour().version == "1.0.0")
        #expect(try await s.etat().estAttachee)
        let recues = carte.recues.compactMap(Self.decouper)
        let commandes = recues.map { $0.commande }
        #expect(commandes == ["bonjour", "etat"])
        #expect(recues.count == 2 && recues[0].rid < recues[1].rid)
        let visees = connexions.toutes.map { "\($0.hote):\($0.port)" }
        #expect(visees == ["0123456789ABCDEF.local:5480"])
        await s.fermer()
    }

    /// Par le reseau, `SondeUSB` attend au-dela du second renvoi du canal : les deux premiers
    /// envois perdus, la reponse au second renvoi aboutit (ici renvois a 100 et 200 ms, attente
    /// de 400 ms ; dans l'app 2 et 4 s, attente de 6 s, et 3 s en USB).
    @Test func reponseAuSecondRenvoi() async throws {
        #expect(SondeUSB.delaiCommandeUSB == .seconds(3))
        #expect(SondeUSB.delaiCommandeReseau == .seconds(6))
        #expect(CanalReseau.Reglages().renvois == [.seconds(2), .seconds(4)])
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        let s = SondeUSB(canal: try await Self.canal(carte), delaiCommande: .milliseconds(400))
        try await s.demarrer {}
        carte.perdre(2)
        #expect(try await s.bonjour().version == "1.0.0")
        carte.perdre(2)
        #expect(try await s.etat().estAttachee)
        #expect(carte.perdus == 4)
        await s.fermer()
    }

    /// Deux `etat` lents de suite par le reseau, comme au debut d'une tournee (`SondeMaillage`,
    /// puis `Tournee`) : chacun n'est servi qu'au second renvoi. L'echeance du premier, deja
    /// servi, n'expire pas le second, qui aboutit dans son propre delai (ici renvois a 0,4 et
    /// 0,8 s, attente de 1,2 s : l'app divisee par 5, renvois a 2 et 4 s, attente de 6 s).
    @Test(.timeLimit(.minutes(1))) func deuxEtatLentsDeSuite() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        var reglages = Self.rapides()
        reglages.renvois = [.milliseconds(400), .milliseconds(800)]
        let s = SondeUSB(canal: try await Self.canal(carte, reglages: reglages), delaiCommande: .milliseconds(1200))
        try await s.demarrer {}
        carte.perdre(2)
        #expect(try await s.etat().estAttachee)
        carte.perdre(2)
        #expect(try await s.etat().estAttachee, "le second, servi apres l'echeance du premier")
        #expect(carte.perdus == 4)
        await s.fermer()
    }

    /// Une tournee entiere par le reseau : le maillage du reseau minimal, table des routeurs
    /// comprise (la carte simulee repond a `routeurs`, sans attente du delai).
    @Test func tourneeParLeReseau() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        let s = SondeUSB(canal: try await Self.canal(carte))
        try await s.demarrer {}
        let r = try await Tournee.executer(s, memoire: MemoireTournee(), maintenant: Date(timeIntervalSince1970: 1_790_000_000))
        let routeurs = r.maillage?.routeurs.map { $0.id }
        #expect(routeurs == [0])
        #expect(carte.recues.compactMap(Self.decouper).map(\.commande).contains("routeurs"))
        await s.fermer()
    }

    /// `routeurs` sur plusieurs lignes par le reseau (meme rid, `suite`) : chaque ligne traverse
    /// le canal, et `SondeUSB.routeurs()` rend la table entiere, dans l'ordre (ExtMac inventees).
    @Test func routeursSurPlusieursLignesParLeReseau() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk) { charge in
            guard let (rid, commande) = Self.decouper(charge), commande == "routeurs" else { return Self.sonde(charge) }
            return [CanalRejoue.routeurs([("0400", nil), ("AC00", "E0000000000000AC")], suite: true),
                    CanalRejoue.routeurs([("E400", "E0000000000000E4")], suite: true),
                    CanalRejoue.routeurs([("F000", nil)], suite: false)].map { "\(rid) \($0)" }
        }
        let s = SondeUSB(canal: try await Self.canal(carte))
        try await s.demarrer {}
        let table = try await s.routeurs()
        #expect(table.map(\.rloc16) == ["0400", "AC00", "E400", "F000"])
        #expect(table.map(\.ext) == [nil, "E0000000000000AC", "E0000000000000E4", nil])
        #expect(Set(carte.recues.compactMap(Self.decouper).map(\.commande)) == ["routeurs"])
        await s.fermer()
    }

    /// Sans aucune reponse, la commande repart avec le meme rid a 2 s puis 4 s (ici 100 et
    /// 200 ms), et plus ensuite.
    @Test func renvoisDuMemeRid() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk)  // ne repond a rien
        let c = try await Self.canal(carte)
        _ = RecueilLignes(try c.ouvrir())
        c.envoyer("etat\n")
        #expect(await attendreQue { carte.recues.count == 3 })
        try await Task.sleep(for: .milliseconds(300))
        let recues = carte.recues
        #expect(recues.count == 3, "premier envoi et deux renvois, pas plus")
        #expect(Set(recues).count == 1, "meme rid, meme commande")
        let ctrs = carte.ctrsRecus
        #expect(ctrs == ctrs.sorted() && Set(ctrs).count == 3, "ctr neuf a chaque envoi")
        c.fermer()
    }

    /// Premier envoi perdu : le renvoi passe, la reponse arrive, et plus rien ne repart.
    @Test func renvoiApresUnePerte() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        var reglages = Self.rapides()
        reglages.renvois = [.milliseconds(100), .milliseconds(600)]
        let c = try await Self.canal(carte, reglages: reglages)
        let lignes = RecueilLignes(try c.ouvrir())
        carte.perdre(1)
        c.envoyer("etat\n")
        #expect(await attendreQue { lignes.liste == [CanalRejoue.etatAttache] })
        try await Task.sleep(for: .milliseconds(700))
        #expect(carte.recues.count == 1, "le renvoi seul arrive ; aucun autre apres la reponse")
        c.fermer()
    }

    /// Doublons ecartes (meme rid, meme ligne : reponse renvoyee par la carte) ; plusieurs
    /// lignes d'une meme reponse (`routeurs`, `suite`) passent toutes.
    @Test func doublonsEcartes() async throws {
        let l1 = #"{"v":1,"t":"routeurs","liste":[],"suite":true}"#
        let l2 = #"{"v":1,"t":"routeurs","liste":[],"suite":false}"#
        let carte = CarteSimulee(cle: VecteursH1.psk) { charge in
            guard let (rid, commande) = Self.decouper(charge) else { return [] }
            if commande == "routeurs" { return ["\(rid) \(l1)", "\(rid) \(l1)", "\(rid) \(l2)", "\(rid) \(l2)"] }
            return Self.sonde(charge)
        }
        let c = try await Self.canal(carte)
        let lignes = RecueilLignes(try c.ouvrir())
        c.envoyer("routeurs\n")
        c.envoyer("etat\n")
        #expect(await attendreQue { lignes.liste.count == 3 })
        try await Task.sleep(for: .milliseconds(100))
        #expect(lignes.liste == [l1, l2, CanalRejoue.etatAttache])
        c.fermer()
    }

    /// Charge sans rid, rid illisible ou ligne vide : ecartee.
    @Test func chargesIllisiblesEcartees() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        let c = try await Self.canal(carte)
        let lignes = RecueilLignes(try c.ouvrir())
        c.envoyer("etat\n")  // ouvre la session cote carte (adresse de reponse)
        #expect(await attendreQue { lignes.liste.count == 1 })
        for charge in [CanalRejoue.bonjour, "x " + CanalRejoue.bonjour, "12", "12 ", "-3 " + CanalRejoue.bonjour] {
            carte.envoyer(charge)
        }
        carte.envoyer("99 " + CanalRejoue.bonjour)
        #expect(await attendreQue { lignes.liste.count == 2 })
        #expect(lignes.liste == [CanalRejoue.etatAttache, CanalRejoue.bonjour])
        c.fermer()
    }

    /// La cle ne passe jamais par le reseau : `cle ...` n'est pas envoye (la carte le
    /// refuserait ; l'alea n'a rien a faire sur le reseau).
    @Test func jamaisDeCleParLeReseau() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        let c = try await Self.canal(carte)
        let lignes = RecueilLignes(try c.ouvrir())
        c.envoyer(CommandeSonde.cleNouvelle(alea: Data(repeating: 0xAB, count: 32), id: 3).ligne)
        c.envoyer("cle\n")
        c.envoyer("etat\n")
        #expect(await attendreQue { lignes.liste.count == 1 })
        let commandes = carte.recues.compactMap(Self.decouper).map { $0.commande }
        #expect(commandes == ["etat"])
        c.fermer()
    }

    /// Silence : un `etat` de veille, dont la reponse n'est pas transmise ; le canal reste ouvert.
    @Test func veille() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        let c = try await Self.canal(carte, reglages: Self.rapides(veille: .milliseconds(150), attenteVeille: .seconds(2)))
        let lignes = RecueilLignes(try c.ouvrir())
        #expect(await attendreQue { carte.recues.count >= 2 }, "une veille apres chaque silence")
        let veilles = carte.recues.compactMap(Self.decouper).allSatisfy { $0.commande == "etat" }
        #expect(veilles)
        #expect(lignes.liste.isEmpty, "reponses de veille gardees par le canal")
        c.fermer()
        #expect(await attendreQue { lignes.liste == ["fin"] })
    }

    /// La veille et ses renvois perdus, mais une autre reponse arrive ensuite : la sonde est
    /// vivante, le canal reste ouvert.
    @Test func veillePerdueMaisSondeVivante() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        let c = try await Self.canal(carte, reglages: Self.rapides(veille: .milliseconds(100), attenteVeille: .seconds(1)))
        let lignes = RecueilLignes(try c.ouvrir())
        carte.perdre(3)
        #expect(await attendreQue { carte.perdus == 3 }, "veille et ses deux renvois perdus")
        c.envoyer("etat\n")
        #expect(await attendreQue { lignes.liste == [CanalRejoue.etatAttache] })
        try await Task.sleep(for: .milliseconds(1500))
        #expect(!lignes.liste.contains("fin"), "canal toujours ouvert")
        c.fermer()
    }

    /// Veille levee par une autre reponse : ses renvois s'arretent (ici veille apres 600 ms de
    /// silence, perdue ; renvois prevus a +300 ms et +1 s).
    @Test func veilleLeveeSansRenvoi() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        var reglages = Self.rapides(veille: .milliseconds(600), attenteVeille: .seconds(3))
        reglages.renvois = [.milliseconds(300), .seconds(1)]
        let c = try await Self.canal(carte, reglages: reglages)
        let lignes = RecueilLignes(try c.ouvrir())
        carte.perdre(1)
        #expect(await attendreQue { carte.perdus == 1 }, "veille perdue")
        c.envoyer("etat\n")
        #expect(await attendreQue { lignes.liste == [CanalRejoue.etatAttache] })
        try await Task.sleep(for: .milliseconds(450))
        let commandes = carte.recues.compactMap(Self.decouper).map { $0.commande }
        #expect(commandes == ["etat"], "le renvoi de la veille levee ne part pas")
        c.fermer()
    }

    /// Fermee, la garde s'arrete.
    @Test func gardeArreteeALaFermeture() async throws {
        let c = try await Self.canal(CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde))
        _ = RecueilLignes(try c.ouvrir())
        #expect(c.surveiller())
        c.fermer()
        #expect(!c.surveiller())
    }

    /// Sonde debranchee : la veille reste sans reponse, le canal se ferme (fin du flux).
    @Test func veilleSansReponseFermeLeCanal() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        let connexions = ConnexionsSimulees()
        let c = try await Self.canal(carte, reglages: Self.rapides(veille: .milliseconds(100), attenteVeille: .milliseconds(300)),
                                     connexions: connexions)
        let lignes = RecueilLignes(try c.ouvrir())
        #expect(c.raisonFermeture == nil)
        carte.eteindre()
        #expect(await attendreQue { lignes.liste == ["fin"] })
        let annulees = connexions.toutes.allSatisfy { $0.annulee }
        #expect(annulees, "transport ferme")
        // La cause, montree comme dans Halo : « Connexion réseau perdue : la sonde ne répond plus… ».
        #expect(c.raisonFermeture == CanalReseau.raisonSilence)
        #expect(CanalReseau.raisonSilence.hasPrefix(ErreurReseau.cheminPerdu("").localizedDescription))
    }

    /// Fermeture par l'app, ou session perdue : fin du flux des lignes.
    @Test func fermetures() async throws {
        let carte = CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde)
        let connexions = ConnexionsSimulees()
        let c = try await Self.canal(carte, connexions: connexions)
        let lignes = RecueilLignes(try c.ouvrir())
        c.fermer()
        #expect(await attendreQue { lignes.liste == ["fin"] })
        #expect(throws: (any Error).self) { _ = try c.ouvrir() }
        let d = try await Self.canal(carte, connexions: connexions)
        let lignesD = RecueilLignes(try d.ouvrir())
        connexions.toutes.last?.echouer(.pasDeRoute)
        #expect(await attendreQue { lignesD.liste == ["fin"] })
        #expect(d.raisonFermeture == TransportUDP.raisonPerte(.pasDeRoute), "cause de la perte gardee")
    }

    /// Fermee avant d'etre ouverte (connexion abandonnee) : flux fini aussitot.
    @Test func fermeeAvantOuverture() async throws {
        let c = try await Self.canal(CarteSimulee(cle: VecteursH1.psk, repondre: Self.sonde))
        c.fermer()
        let lignes = RecueilLignes(try c.ouvrir())
        #expect(await attendreQue { lignes.liste == ["fin"] })
    }

    /// Carte muette ou autre cle : la connexion echoue (aucun DEFI).
    @Test func connexionSansReponse() async throws {
        await #expect(throws: ErreurReseau.aucunDefi) {
            _ = try await Self.canal(CarteSimulee(cle: VecteursH1.psk, mode: .muette))
        }
    }
}
