# Maillage Thread, polissage A : mineurs et robustesse : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** corriger les points mineurs et de robustesse du sous-projet A du polissage, triés avec Djoko le 01/10 (lots 1 à 4) : `outils/tester.sh` qui ne répond plus « réussi » quand une cible ne lance aucun test ; un cœur sûr face à un coût de disposition non fini, à un enfant devenu routeur et à un routeur hors de 0…62 ; des fichiers gardés qui ne perdent jamais ce qu'ils gardent ; une seule construction du graphe et du rapprochement par rendu, que la scène, la fiche et son menu lisent. Rien ne change à l'écran : les douze images de démo restent identiques, octet pour octet.

**Architecture :**
- **Les outils** : avec des cibles, `outils/tester.sh` lit le résultat de `xcodebuild` (le `.xcresult`, par `xcresulttool`) et exige que chaque cible ait lancé au moins un test.
- **Le cœur** (`MaillageCoeur/`, testé) :
  - `DispositionPieces` : un départ dont le coût n'est pas fini n'est pas retenu ; sans départ d'un coût fini, la disposition est celle du départ ;
  - `Maillage.enfantsIdentifies` écarte l'entrée du balayage d'un enfant devenu routeur : le rapprochement (`MaillageAffiche`), l'historique (`ReleveMaillage`) et le journal (`SuiviMaillage`) la suivent ;
  - `ReleveMaillage.encode(to:)` n'écrit jamais un identifiant de routeur hors de 0…62, la plage que la lecture accepte ;
  - `FichiersGardes` (nouveau, `MaillageCoeur/Systeme/`) : la règle commune des quatre fichiers gardés dans le conteneur de l'app (places des pièces, pièces choisies, surnoms, identités des routeurs).
- **L'app** (`MaillageThread/`) :
  - `EntreeScene` porte ce dont la scène est faite (graphe, maillage rapproché, chefs, appareils), construit une fois par rendu dans `FenetrePieces` ; la légende, la fiche (`FicheNoeud`) et « Placer dans une pièce… » (`PiecesChoisies.placement`) le lisent ;
  - `Surveillance.cleHistorique` reconnaît l'ExtMac d'un hôte par `GrapheReseau.extMac(hote:)`, le prédicat de la pièce d'un nœud.

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI, Observation, os (`Logger`, `OSAllocatedUnfairLock`), Swift Testing, XcodeGen, `xcodebuild` et `xcresulttool`, sh.

**Spec :** `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` (sections 2.3 et 2.4 : nœuds, places gardées, pièces choisies ; 4.3 : disposition ; 9 : architecture ; 10 : tests) et `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md` (section 4 : tournée, balayage, identités des routeurs ; section 6 : journal et historique). Le tri des points (local, jamais commité) est repris ci-dessous, point par point, avec ses raisons : ce plan se suffit.

**Validé par Djoko le 01/10 :** le tri du sous-projet A et ses lots 1 à 4. Le lot 5 (le passeur) attend : Djoko ne veut pas y toucher maintenant.

**Décisions du contrôleur sur les points laissés ouverts par l'auteur du plan (01/10) :**
- la couronne de la fiche vient avec la légende, au sous-projet B, comme Djoko l'a placée : en A, rien ne change à l'écran, et `EntreeScene.chefs` est déjà passé à la fiche ;
- les trois précisions de ce plan (enfant devenu routeur ; fichiers gardés ; repli sur le départ quand aucun coût n'est fini) sont reportées dans les specs par le contrôleur à la tâche 5, avec la note de vérification ;
- les rapports de plantage laissés par le rouge de la tâche 2 (`~/Library/Logs/DiagnosticReports`) sont attendus, comme au plan 4b.

**Quand l'exécuter.** Avant le sous-projet B : ce plan est écrit et validé sur le `main` du 01/10 (`be7159e`), après les plans 4a et 4b. **Les numéros de ligne cités sont indicatifs : l'exécutant se repère aux noms (types, fonctions, commentaires) et aux textes cités.** Si un texte à remplacer n'est plus exactement le même, il applique le même changement au texte du moment et le dit dans son rapport.

## Code validé, faits établis et précisions

**Code validé avant exécution.** Le 01/10, tout le code de ce plan a été écrit, compilé et testé dans une copie de `main` (`be7159e`) :
- toute la suite passe, en français et en anglais : 345 tests en 36 suites pour le cœur et 269 en 28 pour l'app (avant ce plan : 336 en 35 et 266 en 28), sans avertissement ;
- les temps de la vue par pièces, en Release, ne bougent pas : la disposition de la grande maison inventée en 0,26 s (budget de 3 000 coups atteint), 150 noms en 0,31 ms, 150 noms très serrés en 2,84 ms ;
- les tests Python de la sonde passent (`python3 -m unittest discover -s sonde/test`, puis avec `/usr/bin/python3`) : ce plan n'y touche pas ;
- les douze images de démo sont identiques, octet pour octet, à celles de la relecture finale du plan 4b (`captures-plan4b-finale`), après la tâche 2, après la tâche 4 et à la fin ;
- la disposition ordinaire est identique au bit près : seize dispositions inventées (quatre maisons ; libres, avec une ou deux pièces fixées, ou un budget de 40 coups) gardent la même empreinte (positions, rayons, coûts et coups) avant et après la tâche 2.

Le plan a ensuite été rejoué tâche par tâche sur une copie neuve de `main` (`be7159e`), ses blocs appliqués par l'outil du contrôleur (`appliquer-blocs.py`, sur le brief de chaque tâche) : le rouge, le vert, la suite entière, les images, un commit par tâche. Les résultats attendus ci-dessous viennent de ce rejeu. L'arbre final est identique à la copie validée. D'autres changements de `main` changeraient ces totaux : chaque tâche donne donc ses effectifs par suite, et l'écart des totaux.

Exécuter une tâche, c'est transcrire les fichiers et les blocs donnés, compiler et tester. Si un fichier doit s'écarter du texte donné, l'exécutant le dit dans son rapport, avec la raison.

**Blocs de modification.** Un fichier existant est modifié soit en entier (« fichier entier »), soit par blocs « remplacer … par … ». Chaque texte à remplacer apparaît une seule fois dans le fichier au moment où on l'applique. Les blocs s'appliquent dans l'ordre, du haut vers le bas, au texte exact, espaces compris. Un fichier créé l'est tel quel. Ce plan ne déplace ni ne supprime aucun fichier, et n'a pas de script.

**Faits établis, utiles à l'exécution** (copie validée et rejeu, 01/10) :
- **Un filtre qui ne lance rien.** Avec un nom faux, ou un test de Swift Testing nommé sans ses parenthèses (`…/GrapheReseauTests/stable` au lieu de `…/GrapheReseauTests/stable()`), `xcodebuild` ne lance aucun test et répond pourtant `** TEST SUCCEEDED **`. Le journal ne le montre pas toujours : `Test run with 0 tests` pour un test sans parenthèses, rien du tout pour une suite inconnue. Le résultat (`.xcresult`), lui, ne liste que ce qui a tourné : c'est ce que lit `tester.sh` après la tâche 1.
- **Un coût non fini vient d'une valeur infinie ou démesurée.** Une carte de largeur NaN laisse le coût fini : `max(r, .nan)` rend `r`, et le rayon ignore la carte. Une largeur infinie, ou une place fixée à 1e308, rendent le rayon de l'étage infini et le coût non fini : ce sont les entrées des tests de la tâche 2.
- **Le rouge de la tâche 2 plante, comme le défaut.** Avant le code, `coutNonFini` et `placeFixeeDemesuree` arrêtent le processus des tests du cœur (`retenu` reste vide, et `rayon` lit hors bornes) : `xcodebuild` relance les tests suivants (`Restarting after unexpected exit, crash, or test timeout`, dans le journal complet), et le système laisse un rapport de plantage `xctest-….ips` par plantage dans `~/Library/Logs/DiagnosticReports`, hors du dépôt.
- **Tests de l'app,** qui tournent dans l'app : deux sessions en même temps sur ce Mac peuvent s'interrompre l'une l'autre (`Test crashed with signal term` sur un test sans rapport). Relancer alors la suite, seule.

**Précisions.** Ce sont les choix faits à l'écriture du plan, là où le tri laissait la main. Aucun ne change l'écran ; Djoko peut les revoir à la tâche 5.
1. **Disposition sans coût fini** (n° 1). La disposition gardée est le départ du premier essai, avant son tassement (`Calcul.depart(0, fixees:)`) : la spirale, les fixées à leur place. Le tassement lui-même pourrait rendre des positions non finies ; la spirale, jamais. Ses rayons et son coût, non finis, en sont tirés tels quels, sans dégagement.
2. **Enfant devenu routeur** (n° 2). Seule une entrée du balayage est écartée, quand son ExtMac est celle d'un routeur de la liste ; une entrée de table (son parent vient de répondre) ou de la sonde reste. La comparaison porte sur l'ExtMac telle que la sonde la donne, comme celle du journal (`SuiviMaillage`, « devenu routeur »).
3. **Routeur hors de 0…62** (n° 18). Le filtre est à l'écriture (`ReleveMaillage.encode(to:)`), le seul passage vers le fichier ; le relevé gardé en mémoire pour la session reste tel quel. Un parent de la sonde hors de la plage est omis, comme un parent inconnu.
4. **Fichiers gardés** (n° 3) :
   - la règle vaut aussi pour `identites-routeurs.json` (`IdentitesGardees`) : même schéma que les surnoms (lu vide s'il est illisible, réécrit en entier, sans version), vérifié ;
   - la version se lit seule (`{"version": n}`), avant le reste : un fichier plus récent, d'un autre schéma, reste « plus récent », jamais « illisible » ;
   - l'état du fichier est relu avant chaque écriture, sans rien retenir de la lecture : un fichier plus récent n'est jamais réécrit ; la mise de côté n'a lieu qu'une fois, le fichier écrit ensuite étant lisible ;
   - le nom de la copie porte l'heure locale (calendrier grégorien) ; un fichier déjà là sous ce nom n'est pas remplacé : le renommage échoue, l'écriture aussi, et l'app le note comme avant ;
   - journal du Mac (sous-système `fr.djoko.maillage`, catégorie `fichiers`) : une fois par fichier et par lancement pour un fichier plus récent, une fois par mise de côté ; le nom du fichier, jamais son contenu.
5. **Une seule construction par rendu** (n° 14). `EntreeScene` porte le graphe, le maillage rapproché, les chefs et les appareils. Son égalité ne compare que ce que la vue dessine (la scène, les libellés, les apparences, le domicile) : un maillage reçu sans effet sur la scène ne la fait pas reposer par le moteur (`MoteurPieces.recevoir`, qui remettrait l'état d'une pièce isolée).
6. **Couronne de la fiche** (n° 14). La fiche n'en montre pas encore : `EntreeScene.chefs` est l'ensemble des nœuds couronnés de la scène, et la fiche reçoit la scène. Le sous-projet B la dessinera de là.
7. **API des seuls tests** (n° 15). `PiecesChoisies.pieces(aPlacer:dans:)` et `PiecesChoisies.choisir(_:routeur:domicile:)` sont retirées ; les tests passent par `placement(_:dans:entree:)` et `choisir(_:_:domicile:)`, sans rien perdre de ce qu'ils vérifient.

**Ce qui reste en place** (hors de ce plan) :
- le lot 5, le passeur (n° 22 à 25) : Djoko ne veut pas y toucher maintenant ;
- le n° 6 (un changement d'état peut réarranger un étage) : reporté en D ;
- les points reportés en B (n° 11, 12, 31), en C (n° 8, 9) et en D (n° 7) ;
- les points laissés en place : n° 5, 10, 13, 17, 19, 20, 21, 28, 29, 32 (le tri du 01/10 en donne les raisons) ;
- `Surveillance.cleHistorique` garde son propre rapprochement, pour les courbes et le journal de la fiche : le maillage frais ou non, dans le réseau de sa partition. Ce n'est pas celui de la scène, qui n'existe plus quand le maillage est périmé.

## Points traités

Le tri du 01/10 (sources : les registres et relectures des plans 3b, 4a et 4b), pour les points de ce plan. Gravité : plantage, donnée perdue ou fausse, visible, invisible, doc.

| n° | point | gravité ; raison du tri | tâche |
|---|---|---|---|
| 26 | `outils/tester.sh` répond « TEST SUCCEEDED » quand un filtre ne trouve aucun test (relecture des correctifs du 3b). | invisible (faux vert) ; gêne B, C et D, qui testent par filtres | 1 |
| 30 | Spec, section 10 : « le coût retenu est au plus celui du départ », sans l'exception des fixées dégagées (4b, ronde de la tâche 4). | doc | 1 |
| 1 | Coût NaN : `retenu` reste vide, puis `rayon` lit hors bornes. Les entrées sont finies depuis M3, mais le calcul n'a pas de garde (4b, doute 2 des correctifs). | plantage, sans chemin connu ; C retouchera la disposition 2D | 2 |
| 2 | Un enfant devenu routeur garde 30 min son entrée de balayage : un nœud « Non identifié » en double (dans « Sans pièce », ou dans la pièce choisie pour son ExtMac), et un enfant de trop dans l'historique (4b, tâche 1 ; doute de la tâche 16). | visible (rare, 30 min au plus) | 2 |
| 18 | Un relevé qui porte le routeur 63 est écrit, puis refusé à la relecture : toute la ligne de la tournée est perdue. Seules des données non conformes y mènent (3b, N1). | donnée perdue | 2 |
| 4 | `extMacs` a deux sens dans `MaillageAffiche.init` : l'ensemble local des routeurs, et la propriété par nœud (T16, mineur 8). | invisible, cosmétique ; renommé en passant, la tâche touchant ce fichier | 2 |
| 3 | Un fichier gardé illisible, ou d'une version plus récente, est lu vide, puis écrasé sans copie : surnoms, pièces choisies, places et ordre des étages sont perdus (4b, tâche 5). | donnée perdue ; une build plus ancienne écraserait un format plus récent, et C changera sans doute `positions-pieces.json` | 3 |
| 14 | La fiche et son menu « Placer dans une pièce… » refont rapprochement et graphe à chaque rendu, à part de la scène ; leur accord ne tient qu'à deux tests (T16, mineur 2). | invisible ; gêne B, car la couronne de la fiche doit suivre les chefs de la scène | 4 |
| 15 | De l'API de production n'est appelée que par les tests ; `LibellesNoeuds.pieces(…, graphe: nil)` ignore en silence les choix d'appareils (T16, mineur 4). | invisible (piège pour un nouvel appelant) | 4 |
| 16 | Le prédicat « un hôte de 16 hexa est une ExtMac » existe en deux copies, l'une sans `isASCII` (T16, mineur 3). | invisible | 4 |
| 27 | Trous de couverture : routeur Thread hors bordure connu de la sonde seule, côté app ; choix sous l'ExtMac d'un routeur de bordure ; maison sans pièces, sans menu pour un appareil (T16, mineur 9). | invisible ; comblés en passant, la tâche 4 touchant ces tests | 4 |

## Global Constraints

- **Plateformes :** app en macOS 26.0 minimum, développée avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`.
- **Code :** identifiants et commentaires en français **sans accents** ; textes affichés avec accents ; tests en Swift Testing. Le nouveau fichier `MaillageCoeur/Systeme/FichiersGardes.swift` est pris par les sources de `project.yml` sans le modifier : ce plan ne touche pas `project.yml`.
- **La scène séparée du moteur** (spec de la vue par pièces, section 9) : `MaillageCoeur/Scene/` n'importe que Foundation, simd et CoreGraphics. `FichiersGardes`, qui importe `os` pour le journal du Mac, est donc dans `MaillageCoeur/Systeme/`.
- **Rien ne change à l'écran :** les douze images de démo restent identiques, octet pour octet (tâches 2 et 4) ; la disposition ordinaire reste identique au bit près.
- **Déterminisme :** aucun hasard dans la scène ; mêmes entrées, même disposition, sur toutes les machines.
- **Textes de l'app :** ce plan n'ajoute ni ne retire aucun texte affiché ; le catalogue (`MaillageThread/Ressources/Localizable.xcstrings`) ne change pas, et `CataloguesTests` le vérifie. Une tâche qui changerait un texte synchroniserait le catalogue par les outils : compiler, `outils/synchroniser-textes.sh`, `outils/traductions/interface.json`, puis `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`.
- **Tests indépendants de la langue :** une attente sur un texte affiché reprend la même clé que le code (`String(localized: "Sans pièce")`), jamais une chaîne française figée. Les tests passent en anglais :

  ```bash
  xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-polA/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-polA/maillage-tests-en.log"
  ```
- **Commandes,** depuis la racine du dépôt, toujours avec un dossier de produits (`DD`) et un dossier temporaire (`TMPDIR`) propres à ce plan : une autre compilation (l'app de Djoko, une autre session) ne partage ni ses produits ni son journal. Le shell d'un agent ne garde pas ses variables d'une commande à l'autre : chaque commande les porte. Une fois, avant la tâche 1 :

  ```bash
  mkdir -p "$HOME/Library/Caches/maillage-polA"
  ```

  Puis, par exemple :

  ```bash
  DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/FichiersGardesTests
  ```

  `outils/tester.sh [cibles…]` génère le projet, compile et lance les tests, en Debug ; les produits vont dans `DD`, le journal complet dans `$TMPDIR/maillage-tests.log`. Après la tâche 1, une cible qui ne lance aucun test fait échouer le script : un test de Swift Testing se nomme avec ses parenthèses (`MaillageCoeurTests/GrapheReseauTests/stable()`). `outils/mesurer.sh` lance les trois tests de temps en Release, dans le même `DD`, journal dans `$TMPDIR/maillage-mesures.log`. La première compilation dans ce `DD` neuf prend quelques minutes.
- **Une suite de tests de l'app à la fois** sur ce Mac : si un test sans rapport échoue avec `Test crashed with signal term`, vérifier qu'aucune autre session ne teste l'app (`pgrep -fl xcodebuild`), puis relancer la suite.
- **L'app :** de la tâche 1 à la tâche 4, un agent ne la lance qu'en mode démo, pour ses images (tâches 2 et 4) : `open -n -g -W "$DD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures <dossier du conteneur>`. Elle écrit ses images sans fenêtre et quitte d'elle-même (`-W` attend qu'elle ait quitté) ; l'agent vérifie qu'elle ne tourne plus. Jamais en mode direct, jamais de `screencapture`, jamais l'app de Djoko. La tâche 5 se fait avec Djoko, par le contrôleur.
- **Données personnelles** (le dépôt est public sur GitHub, `Djoko-cli/maillage-thread`) :
  - `noms.json` n'est jamais commité, ni lu par un test ;
  - les fichiers gardés de Djoko (`positions-pieces.json`, `pieces-routeurs.json`, `surnoms.json`, `identites-routeurs.json`) vivent dans le conteneur de l'app, jamais dans le dépôt ; aucun agent ne les lit. Ils sont lisibles et de version connue : rien ne change pour eux ;
  - les tests écrivent dans un dossier temporaire, avec des données inventées : ExtMac en `E0…` ou `DEADBEEF…`, noms de la démo.
- **Signature :** l'app reste ad hoc (`Signature.xcconfig`). **Ne jamais créer `Local.xcconfig`.** Aucun identifiant d'équipe, empreinte de certificat ni adresse électronique dans un fichier commité.
- **Commits :**
  - un par tâche, message en français sans accents, terminé par une ligne vide puis la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - `git add` avec la liste de fichiers de la tâche, **jamais `git add -A` ni `git add .`** ;
  - jamais de push.
- **Interdits pour les agents :** `sudo` ; ouvrir un port série ou flasher ; lancer l'app en mode direct ; `screencapture` ; lancer le passeur ou `outils/passeur.sh` ; réveiller l'écran.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `outils/tester.sh` | une cible qui ne lance aucun test fait échouer le script (n° 26) | 1 |
| `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` | section 10 : l'exception du dégagement au coût retenu (n° 30) | 1 |
| `MaillageCoeur/Scene/DispositionPieces.swift` | un départ d'un coût non fini n'est pas retenu ; sans départ d'un coût fini, la disposition de départ (n° 1) | 2 |
| `MaillageCoeur/Maillage/Maillage.swift` | `enfantsIdentifies` écarte l'entrée du balayage d'un enfant devenu routeur (n° 2) | 2 |
| `MaillageCoeur/Maillage/Rapprochement.swift` | la doc du même cas ; `extMacs` local renommé `extMacsRouteurs` (n° 2, 4) | 2 |
| `MaillageCoeur/Maillage/HistoriqueMaillage.swift` | `encode(to:)` n'écrit aucun identifiant de routeur hors de 0…62 (n° 18) | 2 |
| `MaillageCoeurTests/DispositionPiecesTests.swift`, `GrapheReseauTests.swift`, `HistoriqueTests.swift` | coût non fini, enfant devenu routeur, routeur 63 | 2 |
| `MaillageCoeur/Systeme/FichiersGardes.swift` | la règle commune des fichiers gardés (n° 3) | 3 |
| `MaillageCoeur/Scene/PlacesGardees.swift`, `PiecesRouteurs.swift`, `MaillageCoeur/Noms/ResolveurNoms.swift` (`Surnoms`), `MaillageCoeur/Maillage/IdentitesGardees.swift` | lisent et écrivent par `FichiersGardes` | 3 |
| `MaillageCoeurTests/FichiersGardesTests.swift` | version plus récente, fichier illisible, cas ordinaire, trois choix de routeurs | 3 |
| `MaillageThread/Vues/Pieces/EntreeScene.swift` | porte le graphe, le maillage rapproché, les chefs et les appareils ; égalité sur ce que la vue dessine (n° 14) | 4 |
| `MaillageThread/Vues/Pieces/FicheNoeud.swift`, `FenetrePieces.swift`, `PiecesChoisies.swift` | la fiche, la légende et le menu lisent la scène du rendu ; API des seuls tests retirée (n° 14, 15) | 4 |
| `MaillageThread/Vues/Pieces/LibellesNoeuds.swift` | `pieces(…, graphe:)` obligatoire (n° 15) | 4 |
| `MaillageThread/Surveillance/Surveillance.swift` | `cleHistorique` par `GrapheReseau.extMac(hote:)` (n° 16) | 4 |
| `MaillageThreadTests/NomsSceneTests.swift`, `FenetrePiecesTests.swift`, `FicheHeureTests.swift`, `CourbesFicheTests.swift`, `MaillageCoeurTests/PiecesAppareilsTests.swift` | tests adaptés à l'API de production ; construction de la scène ; trous de la tâche 16 (n° 27) | 4 |

---

### Task 1: Outils et doc : `tester.sh` refuse une cible qui ne lance rien ; l'exception du dégagement (n° 26, 30)

**Files:**
- Modify: `outils/tester.sh` (fichier entier : la vérification des cibles, après le bilan)
- Modify: `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` (section 10, bloc ci-dessous)

**Interfaces:**
- Consumes :
  - `xcodebuild … test -only-testing:<cible>` ; dans son journal, la ligne `Test session results, code coverage, and logs:` puis le chemin du `.xcresult` de la session ;
  - `xcrun xcresulttool get test-results tests --path <.xcresult>` (Xcode 16 ou plus) : l'arbre de ce qui a tourné, chaque nœud (paquet, suite, test) avec son `nodeIdentifierURL`, `test://com.apple.xcode/<plan>/<cible>`.
- Produces :
  - `outils/tester.sh [cibles…]` : même sortie qu'avant ; avec des cibles, chacune doit être un nœud de ce qui a tourné, sinon `echec : la cible <cible> ne lance aucun test (nom faux, ou test sans ses parentheses ?)` et le code 1. Sans cible, rien ne change ; après un échec de compilation ou de test, non plus (le code n'est déjà pas 0) ;
  - spec, section 10 : l'exception du dégagement au coût retenu.

**N° 26.** `xcodebuild` répond `** TEST SUCCEEDED **` quand un filtre ne lance aucun test : un nom faux, ou un test de Swift Testing sans ses parenthèses. B, C et D testent par filtres : un faux vert y passerait pour un vert. Le journal ne suffit pas à le voir (rien pour une suite inconnue) ; le `.xcresult` de la session, lui, liste ce qui a tourné : un paquet, une suite ou un test n'y paraît que s'il a lancé au moins un test. `tester.sh` compare donc chaque cible aux chemins de ces nœuds.

**N° 30.** La section 10 de la spec dit le coût retenu « au plus celui du départ ». Depuis le dégagement (section 4.3, ajout du 01/10), avec des pièces fixées, la disposition gardée (dégagée, ou le meilleur départ sans recouvrement) peut coûter plus. Les tests ne l'attendent d'ailleurs que sans fixée (`aucunRecouvrement`, `budget`).

- [ ] **Step 1 : constater le faux vert.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/TestsInexistants`
Expected: `** TEST SUCCEEDED **` et `journal complet : … (code 0)`, sans aucune ligne `Test run with` : la cible n'existe pas, aucun test n'a tourné, et le script répond réussi.

- [ ] **Step 2 : écrire le script.** Avec des cibles, et seulement si tout a passé, il relit le `.xcresult` de la session (son chemin est dans le journal) et cherche chaque cible parmi les nœuds qui ont tourné.

`outils/tester.sh` (fichier entier) :

```sh
#!/bin/sh
# Genere le projet puis lance les tests : tous, ou ceux passes en arguments
#   outils/tester.sh MaillageCoeurTests/AdressesTests MaillageThreadTests
# Affiche les erreurs, les tests en echec et le bilan ; journal complet dans
# $TMPDIR/maillage-tests.log. Produits de compilation hors du depot (DD).
# Chaque cible donnee doit lancer au moins un test, sinon echec : un nom faux ne lance rien, et
# xcodebuild repond pourtant TEST SUCCEEDED. Un test de Swift Testing se nomme avec ses
# parentheses (MaillageCoeurTests/GrapheReseauTests/stable()).
set -u
cd "$(dirname "$0")/.."
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage}
JOURNAL=${TMPDIR:-/tmp}/maillage-tests.log
xcodegen generate --quiet || exit 1
FILTRES=""
for t in "$@"; do FILTRES="$FILTRES -only-testing:$t"; done
# shellcheck disable=SC2086
xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' \
  -derivedDataPath "$DD" test $FILTRES > "$JOURNAL" 2>&1
CODE=$?
grep -E "(error|warning): |✘|Test run with|\*\* TEST" "$JOURNAL" | grep -v -e appintentsmetadataprocessor -e "\[Connection\]"
if [ "$CODE" -eq 0 ] && [ $# -gt 0 ]; then
  # Ce qui a tourne : les noeuds du resultat (paquet, suite, test), sous leur chemin de cible.
  RESULTATS=$(sed -n '/^Test session results/{n;s/^[[:space:]]*//;p;}' "$JOURNAL" | tail -n 1)
  LANCES=$(xcrun xcresulttool get test-results tests --path "$RESULTATS" 2>/dev/null \
    | sed -n 's|.*"nodeIdentifierURL" : "test://[^/]*/[^/]*/\([^"]*\)".*|\1|p')
  for t in "$@"; do
    if ! printf '%s\n' "$LANCES" | grep -qxF -- "$t"; then
      echo "echec : la cible $t ne lance aucun test (nom faux, ou test sans ses parentheses ?)"
      CODE=1
    fi
  done
fi
echo "journal complet : $JOURNAL (code $CODE)"
exit $CODE
```

- [ ] **Step 3 : une cible au nom faux échoue, une vraie passe.**

Run (une cible au nom faux) : `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/TestsInexistants`
Expected: `** TEST SUCCEEDED **`, `echec : la cible MaillageCoeurTests/TestsInexistants ne lance aucun test (nom faux, ou test sans ses parentheses ?)`, `journal complet : … (code 1)`.

Run (une vraie) : `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/GrapheReseauTests`
Expected: `Test run with 8 tests in 1 suite passed`, `** TEST SUCCEEDED **`, `journal complet : … (code 0)`.

Run (un test sans ses parenthèses) : `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/GrapheReseauTests/stable`
Expected: `Test run with 0 tests in 1 suite passed`, `** TEST SUCCEEDED **`, `echec : la cible MaillageCoeurTests/GrapheReseauTests/stable ne lance aucun test (nom faux, ou test sans ses parentheses ?)`, `journal complet : … (code 1)`.

Run (le même, avec) : `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh "MaillageCoeurTests/GrapheReseauTests/stable()"`
Expected: `Test run with 1 test in 1 suite passed`, `** TEST SUCCEEDED **`, `journal complet : … (code 0)`.

Run (une vraie et une fausse) : `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/GrapheReseauTests MaillageCoeurTests/TestsInexistants`
Expected: `Test run with 8 tests in 1 suite passed`, `** TEST SUCCEEDED **`, `echec : la cible MaillageCoeurTests/TestsInexistants ne lance aucun test (nom faux, ou test sans ses parentheses ?)`, `journal complet : … (code 1)`.

- [ ] **Step 4 : la spec, section 10.**

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
  - le coût de la disposition retenue est au plus celui du départ.
```

par :

```markdown
  - le coût de la disposition retenue est au plus celui du départ, sauf quand des pièces fixées imposent le dégagement (section 4.3) : la disposition gardée alors, dégagée ou meilleur départ sans recouvrement, peut coûter plus que le départ.
```

- [ ] **Step 5 : toute la suite, sans cible : rien ne change.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh`
Expected: `Test run with 336 tests in 35 suites passed` (cœur) et `Test run with 266 tests in 28 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, l'app inchangée. Sans cible, le script ne relit pas le résultat.

- [ ] **Step 6 : commit.**

```bash
git add outils/tester.sh docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md
git commit -m "Faire echouer tester.sh quand une cible ne lance aucun test, et noter l'exception du degagement au cout retenu

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Robustesse du cœur : coût non fini, enfant devenu routeur, routeur hors de 0…62 (n° 1, 2, 18 ; n° 4 en passant)

**Files:**
- Modify: `MaillageCoeur/Scene/DispositionPieces.swift` (blocs ci-dessous : n° 1)
- Modify: `MaillageCoeur/Maillage/Maillage.swift` (bloc ci-dessous : n° 2)
- Modify: `MaillageCoeur/Maillage/Rapprochement.swift` (blocs ci-dessous : la doc du n° 2, et le n° 4)
- Modify: `MaillageCoeur/Maillage/HistoriqueMaillage.swift` (bloc ci-dessous : n° 18)
- Test: `MaillageCoeurTests/DispositionPiecesTests.swift`, `MaillageCoeurTests/GrapheReseauTests.swift`, `MaillageCoeurTests/HistoriqueTests.swift`

**Interfaces:**
- Consumes :
  - `DispositionPieces.Calcul` (`depart(_:fixees:)`, `cout(_:)`, `rayon(_:_:)`), `Maillage.routeurs` (leur ExtMac), `SourceEnfant.balayage`, `ReleveMaillage.identifiantsRouteur` (0…62), existants ;
  - dans les tests : `MaisonInventee.scene`, `RapprochementTests.instantane()` et `affiches(_:)`, `ConstructionMaillage`, `HistoriqueTests.dossier()` et `date(_:)`, `JournalTests.calendrier`, existants.
- Produces :
  - `DispositionPieces.init(scene:cartes:fixees:budget:)` : un départ dont le coût n'est pas fini n'est pas retenu ; si aucun ne l'est, `positions` est `Calcul.depart(0, fixees:)`, `rayons` et `cout` en sont tirés (non finis), sans arrêt du programme ; le résultat ordinaire est identique au bit près ;
  - `Maillage.enfantsIdentifies` : sans l'entrée du balayage dont l'ExtMac est celle d'un routeur du maillage ; `MaillageAffiche(maillage:reseau:appareils:)` n'en fait ni nœud, ni lien, ni ExtMac ; `ReleveMaillage(_:)` ne la garde pas ;
  - `ReleveMaillage.encode(to:)` : aucun identifiant de routeur hors de 0…62 ; les routeurs, liens, enfants et signaux qui en citent un sont retirés, et le parent de la sonde s'il en est un.

**N° 1, coût non fini.** Un coût NaN ou infini ne se compare pas : `c < coutRetenu` n'est jamais vrai, `retenu` reste vide, puis `rayon` lit hors bornes. Depuis M3, `PlacesGardees.fixees` ignore une place démesurée, et l'app ne donne que des entrées finies ; mais un autre appelant, ou le sous-projet C, qui retouchera la disposition, en donnerait. Un départ d'un coût non fini n'est plus retenu ; sans départ d'un coût fini, la disposition est celle du départ (précision 1). Les tests forcent le coût par des entrées inventées : une carte de largeur infinie, une place fixée à 1e308 (faits établis).

**N° 2, enfant devenu routeur.** Quand un enfant devient routeur, l'entrée du balayage de son ancien parent muet reste jusqu'à 30 minutes, sous son ancien RLOC16 et avec son ExtMac. Le rapprochement en faisait un nœud « Non identifié » de plus (dans « Sans pièce », ou dans la pièce choisie pour son ExtMac : le routeur, lui, y est aussi), et l'historique un enfant de trop. `Maillage.enfantsIdentifies` écarte cette entrée ; le rapprochement ne garde, par ExtMac, que l'entrée que retient `enfantsIdentifies` (précision 26 du plan 4b) : il l'écarte donc aussi, et l'historique, qui lit `enfantsIdentifies`, de même. Le journal (`SuiviMaillage`) ne change pas d'événements : il oubliait déjà un enfant devenu routeur ; il le fait dès la tournée où l'enfant paraît routeur, au lieu de 30 minutes plus tard.

**N° 18, routeur 63.** La lecture refuse une ligne qui cite un identifiant de routeur hors de 0…62 (un RLOC16 n'en porte que six bits, 63 n'est pas attribué) : un relevé non conforme qui porte le routeur 63 était écrit, puis perdu tout entier à la relecture. L'écriture retire ce qui cite un tel identifiant ; le reste de la ligne se relit.

**N° 4, en passant.** La tâche touche `Rapprochement.swift` (la doc du n° 2) : la constante locale `extMacs`, l'ensemble des ExtMac des routeurs, devient `extMacsRouteurs`, pour ne plus avoir le nom de la propriété `extMacs`.

- [ ] **Step 1 : écrire les tests.** Cinq tests, dans trois fichiers du cœur, sur des entrées inventées.

Dans `MaillageCoeurTests/DispositionPiecesTests.swift`, remplacer :

```swift
    /// Plateaux cote a cote en 2D : `esp` entre les bords de deux voisins, la rangee centree sur x = 0.
```

par :

```swift
    /// Un cout non fini, venu d'une carte de largeur infinie (une entree que l'app ne donne pas : elle
    /// mesure ses noms) : aucun depart n'est retenu, et la disposition garde son depart, celui d'avant
    /// l'optimisation (la spirale du premier essai), sans arret du programme.
    @Test func coutNonFini() {
        let (s, cartes) = MaisonInventee.scene(pieces: 6, appareils: 20, routeurs: 3)
        var c = cartes
        c[0].largeur = .infinity
        let d = DispositionPieces(scene: s, cartes: c)
        #expect(d.positions == DispositionPieces.Calcul(scene: s, cartes: c, fixees: [:]).depart(0, fixees: [:]))
        #expect(d.rayons.count == s.etages.count)
        #expect(!d.cout.isFinite && !d.coutDepart.isFinite)
    }

    /// Une place fixee demesuree (1e308 : `PlacesGardees.fixees` l'ignore, un autre appelant pourrait la
    /// donner) rend le rayon de son etage infini : le meme repli sur le depart, la fixee a sa place.
    @Test func placeFixeeDemesuree() {
        let (s, c) = MaisonInventee.scene(pieces: 6, appareils: 20, routeurs: 3)
        let fixees = [0: SIMD2(1e308, 0.0)]
        let d = DispositionPieces(scene: s, cartes: c, fixees: fixees)
        #expect(d.positions == DispositionPieces.Calcul(scene: s, cartes: c, fixees: fixees).depart(0, fixees: fixees))
        #expect(d.positions[0] == fixees[0])
        #expect(!d.cout.isFinite)
    }

    /// Plateaux cote a cote en 2D : `esp` entre les bords de deux voisins, la rangee centree sur x = 0.
```

Dans `MaillageCoeurTests/GrapheReseauTests.swift`, remplacer :

```swift
    /// Elimination : le HomePod palier, reconnu par elimination, est un seul noeud.
```

par :

```swift
    /// Un enfant devenu routeur garde jusqu'a 30 minutes son entree du balayage d'un routeur muet, sous
    /// son ancien RLOC16 : elle est ecartee, son ExtMac etant celle d'un routeur du maillage. Pas de
    /// noeud « Non identifie » en double, ni de lien, ni d'ExtMac a son nom (la cle d'un choix de piece).
    @Test func enfantDevenuRouteur() throws {
        let i = RapprochementTests.instantane()
        let r = try #require(i.reseaux.first)
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.routeurs(Route64(sequence: 1, routes: [0, 1, 2].map {
            RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1)
        }), chef: 0)
        c.identite("E000000000000004", routeur: 1)
        c.muet(2)
        c.enfant(EnfantMaillage(rloc16: 0x0802, extMac: "E000000000000004", source: .balayage))
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        let g = GrapheReseau(reseau: r, appareils: RapprochementTests.affiches(i), maillage: m)
        #expect(g.noeud("rloc:0802") == nil, "pas de noeud en double")
        #expect(!g.noeuds.contains { $0.inconnu && $0.genre == .appareil })
        #expect(g.noeud("E000000000000004")?.routeur == true, "l'appareil est le routeur 1")
        #expect(!g.liens.contains { $0.de == "rloc:0802" })
        #expect(m.extMacs["rloc:0802"] == nil)
    }

    /// Elimination : le HomePod palier, reconnu par elimination, est un seul noeud.
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift
    /// Un octet non UTF-8 (0xC3 isole : un caractere accentue coupe) abime sa ligne seulement : les
```

par :

```swift
    /// Un enfant devenu routeur garde jusqu'a 30 minutes son entree du balayage d'un routeur muet : elle
    /// est ecartee, son ExtMac etant celle d'un routeur du maillage. L'historique n'a pas d'enfant de
    /// trop ; un autre enfant du meme balayage reste.
    @Test func enfantDevenuRouteur() {
        var c = ConstructionMaillage(date: Self.date("2026-09-30T10:00:00Z"), partition: "0000000A")
        c.routeurs(Route64(sequence: 1, routes: [0, 1, 2].map {
            RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1)
        }), chef: 0)
        c.identite("E0000000000000B2", routeur: 2)
        c.muet(1)
        c.enfant(EnfantMaillage(rloc16: 0x0402, extMac: "E0000000000000B2", source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x0403, extMac: "E0000000000000B3", source: .balayage))
        let m = c.maillage()
        #expect(m.enfantsIdentifies["E0000000000000B2"] == nil, "devenu routeur")
        #expect(m.enfantsIdentifies["E0000000000000B3"]?.rloc16 == 0x0403)
        #expect(ReleveMaillage(m).enfants.map(\.extMac) == ["E0000000000000B3"])
    }

    /// Un releve qui cite le routeur 63 (hors de 0...62 : des donnees non conformes) s'ecrit sans lui :
    /// ni ce routeur, ni ses liens, ni ses enfants, ni son signal, ni la sonde sous lui. Le reste de la
    /// ligne se relit, au lieu d'etre perdu avec elle.
    @Test func routeurHorsPlageNonEcrit() throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        let h = HistoriqueFichiers(dossier: d, calendrier: JournalTests.calendrier)
        let date = Self.date("2026-09-30T10:00:00Z")
        typealias R = ReleveMaillage
        try h.ajouter(R(date: date, partition: "0000000A",
                        routeurs: [R.Routeur(id: 0, extMac: "E0000000000000A0"), R.Routeur(id: 63, extMac: "E0000000000000A3")],
                        liens: [LienRadio(a: 0, b: 1, qualiteAB: 3, qualiteBA: 2), LienRadio(a: 0, b: 63, qualiteAB: 1, qualiteBA: 1)],
                        enfants: [R.Enfant(extMac: "E0000000000000B1", parent: 0, qualite: 3),
                                  R.Enfant(extMac: "E0000000000000B3", parent: 63, qualite: 2)],
                        signaux: [SignalSonde(routeur: 0, rssi: -60), SignalSonde(routeur: 63, rssi: -70)],
                        parentSonde: 63))
        let reste = R(date: date, partition: "0000000A", routeurs: [R.Routeur(id: 0, extMac: "E0000000000000A0")],
                      liens: [LienRadio(a: 0, b: 1, qualiteAB: 3, qualiteBA: 2)],
                      enfants: [R.Enfant(extMac: "E0000000000000B1", parent: 0, qualite: 3)],
                      signaux: [SignalSonde(routeur: 0, rssi: -60)], parentSonde: nil)
        #expect(try h.lire(depuis: .distantPast) == [reste])
    }

    /// Un octet non UTF-8 (0xC3 isole : un caractere accentue coupe) abime sa ligne seulement : les
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/DispositionPiecesTests MaillageCoeurTests/GrapheReseauTests MaillageCoeurTests/HistoriqueTests`
Expected: `** TEST FAILED **` ; en échec : `GrapheReseauTests.enfantDevenuRouteur()` (4 attentes), `HistoriqueTests.enfantDevenuRouteur()` (2 attentes), `HistoriqueTests.routeurHorsPlageNonEcrit()` (1 attente) ; et `coutNonFini` et `placeFixeeDemesuree` arrêtent le processus des tests (`retenu` vide, `rayon` hors bornes) : le journal complet dit 2 fois `Restarting after unexpected exit, crash, or test timeout`, et le dernier bilan affiché ne compte que la dernière relance (faits établis).

- [ ] **Step 3 : écrire le code.** Dans l'ordre : la disposition (n° 1), les enfants identifiés (n° 2), le rapprochement (doc du n° 2, n° 4), l'historique (n° 18).

Dans `MaillageCoeur/Scene/DispositionPieces.swift`, remplacer :

```swift
    /// pas et servent d'obstacles.
```

par :

```swift
    /// pas et servent d'obstacles. Un depart d'un cout non fini (une entree demesuree) n'est pas
    /// retenu ; sans depart d'un cout fini, la disposition est celle du depart, sans arret du programme.
```

Dans `MaillageCoeur/Scene/DispositionPieces.swift`, remplacer :

```swift
            if c < coutRetenu {
```

par :

```swift
            // Un cout non fini (une entree demesuree) ne se compare pas : ce depart n'est pas retenu.
            guard c.isFinite else { continue }
            if c < coutRetenu {
```

Dans `MaillageCoeur/Scene/DispositionPieces.swift`, remplacer :

```swift
        }
        // Avec des pieces fixees, une carte libre peut finir sur une autre carte : le tassement
```

par :

```swift
        }
        // Aucun depart d'un cout fini : la disposition de depart, celle d'avant l'optimisation (la
        // spirale du premier essai, les fixees a leur place), sans degagement.
        guard !retenu.isEmpty else {
            let pos = calcul.depart(0, fixees: fixees)
            positions = pos
            rayons = (0..<calcul.nbEtages).map { calcul.rayon(pos, $0) }
            coutDepart = depart
            cout = calcul.cout(pos)
            coups = joues
            return
        }
        // Avec des pieces fixees, une carte libre peut finir sur une autre carte : le tassement
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    /// d'un routeur muet, qui peut dater de 30 minutes ; a egalite, la premiere par RLOC16.
```

par :

```swift
    /// d'un routeur muet, qui peut dater de 30 minutes ; a egalite, la premiere par RLOC16. Une entree
    /// du balayage dont l'ExtMac est celle d'un routeur du maillage est ecartee : l'enfant est devenu
    /// routeur depuis le balayage.
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
        var parExtMac: [String: EnfantMaillage] = [:]
        for e in enfants {
            guard let x = e.extMac else { continue }
```

par :

```swift
        let routeursExt = Set(routeurs.compactMap(\.extMac))
        var parExtMac: [String: EnfantMaillage] = [:]
        for e in enfants {
            guard let x = e.extMac, !(e.source == .balayage && routeursExt.contains(x)) else { continue }
```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
    /// lien : ceux de l'entree que retient `Maillage.enfantsIdentifies` ; l'autre est ecartee.
```

par :

```swift
    /// lien : ceux de l'entree que retient `Maillage.enfantsIdentifies` ; l'autre est ecartee. L'entree
    /// du balayage d'un enfant devenu routeur (l'ExtMac d'un routeur du maillage) n'en donne aucun.
```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
        let extMacs = Set(maillage.routeurs.compactMap(\.extMac))
        func possible(_ r: RouteurMaillage, _ a: RouteurBordure) -> Bool {
            guard let xa = a.adresseEtendue else { return true }
            return r.extMac == nil && !extMacs.contains(xa)
```

par :

```swift
        let extMacsRouteurs = Set(maillage.routeurs.compactMap(\.extMac))
        func possible(_ r: RouteurMaillage, _ a: RouteurBordure) -> Bool {
            guard let xa = a.adresseEtendue else { return true }
            return r.extMac == nil && !extMacsRouteurs.contains(xa)
```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
        // ecartee, sans noeud ni lien.
```

par :

```swift
        // ecartee, sans noeud ni lien. De meme pour l'entree du balayage d'un enfant devenu routeur,
        // qu'elle ne retient pas.
```

Dans `MaillageCoeur/Maillage/HistoriqueMaillage.swift`, remplacer :

```swift
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(partition, forKey: .partition)
        var r = c.nestedUnkeyedContainer(forKey: .routeurs)
        for x in routeurs {
            var l = r.nestedUnkeyedContainer()
            try l.encode(x.id)
            try l.encodeOuNul(x.extMac)
        }
        var li = c.nestedUnkeyedContainer(forKey: .liens)
        for x in liens {
            var l = li.nestedUnkeyedContainer()
            try l.encode(x.a)
            try l.encode(x.b)
            try l.encodeOuNul(x.qualiteAB)
            try l.encodeOuNul(x.qualiteBA)
        }
        var e = c.nestedUnkeyedContainer(forKey: .enfants)
        for x in enfants {
            var l = e.nestedUnkeyedContainer()
            try l.encode(x.extMac)
            try l.encode(x.parent)
            try l.encodeOuNul(x.qualite)
        }
        var s = c.nestedUnkeyedContainer(forKey: .signaux)
        for x in signaux {
            var l = s.nestedUnkeyedContainer()
            try l.encode(x.routeur)
            try l.encode(x.rssi)
        }
        try c.encodeIfPresent(parentSonde, forKey: .parentSonde)
```

par :

```swift
    /// N'ecrit jamais un identifiant de routeur hors de 0...62 (donnees non conformes) : la lecture
    /// refuserait toute la ligne. Les routeurs, liens, enfants et signaux qui en citent un sont retires,
    /// et le parent de la sonde s'il en est un ; le reste de la ligne est garde.
    public func encode(to encoder: any Encoder) throws {
        let ids = Self.identifiantsRouteur
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(partition, forKey: .partition)
        var r = c.nestedUnkeyedContainer(forKey: .routeurs)
        for x in routeurs where ids.contains(x.id) {
            var l = r.nestedUnkeyedContainer()
            try l.encode(x.id)
            try l.encodeOuNul(x.extMac)
        }
        var li = c.nestedUnkeyedContainer(forKey: .liens)
        for x in liens where ids.contains(x.a) && ids.contains(x.b) {
            var l = li.nestedUnkeyedContainer()
            try l.encode(x.a)
            try l.encode(x.b)
            try l.encodeOuNul(x.qualiteAB)
            try l.encodeOuNul(x.qualiteBA)
        }
        var e = c.nestedUnkeyedContainer(forKey: .enfants)
        for x in enfants where ids.contains(x.parent) {
            var l = e.nestedUnkeyedContainer()
            try l.encode(x.extMac)
            try l.encode(x.parent)
            try l.encodeOuNul(x.qualite)
        }
        var s = c.nestedUnkeyedContainer(forKey: .signaux)
        for x in signaux where ids.contains(x.routeur) {
            var l = s.nestedUnkeyedContainer()
            try l.encode(x.routeur)
            try l.encode(x.rssi)
        }
        try c.encodeIfPresent(parentSonde.flatMap { ids.contains($0) ? $0 : nil }, forKey: .parentSonde)
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/DispositionPiecesTests MaillageCoeurTests/GrapheReseauTests MaillageCoeurTests/HistoriqueTests`
Expected: `Test run with 30 tests in 3 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les temps, en Release.** La disposition ne doit pas ralentir : la grande maison inventée sous 1 s, 3 000 coups.

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/mesurer.sh`
Expected: `mesure : disposition de la grande maison en 0.257454791 s, 3000 coups` ; `mesure : placement de 150 noms en 0.3132354 ms, 150 poses` ; `mesure : placement de 150 noms tres serres en 2.8367146 ms, 30 poses` (ces temps-ci au rejeu, qui varient d'une machine à l'autre ; les coups et les poses, non), puis `Test run with 19 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh`
Expected: `Test run with 341 tests in 35 suites passed` (cœur) et `Test run with 266 tests in 28 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 5 tests de plus pour le cœur, l'app inchangée. Les cinq tests de la tâche s'ajoutent au cœur.

- [ ] **Step 7 : les images de démo, identiques.** L'app, en mode démo seulement, écrit douze images de 1440 × 900 points en 2x dans son conteneur, sans fenêtre, puis quitte ; `open -W` attend qu'elle ait quitté. Chacune doit être identique, octet pour octet, à celle de la relecture finale du plan 4b : cette tâche ne change pas le rendu.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polA"
R="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-plan4b-finale"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polA/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polA/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
n=0; for f in "$D"/*.png; do cmp -s "$f" "$R/$(basename "$f")" && n=$((n+1)) || echo "différente : $(basename "$f")"; done; echo "$n identiques sur $(ls "$D" | wc -l | tr -d ' ')"
```

Expected : 12 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`) ; « l'app a quitté » ; « 12 identiques sur 12 ». Si une image diffère, s'arrêter : la tâche a changé le rendu.

- [ ] **Step 8 : commit.**

```bash
git add MaillageCoeurTests/DispositionPiecesTests.swift MaillageCoeurTests/GrapheReseauTests.swift MaillageCoeurTests/HistoriqueTests.swift MaillageCoeur/Scene/DispositionPieces.swift MaillageCoeur/Maillage/Maillage.swift MaillageCoeur/Maillage/Rapprochement.swift MaillageCoeur/Maillage/HistoriqueMaillage.swift
git commit -m "Garder le depart d'une disposition sans cout fini, ecarter le balayage d'un enfant devenu routeur, et n'ecrire aucun routeur hors de 0 a 62 dans l'historique

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Fichiers gardés : jamais réécrits plus récents, mis de côté illisibles (n° 3)

**Files:**
- Create: `MaillageCoeur/Systeme/FichiersGardes.swift`
- Modify: `MaillageCoeur/Scene/PlacesGardees.swift`, `MaillageCoeur/Scene/PiecesRouteurs.swift`, `MaillageCoeur/Noms/ResolveurNoms.swift` (`Surnoms`), `MaillageCoeur/Maillage/IdentitesGardees.swift` (blocs ci-dessous : `lire` et `ecrire` passent par `FichiersGardes`)
- Test: `MaillageCoeurTests/FichiersGardesTests.swift`

**Interfaces:**
- Consumes :
  - `PlacesGardees.versionActuelle` et `PiecesRouteurs.versionActuelle` (1), `Surnoms`, `IdentitesGardees`, existants ; `os.Logger`, `OSAllocatedUnfairLock`.
- Produces :
  - `enum FichiersGardes` (interne au cœur) : `Etat` (`absent`, `lisible`, `plusRecent`, `illisible`) ; `examiner(_:_:version:) -> (etat: Etat, contenu: T?)` ; `lire(_:_:version:) -> T?` ; `ecrire(_:dans:version:) throws` ; `mettreDeCote(_:maintenant:) throws -> URL` ;
  - `PlacesGardees.lire(_:)` et `ecrire(dans:)`, `PiecesRouteurs.lire(_:)` et `ecrire(dans:)`, `Surnoms.lire(_:)` et `ecrire(_:dans:)`, `IdentitesGardees.lire(_:)` et `ecrire(dans:)` : mêmes signatures, par `FichiersGardes`.

**N° 3.** Un fichier gardé illisible, ou d'une version plus récente, était lu vide, puis écrasé sans copie à la première écriture : surnoms, pièces choisies, places et ordre des étages perdus. L'avis « les données se recalculent » ne vaut plus depuis la tâche 16 du plan 4b (le même schéma garde les choix de pièce de Djoko), et les surnoms ne se recalculent pas non plus. Une build plus ancienne écraserait un format plus récent, et le sous-projet C changera sans doute `positions-pieces.json`.

Une règle commune, dans le cœur, pour les quatre fichiers du conteneur (`FichiersGardes`, précision 4) :
- **d'une version plus récente :** lu, en mémoire, comme vide, et jamais réécrit ; l'app travaille en mémoire ; une note au journal du Mac, une fois ;
- **illisible, mais présent :** lu vide ; avant la première écriture, mis de côté par un renommage en `<nom>.illisible-<AAAAMMJJ-HHMMSS>.json`, dans le même dossier, jamais effacé ;
- **absent, ou lisible et de version connue :** rien ne change, ni la lecture ni l'écriture (JSON aux clés triées, indenté, écrit d'un bloc).

`IdentitesGardees` a le même schéma que les surnoms (vérifié) : la règle s'y applique, sans version. Les vrais fichiers de Djoko sont lisibles et de version connue : rien ne change pour lui.

- [ ] **Step 1 : écrire les tests.** Un fichier de tests, dans un dossier temporaire, sur les quatre fichiers gardés.

`MaillageCoeurTests/FichiersGardesTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

/// Fichiers gardes dans le conteneur de l'app : places des pieces, pieces choisies, surnoms, identites
/// des routeurs. Un fichier d'une version plus recente n'est jamais reecrit ; un fichier illisible est
/// mis de cote avant d'etre remplace ; le cas ordinaire ne change pas. Dans un dossier temporaire, avec
/// des donnees inventees.
@Suite("Fichiers gardes : version plus recente, fichier illisible")
struct FichiersGardesTests {
    static let domicile = "Maison inventée"

    static func dossier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("fichiers-\(UUID().uuidString)")
    }

    /// Les noms des fichiers du dossier, tries.
    static func noms(_ d: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: d.path).sorted()
    }

    /// Une sorte de fichier garde : son nom, et un aller-retour (lire, changer une valeur inventee,
    /// ecrire, relire) qui rend vrai si la valeur ecrite se relit.
    struct Sorte: Sendable, CustomTestStringConvertible {
        var nom: String
        var allerRetour: @Sendable (URL) throws -> Bool
        var testDescription: String { nom }
    }

    static let sortes = [
        Sorte(nom: "positions-pieces.json") { url in
            var p = PlacesGardees.lire(url)
            p.garder(SIMD2(1.5, -2.25), piece: "piece:Salon", etage: "zone:Étage", domicile: domicile)
            try p.ecrire(dans: url)
            return PlacesGardees.lire(url) == p
        },
        Sorte(nom: "pieces-routeurs.json") { url in
            var p = PiecesRouteurs.lire(url)
            p.choisir("Salon", routeur: "HomePod Palier", domicile: domicile)
            try p.ecrire(dans: url)
            return PiecesRouteurs.lire(url) == p
        },
        Sorte(nom: "surnoms.json") { url in
            var s = Surnoms.lire(url)
            s["DEADBEEF00000001"] = "Lampe inventée"
            try Surnoms.ecrire(s, dans: url)
            return Surnoms.lire(url) == s
        },
        Sorte(nom: "identites-routeurs.json") { url in
            var g = IdentitesGardees.lire(url) ?? IdentitesGardees(partition: "0000000A", identites: [:])
            g.identites[0x0400] = "E0000000000000A1"
            try g.ecrire(dans: url)
            return IdentitesGardees.lire(url) == g
        },
    ]

    /// Un fichier illisible, mais present, est lu comme vide ; a la premiere ecriture, il est mis de
    /// cote (renomme `<nom>.illisible-AAAAMMJJ-HHMMSS.json` dans le meme dossier, son contenu intact),
    /// puis remplace par le fichier ecrit. La suivante ne met plus rien de cote.
    @Test(arguments: sortes)
    func illisibleMisDeCote(_ sorte: Sorte) throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let url = d.appendingPathComponent(sorte.nom)
        let abime = Data("{pas du json".utf8)
        try abime.write(to: url)
        #expect(try sorte.allerRetour(url))
        let noms = try Self.noms(d)
        let base = url.deletingPathExtension().lastPathComponent
        let mis = noms.filter { $0 != sorte.nom }
        #expect(noms.contains(sorte.nom) && mis.count == 1, "\(noms)")
        let deCote = try #require(mis.first)
        #expect(deCote.wholeMatch(of: /(.+)\.illisible-\d{8}-\d{6}\.json/)?.output.1 == Substring(base), "\(deCote)")
        #expect(try Data(contentsOf: d.appendingPathComponent(deCote)) == abime, "son contenu intact")
        #expect(try sorte.allerRetour(url))
        #expect(try Self.noms(d) == noms, "rien de plus mis de cote")
    }

    /// Un fichier d'une version plus recente (ecrit par une app plus recente, peut-etre d'un autre
    /// schema) est lu comme vide, et jamais reecrit : l'app travaille en memoire, sans erreur.
    @Test(arguments: [#"{"maisons":{"Maison inventée":{"HomePod Palier":"Salon"}},"nouveau":true,"version":2}"#,
                      #"{"maisons":["un autre schéma"],"version":2}"#])
    func plusRecentJamaisReecrit(_ json: String) throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let routeurs = d.appendingPathComponent("pieces-routeurs.json")
        let places = d.appendingPathComponent("positions-pieces.json")
        let recent = Data(json.utf8)
        try recent.write(to: routeurs)
        try recent.write(to: places)
        var p = PiecesRouteurs.lire(routeurs)
        #expect(p == PiecesRouteurs(), "lu comme vide")
        p.choisir("Bureau", routeur: "Apple TV", domicile: Self.domicile)
        try p.ecrire(dans: routeurs)
        var g = PlacesGardees.lire(places)
        #expect(g == PlacesGardees(), "lu comme vide")
        g.ordonner(["zone:Étage"], domicile: Self.domicile)
        try g.ecrire(dans: places)
        #expect(try Data(contentsOf: routeurs) == recent && Data(contentsOf: places) == recent, "jamais reecrit")
        #expect(try Self.noms(d) == ["pieces-routeurs.json", "positions-pieces.json"], "rien de mis de cote")
    }

    /// Le cas ordinaire ne change pas : absent, le fichier est ecrit ; lisible et d'une version connue,
    /// il est relu et reecrit a sa place, sans rien mettre de cote.
    @Test(arguments: sortes)
    func casOrdinaire(_ sorte: Sorte) throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        let url = d.appendingPathComponent(sorte.nom)
        #expect(try sorte.allerRetour(url), "absent")
        #expect(try sorte.allerRetour(url), "lisible")
        #expect(try Self.noms(d) == [sorte.nom])
    }

    /// Un fichier valide d'une app d'avant (les routeurs seuls) garde ses trois choix de routeurs quand
    /// l'app y ajoute le choix d'un appareil : il n'est ni mis de cote ni lu comme vide.
    @Test func troisChoixDesRouteurs() throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let url = d.appendingPathComponent("pieces-routeurs.json")
        let ancien = """
            {
              "maisons" : {
                "" : {
                  "HomePod" : "Cuisine"
                },
                "Maison inventée" : {
                  "Apple TV" : "Salon",
                  "HomePod Palier" : "Bureau"
                }
              },
              "version" : 1
            }
            """
        try Data(ancien.utf8).write(to: url)
        let routeurs = ["": ["HomePod": "Cuisine"], Self.domicile: ["Apple TV": "Salon", "HomePod Palier": "Bureau"]]
        var p = PiecesRouteurs.lire(url)
        #expect(p.maisons == routeurs)
        p.choisir("Salon", appareil: "DEADBEEF00000001", domicile: Self.domicile)
        try p.ecrire(dans: url)
        #expect(PiecesRouteurs.lire(url).maisons == routeurs)
        #expect(PiecesRouteurs.lire(url).choix(appareil: "DEADBEEF00000001", domicile: Self.domicile) == "Salon")
        #expect(try Self.noms(d) == ["pieces-routeurs.json"])
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/FichiersGardesTests MaillageCoeurTests/PlacesGardeesTests MaillageCoeurTests/PiecesRouteursTests MaillageCoeurTests/PiecesAppareilsTests MaillageCoeurTests/IdentitesGardeesTests MaillageCoeurTests/NomsTests`
Expected: `** TEST FAILED **` ; en échec : `FichiersGardesTests.illisibleMisDeCote(_:)` (8 attentes), `FichiersGardesTests.plusRecentJamaisReecrit(_:)` (2 attentes) ; `casOrdinaire` et `troisChoixDesRouteurs` passent déjà : ils fixent le comportement ordinaire, qui ne doit pas changer.

- [ ] **Step 3 : écrire le code.** La règle commune, puis les quatre fichiers.

`MaillageCoeur/Systeme/FichiersGardes.swift` (fichier entier) :

```swift
import Foundation
import os

/// Fichiers JSON gardes dans le conteneur de l'app : les places des pieces (`positions-pieces.json`),
/// les pieces choisies (`pieces-routeurs.json`), les surnoms (`surnoms.json`) et les identites des
/// routeurs (`identites-routeurs.json`). Une regle commune, pour ne jamais perdre ce qu'ils gardent :
/// - absent, ou lisible et d'une version connue : lu et ecrit comme d'habitude ;
/// - d'une version plus recente (une app plus recente l'a ecrit, peut-etre sous un autre schema) : lu
///   comme vide, et jamais reecrit ; l'app travaille en memoire, et le note une fois au journal du Mac ;
/// - present mais illisible : lu comme vide ; avant la premiere ecriture, il est mis de cote, renomme
///   `<nom>.illisible-AAAAMMJJ-HHMMSS.json` dans le meme dossier, et jamais efface.
/// L'etat du fichier est relu avant chaque ecriture : rien n'est retenu d'une lecture a l'autre.
enum FichiersGardes {
    /// Ce qu'est le fichier sur le disque.
    enum Etat: Equatable {
        case absent, lisible, plusRecent, illisible
    }

    /// Le numero de version d'un fichier qui en a un, lu seul : un fichier plus recent peut avoir un
    /// autre schema.
    private struct Version: Decodable {
        var version: Int
    }

    /// Journal du Mac (Console, sous-systeme fr.djoko.maillage) : le nom du fichier, jamais son contenu.
    static let journal = Logger(subsystem: "fr.djoko.maillage", category: "fichiers")
    /// Fichiers d'une version plus recente deja notes au journal, dans ce processus.
    private static let notes = OSAllocatedUnfairLock(initialState: Set<String>())

    /// L'etat du fichier, et son contenu s'il est lisible. `version` : la plus recente que l'app sait
    /// lire ; nil pour un fichier sans version.
    static func examiner<T: Decodable>(_ type: T.Type, _ url: URL, version: Int?) -> (etat: Etat, contenu: T?) {
        guard FileManager.default.fileExists(atPath: url.path) else { return (.absent, nil) }
        guard let d = try? Data(contentsOf: url) else { return (.illisible, nil) }
        if let version {
            guard let v = try? JSONDecoder().decode(Version.self, from: d) else { return (.illisible, nil) }
            if v.version > version { return (.plusRecent, nil) }
        }
        guard let contenu = try? JSONDecoder().decode(T.self, from: d) else { return (.illisible, nil) }
        return (.lisible, contenu)
    }

    /// Le contenu du fichier ; nil s'il manque, s'il est illisible ou d'une version plus recente.
    static func lire<T: Decodable>(_ type: T.Type, _ url: URL, version: Int? = nil) -> T? {
        let (etat, contenu) = examiner(type, url, version: version)
        if etat == .plusRecent { noterPlusRecent(url) }
        return contenu
    }

    /// Ecrit `valeur` en JSON (cles triees, indente), d'un bloc. Sur un fichier d'une version plus
    /// recente, rien n'est ecrit, sans erreur. Un fichier illisible est d'abord mis de cote.
    static func ecrire<T: Codable>(_ valeur: T, dans url: URL, version: Int? = nil) throws {
        switch examiner(T.self, url, version: version).etat {
        case .plusRecent:
            noterPlusRecent(url)
            return
        case .illisible:
            try mettreDeCote(url)
        case .absent, .lisible:
            break
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try e.encode(valeur).write(to: url, options: .atomic)
    }

    /// Renomme le fichier `<nom>.illisible-AAAAMMJJ-HHMMSS.json` dans son dossier, a l'heure locale, et
    /// le note au journal ; rend son nouveau chemin. Un fichier deja la sous ce nom n'est pas remplace :
    /// le renommage echoue.
    @discardableResult
    static func mettreDeCote(_ url: URL, maintenant: Date = Date()) throws -> URL {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .current
        let c = calendrier.dateComponents([.year, .month, .day, .hour, .minute, .second], from: maintenant)
        let horodatage = String(format: "%04d%02d%02d-%02d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0,
                                c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
        let nom = url.deletingPathExtension().lastPathComponent + ".illisible-" + horodatage + ".json"
        let cible = url.deletingLastPathComponent().appendingPathComponent(nom)
        try FileManager.default.moveItem(at: url, to: cible)
        journal.notice("\(url.lastPathComponent, privacy: .public) illisible, mis de cote : \(nom, privacy: .public)")
        return cible
    }

    /// Note au journal, une fois par fichier et par lancement, qu'il est d'une version plus recente.
    private static func noterPlusRecent(_ url: URL) {
        guard notes.withLock({ $0.insert(url.path).inserted }) else { return }
        journal.notice("\(url.lastPathComponent, privacy: .public) d'une version plus recente : lu comme vide, jamais reecrit")
    }
}
```

Dans `MaillageCoeur/Scene/PlacesGardees.swift`, remplacer :

```swift
    /// Vide si le fichier manque, est illisible, ou d'une version plus recente.
    public static func lire(_ url: URL) -> PlacesGardees {
        guard let d = try? Data(contentsOf: url), let p = try? JSONDecoder().decode(PlacesGardees.self, from: d),
              p.version <= versionActuelle else { return PlacesGardees() }
        return p
    }

    public func ecrire(dans url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try e.encode(self).write(to: url, options: .atomic)
```

par :

```swift
    /// Vide si le fichier manque, est illisible, ou d'une version plus recente (`FichiersGardes`).
    public static func lire(_ url: URL) -> PlacesGardees {
        FichiersGardes.lire(PlacesGardees.self, url, version: versionActuelle) ?? PlacesGardees()
    }

    /// Rien n'est ecrit sur un fichier d'une version plus recente ; un fichier illisible est d'abord mis
    /// de cote (`FichiersGardes`).
    public func ecrire(dans url: URL) throws {
        try FichiersGardes.ecrire(self, dans: url, version: Self.versionActuelle)
```

Dans `MaillageCoeur/Scene/PiecesRouteurs.swift`, remplacer :

```swift
    /// Vide si le fichier manque, est illisible, ou d'une version plus recente.
    public static func lire(_ url: URL) -> PiecesRouteurs {
        guard let d = try? Data(contentsOf: url), let p = try? JSONDecoder().decode(PiecesRouteurs.self, from: d),
              p.version <= versionActuelle else { return PiecesRouteurs() }
        return p
    }

    public func ecrire(dans url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try e.encode(self).write(to: url, options: .atomic)
```

par :

```swift
    /// Vide si le fichier manque, est illisible, ou d'une version plus recente (`FichiersGardes`).
    public static func lire(_ url: URL) -> PiecesRouteurs {
        FichiersGardes.lire(PiecesRouteurs.self, url, version: versionActuelle) ?? PiecesRouteurs()
    }

    /// Rien n'est ecrit sur un fichier d'une version plus recente ; un fichier illisible est d'abord mis
    /// de cote (`FichiersGardes`).
    public func ecrire(dans url: URL) throws {
        try FichiersGardes.ecrire(self, dans: url, version: Self.versionActuelle)
```

Dans `MaillageCoeur/Noms/ResolveurNoms.swift`, remplacer :

```swift
    /// Vide si le fichier manque ou est illisible.
    public static func lire(_ url: URL) -> [String: String] {
        guard let d = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return s
    }

    public static func ecrire(_ surnoms: [String: String], dans url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try e.encode(surnoms).write(to: url, options: .atomic)
```

par :

```swift
    /// Vide si le fichier manque ou est illisible (`FichiersGardes`).
    public static func lire(_ url: URL) -> [String: String] {
        FichiersGardes.lire([String: String].self, url) ?? [:]
    }

    /// Un fichier illisible est d'abord mis de cote (`FichiersGardes`).
    public static func ecrire(_ surnoms: [String: String], dans url: URL) throws {
        try FichiersGardes.ecrire(surnoms, dans: url)
```

Dans `MaillageCoeur/Maillage/IdentitesGardees.swift`, remplacer :

```swift
    /// nil si le fichier manque ou est illisible ; un RLOC16 illisible est ignore.
    public static func lire(_ url: URL) -> IdentitesGardees? {
        guard let d = try? Data(contentsOf: url), let f = try? JSONDecoder().decode(Fichier.self, from: d) else {
            return nil
        }
```

par :

```swift
    /// nil si le fichier manque ou est illisible (`FichiersGardes`) ; un RLOC16 illisible est ignore.
    public static func lire(_ url: URL) -> IdentitesGardees? {
        guard let f = FichiersGardes.lire(Fichier.self, url) else { return nil }
```

Dans `MaillageCoeur/Maillage/IdentitesGardees.swift`, remplacer :

```swift
    public func ecrire(dans url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        let routeurs = Dictionary(uniqueKeysWithValues: identites.map { (String(format: "%04X", $0.key), $0.value) })
        try e.encode(Fichier(partition: partition, routeurs: routeurs)).write(to: url, options: .atomic)
```

par :

```swift
    /// Un fichier illisible est d'abord mis de cote (`FichiersGardes`).
    public func ecrire(dans url: URL) throws {
        let routeurs = Dictionary(uniqueKeysWithValues: identites.map { (String(format: "%04X", $0.key), $0.value) })
        try FichiersGardes.ecrire(Fichier(partition: partition, routeurs: routeurs), dans: url)
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/FichiersGardesTests MaillageCoeurTests/PlacesGardeesTests MaillageCoeurTests/PiecesRouteursTests MaillageCoeurTests/PiecesAppareilsTests MaillageCoeurTests/IdentitesGardeesTests MaillageCoeurTests/NomsTests`
Expected: `Test run with 41 tests in 6 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh`
Expected: `Test run with 345 tests in 36 suites passed` (cœur) et `Test run with 266 tests in 28 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 4 tests et 1 suite de plus pour le cœur, l'app inchangée. Une suite de quatre tests s'ajoute au cœur.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeurTests/FichiersGardesTests.swift MaillageCoeur/Systeme/FichiersGardes.swift MaillageCoeur/Scene/PlacesGardees.swift MaillageCoeur/Scene/PiecesRouteurs.swift MaillageCoeur/Noms/ResolveurNoms.swift MaillageCoeur/Maillage/IdentitesGardees.swift
git commit -m "Ne jamais reecrire un fichier garde d'une version plus recente, et mettre de cote un fichier illisible avant de le remplacer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Fiche, menu et placement : une seule construction par rendu (n° 14, 15, 16 ; n° 27 en passant)

**Files:**
- Modify: `MaillageThread/Vues/Pieces/EntreeScene.swift` (fichier entier)
- Modify: `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, `PiecesChoisies.swift`, `FicheNoeud.swift`, `FenetrePieces.swift`, `MaillageThread/Surveillance/Surveillance.swift` (blocs ci-dessous)
- Test: `MaillageThreadTests/NomsSceneTests.swift`, `MaillageThreadTests/FenetrePiecesTests.swift`, `MaillageThreadTests/FicheHeureTests.swift`, `MaillageThreadTests/CourbesFicheTests.swift`, `MaillageCoeurTests/PiecesAppareilsTests.swift`

**Interfaces:**
- Consumes :
  - `Surveillance.appareilsAffiches(pour:)`, `maillageAffiche(pour:)`, `oublierMaillage()`, `LibellesNoeuds.chefs(reseau:maillage:affiche:)`, `GrapheReseau.extMac(hote:)`, `PiecesRouteurs.cle(_:)`, existants.
- Produces :
  - `EntreeScene` : `graphe: GrapheReseau`, `maillage: MaillageAffiche?`, `chefs: Set<String>`, `appareils: [String: AppareilAffiche]`, construits avec la scène ; `==` compare la scène, les libellés, les apparences et le domicile ;
  - `FicheNoeud(id:entree:instant:aRenommer:choisir:fermer:)` : `entree: EntreeScene?`, la scène du même rendu ; la fiche y lit le maillage rapproché ;
  - `PiecesChoisies.placement(_ id: String, dans: Surveillance, entree: EntreeScene) -> Placement?` ; `PiecesChoisies.pieces(aPlacer:dans:)` et `choisir(_:routeur:domicile:)` retirées ;
  - `LibellesNoeuds.pieces(reseau:appareils:maison:nomsRouteurs:choix:graphe:)` : `graphe: GrapheReseau`, obligatoire ;
  - `Surveillance.cleHistorique(noeud:)` : l'hôte d'un appareil par `GrapheReseau.extMac(hote:)` ;
  - dans les tests : `FenetrePiecesTests.entree(_:)` (la scène de la fenêtre pour une surveillance, nil sans réseau), `NomsSceneTests.demoAvecRouteurThread()`.

**N° 14, une seule construction par rendu.** La fiche et son menu « Placer dans une pièce… » refaisaient rapprochement et graphe à chaque rendu, à part de la scène ; leur accord ne tenait qu'à deux tests, et le sous-projet B veut une couronne dans la fiche qui suive les chefs de la scène. `FenetrePieces` construit la scène une fois par rendu (`EntreeScene`), qui porte désormais ce dont elle est faite ; la légende, la fiche et le menu le lisent (précisions 5 et 6). Le rendu ne change pas : les images restent identiques.

**N° 15, API des seuls tests.** `PiecesChoisies.pieces(aPlacer:dans:)` et `choisir(_:routeur:domicile:)` n'étaient appelées que par les tests : elles sont retirées, et les tests passent par `placement(_:dans:entree:)` et `choisir(_:_:domicile:)` (précision 7). `LibellesNoeuds.pieces(…, graphe:)` ignorait en silence les choix d'appareils sans graphe : `graphe` devient obligatoire, et les tests qui ne le passaient pas prennent celui de la scène.

**N° 16, un seul prédicat.** « Un hôte de 16 hexadécimaux est une ExtMac » existait en deux copies : `GrapheReseau.extMac(hote:)`, avec `isASCII`, et `Surveillance.cleHistorique`, sans : `Character.isHexDigit` accepte aussi les chiffres et les lettres A à F en pleine chasse. `cleHistorique` appelle le premier.

**N° 27, en passant.** Les trous de tests de la tâche 16 du plan 4b, simples : un routeur Thread hors bordure, connu de la sonde seule, se place sous son ExtMac (côté app) ; un choix sous l'ExtMac d'un routeur de bordure ne le place pas (côté cœur) ; une maison sans pièces n'a de menu pour aucun nœud. Ces attentes ne dépendent pas du changement de la tâche : elles fixent un comportement déjà là.

- [ ] **Step 1 : écrire les tests.** Les tests passent par l'API de production ; le n° 27 ajoute ses attentes.

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
    /// Libelle d'un noeud : le nom coupe a 40 caracteres, la couronne du chef (celui de la partition
```

par :

```swift
    /// `demoAvecInconnus`, dont le maillage a en plus un routeur Thread qui n'est pas de bordure, connu de
    /// la sonde seule (« rloc:B400 », E0000000000000F1).
    static func demoAvecRouteurThread() throws -> (Surveillance, Reseau) {
        let (s, r) = try demoAvecInconnus()
        let m = try #require(s.maillage)
        var thread = RouteurMaillage(id: 45)
        thread.extMac = "E0000000000000F1"
        s.recevoir(Maillage(date: m.date, partition: m.partition, routeurs: m.routeurs + [thread], liens: m.liens,
                            enfants: m.enfants, signaux: m.signaux), a: s.maintenant)
        return (s, r)
    }

    /// Libelle d'un noeud : le nom coupe a 40 caracteres, la couronne du chef (celui de la partition
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
        let pieces = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: s.noms.maison)
```

par :

```swift
        let pieces = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: s.noms.maison,
                                           graphe: e.graphe)
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
        let (s, r, _) = try Self.demo()
        let maison = try #require(Self.maisonSansRouteurs(s))
```

par :

```swift
        let (s, r, depart) = try Self.demo()
        let maison = try #require(Self.maisonSansRouteurs(s))
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
                                           nomsRouteurs: noms)
```

par :

```swift
                                           nomsRouteurs: noms, graphe: depart.graphe)
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
                                       nomsRouteurs: noms, choix: choix)
        #expect(pieces["HomePod Palier"] == "Salon" && pieces["HomePod mini chambre"] == "Bureau")
        let avecMaison = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: s.noms.maison,
                                               nomsRouteurs: noms, choix: choix)
```

par :

```swift
                                       nomsRouteurs: noms, choix: choix, graphe: depart.graphe)
        #expect(pieces["HomePod Palier"] == "Salon" && pieces["HomePod mini chambre"] == "Bureau")
        let avecMaison = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: s.noms.maison,
                                               nomsRouteurs: noms, choix: choix, graphe: depart.graphe)
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
    /// Sur la maison de demo, avec les noms mesures par l'app : aucun lien ne passe sur une piece
```

par :

```swift
    /// La scene porte ce dont elle est faite, construit une fois avec elle : le graphe, le maillage de la
    /// sonde rapproche, les chefs (ceux des libelles couronnes) et les appareils affiches. Ils n'entrent
    /// pas dans l'egalite : un maillage recu plus tard, qui ne change rien a la scene, ne la fait pas
    /// reposer par le moteur.
    @Test func constructionDeLaScene() throws {
        let (s, r, e) = try Self.demo()
        let m = try #require(s.maillageAffiche(pour: r))
        #expect(e.maillage == m)
        #expect(e.graphe == GrapheReseau(reseau: r, appareils: s.appareilsAffiches(pour: r), maillage: m))
        #expect(e.chefs == ["Apple TV 4K"])
        #expect(Set(e.libelles.filter { $0.value.texte.contains("👑") }.keys) == e.chefs, "la couronne suit les chefs")
        #expect(e.appareils["56B1E064401F74EF"]?.piece == "Bureau")
        let maillage = try #require(s.maillage)
        s.recevoir(Maillage(date: maillage.date.addingTimeInterval(300), partition: maillage.partition,
                            routeurs: maillage.routeurs, liens: maillage.liens, enfants: maillage.enfants,
                            signaux: maillage.signaux), a: s.maintenant)
        let apres = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
        #expect(apres.maillage?.date != e.maillage?.date)
        #expect(apres == e, "la meme scene")
    }

    /// Sur la maison de demo, avec les noms mesures par l'app : aucun lien ne passe sur une piece
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// « Ancien » (6 min) et « perime » (15 min) ne dependent que de l'heure, que rien n'observe : la
```

par :

```swift
    /// La scene de la fenetre, comme la construit `FenetrePieces` a chaque rendu ; nil sans reseau.
    static func entree(_ s: Surveillance) -> EntreeScene? {
        s.reseau.map { EntreeScene(surveillance: s, reseau: $0, places: PlacesGardees()) }
    }

    /// « Ancien » (6 min) et « perime » (15 min) ne dependent que de l'heure, que rien n'observe : la
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        #expect(PiecesChoisies.pieces(aPlacer: "Apple TV 4K", dans: sansRouteurs) != nil, "avec « Placer dans une pièce… »")
        for (s, id) in [(demo, "Apple TV 4K"), (demo, "3A5DFAFCAB581AAF"), (demo, "rloc:041F"), (demo, "7AF0B6D5006CF95F"),
                        (sansRouteurs, "Apple TV 4K")] {
            let v = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                LigneNiveauVue(ligne: .lisibles)
                FicheNoeud(id: id, instant: Date(), aRenommer: .constant(nil)) {}
```

par :

```swift
        #expect(PiecesChoisies.placement("Apple TV 4K", dans: sansRouteurs, entree: try #require(Self.entree(sansRouteurs)))
                != nil, "avec « Placer dans une pièce… »")
        for (s, id) in [(demo, "Apple TV 4K"), (demo, "3A5DFAFCAB581AAF"), (demo, "rloc:041F"), (demo, "7AF0B6D5006CF95F"),
                        (sansRouteurs, "Apple TV 4K")] {
            let entree = Self.entree(s)
            let v = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                LigneNiveauVue(ligne: .lisibles)
                FicheNoeud(id: id, entree: entree, instant: Date(), aRenommer: .constant(nil)) {}
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        let courbes = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
            LigneNiveauVue(ligne: .lisibles)
            FicheNoeud(id: JournalMaillageTests.appareil, instant: Date(), aRenommer: .constant(nil)) {}
```

par :

```swift
        let entreeHistorique = Self.entree(historique)
        let courbes = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
            LigneNiveauVue(ligne: .lisibles)
            FicheNoeud(id: JournalMaillageTests.appareil, entree: entreeHistorique, instant: Date(),
                       aRenommer: .constant(nil)) {}
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        let (s, _, _) = try NomsSceneTests.demo()
        #expect(PiecesChoisies.pieces(aPlacer: "HomePod Palier", dans: s) == nil, "Maison le place au salon")
        s.noms.maison = NomsSceneTests.maisonSansRouteurs(s)
        let pieces = try #require(PiecesChoisies.pieces(aPlacer: "HomePod Palier", dans: s))
        #expect(pieces == ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain", "Salon"])
        #expect(PiecesChoisies.pieces(aPlacer: "56B1E064401F74EF", dans: s) == nil, "un appareil")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("routeurs-\(UUID().uuidString)/pieces-routeurs.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let choisies = PiecesChoisies(fichier: url)
        choisies.choisir("Salon", routeur: "HomePod Palier", domicile: "Maison (démo)")
        #expect(PiecesChoisies(fichier: url).choix.choix(routeur: "HomePod Palier", domicile: "Maison (démo)") == "Salon")
        let memoire = PiecesChoisies(fichier: nil)
        memoire.choisir("Salon", routeur: "HomePod Palier", domicile: "")
```

par :

```swift
        let (s, _, e) = try NomsSceneTests.demo()
        #expect(PiecesChoisies.placement("HomePod Palier", dans: s, entree: e) == nil, "Maison le place au salon")
        s.noms.maison = NomsSceneTests.maisonSansRouteurs(s)
        let entree = try #require(Self.entree(s))
        let pieces = try #require(PiecesChoisies.placement("HomePod Palier", dans: s, entree: entree)?.pieces)
        #expect(pieces == ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain", "Salon"])
        #expect(PiecesChoisies.placement("56B1E064401F74EF", dans: s, entree: entree) == nil, "un appareil")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("routeurs-\(UUID().uuidString)/pieces-routeurs.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let choisies = PiecesChoisies(fichier: url)
        choisies.choisir("Salon", .routeur("HomePod Palier"), domicile: "Maison (démo)")
        #expect(PiecesChoisies(fichier: url).choix.choix(routeur: "HomePod Palier", domicile: "Maison (démo)") == "Salon")
        let memoire = PiecesChoisies(fichier: nil)
        memoire.choisir("Salon", .routeur("HomePod Palier"), domicile: "")
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        let pieces = ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain",
                      "Salon"]
        let appareil = try #require(PiecesChoisies.placement("rloc:041F", dans: s))
        #expect(appareil == PiecesChoisies.Placement(cle: .appareil("E0000000000000FF"), pieces: pieces))
        #expect(PiecesChoisies.placement("1E5019DAC2638F92", dans: s)?.cle == .appareil("1E5019DAC2638F92"))
        #expect(PiecesChoisies.placement("rloc:0420", dans: s) == nil, "sans ExtMac")
        #expect(PiecesChoisies.placement("56B1E064401F74EF", dans: s) == nil, "Maison le place au bureau")
        let routeur = try #require(PiecesChoisies.placement("HomePod Palier", dans: s))
```

par :

```swift
        let e = try #require(Self.entree(s))
        let pieces = ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain",
                      "Salon"]
        let appareil = try #require(PiecesChoisies.placement("rloc:041F", dans: s, entree: e))
        #expect(appareil == PiecesChoisies.Placement(cle: .appareil("E0000000000000FF"), pieces: pieces))
        #expect(PiecesChoisies.placement("1E5019DAC2638F92", dans: s, entree: e)?.cle == .appareil("1E5019DAC2638F92"))
        #expect(PiecesChoisies.placement("rloc:0420", dans: s, entree: e) == nil, "sans ExtMac")
        #expect(PiecesChoisies.placement("56B1E064401F74EF", dans: s, entree: e) == nil, "Maison le place au bureau")
        let routeur = try #require(PiecesChoisies.placement("HomePod Palier", dans: s, entree: e))
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        choisies.choisir("Salon", routeur: "HomePod Palier", domicile: domicile)
```

par :

```swift
        choisies.choisir("Salon", .routeur("HomePod Palier"), domicile: domicile)
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// Un choix perime (sa piece n'est plus dans Maison) ne compte plus : la scene l'ignore, et la
```

par :

```swift
    /// Un routeur Thread qui n'est pas de bordure, connu de la sonde seule, se place sous son ExtMac
    /// (precision 27), « Sans piece » en tete du menu. Dans une maison sans pieces (ni d'accessoire, ni
    /// de zone), aucun noeud n'a de menu, appareil ou routeur.
    @Test func placerUnRouteurThread() throws {
        let (s, _) = try NomsSceneTests.demoAvecRouteurThread()
        let e = try #require(Self.entree(s))
        let noeud = try #require(e.graphe.noeud("rloc:B400"))
        #expect(noeud.inconnu && noeud.routeur && !noeud.bordure)
        let routeur = try #require(PiecesChoisies.placement("rloc:B400", dans: s, entree: e))
        #expect(routeur.cle == .appareil("E0000000000000F1"))
        #expect(MenuPlacer.articles(routeur).first == MenuPlacer.Article(texte: String(localized: "Sans pièce"), piece: nil))
        s.noms.maison?.zones = nil
        for k in s.noms.maison?.accessoires.indices ?? 0..<0 { s.noms.maison?.accessoires[k].piece = nil }
        let sansPieces = try #require(Self.entree(s))
        for id in ["rloc:B400", "rloc:041F", "1E5019DAC2638F92", "HomePod Palier"] {
            #expect(PiecesChoisies.placement(id, dans: s, entree: sansPieces) == nil, "\(id)")
        }
    }

    /// « Placer dans une piece… » lit le graphe de la scene du meme rendu (`EntreeScene`), et n'en
    /// reconstruit pas : apres l'oubli de la sonde, la scene deja construite garde « rloc:041F », que la
    /// sonde seule connait, et son menu ; la scene suivante ne l'a plus, ni le menu.
    @Test func menuDeLaScene() throws {
        let (s, _) = try NomsSceneTests.demoAvecInconnus()
        let e = try #require(Self.entree(s))
        s.oublierMaillage()
        #expect(PiecesChoisies.placement("rloc:041F", dans: s, entree: e)?.cle == .appareil("E0000000000000FF"))
        let suivante = try #require(Self.entree(s))
        #expect(suivante.maillage == nil && suivante.graphe.noeud("rloc:041F") == nil)
        #expect(PiecesChoisies.placement("rloc:041F", dans: s, entree: suivante) == nil)
    }

    /// Un choix perime (sa piece n'est plus dans Maison) ne compte plus : la scene l'ignore, et la
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        let domicile = "Maison (démo)"
        let choisies = PiecesChoisies(fichier: nil)
        for id in ["rloc:041F", "HomePod Palier"] {
            let placement = try #require(PiecesChoisies.placement(id, dans: s), "\(id)")
```

par :

```swift
        let e = try #require(Self.entree(s))
        let domicile = "Maison (démo)"
        let choisies = PiecesChoisies(fichier: nil)
        for id in ["rloc:041F", "HomePod Palier"] {
            let placement = try #require(PiecesChoisies.placement(id, dans: s, entree: e), "\(id)")
```

Dans `MaillageThreadTests/FicheHeureTests.swift`, remplacer :

```swift
            let fiche = FicheNoeud(id: Self.appareil, instant: instant, aRenommer: .constant(nil), fermer: {})
```

par :

```swift
            let fiche = FicheNoeud(id: Self.appareil, entree: nil, instant: instant, aRenommer: .constant(nil), fermer: {})
```

Dans `MaillageThreadTests/CourbesFicheTests.swift`, remplacer :

```swift
        let xa = try #require(br.adresseEtendue)
```

par :

```swift
        #expect(s.cleHistorique(noeud: "ＤＥＡＤＢＥＥＦ00000001") == nil, "hexadecimaux pleine chasse : pas une ExtMac")
        let xa = try #require(br.adresseEtendue)
```

Dans `MaillageCoeurTests/PiecesAppareilsTests.swift`, remplacer :

```swift
        #expect(p.choix(appareil: "DEADBEEF00000001", domicile: Self.domicile) == "Salon")
```

par :

```swift
        // Un choix sous l'ExtMac d'un routeur de bordure (le drapeau des Network Data peut changer d'une
        // tournee a l'autre) ne le place pas : il suit les precisions 23 a 25.
        p.choisir("Cuisine", appareil: "E0000000000000B2", domicile: Self.domicile)
        p.choisir("Cuisine", appareil: "E0000000000000A1", domicile: Self.domicile)
        #expect(p.choix(appareil: "DEADBEEF00000001", domicile: Self.domicile) == "Salon")
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/PiecesAppareilsTests MaillageThreadTests/NomsSceneTests MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/FicheHeureTests MaillageThreadTests/CourbesFicheTests`
Expected: la compilation des tests de l'app échoue, par exemple avec `error: extra argument 'entree' in call` et `error: 'nil' requires a contextual type` (`FicheHeureTests.swift`) : `** TEST FAILED **`.

- [ ] **Step 3 : écrire le code.** La scène et sa construction, puis ses lecteurs : les pièces, le menu, la fiche, la fenêtre, la clé de l'historique.

`MaillageThread/Vues/Pieces/EntreeScene.swift` (fichier entier) :

```swift
import MaillageCoeur
import SwiftUI

/// Ce que la vue par pieces montre d'un reseau, tire de la surveillance (spec de la vue par pieces,
/// section 2) : la scene, le libelle et l'apparence de chaque noeud, et la maison de ses places
/// gardees ; avec ce dont la scene est faite, construit une fois avec elle a chaque rendu (le graphe,
/// le maillage rapproche, les chefs, les appareils), que la fiche et « Placer dans une piece… » lisent
/// ici, sans rien reconstruire : ils voient les memes noeuds, les memes cles et les memes chefs que la
/// scene.
struct EntreeScene: Equatable {
    var scene: ScenePieces
    var libelles: [String: LibellesNoeuds.Libelle]
    var apparences: [String: DessinNoeud.Apparence]
    /// Domicile de Maison ("" sans nom) : la cle de ses places gardees.
    var domicile: String
    /// Noeuds et liens du reseau.
    var graphe: GrapheReseau
    /// Maillage de la sonde rapproche du reseau ; nil sans sonde, ou s'il est perime.
    var maillage: MaillageAffiche?
    /// Noeuds couronnes (le chef de chaque partition, celui du maillage de la sonde) : ceux des
    /// libelles ; la couronne suit ceux-ci partout ou elle parait.
    var chefs: Set<String>
    /// Appareils affiches, par id.
    var appareils: [String: AppareilAffiche]

    /// `places` : les places gardees, dont l'ordre des etages de la maison ; `choix` : les pieces
    /// choisies pour les noeuds que Maison ne place pas, routeurs de bordure (sous leur instance) et
    /// autres noeuds (sous leur ExtMac, precision 27).
    @MainActor
    init(surveillance: Surveillance, reseau r: Reseau, places: PlacesGardees, choix: PiecesRouteurs = PiecesRouteurs()) {
        let affiches = surveillance.appareilsAffiches(pour: r)
        let maillage = surveillance.maillageAffiche(pour: r)
        let graphe = GrapheReseau(reseau: r, appareils: affiches, maillage: maillage)
        let parId = Dictionary(affiches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let chefs = LibellesNoeuds.chefs(reseau: r, maillage: surveillance.maillage, affiche: maillage)
        let libelles = LibellesNoeuds.libelles(graphe: graphe, appareils: parId,
                                               nomsRouteurs: surveillance.nomsRouteurs(pour: r), maillage: maillage,
                                               chefs: chefs)
        let maison = surveillance.noms.maison
        let domicile = maison?.domicile ?? ""
        let pieces = LibellesNoeuds.pieces(reseau: r, appareils: affiches, maison: maison,
                                           nomsRouteurs: surveillance.nomsRouteurs(pour: r), choix: choix,
                                           graphe: graphe)
        let scene = ScenePieces(graphe: graphe, libelles: libelles.mapValues(\.texte), piecesNoeuds: pieces,
                                zones: maison?.zones, chefs: chefs,
                                piecesMaison: maison?.accessoires.contains { $0.piece?.isEmpty == false } == true,
                                ordreEtages: places.maison(domicile).ordreEtages)
        let principale = r.partitions.first(where: \.estPrincipale)?.id
        self.scene = scene
        self.libelles = libelles
        self.domicile = domicile
        self.graphe = graphe
        self.maillage = maillage
        self.chefs = chefs
        appareils = parId
        apparences = Dictionary(scene.noeuds.map { n in
            (n.id, DessinNoeud.apparence(n, etat: parId[n.id]?.etat, principale: n.partition == principale))
        }, uniquingKeysWith: { a, _ in a })
    }

    /// Egalite de ce que la vue dessine : la scene, les libelles, les apparences et le domicile. Ce dont
    /// la scene est faite n'y entre pas : un maillage recu plus tard, qui ne change rien a la scene, ne
    /// la fait pas reposer par le moteur (`MoteurPieces.recevoir`).
    static func == (a: EntreeScene, b: EntreeScene) -> Bool {
        a.scene == b.scene && a.libelles == b.libelles && a.apparences == b.apparences && a.domicile == b.domicile
    }

    /// Ce qui oblige a recalculer la disposition (spec, section 4.3) : les etages, leurs pieces, les
    /// noeuds de chacune et leurs noms. L'ordre des etages seul, ou l'etat d'un noeud, non.
    var cleDisposition: [String: [String: [String]]] {
        var c: [String: [String: [String]]] = [:]
        for e in scene.etages {
            for i in e.pieces {
                let p = scene.pieces[i]
                c[e.id, default: [:]][p.id] = p.noeuds.map { id in
                    [id, libelles[id]?.texte ?? "", libelles[id]?.pastille ?? ""].joined(separator: "|")
                }
            }
        }
        return c
    }
}
```

Dans `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, remplacer :

```swift
    /// nom (`nomsRouteurs`, par instance ; `PiecesRouteurs`). Avec le graphe, un autre noeud que Maison
    /// ne place pas prend la piece choisie pour son ExtMac (precision 27).
    static func pieces(reseau: Reseau, appareils: [AppareilAffiche], maison: NomsMaison?,
                       nomsRouteurs: [String: String] = [:], choix: PiecesRouteurs = PiecesRouteurs(),
                       graphe: GrapheReseau? = nil) -> [String: String] {
```

par :

```swift
    /// nom (`nomsRouteurs`, par instance ; `PiecesRouteurs`). Un autre noeud du graphe que Maison ne
    /// place pas prend la piece choisie pour son ExtMac (precision 27).
    static func pieces(reseau: Reseau, appareils: [AppareilAffiche], maison: NomsMaison?,
                       nomsRouteurs: [String: String] = [:], choix: PiecesRouteurs = PiecesRouteurs(),
                       graphe: GrapheReseau) -> [String: String] {
```

Dans `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, remplacer :

```swift
        if let graphe { pieces = choix.piecesNoeuds(graphe, deMaison: pieces, parmi: toutes, domicile: domicile) }
```

par :

```swift
        pieces = choix.piecesNoeuds(graphe, deMaison: pieces, parmi: toutes, domicile: domicile)
```

Dans `MaillageThread/Vues/Pieces/PiecesChoisies.swift`, remplacer :

```swift
    }

    /// Place un routeur (son instance) dans une piece de la maison ; nil : d'apres son nom.
    func choisir(_ piece: String?, routeur: String, domicile: String) {
        choisir(piece, .routeur(routeur), domicile: domicile)
    }
```

par :

```swift
    }
```

Dans `MaillageThread/Vues/Pieces/PiecesChoisies.swift`, remplacer :

```swift
    /// routeur de bordure que la sonde seule connait (precision 25), un noeud sans ExtMac.
    static func placement(_ id: String, dans surveillance: Surveillance) -> Placement? {
```

par :

```swift
    /// routeur de bordure que la sonde seule connait (precision 25), un noeud sans ExtMac. `entree` : la
    /// scene du meme rendu, dont le graphe et les appareils servent tels quels.
    static func placement(_ id: String, dans surveillance: Surveillance, entree: EntreeScene) -> Placement? {
```

Dans `MaillageThread/Vues/Pieces/PiecesChoisies.swift`, remplacer :

```swift
        // Un autre noeud : par le meme graphe que la scene (`EntreeScene`), donc sous la meme cle.
        guard let r = surveillance.reseau else { return nil }
        let affiches = surveillance.appareilsAffiches(pour: r)
        if let p = affiches.first(where: { $0.id == id })?.piece, !p.isEmpty { return nil }
        let graphe = GrapheReseau(reseau: r, appareils: affiches, maillage: surveillance.maillageAffiche(pour: r))
        guard let n = graphe.noeud(id), let cle = PiecesRouteurs.cle(n) else { return nil }
        return Placement(cle: .appareil(cle), pieces: pieces)
    }

    /// Pieces que propose « Placer dans une piece… » pour un noeud ; nil sans menu (`placement`).
    static func pieces(aPlacer id: String, dans surveillance: Surveillance) -> [String]? {
        placement(id, dans: surveillance)?.pieces
```

par :

```swift
        // Un autre noeud : par le graphe de la scene, donc sous la meme cle.
        if let p = entree.appareils[id]?.piece, !p.isEmpty { return nil }
        guard let n = entree.graphe.noeud(id), let cle = PiecesRouteurs.cle(n) else { return nil }
        return Placement(cle: .appareil(cle), pieces: pieces)
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
    /// Heure de la fenetre du graphe (sa `TimelineView`, chaque minute ; la fin de la panne en demo) :
```

par :

```swift
    /// La scene du meme rendu (`EntreeScene`), avec ce dont elle est faite : la fiche y lit le maillage
    /// rapproche, et « Placer dans une piece… » le graphe, sans rien reconstruire ; nil sans reseau.
    let entree: EntreeScene?
    /// Heure de la fenetre du graphe (sa `TimelineView`, chaque minute ; la fin de la panne en demo) :
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
                    if let piecesChoisies, let placement = PiecesChoisies.placement(id, dans: surveillance) {
```

par :

```swift
                    if let piecesChoisies, let entree,
                       let placement = PiecesChoisies.placement(id, dans: surveillance, entree: entree) {
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
    /// Maillage de la sonde pour le reseau affiche.
    private var sonde: MaillageAffiche? { surveillance.reseau.flatMap { surveillance.maillageAffiche(pour: $0) } }
```

par :

```swift
    /// Maillage de la sonde pour le reseau affiche : celui de la scene.
    private var sonde: MaillageAffiche? { entree?.maillage }
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        // fiche la recoit (`instant`) : sinon SwiftUI la sauterait, ses entrees n'ayant pas change.
```

par :

```swift
        // fiche la recoit (`instant`) : sinon SwiftUI la sauterait, ses entrees n'ayant pas change. La
        // scene est construite une fois par rendu : la legende, la fiche et son menu la lisent.
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                            if let r = surveillance.reseau {
                                LegendeLiens(sonde: surveillance.maillageAffiche(pour: r) != nil,
                                             ancien: surveillance.maillageAncien)
```

par :

```swift
                            if let entree {
                                LegendeLiens(sonde: entree.maillage != nil, ancien: surveillance.maillageAncien)
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                        FicheNoeud(id: selection, instant: surveillance.maintenant(a: contexte.date),
```

par :

```swift
                        FicheNoeud(id: selection, entree: entree, instant: surveillance.maintenant(a: contexte.date),
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    /// d'un routeur de bordure, ou l'hote d'un appareil (l'ExtMac d'un appareil Matter) ; nil si
    /// le noeud n'en a pas.
```

par :

```swift
    /// d'un routeur de bordure, ou l'hote d'un appareil (l'ExtMac d'un appareil Matter, d'apres
    /// `GrapheReseau.extMac(hote:)`, comme la piece d'un noeud) ; nil si le noeud n'en a pas.
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
        if id.count == 16, id.allSatisfy(\.isHexDigit) { return id.uppercased() }
        return nil
```

par :

```swift
        return GrapheReseau.extMac(hote: id)
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh MaillageCoeurTests/PiecesAppareilsTests MaillageThreadTests/NomsSceneTests MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/FicheHeureTests MaillageThreadTests/CourbesFicheTests`
Expected: `Test run with 7 tests in 1 suite passed` (cœur) et `Test run with 28 tests in 4 suites passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" TMPDIR="$HOME/Library/Caches/maillage-polA/" outils/tester.sh`
Expected: `Test run with 345 tests in 36 suites passed` (cœur) et `Test run with 269 tests in 28 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 3 tests de plus pour l'app. Les trois tests de la tâche s'ajoutent à l'app ; les attentes du n° 27 tiennent dans des tests existants.

- [ ] **Step 6 : la suite en anglais.**

```bash
xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-polA" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-polA/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-polA/maillage-tests-en.log"
```

Expected: `Test run with 345 tests in 36 suites passed` et `Test run with 269 tests in 28 suites passed`, `** TEST SUCCEEDED **` : les effectifs du Step 5.

- [ ] **Step 7 : les images de démo, identiques.** L'app, en mode démo seulement, écrit douze images de 1440 × 900 points en 2x dans son conteneur, sans fenêtre, puis quitte ; `open -W` attend qu'elle ait quitté. Chacune doit être identique, octet pour octet, à celle de la relecture finale du plan 4b : cette tâche ne change pas le rendu.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polA"
R="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-plan4b-finale"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polA/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polA/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
n=0; for f in "$D"/*.png; do cmp -s "$f" "$R/$(basename "$f")" && n=$((n+1)) || echo "différente : $(basename "$f")"; done; echo "$n identiques sur $(ls "$D" | wc -l | tr -d ' ')"
```

Expected : 12 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`) ; « l'app a quitté » ; « 12 identiques sur 12 ». Si une image diffère, s'arrêter : la tâche a changé le rendu.

- [ ] **Step 8 : commit.**

```bash
git add MaillageThreadTests/NomsSceneTests.swift MaillageThreadTests/FenetrePiecesTests.swift MaillageThreadTests/FicheHeureTests.swift MaillageThreadTests/CourbesFicheTests.swift MaillageCoeurTests/PiecesAppareilsTests.swift MaillageThread/Vues/Pieces/EntreeScene.swift MaillageThread/Vues/Pieces/LibellesNoeuds.swift MaillageThread/Vues/Pieces/PiecesChoisies.swift MaillageThread/Vues/Pieces/FicheNoeud.swift MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Surveillance/Surveillance.swift
git commit -m "Construire une fois par rendu le graphe et le rapprochement de la scene, que lisent la fiche et son menu, et garder un seul predicat de l'ExtMac d'un hote

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Vérification avec Djoko (par le contrôleur, pas par un sous-agent)

**Files:** aucun.

**Interfaces:**
- Consumes : tout le plan ; l'app compilée dans le `DD` du plan.
- Produces : la vérification de A avec Djoko, en comptes seulement.

Les points de A sont surtout invisibles : quelques gestes rapides suffisent. Chaque action sur l'app de Djoko attend son accord.

- [ ] **Step 1 : vérification avec Djoko.** Recompiler (`outils/tester.sh`, avec le `DD` et le `TMPDIR` du plan), puis, avec lui, quitter l'app qui tourne et lancer celle du `DD` en mode direct : `open "$HOME/Library/Developer/Xcode/DerivedData/maillage-polA/Build/Products/Debug/Maillage Thread.app"`.
  1. **La vue.** Elle s'ouvre comme avant : mêmes étages, mêmes pièces, mêmes places ; aucune pièce n'a bougé.
  2. **Une fiche** (n° 14). Clic sur un appareil, puis sur un routeur, puis sur un nœud que la sonde seule connaît s'il y en a un : chaque fiche montre ce qu'elle montrait (nom, état, ligne de la sonde : parent et qualité, ou voisins et enfants ; journal ; courbes).
  3. **« Placer dans une pièce… »** (n° 14, 15). Sur la fiche d'un nœud que Maison ne place pas (un HomePod resté dans « Sans pièce », par exemple) : le menu montre son premier article, puis les pièces de la maison ; le choix en cours est coché. En choisir une : le nœud y passe ; revenir au choix d'avant.
  4. **Un relevé** (n° 2, 18). Attendre une tournée de la sonde (5 minutes), ou « Rafraîchir depuis Maison » : la vue et la fiche ouverte suivent ; aucun nœud « Non identifié » en double n'apparaît. Les courbes de la fiche d'un appareil gardent leurs relevés après la tournée.
  5. **Les fichiers gardés** (n° 3). Djoko regarde le dossier de l'app (`~/Library/Containers/fr.djoko.maillage/Data/Library/Application Support/Maillage Thread/`), ou autorise le contrôleur à en lister les noms : aucun fichier `*.illisible-*.json` n'y est apparu, puisque les siens sont lisibles et de version connue. On ne lit aucun de ces fichiers.
  6. **Retour.** Des comptes seulement, jamais un nom : fiches ouvertes, choix faits puis défaits, fichiers mis de côté (0 attendu).
- [ ] **Step 2 : rendre l'app.** Quitter l'app du `DD` et relancer l'app habituelle de Djoko, s'il le souhaite. Rien n'est commité : la vérification se rapporte à Djoko.

---

## Couverture des exigences

| Exigence (tri du 01/10, lots 1 à 4) | Tâche | Preuve |
|---|---|---|
| `tester.sh` échoue, avec un message clair, si une cible ou un filtre ne lance aucun test ; sans cible, rien ne change | 1 | une cible au nom faux échoue (code 1), une vraie passe ; un test sans parenthèses échoue ; la suite entière, sans cible, inchangée |
| Spec, section 10 : l'exception des pièces fixées dégagées | 1 | bloc de la spec |
| `DispositionPieces` sûre face à un coût NaN ou infini ; repli sur le départ ; résultat ordinaire identique au bit près | 2 | `coutNonFini`, `placeFixeeDemesuree` ; images identiques ; empreinte de seize dispositions (code validé) |
| Entrée du balayage d'un enfant devenu routeur écartée : nœuds (rapprochement) et historique (`enfantsIdentifies`) | 2 | `GrapheReseauTests.enfantDevenuRouteur`, `HistoriqueTests.enfantDevenuRouteur` |
| L'historique n'écrit aucun identifiant hors de 0…62 ; le reste de la ligne se relit | 2 | `routeurHorsPlageNonEcrit` |
| N° 4 en passant | 2 | `extMacsRouteurs` |
| Fichiers gardés : plus récent jamais réécrit ; illisible mis de côté puis remplacé ; cas ordinaire inchangé ; trois choix de routeurs qui survivent ; une seule implémentation | 3 | `plusRecentJamaisReecrit`, `illisibleMisDeCote`, `casOrdinaire`, `troisChoixDesRouteurs` ; `FichiersGardes` |
| Une seule construction par rendu ; la fiche et le menu la lisent ; rendu identique | 4 | `constructionDeLaScene`, `menuDeLaScene` ; images identiques |
| Couronne de la fiche : les mêmes chefs que la scène | 4 | `constructionDeLaScene` (précision 6) |
| `LibellesNoeuds.pieces(…, graphe:)` obligatoire | 4 | `NomsSceneTests` adaptés |
| API des seuls tests retirée, tests par l'API de production | 4 | `placerUnRouteur`, `placerUnAppareil`, `choixPerimeNonCoche` |
| Un seul prédicat de l'ExtMac d'un hôte, avec `isASCII` | 4 | `CourbesFicheTests.clesEtNoms` (pleine chasse) |
| N° 27 en passant | 4 | `placerUnRouteurThread`, `PiecesAppareilsTests.choixParExtMac` |
| Vérification avec Djoko | 5 | gestes rapides, en comptes |
