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

/// Attentes d'une commande sans id (`bonjour`, `etat`, `routeurs`) : les reponses les servent
/// dans l'ordre. Chaque attente a son jeton : son echeance n'expire qu'elle, et plus rien une
/// fois qu'elle est servie (par le reseau, une reponse lente ne fait plus echouer la requete
/// suivante).
private struct FileAttentes<Valeur: Sendable> {
    private var attentes: [(jeton: Int, suite: CheckedContinuation<Valeur?, Never>)] = []

    var estVide: Bool { attentes.isEmpty }

    mutating func ajouter(_ jeton: Int, _ suite: CheckedContinuation<Valeur?, Never>) {
        attentes.append((jeton, suite))
    }

    /// La premiere attente recoit `valeur` ; rien sans attente.
    mutating func servir(_ valeur: Valeur?) {
        guard !attentes.isEmpty else { return }
        attentes.removeFirst().suite.resume(returning: valeur)
    }

    /// Echeance de l'attente `jeton` : nil pour elle si elle attend encore. Rend son rang dans
    /// la file (0 : la premiere), nil si elle est deja servie.
    @discardableResult
    mutating func expirer(_ jeton: Int) -> Int? {
        guard let i = attentes.firstIndex(where: { $0.jeton == jeton }) else { return nil }
        attentes.remove(at: i).suite.resume(returning: nil)
        return i
    }

    /// Liaison fermee : toutes recoivent nil.
    mutating func liberer() {
        attentes.forEach { $0.suite.resume(returning: nil) }
        attentes = []
    }
}

/// Sonde branchee en USB : envoie les commandes et apparie les reponses, par
/// ordre pour `bonjour`, `etat` et `routeurs`, par id et cible pour `diag` (8 en vol, dans le
/// desordre). Chaque requete a sa propre echeance.
actor SondeUSB: InterlocuteurSonde {
    enum Erreur: Error, LocalizedError, Equatable {
        case fermee
        case sansReponse(String)
        /// Ligne `erreur` de la sonde pendant une demande de cle (firmware sans acces reseau...).
        case refusee(String)

        var errorDescription: String? {
            switch self {
            case .fermee: String(localized: "liaison avec la sonde fermée")
            case .sansReponse(let commande): String(localized: "la sonde ne répond pas à « \(commande) »")
            case .refusee(let raison): String(localized: "la sonde refuse : \(raison)")
            }
        }
    }

    /// Attente de `bonjour`, `etat`, `routeurs` et `cle nouvelle` : 3 s en USB, qui ne perd rien ;
    /// 6 s par le reseau, au-dela du renvoi de 4 s du canal (comme les delais de Halo : 3 s en
    /// USB, 6 s a distance).
    static let delaiCommandeUSB: Duration = .seconds(3)
    static let delaiCommandeReseau: Duration = .seconds(6)
    /// Attente d'un `diag` au-dela de son delai : la sonde a du repondre (elle echoue elle-meme
    /// en `delai`). Par le reseau, le canal renvoie un diag sans reponse jusqu'a cette echeance.
    static let margeDiag: Duration = .seconds(5)

    private let canal: any CanalSonde
    /// Au-dela du delai donne a la sonde, elle a du repondre (elle echoue elle-meme en `delai`).
    private let marge: Duration
    let delaiCommande: Duration
    private var prochainId = 1
    /// Jetons des attentes de `bonjour`, `etat` et `routeurs` (jamais envoyes a la sonde).
    private var prochainJeton = 1
    private var attenteDiag: [Int: (cible: UInt16, suite: CheckedContinuation<ResultatDiag, Never>)] = [:]
    private var attenteEtat = FileAttentes<EtatSonde>()
    private var attenteBonjour = FileAttentes<Bonjour>()
    private var attenteRouteurs = FileAttentes<[RouteurSonde]>()
    /// Parties de la table des routeurs deja recues (lignes `suite`), en attendant la derniere.
    private var routeursRecus: [RouteurSonde] = []
    private var attenteCle: [(id: Int, suite: CheckedContinuation<Result<ReponseCle, Erreur>?, Never>)] = []
    private var lecture: Task<Void, Never>?
    private(set) var fermee = false
    /// Dernier `bonjour` recu sans l'avoir demande : la sonde vient de (re)demarrer.
    private(set) var bonjourSpontane: Bonjour?

    init(canal: any CanalSonde, marge: Duration = SondeUSB.margeDiag, delaiCommande: Duration = SondeUSB.delaiCommandeUSB) {
        self.canal = canal
        self.marge = marge
        self.delaiCommande = delaiCommande
    }

    /// Ouvre le canal et lit ses lignes ; `surFermeture` quand il se ferme.
    /// Une sonde fermee ne s'ouvre plus : fermee avant d'avoir demarre (connexion
    /// abandonnee), elle n'ouvre jamais le canal.
    func demarrer(surFermeture: @escaping @Sendable () -> Void) throws {
        guard !fermee else { throw Erreur.fermee }
        let lignes = try canal.ouvrir()
        lecture = Task {
            for await l in lignes { self.recevoir(l) }
            self.clore()
            surFermeture()
        }
    }

    /// Ferme le canal et attend la fin de la lecture, qui suit celle du flux :
    /// la liaison serie ne finit son flux qu'apres avoir ferme le port. Sans
    /// lecture (jamais demarree, ou ouverture en echec), la sonde est seulement
    /// marquee fermee.
    func fermer() async {
        guard let lecture else {
            clore()
            return
        }
        canal.fermer()
        await lecture.value
    }

    func bonjour() async throws -> Bonjour {
        guard !fermee else { throw Erreur.fermee }
        let jeton = nouveauJeton()
        let b = await withCheckedContinuation { c in
            attenteBonjour.ajouter(jeton, c)
            canal.envoyer(CommandeSonde.bonjour.ligne)
            Task {
                try? await Task.sleep(for: self.delaiCommande)
                self.attenteBonjour.expirer(jeton)
            }
        }
        guard let b else { throw fermee ? Erreur.fermee : Erreur.sansReponse("bonjour") }
        return b
    }

    func etat() async throws -> EtatSonde {
        guard !fermee else { throw Erreur.fermee }
        let jeton = nouveauJeton()
        let e = await withCheckedContinuation { c in
            attenteEtat.ajouter(jeton, c)
            canal.envoyer(CommandeSonde.etat.ligne)
            Task {
                try? await Task.sleep(for: self.delaiCommande)
                self.attenteEtat.expirer(jeton)
            }
        }
        guard let e else { throw fermee ? Erreur.fermee : Erreur.sansReponse("etat") }
        return e
    }

    /// Table des routeurs, ses lignes `suite` reunies. `sansReponse` si la sonde ne la rend
    /// pas : delai depasse (firmware sans `routeurs`), ou `occupee` (verrou d'OpenThread).
    func routeurs() async throws -> [RouteurSonde] {
        guard !fermee else { throw Erreur.fermee }
        let jeton = nouveauJeton()
        let t = await withCheckedContinuation { c in
            attenteRouteurs.ajouter(jeton, c)
            canal.envoyer(CommandeSonde.routeurs.ligne)
            Task {
                try? await Task.sleep(for: self.delaiCommande)
                self.expirerRouteurs(jeton)
            }
        }
        guard let t else { throw fermee ? Erreur.fermee : Erreur.sansReponse("routeurs") }
        return t
    }

    private func nouveauJeton() -> Int {
        defer { prochainJeton += 1 }
        return prochainJeton
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

    /// `cle nouvelle <alea> <id>` (USB seulement) : la reponse `cle` de meme id, qui porte la
    /// cle une seule fois ; une ligne `erreur` pendant l'attente (commande inconnue d'un
    /// firmware anterieur, refus) la termine en `refusee`. Ni l'alea ni la cle n'apparaissent
    /// dans une erreur.
    func cleNouvelle(alea: Data) async throws -> ReponseCle {
        guard !fermee else { throw Erreur.fermee }
        let id = prochainId
        prochainId += 1
        let r = await withCheckedContinuation { c in
            attenteCle.append((id, c))
            canal.envoyer(CommandeSonde.cleNouvelle(alea: alea, id: id).ligne)
            Task {
                try? await Task.sleep(for: self.delaiCommande)
                self.expirerCle(id)
            }
        }
        switch r {
        case .success(let reponse)?: return reponse
        case .failure(let e)?: throw e
        case nil: throw fermee ? Erreur.fermee : Erreur.sansReponse("cle nouvelle")
        }
    }

    private func expirerCle(_ id: Int) {
        guard let i = attenteCle.firstIndex(where: { $0.id == id }) else { return }
        attenteCle.remove(at: i).suite.resume(returning: nil)
    }

    /// Delai de la requete `jeton` depasse : si elle attend encore et que la table en cours de
    /// reception lui revenait (premiere de la file), cette table est abandonnee avec elle.
    private func expirerRouteurs(_ jeton: Int) {
        if attenteRouteurs.expirer(jeton) == 0 { routeursRecus = [] }
    }

    /// Partie de la table : gardee jusqu'a la derniere (`suite` faux), qui rend la table entiere
    /// a la premiere attente ; l'erreur (`occupee`) la libere sans table. Sans attente (reponse
    /// apres le delai), la table est oubliee.
    private func recevoirRouteurs(_ p: PartieRouteurs) {
        if p.erreur == nil {
            routeursRecus += p.liste
            guard !p.suite else { return }
        }
        let table = p.erreur == nil ? routeursRecus : nil
        routeursRecus = []
        attenteRouteurs.servir(table)
    }

    private func expirerDiag(_ id: Int) {
        guard let a = attenteDiag.removeValue(forKey: id) else { return }
        a.suite.resume(returning: ResultatDiag(id: id, cible: String(format: "%04X", a.cible), ok: false, erreur: "delai"))
    }

    private func recevoir(_ ligne: Data) {
        switch MessageSonde.lire(ligne) {
        case .diag(let r)?:
            // Par l'id et la cible : une reponse tardive d'une connexion precedente (meme id,
            // autre cible) ne sert pas cette requete, qui attend la sienne.
            if let a = attenteDiag[r.id], UInt16(r.cible, radix: 16) == a.cible {
                attenteDiag[r.id] = nil
                a.suite.resume(returning: r)
            }
        case .etat(let e)?:
            attenteEtat.servir(e)
        case .routeurs(let p)?:
            recevoirRouteurs(p)
        case .bonjour(let b)?:
            if attenteBonjour.estVide {
                bonjourSpontane = b
            } else {
                attenteBonjour.servir(b)
            }
        case .cle(let c)?:
            if let i = attenteCle.firstIndex(where: { $0.id == c.id }) { attenteCle.remove(at: i).suite.resume(returning: .success(c)) }
        case .erreur(let e)? where !attenteCle.isEmpty:
            // Sans id : la demande de cle en cours (une seule a la fois dans l'app).
            attenteCle.removeFirst().suite.resume(returning: .failure(.refusee(e)))
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
        attenteEtat.liberer()
        attenteBonjour.liberer()
        attenteRouteurs.liberer()
        routeursRecus = []
        attenteCle.forEach { $0.suite.resume(returning: nil) }
        attenteCle = []
    }
}
