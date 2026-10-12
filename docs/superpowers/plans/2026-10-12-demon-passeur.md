# Démon Passeur Noms : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** remplacer le Passeur Noms actuel (app iOS « conçue pour iPad », fenêtre et Dock, relevé ponctuel) par un démon Mac Catalyst invisible qui sert Maison en continu à Maillage Thread (abonnement, « Identifier », ouverture de session), puis livrer le client dans Maillage Thread 1.3.0.

**Architecture:** un contrat d'échange commun (`MaillageCoeur/Noms/ProtocolePasseur.swift`, identique à l'octet dans Maillage Zigbee) définit l'URL `abonner`, les trames `<longueur>\n<JSON>` et les messages `{"v":1,"t":…}`. Le démon est une app Catalyst (`Passeur`) dont le cœur (`Passeur/Logique/`) ne dépend ni de HomeKit ni d'UIKit, et se teste sur macOS (cible `PasseurTests`) derrière des façades imitées ; HomeKit, la scène et le paquet AppKit `Masqueur.bundle` (fenêtres invisibles dès leur création) restent en bordure. Côté app, `AbonnementPasseur` remplace `EcouteReleve` et `NomsInternes` devient un client abonné avec réabonnement.

**Tech Stack:** Swift 6 (concurrence stricte, avertissements en erreurs), SwiftUI/AppKit (app), UIKit + Mac Catalyst + HomeKit + ServiceManagement (démon), Network.framework (boucle locale), Swift Testing, XcodeGen, `xcodebuild`, Python 3 (outil de banc).

**Spec:** `docs/superpowers/specs/2026-10-12-demon-passeur-design.md` (validée par Djoko le 12/10/2026). Elle fait foi ; ce plan l'applique aux étapes 1 et 2 de sa section 7. L'étape 3 (Maillage Zigbee) est faite par la session Zigbee : la tâche 15 lui passe la main.

**Branche :** `demon-passeur`, dans une copie de travail isolée (superpowers:using-git-worktrees).

## Global Constraints

- Identité du démon inchangée : identifiant `fr.djoko.maillage.passeur`, schéma d'URL `maillage-passeur`, nom « Passeur Noms ». Cible `Passeur` : `platform: iOS`, `deploymentTarget: "18.0"`, `SUPPORTS_MACCATALYST: YES`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO`, `LSUIElement: true`. Version du démon : `MARKETING_VERSION: "2.0"`.
- Signature du démon : développement seulement (équipe payante, profil d'un an, Mac enregistré), par `outils/passeur.sh`. Jamais de .dmg, jamais de notarisation, jamais de Developer ID pour lui.
- Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` (réglages du projet, valables aussi pour `Passeur`, `Masqueur` et `PasseurTests`).
- `ProtocolePasseur.swift` doit compiler tel quel dans Maillage Zigbee : il ne dépend que de Foundation et de `CodageJSON` (fichier identique dans les deux dépôts), **jamais** de `NomsMaison` ni d'un autre type propre à Thread. Le relevé y voyage en JSON brut (`MessagePasseur.releve(Data)`).
- Échange (spec 2.1 à 2.3) : 127.0.0.1 seulement ; port de 1 à 65535 ; jeton de 64 chiffres hexadécimaux minuscules (32 octets) ; `tailleMax` 8 Mo par message ; trame `<longueur décimale>\n<JSON>` ; enveloppe `{"v":1,"t":"<type>", …}` ; type inconnu ignoré ; trame mal formée (longueur illisible, nulle ou trop grande, JSON illisible) : connexion fermée.
- Délais (spec 3 et 4) : regroupement des changements **2 s** ; relecture des batteries **toutes les heures** ; fermeture **10 min** après le dernier abonné ; réabonnement après **5 s, 10 s, 30 s, puis toutes les minutes** ; premier délai d'attente du démon **2 min** ; avertissement du profil **30 jours** avant ; attente de Maison pour un relevé ponctuel **100 s** (comme l'ancien passeur).
- `NomsMaison.versionActuelle` passe à **2** (champ `id` des accessoires) ; une ancienne app qui demande un relevé ponctuel (`releve`) reçoit un relevé de **version 1, sans `id`** (elle refuse une version plus récente que la sienne).
- Journal du démon : sous-système `fr.djoko.maillage.passeur`. **Jamais un nom de la maison, ni un UUID d'accessoire, ni le jeton** ; des raisons, des nombres, des erreurs.
- Les tests n'appellent jamais HomeKit, `SMAppService`, `NSWorkspace.open`, ni le vrai démon : `NomsInternes` n'a pas de lanceur par défaut, `DemonPasseur` reçoit toutes ses dépendances.
- Mode démo de l'app : jamais de démon (`cache == nil` : rien n'est lancé).
- Règles du dépôt : commentaires de code en français **sans accents** ; textes de l'interface en français avec accents, catalogue synchronisé et traduit en anglais (`outils/synchroniser-textes.sh`, `outils/traduire.py`) ; messages de commit en français sans accents, terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ; jamais `git add -A` ni `git add .` ; aucun identifiant d'équipe, empreinte de certificat, nom légal, adresse électronique, nom réel de pièce ou d'appareil dans un fichier suivi ; le contenu de `noms.json` n'est jamais affiché.
- Les sous-agents ne lancent jamais le démon, ni `outils/passeur.sh`, ni Maillage Thread en mode direct, ni `open maillage-passeur://…` : les tâches de banc (9 et 14) sont faites par le contrôleur, avec Djoko.

## Review Focus

1. **L'ancien Passeur (app iOS) encore installé** quand Maillage Thread 1.3.0 tourne : il ne connaît pas `abonner` et ouvrirait sa fenêtre à chaque réabonnement. Attendu : l'app ne le lance pas et dit « Passeur Noms est l'ancienne version : relance outils/passeur.sh. ». Test : `problemeInstallation` (tâche 11).
2. **Une ancienne app** (Maillage Thread 1.2.2, Maillage Zigbee 1.1) qui demande un relevé ponctuel au nouveau démon : un relevé de version 2 serait refusé (« version trop récente »). Attendu : version 1, sans `id`. Tests : `enVersion1` (tâche 3) et `ponctuelEnVersion1` (tâche 6).
3. **Deux accessoires de même nom** : leur ordre peut changer d'un relevé à l'autre, et chaque changement de Maison renverrait un relevé « différent ». Attendu : ordre stable (nom, puis `id`) et aucun envoi. Test : `ordreStableDesHomonymes` (tâche 5).
4. **Plusieurs messages dans un même paquet TCP, ou un message coupé en plusieurs paquets** (le démon écrit `etat` puis `releve` d'affilée). Attendu : tous lus, dans l'ordre. Tests : `plusieursTramesDUnCoup` et `trameOctetParOctet` (tâche 2), `jetonEtatEtReleveDUnCoup` (tâche 10).
5. **Une réponse d'identification en retard** (une demande plus récente est partie entre-temps) : attendu, elle est ignorée et n'écrase pas le résultat courant. Test : `reponseIdentifierEnRetard` (tâche 11).

---

## Fichiers

| Fichier | Rôle |
|---|---|
| `MaillageCoeur/Noms/ProtocolePasseur.swift` | (renommé depuis `EnvoiPasseur.swift`) URL `releve`/`abonner`, jeton, lecture du relevé ponctuel, messages, trames, lecteurs de flux |
| `MaillageCoeurTests/ProtocolePasseurTests.swift` | tests du contrat, sans type propre à Thread (recopiables dans Zigbee) |
| `MaillageCoeur/Noms/NomsMaison.swift` | `AccessoireMaison.id`, version 2, `enVersion1()` |
| `Passeur/Logique/Dependances.swift` | façades `SourceMaison`, `LienApp`, `OuvertureSessionDemon`, `Horloge`, `HorlogeReelle`, `UneFois` |
| `Passeur/Logique/Journal.swift` | `journal` (Logger du démon) |
| `Passeur/Logique/ProfilPasseur.swift` | date d'expiration du profil embarqué |
| `Passeur/Logique/OuvertureSMAppService.swift` | correspondance `SMAppService.Status` → `EtatPasseur.Ouverture`, ouverture réelle |
| `Passeur/Logique/DemonPasseur.swift` | cœur du démon : abonnés, relevés, regroupement, batteries, identifier, ouverture, durée de vie, relevé ponctuel |
| `Passeur/Logique/ConnexionApp.swift` | `ConnexionApp` (lien d'abonnement réel) et `LivraisonPonctuelle` |
| `Passeur/MaisonHomeKit.swift` | `SourceMaison` par HomeKit (délégués, relevé, batteries, `identify()`) |
| `Passeur/AppDelegate.swift`, `Passeur/SceneDelegate.swift` | entrée UIKit, chargement de `Masqueur.bundle`, scène refermée, URL transmises |
| `Masqueur/Masqueur.swift` | paquet AppKit : initialiseurs de `NSWindow` interceptés, politique `.accessory` |
| `PasseurTests/*.swift` | tests du cœur du démon (macOS, sans HomeKit) |
| `outils/passeur.sh` | compile en Catalyst, installe, enregistre auprès de LaunchServices |
| `outils/verifier-passeur.py`, `outils/tests/test_verifier_passeur.py` | outil de banc : relevé ponctuel ou abonnement, résumés chiffrés seulement |
| `MaillageThread/Noms/AbonnementPasseur.swift` | (remplace `EcouteReleve.swift`) écoute, jeton, trames dans les deux sens |
| `MaillageThread/Noms/NomsInternes.swift` | client abonné, réabonnement, commandes, textes |
| `MaillageThread/Vues/FenetreReglages.swift` | Réglages › Maison : état, interrupteur, profil |
| `MaillageThread/Vues/Pieces/BoutonIdentifier.swift`, `FicheNoeud.swift` | bouton « Identifier » |
| `MaillageThread/Vues/MenuBarre.swift`, `Pieces/FenetrePieces.swift`, `Pieces/MorceauxFenetre.swift` | `relire()` à la place de `lancerPasseur()`, fin de la relance horaire |
| `project.yml` | cibles `Passeur` (Catalyst), `Masqueur`, `PasseurTests` ; version 1.3.0 |

---

### Task 1 : URL `abonner` et messages du contrat

**Files:**
- Rename: `MaillageCoeur/Noms/EnvoiPasseur.swift` → `MaillageCoeur/Noms/ProtocolePasseur.swift` (`git mv`)
- Modify: `project.yml` (sources de la cible `Passeur` : le nouveau nom du fichier)
- Create: `MaillageCoeurTests/ProtocolePasseurTests.swift`

**Interfaces:**
- Consumes : `EnvoiPasseur` existant (`Cible`, `nouveauJeton()`, `trame(jeton:json:)`, `Lecture`), `CodageJSON.avecMillisecondes` / `sansMillisecondes` (statiques internes du module).
- Produces :
  - `EnvoiPasseur.Demande` (`.releve`, `.abonner`) ; `EnvoiPasseur.Cible(port:jeton:demande: = .releve)`, `cible.demande`, `Cible(url:)` qui lit les deux hôtes.
  - `public struct EtatPasseur: Hashable, Sendable` avec `version: String`, `acces: EtatPasseur.Acces` (`attente`, `autorise`, `refuse`), `ouvertureSession: EtatPasseur.Ouverture` (`active`, `inactive`, `aApprouver`, `indisponible`), `profilExpire: Date?`.
  - `public struct ReponseIdentifier: Hashable, Sendable` (`demande: Int`, `ok: Bool`, `erreur: String?`, constantes `inconnu`, `nonIdentifiable`).
  - `public enum MessagePasseur: Hashable, Sendable` : `.etat(EtatPasseur)`, `.releve(Data)`, `.identifie(ReponseIdentifier)`, `.relire`, `.identifier(demande: Int, accessoire: String)`, `.ouvertureSession(actif: Bool)` ; `var type: String` ; `func json() -> Data` ; `static func lire(_ json: Data) -> MessagePasseur.Lu` avec `Lu` = `.message(MessagePasseur)`, `.ignore(String)`, `.illisible`.

- [x] **Step 1 : renommer le fichier et suivre le renommage dans le projet**

```bash
cd ~/Dev/maillage-thread   # ou la copie de travail de la branche
git mv MaillageCoeur/Noms/EnvoiPasseur.swift MaillageCoeur/Noms/ProtocolePasseur.swift
```

Dans `project.yml`, cible `Passeur`, remplacer la ligne `- path: MaillageCoeur/Noms/EnvoiPasseur.swift` par `- path: MaillageCoeur/Noms/ProtocolePasseur.swift`.

- [x] **Step 2 : écrire les tests qui échouent**

Créer `MaillageCoeurTests/ProtocolePasseurTests.swift` :

```swift
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
```

- [x] **Step 3 : lancer les tests, vérifier qu'ils échouent**

Run : `outils/tester.sh MaillageCoeurTests/ProtocolePasseurTests`
Expected : échec de compilation (`Demande`, `EtatPasseur`, `MessagePasseur` inconnus).

- [x] **Step 4 : écrire le code**

Dans `MaillageCoeur/Noms/ProtocolePasseur.swift` :

1. Remplacer le commentaire d'en-tête de `EnvoiPasseur` (les lignes `/// Envoi du releve du passeur…` jusqu'à `/// Commun a l'app et au passeur, qui compile ce fichier (`project.yml`).`) par :

```swift
/// Echange entre les apps (Maillage Thread, Maillage Zigbee) et le passeur Passeur Noms par la boucle locale du Mac
/// (TCP sur 127.0.0.1), sans dossier partage ni App Group (spec du demon, 12/10/2026, section 2) :
/// 1. l'app ecoute sur 127.0.0.1, sur un port choisi par le systeme, et tire un jeton a usage unique ;
/// 2. elle ouvre le passeur, sans l'activer, avec l'URL `maillage-passeur://<demande>?port=<port>&jeton=<jeton>`
///    (`Cible`) : une app du bac a sable ne peut pas passer d'arguments de lancement, macOS les retire ;
/// 3. `releve` (releve ponctuel) : le passeur se connecte, envoie le jeton sur une ligne, la longueur du JSON sur une
///    ligne, puis le JSON du releve, et ferme (`trame(jeton:json:)`, lu par `Lecture`) ;
/// 4. `abonner` : le passeur se connecte, envoie le jeton sur une ligne (`ligneJeton`), puis les deux cotes echangent des
///    messages (`MessagePasseur`), chacun en trame `<longueur>\n<JSON>` (`trame(_:)`, lu par `LectureTrames` et
///    `LectureFlux`) ; la connexion reste ouverte.
/// Ce fichier est identique a l'octet dans les deux depots, et compile aussi dans le passeur (`project.yml`) : il ne
/// depend que de Foundation et de `CodageJSON`.
```

2. Supprimer `private static let hote = "releve"` et ajouter, juste avant `public struct Cible` :

```swift
    /// Ce que l'URL demande au passeur : un releve ponctuel, puis la connexion est fermee (`releve`), ou un
    /// abonnement, dont la connexion reste ouverte (`abonner`). C'est l'hote de l'URL.
    public enum Demande: String, Hashable, Sendable, CaseIterable {
        case releve
        case abonner
    }
```

3. Dans `Cible` : ajouter la propriété `public var demande: Demande` ; l'initialiseur devient

```swift
        public init(port: UInt16, jeton: String, demande: Demande = .releve) {
            self.port = port
            self.jeton = jeton
            self.demande = demande
        }
```

dans `url`, `c.host = EnvoiPasseur.hote` devient `c.host = demande.rawValue` et le commentaire de `url` dit `maillage-passeur://<demande>?port=<port>&jeton=<jeton>` ; dans `init?(url:)`, la garde devient

```swift
            guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  c.scheme?.lowercased() == EnvoiPasseur.schema,
                  let demande = c.host.flatMap({ Demande(rawValue: $0.lowercased()) }) else { return nil }
```

et la fin `self.init(port: port, jeton: jeton, demande: demande)`. Le commentaire de `init?(url:)` dit « autre schema ou hote qui n'est pas une `Demande` ».

4. À la fin du fichier, ajouter :

```swift
/// Etat du passeur, envoye a chaque abonne a la connexion, puis a chaque changement.
public struct EtatPasseur: Hashable, Sendable {
    /// Acces a Maison (`HMHomeManager.authorizationStatus`).
    public enum Acces: String, Hashable, Sendable {
        case attente, autorise, refuse
    }

    /// Ouverture a la session du passeur (`SMAppService.Status`) : `enabled` -> `active`, `notRegistered` ->
    /// `inactive`, `requiresApproval` -> `aApprouver` (refusee, ou pas encore acceptee dans Reglages > General >
    /// Ouverture), `notFound` -> `indisponible`.
    public enum Ouverture: String, Hashable, Sendable {
        case active, inactive, aApprouver, indisponible
    }

    public var version: String
    public var acces: Acces
    public var ouvertureSession: Ouverture
    /// Expiration du profil de developpement du passeur ; nil s'il est illisible.
    public var profilExpire: Date?

    public init(version: String, acces: Acces, ouvertureSession: Ouverture, profilExpire: Date?) {
        self.version = version
        self.acces = acces
        self.ouvertureSession = ouvertureSession
        self.profilExpire = profilExpire
    }
}

/// Reponse du passeur a `identifier`.
public struct ReponseIdentifier: Hashable, Sendable {
    /// `erreur` : aucun accessoire de Maison n'a cet identifiant.
    public static let inconnu = "inconnu"
    /// `erreur` : l'accessoire ne sait pas s'identifier (`supportsIdentify` faux).
    public static let nonIdentifiable = "nonIdentifiable"

    /// Le numero de la demande, choisi par l'app.
    public var demande: Int
    public var ok: Bool
    /// nil si `ok` ; sinon `inconnu`, `nonIdentifiable`, ou le texte de l'erreur de HomeKit.
    public var erreur: String?

    public init(demande: Int, ok: Bool, erreur: String? = nil) {
        self.demande = demande
        self.ok = ok
        self.erreur = erreur
    }
}

/// Message de l'abonnement, dans un sens ou dans l'autre : un objet JSON `{"v":1,"t":"<type>", ...}`.
public enum MessagePasseur: Hashable, Sendable {
    // Du passeur vers l'app.
    case etat(EtatPasseur)
    /// `noms` : le JSON du releve, objet tel quel. Chaque app le lit dans son propre type (`NomsMaison` dans Maillage
    /// Thread, `ReleveMaison` dans Maillage Zigbee) : ce fichier, commun aux deux, n'en depend pas.
    case releve(Data)
    case identifie(ReponseIdentifier)
    // De l'app vers le passeur.
    case relire
    case identifier(demande: Int, accessoire: String)
    case ouvertureSession(actif: Bool)

    /// Version du format des messages (`v`).
    public static let version = 1

    /// Issue de la lecture d'un message.
    public enum Lu: Hashable, Sendable {
        case message(MessagePasseur)
        /// Type inconnu, ou type connu dont les champs ne se lisent pas : ignore, pour qu'une version suivante ne casse
        /// pas une ancienne. Son type, pour le journal.
        case ignore(String)
        /// Pas un objet JSON, ou sans type `t` texte : la trame est mal formee, la connexion se ferme.
        case illisible
    }

    /// Le `t` du message.
    public var type: String {
        switch self {
        case .etat: "etat"
        case .releve: "releve"
        case .identifie: "identifie"
        case .relire: "relire"
        case .identifier: "identifier"
        case .ouvertureSession: "ouvertureSession"
        }
    }

    /// Le JSON du message : cles triees, barres obliques non echappees ; `null` explicite pour un champ absent
    /// (`profilExpire`, `erreur`). Un releve qui n'est pas du JSON (jamais : il sort d'un encodeur) part en `null`.
    public func json() -> Data {
        var d: [String: Any] = ["v": Self.version, "t": type]
        switch self {
        case .etat(let e):
            d["version"] = e.version
            d["acces"] = e.acces.rawValue
            d["ouvertureSession"] = e.ouvertureSession.rawValue
            d["profilExpire"] = e.profilExpire.map { $0.formatted(CodageJSON.avecMillisecondes) } ?? NSNull()
        case .releve(let noms):
            d["noms"] = (try? JSONSerialization.jsonObject(with: noms)) ?? NSNull()
        case .identifie(let r):
            d["demande"] = r.demande
            d["ok"] = r.ok
            d["erreur"] = r.erreur ?? NSNull()
        case .relire:
            break
        case .identifier(let demande, let accessoire):
            d["demande"] = demande
            d["accessoire"] = accessoire
        case .ouvertureSession(let actif):
            d["actif"] = actif
        }
        // Que des valeurs de JSON (textes, nombres, booleens, null, objets lus par JSONSerialization).
        guard let json = try? JSONSerialization.data(withJSONObject: d, options: [.sortedKeys, .withoutEscapingSlashes])
        else { preconditionFailure("message du passeur impossible a encoder") }
        return json
    }

    /// Lit un message.
    public static func lire(_ json: Data) -> Lu {
        guard let d = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any],
              let t = d["t"] as? String else { return .illisible }
        let m: MessagePasseur?
        switch t {
        case "etat":
            m = lireEtat(d).map { .etat($0) }
        case "releve":
            m = (d["noms"] as? [String: Any])
                .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys, .withoutEscapingSlashes]) }
                .map { .releve($0) }
        case "identifie":
            if let demande = entier(d["demande"]), let ok = booleen(d["ok"]) {
                m = .identifie(ReponseIdentifier(demande: demande, ok: ok, erreur: d["erreur"] as? String))
            } else {
                m = nil
            }
        case "relire":
            m = .relire
        case "identifier":
            if let demande = entier(d["demande"]), let accessoire = d["accessoire"] as? String {
                m = .identifier(demande: demande, accessoire: accessoire)
            } else {
                m = nil
            }
        case "ouvertureSession":
            m = booleen(d["actif"]).map { .ouvertureSession(actif: $0) }
        default:
            m = nil
        }
        return m.map(Lu.message) ?? .ignore(t)
    }

    private static func lireEtat(_ d: [String: Any]) -> EtatPasseur? {
        guard let version = d["version"] as? String,
              let acces = (d["acces"] as? String).flatMap(EtatPasseur.Acces.init(rawValue:)),
              let ouverture = (d["ouvertureSession"] as? String).flatMap(EtatPasseur.Ouverture.init(rawValue:))
        else { return nil }
        let brut = d["profilExpire"]
        let profil: Date?
        if brut == nil || brut is NSNull {
            profil = nil
        } else if let texte = brut as? String,
                  let date = (try? CodageJSON.avecMillisecondes.parse(texte)) ?? (try? CodageJSON.sansMillisecondes.parse(texte)) {
            profil = date
        } else {
            return nil
        }
        return EtatPasseur(version: version, acces: acces, ouvertureSession: ouverture, profilExpire: profil)
    }

    /// Booleen JSON, pas un nombre : JSONSerialization rend les deux en NSNumber.
    private static func booleen(_ v: Any?) -> Bool? {
        guard let n = v as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return nil }
        return n.boolValue
    }

    /// Entier JSON : ni booleen, ni nombre a virgule.
    private static func entier(_ v: Any?) -> Int? {
        guard let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else { return nil }
        return Int(exactly: n.doubleValue)
    }
}
```

- [x] **Step 5 : lancer les tests, vérifier qu'ils passent**

Run : `outils/tester.sh MaillageCoeurTests/ProtocolePasseurTests MaillageCoeurTests/EnvoiPasseurTests MaillageThreadTests/NomsInternesTests`
Expected : PASS (les tests existants du relevé ponctuel restent verts : `Cible(port:jeton:)` vaut `releve`).

- [x] **Step 6 : commit**

```bash
git add project.yml MaillageCoeur/Noms/ProtocolePasseur.swift MaillageCoeurTests/ProtocolePasseurTests.swift
git commit -m "Protocole du passeur : URL abonner et messages de l'abonnement

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`git mv` a déjà indexé la suppression de `EnvoiPasseur.swift`.)

---

### Task 2 : trames de l'abonnement et lecteurs de flux

**Files:**
- Modify: `MaillageCoeur/Noms/ProtocolePasseur.swift`
- Modify: `MaillageCoeurTests/ProtocolePasseurTests.swift`

**Interfaces:**
- Consumes : `MessagePasseur.json()` (tâche 1), `EnvoiPasseur.Lecture.entier`, `Lecture.egaux`, `Lecture.chiffresMax` (statiques internes existants), `EnvoiPasseur.tailleMax`.
- Produces :
  - `EnvoiPasseur.ligneJeton(_ jeton: String) -> Data` (`"<jeton>\n"`).
  - `EnvoiPasseur.trame(_ m: MessagePasseur) -> Data` (`"<longueur>\n<JSON>"`).
  - `public struct EnvoiPasseur.IssueFlux: Equatable, Sendable { var trames: [Data]; var erreur: Erreur? }` avec `Erreur` = `.jetonFaux`, `.trameFausse`.
  - `public struct EnvoiPasseur.LectureTrames` : `init()`, `mutating func ajouter(_ octets: Data) -> IssueFlux` (le démon lit l'app).
  - `public struct EnvoiPasseur.LectureFlux` : `init(jeton:)`, `var jetonAccepte: Bool`, `mutating func ajouter(_ octets: Data) -> IssueFlux` (l'app lit le démon).

- [x] **Step 1 : écrire les tests qui échouent**

Ajouter dans `ProtocolePasseurTests` :

```swift
    /// Lit des octets arrives en paquets de `taille` ; rend toutes les trames et la premiere erreur.
    static func lireTrames(_ octets: Data, par taille: Int) -> EnvoiPasseur.IssueFlux {
        var l = EnvoiPasseur.LectureTrames()
        var tout = EnvoiPasseur.IssueFlux(trames: [], erreur: nil)
        var i = octets.startIndex
        while i < octets.endIndex {
            let j = min(i + taille, octets.endIndex)
            let issue = l.ajouter(octets[i..<j])
            tout.trames += issue.trames
            if let e = issue.erreur { tout.erreur = e; break }
            i = j
        }
        return tout
    }

    @Test func trameDUnMessage() {
        let json = MessagePasseur.relire.json()
        #expect(EnvoiPasseur.trame(.relire) == Data("\(json.count)\n".utf8) + json)
        #expect(EnvoiPasseur.ligneJeton(Self.jeton) == Data("\(Self.jeton)\n".utf8))
    }

    /// Plusieurs trames dans un meme paquet : toutes, dans l'ordre.
    @Test func plusieursTramesDUnCoup() {
        let octets = EnvoiPasseur.trame(.etat(Self.etat)) + EnvoiPasseur.trame(.relire)
            + EnvoiPasseur.trame(.ouvertureSession(actif: true))
        let issue = Self.lireTrames(octets, par: octets.count)
        #expect(issue.erreur == nil)
        #expect(issue.trames.map(MessagePasseur.lire) == [.message(.etat(Self.etat)), .message(.relire),
                                                          .message(.ouvertureSession(actif: true))])
    }

    /// Une trame octet par octet, puis en paquets de 7 : la meme lecture.
    @Test(arguments: [1, 7])
    func trameOctetParOctet(_ taille: Int) {
        let octets = EnvoiPasseur.trame(.etat(Self.etat)) + EnvoiPasseur.trame(.relire)
        let issue = Self.lireTrames(octets, par: taille)
        #expect(issue.erreur == nil)
        #expect(issue.trames.count == 2)
    }

    /// Longueur nulle, trop grande, illisible, ou ligne de longueur sans fin au-dela de 16 chiffres : trame fausse,
    /// puis plus rien ne se lit.
    @Test(arguments: ["0\n{}", "\(EnvoiPasseur.tailleMax + 1)\n", "+5\n", "5 \n", "x\n", "12345678901234567"])
    func trameFausse(_ texte: String) {
        var l = EnvoiPasseur.LectureTrames()
        #expect(l.ajouter(Data(texte.utf8)).erreur == .trameFausse)
        #expect(l.ajouter(EnvoiPasseur.trame(.relire)) == EnvoiPasseur.IssueFlux(trames: [], erreur: .trameFausse))
    }

    /// Les trames completes avant une trame fausse sont rendues avec l'erreur.
    @Test func tramesAvantLErreur() {
        var l = EnvoiPasseur.LectureTrames()
        let issue = l.ajouter(EnvoiPasseur.trame(.relire) + Data("x\n".utf8))
        #expect(issue.trames.count == 1)
        #expect(issue.erreur == .trameFausse)
    }

    /// Cote app : le jeton d'abord (meme coupe en deux), puis les trames du meme paquet.
    @Test func fluxAvecJeton() {
        var l = EnvoiPasseur.LectureFlux(jeton: Self.jeton)
        let octets = EnvoiPasseur.ligneJeton(Self.jeton) + EnvoiPasseur.trame(.etat(Self.etat))
        #expect(l.ajouter(octets.prefix(10)) == EnvoiPasseur.IssueFlux(trames: [], erreur: nil))
        #expect(!l.jetonAccepte)
        let issue = l.ajouter(octets.dropFirst(10))
        #expect(l.jetonAccepte)
        #expect(issue.erreur == nil)
        #expect(issue.trames.map(MessagePasseur.lire) == [.message(.etat(Self.etat))])
    }

    /// Mauvais jeton, ou premiere ligne trop longue sans fin : jeton faux, et plus rien ensuite.
    @Test func fluxJetonFaux() {
        var l = EnvoiPasseur.LectureFlux(jeton: Self.jeton)
        #expect(l.ajouter(EnvoiPasseur.ligneJeton(String(repeating: "00", count: 32))).erreur == .jetonFaux)
        #expect(l.ajouter(EnvoiPasseur.ligneJeton(Self.jeton)).erreur == .jetonFaux)
        var long = EnvoiPasseur.LectureFlux(jeton: Self.jeton)
        #expect(long.ajouter(Data(String(repeating: "a", count: 65).utf8)).erreur == .jetonFaux)
        var vide = EnvoiPasseur.LectureFlux(jeton: "")
        #expect(vide.ajouter(Data("\n".utf8)).erreur == .jetonFaux, "un jeton attendu vide ne laisse rien passer")
    }
```

- [x] **Step 2 : lancer les tests, vérifier qu'ils échouent**

Run : `outils/tester.sh MaillageCoeurTests/ProtocolePasseurTests`
Expected : échec de compilation (`LectureTrames`, `IssueFlux`, `ligneJeton` inconnus).

- [x] **Step 3 : écrire le code**

À la fin de `ProtocolePasseur.swift` :

```swift
extension EnvoiPasseur {
    /// Premiere ligne d'une connexion d'abonnement, du passeur vers l'app : le jeton.
    public static func ligneJeton(_ jeton: String) -> Data {
        Data("\(jeton)\n".utf8)
    }

    /// Trame d'un message de l'abonnement : sa longueur en decimal sur une ligne, puis son JSON.
    public static func trame(_ m: MessagePasseur) -> Data {
        let json = m.json()
        return Data("\(json.count)\n".utf8) + json
    }

    /// Ce que rend une lecture de flux : les JSON des trames completes, dans l'ordre, et l'erreur qui a arrete la
    /// lecture (la connexion se ferme alors ; les trames rendues avec elle restent valables).
    public struct IssueFlux: Equatable, Sendable {
        public enum Erreur: Equatable, Sendable {
            /// Premiere ligne autre que le jeton attendu.
            case jetonFaux
            /// Longueur illisible, nulle ou au-dela de `tailleMax`.
            case trameFausse
        }

        public var trames: [Data]
        public var erreur: Erreur?

        public init(trames: [Data], erreur: Erreur?) {
            self.trames = trames
            self.erreur = erreur
        }
    }

    /// Lecture d'une suite de trames `<longueur>\n<JSON>` au fil des octets recus, sans jeton : le passeur lit ainsi ce
    /// que l'app lui envoie. Plusieurs trames peuvent arriver d'un coup, une trame en plusieurs fois. Apres une
    /// erreur, plus rien ne se lit.
    public struct LectureTrames: Sendable {
        private var tampon = Data()
        /// Longueur lue, JSON pas encore complet.
        private var attendue: Int?
        private var faussee = false

        public init() {}

        public mutating func ajouter(_ octets: Data) -> IssueFlux {
            guard !faussee else { return IssueFlux(trames: [], erreur: .trameFausse) }
            tampon.append(octets)
            var trames: [Data] = []
            while true {
                if let n = attendue {
                    guard tampon.count >= n else { break }
                    let debut = tampon.startIndex
                    trames.append(Data(tampon[debut..<debut + n]))
                    tampon.removeSubrange(debut..<debut + n)
                    attendue = nil
                } else {
                    guard let fin = tampon.firstIndex(of: 0x0A) else {
                        if tampon.count > Lecture.chiffresMax { return fausser(trames) }
                        break
                    }
                    let ligne = Array(tampon[tampon.startIndex..<fin])
                    tampon.removeSubrange(tampon.startIndex...fin)
                    guard let n = Lecture.entier(ligne), n > 0, n <= EnvoiPasseur.tailleMax else { return fausser(trames) }
                    attendue = n
                }
            }
            return IssueFlux(trames: trames, erreur: nil)
        }

        private mutating func fausser(_ trames: [Data]) -> IssueFlux {
            faussee = true
            tampon = Data()
            return IssueFlux(trames: trames, erreur: .trameFausse)
        }
    }

    /// Lecture d'une connexion d'abonnement par l'app : le jeton sur la premiere ligne (compare a temps constant),
    /// puis des trames (`LectureTrames`). Apres une erreur, plus rien ne se lit.
    public struct LectureFlux: Sendable {
        private let attendu: [UInt8]
        private var avantJeton = Data()
        private var trames = LectureTrames()
        private var erreur: IssueFlux.Erreur?
        /// Le jeton est arrive et c'est le bon.
        public private(set) var jetonAccepte = false

        public init(jeton: String) {
            attendu = Array(jeton.utf8)
        }

        public mutating func ajouter(_ octets: Data) -> IssueFlux {
            if let erreur { return IssueFlux(trames: [], erreur: erreur) }
            var reste = octets
            if !jetonAccepte {
                avantJeton.append(octets)
                guard let fin = avantJeton.firstIndex(of: 0x0A) else {
                    if avantJeton.count > attendu.count { return echouer(.jetonFaux) }
                    return IssueFlux(trames: [], erreur: nil)
                }
                guard Lecture.egaux(Array(avantJeton[avantJeton.startIndex..<fin]), attendu) else {
                    return echouer(.jetonFaux)
                }
                jetonAccepte = true
                reste = Data(avantJeton[avantJeton.index(after: fin)...])
                avantJeton = Data()
            }
            let issue = trames.ajouter(reste)
            if let e = issue.erreur { erreur = e }
            return issue
        }

        private mutating func echouer(_ e: IssueFlux.Erreur) -> IssueFlux {
            erreur = e
            avantJeton = Data()
            return IssueFlux(trames: [], erreur: e)
        }
    }
}
```

- [x] **Step 4 : lancer les tests, vérifier qu'ils passent**

Run : `outils/tester.sh MaillageCoeurTests/ProtocolePasseurTests MaillageCoeurTests/EnvoiPasseurTests`
Expected : PASS.

- [x] **Step 5 : commit**

```bash
git add MaillageCoeur/Noms/ProtocolePasseur.swift MaillageCoeurTests/ProtocolePasseurTests.swift
git commit -m "Protocole du passeur : trames de l'abonnement, lecture du flux avec et sans jeton

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 : identifiant des accessoires, relevé de version 2

**Files:**
- Modify: `MaillageCoeur/Noms/NomsMaison.swift`
- Modify: `MaillageCoeurTests/NomsTests.swift` (tests `contratZones`, `fichierNomsJSON`, nouveau `contratIdentifiant`)

**Interfaces:**
- Produces : `AccessoireMaison.id: String?` (dernier paramètre de l'initialiseur, `id: String? = nil`) ; `NomsMaison.versionActuelle == 2` ; `NomsMaison.enVersion1() -> NomsMaison`.

- [x] **Step 1 : écrire les tests qui échouent**

Dans `NomsTests.swift` :
- dans `contratZones`, remplacer `#expect(NomsMaison.versionActuelle == 1)` par `#expect(NomsMaison.versionActuelle == 2)` ;
- dans `fichierNomsJSON`, remplacer `futur.version = 2` par `futur.version = NomsMaison.versionActuelle + 1` et `versionTropRecente(2)` par `versionTropRecente(NomsMaison.versionActuelle + 1)` ;
- ajouter :

```swift
    /// Version 2 : l'identifiant HomeKit de chaque accessoire, que vise « Identifier ». Un releve de version 1 (sans
    /// `id`) se lit toujours ; `enVersion1` rend le format qu'attendent les anciennes apps (sans `id`).
    @Test func contratIdentifiant() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let id = "8D3C2A10-0000-4000-8000-000000000001"
        let n = NomsMaison(date: date, accessoires: [AccessoireMaison(nom: "Halo", id: id)])
        #expect(n.version == 2)
        #expect(String(decoding: try n.donnees(), as: UTF8.self).contains(#""id" : "\#(id)""#))
        #expect(try NomsMaison.lire(try n.donnees()) == n)
        let ancien = #"{"accessoires":[{"nom":"Halo"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        #expect(try NomsMaison.lire(Data(ancien.utf8)).accessoires.first?.id == nil)
        let v1 = n.enVersion1()
        #expect(v1.version == 1)
        #expect(v1.accessoires == [AccessoireMaison(nom: "Halo")])
        #expect(!String(decoding: try v1.donnees(), as: UTF8.self).contains(#""id""#))
        #expect(v1.date == n.date && v1.statut == n.statut)
    }
```

- [x] **Step 2 : lancer les tests, vérifier qu'ils échouent**

Run : `outils/tester.sh MaillageCoeurTests/NomsTests`
Expected : échec de compilation (`id` inconnu).

- [x] **Step 3 : écrire le code**

Dans `NomsMaison.swift` :
- dans `AccessoireMaison`, après `batterie`, ajouter

```swift
    /// `HMAccessory.uniqueIdentifier` en texte (UUID) : ce que vise « Identifier » (absent des releves de version 1).
    public var id: String?
```

  et le paramètre `id: String? = nil` à la fin de l'initialiseur (`self.id = id`) ;
- `NomsMaison.versionActuelle` devient `2`, avec le commentaire `/// 2 : l'identifiant des accessoires (demon Passeur Noms, 12/10/2026). Les zones, champ facultatif, ne l'ont pas changee.` ;
- dans `NomsMaison`, après `donnees()`, ajouter

```swift
    /// Le releve au format de la version 1, sans les `id` : une ancienne app qui demande un releve ponctuel (Maillage
    /// Thread 1.2, Maillage Zigbee 1.1) refuse une version plus recente que la sienne.
    public func enVersion1() -> NomsMaison {
        var n = self
        n.version = 1
        n.accessoires = accessoires.map { a in
            var a = a
            a.id = nil
            return a
        }
        return n
    }
```

- [x] **Step 4 : lancer les tests, vérifier qu'ils passent**

Run : `outils/tester.sh MaillageCoeurTests MaillageThreadTests`
Expected : PASS (les autres usages de `AccessoireMaison(…)` n'utilisent pas `id`).

- [x] **Step 5 : commit**

```bash
git add MaillageCoeur/Noms/NomsMaison.swift MaillageCoeurTests/NomsTests.swift
git commit -m "Releve de Maison version 2 : identifiant des accessoires, format 1 pour les anciennes apps

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 : cible de tests du démon, façades, profil, ouverture de session

**Files:**
- Modify: `project.yml` (cible `PasseurTests`, schéma `MaillageThread`)
- Create: `Passeur/Logique/Dependances.swift`, `Passeur/Logique/Journal.swift`, `Passeur/Logique/ProfilPasseur.swift`, `Passeur/Logique/OuvertureSMAppService.swift`
- Create: `PasseurTests/ProfilPasseurTests.swift`, `PasseurTests/OuvertureSessionDemonTests.swift`

**Interfaces:**
- Consumes : `EtatPasseur`, `ReponseIdentifier`, `MessagePasseur`, `EnvoiPasseur` (tâches 1-2), `NomsMaison` (tâche 3).
- Produces :
  - `@MainActor protocol SourceMaison: AnyObject { var acces: EtatPasseur.Acces { get }; var surChangement: (@MainActor () -> Void)? { get set }; func releve(batteries: Bool) async -> NomsMaison?; func identifier(_ accessoire: UUID) async -> IssueIdentifier }`
  - `enum IssueIdentifier: Equatable, Sendable { case ok, inconnu, nonIdentifiable, erreur(String) }` avec `func reponse(_ demande: Int) -> ReponseIdentifier`
  - `@MainActor protocol LienApp: AnyObject { var surMessage: (@MainActor (MessagePasseur) -> Void)? { get set }; var surFin: (@MainActor () -> Void)? { get set }; func envoyer(_ m: MessagePasseur); func fermer() }`
  - `@MainActor protocol OuvertureSessionDemon: AnyObject { var statut: EtatPasseur.Ouverture { get }; func regler(actif: Bool) -> String? }`
  - `@MainActor protocol Annulable: AnyObject { func annuler() }`, `@MainActor protocol Horloge: AnyObject { func apres(_ delai: Duration, _ action: @escaping @MainActor () async -> Void) -> any Annulable }`, `final class HorlogeReelle: Horloge`
  - `@MainActor final class UneFois` (`init(_:)`, `appeler()`)
  - `let journal: Logger`
  - `enum ProfilPasseur { static func fichier(paquet: URL) -> URL; static func expiration(_ donnees: Data) -> Date?; static func expiration(paquet: URL) -> Date? }`
  - `extension EtatPasseur.Ouverture { init(_ s: SMAppService.Status) }`, `final class OuvertureSMAppService: OuvertureSessionDemon`

- [x] **Step 1 : déclarer la cible de tests**

Dans `project.yml`, sous `targets:`, après `MaillageThreadTests`, ajouter :

```yaml
  # Le coeur du demon Passeur Noms (Passeur/Logique), sans HomeKit ni UIKit, teste sur macOS. Il compile les fichiers
  # communs lui-meme, comme la cible Passeur : pas de dependance a MaillageCoeur (les types seraient en double).
  PasseurTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: PasseurTests
      - path: Passeur/Logique
      - path: MaillageCoeur/Noms/NomsMaison.swift
      - path: MaillageCoeur/Noms/ProtocolePasseur.swift
      - path: MaillageCoeur/Annonces/CodageJSON.swift
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: fr.djoko.maillage.passeur.tests
        GENERATE_INFOPLIST_FILE: YES
```

et dans le schéma `MaillageThread` : `PasseurTests: [test]` sous `build: targets:`, et `- PasseurTests` sous `test: targets:`.

- [x] **Step 2 : écrire les tests qui échouent**

`PasseurTests/ProfilPasseurTests.swift` :

```swift
import Foundation
import Testing

/// Date d'expiration lue dans le profil embarque : la liste de proprietes en clair dans le message CMS.
@Suite("Profil du passeur")
struct ProfilPasseurTests {
    static let expiration = Date(timeIntervalSince1970: 1_823_000_000)

    /// Un faux profil : des octets, la liste XML, des octets.
    static func profil(_ liste: [String: Any]) throws -> Data {
        let xml = try PropertyListSerialization.data(fromPropertyList: liste, format: .xml, options: 0)
        return Data([0x30, 0x82, 0x01, 0x02, 0x06]) + xml + Data([0xA0, 0x82, 0x00])
    }

    @Test func dateLue() throws {
        let d = try Self.profil(["Name": "passeur", "ExpirationDate": Self.expiration])
        #expect(ProfilPasseur.expiration(d) == Self.expiration)
    }

    @Test func illisible() throws {
        #expect(ProfilPasseur.expiration(Data()) == nil)
        #expect(ProfilPasseur.expiration(try Self.profil(["Name": "passeur"])) == nil, "sans date")
        #expect(ProfilPasseur.expiration(try Self.profil(["ExpirationDate": "demain"])) == nil, "pas une date")
        let tronque = try Self.profil(["ExpirationDate": Self.expiration]).prefix(40)
        #expect(ProfilPasseur.expiration(Data(tronque)) == nil, "sans fin de liste")
    }

    @Test func emplacement() {
        let paquet = URL(fileURLWithPath: "/Applications/Passeur Noms.app")
        #expect(ProfilPasseur.fichier(paquet: paquet).path == "/Applications/Passeur Noms.app/Contents/embedded.provisionprofile")
        #expect(ProfilPasseur.expiration(paquet: URL(fileURLWithPath: "/nulle/part.app")) == nil)
    }
}
```

`PasseurTests/OuvertureSessionDemonTests.swift` :

```swift
import ServiceManagement
import Testing

/// Correspondance des etats de SMAppService (spec, section 2.3). Aucun test n'appelle SMAppService.
@Suite("Ouverture a la session du demon")
struct OuvertureSessionDemonTests {
    @Test func correspondance() {
        #expect(EtatPasseur.Ouverture(.enabled) == .active)
        #expect(EtatPasseur.Ouverture(.notRegistered) == .inactive)
        #expect(EtatPasseur.Ouverture(.requiresApproval) == .aApprouver)
        #expect(EtatPasseur.Ouverture(.notFound) == .indisponible)
    }

    @Test func reponsesDIdentification() {
        #expect(IssueIdentifier.ok.reponse(3) == ReponseIdentifier(demande: 3, ok: true))
        #expect(IssueIdentifier.inconnu.reponse(4) == ReponseIdentifier(demande: 4, ok: false, erreur: ReponseIdentifier.inconnu))
        #expect(IssueIdentifier.nonIdentifiable.reponse(5)
                == ReponseIdentifier(demande: 5, ok: false, erreur: ReponseIdentifier.nonIdentifiable))
        #expect(IssueIdentifier.erreur("hors de portée").reponse(6)
                == ReponseIdentifier(demande: 6, ok: false, erreur: "hors de portée"))
    }
}
```

- [x] **Step 3 : lancer les tests, vérifier qu'ils échouent**

Run : `outils/tester.sh PasseurTests`
Expected : échec de compilation (`ProfilPasseur`, `IssueIdentifier` inconnus).

- [x] **Step 4 : écrire le code**

`Passeur/Logique/Journal.swift` :

```swift
import os

/// Journal du demon, a lire avec
/// `/usr/bin/log show --last 1h --predicate 'subsystem == "fr.djoko.maillage.passeur"'` (en zsh, `log` seul est une
/// commande interne). Jamais un nom de Maison, ni un UUID d'accessoire, ni le jeton : des raisons, des nombres et des
/// erreurs. `privacy: .public` pour les textes, sinon le journal les masque.
let journal = Logger(subsystem: "fr.djoko.maillage.passeur", category: "demon")
```

`Passeur/Logique/Dependances.swift` :

```swift
import Foundation

/// Ce que le demon sait de Maison : HomeKit dans l'app (`MaisonHomeKit`), une fausse maison dans les tests.
@MainActor
protocol SourceMaison: AnyObject {
    /// Acces a Maison.
    var acces: EtatPasseur.Acces { get }
    /// Appele a chaque changement : autorisation, maisons, accessoires, noms, pieces, zones, services.
    var surChangement: (@MainActor () -> Void)? { get set }
    /// Le releve de Maison ; `batteries` : relit d'abord les batteries (au plus quelques secondes), sinon leurs
    /// dernieres valeurs connues. nil tant que Maison n'a ni donne ses domiciles ni refuse l'acces.
    func releve(batteries: Bool) async -> NomsMaison?
    /// `identify()` sur l'accessoire de cet identifiant (`HMAccessory.uniqueIdentifier`).
    func identifier(_ accessoire: UUID) async -> IssueIdentifier
}

/// Issue d'une identification, avant d'etre mise dans `ReponseIdentifier`.
enum IssueIdentifier: Equatable, Sendable {
    case ok
    case inconnu
    case nonIdentifiable
    /// Le texte de l'erreur de HomeKit.
    case erreur(String)

    func reponse(_ demande: Int) -> ReponseIdentifier {
        switch self {
        case .ok: ReponseIdentifier(demande: demande, ok: true)
        case .inconnu: ReponseIdentifier(demande: demande, ok: false, erreur: ReponseIdentifier.inconnu)
        case .nonIdentifiable: ReponseIdentifier(demande: demande, ok: false, erreur: ReponseIdentifier.nonIdentifiable)
        case .erreur(let texte): ReponseIdentifier(demande: demande, ok: false, erreur: texte)
        }
    }
}

/// Une connexion d'abonnement vers une app (`ConnexionApp` ; un faux dans les tests). Le jeton part a sa creation.
@MainActor
protocol LienApp: AnyObject {
    /// Message recu de l'app.
    var surMessage: (@MainActor (MessagePasseur) -> Void)? { get set }
    /// Connexion finie (fermee par l'app, coupee, trame mal formee, ou `fermer()`) : une seule fois.
    var surFin: (@MainActor () -> Void)? { get set }
    func envoyer(_ m: MessagePasseur)
    func fermer()
}

/// L'ouverture a la session du demon (`SMAppService.mainApp` dans l'app, `OuvertureSMAppService` ; une fausse dans
/// les tests).
@MainActor
protocol OuvertureSessionDemon: AnyObject {
    var statut: EtatPasseur.Ouverture { get }
    /// Inscrit ou desinscrit le demon ; nil si c'est fait, sinon le texte de l'erreur.
    func regler(actif: Bool) -> String?
}

/// Une action planifiee, annulable.
@MainActor
protocol Annulable: AnyObject {
    func annuler()
}

/// Planifie une action apres un delai : `Task.sleep` dans l'app (`HorlogeReelle`), une horloge avancee a la main dans
/// les tests.
@MainActor
protocol Horloge: AnyObject {
    func apres(_ delai: Duration, _ action: @escaping @MainActor () async -> Void) -> any Annulable
}

@MainActor
final class HorlogeReelle: Horloge {
    private final class Tache: Annulable {
        var tache: Task<Void, Never>?

        func annuler() {
            tache?.cancel()
        }
    }

    func apres(_ delai: Duration, _ action: @escaping @MainActor () async -> Void) -> any Annulable {
        let t = Tache()
        t.tache = Task { @MainActor in
            try? await Task.sleep(for: delai)
            guard !Task.isCancelled else { return }
            await action()
        }
        return t
    }
}

/// Une action appelee une seule fois, au premier `appeler()`.
@MainActor
final class UneFois {
    private var action: (@MainActor () -> Void)?

    init(_ action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    func appeler() {
        let a = action
        action = nil
        a?()
    }
}
```

`Passeur/Logique/ProfilPasseur.swift` :

```swift
import Foundation

/// Le profil de developpement du demon (`embedded.provisionprofile` de son paquet) : un message CMS signe, dont le
/// contenu est une liste de proprietes XML en clair. Sa date d'expiration (`ExpirationDate`) y est lue sans verifier
/// la signature (macOS l'a verifiee au lancement), pour que les apps previennent 30 jours avant (spec, section 3.6).
enum ProfilPasseur {
    /// Le profil dans le paquet d'une app Mac.
    static func fichier(paquet: URL) -> URL {
        paquet.appendingPathComponent("Contents/embedded.provisionprofile")
    }

    /// La date d'expiration ; nil si le profil est illisible.
    static func expiration(_ donnees: Data) -> Date? {
        guard let debut = donnees.range(of: Data("<?xml".utf8)),
              let fin = donnees.range(of: Data("</plist>".utf8), in: debut.lowerBound..<donnees.endIndex) else { return nil }
        let xml = Data(donnees[debut.lowerBound..<fin.upperBound])
        let liste = (try? PropertyListSerialization.propertyList(from: xml, format: nil)) as? [String: Any]
        return liste?["ExpirationDate"] as? Date
    }

    static func expiration(paquet: URL) -> Date? {
        (try? Data(contentsOf: fichier(paquet: paquet))).flatMap(expiration)
    }
}
```

`Passeur/Logique/OuvertureSMAppService.swift` :

```swift
import ServiceManagement

extension EtatPasseur.Ouverture {
    init(_ s: SMAppService.Status) {
        switch s {
        case .enabled: self = .active
        case .notRegistered: self = .inactive
        case .requiresApproval: self = .aApprouver
        case .notFound: self = .indisponible
        @unknown default: self = .indisponible
        }
    }
}

/// L'ouverture a la session du demon lui-meme (`SMAppService.mainApp`, disponible sous Mac Catalyst). A la premiere
/// inscription, macOS montre « Element d'arriere-plan ajoute ». Jamais appelee par les tests.
@MainActor
final class OuvertureSMAppService: OuvertureSessionDemon {
    var statut: EtatPasseur.Ouverture {
        EtatPasseur.Ouverture(SMAppService.mainApp.status)
    }

    func regler(actif: Bool) -> String? {
        do {
            if actif {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
```

- [x] **Step 5 : lancer les tests, vérifier qu'ils passent**

Run : `outils/tester.sh PasseurTests`
Expected : PASS (5 tests). Puis `outils/tester.sh` : tout vert.

- [x] **Step 6 : commit**

```bash
git add project.yml Passeur/Logique PasseurTests
git commit -m "Demon : cible de tests, facades, profil embarque et ouverture de session

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 : cœur du démon, abonnement et relevés

**Files:**
- Create: `Passeur/Logique/DemonPasseur.swift`
- Create: `PasseurTests/Imitations.swift`, `PasseurTests/DemonPasseurTests.swift`

**Interfaces:**
- Consumes : façades de la tâche 4, `NomsMaison`, `CodageJSON`, `EnvoiPasseur.Cible`.
- Produces : `@MainActor final class DemonPasseur` avec
  - `init(source: any SourceMaison, ouverture: any OuvertureSessionDemon, horloge: any Horloge, version: String, profilExpire: Date?, connecter: @escaping @MainActor (EnvoiPasseur.Cible) -> any LienApp, livrerPonctuel: @escaping @MainActor (EnvoiPasseur.Cible, Data, @escaping @MainActor () -> Void) -> Void, quitter: @escaping @MainActor (String) -> Void)`
  - `func demarrer()`, `func recevoir(url: URL) async`, `func recevoir(_ m: MessagePasseur, de lien: any LienApp) async`, `var etat: EtatPasseur`, `private(set) var abonnes`
  - constantes `regroupement` (2 s), `periodeBatteries` (1 h), `inactivite` (10 min), `attenteMaison` (100 s)
  - `static func ordonner(_ a: [AccessoireMaison]) -> [AccessoireMaison]` (nom, puis `id`), utilisé aussi par `MaisonHomeKit`.
- Cette tâche écrit le fichier entier ; la tâche 6 ajoute ses tests (identifier, ouverture, durée de vie, ponctuel), qui passent sans changer le code si celui-ci est recopié tel quel.

- [x] **Step 1 : écrire les imitations des tests**

`PasseurTests/Imitations.swift` :

```swift
import Foundation
import Testing

/// Fausse maison : un releve donne a la main, les lectures et identifications notees.
@MainActor
final class FausseMaison: SourceMaison {
    var acces: EtatPasseur.Acces = .autorise
    var surChangement: (@MainActor () -> Void)?
    /// Ce que rend `releve(batteries:)` ; nil : Maison n'a pas encore repondu.
    var noms: NomsMaison?
    /// Chaque appel de `releve`, avec son `batteries`.
    private(set) var lectures: [Bool] = []
    var issues: [UUID: IssueIdentifier] = [:]
    private(set) var identifies: [UUID] = []

    func releve(batteries: Bool) async -> NomsMaison? {
        lectures.append(batteries)
        return noms
    }

    func identifier(_ accessoire: UUID) async -> IssueIdentifier {
        identifies.append(accessoire)
        return issues[accessoire] ?? .inconnu
    }

    /// Un changement dans Maison.
    func changer() {
        surChangement?()
    }
}

/// Faux lien vers une app : les messages envoyes, notes.
@MainActor
final class FauxLien: LienApp {
    var surMessage: (@MainActor (MessagePasseur) -> Void)?
    var surFin: (@MainActor () -> Void)?
    let cible: EnvoiPasseur.Cible
    private(set) var envoyes: [MessagePasseur] = []
    private(set) var ferme = false

    init(_ cible: EnvoiPasseur.Cible) {
        self.cible = cible
    }

    func envoyer(_ m: MessagePasseur) {
        envoyes.append(m)
    }

    func fermer() {
        ferme = true
        let f = surFin
        surFin = nil
        f?()
    }

    /// L'app s'en va : la connexion se ferme de son cote.
    func partir() {
        let f = surFin
        surFin = nil
        f?()
    }

    var releves: [NomsMaison] {
        envoyes.compactMap { m in
            guard case .releve(let json) = m else { return nil }
            return try? NomsMaison.lire(json)
        }
    }

    var etats: [EtatPasseur] {
        envoyes.compactMap { m in
            guard case .etat(let e) = m else { return nil }
            return e
        }
    }

    var reponses: [ReponseIdentifier] {
        envoyes.compactMap { m in
            guard case .identifie(let r) = m else { return nil }
            return r
        }
    }
}

/// Fausse ouverture a la session : le statut se regle a la main ; `erreur` fait echouer `regler`.
@MainActor
final class FausseOuverture: OuvertureSessionDemon {
    var statut: EtatPasseur.Ouverture = .inactive
    var erreur: String?
    private(set) var reglages: [Bool] = []

    func regler(actif: Bool) -> String? {
        reglages.append(actif)
        if let erreur { return erreur }
        statut = actif ? .active : .inactive
        return nil
    }
}

/// Horloge avancee a la main : les actions echues s'executent dans l'ordre de leur echeance, y compris celles qu'elles
/// planifient dans l'intervalle.
@MainActor
final class FausseHorloge: Horloge {
    final class Tache: Annulable {
        let echeance: Duration
        let action: @MainActor () async -> Void
        var annulee = false

        init(echeance: Duration, action: @escaping @MainActor () async -> Void) {
            self.echeance = echeance
            self.action = action
        }

        func annuler() {
            annulee = true
        }
    }

    private(set) var maintenant: Duration = .zero
    private var taches: [Tache] = []

    func apres(_ delai: Duration, _ action: @escaping @MainActor () async -> Void) -> any Annulable {
        let t = Tache(echeance: maintenant + delai, action: action)
        taches.append(t)
        return t
    }

    func avancer(_ d: Duration) async {
        let fin = maintenant + d
        while let t = taches.filter({ !$0.annulee && $0.echeance <= fin }).min(by: { $0.echeance < $1.echeance }) {
            taches.removeAll { $0 === t }
            maintenant = t.echeance
            await t.action()
        }
        maintenant = fin
    }
}

/// Un demon et ses imitations.
@MainActor
final class BancDemon {
    static let jeton = String(repeating: "ab", count: 32)

    let maison = FausseMaison()
    let ouverture = FausseOuverture()
    let horloge = FausseHorloge()
    private(set) var liens: [FauxLien] = []
    private(set) var ponctuels: [(cible: EnvoiPasseur.Cible, json: Data)] = []
    private var finsPonctuelles: [@MainActor () -> Void] = []
    private(set) var sorties: [String] = []
    private(set) var demon: DemonPasseur!

    init(statut: EtatPasseur.Ouverture = .inactive, noms: NomsMaison? = nil, profilExpire: Date? = nil) {
        ouverture.statut = statut
        maison.noms = noms
        demon = DemonPasseur(
            source: maison, ouverture: ouverture, horloge: horloge, version: "2.0", profilExpire: profilExpire,
            connecter: { [unowned self] cible in
                let l = FauxLien(cible)
                self.liens.append(l)
                return l
            },
            livrerPonctuel: { [unowned self] cible, json, fini in
                self.ponctuels.append((cible, json))
                self.finsPonctuelles.append(fini)
            },
            quitter: { [unowned self] raison in self.sorties.append(raison) })
        demon.demarrer()
    }

    /// Les apps ont lu leurs releves ponctuels et ferme la connexion.
    func finirPonctuels() {
        let f = finsPonctuelles
        finsPonctuelles = []
        f.forEach { $0() }
    }

    static func url(_ d: EnvoiPasseur.Demande, port: UInt16 = 50_000) -> URL {
        EnvoiPasseur.Cible(port: port, jeton: jeton, demande: d).url
    }

    /// Un abonne de plus ; rend son lien.
    func abonner(port: UInt16 = 50_000) async -> FauxLien? {
        await demon.recevoir(url: Self.url(.abonner, port: port))
        return liens.last
    }

    static func noms(_ nom: String = "Halo", date: Date = Date(timeIntervalSince1970: 1_790_000_000)) -> NomsMaison {
        NomsMaison(date: date, accessoires: [AccessoireMaison(nom: nom, id: "8D3C2A10-0000-4000-8000-000000000001")])
    }
}
```

- [x] **Step 2 : écrire les tests qui échouent**

`PasseurTests/DemonPasseurTests.swift` :

```swift
import Foundation
import Testing

@MainActor
@Suite("Demon Passeur Noms : abonnement et releves")
struct DemonPasseurTests {
    static let etatDeBase = EtatPasseur(version: "2.0", acces: .autorise, ouvertureSession: .inactive, profilExpire: nil)

    /// A la connexion : `etat`, puis le releve (batteries lues, premier releve du demon).
    @Test func abonnementEnvoieEtatPuisReleve() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        #expect(l.etats == [Self.etatDeBase])
        #expect(l.releves == [BancDemon.noms()])
        #expect(l.envoyes.first == .etat(Self.etatDeBase), "etat d'abord")
        #expect(b.maison.lectures == [true])
        #expect(b.demon.abonnes.count == 1)
    }

    /// L'expiration du profil voyage dans `etat`.
    @Test func profilDansLEtat() async throws {
        let fin = Date(timeIntervalSince1970: 1_823_000_000)
        let b = BancDemon(noms: BancDemon.noms(), profilExpire: fin)
        let l = try #require(await b.abonner())
        #expect(l.etats.first?.profilExpire == fin)
    }

    /// Un abonne arrive apres un releve : il recoit le dernier, sans nouvelle lecture.
    @Test func secondAbonneRecoitLeDernier() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        _ = await b.abonner(port: 50_000)
        let second = try #require(await b.abonner(port: 50_001))
        #expect(second.releves == [BancDemon.noms()])
        #expect(b.maison.lectures == [true])
    }

    /// Maison pas encore prete : `etat` seulement ; le releve part 2 s apres le changement qui l'annonce.
    @Test func releveAuChangement() async throws {
        let b = BancDemon()
        let l = try #require(await b.abonner())
        #expect(l.releves.isEmpty)
        b.maison.noms = BancDemon.noms()
        b.maison.changer()
        await b.horloge.avancer(.milliseconds(1999))
        #expect(l.releves.isEmpty, "pas avant 2 s")
        await b.horloge.avancer(.milliseconds(1))
        #expect(l.releves == [BancDemon.noms()])
    }

    /// Des changements groupes : un seul releve, 2 s apres le dernier.
    @Test func regroupement() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        b.maison.noms = BancDemon.noms("Halo 2")
        b.maison.changer()
        await b.horloge.avancer(.seconds(1))
        b.maison.changer()
        await b.horloge.avancer(.milliseconds(1500))
        b.maison.changer()
        await b.horloge.avancer(.milliseconds(1999))
        #expect(l.releves.count == 1, "toujours le seul releve de la connexion")
        await b.horloge.avancer(.milliseconds(1))
        #expect(l.releves.map { $0.accessoires.first?.nom } == ["Halo", "Halo 2"])
    }

    /// Releve identique au dernier envoye, date mise a part : rien ne part.
    @Test func identiqueNonRenvoye() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        b.maison.noms = BancDemon.noms(date: Date(timeIntervalSince1970: 1_790_003_600))
        b.maison.changer()
        await b.horloge.avancer(.seconds(2))
        #expect(l.releves.count == 1)
        #expect(b.maison.lectures == [true, false], "changement : batteries pas relues")
    }

    /// Deux accessoires de meme nom, dans un ordre ou l'autre : le meme releve, rien ne part.
    @Test func ordreStableDesHomonymes() async throws {
        let a = AccessoireMaison(nom: "Capteur", id: "8D3C2A10-0000-4000-8000-00000000000A")
        let z = AccessoireMaison(nom: "Capteur", id: "8D3C2A10-0000-4000-8000-00000000000B")
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let b = BancDemon(noms: NomsMaison(date: date, accessoires: [a, z]))
        let l = try #require(await b.abonner())
        b.maison.noms = NomsMaison(date: date, accessoires: [z, a])
        b.maison.changer()
        await b.horloge.avancer(.seconds(2))
        #expect(l.releves.count == 1)
        #expect(DemonPasseur.ordonner([z, a]) == [a, z])
    }

    /// `relire` : releve immediat, batteries relues ; envoye au demandeur meme identique, aux autres seulement s'il a
    /// change.
    @Test func relire() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let demandeur = try #require(await b.abonner(port: 50_000))
        let autre = try #require(await b.abonner(port: 50_001))
        await b.demon.recevoir(.relire, de: demandeur)
        #expect(demandeur.releves.count == 2)
        #expect(autre.releves.count == 1)
        #expect(b.maison.lectures.last == true)
        b.maison.noms = BancDemon.noms("Halo 2")
        await b.demon.recevoir(.relire, de: demandeur)
        #expect(demandeur.releves.count == 3)
        #expect(autre.releves.count == 2)
    }

    /// Un message de l'app passe par `surMessage` du lien.
    @Test func messageParLeLien() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        l.surMessage?(.relire)
        let fin = ContinuousClock.now + .seconds(5)
        while l.releves.count < 2, ContinuousClock.now < fin { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(l.releves.count == 2)
    }

    /// Toutes les heures : batteries relues, releve envoye s'il a change.
    @Test func batteriesToutesLesHeures() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        var n = BancDemon.noms()
        n.accessoires[0].batterie = BatterieMaison(niveau: 40)
        b.maison.noms = n
        await b.horloge.avancer(.seconds(3600))
        #expect(b.maison.lectures == [true, true])
        #expect(l.releves.last?.accessoires.first?.batterie?.niveau == 40)
        await b.horloge.avancer(.seconds(3600))
        #expect(b.maison.lectures == [true, true, true])
    }

    /// L'acces change : `etat` part tout de suite, sans attendre le regroupement.
    @Test func accesChangeEtat() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        b.maison.acces = .refuse
        b.maison.changer()
        #expect(l.etats.last?.acces == .refuse)
        #expect(l.etats.count == 2)
    }

    /// Une URL qui n'est pas celle du passeur : rien.
    @Test func urlIllisible() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        await b.demon.recevoir(url: try #require(URL(string: "maillage-passeur://autre?port=1&jeton=\(BancDemon.jeton)")))
        #expect(b.liens.isEmpty && b.ponctuels.isEmpty)
    }
}
```

- [x] **Step 3 : lancer les tests, vérifier qu'ils échouent**

Run : `outils/tester.sh PasseurTests`
Expected : échec de compilation (`DemonPasseur` inconnu).

- [x] **Step 4 : écrire le code**

`Passeur/Logique/DemonPasseur.swift` :

```swift
import Foundation

/// Le coeur du demon Passeur Noms, sans HomeKit ni reseau (spec du 12/10, sections 2 et 3) : les abonnes (URL
/// `abonner`), les releves ponctuels (URL `releve`), le suivi de Maison avec regroupement de 2 s, les batteries toutes
/// les heures, « Identifier », l'ouverture a la session et la duree de vie. Tout ce qui touche au systeme est donne a
/// l'initialisation : HomeKit (`SourceMaison`), les connexions (`connecter`, `livrerPonctuel`), SMAppService
/// (`OuvertureSessionDemon`), le temps (`Horloge`) et la sortie (`quitter`).
@MainActor
final class DemonPasseur {
    /// Attente apres un changement dans Maison, le temps que les modifications groupees se terminent.
    static let regroupement: Duration = .seconds(2)
    /// Relecture des batteries : pas d'abonnement aux caracteristiques, pour ne pas solliciter les appareils.
    static let periodeBatteries: Duration = .seconds(3600)
    /// Fermeture apres le depart du dernier abonne (ou apres le lancement, si personne ne s'abonne), hors ouverture a
    /// la session.
    static let inactivite: Duration = .seconds(600)
    /// Attente de Maison pour un releve ponctuel ; au-dela, un releve en erreur part, comme l'ancien passeur.
    static let attenteMaison: Duration = .seconds(100)

    private let source: any SourceMaison
    private let ouverture: any OuvertureSessionDemon
    private let horloge: any Horloge
    private let version: String
    private let profilExpire: Date?
    private let connecter: @MainActor (EnvoiPasseur.Cible) -> any LienApp
    private let livrerPonctuel: @MainActor (EnvoiPasseur.Cible, Data, @escaping @MainActor () -> Void) -> Void
    private let quitter: @MainActor (String) -> Void

    /// Les abonnes connectes, ou en cours de connexion.
    private(set) var abonnes: [ObjectIdentifier: any LienApp] = [:]
    /// Releves ponctuels en cours : en attente de Maison ou en cours d'envoi.
    private var ponctuels = 0
    /// Releves ponctuels qui attendent Maison.
    private var enAttente: [EnvoiPasseur.Cible] = []
    /// Le dernier releve lu dans Maison.
    private var dernierReleve: NomsMaison?
    /// Le dernier releve envoye aux abonnes, sous sa forme comparable (`comparable`).
    private var dernierEnvoye: NomsMaison?
    private var dernierEtat: EtatPasseur?
    private var regroupe: (any Annulable)?
    private var fermeture: (any Annulable)?
    private var batteries: (any Annulable)?
    private var attente: (any Annulable)?

    init(source: any SourceMaison, ouverture: any OuvertureSessionDemon, horloge: any Horloge, version: String,
         profilExpire: Date?, connecter: @escaping @MainActor (EnvoiPasseur.Cible) -> any LienApp,
         livrerPonctuel: @escaping @MainActor (EnvoiPasseur.Cible, Data, @escaping @MainActor () -> Void) -> Void,
         quitter: @escaping @MainActor (String) -> Void) {
        self.source = source
        self.ouverture = ouverture
        self.horloge = horloge
        self.version = version
        self.profilExpire = profilExpire
        self.connecter = connecter
        self.livrerPonctuel = livrerPonctuel
        self.quitter = quitter
    }

    /// Au lancement : suivre Maison, planifier les batteries, et la fermeture si personne ne s'abonne.
    func demarrer() {
        source.surChangement = { [weak self] in self?.changement() }
        planifierBatteries()
        verifierDuree()
        journal.notice("lancement, version \(self.version, privacy: .public)")
    }

    var etat: EtatPasseur {
        EtatPasseur(version: version, acces: source.acces, ouvertureSession: ouverture.statut, profilExpire: profilExpire)
    }

    /// URL recue (au lancement ou demon deja ouvert). Jamais l'URL au journal : elle porte le jeton.
    func recevoir(url: URL) async {
        guard let cible = EnvoiPasseur.Cible(url: url) else {
            journal.error("URL illisible, ignorée")
            return
        }
        switch cible.demande {
        case .abonner: await abonner(cible)
        case .releve: await releverPonctuel(cible)
        }
    }

    /// Message d'un abonne.
    func recevoir(_ m: MessagePasseur, de lien: any LienApp) async {
        switch m {
        case .relire:
            await actualiser(batteries: true, demandeur: lien)
        case .identifier(let demande, let accessoire):
            var issue = IssueIdentifier.inconnu
            if let uuid = UUID(uuidString: accessoire) {
                issue = await source.identifier(uuid)
            }
            journal.notice("identification : \(Self.texte(issue), privacy: .public)")
            lien.envoyer(.identifie(issue.reponse(demande)))
        case .ouvertureSession(let actif):
            if let erreur = ouverture.regler(actif: actif) {
                journal.error("ouverture de session (\(actif ? "inscription" : "désinscription", privacy: .public)) : \(erreur, privacy: .public)")
            } else {
                journal.notice("ouverture de session : \(actif ? "inscrit" : "désinscrit", privacy: .public)")
            }
            // Toujours : l'interrupteur de l'app revient a l'etat reel si l'inscription a echoue.
            diffuserEtat(toujours: true)
            verifierDuree()
        case .etat, .releve, .identifie:
            // Messages du passeur vers l'app : ignores dans l'autre sens.
            break
        }
    }

    /// Ordre stable des accessoires : par nom, puis par identifiant (deux accessoires peuvent porter le meme nom).
    static func ordonner(_ a: [AccessoireMaison]) -> [AccessoireMaison] {
        a.sorted { ($0.nom, $0.id ?? "") < ($1.nom, $1.id ?? "") }
    }

    // MARK: Abonnes

    private func abonner(_ cible: EnvoiPasseur.Cible) async {
        let lien = connecter(cible)
        let cle = ObjectIdentifier(lien)
        abonnes[cle] = lien
        lien.surMessage = { [weak self, weak lien] m in
            guard let self, let lien else { return }
            Task { await self.recevoir(m, de: lien) }
        }
        lien.surFin = { [weak self] in self?.depart(cle) }
        journal.notice("abonné accepté, port \(cible.port), \(self.abonnes.count) abonné(s)")
        verifierDuree()
        let e = etat
        dernierEtat = e
        lien.envoyer(.etat(e))
        if let n = dernierReleve {
            lien.envoyer(Self.message(n))
        } else {
            await actualiser(batteries: true, demandeur: nil)
        }
    }

    private func depart(_ cle: ObjectIdentifier) {
        guard abonnes.removeValue(forKey: cle) != nil else { return }
        journal.notice("abonné parti, \(self.abonnes.count) restant(s)")
        verifierDuree()
    }

    /// Envoie `etat` a tous les abonnes s'il a change (`toujours` : meme inchange).
    private func diffuserEtat(toujours: Bool = false) {
        let e = etat
        guard toujours || e != dernierEtat else { return }
        dernierEtat = e
        for l in abonnes.values { l.envoyer(.etat(e)) }
    }

    // MARK: Maison

    /// Changement dans Maison : `etat` tout de suite (l'acces a pu changer), le releve 2 s apres le dernier changement.
    private func changement() {
        diffuserEtat()
        regroupe?.annuler()
        regroupe = horloge.apres(Self.regroupement) { [weak self] in
            guard let self else { return }
            self.regroupe = nil
            // Le premier releve du demon lit les batteries ; les suivants gardent leurs valeurs connues.
            await self.actualiser(batteries: self.dernierReleve == nil, demandeur: nil)
        }
    }

    /// Refait le releve ; l'envoie a tous les abonnes s'il differe du dernier envoye (date et ordre mis a part), et au
    /// `demandeur` dans tous les cas. Sert aussi les releves ponctuels qui attendaient Maison.
    private func actualiser(batteries: Bool, demandeur: (any LienApp)?) async {
        guard let n = await source.releve(batteries: batteries) else { return }
        dernierReleve = n
        servirPonctuels(n)
        let m = Self.message(n)
        let c = Self.comparable(n)
        if c != dernierEnvoye {
            dernierEnvoye = c
            for l in abonnes.values { l.envoyer(m) }
            if !abonnes.isEmpty {
                journal.notice("relevé envoyé : \(n.accessoires.count) accessoires, \(self.abonnes.count) abonné(s)")
            }
        } else if let d = demandeur, abonnes[ObjectIdentifier(d)] != nil {
            d.envoyer(m)
        }
    }

    private func planifierBatteries() {
        batteries = horloge.apres(Self.periodeBatteries) { [weak self] in
            guard let self else { return }
            await self.actualiser(batteries: true, demandeur: nil)
            // L'ouverture a la session a pu changer dans les reglages du Mac.
            self.verifierDuree()
            self.planifierBatteries()
        }
    }

    /// Le releve en message `releve` (JSON compact).
    static func message(_ n: NomsMaison) -> MessagePasseur {
        .releve((try? CodageJSON.encodeur().encode(n)) ?? Data("{}".utf8))
    }

    /// Le releve sans sa date, ses accessoires dans un ordre stable : deux releves egaux sous cette forme ne different
    /// que par l'heure ou par l'ordre de HomeKit.
    static func comparable(_ n: NomsMaison) -> NomsMaison {
        var c = n
        c.date = .distantPast
        c.accessoires = ordonner(n.accessoires)
        return c
    }

    // MARK: Releve ponctuel

    private func releverPonctuel(_ cible: EnvoiPasseur.Cible) async {
        journal.notice("relevé ponctuel demandé, port \(cible.port)")
        ponctuels += 1
        verifierDuree()
        if let n = dernierReleve {
            livrer(n, a: cible)
            return
        }
        enAttente.append(cible)
        if attente == nil {
            attente = horloge.apres(Self.attenteMaison) { [weak self] in
                guard let self else { return }
                self.attente = nil
                self.servirPonctuels(NomsMaison(date: .now, statut: .erreur, message: "Maison n'a pas répondu"))
            }
        }
        await actualiser(batteries: true, demandeur: nil)
    }

    private func servirPonctuels(_ n: NomsMaison) {
        guard !enAttente.isEmpty else { return }
        attente?.annuler()
        attente = nil
        let cibles = enAttente
        enAttente = []
        for c in cibles { livrer(n, a: c) }
    }

    /// Envoie le releve au format de la version 1 (les anciennes apps refusent la version 2), puis, s'il ne reste
    /// personne et que le demon n'est pas inscrit a l'ouverture de session, le ferme.
    private func livrer(_ n: NomsMaison, a cible: EnvoiPasseur.Cible) {
        let json = (try? CodageJSON.encodeur().encode(n.enVersion1())) ?? Data("{}".utf8)
        livrerPonctuel(cible, json) { [weak self] in
            guard let self else { return }
            self.ponctuels -= 1
            journal.notice("relevé ponctuel envoyé : \(n.accessoires.count) accessoires")
            if self.abonnes.isEmpty, self.ponctuels == 0, self.ouverture.statut != .active {
                self.quitter("relevé ponctuel envoyé, aucun abonné")
            } else {
                self.verifierDuree()
            }
        }
    }

    // MARK: Duree de vie

    /// Ferme le demon 10 min apres le depart du dernier abonne (ou apres le lancement, si personne ne s'abonne), sauf
    /// s'il est inscrit a l'ouverture de session ou qu'un releve ponctuel est en cours.
    private func verifierDuree() {
        if resterOuvert {
            fermeture?.annuler()
            fermeture = nil
        } else if fermeture == nil {
            fermeture = horloge.apres(Self.inactivite) { [weak self] in
                guard let self else { return }
                self.fermeture = nil
                guard !self.resterOuvert else { return }
                self.quitter("aucun abonné depuis 10 minutes")
            }
        }
    }

    private var resterOuvert: Bool {
        ouverture.statut == .active || !abonnes.isEmpty || ponctuels > 0
    }

    /// Pour le journal : jamais l'identifiant de l'accessoire.
    private static func texte(_ i: IssueIdentifier) -> String {
        switch i {
        case .ok: "faite"
        case .inconnu: "accessoire inconnu"
        case .nonIdentifiable: "accessoire non identifiable"
        case .erreur(let e): "erreur de HomeKit : \(e)"
        }
    }
}
```

- [x] **Step 5 : lancer les tests, vérifier qu'ils passent**

Run : `outils/tester.sh PasseurTests`
Expected : PASS.

- [x] **Step 6 : commit**

```bash
git add Passeur/Logique/DemonPasseur.swift PasseurTests/Imitations.swift PasseurTests/DemonPasseurTests.swift
git commit -m "Demon : abonnes, releves regroupes et envoyes s'ils changent, batteries toutes les heures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6 : cœur du démon, identifier, ouverture de session, durée de vie, relevé ponctuel

**Files:**
- Create: `PasseurTests/DemonPasseurViesTests.swift`
- Modify (seulement si un test échoue) : `Passeur/Logique/DemonPasseur.swift`

**Interfaces:**
- Consumes : `DemonPasseur`, `BancDemon`, imitations (tâche 5).
- Produces : rien de nouveau ; fixe le comportement des sections 3.3 à 3.5 de la spec.

- [x] **Step 1 : écrire les tests**

`PasseurTests/DemonPasseurViesTests.swift` :

```swift
import Foundation
import Testing

@MainActor
@Suite("Demon Passeur Noms : identifier, ouverture, duree de vie, releve ponctuel")
struct DemonPasseurViesTests {
    static let uuid = UUID(uuidString: "8D3C2A10-0000-4000-8000-000000000001")!

    // MARK: Identifier

    @Test func identifier() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        b.maison.issues[Self.uuid] = .ok
        await b.demon.recevoir(.identifier(demande: 1, accessoire: Self.uuid.uuidString), de: l)
        b.maison.issues[Self.uuid] = .nonIdentifiable
        await b.demon.recevoir(.identifier(demande: 2, accessoire: Self.uuid.uuidString), de: l)
        b.maison.issues[Self.uuid] = .erreur("hors de portée")
        await b.demon.recevoir(.identifier(demande: 3, accessoire: Self.uuid.uuidString), de: l)
        await b.demon.recevoir(.identifier(demande: 4, accessoire: UUID().uuidString), de: l)
        #expect(l.reponses == [ReponseIdentifier(demande: 1, ok: true),
                               ReponseIdentifier(demande: 2, ok: false, erreur: ReponseIdentifier.nonIdentifiable),
                               ReponseIdentifier(demande: 3, ok: false, erreur: "hors de portée"),
                               ReponseIdentifier(demande: 4, ok: false, erreur: ReponseIdentifier.inconnu)])
    }

    /// Un identifiant qui n'est pas un UUID : inconnu, sans demander a Maison.
    @Test func identifiantIllisible() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        await b.demon.recevoir(.identifier(demande: 9, accessoire: "pas-un-uuid"), de: l)
        #expect(l.reponses == [ReponseIdentifier(demande: 9, ok: false, erreur: ReponseIdentifier.inconnu)])
        #expect(b.maison.identifies.isEmpty)
    }

    // MARK: Ouverture de session

    /// Inscription : SMAppService appele, `etat` a jour chez tous les abonnes.
    @Test func ouvertureSession() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner(port: 50_000))
        let autre = try #require(await b.abonner(port: 50_001))
        await b.demon.recevoir(.ouvertureSession(actif: true), de: l)
        #expect(b.ouverture.reglages == [true])
        #expect(l.etats.last?.ouvertureSession == .active)
        #expect(autre.etats.last?.ouvertureSession == .active)
    }

    /// Echec de l'inscription : `etat` repart quand meme, avec l'etat reel (l'interrupteur de l'app revient).
    @Test func ouvertureRefusee() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        b.ouverture.erreur = "Operation not permitted"
        await b.demon.recevoir(.ouvertureSession(actif: true), de: l)
        #expect(l.etats.count == 2)
        #expect(l.etats.last?.ouvertureSession == .inactive)
    }

    // MARK: Duree de vie

    @Test func fermeture10MinApresLeDernier() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        await b.horloge.avancer(.seconds(3000))
        #expect(b.sorties.isEmpty, "un abonne : le demon reste")
        l.partir()
        await b.horloge.avancer(.seconds(599))
        #expect(b.sorties.isEmpty)
        await b.horloge.avancer(.seconds(1))
        #expect(b.sorties == ["aucun abonné depuis 10 minutes"])
    }

    @Test func nouvelAbonneAnnuleLaFermeture() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        let l = try #require(await b.abonner(port: 50_000))
        l.partir()
        await b.horloge.avancer(.seconds(300))
        _ = await b.abonner(port: 50_001)
        await b.horloge.avancer(.seconds(3000))
        #expect(b.sorties.isEmpty)
    }

    @Test func sansAbonneAuLancement() async {
        let b = BancDemon(noms: BancDemon.noms())
        await b.horloge.avancer(.seconds(600))
        #expect(b.sorties == ["aucun abonné depuis 10 minutes"])
    }

    @Test func ouvertureActiveNeFermeJamais() async throws {
        let b = BancDemon(statut: .active, noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        l.partir()
        await b.horloge.avancer(.seconds(7200))
        #expect(b.sorties.isEmpty)
    }

    /// Desinscrit par un abonne qui part ensuite : la fermeture reprend.
    @Test func desinscriptionPuisDepart() async throws {
        let b = BancDemon(statut: .active, noms: BancDemon.noms())
        let l = try #require(await b.abonner())
        await b.demon.recevoir(.ouvertureSession(actif: false), de: l)
        l.partir()
        await b.horloge.avancer(.seconds(600))
        #expect(b.sorties.count == 1)
    }

    // MARK: Releve ponctuel

    /// Le releve ponctuel part au format de la version 1, sans `id` ; puis le demon se ferme.
    @Test func ponctuelEnVersion1() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        await b.demon.recevoir(url: BancDemon.url(.releve, port: 50_123))
        let p = try #require(b.ponctuels.first)
        #expect(p.cible.port == 50_123 && p.cible.demande == .releve)
        let n = try NomsMaison.lire(p.json)
        #expect(n.version == 1)
        #expect(n.accessoires.allSatisfy { $0.id == nil })
        #expect(n.accessoires.first?.nom == "Halo")
        #expect(b.sorties.isEmpty, "pas avant la fin de l'envoi")
        b.finirPonctuels()
        #expect(b.sorties == ["relevé ponctuel envoyé, aucun abonné"])
    }

    @Test func ponctuelAvecAbonneNeFermePas() async throws {
        let b = BancDemon(noms: BancDemon.noms())
        _ = await b.abonner()
        await b.demon.recevoir(url: BancDemon.url(.releve))
        b.finirPonctuels()
        #expect(b.sorties.isEmpty)
    }

    @Test func ponctuelOuvertureActiveNeFermePas() async {
        let b = BancDemon(statut: .active, noms: BancDemon.noms())
        await b.demon.recevoir(url: BancDemon.url(.releve))
        b.finirPonctuels()
        #expect(b.sorties.isEmpty)
    }

    /// Maison pas encore prete : le releve part des qu'elle repond.
    @Test func ponctuelAttendMaison() async {
        let b = BancDemon()
        await b.demon.recevoir(url: BancDemon.url(.releve))
        #expect(b.ponctuels.isEmpty)
        b.maison.noms = BancDemon.noms()
        b.maison.changer()
        await b.horloge.avancer(.seconds(2))
        #expect(b.ponctuels.count == 1)
        await b.horloge.avancer(.seconds(600))
        #expect(b.sorties.isEmpty, "pas de fermeture pendant l'envoi")
    }

    /// Maison muette pendant 100 s : un releve en erreur, comme l'ancien passeur.
    @Test func ponctuelMaisonMuette() async throws {
        let b = BancDemon()
        await b.demon.recevoir(url: BancDemon.url(.releve))
        await b.horloge.avancer(.seconds(99))
        #expect(b.ponctuels.isEmpty)
        await b.horloge.avancer(.seconds(1))
        let n = try NomsMaison.lire(try #require(b.ponctuels.first).json)
        #expect(n.statut == .erreur)
        #expect(n.message == "Maison n'a pas répondu")
    }
}
```

- [x] **Step 2 : lancer les tests**

Run : `outils/tester.sh PasseurTests`
Expected : PASS avec le code de la tâche 5 tel quel. Un test qui échoue est un écart avec la spec (sections 3.3 à 3.5) : corriger `DemonPasseur.swift`, pas le test.

- [x] **Step 3 : commit**

```bash
git add PasseurTests/DemonPasseurViesTests.swift Passeur/Logique/DemonPasseur.swift
git commit -m "Demon : tests d'Identifier, de l'ouverture de session, de la duree de vie et du releve ponctuel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7 : connexions réelles du démon (abonnement et relevé ponctuel)

**Files:**
- Create: `Passeur/Logique/ConnexionApp.swift`
- Create: `PasseurTests/ConnexionAppTests.swift`

**Interfaces:**
- Consumes : `LienApp`, `UneFois`, `journal` (tâche 4), `EnvoiPasseur.ligneJeton`, `trame(_:)`, `trame(jeton:json:)`, `LectureTrames`, `MessagePasseur.lire` (tâches 1-2).
- Produces : `@MainActor final class ConnexionApp: LienApp` (`init(cible: EnvoiPasseur.Cible)`) ; `@MainActor enum LivraisonPonctuelle { static let delai: Duration; static func livrer(_ cible: EnvoiPasseur.Cible, json: Data, fini: @escaping @MainActor () -> Void) }`.

- [ ] **Step 1 : écrire les tests qui échouent**

`PasseurTests/ConnexionAppTests.swift` :

```swift
import Foundation
import Network
import Testing

/// Attend qu'une condition soit vraie, au plus `delai` ; rend la condition.
@MainActor
func attendreQue(_ delai: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
    let fin = ContinuousClock.now + delai
    while !condition(), ContinuousClock.now < fin { try? await Task.sleep(for: .milliseconds(5)) }
    return condition()
}

/// Une valeur que modifient les fermetures des tests (`surMessage`, `surFin`, `fini`) : une fermeture isolee a
/// l'acteur principal ne peut pas modifier une variable locale capturee.
@MainActor
final class Boite<Valeur> {
    var valeur: Valeur

    init(_ valeur: Valeur) {
        self.valeur = valeur
    }
}

/// Fausse app : ecoute sur 127.0.0.1, accepte une connexion, lit le jeton puis les trames (`LectureFlux`), et garde
/// tous les octets recus (releve ponctuel).
@MainActor
final class FausseApp {
    let jeton = String(repeating: "c3", count: 32)
    private let ecouteur: NWListener
    private var connexion: NWConnection?
    private var lecture: EnvoiPasseur.LectureFlux
    private(set) var recus: [MessagePasseur] = []
    private(set) var octets = Data()
    private(set) var fermee = false

    init() throws {
        lecture = EnvoiPasseur.LectureFlux(jeton: jeton)
        let p = NWParameters.tcp
        p.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        ecouteur = try NWListener(using: p)
        ecouteur.newConnectionHandler = { [weak self] c in MainActor.assumeIsolated { self?.accepter(c) } }
        ecouteur.start(queue: .main)
    }

    /// Le port, une fois l'ecoute prete.
    func port() async -> UInt16? {
        _ = await attendreQue { ecouteur.port != nil }
        return ecouteur.port?.rawValue
    }

    var jetonAccepte: Bool { lecture.jetonAccepte }

    private func accepter(_ c: NWConnection) {
        connexion = c
        c.start(queue: .main)
        lire(c)
    }

    private func lire(_ c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] d, _, finie, e in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let d, !d.isEmpty {
                    self.octets.append(d)
                    for j in self.lecture.ajouter(d).trames {
                        if case .message(let m) = MessagePasseur.lire(j) { self.recus.append(m) }
                    }
                }
                if finie || e != nil {
                    self.fermee = true
                    return
                }
                self.lire(c)
            }
        }
    }

    func envoyer(_ o: Data) {
        connexion?.send(content: o, completion: .idempotent)
    }

    func fermer() {
        connexion?.cancel()
        ecouteur.cancel()
    }
}

@MainActor
@Suite("Connexions du demon sur la boucle locale", .timeLimit(.minutes(1)))
struct ConnexionAppTests {
    static func cible(_ app: FausseApp, _ d: EnvoiPasseur.Demande = .abonner) async throws -> EnvoiPasseur.Cible {
        EnvoiPasseur.Cible(port: try #require(await app.port()), jeton: app.jeton, demande: d)
    }

    /// Le jeton, puis les messages ; les messages de l'app arrivent par `surMessage`.
    @Test func echange() async throws {
        let app = try FausseApp()
        let lien = ConnexionApp(cible: try await Self.cible(app))
        let recus = Boite<[MessagePasseur]>([])
        lien.surMessage = { recus.valeur.append($0) }
        lien.envoyer(.etat(EtatPasseur(version: "2.0", acces: .autorise, ouvertureSession: .inactive, profilExpire: nil)))
        lien.envoyer(.releve(Data(#"{"version":2}"#.utf8)))
        #expect(await attendreQue { app.recus.count == 2 })
        #expect(app.jetonAccepte)
        app.envoyer(EnvoiPasseur.trame(.relire) + EnvoiPasseur.trame(.ouvertureSession(actif: true)))
        #expect(await attendreQue { recus.valeur.count == 2 })
        #expect(recus.valeur == [.relire, .ouvertureSession(actif: true)])
        lien.fermer()
        app.fermer()
    }

    /// L'app ferme : `surFin`, une seule fois.
    @Test func finQuandLAppFerme() async throws {
        let app = try FausseApp()
        let lien = ConnexionApp(cible: try await Self.cible(app))
        let fins = Boite(0)
        lien.surFin = { fins.valeur += 1 }
        lien.envoyer(.relire)
        #expect(await attendreQue { app.jetonAccepte })
        app.fermer()
        #expect(await attendreQue { fins.valeur == 1 })
        lien.fermer()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(fins.valeur == 1)
    }

    /// Trame mal formee de l'app : la connexion se ferme.
    @Test func trameFausse() async throws {
        let app = try FausseApp()
        let lien = ConnexionApp(cible: try await Self.cible(app))
        let fini = Boite(false)
        lien.surFin = { fini.valeur = true }
        lien.envoyer(.relire)
        #expect(await attendreQue { app.jetonAccepte })
        app.envoyer(Data("x\n".utf8))
        #expect(await attendreQue { fini.valeur })
        #expect(await attendreQue { app.fermee })
        app.fermer()
    }

    /// Personne n'ecoute : `surFin`.
    @Test func personneNEcoute() async throws {
        let app = try FausseApp()
        let cible = try await Self.cible(app)
        app.fermer()
        try? await Task.sleep(for: .milliseconds(50))
        let lien = ConnexionApp(cible: cible)
        let fini = Boite(false)
        lien.surFin = { fini.valeur = true }
        #expect(await attendreQue { fini.valeur })
    }

    /// Releve ponctuel : la trame de l'ancien passeur, lue par `Lecture` ; `fini` apres la fermeture par l'app.
    @Test func livraisonPonctuelle() async throws {
        let app = try FausseApp()
        let cible = try await Self.cible(app, .releve)
        let json = Data(#"{"accessoires":[],"date":"2026-10-12T12:00:00.000Z","statut":"ok","version":1}"#.utf8)
        let fini = Boite(false)
        LivraisonPonctuelle.livrer(cible, json: json) { fini.valeur = true }
        /// Une lecture neuve de tout ce qui est arrive : la trame est-elle complete ?
        func complete() -> Bool {
            var l = EnvoiPasseur.Lecture(jeton: app.jeton)
            return l.ajouter(app.octets) == .json(json)
        }
        #expect(await attendreQue { complete() })
        #expect(!fini.valeur, "attend que l'app ferme")
        app.fermer()
        #expect(await attendreQue { fini.valeur })
    }
}
```

- [ ] **Step 2 : lancer les tests, vérifier qu'ils échouent**

Run : `outils/tester.sh PasseurTests/ConnexionAppTests`
Expected : échec de compilation (`ConnexionApp`, `LivraisonPonctuelle` inconnus).

- [ ] **Step 3 : écrire le code**

`Passeur/Logique/ConnexionApp.swift` :

```swift
import Foundation
import Network

/// Connexion d'abonnement du demon vers une app, sur 127.0.0.1 (spec, section 2.2) : le jeton sur une ligne, puis des
/// trames dans les deux sens. Une trame mal formee ou un message illisible de l'app ferme la connexion ; un type
/// inconnu est ignore. Tout sur la file principale.
@MainActor
final class ConnexionApp: LienApp {
    var surMessage: (@MainActor (MessagePasseur) -> Void)?
    var surFin: (@MainActor () -> Void)?
    private var connexion: NWConnection?
    private var lecture = EnvoiPasseur.LectureTrames()

    /// Se connecte et envoie le jeton (`send` met en file avant que la connexion soit prete, dans l'ordre).
    init(cible: EnvoiPasseur.Cible) {
        // `Cible` n'a jamais de port 0 (lecture stricte de l'URL).
        guard let port = NWEndpoint.Port(rawValue: cible.port) else { return }
        let c = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        connexion = c
        c.stateUpdateHandler = { [weak self] etat in
            MainActor.assumeIsolated {
                switch etat {
                case .waiting(let e), .failed(let e):
                    journal.error("connexion à l'app impossible : \(String(describing: e), privacy: .public)")
                    self?.terminer()
                case .cancelled:
                    self?.terminer()
                default:
                    break
                }
            }
        }
        c.start(queue: .main)
        c.send(content: EnvoiPasseur.ligneJeton(cible.jeton), completion: .idempotent)
        recevoir(c)
    }

    func envoyer(_ m: MessagePasseur) {
        connexion?.send(content: EnvoiPasseur.trame(m), completion: .contentProcessed { [weak self] erreur in
            guard erreur != nil else { return }
            MainActor.assumeIsolated { self?.terminer() }
        })
    }

    func fermer() {
        terminer()
    }

    private func recevoir(_ c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] donnees, _, finie, erreur in
            MainActor.assumeIsolated {
                guard let self, self.connexion === c else { return }
                if let donnees, !donnees.isEmpty {
                    let issue = self.lecture.ajouter(donnees)
                    for json in issue.trames {
                        guard self.connexion === c else { return }
                        switch MessagePasseur.lire(json) {
                        case .message(let m):
                            self.surMessage?(m)
                        case .ignore(let type):
                            journal.notice("message ignoré : \(type, privacy: .public)")
                        case .illisible:
                            journal.error("message illisible de l'app : connexion fermée")
                            self.terminer()
                            return
                        }
                    }
                    if issue.erreur != nil {
                        journal.error("trame mal formée de l'app : connexion fermée")
                        self.terminer()
                        return
                    }
                }
                if finie || erreur != nil {
                    self.terminer()
                    return
                }
                self.recevoir(c)
            }
        }
    }

    /// Ferme la connexion et previent le demon, une seule fois.
    private func terminer() {
        guard let c = connexion else { return }
        connexion = nil
        c.cancel()
        let fin = surFin
        surFin = nil
        surMessage = nil
        fin?()
    }
}

/// Releve ponctuel (URL `releve`), comme l'ancien passeur : la trame `<jeton>\n<longueur>\n<JSON>`, son cote ferme,
/// puis l'attente de la fermeture par l'app (elle a tout lu). Au plus `delai`. `fini` est appele une fois, quoi qu'il
/// arrive.
@MainActor
enum LivraisonPonctuelle {
    static let delai: Duration = .seconds(10)

    static func livrer(_ cible: EnvoiPasseur.Cible, json: Data, fini: @escaping @MainActor () -> Void) {
        let fin = UneFois(fini)
        guard let port = NWEndpoint.Port(rawValue: cible.port) else {
            fin.appeler()
            return
        }
        let c = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        c.stateUpdateHandler = { etat in
            MainActor.assumeIsolated {
                switch etat {
                case .ready:
                    c.send(content: EnvoiPasseur.trame(jeton: cible.jeton, json: json), contentContext: .finalMessage,
                           isComplete: true, completion: .contentProcessed { erreur in
                        MainActor.assumeIsolated {
                            if let erreur {
                                journal.error("relevé ponctuel non envoyé : \(String(describing: erreur), privacy: .public)")
                                c.cancel()
                                fin.appeler()
                                return
                            }
                            c.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, _, _ in
                                MainActor.assumeIsolated {
                                    c.cancel()
                                    fin.appeler()
                                }
                            }
                        }
                    })
                case .waiting(let e), .failed(let e):
                    journal.error("relevé ponctuel : connexion impossible : \(String(describing: e), privacy: .public)")
                    c.cancel()
                    fin.appeler()
                default:
                    break
                }
            }
        }
        c.start(queue: .main)
        Task { @MainActor in
            try? await Task.sleep(for: delai)
            c.cancel()
            fin.appeler()
        }
    }
}
```

- [ ] **Step 4 : lancer les tests, vérifier qu'ils passent**

Run : `outils/tester.sh PasseurTests`
Expected : PASS.

- [ ] **Step 5 : commit**

```bash
git add Passeur/Logique/ConnexionApp.swift PasseurTests/ConnexionAppTests.swift
git commit -m "Demon : connexion d'abonnement et releve ponctuel sur la boucle locale

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8 : l'app Catalyst, HomeKit et le Masqueur

**Files:**
- Delete: `Passeur/PasseurApp.swift` (`git rm`)
- Create: `Passeur/AppDelegate.swift`, `Passeur/SceneDelegate.swift`, `Passeur/MaisonHomeKit.swift`
- Create: `Masqueur/Masqueur.swift`
- Modify: `Passeur/Passeur.entitlements`, `project.yml` (cibles `Masqueur` et `Passeur`)

**Interfaces:**
- Consumes : `DemonPasseur`, `HorlogeReelle`, `OuvertureSMAppService`, `ProfilPasseur`, `ConnexionApp`, `LivraisonPonctuelle`, `UneFois`, `SourceMaison`, `IssueIdentifier`, `journal`, `DemonPasseur.ordonner`.
- Produces : l'app `Passeur Noms.app` (Catalyst) avec `Contents/PlugIns/Masqueur.bundle` ; clé `MaillagePasseurProtocole` (entier 1) dans son Info.plist, que lisent `outils/passeur.sh` (tâche 9) et l'app (tâche 11).

Pas de test automatique (HomeKit, UIKit, AppKit) : la vérification est une compilation Catalyst sans signature ; le banc de la tâche 9 vérifie le reste avec Djoko.

- [ ] **Step 1 : le projet**

Dans `project.yml`, remplacer la cible `Passeur` entière par :

```yaml
  # Passeur Noms, demon de Maison (spec 2026-10-12-demon-passeur-design.md) : app Mac Catalyst sans fenetre ni Dock
  # (LSUIElement), signee en developpement par outils/passeur.sh (HomeKit est refuse au Developer ID). Masqueur.bundle
  # rend invisible, des sa creation, la fenetre de la scene que macOS impose.
  Masqueur:
    type: bundle
    platform: macOS
    sources:
      - path: Masqueur
    info:
      path: Masqueur/Info.plist
      properties:
        NSPrincipalClass: Masqueur
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: fr.djoko.maillage.passeur.masqueur
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: Apple Development
  Passeur:
    type: application
    platform: iOS
    deploymentTarget: "18.0"
    sources:
      - path: Passeur
      - path: MaillageCoeur/Noms/NomsMaison.swift
      - path: MaillageCoeur/Noms/ProtocolePasseur.swift
      - path: MaillageCoeur/Annonces/CodageJSON.swift
    dependencies:
      - target: Masqueur
        embed: true
        platformFilter: macOS
        copy:
          destination: plugins
    info:
      path: Passeur/Info.plist
      properties:
        CFBundleDisplayName: Passeur Noms
        # Schema d'URL par lequel les apps lui donnent le port et le jeton (EnvoiPasseur.schema).
        CFBundleURLTypes:
          - CFBundleURLName: fr.djoko.maillage.passeur
            CFBundleURLSchemes:
              - maillage-passeur
        # Ni Dock ni menu : un demon.
        LSUIElement: true
        # Version du protocole parle (abonnement) : outils/passeur.sh et les apps reconnaissent ainsi le demon.
        MaillagePasseurProtocole: 1
        NSHomeKitUsageDescription: "Passeur Noms lit les noms, pièces, zones, fabricants et batteries de vos accessoires Maison pour Maillage Thread et Maillage Zigbee, et fait clignoter un accessoire quand vous le demandez (Identifier). Rien ne sort de ce Mac."
        UILaunchScreen: {}
        # macOS 27 impose une scene : declaree sans contenu, refermee des sa connexion (SceneDelegate).
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: true
          UISceneConfigurations:
            UIWindowSceneSessionRoleApplication:
              - UISceneConfigurationName: Defaut
                UISceneDelegateClassName: "$(PRODUCT_MODULE_NAME).SceneDelegate"
    settings:
      base:
        PRODUCT_NAME: Passeur Noms
        PRODUCT_MODULE_NAME: Passeur
        PRODUCT_BUNDLE_IDENTIFIER: fr.djoko.maillage.passeur
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        MARKETING_VERSION: "2.0"
        CURRENT_PROJECT_VERSION: "1"
        CODE_SIGN_ENTITLEMENTS: Passeur/Passeur.entitlements
        # HomeKit exige un profil : signature automatique ; l'equipe est donnee par outils/passeur.sh
        # (DEVELOPMENT_TEAM en ligne de commande).
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: Apple Development
        SUPPORTS_MACCATALYST: YES
        SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO
        TARGETED_DEVICE_FAMILY: "1,2"
```

Dans `Passeur/Passeur.entitlements`, garder `com.apple.developer.homekit` et ajouter, dans le même `<dict>` :

```xml
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
```

- [ ] **Step 2 : le Masqueur**

`Masqueur/Masqueur.swift` (le fichier `Masqueur/Info.plist` est écrit par XcodeGen) :

```swift
import AppKit
import ObjectiveC

/// Module AppKit charge par le demon Catalyst (`AppDelegate.chargerMasqueur`), avant que UIKit connecte la scene que
/// macOS 27 impose : toute fenetre de l'app nait transparente et inerte (initialiseurs de NSWindow echanges), avant
/// tout affichage ; politique d'activation `.accessory` ; par securite, toute fenetre qui deviendrait cle, principale,
/// mise a jour ou exposee est retiree de l'ecran. Valide au cinquieme essai du 12/10 : ni fenetre ni eclair. Repose
/// sur le comportement d'UIKit pour Mac : a reverifier a chaque version majeure de macOS.
@objc(Masqueur)
final class Masqueur: NSObject {
    @MainActor private static var installe = false
    @MainActor private static var observateurs: [any NSObjectProtocol] = []

    /// Appele par l'app, sur le fil principal.
    override init() {
        super.init()
        MainActor.assumeIsolated { Masqueur.installer() }
    }

    @MainActor
    private static func installer() {
        guard !installe else { return }
        installe = true
        intercepter()
        NSApplication.shared.setActivationPolicy(.accessory)
        for nom in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification,
                    NSWindow.didUpdateNotification, NSWindow.didExposeNotification] {
            observateurs.append(NotificationCenter.default.addObserver(forName: nom, object: nil, queue: .main) { note in
                MainActor.assumeIsolated {
                    if let w = note.object as? NSWindow {
                        Masqueur.rendreInvisible(w)
                        w.orderOut(nil)
                    }
                }
            })
        }
        for w in NSApplication.shared.windows {
            rendreInvisible(w)
            w.orderOut(nil)
        }
    }

    @MainActor
    static func rendreInvisible(_ w: NSWindow) {
        w.alphaValue = 0
        w.ignoresMouseEvents = true
        w.hasShadow = false
        w.collectionBehavior.insert([.transient, .ignoresCycle])
    }

    /// Echange les deux initialiseurs de NSWindow contre des versions qui rendent la fenetre invisible des sa creation.
    @MainActor
    private static func intercepter() {
        let paires: [(Selector, Selector)] = [
            (#selector(NSWindow.init(contentRect:styleMask:backing:defer:)),
             #selector(NSWindow.masquer_init(contentRect:styleMask:backing:defer:))),
            (#selector(NSWindow.init(contentRect:styleMask:backing:defer:screen:)),
             #selector(NSWindow.masquer_init(contentRect:styleMask:backing:defer:screen:))),
        ]
        for (original, remplacant) in paires {
            if let a = class_getInstanceMethod(NSWindow.self, original),
               let b = class_getInstanceMethod(NSWindow.self, remplacant) {
                method_exchangeImplementations(a, b)
            }
        }
    }
}

extension NSWindow {
    /// Apres l'echange, cet appel atteint l'initialiseur d'origine.
    @objc func masquer_init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType,
                            defer flag: Bool) -> NSWindow {
        let w = masquer_init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        Masqueur.rendreInvisible(w)
        return w
    }

    @objc func masquer_init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType,
                            defer flag: Bool, screen: NSScreen?) -> NSWindow {
        let w = masquer_init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag, screen: screen)
        Masqueur.rendreInvisible(w)
        return w
    }
}
```

- [ ] **Step 3 : Maison par HomeKit**

`Passeur/MaisonHomeKit.swift` (reprend le relevé et les batteries de l'ancien `PasseurApp.swift`, et ajoute `id`, les délégués de changement et `identify()`) :

```swift
import HomeKit

/// Maison par HomeKit, pour le demon (`SourceMaison`, spec section 3.2) : le releve (noms, pieces, zones, fabricants,
/// noeuds Matter, batteries, identifiants), les changements (delegues des maisons et des accessoires ; pas la
/// joignabilite), et `identify()`. HomeKit ne dit pas sur quel fil il appelle ses delegues : tout passe par l'acteur
/// principal.
@MainActor
final class MaisonHomeKit: NSObject, SourceMaison, HMHomeManagerDelegate, HMHomeDelegate, HMAccessoryDelegate {
    var surChangement: (@MainActor () -> Void)?
    private let gestionnaire = HMHomeManager()
    /// Maison a donne ses domiciles : avant `homeManagerDidUpdateHomes`, la liste est vide (HMHomeManager.h).
    private var maisonChargee = false
    /// Lectures des batteries : Maison repond depuis son cache (0,2 s pour 78 valeurs le 28/09) ; au-dela, le releve
    /// part avec les valeurs deja connues.
    static let delaiLectures: Duration = .seconds(5)

    override init() {
        super.init()
        gestionnaire.delegate = self
    }

    var acces: EtatPasseur.Acces {
        let s = gestionnaire.authorizationStatus
        if s.contains(.authorized) { return .autorise }
        if s.contains(.determined) { return .refuse }
        return .attente
    }

    func releve(batteries: Bool) async -> NomsMaison? {
        let s = gestionnaire.authorizationStatus
        guard s.contains(.authorized) else {
            return s.contains(.determined)
                ? NomsMaison(date: .now, statut: .refuse,
                             message: "Accès à Maison refusé : Réglages Système › Confidentialité et sécurité › Maison.")
                : nil
        }
        guard maisonChargee else { return nil }
        // Jamais un « ok » vide : il effacerait les noms gardes par l'app.
        guard !gestionnaire.homes.isEmpty else {
            return NomsMaison(date: .now, statut: .erreur, message: "Aucun domicile dans Maison")
        }
        if batteries { await lireBatteries() }
        return releveCourant()
    }

    func identifier(_ id: UUID) async -> IssueIdentifier {
        guard let a = gestionnaire.homes.flatMap(\.accessories).first(where: { $0.uniqueIdentifier == id }) else {
            return .inconnu
        }
        guard a.supportsIdentify else { return .nonIdentifiable }
        return await withCheckedContinuation { suite in
            a.identify { erreur in
                suite.resume(returning: erreur.map { .erreur($0.localizedDescription) } ?? .ok)
            }
        }
    }

    // MARK: Releve

    private func releveCourant() -> NomsMaison {
        let accessoires = gestionnaire.homes.flatMap(\.accessories).map { a in
            let b = Self.batterie(a)
            return AccessoireMaison(nom: a.name, piece: a.room?.name, fabricant: a.manufacturer, modele: a.model,
                                    firmware: a.firmwareVersion, categorie: a.category.localizedDescription,
                                    noeudMatter: AccessoireMaison.noeud(a.matterNodeID),
                                    pont: a.category.categoryType == HMAccessoryCategoryTypeBridge ? true : nil,
                                    batterie: b.flatMap {
                                        BatterieMaison.depuisHomeKit(niveau: $0.niveau?.value, charge: $0.charge?.value,
                                                                     alerte: $0.alerte?.value)
                                    },
                                    id: a.uniqueIdentifier.uuidString)
        }
        // Zones et pieces dans l'ordre de Maison.
        let zones = gestionnaire.homes.flatMap(\.zones).map { ZoneMaison(nom: $0.name, pieces: $0.rooms.map(\.name)) }
        let domicile = gestionnaire.homes.map(\.name).joined(separator: " + ")
        return NomsMaison(date: .now, statut: .ok, domicile: domicile.isEmpty ? nil : domicile,
                          accessoires: DemonPasseur.ordonner(accessoires), zones: zones)
    }

    /// Service Batterie d'un accessoire : niveau, etat de charge, alerte.
    private static func batterie(_ a: HMAccessory)
        -> (niveau: HMCharacteristic?, charge: HMCharacteristic?, alerte: HMCharacteristic?)? {
        guard let s = a.services.first(where: { $0.serviceType == HMServiceTypeBattery }) else { return nil }
        func c(_ type: String) -> HMCharacteristic? { s.characteristics.first { $0.characteristicType == type } }
        return (c(HMCharacteristicTypeBatteryLevel), c(HMCharacteristicTypeChargingState),
                c(HMCharacteristicTypeStatusLowBattery))
    }

    /// Relit les batteries ; rend la main a la derniere lecture, ou apres `delaiLectures`.
    private func lireBatteries() async {
        let caracteristiques = gestionnaire.homes.flatMap(\.accessories).compactMap(Self.batterie)
            .flatMap { [$0.niveau, $0.charge, $0.alerte].compactMap { $0 } }
        guard !caracteristiques.isEmpty else { return }
        await withCheckedContinuation { (suite: CheckedContinuation<Void, Never>) in
            let fin = UneFois { suite.resume() }
            let restantes = Compteur(caracteristiques.count)
            for c in caracteristiques {
                c.readValue { @Sendable _ in
                    Task { @MainActor in
                        if restantes.retirer() == 0 { fin.appeler() }
                    }
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: Self.delaiLectures)
                fin.appeler()
            }
        }
    }

    // MARK: Changements

    /// Les maisons et les accessoires ont ce suivi pour delegue (les nouveaux aussi) ; puis le demon est prevenu.
    private func changer() {
        for h in gestionnaire.homes {
            h.delegate = self
            for a in h.accessories { a.delegate = self }
        }
        surChangement?()
    }

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.maisonChargee = true
            self.changer()
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        Task { @MainActor in
            journal.notice("autorisation de Maison : \(status.rawValue)")
            self.changer()
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) { Task { @MainActor in self.changer() } }
    nonisolated func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) { Task { @MainActor in self.changer() } }
    nonisolated func homeManagerDidUpdatePrimaryHome(_ manager: HMHomeManager) { Task { @MainActor in self.changer() } }

    nonisolated func homeDidUpdateName(_ home: HMHome) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didAdd accessory: HMAccessory) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didRemove accessory: HMAccessory) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didUpdate room: HMRoom, for accessory: HMAccessory) {
        Task { @MainActor in self.changer() }
    }
    nonisolated func home(_ home: HMHome, didAdd room: HMRoom) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didRemove room: HMRoom) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didUpdateNameFor room: HMRoom) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didAdd zone: HMZone) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didRemove zone: HMZone) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didUpdateNameFor zone: HMZone) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didAdd room: HMRoom, to zone: HMZone) { Task { @MainActor in self.changer() } }
    nonisolated func home(_ home: HMHome, didRemove room: HMRoom, from zone: HMZone) {
        Task { @MainActor in self.changer() }
    }

    nonisolated func accessoryDidUpdateName(_ accessory: HMAccessory) { Task { @MainActor in self.changer() } }
    nonisolated func accessoryDidUpdateServices(_ accessory: HMAccessory) { Task { @MainActor in self.changer() } }
}

/// Compte a rebours des lectures de batteries.
@MainActor
private final class Compteur {
    private var restant: Int

    init(_ n: Int) {
        restant = n
    }

    /// Une de moins ; rend ce qui reste.
    func retirer() -> Int {
        restant -= 1
        return restant
    }
}
```

- [ ] **Step 4 : l'entrée de l'app et la scène**

`Passeur/AppDelegate.swift` :

```swift
import UIKit

/// Passeur Noms, demon de Maison (spec du 12/10) : app Mac Catalyst sans fenetre ni Dock, lancee par une URL des apps
/// (`maillage-passeur://releve` ou `abonner`) ou a l'ouverture de session. Le coeur est `DemonPasseur` ; ici, ce qui
/// touche au systeme : le Masqueur, HomeKit, SMAppService, le reseau, la sortie.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// Le module AppKit qui masque les fenetres, garde en vie.
    private var masqueur: NSObject?
    private var demon: DemonPasseur?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        chargerMasqueur()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let d = DemonPasseur(
            source: MaisonHomeKit(), ouverture: OuvertureSMAppService(), horloge: HorlogeReelle(), version: version,
            profilExpire: ProfilPasseur.expiration(paquet: Bundle.main.bundleURL),
            connecter: { ConnexionApp(cible: $0) },
            livrerPonctuel: { LivraisonPonctuelle.livrer($0, json: $1, fini: $2) },
            quitter: { raison in
                journal.notice("fin : \(raison, privacy: .public)")
                exit(0)
            })
        demon = d
        d.demarrer()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Defaut", sessionRole: session.role)
    }

    /// URL recues par une scene (`SceneDelegate`).
    func recevoir(_ urls: [URL]) {
        guard let demon else { return }
        for url in urls {
            Task { await demon.recevoir(url: url) }
        }
    }

    /// Avant que UIKit connecte la scene : toute fenetre de l'app nait invisible (spec, section 3.1).
    private func chargerMasqueur() {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("Masqueur.bundle"),
              let module = Bundle(url: url), module.load(),
              let classe = module.principalClass as? NSObject.Type else {
            journal.error("Masqueur.bundle introuvable : la fenêtre imposée par UIKit restera visible")
            return
        }
        masqueur = classe.init()
    }
}
```

`Passeur/SceneDelegate.swift` :

```swift
import UIKit

/// La scene que macOS 27 impose (une app UIKit sans scene s'arrete au lancement) : sans contenu, refermee des sa
/// connexion. Elle porte aussi les URL des apps : a la connexion d'une scene neuve (`urlContexts`), ou a une scene
/// encore la (`openURLContexts`).
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        transmettre(options.urlContexts)
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { erreur in
            journal.error("scène non refermée : \(String(describing: erreur), privacy: .public)")
        }
    }

    func scene(_ scene: UIScene, openURLContexts contextes: Set<UIOpenURLContext>) {
        transmettre(contextes)
    }

    private func transmettre(_ contextes: Set<UIOpenURLContext>) {
        guard !contextes.isEmpty else { return }
        (UIApplication.shared.delegate as? AppDelegate)?.recevoir(contextes.map(\.url))
    }
}
```

Supprimer l'ancien point d'entrée : `git rm Passeur/PasseurApp.swift`.

- [ ] **Step 5 : vérifier la compilation Catalyst (sans signature) et les tests**

Run :

```bash
xcodegen generate --quiet
xcodebuild -project MaillageThread.xcodeproj -scheme Passeur -destination 'platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath "${TMPDIR:-/tmp}/passeur-verif" CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning:|BUILD"
ls "${TMPDIR:-/tmp}/passeur-verif/Build/Products/Debug-maccatalyst/Passeur Noms.app/Contents/PlugIns"
/usr/libexec/PlistBuddy -c "Print :MaillagePasseurProtocole" "${TMPDIR:-/tmp}/passeur-verif/Build/Products/Debug-maccatalyst/Passeur Noms.app/Contents/Info.plist"
outils/tester.sh
```

Expected : `** BUILD SUCCEEDED **` sans `error:` ni `warning:` ; `Masqueur.bundle` listé ; `1` ; tous les tests verts. **Ne pas lancer l'app produite.**

Si Swift 6 refuse une conformité d'un délégué de HomeKit (« conformance … crosses into main actor-isolated code »), garder les méthodes `nonisolated` qui repassent par `Task { @MainActor in … }`, comme ci-dessus ; ne pas baisser `SWIFT_VERSION`.

- [ ] **Step 6 : commit**

```bash
git add project.yml Passeur/AppDelegate.swift Passeur/SceneDelegate.swift Passeur/MaisonHomeKit.swift \
  Passeur/Passeur.entitlements Masqueur/Masqueur.swift
git commit -m "Demon Passeur Noms en Mac Catalyst : HomeKit en arriere-plan, scene refermee, Masqueur AppKit

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`git rm` a déjà indexé la suppression de `Passeur/PasseurApp.swift`. Si XcodeGen a écrit `Masqueur/Info.plist` et `Passeur/Info.plist`, les ajouter aussi : l'ancien `Passeur/Info.plist` était suivi.)

---

### Task 9 : installation par `outils/passeur.sh`, outil de banc, premier banc avec Djoko

**Files:**
- Modify: `outils/passeur.sh` (réécrit)
- Create: `outils/verifier-passeur.py`, `outils/tests/test_verifier_passeur.py`

**Interfaces:**
- Consumes : l'app Catalyst de la tâche 8, la clé `MaillagePasseurProtocole`.
- Produces : `~/Applications/Passeur Noms.app` installé et enregistré ; l'outil `python3 outils/verifier-passeur.py releve|abonner [--duree S] [--relire]`.

Les steps 1 à 4 peuvent être faits par un sous-agent ; les steps 5 à 7 (banc) **par le contrôleur, avec Djoko**.

- [ ] **Step 1 : tests de l'outil de banc (échouent)**

`outils/tests/test_verifier_passeur.py` :

```python
"""Tests de l'outil de banc du passeur : trames et resumes, sans reseau."""
import importlib.util
import json
import pathlib
import unittest

CHEMIN = pathlib.Path(__file__).resolve().parent.parent / "verifier-passeur.py"
spec = importlib.util.spec_from_file_location("verifier_passeur", CHEMIN)
vp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vp)


def trame(objet):
    j = json.dumps(objet).encode()
    return str(len(j)).encode() + b"\n" + j


class Trames(unittest.TestCase):
    def test_plusieurs_et_reste(self):
        a, b = trame({"t": "relire", "v": 1}), trame({"t": "etat", "v": 1})
        trames, reste = vp.lire_trames(a + b + b"12\n{")
        self.assertEqual([json.loads(t)["t"] for t in trames], ["relire", "etat"])
        self.assertEqual(reste, b"12\n{")

    def test_longueur_fausse(self):
        with self.assertRaises(ValueError):
            vp.lire_trames(b"x\n{}")
        with self.assertRaises(ValueError):
            vp.lire_trames(b"0\n")


class Resumes(unittest.TestCase):
    def test_releve_sans_noms(self):
        noms = {"version": 2, "statut": "ok", "accessoires": [{"nom": "Secret", "id": "X"}, {"nom": "Autre"}],
                "zones": [{"nom": "Etage", "pieces": ["Chambre"]}]}
        texte = vp.resumer({"t": "releve", "v": 1, "noms": noms})
        self.assertIn("2 accessoires", texte)
        self.assertIn("1 avec id", texte)
        self.assertNotIn("Secret", texte)
        self.assertNotIn("Chambre", texte)

    def test_etat(self):
        texte = vp.resumer({"t": "etat", "v": 1, "version": "2.0", "acces": "autorise",
                            "ouvertureSession": "inactive", "profilExpire": None})
        self.assertIn("2.0", texte)
        self.assertIn("autorise", texte)

    def test_inconnu(self):
        self.assertIn("allumer", vp.resumer({"t": "allumer", "v": 1}))


if __name__ == "__main__":
    unittest.main()
```

Run : `python3 -m unittest outils/tests/test_verifier_passeur.py`
Expected : échec (`verifier-passeur.py` absent).

- [ ] **Step 2 : l'outil de banc**

`outils/verifier-passeur.py` :

```python
#!/usr/bin/env python3
"""Banc du demon Passeur Noms : joue le role d'une app sur la boucle locale (127.0.0.1).

  python3 outils/verifier-passeur.py releve
  python3 outils/verifier-passeur.py abonner [--duree 120] [--relire]

releve  : demande un releve ponctuel (URL maillage-passeur://releve) et le resume.
abonner : s'abonne (URL maillage-passeur://abonner) et resume chaque message recu pendant --duree secondes ;
          --relire envoie `relire` apres le premier releve.
N'affiche que des nombres et des etats : jamais un nom de Maison, une piece, ni un identifiant d'accessoire, ni le
jeton. Ouvre l'URL avec `open -g` (le demon ne passe pas au premier plan).
"""
import argparse
import json
import secrets
import socket
import subprocess
import sys
import time

TAILLE_MAX = 8 * 1024 * 1024


def lire_trames(tampon):
    """Trames completes `<longueur>\\n<JSON>` du tampon ; rend (trames, reste). ValueError si une longueur est fausse."""
    trames = []
    while True:
        fin = tampon.find(b"\n")
        if fin < 0:
            if len(tampon) > 16:
                raise ValueError("ligne de longueur trop longue")
            return trames, tampon
        ligne = tampon[:fin]
        if not ligne.isdigit():
            raise ValueError("longueur illisible")
        n = int(ligne)
        if n <= 0 or n > TAILLE_MAX:
            raise ValueError("longueur hors bornes")
        if len(tampon) < fin + 1 + n:
            return trames, tampon
        trames.append(tampon[fin + 1:fin + 1 + n])
        tampon = tampon[fin + 1 + n:]


def resumer_noms(noms):
    accessoires = noms.get("accessoires", [])
    avec_id = sum(1 for a in accessoires if a.get("id"))
    return (f"version {noms.get('version')}, statut {noms.get('statut')}, {len(accessoires)} accessoires, "
            f"{avec_id} avec id, {len(noms.get('zones') or [])} zones")


def resumer(message):
    t = message.get("t")
    if t == "etat":
        return (f"etat : version {message.get('version')}, acces {message.get('acces')}, ouverture "
                f"{message.get('ouvertureSession')}, profil {message.get('profilExpire')}")
    if t == "releve":
        return "releve : " + resumer_noms(message.get("noms") or {})
    if t == "identifie":
        return f"identifie : demande {message.get('demande')}, ok {message.get('ok')}, erreur {message.get('erreur')}"
    return f"message de type {t}"


def ecouter():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("127.0.0.1", 0))
    s.listen(1)
    return s, s.getsockname()[1]


def ouvrir(demande, port, jeton):
    subprocess.run(["open", "-g", f"maillage-passeur://{demande}?port={port}&jeton={jeton}"], check=True)


def accepter(s, jeton, delai=120):
    s.settimeout(delai)
    c, _ = s.accept()
    s.close()
    c.settimeout(delai)
    tampon = b""
    while b"\n" not in tampon:
        morceau = c.recv(65536)
        if not morceau:
            raise SystemExit("connexion fermee avant le jeton")
        tampon += morceau
    ligne, _, reste = tampon.partition(b"\n")
    if not secrets.compare_digest(ligne, jeton.encode()):
        raise SystemExit("jeton faux")
    print("jeton : ok")
    return c, reste


def releve():
    jeton = secrets.token_hex(32)
    s, port = ecouter()
    ouvrir("releve", port, jeton)
    c, tampon = accepter(s, jeton)
    while True:
        morceau = c.recv(65536)
        if not morceau:
            break
        tampon += morceau
    c.close()
    longueur, _, json_brut = tampon.partition(b"\n")
    if not longueur.isdigit() or len(json_brut) < int(longueur):
        raise SystemExit("trame du releve incomplete")
    print("releve ponctuel : " + resumer_noms(json.loads(json_brut[:int(longueur)])))


def abonner(duree, relire):
    jeton = secrets.token_hex(32)
    s, port = ecouter()
    ouvrir("abonner", port, jeton)
    c, tampon = accepter(s, jeton)
    c.settimeout(1)
    debut = time.monotonic()
    relu = not relire
    while time.monotonic() - debut < duree:
        try:
            morceau = c.recv(65536)
        except socket.timeout:
            continue
        if not morceau:
            print("le demon a ferme la connexion")
            break
        trames, tampon = lire_trames(tampon + morceau)
        for t in trames:
            message = json.loads(t)
            print(f"{time.strftime('%H:%M:%S')} {resumer(message)}")
            if not relu and message.get("t") == "releve":
                j = json.dumps({"t": "relire", "v": 1}).encode()
                c.sendall(str(len(j)).encode() + b"\n" + j)
                print("relire envoye")
                relu = True
    c.close()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("demande", choices=["releve", "abonner"])
    p.add_argument("--duree", type=int, default=120)
    p.add_argument("--relire", action="store_true")
    a = p.parse_args()
    if a.demande == "releve":
        releve()
    else:
        abonner(a.duree, a.relire)


if __name__ == "__main__":
    sys.exit(main())
```

Run : `python3 -m unittest outils/tests/test_verifier_passeur.py`
Expected : `OK` (6 tests). **Ne pas lancer l'outil lui-même** (il ouvre le démon).

- [ ] **Step 3 : réécrire `outils/passeur.sh`**

Remplacer tout le fichier par :

```sh
#!/bin/sh
# Passeur Noms, demon de Maison (docs/superpowers/specs/2026-10-12-demon-passeur-design.md) : app Mac Catalyst sans
# fenetre ni Dock, qui lit Maison en arriere-plan et la sert a Maillage Thread et Maillage Zigbee par la boucle locale.
# HomeKit n'est pas offert aux apps Mac signees Developer ID (capacite reservee a l'App Store) : le demon reste une
# compilation de developpement, signee par l'equipe payante pour ce Mac enregistre, avec un profil d'un an ; relancer
# ce script pour le renouveler (les apps le rappellent 30 jours avant).
# Compile, arrete le demon qui tourne (par son PID), remplace l'app installee (seulement une installation faite par ce
# script : l'ancienne enveloppe, lien WrappedBundle, ou le demon, cle MaillagePasseurProtocole de son Info.plist),
# l'enregistre aupres de LaunchServices (et desinscrit les copies de compilation, qui reclameraient aussi l'URL
# maillage-passeur://), puis la lance en arriere-plan : le premier lancement demande l'acces a Maison.
#
#   outils/passeur.sh [--sans-lancer]
#
#   --sans-lancer  compile et installe, sans lancer.
#   APP=...        paquet a installer, en .app (defaut : ~/Applications/Passeur Noms.app).
#   DD=...         produits de compilation (defaut : ~/Library/Developer/Xcode/DerivedData/maillage-passeur).
#   EQUIPE=...     equipe de signature, 10 caracteres (defaut : celle du premier certificat « Apple Development »
#                  encore valide du trousseau, sinon celle du certificat « Developer ID Application », la meme
#                  equipe payante : Xcode cree alors le certificat Apple Development). Jamais affichee.
set -eu
USAGE="usage : outils/passeur.sh [--sans-lancer]"
LANCER=oui
for a in "$@"; do
  case "$a" in
    --sans-lancer) LANCER=non ;;
    *) echo "argument inconnu : $a" >&2; echo "$USAGE" >&2; exit 1 ;;
  esac
done
cd "$(dirname "$0")/.."
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage-passeur}
APP=${APP:-"$HOME/Applications/Passeur Noms.app"}
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
# Gardes, avant de toucher au disque : l'app installee est effacee puis remplacee.
case "$APP" in
  *.app) ;;
  *) echo "APP : chemin d'un paquet .app (par exemple ~/Applications/Passeur Noms.app), pas « $APP »" >&2
     exit 1 ;;
esac
ENVELOPPE=non
if [ -e "$APP" ]; then
  if [ "$(readlink "$APP/WrappedBundle" 2>/dev/null)" = "Wrapper/Passeur Noms.app" ]; then
    ENVELOPPE=oui
  elif ! /usr/libexec/PlistBuddy -c "Print :MaillagePasseurProtocole" "$APP/Contents/Info.plist" >/dev/null 2>&1; then
    echo "$APP existe mais n'est pas une installation faite par ce script : rien n'est effacé." >&2
    exit 1
  fi
fi
# Equipe : celle du premier certificat « Apple Development » encore valide (le trousseau peut garder des certificats
# expires).
equipe() {
  pem=""
  security find-certificate -a -c "Apple Development" -p 2>/dev/null | while IFS= read -r ligne; do
    pem="$pem$ligne
"
    case "$ligne" in
      *"END CERTIFICATE"*)
        if printf '%s' "$pem" | openssl x509 -noout -checkend 0 >/dev/null 2>&1; then
          printf '%s' "$pem" | openssl x509 -noout -subject 2>/dev/null |
            sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p'
          break
        fi
        pem="" ;;
    esac
  done
}
# Repli : l'equipe du certificat « Developer ID Application » (une seule identite de ce nom dans le trousseau).
equipeDeveloperID() {
  security find-certificate -c "Developer ID Application" -p 2>/dev/null |
    openssl x509 -noout -subject -nameopt RFC2253 2>/dev/null | sed -nE 's/.*OU=([A-Z0-9]{10}).*/\1/p'
}
EQUIPE=${EQUIPE:-$(equipe | head -1)}
[ -n "$EQUIPE" ] || EQUIPE=$(equipeDeveloperID)
if [ -z "$EQUIPE" ]; then
  echo "Pas de certificat Apple Development ni Developer ID : ajouter un compte Apple dans Xcode (Réglages > Comptes), ou EQUIPE=XXXXXXXXXX" >&2
  exit 1
fi
JOURNAL=${TMPDIR:-/tmp}/maillage-passeur.log
xcodegen generate --quiet
if ! xcodebuild -project MaillageThread.xcodeproj -scheme Passeur \
    -destination 'platform=macOS,variant=Mac Catalyst' \
    -derivedDataPath "$DD" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$EQUIPE" build > "$JOURNAL" 2>&1; then
  # Les erreurs, sans le nom du titulaire ni l'equipe.
  grep -E "error:" "$JOURNAL" | sed -E 's/(Apple Development|Developer ID Application): [^(]*\(([A-Z0-9]{10})\)/\1: <titulaire> (<equipe>)/g; s/[A-Z0-9]{10}/<id>/g' >&2 || true
  echo "échec de la compilation, journal complet : $JOURNAL" >&2
  exit 1
fi
PRODUIT="$DD/Build/Products/Debug-maccatalyst/Passeur Noms.app"
if [ ! -d "$PRODUIT/Contents/PlugIns/Masqueur.bundle" ]; then
  echo "Produit de compilation incomplet (Masqueur.bundle absent) : $PRODUIT ($APP n'est pas touché)" >&2
  exit 1
fi
# Le passeur qui tourne (ancienne enveloppe ou demon) : arrete par son PID avant de remplacer son paquet.
for pid in $(pgrep -f "$APP/" 2>/dev/null || true); do
  kill "$pid" 2>/dev/null || true
done
# LaunchServices : l'ancienne installation et les copies de compilation (l'ancienne app iOS et la nouvelle) ne
# doivent plus reclamer l'URL maillage-passeur:// ni l'identifiant du passeur.
if [ -e "$APP" ]; then
  [ "$ENVELOPPE" = oui ] && "$LSREGISTER" -u "$APP/Wrapper/Passeur Noms.app" 2>/dev/null || true
  "$LSREGISTER" -u "$APP" 2>/dev/null || true
fi
for copie in "$DD/Build/Products/Debug-iphoneos/Passeur Noms.app" "$PRODUIT"; do
  [ -e "$copie" ] && "$LSREGISTER" -u "$copie" 2>/dev/null || true
done
rm -rf "$APP"
mkdir -p "$(dirname "$APP")"
ditto "$PRODUIT" "$APP"
"$LSREGISTER" -f "$APP"
if [ "$LANCER" = non ]; then
  echo "Passeur Noms installé (non lancé) : $APP"
else
  open -g "$APP"
  echo "Passeur Noms installé et lancé en arrière-plan : $APP"
fi
```

- [ ] **Step 4 : vérifier le script sans le lancer, puis commit**

Run : `sh -n outils/passeur.sh && echo syntaxe-ok` (et `shellcheck outils/passeur.sh` s'il est installé).
Expected : `syntaxe-ok`.

```bash
git add outils/passeur.sh outils/verifier-passeur.py outils/tests/test_verifier_passeur.py
git commit -m "Installer le demon Passeur Noms en Catalyst ; outil de banc du passeur

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5 (contrôleur, avec Djoko) : installation**

Ouvrir un onglet du Terminal de l'app nommé « Passeur Noms » et y lancer `outils/passeur.sh` (sa sortie masque déjà l'équipe ; ne pas faire de `tail` sur `$TMPDIR/maillage-passeur.log`, qui contient l'identité de signature). Djoko accepte la demande d'accès à Maison si elle paraît. Attendu (spec, banc 1) : pas d'icône dans le Dock, pas de fenêtre ni d'éclair. Vérifier le processus : `pgrep -lf "Passeur Noms.app/Contents/MacOS"`.

- [ ] **Step 6 (contrôleur, avec Djoko) : relevé ponctuel et abonnement**

```bash
python3 outils/verifier-passeur.py releve
```

Expected : `jeton : ok`, puis `version 1, statut ok, N accessoires, 0 avec id` (N ≈ 143).

```bash
python3 outils/verifier-passeur.py abonner --duree 180 --relire
```

Expected : un `etat`, un `releve` en version 2 avec tous les accessoires « avec id », `relire envoye`, un second `releve`. Pendant ces 3 minutes, Djoko renomme un accessoire dans Maison (puis lui rend son nom) : un `releve` arrive dans les secondes qui suivent chaque renommage (spec, section 8 : changements reçus en arrière-plan, premier point du banc).

- [ ] **Step 7 (contrôleur) : journal**

```bash
/usr/bin/log show --last 15m --predicate 'subsystem == "fr.djoko.maillage.passeur"' --style compact | tail -40
```

Expected : lancement, abonné accepté, relevés envoyés (nombres seulement), aucun nom de Maison, aucun UUID. Tout écart (fenêtre visible, relevé absent après un renommage) arrête le plan : le dire à Djoko avant la tâche 10.

---

### Task 10 : l'abonnement côté app

**Files:**
- Create: `MaillageThread/Noms/AbonnementPasseur.swift`
- Create: `MaillageThreadTests/AbonnementPasseurTests.swift`

**Interfaces:**
- Consumes : `EnvoiPasseur.LectureFlux`, `trame(_:)`, `ligneJeton`, `MessagePasseur` (tâches 1-2).
- Produces : `@MainActor final class AbonnementPasseur` avec `init(jeton:)`, `let jeton`, `func ouvrir(_ suite: @escaping (Evenement) -> Void)`, `func fermer()`, `func envoyer(_ m: MessagePasseur)` ; `enum Evenement: Equatable { case prete(UInt16), connecte, message(MessagePasseur), fin(Fin) }` ; `enum Fin: Equatable { case jetonFaux, trameFausse, fermee, interrompue, ecoute(String) }`. Pour les tests : `final class FauxDemon` et `func attendreQue(_:_:)` (MainActor), réutilisés par la tâche 11.

Note : `NomsInternes.swift` utilise encore `EcouteReleve` jusqu'à la tâche 11. Pour garder la compilation verte entre les deux tâches, **ne supprimer `EcouteReleve.swift` qu'à la tâche 11** ; cette tâche ajoute seulement `AbonnementPasseur`.

- [ ] **Step 1 : écrire les tests qui échouent**

`MaillageThreadTests/AbonnementPasseurTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Network
import Synchronization
import Testing
@testable import MaillageThread

/// Attend qu'une condition soit vraie, au plus `delai` ; rend la condition.
@MainActor
func attendreQue(_ delai: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
    let fin = ContinuousClock.now + delai
    while !condition(), ContinuousClock.now < fin { try? await Task.sleep(for: .milliseconds(5)) }
    return condition()
}

/// Faux demon des tests : se connecte a l'ecoute de l'app, envoie des octets sans fermer son cote, et lit les trames
/// de l'app (`LectureTrames`).
final class FauxDemon: Sendable {
    private let connexion: NWConnection
    private let lecture = Mutex(EnvoiPasseur.LectureTrames())
    private let recus = Mutex<[MessagePasseur]>([])

    init?(port: UInt16) {
        guard let p = NWEndpoint.Port(rawValue: port) else { return nil }
        connexion = NWConnection(host: "127.0.0.1", port: p, using: .tcp)
        connexion.start(queue: .global())
        lire()
    }

    deinit {
        connexion.cancel()
    }

    /// Messages recus de l'app, dans l'ordre.
    var messages: [MessagePasseur] { recus.withLock { $0 } }

    private func lire() {
        connexion.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] d, _, fin, e in
            guard let self else { return }
            if let d, !d.isEmpty {
                let trames = self.lecture.withLock { $0.ajouter(d) }.trames
                for j in trames {
                    if case .message(let m) = MessagePasseur.lire(j) { self.recus.withLock { $0.append(m) } }
                }
            }
            if fin || e != nil { return }
            self.lire()
        }
    }

    /// Envoie ces octets sans fermer son cote ; vrai s'ils sont partis.
    func envoyer(_ octets: Data) async -> Bool {
        await withCheckedContinuation { (suite: CheckedContinuation<Bool, Never>) in
            connexion.send(content: octets, completion: .contentProcessed { erreur in
                suite.resume(returning: erreur == nil)
            })
        }
    }

    func jeton(_ j: String) async -> Bool { await envoyer(EnvoiPasseur.ligneJeton(j)) }
    func message(_ m: MessagePasseur) async -> Bool { await envoyer(EnvoiPasseur.trame(m)) }

    /// Fermeture propre (le demon quitte).
    func fermer() {
        connexion.cancel()
    }

    /// Coupure nette.
    func couper() {
        connexion.forceCancel()
    }
}

@MainActor
@Suite("Abonnement au demon Passeur Noms", .timeLimit(.minutes(1)))
struct AbonnementPasseurTests {
    static let jeton = String(repeating: "7e", count: 32)
    static let etat = EtatPasseur(version: "2.0", acces: .autorise, ouvertureSession: .inactive, profilExpire: nil)

    /// Les evenements d'un abonnement, dans l'ordre.
    final class Evenements {
        var liste: [AbonnementPasseur.Evenement] = []
        var port: UInt16? {
            if case .prete(let p) = liste.first { return p }
            return nil
        }
    }

    static func ouvrir() async throws -> (AbonnementPasseur, Evenements, FauxDemon) {
        let a = AbonnementPasseur(jeton: jeton)
        let e = Evenements()
        a.ouvrir { e.liste.append($0) }
        #expect(await attendreQue { e.port != nil })
        let d = try #require(FauxDemon(port: try #require(e.port)))
        return (a, e, d)
    }

    /// Jeton, `etat` et `releve` ecrits d'un coup : tout est lu, dans l'ordre.
    @Test func jetonEtatEtReleveDUnCoup() async throws {
        let (a, e, d) = try await Self.ouvrir()
        let releve = Data(#"{"version":2}"#.utf8)
        #expect(await d.envoyer(EnvoiPasseur.ligneJeton(Self.jeton) + EnvoiPasseur.trame(.etat(Self.etat))
                                + EnvoiPasseur.trame(.releve(releve))))
        #expect(await attendreQue { e.liste.count == 4 })
        #expect(e.liste.dropFirst().first == .connecte)
        #expect(e.liste.dropFirst(2).first == .message(.etat(Self.etat)))
        guard case .message(.releve) = e.liste.last else {
            Issue.record("releve attendu")
            return
        }
        a.fermer()
    }

    /// Les messages de l'app partent vers le demon, une fois connecte ; avant, ils sont ignores.
    @Test func envoi() async throws {
        let (a, e, d) = try await Self.ouvrir()
        a.envoyer(.relire)
        #expect(await d.jeton(Self.jeton))
        #expect(await attendreQue { e.liste.contains(.connecte) })
        a.envoyer(.identifier(demande: 1, accessoire: "X"))
        a.envoyer(.ouvertureSession(actif: true))
        #expect(await attendreQue { d.messages.count == 2 })
        #expect(d.messages == [.identifier(demande: 1, accessoire: "X"), .ouvertureSession(actif: true)])
        a.fermer()
    }

    /// Un type inconnu est ignore, la connexion reste.
    @Test func typeInconnuIgnore() async throws {
        let (a, e, d) = try await Self.ouvrir()
        #expect(await d.jeton(Self.jeton))
        let inconnu = Data(#"{"t":"allumer","v":1}"#.utf8)
        #expect(await d.envoyer(Data("\(inconnu.count)\n".utf8) + inconnu + EnvoiPasseur.trame(.etat(Self.etat))))
        #expect(await attendreQue { e.liste.contains(.message(.etat(Self.etat))) })
        #expect(!e.liste.contains { if case .fin = $0 { true } else { false } })
        a.fermer()
    }

    @Test func jetonFaux() async throws {
        let (_, e, d) = try await Self.ouvrir()
        #expect(await d.jeton(String(repeating: "00", count: 32)))
        #expect(await attendreQue { e.liste.last == .fin(.jetonFaux) })
    }

    @Test func trameFausse() async throws {
        let (_, e, d) = try await Self.ouvrir()
        #expect(await d.envoyer(EnvoiPasseur.ligneJeton(Self.jeton) + Data("x\n".utf8)))
        #expect(await attendreQue { e.liste.last == .fin(.trameFausse) })
    }

    @Test func jsonIllisible() async throws {
        let (_, e, d) = try await Self.ouvrir()
        #expect(await d.envoyer(EnvoiPasseur.ligneJeton(Self.jeton) + Data("2\n[]".utf8)))
        #expect(await attendreQue { e.liste.last == .fin(.trameFausse) })
    }

    @Test func demonFerme() async throws {
        let (_, e, d) = try await Self.ouvrir()
        #expect(await d.jeton(Self.jeton))
        #expect(await attendreQue { e.liste.contains(.connecte) })
        d.fermer()
        #expect(await attendreQue { e.liste.last == .fin(.fermee) })
    }

    @Test func fermeAvantLeJeton() async throws {
        let (_, e, d) = try await Self.ouvrir()
        #expect(await d.envoyer(Data("7e7e".utf8)))
        d.fermer()
        #expect(await attendreQue { e.liste.last == .fin(.jetonFaux) })
    }

    @Test func coupure() async throws {
        let (_, e, d) = try await Self.ouvrir()
        #expect(await d.jeton(Self.jeton))
        #expect(await attendreQue { e.liste.contains(.connecte) })
        d.couper()
        #expect(await attendreQue {
            if case .fin(let f) = e.liste.last { f == .interrompue || f == .fermee } else { false }
        })
    }

    /// Une seule connexion : l'ecoute se ferme des la premiere.
    @Test func uneSeuleConnexion() async throws {
        let (a, e, d) = try await Self.ouvrir()
        #expect(await d.jeton(Self.jeton))
        #expect(await attendreQue { e.liste.contains(.connecte) })
        let port = try #require(e.port)
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await !FauxPasseur.envoyer(Data("x".utf8), port: port), "plus personne n'ecoute")
        a.fermer()
    }
}
```

- [ ] **Step 2 : lancer les tests, vérifier qu'ils échouent**

Run : `outils/tester.sh MaillageThreadTests/AbonnementPasseurTests`
Expected : échec de compilation (`AbonnementPasseur` inconnu).

- [ ] **Step 3 : écrire le code**

`MaillageThread/Noms/AbonnementPasseur.swift` :

```swift
import Foundation
import MaillageCoeur
import Network

/// Abonnement de l'app au demon Passeur Noms (spec du 12/10, sections 2 et 4.1) : une ecoute TCP sur 127.0.0.1
/// seulement, sur un port choisi par le systeme ; la premiere connexion est la seule acceptee (l'ecoute se ferme
/// aussitot). Le demon y ecrit le jeton (compare a temps constant), puis les deux cotes echangent des trames
/// (`EnvoiPasseur.LectureFlux`, `MessagePasseur`) ; un type inconnu est ignore, une trame mal formee ferme tout. Tout
/// sur la file principale. Le bac a sable de l'app exige `com.apple.security.network.server` pour ecouter.
@MainActor
final class AbonnementPasseur {
    enum Evenement: Equatable {
        /// L'ecoute est prete sur ce port : ouvrir l'URL `abonner`.
        case prete(UInt16)
        /// Le demon est connecte, son jeton accepte.
        case connecte
        case message(MessagePasseur)
        /// L'abonnement est fini ; l'ecoute et la connexion sont fermees.
        case fin(Fin)
    }

    enum Fin: Equatable {
        /// Premiere ligne autre que le jeton, ou connexion fermee avant sa fin.
        case jetonFaux
        /// Longueur illisible ou trop grande, ou JSON illisible.
        case trameFausse
        /// Le demon a ferme la connexion.
        case fermee
        /// Connexion coupee par une erreur.
        case interrompue
        /// Ecoute impossible : la cause.
        case ecoute(String)
    }

    /// Jeton attendu du demon, a usage unique.
    let jeton: String
    private var lecture: EnvoiPasseur.LectureFlux
    private var ecouteur: NWListener?
    private var connexion: NWConnection?
    private var suite: ((Evenement) -> Void)?
    private var pret = false
    private var connecte = false

    init(jeton: String) {
        self.jeton = jeton
        lecture = EnvoiPasseur.LectureFlux(jeton: jeton)
    }

    /// Ouvre l'ecoute ; `suite` recoit `.prete`, puis `.connecte`, les messages et `.fin`, sauf apres `fermer()`.
    func ouvrir(_ suite: @escaping (Evenement) -> Void) {
        self.suite = suite
        let parametres = NWParameters.tcp
        parametres.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let ecouteur: NWListener
        do {
            ecouteur = try NWListener(using: parametres)
        } catch {
            terminer(.ecoute(error.localizedDescription))
            return
        }
        self.ecouteur = ecouteur
        ecouteur.stateUpdateHandler = { [weak self] etat in
            MainActor.assumeIsolated { self?.changement(etat) }
        }
        ecouteur.newConnectionHandler = { [weak self] c in
            MainActor.assumeIsolated { self?.accepter(c) }
        }
        ecouteur.start(queue: .main)
    }

    /// Ferme l'ecoute et la connexion ; plus aucun evenement.
    func fermer() {
        suite = nil
        ecouteur?.cancel()
        ecouteur = nil
        connexion?.cancel()
        connexion = nil
    }

    /// Envoie un message au demon connecte ; ignore avant la connexion.
    func envoyer(_ m: MessagePasseur) {
        guard connecte, let c = connexion else { return }
        c.send(content: EnvoiPasseur.trame(m), completion: .contentProcessed { [weak self] erreur in
            guard erreur != nil else { return }
            MainActor.assumeIsolated { self?.terminer(.interrompue) }
        })
    }

    private func changement(_ etat: NWListener.State) {
        switch etat {
        case .ready:
            guard !pret else { return }
            guard let port = ecouteur?.port?.rawValue else {
                terminer(.ecoute(String(localized: "port inconnu")))
                return
            }
            pret = true
            suite?(.prete(port))
        case .waiting(let e), .failed(let e):
            terminer(.ecoute(e.localizedDescription))
        default:
            break
        }
    }

    /// Une seule connexion : l'ecoute se ferme des la premiere.
    private func accepter(_ c: NWConnection) {
        guard connexion == nil, suite != nil else {
            c.cancel()
            return
        }
        ecouteur?.cancel()
        ecouteur = nil
        connexion = c
        c.start(queue: .main)
        recevoir(c)
    }

    private func recevoir(_ c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] donnees, _, finie, erreur in
            MainActor.assumeIsolated {
                guard let self, self.connexion === c else { return }
                if let donnees, !donnees.isEmpty {
                    let issue = self.lecture.ajouter(donnees)
                    if !self.connecte, self.lecture.jetonAccepte {
                        self.connecte = true
                        self.suite?(.connecte)
                    }
                    for json in issue.trames {
                        // Un message a pu fermer l'abonnement.
                        guard self.connexion === c else { return }
                        switch MessagePasseur.lire(json) {
                        case .message(let m): self.suite?(.message(m))
                        case .ignore: break
                        case .illisible:
                            self.terminer(.trameFausse)
                            return
                        }
                    }
                    switch issue.erreur {
                    case .jetonFaux?:
                        self.terminer(.jetonFaux)
                        return
                    case .trameFausse?:
                        self.terminer(.trameFausse)
                        return
                    case nil:
                        break
                    }
                }
                if erreur != nil {
                    self.terminer(.interrompue)
                    return
                }
                if finie {
                    self.terminer(self.connecte ? .fermee : .jetonFaux)
                    return
                }
                self.recevoir(c)
            }
        }
    }

    private func terminer(_ fin: Fin) {
        guard let suite else { return }
        fermer()
        suite(.fin(fin))
    }
}
```

- [ ] **Step 4 : lancer les tests, vérifier qu'ils passent**

Run : `outils/tester.sh MaillageThreadTests/AbonnementPasseurTests`
Expected : PASS.

- [ ] **Step 5 : commit**

```bash
git add MaillageThread/Noms/AbonnementPasseur.swift MaillageThreadTests/AbonnementPasseurTests.swift
git commit -m "App : abonnement au demon Passeur Noms sur la boucle locale

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11 : `NomsInternes` en client abonné

**Files:**
- Modify: `MaillageThread/Noms/NomsInternes.swift` (réécrit)
- Delete: `MaillageThread/Noms/EcouteReleve.swift` (`git rm`)
- Modify: `MaillageThreadTests/NomsInternesTests.swift`
- Modify (appels) : `MaillageThread/Vues/MenuBarre.swift`, `MaillageThread/Vues/FenetreReglages.swift`, `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`

**Interfaces:**
- Consumes : `AbonnementPasseur`, `FauxDemon`, `attendreQue` (tâche 10) ; `EnvoiPasseur.Cible(…, demande: .abonner)`.
- Produces (pour la tâche 12) : `NomsInternes` avec `noms`, `probleme`, `connecte: Bool`, `etat: EtatPasseur?`, `releveEnCours: Bool`, `identification: NomsInternes.Identification?` (`accessoire: String`, `texte: String`), `tentative: Int` ; `init(cache:delai:attentes:lanceur:)` ; `demarrer()`, `abonner()`, `relire()`, `identifier(accessoire:)`, `reglerOuvertureSession(_:)`, `integrer(_:)` ; statiques `retenir`, `fichierCache`, `lancerPasseurDuMac`, `problemeInstallation(_:)`, `attente(apres:dans:)`, `texte(_ fin:)`, `texte(_ reponse:)`, `texteDemon(connecte:etat:)`, `profilBientotExpire(_:maintenant:)`, `interrupteurActif(connecte:etat:)`, `cleProtocole`, `reabonnements`, `preavisProfil`. Supprimés : `lancerPasseur`, `rafraichirSiAncien`, `doitRafraichir`, `aRafraichir`, `fraicheur`, `validite`, `estAncien`, `derniereDemande`, `NomsInternes.Fin`.

- [ ] **Step 1 : écrire les tests qui échouent**

Dans `MaillageThreadTests/NomsInternesTests.swift` :
- **supprimer** les tests `ancien`, `aRafraichir`, `sansMemoire`, `bonJeton`, `refusDeMaison`, `mauvaisJeton`, `longueurFausse`, `connexionCoupee`, `jsonIllisible`, `delaiDepasse`, `lancementRefuse`, `uneSeuleEcoute`, `ecouteFermeeSiNomsInternesDisparait`, `uneSeuleConnexion`, `deuxConnexionsEnSimultane` ; les aides `lanceur(_:probleme:trame:)`, `bonneTrame`, `releve`, `attendre`, `ecouteFermee`, `occuper` ; les textes `jetonFaux`, `longueurFausse`, `interrompu` ;
- **garder** `FauxPasseur`, `LancementsPasseur`, `lanceurInterdit`, `noms`, `cache`, `cible(_:fois:)`, `refus`, et les tests `echecGardeLesNoms`, `memoireDesNoms`, `zonesDansLesReglages` ;
- renommer la suite en `@Suite("Noms de Maison : client du demon Passeur Noms", .timeLimit(.minutes(1)))` ;
- ajouter :

```swift
    /// Faux lanceur : note chaque lancement ; `probleme` : le lancement echoue.
    static func lanceur(_ lancements: LancementsPasseur, probleme: String? = nil) -> NomsInternes.Lanceur {
        { cible in
            lancements.noter(cible)
            return probleme
        }
    }

    static func json(_ n: NomsMaison) throws -> Data { try n.donnees() }

    /// Un client abonne a un faux demon connecte : le client, le demon et le fichier des noms.
    static func connecte(attentes: [Duration] = [.milliseconds(20)])
        async throws -> (NomsInternes, FauxDemon, LancementsPasseur, URL) {
        let cache = Self.cache()
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: cache, attentes: attentes, lanceur: Self.lanceur(lancements))
        n.demarrer()
        let cible = try #require(await Self.cible(lancements))
        let d = try #require(FauxDemon(port: cible.port))
        #expect(await d.jeton(cible.jeton))
        #expect(await attendreQue { n.connecte })
        return (n, d, lancements, cache)
    }

    /// Au demarrage : l'URL `abonner` ; puis `etat` et les releves successifs, gardes dans `noms.json`.
    @Test func abonnementEtReleves() async throws {
        let (n, d, lancements, cache) = try await Self.connecte()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        #expect(lancements.cible?.demande == .abonner)
        #expect(lancements.cible?.jeton.count == 64)
        let e = EtatPasseur(version: "2.0", acces: .autorise, ouvertureSession: .inactive, profilExpire: nil)
        #expect(await d.message(.etat(e)))
        #expect(await attendreQue { n.etat == e })
        #expect(await d.message(.releve(try Self.json(Self.noms()))))
        #expect(await attendreQue { n.noms == Self.noms() })
        #expect(await d.message(.releve(try Self.json(Self.noms(nom: "Pont")))))
        #expect(await attendreQue { n.noms == Self.noms(nom: "Pont") })
        #expect(NomsInternes(cache: cache, lanceur: NomsInternes.lanceurInterdit).noms == Self.noms(nom: "Pont"))
        #expect(n.tentative == 0)
    }

    /// `relire`, `identifier` et `ouvertureSession` partent vers le demon ; la reponse a « Identifier » s'affiche pour
    /// son accessoire.
    @Test func commandesEnvoyees() async throws {
        let (n, d, _, cache) = try await Self.connecte()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        n.relire()
        #expect(n.releveEnCours)
        n.identifier(accessoire: "A")
        n.reglerOuvertureSession(true)
        #expect(await attendreQue { d.messages.count == 3 })
        #expect(d.messages == [.relire, .identifier(demande: 1, accessoire: "A"), .ouvertureSession(actif: true)])
        #expect(await d.message(.identifie(ReponseIdentifier(demande: 1, ok: true))))
        #expect(await attendreQue { n.identification != nil })
        #expect(n.identification == NomsInternes.Identification(accessoire: "A",
                                                                texte: String(localized: "Identification demandée")))
        #expect(await d.message(.releve(try Self.json(Self.noms()))))
        #expect(await attendreQue { !n.releveEnCours })
    }

    /// Une reponse a une demande plus ancienne que la derniere est ignoree.
    @Test func reponseIdentifierEnRetard() async throws {
        let (n, d, _, cache) = try await Self.connecte()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        n.identifier(accessoire: "A")
        n.identifier(accessoire: "B")
        #expect(await d.message(.identifie(ReponseIdentifier(demande: 1, ok: true))))
        #expect(await d.message(.identifie(ReponseIdentifier(demande: 2, ok: false, erreur: ReponseIdentifier.nonIdentifiable))))
        #expect(await attendreQue { n.identification != nil })
        #expect(n.identification?.accessoire == "B")
        #expect(n.identification?.texte == String(localized: "Cet accessoire ne sait pas s'identifier"))
    }

    /// Le demon ferme : deconnecte, le probleme dit, et un nouvel abonnement (nouveau jeton) apres l'attente.
    @Test func reabonnementApresFermeture() async throws {
        let (n, d, lancements, cache) = try await Self.connecte()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let premier = try #require(lancements.cible)
        d.fermer()
        #expect(await attendreQue { !n.connecte })
        #expect(n.probleme == String(localized: "Passeur Noms s'est déconnecté."))
        let second = try #require(await Self.cible(lancements, fois: 2))
        #expect(second.jeton != premier.jeton)
        #expect(second.demande == .abonner)
    }

    /// Lancement refuse : le probleme, puis d'autres essais ; un demon connecte remet le compte a zero.
    @Test func essaisApresUnEchec() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let introuvable = "Passeur Noms introuvable"
        let n = NomsInternes(cache: cache, attentes: [.milliseconds(10)], lanceur: Self.lanceur(lancements, probleme: introuvable))
        n.demarrer()
        _ = await Self.cible(lancements, fois: 3)
        #expect(lancements.tous.count >= 3)
        #expect(n.probleme == introuvable)
        #expect(n.tentative >= 2)
    }

    /// Les attentes avant de se reabonner : 5 s, 10 s, 30 s, puis toutes les minutes.
    @Test func attentesCroissantes() {
        let a = NomsInternes.reabonnements
        #expect(a == [.seconds(5), .seconds(10), .seconds(30), .seconds(60)])
        #expect(NomsInternes.attente(apres: 0, dans: a) == .seconds(5))
        #expect(NomsInternes.attente(apres: 1, dans: a) == .seconds(10))
        #expect(NomsInternes.attente(apres: 2, dans: a) == .seconds(30))
        #expect(NomsInternes.attente(apres: 3, dans: a) == .seconds(60))
        #expect(NomsInternes.attente(apres: 40, dans: a) == .seconds(60))
    }

    /// Aucun demon dans le delai : le probleme, puis un nouvel essai.
    @Test func delaiSansDemon() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: cache, delai: .milliseconds(100), attentes: [.milliseconds(10)],
                             lanceur: Self.lanceur(lancements))
        n.demarrer()
        _ = await Self.cible(lancements, fois: 2)
        #expect(n.probleme == String(localized: "Passeur Noms ne s'est pas connecté en 2 minutes."))
    }

    /// Un releve illisible garde les noms et le dit.
    @Test func releveIllisible() async throws {
        let (n, d, _, cache) = try await Self.connecte()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        #expect(await d.message(.releve(try Self.json(Self.noms()))))
        #expect(await attendreQue { n.noms != nil })
        #expect(await d.message(.releve(Data(#"{"x":1}"#.utf8))))
        #expect(await attendreQue { n.probleme != nil })
        #expect(n.noms == Self.noms())
    }

    /// Sans memoire (demo, tests) : rien ne se lance, ni au demarrage ni sur demande.
    @Test func sansMemoire() {
        let n = NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit)
        n.demarrer()
        n.relire()
        n.identifier(accessoire: "A")
        #expect(!n.connecte && !n.releveEnCours)
    }

    /// Sans demon connecte, « Rafraichir depuis Maison » relance l'abonnement tout de suite, sans attendre.
    @Test func relireSansDemon() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: cache, attentes: [.seconds(60)], lanceur: Self.lanceur(lancements, probleme: "absent"))
        n.demarrer()
        _ = await Self.cible(lancements)
        #expect(await attendreQue { n.probleme == "absent" })
        n.relire()
        #expect(await Self.cible(lancements, fois: 2) != nil)
        #expect(lancements.tous.count == 2)
    }

    /// L'ancien passeur (app iOS, sans la cle du protocole) n'est pas lance : il ne connait pas `abonner`.
    @Test func problemeInstallation() {
        let ancienne = String(localized: "Passeur Noms est l'ancienne version : relance outils/passeur.sh.")
        #expect(NomsInternes.problemeInstallation(nil) == ancienne)
        #expect(NomsInternes.problemeInstallation(["CFBundleIdentifier": "fr.djoko.maillage.passeur"]) == ancienne)
        #expect(NomsInternes.problemeInstallation([NomsInternes.cleProtocole: 1]) == nil)
    }

    /// Les textes des fins d'abonnement.
    @Test func textesDesFins() {
        #expect(NomsInternes.texte(AbonnementPasseur.Fin.jetonFaux) == String(localized: "Connexion de Passeur Noms refusée : jeton faux."))
        #expect(NomsInternes.texte(AbonnementPasseur.Fin.trameFausse) == String(localized: "Message illisible de Passeur Noms : connexion fermée."))
        #expect(NomsInternes.texte(AbonnementPasseur.Fin.interrompue) == String(localized: "Connexion avec Passeur Noms coupée."))
        #expect(NomsInternes.texte(AbonnementPasseur.Fin.ecoute("occupé"))
                == String(localized: "Écoute de Passeur Noms impossible : \("occupé")"))
    }
```

- [ ] **Step 2 : lancer les tests, vérifier qu'ils échouent**

Run : `outils/tester.sh MaillageThreadTests/NomsInternesTests`
Expected : échec de compilation (`connecte`, `attentes`, `relire`… inconnus).

- [ ] **Step 3 : réécrire `NomsInternes.swift`**

Remplacer tout le fichier par :

```swift
import AppKit
import Foundation
import MaillageCoeur
import Observation

/// Noms de Maison, servis par le demon Passeur Noms (spec du 12/10, section 4.1) et gardes dans le conteneur de l'app
/// (`noms.json`), sans dossier a choisir. Au lancement en mode direct, l'app s'abonne : une ecoute sur 127.0.0.1
/// (`AbonnementPasseur`), un jeton a usage unique et l'URL `maillage-passeur://abonner?port=<port>&jeton=<jeton>`,
/// ouverte sans activation. Le demon envoie `etat` et `releve` a la connexion, puis a chaque changement dans Maison ;
/// l'app lui envoie `relire`, `identifier` et `ouvertureSession`. Connexion perdue, ou aucun demon dans le delai :
/// nouvel abonnement apres 5 s, 10 s, 30 s, puis toutes les minutes.
/// Le dernier releve valide est garde : un echec ne l'efface jamais, il se dit dans `probleme`.
@MainActor
@Observable
final class NomsInternes {
    /// Ouvre le demon avec cette cible (son URL) ; nil s'il est ouvert, sinon le probleme a montrer.
    typealias Lanceur = @MainActor (_ cible: EnvoiPasseur.Cible) async -> String?

    /// Resultat d'une identification, montre quelques secondes dans la fiche de l'appareil.
    struct Identification: Equatable {
        /// L'`id` de l'accessoire de Maison.
        var accessoire: String
        var texte: String
    }

    nonisolated static let fichier = "noms.json"
    nonisolated static let idPasseur = "fr.djoko.maillage.passeur"
    /// Cle de l'Info.plist du demon : la version du protocole qu'il parle. Absente : l'ancien passeur (app iOS), qui ne
    /// connait pas `abonner`.
    nonisolated static let cleProtocole = "MaillagePasseurProtocole"
    /// Premiere attente d'un demon : le temps d'une demande d'acces a Maison. Le texte de `abonner` dit "2 minutes" en
    /// dur : a changer avec cette valeur (le catalogue aussi).
    nonisolated static let delaiParDefaut: Duration = .seconds(120)
    /// Attentes avant de se reabonner ; la derniere se repete.
    nonisolated static let reabonnements: [Duration] = [.seconds(5), .seconds(10), .seconds(30), .seconds(60)]
    /// Avertissement avant l'expiration du profil du demon.
    nonisolated static let preavisProfil: TimeInterval = 30 * 24 * 3600
    /// Duree d'affichage du resultat d'une identification.
    nonisolated static let dureeIdentification: Duration = .seconds(4)

    /// Dernier releve valide.
    private(set) var noms: NomsMaison?
    /// Dernier probleme : demon introuvable ou ancien, lancement refuse, aucun demon dans le delai, connexion perdue,
    /// releve refuse ou illisible, acces a Maison refuse, ecriture impossible.
    private(set) var probleme: String?
    /// Le demon est connecte (jeton accepte).
    private(set) var connecte = false
    /// Dernier `etat` du demon ; garde apres une deconnexion, mais les Reglages ne le lisent que connecte.
    private(set) var etat: EtatPasseur?
    /// `relire` envoye, releve pas encore recu.
    private(set) var releveEnCours = false
    /// Derniere reponse a « Identifier », effacee apres `dureeIdentification`.
    private(set) var identification: Identification?
    /// Echecs d'abonnement depuis la derniere connexion : choisit l'attente suivante.
    private(set) var tentative = 0
    /// Appele a chaque changement des noms retenus.
    @ObservationIgnored var surNoms: ((NomsMaison?) -> Void)?

    @ObservationIgnored private let cache: URL?
    @ObservationIgnored private let delai: Duration
    @ObservationIgnored private let attentes: [Duration]
    @ObservationIgnored private let lanceur: Lanceur
    @ObservationIgnored private var abonnement: AbonnementPasseur?
    @ObservationIgnored private var minuterie: Task<Void, Never>?
    @ObservationIgnored private var reprise: Task<Void, Never>?
    @ObservationIgnored private var effacement: Task<Void, Never>?
    /// Numero de la derniere demande d'identification, et son accessoire.
    @ObservationIgnored private var demande = 0
    @ObservationIgnored private var enIdentification: String?

    /// `cache` : le `noms.json` de l'app ; nil (mode demo, tests) : aucun releve lu, ecrit ni demande. `lanceur` :
    /// `lancerPasseurDuMac` pour l'app, un faux dans les tests. Il n'a pas de valeur par defaut : un test qui
    /// l'oublierait lancerait le vrai demon.
    init(cache: URL?, delai: Duration = NomsInternes.delaiParDefaut, attentes: [Duration] = NomsInternes.reabonnements,
         lanceur: @escaping Lanceur) {
        self.cache = cache
        self.delai = delai
        self.attentes = attentes.isEmpty ? NomsInternes.reabonnements : attentes
        self.lanceur = lanceur
        noms = cache.flatMap { try? NomsMaison.lire(Data(contentsOf: $0)) }
    }

    /// `noms.json` dans le dossier de l'app, a cote de `identites-routeurs.json` ; nil en demo et sous les tests.
    static func fichierCache(demo: Bool, sousTests: Bool) -> URL? {
        demo || sousTests ? nil : Surveillance.dossierParDefaut.appendingPathComponent(fichier)
    }

    /// Donne les noms gardes et s'abonne au demon.
    func demarrer() {
        surNoms?(noms)
        abonner()
    }

    /// Ouvre l'ecoute, puis l'URL `abonner` avec son port et un jeton neuf. Un abonnement a la fois ; jamais sans
    /// memoire.
    func abonner() {
        guard cache != nil, abonnement == nil else { return }
        reprise?.cancel()
        reprise = nil
        let a = AbonnementPasseur(jeton: EnvoiPasseur.nouveauJeton())
        abonnement = a
        minuterie = Task { [weak self, delai] in
            try? await Task.sleep(for: delai)
            guard !Task.isCancelled else { return }
            // Sans NomsInternes, personne ne finira cet abonnement : on ferme l'ecoute.
            guard let self else {
                a.fermer()
                return
            }
            // "2 minutes" : `delaiParDefaut` (120 s), en dur dans le texte.
            self.finir(a, probleme: String(localized: "Passeur Noms ne s'est pas connecté en 2 minutes."))
        }
        a.ouvrir { [weak self] e in self?.surAbonnement(a, e) }
    }

    /// « Rafraichir depuis Maison » : `relire` au demon connecte (releve et batteries) ; sans demon, un nouvel
    /// abonnement tout de suite.
    func relire() {
        guard cache != nil else { return }
        if connecte, let a = abonnement {
            releveEnCours = true
            a.envoyer(.relire)
        } else if abonnement == nil {
            tentative = 0
            abonner()
        }
    }

    /// « Identifier » : le demon appelle `identify()` sur cet accessoire de Maison (son `id`).
    func identifier(accessoire id: String) {
        guard connecte, let a = abonnement else { return }
        demande += 1
        enIdentification = id
        a.envoyer(.identifier(demande: demande, accessoire: id))
    }

    /// L'interrupteur des Reglages : inscrit ou desinscrit le demon a l'ouverture de session.
    func reglerOuvertureSession(_ actif: Bool) {
        guard connecte, let a = abonnement else { return }
        a.envoyer(.ouvertureSession(actif: actif))
    }

    private func surAbonnement(_ a: AbonnementPasseur, _ e: AbonnementPasseur.Evenement) {
        guard abonnement === a else { return }
        switch e {
        case .prete(let port):
            let cible = EnvoiPasseur.Cible(port: port, jeton: a.jeton, demande: .abonner)
            Task { [weak self] in
                guard let self, let p = await self.lanceur(cible) else { return }
                self.finir(a, probleme: p)
            }
        case .connecte:
            minuterie?.cancel()
            minuterie = nil
            connecte = true
            tentative = 0
            probleme = nil
        case .message(let m):
            recevoir(m)
        case .fin(let f):
            finir(a, probleme: Self.texte(f))
        }
    }

    private func recevoir(_ m: MessagePasseur) {
        switch m {
        case .etat(let e):
            etat = e
        case .releve(let json):
            releveEnCours = false
            do {
                integrer(try NomsMaison.lire(json))
            } catch {
                probleme = String(localized: "Relevé de Maison illisible : \(error.localizedDescription)")
            }
        case .identifie(let r):
            guard r.demande == demande, let id = enIdentification else { return }
            montrer(Identification(accessoire: id, texte: Self.texte(r)))
        case .relire, .identifier, .ouvertureSession:
            // Messages de l'app vers le demon : ignores dans l'autre sens.
            break
        }
    }

    /// Ferme l'abonnement, retient le probleme et planifie le suivant.
    private func finir(_ a: AbonnementPasseur, probleme p: String) {
        guard abonnement === a else { return }
        abonnement = nil
        a.fermer()
        minuterie?.cancel()
        minuterie = nil
        connecte = false
        releveEnCours = false
        probleme = p
        let attente = Self.attente(apres: tentative, dans: attentes)
        tentative += 1
        reprise = Task { [weak self] in
            try? await Task.sleep(for: attente)
            guard !Task.isCancelled else { return }
            self?.abonner()
        }
    }

    private func montrer(_ i: Identification) {
        identification = i
        effacement?.cancel()
        effacement = Task { [weak self] in
            try? await Task.sleep(for: Self.dureeIdentification)
            guard !Task.isCancelled else { return }
            self?.identification = nil
        }
    }

    /// Retient un releve recu : les noms s'il est reussi, sinon le probleme ; les noms retenus sont ecrits dans le
    /// conteneur, d'un coup (ecriture atomique).
    func integrer(_ n: NomsMaison) {
        let (garde, p) = Self.retenir(n, ancien: noms)
        probleme = p
        guard garde != noms else { return }
        noms = garde
        if let garde, let cache {
            do {
                try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
                try garde.donnees().write(to: cache, options: .atomic)
            } catch {
                probleme = error.localizedDescription
            }
        }
        surNoms?(garde)
    }

    /// Lanceur reel : Passeur Noms, installe par outils/passeur.sh, ouvert sans activation avec l'URL de la cible. Pas
    /// d'arguments de lancement : macOS retire ceux que passe une app du bac a sable (verifie le 30/09).
    static func lancerPasseurDuMac(_ cible: EnvoiPasseur.Cible) async -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: idPasseur) else {
            return String(localized: "Passeur Noms introuvable : lance outils/passeur.sh.")
        }
        if let p = problemeInstallation(Bundle(url: url)?.infoDictionary) { return p }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        do {
            _ = try await NSWorkspace.shared.open([cible.url], withApplicationAt: url, configuration: configuration)
            return nil
        } catch {
            // Cause la plus probable : le profil de developpement du demon a expire (un an).
            return String(localized: "\(error.localizedDescription) (profil du passeur expiré ? relance outils/passeur.sh)")
        }
    }

    /// L'ancien passeur (app iOS, sans `cleProtocole`) ne connait pas `abonner` et ouvrirait sa fenetre a chaque essai :
    /// il n'est pas lance.
    nonisolated static func problemeInstallation(_ info: [String: Any]?) -> String? {
        (info?[cleProtocole] as? Int) != nil
            ? nil : String(localized: "Passeur Noms est l'ancienne version : relance outils/passeur.sh.")
    }

    /// L'attente avant le prochain abonnement, apres `tentative` echecs.
    nonisolated static func attente(apres tentative: Int, dans attentes: [Duration]) -> Duration {
        attentes[min(max(tentative, 0), attentes.count - 1)]
    }

    nonisolated static func texte(_ f: AbonnementPasseur.Fin) -> String {
        switch f {
        case .jetonFaux: String(localized: "Connexion de Passeur Noms refusée : jeton faux.")
        case .trameFausse: String(localized: "Message illisible de Passeur Noms : connexion fermée.")
        case .fermee: String(localized: "Passeur Noms s'est déconnecté.")
        case .interrompue: String(localized: "Connexion avec Passeur Noms coupée.")
        case .ecoute(let cause): String(localized: "Écoute de Passeur Noms impossible : \(cause)")
        }
    }

    nonisolated static func texte(_ r: ReponseIdentifier) -> String {
        if r.ok { return String(localized: "Identification demandée") }
        switch r.erreur {
        case ReponseIdentifier.inconnu?: return String(localized: "Accessoire introuvable dans Maison")
        case ReponseIdentifier.nonIdentifiable?: return String(localized: "Cet accessoire ne sait pas s'identifier")
        case let e?: return String(localized: "Identification impossible : \(e)")
        case nil: return String(localized: "Identification impossible")
        }
    }

    /// Reglages › Maison : l'etat du demon.
    nonisolated static func texteDemon(connecte: Bool, etat: EtatPasseur?) -> String {
        guard connecte, let e = etat else { return String(localized: "non connecté") }
        let acces = switch e.acces {
        case .autorise: String(localized: "accès à Maison autorisé")
        case .refuse: String(localized: "accès à Maison refusé")
        case .attente: String(localized: "accès à Maison en attente")
        }
        return String(localized: "connecté · version \(e.version) · \(acces)")
    }

    /// Le profil du demon expire dans 30 jours ou moins, ou a expire.
    nonisolated static func profilBientotExpire(_ e: EtatPasseur?, maintenant: Date) -> Bool {
        guard let fin = e?.profilExpire else { return false }
        return fin.timeIntervalSince(maintenant) <= preavisProfil
    }

    /// L'interrupteur d'ouverture de session : actif avec un demon connecte qui a donne son etat. (`indisponible`,
    /// `notFound` de SMAppService, est l'etat d'un demon jamais inscrit : l'inscription reste possible.)
    nonisolated static func interrupteurActif(connecte: Bool, etat: EtatPasseur?) -> Bool {
        connecte && etat != nil
    }

    /// Un releve reussi remplace les noms ; un echec les garde et dit pourquoi, avec les textes de l'app : le message
    /// du passeur (en francais seulement) n'est que le detail d'une erreur.
    nonisolated static func retenir(_ nouveau: NomsMaison, ancien: NomsMaison?) -> (NomsMaison?, String?) {
        switch nouveau.statut {
        case .ok: (nouveau, nil)
        case .refuse:
            (ancien, String(localized: "Accès à Maison refusé au passeur : Réglages Système › Confidentialité et sécurité › Maison."))
        case .indisponible: (ancien, String(localized: "HomeKit indisponible pour le passeur."))
        case .erreur:
            (ancien, nouveau.message.map { String(localized: "Le passeur a échoué : \($0)") }
                ?? String(localized: "Le passeur a échoué."))
        }
    }
}
```

Puis `git rm MaillageThread/Noms/EcouteReleve.swift`.

- [ ] **Step 4 : les appels**

- `MaillageThread/Vues/MenuBarre.swift` : `Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }` devient `Button("Rafraîchir depuis Maison") { nomsMaison.relire() }` (le `.disabled(nomsMaison.releveEnCours)` reste).
- `MaillageThread/Vues/Pieces/MorceauxFenetre.swift` : dans le bouton de rafraîchissement, `nomsMaison.lancerPasseur()` devient `nomsMaison.relire()`.
- `MaillageThread/Vues/Pieces/FenetrePieces.swift` : supprimer le modificateur

```swift
        .task {
            // Batteries de Maison a jour tant que la vue est ouverte.
            while !Task.isCancelled {
                nomsMaison.rafraichirSiAncien()
                try? await Task.sleep(for: .seconds(3600))
            }
        }
```

  (le démon relit les batteries toutes les heures) ; dans `BandeauSansPieces`, `nomsMaison.lancerPasseur()` devient `nomsMaison.relire()`. Si `nomsMaison` n'est plus utilisé dans la structure `FenetrePieces`, retirer sa déclaration `@Environment(NomsInternes.self)` de cette structure seulement.
- `MaillageThread/Vues/FenetreReglages.swift` : dans `nomsDeMaison`, supprimer le bloc `if NomsInternes.estAncien(n, maintenant: .now) { … }` et remplacer `nomsMaison.lancerPasseur()` par `nomsMaison.relire()` (la tâche 12 réécrit la section).

Puis vérifier qu'il ne reste rien :

```bash
grep -rn "lancerPasseur\|rafraichirSiAncien\|estAncien\|EcouteReleve\|aRafraichir\|doitRafraichir" MaillageThread MaillageThreadTests
```

Expected : aucune ligne (hors commentaires à mettre à jour s'il y en a).

- [ ] **Step 5 : lancer les tests, vérifier qu'ils passent**

Run : `outils/tester.sh MaillageThreadTests MaillageCoeurTests/EnvoiPasseurTests`
Expected : PASS, sauf éventuellement `CataloguesTests` (textes à synchroniser à la tâche 12).

- [ ] **Step 6 : commit**

```bash
git add MaillageThread/Noms/NomsInternes.swift MaillageThreadTests/NomsInternesTests.swift \
  MaillageThread/Vues/MenuBarre.swift MaillageThread/Vues/FenetreReglages.swift \
  MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/Pieces/MorceauxFenetre.swift
git commit -m "App : noms de Maison par abonnement au demon, reabonnement, Identifier et ouverture de session

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(`git rm` a indexé la suppression d'`EcouteReleve.swift`.)

---

### Task 12 : Réglages › Maison, bouton « Identifier », textes

**Files:**
- Modify: `MaillageThread/Vues/FenetreReglages.swift` (`nomsDeMaison`)
- Create: `MaillageThread/Vues/Pieces/BoutonIdentifier.swift`
- Modify: `MaillageThread/Vues/Pieces/FicheNoeud.swift` (`boutonsIdentite`)
- Create: `MaillageThreadTests/ReglagesDemonTests.swift`
- Create: `outils/traductions/demon.json` ; Modify: `MaillageThread/Ressources/Localizable.xcstrings` (par les outils)

**Interfaces:**
- Consumes : `NomsInternes.connecte`, `etat`, `identification`, `relire()`, `identifier(accessoire:)`, `reglerOuvertureSession(_:)`, `texteDemon`, `profilBientotExpire`, `interrupteurActif` (tâche 11) ; `Surveillance.accessoire(_:)`, `surveillance.appareil(_:)`, `.boutonDeFiche()`.
- Produces : `struct BoutonIdentifier: View` (`accessoire: AccessoireMaison`), `static func actif(connecte: Bool, accessoire: AccessoireMaison) -> Bool`.

- [ ] **Step 1 : écrire les tests qui échouent**

`MaillageThreadTests/ReglagesDemonTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

/// Ce que montrent les Reglages et la fiche selon l'etat du demon (spec, section 4.1).
@Suite("Reglages du demon et bouton Identifier")
struct ReglagesDemonTests {
    static let maintenant = Date(timeIntervalSince1970: 1_800_000_000)

    static func etat(_ ouverture: EtatPasseur.Ouverture = .inactive, acces: EtatPasseur.Acces = .autorise,
                     profil: Date? = nil) -> EtatPasseur {
        EtatPasseur(version: "2.0", acces: acces, ouvertureSession: ouverture, profilExpire: profil)
    }

    @Test func texteDuDemon() {
        #expect(NomsInternes.texteDemon(connecte: false, etat: Self.etat()) == String(localized: "non connecté"))
        #expect(NomsInternes.texteDemon(connecte: true, etat: nil) == String(localized: "non connecté"))
        #expect(NomsInternes.texteDemon(connecte: true, etat: Self.etat())
                == String(localized: "connecté · version \("2.0") · \(String(localized: "accès à Maison autorisé"))"))
        #expect(NomsInternes.texteDemon(connecte: true, etat: Self.etat(acces: .refuse)).contains(String(localized: "accès à Maison refusé")))
    }

    /// Avertissement 30 jours avant l'expiration du profil, et apres.
    @Test func profil() {
        let jour: TimeInterval = 86_400
        #expect(!NomsInternes.profilBientotExpire(nil, maintenant: Self.maintenant))
        #expect(!NomsInternes.profilBientotExpire(Self.etat(), maintenant: Self.maintenant), "profil illisible")
        #expect(!NomsInternes.profilBientotExpire(Self.etat(profil: Self.maintenant + 31 * jour), maintenant: Self.maintenant))
        #expect(NomsInternes.profilBientotExpire(Self.etat(profil: Self.maintenant + 30 * jour), maintenant: Self.maintenant))
        #expect(NomsInternes.profilBientotExpire(Self.etat(profil: Self.maintenant - jour), maintenant: Self.maintenant))
    }

    /// L'interrupteur : grise sans demon connecte ; actif meme `indisponible` (demon jamais inscrit).
    @Test func interrupteur() {
        #expect(!NomsInternes.interrupteurActif(connecte: false, etat: Self.etat()))
        #expect(!NomsInternes.interrupteurActif(connecte: true, etat: nil))
        #expect(NomsInternes.interrupteurActif(connecte: true, etat: Self.etat(.indisponible)))
        #expect(NomsInternes.interrupteurActif(connecte: true, etat: Self.etat(.aApprouver)))
    }

    /// « Identifier » : grise sans demon connecte, ou pour un accessoire sans `id`.
    @Test func boutonIdentifier() {
        let avec = AccessoireMaison(nom: "Capteur", id: "8D3C2A10-0000-4000-8000-000000000001")
        let sans = AccessoireMaison(nom: "Capteur")
        #expect(BoutonIdentifier.actif(connecte: true, accessoire: avec))
        #expect(!BoutonIdentifier.actif(connecte: false, accessoire: avec))
        #expect(!BoutonIdentifier.actif(connecte: true, accessoire: sans))
    }

    @Test func textesDIdentification() {
        #expect(NomsInternes.texte(ReponseIdentifier(demande: 1, ok: true)) == String(localized: "Identification demandée"))
        #expect(NomsInternes.texte(ReponseIdentifier(demande: 1, ok: false, erreur: ReponseIdentifier.inconnu))
                == String(localized: "Accessoire introuvable dans Maison"))
        #expect(NomsInternes.texte(ReponseIdentifier(demande: 1, ok: false, erreur: "hors de portée"))
                == String(localized: "Identification impossible : \("hors de portée")"))
        #expect(NomsInternes.texte(ReponseIdentifier(demande: 1, ok: false)) == String(localized: "Identification impossible"))
    }
}
```

Run : `outils/tester.sh MaillageThreadTests/ReglagesDemonTests`
Expected : échec de compilation (`BoutonIdentifier` inconnu).

- [ ] **Step 2 : le bouton « Identifier »**

`MaillageThread/Vues/Pieces/BoutonIdentifier.swift` :

```swift
import MaillageCoeur
import SwiftUI

/// « Identifier », dans la fiche d'un appareil relie a un accessoire de Maison (par son noeud ou par une association a
/// la main) : le demon Passeur Noms appelle `identify()` sur l'accessoire, qui clignote ou emet un son. Grise sans
/// demon connecte, ou pour un accessoire sans `id` (releve d'avant le demon). Le resultat s'affiche quelques secondes
/// dessous. Les noms de Maison sont facultatifs dans l'environnement : les mesures de la fiche (`CapturesPieces`) et
/// plusieurs tests la rendent sans eux ; le bouton est alors grise.
struct BoutonIdentifier: View {
    @Environment(NomsInternes.self) private var nomsMaison: NomsInternes?
    let accessoire: AccessoireMaison

    static func actif(connecte: Bool, accessoire: AccessoireMaison) -> Bool {
        connecte && accessoire.id != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button("Identifier") {
                if let id = accessoire.id { nomsMaison?.identifier(accessoire: id) }
            }
            .boutonDeFiche()
            .disabled(!Self.actif(connecte: nomsMaison?.connecte == true, accessoire: accessoire))
            if let i = nomsMaison?.identification, i.accessoire == accessoire.id {
                Text(i.texte).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
```

Dans `FicheNoeud.swift`, `boutonsIdentite`, dans le bloc `if let a = surveillance.appareil(id) { … }`, après le `if surveillance.associeALaMain(a) { … } else if MenuAssocier.propose(a, dans: surveillance) { … }`, ajouter :

```swift
                if let accessoire = surveillance.accessoire(a) {
                    BoutonIdentifier(accessoire: accessoire)
                }
```

et compléter le commentaire de `boutonsIdentite` : « …, et « Identifier » pour un appareil relié à un accessoire de Maison (`BoutonIdentifier`) ». (Écrire ce commentaire sans accents, comme le reste du fichier.)

- [ ] **Step 3 : Réglages › Maison**

Dans `FenetreReglages.swift`, remplacer la propriété `nomsDeMaison` entière par :

```swift
    /// Onglet Maison : le demon Passeur Noms (etat, ouverture de session, profil), puis les noms, pieces et zones qu'il
    /// a releves.
    private var nomsDeMaison: some View {
        Group {
            Section("Passeur Noms") {
                LabeledContent("État", value: NomsInternes.texteDemon(connecte: nomsMaison.connecte, etat: nomsMaison.etat))
                Toggle("Ouvrir Passeur Noms à l'ouverture de session", isOn: Binding(
                    get: { nomsMaison.etat?.ouvertureSession == .active },
                    set: { nomsMaison.reglerOuvertureSession($0) }))
                    .disabled(!NomsInternes.interrupteurActif(connecte: nomsMaison.connecte, etat: nomsMaison.etat))
                if nomsMaison.connecte, nomsMaison.etat?.ouvertureSession == .aApprouver {
                    Text("Accepte Passeur Noms dans Réglages Système › Général › Ouverture.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let fin = nomsMaison.etat?.profilExpire,
                   NomsInternes.profilBientotExpire(nomsMaison.etat, maintenant: .now) {
                    Text("Le profil de Passeur Noms expire le \(fin.formatted(date: .abbreviated, time: .omitted)) : relance outils/passeur.sh.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Section("Noms de Maison") {
                if let n = nomsMaison.noms {
                    LabeledContent("Noms lus",
                                   value: String(localized: "\(n.accessoires.count) accessoires · \(n.date.formatted(date: .abbreviated, time: .shortened))"))
                    // Rien pour un releve d'avant les zones.
                    if let zones = n.zones {
                        LabeledContent("Zones", value: Self.texteZones(zones))
                    }
                }
                if let p = nomsMaison.probleme {
                    Text(p).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    Button("Rafraîchir depuis Maison") { nomsMaison.relire() }
                        .disabled(surveillance.mode == .demo || nomsMaison.releveEnCours)
                    if nomsMaison.releveEnCours {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
    }
```

- [ ] **Step 4 : textes et traductions**

```bash
outils/tester.sh MaillageThreadTests/ReglagesDemonTests
outils/synchroniser-textes.sh
```

Créer `outils/traductions/demon.json` :

```json
{
  "Passeur Noms ne s'est pas connecté en 2 minutes.": "Passeur Noms did not connect within 2 minutes.",
  "Connexion de Passeur Noms refusée : jeton faux.": "Passeur Noms connection refused: wrong token.",
  "Message illisible de Passeur Noms : connexion fermée.": "Unreadable message from Passeur Noms: connection closed.",
  "Passeur Noms s'est déconnecté.": "Passeur Noms disconnected.",
  "Connexion avec Passeur Noms coupée.": "Connection with Passeur Noms lost.",
  "Écoute de Passeur Noms impossible : %@": "Cannot listen for Passeur Noms: %@",
  "Passeur Noms est l'ancienne version : relance outils/passeur.sh.": "Passeur Noms is the old version: run outils/passeur.sh again.",
  "Identification demandée": "Identification requested",
  "Accessoire introuvable dans Maison": "Accessory not found in Home",
  "Cet accessoire ne sait pas s'identifier": "This accessory cannot identify itself",
  "Identification impossible : %@": "Identification failed: %@",
  "Identification impossible": "Identification failed",
  "non connecté": "not connected",
  "accès à Maison autorisé": "Home access allowed",
  "accès à Maison refusé": "Home access denied",
  "accès à Maison en attente": "Home access pending",
  "connecté · version %@ · %@": "connected · version %1$@ · %2$@",
  "Passeur Noms": "Passeur Noms",
  "Ouvrir Passeur Noms à l'ouverture de session": "Open Passeur Noms at login",
  "Accepte Passeur Noms dans Réglages Système › Général › Ouverture.": "Allow Passeur Noms in System Settings › General › Login Items.",
  "Le profil de Passeur Noms expire le %@ : relance outils/passeur.sh.": "The Passeur Noms profile expires on %@: run outils/passeur.sh again.",
  "Identifier": "Identify"
}
```

Puis :

```bash
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/demon.json
outils/tester.sh
```

Expected : tout vert, `CataloguesTests` compris (aucune clé absente, inutilisée ou périmée), et les tests qui rendent la fiche sans `NomsInternes` dans l'environnement (`FicheHeureTests`, `AssociationMaisonTests`, `CourbesFicheTests`, `LegendePiecesTests`, `FenetrePiecesTests`) : le bouton y est grisé, sans plantage. Si `CataloguesTests` signale une clé nouvelle absente de `demon.json` (un texte que ce plan n'a pas listé, par exemple « État » s'il n'existait pas), l'ajouter à `demon.json` avec son anglais et relancer les deux commandes.

- [ ] **Step 5 : commit**

```bash
git add MaillageThread/Vues/FenetreReglages.swift MaillageThread/Vues/Pieces/BoutonIdentifier.swift \
  MaillageThread/Vues/Pieces/FicheNoeud.swift MaillageThreadTests/ReglagesDemonTests.swift \
  outils/traductions/demon.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Reglages Maison : etat du demon, ouverture de session, profil ; bouton Identifier dans la fiche

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13 : version 1.3.0, notes de version, README

**Files:**
- Modify: `project.yml` (`MARKETING_VERSION: "1.3.0"` de `MaillageThread`)
- Modify: `NOTES-VERSIONS.md` (section `## 1.3.0` en tête, **English** puis **Français**)
- Modify: `README.md`, `README.fr.md` (section « Home names (Passeur Noms) » / « Noms de Maison (Passeur Noms) », tableau du code, mentions « conçue pour iPad »)

- [ ] **Step 1 : version**

Dans `project.yml`, cible `MaillageThread` : `MARKETING_VERSION: "1.2.2"` devient `MARKETING_VERSION: "1.3.0"`.

- [ ] **Step 2 : notes de version**

Ajouter en tête des sections de `NOTES-VERSIONS.md`, avant `## 1.2.2` :

```markdown
## 1.3.0

**English**

- Home names now come from a new **Passeur Noms**, a background helper with no window and no Dock icon: install or
  update it with `outils/passeur.sh` (the old "Designed for iPad" Passeur Noms is replaced; Home access may be asked
  once more). Maillage Thread subscribes to it at launch: a device renamed or moved in Home changes in the app within
  seconds, without relaunching anything.
- "Identify" in the card of a device linked to a Home accessory: the accessory blinks or beeps.
- Settings › Home: the state of Passeur Noms, "Open Passeur Noms at login", and a warning 30 days before its
  development profile expires (run `outils/passeur.sh` again). Batteries are read every hour by Passeur Noms.
- If the installed Passeur Noms is the old one, the app says so instead of opening it.

**Français**

- Les noms de Maison viennent d'un nouveau **Passeur Noms**, en arrière-plan, sans fenêtre ni icône dans le Dock :
  l'installer ou le mettre à jour avec `outils/passeur.sh` (il remplace l'ancien Passeur Noms « conçu pour iPad » ;
  l'accès à Maison peut être redemandé une fois). Maillage Thread s'y abonne au lancement : un appareil renommé ou
  déplacé dans Maison change dans l'app en quelques secondes, sans rien relancer.
- « Identifier » dans la fiche d'un appareil relié à un accessoire de Maison : l'accessoire clignote ou émet un son.
- Réglages › Maison : l'état de Passeur Noms, « Ouvrir Passeur Noms à l'ouverture de session », et un avertissement
  30 jours avant l'expiration de son profil de développement (relancer `outils/passeur.sh`). Les batteries sont
  relues toutes les heures par Passeur Noms.
- Si le Passeur Noms installé est l'ancien, l'app le dit au lieu de l'ouvrir.
```

- [ ] **Step 3 : README (anglais puis français, même contenu)**

Dans `README.md`, réécrire la section `## Home names (Passeur Noms)` (et la puce « Passeur Noms is not distributed », le paragraphe de signature qui en parle, les lignes `MaillageThread/Noms/` et `Passeur/` du tableau du code) pour dire, sans plus de détail que la spec :
- Passeur Noms est un démon Mac Catalyst sans fenêtre ni Dock (`LSUIElement`, `Masqueur.bundle` qui rend invisible la fenêtre que macOS impose) ; HomeKit est refusé au Developer ID, donc compilation de développement, profil d'un an, `outils/passeur.sh` pour installer et renouveler ; jamais distribué.
- `outils/passeur.sh` : compile, arrête l'ancien (par PID), remplace seulement une installation faite par le script, enregistre auprès de LaunchServices, lance en arrière-plan ; premier lancement : demande d'accès à Maison.
- L'échange : URL `maillage-passeur://abonner?port=…&jeton=…` ; le démon se connecte à `127.0.0.1`, envoie le jeton, puis des trames `<longueur>\n<JSON>` dans les deux sens (`etat`, `releve`, `identifie` ; `relire`, `identifier`, `ouvertureSession`) ; l'URL `releve` (relevé ponctuel, version 1) reste pour les anciennes apps ; limite connue inchangée (toute app locale peut ouvrir l'URL ; rien ne sort du Mac).
- Le démon suit Maison (regroupement de 2 s, envoi seulement si le relevé change, batteries toutes les heures), reste lancé tant qu'une app est abonnée (10 min ensuite) ou en permanence s'il est inscrit à l'ouverture de session.
- Côté app : abonnement au lancement, réabonnement après 5 s, 10 s, 30 s, puis chaque minute ; « Rafraîchir depuis Maison » envoie `relire` ; « Identifier » dans la fiche ; Réglages › Maison (état, interrupteur, profil 30 jours avant) ; l'ancien passeur détecté.
- Journal : `/usr/bin/log show --last 1h --predicate 'subsystem == "fr.djoko.maillage.passeur"'` ; outil de banc `python3 outils/verifier-passeur.py releve|abonner`.
- Retirer ce qui ne vaut plus : « Designed for iPad », la fenêtre de 10 s, « damaged » / « Open Anyway » au premier lancement de chaque compilation (à garder seulement si le banc de la tâche 9 l'a vu), la relance à l'ouverture de la vue par pièces (15 min, puis chaque heure), l'avertissement des noms de plus de 7 jours.

Faire exactement la même chose en français dans `README.fr.md` (« Noms de Maison (Passeur Noms) »).

- [ ] **Step 4 : vérifications et commit**

```bash
outils/tester.sh
git diff --stat
grep -n "1.3.0" project.yml NOTES-VERSIONS.md
```

Expected : tout vert ; `1.3.0` dans les deux fichiers. Balayage d'anonymisation avant le commit (les mêmes contrôles que le crochet `pre-push` : aucun identifiant d'équipe, nom légal, adresse électronique, nom réel de pièce ou d'appareil dans le diff).

```bash
git add project.yml NOTES-VERSIONS.md README.md README.fr.md
git commit -m "Maillage Thread 1.3.0 : notes de version et README du demon Passeur Noms

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14 (contrôleur, avec Djoko) : banc complet

Pas de code, sauf correctifs. Djoko présent ; Maillage Thread 1.3.0 compilé localement (compilation de travail : Sparkle ne la remplace pas), lancé par Djoko après avoir quitté l'app installée. Chaque correctif passe par un test qui échoue d'abord, dans la tâche concernée.

- [ ] **Step 1 :** Djoko quitte Maillage Thread 1.2.2 ; le contrôleur compile la branche (`outils/tester.sh` vert, puis compilation de l'app) ; Djoko lance la compilation de travail.
- [ ] **Step 2 (banc 2) :** l'app est abonnée (Réglages › Maison : « connecté · version 2.0 · accès à Maison autorisé ») ; Djoko renomme un accessoire dans Maison : le nom change dans l'app en quelques secondes ; puis il lui rend son nom.
- [ ] **Step 3 (banc 3) :** « Identifier » dans la fiche d'un appareil relié (par exemple le FP300 de l'essai du 12/10) : l'appareil réagit, la fiche dit « Identification demandée ».
- [ ] **Step 4 (banc 4) :** l'interrupteur « Ouvrir Passeur Noms à l'ouverture de session » : macOS montre « Élément d'arrière-plan ajouté » ; Djoko ferme sa session puis la rouvre : `pgrep -lf "Passeur Noms.app/Contents/MacOS"` montre le démon avant l'ouverture de Maillage Thread.
- [ ] **Step 5 (banc 5) :** le contrôleur arrête le démon par son PID (`kill <PID>`) : l'app se réabonne seule (délai de 5 s, puis le démon relancé par l'URL) ; Réglages › Maison repasse à « connecté ».
- [ ] **Step 6 (banc 6) :** Maillage Thread 1.2.2 (l'app installée, relevé ponctuel) : Djoko la relance à la place de la compilation de travail, ouvre la vue par pièces ou « Rafraîchir depuis Maison » : les noms arrivent, sans fenêtre ni erreur de version.
- [ ] **Step 7 :** journal du démon relu (aucun nom, aucun UUID) ; résultats notés dans la mémoire du projet (`maillage-thread-projet.md`, `demon-homekit-catalyst.md`).

Après le banc : relecture finale de toute la branche par Opus, puis fusion sur `main` et push après le balayage d'anonymisation, sur demande de Djoko. La publication de 1.3.0 attend un « publie 1.3.0 » explicite.

---

### Task 15 : passation à la session Zigbee

- [ ] **Step 1 :** avec l'accord de Djoko, envoyer à la session Maillage Zigbee (outil de messages entre sessions) une fiche courte :
  - recopier **à l'octet** `MaillageCoeur/Noms/ProtocolePasseur.swift` (il remplace son `EnvoiPasseur.swift`) et `MaillageCoeurTests/ProtocolePasseurTests.swift` depuis `main` de Maillage Thread, puis vérifier avec `cmp` ;
  - le relevé arrive en JSON brut (`MessagePasseur.releve(Data)`) : le lire dans `ReleveMaison`, qui gagne `id` dans `AccessoireReleve` et `versionActuelle = 2` (version 1 toujours lisible) ;
  - `NomsPasseur` devient client abonné selon la spec, section 4.2, en reprenant `AbonnementPasseur` et le `NomsInternes` de Thread (réabonnement 5/10/30/60 s, délai 2 min, `relire`, `identifier`, `ouvertureSession`, détection de l'ancien passeur par `MaillagePasseurProtocole`) ; relevé gardé dans `releve-maison.json` ;
  - interrupteur d'ouverture de session dans ses Réglages, « Identifier » pour les appareils du pont retrouvés dans Maison (`FusionNoms`) ;
  - le démon est déjà installé par `outils/passeur.sh` de Maillage Thread ; rien à compiler côté Zigbee pour lui ;
  - spec : `docs/superpowers/specs/2026-10-12-demon-passeur-design.md` du dépôt Maillage Thread.
