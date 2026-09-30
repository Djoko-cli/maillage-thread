# Maillage Thread, plan 4a : le passeur sans dossier et les zones de Maison : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** faire passer le relevé de Maison du passeur à l'app par la boucle locale du Mac (TCP sur 127.0.0.1, jeton à usage unique), sans dossier à choisir, et y ajouter les zones de Maison, qui seront les étages de la vue par pièces (plan 4b).

**Architecture :**
- **Le cœur** (`MaillageCoeur/Noms/`, Swift pur, testé) :
  - `NomsMaison` gagne le champ facultatif `zones: [ZoneMaison]?` ; un fichier d'avant les zones reste lisible ;
  - `EnvoiPasseur` décrit l'échange, commun à l'app et au passeur : les arguments de lancement (`Cible` : `--port` et `--jeton`), le jeton, la trame (jeton, longueur, JSON) et sa lecture au fil des octets, bornée à 8 Mo, avec le jeton comparé à temps constant.
- **L'app** (`MaillageThread/Noms/`) : `NomsInternes` remplace `DossierNoms`.
  - Pour un relevé : une écoute TCP sur 127.0.0.1 (`EcouteReleve`, Network.framework), un jeton neuf, le passeur lancé sans activation, 120 s d'attente.
  - Le relevé reçu est écrit dans le conteneur (`noms.json`, écriture atomique) ; le dernier relevé valide est gardé ; une seule écoute à la fois.
  - Plus de choix de dossier, de signet ni de `passeur-demande.json`. Les Réglages et le menu suivent.
- **Le passeur** (`Passeur/PasseurApp.swift`) : il lit `--port` et `--jeton`, exporte les zones, envoie la trame puis se ferme ; ouvert à la main, il n'envoie rien.

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI, Observation, Network.framework (`NWListener`, `NWConnection`), AppKit (`NSWorkspace.OpenConfiguration`), HomeKit (passeur), Synchronization (`Mutex`, tests), Swift Testing, XcodeGen.

**Spec :** `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, section 3 (transport et zones), avec ce qui la concerne dans les sections 9 (`NomsInternes`, `PasseurApp.swift`), 10 (tests de `NomsInternes`) et 11 (le plan 4a ne dépend pas de la vue). Le plan révise aussi la section 5 de la spec de l'étape 1 (`docs/superpowers/specs/2026-09-28-maillage-thread-design.md`), qui décrit le dossier choisi une fois.

> **Révision du 30/09 (tâche 6a) :** à la vérification réelle (tâche 6), le port et le jeton passent par une URL, `maillage-passeur://releve?port=…&jeton=…`, et non plus par les arguments de lancement : macOS retire les arguments passés par une app du bac à sable.
> Voir la tâche 6a, au registre local du plan (non publié). Le reste du plan décrit l'état d'avant.

**Quand l'exécuter.** Sur `main`, avant ou pendant le plan 4b (spec, section 11). Il ne dépend pas du plan 3b, et ses blocs ne visent pas les passages que le brouillon du 3b remplace (au 30/09) : l'un et l'autre peuvent passer en premier ; `interface.json` et le catalogue passent par les outils. **Les numéros de ligne cités sont indicatifs : l'exécutant se repère aux noms (types, fonctions, commentaires) et aux textes cités.** Si un texte à remplacer n'est plus exactement le même, il applique le même changement au texte du moment et le dit dans son rapport.

**Code validé avant exécution.** Le 30/09, tout le code de ce plan a été écrit, compilé et testé dans une copie de `main` (commit `709e7b8`) :
- le passeur compile sans signature pour « Designed for iPad » ;
- toute la suite passe, en français et en anglais.

Le plan a ensuite été rejoué tâche par tâche sur une copie neuve de `main` (`709e7b8`) : l'erreur avant le code, les tests après, la suite entière. Les résultats attendus ci-dessous viennent de ce rejeu, comme la liste du `git add` de chaque tâche. L'arbre final est identique à la copie validée. Sur `709e7b8`, le cœur comptait 229 tests en 21 suites et l'app 216 en 24 ; après ce plan, 234 en 22 et 219 en 24. D'autres changements de `main` peuvent changer ces totaux : chaque tâche donne donc ses effectifs par suite, et l'écart des totaux.

Exécuter une tâche, c'est transcrire les fichiers et les blocs donnés, compiler et tester. Si un fichier doit s'écarter du texte donné, l'exécutant le dit dans son rapport, avec la raison.

**Blocs de modification.** Un fichier existant est modifié soit en entier (« fichier entier »), soit par blocs « remplacer … par … ». Chaque texte à remplacer apparaît une seule fois dans le fichier au moment où on l'applique. Les blocs s'appliquent dans l'ordre, du haut vers le bas, au texte exact, espaces compris (outil Edit). Un fichier créé l'est tel quel ; un fichier supprimé l'est par `git rm`.

**Faits établis, utiles à l'exécution :**
- **Essai du passeur-démon (30/09)** :
  - une app iOS lancée par `open -g`, ou par `NSWorkspace` sans activation, lit Maison ;
  - elle reçoit un port et un jeton par ses arguments de lancement (`OpenConfiguration.arguments`) ;
  - elle envoie le JSON par TCP à 127.0.0.1, sans aucune invite « réseau local », et se ferme en moins d'une seconde ;
  - une fenêtre vide passe un instant à chaque lancement : macOS en donne une à toute app iOS.
- **Copie validée (30/09)** :
  - dans le bac à sable de l'app, écouter exige `com.apple.security.network.server`, même sur la boucle locale. Sans lui, `bind(127.0.0.1:0)` échoue (`Operation not permitted`) et les tests de la tâche 3 le montrent : « Écoute du relevé impossible : … Operation not permitted » ;
  - un `NWListener` dont les paramètres portent `requiredLocalEndpoint = 127.0.0.1`, port `.any`, n'écoute que sur la boucle locale, sur un port choisi par le système (`listener.port` une fois prêt) ;
  - pour fermer son côté après l'envoi, le passeur envoie avec `contentContext: .finalMessage` : avec le contexte par défaut, l'app ne voit jamais la fin de la connexion ;
  - les tests de l'app tournent dans l'app. Deux sessions de tests de l'app en même temps sur ce Mac (même identifiant `fr.djoko.maillage`) peuvent s'interrompre l'une l'autre : `Test crashed with signal term` sur un test sans rapport. Relancer alors la suite, seule.

**Précisions à la spec (assumées, à faire valider par Djoko) :**
1. **La trame dans le cœur.** `EnvoiPasseur` (cible, jeton, trame, lecture bornée) est commun à l'app et au passeur, qui compile ce fichier en plus de `NomsMaison.swift` et de `CodageJSON.swift`. Il est testé seul dans le cœur (tâche 2), et `NomsInternes` face à un faux passeur, comme le demande la spec (tâche 3).
2. **Bac à sable.** `com.apple.security.network.server` est ajouté (fait établi ci-dessus). `com.apple.security.files.bookmarks.app-scope`, qui ne servait qu'au signet du dossier des noms, est retiré. `files.user-selected.read-write` reste pour « Enregistrer une capture… ».
3. **Fichier du conteneur.** C'est `noms.json`, comme le dit la spec, dans `Application Support/Maillage Thread/`, à côté de `identites-routeurs.json`. Il n'y a pas de migration :
   - l'ancien cache `noms-maison.json` et la préférence `dossierNoms` (le signet) restent, sans être lus ;
   - l'app n'a donc pas de noms de Maison jusqu'au premier relevé, que l'ouverture du graphe lance d'elle-même (relevé absent).
4. **Une connexion par relevé.** L'écoute se ferme dès la première connexion, et ce qu'elle envoie décide du relevé : un jeton faux le finit, sans seconde chance. La spec dit : « elle ferme l'écoute ».
5. **Délais.** Les 120 s de l'app courent de la demande à la fin de la lecture. Le délai de secours du passeur, sans réponse de Maison, passe de 30 s à 100 s : sans cela, la demande d'accès à Maison du premier lancement, qu'il faut attendre (spec, section 3.1), serait coupée au bout de 30 s.
6. **Passeur ouvert à la main** (par `outils/passeur.sh`, ou le Finder) : il lit Maison, montre ce qu'il a lu (accessoires et zones), n'envoie rien et se ferme après 10 s. Le premier lancement de chaque compilation reste celui de `outils/passeur.sh`, pour Gatekeeper.
7. **Fermeture du passeur.** Après l'envoi, il attend que l'app ferme la connexion, preuve qu'elle a tout lu, puis quitte ; au plus 10 s. Si l'app n'écoute plus (délai passé), il quitte aussitôt. Un passeur resté ouvert ne recevrait pas les arguments du lancement suivant.
8. **Réglages › Noms de Maison.**
   - Une ligne « Zones » : leurs noms dans l'ordre de Maison, ou « aucune zone dans Maison » ; rien pour un relevé d'avant les zones. Djoko voit ainsi ses zones avant le plan 4b.
   - « Rafraîchir depuis Maison » est grisé pendant un relevé, avec un petit indicateur. Dans le menu, le bouton est grisé aussi.
9. **Bouton rafraîchir du graphe.** Il lance le passeur en mode direct, sans condition de dossier. Son aide ne change pas.
10. **Description HomeKit du passeur** (`NSHomeKitUsageDescription`) : elle cite aussi les zones.

**Limites connues :**
- Si Passeur Noms est déjà ouvert, par exemple à la main pendant ses 10 s, le lancement par l'app atteint cette instance sans arguments. Rien n'arrive, et le relevé échoue au bout de 2 minutes (« Passeur Noms n'a rien envoyé en 2 minutes. »), les noms gardés.
- Le jeton passe par les arguments de lancement : les processus du même utilisateur peuvent le lire (`ps`) pendant le relevé. Le risque reste local, comme dans la spec.
- La fenêtre vide du passeur passe toujours un instant à chaque relevé. `LSUIElement` (essai du passeur-démon) n'est pas repris.

## Global Constraints

- **Plateformes :** app en macOS 26.0 minimum ; passeur en iOS 18.0 minimum, lancé sur le Mac « conçu pour iPad ». Développés avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`, pour les trois cibles, passeur compris. Notamment, `Text + Text` est déprécié dans le SDK de macOS 26, donc refusé.
- **Code :** identifiants et commentaires en français **sans accents** ; textes affichés avec accents ; tests en Swift Testing. Les nouveaux fichiers de l'app et du cœur vont dans des dossiers existants, que `project.yml` prend déjà. Seul le passeur liste ses fichiers du cœur un par un : la tâche 4 y ajoute `EnvoiPasseur.swift`.
- **Textes de l'app :** catalogue `MaillageThread/Ressources/Localizable.xcstrings`, français source et anglais obligatoire. Une tâche qui change des textes synchronise elle-même le catalogue, dans cet ordre :
  1. compiler ;
  2. `outils/synchroniser-textes.sh` ;
  3. dans `outils/traductions/interface.json`, retirer les clés que le code n'a plus et ajouter les nouvelles (la tâche donne le script). Une clé morte laissée là, `outils/traduire.py` la remettrait au catalogue ;
  4. `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`.

  Le test `CataloguesTests` refuse une clé absente comme une clé morte. Les textes du passeur restent en français, hors du catalogue.
- **Tests indépendants de la langue :** une attente sur un texte affiché reprend la même clé que le code (`String(localized: "Relevé de Maison refusé : jeton faux.")`), jamais une chaîne française figée. Les tests passent en anglais : `xcodebuild … -testLanguage en -testRegion US test` (vérifié le 30/09).
- **Commandes,** depuis la racine du dépôt, toujours avec un dossier de produits (`DD`) et un dossier temporaire (`TMPDIR`) propres à ce plan : une autre compilation (l'app de Djoko, une autre session) ne partage ni ses produits ni son journal. Le shell d'un agent ne garde pas ses variables d'une commande à l'autre : chaque commande les porte. Une fois, avant la tâche 1 :

  ```bash
  mkdir -p "$HOME/Library/Caches/maillage-plan4a"
  ```

  Puis, par exemple :

  ```bash
  DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh MaillageCoeurTests/NomsTests
  ```

  `outils/tester.sh [cibles…]` génère le projet, compile et lance les tests ; les produits vont dans `DD`, le journal complet dans `$TMPDIR/maillage-tests.log`. `outils/synchroniser-textes.sh` lit les produits dans le même `DD`. La première compilation dans ce `DD` neuf prend quelques minutes.
- **Une suite de tests de l'app à la fois** sur ce Mac (fait établi ci-dessus) : si un test sans rapport échoue avec `Test crashed with signal term`, vérifier qu'aucune autre session ne teste l'app (`pgrep -fl xcodebuild`), puis relancer la suite.
- **Le passeur se compile sans signature** (tâche 4) : aucune équipe, aucun profil, rien d'installé ni de lancé :

  ```bash
  xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme Passeur -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a-passeur" CODE_SIGNING_ALLOWED=NO build
  ```
- **Passeur, Maison et app :** de la tâche 1 à la tâche 5, **aucun agent** :
  - ne lance `outils/passeur.sh` (il signe avec l'équipe de Djoko) ni le passeur ;
  - n'ouvre Maison ;
  - ne lance l'app en mode direct.

  Les tests n'utilisent qu'un faux passeur (un client TCP sur 127.0.0.1) et des fichiers temporaires, jamais le vrai Maison, le vrai trousseau ni le conteneur de l'app. L'instance de l'app sous les tests n'a pas de mémoire (`NomsInternes(cache: nil)`) : elle ne lance jamais le passeur. La tâche 6 se fait avec Djoko, par le contrôleur.
- **Réseau :** l'app n'écoute que sur 127.0.0.1 ; aucun test ne sort de la boucle locale.
- **Données personnelles** (le dépôt est public sur GitHub, `Djoko-cli/maillage-thread`) :
  - `noms.json` n'est jamais commité : ni celui du conteneur, ni celui que l'ancien passeur a laissé à la racine du dépôt principal (ignoré par git), ni `passeur-demande.json` ;
  - aucun nom d'accessoire, de pièce ni de zone de la maison de Djoko dans un fichier commité : les données de test sont inventées, et la vérification (tâche 6) ne note que des comptes.
- **Signature :** l'app reste ad hoc (`Signature.xcconfig`) ; le passeur garde son équipe gratuite, donnée par `outils/passeur.sh`. **Ne jamais créer `Local.xcconfig`.** Aucun identifiant d'équipe, empreinte de certificat ni adresse électronique dans un fichier commité.
- **Commits :**
  - un par tâche, message en français sans accents, terminé par la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - `git add` avec la liste de fichiers de la tâche (un fichier supprimé l'est déjà par `git rm`), **jamais `git add -A` ni `git add .`** ;
  - jamais de push.
- **Interdits pour les agents :** `sudo` ; ouvrir un port série ou flasher ; lancer l'app en mode direct ; lancer le passeur ou `outils/passeur.sh` ; réveiller l'écran.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `MaillageCoeur/Noms/NomsMaison.swift` | `ZoneMaison`, `NomsMaison.zones` ; puis la fin de `DemandePasseur` | 1, 4 |
| `MaillageCoeurTests/NomsTests.swift` | contrat des zones ; puis la fin des tests de `DemandePasseur` | 1, 4 |
| `MaillageCoeur/Noms/EnvoiPasseur.swift`, `MaillageCoeurTests/EnvoiPasseurTests.swift` | `EnvoiPasseur` : cible, jeton, trame, lecture bornée | 2 |
| `MaillageThread/Noms/NomsInternes.swift` | relevé par la boucle locale, dernier relevé valide, lancement du passeur | 3 |
| `MaillageThread/Noms/EcouteReleve.swift` | écoute TCP d'un relevé sur 127.0.0.1 | 3 |
| `MaillageThread/Noms/DossierNoms.swift`, `MaillageThreadTests/DossierNomsTests.swift` | supprimés | 3 |
| `MaillageThread/Droits.entitlements` | `network.server` ajouté, `files.bookmarks.app-scope` retiré | 3 |
| `MaillageThread/MaillageThreadApp.swift`, `MaillageThread/Vues/FenetreReglages.swift`, `MaillageThread/Vues/MenuBarre.swift`, `MaillageThread/Vues/Graphe/FenetreGraphe.swift` | branchement ; Réglages › Noms de Maison ; menu ; bouton rafraîchir du graphe | 3 |
| `MaillageThreadTests/NomsInternesTests.swift`, `MaillageThreadTests/GrapheTests.swift` | faux passeur et cas de la spec ; bouton rafraîchir | 3 |
| `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` | 8 textes nouveaux, 7 retirés | 3 |
| `Passeur/PasseurApp.swift`, `project.yml`, `outils/passeur.sh` | envoi par la boucle locale et zones ; sources et description HomeKit du passeur ; commentaire du script | 4 |
| `README.md`, `README.fr.md`, `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` | mode d'emploi ; spec de l'étape 1 ; lien vers ce plan | 5 |

---

### Task 1: Cœur : les zones de Maison

**Files:**
- Modify: `MaillageCoeur/Noms/NomsMaison.swift` (bloc ci-dessous)
- Test: `MaillageCoeurTests/NomsTests.swift` (bloc ci-dessous)

**Interfaces:**
- Consumes : `NomsMaison` et `CodageJSON` (dates ISO 8601 à la milliseconde, clés triées), existants.
- Produces :
  - `public struct ZoneMaison: Codable, Hashable, Sendable` : `nom: String`, `pieces: [String]`, `init(nom: String, pieces: [String] = [])` ;
  - `NomsMaison.zones: [ZoneMaison]?`, et le paramètre `zones: [ZoneMaison]? = nil`, en dernier, de `NomsMaison.init` ;
  - absent du JSON quand il vaut nil ; lu nil dans un fichier d'avant les zones ; `NomsMaison.versionActuelle` reste 1.

- [ ] **Step 1 : écrire le test.**

Dans `MaillageCoeurTests/NomsTests.swift`, remplacer :

```swift
    @Test func chargeInconnue() throws {
        let json = #"{"accessoires":[{"batterie":{"charge":"sansFil","niveau":40},"nom":"Store"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        #expect(try NomsMaison.lire(Data(json.utf8)).accessoires.first?.batterie == BatterieMaison(niveau: 40))
    }
```

par :

```swift
    @Test func chargeInconnue() throws {
        let json = #"{"accessoires":[{"batterie":{"charge":"sansFil","niveau":40},"nom":"Store"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        #expect(try NomsMaison.lire(Data(json.utf8)).accessoires.first?.batterie == BatterieMaison(niveau: 40))
    }

    /// `zones` est facultatif : un fichier d'avant les zones se lit, sans zones ; un fichier qui
    /// les a les garde dans l'ordre de Maison, pieces comprises. Une maison sans zones donne une
    /// liste vide. Le champ est additif : la version ne change pas, et sans zones il n'est pas ecrit.
    @Test func contratZones() throws {
        let ancien = #"{"accessoires":[{"nom":"Halo","piece":"Bureau"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        #expect(try NomsMaison.lire(Data(ancien.utf8)).zones == nil)
        let avec = #"{"accessoires":[],"date":"2026-09-30T12:00:00.000Z","statut":"ok","version":1,"zones":[{"nom":"Étage","pieces":["Chambre","Bureau"]},{"nom":"Rez-de-chaussée","pieces":["Salon","Cuisine","Entrée"]}]}"#
        #expect(try NomsMaison.lire(Data(avec.utf8)).zones == [
            ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau"]),
            ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée"]),
        ])
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(try NomsMaison.lire(try NomsMaison(date: date, zones: []).donnees()).zones == [])
        let n = NomsMaison(date: date, accessoires: [AccessoireMaison(nom: "Halo", piece: "Bureau")],
                           zones: [ZoneMaison(nom: "Étage", pieces: ["Bureau"])])
        #expect(try NomsMaison.lire(try n.donnees()) == n)
        #expect(NomsMaison.versionActuelle == 1)
        #expect(!String(decoding: try NomsMaison(date: date).donnees(), as: UTF8.self).contains("zones"))
    }
```

- [ ] **Step 2 : vérifier qu'il échoue.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh MaillageCoeurTests/NomsTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: value of type 'NomsMaison' has no member 'zones'`, `error: extra argument 'zones' in call` et `error: cannot find 'ZoneMaison' in scope`.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageCoeur/Noms/NomsMaison.swift`, remplacer :

```swift
/// Contrat du fichier `noms.json`, ecrit d'un coup par le passeur (app iOS
/// lancee sur le Mac) dans un dossier choisi une fois, sans App Group, et lu
/// par l'app.
public struct NomsMaison: Codable, Hashable, Sendable {
    public static let versionActuelle = 1

    public var version: Int
    public var date: Date
    public var statut: StatutPasseur
    public var message: String?
    public var domicile: String?
    public var accessoires: [AccessoireMaison]

    public init(version: Int = NomsMaison.versionActuelle, date: Date, statut: StatutPasseur = .ok,
                message: String? = nil, domicile: String? = nil, accessoires: [AccessoireMaison] = []) {
        self.version = version
        self.date = date
        self.statut = statut
        self.message = message
        self.domicile = domicile
        self.accessoires = accessoires
```

par :

```swift
/// Zone de Maison (`HMZone`), en general un etage, et ses pieces, dans l'ordre de Maison.
/// Une piece peut appartenir a plusieurs zones.
public struct ZoneMaison: Codable, Hashable, Sendable {
    public var nom: String
    public var pieces: [String]

    public init(nom: String, pieces: [String] = []) {
        self.nom = nom
        self.pieces = pieces
    }
}

/// Contrat du fichier `noms.json`, ecrit d'un coup par le passeur (app iOS
/// lancee sur le Mac) dans un dossier choisi une fois, sans App Group, et lu
/// par l'app.
public struct NomsMaison: Codable, Hashable, Sendable {
    /// Les zones, champ facultatif ajoute ensuite, ne la changent pas.
    public static let versionActuelle = 1

    public var version: Int
    public var date: Date
    public var statut: StatutPasseur
    public var message: String?
    public var domicile: String?
    public var accessoires: [AccessoireMaison]
    /// Zones de Maison, dans son ordre : absent d'un fichier d'avant les zones, vide pour
    /// une maison qui n'en a pas.
    public var zones: [ZoneMaison]?

    public init(version: Int = NomsMaison.versionActuelle, date: Date, statut: StatutPasseur = .ok,
                message: String? = nil, domicile: String? = nil, accessoires: [AccessoireMaison] = [],
                zones: [ZoneMaison]? = nil) {
        self.version = version
        self.date = date
        self.statut = statut
        self.message = message
        self.domicile = domicile
        self.accessoires = accessoires
        self.zones = zones
```

- [ ] **Step 4 : vérifier qu'il passe.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh MaillageCoeurTests/NomsTests`
Expected: `Test run with 17 tests in 1 suite passed` (`NomsTests` : les 16 d'avant et `contratZones`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement ; 1 test de plus pour le cœur, l'app inchangée (au rejeu : 230 tests en 21 suites, et 216 en 24 suites).

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Noms/NomsMaison.swift MaillageCoeurTests/NomsTests.swift
git commit -m "Ajouter les zones de Maison au releve du passeur

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Cœur : la trame du passeur (`EnvoiPasseur`)

**Files:**
- Create: `MaillageCoeur/Noms/EnvoiPasseur.swift`
- Test: `MaillageCoeurTests/EnvoiPasseurTests.swift`

**Interfaces:**
- Consumes : rien du reste du code (Foundation seulement : le passeur compilera ce fichier à la tâche 4).
- Produces :
  - `public enum EnvoiPasseur` : `tailleMax` (8 × 1024 × 1024 octets de JSON), `octetsJeton` (32), `nouveauJeton() -> String` (64 chiffres hexadécimaux minuscules, générateur aléatoire du système), `trame(jeton: String, json: Data) -> Data` (`"<jeton>\n<longueur>\n"` puis le JSON) ;
  - `EnvoiPasseur.Cible: Hashable, Sendable` : `port: UInt16`, `jeton: String`, `init(port:jeton:)`, `arguments: [String]` (`["--port", "<port>", "--jeton", "<jeton>"]`), `init?(arguments: [String])` (nil ouvert à la main, ou si le port ou le jeton est illisible ; les autres arguments sont ignorés) ;
  - `EnvoiPasseur.Lecture: Sendable` : `init(jeton: String)`, `mutating func ajouter(_ octets: Data) -> Issue`, `func fin() -> Issue` (la connexion s'est fermée) ; `Lecture.Issue: Equatable, Sendable` : `.incomplete`, `.json(Data)`, `.jetonFaux`, `.longueurFausse`. Le jeton est comparé à temps constant ; une longueur au-delà de `tailleMax` est refusée avant l'arrivée du JSON ; une fois connue, l'issue ne change plus.

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/EnvoiPasseurTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Envoi du releve du passeur par la boucle locale")
struct EnvoiPasseurTests {
    static let jeton = String(repeating: "5a", count: 32)
    static let json = Data(#"{"accessoires":[],"date":"2026-09-30T12:00:00.000Z","statut":"ok","version":1}"#.utf8)

    /// Lit des octets arrives en paquets de `taille` : la premiere issue connue, ou celle de la
    /// fermeture de la connexion apres le dernier paquet.
    static func lire(_ octets: Data, par taille: Int, jeton: String = jeton) -> EnvoiPasseur.Lecture.Issue {
        var l = EnvoiPasseur.Lecture(jeton: jeton)
        var i = octets.startIndex
        while i < octets.endIndex {
            let j = min(i + taille, octets.endIndex)
            let issue = l.ajouter(octets[i..<j])
            if issue != .incomplete { return issue }
            i = j
        }
        return l.fin()
    }

    /// Port et jeton passent par les arguments de lancement et s'y relisent, parmi d'autres
    /// arguments ; ouvert a la main, le passeur n'en a pas.
    @Test func arguments() {
        let c = EnvoiPasseur.Cible(port: 54_321, jeton: Self.jeton)
        #expect(c.arguments == ["--port", "54321", "--jeton", Self.jeton])
        #expect(EnvoiPasseur.Cible(arguments: ["/Applications/Passeur Noms.app/Passeur Noms"] + c.arguments) == c)
        #expect(EnvoiPasseur.Cible(arguments: ["Passeur Noms", "-NSDocumentRevisionsDebugMode", "YES"] + c.arguments) == c)
        #expect(EnvoiPasseur.Cible(arguments: ["Passeur Noms"]) == nil, "ouvert a la main")
        #expect(EnvoiPasseur.Cible(arguments: ["Passeur Noms", "--port", "54321"]) == nil, "sans jeton")
        #expect(EnvoiPasseur.Cible(arguments: ["Passeur Noms", "--jeton", Self.jeton, "--port"]) == nil, "port sans valeur")
        for port in ["0", "70000", "abc", "-1"] {
            #expect(EnvoiPasseur.Cible(arguments: ["Passeur Noms", "--port", port, "--jeton", Self.jeton]) == nil, "port \(port)")
        }
    }

    /// Jeton a usage unique : 32 octets aleatoires, en 64 chiffres hexadecimaux, neuf a chaque tirage.
    @Test func jeton() {
        let a = EnvoiPasseur.nouveauJeton()
        #expect(a.count == 64)
        #expect(a.allSatisfy { "0123456789abcdef".contains($0) })
        #expect(a != EnvoiPasseur.nouveauJeton())
    }

    /// Trame : le jeton sur une ligne, la longueur du JSON sur une ligne, puis le JSON. Elle se
    /// relit quel que soit son decoupage en paquets ; ce qui suit le JSON est ignore.
    @Test func trameLueParMorceaux() {
        let t = EnvoiPasseur.trame(jeton: Self.jeton, json: Self.json)
        #expect(t == Data("\(Self.jeton)\n\(Self.json.count)\n".utf8) + Self.json)
        for taille in [1, 2, 7, 64, 65, 66, 1000, t.count] {
            #expect(Self.lire(t, par: taille) == .json(Self.json), "paquets de \(taille)")
        }
        #expect(Self.lire(t + Data("reste".utf8), par: 5) == .json(Self.json))
    }

    /// Jeton faux : un autre de meme longueur, un plus court ou plus long, une ligne sans fin,
    /// ou une connexion fermee avant la fin du jeton.
    @Test func jetonFaux() {
        let autre = String(repeating: "5a", count: 31) + "5b"
        #expect(Self.lire(EnvoiPasseur.trame(jeton: autre, json: Self.json), par: 1000) == .jetonFaux)
        #expect(Self.lire(EnvoiPasseur.trame(jeton: String(Self.jeton.dropLast()), json: Self.json), par: 1000) == .jetonFaux)
        #expect(Self.lire(EnvoiPasseur.trame(jeton: Self.jeton + "0", json: Self.json), par: 1000) == .jetonFaux)
        #expect(Self.lire(Data(String(repeating: "5a", count: 40).utf8), par: 3) == .jetonFaux, "80 octets sans fin de ligne")
        #expect(Self.lire(Data(Self.jeton.prefix(10).utf8), par: 3) == .jetonFaux, "fermee avant la fin du jeton")
        #expect(Self.lire(Data(), par: 1) == .jetonFaux, "fermee sans rien envoyer")
    }

    /// Longueur fausse : illisible, signee, nulle, au-dela de 8 Mo, sans fin de ligne, ou trame
    /// plus courte qu'annoncee. Au-dela de 8 Mo, elle est refusee avant l'arrivee du JSON.
    @Test func longueurFausse() {
        func trame(_ longueur: String, _ json: Data = Self.json) -> Data {
            Data("\(Self.jeton)\n\(longueur)\n".utf8) + json
        }
        for l in ["", "abc", "-5", "+5", " 5", "0", String(EnvoiPasseur.tailleMax + 1)] {
            #expect(Self.lire(trame(l), par: 1000) == .longueurFausse, "longueur « \(l) »")
        }
        #expect(Self.lire(Data("\(Self.jeton)\n12345678901234567".utf8), par: 1000) == .longueurFausse, "17 chiffres sans fin")
        #expect(Self.lire(trame(String(Self.json.count + 1)), par: 1000) == .longueurFausse, "trame plus courte")
        #expect(Self.lire(Data("\(Self.jeton)\n".utf8), par: 1000) == .longueurFausse, "fermee avant la longueur")
        var l = EnvoiPasseur.Lecture(jeton: Self.jeton)
        #expect(l.ajouter(Data("\(Self.jeton)\n\(EnvoiPasseur.tailleMax + 1)\n".utf8)) == .longueurFausse)
        let max = Data(count: EnvoiPasseur.tailleMax)
        #expect(Self.lire(trame(String(EnvoiPasseur.tailleMax), max), par: 65_536) == .json(max), "8 Mo tout juste")
    }

    /// Une fois l'issue connue, elle ne change plus.
    @Test func issueDefinitive() {
        var l = EnvoiPasseur.Lecture(jeton: Self.jeton)
        #expect(l.ajouter(Data("faux\n".utf8)) == .jetonFaux)
        #expect(l.ajouter(Data("\(Self.jeton)\n".utf8)) == .jetonFaux)
        #expect(l.fin() == .jetonFaux)
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh MaillageCoeurTests/EnvoiPasseurTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find 'EnvoiPasseur' in scope` et `error: cannot find type 'EnvoiPasseur' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Noms/EnvoiPasseur.swift` :

```swift
import Foundation

/// Envoi du releve du passeur a l'app par la boucle locale du Mac (TCP sur 127.0.0.1), sans
/// dossier partage ni App Group :
/// 1. l'app ecoute sur 127.0.0.1, sur un port choisi par le systeme, et tire un jeton a usage unique ;
/// 2. elle lance le passeur sans l'activer, avec `--port <port> --jeton <jeton>` (`Cible`) ;
/// 3. le passeur lit Maison, se connecte et envoie la trame : le jeton sur une ligne, la longueur
///    du JSON (entier decimal) sur une ligne, puis le JSON de `NomsMaison` ; puis il se ferme ;
/// 4. l'app verifie le jeton, en comparaison a temps constant, et lit au plus `tailleMax` octets
///    de JSON (`Lecture`).
/// Commun a l'app et au passeur, qui compile ce fichier (`project.yml`).
public enum EnvoiPasseur {
    /// JSON lu au plus par l'app : 8 Mo (le releve du 30/09, 133 accessoires, en fait 32 Ko).
    public static let tailleMax = 8 * 1024 * 1024
    /// Jeton : autant d'octets aleatoires, en chiffres hexadecimaux (64).
    public static let octetsJeton = 32

    /// Ou le passeur envoie le releve : port et jeton, donnes par ses arguments de lancement.
    public struct Cible: Hashable, Sendable {
        public var port: UInt16
        public var jeton: String

        public init(port: UInt16, jeton: String) {
            self.port = port
            self.jeton = jeton
        }

        /// Arguments de lancement du passeur.
        public var arguments: [String] { ["--port", String(port), "--jeton", jeton] }

        /// Lue dans les arguments du passeur, parmi d'autres ; nil s'il a ete ouvert a la main
        /// (ni port ni jeton), ou si l'un d'eux est illisible.
        public init?(arguments: [String]) {
            func valeur(_ option: String) -> String? {
                guard let i = arguments.firstIndex(of: option), i + 1 < arguments.count else { return nil }
                return arguments[i + 1]
            }
            guard let port = valeur("--port").flatMap({ UInt16($0) }), port != 0,
                  let jeton = valeur("--jeton"), !jeton.isEmpty else { return nil }
            self.init(port: port, jeton: jeton)
        }
    }

    /// Jeton neuf : `octetsJeton` octets du generateur aleatoire du systeme (cryptographique),
    /// en hexadecimal minuscule.
    public static func nouveauJeton() -> String {
        var generateur = SystemRandomNumberGenerator()
        let chiffres = Array("0123456789abcdef")
        var jeton = ""
        for _ in 0..<octetsJeton {
            let o = UInt8.random(in: .min ... .max, using: &generateur)
            jeton.append(chiffres[Int(o >> 4)])
            jeton.append(chiffres[Int(o & 0x0F)])
        }
        return jeton
    }

    /// Trame envoyee par le passeur.
    public static func trame(jeton: String, json: Data) -> Data {
        Data("\(jeton)\n\(json.count)\n".utf8) + json
    }

    /// Lecture d'une trame par l'app, au fil des octets recus.
    public struct Lecture: Sendable {
        public enum Issue: Equatable, Sendable {
            /// Il faut d'autres octets.
            case incomplete
            /// Le JSON, de la longueur annoncee ; ce qui le suit est ignore.
            case json(Data)
            /// Premiere ligne autre que le jeton attendu, ou connexion fermee avant sa fin.
            case jetonFaux
            /// Longueur illisible, nulle ou au-dela de `tailleMax`, ou trame plus courte qu'annoncee.
            case longueurFausse
        }

        private enum Etape: Sendable {
            case jeton, longueur
            case json(Int)
            case finie(Issue)
        }

        private enum Ligne {
            case manque, tropLongue
            case ligne([UInt8])
        }

        /// Chiffres d'une longueur, au plus (`tailleMax` en a 7).
        static let chiffresMax = 16

        private let attendu: [UInt8]
        private var tampon = Data()
        private var etape = Etape.jeton

        public init(jeton: String) {
            attendu = Array(jeton.utf8)
        }

        /// Ajoute des octets recus ; rend l'issue, `incomplete` tant qu'il en faut d'autres.
        /// Une fois connue, l'issue ne change plus.
        public mutating func ajouter(_ octets: Data) -> Issue {
            if case .finie(let issue) = etape { return issue }
            tampon.append(octets)
            while true {
                switch etape {
                case .finie(let issue):
                    return issue
                case .jeton:
                    switch prendreLigne(auPlus: attendu.count) {
                    case .manque: return .incomplete
                    case .tropLongue: return finir(.jetonFaux)
                    case .ligne(let l):
                        guard Self.egaux(l, attendu) else { return finir(.jetonFaux) }
                        etape = .longueur
                    }
                case .longueur:
                    switch prendreLigne(auPlus: Self.chiffresMax) {
                    case .manque: return .incomplete
                    case .tropLongue: return finir(.longueurFausse)
                    case .ligne(let l):
                        guard let n = Self.entier(l), n > 0, n <= EnvoiPasseur.tailleMax else {
                            return finir(.longueurFausse)
                        }
                        etape = .json(n)
                    }
                case .json(let n):
                    guard tampon.count >= n else { return .incomplete }
                    return finir(.json(Data(tampon.prefix(n))))
                }
            }
        }

        /// La connexion s'est fermee : une trame inachevee est fausse.
        public func fin() -> Issue {
            switch etape {
            case .finie(let issue): issue
            case .jeton: .jetonFaux
            case .longueur, .json: .longueurFausse
            }
        }

        /// Premiere ligne du tampon, sans sa fin, retiree du tampon : au plus `max` octets.
        private mutating func prendreLigne(auPlus max: Int) -> Ligne {
            guard let fin = tampon.firstIndex(of: 0x0A) else {
                return tampon.count > max ? .tropLongue : .manque
            }
            let ligne = Array(tampon[tampon.startIndex..<fin])
            tampon.removeSubrange(tampon.startIndex...fin)
            return ligne.count > max ? .tropLongue : .ligne(ligne)
        }

        private mutating func finir(_ issue: Issue) -> Issue {
            etape = .finie(issue)
            tampon = Data()
            return issue
        }

        /// Entier ecrit en chiffres decimaux seuls (ni signe ni espace).
        static func entier(_ l: [UInt8]) -> Int? {
            guard !l.isEmpty, l.count <= chiffresMax, l.allSatisfy({ (0x30...0x39).contains($0) }) else { return nil }
            return l.reduce(0) { $0 * 10 + Int($1 - 0x30) }
        }

        /// Comparaison a temps constant : sa duree ne depend pas de la place du premier ecart.
        static func egaux(_ a: [UInt8], _ b: [UInt8]) -> Bool {
            guard a.count == b.count else { return false }
            var ecart: UInt8 = 0
            for (x, y) in zip(a, b) { ecart |= x ^ y }
            return ecart == 0
        }
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh MaillageCoeurTests/EnvoiPasseurTests`
Expected: `Test run with 6 tests in 1 suite passed` (`EnvoiPasseurTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement ; 6 tests et 1 suite de plus pour le cœur, l'app inchangée (au rejeu : 236 tests en 22 suites, et 216 en 24 suites).

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Noms/EnvoiPasseur.swift MaillageCoeurTests/EnvoiPasseurTests.swift
git commit -m "Decrire la trame du passeur par la boucle locale : cible, jeton, lecture bornee

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: App : `NomsInternes`, le relevé par la boucle locale

**Files:**
- Create: `MaillageThread/Noms/NomsInternes.swift`, `MaillageThread/Noms/EcouteReleve.swift`
- Delete: `MaillageThread/Noms/DossierNoms.swift`, `MaillageThreadTests/DossierNomsTests.swift`
- Modify: `MaillageThread/Droits.entitlements`, `MaillageThread/MaillageThreadApp.swift`, `MaillageThread/Vues/FenetreReglages.swift`, `MaillageThread/Vues/MenuBarre.swift`, `MaillageThread/Vues/Graphe/FenetreGraphe.swift` (blocs ci-dessous) ; `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` (Step 4)
- Test: `MaillageThreadTests/NomsInternesTests.swift` ; `MaillageThreadTests/GrapheTests.swift` (blocs ci-dessous)

**Interfaces:**
- Consumes : `ZoneMaison` (tâche 1) ; `EnvoiPasseur.Cible`, `EnvoiPasseur.nouveauJeton()`, `EnvoiPasseur.Lecture`, `EnvoiPasseur.trame` (tâche 2, les tests) ; `NomsMaison.lire`, `Surveillance.dossierParDefaut`, existants.
- Produces :
  - `@MainActor @Observable final class NomsInternes`, qui remplace `DossierNoms` :
    - `init(cache: URL?, delai: Duration = NomsInternes.delaiParDefaut, lanceur: @escaping NomsInternes.Lanceur = NomsInternes.lancerPasseurDuMac)` : `cache` nil (démo, tests) : aucun relevé lu, écrit ni demandé ;
    - `noms: NomsMaison?` (le dernier relevé valide), `probleme: String?`, `releveEnCours: Bool`, `surNoms: ((NomsMaison?) -> Void)?`, `derniereDemande: Date?` ;
    - `demarrer()`, `lancerPasseur()` (une seule écoute à la fois), `integrer(_ n: NomsMaison)`, `rafraichirSiAncien(maintenant:)` ;
    - statiques : `fichier` (`"noms.json"`), `idPasseur`, `validite` (7 jours), `fraicheur` (15 min), `delaiParDefaut` (120 s), `fichierCache(demo:sousTests:) -> URL?`, `doitRafraichir(memoire:releve:demande:maintenant:)`, `aRafraichir(releve:demande:maintenant:)`, `retenir(_:ancien:)`, `estAncien(_:maintenant:)`, `lancerPasseurDuMac(_:)` ;
    - `typealias Lanceur = @MainActor (_ arguments: [String]) async -> String?` (nil : lancé ; sinon le problème à montrer) ; `enum Fin` (`.recu(Data)`, `.jetonFaux`, `.longueurFausse`, `.delai`, `.lancement(String)`, `.ecoute(String)`) ;
  - `@MainActor final class EcouteReleve` : `init(jeton:)`, `jeton`, `ouvrir(_ suite: @escaping (EcouteReleve.Evenement) -> Void)`, `fermer()` ; `Evenement` : `.prete(UInt16)` (le port), `.fin(NomsInternes.Fin)` ;
  - `FenetreReglages.texteZones(_ zones: [ZoneMaison]) -> String` ; `BarreOutils.lancePasseur(mode:)`, sans `dossierChoisi` ;
  - dans les tests : `FauxPasseur.envoyer(_ octets: Data, port: UInt16) async -> Bool` (vrai si l'app a fermé la connexion, faux si rien n'écoute), `LancementsPasseur` (`noter`, `tous`, `cible`) ;
  - `DossierNoms`, son choix de dossier, son signet et le dépôt de `passeur-demande.json` disparaissent. `DemandePasseur` reste dans le cœur jusqu'à la tâche 4 : le passeur s'en sert encore.

- [ ] **Step 1 : écrire les tests.** Le faux passeur et les cas de la spec (section 10) ; les anciens tests de `DossierNoms` qui restent vrais y sont repris (`echecGardeLesNoms`, `ancien`, `memoireDesNoms`, `aRafraichir`) ; le bouton rafraîchir du graphe.

`MaillageThreadTests/NomsInternesTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Network
import Synchronization
import Testing
@testable import MaillageThread

/// Faux passeur des tests : un client TCP sur 127.0.0.1. Il envoie des octets et ferme son
/// cote, puis attend que l'app ferme la connexion, comme le vrai passeur ; vrai si elle l'a
/// fermee, faux si la connexion a echoue (rien n'ecoute sur ce port).
enum FauxPasseur {
    static func envoyer(_ octets: Data, port: UInt16) async -> Bool {
        guard let p = NWEndpoint.Port(rawValue: port) else { return false }
        let c = NWConnection(host: "127.0.0.1", port: p, using: .tcp)
        let fermee = await withCheckedContinuation { (suite: CheckedContinuation<Bool, Never>) in
            let reprise = Reprise(suite)
            c.stateUpdateHandler = { etat in
                switch etat {
                case .ready:
                    c.send(content: octets, contentContext: .finalMessage, isComplete: true,
                           completion: .contentProcessed { erreur in
                        guard erreur == nil else { return reprise.reprendre(false) }
                        c.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, fin, e in
                            reprise.reprendre(fin || e != nil)
                        }
                    })
                case .waiting, .failed: reprise.reprendre(false)
                default: break
                }
            }
            c.start(queue: .global())
        }
        c.cancel()
        return fermee
    }

    /// Reprend la continuation une seule fois, depuis n'importe quel fil.
    final class Reprise: Sendable {
        private let suite: Mutex<CheckedContinuation<Bool, Never>?>

        init(_ suite: CheckedContinuation<Bool, Never>) {
            self.suite = Mutex(suite)
        }

        func reprendre(_ fermee: Bool) {
            suite.withLock { $0.take() }?.resume(returning: fermee)
        }
    }
}

/// Lancements du passeur demandes par l'app, dans l'ordre (leurs arguments).
final class LancementsPasseur: Sendable {
    private let liste = Mutex<[[String]]>([])

    func noter(_ arguments: [String]) {
        liste.withLock { $0.append(arguments) }
    }

    var tous: [[String]] { liste.withLock { $0 } }
    /// Port et jeton du dernier lancement.
    var cible: EnvoiPasseur.Cible? { tous.last.flatMap { EnvoiPasseur.Cible(arguments: $0) } }
}

@MainActor
@Suite("Noms de Maison : releve du passeur par la boucle locale", .timeLimit(.minutes(1)))
struct NomsInternesTests {
    static let date = Date(timeIntervalSince1970: 1_790_000_000)

    static func noms(_ statut: StatutPasseur = .ok, nom: String = "Halo", message: String? = nil) -> NomsMaison {
        NomsMaison(date: date, statut: statut, message: message,
                   accessoires: statut == .ok ? [AccessoireMaison(nom: nom, noeudMatter: "00000000000002E9")] : [],
                   zones: statut == .ok ? [ZoneMaison(nom: "Étage", pieces: ["Bureau"])] : nil)
    }

    /// `noms.json` dans un dossier temporaire unique, a effacer apres le test.
    static func cache() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("noms-\(UUID().uuidString)")
            .appendingPathComponent(NomsInternes.fichier)
    }

    /// Faux lanceur : note chaque lancement ; puis, comme le passeur, envoie a l'ecoute les
    /// octets que `trame` tire du jeton recu (nil : il ne se connecte pas). `probleme` : le
    /// lancement echoue, rien n'est envoye.
    static func lanceur(_ lancements: LancementsPasseur, probleme: String? = nil,
                        trame: (@Sendable (String) -> Data)? = nil) -> NomsInternes.Lanceur {
        { arguments in
            lancements.noter(arguments)
            if let probleme { return probleme }
            if let trame, let cible = EnvoiPasseur.Cible(arguments: arguments) {
                Task.detached { _ = await FauxPasseur.envoyer(trame(cible.jeton), port: cible.port) }
            }
            return nil
        }
    }

    /// Trame du vrai passeur, avec le jeton recu.
    static func bonneTrame(_ n: NomsMaison) throws -> @Sendable (String) -> Data {
        let json = try n.donnees()
        return { EnvoiPasseur.trame(jeton: $0, json: json) }
    }

    /// Demande un releve et attend sa fin, au plus `delai`.
    static func releve(_ n: NomsInternes, delai: Duration = .seconds(10)) async {
        n.lancerPasseur()
        let fin = ContinuousClock.now + delai
        while n.releveEnCours, ContinuousClock.now < fin { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(!n.releveEnCours, "releve fini")
    }

    /// Textes de l'app, dans la langue de l'hote des tests.
    static let refus = String(localized: "Accès à Maison refusé au passeur : Réglages Système › Confidentialité et sécurité › Maison.")
    static let jetonFaux = String(localized: "Relevé de Maison refusé : jeton faux.")
    static let longueurFausse = String(localized: "Relevé de Maison illisible : longueur fausse.")

    /// Un releve reussi remplace les noms ; un echec du passeur les garde et dit
    /// pourquoi, avec les textes de l'app : le message du passeur (en francais
    /// seulement) n'est que le detail d'une erreur.
    @Test func echecGardeLesNoms() {
        let ancien = Self.noms(nom: "Halo")
        let (garde, probleme) = NomsInternes.retenir(Self.noms(.refuse, message: "Accès refusé"), ancien: ancien)
        #expect(garde == ancien)
        #expect(probleme == Self.refus)
        let (_, indisponible) = NomsInternes.retenir(Self.noms(.indisponible, message: "Capacité absente"), ancien: ancien)
        #expect(indisponible == String(localized: "HomeKit indisponible pour le passeur."))
        let (gardeAussi, erreur) = NomsInternes.retenir(Self.noms(.erreur, message: "Aucun domicile dans Maison"), ancien: ancien)
        #expect(gardeAussi == ancien)
        #expect(erreur == String(localized: "Le passeur a échoué : \("Aucun domicile dans Maison")"))
        let (_, sansDetail) = NomsInternes.retenir(Self.noms(.erreur), ancien: nil)
        #expect(sansDetail == String(localized: "Le passeur a échoué."))
        let (neuf, rien) = NomsInternes.retenir(Self.noms(nom: "Pont"), ancien: ancien)
        #expect(neuf?.accessoires.first?.nom == "Pont")
        #expect(rien == nil)
    }

    /// Au-dela de 7 jours, le profil gratuit du passeur a expire.
    @Test func ancien() {
        #expect(!NomsInternes.estAncien(Self.noms(), maintenant: Self.date + 6 * 86_400))
        #expect(NomsInternes.estAncien(Self.noms(), maintenant: Self.date + 8 * 86_400))
    }

    /// Les noms retenus sont ecrits dans le conteneur et relus au lancement ; un echec ne les
    /// efface pas.
    @Test func memoireDesNoms() throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let n = NomsInternes(cache: cache)
        #expect(n.noms == nil)
        var recus: [NomsMaison?] = []
        n.surNoms = { recus.append($0) }
        n.integrer(Self.noms())
        n.integrer(Self.noms(.refuse, message: "Accès refusé"))
        #expect(n.noms == Self.noms(), "l'echec n'efface pas les noms")
        #expect(n.probleme == Self.refus)
        #expect(recus == [Self.noms()], "un seul changement")
        #expect(NomsInternes(cache: cache).noms == Self.noms(), "relus au lancement")
    }

    /// Relance a l'ouverture du graphe : releve absent ou de plus de 15 min, et
    /// pas de demande dans les 15 dernieres minutes (pas de relance en boucle).
    @Test func aRafraichir() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(NomsInternes.aRafraichir(releve: nil, demande: nil, maintenant: t))
        #expect(!NomsInternes.aRafraichir(releve: t.addingTimeInterval(-14 * 60), demande: nil, maintenant: t))
        #expect(NomsInternes.aRafraichir(releve: t.addingTimeInterval(-16 * 60), demande: nil, maintenant: t))
        #expect(!NomsInternes.aRafraichir(releve: t.addingTimeInterval(-3600), demande: t.addingTimeInterval(-60),
                                          maintenant: t), "demande recente : le passeur ne s'est peut-etre pas lance")
        #expect(NomsInternes.aRafraichir(releve: t.addingTimeInterval(-3600), demande: t.addingTimeInterval(-16 * 60),
                                         maintenant: t))
    }

    /// Sans memoire (demo, tests) : l'ouverture du graphe ne lance jamais le passeur, meme avec
    /// un releve ancien ; le bouton non plus.
    @Test func sansMemoire() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let ancien = t.addingTimeInterval(-3600)
        #expect(NomsInternes.doitRafraichir(memoire: true, releve: ancien, demande: nil, maintenant: t))
        #expect(!NomsInternes.doitRafraichir(memoire: false, releve: ancien, demande: nil, maintenant: t))
        #expect(!NomsInternes.doitRafraichir(memoire: true, releve: t, demande: nil, maintenant: t))
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: nil, lanceur: Self.lanceur(lancements))
        n.rafraichirSiAncien()
        n.lancerPasseur()
        #expect(!n.releveEnCours)
        #expect(lancements.tous.isEmpty)
    }

    /// Un bon jeton : le passeur est lance avec le port de l'ecoute et un jeton de 64 chiffres ;
    /// le releve est retenu, ecrit dans le conteneur et relu au lancement ; l'ecoute est fermee.
    @Test func bonJeton() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(lancements, trame: try Self.bonneTrame(Self.noms())))
        var recus: [NomsMaison?] = []
        n.surNoms = { recus.append($0) }
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == nil)
        #expect(recus == [Self.noms()])
        #expect(try NomsMaison.lire(Data(contentsOf: cache)) == Self.noms(), "ecrit dans le conteneur")
        #expect(NomsInternes(cache: cache).noms == Self.noms(), "relu au lancement")
        let cible = try #require(lancements.cible)
        #expect(lancements.tous.count == 1)
        #expect(cible.jeton.count == 64)
        #expect(await !FauxPasseur.envoyer(Data("encore".utf8), port: cible.port), "ecoute fermee")
    }

    /// Le passeur a pu lire Maison, mais l'acces lui est refuse : les noms gardes restent.
    @Test func refusDeMaison() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(LancementsPasseur(),
                                                                trame: try Self.bonneTrame(Self.noms(.refuse, message: "Accès refusé"))))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == Self.refus)
    }

    /// Un mauvais jeton : rien n'est retenu ni ecrit, le dernier releve valide reste.
    @Test func mauvaisJeton() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let json = try Self.noms(nom: "Intrus").donnees()
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(LancementsPasseur(), trame: { jeton in
            EnvoiPasseur.trame(jeton: String(jeton.reversed()), json: json)
        }))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == Self.jetonFaux)
        #expect(try NomsMaison.lire(Data(contentsOf: cache)) == Self.noms(), "fichier inchange")
    }

    /// Une longueur fausse (illisible, au-dela de 8 Mo, ou plus longue que la trame) : le
    /// dernier releve valide reste.
    @Test func longueurFausse() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let json = try Self.noms(nom: "Intrus").donnees()
        for longueur in ["abc", String(EnvoiPasseur.tailleMax + 1), String(json.count + 10)] {
            let n = NomsInternes(cache: cache, lanceur: Self.lanceur(LancementsPasseur(), trame: { jeton in
                Data("\(jeton)\n\(longueur)\n".utf8) + json
            }))
            n.integrer(Self.noms())
            await Self.releve(n)
            #expect(n.noms == Self.noms(), "longueur \(longueur)")
            #expect(n.probleme == Self.longueurFausse, "longueur \(longueur)")
        }
    }

    /// Un JSON illisible : le dernier releve valide reste, et le detail est dit.
    @Test func jsonIllisible() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(LancementsPasseur(), trame: { jeton in
            EnvoiPasseur.trame(jeton: jeton, json: Data("pas du json".utf8))
        }))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        let debut = String(localized: "Relevé de Maison illisible : \("")")
        #expect(n.probleme?.hasPrefix(debut) == true && n.probleme != Self.longueurFausse, "\(n.probleme ?? "")")
    }

    /// Rien dans le delai (le passeur ne se connecte pas) : le dernier releve valide reste, et
    /// l'ecoute est fermee. (Delai d'une seconde : l'ecoute est prete bien avant.)
    @Test func delaiDepasse() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: cache, delai: .seconds(1), lanceur: Self.lanceur(lancements))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == String(localized: "Passeur Noms n'a rien envoyé en 2 minutes."))
        let cible = try #require(lancements.cible)
        #expect(await !FauxPasseur.envoyer(try Self.bonneTrame(Self.noms(nom: "Tard"))(cible.jeton), port: cible.port),
                "ecoute fermee")
        #expect(n.noms == Self.noms())
    }

    /// Passeur introuvable, ou lancement refuse : le probleme est dit, l'ecoute fermee, les noms gardes.
    @Test func lancementRefuse() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let introuvable = String(localized: "Passeur Noms introuvable : lance outils/passeur.sh.")
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(lancements, probleme: introuvable))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == introuvable)
        let cible = try #require(lancements.cible)
        #expect(await !FauxPasseur.envoyer(Data("x".utf8), port: cible.port), "ecoute fermee")
    }

    /// Une seule ecoute a la fois : une demande pendant un releve est ignoree ; une fois le
    /// releve fini, une autre demande lance de nouveau le passeur, avec un autre jeton.
    @Test func uneSeuleEcoute() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(lancements))
        n.lancerPasseur()
        let premiere = n.derniereDemande
        let fin = ContinuousClock.now + .seconds(10)
        while lancements.tous.isEmpty, ContinuousClock.now < fin { try? await Task.sleep(for: .milliseconds(5)) }
        n.lancerPasseur()
        n.rafraichirSiAncien(maintenant: .now + 3600)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(lancements.tous.count == 1, "demandes ignorees pendant le releve")
        #expect(n.derniereDemande == premiere)
        let cible = try #require(lancements.cible)
        #expect(await FauxPasseur.envoyer(try Self.bonneTrame(Self.noms())(cible.jeton), port: cible.port))
        #expect(!n.releveEnCours)
        #expect(n.noms == Self.noms())
        n.lancerPasseur()
        #expect(n.releveEnCours)
        while lancements.tous.count < 2, ContinuousClock.now < fin { try? await Task.sleep(for: .milliseconds(5)) }
        let seconde = try #require(lancements.cible)
        #expect(seconde.jeton != cible.jeton, "jeton a usage unique")
        #expect(await FauxPasseur.envoyer(try Self.bonneTrame(Self.noms(nom: "Pont"))(seconde.jeton), port: seconde.port))
        #expect(n.noms == Self.noms(nom: "Pont"))
    }

    /// Reglages › Noms de Maison : les zones lues, dans l'ordre de Maison.
    @Test func zonesDansLesReglages() {
        #expect(FenetreReglages.texteZones([ZoneMaison(nom: "Rez-de-chaussée"), ZoneMaison(nom: "Étage")])
                == "Rez-de-chaussée, Étage")
        #expect(FenetreReglages.texteZones([]) == String(localized: "aucune zone dans Maison"))
    }
}
```

Supprimer `MaillageThreadTests/DossierNomsTests.swift` :

```bash
git rm MaillageThreadTests/DossierNomsTests.swift
```

Dans `MaillageThreadTests/GrapheTests.swift`, remplacer :

```swift
    /// Le bouton rafraichir du graphe lance aussi le passeur des noms de Maison, en mode direct
    /// et seulement si un dossier des noms est choisi (« Rafraichir depuis Maison », lui, demande
    /// le dossier s'il manque).
    @Test func rafraichirLanceLePasseurAvecUnDossier() {
        #expect(BarreOutils.lancePasseur(mode: .direct, dossierChoisi: true))
        #expect(!BarreOutils.lancePasseur(mode: .direct, dossierChoisi: false),
                "sans dossier : pas de passeur au premier plan a chaque clic")
        #expect(!BarreOutils.lancePasseur(mode: .demo, dossierChoisi: true))
        #expect(!BarreOutils.lancePasseur(mode: .demo, dossierChoisi: false))
```

par :

```swift
    /// Le bouton rafraichir du graphe lance aussi le passeur des noms de Maison, en mode direct
    /// seulement : plus de dossier des noms a choisir.
    @Test func rafraichirLanceLePasseurEnModeDirect() {
        #expect(BarreOutils.lancePasseur(mode: .direct))
        #expect(!BarreOutils.lancePasseur(mode: .demo))
```

Dans `MaillageThreadTests/GrapheTests.swift`, remplacer :

```swift
        let sansReseau = Surveillance(mode: .direct, dossier: nil)
        let noms = DossierNoms(cache: nil)
```

par :

```swift
        let sansReseau = Surveillance(mode: .direct, dossier: nil)
        let noms = NomsInternes(cache: nil)
```

Dans `MaillageThreadTests/GrapheTests.swift`, remplacer :

```swift
        let surveillance = Surveillance(mode: .direct, dossier: nil)
        let noms = DossierNoms(cache: nil)
```

par :

```swift
        let surveillance = Surveillance(mode: .direct, dossier: nil)
        let noms = NomsInternes(cache: nil)
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh MaillageThreadTests/NomsInternesTests MaillageThreadTests/GrapheTests`
Expected: la compilation des tests de l'app échoue, par exemple avec `error: cannot find 'NomsInternes' in scope`, `error: cannot find type 'NomsInternes' in scope` et `error: type 'FenetreReglages' has no member 'texteZones'`.

- [ ] **Step 3 : écrire le code.** Le modèle et l'écoute, la suppression de `DossierNoms`, le droit d'écouter, puis l'app, les Réglages, le menu et le graphe. Sans `com.apple.security.network.server`, les tests d'écoute échouent : `n.probleme` vaut « Écoute du relevé impossible : … (Network.NWError erreur 1 - Operation not permitted) », et le journal des tests montre `bind(…, 127.0.0.1:0) … failed [1: Operation not permitted]` (constaté dans la copie validée). Le droit est dans les blocs ci-dessous.

`MaillageThread/Noms/NomsInternes.swift` :

```swift
import AppKit
import Foundation
import MaillageCoeur
import Observation

/// Noms de Maison, releves par le passeur (app iOS lancee sur le Mac) et gardes dans le
/// conteneur de l'app (`noms.json`), sans dossier a choisir. Un releve : une ecoute TCP sur
/// 127.0.0.1 (`EcouteReleve`) et un jeton a usage unique ; le passeur, lance sans activation
/// avec `--port` et `--jeton`, lit Maison, envoie le releve (`EnvoiPasseur`) et se ferme.
/// Le dernier releve valide est garde : un echec ne l'efface jamais, il se dit dans `probleme`.
@MainActor
@Observable
final class NomsInternes {
    /// Lance le passeur avec ces arguments ; nil s'il est lance, sinon le probleme a montrer.
    typealias Lanceur = @MainActor (_ arguments: [String]) async -> String?

    /// Fin d'un releve.
    enum Fin: Equatable {
        /// Le JSON du passeur, de la longueur annoncee, a decoder.
        case recu(Data)
        case jetonFaux
        case longueurFausse
        /// Aucun releve dans le delai.
        case delai
        /// Passeur introuvable ou lancement refuse : le probleme a montrer.
        case lancement(String)
        /// Ecoute impossible : la cause.
        case ecoute(String)
    }

    nonisolated static let fichier = "noms.json"
    nonisolated static let idPasseur = "fr.djoko.maillage.passeur"
    /// Profil gratuit du passeur : 7 jours ; au-dela, il faut le recompiler.
    nonisolated static let validite: TimeInterval = 7 * 24 * 3600
    /// Plus recent, un releve suffit : l'ouverture du graphe ne relance pas le passeur.
    nonisolated static let fraicheur: TimeInterval = 15 * 60
    /// Attente d'un releve : le premier lancement attend la reponse a la demande d'acces a Maison.
    nonisolated static let delaiParDefaut: Duration = .seconds(120)

    /// Dernier releve valide.
    private(set) var noms: NomsMaison?
    /// Dernier probleme : releve refuse ou illisible, rien dans le delai, passeur introuvable ou
    /// qui ne se lance pas, acces a Maison refuse, ecriture impossible.
    private(set) var probleme: String?
    /// Une ecoute est ouverte : le passeur est lance, ou va l'etre.
    private(set) var releveEnCours = false
    /// Appele a chaque changement des noms retenus.
    @ObservationIgnored var surNoms: ((NomsMaison?) -> Void)?
    /// Derniere demande de releve.
    @ObservationIgnored private(set) var derniereDemande: Date?

    @ObservationIgnored private let cache: URL?
    @ObservationIgnored private let delai: Duration
    @ObservationIgnored private let lanceur: Lanceur
    @ObservationIgnored private var ecoute: EcouteReleve?
    @ObservationIgnored private var minuterie: Task<Void, Never>?

    /// `cache` : le `noms.json` de l'app ; nil (mode demo, tests) : aucun releve lu, ecrit ni
    /// demande. `lanceur` : le vrai passeur par defaut, un faux dans les tests.
    init(cache: URL?, delai: Duration = NomsInternes.delaiParDefaut,
         lanceur: @escaping Lanceur = NomsInternes.lancerPasseurDuMac) {
        self.cache = cache
        self.delai = delai
        self.lanceur = lanceur
        noms = cache.flatMap { try? NomsMaison.lire(Data(contentsOf: $0)) }
    }

    /// `noms.json` dans le dossier de l'app, a cote de `identites-routeurs.json` ; nil en demo et
    /// sous les tests.
    static func fichierCache(demo: Bool, sousTests: Bool) -> URL? {
        demo || sousTests ? nil : Surveillance.dossierParDefaut.appendingPathComponent(fichier)
    }

    /// Donne les noms gardes.
    func demarrer() {
        surNoms?(noms)
    }

    /// Demande un releve : ouvre l'ecoute, puis lance le passeur avec son port et un jeton neuf.
    /// Une seule ecoute a la fois : une demande pendant un releve est ignoree. Jamais sans memoire.
    func lancerPasseur() {
        guard cache != nil, ecoute == nil else { return }
        derniereDemande = .now
        let e = EcouteReleve(jeton: EnvoiPasseur.nouveauJeton())
        ecoute = e
        releveEnCours = true
        minuterie = Task { [weak self, delai] in
            try? await Task.sleep(for: delai)
            guard !Task.isCancelled else { return }
            self?.finir(e, .delai)
        }
        e.ouvrir { [weak self] evenement in
            self?.surEcoute(e, evenement)
        }
    }

    private func surEcoute(_ e: EcouteReleve, _ evenement: EcouteReleve.Evenement) {
        guard ecoute === e else { return }
        switch evenement {
        case .prete(let port):
            let arguments = EnvoiPasseur.Cible(port: port, jeton: e.jeton).arguments
            Task { [weak self] in
                guard let self, let p = await self.lanceur(arguments) else { return }
                self.finir(e, .lancement(p))
            }
        case .fin(let fin):
            finir(e, fin)
        }
    }

    /// Ferme l'ecoute et retient l'issue du releve (sauf s'il est deja fini).
    private func finir(_ e: EcouteReleve, _ fin: Fin) {
        guard ecoute === e else { return }
        ecoute = nil
        e.fermer()
        minuterie?.cancel()
        minuterie = nil
        releveEnCours = false
        switch fin {
        case .recu(let json):
            do {
                integrer(try NomsMaison.lire(json))
            } catch {
                probleme = String(localized: "Relevé de Maison illisible : \(error.localizedDescription)")
            }
        case .jetonFaux: probleme = String(localized: "Relevé de Maison refusé : jeton faux.")
        case .longueurFausse: probleme = String(localized: "Relevé de Maison illisible : longueur fausse.")
        case .delai: probleme = String(localized: "Passeur Noms n'a rien envoyé en 2 minutes.")
        case .lancement(let p): probleme = p
        case .ecoute(let cause): probleme = String(localized: "Écoute du relevé impossible : \(cause)")
        }
    }

    /// Retient un releve recu : les noms s'il est reussi, sinon le probleme ; les noms retenus
    /// sont ecrits dans le conteneur, d'un coup (ecriture atomique).
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

    /// Lanceur reel : Passeur Noms, installe par outils/passeur.sh, sans activation ; ses
    /// arguments lui donnent le port et le jeton.
    static func lancerPasseurDuMac(_ arguments: [String]) async -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: idPasseur) else {
            return String(localized: "Passeur Noms introuvable : lance outils/passeur.sh.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.arguments = arguments
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            return nil
        } catch {
            // Cause la plus probable apres quelques jours : le profil gratuit a expire.
            return String(localized: "\(error.localizedDescription) (profil de 7 jours expiré ? relance outils/passeur.sh)")
        }
    }

    /// A l'ouverture du graphe, puis toutes les heures tant qu'il reste ouvert :
    /// relance le passeur si le dernier releve a plus de 15 min. Jamais sans
    /// memoire (mode demo, tests).
    func rafraichirSiAncien(maintenant: Date = .now) {
        guard Self.doitRafraichir(memoire: cache != nil, releve: noms?.date, demande: derniereDemande,
                                  maintenant: maintenant) else { return }
        lancerPasseur()
    }

    nonisolated static func doitRafraichir(memoire: Bool, releve: Date?, demande: Date?, maintenant: Date) -> Bool {
        memoire && aRafraichir(releve: releve, demande: demande, maintenant: maintenant)
    }

    /// Releve absent ou de plus de 15 min, et pas de demande dans les 15
    /// dernieres minutes : un passeur qui ne se lance pas n'est pas relance en boucle.
    nonisolated static func aRafraichir(releve: Date?, demande: Date?, maintenant: Date) -> Bool {
        func ancien(_ d: Date?) -> Bool { d.map { maintenant.timeIntervalSince($0) > fraicheur } ?? true }
        return ancien(releve) && ancien(demande)
    }

    /// Un releve reussi remplace les noms ; un echec les garde et dit pourquoi,
    /// avec les textes de l'app : le message du passeur (en francais seulement)
    /// n'est que le detail d'une erreur.
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

    /// Noms de plus de 7 jours : le profil gratuit du passeur a expire.
    nonisolated static func estAncien(_ n: NomsMaison, maintenant: Date) -> Bool {
        maintenant.timeIntervalSince(n.date) > validite
    }
}
```

`MaillageThread/Noms/EcouteReleve.swift` :

```swift
import Foundation
import MaillageCoeur
import Network

/// Ecoute TCP d'un releve du passeur, sur 127.0.0.1 seulement et sur un port choisi par le
/// systeme (Network.framework, comme le reste de l'app). La premiere connexion est la seule
/// acceptee : l'ecoute se ferme aussitot. Sa trame est lue au fil de l'eau
/// (`EnvoiPasseur.Lecture`, au plus 8 Mo de JSON), puis la connexion est fermee : le passeur,
/// qui attend cette fermeture, sait alors que tout a ete lu. Tout se passe sur la file principale.
/// Le bac a sable de l'app exige `com.apple.security.network.server` pour ecouter, meme sur
/// la boucle locale.
@MainActor
final class EcouteReleve {
    enum Evenement: Equatable {
        /// L'ecoute est prete sur ce port : lancer le passeur.
        case prete(UInt16)
        /// Le releve est fini, recu ou non ; l'ecoute et la connexion sont fermees.
        case fin(NomsInternes.Fin)
    }

    /// Jeton attendu du passeur, a usage unique.
    let jeton: String
    private var lecture: EnvoiPasseur.Lecture
    private var ecouteur: NWListener?
    private var connexion: NWConnection?
    private var suite: ((Evenement) -> Void)?
    private var pret = false

    init(jeton: String) {
        self.jeton = jeton
        lecture = EnvoiPasseur.Lecture(jeton: jeton)
    }

    /// Ouvre l'ecoute ; `suite` recoit `.prete`, puis `.fin`, sauf apres `fermer()`.
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

    /// Une seule connexion par releve : l'ecoute se ferme des la premiere.
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
                var issue = EnvoiPasseur.Lecture.Issue.incomplete
                if let donnees, !donnees.isEmpty { issue = self.lecture.ajouter(donnees) }
                if issue == .incomplete, finie || erreur != nil { issue = self.lecture.fin() }
                switch issue {
                case .incomplete: self.recevoir(c)
                case .json(let json): self.terminer(.recu(json))
                case .jetonFaux: self.terminer(.jetonFaux)
                case .longueurFausse: self.terminer(.longueurFausse)
                }
            }
        }
    }

    private func terminer(_ fin: NomsInternes.Fin) {
        guard let suite else { return }
        fermer()
        suite(.fin(fin))
    }
}
```

Supprimer `MaillageThread/Noms/DossierNoms.swift` :

```bash
git rm MaillageThread/Noms/DossierNoms.swift
```

Dans `MaillageThread/Droits.entitlements`, remplacer :

```xml
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
	<key>com.apple.security.files.bookmarks.app-scope</key>
	<true/>
	<key>com.apple.security.device.serial</key>
```

par :

```xml
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.network.server</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
	<key>com.apple.security.device.serial</key>
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
    @State private var nomsMaison: DossierNoms
```

par :

```swift
    @State private var nomsMaison: NomsInternes
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
        // Sans memoire en demo et sous tests : ni les vraies preferences ni le vrai signet.
        let d = DossierNoms(cache: Self.demo || Surveillance.sousTests
                            ? nil : Surveillance.dossierParDefaut.appendingPathComponent("noms-maison.json"))
```

par :

```swift
        // Sans memoire en demo et sous tests : aucun releve lu, ecrit ni demande au passeur.
        let d = NomsInternes(cache: NomsInternes.fichierCache(demo: Self.demo, sousTests: Surveillance.sousTests))
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
/// noms de Maison (dossier du passeur), sonde (liaison USB ou reseau Thread, acces
```

par :

```swift
/// noms de Maison (releve du passeur), sonde (liaison USB ou reseau Thread, acces
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
    @Environment(DossierNoms.self) private var nomsMaison
```

par :

```swift
    @Environment(NomsInternes.self) private var nomsMaison
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
            Section("Noms de Maison") {
                LabeledContent("Dossier des noms") {
                    HStack {
                        Text(nomsMaison.dossier?.path(percentEncoded: false) ?? "—")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choisir…") { nomsMaison.choisir() }
                            .disabled(surveillance.mode == .demo)
                    }
                }
                if let n = nomsMaison.noms {
                    LabeledContent("Noms lus",
                                   value: String(localized: "\(n.accessoires.count) accessoires · \(n.date.formatted(date: .abbreviated, time: .shortened))"))
                    if DossierNoms.estAncien(n, maintenant: .now) {
                        Text("Noms du \(n.date.formatted(date: .abbreviated, time: .omitted)) : relance outils/passeur.sh pour les rafraîchir.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let p = nomsMaison.probleme {
                    Text(p).font(.caption).foregroundStyle(.red)
                }
                Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                    .disabled(surveillance.mode == .demo)
            }
            Section("Sonde") {
```

par :

```swift
            Section("Noms de Maison") {
                if let n = nomsMaison.noms {
                    LabeledContent("Noms lus",
                                   value: String(localized: "\(n.accessoires.count) accessoires · \(n.date.formatted(date: .abbreviated, time: .shortened))"))
                    // Rien pour un releve d'avant les zones.
                    if let zones = n.zones {
                        LabeledContent("Zones", value: Self.texteZones(zones))
                    }
                    if NomsInternes.estAncien(n, maintenant: .now) {
                        Text("Noms du \(n.date.formatted(date: .abbreviated, time: .omitted)) : relance outils/passeur.sh pour les rafraîchir.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let p = nomsMaison.probleme {
                    Text(p).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    // Une demande pendant un releve serait ignoree.
                    Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                        .disabled(surveillance.mode == .demo || nomsMaison.releveEnCours)
                    if nomsMaison.releveEnCours {
                        ProgressView().controlSize(.small)
                    }
                }
            }
            Section("Sonde") {
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
    /// Libelle d'un port dans le choix : la sonde retenue sous son nom seul ; tout autre port,
```

par :

```swift
    /// Zones de Maison lues par le passeur, dans l'ordre de Maison : « Rez-de-chaussee, Etage ».
    static func texteZones(_ zones: [ZoneMaison]) -> String {
        zones.isEmpty ? String(localized: "aucune zone dans Maison") : zones.map(\.nom).joined(separator: ", ")
    }

    /// Libelle d'un port dans le choix : la sonde retenue sous son nom seul ; tout autre port,
```

Dans `MaillageThread/Vues/MenuBarre.swift`, remplacer :

```swift
    @Environment(DossierNoms.self) private var nomsMaison
```

par :

```swift
    @Environment(NomsInternes.self) private var nomsMaison
```

Dans `MaillageThread/Vues/MenuBarre.swift`, remplacer :

```swift
                    Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                    if let p = nomsMaison.probleme {
```

par :

```swift
                    // Une demande pendant un releve serait ignoree.
                    Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                        .disabled(nomsMaison.releveEnCours)
                    if let p = nomsMaison.probleme {
```

Dans `MaillageThread/Vues/Graphe/FenetreGraphe.swift`, remplacer :

```swift
struct FenetreGraphe: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(DossierNoms.self) private var nomsMaison
```

par :

```swift
struct FenetreGraphe: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(NomsInternes.self) private var nomsMaison
```

Dans `MaillageThread/Vues/Graphe/FenetreGraphe.swift`, remplacer :

```swift
/// Barre d'outils flottante : reseau, appareils IP, journal, rafraichir.
struct BarreOutils: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(SondeMaillage.self) private var sonde
    @Environment(DossierNoms.self) private var nomsMaison
    @Environment(\.openWindow) private var openWindow
    @State private var appareilsIP = false

    /// Rafraichir lance aussi le passeur des noms de Maison, en mode direct, et seulement si un
    /// dossier des noms est choisi : sans dossier, le passeur passerait au premier plan a chaque
    /// clic pour en demander un (« Rafraichir depuis Maison », lui, le demande s'il manque).
    static func lancePasseur(mode: Surveillance.Mode, dossierChoisi: Bool) -> Bool {
        mode == .direct && dossierChoisi
```

par :

```swift
/// Barre d'outils flottante : reseau, appareils IP, journal, rafraichir.
struct BarreOutils: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(SondeMaillage.self) private var sonde
    @Environment(NomsInternes.self) private var nomsMaison
    @Environment(\.openWindow) private var openWindow
    @State private var appareilsIP = false

    /// Rafraichir lance aussi le passeur des noms de Maison, en mode direct seulement (sauf
    /// pendant un releve, qui ignore la demande).
    static func lancePasseur(mode: Surveillance.Mode) -> Bool {
        mode == .direct
```

Dans `MaillageThread/Vues/Graphe/FenetreGraphe.swift`, remplacer :

```swift
                    if Self.lancePasseur(mode: surveillance.mode, dossierChoisi: nomsMaison.dossier != nil) {
                        nomsMaison.lancerPasseur()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .help(Self.aideRafraichir(tournee: sonde.tourneeAuRafraichir,
                                          passeur: Self.lancePasseur(mode: surveillance.mode,
                                                                     dossierChoisi: nomsMaison.dossier != nil)))
```

par :

```swift
                    if Self.lancePasseur(mode: surveillance.mode) {
                        nomsMaison.lancerPasseur()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .help(Self.aideRafraichir(tournee: sonde.tourneeAuRafraichir,
                                          passeur: Self.lancePasseur(mode: surveillance.mode)))
```

- [ ] **Step 4 : textes, en français et en anglais.** Compiler, puis mettre le catalogue à jour avec les clés que le compilateur a extraites :

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh MaillageThreadTests/NomsInternesTests MaillageThreadTests/GrapheTests
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" outils/synchroniser-textes.sh
```

Expected : `Test run with 20 tests in 2 suites passed`, `** TEST SUCCEEDED **` (ces cibles n'incluent pas `CataloguesTests`) ; `Localizable.xcstrings` reçoit exactement ces 8 clés : « Passeur Noms n'a rien envoyé en 2 minutes. », « Relevé de Maison illisible : %@ », « Relevé de Maison illisible : longueur fausse. », « Relevé de Maison refusé : jeton faux. », « Zones », « aucune zone dans Maison », « port inconnu », « Écoute du relevé impossible : %@ » ; et ces 7 clés y sont marquées périmées (`"extractionState" : "stale"`) : « Choisir… », « Dossier des noms », « Dossier des noms inaccessible : choisis-le de nouveau (Réglages › Noms de Maison). », « Dossier des noms introuvable : choisis-le de nouveau (Réglages › Noms de Maison). », « Dossier où le passeur écrit noms.json, hors iCloud et hors du dépôt (par exemple « Maillage Thread » dans ton dossier personnel). », « Pas encore de noms.json dans ce dossier : lance le passeur. », « noms.json illisible : %@ ».

Puis les traductions, par ce script, qui retire de `interface.json` les clés mortes, y ajoute les nouvelles et le garde trié au format de l'outil ; `outils/traduire.py` retire ensuite du catalogue les clés périmées :

```bash
python3 - <<'EOF'
import json
f = 'outils/traductions/interface.json'
d = json.load(open(f, encoding='utf-8'))
for k in [
    "Choisir…",
    "Dossier des noms",
    "Dossier des noms inaccessible : choisis-le de nouveau (Réglages › Noms de Maison).",
    "Dossier des noms introuvable : choisis-le de nouveau (Réglages › Noms de Maison).",
    "Dossier où le passeur écrit noms.json, hors iCloud et hors du dépôt (par exemple « Maillage Thread » dans ton dossier personnel).",
    "Pas encore de noms.json dans ce dossier : lance le passeur.",
    "noms.json illisible : %@",
]:
    del d[k]
d.update({
    "Passeur Noms n'a rien envoyé en 2 minutes.": "Passeur Noms sent nothing within 2 minutes.",
    "Relevé de Maison illisible : %@": "Unreadable Home reading: %@",
    "Relevé de Maison illisible : longueur fausse.": "Unreadable Home reading: wrong length.",
    "Relevé de Maison refusé : jeton faux.": "Home reading refused: wrong token.",
    "Zones": "Zones",
    "aucune zone dans Maison": "no zones in Home",
    "port inconnu": "unknown port",
    "Écoute du relevé impossible : %@": "Cannot listen for the Home reading: %@",
})
open(f, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

- [ ] **Step 5 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh MaillageThreadTests/NomsInternesTests MaillageThreadTests/GrapheTests`
Expected: `Test run with 20 tests in 2 suites passed` (`NomsInternesTests` : 14, `GrapheTests` : 6), `** TEST SUCCEEDED **`.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement, `CataloguesTests` compris ; le cœur inchangé ; pour l'app, les 11 tests de `DossierNomsTests` partent et les 14 de `NomsInternesTests` arrivent : 3 tests de plus, autant de suites (au rejeu : 236 tests en 22 suites, et 219 en 24 suites).

- [ ] **Step 7 : commit.** Les deux fichiers supprimés le sont déjà par `git rm`.

```bash
git add MaillageThread/Noms/NomsInternes.swift MaillageThread/Noms/EcouteReleve.swift MaillageThread/Droits.entitlements MaillageThread/MaillageThreadApp.swift MaillageThread/Vues/FenetreReglages.swift MaillageThread/Vues/MenuBarre.swift MaillageThread/Vues/Graphe/FenetreGraphe.swift MaillageThreadTests/NomsInternesTests.swift MaillageThreadTests/GrapheTests.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Recevoir le releve du passeur par la boucle locale, sans dossier

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Passeur : l'envoi par la boucle locale et les zones

**Files:**
- Modify: `Passeur/PasseurApp.swift` (fichier entier), `project.yml`, `outils/passeur.sh`, `MaillageCoeur/Noms/NomsMaison.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/NomsTests.swift` (bloc ci-dessous : les tests de `DemandePasseur` partent avec lui)

**Interfaces:**
- Consumes : `EnvoiPasseur.Cible(arguments:)`, `EnvoiPasseur.trame(jeton:json:)` (tâche 2) ; `ZoneMaison`, `NomsMaison(…, zones:)` (tâche 1).
- Produces :
  - le passeur : `Passeur(cible: EnvoiPasseur.Cible?)`, qui lit `ProcessInfo.processInfo.arguments`, exporte `HMHome.zones` (pièces comprises, dans l'ordre de Maison), envoie la trame, puis quitte ; ouvert à la main, il n'envoie rien ;
  - `project.yml` : le passeur compile `MaillageCoeur/Noms/EnvoiPasseur.swift` ; sa description HomeKit cite les zones ;
  - `DemandePasseur` retiré du cœur, avec ses deux tests.

Aucun test automatique ne lance le passeur : il faudrait l'équipe de Djoko et Maison. Sa logique testable (arguments, trame) est dans le cœur (tâche 2) ; l'envoi réel se vérifie avec Djoko (tâche 6). Cette tâche se vérifie donc par la compilation du passeur, sans signature, et par la suite entière.

- [ ] **Step 1 : le passeur.**

Dans `project.yml`, remplacer :

```yaml
      - path: MaillageCoeur/Noms/NomsMaison.swift
      - path: MaillageCoeur/Annonces/CodageJSON.swift
```

par :

```yaml
      - path: MaillageCoeur/Noms/NomsMaison.swift
      - path: MaillageCoeur/Noms/EnvoiPasseur.swift
      - path: MaillageCoeur/Annonces/CodageJSON.swift
```

Dans `project.yml`, remplacer :

```yaml
        NSHomeKitUsageDescription: "Passeur Noms lit les noms, pièces, fabricants et batteries de vos accessoires Maison pour Maillage Thread. Rien ne sort de ce Mac."
```

par :

```yaml
        NSHomeKitUsageDescription: "Passeur Noms lit les noms, pièces, zones, fabricants et batteries de vos accessoires Maison pour Maillage Thread. Rien ne sort de ce Mac."
```

`Passeur/PasseurApp.swift`, fichier entier :

```swift
import HomeKit
import Network
import SwiftUI

/// Passeur des noms de Maison : app iOS lancee sur le Mac (« concue pour
/// iPad »), seule forme qui ait HomeKit avec une equipe gratuite. Elle lit
/// Maison (noms, pieces, zones, batteries). Lancee par Maillage Thread avec
/// `--port` et `--jeton`, elle lui envoie le releve par la boucle locale du Mac
/// (TCP sur 127.0.0.1, `EnvoiPasseur`), puis se ferme aussitot. Ouverte a la
/// main, elle n'envoie rien : elle montre ce qu'elle a lu, puis se ferme apres 10 s.
@main
struct PasseurApp: App {
    @State private var passeur = Passeur(cible: EnvoiPasseur.Cible(arguments: ProcessInfo.processInfo.arguments))

    var body: some Scene {
        WindowGroup {
            VuePasseur()
                .environment(passeur)
        }
    }
}

struct VuePasseur: View {
    @Environment(Passeur.self) private var passeur

    var body: some View {
        VStack(spacing: 16) {
            Text("Passeur Noms").font(.title2.bold())
            Text(passeur.etat).multilineTextAlignment(.center)
            if let n = passeur.fermetureDans {
                Text("Fermeture dans \(n) s").font(.caption).foregroundStyle(.secondary)
            }
            Text("Maillage Thread lance Passeur Noms quand il lui faut les noms de Maison : le relevé lui arrive par la boucle locale du Mac, sans dossier. Rien ne sort de ce Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(minWidth: 420)
        .task { passeur.demarrer() }
    }
}

@MainActor
@Observable
final class Passeur: NSObject, HMHomeManagerDelegate {
    private(set) var etat = "Lecture de Maison…"
    /// Ouvert a la main : secondes avant la fermeture, apres le releve.
    private(set) var fermetureDans: Int?
    /// Ou envoyer le releve : donne par Maillage Thread ; nil ouvert a la main.
    @ObservationIgnored private let cible: EnvoiPasseur.Cible?
    @ObservationIgnored private var gestionnaire: HMHomeManager?
    /// Un releve est parti (envoye, ou montre) : un seul par lancement.
    @ObservationIgnored private var livre = false
    /// Maison a donne ses domiciles : avant `homeManagerDidUpdateHomes`, la
    /// liste est vide (HMHomeManager.h).
    @ObservationIgnored private var maisonChargee = false
    /// Delai de secours : sans reponse de Maison, le dire plutot qu'attendre sans fin. Assez
    /// long pour la demande d'acces du premier lancement, plus court que l'attente de l'app (120 s).
    static let delaiMaison: Duration = .seconds(100)
    /// Lectures des batteries : Maison repond depuis son cache (0,2 s pour 78
    /// valeurs le 28/09) ; au-dela, le releve part avec les valeurs deja connues.
    static let delaiLectures: Duration = .seconds(5)
    /// Envoi a l'app, au plus : le passeur se ferme ensuite quoi qu'il arrive.
    static let delaiEnvoi: Duration = .seconds(10)
    /// Lectures en cours : a la fin, `apresLectures` livre le releve.
    @ObservationIgnored private var cycle = 0
    @ObservationIgnored private var lecturesRestantes = 0
    @ObservationIgnored private var apresLectures: (@MainActor () -> Void)?

    init(cible: EnvoiPasseur.Cible?) {
        self.cible = cible
        super.init()
    }

    func demarrer() {
        guard gestionnaire == nil else { return }
        let g = HMHomeManager()
        g.delegate = self
        gestionnaire = g
        Task { [weak self] in
            try? await Task.sleep(for: Self.delaiMaison)
            // Rien de livre, ni lecture en cours : Maison n'a pas repondu.
            guard let self, !self.livre, self.apresLectures == nil else { return }
            self.livrer(NomsMaison(date: .now, statut: .erreur, message: "Maison n'a pas répondu"))
        }
    }

    // HomeKit ne dit pas sur quel fil il appelle son delegue : passer par l'acteur principal.
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.maisonChargee = true
            self.relever(manager)
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        Task { @MainActor in self.autorisation(status) }
    }

    /// Acces refuse : releve « refuse ». Acces accorde : releve, des que Maison
    /// a donne ses domiciles (sinon `homeManagerDidUpdateHomes` le fera). L'ordre
    /// des deux rappels ne compte pas.
    private func autorisation(_ s: HMHomeManagerAuthorizationStatus) {
        if s.contains(.authorized) {
            if maisonChargee, let g = gestionnaire { relever(g) }
        } else if s.contains(.determined) {
            livrer(NomsMaison(date: .now, statut: .refuse,
                              message: "Accès à Maison refusé : Réglages Système › Confidentialité et sécurité › Maison."))
        }
    }

    private func relever(_ manager: HMHomeManager) {
        guard manager.authorizationStatus.contains(.authorized) else {
            // Au relancement apres un refus, le statut peut ne jamais etre annonce comme un changement.
            autorisation(manager.authorizationStatus)
            return
        }
        guard !manager.homes.isEmpty else {
            // Jamais un « ok » vide : il effacerait les noms gardes par l'app.
            livrer(NomsMaison(date: .now, statut: .erreur, message: "Aucun domicile dans Maison"))
            return
        }
        // Un releve a la fois : les deux rappels de HomeKit peuvent arriver pendant les lectures.
        guard apresLectures == nil, !livre else { return }
        let caracteristiques = manager.homes.flatMap(\.accessories).compactMap(Self.batterie)
            .flatMap { [$0.niveau, $0.charge, $0.alerte].compactMap { $0 } }
        lire(caracteristiques) { self.livrerReleve(manager) }
    }

    private func livrerReleve(_ manager: HMHomeManager) {
        let accessoires = manager.homes.flatMap(\.accessories).map { a in
            let b = Self.batterie(a)
            return AccessoireMaison(nom: a.name, piece: a.room?.name, fabricant: a.manufacturer, modele: a.model,
                                    firmware: a.firmwareVersion, categorie: a.category.localizedDescription,
                                    noeudMatter: AccessoireMaison.noeud(a.matterNodeID),
                                    pont: a.category.categoryType == HMAccessoryCategoryTypeBridge ? true : nil,
                                    batterie: b.flatMap {
                                        BatterieMaison.depuisHomeKit(niveau: $0.niveau?.value, charge: $0.charge?.value,
                                                                     alerte: $0.alerte?.value)
                                    })
        }.sorted { $0.nom < $1.nom }
        // Zones et pieces dans l'ordre de Maison.
        let zones = manager.homes.flatMap(\.zones).map { ZoneMaison(nom: $0.name, pieces: $0.rooms.map(\.name)) }
        let domicile = manager.homes.map(\.name).joined(separator: " + ")
        livrer(NomsMaison(date: .now, statut: .ok, domicile: domicile.isEmpty ? nil : domicile,
                          accessoires: accessoires, zones: zones))
    }

    /// Service Batterie d'un accessoire : niveau, etat de charge, alerte.
    private static func batterie(_ a: HMAccessory)
        -> (niveau: HMCharacteristic?, charge: HMCharacteristic?, alerte: HMCharacteristic?)? {
        guard let s = a.services.first(where: { $0.serviceType == HMServiceTypeBattery }) else { return nil }
        func c(_ type: String) -> HMCharacteristic? { s.characteristics.first { $0.characteristicType == type } }
        return (c(HMCharacteristicTypeBatteryLevel), c(HMCharacteristicTypeChargingState),
                c(HMCharacteristicTypeStatusLowBattery))
    }

    /// Lit les valeurs, puis appelle `fin` une fois : a la derniere lecture ou au
    /// delai. (Appels a rappel hors d'une fonction async : pas d'avertissement.)
    private func lire(_ caracteristiques: [HMCharacteristic], puis fin: @escaping @MainActor () -> Void) {
        cycle += 1
        let n = cycle
        apresLectures = fin
        lecturesRestantes = caracteristiques.count
        for c in caracteristiques {
            c.readValue { @Sendable _ in
                Task { @MainActor in self.lectureFinie(n) }
            }
        }
        Task {
            try? await Task.sleep(for: Self.delaiLectures)
            self.terminerLectures(n)
        }
        if caracteristiques.isEmpty { terminerLectures(n) }
    }

    private func lectureFinie(_ n: Int) {
        guard n == cycle else { return }
        lecturesRestantes -= 1
        if lecturesRestantes == 0 { terminerLectures(n) }
    }

    private func terminerLectures(_ n: Int) {
        guard n == cycle, let fin = apresLectures else { return }
        apresLectures = nil
        fin()
    }

    /// Livre le releve, une fois : a Maillage Thread, puis fermeture ; ouvert a la main, il le
    /// montre, sans rien envoyer, et se ferme 10 s plus tard.
    private func livrer(_ n: NomsMaison) {
        guard !livre else { return }
        livre = true
        guard let cible else {
            etat = n.statut == .ok
                ? "\(n.accessoires.count) accessoires et \(n.zones?.count ?? 0) zones lus dans Maison. Ouvert à la main, Passeur Noms n'envoie rien : Maillage Thread le lance lui-même."
                : (n.message ?? "Accès à Maison refusé.")
            fermerApres(secondes: 10)
            return
        }
        etat = "Envoi à Maillage Thread…"
        guard let json = try? n.donnees() else { exit(0) }
        Self.envoyer(EnvoiPasseur.trame(jeton: cible.jeton, json: json), port: cible.port)
    }

    /// Envoie la trame a 127.0.0.1:<port> et ferme son cote, attend que l'app ferme la
    /// connexion (elle a tout lu), puis quitte. L'app injoignable (ecoute deja fermee) : quitte
    /// aussi. Jamais plus de `delaiEnvoi` : un passeur qui resterait ouvert ne recevrait pas les
    /// arguments du lancement suivant.
    private static func envoyer(_ trame: Data, port: UInt16) {
        guard let p = NWEndpoint.Port(rawValue: port) else { exit(0) }
        let c = NWConnection(host: "127.0.0.1", port: p, using: .tcp)
        c.stateUpdateHandler = { etat in
            switch etat {
            case .ready:
                c.send(content: trame, contentContext: .finalMessage, isComplete: true,
                       completion: .contentProcessed { erreur in
                    guard erreur == nil else { exit(0) }
                    c.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, _, _ in exit(0) }
                })
            case .waiting, .failed:
                exit(0)
            default:
                break
            }
        }
        c.start(queue: .main)
        Task {
            try? await Task.sleep(for: delaiEnvoi)
            exit(0)
        }
    }

    /// Ouvert a la main : fermeture apres un compte a rebours.
    private func fermerApres(secondes: Int) {
        Task { [weak self] in
            for n in stride(from: secondes, to: 0, by: -1) {
                self?.fermetureDans = n
                try? await Task.sleep(for: .seconds(1))
            }
            exit(0)
        }
    }
}
```

Dans `outils/passeur.sh`, remplacer :

```sh
# sa signature ferait redemander ses autorisations).
# Equipe gratuite : profil de 7 jours ; relancer ce script pour rafraichir.
```

par :

```sh
# sa signature ferait redemander ses autorisations).
# Lance ainsi, a la main, le passeur lit Maison et n'envoie rien : ce premier
# lancement de chaque compilation passe Gatekeeper et, la premiere fois, la
# demande d'acces a Maison. Ensuite, Maillage Thread le lance lui-meme, avec un
# port et un jeton, et recoit le releve par la boucle locale (127.0.0.1).
# Equipe gratuite : profil de 7 jours ; relancer ce script pour le renouveler.
```

- [ ] **Step 2 : le contrat du cœur.** Son commentaire dit le nouveau transport ; `DemandePasseur`, que plus rien n'utilise, part avec ses deux tests.

Dans `MaillageCoeur/Noms/NomsMaison.swift`, remplacer :

```swift
/// Contrat du fichier `noms.json`, ecrit d'un coup par le passeur (app iOS
/// lancee sur le Mac) dans un dossier choisi une fois, sans App Group, et lu
/// par l'app.
public struct NomsMaison: Codable, Hashable, Sendable {
```

par :

```swift
/// Releve de Maison par le passeur (app iOS lancee sur le Mac, sans App Group) : il
/// l'envoie a l'app par la boucle locale (`EnvoiPasseur`), et l'app garde le dernier
/// releve valide dans son conteneur (`noms.json`).
public struct NomsMaison: Codable, Hashable, Sendable {
```

Dans `MaillageCoeur/Noms/NomsMaison.swift`, remplacer :

```swift
}

/// Demande de l'app au passeur, deposee dans le dossier des noms avant de le
/// lancer en arriere-plan : il ecrit `noms.json`, retire la demande et se
/// ferme aussitot, sans compte a rebours. Lance a la main, il n'en trouve pas.
/// (Le passeur se croit toujours au premier plan : il ne peut pas le deviner.)
public struct DemandePasseur: Codable, Hashable, Sendable {
    public static let fichier = "passeur-demande.json"
    /// Au-dela, une demande est un reste (passeur qui ne s'est pas lance) : ignoree.
    public static let validite: TimeInterval = 120

    public var date: Date

    public init(date: Date) {
        self.date = date
    }

    public func estRecente(_ maintenant: Date) -> Bool {
        abs(maintenant.timeIntervalSince(date)) <= Self.validite
    }

    /// Pour le passeur, apres une ecriture reussie (acces au dossier ouvert) :
    /// retire la demande du dossier, quelle qu'elle soit ; vrai si elle est
    /// recente, donc s'il doit se fermer aussitot. Plus ancienne ou illisible,
    /// c'est un reste : le passeur a ete ouvert a la main.
    public static func consommer(dans dossier: URL, maintenant: Date) -> Bool {
        let url = dossier.appendingPathComponent(fichier)
        guard let donnees = try? Data(contentsOf: url) else { return false }
        try? FileManager.default.removeItem(at: url)
        return (try? lire(donnees))?.estRecente(maintenant) == true
    }

    public static func lire(_ donnees: Data) throws -> DemandePasseur {
        try CodageJSON.decodeur().decode(DemandePasseur.self, from: donnees)
    }

    public func donnees() throws -> Data {
        try CodageJSON.encodeur(lisible: true).encode(self)
    }
}
```

par :

```swift
}
```

Dans `MaillageCoeurTests/NomsTests.swift`, remplacer :

```swift
    /// Le passeur consomme la demande apres son ecriture : il la retire dans
    /// tous les cas, et ne se ferme aussitot que si elle est recente.
    @Test func demandeConsommee() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("demande-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let fichier = dossier.appendingPathComponent(DemandePasseur.fichier)
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(!DemandePasseur.consommer(dans: dossier, maintenant: t), "pas de demande : ouvert a la main")
        try DemandePasseur(date: t).donnees().write(to: fichier)
        #expect(DemandePasseur.consommer(dans: dossier, maintenant: t.addingTimeInterval(3)))
        #expect(!FileManager.default.fileExists(atPath: fichier.path))
        try DemandePasseur(date: t).donnees().write(to: fichier)
        #expect(!DemandePasseur.consommer(dans: dossier, maintenant: t.addingTimeInterval(600)), "un reste")
        #expect(!FileManager.default.fileExists(atPath: fichier.path))
        try Data("pas du json".utf8).write(to: fichier)
        #expect(!DemandePasseur.consommer(dans: dossier, maintenant: t))
        #expect(!FileManager.default.fileExists(atPath: fichier.path))
    }

    /// Demande de l'app au passeur : relue telle quelle, recente 2 min seulement.
    @Test func demandePasseur() throws {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let d = DemandePasseur(date: t)
        #expect(try DemandePasseur.lire(try d.donnees()) == d)
        #expect(d.estRecente(t.addingTimeInterval(119)))
        #expect(!d.estRecente(t.addingTimeInterval(121)), "reste d'un passeur qui ne s'est pas lance")
        #expect(DemandePasseur.fichier == "passeur-demande.json")
    }

    @Test func priorite() throws {
```

par :

```swift
    @Test func priorite() throws {
```

- [ ] **Step 3 : compiler le passeur, sans signature.**

Run: `xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme Passeur -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a-passeur" CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|warning:|BUILD" | grep -v appintents`
Expected: `** BUILD SUCCEEDED **`, sans erreur ni avertissement.

- [ ] **Step 4 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement ; 2 tests de moins pour le cœur (ceux de `DemandePasseur`), l'app inchangée (au rejeu : 234 tests en 22 suites, et 219 en 24 suites).

- [ ] **Step 5 : commit.**

```bash
git add Passeur/PasseurApp.swift project.yml outils/passeur.sh MaillageCoeur/Noms/NomsMaison.swift MaillageCoeurTests/NomsTests.swift
git commit -m "Envoyer le releve et les zones de Maison par la boucle locale depuis le passeur

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Documentation

**Files:**
- Modify: `README.md`, `README.fr.md`, `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` (blocs ci-dessous)

**Interfaces:**
- Consumes : le comportement des tâches 1 à 4.
- Produces : le mode d'emploi du passeur (les deux README), la section 5 de la spec de l'étape 1 révisée (plus de dossier ; les zones), et le lien vers ce plan dans la spec de la vue par pièces.

- [ ] **Step 1 : les README et les specs.**

Dans `README.md`, remplacer :

```markdown
| `MaillageThread/Noms/` | Home names: folder chosen once (security-scoped bookmark), reading `noms.json`, last names kept, launching Passeur Noms |
```

par :

```markdown
| `MaillageThread/Noms/` | Home names: launching Passeur Noms, receiving its reading over the loopback (TCP listener on 127.0.0.1, one-time token), last valid names kept in the app's container |
```

Dans `README.md`, remplacer :

```markdown
| `Passeur/` | Passeur Noms: iOS app run on the Mac (Designed for iPad) that reads Home and writes `noms.json` |
```

par :

```markdown
| `Passeur/` | Passeur Noms: iOS app run on the Mac (Designed for iPad) that reads Home and sends its names, rooms and zones to the app over the loopback |
```

Dans `README.md`, remplacer :

```markdown
iOS app run on the Mac ("Designed for iPad"): it reads Home (names, rooms,
manufacturers, `matterNodeID`, batteries), writes `noms.json` in a folder you
choose once, and quits.
```

par :

```markdown
iOS app run on the Mac ("Designed for iPad"): it reads Home (names, rooms,
zones, manufacturers, `matterNodeID`, batteries), hands the reading to
Maillage Thread over the Mac's loopback, and quits. There is no folder to
choose.
```

Dans `README.md`, remplacer :

```markdown
- The team comes from your "Apple Development" certificate (`EQUIPE=` to force
  it). A free team gets a 7-day profile: run the script again to refresh names.
  Only Passeur Noms is signed with the team; Maillage Thread stays ad hoc.
- First launch of each build: macOS says the app is "damaged". Click Cancel,
  then System Settings › Privacy & Security › "Open Anyway". Then allow Home
  access.
- Choose a folder **outside iCloud and outside this repository** (for example
  `~/Maillage Thread`); opened by hand, Passeur Noms offers "Change folder…"
  for 10 s after writing. `noms.json` is ignored by git: never commit it.
- In Maillage Thread: Settings › Home names › Choose… (the same folder). Names
  are reread when Passeur Noms quits. Priority: nickname > Home > HomeKit
  (`_hap._udp`) > host.
- Refreshing: the graph window launches Passeur Noms in the background when it
  opens (if the last reading is older than 15 min), then every hour; "Refresh
  from Home" (menu or settings) does it on demand, and so does the refresh
  button of the graph once a names folder is chosen. The app first drops
  `passeur-demande.json` in the folder, so Passeur Noms writes and quits at
  once; its window only flashes behind the others.
```

par :

```markdown
- The team comes from your "Apple Development" certificate (`EQUIPE=` to force
  it). A free team gets a 7-day profile: after that, Maillage Thread can no
  longer launch Passeur Noms; run the script again. Only Passeur Noms is
  signed with the team; Maillage Thread stays ad hoc.
- First launch of each build: macOS says the app is "damaged". Click Cancel,
  then System Settings › Privacy & Security › "Open Anyway". Then allow Home
  access. Opened by hand like this, Passeur Noms reads Home, shows what it
  read, sends nothing and quits after 10 s.
- A reading: Maillage Thread listens on `127.0.0.1` (TCP, on a port chosen by
  the system), draws a one-time token and launches Passeur Noms in the
  background with `--port` and `--jeton`. Passeur Noms reads Home, connects,
  sends the token, the length of the JSON, then the JSON, and quits once the
  app has read it all. The app checks the token, reads at most 8 MB and
  writes `noms.json` in its own container (atomic write). The loopback needs
  no local network permission. Priority of names: nickname > Home > HomeKit
  (`_hap._udp`) > host.
- The last valid reading is kept. A failure (Passeur Noms not found or
  refused, nothing within 2 minutes, wrong token, unreadable length or JSON,
  Home access denied) keeps it and shows in Settings › Home names and in the
  menu; after 7 days, Settings says to run `outils/passeur.sh` again.
- Refreshing: the graph window launches Passeur Noms when it opens (if the
  last reading is older than 15 min), then every hour; "Refresh from Home"
  (menu or settings) and the refresh button of the graph do it on demand. One
  reading at a time: a request during a reading is ignored. The window of
  Passeur Noms only flashes behind the others.
- Zones: Home's zones (usually floors) and their rooms, in Home's order;
  Settings › Home names lists them. A reading from before zones has none.
- The `noms.json` written in a chosen folder by an older Passeur Noms (at the
  root of this repository, for example) is no longer read: delete it (git
  ignores it).
```

Dans `README.fr.md`, remplacer :

```markdown
| `MaillageThread/Noms/` | noms de Maison : dossier choisi une fois (signet à portée de sécurité), lecture de `noms.json`, derniers noms gardés, lancement de Passeur Noms |
```

par :

```markdown
| `MaillageThread/Noms/` | noms de Maison : lancement de Passeur Noms, réception de son relevé par la boucle locale (écoute TCP sur 127.0.0.1, jeton à usage unique), derniers noms valides gardés dans le conteneur de l'app |
```

Dans `README.fr.md`, remplacer :

```markdown
| `Passeur/` | Passeur Noms : app iOS lancée sur le Mac (« conçue pour iPad ») qui lit Maison et écrit `noms.json` |
```

par :

```markdown
| `Passeur/` | Passeur Noms : app iOS lancée sur le Mac (« conçue pour iPad ») qui lit Maison et envoie ses noms, pièces et zones à l'app par la boucle locale |
```

Dans `README.fr.md`, remplacer :

```markdown
(« conçue pour iPad ») : elle lit Maison (noms, pièces, fabricants,
`matterNodeID`, batteries), écrit `noms.json` dans un dossier choisi une
fois, et se ferme.
```

par :

```markdown
(« conçue pour iPad ») : elle lit Maison (noms, pièces, zones, fabricants,
`matterNodeID`, batteries), passe le relevé à Maillage Thread par la boucle
locale du Mac, et se ferme. Aucun dossier à choisir.
```

Dans `README.fr.md`, remplacer :

```markdown
- L'équipe vient de ton certificat « Apple Development » (`EQUIPE=` pour
  l'imposer). Une équipe gratuite a un profil de 7 jours : relancer le script
  pour rafraîchir les noms. Seul Passeur Noms est signé avec l'équipe ;
  Maillage Thread reste ad hoc.
- Au premier lancement de chaque compilation, macOS dit que l'app est
  « endommagée » : cliquer Annuler, puis Réglages Système › Confidentialité et
  sécurité › « Ouvrir quand même ». Autoriser ensuite l'accès à Maison.
- Choisir un dossier **hors iCloud et hors de ce dépôt** (par exemple
  `~/Maillage Thread`) ; ouvert à la main, Passeur Noms propose « Changer de
  dossier… » pendant 10 s après l'écriture. `noms.json` est ignoré par git :
  ne jamais le commiter.
- Dans Maillage Thread : Réglages › Noms de Maison › Choisir… (le même
  dossier). Les noms sont relus quand Passeur Noms se ferme.
  Priorité : surnom > Maison > HomeKit (`_hap._udp`) > hôte.
- Rafraîchissement : la fenêtre du graphe lance Passeur Noms en arrière-plan à
  son ouverture (si le relevé a plus de 15 min), puis toutes les heures ;
  « Rafraîchir depuis Maison » (menu ou réglages) le fait à la demande, comme
  le bouton rafraîchir du graphe dès qu'un dossier des noms est choisi. L'app
  dépose d'abord `passeur-demande.json` dans le dossier : Passeur Noms écrit
  et se ferme aussitôt, sa fenêtre ne fait que passer derrière les autres.
```

par :

```markdown
- L'équipe vient de ton certificat « Apple Development » (`EQUIPE=` pour
  l'imposer). Une équipe gratuite a un profil de 7 jours : au-delà, Maillage
  Thread ne peut plus lancer Passeur Noms ; relancer le script. Seul Passeur
  Noms est signé avec l'équipe ; Maillage Thread reste ad hoc.
- Au premier lancement de chaque compilation, macOS dit que l'app est
  « endommagée » : cliquer Annuler, puis Réglages Système › Confidentialité et
  sécurité › « Ouvrir quand même ». Autoriser ensuite l'accès à Maison. Ouvert
  ainsi à la main, Passeur Noms lit Maison, montre ce qu'il a lu, n'envoie
  rien et se ferme après 10 s.
- Un relevé : Maillage Thread écoute sur `127.0.0.1` (TCP, sur un port choisi
  par le système), tire un jeton à usage unique et lance Passeur Noms en
  arrière-plan avec `--port` et `--jeton`. Passeur Noms lit Maison, se
  connecte, envoie le jeton, la longueur du JSON puis le JSON, et se ferme
  dès que l'app a tout lu. L'app vérifie le jeton, lit au plus 8 Mo et écrit
  `noms.json` dans son conteneur (écriture atomique). La boucle locale ne
  demande pas l'accès au réseau local. Priorité des noms : surnom > Maison >
  HomeKit (`_hap._udp`) > hôte.
- Le dernier relevé valide est gardé. Un échec (Passeur Noms introuvable ou
  refusé, rien en 2 minutes, jeton faux, longueur ou JSON illisible, accès à
  Maison refusé) le garde et se lit dans Réglages › Noms de Maison et dans le
  menu ; au-delà de 7 jours, les Réglages disent de relancer
  `outils/passeur.sh`.
- Rafraîchissement : la fenêtre du graphe lance Passeur Noms à son ouverture
  (si le relevé a plus de 15 min), puis toutes les heures ; « Rafraîchir
  depuis Maison » (menu ou réglages) et le bouton rafraîchir du graphe le
  font à la demande. Un relevé à la fois : une demande pendant un relevé est
  ignorée. La fenêtre de Passeur Noms ne fait que passer derrière les autres.
- Zones : les zones de Maison (en général les étages) et leurs pièces, dans
  l'ordre de Maison ; Réglages › Noms de Maison les liste. Un relevé d'avant
  les zones n'en a pas.
- Le `noms.json` écrit dans un dossier choisi par un ancien Passeur Noms (à la
  racine de ce dépôt, par exemple) n'est plus lu : l'effacer (git l'ignore).
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, remplacer :

```markdown
3. **`Passeur Noms`** (app iOS lancée sur le Mac « conçue pour iPad »,
   capacité HomeKit ; section 5) : lancé à la demande, lit Maison, écrit
   `noms.json` dans un dossier choisi une fois, se ferme.
```

par :

```markdown
3. **`Passeur Noms`** (app iOS lancée sur le Mac « conçue pour iPad »,
   capacité HomeKit ; section 5) : lancé à la demande, lit Maison, passe le
   relevé à l'app par la boucle locale du Mac, se ferme (sans dossier depuis
   le plan 4a, 30/09).
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, remplacer :

```markdown
  identify the device on Apple's Matter fabric »), ainsi que le nom du
  domicile.
```

par :

```markdown
  identify the device on Apple's Matter fabric »), ainsi que le nom du
  domicile et, depuis le 30/09 (plan 4a), les zones de Maison avec leurs
  pièces, dans l'ordre de Maison (`ZoneMaison`, champ facultatif).
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, remplacer :

```markdown
- Il écrit `noms.json` d'un coup, au format `NomsMaison`, dans **un dossier
  choisi une fois** (par défaut Documents/Maillage Thread ; signet gardé),
  puis se ferme : aussitôt si l'app l'a lancé, sinon 10 s plus tard. L'app
  dépose `passeur-demande.json` (`DemandePasseur`, valable 2 min, ignoré par
  git) dans le dossier juste avant de le lancer ; le passeur le retire après
  l'écriture. Il ne peut pas le deviner seul : lancé sans activation, il se dit
  quand même au premier plan (essai du 28/09), et sa fenêtre passe un instant
  derrière les autres.
```

par :

```markdown
- **Révision du 30/09 (plan 4a ; spec de la vue par pièces, section 3) :
  plus de dossier.** L'app écoute sur `127.0.0.1` (TCP, port choisi par le
  système), tire un jeton à usage unique, puis lance le passeur sans
  l'activer, avec `--port` et `--jeton` dans ses arguments de lancement. Le
  passeur lit Maison, se connecte et envoie le jeton, la longueur du JSON puis
  le JSON (`NomsMaison`, trame `EnvoiPasseur`) ; il se ferme dès que l'app a
  tout lu (10 s d'envoi au plus). Ouvert à la main (sans port ni jeton), il
  n'envoie rien : il montre ce qu'il a lu et se ferme 10 s plus tard. Sa
  fenêtre passe toujours un instant derrière les autres. Aucune invite
  « réseau local » : la boucle locale n'en demande pas (essai du
  passeur-démon, 30/09).
  Auparavant, il écrivait `noms.json` dans un dossier choisi une fois, et
  l'app y déposait `passeur-demande.json` avant de le lancer.
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, remplacer :

```markdown
- Elle lit ce fichier après **un choix unique** dans ses Réglages
  (« Fichier des noms… », signet à portée de sécurité), et le relit quand il
  change.
```

par :

```markdown
- Elle reçoit le relevé par la boucle locale (`NomsInternes`) : jeton
  vérifié à temps constant, au plus 8 Mo, 120 s d'attente (le premier
  lancement attend la réponse à la demande d'accès à Maison), une seule
  écoute à la fois. Elle écrit le dernier relevé valide dans son conteneur
  (`noms.json`, écriture atomique) ; un échec le garde et se dit dans les
  Réglages et le menu (révision du 30/09 ; auparavant, un fichier lu dans un
  dossier choisi une fois, avec un signet à portée de sécurité).
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, remplacer :

```markdown
- **Dossier conseillé (révision du 28/09, après essai)** : hors iCloud et hors
  du dépôt, par exemple `~/Maillage Thread` ; ouvert à la main, le passeur
  montre le dossier utilisé et « Changer de dossier… » pendant les 10 s qui
  précèdent sa fermeture ; `noms.json` est ignoré par git (Djoko a gardé la racine du
  dépôt : c'est le filet de sécurité).
```

par :

```markdown
- **Dossier conseillé (révision du 28/09, après essai ; sans objet depuis le
  plan 4a, 30/09)** : hors iCloud et hors du dépôt. Djoko avait gardé la
  racine du dépôt ; le `noms.json` qui y reste n'est plus lu, et reste ignoré
  par git.
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, remplacer :

```markdown
  fichier des noms choisi une fois (`files.user-selected`, signet).
```

par :

```markdown
  écoute TCP sur la boucle locale pour le relevé du passeur
  (`network.server`, plan 4a, 30/09 ; il remplace le signet du dossier des
  noms ; `files.user-selected` reste pour « Enregistrer une capture… »).
```

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
> - **4a** : le passeur sans dossier, et les zones de Maison ;
```

par :

```markdown
> - **4a** : le passeur sans dossier, et les zones de Maison (`docs/superpowers/plans/2026-09-30-maillage-thread-plan4a-passeur-interne.md`) ;
```

- [ ] **Step 2 : la suite ne change pas.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, les effectifs de la fin de la tâche 4 (au rejeu : 234 tests en 22 suites, et 219 en 24 suites).

- [ ] **Step 3 : commit.**

```bash
git add README.md README.fr.md docs/superpowers/specs/2026-09-28-maillage-thread-design.md docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md
git commit -m "Documenter le passeur sans dossier et les zones de Maison

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Vérification avec Djoko (par le contrôleur, pas par un sous-agent)

**Files:**
- Modify: `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` (section 3, après la vérification)

Chaque lancement du passeur, de l'app en mode direct ou de Maison se fait avec Djoko, à sa demande. Le contenu de `noms.json` (noms, pièces, zones) n'est jamais affiché dans la conversation ni copié dans le dépôt : seuls des comptes.

- [ ] **Step 1 : recompiler le passeur, avec Djoko.** La signature se fait avec son équipe, par le script :

  ```bash
  outils/passeur.sh
  ```

  Attendu :
  - « Passeur Noms lancé » ;
  - au premier lancement de cette compilation, Gatekeeper : Djoko clique Annuler, puis Réglages Système › Confidentialité et sécurité › « Ouvrir quand même » ;
  - la fenêtre du passeur dit « <n> accessoires et <z> zones lus dans Maison. Ouvert à la main, Passeur Noms n'envoie rien… », puis se ferme après 10 s.

  L'accès à Maison reste accordé : même équipe, même identifiant. Si Maison le redemande, Djoko l'accepte.
- [ ] **Step 2 : l'app.**
  1. La compiler : `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a" TMPDIR="$HOME/Library/Caches/maillage-plan4a/" outils/tester.sh`.
  2. Quitter l'app qui tourne.
  3. Djoko lance la nouvelle en mode direct : `open "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4a/Build/Products/Debug/Maillage Thread.app"`.

  Il n'y a pas de migration : avant le premier relevé, Réglages › Noms de Maison ne montre pas de noms. Si la fenêtre du graphe s'ouvre, elle lance aussitôt un relevé (relevé absent) : passer alors au Step 3 sans cliquer.
- [ ] **Step 3 : un relevé réel.** Djoko clique Réglages › Noms de Maison › « Rafraîchir depuis Maison ». Attendu :
  - le bouton grisé et le petit indicateur, quelques secondes ;
  - aucune invite « réseau local », ni du coupe-feu de macOS : il est actif sur ce Mac, et l'app n'écoute que sur 127.0.0.1 ;
  - puis « Noms lus : <n> accessoires · <date> » et « Zones : … », ses zones dans l'ordre de Maison ; aucune erreur en rouge ;
  - le passeur déjà fermé : `pgrep -x "Passeur Noms"` ne rend rien ;
  - dans le graphe, les noms des appareils comme avant.
- [ ] **Step 4 : le fichier du conteneur,** sans l'afficher. Il existe :

  ```bash
  ls -l ~/Library/Containers/fr.djoko.maillage/Data/Library/Application\ Support/Maillage\ Thread/noms.json
  ```

  Et il porte les zones ; ce script n'affiche que des comptes :

  ```bash
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d["accessoires"]), "accessoires,", len(d.get("zones") or []), "zones,", sum(len(z["pieces"]) for z in d.get("zones") or []), "pieces dans les zones")' ~/Library/Containers/fr.djoko.maillage/Data/Library/Application\ Support/Maillage\ Thread/noms.json
  ```
- [ ] **Step 5 : une seule écoute à la fois.** Juste après un clic sur « Rafraîchir depuis Maison », le bouton reste grisé jusqu'à la fin du relevé, dans les Réglages comme dans le menu. Un clic sur le bouton rafraîchir du graphe pendant ce temps relance le réseau et la tournée de la sonde, mais pas un second passeur : `pgrep -x "Passeur Noms"` n'en montre jamais deux. Le relevé est court (l'essai a lu Maison en 0,8 s) : l'observer si possible, sans insister ; les tests le couvrent.
- [ ] **Step 6 : relancer l'app.** Djoko quitte l'app et la relance. Les noms et les zones sont là aussitôt, lus dans le conteneur, sans relevé.
- [ ] **Step 7 (si Djoko le veut) : l'échec garde les noms,** en deux minutes :
  1. Djoko ouvre Passeur Noms à la main, depuis le Finder ;
  2. pendant ses 10 s, il clique « Rafraîchir depuis Maison ».

  C'est la limite connue : le passeur ouvert ne reçoit pas les arguments. Attendu, au bout de 2 minutes : « Passeur Noms n'a rien envoyé en 2 minutes. » en rouge, les noms et les zones gardés. Un nouveau clic, le passeur fermé, fait un relevé normal.
- [ ] **Step 8 : les restes de l'ancien passeur,** au choix de Djoko, qui peut effacer :
  - le `noms.json` et un éventuel `passeur-demande.json` à la racine du dépôt principal (ignorés par git) ;
  - l'ancien cache `noms-maison.json` du conteneur, qui n'est plus lu.
- [ ] **Step 9 : spec, section 3.** À la fin de la section 3.2, ajouter le paragraphe suivant, en remplaçant `<…>` par les valeurs des Steps 3 et 4 : des comptes, jamais un nom. Ajouter ce qu'ont montré les Steps 5 et 7, s'ils ont été faits.

```markdown
**Vérifié le <date> avec Djoko** (plan 4a) : un relevé sans dossier, par la
boucle locale ; <n> accessoires et <z> zones (<p> pièces) reçus, zones
affichées dans Réglages › Noms de Maison ; passeur fermé aussitôt ; aucune
invite « réseau local » ni du coupe-feu ; noms relus au relancement de
l'app.
```

Commit : `git add docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, message « Noter la verification du plan 4a avec Djoko », terminé par la ligne `Co-Authored-By`.

---

## Couverture de la spec

| Spec | Tâches |
|---|---|
| 3.1, 1 : écoute TCP sur 127.0.0.1, port choisi par le système ; jeton à usage unique, 32 octets aléatoires en hexa | 3 (`EcouteReleve`, `NomsInternes.lancerPasseur`) ; 2 (`nouveauJeton`) |
| 3.1, 2 : passeur lancé sans activation, `OpenConfiguration.arguments = ["--port", <port>, "--jeton", <jeton>]` | 3 (`lancerPasseurDuMac`) ; 2 (`Cible.arguments`) |
| 3.1, 3 : le passeur lit Maison, se connecte, envoie le jeton, la longueur puis le JSON, et se ferme | 4 ; 2 (`trame`, `Cible(arguments:)`) ; précision 7 |
| 3.1, 4 : jeton à temps constant, au plus 8 Mo, JSON décodé, écrit dans le conteneur par une écriture atomique, écoute fermée | 2 (`Lecture`) ; 3 (tests `bonJeton`, `longueurFausse`) ; précisions 3 et 4 |
| Échecs : passeur introuvable, lancement refusé, rien dans le délai, jeton faux, longueur ou JSON illisible | 3 (tests `lancementRefuse`, `delaiDepasse`, `mauvaisJeton`, `longueurFausse`, `jsonIllisible`) |
| Délai de 120 s : le premier lancement attend la réponse à la demande d'accès à Maison | 3 (`delaiParDefaut`) ; 4 (secours du passeur à 100 s, précision 5) |
| Dernier relevé valide gardé ; erreur là où l'app montre l'état du passeur ; alerte au-delà de 7 jours | 3 (Réglages et menu ; tests `echecGardeLesNoms`, `memoireDesNoms`, `refusDeMaison`, `ancien`) |
| Une seule écoute à la fois : une demande pendant un relevé est ignorée | 3 (test `uneSeuleEcoute` ; boutons grisés, précision 8) |
| Ce qui disparaît : le choix du dossier, le signet, `passeur-demande.json`, la lecture de `noms.json` dans un dossier | 3 (`DossierNoms`, droit `bookmarks.app-scope`) ; 4 (`DemandePasseur`) ; 5 (documentation) |
| Le `noms.json` de l'ancien passeur à la racine du dépôt : inutile, ignoré par git | 5 (README) ; 6 (Step 8) |
| App ad hoc, passeur avec son équipe gratuite ; aucune invite « réseau local » | contraintes globales ; 3 (`network.server`) ; 6 (Step 3) |
| 3.2 : `zones: [ZoneMaison]?`, dans l'ordre de Maison ; un fichier d'avant les zones reste lisible ; `versionActuelle` inchangée | 1 ; 4 (export par le passeur) ; 3 (Réglages, précision 8) |
| 9 : `DossierNoms` devient `NomsInternes` ; `PasseurApp.swift` exporte les zones et envoie par TCP | 3 ; 4 |
| 10 : `NomsInternes` face à un faux passeur, un client TCP sur 127.0.0.1 : bon jeton ; mauvais jeton, longueur fausse, JSON illisible, délai ; une seule écoute | 3 |
| 10 : nouveaux textes en français et en anglais, `CataloguesTests` | 3 (Step 4) |
| 10 : avec Djoko, un relevé du passeur sans dossier | 6 |
| 11 : plan 4a indépendant de la vue ; le 4b suppose les zones | tout le plan ; les zones arrivent dans `NomsMaison` (tâches 1 et 4) |
