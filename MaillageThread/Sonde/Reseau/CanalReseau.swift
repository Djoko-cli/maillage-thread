import Foundation
import Synchronization

/// Canal de la sonde par le reseau Thread (contrat 1.0.2), sur le transport UDP repris du
/// pont Halo : un `CanalSonde` de plus, `SondeUSB` et la tournee ne changent pas.
/// - Chaque commande part en `<rid> <commande>` (rid decimal, croissant) ; sans aucune
///   reponse, elle repart avec le meme rid a 2 s puis a 4 s : la carte ne relance rien, elle
///   renvoie la reponse gardee (ou se tait, `diag` encore en vol).
/// - Chaque reponse `<rid> <ligne JSON>` passe a `SondeUSB` sans le rid, comme une ligne du
///   canal serie ; un doublon (meme rid, meme ligne) est ecarte.
/// - Apres 30 s sans aucune ligne, un `etat` de veille, dont la reponse reste ici : sans
///   reponse (sonde debranchee, redemarree, hors de portee), le canal se ferme, et l'app se
///   reconnecte (nouvelle poignee de main).
/// - La cle ne passe jamais par le reseau : les commandes `cle ...` ne partent pas.
/// - Fermee, il garde la cause (`raisonFermeture`), montree comme dans Halo :
///   « Connexion réseau perdue : <cause> ».
final class CanalReseau: CanalSonde, CauseFermeture {
    struct Reglages: Sendable {
        /// Renvois d'une commande sans reponse, comptes depuis son premier envoi.
        var renvois: [Duration] = [.seconds(2), .seconds(4)]
        /// Silence (aucune ligne recue) avant une veille.
        var veille: Duration = .seconds(30)
        /// Reponse a la veille, ses renvois compris : au plus.
        var attenteVeille: Duration = .seconds(6)
        /// Doublons : lignes des derniers rid gardees.
        var memoireDoublons = 256
    }

    private let transport: TransportUDP
    private let charges: AsyncStream<EvenementLiaison>
    private let reglages: Reglages

    private struct Etat {
        var suite: AsyncStream<Data>.Continuation?
        var ouvert = false
        var ferme = false
        /// Commandes sans aucune reponse (renvois dus), et leur tache de renvoi.
        var attendus: [Int: Task<Void, Never>] = [:]
        /// Lignes transmises, par rid (doublons) ; rid dans l'ordre, pour borner.
        var vues: [Int: Set<Data>] = [:]
        var ordre: [Int] = []
        /// rid des veilles envoyees (leurs reponses restent ici), et la veille en cours.
        var veilles: Set<Int> = []
        var veille: (rid: Int, depuis: ContinuousClock.Instant)?
        var dernierRecu = ContinuousClock.now
        /// Cause de la fermeture : celle du transport, ou le silence de la sonde.
        var raison: String?
        var taches: [Task<Void, Never>] = []
    }

    private let etat = Mutex(Etat())

    /// Cause d'une fermeture pour silence (veille sans reponse).
    static var raisonSilence: String {
        ErreurReseau.cheminPerdu(String(localized: "la sonde ne répond plus (débranchée, redémarrée ou hors de portée ?)"))
            .localizedDescription
    }

    var raisonFermeture: String? { etat.withLock { $0.raison } }

    /// rid de toutes les commandes de l'app, croissants d'une connexion a l'autre.
    private static let compteur = Mutex(0)

    static func prochainRid() -> Int {
        compteur.withLock { n in
            n = n >= 999_999_999 ? 1 : n + 1
            return n
        }
    }

    /// Ouvre une session vers `<hote>.local:5480` (resolution, poignee de main H1) : le canal
    /// pret, ou l'erreur (`ErreurReseau`).
    static func connecter(hote: String, cle: Data, reglages: Reglages = Reglages(),
                          reglagesTransport: TransportUDP.Reglages = TransportUDP.Reglages(),
                          fabrique: @escaping @Sendable (String, UInt16) -> any ConnexionDatagrammes
                              = { ConnexionNW(hote: $0, port: $1) }) async throws -> CanalReseau {
        let t = TransportUDP(hote: "\(hote).local", cle: cle, reglages: reglagesTransport, fabrique: fabrique)
        let charges = try await t.ouvrir()
        return CanalReseau(transport: t, charges: charges, reglages: reglages)
    }

    init(transport: TransportUDP, charges: AsyncStream<EvenementLiaison>, reglages: Reglages = Reglages()) {
        self.transport = transport
        self.charges = charges
        self.reglages = reglages
    }

    /// Les lignes JSON de la sonde ; le flux finit quand la session se ferme. Une seule fois ;
    /// fermee avant, le canal rend un flux deja fini.
    func ouvrir() throws -> AsyncStream<Data> {
        let (lignes, suite) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .unbounded)
        let (deja, ferme) = etat.withLock { e -> (Bool, Bool) in
            guard !e.ouvert else { return (true, e.ferme) }
            e.ouvert = true
            guard !e.ferme else { return (false, true) }
            e.suite = suite
            e.dernierRecu = .now
            return (false, false)
        }
        if deja { throw ErreurReseau.autre(String(localized: "canal réseau déjà ouvert")) }
        if ferme {
            suite.finish()
            return lignes
        }
        let charges = charges
        let lecture = Task { [weak self] in
            for await e in charges {
                switch e {
                case .donnees(let d): self?.recu(d)
                case .ferme(let r): self?.noterRaison(r)
                }
            }
            // Session fermee (par l'app, la veille, ou perdue) : fin des lignes.
            self?.finir()
        }
        let pas = min(.seconds(1), reglages.veille / 4, reglages.attenteVeille / 4)
        let garde = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: pas)
                guard !Task.isCancelled, let self, self.surveiller() else { return }
            }
        }
        etat.withLock { $0.taches = [lecture, garde] }
        suite.onTermination = { [weak self] _ in self?.fermer() }
        return lignes
    }

    func envoyer(_ ligne: String) {
        let commande = ligne.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commande.isEmpty, !Self.estCommandeCle(commande) else { return }
        let rid = Self.prochainRid()
        emettre(rid, Data("\(rid) \(commande)".utf8))
    }

    /// Ferme la session ; la fin du flux des lignes suit.
    func fermer() {
        let taches = etat.withLock { e -> [Task<Void, Never>] in
            guard !e.ferme else { return [] }
            e.ferme = true
            let t = Array(e.attendus.values) + e.taches.dropFirst()  // la lecture finit avec le transport
            e.attendus.removeAll()
            return t
        }
        taches.forEach { $0.cancel() }
        transport.fermer()
    }

    /// `cle`, `cle nouvelle ...`, `cle efface` : USB seulement.
    static func estCommandeCle(_ commande: String) -> Bool {
        commande.split(separator: " ").first == "cle"
    }

    /// `<rid> <ligne>` : rid decimal positif, ligne non vide ; sinon nil.
    static func lire(_ charge: Data) -> (rid: Int, ligne: Data)? {
        guard let espace = charge.firstIndex(of: 0x20) else { return nil }
        let chiffres = charge[charge.startIndex..<espace]
        guard (1...10).contains(chiffres.count), chiffres.allSatisfy({ (0x30...0x39).contains($0) }),
              let rid = Int(String(decoding: chiffres, as: UTF8.self)), rid > 0 else { return nil }
        let ligne = charge[charge.index(after: espace)...]
        guard !ligne.isEmpty else { return nil }
        return (rid, Data(ligne))
    }

    // MARK: - Envoi et renvois

    private func emettre(_ rid: Int, _ charge: Data) {
        let renvois = reglages.renvois
        let tache = Task { [weak self] in
            var ecoule: Duration = .zero
            for r in renvois {
                try? await Task.sleep(for: r - ecoule)
                ecoule = r
                guard !Task.isCancelled, let self, self.attend(rid) else { return }
                try? self.transport.envoyer(charge)
            }
            self?.oublier(rid)
        }
        let ouvert = etat.withLock { e -> Bool in
            guard !e.ferme else { return false }
            e.attendus[rid] = tache
            return true
        }
        guard ouvert else {
            tache.cancel()
            return
        }
        try? transport.envoyer(charge)
    }

    private func attend(_ rid: Int) -> Bool {
        etat.withLock { $0.attendus[rid] != nil }
    }

    private func oublier(_ rid: Int) {
        _ = etat.withLock { $0.attendus.removeValue(forKey: rid) }
    }

    // MARK: - Reception

    /// Une charge de la carte : la ligne passe, sauf reponse a une veille ou doublon.
    private func recu(_ charge: Data) {
        guard let (rid, ligne) = Self.lire(charge) else { return }
        let memoire = reglages.memoireDoublons
        let (suite, renvoi): (AsyncStream<Data>.Continuation?, Task<Void, Never>?) = etat.withLock { e in
            e.dernierRecu = .now
            let renvoi = e.attendus.removeValue(forKey: rid)
            if e.vues[rid] == nil {
                e.ordre.append(rid)
                if e.ordre.count > memoire {
                    let ancien = e.ordre.removeFirst()
                    e.vues[ancien] = nil
                    e.veilles.remove(ancien)
                }
            }
            guard e.vues[rid, default: []].insert(ligne).inserted else { return (nil, renvoi) }
            if e.veilles.contains(rid) {
                if e.veille?.rid == rid { e.veille = nil }
                return (nil, renvoi)
            }
            return (e.suite, renvoi)
        }
        renvoi?.cancel()
        suite?.yield(ligne)
    }

    /// La premiere cause connue reste (le silence, pose avant la fermeture qu'il provoque).
    private func noterRaison(_ r: String) {
        etat.withLock { e in
            if e.raison == nil { e.raison = r }
        }
    }

    private func finir() {
        let suite = etat.withLock { e -> AsyncStream<Data>.Continuation? in
            e.ferme = true
            let s = e.suite
            e.suite = nil
            e.attendus.values.forEach { $0.cancel() }
            e.attendus.removeAll()
            e.taches.last?.cancel()  // la garde
            return s
        }
        suite?.finish()
    }

    // MARK: - Veille

    private enum Garde {
        case rien
        case veiller(Int)
        case muette
    }

    /// Un pas de la garde : veille apres un silence ; sans reponse a la veille, fermeture.
    /// Faux : la garde s'arrete.
    private func surveiller() -> Bool {
        let maintenant = ContinuousClock.now
        let action = etat.withLock { e -> Garde in
            guard !e.ferme else { return .rien }
            if let v = e.veille {
                // Une ligne recue depuis la veille : la sonde est vivante, meme si la veille s'est perdue.
                guard e.dernierRecu <= v.depuis else {
                    e.veille = nil
                    return .rien
                }
                return maintenant - v.depuis >= reglages.attenteVeille ? .muette : .rien
            }
            guard maintenant - e.dernierRecu >= reglages.veille else { return .rien }
            let rid = Self.prochainRid()
            e.veille = (rid, maintenant)
            e.veilles.insert(rid)
            return .veiller(rid)
        }
        switch action {
        case .rien:
            return true
        case .veiller(let rid):
            emettre(rid, Data("\(rid) etat".utf8))
            return true
        case .muette:
            noterRaison(Self.raisonSilence)
            fermer()
            return false
        }
    }
}
