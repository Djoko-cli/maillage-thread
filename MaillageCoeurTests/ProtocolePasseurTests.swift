import Foundation
import Testing
@testable import MaillageCoeur

/// Contrat de l'abonnement au passeur (spec du 12/10, section 2). Sans type propre a Maillage Thread : ce fichier se
/// recopie tel quel dans Maillage Zigbee, avec `ProtocolePasseur.swift`.
@Suite("Protocole du passeur : URL, messages, trames")
struct ProtocolePasseurTests {
    static let jeton = String(repeating: "5a", count: 32)
    static let etat = EtatPasseur(version: "2.0", acces: .autorise, ouvertureSession: .inactive, profilExpire: nil)

    static func objet(_ json: Data) -> NSDictionary? {
        (try? JSONSerialization.jsonObject(with: json)) as? NSDictionary
    }

    /// L'URL `abonner` : texte exact, aller-retour, hote sans tenir compte de la casse ; `releve` reste la demande par
    /// defaut ; un autre hote est refuse.
    @Test func urlAbonner() throws {
        let c = EnvoiPasseur.Cible(port: 54_321, jeton: Self.jeton, demande: .abonner)
        #expect(c.url.absoluteString == "maillage-passeur://abonner?port=54321&jeton=\(Self.jeton)")
        #expect(EnvoiPasseur.Cible(url: c.url) == c)
        let majuscules = try #require(URL(string: "MAILLAGE-PASSEUR://ABONNER?port=54321&jeton=\(Self.jeton)"))
        #expect(EnvoiPasseur.Cible(url: majuscules)?.demande == .abonner)
        #expect(EnvoiPasseur.Cible(port: 1, jeton: Self.jeton).demande == .releve, "releve par defaut")
        let abonne = try #require(URL(string: "maillage-passeur://abonne?port=54321&jeton=\(Self.jeton)"))
        #expect(EnvoiPasseur.Cible(url: abonne) == nil, "autre hote")
    }

    /// Chaque message se relit tel quel.
    @Test(arguments: [
        MessagePasseur.etat(ProtocolePasseurTests.etat),
        .etat(EtatPasseur(version: "2.1", acces: .refuse, ouvertureSession: .aApprouver,
                          profilExpire: Date(timeIntervalSince1970: 1_820_000_000))),
        .identifie(ReponseIdentifier(demande: 3, ok: true)),
        .identifie(ReponseIdentifier(demande: 4, ok: false, erreur: ReponseIdentifier.nonIdentifiable)),
        .relire,
        .identifier(demande: 7, accessoire: "8D3C2A10-0000-4000-8000-000000000001"),
        .ouvertureSession(actif: true),
        .ouvertureSession(actif: false),
    ])
    func allerRetour(_ m: MessagePasseur) {
        #expect(MessagePasseur.lire(m.json()) == .message(m))
    }

    /// Le releve voyage en JSON brut : le meme objet a l'arrivee, quel que soit son type dans l'app.
    @Test func releveBrut() throws {
        let noms = Data(#"{"accessoires":[{"nom":"Halo","pont":true}],"date":"2026-10-12T12:00:00.000Z","statut":"ok","version":2}"#.utf8)
        guard case .message(.releve(let lu)) = MessagePasseur.lire(MessagePasseur.releve(noms).json()) else {
            Issue.record("releve non relu")
            return
        }
        #expect(Self.objet(lu) == Self.objet(noms))
    }

    /// Le texte exact de quelques messages : cles triees, `v` et `t`, `null` explicite pour un profil illisible.
    @Test func texteExact() {
        #expect(String(decoding: MessagePasseur.relire.json(), as: UTF8.self) == #"{"t":"relire","v":1}"#)
        #expect(String(decoding: MessagePasseur.identifier(demande: 7, accessoire: "X").json(), as: UTF8.self)
                == #"{"accessoire":"X","demande":7,"t":"identifier","v":1}"#)
        #expect(String(decoding: MessagePasseur.etat(Self.etat).json(), as: UTF8.self)
                == #"{"acces":"autorise","ouvertureSession":"inactive","profilExpire":null,"t":"etat","v":1,"version":"2.0"}"#)
    }

    /// Type inconnu, ou type connu aux champs illisibles : ignore, avec son type (une version suivante ne casse pas une
    /// ancienne).
    @Test(arguments: [
        (#"{"t":"allumer","v":1}"#, "allumer"),
        (#"{"t":"etat","v":1,"version":"2.0","acces":"peutEtre","ouvertureSession":"active","profilExpire":null}"#, "etat"),
        (#"{"t":"etat","v":1,"version":"2.0","acces":"autorise","ouvertureSession":"active","profilExpire":"demain"}"#, "etat"),
        (#"{"t":"identifier","v":1,"demande":1}"#, "identifier"),
        (#"{"t":"identifier","v":1,"demande":1.5,"accessoire":"X"}"#, "identifier"),
        (#"{"t":"ouvertureSession","v":1,"actif":1}"#, "ouvertureSession"),
        (#"{"t":"identifie","v":1,"demande":true,"ok":true}"#, "identifie"),
        (#"{"t":"releve","v":1,"noms":[1,2]}"#, "releve"),
    ])
    func ignore(_ texte: String, _ type: String) {
        #expect(MessagePasseur.lire(Data(texte.utf8)) == .ignore(type))
    }

    /// Pas un objet JSON, ou pas de type : illisible (la connexion se ferme).
    @Test(arguments: [#"[]"#, #""x""#, #"{"v":1}"#, #"{"t":3,"v":1}"#, "{", ""])
    func illisible(_ texte: String) {
        #expect(MessagePasseur.lire(Data(texte.utf8)) == .illisible)
    }
}
