# Maillage Thread, plan 3b : journal des parents et historique des qualités : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** tenir le journal des changements du maillage de la sonde (changements de parent, enfant sans parent, routeur Thread qui apparaît ou disparaît) et garder à chaque tournée la qualité de chaque lien et le signal que la sonde reçoit de chaque routeur, montrés en courbes dans la fiche d'un nœud. Avec trois suites de la vague de corrections du plan 3a : lire tout de suite les réponses « occupée » de la sonde, mettre la fiche à l'heure de la fenêtre du graphe, et finir l'anonymiseur des captures de la sonde.

**Architecture :**
- **La tournée** (`MaillageCoeur/Maillage/Tournee.swift`) demande en plus `voisins` à la sonde (une requête locale, par l'USB comme par le réseau) ; le `Maillage` porte le signal de chaque routeur entendu et de son parent (`SignalSonde`).
- **La liaison** (`SondeUSB`) lit les réponses « occupée » d'`etat`, de `voisins` et de `routeurs` sans attendre l'échéance de la commande (n° 36 du tri de la vague).
- **Le cœur** (Swift pur, testé) :
  - `SuiviMaillage` compare deux maillages de suite et en tire les `Evenement` du journal ; `Regroupement` réunit les changements de parent d'un même nœud dans l'heure ;
  - `ReleveMaillage` est la ligne d'historique d'une tournée ; `HistoriqueFichiers` l'écrit dans `maillage-AAAA-MM.jsonl` (`FichiersMensuels`, extrait de `JournalFichiers`, que le journal utilise aussi) ;
  - `CourbesNoeud` tire d'une liste de relevés les courbes d'un nœud sur 24 h, 7 j ou 30 j.
- **L'app** :
  - `Surveillance.recevoir` passe chaque maillage au journal et à l'historique (en mémoire, 30 jours ; sur disque en mode direct) ; oublier la sonde remet le suivi du maillage à zéro ;
  - la fiche du graphe reçoit l'heure de la `TimelineView` de sa fenêtre : « vu il y a … » et les courbes la suivent, chaque minute ;
  - la fiche montre les courbes avec Swift Charts (`CourbesFiche`).
- **Les outils** : `outils/anonymiser-sonde.py` connaît les messages de la sonde 1.0.3 et la forme de chaque champ, contrôle la longueur des TLV et le contenu de la Network Data, et rend telle quelle une capture déjà anonymisée.

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI, Swift Charts, Observation, `os.Logger`, Swift Testing, XcodeGen ; Python 3 (bibliothèque standard, `unittest`) pour l'anonymiseur.

**Spec :** `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, section 6 « Journal et historique », à lire avec les sections 3 (protocole), 3 bis (liaison par le réseau), 4 (tournée), 5 (affichage) et 7 (tests, anonymiseur). La tâche 1 y écrit l'ajout validé par Djoko le 30/09 (signal vu par la sonde). Ce plan fait suite au plan 3a, `docs/superpowers/plans/2026-09-29-maillage-thread-plan3a-sonde.md`, et à sa vague de corrections (tri : `.superpowers/archives/plan3a-sonde-sdd/triage-mineurs.md`, hors du dépôt ; n° 12, 36 et Q3 pour ce plan). Les plans 4a et 4b viennent après lui et remplaceront `FenetreGraphe` : ce plan écrit sur `FenetreGraphe` et `FicheNoeud` tels qu'ils sont.

**Quand l'exécuter.** Sur `main`, à partir de `210b387` (fin de la vague de corrections du plan 3a). Depuis, `main` a reçu `48b8a88` (éclair de la sonde suspendue à 5 s), `709e7b8` et `1bc033c` (menu), `3c46889` (plan 4a) : ils ne touchent aucun fichier de code de ce plan, et chaque bloc de ce plan s'applique aussi sur `3c46889` (vérifié). **Exécuté à partir de `d9f761b`** (30/09 au soir : plan 4a fusionné, Réglages en onglets). Contrôle avant exécution : les 150 blocs du plan, appliqués dans l'ordre sur `d9f761b`, retrouvent chacun leur texte exact, et donnent fichier par fichier le même résultat que la fusion git du rejeu (seuls le catalogue et `interface.json` diffèrent, régénérés par leurs outils). Les deux blocs du tableau des README (tâche 13) ont été réduits à la ligne qui change : le 4a a réécrit la ligne `MaillageThread/Noms/` voisine.

**Validé par Djoko le 30/09** : les 13 points du rapport de rejeu, avec les recommandations (8 Mo par mois, enfants identifiés seulement, « n'a plus de parent » après deux absences sûres, 360 pt sous le graphe, regroupement en 1 h, réponses « occupée », oubli de la sonde, fiche à l'heure vérifiée avec lui, anonymiseur, `etat` deux fois par tournée, capture 1.0.3 à la tâche 13 s'il est là). **Les numéros de ligne cités sont indicatifs : l'exécutant se repère aux noms (types, fonctions, commentaires) et aux textes cités.** Si un texte à remplacer n'est plus exactement le même, l'exécutant applique le même changement au texte du moment et le dit dans son rapport.

**Code validé avant exécution.** Le 30/09, tout le code de ce plan a été écrit, compilé et testé dans un worktree de `210b387`, puis rejoué tâche par tâche sur une copie neuve de `210b387` (branche `plan3b-rejeu`, un commit par tâche avec les listes `git add` ci-dessous ; l'arbre était propre après chaque commit) : l'erreur attendue avant le code, les tests après, la suite entière, en français et en anglais, et les tests Python sous Python 3.11 et 3.9. L'arbre final est identique à la copie validée. Sur `210b387`, le cœur compte 229 tests en 21 suites, l'app 216 en 24 suites, et les tests Python 100 ; après ce plan, 253 en 25, 231 en 27, et 121. Chaque tâche donne ses effectifs par suite, et l'écart des totaux.

Exécuter une tâche, c'est transcrire les fichiers et les blocs donnés, compiler et tester. Si un fichier doit s'écarter du texte donné, l'exécutant le dit dans son rapport, avec la raison.

**Blocs de modification.** Un fichier existant est modifié soit en entier (« fichier entier »), soit par blocs « remplacer … par … ». Chaque texte à remplacer apparaît une seule fois dans le fichier au moment où on l'applique. Les blocs s'appliquent dans l'ordre, du haut vers le bas, au texte exact, espaces compris (outil Edit). Un fichier créé l'est tel quel.

**Écarts à la spec (assumés) :**
1. **Enfants identifiés seulement.** Le journal ne suit, et l'historique ne garde, que les enfants dont l'ExtMac est connue : le RLOC16 d'un enfant change avec son parent, il n'identifie personne d'une tournée à l'autre. Un enfant qui ne répond jamais à la demande d'identité (il y en a trois dans la capture) n'a ni journal ni courbe.
2. **« X n'a plus de parent »** : l'enfant est absent de deux tournées où son absence est sûre. Elle l'est si son dernier parent a répondu (sa table des enfants est fraîche), s'il a quitté la liste des routeurs, ou si l'enfant venait d'un balayage (un routeur muet garde ses enfants balayés jusqu'au balayage suivant). Sous un routeur qui s'est tu sans être balayé, on ne sait pas : rien. Jamais pour la sonde (détachée, elle ne rend pas de maillage), ni pour un enfant devenu routeur. Revu ensuite sous un autre parent : « X a changé de parent : A → B », A étant le dernier connu.
3. **Point de départ.** Le premier maillage d'un lancement, le premier d'une autre partition (les identifiants de routeur y sont redistribués), et le premier après l'oubli de la sonde, ne donnent aucun événement. Les événements sont datés du début de leur tournée. Un routeur « apparaît » ou « disparaît » quand son identifiant entre dans la liste des routeurs ou en sort.
4. **Regroupement :** les changements de parent d'un même nœud dans une fenêtre de 1 h, comptée depuis le premier, forment une ligne « X a changé n fois de parent en 1 h » (dans le journal et le menu ; une notification, si « Autres changements » est cochée, reste une par événement, comme aujourd'hui).
5. **Taille des fichiers :** environ 0,9 Ko par tournée pour 7 routeurs et 20 enfants, soit 8 Mo par mois, et non 5 : chaque enfant est nommé par son ExtMac à chaque ligne, pour que chaque ligne se lise seule. La tâche 13 corrige l'estimation dans la spec.
6. **Mémoire :** l'app garde en mémoire les 30 derniers jours de l'historique (les courbes n'en montrent pas plus) ; les fichiers gardent 90 jours et sont purgés au lancement, comme le journal. L'oubli de la sonde ne vide pas l'historique : il parle du réseau, pas de la sonde.
7. **Courbes :** la moyenne des relevés par 30 min sur 7 j et par 2 h sur 30 j (chaque relevé sur 24 h) ; un trou de plus de 20 min, ou de trois pas, coupe la courbe. La qualité d'un enfant sous un routeur muet est inconnue : pas de point, seuls ses changements de parent se voient. Elles sont dans la fiche, sous les colonnes, pour tout nœud dès que l'historique a un relevé ; le graphe garde alors 360 pt en bas quand une fiche est ouverte (190 sans historique), pour ne pas bouger d'un nœud à l'autre. Elles finissent à l'heure de la fiche (écart 11).
8. **Signal :** celui des seuls routeurs de la liste ; un RSSI positif ou nul (127 : invalide pour OpenThread) est écarté. Si `voisins` répond `occupee`, la tournée continue sans, tout de suite (tâche 3) ; une liste trop longue pour le réseau (plus de 1100 octets : la sonde répond `erreur`) attend l'échéance de la commande (6 s par le réseau).
9. **Démo :** ni historique ni courbes ; le journal du maillage y reste vide (un seul maillage, point de départ).
10. **Réponses « occupée »** (n° 36) : `etat`, `voisins` et `routeurs` refusés par la sonde (verrou d'OpenThread) échouent tout de suite en `occupee` : « la sonde est occupée et n'a pas répondu à « etat » ». Pour `routeurs`, l'erreur change : le plan 3a le rendait en `sansReponse`, sans attendre non plus. Sans `etat`, la tournée s'arrête sur ce message au lieu de « la sonde ne répond pas » au bout de 3 s (6 s par le réseau).
11. **Fiche à l'heure :** la fiche reçoit l'heure de la `TimelineView` de la fenêtre du graphe (`contexte.date`), au lieu de lire `surveillance.maintenant` : sinon SwiftUI garde son rendu d'une minute à l'autre, ses entrées n'ayant pas changé. En démo, la fin de la panne rejouée, comme avant (`Surveillance.maintenant(a:)`).
12. **Anonymiseur :** le nom de la sonde devient `SONDE-01`, `SONDE-02`… ; le nom d'hôte SRP prend la valeur factice de l'ExtMac (Matter l'en tire), et une ligne dont le nom d'hôte n'est pas de l'hexa est refusée ; l'empreinte de la clé est remplacée (`C1E0…`) et la clé toujours masquée ; un texte libre (rôle, mode, version, erreur…) n'est gardé que s'il est sûr (64 caractères au plus, ni 8 hexa de suite, ni adresse) ; un texte des TLV 25 à 28 est refusé s'il porte 12 hexa de suite, une MAC ou une adresse ; un Server de la Network Data n'est accepté qu'en 2, 9 (routeur de dorsale) ou 20 octets (adresse et port). Une capture déjà anonymisée ressort telle quelle : ses valeurs factices sont reconnues à leur forme. Une Network Data de 255 octets ou plus (TLV à longueur étendue) reste refusée.
13. **`etat` deux fois par tournée** (n° 12 du tri) : laissé tel quel, comme le tri le recommande (environ 300 octets toutes les 5 min). `SondeMaillage` le demande avant la tournée, qui le redemande à sa première étape ; un refus (`occupee`) de l'une ou l'autre demande arrête la tournée sur le message de l'écart 10.

## Global Constraints

- **Plateformes :** app en macOS 26.0 minimum, développée avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus ; Python 3.9 ou plus pour les outils (bibliothèque standard seulement).
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`. Notamment, `Text + Text` est déprécié dans le SDK de macOS 26, donc refusé.
- **Code :** identifiants et commentaires en français **sans accents** ; textes affichés avec accents ; tests en Swift Testing, et `unittest` pour Python. Les nouveaux fichiers vont dans des dossiers existants, que `project.yml` prend déjà : il ne change pas. Swift Charts (`import Charts`) fait partie du SDK : aucune dépendance à ajouter.
- **Textes de l'app :** catalogue `MaillageThread/Ressources/Localizable.xcstrings`, français source et anglais obligatoire. Une tâche qui ajoute des textes synchronise elle-même le catalogue, dans cet ordre :
  1. compiler ;
  2. `outils/synchroniser-textes.sh` ;
  3. ajouter les traductions à `outils/traductions/interface.json` (la tâche donne le script) ;
  4. `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`.

  Le test `CataloguesTests` refuse une clé absente comme une clé morte. Les libellés des graphiques (`.value("Heure", …)`) sont des clés du catalogue, comme les `Text`.
- **Tests indépendants de la langue :** une attente sur un texte affiché reprend la même clé interpolée que le code (`String(localized: "\("Prise bureau") n'a plus de parent")`), jamais une chaîne française figée. Ils passent en anglais : `xcodebuild … -testLanguage en -testRegion US test` (vérifié au rejeu, tâches 10 et 13).
- **Commandes,** depuis la racine du dépôt, toujours avec un dossier de produits (`DD`) et un dossier temporaire (`TMPDIR`) propres à ce plan : ni `maillage` (celui de l'app de Djoko), ni `maillage-plan3a-exec`. Une autre compilation (l'app de Djoko, une autre session) ne partage ni ses produits ni son journal. Le shell d'un agent ne garde pas ses variables d'une commande à l'autre : chaque commande les porte. Une fois, avant la tâche 1 :

  ```bash
  mkdir -p "$HOME/Library/Caches/maillage-plan3b"
  ```

  Puis, par exemple :

  ```bash
  DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/TourneeTests
  ```

  `outils/tester.sh [cibles…]` génère le projet, compile et lance les tests ; les produits vont dans `DD`, le journal complet dans `$TMPDIR/maillage-tests.log`. `outils/synchroniser-textes.sh` lit les produits dans le même `DD`. La première compilation dans ce `DD` neuf prend quelques minutes. Les tests Python : `python3 -m unittest discover -s sonde/test`, puis `/usr/bin/python3 -m unittest discover -s sonde/test` (Python 3.9 de Xcode : les outils doivent y tourner).
- **La sonde, les ports série et l'app :** de la tâche 1 à la tâche 12, **aucun agent n'ouvre un port série ni ne flashe**, et l'app n'est jamais lancée en mode direct. Le firmware ne change pas : la 1.0.3, flashée le 30/09, a `voisins` et les réponses « occupée ». La tâche 13 se fait avec Djoko, par le contrôleur.
- **Règles de la sonde, reprises du plan 3a :**
  - l'app n'ouvre jamais un port qu'on ne lui a pas désigné ;
  - les tests n'utilisent jamais le vrai trousseau, ni de trafic hors de la boucle locale ;
  - l'historique, comme les identités des routeurs, n'est jamais écrit en mode démo, ni sous les tests hors d'un dossier temporaire. Dans l'app, seul `Surveillance` en mode direct avec un dossier l'écrit : l'instance de l'app, sous les tests, ne reçoit aucun maillage (sonde inactive, `demarrer` non appelé) ; les tests passent un dossier temporaire, ou aucun.
- **Données personnelles** (le dépôt est public sur GitHub, `Djoko-cli/maillage-thread`) :
  - données de test inventées (ExtMac en `E0…` ou `DEADBEEF…`, partitions `0000000A`, préfixes de documentation `2001:db8`), ou tirées de la capture anonymisée `docs/releves/2026-09-29/capture-sonde.jsonl` et du relevé déjà publié du 28/09 ;
  - jamais `docs/releves/2026-09-29/capture-sonde-essai.jsonl` (la capture brute, jamais commitée), ni aucune autre capture brute ;
  - aucune ExtMac, aucun préfixe, aucune MAC, aucun nom d'hôte ni aucun code d'appairage du vrai réseau dans un fichier commité, ni dans un message ou un rapport ; le fichier `maillage-AAAA-MM.jsonl` de Djoko contient ses ExtMac : il n'est jamais copié dans le dépôt.
- **Signature :** l'app reste ad hoc (`Signature.xcconfig`). **Ne jamais créer `Local.xcconfig`.**
- **Commits :**
  - un par tâche, message en français sans accents, terminé par la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - `git add` avec la liste de fichiers de la tâche, **jamais `git add -A` ni `git add .`** ; après le commit, `git status` ne montre rien ;
  - jamais de push.
- **Interdits pour les agents :** `sudo` ; ouvrir un port série ou flasher ; lancer l'app en mode direct ; lancer le passeur ; réveiller l'écran.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md` | l'ajout du 30/09 ; puis réponses « occupée », fiche à l'heure, taille mesurée, précisions, anonymiseur, vérification | 1, 13 |
| `MaillageCoeur/Maillage/Maillage.swift` | `SignalSonde`, `Maillage.signaux`, `parentSonde`, `enfantsIdentifies`, `ConstructionMaillage.signal` | 2, 5 |
| `MaillageCoeur/Maillage/Tournee.swift` | `InterlocuteurSonde.voisins()`, `voisins` dans l'étape « État de la sonde » | 2 |
| `MaillageCoeur/Maillage/ProtocoleSonde.swift` | `MessageSonde.refusee` : `etat` ou `voisins` en erreur | 3 |
| `MaillageThread/Sonde/SondeUSB.swift` | `voisins()` ; réponses « occupée » (`Erreur.occupee`) | 2, 3 |
| `MaillageCoeurTests/TourneeTests.swift`, `MaillageCoeurTests/ProtocoleSondeTests.swift`, `MaillageThreadTests/SondeTests.swift` | sonde rejouée et canal rejoué qui répondent à `voisins` ; réponses « occupée » | 2, 3 |
| `MaillageThread/Surveillance/Surveillance.swift` | `maintenant(a:)` ; journal du maillage, historique, noms, oubli ; clés, noms et courbes de l'historique | 4, 8, 10 |
| `MaillageThread/Vues/Graphe/FicheNoeud.swift` | `instant` ; nom des nœuds partagé ; courbes sous les colonnes | 4, 8, 10 |
| `MaillageThread/Vues/Graphe/FenetreGraphe.swift` | l'heure de la `TimelineView` passée à la fiche ; marge du bas du graphe | 4, 10 |
| `MaillageThreadTests/FicheHeureTests.swift` | la fiche suit l'heure qu'on lui donne | 4 |
| `MaillageCoeur/Journal/FichiersMensuels.swift`, `MaillageCoeur/Journal/JournalFichiers.swift` | fichiers JSON Lines mensuels, communs au journal et à l'historique | 5 |
| `MaillageCoeur/Maillage/HistoriqueMaillage.swift` | `ReleveMaillage` (une ligne par tournée), `HistoriqueFichiers` | 5 |
| `MaillageCoeur/Suivi/Evenement.swift`, `MaillageCoeur/Maillage/SuiviMaillage.swift` | quatre types d'événement ; `SujetsMaillage`, `SuiviMaillage` | 6 |
| `MaillageThread/Surveillance/TexteEvenement.swift`, `MaillageThread/Vues/Journal/FenetreJournal.swift` | textes ; famille « Maillage » ; lignes regroupées | 6, 7 |
| `MaillageCoeur/Suivi/Regroupement.swift` | `LigneJournal.parents` | 7 |
| `MaillageCoeur/Maillage/CourbesNoeud.swift` | `PeriodeCourbes`, `CourbesNoeud` | 9 |
| `MaillageThread/Vues/Graphe/CourbesFiche.swift` | Swift Charts | 10 |
| `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` | anglais des nouveaux textes | 3, 6, 7, 10 |
| `MaillageCoeurTests/HistoriqueTests.swift`, `SuiviMaillageTests.swift`, `RegroupementParentsTests.swift`, `CourbesNoeudTests.swift` | tests du cœur | 5, 6, 7, 9 |
| `MaillageThreadTests/JournalMaillageTests.swift`, `CourbesFicheTests.swift`, `TexteEvenementTests.swift`, `JournalVueTests.swift` | tests de l'app | 6, 7, 8, 10 |
| `outils/anonymiser-sonde.py`, `sonde/test/test_anonymiseur.py` | l'anonymiseur complet et ses tests | 11, 12 |
| `README.md`, `README.fr.md`, `sonde/README.md` | mode d'emploi | 13 |

---

### Task 1: Spec : l'ajout du 30/09 (signal vu par la sonde)

**Files:**
- Modify: `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md` (blocs ci-dessous : en-tête, section 4, section 6)

**Interfaces:**
- Consumes : la demande de Djoko du 30/09, validée : l'historique garde aussi, à chaque tournée, le signal (dBm) de chaque routeur que la sonde entend (`voisins`, dans le firmware depuis la 1.0.2) et celui de son parent (`etat.parent.rssi`) ; la fiche d'un routeur le montre en courbe sur 24 h, 7 j et 30 j, les changements de parent de la sonde marqués.
- Produces : la spec à jour, que les tâches suivantes suivent ; le lien vers ce plan.

- [ ] **Step 1 : écrire l'ajout dans la spec.**

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, remplacer :

```markdown
> **Plan 3a :** `docs/superpowers/plans/2026-09-29-maillage-thread-plan3a-sonde.md`.
```

par :

```markdown
> **Plan 3a :** `docs/superpowers/plans/2026-09-29-maillage-thread-plan3a-sonde.md`.
>
> **Plan 3b :** `docs/superpowers/plans/2026-09-30-maillage-thread-plan3b-journal.md`.
>
> **Ajout du 30/09 (demande de Djoko, validée) :** l'historique garde aussi le
> signal vu par la sonde, et la fiche d'un routeur le montre en courbe
> (section 6) ; la tournée demande donc `voisins` (section 4).
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, remplacer :

```markdown
   « Rapprochement »). Sans table (firmware 1.0.1, sonde occupée), la tournée
   continue sans elle.
```

par :

```markdown
   « Rapprochement »). Sans table (firmware 1.0.1, sonde occupée), la tournée
   continue sans elle. Enfin `voisins` (requête locale, ajout du 30/09) : le
   signal de chaque routeur que la sonde entend, pour l'historique
   (section 6) ; sans réponse, la tournée continue sans.
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, remplacer :

```markdown
- état de la sonde : `etat` puis `routeurs`, soit 2 ; l'étape s'arrête à 1
  si la sonde n'est pas attachée, ou suspendue ;
```

par :

```markdown
- état de la sonde : `etat`, `routeurs` puis `voisins`, soit 3 ; l'étape
  s'arrête à 1 si la sonde n'est pas attachée, ou suspendue ;
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, remplacer :

```markdown
**Historique.**
- Contenu : à chaque tournée, la qualité de chaque lien, entre routeurs et
  d'enfant à parent.
- Stockage : JSON Lines mensuel (`maillage-AAAA-MM.jsonl`) dans le dossier de
  l'app, gardé 90 jours comme le journal ; environ 5 Mo par mois.
- Affichage : courbes dans la fiche (Swift Charts) sur 24 h, 7 j et 30 j,
  avec les changements de parent marqués.
```

par :

```markdown
**Historique.**
- Contenu : à chaque tournée, la qualité de chaque lien, entre routeurs et
  d'enfant à parent ; et le signal (dBm) de chaque routeur que la sonde
  entend (commande `voisins`, firmware 1.0.2) et celui de son parent
  (`etat.parent.rssi`) (ajout validé par Djoko le 30/09).
- Stockage : JSON Lines mensuel (`maillage-AAAA-MM.jsonl`) dans le dossier de
  l'app, gardé 90 jours comme le journal ; environ 5 Mo par mois.
- Affichage : courbes dans la fiche (Swift Charts) sur 24 h, 7 j et 30 j,
  avec les changements de parent marqués. Dans la fiche d'un routeur, une
  courbe « Signal vu par la sonde » (24 h, 7 j, 30 j), où les changements de
  parent de la sonde sont marqués, car le signal dépend d'abord de l'endroit
  où la sonde est posée (ajout du 30/09).
```

- [ ] **Step 2 : la suite ne change pas.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement ; les effectifs d'avant le plan (au rejeu, sur `210b387` : 229 tests en 21 suites pour le cœur, 216 en 24 suites pour l'app).

- [ ] **Step 3 : commit.**

```bash
git add docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md
git commit -m "Ecrire dans la spec le signal vu par la sonde, ajout du 30/09

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Tournée : `voisins` et signal de la sonde

**Files:**
- Modify: `MaillageCoeur/Maillage/Maillage.swift`, `MaillageCoeur/Maillage/Tournee.swift`, `MaillageThread/Sonde/SondeUSB.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/TourneeTests.swift`, `MaillageThreadTests/SondeTests.swift` (blocs ci-dessous)

**Interfaces:**
- Consumes : `VoisinSonde` (`rloc16`, `ext`, `rssi`, `lqi`, `routeur`), `MessageSonde.voisins([VoisinSonde])` et `CommandeSonde.voisins`, déjà dans `ProtocoleSonde.swift` ; `EtatSonde.parent.rssi` ; `MemoireTournee`, `Tournee.periodeRecherche` (vague de mineurs, lot 1).
- Produces :
  - `public struct SignalSonde: Hashable, Sendable` (`routeur: Int`, `rssi: Int`, `init(routeur:rssi:)`) ;
  - `Maillage.signaux: [SignalSonde]` (routeurs de la liste seulement, par identifiant croissant) et `Maillage.parentSonde: Int?` (identifiant du parent de la sonde) ;
  - `ConstructionMaillage.signal(_ s: SignalSonde)` (un RSSI positif ou nul est ignoré ; le dernier donné pour un routeur l'emporte) ;
  - `InterlocuteurSonde.voisins() async throws -> [VoisinSonde]`, et `SondeUSB.voisins()` (`sansReponse("voisins")` sans liste dans le délai ; la tâche 3 y ajoute `occupee`) ;
  - l'étape `.etatSonde` compte 3 requêtes : `etat`, `routeurs`, `voisins` ;
  - pour les tests : `SondeRejouee.listeVoisins`, `SondeRejouee.capture(…, voisins:)`, `Registre.voisins` ; `CanalRejoue.voisins(_:)`, et `CanalRejoue.reseauMinimal` qui répond à `voisins` (liste vide), faute de quoi chaque tournée des tests de l'app attendrait 3 s.

- [ ] **Step 1 : écrire les tests.** La sonde rejouée répond à `voisins` ; deux tests de la tournée ; le total de l'étape « État de la sonde » passe à 3 ; `SondeUSB.voisins()` et son échéance.

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
        /// Demandes de la table des routeurs (`routeurs`).
        var tables = 0
        func noter(_ r: String) { requetes.append(r) }
        func noterTable() { tables += 1 }
    }

    /// La sonde ne rend pas sa table (firmware sans `routeurs`, verrou d'OpenThread refuse).
    struct SansTable: Error {}
```

par :

```swift
        /// Demandes de la table des routeurs (`routeurs`).
        var tables = 0
        /// Demandes des voisins (`voisins`).
        var voisins = 0
        func noter(_ r: String) { requetes.append(r) }
        func noterTable() { tables += 1 }
        func noterVoisins() { voisins += 1 }
    }

    /// La sonde ne rend pas sa table (firmware sans `routeurs`, verrou d'OpenThread refuse).
    struct SansTable: Error {}
    /// La sonde ne rend pas ses voisins (verrou d'OpenThread refuse, liste trop longue).
    struct SansVoisins: Error {}
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
    /// "<cible>|<tlv,...>" dont la reponse arrive plus tard ; les autres reviennent aussitot.
    var retards: [String: Duration] = [:]
    let registre = Registre()
```

par :

```swift
    /// "<cible>|<tlv,...>" dont la reponse arrive plus tard ; les autres reviennent aussitot.
    var retards: [String: Duration] = [:]
    /// Routeurs voisins que la sonde entend ; nil : elle ne rend pas la liste.
    var listeVoisins: [VoisinSonde]? = []
    let registre = Registre()
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
        guard let table else { throw SansTable() }
        return table
    }
```

par :

```swift
        guard let table else { throw SansTable() }
        return table
    }

    func voisins() async throws -> [VoisinSonde] {
        await registre.noterVoisins()
        guard let listeVoisins else { throw SansVoisins() }
        return listeVoisins
    }
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
    /// Etat de la capture apres le changement de parent : AC09, enfant de AC00 (muet) ; `ext` :
    /// l'ExtMac de la sonde (absente de la capture) ; `table` : celle des routeurs de la sonde,
    /// sans ExtMac par defaut (la capture vient d'une sonde en MED).
    static func capture(chef: Int = 24, ext: String? = nil, reponsesEnPlus: [String: String] = [:],
                        table: [RouteurSonde]? = SondeRejouee.table(), tropLongs: Set<String> = []) throws -> SondeRejouee {
```

par :

```swift
    /// Etat de la capture apres le changement de parent : AC09, enfant de AC00 (muet), qu'elle entend
    /// a -89 dBm ; `ext` : l'ExtMac de la sonde (absente de la capture) ; `table` : celle des routeurs
    /// de la sonde, sans ExtMac par defaut (la capture vient d'une sonde en MED) ; `voisins` : aucun par
    /// defaut (la capture n'en a pas).
    static func capture(chef: Int = 24, ext: String? = nil, reponsesEnPlus: [String: String] = [:],
                        table: [RouteurSonde]? = SondeRejouee.table(), tropLongs: Set<String> = [],
                        voisins: [VoisinSonde]? = []) throws -> SondeRejouee {
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
        r.merge(reponsesEnPlus) { _, b in b }
        return SondeRejouee(etatSonde: e, reponses: r, table: table, tropLongs: tropLongs)
    }

    /// La meme sonde, avec seulement les reponses dont la cle est gardee ; registre neuf.
    func filtree(_ garder: (String) -> Bool) -> SondeRejouee {
        SondeRejouee(etatSonde: etatSonde, reponses: reponses.filter { garder($0.key) }, table: table, tropLongs: tropLongs,
                     refus: refus, retards: retards)
    }

    /// La meme sonde, qui refuse (`erreur`) les requetes dont la cle est choisie ; registre neuf.
    func refusant(_ erreur: String = "occupee", _ choisies: @escaping @Sendable (String) -> Bool) -> SondeRejouee {
        SondeRejouee(etatSonde: etatSonde, reponses: reponses, table: table, tropLongs: tropLongs,
                     refus: { choisies($0) ? erreur : nil }, retards: retards)
    }
```

par :

```swift
        r.merge(reponsesEnPlus) { _, b in b }
        return SondeRejouee(etatSonde: e, reponses: r, table: table, tropLongs: tropLongs, listeVoisins: voisins)
    }

    /// La meme sonde, avec seulement les reponses dont la cle est gardee ; registre neuf.
    func filtree(_ garder: (String) -> Bool) -> SondeRejouee {
        SondeRejouee(etatSonde: etatSonde, reponses: reponses.filter { garder($0.key) }, table: table, tropLongs: tropLongs,
                     refus: refus, retards: retards, listeVoisins: listeVoisins)
    }

    /// La meme sonde, qui refuse (`erreur`) les requetes dont la cle est choisie ; registre neuf.
    func refusant(_ erreur: String = "occupee", _ choisies: @escaping @Sendable (String) -> Bool) -> SondeRejouee {
        SondeRejouee(etatSonde: etatSonde, reponses: reponses, table: table, tropLongs: tropLongs,
                     refus: { choisies($0) ? erreur : nil }, retards: retards, listeVoisins: listeVoisins)
    }
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
    func routeurs() async throws -> [RouteurSonde] { try await base.routeurs() }
```

par :

```swift
    func routeurs() async throws -> [RouteurSonde] { try await base.routeurs() }
    func voisins() async throws -> [VoisinSonde] { try await base.voisins() }
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
        #expect(r.memoire == mem, "memoire inchangee")
        #expect(await sonde.registre.requetes.isEmpty)
        #expect(await sonde.registre.tables == 0, "ni la table des routeurs")
    }
```

par :

```swift
        #expect(r.memoire == mem, "memoire inchangee")
        #expect(await sonde.registre.requetes.isEmpty)
        #expect(await sonde.registre.tables == 0, "ni la table des routeurs")
        #expect(await sonde.registre.voisins == 0, "ni les voisins")
    }
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
    /// Avancement de la premiere tournee : les six etapes dans l'ordre, chacune annoncee a 0
    /// puis une requete a la fois jusqu'a son total, connu des son debut ici. Les totaux sont
    /// les requetes envoyees : `etat` et `routeurs` pour la sonde, 48 pour le balayage.
```

par :

```swift
    /// Avancement de la premiere tournee : les six etapes dans l'ordre, chacune annoncee a 0
    /// puis une requete a la fois jusqu'a son total, connu des son debut ici. Les totaux sont
    /// les requetes envoyees : `etat`, `routeurs` et `voisins` pour la sonde, 48 pour le balayage.
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
        let totaux: [AvancementTournee.Etape: Int] = [.etatSonde: 2, .listeRouteurs: 1, .routeurs: 7, .pileEtReseau: 3,
```

par :

```swift
        let totaux: [AvancementTournee.Etape: Int] = [.etatSonde: 3, .listeRouteurs: 1, .routeurs: 7, .pileEtReseau: 3,
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
        #expect(requetes.count == totaux.values.reduce(0, +) - 2, "une requete diag par pas, hors etat et routeurs de la sonde")
        #expect(await sonde.registre.tables == 1)
```

par :

```swift
        #expect(requetes.count == totaux.values.reduce(0, +) - 3,
                "une requete diag par pas, hors etat, routeurs et voisins de la sonde")
        #expect(await sonde.registre.tables == 1)
        #expect(await sonde.registre.voisins == 1)
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
    /// Sonde pas encore dans le reseau.
    @Test func nonAttachee() async throws {
```

par :

```swift
    /// Signal des routeurs que la sonde entend (valeurs inventees) : son parent AC00 par `etat`
    /// (-89 dBm), qui passe avant sa ligne de `voisins` ; E400 par `voisins`. Ni un RSSI invalide
    /// (127, CC00), ni un enfant, ni un routeur hors de la liste (0800). Une demande par tournee.
    @Test func signauxDeLaSonde() async throws {
        let voisins = [VoisinSonde(rloc16: "E400", ext: "E0000000000000E4", rssi: -72, lqi: 3, routeur: true),
                       VoisinSonde(rloc16: "CC00", ext: "E0000000000000CC", rssi: 127, lqi: 0, routeur: true),
                       VoisinSonde(rloc16: "AC00", ext: "E000000000000007", rssi: -60, lqi: 3, routeur: true),
                       VoisinSonde(rloc16: "0800", ext: "E0000000000000EE", rssi: -80, lqi: 2, routeur: true),
                       VoisinSonde(rloc16: "5003", ext: "E0000000000000A3", rssi: -50, lqi: 3, routeur: false)]
        let sonde = try SondeRejouee.capture(voisins: voisins)
        let (m, _) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.signaux == [SignalSonde(routeur: 43, rssi: -89), SignalSonde(routeur: 57, rssi: -72)])
        #expect(m.parentSonde == 43)
        #expect(await sonde.registre.voisins == 1)
    }

    /// Pas de liste des voisins (verrou d'OpenThread refuse...) : la tournee continue, avec le seul
    /// signal du parent.
    @Test func sansVoisins() async throws {
        let sonde = try SondeRejouee.capture(voisins: nil)
        let (m, _) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeurs.count == 7)
        #expect(m.signaux == [SignalSonde(routeur: 43, rssi: -89)])
        #expect(await sonde.registre.voisins == 1)
    }

    /// Sonde pas encore dans le reseau.
    @Test func nonAttachee() async throws {
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
        #expect(await sonde.registre.tables == 0, "pas de table hors d'une partition")
        #expect(releve.avancements == [AvancementTournee(etape: .etatSonde, fait: 0, total: 2),
                                       AvancementTournee(etape: .etatSonde, fait: 1, total: 2)],
```

par :

```swift
        #expect(await sonde.registre.tables == 0, "pas de table hors d'une partition")
        #expect(await sonde.registre.voisins == 0, "ni de voisins")
        #expect(releve.avancements == [AvancementTournee(etape: .etatSonde, fait: 0, total: 3),
                                       AvancementTournee(etape: .etatSonde, fait: 1, total: 3)],
```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
    /// Sonde attachee (valeurs inventees) : enfant 0001 du routeur 0, qui est le chef.
```

par :

```swift
    /// Ligne `voisins` : chaque routeur par son RLOC16 et son signal (ExtMac inventee).
    static func voisins(_ liste: [(rloc16: String, rssi: Int)]) -> String {
        let l = liste.map { #"{"rloc16":"\#($0.rloc16)","ext":"E0000000000000\#($0.rloc16.prefix(2))","rssi":\#($0.rssi),"lqi":3,"routeur":true}"# }
        return #"{"v":1,"t":"voisins","liste":[\#(l.joined(separator: ","))]}"#
    }

    /// Sonde attachee (valeurs inventees) : enfant 0001 du routeur 0, qui est le chef.
```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
    /// `routeurs` : le chef seul, parent de la sonde, donc sans ExtMac.
    static func reseauMinimal(_ ligne: String) -> [String] {
        switch ligne {
        case "bonjour\n": return [bonjour]
        case "etat\n": return [etatAttache]
        case "routeurs\n": return [routeurs([("0000", nil)], suite: false)]
```

par :

```swift
    /// `routeurs` : le chef seul, parent de la sonde, donc sans ExtMac ; `voisins` : aucun.
    static func reseauMinimal(_ ligne: String) -> [String] {
        switch ligne {
        case "bonjour\n": return [bonjour]
        case "etat\n": return [etatAttache]
        case "routeurs\n": return [routeurs([("0000", nil)], suite: false)]
        case "voisins\n": return [voisins([])]
```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
    /// Un bonjour non demande : la sonde vient de redemarrer.
```

par :

```swift
    /// `voisins` : les routeurs que la sonde entend, avec leur signal (valeurs inventees).
    @Test func voisins() async throws {
        let canal = CanalRejoue { l in l == "voisins\n" ? [CanalRejoue.voisins([("E400", -72), ("CC00", -80)])] : [] }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        let v = try await s.voisins()
        #expect(v.map(\.rloc16) == ["E400", "CC00"])
        #expect(v.map(\.rssi) == [-72, -80])
        #expect(canal.envoyes == ["voisins\n"])
    }

    /// Un bonjour non demande : la sonde vient de redemarrer.
```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
    @Test(.timeLimit(.minutes(1)), arguments: ["bonjour", "etat", "routeurs"])
```

par :

```swift
    @Test(.timeLimit(.minutes(1)), arguments: ["bonjour", "etat", "routeurs", "voisins"])
```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
        case "etat": CanalRejoue.etatDetache
        default: CanalRejoue.routeurs([("0400", nil)], suite: false)
        }
        @Sendable func requete() async throws {
            switch commande {
            case "bonjour": _ = try await s.bonjour()
            case "etat": _ = try await s.etat()
            default: _ = try await s.routeurs()
```

par :

```swift
        case "etat": CanalRejoue.etatDetache
        case "voisins": CanalRejoue.voisins([("0400", -70)])
        default: CanalRejoue.routeurs([("0400", nil)], suite: false)
        }
        @Sendable func requete() async throws {
            switch commande {
            case "bonjour": _ = try await s.bonjour()
            case "etat": _ = try await s.etat()
            case "voisins": _ = try await s.voisins()
            default: _ = try await s.routeurs()
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/TourneeTests MaillageThreadTests/SondeUSBTests`
Expected: la compilation des tests échoue. Au rejeu, la cible de l'app s'est arrêtée la première, avec `error: value of type 'SondeUSB' has no member 'voisins'` ; selon l'ordre de compilation, le cœur peut échouer d'abord (`error: cannot find 'SignalSonde' in scope`, `error: value of type 'Maillage' has no member 'signaux'`).

- [ ] **Step 3 : écrire le code.**

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
/// Le maillage d'une partition, tel qu'une tournee de la sonde le voit.
public struct Maillage: Hashable, Sendable {
```

par :

```swift
/// Signal d'un routeur tel que la sonde l'entend a une tournee (spec de la sonde, section 6) :
/// son parent (`etat`) ou un routeur voisin (`voisins`).
public struct SignalSonde: Hashable, Sendable {
    /// Identifiant du routeur.
    public let routeur: Int
    /// RSSI moyen, en dBm.
    public let rssi: Int

    public init(routeur: Int, rssi: Int) {
        self.routeur = routeur
        self.rssi = rssi
    }
}

/// Le maillage d'une partition, tel qu'une tournee de la sonde le voit.
public struct Maillage: Hashable, Sendable {
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    /// Par RLOC16 croissant.
    public let enfants: [EnfantMaillage]

    public func routeur(_ id: Int) -> RouteurMaillage? { routeurs.first { $0.id == id } }
    public func liens(de id: Int) -> [LienRadio] { liens.filter { $0.a == id || $0.b == id } }
    public func enfants(de id: Int) -> [EnfantMaillage] { enfants.filter { $0.parent == id } }
    public var chef: RouteurMaillage? { routeurs.first(where: \.chef) }
}
```

par :

```swift
    /// Par RLOC16 croissant.
    public let enfants: [EnfantMaillage]
    /// Signal des routeurs de la liste que la sonde entend, son parent compris, par identifiant
    /// croissant.
    public let signaux: [SignalSonde]

    public func routeur(_ id: Int) -> RouteurMaillage? { routeurs.first { $0.id == id } }
    public func liens(de id: Int) -> [LienRadio] { liens.filter { $0.a == id || $0.b == id } }
    public func enfants(de id: Int) -> [EnfantMaillage] { enfants.filter { $0.parent == id } }
    public var chef: RouteurMaillage? { routeurs.first(where: \.chef) }
    /// Identifiant de routeur du parent de la sonde.
    public var parentSonde: Int? { enfants.first { $0.source == .sonde }?.parent }
}
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    private var enfants: [UInt16: EnfantMaillage] = [:]

    public init(date: Date, partition: String) {
```

par :

```swift
    private var enfants: [UInt16: EnfantMaillage] = [:]
    private var signaux: [Int: SignalSonde] = [:]

    public init(date: Date, partition: String) {
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    /// Roles poses a la main (maillage de demo).
```

par :

```swift
    /// Signal d'un routeur entendu par la sonde ; le dernier donne pour un routeur l'emporte. Un
    /// RSSI positif ou nul est ignore (127 : RSSI invalide d'OpenThread, rien d'entendu encore).
    public mutating func signal(_ s: SignalSonde) {
        guard s.rssi < 0 else { return }
        signaux[s.routeur] = s
    }

    /// Roles poses a la main (maillage de demo).
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    public func maillage() -> Maillage {
        Maillage(date: date, partition: partition,
                 routeurs: routeurs.values.sorted { $0.id < $1.id },
                 liens: liens.values.sorted { ($0.a, $0.b) < ($1.a, $1.b) },
                 enfants: enfants.values.sorted { $0.rloc16 < $1.rloc16 })
    }
```

par :

```swift
    /// Le maillage ; les signaux des seuls routeurs de la liste.
    public func maillage() -> Maillage {
        Maillage(date: date, partition: partition,
                 routeurs: routeurs.values.sorted { $0.id < $1.id },
                 liens: liens.values.sorted { ($0.a, $0.b) < ($1.a, $1.b) },
                 enfants: enfants.values.sorted { $0.rloc16 < $1.rloc16 },
                 signaux: signaux.values.filter { routeurs[$0.routeur] != nil }.sorted { $0.routeur < $1.routeur })
    }
```

Dans `MaillageCoeur/Maillage/Tournee.swift`, remplacer :

```swift
    func routeurs() async throws -> [RouteurSonde]
```

par :

```swift
    func routeurs() async throws -> [RouteurSonde]
    /// Routeurs voisins que la sonde entend (`voisins`), avec leur signal ; son parent n'y est
    /// pas (`etat` le donne). Requete locale, sans delai reseau.
    func voisins() async throws -> [VoisinSonde]
```

Dans `MaillageCoeur/Maillage/Tournee.swift`, remplacer :

```swift
        /// `etat` de la sonde, puis sa table des routeurs (`routeurs`).
```

par :

```swift
        /// `etat` de la sonde, puis sa table des routeurs (`routeurs`) et ses voisins (`voisins`).
```

Dans `MaillageCoeur/Maillage/Tournee.swift`, remplacer :

```swift
    /// date d'une recherche complete vaine.
    /// `avancement` est appele au debut de chaque etape atteinte, puis a chaque requete
```

par :

```swift
    /// date d'une recherche complete vaine.
    /// Le maillage porte aussi le signal des routeurs que la sonde entend (`voisins`) et celui
    /// de son parent (`etat`), pour l'historique (spec de la sonde, section 6).
    /// `avancement` est appele au debut de chaque etape atteinte, puis a chaque requete
```

Dans `MaillageCoeur/Maillage/Tournee.swift`, remplacer :

```swift
        signaler(.etatSonde, 0, 2)
        let etat = try await sonde.etat()
        signaler(.etatSonde, 1, 2)
```

par :

```swift
        signaler(.etatSonde, 0, 3)
        let etat = try await sonde.etat()
        signaler(.etatSonde, 1, 3)
```

Dans `MaillageCoeur/Maillage/Tournee.swift`, remplacer :

```swift
        let table = (try? await sonde.routeurs()) ?? []
        signaler(.etatSonde, 2, 2)
        var c = ConstructionMaillage(date: maintenant, partition: partition)
        if let p = etat.parent, let rp = UInt16(p.rloc16, radix: 16) {
            mem.retenir(p.ext, rloc16: rp)
            c.enfant(EnfantMaillage(rloc16: moi, extMac: etat.ext, qualite: p.lqOut, source: .sonde))
        }
```

par :

```swift
        let table = (try? await sonde.routeurs()) ?? []
        signaler(.etatSonde, 2, 3)
        // Voisins de la sonde (requete locale) : le signal de chaque routeur qu'elle entend. Sans
        // reponse, la tournee continue sans eux.
        let voisins = (try? await sonde.voisins()) ?? []
        signaler(.etatSonde, 3, 3)
        var c = ConstructionMaillage(date: maintenant, partition: partition)
        for v in voisins where v.routeur {
            if let r = UInt16(v.rloc16, radix: 16) { c.signal(SignalSonde(routeur: Int(r >> 10), rssi: v.rssi)) }
        }
        if let p = etat.parent, let rp = UInt16(p.rloc16, radix: 16) {
            mem.retenir(p.ext, rloc16: rp)
            c.enfant(EnfantMaillage(rloc16: moi, extMac: etat.ext, qualite: p.lqOut, source: .sonde))
            // Apres les voisins : le signal du parent, donne par `etat`, passe avant.
            c.signal(SignalSonde(routeur: Int(rp >> 10), rssi: p.rssi))
        }
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
/// Attentes d'une commande sans id (`bonjour`, `etat`, `routeurs`) : les reponses les servent
```

par :

```swift
/// Attentes d'une commande sans id (`bonjour`, `etat`, `routeurs`, `voisins`) : les reponses les servent
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
/// ordre pour `bonjour`, `etat` et `routeurs`, par id et cible pour `diag` (8 en vol, dans le
/// desordre). Chaque requete a sa propre echeance.
```

par :

```swift
/// ordre pour `bonjour`, `etat`, `routeurs` et `voisins`, par id et cible pour `diag` (8 en vol,
/// dans le desordre). Chaque requete a sa propre echeance.
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
    /// Attente de `bonjour`, `etat`, `routeurs` et `cle nouvelle` : 3 s en USB, qui ne perd rien ;
```

par :

```swift
    /// Attente de `bonjour`, `etat`, `routeurs`, `voisins` et `cle nouvelle` : 3 s en USB, qui ne perd rien ;
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
    /// Jetons des attentes de `bonjour`, `etat` et `routeurs` (jamais envoyes a la sonde).
```

par :

```swift
    /// Jetons des attentes de `bonjour`, `etat`, `routeurs` et `voisins` (jamais envoyes a la sonde).
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
    private var attenteRouteurs = FileAttentes<[RouteurSonde]>()
```

par :

```swift
    private var attenteRouteurs = FileAttentes<[RouteurSonde]>()
    private var attenteVoisins = FileAttentes<[VoisinSonde]>()
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
    private func nouveauJeton() -> Int {
```

par :

```swift
    /// Routeurs voisins que la sonde entend, avec leur signal. `sansReponse` si la sonde ne rend
    /// pas de liste dans le delai : une ligne `voisins` en erreur (`occupee`, verrou d'OpenThread)
    /// ou `erreur` (liste trop longue par le reseau) n'est pas une liste.
    func voisins() async throws -> [VoisinSonde] {
        guard !fermee else { throw Erreur.fermee }
        let jeton = nouveauJeton()
        let v = await withCheckedContinuation { c in
            attenteVoisins.ajouter(jeton, c)
            canal.envoyer(CommandeSonde.voisins.ligne)
            Task {
                try? await Task.sleep(for: self.delaiCommande)
                self.attenteVoisins.expirer(jeton)
            }
        }
        guard let v else { throw fermee ? Erreur.fermee : Erreur.sansReponse("voisins") }
        return v
    }

    private func nouveauJeton() -> Int {
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
        case .routeurs(let p)?:
            recevoirRouteurs(p)
```

par :

```swift
        case .routeurs(let p)?:
            recevoirRouteurs(p)
        case .voisins(let v)?:
            attenteVoisins.servir(v)
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
        attenteRouteurs.liberer()
        routeursRecus = []
```

par :

```swift
        attenteRouteurs.liberer()
        attenteVoisins.liberer()
        routeursRecus = []
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/TourneeTests MaillageThreadTests/SondeUSBTests`
Expected: `Test run with 51 tests in 1 suite passed` (cœur, `TourneeTests`) et `Test run with 14 tests in 1 suite passed` (app, `SondeUSBTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement ; 2 tests de plus pour le cœur, 1 pour l'app (au rejeu : 231 tests en 21 suites, et 217 en 24 suites).

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Maillage/Maillage.swift MaillageCoeur/Maillage/Tournee.swift MaillageThread/Sonde/SondeUSB.swift MaillageCoeurTests/TourneeTests.swift MaillageThreadTests/SondeTests.swift
git commit -m "Demander les voisins a chaque tournee et garder le signal vu par la sonde

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Liaison : les réponses « occupée » d'`etat` et de `voisins` (n° 36)

**Files:**
- Modify: `MaillageCoeur/Maillage/ProtocoleSonde.swift`, `MaillageThread/Sonde/SondeUSB.swift` (blocs ci-dessous), `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` (Step 4)
- Test: `MaillageCoeurTests/ProtocoleSondeTests.swift`, `MaillageThreadTests/SondeTests.swift` (blocs ci-dessous)

**Interfaces:**
- Consumes : les lignes `{"v":1,"t":"etat","erreur":"occupee"}` et `{"v":1,"t":"voisins","erreur":"occupee"}` que la sonde écrit quand elle n'a pas pu prendre le verrou d'OpenThread (200 ms ; `cmdEtat` et `cmdVoisins` de `sonde/src/main.cpp`) ; `PartieRouteurs.erreur` (plan 3a, pour `routeurs`) ; `SondeUSB.voisins()` (tâche 2).
- Produces :
  - `MessageSonde.refusee(commande: String, erreur: String)` : une ligne `etat` ou `voisins` qui porte une erreur au lieu de ses champs ;
  - `SondeUSB.Erreur.occupee(String)`, « la sonde est occupée et n'a pas répondu à « etat » » : `etat()`, `voisins()` et `routeurs()` échouent tout de suite quand la sonde répond `occupee` ; une autre erreur de ces lignes donne `refusee(_)` ;
  - les attentes d'`etat`, de `routeurs` et de `voisins` portent un `Result` ;
  - `routeurs()` refusé : `occupee("routeurs")`, et non plus `sansReponse("routeurs")` (le test `routeursOccupee` devient `commandeOccupee`, pour les trois commandes) ;
  - la tournée qui n'a pas `etat` s'arrête sur « la sonde est occupée… » dès le refus (`SondeMaillage.erreurTournee`, test `etatOccupee`), au lieu de « la sonde ne répond pas à « etat » » au bout de 3 s. Sans `routeurs` ni `voisins`, elle continue sans, comme avant, mais sans attendre.

- [ ] **Step 1 : écrire les tests.**

Dans `MaillageCoeurTests/ProtocoleSondeTests.swift`, remplacer :

```swift
    }

    @Test func autres() {
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"voisins","liste":[{"rloc16":"AC00","ext":"E000000000000007","rssi":-89,"lqi":3,"routeur":true}]}"#.utf8))
```

par :

```swift
    }

    /// `etat` et `voisins` que la sonde n'a pas pu servir (verrou d'OpenThread refuse) : la commande
    /// et l'erreur, pour que l'app le dise tout de suite, sans attendre l'echeance.
    @Test func refusees() {
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"etat","erreur":"occupee"}"#.utf8))
                == .refusee(commande: "etat", erreur: "occupee"))
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"voisins","erreur":"occupee"}"#.utf8))
                == .refusee(commande: "voisins", erreur: "occupee"))
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"etat","role":"child"}"#.utf8)) == nil, "ni etat lisible, ni erreur")
    }

    @Test func autres() {
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"voisins","liste":[{"rloc16":"AC00","ext":"E000000000000007","rssi":-89,"lqi":3,"routeur":true}]}"#.utf8))
```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
    }

    /// La sonde n'a pas le verrou d'OpenThread (`occupee`) : pas de table, sans attendre le delai.
    @Test(.timeLimit(.minutes(1))) func routeursOccupee() async throws {
        let s = SondeUSB(canal: CanalRejoue { l in
            l == "routeurs\n" ? [#"{"v":1,"t":"routeurs","erreur":"occupee"}"#] : []
        })
        try await s.demarrer {}
        let debut = ContinuousClock.now
        await #expect(throws: SondeUSB.Erreur.sansReponse("routeurs")) { _ = try await s.routeurs() }
        #expect(ContinuousClock.now - debut < SondeUSB.delaiCommandeUSB)
    }

```

par :

```swift
    }

    /// La sonde n'a pas le verrou d'OpenThread (`occupee`) : `etat`, `voisins` et `routeurs`
    /// echouent tout de suite en `occupee`, sans attendre le delai, et le message le dit.
    @Test(.timeLimit(.minutes(1)), arguments: ["etat", "voisins", "routeurs"])
    func commandeOccupee(_ commande: String) async throws {
        let s = SondeUSB(canal: CanalRejoue { l in
            l == commande + "\n" ? [#"{"v":1,"t":"\#(commande)","erreur":"occupee"}"#] : []
        })
        try await s.demarrer {}
        let debut = ContinuousClock.now
        await #expect(throws: SondeUSB.Erreur.occupee(commande)) {
            switch commande {
            case "etat": _ = try await s.etat()
            case "voisins": _ = try await s.voisins()
            default: _ = try await s.routeurs()
            }
        }
        #expect(ContinuousClock.now - debut < SondeUSB.delaiCommandeUSB)
        #expect(SondeUSB.Erreur.occupee(commande).localizedDescription
                == String(localized: "la sonde est occupée et n'a pas répondu à « \(commande) »"))
    }

```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
    }

    /// Age compte depuis la reception : frais jusqu'a 6 min, ancien jusqu'a 15, perime
    /// ensuite ; pendant une tournee, jamais ancien, mais perime apres 15 min.
```

par :

```swift
    }

    /// `etat` refuse au debut d'une tournee (sonde occupee) : l'erreur de la tournee le dit tout de
    /// suite, au lieu de « la sonde ne repond pas » au bout de l'echeance.
    @Test(.timeLimit(.minutes(1))) func etatOccupee() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let canal = CanalRejoue { l in
            l == "etat\n" ? [#"{"v":1,"t":"etat","erreur":"occupee"}"#] : CanalRejoue.reseauMinimal(l)
        }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        let debut = ContinuousClock.now
        await s.connecter(Self.port, choisi: true)
        await Self.attendre { s.erreurTournee != nil }
        #expect(s.erreurTournee == SondeUSB.Erreur.occupee("etat").localizedDescription)
        #expect(ContinuousClock.now - debut < SondeUSB.delaiCommandeUSB)
        await s.oublier()
    }

    /// Age compte depuis la reception : frais jusqu'a 6 min, ancien jusqu'a 15, perime
    /// ensuite ; pendant une tournee, jamais ancien, mais perime apres 15 min.
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/ProtocoleSondeTests MaillageThreadTests/SondeUSBTests MaillageThreadTests/SondeMaillageTests`
Expected: la compilation des tests échoue, par exemple avec `error: type 'MessageSonde?' has no member 'refusee'` (cœur) et `error: type 'SondeUSB.Erreur' has no member 'occupee'` (app).

- [ ] **Step 3 : écrire le code.**

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
    case diag(ResultatDiag)
    case cle(ReponseCle)
    case erreur(String)
    /// Type inconnu (version plus recente de la sonde) : ignore.
```

par :

```swift
    case diag(ResultatDiag)
    case cle(ReponseCle)
    /// Commande sans id (`etat`, `voisins`) que la sonde n'a pas servie : son nom et l'erreur de la
    /// ligne (`occupee` : verrou d'OpenThread refuse). `routeurs` porte la sienne dans `PartieRouteurs`.
    case refusee(commande: String, erreur: String)
    case erreur(String)
    /// Type inconnu (version plus recente de la sonde) : ignore.
```

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
        switch e.t {
        case "bonjour": return (try? d.decode(Bonjour.self, from: json)).map { .bonjour($0) }
        case "etat": return (try? d.decode(EtatSonde.self, from: json)).map { .etat($0) }
        case "voisins": return (try? d.decode(Voisins.self, from: json)).map { .voisins($0.liste) }
        case "routeurs": return (try? d.decode(Routeurs.self, from: json))?.partie.map { .routeurs($0) }
        case "diag": return (try? d.decode(ResultatDiag.self, from: json)).map { .diag($0) }
```

par :

```swift
        switch e.t {
        case "bonjour": return (try? d.decode(Bonjour.self, from: json)).map { .bonjour($0) }
        case "etat":
            if let etat = try? d.decode(EtatSonde.self, from: json) { return .etat(etat) }
            return (try? d.decode(Erreur.self, from: json)).map { .refusee(commande: "etat", erreur: $0.erreur) }
        case "voisins":
            if let v = try? d.decode(Voisins.self, from: json) { return .voisins(v.liste) }
            return (try? d.decode(Erreur.self, from: json)).map { .refusee(commande: "voisins", erreur: $0.erreur) }
        case "routeurs": return (try? d.decode(Routeurs.self, from: json))?.partie.map { .routeurs($0) }
        case "diag": return (try? d.decode(ResultatDiag.self, from: json)).map { .diag($0) }
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
        /// Ligne `erreur` de la sonde pendant une demande de cle (firmware sans acces reseau...).
        case refusee(String)

        var errorDescription: String? {
```

par :

```swift
        /// Ligne `erreur` de la sonde pendant une demande de cle (firmware sans acces reseau...).
        case refusee(String)
        /// La sonde n'a pas servi `etat`, `voisins` ou `routeurs` (`occupee` : verrou d'OpenThread
        /// refuse) : elle le dit tout de suite, sans attendre l'echeance.
        case occupee(String)

        var errorDescription: String? {
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
            case .sansReponse(let commande): String(localized: "la sonde ne répond pas à « \(commande) »")
            case .refusee(let raison): String(localized: "la sonde refuse : \(raison)")
            }
        }
```

par :

```swift
            case .sansReponse(let commande): String(localized: "la sonde ne répond pas à « \(commande) »")
            case .refusee(let raison): String(localized: "la sonde refuse : \(raison)")
            case .occupee(let commande): String(localized: "la sonde est occupée et n'a pas répondu à « \(commande) »")
            }
        }
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
    private var prochainJeton = 1
    private var attenteDiag: [Int: (cible: UInt16, suite: CheckedContinuation<ResultatDiag, Never>)] = [:]
    private var attenteEtat = FileAttentes<EtatSonde>()
    private var attenteBonjour = FileAttentes<Bonjour>()
    private var attenteRouteurs = FileAttentes<[RouteurSonde]>()
    private var attenteVoisins = FileAttentes<[VoisinSonde]>()
    /// Parties de la table des routeurs deja recues (lignes `suite`), en attendant la derniere.
    private var routeursRecus: [RouteurSonde] = []
```

par :

```swift
    private var prochainJeton = 1
    private var attenteDiag: [Int: (cible: UInt16, suite: CheckedContinuation<ResultatDiag, Never>)] = [:]
    /// `etat`, `routeurs` et `voisins` : la reponse, ou le refus de la sonde (`occupee`).
    private var attenteEtat = FileAttentes<Result<EtatSonde, Erreur>>()
    private var attenteBonjour = FileAttentes<Bonjour>()
    private var attenteRouteurs = FileAttentes<Result<[RouteurSonde], Erreur>>()
    private var attenteVoisins = FileAttentes<Result<[VoisinSonde], Erreur>>()
    /// Parties de la table des routeurs deja recues (lignes `suite`), en attendant la derniere.
    private var routeursRecus: [RouteurSonde] = []
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
        }
        guard let e else { throw fermee ? Erreur.fermee : Erreur.sansReponse("etat") }
        return e
    }

    /// Table des routeurs, ses lignes `suite` reunies. `sansReponse` si la sonde ne la rend
    /// pas : delai depasse (firmware sans `routeurs`), ou `occupee` (verrou d'OpenThread).
    func routeurs() async throws -> [RouteurSonde] {
        guard !fermee else { throw Erreur.fermee }
```

par :

```swift
        }
        guard let e else { throw fermee ? Erreur.fermee : Erreur.sansReponse("etat") }
        return try e.get()
    }

    /// Table des routeurs, ses lignes `suite` reunies. `sansReponse` si la sonde ne la rend
    /// pas dans le delai (firmware sans `routeurs`) ; `occupee` tout de suite si elle la refuse
    /// (verrou d'OpenThread).
    func routeurs() async throws -> [RouteurSonde] {
        guard !fermee else { throw Erreur.fermee }
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
        }
        guard let t else { throw fermee ? Erreur.fermee : Erreur.sansReponse("routeurs") }
        return t
    }

    /// Routeurs voisins que la sonde entend, avec leur signal. `sansReponse` si la sonde ne rend
    /// pas de liste dans le delai : une ligne `voisins` en erreur (`occupee`, verrou d'OpenThread)
    /// ou `erreur` (liste trop longue par le reseau) n'est pas une liste.
    func voisins() async throws -> [VoisinSonde] {
        guard !fermee else { throw Erreur.fermee }
```

par :

```swift
        }
        guard let t else { throw fermee ? Erreur.fermee : Erreur.sansReponse("routeurs") }
        return try t.get()
    }

    /// Routeurs voisins que la sonde entend, avec leur signal. `occupee` tout de suite si la sonde
    /// refuse (verrou d'OpenThread) ; `sansReponse` sans liste dans le delai (une ligne `erreur`,
    /// liste trop longue par le reseau, n'en est pas une).
    func voisins() async throws -> [VoisinSonde] {
        guard !fermee else { throw Erreur.fermee }
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
        }
        guard let v else { throw fermee ? Erreur.fermee : Erreur.sansReponse("voisins") }
        return v
    }

```

par :

```swift
        }
        guard let v else { throw fermee ? Erreur.fermee : Erreur.sansReponse("voisins") }
        return try v.get()
    }

```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift

    /// Partie de la table : gardee jusqu'a la derniere (`suite` faux), qui rend la table entiere
    /// a la premiere attente ; l'erreur (`occupee`) la libere sans table. Sans attente (reponse
    /// apres le delai), la table est oubliee.
    private func recevoirRouteurs(_ p: PartieRouteurs) {
        if p.erreur == nil {
```

par :

```swift

    /// Partie de la table : gardee jusqu'a la derniere (`suite` faux), qui rend la table entiere
    /// a la premiere attente ; l'erreur (`occupee`) la termine tout de suite, sans table. Sans
    /// attente (reponse apres le delai), la table est oubliee.
    private func recevoirRouteurs(_ p: PartieRouteurs) {
        if p.erreur == nil {
```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
            guard !p.suite else { return }
        }
        let table = p.erreur == nil ? routeursRecus : nil
        routeursRecus = []
        attenteRouteurs.servir(table)
    }

```

par :

```swift
            guard !p.suite else { return }
        }
        let table = routeursRecus
        routeursRecus = []
        attenteRouteurs.servir(p.erreur.map { .failure(Self.refus("routeurs", $0)) } ?? .success(table))
    }

    /// Erreur d'une commande sans id que la sonde n'a pas servie : `occupee` (verrou d'OpenThread
    /// refuse), ou une autre raison.
    private static func refus(_ commande: String, _ erreur: String) -> Erreur {
        erreur == "occupee" ? .occupee(commande) : .refusee(erreur)
    }

```

Dans `MaillageThread/Sonde/SondeUSB.swift`, remplacer :

```swift
            }
        case .etat(let e)?:
            attenteEtat.servir(e)
        case .routeurs(let p)?:
            recevoirRouteurs(p)
        case .voisins(let v)?:
            attenteVoisins.servir(v)
        case .bonjour(let b)?:
            if attenteBonjour.estVide {
```

par :

```swift
            }
        case .etat(let e)?:
            attenteEtat.servir(.success(e))
        case .routeurs(let p)?:
            recevoirRouteurs(p)
        case .voisins(let v)?:
            attenteVoisins.servir(.success(v))
        case .refusee(commande: "etat", let erreur)?:
            attenteEtat.servir(.failure(Self.refus("etat", erreur)))
        case .refusee(commande: "voisins", let erreur)?:
            attenteVoisins.servir(.failure(Self.refus("voisins", erreur)))
        case .bonjour(let b)?:
            if attenteBonjour.estVide {
```

- [ ] **Step 4 : textes, en français et en anglais.** Compiler, puis ajouter au catalogue les clés que le compilateur a extraites :

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/ProtocoleSondeTests MaillageThreadTests/SondeUSBTests MaillageThreadTests/SondeMaillageTests
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" outils/synchroniser-textes.sh
```

Expected : `** TEST SUCCEEDED **` (ces cibles n'incluent pas `CataloguesTests`) ; `Localizable.xcstrings` reçoit exactement cette clé : « la sonde est occupée et n'a pas répondu à « %@ » ».

Puis les traductions, par ce script qui garde `interface.json` trié et au format de l'outil, et le catalogue :

```bash
python3 - <<'EOF'
import json
f = 'outils/traductions/interface.json'
d = json.load(open(f, encoding='utf-8'))
d.update({
    "la sonde est occupée et n'a pas répondu à « %@ »": "the probe is busy and did not answer “%@”",
})
open(f, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

- [ ] **Step 5 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/ProtocoleSondeTests MaillageThreadTests/SondeUSBTests MaillageThreadTests/SondeMaillageTests`
Expected: `Test run with 21 tests in 1 suite passed` (cœur, `ProtocoleSondeTests`) et `Test run with 51 tests in 2 suites passed` (app : `SondeUSBTests` 14, `SondeMaillageTests` 37), `** TEST SUCCEEDED **`.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement, `CataloguesTests` compris ; 1 test de plus pour le cœur (`refusees`), 1 pour l'app (`etatOccupee` ; `routeursOccupee` devient `commandeOccupee`) (au rejeu : 232 tests en 21 suites, et 218 en 24 suites).

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Maillage/ProtocoleSonde.swift MaillageThread/Sonde/SondeUSB.swift MaillageCoeurTests/ProtocoleSondeTests.swift MaillageThreadTests/SondeTests.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Lire tout de suite les reponses occupee d'etat et de voisins

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Fiche : à l'heure de la fenêtre du graphe

**Files:**
- Modify: `MaillageThread/Surveillance/Surveillance.swift`, `MaillageThread/Vues/Graphe/FicheNoeud.swift`, `MaillageThread/Vues/Graphe/FenetreGraphe.swift` (blocs ci-dessous)
- Test: `MaillageThreadTests/FicheHeureTests.swift`

**Interfaces:**
- Consumes : `FenetreGraphe.horloge` et sa `TimelineView`, qui redessine la fenêtre au début de chaque minute (vague de mineurs, lot 4) ; `Surveillance.maintenant` ; `ScenarioPanne.releves` (pour les tests).
- Produces :
  - `Surveillance.maintenant(a horloge: Date) -> Date` : `horloge` en mode direct, la fin de la panne rejouée en démo ; `maintenant` vaut `maintenant(a: Date())` ;
  - `FicheNoeud.instant: Date`, juste après `id` : « vu il y a … » et « relevé il y a … » se comptent depuis cette heure ;
  - `FenetreGraphe` passe `surveillance.maintenant(a: contexte.date)` à la fiche. Sans cette entrée, qui change chaque minute, SwiftUI garderait le rendu de la fiche : ses autres entrées ne changent pas.

Le test rend la fiche d'un appareil (`ImageRenderer`) à deux heures : le rendu suit `instant`, pas l'horloge du Mac (au rejeu, la fiche qui lisait encore `surveillance.maintenant` échouait sur ce test). Le branchement dans `FenetreGraphe` n'a pas de test : la `TimelineView` ne se lit pas hors de l'écran ; la tâche 13 le vérifie avec Djoko.

- [ ] **Step 1 : écrire le test.**

`MaillageThreadTests/FicheHeureTests.swift` :

```swift
import AppKit
import Foundation
import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Fiche a l'heure de la fenetre du graphe")
struct FicheHeureTests {
    /// Un appareil des premiers releves de la panne rejouee.
    static let appareil = "56B1E064401F74EF"

    /// L'heure de la fenetre (celle de sa TimelineView), ou la fin de la panne rejouee en demo.
    @Test func maintenantALHeureDeLaFenetre() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let direct = Surveillance(mode: .direct, dossier: nil)
        #expect(direct.maintenant(a: t) == t)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        #expect(demo.maintenant(a: t) == demo.maintenant, "la fin de la panne, quelle que soit l'heure")
        #expect(demo.maintenant(a: t) != t)
    }

    /// La fiche d'un appareil lit l'heure qu'on lui donne, pas l'horloge du Mac : « vu il y a … » change
    /// avec elle (rendu de la fiche a deux heures), et deux rendus a la meme heure sont identiques.
    @Test func ficheSuitSonHeure() throws {
        let s = Surveillance(mode: .direct, dossier: nil)
        for a in ScenarioPanne.releves.prefix(12) { s.integrer(a) }
        let vu = try #require(s.instantane?.date)
        func rendu(_ instant: Date) -> Data? {
            let fiche = FicheNoeud(id: Self.appareil, instant: instant, aRenommer: .constant(nil), fermer: {})
                .environment(s)
                .frame(width: 1000)
            return ImageRenderer(content: fiche).nsImage?.tiffRepresentation
        }
        let uneMinute = try #require(rendu(vu.addingTimeInterval(60)))
        #expect(rendu(vu.addingTimeInterval(60)) == uneMinute)
        #expect(rendu(vu.addingTimeInterval(3 * 3600)) != uneMinute)
    }
}
```

- [ ] **Step 2 : vérifier qu'il échoue.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageThreadTests/FicheHeureTests MaillageThreadTests/AffichageSondeTests MaillageThreadTests/GrapheTests`
Expected: la compilation des tests de l'app échoue : `error: cannot call value of non-function type 'Date'` (`maintenant(a:)`) et `error: extra argument 'instant' in call`.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    /// Reference des durees affichees ("vu il y a...") : la fin de la panne rejouee en demo.
    var maintenant: Date { mode == .demo ? (dernierReleve?.date ?? Date()) : Date() }
```

par :

```swift
    /// Reference des durees affichees ("vu il y a...") : la fin de la panne rejouee en demo.
    var maintenant: Date { maintenant(a: Date()) }

    /// Reference des durees a l'heure `horloge` (celle de la fenetre du graphe, que sa `TimelineView`
    /// avance chaque minute) : cette heure, ou la fin de la panne rejouee en demo.
    func maintenant(a horloge: Date) -> Date { mode == .demo ? (dernierReleve?.date ?? horloge) : horloge }
```

Dans `MaillageThread/Vues/Graphe/FicheNoeud.swift`, remplacer :

```swift
    let id: String
    @Binding var aRenommer: NoeudChoisi?
```

par :

```swift
    let id: String
    /// Heure de la fenetre du graphe (sa `TimelineView`, chaque minute ; la fin de la panne en demo) :
    /// les durees de la fiche (« vu il y a... ») suivent l'heure sans autre evenement.
    let instant: Date
    @Binding var aRenommer: NoeudChoisi?
```

Dans `MaillageThread/Vues/Graphe/FicheNoeud.swift`, remplacer :

```swift
                    Text("· vu \(Self.relatif(vu, surveillance.maintenant))").foregroundStyle(.secondary)
```

par :

```swift
                    Text("· vu \(Self.relatif(vu, instant))").foregroundStyle(.secondary)
```

Dans `MaillageThread/Vues/Graphe/FicheNoeud.swift`, remplacer :

```swift
                        Text("· relevé \(Self.relatif(releve, surveillance.maintenant))").foregroundStyle(.secondary)
```

par :

```swift
                        Text("· relevé \(Self.relatif(releve, instant))").foregroundStyle(.secondary)
```

Dans `MaillageThread/Vues/Graphe/FenetreGraphe.swift`, remplacer :

```swift
        // Redessin chaque minute (`horloge`) : le contenu lit l'heure, que rien n'observe.
        TimelineView(Self.horloge) { _ in
```

par :

```swift
        // Redessin chaque minute (`horloge`) : le contenu lit l'heure, que rien n'observe. La fiche la
        // recoit (`instant`) : sinon SwiftUI la sauterait, ses entrees n'ayant pas change.
        TimelineView(Self.horloge) { contexte in
```

Dans `MaillageThread/Vues/Graphe/FenetreGraphe.swift`, remplacer :

```swift
                        FicheNoeud(id: selection, aRenommer: $aRenommer, choisir: { self.selection = $0 }) {
```

par :

```swift
                        FicheNoeud(id: selection, instant: surveillance.maintenant(a: contexte.date), aRenommer: $aRenommer,
                                   choisir: { self.selection = $0 }) {
```

- [ ] **Step 4 : vérifier qu'il passe.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageThreadTests/FicheHeureTests MaillageThreadTests/AffichageSondeTests MaillageThreadTests/GrapheTests`
Expected: `Test run with 23 tests in 3 suites passed` (app : `FicheHeureTests` 2, et `AffichageSondeTests` 15, `GrapheTests` 6, inchangés), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 2 tests et 1 suite de plus pour l'app (au rejeu : 232 tests en 21 suites, et 220 en 25 suites).

- [ ] **Step 6 : commit.**

```bash
git add MaillageThread/Surveillance/Surveillance.swift MaillageThread/Vues/Graphe/FicheNoeud.swift MaillageThread/Vues/Graphe/FenetreGraphe.swift MaillageThreadTests/FicheHeureTests.swift
git commit -m "Mettre la fiche du graphe a l'heure de sa fenetre

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Cœur : l'historique en fichiers mensuels

**Files:**
- Create: `MaillageCoeur/Journal/FichiersMensuels.swift`, `MaillageCoeur/Maillage/HistoriqueMaillage.swift`
- Modify: `MaillageCoeur/Journal/JournalFichiers.swift` (fichier entier : il délègue à `FichiersMensuels`, sans changer son API), `MaillageCoeur/Maillage/Maillage.swift` (bloc ci-dessous)
- Test: `MaillageCoeurTests/HistoriqueTests.swift` ; `MaillageCoeurTests/JournalTests.swift` passe sans changement

**Interfaces:**
- Consumes : `Maillage` (`signaux`, `parentSonde`, tâche 2), `LienRadio`, `CodageJSON` (dates ISO 8601 à la milliseconde, clés triées).
- Produces :
  - `FichiersMensuels(dossier:prefixe:calendrier:)` : `nomFichier(_:)`, `ajouter(_ lignes: [(date: Date, json: Data)])`, `lignes(depuis:) -> [Data]`, `purger(maintenant:)`, et en interne `fichiers()`, `finDuMois(_:)` ; `FichiersMensuels.conservation` (90 jours) ;
  - `Maillage.enfantsIdentifies: [String: EnfantMaillage]` : un enfant par ExtMac, l'entrée fraîche (table, sonde) avant celle d'un balayage ;
  - `ReleveMaillage` (`date`, `partition`, `routeurs: [ReleveMaillage.Routeur]` (`id`, `extMac`), `liens: [LienRadio]`, `enfants: [ReleveMaillage.Enfant]` (`extMac`, `parent`, `qualite`), `signaux: [SignalSonde]`, `parentSonde: Int?`), `init(_ m: Maillage)`, l'init membre à membre public, `cle(routeur:) -> String` (l'ExtMac, sinon `"rloc:XXXX"`), `Codable` en tableaux ;
  - `HistoriqueFichiers(dossier:calendrier:)` : `nomFichier(_:)` (`maillage-AAAA-MM.jsonl`), `ajouter(_ r: ReleveMaillage)`, `lire(depuis:) -> [ReleveMaillage]`, `purger(maintenant:)`.

Une ligne d'historique, sur la tournée de la capture (7 routeurs, 10 enfants identifiés) : 623 octets. Avec 20 enfants : 883 octets. D'où « environ 0,9 Ko par tournée, 8 Mo par mois » (288 tournées par jour).

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/HistoriqueTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Historique du maillage : releves et fichiers mensuels")
struct HistoriqueTests {
    static func date(_ texte: String) -> Date {
        try! Date(texte, strategy: .iso8601)
    }

    static func dossier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("historique-\(UUID().uuidString)")
    }

    /// Petit maillage (valeurs inventees) : le chef 0 et le routeur 1, muet, sans ExtMac ; la sonde
    /// 0001 sous 0 ; un enfant balaye sous 1 ; un enfant de table sans ExtMac ; deux signaux.
    static func maillage(_ date: Date) -> Maillage {
        var c = ConstructionMaillage(date: date, partition: "0000000A")
        c.routeurs(Route64(sequence: 1, routes: [RouteRouteur(idRouteur: 0, qualiteSortante: 3, qualiteEntrante: 2, cout: 1),
                                                 RouteRouteur(idRouteur: 1, qualiteSortante: 0, qualiteEntrante: 0, cout: 1)]),
                   chef: 0)
        c.identite("E0000000000000A0", routeur: 0)
        c.muet(1)
        c.lien(0, 1, sortante: 3, entrante: 2)
        c.enfant(EnfantMaillage(rloc16: 0x0001, extMac: "E0000000000000B1", qualite: 3, source: .sonde))
        c.enfant(EnfantMaillage(rloc16: 0x0402, extMac: "E0000000000000B2", source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x0003, qualite: 2, source: .tableEnfants))
        c.signal(SignalSonde(routeur: 0, rssi: -60))
        c.signal(SignalSonde(routeur: 1, rssi: -75))
        return c.maillage()
    }

    /// Une ligne par tournee, en tableaux : routeurs, liens, enfants identifies (pas celui sans
    /// ExtMac), signaux, parent de la sonde. Relue a l'identique.
    @Test func ligneDUnReleve() throws {
        let r = ReleveMaillage(Self.maillage(Self.date("2026-09-30T10:00:00Z")))
        let json = String(decoding: try CodageJSON.encodeur().encode(r), as: UTF8.self)
        #expect(json == #"{"date":"2026-09-30T10:00:00.000Z","enfants":[["E0000000000000B1",0,3],["E0000000000000B2",1,null]],"liens":[[0,1,3,2]],"parentSonde":0,"partition":"0000000A","routeurs":[[0,"E0000000000000A0"],[1,null]],"signaux":[[0,-60],[1,-75]]}"#)
        #expect(try CodageJSON.decodeur().decode(ReleveMaillage.self, from: Data(json.utf8)) == r)
        #expect(r.cle(routeur: 0) == "E0000000000000A0")
        #expect(r.cle(routeur: 1) == "rloc:0400", "sans ExtMac : son RLOC16")
    }

    /// Un enfant vu deux fois (il a change de parent) : l'entree fraiche (table d'un routeur qui
    /// repond) passe avant celle du balayage d'un routeur muet, qui peut dater de 30 minutes.
    @Test func enfantVuDeuxFois() {
        var c = ConstructionMaillage(date: Self.date("2026-09-30T10:00:00Z"), partition: "0000000A")
        c.enfant(EnfantMaillage(rloc16: 0x0402, extMac: "E0000000000000B2", source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x0805, extMac: "E0000000000000B2", qualite: 2, source: .tableEnfants))
        let m = c.maillage()
        #expect(m.enfantsIdentifies["E0000000000000B2"]?.parent == 2)
        #expect(ReleveMaillage(m).enfants == [ReleveMaillage.Enfant(extMac: "E0000000000000B2", parent: 2, qualite: 2)])
    }

    /// Tournee de la capture, avec des voisins : 7 routeurs et 10 enfants identifies tiennent en
    /// moins de 700 octets ; avec 20 enfants (26 octets chacun), en moins de 1 Ko.
    @Test func tailleDUneLigne() async throws {
        let voisins = [VoisinSonde(rloc16: "E400", ext: "E0000000000000E4", rssi: -72, lqi: 3, routeur: true),
                       VoisinSonde(rloc16: "CC00", ext: "E0000000000000CC", rssi: -80, lqi: 3, routeur: true)]
        let (m, _) = try #require(try await Tournee.complete(try SondeRejouee.capture(voisins: voisins),
                                                               memoire: MemoireTournee(), maintenant: Self.date("2026-09-30T10:00:00Z")))
        let r = ReleveMaillage(m)
        #expect(r.routeurs.count == 7 && r.liens.count == 7)
        #expect(r.enfants.count == 10, "balayes sous AC00, et les enfants des tables qui ont donne leur identite")
        let octets = try CodageJSON.encodeur().encode(r).count
        #expect(octets < 700, "\(octets) octets")
        var vingt = r.enfants
        for n in 0..<10 { vingt.append(ReleveMaillage.Enfant(extMac: String(format: "E0000000000001%02X", n), parent: 24, qualite: 3)) }
        let grand = ReleveMaillage(date: r.date, partition: r.partition, routeurs: r.routeurs, liens: r.liens, enfants: vingt,
                                   signaux: r.signaux, parentSonde: r.parentSonde)
        #expect(try CodageJSON.encodeur().encode(grand).count < 1024)
    }

    /// Fichiers `maillage-AAAA-MM.jsonl` du dossier de l'app : un releve par ligne, au mois de sa
    /// date (calendrier local) ; relus depuis une date, du plus ancien au plus recent, sans ligne
    /// illisible ; purges 90 jours apres la fin de leur mois ; les autres fichiers du dossier (le
    /// journal, les identites) ne sont ni lus ni purges.
    @Test func fichiersMensuels() throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        let h = HistoriqueFichiers(dossier: d, calendrier: JournalTests.calendrier)
        #expect(try h.lire(depuis: .distantPast).isEmpty, "dossier absent")
        let septembre = ReleveMaillage(Self.maillage(Self.date("2026-09-20T10:00:00Z")))
        let fin = ReleveMaillage(Self.maillage(Self.date("2026-09-30T21:00:00Z")))
        let octobre = ReleveMaillage(Self.maillage(Self.date("2026-10-02T10:00:00Z")))
        for r in [fin, septembre, octobre] { try h.ajouter(r) }
        let f = try FileHandle(forWritingTo: d.appendingPathComponent("maillage-2026-09.jsonl"))
        try f.seekToEnd()
        try f.write(contentsOf: Data("{pas du json\n".utf8))
        try f.close()
        try JournalFichiers(dossier: d, calendrier: JournalTests.calendrier)
            .ajouter([Evenement(date: Self.date("2026-09-10T00:00:00Z"), type: .veille)])
        try Data("{}".utf8).write(to: d.appendingPathComponent("identites-routeurs.json"))
        // 30/09 21:00 UTC = 01/10 01:00 a Asia/Tbilisi : fichier d'octobre.
        #expect(h.nomFichier(fin.date) == "maillage-2026-10.jsonl")
        #expect(try h.lire(depuis: .distantPast) == [septembre, fin, octobre])
        #expect(try h.lire(depuis: Self.date("2026-09-25T00:00:00Z")) == [fin, octobre])
        let supprimes = try h.purger(maintenant: Self.date("2027-01-05T12:00:00Z"))
        #expect(supprimes == ["maillage-2026-09.jsonl"], "septembre fini depuis 96 jours ; le journal reste")
        #expect(try h.lire(depuis: .distantPast) == [fin, octobre])
        let restants = try FileManager.default.contentsOfDirectory(atPath: d.path).sorted()
        #expect(restants == ["identites-routeurs.json", "journal-2026-09.jsonl", "maillage-2026-10.jsonl"])
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/HistoriqueTests MaillageCoeurTests/JournalTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find 'ReleveMaillage' in scope`, `error: value of type 'Maillage' has no member 'enfantsIdentifies'` et `error: cannot find 'HistoriqueFichiers' in scope`.

- [ ] **Step 3 : écrire le code.** Les fichiers mensuels, extraits de `JournalFichiers` ; le journal les utilise, sans changer de comportement :

`MaillageCoeur/Journal/FichiersMensuels.swift` :

```swift
import Foundation

/// Fichiers JSON Lines mensuels d'un dossier ("<prefixe>-2026-09.jsonl", mois du calendrier
/// local) : une ligne par enregistrement, ajoutee a la fin du fichier de son mois ; un fichier
/// est supprime quand son mois est fini depuis plus de 90 jours. Le journal (`journal-…`) et
/// l'historique du maillage (`maillage-…`) en sont faits.
public struct FichiersMensuels: Sendable {
    public static let conservation: TimeInterval = 90 * 24 * 3600

    public let dossier: URL
    public let prefixe: String
    public let calendrier: Calendar

    public init(dossier: URL, prefixe: String, calendrier: Calendar = .current) {
        self.dossier = dossier
        self.prefixe = prefixe
        self.calendrier = calendrier
    }

    /// Nom du fichier du mois d'une date.
    public func nomFichier(_ date: Date) -> String {
        let c = calendrier.dateComponents([.year, .month], from: date)
        return prefixe + String(format: "-%04d-%02d.jsonl", c.year ?? 0, c.month ?? 0)
    }

    /// Ajoute chaque ligne (du JSON, sans fin de ligne) a la fin du fichier du mois de sa date.
    public func ajouter(_ lignes: [(date: Date, json: Data)]) throws {
        guard !lignes.isEmpty else { return }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        for (nom, groupe) in Dictionary(grouping: lignes, by: { nomFichier($0.date) }) {
            var donnees = Data()
            for l in groupe {
                donnees.append(l.json)
                donnees.append(0x0A)
            }
            let url = dossier.appendingPathComponent(nom)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let f = try FileHandle(forWritingTo: url)
            defer { try? f.close() }
            try f.seekToEnd()
            try f.write(contentsOf: donnees)
        }
    }

    /// Lignes non vides des fichiers, dans l'ordre des mois puis des lignes ; `depuis` : seulement
    /// les fichiers des mois qui finissent apres cette date.
    public func lignes(depuis debut: Date? = nil) throws -> [Data] {
        var lignes: [Data] = []
        for url in try fichiers() {
            if let debut, let fin = finDuMois(url.lastPathComponent), fin <= debut { continue }
            let texte = try String(contentsOf: url, encoding: .utf8)
            for l in texte.split(separator: "\n") where !l.isEmpty { lignes.append(Data(l.utf8)) }
        }
        return lignes
    }

    /// Supprime les fichiers des mois finis depuis plus de 90 jours ; rend leurs noms.
    @discardableResult
    public func purger(maintenant: Date) throws -> [String] {
        var supprimes: [String] = []
        for url in try fichiers() {
            guard let fin = finDuMois(url.lastPathComponent),
                  maintenant.timeIntervalSince(fin) > Self.conservation else { continue }
            try FileManager.default.removeItem(at: url)
            supprimes.append(url.lastPathComponent)
        }
        return supprimes
    }

    /// Fichiers de ce prefixe, dans l'ordre des mois.
    func fichiers() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: dossier.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: dossier, includingPropertiesForKeys: nil)
            .filter { finDuMois($0.lastPathComponent) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Debut du mois suivant pour "<prefixe>-AAAA-MM.jsonl", nil pour un autre nom.
    func finDuMois(_ nom: String) -> Date? {
        guard nom.hasPrefix(prefixe + "-") else { return nil }
        let m = nom.dropFirst(prefixe.count + 1).wholeMatch(of: /(\d{4})-(\d{2})\.jsonl/)
        guard let m, let annee = Int(m.output.1), let mois = Int(m.output.2),
              let debut = calendrier.date(from: DateComponents(year: annee, month: mois, day: 1)) else { return nil }
        return calendrier.date(byAdding: .month, value: 1, to: debut)
    }
}
```

`MaillageCoeur/Journal/JournalFichiers.swift`, fichier entier :

```swift
import Foundation

/// Journal sur disque : JSON Lines, un fichier par mois ("journal-2026-09.jsonl",
/// mois du calendrier local), un fichier supprime quand son mois est fini depuis
/// plus de 90 jours (`FichiersMensuels`).
public struct JournalFichiers: Sendable {
    public static let conservation = FichiersMensuels.conservation

    public let dossier: URL
    public let calendrier: Calendar
    private let fichiersMensuels: FichiersMensuels

    public init(dossier: URL, calendrier: Calendar = .current) {
        self.dossier = dossier
        self.calendrier = calendrier
        fichiersMensuels = FichiersMensuels(dossier: dossier, prefixe: "journal", calendrier: calendrier)
    }

    /// Nom du fichier du mois d'une date.
    public func nomFichier(_ date: Date) -> String { fichiersMensuels.nomFichier(date) }

    /// Ajoute les evenements a la fin du fichier de leur mois.
    public func ajouter(_ evenements: [Evenement]) throws {
        let encodeur = CodageJSON.encodeur()
        try fichiersMensuels.ajouter(evenements.map { (date: $0.date, json: try encodeur.encode($0)) })
    }

    /// Tous les evenements gardes, du plus ancien au plus recent ; une ligne
    /// illisible est ignoree.
    public func lire() throws -> [Evenement] {
        let decodeur = CodageJSON.decodeur()
        let tous = try fichiersMensuels.lignes().compactMap { try? decodeur.decode(Evenement.self, from: $0) }
        return tous.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }.map(\.element)
    }

    /// Supprime les fichiers des mois finis depuis plus de 90 jours ; rend leurs noms.
    @discardableResult
    public func purger(maintenant: Date) throws -> [String] {
        try fichiersMensuels.purger(maintenant: maintenant)
    }

    /// Fichiers du journal, dans l'ordre des mois.
    func fichiers() throws -> [URL] { try fichiersMensuels.fichiers() }

    /// Debut du mois suivant pour "journal-AAAA-MM.jsonl", nil pour un autre nom.
    func finDuMois(_ nom: String) -> Date? { fichiersMensuels.finDuMois(nom) }
}
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    /// Identifiant de routeur du parent de la sonde.
    public var parentSonde: Int? { enfants.first { $0.source == .sonde }?.parent }
}
```

par :

```swift
    /// Identifiant de routeur du parent de la sonde.
    public var parentSonde: Int? { enfants.first { $0.source == .sonde }?.parent }

    /// Enfants identifies (ExtMac connue), un par ExtMac. Vu deux fois (il a change de parent),
    /// l'entree fraiche (table d'un routeur qui repond, la sonde) passe avant celle d'un
    /// balayage, qui peut dater de 30 minutes ; a egalite, la premiere par RLOC16.
    public var enfantsIdentifies: [String: EnfantMaillage] {
        var parExtMac: [String: EnfantMaillage] = [:]
        for e in enfants {
            guard let x = e.extMac else { continue }
            if let deja = parExtMac[x], deja.source != .balayage || e.source == .balayage { continue }
            parExtMac[x] = e
        }
        return parExtMac
    }
}
```

`MaillageCoeur/Maillage/HistoriqueMaillage.swift` :

```swift
import Foundation

/// Releve d'une tournee pour l'historique (spec de la sonde, section 6) : la qualite de chaque
/// lien, entre routeurs et d'enfant a parent, et le signal des routeurs que la sonde entend.
/// Une ligne JSON de `maillage-AAAA-MM.jsonl`, en tableaux pour rester courte :
/// - `routeurs` : `[identifiant, ExtMac ou null]`, chaque routeur de la liste ;
/// - `liens` : `[a, b, qualite de a vers b, qualite de b vers a]` (null : inconnue) ;
/// - `enfants` : `[ExtMac, identifiant du parent, qualite ou null]`, les enfants identifies, la
///   sonde comprise. Un enfant sans ExtMac n'a pas d'identite stable (son RLOC16 change avec son
///   parent) : il n'est pas garde ;
/// - `signaux` : `[identifiant, dBm]`, les routeurs que la sonde entend, son parent compris ;
/// - `parentSonde` : identifiant du parent de la sonde (absent sans parent connu).
public struct ReleveMaillage: Hashable, Sendable {
    /// Routeur de la liste et son ExtMac (nil : inconnue).
    public struct Routeur: Hashable, Sendable {
        public let id: Int
        public let extMac: String?

        public init(id: Int, extMac: String?) {
            self.id = id
            self.extMac = extMac
        }
    }

    /// Enfant identifie, son parent et la qualite de son lien (nil sous un routeur muet).
    public struct Enfant: Hashable, Sendable {
        public let extMac: String
        public let parent: Int
        public let qualite: Int?

        public init(extMac: String, parent: Int, qualite: Int?) {
            self.extMac = extMac
            self.parent = parent
            self.qualite = qualite
        }
    }

    public let date: Date
    public let partition: String
    /// Par identifiant croissant.
    public let routeurs: [Routeur]
    public let liens: [LienRadio]
    /// Par ExtMac croissante.
    public let enfants: [Enfant]
    public let signaux: [SignalSonde]
    public let parentSonde: Int?

    public init(date: Date, partition: String, routeurs: [Routeur], liens: [LienRadio], enfants: [Enfant],
                signaux: [SignalSonde], parentSonde: Int?) {
        self.date = date
        self.partition = partition
        self.routeurs = routeurs
        self.liens = liens
        self.enfants = enfants
        self.signaux = signaux
        self.parentSonde = parentSonde
    }

    /// Releve d'un maillage : ses enfants identifies (`Maillage.enfantsIdentifies`).
    public init(_ m: Maillage) {
        self.init(date: m.date, partition: m.partition,
                  routeurs: m.routeurs.map { Routeur(id: $0.id, extMac: $0.extMac) },
                  liens: m.liens,
                  enfants: m.enfantsIdentifies.sorted { $0.key < $1.key }
                      .map { Enfant(extMac: $0.key, parent: $0.value.parent, qualite: $0.value.qualite) },
                  signaux: m.signaux, parentSonde: m.parentSonde)
    }

    /// Cle d'un routeur du releve : son ExtMac, sinon "rloc:XXXX" (valable dans sa partition).
    public func cle(routeur id: Int) -> String {
        routeurs.first { $0.id == id }?.extMac ?? String(format: "rloc:%04X", UInt16(id) << 10)
    }
}

extension ReleveMaillage: Codable {
    private enum CodingKeys: String, CodingKey {
        case date, partition, routeurs, liens, enfants, signaux, parentSonde
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var routeurs: [Routeur] = []
        var r = try c.nestedUnkeyedContainer(forKey: .routeurs)
        while !r.isAtEnd {
            var l = try r.nestedUnkeyedContainer()
            routeurs.append(Routeur(id: try l.decode(Int.self), extMac: try l.decodeIfPresent(String.self)))
        }
        var liens: [LienRadio] = []
        var li = try c.nestedUnkeyedContainer(forKey: .liens)
        while !li.isAtEnd {
            var l = try li.nestedUnkeyedContainer()
            liens.append(LienRadio(a: try l.decode(Int.self), b: try l.decode(Int.self),
                                   qualiteAB: try l.decodeIfPresent(Int.self), qualiteBA: try l.decodeIfPresent(Int.self)))
        }
        var enfants: [Enfant] = []
        var e = try c.nestedUnkeyedContainer(forKey: .enfants)
        while !e.isAtEnd {
            var l = try e.nestedUnkeyedContainer()
            enfants.append(Enfant(extMac: try l.decode(String.self), parent: try l.decode(Int.self),
                                  qualite: try l.decodeIfPresent(Int.self)))
        }
        var signaux: [SignalSonde] = []
        var s = try c.nestedUnkeyedContainer(forKey: .signaux)
        while !s.isAtEnd {
            var l = try s.nestedUnkeyedContainer()
            signaux.append(SignalSonde(routeur: try l.decode(Int.self), rssi: try l.decode(Int.self)))
        }
        self.init(date: try c.decode(Date.self, forKey: .date), partition: try c.decode(String.self, forKey: .partition),
                  routeurs: routeurs, liens: liens, enfants: enfants, signaux: signaux,
                  parentSonde: try c.decodeIfPresent(Int.self, forKey: .parentSonde))
    }

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
    }
}

private extension UnkeyedEncodingContainer {
    /// La valeur, ou null.
    mutating func encodeOuNul<T: Encodable>(_ v: T?) throws {
        if let v { try encode(v) } else { try encodeNil() }
    }
}

/// Historique des tournees sur disque (spec de la sonde, section 6) : JSON Lines mensuel
/// (`maillage-AAAA-MM.jsonl`) dans le dossier de l'app, garde 90 jours comme le journal.
public struct HistoriqueFichiers: Sendable {
    private let fichiers: FichiersMensuels

    public init(dossier: URL, calendrier: Calendar = .current) {
        fichiers = FichiersMensuels(dossier: dossier, prefixe: "maillage", calendrier: calendrier)
    }

    /// Nom du fichier du mois d'une date (« maillage-2026-09.jsonl »).
    public func nomFichier(_ date: Date) -> String { fichiers.nomFichier(date) }

    /// Ajoute le releve a la fin du fichier de son mois.
    public func ajouter(_ r: ReleveMaillage) throws {
        try fichiers.ajouter([(date: r.date, json: try CodageJSON.encodeur().encode(r))])
    }

    /// Releves dates de `debut` ou apres, du plus ancien au plus recent ; seuls les fichiers des
    /// mois qui finissent apres `debut` sont lus. Une ligne illisible est ignoree.
    public func lire(depuis debut: Date) throws -> [ReleveMaillage] {
        let decodeur = CodageJSON.decodeur()
        return try fichiers.lignes(depuis: debut)
            .compactMap { try? decodeur.decode(ReleveMaillage.self, from: $0) }
            .filter { $0.date >= debut }
            .sorted { $0.date < $1.date }
    }

    /// Supprime les fichiers des mois finis depuis plus de 90 jours ; rend leurs noms.
    @discardableResult
    public func purger(maintenant: Date) throws -> [String] {
        try fichiers.purger(maintenant: maintenant)
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/HistoriqueTests MaillageCoeurTests/JournalTests`
Expected: `Test run with 7 tests in 2 suites passed` (`HistoriqueTests` : 4, `JournalTests` : 3, inchangé), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement ; 4 tests et 1 suite de plus pour le cœur, l'app inchangée (au rejeu : 236 tests en 22 suites, et 220 en 25 suites).

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Journal/FichiersMensuels.swift MaillageCoeur/Journal/JournalFichiers.swift MaillageCoeur/Maillage/Maillage.swift MaillageCoeur/Maillage/HistoriqueMaillage.swift MaillageCoeurTests/HistoriqueTests.swift
git commit -m "Ecrire l'historique des tournees en fichiers mensuels

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Journal des parents et des routeurs Thread

**Files:**
- Create: `MaillageCoeur/Maillage/SuiviMaillage.swift`
- Modify: `MaillageCoeur/Suivi/Evenement.swift`, `MaillageThread/Surveillance/TexteEvenement.swift`, `MaillageThread/Vues/Journal/FenetreJournal.swift` (blocs ci-dessous), `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` (Step 4)
- Test: `MaillageCoeurTests/SuiviMaillageTests.swift` ; `MaillageThreadTests/TexteEvenementTests.swift`, `MaillageThreadTests/JournalVueTests.swift` (blocs ci-dessous)

**Interfaces:**
- Consumes : `Maillage.enfantsIdentifies` (tâche 5), `RouteurMaillage` (`bordure`, `muet`, `extMac`), `Sujet`, `Evenement`, `Alertes` (tout type non prévu y part en `.informations`, la catégorie « Autres changements », décochée par défaut).
- Produces :
  - `TypeEvenement.parentChange`, `.sansParent`, `.routeurThreadApparu`, `.routeurThreadDisparu` ; gravité « attention » pour `.sansParent` et `.routeurThreadDisparu`, « info » pour les deux autres ;
  - `SujetsMaillage` (`routeurs: [Int: Sujet]`, `enfants: [UInt16: Sujet]`) : le nom de chaque nœud, donné par l'app ;
  - `SuiviMaillage` : `integrer(_ m: Maillage, sujets: SujetsMaillage) -> [Evenement]`, `absencesAvantPerte` (2) ; un changement de parent porte `sujet` (l'enfant), `avant` et `apres` (les noms des deux parents) ; « sans parent », `avant` (le dernier parent) ;
  - `TexteEvenement.titre` pour les quatre types ; `FamilleEvenement.maillage` (« Maillage »).

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/SuiviMaillageTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Suivi du maillage : journal des parents et des routeurs Thread")
struct SuiviMaillageTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    /// Enfant d'un maillage de test : RLOC16, ExtMac (nil : non identifie), source.
    struct Enfant {
        let rloc16: UInt16
        let ext: String?
        var source: SourceEnfant = .tableEnfants
    }

    /// Maillage de la partition 0000000A a `minutes` de t0 (valeurs inventees) : le chef 0 (routeur
    /// de bordure), et les routeurs 1 et 2 par defaut ; `muets` ; ExtMac des routeurs `routeursExt`.
    static func maillage(_ minutes: Double, routeurs: [Int] = [0, 1, 2], bordures: Set<Int> = [0], muets: Set<Int> = [],
                         routeursExt: [Int: String] = [:], enfants: [Enfant], partition: String = "0000000A") -> Maillage {
        var c = ConstructionMaillage(date: t0.addingTimeInterval(minutes * 60), partition: partition)
        c.routeurs(Route64(sequence: 1, routes: routeurs.map { RouteRouteur(idRouteur: $0, qualiteSortante: 0, qualiteEntrante: 0, cout: 1) }),
                   chef: routeurs[0])
        for id in routeurs where bordures.contains(id) { c.marquer(id, bordure: true) }
        for id in muets { c.muet(id) }
        for (id, ext) in routeursExt { c.identite(ext, routeur: id) }
        for e in enfants {
            c.enfant(EnfantMaillage(rloc16: e.rloc16, extMac: e.ext, qualite: e.source == .balayage ? nil : 3, source: e.source))
        }
        return c.maillage()
    }

    /// Noms des noeuds : « R<id> » pour un routeur, « N-<ExtMac> » pour un enfant.
    static func sujets(_ m: Maillage) -> SujetsMaillage {
        var s = SujetsMaillage()
        for r in m.routeurs { s.routeurs[r.id] = Sujet(id: "r\(r.id)", nom: "R\(r.id)") }
        for e in m.enfants { s.enfants[e.rloc16] = Sujet(id: e.extMac ?? "?", nom: "N-" + (e.extMac ?? "?")) }
        return s
    }

    /// Integre les maillages dans l'ordre ; les evenements de chacun.
    static func suivre(_ maillages: [Maillage]) -> [[Evenement]] {
        var suivi = SuiviMaillage()
        return maillages.map { suivi.integrer($0, sujets: sujets($0)) }
    }

    static let b1 = "E0000000000000B1"

    /// Le premier maillage est un point de depart ; le meme ensuite ne dit rien.
    @Test func pointDeDepart() {
        let m = Self.maillage(0, enfants: [Enfant(rloc16: 0x0401, ext: Self.b1)])
        #expect(Self.suivre([m, m]) == [[], []])
    }

    /// Un enfant identifie passe du routeur 1 au 2 : « a change de parent », date de la tournee.
    /// Un enfant sans ExtMac n'est pas suivi.
    @Test func changementDeParent() throws {
        let ev = Self.suivre([Self.maillage(0, enfants: [Enfant(rloc16: 0x0401, ext: Self.b1), Enfant(rloc16: 0x0403, ext: nil)]),
                              Self.maillage(5, enfants: [Enfant(rloc16: 0x0802, ext: Self.b1), Enfant(rloc16: 0x0804, ext: nil)])])
        #expect(ev[1].count == 1)
        let e = try #require(ev[1].first)
        #expect(e.type == .parentChange && e.gravite == .info)
        #expect(e.sujet == Sujet(id: Self.b1, nom: "N-" + Self.b1))
        #expect(e.avant == "R1" && e.apres == "R2")
        #expect(e.date == Self.t0.addingTimeInterval(300))
    }

    /// Absent sous un parent qui repond : « n'a plus de parent » a la seconde absence, une seule
    /// fois ; revu sous un autre parent : « a change de parent » depuis le dernier connu.
    @Test func sansParentApresDeuxAbsences() {
        let present = Self.maillage(0, enfants: [Enfant(rloc16: 0x0401, ext: Self.b1)])
        let absent = { (minutes: Double) in Self.maillage(minutes, enfants: []) }
        let ev = Self.suivre([present, absent(5), absent(10), absent(15),
                              Self.maillage(20, enfants: [Enfant(rloc16: 0x0802, ext: Self.b1)])])
        #expect(ev[1].isEmpty, "une absence : on attend")
        #expect(ev[2].map(\.type) == [.sansParent])
        #expect(ev[2].first?.avant == "R1")
        #expect(ev[2].first?.gravite == .attention)
        #expect(ev[3].isEmpty, "pas de seconde fois")
        #expect(ev[4].map(\.type) == [.parentChange])
        #expect(ev[4].first?.avant == "R1" && ev[4].first?.apres == "R2")
    }

    /// Revu entre deux absences : le compte repart de zero.
    @Test func absencesDeSuite() {
        let present = Self.maillage(0, enfants: [Enfant(rloc16: 0x0401, ext: Self.b1)])
        let ev = Self.suivre([present, Self.maillage(5, enfants: []), present, Self.maillage(15, enfants: [])])
        #expect(ev.allSatisfy { $0.isEmpty })
    }

    /// Enfant lu dans la table d'un routeur qui se tait ensuite : son absence ne dit rien (le
    /// routeur n'a pas ete interroge). Enfant balaye sous un routeur muet : absent, c'est qu'un
    /// nouveau balayage ne l'a pas trouve.
    @Test func absenceSousUnRouteurMuet() {
        let b2 = "E0000000000000B2"
        let ev = Self.suivre([
            Self.maillage(0, muets: [2], enfants: [Enfant(rloc16: 0x0401, ext: Self.b1),
                                                     Enfant(rloc16: 0x0805, ext: b2, source: .balayage)]),
            Self.maillage(5, muets: [1, 2], enfants: []),
            Self.maillage(10, muets: [1, 2], enfants: []),
        ])
        #expect(ev[2].map(\.type) == [.sansParent])
        #expect(ev[2].first?.sujet?.id == b2)
    }

    /// Parent sorti de la liste des routeurs : son enfant est sans parent a la seconde tournee.
    @Test func parentDisparu() {
        let ev = Self.suivre([Self.maillage(0, enfants: [Enfant(rloc16: 0x0401, ext: Self.b1)]),
                              Self.maillage(5, routeurs: [0, 2], enfants: []),
                              Self.maillage(10, routeurs: [0, 2], enfants: [])])
        #expect(ev[1].map(\.type) == [.routeurThreadDisparu])
        #expect(ev[2].map(\.type) == [.sansParent])
    }

    /// Routeurs hors routeurs de bordure : entree (3) et sortie (2) de la liste, nommes par leur
    /// derniere tournee ; un routeur de bordure (0) qui sort ne dit rien ici (le journal des
    /// annonces le dit).
    @Test func routeursThread() {
        let ev = Self.suivre([Self.maillage(0, enfants: []),
                              Self.maillage(5, routeurs: [1, 3], bordures: [], enfants: [])])
        #expect(ev[1].map(\.type) == [.routeurThreadApparu, .routeurThreadDisparu])
        #expect(ev[1].map { $0.sujet?.nom } == ["R3", "R2"])
        #expect(ev[1].map(\.gravite) == [.info, .attention])
    }

    /// La sonde n'est jamais « sans parent » ; son changement de parent est note.
    @Test func sonde() {
        let sonde = { (minutes: Double, rloc: UInt16) in
            Self.maillage(minutes, enfants: [Enfant(rloc16: rloc, ext: "E0000000000000C1", source: .sonde)])
        }
        let ev = Self.suivre([sonde(0, 0x0401), Self.maillage(5, enfants: []), Self.maillage(10, enfants: []),
                              sonde(15, 0x0801)])
        #expect(ev[1].isEmpty && ev[2].isEmpty)
        #expect(ev[3].map(\.type) == [.parentChange])
    }

    /// Enfant devenu routeur : son ExtMac est celle d'un routeur de la liste ; il n'est pas « sans
    /// parent », le routeur apparait.
    @Test func enfantDevenuRouteur() {
        let ev = Self.suivre([Self.maillage(0, enfants: [Enfant(rloc16: 0x0401, ext: Self.b1)]),
                              Self.maillage(5, routeurs: [0, 1, 2, 3], routeursExt: [3: Self.b1], enfants: []),
                              Self.maillage(10, routeurs: [0, 1, 2, 3], routeursExt: [3: Self.b1], enfants: [])])
        #expect(ev[1].map(\.type) == [.routeurThreadApparu])
        #expect(ev[2].isEmpty)
    }

    /// Autre partition : les identifiants de routeur y sont redistribues ; nouveau point de depart.
    @Test func autrePartition() {
        let ev = Self.suivre([Self.maillage(0, enfants: [Enfant(rloc16: 0x0401, ext: Self.b1)]),
                              Self.maillage(5, routeurs: [5, 6], enfants: [Enfant(rloc16: 0x1801, ext: Self.b1)],
                                            partition: "0000000B")])
        #expect(ev[1].isEmpty)
    }

    /// Aucune notification par defaut : ces evenements relevent de « Autres changements ».
    @Test func autresChangements() {
        var a = Alertes()
        let ev = [TypeEvenement.parentChange, .sansParent, .routeurThreadApparu, .routeurThreadDisparu].map {
            Evenement(date: Self.t0, type: $0, sujet: Sujet(id: Self.b1, nom: "Prise"))
        }
        #expect(a.traiter(ev).map(\.categorie) == Array(repeating: .informations, count: 4))
        #expect(!CategorieAlerte.informations.parDefaut)
    }
}
```

Dans `MaillageThreadTests/TexteEvenementTests.swift`, remplacer :

```swift
    /// Point de depart d'un reseau vu apres le lancement : le reseau est nomme.
```

par :

```swift
    /// Evenements du maillage de la sonde : les attentes reprennent les cles du code
    /// (independantes de la langue de l'hote).
    @Test func maillage() {
        let t = ScenarioPanne.date(4, 14)
        let s = Sujet(id: "56B1E064401F74EF", nom: "Prise bureau")
        let change = Evenement(date: t, type: .parentChange, sujet: s, avant: "HomePod salon", apres: "Routeur · 5000")
        #expect(TexteEvenement.titre(change)
                == String(localized: "\("Prise bureau") a changé de parent : \("HomePod salon") → \("Routeur · 5000")"))
        #expect(TexteEvenement.titre(Evenement(date: t, type: .sansParent, sujet: s, avant: "HomePod salon"))
                == String(localized: "\("Prise bureau") n'a plus de parent"))
        #expect(TexteEvenement.titre(Evenement(date: t, type: .routeurThreadApparu, sujet: s))
                == String(localized: "Routeur Thread apparu : \("Prise bureau")"))
        #expect(TexteEvenement.titre(Evenement(date: t, type: .routeurThreadDisparu, sujet: s))
                == String(localized: "Routeur Thread disparu : \("Prise bureau")"))
    }

    /// Point de depart d'un reseau vu apres le lancement : le reseau est nomme.
```

Dans `MaillageThreadTests/JournalVueTests.swift`, remplacer :

```swift
        #expect(FamilleEvenement.reseau.contient(.veille))
        #expect(!FamilleEvenement.routeurs.contient(.appareilDisparu))
    }
```

par :

```swift
        #expect(FamilleEvenement.reseau.contient(.veille))
        #expect(!FamilleEvenement.routeurs.contient(.appareilDisparu))
    }

    /// Les evenements du maillage de la sonde ont leur famille, « Maillage », et elle seule.
    @Test func familleMaillage() {
        for t in [TypeEvenement.parentChange, .sansParent, .routeurThreadApparu, .routeurThreadDisparu] {
            #expect(FamilleEvenement.allCases.filter { $0 != .toutes && $0.contient(t) } == [.maillage], "\(t)")
        }
    }
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/SuiviMaillageTests MaillageThreadTests/TexteEvenementTests MaillageThreadTests/JournalVueTests`
Expected: la compilation échoue, par exemple avec `error: cannot find type 'SujetsMaillage' in scope`, `error: cannot find 'SuiviMaillage' in scope` et `error: type 'TypeEvenement' has no member 'parentChange'`.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageCoeur/Suivi/Evenement.swift`, remplacer :

```swift
    case appareilNouveau, appareilDisparu, appareilRevenu, appareilSansAdresse, appareilChangePartition
```

par :

```swift
    case appareilNouveau, appareilDisparu, appareilRevenu, appareilSansAdresse, appareilChangePartition
    // Maillage de la sonde : un enfant change de parent ou n'en a plus ; un routeur Thread (hors
    // routeurs de bordure) entre dans la liste des routeurs ou en sort
    case parentChange, sansParent, routeurThreadApparu, routeurThreadDisparu
```

Dans `MaillageCoeur/Suivi/Evenement.swift`, remplacer :

```swift
             .appareilDisparu, .appareilSansAdresse, .appareilChangePartition:
```

par :

```swift
             .appareilDisparu, .appareilSansAdresse, .appareilChangePartition, .sansParent, .routeurThreadDisparu:
```

`MaillageCoeur/Maillage/SuiviMaillage.swift` :

```swift
import Foundation

/// Noeuds d'un maillage tels que le journal les nomme (id du noeud dans le graphe et nom
/// affiche), donnes par l'app a chaque tournee : les routeurs par identifiant, les enfants par
/// RLOC16.
public struct SujetsMaillage: Sendable {
    public var routeurs: [Int: Sujet]
    public var enfants: [UInt16: Sujet]

    public init(routeurs: [Int: Sujet] = [:], enfants: [UInt16: Sujet] = [:]) {
        self.routeurs = routeurs
        self.enfants = enfants
    }
}

/// Suit le maillage de la sonde de tournee en tournee et en tire les evenements du journal (spec
/// de la sonde, section 6), tous de la categorie « Autres changements » (pas de notification par
/// defaut) :
/// - un enfant identifie (ExtMac) vu sous un autre parent : « X a change de parent : A → B ». Un
///   enfant sans ExtMac n'est pas suivi : son RLOC16 change avec son parent ;
/// - un enfant identifie absent de deux tournees ou son absence est sure : « X n'a plus de
///   parent ». Elle l'est si son dernier parent a repondu (sa table des enfants est fraiche), s'il
///   a quitte la liste des routeurs, ou si l'enfant venait d'un balayage (un routeur muet garde
///   ses enfants balayes jusqu'au balayage suivant). Sous un parent qui s'est tu sans etre
///   balaye, on ne sait pas. La sonde n'est jamais « sans parent » (detachee, elle ne rend pas de
///   maillage), ni un enfant devenu routeur ;
/// - un routeur hors routeurs de bordure qui entre dans la liste des routeurs, ou en sort.
/// Le premier maillage, et le premier d'une autre partition (les identifiants de routeur y sont
/// redistribues), sont un point de depart : aucun evenement.
public struct SuiviMaillage: Sendable {
    /// Absences sures avant « n'a plus de parent ».
    public static let absencesAvantPerte = 2

    private struct EtatEnfant: Sendable {
        var parent: Int
        var nomParent: String
        var sujet: Sujet
        var source: SourceEnfant
        var absences = 0
        var perdu = false
    }

    private struct EtatRouteur: Sendable {
        var bordure: Bool
        var sujet: Sujet
    }

    private var partition: String?
    /// Enfants identifies, par ExtMac.
    private var enfants: [String: EtatEnfant] = [:]
    /// Routeurs de la derniere tournee, par identifiant.
    private var routeurs: [Int: EtatRouteur] = [:]

    public init() {}

    /// Evenements du maillage d'une tournee, dates du debut de la tournee (`Maillage.date`).
    public mutating func integrer(_ m: Maillage, sujets: SujetsMaillage) -> [Evenement] {
        func sujet(routeur id: Int) -> Sujet {
            let rloc = String(format: "%04X", UInt16(id) << 10)
            return sujets.routeurs[id] ?? Sujet(id: "rloc:" + rloc, nom: rloc)
        }
        var ev: [Evenement] = []
        if partition == m.partition {
            let ids = Set(m.routeurs.map(\.id))
            for r in m.routeurs where routeurs[r.id] == nil && !r.bordure {
                ev.append(Evenement(date: m.date, type: .routeurThreadApparu, sujet: sujet(routeur: r.id)))
            }
            for (id, r) in routeurs.sorted(by: { $0.key < $1.key }) where !ids.contains(id) && !r.bordure {
                ev.append(Evenement(date: m.date, type: .routeurThreadDisparu, sujet: r.sujet))
            }
        } else {
            partition = m.partition
            enfants = [:]
        }
        let presents = m.enfantsIdentifies
        for (ext, e) in presents.sorted(by: { $0.key < $1.key }) {
            let parent = sujet(routeur: e.parent)
            let s = sujets.enfants[e.rloc16] ?? Sujet(id: String(format: "rloc:%04X", e.rloc16), nom: ext)
            if let avant = enfants[ext], avant.parent != e.parent {
                ev.append(Evenement(date: m.date, type: .parentChange, sujet: s, avant: avant.nomParent, apres: parent.nom))
            }
            enfants[ext] = EtatEnfant(parent: e.parent, nomParent: parent.nom, sujet: s, source: e.source)
        }
        let parId = Dictionary(m.routeurs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let routeursExt = Set(m.routeurs.compactMap(\.extMac))
        for (ext, var e) in enfants.sorted(by: { $0.key < $1.key }) where presents[ext] == nil && !e.perdu {
            if routeursExt.contains(ext) {
                // Devenu routeur : son entree est dans la liste des routeurs.
                enfants[ext] = nil
                continue
            }
            let parent = parId[e.parent]
            guard e.source != .sonde, parent == nil || parent?.muet == false || e.source == .balayage else { continue }
            e.absences += 1
            if e.absences >= Self.absencesAvantPerte {
                e.perdu = true
                ev.append(Evenement(date: m.date, type: .sansParent, sujet: e.sujet, avant: e.nomParent))
            }
            enfants[ext] = e
        }
        routeurs = Dictionary(m.routeurs.map { ($0.id, EtatRouteur(bordure: $0.bordure, sujet: sujet(routeur: $0.id))) },
                              uniquingKeysWith: { a, _ in a })
        return ev
    }
}
```

Dans `MaillageThread/Surveillance/TexteEvenement.swift`, remplacer :

```swift
            return String(localized: "\(nom) a rejoint la partition \(apres)")
        }
    }
```

par :

```swift
            return String(localized: "\(nom) a rejoint la partition \(apres)")
        case .parentChange:
            return String(localized: "\(nom) a changé de parent : \(avant) → \(apres)")
        case .sansParent:
            return String(localized: "\(nom) n'a plus de parent")
        case .routeurThreadApparu:
            return String(localized: "Routeur Thread apparu : \(nom)")
        case .routeurThreadDisparu:
            return String(localized: "Routeur Thread disparu : \(nom)")
        }
    }
```

Dans `MaillageThread/Vues/Journal/FenetreJournal.swift`, remplacer :

```swift
    case toutes, reseau, routeurs, prefixes, appareils
```

par :

```swift
    case toutes, reseau, routeurs, prefixes, appareils, maillage
```

Dans `MaillageThread/Vues/Journal/FenetreJournal.swift`, remplacer :

```swift
        case .appareils: String(localized: "Appareils")
        }
```

par :

```swift
        case .appareils: String(localized: "Appareils")
        case .maillage: String(localized: "Maillage")
        }
```

Dans `MaillageThread/Vues/Journal/FenetreJournal.swift`, remplacer :

```swift
            [.appareilNouveau, .appareilDisparu, .appareilRevenu, .appareilSansAdresse, .appareilChangePartition].contains(t)
        }
```

par :

```swift
            [.appareilNouveau, .appareilDisparu, .appareilRevenu, .appareilSansAdresse, .appareilChangePartition].contains(t)
        case .maillage:
            [.parentChange, .sansParent, .routeurThreadApparu, .routeurThreadDisparu].contains(t)
        }
```

- [ ] **Step 4 : textes, en français et en anglais.** Compiler, puis ajouter au catalogue les clés que le compilateur a extraites :

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/SuiviMaillageTests MaillageThreadTests/TexteEvenementTests MaillageThreadTests/JournalVueTests
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" outils/synchroniser-textes.sh
```

Expected : `** TEST SUCCEEDED **` (ces cibles n'incluent pas `CataloguesTests`) ; `Localizable.xcstrings` reçoit exactement ces 5 clés : « %@ a changé de parent : %@ → %@ », « %@ n'a plus de parent », « Maillage », « Routeur Thread apparu : %@ », « Routeur Thread disparu : %@ ».

Puis les traductions, par ce script qui garde `interface.json` trié et au format de l'outil, et le catalogue :

```bash
python3 - <<'EOF'
import json
f = 'outils/traductions/interface.json'
d = json.load(open(f, encoding='utf-8'))
d.update({
    "%@ a changé de parent : %@ → %@": "%1$@ changed parent: %2$@ → %3$@",
    "%@ n'a plus de parent": "%@ has no parent anymore",
    "Routeur Thread apparu : %@": "Thread router appeared: %@",
    "Routeur Thread disparu : %@": "Thread router disappeared: %@",
    "Maillage": "Mesh",
})
open(f, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

- [ ] **Step 5 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/SuiviMaillageTests MaillageThreadTests/TexteEvenementTests MaillageThreadTests/JournalVueTests`
Expected: `Test run with 11 tests in 1 suite passed` (cœur, `SuiviMaillageTests`) et `Test run with 6 tests in 2 suites passed` (app : `TexteEvenementTests` 4, `JournalVueTests` 2), `** TEST SUCCEEDED **`.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement, `CataloguesTests` compris ; 11 tests et 1 suite de plus pour le cœur, 2 tests pour l'app (au rejeu : 247 tests en 23 suites, et 222 en 25 suites).

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Suivi/Evenement.swift MaillageCoeur/Maillage/SuiviMaillage.swift MaillageThread/Surveillance/TexteEvenement.swift MaillageThread/Vues/Journal/FenetreJournal.swift MaillageCoeurTests/SuiviMaillageTests.swift MaillageThreadTests/TexteEvenementTests.swift MaillageThreadTests/JournalVueTests.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Noter au journal les changements de parent et les routeurs Thread

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: Journal : changements de parent regroupés

**Files:**
- Modify: `MaillageCoeur/Suivi/Regroupement.swift`, `MaillageThread/Surveillance/TexteEvenement.swift`, `MaillageThread/Vues/Journal/FenetreJournal.swift` (blocs ci-dessous), `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` (Step 4)
- Test: `MaillageCoeurTests/RegroupementParentsTests.swift` ; `MaillageThreadTests/TexteEvenementTests.swift` (bloc ci-dessous) ; `MaillageCoeurTests/ScenarioPanneTests.swift` passe sans changement (les pertes restent regroupées comme avant)

**Interfaces:**
- Consumes : `TypeEvenement.parentChange` (tâche 6).
- Produces :
  - `LigneJournal.parents([Evenement])` (au moins 2 changements de parent d'un même nœud en 1 h) ; `id` (`"parents-…"`), `date` (le plus récent) et `evenements` le traitent comme `.pertes` ;
  - `Regroupement.fenetreParents` (3600 s) ;
  - `TexteEvenement.titre(_ l: LigneJournal)` : « X a changé n fois de parent en 1 h » ; `LigneJournalVue` : la ligne se déplie sur chaque changement, comme les pertes. Le menu (`MenuBarre`) et le filtre du journal lisent `titre(_:)` et `evenements` : rien à y changer.

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/RegroupementParentsTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Journal : changements de parent regroupes")
struct RegroupementParentsTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    static func parent(_ minutes: Double, _ noeud: String) -> Evenement {
        Evenement(date: t0.addingTimeInterval(minutes * 60), type: .parentChange, sujet: Sujet(id: noeud, nom: noeud),
                  avant: "A", apres: "B")
    }

    /// Changements de parent d'un meme noeud dans une fenetre de 1 h, comptee depuis le premier :
    /// une ligne ; seul dans sa fenetre, il reste une ligne a lui ; un autre noeud a les siennes.
    @Test func uneLigneParNoeudEtParHeure() throws {
        let lignes = Regroupement.lignes([Self.parent(0, "x"), Self.parent(10, "x"), Self.parent(20, "y"),
                                          Self.parent(50, "x"), Self.parent(59, "x"), Self.parent(70, "x")])
        try #require(lignes.map(\.evenements.count) == [1, 4, 1], "la plus recente d'abord : x a 70 min, x, y")
        guard case .parents(let groupe) = lignes[1] else {
            Issue.record("les 4 changements de x dans l'heure regroupes")
            return
        }
        #expect(groupe.map(\.date) == [0.0, 10, 50, 59].map { Self.t0.addingTimeInterval($0 * 60) })
        #expect(lignes[1].date == Self.t0.addingTimeInterval(59 * 60), "date du plus recent")
        #expect(lignes[1].id.hasPrefix("parents-"))
        #expect(lignes[0].evenements.first?.date == Self.t0.addingTimeInterval(70 * 60), "70 min : une autre fenetre")
        #expect(lignes[2].evenements.first?.sujet?.id == "y")
    }

    /// Les pertes restent regroupees a part, et les autres evenements passent tels quels.
    @Test func pertesInchangees() {
        let perte = { (minutes: Double, id: String) in
            Evenement(date: Self.t0.addingTimeInterval(minutes * 60), type: .appareilDisparu, sujet: Sujet(id: id, nom: id))
        }
        let lignes = Regroupement.lignes([perte(0, "a"), Self.parent(1, "x"), perte(2, "b"), Self.parent(3, "x"),
                                          Evenement(date: Self.t0.addingTimeInterval(240), type: .sansParent)])
        #expect(lignes.count == 3)
        #expect(lignes.contains { if case .pertes(let p) = $0 { p.count == 2 } else { false } })
        #expect(lignes.contains { if case .parents(let p) = $0 { p.count == 2 } else { false } })
    }
}
```

Dans `MaillageThreadTests/TexteEvenementTests.swift`, remplacer :

```swift
    /// Point de depart d'un reseau vu apres le lancement : le reseau est nomme.
```

par :

```swift
    /// Changements de parent regroupes : le noeud, et leur nombre dans l'heure.
    @Test func parentsRegroupes() {
        let change = Evenement(date: ScenarioPanne.date(4, 14), type: .parentChange,
                               sujet: Sujet(id: "56B1E064401F74EF", nom: "Prise bureau"), avant: "A", apres: "B")
        let n = 4
        #expect(TexteEvenement.titre(LigneJournal.parents(Array(repeating: change, count: n)))
                == String(localized: "\("Prise bureau") a changé \(n) fois de parent en 1 h"))
    }

    /// Point de depart d'un reseau vu apres le lancement : le reseau est nomme.
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/RegroupementParentsTests MaillageCoeurTests/ScenarioPanneTests MaillageThreadTests/TexteEvenementTests`
Expected: la compilation échoue, par exemple avec `error: type 'LigneJournal' has no member 'parents'`.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageCoeur/Suivi/Regroupement.swift`, remplacer :

```swift
/// Ligne du journal affiche : un evenement, ou des pertes regroupees.
public enum LigneJournal: Hashable, Sendable, Identifiable {
    case evenement(Evenement)
    /// Au moins 2 pertes dans une meme fenetre de 10 min, de la plus ancienne a la plus recente.
    case pertes([Evenement])

    public var id: String {
        switch self {
        case .evenement(let e): e.id
        case .pertes(let l): "pertes-" + (l.first?.id ?? "")
        }
    }

    /// Date de l'evenement, ou de la plus recente des pertes.
    public var date: Date {
        switch self {
        case .evenement(let e): e.date
        case .pertes(let l): l.last?.date ?? .distantPast
        }
    }

    public var evenements: [Evenement] {
        switch self {
        case .evenement(let e): [e]
        case .pertes(let l): l
        }
    }
```

par :

```swift
/// Ligne du journal affiche : un evenement, des pertes regroupees, ou les changements de parent
/// repetes d'un meme noeud.
public enum LigneJournal: Hashable, Sendable, Identifiable {
    case evenement(Evenement)
    /// Au moins 2 pertes dans une meme fenetre de 10 min, de la plus ancienne a la plus recente.
    case pertes([Evenement])
    /// Au moins 2 changements de parent d'un meme noeud dans une fenetre de 1 h, du plus ancien
    /// au plus recent.
    case parents([Evenement])

    public var id: String {
        switch self {
        case .evenement(let e): e.id
        case .pertes(let l): "pertes-" + (l.first?.id ?? "")
        case .parents(let l): "parents-" + (l.first?.id ?? "")
        }
    }

    /// Date de l'evenement, ou du plus recent du groupe.
    public var date: Date {
        switch self {
        case .evenement(let e): e.date
        case .pertes(let l), .parents(let l): l.last?.date ?? .distantPast
        }
    }

    public var evenements: [Evenement] {
        switch self {
        case .evenement(let e): [e]
        case .pertes(let l), .parents(let l): l
        }
    }
```

Dans `MaillageCoeur/Suivi/Regroupement.swift`, remplacer :

```swift
/// Regroupement des pertes pour l'affichage (le journal garde chaque evenement).
public enum Regroupement {
    /// Fenetre de regroupement, comptee depuis la premiere perte.
    public static let fenetre: TimeInterval = 600
```

par :

```swift
/// Regroupement des pertes et des changements de parent pour l'affichage (le journal garde
/// chaque evenement).
public enum Regroupement {
    /// Fenetre de regroupement, comptee depuis la premiere perte.
    public static let fenetre: TimeInterval = 600
    /// Fenetre des changements de parent d'un meme noeud, comptee depuis le premier (spec de la
    /// sonde, section 6 : « X a change 4 fois de parent en 1 h »).
    public static let fenetreParents: TimeInterval = 3600
```

Dans `MaillageCoeur/Suivi/Regroupement.swift`, remplacer :

```swift
    /// Lignes du journal, les plus recentes d'abord : les pertes survenues dans
    /// une meme fenetre de 10 min forment une seule ligne.
    public static func lignes(_ evenements: [Evenement]) -> [LigneJournal] {
        let tries = evenements.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element)
        var lignes: [LigneJournal] = []
        var groupe: [Evenement] = []
        func fermer() {
            if groupe.count >= 2 {
                lignes.append(.pertes(groupe))
            } else if let e = groupe.first {
                lignes.append(.evenement(e))
            }
            groupe = []
        }
        for e in tries {
            if estPerte(e) {
                if let premiere = groupe.first, e.date.timeIntervalSince(premiere.date) >= fenetre { fermer() }
                groupe.append(e)
            } else {
                lignes.append(.evenement(e))
            }
        }
        fermer()
```

par :

```swift
    /// Lignes du journal, les plus recentes d'abord : les pertes survenues dans
    /// une meme fenetre de 10 min forment une seule ligne ; les changements de parent d'un meme
    /// noeud dans une fenetre de 1 h aussi.
    public static func lignes(_ evenements: [Evenement]) -> [LigneJournal] {
        let tries = evenements.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element)
        var lignes: [LigneJournal] = []
        var groupe: [Evenement] = []
        // Changements de parent en cours de regroupement, par noeud.
        var parents: [String: [Evenement]] = [:]
        func fermer() {
            if groupe.count >= 2 {
                lignes.append(.pertes(groupe))
            } else if let e = groupe.first {
                lignes.append(.evenement(e))
            }
            groupe = []
        }
        func fermerParents(_ noeud: String) {
            guard let g = parents.removeValue(forKey: noeud) else { return }
            if g.count >= 2 {
                lignes.append(.parents(g))
            } else if let e = g.first {
                lignes.append(.evenement(e))
            }
        }
        for e in tries {
            if estPerte(e) {
                if let premiere = groupe.first, e.date.timeIntervalSince(premiere.date) >= fenetre { fermer() }
                groupe.append(e)
            } else if e.type == .parentChange, let noeud = e.sujet?.id {
                if let premier = parents[noeud]?.first, e.date.timeIntervalSince(premier.date) >= fenetreParents {
                    fermerParents(noeud)
                }
                parents[noeud, default: []].append(e)
            } else {
                lignes.append(.evenement(e))
            }
        }
        fermer()
        for noeud in parents.keys.sorted() { fermerParents(noeud) }
```

Dans `MaillageThread/Surveillance/TexteEvenement.swift`, remplacer :

```swift
            return String(localized: "\(p.count) appareils perdus entre \(debut) et \(fin)")
        }
```

par :

```swift
            return String(localized: "\(p.count) appareils perdus entre \(debut) et \(fin)")
        case .parents(let p):
            let nom = p.first?.sujet?.nom ?? ""
            return String(localized: "\(nom) a changé \(p.count) fois de parent en 1 h")
        }
```

Dans `MaillageThread/Vues/Journal/FenetreJournal.swift`, remplacer :

```swift
/// Une ligne : pastille de gravite, titre, quand ; le detail des pertes regroupees.
struct LigneJournalVue: View {
    let ligne: LigneJournal

    var body: some View {
        switch ligne {
        case .evenement(let e):
            contenu(TexteEvenement.titre(e), quand: TexteEvenement.quand(e), gravite: e.gravite)
        case .pertes(let pertes):
            DisclosureGroup {
                ForEach(pertes) { e in
```

par :

```swift
/// Une ligne : pastille de gravite, titre, quand ; le detail des pertes et des changements de
/// parent regroupes.
struct LigneJournalVue: View {
    let ligne: LigneJournal

    var body: some View {
        switch ligne {
        case .evenement(let e):
            contenu(TexteEvenement.titre(e), quand: TexteEvenement.quand(e), gravite: e.gravite)
        case .pertes(let groupe), .parents(let groupe):
            DisclosureGroup {
                ForEach(groupe) { e in
```

Dans `MaillageThread/Vues/Journal/FenetreJournal.swift`, remplacer :

```swift
                contenu(TexteEvenement.titre(ligne), quand: pertes.first.map(TexteEvenement.quand) ?? "",
```

par :

```swift
                contenu(TexteEvenement.titre(ligne), quand: groupe.first.map(TexteEvenement.quand) ?? "",
```

- [ ] **Step 4 : textes, en français et en anglais.** Compiler, puis ajouter au catalogue les clés que le compilateur a extraites :

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/RegroupementParentsTests MaillageCoeurTests/ScenarioPanneTests MaillageThreadTests/TexteEvenementTests
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" outils/synchroniser-textes.sh
```

Expected : `** TEST SUCCEEDED **` (ces cibles n'incluent pas `CataloguesTests`) ; `Localizable.xcstrings` reçoit exactement cette clé : « %@ a changé %lld fois de parent en 1 h ».

Puis les traductions, par ce script qui garde `interface.json` trié et au format de l'outil, et le catalogue :

```bash
python3 - <<'EOF'
import json
f = 'outils/traductions/interface.json'
d = json.load(open(f, encoding='utf-8'))
d.update({
    "%@ a changé %lld fois de parent en 1 h": "%1$@ changed parent %2$lld times within 1 h",
})
open(f, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

- [ ] **Step 5 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/RegroupementParentsTests MaillageCoeurTests/ScenarioPanneTests MaillageThreadTests/TexteEvenementTests`
Expected: `Test run with 9 tests in 2 suites passed` (cœur : `RegroupementParentsTests` 2, `ScenarioPanneTests` 7, inchangé) et `Test run with 5 tests in 1 suite passed` (app, `TexteEvenementTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement, `CataloguesTests` compris ; 2 tests et 1 suite de plus pour le cœur, 1 test pour l'app (au rejeu : 249 tests en 24 suites, et 223 en 25 suites).

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Suivi/Regroupement.swift MaillageThread/Surveillance/TexteEvenement.swift MaillageThread/Vues/Journal/FenetreJournal.swift MaillageCoeurTests/RegroupementParentsTests.swift MaillageThreadTests/TexteEvenementTests.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Regrouper les changements de parent d'un noeud dans l'heure

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 8: App : journal du maillage et historique dans `Surveillance`

**Files:**
- Modify: `MaillageThread/Surveillance/Surveillance.swift`, `MaillageThread/Vues/Graphe/FicheNoeud.swift` (blocs ci-dessous)
- Test: `MaillageThreadTests/JournalMaillageTests.swift`

**Interfaces:**
- Consumes : `SuiviMaillage`, `SujetsMaillage` (tâche 6), `ReleveMaillage`, `HistoriqueFichiers` (tâche 5), `MaillageAffiche` (plan 3a), `GrapheCanvas.libelleInconnu(_:noms:)`, `JournalFichiers`, `oublierMaillage()` (appelé par `SondeMaillage.surOubli`).
- Produces :
  - `Surveillance.historique: [ReleveMaillage]` (observé ; les 30 derniers jours ; vide en démo), `Surveillance.dureeHistorique` (30 jours), `Surveillance.journalMac` (`Logger`, catégorie « historique ») ;
  - `recevoir(_:a:)` : les événements du maillage vont au journal ; en mode direct, le relevé va à l'historique en mémoire, et sur disque avec un dossier (`<dossier>/maillage-AAAA-MM.jsonl`, à côté de `identites-routeurs.json`) ; un échec d'écriture est consigné dans le journal du Mac, sans données du réseau ;
  - `chargerHistorique() async` : purge (90 jours) et relecture des 30 derniers jours, hors de l'acteur principal ; lancée par `demarrer()` en mode direct ;
  - `oublierMaillage()` remet aussi le suivi du maillage à zéro : le maillage suivant est un point de départ (test `oubliRepartDeZero`) ; l'historique reste ;
  - `sujets(_ m: Maillage) -> SujetsMaillage` ; `rapprochement(_:)` (privé) ;
  - `nomNoeud(_ id: String, maillage: MaillageAffiche?) -> String?`, que la fiche reprend.

`MaillageThreadApp` ne change pas : il crée déjà `Surveillance(mode: .direct, dossier: Surveillance.dossierParDefaut)` en direct et `dossier: nil` en démo, et ne branche `surMaillage` ni n'appelle `demarrer()` sous les tests.

- [ ] **Step 1 : écrire les tests.** Dossiers temporaires seulement ; dates en secondes entières (le fichier garde la milliseconde) et proches de maintenant (la relecture ne garde que 30 jours).

`MaillageThreadTests/JournalMaillageTests.swift` :

```swift
import Foundation
@testable import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Journal et historique de la sonde dans l'app")
struct JournalMaillageTests {
    /// Un appareil Matter du releve de la demo : son ExtMac est son nom d'hote.
    static let appareil = "56B1E064401F74EF"

    static func dossier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("maillage-\(UUID().uuidString)")
    }

    /// Mode direct sans ecoute, avec les 12 premiers releves de la panne rejouee (instantane,
    /// appareils) ; journal et historique dans `dossier`.
    static func surveillance(_ mode: Surveillance.Mode = .direct, dossier: URL?) -> Surveillance {
        let s = Surveillance(mode: mode, dossier: dossier)
        for a in ScenarioPanne.releves.prefix(12) { s.integrer(a) }
        return s
    }

    /// Maillage de la partition principale (valeurs inventees) : les routeurs 1 (chef) et 5, qui ne
    /// sont pas dans l'instantane ; l'appareil, enfant de `parent`.
    static func maillage(_ s: Surveillance, _ date: Date, parent: Int) throws -> Maillage {
        var c = ConstructionMaillage(date: date, partition: try #require(s.reseau?.principale?.id))
        c.routeurs(Route64(sequence: 1, routes: [1, 5].map { RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1) }),
                   chef: 1)
        c.lien(1, 5, sortante: 3, entrante: 2)
        c.enfant(EnfantMaillage(rloc16: UInt16(parent) << 10 | 2, extMac: Self.appareil, qualite: 3, source: .tableEnfants))
        c.signal(SignalSonde(routeur: 1, rssi: -61))
        return c.maillage()
    }

    /// Changement de parent de l'appareil : au journal (en memoire et sur disque), sous son id et son
    /// nom du graphe, avec le nom des deux routeurs ; chaque tournee a son releve dans
    /// `maillage-AAAA-MM.jsonl`, relu par un nouveau lancement.
    @Test func journalEtHistoriqueSurDisque() async throws {
        let dossier = Self.dossier()
        defer { try? FileManager.default.removeItem(at: dossier) }
        let s = Self.surveillance(dossier: dossier)
        // Des secondes entieres : le fichier garde les dates a la milliseconde.
        let t = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down) - 600)
        s.recevoir(try Self.maillage(s, t, parent: 1), a: t.addingTimeInterval(1))
        s.recevoir(try Self.maillage(s, t.addingTimeInterval(300), parent: 5), a: t.addingTimeInterval(301))
        let e = try #require(s.evenements.last)
        #expect(e.type == .parentChange)
        let a = try #require(s.appareil(Self.appareil))
        #expect(e.sujet == Sujet(id: Self.appareil, nom: s.nom(a)))
        #expect(e.avant == String(localized: "Routeur · \("0400")") && e.apres == String(localized: "Routeur · \("1400")"))
        #expect(try JournalFichiers(dossier: dossier.appendingPathComponent("Journal")).lire().last == e)
        #expect(s.historique.map(\.date) == [t, t.addingTimeInterval(300)])
        let fichier = dossier.appendingPathComponent(HistoriqueFichiers(dossier: dossier).nomFichier(t.addingTimeInterval(300)))
        #expect(FileManager.default.fileExists(atPath: fichier.path))
        let relu = Surveillance(mode: .direct, dossier: dossier)
        await relu.chargerHistorique()
        #expect(relu.historique == s.historique)
    }

    /// Appareil vu deux fois (le balayage ancien d'un routeur muet, et la table de son nouveau
    /// parent) : le journal le nomme comme l'appareil, sous son nouveau parent, meme si le graphe
    /// donne son id a l'entree du balayage (le premier RLOC16).
    @Test func appareilVuDeuxFois() throws {
        let s = Self.surveillance(dossier: nil)
        let t = Date()
        s.recevoir(try Self.maillage(s, t, parent: 1), a: t)
        var c = ConstructionMaillage(date: t.addingTimeInterval(300), partition: try #require(s.reseau?.principale?.id))
        c.routeurs(Route64(sequence: 1, routes: [1, 5].map { RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1) }),
                   chef: 1)
        c.muet(1)
        c.enfant(EnfantMaillage(rloc16: 0x0405, extMac: Self.appareil, source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x1402, extMac: Self.appareil, qualite: 2, source: .tableEnfants))
        s.recevoir(c.maillage(), a: t.addingTimeInterval(300))
        let e = try #require(s.evenements.last)
        #expect(e.type == .parentChange && e.sujet?.id == Self.appareil)
        #expect(e.apres == String(localized: "Routeur · \("1400")"))
    }

    /// Demo : ni releve en memoire, ni fichier, meme avec un dossier ; le journal du maillage reste
    /// en memoire. Direct sans dossier : l'historique en memoire seulement.
    @Test func rienSurDisqueEnDemo() throws {
        let dossier = Self.dossier()
        defer { try? FileManager.default.removeItem(at: dossier) }
        let demo = Self.surveillance(.demo, dossier: dossier)
        let t = Date()
        demo.recevoir(try Self.maillage(demo, t, parent: 1), a: t)
        demo.recevoir(try Self.maillage(demo, t.addingTimeInterval(300), parent: 5), a: t.addingTimeInterval(300))
        #expect(demo.historique.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: dossier.path))
        #expect(demo.evenements.last?.type == .parentChange)
        let memoire = Self.surveillance(dossier: nil)
        memoire.recevoir(try Self.maillage(memoire, t, parent: 1), a: t)
        #expect(memoire.historique.count == 1)
    }

    /// Sonde oubliee : le maillage suivant est un point de depart (pas de « a change de parent »
    /// calcule par-dessus l'oubli) ; l'historique en memoire reste.
    @Test func oubliRepartDeZero() throws {
        let s = Self.surveillance(dossier: nil)
        let t = Date()
        s.recevoir(try Self.maillage(s, t, parent: 1), a: t)
        s.oublierMaillage()
        let avant = s.evenements.count
        s.recevoir(try Self.maillage(s, t.addingTimeInterval(300), parent: 5), a: t.addingTimeInterval(300))
        #expect(s.evenements.count == avant, "point de depart")
        #expect(s.historique.count == 2)
    }

    /// L'historique en memoire garde 30 jours, comptes depuis la reception du dernier maillage.
    @Test func trenteJoursEnMemoire() throws {
        let s = Self.surveillance(dossier: nil)
        let t = Date()
        let vieux = t.addingTimeInterval(-Surveillance.dureeHistorique - 60)
        s.recevoir(try Self.maillage(s, vieux, parent: 1), a: vieux)
        s.recevoir(try Self.maillage(s, t, parent: 1), a: t)
        #expect(s.historique.map(\.date) == [t])
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageThreadTests/JournalMaillageTests MaillageThreadTests/SurveillanceTests MaillageThreadTests/AffichageSondeTests`
Expected: la compilation échoue, par exemple avec `error: value of type 'Surveillance' has no member 'historique'`, `error: value of type 'Surveillance' has no member 'chargerHistorique'` et `error: type 'Surveillance' has no member 'dureeHistorique'`.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
import AppKit
import MaillageCoeur
import Observation
```

par :

```swift
import AppKit
import MaillageCoeur
import Observation
import os
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
/// Modele de l'app : releves -> suivi -> journal et notifications ; noms ;
/// etat lu par les vues.
```

par :

```swift
/// Modele de l'app : releves -> suivi -> journal et notifications ; maillages de la
/// sonde -> journal et historique ; noms ; etat lu par les vues.
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    /// maillage affiche attend le suivant, il n'est pas « ancien ».
    var tourneeEnCours = false
```

par :

```swift
    /// maillage affiche attend le suivant, il n'est pas « ancien ».
    var tourneeEnCours = false
    /// Historique de la sonde (spec de la sonde, section 6) : les releves des 30 derniers jours,
    /// du plus ancien au plus recent ; toujours vide en demo.
    private(set) var historique: [ReleveMaillage] = []
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    @ObservationIgnored private var alertes = Alertes()
```

par :

```swift
    @ObservationIgnored private var alertes = Alertes()
    @ObservationIgnored private var suiviMaillage = SuiviMaillage()
    /// Historique sur disque : mode direct avec un dossier ; nil : nulle part (demo, tests).
    @ObservationIgnored private let fichiersHistorique: HistoriqueFichiers?
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    static let cleScissionsNotifiees = "scissionsNotifiees"
```

par :

```swift
    static let cleScissionsNotifiees = "scissionsNotifiees"
    /// Historique garde en memoire : les courbes de la fiche vont jusqu'a 30 jours.
    static let dureeHistorique: TimeInterval = 30 * 24 * 3600
    /// Journal du Mac (Console, sous-systeme fr.djoko.maillage) : jamais de donnees du reseau.
    nonisolated static let journalMac = Logger(subsystem: "fr.djoko.maillage", category: "historique")
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    /// `dossier` : ou garder le journal et les surnoms (nil : nulle part) ;
    /// `preferences` : les scissions deja notifiees (mode direct, une fois demarree).
```

par :

```swift
    /// `dossier` : ou garder le journal, les surnoms et l'historique de la sonde (nil : nulle
    /// part) ; `preferences` : les scissions deja notifiees (mode direct, une fois demarree).
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
            noms = ResolveurNoms(surnoms: fichierSurnoms.map(Surnoms.lire) ?? [:])
        case .demo:
```

par :

```swift
            noms = ResolveurNoms(surnoms: fichierSurnoms.map(Surnoms.lire) ?? [:])
            fichiersHistorique = dossier.map { HistoriqueFichiers(dossier: $0) }
        case .demo:
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
            noms = ResolveurNoms(maison: NomsDemo.maison)
        }
```

par :

```swift
            noms = ResolveurNoms(maison: NomsDemo.maison)
            fichiersHistorique = nil
        }
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
            recenseur?.surReleve = { [weak self] a in self?.integrer(a) }
```

par :

```swift
            Task { [weak self] in await self?.chargerHistorique() }
            recenseur?.surReleve = { [weak self] a in self?.integrer(a) }
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    /// Nouveau maillage de la sonde, recu a `date` (fin de sa tournee).
    func recevoir(_ m: Maillage, a date: Date) {
        maillage = m
        maillageRecu = date
    }
```

par :

```swift
    /// Nouveau maillage de la sonde, recu a `date` (fin de sa tournee) : ses evenements vont au
    /// journal (changements de parent, routeurs Thread) ; en mode direct, son releve va a
    /// l'historique, en memoire et, avec un dossier, sur disque. Un echec d'ecriture est consigne
    /// dans le journal du Mac ; le releve reste en memoire.
    func recevoir(_ m: Maillage, a date: Date) {
        maillage = m
        maillageRecu = date
        ajouter(suiviMaillage.integrer(m, sujets: sujets(m)))
        guard mode == .direct else { return }
        let r = ReleveMaillage(m)
        let limite = date.addingTimeInterval(-Self.dureeHistorique)
        historique = historique.filter { $0.date >= limite } + [r]
        guard let f = fichiersHistorique else { return }
        do {
            try f.ajouter(r)
        } catch {
            Self.journalMac.error("releve de l'historique non ecrit : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Relit les 30 derniers jours de l'historique, hors de l'acteur principal, apres avoir purge
    /// les mois finis depuis plus de 90 jours ; les releves recus entre-temps restent. Sans dossier
    /// (demo, tests) : rien.
    func chargerHistorique() async {
        guard let f = fichiersHistorique else { return }
        let maintenant = Date()
        let debut = maintenant.addingTimeInterval(-Self.dureeHistorique)
        do {
            let lus = try await Task.detached(priority: .utility) {
                try f.purger(maintenant: maintenant)
                return try f.lire(depuis: debut)
            }.value
            let premier = historique.first?.date ?? .distantFuture
            historique = lus.filter { $0.date < premier } + historique
        } catch {
            Self.journalMac.error("historique illisible : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Rapprochement d'un maillage avec le reseau de sa partition (a defaut, le reseau affiche),
    /// frais ou non ; nil sans instantane.
    private func rapprochement(_ m: Maillage) -> MaillageAffiche? {
        guard let i = instantane,
              let r = i.reseaux.first(where: { r in r.partitions.contains { $0.id == m.partition } }) ?? reseau else {
            return nil
        }
        return MaillageAffiche(maillage: m, reseau: r, appareils: i.appareils + Array(suivi.disparus.values))
    }

    /// Noeuds d'un maillage pour le journal : leur id dans le graphe et leur nom affiche,
    /// d'apres le rapprochement avec le reseau de sa partition (a defaut, le reseau affiche). Un
    /// enfant identifie est d'abord l'appareil de meme ExtMac : vu deux fois (balayage ancien,
    /// table), il n'a son id d'appareil qu'une fois dans le graphe.
    func sujets(_ m: Maillage) -> SujetsMaillage {
        let affiche = rapprochement(m)
        let appareils = (instantane?.appareils ?? []) + Array(suivi.disparus.values)
        func sujet(_ n: NoeudSonde?, rloc16: UInt16, genre: NoeudSonde.Genre, bordure: Bool) -> Sujet {
            let noeud = n ?? NoeudSonde(id: String(format: "rloc:%04X", rloc16), rloc16: rloc16, genre: genre,
                                        reconnu: false, bordure: bordure)
            return Sujet(id: noeud.id, nom: nomNoeud(noeud.id, maillage: affiche) ?? GrapheCanvas.libelleInconnu(noeud))
        }
        var s = SujetsMaillage()
        for r in m.routeurs {
            s.routeurs[r.id] = sujet(affiche?.routeurs[r.id], rloc16: r.rloc16, genre: .routeur, bordure: r.bordure)
        }
        for e in m.enfants {
            if let x = e.extMac, let a = appareils.first(where: { $0.id.uppercased() == x }) {
                s.enfants[e.rloc16] = Sujet(id: a.id, nom: nom(a))
            } else {
                s.enfants[e.rloc16] = sujet(affiche?.enfants[e.rloc16], rloc16: e.rloc16, genre: .enfant, bordure: false)
            }
        }
        return s
    }
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    func nomsRouteurs(pour r: Reseau) -> [String: String] {
        Dictionary(r.routeurs.map { ($0.instance, nom($0)) }, uniquingKeysWith: { a, _ in a })
    }
```

par :

```swift
    func nomsRouteurs(pour r: Reseau) -> [String: String] {
        Dictionary(r.routeurs.map { ($0.instance, nom($0)) }, uniquingKeysWith: { a, _ in a })
    }

    /// Nom affiche d'un noeud du graphe : routeur de bordure, appareil, ou noeud que seule la sonde
    /// connait (« Routeur · 5000 », candidats d'un routeur de bordure non identifie) ; nil s'il
    /// n'est nulle part.
    func nomNoeud(_ id: String, maillage m: MaillageAffiche?) -> String? {
        if let r = instantane?.routeur(id) { return nom(r) }
        if let a = appareil(id) { return nom(a) }
        guard let n = m?.noeud(id) else { return nil }
        let noms = Dictionary((instantane?.routeurs ?? []).map { ($0.instance, nom($0)) }, uniquingKeysWith: { a, _ in a })
        return GrapheCanvas.libelleInconnu(n, noms: noms)
    }
```

Dans `MaillageThread/Vues/Graphe/FicheNoeud.swift`, remplacer :

```swift
    private func nomNoeud(_ id: String) -> String {
        if let r = surveillance.instantane?.routeur(id) { return surveillance.nom(r) }
        if let a = surveillance.appareil(id) { return surveillance.nom(a) }
        if let n = sonde?.noeud(id) { return GrapheCanvas.libelleInconnu(n, noms: nomsRouteurs) }
        return id
    }
```

par :

```swift
    private func nomNoeud(_ id: String) -> String {
        surveillance.nomNoeud(id, maillage: sonde) ?? id
    }
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    /// Sonde oubliee (`SondeMaillage.surOubli`) : son maillage part tout de suite, sans attendre
    /// qu'il soit perime ; le graphe revient aux pointilles.
    func oublierMaillage() {
        maillage = nil
        maillageRecu = nil
    }
```

par :

```swift
    /// Sonde oubliee (`SondeMaillage.surOubli`) : son maillage part tout de suite, sans attendre
    /// qu'il soit perime ; le graphe revient aux pointilles. Son suivi aussi : le maillage suivant
    /// (une autre sonde, plus tard) est un point de depart, sans evenement. L'historique reste : il
    /// parle du reseau, pas de la sonde.
    func oublierMaillage() {
        maillage = nil
        maillageRecu = nil
        suiviMaillage = SuiviMaillage()
    }
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageThreadTests/JournalMaillageTests MaillageThreadTests/SurveillanceTests MaillageThreadTests/AffichageSondeTests`
Expected: `Test run with 26 tests in 3 suites passed` (app : `JournalMaillageTests` 5, et `SurveillanceTests` 6, `AffichageSondeTests` 15, inchangés), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 5 tests et 1 suite de plus pour l'app (au rejeu : 249 tests en 24 suites, et 228 en 26 suites).

- [ ] **Step 6 : commit.**

```bash
git add MaillageThread/Surveillance/Surveillance.swift MaillageThread/Vues/Graphe/FicheNoeud.swift MaillageThreadTests/JournalMaillageTests.swift
git commit -m "Tenir le journal du maillage et l'historique de la sonde

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 9: Cœur : les courbes d'un nœud

**Files:**
- Create: `MaillageCoeur/Maillage/CourbesNoeud.swift`
- Test: `MaillageCoeurTests/CourbesNoeudTests.swift`

**Interfaces:**
- Consumes : `ReleveMaillage` (`cle(routeur:)`, tâche 5), `LienRadio.qualite` (la moins bonne des deux qualités connues).
- Produces :
  - `PeriodeCourbes` (`.jour`, `.semaine`, `.mois` ; `duree`, `pas` : nil, 1800, 7200 s ; `Identifiable`) ;
  - `PointCourbe` (`date`, `valeur`, `troncon`), `CourbeLien` (`id` : la clé de l'autre bout, ou `CourbesNoeud.cleParent`), `ChangementParent` (`date`, `parent` : la clé du nouveau parent) ;
  - `CourbesNoeud(cle:releves:periode:fin:)` : `debut`, `fin`, `liens: [CourbeLien]` (par clé), `parents`, `signal: [PointCourbe]`, `parentsSonde`, `estVide` ; `CourbesNoeud.cleParent` (« parent ») et `ecartMax` (20 min).

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/CourbesNoeudTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Courbes d'un noeud tirees de l'historique")
struct CourbesNoeudTests {
    /// Debut d'un pas de 30 min et de 2 h.
    static let t0 = Date(timeIntervalSince1970: 1_790_006_400)
    static let a0 = "E0000000000000A0"
    static let a1 = "E0000000000000A1"
    static let b1 = "E0000000000000B1"

    /// Releve a `minutes` de t0 (valeurs inventees) : les routeurs 0 (a0) et 1 (sans ExtMac si
    /// `sansExt1`, sinon a1) et leur lien, de qualite `q` de 0 vers 1 et 3 de 1 vers 0 ; l'enfant
    /// b1 sous `parent` ; la sonde sous `parentSonde`, qui entend le routeur 0 a `rssi`.
    static func releve(_ minutes: Double, q: Int = 3, parent: Int = 0, qualiteEnfant: Int? = 3, parentSonde: Int = 0,
                       rssi: Int = -60, sansExt1: Bool = false) -> ReleveMaillage {
        ReleveMaillage(date: t0.addingTimeInterval(minutes * 60), partition: "0000000A",
                       routeurs: [.init(id: 0, extMac: a0), .init(id: 1, extMac: sansExt1 ? nil : a1)],
                       liens: [LienRadio(a: 0, b: 1, qualiteAB: q, qualiteBA: 3)],
                       enfants: [.init(extMac: b1, parent: parent, qualite: qualiteEnfant)],
                       signaux: [SignalSonde(routeur: 0, rssi: rssi)], parentSonde: parentSonde)
    }

    static func minutes(_ m: Double) -> Date { t0.addingTimeInterval(m * 60) }

    /// Routeur : la qualite de son lien avec chaque voisin (la moins bonne des deux sens) et le
    /// signal que la sonde en recoit, a chaque releve de la periode.
    @Test func routeur() {
        let releves = [Self.releve(0, q: 3, rssi: -60), Self.releve(5, q: 2, rssi: -65), Self.releve(10, q: 1, rssi: -70)]
        let c = CourbesNoeud(cle: Self.a0, releves: releves, periode: .jour, fin: Self.minutes(15))
        #expect(c.liens == [CourbeLien(id: Self.a1, points: [PointCourbe(date: Self.minutes(0), valeur: 3, troncon: 0),
                                                             PointCourbe(date: Self.minutes(5), valeur: 2, troncon: 0),
                                                             PointCourbe(date: Self.minutes(10), valeur: 1, troncon: 0)])])
        #expect(c.signal.map(\.valeur) == [-60, -65, -70])
        #expect(c.parents.isEmpty)
        #expect(c.debut == Self.minutes(15).addingTimeInterval(-24 * 3600))
        #expect(CourbesNoeud(cle: Self.a1, releves: releves, periode: .jour, fin: Self.minutes(15)).signal.isEmpty,
                "la sonde n'entend pas le routeur 1")
    }

    /// Enfant : la qualite du lien vers son parent, quel qu'il soit (inconnue sous un routeur muet :
    /// pas de point), et ses changements de parent, a la date du premier releve sous le nouveau.
    @Test func enfant() {
        let releves = [Self.releve(0), Self.releve(5), Self.releve(10, parent: 1, qualiteEnfant: 2),
                       Self.releve(15, parent: 1, qualiteEnfant: nil)]
        let c = CourbesNoeud(cle: Self.b1, releves: releves, periode: .jour, fin: Self.minutes(20))
        #expect(c.liens.map(\.id) == [CourbesNoeud.cleParent])
        #expect(c.liens.first?.points.map(\.valeur) == [3, 3, 2])
        #expect(c.parents == [ChangementParent(date: Self.minutes(10), parent: Self.a1)])
        #expect(c.signal.isEmpty)
        #expect(!c.estVide)
        #expect(CourbesNoeud(cle: "E0000000000000FF", releves: releves, periode: .jour, fin: Self.minutes(20)).estVide)
    }

    /// Changements de parent de la sonde (sur la courbe du signal d'un routeur) ; un routeur sans
    /// ExtMac se suit par son RLOC16.
    @Test func sondeEtRouteurSansExtMac() {
        let releves = [Self.releve(0, parentSonde: 0, sansExt1: true), Self.releve(5, parentSonde: 0, sansExt1: true),
                       Self.releve(10, parentSonde: 1, sansExt1: true)]
        let c = CourbesNoeud(cle: Self.a0, releves: releves, periode: .jour, fin: Self.minutes(15))
        #expect(c.parentsSonde == [ChangementParent(date: Self.minutes(10), parent: "rloc:0400")])
        #expect(c.liens.map(\.id) == ["rloc:0400"])
        let r1 = CourbesNoeud(cle: "rloc:0400", releves: releves, periode: .jour, fin: Self.minutes(15))
        #expect(r1.liens.map(\.id) == [Self.a0])
    }

    /// 7 j : la moyenne de chaque pas de 30 min ; un trou de plus de trois pas ouvre un troncon.
    /// 24 h : chaque releve ; un trou de plus de 20 min ouvre un troncon. Hors periode : rien.
    @Test func pasEtTroncons() {
        let semaine = [0.0, 5, 10, 15, 20, 25].enumerated().map { Self.releve($1, q: $0 < 3 ? 3 : 2) }
            + [Self.releve(210, q: 3)]
        let c = CourbesNoeud(cle: Self.a0, releves: semaine, periode: .semaine, fin: Self.minutes(240))
        #expect(c.liens.first?.points == [PointCourbe(date: Self.minutes(0), valeur: 2.5, troncon: 0),
                                          PointCourbe(date: Self.minutes(210), valeur: 3, troncon: 1)])
        let jour = [Self.releve(0), Self.releve(5), Self.releve(30), Self.releve(35)]
        let d = CourbesNoeud(cle: Self.a0, releves: jour, periode: .jour, fin: Self.minutes(40))
        #expect(d.signal.map(\.troncon) == [0, 0, 1, 1])
        let tard = CourbesNoeud(cle: Self.a0, releves: jour, periode: .jour, fin: Self.minutes(20 + 24 * 60))
        #expect(tard.signal.map(\.date) == [Self.minutes(30), Self.minutes(35)], "24 h avant la fin")
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/CourbesNoeudTests`
Expected: la compilation échoue, par exemple avec `error: cannot find 'CourbesNoeud' in scope`, `error: cannot find 'CourbeLien' in scope`, `error: cannot find 'PointCourbe' in scope` et `error: cannot find 'ChangementParent' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Maillage/CourbesNoeud.swift` :

```swift
import Foundation

/// Periode des courbes de la fiche (spec de la sonde, section 6) : 24 h, 7 j ou 30 j.
public enum PeriodeCourbes: String, CaseIterable, Hashable, Sendable, Identifiable {
    case jour, semaine, mois

    public var id: String { rawValue }

    public var duree: TimeInterval {
        switch self {
        case .jour: 24 * 3600
        case .semaine: 7 * 24 * 3600
        case .mois: 30 * 24 * 3600
        }
    }

    /// Pas des points, moyenne des releves du pas : chaque releve sur 24 h (288 points), 30 min
    /// sur 7 j (336), 2 h sur 30 j (360) ; sans pas, 30 j de releves feraient 8 640 points.
    public var pas: TimeInterval? {
        switch self {
        case .jour: nil
        case .semaine: 1800
        case .mois: 7200
        }
    }
}

/// Point d'une courbe. `troncon` : numero du morceau de courbe ; un trou (plus de 20 min entre
/// deux releves, ou de trois pas) en commence un autre, pour ne pas relier par-dessus le trou.
public struct PointCourbe: Hashable, Sendable {
    public let date: Date
    public let valeur: Double
    public let troncon: Int

    public init(date: Date, valeur: Double, troncon: Int) {
        self.date = date
        self.valeur = valeur
        self.troncon = troncon
    }
}

/// Qualite d'un lien au fil du temps (0 a 3) : l'autre bout, par sa cle (ExtMac, "rloc:XXXX"),
/// ou `CourbesNoeud.cleParent` pour le lien d'un enfant vers son parent, quel qu'il soit.
public struct CourbeLien: Hashable, Sendable, Identifiable {
    public let id: String
    public let points: [PointCourbe]

    public init(id: String, points: [PointCourbe]) {
        self.id = id
        self.points = points
    }
}

/// Changement de parent : sa date (le premier releve sous le nouveau parent) et la cle du nouveau
/// parent.
public struct ChangementParent: Hashable, Sendable {
    public let date: Date
    public let parent: String

    public init(date: Date, parent: String) {
        self.date = date
        self.parent = parent
    }
}

/// Courbes d'un noeud tirees de l'historique (spec de la sonde, section 6), sur une periode :
/// - routeur : la qualite de chaque lien avec un routeur voisin, et le signal que la sonde en
///   recoit (dBm), avec les changements de parent de la sonde, car ce signal depend d'abord de
///   l'endroit ou elle est posee ;
/// - enfant : la qualite du lien vers son parent (inconnue sous un routeur muet), avec ses
///   changements de parent.
/// Un noeud se reconnait d'un releve a l'autre par sa cle : son ExtMac, ou "rloc:XXXX" pour un
/// routeur sans ExtMac (`ReleveMaillage.cle(routeur:)`).
public struct CourbesNoeud: Hashable, Sendable {
    /// Cle de la courbe d'un enfant vers son parent.
    public static let cleParent = "parent"
    /// Trou le plus long entre deux releves d'une meme courbe (sans pas) : la tournee part 5 min
    /// apres la fin de la precedente ; au-dela de 20 min, il en manque.
    public static let ecartMax: TimeInterval = 20 * 60

    public let debut: Date
    public let fin: Date
    /// Par cle de l'autre bout.
    public let liens: [CourbeLien]
    public let parents: [ChangementParent]
    public let signal: [PointCourbe]
    public let parentsSonde: [ChangementParent]

    public var estVide: Bool { liens.allSatisfy { $0.points.isEmpty } && parents.isEmpty && signal.isEmpty }

    /// Courbes du noeud de cle `cle` dans `releves` (du plus ancien au plus recent), sur la
    /// periode qui finit a `fin`.
    public init(cle: String, releves: [ReleveMaillage], periode: PeriodeCourbes, fin: Date) {
        let debut = fin.addingTimeInterval(-periode.duree)
        var liens: [String: [(Date, Double)]] = [:]
        var signal: [(Date, Double)] = []
        var parents: [ChangementParent] = []
        var parentsSonde: [ChangementParent] = []
        var dernierParent: String?
        var dernierParentSonde: String?
        for r in releves where r.date >= debut && r.date <= fin {
            if let id = r.routeurs.first(where: { r.cle(routeur: $0.id) == cle })?.id {
                for l in r.liens where l.a == id || l.b == id {
                    guard let q = l.qualite else { continue }
                    liens[r.cle(routeur: l.a == id ? l.b : l.a), default: []].append((r.date, Double(q)))
                }
                if let s = r.signaux.first(where: { $0.routeur == id }) { signal.append((r.date, Double(s.rssi))) }
            }
            if let e = r.enfants.first(where: { $0.extMac == cle }) {
                let p = r.cle(routeur: e.parent)
                if let d = dernierParent, d != p { parents.append(ChangementParent(date: r.date, parent: p)) }
                dernierParent = p
                if let q = e.qualite { liens[Self.cleParent, default: []].append((r.date, Double(q))) }
            }
            if let ps = r.parentSonde {
                let p = r.cle(routeur: ps)
                if let d = dernierParentSonde, d != p { parentsSonde.append(ChangementParent(date: r.date, parent: p)) }
                dernierParentSonde = p
            }
        }
        self.debut = debut
        self.fin = fin
        self.liens = liens.keys.sorted().map { CourbeLien(id: $0, points: Self.reduire(liens[$0] ?? [], pas: periode.pas)) }
        self.parents = parents
        self.signal = Self.reduire(signal, pas: periode.pas)
        self.parentsSonde = parentsSonde
    }

    /// Points d'une courbe : la moyenne de chaque pas (datee du debut du pas), ou chaque releve
    /// sans pas ; un ecart de plus de trois pas (20 min sans pas) entre deux points ouvre un
    /// nouveau troncon.
    static func reduire(_ bruts: [(Date, Double)], pas: TimeInterval?) -> [PointCourbe] {
        var points = bruts
        if let pas {
            var groupes: [(debut: Date, valeurs: [Double])] = []
            for (d, v) in bruts {
                let debut = Date(timeIntervalSince1970: (d.timeIntervalSince1970 / pas).rounded(.down) * pas)
                if groupes.last?.debut == debut {
                    groupes[groupes.count - 1].valeurs.append(v)
                } else {
                    groupes.append((debut, [v]))
                }
            }
            points = groupes.map { ($0.debut, $0.valeurs.reduce(0, +) / Double($0.valeurs.count)) }
        }
        let ecart = pas.map { 3 * $0 } ?? ecartMax
        var troncon = 0
        var resultat: [PointCourbe] = []
        for (i, (d, v)) in points.enumerated() {
            if i > 0, d.timeIntervalSince(points[i - 1].0) > ecart { troncon += 1 }
            resultat.append(PointCourbe(date: d, valeur: v, troncon: troncon))
        }
        return resultat
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageCoeurTests/CourbesNoeudTests`
Expected: `Test run with 4 tests in 1 suite passed` (cœur, `CourbesNoeudTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement ; 4 tests et 1 suite de plus pour le cœur, l'app inchangée (au rejeu : 253 tests en 25 suites, et 228 en 26 suites).

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Maillage/CourbesNoeud.swift MaillageCoeurTests/CourbesNoeudTests.swift
git commit -m "Tirer de l'historique les courbes d'un noeud

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 10: Fiche : les courbes en Swift Charts

**Files:**
- Create: `MaillageThread/Vues/Graphe/CourbesFiche.swift`
- Modify: `MaillageThread/Surveillance/Surveillance.swift`, `MaillageThread/Vues/Graphe/FicheNoeud.swift`, `MaillageThread/Vues/Graphe/FenetreGraphe.swift` (blocs ci-dessous), `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` (Step 4)
- Test: `MaillageThreadTests/CourbesFicheTests.swift`

**Interfaces:**
- Consumes : `CourbesNoeud`, `PeriodeCourbes` (tâche 9), `Surveillance.historique`, `rapprochement(_:)`, `nomNoeud(_:maillage:)` (tâche 8), `FicheNoeud.instant` (tâche 4), `JournalMaillageTests.surveillance(_:dossier:)`, `.maillage(_:_:parent:)` et `.appareil` (tâche 8, pour les tests).
- Produces :
  - `Surveillance.cleHistorique(noeud:) -> String?` (l'ExtMac du nœud dans le dernier maillage, `"rloc:XXXX"` pour un routeur sans ExtMac, sinon le `xa` d'un routeur de bordure ou l'hôte d'un appareil), `nomsHistorique(_ cles: Set<String>) -> [String: String]`, `courbes(noeud:periode:fin:) -> CourbesNoeud?` ;
  - `CourbesFiche(id:instant:)` : le choix de la période (24 h, 7 j, 30 j), « Qualité des liens » (ou « Qualité du lien vers le parent ») et « Signal vu par la sonde (dBm) », jusqu'à l'heure de la fiche ; `CourbesFiche.titre(_:)`, `titreQualite(_:)`, `nomLien(_:_:)` ;
  - `FicheNoeud.courbesVisibles(dans:)` ; la fiche met les courbes sous ses colonnes ;
  - `FenetreGraphe.margeBas(fiche:courbes:)` : 30, 190, ou 360 pt.

- [ ] **Step 1 : écrire les tests.**

`MaillageThreadTests/CourbesFicheTests.swift` :

```swift
import AppKit
import Foundation
@testable import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Courbes de l'historique dans la fiche")
struct CourbesFicheTests {
    /// Deux tournees (`JournalMaillageTests`) : l'appareil passe du routeur 1 au routeur 5.
    static func surveillance() throws -> Surveillance {
        let s = JournalMaillageTests.surveillance(dossier: nil)
        let t = Date().addingTimeInterval(-600)
        s.recevoir(try JournalMaillageTests.maillage(s, t, parent: 1), a: t)
        s.recevoir(try JournalMaillageTests.maillage(s, t.addingTimeInterval(300), parent: 5), a: t.addingTimeInterval(300))
        return s
    }

    /// Cle d'un noeud dans l'historique : l'ExtMac d'un appareil (son hote), "rloc:0400" pour un
    /// routeur sans ExtMac, le `xa` d'un routeur de bordure de l'instantane ; et le nom d'une cle.
    @Test func clesEtNoms() throws {
        let s = try Self.surveillance()
        let id = JournalMaillageTests.appareil
        #expect(s.cleHistorique(noeud: id) == id)
        #expect(s.cleHistorique(noeud: "rloc:0400") == "rloc:0400")
        let br = try #require(s.instantane?.routeurs.first { $0.adresseEtendue != nil })
        #expect(s.cleHistorique(noeud: br.instance) == br.adresseEtendue)
        #expect(s.cleHistorique(noeud: "instance:inconnue") == nil)
        let xa = try #require(br.adresseEtendue)
        let noms = s.nomsHistorique([id, "rloc:1400", xa, "E0000000000000FF"])
        #expect(noms[id] == s.nom(try #require(s.appareil(id))))
        #expect(noms["rloc:1400"] == String(localized: "Routeur · \("1400")"))
        #expect(noms[xa] == s.nom(br))
        #expect(noms["E0000000000000FF"] == "E0000000000000FF", "inconnue : la cle")
        #expect(CourbesFiche.nomLien(CourbesNoeud.cleParent, noms) == String(localized: "Parent"))
    }

    /// Courbes de l'appareil : la qualite vers son parent et son changement de parent ; du
    /// routeur 1 (sans ExtMac) : son lien avec le 5, et le signal vu par la sonde.
    @Test func courbes() throws {
        let s = try Self.surveillance()
        let c = try #require(s.courbes(noeud: JournalMaillageTests.appareil, periode: .jour, fin: Date()))
        #expect(c.liens.map(\.id) == [CourbesNoeud.cleParent])
        #expect(c.liens.first?.points.count == 2)
        #expect(c.parents.map(\.parent) == ["rloc:1400"])
        let r = try #require(s.courbes(noeud: "rloc:0400", periode: .jour, fin: Date()))
        #expect(r.liens.map(\.id) == ["rloc:1400"])
        #expect(r.signal.map(\.valeur) == [-61, -61])
    }

    /// La fiche montre les courbes des qu'il y a un historique (jamais en demo), et le graphe lui
    /// garde plus de place en bas ; pour un noeud sans historique, une ligne de texte.
    @Test func ficheEtMarge() throws {
        let s = try Self.surveillance()
        #expect(FicheNoeud.courbesVisibles(dans: s))
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        #expect(!FicheNoeud.courbesVisibles(dans: demo))
        #expect(FenetreGraphe.margeBas(fiche: false, courbes: true) == 30)
        #expect(FenetreGraphe.margeBas(fiche: true, courbes: false) == 190)
        #expect(FenetreGraphe.margeBas(fiche: true, courbes: true) == 360)
        let avec = NSHostingView(rootView: CourbesFiche(id: JournalMaillageTests.appareil, instant: Date()).environment(s)).fittingSize
        let sans = NSHostingView(rootView: CourbesFiche(id: "instance:inconnue", instant: Date()).environment(s)).fittingSize
        #expect(avec.height > sans.height + 100, "\(avec) \(sans)")
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageThreadTests/CourbesFicheTests MaillageThreadTests/AffichageSondeTests MaillageThreadTests/GrapheTests`
Expected: la compilation échoue, par exemple avec `error: value of type 'Surveillance' has no member 'cleHistorique'`, `error: cannot find 'CourbesFiche' in scope`, `error: value of type 'Surveillance' has no member 'courbes'`, `error: type 'FicheNoeud' has no member 'courbesVisibles'` et `error: type 'FenetreGraphe' has no member 'margeBas'`.

- [ ] **Step 3 : écrire le code.** Les noms des courbes sont lus une fois par rendu (`nomsHistorique`) : `MaillageAffiche` ne se construit pas à chaque point.

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    /// Nom affiche d'un noeud du graphe : routeur de bordure, appareil, ou noeud que seule la sonde
```

par :

```swift
    /// Cle d'un noeud du graphe dans l'historique : l'ExtMac de son routeur ou de son enfant dans
    /// le dernier maillage ("rloc:XXXX" pour un routeur sans ExtMac), sinon le `xa` de l'annonce
    /// d'un routeur de bordure, ou l'hote d'un appareil (l'ExtMac d'un appareil Matter) ; nil si
    /// le noeud n'en a pas.
    func cleHistorique(noeud id: String) -> String? {
        if let m = maillage, let n = rapprochement(m)?.noeud(id) {
            switch n.genre {
            case .routeur:
                if let r = m.routeur(Int(n.rloc16 >> 10)) { return r.extMac ?? String(format: "rloc:%04X", r.rloc16) }
            case .enfant:
                if let x = m.enfants.first(where: { $0.rloc16 == n.rloc16 })?.extMac { return x }
            }
        }
        if let xa = instantane?.routeur(id)?.adresseEtendue { return xa }
        if id.count == 16, id.allSatisfy(\.isHexDigit) { return id.uppercased() }
        return nil
    }

    /// Noms de noeuds de l'historique, par cle : leur nom dans le graphe, si le dernier maillage
    /// ou l'instantane les connait ; la cle sinon. Le rapprochement n'est fait qu'une fois.
    func nomsHistorique(_ cles: Set<String>) -> [String: String] {
        let affiche = maillage.flatMap(rapprochement)
        func nomDe(_ cle: String) -> String {
            if let m = maillage, let affiche {
                if let r = m.routeurs.first(where: { ($0.extMac ?? String(format: "rloc:%04X", $0.rloc16)) == cle }),
                   let n = affiche.routeurs[r.id], let x = nomNoeud(n.id, maillage: affiche) {
                    return x
                }
                if let e = m.enfants.first(where: { $0.extMac == cle }), let n = affiche.enfants[e.rloc16],
                   let x = nomNoeud(n.id, maillage: affiche) {
                    return x
                }
            }
            if let r = instantane?.routeurs.first(where: { $0.adresseEtendue == cle }) { return nom(r) }
            if let a = (instantane?.appareils ?? []).first(where: { $0.id.uppercased() == cle }) { return nom(a) }
            return cle
        }
        return Dictionary(uniqueKeysWithValues: cles.map { ($0, nomDe($0)) })
    }

    /// Courbes d'un noeud du graphe sur une periode qui finit a `fin` ; nil sans cle.
    func courbes(noeud id: String, periode: PeriodeCourbes, fin: Date) -> CourbesNoeud? {
        cleHistorique(noeud: id).map { CourbesNoeud(cle: $0, releves: historique, periode: periode, fin: fin) }
    }

    /// Nom affiche d'un noeud du graphe : routeur de bordure, appareil, ou noeud que seule la sonde
```

`MaillageThread/Vues/Graphe/CourbesFiche.swift` :

```swift
import Charts
import MaillageCoeur
import SwiftUI

/// Courbes de l'historique dans la fiche (spec de la sonde, section 6), sur 24 h, 7 j ou 30 j :
/// la qualite des liens du noeud (d'un routeur avec ses voisins, d'un enfant vers son parent,
/// ses changements de parent marques) et, pour un routeur, le signal que la sonde en recoit,
/// avec les changements de parent de la sonde marques (ce signal depend d'abord de l'endroit ou
/// elle est posee).
struct CourbesFiche: View {
    @Environment(Surveillance.self) private var surveillance
    let id: String
    /// Fin des courbes : l'heure de la fiche (`FicheNoeud.instant`), qui avance chaque minute.
    let instant: Date
    @State private var periode: PeriodeCourbes = .jour

    var body: some View {
        let courbes = surveillance.courbes(noeud: id, periode: periode, fin: instant)
        let noms = courbes.map { c in
            surveillance.nomsHistorique(Set(c.liens.map(\.id) + (c.parents + c.parentsSonde).map(\.parent)))
        } ?? [:]
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("Historique de la sonde").font(.headline)
                Picker("Période", selection: $periode) {
                    ForEach(PeriodeCourbes.allCases) { Text(Self.titre($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if let c = courbes, !c.estVide {
                HStack(alignment: .top, spacing: 24) {
                    if !c.liens.isEmpty || !c.parents.isEmpty { qualite(c, noms) }
                    if !c.signal.isEmpty { signal(c, noms) }
                }
            } else {
                Text("Pas encore d'historique de la sonde pour ce nœud sur cette période.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func titre(_ p: PeriodeCourbes) -> String {
        switch p {
        case .jour: String(localized: "24 h")
        case .semaine: String(localized: "7 j")
        case .mois: String(localized: "30 j")
        }
    }

    /// « Qualité du lien vers le parent » pour un enfant, « Qualité des liens » pour un routeur.
    static func titreQualite(_ c: CourbesNoeud) -> String {
        c.liens.allSatisfy { $0.id == CourbesNoeud.cleParent }
            ? String(localized: "Qualité du lien vers le parent") : String(localized: "Qualité des liens")
    }

    /// Nom d'une courbe de lien : le voisin, ou « Parent » pour le lien d'un enfant.
    static func nomLien(_ cle: String, _ noms: [String: String]) -> String {
        cle == CourbesNoeud.cleParent ? String(localized: "Parent") : noms[cle] ?? cle
    }

    private func qualite(_ c: CourbesNoeud, _ noms: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.titreQualite(c)).font(.caption).foregroundStyle(.secondary)
            Chart {
                ForEach(c.liens) { l in
                    ForEach(l.points, id: \.date) { p in
                        LineMark(x: .value("Heure", p.date), y: .value("Qualité", p.valeur),
                                 series: .value("Tronçon", "\(l.id)#\(p.troncon)"))
                            .foregroundStyle(by: .value("Lien", Self.nomLien(l.id, noms)))
                            .interpolationMethod(.stepEnd)
                    }
                }
                ForEach(c.parents, id: \.date) { ch in
                    RuleMark(x: .value("Heure", ch.date))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(verbatim: "→ " + (noms[ch.parent] ?? ch.parent)).font(.caption2)
                        }
                }
            }
            .chartXScale(domain: c.debut ... c.fin)
            .chartYScale(domain: 0 ... 3)
            .chartYAxis { AxisMarks(values: [0, 1, 2, 3]) }
            .chartLegend(c.liens.allSatisfy { $0.id == CourbesNoeud.cleParent } ? .hidden : .visible)
            .frame(width: 320, height: 120)
        }
    }

    private func signal(_ c: CourbesNoeud, _ noms: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Signal vu par la sonde (dBm)").font(.caption).foregroundStyle(.secondary)
            Chart {
                ForEach(c.signal, id: \.date) { p in
                    LineMark(x: .value("Heure", p.date), y: .value("Signal", p.valeur),
                             series: .value("Tronçon", p.troncon))
                }
                ForEach(c.parentsSonde, id: \.date) { ch in
                    RuleMark(x: .value("Heure", ch.date))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(verbatim: "→ " + (noms[ch.parent] ?? ch.parent)).font(.caption2)
                        }
                }
            }
            .chartXScale(domain: c.debut ... c.fin)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(width: 320, height: 120)
            if !c.parentsSonde.isEmpty {
                Text("Pointillé : la sonde change de parent.").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
```

Dans `MaillageThread/Vues/Graphe/FicheNoeud.swift`, remplacer :

```swift
    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            if let r = surveillance.instantane?.routeur(id) {
                colonnesRouteur(r)
            } else if let a = surveillance.appareil(id) {
                colonnesAppareil(a)
            } else if let m = sonde, let n = m.noeud(id) {
                colonnesSonde(n, m)
            } else {
                Text("Ce nœud n'est plus visible.").foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    fermer()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .help("Fermer")
                if Self.renommable(id, dans: surveillance) {
                    Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                        .buttonStyle(.glass)
                }
            }
        }
        .padding(16)
```

par :

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 28) {
                if let r = surveillance.instantane?.routeur(id) {
                    colonnesRouteur(r)
                } else if let a = surveillance.appareil(id) {
                    colonnesAppareil(a)
                } else if let m = sonde, let n = m.noeud(id) {
                    colonnesSonde(n, m)
                } else {
                    Text("Ce nœud n'est plus visible.").foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        fermer()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.glass)
                    .help("Fermer")
                    if Self.renommable(id, dans: surveillance) {
                        Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                            .buttonStyle(.glass)
                    }
                }
            }
            if Self.courbesVisibles(dans: surveillance) {
                CourbesFiche(id: id, instant: instant)
            }
        }
        .padding(16)
```

Dans `MaillageThread/Vues/Graphe/FicheNoeud.swift`, remplacer :

```swift
    /// « Renommer… » : le surnom est indexe par l'instance d'un routeur de l'instantane ou
```

par :

```swift
    /// Courbes de l'historique sous les colonnes, pour tout noeud, des que l'historique de la
    /// sonde a un releve (jamais en demo) : la fiche garde sa hauteur d'un noeud a l'autre.
    static func courbesVisibles(dans surveillance: Surveillance) -> Bool {
        !surveillance.historique.isEmpty
    }

    /// « Renommer… » : le surnom est indexe par l'instance d'un routeur de l'instantane ou
```

Dans `MaillageThread/Vues/Graphe/FenetreGraphe.swift`, remplacer :

```swift
                                                 bas: selection == nil ? 30 : 190, cotes: 60),
```

par :

```swift
                                                 bas: Self.margeBas(fiche: selection != nil,
                                                                    courbes: FicheNoeud.courbesVisibles(dans: surveillance)),
                                                 cotes: 60),
```

Dans `MaillageThread/Vues/Graphe/FenetreGraphe.swift`, remplacer :

```swift
    private func graphe(_ r: Reseau, _ palette: Palette) -> some View {
```

par :

```swift
    /// Marge du bas du graphe (pt) : la legende, ou la fiche ouverte, plus haute avec les courbes
    /// de l'historique (la fiche les montre pour tout noeud des qu'il y en a : le graphe ne bouge
    /// pas d'un noeud a l'autre).
    static func margeBas(fiche: Bool, courbes: Bool) -> CGFloat {
        guard fiche else { return 30 }
        return courbes ? 360 : 190
    }

    private func graphe(_ r: Reseau, _ palette: Palette) -> some View {
```

- [ ] **Step 4 : textes, en français et en anglais.** Compiler, puis ajouter au catalogue les clés que le compilateur a extraites :

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageThreadTests/CourbesFicheTests MaillageThreadTests/AffichageSondeTests MaillageThreadTests/GrapheTests
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" outils/synchroniser-textes.sh
```

Expected : `** TEST SUCCEEDED **` (ces cibles n'incluent pas `CataloguesTests`) ; `Localizable.xcstrings` reçoit exactement ces 16 clés : « 24 h », « 30 j », « 7 j », « Heure », « Historique de la sonde », « Lien », « Parent », « Pas encore d'historique de la sonde pour ce nœud sur cette période. », « Pointillé : la sonde change de parent. », « Période », « Qualité », « Qualité des liens », « Qualité du lien vers le parent », « Signal », « Signal vu par la sonde (dBm) », « Tronçon ».

Puis les traductions, par ce script qui garde `interface.json` trié et au format de l'outil, et le catalogue :

```bash
python3 - <<'EOF'
import json
f = 'outils/traductions/interface.json'
d = json.load(open(f, encoding='utf-8'))
d.update({
    "24 h": "24 h",
    "7 j": "7 d",
    "30 j": "30 d",
    "Heure": "Time",
    "Historique de la sonde": "Probe history",
    "Lien": "Link",
    "Parent": "Parent",
    "Pas encore d'historique de la sonde pour ce nœud sur cette période.": "No probe history for this node over this period yet.",
    "Pointillé : la sonde change de parent.": "Dotted line: the probe changes parent.",
    "Période": "Period",
    "Qualité": "Quality",
    "Qualité des liens": "Link quality",
    "Qualité du lien vers le parent": "Link quality to the parent",
    "Signal": "Signal",
    "Signal vu par la sonde (dBm)": "Signal seen by the probe (dBm)",
    "Tronçon": "Segment",
})
open(f, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

- [ ] **Step 5 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh MaillageThreadTests/CourbesFicheTests MaillageThreadTests/AffichageSondeTests MaillageThreadTests/GrapheTests`
Expected: `Test run with 24 tests in 3 suites passed` (app : `CourbesFicheTests` 3, et `AffichageSondeTests` 15, `GrapheTests` 6, inchangés), `** TEST SUCCEEDED **`.

- [ ] **Step 6 : toute la suite, en français puis en anglais.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, sans avertissement, `CataloguesTests` compris ; le cœur inchangé, 3 tests et 1 suite de plus pour l'app (au rejeu : 253 tests en 25 suites, et 231 en 27 suites).

Run: `TMPDIR="$HOME/Library/Caches/maillage-plan3b/" xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" -testLanguage en -testRegion US test 2>&1 | grep -E "✘|Test run with|\*\* TEST"`
Expected: `Test run with 253 tests in 25 suites passed`, `Test run with 231 tests in 27 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 7 : commit.**

```bash
git add MaillageThread/Surveillance/Surveillance.swift MaillageThread/Vues/Graphe/CourbesFiche.swift MaillageThread/Vues/Graphe/FicheNoeud.swift MaillageThread/Vues/Graphe/FenetreGraphe.swift MaillageThreadTests/CourbesFicheTests.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Montrer dans la fiche les courbes de l'historique de la sonde

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 11: Anonymiseur : longueur des TLV, texte des TLV 25 à 28, Prefix et Service

**Files:**
- Modify: `outils/anonymiser-sonde.py` (blocs ci-dessous)
- Test: `sonde/test/test_anonymiseur.py` (blocs ci-dessous)

**Interfaces:**
- Consumes : la garde de la vague de mineurs (lot 6 : `controler_tlv`, `controler_donnees_reseau`, `TLV_CONNUS`, `DONNEES_RESEAU_CONNUES`), et ce qu'elle laissait au plan 3b : la longueur des TLV 1, 2, 5, 6, 16 et 24, le texte des TLV 25 à 28, les sous-TLV des Prefix et des Service. La Network Data de la capture du dépôt (réponse 206) : des Has Route de 15 et 3 octets, un Border Router de 4, un 6LoWPAN Context de 2, des Server de 2, 9 (routeur de dorsale) et 20 octets (serveur SRP).
- Produces :
  - `TLV_LONGUEUR`, `TLV_ENTREES`, `TLV_TEXTE_MAX`, `HEXA_12`, `MAC_TEXTE` ; `longueur_tlv_attendue(t, v)`, `texte_tlv_sur(v)` ;
  - `controler_sous_tlv(o, admis)`, `sous_tlv_prefix(t, v)`, `controler_prefixe(v)`, `controler_service(v)` ; `controler_donnees_reseau(o)` les appelle ;
  - de nouvelles raisons de refus, toutes suivies de « (diag.tlv) » : « TLV N de longueur inattendue » (celles des TLV 0 et 8 ne changent pas), « texte inconnu dans le TLV N », « sous-TLV inconnu d'un Prefix : N », « sous-TLV N de longueur inattendue dans un Prefix », « sous-TLV inconnu d'un Service : N », « Server de longueur inattendue dans la Network Data » ; un Prefix ou un Service coupé : « Network Data tronquee ».
- La charge inventée des tests (`charge_diag()`) avait un TLV 24 (Version) d'un octet : il en a 2, comme dans la capture ; sans ce changement, neuf tests échouent.

- [ ] **Step 1 : écrire les tests.**

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python

def charge_diag():
    """Charge TLV d'un diag de routeur : ExtMac, Address16, Network Data, adresses, version."""
    ext = bytes.fromhex(EXT_ROUTEUR)
    lien_local = ipv6("fe80::")[:8] + bytes([ext[0] ^ 0x02]) + ext[1:]
```

par :

```python

def charge_diag():
    """Charge TLV d'un diag de routeur : ExtMac, Address16, Network Data, adresses, version (2 octets)."""
    ext = bytes.fromhex(EXT_ROUTEUR)
    lien_local = ipv6("fe80::")[:8] + bytes([ext[0] ^ 0x02]) + ext[1:]
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
    rloc = ipv6("%s:0:0:ff:fe00:5000" % PREFIXE_MAILLE)
    return (tlv(0, ext) + tlv(1, bytes.fromhex("5000")) + tlv(7, reseau_inventee()) + tlv(8, lien_local + omr + rloc)
            + tlv(24, b"\x04")).hex().upper()


```

par :

```python
    rloc = ipv6("%s:0:0:ff:fe00:5000" % PREFIXE_MAILLE)
    return (tlv(0, ext) + tlv(1, bytes.fromhex("5000")) + tlv(7, reseau_inventee()) + tlv(8, lien_local + omr + rloc)
            + tlv(24, b"\x00\x04")).hex().upper()


```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
                self.assertEqual(controle(self.diag_avec(tlv(8, bytes(n)))), {})

    # --- Network Data (TLV 7) ---

```

par :

```python
                self.assertEqual(controle(self.diag_avec(tlv(8, bytes(n)))), {})

    def test_tlv_de_longueur_fixe(self):
        """Address16 (1) : 2 octets ; Mode (2) : 1 ; Leader Data (6) : 8 ; Version (24) : 2. Un octet de plus porterait
        un morceau de valeur que l'anonymiseur ne lit pas."""
        for t, n in ((1, 2), (2, 1), (6, 8), (24, 2)):
            self.assertEqual(controle(self.diag_avec(tlv(t, bytes(n)))), {}, t)
            for autre in sorted({0, n - 1, n + 1, 16} - {n}):
                with self.subTest(tlv=t, octets=autre):
                    self.assertEqual(controle(self.diag_avec(tlv(t, bytes(autre)))),
                                     {"TLV %d de longueur inattendue (diag.tlv)" % t: [1]})

    def test_route64_un_octet_par_routeur(self):
        """Route64 (5) : numero de sequence, masque des routeurs (8 octets), puis un octet par routeur du masque."""
        masque = (1 << 63 | 1 << 40 | 1 << 2).to_bytes(8, "big")  # 3 routeurs
        self.assertEqual(controle(self.diag_avec(tlv(5, b"\x01" + masque + bytes(3)))), {})
        self.assertEqual(controle(self.diag_avec(tlv(5, b"\x01" + bytes(8)))), {}, "aucun routeur")
        for nom, charge in (("un octet de trop", b"\x01" + masque + bytes(4)),
                            ("un octet de moins", b"\x01" + masque + bytes(2)),
                            ("masque coupe", b"\x01" + masque[:5]), ("vide", b"")):
            with self.subTest(charge=nom):
                self.assertEqual(controle(self.diag_avec(tlv(5, charge))),
                                 {"TLV 5 de longueur inattendue (diag.tlv)": [1]})

    def test_table_des_enfants_par_entrees_de_3_octets(self):
        for n in (0, 3, 6, 12, 60):
            self.assertEqual(controle(self.diag_avec(tlv(16, bytes(n)))), {}, n)
        for n in (1, 2, 4, 8, 16):
            with self.subTest(octets=n):
                self.assertEqual(controle(self.diag_avec(tlv(16, bytes(n)))),
                                 {"TLV 16 de longueur inattendue (diag.tlv)": [1]})

    def test_texte_des_tlv_25_a_28(self):
        """Fabricant, modele, version logicielle, pile : du texte lisible, sans identifiant. Les versions de pile de la
        capture passent (une date, une heure, un condensat de commit de 9 hexa)."""
        for t, texte in ((25, b""), (25, b"Fabricant"), (26, b"Modele 2"), (27, b"1.4.2"),
                         (28, b"OPENTHREAD/1.0.0; EFR32; May 15 2026 07:09:25"),
                         (28, b"SL-OPENTHREAD/2.5.1.0_GitHub-1fceb225b; EFR32; Sep 18 2024 19:39")):
            with self.subTest(tlv=t, texte=texte):
                self.assertEqual(controle(self.diag_avec(tlv(t, texte))), {})
        for t, texte in ((25, b"Fabricant " + EXT_INCONNU.encode()), (26, b"Modele " + MAC.encode()),
                         (27, b"v" + MAC.encode()), (26, b"de:ad:be:ef:00:01"), (28, b"pile 2001:db8::1 ok"),
                         (28, b"pile fe80::1%wpan0"),
                         (25, b"Fabricant\x00"), (26, "Mod\u00e8le".encode()), (28, b"\xff\xfe")):
            with self.subTest(tlv=t, texte=texte):
                self.assertEqual(controle(self.diag_avec(tlv(t, texte))),
                                 {"texte inconnu dans le TLV %d (diag.tlv)" % t: [1]})

    def test_texte_des_tlv_25_a_28_de_longueur_maximale(self):
        for t, n in ((25, 32), (26, 32), (27, 16), (28, 64)):
            self.assertEqual(controle(self.diag_avec(tlv(t, b"x" * n))), {}, t)
            with self.subTest(tlv=t):
                self.assertEqual(controle(self.diag_avec(tlv(t, b"x" * (n + 1)))),
                                 {"TLV %d de longueur inattendue (diag.tlv)" % t: [1]})

    # --- Network Data (TLV 7) ---

```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
                self.assertEqual(controle(self.diag_avec(tlv(7, reseau))), {"Network Data tronquee (diag.tlv)": [1]})

    def test_les_raisons_de_la_network_data_s_ajoutent_a_celles_du_diag(self):
        inconnu = controle(self.diag_avec(tlv(31, b"\x00") + tlv(7, bytes([0x0D, 0]))))
```

par :

```python
                self.assertEqual(controle(self.diag_avec(tlv(7, reseau))), {"Network Data tronquee (diag.tlv)": [1]})

    def test_sous_tlv_d_un_prefix(self):
        """Has Route (entrees de 3 octets), Border Router (4), 6LoWPAN Context (2) : ceux de la capture. Un autre type,
        ou une autre longueur, pourrait porter une adresse que donnees_reseau() ne remplace pas."""
        def prefixe(*sous):
            return tlv(0x03, bytes([0, 64]) + ipv6(PREFIXE_OMR + "::")[:8] + b"".join(sous))

        for sous in ((), (tlv(0x01, bytes(3)),), (tlv(0x01, bytes(15)),), (tlv(0x00, b""),), (tlv(0x05, bytes(8)),),
                     (tlv(0x05, bytes(4)), tlv(0x07, bytes(2)))):
            with self.subTest(sous=b"".join(sous).hex()):
                self.assertEqual(controle(self.diag_reseau(prefixe(*sous))), {})
        adresse = ipv6("%s:0:%s" % (PREFIXE_OMR, IID_OMR))
        for t in (1, 4, 5, 6, 7, 64, 127):
            with self.subTest(sous_tlv=t):
                self.assertEqual(controle(self.diag_reseau(prefixe(tlv(t << 1 | 1, adresse)))),
                                 {"sous-TLV inconnu d'un Prefix : %d (diag.tlv)" % t: [1]})
        for t, n in ((0, 4), (0, 16), (2, 3), (2, 18), (3, 1), (3, 3), (3, 16)):
            with self.subTest(sous_tlv=t, octets=n):
                self.assertEqual(controle(self.diag_reseau(prefixe(tlv(t << 1 | 1, bytes(n))))),
                                 {"sous-TLV %d de longueur inattendue dans un Prefix (diag.tlv)" % t: [1]})

    def test_server_d_un_service(self):
        """Un RLOC16 seul (2 octets), le serveur SRP (RLOC16, adresse, port : 20 octets, l'adresse remplacee), le
        routeur de dorsale (donnee 01 : 9 octets). Un Server de 12 octets porterait une ExtMac en clair."""
        def service(donnee, *serveurs):
            return tlv(0x0B, b"\x81" + bytes([len(donnee)]) + donnee + b"".join(tlv(0x0D, s) for s in serveurs))

        adresse = ipv6("%s:0:%s" % (PREFIXE_OMR, IID_OMR))
        for nom, reseau in (("RLOC16 seuls", service(b"\x5c\xc5", bytes(2), bytes(2))),
                            ("serveur SRP", service(b"\x5d", b"\x50\x00" + adresse + b"\x16\x80")),
                            ("routeur de dorsale", service(b"\x01", bytes(9))), ("sans Server", service(b"\x5d"))):
            with self.subTest(service=nom):
                self.assertEqual(controle(self.diag_reseau(reseau)), {})
        for nom, reseau in (("ExtMac", service(b"\x5d", b"\x50\x00" + bytes.fromhex(EXT_INCONNU) + b"\x16\x80")),
                            ("9 octets hors dorsale", service(b"\x5d", bytes(9))),
                            ("adresse sans port", service(b"\x5d", b"\x50\x00" + adresse)),
                            ("vide", service(b"\x5d", b""))):
            with self.subTest(service=nom):
                self.assertEqual(controle(self.diag_reseau(reseau)),
                                 {"Server de longueur inattendue dans la Network Data (diag.tlv)": [1]})
        for t in (0, 1, 2, 3, 5, 7, 64):
            with self.subTest(sous_tlv=t):
                reseau = tlv(0x0B, b"\x81\x01\x5d" + tlv(t << 1 | 1, b"\x50\x00"))
                self.assertEqual(controle(self.diag_reseau(reseau)),
                                 {"sous-TLV inconnu d'un Service : %d (diag.tlv)" % t: [1]})

    def test_prefix_ou_service_tronque(self):
        for nom, reseau in (("sous-TLV du Prefix", tlv(0x03, bytes([0, 64]) + bytes(8) + bytes([0x01, 9, 0]))),
                            ("Server", tlv(0x0B, b"\x81\x01\x5d" + bytes([0x0D, 20]) + b"\x50\x00")),
                            ("octets du prefixe", tlv(0x03, bytes([0, 64]) + bytes(4))),
                            ("Prefix vide", tlv(0x03, b"")),
                            ("donnee de service", tlv(0x0B, b"\x81\x02\x5d")), ("Service vide", tlv(0x0B, b""))):
            with self.subTest(reseau=nom):
                self.assertEqual(controle(self.diag_reseau(reseau)), {"Network Data tronquee (diag.tlv)": [1]})

    def test_les_raisons_de_la_network_data_s_ajoutent_a_celles_du_diag(self):
        inconnu = controle(self.diag_avec(tlv(31, b"\x00") + tlv(7, bytes([0x0D, 0]))))
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
        self.assertIn(adresse[8:], anon.Anonymiseur().donnees_reseau(prefixe_tlv(128)))  # l'identifiant d'un /128
        self.assertIn(adresse[:5], anon.Anonymiseur().donnees_reseau(prefixe_tlv(40)))  # les 5 octets d'un /40

    def test_les_tlv_connus_sont_ceux_de_la_capture_actuelle(self):
```

par :

```python
        self.assertIn(adresse[8:], anon.Anonymiseur().donnees_reseau(prefixe_tlv(128)))  # l'identifiant d'un /128
        self.assertIn(adresse[:5], anon.Anonymiseur().donnees_reseau(prefixe_tlv(40)))  # les 5 octets d'un /40
        ext = bytes.fromhex(EXT_INCONNU)  # une ExtMac dans un Server de 12 octets
        serveur = tlv(0x0B, b"\x81\x01\x5d" + tlv(0x0D, b"\x50\x00" + ext + b"\x16\x80"))
        self.assertIn(ext, anon.Anonymiseur().donnees_reseau(serveur))

    def test_les_tlv_connus_sont_ceux_de_la_capture_actuelle(self):
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
                         "prefixe de 17 a 40 bits dans la Network Data (diag.tlv) (1 ligne(s), la premiere : 3)")

    def test_prefixe_128_echoue_sans_rien_ecrire(self):
        """Un /128 (prefixe de documentation, identifiant d'interface invente) : l'identifiant resterait en clair."""
```

par :

```python
                         "prefixe de 17 a 40 bits dans la Network Data (diag.tlv) (1 ligne(s), la premiere : 3)")

    def test_server_de_12_octets_echoue_sans_rien_ecrire(self):
        """Une ExtMac dans un Server : donnees_reseau() ne remplace que l'adresse d'un Server de 18 octets ou plus."""
        messages = capture_inventee()
        serveur = tlv(0x0B, b"\x81\x01\x5d" + tlv(0x0D, b"\x50\x00" + bytes.fromhex(EXT_INCONNU) + b"\x16\x80"))
        messages[2]["tlv"] = tlv(7, reseau_inventee() + serveur).hex().upper()
        self.ecrire(messages)
        self.assertRefus(self.lancer(), "Server de longueur inattendue dans la Network Data (diag.tlv) (1 ligne(s), "
                                        "la premiere : 3)")

    def test_prefixe_128_echoue_sans_rien_ecrire(self):
        """Un /128 (prefixe de documentation, identifiant d'interface invente) : l'identifiant resterait en clair."""
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `python3 -m unittest discover -s sonde/test`
Expected: `Ran 109 tests`, `FAILED (failures=69)` : les neuf tests nouveaux échouent (un échec par sous-test) : `test_tlv_de_longueur_fixe`, `test_route64_un_octet_par_routeur`, `test_table_des_enfants_par_entrees_de_3_octets`, `test_texte_des_tlv_25_a_28`, `test_texte_des_tlv_25_a_28_de_longueur_maximale`, `test_sous_tlv_d_un_prefix`, `test_server_d_un_service`, `test_prefix_ou_service_tronque` et `test_server_de_12_octets_echoue_sans_rien_ecrire`.

- [ ] **Step 3 : écrire le code.**

Dans `outils/anonymiser-sonde.py`, remplacer :

```python
ce qu'il ne connait pas (des noms, jamais une valeur), devant :
- un type de message, un champ ou un TLV inconnu, un TLV a longueur etendue ou
  tronque, un TLV 0 qui n'a pas 8 octets, un TLV 8 qui n'est pas fait
  d'adresses entieres ;
- dans la Network Data (TLV 7), autre chose que des Prefix de 16 bits au plus
  ou de 41 a 96 bits, des Service et une Commissioning Data qui ne porte qu'une
```

par :

```python
ce qu'il ne connait pas (des noms, jamais une valeur), devant :
- un type de message, un champ ou un TLV inconnu, un TLV a longueur etendue ou
  tronque, ou de longueur inattendue : 8 octets pour le TLV 0 (ExtMac), 2 pour
  le 1 (Address16), 1 pour le 2 (Mode), 9 plus un par routeur pour le 5
  (Route64), 8 pour le 6 (Leader Data), des adresses entieres pour le 8, des
  entrees de 3 octets pour le 16 (Child Table), 2 pour le 24 (Version), et au
  plus 32, 32, 16 et 64 pour les textes des TLV 25 a 28 ;
- un texte des TLV 25 a 28 (fabricant, modele, version logicielle, pile) qui
  n'est pas de l'ASCII lisible, ou qui porte 12 hexa de suite, une MAC ou une
  adresse IPv6 ;
- dans la Network Data (TLV 7), autre chose que des Prefix de 16 bits au plus
  ou de 41 a 96 bits, des Service et une Commissioning Data qui ne porte qu'une
```

Dans `outils/anonymiser-sonde.py`, remplacer :

```python
  premiers octets des Prefix, a partir de 41 bits, et l'adresse des Server d'un
  Service ;
- un champ connu qui porte un objet ou une liste (hors parent), ou qui n'est
  pas du texte alors que l'anonymiseur le lit comme un hexa ou une adresse
```

par :

```python
  premiers octets des Prefix, a partir de 41 bits, et l'adresse des Server d'un
  Service ;
- dans un Prefix, autre chose que des Has Route (entrees de 3 octets), des
  Border Router (entrees de 4) et un 6LoWPAN Context (2 octets) ; dans un
  Service, autre chose que des Server, ou un Server qui n'est ni un RLOC16 seul
  (2 octets), ni un RLOC16 suivi d'une adresse et d'un port (20 octets,
  l'adresse remplacee), ni, pour le routeur de dorsale (donnee 01), un RLOC16
  et ses 7 octets de reglages ;
- un champ connu qui porte un objet ou une liste (hors parent), ou qui n'est
  pas du texte alors que l'anonymiseur le lit comme un hexa ou une adresse
```

Dans `outils/anonymiser-sonde.py`, remplacer :

```python
# TLV de diagnostic : 0, 7 et 8 sont traites ; les autres n'ont ni ExtMac ni adresse.
TLV_CONNUS = frozenset({0, 1, 2, 5, 6, 7, 8, 16, 24, 25, 26, 27, 28})
# Network Data (TLV 7), premier niveau : les Prefix (1) et les Service (5) sont traites par donnees_reseau() ; la
# Commissioning Data (4) n'est acceptee que si elle ne porte qu'un sous-TLV Commissioner Session ID (MeshCoP 11,
```

par :

```python
# TLV de diagnostic : 0, 7 et 8 sont traites ; les autres n'ont ni ExtMac ni adresse.
TLV_CONNUS = frozenset({0, 1, 2, 5, 6, 7, 8, 16, 24, 25, 26, 27, 28})
# Longueur exacte : ExtMac (0), Address16 (1), Mode (2), Leader Data (6), Version (24). Un octet de plus porterait un
# morceau de valeur que l'anonymiseur ne lit pas.
TLV_LONGUEUR = {0: 8, 1: 2, 2: 1, 6: 8, 24: 2}
# Faits d'entrees de cette taille : les adresses (8), la Child Table (16). Route64 (5) se lit a part : 9 octets, puis
# un par routeur du masque.
TLV_ENTREES = {8: 16, 16: 3}
# Textes du fabricant (25), du modele (26), de la version logicielle (27) et de la pile (28) : longueur maximale.
TLV_TEXTE_MAX = {25: 32, 26: 32, 27: 16, 28: 64}
# Dans ces textes : 12 hexa de suite (une MAC, une ExtMac), ou une MAC ecrite avec des separateurs. Une version de pile
# porte une date, une heure, parfois un condensat de commit (9 hexa dans la capture) : la limite est a 12.
HEXA_12 = re.compile(r"[0-9A-Fa-f]{12}")
MAC_TEXTE = re.compile(r"[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}")
# Network Data (TLV 7), premier niveau : les Prefix (1) et les Service (5) sont traites par donnees_reseau() ; la
# Commissioning Data (4) n'est acceptee que si elle ne porte qu'un sous-TLV Commissioner Session ID (MeshCoP 11,
```

Dans `outils/anonymiser-sonde.py`, remplacer :

```python


def controler_donnees_reseau(o):
    """Pourquoi la Network Data (TLV 7) n'est pas connue (liste vide si elle l'est) : donnees_reseau() ne remplace
```

par :

```python


def controler_sous_tlv(o, admis):
    """Les sous-TLV d'un Prefix ou d'un Service : `admis(type, valeur)` rend la raison de refuser un sous-TLV, ou
    None s'il est connu. Le bit de poids faible du type est le drapeau "stable"."""
    raisons, i = [], 0
    while i < len(o):
        if i + 2 > len(o) or i + 2 + o[i + 1] > len(o):
            return raisons + ["Network Data tronquee (diag.tlv)"]
        raison = admis(o[i] >> 1, o[i + 2:i + 2 + o[i + 1]])
        if raison:
            raisons.append(raison)
        i += 2 + o[i + 1]
    return raisons


def sous_tlv_prefix(t, v):
    """Has Route (0) : entrees de 3 octets (RLOC16, drapeaux) ; Border Router (2) : entrees de 4 (RLOC16, drapeaux) ;
    6LoWPAN Context (3) : 2 octets (identifiant, longueur). Aucun ne porte d'adresse."""
    if t not in (0, 2, 3):
        return "sous-TLV inconnu d'un Prefix : %d (diag.tlv)" % t
    if (t == 0 and len(v) % 3) or (t == 2 and len(v) % 4) or (t == 3 and len(v) != 2):
        return "sous-TLV %d de longueur inattendue dans un Prefix (diag.tlv)" % t
    return None


def controler_prefixe(v):
    """Un Prefix : domaine, longueur du prefixe en bits, ses octets, puis ses sous-TLV."""
    if len(v) < 2:
        return ["Network Data tronquee (diag.tlv)"]
    if v[1] > PREFIXE_MAX_BITS:
        return ["prefixe de plus de %d bits dans la Network Data (diag.tlv)" % PREFIXE_MAX_BITS]
    if PREFIXE_COURT_MAX_BITS < v[1] < PREFIXE_REMPLACE_MIN_BITS:
        return ["prefixe de %d a %d bits dans la Network Data (diag.tlv)"
                % (PREFIXE_COURT_MAX_BITS + 1, PREFIXE_REMPLACE_MIN_BITS - 1)]
    debut = 2 + (v[1] + 7) // 8
    if debut > len(v):
        return ["Network Data tronquee (diag.tlv)"]
    return controler_sous_tlv(v[debut:], sous_tlv_prefix)


def controler_service(v):
    """Un Service : bit T et identifiant, numero d'entreprise (4 octets) si T est a 0, donnee de service, puis des
    Server seulement. Un Server est un RLOC16 seul (2 octets), un RLOC16 suivi d'une adresse et d'un port (20 octets :
    le serveur SRP, dont donnees_reseau() remplace l'adresse), ou, pour le routeur de dorsale (donnee 01), un RLOC16
    et ses 7 octets de reglages. Un Server de 12 octets porterait une ExtMac en clair."""
    j = 1 if v and v[0] & 0x80 else 5
    if j >= len(v):
        return ["Network Data tronquee (diag.tlv)"]
    if v[j] > DONNEE_SERVICE_MAX:
        return ["donnee de service de plus de %d octets dans la Network Data (diag.tlv)" % DONNEE_SERVICE_MAX]
    donnee = v[j + 1:j + 1 + v[j]]
    if len(donnee) < v[j]:
        return ["Network Data tronquee (diag.tlv)"]

    def admis(t, serveur):
        if t != 6:
            return "sous-TLV inconnu d'un Service : %d (diag.tlv)" % t
        if len(serveur) not in (2, 20) and not (len(serveur) == 9 and donnee == b"\x01"):
            return "Server de longueur inattendue dans la Network Data (diag.tlv)"
        return None

    return controler_sous_tlv(v[j + 1 + v[j]:], admis)


def controler_donnees_reseau(o):
    """Pourquoi la Network Data (TLV 7) n'est pas connue (liste vide si elle l'est) : donnees_reseau() ne remplace
```

Dans `outils/anonymiser-sonde.py`, remplacer :

```python
        if t not in DONNEES_RESEAU_CONNUES:
            raisons.append("sous-TLV inconnu de la Network Data : %d (diag.tlv)" % t)
        elif t == 1 and len(v) >= 2 and v[1] > PREFIXE_MAX_BITS:  # v[1] : longueur du prefixe, en bits
            raisons.append("prefixe de plus de %d bits dans la Network Data (diag.tlv)" % PREFIXE_MAX_BITS)
        elif t == 1 and len(v) >= 2 and PREFIXE_COURT_MAX_BITS < v[1] < PREFIXE_REMPLACE_MIN_BITS:
            raisons.append("prefixe de %d a %d bits dans la Network Data (diag.tlv)"
                           % (PREFIXE_COURT_MAX_BITS + 1, PREFIXE_REMPLACE_MIN_BITS - 1))
        elif t == 4 and not (len(v) == 4 and v[0] == 11 and v[1] == 2):  # un seul sous-TLV, la valeur est libre
            raisons.append("Commissioning Data inconnue dans la Network Data (diag.tlv)")
        elif t == 5 and len(v) >= 1:
            j = 1 if v[0] & 0x80 else 5  # un numero d'entreprise (4 octets) suit si le bit T est a 0
            if j < len(v) and v[j] > DONNEE_SERVICE_MAX:
                raisons.append("donnee de service de plus de %d octets dans la Network Data (diag.tlv)"
                               % DONNEE_SERVICE_MAX)
        i += 2 + n
    return raisons


```

par :

```python
        if t not in DONNEES_RESEAU_CONNUES:
            raisons.append("sous-TLV inconnu de la Network Data : %d (diag.tlv)" % t)
        elif t == 1:
            raisons += controler_prefixe(v)
        elif t == 4 and not (len(v) == 4 and v[0] == 11 and v[1] == 2):  # un seul sous-TLV, la valeur est libre
            raisons.append("Commissioning Data inconnue dans la Network Data (diag.tlv)")
        elif t == 5:
            raisons += controler_service(v)
        i += 2 + n
    return raisons


def longueur_tlv_attendue(t, v):
    """La longueur du TLV connu `t` (voir TLV_LONGUEUR, TLV_ENTREES, TLV_TEXTE_MAX ; la Network Data se lit a part)."""
    if t in TLV_LONGUEUR:
        return len(v) == TLV_LONGUEUR[t]
    if t in TLV_ENTREES:
        return len(v) % TLV_ENTREES[t] == 0
    if t in TLV_TEXTE_MAX:
        return len(v) <= TLV_TEXTE_MAX[t]
    if t == 5:  # numero de sequence, masque des routeurs (64 bits), un octet par routeur du masque
        return len(v) >= 9 and len(v) == 9 + bin(int.from_bytes(v[1:9], "big")).count("1")
    return True


def texte_tlv_sur(v):
    """Le texte d'un TLV 25 a 28 : de l'ASCII lisible, sans 12 hexa de suite, ni MAC, ni adresse IPv6."""
    if any(c < 0x20 or c > 0x7E for c in v):
        return False
    texte = v.decode("ascii")
    if HEXA_12.search(texte) or MAC_TEXTE.search(texte):
        return False
    for mot in re.split(r"[\s;,()\[\]]+", texte):
        if ":" in mot:
            try:
                ipaddress.IPv6Address(mot.split("%")[0])
                return False
            except ValueError:
                pass
    return True


```

Dans `outils/anonymiser-sonde.py`, remplacer :

```python
        if i + 2 + n > len(o):
            return raisons + ["TLV tronque (diag.tlv)"]
        if t not in TLV_CONNUS:
            raisons.append("TLV inconnu : %d (diag.tlv)" % t)
        elif t == 0 and n != 8:
            raisons.append("TLV 0 de longueur inattendue (diag.tlv)")
        elif t == 8 and n % 16 != 0:
            raisons.append("TLV 8 de longueur inattendue (diag.tlv)")
        elif t == 7:
            raisons += controler_donnees_reseau(o[i + 2:i + 2 + n])
        i += 2 + n
    return raisons
```

par :

```python
        if i + 2 + n > len(o):
            return raisons + ["TLV tronque (diag.tlv)"]
        v = o[i + 2:i + 2 + n]
        if t not in TLV_CONNUS:
            raisons.append("TLV inconnu : %d (diag.tlv)" % t)
        elif not longueur_tlv_attendue(t, v):
            raisons.append("TLV %d de longueur inattendue (diag.tlv)" % t)
        elif t == 7:
            raisons += controler_donnees_reseau(v)
        elif t in TLV_TEXTE_MAX and not texte_tlv_sur(v):
            raisons.append("texte inconnu dans le TLV %d (diag.tlv)" % t)
        i += 2 + n
    return raisons
```

- [ ] **Step 4 : vérifier qu'ils passent, sous les deux Python.**

Run: `python3 -m unittest discover -s sonde/test && /usr/bin/python3 -m unittest discover -s sonde/test`
Expected: `Ran 109 tests`, `OK`, sous les deux Python (au rejeu : 3.11.7 et 3.9.6) ; 9 tests de plus qu'avant la tâche (100).

La suite Swift ne change pas : rien à y relancer.

- [ ] **Step 5 : commit.**

```bash
git add outils/anonymiser-sonde.py sonde/test/test_anonymiseur.py
git commit -m "Controler la longueur des TLV et le contenu des Prefix et des Service dans l'anonymiseur

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 12: Anonymiseur : les messages de la sonde 1.0.3 et les captures déjà anonymisées

**Files:**
- Modify: `outils/anonymiser-sonde.py` (fichier entier : les tables, la garde et les remplacements changent ensemble)
- Test: `sonde/test/test_anonymiseur.py` (blocs ci-dessous)

**Interfaces:**
- Consumes : la tâche 11 ; les messages du firmware 1.0.3 (`sonde/src/main.cpp` : `bonjour`, `etat`, `voisins`, `routeurs`, `diag`, `cle`, `oubli`, `erreur`, et les réponses « occupée »), tels que `sonde/sonde_essai.py` les capture (clé masquée en `(masquee)`, `heure` ajoutée) ; les valeurs factices de la capture du dépôt (`E0…`, `0A00…`, `fd00:1111:2222`…, `A0A1A2A3A4A5A6A7`, `A0…`).
- Produces :
  - `CHAMPS_COMMUNS` et `CHAMPS_CONNUS` deviennent des dictionnaires champ → forme (`texte`, `remplace`, `efface`, `nombre`, `booleen`, `rloc16`, `partition`, `heure`, `tlv`, `objet X`, `liste X`, et `?` pour null) ; `OBJETS` (`parent`, `voisin`, `routeur`, `udp` avec `refus_cadence`, `tas`) ; `FORMES`, `texte_sur(x)`, `TEXTE_SUR`, `HEXA_8` ; `CHAMPS_PARENT`, `CHAMPS_TEXTE` et `CHAMPS_PARENT_TEXTE` disparaissent ;
  - `Anonymiseur.factice(table, reel, nieme, deja_factice)` : une valeur déjà factice reste elle-même, une valeur réelle reçoit une factice qui n'a pas encore servi ; `hexa_ext`, `mac`, `nom`, `empreinte` ; les tables `noms`, `empreintes`, `cles` ; `p48_factice(n)`, `P48_FACTICES`, `XP_FACTICE`, `MASQUEE`, `remplaces(table)` ;
  - `message()` remplace `etat.ext`, `bonjour.nom` (`SONDE-01`…), `bonjour.hote` et `cle.hote` (la factice de l'ExtMac), l'`ext` des `voisins` et des `routeurs`, l'`empreinte` (`C1E0…`) et la `cle` (`(masquee)`) de `cle` ; une cible qui n'est ni un RLOC16 ni une adresse, un nom d'hôte qui n'est pas de l'hexa, un préfixe du réseau maillé trop court : la ligne est refusée, avec son seul numéro ;
  - le bilan ne compte que les valeurs remplacées : sur la capture du dépôt, « 64 lignes ; 0 ExtMac, 0 identifiants, 0 prefixes /48 remplaces », et le fichier ressort identique (le lot 6 le trouvait en échec : « fuite : 36 valeur(s) »).
- Tests changés : la garde ne refuse plus `etat.ext`, `voisins`… ; les exemples de champ et de type inconnus deviennent `etat.adresse` et `journal`. Le rapport du lot 6 citait deux tests à changer : en tout, dix tests citaient un champ ou un type de la 1.0.2 comme inconnu ; de plus, `test_scalaires_de_tout_type_passent` ne tient plus (un rôle doit être un texte sûr) et `test_aucun_nom_des_tables_n_est_masque_par_nom_sur` lit les nouvelles tables. Remplacés : `test_champs_apparus_depuis_la_capture_font_echouer` (par `test_une_capture_de_la_sonde_1_0_3_passe` et `test_champ_inconnu_fait_echouer`), `test_scalaires_de_tout_type_passent` (par quatre tests de forme), `test_une_capture_1_0_2_est_refusee` (par `test_capture_1_0_3_anonymisee_sans_valeur_reelle`), `test_la_garde_ne_refuse_pas_la_capture_actuelle` (par `test_la_capture_du_depot_ressort_telle_quelle`).
- `sonde/test/test_sonde_essai.py` ne change pas : cinq de ses tests lisent la réponse 206 de la capture du dépôt, que ce plan ne touche pas.

- [ ] **Step 1 : écrire les tests.**

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
#!/usr/bin/env python3
"""Tests de la garde de outils/anonymiser-sonde.py.

  python3 sonde/test/test_anonymiseur.py
  python3 -m unittest discover -s sonde/test        (tous les tests Python, depuis la racine du depot)

La garde : l'anonymiseur ne connait que les messages bonjour, etat et diag de la capture du 29/09/2026.
Tout autre type de message, champ ou TLV le fait echouer avant toute ecriture, avec un message clair
qui ne cite que des noms, jamais une valeur. Une capture de la sonde 1.0.2 (etat.ext, bonjour.hote,
voisins...) est donc refusee.

Donnees inventees : les valeurs "reelles" de la capture brute ci-dessous n'ont jamais existe (ExtMac
DEADBEEF..., prefixes de documentation 2001:db8). La capture anonymisee du depot sert de reference.
"""
```

par :

```python
#!/usr/bin/env python3
"""Tests de outils/anonymiser-sonde.py : sa garde, ses remplacements, l'outil lance comme on le lance.

  python3 sonde/test/test_anonymiseur.py
  python3 -m unittest discover -s sonde/test        (tous les tests Python, depuis la racine du depot)

La garde : l'anonymiseur ne connait que les messages de la sonde 1.0.3 et ceux de la capture du 29/09/2026,
avec la forme de chaque champ. Tout autre type de message, champ, forme ou TLV le fait echouer avant toute
ecriture, avec un message clair qui ne cite que des noms, jamais une valeur. Une capture deja anonymisee
ressort telle quelle.

Donnees inventees : les valeurs "reelles" des captures brutes ci-dessous n'ont jamais existe (ExtMac
DEADBEEF..., prefixes de documentation 2001:db8). La capture anonymisee du depot sert de reference.
"""
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
import json
import os
import subprocess
import sys
```

par :

```python
import json
import os
import shutil
import subprocess
import sys
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
_spec.loader.exec_module(anon)

# Valeurs "reelles" inventees de la capture brute.
EXT_PARENT = "DEADBEEF00000001"
EXT_ROUTEUR = "DEADBEEF00000002"
EXT_INCONNU = "DEADBEEF00000003"  # celle d'un champ que l'anonymiseur ne connait pas
XP = "FEEDFACECAFEBEEF"
MAC = "DEADBEEF0001"
```

par :

```python
_spec.loader.exec_module(anon)

# Valeurs "reelles" inventees des captures brutes.
EXT_PARENT = "DEADBEEF00000001"
EXT_ROUTEUR = "DEADBEEF00000002"
EXT_INCONNU = "DEADBEEF00000003"  # celle d'un champ que l'anonymiseur ne connait pas
EXT_SONDE = "DEADBEEF00000004"  # celle de la sonde, dont Matter tire le nom d'hote SRP
XP = "FEEDFACECAFEBEEF"
MAC = "DEADBEEF0001"
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
PREFIXE_MAILLE, PREFIXE_OMR = "2001:db8:a1b2", "2001:db8:c3d4"
IID_OMR = "aabb:ccdd:eeff:1122"
# Tout ce qui ne doit plus se lire dans une sortie (minuscules, sans deux-points).
REEL = [EXT_PARENT, EXT_ROUTEUR, EXT_INCONNU, XP, MAC, CODE, "FAUX0000000000000000", "20010db8a1b2", "20010db8c3d4",
        "aabbccddeeff1122", "dcadbeef00000002"]  # dernier : l'IID lien-local de EXT_ROUTEUR (bit U/L inverse)


```

par :

```python
PREFIXE_MAILLE, PREFIXE_OMR = "2001:db8:a1b2", "2001:db8:c3d4"
IID_OMR = "aabb:ccdd:eeff:1122"
NOM, EMPREINTE = "Sonde-du-salon", "FEEDF00D"
CLE = "0123456789ABCDEF" * 4
# Tout ce qui ne doit plus se lire dans une sortie (minuscules, sans deux-points).
REEL = [EXT_PARENT, EXT_ROUTEUR, EXT_INCONNU, EXT_SONDE, XP, MAC, CODE, "FAUX0000000000000000", "20010db8a1b2",
        "20010db8c3d4", "aabbccddeeff1122", NOM, EMPREINTE, CLE,
        "dcadbeef00000002"]  # dernier : l'IID lien-local de EXT_ROUTEUR (bit U/L inverse)


```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python


def controle(*messages):
    """La garde sur ces messages, numerotes a partir de 1."""
```

par :

```python


def capture_1_0_3():
    """Une capture brute inventee de la sonde 1.0.3, de la forme que sonde_essai.py ecrit : chaque type de message,
    les reponses « occupee », la cle deja masquee."""
    compteurs = {"port": 5480, "ouvert": True, "sessions": 1, "provisoire": False, "rx": 120, "rejets": 0,
                 "rx_perdus": 0, "defis": 1, "tx": 118, "tx_perdus": 0, "tx_erreurs": 0, "tampons_min": 22,
                 "lignes_perdues": 0, "refus_cadence": 2}
    return [
        {"heure": "2026-10-01T10:00:00", "t": "bonjour", "v": 1, "produit": "sonde-maillage", "version": "1.0.3",
         "nom": NOM, "mac": MAC, "appairee": True, "code": CODE, "qr": QR, "hote": EXT_SONDE},
        {"heure": "2026-10-01T10:00:01", "t": "etat", "v": 1, "role": "child", "rloc16": "5005", "ext": EXT_SONDE,
         "mode": "rn", "eligible": False,
         "parent": {"rloc16": "5000", "ext": EXT_PARENT, "lqIn": 3, "lqOut": 3, "rssi": -60},
         "partition": "1A2B3C4D", "chef": 24, "canal": 15, "prefixeMaille": "20010DB8A1B20000", "xp": XP,
         "suspendue": False},
        {"heure": "2026-10-01T10:00:02", "t": "etat", "v": 1, "erreur": "occupee"},
        {"heure": "2026-10-01T10:00:03", "t": "routeurs", "v": 1,
         "liste": [{"id": 20, "rloc16": "5000", "ext": EXT_PARENT, "lqIn": 3, "lqOut": 3, "age": 4, "lien": True},
                   {"id": 24, "rloc16": "6000", "ext": None, "lqIn": 0, "lqOut": 0, "age": 30, "lien": False}],
         "suite": False},
        {"heure": "2026-10-01T10:00:04", "t": "voisins", "v": 1,
         "liste": [{"rloc16": "5000", "ext": EXT_PARENT, "rssi": -60, "lqi": 3, "routeur": True},
                   {"rloc16": "6000", "ext": EXT_ROUTEUR, "rssi": -82, "lqi": 1, "routeur": True}]},
        {"heure": "2026-10-01T10:00:05", "t": "voisins", "v": 1, "erreur": "occupee"},
        {"heure": "2026-10-01T10:00:06", "t": "diag", "v": 1, "id": 101, "cible": "5000", "ms": 64, "ok": True,
         "code": "2.04", "tlv": charge_diag(), "tronquee": True},
        {"heure": "2026-10-01T10:00:07", "t": "cle", "v": 1, "empreinte": EMPREINTE, "effacement_en_echec": False,
         "hote": EXT_SONDE, "udp": compteurs, "tas": {"libre": 181234, "min": 160112}},
        {"heure": "2026-10-01T10:00:08", "t": "cle", "v": 1, "id": 7, "cle": "(masquee)", "empreinte": EMPREINTE,
         "hote": EXT_SONDE, "msg": "cle non chargee : active au redemarrage"},
        {"heure": "2026-10-01T10:00:09", "t": "erreur", "v": 1, "erreur": "commande inconnue"},
        {"heure": "2026-10-01T10:00:10", "t": "oubli", "v": 1, "cle_effacee": True},
    ]


def controle(*messages):
    """La garde sur ces messages, numerotes a partir de 1."""
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
        self.assertEqual(controle(*capture_inventee()), {})

    def test_champs_apparus_depuis_la_capture_font_echouer(self):
        """Les champs que le firmware 1.0.2 ecrit et que la capture du 29/09 n'a pas."""
        de_base = {m["t"]: m for m in capture_inventee()}
        for t, champ in (("etat", "ext"), ("etat", "eligible"), ("bonjour", "nom"), ("bonjour", "hote"),
                         ("diag", "tronquee"), ("etat", "liste"), ("diag", "cle")):
            with self.subTest(champ="%s.%s" % (t, champ)):
                self.assertEqual(controle(dict(de_base[t], **{champ: EXT_INCONNU})),
                                 {"champ inconnu : %s.%s" % (t, champ): [1]})

    def test_champ_inconnu_du_parent(self):
```

par :

```python
        self.assertEqual(controle(*capture_inventee()), {})

    def test_une_capture_de_la_sonde_1_0_3_passe(self):
        """Tous les messages de la 1.0.3 : etat.ext et eligible, bonjour.nom et hote, voisins, routeurs, cle (et
        refus_cadence), oubli, erreur, diag.tronquee, et les reponses « occupee »."""
        self.assertEqual(controle(*capture_1_0_3()), {})

    def test_champ_inconnu_fait_echouer(self):
        de_base = {m["t"]: m for m in capture_1_0_3()}
        for t, champ in (("etat", "adresse"), ("etat", "liste"), ("diag", "cle"), ("bonjour", "adresse"),
                         ("voisins", "suite"), ("routeurs", "hote"), ("cle", "nom"), ("oubli", "cle"),
                         ("erreur", "msg")):
            with self.subTest(champ="%s.%s" % (t, champ)):
                self.assertEqual(controle(dict(de_base[t], **{champ: EXT_INCONNU})),
                                 {"champ inconnu : %s.%s" % (t, champ): [1]})

    def test_champ_inconnu_d_un_voisin_d_un_routeur_ou_des_compteurs(self):
        capture = capture_1_0_3()
        routeurs, voisins, cle = capture[3], capture[4], capture[7]
        for message, chemin in ((dict(voisins, liste=[dict(voisins["liste"][0], bssid=EXT_INCONNU)]), "voisins.liste"),
                                (dict(routeurs, liste=[dict(routeurs["liste"][1], nom=EXT_INCONNU)]), "routeurs.liste"),
                                (dict(cle, udp=dict(cle["udp"], adresse=EXT_INCONNU)), "cle.udp"),
                                (dict(cle, tas=dict(cle["tas"], total=5)), "cle.tas")):
            with self.subTest(chemin=chemin):
                (raison,) = controle(message)
                self.assertTrue(raison.startswith("champ inconnu : %s." % chemin), raison)

    def test_listes_et_objets_de_forme_inconnue(self):
        capture = capture_1_0_3()
        routeurs, voisins, cle = capture[3], capture[4], capture[7]
        for liste in ({}, "x", [1], [[]], [EXT_INCONNU], None):
            with self.subTest(liste=liste):
                self.assertEqual(controle(dict(voisins, liste=liste)), {"forme inconnue : voisins.liste": [1]})
        for udp in ([], "x", 5, None):
            with self.subTest(udp=udp):
                self.assertEqual(controle(dict(cle, udp=udp)), {"forme inconnue : cle.udp": [1]})
        sans_ext = dict(voisins["liste"][0], ext=None)  # un voisin a toujours une ExtMac ; un routeur, pas toujours
        self.assertEqual(controle(dict(voisins, liste=[sans_ext])), {"forme inconnue : voisins.liste.ext": [1]})
        self.assertEqual(controle(dict(routeurs, liste=[dict(routeurs["liste"][0], ext=None)])), {})
        self.assertEqual(controle(dict(voisins, liste=[])), {})

    def test_champ_inconnu_du_parent(self):
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
                self.assertEqual(controle(dict(etat, parent=parent)), {"forme inconnue : etat.parent.ext": [1]})

    def test_scalaires_de_tout_type_passent(self):
        etat = capture_inventee()[1]
        for valeur in ("x", "", 0, -5, 1.5, True, None):
            with self.subTest(valeur=valeur):
                self.assertEqual(controle(dict(etat, role=valeur)), {})

    def test_une_raison_repetee_sur_une_meme_ligne_compte_une_fois(self):
```

par :

```python
                self.assertEqual(controle(dict(etat, parent=parent)), {"forme inconnue : etat.parent.ext": [1]})

    def test_texte_libre_sur(self):
        """role, mode, produit, version, erreur, msg, code d'un diag : gardes tels quels, donc sans rien qui
        identifie. 64 caracteres au plus ; jamais 8 hexa de suite, ni une adresse ou une MAC."""
        etat = capture_inventee()[1]
        for valeur in ("child", "leader", "", "x", "rdn", "cle non chargee : active au redemarrage", "envoi NoBufs",
                       "trop_long", "0.1.0-essai", "2.04", "x" * 64, "ResponseTimeout"):
            with self.subTest(valeur=valeur):
                self.assertEqual(controle(dict(etat, role=valeur)), {})
        for valeur in (0, -5, 1.5, True, None, "x" * 65, "DEADBEEF", "x" + MAC, "2001:db8::1", "fe80::1", "a:b",
                       "de:ad:be:ef:00:01", "r\u00f4le", "deux\nlignes", "a/b", "nom@exemple"):
            with self.subTest(valeur=valeur):
                self.assertEqual(controle(dict(etat, role=valeur)), {"forme inconnue : etat.role": [1]})

    def test_nombres_entiers_de_32_bits(self):
        """Une ExtMac tient dans un entier de 64 bits : un nombre n'en porte pas plus de 32."""
        etat = capture_inventee()[1]
        for valeur in (-60, 0, 127, (1 << 32) - 1, -(1 << 31)):
            with self.subTest(valeur=valeur):
                self.assertEqual(controle(dict(etat, parent=dict(etat["parent"], rssi=valeur))), {})
        for valeur in (1 << 32, -(1 << 31) - 1, int(EXT_INCONNU, 16), 1.5, True, "5", None):
            with self.subTest(valeur=valeur):
                self.assertEqual(controle(dict(etat, parent=dict(etat["parent"], rssi=valeur))),
                                 {"forme inconnue : etat.parent.rssi": [1]})

    def test_rloc16_partition_et_heure(self):
        etat = capture_inventee()[1]
        for champ, bonnes, mauvaises in (
                ("rloc16", ("5005", "FFFE", "abcd"), ("5", "50050", "ZZZZ", 5005, None)),
                ("partition", ("1A2B3C4D", None), ("1A2B3C4", "1A2B3C4D5", 12)),
                ("heure", ("2026-09-28T23:44:56",), ("2026-09-28 23:44:56", "hier", "2026-09-28T23:44:56Z", 0))):
            for valeur in bonnes:
                with self.subTest(champ=champ, valeur=valeur):
                    self.assertEqual(controle(dict(etat, **{champ: valeur})), {})
            for valeur in mauvaises:
                with self.subTest(champ=champ, valeur=valeur):
                    self.assertEqual(controle(dict(etat, **{champ: valeur})), {"forme inconnue : etat.%s" % champ: [1]})

    def test_champs_effaces_acceptent_tout_scalaire(self):
        """Code d'appairage, QR code, cle : jamais recopies, leur valeur ne compte pas ; un objet ou une liste, si."""
        bonjour, cle = capture_1_0_3()[0], capture_1_0_3()[8]
        for valeur in (CODE, "", 5, True, None):
            with self.subTest(valeur=valeur):
                self.assertEqual(controle(dict(bonjour, code=valeur)), {})
        for valeur in ({"a": 1}, [CODE]):
            with self.subTest(valeur=valeur):
                self.assertEqual(controle(dict(bonjour, code=valeur)), {"forme inconnue : bonjour.code": [1]})
        self.assertEqual(controle(dict(cle, cle=CLE)), {})

    def test_une_raison_repetee_sur_une_meme_ligne_compte_une_fois(self):
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python

    def test_type_de_message_inconnu_fait_echouer(self):
        """voisins et routeurs (1.0.2), cle, erreur, oubli, et tout ce qui n'est pas un nom de type lisible."""
        for t in ("voisins", "routeurs", "cle", "erreur", "oubli", "inconnu", "ETAT", ""):
            with self.subTest(t=t):
                attendu = "type de message inconnu : %s" % (t or "(illisible)")
```

par :

```python

    def test_type_de_message_inconnu_fait_echouer(self):
        """Un type que la sonde 1.0.3 n'ecrit pas, et tout ce qui n'est pas un nom de type lisible."""
        for t in ("journal", "inconnu", "ETAT", "Bonjour", "voisin", ""):
            with self.subTest(t=t):
                attendu = "type de message inconnu : %s" % (t or "(illisible)")
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python

    def test_type_inconnu_ne_dit_rien_de_ses_champs(self):
        self.assertEqual(controle({"t": "voisins", "v": 1, "liste": [{"ext": EXT_INCONNU}]}),
                         {"type de message inconnu : voisins": [1]})

    def test_ligne_qui_n_est_pas_un_objet(self):
```

par :

```python

    def test_type_inconnu_ne_dit_rien_de_ses_champs(self):
        self.assertEqual(controle({"t": "journal", "v": 1, "liste": [{"ext": EXT_INCONNU}]}),
                         {"type de message inconnu : journal": [1]})

    def test_ligne_qui_n_est_pas_un_objet(self):
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python

    def test_raisons_regroupees_avec_les_numeros_de_ligne(self):
        etat = dict(capture_inventee()[1], ext=EXT_INCONNU)
        ok = capture_inventee()[0]
        inconnu = anon.controler([(2, etat), (5, ok), (9, etat), (12, {"t": "voisins"})])
        self.assertEqual(inconnu, {"champ inconnu : etat.ext": [2, 9], "type de message inconnu : voisins": [12]})
        self.assertEqual(list(inconnu), ["champ inconnu : etat.ext", "type de message inconnu : voisins"])

    # --- TLV du diag ---
```

par :

```python

    def test_raisons_regroupees_avec_les_numeros_de_ligne(self):
        etat = dict(capture_inventee()[1], adresse=EXT_INCONNU)
        ok = capture_inventee()[0]
        inconnu = anon.controler([(2, etat), (5, ok), (9, etat), (12, {"t": "journal"})])
        self.assertEqual(inconnu, {"champ inconnu : etat.adresse": [2, 9], "type de message inconnu : journal": [12]})
        self.assertEqual(list(inconnu), ["champ inconnu : etat.adresse", "type de message inconnu : journal"])

    # --- TLV du diag ---
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python

    def test_aucun_nom_des_tables_n_est_masque_par_nom_sur(self):
        """Les noms connus, et ceux que la 1.0.2 ajoute, restent lisibles dans le refus."""
        noms = set(anon.CHAMPS_COMMUNS) | set(anon.CHAMPS_PARENT) | set(anon.CHAMPS_CONNUS)
        for champs in anon.CHAMPS_CONNUS.values():
            noms |= champs
        noms |= {"ext", "eligible", "nom", "hote", "tronquee", "liste", "suite", "voisins", "routeurs", "cle",
                 "oubli", "erreur", "cle_effacee", "effacement_en_echec"}
        for nom in sorted(noms):
            self.assertEqual(anon.nom_sur(nom), nom)
```

par :

```python

    def test_aucun_nom_des_tables_n_est_masque_par_nom_sur(self):
        """Les noms connus (types, champs, objets) restent lisibles dans le refus."""
        noms = set(anon.CHAMPS_COMMUNS) | set(anon.CHAMPS_CONNUS) | set(anon.OBJETS)
        for champs in list(anon.CHAMPS_CONNUS.values()) + list(anon.OBJETS.values()):
            noms |= set(champs)
        self.assertIn("refus_cadence", noms)
        for nom in sorted(noms):
            self.assertEqual(anon.nom_sur(nom), nom)
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
    def test_le_texte_de_refus_ne_cite_que_des_noms(self):
        """Ni valeur de champ, ni nom abime qui porterait une ExtMac."""
        etat = dict(capture_inventee()[1], ext=EXT_INCONNU)
        etat[EXT_INCONNU] = EXT_ROUTEUR
        texte = anon.texte_refus(anon.controler([(3, etat), (8, {"t": "voisins", "liste": [{"ext": EXT_INCONNU}]})]))
        for valeur in (EXT_INCONNU, EXT_ROUTEUR, XP, MAC):
            self.assertNotIn(valeur.lower(), texte.lower())
        self.assertEqual(texte.splitlines()[0], "refus : la capture contient ce que l'anonymiseur ne connait pas ; "
                                                "rien n'a ete ecrit.")
        self.assertIn("  champ inconnu : etat.ext (1 ligne(s), la premiere : 3)", texte)
        self.assertIn("  champ inconnu : etat.(illisible) (1 ligne(s), la premiere : 3)", texte)
        self.assertIn("  type de message inconnu : voisins (1 ligne(s), la premiere : 8)", texte)
        self.assertIn("CHAMPS_CONNUS", texte.splitlines()[-1])


```

par :

```python
    def test_le_texte_de_refus_ne_cite_que_des_noms(self):
        """Ni valeur de champ, ni nom abime qui porterait une ExtMac."""
        etat = dict(capture_inventee()[1], adresse=EXT_INCONNU)
        etat[EXT_INCONNU] = EXT_ROUTEUR
        texte = anon.texte_refus(anon.controler([(3, etat), (8, {"t": "journal", "liste": [{"ext": EXT_INCONNU}]})]))
        for valeur in (EXT_INCONNU, EXT_ROUTEUR, XP, MAC):
            self.assertNotIn(valeur.lower(), texte.lower())
        self.assertEqual(texte.splitlines()[0], "refus : la capture contient ce que l'anonymiseur ne connait pas ; "
                                                "rien n'a ete ecrit.")
        self.assertIn("  champ inconnu : etat.adresse (1 ligne(s), la premiere : 3)", texte)
        self.assertIn("  champ inconnu : etat.(illisible) (1 ligne(s), la premiere : 3)", texte)
        self.assertIn("  type de message inconnu : journal (1 ligne(s), la premiere : 8)", texte)
        self.assertIn("CHAMPS_CONNUS", texte.splitlines()[-1])


# ---------------------------------------------------------------------------
#  Les remplacements, sans lancer l'outil
# ---------------------------------------------------------------------------


class Remplacement(unittest.TestCase):
    def test_une_valeur_deja_factice_reste_elle_meme(self):
        """Dans le desordre aussi : la factice n'est pas renumerotee (elle le serait par ordre d'apparition)."""
        a = anon.Anonymiseur()
        for valeur in ("E000000000000002", "E000000000000001"):
            self.assertEqual(a.hexa_ext(valeur), valeur)
        self.assertEqual(a.iid(bytes.fromhex("0A00000000000003")), bytes.fromhex("0A00000000000003"))
        self.assertEqual(a.prefixe48(anon.p48_factice(3)), anon.p48_factice(3))
        self.assertEqual((a.mac("A00000000002"), a.nom("SONDE-04"), a.empreinte("C1E00002")),
                         ("A00000000002", "SONDE-04", "C1E00002"))
        self.assertEqual(a.message({"t": "etat", "xp": anon.XP_FACTICE})["xp"], anon.XP_FACTICE)
        self.assertEqual(a.secrets(), set(), "une valeur deja factice n'est pas une valeur reelle")

    def test_une_valeur_reelle_ne_recoit_pas_une_factice_deja_donnee(self):
        a = anon.Anonymiseur()
        a.hexa_ext("E000000000000002")
        self.assertEqual(a.hexa_ext(EXT_PARENT), "E000000000000003")
        a.nom("SONDE-02")
        self.assertEqual(a.nom(NOM), "SONDE-03")

    def test_le_nom_d_hote_suit_l_ext_de_la_sonde(self):
        """Matter tire le nom d'hote SRP de l'ExtMac : les deux ont la meme factice, dans l'ordre ou ils viennent."""
        a = anon.Anonymiseur()
        hote = a.message({"t": "bonjour", "hote": EXT_SONDE})["hote"]
        self.assertEqual(a.message({"t": "etat", "ext": EXT_SONDE})["ext"], hote)
        self.assertEqual(a.message({"t": "cle", "hote": EXT_SONDE.lower()})["hote"], hote)

    def test_la_cle_en_clair_est_masquee_et_cherchee_dans_la_sortie(self):
        a = anon.Anonymiseur()
        self.assertEqual(a.message({"t": "cle", "cle": CLE})["cle"], "(masquee)")
        self.assertEqual(a.message({"t": "cle", "cle": "(masquee)"})["cle"], "(masquee)")
        self.assertIn(CLE.lower(), a.secrets())


```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
    def test_champ_inconnu_echoue_sans_rien_ecrire(self):
        messages = capture_inventee()
        messages[1]["ext"] = EXT_INCONNU
        self.ecrire(messages)
        self.assertRefus(self.lancer(), "champ inconnu : etat.ext (1 ligne(s), la premiere : 2)")

    def test_type_de_message_inconnu_echoue_sans_rien_ecrire(self):
        messages = capture_inventee()
        messages.insert(2, {"heure": "2026-09-28T23:45:00", "t": "voisins", "v": 1,
                            "liste": [{"rloc16": "5000", "ext": EXT_INCONNU, "rssi": -60, "lqi": 3, "routeur": True}]})
        self.ecrire(messages)
        self.assertRefus(self.lancer(), "type de message inconnu : voisins (1 ligne(s), la premiere : 3)")

    def test_tlv_inconnu_echoue_sans_rien_ecrire(self):
```

par :

```python
    def test_champ_inconnu_echoue_sans_rien_ecrire(self):
        messages = capture_inventee()
        messages[1]["adresse"] = EXT_INCONNU
        self.ecrire(messages)
        self.assertRefus(self.lancer(), "champ inconnu : etat.adresse (1 ligne(s), la premiere : 2)")

    def test_type_de_message_inconnu_echoue_sans_rien_ecrire(self):
        messages = capture_inventee()
        messages.insert(2, {"heure": "2026-09-28T23:45:00", "t": "journal", "v": 1,
                            "liste": [{"rloc16": "5000", "ext": EXT_INCONNU, "rssi": -60, "lqi": 3, "routeur": True}]})
        self.ecrire(messages)
        self.assertRefus(self.lancer(), "type de message inconnu : journal (1 ligne(s), la premiere : 3)")

    def test_tlv_inconnu_echoue_sans_rien_ecrire(self):
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
                if fragment:
                    self.assertNotIn(fragment.lower(), r.stderr.lower())

    def test_une_exception_de_l_anonymisation_sort_avec_le_seul_numero_de_ligne(self):
```

par :

```python
                if fragment:
                    self.assertNotIn(fragment.lower(), r.stderr.lower())

    def test_valeur_illisible_de_la_sonde_1_0_3(self):
        """Un nom d'hote qui n'est pas de l'hexa, une ExtMac abimee, une cible ni RLOC16 ni adresse, un prefixe du
        reseau maille trop court : le seul numero de ligne."""
        abimee = "ZZ" + EXT_SONDE[2:]
        cas = ((1, lambda m: m.update(hote="sonde-" + EXT_SONDE[:6])), (2, lambda m: m.update(ext=abimee)),
               (2, lambda m: m.update(prefixeMaille="20010DB8")),
               (5, lambda m: m["liste"][1].update(ext=abimee)), (7, lambda m: m.update(cible="zz" + EXT_SONDE[:8])))
        for numero, abimer in cas:
            with self.subTest(ligne=numero):
                messages = capture_1_0_3()
                abimer(messages[numero - 1])
                self.ecrire(messages)
                r = self.lancer()
                self.assertRefus(r, "la ligne %d porte une valeur que l'anonymiseur ne sait pas lire" % numero)
                self.assertNotIn(EXT_SONDE[:6].lower(), r.stderr.lower())

    def test_une_exception_de_l_anonymisation_sort_avec_le_seul_numero_de_ligne(self):
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
                         "prefixe de plus de 96 bits dans la Network Data (diag.tlv) (1 ligne(s), la premiere : 3)")

    def test_une_capture_1_0_2_est_refusee(self):
        """Ce que la sonde 1.0.2 ecrit en plus : hote et nom, etat.ext et eligible, voisins, routeurs."""
        messages = capture_inventee()
        messages[0].update(nom="Sonde", hote="sonde-ab12")
        messages[1].update(ext=EXT_INCONNU, eligible=False)
        messages += [{"t": "voisins", "v": 1, "liste": []}, {"t": "routeurs", "v": 1, "liste": [], "suite": False}]
        self.ecrire(messages)
        r = self.lancer()
        self.assertRefus(r, "champ inconnu : bonjour.nom", "champ inconnu : bonjour.hote", "champ inconnu : etat.ext",
                         "champ inconnu : etat.eligible", "type de message inconnu : voisins",
                         "type de message inconnu : routeurs")

    def test_ne_touche_pas_a_une_sortie_qui_existe(self):
        messages = capture_inventee()
        messages[1]["ext"] = EXT_INCONNU
        self.ecrire(messages)
        with open(self.sortie, "w", encoding="utf-8") as f:
```

par :

```python
                         "prefixe de plus de 96 bits dans la Network Data (diag.tlv) (1 ligne(s), la premiere : 3)")

    def test_capture_1_0_3_anonymisee_sans_valeur_reelle(self):
        messages = capture_1_0_3()
        messages[8]["cle"] = CLE  # en clair : une capture qui ne viendrait pas de sonde_essai.py
        self.ecrire(messages)
        r = self.lancer()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(r.stdout.startswith("11 lignes ;"), r.stdout)
        with open(self.sortie, encoding="utf-8") as f:
            texte = f.read()
        s = [json.loads(l) for l in texte.splitlines()]
        bas = texte.lower().replace(":", "")
        for valeur in REEL:
            self.assertNotIn(valeur.lower(), bas)
        # Le nom et le nom d'hote de la sonde, l'ExtMac du parent : les memes factices d'un message a l'autre.
        self.assertEqual((s[0]["nom"], s[0]["code"], s[0]["qr"]), ("SONDE-01", None, None))
        self.assertEqual(s[0]["hote"], s[1]["ext"])
        self.assertEqual(s[7]["hote"], s[1]["ext"])
        self.assertEqual({s[1]["parent"]["ext"], s[3]["liste"][0]["ext"], s[4]["liste"][0]["ext"]},
                         {s[1]["parent"]["ext"]})
        self.assertNotEqual(s[4]["liste"][1]["ext"], s[4]["liste"][0]["ext"])
        self.assertIsNone(s[3]["liste"][1]["ext"])
        self.assertEqual((s[7]["empreinte"], s[8]["empreinte"], s[8]["cle"]), ("C1E00001", "C1E00001", "(masquee)"))
        # Gardes tels quels : compteurs, signaux, qualites, reponses « occupee », erreurs, oubli.
        self.assertEqual((s[7]["udp"], s[7]["tas"]), (messages[7]["udp"], messages[7]["tas"]))
        self.assertEqual([v["rssi"] for v in s[4]["liste"]], [-60, -82])
        for i in (2, 5, 9, 10):
            self.assertEqual(s[i], messages[i])
        self.assertTrue(s[6]["tronquee"])

    def test_la_capture_du_depot_ressort_telle_quelle(self):
        """Deja anonymisee : ses valeurs factices restent les memes, et le controle final ne les prend plus pour des
        valeurs reelles."""
        r = self.lancer(entree=CAPTURE_ANONYME)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, "64 lignes ; 0 ExtMac, 0 identifiants, 0 prefixes /48 remplaces\n")
        with open(CAPTURE_ANONYME, "rb") as f, open(self.sortie, "rb") as g:
            self.assertEqual(g.read(), f.read())

    def test_deux_passages_donnent_la_meme_sortie(self):
        self.ecrire(capture_1_0_3() + capture_inventee())
        self.assertEqual(self.lancer().returncode, 0)
        une_fois = os.path.join(self.dossier, "une-fois.jsonl")
        shutil.move(self.sortie, une_fois)
        r = self.lancer(entree=une_fois)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn(" 0 ExtMac, 0 identifiants, 0 prefixes /48 remplaces", r.stdout)
        with open(une_fois, encoding="utf-8") as f, open(self.sortie, encoding="utf-8") as g:
            self.assertEqual(g.read(), f.read())

    def test_ne_touche_pas_a_une_sortie_qui_existe(self):
        messages = capture_inventee()
        messages[1]["adresse"] = EXT_INCONNU
        self.ecrire(messages)
        with open(self.sortie, "w", encoding="utf-8") as f:
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
    def test_lignes_vides_sautees_mais_comptees(self):
        messages = capture_inventee()
        messages[1]["ext"] = EXT_INCONNU
        with open(self.entree, "w", encoding="utf-8") as f:
            f.write(json.dumps(messages[0]) + "\n\n\n" + json.dumps(messages[1]) + "\n")
```

par :

```python
    def test_lignes_vides_sautees_mais_comptees(self):
        messages = capture_inventee()
        messages[1]["adresse"] = EXT_INCONNU
        with open(self.entree, "w", encoding="utf-8") as f:
            f.write(json.dumps(messages[0]) + "\n\n\n" + json.dumps(messages[1]) + "\n")
```

Dans `sonde/test/test_anonymiseur.py`, remplacer :

```python
        self.assertEqual(len(sorties[2]["tlv"]), len(messages[2]["tlv"]), "les TLV gardent leur longueur")

    def test_la_garde_ne_refuse_pas_la_capture_actuelle(self):
        """La capture du depot est deja anonymisee : le controle final peut la refuser (ses valeurs factices
        ressemblent a des valeurs reelles), mais pas la garde."""
        r = self.lancer(entree=CAPTURE_ANONYME)
        self.assertNotIn("ce que l'anonymiseur ne connait pas", r.stderr)
        self.assertNotIn("Traceback", r.stderr)


```

par :

```python
        self.assertEqual(len(sorties[2]["tlv"]), len(messages[2]["tlv"]), "les TLV gardent leur longueur")



```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `python3 -m unittest discover -s sonde/test`
Expected: `Ran 121 tests`, `FAILED (failures=78, errors=3)` : dix-sept tests, dont trois en erreur (`AttributeError: module 'anonymiser_sonde' has no attribute 'OBJETS'`, `AttributeError: 'Anonymiseur' object has no attribute 'hexa_ext'`) ; les tests adaptés qui n'emploient que `etat.adresse` et `journal` passent déjà.

- [ ] **Step 3 : écrire le code.**

`outils/anonymiser-sonde.py`, fichier entier :

```python
#!/usr/bin/env python3
"""Anonymise une capture de la sonde (JSON Lines) avant d'en faire des donnees de test.

  python3 outils/anonymiser-sonde.py <capture brute.jsonl> <capture anonyme.jsonl>

Remplace, de facon coherente d'une ligne a l'autre et jusque dans les TLV de
diagnostic :
- les ExtMac (TLV 0, `ext` de `etat`, de son parent, des voisins et des
  routeurs), les adresses lien-local qui en derivent, et le nom d'hote SRP de
  la sonde (`hote`, 16 hexa : Matter le tire de son ExtMac) ;
- les prefixes IPv6 (/48 : reseau maille, OMR, NAT64...) et les identifiants
  d'interface, sauf ceux des RLOC et ALOC (0000:00ff:fe00:xxxx), gardes ;
- le `xp`, la MAC de la sonde, son nom (SONDE-01, SONDE-02...) et
  l'empreinte de sa cle ;
- les adresses des Network Data (prefixes, donnees de serveur).
Retire le code d'appairage et le QR code (null), et la cle (deja masquee par
sonde_essai.py). Garde les RLOC16, partitions, qualites, signaux, delais,
compteurs et versions de pile. Aucune valeur reelle n'est ecrite dans ce
script : il les repere dans la capture. A la fin, il verifie qu'aucune ne
reste dans la sortie.

Une capture deja anonymisee ressort telle quelle : une valeur deja factice
(ExtMac E000..., identifiant 0A00..., /48 fd00:1111:2222..., MAC A0000000...,
xp A0A1A2A3A4A5A6A7, nom SONDE-NN, empreinte C1E0...) reste elle-meme, et une
valeur reelle recoit une factice qui n'a pas encore servi. Une valeur reelle
de cette forme passerait telle quelle : tiree au hasard, elle n'a presque
aucune chance d'exister. (Une capture qui melerait valeurs reelles et
factices pourrait confondre deux noeuds, jamais laisser passer une valeur
reelle.)

Garde : l'outil ne connait que les messages de la sonde 1.0.3 (bonjour, etat,
voisins, routeurs, diag, cle, oubli, erreur) et ceux de la capture du 29/09
(firmware d'essai), leurs champs et la forme de chacun (CHAMPS_COMMUNS,
CHAMPS_CONNUS, OBJETS), et les TLV de diagnostic que la tournee demande
(TLV_CONNUS). Il echoue AVANT toute ecriture, avec la liste de ce qu'il ne
connait pas (des noms, jamais une valeur), devant :
- une ligne qui n'est pas un objet, un type de message ou un champ inconnu ;
- une valeur qui n'a pas la forme de son champ : un objet ou une liste la ou
  l'outil n'en descend pas ; un texte libre qui n'est pas sur (texte_sur() :
  64 caracteres au plus, lettres, chiffres, espace, point, tiret, souligne,
  « : » seul entre deux espaces, jamais 8 hexa de suite) ; un nombre qui
  n'est pas un entier de 32 bits (une ExtMac en demande 64) ; un RLOC16, une
  partition ou une heure mal formes ; autre chose que du texte dans un champ
  que l'outil remplace ;
- un TLV inconnu, a longueur etendue ou tronque, ou de longueur inattendue :
  8 octets pour le TLV 0 (ExtMac), 2 pour le 1 (Address16), 1 pour le 2
  (Mode), 9 plus un par routeur pour le 5 (Route64), 8 pour le 6 (Leader
  Data), des adresses entieres pour le 8, des entrees de 3 octets pour le 16
  (Child Table), 2 pour le 24 (Version), et au plus 32, 32, 16 et 64 pour les
  textes des TLV 25 a 28 ;
- un texte des TLV 25 a 28 (fabricant, modele, version logicielle, pile) qui
  n'est pas de l'ASCII lisible, ou qui porte 12 hexa de suite, une MAC ou une
  adresse IPv6 ;
- dans la Network Data (TLV 7), autre chose que des Prefix de 16 bits au plus
  ou de 41 a 96 bits, des Service et une Commissioning Data qui ne porte qu'une
  Commissioner Session ID (16 bits, quelle que soit sa valeur), ou une donnee
  de service de plus de 2 octets : donnees_reseau() ne remplace que les 6
  premiers octets des Prefix, a partir de 41 bits, et l'adresse des Server d'un
  Service ;
- dans un Prefix, autre chose que des Has Route (entrees de 3 octets), des
  Border Router (entrees de 4) et un 6LoWPAN Context (2 octets) ; dans un
  Service, autre chose que des Server, ou un Server qui n'est ni un RLOC16 seul
  (2 octets), ni un RLOC16 suivi d'une adresse et d'un port (20 octets,
  l'adresse remplacee), ni, pour le routeur de dorsale (donnee 01), un RLOC16
  et ses 7 octets de reglages.
Une valeur illisible dans un champ remplace (un hexa abime, une adresse, une
cible qui n'est ni un RLOC16 ni une adresse) le fait sortir avec le seul
numero de ligne, jamais la valeur (la trace d'une exception la citerait). Pour
ajouter un champ : verifier qu'il ne porte rien d'identifiant, sinon le
traiter dans message() ; puis l'inscrire dans la table, avec sa forme.
"""
import ipaddress
import json
import re
import sys

MAILLE_RLOC = bytes.fromhex("000000fffe00")
XP_FACTICE = "A0A1A2A3A4A5A6A7"  # le meme pour tout xp, comme dans la capture du 29/09
MASQUEE = "(masquee)"  # la cle, comme sonde_essai.py la capture

# Ce que l'outil connait (voir la garde dans la docstring) : chaque champ avec sa forme. "?" en fin : null permis.
#   texte    : un texte sur (texte_sur()), garde tel quel ;
#   remplace : du texte, remplace par une valeur factice (hexa, adresse, nom) dans message() ;
#   efface   : un scalaire, jamais recopie (code d'appairage, QR code, cle) ;
#   nombre   : un entier de 32 bits, signe ou non ; booleen ;
#   rloc16   : 4 hexa ; partition : 8 hexa ; heure : AAAA-MM-JJTHH:MM:SS, ajoutee par sonde_essai.py ;
#   tlv      : la charge d'un diag, en hexa (controler_tlv()) ;
#   objet X, liste X : un objet des champs OBJETS[X], une liste de tels objets.
CHAMPS_COMMUNS = {"t": "texte", "v": "nombre", "heure": "heure"}
CHAMPS_CONNUS = {
    "bonjour": {"produit": "texte", "version": "texte", "nom": "remplace", "mac": "remplace", "appairee": "booleen",
                "code": "efface?", "qr": "efface?", "hote": "remplace?"},
    "etat": {"erreur": "texte", "role": "texte", "rloc16": "rloc16", "ext": "remplace", "mode": "texte",
             "eligible": "booleen", "parent": "objet parent?", "partition": "partition?", "chef": "nombre?",
             "canal": "nombre", "prefixeMaille": "remplace", "xp": "remplace", "suspendue": "booleen"},
    "voisins": {"erreur": "texte", "liste": "liste voisin"},
    "routeurs": {"erreur": "texte", "liste": "liste routeur", "suite": "booleen"},
    "diag": {"id": "nombre", "cible": "remplace", "ms": "nombre", "ok": "booleen", "code": "texte",
             "erreur": "texte", "tlv": "tlv?", "tronquee": "booleen"},
    "cle": {"id": "nombre", "cle": "efface", "empreinte": "remplace?", "effacement_en_echec": "booleen",
            "hote": "remplace?", "udp": "objet udp", "tas": "objet tas", "msg": "texte"},
    "oubli": {"cle_effacee": "booleen"},
    "erreur": {"erreur": "texte"},
}
OBJETS = {
    "parent": {"rloc16": "rloc16", "ext": "remplace", "lqIn": "nombre", "lqOut": "nombre", "rssi": "nombre",
               "rssiDernier": "nombre", "age": "nombre"},
    "voisin": {"rloc16": "rloc16", "ext": "remplace", "rssi": "nombre", "lqi": "nombre", "routeur": "booleen"},
    "routeur": {"id": "nombre", "rloc16": "rloc16", "ext": "remplace?", "lqIn": "nombre", "lqOut": "nombre",
                "age": "nombre", "lien": "booleen"},
    # Compteurs du transport (ceux du pont Halo), plus les lignes perdues et les commandes refusees par la cadence.
    "udp": {"port": "nombre", "ouvert": "booleen", "sessions": "nombre", "provisoire": "booleen", "rx": "nombre",
            "rejets": "nombre", "rx_perdus": "nombre", "defis": "nombre", "tx": "nombre", "tx_perdus": "nombre",
            "tx_erreurs": "nombre", "tampons_min": "nombre?", "lignes_perdues": "nombre", "refus_cadence": "nombre"},
    "tas": {"libre": "nombre", "min": "nombre"},
}
TEXTE_SUR = re.compile(r"[A-Za-z0-9_. :-]{0,64}")
HEXA_8 = re.compile(r"[0-9A-Fa-f]{8}")
# TLV de diagnostic : 0, 7 et 8 sont traites ; les autres n'ont ni ExtMac ni adresse.
TLV_CONNUS = frozenset({0, 1, 2, 5, 6, 7, 8, 16, 24, 25, 26, 27, 28})
# Longueur exacte : ExtMac (0), Address16 (1), Mode (2), Leader Data (6), Version (24). Un octet de plus porterait un
# morceau de valeur que l'anonymiseur ne lit pas.
TLV_LONGUEUR = {0: 8, 1: 2, 2: 1, 6: 8, 24: 2}
# Faits d'entrees de cette taille : les adresses (8), la Child Table (16). Route64 (5) se lit a part : 9 octets, puis
# un par routeur du masque.
TLV_ENTREES = {8: 16, 16: 3}
# Textes du fabricant (25), du modele (26), de la version logicielle (27) et de la pile (28) : longueur maximale.
TLV_TEXTE_MAX = {25: 32, 26: 32, 27: 16, 28: 64}
# Dans ces textes : 12 hexa de suite (une MAC, une ExtMac), ou une MAC ecrite avec des separateurs. Une version de pile
# porte une date, une heure, parfois un condensat de commit (9 hexa dans la capture) : la limite est a 12.
HEXA_12 = re.compile(r"[0-9A-Fa-f]{12}")
MAC_TEXTE = re.compile(r"[0-9A-Fa-f]{2}(?:[:-][0-9A-Fa-f]{2}){5}")
# Network Data (TLV 7), premier niveau : les Prefix (1) et les Service (5) sont traites par donnees_reseau() ; la
# Commissioning Data (4) n'est acceptee que si elle ne porte qu'un sous-TLV Commissioner Session ID (MeshCoP 11,
# longueur 2), quelle que soit sa valeur : un identifiant de session sur 16 bits n'est pas une donnee personnelle.
DONNEES_RESEAU_CONNUES = frozenset({1, 4, 5})
# Une donnee de service de plus de 2 octets (la capture : 01, 5d, 5cc5) pourrait porter une adresse.
DONNEE_SERVICE_MAX = 2
# donnees_reseau() ne remplace que les 6 premiers octets d'un Prefix : au-dela de 96 bits (le /96 NAT64 de la capture
# passe), l'identifiant d'interface resterait en clair.
PREFIXE_MAX_BITS = 96
# donnees_reseau() ne remplace un Prefix qu'a partir de 6 octets, soit 41 bits : de 17 a 40 bits il passerait en clair.
# Jusqu'a 16 bits (le /7 de la capture), un prefixe n'identifie personne.
PREFIXE_COURT_MAX_BITS = 16
PREFIXE_REMPLACE_MIN_BITS = 41


def texte_sur(x):
    """Un texte libre qui ne porte rien d'identifiant : 64 caracteres au plus, lettres, chiffres, espace, point,
    tiret, souligne, et « : » seul entre deux espaces (« cle non chargee : active au redemarrage ») ; jamais 8 hexa
    de suite (une MAC, un /48, une ExtMac, un code d'appairage en ont 8 ou plus)."""
    return (isinstance(x, str) and TEXTE_SUR.fullmatch(x) is not None and HEXA_8.search(x) is None
            and all(":" not in mot or mot == ":" for mot in x.split(" ")))


FORMES = {
    "texte": texte_sur,
    "remplace": lambda x: isinstance(x, str),
    "efface": lambda x: not isinstance(x, (dict, list)),
    "nombre": lambda x: isinstance(x, int) and not isinstance(x, bool) and -(1 << 31) <= x < 1 << 32,
    "booleen": lambda x: isinstance(x, bool),
    "rloc16": lambda x: isinstance(x, str) and re.fullmatch(r"[0-9A-Fa-f]{4}", x) is not None,
    "partition": lambda x: isinstance(x, str) and re.fullmatch(r"[0-9A-Fa-f]{8}", x) is not None,
    "heure": lambda x: isinstance(x, str) and re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d", x) is not None,
}


def p48_factice(n):
    """Le n-ieme /48 factice, a partir de 1 : fd00:1111:2222, fd00:3333:4444, fd00:5555:6666..."""
    return bytes.fromhex("FD00%04X%04X" % (0x1111 * (2 * n - 1) & 0xFFFF, 0x1111 * 2 * n & 0xFFFF))


P48_FACTICES = frozenset(p48_factice(n) for n in range(1, 4097))


def remplaces(table):
    """Les valeurs reelles d'une table (pas celles, deja factices, qui restent elles-memes)."""
    return [reel for reel, factice in table.items() if reel != factice]


class Anonymiseur:
    def __init__(self):
        self.exts = {}        # ExtMac reelle (8 octets) -> factice ; aussi le nom d'hote SRP
        self.iids = {}        # identifiant d'interface reel -> factice
        self.p48 = {}         # /48 reel (6 octets) -> factice
        self.xp = {}
        self.macs = {}
        self.noms = {}        # nom de la sonde
        self.empreintes = {}  # empreinte de sa cle
        self.cles = set()     # cle en clair (sonde_essai.py la masque deja) : a ne plus trouver

    # --- Tables de correspondance ------------------------------------------

    @staticmethod
    def factice(table, reel, nieme, deja_factice):
        """La valeur factice de `reel`, la meme d'une ligne a l'autre. Deja factice (capture deja anonymisee), elle
        reste elle-meme ; sinon, la premiere factice libre (`nieme(n)`, n a partir du nombre de valeurs vues + 1) :
        jamais une factice deja donnee."""
        if reel not in table:
            if deja_factice(reel):
                table[reel] = reel
            else:
                prises, n = set(table.values()), len(table) + 1
                while nieme(n) in prises:
                    n += 1
                table[reel] = nieme(n)
        return table[reel]

    def ext(self, e):
        return self.factice(self.exts, e, lambda n: bytes.fromhex("E0%014X" % n),
                            lambda x: len(x) == 8 and x[0] == 0xE0 and int.from_bytes(x[1:], "big") < 1 << 16)

    def iid(self, i):
        return self.factice(self.iids, i, lambda n: bytes.fromhex("0A00%012X" % n),
                            lambda x: len(x) == 8 and x[:2] == b"\x0a\x00" and int.from_bytes(x[2:], "big") < 1 << 16)

    def prefixe48(self, p):
        if len(p) != 6:
            raise ValueError("prefixe")  # un prefixe du reseau maille trop court : illisible
        return self.factice(self.p48, p, p48_factice, lambda x: x in P48_FACTICES)

    def hexa_ext(self, texte):
        """Une ExtMac en hexa (ou le nom d'hote SRP, qui en est tire) -> sa factice, en hexa."""
        return self.ext(bytes.fromhex(texte)).hex().upper()

    def mac(self, m):
        return self.factice(self.macs, m, lambda n: "A0000000%04X" % n,
                            lambda x: re.fullmatch(r"A0000000[0-9A-F]{4}", x) is not None)

    def nom(self, x):
        return self.factice(self.noms, x, lambda n: "SONDE-%02d" % n,
                            lambda v: re.fullmatch(r"SONDE-\d{2,}", v) is not None)

    def empreinte(self, x):
        return self.factice(self.empreintes, x, lambda n: "C1E0%04X" % n,
                            lambda v: re.fullmatch(r"C1E0[0-9A-F]{4}", v) is not None)

    def adresse(self, a):
        """Adresse IPv6 de 16 octets."""
        if a[:8] == bytes.fromhex("FE80000000000000"):
            # Lien-local Thread : identifiant tire de l'ExtMac (bit U/L inverse).
            e = bytes([a[8] ^ 0x02]) + a[9:]
            f = self.ext(e)
            return a[:8] + bytes([f[0] ^ 0x02]) + f[1:]
        tete = self.prefixe48(a[:6]) + a[6:8]
        if a[8:14] == MAILLE_RLOC:
            return tete + a[8:]
        return tete + self.iid(a[8:])

    # --- TLV de diagnostic -------------------------------------------------

    def tlv(self, hexa):
        o, i, sortie = bytes.fromhex(hexa), 0, b""
        while i + 2 <= len(o):
            t, n = o[i], o[i + 1]
            v = o[i + 2:i + 2 + n]
            if t == 0 and n == 8:
                v = self.ext(v)
            elif t == 8:
                v = b"".join(self.adresse(v[k:k + 16]) for k in range(0, n - 15, 16))
            elif t == 7:
                v = self.donnees_reseau(v)
            sortie += bytes([t, n]) + v
            i += 2 + n
        return sortie.hex().upper()

    def donnees_reseau(self, o):
        """Network Data : prefixes des TLV Prefix, adresses des donnees de serveur."""
        i, sortie = 0, b""
        while i + 2 <= len(o):
            t, n = o[i] >> 1, o[i + 1]
            v = bytearray(o[i + 2:i + 2 + n])
            if t == 1 and len(v) >= 2:  # Prefix : domaine, longueur en bits, prefixe, sous-TLV
                octets = (v[1] + 7) // 8
                if octets >= 6:
                    v[2:8] = self.prefixe48(bytes(v[2:8]))
            elif t == 5 and len(v) >= 1:  # Service : donnees, puis sous-TLV Server
                j = 1 if v[0] & 0x80 else 5
                if j < len(v):
                    j += 1 + v[j]
                    while j + 2 <= len(v):
                        st, sn = v[j] >> 1, v[j + 1]
                        if st == 6 and sn >= 2 + 16:  # Server : RLOC16, puis une adresse
                            v[j + 4:j + 20] = self.adresse(bytes(v[j + 4:j + 20]))
                        j += 2 + sn
            sortie += bytes([o[i], n]) + bytes(v)
            i += 2 + n
        return sortie

    # --- Messages de la sonde ----------------------------------------------

    def message(self, m):
        m = dict(m)
        t = m.get("t")
        if t == "bonjour":
            if m.get("mac"):
                m["mac"] = self.mac(m["mac"])
            if m.get("nom"):
                m["nom"] = self.nom(m["nom"])
            if m.get("hote"):
                m["hote"] = self.hexa_ext(m["hote"])
            m["code"] = None
            m["qr"] = None
        elif t == "etat":
            if m.get("ext"):
                m["ext"] = self.hexa_ext(m["ext"])
            if m.get("xp"):
                m["xp"] = self.xp.setdefault(m["xp"], XP_FACTICE)
            if m.get("prefixeMaille"):
                p = bytes.fromhex(m["prefixeMaille"])
                m["prefixeMaille"] = (self.prefixe48(p[:6]) + p[6:8]).hex().upper()
            if m.get("parent") and m["parent"].get("ext"):
                m["parent"] = dict(m["parent"], ext=self.hexa_ext(m["parent"]["ext"]))
        elif t in ("voisins", "routeurs"):
            if m.get("liste"):
                m["liste"] = [dict(e, ext=self.hexa_ext(e["ext"])) if e.get("ext") else dict(e) for e in m["liste"]]
        elif t == "diag":
            cible = m.get("cible", "")
            if ":" in cible:
                m["cible"] = str(ipaddress.IPv6Address(self.adresse(ipaddress.IPv6Address(cible).packed)))
            elif cible and not re.fullmatch(r"[0-9A-Fa-f]{4}", cible):
                raise ValueError("cible")  # ni un RLOC16, ni une adresse : illisible
            if m.get("tlv"):
                m["tlv"] = self.tlv(m["tlv"])
        elif t == "cle":
            if "cle" in m:
                if m["cle"] != MASQUEE:
                    self.cles.add(str(m["cle"]))
                m["cle"] = MASQUEE
            if m.get("empreinte"):
                m["empreinte"] = self.empreinte(m["empreinte"])
            if m.get("hote"):
                m["hote"] = self.hexa_ext(m["hote"])
        return m

    def secrets(self):
        """Valeurs reelles, en texte, a ne plus trouver dans la sortie (pas celles qui etaient deja factices)."""
        s = set()
        for e in remplaces(self.exts):
            s.add(e.hex())
            if e:
                s.add((bytes([e[0] ^ 0x02]) + e[1:]).hex())  # l'identifiant lien-local qui en derive
        for i in remplaces(self.iids):
            s.add(i.hex())
        for p in remplaces(self.p48):
            s.add(p.hex())
            s.add(str(ipaddress.IPv6Address(p + bytes(10))).split("::")[0])
        for table in (self.macs, self.noms, self.empreintes):
            s.update(remplaces(table))
        s.update(x for x in self.xp if x != XP_FACTICE)
        s.update(self.cles)
        return {x.lower() for x in s if len(x) >= 8}


def nom_sur(x):
    """Nom de champ ou de type pour un message d'erreur : jamais une valeur. Un nom abime peut porter une ExtMac, une
    MAC, un /48 ou un code d'appairage : 8 hexa de suite, et il devient "(illisible)"."""
    ok = isinstance(x, str) and re.fullmatch(r"[A-Za-z0-9_]{1,32}", x) and not re.search(r"[0-9A-Fa-f]{8}", x)
    return x if ok else "(illisible)"


def controler_sous_tlv(o, admis):
    """Les sous-TLV d'un Prefix ou d'un Service : `admis(type, valeur)` rend la raison de refuser un sous-TLV, ou
    None s'il est connu. Le bit de poids faible du type est le drapeau "stable"."""
    raisons, i = [], 0
    while i < len(o):
        if i + 2 > len(o) or i + 2 + o[i + 1] > len(o):
            return raisons + ["Network Data tronquee (diag.tlv)"]
        raison = admis(o[i] >> 1, o[i + 2:i + 2 + o[i + 1]])
        if raison:
            raisons.append(raison)
        i += 2 + o[i + 1]
    return raisons


def sous_tlv_prefix(t, v):
    """Has Route (0) : entrees de 3 octets (RLOC16, drapeaux) ; Border Router (2) : entrees de 4 (RLOC16, drapeaux) ;
    6LoWPAN Context (3) : 2 octets (identifiant, longueur). Aucun ne porte d'adresse."""
    if t not in (0, 2, 3):
        return "sous-TLV inconnu d'un Prefix : %d (diag.tlv)" % t
    if (t == 0 and len(v) % 3) or (t == 2 and len(v) % 4) or (t == 3 and len(v) != 2):
        return "sous-TLV %d de longueur inattendue dans un Prefix (diag.tlv)" % t
    return None


def controler_prefixe(v):
    """Un Prefix : domaine, longueur du prefixe en bits, ses octets, puis ses sous-TLV."""
    if len(v) < 2:
        return ["Network Data tronquee (diag.tlv)"]
    if v[1] > PREFIXE_MAX_BITS:
        return ["prefixe de plus de %d bits dans la Network Data (diag.tlv)" % PREFIXE_MAX_BITS]
    if PREFIXE_COURT_MAX_BITS < v[1] < PREFIXE_REMPLACE_MIN_BITS:
        return ["prefixe de %d a %d bits dans la Network Data (diag.tlv)"
                % (PREFIXE_COURT_MAX_BITS + 1, PREFIXE_REMPLACE_MIN_BITS - 1)]
    debut = 2 + (v[1] + 7) // 8
    if debut > len(v):
        return ["Network Data tronquee (diag.tlv)"]
    return controler_sous_tlv(v[debut:], sous_tlv_prefix)


def controler_service(v):
    """Un Service : bit T et identifiant, numero d'entreprise (4 octets) si T est a 0, donnee de service, puis des
    Server seulement. Un Server est un RLOC16 seul (2 octets), un RLOC16 suivi d'une adresse et d'un port (20 octets :
    le serveur SRP, dont donnees_reseau() remplace l'adresse), ou, pour le routeur de dorsale (donnee 01), un RLOC16
    et ses 7 octets de reglages. Un Server de 12 octets porterait une ExtMac en clair."""
    j = 1 if v and v[0] & 0x80 else 5
    if j >= len(v):
        return ["Network Data tronquee (diag.tlv)"]
    if v[j] > DONNEE_SERVICE_MAX:
        return ["donnee de service de plus de %d octets dans la Network Data (diag.tlv)" % DONNEE_SERVICE_MAX]
    donnee = v[j + 1:j + 1 + v[j]]
    if len(donnee) < v[j]:
        return ["Network Data tronquee (diag.tlv)"]

    def admis(t, serveur):
        if t != 6:
            return "sous-TLV inconnu d'un Service : %d (diag.tlv)" % t
        if len(serveur) not in (2, 20) and not (len(serveur) == 9 and donnee == b"\x01"):
            return "Server de longueur inattendue dans la Network Data (diag.tlv)"
        return None

    return controler_sous_tlv(v[j + 1 + v[j]:], admis)


def controler_donnees_reseau(o):
    """Pourquoi la Network Data (TLV 7) n'est pas connue (liste vide si elle l'est) : donnees_reseau() ne remplace
    que le /48 des Prefix et l'adresse des Server d'un Service ; le reste passerait en clair."""
    raisons, i = [], 0
    while i < len(o):
        if i + 2 > len(o) or i + 2 + o[i + 1] > len(o):
            return raisons + ["Network Data tronquee (diag.tlv)"]
        t, n = o[i] >> 1, o[i + 1]  # le bit de poids faible est le drapeau "stable"
        v = o[i + 2:i + 2 + n]
        if t not in DONNEES_RESEAU_CONNUES:
            raisons.append("sous-TLV inconnu de la Network Data : %d (diag.tlv)" % t)
        elif t == 1:
            raisons += controler_prefixe(v)
        elif t == 4 and not (len(v) == 4 and v[0] == 11 and v[1] == 2):  # un seul sous-TLV, la valeur est libre
            raisons.append("Commissioning Data inconnue dans la Network Data (diag.tlv)")
        elif t == 5:
            raisons += controler_service(v)
        i += 2 + n
    return raisons


def longueur_tlv_attendue(t, v):
    """La longueur du TLV connu `t` (voir TLV_LONGUEUR, TLV_ENTREES, TLV_TEXTE_MAX ; la Network Data se lit a part)."""
    if t in TLV_LONGUEUR:
        return len(v) == TLV_LONGUEUR[t]
    if t in TLV_ENTREES:
        return len(v) % TLV_ENTREES[t] == 0
    if t in TLV_TEXTE_MAX:
        return len(v) <= TLV_TEXTE_MAX[t]
    if t == 5:  # numero de sequence, masque des routeurs (64 bits), un octet par routeur du masque
        return len(v) >= 9 and len(v) == 9 + bin(int.from_bytes(v[1:9], "big")).count("1")
    return True


def texte_tlv_sur(v):
    """Le texte d'un TLV 25 a 28 : de l'ASCII lisible, sans 12 hexa de suite, ni MAC, ni adresse IPv6."""
    if any(c < 0x20 or c > 0x7E for c in v):
        return False
    texte = v.decode("ascii")
    if HEXA_12.search(texte) or MAC_TEXTE.search(texte):
        return False
    for mot in re.split(r"[\s;,()\[\]]+", texte):
        if ":" in mot:
            try:
                ipaddress.IPv6Address(mot.split("%")[0])
                return False
            except ValueError:
                pass
    return True


def controler_tlv(hexa):
    """Pourquoi la charge TLV d'un diag n'est pas connue (liste vide si elle l'est)."""
    try:
        o = bytes.fromhex(hexa)
    except (TypeError, ValueError):
        return ["tlv illisible (diag.tlv)"]
    raisons, i = [], 0
    while i < len(o):
        if i + 2 > len(o):
            return raisons + ["TLV tronque (diag.tlv)"]
        t, n = o[i], o[i + 1]
        if n == 0xFF:
            return raisons + ["TLV a longueur etendue (diag.tlv)"]
        if i + 2 + n > len(o):
            return raisons + ["TLV tronque (diag.tlv)"]
        v = o[i + 2:i + 2 + n]
        if t not in TLV_CONNUS:
            raisons.append("TLV inconnu : %d (diag.tlv)" % t)
        elif not longueur_tlv_attendue(t, v):
            raisons.append("TLV %d de longueur inattendue (diag.tlv)" % t)
        elif t == 7:
            raisons += controler_donnees_reseau(v)
        elif t in TLV_TEXTE_MAX and not texte_tlv_sur(v):
            raisons.append("texte inconnu dans le TLV %d (diag.tlv)" % t)
        i += 2 + n
    return raisons


def controler(numerotes):
    """La garde. `numerotes` : [(numero de ligne, message)]. Rend {raison: [numeros de ligne]}, vide si tout est
    connu. Ne cite jamais une valeur de la capture, seulement des noms de type et de champ (nom_sur). Une raison
    repetee sur une meme ligne ne compte qu'une fois."""
    inconnu = {}

    def noter(raison, numero):
        numeros = inconnu.setdefault(raison, [])
        if numero not in numeros:
            numeros.append(numero)

    def objet(chemin, champs, o, numero):
        for champ, valeur in o.items():
            if champ not in champs:
                noter("champ inconnu : %s.%s" % (chemin, nom_sur(champ)), numero)
            else:
                forme_de(chemin + "." + champ, champs[champ], valeur, numero)

    def forme_de(chemin, forme, valeur, numero):
        if valeur is None:
            if not forme.endswith("?"):
                noter("forme inconnue : %s" % chemin, numero)
            return
        genre, _, nom = forme.rstrip("?").partition(" ")
        if genre == "objet" and isinstance(valeur, dict):
            objet(chemin, OBJETS[nom], valeur, numero)
        elif genre == "liste" and isinstance(valeur, list) and all(isinstance(e, dict) for e in valeur):
            for e in valeur:
                objet(chemin, OBJETS[nom], e, numero)
        elif genre == "tlv" and not isinstance(valeur, (dict, list)):
            for raison in controler_tlv(valeur):
                noter(raison, numero)
        elif genre not in FORMES or not FORMES[genre](valeur):
            noter("forme inconnue : %s" % chemin, numero)

    for numero, m in numerotes:
        if not isinstance(m, dict):
            noter("ligne qui n'est pas un objet JSON", numero)
            continue
        t = m.get("t")
        if not isinstance(t, str) or t not in CHAMPS_CONNUS:
            noter("type de message inconnu : %s" % nom_sur(t), numero)
            continue
        objet(t, dict(CHAMPS_COMMUNS, **CHAMPS_CONNUS[t]), m, numero)
    return inconnu


def texte_refus(inconnu):
    lignes = ["refus : la capture contient ce que l'anonymiseur ne connait pas ; rien n'a ete ecrit."]
    for raison, numeros in inconnu.items():
        lignes.append("  %s (%d ligne(s), la premiere : %d)" % (raison, len(numeros), numeros[0]))
    lignes.append("Un champ ou un message inconnu peut porter une ExtMac, une adresse ou un nom : le traiter dans "
                  "l'anonymiseur (message(), puis les tables CHAMPS_CONNUS, OBJETS et TLV_CONNUS) avant de lui "
                  "confier cette capture.")
    return "\n".join(lignes)


def lire(chemin):
    """Les messages de la capture avec leur numero de ligne (les lignes vides sont sautees)."""
    res = []
    with open(chemin, encoding="utf-8") as f:
        for numero, ligne in enumerate(f, 1):
            if ligne.strip():
                try:
                    res.append((numero, json.loads(ligne)))
                except ValueError:
                    sys.exit("refus : la ligne %d n'est pas du JSON ; rien n'a ete ecrit." % numero)
    return res


def valeur_illisible(numero):
    """Sort avec le seul numero de ligne : la trace d'une exception (AddressValueError...) citerait la valeur."""
    raise SystemExit("refus : la ligne %d porte une valeur que l'anonymiseur ne sait pas lire ; rien n'a ete ecrit."
                     % numero) from None


def main():
    entree, sortie = sys.argv[1], sys.argv[2]
    a = Anonymiseur()
    numerotes = lire(entree)
    inconnu = controler(numerotes)
    if inconnu:
        sys.exit(texte_refus(inconnu))
    # Le prefixe du reseau maille (sonde attachee) d'abord : il recoit toujours
    # le premier /48 factice.
    for numero, m in numerotes:
        if m.get("t") == "etat" and m.get("prefixeMaille") and m.get("role") in ("child", "router", "leader"):
            try:
                a.prefixe48(bytes.fromhex(m["prefixeMaille"])[:6])
            except (ValueError, TypeError):
                valeur_illisible(numero)
            break
    lignes = []
    for numero, m in numerotes:
        try:
            lignes.append(json.dumps(a.message(m), ensure_ascii=False, sort_keys=True))
        except (ValueError, TypeError):
            valeur_illisible(numero)
    texte = "\n".join(lignes) + "\n"
    minuscule = texte.lower()
    brut = texte.lower().replace(":", "")
    fuites = [s for s in a.secrets() if s in minuscule or s in brut]
    if fuites:
        sys.exit("fuite : %d valeur(s) reelle(s) encore presente(s)" % len(fuites))
    open(sortie, "w", encoding="utf-8").write(texte)
    print("%d lignes ; %d ExtMac, %d identifiants, %d prefixes /48 remplaces" %
          (len(lignes), len(remplaces(a.exts)), len(remplaces(a.iids)), len(remplaces(a.p48))))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4 : vérifier qu'ils passent, sous les deux Python.**

Run: `python3 -m unittest discover -s sonde/test && /usr/bin/python3 -m unittest discover -s sonde/test`
Expected: `Ran 121 tests`, `OK`, sous les deux Python ; 12 tests de plus qu'après la tâche 11 (109).

- [ ] **Step 5 : la capture du dépôt ressort telle quelle.**

Run: `python3 outils/anonymiser-sonde.py docs/releves/2026-09-29/capture-sonde.jsonl "$HOME/Library/Caches/maillage-plan3b/capture.jsonl" && cmp docs/releves/2026-09-29/capture-sonde.jsonl "$HOME/Library/Caches/maillage-plan3b/capture.jsonl" && shasum -a 256 "$HOME/Library/Caches/maillage-plan3b/capture.jsonl" && rm "$HOME/Library/Caches/maillage-plan3b/capture.jsonl"`
Expected: `64 lignes ; 0 ExtMac, 0 identifiants, 0 prefixes /48 remplaces`, `cmp` muet, puis `d77853f1759925819d4ad4f4c1ee3aa07e26e689d75833e5af85a51df5424832` (l'empreinte de la capture validée au plan 3a).

- [ ] **Step 6 : commit.**

```bash
git add outils/anonymiser-sonde.py sonde/test/test_anonymiseur.py
git commit -m "Anonymiser les captures de la sonde 1.0.3 et garder telle quelle une capture deja anonymisee

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 13: Documentation et vérification avec Djoko (par le contrôleur, pas par un sous-agent)

**Files:**
- Modify: `README.md`, `README.fr.md`, `sonde/README.md`, `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md` (blocs ci-dessous ; puis la section 8 après la vérification)

- [ ] **Step 1 : les README et la spec.** Le journal et l'historique, les réponses « occupée », la fiche à l'heure, l'anonymiseur complet ; la taille mesurée et les précisions du plan dans la spec.

Dans `README.md`, remplacer :

```markdown
| `MaillageCoeur/Maillage/` | probe: diagnostic TLVs, Network Data, USB protocol, mesh model, tour (routers, scan of silent routers), kept router identities, matching with the snapshot (elimination, candidates); tested on an anonymized capture |
```

par :

```markdown
| `MaillageCoeur/Maillage/` | probe: diagnostic TLVs, Network Data, USB protocol, mesh model, tour (routers, scan of silent routers), kept router identities, matching with the snapshot (elimination, candidates), log of parents and Thread routers, tour history and curves; tested on an anonymized capture |
```

Dans `README.md`, remplacer :

```markdown
  minutes after it was received (never during a tour); after 15 minutes the
  graph goes back to dotted lines. The graph redraws every minute: both
  changes show up within a minute, with no other event needed.
- Switching "Sonde maillage" off in Home suspends the probe: no tour, even
  after the probe restarts. The board's LED then gives a short orange flash
```

par :

```markdown
  minutes after it was received (never during a tour); after 15 minutes the
  graph goes back to dotted lines. The graph redraws every minute: both
  changes show up within a minute, with no other event needed, and so do the
  open card's "seen … ago" and curves.
- Switching "Sonde maillage" off in Home suspends the probe: no tour, even
  after the probe restarts. The board's LED then gives a short orange flash
```

Dans `README.md`, remplacer :

```markdown
  the probe (see `sonde/README.md`), the probe comes back on, as when first
  set up.
- Probe captures hold the home network's addresses:
  `outils/anonymiser-sonde.py` rewrites them consistently before they become
  test data (`docs/releves/2026-09-29/`). The anonymizer fails on any unknown
  message type, field or TLV, without writing anything: it only knows the
  `bonjour`, `etat` and `diag` messages of that capture, so a capture from
  firmware 1.0.2 or later (`etat.ext`, `bonjour.hote`, `routeurs`…) is refused
  until it handles them.

### Route to the Thread network
```

par :

```markdown
  the probe (see `sonde/README.md`), the probe comes back on, as when first
  set up.
- **Log and history** (plan 3b). Each tour compares its mesh with the
  previous one and writes to the log ("Mesh" family): "X changed parent:
  A → B", "X has no parent anymore" (missing from two tours where its absence
  is certain) and a Thread router other than a border router appearing or
  disappearing; parent changes of one node within the hour fit on one line
  ("X changed parent 4 times within 1 h"). Only identified children (ExtMac)
  are followed. No notification by default ("Other changes"). Each tour also
  adds a line to `maillage-AAAA-MM.jsonl` in the app folder (kept 90 days,
  about 8 MB a month for 7 routers and 20 children): the quality of every
  link, and the signal of every router the probe hears (`voisins`) and of its
  parent (`etat`). A node's card draws its curves over 24 h, 7 d or 30 d: the
  quality of its links, parent changes marked, and for a router the "Signal
  seen by the probe", with the probe's own parent changes marked (the signal
  depends first on where the probe sits). None of this in demo mode.
- Probe captures hold the home network's addresses:
  `outils/anonymiser-sonde.py` rewrites them consistently before they become
  test data (`docs/releves/2026-09-29/`): ExtMacs and the SRP host name,
  prefixes, addresses, the probe's MAC, name and key fingerprint (plan 3b).
  It knows the messages of firmware 1.0.3 and of that capture, the form of
  every field, and the diagnostic TLVs the tour asks for, down to the Network
  Data; it fails on anything else, without writing anything. An already
  anonymized capture comes out unchanged.

### Route to the Thread network
```

Dans `README.fr.md`, remplacer :

```markdown
| `MaillageCoeur/Maillage/` | sonde : TLV du diagnostic, Network Data, protocole USB, modèle du maillage, tournée (routeurs, balayage des routeurs muets), identités des routeurs gardées, rapprochement avec l'instantané (élimination, candidats) ; testé sur une capture anonymisée |
```

par :

```markdown
| `MaillageCoeur/Maillage/` | sonde : TLV du diagnostic, Network Data, protocole USB, modèle du maillage, tournée (routeurs, balayage des routeurs muets), identités des routeurs gardées, rapprochement avec l'instantané (élimination, candidats), journal des parents et des routeurs Thread, historique des tournées et courbes ; testé sur une capture anonymisée |
```

Dans `README.fr.md`, remplacer :

```markdown
  graphe revient aux pointillés. Le graphe se redessine chaque minute : ces
  deux changements y paraissent avec une minute de retard au plus, sans autre
  événement.
- Éteindre « Sonde maillage » dans Maison suspend la sonde : pas de tournée,
  même après un redémarrage de la sonde. Sa LED donne alors un bref éclair
```

par :

```markdown
  graphe revient aux pointillés. Le graphe se redessine chaque minute : ces
  deux changements y paraissent avec une minute de retard au plus, sans autre
  événement, comme le « vu il y a … » et les courbes de la fiche ouverte.
- Éteindre « Sonde maillage » dans Maison suspend la sonde : pas de tournée,
  même après un redémarrage de la sonde. Sa LED donne alors un bref éclair
```

Dans `README.fr.md`, remplacer :

```markdown
  qui désappaire la sonde (voir `sonde/README.md`), la sonde revient allumée,
  comme à sa première mise en service.
- Les captures de la sonde contiennent les adresses du réseau de la maison :
  `outils/anonymiser-sonde.py` les réécrit de façon cohérente avant qu'elles ne
  deviennent des données de test (`docs/releves/2026-09-29/`). L'anonymiseur
  échoue devant tout type de message, champ ou TLV inconnu, sans rien écrire :
  il ne connaît que les messages `bonjour`, `etat` et `diag` de cette capture,
  si bien qu'une capture du firmware 1.0.2 ou plus récent (`etat.ext`,
  `bonjour.hote`, `routeurs`…) est refusée tant qu'il ne les traite pas.

### Route vers le réseau Thread
```

par :

```markdown
  qui désappaire la sonde (voir `sonde/README.md`), la sonde revient allumée,
  comme à sa première mise en service.
- **Journal et historique** (plan 3b). Chaque tournée compare son maillage à
  celui de la précédente et note au journal (famille « Maillage ») : « X a
  changé de parent : A → B », « X n'a plus de parent » (absent de deux
  tournées où son absence est sûre) et l'apparition ou la disparition d'un
  routeur Thread hors routeurs de bordure ; les changements de parent d'un
  même nœud dans l'heure tiennent sur une ligne (« X a changé 4 fois de parent
  en 1 h »). Seuls les enfants identifiés (ExtMac) sont suivis. Pas de
  notification par défaut (« Autres changements »). Chaque tournée ajoute
  aussi une ligne à `maillage-AAAA-MM.jsonl`, dans le dossier de l'app (gardé
  90 jours, environ 8 Mo par mois pour 7 routeurs et 20 enfants) : la qualité
  de chaque lien, et le signal de chaque routeur que la sonde entend
  (`voisins`) et de son parent (`etat`). La fiche d'un nœud en tire ses
  courbes sur 24 h, 7 j ou 30 j : la qualité de ses liens, changements de
  parent marqués, et pour un routeur le « Signal vu par la sonde », où les
  changements de parent de la sonde sont marqués (le signal dépend d'abord de
  l'endroit où elle est posée). Rien de tout cela en démo.
- Les captures de la sonde contiennent les adresses du réseau de la maison :
  `outils/anonymiser-sonde.py` les réécrit de façon cohérente avant qu'elles ne
  deviennent des données de test (`docs/releves/2026-09-29/`) : ExtMac et nom
  d'hôte SRP, préfixes, adresses, MAC, nom et empreinte de la clé de la sonde
  (plan 3b). Il connaît les messages du firmware 1.0.3 et ceux de cette
  capture, la forme de chaque champ et les TLV de diagnostic que la tournée
  demande, jusque dans la Network Data ; il échoue devant tout le reste, sans
  rien écrire. Une capture déjà anonymisée ressort telle quelle.

### Route vers le réseau Thread
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, remplacer :

```markdown
  (identifiant du routeur chef), `canal`, `prefixeMaille`, `xp`, `suspendue`.
- `voisins` : `liste` d'objets `rloc16`, `ext`, `rssi`, `lqi`, `routeur`.
- `diag`, en cas de succès :
  `{"v":1,"t":"diag","id":7,"cible":"4800","ok":true,"ms":123,"tlv":"<hexa>"}`
```

par :

```markdown
  (identifiant du routeur chef), `canal`, `prefixeMaille`, `xp`, `suspendue`.
- `voisins` : `liste` d'objets `rloc16`, `ext`, `rssi`, `lqi`, `routeur`.
- `etat`, `voisins` et `routeurs`, quand la sonde n'a pas pu prendre le
  verrou d'OpenThread (200 ms) : `{"v":1,"t":"etat","erreur":"occupee"}`.
  L'app lit ce refus sans attendre l'échéance de la commande (plan 3b) :
  sans `etat`, la tournée s'arrête sur « la sonde est occupée et n'a pas
  répondu à « etat » » ; sans `routeurs` ni `voisins`, elle continue sans.
- `diag`, en cas de succès :
  `{"v":1,"t":"diag","id":7,"cible":"4800","ok":true,"ms":123,"tlv":"<hexa>"}`
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, remplacer :

```markdown
redessine au début de chaque minute (l'heure n'est observée par personne) :
« ancien » et le retour aux pointillés y paraissent avec une minute de retard
au plus.

**Avancement :** la tournée signale le début de chaque étape qu'elle
```

par :

```markdown
redessine au début de chaque minute (l'heure n'est observée par personne) :
« ancien » et le retour aux pointillés y paraissent avec une minute de retard
au plus. La fiche ouverte reçoit l'heure de ce redessin : son « vu il y a … »
et ses courbes suivent (plan 3b).

**Avancement :** la tournée signale le début de chaque étape qu'elle
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, remplacer :

```markdown
  (`etat.parent.rssi`) (ajout validé par Djoko le 30/09).
- Stockage : JSON Lines mensuel (`maillage-AAAA-MM.jsonl`) dans le dossier de
  l'app, gardé 90 jours comme le journal ; environ 5 Mo par mois.
- Affichage : courbes dans la fiche (Swift Charts) sur 24 h, 7 j et 30 j,
  avec les changements de parent marqués. Dans la fiche d'un routeur, une
```

par :

```markdown
  (`etat.parent.rssi`) (ajout validé par Djoko le 30/09).
- Stockage : JSON Lines mensuel (`maillage-AAAA-MM.jsonl`) dans le dossier de
  l'app, gardé 90 jours comme le journal ; environ 0,9 Ko par tournée pour
  7 routeurs et 20 enfants, soit 8 Mo par mois (5 Mo estimés à la
  conception ; mesuré au plan 3b).
- Affichage : courbes dans la fiche (Swift Charts) sur 24 h, 7 j et 30 j,
  avec les changements de parent marqués. Dans la fiche d'un routeur, une
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, remplacer :

```markdown
  parent de la sonde sont marqués, car le signal dépend d'abord de l'endroit
  où la sonde est posée (ajout du 30/09).

## 7. Tests, permissions, essai préalable (validée)
```

par :

```markdown
  parent de la sonde sont marqués, car le signal dépend d'abord de l'endroit
  où la sonde est posée (ajout du 30/09).

**Précisions du plan 3b (30/09)** (détail : plan 3b, « Écarts à la spec ») :
- seuls les enfants identifiés (ExtMac connue) sont suivis au journal et
  gardés dans l'historique : le RLOC16 d'un enfant change avec son parent ;
- « X n'a plus de parent » : absent de deux tournées où son absence est sûre
  (son dernier parent a répondu, a quitté la liste des routeurs, ou l'enfant
  venait d'un balayage) ; jamais pour la sonde, ni pour un enfant devenu
  routeur ;
- le premier maillage d'un lancement, le premier d'une autre partition, et
  le premier après l'oubli de la sonde, sont un point de départ : aucun
  événement ;
- les courbes font la moyenne par 30 min sur 7 j et par 2 h sur 30 j ; un
  trou de plus de 20 min (ou de trois pas) les coupe ; la qualité d'un enfant
  sous un routeur muet reste inconnue (seuls ses changements de parent se
  voient) ;
- l'app garde en mémoire les 30 derniers jours de l'historique ; rien n'est
  gardé ni montré en démo.

## 7. Tests, permissions, essai préalable (validée)
```

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, remplacer :

```markdown
préfixes (réseau maillé, OMR), les adresses et le `xp` sont remplacés par des
valeurs inventées, de façon cohérente d'une réponse à l'autre. Le code
d'appairage et le QR code sont retirés. L'anonymiseur ne connaît que les
messages `bonjour`, `etat` et `diag` de cette capture et échoue devant tout
autre type de message, champ ou TLV inconnu : les captures de la 1.0.2
(`etat.ext`, `voisins`, `routeurs`…) attendent l'anonymiseur complet de 3b.
Ces données servent à : décodage des TLV, reconstruction du maillage, tournée
(qui interroger, appareils endormis), rapprochement, et pour 3b les écarts du
```

par :

```markdown
préfixes (réseau maillé, OMR), les adresses et le `xp` sont remplacés par des
valeurs inventées, de façon cohérente d'une réponse à l'autre. Le code
d'appairage et le QR code sont retirés. L'anonymiseur (complet au plan 3b)
remplace aussi le nom d'hôte SRP, le nom de la sonde et l'empreinte de sa
clé ; il connaît les messages de la 1.0.3 et ceux de cette capture, la forme
de chaque champ et les TLV de diagnostic que la tournée demande, jusque dans
la Network Data, et échoue devant tout le reste. Une capture déjà anonymisée
ressort telle quelle.
Ces données servent à : décodage des TLV, reconstruction du maillage, tournée
(qui interroger, appareils endormis), rapprochement, et pour 3b les écarts du
```

Dans `sonde/README.md`, remplacer :

```markdown
| `oubli` | efface la clé, désappaire et redémarre : `{"v":1,"t":"oubli","cle_effacee":true\|false}` |

`<cible>` est un RLOC16 en 4 hexa, ou une adresse IPv6 du réseau maillé :
chiffres hexa, `:` et `.` seulement, sinon `syntaxe`. `<id>` et
```

par :

```markdown
| `oubli` | efface la clé, désappaire et redémarre : `{"v":1,"t":"oubli","cle_effacee":true\|false}` |

`etat`, `voisins` et `routeurs` répondent `{"v":1,"t":"<commande>","erreur":"occupee"}`
si le verrou d'OpenThread n'a pas pu être pris (200 ms).

`<cible>` est un RLOC16 en 4 hexa, ou une adresse IPv6 du réseau maillé :
chiffres hexa, `:` et `.` seulement, sinon `syntaxe`. `<id>` et
```

Dans `sonde/README.md`, remplacer :

```markdown

Les captures brutes contiennent les adresses du réseau de la maison. À passer
par `outils/anonymiser-sonde.py` avant de les mettre dans le dépôt.
L'anonymiseur échoue devant tout type de message, champ ou TLV inconnu, sans
rien écrire : il ne connaît que `bonjour`, `etat` et `diag` de la capture du
29/09. Une capture du firmware 1.0.2 ou plus récent (`etat.ext`,
`bonjour.hote`, `bonjour.nom`, `voisins`, `routeurs`) est donc refusée tant
qu'il ne les traite pas.

## Tests sur le Mac
```

par :

```markdown

Les captures brutes contiennent les adresses du réseau de la maison. À passer
par `outils/anonymiser-sonde.py` avant de les mettre dans le dépôt. Il
connaît les messages de la 1.0.3 (tous ceux du tableau, réponses « occupée »
comprises) et ceux de la capture du 29/09, la forme de chaque champ et les
TLV de diagnostic que la tournée demande, jusque dans la Network Data ; il
échoue devant tout le reste, sans rien écrire, et ne cite que des noms.
Une capture déjà anonymisée ressort telle quelle.

## Tests sur le Mac
```

Dans `sonde/README.md`, remplacer :

```markdown
`python3 -m unittest discover -s sonde/test` : les tests Python, sans carte ni
réseau : le masquage de la clé par `sonde_essai.py` (à l'écran et dans la
capture, y compris sur une ligne abîmée), le décodage du TLV 7 et la garde de
l'anonymiseur. `lancer.sh` ne les lance pas.
```

par :

```markdown
`python3 -m unittest discover -s sonde/test` : les tests Python, sans carte ni
réseau : le masquage de la clé par `sonde_essai.py` (à l'écran et dans la
capture, y compris sur une ligne abîmée), le décodage du TLV 7 et
l'anonymiseur (sa garde, ses remplacements, la capture du dépôt qui ressort
telle quelle). `lancer.sh` ne les lance pas.
```

- [ ] **Step 2 : les suites ne changent pas.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`
Expected: `** TEST SUCCEEDED **`, les effectifs de la fin de la tâche 10 (au rejeu : 253 tests en 25 suites, et 231 en 27 suites).

Run: `TMPDIR="$HOME/Library/Caches/maillage-plan3b/" xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" -testLanguage en -testRegion US test 2>&1 | grep -E "✘|Test run with|\*\* TEST"`
Expected: les mêmes effectifs, `** TEST SUCCEEDED **`.

Run: `python3 -m unittest discover -s sonde/test && /usr/bin/python3 -m unittest discover -s sonde/test`
Expected: `Ran 121 tests`, `OK`, deux fois.

- [ ] **Step 3 : commit.**

```bash
git add README.md README.fr.md docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md sonde/README.md
git commit -m "Documenter le journal, l'historique, les reponses occupee et l'anonymiseur complet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4 : vérification sur la carte, avec Djoko.** Chaque action sur une carte ou un port attend l'accord de Djoko. Le firmware ne change pas (1.0.3) : rien à flasher.

1. **App.** Recompiler (`DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b" TMPDIR="$HOME/Library/Caches/maillage-plan3b/" outils/tester.sh`), quitter l'app qui tourne ; Djoko lance la nouvelle en mode direct : `open "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b/Build/Products/Debug/Maillage Thread.app"`. La sonde retenue se reconnecte seule (USB ou réseau, comme avant). Aucun port non désigné n'est ouvert.
2. **Première tournée.** La ligne de la tournée montre « État de la sonde · 3/3 » (`etat`, `routeurs`, `voisins`). Dans le journal, rien de nouveau : c'est le point de départ. Dans le dossier de l'app (`~/Library/Containers/fr.djoko.maillage/Data/Library/Application Support/Maillage Thread/`), `maillage-AAAA-MM.jsonl` a une ligne ; la lire sans la copier dans le dépôt :

   ```bash
   tail -1 ~/Library/Containers/fr.djoko.maillage/Data/Library/Application\ Support/Maillage\ Thread/maillage-*.jsonl | python3 -m json.tool | head -40
   ```

   Attendu : `routeurs`, `liens`, `enfants`, `signaux` (au moins le parent de la sonde), `parentSonde`. (L'app est dans le bac à sable : son dossier est dans son conteneur, à côté de `identites-routeurs.json`.)
3. **Fiche à l'heure.** Djoko rafraîchit (le bouton du graphe relance aussi le passeur des noms de Maison), puis ouvre la fiche d'un appareil à pile : « · relevé il y a 1 minute » passe à « 2 minutes », puis « 3 minutes », sans autre action ni autre événement ; de même « · vu il y a … » dans la fiche d'un appareil disparu depuis peu. (Celui d'un appareil présent suit l'instantané, qui peut changer entre-temps.)
4. **Changement de parent.** Par la liaison réseau, Djoko pose la sonde dans une autre pièce. À une tournée suivante, le journal (famille « Maillage ») dit « <sonde> a changé de parent : A → B », sans notification (« Autres changements » décochée). Deux déplacements dans l'heure : une seule ligne « … a changé 2 fois de parent en 1 h », qui se déplie.
5. **Courbes, après quelques heures** (une douzaine de tournées au moins). La fiche d'un routeur qui répond (`5000` ou `6000`) : « Qualité des liens », une courbe par voisin ; celle d'un routeur de bordure d'Apple entendu par la sonde : « Signal vu par la sonde (dBm) », les changements de parent de la sonde en pointillé, avec le nom du nouveau parent ; celle d'un enfant d'un routeur qui répond : « Qualité du lien vers le parent ». Les boutons 24 h, 7 j, 30 j changent l'échelle ; le graphe ne bouge pas d'une fiche à l'autre ; les courbes avancent avec l'heure. La fiche d'un nœud sans historique le dit en une ligne.
6. **Démo.** L'app en mode direct quittée : `open "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan3b/Build/Products/Debug/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D` : fiche sans courbes, et le dernier fichier `maillage-*.jsonl` ne change pas (même taille avant et après). Quitter la démo, relancer l'app en mode direct.
7. **Taille.** Relever la taille du fichier et le nombre de lignes (`wc -c`, `wc -l`) : octets par tournée, et par mois (× 288 × 30).
8. **Capture 1.0.3, si Djoko le souhaite** (facultatif ; l'anonymiseur est validé sur des captures inventées). L'app quittée, la sonde en USB : `python3 sonde/sonde_essai.py <port de la sonde> docs/releves/<AAAA-MM-JJ>/capture-sonde-essai.jsonl bonjour etat voisins routeurs cle`, puis `python3 outils/anonymiser-sonde.py docs/releves/<AAAA-MM-JJ>/capture-sonde-essai.jsonl docs/releves/<AAAA-MM-JJ>/capture-sonde.jsonl`. (`<AAAA-MM-JJ>` : le jour de la capture.) Attendu : aucun refus, un bilan qui compte les ExtMac remplacées ; Djoko relit la capture anonymisée avant tout commit. La brute reste hors du dépôt (`.gitignore` : `capture-*-essai.jsonl`), et le dossier du 29/09 ne change pas (cinq tests de `sonde/test/test_sonde_essai.py` lisent sa réponse 206).

- [ ] **Step 5 : spec, section 8.** À la fin de la section 8, ajouter le paragraphe suivant, en remplaçant `<…>` par les valeurs du Step 4. Ce sont des comptes, des durées et des RLOC16, jamais une ExtMac ni une adresse.

```markdown
**Vérifié le <date> avec Djoko** (plan 3b, firmware 1.0.3 inchangé) : la
tournée demande `voisins` (« État de la sonde · 3/3 ») ; une ligne
d'historique de <o> octets par tournée (<n> routeurs, <e> enfants
identifiés), soit <m> Mo par mois ; les durées de la fiche ouverte
(« relevé il y a … ») avancent chaque minute ; changement de parent de la sonde noté au journal
sans notification, et regroupé dans l'heure ; après <h> heures, les courbes
des routeurs `<r1>` et `<r2>` (qualité, signal vu par la sonde) et d'un
enfant ; rien d'écrit en démo.
```

Commit : `git add docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, message « Noter la verification du plan 3b avec Djoko », terminé par la ligne `Co-Authored-By`. Avec la capture facultative du Step 4 : `git add` de la seule capture anonymisée, relue par Djoko, dans un commit à part.

---

## Couverture de la spec

| Spec, section 6 (et l'ajout du 30/09), et les suites de la vague de corrections | Tâches |
|---|---|
| Journal : « X a changé de parent : A → B » | 6 (événement), 8 (noms du graphe), écarts 1 à 3 |
| Journal : « X n'a plus de parent » | 6, écart 2 |
| Journal : un routeur Thread (hors routeurs de bordure) apparaît ou disparaît | 6, écart 3 |
| Changements de parent répétés regroupés : « X a changé 4 fois de parent en 1 h » | 7, écart 4 |
| Pas de notification par défaut, catégorie « Autres changements » | 6 (test `autresChangements`) |
| Historique : à chaque tournée, la qualité de chaque lien, entre routeurs et d'enfant à parent | 5 (`ReleveMaillage`), 8 (à chaque maillage reçu), écart 1 |
| Ajout : le signal (dBm) de chaque routeur que la sonde entend (`voisins`) et de son parent (`etat.parent.rssi`) | 2 (tournée, `SondeUSB`), 5 (dans le relevé), écart 8 |
| Ajout : la tournée demande `voisins`, par l'USB comme par le réseau | 2 (`SondeUSB.voisins()` sert les deux liaisons ; `voisins` est dans la liste blanche du firmware depuis la 1.0.2) |
| Stockage : JSON Lines mensuel `maillage-AAAA-MM.jsonl` dans le dossier de l'app, gardé 90 jours comme le journal | 5, 8 ; taille : écart 5, tâche 13 |
| Affichage : courbes dans la fiche (Swift Charts) sur 24 h, 7 j et 30 j, changements de parent marqués | 9, 10, écart 7 |
| Ajout : dans la fiche d'un routeur, « Signal vu par la sonde » sur 24 h, 7 j, 30 j, changements de parent de la sonde marqués | 9 (`signal`, `parentsSonde`), 10 |
| Jamais écrit en démo ni sous les tests hors d'un dossier temporaire | 8 (tests `rienSurDisqueEnDemo`, dossiers temporaires), écart 9 |
| Réponses « occupée » d'`etat` et de `voisins` (n° 36), et de `routeurs` | 3, écart 10 ; spec, section 3 : tâche 13 |
| Fiche à l'heure de la fenêtre du graphe (relecture du lot 4) | 4, 10 (`CourbesFiche(id:instant:)`), écart 11 ; spec, section 4 : tâche 13 |
| Oubli de la sonde : le maillage suivant est un point de départ | 8 (test `oubliRepartDeZero`), écart 3 |
| Anonymiseur complet (Q3 et lot 6) : champs et messages de la 1.0.2 et de la 1.0.3, sous-TLV des Prefix et des Service, longueur des TLV 1, 2, 5, 6, 16 et 24, texte des TLV 25 à 28, `refus_cadence`, capture déjà anonymisée | 11, 12, écart 12 ; spec, section 7 : tâche 13 |
| Spec à jour (sections 3, 4, 6 et 7) | 1 ; le reste : 13 |
| Vérification sur la carte | 13, avec Djoko |
