import Foundation
import MaillageCoeur

/// Lignes machine de la sonde et envoi des commandes : la liaison serie dans
/// l'app, un canal rejoue dans les tests.
protocol CanalSonde: Sendable {
    /// Lignes machine (JSON, sans RS ni LF) ; le flux finit quand le port se ferme.
    func ouvrir() throws -> AsyncStream<Data>
    func envoyer(_ ligne: String)
    func fermer()
}

/// Canal sur la liaison serie : le flux USB decoupe en lignes machine.
struct CanalSerie: CanalSonde {
    let liaison: LiaisonSerie

    func ouvrir() throws -> AsyncStream<Data> {
        let flux = try liaison.ouvrir()
        let (lignes, suite) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .unbounded)
        let lecture = Task {
            var decoupeur = DecoupeurLignes()
            for await e in flux {
                guard case .donnees(let d) = e else { break }
                for l in decoupeur.ajouter(d) { suite.yield(l) }
            }
            suite.finish()
        }
        suite.onTermination = { _ in lecture.cancel() }
        return lignes
    }

    func envoyer(_ ligne: String) { liaison.envoyer(Data(ligne.utf8)) }
    func fermer() { liaison.fermer() }
}

/// Sonde branchee en USB : envoie les commandes et apparie les reponses, par
/// ordre pour `bonjour` et `etat`, par id pour `diag` (8 en vol, dans le desordre).
actor SondeUSB: InterlocuteurSonde {
    enum Erreur: Error, LocalizedError, Equatable {
        case fermee
        case sansReponse(String)

        var errorDescription: String? {
            switch self {
            case .fermee: String(localized: "liaison avec la sonde fermée")
            case .sansReponse(let commande): String(localized: "la sonde ne répond pas à « \(commande) »")
            }
        }
    }

    /// Attente de `bonjour` et `etat`.
    static let delaiCommande: Duration = .seconds(3)

    private let canal: any CanalSonde
    /// Au-dela du delai donne a la sonde, elle a du repondre (elle echoue elle-meme en `delai`).
    private let marge: Duration
    private var prochainId = 1
    private var attenteDiag: [Int: (cible: UInt16, suite: CheckedContinuation<ResultatDiag, Never>)] = [:]
    private var attenteEtat: [CheckedContinuation<EtatSonde?, Never>] = []
    private var attenteBonjour: [CheckedContinuation<Bonjour?, Never>] = []
    private var lecture: Task<Void, Never>?
    private(set) var fermee = false
    /// Dernier `bonjour` recu sans l'avoir demande : la sonde vient de (re)demarrer.
    private(set) var bonjourSpontane: Bonjour?

    init(canal: any CanalSonde, marge: Duration = .seconds(5)) {
        self.canal = canal
        self.marge = marge
    }

    /// Ouvre le canal et lit ses lignes ; `surFermeture` quand il se ferme.
    func demarrer(surFermeture: @escaping @Sendable () -> Void) throws {
        let lignes = try canal.ouvrir()
        lecture = Task {
            for await l in lignes { self.recevoir(l) }
            self.clore()
            surFermeture()
        }
    }

    func fermer() {
        canal.fermer()
    }

    func bonjour() async throws -> Bonjour {
        guard !fermee else { throw Erreur.fermee }
        let b = await withCheckedContinuation { c in
            attenteBonjour.append(c)
            canal.envoyer(CommandeSonde.bonjour.ligne)
            Task {
                try? await Task.sleep(for: Self.delaiCommande)
                self.expirerBonjour()
            }
        }
        guard let b else { throw fermee ? Erreur.fermee : Erreur.sansReponse("bonjour") }
        return b
    }

    func etat() async throws -> EtatSonde {
        guard !fermee else { throw Erreur.fermee }
        let e = await withCheckedContinuation { c in
            attenteEtat.append(c)
            canal.envoyer(CommandeSonde.etat.ligne)
            Task {
                try? await Task.sleep(for: Self.delaiCommande)
                self.expirerEtat()
            }
        }
        guard let e else { throw fermee ? Erreur.fermee : Erreur.sansReponse("etat") }
        return e
    }

    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        guard !fermee else { throw Erreur.fermee }
        let id = prochainId
        prochainId += 1
        let r = await withCheckedContinuation { c in
            attenteDiag[id] = (cible, c)
            canal.envoyer(CommandeSonde.diag(cible: cible, tlv: tlv, id: id, delaiMs: delaiMs).ligne)
            Task {
                try? await Task.sleep(for: .milliseconds(delaiMs) + self.marge)
                self.expirerDiag(id)
            }
        }
        if r.erreur == "fermee" { throw Erreur.fermee }
        return r
    }

    private func expirerBonjour() {
        if !attenteBonjour.isEmpty { attenteBonjour.removeFirst().resume(returning: nil) }
    }

    private func expirerEtat() {
        if !attenteEtat.isEmpty { attenteEtat.removeFirst().resume(returning: nil) }
    }

    private func expirerDiag(_ id: Int) {
        guard let a = attenteDiag.removeValue(forKey: id) else { return }
        a.suite.resume(returning: ResultatDiag(id: id, cible: String(format: "%04X", a.cible), ok: false, erreur: "delai"))
    }

    private func recevoir(_ ligne: Data) {
        switch MessageSonde.lire(ligne) {
        case .diag(let r)?:
            attenteDiag.removeValue(forKey: r.id)?.suite.resume(returning: r)
        case .etat(let e)?:
            if !attenteEtat.isEmpty { attenteEtat.removeFirst().resume(returning: e) }
        case .bonjour(let b)?:
            if attenteBonjour.isEmpty {
                bonjourSpontane = b
            } else {
                attenteBonjour.removeFirst().resume(returning: b)
            }
        default:
            break
        }
    }

    /// Liaison fermee : toutes les attentes sont liberees.
    private func clore() {
        fermee = true
        for (id, a) in attenteDiag {
            a.suite.resume(returning: ResultatDiag(id: id, cible: String(format: "%04X", a.cible), ok: false, erreur: "fermee"))
        }
        attenteDiag = [:]
        attenteEtat.forEach { $0.resume(returning: nil) }
        attenteEtat = []
        attenteBonjour.forEach { $0.resume(returning: nil) }
        attenteBonjour = []
    }
}
