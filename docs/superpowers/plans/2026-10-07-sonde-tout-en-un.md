# Sonde tout-en-un : écoute des annonces MLE, résolution des parents, qualité des enfants : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Les tâches 1 à 11 peuvent aller à des sous-agents ; les tâches 12 à 16 se font avec Djoko, par le contrôleur de la session lui-même.

**Goal :** donner à la sonde, en firmware 1.1.0, l'écoute des messages MLE de ses voisins et la résolution d'adresse ; donner à Maillage Thread 1.1.0 les liens entendus, fusionnés avec ceux du diagnostic, la résolution des parents à la place du balayage, la qualité des enfants des routeurs Apple par leurs compteurs MAC, la source et l'âge de chaque lien dans la fiche, la couverture de l'écoute dans Réglages › Sonde et les champs facultatifs de l'historique ; puis, avec Djoko, flasher la sonde sans effacement, passer au banc, finir l'essai, fusionner, pousser et publier la 1.1.0.

**Architecture :**
- **Le décodage pur** (`sonde/src/mle.h`, `mle.cpp`), sans Arduino, testé sur le Mac : l'en-tête 802.15.4 (formats 2003/2006 et 2015 : numéro de séquence supprimé, PAN selon le tableau 7-2, IE d'en-tête et de charge), 6LoWPAN IPHC sans contexte, UDP vers le port MLE 19788, l'en-tête de sécurité MLE, le nonce et les données associées, la dérivation de la clé MLE, les TLV Source Address, Route64 et Leader Data ; les deux clés MLE gardées (`ClesMle`) ; la table des routeurs entendus (`TableEntendus`, 32 places, oubli après 10 min). La crypto est à part, comme pour H1 : mbedTLS sur la carte (`mle_crypto.cpp`), CommonCrypto dans le test, où le CCM est bâti sur l'AES-ECB. Les vecteurs viennent d'un script Python (`sonde/test/vecteurs_mle.py`, AESCCM de la bibliothèque `cryptography`), à clé et adresses inventées.
- **Sur la carte** (`sonde/src/ecoute.h`, `ecoute.cpp`, `main.cpp`) : le rappel des trames (`otLinkSetPcapCallback`), dans la tâche OpenThread, trie et copie dans une file FreeRTOS de 16 trames, sans verrou, sans Matter ni CHIP ; `loop()` décode (`ecoute::tour`). La clé réseau n'est lue, sous le verrou OpenThread, que quand la séquence de clé de la pile change, puis effacée. Les commandes `annonces` et `resoudre <ipv6> <id>` (`otIcmp6SendEchoRequest`, puis le cache d'adresses toutes les 250 ms, 15 s au plus, 8 en vol), `etat.ecoute`, la liste blanche du réseau ; la version 1.1.0.
- **Le cœur** (`MaillageCoeur/Maillage/`) : la lecture des messages 1.1.0 (`AnnonceSonde`, `ResultatResolution`, `CompteursEcoute`) et de la TLV 9 (`CompteursMac`) ; la fusion dans `ConstructionMaillage` : chaque sens d'un lien garde sa source et sa date, la mesure la plus récente l'emporte ; `QualiteCompteurs` ; la tournée (`Tournee.swift`) : `annonces` après `voisins`, l'écoute, la résolution des parents (`AppareilAResoudre`, `ResolutionAppareil`), qui remplace le balayage, les compteurs des enfants des routeurs muets ; l'historique et l'origine de chaque lien (`OrigineLien`).
- **L'app** (`MaillageThread/`) : `SondeUSB` (`annonces`, `diag(adresse:)`, `resoudre`) et les renvois du canal réseau ; la fiche (`FicheNoeud`), la couverture (`FenetreReglages`), les appareils à résoudre passés à la tournée (`Surveillance`, `SondeMaillage`) ; les textes par le catalogue.
- **La version 1.1.0** : `MARKETING_VERSION`, `NOTES-VERSIONS.md`, les README (ce que l'écoute apporte, et ses limites).

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI, AppKit, Swift Testing, XcodeGen, `xcodebuild` (Xcode 27) ; C++ (gnu++17) sur pioarduino 55.03.312-1 (Arduino-ESP32 3.3.12, ESP-IDF 5.5.5, OpenThread et mbedTLS de l'ESP-IDF, Matter 1.5), PlatformIO ; clang++ de Xcode (ASan, UBSan, CommonCrypto) pour les tests hôte ; Python 3.9 (`/usr/bin/python3`, `unittest`, sans dépendance) ; le Python de PlatformIO (`~/.platformio/penv/bin/python`, bibliothèque `cryptography`), pour les vecteurs seulement.

**Spec :** `docs/superpowers/specs/2026-10-07-sonde-tout-en-un-design.md` (validée par Djoko le 07/10, partie par partie). Le brief de ce plan est privé : `.superpowers/sonde-tout-en-un/plan-brief.md`.

**Quand l'exécuter.** Après la validation de ce plan par Djoko, sur un worktree neuf (Global Constraints). Les numéros de ligne ne sont jamais cités : l'exécutant se repère aux blocs, qui s'appliquent au texte exact.

## La préparation du 07/10 : essai, code validé, rejeu

**L'essai du 07/10** (spec, section 0), sur une seconde carte C6 ajoutée à Maison (« Sonde essai »), avec un firmware jetable (branche `essai-ecoute`, jamais fusionnée) :
- **prouvé sur la carte** : la dérivation de la clé MLE, le nonce, les données associées, l'ordre des octets, le déchiffrement des trames au format 2006 (des centaines de messages, aucun échec) et la lecture du cache d'adresses ;
- **jamais exercé** : les trames au format 2015 (aucune entendue) et `otIcmp6SendEchoRequest` (l'essai déclenchait la résolution par un `diag` vers l'adresse publique). Les tests hôte couvrent le format 2015 ; le banc (tâche 13) voit la résolution par la demande d'écho ;
- les routeurs Apple répondent à une résolution avec **leur propre** RLOC16 (`xx00`), les routeurs tiers avec celui de l'enfant (`xxNN`) ;
- le diagnostic (TMF) n'est accepté que sur les adresses internes (RLOC, ML-EID), jamais sur l'adresse publique (OMR) : la TLV 9 se demande au ML-EID que donne le cache ;
- un appareil endormi ne rend pas la TLV 4, mais rend la TLV 9 : 9 compteurs de 32 bits, gros-boutistes, dans l'ordre de la spec Thread (`ifInUnknownProtos`, `ifInErrors`, `ifOutErrors`, `ifInUcastPkts`, `ifInBroadcastPkts`, `ifInDiscards`, `ifOutUcastPkts`, `ifOutBroadcastPkts`, `ifOutDiscards`) ;
- par le réseau, une ligne de réponse fait 1100 octets au plus : une réponse en plusieurs lignes porte `"suite":true` sur toutes sauf la dernière, comme `routeurs` ;
- `dns-sd` rend des adresses avec un suffixe d'interface (`%…`) : l'app n'envoie à la sonde que l'adresse nue (`AdresseIPv6` n'a pas de suffixe).

**Code validé avant exécution.** Le 07/10, tout le code de ce plan a été écrit en TDD, compilé et testé dans un worktree, sur la branche `sonde-tout-en-un-brouillon`, à partir de `554f5e8`. Puis le plan a été rejoué sur un worktree neuf (branche `sonde-tout-en-un-rejeu`), ses blocs appliqués par `appliquer-blocs.py` sur le brief de chaque tâche, ses commandes lancées telles quelles : l'arbre final est identique à celui de la copie validée, au plan près (arbre `bfe95eea203d0261ce37f23f462c0c9177bc9689`). Le rejeu a corrigé le plan en deux points : un test de la tournée (`lienDecideParLePlusGrandIdentifiant`), rouge dans la copie validée de sa tâche 5 jusqu'à sa tâche 7, est mis à jour dès la tâche 5 (les arbres des tâches 5 et 6 diffèrent donc de ceux de la copie validée par ces deux lignes, les autres sont identiques) ; et les cibles de test sont les bonnes (`SondeUSBTests` et `SondeMaillageTests`, les deux suites de `SondeTests.swift` ; `QualiteCompteursTests`). Les résultats attendus ci-dessous viennent de ce rejeu.
- **Les suites,** en français et en anglais, sans avertissement : 440 tests en 43 suites pour le cœur, 418 en 35 pour l'app (avant ce plan : 420 et 42, 409 et 35) ;
- **les tests hôte de la sonde :** `test_h1` 121 vérifications, `test_distant` 154 (145 avant), `test_mle` 72 874 (nouveau) ; **les tests Python :** `sonde/test` 146 tests (141 avant), `outils/tests` 96 (inchangés) ; `vecteurs_mle.py --verifier` : conforme ;
- **`pio run`** compile, sans avertissement dans `sonde/src/` : 76,5 % de la flash et 53,1 % de la RAM (76 % et 55 % à l'essai) ;
- **les images de démo** ne changent pas : les 21, rendues avant la tâche 2 et après la tâche 10, sont identiques octet pour octet. Le maillage de la démo n'a ni source ni date : la fiche du chef n'a pas une ligne de plus.

**Faits établis** (Xcode 27, macOS 27, le 07/10) :
- **`python3`** est, dans le shell de la session, celui de PlatformIO : les outils et les tests Python se lancent par `/usr/bin/python3` ; le script des vecteurs, lui, par `~/.platformio/penv/bin/python`, seul à avoir `cryptography`. Sans elle, il s'arrête sur `ModuleNotFoundError`.
- **« Could not launch “MaillageThreadTests” »** (LaunchServices, `-10699`) arrive parfois (deux fois sur huit à la base, au rejeu, comme après ce plan) : relancer la commande ; si l'erreur revient, lancer `outils/tester.sh MaillageCoeurTests`, puis `outils/tester.sh MaillageThreadTests`.
- **Une app de travail peut être arrêtée en route,** sans rapport de plantage ni message : l'hôte des tests (« Restarting after unexpected exit, crash, or test timeout », puis `** TEST FAILED **` alors que tous les tests lancés passent), ou l'app des captures (moins de 21 images, la dernière à moitié écrite, `….png.sb-…`). Vu trois fois au rejeu (deux sur l'hôte des tests, une sur les captures), jamais reproduit en relançant la même commande, une vingtaine de fois ; c'est l'app de même identifiant que celle de Djoko, qui tourne. Relancer la commande.
- **Une compilation peut être interrompue de l'extérieur** (`** BUILD INTERRUPTED **`) quand une autre session compile en même temps : relancer la commande.
- **`pio run`** sans `-t` ne touche à aucun port. Dans un worktree neuf, la première compilation recompile le cadre Arduino dans `sonde/.pio` (ignoré par git) : une demi-minute au rejeu ; les suivantes, quelques secondes.
- **`xcstringstool sync`** (`outils/synchroniser-textes.sh`) marque « stale » une clé disparue du code, et `traduire.py` retire les clés « stale » ; mais il remet toute clé de `interface.json` : le script des textes de la tâche 7 y retire donc « Balayage des routeurs muets ».
- **L'app 1.0.0 lit l'historique de la 1.1.0** : elle décode chaque lien et chaque enfant champ par champ et ignore ceux qui suivent (les sources, le taux d'échec). Une app 1.0.0 relancée après le banc ne perd donc rien.
- Sous zsh, `echo ====` échoue : les séparateurs s'écrivent `== …`.

## Précisions

Ce sont les choix faits à l'écriture du code, là où la spec et le brief laissaient la main ; Djoko les valide avec le plan.
1. **Deux clés MLE, dérivées seulement quand la séquence change.** `ClesMle` garde les clés de la séquence courante de la pile et de la suivante (la rotation). Une trame d'une autre séquence ne fait jamais relire la clé réseau : la carte la relit une fois quand la séquence de la pile a changé, puis l'efface. Une trame forgée ne peut donc pas la faire lire en boucle.
2. **Le rappel ne garde que les trames de données sans sécurité MAC** (les messages MLE ne sont pas chiffrés au niveau MAC), de 127 octets au plus ; les trames émises par la sonde sont ignorées. `etat.ecoute.trames` compte toutes les trames reçues, avant ce tri ; `echecs`, les messages MLE chiffrés non déchiffrés (en-tête illisible, clé indisponible, MIC faux).
3. **La table des routeurs entendus** se met à jour à chaque message d'un routeur (RLOC16 en `xx00`, TLV Source Address présente) : signal, nombre, âge ; la partition et la Route64 restent celles du dernier message qui les portait (une Link Request n'en a pas). Table pleine, le routeur entendu le moins récemment laisse sa place.
4. **`annonces`** suit l'ordre des places de la table ; `"seq"` est le numéro de séquence de la Route64 (`null` sans Route64) ; la dernière ligne porte `"suite":false`. L'app trie elle-même, du plus ancien message au plus récent.
5. **`resoudre` a sa propre réserve de 8 places**, à part de celle de `diag` : 8 diagnostics et 8 résolutions peuvent être en vol ensemble. Une entrée du cache d'adresses en état `CACHED` ou `SNOOPED` vaut réponse ; `mleid` est l'identifiant ML-EID de 16 octets, en 32 hexa (`null` si le cache ne l'a pas). Un rid répété par le réseau ne relance pas une résolution encore en vol, comme pour `diag`.
6. **Sans `annonces` (firmware 1.0.x), la tournée ne fait ni l'écoute, ni la résolution, ni les compteurs** : la sonde ne connaît ni `resoudre`, ni le diagnostic à un ML-EID. Le balayage n'existe plus : la tournée s'en tient au diagnostic.
7. **Les enfants résolus ne s'ajoutent que sous un routeur muet** : sous un routeur qui répond, sa table des enfants fait foi. Un appareil déjà là (même ExtMac ou même adresse qu'un enfant d'une table ou que la sonde) n'est pas ajouté, ni un appareil dont la résolution rend le RLOC16 d'un routeur de même ExtMac (c'est ce routeur).
8. **L'enfant d'un routeur Apple reçoit un RLOC16 inventé** : la réponse Apple ne donne que le RLOC16 du parent ; l'enfant prend celui du parent, avec le bit 9 (`EnfantMaillage.bitInvente`, nul dans un vrai RLOC16 : l'identifiant d'enfant tient sur 9 bits) et un numéro dans l'ordre des appareils. La fiche ne l'affiche pas.
9. **Les compteurs** : le relevé gardé est remplacé à chaque lecture, par appareil (son identifiant, qui porte l'ExtMac d'un appareil Matter), en mémoire seulement ; le taux est celui des deux derniers relevés. Moins de 50 envois entre eux, ou un compteur qui baisse : qualité inconnue, et le relevé repart du dernier. La TLV 9 n'est demandée qu'aux enfants des routeurs muets, à leur résolution.
10. **La résolution est complète toutes les 30 min** ; entre deux, la tournée ne résout que les appareils jamais demandés (un appareil nouveau). Une demande que la sonde refuse (`occupee`, `suspendue`, `envoi…`) ne compte pas : elle est refaite à la tournée suivante ; un appareil refusé garde sa résolution d'avant, et une résolution complète dont toutes les demandes sont refusées ne remplace pas la précédente. La sonde n'est jamais résolue.
11. **L'historique** écrit des codes courts : `d` ou `e` pour la source de chaque sens d'un lien, `t`, `r` ou `s` pour un enfant (table, résolution, sonde), et le taux d'échec arrondi au dix-millième ; ni les dates des mesures, ni le ML-EID. Un lien sans source s'écrit comme avant (4 champs) ; un code inconnu se lit sans source.
12. **La fiche** : la ligne du parent d'un appareil porte son origine (« résolu il y a 12 minutes · compteurs de l'enfant : 0,7 % d'échecs ») ; la fiche d'un routeur liste ses liens radio qui ont une source, par nom de voisin ; « jamais entendu par la sonde ; liens vus seulement par ses voisins » ne paraît que si la tournée a lu les annonces. Le RLOC16 inventé n'est pas affiché.
13. **La couverture** (« routeurs entendus : n sur m ») compte les routeurs de la liste de la partition (Route64) qui ont une annonce à cette tournée ; sans annonces lues, la ligne n'est pas là.
14. **L'anonymiseur** (`outils/anonymiser-sonde.py`) n'apprend pas les messages de la 1.1.0 : il les refuse, comme tout message inconnu, sans rien écrire (les README le disent). Il sera à étendre avant de faire une donnée de test d'une capture 1.1.0.
15. **`sonde_essai.py`** envoie `annonces` et `resoudre` et les affiche (les liens de chaque Route64 ; la résolution, avec 20 s d'attente) ; leurs données ne sont jamais masquées (une Route64 n'est pas une clé).

## Global Constraints

- **Plateformes :** Maillage Thread en macOS 26.0 minimum, développé avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus. La sonde : ESP32-C6 SuperMini, pioarduino 55.03.312-1, comme `sonde/platformio.ini`.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`. Code : identifiants et commentaires en français **sans accents** ; textes affichés avec accents, par le catalogue ; tests en Swift Testing (app), `unittest` (Python 3.9, `/usr/bin/python3`, sans dépendance) et programmes C++ de `sonde/test/` (`sh sonde/test/lancer.sh`).
- **Sécurité de la sonde :**
  - la clé réseau ne sort jamais de la carte et n'apparaît dans aucune ligne de sortie ; elle et les clés MLE dérivées sont effacées de la mémoire après usage ; aucune commande ne les rend ;
  - le rappel des trames s'exécute dans la tâche OpenThread : il ne bloque jamais (file pleine : comptée) et n'appelle ni Matter ni CHIP ; la règle de `main.cpp` tient : aucun appel Matter ou CHIP sous le verrou OpenThread ;
  - les tests et les vecteurs n'ont que des valeurs inventées (clé réseau `00112233445566778899AABBCCDDEEFF`, ExtMac `E000…`, partition `1234ABCD`).
- **Variables.** Le shell d'un agent ne garde pas ses variables d'une commande à l'autre : chaque commande porte les siennes. `$S` est le scratchpad de la session ; son chemin n'est écrit ni dans ce plan ni dans un commit (il contient le nom d'utilisateur).
  - `P=$HOME/Dev/maillage-thread/.superpowers/sonde-tout-en-un` : le dossier privé (ignoré par git) : le plan, les briefs des tâches, les sorties privées ;
  - `W=$S/sonde-tout-en-un-exec` : le worktree, hors d'iCloud : `$W/maillage`, sur la branche `sonde-tout-en-un` ;
  - `DD=$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec` : le seul dossier de produits de ce plan (l'app de Djoko tourne depuis Applications) ; `TMPDIR=$HOME/Library/Caches/sonde-tout-en-un-exec/` ;
  - `AB=$HOME/Dev/maillage-thread/.superpowers/archives/polissage-c-sdd/appliquer-blocs.py` : l'outil des blocs ;
  - `A=$HOME/Dev/maillage-thread/.superpowers/anonymisation` : le contrôle d'anonymisation (`$A/outils/controles.py`, `$A/execution/table.json`).
- **Une fois, avant la tâche 1 :**

  ```bash
  P=$HOME/Dev/maillage-thread/.superpowers/sonde-tout-en-un; W=$S/sonde-tout-en-un-exec
  mkdir -p "$P" "$W" "$HOME/Library/Caches/sonde-tout-en-un-exec"
  git -C ~/Dev/maillage-thread show sonde-tout-en-un-brouillon:docs/superpowers/plans/2026-10-07-sonde-tout-en-un.md > "$P/plan.md"
  git -C ~/Dev/maillage-thread worktree add -q -b sonde-tout-en-un "$W/maillage" main
  git -C "$W/maillage" log --oneline -1
  ```

  Expected : `554f5e8 Ecrire la spec de la sonde tout-en-un : ecoute des annonces MLE, resolution des parents, qualite des enfants`. Si `main` a avancé, les blocs s'appliquent tant que leur texte est le même ; sinon, l'exécutant applique le même changement au texte du moment et le dit.
- **Le brief d'une tâche** (pour `appliquer-blocs.py`) : `awk -v n=N '$0 ~ "^### Task " n ":" {f=1} f && $0 ~ "^### Task " n+1 ":" {f=0} f' "$P/plan.md" > "$P/brief-N.md"`. **Blocs :** un fichier existant change par blocs « remplacer … par … », ou en entier ; un fichier créé l'est tel quel. Les blocs d'une étape s'appliquent par `/usr/bin/python3 "$AB" "$P/brief-N.md" --etapes K`, **depuis `$W/maillage`** (le `--verifier` d'abord, si l'on veut : il n'écrit rien). Les catalogues (`.xcstrings`), `outils/traductions/interface.json` et `sonde/test/vecteurs_mle.h` ne changent que par les outils.
- **Les tests de Maillage Thread :** `DD="$DD" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh [cibles…]`, depuis `$W/maillage` (journal dans `$TMPDIR/maillage-tests.log`) ; une cible : `MaillageCoeurTests/TourneeTests`. En anglais :

  ```bash
  W=$S/sonde-tout-en-un-exec; DD=$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec; cd "$W/maillage" && xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$DD" -testLanguage en -testRegion US test > "$HOME/Library/Caches/sonde-tout-en-un-exec/maillage-en.log" 2>&1; echo "code $?"; grep -E "(error|warning): |✘|Test run with|\*\* TEST" "$HOME/Library/Caches/sonde-tout-en-un-exec/maillage-en.log" | grep -v -e appintentsmetadataprocessor -e "\[Connection\]"
  ```

- **Les tests de la sonde,** depuis `$W/maillage` : `sh sonde/test/lancer.sh` (hôte) ; `/usr/bin/python3 -m unittest discover -s sonde/test` et `/usr/bin/python3 -m unittest discover -s outils/tests` (Python) ; `~/.platformio/penv/bin/python sonde/test/vecteurs_mle.py --verifier` (les vecteurs) ; `cd sonde && ~/.platformio/penv/bin/pio run` (la compilation, **jamais** `-t`).
- **Une suite à la fois** sur ce Mac ; une compilation interrompue de l'extérieur se relance (faits établis).
- **Données :** aucune donnée réelle (réseau, adresses, ExtMac, MAC, préfixes, noms de pièces ou d'appareils, prénom) dans un fichier commité ; les tests n'utilisent que des valeurs inventées. **Chaque commit** passe d'abord le contrôle d'anonymisation sur ses fichiers (son étape de commit le fait) : `trouve : aucun`, sinon pas de commit. Les sorties qui portent une MAC ou une adresse réelle (le flash, l'effacement, le banc) vont dans `$P`, dont on ne montre que des comptes et des lignes choisies.
- **Commits :** un par tâche, en français sans accents, terminés par une ligne vide puis `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ; `git add` avec la liste de la tâche, jamais `-A` ni `.` ; l'auteur est celui de la configuration du dépôt (Djoko-cli, adresse noreply).
- **Étapes avec Djoko** (tâches 12 à 16) : le contrôleur décrit le geste, attend un oui clair dans la conversation, puis l'exécute ; un accord vaut pour un geste. Djoko désigne lui-même chaque port ; ce qui se fait dans Maison ou dans macOS (retirer un accessoire, quitter une app, une demande d'accès au trousseau), c'est lui qui le fait.
- **Interdits** pour les agents :
  - `sudo` ; **les ports série et le flash** hors des tâches 12 et 14 (aucun `pio run -t upload`, `-t erase`, `pio device monitor`, `esptool`, aucun accès à `/dev/cu.*`) ;
  - lancer Maillage Thread en mode direct hors de la tâche 13 (seulement en démo, pour ses images, et ses tests), réveiller l'écran, `screencapture`, quitter les apps de Djoko (pour arrêter une instance de ce plan : `kill` sur son PID) ;
  - un push ou un `gh` qui modifie quelque chose hors des tâches 15 et 16 ; toucher le trousseau de Djoko (les tests ne le touchent jamais).
- **Disque :** environ 7 Go libres. Les DD, les caches et les produits de ce plan vont à la corbeille (`~/.Trash`) à la fin ; rien ne s'efface définitivement.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `sonde/src/mle.h`, `sonde/src/mle.cpp` (nouveaux) | le décodage pur : 802.15.4, IPHC, UDP, en-tête de sécurité MLE, nonce, données associées, clé MLE, TLV ; `ClesMle`, `TableEntendus` | 2 |
| `sonde/src/mle_crypto.cpp` (nouveau) | HMAC-SHA256 et AES-CCM par mbedTLS, sur la carte | 2 |
| `sonde/test/vecteurs_mle.py`, `sonde/test/vecteurs_mle.h` (nouveaux) | le script des vecteurs, à clé et adresses inventées, et le fichier qu'il écrit | 2 |
| `sonde/test/test_mle.cpp` (nouveau), `sonde/test/lancer.sh` | les tests hôte de l'écoute (CommonCrypto ; le CCM sur l'AES-ECB) | 2 |
| `sonde/src/ecoute.h`, `sonde/src/ecoute.cpp` (nouveaux) | le rappel des trames, la file, le décodage dans `loop()`, les compteurs, la table | 3 |
| `sonde/src/main.cpp` | la version 1.1.0, la clé sous le verrou, `annonces`, `resoudre`, `etat.ecoute` | 3 |
| `sonde/src/distant.cpp`, `sonde/src/distant.h`, `sonde/test/test_distant.cpp` | la liste blanche : `annonces`, `resoudre` | 3 |
| `sonde/sonde_essai.py`, `sonde/test/test_sonde_essai.py` | l'outil d'essai : `annonces`, `resoudre` | 3 |
| `sonde/README.md`, `sonde/platformio.ini` | la sonde 1.1.0 : écoute, résolution, commandes, tests | 3 |
| `MaillageCoeur/Maillage/ProtocoleSonde.swift`, `DiagnosticThread.swift`, et leurs tests | les messages de la 1.1.0 ; la TLV 9 | 4 |
| `MaillageCoeur/Maillage/Maillage.swift`, `QualiteCompteurs.swift` (nouveau), `MaillageCoeurTests/MaillageTests.swift` (et un test de `TourneeTests.swift`) | la fusion des sources, la couverture, les enfants résolus ; la qualité par les compteurs | 5, 7 |
| `MaillageThread/Sonde/SondeUSB.swift`, `MaillageThread/Sonde/Reseau/CanalReseau.swift`, et leurs tests | `annonces`, `diag(adresse:)`, `resoudre` ; leurs délais et leurs renvois | 6 |
| `MaillageCoeur/Maillage/Tournee.swift`, `Resolution.swift` (nouveau), `SuiviMaillage.swift`, `Rapprochement.swift`, `MaillageCoeur/Demo/MaillageDemo.swift`, et leurs tests | la tournée : écoute, résolution à la place du balayage, compteurs ; le journal | 7 |
| `MaillageThread/Sonde/TexteTournee.swift`, `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, `MaillageThread/Surveillance/Surveillance.swift`, et leurs tests | les étapes de la tournée affichées | 7 |
| `MaillageCoeur/Maillage/HistoriqueMaillage.swift`, `Rapprochement.swift`, et leurs tests | les champs facultatifs de l'historique ; l'origine de chaque lien | 8 |
| `MaillageThread/Vues/Pieces/FicheNoeud.swift`, `MaillageThread/Vues/FenetreReglages.swift`, `MaillageThread/Sonde/SondeMaillage.swift`, `MaillageThread/Surveillance/Surveillance.swift`, `MaillageThread/MaillageThreadApp.swift`, et leurs tests | la fiche, la couverture, les appareils à résoudre | 9 |
| `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json` | les textes (par les outils) | 7, 9 |
| `project.yml`, `MaillageThreadTests/MisesAJourTests.swift`, `NOTES-VERSIONS.md`, `README.md`, `README.fr.md` | la version 1.1.0 | 10 |
| `docs/superpowers/specs/2026-10-07-sonde-tout-en-un-design.md` | le banc, noté (comptes seulement) | 13 |
| `docs/superpowers/plans/2026-10-07-sonde-tout-en-un.md` | ce plan, ajouté à la branche avant la fusion | 15 |
| `appcast.xml` | le flux des mises à jour, commité et poussé par `publier.sh` | 16 |

**Privé** (`$P`, jamais commité) : `plan.md` et `brief-N.md` ; `flash-1.1.0.txt`, `effacement-essai.txt`, `banc.txt` (tâches 12 à 14 : ils portent une MAC ou des adresses réelles) ; `controle-*.txt` (tâche 15).

---

### Task 1: L'état de départ

**Files :** aucun.

**Interfaces:**
- Consumes : `main` en `554f5e8`, et le worktree `$W/maillage` (Global Constraints).
- Produces : les effectifs de départ, et les 21 images de démo de référence (tâche 11).

- [ ] **Step 1 : les suites de l'app, au départ.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh`

Expected : `Test run with 420 tests in 42 suites passed` (cœur) et `Test run with 409 tests in 35 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 2 : les tests de la sonde et des outils, au départ.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && sh sonde/test/lancer.sh && /usr/bin/python3 -m unittest discover -s sonde/test 2>&1 | tail -3 && /usr/bin/python3 -m unittest discover -s outils/tests 2>&1 | tail -3`

Expected : `test_h1 : 121 verification(s), 0 echec(s)` ; `test_distant : 145 verification(s), 0 echec(s)` ; `Ran 141 tests`, `OK` ; `Ran 96 tests`, `OK` (`outils/tests` dure deux à trois minutes).

- [ ] **Step 3 : les images de démo de référence.**

```bash
W=$S/sonde-tout-en-un-exec; D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-sonde-tout-en-un-exec-base"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "[s]onde-tout-en-un-exec/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitte"
```

Expected : `21` ; `l'app a quitte`. Moins de 21 (l'app arrêtée en route, faits établis) : mettre `$D` à la corbeille et relancer le step.

Pas de commit.

---

### Task 2: Le décodage et le déchiffrement MLE, dans un module pur testé sur le Mac

**Files :**
- Create : `sonde/test/vecteurs_mle.py`, `sonde/test/vecteurs_mle.h` (par le script), `sonde/test/test_mle.cpp`, `sonde/src/mle.h`, `sonde/src/mle.cpp`, `sonde/src/mle_crypto.cpp`
- Modify : `sonde/test/lancer.sh` (en entier)

**Interfaces:**
- Consumes : rien de la carte ; `mle.h` et `mle.cpp` n'incluent ni Arduino, ni OpenThread, ni mbedTLS.
- Produces (`namespace mle`, `sonde/src/mle.h`) :
  - les constantes `kPortMle` (19788), `kPsduMax` (127), `kRoute64Max` (72), `kCle`, `kNonce`, `kMic`, `kEnTeteSecurite` (10), `kDonneesAssociees` (42), `kSuiteChiffree` (0), `kControle` (`0x15`), `kNiveau` (5) ;
  - la crypto, fournie par la plateforme : `hmacSha256(cle, nCle, message, n, sortie)` et `aesCcmDechiffrer(cle, nonce, aad, nAad, chiffre, n, mic, clair)`, qui efface `clair` quand le MIC est faux ; `effacer(p, n)` ;
  - les briques : `lireMac(psdu, n, &EnTeteMac)` (trames de données sans sécurité MAC), `lireDatagramme(psdu, mac, &Datagramme) -> Refus` (`Aucun`, `PasIphc`, `Contexte`, `PasUdp`, `Tronquee`), `lienLocal`, `lireSecuriteMle`, `extDepuisIid`, `nonceMle`, `donneesAssociees`, `deriverCleMle`, `lireTlv` ;
  - `decoder(psdu, n, FournisseurCle, contexte, &Message) -> Issue` (`Ignoree`, `Dechiffree`, `Echec`) ; `Message` porte l'ExtMac de l'émetteur, la commande MLE, le RLOC16 (TLV Source Address), la partition (Leader Data) et la Route64 brute ;
  - `ClesMle` : `preparer(courante, cleReseau)` (dérive la courante et la suivante), `trouver(sequence, cle)`, `preparees()`, `courante()`, `effacer()` ;
  - `Entendu` et `TableEntendus` (`kPlaces` 32, `kOubliMs` 600 000) : `noter(message, rssi, maintenant)`, `oublier(maintenant)`, `place(i)`, `nombre()`.

Le script des vecteurs calcule à part (HMAC de la bibliothèque standard, AESCCM de `cryptography`) ce que le module doit trouver : 22 trames, chacune avec son issue et, déchiffrée, sa commande, son RLOC16, sa partition et sa Route64, ou son refus. Le test bâtit le CCM (RFC 3610, L = 2, M = 4) sur l'AES-ECB de CommonCrypto ; il passe aussi chaque trame tronquée, chaque octet abîmé, et 200 000 trames tirées au hasard (la moitié formées jusqu'au déchiffrement), sous ASan et UBSan.

- [ ] **Step 1 : le script des vecteurs** (`--etapes 1`).

`sonde/test/vecteurs_mle.py` :

```python
#!/usr/bin/env python3
"""Vecteurs de test de l'ecoute MLE de la sonde (sonde/src/mle.h), ecrits dans sonde/test/vecteurs_mle.h.

Des trames 802.15.4 inventees, qui portent des messages MLE chiffres comme les routeurs Thread les envoient : en-tete
MAC aux formats 2006 et 2015 (sequence supprimee, PAN selon le tableau 7-2, IE d'en-tete et de charge), 6LoWPAN IPHC
sans contexte (adresses en ligne ou tirees des adresses MAC, multicast compresse), UDP compresse ou non, en-tete de
securite MLE, AES-CCM a MIC de 4 octets. La cle reseau, les ExtMac, la partition et les routeurs sont inventes ; rien
ne vient d'un vrai reseau. Le calcul est independant du firmware : HMAC-SHA256 de la bibliotheque standard, AES-CCM de
la bibliotheque cryptography (presente dans le Python de PlatformIO, ~/.platformio/penv/bin/python).

  ~/.platformio/penv/bin/python sonde/test/vecteurs_mle.py             # ecrit sonde/test/vecteurs_mle.h
  ~/.platformio/penv/bin/python sonde/test/vecteurs_mle.py --verifier  # compare au fichier commite
"""
import hashlib
import hmac
import os
import struct
import sys

from cryptography.hazmat.primitives.ciphers.aead import AESCCM

ICI = os.path.dirname(os.path.abspath(__file__))
SORTIE = os.path.join(ICI, 'vecteurs_mle.h')

CLE_RESEAU = bytes.fromhex('00112233445566778899AABBCCDDEEFF')
SEQUENCE = 5          # sequence courante de la pile, dans les tests ; la suivante (6) se dechiffre aussi
PAN = 0xFACE
PARTITION = 0x1234ABCD
PORT_MLE = 19788
PORT_TMF = 61631

EXT_A = bytes.fromhex('E000000000000A01')   # routeur 20 (5000)
EXT_B = bytes.fromhex('E000000000000B02')   # routeur 1 (0400)
EXT_C = bytes.fromhex('E000000000000C03')   # routeur 43 (AC00)
EXT_E = bytes.fromhex('E000000000000E05')   # un enfant (5004)
EXT_SONDE = bytes.fromhex('E00000000000F0F0')

IGNOREE, DECHIFFREE, ECHEC = 0, 1, 2
AUCUN, PAS_IPHC, CONTEXTE, PAS_UDP, TRONQUEE = 0, 1, 2, 3, 4


def cle_mle(sequence):
    """Les 128 premiers bits de HMAC-SHA256(cle reseau, sequence gros-boutiste || « Thread »)."""
    return hmac.new(CLE_RESEAU, struct.pack('>I', sequence) + b'Thread', hashlib.sha256).digest()[:16]


def fcs(octets):
    """FCS de 802.15.4 : CRC-16 de l'UIT-T, bits de poids faible d'abord, en petit-boutiste."""
    crc = 0
    for o in octets:
        crc ^= o
        for _ in range(8):
            crc = (crc >> 1) ^ 0x8408 if crc & 1 else crc >> 1
    return struct.pack('<H', crc)


def iid_ext(ext):
    """Identifiant d'interface d'une ExtMac : le bit U/L inverse."""
    return bytes([ext[0] ^ 0x02]) + ext[1:]


def iid_court(court):
    return bytes([0, 0, 0, 0xFF, 0xFE, 0, court >> 8, court & 0xFF])


def lien_local(iid):
    return bytes.fromhex('FE80000000000000') + iid


def multicast(texte):
    """ff02::1 etc., en 16 octets."""
    groupes = texte.split('::')
    tete = [int(x, 16) for x in groupes[0].split(':') if x]
    queue = [int(x, 16) for x in groupes[1].split(':') if x] if len(groupes) > 1 else []
    mots = tete + [0] * (8 - len(tete) - len(queue)) + queue
    return b''.join(struct.pack('>H', m) for m in mots)


def mac(version, dst, src, compression, sequence=0x42, supprimer_sequence=False, ies=b'', ie_present=False,
        securite=False):
    """En-tete MAC d'une trame de donnees. dst, src : (mode, adresse dans l'ordre naturel) ; mode 0, 2 ou 3."""
    mode_dst, a_dst = dst
    mode_src, a_src = src
    fcf = 0x0001 | (0x0008 if securite else 0) | (0x0040 if compression else 0)
    fcf |= (0x0100 if supprimer_sequence else 0) | (0x0200 if ie_present else 0)
    fcf |= mode_dst << 10 | version << 12 | mode_src << 14
    if version < 2:
        pan_dst, pan_src = mode_dst != 0, mode_src != 0 and not compression
    else:
        # 802.15.4-2015, tableau 7-2.
        if not mode_dst and not mode_src:
            pan_dst, pan_src = compression, False
        elif mode_dst and not mode_src:
            pan_dst, pan_src = not compression, False
        elif not mode_dst:
            pan_dst, pan_src = False, not compression
        elif mode_dst == 3 and mode_src == 3:
            pan_dst, pan_src = not compression, False
        else:
            pan_dst, pan_src = True, not compression
    h = struct.pack('<H', fcf)
    if not supprimer_sequence:
        h += bytes([sequence])
    if pan_dst:
        h += struct.pack('<H', PAN)
    h += a_dst[::-1]
    if pan_src:
        h += struct.pack('<H', PAN)
    h += a_src[::-1]
    return h + ies


def ie_entete(identifiant, valeur):
    return struct.pack('<H', len(valeur) | identifiant << 7) + valeur


def ie_charge(groupe, valeur):
    return struct.pack('<H', len(valeur) | groupe << 11 | 0x8000) + valeur


def somme_udp(src, dst, port_src, port_dst, charge):
    longueur = 8 + len(charge)
    donnees = src + dst + struct.pack('>IxxxB', longueur, 17) + struct.pack('>HHHH', port_src, port_dst, longueur, 0)
    donnees += charge + (b'\0' if len(charge) % 2 else b'')
    s = sum(struct.unpack('>%dH' % (len(donnees) // 2), donnees))
    while s >> 16:
        s = (s & 0xFFFF) + (s >> 16)
    return (~s & 0xFFFF) or 0xFFFF


def iphc(src, dst, sam, m, dam, src_en_ligne, dst_en_ligne, tf=3, nh=True, hlim=3):
    """IPHC sans contexte ; les champs en ligne, dans l'ordre : TF, en-tete suivant, limite, source, destination."""
    a = 0x60 | tf << 3 | (0x04 if nh else 0) | hlim
    b = sam << 4 | (0x08 if m else 0) | dam
    tfs = {0: b'\x00\x0A\xBC\xDE', 1: b'\x0A\xBC\xDE', 2: b'\x00', 3: b''}
    h = bytes([a, b]) + tfs[tf]
    if not nh:
        h += bytes([17])
    if hlim == 0:
        h += bytes([255])
    return h + src_en_ligne + dst_en_ligne


def udp(src, dst, port_src, port_dst, charge, nhc=True, ports=0, somme=True):
    if not nhc:
        return struct.pack('>HHHH', port_src, port_dst, 8 + len(charge), somme_udp(src, dst, port_src, port_dst, charge))
    u = 0xF0 | (0 if somme else 0x04) | ports
    if ports == 0:
        p = struct.pack('>HH', port_src, port_dst)
    elif ports == 1:
        p = struct.pack('>HB', port_src, port_dst & 0xFF)
    elif ports == 2:
        p = struct.pack('>BH', port_src & 0xFF, port_dst)
    else:
        p = bytes([(port_src & 0x0F) << 4 | (port_dst & 0x0F)])
    return bytes([u]) + p + (struct.pack('>H', somme_udp(src, dst, port_src, port_dst, charge)) if somme else b'')


def mle_chiffre(src, dst, compteur, sequence, clair):
    """Suite 0, en-tete de securite (controle 0x15, compteur, source et index de cle), puis AES-CCM et le MIC."""
    entete = bytes([0x15]) + struct.pack('<I', compteur) + struct.pack('>I', sequence) + bytes([(sequence & 0x7F) + 1])
    ext = iid_ext(src[8:])  # l'ExtMac de l'identifiant d'interface, bit U/L inverse
    nonce = ext + struct.pack('>I', compteur) + bytes([5])
    chiffre = AESCCM(cle_mle(sequence), tag_length=4).encrypt(nonce, clair, src + dst + entete)
    return bytes([0]) + entete + chiffre


def tlv(t, v):
    return bytes([t, len(v)]) + v


def route64(sequence, routes):
    """routes : {identifiant : (sortante, entrante, cout)}."""
    masque = 0
    for r in routes:
        masque |= 1 << (63 - r)
    octets = bytes([(s << 6) | (e << 4) | c for _, (s, e, c) in sorted(routes.items())])
    return bytes([sequence]) + struct.pack('>Q', masque) + octets


def chef(partition=PARTITION, chef_id=20):
    return struct.pack('>IBBBB', partition, 64, 0x11, 0x22, chef_id)


R64_A = route64(0x7A, {1: (3, 3, 1), 20: (0, 0, 0), 43: (2, 1, 2)})
R64_B = route64(0x7A, {1: (0, 0, 0), 20: (3, 3, 1), 43: (1, 1, 3)})
R64_C = route64(0x7B, {1: (1, 1, 3), 20: (1, 2, 2), 43: (0, 0, 0)})
R64_MAX = route64(0x10, {i: (i % 4, (i + 1) % 4, i % 16) for i in range(63)})


def annonce(source, r64=None, partition=PARTITION, commande=4):
    """Commande, Source Address, Leader Data (sans elle si partition est None), Route64."""
    clair = bytes([commande]) + tlv(0, struct.pack('>H', source))
    if partition is not None:
        clair += tlv(11, chef(partition))
    if r64 is not None:
        clair += tlv(9, r64)
    return clair


class Trame:
    def __init__(self, nom, psdu, issue, version=1, mode_dst=0, mode_src=0, charge=0, refus=AUCUN, src=b'',
                 dst=b'', port_src=0, port_dst=0, mac_lue=True, message=None, ext=b''):
        self.nom, self.psdu, self.issue = nom, psdu, issue
        self.version, self.mode_dst, self.mode_src, self.charge = version, mode_dst, mode_src, charge
        self.refus, self.src, self.dst, self.port_src, self.port_dst = refus, src, dst, port_src, port_dst
        self.mac_lue, self.message, self.ext = mac_lue, message, ext


def trame(nom, h_mac, h_ip, src, dst, port_src, port_dst, charge_udp, issue, version, mode_dst, mode_src,
          udp_args=None, message=None, refus=AUCUN):
    corps = h_mac + h_ip + udp(src, dst, port_src, port_dst, charge_udp, **(udp_args or {})) + charge_udp
    psdu = corps + fcs(corps)
    assert len(psdu) <= 127, nom
    return Trame(nom, psdu, issue, version=version, mode_dst=mode_dst, mode_src=mode_src, charge=len(h_mac),
                 refus=refus, src=src, dst=dst, port_src=port_src, port_dst=port_dst, message=message,
                 ext=iid_ext(src[8:]) if message is not None else b'')


def trames():
    t = []
    ff02_1, ff02_2 = multicast('ff02::1'), multicast('ff02::2')
    court = (2, b'\xff\xff')

    # 1. Annonce de 2006 : diffusion, source longue, PAN compresse ; IPHC tout tire du MAC ; UDP compresse.
    src = lien_local(iid_ext(EXT_A))
    h = mac(1, court, (3, EXT_A), True)
    ip = iphc(src, ff02_1, 3, True, 3, b'', b'\x01')
    c = annonce(0x5000, R64_A)
    t.append(trame('annonce 2006', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_1, 0x107, SEQUENCE, c), DECHIFFREE, 1, 2, 3,
                   message=(4, 0x5000, PARTITION, R64_A)))
    base = t[-1]

    # 2. 2015 : sequence supprimee, deux adresses longues et PAN compresse (aucun PAN), IE d'en-tete puis HT2 ;
    #    destination lien-local tiree du MAC ; UDP sans somme.
    src = lien_local(iid_ext(EXT_C))
    dst = lien_local(iid_ext(EXT_SONDE))
    ies = ie_entete(0x1A, b'\x10\x00\x20\x00') + ie_entete(0x7F, b'')
    h = mac(2, (3, EXT_SONDE), (3, EXT_C), True, supprimer_sequence=True, ies=ies, ie_present=True)
    ip = iphc(src, dst, 3, False, 3, b'', b'')
    c = annonce(0xAC00, R64_C, commande=1)
    t.append(trame('accept 2015, sans sequence ni PAN', h, ip, src, dst, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, dst, 0x2201, SEQUENCE, c), DECHIFFREE, 2, 3, 3, udp_args={'somme': False},
                   message=(1, 0xAC00, PARTITION, R64_C)))

    # 3. 2015 : destination courte, source longue, PAN compresse (PAN de la destination seulement) ; IE d'en-tete,
    #    HT1, puis des IE de charge jusqu'a leur fin.
    src = lien_local(iid_ext(EXT_B))
    ies = ie_entete(0x1A, b'\x01\x02\x03\x04') + ie_entete(0x7E, b'') + ie_charge(0x1, b'\xAA\xBB') + ie_charge(0xF, b'')
    h = mac(2, court, (3, EXT_B), True, ies=ies, ie_present=True)
    ip = iphc(src, ff02_1, 3, True, 3, b'', b'\x01')
    c = annonce(0x0400, R64_B)
    t.append(trame('annonce 2015, IE de charge', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_1, 0x3301, SEQUENCE, c), DECHIFFREE, 2, 2, 3,
                   message=(4, 0x0400, PARTITION, R64_B)))

    # 4. 2006 sans compression de PAN (deux PAN) ; IPHC tout en ligne : TF de 4 octets, en-tete suivant, limite,
    #    adresses de 128 bits ; UDP non compresse.
    src = lien_local(iid_ext(EXT_B))
    dst = lien_local(iid_ext(EXT_SONDE))
    h = mac(1, (3, EXT_SONDE), (3, EXT_B), False)
    ip = iphc(src, dst, 0, False, 0, src, dst, tf=0, nh=False, hlim=0)
    c = annonce(0x0400, R64_B)
    t.append(trame('2006, tout en ligne', h, ip, src, dst, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, dst, 0x4401, SEQUENCE, c), DECHIFFREE, 1, 3, 3, udp_args={'nhc': False},
                   message=(4, 0x0400, PARTITION, R64_B)))

    # 5. Source en 16 bits en ligne (fe80::ff:fe00:0400), multicast sur 32 bits (ff02::2) ; TF de 3 octets.
    src = lien_local(iid_court(0x0400))
    h = mac(1, court, (2, b'\x04\x00'), True)
    ip = iphc(src, ff02_2, 2, True, 2, b'\x04\x00', b'\x02\x00\x00\x02', tf=1)
    c = annonce(0x0400, R64_B)
    t.append(trame('source 16 bits, multicast 32 bits', h, ip, src, ff02_2, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_2, 0x5501, SEQUENCE, c), DECHIFFREE, 1, 2, 2,
                   message=(4, 0x0400, PARTITION, R64_B)))

    # 6. Source tiree de l'adresse MAC courte, multicast sur 48 bits (ff02::1) ; TF d'un octet.
    src = lien_local(iid_court(0x5000))
    h = mac(1, court, (2, b'\x50\x00'), True)
    ip = iphc(src, ff02_1, 3, True, 1, b'', b'\x02\x00\x00\x00\x00\x01', tf=2)
    c = annonce(0x5000, R64_A)
    t.append(trame('source MAC courte, multicast 48 bits', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_1, 0x6601, SEQUENCE, c), DECHIFFREE, 1, 2, 2,
                   message=(4, 0x5000, PARTITION, R64_A)))

    # 7. Source en 64 bits en ligne, multicast de 128 bits en ligne.
    src = lien_local(iid_ext(EXT_A))
    h = mac(1, court, (3, EXT_A), True)
    ip = iphc(src, ff02_1, 1, True, 0, iid_ext(EXT_A), ff02_1)
    c = annonce(0x5000, R64_A)
    t.append(trame('source 64 bits, multicast en ligne', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_1, 0x7701, SEQUENCE, c), DECHIFFREE, 1, 2, 3,
                   message=(4, 0x5000, PARTITION, R64_A)))

    # 7 bis. Route64 pleine (63 routeurs, 72 octets), sans Leader Data : tout le reste au plus court.
    ip = iphc(src, ff02_1, 3, True, 3, b'', b'\x01')
    c = annonce(0x5000, R64_MAX, partition=None)
    t.append(trame('Route64 pleine, sans Leader Data', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_1, 0x7702, SEQUENCE, c), DECHIFFREE, 1, 2, 3, udp_args={'somme': False},
                   message=(4, 0x5000, None, R64_MAX)))

    # 8. La sequence suivante (rotation de cle) : dechiffree aussi.
    src = lien_local(iid_ext(EXT_A))
    h = mac(1, court, (3, EXT_A), True)
    ip = iphc(src, ff02_1, 3, True, 3, b'', b'\x01')
    c = annonce(0x5000, R64_A)
    t.append(trame('sequence suivante', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_1, 0x8801, SEQUENCE + 1, c), DECHIFFREE, 1, 2, 3,
                   message=(4, 0x5000, PARTITION, R64_A)))

    # 9. Un enfant (5004) : dechiffre, sans place dans la table des routeurs ; sans Route64.
    src = lien_local(iid_ext(EXT_E))
    h = mac(1, court, (3, EXT_E), True)
    ip = iphc(src, ff02_1, 3, True, 3, b'', b'\x01')
    c = annonce(0x5004, None, commande=13)
    t.append(trame('enfant', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_1, 0x9901, SEQUENCE, c), DECHIFFREE, 1, 2, 3,
                   message=(13, 0x5004, PARTITION, b'')))

    # 10. Une autre partition (Leader Data) : dechiffree, la partition lue.
    src = lien_local(iid_ext(EXT_C))
    h = mac(1, court, (3, EXT_C), True)
    ip = iphc(src, ff02_1, 3, True, 3, b'', b'\x01')
    c = annonce(0xAC00, R64_C, partition=0x0BADCAFE)
    t.append(trame('autre partition', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_1, 0xAA01, SEQUENCE, c), DECHIFFREE, 1, 2, 3,
                   message=(4, 0xAC00, 0x0BADCAFE, R64_C)))

    # 11. MIC faux : la trame 1, dernier octet du MIC change (le FCS refait).
    corps = bytearray(base.psdu[:-2])
    corps[-1] ^= 0x01
    t.append(Trame('MIC faux', bytes(corps) + fcs(corps), ECHEC, version=1, mode_dst=2, mode_src=3, charge=base.charge,
                   src=base.src, dst=base.dst, port_src=PORT_MLE, port_dst=PORT_MLE))

    # 12. Sequence de cle inconnue (ni la courante ni la suivante).
    src = lien_local(iid_ext(EXT_A))
    h = mac(1, court, (3, EXT_A), True)
    ip = iphc(src, ff02_1, 3, True, 3, b'', b'\x01')
    t.append(trame('sequence inconnue', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   mle_chiffre(src, ff02_1, 0xBB01, SEQUENCE + 4, annonce(0x5000, R64_A)), ECHEC, 1, 2, 3))

    # 13. MLE sans securite (suite 255, Discovery Request) : ignoree.
    t.append(trame('MLE sans securite', h, ip, src, ff02_1, PORT_MLE, PORT_MLE,
                   bytes([255, 16]) + tlv(26, b'\x80\x00'), IGNOREE, 1, 2, 3))

    # 14. Un autre port (TMF, 61631), ports compresses sur 4 bits : ignoree.
    t.append(trame('TMF, ports sur 4 bits', h, ip, src, ff02_1, PORT_TMF, PORT_TMF, b'\x50\x02\xAB\xCD',
                   IGNOREE, 1, 2, 3, udp_args={'ports': 3}))

    # 15. Ports compresses : destination sur 8 bits (0xF0BF), puis source sur 8 bits.
    t.append(trame('port de destination sur 8 bits', h, ip, src, ff02_1, PORT_MLE, PORT_TMF, b'\x01\x02',
                   IGNOREE, 1, 2, 3, udp_args={'ports': 1}))
    t.append(trame('port de source sur 8 bits', h, ip, src, ff02_1, PORT_TMF, PORT_MLE, b'\x01\x02',
                   ECHEC, 1, 2, 3, udp_args={'ports': 2}))

    # 16. Securite MAC : la trame n'est pas lue.
    corps = mac(1, court, (3, EXT_A), True, securite=True) + b'\x00' * 20
    t.append(Trame('securite MAC', corps + fcs(corps), IGNOREE, mac_lue=False))

    # 17. Un fragment 6LoWPAN (dispatch 11000) : pas d'IPHC.
    corps = mac(1, court, (3, EXT_A), True) + b'\xC0\x50\x12\x34' + b'\x00' * 8
    t.append(Trame('fragment', corps + fcs(corps), IGNOREE, version=1, mode_dst=2, mode_src=3,
                   charge=len(mac(1, court, (3, EXT_A), True)), refus=PAS_IPHC))

    # 18. IPHC avec contexte (SAC a 1) : pas une adresse lien-local.
    corps = mac(1, court, (3, EXT_A), True) + bytes([0x7B, 0x7B]) + b'\x00' * 8
    t.append(Trame('contexte', corps + fcs(corps), IGNOREE, version=1, mode_dst=2, mode_src=3,
                   charge=len(mac(1, court, (3, EXT_A), True)), refus=CONTEXTE))

    # 19. En-tete suivant autre qu'UDP (ICMPv6, 58) en ligne.
    corps = mac(1, court, (3, EXT_A), True) + bytes([0x78, 0x3B, 58]) + b'\x80\x00\x12\x34'
    t.append(Trame('ICMPv6', corps + fcs(corps), IGNOREE, version=1, mode_dst=2, mode_src=3,
                   charge=len(mac(1, court, (3, EXT_A), True)), refus=PAS_UDP))

    # 20. Une trame d'acquittement (type 2) : pas une trame de donnees.
    corps = bytes([0x02, 0x10, 0x42])
    t.append(Trame('acquittement', corps + fcs(corps), IGNOREE, mac_lue=False))
    return t


# --- ecriture du fichier C -------------------------------------------------------------------------------------

def octets_c(o, retrait='    '):
    lignes = []
    for i in range(0, len(o), 16):
        lignes.append(retrait + ', '.join('0x%02X' % x for x in o[i:i + 16]) + ',')
    return '\n'.join(lignes) if lignes else retrait


def generer():
    lignes = [
        '// Vecteurs de test de l\'ecoute MLE (sonde/src/mle.h), generes par sonde/test/vecteurs_mle.py : ne pas',
        '// modifier a la main. Cle reseau, ExtMac, partition et routeurs inventes.',
        '//   ~/.platformio/penv/bin/python sonde/test/vecteurs_mle.py',
        '#pragma once',
        '#include <stddef.h>',
        '#include <stdint.h>',
        '',
        'static const uint8_t kCleReseau[16] = {',
        octets_c(CLE_RESEAU),
        '};',
        'static const uint32_t kSequence = %d;' % SEQUENCE,
        '',
        '// Cle MLE de quelques sequences : HMAC-SHA256(cle reseau, sequence || "Thread"), 16 premiers octets.',
        'struct VecteurDerivation {',
        '  uint32_t sequence;',
        '  uint8_t cle[16];',
        '};',
        'static const VecteurDerivation kDerivations[] = {',
    ]
    for s in (0, SEQUENCE, SEQUENCE + 1, 0xFFFFFFFF):
        lignes.append('    {0x%08XU, {%s}},' % (s, ', '.join('0x%02X' % x for x in cle_mle(s))))
    lignes.append('};')
    lignes.append('')
    # Un vecteur AES-CCM seul, pour la crypto des tests : la charge MLE de la trame 1.
    cle = cle_mle(SEQUENCE)
    nonce = iid_ext(iid_ext(EXT_A)) + struct.pack('>I', 0x107) + bytes([5])
    aad = bytes(range(42))
    clair = annonce(0x5000, R64_A)
    chiffre = AESCCM(cle, tag_length=4).encrypt(nonce, clair, aad)
    lignes += [
        '// AES-128-CCM, MIC de 4 octets : un vecteur seul (la crypto des tests).',
        'static const uint8_t kCcmCle[16] = {', octets_c(cle), '};',
        'static const uint8_t kCcmNonce[13] = {', octets_c(nonce), '};',
        'static const uint8_t kCcmAad[42] = {', octets_c(aad), '};',
        'static const uint8_t kCcmClair[%d] = {' % len(clair), octets_c(clair), '};',
        'static const uint8_t kCcmChiffre[%d] = {' % len(chiffre[:-4]), octets_c(chiffre[:-4]), '};',
        'static const uint8_t kCcmMic[4] = {', octets_c(chiffre[-4:]), '};',
        '',
    ]
    liste = trames()
    for k, t in enumerate(liste):
        lignes += ['// %d. %s' % (k + 1, t.nom), 'static const uint8_t kTrame%d[%d] = {' % (k + 1, len(t.psdu)),
                   octets_c(t.psdu), '};']
        if t.message is not None and t.message[3]:
            lignes += ['static const uint8_t kRoute%d[%d] = {' % (k + 1, len(t.message[3])), octets_c(t.message[3]),
                       '};']
    lignes += [
        '',
        '// Issue attendue de decoder() : 0 ignoree, 1 dechiffree, 2 echec. Refus attendu de lireDatagramme() : 0 aucun,',
        '// 1 pas IPHC, 2 contexte, 3 pas UDP, 4 tronquee.',
        'struct VecteurTrame {',
        '  const char *nom;',
        '  const uint8_t *psdu;',
        '  size_t n;',
        '  int issue;',
        '  bool macLue;',
        '  uint8_t version, modeDst, modeSrc;',
        '  size_t charge;',
        '  int refus;',
        '  uint8_t src[16], dst[16];',
        '  uint16_t portSrc, portDst;',
        '  uint8_t ext[8];',
        '  uint8_t commande;',
        '  uint16_t rloc16;',
        '  bool aPartition;',
        '  uint32_t partition;',
        '  const uint8_t *route64;',
        '  size_t nRoute64;',
        '};',
        'static const VecteurTrame kTrames[] = {',
    ]

    def tableau(o, n):
        o = o or bytes(n)
        return '{%s}' % ', '.join('0x%02X' % x for x in o)

    for k, t in enumerate(liste):
        m = t.message
        route = ('kRoute%d, %d' % (k + 1, len(m[3]))) if m is not None and m[3] else 'nullptr, 0'
        lignes.append('    {"%s", kTrame%d, %d, %d, %s, %d, %d, %d, %d, %d,' % (
            t.nom, k + 1, len(t.psdu), t.issue, 'true' if t.mac_lue else 'false', t.version, t.mode_dst, t.mode_src,
            t.charge, t.refus))
        lignes.append('     %s,' % tableau(t.src, 16))
        lignes.append('     %s,' % tableau(t.dst, 16))
        partition = m[2] if m is not None else None
        lignes.append('     %d, %d, %s, %d, 0x%04X, %s, 0x%08XU, %s},' % (
            t.port_src, t.port_dst, tableau(t.ext, 8), m[0] if m else 0, m[1] if m else 0,
            'true' if partition is not None else 'false', partition or 0, route))
    lignes.append('};')
    return '\n'.join(lignes) + '\n'


def main():
    texte = generer()
    if '--verifier' in sys.argv[1:]:
        with open(SORTIE, encoding='utf-8') as f:
            if f.read() != texte:
                print('vecteurs_mle.h differe de ce que le script produit')
                return 1
        print('vecteurs_mle.h : conforme au script')
        return 0
    with open(SORTIE, 'w', encoding='utf-8') as f:
        f.write(texte)
    print('ecrit : %s (%d trames)' % (os.path.relpath(SORTIE), len(trames())))
    return 0


if __name__ == '__main__':
    sys.exit(main())
```

- [ ] **Step 2 : les vecteurs, écrits par le script.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && ~/.platformio/penv/bin/python sonde/test/vecteurs_mle.py && ~/.platformio/penv/bin/python sonde/test/vecteurs_mle.py --verifier && shasum -a 256 sonde/test/vecteurs_mle.h`

Expected : `ecrit : sonde/test/vecteurs_mle.h (22 trames)` ; `vecteurs_mle.h : conforme au script` ; `1abe72685f359d5a9a498b21ee35c43e28af27dfb91652e46cc029ec1244ec76  sonde/test/vecteurs_mle.h` : le fichier de la copie validée, octet pour octet (le script est déterministe).

- [ ] **Step 3 : les tests d'abord** (`--etapes 3`).

`sonde/test/test_mle.cpp` :

```cpp
// Tests hote de sonde/src/mle.{h,cpp} (ecoute des messages MLE, firmware 1.1.0) : derivation de la cle MLE,
// AES-CCM, en-tete 802.15.4 (2006 et 2015, IE, PAN), IPHC, UDP, en-tete de securite MLE, dechiffrement et refus,
// TLV, cles gardees, table des routeurs entendus ; et la robustesse devant des trames tronquees ou abimees (ASan,
// UBSan). Vecteurs : sonde/test/vecteurs_mle.h, produits par sonde/test/vecteurs_mle.py (cle et adresses inventees).
// Lancer : sh sonde/test/lancer.sh
//
// La crypto de la plateforme vient ici de CommonCrypto (macOS), qui n'a pas d'AES-CCM : il est bati ci-dessous sur
// son AES-ECB, d'apres la RFC 3610 (L = 2, M = 4). Sur la carte, mbedTLS (src/mle_crypto.cpp).
#include <CommonCrypto/CommonCryptor.h>
#include <CommonCrypto/CommonHMAC.h>
#include <stdio.h>
#include <string.h>

#include "mle.h"
#include "vecteurs_mle.h"

using namespace mle;

namespace mle {

bool hmacSha256(const uint8_t *cle, size_t nCle, const uint8_t *message, size_t n, uint8_t sortie[32]) {
  CCHmac(kCCHmacAlgSHA256, cle, nCle, message, n, sortie);
  return true;
}

static void aes(const uint8_t cle[kCle], const uint8_t entree[16], uint8_t sortie[16]) {
  uint8_t bloc[16];
  size_t ecrits = 0;
  CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionECBMode, cle, kCle, nullptr, entree, 16, bloc, 16, &ecrits);
  memcpy(sortie, bloc, 16);
}

bool aesCcmDechiffrer(const uint8_t cle[kCle], const uint8_t nonce[kNonce], const uint8_t *aad, size_t nAad,
                      const uint8_t *chiffre, size_t n, const uint8_t mic[kMic], uint8_t *clair) {
  // Compteur : A_i = drapeaux (L - 1), nonce, i sur 2 octets ; S_0 masque le MIC, S_1... le texte.
  uint8_t a[16] = {0x01}, s[16], x[16], b[16];
  memcpy(a + 1, nonce, kNonce);
  for (size_t k = 0; k < n; k += 16) {
    const uint16_t i = (uint16_t)(1 + k / 16);
    a[14] = (uint8_t)(i >> 8);
    a[15] = (uint8_t)i;
    aes(cle, a, s);
    for (size_t j = 0; j < 16 && k + j < n; j++) clair[k + j] = chiffre[k + j] ^ s[j];
  }
  // CBC-MAC : B_0 (Adata, M, L), la longueur des donnees associees sur 2 octets puis elles, puis le clair.
  b[0] = (uint8_t)((nAad ? 0x40 : 0) | ((kMic - 2) / 2) << 3 | (2 - 1));
  memcpy(b + 1, nonce, kNonce);
  b[14] = (uint8_t)(n >> 8);
  b[15] = (uint8_t)n;
  aes(cle, b, x);
  uint8_t bloc[16];
  size_t remplis = 0;
  auto ajouter = [&](uint8_t o) {
    bloc[remplis++] = o;
    if (remplis == 16) {
      for (int j = 0; j < 16; j++) x[j] ^= bloc[j];
      aes(cle, x, x);
      remplis = 0;
    }
  };
  auto completer = [&]() {
    if (!remplis) return;
    while (remplis < 16) bloc[remplis++] = 0;
    for (int j = 0; j < 16; j++) x[j] ^= bloc[j];
    aes(cle, x, x);
    remplis = 0;
  };
  if (nAad) {
    ajouter((uint8_t)(nAad >> 8));
    ajouter((uint8_t)nAad);
    for (size_t k = 0; k < nAad; k++) ajouter(aad[k]);
    completer();
  }
  for (size_t k = 0; k < n; k++) ajouter(clair[k]);
  completer();
  a[14] = a[15] = 0;
  aes(cle, a, s);
  uint8_t difference = 0;
  for (size_t j = 0; j < kMic; j++) difference |= (uint8_t)((x[j] ^ s[j]) ^ mic[j]);
  if (difference) {
    effacer(clair, n);
    return false;
  }
  return true;
}

}  // namespace mle

static int gChecks = 0, gFails = 0;
#define CHECK(cond, ...)                              \
  do {                                                \
    gChecks++;                                        \
    if (!(cond)) {                                    \
      if (++gFails <= 40) {                           \
        printf("ECHEC %s:%d : ", __FILE__, __LINE__); \
        printf(__VA_ARGS__);                          \
        printf("\n");                                 \
      }                                               \
    }                                                 \
  } while (0)

// Les cles de la pile des tests : la sequence courante (kSequence) et la suivante.
static bool fournir(void *contexte, uint32_t sequence, uint8_t cle[kCle]) {
  return static_cast<const ClesMle *>(contexte)->trouver(sequence, cle);
}

static bool nul(const uint8_t *p, size_t n) {
  for (size_t i = 0; i < n; i++)
    if (p[i]) return false;
  return true;
}

static void testDerivation() {
  for (const VecteurDerivation &v : kDerivations) {
    uint8_t cle[kCle] = {};
    CHECK(deriverCleMle(kCleReseau, v.sequence, cle) && !memcmp(cle, v.cle, kCle), "cle MLE de la sequence %u",
          v.sequence);
  }
  // Deux cles gardees : la courante et la suivante ; rien d'autre.
  ClesMle cles;
  uint8_t cle[kCle];
  CHECK(!cles.preparees() && !cles.trouver(kSequence, cle), "rien avant preparer");
  CHECK(cles.preparer(kSequence, kCleReseau) && cles.preparees() && cles.courante() == kSequence, "preparees");
  CHECK(cles.trouver(kSequence, cle) && !memcmp(cle, kDerivations[1].cle, kCle), "la courante");
  CHECK(cles.trouver(kSequence + 1, cle) && !memcmp(cle, kDerivations[2].cle, kCle), "la suivante");
  CHECK(!cles.trouver(kSequence - 1, cle) && !cles.trouver(kSequence + 2, cle), "ni la precedente, ni d'autres");
  // La suivante de 0xFFFFFFFF est 0.
  CHECK(cles.preparer(0xFFFFFFFFu, kCleReseau), "preparees au bout");
  CHECK(cles.trouver(0xFFFFFFFFu, cle) && !memcmp(cle, kDerivations[3].cle, kCle), "0xFFFFFFFF");
  CHECK(cles.trouver(0, cle) && !memcmp(cle, kDerivations[0].cle, kCle), "puis 0");
  CHECK(!cles.trouver(kSequence, cle), "les anciennes ne restent pas");
  cles.effacer();
  CHECK(!cles.preparees() && !cles.trouver(0, cle), "effacees");
}

static void testCcm() {
  uint8_t clair[sizeof(kCcmClair)];
  CHECK(aesCcmDechiffrer(kCcmCle, kCcmNonce, kCcmAad, sizeof(kCcmAad), kCcmChiffre, sizeof(kCcmChiffre), kCcmMic,
                         clair) &&
            !memcmp(clair, kCcmClair, sizeof(clair)),
        "AES-CCM : le vecteur");
  uint8_t mic[kMic];
  memcpy(mic, kCcmMic, kMic);
  mic[3] ^= 0x80;
  memset(clair, 0xEE, sizeof(clair));
  CHECK(!aesCcmDechiffrer(kCcmCle, kCcmNonce, kCcmAad, sizeof(kCcmAad), kCcmChiffre, sizeof(kCcmChiffre), mic, clair) &&
            nul(clair, sizeof(clair)),
        "AES-CCM : MIC faux refuse, clair efface");
  uint8_t aad[sizeof(kCcmAad)];
  memcpy(aad, kCcmAad, sizeof(aad));
  aad[0] ^= 1;
  CHECK(!aesCcmDechiffrer(kCcmCle, kCcmNonce, aad, sizeof(aad), kCcmChiffre, sizeof(kCcmChiffre), kCcmMic, clair),
        "AES-CCM : donnees associees changees refusees");
}

static void testTrames() {
  ClesMle cles;
  cles.preparer(kSequence, kCleReseau);
  for (const VecteurTrame &v : kTrames) {
    EnTeteMac m;
    const bool lue = lireMac(v.psdu, v.n, &m);
    CHECK(lue == v.macLue, "%s : en-tete MAC %s", v.nom, v.macLue ? "lu" : "refuse");
    if (lue) {
      CHECK(m.version == v.version && m.modeDst == v.modeDst && m.modeSrc == v.modeSrc, "%s : version et modes",
            v.nom);
      CHECK(m.charge == v.charge && m.fin == v.n - 2, "%s : charge a %zu (attendue %zu)", v.nom, m.charge, v.charge);
      Datagramme d;
      const Refus r = lireDatagramme(v.psdu, m, &d);
      CHECK((int)r == v.refus, "%s : refus %d (attendu %d)", v.nom, (int)r, v.refus);
      if (r == Refus::Aucun) {
        CHECK(!memcmp(d.src, v.src, 16) && !memcmp(d.dst, v.dst, 16), "%s : adresses", v.nom);
        CHECK(d.portSrc == v.portSrc && d.portDst == v.portDst, "%s : ports %u et %u", v.nom, d.portSrc, d.portDst);
      }
    }
    Message msg;
    const Issue i = decoder(v.psdu, v.n, fournir, &cles, &msg);
    CHECK((int)i == v.issue, "%s : issue %d (attendue %d)", v.nom, (int)i, v.issue);
    if (i != Issue::Dechiffree) continue;
    CHECK(!memcmp(msg.ext, v.ext, 8), "%s : ExtMac de l'emetteur", v.nom);
    CHECK(msg.commande == v.commande && msg.aSource && msg.rloc16 == v.rloc16, "%s : commande et RLOC16", v.nom);
    CHECK(msg.aPartition == v.aPartition && msg.partition == v.partition, "%s : partition", v.nom);
    CHECK(msg.nRoute64 == v.nRoute64 && (!v.nRoute64 || !memcmp(msg.route64, v.route64, v.nRoute64)),
          "%s : Route64 (%u octets)", v.nom, msg.nRoute64);
  }
}

// Toute trame tronquee d'une trame dechiffrable : jamais dechiffree, jamais hors des bornes (ASan).
static void testTronquees() {
  ClesMle cles;
  cles.preparer(kSequence, kCleReseau);
  int dechiffrees = 0;
  for (const VecteurTrame &v : kTrames) {
    if (v.issue != 1) continue;
    for (size_t n = 0; n < v.n; n++) {
      uint8_t copie[kPsduMax];
      memcpy(copie, v.psdu, n);
      Message msg;
      if (decoder(copie, n, fournir, &cles, &msg) == Issue::Dechiffree) dechiffrees++;
    }
  }
  CHECK(dechiffrees == 0, "trames tronquees : %d dechiffrees", dechiffrees);
}

// Chaque octet d'une trame change a son tour : le message n'est jamais dechiffre avec une autre ExtMac, une autre
// commande ni d'autres TLV que celles de la trame (le MIC couvre tout ce qui compte), et rien ne deborde.
static void testAbimees() {
  ClesMle cles;
  cles.preparer(kSequence, kCleReseau);
  int faux = 0;
  for (const VecteurTrame &v : kTrames) {
    if (v.issue != 1) continue;
    for (size_t k = 0; k + 2 < v.n; k++) {
      static const uint8_t kMasques[] = {0x01, 0x80, 0xFF};
      for (uint8_t masque : kMasques) {
        uint8_t copie[kPsduMax];
        memcpy(copie, v.psdu, v.n);
        copie[k] ^= masque;
        Message msg;
        if (decoder(copie, v.n, fournir, &cles, &msg) != Issue::Dechiffree) continue;
        const bool pareil = !memcmp(msg.ext, v.ext, 8) && msg.commande == v.commande && msg.rloc16 == v.rloc16 &&
                            msg.nRoute64 == v.nRoute64 && msg.partition == v.partition;
        if (!pareil) faux++;
      }
    }
  }
  CHECK(faux == 0, "trames abimees : %d dechiffrees autrement", faux);
}

// Des trames au hasard (generateur fixe) : rien ne deborde, rien n'est dechiffre.
static void testHasard() {
  ClesMle cles;
  cles.preparer(kSequence, kCleReseau);
  uint32_t x = 0x9E3779B9u;
  auto suivant = [&x]() {
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return x;
  };
  int dechiffrees = 0;
  for (int k = 0; k < 200000; k++) {
    uint8_t t[kPsduMax];
    const size_t n = suivant() % (kPsduMax + 1);
    for (size_t i = 0; i < n; i++) t[i] = (uint8_t)suivant();
    // Une trame sur deux commence comme une trame de donnees (2003, PAN compresse, destination courte, source
    // longue), IPHC tire du MAC, UDP vers le port MLE, en-tete de securite de la sequence courante : le hasard va
    // jusqu'au dechiffrement.
    if (k % 2 && n > 40) {
      const uint8_t debut[] = {0x41, 0xC8};
      memcpy(t, debut, sizeof(debut));
      t[15] = 0x7F;
      t[16] = 0x3B;
      t[17] = 0xF0;
      t[20] = (uint8_t)(kPortMle >> 8);
      t[21] = (uint8_t)kPortMle;
      t[24] = kSuiteChiffree;
      t[25] = kControle;
      t[30] = t[31] = t[32] = 0;
      t[33] = (uint8_t)kSequence;
    }
    Message msg;
    if (decoder(t, n, fournir, &cles, &msg) == Issue::Dechiffree) dechiffrees++;
    EnTeteMac m;
    if (lireMac(t, n, &m)) {
      CHECK(m.charge <= m.fin && m.fin + 2 == n, "hasard : bornes de la charge");
      Datagramme d;
      if (lireDatagramme(t, m, &d) == Refus::Aucun) CHECK(d.charge <= m.fin, "hasard : bornes de l'UDP");
    }
  }
  CHECK(dechiffrees == 0, "hasard : %d dechiffrees", dechiffrees);
}

static void testSecurite() {
  // Suite 0, controle 0x15, compteur 0x04030201 (petit-boutiste), sequence 0x00000005 (gros-boutiste), index 6,
  // une commande chiffree, le MIC.
  const uint8_t c[] = {0x00, 0x15, 0x01, 0x02, 0x03, 0x04, 0x00, 0x00, 0x00, 0x05, 0x06, 0xAA, 0x11, 0x22, 0x33, 0x44};
  SecuriteMle s;
  CHECK(lireSecuriteMle(c, sizeof(c), &s), "en-tete de securite lu");
  CHECK(s.compteur == 0x04030201u && s.sequence == 5 && s.index == 6, "compteur, sequence, index");
  CHECK(s.entete == c + 1 && s.chiffre == c + 11 && s.n == 1 && s.mic == c + 12, "places");
  CHECK(!lireSecuriteMle(c, sizeof(c) - 1, &s), "sans octet chiffre : refuse");
  uint8_t autre[sizeof(c)];
  memcpy(autre, c, sizeof(c));
  autre[1] = 0x0D;  // niveau 5, cle en mode 1
  CHECK(!lireSecuriteMle(autre, sizeof(autre), &s), "autre controle : refuse");
  memcpy(autre, c, sizeof(c));
  autre[0] = 0xFF;
  CHECK(!lireSecuriteMle(autre, sizeof(autre), &s), "sans securite : refuse");
  // Nonce et donnees associees.
  const uint8_t ext[8] = {0xE0, 0, 0, 0, 0, 0, 0x0A, 0x01};
  uint8_t nonce[kNonce];
  nonceMle(ext, 0x01020304u, nonce);
  const uint8_t attendu[kNonce] = {0xE0, 0, 0, 0, 0, 0, 0x0A, 0x01, 0x01, 0x02, 0x03, 0x04, 0x05};
  CHECK(!memcmp(nonce, attendu, kNonce), "nonce : ExtMac, compteur gros-boutiste, niveau 5");
  uint8_t iid[8] = {0xE2, 0, 0, 0, 0, 0, 0x0A, 0x01}, e[8];
  extDepuisIid(iid, e);
  CHECK(!memcmp(e, ext, 8), "ExtMac d'un identifiant d'interface : bit U/L inverse");
  uint8_t src[16], dst[16], aad[kDonneesAssociees];
  for (int k = 0; k < 16; k++) src[k] = (uint8_t)k, dst[k] = (uint8_t)(0x80 + k);
  donneesAssociees(src, dst, c + 1, aad);
  CHECK(!memcmp(aad, src, 16) && !memcmp(aad + 16, dst, 16) && !memcmp(aad + 32, c + 1, 10), "donnees associees");
  CHECK(lienLocal(src) == false && lienLocal(kTrames[0].src), "lien-local : fe80::/64");
}

static void testTlv() {
  // Commande, Source Address, une TLV inconnue, Leader Data, Route64.
  const uint8_t c[] = {0x04, 0x00, 0x02, 0x50, 0x00, 0x22, 0x01, 0xEE, 0x0B, 0x08, 0x12, 0x34, 0xAB, 0xCD,
                       0x40, 0x11, 0x22, 0x14, 0x09, 0x0A, 0x7A, 0x80, 0, 0, 0, 0, 0, 0, 0, 0xF1};
  Message m;
  lireTlv(c, sizeof(c), &m);
  CHECK(m.commande == 4 && m.aSource && m.rloc16 == 0x5000, "commande et Source Address");
  CHECK(m.aPartition && m.partition == 0x1234ABCDu, "Leader Data");
  CHECK(m.nRoute64 == 10 && m.route64[0] == 0x7A && m.route64[9] == 0xF1, "Route64");
  // La Route64 deborde : la lecture s'arrete, le reste lu avant est garde.
  Message t;
  lireTlv(c, sizeof(c) - 1, &t);
  CHECK(t.aSource && t.aPartition && t.nRoute64 == 0, "TLV tronquee : ignoree");
  // Route64 trop courte (8 octets) ou trop longue (73) : ignoree.
  uint8_t court[] = {0x04, 0x09, 0x08, 1, 2, 3, 4, 5, 6, 7, 8};
  Message u;
  lireTlv(court, sizeof(court), &u);
  CHECK(u.nRoute64 == 0, "Route64 de 8 octets ignoree");
  uint8_t long_[2 + 2 + 73] = {0x04, 0x09, 73};
  Message w;
  lireTlv(long_, 3 + 73, &w);
  CHECK(w.nRoute64 == 0, "Route64 de 73 octets ignoree");
  // Source Address de 3 octets : ignoree ; message vide : rien.
  const uint8_t mauvais[] = {0x04, 0x00, 0x03, 0x50, 0x00, 0x01};
  Message x;
  lireTlv(mauvais, sizeof(mauvais), &x);
  CHECK(!x.aSource, "Source Address de 3 octets ignoree");
  Message y;
  lireTlv(c, 0, &y);
  CHECK(y.commande == 0 && !y.aSource, "message vide");
}

static Message routeur(uint8_t n, uint16_t rloc16, bool route = true) {
  Message m;
  m.ext[0] = 0xE0;
  m.ext[7] = n;
  m.aSource = true;
  m.rloc16 = rloc16;
  m.aPartition = true;
  m.partition = 0x1234ABCD;
  if (route) {
    m.nRoute64 = 10;
    m.route64[0] = n;
  }
  return m;
}

static void testTable() {
  TableEntendus t;
  CHECK(t.nombre() == 0, "vide");
  CHECK(!t.noter(routeur(1, 0x5004), -60, 1000), "un enfant n'entre pas");
  Message sansSource = routeur(1, 0x5000);
  sansSource.aSource = false;
  CHECK(!t.noter(sansSource, -60, 1000), "sans Source Address, rien");
  CHECK(!t.noter(routeur(1, 0x5200), -60, 1000), "bit 9 du RLOC16 : pas un routeur");
  CHECK(t.noter(routeur(1, 0x5000), -60, 1000) && t.nombre() == 1, "un routeur");
  const Entendu &e = t.place(0);
  CHECK(e.utilise && e.ext[7] == 1 && e.rloc16 == 0x5000 && e.aPartition && e.partition == 0x1234ABCDu, "son entree");
  CHECK(e.nRoute64 == 10 && e.route64[0] == 1 && e.nb == 1 && e.dernier == 1000, "sa Route64, un message");
  CHECK(e.rssi == -60 && e.rssiMin == -60 && e.rssiMax == -60, "signal");
  // Un message sans Route64 (demande de lien) garde la Route64 d'avant ; le signal suit.
  CHECK(t.noter(routeur(1, 0x5000, false), -75, 2000), "sans Route64");
  CHECK(e.nRoute64 == 10 && e.nb == 2 && e.dernier == 2000, "la Route64 d'avant reste");
  CHECK(t.noter(routeur(1, 0x5000), -50, 3000), "encore");
  CHECK(e.rssi == -50 && e.rssiMin == -75 && e.rssiMax == -50 && e.nb == 3, "minimum et maximum");
  // Nouvel identifiant (redemarrage) : la meme entree, le nouveau RLOC16.
  CHECK(t.noter(routeur(1, 0x0400), -50, 4000) && t.nombre() == 1 && e.rloc16 == 0x0400, "nouveau RLOC16");
  // Muet depuis 10 min : retire ; un autre, plus recent, reste.
  CHECK(t.noter(routeur(2, 0xAC00), -80, 300000), "un autre");
  t.oublier(4000 + TableEntendus::kOubliMs - 1);
  CHECK(t.nombre() == 2, "pas encore 10 min");
  t.oublier(4000 + TableEntendus::kOubliMs);
  CHECK(t.nombre() == 1 && !t.place(0).utilise && t.place(1).ext[7] == 2, "10 min : retire");
  // Pleine : le plus ancien laisse sa place.
  TableEntendus p;
  for (uint8_t k = 0; k < TableEntendus::kPlaces; k++) p.noter(routeur(k, (uint16_t)(k << 10)), -70, 10000u + k);
  CHECK(p.nombre() == TableEntendus::kPlaces, "pleine");
  p.noter(routeur(0, 0), -70, 20000);  // le routeur 0 revient : il n'est plus le plus ancien
  CHECK(p.noter(routeur(200, 0xFC00), -70, 30000), "un de plus");
  bool unPresent = false, zeroPresent = false, deuxCentsPresent = false;
  for (size_t k = 0; k < TableEntendus::kPlaces; k++) {
    unPresent |= p.place(k).ext[7] == 1;
    zeroPresent |= p.place(k).ext[7] == 0;
    deuxCentsPresent |= p.place(k).ext[7] == 200;
  }
  CHECK(!unPresent && zeroPresent && deuxCentsPresent, "le plus ancien (1) remplace");
  // Retour a zero de millis() : les ages restent justes.
  TableEntendus z;
  z.noter(routeur(9, 0x2400), -70, 0xFFFFFF00u);
  z.oublier(0x00000100u);
  CHECK(z.nombre() == 1, "zero : 512 ms plus tard, toujours la");
  z.oublier(0xFFFFFF00u + TableEntendus::kOubliMs);
  CHECK(z.nombre() == 0, "zero : 10 min plus tard, retire");
}

int main() {
  testDerivation();
  testCcm();
  testSecurite();
  testTlv();
  testTrames();
  testTronquees();
  testAbimees();
  testHasard();
  testTable();
  printf("test_mle : %d verification(s), %d echec(s)\n", gChecks, gFails);
  return gFails ? 1 : 0;
}
```

`sonde/test/lancer.sh`, fichier entier :

```sh
#!/bin/sh
# Tests hote purs de la sonde, sans carte : enveloppe H1 (test_h1.cpp, repris
# du pont Halo de benq) et briques pures (test_distant.cpp : commandes a
# distance, soit rid, liste blanche, reponses gardees et cadence ; depuis la
# 1.0.3, entiers des commandes, reprises CoAP d'un diag et LED de la carte,
# voyant.h) ; depuis la 1.1.0, l'ecoute des messages MLE (test_mle.cpp :
# trames 802.15.4, IPHC, UDP, dechiffrement, TLV, routeurs entendus, sur les
# vecteurs de vecteurs_mle.py).
#
#   sh sonde/test/lancer.sh
#
# clang++ de Xcode (CommonCrypto pour la crypto de H1 et de MLE), ASan et UBSan. Les
# binaires vont dans un dossier temporaire : rien ne reste dans le depot.
set -e
ICI=$(cd "$(dirname "$0")" && pwd)
SRC="$ICI/../src"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DRAPEAUX="-std=gnu++17 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-sanitize-recover=undefined -fno-omit-frame-pointer"
clang++ $DRAPEAUX -I"$SRC" "$ICI/test_h1.cpp" "$SRC/h1_proto.cpp" -o "$TMP/test_h1"
clang++ $DRAPEAUX -I"$SRC" "$ICI/test_distant.cpp" "$SRC/distant.cpp" -o "$TMP/test_distant"
clang++ $DRAPEAUX -I"$SRC" "$ICI/test_mle.cpp" "$SRC/mle.cpp" -o "$TMP/test_mle"
"$TMP/test_h1"
"$TMP/test_distant"
"$TMP/test_mle"
```

- [ ] **Step 4 : les voir échouer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && sh sonde/test/lancer.sh 2>&1 | grep -E "error|verification"`

Expected : `clang++: error: no such file or directory: '…/sonde/test/../src/mle.cpp'` : le module n'existe pas encore. Aucun test ne tourne : `lancer.sh` compile tout avant de lancer.

- [ ] **Step 5 : le module, et sa crypto sur la carte** (`--etapes 5`).

`sonde/src/mle.h` :

```cpp
#pragma once
// ===========================================================================
//  Ecoute des messages MLE : briques pures (firmware 1.1.0, spec de la sonde
//  tout-en-un, section 1)
//
//  Une trame 802.15.4 recue (PSDU, FCS compris), dans l'ordre :
//  - l'en-tete MAC, aux formats 2003/2006 et 2015 : numero de sequence
//    supprime (2015), PAN selon le tableau 7-2 (2015), IE d'en-tete jusqu'a
//    HT1 ou HT2 (2015 ; apres HT1, les IE de charge jusqu'a leur fin) ;
//    seules les trames de donnees sans securite MAC sont lues ;
//  - 6LoWPAN IPHC sans contexte (adresses en ligne, ou tirees des adresses
//    MAC), puis UDP, compresse (NHC) ou non ;
//  - vers le port MLE 19788, depuis une adresse lien-local : l'en-tete de
//    securite MLE (suite 0, controle 0x15 : niveau 5, cle en mode 2), le
//    compteur de trame petit-boutiste, la sequence de cle gros-boutiste dans
//    la source de cle ;
//  - le dechiffrement AES-CCM (MIC de 4 octets) par la cle MLE de cette
//    sequence : les 128 premiers bits de HMAC-SHA256(cle reseau, sequence ||
//    « Thread »). Nonce : ExtMac de l'emetteur (identifiant d'interface de son
//    adresse lien-local, bit U/L inverse), compteur gros-boutiste, niveau 5.
//    Donnees associees : adresses IPv6 source et destination, puis les 10
//    octets de l'en-tete de securite (controle, compteur, source et index de
//    cle) ;
//  - les TLV du message : Source Address (0), Route64 (9), Leader Data (11).
//
//  Aussi : la table des routeurs entendus (TableEntendus) et les deux cles MLE
//  gardees (ClesMle). La cle reseau n'est jamais gardee ici : ClesMle::preparer
//  la recoit le temps d'une derivation ; l'appelant l'efface.
//
//  Pur et sans Arduino : teste sur l'hote par sonde/test/test_mle.cpp, sur des
//  vecteurs produits par sonde/test/vecteurs_mle.py (cle et adresses
//  inventees) ; lancer : sh sonde/test/lancer.sh. La crypto vient de la
//  plateforme : mbedTLS sur la carte (mle_crypto.cpp), CommonCrypto dans les
//  tests (AES-CCM bati sur son AES-ECB).
// ===========================================================================
#include <stddef.h>
#include <stdint.h>

namespace mle {

constexpr uint16_t kPortMle = 19788;
// PSDU d'une trame 802.15.4, FCS compris.
constexpr size_t kPsduMax = 127;
// Valeur d'une TLV Route64 : sequence, masque de 8 octets, un octet par routeur (63 au plus).
constexpr size_t kRoute64Max = 72;
constexpr size_t kCle = 16;
constexpr size_t kNonce = 13;
constexpr size_t kMic = 4;
// En-tete de securite MLE sans la suite : controle, compteur (4), source de cle (4), index.
constexpr size_t kEnTeteSecurite = 10;
// Donnees associees : adresses source et destination, puis l'en-tete de securite.
constexpr size_t kDonneesAssociees = 16 + 16 + kEnTeteSecurite;
// Suite de securite d'un message MLE chiffre, et d'un message sans securite (Discovery).
constexpr uint8_t kSuiteChiffree = 0;
constexpr uint8_t kSuiteSansSecurite = 255;
// Niveau 5 (chiffrement, MIC de 32 bits), cle designee par sa source (mode 2).
constexpr uint8_t kControle = 0x15;
constexpr uint8_t kNiveau = 5;

// --- Crypto de la plateforme -------------------------------------------------

// HMAC-SHA256(cle, message). false : echec de la plateforme (sortie indefinie).
bool hmacSha256(const uint8_t *cle, size_t nCle, const uint8_t *message, size_t n, uint8_t sortie[32]);
// AES-128-CCM, nonce de 13 octets, MIC de 4 octets : dechiffre `n` octets et
// verifie le MIC. false : MIC faux ou echec ; `clair` est alors efface.
bool aesCcmDechiffrer(const uint8_t cle[kCle], const uint8_t nonce[kNonce], const uint8_t *aad, size_t nAad,
                      const uint8_t *chiffre, size_t n, const uint8_t mic[kMic], uint8_t *clair);

// --- Outils ------------------------------------------------------------------

// Mise a zero que l'optimiseur ne retire pas (cles et clairs sur la pile).
void effacer(void *p, size_t n);

// --- 802.15.4 ------------------------------------------------------------------

struct EnTeteMac {
  uint8_t version = 0;  // 0 : 2003, 1 : 2006, 2 : 2015
  uint8_t modeDst = 0;  // 0 : absente, 2 : courte, 3 : longue
  uint8_t modeSrc = 0;
  uint8_t dst[8] = {};  // dans l'ordre de la trame (petit-boutiste)
  uint8_t src[8] = {};
  size_t charge = 0;    // debut de la charge MAC, apres les IE
  size_t fin = 0;       // fin de la charge MAC : le FCS commence la
};

// En-tete d'une trame de donnees sans securite MAC. false : autre type de
// trame, securite MAC, version ou mode d'adresse inconnu, trame trop courte ou
// trop longue, IE mal formes.
bool lireMac(const uint8_t *psdu, size_t n, EnTeteMac *m);

// --- IPv6 (IPHC) et UDP ----------------------------------------------------------

struct Datagramme {
  uint8_t src[16] = {};
  uint8_t dst[16] = {};
  uint16_t portSrc = 0;
  uint16_t portDst = 0;
  size_t charge = 0;  // debut de la charge UDP dans la trame
};

enum class Refus : uint8_t {
  Aucun,
  PasIphc,     // fragment, en-tete maille, autre dispatch
  Contexte,    // IPHC avec contexte : pas une adresse lien-local
  PasUdp,      // autre en-tete suivant
  Tronquee,    // la trame finit avant l'en-tete
};

// IPHC sans contexte, puis UDP (NHC ou en ligne), a partir de la charge MAC.
Refus lireDatagramme(const uint8_t *psdu, const EnTeteMac &m, Datagramme *d);

// fe80::/64.
bool lienLocal(const uint8_t adresse[16]);

// --- Securite MLE ------------------------------------------------------------

struct SecuriteMle {
  uint32_t compteur = 0;   // compteur de trame
  uint32_t sequence = 0;   // sequence de cle (source de cle)
  uint8_t index = 0;       // index de cle
  const uint8_t *entete = nullptr;  // les kEnTeteSecurite octets, apres la suite
  const uint8_t *chiffre = nullptr;
  size_t n = 0;            // octets chiffres (commande et TLV)
  const uint8_t *mic = nullptr;
};

// Charge UDP d'un message MLE chiffre : suite 0, controle 0x15, puis au moins
// un octet chiffre et le MIC. false sinon.
bool lireSecuriteMle(const uint8_t *charge, size_t n, SecuriteMle *s);

// ExtMac (ordre naturel) d'un identifiant d'interface : le bit U/L inverse.
void extDepuisIid(const uint8_t iid[8], uint8_t ext[8]);
// Nonce : ExtMac, compteur gros-boutiste, niveau 5.
void nonceMle(const uint8_t ext[8], uint32_t compteur, uint8_t nonce[kNonce]);
// Donnees associees : source, destination, en-tete de securite.
void donneesAssociees(const uint8_t src[16], const uint8_t dst[16], const uint8_t entete[kEnTeteSecurite],
                      uint8_t aad[kDonneesAssociees]);
// Cle MLE d'une sequence : les 128 premiers bits de HMAC-SHA256(cle reseau,
// sequence gros-boutiste || « Thread »). false : echec de la plateforme.
bool deriverCleMle(const uint8_t cleReseau[kCle], uint32_t sequence, uint8_t cleMle[kCle]);

// --- Message dechiffre --------------------------------------------------------

struct Message {
  uint8_t ext[8] = {};      // emetteur, ordre naturel
  uint8_t commande = 0;
  bool aSource = false;     // TLV Source Address
  uint16_t rloc16 = 0;
  bool aPartition = false;  // TLV Leader Data
  uint32_t partition = 0;
  uint8_t nRoute64 = 0;     // valeur de la TLV Route64 (0 : absente ou mal formee)
  uint8_t route64[kRoute64Max] = {};
};

// Commande et TLV d'un message dechiffre. Une TLV qui deborde arrete la
// lecture ; ce qui a ete lu avant reste. Une Route64 de moins de 9 octets ou de
// plus de kRoute64Max est ignoree.
void lireTlv(const uint8_t *clair, size_t n, Message *m);

enum class Issue : uint8_t {
  Ignoree,     // pas un message MLE chiffre : autre trame, autre port, MLE sans securite
  Dechiffree,  // MIC verifie : le message est lu
  Echec,       // message MLE chiffre non dechiffre : en-tete illisible, cle indisponible, MIC faux
};

// Cle MLE d'une sequence ; false si elle n'est pas disponible.
typedef bool (*FournisseurCle)(void *contexte, uint32_t sequence, uint8_t cleMle[kCle]);

// Une trame entiere. Les cles et le clair passent par la pile et en sont
// effaces avant le retour.
Issue decoder(const uint8_t *psdu, size_t n, FournisseurCle cle, void *contexte, Message *m);

// --- Cles MLE gardees ---------------------------------------------------------

// Deux cles MLE derivees : la sequence courante de la pile et la suivante (une
// rotation de cle les fait servir l'une apres l'autre). Jamais la cle reseau.
class ClesMle {
 public:
  // Derive les cles de `courante` et de `courante + 1` ; l'appelant efface
  // ensuite `cleReseau`. false : echec de la plateforme (rien n'est garde).
  bool preparer(uint32_t courante, const uint8_t cleReseau[kCle]);
  // Cle gardee de cette sequence.
  bool trouver(uint32_t sequence, uint8_t cle[kCle]) const;
  bool preparees() const { return prepare_; }
  uint32_t courante() const { return courante_; }
  void effacer();

 private:
  struct Place {
    uint32_t sequence = 0;
    uint8_t cle[kCle] = {};
  };
  Place places_[2];
  bool prepare_ = false;
  uint32_t courante_ = 0;
};

// --- Routeurs entendus --------------------------------------------------------

struct Entendu {
  bool utilise = false;
  uint8_t ext[8] = {};      // ordre naturel
  uint16_t rloc16 = 0;
  bool aPartition = false;
  uint32_t partition = 0;
  uint8_t nRoute64 = 0;     // derniere Route64 brute ; 0 : aucune encore
  uint8_t route64[kRoute64Max] = {};
  int8_t rssi = 0;          // derniere trame
  int8_t rssiMin = 0;       // depuis l'entree dans la table
  int8_t rssiMax = 0;
  uint32_t nb = 0;          // messages dechiffres
  uint32_t dernier = 0;     // millis() du dernier
};

// Routeurs entendus, par ExtMac : seuls les emetteurs dont le RLOC16 est celui
// d'un routeur (10 bits de poids faible nuls) y entrent. Un routeur muet depuis
// kOubliMs en sort. Table pleine : le plus ancien laisse sa place.
class TableEntendus {
 public:
  static constexpr size_t kPlaces = 32;
  static constexpr uint32_t kOubliMs = 600000;

  // Un message dechiffre ; false s'il n'est pas d'un routeur (sans TLV Source
  // Address, ou RLOC16 d'enfant).
  bool noter(const Message &m, int8_t rssi, uint32_t maintenant);
  // Retire les routeurs muets depuis kOubliMs.
  void oublier(uint32_t maintenant);
  const Entendu &place(size_t i) const { return places_[i]; }
  size_t nombre() const;

 private:
  Entendu places_[kPlaces];
};

}  // namespace mle
```

`sonde/src/mle.cpp` :

```cpp
#include "mle.h"

#include <string.h>

namespace mle {

void effacer(void *p, size_t n) {
  volatile uint8_t *v = static_cast<volatile uint8_t *>(p);
  while (n--) *v++ = 0;
}

// ===========================================================================
//  802.15.4
// ===========================================================================

namespace {

constexpr uint8_t kTypeDonnees = 1;
constexpr uint8_t kVersion2015 = 2;
constexpr uint8_t kModeCourte = 2, kModeLongue = 3;
constexpr uint8_t kHt1 = 0x7E, kHt2 = 0x7F;   // fin des IE d'en-tete : IE de charge ensuite, ou la charge
constexpr uint8_t kFinIeCharge = 0x0F;         // groupe qui termine les IE de charge

size_t longueurAdresse(uint8_t mode) { return mode == kModeLongue ? 8 : mode == kModeCourte ? 2 : 0; }

}  // namespace

bool lireMac(const uint8_t *p, size_t n, EnTeteMac *m) {
  // Controle (2), sequence (1), au moins une adresse courte, FCS (2).
  if (n < 2 + 2 || n > kPsduMax) return false;
  *m = EnTeteMac();
  m->fin = n - 2;
  const uint16_t fcf = (uint16_t)(p[0] | p[1] << 8);
  if ((fcf & 0x07) != kTypeDonnees || (fcf & 0x08)) return false;  // donnees, sans securite MAC
  m->version = (uint8_t)((fcf >> 12) & 3);
  m->modeDst = (uint8_t)((fcf >> 10) & 3);
  m->modeSrc = (uint8_t)((fcf >> 14) & 3);
  if (m->version > kVersion2015 || m->modeDst == 1 || m->modeSrc == 1) return false;
  const bool v2015 = m->version == kVersion2015;
  const bool compression = fcf & 0x40;
  size_t i = 2;
  if (!(v2015 && (fcf & 0x0100))) i++;  // numero de sequence, sauf supprime (2015)
  const bool dst = m->modeDst != 0, src = m->modeSrc != 0;
  bool panDst, panSrc;
  if (!v2015) {
    // 2003 et 2006 : PAN de la destination, et celui de la source sans compression.
    panDst = dst;
    panSrc = src && !compression;
  } else if (!dst && !src) {
    // 2015, tableau 7-2.
    panDst = compression;
    panSrc = false;
  } else if (dst && !src) {
    panDst = !compression;
    panSrc = false;
  } else if (!dst) {
    panDst = false;
    panSrc = !compression;
  } else if (m->modeDst == kModeLongue && m->modeSrc == kModeLongue) {
    panDst = !compression;
    panSrc = false;
  } else {
    panDst = true;
    panSrc = !compression;
  }
  const size_t lDst = longueurAdresse(m->modeDst), lSrc = longueurAdresse(m->modeSrc);
  const size_t entete = (panDst ? 2 : 0) + lDst + (panSrc ? 2 : 0) + lSrc;
  if (i + entete > m->fin) return false;
  if (panDst) i += 2;
  memcpy(m->dst, p + i, lDst);
  i += lDst;
  if (panSrc) i += 2;
  memcpy(m->src, p + i, lSrc);
  i += lSrc;
  if (v2015 && (fcf & 0x0200)) {
    // IE d'en-tete : longueur (7 bits), identifiant (8 bits), type 0.
    bool fini = false;
    bool charges = false;
    while (!fini) {
      if (i + 2 > m->fin) return false;
      const uint16_t d = (uint16_t)(p[i] | p[i + 1] << 8);
      if (d & 0x8000) return false;
      const size_t l = d & 0x7F;
      const uint8_t id = (uint8_t)((d >> 7) & 0xFF);
      i += 2;
      if (i + l > m->fin) return false;
      i += l;
      if (id == kHt1) charges = fini = true;
      if (id == kHt2) fini = true;
    }
    // IE de charge (apres HT1) : longueur (11 bits), groupe (4 bits), type 1 ; jusqu'au groupe 0x0F.
    while (charges) {
      if (i + 2 > m->fin) return false;
      const uint16_t d = (uint16_t)(p[i] | p[i + 1] << 8);
      if (!(d & 0x8000)) return false;
      const size_t l = d & 0x07FF;
      const uint8_t groupe = (uint8_t)((d >> 11) & 0x0F);
      i += 2;
      if (i + l > m->fin) return false;
      i += l;
      if (groupe == kFinIeCharge) charges = false;
    }
  }
  m->charge = i;
  return true;
}

// ===========================================================================
//  IPHC et UDP
// ===========================================================================

namespace {

// Identifiant d'interface tire d'une adresse MAC (dans l'ordre de la trame) :
// longue, l'adresse dans l'ordre naturel, bit U/L inverse ; courte,
// 0000:00ff:fe00:XXXX.
bool iidDepuisMac(const uint8_t *mac, uint8_t mode, uint8_t iid[8]) {
  if (mode == kModeLongue) {
    for (int k = 0; k < 8; k++) iid[k] = mac[7 - k];
    iid[0] ^= 0x02;
    return true;
  }
  if (mode == kModeCourte) {
    memset(iid, 0, 8);
    iid[3] = 0xFF;
    iid[4] = 0xFE;
    iid[6] = mac[1];
    iid[7] = mac[0];
    return true;
  }
  return false;
}

// Adresse unicast sans contexte (SAC ou DAC a 0) : fe80::/64 et l'identifiant,
// en ligne (128, 64 ou 16 bits) ou tire de l'adresse MAC.
bool unicast(const uint8_t *p, size_t fin, size_t *i, uint8_t mode, const uint8_t *mac, uint8_t modeMac,
             uint8_t adresse[16]) {
  static const size_t kLongueurs[] = {16, 8, 2, 0};
  if (*i + kLongueurs[mode] > fin) return false;
  memset(adresse, 0, 16);
  adresse[0] = 0xFE;
  adresse[1] = 0x80;
  switch (mode) {
    case 0: memcpy(adresse, p + *i, 16); break;
    case 1: memcpy(adresse + 8, p + *i, 8); break;
    case 2:
      adresse[11] = 0xFF;
      adresse[12] = 0xFE;
      adresse[14] = p[*i];
      adresse[15] = p[*i + 1];
      break;
    default:
      if (!iidDepuisMac(mac, modeMac, adresse + 8)) return false;
      break;
  }
  *i += kLongueurs[mode];
  return true;
}

// Destination multicast sans contexte (M a 1, DAC a 0) : 128 bits, ffXX::00XX:XXXX:XXXX,
// ffXX::00XX:XXXX ou ff02::00XX.
bool multicast(const uint8_t *p, size_t fin, size_t *i, uint8_t mode, uint8_t adresse[16]) {
  static const size_t kLongueurs[] = {16, 6, 4, 1};
  if (*i + kLongueurs[mode] > fin) return false;
  memset(adresse, 0, 16);
  const uint8_t *e = p + *i;
  switch (mode) {
    case 0: memcpy(adresse, e, 16); break;
    case 1:
      adresse[0] = 0xFF;
      adresse[1] = e[0];
      memcpy(adresse + 11, e + 1, 5);
      break;
    case 2:
      adresse[0] = 0xFF;
      adresse[1] = e[0];
      memcpy(adresse + 13, e + 1, 3);
      break;
    default:
      adresse[0] = 0xFF;
      adresse[1] = 0x02;
      adresse[15] = e[0];
      break;
  }
  *i += kLongueurs[mode];
  return true;
}

constexpr uint8_t kProtocoleUdp = 17;

}  // namespace

bool lienLocal(const uint8_t a[16]) {
  static const uint8_t kPrefixe[8] = {0xFE, 0x80, 0, 0, 0, 0, 0, 0};
  return !memcmp(a, kPrefixe, sizeof(kPrefixe));
}

Refus lireDatagramme(const uint8_t *p, const EnTeteMac &m, Datagramme *d) {
  *d = Datagramme();
  const size_t fin = m.fin;
  size_t i = m.charge;
  if (i + 2 > fin) return Refus::Tronquee;
  if ((p[i] & 0xE0) != 0x60) return Refus::PasIphc;
  const uint8_t a = p[i], b = p[i + 1];
  i += 2;
  const uint8_t tf = (a >> 3) & 3, hlim = a & 3;
  const bool nh = a & 0x04;
  const bool cid = b & 0x80, sac = b & 0x40, mcast = b & 0x08, dac = b & 0x04;
  const uint8_t sam = (b >> 4) & 3, dam = b & 3;
  if (cid || sac || dac) return Refus::Contexte;
  static const size_t kTf[] = {4, 3, 1, 0};
  i += kTf[tf];
  uint8_t suivant = 0;
  if (!nh) {
    if (i + 1 > fin) return Refus::Tronquee;
    suivant = p[i++];
  }
  if (hlim == 0) i++;
  if (i > fin) return Refus::Tronquee;
  if (!unicast(p, fin, &i, sam, m.src, m.modeSrc, d->src)) return Refus::Tronquee;
  const bool dstLue = mcast ? multicast(p, fin, &i, dam, d->dst) : unicast(p, fin, &i, dam, m.dst, m.modeDst, d->dst);
  if (!dstLue) return Refus::Tronquee;
  if (nh) {
    // NHC UDP : 11110CPP.
    if (i + 1 > fin) return Refus::Tronquee;
    const uint8_t u = p[i++];
    if ((u & 0xF8) != 0xF0) return Refus::PasUdp;
    static const size_t kPorts[] = {4, 3, 3, 1};
    const uint8_t ports = u & 3;
    const size_t somme = (u & 0x04) ? 0 : 2;
    if (i + kPorts[ports] + somme > fin) return Refus::Tronquee;
    const uint8_t *e = p + i;
    switch (ports) {
      case 0:
        d->portSrc = (uint16_t)(e[0] << 8 | e[1]);
        d->portDst = (uint16_t)(e[2] << 8 | e[3]);
        break;
      case 1:
        d->portSrc = (uint16_t)(e[0] << 8 | e[1]);
        d->portDst = (uint16_t)(0xF000 | e[2]);
        break;
      case 2:
        d->portSrc = (uint16_t)(0xF000 | e[0]);
        d->portDst = (uint16_t)(e[1] << 8 | e[2]);
        break;
      default:
        d->portSrc = (uint16_t)(0xF0B0 | e[0] >> 4);
        d->portDst = (uint16_t)(0xF0B0 | (e[0] & 0x0F));
        break;
    }
    i += kPorts[ports] + somme;
  } else {
    if (suivant != kProtocoleUdp) return Refus::PasUdp;
    if (i + 8 > fin) return Refus::Tronquee;
    d->portSrc = (uint16_t)(p[i] << 8 | p[i + 1]);
    d->portDst = (uint16_t)(p[i + 2] << 8 | p[i + 3]);
    i += 8;
  }
  d->charge = i;
  return Refus::Aucun;
}

// ===========================================================================
//  Securite MLE
// ===========================================================================

bool lireSecuriteMle(const uint8_t *c, size_t n, SecuriteMle *s) {
  *s = SecuriteMle();
  if (n < 1 + kEnTeteSecurite + 1 + kMic || c[0] != kSuiteChiffree || c[1] != kControle) return false;
  s->entete = c + 1;
  s->compteur = (uint32_t)c[2] | (uint32_t)c[3] << 8 | (uint32_t)c[4] << 16 | (uint32_t)c[5] << 24;
  s->sequence = (uint32_t)c[6] << 24 | (uint32_t)c[7] << 16 | (uint32_t)c[8] << 8 | (uint32_t)c[9];
  s->index = c[10];
  s->chiffre = c + 1 + kEnTeteSecurite;
  s->n = n - 1 - kEnTeteSecurite - kMic;
  s->mic = c + n - kMic;
  return true;
}

void extDepuisIid(const uint8_t iid[8], uint8_t ext[8]) {
  memcpy(ext, iid, 8);
  ext[0] ^= 0x02;
}

void nonceMle(const uint8_t ext[8], uint32_t compteur, uint8_t nonce[kNonce]) {
  memcpy(nonce, ext, 8);
  nonce[8] = (uint8_t)(compteur >> 24);
  nonce[9] = (uint8_t)(compteur >> 16);
  nonce[10] = (uint8_t)(compteur >> 8);
  nonce[11] = (uint8_t)compteur;
  nonce[12] = kNiveau;
}

void donneesAssociees(const uint8_t src[16], const uint8_t dst[16], const uint8_t entete[kEnTeteSecurite],
                      uint8_t aad[kDonneesAssociees]) {
  memcpy(aad, src, 16);
  memcpy(aad + 16, dst, 16);
  memcpy(aad + 32, entete, kEnTeteSecurite);
}

bool deriverCleMle(const uint8_t cleReseau[kCle], uint32_t sequence, uint8_t cleMle[kCle]) {
  const uint8_t entree[4 + 6] = {(uint8_t)(sequence >> 24), (uint8_t)(sequence >> 16), (uint8_t)(sequence >> 8),
                                 (uint8_t)sequence, 'T', 'h', 'r', 'e', 'a', 'd'};
  uint8_t hash[32];
  const bool ok = hmacSha256(cleReseau, kCle, entree, sizeof(entree), hash);
  if (ok) memcpy(cleMle, hash, kCle);  // les 128 premiers bits : la cle MLE
  effacer(hash, sizeof(hash));
  return ok;
}

// ===========================================================================
//  Message
// ===========================================================================

namespace {

constexpr uint8_t kTlvSource = 0, kTlvRoute64 = 9, kTlvChef = 11;

}  // namespace

void lireTlv(const uint8_t *c, size_t n, Message *m) {
  if (n < 1) return;
  m->commande = c[0];
  for (size_t i = 1; i + 2 <= n;) {
    const uint8_t type = c[i];
    const size_t l = c[i + 1];
    if (i + 2 + l > n) break;
    const uint8_t *v = c + i + 2;
    if (type == kTlvSource && l == 2) {
      m->aSource = true;
      m->rloc16 = (uint16_t)(v[0] << 8 | v[1]);
    } else if (type == kTlvChef && l == 8) {
      m->aPartition = true;
      m->partition = (uint32_t)v[0] << 24 | (uint32_t)v[1] << 16 | (uint32_t)v[2] << 8 | (uint32_t)v[3];
    } else if (type == kTlvRoute64 && l >= 9 && l <= kRoute64Max) {
      m->nRoute64 = (uint8_t)l;
      memcpy(m->route64, v, l);
    }
    i += 2 + l;
  }
}

Issue decoder(const uint8_t *psdu, size_t n, FournisseurCle fournir, void *contexte, Message *m) {
  EnTeteMac mac;
  Datagramme d;
  if (!lireMac(psdu, n, &mac) || lireDatagramme(psdu, mac, &d) != Refus::Aucun) return Issue::Ignoree;
  if (d.portDst != kPortMle || !lienLocal(d.src)) return Issue::Ignoree;
  const uint8_t *c = psdu + d.charge;
  const size_t nc = mac.fin - d.charge;
  if (nc >= 1 && c[0] == kSuiteSansSecurite) return Issue::Ignoree;
  SecuriteMle s;
  if (!lireSecuriteMle(c, nc, &s)) return Issue::Echec;
  uint8_t cle[kCle];
  if (!fournir(contexte, s.sequence, cle)) {
    effacer(cle, sizeof(cle));
    return Issue::Echec;
  }
  uint8_t ext[8], nonce[kNonce], aad[kDonneesAssociees], clair[kPsduMax];
  extDepuisIid(d.src + 8, ext);
  nonceMle(ext, s.compteur, nonce);
  donneesAssociees(d.src, d.dst, s.entete, aad);
  const bool ok = aesCcmDechiffrer(cle, nonce, aad, sizeof(aad), s.chiffre, s.n, s.mic, clair);
  effacer(cle, sizeof(cle));
  if (!ok) {
    effacer(clair, sizeof(clair));
    return Issue::Echec;
  }
  *m = Message();
  memcpy(m->ext, ext, 8);
  lireTlv(clair, s.n, m);
  effacer(clair, sizeof(clair));
  return Issue::Dechiffree;
}

// ===========================================================================
//  Cles MLE gardees
// ===========================================================================

bool ClesMle::preparer(uint32_t courante, const uint8_t cleReseau[kCle]) {
  Place p[2];
  p[0].sequence = courante;
  p[1].sequence = courante + 1;  // la suivante, a la rotation (le retour a 0 compris)
  const bool ok = deriverCleMle(cleReseau, p[0].sequence, p[0].cle) && deriverCleMle(cleReseau, p[1].sequence, p[1].cle);
  if (ok) {
    effacer();
    memcpy(places_, p, sizeof(places_));
    prepare_ = true;
    courante_ = courante;
  }
  mle::effacer(p, sizeof(p));
  return ok;
}

bool ClesMle::trouver(uint32_t sequence, uint8_t cle[kCle]) const {
  if (!prepare_) return false;
  for (const Place &p : places_)
    if (p.sequence == sequence) {
      memcpy(cle, p.cle, kCle);
      return true;
    }
  return false;
}

void ClesMle::effacer() {
  mle::effacer(places_, sizeof(places_));
  prepare_ = false;
  courante_ = 0;
}

// ===========================================================================
//  Routeurs entendus
// ===========================================================================

bool TableEntendus::noter(const Message &m, int8_t rssi, uint32_t maintenant) {
  if (!m.aSource || (m.rloc16 & 0x03FF)) return false;
  Entendu *e = nullptr, *libre = nullptr, *ancien = nullptr;
  for (Entendu &p : places_) {
    if (p.utilise && !memcmp(p.ext, m.ext, 8)) {
      e = &p;
      break;
    }
    if (!p.utilise) {
      if (!libre) libre = &p;
    } else if (!ancien || maintenant - p.dernier > maintenant - ancien->dernier) {
      ancien = &p;
    }
  }
  if (!e) {
    e = libre ? libre : ancien;
    *e = Entendu();
    e->utilise = true;
    memcpy(e->ext, m.ext, 8);
    e->rssiMin = e->rssiMax = rssi;
  }
  e->rloc16 = m.rloc16;
  if (m.aPartition) {
    e->aPartition = true;
    e->partition = m.partition;
  }
  if (m.nRoute64) {
    e->nRoute64 = m.nRoute64;
    memcpy(e->route64, m.route64, m.nRoute64);
  }
  e->rssi = rssi;
  if (rssi < e->rssiMin) e->rssiMin = rssi;
  if (rssi > e->rssiMax) e->rssiMax = rssi;
  e->nb++;
  e->dernier = maintenant;
  return true;
}

void TableEntendus::oublier(uint32_t maintenant) {
  for (Entendu &p : places_)
    if (p.utilise && maintenant - p.dernier >= kOubliMs) p = Entendu();
}

size_t TableEntendus::nombre() const {
  size_t k = 0;
  for (const Entendu &p : places_) k += p.utilise;
  return k;
}

}  // namespace mle
```

`sonde/src/mle_crypto.cpp` :

```cpp
// Crypto de l'ecoute MLE sur la carte : mbedTLS (SHA-256 et AES materiels du
// C6). Les tests hote fournissent la leur (sonde/test/test_mle.cpp,
// CommonCrypto). Appels depuis la tache loop seulement (ecoute.cpp).
#include <mbedtls/ccm.h>
#include <mbedtls/md.h>

#include "mle.h"

namespace mle {

bool hmacSha256(const uint8_t *cle, size_t nCle, const uint8_t *message, size_t n, uint8_t sortie[32]) {
  const mbedtls_md_info_t *info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  return info != nullptr && mbedtls_md_hmac(info, cle, nCle, message, n, sortie) == 0;
}

bool aesCcmDechiffrer(const uint8_t cle[kCle], const uint8_t nonce[kNonce], const uint8_t *aad, size_t nAad,
                      const uint8_t *chiffre, size_t n, const uint8_t mic[kMic], uint8_t *clair) {
  mbedtls_ccm_context ccm;
  mbedtls_ccm_init(&ccm);
  int e = mbedtls_ccm_setkey(&ccm, MBEDTLS_CIPHER_ID_AES, cle, 128);
  if (e == 0) e = mbedtls_ccm_auth_decrypt(&ccm, n, nonce, kNonce, aad, nAad, chiffre, clair, mic, kMic);
  // Libere et efface le contexte (la cle etendue).
  mbedtls_ccm_free(&ccm);
  if (e != 0) effacer(clair, n);
  return e == 0;
}

}  // namespace mle
```

- [ ] **Step 6 : les voir passer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && sh sonde/test/lancer.sh`

Expected : `test_h1 : 121 verification(s), 0 echec(s)` ; `test_distant : 145 verification(s), 0 echec(s)` ; `test_mle : 72874 verification(s), 0 echec(s)` ; ni avertissement de compilation, ni rapport d'ASan ou d'UBSan.

- [ ] **Step 7 : commit.**

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add sonde/src/mle.cpp sonde/src/mle.h sonde/src/mle_crypto.cpp sonde/test/lancer.sh sonde/test/test_mle.cpp sonde/test/vecteurs_mle.h sonde/test/vecteurs_mle.py && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --cached --name-only | sed "s|^|$PWD/|") && git commit -q -F - <<'EOF'
Decoder et dechiffrer les messages MLE dans un module pur de la sonde, teste sur des vecteurs inventes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` (suivi des faux positifs connus) ; `0`.

---

### Task 3: L'écoute et la résolution sur la carte : le firmware 1.1.0

**Files :**
- Create : `sonde/src/ecoute.h`, `sonde/src/ecoute.cpp`
- Modify : `sonde/src/main.cpp`, `sonde/src/distant.cpp`, `sonde/src/distant.h`, `sonde/test/test_distant.cpp`, `sonde/sonde_essai.py`, `sonde/test/test_sonde_essai.py`, `sonde/README.md`, `sonde/platformio.ini` (blocs)

**Interfaces:**
- Consumes : `mle.h` (tâche 2).
- Produces :
  - `ecoute::demarrer(ot, Acces{sequence, cleReseau})`, appelé sous le verrou OpenThread après `Matter.begin()` ; `ecoute::tour(maintenant)`, dans `loop()` ; `ecoute::compteurs()` (`trames`, `mle`, `echecs`, `filePleine`) ; `ecoute::entendus()` ;
  - dans `main.cpp` : `lireSequenceCle` et `lireCleReseau` (verrou OpenThread en 50 ms au plus ; la copie de la clé réseau effacée) ; `cmdAnnonces` ; `cmdResoudre`, `resolutionsTour`, `resolutionsFinies` (8 places, `kResolutionMs` 15 000, `kPasCacheMs` 250) ; `etat` et son `ecoute` ; `kVersion` `"1.1.0"` ;
  - `distant::permise` : `"annonces"` exactement, et `"resoudre "` suivi des arguments ;
  - dans `sonde_essai.py` : `liens_route64(hexa)`, `delai_reponse(commande)`, `attente` et `fin_de_reponse` pour `resoudre` (par son id) et pour `annonces` (`"suite"`), et l'affichage des deux.

Le contrat (spec, section 1.2), sans changement de l'enveloppe H1 :
- `annonces` : une ligne par routeur entendu, `{"v":1,"t":"annonces","rloc16":"XXXX","ext":"<16 hexa>","partition":"<8 hexa>"|null,"route64":"<hexa>"|null,"seq":…|null,"rssi":…,"rssi_min":…,"rssi_max":…,"nb":…,"age_s":…,"suite":…}`, `"suite":true` sauf sur la dernière ; sans routeur entendu, la seule ligne `{"v":1,"t":"annonces","vide":true}` ; une ligne fait moins de 400 octets ;
- `resoudre <ipv6> <id>` : `{"v":1,"t":"resoudre","id":…,"cible":"<ipv6>","ok":true,"ms":…,"rloc16":"XXXX","mleid":"<32 hexa>"|null}`, ou `"ok":false` et l'`"erreur"` : `introuvable` (rien en 15 s), `syntaxe`, `suspendue`, `occupee` (8 en vol, ou le verrou OpenThread refusé), `envoi …` ;
- `etat` gagne `"ecoute":{"trames":…,"mle":…,"echecs":…,"file_pleine":…}`, depuis le démarrage.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`) : la liste blanche, et l'outil d'essai.

Dans `sonde/test/test_distant.cpp`, remplacer :

```cpp
// Tests hote de sonde/src/distant.{h,cpp} (rid, liste blanche, reponses
// gardees, cadence ; depuis la 1.0.3, entiers des commandes et reprises CoAP
// d'un diag) et de sonde/src/voyant.h (LED de la carte, 1.0.3).
// Lancer : sh sonde/test/lancer.sh
#include <stdio.h>
```

par :

```cpp
// Tests hote de sonde/src/distant.{h,cpp} (rid, liste blanche, reponses
// gardees, cadence ; depuis la 1.0.3, entiers des commandes et reprises CoAP
// d'un diag ; depuis la 1.1.0, annonces et resoudre dans la liste blanche) et
// de sonde/src/voyant.h (LED de la carte, 1.0.3).
// Lancer : sh sonde/test/lancer.sh
#include <stdio.h>
```

Dans `sonde/test/test_distant.cpp`, remplacer :

```cpp
  CHECK(texteRid(1000, t) == 4 && !strcmp(t, "1000"), "texte 1000");
  // liste blanche
  const char *oui[] = {"bonjour", "etat", "voisins", "routeurs", "diag 0400 0 1", "diag ", "  etat", " diag x"};
  const char *non[] = {"", "cle", "cle nouvelle", "cle efface", "nom x", "oubli", "Bonjour", "etat ", "etatx",
                       "diag", "routeur", "voisins x", "bonjour\t", "diagx 1", "routeurs;oubli"};
  for (const char *x : oui) CHECK(permise(x), "permise : %s", x);
  for (const char *x : non) CHECK(!permise(x), "refusee : %s", x);
```

par :

```cpp
  CHECK(texteRid(1000, t) == 4 && !strcmp(t, "1000"), "texte 1000");
  // liste blanche
  const char *oui[] = {"bonjour", "etat", "voisins", "routeurs", "diag 0400 0 1", "diag ", "  etat", " diag x",
                       "annonces", "resoudre fd00::1 7", "resoudre ", " annonces"};
  const char *non[] = {"", "cle", "cle nouvelle", "cle efface", "nom x", "oubli", "Bonjour", "etat ", "etatx",
                       "diag", "routeur", "voisins x", "bonjour\t", "diagx 1", "routeurs;oubli", "annonces x",
                       "annonce", "resoudre", "resoudrex 1", "Annonces"};
  for (const char *x : oui) CHECK(permise(x), "permise : %s", x);
  for (const char *x : non) CHECK(!permise(x), "refusee : %s", x);
```

Dans `sonde/test/test_sonde_essai.py`, remplacer :

```python
#!/usr/bin/env python3
"""Tests de sonde/sonde_essai.py : masquage des secrets et decodage du TLV 7.

  python3 sonde/test/test_sonde_essai.py
```

par :

```python
#!/usr/bin/env python3
"""Tests de sonde/sonde_essai.py : masquage des secrets, decodage du TLV 7, annonces et resolutions (1.1.0).

  python3 sonde/test/test_sonde_essai.py
```

Dans `sonde/test/test_sonde_essai.py`, remplacer :

```python


class Structure(unittest.TestCase):
    def test_le_bloc_main_est_la_derniere_instruction_du_module(self):
```

par :

```python


class AnnoncesEtResolution(unittest.TestCase):
    """Firmware 1.1.0 : annonces (une ligne par routeur entendu, "suite" sauf sur la derniere) et resoudre (une
    reponse par id, apres 15 s au plus). Valeurs inventees."""

    ANNONCE = {"v": 1, "t": "annonces", "rloc16": "5000", "ext": "E000000000000A01", "partition": "1234ABCD",
               "route64": "7A" + "4000080000100000" + "F10092", "seq": 122, "rssi": -61, "rssi_min": -70,
               "rssi_max": -55, "nb": 12, "age_s": 7, "suite": True}

    def test_attente_d_une_resolution_par_son_id(self):
        self.assertEqual(s.attente("resoudre fd00::1 17"), ("resoudre", 17))
        self.assertEqual(s.attente("annonces"), ("annonces", None))
        self.assertEqual(s.delai_reponse("resoudre fd00::1 17"), 20)
        self.assertEqual(s.delai_reponse("annonces"), 6)

    def test_fin_d_une_reponse(self):
        self.assertFalse(s.fin_de_reponse(self.ANNONCE, "annonces", None), "suite : d'autres lignes viennent")
        self.assertTrue(s.fin_de_reponse(dict(self.ANNONCE, suite=False), "annonces", None))
        self.assertTrue(s.fin_de_reponse({"v": 1, "t": "annonces", "vide": True}, "annonces", None))
        r = {"v": 1, "t": "resoudre", "id": 17, "cible": "fd00::1", "ok": False, "erreur": "introuvable"}
        self.assertTrue(s.fin_de_reponse(r, "resoudre", 17))
        self.assertFalse(s.fin_de_reponse(dict(r, id=16), "resoudre", 17), "une autre resolution")

    def test_liens_d_une_route64(self):
        # Routeurs 1, 20 et 43 : 1 et 43 voisins (qualites sortante et entrante), 20 l'emetteur lui-meme.
        self.assertEqual(s.liens_route64(self.ANNONCE["route64"]), [(1, 3, 3), (43, 2, 1)])
        self.assertEqual(s.liens_route64("7A00"), [], "trop courte")

    def test_affichage(self):
        ecran = io.StringIO()
        with contextlib.redirect_stdout(ecran):
            s.afficher(self.ANNONCE)
            s.afficher({"v": 1, "t": "annonces", "vide": True})
            s.afficher({"v": 1, "t": "resoudre", "id": 17, "cible": "fd00::1", "ok": True, "ms": 340,
                        "rloc16": "AC00", "mleid": "FD00111122220C87" + "0000000000000017"})
        texte = ecran.getvalue()
        self.assertIn("5000 ext E000000000000A01 partition 1234ABCD rssi -61 (-70..-55) 12 msg il y a 7 s", texte)
        self.assertIn("liens : 0400 3/3, AC00 2/1", texte)
        self.assertIn("aucun routeur entendu", texte)
        self.assertIn("fd00::1 : AC00 (parent AC00), 340 ms, ML-EID fd00:1111:2222:c87::17", texte)

    def test_donnees_entieres(self):
        """Une Route64 et un ML-EID ont plus de 16 hexa : ce sont des donnees, jamais masquees."""
        for t in ("annonces", "resoudre"):
            self.assertIn(t, s.TYPES_DONNEES)
        self.assertEqual(s.sans_cle(self.ANNONCE), self.ANNONCE)


class Structure(unittest.TestCase):
    def test_le_bloc_main_est_la_derniere_instruction_du_module(self):
```

- [ ] **Step 2 : les voir échouer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && sh sonde/test/lancer.sh 2>&1 | grep -E "ECHEC|verification" | head -12; /usr/bin/python3 -m unittest discover -s sonde/test 2>&1 | tail -3`

Expected : `test_h1 : 121 verification(s), 0 echec(s)` ; quatre `ECHEC …/test_distant.cpp:102 : permise : …` (`annonces`, `resoudre fd00::1 7`, `resoudre `, ` annonces`) ; `test_distant : 154 verification(s), 4 echec(s)` ; puis, pour Python, `FAILED (failures=4, errors=1)`.

- [ ] **Step 3 : la liste blanche, l'écoute, les commandes et l'outil d'essai** (`--etapes 3`).

Dans `sonde/src/distant.h`, remplacer :

```cpp
// ===========================================================================
//  Commandes de la sonde : briques pures (contrat de la 1.0.2, complete en
//  1.0.3)
//
//  Commandes recues par le reseau. Charge d'un message H1 de l'app :
```

par :

```cpp
// ===========================================================================
//  Commandes de la sonde : briques pures (contrat de la 1.0.2, complete en
//  1.0.3 et en 1.1.0)
//
//  Commandes recues par le reseau. Charge d'un message H1 de l'app :
```

Dans `sonde/src/distant.h`, remplacer :

```cpp
//  l'USB. Charge d'une reponse : "<rid> <ligne JSON>".
//
//  - Liste blanche : bonjour, etat, voisins, routeurs, diag. Tout le reste
//    (cle..., nom, oubli, commande inconnue) : refuse a distance.
//  - Reponses gardees : un rid repete dans la meme session ne relance rien,
//    la reponse gardee repart : les 8 dernieres reponses, dans la limite de
```

par :

```cpp
//  l'USB. Charge d'une reponse : "<rid> <ligne JSON>".
//
//  - Liste blanche : bonjour, etat, voisins, routeurs, diag ; depuis la
//    1.1.0, annonces et resoudre. Tout le reste (cle..., nom, oubli, commande
//    inconnue) : refuse a distance.
//  - Reponses gardees : un rid repete dans la meme session ne relance rien,
//    la reponse gardee repart : les 8 dernieres reponses, dans la limite de
```

Dans `sonde/src/distant.h`, remplacer :

```cpp

// Commande permise a distance (espaces de tete sautes, comme l'aiguillage) :
// "bonjour", "etat", "voisins", "routeurs" exactement, ou "diag " suivi des
// arguments.
bool permise(const char *commande);

```

par :

```cpp

// Commande permise a distance (espaces de tete sautes, comme l'aiguillage) :
// "bonjour", "etat", "voisins", "routeurs", "annonces" exactement, ou "diag "
// ou "resoudre " suivi des arguments.
bool permise(const char *commande);

```

Dans `sonde/src/distant.cpp`, remplacer :

```cpp
  while (*commande == ' ') commande++;
  return !strcmp(commande, "bonjour") || !strcmp(commande, "etat") || !strcmp(commande, "voisins") ||
         !strcmp(commande, "routeurs") || !strncmp(commande, "diag ", 5);
}

```

par :

```cpp
  while (*commande == ' ') commande++;
  return !strcmp(commande, "bonjour") || !strcmp(commande, "etat") || !strcmp(commande, "voisins") ||
         !strcmp(commande, "routeurs") || !strcmp(commande, "annonces") || !strncmp(commande, "diag ", 5) ||
         !strncmp(commande, "resoudre ", 9);
}

```

`sonde/src/ecoute.h` :

```cpp
#pragma once
// ===========================================================================
//  Ecoute des messages MLE sur la carte (firmware 1.1.0, spec de la sonde
//  tout-en-un, section 1.1)
//
//  En FED, la sonde recoit les messages MLE de ses voisins a un saut (les
//  annonces des routeurs portent leur Route64), sans mode promiscuite.
//  - Le rappel des trames (otLinkSetPcapCallback), dans la tache OpenThread,
//    ne fait qu'un tri (trames de donnees sans securite MAC) et une copie dans
//    une file FreeRTOS de 16 trames : une file pleine est comptee, jamais
//    bloquante. Jamais de verrou, jamais d'appel Matter ni CHIP, jamais de
//    Serial.
//  - Tout le reste dans la tache loop (tour) : le dechiffrement (mle.h), la
//    table des routeurs entendus, l'oubli de ceux qui se taisent depuis 10 min.
//  - La cle reseau n'est lue, sous le verrou OpenThread et par main.cpp, que
//    pour deriver les cles MLE quand la sequence de la pile change, puis
//    effacee ; seules deux cles MLE sont gardees (mle::ClesMle). Aucune
//    commande ne rend ni la cle reseau ni une cle derivee.
// ===========================================================================
#include <openthread/instance.h>
#include <stdint.h>

#include "mle.h"

namespace ecoute {

// Fournis par main.cpp, sous le verrou OpenThread : la sequence de cle courante
// de la pile, et la cle reseau (que l'appelant efface apres usage). false :
// verrou non pris.
struct Acces {
  bool (*sequence)(uint32_t *courante);
  bool (*cleReseau)(uint8_t cle[mle::kCle]);
};

// Pose le rappel des trames ; verrou OpenThread pris par l'appelant.
void demarrer(otInstance *ot, const Acces &acces);

// Tache loop : les trames de la file (16 au plus), puis l'oubli des routeurs
// muets depuis 10 min.
void tour(uint32_t maintenant);

// Depuis le demarrage (etat.ecoute).
struct Compteurs {
  uint32_t trames;      // trames recues par le rappel
  uint32_t mle;         // messages MLE dechiffres
  uint32_t echecs;      // messages MLE chiffres non dechiffres : en-tete illisible, cle indisponible, MIC faux
  uint32_t filePleine;  // trames perdues, file pleine
};
Compteurs compteurs();

// Routeurs entendus (commande annonces), lus dans la tache loop.
const mle::TableEntendus &entendus();

}  // namespace ecoute
```

`sonde/src/ecoute.cpp` :

```cpp
// Ecoute des messages MLE sur la carte : voir ecoute.h. Les briques pures
// (decodage, cles, table) sont dans mle.h, testees sur l'hote.
#include "ecoute.h"

#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <openthread/link.h>
#include <openthread/platform/radio.h>
#include <string.h>

#include <atomic>

namespace ecoute {
namespace {

constexpr uint8_t kFile = 16;

struct Trame {
  uint8_t n;
  int8_t rssi;
  uint8_t psdu[mle::kPsduMax];
};

QueueHandle_t sFile = nullptr;
Trame sTrameOt;    // tampon du rappel (tache OpenThread seulement)
Trame sTrameLoop;  // tampon de la tache loop
// Ecrits par le rappel (tache OpenThread), lus par la tache loop.
std::atomic<uint32_t> sTrames{0};
std::atomic<uint32_t> sFilePleine{0};
// Tache loop seulement.
uint32_t sMle = 0, sEchecs = 0;
mle::TableEntendus sEntendus;
mle::ClesMle sCles;
Acces sAcces = {nullptr, nullptr};

// Tache OpenThread, verrou OpenThread tenu : le tri et la copie, rien d'autre.
// Les messages MLE ne sont pas chiffres au niveau MAC : seules les trames de
// donnees sans securite MAC sont gardees.
void surTrame(const otRadioFrame *f, bool emise, void *) {
  if (emise || f == nullptr || f->mPsdu == nullptr) return;
  sTrames.fetch_add(1, std::memory_order_relaxed);
  const uint16_t n = f->mLength;
  if (n < 3 || n > mle::kPsduMax) return;
  if ((f->mPsdu[0] & 0x07) != 0x01 || (f->mPsdu[0] & 0x08)) return;
  sTrameOt.n = (uint8_t)n;
  sTrameOt.rssi = f->mInfo.mRxInfo.mRssi;
  memcpy(sTrameOt.psdu, f->mPsdu, n);
  if (sFile == nullptr || xQueueSend(sFile, &sTrameOt, 0) != pdTRUE)
    sFilePleine.fetch_add(1, std::memory_order_relaxed);
}

// Cle MLE d'une sequence : gardee, ou derivee quand la sequence de la pile a
// change depuis la derniere derivation (rotation de cle). Une sequence
// etrangere (ni la courante ni la suivante) ne fait jamais relire la cle
// reseau. La cle reseau ne passe que par la pile de cette fonction, effacee.
bool fournir(void *, uint32_t sequence, uint8_t cle[mle::kCle]) {
  if (sCles.trouver(sequence, cle)) return true;
  uint32_t courante = 0;
  if (sAcces.sequence == nullptr || !sAcces.sequence(&courante)) return false;
  if (sCles.preparees() && courante == sCles.courante()) return false;
  uint8_t reseau[mle::kCle];
  const bool lue = sAcces.cleReseau != nullptr && sAcces.cleReseau(reseau);
  const bool preparees = lue && sCles.preparer(courante, reseau);
  mle::effacer(reseau, sizeof(reseau));
  return preparees && sCles.trouver(sequence, cle);
}

}  // namespace

void demarrer(otInstance *ot, const Acces &acces) {
  sAcces = acces;
  if (sFile == nullptr) sFile = xQueueCreate(kFile, sizeof(Trame));
  otLinkSetPcapCallback(ot, surTrame, nullptr);
}

void tour(uint32_t maintenant) {
  for (uint8_t k = 0; k < kFile && sFile != nullptr && xQueueReceive(sFile, &sTrameLoop, 0) == pdTRUE; k++) {
    mle::Message m;
    switch (mle::decoder(sTrameLoop.psdu, sTrameLoop.n, fournir, nullptr, &m)) {
      case mle::Issue::Dechiffree:
        sMle++;
        sEntendus.noter(m, sTrameLoop.rssi, maintenant);
        break;
      case mle::Issue::Echec:
        sEchecs++;
        break;
      case mle::Issue::Ignoree:
        break;
    }
  }
  sEntendus.oublier(maintenant);
}

Compteurs compteurs() {
  return {sTrames.load(std::memory_order_relaxed), sMle, sEchecs, sFilePleine.load(std::memory_order_relaxed)};
}

const mle::TableEntendus &entendus() { return sEntendus; }

}  // namespace ecoute
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
// ===========================================================================
//  Sonde de maillage Thread, firmware 1.0.3 (spec de la sonde, sections 2 et
//  3 ; contrat de la 1.0.2 : FED, routeurs, acces reseau comme le pont Halo ;
//  1.0.3 : LED, retour allume apres oubli, refus de la cadence comptes)
//
//  Noeud Matter sur Thread, en FED non eligible routeur (Full End Device) :
```

par :

```cpp
// ===========================================================================
//  Sonde de maillage Thread, firmware 1.1.0 (spec de la sonde, sections 2 et
//  3 ; contrat de la 1.0.2 : FED, routeurs, acces reseau comme le pont Halo ;
//  1.0.3 : LED, retour allume apres oubli, refus de la cadence comptes ;
//  1.1.0 : ecoute des messages MLE et resolution d'adresse, spec de la sonde
//  tout-en-un, section 1)
//
//  Noeud Matter sur Thread, en FED non eligible routeur (Full End Device) :
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
//  sur le port CoAP de la sonde ; ses TLV partent en hexa, sans decodage :
//  c'est l'app qui decode. Jusqu'a 8 requetes en vol, reperees par leur id.
//
//  USB : une commande par ligne ; chaque reponse est une ligne machine,
```

par :

```cpp
//  sur le port CoAP de la sonde ; ses TLV partent en hexa, sans decodage :
//  c'est l'app qui decode. Jusqu'a 8 requetes en vol, reperees par leur id.
//
//  Depuis la 1.1.0, la sonde ecoute aussi les messages MLE de ses voisins a un
//  saut (ecoute.h) : elle les dechiffre avec la cle MLE, derivee de la cle
//  reseau, et garde, par routeur entendu, sa derniere Route64 brute (c'est
//  l'app qui la decode), son signal et l'age du dernier message. La cle reseau
//  ne sort jamais de la carte et n'est lue que le temps d'une derivation.
//
//  USB : une commande par ligne ; chaque reponse est une ligne machine,
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
//                                     decimal, sinon « syntaxe » ; delai de
//                                     3 a 60 s, 45 s par defaut
//    cle                              empreinte de la cle d'acces reseau
//                                     (null sans cle), effacement_en_echec,
```

par :

```cpp
//                                     decimal, sinon « syntaxe » ; delai de
//                                     3 a 60 s, 45 s par defaut
//    annonces                         routeurs entendus (1.1.0) : une ligne
//                                     par routeur ("suite":true sauf sur la
//                                     derniere), ou une ligne "vide":true
//    resoudre <ipv6> <id>             resolution d'adresse (1.1.0) : demande
//                                     d'echo ICMPv6, puis le cache d'adresses
//                                     toutes les 250 ms, 15 s au plus ;
//                                     rloc16 et mleid, ou « introuvable »
//    cle                              empreinte de la cle d'acces reseau
//                                     (null sans cle), effacement_en_echec,
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
//  "<rid> <ligne JSON>" (la ligne de l'USB sans RS ni LF), 1100 octets au
//  plus. Permis : bonjour (sans code ni QR code), etat, voisins, routeurs,
//  diag ; le reste : erreur « refuse ». Un rid repete ne relance rien (les 8
//  dernieres reponses, dans la limite de 4096 octets par session) ; 20
//  commandes par seconde et par session au plus (au-dela, rien, et le refus
```

par :

```cpp
//  "<rid> <ligne JSON>" (la ligne de l'USB sans RS ni LF), 1100 octets au
//  plus. Permis : bonjour (sans code ni QR code), etat, voisins, routeurs,
//  diag, annonces, resoudre ; le reste : erreur « refuse ». Un rid repete ne relance rien (les 8
//  dernieres reponses, dans la limite de 4096 octets par session) ; 20
//  commandes par seconde et par session au plus (au-dela, rien, et le refus
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
#include <esp_system.h>
#include <openthread/coap.h>
#include <openthread/ip6.h>
#include <openthread/link.h>
```

par :

```cpp
#include <esp_system.h>
#include <openthread/coap.h>
#include <openthread/icmp6.h>
#include <openthread/ip6.h>
#include <openthread/link.h>
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp

#include "distant.h"
#include "h1_proto.h"
#include "reseau.h"
#include "voyant.h"

static const char *const kVersion = "1.0.3";

// ---------------------------------------------------------------------------
```

par :

```cpp

#include "distant.h"
#include "ecoute.h"
#include "h1_proto.h"
#include "reseau.h"
#include "voyant.h"

static const char *const kVersion = "1.1.0";

// ---------------------------------------------------------------------------
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
bool reseauVerrouEssai() { return verrouOt(0); }
void reseauVerrouLibere() { libereOt(); }

// ---------------------------------------------------------------------------
```

par :

```cpp
bool reseauVerrouEssai() { return verrouOt(0); }
void reseauVerrouLibere() { libereOt(); }

// Pour ecoute.cpp (1.1.0) : la sequence de cle courante de la pile, et la cle
// reseau, le temps d'en deriver les cles MLE. La copie d'OpenThread est
// effacee ici ; l'appelant efface la sienne. Jamais imprimee, jamais rendue
// par une commande.
static bool lireSequenceCle(uint32_t *courante) {
  if (!verrouOt(50)) return false;
  *courante = otThreadGetKeySequenceCounter(esp_openthread_get_instance());
  libereOt();
  return true;
}

static bool lireCleReseau(uint8_t cle[mle::kCle]) {
  if (!verrouOt(50)) return false;
  otNetworkKey k;
  otThreadGetNetworkKey(esp_openthread_get_instance(), &k);
  libereOt();
  memcpy(cle, k.m8, mle::kCle);
  h1::wipe(&k, sizeof(k));
  return true;
}

// ---------------------------------------------------------------------------
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
  sThreadPret = chip::DeviceLayer::ThreadStackMgrImpl().OTInstance() != nullptr;
  if (!sThreadPret) Serial.println("!! pile Thread absente");
  // Comme l'exemple officiel : l'etat relu passe par le rappel une fois Matter demarre.
  sInterrupteur.updateAccessory();
```

par :

```cpp
  sThreadPret = chip::DeviceLayer::ThreadStackMgrImpl().OTInstance() != nullptr;
  if (!sThreadPret) Serial.println("!! pile Thread absente");
  // Ecoute des messages MLE (1.1.0) : le rappel des trames, des que la pile
  // existe. Verrou OT sans limite, comme imposerFed ; aucun appel CHIP dessous.
  if (sThreadPret) {
    esp_openthread_lock_acquire(portMAX_DELAY);
    ecoute::demarrer(esp_openthread_get_instance(), {lireSequenceCle, lireCleReseau});
    esp_openthread_lock_release();
  }
  // Comme l'exemple officiel : l'etat relu passe par le rappel une fois Matter demarre.
  sInterrupteur.updateAccessory();
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
  libereOt();
  ajoute(",\"suspendue\":%s", sSuspendue ? "true" : "false");
  fin();
}
```

par :

```cpp
  libereOt();
  ajoute(",\"suspendue\":%s", sSuspendue ? "true" : "false");
  // Ecoute des messages MLE (1.1.0), depuis le demarrage.
  const ecoute::Compteurs c = ecoute::compteurs();
  ajoute(",\"ecoute\":{\"trames\":%lu,\"mle\":%lu,\"echecs\":%lu,\"file_pleine\":%lu}", (unsigned long)c.trames,
         (unsigned long)c.mle, (unsigned long)c.echecs, (unsigned long)c.filePleine);
  fin();
}
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp

// ---------------------------------------------------------------------------
//  Cle d'acces reseau (USB seulement)
// ---------------------------------------------------------------------------
```

par :

```cpp

// ---------------------------------------------------------------------------
//  annonces : routeurs entendus (1.1.0, ecoute.h)
// ---------------------------------------------------------------------------

// Une ligne par routeur entendu, "suite":true sur toutes sauf la derniere
// ("suite":false) ; sans routeur, une seule ligne "vide":true. Champs : rloc16,
// ext, partition (Leader Data ; null sans elle), route64 (derniere Route64
// brute, en hexa ; null sans elle), seq (sa sequence), rssi (dernier message),
// rssi_min et rssi_max (depuis l'entree dans la table), nb (messages
// dechiffres), age_s (depuis le dernier). Une ligne fait moins de 400 octets :
// elle passe par le reseau (1100 au plus). Ni la cle reseau ni une cle
// derivee : seulement ce que les routeurs annoncent a leurs voisins.
static void cmdAnnonces() {
  const mle::TableEntendus &t = ecoute::entendus();
  const uint32_t maintenant = millis();
  size_t restants = t.nombre();
  if (restants == 0) {
    debut("annonces");
    ajoute(",\"vide\":true");
    fin();
    return;
  }
  for (size_t k = 0; k < mle::TableEntendus::kPlaces; k++) {
    const mle::Entendu &e = t.place(k);
    if (!e.utilise) continue;
    restants--;
    debut("annonces");
    ajoute(",\"rloc16\":\"%04X\"", e.rloc16);
    hexa("ext", e.ext, sizeof(e.ext));
    if (e.aPartition) ajoute(",\"partition\":\"%08lX\"", (unsigned long)e.partition);
    else ajoute(",\"partition\":null");
    if (e.nRoute64) {
      hexa("route64", e.route64, e.nRoute64);
      ajoute(",\"seq\":%u", e.route64[0]);
    } else {
      ajoute(",\"route64\":null,\"seq\":null");
    }
    ajoute(",\"rssi\":%d,\"rssi_min\":%d,\"rssi_max\":%d,\"nb\":%lu,\"age_s\":%lu", e.rssi, e.rssiMin, e.rssiMax,
           (unsigned long)e.nb, (unsigned long)((maintenant - e.dernier) / 1000));
    ajoute(",\"suite\":%s", restants ? "true" : "false");
    fin();
  }
}

// ---------------------------------------------------------------------------
//  resoudre : resolution d'adresse (1.1.0), 8 en vol
// ---------------------------------------------------------------------------

// Une demande d'echo ICMPv6 vers l'adresse fait resoudre celle-ci par
// OpenThread (Address Query) : un routeur repond pour lui-meme, ou le parent
// pour son enfant, endormi ou non. Le cache d'adresses donne ensuite le RLOC16
// trouve (celui du parent, ou de l'enfant, selon le routeur), et le ML-EID de
// la cible quand la reponse l'a porte. loop() lit le cache toutes les 250 ms,
// 15 s au plus.
static constexpr uint32_t kResolutionMs = 15000, kPasCacheMs = 250;

// Un emplacement par resolution en vol, dans la tache loop seulement.
struct Resolution {
  bool enVol = false;
  bool finie = false;    // trouvee ou echue : la reponse attend son depart
  bool trouvee = false;
  uint32_t id = 0;
  char cible[48] = {};
  otIp6Address adresse = {};
  uint32_t debutMs = 0, prochainMs = 0, finMs = 0;
  uint16_t rloc16 = 0;
  bool mleidValide = false;
  otIp6Address mleid = {};
  Sortie sortie;  // qui attend la reponse : l'USB, ou une session reseau et son rid
};
static Resolution sResolutions[kEnVol];

static void repondreResolutionErreur(uint32_t id, const char *cible, const char *erreur) {
  debut("resoudre");
  ajoute(",\"id\":%lu,\"cible\":\"%s\",\"ok\":false,\"erreur\":\"%s\"", (unsigned long)id, cible, erreur);
  fin();
}

// resoudre <ipv6> <id>. id en decimal (distant::lireEntier) ; adresse mal
// formee (pas une IPv6, ou un autre caractere que l'hexa, ':' et '.') :
// « syntaxe », avec l'id s'il a pu etre lu (0 sinon). Puis « suspendue »,
// « occupee » (8 en vol, ou verrou OT refuse) ou « envoi ... ».
static void cmdResoudre(char *args) {
  char *cible = strtok(args, " ");
  char *idTexte = strtok(nullptr, " ");
  char *reste = strtok(nullptr, " ");
  uint32_t id = 0;
  const bool idLu = idTexte && distant::lireEntier(idTexte, &id);
  otIp6Address adresse;
  if (!cible || !idLu || reste || strlen(cible) >= sizeof(sResolutions[0].cible) ||
      strspn(cible, kCaracteresCible) != strlen(cible) || otIp6AddressFromString(cible, &adresse) != OT_ERROR_NONE)
    return repondreResolutionErreur(id, "", "syntaxe");
  if (sSuspendue) return repondreResolutionErreur(id, cible, "suspendue");
  size_t libre = kEnVol;
  for (size_t i = 0; i < kEnVol; i++)
    if (!sResolutions[i].enVol) {
      libre = i;
      break;
    }
  if (libre == kEnVol || !verrouOt(500)) return repondreResolutionErreur(id, cible, "occupee");
  otInstance *ot = esp_openthread_get_instance();
  otMessage *msg = otIp6NewMessage(ot, nullptr);
  otError e = msg ? OT_ERROR_NONE : OT_ERROR_NO_BUFS;
  if (msg) {
    otMessageInfo info;
    memset(&info, 0, sizeof(info));
    info.mPeerAddr = adresse;
    e = otIcmp6SendEchoRequest(ot, msg, &info, (uint16_t)id);
    if (e != OT_ERROR_NONE) otMessageFree(msg);  // refuse : il nous reste
  }
  libereOt();
  if (e != OT_ERROR_NONE) {
    char texte[24];
    snprintf(texte, sizeof(texte), "envoi %s", otThreadErrorToString(e));
    return repondreResolutionErreur(id, cible, texte);
  }
  Resolution &r = sResolutions[libre];
  r = Resolution();
  r.id = id;
  snprintf(r.cible, sizeof(r.cible), "%s", cible);
  r.adresse = adresse;
  r.debutMs = millis();
  r.prochainMs = r.debutMs + kPasCacheMs;
  r.sortie = sSortie;
  r.enVol = true;
}

// Le cache d'adresses, toutes les 250 ms, pour les resolutions en vol : une
// entree resolue (ou vue passer) de leur adresse donne le RLOC16 et, s'il est
// connu, le ML-EID. 15 s sans elle : introuvable. Verrou OT occupe : au tour
// suivant.
static void resolutionsTour(uint32_t maintenant) {
  bool due = false;
  for (const Resolution &r : sResolutions)
    due = due || (r.enVol && !r.finie && (int32_t)(maintenant - r.prochainMs) >= 0);
  if (!due || !verrouOt(50)) return;
  otInstance *ot = esp_openthread_get_instance();
  otCacheEntryIterator it;
  memset(&it, 0, sizeof(it));
  otCacheEntryInfo info;
  while (otThreadGetNextCacheEntry(ot, &info, &it) == OT_ERROR_NONE) {
    if (info.mState != OT_CACHE_ENTRY_STATE_CACHED && info.mState != OT_CACHE_ENTRY_STATE_SNOOPED) continue;
    for (Resolution &r : sResolutions) {
      if (!r.enVol || r.finie || r.trouvee || memcmp(&info.mTarget, &r.adresse, sizeof(r.adresse))) continue;
      r.trouvee = true;
      r.rloc16 = info.mRloc16;
      r.mleidValide = info.mValidLastTrans;
      if (r.mleidValide) r.mleid = info.mMeshLocalEid;
      r.finMs = maintenant;
    }
  }
  libereOt();
  for (Resolution &r : sResolutions) {
    if (!r.enVol || r.finie || (int32_t)(maintenant - r.prochainMs) < 0) continue;
    if (r.trouvee || maintenant - r.debutMs >= kResolutionMs) r.finie = true;
    else r.prochainMs = maintenant + kPasCacheMs;
  }
}

// {"v":1,"t":"resoudre","id":7,"cible":"<ipv6>","ok":true,"ms":340,"rloc16":"AC00","mleid":"<32 HEXA>"|null}, ou
// "ok":false et "erreur":"introuvable".
static void imprimerResolution(const Resolution &r) {
  debut("resoudre");
  ajoute(",\"id\":%lu,\"cible\":\"%s\"", (unsigned long)r.id, r.cible);
  if (r.trouvee) {
    ajoute(",\"ok\":true,\"ms\":%lu,\"rloc16\":\"%04X\"", (unsigned long)(r.finMs - r.debutMs), r.rloc16);
    if (r.mleidValide) hexa("mleid", r.mleid.mFields.m8, sizeof(r.mleid.mFields.m8));
    else ajoute(",\"mleid\":null");
  } else {
    ajoute(",\"ok\":false,\"erreur\":\"introuvable\"");
  }
  fin();
}

// Reponses pretes, comme celles d'un diag : pour une session reseau partie
// entre-temps, la reponse tombe ; sinon elle attend une place dans la file
// d'emission, puis elle est gardee pour un rid repete.
static void resolutionsFinies() {
  for (Resolution &r : sResolutions) {
    if (!r.enVol || !r.finie) continue;
    if (r.sortie.reseau) {
      if (!reseauSessionActive(r.sortie.place, r.sortie.generation)) {
        r = Resolution();
        continue;
      }
      if (!reseauPlacesLibres()) continue;
      sGardees[r.sortie.place].commencer(r.sortie.rid);
    }
    sSortie = r.sortie;
    imprimerResolution(r);
    sSortie = Sortie();
    if (r.sortie.reseau) sGardees[r.sortie.place].terminer();
    r = Resolution();
  }
}

// ---------------------------------------------------------------------------
//  Cle d'acces reseau (USB seulement)
// ---------------------------------------------------------------------------
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
// "<rid> <commande>" d'une session etablie. Sans rid lisible, aucune reponse
// possible : ignoree. Un rid deja servi ne relance rien : la reponse gardee
// repart, ou rien si un diag de ce rid est encore en vol. Puis la cadence,
// comme Halo apres l'id (benq cli.cpp) : plus de 20 commandes dans la seconde,
// rien, sans reponse (l'app renvoie), mais le refus est compte
```

par :

```cpp
// "<rid> <commande>" d'une session etablie. Sans rid lisible, aucune reponse
// possible : ignoree. Un rid deja servi ne relance rien : la reponse gardee
// repart, ou rien si un diag ou une resolution de ce rid est encore en vol. Puis la cadence,
// comme Halo apres l'id (benq cli.cpp) : plus de 20 commandes dans la seconde,
// rien, sans reponse (l'app renvoie), mais le refus est compte
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
  const uint32_t generation = reseauGeneration(place);
  for (const Requete &r : sRequetes)
    if (r.enVol && r.sortie.reseau && r.sortie.place == place && r.sortie.generation == generation &&
        r.sortie.rid == rid)
```

par :

```cpp
  const uint32_t generation = reseauGeneration(place);
  for (const Requete &r : sRequetes)
    if (r.enVol && r.sortie.reseau && r.sortie.place == place && r.sortie.generation == generation &&
        r.sortie.rid == rid)
      return;
  for (const Resolution &r : sResolutions)
    if (r.enVol && r.sortie.reseau && r.sortie.place == place && r.sortie.generation == generation &&
        r.sortie.rid == rid)
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
  if (!strcmp(c, "routeurs")) return cmdRouteurs();
  if (!strncmp(c, "diag ", 5)) return cmdDiag(c + 5);
  if (!strcmp(c, "cle") || !strncmp(c, "cle ", 4)) return cmdCle(c + 3);
  if (!strcmp(c, "oubli")) return cmdOubli();
```

par :

```cpp
  if (!strcmp(c, "routeurs")) return cmdRouteurs();
  if (!strncmp(c, "diag ", 5)) return cmdDiag(c + 5);
  if (!strcmp(c, "annonces")) return cmdAnnonces();
  if (!strncmp(c, "resoudre ", 9)) return cmdResoudre(c + 9);
  if (!strcmp(c, "cle") || !strncmp(c, "cle ", 4)) return cmdCle(c + 3);
  if (!strcmp(c, "oubli")) return cmdOubli();
```

Dans `sonde/src/main.cpp`, remplacer :

```cpp
  }
  diagsFinis();
  reseauTour();
  surveillerAppairage(millis());
```

par :

```cpp
  }
  diagsFinis();
  ecoute::tour(millis());
  resolutionsTour(millis());
  resolutionsFinies();
  reseauTour();
  surveillerAppairage(millis());
```

Dans `sonde/sonde_essai.py`, remplacer :

```python

Commandes : bonjour, etat, voisins, routeurs, "diag <cible> <t,t,...> <id>",
cle, "cle efface", "cle nouvelle", ecoute:<s> (lit <s> secondes sans rien
envoyer). Chaque ligne machine est ajoutee a la capture avec l'heure ; les
reponses diag et routeurs sont mises en forme a l'ecran. La cle n'est jamais
affichee ni capturee.

USB (<port> : celui que Djoko designe) : ouverture sure du C6 (comme benq
```

par :

```python

Commandes : bonjour, etat, voisins, routeurs, "diag <cible> <t,t,...> <id>",
annonces et "resoudre <ipv6> <id>" (firmware 1.1.0), cle, "cle efface",
"cle nouvelle", ecoute:<s> (lit <s> secondes sans rien envoyer). Chaque ligne
machine est ajoutee a la capture avec l'heure ; les reponses diag, routeurs,
annonces (avec les liens de chaque Route64) et resoudre sont mises en forme a
l'ecran. La cle n'est jamais affichee ni capturee.

USB (<port> : celui que Djoko designe) : ouverture sure du C6 (comme benq
```

Dans `sonde/sonde_essai.py`, remplacer :

```python
HEXA_16 = re.compile(r"[0-9A-Fa-f]{16,}")
CHAMP_CLE = re.compile(r'("cle"\s*:\s*")[0-9A-Fa-f]+')
TYPES_DONNEES = frozenset({"bonjour", "etat", "voisins", "routeurs", "diag", "erreur", "oubli"})


```

par :

```python
HEXA_16 = re.compile(r"[0-9A-Fa-f]{16,}")
CHAMP_CLE = re.compile(r'("cle"\s*:\s*")[0-9A-Fa-f]+')
TYPES_DONNEES = frozenset({"bonjour", "etat", "voisins", "routeurs", "diag", "erreur", "oubli", "annonces", "resoudre"})


```

Dans `sonde/sonde_essai.py`, remplacer :

```python


def afficher(m):
    m = sans_cle(m)
    if m.get("t") == "diag" and m.get("ok") and "tlv" in m:
        print(f"<< diag {m['cible']} : {m['ms']} ms, code {m.get('code')}, {len(m['tlv']) // 2} octets")
        for ligne in decoder(m["tlv"]):
```

par :

```python


def liens_route64(hexa):
    """Liens d'une Route64 brute (annonces, 1.1.0) : (identifiant, qualite sortante, entrante), voisins seulement."""
    try:
        v = bytes.fromhex(hexa)
    except (TypeError, ValueError):
        return []
    if len(v) < 9:
        return []
    masque = int.from_bytes(v[1:9], "big")
    ids = [r for r in range(64) if masque & (1 << (63 - r))]
    return [(r, b >> 6, (b >> 4) & 3) for r, b in zip(ids, v[9:]) if b >> 4]


def afficher(m):
    m = sans_cle(m)
    if m.get("t") == "annonces" and m.get("vide"):
        print("<< annonces : aucun routeur entendu")
    elif m.get("t") == "annonces" and "rloc16" in m:
        print(f"<< annonces {m['rloc16']} ext {m.get('ext')} partition {m.get('partition') or '-'} rssi {m.get('rssi')}"
              f" ({m.get('rssi_min')}..{m.get('rssi_max')}) {m.get('nb')} msg il y a {m.get('age_s')} s")
        liens = liens_route64(m.get("route64") or "")
        print("      liens : " + (", ".join(f"{r << 10:04X} {so}/{en}" for r, so, en in liens) or "-"))
    elif m.get("t") == "resoudre" and m.get("ok"):
        rloc = int(m["rloc16"], 16)
        mleid = str(ipaddress.IPv6Address(bytes.fromhex(m["mleid"]))) if m.get("mleid") else "inconnu"
        print(f"<< resoudre {m['cible']} : {m['rloc16']} (parent {rloc & 0xFC00:04X}), {m.get('ms')} ms, ML-EID {mleid}")
    elif m.get("t") == "resoudre":
        print(f"<< resoudre {m.get('cible')} : {m.get('erreur')}")
    elif m.get("t") == "diag" and m.get("ok") and "tlv" in m:
        print(f"<< diag {m['cible']} : {m['ms']} ms, code {m.get('code')}, {len(m['tlv']) // 2} octets")
        for ligne in decoder(m["tlv"]):
```

Dans `sonde/sonde_essai.py`, remplacer :

```python

def attente(c):
    """Type de la ligne qui termine la reponse a c, et l'id d'un diag."""
    mots = c.split()
    attendu = mots[0] if mots else ""
    diag_id = None
    if attendu == "diag" and len(mots) >= 4 and mots[3].isdigit():
        diag_id = int(mots[3])
    return attendu, diag_id


def fin_de_reponse(m, attendu, diag_id):
    # routeurs : "suite":true sur chaque ligne sauf la derniere.
    if m.get("t") == "erreur":
        return True
    return m.get("t") == attendu and not m.get("suite") and (attendu != "diag" or m.get("id") == diag_id)


```

par :

```python

def attente(c):
    """Type de la ligne qui termine la reponse a c, et l'id d'un diag ou d'une resolution."""
    mots = c.split()
    attendu = mots[0] if mots else ""
    ident = None
    if attendu == "diag" and len(mots) >= 4 and mots[3].isdigit():
        ident = int(mots[3])
    if attendu == "resoudre" and len(mots) >= 3 and mots[2].isdigit():
        ident = int(mots[2])
    return attendu, ident


def delai_reponse(c):
    """Attente de la reponse a c, en secondes : un diag, son delai (45 s par defaut) plus 5 s ; une resolution, ses
    15 s plus 5 s ; le reste, 6 s."""
    mots = c.split()
    if mots[:1] == ["diag"]:
        return (int(mots[4]) / 1000 if len(mots) >= 5 and mots[4].isdigit() else 45) + 5
    if mots[:1] == ["resoudre"]:
        return 15 + 5
    return 6


def fin_de_reponse(m, attendu, ident):
    # routeurs, annonces : "suite":true sur chaque ligne sauf la derniere.
    if m.get("t") == "erreur":
        return True
    return (m.get("t") == attendu and not m.get("suite")
            and (attendu not in ("diag", "resoudre") or m.get("id") == ident))


```

Dans `sonde/sonde_essai.py`, remplacer :

```python
            os.write(fd, (c + "\n").encode("ascii"))
            attendu, diag_id = attente(c)
            delai = 50 if attendu == "diag" else 5
            for m in lecteur.lignes(time.time() + delai):
                afficher(m)
                if fin_de_reponse(m, attendu, diag_id):
```

par :

```python
            os.write(fd, (c + "\n").encode("ascii"))
            attendu, diag_id = attente(c)
            for m in lecteur.lignes(time.time() + delai_reponse(c)):
                afficher(m)
                if fin_de_reponse(m, attendu, diag_id):
```

Dans `sonde/sonde_essai.py`, remplacer :

```python
            rid += 1
            attendu, diag_id = attente(c)
            mots = c.split()
            delai_diag = int(mots[4]) / 1000 if attendu == "diag" and len(mots) >= 5 and mots[4].isdigit() else 45
            limite = delai_diag + 5 if attendu == "diag" else 6
            print(f">> {rid} {c}")
            session.envoyer(f"{rid} {c}".encode("ascii"))
```

par :

```python
            rid += 1
            attendu, diag_id = attente(c)
            limite = delai_reponse(c)
            print(f">> {rid} {c}")
            session.envoyer(f"{rid} {c}".encode("ascii"))
```

Dans `sonde/platformio.ini`, remplacer :

```ini
; Sonde de maillage Thread, firmware 1.0.3 (spec :
; docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md ; 1.0.2 :
; FED, commande routeurs, acces reseau comme le pont Halo de benq ; 1.0.3 :
; LED de la carte, retour allume apres oubli, refus de la cadence comptes).
; ESP32-C6 SuperMini, noeud Matter sur Thread en FED non eligible routeur
; (appaire a Maison par Bluetooth), requetes de diagnostic Thread (DIAG_GET)
```

par :

```ini
; Sonde de maillage Thread, firmware 1.1.0 (spec :
; docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md ; 1.0.2 :
; FED, commande routeurs, acces reseau comme le pont Halo de benq ; 1.0.3 :
; LED de la carte, retour allume apres oubli, refus de la cadence comptes ;
; 1.1.0 : ecoute des messages MLE, commandes annonces et resoudre, spec
; docs/superpowers/specs/2026-10-07-sonde-tout-en-un-design.md).
; ESP32-C6 SuperMini, noeud Matter sur Thread en FED non eligible routeur
; (appaire a Maison par Bluetooth), requetes de diagnostic Thread (DIAG_GET)
```

- [ ] **Step 4 : les voir passer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && sh sonde/test/lancer.sh && /usr/bin/python3 -m unittest discover -s sonde/test 2>&1 | tail -3`

Expected : `test_h1 : 121 verification(s), 0 echec(s)` ; `test_distant : 154 verification(s), 0 echec(s)` ; `test_mle : 72874 verification(s), 0 echec(s)` ; `Ran 146 tests`, `OK`.

- [ ] **Step 5 : la compilation du firmware.** Aucun port : `pio run`, sans `-t`.

Run : `W=$S/sonde-tout-en-un-exec; C=$HOME/Library/Caches/sonde-tout-en-un-exec; cd "$W/maillage/sonde" && ~/.platformio/penv/bin/pio run > "$C/pio.log" 2>&1; echo "code $?"; grep -E "^(RAM|Flash):|SUCCESS|FAILED" "$C/pio.log"; grep -E "^src/[^:]+:[0-9]+:[0-9]+: (warning|error)" "$C/pio.log" | wc -l`

Expected : `code 0` ; `RAM:   [=====     ]  53.1% (used 174032 bytes from 327680 bytes)` ; `Flash: [========  ]  76.5% (used 2407214 bytes from 3145728 bytes)` ; `[SUCCESS]` ; `0` (aucun avertissement ni erreur dans `sonde/src/`). Une demi-minute dans un worktree neuf, au rejeu ; quelques secondes ensuite.

- [ ] **Step 6 : le README de la sonde** (`--etapes 6`) : l'écoute, la résolution, les commandes, la liste blanche, les tests.

Dans `sonde/README.md`, remplacer :

```markdown
commande `routeurs`.

Spec : `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`.

## Compiler et flasher
```

par :

```markdown
commande `routeurs`.

Depuis la 1.1.0, la sonde **écoute aussi les messages MLE** de ses voisins à
un saut (voir « Écoute des messages MLE ») : les annonces des routeurs portent
leur Route64, leurs liens dans les deux sens, même pour les routeurs de
bordure d'Apple, qui ne répondent pas au diagnostic. Et elle **résout
l'adresse** d'un appareil (`resoudre`) : OpenThread demande au réseau qui la
porte, et le parent d'un enfant endormi répond à sa place.

Spec : `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md` ;
pour la 1.1.0, `docs/superpowers/specs/2026-10-07-sonde-tout-en-un-design.md`.

## Compiler et flasher
```

Dans `sonde/README.md`, remplacer :

```markdown
effacement (`-t upload` seul) : l'appairage Maison, le réseau Thread, le nom
et la clé d'accès réseau sont gardés. De la 1.0.1 à la 1.0.2, la sonde passe
de MED (`rn`) à FED (`rdn`) au démarrage et se rattache.

**Toujours désigner le port de la sonde.** Le pont Halo de benq est lui
```

par :

```markdown
effacement (`-t upload` seul) : l'appairage Maison, le réseau Thread, le nom
et la clé d'accès réseau sont gardés. De la 1.0.1 à la 1.0.2, la sonde passe
de MED (`rn`) à FED (`rdn`) au démarrage et se rattache. De la 1.0.3 à la
1.1.0, rien ne change de ce qui est gardé ; place à la compilation : 76,5 % de
la flash et 53,1 % de la RAM.

**Toujours désigner le port de la sonde.** Le pont Halo de benq est lui
```

Dans `sonde/README.md`, remplacer :

```markdown
| `routeurs` | table des routeurs d'OpenThread : `{"v":1,"t":"routeurs","liste":[{"id":…,"rloc16":"XXXX","ext":"<16 hexa>"\|null,"lqIn":…,"lqOut":…,"age":…,"lien":…}],"suite":…}`, plusieurs lignes si besoin (`"suite":true` sur toutes sauf la dernière) |
| `diag <cible> <t,t,…> <id> [<délai ms>]` | TLV de la réponse en hexa, ou l'erreur : `delai`, `suspendue`, `occupee` (8 requêtes en vol), `envoi…` |
| `cle` | `{"v":1,"t":"cle","empreinte":"<8 hexa>"\|null,…}`, avec `effacement_en_echec`, le nom d'hôte, les compteurs du transport (`udp`, dont `lignes_perdues` et `refus_cadence`) et le tas (`tas`) |
| `cle efface` | efface la clé (plus d'accès réseau) ; la réponse de `cle`, ou l'erreur `ecriture` |
```

par :

```markdown
| `routeurs` | table des routeurs d'OpenThread : `{"v":1,"t":"routeurs","liste":[{"id":…,"rloc16":"XXXX","ext":"<16 hexa>"\|null,"lqIn":…,"lqOut":…,"age":…,"lien":…}],"suite":…}`, plusieurs lignes si besoin (`"suite":true` sur toutes sauf la dernière) |
| `diag <cible> <t,t,…> <id> [<délai ms>]` | TLV de la réponse en hexa, ou l'erreur : `delai`, `suspendue`, `occupee` (8 requêtes en vol), `envoi…` |
| `annonces` | (1.1.0) une ligne par routeur entendu : `{"v":1,"t":"annonces","rloc16":"XXXX","ext":"<16 hexa>","partition":"<8 hexa>"\|null,"route64":"<hexa>"\|null,"seq":…,"rssi":…,"rssi_min":…,"rssi_max":…,"nb":…,"age_s":…,"suite":…}` (`"suite":true` sur toutes sauf la dernière) ; sans routeur entendu, une seule ligne `{"v":1,"t":"annonces","vide":true}` |
| `resoudre <ipv6> <id>` | (1.1.0) `{"v":1,"t":"resoudre","id":…,"cible":"<ipv6>","ok":true,"ms":…,"rloc16":"XXXX","mleid":"<32 hexa>"\|null}`, ou l'erreur : `introuvable` (rien en 15 s), `syntaxe` (adresse mal formée), `suspendue`, `occupee` (8 résolutions en vol), `envoi…` |
| `cle` | `{"v":1,"t":"cle","empreinte":"<8 hexa>"\|null,…}`, avec `effacement_en_echec`, le nom d'hôte, les compteurs du transport (`udp`, dont `lignes_perdues` et `refus_cadence`) et le tas (`tas`) |
| `cle efface` | efface la clé (plus d'accès réseau) ; la réponse de `cle`, ou l'erreur `ecriture` |
```

Dans `sonde/README.md`, remplacer :

```markdown

`etat`, `voisins` et `routeurs` répondent `{"v":1,"t":"<commande>","erreur":"occupee"}`
si le verrou d'OpenThread n'a pas pu être pris (200 ms).

`<cible>` est un RLOC16 en 4 hexa, ou une adresse IPv6 du réseau maillé :
```

par :

```markdown

`etat`, `voisins` et `routeurs` répondent `{"v":1,"t":"<commande>","erreur":"occupee"}`
si le verrou d'OpenThread n'a pas pu être pris (200 ms). Depuis la 1.1.0,
`etat` porte aussi `ecoute` : `{"trames":…,"mle":…,"echecs":…,"file_pleine":…}`,
les trames reçues, les messages MLE déchiffrés, ceux qui ne l'ont pas été
(en-tête illisible, clé indisponible, MIC faux) et les trames perdues file
pleine, depuis le démarrage.

`<cible>` est un RLOC16 en 4 hexa, ou une adresse IPv6 du réseau maillé :
```

Dans `sonde/README.md`, remplacer :

```markdown
les autres au fil des minutes. L'entrée du parent n'a jamais d'ExtMac (voir
`etat`). `age` n'a de sens que pour un routeur entendu.

## Accès par le réseau Thread
```

par :

```markdown
les autres au fil des minutes. L'entrée du parent n'a jamais d'ExtMac (voir
`etat`). `age` n'a de sens que pour un routeur entendu.

## Écoute des messages MLE (1.1.0)

- **Les trames.** Au démarrage de la pile Thread, la sonde pose
  `otLinkSetPcapCallback` : OpenThread lui donne chaque trame reçue, sans mode
  promiscuité. Le rappel, dans la tâche OpenThread, ne fait qu'un tri (trames
  de données sans sécurité MAC) et une copie dans une file de 16 trames ; une
  file pleine est comptée, jamais bloquante ; ni verrou, ni Matter, ni CHIP.
  Le reste se fait dans `loop()`.
- **Le décodage** (`src/mle.h`, sans Arduino, testé sur le Mac) : en-tête
  802.15.4 aux formats 2003/2006 et 2015 (numéro de séquence supprimé, PAN
  selon le tableau 7-2, IE d'en-tête jusqu'à HT1 ou HT2), 6LoWPAN IPHC sans
  contexte, UDP vers le port MLE 19788, source lien-local.
- **Le déchiffrement** : suite de sécurité 0, contrôle `0x15` (niveau 5, clé
  en mode 2), compteur de trame petit-boutiste, séquence de clé gros-boutiste.
  La clé MLE est les 128 premiers bits de HMAC-SHA256(clé réseau, séquence ‖
  « Thread ») ; AES-CCM, MIC de 4 octets ; nonce : l'ExtMac de l'émetteur
  (tirée de son adresse lien-local), le compteur, le niveau ; données
  associées : les adresses IPv6 source et destination, puis les 10 octets de
  l'en-tête de sécurité. mbedTLS sur la carte (`src/mle_crypto.cpp`).
- **La clé réseau** ne quitte jamais la carte : lue sous le verrou
  d'OpenThread seulement pour dériver les clés MLE, quand la séquence de la
  pile change, puis effacée. Deux clés MLE sont gardées : la séquence courante
  et la suivante (rotation). Aucune commande ne rend ni la clé réseau ni une
  clé dérivée ; une séquence étrangère ne fait jamais relire la clé réseau.
- **La table des routeurs entendus**, par ExtMac, 32 entrées : RLOC16 (TLV
  Source Address), partition (TLV Leader Data), dernière Route64 brute (au
  plus 72 octets), signal (dernier, minimum et maximum depuis l'entrée),
  nombre de messages, âge du dernier. Seuls les émetteurs dont le RLOC16 est
  celui d'un routeur y entrent ; un routeur muet depuis 10 minutes en sort ;
  table pleine, le plus ancien laisse sa place. `annonces` la rend : c'est
  l'app qui décode les Route64.

## Résolution d'adresse (1.1.0)

`resoudre <ipv6> <id>` envoie une demande d'écho ICMPv6
(`otIcmp6SendEchoRequest`) : OpenThread résout l'adresse (Address Query). Un
routeur répond pour lui-même ; le parent d'un enfant, endormi ou non, répond à
sa place : les routeurs Apple avec leur propre RLOC16, les routeurs tiers avec
celui de l'enfant. La sonde lit ensuite son cache d'adresses
(`otThreadGetNextCacheEntry`) toutes les 250 ms, 15 s au plus : `rloc16`, et
`mleid` (le ML-EID de l'appareil) quand la réponse l'a porté. Au plus 8 en
vol, comme `diag`. Le diagnostic (`diag`) n'est accepté que sur les adresses
internes du réseau (RLOC, ML-EID) : c'est au ML-EID que l'app demande la TLV 9
(compteurs MAC) d'un enfant.

## Accès par le réseau Thread
```

Dans `sonde/README.md`, remplacer :

```markdown
  `{"v":1,"t":"erreur","erreur":"ligne trop longue"}` (entier sur l'USB).
- **Permis à distance** : `bonjour` (sans code d'appairage ni QR code :
  `null`), `etat`, `voisins`, `routeurs`, `diag`. Tout le reste répond
  `{"v":1,"t":"erreur","erreur":"refuse"}`.
- **Un rid répété** dans la même session ne relance rien : la sonde renvoie
  la réponse gardée (les 8 dernières réponses, dans la limite de 4096 octets
  par session ; au-delà, un rid répété relance la commande, une lecture), ou
  ne dit rien si un `diag` de ce rid est encore en vol. Prendre un rid neuf
  par requête.
- **Cadence** : 20 commandes par seconde glissante et par session au plus
  (comme Halo) ; au-delà, rien n'est exécuté ni répondu, l'app renvoie.
```

par :

```markdown
  `{"v":1,"t":"erreur","erreur":"ligne trop longue"}` (entier sur l'USB).
- **Permis à distance** : `bonjour` (sans code d'appairage ni QR code :
  `null`), `etat`, `voisins`, `routeurs`, `diag`, et depuis la 1.1.0
  `annonces` et `resoudre`. Tout le reste répond
  `{"v":1,"t":"erreur","erreur":"refuse"}`. Une ligne d'`annonces` fait moins
  de 400 octets.
- **Un rid répété** dans la même session ne relance rien : la sonde renvoie
  la réponse gardée (les 8 dernières réponses, dans la limite de 4096 octets
  par session ; au-delà, un rid répété relance la commande, une lecture), ou
  ne dit rien si un `diag` ou un `resoudre` de ce rid est encore en vol.
  Prendre un rid neuf par requête.
- **Cadence** : 20 commandes par seconde glissante et par session au plus
  (comme Halo) ; au-delà, rien n'est exécuté ni répondu, l'app renvoie.
```

Dans `sonde/README.md`, remplacer :

```markdown

- `sonde_essai.py <port> <capture.jsonl> <commande>…` : envoie des commandes
  par l'USB, garde les réponses, décode les TLV et la table des routeurs.
  `"cle nouvelle"` : l'outil tire l'aléa et range la clé dans le fichier
  `SONDE_CLE` (0600) ; il ne lit alors rien à l'écran de ce qui arrive. La
```

par :

```markdown

- `sonde_essai.py <port> <capture.jsonl> <commande>…` : envoie des commandes
  par l'USB, garde les réponses, décode les TLV et la table des routeurs ;
  depuis la 1.1.0, les annonces (les liens de chaque Route64) et les
  résolutions (`resoudre`, 20 s d'attente au plus).
  `"cle nouvelle"` : l'outil tire l'aléa et range la clé dans le fichier
  `SONDE_CLE` (0600) ; il ne lit alors rien à l'écran de ce qui arrive. La
```

Dans `sonde/README.md`, remplacer :

```markdown
de `voyant.h` (`test_distant.cpp` : rid, liste blanche, réponses gardées,
cadence ; depuis la 1.0.3, lecture des entiers, reprises CoAP d'un `diag` et
séquence de la LED).

`python3 -m unittest discover -s sonde/test` : les tests Python, sans carte ni
```

par :

```markdown
de `voyant.h` (`test_distant.cpp` : rid, liste blanche, réponses gardées,
cadence ; depuis la 1.0.3, lecture des entiers, reprises CoAP d'un `diag` et
séquence de la LED) ; depuis la 1.1.0, l'écoute (`test_mle.cpp` : dérivation
de la clé MLE, AES-CCM et refus d'un MIC faux, trames 802.15.4 de 2006 et de
2015, IE, PAN, IPHC, UDP compressé ou non, TLV, clés gardées, table des
routeurs entendus, trames tronquées, abîmées ou tirées au hasard). Ses
vecteurs (`test/vecteurs_mle.h`) viennent de `test/vecteurs_mle.py`, à clé et
adresses inventées, calculés à part (bibliothèque `cryptography`, présente
dans le Python de PlatformIO) :
`~/.platformio/penv/bin/python sonde/test/vecteurs_mle.py` les récrit,
`--verifier` les compare au fichier commité. Sur le Mac, CommonCrypto n'a pas
d'AES-CCM : le test le bâtit sur son AES-ECB.

`python3 -m unittest discover -s sonde/test` : les tests Python, sans carte ni
```

- [ ] **Step 7 : commit.**

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add sonde/README.md sonde/platformio.ini sonde/sonde_essai.py sonde/src/distant.cpp sonde/src/distant.h sonde/src/ecoute.cpp sonde/src/ecoute.h sonde/src/main.cpp sonde/test/test_distant.cpp sonde/test/test_sonde_essai.py && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --cached --name-only | sed "s|^|$PWD/|") && git commit -q -F - <<'EOF'
Ecouter les annonces MLE et resoudre les adresses sur la sonde : annonces, resoudre, etat.ecoute, firmware 1.1.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` ; `0`.

---

### Task 4: Les messages de la sonde 1.1.0, et la TLV 9, dans le cœur

**Files :**
- Modify : `MaillageCoeur/Maillage/ProtocoleSonde.swift`, `MaillageCoeur/Maillage/DiagnosticThread.swift`, `MaillageCoeurTests/ProtocoleSondeTests.swift`, `MaillageCoeurTests/DiagnosticThreadTests.swift` (blocs)

**Interfaces:**
- Consumes : le contrat de la tâche 3.
- Produces :
  - `TypeTLV.compteursMac` (9) ; `CompteursMac` : les 9 compteurs `UInt32` dans l'ordre de la spec Thread (`protocolesInconnus`, `erreursRecues`, `erreursEmises`, `unicastRecus`, `diffusionsRecues`, `rejetsRecus`, `unicastEmis`, `diffusionsEmises`, `rejetsEmis`), lus d'une valeur de 36 octets (sinon `nil`) ; `ReponseDiagnostic.compteursMac` ;
  - `CompteursEcoute` (`trames`, `mle`, `echecs`, `filePleine`, clé `file_pleine`) et `EtatSonde.ecoute` (`nil` avant la 1.1.0) ;
  - `AnnonceSonde` (`rloc16`, `ext`, `partition`, `route64`, `seq`, `rssi`, `rssiMin`, `rssiMax`, `nb`, `ageS` ; `rloc16Valeur`, `route64Decodee`) et `PartieAnnonces(liste:suite:)` ;
  - `ResultatResolution` (`id`, `cible`, `ok`, `ms`, `rloc16`, `mleid`, `erreur` ; `rloc16Valeur`, `adresseMleid`, `introuvable`) ;
  - `MessageSonde.annonces(PartieAnnonces)` et `.resoudre(ResultatResolution)` ; `CommandeSonde.diagAdresse(cible:tlv:id:delaiMs:)`, `.annonces` et `.resoudre(adresse:id:)`.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`).

Dans `MaillageCoeurTests/ProtocoleSondeTests.swift`, remplacer :

```swift
    }

    @Test func commandes() {
        #expect(CommandeSonde.bonjour.ligne == "bonjour\n")
```

par :

```swift
    }

    /// `etat` du firmware 1.1.0 : les compteurs de l'ecoute (`ecoute`) ; un firmware plus ancien n'en a pas.
    @Test func etatEcoute() throws {
        let base = #""v":1,"t":"etat","role":"child","rloc16":"AC09","ext":"E0000000000000FF","mode":"rdn","eligible":false,"parent":null,"partition":"1234ABCD","chef":20,"canal":25,"prefixeMaille":"FD00111122220C87","xp":"A0A1A2A3A4A5A6A7","suspendue":false"#
        guard case .etat(let e)? = MessageSonde.lire(Data(("{" + base + #","ecoute":{"trames":1200,"mle":340,"echecs":2,"file_pleine":1}}"#).utf8)),
              case .etat(let ancien)? = MessageSonde.lire(Data(("{" + base + "}").utf8)) else {
            Issue.record("etat 1.1.0 illisible")
            return
        }
        #expect(e.ecoute == CompteursEcoute(trames: 1200, mle: 340, echecs: 2, filePleine: 1))
        #expect(ancien.ecoute == nil, "firmware 1.0.3")
    }

    /// `annonces` (firmware 1.1.0) : une ligne par routeur entendu, `suite` sur chaque ligne sauf la derniere ;
    /// sans routeur entendu, une ligne `vide`. La Route64 brute se decode comme celle du diagnostic (valeurs
    /// inventees : la Route64 des routeurs 1, 20 et 43).
    @Test func annonces() throws {
        let route = "7A" + "4000080000100000" + "F10092"
        let ligne = #"{"v":1,"t":"annonces","rloc16":"5000","ext":"E000000000000A01","partition":"1234ABCD","route64":"\#(route)","seq":122,"rssi":-61,"rssi_min":-70,"rssi_max":-55,"nb":12,"age_s":7,"suite":true}"#
        guard case .annonces(let p)? = MessageSonde.lire(Data(ligne.utf8)) else {
            Issue.record("annonces illisible")
            return
        }
        #expect(p.suite)
        let a = try #require(p.liste.first)
        #expect(p.liste.count == 1)
        #expect(a == AnnonceSonde(rloc16: "5000", ext: "E000000000000A01", partition: "1234ABCD", route64: route, seq: 122,
                                  rssi: -61, rssiMin: -70, rssiMax: -55, nb: 12, ageS: 7))
        #expect(a.rloc16Valeur == 0x5000)
        let r64 = try #require(a.route64Decodee)
        #expect(r64.sequence == 0x7A && r64.routeurs == [1, 20, 43])
        #expect(r64.route(vers: 43) == RouteRouteur(idRouteur: 43, qualiteSortante: 2, qualiteEntrante: 1, cout: 2))
        let derniere = #"{"v":1,"t":"annonces","rloc16":"AC00","ext":"E000000000000C03","partition":null,"route64":null,"seq":null,"rssi":-80,"rssi_min":-80,"rssi_max":-80,"nb":1,"age_s":0,"suite":false}"#
        guard case .annonces(let fin)? = MessageSonde.lire(Data(derniere.utf8)) else {
            Issue.record("derniere annonce illisible")
            return
        }
        #expect(!fin.suite && fin.liste.first?.partition == nil && fin.liste.first?.route64Decodee == nil)
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"annonces","vide":true}"#.utf8))
                == .annonces(PartieAnnonces(liste: [], suite: false)))
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"annonces","rloc16":"5000"}"#.utf8)) == nil, "ni annonce lisible, ni vide")
        let abimee = AnnonceSonde(rloc16: "5000", ext: "E000000000000A01", partition: nil, route64: "7A40", seq: nil,
                                  rssi: -61, rssiMin: -61, rssiMax: -61, nb: 1, ageS: 0)
        #expect(abimee.route64Decodee == nil, "Route64 trop courte")
    }

    /// `resoudre` (firmware 1.1.0) : le RLOC16 trouve et le ML-EID (32 hexa) si le cache le donne ; ou
    /// `introuvable`, ou un refus (valeurs inventees).
    @Test func resoudre() throws {
        let ok = #"{"v":1,"t":"resoudre","id":7,"cible":"fd00:aaaa:bbbb:1::17","ok":true,"ms":340,"rloc16":"AC00","mleid":"FD00111122220C870000000000000017"}"#
        guard case .resoudre(let r)? = MessageSonde.lire(Data(ok.utf8)) else {
            Issue.record("resoudre illisible")
            return
        }
        #expect(r.ok && r.id == 7 && r.cible == "fd00:aaaa:bbbb:1::17" && r.ms == 340)
        #expect(r.rloc16Valeur == 0xAC00)
        #expect(r.adresseMleid == AdresseIPv6("fd00:1111:2222:c87::17"))
        #expect(!r.introuvable)
        let sansMleid = #"{"v":1,"t":"resoudre","id":8,"cible":"fd00:aaaa:bbbb:1::18","ok":true,"ms":90,"rloc16":"5003","mleid":null}"#
        guard case .resoudre(let s)? = MessageSonde.lire(Data(sansMleid.utf8)) else {
            Issue.record("resoudre sans ML-EID illisible")
            return
        }
        #expect(s.rloc16Valeur == 0x5003 && s.adresseMleid == nil)
        let introuvable = #"{"v":1,"t":"resoudre","id":9,"cible":"fd00:aaaa:bbbb:1::19","ok":false,"erreur":"introuvable"}"#
        guard case .resoudre(let i)? = MessageSonde.lire(Data(introuvable.utf8)) else {
            Issue.record("resoudre introuvable illisible")
            return
        }
        #expect(i.introuvable && i.rloc16Valeur == nil)
        #expect(ResultatResolution(id: 1, cible: "fd00::1", ok: false, erreur: "occupee").introuvable == false)
    }

    /// Commandes du firmware 1.1.0 : l'adresse IPv6 part sans zone, sous la forme courte (`AdresseIPv6`).
    @Test func commandesToutEnUn() throws {
        let a = try #require(AdresseIPv6("fd00:aaaa:bbbb:1::17%en0"))
        #expect(CommandeSonde.annonces.ligne == "annonces\n")
        #expect(CommandeSonde.resoudre(adresse: a, id: 7).ligne == "resoudre fd00:aaaa:bbbb:1::17 7\n")
        let mleid = try #require(AdresseIPv6("fd00:1111:2222:c87::17"))
        #expect(CommandeSonde.diagAdresse(cible: mleid, tlv: [9], id: 8, delaiMs: 8000).ligne
                == "diag fd00:1111:2222:c87::17 9 8 8000\n")
    }

    @Test func commandes() {
        #expect(CommandeSonde.bonjour.ligne == "bonjour\n")
```

Dans `MaillageCoeurTests/DiagnosticThreadTests.swift`, remplacer :

```swift
                                                  Array(complete.dropLast()))) == nil, "coupee apres une TLV entiere")
    }
}
```

par :

```swift
                                                  Array(complete.dropLast()))) == nil, "coupee apres une TLV entiere")
    }

    /// TLV 9, compteurs MAC (spec de la sonde tout-en-un, section 2.3) : neuf compteurs de 32 bits,
    /// gros-boutistes, dans l'ordre de la spec Thread. Un appareil endormi la rend (pas la TLV 4). Une autre
    /// longueur : ignoree (valeurs inventees).
    @Test func compteursMac() throws {
        let valeurs: [UInt32] = [1, 2, 37, 0x01020304, 5, 6, 4321, 8, 0xFFFFFFFF]
        let octets = valeurs.flatMap { v in (0..<4).map { UInt8(truncatingIfNeeded: v >> (24 - 8 * $0)) } }
        let r = try #require(ReponseDiagnostic(hexa: Self.hexa(Self.tlv(TypeTLV.compteursMac, octets))))
        let c = try #require(r.compteursMac)
        #expect(c == CompteursMac(protocolesInconnus: 1, erreursRecues: 2, erreursEmises: 37,
                                  unicastRecus: 0x01020304, diffusionsRecues: 5, rejetsRecus: 6, unicastEmis: 4321,
                                  diffusionsEmises: 8, rejetsEmis: 0xFFFFFFFF))
        let courte = try #require(ReponseDiagnostic(hexa: Self.hexa(Self.tlv(TypeTLV.compteursMac, Array(octets.dropLast())))))
        #expect(courte.compteursMac == nil, "35 octets")
        #expect(TypeTLV.compteursMac == 9)
    }
}
```

- [ ] **Step 2 : les voir échouer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh MaillageCoeurTests/ProtocoleSondeTests MaillageCoeurTests/DiagnosticThreadTests`

Expected : la compilation des tests échoue, `** TEST FAILED **` : `type 'TypeTLV' has no member 'compteursMac'`, `cannot find 'CompteursMac' in scope`, `cannot find 'CompteursEcoute' in scope`, `value of type 'EtatSonde' has no member 'ecoute'`, `type 'MessageSonde?' has no member 'annonces'`.

- [ ] **Step 3 : les messages et la TLV 9** (`--etapes 3`).

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
}

/// Reponse a `etat`.
public struct EtatSonde: Hashable, Sendable, Codable {
```

par :

```swift
}

/// Compteurs de l'ecoute des messages MLE (`etat.ecoute`, firmware 1.1.0), depuis le demarrage de la sonde.
public struct CompteursEcoute: Hashable, Sendable, Codable {
    /// Trames recues.
    public let trames: Int
    /// Messages MLE dechiffres.
    public let mle: Int
    /// Messages MLE chiffres non dechiffres : en-tete illisible, cle indisponible, MIC faux.
    public let echecs: Int
    /// Trames perdues, la file de la sonde pleine.
    public let filePleine: Int

    public init(trames: Int, mle: Int, echecs: Int, filePleine: Int) {
        self.trames = trames
        self.mle = mle
        self.echecs = echecs
        self.filePleine = filePleine
    }

    enum CodingKeys: String, CodingKey {
        case trames, mle, echecs
        case filePleine = "file_pleine"
    }
}

/// Reponse a `etat`.
public struct EtatSonde: Hashable, Sendable, Codable {
```

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
    public let xp: String?
    public let suspendue: Bool

    /// Attachee au reseau : enfant, routeur ou chef.
```

par :

```swift
    public let xp: String?
    public let suspendue: Bool
    /// Compteurs de l'ecoute (firmware 1.1.0) ; nil pour un firmware plus ancien.
    public let ecoute: CompteursEcoute?

    /// Attachee au reseau : enfant, routeur ou chef.
```

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
}

/// Reponse a `diag` : les TLV en hexa, ou l'erreur (`delai`, `suspendue`, `occupee`, `envoi`...).
public struct ResultatDiag: Hashable, Sendable, Codable {
```

par :

```swift
}

/// Routeur entendu par la sonde (`annonces`, firmware 1.1.0) : une ligne par routeur. La sonde dechiffre ses messages
/// MLE et garde sa derniere Route64, brute : l'app la decode (`route64Decodee`).
public struct AnnonceSonde: Hashable, Sendable, Codable {
    public let rloc16: String
    /// ExtMac de l'emetteur, 16 hexa.
    public let ext: String
    /// Partition de sa TLV Leader Data, 8 hexa ; nil sans elle.
    public let partition: String?
    /// Derniere Route64 brute (valeur de la TLV 9 du message MLE, en hexa) ; nil sans elle.
    public let route64: String?
    public let seq: Int?
    /// Signal du dernier message, et le plus faible et le plus fort depuis son entree dans la table, en dBm.
    public let rssi: Int
    public let rssiMin: Int
    public let rssiMax: Int
    /// Messages dechiffres.
    public let nb: Int
    /// Secondes depuis le dernier.
    public let ageS: Int

    enum CodingKeys: String, CodingKey {
        case rloc16, ext, partition, route64, seq, rssi, nb
        case rssiMin = "rssi_min"
        case rssiMax = "rssi_max"
        case ageS = "age_s"
    }

    public var rloc16Valeur: UInt16? { UInt16(rloc16, radix: 16) }

    /// La Route64 decodee comme celle du diagnostic (`ReponseDiagnostic.route64`) ; nil sans elle, ou illisible.
    public var route64Decodee: Route64? {
        route64.flatMap { Data(hexa: $0) }.flatMap { ReponseDiagnostic.route64([UInt8]($0)) }
    }
}

/// Une ligne d'`annonces` : un routeur entendu (`suite` : d'autres lignes suivent, la derniere a `suite` faux), ou
/// aucun (la ligne `vide`).
public struct PartieAnnonces: Hashable, Sendable {
    public let liste: [AnnonceSonde]
    public let suite: Bool

    public init(liste: [AnnonceSonde], suite: Bool) {
        self.liste = liste
        self.suite = suite
    }
}

/// Reponse a `resoudre` (firmware 1.1.0) : le RLOC16 que le cache d'adresses de la sonde donne pour l'adresse (celui
/// du parent pour un routeur Apple, celui de l'enfant pour un routeur tiers), et le ML-EID de la cible quand la reponse
/// l'a porte ; ou l'erreur (`introuvable`, `syntaxe`, `suspendue`, `occupee`, `envoi`...).
public struct ResultatResolution: Hashable, Sendable, Codable {
    public let id: Int
    public let cible: String
    public let ok: Bool
    public let ms: Int?
    public let rloc16: String?
    /// ML-EID, 32 hexa ; nil si le cache ne le donne pas.
    public let mleid: String?
    public let erreur: String?

    public init(id: Int, cible: String, ok: Bool, ms: Int? = nil, rloc16: String? = nil, mleid: String? = nil,
                erreur: String? = nil) {
        self.id = id
        self.cible = cible
        self.ok = ok
        self.ms = ms
        self.rloc16 = rloc16
        self.mleid = mleid
        self.erreur = erreur
    }

    public var rloc16Valeur: UInt16? { ok ? rloc16.flatMap { UInt16($0, radix: 16) } : nil }

    public var adresseMleid: AdresseIPv6? {
        mleid.flatMap { Data(hexa: $0) }.flatMap { AdresseIPv6(octets: [UInt8]($0)) }
    }

    /// Aucun routeur n'a repondu pour l'adresse en 15 s : l'appareil reste en rattachement suppose.
    public var introuvable: Bool { !ok && erreur == "introuvable" }
}

/// Reponse a `diag` : les TLV en hexa, ou l'erreur (`delai`, `suspendue`, `occupee`, `envoi`...).
public struct ResultatDiag: Hashable, Sendable, Codable {
```

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
    case routeurs(PartieRouteurs)
    case diag(ResultatDiag)
    case cle(ReponseCle)
    /// Commande sans id (`etat`, `voisins`) que la sonde n'a pas servie : son nom et l'erreur de la
```

par :

```swift
    case routeurs(PartieRouteurs)
    case diag(ResultatDiag)
    /// Une ligne d'`annonces` (firmware 1.1.0 ; `SondeUSB` reunit les lignes d'une meme reponse).
    case annonces(PartieAnnonces)
    case resoudre(ResultatResolution)
    case cle(ReponseCle)
    /// Commande sans id (`etat`, `voisins`) que la sonde n'a pas servie : son nom et l'erreur de la
```

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
    }

    /// JSON d'une ligne machine, sans RS ni LF ; nil si illisible ou d'une autre version.
    public static func lire(_ json: Data) -> MessageSonde? {
```

par :

```swift
    }

    private struct Annonces: Decodable {
        let vide: Bool?
        let suite: Bool?
    }

    /// JSON d'une ligne machine, sans RS ni LF ; nil si illisible ou d'une autre version.
    public static func lire(_ json: Data) -> MessageSonde? {
```

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
        case "routeurs": return (try? d.decode(Routeurs.self, from: json))?.partie.map { .routeurs($0) }
        case "diag": return (try? d.decode(ResultatDiag.self, from: json)).map { .diag($0) }
        case "cle": return (try? d.decode(ReponseCle.self, from: json)).map { .cle($0) }
        case "erreur": return (try? d.decode(Erreur.self, from: json)).map { .erreur($0.erreur) }
```

par :

```swift
        case "routeurs": return (try? d.decode(Routeurs.self, from: json))?.partie.map { .routeurs($0) }
        case "diag": return (try? d.decode(ResultatDiag.self, from: json)).map { .diag($0) }
        case "annonces":
            if let a = try? d.decode(AnnonceSonde.self, from: json) {
                return .annonces(PartieAnnonces(liste: [a], suite: (try? d.decode(Annonces.self, from: json))?.suite ?? false))
            }
            guard (try? d.decode(Annonces.self, from: json))?.vide == true else { return nil }
            return .annonces(PartieAnnonces(liste: [], suite: false))
        case "resoudre": return (try? d.decode(ResultatResolution.self, from: json)).map { .resoudre($0) }
        case "cle": return (try? d.decode(ReponseCle.self, from: json)).map { .cle($0) }
        case "erreur": return (try? d.decode(Erreur.self, from: json)).map { .erreur($0.erreur) }
```

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
    /// `diag <RLOC16> <t,t,...> <id> [<delai ms>]`
    case diag(cible: UInt16, tlv: [UInt8], id: Int, delaiMs: Int?)
    /// `cle nouvelle <alea en 64 HEXA> <id>` (USB seulement) : la carte en tire la cle de
    /// l'acces reseau et la rend une seule fois (`cle`).
```

par :

```swift
    /// `diag <RLOC16> <t,t,...> <id> [<delai ms>]`
    case diag(cible: UInt16, tlv: [UInt8], id: Int, delaiMs: Int?)
    /// `diag <ipv6> <t,t,...> <id> [<delai ms>]` : vers une adresse du reseau maille (le ML-EID d'un enfant).
    case diagAdresse(cible: AdresseIPv6, tlv: [UInt8], id: Int, delaiMs: Int?)
    /// Routeurs entendus par la sonde (firmware 1.1.0).
    case annonces
    /// `resoudre <ipv6> <id>` (firmware 1.1.0) : l'adresse sans zone.
    case resoudre(adresse: AdresseIPv6, id: Int)
    /// `cle nouvelle <alea en 64 HEXA> <id>` (USB seulement) : la carte en tire la cle de
    /// l'acces reseau et la rend une seule fois (`cle`).
```

Dans `MaillageCoeur/Maillage/ProtocoleSonde.swift`, remplacer :

```swift
            if let delai { l += " \(delai)" }
            return l + "\n"
        case .cleNouvelle(let alea, let id):
            return "cle nouvelle " + alea.map { String(format: "%02X", $0) }.joined() + " \(id)\n"
```

par :

```swift
            if let delai { l += " \(delai)" }
            return l + "\n"
        case .diagAdresse(let cible, let tlv, let id, let delai):
            var l = "diag \(cible) " + tlv.map(String.init).joined(separator: ",") + " \(id)"
            if let delai { l += " \(delai)" }
            return l + "\n"
        case .annonces: return "annonces\n"
        case .resoudre(let adresse, let id): return "resoudre \(adresse) \(id)\n"
        case .cleNouvelle(let alea, let id):
            return "cle nouvelle " + alea.map { String(format: "%02X", $0) }.joined() + " \(id)\n"
```

Dans `MaillageCoeur/Maillage/DiagnosticThread.swift`, remplacer :

```swift
    public static let mode: UInt8 = 2
    public static let route64: UInt8 = 5
    public static let donneesChef: UInt8 = 6
    public static let donneesReseau: UInt8 = 7
```

par :

```swift
    public static let mode: UInt8 = 2
    public static let route64: UInt8 = 5
    /// Compteurs MAC : un appareil endormi la rend (spec de la sonde tout-en-un, section 2.3).
    public static let compteursMac: UInt8 = 9
    public static let donneesChef: UInt8 = 6
    public static let donneesReseau: UInt8 = 7
```

Dans `MaillageCoeur/Maillage/DiagnosticThread.swift`, remplacer :

```swift
}

/// Entree d'une Child Table : un enfant du routeur qui repond.
public struct EntreeEnfant: Hashable, Sendable, Codable {
```

par :

```swift
}

/// TLV 9, compteurs MAC d'un noeud depuis son demarrage : neuf compteurs de 32 bits, gros-boutistes, dans l'ordre de
/// la spec Thread (`ifInUnknownProtos`, `ifInErrors`, `ifOutErrors`, `ifInUcastPkts`, `ifInBroadcastPkts`,
/// `ifInDiscards`, `ifOutUcastPkts`, `ifOutBroadcastPkts`, `ifOutDiscards`). Le rapport entre les echecs d'envoi et
/// les envois, entre deux releves, mesure le lien d'un enfant vers son parent (`QualiteCompteurs`).
public struct CompteursMac: Hashable, Sendable {
    public let protocolesInconnus: UInt32
    public let erreursRecues: UInt32
    /// `ifOutErrors` : trames que l'appareil n'a pas reussi a envoyer.
    public let erreursEmises: UInt32
    public let unicastRecus: UInt32
    public let diffusionsRecues: UInt32
    public let rejetsRecus: UInt32
    /// `ifOutUcastPkts` : trames unicast envoyees.
    public let unicastEmis: UInt32
    public let diffusionsEmises: UInt32
    public let rejetsEmis: UInt32

    public init(protocolesInconnus: UInt32, erreursRecues: UInt32, erreursEmises: UInt32, unicastRecus: UInt32,
                diffusionsRecues: UInt32, rejetsRecus: UInt32, unicastEmis: UInt32, diffusionsEmises: UInt32,
                rejetsEmis: UInt32) {
        self.protocolesInconnus = protocolesInconnus
        self.erreursRecues = erreursRecues
        self.erreursEmises = erreursEmises
        self.unicastRecus = unicastRecus
        self.diffusionsRecues = diffusionsRecues
        self.rejetsRecus = rejetsRecus
        self.unicastEmis = unicastEmis
        self.diffusionsEmises = diffusionsEmises
        self.rejetsEmis = rejetsEmis
    }

    /// 36 octets ; nil pour une autre longueur.
    init?(_ v: [UInt8]) {
        guard v.count == 36 else { return nil }
        let c = stride(from: 0, to: 36, by: 4).map { k in v[k..<(k + 4)].reduce(UInt32(0)) { $0 << 8 | UInt32($1) } }
        self.init(protocolesInconnus: c[0], erreursRecues: c[1], erreursEmises: c[2], unicastRecus: c[3],
                  diffusionsRecues: c[4], rejetsRecus: c[5], unicastEmis: c[6], diffusionsEmises: c[7], rejetsEmis: c[8])
    }
}

/// Entree d'une Child Table : un enfant du routeur qui repond.
public struct EntreeEnfant: Hashable, Sendable, Codable {
```

Dans `MaillageCoeur/Maillage/DiagnosticThread.swift`, remplacer :

```swift
    public private(set) var mode: ModeThread?
    public private(set) var route64: Route64?
    public private(set) var chef: DonneesChef?
    /// Network Data brutes (TLV 7), decodees par `DonneesReseau`.
```

par :

```swift
    public private(set) var mode: ModeThread?
    public private(set) var route64: Route64?
    public private(set) var compteursMac: CompteursMac?
    public private(set) var chef: DonneesChef?
    /// Network Data brutes (TLV 7), decodees par `DonneesReseau`.
```

Dans `MaillageCoeur/Maillage/DiagnosticThread.swift`, remplacer :

```swift
            case TypeTLV.mode where v.count == 1: mode = ModeThread(brut: v[0])
            case TypeTLV.route64: route64 = Self.route64(v)
            case TypeTLV.donneesChef where v.count == 8:
                chef = DonneesChef(partition: Data(v[0..<4]).hexa, poids: v[4], version: v[5], versionStable: v[6],
```

par :

```swift
            case TypeTLV.mode where v.count == 1: mode = ModeThread(brut: v[0])
            case TypeTLV.route64: route64 = Self.route64(v)
            case TypeTLV.compteursMac: compteursMac = CompteursMac(v)
            case TypeTLV.donneesChef where v.count == 8:
                chef = DonneesChef(partition: Data(v[0..<4]).hexa, poids: v[4], version: v[5], versionStable: v[6],
```

Dans `MaillageCoeur/Maillage/DiagnosticThread.swift`, remplacer :

```swift

    /// Octet de sequence, masque de 64 bits des routeurs actifs, puis un octet par
    /// routeur : qualite sortante (2 bits), entrante (2 bits), cout (4 bits).
    static func route64(_ v: [UInt8]) -> Route64? {
        guard v.count >= 9 else { return nil }
```

par :

```swift

    /// Octet de sequence, masque de 64 bits des routeurs actifs, puis un octet par
    /// routeur : qualite sortante (2 bits), entrante (2 bits), cout (4 bits). La meme valeur que la TLV Route64 des
    /// annonces MLE (`AnnonceSonde.route64Decodee`).
    static func route64(_ v: [UInt8]) -> Route64? {
        guard v.count >= 9 else { return nil }
```

- [ ] **Step 4 : les voir passer.** La commande du step 2.

Expected : `Test run with 39 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh`

Expected : `Test run with 425 tests in 42 suites passed` (cœur) et `Test run with 409 tests in 35 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add MaillageCoeur/Maillage/DiagnosticThread.swift MaillageCoeur/Maillage/ProtocoleSonde.swift MaillageCoeurTests/DiagnosticThreadTests.swift MaillageCoeurTests/ProtocoleSondeTests.swift && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --cached --name-only | sed "s|^|$PWD/|") && git commit -q -F - <<'EOF'
Lire les messages de la sonde 1.1.0 : annonces, resoudre, compteurs de l'ecoute et compteurs MAC (TLV 9)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` ; `0`.

---

### Task 5: La fusion du diagnostic et de l'écoute dans le maillage, et la qualité par les compteurs

**Files :**
- Create : `MaillageCoeur/Maillage/QualiteCompteurs.swift`
- Modify : `MaillageCoeur/Maillage/Maillage.swift` (en entier), `MaillageCoeurTests/MaillageTests.swift`, `MaillageCoeurTests/TourneeTests.swift` (blocs)

**Interfaces:**
- Consumes : `CompteursMac` (tâche 4), `Route64`.
- Produces :
  - `RouteurMaillage.entendu` (date du dernier message entendu par la sonde) ;
  - `SourceLien` (`.diagnostic`, codé `diag`, et `.ecoute`) ; `LienRadio.sourceAB`, `sourceBA`, `dateAB`, `dateBA`, et `sansDates` (le lien sans ses dates, pour l'historique) ;
  - `CouvertureEcoute(entendus:routeurs:)` ; `Maillage.annoncesLues` et `Maillage.couverture` (`nil` sans annonces lues) ;
  - `SourceEnfant.resolution` (le balayage part à la tâche 7) ; `EnfantMaillage.resolu`, `echecs`, `bitInvente` (`0x0200`), `rloc16Connu` ;
  - `ConstructionMaillage.lien(_:_:sortante:entrante:source:date:)` : chaque sens garde la mesure la plus récente ; une mesure sans date remplace ; à date égale, le diagnostic reste ; `ecoute(_:routeur:date:)` (la Route64 d'une annonce : les liens d'un routeur de la liste, dans les deux sens, et sa date d'écoute) ; `annoncesRecues()` ;
  - `QualiteCompteurs.tramesMin` (50), `qualite(taux:)` (moins de 1 % : 3 ; jusqu'à 5 % : 2 ; au-delà : 1), `mesure(avant:apres:) -> (qualite, taux)?` (`nil` si un compteur baisse, ou sous 50 envois).

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`). Un lien du diagnostic porte désormais sa source et sa date : le test de la tournée qui compare un lien les attend (la tâche 7 récrit ce fichier en entier, ce bloc compris).

Dans `MaillageCoeurTests/MaillageTests.swift`, remplacer :

```swift
        #expect(c.maillage().routeurs.filter(\.bbrPrincipal).map(\.id) == [45])
    }
}
```

par :

```swift
        #expect(c.maillage().routeurs.filter(\.bbrPrincipal).map(\.id) == [45])
    }

    // MARK: Sonde tout-en-un (spec du 07/10, sections 2.1 a 2.3)

    static let debut = Date(timeIntervalSince1970: 1_790_000_000)

    /// Route64 d'une annonce entendue : pour chaque voisin, les qualites sortante et entrante (valeurs inventees).
    static func route64(_ voisins: (id: Int, sortante: Int, entrante: Int)...) -> Route64 {
        Route64(sequence: 1, routes: voisins.map {
            RouteRouteur(idRouteur: $0.id, qualiteSortante: $0.sortante, qualiteEntrante: $0.entrante, cout: 1)
        })
    }

    /// Construction aux routeurs 1, 2, 3 et 5 (le chef : 1).
    static func quatreRouteurs() -> ConstructionMaillage {
        var c = ConstructionMaillage(date: Self.debut, partition: "1234ABCD")
        c.routeurs(Self.route64((1, 0, 0), (2, 0, 0), (3, 0, 0), (5, 0, 0)), chef: 1)
        return c
    }

    /// Fusion du diagnostic et de l'ecoute : chaque sens prend la mesure la plus recente. Le diagnostic est date du
    /// debut de la tournee, l'ecoute de l'age de l'annonce : a date egale, le diagnostic l'emporte. Un lien connu
    /// d'un seul cote (la Route64 d'une annonce) a ses deux sens.
    @Test func fusionDiagnosticEtEcoute() throws {
        var c = Self.quatreRouteurs()
        // 2 repond au diagnostic : 2 -> 3 en 3, 3 -> 2 en 2.
        c.reponse(try Self.reponseVoisins((id: 3, sortante: 3, entrante: 2)), routeur: 2)
        // 3 entendu il y a 2 min : 3 -> 2 en 1, 2 -> 3 en 1 ; et 3 -> 5 en 2, 5 -> 3 en 3 (5 ne repond pas).
        c.ecoute(Self.route64((2, 1, 1), (3, 0, 0), (5, 2, 3)), routeur: 3, date: Self.debut - 120)
        // 1 entendu a l'instant (age 0) : 1 -> 2 en 2, 2 -> 1 en 1 ; 2 repond aussi pour ce lien plus bas.
        c.ecoute(Self.route64((2, 2, 1)), routeur: 1, date: Self.debut)
        c.reponse(try Self.reponseVoisins((id: 1, sortante: 3, entrante: 3), (id: 3, sortante: 3, entrante: 2)), routeur: 2)
        let m = c.maillage()
        let l23 = try #require(m.liens.first { $0.a == 2 && $0.b == 3 })
        #expect(l23.qualiteAB == 3 && l23.qualiteBA == 2, "le diagnostic, plus recent, dans les deux sens")
        #expect(l23.sourceAB == .diagnostic && l23.sourceBA == .diagnostic)
        #expect(l23.dateAB == Self.debut && l23.dateBA == Self.debut)
        let l35 = try #require(m.liens.first { $0.a == 3 && $0.b == 5 })
        #expect(l35.qualiteAB == 2 && l35.qualiteBA == 3, "connu de 3 seul : les deux sens, de l'annonce")
        #expect(l35.sourceAB == .ecoute && l35.sourceBA == .ecoute && l35.dateAB == Self.debut - 120)
        let l12 = try #require(m.liens.first { $0.a == 1 && $0.b == 2 })
        #expect(l12.qualiteAB == 3 && l12.qualiteBA == 3 && l12.sourceAB == .diagnostic, "a date egale, le diagnostic")
        #expect(m.routeur(3)?.entendu == Self.debut - 120 && m.routeur(1)?.entendu == Self.debut)
        #expect(m.routeur(2)?.entendu == nil && m.routeur(5)?.entendu == nil)
        #expect(l35.sansDates.dateAB == nil && l35.sansDates.sourceAB == .ecoute, "l'historique garde la source, pas la date")
    }

    /// Deux annonces pour la meme paire : chaque sens prend la plus recente ; une annonce plus ancienne arrivee
    /// ensuite ne change rien. Une entree sans qualite (pas voisins) ne remplace rien.
    @Test func ecouteLaPlusRecente() throws {
        var c = Self.quatreRouteurs()
        c.ecoute(Self.route64((5, 3, 2)), routeur: 3, date: Self.debut - 60)
        c.ecoute(Self.route64((3, 1, 1)), routeur: 5, date: Self.debut - 30)
        c.ecoute(Self.route64((5, 2, 2)), routeur: 3, date: Self.debut - 600)
        c.ecoute(Self.route64((5, 0, 0)), routeur: 2, date: Self.debut)
        let m = c.maillage()
        #expect(m.liens.count == 1)
        let l = try #require(m.liens.first)
        #expect((l.a, l.b) == (3, 5) && l.qualiteAB == 1 && l.qualiteBA == 1, "celle de 5, il y a 30 s")
        #expect(l.dateAB == Self.debut - 30 && l.dateBA == Self.debut - 30)
        #expect(m.routeur(3)?.entendu == Self.debut - 60, "l'annonce la plus recente de 3")
        #expect(m.routeur(2)?.entendu == Self.debut, "entendu, meme sans lien")
    }

    /// L'ecoute ne cree ni routeur ni lien hors de la liste des routeurs : une annonce d'un routeur absent est
    /// ecartee, un voisin absent aussi. Une annonce sans Route64 rend le routeur entendu, sans lien.
    @Test func ecouteDansLaListeSeulement() throws {
        var c = Self.quatreRouteurs()
        c.ecoute(Self.route64((1, 3, 3)), routeur: 9, date: Self.debut)
        c.ecoute(Self.route64((9, 3, 3), (1, 2, 2)), routeur: 2, date: Self.debut)
        c.ecoute(nil, routeur: 5, date: Self.debut - 5)
        let m = c.maillage()
        #expect(m.routeurs.map(\.id) == [1, 2, 3, 5])
        #expect(m.liens.map { [$0.a, $0.b] } == [[1, 2]])
        #expect(m.routeur(5)?.entendu == Self.debut - 5)
    }

    /// Couverture de l'ecoute (Reglages › Sonde) : routeurs entendus sur les routeurs de la partition, si la sonde
    /// a rendu ses annonces ; sinon (firmware 1.0.3, sonde muette) inconnue.
    @Test func couverture() {
        var c = Self.quatreRouteurs()
        c.ecoute(nil, routeur: 2, date: Self.debut)
        c.ecoute(Self.route64((1, 3, 3)), routeur: 3, date: Self.debut)
        #expect(c.maillage().couverture == nil, "annonces non lues")
        c.annoncesRecues()
        #expect(c.maillage().couverture == CouvertureEcoute(entendus: 2, routeurs: 4))
        #expect(c.maillage().annoncesLues)
        var vide = Self.quatreRouteurs()
        vide.annoncesRecues()
        #expect(vide.maillage().couverture == CouvertureEcoute(entendus: 0, routeurs: 4))
    }

    /// Enfant resolu sous un routeur qui repond par son propre RLOC16 (Apple) : un numero invente, bit 9 a 1, jamais
    /// un vrai RLOC16 ; son parent reste juste. Comme une entree de balayage, une entree resolue dont l'ExtMac est
    /// celle d'un routeur est ecartee des enfants identifies, et passe apres la sonde et une table.
    @Test func enfantResolu() {
        let e = EnfantMaillage(rloc16: 0xAC00 | EnfantMaillage.bitInvente | 2, extMac: "E0000000000000C1",
                               adresses: [], source: .resolution, resolu: Self.debut, echecs: 0.007)
        #expect(!e.rloc16Connu && e.parent == 43)
        #expect(EnfantMaillage(rloc16: 0xAC05, source: .tableEnfants).rloc16Connu)
        var c = Self.quatreRouteurs()
        c.identite("E0000000000000C2", routeur: 5)
        c.enfant(e)
        c.enfant(EnfantMaillage(rloc16: 0x1600, extMac: "E0000000000000C2", source: .resolution))
        c.enfant(EnfantMaillage(rloc16: 0x0805, extMac: "E0000000000000C1", qualite: 2, source: .tableEnfants))
        let m = c.maillage()
        #expect(m.enfantsIdentifies["E0000000000000C2"] == nil, "devenu routeur")
        #expect(m.enfantsIdentifies["E0000000000000C1"]?.source == .tableEnfants, "la table passe avant")
        let resolu = m.enfants.first { $0.rloc16 == e.rloc16 }
        #expect(resolu?.resolu == Self.debut && resolu?.echecs == 0.007)
    }
}

@Suite("Qualite d'un enfant par ses compteurs MAC")
struct QualiteCompteursTests {
    static func releve(envois: UInt32, echecs: UInt32) -> CompteursMac {
        CompteursMac(protocolesInconnus: 0, erreursRecues: 0, erreursEmises: echecs, unicastRecus: 10, diffusionsRecues: 0,
                     rejetsRecus: 0, unicastEmis: envois, diffusionsEmises: 0, rejetsEmis: 0)
    }

    /// Taux d'echec entre deux releves : Δ echecs / Δ envois. Moins de 1 % : 3 ; de 1 a 5 % : 2 ; au-dela : 1.
    @Test func tauxEtQualite() throws {
        let avant = Self.releve(envois: 5000, echecs: 40)
        let m = try #require(QualiteCompteurs.mesure(avant: avant, apres: Self.releve(envois: 6000, echecs: 47)))
        #expect(m.qualite == 3 && abs(m.taux - 0.007) < 1e-12)
        #expect(QualiteCompteurs.mesure(avant: avant, apres: Self.releve(envois: 6000, echecs: 50))?.qualite == 2, "1 %")
        #expect(QualiteCompteurs.mesure(avant: avant, apres: Self.releve(envois: 6000, echecs: 90))?.qualite == 2, "5 %")
        #expect(QualiteCompteurs.mesure(avant: avant, apres: Self.releve(envois: 6000, echecs: 91))?.qualite == 1, "5,1 %")
        #expect(QualiteCompteurs.qualite(taux: 0.0099) == 3 && QualiteCompteurs.qualite(taux: 0.5) == 1)
    }

    /// Moins de 50 trames envoyees entre les deux releves : qualite inconnue ; 50 suffisent.
    @Test func seuilDe50Trames() {
        let avant = Self.releve(envois: 100, echecs: 0)
        #expect(QualiteCompteurs.mesure(avant: avant, apres: Self.releve(envois: 149, echecs: 0)) == nil)
        #expect(QualiteCompteurs.mesure(avant: avant, apres: Self.releve(envois: 150, echecs: 0))?.qualite == 3)
        #expect(QualiteCompteurs.tramesMin == 50)
    }

    /// Un compteur qui baisse (l'appareil a redemarre) : pas de mesure ; le releve repart de zero.
    @Test func compteurQuiBaisse() {
        let avant = Self.releve(envois: 9000, echecs: 30)
        #expect(QualiteCompteurs.mesure(avant: avant, apres: Self.releve(envois: 200, echecs: 31)) == nil, "envois")
        #expect(QualiteCompteurs.mesure(avant: avant, apres: Self.releve(envois: 9900, echecs: 2)) == nil, "echecs")
    }
}
```

Dans `MaillageCoeurTests/TourneeTests.swift`, remplacer :

```swift
        #expect(m.liens == [LienRadio(a: 10, b: 12, qualiteAB: 3, qualiteBA: 1)], "le rapport du 12")
```

par :

```swift
        #expect(m.liens == [LienRadio(a: 10, b: 12, qualiteAB: 3, qualiteBA: 1, sourceAB: .diagnostic, sourceBA: .diagnostic,
                                      dateAB: Self.t0, dateBA: Self.t0)], "le rapport du 12")
```

- [ ] **Step 2 : les voir échouer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh MaillageCoeurTests/MaillageTests MaillageCoeurTests/QualiteCompteursTests MaillageCoeurTests/TourneeTests`

Expected : la compilation des tests échoue : `value of type 'ConstructionMaillage' has no member 'ecoute'`, `cannot find 'QualiteCompteurs' in scope`, `value of type 'RouteurMaillage' has no member 'entendu'`, `value of type 'LienRadio' has no member 'sourceAB'`, `cannot find 'CouvertureEcoute' in scope`, `type 'SourceEnfant' has no member 'resolution'`… ; dans `TourneeTests`, `extra arguments at positions #5, #6, #7, #8 in call`.

- [ ] **Step 3 : la fusion, la couverture, les enfants résolus, la qualité par les compteurs** (`--etapes 3`).

`MaillageCoeur/Maillage/Maillage.swift`, fichier entier :

```swift
import Foundation

/// Routeur Thread vu par la sonde.
public struct RouteurMaillage: Hashable, Sendable, Identifiable {
    /// Identifiant de routeur, de 0 a 62 : son RLOC16 est `id << 10`.
    public let id: Int
    public var extMac: String?
    /// Publie un prefixe, une route ou le service SRP (Network Data).
    public var bordure = false
    public var bbrPrincipal = false
    public var chef = false
    /// N'a pas repondu a la tournee : ses liens et ses enfants ne viennent que des autres.
    public var muet = false
    public var version: Int?
    /// Version de la pile (TLV 28).
    public var pile: String?
    /// Dernier message MLE de ce routeur que la sonde a entendu (`annonces`, firmware 1.1.0) ; nil s'il n'est pas
    /// entendu.
    public var entendu: Date?

    public init(id: Int) { self.id = id }

    public var rloc16: UInt16 { UInt16(id) << 10 }
}

/// D'ou vient la mesure d'un sens d'un lien entre routeurs (spec de la sonde tout-en-un, section 2.1). Un lien est un
/// lien : il est dessine pareil quelle que soit sa source ; la fiche dit la source et l'age.
public enum SourceLien: String, Hashable, Sendable {
    /// Route64 d'un routeur qui repond au diagnostic, mesuree au debut de la tournee.
    case diagnostic = "diag"
    /// Route64 d'une annonce MLE que la sonde a entendue, datee de l'age que la sonde donne.
    case ecoute
}

/// Lien radio entre deux routeurs voisins (a < b), avec la qualite dans chaque
/// sens, de 0 a 3 ; nil : inconnue.
public struct LienRadio: Hashable, Sendable {
    public let a: Int
    public let b: Int
    /// Qualite du lien de a vers b.
    public var qualiteAB: Int?
    /// Qualite du lien de b vers a.
    public var qualiteBA: Int?
    /// Source de la mesure de chaque sens ; nil : inconnue (maillage de demo, historique d'avant la 1.1.0).
    public var sourceAB: SourceLien?
    public var sourceBA: SourceLien?
    /// Date de la mesure de chaque sens ; nil : inconnue. L'historique ne la garde pas.
    public var dateAB: Date?
    public var dateBA: Date?

    /// La moins bonne des qualites connues.
    public var qualite: Int? { [qualiteAB, qualiteBA].compactMap { $0 }.min() }

    /// Le meme lien sans les dates de ses mesures, comme l'historique le garde.
    public var sansDates: LienRadio {
        var l = self
        l.dateAB = nil
        l.dateBA = nil
        return l
    }
}

/// Couverture de l'ecoute (Reglages › Sonde) : les routeurs de la partition que la sonde entend, sur tous.
public struct CouvertureEcoute: Hashable, Sendable {
    public let entendus: Int
    public let routeurs: Int

    public init(entendus: Int, routeurs: Int) {
        self.entendus = entendus
        self.routeurs = routeurs
    }
}

/// D'ou vient un enfant.
public enum SourceEnfant: String, Hashable, Sendable {
    /// Child Table de son parent, un routeur qui repond.
    case tableEnfants
    /// Trouve par balayage sous un routeur muet.
    case balayage
    /// Rattache a son parent par la resolution d'adresse (spec de la sonde tout-en-un, section 2.2), sous un routeur
    /// qui ne repond pas au diagnostic.
    case resolution
    /// La sonde elle-meme.
    case sonde
}

/// Enfant d'un routeur (appareil endormi ou non, ou la sonde).
public struct EnfantMaillage: Hashable, Sendable, Identifiable {
    public let rloc16: UInt16
    public var extMac: String?
    /// Qualite du lien de l'enfant vers son parent, de 0 a 3 ; nil sous un routeur muet.
    public var qualite: Int?
    /// Delai d'expiration de l'enfant (Child Timeout), en secondes.
    public var delai: Int?
    public var endormi: Bool?
    /// Adresses donnees par l'enfant (TLV 8), pour le reconnaitre par son adresse OMR.
    public var adresses: [AdresseIPv6]
    public var source: SourceEnfant
    /// Date de la resolution d'adresse qui l'a rattache (source `.resolution`) ; nil sinon.
    public var resolu: Date?
    /// Taux d'echec d'envoi de l'enfant entre deux releves de ses compteurs MAC, quand sa qualite en vient (enfant d'un
    /// routeur qui ne repond pas, spec de la sonde tout-en-un, section 2.3) ; nil sinon.
    public var echecs: Double?

    public init(rloc16: UInt16, extMac: String? = nil, qualite: Int? = nil, delai: Int? = nil, endormi: Bool? = nil,
                adresses: [AdresseIPv6] = [], source: SourceEnfant, resolu: Date? = nil, echecs: Double? = nil) {
        self.rloc16 = rloc16
        self.extMac = extMac
        self.qualite = qualite
        self.delai = delai
        self.endormi = endormi
        self.adresses = adresses
        self.source = source
        self.resolu = resolu
        self.echecs = echecs
    }

    public var id: UInt16 { rloc16 }
    /// Identifiant de routeur du parent.
    public var parent: Int { Int(rloc16 >> 10) }

    /// Bit 9 d'un RLOC16 : toujours nul dans un vrai (6 bits de routeur, un bit nul, 9 bits d'enfant). Un enfant resolu
    /// sous un routeur qui repond par son propre RLOC16 (Apple) n'a pas le sien : il recoit un numero invente sous son
    /// parent, ce bit a 1, qui ne peut etre celui d'aucun autre noeud.
    public static let bitInvente: UInt16 = 0x0200

    /// Son vrai RLOC16 est connu (`bitInvente` nul).
    public var rloc16Connu: Bool { rloc16 & Self.bitInvente == 0 }
}

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
    public let date: Date
    public let partition: String
    /// Par identifiant croissant.
    public let routeurs: [RouteurMaillage]
    /// Par (a, b) croissants.
    public let liens: [LienRadio]
    /// Par RLOC16 croissant.
    public let enfants: [EnfantMaillage]
    /// Signal des routeurs de la liste que la sonde entend, son parent compris, par identifiant
    /// croissant.
    public let signaux: [SignalSonde]
    /// Date du balayage dont viennent les enfants balayes de ce maillage
    /// (`MemoireTournee.dernierBalayage`) ; nil sans balayage.
    public var balayage: Date?
    /// La sonde a rendu ses annonces a cette tournee (firmware 1.1.0) : un routeur sans `entendu` n'est pas entendu.
    public var annoncesLues = false

    /// Couverture de l'ecoute : les routeurs entendus sur ceux de la partition ; nil si la sonde n'a pas rendu ses
    /// annonces (firmware 1.0.3, sonde muette).
    public var couverture: CouvertureEcoute? {
        annoncesLues ? CouvertureEcoute(entendus: routeurs.count { $0.entendu != nil }, routeurs: routeurs.count) : nil
    }

    public func routeur(_ id: Int) -> RouteurMaillage? { routeurs.first { $0.id == id } }
    public func liens(de id: Int) -> [LienRadio] { liens.filter { $0.a == id || $0.b == id } }
    public func enfants(de id: Int) -> [EnfantMaillage] { enfants.filter { $0.parent == id } }
    public var chef: RouteurMaillage? { routeurs.first(where: \.chef) }
    /// Identifiant de routeur du parent de la sonde.
    public var parentSonde: Int? { enfants.first { $0.source == .sonde }?.parent }

    /// Enfants identifies (ExtMac connue), un par ExtMac. Vu deux fois (il a change de parent),
    /// l'entree la plus fraiche l'emporte : la sonde (elle sait son parent), puis la table d'un
    /// routeur qui repond (l'ancien parent garde l'enfant jusqu'a son echeance), puis le balayage
    /// ou la resolution sous un routeur muet, qui peuvent dater de 30 minutes ; a egalite, la premiere
    /// par RLOC16. Une entree du balayage ou de la resolution dont l'ExtMac est celle d'un routeur du
    /// maillage est ecartee : l'enfant est devenu routeur depuis.
    public var enfantsIdentifies: [String: EnfantMaillage] {
        func rang(_ s: SourceEnfant) -> Int {
            switch s {
            case .sonde: 0
            case .tableEnfants: 1
            case .balayage, .resolution: 2
            }
        }
        let routeursExt = Set(routeurs.compactMap(\.extMac))
        var parExtMac: [String: EnfantMaillage] = [:]
        for e in enfants {
            let ancien = e.source == .balayage || e.source == .resolution
            guard let x = e.extMac, !(ancien && routeursExt.contains(x)) else { continue }
            if let deja = parExtMac[x], rang(deja.source) <= rang(e.source) { continue }
            parExtMac[x] = e
        }
        return parExtMac
    }
}

/// Assemble un `Maillage` au fil des reponses d'une tournee.
public struct ConstructionMaillage: Sendable {
    private let date: Date
    private let partition: String
    private var routeurs: [Int: RouteurMaillage] = [:]
    private var liens: [Int: LienRadio] = [:]
    private var enfants: [UInt16: EnfantMaillage] = [:]
    private var signaux: [Int: SignalSonde] = [:]
    private var annoncesLues = false

    public init(date: Date, partition: String) {
        self.date = date
        self.partition = partition
    }

    /// Routeurs actifs de la partition (Route64 du chef, ou d'un routeur qui repond).
    public mutating func routeurs(_ r: Route64, chef: Int) {
        for id in r.routeurs where routeurs[id] == nil { routeurs[id] = RouteurMaillage(id: id) }
        routeurs[chef, default: RouteurMaillage(id: chef)].chef = true
    }

    /// Roles lus dans les Network Data. BBR principal, comme OpenThread : celui du chef s'il est
    /// parmi les serveurs, sinon le premier de `d.bbr` (de meme si le chef n'est pas encore connu).
    /// `seulementConnus` : Network Data d'une tournee precedente, pour les seuls routeurs deja dans
    /// le maillage (la liste des routeurs a pu changer depuis) ; un serveur BBR absent ne compte pas.
    public mutating func reseau(_ d: DonneesReseau, seulementConnus: Bool = false) {
        func pris(_ rloc: UInt16) -> Bool { !seulementConnus || routeurs[Int(rloc >> 10)] != nil }
        for rloc in d.routeursDeBordure where pris(rloc) {
            routeurs[Int(rloc >> 10), default: RouteurMaillage(id: Int(rloc >> 10))].bordure = true
        }
        let chef = routeurs.values.first(where: \.chef)?.rloc16
        let serveurs = d.bbr.filter(pris)
        if let principal = serveurs.first(where: { $0 == chef }) ?? serveurs.first {
            routeurs[Int(principal >> 10), default: RouteurMaillage(id: Int(principal >> 10))].bbrPrincipal = true
        }
    }

    /// Reponse d'un routeur : identite, version, ses liens (Route64) et ses enfants (Child Table).
    public mutating func reponse(_ r: ReponseDiagnostic, routeur id: Int) {
        var routeur = routeurs[id, default: RouteurMaillage(id: id)]
        routeur.extMac = r.extMac ?? routeur.extMac
        routeur.version = r.version ?? routeur.version
        routeur.muet = false
        routeurs[id] = routeur
        for route in r.route64?.routes ?? [] where route.idRouteur != id {
            if routeurs[route.idRouteur] == nil { routeurs[route.idRouteur] = RouteurMaillage(id: route.idRouteur) }
            guard route.estVoisin else { continue }
            lien(id, route.idRouteur, sortante: route.qualiteSortante, entrante: route.qualiteEntrante, source: .diagnostic,
                 date: date)
        }
        for e in r.enfants ?? [] {
            enfant(EnfantMaillage(rloc16: e.rloc16(parent: routeur.rloc16), qualite: e.qualite, delai: e.delai,
                                  endormi: e.mode.endormi, source: .tableEnfants))
        }
    }

    /// Annonce d'un routeur que la sonde a entendue (`annonces`), datee de son age : le routeur est entendu, et sa
    /// Route64, s'il y en a une, donne ses liens avec les routeurs du maillage, dans les deux sens (spec de la sonde
    /// tout-en-un, section 2.1). Ni le routeur ni ses voisins ne sont ajoutes : une annonce d'un routeur hors de la
    /// liste des routeurs est ecartee, comme un voisin qui n'y est pas.
    public mutating func ecoute(_ r: Route64?, routeur id: Int, date: Date) {
        guard var routeur = routeurs[id] else { return }
        routeur.entendu = max(routeur.entendu ?? date, date)
        routeurs[id] = routeur
        for route in r?.routes ?? [] where route.idRouteur != id && route.estVoisin && routeurs[route.idRouteur] != nil {
            lien(id, route.idRouteur, sortante: route.qualiteSortante, entrante: route.qualiteEntrante, source: .ecoute,
                 date: date)
        }
    }

    /// La sonde a rendu ses annonces a cette tournee : un routeur sans `entendu` n'a pas ete entendu (couverture).
    public mutating func annoncesRecues() {
        annoncesLues = true
    }

    /// ExtMac apprise ailleurs (parent de la sonde, table des routeurs, tournee precedente) : pour
    /// un routeur qui ne la donne pas lui-meme, muet ou dont la reponse n'a pas l'ExtMac. Ne
    /// remplace jamais celle qu'il a donnee.
    public mutating func identite(_ ext: String, routeur id: Int) {
        var r = routeurs[id, default: RouteurMaillage(id: id)]
        r.extMac = r.extMac ?? ext
        routeurs[id] = r
    }

    public mutating func pile(_ p: String?, routeur id: Int) {
        routeurs[id, default: RouteurMaillage(id: id)].pile = p
    }

    /// Routeur qui n'a pas repondu.
    public mutating func muet(_ id: Int) {
        routeurs[id, default: RouteurMaillage(id: id)].muet = true
    }

    /// Enfant trouve (table, balayage, sonde) ; complete celui qui est deja connu.
    public mutating func enfant(_ e: EnfantMaillage) {
        guard var connu = enfants[e.rloc16] else {
            enfants[e.rloc16] = e
            return
        }
        connu.extMac = connu.extMac ?? e.extMac
        connu.qualite = connu.qualite ?? e.qualite
        connu.delai = connu.delai ?? e.delai
        connu.endormi = connu.endormi ?? e.endormi
        connu.resolu = connu.resolu ?? e.resolu
        connu.echecs = connu.echecs ?? e.echecs
        if connu.adresses.isEmpty { connu.adresses = e.adresses }
        if e.source == .sonde { connu.source = .sonde }
        enfants[e.rloc16] = connu
    }

    /// Signal d'un routeur entendu par la sonde ; le dernier donne pour un routeur l'emporte. Un
    /// RSSI positif ou nul est ignore (127 : RSSI invalide d'OpenThread, rien d'entendu encore).
    public mutating func signal(_ s: SignalSonde) {
        guard s.rssi < 0 else { return }
        signaux[s.routeur] = s
    }

    /// Roles poses a la main (maillage de demo).
    mutating func marquer(_ id: Int, bordure: Bool, bbrPrincipal: Bool = false) {
        var r = routeurs[id, default: RouteurMaillage(id: id)]
        r.bordure = bordure
        r.bbrPrincipal = bbrPrincipal
        routeurs[id] = r
    }

    /// Lien vu par `de` : qualite sortante (de -> vers) et entrante (vers -> de), mesurees a `date` par `source`.
    /// Un lien est souvent lu aux deux bouts (chaque routeur qui repond le voit dans sa Route64, chaque annonce
    /// entendue aussi). Les rapports ne sont pas fusionnes : chaque sens prend la mesure la plus recente (spec de la
    /// sonde tout-en-un, section 2.1), ni moyenne, ni meilleure, ni pire valeur ; a date egale, le diagnostic
    /// l'emporte sur l'ecoute, et entre deux mesures de meme source la derniere appliquee ; sans date (maillage de
    /// demo), la derniere appliquee. Le diagnostic d'une tournee est date de son debut, et la tournee applique les
    /// reponses par identifiant croissant : quand les deux bouts repondent, celui de plus grand identifiant decide,
    /// pour les deux sens. Un lien lu par un seul bout garde ses deux sens, ranges de `a` vers `b` (le plus petit
    /// identifiant d'abord). Une entree de Route64 sans qualite (pas voisin, `estVoisin` faux) n'est pas
    /// appliquee : elle ne remplace pas le rapport de l'autre bout.
    mutating func lien(_ de: Int, _ vers: Int, sortante: Int, entrante: Int, source: SourceLien? = nil, date: Date? = nil) {
        let (a, b) = (min(de, vers), max(de, vers))
        var l = liens[a * 64 + b] ?? LienRadio(a: a, b: b)
        let (ab, ba) = de == a ? (sortante, entrante) : (entrante, sortante)
        if Self.remplace(l.qualiteAB, l.sourceAB, l.dateAB, par: source, date) {
            l.qualiteAB = ab
            l.sourceAB = source
            l.dateAB = date
        }
        if Self.remplace(l.qualiteBA, l.sourceBA, l.dateBA, par: source, date) {
            l.qualiteBA = ba
            l.sourceBA = source
            l.dateBA = date
        }
        liens[a * 64 + b] = l
    }

    /// Une mesure (`source`, `date`) remplace celle d'un sens : sens inconnu, ou l'une sans date ; sinon la plus recente,
    /// et a date egale toujours, sauf l'ecoute devant le diagnostic.
    static func remplace(_ qualite: Int?, _ ancienne: SourceLien?, _ quand: Date?, par source: SourceLien?,
                         _ date: Date?) -> Bool {
        guard qualite != nil, let quand, let date else { return true }
        if date != quand { return date > quand }
        return !(ancienne == .diagnostic && source == .ecoute)
    }

    /// Enfants des tables encore sans ExtMac, par RLOC16 : a identifier (la sonde exceptee ; un enfant resolu, dont le
    /// RLOC16 peut etre invente, aussi).
    public var enfantsSansIdentite: [UInt16] {
        enfants.values.filter { $0.extMac == nil && $0.source != .sonde && $0.source != .resolution }.map(\.rloc16).sorted()
    }

    /// Le maillage ; les signaux des seuls routeurs de la liste.
    public func maillage() -> Maillage {
        var m = Maillage(date: date, partition: partition,
                         routeurs: routeurs.values.sorted { $0.id < $1.id },
                         liens: liens.values.sorted { ($0.a, $0.b) < ($1.a, $1.b) },
                         enfants: enfants.values.sorted { $0.rloc16 < $1.rloc16 },
                         signaux: signaux.values.filter { routeurs[$0.routeur] != nil }.sorted { $0.routeur < $1.routeur })
        m.annoncesLues = annoncesLues
        return m
    }
}
```

`MaillageCoeur/Maillage/QualiteCompteurs.swift` :

```swift
import Foundation

/// Qualite du lien d'un enfant vers son parent, tiree de ses compteurs MAC (TLV 9) entre deux releves (spec de la sonde
/// tout-en-un, section 2.3) : le taux d'echec, les echecs d'envoi sur les envois (Δ `ifOutErrors` / Δ
/// `ifOutUcastPkts`). C'est le lien vu du cote de l'enfant : sous un routeur Apple, qui ne repond pas au diagnostic, la
/// seule mesure possible ; la qualite vue par le parent reste inconnue.
public enum QualiteCompteurs {
    /// Trames envoyees entre deux releves, au moins : en deca, la qualite reste inconnue.
    public static let tramesMin: UInt32 = 50

    /// Qualite d'un taux d'echec : moins de 1 %, bonne (3) ; de 1 a 5 %, moyenne (2) ; au-dela, faible (1).
    public static func qualite(taux: Double) -> Int {
        taux < 0.01 ? 3 : taux <= 0.05 ? 2 : 1
    }

    /// Le taux d'echec entre deux releves, et sa qualite ; nil si moins de `tramesMin` trames sont parties entre les
    /// deux, ou si un compteur a baisse (l'appareil a redemarre : le releve repart de zero).
    public static func mesure(avant: CompteursMac, apres: CompteursMac) -> (qualite: Int, taux: Double)? {
        guard apres.unicastEmis >= avant.unicastEmis, apres.erreursEmises >= avant.erreursEmises else { return nil }
        let envois = apres.unicastEmis - avant.unicastEmis
        guard envois >= tramesMin else { return nil }
        let taux = Double(apres.erreursEmises - avant.erreursEmises) / Double(envois)
        return (qualite(taux: taux), taux)
    }
}
```

- [ ] **Step 4 : les voir passer.** La commande du step 2.

Expected : `Test run with 74 tests in 3 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh`

Expected : `Test run with 433 tests in 43 suites passed` (cœur) et `Test run with 409 tests in 35 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add MaillageCoeur/Maillage/Maillage.swift MaillageCoeur/Maillage/QualiteCompteurs.swift MaillageCoeurTests/MaillageTests.swift MaillageCoeurTests/TourneeTests.swift && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --cached --name-only | sed "s|^|$PWD/|") && git commit -q -F - <<'EOF'
Fusionner diagnostic et ecoute dans le maillage : source et date de chaque sens, routeurs entendus, couverture, enfants resolus, qualite par les compteurs MAC

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` ; `0`.

---

### Task 6: `annonces`, `resoudre` et le diagnostic d'une adresse, par l'USB et par le réseau

**Files :**
- Modify : `MaillageThread/Sonde/SondeUSB.swift` (en entier), `MaillageThread/Sonde/Reseau/CanalReseau.swift`, `MaillageThreadTests/SondeTests.swift`, `MaillageThreadTests/CanalReseauTests.swift` (blocs)

**Interfaces:**
- Consumes : `CommandeSonde`, `MessageSonde`, `AnnonceSonde`, `ResultatResolution` (tâche 4).
- Produces :
  - `SondeUSB.delaiResolution` (15 s, celui de la sonde) et le paramètre `delaiResolution` de l'initialiseur ;
  - `SondeUSB.annonces() -> [AnnonceSonde]` (les lignes `suite` réunies ; sans réponse : `sansReponse("annonces")`) ; `diag(adresse:_:delaiMs:)` (le diagnostic d'une adresse IPv6, attendu par sa cible) ; `resoudre(_:) -> ResultatResolution` (au-delà de 15 s et d'une marge : l'erreur `delai`) ; `clore` libère les attentes de `annonces` et de `resoudre` ;
  - `CanalReseau.Reglages.volResolution` et `volEnCours(_:)` (le délai d'un `diag` ou d'un `resoudre`) ; les renvois d'un `resoudre` : à 2, 4, 16 et 19 s.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`).

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
    static func diag(_ id: Int, _ cible: String, tlv: String) -> String {
        #"{"v":1,"t":"diag","id":\#(id),"cible":"\#(cible)","ms":40,"ok":true,"code":"2.04","tlv":"\#(tlv)"}"#
    }

```

par :

```swift
    static func diag(_ id: Int, _ cible: String, tlv: String) -> String {
        #"{"v":1,"t":"diag","id":\#(id),"cible":"\#(cible)","ms":40,"ok":true,"code":"2.04","tlv":"\#(tlv)"}"#
    }

    /// Ligne `annonces` (firmware 1.1.0) : un routeur entendu, sa Route64 brute (ExtMac inventee) ; `suite` :
    /// d'autres lignes suivent.
    static func annonce(_ rloc16: String, route64: String?, age: Int = 5, suite: Bool) -> String {
        #"{"v":1,"t":"annonces","rloc16":"\#(rloc16)","ext":"E0000000000000\#(rloc16.prefix(2))","partition":"0000000A","route64":\#(route64.map { "\"\($0)\"" } ?? "null"),"seq":null,"rssi":-70,"rssi_min":-75,"rssi_max":-65,"nb":3,"age_s":\#(age),"suite":\#(suite)}"#
    }

    static let annoncesVides = #"{"v":1,"t":"annonces","vide":true}"#

    /// Reponse a `resoudre` (firmware 1.1.0) : le RLOC16 trouve et, s'il est donne, le ML-EID (32 hexa).
    static func resolution(_ id: Int, _ cible: String, rloc16: String, mleid: String? = nil) -> String {
        #"{"v":1,"t":"resoudre","id":\#(id),"cible":"\#(cible)","ok":true,"ms":120,"rloc16":"\#(rloc16)","mleid":\#(mleid.map { "\"\($0)\"" } ?? "null")}"#
    }

```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
        canal.fermer()
        await #expect(throws: SondeUSB.Erreur.fermee) { _ = try await requete.value }
    }

```

par :

```swift
        canal.fermer()
        await #expect(throws: SondeUSB.Erreur.fermee) { _ = try await requete.value }
    }

    /// `annonces` (firmware 1.1.0) sur deux lignes (`suite`) : les deux routeurs entendus, dans l'ordre ; puis la ligne
    /// `vide` : aucun.
    @Test func annoncesSurPlusieursLignes() async throws {
        let appels = Mutex(0)
        let canal = CanalRejoue { l in
            guard l == "annonces\n" else { return [] }
            let n = appels.withLock { a in
                a += 1
                return a
            }
            return n == 1 ? [CanalRejoue.annonce("0400", route64: "01800000000000000000", suite: true),
                             CanalRejoue.annonce("AC00", route64: nil, age: 40, suite: false)]
                          : [CanalRejoue.annoncesVides]
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        let a = try await s.annonces()
        #expect(a.map(\.rloc16) == ["0400", "AC00"])
        #expect(a.map(\.ageS) == [5, 40])
        #expect(a.first?.route64Decodee?.routeurs == [0])
        #expect(try await s.annonces().isEmpty, "aucun routeur entendu")
        #expect(canal.envoyes == ["annonces\n", "annonces\n"])
    }

    /// Pas de fin d'`annonces` dans le delai (firmware 1.0.3 : `commande inconnue`, ou une ligne `suite` sans la
    /// derniere) : `sansReponse`, et la partie recue est abandonnee.
    @Test(.timeLimit(.minutes(1))) func annoncesSansReponse() async throws {
        let appels = Mutex(0)
        let canal = CanalRejoue { l in
            guard l == "annonces\n" else { return [] }
            let n = appels.withLock { a in
                a += 1
                return a
            }
            return n == 1 ? [CanalRejoue.annonce("0400", route64: nil, suite: true)]
                          : [#"{"v":1,"t":"erreur","erreur":"commande inconnue"}"#]
        }
        let s = SondeUSB(canal: canal, delaiCommande: .milliseconds(200))
        try await s.demarrer {}
        await #expect(throws: SondeUSB.Erreur.sansReponse("annonces")) { _ = try await s.annonces() }
        await #expect(throws: SondeUSB.Erreur.sansReponse("annonces")) { _ = try await s.annonces() }
    }

    /// `resoudre` (firmware 1.1.0) : l'adresse part nue (sans zone) ; deux resolutions en vol, les reponses dans le
    /// desordre, chacune a son id et a sa cible ; une reponse d'un autre id, ou d'une autre cible au meme id, ignoree.
    @Test func resolutionsDansLeDesordre() async throws {
        let a1 = try #require(AdresseIPv6("fd00:aaaa:bbbb:1::17%en0"))
        let a2 = try #require(AdresseIPv6("fd00:aaaa:bbbb:1::18"))
        let canal = CanalRejoue { l in
            guard l.hasPrefix("resoudre fd00:aaaa:bbbb:1::18") else { return [] }
            return [CanalRejoue.resolution(2, "fd00:aaaa:bbbb:1::18", rloc16: "5003"),
                    CanalRejoue.resolution(1, "fd00:aaaa:bbbb:1::99", rloc16: "0400"),
                    CanalRejoue.resolution(1, "fd00:aaaa:bbbb:1::17", rloc16: "AC00", mleid: "FD00111122220C870000000000000017")]
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        async let r1 = s.resoudre(a1)
        try await Task.sleep(for: .milliseconds(50))
        async let r2 = s.resoudre(a2)
        let (p, q) = try await (r1, r2)
        #expect(p.rloc16Valeur == 0xAC00 && p.adresseMleid == AdresseIPv6("fd00:1111:2222:c87::17"))
        #expect(q.rloc16Valeur == 0x5003 && q.adresseMleid == nil)
        #expect(canal.envoyes == ["resoudre fd00:aaaa:bbbb:1::17 1\n", "resoudre fd00:aaaa:bbbb:1::18 2\n"])
    }

    /// Sans reponse a `resoudre` (firmware sans resolution) : `delai`, apres les 15 s de la sonde et la marge ; liaison
    /// fermee pendant l'attente : `fermee`.
    @Test(.timeLimit(.minutes(1))) func resolutionSansReponse() async throws {
        let a = try #require(AdresseIPv6("fd00:aaaa:bbbb:1::17"))
        let canal = CanalRejoue { _ in [] }
        let s = SondeUSB(canal: canal, marge: .milliseconds(50), delaiResolution: .milliseconds(100))
        try await s.demarrer {}
        let r = try await s.resoudre(a)
        #expect(!r.ok && r.erreur == "delai" && r.cible == "fd00:aaaa:bbbb:1::17" && !r.introuvable)
        let lente = SondeUSB(canal: canal, delaiResolution: .seconds(30))
        try await lente.demarrer {}
        let requete = Task { try await lente.resoudre(a) }
        try await Task.sleep(for: .milliseconds(50))
        canal.fermer()
        await #expect(throws: SondeUSB.Erreur.fermee) { _ = try await requete.value }
    }

    /// `diag` vers une adresse (le ML-EID d'un enfant, pour ses compteurs MAC) : la reponse a sa cible, ecrite comme
    /// la commande l'a envoyee.
    @Test func diagParAdresse() async throws {
        let mleid = try #require(AdresseIPv6("fd00:1111:2222:c87::17"))
        let compteurs = "0924" + String(repeating: "00000001", count: 9)
        let canal = CanalRejoue { l in
            l.hasPrefix("diag fd00:1111:2222:c87::17 9 ") ? [CanalRejoue.diag(1, "fd00:1111:2222:c87::17", tlv: compteurs)] : []
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        let r = try await s.diag(adresse: mleid, [9], delaiMs: 8000)
        #expect(r.reponse?.compteursMac?.unicastEmis == 1)
        #expect(canal.envoyes == ["diag fd00:1111:2222:c87::17 9 1 8000\n"])
    }

```

Dans `MaillageThreadTests/CanalReseauTests.swift`, remplacer :

```swift
        #expect(r.renvois(pour: "diag 5000 1 1 0") == [s(2), s(4)])
        #expect(r.renvois(pour: "diag 5000 1 1") == [s(2), s(4)], "sans delai lisible : comme les autres")
        for commande in ["bonjour", "etat", "voisins", "routeurs"] {
            #expect(r.renvois(pour: commande) == [s(2), s(4)])
        }
        #expect(SondeUSB.margeDiag == r.margeDiag, "echeance de SondeUSB")
    }

```

par :

```swift
        #expect(r.renvois(pour: "diag 5000 1 1 0") == [s(2), s(4)])
        #expect(r.renvois(pour: "diag 5000 1 1") == [s(2), s(4)], "sans delai lisible : comme les autres")
        for commande in ["bonjour", "etat", "voisins", "routeurs", "annonces"] {
            #expect(r.renvois(pour: commande) == [s(2), s(4)])
        }
        #expect(SondeUSB.margeDiag == r.margeDiag, "echeance de SondeUSB")
        // Une resolution (firmware 1.1.0) reste en vol 15 s au plus : renvois a 2 et 4 s, puis 16 et 19 s.
        #expect(r.renvois(pour: "resoudre fd00:aaaa:bbbb:1::17 7") == [s(2), s(4), s(16), s(19)])
        #expect(r.renvois(pour: "resoudre fd00:aaaa:bbbb:1::17") == [s(2), s(4)], "sans id : comme les autres")
        #expect(r.volResolution == SondeUSB.delaiResolution)
    }

```

- [ ] **Step 2 : les voir échouer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh MaillageThreadTests/SondeUSBTests MaillageThreadTests/SondeMaillageTests MaillageThreadTests/CanalReseauTests`

Expected : la compilation des tests échoue : `value of type 'SondeUSB' has no member 'annonces'`, `value of type 'SondeUSB' has no member 'resoudre'`, `extra argument 'delaiResolution' in call`, `extraneous argument label 'adresse:' in call`, `type 'SondeUSB' has no member 'delaiResolution'`, `value of type 'CanalReseau.Reglages' has no member 'volResolution'`.

- [ ] **Step 3 : les requêtes et leurs renvois** (`--etapes 3`).

`MaillageThread/Sonde/SondeUSB.swift`, fichier entier :

```swift
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

/// Attentes d'une commande sans id (`bonjour`, `etat`, `routeurs`, `voisins`, `annonces`) : les reponses les servent
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
/// ordre pour `bonjour`, `etat`, `routeurs`, `voisins` et `annonces`, par id et cible pour `diag` et `resoudre`
/// (8 en vol chacun, dans le desordre). Chaque requete a sa propre echeance.
actor SondeUSB: InterlocuteurSonde {
    enum Erreur: Error, LocalizedError, Equatable {
        case fermee
        case sansReponse(String)
        /// La sonde refuse, pour une autre raison qu'`occupee` : une ligne `erreur` pendant une
        /// demande de cle (firmware sans acces reseau...), ou le refus d'`etat`, de `voisins` ou de
        /// `routeurs` (la raison, telle que la sonde la donne).
        case refusee(String)
        /// La sonde n'a pas servi `etat`, `voisins` ou `routeurs` (`occupee` : verrou d'OpenThread
        /// refuse) : elle le dit tout de suite, sans attendre l'echeance.
        case occupee(String)

        var errorDescription: String? {
            switch self {
            case .fermee: String(localized: "liaison avec la sonde fermée")
            case .sansReponse(let commande): String(localized: "la sonde ne répond pas à « \(commande) »")
            case .refusee(let raison): String(localized: "la sonde refuse : \(raison)")
            case .occupee(let commande): String(localized: "la sonde est occupée et n'a pas répondu à « \(commande) »")
            }
        }
    }

    /// Attente de `bonjour`, `etat`, `routeurs`, `voisins`, `annonces` et `cle nouvelle` : 3 s en USB, qui ne perd rien ;
    /// 6 s par le reseau, au-dela du renvoi de 4 s du canal (comme les delais de Halo : 3 s en
    /// USB, 6 s a distance).
    static let delaiCommandeUSB: Duration = .seconds(3)
    static let delaiCommandeReseau: Duration = .seconds(6)
    /// Attente d'un `diag` au-dela de son delai : la sonde a du repondre (elle echoue elle-meme
    /// en `delai`). Par le reseau, le canal renvoie un diag sans reponse jusqu'a cette echeance.
    static let margeDiag: Duration = .seconds(5)
    /// Duree d'une resolution sur la sonde (firmware 1.1.0) : elle lit son cache d'adresses 15 s au plus, puis repond
    /// `introuvable`. L'app attend la marge en plus.
    static let delaiResolution: Duration = .seconds(15)

    private let canal: any CanalSonde
    /// Au-dela du delai donne a la sonde, elle a du repondre (elle echoue elle-meme en `delai`).
    private let marge: Duration
    let delaiCommande: Duration
    private let delaiResolution: Duration
    private var prochainId = 1
    /// Jetons des attentes de `bonjour`, `etat`, `routeurs` et `voisins` (jamais envoyes a la sonde).
    private var prochainJeton = 1
    /// `diag` en vol, par id, avec leur cible telle que la commande l'ecrit (RLOC16 en 4 hexa, ou adresse IPv6).
    private var attenteDiag: [Int: (cible: String, suite: CheckedContinuation<ResultatDiag, Never>)] = [:]
    /// `resoudre` en vol, par id, avec leur cible telle que la commande l'ecrit.
    private var attenteResolution: [Int: (cible: String, suite: CheckedContinuation<ResultatResolution, Never>)] = [:]
    /// `etat`, `routeurs` et `voisins` : la reponse, ou le refus de la sonde (`occupee`).
    private var attenteEtat = FileAttentes<Result<EtatSonde, Erreur>>()
    private var attenteBonjour = FileAttentes<Bonjour>()
    private var attenteRouteurs = FileAttentes<Result<[RouteurSonde], Erreur>>()
    private var attenteVoisins = FileAttentes<Result<[VoisinSonde], Erreur>>()
    private var attenteAnnonces = FileAttentes<[AnnonceSonde]>()
    /// Parties de la table des routeurs deja recues (lignes `suite`), en attendant la derniere.
    private var routeursRecus: [RouteurSonde] = []
    /// Routeurs entendus deja recus (lignes `suite` d'`annonces`), en attendant la derniere.
    private var annoncesRecues: [AnnonceSonde] = []
    private var attenteCle: [(id: Int, suite: CheckedContinuation<Result<ReponseCle, Erreur>?, Never>)] = []
    private var lecture: Task<Void, Never>?
    private(set) var fermee = false
    /// Dernier `bonjour` recu sans l'avoir demande : la sonde vient de (re)demarrer.
    private(set) var bonjourSpontane: Bonjour?

    init(canal: any CanalSonde, marge: Duration = SondeUSB.margeDiag, delaiCommande: Duration = SondeUSB.delaiCommandeUSB,
         delaiResolution: Duration = SondeUSB.delaiResolution) {
        self.canal = canal
        self.marge = marge
        self.delaiCommande = delaiCommande
        self.delaiResolution = delaiResolution
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
        return try e.get()
    }

    /// Table des routeurs, ses lignes `suite` reunies. `sansReponse` si la sonde ne la rend
    /// pas dans le delai (firmware sans `routeurs`) ; `occupee` tout de suite si elle la refuse
    /// (verrou d'OpenThread).
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
        return try t.get()
    }

    /// Routeurs voisins que la sonde entend, avec leur signal. `occupee` tout de suite si la sonde
    /// refuse (verrou d'OpenThread) ; `sansReponse` sans liste dans le delai (une ligne `erreur`,
    /// liste trop longue par le reseau, n'en est pas une).
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
        return try v.get()
    }

    /// Routeurs que la sonde entend (firmware 1.1.0), ses lignes `suite` reunies ; vide sur la ligne `vide`.
    /// `sansReponse` sans la derniere ligne dans le delai (un firmware 1.0.x repond `commande inconnue`).
    func annonces() async throws -> [AnnonceSonde] {
        guard !fermee else { throw Erreur.fermee }
        let jeton = nouveauJeton()
        let a = await withCheckedContinuation { c in
            attenteAnnonces.ajouter(jeton, c)
            canal.envoyer(CommandeSonde.annonces.ligne)
            Task {
                try? await Task.sleep(for: self.delaiCommande)
                self.expirerAnnonces(jeton)
            }
        }
        guard let a else { throw fermee ? Erreur.fermee : Erreur.sansReponse("annonces") }
        return a
    }

    private func nouveauJeton() -> Int {
        defer { prochainJeton += 1 }
        return prochainJeton
    }

    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        try await diag(String(format: "%04X", cible), delaiMs: delaiMs) {
            CommandeSonde.diag(cible: cible, tlv: tlv, id: $0, delaiMs: delaiMs)
        }
    }

    /// `diag` vers une adresse du reseau maille (le ML-EID d'un enfant).
    func diag(adresse: AdresseIPv6, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        try await diag(adresse.description, delaiMs: delaiMs) {
            CommandeSonde.diagAdresse(cible: adresse, tlv: tlv, id: $0, delaiMs: delaiMs)
        }
    }

    /// Envoie la commande de l'id suivant, et attend sa reponse, appariee par l'id et la cible (`cible`, telle que
    /// la commande l'ecrit).
    private func diag(_ cible: String, delaiMs: Int, commande: (Int) -> CommandeSonde) async throws -> ResultatDiag {
        guard !fermee else { throw Erreur.fermee }
        let id = prochainId
        prochainId += 1
        let ligne = commande(id).ligne
        let r = await withCheckedContinuation { c in
            attenteDiag[id] = (cible, c)
            canal.envoyer(ligne)
            Task {
                try? await Task.sleep(for: .milliseconds(delaiMs) + self.marge)
                self.expirerDiag(id)
            }
        }
        if r.erreur == "fermee" { throw Erreur.fermee }
        return r
    }

    /// `resoudre <adresse> <id>` (firmware 1.1.0) : la reponse de meme id et de meme cible, ou `delai` apres les 15 s
    /// de la sonde et la marge (firmware sans resolution, ligne perdue).
    func resoudre(_ adresse: AdresseIPv6) async throws -> ResultatResolution {
        guard !fermee else { throw Erreur.fermee }
        let id = prochainId
        prochainId += 1
        let r = await withCheckedContinuation { c in
            attenteResolution[id] = (adresse.description, c)
            canal.envoyer(CommandeSonde.resoudre(adresse: adresse, id: id).ligne)
            Task {
                try? await Task.sleep(for: self.delaiResolution + self.marge)
                self.expirerResolution(id)
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

    /// De meme pour `annonces`.
    private func expirerAnnonces(_ jeton: Int) {
        if attenteAnnonces.expirer(jeton) == 0 { annoncesRecues = [] }
    }

    /// Ligne d'`annonces` : gardee jusqu'a la derniere (`suite` faux), qui rend la liste entiere a la premiere attente.
    /// Sans attente (reponse apres le delai), la liste est oubliee.
    private func recevoirAnnonces(_ p: PartieAnnonces) {
        annoncesRecues += p.liste
        guard !p.suite else { return }
        let liste = annoncesRecues
        annoncesRecues = []
        attenteAnnonces.servir(liste)
    }

    /// Partie de la table : gardee jusqu'a la derniere (`suite` faux), qui rend la table entiere
    /// a la premiere attente ; l'erreur (`occupee`) la termine tout de suite, sans table. Sans
    /// attente (reponse apres le delai), la table est oubliee.
    private func recevoirRouteurs(_ p: PartieRouteurs) {
        if p.erreur == nil {
            routeursRecus += p.liste
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

    private func expirerDiag(_ id: Int) {
        guard let a = attenteDiag.removeValue(forKey: id) else { return }
        a.suite.resume(returning: ResultatDiag(id: id, cible: a.cible, ok: false, erreur: "delai"))
    }

    private func expirerResolution(_ id: Int) {
        guard let a = attenteResolution.removeValue(forKey: id) else { return }
        a.suite.resume(returning: ResultatResolution(id: id, cible: a.cible, ok: false, erreur: "delai"))
    }

    private func recevoir(_ ligne: Data) {
        switch MessageSonde.lire(ligne) {
        case .diag(let r)?:
            // Par l'id et la cible : une reponse tardive d'une connexion precedente (meme id,
            // autre cible) ne sert pas cette requete, qui attend la sienne.
            if let a = attenteDiag[r.id], r.cible == a.cible {
                attenteDiag[r.id] = nil
                a.suite.resume(returning: r)
            }
        case .resoudre(let r)?:
            if let a = attenteResolution[r.id], r.cible == a.cible {
                attenteResolution[r.id] = nil
                a.suite.resume(returning: r)
            }
        case .annonces(let p)?:
            recevoirAnnonces(p)
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
            a.suite.resume(returning: ResultatDiag(id: id, cible: a.cible, ok: false, erreur: "fermee"))
        }
        attenteDiag = [:]
        for (id, a) in attenteResolution {
            a.suite.resume(returning: ResultatResolution(id: id, cible: a.cible, ok: false, erreur: "fermee"))
        }
        attenteResolution = [:]
        attenteAnnonces.liberer()
        annoncesRecues = []
        attenteEtat.liberer()
        attenteBonjour.liberer()
        attenteRouteurs.liberer()
        attenteVoisins.liberer()
        routeursRecus = []
        attenteCle.forEach { $0.suite.resume(returning: nil) }
        attenteCle = []
    }
}
```

Dans `MaillageThread/Sonde/Reseau/CanalReseau.swift`, remplacer :

```swift
/// - Chaque commande part en `<rid> <commande>` (rid decimal, croissant) ; sans aucune
///   reponse, elle repart avec le meme rid a 2 s puis a 4 s : la carte ne relance rien, elle
///   renvoie la reponse gardee (ou se tait, `diag` encore en vol). Un `diag` repart ensuite
///   1 s apres la fin de son vol, puis tous les 3 s, jusqu'a 1 s avant l'echeance de
///   `SondeUSB` : sa reponse perdue apres le vol se redemande.
/// - Au plus 18 nouvelles commandes par seconde glissante (la carte en accepte 20 par session,
///   au-dela elle se tait) : les suivantes attendent, dans l'ordre ; les renvois ne comptent
```

par :

```swift
/// - Chaque commande part en `<rid> <commande>` (rid decimal, croissant) ; sans aucune
///   reponse, elle repart avec le meme rid a 2 s puis a 4 s : la carte ne relance rien, elle
///   renvoie la reponse gardee (ou se tait, `diag` ou `resoudre` encore en vol). Un `diag` repart
///   ensuite 1 s apres la fin de son vol, puis tous les 3 s, jusqu'a 1 s avant l'echeance de
///   `SondeUSB` : sa reponse perdue apres le vol se redemande ; un `resoudre` de meme, son vol
///   etant de 15 s.
/// - Au plus 18 nouvelles commandes par seconde glissante (la carte en accepte 20 par session,
///   au-dela elle se tait) : les suivantes attendent, dans l'ordre ; les renvois ne comptent
```

Dans `MaillageThread/Sonde/Reseau/CanalReseau.swift`, remplacer :

```swift
        var margeDiag: Duration = SondeUSB.margeDiag
        var avanceDiag: Duration = .seconds(1)
        /// Silence (aucune ligne recue) avant une veille : 10 s, comme le ping de Halo. La carte
        /// donne a un nouveau client la place d'une session muette depuis 30 s : la veille garde
```

par :

```swift
        var margeDiag: Duration = SondeUSB.margeDiag
        var avanceDiag: Duration = .seconds(1)
        /// Vol d'un `resoudre` (firmware 1.1.0) : 15 s au plus sur la carte, muette pendant ce temps.
        var volResolution: Duration = SondeUSB.delaiResolution
        /// Silence (aucune ligne recue) avant une veille : 10 s, comme le ping de Halo. La carte
        /// donne a un nouveau client la place d'une session muette depuis 30 s : la veille garde
```

Dans `MaillageThread/Sonde/Reseau/CanalReseau.swift`, remplacer :

```swift

        /// Renvois d'une commande (sans fin de ligne), comptes depuis son premier envoi :
        /// `renvois`, puis pour un `diag` ceux d'apres son vol, au-dela du dernier de `renvois`
        /// (2, 4, 7 et 10 s pour un diag de 6000 ms ; 2, 4, 9 et 12 s pour 8000 ms).
        func renvois(pour commande: String) -> [Duration] {
            guard let ms = Self.delaiDiag(commande), let fixe = renvois.last else { return renvois }
            var r = renvois
            let vol = Duration.milliseconds(ms)
            let dernier = vol + margeDiag - avanceDiag
            var t = vol + apresVolDiag
```

par :

```swift

        /// Renvois d'une commande (sans fin de ligne), comptes depuis son premier envoi :
        /// `renvois`, puis pour un `diag` ou un `resoudre` ceux d'apres son vol, au-dela du dernier de
        /// `renvois` (2, 4, 7 et 10 s pour un diag de 6000 ms ; 2, 4, 9 et 12 s pour 8000 ms ; 2, 4, 16
        /// et 19 s pour un resoudre).
        func renvois(pour commande: String) -> [Duration] {
            guard let vol = volEnCours(commande), let fixe = renvois.last else { return renvois }
            var r = renvois
            let dernier = vol + margeDiag - avanceDiag
            var t = vol + apresVolDiag
```

Dans `MaillageThread/Sonde/Reseau/CanalReseau.swift`, remplacer :

```swift
            }
            return r
        }

```

par :

```swift
            }
            return r
        }

        /// Duree pendant laquelle la carte se tait sur la commande : le delai d'un `diag`, ou le vol d'un
        /// `resoudre <adresse> <id>` ; nil pour une autre commande.
        func volEnCours(_ commande: String) -> Duration? {
            if let ms = Self.delaiDiag(commande) { return .milliseconds(ms) }
            let mots = commande.split(separator: " ")
            return mots.count == 3 && mots[0] == "resoudre" ? volResolution : nil
        }

```

- [ ] **Step 4 : les voir passer.** La commande du step 2.

Expected : `Test run with 82 tests in 3 suites passed`, `** TEST SUCCEEDED **` (une trentaine de secondes : les délais des requêtes).

- [ ] **Step 5 : toute la suite.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh`

Expected : `Test run with 433 tests in 43 suites passed` (cœur) et `Test run with 414 tests in 35 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add MaillageThread/Sonde/Reseau/CanalReseau.swift MaillageThread/Sonde/SondeUSB.swift MaillageThreadTests/CanalReseauTests.swift MaillageThreadTests/SondeTests.swift && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --cached --name-only | sed "s|^|$PWD/|") && git commit -q -F - <<'EOF'
Demander a la sonde ses annonces, ses resolutions et le diagnostic d'une adresse, par l'USB et par le reseau

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` ; `0`.

---

### Task 7: La tournée : l'écoute, la résolution des parents à la place du balayage, les compteurs des enfants

**Files :**
- Create : `MaillageCoeur/Maillage/Resolution.swift`
- Modify : `MaillageCoeur/Maillage/Tournee.swift` (en entier), `MaillageCoeur/Maillage/Maillage.swift`, `MaillageCoeur/Maillage/Rapprochement.swift`, `MaillageCoeur/Maillage/SuiviMaillage.swift`, `MaillageCoeur/Demo/MaillageDemo.swift`, `MaillageThread/Sonde/TexteTournee.swift`, `MaillageThread/Surveillance/Surveillance.swift`, `MaillageThread/Vues/Pieces/MorceauxFenetre.swift` (blocs, ou en entier) ; les tests : `MaillageCoeurTests/TourneeTests.swift` (en entier), `SuiviMaillageTests.swift`, `MaillageTests.swift`, `HistoriqueTests.swift`, `GrapheReseauTests.swift`, `RapprochementTests.swift`, `MaillageDemoTests.swift`, `MaillageThreadTests/AffichageSondeTests.swift`, `FenetreTests.swift`, `JournalMaillageTests.swift`, `SondeTests.swift` (blocs) ; `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json` (outils)

**Interfaces:**
- Consumes : `AnnonceSonde`, `ResultatResolution`, `CompteursMac` (tâche 4) ; `ConstructionMaillage.ecoute`, `lien`, `annoncesRecues`, `QualiteCompteurs` (tâche 5) ; `SondeUSB.annonces`, `diag(adresse:)`, `resoudre` (tâche 6).
- Produces :
  - `InterlocuteurSonde` gagne `annonces()`, `diag(adresse:_:delaiMs:)` et `resoudre(_:)` ;
  - `AvancementTournee.Etape` : `.resolution` et `.compteurs` à la place de `.balayage` ; `.etatSonde` compte 4 requêtes (`etat`, `routeurs`, `voisins`, `annonces`) ;
  - `MemoireTournee` : `resolutions` (`[String: ResolutionAppareil]`, par identifiant d'appareil), `demandes`, `derniereResolution`, `compteurs` (`[String: CompteursMac]`) ; plus de `balayes`, `dernierBalayage`, `muetsBalayes`, `dejaRepondu` ;
  - `Tournee.tlvCompteurs` (`[9]`), `periodeResolution` (30 min) ; plus de `tlvBalayage`, `delaiBalayage`, `numerosMax`, `apresDernier`, `periodeBalayage` ; `executer(_:memoire:maintenant:appareils:avancement:)` ;
  - `AppareilAResoudre(id:partition:adresse:)` et `AppareilAResoudre.depuis(_:)` (les appareils Thread d'un instantané, à leur adresse sur le préfixe OMR de leur partition) ; `ResolutionAppareil` (`rloc16`, `mleid`, `adresse`, `date`, `qualite`, `echecs` ; `parent`) ;
  - `SourceEnfant.balayage` retiré ; `Maillage.resolution` à la place de `Maillage.balayage` ; `SuiviMaillage` compte une absence sous un routeur muet une fois par résolution ;
  - `TexteTournee` : « Résolution des parents » et « Compteurs des enfants », à la place de « Balayage des routeurs muets ».

La tournée (spec, sections 2.1 à 2.3) : après `etat`, `routeurs` et `voisins`, `annonces` (sans réponse, la tournée continue sans l'écoute, sans la résolution et sans les compteurs) ; chaque annonce de la partition relie un RLOC16 à une ExtMac ; puis la liste des routeurs, les routeurs, la pile et la Network Data, comme avant ; puis l'écoute : la Route64 de chaque annonce, datée de son âge, fusionnée avec le diagnostic ; puis la résolution des appareils de la partition (toutes les 30 min, et les appareils nouveaux à la tournée suivante ; 8 en vol) ; puis la TLV 9 au ML-EID de chaque enfant résolu sous un routeur muet ; puis les identités des enfants des tables ; enfin les enfants résolus sous leur parent muet.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`). `SondeRejouee` rejoue aussi `annonces`, `resoudre` et le diagnostic d'une adresse ; les tests du balayage deviennent ceux de la résolution.

`MaillageCoeurTests/TourneeTests.swift`, fichier entier :

```swift
import Foundation
import Synchronization
import Testing
@testable import MaillageCoeur

/// Avancements recus d'une tournee, dans l'ordre.
final class ReleveAvancement: Sendable {
    private let liste = Mutex<[AvancementTournee]>([])

    func noter(_ a: AvancementTournee) {
        liste.withLock { $0.append(a) }
    }

    var avancements: [AvancementTournee] { liste.withLock { $0 } }

    /// Etapes dans l'ordre ou elles commencent (une etape revenue apres une autre y serait deux fois).
    var etapes: [AvancementTournee.Etape] {
        avancements.map(\.etape).reduce(into: []) { if $0.last != $1 { $0.append($1) } }
    }

    func de(_ e: AvancementTournee.Etape) -> [AvancementTournee] { avancements.filter { $0.etape == e } }

    /// Compteurs croissants : `fait` monte de 0 ou 1 a chaque appel, le total ne baisse jamais.
    static func croissants(_ a: [AvancementTournee]) -> Bool {
        zip(a, a.dropFirst()).allSatisfy { p, s in (0...1).contains(s.fait - p.fait) && s.total >= p.total }
    }
}

/// Sonde rejouee : repond avec les TLV de la capture, echoue en `delai` pour le reste (ou en
/// `trop_long`, reponse de plus de 1100 octets par le reseau, pour `tropLongs` ; ou refuse la
/// requete, pour `refus`), et note ses requetes. Depuis le firmware 1.1.0 : ses annonces, et ses
/// resolutions (`introuvable` pour une adresse qu'elle ne connait pas).
struct SondeRejouee: InterlocuteurSonde {
    actor Registre {
        /// Requetes `diag`, "<cible>|<tlv,...>", et `resoudre`, "<adresse>|resoudre".
        var requetes: [String] = []
        /// Demandes de la table des routeurs (`routeurs`).
        var tables = 0
        /// Demandes des voisins (`voisins`).
        var voisins = 0
        /// Demandes des routeurs entendus (`annonces`).
        var annonces = 0
        func noter(_ r: String) { requetes.append(r) }
        func noterTable() { tables += 1 }
        func noterVoisins() { voisins += 1 }
        func noterAnnonces() { annonces += 1 }
    }

    /// La sonde ne rend pas sa table (firmware sans `routeurs`, verrou d'OpenThread refuse).
    struct SansTable: Error {}
    /// La sonde ne rend pas ses voisins (verrou d'OpenThread refuse, liste trop longue).
    struct SansVoisins: Error {}
    /// La sonde ne rend pas ses annonces (firmware 1.0.x).
    struct SansAnnonces: Error {}

    let etatSonde: EtatSonde
    /// "<cible>|<tlv,...>" -> TLV hexa.
    let reponses: [String: String]
    /// Table des routeurs de la sonde ; nil : elle ne la rend pas.
    var table: [RouteurSonde]? = []
    /// "<cible>|<tlv,...>" dont la reponse est trop longue pour le reseau.
    var tropLongs: Set<String> = []
    /// Refus de la sonde (`occupee`, `suspendue`...) d'une requete "<cible>|<tlv,...>" : elle ne
    /// part pas ; nil : pas de refus.
    var refus: @Sendable (String) -> String? = { _ in nil }
    /// "<cible>|<tlv,...>" dont la reponse arrive plus tard ; les autres reviennent aussitot.
    var retards: [String: Duration] = [:]
    /// Routeurs voisins que la sonde entend ; nil : elle ne rend pas la liste.
    var listeVoisins: [VoisinSonde]? = []
    /// Routeurs dont la sonde entend les annonces ; nil : elle ne les rend pas (firmware 1.0.x).
    var listeAnnonces: [AnnonceSonde]? = []
    /// Resolutions, par adresse (sa forme courte) ; une autre adresse : `introuvable`.
    var resolutions: [String: ResultatResolution] = [:]
    let registre = Registre()

    /// Cle d'une requete : "<cible>|<tlv,...>".
    static func cle(_ cible: UInt16, _ tlv: [UInt8]) -> String {
        String(format: "%04X|", cible) + tlv.map(String.init).joined(separator: ",")
    }

    /// Cle d'une requete vers une adresse : "<adresse>|<tlv,...>".
    static func cle(_ adresse: AdresseIPv6, _ tlv: [UInt8]) -> String {
        "\(adresse)|" + tlv.map(String.init).joined(separator: ",")
    }

    /// Cle d'une resolution : "<adresse>|resoudre".
    static func cleResolution(_ adresse: AdresseIPv6) -> String { "\(adresse)|resoudre" }

    func etat() async throws -> EtatSonde { etatSonde }

    func routeurs() async throws -> [RouteurSonde] {
        await registre.noterTable()
        guard let table else { throw SansTable() }
        return table
    }

    func voisins() async throws -> [VoisinSonde] {
        await registre.noterVoisins()
        guard let listeVoisins else { throw SansVoisins() }
        return listeVoisins
    }

    func annonces() async throws -> [AnnonceSonde] {
        await registre.noterAnnonces()
        guard let listeAnnonces else { throw SansAnnonces() }
        return listeAnnonces
    }

    func diag(adresse: AdresseIPv6, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        let cle = Self.cle(adresse, tlv)
        await registre.noter(cle)
        if let e = refus(cle) { return ResultatDiag(id: 0, cible: "\(adresse)", ok: false, erreur: e) }
        guard let t = reponses[cle] else {
            return ResultatDiag(id: 0, cible: "\(adresse)", ok: false, ms: delaiMs, erreur: "delai")
        }
        return ResultatDiag(id: 0, cible: "\(adresse)", ok: true, ms: 900, code: "2.04", tlv: t)
    }

    func resoudre(_ adresse: AdresseIPv6) async throws -> ResultatResolution {
        let cle = Self.cleResolution(adresse)
        await registre.noter(cle)
        if let e = refus(cle) { return ResultatResolution(id: 0, cible: "\(adresse)", ok: false, erreur: e) }
        return resolutions["\(adresse)"] ?? ResultatResolution(id: 0, cible: "\(adresse)", ok: false, erreur: "introuvable")
    }

    /// Table des 7 routeurs de la capture, telle qu'une sonde en FED la donne : tous par leur
    /// RLOC16 ; l'ExtMac des seuls routeurs `entendus` (RLOC16 -> ExtMac inventee).
    static func table(entendus: [UInt16: String] = [:]) -> [RouteurSonde] {
        [0x0400, 0x5000, 0x6000, 0xAC00, 0xB400, 0xCC00, 0xE400].map { (r: UInt16) in
            let ext = entendus[r]
            return RouteurSonde(id: Int(r >> 10), rloc16: String(format: "%04X", r), ext: ext, lqIn: ext == nil ? 0 : 3,
                                lqOut: ext == nil ? 0 : 3, age: 4, lien: ext != nil)
        }
    }

    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        let cle = Self.cle(cible, tlv)
        await registre.noter(cle)
        if let e = refus(cle) {
            return ResultatDiag(id: 0, cible: String(format: "%04X", cible), ok: false, erreur: e)
        }
        if let d = retards[cle] { try await Task.sleep(for: d) }
        if tropLongs.contains(cle) {
            return ResultatDiag(id: 0, cible: String(format: "%04X", cible), ok: false, erreur: "trop_long")
        }
        guard let t = reponses[cle] else {
            return ResultatDiag(id: 0, cible: String(format: "%04X", cible), ok: false, ms: delaiMs, erreur: "delai")
        }
        return ResultatDiag(id: 0, cible: String(format: "%04X", cible), ok: true, ms: 50, code: "2.04", tlv: t)
    }

    /// Etat de la capture apres le changement de parent : AC09, enfant de AC00 (muet), qu'elle entend
    /// a -89 dBm ; `ext` : l'ExtMac de la sonde (absente de la capture) ; `table` : celle des routeurs
    /// de la sonde, sans ExtMac par defaut (la capture vient d'une sonde en MED) ; `voisins` : aucun par
    /// defaut (la capture n'en a pas).
    static func capture(chef: Int = 24, ext: String? = nil, reponsesEnPlus: [String: String] = [:],
                        table: [RouteurSonde]? = SondeRejouee.table(), tropLongs: Set<String> = [],
                        voisins: [VoisinSonde]? = [], annonces: [AnnonceSonde]? = [],
                        resolutions: [String: ResultatResolution] = [:]) throws -> SondeRejouee {
        let champExt = ext.map { #","ext":"\#($0)""# } ?? ""
        let base = #"{"v":1,"t":"etat","role":"child","rloc16":"AC09"\#(champExt),"mode":"rn","parent":{"rloc16":"AC00","ext":"E000000000000007","lqIn":3,"lqOut":3,"rssi":-89},"partition":"46CBEBCD","chef":\#(chef),"canal":25,"prefixeMaille":"FD00111122220C87","xp":"A0A1A2A3A4A5A6A7","suspendue":false}"#
        guard case .etat(let e)? = MessageSonde.lire(Data(base.utf8)) else { throw CaptureSonde.ErreurCapture(id: 0) }
        var r: [String: String] = [
            "6000|5,6": try CaptureSonde.tlv(204),
            "5000|0,1,5,16,8,24": try CaptureSonde.tlv(104),
            "6000|0,1,5,16,8,24": try CaptureSonde.tlv(106),
            "5000|25,26,27,28": try CaptureSonde.tlv(105),
            "6000|25,26,27,28": try CaptureSonde.tlv(107),
            "5000|7": try CaptureSonde.tlv(206),
            "AC01|0,1,2,8": try CaptureSonde.tlv(411),
            "5004|0,8": try CaptureSonde.tlv(116),
            "5001|0,8": try CaptureSonde.tlv(117),
            "6003|0,8": try CaptureSonde.tlv(118),
        ]
        for (n, id) in zip(3...8, 503...508) { r[String(format: "AC%02X|0,1,2,8", n)] = try CaptureSonde.tlv(id) }
        r.merge(reponsesEnPlus) { _, b in b }
        return SondeRejouee(etatSonde: e, reponses: r, table: table, tropLongs: tropLongs, listeVoisins: voisins,
                            listeAnnonces: annonces, resolutions: resolutions)
    }

    /// La meme sonde, avec seulement les reponses dont la cle est gardee ; registre neuf.
    func filtree(_ garder: (String) -> Bool) -> SondeRejouee {
        SondeRejouee(etatSonde: etatSonde, reponses: reponses.filter { garder($0.key) }, table: table, tropLongs: tropLongs,
                     refus: refus, retards: retards, listeVoisins: listeVoisins, listeAnnonces: listeAnnonces,
                     resolutions: resolutions)
    }

    /// La meme sonde, qui refuse (`erreur`) les requetes dont la cle est choisie ; registre neuf.
    func refusant(_ erreur: String = "occupee", _ choisies: @escaping @Sendable (String) -> Bool) -> SondeRejouee {
        SondeRejouee(etatSonde: etatSonde, reponses: reponses, table: table, tropLongs: tropLongs,
                     refus: { choisies($0) ? erreur : nil }, retards: retards, listeVoisins: listeVoisins,
                     listeAnnonces: listeAnnonces, resolutions: resolutions)
    }
}

/// Sonde dont la liaison se ferme a une requete "<cible>|<tlv,...>" : `diag` y echoue par une
/// erreur, comme `SondeUSB` une fois la liaison fermee.
struct SondeFermee: InterlocuteurSonde {
    struct Fermee: Error {}

    let base: SondeRejouee
    let sur: String

    func etat() async throws -> EtatSonde { try await base.etat() }
    func routeurs() async throws -> [RouteurSonde] { try await base.routeurs() }
    func voisins() async throws -> [VoisinSonde] { try await base.voisins() }
    func annonces() async throws -> [AnnonceSonde] { try await base.annonces() }

    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        if SondeRejouee.cle(cible, tlv) == sur { throw Fermee() }
        return try await base.diag(cible, tlv, delaiMs: delaiMs)
    }

    func diag(adresse: AdresseIPv6, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        if SondeRejouee.cle(adresse, tlv) == sur { throw Fermee() }
        return try await base.diag(adresse: adresse, tlv, delaiMs: delaiMs)
    }

    func resoudre(_ adresse: AdresseIPv6) async throws -> ResultatResolution {
        if SondeRejouee.cleResolution(adresse) == sur { throw Fermee() }
        return try await base.resoudre(adresse)
    }
}

/// Requetes en vol pendant un essai de `parallele` : le maximum atteint, et les requetes parties
/// que la requete retenue a vues a sa sortie.
actor EnVol {
    private(set) var enVol = 0
    private(set) var maximum = 0
    private(set) var parties = 0
    private(set) var vues: Int?

    func partir() {
        enVol += 1
        parties += 1
        maximum = max(maximum, enVol)
    }

    func revenir() { enVol -= 1 }

    /// Retient la requete jusqu'a ce que `n` soient parties (2 s au plus) ; note celles qu'elle a vues.
    func retenir(jusqua n: Int) async {
        var essais = 0
        while parties < n && essais < 400 {
            try? await Task.sleep(for: .milliseconds(5))
            essais += 1
        }
        vues = parties
    }
}

extension Tournee {
    /// Tournee qui doit rendre un maillage (tests) : le maillage et la memoire ; nil sans maillage.
    static func complete(_ sonde: some InterlocuteurSonde, memoire: MemoireTournee, maintenant: Date,
                         appareils: [AppareilAResoudre] = [], avancement: (@Sendable (AvancementTournee) -> Void)? = nil)
        async throws -> (maillage: Maillage, memoire: MemoireTournee)? {
        let r = try await executer(sonde, memoire: memoire, maintenant: maintenant, appareils: appareils,
                                   avancement: avancement)
        return r.maillage.map { ($0, r.memoire) }
    }
}

@Suite("Tournee de la sonde")
struct TourneeTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    /// Identifiant de routeur de la cible d'une requete "<cible>|<tlv,...>".
    static func routeur(_ requete: String) -> Int? {
        UInt16(requete.prefix(4), radix: 16).map { Int($0 >> 10) }
    }

    // MARK: Donnees de la sonde tout-en-un (inventees)

    /// Adresse OMR inventee d'un appareil : fd00:aaaa:bbbb:1::<n>.
    static func omr(_ n: Int) -> AdresseIPv6 { AdresseIPv6("fd00:aaaa:bbbb:1::\(String(n, radix: 16))")! }

    /// Appareils de la partition de la capture, et leur adresse OMR : sous AC00 (routeur Apple, muet), resolu par son
    /// RLOC16 (0A) ; sous AC00, resolu par celui de l'enfant (0B, AC05) ; introuvable (0C) ; sous le 20, qui repond (04) ;
    /// le routeur AC00 lui-meme (07) ; la sonde (AA) ; un accessoire HomeKit, dont l'hote n'est pas l'ExtMac, sous AC00 ;
    /// puis un appareil d'une autre partition.
    static let appareils: [AppareilAResoudre] = [
        AppareilAResoudre(id: "E00000000000000A", partition: "46CBEBCD", adresse: omr(0x0A)),
        AppareilAResoudre(id: "E00000000000000B", partition: "46CBEBCD", adresse: omr(0x0B)),
        AppareilAResoudre(id: "E00000000000000C", partition: "46CBEBCD", adresse: omr(0x0C)),
        AppareilAResoudre(id: "E000000000000004", partition: "46CBEBCD", adresse: omr(0x04)),
        AppareilAResoudre(id: "E000000000000007", partition: "46CBEBCD", adresse: omr(0x07)),
        AppareilAResoudre(id: "E0000000000000AA", partition: "46CBEBCD", adresse: omr(0xAA)),
        AppareilAResoudre(id: "Prise-HomeKit", partition: "46CBEBCD", adresse: omr(0x50)),
        AppareilAResoudre(id: "E0000000000000F1", partition: "73586B68", adresse: omr(0xF1)),
    ]

    /// Les resolutions de la sonde, par adresse : le RLOC16 du parent (AC00, routeur Apple) ou de l'enfant (AC05 ;
    /// 5004 sous le 20) ; le ML-EID (fd00:1111:2222:c87::<n>) quand le cache le donne.
    static let resolutions: [String: ResultatResolution] = {
        func ok(_ n: Int, _ rloc16: String, mleid: Bool) -> (String, ResultatResolution) {
            let cible = "\(omr(n))"
            return (cible, ResultatResolution(id: 0, cible: cible, ok: true, ms: 300, rloc16: rloc16,
                                              mleid: mleid ? String(format: "FD00111122220C87%016lX", n) : nil))
        }
        return Dictionary(uniqueKeysWithValues: [ok(0x0A, "AC00", mleid: true), ok(0x0B, "AC05", mleid: false),
                                                 ok(0x04, "5004", mleid: true), ok(0x07, "AC00", mleid: false),
                                                 ok(0x50, "AC00", mleid: true)])
    }()

    /// ML-EID d'un appareil resolu : fd00:1111:2222:c87::<n>.
    static func mleid(_ n: Int) -> AdresseIPv6 { AdresseIPv6("fd00:1111:2222:c87::\(String(n, radix: 16))")! }

    /// Requete des compteurs MAC d'un enfant, a son ML-EID.
    static func cleCompteurs(_ n: Int) -> String { SondeRejouee.cle(mleid(n), Tournee.tlvCompteurs) }

    /// TLV 9 (hexa) : `envois` trames unicast envoyees, dont `echecs` en echec.
    static func compteurs(envois: UInt32, echecs: UInt32) -> String {
        let c: [UInt32] = [0, 0, echecs, 500, 20, 0, envois, 12, 0]
        return Data([TypeTLV.compteursMac, 36] + c.flatMap { v in (0..<4).map { UInt8(truncatingIfNeeded: v >> (24 - 8 * $0)) } }).hexa
    }

    /// La sonde de la capture, la sonde ayant pour ExtMac E0000000000000AA, avec ses resolutions.
    static func sondeResolue(reponsesEnPlus: [String: String] = [:], annonces: [AnnonceSonde]? = [],
                             resolutions: [String: ResultatResolution] = TourneeTests.resolutions) throws -> SondeRejouee {
        try SondeRejouee.capture(ext: "E0000000000000AA", reponsesEnPlus: reponsesEnPlus, annonces: annonces,
                                 resolutions: resolutions)
    }

    /// Annonce entendue d'un routeur de la capture, de la partition de la capture sauf `partition` ; Route64 des 7
    /// routeurs, avec les liens de `qualites` (sortante et entrante, vues par lui).
    static func annonce(_ rloc16: String, _ ext: String, qualites: [Int: (sortante: Int, entrante: Int)], age: Int,
                        partition: String = "46CBEBCD") -> AnnonceSonde {
        let route = String(Self.route64([1, 20, 24, 43, 45, 51, 57], qualites: qualites).dropFirst(4))
        return AnnonceSonde(rloc16: rloc16, ext: ext, partition: partition, route64: route, seq: 1, rssi: -70, rssiMin: -80,
                            rssiMax: -60, nb: 4, ageS: age)
    }

    /// Premiere tournee : routeurs, roles, liens, enfants des tables, memoire ; aucun appareil a resoudre.
    @Test func premiere() async throws {
        let sonde = try SondeRejouee.capture()
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.partition == "46CBEBCD")
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        #expect(m.chef?.id == 24)
        #expect(m.routeurs.filter(\.muet).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m.routeurs.filter(\.bordure).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m.routeur(45)?.bbrPrincipal == true)
        #expect(m.routeur(43)?.extMac == "E000000000000007", "parent de la sonde")
        #expect(m.routeur(20)?.pile?.hasPrefix("SL-OPENTHREAD") == true)
        #expect(m.liens.count == 7)
        #expect(m.enfants(de: 43).map(\.rloc16) == [0xAC09], "la sonde ; sans appareil a resoudre, aucun enfant resolu")
        #expect(m.enfants(de: 43).last?.source == .sonde)
        #expect(m.enfants.count == 7)
        let de20 = m.enfants(de: 20)
        #expect(de20.map(\.extMac) == ["E000000000000005", "E000000000000004"], "tables : identifies une fois")
        #expect(de20.first?.adresses.count == 4)
        #expect(m.enfants(de: 24).filter { $0.extMac == nil }.map(\.rloc16) == [0x6002, 0x6005, 0x6006], "sans reponse")
        #expect(mem.echecs[43] == 1)
        #expect(!mem.estMuet(43), "muet a partir de 2 echecs de suite")
        #expect(mem.repondants == [20, 24])
        #expect(mem.identites[0xAC00] == "E000000000000007")
        #expect(mem.identites[0x5000] == "E000000000000002")
        #expect(mem.derniereResolution == Self.t0, "une resolution complete, sans appareil")
        #expect(m.resolution == Self.t0, "le maillage dit de quelle resolution viennent ses enfants resolus")
        #expect(m.annoncesLues && m.couverture == CouvertureEcoute(entendus: 0, routeurs: 7), "rien d'entendu")
        let requetes = await sonde.registre.requetes
        #expect(!requetes.contains { $0.hasSuffix("|resoudre") })
        #expect(requetes.filter { $0.hasSuffix("|25,26,27,28") }.count == 2)
        #expect(requetes.filter { $0.hasSuffix("|0,8") }.count == 6, "les 6 enfants des tables")
        #expect(mem.identifies.count == 3)
    }

    /// Deuxieme tournee (5 min) : les muets le deviennent ; pas de nouvelle resolution ;
    /// pile deja connue ; les enfants des tables sans reponse attendent 30 min.
    /// Troisieme (10 min) : les muets ne sont plus interroges.
    @Test func suivantes() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let avant2 = await sonde.registre.requetes.count
        let (m2, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 300))
        let requetes2 = await sonde.registre.requetes.dropFirst(avant2)
        #expect(requetes2.count == 9, "chef, 7 routeurs, Network Data ; pas 6002, 6005, 6006, demandes il y a 5 min")
        #expect(mem2.estMuet(43))
        #expect(mem2.muetInterroge[43] == Self.t0 + 300)
        #expect(m2.enfants(de: 43).count == 1, "la sonde")
        #expect(m2.resolution == Self.t0, "pas de nouvelle resolution : celle de la premiere tournee")

        let avant3 = await sonde.registre.requetes.count
        let (m3, _) = try #require(try await Tournee.complete(sonde, memoire: mem2, maintenant: Self.t0 + 600))
        let requetes3 = Array(await sonde.registre.requetes.dropFirst(avant3))
        #expect(requetes3.first == "6000|5,6", "la liste des routeurs d'abord")
        #expect(requetes3.sorted() == ["5000|0,1,5,16,8,24", "5000|7", "6000|0,1,5,16,8,24", "6000|5,6"],
                "en parallele : dans le desordre")
        #expect(m3.routeurs.filter(\.muet).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m3.enfants.count == 7)
        #expect(m3.resolution == Self.t0)
    }

    /// Resolution de nouveau apres 30 min, et les 6 identites des enfants des tables redemandees
    /// parce que 30 min ont passe ; une seconde avant, ni l'une ni les autres.
    @Test func resolutionDue() async throws {
        let sonde = try Self.sondeResolue()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: Self.appareils))
        let avant = await sonde.registre.requetes.count
        let (m2, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 1799,
                                                                appareils: Self.appareils))
        let pendant = await sonde.registre.requetes.count
        let (m3, _) = try #require(try await Tournee.complete(sonde, memoire: mem2, maintenant: Self.t0 + 1800,
                                                             appareils: Self.appareils))
        #expect(m2.resolution == Self.t0 && m3.resolution == Self.t0 + 1800, "une nouvelle resolution, une nouvelle date")
        let toutes = await sonde.registre.requetes
        let presque = toutes[avant..<pendant], requetes = toutes[pendant...]
        #expect(presque.filter { $0.hasSuffix("|resoudre") || $0.hasSuffix("|0,8") || $0.hasSuffix("|9") }.isEmpty,
                "29 min 59 s : rien de du")
        #expect(requetes.filter { $0.hasSuffix("|resoudre") }.count == 6)
        #expect(requetes.filter { $0.hasSuffix("|9") }.count == 2, "les compteurs, avec la resolution")
        #expect(requetes.filter { $0.hasSuffix("|0,8") }.count == 6, "30 min ont passe : identites redemandees")
    }

    /// Resolution des parents (spec de la sonde tout-en-un, section 2.2) : chaque appareil de la partition de la sonde,
    /// elle exceptee, sauf ceux d'une autre partition. Le parent est le RLOC16 rendu, sans ses 10 bits de poids faible.
    /// Sous AC00, muet : l'appareil resolu par le RLOC16 de AC00 recoit un numero invente (AE00, AE01 : bit 9, dans
    /// l'ordre des appareils), celui resolu par AC05 le garde ; l'accessoire HomeKit est rattache par son adresse.
    /// Ni le routeur AC00 lui-meme, ni l'appareil sous le 20 (sa table fait foi), ni l'introuvable.
    @Test func resolutionDesParents() async throws {
        let sonde = try Self.sondeResolue()
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: Self.appareils))
        let demandes = await sonde.registre.requetes.filter { $0.hasSuffix("|resoudre") }
        #expect(demandes.sorted() == [0x04, 0x07, 0x0A, 0x0B, 0x0C, 0x50].map { "\(Self.omr($0))|resoudre" }.sorted(),
                "ni la sonde, ni l'autre partition")
        #expect(m.enfants(de: 43).map(\.rloc16) == [0xAC05, 0xAC09, 0xAE00, 0xAE01])
        let a = try #require(m.enfants.first { $0.rloc16 == 0xAE00 })
        #expect(a.extMac == "E00000000000000A" && a.source == .resolution && a.resolu == Self.t0 && !a.rloc16Connu)
        #expect(a.adresses == [Self.omr(0x0A)] && a.qualite == nil)
        let b = try #require(m.enfants.first { $0.rloc16 == 0xAC05 })
        #expect(b.extMac == "E00000000000000B" && b.rloc16Connu)
        let h = try #require(m.enfants.first { $0.rloc16 == 0xAE01 })
        #expect(h.extMac == nil && h.adresses == [Self.omr(0x50)], "HomeKit : rapproche par son adresse")
        #expect(!m.enfants.contains { $0.extMac == "E000000000000007" }, "le routeur AC00 lui-meme")
        #expect(!m.enfants.contains { $0.adresses.contains(Self.omr(0x04)) }, "sous le 20 : sa table")
        #expect(Set(mem.resolutions.keys) == ["E00000000000000A", "E00000000000000B", "E000000000000004",
                                              "E000000000000007", "Prise-HomeKit"])
        #expect(mem.resolutions["E00000000000000A"]?.mleid == Self.mleid(0x0A))
        #expect(mem.demandes == ["E00000000000000A", "E00000000000000B", "E00000000000000C", "E000000000000004",
                                 "E000000000000007", "Prise-HomeKit"], "l'introuvable compte comme demande")
        #expect(mem.derniereResolution == Self.t0 && m.resolution == Self.t0)
        // Gardes 30 min, comme le balayage qu'elles remplacent : a 5 min, les memes enfants, sans requete.
        let avant = await sonde.registre.requetes.count
        let (m2, _) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0 + 300,
                                                              appareils: Self.appareils))
        #expect(m2.enfants(de: 43).map(\.rloc16) == [0xAC05, 0xAC09, 0xAE00, 0xAE01])
        #expect(await sonde.registre.requetes.dropFirst(avant).filter { $0.hasSuffix("|resoudre") }.isEmpty)
    }

    /// Qualite des enfants des routeurs Apple (spec de la sonde tout-en-un, section 2.3) : a chaque resolution, les
    /// compteurs MAC (TLV 9) de chaque enfant resolu sous un routeur muet qui a un ML-EID, demandes a ce ML-EID. Le
    /// taux d'echec entre deux releves donne sa qualite (0,7 % : 3) ; moins de 50 trames entre les deux, ou un
    /// compteur qui baisse (l'appareil a redemarre) : inconnue, et le releve repart. Un enfant qui ne repond pas : rien.
    @Test func compteursDesEnfants() async throws {
        func sonde(_ envois: UInt32, _ echecs: UInt32) throws -> SondeRejouee {
            try Self.sondeResolue(reponsesEnPlus: [Self.cleCompteurs(0x0A): Self.compteurs(envois: envois, echecs: echecs)])
        }
        func enfant(_ m: Maillage) throws -> EnfantMaillage { try #require(m.enfants.first { $0.rloc16 == 0xAE00 }) }
        let s1 = try sonde(1000, 3)
        let (m1, mem1) = try #require(try await Tournee.complete(s1, memoire: MemoireTournee(), maintenant: Self.t0,
                                                                 appareils: Self.appareils))
        #expect(await s1.registre.requetes.filter { $0.hasSuffix("|9") }.sorted() == [Self.cleCompteurs(0x0A), Self.cleCompteurs(0x50)].sorted(),
                "les deux enfants de AC00 qui ont un ML-EID")
        #expect(try enfant(m1).qualite == nil, "un seul releve")
        #expect(mem1.compteurs["E00000000000000A"]?.unicastEmis == 1000)
        #expect(mem1.compteurs["Prise-HomeKit"] == nil, "muet : rien")
        let (m2, mem2) = try #require(try await Tournee.complete(try sonde(2000, 10), memoire: mem1,
                                                                 maintenant: Self.t0 + 1800, appareils: Self.appareils))
        let e2 = try enfant(m2)
        #expect(e2.qualite == 3 && e2.echecs.map { abs($0 - 0.007) < 1e-12 } == true, "7 echecs sur 1000 envois")
        #expect(mem2.resolutions["E00000000000000A"]?.qualite == 3)
        let (m3, mem3) = try #require(try await Tournee.complete(try sonde(2040, 15), memoire: mem2,
                                                                 maintenant: Self.t0 + 3600, appareils: Self.appareils))
        #expect(try enfant(m3).qualite == nil && mem3.compteurs["E00000000000000A"]?.unicastEmis == 2040, "40 trames")
        let (m4, mem4) = try #require(try await Tournee.complete(try sonde(100, 0), memoire: mem3,
                                                                 maintenant: Self.t0 + 5400, appareils: Self.appareils))
        #expect(try enfant(m4).qualite == nil && mem4.compteurs["E00000000000000A"]?.unicastEmis == 100, "redemarre")
        let (m5, _) = try #require(try await Tournee.complete(try sonde(400, 20), memoire: mem4,
                                                              maintenant: Self.t0 + 7200, appareils: Self.appareils))
        #expect(try enfant(m5).qualite == 1, "20 echecs sur 300 : 6,7 %")
    }

    /// Sans annonces (firmware 1.0.x, ou la sonde ne les rend pas) : ni ecoute, ni resolution, ni compteurs ; la
    /// couverture est inconnue, la resolution reste due.
    @Test func sansAnnonces() async throws {
        let sonde = try Self.sondeResolue(annonces: nil)
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: Self.appareils))
        #expect(!m.annoncesLues && m.couverture == nil)
        #expect(await !sonde.registre.requetes.contains { $0.hasSuffix("|resoudre") || $0.hasSuffix("|9") })
        #expect(mem.derniereResolution == nil && mem.resolutions.isEmpty && m.resolution == nil)
        #expect(await sonde.registre.annonces == 1)
    }

    /// Annonces entendues (spec de la sonde tout-en-un, section 2.1) : les liens entre routeurs Apple, muets au
    /// diagnostic, viennent de leur Route64, dates de l'age de l'annonce ; chaque sens garde la mesure la plus recente,
    /// et le diagnostic d'un routeur qui repond l'emporte. Chaque annonce donne l'identite de son routeur. Une annonce
    /// d'une autre partition, ou d'un enfant, est ecartee. Couverture : 3 routeurs entendus sur 7 (ExtMac inventees).
    @Test func ecouteDesAnnonces() async throws {
        let annonces = [
            Self.annonce("AC00", "E000000000000007", qualites: [1: (3, 3), 57: (2, 1)], age: 30),
            Self.annonce("E400", "E0000000000000E4", qualites: [43: (3, 3), 45: (3, 2)], age: 120),
            Self.annonce("5000", "E000000000000002", qualites: [24: (1, 1)], age: 10),
            Self.annonce("CC00", "E0000000000000CC", qualites: [57: (3, 3)], age: 5, partition: "73586B68"),
            Self.annonce("AC05", "E0000000000000D5", qualites: [43: (3, 3)], age: 5),
        ]
        let sonde = try SondeRejouee.capture(annonces: annonces)
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let l4357 = try #require(m.liens.first { $0.a == 43 && $0.b == 57 })
        #expect(l4357.qualiteAB == 2 && l4357.qualiteBA == 1, "l'annonce de 43, plus recente que celle de 57")
        #expect(l4357.sourceAB == .ecoute && l4357.dateAB == Self.t0 - 30)
        let l4557 = try #require(m.liens.first { $0.a == 45 && $0.b == 57 })
        #expect(l4557.qualiteAB == 2 && l4557.qualiteBA == 3 && l4557.dateBA == Self.t0 - 120, "connu de 57 seul")
        #expect(m.liens.first { $0.a == 1 && $0.b == 43 }?.sourceBA == .ecoute, "entre deux routeurs Apple")
        let l2024 = try #require(m.liens.first { $0.a == 20 && $0.b == 24 })
        #expect(l2024.sourceAB == .diagnostic && l2024.qualite == 3, "le diagnostic, plus recent")
        #expect(!m.liens.contains { $0.a == 51 && $0.b == 57 }, "l'annonce de l'autre partition est ecartee")
        #expect(m.routeur(43)?.entendu == Self.t0 - 30 && m.routeur(57)?.entendu == Self.t0 - 120)
        #expect(m.routeur(51)?.entendu == nil && m.routeur(1)?.entendu == nil)
        #expect(mem.identites[0xE400] == "E0000000000000E4" && mem.identites[0xCC00] == nil && mem.identites[0xAC05] == nil)
        #expect(m.routeur(57)?.extMac == "E0000000000000E4", "muet : l'identite de son annonce")
        #expect(m.couverture == CouvertureEcoute(entendus: 3, routeurs: 7))
        #expect(await sonde.registre.annonces == 1)
    }

    /// Un appareil apparait entre deux resolutions completes : il est resolu a la tournee suivante, seul, et les autres
    /// gardent la leur. Un appareil deja demande, meme introuvable, ne l'est plus avant la resolution complete suivante.
    @Test func resolutionDUnAppareilNouveau() async throws {
        let sonde = try Self.sondeResolue()
        let deux = Array(Self.appareils.prefix(2))
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: deux))
        #expect(mem1.demandes == ["E00000000000000A", "E00000000000000B"])
        let avant = await sonde.registre.requetes.count
        let (m2, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 300,
                                                                appareils: Self.appareils))
        let demandees = await sonde.registre.requetes.dropFirst(avant).filter { $0.hasSuffix("|resoudre") }
        #expect(demandees.sorted() == [0x04, 0x07, 0x0C, 0x50].map { "\(Self.omr($0))|resoudre" }.sorted(), "les nouveaux seuls")
        #expect(mem2.derniereResolution == Self.t0, "pas une resolution complete")
        #expect(mem2.resolutions.count == 5 && mem2.demandes.count == 6)
        #expect(m2.enfants(de: 43).map(\.rloc16) == [0xAC05, 0xAC09, 0xAE00, 0xAE01])
        let avant3 = await sonde.registre.requetes.count
        _ = try #require(try await Tournee.complete(sonde, memoire: mem2, maintenant: Self.t0 + 600, appareils: Self.appareils))
        #expect(await sonde.registre.requetes.dropFirst(avant3).filter { $0.hasSuffix("|resoudre") }.isEmpty)
    }

    /// Chef muet : Route64 d'un routeur qui a repondu a la tournee precedente.
    @Test func chefMuet() async throws {
        let sonde = try SondeRejouee.capture(chef: 45, reponsesEnPlus: ["5000|5,6": try CaptureSonde.tlv(104)])
        var mem = MemoireTournee()
        mem.echecs[45] = 2
        mem.repondants = [20]
        let (m, _) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0))
        #expect(m.routeurs.count == 7)
        #expect(m.chef?.id == 45)
        #expect(await sonde.registre.requetes.first == "5000|5,6")
    }

    /// Chef muet des le lancement : memoire neuve, aucun secours connu. La Route64 vient
    /// d'abord des autres routeurs de la table de la sonde, en un groupe (le 20 et le 24 la
    /// donnent) : pas de recherche sur les autres identifiants.
    @Test func chefMuetSansSecours() async throws {
        let sonde = try SondeRejouee.capture(chef: 45, reponsesEnPlus: ["5000|5,6": try CaptureSonde.tlv(104)])
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        #expect(m.chef?.id == 45)
        let requetes = await sonde.registre.requetes.filter { $0.hasSuffix("|5,6") }
        #expect(requetes.first == "B400|5,6", "le chef d'abord")
        #expect(requetes.dropFirst().compactMap(Self.routeur).sorted() == [1, 20, 24, 43, 51, 57], "puis la table")
        #expect(mem.repondants == [20, 24])
        #expect(mem.rechercheVaine == nil)
    }

    /// Chef muet des le lancement, sans table des routeurs (firmware 1.0.1) : la Route64 vient
    /// des autres identifiants, par groupes de 8 dans l'ordre croissant ; arret au groupe du 20.
    @Test func chefMuetSansSecoursNiTable() async throws {
        let sonde = try SondeRejouee.capture(chef: 45, reponsesEnPlus: ["5000|5,6": try CaptureSonde.tlv(104)], table: nil)
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        let ids = await sonde.registre.requetes.filter { $0.hasSuffix("|5,6") }.compactMap(Self.routeur)
        #expect(ids.first == 45, "le chef d'abord")
        #expect(ids.dropFirst().sorted() == Array(0...23), "puis 0 a 23 : arret au groupe du 20")
        #expect(mem.repondants == [20, 24])
    }

    /// Rien ne repond, sonde attachee : pas de maillage ; la memoire rendue n'a que la partition,
    /// l'identite du parent et la date de cette recherche vaine. La liste des routeurs est
    /// demandee une fois a chaque identifiant, 63 en tout : au chef, aux autres routeurs de la
    /// table de la sonde, puis aux autres identifiants.
    @Test func rienNeRepond() async throws {
        let sonde = try SondeRejouee.capture().filtree { _ in false }
        let r = try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0)
        #expect(r.maillage == nil)
        var attendue = MemoireTournee()
        attendue.partition = "46CBEBCD"
        attendue.identites = [0xAC00: "E000000000000007"]
        attendue.rechercheVaine = Self.t0
        #expect(r.memoire == attendue)
        let requetes = await sonde.registre.requetes
        #expect(requetes.allSatisfy { $0.hasSuffix("|5,6") })
        let ids = requetes.compactMap(Self.routeur)
        #expect(ids.count == 63 && Set(ids) == Set(0...62), "une fois chaque identifiant")
        #expect(ids.first == 24, "le chef")
        #expect(Set(ids.dropFirst().prefix(6)) == [1, 20, 43, 45, 51, 57], "puis les autres routeurs de la table")
    }

    /// Apres une recherche complete vaine, pas de nouvelle recherche complete avant 30 min : le
    /// chef et les autres routeurs de la table seulement (7 requetes au lieu de 63), et la date
    /// est gardee ; l'avancement a ce total. A 30 min, de nouveau partout.
    @Test func rechercheBorneeApresUnEchec() async throws {
        let sonde = try SondeRejouee.capture().filtree { _ in false }
        let r1 = try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0)
        #expect(r1.memoire.rechercheVaine == Self.t0)
        let n1 = await sonde.registre.requetes.count
        let releve = ReleveAvancement()
        let r2 = try await Tournee.executer(sonde, memoire: r1.memoire, maintenant: Self.t0 + 1799,
                                            avancement: { releve.noter($0) })
        let n2 = await sonde.registre.requetes.count
        #expect(n2 - n1 == 7, "le chef et les 6 autres routeurs de la table")
        #expect(r2.memoire.rechercheVaine == Self.t0, "date gardee")
        let liste = releve.de(.listeRouteurs)
        #expect(liste.last == AvancementTournee(etape: .listeRouteurs, fait: 7, total: 7))
        #expect(ReleveAvancement.croissants(liste))
        let r3 = try await Tournee.executer(sonde, memoire: r2.memoire, maintenant: Self.t0 + 1800)
        #expect(await sonde.registre.requetes.count - n2 == 63, "30 min apres : partout")
        #expect(r3.memoire.rechercheVaine == Self.t0 + 1800)
    }

    /// Recherche dont la sonde refuse toutes les requetes (`occupee`) : ce n'est pas un echec, la
    /// suivante cherche de nouveau partout. Sans table ni secours, dans les 30 min d'une recherche
    /// vaine : le chef seul.
    @Test func rechercheRefuseeOuSansTable() async throws {
        let refusee = try SondeRejouee.capture().filtree { _ in false }.refusant { _ in true }
        let r = try await Tournee.executer(refusee, memoire: MemoireTournee(), maintenant: Self.t0)
        #expect(await refusee.registre.requetes.count == 63)
        #expect(r.memoire.rechercheVaine == nil)

        let sansTable = try SondeRejouee.capture(table: nil).filtree { _ in false }
        var mem = MemoireTournee()
        mem.partition = "46CBEBCD"
        mem.rechercheVaine = Self.t0
        let r2 = try await Tournee.executer(sansTable, memoire: mem, maintenant: Self.t0 + 300)
        #expect(r2.maillage == nil)
        #expect(await sansTable.registre.requetes == ["6000|5,6"], "le chef seul")
    }

    /// Chef muet et secours sans Route64 : la recherche ne leur redemande pas la liste. Le secours,
    /// puis le chef muet, puis les autres, chacun une fois : sans table, les 61 autres
    /// identifiants ; avec la table, d'abord ses autres routeurs.
    @Test func rechercheSansLesEssais() async throws {
        var mem = MemoireTournee()
        mem.partition = "46CBEBCD"
        mem.echecs[45] = 2
        mem.repondants = [20]
        let sansTable = try SondeRejouee.capture(chef: 45, table: nil).filtree { _ in false }
        let r = try await Tournee.executer(sansTable, memoire: mem, maintenant: Self.t0)
        #expect(r.maillage == nil)
        let ids = await sansTable.registre.requetes.compactMap(Self.routeur)
        #expect(Array(ids.prefix(2)) == [20, 45], "le secours, puis le chef muet")
        #expect(ids.count == 63 && Set(ids) == Set(0...62), "puis les 61 autres, une fois chacun")

        let avecTable = try SondeRejouee.capture(chef: 45).filtree { _ in false }
        _ = try await Tournee.executer(avecTable, memoire: mem, maintenant: Self.t0)
        let ids2 = await avecTable.registre.requetes.compactMap(Self.routeur)
        #expect(Array(ids2.prefix(2)) == [20, 45])
        #expect(Set(ids2.dropFirst(2).prefix(5)) == [1, 24, 43, 51, 57], "la table, sans eux")
        #expect(ids2.count == 63 && Set(ids2) == Set(0...62))
    }

    /// Sonde dont le chef (45) ne donne pas la Route64, sans table ni autre reponse que les
    /// Route64 de `listes` (identifiant -> routeurs de sa Route64) ; `lents` : 100 ms plus tard.
    static func rechercheSeule(_ listes: [Int: [Int]], lents: Set<Int> = []) throws -> SondeRejouee {
        let cle = { (id: Int) in SondeRejouee.cle(UInt16(id) << 10, Tournee.tlvChef) }
        let base = try SondeRejouee.capture(chef: 45, table: nil)
        return SondeRejouee(etatSonde: base.etatSonde,
                            reponses: Dictionary(uniqueKeysWithValues: listes.map { (cle($0.key), Self.route64($0.value)) }),
                            table: nil,
                            retards: Dictionary(uniqueKeysWithValues: lents.map { (cle($0), Duration.milliseconds(100)) }))
    }

    /// Recherche par groupes de 8 dans l'ordre croissant (sans table) : un routeur qui donne la
    /// Route64 en 7 l'arrete apres le premier groupe (0 a 7), en 9 apres le second (0 a 15). Dans
    /// un groupe, celle du plus petit identifiant qui la donne, meme revenue apres une autre (le
    /// 9, lent, et le 12 ; Route64 inventees).
    @Test func rechercheParGroupesDe8() async throws {
        let cas: [(listes: [Int: [Int]], lents: Set<Int>, requetes: Int, routeurs: [Int])] = [
            ([7: [7, 45]], [], 9, [7, 45]),
            ([9: [9, 45]], [], 17, [9, 45]),
            ([9: [9, 45], 12: [12, 45]], [9], 17, [9, 45]),
        ]
        for c in cas {
            let sonde = try Self.rechercheSeule(c.listes, lents: c.lents)
            let (m, _) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
            #expect(m.routeurs.map(\.id) == c.routeurs, "\(c.listes)")
            #expect(await sonde.registre.requetes.filter { $0.hasSuffix("|5,6") }.count == c.requetes, "\(c.listes)")
        }
    }

    /// Echec passager : le 20, qui repond d'habitude, rate une tournee. Sans reponse dans ce
    /// maillage, un echec ; muet au second echec de suite.
    @Test func echecPassager() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let sans20 = sonde.filtree { !$0.hasPrefix("5000|") }
        let (m2, mem2) = try #require(try await Tournee.complete(sans20, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(mem2.echecs[20] == 1 && !mem2.estMuet(20))
        #expect(m2.routeur(20)?.muet == true)

        let (_, mem3) = try #require(try await Tournee.complete(sans20, memoire: mem2, maintenant: Self.t0 + 600))
        #expect(mem3.estMuet(20))
    }

    /// La sonde refuse (`occupee`) les requetes aux routeurs deux tournees de suite : ce n'est pas
    /// un silence des routeurs. Aucun echec de plus, aucun routeur muet ; le maillage
    /// les marque sans reponse a la tournee, et les secours restent.
    @Test func refusNeComptentPasCommeSilence() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let occupee = sonde.refusant { $0.hasSuffix("|0,1,5,16,8,24") }
        let (m2, mem2) = try #require(try await Tournee.complete(occupee, memoire: mem1, maintenant: Self.t0 + 300))
        let (m3, mem3) = try #require(try await Tournee.complete(occupee, memoire: mem2, maintenant: Self.t0 + 600))
        #expect(mem3.echecs == mem1.echecs, "aucun echec de plus")
        #expect(!mem3.estMuet(20) && !mem3.estMuet(24) && !mem3.estMuet(43))
        #expect(mem3.muetInterroge.isEmpty)
        #expect(m2.routeurs.filter(\.muet).count == 7 && m3.routeurs.filter(\.muet).count == 7, "sans reponse")
        let requetes = await occupee.registre.requetes
        #expect(requetes.filter { $0 == "AC00|0,1,5,16,8,24" }.count == 2, "pas muet : interroge a chaque tournee")
        #expect(mem3.repondants == [20, 24])
    }

    /// Reponse `ok` illisible du 20 (TLV tronquee), deux tournees de suite : ce n'est pas un
    /// silence. Ses echecs ne bougent pas, il n'est pas muet ; le maillage le marque
    /// sans reponse a la tournee.
    @Test func reponseIllisibleNEstPasUnSilence() async throws {
        let (_, mem1) = try #require(try await Tournee.complete(try SondeRejouee.capture(), memoire: MemoireTournee(),
                                                               maintenant: Self.t0))
        let illisible = try SondeRejouee.capture(reponsesEnPlus: ["5000|0,1,5,16,8,24": "0008E0"])
        let (m2, mem2) = try #require(try await Tournee.complete(illisible, memoire: mem1, maintenant: Self.t0 + 300))
        let (m3, mem3) = try #require(try await Tournee.complete(illisible, memoire: mem2, maintenant: Self.t0 + 600))
        #expect(mem3.echecs[20] == 0 && !mem3.estMuet(20))
        #expect(m2.routeur(20)?.muet == true && m3.routeur(20)?.muet == true, "sans reponse")
    }

    /// Resolution due (30 min) dont la sonde refuse toutes les demandes : elle ne remplace pas la precedente. Les
    /// enfants resolus restent affiches, et elle est refaite a la tournee suivante. Une resolution ou rien n'est trouve
    /// (`introuvable`) remplace la precedente, elle : les appareils reviennent en rattachement suppose.
    @Test func resolutionRefuseeGardeLaPrecedente() async throws {
        let sonde = try Self.sondeResolue()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: Self.appareils))
        #expect(mem1.resolutions.count == 5)
        let refusee = sonde.refusant("suspendue") { $0.hasSuffix("|resoudre") }
        let (m2, mem2) = try #require(try await Tournee.complete(refusee, memoire: mem1, maintenant: Self.t0 + 1800,
                                                                appareils: Self.appareils))
        #expect(await refusee.registre.requetes.filter { $0.hasSuffix("|resoudre") }.count == 6, "resolution tentee")
        #expect(mem2.resolutions == mem1.resolutions && mem2.demandes == mem1.demandes)
        #expect(mem2.derniereResolution == Self.t0, "a refaire")
        #expect(m2.enfants(de: 43).count == 4, "3 enfants resolus et la sonde")
        #expect(m2.resolution == Self.t0, "resolution refusee : ses enfants restent ceux de la precedente")

        let avant = await sonde.registre.requetes.count
        let (_, mem3) = try #require(try await Tournee.complete(sonde, memoire: mem2, maintenant: Self.t0 + 2100,
                                                               appareils: Self.appareils))
        #expect(await sonde.registre.requetes.dropFirst(avant).filter { $0.hasSuffix("|resoudre") }.count == 6, "refaite")
        #expect(mem3.derniereResolution == Self.t0 + 2100)

        let rien = try Self.sondeResolue(resolutions: [:])
        let (m4, mem4) = try #require(try await Tournee.complete(rien, memoire: mem1, maintenant: Self.t0 + 1800,
                                                                appareils: Self.appareils))
        #expect(mem4.resolutions.isEmpty && mem4.derniereResolution == Self.t0 + 1800)
        #expect(m4.enfants(de: 43).map(\.source) == [.sonde])
        #expect(m4.resolution == Self.t0 + 1800, "une resolution d'introuvables est une resolution")
    }

    /// Resolution refusee en partie : l'appareil refuse garde sa resolution d'avant, et il est demande de nouveau a la
    /// tournee suivante, seul.
    @Test func resolutionRefuseeEnPartie() async throws {
        let sonde = try Self.sondeResolue()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: Self.appareils))
        let cleB = "\(Self.omr(0x0B))|resoudre"
        let refusee = sonde.refusant { $0 == cleB }
        let (m2, mem2) = try #require(try await Tournee.complete(refusee, memoire: mem1, maintenant: Self.t0 + 1800,
                                                                appareils: Self.appareils))
        #expect(mem2.derniereResolution == Self.t0 + 1800)
        #expect(mem2.resolutions["E00000000000000B"] == mem1.resolutions["E00000000000000B"], "sa resolution d'avant")
        #expect(!mem2.demandes.contains("E00000000000000B"))
        #expect(m2.enfants.contains { $0.rloc16 == 0xAC05 })
        let avant = await sonde.registre.requetes.count
        let (_, mem3) = try #require(try await Tournee.complete(sonde, memoire: mem2, maintenant: Self.t0 + 2100,
                                                               appareils: Self.appareils))
        #expect(await sonde.registre.requetes.dropFirst(avant).filter { $0.hasSuffix("|resoudre") } == [cleB])
        #expect(mem3.demandes.contains("E00000000000000B") && mem3.resolutions["E00000000000000B"]?.date == Self.t0 + 2100)
    }

    /// Resolution due sans aucun appareil a resoudre (tous partis de l'instantane) : elle remplace la precedente par
    /// rien et prend la date de la tournee ; les enfants resolus d'avant ne s'affichent plus.
    @Test func resolutionSansAppareil() async throws {
        let sonde = try Self.sondeResolue()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: Self.appareils))
        #expect(!mem1.resolutions.isEmpty)
        let (m, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 1800))
        #expect(mem2.resolutions.isEmpty && mem2.demandes.isEmpty && mem2.derniereResolution == Self.t0 + 1800)
        #expect(m.enfants(de: 43).map(\.source) == [.sonde])
    }

    /// Recherche sans aucun groupe a interroger : rien n'a ete refuse.
    @Test func rechercheVideNonRefusee() async throws {
        let r = try await Tournee.chercherRoute64(try SondeRejouee.capture(), groupes: [])
        #expect(r.route64 == nil && !r.refusee)
    }

    /// Routeur muet (43 : silences a 0 et 5 min) : interroge au plus une fois par heure. Pas a
    /// 5 min + 59 min 59 s, de nouveau a 5 min + 1 h.
    @Test func muetReinterrogeApresUneHeure() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let (_, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(mem2.estMuet(43) && mem2.muetInterroge[43] == Self.t0 + 300)
        let avant = await sonde.registre.requetes.count
        let (_, mem3) = try #require(try await Tournee.complete(sonde, memoire: mem2, maintenant: Self.t0 + 300 + 3599))
        let pendant = await sonde.registre.requetes.count
        let (_, mem4) = try #require(try await Tournee.complete(sonde, memoire: mem3, maintenant: Self.t0 + 300 + 3600))
        let requetes = await sonde.registre.requetes
        #expect(!requetes[avant..<pendant].contains("AC00|0,1,5,16,8,24"), "dans l'heure")
        #expect(mem3.muetInterroge[43] == Self.t0 + 300)
        #expect(requetes[pendant...].contains("AC00|0,1,5,16,8,24"), "une heure apres")
        #expect(mem4.muetInterroge[43] == Self.t0 + 3900 && mem4.echecs[43] == 3)
    }

    /// TLV (hexa) d'une reponse dont le type est dans `types`, dans leur ordre : une moitie de
    /// la reponse entiere.
    static func garder(_ hexa: String, _ types: Set<UInt8>) throws -> String {
        let o = [UInt8](try #require(Data(hexa: hexa)))
        var i = 0, gardees: [UInt8] = []
        while i + 2 <= o.count {
            let fin = i + 2 + Int(o[i + 1])
            if types.contains(o[i]) { gardees += o[i..<fin] }
            i = fin
        }
        return Data(gardees).hexa
    }

    /// TLV Route64 (hexa) des routeurs `ids`, croissants : sequence 1 ; un lien vers chaque routeur
    /// de `qualites` (qualite sortante et entrante vues par celui qui repond, cout 1), aucun vers
    /// les autres.
    static func route64(_ ids: [Int], qualites: [Int: (sortante: Int, entrante: Int)] = [:]) -> String {
        let masque = ids.reduce(UInt64(0)) { $0 | UInt64(1) << (63 - $1) }
        let routes = ids.map { id in qualites[id].map { UInt8($0.sortante << 6 | $0.entrante << 4 | 1) } ?? 0 }
        let octets: [UInt8] = [TypeTLV.route64, UInt8(9 + ids.count), 1]
            + (0..<8).map { UInt8(truncatingIfNeeded: masque >> (56 - 8 * $0)) } + routes
        return Data(octets).hexa
    }

    /// Lien lu aux deux bouts, avec d'autres qualites dans chaque Route64 : la tournee applique
    /// les reponses par identifiant croissant, et celle du plus grand decide (regle de
    /// `ConstructionMaillage.lien`), meme revenue la premiere (le 10 est lent ; routeurs inventes).
    @Test func lienDecideParLePlusGrandIdentifiant() async throws {
        var sonde = try SondeRejouee.capture(chef: 12, reponsesEnPlus: [
            "3000|5,6": Self.route64([10, 12]),
            // Vu par le 10 : 10 -> 12 de qualite 1, 12 -> 10 de qualite 2.
            "2800|0,1,5,16,8,24": Self.route64([10, 12], qualites: [12: (sortante: 1, entrante: 2)]),
            // Vu par le 12 : 12 -> 10 de qualite 1, 10 -> 12 de qualite 3.
            "3000|0,1,5,16,8,24": Self.route64([10, 12], qualites: [10: (sortante: 1, entrante: 3)]),
        ], table: [])
        sonde.retards = ["2800|0,1,5,16,8,24": .milliseconds(100)]
        let (m, _) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeurs.map(\.id) == [10, 12] && !m.routeurs.contains(where: \.muet), "les deux repondent")
        #expect(m.liens == [LienRadio(a: 10, b: 12, qualiteAB: 3, qualiteBA: 1, sourceAB: .diagnostic, sourceBA: .diagnostic,
                                      dateAB: Self.t0, dateBA: Self.t0)], "le rapport du 12")
    }

    /// TLV Child Table (hexa) des enfants `numeros` : qualite 3, delai 2^8 s, endormis (mode 04).
    static func tableEnfants(_ numeros: [Int]) -> String {
        let octets = numeros.flatMap { n -> [UInt8] in
            let x = 12 << 11 | 3 << 9 | n
            return [UInt8(x >> 8), UInt8(x & 0xFF), 0x04]
        }
        return Data([TypeTLV.tableEnfants, UInt8(octets.count)] + octets).hexa
    }

    /// Reponse du routeur 20 trop longue pour le reseau (`trop_long` : plus de 1100 octets) : il a
    /// repondu. Sa requete est refaite une fois en deux moities de TLV, reunies : le maillage et
    /// la memoire sont ceux d'une reponse entiere ; aucun echec.
    @Test func tropLongEnDeuxMoities() async throws {
        let (m0, mem0) = try #require(try await Tournee.complete(try SondeRejouee.capture(), memoire: MemoireTournee(),
                                                                  maintenant: Self.t0))
        let entiere = try CaptureSonde.tlv(104)
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["5000|0,1,5": try Self.garder(entiere, [0, 1, 5]),
                                                              "5000|16,8,24": try Self.garder(entiere, [16, 8, 24])],
                                             tropLongs: ["5000|0,1,5,16,8,24"])
        let releve = ReleveAvancement()
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               avancement: { releve.noter($0) }))
        #expect(m == m0)
        #expect(mem == mem0)
        #expect(m.routeur(20)?.muet == false)
        let routeurs = releve.de(.routeurs)
        #expect(ReleveAvancement.croissants(routeurs))
        #expect(routeurs.last == AvancementTournee(etape: .routeurs, fait: 9, total: 9), "7 routeurs, puis 2 moities")
        let requetes = await sonde.registre.requetes
        let de20 = requetes.filter { $0.hasPrefix("5000|") && $0 != "5000|7" && $0 != "5000|25,26,27,28" }
        #expect(de20.first == "5000|0,1,5,16,8,24", "la requete entiere d'abord")
        #expect(de20.dropFirst().sorted() == ["5000|0,1,5", "5000|16,8,24"], "puis ses moities, une seule fois, en parallele : dans le desordre")
    }

    /// Une moitie encore trop longue : ce qu'on a est garde (ExtMac, liens), sans nouveau
    /// decoupage, et le routeur n'est ni muet, ni en echec.
    @Test func tropLongUneMoitieTropLongue() async throws {
        let (m0, _) = try #require(try await Tournee.complete(try SondeRejouee.capture(), memoire: MemoireTournee(),
                                                               maintenant: Self.t0))
        let entiere = try CaptureSonde.tlv(104)
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["5000|0,1,5": try Self.garder(entiere, [0, 1, 5])],
                                             tropLongs: ["5000|0,1,5,16,8,24", "5000|16,8,24"])
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeur(20)?.muet == false)
        #expect(m.routeur(20)?.extMac == "E000000000000002")
        #expect(m.liens == m0.liens, "liens de sa Route64, dans la moitie gardee")
        #expect(m.enfants(de: 20).isEmpty, "table des enfants dans la moitie trop longue")
        #expect(mem.echecs[20] == 0)
        #expect(mem.repondants == [20, 24])
        let requetes = await sonde.registre.requetes
        let de20 = requetes.filter { $0.hasPrefix("5000|0,1,5") || $0.hasPrefix("5000|16,8") }
        #expect(de20.first == "5000|0,1,5,16,8,24", "la requete entiere d'abord")
        #expect(de20.dropFirst().sorted() == ["5000|0,1,5", "5000|16,8,24"], "ses moities, pas de troisieme decoupage")
    }

    /// Un routeur qui repond sans son ExtMac (ici la moitie qui la porte reste sans reponse)
    /// garde l'identite connue d'une tournee precedente, comme un muet : il ne perd pas son nom.
    @Test func repondantSansExtMacGardeSonIdentite() async throws {
        let (_, mem1) = try #require(try await Tournee.complete(try SondeRejouee.capture(), memoire: MemoireTournee(),
                                                                 maintenant: Self.t0))
        #expect(mem1.identites[0x5000] == "E000000000000002")
        let entiere = try CaptureSonde.tlv(104)
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["5000|16,8,24": try Self.garder(entiere, [16, 8, 24])],
                                             tropLongs: ["5000|0,1,5,16,8,24"])
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(m.routeur(20)?.muet == false)
        #expect(m.routeur(20)?.extMac == "E000000000000002", "identite connue")
        #expect(m.enfants(de: 20).count == 2, "sa table des enfants, dans la moitie recue")
        #expect(mem.identites[0x5000] == "E000000000000002")
        #expect(mem.echecs[20] == 0)
    }

    /// L'identite connue d'un routeur qui repond sans ExtMac se lit apres toutes les reponses :
    /// si un routeur suivant repond avec cette ExtMac (elle a change de routeur), la paire perimee
    /// est oubliee et le premier ne la prend pas (valeurs de la capture ; paire perimee inventee).
    @Test func identiteConnueApresToutesLesReponses() async throws {
        var memoire = MemoireTournee()
        memoire.partition = "46CBEBCD"
        memoire.identites = [0x5000: "E000000000000003"]  // l'ExtMac du 24, perimee sous le 20
        let entiere = try CaptureSonde.tlv(104)
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["5000|16,8,24": try Self.garder(entiere, [16, 8, 24])],
                                             tropLongs: ["5000|0,1,5,16,8,24"])
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: memoire, maintenant: Self.t0))
        #expect(m.routeur(24)?.extMac == "E000000000000003")
        #expect(m.routeur(20)?.extMac == nil, "la paire perimee est oubliee avant d'etre lue")
        #expect(mem.identites[0x5000] == nil)
        #expect(mem.identites[0x6000] == "E000000000000003")
    }

    /// Aucun routeur ne repond a sa requete (sonde occupee...) : les secours de la
    /// tournee precedente restent.
    @Test func repondantsGardes() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let seulChef = sonde.filtree { $0 == "6000|5,6" }
        let (m2, mem2) = try #require(try await Tournee.complete(seulChef, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(m2.routeurs.filter(\.muet).count == 7)
        #expect(mem2.repondants == [20, 24])
    }

    /// Identites gardees : a 30 min, les enfants des tables ne repondent pas a la
    /// nouvelle demande ; celles de la premiere tournee restent.
    @Test func identitesGardees() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let endormis = sonde.filtree { !$0.hasSuffix("|0,8") }
        let (m2, mem2) = try #require(try await Tournee.complete(endormis, memoire: mem1, maintenant: Self.t0 + 1800))
        #expect(await endormis.registre.requetes.filter { $0.hasSuffix("|0,8") }.count == 6, "redemandees")
        #expect(m2.enfants(de: 20).map(\.extMac) == ["E000000000000005", "E000000000000004"])
        #expect(mem2.identifies.count == 3)
    }

    /// Demandes d'identite refusees par la sonde (`occupee`) : elles ne comptent pas comme
    /// faites, et la tournee suivante (5 min) les refait ; les enfants qui repondent sont
    /// identifies.
    @Test func identitesRefuseesRedemandees() async throws {
        let sonde = try SondeRejouee.capture()
        let refusees = sonde.refusant { $0.hasSuffix("|0,8") }
        let (_, mem1) = try #require(try await Tournee.complete(refusees, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(await refusees.registre.requetes.filter { $0.hasSuffix("|0,8") }.count == 6)
        #expect(mem1.identiteDemandee.isEmpty && mem1.identifies.isEmpty)
        let (m2, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(await sonde.registre.requetes.filter { $0.hasSuffix("|0,8") }.count == 6, "redemandees")
        #expect(mem2.identifies.count == 3 && mem2.identiteDemandee.count == 6)
        #expect(m2.enfants(de: 20).map(\.extMac) == ["E000000000000005", "E000000000000004"])
    }

    /// Table des routeurs de la sonde (FED) : les paires RLOC16 ↔ ExtMac des routeurs qu'elle
    /// entend sont retenues comme celle de son parent, et donnent leur ExtMac aux routeurs
    /// muets ; une demande par tournee. La sonde les entend ensuite moins (elle a bouge) : les
    /// paires restent (ExtMac inventees).
    @Test func routeursEntendus() async throws {
        let entendus: [UInt16: String] = [0xE400: "E0000000000000E4", 0xCC00: "E0000000000000CC"]
        let sonde = try SondeRejouee.capture(table: SondeRejouee.table(entendus: entendus))
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeur(57)?.extMac == "E0000000000000E4")
        #expect(m.routeur(51)?.extMac == "E0000000000000CC")
        #expect(m.routeur(1)?.extMac == nil, "pas entendu")
        #expect(m.routeur(43)?.extMac == "E000000000000007", "le parent, par etat")
        #expect(mem.identites[0xE400] == "E0000000000000E4" && mem.identites[0xCC00] == "E0000000000000CC")
        #expect(mem.identites[0xAC00] == "E000000000000007")
        #expect(await sonde.registre.tables == 1)

        let ailleurs = try SondeRejouee.capture(table: SondeRejouee.table(entendus: [0xE400: "E0000000000000E4"]))
        let (m2, mem2) = try #require(try await Tournee.complete(ailleurs, memoire: mem, maintenant: Self.t0 + 300))
        #expect(m2.routeur(51)?.extMac == "E0000000000000CC", "retenue d'une tournee a l'autre")
        #expect(mem2.identites[0xCC00] == "E0000000000000CC")
        #expect(await ailleurs.registre.tables == 1)
    }

    /// Pas de table (firmware sans `routeurs`, verrou d'OpenThread refuse) : la tournee continue,
    /// sans ces paires.
    @Test func sansTable() async throws {
        let sonde = try SondeRejouee.capture(table: nil)
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        #expect(mem.identites == [0xAC00: "E000000000000007", 0x5000: "E000000000000002", 0x6000: "E000000000000003"])
        #expect(await sonde.registre.tables == 1)
    }

    /// Une ExtMac n'a qu'un RLOC16 : un routeur qui a change d'identifiant (redemarrage) perd
    /// l'ancienne paire, qui ne donne plus son ExtMac a l'identifiant libere.
    @Test func identiteDeplacee() async throws {
        let sonde = try SondeRejouee.capture(table: SondeRejouee.table(entendus: [0xE400: "E0000000000000E4"]))
        var mem = MemoireTournee()
        mem.partition = "46CBEBCD"
        mem.identites[0x0400] = "E0000000000000E4"
        let (m, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0))
        #expect(mem2.identites[0x0400] == nil)
        #expect(mem2.identites[0xE400] == "E0000000000000E4")
        #expect(m.routeur(1)?.extMac == nil)
        #expect(m.routeur(57)?.extMac == "E0000000000000E4")
    }

    /// Pas de liste des routeurs (plus rien ne repond apres `etat`) : pas de maillage, mais la
    /// memoire rendue garde les identites apprises (parent, table des routeurs), pour qu'une sonde
    /// promenee les garde, et la date de la recherche vaine ; le reste est la memoire d'avant,
    /// aucun routeur ne passe pour muet. Dans une autre partition, elle est remise a zero, sauf
    /// ces identites et cette date (ExtMac inventee).
    @Test func identitesSansListe() async throws {
        let (_, mem1) = try #require(try await Tournee.complete(try SondeRejouee.capture(), memoire: MemoireTournee(),
                                                               maintenant: Self.t0))
        let muette = try SondeRejouee.capture(table: SondeRejouee.table(entendus: [0xE400: "E0000000000000E4"]))
            .filtree { _ in false }
        let r = try await Tournee.executer(muette, memoire: mem1, maintenant: Self.t0 + 300)
        #expect(r.maillage == nil)
        var attendue = mem1
        attendue.identites[0xE400] = "E0000000000000E4"
        attendue.rechercheVaine = Self.t0 + 300
        #expect(r.memoire == attendue, "la memoire d'avant, plus le routeur entendu et la recherche vaine")

        var ailleurs = mem1
        ailleurs.partition = "73586B68"
        let r2 = try await Tournee.executer(muette, memoire: ailleurs, maintenant: Self.t0 + 300)
        #expect(r2.maillage == nil)
        var neuve = MemoireTournee()
        neuve.partition = "46CBEBCD"
        neuve.identites = [0xAC00: "E000000000000007", 0xE400: "E0000000000000E4"]
        neuve.rechercheVaine = Self.t0 + 300
        #expect(r2.memoire == neuve)
    }

    /// Network Data en echec a la tournee suivante : les dernieres lues servent (routeurs de
    /// bordure, BBR principal) ; sinon, les routeurs de bordure et leurs candidats disparaitraient
    /// d'une tournee a l'autre. Sans Network Data deja lues, aucun routeur de bordure.
    @Test func reseauGarde() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(mem1.donneesReseau != nil)
        let sansReseau = sonde.filtree { $0 != "5000|7" }
        let (m2, mem2) = try #require(try await Tournee.complete(sansReseau, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(await sansReseau.registre.requetes.contains("5000|7"), "demandees, en echec")
        #expect(m2.routeurs.filter(\.bordure).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m2.routeur(45)?.bbrPrincipal == true)
        #expect(mem2.donneesReseau == mem1.donneesReseau)
        let (m3, _) = try #require(try await Tournee.complete(sansReseau, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m3.routeurs.filter(\.bordure).isEmpty)
    }

    /// Autre partition : les Network Data gardees de l'ancienne sont oubliees avec le reste de la
    /// memoire ; la requete echouant, aucun routeur n'est marque d'apres elles (ni routeur de
    /// bordure, ni BBR principal).
    @Test func autrePartitionOublieLesNetworkData() async throws {
        let anciennes = try #require(DonneesReseau(MaillageTests.bbrE400PuisB400))
        var mem = MemoireTournee()
        mem.partition = "73586B68"
        mem.donneesReseau = anciennes
        let sonde = try SondeRejouee.capture().filtree { $0 != "5000|7" }
        let (m, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0))
        #expect(mem2.partition == "46CBEBCD")
        #expect(mem2.donneesReseau == nil)
        #expect(!m.routeurs.contains { $0.bordure || $0.bbrPrincipal })
    }

    /// Paire d'un routeur sorti de la liste des routeurs (routeur disparu, identifiant libere) :
    /// oubliee des que la tournee a la Route64. Celle d'un routeur encore dans la liste reste,
    /// meme s'il n'est plus entendu (ExtMac inventees).
    @Test func pairesHorsDeLaListe() async throws {
        let sonde = try SondeRejouee.capture()
        var mem = MemoireTournee()
        mem.partition = "46CBEBCD"
        mem.identites = [0x0800: "E0000000000000EE", 0xE400: "E0000000000000E4"]
        let (m, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0))
        #expect(!m.routeurs.contains { $0.id == 2 }, "l'identifiant 2 n'est pas dans la Route64")
        #expect(mem2.identites[0x0800] == nil, "oubliee")
        #expect(mem2.identites[0xE400] == "E0000000000000E4", "le routeur 57 est dans la liste : gardee")
        #expect(m.routeur(57)?.extMac == "E0000000000000E4")
    }

    /// Routeur sorti de la liste des routeurs (identifiant libere) : ses echecs, sa derniere
    /// interrogation de muet, sa pile, sa place de secours et les enfants resolus sous lui sont
    /// oublies des que la tournee a la Route64. L'identifiant reattribue repart de zero :
    /// interroge tout de suite, et non tenu pour un muet deja interroge dans l'heure (Route64 et
    /// appareils inventes).
    @Test func memoireOublieeHorsDeLaListe() async throws {
        let sonde = try SondeRejouee.capture()
        var mem = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0)).memoire
        mem.echecs[2] = 2
        mem.muetInterroge[2] = Self.t0
        mem.piles[2] = "SL-OPENTHREAD"
        mem.repondants = [2, 20]
        mem.resolutions["E0000000000000E2"] = ResolutionAppareil(rloc16: 0x0800, mleid: nil, adresse: Self.omr(0xE2), date: Self.t0)
        mem.resolutions["E0000000000000E3"] = ResolutionAppareil(rloc16: 0xAC00, mleid: nil, adresse: Self.omr(0xE3), date: Self.t0)
        let seulChef = sonde.filtree { $0 == "6000|5,6" }
        let (_, mem2) = try #require(try await Tournee.complete(seulChef, memoire: mem, maintenant: Self.t0 + 300))
        #expect(mem2.echecs[2] == nil && mem2.muetInterroge[2] == nil && mem2.piles[2] == nil)
        #expect(mem2.repondants == [20], "aucun routeur n'a repondu : les secours d'avant, sans le 2")
        #expect(mem2.derniereResolution == Self.t0, "pas de nouvelle resolution")
        #expect(Set(mem2.resolutions.keys) == ["E0000000000000E3"], "l'appareil resolu sous le 2, lui seul")

        let avec2 = try SondeRejouee.capture(reponsesEnPlus: ["6000|5,6": Self.route64([1, 2, 20, 24, 43, 45, 51, 57])])
        let (m3, mem3) = try #require(try await Tournee.complete(avec2, memoire: mem2, maintenant: Self.t0 + 600))
        #expect(await avec2.registre.requetes.contains("0800|0,1,5,16,8,24"), "interroge")
        #expect(mem3.echecs[2] == 1, "premier silence")
        #expect(m3.routeur(2)?.muet == true)
    }

    /// Enfant absent de la table de son parent, qui a repondu : son identite (ExtMac, adresses) et
    /// la date de sa derniere demande sont oubliees. Un appareil qui reprend son RLOC16 sans
    /// repondre n'a pas l'ancien nom, et son identite est demandee tout de suite.
    @Test func identiteOublieeHorsDeLaTable() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(mem1.identifies[0x5001]?.extMac == "E000000000000005")
        let sans5001 = try Self.garder(try CaptureSonde.tlv(104), [0, 1, 5, 8, 24]) + Self.tableEnfants([4])
        let parti = try SondeRejouee.capture(reponsesEnPlus: ["5000|0,1,5,16,8,24": sans5001])
        let (_, mem2) = try #require(try await Tournee.complete(parti, memoire: mem1, maintenant: Self.t0 + 300))
        #expect(mem2.identifies[0x5001] == nil && mem2.identiteDemandee[0x5001] == nil, "absent de la table du 20")
        #expect(mem2.identifies[0x5004]?.extMac == "E000000000000004", "encore dans sa table")
        #expect(mem2.identifies[0x6003]?.extMac == "E000000000000006")

        let repris = sonde.filtree { $0 != "5001|0,8" }
        let (m3, mem3) = try #require(try await Tournee.complete(repris, memoire: mem2, maintenant: Self.t0 + 600))
        #expect(await repris.registre.requetes.contains("5001|0,8"), "demandee tout de suite")
        let e = try #require(m3.enfants.first { $0.rloc16 == 0x5001 })
        #expect(e.extMac == nil, "pas l'ancien nom")
        #expect(mem3.identiteDemandee[0x5001] == Self.t0 + 600)
    }

    /// Identites d'enfants dont le parent est sorti de la liste des routeurs : oubliees. Celles des
    /// enfants d'un routeur muet, ou d'un routeur dont la table n'est pas venue (moitie de reponse
    /// trop longue), restent : leur table n'est pas lue (ExtMac inventees).
    @Test func identitesOublieesAvecLeParent() async throws {
        var mem = MemoireTournee()
        mem.partition = "46CBEBCD"
        let demande = Self.t0 - 60
        for x in [0x0801, 0xAC01, 0x5001] as [UInt16] {
            mem.identifies[x] = EnfantMaillage(rloc16: x, extMac: String(format: "E00000000000%04X", x), source: .tableEnfants)
            mem.identiteDemandee[x] = demande
        }
        let entiere = try CaptureSonde.tlv(104)
        let sonde = try SondeRejouee.capture(reponsesEnPlus: ["5000|0,1,5": try Self.garder(entiere, [0, 1, 5])],
                                             tropLongs: ["5000|0,1,5,16,8,24", "5000|16,8,24"])
        let (_, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0))
        #expect(mem2.identifies[0x0801] == nil && mem2.identiteDemandee[0x0801] == nil, "le 2 n'est plus dans la liste")
        #expect(mem2.identifies[0xAC01] != nil && mem2.identiteDemandee[0xAC01] == demande, "parent muet")
        #expect(mem2.identifies[0x5001] != nil && mem2.identiteDemandee[0x5001] == demande, "table du 20 pas venue")
    }

    /// Enfant resolu sous un routeur muet (AC05) passe a un routeur qui repond (5002, dans sa
    /// table) : a la tournee suivante, avant la resolution suivante, son identite le reconnait, et il
    /// n'est plus affiche sous l'ancien parent. Les autres enfants resolus restent.
    @Test func enfantAyantChangeDeParent() async throws {
        let sonde = try Self.sondeResolue()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: Self.appareils))
        #expect(mem1.resolutions["E00000000000000B"]?.rloc16 == 0xAC05)
        let table20 = try Self.garder(try CaptureSonde.tlv(104), [0, 1, 5, 8, 24]) + Self.tableEnfants([4, 1, 2])
        let parti = try Self.sondeResolue(reponsesEnPlus: ["5000|0,1,5,16,8,24": table20, "5002|0,8": "0008E00000000000000B"])
        let (m2, mem2) = try #require(try await Tournee.complete(parti, memoire: mem1, maintenant: Self.t0 + 300,
                                                                appareils: Self.appareils))
        #expect(mem2.derniereResolution == Self.t0, "pas de nouvelle resolution")
        #expect(m2.enfants.filter { $0.extMac == "E00000000000000B" }.map(\.rloc16) == [0x5002], "une seule fois")
        #expect(m2.enfants(de: 43).map(\.rloc16) == [0xAC09, 0xAE00, 0xAE01])
    }

    /// La sonde est un appareil Matter de l'instantane : elle n'est jamais resolue (elle se connait), ni un appareil
    /// d'une autre partition (la resolution ne traverse pas les partitions) ; la sonde n'est affichee qu'une fois.
    @Test func sondeEtAutrePartitionJamaisResolues() async throws {
        let sonde = try Self.sondeResolue()
        let (m, mem) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                               appareils: Self.appareils))
        let demandes = await sonde.registre.requetes.filter { $0.hasSuffix("|resoudre") }
        #expect(!demandes.contains("\(Self.omr(0xAA))|resoudre") && !demandes.contains("\(Self.omr(0xF1))|resoudre"))
        #expect(m.enfants.filter { $0.extMac == "E0000000000000AA" }.map(\.rloc16) == [0xAC09], "la sonde, une fois")
        #expect(!mem.demandes.contains("E0000000000000AA") && !mem.demandes.contains("E0000000000000F1"))
    }

    /// Autre partition (panne, fusion) : les identifiants de routeur y sont
    /// redistribues ; ce qui etait retenu de l'ancienne ne sert plus : resolutions, demandes et
    /// releves des compteurs (la resolution est refaite), identites d'enfants et dates de leurs
    /// demandes, recherche vaine (ExtMac inventees).
    @Test func autrePartition() async throws {
        let sonde = try SondeRejouee.capture()
        var mem = MemoireTournee()
        mem.partition = "73586B68"
        mem.identites[0xB400] = "E0000000000000EE"
        mem.echecs[20] = 2
        mem.muetInterroge[20] = Self.t0
        mem.resolutions["E0000000000000E2"] = ResolutionAppareil(rloc16: 0xAC00, mleid: nil, adresse: Self.omr(0xE2), date: Self.t0)
        mem.demandes = ["E0000000000000E2"]
        mem.derniereResolution = Self.t0
        mem.compteurs["E0000000000000E2"] = CompteursMac(protocolesInconnus: 0, erreursRecues: 0, erreursEmises: 1,
                                                         unicastRecus: 0, diffusionsRecues: 0, rejetsRecus: 0,
                                                         unicastEmis: 100, diffusionsEmises: 0, rejetsEmis: 0)
        mem.identiteDemandee[0x5001] = Self.t0 + 30
        mem.identifies[0x6002] = EnfantMaillage(rloc16: 0x6002, extMac: "E0000000000000EF", source: .tableEnfants)
        mem.rechercheVaine = Self.t0
        let (m, mem2) = try #require(try await Tournee.complete(sonde, memoire: mem, maintenant: Self.t0 + 60))
        #expect(mem2.partition == "46CBEBCD")
        #expect(m.routeur(45)?.extMac == nil, "B400 : pas l'ExtMac retenu dans l'autre partition")
        #expect(m.routeur(20)?.muet == false, "5000 interroge de nouveau")
        #expect(mem2.derniereResolution == Self.t0 + 60, "resolution refaite")
        #expect(mem2.resolutions.isEmpty && mem2.demandes.isEmpty && mem2.compteurs.isEmpty)
        #expect(await sonde.registre.requetes.contains("5001|0,8"), "identite redemandee")
        #expect(mem2.identiteDemandee[0x5001] == Self.t0 + 60)
        let e = try #require(m.enfants.first { $0.rloc16 == 0x6002 })
        #expect(e.extMac == nil, "pas l'identite de l'autre partition")
        #expect(mem2.rechercheVaine == nil)
    }

    /// Sonde suspendue (interrupteur eteint dans Maison) : pas de tournee, aucune requete.
    @Test func suspendue() async throws {
        let base = #"{"v":1,"t":"etat","role":"child","rloc16":"AC09","mode":"rn","parent":null,"partition":"46CBEBCD","chef":24,"canal":25,"prefixeMaille":null,"xp":null,"suspendue":true}"#
        guard case .etat(let e)? = MessageSonde.lire(Data(base.utf8)) else {
            Issue.record("etat illisible")
            return
        }
        let sonde = SondeRejouee(etatSonde: e, reponses: [:])
        var mem = MemoireTournee()
        mem.echecs[20] = 1
        let r = try await Tournee.executer(sonde, memoire: mem, maintenant: Self.t0)
        #expect(r.maillage == nil)
        #expect(r.memoire == mem, "memoire inchangee")
        #expect(await sonde.registre.requetes.isEmpty)
        #expect(await sonde.registre.tables == 0, "ni la table des routeurs")
        #expect(await sonde.registre.voisins == 0, "ni les voisins")
        #expect(await sonde.registre.annonces == 0, "ni les annonces")
    }

    /// Avancement de la premiere tournee : les sept etapes dans l'ordre, chacune annoncee a 0
    /// puis une requete a la fois jusqu'a son total, connu des son debut ici. Les totaux sont
    /// les requetes envoyees : `etat`, `routeurs`, `voisins` et `annonces` pour la sonde, 6
    /// resolutions et 2 releves de compteurs.
    @Test func avancementPremiere() async throws {
        let sonde = try Self.sondeResolue()
        let releve = ReleveAvancement()
        _ = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                   appareils: Self.appareils, avancement: { releve.noter($0) }))
        #expect(releve.etapes == AvancementTournee.Etape.allCases)
        let totaux: [AvancementTournee.Etape: Int] = [.etatSonde: 4, .listeRouteurs: 1, .routeurs: 7, .pileEtReseau: 3,
                                                       .resolution: 6, .compteurs: 2, .identites: 6]
        for (etape, total) in totaux {
            let a = releve.de(etape)
            #expect(a.map(\.fait) == Array(0...total), "\(etape)")
            #expect(a.allSatisfy { $0.total == total }, "\(etape)")
        }
        let requetes = await sonde.registre.requetes
        #expect(requetes.count == totaux.values.reduce(0, +) - 4,
                "une requete par pas, hors etat, routeurs, voisins et annonces de la sonde")
        #expect(await sonde.registre.tables == 1)
        #expect(await sonde.registre.voisins == 1)
        #expect(await sonde.registre.annonces == 1)
    }

    /// Deuxieme tournee (5 min) : la liste des routeurs s'arrete au chef, avant son total
    /// (le chef et un secours) ; piles connues : Network Data seules ; la resolution (pas due),
    /// les compteurs et les identites (demandees il y a 5 min) sont annonces sans rien a faire.
    @Test func avancementSuivante() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let releve = ReleveAvancement()
        _ = try #require(try await Tournee.complete(sonde, memoire: mem1, maintenant: Self.t0 + 300,
                                                   avancement: { releve.noter($0) }))
        #expect(releve.etapes == AvancementTournee.Etape.allCases)
        #expect(releve.de(.listeRouteurs) == [AvancementTournee(etape: .listeRouteurs, fait: 0, total: 2),
                                              AvancementTournee(etape: .listeRouteurs, fait: 1, total: 2)])
        #expect(releve.de(.pileEtReseau).last == AvancementTournee(etape: .pileEtReseau, fait: 1, total: 1))
        #expect(releve.de(.resolution) == [AvancementTournee(etape: .resolution, fait: 0, total: 0)])
        #expect(releve.de(.compteurs) == [AvancementTournee(etape: .compteurs, fait: 0, total: 0)])
        #expect(releve.de(.identites) == [AvancementTournee(etape: .identites, fait: 0, total: 0)])
        #expect(ReleveAvancement.croissants(releve.de(.routeurs)))
    }

    /// Chef muet des le lancement : le total de la liste des routeurs grandit quand la
    /// recherche commence (le chef, puis les 6 autres routeurs de la table et les 56 autres
    /// identifiants) ; elle s'arrete au groupe de la table, avant son total, apres 7 requetes.
    /// Sans table (les 62 autres identifiants), au groupe du 20, apres 25 requetes.
    @Test func avancementRecherche() async throws {
        let tlv20 = try CaptureSonde.tlv(104)
        for (table, faites) in [(SondeRejouee.table(), 7), (nil, 25)] as [([RouteurSonde]?, Int)] {
            let sonde = try SondeRejouee.capture(chef: 45, reponsesEnPlus: ["5000|5,6": tlv20], table: table)
            let releve = ReleveAvancement()
            _ = try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                                       avancement: { releve.noter($0) }))
            let liste = releve.de(.listeRouteurs)
            #expect(Array(liste.prefix(3)) == [AvancementTournee(etape: .listeRouteurs, fait: 0, total: 1),
                                               AvancementTournee(etape: .listeRouteurs, fait: 1, total: 1),
                                               AvancementTournee(etape: .listeRouteurs, fait: 1, total: 63)])
            #expect(liste.last == AvancementTournee(etape: .listeRouteurs, fait: faites, total: 63))
            #expect(ReleveAvancement.croissants(liste))
            #expect(await sonde.registre.requetes.filter { $0.hasSuffix("|5,6") }.count == faites)
        }
    }

    /// `parallele` sur 20 elements, en fenetre glissante : jamais plus de 8 requetes en vol, et
    /// l'element 0, retenu, n'empeche pas les 19 autres de partir (chaque requete revenue en lance
    /// une). Resultats dans l'ordre des elements ; `apresChacune` a chaque requete revenue.
    @Test(.timeLimit(.minutes(1))) func paralleleFenetreGlissante() async throws {
        let vol = EnVol()
        var faites: [Int] = []
        let r = try await Tournee.parallele(Array(0..<20), { e in
            await vol.partir()
            if e == 0 { await vol.retenir(jusqua: 20) } else { try await Task.sleep(for: .milliseconds(10)) }
            await vol.revenir()
            return ResultatDiag(id: e, cible: "", ok: false, erreur: "delai")
        }, apresChacune: { n, _, _ in faites.append(n) })
        #expect(await vol.vues == 20, "tous partis pendant que le 0 etait retenu")
        #expect(await vol.maximum <= Tournee.enVol)
        #expect(r.map(\.0) == Array(0..<20) && r.map(\.1.id) == Array(0..<20))
        #expect(faites == Array(1...20))
    }

    /// Liaison fermee au milieu d'un groupe (`diag` echoue par une erreur) : `parallele` rend
    /// l'erreur, et la tournee aussi ; l'appelant garde sa memoire.
    @Test func erreurAuMilieuDUnGroupe() async throws {
        await #expect(throws: SondeFermee.Fermee.self) {
            _ = try await Tournee.parallele(Array(0..<10), { e in
                if e == 4 { throw SondeFermee.Fermee() }
                return ResultatDiag(id: e, cible: "", ok: false, erreur: "delai")
            })
        }
        let sonde = SondeFermee(base: try SondeRejouee.capture(), sur: "5000|0,1,5,16,8,24")
        await #expect(throws: SondeFermee.Fermee.self) {
            _ = try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0)
        }
    }

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

    /// Bords du garde du signal : -1 dBm est valide ; 0 et les RSSI positifs (127 : invalide
    /// d'OpenThread) sont ignores ; le dernier signal valide d'un routeur l'emporte, et un invalide
    /// ne l'efface pas.
    @Test func bordsDuSignal() {
        var c = ConstructionMaillage(date: Self.t0, partition: "0000000A")
        c.routeurs(Route64(sequence: 1, routes: (1...4).map { RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1) }),
                   chef: 1)
        c.signal(SignalSonde(routeur: 1, rssi: -1))
        c.signal(SignalSonde(routeur: 2, rssi: 0))
        c.signal(SignalSonde(routeur: 3, rssi: 127))
        c.signal(SignalSonde(routeur: 4, rssi: -60))
        c.signal(SignalSonde(routeur: 4, rssi: 0))
        #expect(c.maillage().signaux == [SignalSonde(routeur: 1, rssi: -1), SignalSonde(routeur: 4, rssi: -60)])
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
        let base = #"{"v":1,"t":"etat","role":"disabled","rloc16":"FFFE","mode":"rn","parent":null,"partition":null,"chef":null,"canal":11,"prefixeMaille":null,"xp":null,"suspendue":false}"#
        guard case .etat(let e)? = MessageSonde.lire(Data(base.utf8)) else {
            Issue.record("etat illisible")
            return
        }
        let sonde = SondeRejouee(etatSonde: e, reponses: [:])
        let releve = ReleveAvancement()
        let r = try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0,
                                           avancement: { releve.noter($0) })
        #expect(r.maillage == nil && r.memoire == MemoireTournee())
        #expect(await sonde.registre.tables == 0, "pas de table hors d'une partition")
        #expect(await sonde.registre.voisins == 0, "ni de voisins")
        #expect(releve.avancements == [AvancementTournee(etape: .etatSonde, fait: 0, total: 4),
                                       AvancementTournee(etape: .etatSonde, fait: 1, total: 4)],
                "l'etape s'arrete avant son total")
    }
}
```

Dans `MaillageCoeurTests/SuiviMaillageTests.swift`, remplacer :

```swift
    /// Maillage de la partition 0000000A a `minutes` de t0 (valeurs inventees) : le chef 0 (routeur
    /// de bordure), et les routeurs 1 et 2 par defaut ; `muets` ; ExtMac des routeurs `routeursExt` ;
    /// `balayage` : date du balayage dont viennent les enfants balayes, en minutes apres t0 (nil :
    /// aucun balayage).
    static func maillage(_ minutes: Double, routeurs: [Int] = [0, 1, 2], bordures: Set<Int> = [0], muets: Set<Int> = [],
                         routeursExt: [Int: String] = [:], enfants: [Enfant], partition: String = "0000000A",
                         balayage: Double? = nil) -> Maillage {
        var c = ConstructionMaillage(date: t0.addingTimeInterval(minutes * 60), partition: partition)
        c.routeurs(Route64(sequence: 1, routes: routeurs.map { RouteRouteur(idRouteur: $0, qualiteSortante: 0, qualiteEntrante: 0, cout: 1) }),
```

par :

```swift
    /// Maillage de la partition 0000000A a `minutes` de t0 (valeurs inventees) : le chef 0 (routeur
    /// de bordure), et les routeurs 1 et 2 par defaut ; `muets` ; ExtMac des routeurs `routeursExt` ;
    /// `resolution` : date de la resolution dont viennent les enfants resolus, en minutes apres t0
    /// (nil : aucune resolution).
    static func maillage(_ minutes: Double, routeurs: [Int] = [0, 1, 2], bordures: Set<Int> = [0], muets: Set<Int> = [],
                         routeursExt: [Int: String] = [:], enfants: [Enfant], partition: String = "0000000A",
                         resolution: Double? = nil) -> Maillage {
        var c = ConstructionMaillage(date: t0.addingTimeInterval(minutes * 60), partition: partition)
        c.routeurs(Route64(sequence: 1, routes: routeurs.map { RouteRouteur(idRouteur: $0, qualiteSortante: 0, qualiteEntrante: 0, cout: 1) }),
```

Dans `MaillageCoeurTests/SuiviMaillageTests.swift`, remplacer :

```swift
        for (id, ext) in routeursExt { c.identite(ext, routeur: id) }
        for e in enfants {
            c.enfant(EnfantMaillage(rloc16: e.rloc16, extMac: e.ext, qualite: e.source == .balayage ? nil : 3, source: e.source))
        }
        var m = c.maillage()
        m.balayage = balayage.map { t0.addingTimeInterval($0 * 60) }
        return m
    }
```

par :

```swift
        for (id, ext) in routeursExt { c.identite(ext, routeur: id) }
        for e in enfants {
            c.enfant(EnfantMaillage(rloc16: e.rloc16, extMac: e.ext, qualite: e.source == .resolution ? nil : 3, source: e.source))
        }
        var m = c.maillage()
        m.resolution = resolution.map { t0.addingTimeInterval($0 * 60) }
        return m
    }
```

Dans `MaillageCoeurTests/SuiviMaillageTests.swift`, remplacer :

```swift

    /// Enfant lu dans la table d'un routeur qui se tait ensuite : son absence ne dit rien (le
    /// routeur n'a pas ete interroge). Enfant balaye sous un routeur muet : absent, c'est qu'un
    /// nouveau balayage ne l'a pas trouve ; il faut deux balayages distincts (ici aux minutes 5 et 10).
    @Test func absenceSousUnRouteurMuet() {
        let b2 = "E0000000000000B2"
        let ev = Self.suivre([
            Self.maillage(0, muets: [2], enfants: [Enfant(rloc16: 0x0401, ext: Self.b1),
                                                     Enfant(rloc16: 0x0805, ext: b2, source: .balayage)], balayage: 0),
            Self.maillage(5, muets: [1, 2], enfants: [], balayage: 5),
            Self.maillage(10, muets: [1, 2], enfants: [], balayage: 10),
        ])
        #expect(ev[1].isEmpty)
```

par :

```swift

    /// Enfant lu dans la table d'un routeur qui se tait ensuite : son absence ne dit rien (le
    /// routeur n'a pas ete interroge). Enfant resolu sous un routeur muet : absent, c'est qu'une
    /// nouvelle resolution ne l'a pas trouve ; il faut deux resolutions distinctes (ici aux minutes 5 et 10).
    @Test func absenceSousUnRouteurMuet() {
        let b2 = "E0000000000000B2"
        let ev = Self.suivre([
            Self.maillage(0, muets: [2], enfants: [Enfant(rloc16: 0x0401, ext: Self.b1),
                                                     Enfant(rloc16: 0x0805, ext: b2, source: .resolution)], resolution: 0),
            Self.maillage(5, muets: [1, 2], enfants: [], resolution: 5),
            Self.maillage(10, muets: [1, 2], enfants: [], resolution: 10),
        ])
        #expect(ev[1].isEmpty)
```

Dans `MaillageCoeurTests/SuiviMaillageTests.swift`, remplacer :

```swift
    }

    /// Un balayage est reutilise par les tournees jusqu'au suivant : une seule observation, meme
    /// comptee a chaque tournee, n'est pas une absence de plus. Enfant balaye sous un routeur muet
    /// (2), present au balayage de la minute 0, absent de celui de la minute 5 (reutilise aux
    /// minutes 10 et 15) : une absence. Absent de celui de la minute 35 : « sans parent », une seule
    /// fois.
    @Test func unBalayageNeCompteQuUneFois() {
        let b2 = "E0000000000000B2"
        let absent = { (minutes: Double, balayage: Double) in
            Self.maillage(minutes, muets: [2], enfants: [], balayage: balayage)
        }
        let ev = Self.suivre([
            Self.maillage(0, muets: [2], enfants: [Enfant(rloc16: 0x0805, ext: b2, source: .balayage)], balayage: 0),
            absent(5, 5), absent(10, 5), absent(15, 5),
            absent(35, 35), absent(40, 35),
        ])
        #expect(ev[1].isEmpty && ev[2].isEmpty && ev[3].isEmpty, "le meme balayage, vu trois fois")
        #expect(ev[4].map(\.type) == [.sansParent], "un second balayage ne le trouve pas")
        #expect(ev[4].first?.sujet?.id == b2 && ev[4].first?.avant == "R2")
        #expect(ev[5].isEmpty, "pas de seconde fois")
    }

    /// Sans balayage (nil) sous un parent muet : l'enfant balaye n'est pas retrouve, mais rien n'a
    /// ete observe : aucune absence. Seuls deux balayages distincts (minutes 25 et 30) comptent.
    @Test func sansBalayageSousUnParentMuet() {
        let b2 = "E0000000000000B2"
        let sans = { (minutes: Double) in Self.maillage(minutes, muets: [2], enfants: [], balayage: nil) }
        let ev = Self.suivre([
            Self.maillage(0, muets: [2], enfants: [Enfant(rloc16: 0x0805, ext: b2, source: .balayage)], balayage: 0),
            sans(5), sans(10), sans(15), sans(20),
            Self.maillage(25, muets: [2], enfants: [], balayage: 25),
            Self.maillage(30, muets: [2], enfants: [], balayage: 30),
        ])
        #expect(ev[1...4].allSatisfy { $0.isEmpty }, "quatre tournees sans balayage : pas une absence")
        #expect(ev[5].isEmpty, "premier balayage qui ne le trouve pas")
        #expect(ev[6].map(\.type) == [.sansParent], "second balayage : le compte n'avait pas avance avant")
    }

```

par :

```swift
    }

    /// Une resolution est reutilisee par les tournees jusqu'a la suivante : une seule observation,
    /// meme comptee a chaque tournee, n'est pas une absence de plus. Enfant resolu sous un routeur
    /// muet (2), present a la resolution de la minute 0, absent de celle de la minute 5 (reutilisee
    /// aux minutes 10 et 15) : une absence. Absent de celle de la minute 35 : « sans parent », une
    /// seule fois.
    @Test func uneResolutionNeCompteQuUneFois() {
        let b2 = "E0000000000000B2"
        let absent = { (minutes: Double, resolution: Double) in
            Self.maillage(minutes, muets: [2], enfants: [], resolution: resolution)
        }
        let ev = Self.suivre([
            Self.maillage(0, muets: [2], enfants: [Enfant(rloc16: 0x0805, ext: b2, source: .resolution)], resolution: 0),
            absent(5, 5), absent(10, 5), absent(15, 5),
            absent(35, 35), absent(40, 35),
        ])
        #expect(ev[1].isEmpty && ev[2].isEmpty && ev[3].isEmpty, "la meme resolution, vue trois fois")
        #expect(ev[4].map(\.type) == [.sansParent], "une seconde resolution ne le trouve pas")
        #expect(ev[4].first?.sujet?.id == b2 && ev[4].first?.avant == "R2")
        #expect(ev[5].isEmpty, "pas de seconde fois")
    }

    /// Sans resolution (nil) sous un parent muet : l'enfant resolu n'est pas retrouve, mais rien n'a
    /// ete observe : aucune absence. Seules deux resolutions distinctes (minutes 25 et 30) comptent.
    @Test func sansResolutionSousUnParentMuet() {
        let b2 = "E0000000000000B2"
        let sans = { (minutes: Double) in Self.maillage(minutes, muets: [2], enfants: [], resolution: nil) }
        let ev = Self.suivre([
            Self.maillage(0, muets: [2], enfants: [Enfant(rloc16: 0x0805, ext: b2, source: .resolution)], resolution: 0),
            sans(5), sans(10), sans(15), sans(20),
            Self.maillage(25, muets: [2], enfants: [], resolution: 25),
            Self.maillage(30, muets: [2], enfants: [], resolution: 30),
        ])
        #expect(ev[1...4].allSatisfy { $0.isEmpty }, "quatre tournees sans resolution : pas une absence")
        #expect(ev[5].isEmpty, "premiere resolution qui ne le trouve pas")
        #expect(ev[6].map(\.type) == [.sansParent], "seconde resolution : le compte n'avait pas avance avant")
    }

```

Dans `MaillageCoeurTests/MaillageTests.swift`, remplacer :

```swift

    /// Tournee de la capture : Route64 du chef (6000), 5000 et 6000 qui repondent,
    /// les 5 routeurs de bordure muets, Network Data, balayage sous AC00, la sonde.
    static func tournee() throws -> Maillage {
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
```

par :

```swift

    /// Tournee de la capture : Route64 du chef (6000), 5000 et 6000 qui repondent,
    /// les 5 routeurs de bordure muets, Network Data, enfants resolus sous AC00, la sonde.
    static func tournee() throws -> Maillage {
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
```

Dans `MaillageCoeurTests/MaillageTests.swift`, remplacer :

```swift
            let r = try reponse(id)
            c.enfant(EnfantMaillage(rloc16: try #require(r.rloc16), extMac: r.extMac, endormi: r.mode?.endormi,
                                    source: .balayage))
        }
        c.enfant(EnfantMaillage(rloc16: 0xAC09, qualite: 3, source: .sonde))
```

par :

```swift
            let r = try reponse(id)
            c.enfant(EnfantMaillage(rloc16: try #require(r.rloc16), extMac: r.extMac, endormi: r.mode?.endormi,
                                    source: .resolution))
        }
        c.enfant(EnfantMaillage(rloc16: 0xAC09, qualite: 3, source: .sonde))
```

Dans `MaillageCoeurTests/MaillageTests.swift`, remplacer :

```swift
    }

    /// Enfants : tables de 5000 et 6000, balayage sous AC00, la sonde.
    @Test func enfants() throws {
        let m = try Self.tournee()
```

par :

```swift
    }

    /// Enfants : tables de 5000 et 6000, enfants resolus sous AC00, la sonde.
    @Test func enfants() throws {
        let m = try Self.tournee()
```

Dans `MaillageCoeurTests/MaillageTests.swift`, remplacer :

```swift
        #expect(ac04.extMac == "E00000000000000A")
        #expect(ac04.qualite == nil, "sous un routeur muet")
        #expect(ac04.source == .balayage)
        #expect(de43.last?.source == .sonde)
        #expect(m.enfants(de: 24).count == 4)
```

par :

```swift
        #expect(ac04.extMac == "E00000000000000A")
        #expect(ac04.qualite == nil, "sous un routeur muet")
        #expect(ac04.source == .resolution)
        #expect(de43.last?.source == .sonde)
        #expect(m.enfants(de: 24).count == 4)
```

Dans `MaillageCoeurTests/MaillageTests.swift`, remplacer :

```swift
        let adresse = try #require(AdresseIPv6("fd00:5555:6666:0:a00::7"))
        c.enfant(EnfantMaillage(rloc16: 0x5004, extMac: "E000000000000004", endormi: true, adresses: [adresse],
                                source: .balayage))
        #expect(c.enfantsSansIdentite == [0x5001])
        let e = try #require(c.maillage().enfants.first { $0.rloc16 == 0x5004 })
```

par :

```swift
        let adresse = try #require(AdresseIPv6("fd00:5555:6666:0:a00::7"))
        c.enfant(EnfantMaillage(rloc16: 0x5004, extMac: "E000000000000004", endormi: true, adresses: [adresse],
                                source: .resolution))
        #expect(c.enfantsSansIdentite == [0x5001])
        let e = try #require(c.maillage().enfants.first { $0.rloc16 == 0x5004 })
```

Dans `MaillageCoeurTests/MaillageTests.swift`, remplacer :

```swift
        let a2 = try #require(AdresseIPv6("fd00:5555:6666:0:a00::2"))
        let table = EnfantMaillage(rloc16: 0x5004, qualite: 2, delai: 256, endormi: true, source: .tableEnfants)
        let balayage = EnfantMaillage(rloc16: 0x5004, extMac: "E0000000000000AA", qualite: 1, delai: 30, endormi: false,
                                      adresses: [a1], source: .balayage)
        let autre = EnfantMaillage(rloc16: 0x5004, extMac: "E0000000000000BB", qualite: 3, delai: 60, endormi: true,
                                   adresses: [a2], source: .balayage)
        func fusion(_ premier: EnfantMaillage, _ second: EnfantMaillage) throws -> EnfantMaillage {
            var c = ConstructionMaillage(date: .now, partition: "46CBEBCD")
```

par :

```swift
        let a2 = try #require(AdresseIPv6("fd00:5555:6666:0:a00::2"))
        let table = EnfantMaillage(rloc16: 0x5004, qualite: 2, delai: 256, endormi: true, source: .tableEnfants)
        let resolu = EnfantMaillage(rloc16: 0x5004, extMac: "E0000000000000AA", qualite: 1, delai: 30, endormi: false,
                                    adresses: [a1], source: .resolution)
        let autre = EnfantMaillage(rloc16: 0x5004, extMac: "E0000000000000BB", qualite: 3, delai: 60, endormi: true,
                                   adresses: [a2], source: .resolution)
        func fusion(_ premier: EnfantMaillage, _ second: EnfantMaillage) throws -> EnfantMaillage {
            var c = ConstructionMaillage(date: .now, partition: "46CBEBCD")
```

Dans `MaillageCoeurTests/MaillageTests.swift`, remplacer :

```swift
            return enfants[0]
        }
        // Table d'abord, incomplete : ses valeurs restent, le balayage comble l'ExtMac et les adresses.
        #expect(try fusion(table, balayage) == EnfantMaillage(rloc16: 0x5004, extMac: "E0000000000000AA", qualite: 2,
                                                              delai: 256, endormi: true, adresses: [a1],
                                                              source: .tableEnfants))
        // Balayage d'abord, complet : rien n'est remplace, ni par la table, ni par sa source.
        #expect(try fusion(balayage, table) == balayage)
        // Deux entrees completes : la premiere gagne partout.
        #expect(try fusion(balayage, autre) == balayage)
        #expect(try fusion(autre, balayage) == autre)
    }

```

par :

```swift
            return enfants[0]
        }
        // Table d'abord, incomplete : ses valeurs restent, la resolution comble l'ExtMac et les adresses.
        #expect(try fusion(table, resolu) == EnfantMaillage(rloc16: 0x5004, extMac: "E0000000000000AA", qualite: 2,
                                                              delai: 256, endormi: true, adresses: [a1],
                                                              source: .tableEnfants))
        // Resolution d'abord, complete : rien n'est remplace, ni par la table, ni par sa source.
        #expect(try fusion(resolu, table) == resolu)
        // Deux entrees completes : la premiere gagne partout.
        #expect(try fusion(resolu, autre) == resolu)
        #expect(try fusion(autre, resolu) == autre)
    }

```

Dans `MaillageCoeurTests/MaillageTests.swift`, remplacer :

```swift

    /// Enfant resolu sous un routeur qui repond par son propre RLOC16 (Apple) : un numero invente, bit 9 a 1, jamais
    /// un vrai RLOC16 ; son parent reste juste. Comme une entree de balayage, une entree resolue dont l'ExtMac est
    /// celle d'un routeur est ecartee des enfants identifies, et passe apres la sonde et une table.
    @Test func enfantResolu() {
```

par :

```swift

    /// Enfant resolu sous un routeur qui repond par son propre RLOC16 (Apple) : un numero invente, bit 9 a 1, jamais
    /// un vrai RLOC16 ; son parent reste juste. Une entree resolue dont l'ExtMac est
    /// celle d'un routeur est ecartee des enfants identifies, et passe apres la sonde et une table.
    @Test func enfantResolu() {
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift

    /// Petit maillage (valeurs inventees) : le chef 0 et le routeur 1, muet, sans ExtMac ; la sonde
    /// 0001 sous 0 ; un enfant balaye sous 1 ; un enfant de table sans ExtMac ; deux signaux.
    static func maillage(_ date: Date) -> Maillage {
        var c = ConstructionMaillage(date: date, partition: "0000000A")
```

par :

```swift

    /// Petit maillage (valeurs inventees) : le chef 0 et le routeur 1, muet, sans ExtMac ; la sonde
    /// 0001 sous 0 ; un enfant resolu sous 1 ; un enfant de table sans ExtMac ; deux signaux.
    static func maillage(_ date: Date) -> Maillage {
        var c = ConstructionMaillage(date: date, partition: "0000000A")
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift
        c.lien(0, 1, sortante: 3, entrante: 2)
        c.enfant(EnfantMaillage(rloc16: 0x0001, extMac: "E0000000000000B1", qualite: 3, source: .sonde))
        c.enfant(EnfantMaillage(rloc16: 0x0402, extMac: "E0000000000000B2", source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x0003, qualite: 2, source: .tableEnfants))
        c.signal(SignalSonde(routeur: 0, rssi: -60))
```

par :

```swift
        c.lien(0, 1, sortante: 3, entrante: 2)
        c.enfant(EnfantMaillage(rloc16: 0x0001, extMac: "E0000000000000B1", qualite: 3, source: .sonde))
        c.enfant(EnfantMaillage(rloc16: 0x0402, extMac: "E0000000000000B2", source: .resolution))
        c.enfant(EnfantMaillage(rloc16: 0x0003, qualite: 2, source: .tableEnfants))
        c.signal(SignalSonde(routeur: 0, rssi: -60))
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift

    /// Un enfant vu deux fois (il a change de parent) : la sonde passe avant une table, une table
    /// avant le balayage d'un routeur muet (qui peut dater de 30 minutes), quel que soit l'ordre
    /// des RLOC16 (donc des insertions). La sonde compte : son ancien parent la garde dans sa
    /// table jusqu'a l'echeance de l'enfant, et peut avoir le plus petit identifiant.
    @Test(arguments: [
        // (source de l'entree au plus petit RLOC16, parent ; source de l'autre, parent ; parent attendu)
        (SourceEnfant.balayage, 1, SourceEnfant.tableEnfants, 2, 2),
        (.tableEnfants, 2, .balayage, 1, 2),
        (.tableEnfants, 1, .sonde, 2, 2),
        (.sonde, 1, .tableEnfants, 2, 1),
        (.balayage, 1, .sonde, 2, 2),
        (.sonde, 1, .balayage, 2, 1),
    ])
    func enfantVuDeuxFois(premiere: SourceEnfant, parentPremiere: Int, seconde: SourceEnfant, parentSeconde: Int,
```

par :

```swift

    /// Un enfant vu deux fois (il a change de parent) : la sonde passe avant une table, une table
    /// avant la resolution sous un routeur muet (qui peut dater de 30 minutes), quel que soit l'ordre
    /// des RLOC16 (donc des insertions). La sonde compte : son ancien parent la garde dans sa
    /// table jusqu'a l'echeance de l'enfant, et peut avoir le plus petit identifiant.
    @Test(arguments: [
        // (source de l'entree au plus petit RLOC16, parent ; source de l'autre, parent ; parent attendu)
        (SourceEnfant.resolution, 1, SourceEnfant.tableEnfants, 2, 2),
        (.tableEnfants, 2, .resolution, 1, 2),
        (.tableEnfants, 1, .sonde, 2, 2),
        (.sonde, 1, .tableEnfants, 2, 1),
        (.resolution, 1, .sonde, 2, 2),
        (.sonde, 1, .resolution, 2, 1),
    ])
    func enfantVuDeuxFois(premiere: SourceEnfant, parentPremiere: Int, seconde: SourceEnfant, parentSeconde: Int,
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift
    }

    /// Un enfant devenu routeur garde jusqu'a 30 minutes son entree du balayage d'un routeur muet : elle
    /// est ecartee, son ExtMac etant celle d'un routeur du maillage. L'historique n'a pas d'enfant de
    /// trop ; un autre enfant du meme balayage reste.
    @Test func enfantDevenuRouteur() {
        var c = ConstructionMaillage(date: Self.date("2026-09-30T10:00:00Z"), partition: "0000000A")
```

par :

```swift
    }

    /// Un enfant devenu routeur garde jusqu'a 30 minutes son entree de la resolution sous un routeur muet :
    /// elle est ecartee, son ExtMac etant celle d'un routeur du maillage. L'historique n'a pas d'enfant de
    /// trop ; un autre enfant de la meme resolution reste.
    @Test func enfantDevenuRouteur() {
        var c = ConstructionMaillage(date: Self.date("2026-09-30T10:00:00Z"), partition: "0000000A")
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift
        c.identite("E0000000000000B2", routeur: 2)
        c.muet(1)
        c.enfant(EnfantMaillage(rloc16: 0x0402, extMac: "E0000000000000B2", source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x0403, extMac: "E0000000000000B3", source: .balayage))
        let m = c.maillage()
        #expect(m.enfantsIdentifies["E0000000000000B2"] == nil, "devenu routeur")
```

par :

```swift
        c.identite("E0000000000000B2", routeur: 2)
        c.muet(1)
        c.enfant(EnfantMaillage(rloc16: 0x0402, extMac: "E0000000000000B2", source: .resolution))
        c.enfant(EnfantMaillage(rloc16: 0x0403, extMac: "E0000000000000B3", source: .resolution))
        let m = c.maillage()
        #expect(m.enfantsIdentifies["E0000000000000B2"] == nil, "devenu routeur")
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift
    }

    /// Seule l'entree du balayage est ecartee : une entree de la table d'un routeur ou de la sonde, que
    /// l'on vient de lire, garde son enfant, meme si son ExtMac est celle d'un routeur du maillage.
    @Test func entreeFraicheDunRouteurGardee() {
```

par :

```swift
    }

    /// Seule l'entree de la resolution est ecartee : une entree de la table d'un routeur ou de la sonde, que
    /// l'on vient de lire, garde son enfant, meme si son ExtMac est celle d'un routeur du maillage.
    @Test func entreeFraicheDunRouteurGardee() {
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift
    }

    /// Tournee de la capture, avec des voisins : 7 routeurs et 10 enfants identifies tiennent en
    /// moins de 700 octets ; avec 20 enfants (26 octets chacun), en moins de 1 Ko.
    @Test func tailleDUneLigne() async throws {
```

par :

```swift
    }

    /// Tournee de la capture, avec des voisins : 7 routeurs et 3 enfants identifies tiennent en
    /// moins de 700 octets ; avec 20 enfants (26 octets chacun), en moins de 1 Ko.
    @Test func tailleDUneLigne() async throws {
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift
        let r = ReleveMaillage(m)
        #expect(r.routeurs.count == 7 && r.liens.count == 7)
        #expect(r.enfants.count == 10, "balayes sous AC00, et les enfants des tables qui ont donne leur identite")
        let octets = try CodageJSON.encodeur().encode(r).count
        #expect(octets < 700, "\(octets) octets")
        var vingt = r.enfants
        for n in 0..<10 { vingt.append(ReleveMaillage.Enfant(extMac: String(format: "E0000000000001%02X", n), parent: 24, qualite: 3)) }
        let grand = ReleveMaillage(date: r.date, partition: r.partition, routeurs: r.routeurs, liens: r.liens, enfants: vingt,
                                   signaux: r.signaux, parentSonde: r.parentSonde)
```

par :

```swift
        let r = ReleveMaillage(m)
        #expect(r.routeurs.count == 7 && r.liens.count == 7)
        #expect(r.enfants.count == 3, "les enfants des tables qui ont donne leur identite")
        let octets = try CodageJSON.encodeur().encode(r).count
        #expect(octets < 700, "\(octets) octets")
        var vingt = r.enfants
        for n in 0..<17 { vingt.append(ReleveMaillage.Enfant(extMac: String(format: "E0000000000001%02X", n), parent: 24, qualite: 3)) }
        let grand = ReleveMaillage(date: r.date, partition: r.partition, routeurs: r.routeurs, liens: r.liens, enfants: vingt,
                                   signaux: r.signaux, parentSonde: r.parentSonde)
```

Dans `MaillageCoeurTests/GrapheReseauTests.swift`, remplacer :

```swift
    }

    /// Un enfant vu deux fois (il a change de parent ; l'ancienne entree du balayage d'un routeur muet
    /// peut rester 30 minutes) n'est qu'un noeud, pas un « rloc:XXXX » inconnu de plus : il est
    /// rattache par l'entree que retient `Maillage.enfantsIdentifies` (la sonde, puis la table d'un
    /// routeur qui repond, puis le balayage), quel que soit l'ordre des RLOC16.
    @Test(arguments: [
        // (source de l'entree sous le routeur 0 ; source de l'entree sous le routeur 1 ; parent attendu)
        (SourceEnfant.balayage, SourceEnfant.tableEnfants, "rloc:0400"),
        (.tableEnfants, .balayage, "rloc:0000"),
        (.tableEnfants, .sonde, "rloc:0400"),
    ])
```

par :

```swift
    }

    /// Un enfant vu deux fois (il a change de parent ; l'ancienne entree de la resolution sous un routeur muet
    /// peut rester 30 minutes) n'est qu'un noeud, pas un « rloc:XXXX » inconnu de plus : il est
    /// rattache par l'entree que retient `Maillage.enfantsIdentifies` (la sonde, puis la table d'un
    /// routeur qui repond, puis la resolution), quel que soit l'ordre des RLOC16.
    @Test(arguments: [
        // (source de l'entree sous le routeur 0 ; source de l'entree sous le routeur 1 ; parent attendu)
        (SourceEnfant.resolution, SourceEnfant.tableEnfants, "rloc:0400"),
        (.tableEnfants, .resolution, "rloc:0000"),
        (.tableEnfants, .sonde, "rloc:0400"),
    ])
```

Dans `MaillageCoeurTests/GrapheReseauTests.swift`, remplacer :

```swift
    }

    /// Un enfant devenu routeur garde jusqu'a 30 minutes son entree du balayage d'un routeur muet, sous
    /// son ancien RLOC16 : elle est ecartee, son ExtMac etant celle d'un routeur du maillage. Pas de
    /// noeud « Non identifie » en double, ni de lien, ni d'ExtMac a son nom (la cle d'un choix de piece).
```

par :

```swift
    }

    /// Un enfant devenu routeur garde jusqu'a 30 minutes son entree de la resolution sous un routeur muet, sous
    /// son ancien RLOC16 : elle est ecartee, son ExtMac etant celle d'un routeur du maillage. Pas de
    /// noeud « Non identifie » en double, ni de lien, ni d'ExtMac a son nom (la cle d'un choix de piece).
```

Dans `MaillageCoeurTests/GrapheReseauTests.swift`, remplacer :

```swift
        c.identite("E000000000000004", routeur: 1)
        c.muet(2)
        c.enfant(EnfantMaillage(rloc16: 0x0802, extMac: "E000000000000004", source: .balayage))
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        let g = GrapheReseau(reseau: r, appareils: RapprochementTests.affiches(i), maillage: m)
```

par :

```swift
        c.identite("E000000000000004", routeur: 1)
        c.muet(2)
        c.enfant(EnfantMaillage(rloc16: 0x0802, extMac: "E000000000000004", source: .resolution))
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        let g = GrapheReseau(reseau: r, appareils: RapprochementTests.affiches(i), maillage: m)
```

Dans `MaillageCoeurTests/RapprochementTests.swift`, remplacer :

```swift
    }

    /// Maillage de la capture ; `entendus` : les routeurs que la sonde entend (RLOC16 -> ExtMac).
    static func maillage(entendus: [UInt16: String] = [:]) async throws -> Maillage {
        let sonde = try SondeRejouee.capture(table: SondeRejouee.table(entendus: entendus))
        return try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: .now)).maillage
    }

```

par :

```swift
    }

    /// Maillage de la capture ; `entendus` : les routeurs que la sonde entend (RLOC16 -> ExtMac). L'appareil
    /// E00000000000000A est resolu sous AC00, muet, qui repond pour lui avec son propre RLOC16.
    static func maillage(entendus: [UInt16: String] = [:]) async throws -> Maillage {
        let cible = "fd00:5555:6666:0:b00::6"
        let sonde = try SondeRejouee.capture(table: SondeRejouee.table(entendus: entendus),
                                             resolutions: [cible: ResultatResolution(id: 0, cible: cible, ok: true, rloc16: "AC00")])
        let appareils = [AppareilAResoudre(id: "E00000000000000A", partition: "46CBEBCD", adresse: try #require(AdresseIPv6(cible)))]
        return try #require(try await Tournee.complete(sonde, memoire: MemoireTournee(), maintenant: .now,
                                                       appareils: appareils)).maillage
    }

```

Dans `MaillageCoeurTests/RapprochementTests.swift`, remplacer :

```swift
        #expect(m.enfants[0xAC09]?.id == "rloc:AC09", "la sonde, sans ExtMac (firmware d'essai)")
        #expect(m.inconnus.filter { $0.genre == .routeur }.map(\.id) == ["rloc:0400", "rloc:CC00", "rloc:E400"])
        #expect(m.inconnus.count == 12)
        #expect(m.liens.contains(LienAffiche(de: "E000000000000002", vers: "E000000000000003", genre: .radio, qualite: 3)))
        #expect(m.liens.contains(LienAffiche(de: "E000000000000004", vers: "E000000000000002", genre: .parent, qualite: 2)))
```

par :

```swift
        #expect(m.enfants[0xAC09]?.id == "rloc:AC09", "la sonde, sans ExtMac (firmware d'essai)")
        #expect(m.inconnus.filter { $0.genre == .routeur }.map(\.id) == ["rloc:0400", "rloc:CC00", "rloc:E400"])
        #expect(m.inconnus.count == 7, "3 routeurs ; 6002, 6005 et 6006, sans identite ; la sonde")
        #expect(m.liens.contains(LienAffiche(de: "E000000000000002", vers: "E000000000000003", genre: .radio, qualite: 3)))
        #expect(m.liens.contains(LienAffiche(de: "E000000000000004", vers: "E000000000000002", genre: .parent, qualite: 2)))
```

Dans `MaillageCoeurTests/MaillageDemoTests.swift`, remplacer :

```swift
        #expect(affiche.routeurs.values.filter { $0.bordure }.allSatisfy { $0.reconnu })
        let muet = try #require(m.routeurs.first { $0.muet })
        #expect(m.enfants(de: muet.id).allSatisfy { $0.qualite == nil && $0.source == .balayage })
    }

```

par :

```swift
        #expect(affiche.routeurs.values.filter { $0.bordure }.allSatisfy { $0.reconnu })
        let muet = try #require(m.routeurs.first { $0.muet })
        #expect(m.enfants(de: muet.id).allSatisfy { $0.qualite == nil && $0.source == .resolution })
    }

```

Dans `MaillageThreadTests/AffichageSondeTests.swift`, remplacer :

```swift
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: "SONDE-01", derniere: t - 120, avancement: nil, maintenant: t)
                == String(localized: "\("SONDE-01") : connectée · relevé \(FicheNoeud.relatif(t - 120, t))"))
        let balayage = AvancementTournee(etape: .balayage, fait: 24, total: 48)
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: "SONDE-01", derniere: t - 120, avancement: balayage, maintenant: t)
                == String(localized: "\("SONDE-01") : \(TexteTournee.etape(.balayage)) \(24)/\(48)…"))
        let rien = AvancementTournee(etape: .identites, fait: 0, total: 0)
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: nil, derniere: nil, avancement: rien, maintenant: t)
```

par :

```swift
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: "SONDE-01", derniere: t - 120, avancement: nil, maintenant: t)
                == String(localized: "\("SONDE-01") : connectée · relevé \(FicheNoeud.relatif(t - 120, t))"))
        let resolution = AvancementTournee(etape: .resolution, fait: 24, total: 48)
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: "SONDE-01", derniere: t - 120, avancement: resolution, maintenant: t)
                == String(localized: "\("SONDE-01") : \(TexteTournee.etape(.resolution)) \(24)/\(48)…"))
        let rien = AvancementTournee(etape: .identites, fait: 0, total: 0)
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: nil, derniere: nil, avancement: rien, maintenant: t)
```

Dans `MaillageThreadTests/AffichageSondeTests.swift`, remplacer :

```swift
        #expect(Set(etapes).count == etapes.count)
        #expect(!etapes.contains(""))
        let a = AvancementTournee(etape: .balayage, fait: 24, total: 48)
        #expect(TexteTournee.avancement(a) == String(localized: "\(TexteTournee.etape(.balayage)) · \(24)/\(48)"))
        #expect(TexteTournee.avancement(AvancementTournee(etape: .identites, fait: 0, total: 0))
                == TexteTournee.etape(.identites))
```

par :

```swift
        #expect(Set(etapes).count == etapes.count)
        #expect(!etapes.contains(""))
        let a = AvancementTournee(etape: .resolution, fait: 24, total: 48)
        #expect(TexteTournee.avancement(a) == String(localized: "\(TexteTournee.etape(.resolution)) · \(24)/\(48)"))
        #expect(TexteTournee.avancement(AvancementTournee(etape: .identites, fait: 0, total: 0))
                == TexteTournee.etape(.identites))
```

Dans `MaillageThreadTests/FenetreTests.swift`, remplacer :

```swift
    /// tournee) ; rien sans sonde. Le gabarit que compte la marge a la taille de la ligne montree.
    @Test func placeDeLaTournee() {
        let a = AvancementTournee(etape: .balayage, fait: 24, total: 48)
        let debut = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(LigneTournee.place(serie: "A0:00:00:00:00:01", debut: debut) == .montree)
```

par :

```swift
    /// tournee) ; rien sans sonde. Le gabarit que compte la marge a la taille de la ligne montree.
    @Test func placeDeLaTournee() {
        let a = AvancementTournee(etape: .resolution, fait: 24, total: 48)
        let debut = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(LigneTournee.place(serie: "A0:00:00:00:00:01", debut: debut) == .montree)
```

Dans `MaillageThreadTests/JournalMaillageTests.swift`, remplacer :

```swift
    }

    /// Appareil vu deux fois (le balayage ancien d'un routeur muet, et la table de son nouveau
    /// parent) : le journal le nomme comme l'appareil, sous son nouveau parent, meme si le graphe
    /// donne son id a l'entree du balayage (le premier RLOC16).
    @Test func appareilVuDeuxFois() throws {
        let s = Self.surveillance(dossier: nil)
```

par :

```swift
    }

    /// Appareil vu deux fois (la resolution ancienne sous un routeur muet, et la table de son nouveau
    /// parent) : le journal le nomme comme l'appareil, sous son nouveau parent, meme si le graphe
    /// donne son id a l'entree de la resolution (le premier RLOC16).
    @Test func appareilVuDeuxFois() throws {
        let s = Self.surveillance(dossier: nil)
```

Dans `MaillageThreadTests/JournalMaillageTests.swift`, remplacer :

```swift
                   chef: 1)
        c.muet(1)
        c.enfant(EnfantMaillage(rloc16: 0x0405, extMac: Self.appareil, source: .balayage))
        c.enfant(EnfantMaillage(rloc16: 0x1402, extMac: Self.appareil, qualite: 2, source: .tableEnfants))
        s.recevoir(c.maillage(), a: t.addingTimeInterval(300))
```

par :

```swift
                   chef: 1)
        c.muet(1)
        c.enfant(EnfantMaillage(rloc16: 0x0405, extMac: Self.appareil, source: .resolution))
        c.enfant(EnfantMaillage(rloc16: 0x1402, extMac: Self.appareil, qualite: 2, source: .tableEnfants))
        s.recevoir(c.maillage(), a: t.addingTimeInterval(300))
```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
    /// aboutit (maillage d'un routeur muet, sans enfant). `diag <cible> <tlv> <id> <ms>` :
    /// la Route64 a la demande de la liste des routeurs, `delai` a toute autre requete ;
    /// `routeurs` : le chef seul, parent de la sonde, donc sans ExtMac ; `voisins` : aucun.
    static func reseauMinimal(_ ligne: String) -> [String] {
        switch ligne {
```

par :

```swift
    /// aboutit (maillage d'un routeur muet, sans enfant). `diag <cible> <tlv> <id> <ms>` :
    /// la Route64 a la demande de la liste des routeurs, `delai` a toute autre requete ;
    /// `routeurs` : le chef seul, parent de la sonde, donc sans ExtMac ; `voisins` : aucun ;
    /// `annonces` (firmware 1.1.0) : aucun routeur entendu.
    static func reseauMinimal(_ ligne: String) -> [String] {
        switch ligne {
```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
        case "routeurs\n": return [routeurs([("0000", nil)], suite: false)]
        case "voisins\n": return [voisins([])]
        default: break
        }
```

par :

```swift
        case "routeurs\n": return [routeurs([("0000", nil)], suite: false)]
        case "voisins\n": return [voisins([])]
        case "annonces\n": return [annoncesVides]
        default: break
        }
```

- [ ] **Step 2 : les voir échouer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh MaillageCoeurTests/TourneeTests MaillageCoeurTests/SuiviMaillageTests MaillageCoeurTests/MaillageTests MaillageCoeurTests/HistoriqueTests MaillageCoeurTests/GrapheReseauTests MaillageCoeurTests/RapprochementTests MaillageCoeurTests/MaillageDemoTests MaillageThreadTests/AffichageSondeTests MaillageThreadTests/FenetreTests MaillageThreadTests/JournalMaillageTests MaillageThreadTests/SondeUSBTests MaillageThreadTests/SondeMaillageTests`

Expected : la compilation des tests échoue : `cannot find 'AppareilAResoudre' in scope`, `cannot find type 'AppareilAResoudre' in scope`, `extra argument 'appareils' in call` (`TourneeTests`, `RapprochementTests`).

- [ ] **Step 3 : la tournée, la résolution, le modèle, le journal et les textes de la tournée** (`--etapes 3`).

`MaillageCoeur/Maillage/Resolution.swift` :

```swift
import Foundation

/// Appareil Matter ou HomeKit sur Thread que l'app connait, a resoudre par la sonde (spec de la sonde tout-en-un,
/// section 2.2) : son adresse sur le prefixe OMR de sa partition.
public struct AppareilAResoudre: Hashable, Sendable {
    /// Identifiant de l'appareil dans l'instantane : son hote, l'ExtMac d'un appareil Matter.
    public let id: String
    public let partition: String
    /// Son adresse sur le prefixe OMR de sa partition, sans zone (`AdresseIPv6`) : la sonde n'accepte que l'adresse nue.
    public let adresse: AdresseIPv6

    public init(id: String, partition: String, adresse: AdresseIPv6) {
        self.id = id
        self.partition = partition
        self.adresse = adresse
    }

    /// Les appareils Thread d'un instantane qui ont une partition et une adresse sur son prefixe OMR, par identifiant.
    /// La tournee garde ceux de la partition de la sonde : la resolution ne traverse pas les partitions.
    public static func depuis(_ i: Instantane) -> [AppareilAResoudre] {
        i.appareils.compactMap { a in
            guard a.genre == .thread, let p = a.partition, let prefixe = a.prefixe,
                  let adresse = a.adresses.first(where: prefixe.contient) else { return nil }
            return AppareilAResoudre(id: a.id, partition: p, adresse: adresse)
        }.sorted { $0.id < $1.id }
    }
}

/// Parent d'un appareil trouve par la resolution d'adresse (spec de la sonde tout-en-un, section 2.2), garde en memoire
/// de la tournee jusqu'a la resolution complete suivante (30 min).
public struct ResolutionAppareil: Hashable, Sendable {
    /// RLOC16 rendu par la sonde : celui du parent (un routeur Apple repond pour son enfant avec le sien), ou celui de
    /// l'enfant (un routeur tiers repond avec celui de l'enfant).
    public let rloc16: UInt16
    /// ML-EID de l'appareil, quand le cache de la sonde le donne : ses compteurs MAC se demandent la (le diagnostic
    /// n'est accepte que sur les adresses internes du reseau). Jamais dans l'historique.
    public let mleid: AdresseIPv6?
    /// L'adresse resolue (sur le prefixe OMR de la partition).
    public let adresse: AdresseIPv6
    public let date: Date
    /// Qualite tiree des compteurs MAC a cette resolution (`QualiteCompteurs`), et le taux d'echec ; nil : inconnue.
    public var qualite: Int?
    public var echecs: Double?

    public init(rloc16: UInt16, mleid: AdresseIPv6?, adresse: AdresseIPv6, date: Date, qualite: Int? = nil,
                echecs: Double? = nil) {
        self.rloc16 = rloc16
        self.mleid = mleid
        self.adresse = adresse
        self.date = date
        self.qualite = qualite
        self.echecs = echecs
    }

    /// Identifiant de routeur du parent : le RLOC16 rendu, sans ses 10 bits de poids faible.
    public var parent: Int { Int(rloc16 >> 10) }
}
```

`MaillageCoeur/Maillage/Tournee.swift`, fichier entier :

```swift
import Foundation

/// Ce que la tournee demande a la sonde : la liaison USB dans l'app, une sonde
/// rejouee dans les tests.
public protocol InterlocuteurSonde: Sendable {
    func etat() async throws -> EtatSonde
    /// Table des routeurs de la sonde (`routeurs`, lignes `suite` reunies) : tous les routeurs
    /// de la partition par leur RLOC16, l'ExtMac de ceux qu'elle entend. Requete locale, sans
    /// delai reseau.
    func routeurs() async throws -> [RouteurSonde]
    /// Routeurs voisins que la sonde entend (`voisins`), avec leur signal ; son parent n'y est
    /// pas (`etat` le donne). Requete locale, sans delai reseau.
    func voisins() async throws -> [VoisinSonde]
    /// Routeurs dont la sonde a entendu les messages MLE (`annonces`, lignes `suite` reunies ; firmware 1.1.0),
    /// avec leur derniere Route64 brute. Requete locale, sans delai reseau. Un firmware plus ancien ne la connait pas.
    func annonces() async throws -> [AnnonceSonde]
    /// `DIAG_GET` vers un RLOC16 : la reponse, ou l'echec (`delai`, `occupee`...).
    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag
    /// `DIAG_GET` vers une adresse du reseau maille (le ML-EID d'un enfant) : la reponse, ou l'echec.
    func diag(adresse: AdresseIPv6, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag
    /// Resolution d'une adresse (`resoudre`, firmware 1.1.0) : le RLOC16 trouve en 15 s au plus, ou l'echec
    /// (`introuvable`, un refus).
    func resoudre(_ adresse: AdresseIPv6) async throws -> ResultatResolution
}

/// Avancement d'une tournee : l'etape en cours, ses requetes revenues et le total prevu a
/// ce moment. Au cours d'une etape, `fait` monte de un a chaque requete revenue et le total
/// ne baisse jamais. Liste des routeurs : le chef et les secours, puis, s'il faut chercher,
/// les autres routeurs de la table de la sonde et tous les autres identifiants (ceux-ci pas
/// dans les 30 min qui suivent une recherche complete vaine) ; l'etape s'arrete a la premiere
/// Route64, souvent avant son total.
public struct AvancementTournee: Hashable, Sendable {
    /// Etapes d'une tournee, dans l'ordre.
    public enum Etape: CaseIterable, Hashable, Sendable {
        /// `etat` de la sonde, puis sa table des routeurs (`routeurs`), ses voisins (`voisins`) et les routeurs
        /// qu'elle entend (`annonces`).
        case etatSonde
        /// Route64 : au chef, aux secours, puis recherche.
        case listeRouteurs
        /// Interrogation des routeurs.
        case routeurs
        /// Pile (une fois par routeur qui repond) et Network Data.
        case pileEtReseau
        /// Resolution des parents des appareils (toutes les 30 min, et un appareil nouveau).
        case resolution
        /// Compteurs MAC des enfants resolus sous un routeur qui ne repond pas.
        case compteurs
        /// Identite des enfants des tables.
        case identites
    }

    public let etape: Etape
    /// Requetes de l'etape revenues.
    public let fait: Int
    /// Requetes prevues pour l'etape a ce moment ; 0 : rien a faire.
    public let total: Int

    public init(etape: Etape, fait: Int, total: Int) {
        self.etape = etape
        self.fait = fait
        self.total = total
    }
}

/// Ce que la tournee retient d'une fois sur l'autre (spec de la sonde, section 4).
public struct MemoireTournee: Hashable, Sendable {
    /// Silences de suite (`delai`), par routeur : muet a partir de 2. Un refus de la sonde
    /// (`occupee`, `suspendue`...) ou une reponse illisible n'en est pas un.
    public var echecs: [Int: Int] = [:]
    /// Derniere interrogation d'un routeur muet : une fois par heure.
    public var muetInterroge: [Int: Date] = [:]
    /// Pile (TLV 28), demandee une fois par routeur qui repond ; "" : aucune.
    public var piles: [Int: String] = [:]
    /// ExtMac des routeurs, par RLOC16 : parents successifs de la sonde, routeurs qui repondent,
    /// routeurs que la sonde entend (sa table des routeurs, ses annonces). Une ExtMac n'a qu'un RLOC16 (`retenir`).
    public var identites: [UInt16: String] = [:]
    /// Parents trouves par la resolution d'adresse, par appareil (spec de la sonde tout-en-un, section 2.2) : ceux de
    /// la derniere resolution complete, et des appareils nouveaux depuis ; oublies quand leur parent sort de la liste.
    public var resolutions: [String: ResolutionAppareil] = [:]
    /// Appareils demandes depuis la derniere resolution complete, resolus ou non (une demande que la sonde refuse ne
    /// compte pas) : un appareil qui n'y est pas est nouveau, et se resout a la tournee suivante.
    public var demandes: Set<String> = []
    /// Derniere resolution complete (toutes les 30 min ; une resolution dont la sonde a refuse toutes les demandes ne
    /// compte pas).
    public var derniereResolution: Date?
    /// Dernier releve des compteurs MAC de chaque enfant resolu sous un routeur muet, par appareil : le prochain
    /// donnera son taux d'echec (`QualiteCompteurs`).
    public var compteurs: [String: CompteursMac] = [:]
    /// Enfants des tables identifies (ExtMac, adresses), par RLOC16 : gardes jusqu'a une nouvelle
    /// reponse ; oublies quand leur parent sort de la liste des routeurs, ou qu'ils manquent a la
    /// table de leur parent qui l'a donnee.
    public var identifies: [UInt16: EnfantMaillage] = [:]
    /// Derniere demande d'identite a un enfant des tables, par RLOC16 : une par demi-heure
    /// au plus, qu'il ait repondu ou non (une demande refusee par la sonde ne compte pas) ;
    /// oubliee avec son identite.
    public var identiteDemandee: [UInt16: Date] = [:]
    /// Routeurs qui ont repondu a la derniere tournee ou l'un a repondu : Route64 de
    /// secours quand le chef ne la donne pas.
    public var repondants: [Int] = []
    /// Derniere recherche complete de la Route64 restee vaine (une recherche dont la sonde a
    /// refuse toutes les requetes ne compte pas) : pas de nouvelle recherche complete avant
    /// `Tournee.periodeRecherche`.
    public var rechercheVaine: Date?
    /// Dernieres Network Data lues : elles servent quand leur requete echoue ou n'est pas faite
    /// (aucun routeur ne repond) ; sinon les routeurs de bordure, le BBR principal et les
    /// candidats disparaitraient d'une tournee a l'autre.
    public var donneesReseau: DonneesReseau?
    /// Partition de ce qui est retenu : une autre remet tout a zero.
    public var partition: String?

    public init() {}

    public func estMuet(_ id: Int) -> Bool { (echecs[id] ?? 0) >= 2 }

    /// Retient l'ExtMac d'un routeur. Un routeur qui a change d'identifiant (redemarrage) perd
    /// l'ancienne paire : elle ne donne plus son ExtMac a l'identifiant libere.
    mutating func retenir(_ ext: String, rloc16: UInt16) {
        for (r, e) in identites where e == ext && r != rloc16 { identites[r] = nil }
        identites[rloc16] = ext
    }
}

/// Tournee de la sonde : liste des routeurs, routeurs qui repondent, roles, liens entendus par la
/// sonde, puis resolution des parents des appareils et qualite des enfants des routeurs muets.
public enum Tournee {
    public static let tlvChef: [UInt8] = [TypeTLV.route64, TypeTLV.donneesChef]
    public static let tlvRouteur: [UInt8] = [TypeTLV.extMac, TypeTLV.address16, TypeTLV.route64, TypeTLV.tableEnfants,
                                             TypeTLV.adresses, TypeTLV.version]
    public static let tlvPile: [UInt8] = [TypeTLV.fabricant, TypeTLV.modele, TypeTLV.versionLogicielle, TypeTLV.pile]
    public static let tlvReseau: [UInt8] = [TypeTLV.donneesReseau]
    public static let tlvIdentite: [UInt8] = [TypeTLV.extMac, TypeTLV.adresses]
    /// Compteurs MAC d'un enfant, demandes a son ML-EID (spec de la sonde tout-en-un, section 2.3).
    public static let tlvCompteurs: [UInt8] = [TypeTLV.compteursMac]
    public static let delaiRouteur = 6000
    /// Requetes en vol a la fois (la sonde en tient 8, et 8 resolutions).
    public static let enVol = 8
    /// Delai d'un enfant : un endormi ne repond qu'a son reveil.
    public static let delaiEnfant = 8000
    /// Identites des enfants des tables : redemandees apres ce delai.
    public static let periodeIdentite: TimeInterval = 30 * 60
    /// Resolution complete des parents : toutes les 30 min (un appareil nouveau, a la tournee suivante).
    public static let periodeResolution: TimeInterval = 30 * 60
    public static let periodeMuet: TimeInterval = 3600
    /// Apres une recherche complete de la Route64 vaine, delai avant la suivante.
    public static let periodeRecherche: TimeInterval = 30 * 60

    /// Une tournee, et la resolution des parents si elle est due : le maillage et la memoire a garder. Pas de
    /// maillage si la sonde n'est pas attachee, ou suspendue dans Maison (ses requetes echoueraient toutes : aucun
    /// routeur ne doit passer pour muet ; memoire inchangee), ou si aucun routeur n'a donne la liste des routeurs
    /// (Route64) : la memoire rendue est alors celle d'avant (remise a zero dans une autre partition), avec les seules
    /// identites apprises par `etat`, la table des routeurs et les annonces, qu'une sonde promenee garde ainsi, et la
    /// date d'une recherche complete vaine.
    /// Le maillage porte aussi le signal des routeurs que la sonde entend (`voisins`) et celui de son parent (`etat`),
    /// pour l'historique (spec de la sonde, section 6) ; et, depuis le firmware 1.1.0 (spec de la sonde tout-en-un,
    /// section 2), les liens des routeurs dont la sonde entend les annonces, fusionnes avec ceux du diagnostic, et les
    /// enfants des routeurs muets rattaches par la resolution d'adresse de `appareils` (ceux de la partition de la
    /// sonde, elle exceptee), avec la qualite que donnent leurs compteurs MAC.
    /// `avancement` est appele au debut de chaque etape atteinte, puis a chaque requete revenue (voir
    /// `AvancementTournee`), depuis la tache de la tournee.
    public static func executer(_ sonde: some InterlocuteurSonde, memoire: MemoireTournee, maintenant: Date,
                                appareils: [AppareilAResoudre] = [],
                                avancement: (@Sendable (AvancementTournee) -> Void)? = nil)
        async throws -> (maillage: Maillage?, memoire: MemoireTournee) {
        func signaler(_ etape: AvancementTournee.Etape, _ fait: Int, _ total: Int) {
            avancement?(AvancementTournee(etape: etape, fait: fait, total: total))
        }
        var mem = memoire
        signaler(.etatSonde, 0, 4)
        let etat = try await sonde.etat()
        signaler(.etatSonde, 1, 4)
        guard etat.estAttachee, !etat.suspendue, let partition = etat.partition, let chef = etat.chef,
              let moi = etat.rloc16Valeur else { return (nil, memoire) }
        // Autre partition : les identifiants de routeur y sont redistribues, rien ne vaut plus.
        if let ancienne = mem.partition, ancienne != partition { mem = MemoireTournee() }
        mem.partition = partition
        // Table des routeurs de la sonde (requete locale, sans delai reseau) : ExtMac des routeurs
        // qu'elle entend. Sans table (firmware sans `routeurs`, sonde occupee), la tournee continue.
        let table = (try? await sonde.routeurs()) ?? []
        signaler(.etatSonde, 2, 4)
        // Voisins de la sonde (requete locale) : le signal de chaque routeur qu'elle entend. Sans
        // reponse, la tournee continue sans eux.
        let voisins = (try? await sonde.voisins()) ?? []
        signaler(.etatSonde, 3, 4)
        // Routeurs dont la sonde entend les messages MLE (requete locale, firmware 1.1.0) : ceux de sa partition, du
        // plus ancien message au plus recent. Sans reponse (firmware 1.0.x), la tournee continue sans l'ecoute, sans
        // la resolution et sans les compteurs, que la sonde ne connait pas.
        let annonces = (try? await sonde.annonces()).map { liste in
            liste.filter { $0.partition == partition && ($0.rloc16Valeur.map { $0 & 0x3FF == 0 } ?? false) }
                .sorted { $0.ageS > $1.ageS }
        }
        signaler(.etatSonde, 4, 4)
        var c = ConstructionMaillage(date: maintenant, partition: partition)
        for v in voisins where v.routeur {
            if let r = UInt16(v.rloc16, radix: 16) { c.signal(SignalSonde(routeur: Int(r >> 10), rssi: v.rssi)) }
        }
        // Chaque annonce relie un RLOC16 a une ExtMac, comme le parent de la sonde ; la plus recente l'emporte, et le
        // parent et la table, plus frais, passent apres.
        for a in annonces ?? [] {
            if let r = a.rloc16Valeur { mem.retenir(a.ext, rloc16: r) }
        }
        if let p = etat.parent, let rp = UInt16(p.rloc16, radix: 16) {
            mem.retenir(p.ext, rloc16: rp)
            c.enfant(EnfantMaillage(rloc16: moi, extMac: etat.ext, qualite: p.lqOut, source: .sonde))
            // Apres les voisins : le signal du parent, donne par `etat`, passe avant.
            c.signal(SignalSonde(routeur: Int(rp >> 10), rssi: p.rssi))
        }
        for r in table {
            if let ext = r.ext, let rloc = r.rloc16Valeur { mem.retenir(ext, rloc16: rloc) }
        }

        // 1. Liste des routeurs : Route64 du chef, puis des routeurs qui ont repondu a la
        // tournee precedente (avant le chef s'il est muet) ; sinon, des autres routeurs de la
        // table de la sonde, puis des autres identifiants.
        let secours = mem.repondants.filter { $0 != chef }
        let essais = mem.estMuet(chef) ? secours + [chef] : [chef] + secours
        var route64: Route64?
        signaler(.listeRouteurs, 0, essais.count)
        for (n, id) in essais.enumerated() {
            let r = try await sonde.diag(rloc16(id), tlvChef, delaiMs: delaiRouteur)
            signaler(.listeRouteurs, n + 1, essais.count)
            if let r64 = r.reponse?.route64 {
                route64 = r64
                break
            }
        }
        if route64 == nil {
            // D'abord les autres routeurs de la table de la sonde ; puis les autres identifiants,
            // sauf dans les 30 min qui suivent une recherche complete vaine (sans reponse, elle
            // coute 63 requetes, pres d'une minute).
            let deLaTable = Set(table.map(\.id)).subtracting(essais).filter { (0...62).contains($0) }.sorted()
            let complete = mem.rechercheVaine.map { maintenant.timeIntervalSince($0) >= periodeRecherche } ?? true
            let autres = complete ? (0...62).filter { !essais.contains($0) && !deLaTable.contains($0) } : []
            let parGroupes = groupes(deLaTable) + groupes(autres)
            let recherche = try await chercherRoute64(sonde, groupes: parGroupes) { faites, prevues in
                signaler(.listeRouteurs, essais.count + faites, essais.count + prevues)
            }
            route64 = recherche.route64
            if route64 == nil, complete, !recherche.refusee { mem.rechercheVaine = maintenant }
        }
        guard let route64 else { return (nil, mem) }
        c.routeurs(route64, chef: chef)
        // Routeurs sortis de la liste (routeur disparu, identifiant libere) : leur paire, leurs
        // echecs, leur pile, leur place de secours et les enfants resolus sous eux sont oublies ; un
        // identifiant reattribue repart de zero.
        let liste = Set(route64.routeurs)
        mem.identites = mem.identites.filter { liste.contains(Int($0.key >> 10)) }
        mem.echecs = mem.echecs.filter { liste.contains($0.key) }
        mem.muetInterroge = mem.muetInterroge.filter { liste.contains($0.key) }
        mem.piles = mem.piles.filter { liste.contains($0.key) }
        mem.repondants = mem.repondants.filter { liste.contains($0) }
        mem.resolutions = mem.resolutions.filter { liste.contains($0.value.parent) }

        // 2. Chaque routeur, en parallele, sauf un muet deja interroge dans l'heure.
        let aInterroger = route64.routeurs.filter { id in
            guard mem.estMuet(id), let quand = mem.muetInterroge[id] else { return true }
            return maintenant.timeIntervalSince(quand) >= periodeMuet
        }
        signaler(.routeurs, 0, aInterroger.count)
        var repondants: [Int] = []
        let reponsesRouteurs = try await parallele(aInterroger, {
            try await sonde.diag(rloc16($0), tlvRouteur, delaiMs: delaiRouteur)
        }, apresChacune: { n, _, _ in signaler(.routeurs, n, aInterroger.count) })
        // Reponse trop longue pour le reseau : le routeur a repondu. Sa requete est refaite une
        // fois, en deux moities de TLV, reunies ; une moitie encore trop longue (ou sans reponse)
        // est laissee : ce qu'on a est garde, sans echec.
        let aCouper = reponsesRouteurs.filter { $0.1.tropLong }.flatMap { r in moities(tlvRouteur).map { (r.0, $0) } }
        var reunies: [Int: String] = [:]
        if !aCouper.isEmpty {
            let total = aInterroger.count + aCouper.count
            signaler(.routeurs, aInterroger.count, total)
            let reponsesMoities = try await parallele(aCouper, {
                try await sonde.diag(rloc16($0.0), $0.1, delaiMs: delaiRouteur)
            }, apresChacune: { n, _, _ in signaler(.routeurs, aInterroger.count + n, total) })
            for ((id, _), r) in reponsesMoities {
                if let t = r.tlv, r.reponse != nil { reunies[id, default: ""] += t }
            }
        }
        var sansExtMac: [Int] = []
        // Enfants de la table de chaque routeur qui l'a donnee.
        var tables: [Int: Set<UInt16>] = [:]
        for (id, r) in reponsesRouteurs {
            if let rep = r.tropLong ? ReponseDiagnostic(hexa: reunies[id] ?? "") : r.reponse {
                c.reponse(rep, routeur: id)
                mem.echecs[id] = 0
                mem.muetInterroge[id] = nil
                if let ext = rep.extMac {
                    mem.retenir(ext, rloc16: rloc16(id))
                } else {
                    sansExtMac.append(id)
                }
                if let enfants = rep.enfants { tables[id] = Set(enfants.map { $0.rloc16(parent: rloc16(id)) }) }
                repondants.append(id)
            } else if r.silence {
                // Seul un silence compte : un refus de la sonde, ou une reponse illisible, ne dit
                // pas que le routeur se tait.
                mem.echecs[id, default: 0] += 1
                if mem.estMuet(id) { mem.muetInterroge[id] = maintenant }
            }
        }
        // Personne n'a repondu (sonde occupee...) : les secours d'avant restent.
        if !repondants.isEmpty { mem.repondants = repondants }
        let muets = Set(route64.routeurs).subtracting(repondants)
        for id in muets.sorted() { c.muet(id) }
        // Muets, et repondants sans ExtMac (moitie d'un `trop_long` sans reponse...) : l'identite
        // connue, lue apres toutes les reponses (une ExtMac passee a un autre routeur a oublie sa
        // paire perimee).
        for id in muets.sorted() + sansExtMac {
            if let ext = mem.identites[rloc16(id)] { c.identite(ext, routeur: id) }
        }

        // 3. Pile, une fois ; Network Data, a un routeur qui repond.
        let sansPile = repondants.filter { mem.piles[$0] == nil }
        let totalPile = sansPile.count + (repondants.isEmpty ? 0 : 1)
        signaler(.pileEtReseau, 0, totalPile)
        for (n, id) in sansPile.enumerated() {
            let r = try await sonde.diag(rloc16(id), tlvPile, delaiMs: delaiRouteur)
            signaler(.pileEtReseau, n + 1, totalPile)
            if let rep = r.reponse { mem.piles[id] = rep.pile ?? "" }
        }
        for id in repondants {
            c.pile(mem.piles[id].flatMap { $0.isEmpty ? nil : $0 }, routeur: id)
        }
        var lues: DonneesReseau?
        if let id = repondants.first {
            let r = try await sonde.diag(rloc16(id), tlvReseau, delaiMs: delaiRouteur)
            signaler(.pileEtReseau, totalPile, totalPile)
            if let brutes = r.reponse?.donneesReseau { lues = DonneesReseau(brutes) }
        }
        if let d = lues {
            c.reseau(d)
            mem.donneesReseau = d
        } else if let d = mem.donneesReseau {
            // Requete en echec, ou aucun routeur qui reponde : les dernieres lues, pour les seuls
            // routeurs de la liste.
            c.reseau(d, seulementConnus: true)
        }

        // 4. Ecoute (spec de la sonde tout-en-un, section 2.1) : la Route64 de chaque annonce d'un routeur de la
        // liste donne ses liens, dates de l'age que donne la sonde ; chaque sens garde la mesure la plus recente,
        // diagnostic ou ecoute (`ConstructionMaillage.lien`).
        if let annonces {
            for a in annonces {
                guard let r = a.rloc16Valeur else { continue }
                c.ecoute(a.route64Decodee, routeur: Int(r >> 10), date: maintenant.addingTimeInterval(-TimeInterval(a.ageS)))
            }
            c.annoncesRecues()
        }

        // 5. Resolution des parents (spec de la sonde tout-en-un, section 2.2), a la place du balayage : toutes les
        // 30 min, et pour un appareil nouveau a la tournee suivante ; 8 en vol. Une demande que la sonde refuse ne
        // compte pas : elle est refaite a la tournee suivante. Une resolution complete remplace la precedente, sauf
        // si la sonde a refuse toutes ses demandes ; un appareil non resolu reste en rattachement suppose.
        let moiExt = etat.ext?.uppercased()
        let cibles = appareils.filter { $0.partition == partition && $0.id.uppercased() != moiExt }.sorted { $0.id < $1.id }
        let complete = mem.derniereResolution.map { maintenant.timeIntervalSince($0) >= periodeResolution } ?? true
        let aResoudre = annonces == nil ? [] : complete ? cibles : cibles.filter { !mem.demandes.contains($0.id) }
        signaler(.resolution, 0, aResoudre.count)
        let resolues = try await parallele(aResoudre, { try await sonde.resoudre($0.adresse) },
                                           apresChacune: { n, _, _ in signaler(.resolution, n, aResoudre.count) })
        var nouvelles: [String: ResolutionAppareil] = [:]
        var demandees: Set<String> = []
        for (a, r) in resolues where !r.refus {
            demandees.insert(a.id)
            if let rloc = r.rloc16Valeur {
                nouvelles[a.id] = ResolutionAppareil(rloc16: rloc, mleid: r.adresseMleid, adresse: a.adresse, date: maintenant)
            }
        }
        if complete && annonces != nil {
            if aResoudre.isEmpty || !demandees.isEmpty {
                // Un appareil refuse cette fois garde sa resolution d'avant, et sera demande de nouveau.
                let refuses = Set(aResoudre.map(\.id)).subtracting(demandees)
                mem.resolutions = nouvelles.merging(mem.resolutions.filter { refuses.contains($0.key) }) { n, _ in n }
                mem.demandes = demandees
                mem.derniereResolution = maintenant
            }
        } else {
            mem.resolutions.merge(nouvelles) { _, n in n }
            mem.demandes.formUnion(demandees)
        }

        // 6. Compteurs MAC (spec de la sonde tout-en-un, section 2.3) : a sa resolution, chaque enfant d'un routeur
        // muet (Apple) dont la sonde connait le ML-EID ; le taux d'echec entre deux releves donne sa qualite. Sans
        // reponse, la qualite reste inconnue et le releve d'avant reste.
        let aMesurer = nouvelles.filter { muets.contains($0.value.parent) }.sorted { $0.key < $1.key }
            .compactMap { id, r in r.mleid.map { (id, $0) } }
        signaler(.compteurs, 0, aMesurer.count)
        let mesures = try await parallele(aMesurer, {
            try await sonde.diag(adresse: $0.1, tlvCompteurs, delaiMs: delaiEnfant)
        }, apresChacune: { n, _, _ in signaler(.compteurs, n, aMesurer.count) })
        for ((id, _), r) in mesures {
            guard let releve = r.reponse?.compteursMac else { continue }
            if let avant = mem.compteurs[id], let q = QualiteCompteurs.mesure(avant: avant, apres: releve) {
                mem.resolutions[id]?.qualite = q.qualite
                mem.resolutions[id]?.echecs = q.taux
            }
            mem.compteurs[id] = releve
        }

        // 7. Enfants des tables : ExtMac et adresses, gardees jusqu'a une nouvelle reponse ;
        // demandees de nouveau apres 30 min, que l'enfant ait repondu ou non.
        // Endormis sous un routeur qui repond : interroges au plus une fois par demi-heure, la Child Table ne donnant pas leur ExtMac.
        // L'identite d'un enfant (et la date de sa demande) est oubliee quand son parent sort de la
        // liste, ou qu'il manque a la table de son parent qui l'a donnee : un appareil qui reprend
        // son RLOC16 n'a pas l'ancien nom, et son identite est demandee tout de suite.
        func garde(_ enfant: UInt16) -> Bool {
            let parent = Int(enfant >> 10)
            return liste.contains(parent) && (tables[parent].map { $0.contains(enfant) } ?? true)
        }
        mem.identifies = mem.identifies.filter { garde($0.key) }
        mem.identiteDemandee = mem.identiteDemandee.filter { garde($0.key) }
        let aIdentifier = c.enfantsSansIdentite.filter { cible in
            mem.identiteDemandee[cible].map { maintenant.timeIntervalSince($0) >= periodeIdentite } ?? true
        }
        signaler(.identites, 0, aIdentifier.count)
        let identites = try await parallele(aIdentifier, {
            try await sonde.diag($0, tlvIdentite, delaiMs: delaiEnfant)
        }, apresChacune: { n, _, _ in signaler(.identites, n, aIdentifier.count) })
        for (cible, r) in identites {
            // Une demande refusee par la sonde n'est pas faite : elle le sera a la tournee suivante.
            if !r.refus { mem.identiteDemandee[cible] = maintenant }
            guard let rep = r.reponse else { continue }
            mem.identifies[cible] = EnfantMaillage(rloc16: cible, extMac: rep.extMac, adresses: rep.adresses, source: .tableEnfants)
        }
        for cible in c.enfantsSansIdentite {
            if let e = mem.identifies[cible] { c.enfant(e) }
        }

        // 8. Enfants resolus, sous leur parent muet (sous un routeur qui repond, sa table fait foi), apres les
        // identites : pas un appareil deja la (meme ExtMac ou meme adresse qu'un enfant des tables ou de la sonde : il
        // a change de parent depuis), ni un routeur lui-meme. Le RLOC16 rendu est celui de l'enfant (routeur tiers),
        // ou celui du parent (routeur Apple) : l'enfant recoit alors un numero invente sous lui
        // (`EnfantMaillage.bitInvente`), dans l'ordre des appareils.
        let dejaLa = c.maillage()
        let extMacs = Set(dejaLa.enfants.compactMap(\.extMac)), adresses = Set(dejaLa.enfants.flatMap(\.adresses))
        var inventes: [Int: UInt16] = [:]
        for (id, r) in mem.resolutions.sorted(by: { $0.key < $1.key }) where muets.contains(r.parent) {
            let ext = GrapheReseau.extMac(hote: id)
            if let ext, extMacs.contains(ext) { continue }
            if adresses.contains(r.adresse) { continue }
            var rloc = r.rloc16
            if rloc & 0x3FF == 0 {
                // Le RLOC16 d'un routeur : l'appareil est ce routeur lui-meme (son ExtMac), ou un enfant d'un routeur Apple.
                if let ext, ext == dejaLa.routeur(r.parent)?.extMac?.uppercased() { continue }
                let k = inventes[r.parent, default: 0]
                inventes[r.parent] = k + 1
                rloc = rloc16(r.parent) | EnfantMaillage.bitInvente | (k & 0x1FF)
            } else if rloc == moi {
                continue
            }
            c.enfant(EnfantMaillage(rloc16: rloc, extMac: ext, qualite: r.qualite, adresses: [r.adresse],
                                    source: .resolution, resolu: r.date, echecs: r.echecs))
        }
        var maillage = c.maillage()
        // Date de la resolution complete dont viennent les enfants resolus (une resolution refusee ne la change pas).
        maillage.resolution = mem.derniereResolution
        return (maillage, mem)
    }

    static func rloc16(_ routeur: Int) -> UInt16 { UInt16(routeur) << 10 }

    /// Une requete coupee en deux moities de TLV (reponse trop longue pour le reseau).
    static func moities(_ tlv: [UInt8]) -> [[UInt8]] {
        let milieu = tlv.count / 2
        return [Array(tlv[..<milieu]), Array(tlv[milieu...])].filter { !$0.isEmpty }
    }

    /// Identifiants par groupes de `enVol`, dans l'ordre.
    static func groupes(_ ids: [Int]) -> [[Int]] {
        stride(from: 0, to: ids.count, by: enVol).map { Array(ids[$0..<min($0 + enVol, ids.count)]) }
    }

    /// Route64 quand ni le chef ni les secours ne l'ont donnee (chef muet des le lancement) :
    /// les `groupes` d'identifiants dans l'ordre, chacun en parallele ; au premier groupe ou l'un
    /// la donne, celle du premier du groupe (le plus petit). `refusee` : il y a eu des requetes,
    /// et la sonde les a toutes refusees. `suivi` : requetes revenues et prevues (tous ces
    /// identifiants), au debut puis a chaque requete revenue.
    static func chercherRoute64(_ sonde: some InterlocuteurSonde, groupes: [[Int]],
                                suivi: (_ faites: Int, _ prevues: Int) -> Void = { _, _ in }) async throws
        -> (route64: Route64?, refusee: Bool) {
        let prevues = groupes.reduce(0) { $0 + $1.count }
        suivi(0, prevues)
        var faites = 0
        var refusee = !groupes.isEmpty
        for groupe in groupes {
            let avant = faites
            let resultats = try await parallele(groupe, {
                try await sonde.diag(rloc16($0), tlvChef, delaiMs: delaiRouteur)
            }, apresChacune: { n, _, _ in suivi(avant + n, prevues) })
            faites += groupe.count
            for (_, r) in resultats {
                if let route64 = r.reponse?.route64 { return (route64, false) }
                refusee = refusee && r.refus
            }
        }
        return (nil, refusee)
    }

    /// Au plus `enVol` requetes a la fois ; resultats dans l'ordre des elements.
    /// `apresChacune` : a chaque requete revenue, le nombre de revenues, l'element et son resultat.
    static func parallele<E: Sendable, R: Sendable>(_ elements: [E],
                                                    _ requete: @escaping @Sendable (E) async throws -> R,
                                                    apresChacune: (_ faites: Int, _ element: E, _ resultat: R) -> Void = { _, _, _ in })
        async throws -> [(E, R)] {
        var resultats: [(Int, E, R)] = []
        try await withThrowingTaskGroup(of: (Int, E, R).self) { groupe in
            var suivant = 0
            func lancer() {
                let i = suivant
                suivant += 1
                let e = elements[i]
                groupe.addTask { (i, e, try await requete(e)) }
            }
            while suivant < min(enVol, elements.count) { lancer() }
            while let r = try await groupe.next() {
                resultats.append(r)
                apresChacune(resultats.count, r.1, r.2)
                if suivant < elements.count { lancer() }
            }
        }
        return resultats.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2) }
    }
}

fileprivate extension ResultatDiag {
    /// Silence de la cible : la requete est partie, et rien n'est revenu a temps (`delai`). Une
    /// reponse illisible (`ok`, TLV tronquee) n'en est pas un.
    var silence: Bool { !ok && erreur == "delai" }

    /// Refus : ni reponse (lisible ou non), ni `trop_long`, ni silence. La sonde n'a pas envoye
    /// la requete (`occupee`, `suspendue`, `envoi...`), ou elle rend une autre erreur d'OpenThread
    /// apres l'envoi (`Abort`...) : dans les deux cas, rien n'est dit de la cible.
    var refus: Bool { !ok && !tropLong && !silence }
}

fileprivate extension ResultatResolution {
    /// Refus : ni le RLOC16 trouve, ni `introuvable`. La sonde n'a pas fait la demande (`occupee`, `suspendue`,
    /// `envoi...`, `syntaxe`), ou ne l'a pas rendue a temps (`delai`) : rien n'est dit de l'appareil.
    var refus: Bool { !ok && !introuvable }
}
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    /// Child Table de son parent, un routeur qui repond.
    case tableEnfants
    /// Trouve par balayage sous un routeur muet.
    case balayage
    /// Rattache a son parent par la resolution d'adresse (spec de la sonde tout-en-un, section 2.2), sous un routeur
    /// qui ne repond pas au diagnostic.
```

par :

```swift
    /// Child Table de son parent, un routeur qui repond.
    case tableEnfants
    /// Rattache a son parent par la resolution d'adresse (spec de la sonde tout-en-un, section 2.2), sous un routeur
    /// qui ne repond pas au diagnostic.
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    /// croissant.
    public let signaux: [SignalSonde]
    /// Date du balayage dont viennent les enfants balayes de ce maillage
    /// (`MemoireTournee.dernierBalayage`) ; nil sans balayage.
    public var balayage: Date?
    /// La sonde a rendu ses annonces a cette tournee (firmware 1.1.0) : un routeur sans `entendu` n'est pas entendu.
    public var annoncesLues = false
```

par :

```swift
    /// croissant.
    public let signaux: [SignalSonde]
    /// Date de la resolution complete dont viennent les enfants resolus de ce maillage
    /// (`MemoireTournee.derniereResolution`) ; nil sans resolution.
    public var resolution: Date?
    /// La sonde a rendu ses annonces a cette tournee (firmware 1.1.0) : un routeur sans `entendu` n'est pas entendu.
    public var annoncesLues = false
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    /// Enfants identifies (ExtMac connue), un par ExtMac. Vu deux fois (il a change de parent),
    /// l'entree la plus fraiche l'emporte : la sonde (elle sait son parent), puis la table d'un
    /// routeur qui repond (l'ancien parent garde l'enfant jusqu'a son echeance), puis le balayage
    /// ou la resolution sous un routeur muet, qui peuvent dater de 30 minutes ; a egalite, la premiere
    /// par RLOC16. Une entree du balayage ou de la resolution dont l'ExtMac est celle d'un routeur du
    /// maillage est ecartee : l'enfant est devenu routeur depuis.
    public var enfantsIdentifies: [String: EnfantMaillage] {
        func rang(_ s: SourceEnfant) -> Int {
            switch s {
            case .sonde: 0
            case .tableEnfants: 1
            case .balayage, .resolution: 2
            }
        }
        let routeursExt = Set(routeurs.compactMap(\.extMac))
        var parExtMac: [String: EnfantMaillage] = [:]
        for e in enfants {
            let ancien = e.source == .balayage || e.source == .resolution
            guard let x = e.extMac, !(ancien && routeursExt.contains(x)) else { continue }
            if let deja = parExtMac[x], rang(deja.source) <= rang(e.source) { continue }
            parExtMac[x] = e
```

par :

```swift
    /// Enfants identifies (ExtMac connue), un par ExtMac. Vu deux fois (il a change de parent),
    /// l'entree la plus fraiche l'emporte : la sonde (elle sait son parent), puis la table d'un
    /// routeur qui repond (l'ancien parent garde l'enfant jusqu'a son echeance), puis la resolution
    /// sous un routeur muet, qui peut dater de 30 minutes ; a egalite, la premiere par RLOC16. Une
    /// entree de la resolution dont l'ExtMac est celle d'un routeur du maillage est ecartee : l'enfant
    /// est devenu routeur depuis.
    public var enfantsIdentifies: [String: EnfantMaillage] {
        func rang(_ s: SourceEnfant) -> Int {
            switch s {
            case .sonde: 0
            case .tableEnfants: 1
            case .resolution: 2
            }
        }
        let routeursExt = Set(routeurs.compactMap(\.extMac))
        var parExtMac: [String: EnfantMaillage] = [:]
        for e in enfants {
            guard let x = e.extMac, !(e.source == .resolution && routeursExt.contains(x)) else { continue }
            if let deja = parExtMac[x], rang(deja.source) <= rang(e.source) { continue }
            parExtMac[x] = e
```

Dans `MaillageCoeur/Maillage/Maillage.swift`, remplacer :

```swift
    }

    /// Enfant trouve (table, balayage, sonde) ; complete celui qui est deja connu.
    public mutating func enfant(_ e: EnfantMaillage) {
        guard var connu = enfants[e.rloc16] else {
```

par :

```swift
    }

    /// Enfant trouve (table, resolution, sonde) ; complete celui qui est deja connu.
    public mutating func enfant(_ e: EnfantMaillage) {
        guard var connu = enfants[e.rloc16] else {
```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
    /// Un enfant vu deux fois (meme ExtMac, precision 26 du plan 4b) ne donne qu'un noeud et un
    /// lien : ceux de l'entree que retient `Maillage.enfantsIdentifies` ; l'autre est ecartee. L'entree
    /// du balayage d'un enfant devenu routeur (l'ExtMac d'un routeur du maillage) n'en donne aucun.
    /// Chaque noeud garde l'ExtMac que la sonde lui connait (`extMacs`).
    public init(maillage: Maillage, reseau: Reseau, appareils: [Appareil]) {
```

par :

```swift
    /// Un enfant vu deux fois (meme ExtMac, precision 26 du plan 4b) ne donne qu'un noeud et un
    /// lien : ceux de l'entree que retient `Maillage.enfantsIdentifies` ; l'autre est ecartee. L'entree
    /// de la resolution d'un enfant devenu routeur (l'ExtMac d'un routeur du maillage) n'en donne aucun.
    /// Chaque noeud garde l'ExtMac que la sonde lui connait (`extMacs`).
    public init(maillage: Maillage, reseau: Reseau, appareils: [Appareil]) {
```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
        }

        // Un enfant vu deux fois (il a change de parent, et l'ancienne entree du balayage d'un routeur
        // muet peut rester 30 minutes) n'est qu'un noeud : l'entree que retient
        // `Maillage.enfantsIdentifies` (la sonde, puis une table, puis le balayage) ; l'autre est
        // ecartee, sans noeud ni lien. De meme pour l'entree du balayage d'un enfant devenu routeur,
        // qu'elle ne retient pas.
        let retenus = maillage.enfantsIdentifies
        var enfants: [UInt16: NoeudSonde] = [:]
```

par :

```swift
        }

        // Un enfant vu deux fois (il a change de parent, et l'ancienne entree de la resolution sous un
        // routeur muet peut rester 30 minutes) n'est qu'un noeud : l'entree que retient
        // `Maillage.enfantsIdentifies` (la sonde, puis une table, puis la resolution) ; l'autre est
        // ecartee, sans noeud ni lien. De meme pour l'entree de la resolution d'un enfant devenu
        // routeur, qu'elle ne retient pas.
        let retenus = maillage.enfantsIdentifies
        var enfants: [UInt16: NoeudSonde] = [:]
```

Dans `MaillageCoeur/Maillage/SuiviMaillage.swift`, remplacer :

```swift
///   parent ». Elle l'est si son dernier parent a repondu (sa table des enfants est fraiche) ou
///   s'il a quitte la liste des routeurs : une absence par tournee. Elle l'est aussi si l'enfant
///   venait d'un balayage et que son parent est toujours muet (un routeur muet garde ses enfants
///   balayes jusqu'au balayage suivant) : le balayage est reutilise par toutes les tournees
///   jusqu'au suivant, donc l'absence doit etre vue par deux balayages distincts, et non par deux
///   tournees (choix de Djoko, 30/09 : un balayage qui rate un appareil endormi trop lent ne suffit
///   pas ; l'alerte vient apres 30 a 60 min). Sous un parent qui s'est tu sans etre balaye, on ne
///   sait pas. La sonde n'est jamais « sans parent » (detachee, elle ne rend pas de maillage),
///   ni un enfant devenu routeur ;
/// - un routeur hors routeurs de bordure qui entre dans la liste des routeurs, ou en sort.
/// Le premier maillage, et le premier d'une autre partition (les identifiants de routeur y sont
```

par :

```swift
///   parent ». Elle l'est si son dernier parent a repondu (sa table des enfants est fraiche) ou
///   s'il a quitte la liste des routeurs : une absence par tournee. Elle l'est aussi si l'enfant
///   venait d'une resolution et que son parent est toujours muet (un routeur muet garde ses enfants
///   resolus jusqu'a la resolution suivante) : la resolution est reutilisee par toutes les tournees
///   jusqu'a la suivante, donc l'absence doit etre vue par deux resolutions distinctes, et non par
///   deux tournees (choix de Djoko, 30/09, pour le balayage qu'elle remplace : une resolution qui
///   rate un appareil ne suffit pas ; l'alerte vient apres 30 a 60 min). Sous un parent qui s'est tu
///   sans resolution, on ne sait pas. La sonde n'est jamais « sans parent » (detachee, elle ne rend
///   pas de maillage), ni un enfant devenu routeur ;
/// - un routeur hors routeurs de bordure qui entre dans la liste des routeurs, ou en sort.
/// Le premier maillage, et le premier d'une autre partition (les identifiants de routeur y sont
```

Dans `MaillageCoeur/Maillage/SuiviMaillage.swift`, remplacer :

```swift
        var absences = 0
        var perdu = false
        /// Date du balayage de la derniere absence comptee sous un parent muet.
        var balayageCompte: Date?
    }

```

par :

```swift
        var absences = 0
        var perdu = false
        /// Date de la resolution de la derniere absence comptee sous un parent muet.
        var resolutionComptee: Date?
    }

```

Dans `MaillageCoeur/Maillage/SuiviMaillage.swift`, remplacer :

```swift
            }
            let parent = parId[e.parent]
            guard e.source != .sonde, parent == nil || parent?.muet == false || e.source == .balayage else { continue }
            if parent?.muet == true {
                // Parent toujours dans la liste et muet : l'absence ne vient que du balayage, reutilise
                // par chaque tournee jusqu'au suivant ; elle ne compte qu'une fois par balayage.
                guard let balayage = m.balayage, balayage != e.balayageCompte else { continue }
                e.balayageCompte = balayage
            }
            e.absences += 1
```

par :

```swift
            }
            let parent = parId[e.parent]
            guard e.source != .sonde, parent == nil || parent?.muet == false || e.source == .resolution else { continue }
            if parent?.muet == true {
                // Parent toujours dans la liste et muet : l'absence ne vient que de la resolution, reutilisee
                // par chaque tournee jusqu'a la suivante ; elle ne compte qu'une fois par resolution.
                guard let resolution = m.resolution, resolution != e.resolutionComptee else { continue }
                e.resolutionComptee = resolution
            }
            e.absences += 1
```

Dans `MaillageCoeur/Demo/MaillageDemo.swift`, remplacer :

```swift
            c.lien(a, ids[1 + k % (bordures.count - 1)], sortante: 2, entrante: 1)
        }
        // Enfants, a tour de role ; sous le routeur muet, sans qualite.
        for (k, a) in enfants.enumerated() {
            let parent = ids[k % ids.count]
            c.enfant(EnfantMaillage(rloc16: UInt16(parent) << 10 | UInt16(1 + k / ids.count), extMac: a.id,
                                    qualite: parent == muet ? nil : qualites[k % 4], endormi: a.endormi,
                                    source: parent == muet ? .balayage : .tableEnfants))
        }
        c.enfant(EnfantMaillage(rloc16: UInt16(chef) << 10 | 0x1F, extMac: "E0000000000000FF", qualite: 1, endormi: true,
```

par :

```swift
            c.lien(a, ids[1 + k % (bordures.count - 1)], sortante: 2, entrante: 1)
        }
        // Enfants, a tour de role ; sous le routeur muet, resolus, sans qualite.
        for (k, a) in enfants.enumerated() {
            let parent = ids[k % ids.count]
            c.enfant(EnfantMaillage(rloc16: UInt16(parent) << 10 | UInt16(1 + k / ids.count), extMac: a.id,
                                    qualite: parent == muet ? nil : qualites[k % 4], endormi: a.endormi,
                                    source: parent == muet ? .resolution : .tableEnfants))
        }
        c.enfant(EnfantMaillage(rloc16: UInt16(chef) << 10 | 0x1F, extMac: "E0000000000000FF", qualite: 1, endormi: true,
```

`MaillageThread/Sonde/TexteTournee.swift`, fichier entier :

```swift
import Foundation
import MaillageCoeur

/// Textes de l'avancement d'une tournee : barre du graphe, Reglages › Sonde, menu.
enum TexteTournee {
    /// Libelle court d'une etape.
    static func etape(_ e: AvancementTournee.Etape) -> String {
        switch e {
        case .etatSonde: String(localized: "État de la sonde")
        case .listeRouteurs: String(localized: "Liste des routeurs")
        case .routeurs: String(localized: "Routeurs")
        case .pileEtReseau: String(localized: "Pile et Network Data")
        case .resolution: String(localized: "Résolution des parents")
        case .compteurs: String(localized: "Compteurs des enfants")
        case .identites: String(localized: "Identité des enfants")
        }
    }

    /// « Resolution des parents · 12/26 » ; l'etape seule quand elle n'a rien a faire.
    static func avancement(_ a: AvancementTournee) -> String {
        guard a.total > 0 else { return etape(a.etape) }
        return String(localized: "\(etape(a.etape)) · \(a.fait)/\(a.total)")
    }

    /// Duree ecoulee : « 0:42 », « 1:02:03 » au-dela d'une heure.
    static func chrono(_ secondes: TimeInterval) -> String {
        let s = max(0, Int(secondes))
        if s >= 3600 { return String(format: "%ld:%02ld:%02ld", s / 3600, s / 60 % 60, s % 60) }
        return String(format: "%ld:%02ld", s / 60, s % 60)
    }

    /// Duree ecoulee en unites : « 42 s », « 1 min 30 s ».
    static func duree(_ secondes: TimeInterval) -> String {
        Duration.seconds(max(0, Int(secondes)))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }

    /// Barre du graphe : « Resolution des parents · 12/26 · 0:42 ».
    static func barre(_ a: AvancementTournee, debut: Date, maintenant: Date) -> String {
        String(localized: "\(avancement(a)) · \(chrono(maintenant.timeIntervalSince(debut)))")
    }

    /// Texte le plus large de la barre pour une etape (compteur a trois chiffres, duree de
    /// 99:59), invisible : il donne sa largeur fixe a la capsule de la tournee.
    static func gabaritBarre(_ e: AvancementTournee.Etape) -> String {
        String(localized: "\(avancement(AvancementTournee(etape: e, fait: 888, total: 888))) · \(chrono(99 * 60 + 59))")
    }

    /// Reglages › Sonde : « Resolution des parents · 12/26 · depuis 42 s ».
    static func reglages(_ a: AvancementTournee, debut: Date, maintenant: Date) -> String {
        String(localized: "\(avancement(a)) · depuis \(duree(maintenant.timeIntervalSince(debut)))")
    }

    /// Menu : « SONDE-01 : Resolution des parents 12/26… ».
    static func menu(_ a: AvancementTournee, nom: String) -> String {
        guard a.total > 0 else { return String(localized: "\(nom) : \(etape(a.etape))…") }
        return String(localized: "\(nom) : \(etape(a.etape)) \(a.fait)/\(a.total)…")
    }
}
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
    /// Noeuds d'un maillage pour le journal : leur id dans le graphe et leur nom affiche,
    /// d'apres le rapprochement avec le reseau de sa partition (a defaut, le reseau affiche). Un
    /// enfant identifie est d'abord l'appareil de meme ExtMac : vu deux fois (balayage ancien,
    /// table), il n'a son id d'appareil qu'une fois dans le graphe.
    func sujets(_ m: Maillage) -> SujetsMaillage {
```

par :

```swift
    /// Noeuds d'un maillage pour le journal : leur id dans le graphe et leur nom affiche,
    /// d'apres le rapprochement avec le reseau de sa partition (a defaut, le reseau affiche). Un
    /// enfant identifie est d'abord l'appareil de meme ExtMac : vu deux fois (resolution ancienne,
    /// table), il n'a son id d'appareil qu'une fois dans le graphe.
    func sujets(_ m: Maillage) -> SujetsMaillage {
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
}

/// Tournee de la sonde en cours : un petit indicateur de progression et « Balayage des
/// routeurs muets · 24/48 · 0:42 », la duree a jour chaque seconde. Sans debut : la place de la
/// ligne, sans horloge.
struct IndicateurTournee: View {
```

par :

```swift
}

/// Tournee de la sonde en cours : un petit indicateur de progression et « Resolution des
/// parents · 12/26 · 0:42 », la duree a jour chaque seconde. Sans debut : la place de la
/// ligne, sans horloge.
struct IndicateurTournee: View {
```

- [ ] **Step 4 : les voir passer.** La commande du step 2 (sans `CataloguesTests`, que le step 6 passe après les textes).

Expected : `Test run with 126 tests in 7 suites passed` (cœur) et `Test run with 84 tests in 5 suites passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes,** par les outils : synchroniser le catalogue avec ceux qu'a extraits la compilation du step 4, retirer de `interface.json` l'étape qui n'existe plus, puis traduire.

```bash
W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" outils/synchroniser-textes.sh && /usr/bin/python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
del d["Balayage des routeurs muets"]
d.update({
    "Compteurs des enfants": "Child counters",
    "Résolution des parents": "Parent resolution",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
/usr/bin/python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json && git diff --stat -- MaillageThread/Ressources outils/traductions
```

Expected : `MaillageThread/Ressources/Localizable.xcstrings | 48` et `outils/traductions/interface.json | 3` (`2 files changed, 34 insertions(+), 17 deletions(-)`) : deux clés nouvelles, une retirée.

- [ ] **Step 6 : toute la suite.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh`

Expected : `Test run with 436 tests in 43 suites passed` (cœur) et `Test run with 414 tests in 35 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; `CataloguesTests` vérifie le catalogue.

- [ ] **Step 7 : commit.**

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add MaillageCoeur/Demo/MaillageDemo.swift MaillageCoeur/Maillage/Maillage.swift MaillageCoeur/Maillage/Rapprochement.swift MaillageCoeur/Maillage/Resolution.swift MaillageCoeur/Maillage/SuiviMaillage.swift MaillageCoeur/Maillage/Tournee.swift MaillageCoeurTests/GrapheReseauTests.swift MaillageCoeurTests/HistoriqueTests.swift MaillageCoeurTests/MaillageDemoTests.swift MaillageCoeurTests/MaillageTests.swift MaillageCoeurTests/RapprochementTests.swift MaillageCoeurTests/SuiviMaillageTests.swift MaillageCoeurTests/TourneeTests.swift MaillageThread/Ressources/Localizable.xcstrings MaillageThread/Sonde/TexteTournee.swift MaillageThread/Surveillance/Surveillance.swift MaillageThread/Vues/Pieces/MorceauxFenetre.swift MaillageThreadTests/AffichageSondeTests.swift MaillageThreadTests/FenetreTests.swift MaillageThreadTests/JournalMaillageTests.swift MaillageThreadTests/SondeTests.swift outils/traductions/interface.json && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --cached --name-only | sed "s|^|$PWD/|") && git commit -q -F - <<'EOF'
Ecouter les annonces et resoudre les parents dans la tournee, a la place du balayage : liens fusionnes, compteurs MAC des enfants

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` ; `0`.

---

### Task 8: L'historique garde la source des liens et la qualité calculée des enfants ; l'origine de chaque lien affiché

**Files :**
- Modify : `MaillageCoeur/Maillage/HistoriqueMaillage.swift` (en entier), `MaillageCoeur/Maillage/Rapprochement.swift`, `MaillageCoeurTests/HistoriqueTests.swift`, `MaillageCoeurTests/RapprochementTests.swift` (blocs)

**Interfaces:**
- Consumes : `LienRadio` et ses sources, `EnfantMaillage.resolu` et `echecs` (tâche 5), `Maillage.annoncesLues` et `RouteurMaillage.entendu`.
- Produces :
  - `ReleveMaillage.Enfant.source` (`SourceEnfant?`) et `echecs` (`Double?`, arrondi au dix-millième) ; un lien s'écrit `[a,b,qAB,qBA,sAB,sBA]` quand il a une source (`d` diagnostic, `e` écoute), un enfant `[ext,parent,q,source(,echecs)]` (`t` table, `r` résolution, `s` sonde) ; sans les dates des mesures ; une ligne d'avant, ou un code inconnu, se lit sans source (spec, section 2.5) ;
  - `OrigineLien` (`diagnostic`, `entendu`, `resolu`, `echecs`, `sonde`), `init?(_ lien: LienRadio)` (`nil` sans source) et `init(_ enfant: EnfantMaillage)` ; `LienAffiche.origine` ;
  - `MaillageAffiche.routeursMuets`, `entendus` (`[Int: Date]`), `annoncesLues`, et `jamaisEntendu(_ id:) -> Bool`.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`).

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift

    /// Une ligne par tournee, en tableaux : routeurs, liens, enfants identifies (pas celui sans
    /// ExtMac), signaux, parent de la sonde. Relue a l'identique.
    @Test func ligneDUnReleve() throws {
        let r = ReleveMaillage(Self.maillage(Self.date("2026-09-30T10:00:00Z")))
        let json = String(decoding: try CodageJSON.encodeur().encode(r), as: UTF8.self)
        #expect(json == #"{"date":"2026-09-30T10:00:00.000Z","enfants":[["E0000000000000B1",0,3],["E0000000000000B2",1,null]],"liens":[[0,1,3,2]],"parentSonde":0,"partition":"0000000A","routeurs":[[0,"E0000000000000A0"],[1,null]],"signaux":[[0,-60],[1,-75]]}"#)
        #expect(try CodageJSON.decodeur().decode(ReleveMaillage.self, from: Data(json.utf8)) == r)
        #expect(r.cle(routeur: 0) == "E0000000000000A0")
```

par :

```swift

    /// Une ligne par tournee, en tableaux : routeurs, liens, enfants identifies (pas celui sans
    /// ExtMac) avec leur source, signaux, parent de la sonde. Relue a l'identique.
    @Test func ligneDUnReleve() throws {
        let r = ReleveMaillage(Self.maillage(Self.date("2026-09-30T10:00:00Z")))
        let json = String(decoding: try CodageJSON.encodeur().encode(r), as: UTF8.self)
        #expect(json == #"{"date":"2026-09-30T10:00:00.000Z","enfants":[["E0000000000000B1",0,3,"s"],["E0000000000000B2",1,null,"r"]],"liens":[[0,1,3,2]],"parentSonde":0,"partition":"0000000A","routeurs":[[0,"E0000000000000A0"],[1,null]],"signaux":[[0,-60],[1,-75]]}"#)
        #expect(try CodageJSON.decodeur().decode(ReleveMaillage.self, from: Data(json.utf8)) == r)
        #expect(r.cle(routeur: 0) == "E0000000000000A0")
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift
    }

    /// Tournee de la capture, avec des voisins : 7 routeurs et 3 enfants identifies tiennent en
    /// moins de 700 octets ; avec 20 enfants (26 octets chacun), en moins de 1 Ko.
    @Test func tailleDUneLigne() async throws {
        let voisins = [VoisinSonde(rloc16: "E400", ext: "E0000000000000E4", rssi: -72, lqi: 3, routeur: true),
```

par :

```swift
    }

    /// Tournee de la capture, avec des voisins : 7 routeurs, leurs liens avec leurs sources et 3 enfants
    /// identifies tiennent en moins de 700 octets ; avec 20 enfants (30 octets chacun), en moins de 1 Ko.
    @Test func tailleDUneLigne() async throws {
        let voisins = [VoisinSonde(rloc16: "E400", ext: "E0000000000000E4", rssi: -72, lqi: 3, routeur: true),
```

Dans `MaillageCoeurTests/HistoriqueTests.swift`, remplacer :

```swift
        #expect(octets < 700, "\(octets) octets")
        var vingt = r.enfants
        for n in 0..<17 { vingt.append(ReleveMaillage.Enfant(extMac: String(format: "E0000000000001%02X", n), parent: 24, qualite: 3)) }
        let grand = ReleveMaillage(date: r.date, partition: r.partition, routeurs: r.routeurs, liens: r.liens, enfants: vingt,
                                   signaux: r.signaux, parentSonde: r.parentSonde)
        #expect(try CodageJSON.encodeur().encode(grand).count < 1024)
    }

```

par :

```swift
        #expect(octets < 700, "\(octets) octets")
        var vingt = r.enfants
        for n in 0..<17 {
            vingt.append(ReleveMaillage.Enfant(extMac: String(format: "E0000000000001%02X", n), parent: 24, qualite: 3,
                                               source: .tableEnfants))
        }
        let grand = ReleveMaillage(date: r.date, partition: r.partition, routeurs: r.routeurs, liens: r.liens, enfants: vingt,
                                   signaux: r.signaux, parentSonde: r.parentSonde)
        #expect(try CodageJSON.encodeur().encode(grand).count < 1024)
    }

    /// Champs facultatifs de la sonde tout-en-un (spec, section 2.5) : la source de chaque sens d'un lien
    /// (`d` diagnostic, `e` ecoute), la source d'un enfant (`t` table, `r` resolution, `s` sonde) et le taux
    /// d'echec que donnent ses compteurs MAC, arrondi a 1/10 000. Pas les dates des mesures. Relue a l'identique.
    @Test func champsFacultatifs() throws {
        let t0 = Self.date("2026-10-07T10:00:00Z")
        var c = ConstructionMaillage(date: t0, partition: "0000000A")
        c.routeurs(Route64(sequence: 1, routes: [0, 1, 2].map {
            RouteRouteur(idRouteur: $0, qualiteSortante: 0, qualiteEntrante: 0, cout: 1)
        }), chef: 0)
        c.lien(0, 1, sortante: 3, entrante: 2, source: .diagnostic, date: t0)
        c.ecoute(Route64(sequence: 1, routes: [RouteRouteur(idRouteur: 1, qualiteSortante: 1, qualiteEntrante: 2, cout: 1)]),
                 routeur: 2, date: t0 - 120)
        c.enfant(EnfantMaillage(rloc16: 0x0A00, extMac: "E0000000000000C1", qualite: 3, source: .resolution, resolu: t0,
                                echecs: 0.0071428))
        c.enfant(EnfantMaillage(rloc16: 0x0A01, extMac: "E0000000000000C2", source: .resolution, resolu: t0))
        let r = ReleveMaillage(c.maillage())
        let json = String(decoding: try CodageJSON.encodeur().encode(r), as: UTF8.self)
        #expect(json == #"{"date":"2026-10-07T10:00:00.000Z","enfants":[["E0000000000000C1",2,3,"r",0.0071],["E0000000000000C2",2,null,"r"]],"liens":[[0,1,3,2,"d","d"],[1,2,2,1,"e","e"]],"partition":"0000000A","routeurs":[[0,null],[1,null],[2,null]],"signaux":[]}"#)
        #expect(try CodageJSON.decodeur().decode(ReleveMaillage.self, from: Data(json.utf8)) == r)
        #expect(r.liens.allSatisfy { $0.dateAB == nil && $0.dateBA == nil })
        #expect(r.enfants.first?.echecs == 0.0071 && r.enfants.first?.source == .resolution)
    }

    /// Lecture de l'ancien historique (avant la sonde tout-en-un) : les lignes sans les champs facultatifs se lisent
    /// comme avant, sources et taux inconnus ; une source inconnue (version plus recente) aussi.
    @Test func ancienHistorique() throws {
        let ancienne = #"{"date":"2026-09-30T10:00:00.000Z","enfants":[["E0000000000000B1",0,3],["E0000000000000B2",1,null]],"liens":[[0,1,3,2]],"parentSonde":0,"partition":"0000000A","routeurs":[[0,"E0000000000000A0"],[1,null]],"signaux":[[0,-60],[1,-75]]}"#
        let r = try CodageJSON.decodeur().decode(ReleveMaillage.self, from: Data(ancienne.utf8))
        #expect(r.liens == [LienRadio(a: 0, b: 1, qualiteAB: 3, qualiteBA: 2)])
        #expect(r.enfants.map(\.source) == [nil, nil] && r.enfants.map(\.echecs) == [nil, nil])
        #expect(r.enfants.map(\.qualite) == [3, nil] && r.parentSonde == 0)
        let future = #"{"date":"2026-09-30T10:00:00.000Z","enfants":[["E0000000000000B1",0,3,"x",0.5]],"liens":[[0,1,3,2,"z",null]],"partition":"0000000A","routeurs":[],"signaux":[]}"#
        let f = try CodageJSON.decodeur().decode(ReleveMaillage.self, from: Data(future.utf8))
        #expect(f.liens.first?.sourceAB == nil && f.enfants.first?.source == nil && f.enfants.first?.echecs == 0.5)
    }

```

Dans `MaillageCoeurTests/RapprochementTests.swift`, remplacer :

```swift
        #expect(m.inconnus.filter { $0.genre == .routeur }.map(\.id) == ["rloc:0400", "rloc:CC00", "rloc:E400"])
        #expect(m.inconnus.count == 7, "3 routeurs ; 6002, 6005 et 6006, sans identite ; la sonde")
        #expect(m.liens.contains(LienAffiche(de: "E000000000000002", vers: "E000000000000003", genre: .radio, qualite: 3)))
        #expect(m.liens.contains(LienAffiche(de: "E000000000000004", vers: "E000000000000002", genre: .parent, qualite: 2)))
        #expect(m.liens.contains(LienAffiche(de: "E00000000000000A", vers: "HomePod bureau", genre: .parent, qualite: nil)))
        #expect(m.parent(de: "E000000000000005") == "E000000000000002")
        #expect(m.noeud("Apple TV")?.rloc16 == 0xB400)
    }

```

par :

```swift
        #expect(m.inconnus.filter { $0.genre == .routeur }.map(\.id) == ["rloc:0400", "rloc:CC00", "rloc:E400"])
        #expect(m.inconnus.count == 7, "3 routeurs ; 6002, 6005 et 6006, sans identite ; la sonde")
        let diagnostic = OrigineLien(diagnostic: true)
        #expect(m.liens.contains(LienAffiche(de: "E000000000000002", vers: "E000000000000003", genre: .radio, qualite: 3,
                                             origine: diagnostic)))
        #expect(m.liens.contains(LienAffiche(de: "E000000000000004", vers: "E000000000000002", genre: .parent, qualite: 2,
                                             origine: diagnostic)))
        let resolu = try #require(m.liens.first { $0.de == "E00000000000000A" })
        #expect(resolu.vers == "HomePod bureau" && resolu.genre == .parent && resolu.qualite == nil)
        #expect(resolu.origine?.resolu != nil && resolu.origine?.diagnostic == false, "resolu sous un routeur Apple")
        #expect(m.parent(de: "E000000000000005") == "E000000000000002")
        #expect(m.noeud("Apple TV")?.rloc16 == 0xB400)
    }

    /// Origine de chaque lien, pour la fiche (spec de la sonde tout-en-un, section 2.4) : la source et l'age. Un lien
    /// radio entendu puis mesure par le diagnostic, plus recent, n'a plus que lui ; un lien sans source (maillage de
    /// demo) n'en a pas. Un enfant : la table de son parent, la resolution et le taux de ses compteurs,
    /// ou la sonde. Les routeurs muets, entendus ou non, et si la sonde a rendu ses annonces.
    @Test func origineDesLiens() throws {
        let i = Self.instantane()
        let r = try #require(i.reseaux.first)
        let t0 = Date(timeIntervalSince1970: 1_790_000_000)
        var c = ConstructionMaillage(date: t0, partition: "46CBEBCD")
        c.routeurs(Route64(sequence: 1, routes: [1, 2, 3, 4].map {
            RouteRouteur(idRouteur: $0, qualiteSortante: 0, qualiteEntrante: 0, cout: 1)
        }), chef: 1)
        c.lien(1, 2, sortante: 3, entrante: 3, source: .diagnostic, date: t0)
        c.ecoute(Route64(sequence: 1, routes: [RouteRouteur(idRouteur: 3, qualiteSortante: 2, qualiteEntrante: 1, cout: 1)]),
                 routeur: 2, date: t0 - 180)
        c.lien(1, 3, sortante: 3, entrante: 3)
        c.ecoute(Route64(sequence: 1, routes: [RouteRouteur(idRouteur: 1, qualiteSortante: 2, qualiteEntrante: 0, cout: 1)]),
                 routeur: 4, date: t0 - 60)
        c.lien(1, 4, sortante: 3, entrante: 0, source: .diagnostic, date: t0)
        for id in [2, 3, 4] { c.muet(id) }
        c.annoncesRecues()
        c.enfant(EnfantMaillage(rloc16: 0x0401, extMac: "E000000000000004", qualite: 2, source: .tableEnfants))
        c.enfant(EnfantMaillage(rloc16: 0x0E00, extMac: "E000000000000005", qualite: 3, source: .resolution, resolu: t0,
                                echecs: 0.004))
        c.enfant(EnfantMaillage(rloc16: 0x0402, source: .sonde))
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        func lien(_ a: Int, _ b: Int) -> LienAffiche? {
            m.liens.first { $0.genre == .radio && Set([$0.de, $0.vers]) == Set([m.routeurs[a]?.id, m.routeurs[b]?.id]) }
        }
        #expect(lien(1, 2)?.origine == OrigineLien(diagnostic: true))
        #expect(lien(2, 3)?.origine == OrigineLien(entendu: t0 - 180), "entendu seulement")
        #expect(lien(1, 3)?.origine == nil, "sans source")
        #expect(lien(1, 4)?.origine == OrigineLien(diagnostic: true), "le diagnostic, plus recent, dans les deux sens")
        #expect(m.liens.first { $0.de == "E000000000000004" }?.origine == OrigineLien(diagnostic: true))
        #expect(m.liens.first { $0.de == "E000000000000005" }?.origine == OrigineLien(resolu: t0, echecs: 0.004))
        #expect(m.liens.first { $0.de == "rloc:0402" }?.origine == OrigineLien(sonde: true))
        #expect(m.routeursMuets == [2, 3, 4] && m.entendus == [2: t0 - 180, 4: t0 - 60] && m.annoncesLues)
        #expect(m.jamaisEntendu(try #require(m.routeurs[3]?.id)), "muet, jamais entendu")
        #expect(!m.jamaisEntendu(try #require(m.routeurs[2]?.id)), "entendu")
        #expect(!m.jamaisEntendu(try #require(m.routeurs[1]?.id)), "repond au diagnostic")
        var sans = ConstructionMaillage(date: t0, partition: "46CBEBCD")
        sans.routeurs(Route64(sequence: 1, routes: [RouteRouteur(idRouteur: 3, qualiteSortante: 0, qualiteEntrante: 0, cout: 1)]),
                      chef: 3)
        sans.muet(3)
        let ancien = MaillageAffiche(maillage: sans.maillage(), reseau: r, appareils: i.appareils)
        #expect(!ancien.jamaisEntendu(try #require(ancien.routeurs[3]?.id)), "sans annonces (1.0.3), on ne sait pas")
    }

```

- [ ] **Step 2 : les voir échouer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh MaillageCoeurTests/HistoriqueTests MaillageCoeurTests/RapprochementTests`

Expected : la compilation des tests échoue : `value of type 'LienAffiche' has no member 'origine'`, `cannot find 'OrigineLien' in scope`, `value of type 'MaillageAffiche' has no member 'jamaisEntendu'`, `value of type 'ReleveMaillage.Enfant' has no member 'source'`, `… has no member 'echecs'`.

- [ ] **Step 3 : les champs facultatifs et l'origine des liens** (`--etapes 3`).

`MaillageCoeur/Maillage/HistoriqueMaillage.swift`, fichier entier :

```swift
import Foundation

/// Releve d'une tournee pour l'historique (spec de la sonde, section 6) : la qualite de chaque
/// lien, entre routeurs et d'enfant a parent, et le signal des routeurs que la sonde entend.
/// Une ligne JSON de `maillage-AAAA-MM.jsonl`, en tableaux pour rester courte :
/// - `routeurs` : `[identifiant, ExtMac ou null]`, chaque routeur de la liste ;
/// - `liens` : `[a, b, qualite de a vers b, qualite de b vers a]` (null : inconnue), puis, depuis la
///   sonde tout-en-un (spec, section 2.5), la source de chaque sens : `d` diagnostic, `e` ecoute (null :
///   inconnue) ; un lien sans source n'en a pas ;
/// - `enfants` : `[ExtMac, identifiant du parent, qualite ou null]`, les enfants identifies, la
///   sonde comprise, puis leur source (`t` table de son parent, `r` resolution, `s` la sonde) et, quand
///   leur qualite vient de leurs compteurs MAC, le taux d'echec (au 1/10 000). Un enfant sans ExtMac n'a
///   pas d'identite stable (son RLOC16 change avec son parent) : il n'est pas garde ;
/// - `signaux` : `[identifiant, dBm]`, les routeurs que la sonde entend, son parent compris ;
/// - `parentSonde` : identifiant du parent de la sonde (absent sans parent connu).
/// Les champs facultatifs manquent aux lignes d'avant : elles se lisent comme avant, sources et taux
/// inconnus ; une source inconnue (version plus recente) aussi.
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

    /// Enfant identifie, son parent et la qualite de son lien (nil sous un routeur muet), sa source et le
    /// taux d'echec de ses compteurs MAC quand sa qualite en vient (nil : ligne d'avant, ou inconnus).
    public struct Enfant: Hashable, Sendable {
        public let extMac: String
        public let parent: Int
        public let qualite: Int?
        public let source: SourceEnfant?
        public let echecs: Double?

        public init(extMac: String, parent: Int, qualite: Int?, source: SourceEnfant? = nil, echecs: Double? = nil) {
            self.extMac = extMac
            self.parent = parent
            self.qualite = qualite
            self.source = source
            self.echecs = echecs
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

    /// Releve d'un maillage : ses enfants identifies (`Maillage.enfantsIdentifies`), avec leur source et leur taux
    /// d'echec arrondi au 1/10 000 ; ses liens sans les dates de leurs mesures.
    public init(_ m: Maillage) {
        self.init(date: m.date, partition: m.partition,
                  routeurs: m.routeurs.map { Routeur(id: $0.id, extMac: $0.extMac) },
                  liens: m.liens.map(\.sansDates),
                  enfants: m.enfantsIdentifies.sorted { $0.key < $1.key }
                      .map { Enfant(extMac: $0.key, parent: $0.value.parent, qualite: $0.value.qualite, source: $0.value.source,
                                    echecs: $0.value.echecs.map { ($0 * 10_000).rounded() / 10_000 }) },
                  signaux: m.signaux, parentSonde: m.parentSonde)
    }

    /// Identifiants de routeur possibles : 0 a 62 (un RLOC16 porte 6 bits de routeur ; 63 n'est pas
    /// attribue).
    static let identifiantsRouteur = 0...62

    /// Cle d'un routeur du releve : son ExtMac, sinon "rloc:XXXX" (valable dans sa partition) ;
    /// "rloc:?" pour un identifiant hors plage (fonction totale : jamais d'arret du programme).
    public func cle(routeur id: Int) -> String {
        guard Self.identifiantsRouteur.contains(id) else { return "rloc:?" }
        return routeurs.first { $0.id == id }?.extMac ?? String(format: "rloc:%04X", UInt16(id) << 10)
    }
}

extension ReleveMaillage: Codable {
    private enum CodingKeys: String, CodingKey {
        case date, partition, routeurs, liens, enfants, signaux, parentSonde
    }

    /// Codes courts des sources dans l'historique.
    private static let codesLiens: [SourceLien: String] = [.diagnostic: "d", .ecoute: "e"]
    private static let codesEnfants: [SourceEnfant: String] = [.tableEnfants: "t", .resolution: "r", .sonde: "s"]

    private static func sourceLien(_ code: String?) -> SourceLien? {
        code.flatMap { c in codesLiens.first { $0.value == c }?.key }
    }

    private static func sourceEnfant(_ code: String?) -> SourceEnfant? {
        code.flatMap { c in codesEnfants.first { $0.value == c }?.key }
    }

    /// Decode un identifiant de routeur ; hors de 0...62, la ligne entiere est refusee.
    private static func identifiant(_ l: inout any UnkeyedDecodingContainer) throws -> Int {
        let id = try l.decode(Int.self)
        guard identifiantsRouteur.contains(id) else {
            throw DecodingError.dataCorruptedError(in: l, debugDescription: "identifiant de routeur hors de 0...62 : \(id)")
        }
        return id
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var routeurs: [Routeur] = []
        var r = try c.nestedUnkeyedContainer(forKey: .routeurs)
        while !r.isAtEnd {
            var l = try r.nestedUnkeyedContainer()
            routeurs.append(Routeur(id: try Self.identifiant(&l), extMac: try l.decodeIfPresent(String.self)))
        }
        var liens: [LienRadio] = []
        var li = try c.nestedUnkeyedContainer(forKey: .liens)
        while !li.isAtEnd {
            var l = try li.nestedUnkeyedContainer()
            liens.append(LienRadio(a: try Self.identifiant(&l), b: try Self.identifiant(&l),
                                   qualiteAB: try l.decodeIfPresent(Int.self), qualiteBA: try l.decodeIfPresent(Int.self),
                                   sourceAB: Self.sourceLien(try l.decodeIfPresent(String.self)),
                                   sourceBA: Self.sourceLien(try l.decodeIfPresent(String.self))))
        }
        var enfants: [Enfant] = []
        var e = try c.nestedUnkeyedContainer(forKey: .enfants)
        while !e.isAtEnd {
            var l = try e.nestedUnkeyedContainer()
            enfants.append(Enfant(extMac: try l.decode(String.self), parent: try Self.identifiant(&l),
                                  qualite: try l.decodeIfPresent(Int.self),
                                  source: Self.sourceEnfant(try l.decodeIfPresent(String.self)),
                                  echecs: try l.decodeIfPresent(Double.self)))
        }
        var signaux: [SignalSonde] = []
        var s = try c.nestedUnkeyedContainer(forKey: .signaux)
        while !s.isAtEnd {
            var l = try s.nestedUnkeyedContainer()
            signaux.append(SignalSonde(routeur: try Self.identifiant(&l), rssi: try l.decode(Int.self)))
        }
        let parentSonde = try c.decodeIfPresent(Int.self, forKey: .parentSonde)
        if let p = parentSonde, !Self.identifiantsRouteur.contains(p) {
            throw DecodingError.dataCorruptedError(forKey: .parentSonde, in: c,
                                                   debugDescription: "identifiant de routeur hors de 0...62 : \(p)")
        }
        self.init(date: try c.decode(Date.self, forKey: .date), partition: try c.decode(String.self, forKey: .partition),
                  routeurs: routeurs, liens: liens, enfants: enfants, signaux: signaux, parentSonde: parentSonde)
    }

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
            if x.sourceAB != nil || x.sourceBA != nil {
                try l.encodeOuNul(x.sourceAB.flatMap { Self.codesLiens[$0] })
                try l.encodeOuNul(x.sourceBA.flatMap { Self.codesLiens[$0] })
            }
        }
        var e = c.nestedUnkeyedContainer(forKey: .enfants)
        for x in enfants where ids.contains(x.parent) {
            var l = e.nestedUnkeyedContainer()
            try l.encode(x.extMac)
            try l.encode(x.parent)
            try l.encodeOuNul(x.qualite)
            if x.source != nil || x.echecs != nil {
                try l.encodeOuNul(x.source.flatMap { Self.codesEnfants[$0] })
                if let echecs = x.echecs { try l.encode(echecs) }
            }
        }
        var s = c.nestedUnkeyedContainer(forKey: .signaux)
        for x in signaux where ids.contains(x.routeur) {
            var l = s.nestedUnkeyedContainer()
            try l.encode(x.routeur)
            try l.encode(x.rssi)
        }
        try c.encodeIfPresent(parentSonde.flatMap { ids.contains($0) ? $0 : nil }, forKey: .parentSonde)
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

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
}

/// Lien de la sonde entre deux noeuds du graphe.
public struct LienAffiche: Hashable, Sendable {
```

par :

```swift
}

/// D'ou viennent les mesures d'un lien de la sonde, pour la fiche (spec de la sonde tout-en-un, section 2.4) : un lien
/// est dessine pareil quelle que soit sa source ; la fiche dit la source et l'age.
public struct OrigineLien: Hashable, Sendable {
    /// Le diagnostic : la Route64 d'un routeur qui repond, ou la table des enfants de son parent.
    public var diagnostic: Bool
    /// Une annonce entendue par la sonde : la date de la plus recente des mesures qui en viennent.
    public var entendu: Date?
    /// Le parent trouve par la resolution d'adresse, a cette date.
    public var resolu: Date?
    /// Le taux d'echec d'envoi de l'enfant, tire de ses compteurs MAC.
    public var echecs: Double?
    /// Le parent de la sonde, qu'elle donne elle-meme (`etat`).
    public var sonde: Bool

    public init(diagnostic: Bool = false, entendu: Date? = nil, resolu: Date? = nil, echecs: Double? = nil,
                sonde: Bool = false) {
        self.diagnostic = diagnostic
        self.entendu = entendu
        self.resolu = resolu
        self.echecs = echecs
        self.sonde = sonde
    }

    /// D'un lien entre routeurs, ses deux sens reunis ; nil si aucun n'a de source (maillage de demo).
    init?(_ l: LienRadio) {
        let sens = [(l.sourceAB, l.dateAB), (l.sourceBA, l.dateBA)]
        guard sens.contains(where: { $0.0 != nil }) else { return nil }
        self.init(diagnostic: sens.contains { $0.0 == .diagnostic },
                  entendu: sens.filter { $0.0 == .ecoute }.compactMap(\.1).max())
    }

    /// Du lien d'un enfant vers son parent.
    init(_ e: EnfantMaillage) {
        switch e.source {
        case .tableEnfants: self.init(diagnostic: true)
        case .resolution: self.init(resolu: e.resolu, echecs: e.echecs)
        case .sonde: self.init(sonde: true)
        }
    }
}

/// Lien de la sonde entre deux noeuds du graphe.
public struct LienAffiche: Hashable, Sendable {
```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
    /// De 0 a 3 ; nil : inconnue (parent muet).
    public let qualite: Int?
}

```

par :

```swift
    /// De 0 a 3 ; nil : inconnue (parent muet).
    public let qualite: Int?
    /// D'ou viennent ses mesures ; nil : inconnu (maillage de demo).
    public var origine: OrigineLien?
}

```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
    /// place pas (precision 27, spec de la vue par pieces, section 2.3).
    public let extMacs: [String: String]

    /// Rapproche le maillage des routeurs de bordure de sa partition et des appareils :
```

par :

```swift
    /// place pas (precision 27, spec de la vue par pieces, section 2.3).
    public let extMacs: [String: String]
    /// Routeurs sans reponse au diagnostic a cette tournee, par identifiant.
    public let routeursMuets: Set<Int>
    /// Routeurs que la sonde a entendus, et leur dernier message, par identifiant.
    public let entendus: [Int: Date]
    /// La sonde a rendu ses annonces (firmware 1.1.0) : un routeur absent d'`entendus` n'a pas ete entendu.
    public let annoncesLues: Bool

    /// Rapproche le maillage des routeurs de bordure de sa partition et des appareils :
```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
        var liens = maillage.liens.compactMap { l -> LienAffiche? in
            guard let a = routeurs[l.a], let b = routeurs[l.b] else { return nil }
            return LienAffiche(de: a.id, vers: b.id, genre: .radio, qualite: l.qualite)
        }
        for e in maillage.enfants {
            guard let enfant = enfants[e.rloc16], let parent = routeurs[e.parent] else { continue }
            liens.append(LienAffiche(de: enfant.id, vers: parent.id, genre: .parent, qualite: e.qualite))
        }
        self.routeurs = routeurs
```

par :

```swift
        var liens = maillage.liens.compactMap { l -> LienAffiche? in
            guard let a = routeurs[l.a], let b = routeurs[l.b] else { return nil }
            return LienAffiche(de: a.id, vers: b.id, genre: .radio, qualite: l.qualite, origine: OrigineLien(l))
        }
        for e in maillage.enfants {
            guard let enfant = enfants[e.rloc16], let parent = routeurs[e.parent] else { continue }
            liens.append(LienAffiche(de: enfant.id, vers: parent.id, genre: .parent, qualite: e.qualite,
                                     origine: OrigineLien(e)))
        }
        self.routeurs = routeurs
```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
        }
        self.extMacs = connues
    }

```

par :

```swift
        }
        self.extMacs = connues
        routeursMuets = Set(maillage.routeurs.filter(\.muet).map(\.id))
        entendus = Dictionary(uniqueKeysWithValues: maillage.routeurs.compactMap { r in r.entendu.map { (r.id, $0) } })
        annoncesLues = maillage.annoncesLues
    }

    /// Un routeur que la sonde n'a jamais entendu, muet au diagnostic (un routeur Apple hors de portee) : ses liens ne
    /// viennent que de ses voisins. Faux si la sonde n'a pas rendu ses annonces (on ne sait pas).
    public func jamaisEntendu(_ id: String) -> Bool {
        guard annoncesLues, let r = routeurs.first(where: { $0.value.id == id })?.key else { return false }
        return routeursMuets.contains(r) && entendus[r] == nil
    }

```

- [ ] **Step 4 : les voir passer.** La commande du step 2.

Expected : `Test run with 26 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh`

Expected : `Test run with 439 tests in 43 suites passed` (cœur) et `Test run with 414 tests in 35 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add MaillageCoeur/Maillage/HistoriqueMaillage.swift MaillageCoeur/Maillage/Rapprochement.swift MaillageCoeurTests/HistoriqueTests.swift MaillageCoeurTests/RapprochementTests.swift && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --cached --name-only | sed "s|^|$PWD/|") && git commit -q -F - <<'EOF'
Garder la source des liens et la qualite calculee des enfants dans l'historique, et dire l'origine de chaque lien affiche

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` ; `0`.

---

### Task 9: La fiche, la couverture dans Réglages › Sonde, et les appareils à résoudre

**Files :**
- Modify : `MaillageThread/Vues/Pieces/FicheNoeud.swift`, `MaillageThread/Vues/FenetreReglages.swift`, `MaillageThread/Sonde/SondeMaillage.swift`, `MaillageThread/Surveillance/Surveillance.swift`, `MaillageThread/MaillageThreadApp.swift`, `MaillageThreadTests/AffichageSondeTests.swift`, `MaillageThreadTests/SondeTests.swift`, `MaillageThreadTests/SurveillanceTests.swift`, `MaillageCoeurTests/RapprochementTests.swift` (blocs) ; `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json` (outils)

**Interfaces:**
- Consumes : `OrigineLien`, `LienAffiche.origine`, `MaillageAffiche.jamaisEntendu` (tâche 8) ; `Maillage.couverture` (tâche 5) ; `AppareilAResoudre.depuis` et `Tournee.executer(…, appareils:)` (tâche 7).
- Produces :
  - `FicheNoeud.ligneSonde(_:maillage:nom:instant:)` (un enfant sans vrai RLOC16 n'en affiche pas ; son origine suit), `lignesLiens(_:maillage:nom:instant:)` (« voisin : qualité · origine », pour les liens radio qui ont une source), `texteOrigine(_:_:)`, `texteEchecs(_:)`, `texteJamaisEntendu` ;
  - `FenetreReglages.texteCouverture(_:)` et la ligne « Couverture » de Réglages › Sonde ;
  - `SondeMaillage.couverture` (remise à zéro par « Oublier la sonde » et par une autre sonde) et `SondeMaillage.appareilsAResoudre`, que la tournée appelle ;
  - `Surveillance.appareilsAResoudre()` (les appareils de l'instantané courant), branché dans `MaillageThreadApp`.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`).

Dans `MaillageThreadTests/AffichageSondeTests.swift`, remplacer :

```swift
        #expect(FicheNoeud.texteQualite(nil) == String(localized: "qualité inconnue"))
        #expect(FicheNoeud.texteQualite(3) == String(localized: "qualité \(3)"))
    }

```

par :

```swift
        #expect(FicheNoeud.texteQualite(nil) == String(localized: "qualité inconnue"))
        #expect(FicheNoeud.texteQualite(3) == String(localized: "qualité \(3)"))
    }

    /// Source et age d'un lien dans la fiche (spec de la sonde tout-en-un, section 2.4) : « diagnostic », « entendu il y
    /// a 3 minutes », « resolu il y a 12 minutes », « compteurs de l'enfant : 0,7 % d'echecs », ou donne par la sonde ;
    /// plusieurs a la suite.
    @Test func origineDUnLien() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let diagnostic = String(localized: "diagnostic")
        let entendu = String(localized: "entendu \(FicheNoeud.relatif(t - 180, t))")
        #expect(FicheNoeud.texteOrigine(OrigineLien(diagnostic: true), t) == diagnostic)
        #expect(FicheNoeud.texteOrigine(OrigineLien(entendu: t - 180), t) == entendu)
        #expect(FicheNoeud.texteOrigine(OrigineLien(diagnostic: true, entendu: t - 180), t) == diagnostic + " · " + entendu)
        let pourcentage = 0.007.formatted(.percent.precision(.fractionLength(1)))
        #expect(FicheNoeud.texteEchecs(0.007) == String(localized: "compteurs de l'enfant : \(pourcentage) d'échecs"))
        #expect(FicheNoeud.texteOrigine(OrigineLien(resolu: t - 720, echecs: 0.007), t)
                == String(localized: "résolu \(FicheNoeud.relatif(t - 720, t))") + " · " + FicheNoeud.texteEchecs(0.007))
        #expect(FicheNoeud.texteOrigine(OrigineLien(sonde: true), t) == String(localized: "donné par la sonde"))
        #expect(FenetreReglages.texteCouverture(CouvertureEcoute(entendus: 3, routeurs: 7))
                == String(localized: "routeurs entendus : \(3) sur \(7)"))
    }

    /// Fiche d'un routeur et de ses enfants avec la sonde 1.1.0 : chaque lien radio sur sa ligne, avec sa source et son
    /// age (un lien sans source, du maillage de demo, n'en a pas) ; « jamais entendu par la sonde » pour un routeur muet
    /// que la sonde n'entend pas ; un enfant resolu sous un routeur Apple, sans RLOC16 connu (appareils de la demo,
    /// maillage invente).
    @Test func ficheAvecLesSources() throws {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let r = try #require(s.reseau), i = try #require(s.instantane), p = try #require(r.principale)
        let appareils = i.appareils.filter { $0.partition == p.id && $0.etat == .joignable }.sorted { $0.id < $1.id }
        let routeur = try #require(appareils.first), enfant = try #require(appareils.last)
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        // Route64 (hexa) : sequence 1, masque des routeurs 1, 2 et 3 (ou du seul 1), un octet par routeur.
        func route64(_ hexa: String) throws -> Route64 { try #require(ReponseDiagnostic(hexa: hexa)?.route64) }
        var c = ConstructionMaillage(date: t, partition: p.id)
        c.routeurs(try route64("050C" + "01" + "7000000000000000" + "000000"), chef: 1)
        c.identite(routeur.id.uppercased(), routeur: 2)
        // Le chef 1 repond : sa Route64 des routeurs 1, 2 et 3, voisin du 2 (qualites 3 et 3).
        c.reponse(try #require(ReponseDiagnostic(hexa: "050C" + "01" + "7000000000000000" + "00F100")), routeur: 1)
        // Le 2 entendu il y a 3 min : voisin du 1 (qualites 2 et 2), plus ancien que le diagnostic.
        c.ecoute(try route64("050A" + "01" + "4000000000000000" + "A1"), routeur: 2, date: t - 180)
        c.muet(2)
        c.muet(3)
        c.annoncesRecues()
        c.enfant(EnfantMaillage(rloc16: 0x0C00 | EnfantMaillage.bitInvente, extMac: enfant.id.uppercased(), qualite: 2,
                                source: .resolution, resolu: t - 720, echecs: 0.012))
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        let n2 = try #require(m.noeud(routeur.id))
        let lignes = FicheNoeud.lignesLiens(n2, maillage: m, nom: { "[\($0)]" }, instant: t)
        #expect(lignes.count == 1)
        let l = try #require(m.liens.first { $0.genre == .radio })
        let o = try #require(l.origine)
        #expect(lignes.first == String(localized: "\("[\(l.de == n2.id ? l.vers : l.de)]") : \(FicheNoeud.texteQualite(l.qualite)) · \(FicheNoeud.texteOrigine(o, t))"))
        #expect(!m.jamaisEntendu(n2.id), "entendu")
        #expect(m.jamaisEntendu(try #require(m.routeurs[3]?.id)), "muet, pas entendu")
        #expect(FicheNoeud.texteJamaisEntendu == String(localized: "jamais entendu par la sonde ; liens vus seulement par ses voisins"))
        let ne = try #require(m.noeud(enfant.id))
        let parent = try #require(m.parent(de: ne.id))
        #expect(FicheNoeud.ligneSonde(ne, maillage: m, nom: { "[\($0)]" }, instant: t)
                == String(localized: "parent \("[\(parent)]"), \(FicheNoeud.texteQualite(2))") + " · "
                    + String(localized: "résolu \(FicheNoeud.relatif(t - 720, t))") + " · " + FicheNoeud.texteEchecs(0.012),
                "sans RLOC16 : il est invente")
        // Maillage de demo : aucune source, aucune ligne de lien.
        let demo = try #require(s.maillageAffiche(pour: r))
        let chef = try #require(demo.routeurs[1])
        #expect(FicheNoeud.lignesLiens(chef, maillage: demo, nom: { $0 }, instant: t).isEmpty)
    }

```

Dans `MaillageThreadTests/SondeTests.swift`, remplacer :

```swift
    /// « Oublier la sonde » efface son releve : etat de la sonde (partition, suspension), dernier
    /// releve et erreur de tournee ne restent pas apres elle.
    @Test(.timeLimit(.minutes(1))) func oublierEffaceLeReleve() async throws {
        let (p, domaine) = try Self.preferences()
```

par :

```swift
    /// « Oublier la sonde » efface son releve : etat de la sonde (partition, suspension), dernier
    /// releve et erreur de tournee ne restent pas apres elle.
    /// Firmware 1.1.0 : chaque tournee demande a l'app ses appareils a resoudre, et les passe a la sonde ; la couverture
    /// de l'ecoute (routeurs entendus sur ceux de la partition) est retenue avec le releve, et oubliee avec lui (valeurs
    /// inventees : le chef 0, entendu et muet ; l'appareil resolu sous lui, avec son propre RLOC16).
    @Test(.timeLimit(.minutes(1))) func couvertureEtResolution() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let canal = CanalRejoue { l in
            if l == "annonces\n" { return [CanalRejoue.annonce("0000", route64: "01800000000000000000", suite: false)] }
            let mots = l.trimmingCharacters(in: .newlines).split(separator: " ").map(String.init)
            if mots.count == 3, mots[0] == "resoudre", let id = Int(mots[2]) {
                return [CanalRejoue.resolution(id, mots[1], rloc16: "0002")]
            }
            return CanalRejoue.reseauMinimal(l)
        }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        let adresse = try #require(AdresseIPv6("fd00:aaaa:bbbb:1::17"))
        var demandes = 0
        s.appareilsAResoudre = {
            demandes += 1
            return [AppareilAResoudre(id: "E0000000000000C1", partition: "0000000A", adresse: adresse)]
        }
        var recu: Maillage?
        s.surMaillage = { m, _ in recu = m }
        await s.connecter(Self.port, choisi: true)
        await Self.attendre { s.derniereTournee != nil && !s.tourneeEnCours }
        #expect(demandes == 1)
        #expect(s.couverture == CouvertureEcoute(entendus: 1, routeurs: 1))
        #expect(canal.envoyes.contains { $0.hasPrefix("resoudre fd00:aaaa:bbbb:1::17 ") })
        let e = try #require(recu?.enfants.first { $0.extMac == "E0000000000000C1" })
        #expect(e.rloc16 == 0x0002 && e.source == .resolution, "sous le chef, muet")
        await s.oublier()
        #expect(s.couverture == nil)
    }

    @Test(.timeLimit(.minutes(1))) func oublierEffaceLeReleve() async throws {
        let (p, domaine) = try Self.preferences()
```

Dans `MaillageThreadTests/SurveillanceTests.swift`, remplacer :

```swift
        s.demarrer()
        return s
    }

```

par :

```swift
        s.demarrer()
        return s
    }

    /// Les appareils que la sonde doit resoudre (spec de la sonde tout-en-un, section 2.2) : ceux de l'instantane qui
    /// ont une adresse sur le prefixe OMR de leur partition ; aucun sans instantane.
    @Test func appareilsAResoudre() throws {
        let s = Self.demo()
        let i = try #require(s.instantane)
        #expect(s.appareilsAResoudre() == AppareilAResoudre.depuis(i))
        #expect(!s.appareilsAResoudre().isEmpty)
        #expect(Surveillance(mode: .demo, dossier: nil).appareilsAResoudre().isEmpty, "pas encore d'instantane")
    }

```

Dans `MaillageCoeurTests/RapprochementTests.swift`, remplacer :

```swift
        let ancien = MaillageAffiche(maillage: sans.maillage(), reseau: r, appareils: i.appareils)
        #expect(!ancien.jamaisEntendu(try #require(ancien.routeurs[3]?.id)), "sans annonces (1.0.3), on ne sait pas")
    }

```

par :

```swift
        let ancien = MaillageAffiche(maillage: sans.maillage(), reseau: r, appareils: i.appareils)
        #expect(!ancien.jamaisEntendu(try #require(ancien.routeurs[3]?.id)), "sans annonces (1.0.3), on ne sait pas")
    }

    /// Appareils a resoudre (spec de la sonde tout-en-un, section 2.2) : les appareils Thread de l'instantane qui ont
    /// une partition et une adresse sur son prefixe OMR, par identifiant, chacun avec cette adresse, sans zone ; pas un
    /// appareil du reseau local, ni un appareil sans adresse.
    @Test func appareilsAResoudre() throws {
        var b = Banc()
        b.routeur("Apple TV", partition: "46CBEBCD", primaire: true, lien: "fe80::1", omr: Self.omr, xa: "E0000000000000A1")
        b.appareil("E000000000000004", noeud: 1, adresses: ["fd00:5555:6666:0:b00::4%en0", "fe80::4"])
        b.appareil("Eve-HAP", noeud: 2, adresses: ["fd00:5555:6666:0:a00::9"])
        b.appareil("Prise-Wifi", noeud: 3, adresses: ["192.168.1.30"])
        b.appareil("Sans-Adresse", noeud: 4, adresses: [])
        let a = AppareilAResoudre.depuis(Instantane(annonces: b.annonces))
        #expect(a == [AppareilAResoudre(id: "E000000000000004", partition: "46CBEBCD",
                                        adresse: try #require(AdresseIPv6("fd00:5555:6666:0:b00::4"))),
                      AppareilAResoudre(id: "Eve-HAP", partition: "46CBEBCD",
                                        adresse: try #require(AdresseIPv6("fd00:5555:6666:0:a00::9")))])
        #expect(a.first?.adresse.description == "fd00:5555:6666:0:b00::4", "l'adresse nue, sans zone")
    }

```

- [ ] **Step 2 : les voir échouer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh MaillageThreadTests/AffichageSondeTests MaillageThreadTests/SondeMaillageTests MaillageThreadTests/SurveillanceTests MaillageCoeurTests/RapprochementTests`

Expected : la compilation des tests échoue : `type 'FicheNoeud' has no member 'texteOrigine'`, `type 'FicheNoeud' has no member 'texteEchecs'`, `type 'FenetreReglages' has no member 'texteCouverture'`, `value of type 'Surveillance' has no member 'appareilsAResoudre'`.

- [ ] **Step 3 : la fiche, la couverture, les appareils à résoudre** (`--etapes 3`).

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
    private var sonde: MaillageAffiche? { entree?.maillage }

    /// Ce que la sonde sait du noeud : son parent (enfant), ses voisins et ses enfants (routeur).
    @ViewBuilder
    private func lignesSonde(_ id: String) -> some View {
        if let m = sonde, let n = m.noeud(id) {
            Text(Self.ligneSonde(n, maillage: m, nom: nomNoeud)).foregroundStyle(.secondary)
        }
    }
```

par :

```swift
    private var sonde: MaillageAffiche? { entree?.maillage }

    /// Ce que la sonde sait du noeud : son parent (enfant), ses voisins et ses enfants (routeur) ; puis, pour un routeur,
    /// chaque lien avec sa source et son age, et s'il n'a jamais ete entendu par la sonde (spec de la sonde tout-en-un,
    /// section 2.4).
    @ViewBuilder
    private func lignesSonde(_ id: String) -> some View {
        if let m = sonde, let n = m.noeud(id) {
            Text(Self.ligneSonde(n, maillage: m, nom: nomNoeud, instant: instant)).foregroundStyle(.secondary)
            ForEach(Self.lignesLiens(n, maillage: m, nom: nomNoeud, instant: instant), id: \.self) { ligne in
                Text(ligne).font(.caption).foregroundStyle(.secondary)
            }
            if m.jamaisEntendu(id) {
                Text(Self.texteJamaisEntendu).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
                PastilleChef()
            }
            Text(Self.ligneSonde(n, maillage: m, nom: nomNoeud)).foregroundStyle(.secondary)
            if !n.candidats.isEmpty {
                // Chaque candidat ouvre la fiche de son annonce, pas dessinee a part.
```

par :

```swift
                PastilleChef()
            }
            lignesSonde(n.id)
            if !n.candidats.isEmpty {
                // Chaque candidat ouvre la fiche de son annonce, pas dessinee a part.
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
    }

    /// « RLOC16 5004 · parent HomePod bureau, qualite 3 » ; « RLOC16 5000 · voisins : 4 · enfants : 2 ».
    static func ligneSonde(_ n: NoeudSonde, maillage m: MaillageAffiche, nom: (String) -> String) -> String {
        let rloc = String(format: "%04X", n.rloc16)
        switch n.genre {
        case .enfant:
            guard let p = m.parent(de: n.id) else { return String(localized: "RLOC16 \(rloc)") }
            let q = m.liens.first { $0.genre == .parent && $0.de == n.id }?.qualite
            return String(localized: "RLOC16 \(rloc) · parent \(nom(p)), \(texteQualite(q))")
        case .routeur:
            let voisins = m.liens.filter { $0.genre == .radio && ($0.de == n.id || $0.vers == n.id) }.count
```

par :

```swift
    }

    /// « RLOC16 5004 · parent HomePod bureau, qualite 3 · diagnostic » ; un enfant resolu sous un routeur Apple, dont le
    /// RLOC16 est invente (`EnfantMaillage.bitInvente`), sans lui : « parent HomePod bureau, qualite 3 · resolu il y a
    /// 12 minutes · compteurs de l'enfant : 0,7 % d'echecs » ; « RLOC16 5000 · voisins : 4 · enfants : 2 ».
    static func ligneSonde(_ n: NoeudSonde, maillage m: MaillageAffiche, nom: (String) -> String,
                           instant: Date = .now) -> String {
        let rloc = String(format: "%04X", n.rloc16)
        switch n.genre {
        case .enfant:
            guard let p = m.parent(de: n.id) else { return String(localized: "RLOC16 \(rloc)") }
            let lien = m.liens.first { $0.genre == .parent && $0.de == n.id }
            let q = lien?.qualite
            let ligne = n.rloc16 & EnfantMaillage.bitInvente == 0
                ? String(localized: "RLOC16 \(rloc) · parent \(nom(p)), \(texteQualite(q))")
                : String(localized: "parent \(nom(p)), \(texteQualite(q))")
            return ([ligne] + (lien?.origine.map { [texteOrigine($0, instant)] } ?? [])).joined(separator: " · ")
        case .routeur:
            let voisins = m.liens.filter { $0.genre == .radio && ($0.de == n.id || $0.vers == n.id) }.count
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
    static func texteQualite(_ q: Int?) -> String {
        q.map { String(localized: "qualité \($0)") } ?? String(localized: "qualité inconnue")
    }

```

par :

```swift
    static func texteQualite(_ q: Int?) -> String {
        q.map { String(localized: "qualité \($0)") } ?? String(localized: "qualité inconnue")
    }

    /// Liens radio d'un routeur, chacun avec sa source et son age : « HomePod salon : qualite 3 · entendu il y a 3
    /// minutes » ; un lien sans source (maillage de demo) n'a pas de ligne.
    static func lignesLiens(_ n: NoeudSonde, maillage m: MaillageAffiche, nom: (String) -> String,
                            instant: Date) -> [String] {
        guard n.genre == .routeur else { return [] }
        return m.liens.filter { $0.genre == .radio && ($0.de == n.id || $0.vers == n.id) }.compactMap { l in
            guard let o = l.origine else { return nil }
            let voisin = l.de == n.id ? l.vers : l.de
            return String(localized: "\(nom(voisin)) : \(texteQualite(l.qualite)) · \(texteOrigine(o, instant))")
        }.sorted()
    }

    /// Source et age d'un lien : « diagnostic », « entendu il y a 3 minutes », « resolu il y a 12 minutes »,
    /// « compteurs de l'enfant : 0,7 % d'echecs », « donne par la sonde » ; plusieurs, separes par « · ».
    static func texteOrigine(_ o: OrigineLien, _ instant: Date) -> String {
        var parties: [String] = []
        if o.sonde { parties.append(String(localized: "donné par la sonde")) }
        if o.diagnostic { parties.append(String(localized: "diagnostic")) }
        if let d = o.entendu { parties.append(String(localized: "entendu \(relatif(d, instant))")) }
        if let d = o.resolu { parties.append(String(localized: "résolu \(relatif(d, instant))")) }
        if let e = o.echecs { parties.append(texteEchecs(e)) }
        return parties.joined(separator: " · ")
    }

    /// « compteurs de l'enfant : 0,7 % d'echecs » : le taux d'echec d'envoi, au dixieme de pour cent.
    static func texteEchecs(_ taux: Double) -> String {
        String(localized: "compteurs de l'enfant : \(taux.formatted(.percent.precision(.fractionLength(1)))) d'échecs")
    }

    /// Un routeur muet que la sonde n'entend pas (`MaillageAffiche.jamaisEntendu`).
    static var texteJamaisEntendu: String {
        String(localized: "jamais entendu par la sonde ; liens vus seulement par ses voisins")
    }

```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
    }

    /// « Dernier releve » de la sonde : la date et l'heure (la sonde peut rester des jours sans
    /// relever), comme le dernier releve du reseau local (section Diagnostic).
```

par :

```swift
    }

    /// Couverture de l'ecoute (spec de la sonde tout-en-un, section 2.4) : « routeurs entendus : 3 sur 7 », les routeurs
    /// de la partition que la sonde entend ; elle varie quand on deplace la sonde.
    static func texteCouverture(_ c: CouvertureEcoute) -> String {
        String(localized: "routeurs entendus : \(c.entendus) sur \(c.routeurs)")
    }

    /// « Dernier releve » de la sonde : la date et l'heure (la sonde peut rester des jours sans
    /// relever), comme le dernier releve du reseau local (section Diagnostic).
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
            if let e = sonde.etatSonde {
                LabeledContent("Partition", value: e.partition ?? "—")
                if e.suspendue {
                    Text("Sonde suspendue dans Maison (interrupteur « Sonde maillage » éteint) : pas de relevé.")
```

par :

```swift
            if let e = sonde.etatSonde {
                LabeledContent("Partition", value: e.partition ?? "—")
                if let c = sonde.couverture {
                    LabeledContent("Couverture", value: FenetreReglages.texteCouverture(c))
                }
                if e.suspendue {
                    Text("Sonde suspendue dans Maison (interrupteur « Sonde maillage » éteint) : pas de relevé.")
```

Dans `MaillageThread/Sonde/SondeMaillage.swift`, remplacer :

```swift
    /// Derniere erreur d'une tournee (la liaison reste ouverte).
    private(set) var erreurTournee: String?
    private(set) var liaison: Liaison = .usb
    /// Nom d'hote SRP de la sonde retenue (sans `.local`) : l'acces reseau vise `<hote>.local`.
```

par :

```swift
    /// Derniere erreur d'une tournee (la liaison reste ouverte).
    private(set) var erreurTournee: String?
    /// Couverture de l'ecoute au dernier maillage (firmware 1.1.0, spec de la sonde tout-en-un, section 2.4) : les
    /// routeurs que la sonde entend, sur ceux de la partition ; nil sans (firmware plus ancien, sans releve).
    private(set) var couverture: CouvertureEcoute?
    private(set) var liaison: Liaison = .usb
    /// Nom d'hote SRP de la sonde retenue (sans `.local`) : l'acces reseau vise `<hote>.local`.
```

Dans `MaillageThread/Sonde/SondeMaillage.swift`, remplacer :

```swift
    /// Appele quand la sonde est oubliee : son maillage part du graphe.
    @ObservationIgnored var surOubli: (() -> Void)?

    @ObservationIgnored private let preferences: UserDefaults
```

par :

```swift
    /// Appele quand la sonde est oubliee : son maillage part du graphe.
    @ObservationIgnored var surOubli: (() -> Void)?
    /// Appareils de l'app a resoudre (l'instantane : spec de la sonde tout-en-un, section 2.2), demandes au debut de
    /// chaque tournee ; nil : aucun.
    @ObservationIgnored var appareilsAResoudre: (@MainActor () -> [AppareilAResoudre])?

    @ObservationIgnored private let preferences: UserDefaults
```

Dans `MaillageThread/Sonde/SondeMaillage.swift`, remplacer :

```swift
        derniereTournee = nil
        erreurTournee = nil
        surOubli?()
        deconnecter(.sansSonde)
```

par :

```swift
        derniereTournee = nil
        erreurTournee = nil
        couverture = nil
        surOubli?()
        deconnecter(.sansSonde)
```

Dans `MaillageThread/Sonde/SondeMaillage.swift`, remplacer :

```swift
                    derniereTournee = nil
                    erreurTournee = nil
                }
            }
```

par :

```swift
                    derniereTournee = nil
                    erreurTournee = nil
                    couverture = nil
                }
            }
```

Dans `MaillageThread/Sonde/SondeMaillage.swift`, remplacer :

```swift
            guard sonde === self.sonde else { return }
            etatSonde = e
            let r = try await Tournee.executer(sonde, memoire: memoire, maintenant: horloge(), avancement: suivi)
            guard sonde === self.sonde else { return }
            // Meme sans maillage (pas de liste des routeurs), les identites apprises sont gardees.
```

par :

```swift
            guard sonde === self.sonde else { return }
            etatSonde = e
            let appareils = appareilsAResoudre?() ?? []
            let r = try await Tournee.executer(sonde, memoire: memoire, maintenant: horloge(), appareils: appareils,
                                               avancement: suivi)
            guard sonde === self.sonde else { return }
            // Meme sans maillage (pas de liste des routeurs), les identites apprises sont gardees.
```

Dans `MaillageThread/Sonde/SondeMaillage.swift`, remplacer :

```swift
                let recu = horloge()
                derniereTournee = recu
                surMaillage?(m, recu)
            }
```

par :

```swift
                let recu = horloge()
                derniereTournee = recu
                couverture = m.couverture
                surMaillage?(m, recu)
            }
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, remplacer :

```swift
        }
        return s
    }

```

par :

```swift
        }
        return s
    }

    /// Appareils que la sonde doit resoudre (spec de la sonde tout-en-un, section 2.2) : ceux de l'instantane qui ont
    /// une adresse sur le prefixe OMR de leur partition, l'adresse nue ; aucun sans instantane.
    func appareilsAResoudre() -> [AppareilAResoudre] {
        instantane.map(AppareilAResoudre.depuis) ?? []
    }

```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
            sm.surTournee = { [weak s] enCours in s?.tourneeEnCours = enCours }
            sm.surOubli = { [weak s] in s?.oublierMaillage() }
            sm.demarrer()
        }
```

par :

```swift
            sm.surTournee = { [weak s] enCours in s?.tourneeEnCours = enCours }
            sm.surOubli = { [weak s] in s?.oublierMaillage() }
            sm.appareilsAResoudre = { [weak s] in s?.appareilsAResoudre() ?? [] }
            sm.demarrer()
        }
```

- [ ] **Step 4 : les voir passer.** La commande du step 2.

Expected : `Test run with 15 tests in 1 suite passed` (cœur) et `Test run with 60 tests in 3 suites passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes,** par les outils.

```bash
W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" outils/synchroniser-textes.sh && /usr/bin/python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "%@ : %@ · %@": "%@: %@ · %@",
    "Couverture": "Coverage",
    "compteurs de l'enfant : %@ d'échecs": "child's counters: %@ failed",
    "diagnostic": "diagnostics",
    "donné par la sonde": "given by the probe",
    "entendu %@": "heard %@",
    "jamais entendu par la sonde ; liens vus seulement par ses voisins": "never heard by the probe; links seen only by its neighbors",
    "parent %@, %@": "parent %@, %@",
    "routeurs entendus : %lld sur %lld": "routers heard: %lld of %lld",
    "résolu %@": "resolved %@",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
/usr/bin/python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json && git diff --stat -- MaillageThread/Ressources outils/traductions
```

Expected : `MaillageThread/Ressources/Localizable.xcstrings | 160` et `outils/traductions/interface.json | 10` (`2 files changed, 170 insertions(+)`) : dix clés nouvelles.

- [ ] **Step 6 : toute la suite.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh`

Expected : `Test run with 440 tests in 43 suites passed` (cœur) et `Test run with 418 tests in 35 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 7 : commit.**

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add MaillageCoeurTests/RapprochementTests.swift MaillageThread/MaillageThreadApp.swift MaillageThread/Ressources/Localizable.xcstrings MaillageThread/Sonde/SondeMaillage.swift MaillageThread/Surveillance/Surveillance.swift MaillageThread/Vues/FenetreReglages.swift MaillageThread/Vues/Pieces/FicheNoeud.swift MaillageThreadTests/AffichageSondeTests.swift MaillageThreadTests/SondeTests.swift MaillageThreadTests/SurveillanceTests.swift outils/traductions/interface.json && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --cached --name-only | sed "s|^|$PWD/|") && git commit -q -F - <<'EOF'
Montrer la source et l'age de chaque lien dans la fiche, la couverture de l'ecoute dans les Reglages, et passer les appareils a resoudre a la tournee

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` ; `0`.

---

### Task 10: Maillage Thread 1.1.0 : la version, les notes de version et les README

**Files :**
- Modify : `project.yml`, `MaillageThreadTests/MisesAJourTests.swift`, `NOTES-VERSIONS.md`, `README.md`, `README.fr.md` (blocs ; les README sans bloc de code clôturé)

**Interfaces:**
- Consumes : tout ce qui précède, pour le dire.
- Produces : `MARKETING_VERSION` `1.1.0` ; la section `## 1.1.0` de `NOTES-VERSIONS.md` (bloc **English**, puis bloc **Français**), que `outils/publier.sh` lit ; les README, anglais et français, au même contenu : ce que l'écoute apporte et ses limites (spec, sections 7 et 8), la résolution, la qualité des enfants, la fiche, la couverture, l'historique.

- [ ] **Step 1 : le test d'abord** (`--etapes 1`).

Dans `MaillageThreadTests/MisesAJourTests.swift`, remplacer :

```swift
    @Test func infoPlist() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["CFBundleShortVersionString"] as? String == "1.0.0")
        #expect(Int(info["CFBundleVersion"] as? String ?? "") != nil, "un nombre, que compare Sparkle")
        #expect(info["SUFeedURL"] as? String
```

par :

```swift
    @Test func infoPlist() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["CFBundleShortVersionString"] as? String == "1.1.0")
        #expect(Int(info["CFBundleVersion"] as? String ?? "") != nil, "un nombre, que compare Sparkle")
        #expect(info["SUFeedURL"] as? String
```

- [ ] **Step 2 : le voir échouer.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh "MaillageThreadTests/MisesAJourTests/infoPlist()"`

Expected : `✘ Test infoPlist() recorded an issue at MisesAJourTests.swift:13:9: Expectation failed: info["CFBundleShortVersionString"] as? String == "1.1.0"` ; `** TEST FAILED **`.

- [ ] **Step 3 : la version** (`--etapes 3`).

Dans `project.yml`, remplacer :

```yaml
        # La version publiee (outils/publier.sh) ; le numero de compilation, que compare Sparkle, est donne a la
        # publication : le nombre de commits de main.
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        # Le flux des mises a jour (appcast.xml du depot, que publier.sh tient a jour, a son adresse brute) et la cle
```

par :

```yaml
        # La version publiee (outils/publier.sh) ; le numero de compilation, que compare Sparkle, est donne a la
        # publication : le nombre de commits de main.
        MARKETING_VERSION: "1.1.0"
        CURRENT_PROJECT_VERSION: "1"
        # Le flux des mises a jour (appcast.xml du depot, que publier.sh tient a jour, a son adresse brute) et la cle
```

- [ ] **Step 4 : le voir passer.** La commande du step 2.

Expected : `Test run with 1 test in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les notes de version et les README** (`--etapes 5`).

Dans `NOTES-VERSIONS.md`, remplacer :

```markdown
Maillage Thread : une section par version publiée, en anglais puis en français. `outils/publier.sh` en tire les
notes de la version publiée sur GitHub et celles de la fenêtre de mise à jour.

## 1.0.0
```

par :

```markdown
Maillage Thread : une section par version publiée, en anglais puis en français. `outils/publier.sh` en tire les
notes de la version publiée sur GitHub et celles de la fenêtre de mise à jour.

## 1.1.0

**English**

- The probe listens (firmware 1.1.0, to flash without erasing: the probe stays in Home): it hears the MLE
  advertisements of the routers within its radio range and decrypts them on the board, and the app draws their
  links, between Apple border routers too, which never answer diagnostics. For each direction of a link, the most
  recent measure wins, diagnostics or listening.
- Parent resolution replaces the scan of silent routers: every 30 minutes, and when a device appears, the probe
  resolves the Thread address of each Matter or HomeKit device, and the answer gives its parent, under an Apple
  router too.
- The children of Apple routers get a quality, from their MAC counters (failed sends between two readings).
- The node card gives the source and age of each link ("heard 3 minutes ago", "diagnostics", "child's counters:
  0.7% failed"); Settings, Probe, gives the coverage of the listening ("routers heard: 5 of 7").
- The history keeps the source of each link and the quality computed for the children; older files read as before.
- With a firmware older than 1.1.0, the app keeps to diagnostics.

**Français**

- La sonde écoute (firmware 1.1.0, à flasher sans effacement : la sonde reste dans Maison) : elle entend les
  annonces MLE des routeurs à portée de sa radio et les déchiffre sur la carte, et l'app dessine leurs liens, entre
  routeurs de bordure d'Apple aussi, qui ne répondent jamais au diagnostic. Pour chaque sens d'un lien, la mesure la
  plus récente l'emporte, diagnostic ou écoute.
- La résolution des parents remplace le balayage des routeurs muets : toutes les 30 minutes, et quand un appareil
  paraît, la sonde résout l'adresse Thread de chaque appareil Matter ou HomeKit, et la réponse donne son parent, sous
  un routeur d'Apple aussi.
- Les enfants des routeurs d'Apple ont une qualité, d'après leurs compteurs MAC (les échecs d'envoi entre deux
  relevés).
- La fiche d'un nœud donne la source et l'âge de chaque lien (« entendu il y a 3 minutes », « diagnostic »,
  « compteurs de l'enfant : 0,7 % d'échecs ») ; Réglages, Sonde, donne la couverture de l'écoute (« routeurs
  entendus : 5 sur 7 »).
- L'historique garde la source de chaque lien et la qualité calculée des enfants ; les fichiers d'avant se lisent
  comme avant.
- Avec un firmware antérieur à 1.1.0, l'app s'en tient au diagnostic.

## 1.0.0
```

Dans `README.md`, remplacer :

```markdown
| `MaillageCoeur/` | framework without UI: TXT decoding, snapshot (networks, partitions, prefixes, devices), tracking and log events, file log, names, routing table; tested on the real survey and on the replayed outage |
| `MaillageCoeur/Scene/` | room view without UI: nodes and links, floors and rooms, cards, layout (deterministic, with a budget), kept places, camera and flight, label placement and semantic zoom, projection for the `Canvas` engine; optimized even in Debug |
| `MaillageCoeur/Maillage/` | probe: diagnostic TLVs, Network Data, USB protocol, mesh model, tour (routers, scan of silent routers), kept router identities, matching with the snapshot (elimination, candidates), log of parents and Thread routers, tour history and curves; tested on an anonymized capture |
| `MaillageThread/Sonde/` | probe link: serial port without resetting the C6, USB ports, access over the Thread network (`Reseau/`: UDP transport and H1 envelope from the Halo bridge, key in the keychain, rid and resends), `SondeUSB` (requests matched by id and target, each with its own deadline), app model (probe remembered by its USB serial number, USB or network link, a tour every 5 minutes) |
| `MaillageThread/Noms/` | Home names: launching Passeur Noms, receiving its reading over the loopback (TCP listener on 127.0.0.1, one-time token), last valid names kept in the app's container |
```

par :

```markdown
| `MaillageCoeur/` | framework without UI: TXT decoding, snapshot (networks, partitions, prefixes, devices), tracking and log events, file log, names, routing table; tested on the real survey and on the replayed outage |
| `MaillageCoeur/Scene/` | room view without UI: nodes and links, floors and rooms, cards, layout (deterministic, with a budget), kept places, camera and flight, label placement and semantic zoom, projection for the `Canvas` engine; optimized even in Debug |
| `MaillageCoeur/Maillage/` | probe: diagnostic TLVs, Network Data, USB protocol, mesh model, tour (routers, MLE advertisements heard, parent resolution, children's MAC counters), kept router identities, matching with the snapshot (elimination, candidates), log of parents and Thread routers, tour history and curves; tested on an anonymized capture |
| `MaillageThread/Sonde/` | probe link: serial port without resetting the C6, USB ports, access over the Thread network (`Reseau/`: UDP transport and H1 envelope from the Halo bridge, key in the keychain, rid and resends), `SondeUSB` (requests matched by id and target, each with its own deadline), app model (probe remembered by its USB serial number, USB or network link, a tour every 5 minutes) |
| `MaillageThread/Noms/` | Home names: launching Passeur Noms, receiving its reading over the loopback (TCP listener on 127.0.0.1, one-time token), last valid names kept in the app's container |
```

Dans `README.md`, remplacer :

```markdown
nobody's parent. It sends Thread network diagnostics (`DIAG_GET`) for the app
and passes the raw answers back, over USB or, once access is allowed, over
the Thread network; the app decodes them and rebuilds the mesh.

The **Halo bridge** is the author's other ESP32-C6 project, a Matter over
```

par :

```markdown
nobody's parent. It sends Thread network diagnostics (`DIAG_GET`) for the app
and passes the raw answers back, over USB or, once access is allowed, over
the Thread network; the app decodes them and rebuilds the mesh. Since
firmware 1.1.0, it also hears the MLE advertisements of the routers around
it and resolves the parent of each device (see below).

The **Halo bridge** is the author's other ESP32-C6 project, a Matter over
```

Dans `README.md`, remplacer :

```markdown
  start. While a tour runs, a line at the top left, under the capsules (above
  the split-network banner), shows its step, a counter of requests and its
  duration ("Scan of silent routers · 24/48 · 0:42"). It is only there during
  the tour: the banner and the path move up when it goes, and back down
  when it comes. The view itself does not move: its top margin keeps the
```

par :

```markdown
  start. While a tour runs, a line at the top left, under the capsules (above
  the split-network banner), shows its step, a counter of requests and its
  duration ("Parent resolution · 12/26 · 0:42"). It is only there during
  the tour: the banner and the path move up when it goes, and back down
  when it comes. The view itself does not move: its top margin keeps the
```

Dans `README.md`, remplacer :

```markdown
  its identity (ExtMac, addresses) at most once every half hour, sleepy ones
  included (a Matter device's ExtMac is its host name).
- **Apple's border routers never answer diagnostics.** The scan of possible
  child RLOC16s targets the routers that never answered (Apple's) or that
  stayed silent two tours in a row (a refusal by the probe, or an unreadable
  answer, is not a silence), every 30 minutes or when that set changes; the
  quality of those links stays unknown, and a link between two Apple routers
  is never drawn.
- **Border router identities.** A silent Apple router does not give its
  ExtMac, so not the name of its announcement either. The probe (firmware
  1.0.2) learns the ExtMac of the routers it hears: each tour reads its router
  table (`routeurs`) and keeps every RLOC16 ↔ ExtMac pair, like the one of its
  parent, even when the tour gets no mesh. These identities are kept from one
  launch to the next with their partition (`identites-routeurs.json` in the
  app folder; another partition erases them, and the pair of a router that
```

par :

```markdown
  its identity (ExtMac, addresses) at most once every half hour, sleepy ones
  included (a Matter device's ExtMac is its host name).
- **Apple's border routers never answer diagnostics.** Since firmware 1.1.0,
  the probe makes up for it in three ways, below: listening, parent
  resolution and the children's MAC counters. They replace the scan of
  possible child RLOC16s, which missed the children that don't answer
  diagnostics.
- **Listening.** The probe hears the MLE advertisements of the routers within
  its radio range and decrypts them on the board: it derives the MLE key from
  the network key, which never leaves the board and is wiped right after.
  Each advertisement carries the router's routing table (Route64), so its
  links in both directions with every other router, Apple's included. After
  the probe's state, its router table and its neighbors, the tour asks for
  them (`annonces`; without an answer, it goes on without them) and keeps
  the routers of its partition: those heard from another partition (an Aqara
  hub's, for example) are set aside. For each pair of routers, each
  direction keeps the most recent measure, diagnostics or listening, dated
  by the age the probe gives; a link known from one end only is shown. Each
  advertisement also ties a RLOC16 to an ExtMac, like the probe's parent.
- **Parent resolution**, every 30 minutes and when a device appears: for each
  Matter or HomeKit device on Thread that the app knows with an address on
  its partition's OMR prefix, the probe has OpenThread resolve that address
  (`resoudre`, 8 in flight). The parent answers for its sleepy child, and the
  probe's address cache gives the RLOC16 found: without its 10 low bits, it
  is the parent's. Apple routers answer with their own RLOC16, third-party
  routers with the child's. The child is attached to its parent, dated
  (under a router that answers diagnostics, its child table prevails); a
  device that isn't resolved stays dotted ("assumed attachment"), as before.
- **Quality of the children of Apple routers.** At each resolution, the app
  asks each child of a silent router (Apple's) for its MAC counters (TLV 9,
  at its ML-EID, which the address cache gives: diagnostics are only
  accepted on the network's internal addresses). Between two readings,
  failed sends over unicast sends give the quality: under 1 %, 3; from 1 to
  5 %, 2; above, 1. Under 50 frames sent between the two readings, the
  quality is unknown; a counter that goes down (the device restarted) starts
  the readings over. A child that doesn't answer keeps an unknown quality;
  under a third-party router, the quality comes from its child table, as
  before.
- **What listening brings, and its limits.** The probe only hears the
  routers within its radio range; a single router heard gives all its
  links, and a link shows as soon as one of its two ends is heard. A badly
  placed probe never brings less than before: diagnostics, resolution and
  counters don't depend on where it sits. Settings › Probe shows the
  coverage, "routers heard: 5 of 7" (out of the routers of its partition);
  moving the probe changes it. The quality seen by an Apple parent stays
  unknown: only the child's, if it answers diagnostics, is measured.
  Resolution doesn't cross partitions: the children of another partition
  stay unknown. The mesh is a dated photo: links and parents change, and the
  card gives the age of each piece of information. With a firmware older
  than 1.1.0, the tour keeps to diagnostics.
- **Border router identities.** A silent Apple router does not give its
  ExtMac, so not the name of its announcement either. The probe (firmware
  1.0.2) learns the ExtMac of the routers it hears: each tour reads its router
  table (`routeurs`) and, since firmware 1.1.0, their MLE advertisements, and
  keeps every RLOC16 ↔ ExtMac pair, like the one of its parent, even when the
  tour gets no mesh. These identities are kept from one
  launch to the next with their partition (`identites-routeurs.json` in the
  app folder; another partition erases them, and the pair of a router that
```

Dans `README.md`, remplacer :

```markdown
- In the room view, solid lines between routers are radio links (2 points,
  colored by quality: green 3, yellow 2, orange 1, grey unknown); a child's
  line to its parent stays thin. Dotted lines stay for what the probe does not
  see. The mesh leader wears the crown. The card gives the parent and the
  quality, or a router's number of neighbors and children. If the probe stops
  answering, the last mesh is marked old 6 minutes after it was received
  (never during a tour); after 15 minutes the view goes back to dotted lines.
  The view redraws every minute: both changes show up within a minute, with
  no other event needed, and so do the open card's "seen … ago" and curves.
- Switching "Sonde maillage" off in Home suspends the probe: no tour, even
  after the probe restarts. The board's LED then gives a short orange flash
```

par :

```markdown
- In the room view, solid lines between routers are radio links (2 points,
  colored by quality: green 3, yellow 2, orange 1, grey unknown); a child's
  line to its parent stays thin. A link is a link: same line and same color
  whatever its source. Dotted lines stay for what the probe does not see. The
  mesh leader wears the crown. The card gives the parent and the quality, or
  a router's number of neighbors and children, and the source and age of
  each link ("diagnostics", "heard 3 minutes ago", "resolved 12 minutes
  ago", "child's counters: 0.7% failed"); for a router the probe has never
  heard, "never heard by the probe; links seen only by its neighbors". If
  the probe stops answering, the last mesh is marked old 6 minutes after it
  was received (never during a tour); after 15 minutes the view goes back to
  dotted lines. The view redraws every minute: both changes show up within a
  minute, with no other event needed, and so do the open card's "seen … ago"
  and curves.
- Switching "Sonde maillage" off in Home suspends the probe: no tour, even
  after the probe restarts. The board's LED then gives a short orange flash
```

Dans `README.md`, remplacer :

```markdown
  previous one and writes to the log ("Mesh" family): "X changed parent:
  A → B", "X has no parent anymore" (missing from two tours where its absence
  is certain; for a child known only by the scan of a silent router, such as
  an Apple border router, missing from two distinct scans, usually 30 to 60
  min apart) and a Thread router other than a border router appearing or
  disappearing; parent changes of one node within the hour fit on one line
  ("X changed parent 4 times within 1 h"). Only identified children (ExtMac)
  are followed. No notification by default ("Other changes"). Each tour also
  adds a line to `maillage-AAAA-MM.jsonl` in the app folder (kept 90 days,
  about 8 MB a month for 7 routers and 20 children): the quality of every
  link, and the signal of every router the probe hears (`voisins`) and of its
  parent (`etat`). A node's card draws its curves over 24 h, 7 d or 30 d: the
  quality of its links, parent changes marked, and for a router the "Signal
  seen by the probe", with the probe's own parent changes marked (the signal
  depends first on where the probe sits); its scale, in tens of dBm, always
  has its ticks, even for a single reading, and hovering gives the value and
  time of the nearest reading. None of this in demo mode.
- Probe captures hold the home network's addresses:
  `outils/anonymiser-sonde.py` rewrites them consistently before they become
```

par :

```markdown
  previous one and writes to the log ("Mesh" family): "X changed parent:
  A → B", "X has no parent anymore" (missing from two tours where its absence
  is certain; for a child known only by resolution, under an Apple border
  router, missing from two distinct resolutions, usually 30 to 60 min apart)
  and a Thread router other than a border router appearing or disappearing;
  parent changes of one node within the hour fit on one line ("X changed
  parent 4 times within 1 h"). Only identified children (ExtMac) are
  followed. No notification by default ("Other changes"). Each tour also
  adds a line to `maillage-AAAA-MM.jsonl` in the app folder (kept 90 days,
  about 8 MB a month for 7 routers and 20 children, up to 12 MB with the
  links heard and their sources): the quality of every link and, since
  1.1.0, its source (diagnostics or listening) and the quality the counters
  give the children (older files read as before), and the signal of every
  router the probe hears (`voisins`) and of its parent (`etat`). A node's
  card draws its curves over 24 h, 7 d or 30 d: the quality of its links,
  parent changes marked, and for a router the "Signal seen by the probe",
  with the probe's own parent changes marked (the signal depends first on
  where the probe sits); its scale, in tens of dBm, always has its ticks,
  even for a single reading, and hovering gives the value and time of the
  nearest reading. None of this in demo mode.
- Probe captures hold the home network's addresses:
  `outils/anonymiser-sonde.py` rewrites them consistently before they become
```

Dans `README.md`, remplacer :

```markdown
  It knows the messages of firmware 1.0.3 and of that capture, the form of
  every field, and the diagnostic TLVs the tour asks for, down to the Network
  Data; it fails on anything else, without writing anything. An already
  anonymized capture comes out unchanged. Free texts (vendor, model, versions,
  the probe's messages) are refused at the slightest identifier pattern, an
  address or hex digits even when split by separators: an ISO date may be
  refused too. An identifier deliberately disguised in a firmware string (hex
  split by other letters) would still pass.

### Route to the Thread network
```

par :

```markdown
  It knows the messages of firmware 1.0.3 and of that capture, the form of
  every field, and the diagnostic TLVs the tour asks for, down to the Network
  Data; it fails on anything else, the new messages of firmware 1.1.0
  included (`annonces`, `resoudre`, the listening counters, TLV 9), without
  writing anything. An already anonymized capture comes out unchanged. Free
  texts (vendor, model, versions, the probe's messages) are refused at the
  slightest identifier pattern, an address or hex digits even when split by
  separators: an ISO date may be refused too. An identifier deliberately
  disguised in a firmware string (hex split by other letters) would still
  pass.

### Route to the Thread network
```

Dans `README.fr.md`, remplacer :

```markdown
| `MaillageCoeur/` | framework sans interface : décodage des TXT, instantané (réseaux, partitions, préfixes, appareils), suivi et événements du journal, journal en fichiers, noms, table de routage ; testé sur le relevé réel et sur la panne rejouée |
| `MaillageCoeur/Scene/` | vue par pièces, sans interface : nœuds et liens, étages et pièces, cartes, disposition (déterministe, avec budget), places gardées, caméra et envol, placement des noms et zoom sémantique, projection vers le moteur `Canvas` ; optimisé même en Debug |
| `MaillageCoeur/Maillage/` | sonde : TLV du diagnostic, Network Data, protocole USB, modèle du maillage, tournée (routeurs, balayage des routeurs muets), identités des routeurs gardées, rapprochement avec l'instantané (élimination, candidats), journal des parents et des routeurs Thread, historique des tournées et courbes ; testé sur une capture anonymisée |
| `MaillageThread/Sonde/` | liaison avec la sonde : port série sans redémarrer le C6, ports USB, accès par le réseau Thread (`Reseau/` : transport UDP et enveloppe H1 du pont Halo, clé dans le trousseau, rid et renvois), `SondeUSB` (requêtes appariées par id et par cible, chacune avec son échéance), modèle de l'app (sonde retenue par son numéro de série USB, liaison USB ou réseau, une tournée toutes les 5 minutes) |
| `MaillageThread/Noms/` | noms de Maison : lancement de Passeur Noms, réception de son relevé par la boucle locale (écoute TCP sur 127.0.0.1, jeton à usage unique), derniers noms valides gardés dans le conteneur de l'app |
```

par :

```markdown
| `MaillageCoeur/` | framework sans interface : décodage des TXT, instantané (réseaux, partitions, préfixes, appareils), suivi et événements du journal, journal en fichiers, noms, table de routage ; testé sur le relevé réel et sur la panne rejouée |
| `MaillageCoeur/Scene/` | vue par pièces, sans interface : nœuds et liens, étages et pièces, cartes, disposition (déterministe, avec budget), places gardées, caméra et envol, placement des noms et zoom sémantique, projection vers le moteur `Canvas` ; optimisé même en Debug |
| `MaillageCoeur/Maillage/` | sonde : TLV du diagnostic, Network Data, protocole USB, modèle du maillage, tournée (routeurs, annonces MLE entendues, résolution des parents, compteurs MAC des enfants), identités des routeurs gardées, rapprochement avec l'instantané (élimination, candidats), journal des parents et des routeurs Thread, historique des tournées et courbes ; testé sur une capture anonymisée |
| `MaillageThread/Sonde/` | liaison avec la sonde : port série sans redémarrer le C6, ports USB, accès par le réseau Thread (`Reseau/` : transport UDP et enveloppe H1 du pont Halo, clé dans le trousseau, rid et renvois), `SondeUSB` (requêtes appariées par id et par cible, chacune avec son échéance), modèle de l'app (sonde retenue par son numéro de série USB, liaison USB ou réseau, une tournée toutes les 5 minutes) |
| `MaillageThread/Noms/` | noms de Maison : lancement de Passeur Noms, réception de son relevé par la boucle locale (écoute TCP sur 127.0.0.1, jeton à usage unique), derniers noms valides gardés dans le conteneur de l'app |
```

Dans `README.fr.md`, remplacer :

```markdown
diagnostic Thread (`DIAG_GET`) et lui rend les réponses brutes, par l'USB ou,
une fois l'accès autorisé, par le réseau Thread ; l'app les décode et
reconstruit le maillage.

Le **pont Halo** est l'autre projet ESP32-C6 de l'auteur, un pont Matter sur
```

par :

```markdown
diagnostic Thread (`DIAG_GET`) et lui rend les réponses brutes, par l'USB ou,
une fois l'accès autorisé, par le réseau Thread ; l'app les décode et
reconstruit le maillage. Depuis le firmware 1.1.0, elle entend aussi les
annonces MLE des routeurs qui l'entourent et résout le parent de chaque
appareil (voir plus bas).

Le **pont Halo** est l'autre projet ESP32-C6 de l'auteur, un pont Matter sur
```

Dans `README.fr.md`, remplacer :

```markdown
  vraiment. Pendant une tournée, une ligne en haut à gauche, sous les capsules
  (au-dessus du bandeau d'un réseau scindé), montre son étape, un compteur de
  requêtes et sa durée (« Balayage des routeurs muets · 24/48 · 0:42 »). Elle
  n'est là que pendant la tournée : le bandeau et le fil remontent quand elle
  disparaît, et redescendent quand elle paraît. La vue, elle, ne bouge pas :
```

par :

```markdown
  vraiment. Pendant une tournée, une ligne en haut à gauche, sous les capsules
  (au-dessus du bandeau d'un réseau scindé), montre son étape, un compteur de
  requêtes et sa durée (« Résolution des parents · 12/26 · 0:42 »). Elle
  n'est là que pendant la tournée : le bandeau et le fil remontent quand elle
  disparaît, et redescendent quand elle paraît. La vue, elle, ne bouge pas :
```

Dans `README.fr.md`, remplacer :

```markdown
  routeur son identité (ExtMac, adresses), au plus une fois par demi-heure,
  endormis compris (l'ExtMac d'un appareil Matter est son nom d'hôte).
- **Les routeurs de bordure d'Apple ne répondent jamais au diagnostic.** Le
  balayage des RLOC16 d'enfant possibles vise les routeurs qui n'ont jamais
  répondu (ceux d'Apple) ou qui se sont tus deux tournées de suite (un refus
  de la sonde, ou une réponse illisible, n'est pas un silence), toutes les 30
  minutes ou quand cet ensemble change ; la qualité de ces liens reste
  inconnue, et un lien entre deux routeurs Apple n'est jamais dessiné.
- **Identité des routeurs de bordure.** Muet, un routeur d'Apple ne donne pas
  son ExtMac, donc pas le nom de son annonce. La sonde (firmware 1.0.2)
  apprend celle des routeurs qu'elle entend : chaque tournée lit sa table des
  routeurs (`routeurs`) et retient chaque paire RLOC16 ↔ ExtMac, comme celle
  de son parent, même quand la tournée n'aboutit pas. Ces identités sont
  gardées d'un lancement à l'autre avec leur partition
  (`identites-routeurs.json` dans le dossier de l'app ; une autre partition
```

par :

```markdown
  routeur son identité (ExtMac, adresses), au plus une fois par demi-heure,
  endormis compris (l'ExtMac d'un appareil Matter est son nom d'hôte).
- **Les routeurs de bordure d'Apple ne répondent jamais au diagnostic.**
  Depuis le firmware 1.1.0, la sonde y supplée de trois façons, ci-dessous :
  l'écoute, la résolution des parents et les compteurs MAC des enfants. Elles
  remplacent le balayage des RLOC16 d'enfant possibles, qui manquait les
  enfants muets au diagnostic.
- **L'écoute.** La sonde entend les annonces MLE des routeurs à portée de sa
  radio et les déchiffre sur la carte : elle tire la clé MLE de la clé
  réseau, qui ne quitte jamais la carte et s'efface aussitôt. Chaque annonce
  porte la table de routage du routeur (Route64), donc ses liens dans les
  deux sens avec chacun des autres routeurs, ceux d'Apple compris. Après
  l'état de la sonde, sa table des routeurs et ses voisins, la tournée les
  demande (`annonces` ; sans réponse, elle continue sans) et garde les
  routeurs de sa partition : ceux d'une autre partition (celle d'un hub
  Aqara, par exemple) sont écartés. Pour une paire de routeurs, chaque sens
  garde la mesure la plus récente, diagnostic ou écoute, datée de l'âge que
  donne la sonde ; un lien connu d'un seul côté est affiché. Chaque annonce
  relie aussi un RLOC16 à une ExtMac, comme le parent de la sonde.
- **La résolution des parents**, toutes les 30 minutes et quand un appareil
  paraît : pour chaque appareil Matter ou HomeKit sur Thread que l'app
  connaît avec une adresse sur le préfixe OMR de sa partition, la sonde fait
  résoudre cette adresse par OpenThread (`resoudre`, 8 en vol). Le parent
  répond pour son enfant endormi, et le cache d'adresses de la sonde donne le
  RLOC16 trouvé : sans ses 10 bits de poids faible, c'est celui du parent.
  Les routeurs Apple répondent avec leur propre RLOC16, les routeurs tiers
  avec celui de l'enfant. L'enfant est rattaché à son parent, daté (sous un
  routeur qui répond au diagnostic, sa table des enfants l'emporte) ; un
  appareil non résolu reste en pointillés (« rattachement supposé »), comme
  avant.
- **La qualité des enfants des routeurs Apple.** À chaque résolution, l'app
  demande à chaque enfant d'un routeur muet (ceux d'Apple) ses compteurs MAC
  (TLV 9, à son ML-EID, que donne le cache d'adresses : le diagnostic n'est
  accepté que sur les adresses internes du réseau). Entre deux relevés, les
  échecs d'envoi rapportés aux envois donnent la qualité : moins de 1 %, 3 ;
  de 1 à 5 %, 2 ; au-delà, 1. Sous 50 trames envoyées entre les deux
  relevés, la qualité est inconnue ; un compteur qui baisse (l'appareil a
  redémarré) fait repartir les relevés. Un enfant qui ne répond pas garde une
  qualité inconnue ; sous un routeur tiers, la qualité vient de sa table des
  enfants, comme avant.
- **Ce que l'écoute apporte, et ses limites.** La sonde n'entend que les
  routeurs à portée de sa radio ; un seul routeur entendu donne tous ses
  liens, et un lien paraît dès que l'un de ses deux bouts est entendu. Une
  sonde mal placée n'apporte jamais moins qu'avant : le diagnostic, la
  résolution et les compteurs ne dépendent pas de sa position. Réglages ›
  Sonde montre la couverture, « routeurs entendus : 5 sur 7 » (sur les
  routeurs de sa partition) ; déplacer la sonde la fait varier. La qualité
  vue par un parent Apple reste inconnue : seule celle de l'enfant, s'il
  répond au diagnostic, est mesurée. La résolution ne traverse pas les
  partitions : les enfants d'une autre partition restent inconnus. Le
  maillage est une photo datée : liens et parents changent, et la fiche
  donne l'âge de chaque information. Avec un firmware antérieur à 1.1.0, la
  tournée s'en tient au diagnostic.
- **Identité des routeurs de bordure.** Muet, un routeur d'Apple ne donne pas
  son ExtMac, donc pas le nom de son annonce. La sonde (firmware 1.0.2)
  apprend celle des routeurs qu'elle entend : chaque tournée lit sa table des
  routeurs (`routeurs`) et, depuis le firmware 1.1.0, leurs annonces MLE, et
  retient chaque paire RLOC16 ↔ ExtMac, comme celle de son parent, même
  quand la tournée n'aboutit pas. Ces identités sont
  gardées d'un lancement à l'autre avec leur partition
  (`identites-routeurs.json` dans le dossier de l'app ; une autre partition
```

Dans `README.fr.md`, remplacer :

```markdown
- Dans la vue par pièces, les traits pleins entre routeurs sont les liens
  radio (2 points, colorés par la qualité : vert 3, jaune 2, orange 1, gris
  inconnue) ; le trait d'un enfant vers son parent reste fin. Les pointillés
  restent pour ce que la sonde ne voit pas. Le chef du maillage porte la
  couronne. La fiche donne le parent et la qualité, ou le nombre de voisins et
  d'enfants d'un routeur. Si la sonde ne répond plus, le dernier maillage est
  marqué ancien 6 minutes après sa réception (jamais pendant une tournée) ;
  après 15 minutes, la vue revient aux pointillés. La vue se redessine chaque
  minute : ces deux changements y paraissent avec une minute de retard au
  plus, sans autre événement, comme le « vu il y a … » et les courbes de la
  fiche ouverte.
- Éteindre « Sonde maillage » dans Maison suspend la sonde : pas de tournée,
  même après un redémarrage de la sonde. Sa LED donne alors un bref éclair
```

par :

```markdown
- Dans la vue par pièces, les traits pleins entre routeurs sont les liens
  radio (2 points, colorés par la qualité : vert 3, jaune 2, orange 1, gris
  inconnue) ; le trait d'un enfant vers son parent reste fin. Un lien est un
  lien : même trait et même couleur, quelle que soit sa source. Les
  pointillés restent pour ce que la sonde ne voit pas. Le chef du maillage
  porte la couronne. La fiche donne le parent et la qualité, ou le nombre de
  voisins et d'enfants d'un routeur, et la source et l'âge de chaque lien
  (« diagnostic », « entendu il y a 3 minutes », « résolu il y a 12
  minutes », « compteurs de l'enfant : 0,7 % d'échecs ») ; pour un routeur
  que la sonde n'a jamais entendu, « jamais entendu par la sonde ; liens vus
  seulement par ses voisins ». Si la sonde ne répond plus, le dernier
  maillage est marqué ancien 6 minutes après sa réception (jamais pendant
  une tournée) ; après 15 minutes, la vue revient aux pointillés. La vue se
  redessine chaque minute : ces deux changements y paraissent avec une
  minute de retard au plus, sans autre événement, comme le « vu il y a … »
  et les courbes de la fiche ouverte.
- Éteindre « Sonde maillage » dans Maison suspend la sonde : pas de tournée,
  même après un redémarrage de la sonde. Sa LED donne alors un bref éclair
```

Dans `README.fr.md`, remplacer :

```markdown
  celui de la précédente et note au journal (famille « Maillage ») : « X a
  changé de parent : A → B », « X n'a plus de parent » (absent de deux
  tournées où son absence est sûre ; pour un enfant connu seulement par le
  balayage d'un routeur muet, comme un routeur de bordure d'Apple, absent de
  deux balayages distincts, en général à 30 à 60 min d'écart) et
  l'apparition ou la disparition d'un
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
  l'endroit où elle est posée) ; son échelle, en dizaines de dBm, a toujours
```

par :

```markdown
  celui de la précédente et note au journal (famille « Maillage ») : « X a
  changé de parent : A → B », « X n'a plus de parent » (absent de deux
  tournées où son absence est sûre ; pour un enfant connu seulement par la
  résolution, sous un routeur de bordure d'Apple, absent de deux résolutions
  distinctes, en général à 30 à 60 min d'écart) et l'apparition ou la
  disparition d'un routeur Thread hors routeurs de bordure ; les changements
  de parent d'un même nœud dans l'heure tiennent sur une ligne (« X a changé
  4 fois de parent en 1 h »). Seuls les enfants identifiés (ExtMac) sont
  suivis. Pas de notification par défaut (« Autres changements »). Chaque
  tournée ajoute aussi une ligne à `maillage-AAAA-MM.jsonl`, dans le dossier
  de l'app (gardé 90 jours, environ 8 Mo par mois pour 7 routeurs et 20
  enfants, jusqu'à 12 Mo avec les liens entendus et leurs sources) : la
  qualité de chaque lien et, depuis la 1.1.0, sa source (diagnostic ou
  écoute) et la qualité que les compteurs donnent aux enfants (les fichiers
  d'avant se lisent comme avant), et le signal de chaque routeur que la sonde
  entend (`voisins`) et de son parent (`etat`). La fiche d'un nœud en tire
  ses courbes sur 24 h, 7 j ou 30 j : la qualité de ses liens, changements
  de parent marqués, et pour un routeur le « Signal vu par la sonde », où les
  changements de parent de la sonde sont marqués (le signal dépend d'abord de
  l'endroit où elle est posée) ; son échelle, en dizaines de dBm, a toujours
```

Dans `README.fr.md`, remplacer :

```markdown
  (plan 3b). Il connaît les messages du firmware 1.0.3 et ceux de cette
  capture, la forme de chaque champ et les TLV de diagnostic que la tournée
  demande, jusque dans la Network Data ; il échoue devant tout le reste, sans
  rien écrire. Une capture déjà anonymisée ressort telle quelle. Les textes
  libres (fabricant, modèle, versions, messages de la sonde) sont refusés au
  moindre motif d'identifiant, adresse ou chiffres hexa même coupés par des
  séparateurs : une date ISO peut l'être aussi. Un identifiant déguisé exprès
  dans une chaîne d'un firmware (hexa coupé par d'autres lettres) passerait.

### Route vers le réseau Thread
```

par :

```markdown
  (plan 3b). Il connaît les messages du firmware 1.0.3 et ceux de cette
  capture, la forme de chaque champ et les TLV de diagnostic que la tournée
  demande, jusque dans la Network Data ; il échoue devant tout le reste, les
  messages nouveaux du firmware 1.1.0 compris (`annonces`, `resoudre`, les
  compteurs de l'écoute, la TLV 9), sans rien écrire. Une capture déjà
  anonymisée ressort telle quelle. Les textes libres (fabricant, modèle,
  versions, messages de la sonde) sont refusés au moindre motif
  d'identifiant, adresse ou chiffres hexa même coupés par des séparateurs :
  une date ISO peut l'être aussi. Un identifiant déguisé exprès dans une
  chaîne d'un firmware (hexa coupé par d'autres lettres) passerait.

### Route vers le réseau Thread
```

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && /usr/bin/python3 -c "import importlib.util as u; s = u.spec_from_file_location('p', 'outils/publication.py'); m = u.module_from_spec(s); s.loader.exec_module(m); print(m.notes('NOTES-VERSIONS.md', '1.1.0').splitlines()[0])"`

Expected : `**English**` (la section que `publier.sh` lira).

- [ ] **Step 6 : commit.** Toute la suite passe à la tâche 11.

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add MaillageThreadTests/MisesAJourTests.swift NOTES-VERSIONS.md README.fr.md README.md project.yml && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --cached --name-only | sed "s|^|$PWD/|") && git commit -q -F - <<'EOF'
Passer Maillage Thread en 1.1.0 : notes de version, et ce que l'ecoute apporte et ses limites dans les README

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` ; `0`.

---

### Task 11: Toutes les suites, et les images de démo

**Files :** aucun.

**Interfaces:**
- Consumes : la branche `sonde-tout-en-un` (tâches 2 à 10) ; les images de référence (tâche 1).
- Produces : la preuve que tout passe, en français et en anglais, et que la démo ne change pas.

- [ ] **Step 1 : l'app, en français.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec" TMPDIR="$HOME/Library/Caches/sonde-tout-en-un-exec/" outils/tester.sh`

Expected : `Test run with 440 tests in 43 suites passed` (cœur) et `Test run with 418 tests in 35 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 2 : l'app, en anglais.** La commande anglaise des Global Constraints.

Expected : `code 0` ; `Test run with 440 tests in 43 suites passed` et `Test run with 418 tests in 35 suites passed`, `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 3 : la sonde et les outils.**

Run : `W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && sh sonde/test/lancer.sh && /usr/bin/python3 -m unittest discover -s sonde/test 2>&1 | tail -3 && /usr/bin/python3 -m unittest discover -s outils/tests 2>&1 | tail -3 && ~/.platformio/penv/bin/python sonde/test/vecteurs_mle.py --verifier`

Expected : `test_h1 : 121 verification(s), 0 echec(s)` ; `test_distant : 154 verification(s), 0 echec(s)` ; `test_mle : 72874 verification(s), 0 echec(s)` ; `Ran 146 tests`, `OK` ; `Ran 96 tests`, `OK` ; `vecteurs_mle.h : conforme au script`.

- [ ] **Step 4 : le firmware compile toujours.** La commande du step 5 de la tâche 3.

Expected : comme à la tâche 3 : `code 0`, `RAM` à 53.1 %, `Flash` à 76.5 %, `[SUCCESS]`, `0`.

- [ ] **Step 5 : les images de démo, comparées à celles de la tâche 1,** puis mises à la corbeille.

```bash
W=$S/sonde-tout-en-un-exec; T="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp"; B="$T/captures-sonde-tout-en-un-exec-base"; D="$T/captures-sonde-tout-en-un-exec-fin"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
n=0; for f in "$B"/*.png; do cmp -s "$f" "$D/$(basename "$f")" && n=$((n+1)); done; echo "identiques : $n sur $(ls "$B" | wc -l | tr -d ' ')"
pgrep -f "[s]onde-tout-en-un-exec/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitte"
[ "$n" -eq 21 ] && for d in "$B" "$D"; do mv "$d" "$HOME/.Trash/$(basename "$d")-$(date +%H%M%S)"; done
```

Expected : `identiques : 21 sur 21` ; `l'app a quitte` ; les deux dossiers d'images vont à la corbeille. Moins de 21 : une image a changé, ou l'app a été arrêtée en route (moins de 21 fichiers `.png` dans `$D`, faits établis) ; dans ce cas, mettre `$D` à la corbeille et relancer le step.

Pas de commit.

---

### Task 12: Le flash de la sonde en 1.1.0, sans effacement (avec Djoko)

**Files :** aucun ; `$P/flash-1.1.0.txt` (privé : il porte la MAC de la carte).

**Interfaces:**
- Consumes : le firmware de la tâche 3 (`$W/maillage/sonde`, compilé à la tâche 11).
- Produces : la sonde en 1.1.0, toujours dans Maison (appairage, réseau Thread, nom et clé d'accès réseau gardés).

Le pont Halo et la carte d'essai sont aussi des C6 : flasher l'un d'eux par erreur le remplacerait. Le numéro de série USB d'un C6 est son adresse MAC (`sonde/README.md`) : le port se vérifie par elle, et Djoko la confirme ; **aucune MAC n'est écrite dans ce plan, ni montrée** hors de ce que Djoko lit lui-même. Jamais `-t erase` ici.

- [ ] **Step 1 (Djoko) : préparer.** « Sonde maillage » allumé dans Maison. Djoko quitte lui-même Maillage Thread (il tient le port de la sonde quand elle est branchée), branche la sonde au Mac en USB, et désigne son port (`/dev/cu.usbmodem…`).

- [ ] **Step 2 (avec Djoko, accord) : la MAC derrière le port,** lue dans le registre des périphériques, sans ouvrir le port.

```bash
PORT=/dev/cu.usbmodemXXXX   # le port que Djoko a designe
ioreg -r -c IOUSBHostDevice -l | awk -v p="$PORT" '/"USB Serial Number"/ {n=$NF} /"IOCalloutDevice"/ && index($0, "\"" p "\"") {gsub(/"/, "", n); print n}'
```

Expected : une seule ligne, le numéro de série USB de la carte, sa MAC : Djoko la compare à celle qu'il connaît pour la sonde. Rien n'est écrit dans un fichier. Si ce n'est pas la MAC de la sonde, ou si rien ne sort : arrêter, et demander à Djoko.

- [ ] **Step 3 (avec Djoko, accord) : flasher, sans effacement.**

```bash
P=$HOME/Dev/maillage-thread/.superpowers/sonde-tout-en-un; W=$S/sonde-tout-en-un-exec; PORT=/dev/cu.usbmodemXXXX
cd "$W/maillage/sonde" && ~/.platformio/penv/bin/pio run -t upload --upload-port "$PORT" > "$P/flash-1.1.0.txt" 2>&1; echo "code $?"; grep -E "Hash of data verified|Hard resetting|SUCCESS|FAILED" "$P/flash-1.1.0.txt" | sort | uniq -c
```

Expected : `code 0` ; des `Hash of data verified.`, `Hard resetting via RTS pin...` et `[SUCCESS]`. La sortie complète, dans `$P/flash-1.1.0.txt`, porte la MAC que l'outil a lue sur la carte (ligne `MAC:`) : Djoko peut l'y comparer ; elle n'est pas montrée ici. Un échec (`FAILED`, port occupé) : ne rien relancer sans Djoko.

La sonde redémarre en 1.1.0 et se rattache ; le banc (tâche 13) le vérifie.

---

### Task 13: Le banc (avec Djoko, spec, section 5)

**Files :**
- Modify : `docs/superpowers/specs/2026-10-07-sonde-tout-en-un-design.md` (le banc, noté au step 5 : des comptes seulement)

**Interfaces:**
- Consumes : la sonde en 1.1.0 (tâche 12) ; l'app de travail, `$DD/Build/Products/Debug/Maillage Thread.app` (tâche 11).
- Produces : le banc fait, noté dans la spec ; `$P/banc.txt` (privé).

L'app du banc est la compilation de travail, en mode direct, avec l'accord de Djoko. Elle a l'identifiant de celle d'Applications, donc son conteneur : ses réglages (le port, la liaison), sa clé d'accès à la sonde dans le trousseau (signée ad hoc, la compilation de travail peut faire demander à macOS l'accès à cette clé : c'est Djoko qui répond), son journal et son historique (les lignes de la 1.1.0 portent des champs de plus, que la 1.0.0 lit sans eux : faits établis). Le contrôleur note ce que Djoko voit dans `$P/banc.txt`, en comptes et en RLOC16, jamais un nom, une ExtMac ou une adresse.

- [ ] **Step 1 (avec Djoko, accord) : lancer l'app de travail.** Son app d'Applications est quittée (tâche 12).

```bash
open -n "$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-exec/Build/Products/Debug/Maillage Thread.app"; sleep 5; pgrep -f "[s]onde-tout-en-un-exec/Build/Products/Debug/Maillage Thread.app"
```

Expected : un PID, à noter (pour l'arrêter au step 4). Réglages › Sonde : « connectée », firmware 1.1.0, pas d'avertissement de suspension.

- [ ] **Step 2 (Djoko) : la sonde à sa place habituelle ; une tournée et une résolution,** puis la vue comparée aux relevés de l'essai. La première tournée de la 1.1.0 fait la résolution complète (la mémoire de la tournée est neuve) ; le bouton rafraîchir de la capsule du réseau en lance une sans attendre les 5 minutes. Pendant la tournée, la ligne du haut passe par « Résolution des parents · n/m » puis « Compteurs des enfants ». Ensuite :
  1. **les liens entre routeurs Apple**, en traits pleins colorés par la qualité, comme les autres (avant : jamais dessinés) ; la fiche d'un routeur Apple liste ses liens, avec « entendu il y a … » ou « diagnostic » ;
  2. **les parents résolus** : les appareils sous un routeur Apple rattachés en trait plein (« résolu il y a … » dans leur fiche), et non plus en pointillés ; leur nombre comparé à celui de l'essai (20 appareils sur 26) ;
  3. **la qualité d'un enfant qui répond** : elle demande deux relevés de ses compteurs, à deux résolutions (30 minutes) d'écart, et 50 envois au moins entre eux : à la seconde, sa fiche dit « compteurs de l'enfant : … % d'échecs », et son trait prend la couleur de la qualité ;
  4. un routeur que la sonde n'entend pas dit « jamais entendu par la sonde ; liens vus seulement par ses voisins ».

  Le contrôleur note les comptes : routeurs entendus, liens entre routeurs Apple, appareils résolus sur appareils à résoudre, enfants avec une qualité.

- [ ] **Step 3 (Djoko) : la couverture.** Réglages › Sonde, « Couverture : routeurs entendus : n sur m ». Djoko déplace la sonde (par le réseau Thread si l'accès est autorisé, sinon branchée ailleurs), lance une tournée : la couverture varie. Puis la sonde retourne à sa place. Le contrôleur note les deux comptes.

- [ ] **Step 4 (avec Djoko, accord) : la fin du banc.** Arrêter l'app de travail (`kill` sur le PID du step 1), puis Djoko rouvre son app d'Applications (la 1.0.0 jusqu'à la tâche 16 ; elle travaille comme avant avec la sonde en 1.1.0, dont `diag` n'a pas changé).

- [ ] **Step 5 : noter le banc dans la spec.** À la fin de la section 5 de la spec (après le point 3), ce paragraphe, les `<…>` remplacés par les comptes du banc : jamais un nom, une ExtMac, une MAC ou une adresse.

```markdown

**Vérifié le <date> avec Djoko** (firmware 1.1.0 flashé sans effacement, app 1.1.0 de travail) : à sa place habituelle, la sonde entend <h> routeurs sur <m> (<h2> sur <m> à l'autre place essayée) ; <l> liens entre routeurs Apple dessinés ; <p> appareils sur <q> rattachés à leur parent par la résolution ; <c> enfants avec une qualité par leurs compteurs.
```

```bash
W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git add docs/superpowers/specs/2026-10-07-sonde-tout-en-un-design.md && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" "$PWD/docs/superpowers/specs/2026-10-07-sonde-tout-en-un-design.md" && git commit -q -F - <<'EOF'
Noter le banc de la sonde tout-en-un avec Djoko

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `trouve : aucun` ; `0`.

---

### Task 14: La fin de l'essai (avec Djoko, spec, section 6)

**Files :** aucun ; `$P/effacement-essai.txt` (privé : il porte la MAC de la carte d'essai).

**Interfaces:**
- Consumes : la carte d'essai, « Sonde essai » dans Maison ; le worktree `essai-ecoute` et les captures de l'essai, dans le scratchpad de la session de l'essai.
- Produces : ni la carte d'essai, ni Maison, ni le Mac ne gardent rien de l'essai : la carte est effacée (ni clé réseau, ni appairage) ; les captures, le worktree et la branche sont à la corbeille.

- [ ] **Step 1 (Djoko) : retirer « Sonde essai » de Maison** (la fiche de l'accessoire, « Supprimer l'accessoire »). Il le dit au contrôleur.

- [ ] **Step 2 (avec Djoko, accord) : la carte d'essai, et son port.** Djoko la branche et désigne son port ; la MAC derrière ce port, comme à la tâche 12, step 2 :

```bash
PORT=/dev/cu.usbmodemXXXX   # le port de la carte d'essai, que Djoko a designe
ioreg -r -c IOUSBHostDevice -l | awk -v p="$PORT" '/"USB Serial Number"/ {n=$NF} /"IOCalloutDevice"/ && index($0, "\"" p "\"") {gsub(/"/, "", n); print n}'
```

Expected : une seule ligne : Djoko confirme que c'est la carte d'essai, ni la sonde, ni le pont Halo. Sinon : arrêter.

- [ ] **Step 3 (avec Djoko, accord) : l'effacement de la carte d'essai.**

```bash
P=$HOME/Dev/maillage-thread/.superpowers/sonde-tout-en-un; W=$S/sonde-tout-en-un-exec; PORT=/dev/cu.usbmodemXXXX
cd "$W/maillage/sonde" && ~/.platformio/penv/bin/pio run -t erase --upload-port "$PORT" > "$P/effacement-essai.txt" 2>&1; echo "code $?"; grep -E "erased successfully|SUCCESS|FAILED" "$P/effacement-essai.txt" | sed "s/in [0-9.]* seconds/in … seconds/"
```

Expected : `code 0` ; `Flash memory erased successfully in … seconds.` ; `[SUCCESS]`. La carte n'a plus de firmware, ni clé réseau, ni appairage ; Djoko la débranche.

- [ ] **Step 4 (avec Djoko, accord) : la corbeille.** Le worktree `essai-ecoute`, ses captures privées et les journaux de ses flashs (à côté de lui, dans le scratchpad de la session de l'essai), la copie de son code faite pour ce plan (`sonde-tout-en-un/reference-essai`, au même endroit), puis la branche : gardée dans un paquet git (`bundle`) à la corbeille, avant d'être retirée du dépôt.

```bash
E=$(git -C ~/Dev/maillage-thread worktree list --porcelain | awk '/^worktree /{w=substr($0, 10)} /^branch refs\/heads\/essai-ecoute$/{print w}'); echo "worktree : $E"
H=$(date +%H%M%S); R=$(dirname "$E")
git -C ~/Dev/maillage-thread bundle create "$HOME/.Trash/essai-ecoute-$H.bundle" essai-ecoute && mv "$E" "$HOME/.Trash/essai-ecoute-$H" && for f in "$R/ecoute-captures" "$R"/flash-ecoute*.log "$R/sonde-tout-en-un/reference-essai"; do [ -e "$f" ] && mv "$f" "$HOME/.Trash/$(basename "$f")-$H"; done
git -C ~/Dev/maillage-thread worktree prune && git -C ~/Dev/maillage-thread branch -D essai-ecoute; git -C ~/Dev/maillage-thread worktree list | grep -c essai-ecoute; git -C ~/Dev/maillage-thread branch --list essai-ecoute | wc -l
```

Expected : le chemin du worktree ; `Deleted branch essai-ecoute (was …)` ; `0` ; `0`. La branche reste dans la corbeille : `git clone "$HOME/.Trash/essai-ecoute-….bundle"` la rend.

---

### Task 15: La fusion et le push (avec Djoko)

**Files :**
- Create : `docs/superpowers/plans/2026-10-07-sonde-tout-en-un.md` (ce plan, tel quel)

**Interfaces:**
- Consumes : la branche `sonde-tout-en-un` (tâches 2 à 10 et 13).
- Produces : `main` à jour dans le dépôt de travail et sur GitHub.

- [ ] **Step 1 : le plan, sur la branche.**

```bash
W=$S/sonde-tout-en-un-exec; cd "$W/maillage" && git show sonde-tout-en-un-brouillon:docs/superpowers/plans/2026-10-07-sonde-tout-en-un.md > docs/superpowers/plans/2026-10-07-sonde-tout-en-un.md && git add docs/superpowers/plans/2026-10-07-sonde-tout-en-un.md && git commit -q -F - <<'EOF'
Ecrire le plan de la sonde tout-en-un : firmware 1.1.0, app 1.1.0, banc, fin de l'essai, publication

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git log --oneline main..sonde-tout-en-un | wc -l
```

Expected : `11` (les tâches 2 à 10, le banc de la tâche 13, et le plan).

- [ ] **Step 2 : le contrôle d'anonymisation de toute la branche,** ses fichiers et ses messages.

```bash
P=$HOME/Dev/maillage-thread/.superpowers/sonde-tout-en-un; W=$S/sonde-tout-en-un-exec; A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; cd "$W/maillage" && git log --format=%B main..sonde-tout-en-un > "$P/controle-messages.txt" && /usr/bin/python3 "$A/outils/controles.py" fichiers --table "$A/execution/table.json" $(git diff --name-only main..sonde-tout-en-un | sed "s|^|$PWD/|") "$P/controle-messages.txt"; echo "code $?"
```

Expected : `trouve : aucun` (suivi des faux positifs connus) ; `code 0`. Sinon : rien ne part ; le dire à Djoko.

- [ ] **Step 3 (avec Djoko, accord) : fusionner dans le dépôt de travail.** Le geste : `main` avance d'un coup (`--ff-only`) sur `sonde-tout-en-un`, dans `~/Dev/maillage-thread`.

```bash
git -C ~/Dev/maillage-thread status --short | wc -l; git -C ~/Dev/maillage-thread merge -q --ff-only sonde-tout-en-un && git -C ~/Dev/maillage-thread log --oneline -1
```

Expected : `0` ; le commit du plan.

- [ ] **Step 4 (avec Djoko, accord) : pousser.** Le geste : `git push origin main`, jamais en force.

```bash
git -C ~/Dev/maillage-thread push -q origin main && git -C ~/Dev/maillage-thread status -sb | head -1
```

Expected : `## main...origin/main`, sans `ahead`.

---

### Task 16: La publication de Maillage Thread 1.1.0 (avec Djoko)

**Interfaces:**
- Consumes : `main` sur GitHub (tâche 15) ; la clé de Sparkle et le certificat `Djoko-cli Code Signing`, dans le trousseau de Djoko (plan du déploiement) ; les outils de Sparkle 2.10.0 (`$HOME/Dev/maillage-thread/.superpowers/deploiement/sparkle/bin`).
- Produces : la version publiée `maillage-v1.1.0` de `Djoko-cli/maillage-thread`, avec son `.dmg` ; le flux `appcast.xml`, la 1.1.0 en tête, commité sur `main` et poussé ; le dépôt de travail à jour ; l'app de Djoko en 1.1.0.

Comme au déploiement (tâches 15 et 16 de son plan) : la publication se fait depuis un clone neuf de GitHub, hors d'iCloud, sans `Local.xcconfig`, son auteur posé comme celui du dépôt de travail (adresse noreply) ; `SPARKLE_BIN` désigne les outils de Sparkle ; `DD` un dossier de produits à elle. `publier.sh` vérifie, lance toutes les suites (une vingtaine de minutes), compile, signe, passe le contrôle d'anonymisation, puis fait les gestes publics, chacun noté dans `build/publication/1.1.0/gestes.txt`.

- [ ] **Step 1 : le clone.**

```bash
W=$S/sonde-tout-en-un-exec; git clone -q https://github.com/Djoko-cli/maillage-thread "$W/publication-maillage" && git -C "$W/publication-maillage" config user.name "$(git -C ~/Dev/maillage-thread config user.name)" && git -C "$W/publication-maillage" config user.email "$(git -C ~/Dev/maillage-thread config user.email)" && git -C "$W/publication-maillage" config user.email | grep -c "@users.noreply.github.com$"; git -C "$W/publication-maillage" log --oneline -1
```

Expected : `1` (l'adresse noreply) ; la tête de `main` de la tâche 15 (le commit du plan).

- [ ] **Step 2 (avec Djoko, accord) : publier la 1.1.0.** Le geste : `publier.sh` vérifie tout, lance les suites, compile, signe le `.dmg` avec la clé du trousseau, ajoute la 1.1.0 en tête du flux, passe le contrôle d'anonymisation, crée la version publiée `maillage-v1.1.0` avec le `.dmg`, puis commite le flux sur `main` et le pousse aussitôt. En tâche de fond.

```bash
W=$S/sonde-tout-en-un-exec; cd "$W/publication-maillage" && SPARKLE_BIN="$HOME/Dev/maillage-thread/.superpowers/deploiement/sparkle/bin" DD="$HOME/Library/Developer/Xcode/DerivedData/sonde-tout-en-un-publication" outils/publier.sh 1.1.0 --sans-bureau > "$W/publication-maillage.txt" 2>&1; echo "code $?" >> "$W/publication-maillage.txt"; grep -v "^tests " "$W/publication-maillage.txt"
```

Expected : `version 1.1.0, numero de compilation <commits de main>, macOS 26.0 minimum` ; `exigence de signature : designated => identifier "fr.djoko.maillage" and certificate leaf = H"…"` (la même qu'en 1.0.0 : l'app garde l'accès à sa clé du trousseau) ; `contenu du .dmg : aucun chemin personnel` ; `signe : …/Maillage-Thread-1.1.0.dmg (… octets) ; flux : …/appcast.xml` ; `controle d'anonymisation (… fichiers) : trouve : aucun ; …` ; `publie : https://github.com/Djoko-cli/maillage-thread/releases/tag/maillage-v1.1.0` ; `flux commite et pousse sur main : https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml` ; `code 0`.

**La reprise.** Un `refus : …` ou un `echec : …` avant `publie :` n'a rien publié : le lire, corriger, relancer la même commande (une suite tombée sur « Could not launch », par exemple, se relance telle quelle). Un échec pendant les gestes publics laisse ceux déjà faits, notés dans `build/publication/1.1.0/gestes.txt` (« tentative : … » avant chaque geste, puis sa réussite, ou « echec : … » avec la reprise) : ce fichier dit où reprendre, avec les produits du même dossier (`notes.md`, `appcast.xml`, `message-commit.txt`, le `.dmg`). Une « tentative » sans suite est ambiguë : lire GitHub d'abord (`gh release view maillage-v1.1.0 -R Djoko-cli/maillage-thread`, `git -C "$W/publication-maillage" ls-remote origin main`), puis reprendre, avec l'accord de Djoko. Un échec après `publie :` (le push du flux) laisse la version publiée sans flux : pousser le commit du flux à la main (`git -C "$W/publication-maillage" push origin HEAD:main`), avec son accord.

- [ ] **Step 3 : le flux en ligne.**

```bash
gh release view maillage-v1.1.0 -R Djoko-cli/maillage-thread --json assets -q '.assets[].name'; curl -sL https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml | grep -E "shortVersionString|enclosure" | cut -c1-120
```

Expected : `Maillage-Thread-1.1.0.dmg`, seul ; dans le flux, `<sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>` et l'`enclosure` vers `https://github.com/Djoko-cli/maillage-thread/releases/download/maillage-v1.1.0/Maillage-Thread-1.1.0.dmg`, puis ceux de la 1.0.0. L'adresse brute peut mettre quelques minutes à suivre `main`.

- [ ] **Step 4 (avec Djoko, accord) : le dépôt de travail à jour.** Le geste : `git pull --ff-only` dans `~/Dev/maillage-thread`, pour y recevoir le commit du flux.

```bash
git -C ~/Dev/maillage-thread pull -q --ff-only && git -C ~/Dev/maillage-thread log --oneline -1
```

Expected : `Publier Maillage Thread 1.1.0 dans le flux des mises a jour`.

- [ ] **Step 5 (avec Djoko, accord, s'il le veut) : le `.dmg` sur son Bureau.**

```bash
W=$S/sonde-tout-en-un-exec; cp "$W/publication-maillage/build/publication/1.1.0/Maillage-Thread-1.1.0.dmg" ~/Desktop/ && ls -la ~/Desktop/Maillage-Thread-1.1.0.dmg
```

Expected : le fichier, à la taille que dit le flux (step 3).

- [ ] **Step 6 (Djoko) : la mise à jour, en vrai.** Dans son Maillage Thread 1.0.0 (Applications), « Rechercher les mises à jour… » : la fenêtre de Sparkle propose la 1.1.0, avec ses notes (anglais, puis français) ; « Installer et relancer » : l'app se relance en 1.1.0. Réglages › Sonde : firmware 1.1.0 et la couverture ; aucune demande d'accès au trousseau (même exigence de signature). Après une tournée, la vue est celle du banc.

- [ ] **Step 7 (avec Djoko, accord) : ranger.** À la corbeille : les DD de ce plan (`sonde-tout-en-un-exec`, `sonde-tout-en-un-publication`), `$W/publication-maillage` et sa sortie, `$HOME/Library/Caches/sonde-tout-en-un-exec` ; le worktree `$W/maillage`, après la fusion (ses commits sont dans `main`), puis `git worktree prune` ; et les worktrees de la préparation (branches `sonde-tout-en-un-brouillon` et `sonde-tout-en-un-rejeu`), dont les branches restent jusqu'à ce que Djoko les retire. Rien ne s'efface définitivement.

---

## Exécution (07 et 08/10/2026)

Le plan a été exécuté tâche par tâche, chaque tâche relue. Les relectures ont corrigé, au-delà du plan :
- **le test au hasard du décodage MLE** : un octet du gabarit était faux (seules 261 trames sur 200 000 allaient jusqu'au déchiffrement) ;
- **`annonces` par le réseau** : les lignes partent au fil des places libres de la file d'émission (une place laissée libre), la réponse n'est plus gardée (un renvoi relance la lecture), et l'app lui donne un délai propre ;
- **la tournée** : un appareil dont le parent sort de la liste est re-résolu dans la même tournée (sinon, un faux « n'a plus de parent ») ;
- **l'affichage** : le RLOC16 inventé d'un enfant résolu n'apparaît nulle part (« Non identifié » seul) ;
- **la clé réseau** : lue au plus une fois par séquence de clé de la pile, même après un échec de dérivation ; une trame forgée ne prend plus le verrou d'OpenThread ;
- **les compteurs MAC (décision de Djoko du 07/10)** : `ifOutErrors` compte les échecs d'accès au canal, pas les accusés manquants ; ils ne donnent donc plus de qualité, seulement « accès au canal refusés : x % » en information (précision 9 remplacée ; voir la spec, section 2.3).

Effectifs finaux : cœur 441 tests, app 421 (français et anglais) ; hôte `test_h1` 121, `test_distant` 160, `test_mle` 138 824 ; Python 146 et 96 ; firmware : flash 76,5 %, RAM 54,1 %. Le banc est noté dans la spec, section 5.
