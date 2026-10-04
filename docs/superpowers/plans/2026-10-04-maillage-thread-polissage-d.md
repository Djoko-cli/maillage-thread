# Maillage Thread, polissage D : les gestes et les animations : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** livrer le sous-projet D du polissage, qui le clôt, tel que Djoko l'a validé le 04/10 avec ses trois ajouts du même jour et ses décisions du 05/10 : chaque nouvelle disposition glisse en 0,9 s au lieu de sauter, un appareil en ligne droite jusqu'à sa nouvelle pièce ; un badge qui change ne fait plus bouger l'étage ; la molette revient à la fiche et à la légende, et Échap suit son chemin quand il n'a rien à faire ; les restes de C ; l'isolement et la politique de la grille sortent du moteur ; un routeur dont tous les candidats sont dans la même pièce y va ; la rotation lente continue pendant un isolement ; le signal vu par la sonde a toujours une échelle, et sa valeur se lit au survol ; le moteur est réparti en fichiers.

**Architecture :**
- **Le cœur** (`MaillageCoeur/`) :
  - `Scene/Isolement.swift` (nouveau) : l'enum `Isolement`, sorti du moteur, et ses règles (provenance, remontée, recalage, clic sur un étage, rotation lente) ;
  - `Scene/PolitiqueGrille.swift` (nouveau) : le réglage de la grille, ses colonnes, la demande qui attend la vue d'ensemble 2D, l'hystérésis, les durées ;
  - `Scene/TransitionScene.swift` (nouveau) : `PosesScene` (les poses par clé, ancrées sur les plateaux) et `TransitionScene` (le glissement, les fondus, l'interruption) ; `SceneProjetee` prend les poses de ce qui change, et dessine ce qui s'efface ;
  - `Scene/CartesPieces.swift`, `ScenePieces.swift` : les badges d'un nom et la place réservée ; la scène voit les noms nus ; la clé de la disposition, sans badges ; le chef dans son groupe ;
  - `Scene/PiecesRouteurs.swift` : la pièce d'un routeur aux candidats ;
  - `Scene/Niveaux.swift`, `PlacesGardees.swift` : l'ordre fondu dans l'ordre gardé ;
  - `Maillage/EchelleSignal.swift` (nouveau) : l'échelle du signal, le relevé sous le pointeur, son étiquette.
- **L'app** (`MaillageThread/Vues/Pieces/`) :
  - `MoteurPieces` : il appelle `Isolement` et `PolitiqueGrille` ; la transition, son horloge, la vue qui suit ; la grille rechoisie quand les rayons changent ; la molette, Échap, le chemin des événements ; la rotation lente pendant un isolement ; le menu à la fin de l'envol ;
  - `LibellesNoeuds`, `EntreeScene`, `MesureNoms` : le nom nu de chaque nœud, la réserve des badges mesurée avec la vraie police, la pièce d'un routeur aux candidats ;
  - `FenetrePieces` : le point de la vue pour la molette (`VuePieces.point`, `SondeFenetre`) ;
  - `CourbesFiche` : l'échelle et le survol du signal ;
  - `MoteurPieces+Scene`, `+Camera`, `+Image`, `+Gestes`, `+Poses` (nouveaux) : le moteur réparti en extensions, par responsabilité ;
  - `CapturesPieces` : vingt et une images.

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI (`Canvas`, `TimelineView`, Swift Charts : `chartOverlay`, `ChartProxy`, `AnnotationOverflowResolution`), AppKit (`NSEvent`, moniteur local), Swift Testing, XcodeGen, `xcodebuild`.

**Spec :** `docs/superpowers/specs/2026-10-04-maillage-thread-polissage-d-design.md` (validée par Djoko le 04/10, avec ses ajouts 4.1, 4.2 et 4.3 du même jour, commits `59404e1` et `7323950`, et ses décisions du 05/10 sur la première version de ce plan, commit `6550530`). D n'a pas de maquette : les images de démo et la vérification en vrai avec Djoko en tiennent lieu.

**Quand l'exécuter.** Après la spec de D : ce plan est écrit et validé sur `main` en `6550530`. **Les numéros de ligne cités sont indicatifs : l'exécutant se repère aux noms (types, fonctions, commentaires) et aux textes cités.** Si un texte à remplacer n'est plus exactement le même, il applique le même changement au texte du moment et le dit dans son rapport.

## Code validé, faits établis et précisions

**Code validé avant exécution.** Les 04 et 05/10, tout le code de ce plan a été écrit, compilé et testé dans une copie de `main` (`7323950`, puis avancée à `6550530`, qui ne change que la spec) :
- toute la suite passe, en français et en anglais : 396 tests en 41 suites pour le cœur et 364 en 32 pour l'app (avant ce plan : 369 tests en 37 suites, et 347 en 30), sans avertissement ;
- les temps de la vue par pièces, en Release, et les tests Python de la sonde : ce plan ne les change pas (tâche 8) ;
- chaque tâche a eu ses mutants : des changements plausibles du code, appliqués un à un, que ses tests doivent faire échouer. Ils sont listés à la fin de chaque tâche : 104 essayés ; 101 tués par les tests, 2 arrêtés par la compilation (tâche 7), 1 survivant. Deux survivaient à la première écriture de la tâche 1, un à celle de la tâche 4 : les attentes qui les tuent sont dans le plan. Le seul survivant, à la tâche 8, touche la boucle des captures, que l'image 21 montre ;
- les images de démo ont été rendues et regardées, à côté de celles de la fin de C (`captures-polC-finale`) : les tâches 1, 2, 3, 5, 6 et 7 n'en changent aucune, octet pour octet ; la tâche 4 les change toutes (la réserve des badges) ; la tâche 8 en ajoute une, un appareil à mi-chemin de son glissement.

Le plan a ensuite été rejoué tâche par tâche sur une copie neuve de `main` (`6550530`), ses blocs appliqués par l'outil du contrôleur (`appliquer-blocs.py`, sur le brief de chaque tâche, découpé par `task-brief`) : le rouge, le vert, la suite entière, les images, un commit par tâche. Les résultats attendus ci-dessous viennent de ce rejeu. L'arbre final est identique à la copie validée, au plan près ; les images aussi. D'autres changements de `main` changeraient ces totaux : chaque tâche donne donc ses effectifs.

Exécuter une tâche, c'est transcrire les fichiers et les blocs donnés, compiler et tester. Si un fichier doit s'écarter du texte donné, l'exécutant le dit dans son rapport, avec la raison.

**Blocs de modification.** Un fichier existant est modifié par blocs « remplacer … par … ». Chaque texte à remplacer apparaît une seule fois dans le fichier au moment où on l'applique. Les blocs s'appliquent dans l'ordre, du haut vers le bas, au texte exact, espaces compris. Un fichier créé l'est tel quel. Aucun texte nouveau n'entre au catalogue : ce plan ne touche ni `Localizable.xcstrings` ni `outils/traductions/interface.json` (les textes nouveaux sont des noms, des nombres et des heures, `Text(verbatim:)`). Ce plan ne déplace ni ne supprime aucun fichier ; il en crée quinze : `Isolement.swift`, `PolitiqueGrille.swift`, `TransitionScene.swift`, `EchelleSignal.swift`, et `IsolementCoeurTests.swift`, `PolitiqueGrilleTests.swift`, `TransitionSceneTests.swift`, `EchelleSignalTests.swift` dans le cœur, `GlissementTests.swift` et `MoletteEtEchapTests.swift` dans l'app, et les cinq extensions du moteur, `MoteurPieces+Scene.swift`, `+Camera.swift`, `+Image.swift`, `+Gestes.swift` et `+Poses.swift`.

**Faits établis** (Xcode 27, macOS 27, copie validée et rejeu, 04 et 05/10) :
- **`#expect` n'accepte pas d'appel `mutating`** dans son expression : un test garde d'abord le résultat (`let pose = p.premiereZone(…)`), puis l'attend.
- **Un événement de molette fabriqué** (`CGEvent(scrollWheelEvent2Source:…)`, puis `NSEvent(cgEvent:)`) n'a pas de fenêtre, même avec le numéro de la fenêtre dans ses champs ; un `keyDown` fabriqué par `NSEvent.keyEvent(…, windowNumber:)` a la sienne. Le moniteur se teste donc en deux morceaux : la lecture de l'événement (`EvenementVue`), puis la décision (`prendre`).
- **La sonde de la vue** (`SondeFenetre`, au fond de `VuePieces`) a la taille de la vue, et la vue celle de l'espace `VuePieces.espace` : le point de la molette dans la vue est celui de la fenêtre, converti par la sonde, l'axe vertical retourné.
- **`ImageRenderer`** ne rend ni l'horloge, ni le survol, ni un menu : le glissement animé, la molette au-dessus de la fiche et l'étiquette du signal ne se voient qu'en vrai (tâche 8).
- **Les formats d'heure de macOS 27**, pour l'étiquette du signal, le 21/09/2026 à 14 h 13 UTC, à Paris : « 16:13 » en français, « 4:13 PM » en anglais (une espace fine insécable avant PM) ; avec le jour, « 21 sept. à 16:13 » et « Sep 21 at 4:13 PM ».
- **La disposition est globale** : un appareil qui change de pièce relance le calcul de toute la maison, et des pièces d'autres étages peuvent bouger (dans la démo, l'ampoule de l'entrée placée dans la cuisine déplace la buanderie et la cuisine de plus de 27 unités, la chambre et la salle de bain de plus de 10). C'est ce que la transition fait glisser.
- **Les cartes de la démo s'élargissent** avec la réserve des badges : dans `07-2d-zoom-salon`, celle du salon passe d'environ 560 à 665 points d'image (le volet du salon a une pile connue).
- **Une image se rend avec l'app que la dernière compilation a laissée** dans le `DD` : après un essai de mutants, qui recompile avec un mutant, la suite doit repasser avant les images (sinon elles montrent le mutant ; relevé sur la copie).
- **Le temps réel dans les tests** : `reculerTransition(de:)` avance l'horloge de la transition et des plateaux, sans attendre ; les seules attentes réelles sont des bornes basses (20 ms entre deux images, pour voir la rotation lente tourner), ou des attentes d'une fin (`MoteurPiecesTests.attendre`, 5 s au plus).

**Précisions.** Ce sont les choix faits à l'écriture du plan, là où la spec et le brief laissaient la main. Djoko les a revues le 05/10 (spec, commit `6550530`) ; il peut encore les revoir à la tâche 9.
1. **L'isolement, dans le cœur** (tâche 1) : l'enum `Isolement` quitte `MoteurPieces.swift` avec ses règles, en fonctions pures qui rendent un état ou une action (`Remontee`, `ClicEtage`) que le moteur exécute. Les états d'animation (`s`, `se`, `fk`, `ek`, `focus`, `etageEnVue`) restent dans le moteur : ils suivent l'horloge. La règle du clic sur un étage n'a plus qu'un endroit (`clicEtage`), lu par le clic, par `disqueCliquable` et par la main du survol.
2. **La politique de la grille, dans le cœur** (tâche 1) : `PolitiqueGrille`, une valeur que le moteur garde ; ses trois demandes portent leurs durées (2,6 s pour le réglage, 0,4 s au redimensionnement et après un changement de niveau ; les 0,9 s de la 3D restent au moteur, avec les glissements). Le moteur garde `grille`, `colonnes` et `grilleEnAttente` en lecture : les tests de C n'ont pas à changer.
3. **Les poses, ancrées sur les plateaux** (tâche 2) : une place est une ancre (la clé d'un plateau, une place sur lui, un poids) ; la géométrie du moment la pose dans le monde. Une pose en route d'un plateau à un autre est une moyenne pondérée d'ancres, fusionnées par plateau : la ligne droite et l'interruption sont exactes, et une pose n'a jamais plus d'ancres que de plateaux. Le glissement suit la cubique entrée-sortie de C ; les fondus sont linéaires, comme le fondu de l'envol.
4. **Ce qui glisse** (tâche 3) : chaque scène posée dont la disposition change (positions, tailles, pièces, nœuds, liens). Une scène de même disposition laisse la transition aller à son terme. Les plateaux glissent en 0,9 s en 2D comme en 3D ; après un changement de niveau, comme en C (0,4 s en 2D). Un plateau nouveau part de sa place d'arrivée, comme en C : il n'a pas de fondu.
5. **Ce qui s'efface** (tâche 2) : un bloc, une pastille et un lien, à leur dernière place ; ils ne se cliquent pas et n'ont pas de nom. Une pastille qui s'efface garde le dessin de la scène d'avant (`apparencesParties`).
6. **Une pièce glissée par Djoko** (tâche 3) : glisser ne relance pas le calcul, comme avant (décision de Djoko du 05/10). Une pièce en route que Djoko prend est posée à sa place, avec ses nœuds, et suit le pointeur depuis là. La disposition suivante la trouve fixée, déjà à sa place : elle n'est pas animée.
7. **La réserve des badges** (tâche 4) : un nœud qui route réserve la couronne et ⚠︎ ; un autre, ☾ et ⚠︎ ; un nœud dont la pile est connue (Maison), la plus large des pastilles d'une pile faible (de 0 à 100 %, ou « faible ») : décision de Djoko du 05/10. La clé de la disposition compte, pour chaque nœud, s'il route et si sa pile est connue. Le cœur compose les textes ; l'app les mesure avec la vraie police (`MesureNoms`), comme les noms. La clé de la disposition passe dans le cœur, avec, pour chaque nœud, s'il route.
8. **Le chef garde sa place dans sa carte** (tâche 4 ; décision de Djoko du 05/10, écart voulu à la spec de la vue par pièces, section 2.2) : sinon un changement de chef réordonnerait sa carte, ses liens et le coût, et pourrait déplacer l'étage. Dans la démo, l'Apple TV 4K reste en tête du salon, par son nom.
9. **La molette** (tâche 5) : les éléments posés sur la vue sont ceux qui comptent déjà pour les noms (`cadresInterface`) : la fiche, la légende, la ligne des capsules, bande de la fenêtre comprise, la colonne du haut et la ligne de niveau. Pendant un vol, la molette reste prise et ignorée, comme avant.
10. **Échap** (tâche 5) : pendant l'envol, comme à la vue d'ensemble sans zoom ni fiche, il n'est pas pris.
11. **Les restes de C** (tâches 3 et 5) : un absent reste juste après celui qui le précédait dans l'ordre gardé (en tête s'il l'était) ; quand seuls les rayons changent, la grille se rechoisit avec l'hystérésis, et attend, hors de la vue d'ensemble, comme un redimensionnement ; le menu revient par le survol, repris à la fin de l'envol ou du fondu.
12. **La rotation lente pendant un isolement** (tâche 5) : un geste qui l'arrête est un glisser (⌥ compris), le zoom de la molette en route (jusqu'à la fin de son amorti), ou un pincement commencé.
13. **Le routeur aux candidats** (tâche 4) : la règle s'applique, dans l'app, à un nœud de bordure resté sans pièce après les autres règles ; dans la démo, les HomePod d'une paire laissés sans ExtMac vont au salon.
14. **L'étiquette du signal** (tâche 6) : au format d'heure de la langue de l'app, donc « 16:13 » en français, et non « 14 h 32 » comme dans l'exemple de la spec ; la valeur arrondie au dBm, avec le vrai signe moins (U+2212). Le survol passe par `chartOverlay` : `chartXSelection` ne suit pas le simple survol sur le Mac.
15. **L'image du glissement** (tâche 8) : un vrai « Placer dans une pièce… » de la démo, sur l'appareil inconnu « 041F » sans pièce, vers la cuisine, en 2D, posé à mi-chemin par `poserTransition(0.5)`, la vue zoomée vers « Sans pièce ».
16. **Deux aides de test dans le moteur** (tâche 3) : `poserTransition(_:)`, qui sert aussi aux captures, et `reculerTransition(de:)`, qui avance l'horloge de la transition sans attendre.
17. **Le moteur en fichiers** (tâche 7 ; décision de Djoko du 05/10) : six fichiers, de 114 à 402 lignes, par responsabilité ; le code déplacé tel quel, section par section. Une extension ne voit pas un membre privé d'un autre fichier : les membres `private` ou `private(set)` qu'un autre fichier du moteur lit ou écrit perdent ce mot (109 des 138) ; les autres le gardent. Les fichiers nouveaux entrent dans la cible par XcodeGen (`project.yml` prend tout le dossier `MaillageThread` ; le projet généré n'est pas commité).

## Global Constraints

- **Plateformes :** app en macOS 26.0 minimum, développée avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`.
- **Code :** identifiants et commentaires en français **sans accents** ; textes affichés avec accents ; tests en Swift Testing. Les nouveaux fichiers sont pris par les sources de `project.yml` sans le modifier : ce plan ne touche pas `project.yml`.
- **Le comportement de C ne change pas,** hors de ce que la spec de D change : les tests d'avant restent verts sans être affaiblis ; quatre s'adaptent, et le plan dit pourquoi (`lignesEtRayons`, `libelles`, `nouvelleDisposition` à la tâche 4, `etageIsole` à la tâche 5).
- **Déterminisme :** aucun hasard ; les images de démo ne dépendent ni de l'heure ni des préférences.
- **Textes de l'app :** tout texte nouveau irait au catalogue, avec son anglais, par les outils (`outils/synchroniser-textes.sh`, puis `outils/traduire.py`) ; ce plan n'en ajoute aucun. `CataloguesTests` refuse une clé sans anglais, absente ou inutilisée.
- **Tests indépendants de la langue :** une attente sur un texte affiché reprend la même clé que le code (`String(localized: "Sans pièce")`), jamais une chaîne française figée ; un format d'heure se teste avec une langue et un fuseau donnés. Les tests passent en anglais :

  ```bash
  xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-polD/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-polD/maillage-tests-en.log"
  ```
- **Commandes,** depuis la racine du dépôt, toujours avec un dossier de produits (`DD`) et un dossier temporaire (`TMPDIR`) propres à ce plan. Le shell d'un agent ne garde pas ses variables d'une commande à l'autre : chaque commande les porte. Une fois, avant la tâche 1 :

  ```bash
  mkdir -p "$HOME/Library/Caches/maillage-polD"
  ```

  `outils/tester.sh [cibles…]` génère le projet, compile et lance les tests, en Debug ; les produits vont dans `DD`, le journal complet dans `$TMPDIR/maillage-tests.log` ; une cible qui ne lance aucun test fait échouer le script. `outils/mesurer.sh` lance les trois tests de temps en Release, dans le même `DD`. La première compilation dans ce `DD` neuf prend quelques minutes. **Jamais un autre `DD` que `maillage-polD` :** l'app de Djoko tourne depuis un autre.
- **Une suite de tests de l'app à la fois** sur ce Mac : si un test sans rapport échoue avec `Test crashed with signal term`, vérifier qu'aucune autre session ne teste l'app (`pgrep -fl xcodebuild`), puis relancer la suite.
- **L'app :** de la tâche 1 à la tâche 8, un agent ne la lance qu'en mode démo, pour ses images, en instance à part : `open -n -g -W "$DD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures <dossier du conteneur>`. Elle écrit ses images sans fenêtre et quitte d'elle-même ; l'agent vérifie qu'elle ne tourne plus. Pour l'arrêter, `kill` sur son PID seulement, jamais `osascript … quit` : l'app de Djoko porte le même identifiant. Jamais en mode direct, jamais de `screencapture`, et l'app de Djoko n'est jamais quittée. La tâche 9 se fait avec Djoko, par le contrôleur.
- **Les préférences de l'app** sont celles de l'app de Djoko (même identifiant) : un test n'écrit jamais dans `UserDefaults.standard` (il prend un domaine à lui, `SondeMaillageTests.preferences()`), et ne suppose pas le mode 2D ou 3D gardé.
- **Données personnelles** (le dépôt est public sur GitHub) : `noms.json` n'est jamais commité, ni lu par un test ; aucun agent ne lit le conteneur de l'app hors des dossiers d'images de ce plan ; les tests utilisent des données inventées ou celles de la démo, aucun nom réel de pièce ou de zone de la maison de Djoko (« Grange », dans `unEtageAbsentGardeSonRang`, est inventé).
- **Signature :** l'app reste ad hoc (`Signature.xcconfig`). **Ne jamais créer `Local.xcconfig`.**
- **Commits :** un par tâche, message en français sans accents, terminé par une ligne vide puis la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ; `git add` avec la liste de fichiers de la tâche, **jamais `git add -A` ni `git add .`** ; jamais de push.
- **Interdits pour les agents :** `sudo` ; ouvrir un port série ou flasher ; lancer l'app en mode direct ; `screencapture` ; lancer le passeur ou `outils/passeur.sh` ; un navigateur ; réveiller l'écran ; quitter l'app de Djoko.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `MaillageCoeur/Scene/Isolement.swift` (nouveau) | l'isolement et ses règles ; la rotation lente | 1, 5 |
| `MaillageCoeur/Scene/PolitiqueGrille.swift` (nouveau) | la politique de la grille | 1 |
| `MaillageCoeur/Scene/TransitionScene.swift` (nouveau) | `PosesScene`, `TransitionScene` | 2 |
| `MaillageCoeur/Scene/SceneProjetee.swift` | les poses de ce qui change ; ce qui s'efface | 2 |
| `MaillageCoeur/Scene/CartesPieces.swift` | les badges d'un nom, le texte réservé | 4 |
| `MaillageCoeur/Scene/ScenePieces.swift` | les noms nus, le chef dans son groupe, la clé de la disposition | 4 |
| `MaillageCoeur/Scene/PiecesRouteurs.swift` | la pièce d'un routeur aux candidats | 4 |
| `MaillageCoeur/Scene/Niveaux.swift`, `PlacesGardees.swift` | l'ordre fondu dans l'ordre gardé | 5 |
| `MaillageCoeur/Maillage/EchelleSignal.swift` (nouveau) | l'échelle du signal, le survol, l'étiquette | 6 |
| `MaillageThread/Vues/Pieces/MoteurPieces.swift` | l'appel des types du cœur ; la transition ; la grille et les rayons ; la molette, Échap, la rotation, le menu après l'envol ; les cartes réservées | 1, 3, 4, 5, 7 |
| `MaillageThread/Vues/Pieces/MoteurPieces+Scene.swift`, `+Camera.swift`, `+Image.swift`, `+Gestes.swift`, `+Poses.swift` (nouveaux) | le moteur réparti en extensions | 7 |
| `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, `EntreeScene.swift`, `MesureNoms.swift` | le nom nu, la clé, la réserve mesurée, les candidats | 4 |
| `MaillageThread/Vues/Pieces/FenetrePieces.swift` | le point de la vue, la sonde de la vue | 5 |
| `MaillageThread/Vues/Pieces/CourbesFiche.swift` | l'échelle et le survol du signal | 6 |
| `MaillageThread/Vues/Pieces/CapturesPieces.swift` | la vingt et unième image | 8 |
| `MaillageCoeurTests/IsolementCoeurTests.swift`, `PolitiqueGrilleTests.swift` (nouveaux) | les règles sorties du moteur | 1, 5 |
| `MaillageCoeurTests/TransitionSceneTests.swift` (nouveau) | la transition et la projection | 2 |
| `MaillageCoeurTests/CartesPiecesTests.swift`, `ScenePiecesTests.swift`, `PiecesRouteursTests.swift` | les badges, la clé, les candidats | 4 |
| `MaillageCoeurTests/NiveauxTests.swift` | l'ordre fondu | 5 |
| `MaillageCoeurTests/EchelleSignalTests.swift` (nouveau) | l'échelle, le survol, l'étiquette | 6 |
| `MaillageThreadTests/GlissementTests.swift` (nouveau) | le glissement dans le moteur, la grille et les rayons | 3 |
| `MaillageThreadTests/MoletteEtEchapTests.swift` (nouveau) | la molette, Échap, le menu après l'envol, l'étage absent | 5 |
| `MaillageThreadTests/IsolementTests.swift`, `MoteurPiecesTests.swift`, `NomsSceneTests.swift`, `CourbesFicheTests.swift`, `FenetrePiecesTests.swift` | les attentes du câblage ; les badges ; la rotation ; l'échelle de la fiche ; les images | 1, 4, 5, 6, 8 |
| `README.md`, `README.fr.md` | les glissements, les badges, la molette, Échap, la rotation, le signal, les vingt et une images | 8 |

---

### Task 1: L'allègement du moteur : l'isolement et la politique de la grille, des types purs du cœur, à comportement constant

**Files:**
- Create: `MaillageCoeur/Scene/Isolement.swift`, `MaillageCoeur/Scene/PolitiqueGrille.swift`, `MaillageCoeurTests/IsolementCoeurTests.swift`, `MaillageCoeurTests/PolitiqueGrilleTests.swift`
- Modify: `MaillageThread/Vues/Pieces/MoteurPieces.swift` (blocs ci-dessous)
- Test: `MaillageThreadTests/IsolementTests.swift`, `MaillageThreadTests/MoteurPiecesTests.swift`

**Interfaces:**
- Consumes :
  - `MoteurPieces` (`isolement`, `isoler`, `allerEtage`, `remonter`, `cliquerEtage`, `disqueCliquable`, `installer`, `reglerGrille`, `zoneChangee`, `demanderGrille`, `attendreGrille`, `poserGrille`, `basculer`, `poserTaille`, `controles`, `doitContinuer`), `GeometrieMaison.colonnes(rayons:taille:enPlace:)`, `CameraScene.dureeEnvol`, `dureeCases`, existants ;
  - dans les tests : `IsolementTests.jardinDehors`, `nomDEtage`, `pointDeDisque`, `MoteurPiecesTests.redimensionnement`, existants.
- Produces :
  - `Isolement` (cœur ; `.maison`, `.etage(String)`, `.piece(String, provenance:)`), `Isolement.Remontee`, `Isolement.ClicEtage` ; `isoler(piece:etage:)`, `remonter(etageDeLaPiece:plusieursPlateaux:clavier:)`, `clicEtage(_:disque:plusieursPlateaux:pieceIsolee:)`, `cliquable(_:disque:plusieursPlateaux:pieceIsolee:)`, `recaler(pieces:etages:)`, `Isolement.rotationLente(troisD:bascule:cochee:reduire:sansIsolement:)` ;
  - `PolitiqueGrille` (cœur) : `Demande(duree:hysteresis:)`, `reglage`, `redimensionnement`, `niveaux`, `grille`, `colonnes`, `attente`, `colonnesDeLaGeometrie`, `sansVraieTaille`, `regler(_:)`, `demander(_:ensemble2D:rayons:zone:)`, `attendre(_:)`, `poser(_:rayons:zone:)`, `choisir(rayons:zone:enPlace:)`, `premiereZone(rayons:zone:)`, `oublierAttente()` ;
  - `MoteurPieces.politique` ; `grille`, `colonnes` et `grilleEnAttente`, désormais lus sur elle ; `MoteurPieces.GrilleEnAttente`, un alias de `PolitiqueGrille.Demande`.

**Ce qui sort du moteur** (spec, section 5 ; précisions 1 et 2). Les deux machines d'états que la relecture finale de C avait relevées (mineur 5) :
- **l'isolement** : l'enum `Isolement`, qui vivait dans `MoteurPieces.swift`, passe dans le cœur avec ses règles : la provenance (`isoler`), la remontée (`remonter`, qui rend un `Remontee` que le moteur exécute), le recalage quand une scène arrive (`recaler`), et la règle des clics sur le nom ou le disque d'un étage (`clicEtage`). Cette règle était écrite deux fois (relecture de la tâche 5 de C, mineur 2) : `disqueCliquable`, la garde de `cliquerEtage` et la main du survol sur un nom d'étage la lisent désormais toutes à cet endroit ;
- **la politique de la grille** : le réglage, les colonnes choisies, la demande qui attend la vue d'ensemble 2D, l'hystérésis, la taille nulle, les trois demandes et leurs durées. Le moteur garde la géométrie, les glissements et le cadrage, et appelle ces règles ;
- **la règle de la rotation lente**, sur la demande du contrôleur : elle passe dans `Isolement.rotationLente`, telle quelle ; la tâche 5 la change (spec, section 4.2).

**Le comportement ne change pas.** Le moteur garde ses accesseurs (`isolement`, `grille`, `colonnes`, `grilleEnAttente`) : les tests du moteur, de la fenêtre et de l'isolement restent verts, inchangés. Deux reçoivent une attente de plus, contre deux mutants du câblage qui survivaient : la main sur le nom de l'étage isolé (`survol`), et la grille gardée par l'hystérésis quand la taille est posée à la main (`redimensionnement`).

**Les images de démo ne changent pas.**

- [ ] **Step 1 : écrire les tests.** Les règles de l'isolement et de la politique de la grille, à part ; deux attentes de plus dans les tests de l'app.

`MaillageCoeurTests/IsolementCoeurTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

/// Les regles de l'isolement, sorties du moteur (polissage D, section 5) : la provenance, la remontee, le clic sur le
/// nom ou le disque d'un etage, le recalage sur une nouvelle scene, la rotation lente.
@Suite("Scene : isolement")
struct IsolementCoeurTests {
    /// La provenance (polissage C, section 5.4) : depuis la maison, aucune ; depuis un etage isole, cet etage, meme pour
    /// une piece d'un autre etage ; d'une piece a une autre, elle reste pour une piece de l'etage d'ou l'on vient, et
    /// devient la maison pour une autre.
    @Test func isoler() {
        #expect(Isolement.maison.isoler(piece: "p", etage: "a") == .piece("p", provenance: nil))
        #expect(Isolement.etage("a").isoler(piece: "p", etage: "a") == .piece("p", provenance: "a"))
        #expect(Isolement.etage("a").isoler(piece: "p", etage: "b") == .piece("p", provenance: "a"),
                "depuis un etage isole, une piece d'un autre etage")
        #expect(Isolement.piece("q", provenance: "a").isoler(piece: "p", etage: "a") == .piece("p", provenance: "a"))
        #expect(Isolement.piece("q", provenance: "a").isoler(piece: "p", etage: "b") == .piece("p", provenance: nil))
        #expect(Isolement.piece("q", provenance: nil).isoler(piece: "p", etage: "a") == .piece("p", provenance: nil))
    }

    /// La remontee (section 5.4) : une piece ouverte depuis un etage, a l'etage de la piece (celui du fil, pas
    /// forcement sa provenance), dans une maison de plusieurs plateaux ; sinon la maison ; un etage, la maison ; a la
    /// maison, Echap seulement.
    @Test func remonter() {
        let depuisA = Isolement.piece("p", provenance: "a")
        #expect(depuisA.remonter(etageDeLaPiece: "b", plusieursPlateaux: true, clavier: true) == .etage("b"))
        #expect(depuisA.remonter(etageDeLaPiece: "b", plusieursPlateaux: true, clavier: false) == .etage("b"))
        #expect(depuisA.remonter(etageDeLaPiece: "b", plusieursPlateaux: false, clavier: true) == .maison)
        #expect(depuisA.remonter(etageDeLaPiece: nil, plusieursPlateaux: true, clavier: true) == .maison)
        #expect(Isolement.piece("p", provenance: nil).remonter(etageDeLaPiece: "b", plusieursPlateaux: true, clavier: true)
                == .maison)
        for clavier in [false, true] {
            #expect(Isolement.etage("a").remonter(etageDeLaPiece: nil, plusieursPlateaux: true, clavier: clavier) == .maison)
        }
        #expect(Isolement.maison.remonter(etageDeLaPiece: nil, plusieursPlateaux: true, clavier: true) == .maison)
        #expect(Isolement.maison.remonter(etageDeLaPiece: nil, plusieursPlateaux: true, clavier: false) == .rien)
    }

    /// Le clic sur le nom ou le disque d'un etage (section 5.4), et la main qui s'y pose : il isole l'etage, sauf son
    /// propre disque, l'etage isole ; son nom, si. Dans une maison d'un seul plateau, seulement depuis une piece isolee,
    /// pour revenir a la maison.
    @Test func clicSurUnEtage() {
        for disque in [false, true] {
            for i in [Isolement.maison, .etage("b"), .piece("p", provenance: "a"), .piece("p", provenance: nil)] {
                #expect(i.clicEtage("a", disque: disque, plusieursPlateaux: true, pieceIsolee: false) == .isoler)
                #expect(i.clicEtage("a", disque: disque, plusieursPlateaux: false, pieceIsolee: true) == .maison)
                #expect(i.clicEtage("a", disque: disque, plusieursPlateaux: false, pieceIsolee: false) == .rien)
                #expect(i.cliquable("a", disque: disque, plusieursPlateaux: true, pieceIsolee: false))
                #expect(i.cliquable("a", disque: disque, plusieursPlateaux: false, pieceIsolee: true))
                #expect(!i.cliquable("a", disque: disque, plusieursPlateaux: false, pieceIsolee: false))
            }
        }
        let a = Isolement.etage("a")
        #expect(a.clicEtage("a", disque: true, plusieursPlateaux: true, pieceIsolee: false) == .rien, "son propre disque")
        #expect(!a.cliquable("a", disque: true, plusieursPlateaux: true, pieceIsolee: false))
        #expect(a.clicEtage("a", disque: false, plusieursPlateaux: true, pieceIsolee: false) == .isoler, "son nom")
        #expect(a.cliquable("a", disque: false, plusieursPlateaux: true, pieceIsolee: false))
    }

    /// Une nouvelle scene : la piece ou l'etage isoles qui disparaissent rendent la maison ; presents, rien ne change,
    /// meme si l'etage de la provenance a disparu.
    @Test func recaler() {
        let pieces: Set = ["p"], etages: Set = ["a"]
        #expect(Isolement.piece("q", provenance: "a").recaler(pieces: pieces, etages: etages) == .maison)
        #expect(Isolement.piece("p", provenance: "z").recaler(pieces: pieces, etages: etages) == .piece("p", provenance: "z"))
        #expect(Isolement.etage("b").recaler(pieces: pieces, etages: etages) == .maison)
        #expect(Isolement.etage("a").recaler(pieces: pieces, etages: etages) == .etage("a"))
        #expect(Isolement.maison.recaler(pieces: [], etages: []) == .maison)
    }

    /// La rotation lente (spec de la vue par pieces, section 7) : en 3D, l'envol fini, cochee, sans « Reduire les
    /// animations », sans isolement ; chaque condition l'arrete.
    @Test func rotationLente() {
        #expect(Isolement.rotationLente(troisD: true, bascule: 1, cochee: true, reduire: false, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: false, bascule: 1, cochee: true, reduire: false, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 0.999, cochee: true, reduire: false, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 1, cochee: false, reduire: false, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 1, cochee: true, reduire: true, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 1, cochee: true, reduire: false, sansIsolement: false))
    }
}
```

`MaillageCoeurTests/PolitiqueGrilleTests.swift` (fichier entier) :

```swift
import CoreGraphics
import Foundation
import Testing
@testable import MaillageCoeur

/// La politique de la grille 2D, sortie du moteur (polissage D, section 5) : le reglage, la premiere vraie taille, la
/// demande qui attend la vue d'ensemble 2D, l'hysteresis, les durees. Les rayons et les tailles sont ceux de
/// `CameraSceneTests.hysteresisEtTailleNulle` : quatre plateaux de 12, la rangee a 1820 x 1000, 2 x 2 a 1100 x 760, et
/// 2 x 2 en place qui reste a 1820 x 1000 (a moins de 5 %) mais pas a 2200 x 1000.
@Suite("Scene : politique de la grille")
struct PolitiqueGrilleTests {
    static let r = [12.0, 12, 12, 12]
    static let carree = CGSize(width: 1100, height: 760), pres = CGSize(width: 1820, height: 1000)
    static let large = CGSize(width: 2200, height: 1000)

    /// Les trois demandes (polissage C, section 3.5) : le reglage, 2,6 s sans hysteresis ; le redimensionnement, 0,4 s
    /// avec ; un changement de niveau, 0,4 s sans.
    @Test func durees() {
        #expect(PolitiqueGrille.reglage == PolitiqueGrille.Demande(duree: 2.6, hysteresis: false))
        #expect(PolitiqueGrille.redimensionnement == PolitiqueGrille.Demande(duree: 0.4, hysteresis: true))
        #expect(PolitiqueGrille.niveaux == PolitiqueGrille.Demande(duree: 0.4, hysteresis: false))
    }

    /// Au depart, en grille, sans colonnes : la rangee en attendant une vraie taille. Le reglage ne change que s'il
    /// change ; en rangee, la geometrie n'a pas de colonnes, meme choisies.
    @Test func reglage() {
        var p = PolitiqueGrille()
        #expect(p.grille && p.colonnes == nil && p.attente == nil && p.colonnesDeLaGeometrie == nil && p.sansVraieTaille)
        let meme = p.regler(true)
        #expect(!meme && p.grille)
        let posee = p.premiereZone(rayons: Self.r, zone: Self.carree)
        #expect(posee && p.colonnesDeLaGeometrie == 2)
        let enRangee = p.regler(false)
        #expect(enRangee && !p.grille)
        #expect(p.colonnes == 2 && p.colonnesDeLaGeometrie == nil && !p.sansVraieTaille)
        let encore = p.regler(false)
        #expect(!encore)
        let enGrille = p.regler(true)
        #expect(enGrille && p.colonnesDeLaGeometrie == 2)
        #expect(!PolitiqueGrille(grille: false).sansVraieTaille && PolitiqueGrille(grille: false).colonnesDeLaGeometrie == nil)
    }

    /// La premiere vraie taille (section 3.3) : une taille de 1 pt ou moins, en largeur comme en hauteur, n'en pose
    /// aucune ; la premiere vraie pose ses colonnes, une seule fois ; en rangee, rien.
    @Test func premiereVraieTaille() {
        var p = PolitiqueGrille()
        for zone in [CGSize.zero, CGSize(width: 1, height: 600), CGSize(width: 600, height: 1)] {
            let posee = p.premiereZone(rayons: Self.r, zone: zone)
            #expect(!posee && p.colonnes == nil && p.sansVraieTaille, "\(zone) : rien")
        }
        let deux = p.premiereZone(rayons: Self.r, zone: CGSize(width: 2, height: 2))
        #expect(deux && p.colonnes != nil, "2 pt : une vraie taille")
        var q = PolitiqueGrille()
        let premiere = q.premiereZone(rayons: Self.r, zone: Self.carree)
        #expect(premiere && q.colonnes == 2)
        let seconde = q.premiereZone(rayons: Self.r, zone: Self.pres)
        #expect(!seconde && q.colonnes == 2, "une seule fois")
        var rangee = PolitiqueGrille(grille: false)
        let enRangee = rangee.premiereZone(rayons: Self.r, zone: Self.carree)
        #expect(!enRangee && rangee.colonnes == nil)
    }

    /// Hors de la vue d'ensemble 2D, une demande attend, sans rien choisir ; une seconde garde la plus longue duree, dans
    /// les deux ordres, et l'hysteresis seulement si les deux la demandent. A la vue d'ensemble, elle se pose : plus
    /// d'attente, les colonnes de la zone.
    @Test func attente() {
        var p = PolitiqueGrille()
        _ = p.premiereZone(rayons: Self.r, zone: Self.carree)
        let attend = p.demander(PolitiqueGrille.redimensionnement, ensemble2D: false, rayons: Self.r, zone: Self.large)
        #expect(!attend && p.attente == PolitiqueGrille.redimensionnement && p.colonnes == 2)
        let attendEncore = p.demander(PolitiqueGrille.reglage, ensemble2D: false, rayons: Self.r, zone: Self.large)
        #expect(!attendEncore)
        #expect(p.attente == PolitiqueGrille.Demande(duree: 2.6, hysteresis: false))
        var q = PolitiqueGrille()
        q.attendre(PolitiqueGrille.reglage)
        q.attendre(PolitiqueGrille.redimensionnement)
        #expect(q.attente == PolitiqueGrille.Demande(duree: 2.6, hysteresis: false), "la plus longue, dans l'autre ordre")
        var h = PolitiqueGrille()
        h.attendre(PolitiqueGrille.redimensionnement)
        h.attendre(PolitiqueGrille.Demande(duree: 0.2, hysteresis: true))
        #expect(h.attente == PolitiqueGrille.Demande(duree: 0.4, hysteresis: true), "l'hysteresis, si toutes la demandent")
        let posee = p.demander(PolitiqueGrille.niveaux, ensemble2D: true, rayons: Self.r, zone: Self.large)
        #expect(posee && p.attente == nil && p.colonnes == 4)
        p.attendre(PolitiqueGrille.niveaux)
        p.oublierAttente()
        #expect(p.attente == nil && p.colonnes == 4)
    }

    /// L'hysteresis de 5 % (section 3.3) : 2 x 2 en place reste a 1820 x 1000 avec une demande qui la porte, et pas
    /// sans ; a 2200 x 1000, la rangee l'emporte meme avec. En rangee, rien ne se choisit.
    @Test func hysteresis() {
        func enPlace() -> PolitiqueGrille {
            var p = PolitiqueGrille()
            _ = p.premiereZone(rayons: Self.r, zone: Self.carree)
            return p
        }
        var avec = enPlace()
        avec.poser(PolitiqueGrille.redimensionnement, rayons: Self.r, zone: Self.pres)
        #expect(avec.colonnes == 2)
        var sans = enPlace()
        sans.poser(PolitiqueGrille.niveaux, rayons: Self.r, zone: Self.pres)
        #expect(sans.colonnes == 4)
        var loin = enPlace()
        loin.poser(PolitiqueGrille.redimensionnement, rayons: Self.r, zone: Self.large)
        #expect(loin.colonnes == 4)
        var choix = enPlace()
        choix.choisir(rayons: Self.r, zone: Self.pres, enPlace: true)
        #expect(choix.colonnes == 2)
        choix.choisir(rayons: Self.r, zone: Self.pres, enPlace: false)
        #expect(choix.colonnes == 4)
        choix.choisir(rayons: Self.r, zone: CGSize(width: 600, height: 1), enPlace: false)
        #expect(choix.colonnes == 4, "1 pt de haut : rien ne change")
        var rangee = enPlace()
        _ = rangee.regler(false)
        rangee.poser(PolitiqueGrille.niveaux, rayons: Self.r, zone: Self.pres)
        #expect(rangee.colonnes == 2 && rangee.attente == nil)
    }
}
```

Dans `MaillageThreadTests/IsolementTests.swift`, remplacer :

```swift
        #expect(m.survolEtage == nil && m.curseurForme == .fleche, "le disque de l'etage isole")
```

par :

```swift
        #expect(m.survolEtage == nil && m.curseurForme == .fleche, "le disque de l'etage isole")
        m.survoler(try Self.nomDEtage(m, etage))
        #expect(m.survolNomEtage == etage && m.curseurForme == .main, "son nom, lui, se clique")
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        #expect(h.colonnes == enPlace && h.glissementPlateaux == nil, "l'hysteresis garde la grille en place")
```

par :

```swift
        #expect(h.colonnes == enPlace && h.glissementPlateaux == nil, "l'hysteresis garde la grille en place")
        h.poserTaille(CGSize(width: largeur, height: hauteur))
        #expect(h.colonnes == enPlace, "la taille posee a la main la garde aussi")
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/IsolementCoeurTests MaillageCoeurTests/PolitiqueGrilleTests MaillageThreadTests/IsolementTests MaillageThreadTests/MoteurPiecesTests`
Expected: la compilation des tests échoue (`PolitiqueGrilleTests.swift`), par exemple avec `error: cannot find 'PolitiqueGrille' in scope` et `error: cannot find type 'PolitiqueGrille' in scope` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Scene/Isolement.swift` (fichier entier) :

```swift
import Foundation

/// Ce que montre la vue par pieces (polissage C, section 5) : la maison, un etage isole (sa cle), ou une piece isolee
/// (sa cle), avec sa provenance : l'etage isole d'ou on l'a ouverte, nil depuis la maison. Ses regles sont ici, sorties
/// du moteur (polissage D, section 5) : les transitions (isoler, aller a un etage, remonter), le recalage quand une
/// scene arrive, et la regle des clics sur le nom ou le disque d'un etage, en un seul endroit pour le clic et pour la
/// main du pointeur. Le moteur garde les vols, les fondus et la camera.
public enum Isolement: Hashable, Sendable {
    case maison
    case etage(String)
    case piece(String, provenance: String?)

    /// Ce que fait une remontee (Echap, clic a cote) : aller a un etage (sa cle), revenir a la maison, ou rien.
    public enum Remontee: Hashable, Sendable {
        case etage(String)
        case maison
        case rien
    }

    /// Ce que fait un clic sur le nom ou le disque d'un etage : l'isoler, revenir a la maison, ou rien.
    public enum ClicEtage: Hashable, Sendable {
        case isoler
        case maison
        case rien
    }

    /// Isoler la piece `piece`, de l'etage `etage` (section 5.4) : depuis la maison, sans provenance ; depuis un
    /// etage isole, cet etage ; d'une piece a une autre, la provenance reste, sauf vers une piece d'un autre etage :
    /// la maison.
    public func isoler(piece: String, etage: String) -> Isolement {
        let provenance: String? = switch self {
        case .maison: nil
        case .etage(let k): k
        case .piece(_, let p): p == etage ? p : nil
        }
        return .piece(piece, provenance: provenance)
    }

    /// Echap et le clic a cote remontent d'ou l'on vient (section 5.4) : une piece ouverte depuis un etage isole, a
    /// l'etage de la piece (`etageDeLaPiece`, celui du fil), dans une maison de plusieurs plateaux ; une autre piece,
    /// ou un etage, a la maison. A la maison, Echap (`clavier`) ramene une vue zoomee ou deplacee a la vue d'ensemble ;
    /// le clic a cote ne fait rien.
    public func remonter(etageDeLaPiece: String?, plusieursPlateaux: Bool, clavier: Bool) -> Remontee {
        switch self {
        case .piece(_, let provenance):
            if provenance != nil, plusieursPlateaux, let e = etageDeLaPiece { return .etage(e) }
            return .maison
        case .etage:
            return .maison
        case .maison:
            return clavier ? .maison : .rien
        }
    }

    /// Un clic sur le nom (`disque` faux) ou le disque de l'etage `cle` (section 5.4) : il l'isole ; son propre disque,
    /// l'etage isole, entre les pieces, ne fait rien. Dans une maison d'un seul plateau, seulement depuis une piece
    /// isolee (`pieceIsolee`), pour remonter a la maison. La main du pointeur suit la meme regle (`cliquable`).
    public func clicEtage(_ cle: String, disque: Bool, plusieursPlateaux: Bool, pieceIsolee: Bool) -> ClicEtage {
        guard plusieursPlateaux else { return pieceIsolee ? .maison : .rien }
        if disque, self == .etage(cle) { return .rien }
        return .isoler
    }

    /// Le clic sur ce nom ou ce disque fait quelque chose : la main du pointeur s'y pose.
    public func cliquable(_ cle: String, disque: Bool, plusieursPlateaux: Bool, pieceIsolee: Bool) -> Bool {
        clicEtage(cle, disque: disque, plusieursPlateaux: plusieursPlateaux, pieceIsolee: pieceIsolee) != .rien
    }

    /// La rotation lente tourne (spec de la vue par pieces, section 7) : en 3D, l'envol fini (`bascule` a 1), cochee,
    /// sans « Reduire les animations », et ni piece ni etage isoles, ni en train d'etre quittes (`sansIsolement`).
    public static func rotationLente(troisD: Bool, bascule: Double, cochee: Bool, reduire: Bool,
                                     sansIsolement: Bool) -> Bool {
        troisD && bascule == 1 && cochee && !reduire && sansIsolement
    }

    /// Sur une nouvelle scene, de pieces `pieces` et de plateaux `etages` (leurs cles) : une piece isolee ou un etage
    /// isole qui disparait rend la maison ; sinon, rien ne change.
    public func recaler(pieces: Set<String>, etages: Set<String>) -> Isolement {
        switch self {
        case .piece(let p, _) where !pieces.contains(p): .maison
        case .etage(let k) where !etages.contains(k): .maison
        default: self
        }
    }
}
```

`MaillageCoeur/Scene/PolitiqueGrille.swift` (fichier entier) :

```swift
import CoreGraphics
import Foundation

/// La politique de la grille 2D (polissage C, sections 3.3 et 3.5 ; sortie du moteur au polissage D, section 5) : le
/// reglage (en grille ou en rangee), les colonnes choisies, et une demande qui attend la vue d'ensemble 2D. Une demande
/// porte la duree du glissement de ses plateaux et l'hysteresis : au changement du reglage, 2,6 s sans hysteresis ; au
/// redimensionnement, 0,4 s avec ; apres un changement de niveau, 0,4 s sans (en 3D, les plateaux glissent en 0,9 s).
/// Une taille de 1 pt ou moins ne choisit rien. Le moteur pose la geometrie et cadre la vue ; il appelle ces regles.
public struct PolitiqueGrille: Hashable, Sendable {
    /// Une demande : la duree du glissement des plateaux vers leur nouvelle case, et si la grille en place reste tant
    /// qu'elle est a moins de 5 % du choix.
    public struct Demande: Hashable, Sendable {
        public var duree: Double
        public var hysteresis: Bool

        public init(duree: Double, hysteresis: Bool) {
            self.duree = duree
            self.hysteresis = hysteresis
        }
    }

    /// Le changement du reglage : les plateaux glissent comme l'envol, 2,6 s, sans hysteresis.
    public static let reglage = Demande(duree: CameraScene.dureeEnvol, hysteresis: false)
    /// Une autre zone visible : 0,4 s, avec l'hysteresis.
    public static let redimensionnement = Demande(duree: CameraScene.dureeCases, hysteresis: true)
    /// Un changement de niveau, hors de la vue d'ensemble 2D : 0,4 s, sans hysteresis, a son retour.
    public static let niveaux = Demande(duree: CameraScene.dureeCases, hysteresis: false)

    /// Etages en 2D : en grille (le reglage par defaut), ou en rangee.
    public private(set) var grille: Bool
    /// Colonnes de la grille ; nil : pas encore de vraie taille, la rangee en attendant.
    public private(set) var colonnes: Int?
    /// Une demande qui attend la vue d'ensemble 2D (zoomee, isolee, en 3D, en mouvement).
    public private(set) var attente: Demande?

    public init(grille: Bool = true) {
        self.grille = grille
    }

    /// Les colonnes de la geometrie : en grille, celles choisies (nil, la rangee, avant une vraie taille) ; en rangee,
    /// nil.
    public var colonnesDeLaGeometrie: Int? { grille ? colonnes : nil }

    /// Le reglage ; rend vrai s'il change.
    public mutating func regler(_ g: Bool) -> Bool {
        guard g != grille else { return false }
        grille = g
        return true
    }

    /// Une demande : a la vue d'ensemble 2D (`ensemble2D`), elle se pose tout de suite, et la fonction rend vrai (le
    /// moteur pose alors la geometrie, ses plateaux glissant en `d.duree`) ; sinon elle attend.
    public mutating func demander(_ d: Demande, ensemble2D: Bool, rayons: [Double], zone: CGSize) -> Bool {
        guard ensemble2D else {
            attendre(d)
            return false
        }
        poser(d, rayons: rayons, zone: zone)
        return true
    }

    /// Une demande attend la vue d'ensemble 2D : avec une autre en attente, la plus longue duree, et l'hysteresis
    /// seulement si toutes la demandent.
    public mutating func attendre(_ d: Demande) {
        attente = Demande(duree: max(attente?.duree ?? 0, d.duree), hysteresis: (attente?.hysteresis ?? true) && d.hysteresis)
    }

    /// Pose une demande : plus d'attente ; en grille, les colonnes de la zone `zone`, la grille en place gardee si la
    /// demande a l'hysteresis.
    public mutating func poser(_ d: Demande, rayons: [Double], zone: CGSize) {
        attente = nil
        choisir(rayons: rayons, zone: zone, enPlace: d.hysteresis)
    }

    /// En grille, les colonnes de la zone `zone` ; `enPlace` : la grille en place reste a moins de 5 % du choix. Une
    /// taille de 1 pt ou moins ne change rien.
    public mutating func choisir(rayons: [Double], zone: CGSize, enPlace: Bool) {
        guard grille, let c = GeometrieMaison.colonnes(rayons: rayons, taille: zone, enPlace: enPlace ? colonnes : nil)
        else { return }
        colonnes = c
    }

    /// En grille, aucune colonne n'est encore choisie : la grille attend une vraie taille.
    public var sansVraieTaille: Bool { grille && colonnes == nil }

    /// La premiere vraie zone (section 3.3) : en grille, avant tout choix, les colonnes de cette zone, sans autre
    /// condition. Rend vrai si elle les pose : le moteur cadre alors la vue d'ensemble ; une taille de 1 pt ou moins
    /// n'en pose aucune.
    public mutating func premiereZone(rayons: [Double], zone: CGSize) -> Bool {
        guard sansVraieTaille, let c = GeometrieMaison.colonnes(rayons: rayons, taille: zone) else { return false }
        colonnes = c
        return true
    }

    /// La demande en attente part : l'envol vers la 2D pose la grille de la zone du moment.
    public mutating func oublierAttente() {
        attente = nil
    }
}
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    case fond
}

/// Ce que montre la vue (polissage C, section 5) : la maison, un etage isole (sa cle), ou une piece isolee (sa cle),
/// avec sa provenance : l'etage isole d'ou on l'a ouverte, nil depuis la maison.
enum Isolement: Equatable {
    case maison
    case etage(String)
    case piece(String, provenance: String?)
```

par :

```swift
    case fond
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Etages en 2D (polissage C, section 3.1) : en grille, ou en rangee ; le reglage, pose par la fenetre.
    @ObservationIgnored private(set) var grille = true
    /// Colonnes de la grille ; nil : pas encore de vraie taille, la rangee en attendant.
    @ObservationIgnored private(set) var colonnes: Int?
    /// Une grille voulue attend la vue d'ensemble 2D (zoomee, isolee, en 3D, en mouvement).
    @ObservationIgnored private(set) var grilleEnAttente: GrilleEnAttente?
```

par :

```swift
    /// La politique de la grille 2D (polissage C, section 3 ; dans le coeur depuis le polissage D, section 5) : le
    /// reglage « Etages en 2D », pose par la fenetre, les colonnes choisies, une demande qui attend la vue d'ensemble 2D.
    @ObservationIgnored private(set) var politique = PolitiqueGrille()
    var grille: Bool { politique.grille }
    var colonnes: Int? { politique.colonnes }
    var grilleEnAttente: GrilleEnAttente? { politique.attente }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    struct GrilleEnAttente: Equatable {
        var duree: Double
        var hysteresis: Bool
    }
```

par :

```swift
    typealias GrilleEnAttente = PolitiqueGrille.Demande
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            colonnes = colonnesVoulues(scene, enPlace: nil) ?? colonnes
        } else if niveauxChanges {
            attendreGrille(CameraScene.dureeCases, hysteresis: false)
```

par :

```swift
            politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: false)
        } else if niveauxChanges {
            politique.attendre(PolitiqueGrille.niveaux)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        ek = ek.filter { clesEtages.contains($0.key) }
```

par :

```swift
        ek = ek.filter { clesEtages.contains($0.key) }
        isolement = isolement.recaler(pieces: clesPieces, etages: clesEtages)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            isolee = nil
            if case .piece = isolement { isolement = .maison }
```

par :

```swift
            isolee = nil
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            seCible = 0
            if case .etage = isolement { isolement = .maison }
```

par :

```swift
            seCible = 0
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        GeometrieMaison(rayons: scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge },
                        plateaux: scene.etages.map {
                            GeometrieMaison.Plateau(niveau: $0.niveau, principal: $0.principal, dehors: $0.dehors)
                        },
                        colonnes: grille ? colonnes : nil)
    }

    /// Les colonnes de la grille pour la zone visible de la vue (polissage C, section 3.3) ; nil sans vraie taille.
    private func colonnesVoulues(_ scene: ScenePieces, enPlace: Int?) -> Int? {
        GeometrieMaison.colonnes(rayons: scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge },
                                 taille: zoneVisible, enPlace: enPlace)
```

par :

```swift
        GeometrieMaison(rayons: rayons(scene),
                        plateaux: scene.etages.map {
                            GeometrieMaison.Plateau(niveau: $0.niveau, principal: $0.principal, dehors: $0.dehors)
                        },
                        colonnes: politique.colonnesDeLaGeometrie)
    }

    /// Les rayons des plateaux d'une scene, ceux de sa disposition : la grille se choisit sur eux.
    private func rayons(_ scene: ScenePieces) -> [Double] {
        scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        guard g != grille else { return }
        grille = g
        guard pret else { return }
        demanderGrille(CameraScene.dureeEnvol, hysteresis: false)
```

par :

```swift
        guard politique.regler(g), pret else { return }
        demanderGrille(PolitiqueGrille.reglage)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if grille && colonnes == nil {
            guard let c = colonnesVoulues(scene, enPlace: nil) else { return }
            colonnes = c
```

par :

```swift
        if politique.sansVraieTaille {
            guard politique.premiereZone(rayons: rayons(scene), zone: zoneVisible) else { return }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        demanderGrille(CameraScene.dureeCases, hysteresis: true)
    }

    /// Une grille voulue : posee a la vue d'ensemble 2D, ses plateaux glissant en `duree` ; sinon elle attend.
    private func demanderGrille(_ duree: Double, hysteresis: Bool) {
        if t == 0 && aLaVueDEnsemble {
            poserGrille(duree, hysteresis: hysteresis)
        } else {
            attendreGrille(duree, hysteresis: hysteresis)
        }
    }

    /// Une grille attend la vue d'ensemble 2D : la plus longue duree, et l'hysteresis si toutes la demandent.
    private func attendreGrille(_ duree: Double, hysteresis: Bool) {
        let a = grilleEnAttente
        grilleEnAttente = GrilleEnAttente(duree: max(a?.duree ?? 0, duree), hysteresis: (a?.hysteresis ?? true) && hysteresis)
    }

    private func poserGrille(_ duree: Double, hysteresis: Bool) {
        grilleEnAttente = nil
        guard let scene else { return }
        if grille, let c = colonnesVoulues(scene, enPlace: hysteresis ? colonnes : nil) { colonnes = c }
```

par :

```swift
        demanderGrille(PolitiqueGrille.redimensionnement)
    }

    /// Une grille voulue : posee a la vue d'ensemble 2D, ses plateaux glissant en `d.duree` ; sinon elle attend
    /// (`PolitiqueGrille`).
    private func demanderGrille(_ d: PolitiqueGrille.Demande) {
        guard let scene else { return }
        if politique.demander(d, ensemble2D: t == 0 && aLaVueDEnsemble, rayons: rayons(scene), zone: zoneVisible) {
            poserGeometrie(d.duree)
        }
    }

    /// Pose la grille d'une demande, puis sa geometrie.
    private func poserGrille(_ d: PolitiqueGrille.Demande) {
        guard let scene else { return }
        politique.poser(d, rayons: rayons(scene), zone: zoneVisible)
        poserGeometrie(d.duree)
    }

    /// La geometrie de la grille choisie : ses plateaux glissent en `duree`.
    private func poserGeometrie(_ duree: Double) {
        guard let scene else { return }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            grilleEnAttente = nil
            if grille, let c = colonnesVoulues(scene, enPlace: nil) { colonnes = c }
```

par :

```swift
            politique.oublierAttente()
            politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: false)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        let provenance: String? = switch isolement {
        case .maison: nil
        case .etage(let k): k
        case .piece(_, let p): p == etage ? p : nil
        }
        isolement = .piece(piece.id, provenance: provenance)
```

par :

```swift
        isolement = isolement.isoler(piece: piece.id, etage: etage)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        switch isolement {
        case .piece(let cle, let provenance):
            if provenance != nil, let scene, scene.etages.count > 1, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
                allerEtage(scene.pieces[i].etage)
            } else {
                versMaison()
            }
        case .etage:
            versMaison()
        case .maison:
            if clavier { versMaison() }
```

par :

```swift
        var etageDeLaPiece: String?
        if case .piece(let cle, _) = isolement, let scene, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            etageDeLaPiece = scene.etages[scene.pieces[i].etage].id
        }
        switch isolement.remonter(etageDeLaPiece: etageDeLaPiece, plusieursPlateaux: (scene?.etages.count ?? 0) > 1,
                                  clavier: clavier) {
        case .etage(let cle):
            if let e = scene?.etages.firstIndex(where: { $0.id == cle }) { allerEtage(e) }
        case .maison:
            versMaison()
        case .rien:
            break
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if let g = grilleEnAttente, t == 0, aLaVueDEnsemble { poserGrille(g.duree, hysteresis: g.hysteresis) }
        if !occupe, let e = attente { appliquer(e) }
```

par :

```swift
        if let g = politique.attente, t == 0, aLaVueDEnsemble { poserGrille(g) }
        if !occupe, let e = attente { appliquer(e) }
    }

    /// La rotation lente tourne (`Isolement.rotationLente`).
    private var rotationLente: Bool {
        Isolement.rotationLente(troisD: troisD, bascule: t, cochee: rotation, reduire: reduire, sansIsolement: sansIsolement)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if troisD && t == 1 && rotation && !reduire && sansIsolement && geste == nil {
```

par :

```swift
        if rotationLente && geste == nil {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if troisD && t == 1 && rotation && !reduire && sansIsolement { return true }
```

par :

```swift
        if rotationLente { return true }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        case .nomEtage: (scene?.etages.count ?? 0) > 1 || estIsolee
```

par :

```swift
        case .nomEtage(let e): clicEtage(e, disque: false) != .rien
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        guard let scene, e < scene.etages.count else { return false }
        return scene.etages.count > 1 ? estIsolee || isolement != .etage(scene.etages[e].id) : estIsolee
```

par :

```swift
        clicEtage(e, disque: true) != .rien
    }

    /// Ce que fait un clic sur le nom ou le disque du plateau `e` (`Isolement.clicEtage`) : la regle du clic et de la
    /// main du pointeur.
    private func clicEtage(_ e: Int, disque: Bool) -> Isolement.ClicEtage {
        guard let scene, e < scene.etages.count else { return .rien }
        return isolement.clicEtage(scene.etages[e].id, disque: disque, plusieursPlateaux: scene.etages.count > 1,
                                   pieceIsolee: estIsolee)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        guard let scene, e < scene.etages.count else { return }
        guard scene.etages.count > 1 else {
            if estIsolee { versMaison() }
            return
        }
        if disque, isolement == .etage(scene.etages[e].id) { return }
        allerEtage(e)
```

par :

```swift
        switch clicEtage(e, disque: disque) {
        case .isoler: allerEtage(e)
        case .maison: versMaison()
        case .rien: break
        }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if grille, let c = colonnesVoulues(scene, enPlace: colonnes) { colonnes = c }
        glissementPlateaux = nil
        grilleEnAttente = nil
```

par :

```swift
        politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: true)
        glissementPlateaux = nil
        politique.oublierAttente()
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/IsolementCoeurTests MaillageCoeurTests/PolitiqueGrilleTests MaillageThreadTests/IsolementTests MaillageThreadTests/MoteurPiecesTests`
Expected: `Test run with 10 tests in 2 suites passed` (cœur) et `Test run with 52 tests in 2 suites passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh`
Expected: `Test run with 379 tests in 39 suites passed` (cœur) et `Test run with 347 tests in 30 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 10 tests de plus et 2 suites pour le cœur, l'app inchangée.

- [ ] **Step 6 : les images de démo, identiques.** Comparées à celles de `main`, rendues à la fin de C (`captures-polC-finale`) : identiques, octet pour octet. Si une image diffère, s'arrêter : la tâche a changé le rendu. Les images se rendent toujours juste après la suite du step précédent, avec l'app qu'elle vient de compiler.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t1"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "maillage-polD/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
for f in $(ls "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-finale"); do cmp -s "$D/$f" "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-finale/$f" && echo "$f identique" || echo "$f differe"; done | sort | awk '{print $2}' | uniq -c
```

Expected : 20 ; « l'app a quitté » ; « 20 identique ».

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Scene/Isolement.swift MaillageCoeur/Scene/PolitiqueGrille.swift MaillageCoeurTests/IsolementCoeurTests.swift MaillageCoeurTests/PolitiqueGrilleTests.swift MaillageThread/Vues/Pieces/MoteurPieces.swift MaillageThreadTests/IsolementTests.swift MaillageThreadTests/MoteurPiecesTests.swift
git commit -m "Sortir du moteur dans le coeur l'isolement et la politique de la grille, en types purs testes a part, sans changer le comportement

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Mutants essayés sur la copie validée** (chacun appliqué seul, la tâche jouée par ses tests ; un mutant qui ne compilait pas a été rejoué sous une forme qui compile, sauf pour le découpage, où la compilation est l'attente) :

- **Dans le cœur** (18 mutants, tous tués par `IsolementCoeurTests` et `PolitiqueGrilleTests`) : la provenance gardée vers une pièce d'un autre étage ; la remontée vers la provenance au lieu de l'étage de la pièce ; sans la garde des plusieurs plateaux ; le clic à côté qui remonte à la maison ; le nom de l'étage isolé qui ne fait rien ; une maison d'un seul plateau sans retour depuis une pièce isolée ; un étage disparu gardé ; la rotation sans « Réduire » ; la rotation dès 0,5 de bascule ; l'attente qui garde la dernière durée ; l'hystérésis en « ou » ; la pose sans hystérésis ; la pose qui garde l'attente ; la première taille prise plusieurs fois ; les colonnes en rangée ; le choix en rangée ; la demande toujours posée ; le réglage qui rend vrai sans changer.
- **Dans le moteur** (5 mutants du câblage) : la main sur un nom d'étage avec la règle du disque, et la taille posée sans hystérésis survivaient : les deux attentes ajoutées les tuent ; le clic à côté pris pour Échap, le redimensionnement qui demande le réglage, le recalage oublié, tués par les tests existants.

### Task 2: La transition dans le cœur : les poses par clé, le glissement de 0,9 s, les fondus de 0,3 s, l'interruption, la scène projetée

**Files:**
- Create: `MaillageCoeur/Scene/TransitionScene.swift`, `MaillageCoeurTests/TransitionSceneTests.swift`
- Modify: `MaillageCoeur/Scene/SceneProjetee.swift` (blocs ci-dessous)

**Interfaces:**
- Consumes : `ScenePieces`, `CartesPieces.Carte`, `GeometrieMaison` (`centrePlateau`), `CameraScene.rampe`, `SceneProjetee.init(scene:cartes:positions:geometrie:etat:orbite:cadre:)`, `GrapheReseau.Lien`, existants ; dans les tests, `SceneProjeteeTests.scene()`, `indice`, `cadre`.
- Produces :
  - `PosesScene` : `Ancre(plateau:place:poids:)`, `Piece(ancres:taille:teinte:opacite:)`, `Noeud(ancres:decalage:rayon:opacite:)`, `Lien(_:opacite:)` ; `pieces`, `noeuds`, `liens` ; `init(scene:cartes:positions:)`, `cle(_:)`, `recouvertes(par:)`, `centre(_:geometrie:plateaux:t:)`, `melange(_:_:_:)` ;
  - `TransitionScene` : `duree` (0,9), `dureeFondu` (0,3), `depart`, `arrivee`, `debut` ; `init?(de:vers:a:reduire:)`, `finie(a:)`, `poses(a:)`, `oublier(pieces:noeuds:)` ;
  - `SceneProjetee(…, poses:)` (vide par défaut : la projection d'avant, au bit près) ; `SceneProjetee.fantomes` ; les blocs de ce qui s'efface, `piece` à -1.

**La représentation** (spec, section 1 ; précision 3). Une pose est rangée par clé : pièce, nœud, lien. Sa place est une **ancre** sur un plateau, par la clé du plateau, et non un point du monde : la géométrie du moment la pose dans le monde, en 2D comme en 3D, pendant que les plateaux glissent (C) ou que la vue bascule. Une pose en route d'un plateau à un autre est la moyenne pondérée de ses ancres ; deux ancres du même plateau n'en font qu'une. Ainsi :
- un appareil qui change de pièce, et d'étage, va **en ligne droite** dans le monde, en 2D comme en 3D, quelle que soit la géométrie (`dUnPlateauALAutre`) ;
- **l'interruption est exacte** : la pose affichée d'une transition en cours est encore un jeu d'ancres, d'où repart la suivante, sans saut ; il n'y a jamais plus d'ancres que de plateaux.

**La transition** ne garde que ce qui change. Ce qui est présent des deux côtés glisse en 0,9 s, en cubique entrée-sortie (`CameraScene.rampe`) : le centre et la taille d'une pièce, la place d'un nœud (le centre de sa pièce, puis sa place dans la carte). Ce qui n'est que d'un côté apparaît ou s'efface à sa place, en fondu linéaire de 0,3 s, depuis l'opacité du départ (une transition interrompue). Un lien n'entre dans la transition que s'il apparaît ou s'en va ; ses bouts suivent les nœuds. « Réduire les animations » : pas de transition.

**La scène projetée** prend les poses de ce qui change ; le reste est projeté comme avant, au bit près (`sceneProjeteeEnRoute`). Ce qui s'efface, absent de la scène, s'y dessine aussi, à sa dernière place : un bloc (`piece` à -1), une pastille (dans `fantomes`), un lien. Rien de cela ne se clique, ni ne porte de nom.

**Le moteur ne change pas encore** : la tâche 3 branche la transition. **Les images de démo ne changent pas.**

- [ ] **Step 1 : écrire les tests.** Les poses, la transition, et la scène projetée qui les prend.

`MaillageCoeurTests/TransitionSceneTests.swift` (fichier entier) :

```swift
import CoreGraphics
import Foundation
import simd
import Testing
@testable import MaillageCoeur

/// Le glissement d'une disposition a l'autre (polissage D, section 1) : les poses par cle, en route en 0,9 s en
/// cubique entree-sortie, les fondus de 0,3 s, l'interruption sans saut, « Reduire les animations » ; et la scene
/// projetee qui les prend.
@Suite("Scene : transition d'une disposition a l'autre")
struct TransitionSceneTests {
    typealias A = PosesScene.Ancre

    /// Une piece « p », sur le plateau `plateau`, a `x`, de largeur `l`.
    static func piece(_ plateau: String = "a", x: Double, l: Double = 2) -> PosesScene.Piece {
        PosesScene.Piece(ancres: [A(plateau: plateau, place: SIMD2(x, 0))], taille: SIMD2(l, 2), teinte: 3)
    }

    static func noeud(_ plateau: String, x: Double) -> PosesScene.Noeud {
        PosesScene.Noeud(ancres: [A(plateau: plateau, place: SIMD2(x, 0))], decalage: SIMD2(0.5, -0.5), rayon: 7)
    }

    static func lien(_ de: String, _ vers: String) -> GrapheReseau.Lien {
        GrapheReseau.Lien(de: de, vers: vers, genre: .radio, qualite: 2)
    }

    /// Le centre d'une seule ancre posee, sa place sur x.
    static func x(_ p: PosesScene.Piece?) -> Double? {
        guard let p, p.ancres.count == 1 else { return nil }
        return p.ancres[0].place.x
    }

    /// Les poses a 0, au quart, a la moitie et a la fin du temps : 0, 6,25 % (la cubique, et non une droite ni une
    /// autre courbe symetrique), 50 % et 100 % du chemin, la taille de la carte avec ; finie a 0,9 s, pas avant ; a la
    /// fin, exactement l'arrivee.
    @Test func glissement() throws {
        var d = PosesScene(), a = PosesScene()
        d.pieces["p"] = Self.piece(x: 0, l: 2)
        a.pieces["p"] = Self.piece(x: 10, l: 4)
        let t = try #require(TransitionScene(de: d, vers: a, a: 100))
        #expect(TransitionScene.duree == 0.9 && TransitionScene.dureeFondu == 0.3)
        #expect(Self.x(t.poses(a: 100).pieces["p"]) == 0)
        #expect(abs((Self.x(t.poses(a: 100.225).pieces["p"]) ?? -1) - 0.625) < 1e-9, "6,25 % au quart du temps")
        #expect(abs((Self.x(t.poses(a: 100.45).pieces["p"]) ?? -1) - 5) < 1e-9)
        #expect(abs((t.poses(a: 100.45).pieces["p"]?.taille.x ?? -1) - 3) < 1e-9)
        #expect(abs((Self.x(t.poses(a: 100.675).pieces["p"]) ?? -1) - 9.375) < 1e-9, "93,75 % aux trois quarts")
        #expect(t.poses(a: 100.9).pieces["p"] == a.pieces["p"] && t.poses(a: 105).pieces["p"] == a.pieces["p"])
        #expect(t.poses(a: 99).pieces["p"] == d.pieces["p"], "avant le debut : le depart")
        #expect(!t.finie(a: 100.89) && t.finie(a: 100.9) && t.finie(a: 101))
    }

    /// Les fondus de 0,3 s : ce qui arrive, piece, noeud ou lien, apparait a sa place, de 0 a 1 ; ce qui part s'efface
    /// a sa derniere place, de 1 a 0. Puis la pose reste, jusqu'a la fin du glissement.
    @Test func fondus() throws {
        var d = PosesScene(), a = PosesScene()
        d.pieces["part"] = Self.piece(x: 1)
        a.pieces["arrive"] = Self.piece("b", x: 2)
        d.noeuds["n0"] = Self.noeud("a", x: 1)
        a.noeuds["n1"] = Self.noeud("b", x: 2)
        d.liens[PosesScene.cle(Self.lien("n0", "x"))] = PosesScene.Lien(Self.lien("n0", "x"))
        a.liens[PosesScene.cle(Self.lien("n1", "x"))] = PosesScene.Lien(Self.lien("n1", "x"))
        let t = try #require(TransitionScene(de: d, vers: a, a: 0))
        let parti = PosesScene.cle(Self.lien("n0", "x")), venu = PosesScene.cle(Self.lien("n1", "x"))
        for (instant, arrivee) in [(0.0, 0.0), (0.075, 0.25), (0.15, 0.5), (0.3, 1.0), (0.6, 1.0)] {
            let p = t.poses(a: instant)
            for o in [p.pieces["arrive"]?.opacite, p.noeuds["n1"]?.opacite, p.liens[venu]?.opacite] {
                #expect(abs((o ?? -1) - arrivee) < 1e-9, "a \(instant) s, ce qui arrive")
            }
            for o in [p.pieces["part"]?.opacite, p.noeuds["n0"]?.opacite, p.liens[parti]?.opacite] {
                #expect(abs((o ?? -1) - (1 - arrivee)) < 1e-9, "a \(instant) s, ce qui part")
            }
            #expect(Self.x(p.pieces["part"]) == 1 && Self.x(p.pieces["arrive"]) == 2, "a sa place")
            #expect(p.noeuds["n0"]?.ancres == d.noeuds["n0"]?.ancres && p.noeuds["n1"]?.ancres == a.noeuds["n1"]?.ancres)
        }
    }

    /// Rien ne change : pas de transition ; un lien deja la, ou la qualite seule change, non plus. « Reduire les
    /// animations » : jamais de transition, tout est immediat. La transition ne garde que ce qui change.
    @Test func ceQuiChange() throws {
        var d = PosesScene()
        d.pieces["p"] = Self.piece(x: 0)
        d.pieces["q"] = Self.piece(x: 5)
        d.liens["l"] = PosesScene.Lien(Self.lien("p", "q"))
        #expect(TransitionScene(de: d, vers: d, a: 0) == nil)
        var a = d
        a.liens["l"]?.qualite = 3
        #expect(TransitionScene(de: d, vers: a, a: 0) == nil, "la qualite d'un lien")
        a.pieces["q"] = Self.piece(x: 6)
        #expect(TransitionScene(de: d, vers: a, a: 0, reduire: true) == nil, "« Reduire les animations »")
        let t = try #require(TransitionScene(de: d, vers: a, a: 0))
        #expect(Set(t.depart.pieces.keys) == ["q"] && Set(t.arrivee.pieces.keys) == ["q"] && t.depart.liens.isEmpty)
        var s = d
        s.pieces["p"]?.opacite = 0.4
        let fondu = try #require(TransitionScene(de: s, vers: d, a: 0), "une opacite en route change aussi")
        #expect(abs((fondu.poses(a: 0.15).pieces["p"]?.opacite ?? -1) - 0.7) < 1e-9 && fondu.poses(a: 0.3).pieces["p"]?.opacite == 1)
    }

    /// Une nouvelle disposition pendant un glissement repart de la pose affichee, sans saut : a l'instant de
    /// l'interruption, les poses de la nouvelle transition sont celles qui etaient affichees, places et opacites, y
    /// compris ce qui apparaissait encore et ce qui s'effacait ; puis elles vont a la nouvelle arrivee.
    @Test func interruption() throws {
        var p0 = PosesScene(), p1 = PosesScene(), p2 = PosesScene()
        p0.pieces["p"] = Self.piece(x: 0)
        p0.pieces["part"] = Self.piece(x: 3)
        p1.pieces["p"] = Self.piece(x: 10)
        p1.pieces["arrive"] = Self.piece(x: 7)
        p2.pieces["p"] = Self.piece(x: -10)
        p2.pieces["arrive"] = Self.piece(x: 7)
        let t1 = try #require(TransitionScene(de: p0, vers: p1, a: 0))
        let affichee = p1.recouvertes(par: t1.poses(a: 0.1))
        let t2 = try #require(TransitionScene(de: affichee, vers: p2, a: 0.1))
        let avant = t1.poses(a: 0.1), apres = t2.poses(a: 0.1)
        for k in ["p", "part", "arrive"] {
            #expect(apres.pieces[k] == avant.pieces[k], "\(k) : pas de saut")
        }
        #expect(abs((avant.pieces["arrive"]?.opacite ?? -1) - 1.0 / 3) < 1e-9 && (Self.x(avant.pieces["p"]) ?? 0) > 0)
        #expect(t2.poses(a: 1).pieces["p"] == p2.pieces["p"] && t2.poses(a: 0.4).pieces["arrive"]?.opacite == 1)
        #expect(t2.poses(a: 0.4).pieces["part"]?.opacite == 0, "ce qui s'effacait finit de s'effacer")
        #expect(p1.recouvertes(par: PosesScene()) == p1)
    }

    /// Un noeud qui change de plateau va en ligne droite, d'un etage a l'autre, en 2D comme en 3D : ses ancres, melangees,
    /// donnent a chaque instant le point du segment entre ses deux places dans le monde.
    @Test(arguments: [0.0, 1.0]) func dUnPlateauALAutre(t: Double) throws {
        let g = GeometrieMaison(rayons: [5, 4])
        let plateaux = ["a": 0, "b": 1]
        let da = [A(plateau: "a", place: SIMD2(1, -2))], ab = [A(plateau: "b", place: SIMD2(-1, 3))]
        let w0 = try #require(PosesScene.centre(da, geometrie: g, plateaux: plateaux, t: t))
        let w1 = try #require(PosesScene.centre(ab, geometrie: g, plateaux: plateaux, t: t))
        #expect(simd_distance(w0, w1) > 4)
        if t == 1 { #expect(w1.y - w0.y > 4, "d'un etage a l'autre") }
        for e in [0.25, 0.5, 0.75] {
            let m = try #require(PosesScene.centre(PosesScene.melange(da, ab, e), geometrie: g, plateaux: plateaux, t: t))
            #expect(simd_distance(m, w0 + (w1 - w0) * e) < 1e-9, "a \(e) du chemin, sur le segment")
        }
    }

    /// Le melange : a 0 et a 1, exactement les ancres d'un cote ; deux ancres du meme plateau n'en font qu'une, a la
    /// moyenne ponderee ; une ancre sur un plateau absent ne compte pas, et sans aucune, pas de centre.
    @Test func melange() throws {
        let a = [A(plateau: "a", place: SIMD2(0, 0))], b = [A(plateau: "a", place: SIMD2(8, 4))]
        #expect(PosesScene.melange(a, b, 0) == a && PosesScene.melange(a, b, 1) == b)
        let m = PosesScene.melange(a, b, 0.25)
        #expect(m.count == 1 && m[0].plateau == "a" && abs(m[0].poids - 1) < 1e-12)
        #expect(simd_distance(m[0].place, SIMD2(2, 1)) < 1e-12)
        let deux = PosesScene.melange(a, [A(plateau: "b", place: SIMD2(8, 4))], 0.25)
        #expect(deux.map(\.plateau) == ["a", "b"] && abs(deux[0].poids - 0.75) < 1e-12 && abs(deux[1].poids - 0.25) < 1e-12)
        let g = GeometrieMaison(rayons: [5, 4])
        let seul = PosesScene.centre(deux, geometrie: g, plateaux: ["a": 0], t: 0)
        let centreA = try #require(PosesScene.centre(a, geometrie: g, plateaux: ["a": 0], t: 0))
        #expect(simd_distance(try #require(seul), centreA) < 1e-12, "le plateau absent ne compte pas")
        #expect(PosesScene.centre(deux, geometrie: g, plateaux: [:], t: 0) == nil)
        let c = PosesScene.centre(a, geometrie: g, plateaux: ["a": 1], t: 0)
        #expect(c == SIMD3(g.centres2D[1].x, 0, g.centres2D[1].y), "l'ancre suit son plateau, par sa cle")
    }

    /// Une piece qu'on prend pour la glisser, et ses noeuds : ils ne glissent plus.
    @Test func oublier() throws {
        var d = PosesScene(), a = PosesScene()
        d.pieces["p"] = Self.piece(x: 0)
        a.pieces["p"] = Self.piece(x: 4)
        d.noeuds["n"] = Self.noeud("a", x: 0)
        a.noeuds["n"] = Self.noeud("a", x: 4)
        d.pieces["q"] = Self.piece(x: 1)
        a.pieces["q"] = Self.piece(x: 2)
        var t = try #require(TransitionScene(de: d, vers: a, a: 0))
        t.oublier(pieces: ["p"], noeuds: ["n"])
        let p = t.poses(a: 0.45)
        #expect(p.pieces["p"] == nil && p.noeuds["n"] == nil && p.pieces["q"] != nil)
    }

    /// Les poses d'une scene posee : chaque piece a sa place, sur son plateau, de la taille de sa carte, opaque ; chaque
    /// noeud a sa place dans sa carte ; chaque lien.
    @Test func posesDUneScene() throws {
        let (s, c, d, _) = try SceneProjeteeTests.scene()
        let p = PosesScene(scene: s, cartes: c, positions: d.positions)
        #expect(p.pieces.count == s.pieces.count && p.noeuds.count == s.noeuds.count && p.liens.count == s.liens.count)
        let bureau = try SceneProjeteeTests.indice(s, "Bureau")
        let pose = try #require(p.pieces["piece:Bureau"])
        #expect(pose.ancres == [A(plateau: "zone:Étage", place: d.positions[bureau])] && pose.opacite == 1)
        #expect(pose.taille == SIMD2(c[bureau].largeur, c[bureau].profondeur) && pose.teinte == s.pieces[bureau].teinte)
        let r = try #require(s.pieces[bureau].noeuds.firstIndex(of: "E000000000000003"))
        let n = try #require(p.noeuds["E000000000000003"])
        #expect(n.ancres == pose.ancres && n.decalage == c[bureau].places[r] && n.rayon == 7)
    }

    /// La scene projetee prend les poses : posee, une pose ne change rien, au bit pres ; une piece et un noeud en route
    /// sont a leur pose ; un noeud qui change de piece, et d'etage, en ligne droite ; l'opacite d'un fondu.
    @Test func sceneProjeteeEnRoute() throws {
        let (s, c, d, g) = try SceneProjeteeTests.scene()
        let e = EtatAnime(t: 1, fk: Array(repeating: 0, count: s.pieces.count))
        let o = CameraScene.canonique(g, aspect: 1.5, u: 1)
        func projeter(_ poses: PosesScene, scene: ScenePieces? = nil, positions: [SIMD2<Double>]? = nil) -> SceneProjetee {
            SceneProjetee(scene: scene ?? s, cartes: c, positions: positions ?? d.positions, geometrie: g, etat: e, orbite: o,
                          cadre: SceneProjeteeTests.cadre, poses: poses)
        }
        let sans = projeter(PosesScene()), posee = projeter(PosesScene(scene: s, cartes: c, positions: d.positions))
        #expect(posee.centresNoeuds == sans.centresNoeuds && posee.ancresPieces == sans.ancresPieces)
        #expect(posee.disques.map(\.opacite) == sans.disques.map(\.opacite) && posee.fantomes.isEmpty)
        // Le bureau glisse de 2 sur x, ses noeuds avec lui ; E...03 passe au salon, a mi-chemin.
        let bureau = try SceneProjeteeTests.indice(s, "Bureau"), salon = try SceneProjeteeTests.indice(s, "Salon")
        let arrivee = PosesScene(scene: s, cartes: c, positions: d.positions)
        var depart = arrivee
        depart.pieces["piece:Bureau"]?.ancres[0].place.x -= 2
        depart.noeuds["E000000000000003"] = PosesScene.Noeud(ancres: [A(plateau: "zone:Rez-de-chaussée", place: d.positions[salon])],
                                                         decalage: .zero, rayon: 7)
        let t = try #require(TransitionScene(de: depart, vers: arrivee, a: 0))
        let mi = projeter(t.poses(a: 0.45))
        let ici = try #require(sans.ancresPieces[bureau]), la = try #require(mi.ancresPieces[bureau])
        #expect(ici != la, "le bureau, en route")
        let w0 = SIMD3(g.centrePlateau(0, 1).x + d.positions[salon].x, g.centrePlateau(0, 1).y + 0.1 + 1.22,
                       g.centrePlateau(0, 1).z + d.positions[salon].y)
        let w1 = try #require(sans.centresNoeuds["E000000000000003"])
        let w = try #require(mi.centresNoeuds["E000000000000003"])
        #expect(simd_distance(w, (w0 + w1) / 2) < 1e-9 && w1.y - w0.y > 4, "d'un etage a l'autre, en ligne droite")
        let e02 = try #require(mi.centresNoeuds["E000000000000002"]), e02Posee = try #require(sans.centresNoeuds["E000000000000002"])
        #expect(abs((e02Posee.x - e02.x) - 1) < 1e-9 && abs(e02Posee.z - e02.z) < 1e-9,
                "le bureau, a mi-chemin, 1 unite avant sa place ; un noeud du bureau suit sa piece")
        // Un fondu : la pastille et le bloc a l'opacite de la pose ; les liens aussi.
        var f = PosesScene()
        f.pieces["piece:Salon"] = arrivee.pieces["piece:Salon"]
        f.pieces["piece:Salon"]?.opacite = 0.5
        f.noeuds["HomePod"] = arrivee.noeuds["HomePod"]
        f.noeuds["HomePod"]?.opacite = 0.25
        let radio = try #require(s.liens.first { $0.genre == .radio })
        f.liens[PosesScene.cle(radio)] = PosesScene.Lien(radio, opacite: 0.5)
        let fondu = projeter(f)
        let blocSalon = try #require(fondu.blocs.first { $0.piece == salon }), blocSans = try #require(sans.blocs.first { $0.piece == salon })
        #expect(abs(blocSalon.opaciteVerre - blocSans.opaciteVerre * 0.5) < 1e-12 && abs(blocSalon.opaciteAretes - 0.375) < 1e-12)
        #expect(fondu.disques.first { $0.noeud == "HomePod" }?.opacite == 0.25)
        #expect(fondu.liensRouteurs.contains { abs($0.opacite - 0.475) < 1e-12 } && fondu.liensRouteurs.count == sans.liensRouteurs.count)
    }

    /// Ce qui s'efface, absent de la scene, se dessine a sa derniere place, a son opacite : une piece (son bloc, sans
    /// ancre de nom, et qui ne se clique pas), un noeud (sa pastille, sans nom, qui ne se clique pas), un lien entre les
    /// places de ses bouts. Un element sur un plateau absent ne se dessine pas.
    @Test func ceQuiSEfface() throws {
        let (s, c, d, g) = try SceneProjeteeTests.scene()
        let e = EtatAnime(t: 0, fk: Array(repeating: 0, count: s.pieces.count))
        let o = CameraScene.canonique(g, aspect: 1.5, u: 0)
        var f = PosesScene()
        f.pieces["piece:Garage"] = PosesScene.Piece(ancres: [A(plateau: "zone:Étage", place: SIMD2(0, 0))],
                                                    taille: SIMD2(3, 3), teinte: 2, opacite: 0.6)
        f.pieces["piece:Ailleurs"] = PosesScene.Piece(ancres: [A(plateau: "zone:Absente", place: .zero)],
                                                      taille: SIMD2(3, 3), teinte: 2, opacite: 0.6)
        f.noeuds["E000000000000009"] = PosesScene.Noeud(ancres: [A(plateau: "zone:Étage", place: SIMD2(0, 0))],
                                                        decalage: .zero, rayon: 7, opacite: 0.8)
        let parti = GrapheReseau.Lien(de: "E000000000000009", vers: "HomePod", genre: .radio, qualite: 1)
        f.liens[PosesScene.cle(parti)] = PosesScene.Lien(parti, opacite: 0.4)
        let sans = SceneProjetee(scene: s, cartes: c, positions: d.positions, geometrie: g, etat: e, orbite: o,
                                 cadre: SceneProjeteeTests.cadre)
        let p = SceneProjetee(scene: s, cartes: c, positions: d.positions, geometrie: g, etat: e, orbite: o,
                              cadre: SceneProjeteeTests.cadre, poses: f)
        let fantome = try #require(p.blocs.first { $0.piece == -1 })
        #expect(p.blocs.count == sans.blocs.count + 1 && abs(fantome.opaciteVerre - 0.6 * 0.13) < 1e-12)
        #expect(p.ancresPieces.count == sans.ancresPieces.count)
        let dessus = SceneProjetee.boite(fantome.faces[0].points)
        #expect(p.piece(sous: CGPoint(x: dessus.midX, y: dessus.midY)) != -1)
        let disque = try #require(p.disques.first { $0.noeud == "E000000000000009" })
        #expect(disque.opacite == 0.8 && p.fantomes == ["E000000000000009"] && p.ancresNoeuds["E000000000000009"] == nil)
        #expect(p.noeud(sous: disque.centre, marge: 0) != "E000000000000009")
        #expect(p.liensRouteurs.count == sans.liensRouteurs.count + 1 && p.liensRouteurs.contains { abs($0.opacite - 0.38) < 1e-12 })
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/TransitionSceneTests MaillageCoeurTests/SceneProjeteeTests`
Expected: la compilation des tests échoue (`TransitionSceneTests.swift`), par exemple avec `error: cannot find type 'PosesScene' in scope` et `error: cannot find 'PosesScene' in scope` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
    public var centresNoeuds: [String: SIMD3<Double>] = [:]
```

par :

```swift
    public var centresNoeuds: [String: SIMD3<Double>] = [:]
    /// Noeuds qui s'effacent pendant une transition (polissage D, section 1) : absents de la scene, ils ne se cliquent
    /// pas et n'ont pas de nom.
    public var fantomes: Set<String> = []
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
    /// de `scene`, et `g.rayons` ses etages, memes effectifs et meme ordre.
    public init(scene: ScenePieces, cartes: [CartesPieces.Carte], positions: [SIMD2<Double>], geometrie g: GeometrieMaison,
                etat: EtatAnime, orbite: Orbite, cadre: CGRect) {
```

par :

```swift
    /// de `scene`, et `g.rayons` ses etages, memes effectifs et meme ordre. `poses` : ce qui est en transition
    /// (polissage D, section 1), par cle, qui l'emporte sur la disposition ; ce qui s'efface, absent de la scene, s'y
    /// dessine aussi, a sa derniere place, sans se cliquer.
    public init(scene: ScenePieces, cartes: [CartesPieces.Carte], positions: [SIMD2<Double>], geometrie g: GeometrieMaison,
                etat: EtatAnime, orbite: Orbite, cadre: CGRect, poses: PosesScene = PosesScene()) {
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        // Pieces : blocs de verre ; noeuds a mi-hauteur de leur bloc en 3D.
```

par :

```swift
        // Pieces : blocs de verre ; noeuds a mi-hauteur de leur bloc en 3D. Une piece ou un noeud en transition prend
        // sa pose ; une piece qui s'efface, absente de la scene, se dessine a sa derniere place (`piece` -1).
        let plateaux = Dictionary(scene.etages.indices.map { (scene.etages[$0].id, $0) }, uniquingKeysWith: { a, _ in a })
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        for (i, pc) in scene.pieces.enumerated() where i < cartes.count && i < positions.count {
            let c = g.centrePlateau(pc.etage, t)
            let fe = CameraScene.rampe(i < etat.fk.count ? etat.fk[i] : 0)
            let voile = 1 - es * (1 - fe), f = 1 + 0.3 * fe
            voiles[i] = voile
            echelles[i] = f
            let vis = min(1 - 0.85 * (1 - voile), pc.etage < ve.count ? ve[pc.etage] : 1)
            let bx = c.x + positions[i].x, bz = c.z + positions[i].y
            let y0 = c.y + 0.02, y1 = y0 + h
            let x0 = bx - cartes[i].largeur * f / 2, x1 = bx + cartes[i].largeur * f / 2
            let z0 = bz - cartes[i].profondeur * f / 2, z1 = bz + cartes[i].profondeur * f / 2
            centres[i] = SIMD3(bx, (y0 + y1) / 2, bz)
            let k: [SIMD3<Double>] = [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1],
                                      [x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]]
            let teinte = Teinte(hexa: ScenePieces.teintes[pc.teinte % ScenePieces.teintes.count])
```

par :

```swift
        var apparitions: [String: Double] = [:]
        func bloc(_ i: Int, centre m: SIMD3<Double>, taille: SIMD2<Double>, f: Double, teinte n: Int, vis: Double) {
            let bx = m.x, bz = m.z
            let y0 = m.y + 0.02, y1 = y0 + h
            let x0 = bx - taille.x * f / 2, x1 = bx + taille.x * f / 2
            let z0 = bz - taille.y * f / 2, z1 = bz + taille.y * f / 2
            let centre = SIMD3(bx, (y0 + y1) / 2, bz)
            if i >= 0 { centres[i] = centre }
            let k: [SIMD3<Double>] = [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1],
                                      [x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]]
            let teinte = Teinte(hexa: ScenePieces.teintes[n % ScenePieces.teintes.count])
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
                              opaciteAretes: vis * 0.75, profondeur: proj.profondeur(centres[i])))
            let coins = k.compactMap { proj.ecran($0) }
            if coins.count == 8 { ancresPieces[i] = Self.boite(coins) }
            for (r, id) in pc.noeuds.enumerated() where r < cartes[i].places.count {
                let l = cartes[i].places[r]
                mondes[id] = SIMD3(bx + l.x * f, c.y + 0.1 + 0.5 * h * t, bz + l.y * f)
            }
```

par :

```swift
                              opaciteAretes: vis * 0.75, profondeur: proj.profondeur(centre)))
            let coins = k.compactMap { proj.ecran($0) }
            if i >= 0, coins.count == 8 { ancresPieces[i] = Self.boite(coins) }
        }
        // Un noeud en transition : le centre de sa piece, puis sa place dans la carte, a l'echelle `f`.
        func monde(_ n: PosesScene.Noeud, f: Double) -> SIMD3<Double>? {
            guard let c = PosesScene.centre(n.ancres, geometrie: g, plateaux: plateaux, t: t) else { return nil }
            return SIMD3(c.x + n.decalage.x * f, c.y + 0.1 + 0.5 * h * t, c.z + n.decalage.y * f)
        }
        for (i, pc) in scene.pieces.enumerated() where i < cartes.count && i < positions.count {
            let c = g.centrePlateau(pc.etage, t)
            let fe = CameraScene.rampe(i < etat.fk.count ? etat.fk[i] : 0)
            let voile = 1 - es * (1 - fe), f = 1 + 0.3 * fe
            voiles[i] = voile
            echelles[i] = f
            var vis = min(1 - 0.85 * (1 - voile), pc.etage < ve.count ? ve[pc.etage] : 1)
            var m = SIMD3(c.x + positions[i].x, c.y, c.z + positions[i].y)
            var taille = SIMD2(cartes[i].largeur, cartes[i].profondeur)
            if let pose = poses.pieces[pc.id], let centre = PosesScene.centre(pose.ancres, geometrie: g, plateaux: plateaux, t: t) {
                m = centre
                taille = pose.taille
                vis *= pose.opacite
            }
            bloc(i, centre: m, taille: taille, f: f, teinte: pc.teinte, vis: vis)
            for (r, id) in pc.noeuds.enumerated() where r < cartes[i].places.count {
                if let n = poses.noeuds[id] {
                    apparitions[id] = n.opacite
                    if let w = monde(n, f: f) {
                        mondes[id] = w
                        continue
                    }
                }
                let l = cartes[i].places[r]
                mondes[id] = SIMD3(m.x + l.x * f, m.y + 0.1 + 0.5 * h * t, m.z + l.y * f)
            }
        }
        let presentes = Set(scene.pieces.map(\.id))
        for (k, pose) in poses.pieces.sorted(by: { $0.key < $1.key }) where !presentes.contains(k) {
            guard let centre = PosesScene.centre(pose.ancres, geometrie: g, plateaux: plateaux, t: t) else { continue }
            bloc(-1, centre: centre, taille: pose.taille, f: 1, teinte: pose.teinte, vis: pose.opacite)
        }
        for (id, n) in poses.noeuds where scene.noeud(id) == nil {
            guard let w = monde(n, f: 1) else { continue }
            mondes[id] = w
            fantomes.insert(id)
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
                                  opacite: min(1 - 0.8 * (1 - voiles[n.piece]), voileEtage(n.piece)),
                                  profondeur: proj.profondeur(p)))
            ancresNoeuds[n.id] = CGRect(x: Double(e.x) - r, y: Double(e.y) - r, width: 2 * r, height: 2 * r)
```

par :

```swift
                                  opacite: min(1 - 0.8 * (1 - voiles[n.piece]), voileEtage(n.piece)) * (apparitions[n.id] ?? 1),
                                  profondeur: proj.profondeur(p)))
            ancresNoeuds[n.id] = CGRect(x: Double(e.x) - r, y: Double(e.y) - r, width: 2 * r, height: 2 * r)
        }
        for id in fantomes.sorted() {
            guard let n = poses.noeuds[id], let p = mondes[id], let e = proj.ecran(p) else { continue }
            let r = min(n.rayon * 1.1, max(3, n.rayon * proj.pxParUnite(p) / CartesPieces.px))
            disques.append(Disque(noeud: id, centre: e, rayon: r, opacite: n.opacite, profondeur: proj.profondeur(p)))
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
            if l.genre == .radio {
                liensRouteurs.append(Lien(a: pa, b: pb, genre: .radio, qualite: l.qualite, opacite: 0.95 * poids,
                                          eclaire: eclaire))
            } else {
                liensEnfants.append(Lien(a: pa, b: pb, genre: l.genre, qualite: l.qualite,
                                         opacite: eclaire ? 0.85 : 0.28 * poids, eclaire: eclaire))
```

par :

```swift
            let fondu = poses.liens[PosesScene.cle(l)]?.opacite ?? 1
            if l.genre == .radio {
                liensRouteurs.append(Lien(a: pa, b: pb, genre: .radio, qualite: l.qualite, opacite: 0.95 * poids * fondu,
                                          eclaire: eclaire))
            } else {
                liensEnfants.append(Lien(a: pa, b: pb, genre: l.genre, qualite: l.qualite,
                                         opacite: (eclaire ? 0.85 : 0.28 * poids) * fondu, eclaire: eclaire))
            }
        }
        // Les liens qui s'effacent, absents de la scene, entre les places affichees de leurs bouts.
        let presents = Set(scene.liens.map(PosesScene.cle))
        for (k, l) in poses.liens.sorted(by: { $0.key < $1.key }) where !presents.contains(k) {
            guard let a = mondes[l.de], let b = mondes[l.vers], let (pa, pb) = proj.segment(a, b) else { continue }
            if l.genre == .radio {
                liensRouteurs.append(Lien(a: pa, b: pb, genre: .radio, qualite: l.qualite, opacite: 0.95 * l.opacite,
                                          eclaire: false))
            } else {
                liensEnfants.append(Lien(a: pa, b: pb, genre: l.genre, qualite: l.qualite, opacite: 0.28 * l.opacite,
                                         eclaire: false))
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        blocs.reversed().first { b in b.faces.contains { Self.contient($0.points, p) } }?.piece
```

par :

```swift
        blocs.reversed().first { b in b.piece >= 0 && b.faces.contains { Self.contient($0.points, p) } }?.piece
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        for d in disques where d.opacite > 0.5 {
```

par :

```swift
        for d in disques where d.opacite > 0.5 && !fantomes.contains(d.noeud) {
```

`MaillageCoeur/Scene/TransitionScene.swift` (fichier entier) :

```swift
import Foundation
import simd

/// Les poses d'une scene, par cle (polissage D, section 1) : chaque piece (son centre sur son plateau, la taille de sa
/// carte, sa teinte), chaque noeud (le centre de sa piece et sa place dans la carte, le rayon de sa pastille) et chaque
/// lien, avec leur opacite. Une place est une ancre sur un plateau, par la cle du plateau : la geometrie du moment la
/// pose dans le monde, en 2D comme en 3D, pendant que les plateaux glissent ou que la vue bascule. Une pose en route
/// d'un plateau a un autre est la moyenne ponderee de ses ancres ; posee, elle n'en a qu'une, de poids 1.
public struct PosesScene: Hashable, Sendable {
    public struct Ancre: Hashable, Sendable {
        public var plateau: String
        public var place: SIMD2<Double>
        public var poids: Double

        public init(plateau: String, place: SIMD2<Double>, poids: Double = 1) {
            self.plateau = plateau
            self.place = place
            self.poids = poids
        }
    }

    public struct Piece: Hashable, Sendable {
        public var ancres: [Ancre]
        /// Largeur (x) et profondeur (z) de sa carte, en unites.
        public var taille: SIMD2<Double>
        public var teinte: Int
        public var opacite: Double

        public init(ancres: [Ancre], taille: SIMD2<Double>, teinte: Int, opacite: Double = 1) {
            self.ancres = ancres
            self.taille = taille
            self.teinte = teinte
            self.opacite = opacite
        }
    }

    public struct Noeud: Hashable, Sendable {
        /// Le centre de sa piece.
        public var ancres: [Ancre]
        /// Sa place dans la carte de sa piece, par rapport a son centre, en unites.
        public var decalage: SIMD2<Double>
        /// Rayon naturel de sa pastille (px).
        public var rayon: Double
        public var opacite: Double

        public init(ancres: [Ancre], decalage: SIMD2<Double>, rayon: Double, opacite: Double = 1) {
            self.ancres = ancres
            self.decalage = decalage
            self.rayon = rayon
            self.opacite = opacite
        }
    }

    public struct Lien: Hashable, Sendable {
        public var de: String
        public var vers: String
        public var genre: GrapheReseau.Lien.Genre
        public var qualite: Int?
        public var opacite: Double

        public init(_ l: GrapheReseau.Lien, opacite: Double = 1) {
            de = l.de
            vers = l.vers
            genre = l.genre
            qualite = l.qualite
            self.opacite = opacite
        }
    }

    public var pieces: [String: Piece] = [:]
    public var noeuds: [String: Noeud] = [:]
    public var liens: [String: Lien] = [:]

    public init() {}

    /// Les poses de `scene` posee : chaque piece a sa place (`positions`), de la taille de sa carte (`cartes`) ; chaque
    /// noeud a sa place dans la carte de sa piece ; chaque lien. Tout est opaque.
    public init(scene: ScenePieces, cartes: [CartesPieces.Carte], positions: [SIMD2<Double>]) {
        for (i, p) in scene.pieces.enumerated() where i < cartes.count && i < positions.count && p.etage < scene.etages.count {
            let ancres = [Ancre(plateau: scene.etages[p.etage].id, place: positions[i])]
            pieces[p.id] = Piece(ancres: ancres, taille: SIMD2(cartes[i].largeur, cartes[i].profondeur), teinte: p.teinte)
            for (r, id) in p.noeuds.enumerated() where r < cartes[i].places.count {
                noeuds[id] = Noeud(ancres: ancres, decalage: cartes[i].places[r], rayon: scene.noeud(id)?.rayon ?? 7)
            }
        }
        for l in scene.liens { liens[Self.cle(l)] = Lien(l) }
    }

    /// Cle d'un lien : ses deux bouts et son genre ; sa qualite peut changer sans en faire un autre.
    public static func cle(_ l: GrapheReseau.Lien) -> String {
        l.de + ">" + l.vers + ">" + l.genre.rawValue
    }

    /// Ces poses, recouvertes par `autres` : la pose affichee d'une scene, celles en transition l'emportant.
    public func recouvertes(par autres: PosesScene) -> PosesScene {
        var r = self
        r.pieces.merge(autres.pieces) { _, b in b }
        r.noeuds.merge(autres.noeuds) { _, b in b }
        r.liens.merge(autres.liens) { _, b in b }
        return r
    }

    /// Le centre dans le monde d'ancres, sur la geometrie `g` a l'avancement `t` de la bascule : la moyenne, ponderee,
    /// du centre de chaque plateau plus sa place ; `plateaux` : l'indice de chaque plateau de `g`, par cle. Une ancre
    /// sur un plateau absent ne compte pas ; nil sans aucune.
    public static func centre(_ ancres: [Ancre], geometrie g: GeometrieMaison, plateaux: [String: Int],
                              t: Double) -> SIMD3<Double>? {
        var somme = SIMD3<Double>.zero, poids = 0.0
        for a in ancres {
            guard let e = plateaux[a.plateau], e < g.rayons.count else { continue }
            let c = g.centrePlateau(e, t)
            somme += SIMD3(c.x + a.place.x, c.y, c.z + a.place.y) * a.poids
            poids += a.poids
        }
        return poids > 0 ? somme / poids : nil
    }

    /// Le melange de deux poses d'ancres, a `e` du chemin de `a` a `b` : chaque ancre garde son plateau, son poids
    /// multiplie par 1 - e (celles de `a`) ou par e (celles de `b`) ; deux ancres du meme plateau n'en font qu'une, a la
    /// moyenne ponderee de leurs places. A 0, les ancres de `a` ; a 1, celles de `b`, exactement.
    public static func melange(_ a: [Ancre], _ b: [Ancre], _ e: Double) -> [Ancre] {
        if e <= 0 { return a }
        if e >= 1 { return b }
        var r: [Ancre] = []
        for x in a.map({ Ancre(plateau: $0.plateau, place: $0.place, poids: $0.poids * (1 - e)) })
            + b.map({ Ancre(plateau: $0.plateau, place: $0.place, poids: $0.poids * e) }) where x.poids > 0 {
            if let k = r.firstIndex(where: { $0.plateau == x.plateau }) {
                let w = r[k].poids + x.poids
                r[k].place = (r[k].place * r[k].poids + x.place * x.poids) / w
                r[k].poids = w
            } else {
                r.append(x)
            }
        }
        return r
    }
}

/// Le glissement d'une disposition a l'autre (polissage D, section 1) : de la pose affichee a la pose nouvelle, chaque
/// piece (son centre et sa taille) et chaque noeud (sa place dans le monde) glisse en 0,9 s, en cubique entree-sortie ;
/// un element present d'un seul cote apparait ou s'efface en fondu de 0,3 s, a sa place ; un lien suit ses bouts. Elle
/// ne garde que ce qui change : le reste est pose. Une nouvelle disposition pendant le glissement repart de la pose
/// affichee (`PosesScene.recouvertes`), sans saut. Avec « Reduire les animations », pas de transition : tout est
/// immediat, sans fondu.
public struct TransitionScene: Hashable, Sendable {
    /// Le glissement, celui des changements de niveau de C (`CameraScene.dureeNiveaux`).
    public static let duree = 0.9
    /// Les apparitions et les disparitions.
    public static let dureeFondu = 0.3

    /// Les poses de depart et d'arrivee, de ce qui change seulement.
    public var depart: PosesScene
    public var arrivee: PosesScene
    public var debut: Double

    /// La transition de `affichee`, la pose affichee de la scene d'avant, a `arrivee`, la nouvelle, depuis l'instant
    /// `debut` ; nil si rien ne change, ou avec « Reduire les animations ».
    public init?(de affichee: PosesScene, vers arrivee: PosesScene, a debut: Double, reduire: Bool = false) {
        guard !reduire else { return nil }
        var d = PosesScene(), a = PosesScene()
        for k in Set(affichee.pieces.keys).union(arrivee.pieces.keys) where affichee.pieces[k] != arrivee.pieces[k] {
            d.pieces[k] = affichee.pieces[k]
            a.pieces[k] = arrivee.pieces[k]
        }
        for k in Set(affichee.noeuds.keys).union(arrivee.noeuds.keys) where affichee.noeuds[k] != arrivee.noeuds[k] {
            d.noeuds[k] = affichee.noeuds[k]
            a.noeuds[k] = arrivee.noeuds[k]
        }
        for k in Set(affichee.liens.keys).union(arrivee.liens.keys) where affichee.liens[k]?.opacite != arrivee.liens[k]?.opacite {
            d.liens[k] = affichee.liens[k]
            a.liens[k] = arrivee.liens[k]
        }
        guard d != PosesScene() || a != PosesScene() else { return nil }
        depart = d
        self.arrivee = a
        self.debut = debut
    }

    /// Le glissement est fini a l'instant `now`.
    public func finie(a now: Double) -> Bool { now - debut >= Self.duree }

    /// Les poses de ce qui change, a l'instant `now` : en route en cubique entree-sortie ; l'opacite en route, en 0,3 s,
    /// vers 1 pour ce qui arrive, vers 0 pour ce qui part, depuis celle du depart (une transition interrompue).
    public func poses(a now: Double) -> PosesScene {
        let e = CameraScene.rampe(min(1, max(0, (now - debut) / Self.duree)))
        let f = min(1, max(0, (now - debut) / Self.dureeFondu))
        func opacite(_ o0: Double?, _ o1: Double?) -> Double {
            let a = o0 ?? 0, b = o1 == nil ? 0 : 1.0
            return a + (b - a) * f
        }
        var r = PosesScene()
        for k in Set(depart.pieces.keys).union(arrivee.pieces.keys) {
            let d = depart.pieces[k], a = arrivee.pieces[k]
            guard var p = a ?? d else { continue }
            if let d, let a {
                p.ancres = PosesScene.melange(d.ancres, a.ancres, e)
                p.taille = d.taille + (a.taille - d.taille) * e
            }
            p.opacite = opacite(d?.opacite, a?.opacite)
            r.pieces[k] = p
        }
        for k in Set(depart.noeuds.keys).union(arrivee.noeuds.keys) {
            let d = depart.noeuds[k], a = arrivee.noeuds[k]
            guard var n = a ?? d else { continue }
            if let d, let a {
                n.ancres = PosesScene.melange(d.ancres, a.ancres, e)
                n.decalage = d.decalage + (a.decalage - d.decalage) * e
                n.rayon = d.rayon + (a.rayon - d.rayon) * e
            }
            n.opacite = opacite(d?.opacite, a?.opacite)
            r.noeuds[k] = n
        }
        for k in Set(depart.liens.keys).union(arrivee.liens.keys) {
            guard var l = arrivee.liens[k] ?? depart.liens[k] else { continue }
            l.opacite = opacite(depart.liens[k]?.opacite, arrivee.liens[k]?.opacite)
            r.liens[k] = l
        }
        return r
    }

    /// Ces pieces et ces noeuds ne glissent plus : poses, a leur place d'arrivee (une piece que Djoko prend pour la
    /// glisser, et ses noeuds).
    public mutating func oublier(pieces: Set<String>, noeuds: Set<String>) {
        for k in pieces {
            depart.pieces[k] = nil
            arrivee.pieces[k] = nil
        }
        for k in noeuds {
            depart.noeuds[k] = nil
            arrivee.noeuds[k] = nil
        }
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/TransitionSceneTests MaillageCoeurTests/SceneProjeteeTests`
Expected: `Test run with 18 tests in 2 suites passed` (cœur), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh`
Expected: `Test run with 389 tests in 40 suites passed` (cœur) et `Test run with 347 tests in 30 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 10 tests de plus et 1 suite pour le cœur, l'app inchangée.

- [ ] **Step 6 : les images de démo, identiques.** Comparées à celles de la tâche 1 : identiques, octet pour octet. Si une image diffère, s'arrêter : la tâche a changé le rendu. Les images se rendent toujours juste après la suite du step précédent, avec l'app qu'elle vient de compiler.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t2"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "maillage-polD/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
for f in $(ls "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t1"); do cmp -s "$D/$f" "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t1/$f" && echo "$f identique" || echo "$f differe"; done | sort | awk '{print $2}' | uniq -c
```

Expected : 20 ; « l'app a quitté » ; « 20 identique ».

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Scene/SceneProjetee.swift MaillageCoeur/Scene/TransitionScene.swift MaillageCoeurTests/TransitionSceneTests.swift
git commit -m "Ecrire dans le coeur la transition d'une disposition a l'autre : les poses par cle, le glissement en 0,9 s, les fondus de 0,3 s, l'interruption sans saut, et la scene projetee qui les prend

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Mutants essayés sur la copie validée** (chacun appliqué seul, la tâche jouée par ses tests ; un mutant qui ne compilait pas a été rejoué sous une forme qui compile, sauf pour le découpage, où la compilation est l'attente) :

21 mutants, tous tués par `TransitionSceneTests` : une rampe linéaire ; une durée de 1 s ; le fondu sur la durée du glissement ; l'opacité de départ ignorée ; la taille qui ne glisse pas ; « Réduire » ignoré ; tout gardé dans la transition ; le mélange sans fusion des ancres ; le centre sans les poids ; une ancre sur un plateau absent comptée ; `oublier` sans les nœuds ; un lien dont seule la qualité change mis en transition ; le décalage dans la carte qui ne glisse pas ; dans la projection, l'opacité d'une pièce ignorée, un bloc ou une pastille qui s'efface cliquable, l'apparition d'un nœud ignorée, le fondu des liens ignoré, les liens qui s'effacent oubliés, un nœud en route placé par sa pièce, un bloc qui s'efface opaque.

### Task 3: Le glissement dans le moteur : chaque nouvelle disposition glisse, la vue suit ce qu'elle regarde, la grille rechoisie quand les rayons changent

**Files:**
- Create: `MaillageThreadTests/GlissementTests.swift`
- Modify: `MaillageThread/Vues/Pieces/MoteurPieces.swift` (blocs ci-dessous)

**Interfaces:**
- Consumes : `PosesScene`, `TransitionScene`, `SceneProjetee(…, poses:)` (tâche 2), `PolitiqueGrille` (tâche 1) ; `MoteurPieces.installer`, `viser`, `avancer`, `suivre`, `ancreCamera`, `centrePiece`, `glisser`, `doitContinuer`, existants ; dans les tests, `NomsSceneTests.demo()`, `MoteurPiecesTests.moteur`, `dessiner`, `pointDePiece`, `indice`, `attendre`, `quatrePlateaux`, `IsolementTests.sceneQuiArrive`.
- Produces :
  - `MoteurPieces.transition`, `posesAffichees` ; `poserTransition(_:)` (captures, tests) ; `reculerTransition(de:)` (tests : l'horloge de la transition) ; `centrePiece(_:dans:)` donne la pose affichée d'une pièce en route ;
  - dans les tests, `GlissementTests.demo(_:dans:)`, `demo(_:)`, `demo(_:nom:)`, `moteur(troisD:)`, `monde(_:_:)`.

**Quand** (spec, section 1 ; précision 4). À chaque scène posée, le moteur compare la pose affichée de la scène d'avant (ses poses, recouvertes par celles de la transition en cours) et la pose nouvelle : si elles diffèrent, une transition part de l'affichée. Une scène dont la disposition ne change rien (un relevé de même clé) laisse la transition en cours aller à son terme, sans la relancer. Les plateaux glissent en 0,9 s, en 2D comme en 3D, vers la géométrie de la nouvelle disposition ; après un changement de niveau, ils gardent leur glissement de C (0,4 s en 2D, 0,9 s en 3D). Un glissement de plateaux qui ne bougerait rien n'est plus créé.

**Une seule horloge** : `avancer` fait avancer la transition et la géométrie à chaque image, puis la transition s'arrête ; l'horloge ne tourne pas au repos (`doitContinuer`). Les pastilles qui s'effacent gardent leur dessin, celui de la scène d'avant.

**La vue suit ce qu'elle regarde.** `centrePiece` donne la pose affichée d'une pièce en route : la caméra d'une pièce isolée, d'un étage isolé ou d'une vue zoomée la suit, image après image (`suivre`), comme pour la grille de C ; un vol en cours rejoint l'arrivée de ce qu'il vise.

**Une pièce que Djoko prend pour la glisser** (précision 6) : si elle est en route, elle est posée à sa place, avec ses nœuds, et suit le pointeur depuis là. Glisser une pièce ne relance pas le calcul, comme avant. La disposition suivante la trouve fixée, déjà à sa place : elle n'est pas animée ; seules les autres pièces que le recalcul déplace glissent.

**La grille est rechoisie quand les rayons changent** (spec, section 4 ; précision 11) : une nouvelle disposition qui garde les niveaux mais change les rayons rechoisit les colonnes à la vue d'ensemble 2D, avec l'hystérésis de 5 % ; zoomée ou isolée, la vue attend, comme un redimensionnement (`PolitiqueGrille.redimensionnement`).

**« Réduire les animations »** : tout est immédiat.

**Les images de démo ne changent pas** : chaque image installe sa scène une seule fois.

- [ ] **Step 1 : écrire les tests.** Une nouvelle disposition qui glisse au lieu de sauter, en 2D et en 3D ; « Réduire » ; l'interruption ; la vue qui suit, par l'horloge ; la pièce glissée ; la grille rechoisie quand les rayons changent.

`MaillageThreadTests/GlissementTests.swift` (fichier entier) :

```swift
import AppKit
import Foundation
import MaillageCoeur
import simd
import SwiftUI
import Testing
@testable import MaillageThread

/// Le glissement d'une disposition a l'autre, dans le moteur (polissage D, section 1) : une nouvelle disposition glisse
/// au lieu de sauter, de la pose affichee, en 0,9 s ; les liens suivent ; une autre disposition en route repart de la
/// pose affichee ; la vue suit la piece isolee ; une piece qu'on glisse n'est pas animee ; « Reduire les animations » ;
/// la grille rechoisie quand les rayons changent (section 4).
@MainActor
@Suite("Vue par pieces : glissement d'une disposition a l'autre")
struct GlissementTests {
    /// La Prise salon de la demo (un appareil du salon, au rez-de-chaussee).
    static let prise = "7AF0B6D5006CF95F"

    /// La demo, l'accessoire `nom` place dans la piece `piece` (« Placer dans une piece… », ou Maison).
    static func demo(_ nom: String, dans piece: String) throws -> EntreeScene {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        for k in maison.accessoires.indices where maison.accessoires[k].nom == nom { maison.accessoires[k].piece = piece }
        s.noms.maison = maison
        return EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
    }

    /// La demo, chaque accessoire de `deplacer` place dans sa piece.
    static func demo(_ deplacer: [String: String]) throws -> EntreeScene {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        for k in maison.accessoires.indices {
            if let p = deplacer[maison.accessoires[k].nom] { maison.accessoires[k].piece = p }
        }
        s.noms.maison = maison
        return EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
    }

    /// La demo, l'accessoire `nom` renomme `nouveau`.
    static func demo(_ nom: String, nom nouveau: String) throws -> EntreeScene {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        for k in maison.accessoires.indices where maison.accessoires[k].nom == nom { maison.accessoires[k].nom = nouveau }
        s.noms.maison = maison
        return EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
    }

    /// Le moteur de la demo, fige (sans horloge : les etats se posent a la main), une image dessinee.
    static func moteur(troisD: Bool = false) throws -> (MoteurPieces, EntreeScene) {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces(troisD: troisD)
        m.marges = (84, 50)
        m.poserTaille(MoteurPiecesTests.taille)
        m.installerMaintenant(e)
        m.fige = true
        if troisD { m.poserBascule(1) }
        MoteurPiecesTests.dessiner(m)
        return (m, e)
    }

    /// La place d'un noeud dans le monde, a l'image.
    static func monde(_ m: MoteurPieces, _ id: String) throws -> SIMD3<Double> {
        try #require(m.projetee?.centresNoeuds[id])
    }

    /// La Prise salon placee dans la cuisine, en 2D, ou dans la chambre, a l'etage, en 3D : elle part de sa place
    /// affichee, sans saut ; a mi-temps, elle est en route, sur le segment de ses deux places quand les plateaux ne
    /// bougent pas ; a la fin, a sa nouvelle place. Les liens suivent sa pastille. La transition dure 0,9 s, et
    /// l'horloge tourne pendant ce temps.
    @Test(arguments: [false, true]) func nouvelleDispositionQuiGlisse(troisD: Bool) throws {
        let (m, _) = try Self.moteur(troisD: troisD)
        let avant = try Self.monde(m, Self.prise)
        let e2 = try Self.demo("Prise salon", dans: troisD ? "Chambre" : "Cuisine")
        let instant = MoteurPieces.maintenant()
        m.installerMaintenant(e2)
        let tr = try #require(m.transition)
        #expect(tr.debut >= instant && tr.debut - instant < 1 && m.doitContinuer(tr.debut + 0.5))
        #expect(tr.depart.noeuds[Self.prise] != nil && tr.arrivee.noeuds[Self.prise] != nil)
        MoteurPiecesTests.dessiner(m)
        #expect(simd_distance(try Self.monde(m, Self.prise), avant) < 1e-9, "pas de saut")
        m.poserTransition(1)
        MoteurPiecesTests.dessiner(m)
        let apres = try Self.monde(m, Self.prise)
        let f = try #require(MoteurPiecesTests.moteur(e2).projetee?.centresNoeuds[Self.prise])
        if troisD {
            #expect(apres.y - avant.y > 4, "d'un etage a l'autre")
        } else {
            #expect(simd_distance(apres, f) < 1e-9, "sa place dans la nouvelle disposition")
        }
        #expect(simd_distance(apres, avant) > 3)
        m.poserTransition(0.5)
        MoteurPiecesTests.dessiner(m)
        let mi = try Self.monde(m, Self.prise)
        let d = simd_distance(avant, apres)
        #expect(simd_distance(mi, avant) > 0.25 * d && simd_distance(mi, apres) > 0.25 * d, "en route")
        let disque = try #require(m.projetee?.disques.first { $0.noeud == Self.prise })
        let p = try #require(m.projetee)
        #expect((p.liensEnfants + p.liensRouteurs).contains { $0.a == disque.centre || $0.b == disque.centre },
                "un lien suit sa pastille")
    }

    /// « Reduire les animations » : la nouvelle disposition est posee tout de suite, sans transition, sans fondu.
    @Test func reduire() throws {
        let (m, _) = try Self.moteur()
        m.reduire = true
        let e2 = try Self.demo("Prise salon", dans: "Cuisine")
        m.installerMaintenant(e2)
        #expect(m.transition == nil && m.posesAffichees == PosesScene() && m.glissementPlateaux == nil)
        MoteurPiecesTests.dessiner(m)
        let f = try #require(MoteurPiecesTests.moteur(e2).projetee?.centresNoeuds[Self.prise])
        #expect(simd_distance(try Self.monde(m, Self.prise), f) < 1e-9)
    }

    /// Une nouvelle disposition pendant un glissement repart de la pose affichee, sans saut ; une disposition qui ne
    /// change rien laisse le glissement en cours.
    @Test func interruption() throws {
        let (m, e) = try Self.moteur()
        let e2 = try Self.demo("Prise salon", dans: "Cuisine")
        m.installerMaintenant(e2)
        let premiere = try #require(m.transition)
        m.installerMaintenant(e2)
        #expect(m.transition == premiere, "la meme disposition : le glissement continue")
        m.poserTransition(0.5)
        MoteurPiecesTests.dessiner(m)
        let mi = try Self.monde(m, Self.prise)
        m.installerMaintenant(try Self.demo("Prise salon", dans: "Entrée"))
        #expect(m.transition != premiere)
        MoteurPiecesTests.dessiner(m)
        #expect(simd_distance(try Self.monde(m, Self.prise), mi) < 1e-9, "pas de saut")
        m.installerMaintenant(e)
        MoteurPiecesTests.dessiner(m)
        #expect(simd_distance(try Self.monde(m, Self.prise), mi) < 1e-9, "pas de saut, encore")
    }

    /// Par l'horloge : la cuisine isolee, qu'une nouvelle disposition deplace de plus de 20 unites (l'ampoule de l'entree placee dans la cuisine), glisse, et la vue la
    /// suit, a mi-temps (sa place a l'image, de sa pose affichee) comme au bout ; l'horloge tourne pendant le glissement,
    /// meme sans plateau qui glisse.
    @Test func parLHorloge() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPiecesTests.moteur(e)
        let cuisine = try MoteurPiecesTests.indice(e, "Cuisine")
        m.installerMaintenant(try Self.demo("Ampoule entrée", dans: "Cuisine"))
        let g = try #require(m.glissementPlateaux)
        #expect(g.duree2D == TransitionScene.duree && g.duree3D == TransitionScene.duree, "les plateaux glissent en 0,9 s")
        let arrivee = try #require(m.entree)
        let apres = try #require(MoteurPiecesTests.moteur(arrivee).centrePiece(cuisine))
        // Les plateaux poses tout de suite : seul le glissement de la disposition fait tourner l'horloge ; puis la cuisine
        // isolee, a sa place affichee, celle d'avant.
        m.poserTaille(MoteurPiecesTests.taille)
        m.poserIsolement(cuisine)
        let avant = try #require(m.centrePiece(cuisine))
        #expect(m.glissementPlateaux == nil && m.transition != nil && simd_distance(m.orbite.cible, avant) < 1e-6)
        #expect(simd_distance(avant, apres) > 20)
        #expect(m.doitContinuer(MoteurPieces.maintenant() + 0.7), "l'horloge tourne pendant le glissement")
        m.reculerTransition(de: 0.45)
        MoteurPiecesTests.dessiner(m)
        let pose = try #require(m.posesAffichees.pieces["piece:Cuisine"])
        let plateaux = Dictionary(uniqueKeysWithValues: arrivee.scene.etages.enumerated().map { ($1.id, $0) })
        let mi = try #require(PosesScene.centre(pose.ancres, geometrie: m.geometrie, plateaux: plateaux, t: 0))
        let d = simd_distance(avant, apres)
        #expect(simd_distance(mi, avant) > 0.25 * d && simd_distance(mi, apres) > 0.25 * d, "la cuisine en route")
        #expect(simd_distance(SIMD2(m.orbite.cible.x, m.orbite.cible.z), SIMD2(mi.x, mi.z)) < 1e-6, "la vue la suit")
        m.reculerTransition(de: 1)
        MoteurPiecesTests.dessiner(m)
        #expect(m.transition == nil && m.posesAffichees == PosesScene())
        #expect(simd_distance(m.orbite.cible, apres) < 1e-6, "au bout, la vue sur la cuisine")
    }

    /// Une piece qu'on prend en route est posee a sa place, ses noeuds avec elle, et suit le pointeur ; une piece
    /// glissee par Djoko n'est pas animee a son relachement, quand la disposition suivante arrive : elle y est fixee,
    /// deja a sa place ; les autres glissent.
    @Test(.timeLimit(.minutes(1))) func pieceGlissee() async throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPiecesTests.moteur(e)
        m.installerMaintenant(try Self.demo("Prise salon", dans: "Cuisine"))
        let cuisine = try MoteurPiecesTests.indice(try #require(m.entree), "Cuisine")
        #expect(m.transition?.arrivee.pieces["piece:Cuisine"] != nil)
        MoteurPiecesTests.dessiner(m)
        let p = try MoteurPiecesTests.pointDePiece(m, cuisine)
        m.glisser(p, depart: p)
        #expect(m.transition?.arrivee.pieces["piece:Cuisine"] == nil && m.posesAffichees.pieces["piece:Cuisine"] == nil)
        #expect(m.transition?.arrivee.noeuds[Self.prise] == nil, "ses noeuds avec elle")
        #expect(m.transition?.arrivee.pieces["piece:Salon"] != nil, "les autres glissent encore")
        m.glisser(CGPoint(x: p.x + 10, y: p.y), depart: p)
        m.relacher(CGPoint(x: p.x + 10, y: p.y))
        // Glisser le salon pendant qu'une autre disposition arrive : elle attend le relachement, puis se calcule, le
        // salon fixe.
        try await MoteurPiecesTests.attendre {
            MoteurPiecesTests.dessiner(m)
            return m.transition == nil
        }
        let salon = try MoteurPiecesTests.indice(try #require(m.entree), "Salon")
        MoteurPiecesTests.dessiner(m)
        let q = try MoteurPiecesTests.pointDePiece(m, salon)
        m.glisser(q, depart: q)
        m.glisser(CGPoint(x: q.x + 60, y: q.y + 20), depart: q)
        m.recevoir(try Self.demo(["Prise salon": "Cuisine", "Ampoule entrée": "Cuisine"]))
        let place = m.positions[salon]
        m.relacher(CGPoint(x: q.x + 60, y: q.y + 20))
        try await MoteurPiecesTests.attendre { m.entree?.scene.pieces.first { $0.nom == .maison("Entrée") }?.noeuds.count == 1 }
        let tr = try #require(m.transition, "les autres pieces glissent")
        #expect(tr.arrivee.pieces["piece:Salon"] == nil && tr.depart.pieces["piece:Salon"] == nil, "le salon, deja a sa place")
        let i = try MoteurPiecesTests.indice(try #require(m.entree), "Salon")
        #expect(simd_distance(m.positions[i], place) < 1e-9)
    }

    /// La grille est rechoisie quand une nouvelle disposition change les rayons sans changer les niveaux (polissage D,
    /// section 4) : a la vue d'ensemble 2D, avec l'hysteresis ; zoomee, elle attend, comme un redimensionnement.
    @Test func grilleRechoisieQuandLesRayonsChangent() throws {
        let e1 = try MoteurPiecesTests.quatrePlateaux()
        let e2 = try IsolementTests.sceneQuiArrive(e1, places: PlacesGardees()) { zones in
            // Le bureau et la chambre d'amis quittent les combles pour l'etage : leurs rayons changent, pas les niveaux.
            zones[3].pieces.removeAll { $0 == "Bureau" || $0 == "Chambre d'amis" }
            zones[2].pieces += ["Bureau", "Chambre d'amis"]
        }
        let e3 = try IsolementTests.sceneQuiArrive(e1, places: PlacesGardees()) { zones in
            // L'entree quitte le jardin pour le rez-de-chaussee : un petit changement des rayons.
            zones[1].pieces.removeAll { $0 == "Entrée" }
            zones[0].pieces += ["Entrée"]
        }
        let r1 = MoteurPiecesTests.moteur(e1).geometrie.rayons, r2 = MoteurPiecesTests.moteur(e2).geometrie.rayons
        let r3 = MoteurPiecesTests.moteur(e3).geometrie.rayons
        #expect(r1 != r2 && r1 != r3 && e1.scene.niveaux == e2.scene.niveaux && e1.scene.niveaux == e3.scene.niveaux)
        // Une vue ou la grille en place pour les premiers rayons ne tient plus pour les seconds, meme avec l'hysteresis.
        let tailles = stride(from: 650.0, through: 1600, by: 50).flatMap { h in
            stride(from: 820.0, through: 2400, by: 20).map { CGSize(width: $0, height: h) }
        }
        let (taille, c1) = try #require(tailles.lazy.compactMap { t -> (CGSize, Int)? in
            let zone = CGSize(width: t.width, height: t.height - 84 - 50)
            guard let c1 = GeometrieMaison.colonnes(rayons: r1, taille: zone),
                  GeometrieMaison.colonnes(rayons: r2, taille: zone, enPlace: c1) != c1 else { return nil }
            return (t, c1)
        }.first, "une vue ou la grille change")
        let m = MoteurPiecesTests.moteur(e1, taille: taille)
        #expect(m.colonnes == c1)
        m.installerMaintenant(e2)
        let c2 = GeometrieMaison.colonnes(rayons: r2, taille: m.zoneVisible, enPlace: c1)
        #expect(m.colonnes == c2 && m.colonnes != c1 && m.geometrieVisee.colonnes == c2 && m.grilleEnAttente == nil)
        let z = MoteurPiecesTests.moteur(e1, taille: taille)
        z.poserZoom(echelle: 1, vers: nil)
        z.installerMaintenant(e2)
        #expect(z.colonnes == c1 && z.grilleEnAttente == PolitiqueGrille.redimensionnement, "zoomee : elle attend")
        // Et une vue ou le choix, sans la grille en place, changerait, mais ou elle reste a moins de 5 % : elle reste.
        let (garde, enPlace) = try #require(tailles.lazy.compactMap { t -> (CGSize, Int)? in
            let zone = CGSize(width: t.width, height: t.height - 84 - 50)
            guard let c = GeometrieMaison.colonnes(rayons: r1, taille: zone), GeometrieMaison.colonnes(rayons: r3, taille: zone) != c,
                  GeometrieMaison.colonnes(rayons: r3, taille: zone, enPlace: c) == c else { return nil }
            return (t, c)
        }.first, "une vue ou l'hysteresis garde la grille")
        let h = MoteurPiecesTests.moteur(e1, taille: garde)
        h.installerMaintenant(e3)
        #expect(h.colonnes == enPlace, "l'hysteresis la garde")
        let p = MoteurPiecesTests.moteur(e1, taille: taille)
        p.installerMaintenant(e1)
        #expect(p.colonnes == c1 && p.grilleEnAttente == nil && p.transition == nil && p.glissementPlateaux == nil,
                "les memes rayons : rien")
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageThreadTests/GlissementTests MaillageThreadTests/MoteurPiecesTests MaillageThreadTests/IsolementTests`
Expected: la compilation des tests échoue (`GlissementTests.swift`), par exemple avec `error: value of type 'MoteurPieces' has no member 'transition'` et `error: value of type 'MoteurPieces' has no member 'poserTransition'` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    @ObservationIgnored private(set) var glissementPlateaux: GlissementPlateaux?
```

par :

```swift
    @ObservationIgnored private(set) var glissementPlateaux: GlissementPlateaux?
    /// Le glissement d'une disposition a l'autre (polissage D, section 1) : les pieces, les noeuds et les liens qui
    /// changent, de leur pose affichee a leur nouvelle pose ; nil au repos.
    @ObservationIgnored private(set) var transition: TransitionScene?
    /// Les poses de l'image, de ce qui est en transition : la scene projetee les prend, la camera les suit.
    @ObservationIgnored private(set) var posesAffichees = PosesScene()
    /// Le dessin des pastilles qui s'effacent, absentes de la scene : celui de la scene d'avant.
    @ObservationIgnored private var apparencesParties: [String: DessinNoeud.Apparence] = [:]
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        let image = geometrie
```

par :

```swift
        let image = geometrie
        // La pose affichee de la scene d'avant, et sa pose d'arrivee (polissage D, section 1).
        let avant = entree.map { PosesScene(scene: $0.scene, cartes: cartes, positions: positions) }
        let affichee = avant?.recouvertes(par: posesAffichees)
        let rayonsAvant = entree.map { Dictionary(zip($0.scene.etages.map(\.id), geometrieVisee.rayons).map { ($0, $1) },
                                                  uniquingKeysWith: { a, _ in a }) }
        let ancienne = entree
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        positions = scene.pieces.map { placesCalculees[$0.id] ?? .zero }
```

par :

```swift
        positions = scene.pieces.map { placesCalculees[$0.id] ?? .zero }
        // Une nouvelle disposition glisse (polissage D, section 1) : de la pose affichee a la nouvelle, en 0,9 s ; une
        // disposition qui ne change rien laisse le glissement en cours. Avec « Reduire les animations », tout de suite.
        let arrivee = PosesScene(scene: scene, cartes: cartes, positions: positions)
        if pret, let affichee, let avant, arrivee != avant || transition == nil {
            transition = TransitionScene(de: affichee, vers: arrivee, a: Self.maintenant(), reduire: reduire)
            if let tr = transition {
                posesAffichees = tr.poses(a: tr.debut)
                apparencesParties = (ancienne?.apparences ?? [:]).merging(apparencesParties) { a, _ in a }
            } else {
                posesAffichees = PosesScene()
                apparencesParties = [:]
            }
        }
        // Les rayons changent sans les niveaux : la grille se rechoisit, a la vue d'ensemble 2D, avec l'hysteresis ;
        // sinon elle attend (polissage D, section 4).
        let rayonsChanges = pret && !niveauxChanges
            && Dictionary(zip(scene.etages.map(\.id), rayons(scene)).map { ($0, $1) }, uniquingKeysWith: { a, _ in a }) != rayonsAvant
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        }
        viser(geometriePour(scene), depuis: anciens, duree2D: niveauxChanges ? CameraScene.dureeCases : 0,
              duree3D: niveauxChanges ? CameraScene.dureeNiveaux : 0)
```

par :

```swift
        } else if rayonsChanges && grille {
            if ensemble {
                politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: true)
            } else {
                politique.attendre(PolitiqueGrille.redimensionnement)
            }
        }
        let glisse = pret ? TransitionScene.duree : 0
        viser(geometriePour(scene), depuis: anciens, duree2D: niveauxChanges ? CameraScene.dureeCases : glisse,
              duree3D: niveauxChanges ? CameraScene.dureeNiveaux : glisse)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        guard pret, d2 > 0 || d3 > 0, scene != nil else {
```

par :

```swift
        let depart = self.depart(geometrie, anciens: anciens, vers: g)
        // Rien ne bouge : pas de glissement (une nouvelle disposition aux memes plateaux).
        guard pret, d2 > 0 || d3 > 0, scene != nil, depart != g || glissementPlateaux != nil else {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        }
        let depart = self.depart(geometrie, anciens: anciens, vers: g)
```

par :

```swift
        }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
                              orbite: orbite, cadre: cadre)
```

par :

```swift
                              orbite: orbite, cadre: cadre, poses: posesAffichees)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
                                             apparences: entree?.apparences ?? [:], routeurs: routeurs,
```

par :

```swift
                                             apparences: apparences, routeurs: routeurs,
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if !fige && !doitContinuer(now) { endormir() }
```

par :

```swift
        if !fige && !doitContinuer(now) { endormir() }
    }

    /// Le dessin des pastilles : celles de la scene, et celles qui s'effacent, de la scene d'avant.
    private var apparences: [String: DessinNoeud.Apparence] {
        let a = entree?.apparences ?? [:]
        return apparencesParties.isEmpty ? a : a.merging(apparencesParties) { x, _ in x }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if glissementPlateaux != nil {
            let ancre0 = ancreCamera()
            geometrie = geometrie(a: now)
            if geometrie == geometrieVisee { glissementPlateaux = nil }
```

par :

```swift
        // Les plateaux et les pieces glissent ; la vue suit ce qu'elle regarde.
        if glissementPlateaux != nil || transition != nil {
            let ancre0 = ancreCamera()
            if glissementPlateaux != nil {
                geometrie = geometrie(a: now)
                if geometrie == geometrieVisee { glissementPlateaux = nil }
            }
            if let tr = transition {
                if tr.finie(a: now) {
                    finirTransition()
                } else {
                    posesAffichees = tr.poses(a: now)
                }
            }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift

    // MARK: Horloge
```

par :

```swift

    /// Fin du glissement d'une disposition : tout est pose.
    private func finirTransition() {
        transition = nil
        posesAffichees = PosesScene()
        apparencesParties = [:]
    }

    // MARK: Horloge
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if enMouvement || s != sCible || margesEnRoute || glissementPlateaux != nil || (attente != nil && geste == nil) {
```

par :

```swift
        if enMouvement || s != sCible || margesEnRoute || glissementPlateaux != nil || transition != nil
            || (attente != nil && geste == nil) {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
                      indiceEtageIsole.map({ $0 == scene.pieces[i].etage }) ?? true, let c = centrePiece(i) {
                // Les pieces de l'etage isole se glissent ; celles des autres etages se cliquent seulement.
                geste = .piece(scene.pieces[i].id, hauteur: c.y)
```

par :

```swift
                      indiceEtageIsole.map({ $0 == scene.pieces[i].etage }) ?? true {
                // Les pieces de l'etage isole se glissent ; celles des autres etages se cliquent seulement. Une piece en
                // route vers sa place y est posee, avec ses noeuds : elle suit le pointeur depuis sa place.
                transition?.oublier(pieces: [scene.pieces[i].id], noeuds: Set(scene.pieces[i].noeuds))
                if let tr = transition { posesAffichees = tr.poses(a: Self.maintenant()) }
                geste = .piece(scene.pieces[i].id, hauteur: centrePiece(i)?.y ?? 0)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift

    func poserAzimut(_ decalage: Double) { orbite.azimut += decalage }
```

par :

```swift

    /// Le glissement d'une disposition, pose a `q` (de 0 a 1) de son temps, sans horloge : les poses des pieces et des
    /// noeuds, et les plateaux qui glissent avec eux.
    func poserTransition(_ q: Double) {
        guard let tr = transition else { return }
        posesAffichees = tr.poses(a: tr.debut + q * TransitionScene.duree)
        if let gl = glissementPlateaux { geometrie = geometrie(a: gl.debut + q * max(gl.duree2D, gl.duree3D)) }
    }

    /// Le glissement d'une disposition et celui des plateaux, commences `dt` secondes plus tot (tests) : l'image suivante
    /// les avance d'autant, par l'horloge.
    func reculerTransition(de dt: Double) {
        transition?.debut -= dt
        glissementPlateaux?.debut -= dt
    }

    func poserAzimut(_ decalage: Double) { orbite.azimut += decalage }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        let c = (g ?? geometrie).centrePlateau(scene.pieces[i].etage, t)
        return SIMD3(c.x + positions[i].x, c.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, c.z + positions[i].y)
```

par :

```swift
        let g = g ?? geometrie
        // En route (polissage D, section 1) : sa pose affichee.
        if let pose = posesAffichees.pieces[scene.pieces[i].id],
           let m = PosesScene.centre(pose.ancres, geometrie: g, plateaux: plateaux(scene), t: t) {
            return SIMD3(m.x, m.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, m.z)
        }
        let c = g.centrePlateau(scene.pieces[i].etage, t)
        return SIMD3(c.x + positions[i].x, c.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, c.z + positions[i].y)
    }

    /// L'indice de chaque plateau de la scene, par cle.
    private func plateaux(_ scene: ScenePieces) -> [String: Int] {
        Dictionary(scene.etages.indices.map { (scene.etages[$0].id, $0) }, uniquingKeysWith: { a, _ in a })
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageThreadTests/GlissementTests MaillageThreadTests/MoteurPiecesTests MaillageThreadTests/IsolementTests`
Expected: `Test run with 58 tests in 3 suites passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh`
Expected: `Test run with 389 tests in 40 suites passed` (cœur) et `Test run with 353 tests in 31 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 6 tests de plus et 1 suite pour l'app.

- [ ] **Step 6 : les images de démo, identiques.** Comparées à celles de la tâche 2 : identiques, octet pour octet. Si une image diffère, s'arrêter : la tâche a changé le rendu. Les images se rendent toujours juste après la suite du step précédent, avec l'app qu'elle vient de compiler.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t3"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "maillage-polD/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
for f in $(ls "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t2"); do cmp -s "$D/$f" "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t2/$f" && echo "$f identique" || echo "$f differe"; done | sort | awk '{print $2}' | uniq -c
```

Expected : 20 ; « l'app a quitté » ; « 20 identique ».

- [ ] **Step 7 : commit.**

```bash
git add MaillageThread/Vues/Pieces/MoteurPieces.swift MaillageThreadTests/GlissementTests.swift
git commit -m "Faire glisser chaque nouvelle disposition dans le moteur, de la pose affichee a la nouvelle, la vue suivant ce qu'elle regarde, et rechoisir la grille quand les rayons changent

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Mutants essayés sur la copie validée** (chacun appliqué seul, la tâche jouée par ses tests ; un mutant qui ne compilait pas a été rejoué sous une forme qui compile, sauf pour le découpage, où la compilation est l'attente) :

15 mutants, tous tués par `GlissementTests` : jamais de transition ; la pose affichée sans la transition en cours ; la même disposition qui relance la transition ; l'image sans les poses ; `avancer` qui ne fait pas avancer les poses ; la vue qui ne suit pas la transition ; `centrePiece` sans la pose affichée ; le glisser qui ne pose pas la pièce en route ; les plateaux qui ne glissent pas ; un glissement de plateaux créé sans changement ; les rayons ignorés ; la grille qui n'attend jamais ; le choix sans hystérésis ; l'horloge sans la transition ; la transition jamais finie. Les tests au temps réel n'y ont qu'une borne basse (`reculerTransition` avance l'horloge de la transition sans attendre).

### Task 4: Les badges ne déplacent plus les pièces ; un routeur aux candidats d'une même pièce va dans cette pièce

**Files:**
- Modify: `MaillageCoeur/Scene/CartesPieces.swift`, `MaillageCoeur/Scene/PiecesRouteurs.swift`, `MaillageCoeur/Scene/ScenePieces.swift`, `MaillageThread/Vues/Pieces/EntreeScene.swift`, `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, `MaillageThread/Vues/Pieces/MesureNoms.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/CartesPiecesTests.swift`, `MaillageCoeurTests/PiecesRouteursTests.swift`, `MaillageCoeurTests/ScenePiecesTests.swift`, `MaillageThreadTests/MoteurPiecesTests.swift`, `MaillageThreadTests/NomsSceneTests.swift`

**Interfaces:**
- Consumes : `ScenePieces`, `CartesPieces`, `PiecesRouteurs` (`piece(routeur:nom:parmi:domicile:)`, `choisir`), `LibellesNoeuds`, `MesureNoms` (`noeud`, `pastille`), `EntreeScene`, `MaillageAffiche.noeud(_:)`, `NoeudSonde.candidats`, existants ; dans les tests, `MaillageDemo.maillage(_:date:sansIdentite:)`, `PiecesChoisies.placement`.
- Produces :
  - `CartesPieces.couronne`, `lune`, `alerte` ; `texte(_:chef:endormi:alerte:)`, `texteReserve(_:routeur:)` ;
  - `ScenePieces.CleDisposition`, `ScenePieces.cleDisposition` (la clé, dans le cœur) ; `ScenePieces(…, piles:)`, `ScenePieces.Noeud.pile` ; `ScenePieces.Noeud.libelle` : le nom sans ses badges ; le rang d'une ligne sans le chef ;
  - `PiecesRouteurs.pieceDeMaison(routeur:maison:)`, `piece(candidats:noms:maison:parmi:domicile:)` ;
  - `LibellesNoeuds.Libelle.nom` (`init(texte:pastille:nom:)`) ; `LibellesNoeuds.pieces(…, maillage:)` ; `EntreeScene.CleDisposition` (un alias) ;
  - `MesureNoms.reserve(_:routeur:pile:)`, `pastilleReservee`.

**Les badges** (spec, section 2 ; précision 7). La carte d'une pièce mesure, pour chaque nom, la place de tous ses badges possibles, affichés ou non, avec la vraie police (`MesureNoms.reserve`) :
- un nœud qui route : la couronne (le chef d'une partition est un routeur) et ⚠︎ ;
- un autre nœud : ☾ et ⚠︎ ;
- un nœud dont la pile est connue (décision de Djoko du 05/10) : la plus large des pastilles d'une pile faible, de 0 à 100 % ou « faible », mesurées une fois. Une pile qui devient connue élargit donc la carte, une fois.
Le cœur compose ces textes (`CartesPieces.texte`, `texteReserve`) : un nom affiché, quels que soient ses badges, est un début du nom réservé (`badgesReserves`), et l'app vérifie avec la vraie police que chacun y tient, pour chaque nœud de la démo (`reserveDesBadges`).

**La scène et la clé ne voient plus les badges.** La scène reçoit les noms nus (`Libelle.nom`) ; la clé de la disposition passe dans le cœur (`ScenePieces.cleDisposition`) : par pièce, ses nœuds dans l'ordre de la carte, chacun par son id, son nom nu, s'il route et si sa pile est connue (ce qui décide de sa réserve et de son rayon). Un badge qui paraît ou s'en va ne relance donc plus le calcul : la scène est posée tout de suite, rien ne bouge, seul le nom change (`unBadgeNeBougeRien`).

**Le chef garde sa place dans sa carte** (précision 8 ; décision de Djoko du 05/10, écart voulu à la spec de la vue par pièces, section 2.2, qui le mettait en tête) : un changement de chef aurait réordonné les lignes, donc les liens et le coût, et pu déplacer l'étage. Les lignes vont désormais par groupe (routeurs de bordure, autres routeurs, autres nœuds), puis par nom nu. Dans la démo, l'Apple TV 4K reste en tête du salon : son nom vient le premier.

**Un routeur aux candidats d'une même pièce** (spec, section 4.1 ; précision 13). Un routeur de bordure non identifié prend la pièce de ses candidats s'ils l'ont tous, et la même : pour chacun, sa pièce de Maison, sinon le choix gardé sous son instance, sinon la règle du nom (`PiecesRouteurs.piece(candidats:…)`). Sinon, il reste dans « Sans pièce ». Son nom ne change pas, et sa fiche ne propose toujours pas « Placer dans une pièce… ».

**Les images de démo changent toutes** : les cartes s'élargissent (celle du salon, dans `07-2d-zoom-salon`, d'environ un cinquième : seul le volet du salon y a une pile connue).

- [ ] **Step 1 : écrire les tests.** Les badges réservés et la clé sans badges dans le cœur, une carte avec et sans pile connue, les lignes d'une carte, la pièce d'un routeur aux candidats ; dans l'app, la réserve avec la vraie police, un badge qui ne bouge rien, les deux HomePod non identifiés de la démo ; trois tests adaptés (`lignesEtRayons`, `libelles`, `nouvelleDisposition`).

Dans `MaillageCoeurTests/CartesPiecesTests.swift`, remplacer :

```swift

    /// Une carte par piece de la scene, dans l'ordre de ses lignes ; les largeurs viennent de l'app.
```

par :

```swift

    /// Le nom affiche et le nom que la carte reserve (polissage D, section 2) : la couronne, ☾ et ⚠︎, dans cet ordre,
    /// chacun apres une espace ; la carte reserve la couronne a un noeud qui route, ☾ a un autre, ⚠︎ a tous (la pastille,
    /// a un noeud dont la pile est connue : `ScenePiecesTests.cleSansLesBadges`). Chaque nom affiche, quels que soient ses badges, tient dans le nom reserve : il en est un debut, ses badges
    /// pris dans l'ordre de la reserve.
    @Test func badgesReserves() {
        #expect(CartesPieces.texte("Lampe", chef: false, endormi: false, alerte: false) == "Lampe")
        #expect(CartesPieces.texte("Lampe", chef: true, endormi: true, alerte: true) == "Lampe 👑 ☾ ⚠︎")
        #expect(CartesPieces.texte("Lampe", chef: false, endormi: true, alerte: false) == "Lampe ☾")
        #expect(CartesPieces.texte("Lampe", chef: false, endormi: false, alerte: true) == "Lampe ⚠︎")
        #expect(CartesPieces.texte("Prise", chef: true, endormi: false, alerte: false) == "Prise 👑")
        #expect(CartesPieces.texteReserve("Prise", routeur: true) == "Prise 👑 ⚠︎")
        #expect(CartesPieces.texteReserve("Lampe", routeur: false) == "Lampe ☾ ⚠︎")
        for routeur in [false, true] {
            let reserve = CartesPieces.texteReserve("Nom", routeur: routeur)
            for alerte in [false, true] {
                let affiche = CartesPieces.texte("Nom", chef: routeur, endormi: !routeur, alerte: alerte)
                #expect(reserve.hasPrefix(affiche), "\(affiche) dans \(reserve)")
            }
        }
    }

    /// Une carte par piece de la scene, dans l'ordre de ses lignes ; les largeurs viennent de l'app.
```

Dans `MaillageCoeurTests/PiecesRouteursTests.swift`, remplacer :

```swift

    /// Pieces de Maison : celles des accessoires et celles des zones, sans doublon ni nom vide.
```

par :

```swift

    /// Un routeur de bordure non identifie, aux candidats (polissage D, section 4.1) : il va dans leur piece s'ils sont
    /// tous dans la meme ; sinon, ou si l'un n'en a pas, nulle part (« Sans piece »). La piece d'un candidat : celle de
    /// son accessoire de Maison, sinon le choix garde sous son instance, avant la regle de son nom (son surnom, sinon
    /// l'instance).
    @Test func candidats() {
        var p = PiecesRouteurs()
        let maison = NomsMaison(date: Date(timeIntervalSince1970: 1_790_000_000), accessoires: [
            AccessoireMaison(nom: "HomePod A", piece: "Bureau"), AccessoireMaison(nom: "HomePod B", piece: "Bureau"),
        ])
        func piece(_ c: [String], noms: [String: String] = [:], maison m: NomsMaison? = nil) -> String? {
            p.piece(candidats: c, noms: noms, maison: m, parmi: Self.pieces, domicile: "Maison")
        }
        #expect(piece(["HomePod Salon gauche", "HomePod Salon droit"]) == "Salon", "la meme piece, par le nom")
        #expect(piece(["HomePod Salon", "HomePod mini chambre"]) == nil, "des pieces differentes")
        #expect(piece(["HomePod Salon", "HomePod"]) == nil, "un candidat sans piece")
        #expect(piece(["HomePod"]) == nil && piece([]) == nil)
        #expect(piece(["HomePod"], noms: ["HomePod": "HomePod du salon"]) == "Salon", "le surnom")
        #expect(piece(["HomePod A", "HomePod B"], maison: maison) == "Bureau", "l'accessoire de Maison")
        #expect(piece(["HomePod A", "HomePod Salon"], maison: maison) == nil)
        p.choisir("Chambre", routeur: "HomePod Salon gauche", domicile: "Maison")
        #expect(piece(["HomePod Salon gauche", "HomePod Salon droit"]) == nil, "le choix avant le nom : deux pieces")
        p.choisir("Chambre", routeur: "HomePod Salon droit", domicile: "Maison")
        #expect(piece(["HomePod Salon gauche", "HomePod Salon droit"]) == "Chambre", "le choix avant le nom")
        p.choisir("Chambre", routeur: "HomePod A", domicile: "Maison")
        #expect(piece(["HomePod A", "HomePod B"], maison: maison) == "Bureau", "Maison avant le choix")
        #expect(PiecesRouteurs.pieceDeMaison(routeur: "HomePod A", maison: maison) == "Bureau")
        #expect(PiecesRouteurs.pieceDeMaison(routeur: "HomePod C", maison: maison) == nil)
    }

    /// Pieces de Maison : celles des accessoires et celles des zones, sans doublon ni nom vide.
```

Dans `MaillageCoeurTests/ScenePiecesTests.swift`, remplacer :

```swift
    /// Lignes d'une carte : le chef, les routeurs de bordure, les autres routeurs, puis les autres
    /// noeuds, par libelle ; rayons 15 (centre), 13, 8 et 7.
```

par :

```swift
    /// La cle de la disposition et les cartes ne dependent pas des badges (polissage D, section 2) : la scene voit les
    /// noms sans eux, et un autre chef ne reordonne pas les lignes. Un autre nom, une autre piece, une pile qui devient
    /// connue changent la cle ; la largeur reservee d'un nom (ici 7 px par caractere de `texteReserve`, plus 50 pour la
    /// pastille d'une pile connue) fait des cartes egales, avec ou sans badge, et une carte plus large avec une pile
    /// connue (polissage D, section 2, decision du 05/10).
    @Test func cleSansLesBadges() throws {
        let g = try Self.graphe(sonde: true)
        let tous = Dictionary(uniqueKeysWithValues: g.noeuds.map { ($0.id, "Salon") })
        func scene(chefs: Set<String>, libelles: [String: String] = Self.libelles, pieces: [String: String]? = nil,
                   piles: Set<String> = []) -> ScenePieces {
            ScenePieces(graphe: g, libelles: libelles, piecesNoeuds: pieces ?? tous, zones: nil, chefs: chefs, piecesMaison: true,
                        piles: piles)
        }
        let a = scene(chefs: ["Apple TV"]), b = scene(chefs: ["HomePod"]), c = scene(chefs: [])
        #expect(a.cleDisposition == b.cleDisposition && a.cleDisposition == c.cleDisposition)
        #expect(a.pieces.map(\.noeuds) == b.pieces.map(\.noeuds))
        func largeurs(_ s: ScenePieces) -> [String: Double] {
            Dictionary(uniqueKeysWithValues: s.noeuds.map {
                ($0.id, 7.0 * Double(CartesPieces.texteReserve($0.libelle, routeur: $0.routeur).count) + ($0.pile ? 50 : 0))
            })
        }
        #expect(CartesPieces.cartes(a, largeurs: largeurs(a)) == CartesPieces.cartes(b, largeurs: largeurs(b)))
        let pile = scene(chefs: ["Apple TV"], piles: ["E000000000000002"])
        #expect(pile.noeud("E000000000000002")?.pile == true && a.noeud("E000000000000002")?.pile == false)
        #expect(pile.cleDisposition != a.cleDisposition, "une pile connue")
        let salonPile = try #require(pile.pieces.firstIndex { $0.nom == .maison("Salon") })
        #expect(CartesPieces.cartes(pile, largeurs: largeurs(pile))[salonPile].largeur
                > CartesPieces.cartes(a, largeurs: largeurs(a))[salonPile].largeur, "une carte plus large avec une pile connue")
        var renomme = Self.libelles
        renomme["E000000000000002"] = "Lampe du salon"
        #expect(scene(chefs: ["Apple TV"], libelles: renomme).cleDisposition != a.cleDisposition, "un autre nom")
        var ailleurs = tous
        ailleurs["E000000000000002"] = "Cuisine"
        #expect(scene(chefs: ["Apple TV"], pieces: ailleurs).cleDisposition != a.cleDisposition, "une autre piece")
        let salon = try #require(a.cleDisposition.pieces["maison"]?["piece:Salon"])
        #expect(salon.contains("HomePod|HomePod|R|") && salon.contains("E000000000000002|Lampe salon||"), "l'id, le nom, s'il route")
        #expect(try #require(pile.cleDisposition.pieces["maison"]?["piece:Salon"]).contains("E000000000000002|Lampe salon||P"),
                "et si sa pile est connue")
        #expect(a.cleDisposition.niveaux == ["maison": "maison#0"])
    }

    /// Lignes d'une carte : les routeurs de bordure, les autres routeurs, puis les autres noeuds, par nom ; le chef reste
    /// dans son groupe (polissage D, section 2) ; rayons 15 (centre), 13, 8 et 7.
```

Dans `MaillageCoeurTests/ScenePiecesTests.swift`, remplacer :

```swift
                == ["HomePod", "Apple TV", "E000000000000004", "E000000000000005", "E000000000000003", "E000000000000002"])
        #expect(s.noeud("HomePod")?.rang == 0 && s.noeud("HomePod")?.rayon == 13)
```

par :

```swift
                == ["Apple TV", "HomePod", "E000000000000004", "E000000000000005", "E000000000000003", "E000000000000002"])
        #expect(s.noeud("HomePod")?.rang == 1 && s.noeud("HomePod")?.rayon == 13 && s.noeud("HomePod")?.chef == true)
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        var autre = e
        autre.libelles["56B1E064401F74EF"] = LibellesNoeuds.Libelle(texte: "Pont du bureau, sous la lampe de l'écran")
```

par :

```swift
        let autre = try GlissementTests.demo("Halo", nom: "Pont du bureau, sous la lampe de l'écran")
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
        #expect(e.libelles["86E7BD1A75F28E6D"] == LibellesNoeuds.Libelle(texte: "Nuki Ultra ☾"))
```

par :

```swift
        #expect(e.libelles["86E7BD1A75F28E6D"] == LibellesNoeuds.Libelle(texte: "Nuki Ultra ☾", nom: "Nuki Ultra"))
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift

    /// La scene porte ce dont elle est faite, construit une fois avec elle : le graphe, le maillage de la
```

par :

```swift

    /// Un badge qui change ne change ni la scene ni la cle de la disposition (polissage D, section 2) : une pile qui
    /// faiblit donne sa pastille au libelle, sans plus. Le moteur pose la scene tout de suite, sans calcul : rien ne
    /// bouge, ni piece ni carte, rien ne glisse ; seul le nom change.
    @Test func unBadgeNeBougeRien() throws {
        let (s, r, e) = try Self.demo()
        let m = MoteurPiecesTests.moteur(e)
        var maison = try #require(s.noms.maison)
        let k = try #require(maison.accessoires.firstIndex { $0.nom == "Nuki Ultra" })
        maison.accessoires[k].batterie = BatterieMaison(niveau: 5)
        s.noms.maison = maison
        let e2 = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
        let nuki = "86E7BD1A75F28E6D"
        #expect(e2.libelles[nuki]?.pastille == String(localized: "\(5)\u{202F}%") && e.libelles[nuki]?.pastille == nil)
        #expect(e2.scene == e.scene && e2.cleDisposition == e.cleDisposition && e2 != e)
        // La scene ne voit que les noms : ni ☾, ni la couronne du chef.
        #expect(e.libelles[nuki]?.texte == "Nuki Ultra ☾" && e.scene.noeud(nuki)?.libelle == "Nuki Ultra")
        #expect(e.libelles["Apple TV 4K"]?.texte == "Apple TV 4K 👑" && e.scene.noeud("Apple TV 4K")?.libelle == "Apple TV 4K")
        let (positions, cartes) = (m.positions, m.cartes)
        let mesure = MesureNoms()
        let reserves = Dictionary(uniqueKeysWithValues: e.scene.noeuds.map {
            ($0.id, Double(mesure.reserve($0.libelle, routeur: $0.rang <= 2, pile: $0.pile).width))
        })
        #expect(cartes == CartesPieces.cartes(e.scene, largeurs: reserves), "les cartes reservent la place des badges")
        m.recevoir(e2)
        #expect(m.entree == e2, "posee tout de suite, sans calcul")
        #expect(m.positions == positions && m.cartes == cartes && m.transition == nil && m.glissementPlateaux == nil)
        #expect(m.textes.noeuds[nuki]?.pastille == String(localized: "\(5)\u{202F}%"))
        // Une pile qui devient connue (decision du 05/10) : la cle change, et la carte de la cuisine s'elargit, une fois.
        let k2 = try #require(maison.accessoires.firstIndex { $0.nom == "Interrupteur cuisine" })
        maison.accessoires[k2].batterie = BatterieMaison(niveau: 80)
        s.noms.maison = maison
        let e3 = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
        let cuisine = try MoteurPiecesTests.indice(e, "Cuisine")
        #expect(e3.cleDisposition != e.cleDisposition && e3.scene.noeud("D6ECDD6EF9C0CB0C")?.pile == true)
        #expect(e.scene.noeud("D6ECDD6EF9C0CB0C")?.pile == false && e.scene.noeud(nuki)?.pile == true)
        #expect(MoteurPiecesTests.moteur(e3).cartes[cuisine].largeur > cartes[cuisine].largeur)
    }

    /// La place que la carte reserve au nom de chaque noeud de la demo (polissage D, section 2), avec la vraie police :
    /// chacun de ses noms affiches y tient, quels que soient ses badges, la pastille la plus large comprise pour un noeud
    /// dont la pile est connue ; sans pile connue, la reserve n'a pas de pastille (decision du 05/10).
    @Test func reserveDesBadges() throws {
        let (_, _, e) = try Self.demo()
        let mesure = MesureNoms()
        let pastilles = (0...100).compactMap { LibellesNoeuds.pastilleBatterie(BatterieMaison(niveau: $0, alerte: true)) }
            + [String(localized: "faible")]
        let large = mesure.pastilleReservee
        #expect(pastilles.contains(large) && pastilles.allSatisfy { mesure.pastille($0).width <= mesure.pastille(large).width })
        for n in e.scene.noeuds {
            let routeur = n.rang <= 2
            let reserve = mesure.reserve(n.libelle, routeur: routeur, pile: n.pile)
            for badge in [false, true] {
                for alerte in [false, true] {
                    let texte = CartesPieces.texte(n.libelle, chef: routeur && badge, endormi: !routeur && badge, alerte: alerte)
                    let affiche = mesure.noeud(LibellesNoeuds.Libelle(texte: texte, pastille: n.pile ? large : nil),
                                               routeur: routeur)
                    #expect(affiche.width <= reserve.width && affiche.height <= reserve.height, "\(texte)")
                }
            }
            let sansPastille = mesure.noeud(LibellesNoeuds.Libelle(texte: CartesPieces.texteReserve(n.libelle, routeur: routeur)),
                                            routeur: routeur)
            #expect(n.pile ? reserve.width > sansPastille.width : reserve == sansPastille, "\(n.libelle)")
            #expect(mesure.reserve(n.libelle, routeur: routeur, pile: true).width > sansPastille.width)
        }
        #expect(e.scene.noeuds.filter(\.pile).count == 9, "les neuf piles connues de la demo")
    }

    /// Deux routeurs de bordure non identifies (polissage D, section 4.1), les HomePod de la demo sans leur ExtMac :
    /// leurs candidats, les deux HomePod, sont au salon ; ils y vont, sous leur nom « A ou B · RLOC16 », et la fiche ne
    /// leur propose toujours pas « Placer dans une piece… ». Un candidat dans une autre piece : « Sans piece ».
    @Test func routeursAuxCandidats() throws {
        let (s, r, _) = try Self.demo()
        let i = try #require(s.instantane)
        let m = try #require(MaillageDemo.maillage(i, date: s.maintenant, sansIdentite: ["HomePod Avant", "HomePod Palier"]))
        s.recevoir(m, a: s.maintenant)
        let e = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
        let inconnus = e.scene.noeuds.filter { $0.inconnu && $0.bordure }
        #expect(inconnus.count == 2)
        for n in inconnus {
            #expect(e.scene.pieces[n.piece].nom == .maison("Salon"), "\(n.id)")
            #expect(e.libelles[n.id]?.texte.contains("HomePod Avant") == true)
            #expect(PiecesChoisies.placement(n.id, dans: s, entree: e) == nil)
        }
        var maison = try #require(s.noms.maison)
        let k = try #require(maison.accessoires.firstIndex { $0.nom == "HomePod Avant" })
        maison.accessoires[k].piece = "Cuisine"
        s.noms.maison = maison
        let autre = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
        for n in autre.scene.noeuds where n.inconnu && n.bordure {
            #expect(autre.scene.pieces[n.piece].nom == .sansPiece, "\(n.id)")
        }
    }

    /// La scene porte ce dont elle est faite, construit une fois avec elle : le graphe, le maillage de la
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/CartesPiecesTests MaillageCoeurTests/ScenePiecesTests MaillageCoeurTests/PiecesRouteursTests MaillageThreadTests/NomsSceneTests MaillageThreadTests/MoteurPiecesTests`
Expected: la compilation des tests échoue (`PiecesRouteursTests.swift`, `CartesPiecesTests.swift`), par exemple avec `error: extra arguments at positions #1, #3 in call` et `error: missing argument for parameter 'routeur' in call` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageCoeur/Scene/CartesPieces.swift`, remplacer :

```swift
            self.largeurNom = largeurNom
        }
```

par :

```swift
            self.largeurNom = largeurNom
        }
    }

    /// Les badges d'un nom : la couronne du chef, la lune d'un endormi, l'alerte d'un appareil sans adresse ou disparu.
    public static let couronne = "👑"
    public static let lune = "☾"
    public static let alerte = "⚠︎"

    /// Le nom affiche d'un noeud : son nom, deja coupe, puis la couronne du chef, ☾ endormi, ⚠︎ sans adresse ou disparu.
    public static func texte(_ nom: String, chef: Bool, endormi: Bool, alerte a: Bool) -> String {
        var t = nom
        if chef { t += " " + couronne }
        if endormi { t += " " + lune }
        if a { t += " " + alerte }
        return t
    }

    /// Le texte que la carte reserve au nom d'un noeud (polissage D, section 2) : son nom et tous les badges qu'il peut
    /// porter, affiches ou non. La couronne va a un noeud qui route (le chef d'une partition est un routeur), ☾ a un
    /// noeud qui ne route pas (un routeur n'est jamais endormi), ⚠︎ a tous.
    public static func texteReserve(_ nom: String, routeur: Bool) -> String {
        texte(nom, chef: routeur, endormi: !routeur, alerte: true)
```

Dans `MaillageCoeur/Scene/PiecesRouteurs.swift`, remplacer :

```swift
        try FichiersGardes.ecrire(self, dans: url, version: Self.versionActuelle)
```

par :

```swift
        try FichiersGardes.ecrire(self, dans: url, version: Self.versionActuelle)
    }

    /// Piece de Maison d'un routeur de bordure (son instance) : celle de l'accessoire qui porte son nom.
    public static func pieceDeMaison(routeur: String, maison: NomsMaison?) -> String? {
        maison?.accessoires.first { $0.nom == routeur && $0.piece?.isEmpty == false }?.piece
    }

    /// Piece d'un routeur de bordure non identifie (polissage D, section 4.1), d'apres ses candidats, les annonces
    /// qui peuvent etre la sienne : celle de chacun, comme pour un routeur identifie qui porterait son annonce (sa piece
    /// de Maison, sinon le choix garde sous son instance, sinon la regle du nom de `noms`, l'instance a defaut). Si tous
    /// en ont une, et que c'est la meme, le routeur y va ; sinon nil : « Sans piece ».
    public func piece(candidats: [String], noms: [String: String], maison: NomsMaison?, parmi pieces: [String],
                      domicile: String) -> String? {
        let p = candidats.map { c in
            Self.pieceDeMaison(routeur: c, maison: maison)
                ?? piece(routeur: c, nom: noms[c] ?? c, parmi: pieces, domicile: domicile)
        }
        guard let premiere = p.first ?? nil, p.allSatisfy({ $0 == premiere }) else { return nil }
        return premiere
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
/// - Noeuds d'une carte : le chef, les routeurs de bordure, les autres routeurs, les autres
///   noeuds ; par libelle dans chaque groupe. Rayon naturel : 15 px pour le centre d'une
```

par :

```swift
/// - Noeuds d'une carte : les routeurs de bordure, les autres routeurs, les autres noeuds ; par nom
///   dans chaque groupe, sans ses badges. Le chef reste dans son groupe (polissage D, section 2) : un
///   changement de chef ne reordonne pas la carte. Rayon naturel : 15 px pour le centre d'une
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
        /// Nom affiche, avec la couronne, la lune et l'alerte ; deja coupe (`CartesPieces.couper`).
```

par :

```swift
        /// Nom, sans la couronne, la lune ni l'alerte (polissage D, section 2) ; deja coupe (`CartesPieces.couper`).
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
        /// Rang dans sa carte : 0 chef, 1 routeur de bordure, 2 autre routeur, 3 autre noeud.
```

par :

```swift
        /// Sa pile est connue (Maison) : la carte reserve la place de la pastille d'une pile faible (polissage D,
        /// section 2).
        public var pile: Bool
        /// Rang dans sa carte : 1 routeur de bordure, 2 autre routeur, 3 autre noeud.
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
    /// `libelles` : nom affiche de chaque noeud (son id a defaut) ; `piecesNoeuds` : piece de Maison
    /// de chaque noeud qui en a une ; `zones` : celles de Maison (nil : fichier d'avant les zones) ;
    /// `chefs` : noeuds couronnes ; `piecesMaison` : Maison a au moins une piece ; `ordreEtages` :
    /// cles des etages dans l'ordre garde, du bas vers le haut ; `aCote` : les choix de niveau gardes.
    public init(graphe: GrapheReseau, libelles: [String: String], piecesNoeuds: [String: String],
                zones: [ZoneMaison]?, chefs: Set<String>, piecesMaison: Bool, ordreEtages: [String] = [],
                aCote: [String: PlacesGardees.ACote] = [:]) {
```

par :

```swift
    /// `libelles` : nom de chaque noeud, sans ses badges (son id a defaut) ; `piecesNoeuds` : piece de Maison
    /// de chaque noeud qui en a une ; `zones` : celles de Maison (nil : fichier d'avant les zones) ;
    /// `chefs` : noeuds couronnes ; `piecesMaison` : Maison a au moins une piece ; `ordreEtages` :
    /// cles des etages dans l'ordre garde, du bas vers le haut ; `aCote` : les choix de niveau gardes ; `piles` : les
    /// noeuds dont la pile est connue.
    public init(graphe: GrapheReseau, libelles: [String: String], piecesNoeuds: [String: String],
                zones: [ZoneMaison]?, chefs: Set<String>, piecesMaison: Bool, ordreEtages: [String] = [],
                aCote: [String: PlacesGardees.ACote] = [:], piles: Set<String> = []) {
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
            let rang = chef ? 0 : n.bordure ? 1 : n.routeur ? 2 : 3
            let rayon: Double = n.genre == .centre ? 15 : n.bordure ? 13 : n.routeur ? 8 : 7
            indices[n.id] = noeuds.count
            noeuds.append(Noeud(id: n.id, libelle: libelle(n.id), genre: n.genre, partition: n.partition,
                                routeur: n.routeur, bordure: n.bordure, inconnu: n.inconnu, chef: chef, rang: rang,
```

par :

```swift
            let rang = n.bordure ? 1 : n.routeur ? 2 : 3
            let rayon: Double = n.genre == .centre ? 15 : n.bordure ? 13 : n.routeur ? 8 : 7
            indices[n.id] = noeuds.count
            noeuds.append(Noeud(id: n.id, libelle: libelle(n.id), genre: n.genre, partition: n.partition,
                                routeur: n.routeur, bordure: n.bordure, inconnu: n.inconnu, chef: chef,
                                pile: piles.contains(n.id), rang: rang,
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
    public func noeud(_ id: String) -> Noeud? { indices[id].map { noeuds[$0] } }
```

par :

```swift
    public func noeud(_ id: String) -> Noeud? { indices[id].map { noeuds[$0] } }

    /// Ce qui oblige a recalculer la disposition (spec de la vue par pieces, section 4.3 ; polissage C, section 4 ;
    /// polissage D, section 2).
    public struct CleDisposition: Hashable, Sendable {
        /// Etage -> piece -> ses noeuds, dans l'ordre de sa carte : l'id, le nom sans ses badges, s'il route, et si sa pile
        /// est connue.
        public var pieces: [String: [String: [String]]] = [:]
        /// La place de chaque plateau dans la vue de reference du cout : l'etage principal de son niveau, et son rang
        /// dans le niveau.
        public var niveaux: [String: String] = [:]
    }

    /// Les etages, leurs pieces, les noeuds de chacune, leurs noms, s'ils routent et si leur pile est connue, et les
    /// niveaux tels que les voit le cout : qui partage le niveau de qui, dans quel ordre. Ni les badges d'un nom (la
    /// couronne, ☾, ⚠︎, la pastille d'une pile faible : la carte leur reserve leur place), ni l'ordre des niveaux, ni une
    /// zone dans ou hors de la maison, ni l'etat d'un noeud.
    public var cleDisposition: CleDisposition {
        var c = CleDisposition()
        for e in etages {
            for i in e.pieces {
                let p = pieces[i]
                c.pieces[e.id, default: [:]][p.id] = p.noeuds.map { id in
                    let n = noeud(id)
                    return [id, n?.libelle ?? "", n?.routeur == true ? "R" : "", n?.pile == true ? "P" : ""]
                        .joined(separator: "|")
                }
            }
        }
        for l in niveaux.liste {
            for (k, cle) in l.enumerated() { c.niveaux[cle] = l[0] + "#" + String(k) }
        }
        return c
    }
```

Dans `MaillageThread/Vues/Pieces/EntreeScene.swift`, remplacer :

```swift
                                           graphe: graphe)
        let scene = ScenePieces(graphe: graphe, libelles: libelles.mapValues(\.texte), piecesNoeuds: pieces,
                                zones: maison?.zones, chefs: chefs,
                                piecesMaison: maison?.accessoires.contains { $0.piece?.isEmpty == false } == true,
                                ordreEtages: places.maison(domicile).ordreEtages, aCote: places.maison(domicile).aCote)
```

par :

```swift
                                           graphe: graphe, maillage: maillage)
        // La scene voit les noms sans leurs badges : un badge qui change ne la change pas (polissage D, section 2).
        let scene = ScenePieces(graphe: graphe, libelles: libelles.mapValues(\.nom), piecesNoeuds: pieces,
                                zones: maison?.zones, chefs: chefs,
                                piecesMaison: maison?.accessoires.contains { $0.piece?.isEmpty == false } == true,
                                ordreEtages: places.maison(domicile).ordreEtages, aCote: places.maison(domicile).aCote,
                                piles: Set(parId.filter { $0.value.batterie != nil }.keys))
```

Dans `MaillageThread/Vues/Pieces/EntreeScene.swift`, remplacer :

```swift
    /// Ce qui oblige a recalculer la disposition (spec, section 4.3 ; polissage C, section 4).
    struct CleDisposition: Equatable {
        /// Etage -> piece -> ses noeuds et leurs noms.
        var pieces: [String: [String: [String]]] = [:]
        /// La place de chaque plateau dans la vue de reference du cout : l'etage principal de son niveau, et
        /// son rang dans le niveau.
        var niveaux: [String: String] = [:]
    }

    /// Les etages, leurs pieces, les noeuds de chacune et leurs noms, et les niveaux tels que les voit le cout :
    /// qui partage le niveau de qui, dans quel ordre. L'ordre des niveaux, une zone dans ou hors de la maison,
    /// ou l'etat d'un noeud, non.
    var cleDisposition: CleDisposition {
        var c = CleDisposition()
        for e in scene.etages {
            for i in e.pieces {
                let p = scene.pieces[i]
                c.pieces[e.id, default: [:]][p.id] = p.noeuds.map { id in
                    [id, libelles[id]?.texte ?? "", libelles[id]?.pastille ?? ""].joined(separator: "|")
                }
            }
        }
        for l in scene.niveaux.liste {
            for (k, cle) in l.enumerated() { c.niveaux[cle] = l[0] + "#" + String(k) }
        }
        return c
    }
```

par :

```swift
    /// Ce qui oblige a recalculer la disposition : celle de la scene, sans les badges des noms (polissage D, section 2).
    typealias CleDisposition = ScenePieces.CleDisposition

    var cleDisposition: CleDisposition { scene.cleDisposition }
```

Dans `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, remplacer :

```swift
    static let couronne = "👑"
    static let lune = "☾"

    /// Libelle d'un noeud : son texte, et la pastille de sa batterie faible.
    struct Libelle: Hashable {
        var texte: String
        var pastille: String?
```

par :

```swift
    static let couronne = CartesPieces.couronne
    static let lune = CartesPieces.lune

    /// Libelle d'un noeud : son texte, et la pastille de sa batterie faible ; son nom, sans ses badges (polissage D,
    /// section 2) : la scene et sa carte ne voient que lui.
    struct Libelle: Hashable {
        var texte: String
        var pastille: String?
        var nom: String

        /// `nom` : le texte, a defaut.
        init(texte: String, pastille: String? = nil, nom: String? = nil) {
            self.texte = texte
            self.pastille = pastille
            self.nom = nom ?? texte
        }
```

Dans `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, remplacer :

```swift
            var texte = CartesPieces.couper(nom)
            if chefs.contains(n.id) { texte += " " + couronne }
            if endormi(a, routeur: n.routeur) { texte += " " + lune }
            if a?.etat == .sansAdresse || a?.etat == .disparu { texte += " ⚠︎" }
            libelles[n.id] = Libelle(texte: texte, pastille: pastilleBatterie(a?.batterie))
```

par :

```swift
            let coupe = CartesPieces.couper(nom)
            let texte = CartesPieces.texte(coupe, chef: chefs.contains(n.id), endormi: endormi(a, routeur: n.routeur),
                                           alerte: a?.etat == .sansAdresse || a?.etat == .disparu)
            libelles[n.id] = Libelle(texte: texte, pastille: pastilleBatterie(a?.batterie), nom: coupe)
```

Dans `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, remplacer :

```swift
    /// nom (`nomsRouteurs`, par instance ; `PiecesRouteurs`). Un autre noeud du graphe que Maison ne
    /// place pas prend la piece choisie pour son ExtMac (precision 27).
    static func pieces(reseau: Reseau, appareils: [AppareilAffiche], maison: NomsMaison?,
                       nomsRouteurs: [String: String] = [:], choix: PiecesRouteurs = PiecesRouteurs(),
                       graphe: GrapheReseau) -> [String: String] {
```

par :

```swift
    /// nom (`nomsRouteurs`, par instance ; `PiecesRouteurs`). Un routeur de bordure que seule la sonde connait, non
    /// identifie, prend la piece de ses candidats s'ils sont tous dans la meme (polissage D, section 4.1, `maillage`).
    /// Un autre noeud du graphe que Maison ne
    /// place pas prend la piece choisie pour son ExtMac (precision 27).
    static func pieces(reseau: Reseau, appareils: [AppareilAffiche], maison: NomsMaison?,
                       nomsRouteurs: [String: String] = [:], choix: PiecesRouteurs = PiecesRouteurs(),
                       graphe: GrapheReseau, maillage: MaillageAffiche? = nil) -> [String: String] {
```

Dans `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, remplacer :

```swift
            }
        }
```

par :

```swift
            }
        }
        for n in graphe.noeuds where n.bordure && pieces[n.id] == nil {
            guard let candidats = maillage?.noeud(n.id)?.candidats, !candidats.isEmpty,
                  let p = choix.piece(candidats: candidats, noms: nomsRouteurs, maison: maison, parmi: toutes,
                                      domicile: domicile) else { continue }
            pieces[n.id] = p
        }
```

Dans `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, remplacer :

```swift
        maison?.accessoires.first { $0.nom == routeur && $0.piece?.isEmpty == false }?.piece
```

par :

```swift
        PiecesRouteurs.pieceDeMaison(routeur: routeur, maison: maison)
```

Dans `MaillageThread/Vues/Pieces/MesureNoms.swift`, remplacer :

```swift
    private var tailles: [Cle: CGSize] = [:]
```

par :

```swift
    private var tailles: [Cle: CGSize] = [:]
    private var pastilleLaPlusLarge: String?
```

Dans `MaillageThread/Vues/Pieces/MesureNoms.swift`, remplacer :

```swift
        return taille
```

par :

```swift
        return taille
    }

    /// Boite que la carte reserve au nom d'un noeud (polissage D, section 2) : son nom et tous les badges qu'il peut
    /// porter, affiches ou non (`CartesPieces.texteReserve`), puis, pour un noeud dont la pile est connue (`pile`), la
    /// plus large des pastilles d'une pile faible. Un badge qui parait ou s'en va n'y change rien.
    func reserve(_ nom: String, routeur: Bool, pile: Bool) -> CGSize {
        noeud(LibellesNoeuds.Libelle(texte: CartesPieces.texteReserve(nom, routeur: routeur),
                                     pastille: pile ? pastilleReservee : nil),
              routeur: routeur)
    }

    /// La plus large des pastilles d'une pile faible : de 0 a 100 %, ou « faible ».
    var pastilleReservee: String {
        if let p = pastilleLaPlusLarge { return p }
        let textes = (0...100).compactMap { LibellesNoeuds.pastilleBatterie(BatterieMaison(niveau: $0, alerte: true)) }
            + [LibellesNoeuds.pastilleBatterie(BatterieMaison(alerte: true))].compactMap { $0 }
        let p = textes.max { pastille($0).width < pastille($1).width } ?? ""
        pastilleLaPlusLarge = p
        return p
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Cartes des pieces d'une scene, d'apres les noms mesures des noeuds.
    private func cartesPour(_ e: EntreeScene) -> [CartesPieces.Carte] {
        var largeurs: [String: Double] = [:]
        for n in e.scene.noeuds {
            guard let l = e.libelles[n.id] else { continue }
            largeurs[n.id] = mesure.noeud(l, routeur: n.rang <= 2).width
```

par :

```swift
    /// Cartes des pieces d'une scene, d'apres les noms mesures des noeuds, avec la place de tous leurs badges possibles
    /// (polissage D, section 2) : un badge qui change ne change pas la carte.
    private func cartesPour(_ e: EntreeScene) -> [CartesPieces.Carte] {
        var largeurs: [String: Double] = [:]
        for n in e.scene.noeuds {
            largeurs[n.id] = mesure.reserve(n.libelle, routeur: n.rang <= 2, pile: n.pile).width
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/CartesPiecesTests MaillageCoeurTests/ScenePiecesTests MaillageCoeurTests/PiecesRouteursTests MaillageThreadTests/NomsSceneTests MaillageThreadTests/MoteurPiecesTests`
Expected: `Test run with 23 tests in 3 suites passed` (cœur) et `Test run with 51 tests in 2 suites passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh`
Expected: `Test run with 392 tests in 40 suites passed` (cœur) et `Test run with 356 tests in 31 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 3 tests de plus pour le cœur, 3 tests de plus pour l'app.

- [ ] **Step 6 : les images de démo, qui changent toutes.** Les cartes réservent la place des badges : chaque image diffère de celle de la tâche 3. Les images se rendent toujours juste après la suite du step précédent, avec l'app qu'elle vient de compiler.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t4"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "maillage-polD/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
for f in $(ls "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t3"); do cmp -s "$D/$f" "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t3/$f" && echo "$f identique" || echo "$f differe"; done | sort | awk '{print $2}' | uniq -c
```

Expected : 20 ; « l'app a quitté » ; « 20 differe ». Regarder (outil Read) `07-2d-zoom-salon.png` à côté de celle de la tâche 3 : la carte du salon plus large, rien d'autre ne change de nature.

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Scene/CartesPieces.swift MaillageCoeur/Scene/PiecesRouteurs.swift MaillageCoeur/Scene/ScenePieces.swift MaillageCoeurTests/CartesPiecesTests.swift MaillageCoeurTests/PiecesRouteursTests.swift MaillageCoeurTests/ScenePiecesTests.swift MaillageThread/Vues/Pieces/EntreeScene.swift MaillageThread/Vues/Pieces/LibellesNoeuds.swift MaillageThread/Vues/Pieces/MesureNoms.swift MaillageThread/Vues/Pieces/MoteurPieces.swift MaillageThreadTests/MoteurPiecesTests.swift MaillageThreadTests/NomsSceneTests.swift
git commit -m "Reserver dans chaque carte la place des badges possibles de ses noms, et celle de la pastille aux piles connues, garder les badges hors de la scene et de la cle de la disposition, laisser le chef a sa place, et mettre un routeur non identifie dans la piece de ses candidats quand c'est la meme

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Mutants essayés sur la copie validée** (chacun appliqué seul, la tâche jouée par ses tests ; un mutant qui ne compilait pas a été rejoué sous une forme qui compile, sauf pour le découpage, où la compilation est l'attente) :

17 mutants, tous tués : la réserve sans ⚠︎ ; la pastille jamais réservée, toujours réservée, ou réservée selon le routeur et non la pile ; les cartes mesurées sur le nom affiché, ou sans la pile (`unBadgeNeBougeRien`) ; la clé avec le chef, ou sans la pile ; la scène qui voit les badges (tué une fois `unBadgeNeBougeRien` complété par ses attentes sur la scène) ; les piles non passées à la scène ; le chef en tête ; la clé sans « s'il route » ; le premier candidat seul ; le choix avant Maison ; les candidats ignorés par l'app ; les candidats sans leur surnom ; la pastille réservée qui n'est pas la plus large.

### Task 5: La molette et Échap ; la rotation lente pendant un isolement ; un étage absent garde son rang ; le menu revient à la fin de l'envol

**Files:**
- Create: `MaillageThreadTests/MoletteEtEchapTests.swift`
- Modify: `MaillageCoeur/Scene/Isolement.swift`, `MaillageCoeur/Scene/Niveaux.swift`, `MaillageCoeur/Scene/PlacesGardees.swift`, `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/IsolementCoeurTests.swift`, `MaillageCoeurTests/NiveauxTests.swift`, `MaillageThreadTests/IsolementTests.swift`

**Interfaces:**
- Consumes : `MoteurPieces` (`ecouter`, `molette`, `sortir`, `remonter`, `cadresInterface`, `survoler`, `avancer`, `controles`), `SondeFenetre`, `Isolement.rotationLente` (tâche 1), `PlacesGardees.ranger`, `Rangement`, existants ; dans les tests, `FenetrePiecesTests.fenetre`, `fermer`, `SondeMaillageTests.preferences()`.
- Produces :
  - `MoteurPieces.molette(_:precis:en:) -> Bool`, `surInterface(_:)`, `sortir() -> Bool`, `vue`, `prendre(_: NSEvent)`, `EvenementVue`, `prendre(_: EvenementVue)` ; `VuePieces.point(_:dans:)` ; `SondeFenetre` rapporte sa vue ;
  - `Isolement.rotationLente(troisD:bascule:cochee:reduire:geste:)` ;
  - `Rangement.fondre(_:dans:)` ; `PlacesGardees.ranger` fond le nouvel ordre dans l'ordre gardé.

**La molette** (spec, section 3 ; précision 9). Le moniteur local lit le point du pointeur dans la vue (`VuePieces.point`, depuis la sonde de la vue dans AppKit) : au-dessus d'un élément posé sur la vue (`cadresInterface` : la fiche, la légende, la ligne des capsules, bande de la fenêtre comprise, la colonne du haut, la ligne de niveau), l'événement leur revient ; au-dessus de la scène, rien ne change.

**Échap** (précision 10), dans cet ordre : une fiche ouverte se ferme ; sinon la vue remonte d'un cran, ou une vue zoomée revient à la vue d'ensemble ; sinon, à la vue d'ensemble sans zoom ni fiche, ou pendant l'envol, Échap n'est pas pris et suit son chemin.

**Le chemin des événements** : le moniteur lit l'événement (`EvenementVue`) puis le moteur décide (`prendre`) ; la fenêtre est vérifiée sur l'événement. Un événement de molette fabriqué pour un test n'a pas de fenêtre (faits établis) : le test passe par `EvenementVue` pour la molette, et par un vrai `keyDown` pour Échap.

**La rotation lente pendant un isolement** (spec, section 4.2 ; précision 12). Elle continue quand une pièce ou un étage est isolé, autour de la cible de la caméra ; le vol d'abord, puis elle reprend, sans saut (elle part de la pose du bout du vol). Elle s'arrête pendant un geste : un glisser (⌥ compris), le zoom de la molette en route, un pincement. Décochée, ou avec « Réduire les animations » : pas de rotation. Les repères « ailleurs » et les noms la suivent, comme à la vue d'ensemble. Le test `etageIsole`, qui attendait l'arrêt (C, 5.1), attend désormais qu'elle continue.

**Un étage absent garde son rang** (spec, section 4 ; précision 11). `PlacesGardees.ranger` fond le nouvel ordre dans l'ordre gardé : un plateau absent de la scène y reste juste après celui qui le précédait, en tête s'il l'était. Cela vaut pour tous les articles du menu, « Monter » et « Descendre » compris.

**Le menu revient à la fin de l'envol ou du fondu** : le survol est repris sous le pointeur immobile, hors du rendu.

**Les images de démo ne changent pas.**

- [ ] **Step 1 : écrire les tests.** La molette et Échap, sur le moteur et dans la vraie fenêtre ; le menu à la fin de l'envol ; l'étage absent ; l'ordre fondu dans le cœur ; la rotation lente pendant un isolement.

Dans `MaillageCoeurTests/IsolementCoeurTests.swift`, remplacer :

```swift
    /// La rotation lente (spec de la vue par pieces, section 7) : en 3D, l'envol fini, cochee, sans « Reduire les
    /// animations », sans isolement ; chaque condition l'arrete.
    @Test func rotationLente() {
        #expect(Isolement.rotationLente(troisD: true, bascule: 1, cochee: true, reduire: false, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: false, bascule: 1, cochee: true, reduire: false, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 0.999, cochee: true, reduire: false, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 1, cochee: false, reduire: false, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 1, cochee: true, reduire: true, sansIsolement: true))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 1, cochee: true, reduire: false, sansIsolement: false))
```

par :

```swift
    /// La rotation lente (spec de la vue par pieces, section 7 ; polissage D, section 4.2) : en 3D, l'envol fini,
    /// cochee, sans « Reduire les animations », hors d'un geste ; chaque condition l'arrete. L'isolement, non.
    @Test func rotationLente() {
        #expect(Isolement.rotationLente(troisD: true, bascule: 1, cochee: true, reduire: false, geste: false))
        #expect(!Isolement.rotationLente(troisD: false, bascule: 1, cochee: true, reduire: false, geste: false))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 0.999, cochee: true, reduire: false, geste: false))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 1, cochee: false, reduire: false, geste: false))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 1, cochee: true, reduire: true, geste: false))
        #expect(!Isolement.rotationLente(troisD: true, bascule: 1, cochee: true, reduire: false, geste: true))
```

Dans `MaillageCoeurTests/NiveauxTests.swift`, remplacer :

```swift
        #expect(r.ordre == ["c", "a", "b", "e", "d"])
    }
```

par :

```swift
        #expect(r.ordre == ["c", "a", "b", "e", "d"])
    }

    /// Le nouvel ordre fondu dans l'ordre garde (polissage D, section 4) : un plateau absent de la scene y garde son rang
    /// relatif, juste apres celui qui le precedait ; en tete s'il l'etait ; plusieurs absents de suite restent ensemble,
    /// dans leur ordre. Un plateau nouveau garde la place que lui donne le nouvel ordre ; sans ordre garde, le nouvel ordre.
    @Test func ordreFondu() {
        #expect(Rangement.fondre(["a", "c", "b"], dans: ["a", "x", "b", "c"]) == ["a", "x", "c", "b"])
        #expect(Rangement.fondre(["b", "a"], dans: ["x", "a", "b"]) == ["x", "b", "a"])
        #expect(Rangement.fondre(["b", "a"], dans: ["a", "x", "y", "b"]) == ["b", "a", "x", "y"])
        #expect(Rangement.fondre(["a", "n", "b"], dans: ["a", "b", "z"]) == ["a", "n", "b", "z"])
        #expect(Rangement.fondre(["a", "b"], dans: []) == ["a", "b"] && Rangement.fondre(["b", "a"], dans: ["a", "b"]) == ["b", "a"])
        var p = PlacesGardees()
        p.ordonner(["a", "x", "b"], domicile: "Maison")
        p.ranger(Rangement(ordre: ["b", "a"], aCote: [:]), domicile: "Maison")
        #expect(p.maison("Maison").ordreEtages == ["b", "a", "x"])
    }
```

Dans `MaillageThreadTests/IsolementTests.swift`, remplacer :

```swift
        t.fige = false
        let azimut = t.orbite.azimut
        MoteurPiecesTests.dessiner(t)
        MoteurPiecesTests.dessiner(t)
        #expect(t.orbite.azimut == azimut, "la rotation lente s'arrete")
```

par :

```swift
        // La rotation lente continue, autour de la cible (polissage D, section 4.2).
        t.fige = false
        let (azimut, cible) = (t.orbite.azimut, t.orbite.cible)
        MoteurPiecesTests.dessiner(t)
        Thread.sleep(forTimeInterval: 0.02)
        MoteurPiecesTests.dessiner(t)
        #expect(t.orbite.azimut < azimut && t.orbite.cible == cible, "la rotation lente continue, autour de la cible")
    }

    /// La rotation lente pendant un isolement (polissage D, section 4.2) : en 3D, autour de la piece isolee, la cible et
    /// la distance gardees ; elle s'arrete pendant un geste (un glisser, le zoom de la molette, un pincement) et reprend
    /// apres ; « Rotation lente » decochee ou « Reduire les animations » : pas de rotation. Le temps reel n'y est qu'une
    /// borne basse : 20 ms entre deux images.
    @Test func rotationPendantLIsolement() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (_, e) = try Self.jardinDehors(url)
        let salon = try MoteurPiecesTests.indice(e, "Salon")
        func moteur() -> MoteurPieces {
            let m = MoteurPieces(troisD: true)
            m.marges = (84, 50)
            m.poserTaille(MoteurPiecesTests.taille)
            m.installerMaintenant(e)
            m.poserIsolement(salon)
            MoteurPiecesTests.dessiner(m)
            return m
        }
        // Deux images, 20 ms apres : l'azimut tourne-t-il ?
        func tourne(_ m: MoteurPieces) -> Bool {
            let a = m.orbite.azimut
            Thread.sleep(forTimeInterval: 0.02)
            MoteurPiecesTests.dessiner(m)
            return m.orbite.azimut < a
        }
        let m = moteur()
        let (cible, distance) = (m.orbite.cible, m.orbite.distance)
        #expect(m.estIsolee && tourne(m), "elle tourne, la piece isolee")
        #expect(m.orbite.cible == cible && abs(m.orbite.distance - distance) < 1e-9, "autour de la cible")
        let p = try MoteurPiecesTests.pointDePiece(m, salon)
        m.glisser(p, depart: p)
        #expect(!tourne(m), "pendant un glisser")
        m.relacher(p)
        #expect(tourne(m), "apres")
        m.molette(-3, precis: false)
        #expect(!tourne(m), "pendant le zoom de la molette")
        // Un pincement a peine commence : son zoom, minuscule, se fait a la premiere image ; le geste, lui, dure.
        let pince = moteur()
        pince.pincer(1.0001, en: p)
        MoteurPiecesTests.dessiner(pince)
        #expect(!tourne(pince), "pendant un pincement")
        pince.finPincement()
        #expect(tourne(pince), "apres le pincement")
        let r = moteur()
        r.reduire = true
        MoteurPiecesTests.dessiner(r)
        #expect(!tourne(r), "« Reduire les animations »")
        let d = moteur()
        d.basculerRotation()
        MoteurPiecesTests.dessiner(d)
        #expect(!d.rotation && !tourne(d), "decochee")
```

`MaillageThreadTests/MoletteEtEchapTests.swift` (fichier entier) :

```swift
import AppKit
import CoreGraphics
import Foundation
import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

/// La molette et Echap (polissage D, section 3), le menu du clic droit a la fin de l'envol, et l'ordre des etages
/// fondu dans l'ordre garde (section 4).
@MainActor
@Suite("Vue par pieces : molette, Echap, menu apres l'envol, ordre garde")
struct MoletteEtEchapTests {
    /// La molette au-dessus d'un element pose sur la vue (la fiche, la legende, la ligne des capsules, la colonne du
    /// haut) n'est pas prise : la vue ne zoome pas ; au-dessus de la scene, elle zoome. Pendant un vol, elle est prise et
    /// ignoree, comme avant.
    @Test func moletteAuDessusDesElements() throws {
        let (m, e) = try MoteurPiecesTests.moteur()
        m.cadresInterface = ["fiche": CGRect(x: 16, y: 500, width: 600, height: 280),
                             "legende": CGRect(x: 16, y: 300, width: 400, height: 190),
                             "ligne": CGRect(x: 80, y: 0, width: 1100, height: 52),
                             "colonne": CGRect(x: 16, y: 62, width: 300, height: 40)]
        for p in [CGPoint(x: 100, y: 600), CGPoint(x: 20, y: 489), CGPoint(x: 600, y: 10), CGPoint(x: 315, y: 101)] {
            #expect(m.surInterface(p) && !m.molette(-3, precis: false, en: p) && !m.vueTouchee, "\(p)")
        }
        #expect(!m.surInterface(CGPoint(x: 900, y: 400)) && !m.surInterface(CGPoint(x: 616, y: 500)))
        #expect(m.molette(-3, precis: false, en: CGPoint(x: 900, y: 400)) && m.vueTouchee, "au-dessus de la scene")
        let v = MoteurPiecesTests.moteur(e)
        v.cliquer(try MoteurPiecesTests.pointDePiece(v, try MoteurPiecesTests.indice(e, "Salon")))
        #expect(v.enMouvement && v.molette(-3, precis: false, en: CGPoint(x: 900, y: 400)), "pendant un vol : prise")
    }

    /// Echap (section 3), dans cet ordre : une fiche ouverte se ferme, sans rien d'autre ; sinon la vue remonte d'un
    /// cran ; sinon, a la vue d'ensemble sans zoom ni fiche, Echap n'est pas pris. Zoomee, Echap la ramene.
    @Test func echapDansLesTroisCas() throws {
        let (m, e) = try MoteurPiecesTests.moteur()
        let salon = try MoteurPiecesTests.indice(e, "Salon")
        m.poserIsolement(salon)
        m.selection = "Apple TV 4K"
        #expect(m.sortir() && m.selection == nil && m.estIsolee, "la fiche d'abord")
        #expect(m.sortir() && !m.estIsolee && m.isolement == .maison, "puis la vue remonte")
        let n = MoteurPiecesTests.moteur(e)
        #expect(!n.sortir() && n.sansIsolement && !n.vueTouchee, "a la vue d'ensemble : pas pris")
        n.poserZoom(echelle: 1, vers: nil)
        #expect(n.sortir() && !n.vueTouchee, "zoomee : la vue d'ensemble")
        n.basculer(troisD: true)
        #expect(!n.sortir(), "pendant l'envol, rien a faire")
    }

    /// Le chemin des evenements du moniteur, dans la vraie fenetre : Echap y est pris s'il a a faire, sinon il suit son
    /// chemin ; un Echap d'une autre fenetre n'est jamais pris ; la molette au-dessus de la legende ne zoome pas,
    /// au-dessus de la scene si. Le point de la molette est celui de la vue, depuis son coin haut gauche.
    @Test(.timeLimit(.minutes(1))) func evenementsDeLaFenetre() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let (fenetre, moteur) = try FenetrePiecesTests.fenetre(demo, taille: CGSize(width: 1100, height: 760), preferences: p)
        defer { FenetrePiecesTests.fermer(fenetre) }
        try await MoteurPiecesTests.attendre {
            moteur.pret && moteur.cadresInterface["legende"] != nil && !moteur.margesEnRoute && moteur.vue != nil
        }
        #expect(moteur.fenetre === fenetre)
        func echap(_ w: NSWindow) throws -> NSEvent {
            try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                          windowNumber: w.windowNumber, context: nil, characters: "\u{1B}",
                                          charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53))
        }
        moteur.selection = "Apple TV 4K"
        #expect(moteur.prendre(try echap(fenetre)) && moteur.selection == nil, "la fiche se ferme")
        #expect(!moteur.prendre(try echap(fenetre)), "a la vue d'ensemble, Echap suit son chemin")
        let autre = NSWindow(contentRect: NSRect(x: -6000, y: -6000, width: 200, height: 200), styleMask: [.titled],
                             backing: .buffered, defer: false)
        autre.isReleasedWhenClosed = false
        moteur.selection = "Apple TV 4K"
        #expect(!moteur.prendre(try echap(autre)) && moteur.selection != nil, "une autre fenetre")
        moteur.selection = nil
        // La molette, en un point de la vue (depuis le haut), au-dessus de la legende puis de la scene : l'evenement lu
        // porte le point de la fenetre, que le moteur ramene a la vue.
        let vue = try #require(moteur.vue)
        func molette(en q: CGPoint) -> MoteurPieces.EvenementVue {
            let dansFenetre = vue.convert(CGPoint(x: q.x, y: vue.isFlipped ? q.y : vue.bounds.height - q.y), to: nil)
            return MoteurPieces.EvenementVue(.molette(dy: -40, precis: true, position: dansFenetre))
        }
        let legende = try #require(moteur.cadresInterface["legende"])
        let surLegende = CGPoint(x: legende.midX, y: legende.midY)
        let dansFenetre = vue.convert(CGPoint(x: surLegende.x, y: vue.isFlipped ? surLegende.y : vue.bounds.height - surLegende.y), to: nil)
        let retour = VuePieces.point(dansFenetre, dans: vue)
        #expect(abs(retour.x - surLegende.x) < 1e-6 && abs(retour.y - surLegende.y) < 1e-6, "le point de la vue")
        #expect(abs(dansFenetre.y - (fenetre.contentView?.bounds.height ?? 0) + surLegende.y) < 1, "la fenetre compte depuis le bas")
        #expect(!moteur.prendre(molette(en: surLegende)) && !moteur.vueTouchee, "au-dessus de la legende : pas de zoom")
        let scene = CGPoint(x: 900, y: 300)
        #expect(!moteur.surInterface(scene))
        #expect(moteur.prendre(molette(en: scene)) && moteur.vueTouchee, "au-dessus de la scene : le zoom")
        #expect(!moteur.prendre(MoteurPieces.EvenementVue(.option(true))), "⌥ suit son chemin")
    }

    /// Le menu du clic droit revient des la fin de l'envol ou de son fondu (section 4), sans mouvement du pointeur :
    /// le pointeur immobile sur le fond reprend le menu du fond.
    @Test(.timeLimit(.minutes(1)), arguments: [false, true]) func menuALaFinDeLEnvol(reduire: Bool) async throws {
        let (m, _) = try MoteurPiecesTests.moteur()
        m.reduire = reduire
        let fond = CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3)
        m.survoler(fond)
        #expect(m.cibleMenu == .fond)
        m.basculer(troisD: true)
        #expect(m.enMouvement && m.cibleMenu == .aucune)
        try await MoteurPiecesTests.attendre {
            MoteurPiecesTests.dessiner(m)
            return !m.enMouvement
        }
        #expect(!m.enMouvement && m.t == 1)
        try await MoteurPiecesTests.attendre { m.cibleMenu == .fond }
        #expect(m.cibleMenu == .fond, "le menu du fond, sous le pointeur immobile")
    }

    /// « Monter d'un etage » avec un etage absent de la scene (section 4) : il garde son rang relatif dans l'ordre garde,
    /// juste apres celui qui le precedait.
    @Test func unEtageAbsentGardeSonRang() throws {
        let base = try MoteurPiecesTests.quatrePlateaux()
        var places = PlacesGardees()
        let rdc = IsolementTests.rdc, jardin = IsolementTests.jardin, etage = IsolementTests.etage
        let combles = IsolementTests.combles
        places.ordonner([rdc, "zone:Grange", jardin, etage, combles], domicile: base.domicile)
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try places.ecrire(dans: url)
        let e = try MoteurPiecesTests.quatrePlateaux(places)
        let m = MoteurPiecesTests.moteur(e, fichier: url)
        #expect(e.scene.etages.map(\.id) == [rdc, jardin, etage, combles])
        m.deplacerEtage(rdc, de: 1)
        #expect(m.places.maison(base.domicile).ordreEtages == [jardin, rdc, "zone:Grange", etage, combles])
        #expect(PlacesGardees.lire(url).maison(base.domicile).ordreEtages == [jardin, rdc, "zone:Grange", etage, combles])
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/IsolementCoeurTests MaillageCoeurTests/NiveauxTests MaillageThreadTests/MoletteEtEchapTests MaillageThreadTests/IsolementTests`
Expected: la compilation des tests échoue (`IsolementCoeurTests.swift`, `MoletteEtEchapTests.swift`), par exemple avec `error: incorrect argument label in call (have 'troisD:bascule:cochee:reduire:geste:', expected 'troisD:bascule:cochee:reduire:sansIsolement:')` et `error: value of type 'MoteurPieces' has no member 'surInterface'` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageCoeur/Scene/Isolement.swift`, remplacer :

```swift
    /// sans « Reduire les animations », et ni piece ni etage isoles, ni en train d'etre quittes (`sansIsolement`).
    public static func rotationLente(troisD: Bool, bascule: Double, cochee: Bool, reduire: Bool,
                                     sansIsolement: Bool) -> Bool {
        troisD && bascule == 1 && cochee && !reduire && sansIsolement
```

par :

```swift
    /// sans « Reduire les animations », hors d'un geste (`geste` : un glisser, la molette, un pincement). Elle continue
    /// quand une piece ou un etage est isole (polissage D, section 4.2), autour de la cible de la camera.
    public static func rotationLente(troisD: Bool, bascule: Double, cochee: Bool, reduire: Bool, geste: Bool) -> Bool {
        troisD && bascule == 1 && cochee && !reduire && !geste
```

Dans `MaillageCoeur/Scene/Niveaux.swift`, remplacer :

```swift

/// Les operations du menu du clic droit (polissage C, section 1.3) : chacune rend le nouvel ordre des
```

par :

```swift

extension Rangement {
    /// Le nouvel ordre `nouveau`, fondu dans l'ordre garde `garde` (polissage D, section 4) : les plateaux du nouvel
    /// ordre y sont dans le leur ; un plateau du garde absent du nouveau, absent de la scene, y garde son rang relatif,
    /// juste apres celui qui le precedait dans le garde (en tete s'il n'en avait pas).
    public static func fondre(_ nouveau: [String], dans garde: [String]) -> [String] {
        let presents = Set(nouveau)
        var r = nouveau
        var precedent: String?
        for c in garde {
            if !presents.contains(c), !r.contains(c) {
                let i = precedent.flatMap { r.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
                r.insert(c, at: i)
            }
            precedent = c
        }
        return r
    }
}

/// Les operations du menu du clic droit (polissage C, section 1.3) : chacune rend le nouvel ordre des
```

Dans `MaillageCoeur/Scene/PlacesGardees.swift`, remplacer :

```swift
    /// Garde l'ordre des plateaux et les choix de niveau, apres un choix du menu du clic droit.
    public mutating func ranger(_ r: Rangement, domicile: String) {
        maisons[domicile, default: Maison()].ordreEtages = r.ordre
```

par :

```swift
    /// Garde l'ordre des plateaux et les choix de niveau, apres un choix du menu du clic droit. Le nouvel ordre, celui
    /// des plateaux de la scene, est fondu dans l'ordre garde : un plateau absent de la scene y garde son rang relatif
    /// (polissage D, section 4 ; `Rangement.fondre`).
    public mutating func ranger(_ r: Rangement, domicile: String) {
        maisons[domicile, default: Maison()].ordreEtages = Rangement.fondre(r.ordre, dans: maison(domicile).ordreEtages)
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift

    /// Le style du pointeur pour un curseur du moteur : le lien (la main), la main ouverte, la main fermee.
```

par :

```swift

    /// Le point de la vue (points, depuis son coin haut gauche, comme l'espace de la vue) d'un point de sa fenetre
    /// (`locationInWindow`) ; `vue` : la sonde de la vue, dans AppKit, de sa taille.
    static func point(_ p: CGPoint, dans vue: NSView) -> CGPoint {
        let q = vue.convert(p, from: nil)
        return CGPoint(x: q.x, y: vue.isFlipped ? q.y : vue.bounds.height - q.y)
    }

    /// Le style du pointeur pour un curseur du moteur : le lien (la main), la main ouverte, la main fermee.
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        .background(SondeFenetre { moteur.fenetre = $0 })
```

par :

```swift
        .background(SondeFenetre { v in
            moteur.fenetre = v.window
            moteur.vue = v
        })
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
/// Rapporte la fenetre qui porte la vue (la molette et Echap ne valent que pour elle).
struct SondeFenetre: NSViewRepresentable {
    let rapporter: (NSWindow?) -> Void
```

par :

```swift
/// Rapporte la vue, dans AppKit, et la fenetre qui la porte (la molette et Echap ne valent que pour elle).
struct SondeFenetre: NSViewRepresentable {
    let rapporter: (NSView) -> Void
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        let rapporter: (NSWindow?) -> Void

        init(_ rapporter: @escaping (NSWindow?) -> Void) {
```

par :

```swift
        let rapporter: (NSView) -> Void

        init(_ rapporter: @escaping (NSView) -> Void) {
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
            rapporter(window)
```

par :

```swift
            rapporter(self)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Fenetre de la vue : la molette et Echap ne valent que pour elle.
    @ObservationIgnored weak var fenetre: NSWindow?
```

par :

```swift
    /// Fenetre de la vue : la molette et Echap ne valent que pour elle. La vue, dans AppKit : le point de la molette.
    @ObservationIgnored weak var fenetre: NSWindow?
    @ObservationIgnored weak var vue: NSView?
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// autres plateaux s'estompent a 15 %, la sphere et « ⌂ Maison » s'effacent, la rotation lente s'arrete. Une
```

par :

```swift
    /// autres plateaux s'estompent a 15 %, la sphere et « ⌂ Maison » s'effacent ; la rotation lente continue (polissage D). Une
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Echap.
    func sortir() {
        remonter(clavier: true)
```

par :

```swift
    /// Echap (polissage D, section 3), dans cet ordre : une fiche ouverte se ferme ; sinon la vue remonte d'un cran ;
    /// sinon, a la vue d'ensemble sans zoom ni fiche, Echap n'est pas pris (faux) : l'evenement suit son chemin.
    @discardableResult
    func sortir() -> Bool {
        if selection != nil {
            selection = nil
            return true
        }
        guard envol == nil, fondu == nil, isolement != .maison || focus != nil || etageEnVue != nil || vueTouchee else {
            return false
        }
        remonter(clavier: true)
        return true
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        instant = now
```

par :

```swift
        instant = now
        let basculait = envol != nil || fondu != nil
        defer { if basculait && envol == nil && fondu == nil { basculeFinie() } }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// La rotation lente tourne (`Isolement.rotationLente`).
    private var rotationLente: Bool {
        Isolement.rotationLente(troisD: troisD, bascule: t, cochee: rotation, reduire: reduire, sansIsolement: sansIsolement)
```

par :

```swift
    /// La rotation lente tourne (`Isolement.rotationLente`), une piece ou un etage isoles compris (polissage D,
    /// section 4.2), sauf pendant un geste : un glisser (⌥ compris), le zoom de la molette en route, un pincement.
    private var rotationLente: Bool {
        Isolement.rotationLente(troisD: troisD, bascule: t, cochee: rotation, reduire: reduire,
                                geste: geste != nil || zoomEnAttente != 0 || dernierPincement != 1)
    }

    /// L'envol ou son fondu fini : le survol, le menu du clic droit et le curseur reprennent sous le pointeur immobile
    /// (polissage D, section 4), hors du rendu.
    private func basculeFinie() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.survoler(self.curseur, option: self.optionTenue)
        }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if rotationLente && geste == nil {
```

par :

```swift
        if rotationLente {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// La molette zoome, sauf pendant un vol et pendant ⌥ + glisser : elle est alors ignoree, non differee.
    func molette(_ dy: Double, precis: Bool) {
        guard !enMouvement, !deplaceDansLEcran else { return }
        zoomer(precis ? -dy * 0.004 : -dy * 0.08, en: curseur)
```

par :

```swift
    /// La molette zoome, sauf pendant un vol et pendant ⌥ + glisser : elle est alors ignoree, non differee. Au-dessus
    /// d'un element pose sur la vue (`p`, dans la vue : la fiche, la legende, la ligne des capsules, la colonne du haut),
    /// elle n'est pas prise (faux) : l'evenement leur revient (polissage D, section 3).
    @discardableResult
    func molette(_ dy: Double, precis: Bool, en p: CGPoint? = nil) -> Bool {
        if let p, surInterface(p) { return false }
        guard !enMouvement, !deplaceDansLEcran else { return true }
        zoomer(precis ? -dy * 0.004 : -dy * 0.08, en: curseur)
        return true
    }

    /// Le point `p` de la vue est sur un element pose sur elle.
    func surInterface(_ p: CGPoint) -> Bool {
        cadresInterface.values.contains { $0.contains(p) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            let pourMoi = MainActor.assumeIsolated { e.window != nil && e.window === self.fenetre }
            guard pourMoi else { return e }
            switch e.type {
            case .scrollWheel:
                let dy = Double(e.scrollingDeltaY), precis = e.hasPreciseScrollingDeltas
                MainActor.assumeIsolated { self.molette(dy, precis: precis) }
                return nil
            case .keyDown where e.keyCode == 53:
                MainActor.assumeIsolated { self.sortir() }
                return nil
            case .flagsChanged:
                // ⌥ et la main ouverte (polissage C, section 6) : l'evenement continue son chemin.
                let option = e.modifierFlags.contains(.option)
                MainActor.assumeIsolated { self.changerOption(option) }
                return e
            default:
                return e
            }
```

par :

```swift
            let pris = MainActor.assumeIsolated { self.prendre(e) }
            return pris ? nil : e
        }
    }

    /// Un evenement du moniteur, dans la fenetre de la vue seulement : la molette, au-dessus de la scene (pas d'un element
    /// pose sur elle), et Echap, s'il a quelque chose a faire, sont pris (vrai : le moniteur rend nil) ; ⌥ pressee ou
    /// relachee met a jour la main ouverte (polissage C, section 6) et continue son chemin, comme tout le reste.
    func prendre(_ e: NSEvent) -> Bool {
        guard e.window != nil, e.window === fenetre else { return false }
        return prendre(EvenementVue(e))
    }

    /// Ce que le moniteur lit d'un evenement de la fenetre de la vue.
    struct EvenementVue {
        enum Genre {
            /// La molette : son pas, precis (trackpad) ou non, et le point du pointeur dans la fenetre.
            case molette(dy: Double, precis: Bool, position: CGPoint)
            case echap
            /// ⌥ tenue ou non.
            case option(Bool)
            case autre
        }

        var genre: Genre

        init(_ genre: Genre) {
            self.genre = genre
        }

        init(_ e: NSEvent) {
            switch e.type {
            case .scrollWheel:
                genre = .molette(dy: Double(e.scrollingDeltaY), precis: e.hasPreciseScrollingDeltas, position: e.locationInWindow)
            case .keyDown where e.keyCode == 53:
                genre = .echap
            case .flagsChanged:
                genre = .option(e.modifierFlags.contains(.option))
            default:
                genre = .autre
            }
        }
    }

    /// La meme chose, une fois l'evenement lu.
    func prendre(_ e: EvenementVue) -> Bool {
        switch e.genre {
        case .molette(let dy, let precis, let position):
            return molette(dy, precis: precis, en: vue.map { VuePieces.point(position, dans: $0) })
        case .echap:
            return sortir()
        case .option(let option):
            changerOption(option)
            return false
        case .autre:
            return false
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/IsolementCoeurTests MaillageCoeurTests/NiveauxTests MaillageThreadTests/MoletteEtEchapTests MaillageThreadTests/IsolementTests`
Expected: `Test run with 13 tests in 2 suites passed` (cœur) et `Test run with 23 tests in 2 suites passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh`
Expected: `Test run with 393 tests in 40 suites passed` (cœur) et `Test run with 362 tests in 32 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 1 test de plus pour le cœur, 6 tests de plus et 1 suite pour l'app.

- [ ] **Step 6 : les images de démo, identiques.** Comparées à celles de la tâche 4 : identiques, octet pour octet. Si une image diffère, s'arrêter : la tâche a changé le rendu. Les images se rendent toujours juste après la suite du step précédent, avec l'app qu'elle vient de compiler.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t5"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "maillage-polD/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
for f in $(ls "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t4"); do cmp -s "$D/$f" "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t4/$f" && echo "$f identique" || echo "$f differe"; done | sort | awk '{print $2}' | uniq -c
```

Expected : 20 ; « l'app a quitté » ; « 20 identique ».

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Scene/Isolement.swift MaillageCoeur/Scene/Niveaux.swift MaillageCoeur/Scene/PlacesGardees.swift MaillageCoeurTests/IsolementCoeurTests.swift MaillageCoeurTests/NiveauxTests.swift MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/Pieces/MoteurPieces.swift MaillageThreadTests/IsolementTests.swift MaillageThreadTests/MoletteEtEchapTests.swift
git commit -m "Laisser la molette aux elements poses sur la vue et Echap a son chemin quand il n'a rien a faire, fermer d'abord la fiche, faire tourner la rotation lente pendant un isolement, garder son rang a un etage absent, et rendre le menu a la fin de l'envol

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Mutants essayés sur la copie validée** (chacun appliqué seul, la tâche jouée par ses tests ; un mutant qui ne compilait pas a été rejoué sous une forme qui compile, sauf pour le découpage, où la compilation est l'attente) :

14 mutants, tous tués : Échap qui ne ferme pas d'abord la fiche ; Échap toujours pris ; Échap qui oublie le zoom ; la molette sans les éléments posés ; le moniteur sans la vérification de la fenêtre ; la molette sans le point de la vue ; le point sans retournement de l'axe vertical ; le menu non repris après l'envol ; la rotation arrêtée par le seul glisser, ou sans le pincement, ou encore par l'isolement ; un absent mis à la fin, ou toujours en tête ; `ranger` sans fondre.

### Task 6: Le signal vu par la sonde : une échelle toujours graduée, et sa valeur au survol

**Files:**
- Create: `MaillageCoeur/Maillage/EchelleSignal.swift`, `MaillageCoeurTests/EchelleSignalTests.swift`
- Modify: `MaillageThread/Vues/Pieces/CourbesFiche.swift` (blocs ci-dessous)
- Test: `MaillageThreadTests/CourbesFicheTests.swift`

**Interfaces:**
- Consumes : `PointCourbe`, `PeriodeCourbes` (`duree`), `CourbesNoeud` (`signal`, `debut`, `fin`), `CourbesFiche.signal`, existants ; dans les tests, `CourbesFicheTests.surveillance()`, `JournalMaillageTests.appareil`.
- Produces : `EchelleSignal` (cœur) : `portee` (0,02), `domaine(_:)`, `graduations(_:)`, `plusProche(_:de:periode:)`, `etiquette(_:periode:locale:fuseau:)`, `aGauche(_:debut:fin:)` ; `CourbesFiche.echelle(_:)`.

**L'échelle** (spec, section 4.3). Le domaine vertical vient du cœur : du minimum moins 5 dB, arrondi à la dizaine inférieure, au maximum plus 5 dB, arrondi à la dizaine supérieure ; au moins 10 dB, et deux graduations au moins, sur les dizaines. Un seul point à −67 dBm donne −80 … −60, gradué −80, −70, −60.

**Le survol** (précision 14). Le relevé le plus proche du pointeur dans le temps, à moins de 2 % de la durée de la période ; aucun dans un trou. Un trait vertical à son heure, un point sur sa valeur, et une étiquette : sa valeur arrondie au dBm, avec le vrai signe moins, puis son heure, au format de la langue de l'app (`locale` de SwiftUI) : « −67 dBm · 16:13 » en français, « −67 dBm · 4:13 PM » en anglais ; en 7 j et 30 j, le jour aussi (« 21 sept. à 16:13 »). L'étiquette se pose à gauche du trait dans la moitié droite du graphe, et reste dans son cadre (`overflowResolution`). Le pointeur sorti, elle disparaît.

**`chartOverlay`, et non `chartXSelection`** : la sélection de Swift Charts suit le clic et le glisser, pas le simple survol, sur le Mac. Un calque transparent lit le survol (`onContinuousHover`) et convertit son abscisse en heure (`ChartProxy.value(atX:)`).

**La qualité des liens** garde son échelle de 0 à 3, sans survol.

**Les images de démo ne changent pas** : la démo n'a pas d'historique, donc pas de courbes.

- [ ] **Step 1 : écrire les tests.** Le domaine, le relevé le plus proche, l'étiquette, dans le cœur ; l'échelle de la fiche.

`MaillageCoeurTests/EchelleSignalTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

/// Le signal vu par la sonde, dans la fiche (polissage D, section 4.3) : le domaine et ses graduations, le releve sous
/// le pointeur, son etiquette, sans dependre de la langue ni du fuseau de la machine.
@Suite("Courbes : echelle et survol du signal")
struct EchelleSignalTests {
    /// Le domaine : un seul point (−67 donne −80 ... −60) ; des valeurs egales ; des valeurs etalees ; des valeurs deja
    /// sur une dizaine (−70 donne −80 ... −60, pas −70 ... −70). Toujours 10 dB au moins, et deux graduations au moins,
    /// sur les dizaines.
    @Test func domaine() throws {
        #expect(EchelleSignal.domaine([-67]) == -80 ... -60)
        #expect(EchelleSignal.domaine([-67, -67, -67]) == -80 ... -60)
        #expect(EchelleSignal.domaine([-91, -58]) == -100 ... -50)
        #expect(EchelleSignal.domaine([-70]) == -80 ... -60)
        #expect(EchelleSignal.domaine([-75]) == -80 ... -70, "a 5 dB d'une dizaine : elle-meme")
        #expect(EchelleSignal.domaine([-74.9]) == -80 ... -60)
        #expect(EchelleSignal.domaine([-65.1]) == -80 ... -60 && EchelleSignal.domaine([-64.9]) == -70 ... -50)
        #expect(EchelleSignal.domaine([]) == nil)
        #expect(EchelleSignal.graduations(-80 ... -60) == [-80, -70, -60])
        #expect(EchelleSignal.graduations(-100 ... -50) == [-100, -90, -80, -70, -60, -50])
        #expect(EchelleSignal.graduations(-80 ... -70) == [-80, -70])
        for v in stride(from: -100.0, through: -30, by: 0.7) {
            let d = try #require(EchelleSignal.domaine([v]))
            #expect(d.upperBound - d.lowerBound >= 10 && EchelleSignal.graduations(d).count >= 2 && d.contains(v), "\(v)")
        }
    }

    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    static func point(_ s: TimeInterval, _ v: Double = -67) -> PointCourbe {
        PointCourbe(date: t0.addingTimeInterval(s), valeur: v, troncon: 0)
    }

    /// Le releve sous le pointeur : le plus proche dans le temps ; a moins de 2 % de la periode, des deux cotes (sur
    /// 24 h, 1 728 s) ; au-dela, dans un trou, aucun ; sur 7 j, 2 % font 12 096 s.
    @Test func plusProche() {
        let points = [Self.point(0, -60), Self.point(600, -61), Self.point(9000, -62)]
        #expect(EchelleSignal.portee == 0.02)
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(200), periode: .jour) == points[0])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(400), periode: .jour) == points[1])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(-1727), periode: .jour) == points[0])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(-1729), periode: .jour) == nil)
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(600 + 1727), periode: .jour) == points[1])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(600 + 1729), periode: .jour) == nil, "un trou")
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(9000 - 1727), periode: .jour) == points[2])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(600 + 1729), periode: .semaine) == points[1])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(9000 + 12_095), periode: .semaine) == points[2])
        #expect(EchelleSignal.plusProche(points, de: Self.t0.addingTimeInterval(9000 + 12_097), periode: .semaine) == nil)
        #expect(EchelleSignal.plusProche([], de: Self.t0, periode: .mois) == nil)
    }

    /// L'etiquette, en francais et en anglais, a Paris : la valeur arrondie avec le vrai signe moins, puis l'heure ; en
    /// 7 j et 30 j, le jour aussi. Et sa place : a gauche du trait dans la moitie droite du graphe.
    @Test func etiquette() {
        let paris = TimeZone(identifier: "Europe/Paris")!
        let p = Self.point(0, -66.6)
        let fr = Locale(identifier: "fr_FR"), en = Locale(identifier: "en_US")
        #expect(EchelleSignal.etiquette(p, periode: .jour, locale: fr, fuseau: paris) == "\u{2212}67 dBm · 16:13")
        #expect(EchelleSignal.etiquette(p, periode: .jour, locale: en, fuseau: paris) == "\u{2212}67 dBm · 4:13\u{202F}PM")
        #expect(EchelleSignal.etiquette(p, periode: .semaine, locale: fr, fuseau: paris) == "\u{2212}67 dBm · 21 sept. à 16:13")
        #expect(EchelleSignal.etiquette(p, periode: .mois, locale: en, fuseau: paris) == "\u{2212}67 dBm · Sep 21 at 4:13\u{202F}PM")
        #expect(EchelleSignal.etiquette(Self.point(0, 3), periode: .jour, locale: fr, fuseau: paris) == "3 dBm · 16:13")
        let fin = Self.t0.addingTimeInterval(100)
        #expect(EchelleSignal.aGauche(Self.t0.addingTimeInterval(51), debut: Self.t0, fin: fin))
        #expect(!EchelleSignal.aGauche(Self.t0.addingTimeInterval(50), debut: Self.t0, fin: fin))
        #expect(!EchelleSignal.aGauche(Self.t0, debut: Self.t0, fin: Self.t0))
    }
}
```

Dans `MaillageThreadTests/CourbesFicheTests.swift`, remplacer :

```swift

    /// La fiche montre les courbes des qu'il y a un historique (jamais en demo), et la vue lui
```

par :

```swift

    /// L'echelle du signal de la fiche (polissage D, section 4.3) : celle du coeur, sur les valeurs de la courbe ; deux
    /// releves egaux a -61 dBm donnent -70 ... -50, gradue -70, -60, -50 ; sans valeur, -100 ... -40.
    @Test func echelleDuSignal() throws {
        let s = try Self.surveillance()
        let r = try #require(s.courbes(noeud: "rloc:0400", periode: .jour, fin: Date()))
        let e = CourbesFiche.echelle(r)
        #expect(e.domaine == -70 ... -50 && e.graduations == [-70, -60, -50])
        let vide = try #require(s.courbes(noeud: JournalMaillageTests.appareil, periode: .jour, fin: Date()))
        #expect(vide.signal.isEmpty && CourbesFiche.echelle(vide).domaine == -100 ... -40)
        #expect(CourbesFiche.echelle(vide).graduations == [-100, -90, -80, -70, -60, -50, -40])
    }

    /// La fiche montre les courbes des qu'il y a un historique (jamais en demo), et la vue lui
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/EchelleSignalTests MaillageThreadTests/CourbesFicheTests`
Expected: la compilation des tests échoue (`EchelleSignalTests.swift`), par exemple avec `error: cannot find 'EchelleSignal' in scope` et `error: no calls to throwing functions occur within 'try' expression [#UnnecessaryEffectMarker]` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Maillage/EchelleSignal.swift` (fichier entier) :

```swift
import Foundation

/// Le signal vu par la sonde, dans la fiche (polissage D, section 4.3) : son echelle, toujours visible, meme pour un
/// seul point ou des valeurs toutes egales ; le releve sous le pointeur et son etiquette.
public enum EchelleSignal {
    /// Un releve ne compte au survol qu'a moins de 2 % de la duree de la periode du pointeur.
    public static let portee = 0.02

    /// Le domaine vertical (dBm) : du minimum moins 5 dB, arrondi a la dizaine inferieure, au maximum plus 5 dB, arrondi
    /// a la dizaine superieure ; au moins 10 dB. Nil sans valeur.
    public static func domaine(_ valeurs: [Double]) -> ClosedRange<Double>? {
        guard let bas = valeurs.min(), let haut = valeurs.max() else { return nil }
        return ((bas - 5) / 10).rounded(.down) * 10 ... ((haut + 5) / 10).rounded(.up) * 10
    }

    /// Les graduations : chaque dizaine du domaine, du bas vers le haut.
    public static func graduations(_ d: ClosedRange<Double>) -> [Double] {
        stride(from: (d.lowerBound / 10).rounded(.up) * 10, through: d.upperBound, by: 10).map { $0 }
    }

    /// Le releve le plus proche de `date` dans le temps, a moins de 2 % de la duree de `periode` ; nil s'il n'y en a pas
    /// (un trou de la courbe). A egale distance, le plus ancien.
    public static func plusProche(_ points: [PointCourbe], de date: Date, periode: PeriodeCourbes) -> PointCourbe? {
        let portee = Self.portee * periode.duree
        return points.filter { abs($0.date.timeIntervalSince(date)) < portee }
            .min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    /// L'etiquette d'un releve : sa valeur arrondie au dBm, avec le vrai signe moins, puis son heure, au format de
    /// `locale`, dans le fuseau `fuseau` : « −67 dBm · 14:32 » ; en 7 j et 30 j, le jour aussi.
    public static func etiquette(_ p: PointCourbe, periode: PeriodeCourbes, locale: Locale, fuseau: TimeZone) -> String {
        let v = Int(p.valeur.rounded())
        let valeur = (v < 0 ? "\u{2212}" : "") + String(abs(v))
        var style = Date.FormatStyle(locale: locale, timeZone: fuseau).hour().minute()
        if periode != .jour { style = style.day().month(.abbreviated) }
        return valeur + " dBm · " + p.date.formatted(style)
    }

    /// L'etiquette se pose a gauche du trait dans la moitie droite du graphe (`debut` a `fin`), a droite sinon : elle
    /// reste dans le cadre.
    public static func aGauche(_ date: Date, debut: Date, fin: Date) -> Bool {
        let duree = fin.timeIntervalSince(debut)
        return duree > 0 && date.timeIntervalSince(debut) / duree > 0.5
    }
}
```

Dans `MaillageThread/Vues/Pieces/CourbesFiche.swift`, remplacer :

```swift
/// elle est posee).
struct CourbesFiche: View {
    @Environment(Surveillance.self) private var surveillance
```

par :

```swift
/// elle est posee). Le signal a toujours une echelle, et sa valeur se lit au survol (polissage D,
/// section 4.3).
struct CourbesFiche: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.locale) private var langue
```

Dans `MaillageThread/Vues/Pieces/CourbesFiche.swift`, remplacer :

```swift
    @State private var periode: PeriodeCourbes = .jour
```

par :

```swift
    @State private var periode: PeriodeCourbes = .jour
    /// L'heure sous le pointeur, au-dessus du graphe du signal ; nil, ailleurs.
    @State private var survole: Date?
```

Dans `MaillageThread/Vues/Pieces/CourbesFiche.swift`, remplacer :

```swift
    private func signal(_ c: CourbesNoeud, _ noms: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
```

par :

```swift
    /// L'echelle du signal (polissage D, section 4.3) : son domaine, des dizaines de dBm autour de ses valeurs, et ses
    /// graduations ; sans valeur, de -100 a -40 dBm.
    static func echelle(_ c: CourbesNoeud) -> (domaine: ClosedRange<Double>, graduations: [Double]) {
        let d = EchelleSignal.domaine(c.signal.map(\.valeur)) ?? -100 ... -40
        return (d, EchelleSignal.graduations(d))
    }

    private func signal(_ c: CourbesNoeud, _ noms: [String: String]) -> some View {
        let echelle = Self.echelle(c)
        // Le releve sous le pointeur, a moins de 2 % de la periode ; aucun dans un trou.
        let releve = survole.flatMap { EchelleSignal.plusProche(c.signal, de: $0, periode: periode) }
        return VStack(alignment: .leading, spacing: 2) {
```

Dans `MaillageThread/Vues/Pieces/CourbesFiche.swift`, remplacer :

```swift
            }
            .chartXScale(domain: c.debut ... c.fin)
            .chartYScale(domain: .automatic(includesZero: false))
```

par :

```swift
                // Le releve survole : un trait a son heure, un point sur sa valeur, son etiquette, dans le cadre.
                if let r = releve {
                    RuleMark(x: .value("Heure", r.date))
                        .foregroundStyle(.primary.opacity(0.5))
                        .annotation(position: .top,
                                    alignment: EchelleSignal.aGauche(r.date, debut: c.debut, fin: c.fin) ? .trailing : .leading,
                                    spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            Text(verbatim: EchelleSignal.etiquette(r, periode: periode, locale: langue, fuseau: .current))
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 4)
                                .background(.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
                        }
                    PointMark(x: .value("Heure", r.date), y: .value("Signal", r.valeur))
                        .symbolSize(30)
                }
            }
            .chartXScale(domain: c.debut ... c.fin)
            .chartYScale(domain: echelle.domaine)
            .chartYAxis { AxisMarks(values: echelle.graduations) }
            .chartOverlay { proxy in
                GeometryReader { g in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let p):
                                guard let cadre = proxy.plotFrame else { return }
                                survole = proxy.value(atX: p.x - g[cadre].origin.x, as: Date.self)
                            case .ended:
                                survole = nil
                            }
                        }
                }
            }
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageCoeurTests/EchelleSignalTests MaillageThreadTests/CourbesFicheTests`
Expected: `Test run with 3 tests in 1 suite passed` (cœur) et `Test run with 5 tests in 1 suite passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh`
Expected: `Test run with 396 tests in 41 suites passed` (cœur) et `Test run with 363 tests in 32 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 3 tests de plus et 1 suite pour le cœur, 1 test de plus pour l'app.

- [ ] **Step 6 : les images de démo, identiques.** Comparées à celles de la tâche 5 : identiques, octet pour octet. Si une image diffère, s'arrêter : la tâche a changé le rendu. Les images se rendent toujours juste après la suite du step précédent, avec l'app qu'elle vient de compiler.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t6"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "maillage-polD/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
for f in $(ls "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t5"); do cmp -s "$D/$f" "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t5/$f" && echo "$f identique" || echo "$f differe"; done | sort | awk '{print $2}' | uniq -c
```

Expected : 20 ; « l'app a quitté » ; « 20 identique ».

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Maillage/EchelleSignal.swift MaillageCoeurTests/EchelleSignalTests.swift MaillageThread/Vues/Pieces/CourbesFiche.swift MaillageThreadTests/CourbesFicheTests.swift
git commit -m "Donner au signal vu par la sonde une echelle toujours graduee, calculee dans le coeur, et montrer au survol la valeur et l'heure du releve le plus proche

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Mutants essayés sur la copie validée** (chacun appliqué seul, la tâche jouée par ses tests ; un mutant qui ne compilait pas a été rejoué sous une forme qui compile, sauf pour le découpage, où la compilation est l'attente) :

8 mutants, tous tués par `EchelleSignalTests` : sans la marge de 5 dB ; des graduations de 20 dB ; une portée de 3 % ; le premier relevé et non le plus proche ; un tiret au lieu du signe moins ; sans le jour en 7 j ; l'étiquette à gauche dès le quart du graphe ; la valeur tronquée et non arrondie. La vue elle-même (le domaine posé, le calque de survol) ne se voit qu'en vrai : `ImageRenderer` ne survole rien.

### Task 7: Le moteur en fichiers : `MoteurPieces` réparti en extensions, par responsabilité, le code déplacé tel quel

**Files:**
- Create: `MaillageThread/Vues/Pieces/MoteurPieces+Camera.swift`, `MaillageThread/Vues/Pieces/MoteurPieces+Gestes.swift`, `MaillageThread/Vues/Pieces/MoteurPieces+Image.swift`, `MaillageThread/Vues/Pieces/MoteurPieces+Poses.swift`, `MaillageThread/Vues/Pieces/MoteurPieces+Scene.swift`
- Modify: `MaillageThread/Vues/Pieces/MoteurPieces.swift` (blocs ci-dessous)

**Interfaces:**
- Consumes : `MoteurPieces.swift` tel que les tâches 1 à 6 le laissent (1 877 lignes).
- Produces : `MoteurPieces.swift` (les types de la vue, la classe, son état, son `init` et ses propriétés calculées) et cinq extensions : `MoteurPieces+Scene.swift` (la scène et sa disposition, les places gardées, le menu du clic droit), `MoteurPieces+Camera.swift` (les plateaux et la grille, la caméra, les vols, l'isolement), `MoteurPieces+Image.swift` (chaque image, l'avance de l'état, l'horloge), `MoteurPieces+Gestes.swift` (la souris, le clavier, la molette, Échap), `MoteurPieces+Poses.swift` (les états posés à la main, pour les captures et les tests). Aucune interface ne change.

**Pourquoi** (spec, section 5, décision de Djoko du 05/10) : le moteur passait de 1 724 à 1 877 lignes. Il est réparti en six fichiers, de 114 à 402 lignes, par responsabilité ; c'est la dernière tâche de code, avant la démo et la doc.

**Le code est déplacé, sans être réécrit** (précision 17) : chaque section (`// MARK:`) du fichier passe telle quelle, dans le même ordre, dans une extension de `MoteurPieces`, sous trois à quatre `import`. Une seule chose change : un membre `private` (ou `private(set)`) qu'un autre fichier du moteur lit ou écrit ne l'est plus, car une extension ne voit pas un membre privé d'un autre fichier. Les autres gardent leur `private` : il en reste 29 sur 138. Les propriétés stockées restent dans la classe, dans `MoteurPieces.swift`. Le Step 5 le vérifie : le code de tous les fichiers, remis bout à bout sans le mot `private`, est exactement celui d'avant, sans le mot `private`.

**Les nouveaux fichiers dans la cible** : le projet Xcode est généré par XcodeGen depuis `project.yml`, et n'est pas commité (`.gitignore`). La cible de l'app prend tout le dossier `MaillageThread` (`sources: - path: MaillageThread`) : un fichier nouveau y entre au prochain `xcodegen generate`, que `outils/tester.sh` lance d'abord. Ni `project.yml` ni un `pbxproj` ne changent.

**Les tests ne changent pas, ni les images de démo**, octet pour octet.

- [ ] **Step 1 : garder le moteur d'avant**, pour le Step 5.

```bash
mkdir -p "$HOME/Library/Caches/maillage-polD/"
git show HEAD:MaillageThread/Vues/Pieces/MoteurPieces.swift > "$HOME/Library/Caches/maillage-polD/MoteurPieces-avant.swift"
wc -l < "$HOME/Library/Caches/maillage-polD/MoteurPieces-avant.swift"
```

Expected : `1877`.

- [ ] **Step 2 : découper.** Les cinq extensions, fichiers entiers ; puis, dans `MoteurPieces.swift`, un seul remplacement : du premier `private` retiré à la fin du fichier, ce qui reste dans la classe.

`MaillageThread/Vues/Pieces/MoteurPieces+Camera.swift` (fichier entier) :

```swift
import Foundation
import MaillageCoeur
import simd

/// Les plateaux et la grille, la camera, les vols et l'isolement (polissage D, section 5 : le moteur en fichiers).
extension MoteurPieces {
    // MARK: Plateaux

    /// La geometrie d'une scene : les rayons de sa disposition, ses niveaux, et la grille du reglage (en grille, les
    /// colonnes choisies, la rangee en attendant une vraie taille).
    func geometriePour(_ scene: ScenePieces) -> GeometrieMaison {
        GeometrieMaison(rayons: rayons(scene),
                        plateaux: scene.etages.map {
                            GeometrieMaison.Plateau(niveau: $0.niveau, principal: $0.principal, dehors: $0.dehors)
                        },
                        colonnes: politique.colonnesDeLaGeometrie)
    }

    /// Les rayons des plateaux d'une scene, ceux de sa disposition : la grille se choisit sur eux.
    func rayons(_ scene: ScenePieces) -> [Double] {
        scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge }
    }

    /// La zone visible ou se choisit la grille (polissage C, section 3.3, decision de Djoko du 03/10) : la vue moins la
    /// marge du haut et celle du bas, la legende ouverte ou repliee, sans la fiche (`basGrille`). La vue d'ensemble y est
    /// toujours la plus grande possible.
    var zoneVisible: CGSize {
        CGSize(width: taille.width, height: taille.height - marges.haut - (basGrille ?? marges.bas))
    }

    /// Pose la geometrie visee : tout de suite, ou en glissant (« Reduire les animations » : tout de suite) depuis la
    /// geometrie de l'image, remise dans l'ordre des plateaux de la scene (`anciens` : celui de l'image). Un
    /// glissement en cours repart de l'image, avec le temps qui lui restait s'il est plus long.
    func viser(_ g: GeometrieMaison, depuis anciens: [String], duree2D: Double, duree3D: Double) {
        let now = Self.maintenant()
        var d2 = reduire ? 0 : duree2D
        var d3 = reduire ? 0 : duree3D
        if let gl = glissementPlateaux, !reduire {
            d2 = max(d2, gl.duree2D - (now - gl.debut))
            d3 = max(d3, gl.duree3D - (now - gl.debut))
        }
        geometrieVisee = g
        let depart = self.depart(geometrie, anciens: anciens, vers: g)
        // Rien ne bouge : pas de glissement (une nouvelle disposition aux memes plateaux).
        guard pret, d2 > 0 || d3 > 0, scene != nil, depart != g || glissementPlateaux != nil else {
            geometrie = g
            glissementPlateaux = nil
            return
        }
        geometrie = depart
        glissementPlateaux = GlissementPlateaux(depart: depart, debut: now, duree2D: d2, duree3D: d3)
        reveiller()
    }

    /// Le depart d'un glissement vers `g`, la geometrie de la scene : la geometrie `image`, remise dans l'ordre des
    /// plateaux de la scene (`anciens` : celui de l'image), chaque plateau a sa place d'avant, retrouvee par sa cle ;
    /// la boite, le pas, la sphere et le cadrage de l'image. Un plateau nouveau part de sa place d'arrivee.
    func depart(_ image: GeometrieMaison, anciens: [String], vers g: GeometrieMaison) -> GeometrieMaison {
        var depart = g
        for (i, c) in (scene?.etages.map(\.id) ?? []).enumerated() {
            guard let j = anciens.firstIndex(of: c), j < image.centres2D.count else { continue }
            depart.centres2D[i] = image.centres2D[j]
            depart.centres3D[i] = image.centres3D[j]
        }
        depart.boite = image.boite
        depart.pasEtage = image.pasEtage
        depart.centreSphere = image.centreSphere
        depart.rayonSphere = image.rayonSphere
        depart.rayonCadre = image.rayonCadre
        return depart
    }

    /// La geometrie de l'image a l'instant `now` : en route vers la geometrie visee, ou elle.
    func geometrie(a now: Double) -> GeometrieMaison {
        guard let gl = glissementPlateaux else { return geometrieVisee }
        let q2 = gl.duree2D > 0 ? min(1, max(0, (now - gl.debut) / gl.duree2D)) : 1
        let q3 = gl.duree3D > 0 ? min(1, max(0, (now - gl.debut) / gl.duree3D)) : 1
        if q2 >= 1 && q3 >= 1 { return geometrieVisee }
        return gl.depart.vers(geometrieVisee, k2: CameraScene.rampe(q2), k3: CameraScene.rampe(q3))
    }

    /// Le reglage « Etages en 2D » (polissage C, section 3.1) : en grille ou en rangee. Il s'applique tout de suite a
    /// la vue ouverte, les plateaux glissant comme l'envol, en 2,6 s ; zoomee, isolee ou en 3D, au retour a la vue
    /// d'ensemble 2D.
    func reglerGrille(_ g: Bool) {
        guard politique.regler(g), pret else { return }
        demanderGrille(PolitiqueGrille.reglage)
    }

    /// La zone visible a change (polissage C, sections 3.3 et 3.5) : la taille de la vue, ou ses marges sans la fiche
    /// (la legende ouverte ou repliee, un bandeau). La premiere vraie zone pose la grille et cadre la vue d'ensemble,
    /// sans autre condition ; ensuite, la grille se recalcule a la vue d'ensemble 2D, avec l'hysteresis, et les plateaux
    /// glissent en 0,4 s ; zoomee, isolee ou en 3D, elle attend.
    func zoneChangee() {
        guard pret, let scene else { return }
        if politique.sansVraieTaille {
            guard politique.premiereZone(rayons: rayons(scene), zone: zoneVisible) else { return }
            viser(geometriePour(scene), depuis: scene.etages.map(\.id), duree2D: 0, duree3D: 0)
            vueTouchee = false
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
            return
        }
        demanderGrille(PolitiqueGrille.redimensionnement)
    }

    /// Une grille voulue : posee a la vue d'ensemble 2D, ses plateaux glissant en `d.duree` ; sinon elle attend
    /// (`PolitiqueGrille`).
    private func demanderGrille(_ d: PolitiqueGrille.Demande) {
        guard let scene else { return }
        if politique.demander(d, ensemble2D: t == 0 && aLaVueDEnsemble, rayons: rayons(scene), zone: zoneVisible) {
            poserGeometrie(d.duree)
        }
    }

    /// Pose la grille d'une demande, puis sa geometrie.
    func poserGrille(_ d: PolitiqueGrille.Demande) {
        guard let scene else { return }
        politique.poser(d, rayons: rayons(scene), zone: zoneVisible)
        poserGeometrie(d.duree)
    }

    /// La geometrie de la grille choisie : ses plateaux glissent en `duree`.
    private func poserGeometrie(_ duree: Double) {
        guard let scene else { return }
        let g = geometriePour(scene)
        guard g != geometrieVisee else { return }
        viser(g, depuis: scene.etages.map(\.id), duree2D: duree, duree3D: 0)
        if glissementPlateaux == nil && aLaVueDEnsemble { recadrer() }   // posee tout de suite : cadree tout de suite
    }

    /// Ce que la vue regarde : la piece isolee, l'etage isole, ou la cible de la vue d'ensemble ; dans la geometrie de
    /// l'image, ou dans `g`.
    func ancreCamera(dans g: GeometrieMaison? = nil) -> SIMD3<Double> {
        let g = g ?? geometrie
        if let i = focus, let c = centrePiece(i, dans: g) { return c }
        if let k = etageEnVue, let e = scene?.etages.firstIndex(where: { $0.id == k }) { return g.centrePlateau(e, t) }
        return g.cible2D + (g.centreSphere - g.cible2D) * t
    }

    /// Les plateaux glissent : un vol rejoint l'arrivee de ce qu'il vise ; a la vue d'ensemble, elle se recadre ; sinon,
    /// la vue suit ce qu'elle regarde (`ancre0` : sa place a l'image d'avant).
    func suivre(depuis ancre0: SIMD3<Double>) {
        if vol != nil {
            if let v = viseeVol, let fin = volVers(v) {
                vol?.oeil1 = fin.oeil1
                vol?.cible1 = fin.cible1
            }
        } else if envol == nil && fondu == nil {
            if aLaVueDEnsemble {
                recadrer()
            } else {
                orbite.cible += ancreCamera() - ancre0
            }
        }
    }

    /// Le vol vers ce que l'on vise, depuis la camera du moment.
    private func volVers(_ v: Visee) -> Vol? {
        switch v {
        case .ensemble: CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1)
        case .piece(let cle): scene?.pieces.firstIndex { $0.id == cle }.flatMap(volVersPiece)
        case .etage(let cle): scene?.etages.firstIndex { $0.id == cle }.map(volVersEtage)
        }
    }

    // MARK: Camera

    /// Cadre la vue d'ensemble a l'avancement courant, en gardant l'orbite en 3D.
    func recadrer() {
        var c = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        if t == 1 {
            c.azimut = orbite.azimut
            c.inclinaison = orbite.inclinaison
        }
        orbite = c
    }

    /// Bascule 2D / 3D : un envol de 2,6 s depuis la vue courante (un fondu de 0,3 s si « Reduire
    /// les animations ») ; une piece isolee est relachee. Pas de menu du clic droit pendant l'envol, meme sous un
    /// pointeur immobile : sa cible tombe, et le survol ne la reprend qu'apres lui.
    func basculer(troisD v: Bool) {
        guard v != troisD else { return }
        troisD = v
        if cibleMenu != .aucune { cibleMenu = .aucune }
        focus = nil
        isolee = nil
        s = 0
        sCible = 0
        fk = [:]
        etageEnVue = nil
        se = 0
        seCible = 0
        ek = [:]
        isolement = .maison
        vol = nil
        zoomEnAttente = 0
        rotationEnAttente = .zero
        vueTouchee = false
        textes = entree.map { Self.textes($0, focus: nil) } ?? textes
        construireEtiquettes()
        majFil()
        // Vers la 2D, l'envol se pose sur la grille de la zone visible du moment (polissage C, section 3.5).
        if !v, let scene {
            politique.oublierAttente()
            politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: false)
            viser(geometriePour(scene), depuis: scene.etages.map(\.id), duree2D: 0, duree3D: 0)
        }
        let arrivee = v ? 1.0 : 0.0
        if reduire {
            fondu = Fondu(debut: Self.maintenant(), arrivee: arrivee)
        } else {
            envol = Envol(depuis: orbite, t: t, vers: arrivee, geometrie: geometrie, aspect: aspect)
            debutEnvol = Self.maintenant()
        }
        reveiller()
    }

    /// Isole une piece : la camera y vole en 1,3 s (tout de suite si « Reduire les animations »), les
    /// autres s'estompent, ses reperes « ailleurs » apparaissent. Son etage est celui du fil : les disques des
    /// autres etages restent a 15 %, cliquables (polissage C, section 5.2). La provenance (section 5.4) : depuis la
    /// maison ou un etage isole, ce que l'on quitte ; d'une piece a une autre, elle reste, sauf vers une piece d'un
    /// autre etage : la maison.
    func isoler(_ i: Int) {
        guard let scene, i < scene.pieces.count, !(focus == i && sCible == 1) else { return }
        let piece = scene.pieces[i], etage = scene.etages[piece.etage].id
        isolement = isolement.isoler(piece: piece.id, etage: etage)
        focus = i
        isolee = textes.pieces[i]?.nom
        if sCible != 1 {
            sDepart = s
            sCible = 1
            sDebut = Self.maintenant()
        }
        if scene.etages.count > 1 { viserEtage(etage) }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        majFil()
        if let v = volVersPiece(i) { voler(v, visee: .piece(piece.id)) }
    }

    /// Isole un etage (polissage C, section 5.1) : un vol de 1,3 s cadre son plateau, bande de son nom comprise ; les
    /// autres plateaux s'estompent a 15 %, la sphere et « ⌂ Maison » s'effacent ; la rotation lente continue (polissage D). Une
    /// piece isolee est relachee. Rien dans une maison d'un seul plateau, ni pendant l'envol.
    func allerEtage(_ e: Int) {
        guard let scene, scene.etages.count > 1, e < scene.etages.count, envol == nil, fondu == nil else { return }
        quitterPiece()
        let cle = scene.etages[e].id
        isolement = .etage(cle)
        viserEtage(cle)
        majFil()
        voler(volVersEtage(e), visee: .etage(cle))
    }

    /// Vol vers un etage isole.
    func volVersEtage(_ e: Int) -> Vol {
        CameraScene.volVersEtage(orbite, geometrie, etage: e, aspect: aspect, u: t, troisD: t == 1)
    }

    /// L'isolement d'etage vise `cle` : son plateau reste net.
    func viserEtage(_ cle: String) {
        etageEnVue = cle
        if seCible != 1 {
            seDepart = se
            seCible = 1
            seDebut = Self.maintenant()
        }
    }

    /// La piece isolee est relachee : son isolement redescend en 1,3 s.
    private func quitterPiece() {
        guard focus != nil, sCible != 0 else { return }
        sDepart = s
        sCible = 0
        sDebut = Self.maintenant()
        isolee = nil
        // Retour lance avant la premiere image de l'isolement : `s` est deja a 0, et l'horloge ne
        // finirait jamais ce retour.
        if s == 0 { finirRetour() }
    }

    /// L'etage isole est relache.
    private func quitterEtage() {
        guard seCible != 0 else { return }
        seDepart = se
        seCible = 0
        seDebut = Self.maintenant()
        if se == 0 { etageEnVue = nil }
    }

    /// Le fil de ce que montre la vue.
    func majFil() {
        var f = Fil()
        if let scene {
            func cran(_ e: Int) -> Fil.Cran { Fil.Cran(nom: textes.etages[e] ?? "", etage: e) }
            switch isolement {
            case .maison:
                break
            case .etage(let cle):
                f.etage = scene.etages.firstIndex { $0.id == cle }.map(cran)
            case .piece(let cle, _):
                if let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
                    f.piece = textes.pieces[i]?.nom
                    if scene.etages.count > 1 { f.etage = cran(scene.pieces[i].etage) }
                }
            }
        }
        if f != fil { fil = f }
    }

    /// Vol vers une piece, a la hauteur de vue de la spec (section 7).
    func volVersPiece(_ i: Int) -> Vol? {
        guard let c = centrePiece(i) else { return nil }
        return CameraScene.volVersPiece(orbite, centre: c, largeur: cartes[i].largeur, profondeur: cartes[i].profondeur,
                                        aspect: aspect, troisD: t == 1)
    }

    /// Retour a la maison (« Maison » dans le fil, double-clic, ou en remontant) : la piece et l'etage isoles sont
    /// relaches, le zoom et le deplacement annules, par un vol de 1,3 s qui part de la pose courante. « Reduire les
    /// animations » : tout de suite, ou par un fondu de 0,3 s (`enFondu`, le double-clic).
    func versMaison(enFondu: Bool = false) {
        guard isolement != .maison || focus != nil || etageEnVue != nil || vueTouchee else { return }
        quitterPiece()
        quitterEtage()
        isolement = .maison
        majFil()
        vueTouchee = false
        voler(CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1), visee: .ensemble,
              enFondu: enFondu)
    }

    /// Echap et le clic a cote remontent d'ou l'on vient (polissage C, section 5.4) : une piece ouverte depuis un etage
    /// isole, a l'etage de la piece ; une autre piece, ou un etage, a la maison. A la maison, Echap ramene une vue
    /// zoomee ou deplacee a la vue d'ensemble (`clavier`) ; le clic a cote ne fait rien. Rien pendant l'envol.
    func remonter(clavier: Bool = true) {
        guard envol == nil, fondu == nil else { return }
        var etageDeLaPiece: String?
        if case .piece(let cle, _) = isolement, let scene, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            etageDeLaPiece = scene.etages[scene.pieces[i].etage].id
        }
        switch isolement.remonter(etageDeLaPiece: etageDeLaPiece, plusieursPlateaux: (scene?.etages.count ?? 0) > 1,
                                  clavier: clavier) {
        case .etage(let cle):
            if let e = scene?.etages.firstIndex(where: { $0.id == cle }) { allerEtage(e) }
        case .maison:
            versMaison()
        case .rien:
            break
        }
    }

    /// Echap (polissage D, section 3), dans cet ordre : une fiche ouverte se ferme ; sinon la vue remonte d'un cran ;
    /// sinon, a la vue d'ensemble sans zoom ni fiche, Echap n'est pas pris (faux) : l'evenement suit son chemin.
    @discardableResult
    func sortir() -> Bool {
        if selection != nil {
            selection = nil
            return true
        }
        guard envol == nil, fondu == nil, isolement != .maison || focus != nil || etageEnVue != nil || vueTouchee else {
            return false
        }
        remonter(clavier: true)
        return true
    }

    /// Fin du retour d'un isolement : plus de piece isolee, ni de reperes « ailleurs ».
    func finirRetour() {
        focus = nil
        if let e = entree { textes = Self.textes(e, focus: nil) }
        construireEtiquettes()
    }

    /// Double-clic sur le fond ou sur un disque (precision 17 du plan 4b ; polissage C, section 5.4) : retour a la vue
    /// d'ensemble d'un geste, de partout. Le premier clic a deja agi seul ; le second relache ce qui reste isole et
    /// annule le zoom et le deplacement.
    func doubleCliquer() {
        versMaison(enFondu: true)
    }

    private func voler(_ v: Vol, visee: Visee, enFondu: Bool = false) {
        zoomEnAttente = 0
        rotationEnAttente = .zero
        viseeVol = nil
        if reduire && enFondu {
            fondu = Fondu(debut: Self.maintenant(), arrivee: t, orbite: v.orbite(1, depuis: orbite))
            vol = nil
        } else if reduire {
            orbite = v.orbite(1, depuis: orbite)
            vol = nil
        } else {
            vol = v
            viseeVol = visee
            debutVol = Self.maintenant()
        }
        reveiller()
    }

    func basculerRotation() {
        rotation.toggle()
        reveiller()
    }
}
```

`MaillageThread/Vues/Pieces/MoteurPieces+Gestes.swift` (fichier entier) :

```swift
import AppKit
import MaillageCoeur
import SwiftUI
import simd

/// La souris, le clavier, la molette et Echap (polissage D, section 5 : le moteur en fichiers).
extension MoteurPieces {
    // MARK: Souris et clavier

    /// Noeud sous un point : sa pastille, a 8 points pres, sinon son nom.
    func noeudSous(_ p: CGPoint) -> String? {
        if let n = projetee?.noeud(sous: p, marge: 8) { return n }
        for l in etiquettes where l.vu && l.rect.contains(p) {
            if case .noeud(let id) = l.genre { return id }
        }
        return nil
    }

    /// Survol : le nom de l'appareil en semi-gras ; un disque cliquable s'eclaircit, le nom d'un etage se souligne ; la
    /// main sur ce qui se clique (polissage C, maquette). Rien pendant l'envol : ni clic, ni menu du clic droit.
    func survoler(_ p: CGPoint?, option: Bool = false) {
        curseur = p
        optionTenue = option
        let libre = envol == nil && fondu == nil
        let c = libre ? p.map(cibleClic(en:)) ?? .fond : .fond
        let n: String? = if case .appareil(let id) = c { id } else { nil }
        let disque: Int? = if case .disque(let e) = c, disqueCliquable(e) { e } else { nil }
        let nom: Int? = if case .nomEtage(let e) = c { e } else { nil }
        if n != survol || disque != survolEtage || nom != survolNomEtage {
            survol = n
            survolEtage = disque
            survolNomEtage = nom
            reveiller()
        }
        surCliquable = switch c {
        case .appareil, .piece: true
        case .nomEtage(let e): clicEtage(e, disque: false) != .rien
        case .disque(let e): disqueCliquable(e)
        case .fond: false
        }
        majCurseur()
        let cible = libre ? p.map(cible(en:)) ?? .aucune : .aucune
        if cible != cibleMenu { cibleMenu = cible }
    }

    /// ⌥ pressee ou relachee, le pointeur immobile (le moniteur des touches).
    func changerOption(_ option: Bool) {
        guard option != optionTenue else { return }
        optionTenue = option
        majCurseur()
    }

    /// Le curseur (polissage C, section 6) : une main fermee pendant ⌥ + glisser ; une main ouverte tant que ⌥ est
    /// tenue au-dessus de la vue en 3D ; sinon, une main sur ce qui se clique.
    private func majCurseur() {
        let forme: Curseur
        if case .ecran? = geste {
            forme = .mainFermee
        } else if optionTenue && curseur != nil && troisD && t == 1 && envol == nil && fondu == nil {
            forme = .mainOuverte
        } else {
            forme = surCliquable ? .main : .fleche
        }
        if forme != curseurForme { curseurForme = forme }
    }

    /// Ce que vise un clic en `p`, du plus fort au plus faible (polissage C, section 5.1).
    func cibleClic(en p: CGPoint) -> CibleClic {
        if let n = noeudSous(p) { return .appareil(n) }
        if let i = pieceSous(p) { return .piece(i) }
        if let e = nomEtageSous(p) { return .nomEtage(e) }
        if let e = disqueSous(p) { return .disque(e) }
        return .fond
    }

    /// Nom d'etage sous un point (`marge` points autour).
    func nomEtageSous(_ p: CGPoint, marge: CGFloat = 0) -> Int? {
        for l in etiquettes where l.vu && l.rect.insetBy(dx: -marge, dy: -marge).contains(p) {
            if case .etage(let e) = l.genre { return e }
        }
        return nil
    }

    /// Disque d'un plateau sous un point : en 3D, le plus proche sur le rayon, au point ou il le rencontre.
    func disqueSous(_ p: CGPoint) -> Int? {
        guard let projetee else { return nil }
        let proj = ProjectionScene(orbite, cadre: cadre)
        var meilleur: (etage: Int, profondeur: Double)?
        for pl in projetee.plateaux where pl.etage < geometrie.rayons.count && SceneProjetee.contient(pl.polygone, p) {
            let point = proj.sol(p, hauteur: geometrie.centrePlateau(pl.etage, t).y)
            let d = point.map { proj.profondeur($0) } ?? pl.profondeur
            if d < meilleur?.profondeur ?? .infinity { meilleur = (pl.etage, d) }
        }
        return meilleur?.etage
    }

    /// Un clic sur ce disque fait quelque chose (polissage C, section 5.4) : sauf celui de l'etage isole, entre ses
    /// pieces ; dans une maison d'un seul plateau, seulement depuis une piece isolee, pour remonter.
    func disqueCliquable(_ e: Int) -> Bool {
        clicEtage(e, disque: true) != .rien
    }

    /// Ce que fait un clic sur le nom ou le disque du plateau `e` (`Isolement.clicEtage`) : la regle du clic et de la
    /// main du pointeur.
    private func clicEtage(_ e: Int, disque: Bool) -> Isolement.ClicEtage {
        guard let scene, e < scene.etages.count else { return .rien }
        return isolement.clicEtage(scene.etages[e].id, disque: disque, plusieursPlateaux: scene.etages.count > 1,
                                   pieceIsolee: estIsolee)
    }

    /// Piece sous un point : son nom (le nom et le compte de ses appareils), sinon sa boite, la plus proche
    /// (verification du 02/10 : en 3D, les boites sont petites, et l'on clique volontiers sur le nom). Le nom,
    /// dessine par-dessus les boites, l'emporte sur celle d'une autre piece qu'il recouvre.
    func pieceSous(_ p: CGPoint) -> Int? {
        for l in etiquettes where l.vu && l.rect.contains(p) {
            if case .piece(let i) = l.genre { return i }
        }
        return projetee?.piece(sous: p)
    }

    /// Clic droit (polissage C, section 1.3) : le nom d'un etage, a 2 points pres, ou son disque, hors des pieces et
    /// des appareils, par la cle de son plateau ; le fond, hors de tout cela ; rien sur une piece ou un appareil.
    func cible(en p: CGPoint) -> CibleMenu {
        if let e = nomEtageSous(p, marge: 2) { return cleEtage(e).map(CibleMenu.etage) ?? .aucune }
        if noeudSous(p) != nil || pieceSous(p) != nil { return .aucune }
        if let e = disqueSous(p) { return cleEtage(e).map(CibleMenu.etage) ?? .aucune }
        return .fond
    }

    /// Un glisser, a chaque deplacement du pointeur ; `option` : ⌥ tenue, lue a l'appui seulement (polissage C,
    /// section 6) : en 3D, la vue glisse alors dans le plan de l'ecran, depuis le fond, un disque ou une piece, qui ne
    /// bouge pas ; un vol en cours s'arrete, et pendant le geste la camera n'obeit qu'au pointeur (`deplaceDansLEcran`).
    /// Relacher ⌥ en route ne change rien. En 2D, ⌥ ne change rien.
    func glisser(_ p: CGPoint, depart d: CGPoint, option: Bool = false) {
        // Un geste reste d'un glisser annule (sans relachement), et celui-ci part d'ailleurs : il est clos.
        if geste != nil, d != departGeste { terminerGeste() }
        if geste == nil {
            bouge = false
            abandonApresGlisser = false
            precedent = d
            departGeste = d
            if option && troisD && t == 1 && envol == nil && fondu == nil {
                vol = nil
                viseeVol = nil
                geste = .ecran(orbite)
            } else if !estIsolee, !enMouvement, let scene, let i = projetee?.piece(sous: d), i < scene.pieces.count,
                      indiceEtageIsole.map({ $0 == scene.pieces[i].etage }) ?? true {
                // Les pieces de l'etage isole se glissent ; celles des autres etages se cliquent seulement. Une piece en
                // route vers sa place y est posee, avec ses noeuds : elle suit le pointeur depuis sa place.
                transition?.oublier(pieces: [scene.pieces[i].id], noeuds: Set(scene.pieces[i].noeuds))
                if let tr = transition { posesAffichees = tr.poses(a: Self.maintenant()) }
                geste = .piece(scene.pieces[i].id, hauteur: centrePiece(i)?.y ?? 0)
            } else {
                geste = .fond
            }
            majCurseur()
        }
        if !bouge && hypot(p.x - d.x, p.y - d.y) < 5 { return }
        bouge = true
        defer { precedent = p }
        guard !enMouvement, let geste else { return }
        let proj = ProjectionScene(orbite, cadre: cadre)
        switch geste {
        case .ecran(let o):
            orbite = CameraScene.deplacerDansLEcran(o, glisse: CGSize(width: p.x - d.x, height: p.y - d.y), cadre: cadre)
            vueTouchee = true
        case .piece(let id, let h):
            guard let scene, let i = scene.pieces.firstIndex(where: { $0.id == id }), i < positions.count,
                  i < cartes.count, scene.pieces[i].etage < geometrie.rayons.count,
                  let a = proj.sol(precedent, hauteur: h), let b = proj.sol(p, hauteur: h) else { return }
            var pos = positions[i] + SIMD2(b.x - a.x, b.z - a.z)
            let r = max(0, geometrie.rayons[scene.pieces[i].etage] - 0.5 * hypot(cartes[i].largeur, cartes[i].profondeur))
            if simd_length(pos) > r { pos = simd_length(pos) > 0 ? simd_normalize(pos) * r : .zero }
            positions[i] = pos
        case .fond:
            if t == 0 {
                if let a = proj.sol(precedent, hauteur: orbite.cible.y), let b = proj.sol(p, hauteur: orbite.cible.y) {
                    orbite.cible += a - b
                    vueTouchee = true
                }
            } else {
                let h = max(1, Double(taille.height))
                rotationEnAttente.x -= 2 * .pi * Double(p.x - precedent.x) / h
                rotationEnAttente.y -= 2 * .pi * Double(p.y - precedent.y) / h
            }
        }
        reveiller()
    }

    /// Fin d'un glisser, ou clic. Deux clics sur le fond ou sur un disque, a moins de l'intervalle du double-clic
    /// de macOS et de 5 points : le second est un double-clic ; le premier a agi comme un clic simple. Une
    /// scene recue pendant le geste s'applique ensuite, avec la place gardee de la piece glissee.
    func relacher(_ p: CGPoint, a instant: Double = MoteurPieces.maintenant()) {
        let g = geste
        let clic = !bouge && !(g == nil && abandonApresGlisser)
        geste = nil
        bouge = false
        abandonApresGlisser = false
        majCurseur()
        if case .piece(let id, _)? = g, !clic {
            garder(id)
        } else if clic {
            let fond = switch cibleClic(en: p) {
            case .fond, .disque: true
            default: false
            }
            if fond, let c = clicFond, instant - c.instant <= NSEvent.doubleClickInterval,
               hypot(p.x - c.point.x, p.y - c.point.y) <= 5 {
                clicFond = nil
                if envol == nil, fondu == nil { doubleCliquer() }
            } else {
                clicFond = fond ? (instant, p) : nil
                cliquer(p)
            }
        }
        if !occupe, let e = attente { appliquer(e) }
        reveiller()
    }

    /// Geste annule : SwiftUI remet l'etat du geste a zero sans appeler `onEnded` (la vue quitte la
    /// fenetre pendant le geste, ou le geste est interrompu). Il est clos sans clic, la piece glissee
    /// garde sa place, et la scene en attente s'applique. Apres un relachement, plus de geste : rien.
    func abandonnerGeste() {
        guard geste != nil else { return }
        abandonApresGlisser = bouge
        terminerGeste()
        if !occupe, let e = attente { appliquer(e) }
        reveiller()
    }

    /// Clot un geste reste ouvert (glisser annule, sans relachement) : la piece glissee garde sa place,
    /// sans clic. Depuis `glisser`, la scene en attente s'applique a la fin du geste suivant (sinon les
    /// indices de la projection, qui a servi a le commencer, periment) ; depuis `abandonnerGeste`, elle
    /// s'applique tout de suite apres, sauf pendant un mouvement.
    private func terminerGeste() {
        if case .piece(let id, _)? = geste, bouge { garder(id) }
        geste = nil
        bouge = false
        majCurseur()
    }

    /// Clic sans glisser, selon sa cible (polissage C, sections 5.1 et 5.4) : un appareil ou son nom ouvre sa fiche ;
    /// une piece ou son nom l'isole (en piece isolee, une autre piece y mene, meme pendant le vol) ; le nom ou le
    /// disque d'un etage l'isole ; a cote, la fiche se ferme et la vue remonte d'ou elle vient. Rien pendant l'envol.
    func cliquer(_ p: CGPoint) {
        guard envol == nil, fondu == nil else { return }
        switch cibleClic(en: p) {
        case .appareil(let n):
            selection = n
        case .piece(let i):
            if !(focus == i && sCible == 1) { isoler(i) }
        case .nomEtage(let e):
            cliquerEtage(e, disque: false)
        case .disque(let e):
            cliquerEtage(e, disque: true)
        case .fond:
            selection = nil
            remonter(clavier: false)
        }
    }

    /// Clic sur le nom ou le disque d'un etage : il l'isole ; son propre disque, l'etage isole, entre les pieces, ne
    /// fait rien. Maison d'un seul plateau : seulement depuis une piece isolee, pour remonter a la maison.
    private func cliquerEtage(_ e: Int, disque: Bool) {
        switch clicEtage(e, disque: disque) {
        case .isoler: allerEtage(e)
        case .maison: versMaison()
        case .rien: break
        }
    }

    /// La molette zoome, sauf pendant un vol et pendant ⌥ + glisser : elle est alors ignoree, non differee. Au-dessus
    /// d'un element pose sur la vue (`p`, dans la vue : la fiche, la legende, la ligne des capsules, la colonne du haut),
    /// elle n'est pas prise (faux) : l'evenement leur revient (polissage D, section 3).
    @discardableResult
    func molette(_ dy: Double, precis: Bool, en p: CGPoint? = nil) -> Bool {
        if let p, surInterface(p) { return false }
        guard !enMouvement, !deplaceDansLEcran else { return true }
        zoomer(precis ? -dy * 0.004 : -dy * 0.08, en: curseur)
        return true
    }

    /// Le point `p` de la vue est sur un element pose sur elle.
    func surInterface(_ p: CGPoint) -> Bool {
        cadresInterface.values.contains { $0.contains(p) }
    }

    /// Le pincement zoome de son increment depuis le dernier `m`, sauf pendant un vol et pendant ⌥ + glisser : il est
    /// alors ignore, mais suivi, pour que celui qui continue apres ne saute pas de ce qu'il a fait pendant.
    func pincer(_ m: Double, en p: CGPoint) {
        let l = -log(max(0.05, m) / max(0.05, dernierPincement))
        dernierPincement = m
        guard !enMouvement, !deplaceDansLEcran else { return }
        zoomer(l, en: p)
    }

    func finPincement() { dernierPincement = 1 }

    /// Zoom amorti ; en 2D, vers le point sous le curseur.
    private func zoomer(_ l: Double, en p: CGPoint?) {
        ancreZoom = nil
        if t == 0, let p { ancreZoom = ProjectionScene(orbite, cadre: cadre).sol(p, hauteur: orbite.cible.y) }
        zoomEnAttente += l
        vueTouchee = true
        reveiller()
    }

    /// Molette et Echap, dans la fenetre de la vue seulement : un moniteur local (SwiftUI n'a pas
    /// d'evenement de molette brut).
    func ecouter() {
        guard moniteur == nil else { return }
        moniteur = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown, .flagsChanged]) { [weak self] e in
            guard let self else { return e }
            let pris = MainActor.assumeIsolated { self.prendre(e) }
            return pris ? nil : e
        }
    }

    /// Un evenement du moniteur, dans la fenetre de la vue seulement : la molette, au-dessus de la scene (pas d'un element
    /// pose sur elle), et Echap, s'il a quelque chose a faire, sont pris (vrai : le moniteur rend nil) ; ⌥ pressee ou
    /// relachee met a jour la main ouverte (polissage C, section 6) et continue son chemin, comme tout le reste.
    func prendre(_ e: NSEvent) -> Bool {
        guard e.window != nil, e.window === fenetre else { return false }
        return prendre(EvenementVue(e))
    }

    /// Ce que le moniteur lit d'un evenement de la fenetre de la vue.
    struct EvenementVue {
        enum Genre {
            /// La molette : son pas, precis (trackpad) ou non, et le point du pointeur dans la fenetre.
            case molette(dy: Double, precis: Bool, position: CGPoint)
            case echap
            /// ⌥ tenue ou non.
            case option(Bool)
            case autre
        }

        var genre: Genre

        init(_ genre: Genre) {
            self.genre = genre
        }

        init(_ e: NSEvent) {
            switch e.type {
            case .scrollWheel:
                genre = .molette(dy: Double(e.scrollingDeltaY), precis: e.hasPreciseScrollingDeltas, position: e.locationInWindow)
            case .keyDown where e.keyCode == 53:
                genre = .echap
            case .flagsChanged:
                genre = .option(e.modifierFlags.contains(.option))
            default:
                genre = .autre
            }
        }
    }

    /// La meme chose, une fois l'evenement lu.
    func prendre(_ e: EvenementVue) -> Bool {
        switch e.genre {
        case .molette(let dy, let precis, let position):
            return molette(dy, precis: precis, en: vue.map { VuePieces.point(position, dans: $0) })
        case .echap:
            return sortir()
        case .option(let option):
            changerOption(option)
            return false
        case .autre:
            return false
        }
    }

    func arreterEcoute() {
        if let m = moniteur { NSEvent.removeMonitor(m) }
        moniteur = nil
    }
}
```

`MaillageThread/Vues/Pieces/MoteurPieces+Image.swift` (fichier entier) :

```swift
import Foundation
import MaillageCoeur
import SwiftUI
import simd

/// Chaque image du `Canvas`, l'avance de l'etat et l'horloge (polissage D, section 5 : le moteur en fichiers).
extension MoteurPieces {
    // MARK: Image

    /// Une image du `Canvas` : avance l'etat, projette la scene, place les noms, dessine.
    func image(_ ctx: inout GraphicsContext, taille nouvelle: CGSize, echelle: Double, palette: Palette) {
        // Taille ou marges changees : la vue d'ensemble se recadre, sauf si Djoko a zoome ou isole une piece ; une
        // nouvelle zone visible recalcule la grille (polissage C, sections 3.3 et 3.5).
        taille = nouvelle
        let changee = zoneVisible != zoneGrille
        zoneGrille = zoneVisible
        let now = Self.maintenant()
        let m = margesDuCadre(now)
        let voulu = CGRect(x: 0, y: m.haut, width: nouvelle.width, height: max(1, nouvelle.height - m.haut - m.bas))
        if voulu != cadre {
            cadre = voulu
            if aLaVueDEnsemble && !fige { recadrer() }
        }
        if changee && !fige { zoneChangee() }
        if !fige { avancer(now) }
        guard pret, let scene else { return }
        let parts = scene.pieces.map { fk[$0.id] ?? 0 }
        let etat = EtatAnime(t: t, s: s, fk: parts, focus: focus, survol: survol, selection: selection, se: se,
                             ek: scene.etages.map { ek[$0.id] ?? 0 }, survolEtage: survolEtage)
        let p = SceneProjetee(scene: scene, cartes: cartes, positions: positions, geometrie: geometrie, etat: etat,
                              orbite: orbite, cadre: cadre, poses: posesAffichees)
        PlacementNoms.regler(&etiquettes, scene: scene, niveau: p.niveau, survol: survol, selection: selection, focus: focus,
                             isolee: estIsolee, fk: parts, s: s, t: t, se: se, voiles: p.voilesEtages,
                             etageIsole: indiceEtageIsole, survolNomEtage: survolNomEtage)
        let ancres: [CGRect?] = etiquettes.map { l in
            switch l.genre {
            case .noeud(let id): p.ancresNoeuds[id]
            case .piece(let i): p.ancresPieces[i]
            case .etage(let i): p.ancresEtages[i]
            case .maison: p.ancreMaison
            case .ailleurs(let id): p.ancresAilleurs[id]
            }
        }
        var obstacles = p.disques.filter { $0.opacite > 0.5 }.map { d in
            CGRect(x: Double(d.centre.x) - d.rayon, y: Double(d.centre.y) - d.rayon, width: 2 * d.rayon, height: 2 * d.rayon)
        }
        obstacles += cadresInterface.values.map { $0.insetBy(dx: -4, dy: -4) }
        traits = PlacementNoms.placer(&etiquettes, ancres: ancres, obstacles: obstacles, cadre: taille, dt: dt)
        projetee = p
        var g = ctx
        g.opacity = opaciteFondu * opaciteMarges
        RenduCanvas.dessiner(&g, ImagePieces(projetee: p, etiquettes: etiquettes, traits: traits, textes: textes,
                                             apparences: apparences, routeurs: routeurs,
                                             teintesPieces: teintes, selection: selection, echelle: echelle),
                             palette: palette, cache: cache)
        let nouvelle = ligne(p.niveau, ancres: ancres)
        if nouvelle != ligneNiveau {
            // Hors du rendu, sauf pour une capture (rendue d'un trait).
            if fige {
                ligneNiveau = nouvelle
            } else {
                Task { @MainActor [weak self] in self?.ligneNiveau = nouvelle }
            }
        }
        if !fige && !doitContinuer(now) { endormir() }
    }

    /// Le dessin des pastilles : celles de la scene, et celles qui s'effacent, de la scene d'avant.
    private var apparences: [String: DessinNoeud.Apparence] {
        let a = entree?.apparences ?? [:]
        return apparencesParties.isEmpty ? a : a.merging(apparencesParties) { x, _ in x }
    }

    /// Marges du cadre a l'instant `now` : les marges visees, ou en route vers elles quand elles changent, pendant
    /// 0,3 s, ou 0,45 s quand la legende s'ouvre ou se replie (`legendeBasculee`) ; avec « Reduire les animations »,
    /// par un fondu de cette duree (la scene s'efface, les marges sautent a mi-chemin, la scene revient :
    /// `opaciteMarges`) ; tout de suite avant la premiere disposition et pour une capture.
    func margesDuCadre(_ now: Double) -> (haut: CGFloat, bas: CGFloat) {
        let actuelles = margesCadre ?? marges
        let visees = glissement?.arrivee ?? actuelles
        if marges.haut != visees.haut || marges.bas != visees.bas {
            if pret, !fige, margesCadre != nil {
                glissement = GlissementMarges(depart: actuelles, arrivee: marges, debut: now,
                                              duree: dureeAnnoncee ?? Apparition.duree, fondu: reduire)
                // Le glissement demande des images : l'horloge repart, hors du rendu.
                if !anime { Task { @MainActor [weak self] in self?.reveiller() } }
            } else {
                glissement = nil
            }
            dureeAnnoncee = nil
        }
        guard let g = glissement else {
            margesCadre = marges
            opaciteMarges = 1
            return marges
        }
        let q = min(1, max(0, (now - g.debut) / g.duree))
        let m: (haut: CGFloat, bas: CGFloat)
        if g.fondu {
            m = q < 0.5 ? g.depart : g.arrivee
            opaciteMarges = abs(1 - 2 * q)
        } else {
            let e = CGFloat(Apparition.courbe(q))
            m = (haut: g.depart.haut + (g.arrivee.haut - g.depart.haut) * e,
                 bas: g.depart.bas + (g.arrivee.bas - g.depart.bas) * e)
        }
        if q >= 1 {
            glissement = nil
            opaciteMarges = 1
        }
        margesCadre = m
        return m
    }

    /// Les marges du cadre sont en route.
    var margesEnRoute: Bool { glissement != nil }

    /// Les marges du cadre sont en route par un fondu (« Reduire les animations »).
    var margesEnFondu: Bool { glissement?.fondu == true }

    /// La legende s'ouvre ou se replie, d'un clic : le recadrage qui l'accompagne (le prochain changement des
    /// marges) prend sa duree, 0,45 s (`Apparition.dureeLegende`), au lieu des 0,3 s de la fiche et des bandeaux.
    func legendeBasculee() {
        dureeAnnoncee = Apparition.dureeLegende
    }

    /// L'etage vise par l'isolement, dans la scene ; nil : la maison ou une piece.
    var indiceEtageIsole: Int? {
        guard case .etage(let cle) = isolement else { return nil }
        return scene?.etages.firstIndex { $0.id == cle }
    }

    private func ligne(_ niveau: NiveauZoom, ancres: [CGRect?]) -> LigneNiveau {
        if estIsolee, let nom = isolee { return .isolee(nom) }
        if let e = indiceEtageIsole, let nom = textes.etages[e] { return .etageIsole(nom) }
        switch niveau {
        case .pieces: return .pieces
        case .routeurs: return .routeurs
        case .tous:
            let n = PlacementNoms.masques(etiquettes, ancres: ancres, cadre: taille)
            return n > 0 ? .masques(n) : .lisibles
        }
    }

    private func avancer(_ now: Double) {
        dt = instant.map { min(0.1, max(0, now - $0)) } ?? 0
        instant = now
        let basculait = envol != nil || fondu != nil
        defer { if basculait && envol == nil && fondu == nil { basculeFinie() } }
        if let e = envol {
            let q = min(1, max(0, (now - debutEnvol) / CameraScene.dureeEnvol))
            (t, orbite) = e.pose(q, geometrie: geometrie, aspect: aspect)
            if q >= 1 {
                envol = nil
                t = e.arrivee
            }
        }
        if let f = fondu {
            let q = min(1, max(0, (now - f.debut) / CameraScene.dureeFondu))
            if q >= 0.5 && !f.saute {
                t = f.arrivee
                orbite = f.orbite ?? CameraScene.canonique(geometrie, aspect: aspect, u: t)
                fondu?.saute = true
            }
            opaciteFondu = abs(1 - 2 * q)
            if q >= 1 {
                fondu = nil
                opaciteFondu = 1
            }
        }
        if s != sCible {
            let r = min(1, max(0, (now - sDebut) / CameraScene.dureeVol))
            s = sDepart + (sCible - sDepart) * r
            if r >= 1 {
                s = sCible
                if s == 0 { finirRetour() }
            }
        }
        if se != seCible {
            let r = min(1, max(0, (now - seDebut) / CameraScene.dureeVol))
            se = seDepart + (seCible - seDepart) * r
            if r >= 1 {
                se = seCible
                if se == 0 { etageEnVue = nil }
            }
        }
        // Les parts propres, par cle : celle de la piece isolee et celle de l'etage en vue tendent vers 1.
        if let scene {
            let piece = focus.flatMap { $0 < scene.pieces.count && sCible == 1 ? scene.pieces[$0].id : nil }
            func tendre(_ x: Double?, vers c: Double) -> Double {
                var f = x ?? 0
                f += (c - f) * min(1, dt * 3.5)
                return abs(c - f) < 1e-3 ? c : f
            }
            for p in scene.pieces { fk[p.id] = tendre(fk[p.id], vers: p.id == piece ? 1 : 0) }
            for e in scene.etages { ek[e.id] = tendre(ek[e.id], vers: e.id == etageEnVue ? 1 : 0) }
        }
        // Les plateaux et les pieces glissent ; la vue suit ce qu'elle regarde.
        if glissementPlateaux != nil || transition != nil {
            let ancre0 = ancreCamera()
            if glissementPlateaux != nil {
                geometrie = geometrie(a: now)
                if geometrie == geometrieVisee { glissementPlateaux = nil }
            }
            if let tr = transition {
                if tr.finie(a: now) {
                    finirTransition()
                } else {
                    posesAffichees = tr.poses(a: now)
                }
            }
            suivre(depuis: ancre0)
        }
        if let v = vol {
            let q = min(1, max(0, (now - debutVol) / CameraScene.dureeVol))
            orbite = v.orbite(q, depuis: orbite)
            if q >= 1 {
                vol = nil
                viseeVol = nil
            }
        } else if envol == nil && fondu == nil {
            controles()
        }
        // Une grille qui attendait la vue d'ensemble 2D s'y pose.
        if let g = politique.attente, t == 0, aLaVueDEnsemble { poserGrille(g) }
        if !occupe, let e = attente { appliquer(e) }
    }

    /// La rotation lente tourne (`Isolement.rotationLente`), une piece ou un etage isoles compris (polissage D,
    /// section 4.2), sauf pendant un geste : un glisser (⌥ compris), le zoom de la molette en route, un pincement.
    private var rotationLente: Bool {
        Isolement.rotationLente(troisD: troisD, bascule: t, cochee: rotation, reduire: reduire,
                                geste: geste != nil || zoomEnAttente != 0 || dernierPincement != 1)
    }

    /// L'envol ou son fondu fini : le survol, le menu du clic droit et le curseur reprennent sous le pointeur immobile
    /// (polissage D, section 4), hors du rendu.
    private func basculeFinie() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.survoler(self.curseur, option: self.optionTenue)
        }
    }

    /// Rotation lente, rotation amortie, zoom amorti ; rien pendant ⌥ + glisser : ce qui attend reprend au relachement.
    private func controles() {
        guard !deplaceDansLEcran else { return }
        if rotationLente {
            orbite.azimut -= 2 * .pi / CameraScene.dureeTour * dt
        }
        if rotationEnAttente != .zero {
            let pas = rotationEnAttente * (1 - pow(0.95, 60 * dt))
            orbite.azimut += pas.x
            orbite.inclinaison = min(1.45, max(0.15, orbite.inclinaison + pas.y))
            rotationEnAttente -= pas
            if simd_length(rotationEnAttente) < 1e-5 { rotationEnAttente = .zero }
        }
        if zoomEnAttente != 0 {
            var pas = zoomEnAttente * (1 - exp(-dt * 16))
            if abs(zoomEnAttente) < 0.002 { pas = zoomEnAttente }
            let bornes = CameraScene.bornes(geometrie, aspect: aspect, troisD: t == 1, champ: orbite.champ)
            orbite = CameraScene.zoomer(orbite, facteur: pas, ancre: ancreZoom, bornes: bornes)
            zoomEnAttente -= pas
            if orbite.distance <= bornes.lowerBound || orbite.distance >= bornes.upperBound { zoomEnAttente = 0 }
        }
    }

    /// Fin du glissement d'une disposition : tout est pose.
    private func finirTransition() {
        transition = nil
        posesAffichees = PosesScene()
        apparencesParties = [:]
    }

    // MARK: Horloge

    func doitContinuer(_ now: Double) -> Bool {
        // Une scene qui attend la fin d'un glisser s'applique au relachement : pas d'image pour elle.
        if enMouvement || s != sCible || margesEnRoute || glissementPlateaux != nil || transition != nil
            || (attente != nil && geste == nil) {
            return true
        }
        if se != seCible || fk.values.contains(where: { $0 != 0 && $0 != 1 }) || ek.values.contains(where: { $0 != 0 && $0 != 1 }) {
            return true
        }
        if rotationLente { return true }
        if zoomEnAttente != 0 || rotationEnAttente != .zero || (geste != nil && bouge) { return true }
        if now - derniereActivite < 0.6 { return true }
        return etiquettes.contains { $0.envie > 0 }
    }

    /// Arrete l'horloge apres l'image (pas pendant le rendu).
    private func endormir() {
        guard anime else { return }
        Task { @MainActor [weak self] in
            guard let self, !self.doitContinuer(Self.maintenant()) else { return }
            self.anime = false
        }
    }

    func reveiller() {
        derniereActivite = Self.maintenant()
        if !anime {
            // Pas de temps nul a la premiere image : sinon le zoom amorti ferait un bond.
            instant = nil
            anime = true
        }
    }
}
```

`MaillageThread/Vues/Pieces/MoteurPieces+Poses.swift` (fichier entier) :

```swift
import Foundation
import MaillageCoeur
import simd

/// Les etats poses a la main, pour les captures et les tests (polissage D, section 5 : le moteur en fichiers).
extension MoteurPieces {
    // MARK: Etats poses a la main (captures, tests)

    func poserBascule(_ q: Double) {
        t = CameraScene.rampe(q)
        troisD = q > 0
        orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
    }

    /// Une piece isolee, au bout de son vol ; `depuisEtage` : ouverte depuis son etage isole (sa provenance).
    func poserIsolement(_ i: Int, depuisEtage: Bool = false) {
        guard let scene, i < scene.pieces.count else { return }
        let etage = scene.etages[scene.pieces[i].etage].id
        isolement = .piece(scene.pieces[i].id, provenance: depuisEtage ? etage : nil)
        focus = i
        isolee = textes.pieces[i]?.nom
        s = 1
        sCible = 1
        fk[scene.pieces[i].id] = 1
        if scene.etages.count > 1 {
            etageEnVue = etage
            se = 1
            seCible = 1
            ek[etage] = 1
        }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        majFil()
        if let v = volVersPiece(i) { orbite = v.orbite(1, depuis: orbite) }
    }

    /// Un etage isole, au bout de son vol.
    func poserEtageIsole(_ e: Int) {
        guard let scene, scene.etages.count > 1, e < scene.etages.count else { return }
        let cle = scene.etages[e].id
        isolement = .etage(cle)
        etageEnVue = cle
        se = 1
        seCible = 1
        ek[cle] = 1
        majFil()
        orbite = volVersEtage(e).orbite(1, depuis: orbite)
    }

    func poserSurvol(_ id: String?) { survol = id }

    /// Le glissement d'une disposition, pose a `q` (de 0 a 1) de son temps, sans horloge : les poses des pieces et des
    /// noeuds, et les plateaux qui glissent avec eux.
    func poserTransition(_ q: Double) {
        guard let tr = transition else { return }
        posesAffichees = tr.poses(a: tr.debut + q * TransitionScene.duree)
        if let gl = glissementPlateaux { geometrie = geometrie(a: gl.debut + q * max(gl.duree2D, gl.duree3D)) }
    }

    /// Le glissement d'une disposition et celui des plateaux, commences `dt` secondes plus tot (tests) : l'image suivante
    /// les avance d'autant, par l'horloge.
    func reculerTransition(de dt: Double) {
        transition?.debut -= dt
        glissementPlateaux?.debut -= dt
    }

    func poserAzimut(_ decalage: Double) { orbite.azimut += decalage }

    func poserInclinaison(_ i: Double) { orbite.inclinaison = i }

    /// Centre du bloc d'une piece, dans le monde ; dans la geometrie de l'image, ou dans `g`.
    func centrePiece(_ i: Int, dans g: GeometrieMaison? = nil) -> SIMD3<Double>? {
        guard let scene, i < scene.pieces.count, i < positions.count else { return nil }
        let g = g ?? geometrie
        // En route (polissage D, section 1) : sa pose affichee.
        if let pose = posesAffichees.pieces[scene.pieces[i].id],
           let m = PosesScene.centre(pose.ancres, geometrie: g, plateaux: plateaux(scene), t: t) {
            return SIMD3(m.x, m.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, m.z)
        }
        let c = g.centrePlateau(scene.pieces[i].etage, t)
        return SIMD3(c.x + positions[i].x, c.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, c.z + positions[i].y)
    }

    /// L'indice de chaque plateau de la scene, par cle.
    private func plateaux(_ scene: ScenePieces) -> [String: Int] {
        Dictionary(scene.etages.indices.map { (scene.etages[$0].id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Zoom a l'echelle `k` (points par unite a la cible, divises par 24), vers le point `vers`.
    func poserZoom(echelle k: Double, vers a: SIMD3<Double>?) {
        let k0 = ProjectionScene(orbite, cadre: cadre).pxParUnite(orbite.cible) / CartesPieces.px
        let f = k0 / k
        if let a { orbite.cible = a + (orbite.cible - a) * f }
        orbite.distance *= f
        vueTouchee = true
    }

    /// Pose le cadre sans image, et la grille de cette zone visible, tout de suite (captures, tests).
    func poserTaille(_ nouvelle: CGSize) {
        taille = nouvelle
        zoneGrille = zoneVisible
        margesCadre = marges
        glissement = nil
        cadre = CGRect(x: 0, y: marges.haut, width: nouvelle.width,
                       height: max(1, nouvelle.height - marges.haut - marges.bas))
        guard pret, let scene else { return }
        politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: true)
        glissementPlateaux = nil
        politique.oublierAttente()
        geometrieVisee = geometriePour(scene)
        geometrie = geometrieVisee
        recadrer()
    }
}
```

`MaillageThread/Vues/Pieces/MoteurPieces+Scene.swift` (fichier entier) :

```swift
import Foundation
import MaillageCoeur
import SwiftUI

/// La scene et sa disposition, les places gardees et le menu du clic droit (polissage D, section 5 : le moteur
/// en fichiers). Les membres que d'autres fichiers du moteur lisent ou ecrivent ne sont plus prives.
extension MoteurPieces {
    // MARK: Scene et disposition

    /// Nouvelle scene : appliquee tout de suite, ou a la fin du mouvement en cours (envol, vol, fondu)
    /// ou du glisser. Si ses etages, ses pieces, ses noeuds ou leurs noms changent, la disposition est
    /// recalculee hors du fil principal ; l'ancienne reste affichee pendant ce temps.
    func recevoir(_ e: EntreeScene) {
        if occupe {
            attente = e
            return
        }
        appliquer(e)
    }

    func appliquer(_ e: EntreeScene) {
        attente = nil
        let cle = e.cleDisposition
        if cle == cleCalculee {
            calcul?.cancel()
            enCalcul = nil
            installer(e)
            return
        }
        // Meme structure que la disposition en calcul : elle vaudra pour cette scene.
        if enCalcul?.cleDisposition == cle {
            enCalcul = e
            return
        }
        calculer(e)
    }

    /// Lance le calcul de la disposition d'une scene, hors du fil principal, avec les places gardees
    /// du moment ; un calcul en cours est abandonne.
    private func calculer(_ e: EntreeScene) {
        calcul?.cancel()
        enCalcul = e
        let cle = e.cleDisposition
        let cartes = cartesPour(e)
        let fixees = places.fixees(e.scene, domicile: e.domicile)
        let scene = e.scene
        calcul = Task { [weak self] in
            let d = await Task.detached(priority: .userInitiated) {
                DispositionPieces(scene: scene, cartes: cartes, fixees: fixees)
            }.value
            guard !Task.isCancelled, let self else { return }
            self.retenir(d, scene: scene, cartes: cartes, cle: cle)
        }
    }

    /// La meme chose, sur le fil principal (captures, tests).
    func installerMaintenant(_ e: EntreeScene) {
        calcul?.cancel()
        let cartes = cartesPour(e)
        let d = DispositionPieces(scene: e.scene, cartes: cartes, fixees: places.fixees(e.scene, domicile: e.domicile))
        enCalcul = e
        retenir(d, scene: e.scene, cartes: cartes, cle: e.cleDisposition)
    }

    /// Cartes des pieces d'une scene, d'apres les noms mesures des noeuds, avec la place de tous leurs badges possibles
    /// (polissage D, section 2) : un badge qui change ne change pas la carte.
    private func cartesPour(_ e: EntreeScene) -> [CartesPieces.Carte] {
        var largeurs: [String: Double] = [:]
        for n in e.scene.noeuds {
            largeurs[n.id] = mesure.reserve(n.libelle, routeur: n.rang <= 2, pile: n.pile).width
        }
        return CartesPieces.cartes(e.scene, largeurs: largeurs)
    }

    /// Une disposition calculee pour `scene` : gardee par cles (piece, etage), d'apres cette scene, dont
    /// elle suit les indices (une scene plus recente de meme structure peut ranger ses etages, donc ses
    /// pieces, dans un autre ordre) ; puis posee avec la derniere scene de cette structure, si une scene
    /// d'une autre structure ne l'a pas depassee ; a la fin du mouvement ou du glisser en cours, s'il y
    /// en a un.
    private func retenir(_ d: DispositionPieces, scene: ScenePieces, cartes: [CartesPieces.Carte],
                         cle: EntreeScene.CleDisposition) {
        guard let e = enCalcul, e.cleDisposition == cle else { return }
        placesCalculees = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { (scene.pieces[$0].id, d.positions[$0]) })
        rayonsCalcules = Dictionary(scene.etages.indices.map { (scene.etages[$0].id, d.rayons[$0]) },
                                    uniquingKeysWith: { a, _ in a })
        cartesCalculees = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { (scene.pieces[$0].id, cartes[$0]) })
        cleCalculee = cle
        enCalcul = nil
        if occupe {
            if attente == nil { attente = e }
            return
        }
        installer(e)
    }

    /// Pose une scene sur la disposition gardee : positions et rayons retrouves par cles, noms,
    /// piece isolee.
    private func installer(_ e: EntreeScene) {
        let scene = e.scene
        let ancienFocus = focus.flatMap { $0 < clesPieces.count ? clesPieces[$0] : nil }
        // Des niveaux changes (le menu du clic droit) : les plateaux glissent vers leur nouvelle place (polissage C,
        // section 1.3) ; a la vue d'ensemble 2D, la grille se recalcule, sinon elle l'attend.
        let anciens = entree?.scene.etages.map(\.id) ?? []
        let niveauxChanges = pret && entree?.scene.niveaux != scene.niveaux
        let ensemble = aLaVueDEnsemble && t == 0
        let image = geometrie
        // La pose affichee de la scene d'avant, et sa pose d'arrivee (polissage D, section 1).
        let avant = entree.map { PosesScene(scene: $0.scene, cartes: cartes, positions: positions) }
        let affichee = avant?.recouvertes(par: posesAffichees)
        let rayonsAvant = entree.map { Dictionary(zip($0.scene.etages.map(\.id), geometrieVisee.rayons).map { ($0, $1) },
                                                  uniquingKeysWith: { a, _ in a }) }
        let ancienne = entree
        entree = e
        // Un autre ordre des plateaux : le disque et le nom d'etage survoles, des indices, en designeraient
        // d'autres ; le prochain mouvement du pointeur les reprend.
        if scene.etages.map(\.id) != anciens {
            survolEtage = nil
            survolNomEtage = nil
        }
        cartes = scene.pieces.map { cartesCalculees[$0.id] ?? CartesPieces.carte([]) }
        positions = scene.pieces.map { placesCalculees[$0.id] ?? .zero }
        // Une nouvelle disposition glisse (polissage D, section 1) : de la pose affichee a la nouvelle, en 0,9 s ; une
        // disposition qui ne change rien laisse le glissement en cours. Avec « Reduire les animations », tout de suite.
        let arrivee = PosesScene(scene: scene, cartes: cartes, positions: positions)
        if pret, let affichee, let avant, arrivee != avant || transition == nil {
            transition = TransitionScene(de: affichee, vers: arrivee, a: Self.maintenant(), reduire: reduire)
            if let tr = transition {
                posesAffichees = tr.poses(a: tr.debut)
                apparencesParties = (ancienne?.apparences ?? [:]).merging(apparencesParties) { a, _ in a }
            } else {
                posesAffichees = PosesScene()
                apparencesParties = [:]
            }
        }
        // Les rayons changent sans les niveaux : la grille se rechoisit, a la vue d'ensemble 2D, avec l'hysteresis ;
        // sinon elle attend (polissage D, section 4).
        let rayonsChanges = pret && !niveauxChanges
            && Dictionary(zip(scene.etages.map(\.id), rayons(scene)).map { ($0, $1) }, uniquingKeysWith: { a, _ in a }) != rayonsAvant
        if grille && (!pret || (niveauxChanges && ensemble)) {
            politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: false)
        } else if niveauxChanges {
            politique.attendre(PolitiqueGrille.niveaux)
        } else if rayonsChanges && grille {
            if ensemble {
                politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: true)
            } else {
                politique.attendre(PolitiqueGrille.redimensionnement)
            }
        }
        let glisse = pret ? TransitionScene.duree : 0
        viser(geometriePour(scene), depuis: anciens, duree2D: niveauxChanges ? CameraScene.dureeCases : glisse,
              duree3D: niveauxChanges ? CameraScene.dureeNiveaux : glisse)
        // Les parts de l'isolement sont gardees par cle (triage A, n° 9) : un releve recu pendant un fondu ne remet pas
        // la piece a pleine taille. L'etage en vue suit ce que vise la vue (polissage C, section 5) : celui de la piece
        // isolee, qui a pu changer de zone. Une piece isolee qui disparait rend la maison, comme avant les etages :
        // l'etage est relache, comme a la bascule, et la vue d'ensemble se recadre (plus bas). Un etage isole qui
        // disparait rend aussi la maison.
        let clesPieces = Set(scene.pieces.map(\.id)), clesEtages = Set(scene.etages.map(\.id))
        fk = fk.filter { clesPieces.contains($0.key) }
        ek = ek.filter { clesEtages.contains($0.key) }
        isolement = isolement.recaler(pieces: clesPieces, etages: clesEtages)
        if let cle = ancienFocus, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            focus = i
            if case .piece = isolement, scene.etages.count > 1 { viserEtage(scene.etages[scene.pieces[i].etage].id) }
        } else if focus != nil {
            focus = nil
            s = 0
            sCible = 0
            isolee = nil
            if isolement == .maison {
                etageEnVue = nil
                se = 0
                seCible = 0
                ek = [:]
            }
        }
        if let k = etageEnVue, !clesEtages.contains(k) {
            etageEnVue = nil
            se = 0
            seCible = 0
        }
        textes = Self.textes(e, focus: focus)
        routeurs = Set(scene.noeuds.filter { $0.rang <= 2 }.map(\.id))
        teintes = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { ($0, scene.pieces[$0].teinte) })
        construireEtiquettes()
        majFil()
        if !pret {
            pret = true
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        } else if !vueTouchee && sansIsolement {
            recadrer()
        } else if niveauxChanges && glissementPlateaux == nil {
            // Des niveaux changes, avec « Reduire les animations » : les plateaux sont poses tout de suite
            // (section 1.3). La vue isolee ou zoomee suit ce qu'elle regarde, d'un coup, depuis sa place au depart du
            // glissement qu'il n'y a pas : comme le glissement le lui fait suivre image apres image (`suivre`), sans
            // « Reduire ».
            suivre(depuis: ancreCamera(dans: depart(image, anciens: anciens, vers: geometrie)))
        }
        reveiller()
    }

    /// Textes des noms : libelles, pieces (nom, compte), etages, maison, reperes « ailleurs ».
    static func textes(_ e: EntreeScene, focus: Int?) -> TextesScene {
        var t = TextesScene()
        t.noeuds = e.libelles
        for (i, p) in e.scene.pieces.enumerated() {
            t.pieces[i] = TextesScene.Piece(nom: LibellesNoeuds.nom(p.nom, libelles: e.libelles),
                                            compte: LibellesNoeuds.compte(p.noeuds.count))
        }
        for (i, et) in e.scene.etages.enumerated() { t.etages[i] = LibellesNoeuds.nom(et.nom) }
        t.maison = String(localized: "⌂ Maison")
        if let f = focus {
            for a in SceneProjetee.reperes(e.scene, focus: f) {
                t.ailleurs[a.enfant] = LibellesNoeuds.ailleurs(a, scene: e.scene, libelles: e.libelles)
            }
        }
        return t
    }

    /// Cle d'un nom, qui ne depend pas des indices de la scene.
    private func cle(_ g: Etiquette.Genre) -> String {
        switch g {
        case .noeud(let id): "n:" + id
        case .piece(let i): "p:" + (i < clesPieces.count ? clesPieces[i] : "")
        case .etage(let i): "e:" + (i < clesEtages.count ? clesEtages[i] : "")
        case .maison: "m"
        case .ailleurs(let id): "a:" + id
        }
    }

    /// Noms de la scene, dans l'ordre de la maquette (appareils, etages, pieces, maison, reperes) ;
    /// chacun garde son etat de placement d'une scene a l'autre.
    func construireEtiquettes() {
        guard let scene else { return }
        var anciennes: [String: Etiquette] = [:]
        for l in etiquettes { anciennes[cle(l.genre)] = l }
        clesPieces = scene.pieces.map(\.id)
        clesEtages = scene.etages.map(\.id)
        var l: [Etiquette] = []
        func ajouter(_ genre: Etiquette.Genre, _ taille: CGSize) {
            var e = Etiquette(genre, taille: taille)
            if let a = anciennes[cle(genre)] {
                e.place = a.place
                e.envie = a.envie
                e.vu = a.vu
                e.rect = a.rect
                e.rectAvant = a.rectAvant
            }
            l.append(e)
        }
        for n in scene.noeuds {
            ajouter(.noeud(n.id), mesure.noeud(textes.noeuds[n.id] ?? LibellesNoeuds.Libelle(texte: n.id), routeur: n.rang <= 2))
        }
        for i in scene.etages.indices { ajouter(.etage(i), mesure.etage(textes.etages[i] ?? "")) }
        for i in scene.pieces.indices {
            let t = textes.pieces[i] ?? TextesScene.Piece(nom: "", compte: "")
            ajouter(.piece(i), mesure.piece(nom: t.nom, compte: t.compte))
        }
        ajouter(.maison, mesure.maison(textes.maison))
        for (id, texte) in textes.ailleurs.sorted(by: { $0.key < $1.key }) { ajouter(.ailleurs(id), mesure.ailleurs(texte)) }
        etiquettes = l
    }

    // MARK: Places gardees et ordre des etages

    private func enregistrer() {
        guard let fichierPlaces else { return }
        do {
            try places.ecrire(dans: fichierPlaces)
        } catch {
            Self.journal.error("places des pieces non ecrites : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Garde la place d'une piece qu'on vient de glisser : elle est desormais fixee. Un calcul en cours
    /// ne la connait pas : il est relance avec elle (sinon, a sa fin, la piece sauterait a la place
    /// qu'il lui donne). Une place non finie (camera degeneree) n'est pas gardee.
    func garder(_ id: String) {
        guard let e = entree, let i = e.scene.pieces.firstIndex(where: { $0.id == id }), i < positions.count,
              positions[i].x.isFinite, positions[i].y.isFinite else { return }
        let p = e.scene.pieces[i]
        places.garder(positions[i], piece: p.id, etage: e.scene.etages[p.etage].id, domicile: e.domicile)
        placesCalculees[p.id] = positions[i]
        enregistrer()
        if let c = enCalcul { calculer(c) }
    }

    // MARK: Menu du clic droit (polissage C, section 1.3)

    /// La scene la plus recente : celle qui attend la fin d'un mouvement ou d'un geste, sinon celle du calcul en cours,
    /// sinon celle affichee. Apres un choix du menu, elle le porte avant la scene affichee.
    private var sceneRecente: EntreeScene? { attente ?? enCalcul ?? entree }

    /// Le menu du nom ou du disque du plateau `cle`, sur la scene la plus recente : ses coches et ses grises suivent le
    /// dernier choix, meme quand la scene de ce choix attend encore. Il lit la version de cette scene, observee : une
    /// vue qui le montre se refait quand elle change, meme si la cible du clic droit, elle, ne change pas.
    func menuEtage(_ cle: String) -> MenuEtage? {
        _ = versionScene
        guard let scene = sceneRecente?.scene, let niveau = scene.niveaux.niveau(cle) else { return nil }
        let n = scene.niveaux, estPrincipal = n.estPrincipal(cle)
        func nom(_ c: String) -> String {
            scene.etages.firstIndex { $0.id == c }.map { LibellesNoeuds.nom(scene.etages[$0].nom) } ?? c
        }
        let niveaux = n.liste.indices.filter { !(estPrincipal && $0 == niveau) }.map { i in
            MenuEtage.Niveau(principal: n.liste[i][0], nom: nom(n.liste[i][0]), coche: !estPrincipal && i == niveau)
        }
        return MenuEtage(nom: nom(cle), monter: estPrincipal && niveau < n.liste.count - 1,
                         descendre: estPrincipal && niveau > 0, niveaux: niveaux, aCote: !estPrincipal,
                         dehors: n.dehors(cle))
    }

    /// Un choix du menu, calcule sur la scene la plus recente et sur les choix gardes : le nouvel ordre des plateaux et
    /// les nouveaux choix de niveau, gardes ; la scene suivante les prend (`EntreeScene`), et les plateaux glissent vers
    /// leur nouvelle place. Sur la scene affichee, un choix fait pendant que la scene du precedent attend (un vol, le
    /// calcul de sa disposition) defaisait le precedent.
    private func ranger(_ operation: (Niveaux, [String: PlacesGardees.ACote]) -> Rangement?) {
        guard let e = sceneRecente, let r = operation(e.scene.niveaux, places.maison(e.domicile).aCote) else { return }
        places.ranger(r, domicile: e.domicile)
        enregistrer()
    }

    /// La cle du plateau `e` de la scene affichee, celle des noms et de la projection.
    func cleEtage(_ e: Int) -> String? {
        guard let scene, scene.etages.indices.contains(e) else { return nil }
        return scene.etages[e].id
    }

    /// « Monter d'un etage » (+1) ou « Descendre d'un etage » (-1) : le niveau entier de l'etage `cle`, zones a cote
    /// comprises, change de place avec son voisin.
    func deplacerEtage(_ cle: String, de pas: Int) {
        ranger { $0.deplacer(cle, de: pas, choix: $1) }
    }

    /// La meme chose pour le plateau `e` de la scene affichee.
    func deplacerEtage(_ e: Int, de pas: Int) {
        if let cle = cleEtage(e) { deplacerEtage(cle, de: pas) }
    }

    func peutDeplacerEtage(_ e: Int, de pas: Int) -> Bool {
        cleEtage(e).flatMap(menuEtage).map { pas > 0 ? $0.monter : $0.descendre } ?? false
    }

    /// « Au meme niveau que » le niveau de l'etage principal `principal` (sa cle), dans la maison.
    func mettreAuNiveau(_ cle: String, de principal: String) {
        ranger { n, choix in n.niveau(principal).flatMap { n.rejoindre(cle, niveau: $0, choix: choix) } }
    }

    /// « Hors de la maison », coche ou non.
    func basculerDehors(_ cle: String) {
        ranger { $0.basculerDehors(cle, choix: $1) }
    }

    /// « Sur son propre niveau ».
    func mettreSurSonNiveau(_ cle: String) {
        ranger { $0.propreNiveau(cle, choix: $1) }
    }

    /// « Replacer les pieces automatiquement » : oublie les places gardees de la maison (pas l'ordre
    /// des etages) et recalcule la disposition de la scene la plus recente (celle qui attend la fin d'un
    /// mouvement ou d'un geste, sinon celle du calcul en cours, sinon celle affichee) ; l'ancienne reste
    /// affichee pendant ce temps.
    func replacerPieces() {
        guard let e = sceneRecente else { return }
        places.replacer(domicile: e.domicile)
        enregistrer()
        cleCalculee = nil
        enCalcul = nil
        appliquer(e)
    }
}
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    private(set) var troisD: Bool
    var rotation = true
    /// Horloge en marche : seulement pendant un mouvement, et 0,6 s apres.
    private(set) var anime = true
    /// Nom de la piece isolee ; nil sinon.
    private(set) var isolee: String?
    /// Ce que montre la vue, et sa provenance (polissage C, section 5) ; le fil qui le dit.
    private(set) var isolement = Isolement.maison
    private(set) var fil = Fil()
    private(set) var curseurForme = Curseur.fleche
    var selection: String?
    private(set) var ligneNiveau = LigneNiveau.lisibles
    private(set) var cibleMenu = CibleMenu.aucune
    /// Version de la scene la plus recente (`sceneRecente`), observee : elle change avec elle, a chaque scene
    /// recue, en calcul ou posee. Le menu du clic droit la lit (`menuEtage`) : rouvert sur la meme cible apres un
    /// choix, il suit la scene de ce choix, que SwiftUI ne voit pas (relecture finale, Important 1).
    private(set) var versionScene = 0
    private(set) var places: PlacesGardees
    /// La premiere disposition est calculee.
    private(set) var pret = false
    /// « Reduire les animations » (accessibilite de macOS).
    var reduire = false {
        didSet { reveiller() }
    }

    nonisolated static let journal = Logger(subsystem: "fr.djoko.maillage", category: "pieces")

    // MARK: Etat non observe

    @ObservationIgnored private let fichierPlaces: URL?
    /// Scene affichee, posee sur sa disposition.
    @ObservationIgnored private(set) var entree: EntreeScene? {
        didSet { versionScene &+= 1 }
    }
    /// Scene recue pendant un mouvement ou un glisser : appliquee a sa fin.
    @ObservationIgnored private var attente: EntreeScene? {
        didSet { versionScene &+= 1 }
    }
    /// Scene dont la disposition se calcule : `entree` reste affichee jusqu'a la fin du calcul.
    @ObservationIgnored private var enCalcul: EntreeScene? {
        didSet { versionScene &+= 1 }
    }
    @ObservationIgnored private var calcul: Task<Void, Never>?
    @ObservationIgnored private var cleCalculee: EntreeScene.CleDisposition?
    @ObservationIgnored private var placesCalculees: [String: SIMD2<Double>] = [:]
    @ObservationIgnored private var rayonsCalcules: [String: Double] = [:]
    @ObservationIgnored private var cartesCalculees: [String: CartesPieces.Carte] = [:]
    @ObservationIgnored private(set) var cartes: [CartesPieces.Carte] = []
    @ObservationIgnored private(set) var positions: [SIMD2<Double>] = []
    /// La geometrie de l'image ; elle rejoint la geometrie visee (`geometrieVisee`) quand les plateaux glissent.
    @ObservationIgnored private(set) var geometrie = GeometrieMaison(rayons: [])
    /// La geometrie de la scene, avec les rayons de sa disposition et la grille du reglage.
    @ObservationIgnored private(set) var geometrieVisee = GeometrieMaison(rayons: [])
    @ObservationIgnored private(set) var glissementPlateaux: GlissementPlateaux?
    /// Le glissement d'une disposition a l'autre (polissage D, section 1) : les pieces, les noeuds et les liens qui
    /// changent, de leur pose affichee a leur nouvelle pose ; nil au repos.
    @ObservationIgnored private(set) var transition: TransitionScene?
    /// Les poses de l'image, de ce qui est en transition : la scene projetee les prend, la camera les suit.
    @ObservationIgnored private(set) var posesAffichees = PosesScene()
    /// Le dessin des pastilles qui s'effacent, absentes de la scene : celui de la scene d'avant.
    @ObservationIgnored private var apparencesParties: [String: DessinNoeud.Apparence] = [:]
    /// La politique de la grille 2D (polissage C, section 3 ; dans le coeur depuis le polissage D, section 5) : le
    /// reglage « Etages en 2D », pose par la fenetre, les colonnes choisies, une demande qui attend la vue d'ensemble 2D.
    @ObservationIgnored private(set) var politique = PolitiqueGrille()
    var grille: Bool { politique.grille }
    var colonnes: Int? { politique.colonnes }
    var grilleEnAttente: GrilleEnAttente? { politique.attente }
    /// Ce que vise le vol en cours : son arrivee suit les plateaux qui glissent.
    @ObservationIgnored private var viseeVol: Visee?
    @ObservationIgnored private(set) var orbite = Orbite(cible: .zero, distance: 1000, azimut: 0, inclinaison: 0.0001, champ: 2)
    @ObservationIgnored private var taille = CGSize.zero
    /// Marges du haut (le haut de la fenetre, mesure) et du bas (la pile du bas, mesuree : la legende et la ligne
    /// de niveau, puis la fiche), posees par la vue : la place utile de la vue d'ensemble. Le cadre les rejoint en
    /// 0,3 s, sur la courbe de la fiche qui glisse (`Apparition`) : la vue se releve avec elle, au-dessus de la pile,
    /// ou descend sous un bandeau ; en 0,45 s quand la legende s'ouvre ou se replie (`legendeBasculee`) ; avec
    /// « Reduire les animations », par un fondu.
    @ObservationIgnored var marges: (haut: CGFloat, bas: CGFloat) = (0, 0)
    /// Marge du bas de la zone visible ou se choisit la grille (polissage C, section 3.3) : celle de la legende, ouverte
    /// ou repliee, sans la fiche, qui va et vient (`FenetrePieces.margeBasGrille`) ; nil : celle du cadre.
    @ObservationIgnored var basGrille: CGFloat?
    /// La zone visible de la derniere image : une autre recalcule la grille.
    @ObservationIgnored private var zoneGrille = CGSize.zero
    /// Marges du cadre, et leur glissement en cours vers `marges`.
    @ObservationIgnored private var margesCadre: (haut: CGFloat, bas: CGFloat)?
    @ObservationIgnored private var glissement: GlissementMarges?
    /// Duree du prochain glissement des marges : celle de la legende, qui vient de s'ouvrir ou de se replier
    /// (`legendeBasculee`) ; nil, celle de la fiche et des bandeaux.
    @ObservationIgnored private var dureeAnnoncee: Double?
    /// Opacite de la scene pendant le fondu des marges (« Reduire les animations ») ; 1 sinon.
    @ObservationIgnored private(set) var opaciteMarges = 1.0
    @ObservationIgnored private(set) var cadre = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// Bascule adoucie : 0 en 2D, 1 en 3D.
    @ObservationIgnored private(set) var t: Double
    @ObservationIgnored private var envol: Envol?
    @ObservationIgnored private var debutEnvol = 0.0
    /// « Reduire les animations » : l'envol, et le retour a la vue d'ensemble par double-clic, sont un
    /// fondu ; la camera saute a mi-chemin.
    @ObservationIgnored private var fondu: Fondu?
    @ObservationIgnored private var opaciteFondu = 1.0
    /// Isolement : `s` general, `fk` propre a chaque piece.
    @ObservationIgnored private(set) var s = 0.0
    @ObservationIgnored private var sCible = 0.0
    @ObservationIgnored private var sDepart = 0.0
    @ObservationIgnored private var sDebut = 0.0
    @ObservationIgnored private(set) var focus: Int?
    /// Part propre a chaque piece de l'isolement, gardee par cle (triage A, n° 9).
    @ObservationIgnored private(set) var fk: [String: Double] = [:]
    /// Isolement d'un etage (polissage C, section 5) : `se` general, `ek` propre a chaque plateau, par cle ; l'etage
    /// en vue (isole, celui de la piece isolee, ou qui l'etait, pendant le retour).
    @ObservationIgnored private(set) var se = 0.0
    @ObservationIgnored private var seCible = 0.0
    @ObservationIgnored private var seDepart = 0.0
    @ObservationIgnored private var seDebut = 0.0
    @ObservationIgnored private(set) var ek: [String: Double] = [:]
    @ObservationIgnored private(set) var etageEnVue: String?
    /// Disque cliquable et nom d'etage sous le pointeur.
    @ObservationIgnored private(set) var survolEtage: Int?
    @ObservationIgnored private(set) var survolNomEtage: Int?
    @ObservationIgnored private var vol: Vol?
    @ObservationIgnored private var debutVol = 0.0
    @ObservationIgnored private(set) var survol: String?
    @ObservationIgnored private var curseur: CGPoint?
    @ObservationIgnored private var zoomEnAttente = 0.0
    @ObservationIgnored private var ancreZoom: SIMD3<Double>?
    @ObservationIgnored private var dernierPincement = 1.0
    @ObservationIgnored private var rotationEnAttente = SIMD2<Double>.zero
    @ObservationIgnored private var geste: Geste?
    /// Point de depart du geste en cours : un glisser qui part d'ailleurs en commence un autre.
    @ObservationIgnored private var departGeste = CGPoint.zero
    @ObservationIgnored private var bouge = false
    /// Le dernier geste, qui avait bouge, a ete clos par `abandonnerGeste` : si son relachement arrive
    /// encore (SwiftUI peut remettre l'etat du geste a zero avant d'appeler `onEnded`), ce n'est pas un
    /// clic.
    @ObservationIgnored private var abandonApresGlisser = false
    @ObservationIgnored private var precedent = CGPoint.zero
    @ObservationIgnored private var derniereActivite = 0.0
    @ObservationIgnored private var instant: Double?
    @ObservationIgnored private var dt = 0.0
    /// Djoko a zoome ou deplace la vue : un redimensionnement ne la recadre plus.
    @ObservationIgnored private(set) var vueTouchee = false
    @ObservationIgnored private(set) var etiquettes: [Etiquette] = []
    @ObservationIgnored private(set) var textes = TextesScene()
    /// Noeuds routeurs (leur nom en 12 points) et teinte de chaque piece, pour le dessin.
    @ObservationIgnored private var routeurs: Set<String> = []
    @ObservationIgnored private var teintes: [Int: Int] = [:]
    @ObservationIgnored private(set) var projetee: SceneProjetee?
    @ObservationIgnored private var traits: [PlacementNoms.Trait] = []
    /// Cles des pieces et des etages de la scene des noms : un nom garde son etat d'une scene a l'autre.
    @ObservationIgnored private var clesPieces: [String] = []
    @ObservationIgnored private var clesEtages: [String] = []
    @ObservationIgnored private let cache = CacheTextes()
    @ObservationIgnored private let mesure = MesureNoms()
    /// Ce qui est pose sur la vue (barre, fil, ligne de niveau, legende, fiche), par element : les noms
    /// l'evitent.
    @ObservationIgnored var cadresInterface: [String: CGRect] = [:]
    /// Fenetre de la vue : la molette et Echap ne valent que pour elle. La vue, dans AppKit : le point de la molette.
    @ObservationIgnored weak var fenetre: NSWindow?
    @ObservationIgnored weak var vue: NSView?
    @ObservationIgnored private var moniteur: Any?
    /// Captures : l'etat est pose a la main, l'horloge n'avance pas.
    @ObservationIgnored var fige = false

    /// Dernier clic sur le fond (instant, point) : un second, assez pres et assez tot, est un double-clic.
    @ObservationIgnored private var clicFond: (instant: Double, point: CGPoint)?

    private enum Geste {
        case fond
        /// Une piece qu'on glisse (son identifiant, jamais un indice qui perimerait), sur le plan
        /// horizontal y = `hauteur`.
        case piece(String, hauteur: Double)
        /// ⌥ + glisser en 3D : la vue glisse dans le plan de l'ecran, depuis l'orbite de l'appui.
        case ecran(Orbite)
    }

    /// ⌥ est tenue (le survol et le moniteur des touches la suivent) ; ce que le pointeur vise est cliquable.
    @ObservationIgnored private var optionTenue = false
    @ObservationIgnored private var surCliquable = false

    /// ⌥ + glisser en cours : la camera n'obeit qu'au pointeur. La maquette coupe alors ses controles : l'inertie de
    /// rotation et le zoom amorti attendent, la molette et le pincement sont ignores ; au relachement, tout reprend.
    private var deplaceDansLEcran: Bool {
        if case .ecran? = geste { true } else { false }
    }

    /// Glissement des marges du cadre, de `depart` a `arrivee`, depuis `debut`, en `duree` ; `fondu` : avec
    /// « Reduire les animations », un fondu par le fond, les marges sautant a mi-chemin.
    private struct GlissementMarges {
        var depart: (haut: CGFloat, bas: CGFloat)
        var arrivee: (haut: CGFloat, bas: CGFloat)
        var debut: Double
        var duree: Double
        var fondu: Bool
    }

    /// Glissement des plateaux (polissage C, sections 1.3 et 3.5) : de `depart`, la geometrie de l'image a son debut,
    /// remise dans l'ordre des plateaux de la scene, vers la geometrie visee ; en 2D en `duree2D`, en 3D en
    /// `duree3D` (0 : sans glissement), en cubique entree-sortie.
    struct GlissementPlateaux {
        var depart: GeometrieMaison
        var debut: Double
        var duree2D: Double
        var duree3D: Double
    }

    /// Une grille voulue qui attend la vue d'ensemble 2D : la duree du glissement de ses plateaux, et si elle garde
    /// la grille en place tant qu'elle est a moins de 5 % du choix (un redimensionnement).
    typealias GrilleEnAttente = PolitiqueGrille.Demande

    /// Ce que vise un vol : la vue d'ensemble, une piece ou un etage (sa cle).
    private enum Visee {
        case ensemble
        case piece(String)
        case etage(String)
    }

    /// Fondu de 0,3 s par le fond (« Reduire les animations ») : la scene s'efface, la camera saute a
    /// mi-chemin, la scene revient.
    private struct Fondu {
        var debut: Double
        /// Avancement de la bascule vise : 0 en 2D, 1 en 3D (le meme pour un retour a la vue d'ensemble).
        var arrivee: Double
        /// Camera a mi-chemin : la fin du vol (retour a la vue d'ensemble) ; nil : la vue d'ensemble du
        /// mode vise (bascule).
        var orbite: Orbite?
        var saute = false
    }

    /// `troisD` : le mode garde ; `fichierPlaces` : `positions-pieces.json` (nil : ni lu ni ecrit) ; `places` : sans
    /// fichier, les places de depart, en memoire (la demo et son choix de niveau).
    init(troisD: Bool = false, fichierPlaces: URL? = nil, selection: String? = nil, places depart: PlacesGardees? = nil) {
        self.troisD = troisD
        t = troisD ? 1 : 0
        self.fichierPlaces = fichierPlaces
        places = fichierPlaces.map(PlacesGardees.lire) ?? depart ?? PlacesGardees()
        self.selection = selection
    }

    static func maintenant() -> Double { CACurrentMediaTime() }

    var scene: ScenePieces? { entree?.scene }
    var aspect: Double { cadre.height > 0 ? Double(cadre.width / cadre.height) : 1.6 }
    /// Une piece est isolee (et non en train d'etre quittee).
    var estIsolee: Bool { focus != nil && sCible == 1 }
    var enMouvement: Bool { envol != nil || fondu != nil || vol != nil }
    /// La vue est a la vue d'ensemble : ni zoomee, ni deplacee, ni isolee, ni en mouvement.
    var aLaVueDEnsemble: Bool { pret && !vueTouchee && sansIsolement && !enMouvement }
    /// Ni piece ni etage isoles, ni en train d'etre quittes.
    var sansIsolement: Bool { isolement == .maison && focus == nil && etageEnVue == nil }
    /// Un mouvement, ou un glisser en cours (spec, sections 5 et 7) : une scene recue attend sa fin.
    var occupe: Bool { enMouvement || geste != nil }

    // MARK: Scene et disposition

    /// Nouvelle scene : appliquee tout de suite, ou a la fin du mouvement en cours (envol, vol, fondu)
    /// ou du glisser. Si ses etages, ses pieces, ses noeuds ou leurs noms changent, la disposition est
    /// recalculee hors du fil principal ; l'ancienne reste affichee pendant ce temps.
    func recevoir(_ e: EntreeScene) {
        if occupe {
            attente = e
            return
        }
        appliquer(e)
    }

    private func appliquer(_ e: EntreeScene) {
        attente = nil
        let cle = e.cleDisposition
        if cle == cleCalculee {
            calcul?.cancel()
            enCalcul = nil
            installer(e)
            return
        }
        // Meme structure que la disposition en calcul : elle vaudra pour cette scene.
        if enCalcul?.cleDisposition == cle {
            enCalcul = e
            return
        }
        calculer(e)
    }

    /// Lance le calcul de la disposition d'une scene, hors du fil principal, avec les places gardees
    /// du moment ; un calcul en cours est abandonne.
    private func calculer(_ e: EntreeScene) {
        calcul?.cancel()
        enCalcul = e
        let cle = e.cleDisposition
        let cartes = cartesPour(e)
        let fixees = places.fixees(e.scene, domicile: e.domicile)
        let scene = e.scene
        calcul = Task { [weak self] in
            let d = await Task.detached(priority: .userInitiated) {
                DispositionPieces(scene: scene, cartes: cartes, fixees: fixees)
            }.value
            guard !Task.isCancelled, let self else { return }
            self.retenir(d, scene: scene, cartes: cartes, cle: cle)
        }
    }

    /// La meme chose, sur le fil principal (captures, tests).
    func installerMaintenant(_ e: EntreeScene) {
        calcul?.cancel()
        let cartes = cartesPour(e)
        let d = DispositionPieces(scene: e.scene, cartes: cartes, fixees: places.fixees(e.scene, domicile: e.domicile))
        enCalcul = e
        retenir(d, scene: e.scene, cartes: cartes, cle: e.cleDisposition)
    }

    /// Cartes des pieces d'une scene, d'apres les noms mesures des noeuds, avec la place de tous leurs badges possibles
    /// (polissage D, section 2) : un badge qui change ne change pas la carte.
    private func cartesPour(_ e: EntreeScene) -> [CartesPieces.Carte] {
        var largeurs: [String: Double] = [:]
        for n in e.scene.noeuds {
            largeurs[n.id] = mesure.reserve(n.libelle, routeur: n.rang <= 2, pile: n.pile).width
        }
        return CartesPieces.cartes(e.scene, largeurs: largeurs)
    }

    /// Une disposition calculee pour `scene` : gardee par cles (piece, etage), d'apres cette scene, dont
    /// elle suit les indices (une scene plus recente de meme structure peut ranger ses etages, donc ses
    /// pieces, dans un autre ordre) ; puis posee avec la derniere scene de cette structure, si une scene
    /// d'une autre structure ne l'a pas depassee ; a la fin du mouvement ou du glisser en cours, s'il y
    /// en a un.
    private func retenir(_ d: DispositionPieces, scene: ScenePieces, cartes: [CartesPieces.Carte],
                         cle: EntreeScene.CleDisposition) {
        guard let e = enCalcul, e.cleDisposition == cle else { return }
        placesCalculees = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { (scene.pieces[$0].id, d.positions[$0]) })
        rayonsCalcules = Dictionary(scene.etages.indices.map { (scene.etages[$0].id, d.rayons[$0]) },
                                    uniquingKeysWith: { a, _ in a })
        cartesCalculees = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { (scene.pieces[$0].id, cartes[$0]) })
        cleCalculee = cle
        enCalcul = nil
        if occupe {
            if attente == nil { attente = e }
            return
        }
        installer(e)
    }

    /// Pose une scene sur la disposition gardee : positions et rayons retrouves par cles, noms,
    /// piece isolee.
    private func installer(_ e: EntreeScene) {
        let scene = e.scene
        let ancienFocus = focus.flatMap { $0 < clesPieces.count ? clesPieces[$0] : nil }
        // Des niveaux changes (le menu du clic droit) : les plateaux glissent vers leur nouvelle place (polissage C,
        // section 1.3) ; a la vue d'ensemble 2D, la grille se recalcule, sinon elle l'attend.
        let anciens = entree?.scene.etages.map(\.id) ?? []
        let niveauxChanges = pret && entree?.scene.niveaux != scene.niveaux
        let ensemble = aLaVueDEnsemble && t == 0
        let image = geometrie
        // La pose affichee de la scene d'avant, et sa pose d'arrivee (polissage D, section 1).
        let avant = entree.map { PosesScene(scene: $0.scene, cartes: cartes, positions: positions) }
        let affichee = avant?.recouvertes(par: posesAffichees)
        let rayonsAvant = entree.map { Dictionary(zip($0.scene.etages.map(\.id), geometrieVisee.rayons).map { ($0, $1) },
                                                  uniquingKeysWith: { a, _ in a }) }
        let ancienne = entree
        entree = e
        // Un autre ordre des plateaux : le disque et le nom d'etage survoles, des indices, en designeraient
        // d'autres ; le prochain mouvement du pointeur les reprend.
        if scene.etages.map(\.id) != anciens {
            survolEtage = nil
            survolNomEtage = nil
        }
        cartes = scene.pieces.map { cartesCalculees[$0.id] ?? CartesPieces.carte([]) }
        positions = scene.pieces.map { placesCalculees[$0.id] ?? .zero }
        // Une nouvelle disposition glisse (polissage D, section 1) : de la pose affichee a la nouvelle, en 0,9 s ; une
        // disposition qui ne change rien laisse le glissement en cours. Avec « Reduire les animations », tout de suite.
        let arrivee = PosesScene(scene: scene, cartes: cartes, positions: positions)
        if pret, let affichee, let avant, arrivee != avant || transition == nil {
            transition = TransitionScene(de: affichee, vers: arrivee, a: Self.maintenant(), reduire: reduire)
            if let tr = transition {
                posesAffichees = tr.poses(a: tr.debut)
                apparencesParties = (ancienne?.apparences ?? [:]).merging(apparencesParties) { a, _ in a }
            } else {
                posesAffichees = PosesScene()
                apparencesParties = [:]
            }
        }
        // Les rayons changent sans les niveaux : la grille se rechoisit, a la vue d'ensemble 2D, avec l'hysteresis ;
        // sinon elle attend (polissage D, section 4).
        let rayonsChanges = pret && !niveauxChanges
            && Dictionary(zip(scene.etages.map(\.id), rayons(scene)).map { ($0, $1) }, uniquingKeysWith: { a, _ in a }) != rayonsAvant
        if grille && (!pret || (niveauxChanges && ensemble)) {
            politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: false)
        } else if niveauxChanges {
            politique.attendre(PolitiqueGrille.niveaux)
        } else if rayonsChanges && grille {
            if ensemble {
                politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: true)
            } else {
                politique.attendre(PolitiqueGrille.redimensionnement)
            }
        }
        let glisse = pret ? TransitionScene.duree : 0
        viser(geometriePour(scene), depuis: anciens, duree2D: niveauxChanges ? CameraScene.dureeCases : glisse,
              duree3D: niveauxChanges ? CameraScene.dureeNiveaux : glisse)
        // Les parts de l'isolement sont gardees par cle (triage A, n° 9) : un releve recu pendant un fondu ne remet pas
        // la piece a pleine taille. L'etage en vue suit ce que vise la vue (polissage C, section 5) : celui de la piece
        // isolee, qui a pu changer de zone. Une piece isolee qui disparait rend la maison, comme avant les etages :
        // l'etage est relache, comme a la bascule, et la vue d'ensemble se recadre (plus bas). Un etage isole qui
        // disparait rend aussi la maison.
        let clesPieces = Set(scene.pieces.map(\.id)), clesEtages = Set(scene.etages.map(\.id))
        fk = fk.filter { clesPieces.contains($0.key) }
        ek = ek.filter { clesEtages.contains($0.key) }
        isolement = isolement.recaler(pieces: clesPieces, etages: clesEtages)
        if let cle = ancienFocus, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            focus = i
            if case .piece = isolement, scene.etages.count > 1 { viserEtage(scene.etages[scene.pieces[i].etage].id) }
        } else if focus != nil {
            focus = nil
            s = 0
            sCible = 0
            isolee = nil
            if isolement == .maison {
                etageEnVue = nil
                se = 0
                seCible = 0
                ek = [:]
            }
        }
        if let k = etageEnVue, !clesEtages.contains(k) {
            etageEnVue = nil
            se = 0
            seCible = 0
        }
        textes = Self.textes(e, focus: focus)
        routeurs = Set(scene.noeuds.filter { $0.rang <= 2 }.map(\.id))
        teintes = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { ($0, scene.pieces[$0].teinte) })
        construireEtiquettes()
        majFil()
        if !pret {
            pret = true
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        } else if !vueTouchee && sansIsolement {
            recadrer()
        } else if niveauxChanges && glissementPlateaux == nil {
            // Des niveaux changes, avec « Reduire les animations » : les plateaux sont poses tout de suite
            // (section 1.3). La vue isolee ou zoomee suit ce qu'elle regarde, d'un coup, depuis sa place au depart du
            // glissement qu'il n'y a pas : comme le glissement le lui fait suivre image apres image (`suivre`), sans
            // « Reduire ».
            suivre(depuis: ancreCamera(dans: depart(image, anciens: anciens, vers: geometrie)))
        }
        reveiller()
    }

    /// Textes des noms : libelles, pieces (nom, compte), etages, maison, reperes « ailleurs ».
    static func textes(_ e: EntreeScene, focus: Int?) -> TextesScene {
        var t = TextesScene()
        t.noeuds = e.libelles
        for (i, p) in e.scene.pieces.enumerated() {
            t.pieces[i] = TextesScene.Piece(nom: LibellesNoeuds.nom(p.nom, libelles: e.libelles),
                                            compte: LibellesNoeuds.compte(p.noeuds.count))
        }
        for (i, et) in e.scene.etages.enumerated() { t.etages[i] = LibellesNoeuds.nom(et.nom) }
        t.maison = String(localized: "⌂ Maison")
        if let f = focus {
            for a in SceneProjetee.reperes(e.scene, focus: f) {
                t.ailleurs[a.enfant] = LibellesNoeuds.ailleurs(a, scene: e.scene, libelles: e.libelles)
            }
        }
        return t
    }

    /// Cle d'un nom, qui ne depend pas des indices de la scene.
    private func cle(_ g: Etiquette.Genre) -> String {
        switch g {
        case .noeud(let id): "n:" + id
        case .piece(let i): "p:" + (i < clesPieces.count ? clesPieces[i] : "")
        case .etage(let i): "e:" + (i < clesEtages.count ? clesEtages[i] : "")
        case .maison: "m"
        case .ailleurs(let id): "a:" + id
        }
    }

    /// Noms de la scene, dans l'ordre de la maquette (appareils, etages, pieces, maison, reperes) ;
    /// chacun garde son etat de placement d'une scene a l'autre.
    private func construireEtiquettes() {
        guard let scene else { return }
        var anciennes: [String: Etiquette] = [:]
        for l in etiquettes { anciennes[cle(l.genre)] = l }
        clesPieces = scene.pieces.map(\.id)
        clesEtages = scene.etages.map(\.id)
        var l: [Etiquette] = []
        func ajouter(_ genre: Etiquette.Genre, _ taille: CGSize) {
            var e = Etiquette(genre, taille: taille)
            if let a = anciennes[cle(genre)] {
                e.place = a.place
                e.envie = a.envie
                e.vu = a.vu
                e.rect = a.rect
                e.rectAvant = a.rectAvant
            }
            l.append(e)
        }
        for n in scene.noeuds {
            ajouter(.noeud(n.id), mesure.noeud(textes.noeuds[n.id] ?? LibellesNoeuds.Libelle(texte: n.id), routeur: n.rang <= 2))
        }
        for i in scene.etages.indices { ajouter(.etage(i), mesure.etage(textes.etages[i] ?? "")) }
        for i in scene.pieces.indices {
            let t = textes.pieces[i] ?? TextesScene.Piece(nom: "", compte: "")
            ajouter(.piece(i), mesure.piece(nom: t.nom, compte: t.compte))
        }
        ajouter(.maison, mesure.maison(textes.maison))
        for (id, texte) in textes.ailleurs.sorted(by: { $0.key < $1.key }) { ajouter(.ailleurs(id), mesure.ailleurs(texte)) }
        etiquettes = l
    }

    // MARK: Places gardees et ordre des etages

    private func enregistrer() {
        guard let fichierPlaces else { return }
        do {
            try places.ecrire(dans: fichierPlaces)
        } catch {
            Self.journal.error("places des pieces non ecrites : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Garde la place d'une piece qu'on vient de glisser : elle est desormais fixee. Un calcul en cours
    /// ne la connait pas : il est relance avec elle (sinon, a sa fin, la piece sauterait a la place
    /// qu'il lui donne). Une place non finie (camera degeneree) n'est pas gardee.
    private func garder(_ id: String) {
        guard let e = entree, let i = e.scene.pieces.firstIndex(where: { $0.id == id }), i < positions.count,
              positions[i].x.isFinite, positions[i].y.isFinite else { return }
        let p = e.scene.pieces[i]
        places.garder(positions[i], piece: p.id, etage: e.scene.etages[p.etage].id, domicile: e.domicile)
        placesCalculees[p.id] = positions[i]
        enregistrer()
        if let c = enCalcul { calculer(c) }
    }

    // MARK: Menu du clic droit (polissage C, section 1.3)

    /// La scene la plus recente : celle qui attend la fin d'un mouvement ou d'un geste, sinon celle du calcul en cours,
    /// sinon celle affichee. Apres un choix du menu, elle le porte avant la scene affichee.
    private var sceneRecente: EntreeScene? { attente ?? enCalcul ?? entree }

    /// Le menu du nom ou du disque du plateau `cle`, sur la scene la plus recente : ses coches et ses grises suivent le
    /// dernier choix, meme quand la scene de ce choix attend encore. Il lit la version de cette scene, observee : une
    /// vue qui le montre se refait quand elle change, meme si la cible du clic droit, elle, ne change pas.
    func menuEtage(_ cle: String) -> MenuEtage? {
        _ = versionScene
        guard let scene = sceneRecente?.scene, let niveau = scene.niveaux.niveau(cle) else { return nil }
        let n = scene.niveaux, estPrincipal = n.estPrincipal(cle)
        func nom(_ c: String) -> String {
            scene.etages.firstIndex { $0.id == c }.map { LibellesNoeuds.nom(scene.etages[$0].nom) } ?? c
        }
        let niveaux = n.liste.indices.filter { !(estPrincipal && $0 == niveau) }.map { i in
            MenuEtage.Niveau(principal: n.liste[i][0], nom: nom(n.liste[i][0]), coche: !estPrincipal && i == niveau)
        }
        return MenuEtage(nom: nom(cle), monter: estPrincipal && niveau < n.liste.count - 1,
                         descendre: estPrincipal && niveau > 0, niveaux: niveaux, aCote: !estPrincipal,
                         dehors: n.dehors(cle))
    }

    /// Un choix du menu, calcule sur la scene la plus recente et sur les choix gardes : le nouvel ordre des plateaux et
    /// les nouveaux choix de niveau, gardes ; la scene suivante les prend (`EntreeScene`), et les plateaux glissent vers
    /// leur nouvelle place. Sur la scene affichee, un choix fait pendant que la scene du precedent attend (un vol, le
    /// calcul de sa disposition) defaisait le precedent.
    private func ranger(_ operation: (Niveaux, [String: PlacesGardees.ACote]) -> Rangement?) {
        guard let e = sceneRecente, let r = operation(e.scene.niveaux, places.maison(e.domicile).aCote) else { return }
        places.ranger(r, domicile: e.domicile)
        enregistrer()
    }

    /// La cle du plateau `e` de la scene affichee, celle des noms et de la projection.
    private func cleEtage(_ e: Int) -> String? {
        guard let scene, scene.etages.indices.contains(e) else { return nil }
        return scene.etages[e].id
    }

    /// « Monter d'un etage » (+1) ou « Descendre d'un etage » (-1) : le niveau entier de l'etage `cle`, zones a cote
    /// comprises, change de place avec son voisin.
    func deplacerEtage(_ cle: String, de pas: Int) {
        ranger { $0.deplacer(cle, de: pas, choix: $1) }
    }

    /// La meme chose pour le plateau `e` de la scene affichee.
    func deplacerEtage(_ e: Int, de pas: Int) {
        if let cle = cleEtage(e) { deplacerEtage(cle, de: pas) }
    }

    func peutDeplacerEtage(_ e: Int, de pas: Int) -> Bool {
        cleEtage(e).flatMap(menuEtage).map { pas > 0 ? $0.monter : $0.descendre } ?? false
    }

    /// « Au meme niveau que » le niveau de l'etage principal `principal` (sa cle), dans la maison.
    func mettreAuNiveau(_ cle: String, de principal: String) {
        ranger { n, choix in n.niveau(principal).flatMap { n.rejoindre(cle, niveau: $0, choix: choix) } }
    }

    /// « Hors de la maison », coche ou non.
    func basculerDehors(_ cle: String) {
        ranger { $0.basculerDehors(cle, choix: $1) }
    }

    /// « Sur son propre niveau ».
    func mettreSurSonNiveau(_ cle: String) {
        ranger { $0.propreNiveau(cle, choix: $1) }
    }

    /// « Replacer les pieces automatiquement » : oublie les places gardees de la maison (pas l'ordre
    /// des etages) et recalcule la disposition de la scene la plus recente (celle qui attend la fin d'un
    /// mouvement ou d'un geste, sinon celle du calcul en cours, sinon celle affichee) ; l'ancienne reste
    /// affichee pendant ce temps.
    func replacerPieces() {
        guard let e = sceneRecente else { return }
        places.replacer(domicile: e.domicile)
        enregistrer()
        cleCalculee = nil
        enCalcul = nil
        appliquer(e)
    }

    // MARK: Plateaux

    /// La geometrie d'une scene : les rayons de sa disposition, ses niveaux, et la grille du reglage (en grille, les
    /// colonnes choisies, la rangee en attendant une vraie taille).
    private func geometriePour(_ scene: ScenePieces) -> GeometrieMaison {
        GeometrieMaison(rayons: rayons(scene),
                        plateaux: scene.etages.map {
                            GeometrieMaison.Plateau(niveau: $0.niveau, principal: $0.principal, dehors: $0.dehors)
                        },
                        colonnes: politique.colonnesDeLaGeometrie)
    }

    /// Les rayons des plateaux d'une scene, ceux de sa disposition : la grille se choisit sur eux.
    private func rayons(_ scene: ScenePieces) -> [Double] {
        scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge }
    }

    /// La zone visible ou se choisit la grille (polissage C, section 3.3, decision de Djoko du 03/10) : la vue moins la
    /// marge du haut et celle du bas, la legende ouverte ou repliee, sans la fiche (`basGrille`). La vue d'ensemble y est
    /// toujours la plus grande possible.
    var zoneVisible: CGSize {
        CGSize(width: taille.width, height: taille.height - marges.haut - (basGrille ?? marges.bas))
    }

    /// Pose la geometrie visee : tout de suite, ou en glissant (« Reduire les animations » : tout de suite) depuis la
    /// geometrie de l'image, remise dans l'ordre des plateaux de la scene (`anciens` : celui de l'image). Un
    /// glissement en cours repart de l'image, avec le temps qui lui restait s'il est plus long.
    private func viser(_ g: GeometrieMaison, depuis anciens: [String], duree2D: Double, duree3D: Double) {
        let now = Self.maintenant()
        var d2 = reduire ? 0 : duree2D
        var d3 = reduire ? 0 : duree3D
        if let gl = glissementPlateaux, !reduire {
            d2 = max(d2, gl.duree2D - (now - gl.debut))
            d3 = max(d3, gl.duree3D - (now - gl.debut))
        }
        geometrieVisee = g
        let depart = self.depart(geometrie, anciens: anciens, vers: g)
        // Rien ne bouge : pas de glissement (une nouvelle disposition aux memes plateaux).
        guard pret, d2 > 0 || d3 > 0, scene != nil, depart != g || glissementPlateaux != nil else {
            geometrie = g
            glissementPlateaux = nil
            return
        }
        geometrie = depart
        glissementPlateaux = GlissementPlateaux(depart: depart, debut: now, duree2D: d2, duree3D: d3)
        reveiller()
    }

    /// Le depart d'un glissement vers `g`, la geometrie de la scene : la geometrie `image`, remise dans l'ordre des
    /// plateaux de la scene (`anciens` : celui de l'image), chaque plateau a sa place d'avant, retrouvee par sa cle ;
    /// la boite, le pas, la sphere et le cadrage de l'image. Un plateau nouveau part de sa place d'arrivee.
    private func depart(_ image: GeometrieMaison, anciens: [String], vers g: GeometrieMaison) -> GeometrieMaison {
        var depart = g
        for (i, c) in (scene?.etages.map(\.id) ?? []).enumerated() {
            guard let j = anciens.firstIndex(of: c), j < image.centres2D.count else { continue }
            depart.centres2D[i] = image.centres2D[j]
            depart.centres3D[i] = image.centres3D[j]
        }
        depart.boite = image.boite
        depart.pasEtage = image.pasEtage
        depart.centreSphere = image.centreSphere
        depart.rayonSphere = image.rayonSphere
        depart.rayonCadre = image.rayonCadre
        return depart
    }

    /// La geometrie de l'image a l'instant `now` : en route vers la geometrie visee, ou elle.
    func geometrie(a now: Double) -> GeometrieMaison {
        guard let gl = glissementPlateaux else { return geometrieVisee }
        let q2 = gl.duree2D > 0 ? min(1, max(0, (now - gl.debut) / gl.duree2D)) : 1
        let q3 = gl.duree3D > 0 ? min(1, max(0, (now - gl.debut) / gl.duree3D)) : 1
        if q2 >= 1 && q3 >= 1 { return geometrieVisee }
        return gl.depart.vers(geometrieVisee, k2: CameraScene.rampe(q2), k3: CameraScene.rampe(q3))
    }

    /// Le reglage « Etages en 2D » (polissage C, section 3.1) : en grille ou en rangee. Il s'applique tout de suite a
    /// la vue ouverte, les plateaux glissant comme l'envol, en 2,6 s ; zoomee, isolee ou en 3D, au retour a la vue
    /// d'ensemble 2D.
    func reglerGrille(_ g: Bool) {
        guard politique.regler(g), pret else { return }
        demanderGrille(PolitiqueGrille.reglage)
    }

    /// La zone visible a change (polissage C, sections 3.3 et 3.5) : la taille de la vue, ou ses marges sans la fiche
    /// (la legende ouverte ou repliee, un bandeau). La premiere vraie zone pose la grille et cadre la vue d'ensemble,
    /// sans autre condition ; ensuite, la grille se recalcule a la vue d'ensemble 2D, avec l'hysteresis, et les plateaux
    /// glissent en 0,4 s ; zoomee, isolee ou en 3D, elle attend.
    private func zoneChangee() {
        guard pret, let scene else { return }
        if politique.sansVraieTaille {
            guard politique.premiereZone(rayons: rayons(scene), zone: zoneVisible) else { return }
            viser(geometriePour(scene), depuis: scene.etages.map(\.id), duree2D: 0, duree3D: 0)
            vueTouchee = false
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
            return
        }
        demanderGrille(PolitiqueGrille.redimensionnement)
    }

    /// Une grille voulue : posee a la vue d'ensemble 2D, ses plateaux glissant en `d.duree` ; sinon elle attend
    /// (`PolitiqueGrille`).
    private func demanderGrille(_ d: PolitiqueGrille.Demande) {
        guard let scene else { return }
        if politique.demander(d, ensemble2D: t == 0 && aLaVueDEnsemble, rayons: rayons(scene), zone: zoneVisible) {
            poserGeometrie(d.duree)
        }
    }

    /// Pose la grille d'une demande, puis sa geometrie.
    private func poserGrille(_ d: PolitiqueGrille.Demande) {
        guard let scene else { return }
        politique.poser(d, rayons: rayons(scene), zone: zoneVisible)
        poserGeometrie(d.duree)
    }

    /// La geometrie de la grille choisie : ses plateaux glissent en `duree`.
    private func poserGeometrie(_ duree: Double) {
        guard let scene else { return }
        let g = geometriePour(scene)
        guard g != geometrieVisee else { return }
        viser(g, depuis: scene.etages.map(\.id), duree2D: duree, duree3D: 0)
        if glissementPlateaux == nil && aLaVueDEnsemble { recadrer() }   // posee tout de suite : cadree tout de suite
    }

    /// Ce que la vue regarde : la piece isolee, l'etage isole, ou la cible de la vue d'ensemble ; dans la geometrie de
    /// l'image, ou dans `g`.
    private func ancreCamera(dans g: GeometrieMaison? = nil) -> SIMD3<Double> {
        let g = g ?? geometrie
        if let i = focus, let c = centrePiece(i, dans: g) { return c }
        if let k = etageEnVue, let e = scene?.etages.firstIndex(where: { $0.id == k }) { return g.centrePlateau(e, t) }
        return g.cible2D + (g.centreSphere - g.cible2D) * t
    }

    /// Les plateaux glissent : un vol rejoint l'arrivee de ce qu'il vise ; a la vue d'ensemble, elle se recadre ; sinon,
    /// la vue suit ce qu'elle regarde (`ancre0` : sa place a l'image d'avant).
    private func suivre(depuis ancre0: SIMD3<Double>) {
        if vol != nil {
            if let v = viseeVol, let fin = volVers(v) {
                vol?.oeil1 = fin.oeil1
                vol?.cible1 = fin.cible1
            }
        } else if envol == nil && fondu == nil {
            if aLaVueDEnsemble {
                recadrer()
            } else {
                orbite.cible += ancreCamera() - ancre0
            }
        }
    }

    /// Le vol vers ce que l'on vise, depuis la camera du moment.
    private func volVers(_ v: Visee) -> Vol? {
        switch v {
        case .ensemble: CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1)
        case .piece(let cle): scene?.pieces.firstIndex { $0.id == cle }.flatMap(volVersPiece)
        case .etage(let cle): scene?.etages.firstIndex { $0.id == cle }.map(volVersEtage)
        }
    }

    // MARK: Camera

    /// Cadre la vue d'ensemble a l'avancement courant, en gardant l'orbite en 3D.
    func recadrer() {
        var c = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        if t == 1 {
            c.azimut = orbite.azimut
            c.inclinaison = orbite.inclinaison
        }
        orbite = c
    }

    /// Bascule 2D / 3D : un envol de 2,6 s depuis la vue courante (un fondu de 0,3 s si « Reduire
    /// les animations ») ; une piece isolee est relachee. Pas de menu du clic droit pendant l'envol, meme sous un
    /// pointeur immobile : sa cible tombe, et le survol ne la reprend qu'apres lui.
    func basculer(troisD v: Bool) {
        guard v != troisD else { return }
        troisD = v
        if cibleMenu != .aucune { cibleMenu = .aucune }
        focus = nil
        isolee = nil
        s = 0
        sCible = 0
        fk = [:]
        etageEnVue = nil
        se = 0
        seCible = 0
        ek = [:]
        isolement = .maison
        vol = nil
        zoomEnAttente = 0
        rotationEnAttente = .zero
        vueTouchee = false
        textes = entree.map { Self.textes($0, focus: nil) } ?? textes
        construireEtiquettes()
        majFil()
        // Vers la 2D, l'envol se pose sur la grille de la zone visible du moment (polissage C, section 3.5).
        if !v, let scene {
            politique.oublierAttente()
            politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: false)
            viser(geometriePour(scene), depuis: scene.etages.map(\.id), duree2D: 0, duree3D: 0)
        }
        let arrivee = v ? 1.0 : 0.0
        if reduire {
            fondu = Fondu(debut: Self.maintenant(), arrivee: arrivee)
        } else {
            envol = Envol(depuis: orbite, t: t, vers: arrivee, geometrie: geometrie, aspect: aspect)
            debutEnvol = Self.maintenant()
        }
        reveiller()
    }

    /// Isole une piece : la camera y vole en 1,3 s (tout de suite si « Reduire les animations »), les
    /// autres s'estompent, ses reperes « ailleurs » apparaissent. Son etage est celui du fil : les disques des
    /// autres etages restent a 15 %, cliquables (polissage C, section 5.2). La provenance (section 5.4) : depuis la
    /// maison ou un etage isole, ce que l'on quitte ; d'une piece a une autre, elle reste, sauf vers une piece d'un
    /// autre etage : la maison.
    func isoler(_ i: Int) {
        guard let scene, i < scene.pieces.count, !(focus == i && sCible == 1) else { return }
        let piece = scene.pieces[i], etage = scene.etages[piece.etage].id
        isolement = isolement.isoler(piece: piece.id, etage: etage)
        focus = i
        isolee = textes.pieces[i]?.nom
        if sCible != 1 {
            sDepart = s
            sCible = 1
            sDebut = Self.maintenant()
        }
        if scene.etages.count > 1 { viserEtage(etage) }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        majFil()
        if let v = volVersPiece(i) { voler(v, visee: .piece(piece.id)) }
    }

    /// Isole un etage (polissage C, section 5.1) : un vol de 1,3 s cadre son plateau, bande de son nom comprise ; les
    /// autres plateaux s'estompent a 15 %, la sphere et « ⌂ Maison » s'effacent ; la rotation lente continue (polissage D). Une
    /// piece isolee est relachee. Rien dans une maison d'un seul plateau, ni pendant l'envol.
    func allerEtage(_ e: Int) {
        guard let scene, scene.etages.count > 1, e < scene.etages.count, envol == nil, fondu == nil else { return }
        quitterPiece()
        let cle = scene.etages[e].id
        isolement = .etage(cle)
        viserEtage(cle)
        majFil()
        voler(volVersEtage(e), visee: .etage(cle))
    }

    /// Vol vers un etage isole.
    private func volVersEtage(_ e: Int) -> Vol {
        CameraScene.volVersEtage(orbite, geometrie, etage: e, aspect: aspect, u: t, troisD: t == 1)
    }

    /// L'isolement d'etage vise `cle` : son plateau reste net.
    private func viserEtage(_ cle: String) {
        etageEnVue = cle
        if seCible != 1 {
            seDepart = se
            seCible = 1
            seDebut = Self.maintenant()
        }
    }

    /// La piece isolee est relachee : son isolement redescend en 1,3 s.
    private func quitterPiece() {
        guard focus != nil, sCible != 0 else { return }
        sDepart = s
        sCible = 0
        sDebut = Self.maintenant()
        isolee = nil
        // Retour lance avant la premiere image de l'isolement : `s` est deja a 0, et l'horloge ne
        // finirait jamais ce retour.
        if s == 0 { finirRetour() }
    }

    /// L'etage isole est relache.
    private func quitterEtage() {
        guard seCible != 0 else { return }
        seDepart = se
        seCible = 0
        seDebut = Self.maintenant()
        if se == 0 { etageEnVue = nil }
    }

    /// Le fil de ce que montre la vue.
    private func majFil() {
        var f = Fil()
        if let scene {
            func cran(_ e: Int) -> Fil.Cran { Fil.Cran(nom: textes.etages[e] ?? "", etage: e) }
            switch isolement {
            case .maison:
                break
            case .etage(let cle):
                f.etage = scene.etages.firstIndex { $0.id == cle }.map(cran)
            case .piece(let cle, _):
                if let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
                    f.piece = textes.pieces[i]?.nom
                    if scene.etages.count > 1 { f.etage = cran(scene.pieces[i].etage) }
                }
            }
        }
        if f != fil { fil = f }
    }

    /// Vol vers une piece, a la hauteur de vue de la spec (section 7).
    private func volVersPiece(_ i: Int) -> Vol? {
        guard let c = centrePiece(i) else { return nil }
        return CameraScene.volVersPiece(orbite, centre: c, largeur: cartes[i].largeur, profondeur: cartes[i].profondeur,
                                        aspect: aspect, troisD: t == 1)
    }

    /// Retour a la maison (« Maison » dans le fil, double-clic, ou en remontant) : la piece et l'etage isoles sont
    /// relaches, le zoom et le deplacement annules, par un vol de 1,3 s qui part de la pose courante. « Reduire les
    /// animations » : tout de suite, ou par un fondu de 0,3 s (`enFondu`, le double-clic).
    func versMaison(enFondu: Bool = false) {
        guard isolement != .maison || focus != nil || etageEnVue != nil || vueTouchee else { return }
        quitterPiece()
        quitterEtage()
        isolement = .maison
        majFil()
        vueTouchee = false
        voler(CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1), visee: .ensemble,
              enFondu: enFondu)
    }

    /// Echap et le clic a cote remontent d'ou l'on vient (polissage C, section 5.4) : une piece ouverte depuis un etage
    /// isole, a l'etage de la piece ; une autre piece, ou un etage, a la maison. A la maison, Echap ramene une vue
    /// zoomee ou deplacee a la vue d'ensemble (`clavier`) ; le clic a cote ne fait rien. Rien pendant l'envol.
    func remonter(clavier: Bool = true) {
        guard envol == nil, fondu == nil else { return }
        var etageDeLaPiece: String?
        if case .piece(let cle, _) = isolement, let scene, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            etageDeLaPiece = scene.etages[scene.pieces[i].etage].id
        }
        switch isolement.remonter(etageDeLaPiece: etageDeLaPiece, plusieursPlateaux: (scene?.etages.count ?? 0) > 1,
                                  clavier: clavier) {
        case .etage(let cle):
            if let e = scene?.etages.firstIndex(where: { $0.id == cle }) { allerEtage(e) }
        case .maison:
            versMaison()
        case .rien:
            break
        }
    }

    /// Echap (polissage D, section 3), dans cet ordre : une fiche ouverte se ferme ; sinon la vue remonte d'un cran ;
    /// sinon, a la vue d'ensemble sans zoom ni fiche, Echap n'est pas pris (faux) : l'evenement suit son chemin.
    @discardableResult
    func sortir() -> Bool {
        if selection != nil {
            selection = nil
            return true
        }
        guard envol == nil, fondu == nil, isolement != .maison || focus != nil || etageEnVue != nil || vueTouchee else {
            return false
        }
        remonter(clavier: true)
        return true
    }

    /// Fin du retour d'un isolement : plus de piece isolee, ni de reperes « ailleurs ».
    private func finirRetour() {
        focus = nil
        if let e = entree { textes = Self.textes(e, focus: nil) }
        construireEtiquettes()
    }

    /// Double-clic sur le fond ou sur un disque (precision 17 du plan 4b ; polissage C, section 5.4) : retour a la vue
    /// d'ensemble d'un geste, de partout. Le premier clic a deja agi seul ; le second relache ce qui reste isole et
    /// annule le zoom et le deplacement.
    func doubleCliquer() {
        versMaison(enFondu: true)
    }

    private func voler(_ v: Vol, visee: Visee, enFondu: Bool = false) {
        zoomEnAttente = 0
        rotationEnAttente = .zero
        viseeVol = nil
        if reduire && enFondu {
            fondu = Fondu(debut: Self.maintenant(), arrivee: t, orbite: v.orbite(1, depuis: orbite))
            vol = nil
        } else if reduire {
            orbite = v.orbite(1, depuis: orbite)
            vol = nil
        } else {
            vol = v
            viseeVol = visee
            debutVol = Self.maintenant()
        }
        reveiller()
    }

    func basculerRotation() {
        rotation.toggle()
        reveiller()
    }

    // MARK: Image

    /// Une image du `Canvas` : avance l'etat, projette la scene, place les noms, dessine.
    func image(_ ctx: inout GraphicsContext, taille nouvelle: CGSize, echelle: Double, palette: Palette) {
        // Taille ou marges changees : la vue d'ensemble se recadre, sauf si Djoko a zoome ou isole une piece ; une
        // nouvelle zone visible recalcule la grille (polissage C, sections 3.3 et 3.5).
        taille = nouvelle
        let changee = zoneVisible != zoneGrille
        zoneGrille = zoneVisible
        let now = Self.maintenant()
        let m = margesDuCadre(now)
        let voulu = CGRect(x: 0, y: m.haut, width: nouvelle.width, height: max(1, nouvelle.height - m.haut - m.bas))
        if voulu != cadre {
            cadre = voulu
            if aLaVueDEnsemble && !fige { recadrer() }
        }
        if changee && !fige { zoneChangee() }
        if !fige { avancer(now) }
        guard pret, let scene else { return }
        let parts = scene.pieces.map { fk[$0.id] ?? 0 }
        let etat = EtatAnime(t: t, s: s, fk: parts, focus: focus, survol: survol, selection: selection, se: se,
                             ek: scene.etages.map { ek[$0.id] ?? 0 }, survolEtage: survolEtage)
        let p = SceneProjetee(scene: scene, cartes: cartes, positions: positions, geometrie: geometrie, etat: etat,
                              orbite: orbite, cadre: cadre, poses: posesAffichees)
        PlacementNoms.regler(&etiquettes, scene: scene, niveau: p.niveau, survol: survol, selection: selection, focus: focus,
                             isolee: estIsolee, fk: parts, s: s, t: t, se: se, voiles: p.voilesEtages,
                             etageIsole: indiceEtageIsole, survolNomEtage: survolNomEtage)
        let ancres: [CGRect?] = etiquettes.map { l in
            switch l.genre {
            case .noeud(let id): p.ancresNoeuds[id]
            case .piece(let i): p.ancresPieces[i]
            case .etage(let i): p.ancresEtages[i]
            case .maison: p.ancreMaison
            case .ailleurs(let id): p.ancresAilleurs[id]
            }
        }
        var obstacles = p.disques.filter { $0.opacite > 0.5 }.map { d in
            CGRect(x: Double(d.centre.x) - d.rayon, y: Double(d.centre.y) - d.rayon, width: 2 * d.rayon, height: 2 * d.rayon)
        }
        obstacles += cadresInterface.values.map { $0.insetBy(dx: -4, dy: -4) }
        traits = PlacementNoms.placer(&etiquettes, ancres: ancres, obstacles: obstacles, cadre: taille, dt: dt)
        projetee = p
        var g = ctx
        g.opacity = opaciteFondu * opaciteMarges
        RenduCanvas.dessiner(&g, ImagePieces(projetee: p, etiquettes: etiquettes, traits: traits, textes: textes,
                                             apparences: apparences, routeurs: routeurs,
                                             teintesPieces: teintes, selection: selection, echelle: echelle),
                             palette: palette, cache: cache)
        let nouvelle = ligne(p.niveau, ancres: ancres)
        if nouvelle != ligneNiveau {
            // Hors du rendu, sauf pour une capture (rendue d'un trait).
            if fige {
                ligneNiveau = nouvelle
            } else {
                Task { @MainActor [weak self] in self?.ligneNiveau = nouvelle }
            }
        }
        if !fige && !doitContinuer(now) { endormir() }
    }

    /// Le dessin des pastilles : celles de la scene, et celles qui s'effacent, de la scene d'avant.
    private var apparences: [String: DessinNoeud.Apparence] {
        let a = entree?.apparences ?? [:]
        return apparencesParties.isEmpty ? a : a.merging(apparencesParties) { x, _ in x }
    }

    /// Marges du cadre a l'instant `now` : les marges visees, ou en route vers elles quand elles changent, pendant
    /// 0,3 s, ou 0,45 s quand la legende s'ouvre ou se replie (`legendeBasculee`) ; avec « Reduire les animations »,
    /// par un fondu de cette duree (la scene s'efface, les marges sautent a mi-chemin, la scene revient :
    /// `opaciteMarges`) ; tout de suite avant la premiere disposition et pour une capture.
    func margesDuCadre(_ now: Double) -> (haut: CGFloat, bas: CGFloat) {
        let actuelles = margesCadre ?? marges
        let visees = glissement?.arrivee ?? actuelles
        if marges.haut != visees.haut || marges.bas != visees.bas {
            if pret, !fige, margesCadre != nil {
                glissement = GlissementMarges(depart: actuelles, arrivee: marges, debut: now,
                                              duree: dureeAnnoncee ?? Apparition.duree, fondu: reduire)
                // Le glissement demande des images : l'horloge repart, hors du rendu.
                if !anime { Task { @MainActor [weak self] in self?.reveiller() } }
            } else {
                glissement = nil
            }
            dureeAnnoncee = nil
        }
        guard let g = glissement else {
            margesCadre = marges
            opaciteMarges = 1
            return marges
        }
        let q = min(1, max(0, (now - g.debut) / g.duree))
        let m: (haut: CGFloat, bas: CGFloat)
        if g.fondu {
            m = q < 0.5 ? g.depart : g.arrivee
            opaciteMarges = abs(1 - 2 * q)
        } else {
            let e = CGFloat(Apparition.courbe(q))
            m = (haut: g.depart.haut + (g.arrivee.haut - g.depart.haut) * e,
                 bas: g.depart.bas + (g.arrivee.bas - g.depart.bas) * e)
        }
        if q >= 1 {
            glissement = nil
            opaciteMarges = 1
        }
        margesCadre = m
        return m
    }

    /// Les marges du cadre sont en route.
    var margesEnRoute: Bool { glissement != nil }

    /// Les marges du cadre sont en route par un fondu (« Reduire les animations »).
    var margesEnFondu: Bool { glissement?.fondu == true }

    /// La legende s'ouvre ou se replie, d'un clic : le recadrage qui l'accompagne (le prochain changement des
    /// marges) prend sa duree, 0,45 s (`Apparition.dureeLegende`), au lieu des 0,3 s de la fiche et des bandeaux.
    func legendeBasculee() {
        dureeAnnoncee = Apparition.dureeLegende
    }

    /// L'etage vise par l'isolement, dans la scene ; nil : la maison ou une piece.
    var indiceEtageIsole: Int? {
        guard case .etage(let cle) = isolement else { return nil }
        return scene?.etages.firstIndex { $0.id == cle }
    }

    private func ligne(_ niveau: NiveauZoom, ancres: [CGRect?]) -> LigneNiveau {
        if estIsolee, let nom = isolee { return .isolee(nom) }
        if let e = indiceEtageIsole, let nom = textes.etages[e] { return .etageIsole(nom) }
        switch niveau {
        case .pieces: return .pieces
        case .routeurs: return .routeurs
        case .tous:
            let n = PlacementNoms.masques(etiquettes, ancres: ancres, cadre: taille)
            return n > 0 ? .masques(n) : .lisibles
        }
    }

    private func avancer(_ now: Double) {
        dt = instant.map { min(0.1, max(0, now - $0)) } ?? 0
        instant = now
        let basculait = envol != nil || fondu != nil
        defer { if basculait && envol == nil && fondu == nil { basculeFinie() } }
        if let e = envol {
            let q = min(1, max(0, (now - debutEnvol) / CameraScene.dureeEnvol))
            (t, orbite) = e.pose(q, geometrie: geometrie, aspect: aspect)
            if q >= 1 {
                envol = nil
                t = e.arrivee
            }
        }
        if let f = fondu {
            let q = min(1, max(0, (now - f.debut) / CameraScene.dureeFondu))
            if q >= 0.5 && !f.saute {
                t = f.arrivee
                orbite = f.orbite ?? CameraScene.canonique(geometrie, aspect: aspect, u: t)
                fondu?.saute = true
            }
            opaciteFondu = abs(1 - 2 * q)
            if q >= 1 {
                fondu = nil
                opaciteFondu = 1
            }
        }
        if s != sCible {
            let r = min(1, max(0, (now - sDebut) / CameraScene.dureeVol))
            s = sDepart + (sCible - sDepart) * r
            if r >= 1 {
                s = sCible
                if s == 0 { finirRetour() }
            }
        }
        if se != seCible {
            let r = min(1, max(0, (now - seDebut) / CameraScene.dureeVol))
            se = seDepart + (seCible - seDepart) * r
            if r >= 1 {
                se = seCible
                if se == 0 { etageEnVue = nil }
            }
        }
        // Les parts propres, par cle : celle de la piece isolee et celle de l'etage en vue tendent vers 1.
        if let scene {
            let piece = focus.flatMap { $0 < scene.pieces.count && sCible == 1 ? scene.pieces[$0].id : nil }
            func tendre(_ x: Double?, vers c: Double) -> Double {
                var f = x ?? 0
                f += (c - f) * min(1, dt * 3.5)
                return abs(c - f) < 1e-3 ? c : f
            }
            for p in scene.pieces { fk[p.id] = tendre(fk[p.id], vers: p.id == piece ? 1 : 0) }
            for e in scene.etages { ek[e.id] = tendre(ek[e.id], vers: e.id == etageEnVue ? 1 : 0) }
        }
        // Les plateaux et les pieces glissent ; la vue suit ce qu'elle regarde.
        if glissementPlateaux != nil || transition != nil {
            let ancre0 = ancreCamera()
            if glissementPlateaux != nil {
                geometrie = geometrie(a: now)
                if geometrie == geometrieVisee { glissementPlateaux = nil }
            }
            if let tr = transition {
                if tr.finie(a: now) {
                    finirTransition()
                } else {
                    posesAffichees = tr.poses(a: now)
                }
            }
            suivre(depuis: ancre0)
        }
        if let v = vol {
            let q = min(1, max(0, (now - debutVol) / CameraScene.dureeVol))
            orbite = v.orbite(q, depuis: orbite)
            if q >= 1 {
                vol = nil
                viseeVol = nil
            }
        } else if envol == nil && fondu == nil {
            controles()
        }
        // Une grille qui attendait la vue d'ensemble 2D s'y pose.
        if let g = politique.attente, t == 0, aLaVueDEnsemble { poserGrille(g) }
        if !occupe, let e = attente { appliquer(e) }
    }

    /// La rotation lente tourne (`Isolement.rotationLente`), une piece ou un etage isoles compris (polissage D,
    /// section 4.2), sauf pendant un geste : un glisser (⌥ compris), le zoom de la molette en route, un pincement.
    private var rotationLente: Bool {
        Isolement.rotationLente(troisD: troisD, bascule: t, cochee: rotation, reduire: reduire,
                                geste: geste != nil || zoomEnAttente != 0 || dernierPincement != 1)
    }

    /// L'envol ou son fondu fini : le survol, le menu du clic droit et le curseur reprennent sous le pointeur immobile
    /// (polissage D, section 4), hors du rendu.
    private func basculeFinie() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.survoler(self.curseur, option: self.optionTenue)
        }
    }

    /// Rotation lente, rotation amortie, zoom amorti ; rien pendant ⌥ + glisser : ce qui attend reprend au relachement.
    private func controles() {
        guard !deplaceDansLEcran else { return }
        if rotationLente {
            orbite.azimut -= 2 * .pi / CameraScene.dureeTour * dt
        }
        if rotationEnAttente != .zero {
            let pas = rotationEnAttente * (1 - pow(0.95, 60 * dt))
            orbite.azimut += pas.x
            orbite.inclinaison = min(1.45, max(0.15, orbite.inclinaison + pas.y))
            rotationEnAttente -= pas
            if simd_length(rotationEnAttente) < 1e-5 { rotationEnAttente = .zero }
        }
        if zoomEnAttente != 0 {
            var pas = zoomEnAttente * (1 - exp(-dt * 16))
            if abs(zoomEnAttente) < 0.002 { pas = zoomEnAttente }
            let bornes = CameraScene.bornes(geometrie, aspect: aspect, troisD: t == 1, champ: orbite.champ)
            orbite = CameraScene.zoomer(orbite, facteur: pas, ancre: ancreZoom, bornes: bornes)
            zoomEnAttente -= pas
            if orbite.distance <= bornes.lowerBound || orbite.distance >= bornes.upperBound { zoomEnAttente = 0 }
        }
    }

    /// Fin du glissement d'une disposition : tout est pose.
    private func finirTransition() {
        transition = nil
        posesAffichees = PosesScene()
        apparencesParties = [:]
    }

    // MARK: Horloge

    func doitContinuer(_ now: Double) -> Bool {
        // Une scene qui attend la fin d'un glisser s'applique au relachement : pas d'image pour elle.
        if enMouvement || s != sCible || margesEnRoute || glissementPlateaux != nil || transition != nil
            || (attente != nil && geste == nil) {
            return true
        }
        if se != seCible || fk.values.contains(where: { $0 != 0 && $0 != 1 }) || ek.values.contains(where: { $0 != 0 && $0 != 1 }) {
            return true
        }
        if rotationLente { return true }
        if zoomEnAttente != 0 || rotationEnAttente != .zero || (geste != nil && bouge) { return true }
        if now - derniereActivite < 0.6 { return true }
        return etiquettes.contains { $0.envie > 0 }
    }

    /// Arrete l'horloge apres l'image (pas pendant le rendu).
    private func endormir() {
        guard anime else { return }
        Task { @MainActor [weak self] in
            guard let self, !self.doitContinuer(Self.maintenant()) else { return }
            self.anime = false
        }
    }

    func reveiller() {
        derniereActivite = Self.maintenant()
        if !anime {
            // Pas de temps nul a la premiere image : sinon le zoom amorti ferait un bond.
            instant = nil
            anime = true
        }
    }

    // MARK: Souris et clavier

    /// Noeud sous un point : sa pastille, a 8 points pres, sinon son nom.
    func noeudSous(_ p: CGPoint) -> String? {
        if let n = projetee?.noeud(sous: p, marge: 8) { return n }
        for l in etiquettes where l.vu && l.rect.contains(p) {
            if case .noeud(let id) = l.genre { return id }
        }
        return nil
    }

    /// Survol : le nom de l'appareil en semi-gras ; un disque cliquable s'eclaircit, le nom d'un etage se souligne ; la
    /// main sur ce qui se clique (polissage C, maquette). Rien pendant l'envol : ni clic, ni menu du clic droit.
    func survoler(_ p: CGPoint?, option: Bool = false) {
        curseur = p
        optionTenue = option
        let libre = envol == nil && fondu == nil
        let c = libre ? p.map(cibleClic(en:)) ?? .fond : .fond
        let n: String? = if case .appareil(let id) = c { id } else { nil }
        let disque: Int? = if case .disque(let e) = c, disqueCliquable(e) { e } else { nil }
        let nom: Int? = if case .nomEtage(let e) = c { e } else { nil }
        if n != survol || disque != survolEtage || nom != survolNomEtage {
            survol = n
            survolEtage = disque
            survolNomEtage = nom
            reveiller()
        }
        surCliquable = switch c {
        case .appareil, .piece: true
        case .nomEtage(let e): clicEtage(e, disque: false) != .rien
        case .disque(let e): disqueCliquable(e)
        case .fond: false
        }
        majCurseur()
        let cible = libre ? p.map(cible(en:)) ?? .aucune : .aucune
        if cible != cibleMenu { cibleMenu = cible }
    }

    /// ⌥ pressee ou relachee, le pointeur immobile (le moniteur des touches).
    func changerOption(_ option: Bool) {
        guard option != optionTenue else { return }
        optionTenue = option
        majCurseur()
    }

    /// Le curseur (polissage C, section 6) : une main fermee pendant ⌥ + glisser ; une main ouverte tant que ⌥ est
    /// tenue au-dessus de la vue en 3D ; sinon, une main sur ce qui se clique.
    private func majCurseur() {
        let forme: Curseur
        if case .ecran? = geste {
            forme = .mainFermee
        } else if optionTenue && curseur != nil && troisD && t == 1 && envol == nil && fondu == nil {
            forme = .mainOuverte
        } else {
            forme = surCliquable ? .main : .fleche
        }
        if forme != curseurForme { curseurForme = forme }
    }

    /// Ce que vise un clic en `p`, du plus fort au plus faible (polissage C, section 5.1).
    func cibleClic(en p: CGPoint) -> CibleClic {
        if let n = noeudSous(p) { return .appareil(n) }
        if let i = pieceSous(p) { return .piece(i) }
        if let e = nomEtageSous(p) { return .nomEtage(e) }
        if let e = disqueSous(p) { return .disque(e) }
        return .fond
    }

    /// Nom d'etage sous un point (`marge` points autour).
    func nomEtageSous(_ p: CGPoint, marge: CGFloat = 0) -> Int? {
        for l in etiquettes where l.vu && l.rect.insetBy(dx: -marge, dy: -marge).contains(p) {
            if case .etage(let e) = l.genre { return e }
        }
        return nil
    }

    /// Disque d'un plateau sous un point : en 3D, le plus proche sur le rayon, au point ou il le rencontre.
    func disqueSous(_ p: CGPoint) -> Int? {
        guard let projetee else { return nil }
        let proj = ProjectionScene(orbite, cadre: cadre)
        var meilleur: (etage: Int, profondeur: Double)?
        for pl in projetee.plateaux where pl.etage < geometrie.rayons.count && SceneProjetee.contient(pl.polygone, p) {
            let point = proj.sol(p, hauteur: geometrie.centrePlateau(pl.etage, t).y)
            let d = point.map { proj.profondeur($0) } ?? pl.profondeur
            if d < meilleur?.profondeur ?? .infinity { meilleur = (pl.etage, d) }
        }
        return meilleur?.etage
    }

    /// Un clic sur ce disque fait quelque chose (polissage C, section 5.4) : sauf celui de l'etage isole, entre ses
    /// pieces ; dans une maison d'un seul plateau, seulement depuis une piece isolee, pour remonter.
    func disqueCliquable(_ e: Int) -> Bool {
        clicEtage(e, disque: true) != .rien
    }

    /// Ce que fait un clic sur le nom ou le disque du plateau `e` (`Isolement.clicEtage`) : la regle du clic et de la
    /// main du pointeur.
    private func clicEtage(_ e: Int, disque: Bool) -> Isolement.ClicEtage {
        guard let scene, e < scene.etages.count else { return .rien }
        return isolement.clicEtage(scene.etages[e].id, disque: disque, plusieursPlateaux: scene.etages.count > 1,
                                   pieceIsolee: estIsolee)
    }

    /// Piece sous un point : son nom (le nom et le compte de ses appareils), sinon sa boite, la plus proche
    /// (verification du 02/10 : en 3D, les boites sont petites, et l'on clique volontiers sur le nom). Le nom,
    /// dessine par-dessus les boites, l'emporte sur celle d'une autre piece qu'il recouvre.
    func pieceSous(_ p: CGPoint) -> Int? {
        for l in etiquettes where l.vu && l.rect.contains(p) {
            if case .piece(let i) = l.genre { return i }
        }
        return projetee?.piece(sous: p)
    }

    /// Clic droit (polissage C, section 1.3) : le nom d'un etage, a 2 points pres, ou son disque, hors des pieces et
    /// des appareils, par la cle de son plateau ; le fond, hors de tout cela ; rien sur une piece ou un appareil.
    func cible(en p: CGPoint) -> CibleMenu {
        if let e = nomEtageSous(p, marge: 2) { return cleEtage(e).map(CibleMenu.etage) ?? .aucune }
        if noeudSous(p) != nil || pieceSous(p) != nil { return .aucune }
        if let e = disqueSous(p) { return cleEtage(e).map(CibleMenu.etage) ?? .aucune }
        return .fond
    }

    /// Un glisser, a chaque deplacement du pointeur ; `option` : ⌥ tenue, lue a l'appui seulement (polissage C,
    /// section 6) : en 3D, la vue glisse alors dans le plan de l'ecran, depuis le fond, un disque ou une piece, qui ne
    /// bouge pas ; un vol en cours s'arrete, et pendant le geste la camera n'obeit qu'au pointeur (`deplaceDansLEcran`).
    /// Relacher ⌥ en route ne change rien. En 2D, ⌥ ne change rien.
    func glisser(_ p: CGPoint, depart d: CGPoint, option: Bool = false) {
        // Un geste reste d'un glisser annule (sans relachement), et celui-ci part d'ailleurs : il est clos.
        if geste != nil, d != departGeste { terminerGeste() }
        if geste == nil {
            bouge = false
            abandonApresGlisser = false
            precedent = d
            departGeste = d
            if option && troisD && t == 1 && envol == nil && fondu == nil {
                vol = nil
                viseeVol = nil
                geste = .ecran(orbite)
            } else if !estIsolee, !enMouvement, let scene, let i = projetee?.piece(sous: d), i < scene.pieces.count,
                      indiceEtageIsole.map({ $0 == scene.pieces[i].etage }) ?? true {
                // Les pieces de l'etage isole se glissent ; celles des autres etages se cliquent seulement. Une piece en
                // route vers sa place y est posee, avec ses noeuds : elle suit le pointeur depuis sa place.
                transition?.oublier(pieces: [scene.pieces[i].id], noeuds: Set(scene.pieces[i].noeuds))
                if let tr = transition { posesAffichees = tr.poses(a: Self.maintenant()) }
                geste = .piece(scene.pieces[i].id, hauteur: centrePiece(i)?.y ?? 0)
            } else {
                geste = .fond
            }
            majCurseur()
        }
        if !bouge && hypot(p.x - d.x, p.y - d.y) < 5 { return }
        bouge = true
        defer { precedent = p }
        guard !enMouvement, let geste else { return }
        let proj = ProjectionScene(orbite, cadre: cadre)
        switch geste {
        case .ecran(let o):
            orbite = CameraScene.deplacerDansLEcran(o, glisse: CGSize(width: p.x - d.x, height: p.y - d.y), cadre: cadre)
            vueTouchee = true
        case .piece(let id, let h):
            guard let scene, let i = scene.pieces.firstIndex(where: { $0.id == id }), i < positions.count,
                  i < cartes.count, scene.pieces[i].etage < geometrie.rayons.count,
                  let a = proj.sol(precedent, hauteur: h), let b = proj.sol(p, hauteur: h) else { return }
            var pos = positions[i] + SIMD2(b.x - a.x, b.z - a.z)
            let r = max(0, geometrie.rayons[scene.pieces[i].etage] - 0.5 * hypot(cartes[i].largeur, cartes[i].profondeur))
            if simd_length(pos) > r { pos = simd_length(pos) > 0 ? simd_normalize(pos) * r : .zero }
            positions[i] = pos
        case .fond:
            if t == 0 {
                if let a = proj.sol(precedent, hauteur: orbite.cible.y), let b = proj.sol(p, hauteur: orbite.cible.y) {
                    orbite.cible += a - b
                    vueTouchee = true
                }
            } else {
                let h = max(1, Double(taille.height))
                rotationEnAttente.x -= 2 * .pi * Double(p.x - precedent.x) / h
                rotationEnAttente.y -= 2 * .pi * Double(p.y - precedent.y) / h
            }
        }
        reveiller()
    }

    /// Fin d'un glisser, ou clic. Deux clics sur le fond ou sur un disque, a moins de l'intervalle du double-clic
    /// de macOS et de 5 points : le second est un double-clic ; le premier a agi comme un clic simple. Une
    /// scene recue pendant le geste s'applique ensuite, avec la place gardee de la piece glissee.
    func relacher(_ p: CGPoint, a instant: Double = MoteurPieces.maintenant()) {
        let g = geste
        let clic = !bouge && !(g == nil && abandonApresGlisser)
        geste = nil
        bouge = false
        abandonApresGlisser = false
        majCurseur()
        if case .piece(let id, _)? = g, !clic {
            garder(id)
        } else if clic {
            let fond = switch cibleClic(en: p) {
            case .fond, .disque: true
            default: false
            }
            if fond, let c = clicFond, instant - c.instant <= NSEvent.doubleClickInterval,
               hypot(p.x - c.point.x, p.y - c.point.y) <= 5 {
                clicFond = nil
                if envol == nil, fondu == nil { doubleCliquer() }
            } else {
                clicFond = fond ? (instant, p) : nil
                cliquer(p)
            }
        }
        if !occupe, let e = attente { appliquer(e) }
        reveiller()
    }

    /// Geste annule : SwiftUI remet l'etat du geste a zero sans appeler `onEnded` (la vue quitte la
    /// fenetre pendant le geste, ou le geste est interrompu). Il est clos sans clic, la piece glissee
    /// garde sa place, et la scene en attente s'applique. Apres un relachement, plus de geste : rien.
    func abandonnerGeste() {
        guard geste != nil else { return }
        abandonApresGlisser = bouge
        terminerGeste()
        if !occupe, let e = attente { appliquer(e) }
        reveiller()
    }

    /// Clot un geste reste ouvert (glisser annule, sans relachement) : la piece glissee garde sa place,
    /// sans clic. Depuis `glisser`, la scene en attente s'applique a la fin du geste suivant (sinon les
    /// indices de la projection, qui a servi a le commencer, periment) ; depuis `abandonnerGeste`, elle
    /// s'applique tout de suite apres, sauf pendant un mouvement.
    private func terminerGeste() {
        if case .piece(let id, _)? = geste, bouge { garder(id) }
        geste = nil
        bouge = false
        majCurseur()
    }

    /// Clic sans glisser, selon sa cible (polissage C, sections 5.1 et 5.4) : un appareil ou son nom ouvre sa fiche ;
    /// une piece ou son nom l'isole (en piece isolee, une autre piece y mene, meme pendant le vol) ; le nom ou le
    /// disque d'un etage l'isole ; a cote, la fiche se ferme et la vue remonte d'ou elle vient. Rien pendant l'envol.
    func cliquer(_ p: CGPoint) {
        guard envol == nil, fondu == nil else { return }
        switch cibleClic(en: p) {
        case .appareil(let n):
            selection = n
        case .piece(let i):
            if !(focus == i && sCible == 1) { isoler(i) }
        case .nomEtage(let e):
            cliquerEtage(e, disque: false)
        case .disque(let e):
            cliquerEtage(e, disque: true)
        case .fond:
            selection = nil
            remonter(clavier: false)
        }
    }

    /// Clic sur le nom ou le disque d'un etage : il l'isole ; son propre disque, l'etage isole, entre les pieces, ne
    /// fait rien. Maison d'un seul plateau : seulement depuis une piece isolee, pour remonter a la maison.
    private func cliquerEtage(_ e: Int, disque: Bool) {
        switch clicEtage(e, disque: disque) {
        case .isoler: allerEtage(e)
        case .maison: versMaison()
        case .rien: break
        }
    }

    /// La molette zoome, sauf pendant un vol et pendant ⌥ + glisser : elle est alors ignoree, non differee. Au-dessus
    /// d'un element pose sur la vue (`p`, dans la vue : la fiche, la legende, la ligne des capsules, la colonne du haut),
    /// elle n'est pas prise (faux) : l'evenement leur revient (polissage D, section 3).
    @discardableResult
    func molette(_ dy: Double, precis: Bool, en p: CGPoint? = nil) -> Bool {
        if let p, surInterface(p) { return false }
        guard !enMouvement, !deplaceDansLEcran else { return true }
        zoomer(precis ? -dy * 0.004 : -dy * 0.08, en: curseur)
        return true
    }

    /// Le point `p` de la vue est sur un element pose sur elle.
    func surInterface(_ p: CGPoint) -> Bool {
        cadresInterface.values.contains { $0.contains(p) }
    }

    /// Le pincement zoome de son increment depuis le dernier `m`, sauf pendant un vol et pendant ⌥ + glisser : il est
    /// alors ignore, mais suivi, pour que celui qui continue apres ne saute pas de ce qu'il a fait pendant.
    func pincer(_ m: Double, en p: CGPoint) {
        let l = -log(max(0.05, m) / max(0.05, dernierPincement))
        dernierPincement = m
        guard !enMouvement, !deplaceDansLEcran else { return }
        zoomer(l, en: p)
    }

    func finPincement() { dernierPincement = 1 }

    /// Zoom amorti ; en 2D, vers le point sous le curseur.
    private func zoomer(_ l: Double, en p: CGPoint?) {
        ancreZoom = nil
        if t == 0, let p { ancreZoom = ProjectionScene(orbite, cadre: cadre).sol(p, hauteur: orbite.cible.y) }
        zoomEnAttente += l
        vueTouchee = true
        reveiller()
    }

    /// Molette et Echap, dans la fenetre de la vue seulement : un moniteur local (SwiftUI n'a pas
    /// d'evenement de molette brut).
    func ecouter() {
        guard moniteur == nil else { return }
        moniteur = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown, .flagsChanged]) { [weak self] e in
            guard let self else { return e }
            let pris = MainActor.assumeIsolated { self.prendre(e) }
            return pris ? nil : e
        }
    }

    /// Un evenement du moniteur, dans la fenetre de la vue seulement : la molette, au-dessus de la scene (pas d'un element
    /// pose sur elle), et Echap, s'il a quelque chose a faire, sont pris (vrai : le moniteur rend nil) ; ⌥ pressee ou
    /// relachee met a jour la main ouverte (polissage C, section 6) et continue son chemin, comme tout le reste.
    func prendre(_ e: NSEvent) -> Bool {
        guard e.window != nil, e.window === fenetre else { return false }
        return prendre(EvenementVue(e))
    }

    /// Ce que le moniteur lit d'un evenement de la fenetre de la vue.
    struct EvenementVue {
        enum Genre {
            /// La molette : son pas, precis (trackpad) ou non, et le point du pointeur dans la fenetre.
            case molette(dy: Double, precis: Bool, position: CGPoint)
            case echap
            /// ⌥ tenue ou non.
            case option(Bool)
            case autre
        }

        var genre: Genre

        init(_ genre: Genre) {
            self.genre = genre
        }

        init(_ e: NSEvent) {
            switch e.type {
            case .scrollWheel:
                genre = .molette(dy: Double(e.scrollingDeltaY), precis: e.hasPreciseScrollingDeltas, position: e.locationInWindow)
            case .keyDown where e.keyCode == 53:
                genre = .echap
            case .flagsChanged:
                genre = .option(e.modifierFlags.contains(.option))
            default:
                genre = .autre
            }
        }
    }

    /// La meme chose, une fois l'evenement lu.
    func prendre(_ e: EvenementVue) -> Bool {
        switch e.genre {
        case .molette(let dy, let precis, let position):
            return molette(dy, precis: precis, en: vue.map { VuePieces.point(position, dans: $0) })
        case .echap:
            return sortir()
        case .option(let option):
            changerOption(option)
            return false
        case .autre:
            return false
        }
    }

    func arreterEcoute() {
        if let m = moniteur { NSEvent.removeMonitor(m) }
        moniteur = nil
    }

    // MARK: Etats poses a la main (captures, tests)

    func poserBascule(_ q: Double) {
        t = CameraScene.rampe(q)
        troisD = q > 0
        orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
    }

    /// Une piece isolee, au bout de son vol ; `depuisEtage` : ouverte depuis son etage isole (sa provenance).
    func poserIsolement(_ i: Int, depuisEtage: Bool = false) {
        guard let scene, i < scene.pieces.count else { return }
        let etage = scene.etages[scene.pieces[i].etage].id
        isolement = .piece(scene.pieces[i].id, provenance: depuisEtage ? etage : nil)
        focus = i
        isolee = textes.pieces[i]?.nom
        s = 1
        sCible = 1
        fk[scene.pieces[i].id] = 1
        if scene.etages.count > 1 {
            etageEnVue = etage
            se = 1
            seCible = 1
            ek[etage] = 1
        }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        majFil()
        if let v = volVersPiece(i) { orbite = v.orbite(1, depuis: orbite) }
    }

    /// Un etage isole, au bout de son vol.
    func poserEtageIsole(_ e: Int) {
        guard let scene, scene.etages.count > 1, e < scene.etages.count else { return }
        let cle = scene.etages[e].id
        isolement = .etage(cle)
        etageEnVue = cle
        se = 1
        seCible = 1
        ek[cle] = 1
        majFil()
        orbite = volVersEtage(e).orbite(1, depuis: orbite)
    }

    func poserSurvol(_ id: String?) { survol = id }

    /// Le glissement d'une disposition, pose a `q` (de 0 a 1) de son temps, sans horloge : les poses des pieces et des
    /// noeuds, et les plateaux qui glissent avec eux.
    func poserTransition(_ q: Double) {
        guard let tr = transition else { return }
        posesAffichees = tr.poses(a: tr.debut + q * TransitionScene.duree)
        if let gl = glissementPlateaux { geometrie = geometrie(a: gl.debut + q * max(gl.duree2D, gl.duree3D)) }
    }

    /// Le glissement d'une disposition et celui des plateaux, commences `dt` secondes plus tot (tests) : l'image suivante
    /// les avance d'autant, par l'horloge.
    func reculerTransition(de dt: Double) {
        transition?.debut -= dt
        glissementPlateaux?.debut -= dt
    }

    func poserAzimut(_ decalage: Double) { orbite.azimut += decalage }

    func poserInclinaison(_ i: Double) { orbite.inclinaison = i }

    /// Centre du bloc d'une piece, dans le monde ; dans la geometrie de l'image, ou dans `g`.
    func centrePiece(_ i: Int, dans g: GeometrieMaison? = nil) -> SIMD3<Double>? {
        guard let scene, i < scene.pieces.count, i < positions.count else { return nil }
        let g = g ?? geometrie
        // En route (polissage D, section 1) : sa pose affichee.
        if let pose = posesAffichees.pieces[scene.pieces[i].id],
           let m = PosesScene.centre(pose.ancres, geometrie: g, plateaux: plateaux(scene), t: t) {
            return SIMD3(m.x, m.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, m.z)
        }
        let c = g.centrePlateau(scene.pieces[i].etage, t)
        return SIMD3(c.x + positions[i].x, c.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, c.z + positions[i].y)
    }

    /// L'indice de chaque plateau de la scene, par cle.
    private func plateaux(_ scene: ScenePieces) -> [String: Int] {
        Dictionary(scene.etages.indices.map { (scene.etages[$0].id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Zoom a l'echelle `k` (points par unite a la cible, divises par 24), vers le point `vers`.
    func poserZoom(echelle k: Double, vers a: SIMD3<Double>?) {
        let k0 = ProjectionScene(orbite, cadre: cadre).pxParUnite(orbite.cible) / CartesPieces.px
        let f = k0 / k
        if let a { orbite.cible = a + (orbite.cible - a) * f }
        orbite.distance *= f
        vueTouchee = true
    }

    /// Pose le cadre sans image, et la grille de cette zone visible, tout de suite (captures, tests).
    func poserTaille(_ nouvelle: CGSize) {
        taille = nouvelle
        zoneGrille = zoneVisible
        margesCadre = marges
        glissement = nil
        cadre = CGRect(x: 0, y: marges.haut, width: nouvelle.width,
                       height: max(1, nouvelle.height - marges.haut - marges.bas))
        guard pret, let scene else { return }
        politique.choisir(rayons: rayons(scene), zone: zoneVisible, enPlace: true)
        glissementPlateaux = nil
        politique.oublierAttente()
        geometrieVisee = geometriePour(scene)
        geometrie = geometrieVisee
        recadrer()
    }
```

par :

```swift
    var troisD: Bool
    var rotation = true
    /// Horloge en marche : seulement pendant un mouvement, et 0,6 s apres.
    var anime = true
    /// Nom de la piece isolee ; nil sinon.
    var isolee: String?
    /// Ce que montre la vue, et sa provenance (polissage C, section 5) ; le fil qui le dit.
    var isolement = Isolement.maison
    var fil = Fil()
    var curseurForme = Curseur.fleche
    var selection: String?
    var ligneNiveau = LigneNiveau.lisibles
    var cibleMenu = CibleMenu.aucune
    /// Version de la scene la plus recente (`sceneRecente`), observee : elle change avec elle, a chaque scene
    /// recue, en calcul ou posee. Le menu du clic droit la lit (`menuEtage`) : rouvert sur la meme cible apres un
    /// choix, il suit la scene de ce choix, que SwiftUI ne voit pas (relecture finale, Important 1).
    private(set) var versionScene = 0
    var places: PlacesGardees
    /// La premiere disposition est calculee.
    var pret = false
    /// « Reduire les animations » (accessibilite de macOS).
    var reduire = false {
        didSet { reveiller() }
    }

    nonisolated static let journal = Logger(subsystem: "fr.djoko.maillage", category: "pieces")

    // MARK: Etat non observe

    @ObservationIgnored let fichierPlaces: URL?
    /// Scene affichee, posee sur sa disposition.
    @ObservationIgnored var entree: EntreeScene? {
        didSet { versionScene &+= 1 }
    }
    /// Scene recue pendant un mouvement ou un glisser : appliquee a sa fin.
    @ObservationIgnored var attente: EntreeScene? {
        didSet { versionScene &+= 1 }
    }
    /// Scene dont la disposition se calcule : `entree` reste affichee jusqu'a la fin du calcul.
    @ObservationIgnored var enCalcul: EntreeScene? {
        didSet { versionScene &+= 1 }
    }
    @ObservationIgnored var calcul: Task<Void, Never>?
    @ObservationIgnored var cleCalculee: EntreeScene.CleDisposition?
    @ObservationIgnored var placesCalculees: [String: SIMD2<Double>] = [:]
    @ObservationIgnored var rayonsCalcules: [String: Double] = [:]
    @ObservationIgnored var cartesCalculees: [String: CartesPieces.Carte] = [:]
    @ObservationIgnored var cartes: [CartesPieces.Carte] = []
    @ObservationIgnored var positions: [SIMD2<Double>] = []
    /// La geometrie de l'image ; elle rejoint la geometrie visee (`geometrieVisee`) quand les plateaux glissent.
    @ObservationIgnored var geometrie = GeometrieMaison(rayons: [])
    /// La geometrie de la scene, avec les rayons de sa disposition et la grille du reglage.
    @ObservationIgnored var geometrieVisee = GeometrieMaison(rayons: [])
    @ObservationIgnored var glissementPlateaux: GlissementPlateaux?
    /// Le glissement d'une disposition a l'autre (polissage D, section 1) : les pieces, les noeuds et les liens qui
    /// changent, de leur pose affichee a leur nouvelle pose ; nil au repos.
    @ObservationIgnored var transition: TransitionScene?
    /// Les poses de l'image, de ce qui est en transition : la scene projetee les prend, la camera les suit.
    @ObservationIgnored var posesAffichees = PosesScene()
    /// Le dessin des pastilles qui s'effacent, absentes de la scene : celui de la scene d'avant.
    @ObservationIgnored var apparencesParties: [String: DessinNoeud.Apparence] = [:]
    /// La politique de la grille 2D (polissage C, section 3 ; dans le coeur depuis le polissage D, section 5) : le
    /// reglage « Etages en 2D », pose par la fenetre, les colonnes choisies, une demande qui attend la vue d'ensemble 2D.
    @ObservationIgnored var politique = PolitiqueGrille()
    var grille: Bool { politique.grille }
    var colonnes: Int? { politique.colonnes }
    var grilleEnAttente: GrilleEnAttente? { politique.attente }
    /// Ce que vise le vol en cours : son arrivee suit les plateaux qui glissent.
    @ObservationIgnored var viseeVol: Visee?
    @ObservationIgnored var orbite = Orbite(cible: .zero, distance: 1000, azimut: 0, inclinaison: 0.0001, champ: 2)
    @ObservationIgnored var taille = CGSize.zero
    /// Marges du haut (le haut de la fenetre, mesure) et du bas (la pile du bas, mesuree : la legende et la ligne
    /// de niveau, puis la fiche), posees par la vue : la place utile de la vue d'ensemble. Le cadre les rejoint en
    /// 0,3 s, sur la courbe de la fiche qui glisse (`Apparition`) : la vue se releve avec elle, au-dessus de la pile,
    /// ou descend sous un bandeau ; en 0,45 s quand la legende s'ouvre ou se replie (`legendeBasculee`) ; avec
    /// « Reduire les animations », par un fondu.
    @ObservationIgnored var marges: (haut: CGFloat, bas: CGFloat) = (0, 0)
    /// Marge du bas de la zone visible ou se choisit la grille (polissage C, section 3.3) : celle de la legende, ouverte
    /// ou repliee, sans la fiche, qui va et vient (`FenetrePieces.margeBasGrille`) ; nil : celle du cadre.
    @ObservationIgnored var basGrille: CGFloat?
    /// La zone visible de la derniere image : une autre recalcule la grille.
    @ObservationIgnored var zoneGrille = CGSize.zero
    /// Marges du cadre, et leur glissement en cours vers `marges`.
    @ObservationIgnored var margesCadre: (haut: CGFloat, bas: CGFloat)?
    @ObservationIgnored var glissement: GlissementMarges?
    /// Duree du prochain glissement des marges : celle de la legende, qui vient de s'ouvrir ou de se replier
    /// (`legendeBasculee`) ; nil, celle de la fiche et des bandeaux.
    @ObservationIgnored var dureeAnnoncee: Double?
    /// Opacite de la scene pendant le fondu des marges (« Reduire les animations ») ; 1 sinon.
    @ObservationIgnored var opaciteMarges = 1.0
    @ObservationIgnored var cadre = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// Bascule adoucie : 0 en 2D, 1 en 3D.
    @ObservationIgnored var t: Double
    @ObservationIgnored var envol: Envol?
    @ObservationIgnored var debutEnvol = 0.0
    /// « Reduire les animations » : l'envol, et le retour a la vue d'ensemble par double-clic, sont un
    /// fondu ; la camera saute a mi-chemin.
    @ObservationIgnored var fondu: Fondu?
    @ObservationIgnored var opaciteFondu = 1.0
    /// Isolement : `s` general, `fk` propre a chaque piece.
    @ObservationIgnored var s = 0.0
    @ObservationIgnored var sCible = 0.0
    @ObservationIgnored var sDepart = 0.0
    @ObservationIgnored var sDebut = 0.0
    @ObservationIgnored var focus: Int?
    /// Part propre a chaque piece de l'isolement, gardee par cle (triage A, n° 9).
    @ObservationIgnored var fk: [String: Double] = [:]
    /// Isolement d'un etage (polissage C, section 5) : `se` general, `ek` propre a chaque plateau, par cle ; l'etage
    /// en vue (isole, celui de la piece isolee, ou qui l'etait, pendant le retour).
    @ObservationIgnored var se = 0.0
    @ObservationIgnored var seCible = 0.0
    @ObservationIgnored var seDepart = 0.0
    @ObservationIgnored var seDebut = 0.0
    @ObservationIgnored var ek: [String: Double] = [:]
    @ObservationIgnored var etageEnVue: String?
    /// Disque cliquable et nom d'etage sous le pointeur.
    @ObservationIgnored var survolEtage: Int?
    @ObservationIgnored var survolNomEtage: Int?
    @ObservationIgnored var vol: Vol?
    @ObservationIgnored var debutVol = 0.0
    @ObservationIgnored var survol: String?
    @ObservationIgnored var curseur: CGPoint?
    @ObservationIgnored var zoomEnAttente = 0.0
    @ObservationIgnored var ancreZoom: SIMD3<Double>?
    @ObservationIgnored var dernierPincement = 1.0
    @ObservationIgnored var rotationEnAttente = SIMD2<Double>.zero
    @ObservationIgnored var geste: Geste?
    /// Point de depart du geste en cours : un glisser qui part d'ailleurs en commence un autre.
    @ObservationIgnored var departGeste = CGPoint.zero
    @ObservationIgnored var bouge = false
    /// Le dernier geste, qui avait bouge, a ete clos par `abandonnerGeste` : si son relachement arrive
    /// encore (SwiftUI peut remettre l'etat du geste a zero avant d'appeler `onEnded`), ce n'est pas un
    /// clic.
    @ObservationIgnored var abandonApresGlisser = false
    @ObservationIgnored var precedent = CGPoint.zero
    @ObservationIgnored var derniereActivite = 0.0
    @ObservationIgnored var instant: Double?
    @ObservationIgnored var dt = 0.0
    /// Djoko a zoome ou deplace la vue : un redimensionnement ne la recadre plus.
    @ObservationIgnored var vueTouchee = false
    @ObservationIgnored var etiquettes: [Etiquette] = []
    @ObservationIgnored var textes = TextesScene()
    /// Noeuds routeurs (leur nom en 12 points) et teinte de chaque piece, pour le dessin.
    @ObservationIgnored var routeurs: Set<String> = []
    @ObservationIgnored var teintes: [Int: Int] = [:]
    @ObservationIgnored var projetee: SceneProjetee?
    @ObservationIgnored var traits: [PlacementNoms.Trait] = []
    /// Cles des pieces et des etages de la scene des noms : un nom garde son etat d'une scene a l'autre.
    @ObservationIgnored var clesPieces: [String] = []
    @ObservationIgnored var clesEtages: [String] = []
    @ObservationIgnored let cache = CacheTextes()
    @ObservationIgnored let mesure = MesureNoms()
    /// Ce qui est pose sur la vue (barre, fil, ligne de niveau, legende, fiche), par element : les noms
    /// l'evitent.
    @ObservationIgnored var cadresInterface: [String: CGRect] = [:]
    /// Fenetre de la vue : la molette et Echap ne valent que pour elle. La vue, dans AppKit : le point de la molette.
    @ObservationIgnored weak var fenetre: NSWindow?
    @ObservationIgnored weak var vue: NSView?
    @ObservationIgnored var moniteur: Any?
    /// Captures : l'etat est pose a la main, l'horloge n'avance pas.
    @ObservationIgnored var fige = false

    /// Dernier clic sur le fond (instant, point) : un second, assez pres et assez tot, est un double-clic.
    @ObservationIgnored var clicFond: (instant: Double, point: CGPoint)?

    enum Geste {
        case fond
        /// Une piece qu'on glisse (son identifiant, jamais un indice qui perimerait), sur le plan
        /// horizontal y = `hauteur`.
        case piece(String, hauteur: Double)
        /// ⌥ + glisser en 3D : la vue glisse dans le plan de l'ecran, depuis l'orbite de l'appui.
        case ecran(Orbite)
    }

    /// ⌥ est tenue (le survol et le moniteur des touches la suivent) ; ce que le pointeur vise est cliquable.
    @ObservationIgnored var optionTenue = false
    @ObservationIgnored var surCliquable = false

    /// ⌥ + glisser en cours : la camera n'obeit qu'au pointeur. La maquette coupe alors ses controles : l'inertie de
    /// rotation et le zoom amorti attendent, la molette et le pincement sont ignores ; au relachement, tout reprend.
    var deplaceDansLEcran: Bool {
        if case .ecran? = geste { true } else { false }
    }

    /// Glissement des marges du cadre, de `depart` a `arrivee`, depuis `debut`, en `duree` ; `fondu` : avec
    /// « Reduire les animations », un fondu par le fond, les marges sautant a mi-chemin.
    struct GlissementMarges {
        var depart: (haut: CGFloat, bas: CGFloat)
        var arrivee: (haut: CGFloat, bas: CGFloat)
        var debut: Double
        var duree: Double
        var fondu: Bool
    }

    /// Glissement des plateaux (polissage C, sections 1.3 et 3.5) : de `depart`, la geometrie de l'image a son debut,
    /// remise dans l'ordre des plateaux de la scene, vers la geometrie visee ; en 2D en `duree2D`, en 3D en
    /// `duree3D` (0 : sans glissement), en cubique entree-sortie.
    struct GlissementPlateaux {
        var depart: GeometrieMaison
        var debut: Double
        var duree2D: Double
        var duree3D: Double
    }

    /// Une grille voulue qui attend la vue d'ensemble 2D : la duree du glissement de ses plateaux, et si elle garde
    /// la grille en place tant qu'elle est a moins de 5 % du choix (un redimensionnement).
    typealias GrilleEnAttente = PolitiqueGrille.Demande

    /// Ce que vise un vol : la vue d'ensemble, une piece ou un etage (sa cle).
    enum Visee {
        case ensemble
        case piece(String)
        case etage(String)
    }

    /// Fondu de 0,3 s par le fond (« Reduire les animations ») : la scene s'efface, la camera saute a
    /// mi-chemin, la scene revient.
    struct Fondu {
        var debut: Double
        /// Avancement de la bascule vise : 0 en 2D, 1 en 3D (le meme pour un retour a la vue d'ensemble).
        var arrivee: Double
        /// Camera a mi-chemin : la fin du vol (retour a la vue d'ensemble) ; nil : la vue d'ensemble du
        /// mode vise (bascule).
        var orbite: Orbite?
        var saute = false
    }

    /// `troisD` : le mode garde ; `fichierPlaces` : `positions-pieces.json` (nil : ni lu ni ecrit) ; `places` : sans
    /// fichier, les places de depart, en memoire (la demo et son choix de niveau).
    init(troisD: Bool = false, fichierPlaces: URL? = nil, selection: String? = nil, places depart: PlacesGardees? = nil) {
        self.troisD = troisD
        t = troisD ? 1 : 0
        self.fichierPlaces = fichierPlaces
        places = fichierPlaces.map(PlacesGardees.lire) ?? depart ?? PlacesGardees()
        self.selection = selection
    }

    static func maintenant() -> Double { CACurrentMediaTime() }

    var scene: ScenePieces? { entree?.scene }
    var aspect: Double { cadre.height > 0 ? Double(cadre.width / cadre.height) : 1.6 }
    /// Une piece est isolee (et non en train d'etre quittee).
    var estIsolee: Bool { focus != nil && sCible == 1 }
    var enMouvement: Bool { envol != nil || fondu != nil || vol != nil }
    /// La vue est a la vue d'ensemble : ni zoomee, ni deplacee, ni isolee, ni en mouvement.
    var aLaVueDEnsemble: Bool { pret && !vueTouchee && sansIsolement && !enMouvement }
    /// Ni piece ni etage isoles, ni en train d'etre quittes.
    var sansIsolement: Bool { isolement == .maison && focus == nil && etageEnVue == nil }
    /// Un mouvement, ou un glisser en cours (spec, sections 5 et 7) : une scene recue attend sa fin.
    var occupe: Bool { enMouvement || geste != nil }
```

- [ ] **Step 3 : les nouveaux fichiers dans la cible.** Rien à faire : `outils/tester.sh` lance `xcodegen generate`, et la cible de l'app prend tout le dossier `MaillageThread` (`project.yml`). Ni `project.yml` ni le projet généré, non commité, ne se modifient à la main.

- [ ] **Step 4 : toute la suite.** Les tests ne changent pas.

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh`
Expected: `Test run with 396 tests in 41 suites passed` (cœur) et `Test run with 363 tests in 32 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, l'app inchangée.

- [ ] **Step 5 : vérifier que le code est déplacé tel quel.** Les six fichiers, remis bout à bout dans l'ordre (la classe, puis les extensions, sans leurs `import` ni leur en-tête), sans le mot `private`, redonnent le moteur d'avant sans le mot `private`, au caractère près.

```bash
python3 - <<'EOF'
import os, pathlib
P = 'MaillageThread/Vues/Pieces/'
def nu(t):
    return t.replace('private(set) ', '').replace('private ', '')
avant = nu(open(os.path.expanduser('~/Library/Caches/maillage-polD/MoteurPieces-avant.swift')).read())
morceaux = open(P + 'MoteurPieces.swift').read().split('\n')[:-2]
for k in ['Scene', 'Camera', 'Image', 'Gestes', 'Poses']:
    lignes = open(P + 'MoteurPieces+' + k + '.swift').read().split('\n')
    debut = lignes.index('extension MoteurPieces {')
    morceaux += [''] + lignes[debut + 1:-2]
morceaux += ['}', '']
print('deplace tel quel' if nu('\n'.join(morceaux)) == avant else 'ECART')
print(sum(f.read_text().count('private') for f in pathlib.Path(P).glob('MoteurPieces*.swift')), 'private')
print(max(len(f.read_text().split('\n')) - 1 for f in pathlib.Path(P).glob('MoteurPieces*.swift')), 'lignes au plus')
EOF
```

Expected : `deplace tel quel`, `29 private`, `402 lignes au plus`.

- [ ] **Step 6 : les images de démo, identiques.** Comparées à celles de la tâche 6 : identiques, octet pour octet. Si une image diffère, s'arrêter : la tâche a changé le rendu. Les images se rendent toujours juste après la suite du step précédent, avec l'app qu'elle vient de compiler.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t7"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "maillage-polD/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
for f in $(ls "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t6"); do cmp -s "$D/$f" "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t6/$f" && echo "$f identique" || echo "$f differe"; done | sort | awk '{print $2}' | uniq -c
```

Expected : 20 ; « l'app a quitté » ; « 20 identique ».

- [ ] **Step 7 : commit.**

```bash
git add MaillageThread/Vues/Pieces/MoteurPieces+Camera.swift MaillageThread/Vues/Pieces/MoteurPieces+Gestes.swift MaillageThread/Vues/Pieces/MoteurPieces+Image.swift MaillageThread/Vues/Pieces/MoteurPieces+Poses.swift MaillageThread/Vues/Pieces/MoteurPieces+Scene.swift MaillageThread/Vues/Pieces/MoteurPieces.swift
git commit -m "Decouper le moteur de la vue par pieces en six fichiers, par responsabilite, le code deplace tel quel, sans private pour ce qu'un autre fichier du moteur lit ou ecrit

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Mutants essayés sur la copie validée** (chacun appliqué seul, la tâche jouée par ses tests ; un mutant qui ne compilait pas a été rejoué sous une forme qui compile, sauf pour le découpage, où la compilation est l'attente) :

Le déplacement lui-même se vérifie par le Step 5. Trois mutants : un `private(set)` remis sur un membre qu'une extension écrit (`geometrie`) : la compilation échoue ; un appel perdu au déplacement (`zoneChangee()` dans l'image) : la compilation échoue (une variable devient inutilisée, et les avertissements sont des erreurs) ; un corps changé en route (`recadrer` qui ne garde plus l'orbite en 3D) : tué par `pieceIsoleeQuiDisparait`, et vu par le Step 5.

### Task 8: La démo et ses vingt et une images ; le README

**Files:**
- Modify: `MaillageThread/Vues/Pieces/CapturesPieces.swift`, `README.fr.md`, `README.md` (blocs ci-dessous)
- Test: `MaillageThreadTests/FenetrePiecesTests.swift`

**Interfaces:**
- Consumes : `MoteurPieces.poserTransition(_:)` (tâche 3), `poserZoom`, `centrePiece`, `PiecesRouteurs.choisir(_:appareil:domicile:)`, `EntreeScene(surveillance:reseau:places:choix:)`, `CapturesPieces`, existants.
- Produces : `CapturesPieces.Cas.deplacer`, `CapturesPieces.appareilDansLaCuisine`, l'image `21-2d-appareil-en-route` ; le README, en anglais et en français.

**L'image du glissement** (spec, section 6 ; précision 15) : la scène de la démo, puis celle où l'appareil inconnu « Non identifié · 041F » (ExtMac `E0000000000000FF`), sans pièce, est placé dans la cuisine par « Placer dans une pièce… » (`PiecesRouteurs`), posée à mi-chemin de son glissement, la vue zoomée (k = 1) vers « Sans pièce ». La cuisine et « Sans pièce » échangent leur place dans la nouvelle disposition : à mi-chemin, leurs cartes se croisent.

**Le README** décrit les glissements, les badges qui ne bougent plus rien, le routeur aux candidats, la molette, Échap, la rotation lente pendant un isolement, l'échelle et le survol du signal, et les vingt et une images.

- [ ] **Step 1 : écrire les tests.** Les vingt et une images ; l'image du glissement.

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
@testable import MaillageCoeur
```

par :

```swift
@testable import MaillageCoeur
import simd
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        ])
```

par :

```swift
            "21-2d-appareil-en-route",
        ])
        #expect(CapturesPieces.cas.filter { $0.deplacer != nil }.map(\.nom) == ["21-2d-appareil-en-route"])
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        #expect(FicheNoeud.couronne(choisi, entree: e))
```

par :

```swift
        #expect(FicheNoeud.couronne(choisi, entree: e))
    }

    /// L'image du glissement (polissage D, section 6) : la scene de la demo, puis celle ou l'appareil inconnu « 041F »,
    /// sans piece, est place dans la cuisine ; posee a mi-chemin, sa pastille est en route, loin de ses deux places.
    @Test func imageDuGlissement() throws {
        let (s, r, e) = try NomsSceneTests.demo()
        let cas = try #require(CapturesPieces.cas.first { $0.nom == "21-2d-appareil-en-route" })
        let choix = try #require(cas.deplacer)
        let e2 = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees(), choix: choix)
        let id = "rloc:041F"
        #expect(e.scene.noeud(id).map { e.scene.pieces[$0.piece].nom } == .sansPiece)
        #expect(e2.scene.noeud(id).map { e2.scene.pieces[$0.piece].nom } == .maison("Cuisine"))
        let m = MoteurPieces()
        m.fige = true
        m.marges = (84, 50)
        m.poserTaille(MoteurPiecesTests.taille)
        m.installerMaintenant(e)
        MoteurPiecesTests.dessiner(m)
        let avant = try #require(m.projetee?.centresNoeuds[id])
        m.installerMaintenant(e2)
        m.poserTransition(1)
        MoteurPiecesTests.dessiner(m)
        let apres = try #require(m.projetee?.centresNoeuds[id])
        cas.poser(m, e2.scene)
        MoteurPiecesTests.dessiner(m)
        let mi = try #require(m.projetee?.centresNoeuds[id])
        let d = simd_distance(avant, apres)
        #expect(d > 3 && simd_distance(mi, avant) > 0.25 * d && simd_distance(mi, apres) > 0.25 * d)
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests`
Expected: la compilation des tests échoue (`FenetrePiecesTests.swift`), par exemple avec `error: value of type 'CapturesPieces.Cas' has no member 'deplacer'` et `error: no calls to throwing functions occur within 'try' expression [#UnnecessaryEffectMarker]` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
/// rangee (la zone visible, section 3.3). Sans fenetre ni capture d'ecran ;
```

par :

```swift
/// rangee (la zone visible, section 3.3). Puis un appareil a mi-chemin de son glissement vers une autre piece
/// (polissage D, section 6). Sans fenetre ni capture d'ecran ;
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
    /// en grille ou en rangee, et les places gardees, dont le choix de niveau du jardin.
```

par :

```swift
    /// en grille ou en rangee, et les places gardees, dont le choix de niveau du jardin ; `deplacer` : apres la scene
    /// de la demo, celle des pieces choisies (« Placer dans une piece… »), posee a mi-chemin de son glissement.
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
        var places = NomsDemo.places()
```

par :

```swift
        var places = NomsDemo.places()
        var deplacer: PiecesRouteurs?
    }

    /// L'appareil inconnu de la demo, que seule la sonde connait (« Non identifie · 041F », sans piece), place dans la
    /// cuisine.
    static var appareilDansLaCuisine: PiecesRouteurs {
        var p = PiecesRouteurs()
        p.choisir("Cuisine", appareil: "E0000000000000FF", domicile: NomsDemo.maison.domicile ?? "")
        return p
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
            m.poserIsolement(piece(sc, "Terrasse"), depuisEtage: true)
        },
```

par :

```swift
            m.poserIsolement(piece(sc, "Terrasse"), depuisEtage: true)
        },
        Cas(nom: "21-2d-appareil-en-route", poser: { m, sc in
            m.poserTransition(0.5)
            let sansPiece = sc.pieces.firstIndex { $0.nom == .sansPiece } ?? 0
            m.poserZoom(echelle: 1, vers: m.centrePiece(sansPiece))
        }, deplacer: appareilDansLaCuisine),
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
            m.installerMaintenant(e)
            m.poserTaille(taille)
```

par :

```swift
            m.installerMaintenant(e)
            m.poserTaille(taille)
            if let choix = c.deplacer {
                m.installerMaintenant(EntreeScene(surveillance: s, reseau: r, places: m.places, choix: choix))
            }
```

Dans `README.fr.md`, remplacer :

```markdown
Avec `-captures <dossier>`, l'app écrit vingt images PNG de la vue par
pièces (2D, envol, 3D, zooms, pièces isolées, survol, la fiche du chef, la
légende repliée ; puis les étages : la grille 2 × 2 dans une fenêtre carrée,
la même fenêtre en rangée, la 3D avec le jardin dans la maison, un étage isolé
en 2D et en 3D, une pièce isolée depuis son étage), puis quitte, sans fenêtre.
```

par :

```markdown
Avec `-captures <dossier>`, l'app écrit vingt et une images PNG de la vue
par pièces (2D, envol, 3D, zooms, pièces isolées, survol, la fiche du chef, la
légende repliée ; puis les étages : la grille 2 × 2 dans une fenêtre carrée,
la même fenêtre en rangée, la 3D avec le jardin dans la maison, un étage isolé
en 2D et en 3D, une pièce isolée depuis son étage ; enfin un appareil à
mi-chemin de son glissement vers la cuisine), puis quitte, sans fenêtre.
```

Dans `README.fr.md`, remplacer :

```markdown
  rotation lente qu'on peut couper. La bascule est un envol de 2,6 s ; les
  plateaux glissent vers leur place quand la fenêtre change de taille, quand la
  légende s'ouvre ou se replie, quand le réglage change, et après un changement
  de niveau.
- **Gestes.** Molette ou pincement : zoom, vers le curseur en 2D. Glisser le
```

par :

```markdown
  rotation lente qu'on peut couper, qui continue autour d'une pièce ou d'un
  étage isolés et s'arrête pendant un geste. La bascule est un envol de 2,6 s ;
  les plateaux glissent vers leur place quand la fenêtre change de taille, quand
  la légende s'ouvre ou se replie, quand le réglage change, et après un
  changement de niveau.
- **Glissements.** Une nouvelle disposition (un relevé, un appareil placé dans
  une pièce, un choix de niveau) glisse en 0,9 s : les pièces, les appareils et
  les plateaux vont de leur place affichée à la nouvelle, un appareil en ligne
  droite d'une pièce à l'autre, d'un étage à l'autre s'il le faut ; ce qui
  apparaît ou disparaît le fait en fondu de 0,3 s, et les liens suivent. La vue
  suit ce qu'elle regarde. Un badge qui change (☾, ⚠︎, 👑, pile faible) ne
  fait plus bouger l'étage : chaque carte réserve la place des badges possibles
  de ses noms. Un routeur de bordure non identifié, dont tous les candidats
  sont dans la même pièce, va dans cette pièce.
- **Gestes.** Molette ou pincement : zoom, vers le curseur en 2D ; au-dessus
  de la fiche, de la légende ou du haut de la fenêtre, la molette leur revient.
  Glisser le
```

Dans `README.fr.md`, remplacer :

```markdown
  l'isoler de même. Clic à côté ou Échap : remonter d'un cran, d'une pièce à
  son étage si on l'a ouverte depuis lui, sinon à la maison ; le fil
  « Maison › Étage › Pièce » y mène aussi. En 3D, ⌥ + glisser déplace la vue
```

par :

```markdown
  l'isoler de même. Échap ferme d'abord la fiche ouverte ; sinon, comme le clic
  à côté, il remonte d'un cran, d'une pièce à son étage si on l'a ouverte
  depuis lui, sinon à la maison, et ramène une vue zoomée à la vue d'ensemble ;
  là, il n'est pas pris et suit son chemin. Le fil « Maison › Étage › Pièce »
  mène aussi à chaque cran. En 3D, ⌥ + glisser déplace la vue
```

Dans `README.fr.md`, remplacer :

```markdown
  immédiats, la rotation lente est coupée, la fiche, la légende et les
```

par :

```markdown
  immédiats, comme les glissements d'une disposition à l'autre, la rotation
  lente est coupée, la fiche, la légende et les
```

Dans `README.fr.md`, remplacer :

```markdown
  l'endroit où elle est posée). Rien de tout cela en démo.
```

par :

```markdown
  l'endroit où elle est posée) ; son échelle, en dizaines de dBm, a toujours
  ses graduations, même pour un seul relevé, et le survol donne la valeur et
  l'heure du relevé le plus proche. Rien de tout cela en démo.
```

Dans `README.md`, remplacer :

```markdown
With `-captures <folder>`, the app writes twenty PNG images of the room view
(2D, flight, 3D, zooms, isolated rooms, hover, the leader's card, the folded
legend; then the floors: the 2 × 2 grid in a square window, the same window
in a row, 3D with the garden inside the house, a floor isolated in 2D and in
3D, a room isolated from its floor), then quits, with no window. Its renderer
```

par :

```markdown
With `-captures <folder>`, the app writes twenty-one PNG images of the room
view (2D, flight, 3D, zooms, isolated rooms, hover, the leader's card, the
folded legend; then the floors: the 2 × 2 grid in a square window, the same
window in a row, 3D with the garden inside the house, a floor isolated in 2D
and in 3D, a room isolated from its floor; last, a device halfway through its
slide to the kitchen), then quits, with no window. Its renderer
```

Dans `README.md`, remplacer :

```markdown
  it, with a slow rotation you can turn off. Switching is a 2.6 s flight; the
  platforms slide to their place when the window is resized, when the legend
  opens or folds, when the setting changes, and after a level change.
- **Gestures.** Scroll wheel or pinch: zoom, towards the pointer in 2D. Drag
```

par :

```markdown
  it, with a slow rotation you can turn off, which goes on around an isolated
  room or floor and stops during a gesture. Switching is a 2.6 s flight; the
  platforms slide to their place when the window is resized, when the legend
  opens or folds, when the setting changes, and after a level change.
- **Slides.** A new layout (a tour, a device placed in a room, a level
  choice) slides in 0.9 s: rooms, devices and platforms go from their shown
  place to the new one, a device in a straight line from room to room, from
  floor to floor if need be; what appears or disappears fades in 0.3 s, and
  links follow. The view follows what it looks at. A changing badge (☾, ⚠︎,
  👑, low battery) no longer moves the floor: each card keeps room for the
  possible badges of its names. An unidentified border router whose candidates
  are all in the same room goes to that room.
- **Gestures.** Scroll wheel or pinch: zoom, towards the pointer in 2D; over
  the card, the legend or the top of the window, the wheel goes to them. Drag
```

Dans `README.md`, remplacer :

```markdown
  isolate it the same way. Click outside or Esc: go up one step, from a room
  to its floor if you opened it from there, otherwise to the house; the
  "Home › Floor › Room" path leads there too. In 3D, ⌥ + drag pans the view in
```

par :

```markdown
  isolate it the same way. Esc first closes the open card; otherwise, like a
  click outside, it goes up one step, from a room to its floor if you opened
  it from there, otherwise to the house, and brings a zoomed view back to the
  overview; there, it is not taken and goes its way. The "Home › Floor ›
  Room" path also leads to each step. In 3D, ⌥ + drag pans the view in
```

Dans `README.md`, remplacer :

```markdown
  return become a fade, other camera flights are immediate, the slow rotation
```

par :

```markdown
  return become a fade, other camera flights are immediate, as are the slides
  from one layout to the next, the slow rotation
```

Dans `README.md`, remplacer :

```markdown
  depends first on where the probe sits). None of this in demo mode.
```

par :

```markdown
  depends first on where the probe sits); its scale, in tens of dBm, always
  has its ticks, even for a single reading, and hovering gives the value and
  time of the nearest reading. None of this in demo mode.
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests`
Expected: `Test run with 39 tests in 1 suite passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/tester.sh`
Expected: `Test run with 396 tests in 41 suites passed` (cœur) et `Test run with 364 tests in 32 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 1 test de plus pour l'app.

- [ ] **Step 6 : la suite en anglais.**

```bash
xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-polD/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-polD/maillage-tests-en.log"
```

Expected: `Test run with 396 tests in 41 suites passed` et `Test run with 364 tests in 32 suites passed`, `** TEST SUCCEEDED **` : les effectifs du Step 5.

- [ ] **Step 7 : les tests Python de la sonde, et les temps.** Ce plan ne touche pas à la sonde.

```bash
python3 -m unittest discover -s sonde/test 2>&1 | tail -3
/usr/bin/python3 -m unittest discover -s sonde/test 2>&1 | tail -3
```

Expected : `Ran 141 tests` puis `OK`, deux fois.

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polD" TMPDIR="$HOME/Library/Caches/maillage-polD/" outils/mesurer.sh`
Expected: `mesure : disposition de la grande maison en 0.209822458 s, 3000 coups` ; `mesure : placement de 150 noms en 0.3109875 ms, 150 poses` ; `mesure : placement de 150 noms tres serres en 2.86540835 ms, 30 poses` (ces temps-ci au rejeu, qui varient d'une machine à l'autre ; les coups et les poses, non), puis `Test run with 22 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 8 : les vingt et une images de démo.** Les vingt d'avant sont identiques à celles de la tâche 7, octet pour octet ; la vingt et unième s'ajoute. Les images se rendent toujours juste après la suite du step précédent, avec l'app qu'elle vient de compiler.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "maillage-polD/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
for f in $(ls "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t7"); do cmp -s "$D/$f" "$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polD-t7/$f" && echo "$f identique" || echo "$f differe"; done | sort | awk '{print $2}' | uniq -c
```

Expected : 21 ; « l'app a quitté » ; « 20 identique » (la comparaison porte sur les vingt images de la tâche 7). Regarder (outil Read) `21-2d-appareil-en-route.png` : « Non identifié · 041F » entre « Sans pièce » et la cuisine.

- [ ] **Step 9 : commit.**

```bash
git add MaillageThread/Vues/Pieces/CapturesPieces.swift MaillageThreadTests/FenetrePiecesTests.swift README.fr.md README.md
git commit -m "Rendre une image de demo d'un appareil a mi-chemin de son glissement vers la cuisine, et decrire dans le README les glissements, les badges, la molette, Echap, la rotation lente pendant un isolement et l'echelle du signal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

**Mutants essayés sur la copie validée** (chacun appliqué seul, la tâche jouée par ses tests ; un mutant qui ne compilait pas a été rejoué sous une forme qui compile, sauf pour le découpage, où la compilation est l'attente) :

3 mutants de l'image du glissement : l'état de capture qui ne pose pas la transition, ou la pose au bout, tués par `imageDuGlissement` ; la boucle des captures qui n'installe pas la scène déplacée **survit** aux tests (le test bâtit lui-même la scène déplacée) : le Step 8 le voit, l'image 21 n'ayant alors plus d'appareil en route, et différant de celle du rejeu.

### Task 9: Vérification avec Djoko (par le contrôleur, pas par un sous-agent)

**Files:** aucun.

**Interfaces:**
- Consumes : tout le plan ; l'app compilée dans le `DD` du plan ; les images de `captures-polD` et celles de la fin de C (`captures-polC-finale`).
- Produces : la vérification de D avec Djoko (spec, section 6), en vrai, et ses décisions sur les précisions.

Ce qui ne se voit qu'en vrai : `ImageRenderer` ne rend ni l'horloge (les glissements, les fondus, la rotation), ni le survol, ni les événements de la molette et du clavier. Chaque action sur l'app de Djoko attend son accord.

- [ ] **Step 1 : les images.** Montrer à Djoko, à côté de celles de la fin de C :
  1. `captures-polD/07-2d-zoom-salon.png` avec `captures-polC-finale/07-2d-zoom-salon.png` : la carte du salon réserve la place des badges, et de la pastille du volet, dont la pile est connue : environ un cinquième plus large ; `01-2d.png` et `05-3d.png` : l'effet sur la maison entière ;
  2. `21-2d-appareil-en-route.png` : « Non identifié · 041F » à mi-chemin de « Sans pièce » vers la cuisine, les deux cartes qui échangent leur place se croisant ;
  3. le salon de `07` : l'Apple TV 4K, le chef, reste en tête, par son nom (précision 8, décision du 05/10).
- [ ] **Step 2 : dans l'app.** Recompiler (`outils/tester.sh`, avec le `DD` et le `TMPDIR` du plan), puis, avec son accord, quitter l'app qui tourne et lancer celle du `DD` en mode direct : `open "$HOME/Library/Developer/Xcode/DerivedData/maillage-polD/Build/Products/Debug/Maillage Thread.app"`. Avec Djoko, sur sa maison (spec, section 6) :
  1. **« Placer dans une pièce… »** sur un appareil : il glisse jusqu'à sa nouvelle pièce, en 0,9 s, en 2D puis en 3D, d'un étage à l'autre en ligne droite ; ses liens le suivent ; les pièces que le recalcul déplace glissent aussi ; ce qui apparaît ou disparaît se fond en 0,3 s ; une pièce ou un étage isolés, la vue les suit. Un second choix pendant le glissement repart de la pose affichée, sans saut.
  2. **Une pièce glissée à la main** : elle n'est pas animée au relâchement, et rien d'autre ne bouge ; à la disposition suivante, les autres glissent si elles bougent (précision 6, décision du 05/10).
  3. **Un badge qui change** (une pile qui faiblit, un appareil qui disparaît, un autre chef) ne fait plus bouger l'étage ; seule une pile qui devient connue élargit sa carte, une fois ; les cartes, plus larges, lui conviennent-elles ?
  4. **La molette** au-dessus de la fiche (ses courbes défilent) et de la légende : la vue ne zoome pas ; au-dessus de la scène, si. **Échap** : la fiche se ferme d'abord, puis la vue remonte ; à la vue d'ensemble, il suit son chemin (en plein écran, l'effet de macOS).
  5. **La rotation lente**, en 3D, autour d'une pièce isolée, puis d'un étage isolé : elle reprend à la fin du vol, sans saut ; elle s'arrête pendant un glisser, la molette, un pincement, puis reprend ; décochée, ou avec « Réduire les animations », elle ne tourne pas.
  6. **Les deux HomePod de la paire** dans leur pièce, même quand la sonde ne les identifie pas (« A ou B · RLOC16 ») ; leur fiche ne propose pas « Placer dans une pièce… ».
  7. **Le signal vu par la sonde**, dans la fiche d'un routeur : l'échelle avec un seul relevé (juste après la première tournée), graduée sur les dizaines ; puis la valeur au survol, le trait, le point et l'étiquette (« −67 dBm · 16:13 », avec le jour en 7 j et 30 j), à gauche du trait près du bord droit, rien dans un trou, rien quand le pointeur sort (précision 14 : le format de l'heure).
  8. **Les restes de C** : « Monter » ou « Descendre » avec un étage momentanément absent, qui revient à son rang ; la grille rechoisie quand une nouvelle disposition change les rayons ; le menu du clic droit qui revient à la fin de l'envol, le pointeur immobile.
  9. **« Réduire les animations »** : les glissements et les fondus sont immédiats.
  10. **Le reste de la vue**, inchangé, le moteur découpé en fichiers (tâche 7) : grille et rangée, isolement, ⌥ + glisser, l'envol, le menu.
  11. **Retour.** Des comptes seulement, jamais un nom.
- [ ] **Step 3 : rendre l'app.** Quitter l'app du `DD` et relancer l'app habituelle de Djoko, s'il le souhaite. Puis reporter dans la spec de D, comme aux polissages A, B et C, les précisions que Djoko valide, et la note de vérification.

---

## Couverture des exigences

| Exigence (spec de D, et brief du plan) | Tâche | Preuve |
|---|---|---|
| L'isolement sorti du moteur : l'état, les transitions, le recalage, la règle des clics sur un disque | 1 | `IsolementCoeurTests` ; `provenance`, `cliquerUnEtage`, `survol`, `pieceIsoleeQuiDisparait` |
| La politique de la grille sortie du moteur : la demande, l'attente, l'hystérésis, la taille nulle, les durées | 1 | `PolitiqueGrilleTests` ; `redimensionnement`, `grilleQuiAttend`, `premiereVraieTaille` |
| Le comportement ne change pas ; les règles écrites deux fois n'ont plus qu'un endroit | 1 | la suite, inchangée ; images identiques ; `clicEtage` |
| Les poses à 0, à la moitié, à la fin ; la courbe ; les fondus ; l'interruption ; « Réduire » | 2, 3 | `glissement`, `fondus`, `interruption`, `ceQuiChange` ; `nouvelleDispositionQuiGlisse`, `reduire`, `interruption` (app) |
| Un appareil en ligne droite, d'un étage à l'autre, en 2D et en 3D ; les liens suivent | 2, 3 | `dUnPlateauALAutre`, `sceneProjeteeEnRoute` ; `nouvelleDispositionQuiGlisse` ; vérification 1 |
| Ce qui apparaît ou disparaît, en fondu, à sa place | 2 | `fondus`, `ceQuiSEfface` |
| Une seule horloge, aucune image au repos ; la caméra suit ce qu'elle regarde | 3 | `parLHorloge` |
| La pièce glissée par Djoko n'est pas animée | 3 | `pieceGlissee` ; vérification 2 |
| La largeur d'une carte et la clé de disposition ne dépendent pas des badges | 4 | `badgesReserves`, `cleSansLesBadges`, `reserveDesBadges`, `unBadgeNeBougeRien` ; vérification 3 |
| La pastille réservée aux piles connues ; une pile qui devient connue change la clé (décision du 05/10) | 4 | `cleSansLesBadges`, `reserveDesBadges`, `unBadgeNeBougeRien` |
| Le moteur réparti en fichiers, le code déplacé tel quel, les tests et les images inchangés (décision du 05/10) | 7 | Step 5 de la tâche 7 ; la suite ; images identiques |
| Un routeur aux candidats d'une même pièce : même pièce, pièces différentes, un sans pièce, le choix avant le nom | 4 | `candidats` ; `routeursAuxCandidats` ; vérification 6 |
| La molette au-dessus de la fiche et de la légende ; Échap dans les trois cas | 5 | `moletteAuDessusDesElements`, `echapDansLesTroisCas`, `evenementsDeLaFenetre` ; vérification 4 |
| La rotation lente pendant un isolement : autour de la cible, arrêtée par un geste, puis reprise | 5 | `rotationLente`, `rotationPendantLIsolement`, `etageIsole` ; vérification 5 |
| Un étage absent garde son rang | 5 | `ordreFondu`, `unEtageAbsentGardeSonRang` ; vérification 8 |
| La grille rechoisie quand les rayons changent | 3 | `grilleRechoisieQuandLesRayonsChangent` ; vérification 8 |
| Le menu revient à la fin de l'envol ou du fondu | 5 | `menuALaFinDeLEnvol` ; vérification 8 |
| Le signal : le domaine, le relevé le plus proche et le seuil de 2 %, un trou, l'étiquette en 24 h et en 7 j | 6 | `domaine`, `plusProche`, `etiquette`, `echelleDuSignal` ; vérification 7 |
| Les captures : toutes changent une fois ; un appareil à mi-glissement | 4, 8 | `captures-polD` ; `imagesDeDemo`, `imageDuGlissement` |
| Des tests qui tuent les mutants plausibles | 1 à 8 | les mutants de chaque tâche |
| Vérification avec Djoko (spec, section 6) | 9 | Step 2 |

