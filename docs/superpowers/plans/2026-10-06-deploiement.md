# Déploiement de Maillage Thread et de Halo Compagnon : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Les tâches 1 à 10 peuvent aller à des sous-agents ; les tâches 11 à 17 se font avec Djoko, par le contrôleur de la session lui-même.

**Goal :** livrer les deux apps macOS, Maillage Thread et Halo Compagnon, en versions publiées sur GitHub (étiquettes `maillage-vX.Y.Z` et `compagnon-vX.Y.Z`) qui se mettent à jour seules par Sparkle 2, d'après un flux tenu dans chaque dépôt, leurs `.dmg` signés Ed25519 et leur code signé par un certificat auto-signé stable ; renommer le démon `halo-routes` en Thread Route, avec la migration, et montrer son état dans les deux apps ; écrire `publier.sh` dans les deux dépôts, prêt pour une notarisation désactivée ; corriger la spec ; puis, avec Djoko, créer la vraie clé et le certificat, répéter, migrer, fusionner, publier les deux 1.0.0, remettre les `.dmg` sur le Bureau et vérifier en vrai.

**Architecture :**
- **Thread Route** (dépôt du pont Halo, `tools/macos/thread-route`) : `halo-routes` renommé, au comportement inchangé. Son installateur retire l'ancien démon avant de poser le nouveau (`installer.sh --plan` dit l'ordre sans rien changer ; `tests.sh` le vérifie sur une fausse racine). **Il est installé par son installateur**, avec le mot de passe administrateur (spec, section 2 : le repli, validé par Djoko le 06/10 après l'essai). Maillage Thread en garde une copie conforme (`outils/thread-route`), avec son script de synchronisation et son test.
- **L'état de Thread Route** dans chaque app (`EtatThreadRoute`) : lu auprès de macOS par `SMAppService.statusForLegacyPlist`, que permet le bac à sable, pour le plist de Thread Route et pour celui de `halo-routes`. Quatre cas : absent, désactivé dans Réglages Système, actif, ancien (`halo-routes` encore là) ; avec la commande d'installation. Halo Compagnon le montre dans Réglages, Général, et dans son message « Pas de route » ; Maillage Thread dans Réglages, Diagnostic.
- **Sparkle 2.10.0** par le gestionnaire de paquets Swift, déclaré dans `project.yml`. `MisesAJour`, dans chaque app : `SPUStandardUpdaterController`, démarré au lancement sauf sous les tests (et, pour Maillage Thread, en démo) ; le menu « Rechercher les mises à jour… » ; dans les Réglages, « Rechercher automatiquement » et « Installer automatiquement ». L'Info.plist porte le flux, à l'adresse brute du fichier `appcast.xml` du dépôt sur `main`, la clé publique (`CLE_MISES_A_JOUR`, provisoire jusqu'à la tâche 11), et les réglages de Sparkle ; les droits ajoutent les deux `mach-lookup` de Sparkle.
- **`publier.sh`** dans chaque dépôt (`outils/publier.sh`, `apps/macos/Outils/publier.sh`) : un appel de `publication.py`, identique dans les deux dépôts, avec ses tests sur un faux dépôt et de fausses commandes. Il compile en Release, puis **signe l'app par le certificat `Djoko-cli Code Signing`** (son code imbriqué d'abord, le runtime renforcé), trouvé par son nom dans le trousseau ; l'identité se règle en un seul endroit, `IDENTITE_SIGNATURE`. Une étape de notarisation est écrite, désactivée par défaut (`NOTARISER=1`, `PROFIL_NOTARISATION`). La version publiée porte l'étiquette de l'app (`maillage-v`, `compagnon-v`) et le seul `.dmg` ; puis la version entre en tête du flux du dépôt (`appcast.xml` à la racine de Maillage Thread, `apps/macos/appcast.xml` dans le pont), qui garde toutes les versions, et ce fichier est commité sur `main` et poussé aussitôt. `--repetition` fait tout sans GitHub ni Bureau, avec la clé et le certificat de Djoko, ou une paire et un certificat d'essai (`--trousseau`, un trousseau à part).
- **Les compilations de travail et les tests restent ad hoc**, sans changement.
- **La spec** (dans les deux dépôts, identique) : les décisions de Djoko du 06/10 (le certificat, le flux dans le dépôt et les étiquettes par app, Thread Route par son installateur, macOS 15 pour Halo Compagnon), la distribution large (section 7).
- **Privé, jamais commité** (`$P`, sous `.superpowers/`) : les outils de Sparkle, `repetition.sh`, `trousseau-essai.py`.

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI, AppKit, ServiceManagement (`SMAppService`), Security (`SecTask`), Sparkle 2.10.0 (SPM ; `sign_update`, `generate_keys` et `sparkle-cli` du même projet), Swift Testing, XcodeGen 2.46, `xcodebuild` (Xcode 27), Python 3.9 (`/usr/bin/python3`, sans dépendance), sh, clang, `codesign`, `security`, `openssl`, `hdiutil`, `notarytool` et `stapler` (désactivés), `gh`.

**Spec :** `docs/superpowers/specs/2026-10-06-deploiement-design.md` (validée par Djoko le 06/10 ; une copie identique dans le dépôt du pont Halo). Le brief de ce plan est privé : `.superpowers/deploiement/plan-brief.md`.

**Quand l'exécuter.** Après la validation de ce plan par Djoko, sur deux worktrees neufs (Global Constraints). Les numéros de ligne ne sont jamais cités : l'exécutant se repère aux blocs, qui s'appliquent au texte exact.

## La préparation du 06/10 : essai, code validé, répétition, rejeu

**L'essai de Thread Route** (spec, section 2), fait le 06/10 avec des apps jetables, dans le bac à sable, et un démon d'essai inoffensif :
1. **macOS refuse tout de suite d'inscrire**, depuis une app du bac à sable, un démon qui n'y est pas : « SMAppService target executable must be sandboxed because the app is sandboxed » (`backgroundtaskmanagementd`). Ni la signature ad hoc ni un certificat auto-signé n'y changent rien.
2. **Ce qu'une app du bac à sable voit d'un démon posé par un installateur** (essayé sur `halo-routes`, installé et actif) : `SMAppService.statusForLegacyPlist(at:)` répond `enabled` pour son plist, `notRegistered` pour un plist absent (le moyen retenu, sans droit de plus) ; `sysctl` `KERN_PROC_ALL` voit aussi le processus et son uid ; les plists de `/Library/LaunchDaemons` se lisent, les journaux de `/Library/Logs` ne s'ouvrent pas.
3. **Root :** `halo-routes`, posé par `installer.sh`, tourne en uid 0.

**Décision de Djoko (06/10) :** le repli. Thread Route est installé par `installer.sh`, renommé, avec la migration depuis `halo-routes` ; les apps affichent son état et la commande. Rien, dans ce plan, n'inscrit de démon par une app.

**Code validé avant exécution.** Le 06/10, tout le code de ce plan a été écrit en TDD, compilé et testé dans deux worktrees, sur la branche `deploiement-brouillon` : Maillage Thread à partir de `b5733c8`, le pont Halo à partir de `8b854da` ; puis repris le même jour pour les décisions de Djoko : la signature des versions publiées par un certificat auto-signé stable ; la notarisation écrite et désactivée, et la section 7 de la spec ; le flux tenu dans le dépôt, avec des étiquettes propres à chaque app ; le repli pour Thread Route. Puis le plan a été rejoué sur deux worktrees neufs, ses blocs appliqués par `appliquer-blocs.py` sur le brief de chaque tâche : les arbres finaux sont identiques à ceux de la copie validée (Maillage Thread `e0467273ec6cda6d11f43996c8d453b94a8dcd72`, au plan près ; pont Halo `e62737a198278462ea07364c8599aa640b01dc8d`). Les résultats attendus ci-dessous viennent de ce rejeu.
- **Les suites,** en français et en anglais, sans avertissement : Maillage Thread 420 tests en 42 suites pour le cœur, 398 en 34 pour l'app (avant ce plan : 420 et 42, 391 et 32) ; Halo Compagnon 144 tests en 20 suites pour HaloProtocole, 41 en 9 pour l'app (avant : 144 et 20, 34 et 7) ;
- **les tests Python et hôte :** Maillage Thread : `outils/tests`, 37 tests (nouveaux : 3 pour la copie de Thread Route, 34 pour la publication) ; la sonde, 141 tests Python, `test_h1` 121 et `test_distant` 145 vérifications ; la copie de Thread Route, 47 vérifications de la décision et 4 de l'installation. Pont Halo : `apps/macos/Outils/tests`, 34 tests (nouveaux) ; `tools/test_halo1.sh`, 2 232 508 vérifications du protocole, 301 du JSON, 121 de H1, et deux contrôles de lignes machine sans erreur ; `tools/test_halo_udp.py`, 8 tests ; Thread Route, 47 et 4 vérifications ; `apps/macos/Outils/generer_demo.py` régénère la démo à l'identique ;
- **les images de démo de Maillage Thread** ne changent pas : les 21, rendues avant la tâche 4 et après la tâche 9, sont identiques octet pour octet (la spec n'en impose aucune).

**La répétition, sans GitHub** (spec, section 4), sur des clones des copies validées, avec une paire de clés Ed25519 d'essai dans des fichiers et un certificat auto-signé d'essai dans un trousseau à part (jamais le trousseau de la session), et un serveur HTTP sur 127.0.0.1 : pour chaque app, `publier.sh --repetition` a compilé une copie 1.0.0 puis une version 1.0.1 avec le flux local et la clé publique d'essai, signé l'app par le certificat d'essai (`Djoko-cli Code Signing (essai)`, dans un trousseau à part), puis ses `.dmg` avec la clé privée d'essai (`sign_update --ed-key-file`), passé le contrôle d'anonymisation (rien trouvé), et ajouté chaque version en tête du flux du dépôt, commité dans le clone (« Publier … dans le flux des mises a jour ») : après la 1.0.1, le flux porte les deux versions. Un serveur local a servi ce flux comme l'adresse brute du dépôt (`/Djoko-cli/<dépôt>/main/<chemin>`) et les `.dmg` comme les versions publiées (`/Djoko-cli/<dépôt>/releases/download/<étiquette>/`) ; puis `sparkle-cli`, sur la copie 1.0.0 : le flux d'après la 1.0.0 ne propose rien de plus récent (« No new update available! ») ; le flux d'après la 1.0.1, la signature remplacée par celle d'une autre clé, est refusé (erreur 4005, « The update is improperly signed and could not be validated ») et la copie reste en 1.0.0 ; le flux d'après la 1.0.1 la passe en 1.0.1, signature valide, avec la même exigence de signature qu'avant, et que celles des deux compilations (`identifier "<identifiant>" and certificate leaf = H"…"`). `repetition.sh` (tâche 10) refait tout cela d'un coup ; la tâche 12 le refait avec la vraie clé et le vrai certificat. Ce que seule une vraie session avec Djoko peut vérifier : la fenêtre de Sparkle, « Installer et relancer », l'app elle-même avec le runtime renforcé, l'installation de Thread Route et sa vue par les deux apps, le trousseau de Halo Compagnon après une mise à jour, et l'adresse brute de GitHub (tâches 13, 15 et 17).

**Faits établis** (Xcode 27, macOS 27, le 06/10) :
- **Sparkle 2.10.0** est la dernière version (13/09/2026) ; elle exige macOS 12. Son archive ne contient plus `sparkle-cli` (retiré en 2.9.0) : il se compile depuis la source de la même version (schéma `sparkle-cli`), signé ad hoc. `generate_keys` range toujours la clé dans le trousseau : la paire d'essai se fait par `openssl genpkey -algorithm ed25519`, la clé privée en base64 des 32 octets de la graine (le format de `sign_update --ed-key-file`), la publique en base64 des 32 octets.
- **Sparkle accepte une mise à jour ad hoc vers ad hoc**, et une mise à jour signée par le même certificat auto-signé : la signature Ed25519 passe, la copie mise à jour garde une signature valide (`codesign --verify --deep --strict`) et la même exigence de signature (`designated => identifier "<identifiant>" and certificate leaf = H"…"`), que celle de la 1.0.0 et de la 1.0.1.
- **Le commit du flux est public** : son auteur doit porter l'adresse noreply de GitHub. Un clone neuf n'a pas la configuration du dépôt de travail (`user.email`, l'adresse noreply) : il prendrait la configuration globale du Mac, une vraie adresse. `publication.py` refuse donc de publier si `git config user.email` ne finit pas par `@users.noreply.github.com` ; la tâche 15 pose la configuration dans chaque clone.
- **Un certificat auto-signé** signe sans être approuvé (`CSSMERR_TP_NOT_TRUSTED` dans `security find-identity`, et `0 valid identities`) : `codesign` l'accepte, avec `--keychain` pour un trousseau qui n'est pas dans la liste de recherche ; `publication.py` le cherche donc sans `-v`. Xcode signe déjà le code imbriqué de Sparkle (services XPC, `Updater.app`, `Autoupdate`) en ad hoc ; la publication le signe de nouveau, du plus profond au moins profond, avec `--preserve-metadata=entitlements` : les droits de chaque morceau restent. Tout le code porte le runtime renforcé (`flags=0x10000(runtime)`), compatible avec Sparkle et le bac à sable (la répétition l'a fait tourner par `sparkle-cli` ; l'app elle-même, en vrai, à la tâche 17).
- **`security create-keychain` ajoute le trousseau à la liste de recherche de la session.** Ses chemins ont des espaces : la remettre par le shell la casse (vu le 06/10, et réparée aussitôt). `trousseau-essai.py` la relit et la remet par Python, et vérifie qu'elle n'a pas changé.
- **La compilation de publication est universelle** (`arm64` et `x86_64`) : `-destination generic/platform=macOS`, en Release.
- **Xcode ajoute ses droits de test** (`com.apple.testmanagerd`…) au `mach-lookup` d'une compilation Debug : le test des droits ne compte que ceux qui ne commencent pas par `com.apple.`.
- **Halo Compagnon garde `GENERATE_INFOPLIST_FILE`** : l'Info.plist que génère XcodeGen (`info:`, ignoré par git) porte les clés de Sparkle, et Xcode y ajoute celles de `INFOPLIST_KEY_`.
- **`sparkle-cli` écrit `SULastCheckTime`** dans `~/Library/Preferences/<identifiant>.plist`, hors du conteneur, que les apps du bac à sable ne lisent pas ; la répétition met ces fichiers à la corbeille après coup.
- **Une compilation peut être interrompue de l'extérieur** (`** BUILD INTERRUPTED **`, ou `Terminated: 15`) quand une autre session compile en même temps : relancer la commande, en tâche de fond pour les longues.
- **`tools/macos/thread-route/tests.sh`** finit par un passage en essai qui lit les routes du Mac : sa sortie porte le vrai préfixe du réseau Thread. Elle va dans un fichier privé, dont on ne montre que les comptes.
- **`python3`** est, dans le shell de la session, celui de PlatformIO : les outils se lancent par `/usr/bin/python3`. Sous zsh, `echo ====` échoue : les séparateurs s'écrivent `== …`.

## Précisions

Ce sont les choix faits à l'écriture du plan, là où la spec et le brief laissaient la main ; Djoko a tranché ceux qu'il fallait le 06/10 (points 1, 4, 9 et 10).
1. **Thread Route, par le repli** (spec, section 2 ; décision de Djoko du 06/10) : installé par `installer.sh`, qui fait aussi la migration ; les deux apps montrent son état et la commande d'installation (`sh tools/macos/thread-route/installer.sh` dans Halo Compagnon, `sh outils/thread-route/installer.sh` dans Maillage Thread), et le bouton « Ouvrir Réglages Système… » quand il y est désactivé. Il n'y a qu'un démon, posé par l'installateur, que les deux apps voient pareil ; le quatrième cas est `halo-routes` encore installé. Une mise à jour d'une app n'apporte pas de nouvelle version du démon : on relance l'installateur.
2. **La copie conforme** : `outils/thread-route/` reçoit les fichiers de la source par `git archive` ; la révision notée (`outils/thread-route.source`) est l'arbre git du dossier source (`3e99d3ecc9a1473e8896adefbd4fdee6e4749745`), pas un commit : il ne dépend que du contenu. `outils/tests/test_thread_route.py` recalcule l'arbre de la copie et, si le dépôt du pont est sur le Mac (`DEPOT_HALO`), vérifie qu'il y existe.
3. **La clé publique provisoire.** Tant que la vraie clé n'existe pas, `CLE_MISES_A_JOUR` vaut une clé dont la moitié privée n'a jamais été gardée : une app qui la porte refuse toute mise à jour. La tâche 11 la remplace par la vraie ; `publier.sh` refuse de publier si la clé de `project.yml` n'est pas celle du trousseau.
4. **La version minimale du système dans `appcast.xml`** vient de `deploymentTarget` de chaque `project.yml` : 26.0 pour Maillage Thread, **15.0 pour Halo Compagnon** (décision de Djoko du 06/10 ; la spec le dit).
5. **Le moteur ne démarre pas en démo** dans Maillage Thread (la démo n'écrit ni ne notifie rien), comme sous les tests ; Halo Compagnon n'a pas de mode démo au lancement à part une source : il ne s'arrête que sous les tests.
6. **`publier.sh` compile ad hoc, puis signe par le certificat** : la compilation impose l'ad hoc en ligne de commande (`CODE_SIGN_IDENTITY=-`, `DEVELOPMENT_TEAM=` vide), si bien qu'une équipe d'un `Local.xcconfig` du poste n'entre jamais dans une version publiée ; puis `publication.py` signe le code imbriqué et l'app par `codesign`, avec l'identité de `IDENTITE_SIGNATURE` (par défaut `Djoko-cli Code Signing`), et écrit l'exigence de signature dans `exigence.txt`. Les publications se font depuis des clones neufs de GitHub (tâche 15), hors d'iCloud.
   **La notarisation, écrite et désactivée** (spec, section 7) : `NOTARISER=1` signe les codes avec horodatage, signe le `.dmg`, le soumet (`xcrun notarytool submit --wait`, profil `PROFIL_NOTARISATION`), l'agrafe (`xcrun stapler staple`) et l'évalue (`spctl --assess`), avant la signature Ed25519 (l'agrafe change le `.dmg`). Sans profil, elle s'arrête avant de compiler. Elle demande un Developer ID : avec le certificat auto-signé, Apple la refuserait.
7. **Les tests avant publication** : les suites des apps en français et en anglais, les tests Python, les tests hôte, ceux de Thread Route ; leur sortie va dans `build/publication/X.Y.Z/tests-N.log` (celle de Thread Route porte le préfixe du réseau : privée, jamais montrée).
8. **La remise sur le Bureau** est l'étape 8 de `publier.sh` ; la tâche 15 publie avec `--sans-bureau`, pour que la remise (tâche 16) ait son propre accord.
9. **Le flux dans le dépôt, les étiquettes par app** (décision de Djoko du 06/10) : chaque app lit `appcast.xml` à l'adresse brute du dépôt sur `main` ; ce flux garde toutes les versions publiées, la nouvelle en tête, et l'adresse de chaque `.dmg` est celle de sa version publiée, sous l'étiquette de l'app (`maillage-vX.Y.Z`, `compagnon-vX.Y.Z`) : une version du firmware, publiée un jour sur le même dépôt, n'y change rien. `publier.sh` commite le flux sur `main` (`git add` de ce seul fichier, message en français sans accents terminé par la ligne Co-Authored-By) après la version publiée, et le pousse aussitôt, après le contrôle d'anonymisation des fichiers et du message.
10. **Les textes nouveaux** passent par les catalogues, avec leur anglais (acceptés par Djoko le 06/10) : « Mises à jour » (Updates), « Rechercher les mises à jour… » (Check for Updates…), « Rechercher automatiquement » (Check for updates automatically), « Installer automatiquement » (Install updates automatically), « Thread Route », et les états et consignes de Thread Route.

## Global Constraints

- **Plateformes :** Maillage Thread en macOS 26.0 minimum, Halo Compagnon en macOS 15.0 ; développées avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`. Code : identifiants et commentaires en français **sans accents** ; textes affichés avec accents ; tests en Swift Testing (apps) et `unittest` (Python 3.9, `/usr/bin/python3`, sans dépendance).
- **Sparkle 2, à la version figée 2.10.0**, par le gestionnaire de paquets Swift (`exactVersion: 2.10.0`), depuis `https://github.com/sparkle-project/Sparkle` ; ses outils de la même version : l'archive `Sparkle-2.10.0.tar.xz` (SHA-256 `c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c`) et, pour `sparkle-cli`, la source de l'étiquette `2.10.0` (`cf43af1f26a921a8dc0be80834b9c3038bea5fd645708d26375126cbc57c316b`). Djoko a autorisé ces téléchargements le 06/10.
- **Valeurs de la spec,** à l'identique :
  - le flux, dans le dépôt, à son adresse brute sur `main` : `https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml` et `https://raw.githubusercontent.com/Djoko-cli/benq-screenbar-halo-matter/main/apps/macos/appcast.xml` ; il garde toutes les versions publiées, la nouvelle en tête ;
  - `SUScheduledCheckInterval` = 86400, `SUAutomaticallyUpdate`, `SUEnableAutomaticChecks`, `SUEnableInstallerLauncherService` ; les droits `<identifiant>-spks` et `<identifiant>-spki` ;
  - Thread Route : dossier `tools/macos/thread-route`, programme `thread-route`, étiquette `fr.djoko.thread.route` ;
  - les `.dmg` : `Maillage-Thread-X.Y.Z.dmg`, `Halo-Compagnon-X.Y.Z.dmg` ; les étiquettes propres à chaque app, `maillage-vX.Y.Z` et `compagnon-vX.Y.Z` ; l'adresse de chaque `.dmg` est celle de sa version publiée ; les premières versions 1.0.0 ; la version minimale du système : 26.0 pour Maillage Thread, 15.0 pour Halo Compagnon.
- **Signature :**
  - les compilations de travail et les tests restent ad hoc, comme aujourd'hui (`Signature.xcconfig`) ;
  - seule la compilation de publication (`publier.sh`) signe par le certificat auto-signé de Djoko, `Djoko-cli Code Signing` (nom neutre : ni nom, ni adresse, ni équipe ; 10 ans ; le même pour toutes ses apps), trouvé par son nom dans le trousseau au moment de publier. Le dépôt écrit ce nom, jamais une empreinte ;
  - **jamais de `Local.xcconfig`** ; aucun identifiant d'équipe, identifiant Apple, mot de passe ni adresse électronique dans un fichier commité ; la notarisation, désactivée, lit un profil du trousseau.
- **Trousseaux :** le trousseau de session de Djoko n'est jamais touché par les tests ni par un agent, hors des tâches 11, 12 et 15 (avec lui). Les essais de signature se font avec un certificat d'essai dans un trousseau à part, que `trousseau-essai.py` crée et détruit, et qui laisse la liste de recherche de la session telle qu'elle était.
- **Bac à sable gardé** dans les deux apps. Les tests n'écrivent jamais dans `UserDefaults.standard` (les préférences sont celles des apps de Djoko : même identifiant) ; ils ne démarrent jamais Sparkle et n'accèdent jamais au réseau.
- **Variables.** Le shell d'un agent ne garde pas ses variables d'une commande à l'autre : chaque commande porte les siennes. `$S` est le scratchpad de la session ; son chemin n'est écrit ni dans ce plan ni dans un commit (il contient le nom d'utilisateur).
  - `P=$HOME/Dev/maillage-thread/.superpowers/deploiement` : le dossier privé (ignoré par git)  ; `SB=$P/sparkle/bin` (`sign_update`, `generate_keys`) ; `CLI=$P/sparkle/sparkle.app/Contents/MacOS/sparkle` ;
  - `W=$S/deploiement-exec` : les worktrees, hors d'iCloud : `$W/maillage` (Maillage Thread) et `$W/halo` (pont Halo), sur la branche `deploiement` ;
  - `DDM=$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage`, `DDH=$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-halo` : les seuls dossiers de produits de ce plan (l'app de Djoko tourne depuis un autre) ; `TMPDIR=$HOME/Library/Caches/deploiement-exec/` ;
  - `AB=$HOME/Dev/maillage-thread/.superpowers/archives/polissage-c-sdd/appliquer-blocs.py` : l'outil des blocs.
- **Une fois, avant la tâche 1 :**

  ```bash
  P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec
  mkdir -p "$P" "$W" "$HOME/Library/Caches/deploiement-exec"
  git -C ~/Dev/maillage-thread show deploiement-brouillon:docs/superpowers/plans/2026-10-06-deploiement.md > "$P/plan.md"
  git -C ~/Dev/maillage-thread worktree add -q -b deploiement "$W/maillage" main
  git -C ~/Documents/Dev/esp32/benq worktree add -q -b deploiement "$W/halo" main
  git -C "$W/maillage" log --oneline -1; git -C "$W/halo" log --oneline -1
  ```

  Expected : `b5733c8 Ecrire la spec du deploiement…` et `8b854da Ecrire la spec du deploiement…`. Si `main` a avancé, les blocs s'appliquent tant que leur texte est le même ; sinon, l'exécutant applique le même changement au texte du moment et le dit.
- **Le brief d'une tâche** (pour `appliquer-blocs.py`) : `awk -v n=N '$0 ~ "^### Task " n ":" {f=1} f && $0 ~ "^### Task " n+1 ":" {f=0} f' "$P/plan.md" > "$P/brief-N.md"`. **Blocs :** un fichier existant change par blocs « remplacer … par … », ou en entier ; un fichier créé l'est tel quel. Les blocs d'une étape s'appliquent par `/usr/bin/python3 "$AB" "$P/brief-N.md" --etapes K`, **depuis la racine du dépôt concerné** : `$W/maillage` pour Maillage Thread, `$W/halo` pour le pont Halo (chemins depuis la racine du dépôt du pont, `apps/macos/…`), `~/Dev/maillage-thread` pour les fichiers privés de `.superpowers/deploiement/`. Chaque étape ne touche qu'un dépôt. Les catalogues (`.xcstrings`) et `outils/traductions/interface.json` ne changent que par les outils.
- **Les tests de Maillage Thread :** `DD="$DDM" TMPDIR="$HOME/Library/Caches/deploiement-exec/" outils/tester.sh [cibles…]`, depuis `$W/maillage` (journal dans `$TMPDIR/maillage-tests.log`) ; en anglais :

  ```bash
  cd "$W/maillage" && xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$DDM" -testLanguage en -testRegion US test > "$HOME/Library/Caches/deploiement-exec/maillage-en.log" 2>&1; grep -E "(error|warning): |✘|Test run with|\*\* TEST" "$HOME/Library/Caches/deploiement-exec/maillage-en.log" | grep -v -e appintentsmetadataprocessor -e "\[Connection\]"
  ```

- **Les tests de Halo Compagnon,** depuis `$W/halo/apps/macos` (jamais de `DerivedData` sous `~/Documents`) :

  ```bash
  cd "$W/halo/apps/macos" && xcodegen generate --quiet && xcodebuild -project HaloCompagnon.xcodeproj -scheme HaloCompagnon -destination 'platform=macOS' -derivedDataPath "$DDH" test > "$HOME/Library/Caches/deploiement-exec/halo-tests.log" 2>&1; echo "code $?"; grep -E "(error|warning): |✘|Test run with|\*\* TEST" "$HOME/Library/Caches/deploiement-exec/halo-tests.log" | grep -v -e appintentsmetadataprocessor -e "\[Connection\]"
  ```

  Une cible : `-only-testing:HaloCompagnonTests/ThreadRouteTests` avant `test` ; en anglais : `-testLanguage en -testRegion US` avant `test`.
- **Une suite à la fois** sur ce Mac ; une compilation interrompue de l'extérieur se relance (faits établis).
- **Données :** aucune donnée réelle (réseau, noms, prénom) dans un fichier commité ; les tests n'utilisent que des valeurs inventées. La sortie de `thread-route/tests.sh` va dans un fichier privé (`$P/…`), dont on ne montre que les comptes.
- **Commits :** un par tâche et par dépôt, en français sans accents, terminés par une ligne vide puis `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ; `git add` avec la liste de la tâche, jamais `-A` ni `.` ; l'auteur est celui de la configuration du dépôt (Djoko-cli, adresse noreply).
- **Étapes avec Djoko** (tâches 11 à 17) : le contrôleur décrit le geste, attend un oui clair dans la conversation, puis l'exécute ; un accord vaut pour un geste. Ce que macOS demande (mot de passe administrateur, approbation dans Réglages Système, accès au trousseau), c'est Djoko qui le donne.
- **Interdits** pour les agents :
  - `sudo`, le port série, le flashage ;
  - lancer Maillage Thread en mode direct (seulement en démo, pour ses images, et ses tests), réveiller l'écran, `screencapture`, quitter les apps de Djoko (pour arrêter une instance de ce plan : `kill` sur son PID) ;
  - un push, une étiquette poussée ou un `gh` qui modifie quelque chose hors des tâches 14 et 15 ;
  - toucher le trousseau de Djoko hors des tâches 11, 12 et 15 (par `generate_keys`, `sign_update`, `codesign` et `security`, avec lui) ; changer la liste de recherche des trousseaux par le shell.
- **Rien ne reste installé** hors de ce que Djoko accepte : Thread Route est installé par Djoko, par son installateur, à la tâche 13 ; aucune app n'inscrit de démon.
- **Commits faits à la demande de Djoko** (la clé, le plan, le flux) : poussés aussitôt, après le contrôle d'anonymisation des fichiers et des messages ; leur auteur porte l'adresse noreply de GitHub.
- **Disque :** environ 7 Go libres. Les DD, les caches et les produits de ce plan vont à la corbeille (`~/.Trash`) à la fin ; rien ne s'efface définitivement.

## Carte des fichiers

**Pont Halo** (`Djoko-cli/benq-screenbar-halo-matter`, chemins depuis la racine du dépôt) :

| Fichier | Rôle | Tâche |
|---|---|---|
| `tools/macos/thread-route/` (renommé depuis `tools/macos/halo-routes/`) : `thread-route.c` (depuis `halo-routes.c`), `fr.djoko.thread.route.plist` (depuis `fr.djoko.halo.routes.plist`), `logique.c`, `logique.h`, `test_logique.c` | le démon, au comportement inchangé ; noms, étiquette, journal | 2 |
| `tools/macos/thread-route/installer.sh`, `desinstaller.sh`, `tests.sh` | installation avec la migration (`--plan`) ; désinstallation ; tests de l'ordre de l'installation | 2 |
| `tools/macos/thread-route/README.md`, `README.fr.md` | Thread Route : installer, migrer, pourquoi pas par l'app | 2 |
| `README.md`, `README.fr.md`, `docs/PROTOCOLE-JSON.md`, `docs/PROTOCOLE-JSON.fr.md`, `docs/ETUDE-THREAD-COMPAGNON.md`, `docs/ETUDE-THREAD-COMPAGNON.fr.md` | le chemin et l'étiquette de Thread Route | 2 |
| `apps/macos/HaloCompagnon/Reseau/ThreadRoute.swift` (nouveau) | `EtatThreadRoute` : quatre cas, libellés, consignes | 3 |
| `apps/macos/HaloCompagnon/Reseau/AlerteReseau.swift` | le message « Pas de route » selon l'état | 3 |
| `apps/macos/HaloCompagnon/Vues/Reglages.swift` | Réglages, Général : sections « Mises à jour » et « Thread Route » | 3, 6 |
| `apps/macos/HaloCompagnon/Modele/MisesAJour.swift` (nouveau) | Sparkle : le moteur, le menu, les réglages | 6 |
| `apps/macos/HaloCompagnon/HaloCompagnonApp.swift` | le moteur au lancement ; le menu « Rechercher les mises à jour… » | 6 |
| `apps/macos/HaloCompagnon/HaloCompagnon.entitlements` | les droits `mach-lookup` de Sparkle | 6 |
| `apps/macos/project.yml`, `apps/macos/.gitignore` | Sparkle 2.10.0, l'Info.plist de XcodeGen (ignoré), la version 1.0.0, le flux, la clé | 6, 11 |
| `apps/macos/HaloCompagnon/Ressources/Localizable.xcstrings` | les textes nouveaux (par les outils) | 3, 6 |
| `apps/macos/HaloCompagnonTests/ThreadRouteTests.swift`, `MisesAJourTests.swift` (nouveaux), `PontReseauTests.swift` | l'état de Thread Route ; l'Info.plist, les droits, le moteur arrêté ; le message | 3, 6 |
| `apps/macos/Outils/publier.sh`, `publication.py`, `tests/test_publication.py` (nouveaux) | la publication, la signature par le certificat, la notarisation désactivée, et leurs tests | 8 |
| `apps/macos/NOTES-VERSIONS.md` (nouveau), `apps/macos/README.md`, `README.fr.md` | les notes de 1.0.0 ; installer, Gatekeeper, mises à jour, trousseau, Thread Route, publier ; le message « Pas de route » | 3, 9 |
| `docs/superpowers/specs/2026-10-06-deploiement-design.md` | la spec corrigée : signature par le certificat, flux dans le dépôt et étiquettes par app, Thread Route par son installateur, macOS 15 pour Halo Compagnon, distribution large | 9 |
| `apps/macos/appcast.xml` (nouveau, à la publication) | le flux des mises à jour, commité et poussé par `publier.sh` | 15 |

**Maillage Thread** (`Djoko-cli/maillage-thread`) :

| Fichier | Rôle | Tâche |
|---|---|---|
| `outils/thread-route/` (nouveau), `outils/thread-route.source` (nouveau) | la copie conforme de Thread Route et sa révision notée | 4 |
| `outils/synchroniser-thread-route.sh`, `outils/tests/test_thread_route.py` (nouveaux) | la copie, et son test | 4 |
| `MaillageThread/Surveillance/ThreadRoute.swift` (nouveau) | `EtatThreadRoute` (la commande de la copie de ce dépôt) | 4 |
| `MaillageThread/Vues/FenetreReglages.swift` | Réglages : Diagnostic, « Thread Route » ; Général, « Mises à jour » | 4, 5 |
| `MaillageCoeur/Systeme/TableRoutage.swift` | un commentaire : Thread Route | 4 |
| `MaillageThread/Surveillance/MisesAJour.swift` (nouveau) | Sparkle : le moteur, le menu, les réglages | 5 |
| `MaillageThread/MaillageThreadApp.swift`, `Vues/ControleurReglages.swift`, `Vues/MenuBarre.swift` | le moteur au lancement, passé aux Réglages et au menu ; « Rechercher les mises à jour… » | 5 |
| `MaillageThread/Droits.entitlements`, `project.yml` | les droits de Sparkle ; Sparkle 2.10.0, l'Info.plist, la version 1.0.0, le flux, la clé | 5, 11 |
| `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json` | les textes nouveaux (par les outils) | 4, 5 |
| `MaillageThreadTests/ThreadRouteTests.swift`, `MisesAJourTests.swift` (nouveaux) | l'état de Thread Route ; l'Info.plist, les droits, le moteur arrêté | 4, 5 |
| `outils/publier.sh`, `outils/publication.py`, `outils/tests/test_publication.py` (nouveaux) | la publication, la signature par le certificat, la notarisation désactivée, et leurs tests | 7 |
| `NOTES-VERSIONS.md` (nouveau), `README.md`, `README.fr.md` | les notes de 1.0.0 ; installer, Gatekeeper, mises à jour, Thread Route, passeur, publier | 9 |
| `docs/superpowers/specs/2026-10-06-deploiement-design.md` | la spec corrigée, identique à celle du pont | 9 |
| `docs/superpowers/plans/2026-10-06-deploiement.md` | ce plan, ajouté à la branche avant la fusion | 14 |
| `appcast.xml` (nouveau, à la publication) | le flux des mises à jour, commité et poussé par `publier.sh` | 15 |

**Privé** (`$P`, jamais commité) :

| Fichier | Rôle | Tâche |
|---|---|---|
| `sparkle/` | l'archive de Sparkle 2.10.0 (`bin/`), `sparkle.app` (`sparkle-cli`) | 10 |
| `repetition.sh`, `cle-essai/` | la répétition, la paire d'essai et l'autre clé d'essai | 10, 12 |
| `trousseau-essai.py`, `certificat-essai/` | le certificat d'essai, dans un trousseau à part, créé puis détruit | 10 |

---

### Task 1: L'état de départ

**Files :** aucun.

**Interfaces:**
- Consumes : rien.
- Produces : l'état de `halo-routes` sur ce Mac (tâche 13), et la preuve que rien n'est encore publié ni étiqueté.

Thread Route est installé par son installateur (décision de Djoko du 06/10, après l'essai : « La préparation du 06/10 ») ; aucune tâche de ce plan n'inscrit de démon par une app.

- [ ] **Step 1 : ce qui tourne, ce qui est publié.**

```bash
launchctl print system/fr.djoko.halo.routes 2>&1 | grep -m1 -E "^\s+state = |Could not find"; launchctl print system 2>/dev/null | grep -c "fr.djoko.thread.route"; for d in ~/Dev/maillage-thread ~/Documents/Dev/esp32/benq; do git -C "$d" status --short | wc -l; git -C "$d" tag -l | wc -l; done; for r in maillage-thread benq-screenbar-halo-matter; do gh release list -R Djoko-cli/$r | wc -l; done
```

Expected : `state = running` (sinon `Could not find service` : la tâche 13 n'aura rien à migrer) ; `0` (Thread Route n'est pas encore là) ; `0` et `0` pour chaque dépôt de travail (propre, sans étiquette) ; `0` et `0` (aucune version publiée).

Pas de commit.

---

### Task 2: Thread Route : le renommage, et la migration depuis halo-routes (pont Halo)

**Files :**
- Rename : `tools/macos/halo-routes/` → `tools/macos/thread-route/` ; `halo-routes.c` → `thread-route.c` ; `fr.djoko.halo.routes.plist` → `fr.djoko.thread.route.plist`
- Modify (par `sed`) : `thread-route.c`, `logique.c`, `logique.h`, `test_logique.c`, `fr.djoko.thread.route.plist` ; `README.md`, `README.fr.md`, `apps/macos/README.md`, `apps/macos/README.fr.md`, `docs/PROTOCOLE-JSON.md`, `docs/PROTOCOLE-JSON.fr.md`, `docs/ETUDE-THREAD-COMPAGNON.md`, `docs/ETUDE-THREAD-COMPAGNON.fr.md`
- Modify (fichiers entiers) : `tools/macos/thread-route/tests.sh`, `installer.sh`, `desinstaller.sh`, `README.md`, `README.fr.md`

**Interfaces:**
- Consumes : rien.
- Produces :
  - `sh tools/macos/thread-route/installer.sh [--plan]` : avec `--plan`, l'installation, une action par ligne, sans rien changer ; `THREAD_ROUTE_RACINE` pose une fausse racine (tests). Sans `--plan` : compilation, tests, essai, puis les actions par `sudo` (par Djoko seulement) ;
  - les chemins `/Library/PrivilegedHelperTools/fr.djoko.thread.route`, `/Library/LaunchDaemons/fr.djoko.thread.route.plist`, `/Library/Logs/fr.djoko.thread.route.log` (tâches 3, 4 et 13).

Le comportement du démon ne change pas : seuls ses noms changent. L'installateur gagne la migration ; la désinstallation retire aussi un `halo-routes` resté.

- [ ] **Step 1 : renommer,** depuis `$W/halo`.

```bash
W=$S/deploiement-exec; cd "$W/halo" && git mv tools/macos/halo-routes tools/macos/thread-route && git mv tools/macos/thread-route/halo-routes.c tools/macos/thread-route/thread-route.c && git mv tools/macos/thread-route/fr.djoko.halo.routes.plist tools/macos/thread-route/fr.djoko.thread.route.plist && (cd tools/macos/thread-route && sed -i '' -e 's/fr\.djoko\.halo\.routes/fr.djoko.thread.route/g' -e 's/halo-routes/thread-route/g' thread-route.c logique.c logique.h test_logique.c fr.djoko.thread.route.plist) && git status --short | wc -l
```

Expected : `10` (sept renommés, dont trois changés, et les trois scripts).

- [ ] **Step 2 : le test de l'installation, d'abord** (`--etapes 2`). Il vérifie, sur une fausse racine, que l'ancien démon est arrêté et retiré avant que le nouveau soit posé ; il ne lance jamais un installateur qui ne connaît pas `--plan`.

`tools/macos/thread-route/tests.sh`, fichier entier :

```sh
#!/bin/sh
# Tests de Thread Route sans rien installer : decision (test_logique.c), ordre de l'installation et
# de la migration depuis halo-routes (installer.sh --plan, sur une fausse racine), puis compilation
# du demon et un passage en essai (-n : lit le noyau, ne change rien).
#   sh tests.sh
set -eu
cd "$(dirname "$0")"
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
clang -std=c11 -Wall -Wextra -Werror -o "$OUT/test_logique" logique.c test_logique.c
"$OUT/test_logique"

# Installation : l'ancien demon (halo-routes) est arrete et retire avant que le nouveau soit pose.
R="$OUT/racine"
mkdir -p "$R/Library/LaunchDaemons" "$R/Library/PrivilegedHelperTools"
# Jamais une vraie installation depuis les tests : un installateur sans --plan n'est pas lance.
plan() {
  if grep -q -e '--plan' installer.sh; then THREAD_ROUTE_RACINE="$R" sh installer.sh --plan; else echo "installer.sh sans --plan"; fi
}
attendu_neuf="launchctl bootout system/fr.djoko.thread.route
install -d -m 1755 -o root -g wheel $R/Library/PrivilegedHelperTools
install -m 755 -o root -g wheel <programme compile> $R/Library/PrivilegedHelperTools/fr.djoko.thread.route
install -m 644 -o root -g wheel fr.djoko.thread.route.plist $R/Library/LaunchDaemons/fr.djoko.thread.route.plist
launchctl bootstrap system $R/Library/LaunchDaemons/fr.djoko.thread.route.plist"
attendu_migration="launchctl bootout system/fr.djoko.halo.routes
rm -f $R/Library/PrivilegedHelperTools/fr.djoko.halo.routes $R/Library/LaunchDaemons/fr.djoko.halo.routes.plist
$attendu_neuf"
VERIFS=0
ECHECS=0
verifier() {
  VERIFS=$((VERIFS + 1))
  if [ "$2" != "$3" ]; then
    ECHECS=$((ECHECS + 1))
    printf 'ECHEC installation (%s) :\n%s\n-- attendu :\n%s\n' "$1" "$2" "$3"
  fi
}
verifier "sans ancien demon" "$(plan)" "$attendu_neuf"
touch "$R/Library/LaunchDaemons/fr.djoko.halo.routes.plist" "$R/Library/PrivilegedHelperTools/fr.djoko.halo.routes"
verifier "migration depuis halo-routes" "$(plan)" "$attendu_migration"
rm "$R/Library/LaunchDaemons/fr.djoko.halo.routes.plist"
verifier "ancien programme seul" "$(plan)" "$attendu_migration"
rm "$R/Library/PrivilegedHelperTools/fr.djoko.halo.routes"
touch "$R/Library/LaunchDaemons/fr.djoko.halo.routes.plist"
verifier "ancien plist seul" "$(plan)" "$attendu_migration"
echo "installation : $VERIFS verification(s), $ECHECS echec(s)"
[ "$ECHECS" -eq 0 ]

clang -std=c11 -O2 -Wall -Wextra -Werror -o "$OUT/thread-route" thread-route.c logique.c
"$OUT/thread-route" -n -1 -v
```

- [ ] **Step 3 : le voir échouer.**

Run : `P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec; cd "$W/halo" && sh tools/macos/thread-route/tests.sh > "$P/thread-route-rouge.txt" 2>&1; echo "code $?"; grep -E "verification\(s\)" "$P/thread-route-rouge.txt"`

Expected : `code 1` ; `thread-route : 47 verification(s), 0 echec(s)` ; `installation : 4 verification(s), 4 echec(s)` (l'ancien installateur n'a pas `--plan`).

- [ ] **Step 4 : l'installateur et la désinstallation** (`--etapes 4`).

`tools/macos/thread-route/installer.sh`, fichier entier :

```sh
#!/bin/sh
# Installe Thread Route : demon launchd (root) qui garde la route du reseau Thread sur ce Mac
# (README.md). A lancer sous son compte, sans sudo : le programme est compile et teste ici, seules
# la copie et la mise en service demandent le mot de passe administrateur.
#   sh installer.sh          (depuis ce dossier, ou avec son chemin)
#   sh installer.sh --plan   n'installe rien : dit, dans l'ordre, ce que l'installation ferait
# L'ancien demon, halo-routes (fr.djoko.halo.routes), est arrete et retire avant que Thread Route
# soit pose : les deux ne tournent jamais ensemble. Son journal est garde.
set -eu
cd "$(dirname "$0")"
ETIQ=fr.djoko.thread.route
ANCIEN=fr.djoko.halo.routes
# Pour les tests (tests.sh) : une fausse racine, avec --plan.
RACINE=${THREAD_ROUTE_RACINE:-}
BIN=$RACINE/Library/PrivilegedHelperTools/$ETIQ
PLIST=$RACINE/Library/LaunchDaemons/$ETIQ.plist
JOURNAL=/Library/Logs/$ETIQ.log
PLAN=0
[ "${1:-}" = "--plan" ] && PLAN=1

# Une action d'administrateur : ecrite avec --plan, faite par sudo sinon.
faire() {
  if [ "$PLAN" -eq 1 ]; then echo "$*"; else sudo "$@"; fi
}

# L'installation, dans l'ordre. $1 : le programme compile.
installer() {
  if [ -e "$RACINE/Library/LaunchDaemons/$ANCIEN.plist" ] || [ -e "$RACINE/Library/PrivilegedHelperTools/$ANCIEN" ]; then
    faire launchctl bootout "system/$ANCIEN" 2>/dev/null || true
    faire rm -f "$RACINE/Library/PrivilegedHelperTools/$ANCIEN" "$RACINE/Library/LaunchDaemons/$ANCIEN.plist"
  fi
  faire launchctl bootout "system/$ETIQ" 2>/dev/null || true
  [ "$PLAN" -eq 0 ] && [ -d "$RACINE/Library/PrivilegedHelperTools" ] ||
    faire install -d -m 1755 -o root -g wheel "$RACINE/Library/PrivilegedHelperTools"
  faire install -m 755 -o root -g wheel "$1" "$BIN"
  faire install -m 644 -o root -g wheel "$ETIQ.plist" "$PLIST"
  faire launchctl bootstrap system "$PLIST"
}

if [ "$PLAN" -eq 1 ]; then
  installer "<programme compile>"
  exit 0
fi

if [ "$(id -u)" -eq 0 ]; then
  echo "A lancer sans sudo (le mot de passe sera demande pour l'installation seulement)." >&2
  exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "Compilation et tests..."
clang -std=c11 -Wall -Wextra -Werror -o "$TMP/test_logique" logique.c test_logique.c
"$TMP/test_logique"
clang -std=c11 -O2 -Wall -Wextra -Werror -o "$TMP/thread-route" thread-route.c logique.c
echo "Ce que Thread Route ferait maintenant (essai, rien n'est change) :"
if ! "$TMP/thread-route" -n -1 -v > "$TMP/essai.txt" 2>&1; then
  sed 's/^/  /' "$TMP/essai.txt"
  echo "L'essai a echoue : rien n'est installe." >&2
  exit 1
fi
sed 's/^/  /' "$TMP/essai.txt"

echo "Installation (mot de passe administrateur)..."
installer "$TMP/thread-route"
echo "Installe : $BIN (journal : $JOURNAL)"

# Une route posee a la main pour un prefixe annonce reste a son proprietaire : Thread Route ne la
# garde pas. La signaler.
# (prefixe ULA /64 via un routeur en lien local, statique, sans la marque 1 de Thread Route)
netstat -rn -f inet6 | awk '$1 ~ /^f[cd][0-9a-f][0-9a-f]:.*\/64$/ && $2 ~ /^fe80:/ && $3 ~ /S/ && $3 !~ /1/ {print $1, $2}' |
while read -r dst gw; do
  echo "Route posee a la main : $dst via $gw. Pour que Thread Route en prenne la garde :"
  echo "  sudo route -n delete -inet6 -prefixlen 64 ${dst%/64}"
done
```

`tools/macos/thread-route/desinstaller.sh`, fichier entier :

```sh
#!/bin/sh
# Desinstalle Thread Route (et halo-routes, son ancien nom, s'il reste). A l'arret, le demon retire
# les routes qu'il avait posees ; les routes du noyau et celles posees a la main restent.
#   sh desinstaller.sh
set -eu
for ETIQ in fr.djoko.thread.route fr.djoko.halo.routes; do
  sudo launchctl bootout "system/$ETIQ" 2>/dev/null || true
  sudo rm -f "/Library/PrivilegedHelperTools/$ETIQ" "/Library/LaunchDaemons/$ETIQ.plist"
done
echo "Desinstalle (journal garde : /Library/Logs/fr.djoko.thread.route.log)"
```

- [ ] **Step 5 : le voir passer.** La fin de la sortie est le passage en essai, qui porte le préfixe du réseau : elle reste dans le fichier privé.

Run : `P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec; cd "$W/halo" && sh tools/macos/thread-route/tests.sh > "$P/thread-route-vert.txt" 2>&1; echo "code $?"; grep -E "verification\(s\)" "$P/thread-route-vert.txt"; THREAD_ROUTE_RACINE=/tmp/aucune sh tools/macos/thread-route/installer.sh --plan | head -2`

Expected : `code 0` ; `thread-route : 47 verification(s), 0 echec(s)` ; `installation : 4 verification(s), 0 echec(s)` ; puis `launchctl bootout system/fr.djoko.thread.route` et `install -d -m 1755 -o root -g wheel /tmp/aucune/Library/PrivilegedHelperTools`.

- [ ] **Step 6 : les README de Thread Route** (`--etapes 6`), sans bloc de code clôturé : leurs commandes sont en retrait, et se lancent depuis le dossier, dans un dépôt comme dans l'autre.

`tools/macos/thread-route/README.md`, fichier entier :

```markdown
[Français](README.fr.md) · **English**

# Thread Route: the Mac's system helper for the Thread network

A launchd daemon (root) that keeps the Mac's route to the Thread network: to
the Halo bridge over UDP (docs/PROTOCOLE-JSON.md, section 10, in the Halo
bridge repository) and to Maillage Thread's probe over "Thread Network". It
was called `halo-routes` (`fr.djoko.halo.routes`) until Oct 6, 2026.

Its source lives in the Halo bridge repository (`tools/macos/thread-route`);
Maillage Thread keeps an identical copy (`outils/thread-route`). The commands
below run from this folder.

## Why

The Mac reaches Thread nodes through the OMR prefix (a `/64` ULA) that
border routers (HomePod, Apple TV) advertise on the LAN (the RIO option of
router advertisements). macOS kernel bug (10.1): it removes the route for
this prefix when it switches routers (one of them looks briefly
unreachable, or its advertisement expires), but its list of advertised
routes may still believe it's in place. The route then never gets put
back: `No route to host` until the interface restarts, sometimes even
longer. A static route holds up better, but it takes root to set one, and
an app can't choose its own outbound router on its own.

## What it does

On every kernel message about routes (300 ms later, to debounce bursts)
and every 10 s (a lost router doesn't trigger any message), it re-reads
the kernel's list of advertised routes
(`sysctl net.inet6.icmp6.nd6_rtilist`), the state of the routers (neighbor
cache), and that of the interfaces. For each advertised ULA `/64` prefix:

- no route: it sets one, static, marked `RTF_PROTO1` (flag `1` in
  `netstat -rn`), via the safest router: reachable first (neighbor
  `REACHABLE`, `STALE`, `DELAY`, or `PROBE`, as judged by the kernel), then
  the one the kernel believes it has installed (if that one goes down, the
  kernel itself removes the route and sets its own), then on the main
  interface; never through a downed interface;
- our route goes through a router that no longer advertises the prefix: it
  switches routers; through a router that's unreachable (or whose
  interface is down) while another is reachable: it also switches, if
  that's confirmed over two passes at least 2 s apart. The switch happens
  in place (`route change`: gateway and interface, with no drop); failing
  that, removal then re-addition;
- no more advertisement at all: it removes our route (the advertisement
  having expired, the kernel wouldn't have a route either).

The static route isn't safe from this: when the kernel switches routers or
an advertisement expires, it removes the route for the prefix, whichever
one it is (by prefix and mask), and generally sets its own; otherwise, the
daemon puts its own back on the next pass. At most 6 changes per prefix
per minute; after a failure, nothing before the next minute. On stopping
(`launchctl bootout`, uninstall), it removes the routes it set.

## What it doesn't do

- It doesn't touch any route that isn't its own: the kernel's, ones set by
  hand, and any prefix outside `fc00::/7` or with a length other than 64.
  It only sets what the kernel would have set itself for an advertisement
  it accepted.
- No input from outside the kernel: no network port, no command file, no
  runtime argument. Changes go through `/sbin/route`, with fixed argv, no
  shell.
- The Thread network's prefix isn't hardcoded: if it changes, the daemon
  follows the advertisements.

## Installing

Under your own account, without sudo (the program is built and tested
here; only copying it into place and putting it into service require the
administrator password):

    sh installer.sh

The installer first shows what the daemon would do (a dry run, nothing is
changed). A route set by hand for the same prefix stays with its owner:
the daemon leaves it in place and doesn't take it over. The installer
flags it; remove it for the daemon to take over managing it
(`sudo route -n delete -inet6 -prefixlen 64 <prefixe>`).

**From halo-routes.** The installer first stops and removes the old daemon
(`fr.djoko.halo.routes`, its program and its plist), then puts Thread Route
in place: the two never run together. The old log
(`/Library/Logs/fr.djoko.halo.routes.log`) is kept. `sh installer.sh --plan`
tells, without changing anything, what the installation would do.

**Updating.** A new version of Thread Route installs the same way, by running
`installer.sh` again: an app's automatic update doesn't touch it.

**Why not from the app.** Halo Compagnon and Maillage Thread stay in the
macOS sandbox. Trial of Oct 6, 2026: `SMAppService` refuses to register a
daemon there that isn't sandboxed itself ("SMAppService target executable
must be sandboxed because the app is sandboxed"), and a sandboxed daemon
couldn't keep the routes. Both apps therefore only read its status
(`SMAppService.statusForLegacyPlist`, which the sandbox allows): absent, to
approve, active, or halo-routes still there.

Files: `/Library/PrivilegedHelperTools/fr.djoko.thread.route` (the
program), `/Library/LaunchDaemons/fr.djoko.thread.route.plist` (launches at
startup, restarts if it stops), `/Library/Logs/fr.djoko.thread.route.log`
(log).

## Checking

    tail -f /Library/Logs/fr.djoko.thread.route.log
    netstat -rn -f inet6 | grep '^fd'

A route set by the daemon carries the `S` (static) and `1` (its own
marker) flags. macOS also shows it in System Settings, General, Login Items
& Extensions, "Allow in the Background": turned off there, it no longer runs
("to approve" in the apps). A dry run with nothing installed or changed (no
need to be root); its output shows the Thread network's prefix:

    sh tests.sh

## Uninstalling

    sh desinstaller.sh

The daemon removes its routes as it stops; the log is kept. A leftover
`halo-routes` is removed too.

## Limitations

- Killed without a chance to clean up (SIGKILL), it picks its routes back
  up on restart as long as their prefix is still advertised; a route whose
  prefix has since disappeared stays until the Mac reboots.
- A small race: between its reading of the table and a removal or a
  change, the kernel may set its own route for the prefix; `route` targets
  the prefix and mask without checking who owns the route, and would then
  touch the kernel's own (the next pass puts a route back if needed).
- At most 32 ULA `/64` prefixes tracked (and 32 routers per prefix):
  beyond that, the extra prefixes are ignored, and as long as the list
  overflows, the daemon stops removing its routes for lack of an
  advertisement; the log flags it.
- The log isn't rotated: a few lines per kernel incident.
- Works around the bug, doesn't fix it: without the daemon, the kernel's
  route can still disappear.
```

`tools/macos/thread-route/README.fr.md`, fichier entier :

```markdown
**Français** · [English](README.md)

# Thread Route : assistant systeme du Mac pour le reseau Thread

Demon launchd (root) qui garde la route du Mac vers le reseau Thread : vers le
pont Halo en UDP (docs/PROTOCOLE-JSON.md, section 10, dans le depot du pont
Halo) et vers la sonde de Maillage Thread par « Reseau Thread ». Il s'appelait
`halo-routes` (`fr.djoko.halo.routes`) jusqu'au 06/10/2026.

Sa source est dans le depot du pont Halo (`tools/macos/thread-route`) ;
Maillage Thread en garde une copie a l'identique (`outils/thread-route`). Les
commandes ci-dessous se lancent depuis ce dossier.

## Pourquoi

Le Mac joint les noeuds Thread par le prefixe OMR (ULA `/64`) que les routeurs
de bordure (HomePod, Apple TV) annoncent sur le LAN (option RIO des annonces de
routeur). Bug du noyau de macOS (10.1) : il retire la route de ce prefixe quand
il change de routeur (l'un d'eux parait un instant injoignable, ou son annonce
expire), mais sa liste des routes annoncees peut la croire toujours posee. La
route n'est alors plus remise : `No route to host` jusqu'au redemarrage de
l'interface, parfois au-dela. Une route statique tient mieux, mais il faut etre
root pour la poser, et une app ne peut pas choisir seule son routeur de sortie.

## Ce qu'il fait

A chaque message du noyau sur les routes (300 ms apres, les rafales sont
fondues) et toutes les 10 s (un routeur perdu ne donne lieu a aucun message), il
relit la liste des routes annoncees du noyau
(`sysctl net.inet6.icmp6.nd6_rtilist`), l'etat des routeurs (cache des voisins)
et celui des interfaces. Pour chaque prefixe ULA `/64` annonce :

- aucune route : il en pose une, statique, marquee `RTF_PROTO1` (drapeau `1`
  dans `netstat -rn`), via le routeur le plus sur : joignable d'abord (voisin
  `REACHABLE`, `STALE`, `DELAY` ou `PROBE`, comme en juge le noyau), puis celui
  que le noyau croit avoir installe (s'il tombe, le noyau retire lui-meme la
  route et pose la sienne), puis sur l'interface principale ; jamais via une
  interface tombee ;
- notre route passe par un routeur qui n'annonce plus le prefixe : il change de
  routeur ; par un routeur injoignable (ou dont l'interface est tombee) alors
  qu'un autre est joignable : il change aussi, si c'est confirme a deux passages
  espaces de 2 s au moins. Le changement se fait sur place (`route change` :
  passerelle et interface, sans coupure) ; a defaut, retrait puis ajout ;
- plus aucune annonce : il retire notre route (l'annonce expiree, le noyau
  n'aurait plus de route non plus).

La route statique n'est pas a l'abri : quand le noyau change de routeur ou
qu'une annonce expire, il retire la route du prefixe, quelle qu'elle soit (par
prefixe et masque), et pose en general la sienne ; sinon, le demon remet la
sienne au passage suivant. Au plus 6 changements par prefixe et par minute ;
apres un echec, rien avant la minute suivante. A l'arret (`launchctl bootout`,
desinstallation), il retire les routes qu'il a posees.

## Ce qu'il ne fait pas

- Il ne touche a aucune route qui n'est pas a lui : celles du noyau, celles
  posees a la main, et tout prefixe hors de `fc00::/7` ou d'une autre longueur
  que 64. Il ne pose que ce que le noyau aurait pose lui-meme pour une annonce
  qu'il a acceptee.
- Aucune entree hors du noyau : ni port reseau, ni fichier de commande, ni
  argument a l'execution. Les changements passent par `/sbin/route`, argv
  fixe, sans shell.
- Le prefixe du reseau Thread n'est pas ecrit en dur : s'il change, le demon
  suit les annonces.

## Installer

Sous son compte, sans sudo (le programme est compile et teste ici ; seules la
copie et la mise en service demandent le mot de passe administrateur) :

    sh installer.sh

L'installeur montre d'abord ce que le demon ferait (essai, rien n'est change).
Une route posee a la main pour le meme prefixe reste a son proprietaire : le
demon la laisse en place et ne la garde pas. L'installeur la signale ; la
retirer pour qu'il en prenne la garde (`sudo route -n delete -inet6
-prefixlen 64 <prefixe>`).

**Depuis halo-routes.** L'installeur arrete et retire d'abord l'ancien demon
(`fr.djoko.halo.routes`, son programme et son plist), puis pose Thread Route :
les deux ne tournent jamais ensemble. L'ancien journal
(`/Library/Logs/fr.djoko.halo.routes.log`) est garde. `sh installer.sh --plan`
dit, sans rien changer, ce que l'installation ferait.

**Mise a jour.** Une nouvelle version de Thread Route s'installe de meme, en
relancant `installer.sh` : la mise a jour automatique d'une app ne le touche
pas.

**Pourquoi pas par l'app.** Halo Compagnon et Maillage Thread restent dans le
bac a sable de macOS. Essai du 06/10/2026 : `SMAppService` refuse d'y inscrire
un demon qui n'est pas lui-meme dans le bac a sable (« SMAppService target
executable must be sandboxed because the app is sandboxed »), et un demon dans
le bac a sable ne pourrait pas garder les routes. Les deux apps lisent donc
seulement son etat (`SMAppService.statusForLegacyPlist`, que permet le bac a
sable) : absent, a approuver, actif, ou halo-routes encore la.

Fichiers : `/Library/PrivilegedHelperTools/fr.djoko.thread.route` (programme),
`/Library/LaunchDaemons/fr.djoko.thread.route.plist` (lancement au demarrage,
relance s'il s'arrete), `/Library/Logs/fr.djoko.thread.route.log` (journal).

## Verifier

    tail -f /Library/Logs/fr.djoko.thread.route.log
    netstat -rn -f inet6 | grep '^fd'

Une route du demon porte les drapeaux `S` (statique) et `1` (sa marque).
macOS le montre aussi dans Reglages Systeme, General, Ouverture et extensions,
« Autoriser en arriere-plan » : desactive la, il ne tourne plus (« a
approuver » dans les apps). Essai sans rien installer ni changer (pas besoin
d'etre root) ; sa sortie porte le prefixe du reseau Thread :

    sh tests.sh

## Desinstaller

    sh desinstaller.sh

Le demon retire ses routes en s'arretant ; le journal est garde. Un
`halo-routes` reste est retire aussi.

## Limites

- Tue sans pouvoir se nettoyer (SIGKILL), il reprend ses routes a la relance
  tant que leur prefixe est annonce ; une route dont le prefixe a disparu
  entre-temps reste jusqu'au redemarrage du Mac.
- Course minime : entre sa lecture de la table et un retrait ou un changement,
  le noyau peut poser sa propre route pour le prefixe ; `route` vise le prefixe
  et le masque sans regarder a qui est la route, et toucherait alors celle du
  noyau (le passage suivant remet une route si besoin).
- Au plus 32 prefixes ULA `/64` suivis (et 32 routeurs par prefixe) : au-dela,
  les prefixes en trop sont ignores et, tant que la liste deborde, le demon ne
  retire plus ses routes faute d'annonce ; le journal le signale.
- Le journal n'est pas tourne : quelques lignes par incident du noyau.
- Contourne le bug, ne le corrige pas : sans demon, la route du noyau peut
  toujours disparaitre.
```

- [ ] **Step 7 : le chemin et l'étiquette dans la documentation du pont.**

```bash
W=$S/deploiement-exec; cd "$W/halo" && sed -i '' -e 's|tools/macos/halo-routes/  |tools/macos/thread-route/ |' -e 's|tools/macos/halo-routes|tools/macos/thread-route|g' -e 's|fr\.djoko\.halo\.routes|fr.djoko.thread.route|g' README.md README.fr.md apps/macos/README.md apps/macos/README.fr.md docs/PROTOCOLE-JSON.md docs/PROTOCOLE-JSON.fr.md docs/ETUDE-THREAD-COMPAGNON.md docs/ETUDE-THREAD-COMPAGNON.fr.md && git grep -l "halo-routes\|halo\.routes" -- . ':!docs/superpowers'
```

Expected : seulement `apps/macos/HaloCompagnon/Reseau/AlerteReseau.swift` et `apps/macos/HaloCompagnon/Ressources/Localizable.xcstrings` (tâche 3), et dans `tools/macos/thread-route/` : `README.fr.md`, `README.md`, `desinstaller.sh`, `installer.sh`, `tests.sh` (l'ancien nom, pour la migration).

- [ ] **Step 8 : commit.**

```bash
W=$S/deploiement-exec; cd "$W/halo" && git add tools/macos README.md README.fr.md apps/macos/README.md apps/macos/README.fr.md docs/PROTOCOLE-JSON.md docs/PROTOCOLE-JSON.fr.md docs/ETUDE-THREAD-COMPAGNON.md docs/ETUDE-THREAD-COMPAGNON.fr.md && git commit -q -F - <<'EOF'
Renommer halo-routes en Thread Route : l'installateur retire l'ancien demon avant de poser le nouveau

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git rev-parse HEAD:tools/macos/thread-route
```

Expected : `3e99d3ecc9a1473e8896adefbd4fdee6e4749745` (l'arbre de Thread Route, noté par la copie de Maillage Thread à la tâche 4).

---

### Task 3: L'état de Thread Route dans Halo Compagnon

**Files :**
- Create : `apps/macos/HaloCompagnon/Reseau/ThreadRoute.swift`, `apps/macos/HaloCompagnonTests/ThreadRouteTests.swift`
- Modify : `apps/macos/HaloCompagnon/Reseau/AlerteReseau.swift`, `apps/macos/HaloCompagnon/Vues/Reglages.swift`, `apps/macos/HaloCompagnonTests/PontReseauTests.swift`, `apps/macos/README.md`, `apps/macos/README.fr.md` (blocs) ; `apps/macos/HaloCompagnon/Ressources/Localizable.xcstrings` (outils)

**Interfaces:**
- Consumes : les chemins des plists de Thread Route et de `halo-routes` (tâche 2).
- Produces :
  - `enum EtatThreadRoute: Equatable, Sendable { case absent, aApprouver, actif, ancien }` ; `static let plist`, `plistAncien: URL` ; `static func depuis(nouveau: SMAppService.Status, ancien: SMAppService.Status) -> EtatThreadRoute` ; `static func lire() -> EtatThreadRoute` ; `var libelle: String` ; `var consigne: String?` (nil quand il est actif) ;
  - `AlerteReseau.textePasDeRoute(_ etat: EtatThreadRoute) -> String` (remplace `textePasDeRoute(assistant:)`) ;
  - `struct SectionThreadRoute: View`, dans l'onglet Général des Réglages.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`, depuis `$W/halo`).

`apps/macos/HaloCompagnonTests/ThreadRouteTests.swift` :

```swift
import Foundation
import ServiceManagement
import Testing
@testable import HaloCompagnon

/// L'etat de Thread Route, lu de ce que le systeme dit de ses deux plists : le sien et celui de
/// halo-routes, son ancien nom. Seulement la decision, sur des etats donnes : l'etat reel depend du Mac.
@Suite("Thread Route : son etat", .langue(.francais))
struct ThreadRouteTests {
    /// Les quatre cas : absent, a approuver, actif, ancien.
    @Test func quatreCas() {
        #expect(EtatThreadRoute.depuis(nouveau: .notRegistered, ancien: .notRegistered) == .absent)
        #expect(EtatThreadRoute.depuis(nouveau: .notFound, ancien: .notFound) == .absent)
        #expect(EtatThreadRoute.depuis(nouveau: .requiresApproval, ancien: .notRegistered) == .aApprouver,
                "desactive dans Reglages Systeme")
        #expect(EtatThreadRoute.depuis(nouveau: .enabled, ancien: .notRegistered) == .actif)
        #expect(EtatThreadRoute.depuis(nouveau: .notRegistered, ancien: .enabled) == .ancien, "halo-routes encore la")
        #expect(EtatThreadRoute.depuis(nouveau: .notRegistered, ancien: .requiresApproval) == .ancien)
    }

    /// Thread Route compte d'abord : un halo-routes reste n'y change rien.
    @Test func leNouveauDAbord() {
        #expect(EtatThreadRoute.depuis(nouveau: .enabled, ancien: .enabled) == .actif)
        #expect(EtatThreadRoute.depuis(nouveau: .requiresApproval, ancien: .enabled) == .aApprouver)
    }

    /// Les plists que lit l'app : ceux que posent l'installateur et l'ancien.
    @Test func plists() {
        #expect(EtatThreadRoute.plist.path == "/Library/LaunchDaemons/fr.djoko.thread.route.plist")
        #expect(EtatThreadRoute.plistAncien.path == "/Library/LaunchDaemons/fr.djoko.halo.routes.plist")
    }

    /// Ce que montrent les Reglages : un libelle par etat, et ce qu'il reste a faire.
    @Test func libellesEtConsignes() {
        let tous: [EtatThreadRoute] = [.absent, .aApprouver, .actif, .ancien]
        #expect(Set(tous.map(\.libelle)).count == 4)
        #expect(EtatThreadRoute.actif.consigne == nil)
        #expect(EtatThreadRoute.absent.consigne?.contains("sh tools/macos/thread-route/installer.sh") == true)
        #expect(EtatThreadRoute.ancien.consigne?.contains("sh tools/macos/thread-route/installer.sh") == true)
        #expect(EtatThreadRoute.aApprouver.consigne?.contains("Réglages Système") == true)
    }
}
```

Dans `apps/macos/HaloCompagnonTests/PontReseauTests.swift`, remplacer :

```swift
    @Test func textePasDeRoute() {
        #expect(AlerteReseau.textePasDeRoute(assistant: false).contains("installer.sh"))
        #expect(!AlerteReseau.textePasDeRoute(assistant: true).contains("installer.sh"))
    }
```

par :

```swift
    /// Sans route : ce que dit le bandeau, selon l'etat de Thread Route.
    @Test func textePasDeRoute() {
        let installer = "sh tools/macos/thread-route/installer.sh"
        #expect(AlerteReseau.textePasDeRoute(.absent).contains(installer))
        #expect(AlerteReseau.textePasDeRoute(.ancien).contains(installer), "halo-routes a remplacer")
        #expect(!AlerteReseau.textePasDeRoute(.actif).contains("installer.sh"), "la route revient d'elle-meme")
        #expect(AlerteReseau.textePasDeRoute(.aApprouver).contains("Réglages Système"))
        #expect(!AlerteReseau.textePasDeRoute(.aApprouver).contains("installer.sh"))
        for e in [EtatThreadRoute.absent, .aApprouver, .actif, .ancien] {
            #expect(AlerteReseau.textePasDeRoute(e).hasPrefix(ErreurReseau.pasDeRoute.description + " "))
        }
    }
```

- [ ] **Step 2 : les voir échouer.** La commande de Halo Compagnon (Global Constraints), avec `-only-testing:HaloCompagnonTests/ThreadRouteTests -only-testing:HaloCompagnonTests/PontReseauTests`.

Expected : `error: cannot find 'EtatThreadRoute' in scope` (et d'autres erreurs qui en découlent), `** TEST FAILED **`.

- [ ] **Step 3 : l'état, le message, les Réglages** (`--etapes 3`).

`apps/macos/HaloCompagnon/Reseau/ThreadRoute.swift` :

```swift
import Foundation
import ServiceManagement

/// Etat de Thread Route, le demon systeme qui garde la route du Mac vers le reseau Thread
/// (`tools/macos/thread-route`, 10.1). Il s'installe par son installateur, avec le mot de passe
/// administrateur : une app dans le bac a sable ne peut pas l'inscrire elle-meme (essai du 06/10 :
/// SMAppService y refuse un demon qui n'est pas dans le bac a sable). L'app lit son etat aupres du
/// systeme, ce que permet le bac a sable (`SMAppService.statusForLegacyPlist`).
enum EtatThreadRoute: Equatable, Sendable {
    /// Ni Thread Route, ni halo-routes.
    case absent
    /// Installe, mais desactive dans Reglages Systeme (Ouverture et extensions).
    case aApprouver
    /// Installe et autorise : launchd le garde en marche.
    case actif
    /// halo-routes, son ancien nom, est encore installe : l'installateur le remplace.
    case ancien

    static let plist = URL(fileURLWithPath: "/Library/LaunchDaemons/fr.djoko.thread.route.plist")
    static let plistAncien = URL(fileURLWithPath: "/Library/LaunchDaemons/fr.djoko.halo.routes.plist")

    /// L'etat, a partir de ce que le systeme dit du plist de Thread Route et de celui de halo-routes.
    static func depuis(nouveau: SMAppService.Status, ancien: SMAppService.Status) -> EtatThreadRoute {
        switch nouveau {
        case .enabled: .actif
        case .requiresApproval: .aApprouver
        default: ancien == .enabled || ancien == .requiresApproval ? .ancien : .absent
        }
    }

    /// L'etat du moment, lu aupres du systeme.
    static func lire() -> EtatThreadRoute {
        depuis(nouveau: SMAppService.statusForLegacyPlist(at: plist),
               ancien: SMAppService.statusForLegacyPlist(at: plistAncien))
    }

    /// Libelle de l'etat, dans les Reglages.
    var libelle: String {
        switch self {
        case .absent: tr("Absent")
        case .aApprouver: tr("Désactivé dans Réglages Système")
        case .actif: tr("Actif")
        case .ancien: tr("halo-routes, son ancien nom, est encore installé")
        }
    }

    /// Ce qu'il reste a faire ; rien quand il est actif.
    var consigne: String? {
        switch self {
        case .absent: tr("Pour l'installer : sh tools/macos/thread-route/installer.sh (mot de passe administrateur).")
        case .aApprouver: tr("L'autoriser dans Réglages Système, Général, Ouverture et extensions.")
        case .actif: nil
        case .ancien: tr("Pour le remplacer : sh tools/macos/thread-route/installer.sh (mot de passe administrateur).")
        }
    }
}
```

Dans `apps/macos/HaloCompagnon/Reseau/AlerteReseau.swift`, remplacer :

```swift
        case .transport(.pasDeRoute): Self.textePasDeRoute(assistant: Self.assistantInstalle)
        case .transport(let e): e.description
```

par :

```swift
        case .transport(.pasDeRoute): Self.textePasDeRoute(EtatThreadRoute.lire())
        case .transport(let e): e.description
```

Dans `apps/macos/HaloCompagnon/Reseau/AlerteReseau.swift`, remplacer :

```swift
    static func textePasDeRoute(assistant: Bool) -> String {
        ErreurReseau.pasDeRoute.description + " " + (assistant
            ? tr("L'assistant système halo-routes est installé : la route revient d'elle-même.")
            : tr("Installer l'assistant système : sh tools/macos/halo-routes/installer.sh"))
    }

    /// Le plist de l'assistant (10.1), si la sandbox laisse le voir.
    static var assistantInstalle: Bool {
        FileManager.default.fileExists(atPath: "/Library/LaunchDaemons/fr.djoko.halo.routes.plist")
    }
```

par :

```swift
    /// Sans route : la route revient d'elle-meme si Thread Route est actif (10.1) ; sinon, ce qu'il reste a faire.
    static func textePasDeRoute(_ etat: EtatThreadRoute) -> String {
        ErreurReseau.pasDeRoute.description + " "
            + (etat.consigne ?? tr("Thread Route est actif : la route revient d'elle-même."))
    }
```

Dans `apps/macos/HaloCompagnon/Vues/Reglages.swift`, remplacer :

```swift
import SwiftUI
```

par :

```swift
import ServiceManagement
import SwiftUI
```

Dans `apps/macos/HaloCompagnon/Vues/Reglages.swift`, remplacer :

```swift
/// Onglet Général : langue de l'app.
struct Reglages: View {
```

par :

```swift
/// Onglet Général : langue de l'app, Thread Route.
struct Reglages: View {
```

Dans `apps/macos/HaloCompagnon/Vues/Reglages.swift`, remplacer :

```swift
        }
        .formStyle(.grouped)
```

par :

```swift
            SectionThreadRoute()
        }
        .formStyle(.grouped)
```

Dans `apps/macos/HaloCompagnon/Vues/Reglages.swift`, remplacer :

```swift
        .fixedSize(horizontal: false, vertical: true)
    }
}

```

par :

```swift
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Onglet General : Thread Route, le demon qui garde la route du Mac vers le reseau Thread (10.1). Son etat
/// est relu a chaque apparition de l'onglet : une installation ou une approbation faites entre-temps s'y voient.
struct SectionThreadRoute: View {
    @State private var etat = EtatThreadRoute.lire()

    var body: some View {
        Section("Thread Route") {
            LabeledContent("État", value: etat.libelle)
            if let c = etat.consigne {
                Text(c)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if etat == .aApprouver {
                Button("Ouvrir Réglages Système…") { SMAppService.openSystemSettingsLoginItems() }
            }
        }
        .onAppear { etat = EtatThreadRoute.lire() }
    }
}

```

- [ ] **Step 4 : les voir passer.** La même commande qu'au step 2.

Expected : `Test run with 16 tests in 2 suites passed`, `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 5 : les textes,** par les outils : synchroniser le catalogue avec ceux qu'a extraits la compilation, puis traduire.

```bash
W=$S/deploiement-exec; DDH=$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-halo; T=$HOME/Library/Caches/deploiement-exec; cd "$W/halo/apps/macos" && I="$DDH/Build/Intermediates.noindex/HaloCompagnon.build/Debug" && xcrun xcstringstool sync HaloCompagnon/Ressources/*.xcstrings --stringsdata "$I"/HaloCompagnon.build/Objects-normal/arm64/*.stringsdata && cat > "$T/traductions-thread-route.json" <<'EOF'
{
  "Absent": "Absent",
  "Actif": "Active",
  "Désactivé dans Réglages Système": "Turned off in System Settings",
  "L'autoriser dans Réglages Système, Général, Ouverture et extensions.": "Allow it in System Settings, General, Login Items & Extensions.",
  "Ouvrir Réglages Système…": "Open System Settings…",
  "Pour l'installer : sh tools/macos/thread-route/installer.sh (mot de passe administrateur).": "To install it: sh tools/macos/thread-route/installer.sh (administrator password).",
  "Pour le remplacer : sh tools/macos/thread-route/installer.sh (mot de passe administrateur).": "To replace it: sh tools/macos/thread-route/installer.sh (administrator password).",
  "Thread Route": "Thread Route",
  "Thread Route est actif : la route revient d'elle-même.": "Thread Route is active: the route will come back by itself.",
  "halo-routes, son ancien nom, est encore installé": "halo-routes, its former name, is still installed",
  "État": "Status"
}
EOF
/usr/bin/python3 Outils/traduire.py HaloCompagnon/Ressources/Localizable.xcstrings "$T/traductions-thread-route.json" && git diff --stat HaloCompagnon/Ressources/
```

Expected : seul `Localizable.xcstrings` change ; les deux anciens textes de `halo-routes` en sortent (périmés).

- [ ] **Step 6 : toute la suite.** La commande de Halo Compagnon, sans cible.

Expected : `Test run with 144 tests in 20 suites passed` (HaloProtocole) et `Test run with 38 tests in 8 suites passed` (l'app : 4 de plus, et une suite), `** TEST SUCCEEDED **`, sans avertissement. `LocalisationTests` vérifie le catalogue.

- [ ] **Step 7 : le README de l'app** (`--etapes 7`) : ce que dit le message « Pas de route ».

Dans `apps/macos/README.md`, remplacer :

```markdown
The "No IPv6 route" message depends on the `tools/macos/thread-route/` system
helper: if its `/Library/LaunchDaemons/fr.djoko.thread.route.plist` file is
visible from the sandbox, the message says the route comes back on its
own; otherwise it points to `sh tools/macos/thread-route/installer.sh`.

```

par :

```markdown
The "No IPv6 route" message depends on Thread Route, the
`tools/macos/thread-route/` system helper (formerly halo-routes). The app
reads its status from macOS (`SMAppService.statusForLegacyPlist`, which the
sandbox allows), with every message and every time Settings opens (General,
Thread Route): active, the message says the route comes back on its own;
absent, or halo-routes still there, it points to
`sh tools/macos/thread-route/installer.sh`; turned off in System Settings,
it says to allow it there.

```

Dans `apps/macos/README.fr.md`, remplacer :

```markdown
Le message « Pas de route » dépend de l'assistant système
`tools/macos/thread-route/` : si son fichier
`/Library/LaunchDaemons/fr.djoko.thread.route.plist` est visible depuis le bac
à sable, le message dit que la route revient seule ; sinon il renvoie à
`sh tools/macos/thread-route/installer.sh`.

```

par :

```markdown
Le message « Pas de route » dépend de Thread Route, l'assistant système
`tools/macos/thread-route/` (anciennement halo-routes). L'app lit son état
auprès de macOS (`SMAppService.statusForLegacyPlist`, que permet le bac à
sable), à chaque message et à chaque ouverture des Réglages (Général, Thread
Route) : actif, le message dit que la route revient seule ; absent, ou
halo-routes encore là, il renvoie à `sh tools/macos/thread-route/installer.sh` ;
désactivé dans Réglages Système, il dit de l'y autoriser.

```

- [ ] **Step 8 : commit.**

```bash
W=$S/deploiement-exec; cd "$W/halo" && git add apps/macos/HaloCompagnon/Reseau/ThreadRoute.swift apps/macos/HaloCompagnon/Reseau/AlerteReseau.swift apps/macos/HaloCompagnon/Vues/Reglages.swift apps/macos/HaloCompagnon/Ressources/Localizable.xcstrings apps/macos/HaloCompagnonTests/ThreadRouteTests.swift apps/macos/HaloCompagnonTests/PontReseauTests.swift apps/macos/README.md apps/macos/README.fr.md && git commit -q -F - <<'EOF'
Montrer l'etat de Thread Route dans Halo Compagnon : absent, a approuver, actif ou halo-routes encore la

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `0`.

---

### Task 4: La copie conforme de Thread Route, et son état dans Maillage Thread

**Files :**
- Create : `outils/tests/test_thread_route.py`, `outils/synchroniser-thread-route.sh`, `outils/thread-route/` et `outils/thread-route.source` (par le script), `MaillageThread/Surveillance/ThreadRoute.swift`, `MaillageThreadTests/ThreadRouteTests.swift`
- Modify : `MaillageThread/Vues/FenetreReglages.swift`, `MaillageCoeur/Systeme/TableRoutage.swift` (blocs) ; `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json` (outils)

**Interfaces:**
- Consumes : Thread Route au commit de la tâche 2, dans `$W/halo`.
- Produces :
  - `outils/synchroniser-thread-route.sh [revision]` (`DEPOT_HALO`) ; `outils/thread-route.source`, ses champs `chemin : …` et `arbre : <sha1>` ;
  - `arbre_git(dossier) -> str` et `source_notee() -> dict` dans `test_thread_route.py` ;
  - `EtatThreadRoute`, comme dans Halo Compagnon (tâche 3), avec la commande `sh outils/thread-route/installer.sh`.

- [ ] **Step 1 : la base.** Toute la suite sur `main`, puis les images de démo, qui serviront de référence (tâche 10).

Run : `W=$S/deploiement-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" TMPDIR="$HOME/Library/Caches/deploiement-exec/" outils/tester.sh`

Expected : `Test run with 420 tests in 42 suites passed` (cœur) et `Test run with 391 tests in 32 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-deploiement-base"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "[d]eploiement-exec-maillage/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitte"
```

Expected : `21` ; `l'app a quitte`.

- [ ] **Step 2 : le test de la copie, d'abord** (`--etapes 2`, depuis `$W/maillage`).

`outils/tests/test_thread_route.py` :

```python
"""La copie de Thread Route (outils/thread-route) est celle de sa source, le depot du pont Halo
(tools/macos/thread-route), a la revision notee dans outils/thread-route.source : l'arbre git de
la source. outils/synchroniser-thread-route.sh refait la copie et la note.

  /usr/bin/python3 -m unittest discover -s outils/tests

Le depot du pont Halo (DEPOT_HALO, par defaut ~/Documents/Dev/esp32/benq) n'est lu que s'il est la.
"""
import hashlib
import os
import re
import subprocess
import tempfile
import unittest

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
COPIE = os.path.join(RACINE, 'outils', 'thread-route')
SOURCE = os.path.join(RACINE, 'outils', 'thread-route.source')
DEPOT_HALO = os.environ.get('DEPOT_HALO', os.path.expanduser('~/Documents/Dev/esp32/benq'))
IGNORES = {'.DS_Store'}


def arbre_git(dossier):
    """Identifiant git (SHA-1) de l'arbre d'un dossier de fichiers, sans sous-dossier, tel que git le calcule :
    un blob par fichier (« blob <taille>\\0 » puis le contenu), le mode 100755 ou 100644 selon le droit
    d'execution, les entrees dans l'ordre des octets de leur nom."""
    entrees = []
    for nom in os.listdir(dossier):
        if nom in IGNORES:
            continue
        chemin = os.path.join(dossier, nom)
        if os.path.isdir(chemin):
            raise ValueError('sous-dossier inattendu : ' + nom)
        with open(chemin, 'rb') as f:
            contenu = f.read()
        blob = hashlib.sha1(b'blob %d\0' % len(contenu) + contenu).digest()
        mode = b'100755' if os.access(chemin, os.X_OK) else b'100644'
        entrees.append((nom.encode('utf-8'), mode, blob))
    corps = b''.join(mode + b' ' + nom + b'\0' + blob for nom, mode, blob in sorted(entrees))
    return hashlib.sha1(b'tree %d\0' % len(corps) + corps).hexdigest()


def source_notee():
    """Les champs de outils/thread-route.source : « cle : valeur » par ligne."""
    with open(SOURCE, encoding='utf-8') as f:
        return dict(re.findall(r'^(\w+) : (.+)$', f.read(), re.M))


class CopieThreadRouteTests(unittest.TestCase):
    def test_arbre_git_comme_git(self):
        """arbre_git rend l'identifiant que git donne au meme dossier (un fichier executable, un ordinaire)."""
        with tempfile.TemporaryDirectory() as d:
            sous = os.path.join(d, 'x')
            os.mkdir(sous)
            with open(os.path.join(sous, 'b.sh'), 'w') as f:
                f.write('#!/bin/sh\necho b\n')
            os.chmod(os.path.join(sous, 'b.sh'), 0o755)
            with open(os.path.join(sous, 'a.c'), 'w') as f:
                f.write('int a;\n')
            env = dict(os.environ, GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_SYSTEM='/dev/null')
            subprocess.run(['git', 'init', '-q', d], check=True, env=env)
            subprocess.run(['git', '-C', d, 'add', 'x'], check=True, env=env)
            arbre = subprocess.run(['git', '-C', d, 'write-tree', '--prefix=x/'], check=True, env=env,
                                   capture_output=True, text=True).stdout.strip()
            self.assertEqual(arbre_git(sous), arbre)

    def test_copie_conforme_a_la_revision_notee(self):
        notee = source_notee()
        self.assertEqual(notee.get('chemin'), 'tools/macos/thread-route')
        self.assertRegex(notee.get('arbre', ''), r'^[0-9a-f]{40}$')
        self.assertEqual(arbre_git(COPIE), notee['arbre'],
                         'la copie a change : outils/synchroniser-thread-route.sh la refait depuis sa source')

    def test_revision_notee_dans_la_source(self):
        """L'arbre note existe dans le depot du pont Halo, s'il est sur ce Mac : la copie vient bien de lui."""
        if not os.path.isdir(DEPOT_HALO):
            self.skipTest('depot du pont Halo absent : ' + DEPOT_HALO)
        r = subprocess.run(['git', '-C', DEPOT_HALO, 'cat-file', '-t', source_notee()['arbre']],
                           capture_output=True, text=True)
        self.assertEqual(r.stdout.strip(), 'tree', 'arbre note introuvable dans ' + DEPOT_HALO)


if __name__ == '__main__':
    unittest.main()
```

Run : `W=$S/deploiement-exec; cd "$W/maillage" && /usr/bin/python3 -m unittest discover -s outils/tests 2>&1 | tail -3`

Expected : `Ran 3 tests`, `FAILED (errors=2)` : pas de `outils/thread-route.source` (`test_arbre_git_comme_git` passe déjà).

- [ ] **Step 3 : le script de la copie** (`--etapes 3`), puis la copie.

`outils/synchroniser-thread-route.sh` :

```sh
#!/bin/sh
# Copie Thread Route depuis sa source, le depot du pont Halo, a l'identique : outils/thread-route/
# recoit les fichiers de tools/macos/thread-route a la revision donnee (main par defaut), et
# outils/thread-route.source note l'arbre git de cette source. outils/tests/test_thread_route.py
# verifie la copie. Ne rien modifier dans outils/thread-route : changer la source, puis copier.
#   outils/synchroniser-thread-route.sh [revision]
#   DEPOT_HALO : le depot du pont Halo (par defaut ~/Documents/Dev/esp32/benq)
set -eu
cd "$(dirname "$0")/.."
DEPOT=${DEPOT_HALO:-$HOME/Documents/Dev/esp32/benq}
REV=${1:-main}
CHEMIN=tools/macos/thread-route
ARBRE=$(git -C "$DEPOT" rev-parse --verify "$REV:$CHEMIN")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
git -C "$DEPOT" archive "$REV" "$CHEMIN" | tar -x -C "$TMP"
rm -rf outils/thread-route
cp -R "$TMP/$CHEMIN" outils/thread-route
cat > outils/thread-route.source <<FIN
Copie de Thread Route, a l'identique : ne pas la modifier ici (outils/synchroniser-thread-route.sh).
depot : Djoko-cli/benq-screenbar-halo-matter
chemin : $CHEMIN
arbre : $ARBRE
FIN
echo "copie : $CHEMIN, arbre $ARBRE"
```

```bash
W=$S/deploiement-exec; cd "$W/maillage" && chmod 755 outils/synchroniser-thread-route.sh && DEPOT_HALO="$W/halo" outils/synchroniser-thread-route.sh HEAD && ls outils/thread-route | wc -l && /usr/bin/python3 -m unittest discover -s outils/tests 2>&1 | tail -3
```

Expected : `copie : tools/macos/thread-route, arbre 3e99d3ecc9a1473e8896adefbd4fdee6e4749745` ; `10` ; `Ran 3 tests`, `OK`. Le `HEAD` de `$W/halo` est le commit de la tâche 3, dont Thread Route est celui de la tâche 2.

- [ ] **Step 4 : les tests de l'état, d'abord** (`--etapes 4`).

`MaillageThreadTests/ThreadRouteTests.swift` :

```swift
import Foundation
import ServiceManagement
import Testing
@testable import MaillageThread

/// L'etat de Thread Route, lu de ce que le systeme dit de ses deux plists : le sien et celui de
/// halo-routes, son ancien nom. Seulement la decision, sur des etats donnes : l'etat reel depend du Mac.
@Suite("Thread Route : son etat")
struct ThreadRouteTests {
    /// Les quatre cas : absent, a approuver, actif, ancien.
    @Test func quatreCas() {
        #expect(EtatThreadRoute.depuis(nouveau: .notRegistered, ancien: .notRegistered) == .absent)
        #expect(EtatThreadRoute.depuis(nouveau: .notFound, ancien: .notFound) == .absent)
        #expect(EtatThreadRoute.depuis(nouveau: .requiresApproval, ancien: .notRegistered) == .aApprouver,
                "desactive dans Reglages Systeme")
        #expect(EtatThreadRoute.depuis(nouveau: .enabled, ancien: .notRegistered) == .actif)
        #expect(EtatThreadRoute.depuis(nouveau: .notRegistered, ancien: .enabled) == .ancien, "halo-routes encore la")
        #expect(EtatThreadRoute.depuis(nouveau: .notRegistered, ancien: .requiresApproval) == .ancien)
    }

    /// Thread Route compte d'abord : un halo-routes reste n'y change rien.
    @Test func leNouveauDAbord() {
        #expect(EtatThreadRoute.depuis(nouveau: .enabled, ancien: .enabled) == .actif)
        #expect(EtatThreadRoute.depuis(nouveau: .requiresApproval, ancien: .enabled) == .aApprouver)
    }

    /// Les plists que lit l'app : ceux que posent l'installateur et l'ancien.
    @Test func plists() {
        #expect(EtatThreadRoute.plist.path == "/Library/LaunchDaemons/fr.djoko.thread.route.plist")
        #expect(EtatThreadRoute.plistAncien.path == "/Library/LaunchDaemons/fr.djoko.halo.routes.plist")
    }

    /// Ce que montrent les Reglages : un libelle par etat, et ce qu'il reste a faire, avec la commande de la
    /// copie de ce depot.
    @Test func libellesEtConsignes() {
        let tous: [EtatThreadRoute] = [.absent, .aApprouver, .actif, .ancien]
        #expect(Set(tous.map(\.libelle)).count == 4)
        #expect(EtatThreadRoute.actif.consigne == nil)
        #expect(EtatThreadRoute.absent.consigne?.contains("sh outils/thread-route/installer.sh") == true)
        #expect(EtatThreadRoute.ancien.consigne?.contains("sh outils/thread-route/installer.sh") == true)
        #expect(EtatThreadRoute.ancien.consigne != EtatThreadRoute.absent.consigne)
        let approuver = EtatThreadRoute.aApprouver.consigne
        #expect(approuver != nil && approuver?.contains("installer.sh") == false)
    }
}
```

Run : `W=$S/deploiement-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" TMPDIR="$HOME/Library/Caches/deploiement-exec/" outils/tester.sh MaillageThreadTests/ThreadRouteTests`

Expected : `error: cannot find 'EtatThreadRoute' in scope`, `** TEST FAILED **`.

- [ ] **Step 5 : l'état et la section des Réglages** (`--etapes 5`).

`MaillageThread/Surveillance/ThreadRoute.swift` :

```swift
import Foundation
import ServiceManagement

/// Etat de Thread Route, le demon systeme qui garde la route du Mac vers le reseau Thread, et donc vers la sonde
/// par « Reseau Thread ». Sa source est dans le depot du pont Halo ; ce depot en garde une copie a l'identique
/// (`outils/thread-route`). Il s'installe par son installateur, avec le mot de passe administrateur : une app dans
/// le bac a sable ne peut pas l'inscrire elle-meme (essai du 06/10 : SMAppService y refuse un demon qui n'est pas
/// dans le bac a sable). L'app lit son etat aupres du systeme, ce que permet le bac a sable
/// (`SMAppService.statusForLegacyPlist`).
enum EtatThreadRoute: Equatable, Sendable {
    /// Ni Thread Route, ni halo-routes.
    case absent
    /// Installe, mais desactive dans Reglages Systeme (Ouverture et extensions).
    case aApprouver
    /// Installe et autorise : launchd le garde en marche.
    case actif
    /// halo-routes, son ancien nom, est encore installe : l'installateur le remplace.
    case ancien

    static let plist = URL(fileURLWithPath: "/Library/LaunchDaemons/fr.djoko.thread.route.plist")
    static let plistAncien = URL(fileURLWithPath: "/Library/LaunchDaemons/fr.djoko.halo.routes.plist")

    /// L'etat, a partir de ce que le systeme dit du plist de Thread Route et de celui de halo-routes.
    static func depuis(nouveau: SMAppService.Status, ancien: SMAppService.Status) -> EtatThreadRoute {
        switch nouveau {
        case .enabled: .actif
        case .requiresApproval: .aApprouver
        default: ancien == .enabled || ancien == .requiresApproval ? .ancien : .absent
        }
    }

    /// L'etat du moment, lu aupres du systeme.
    static func lire() -> EtatThreadRoute {
        depuis(nouveau: SMAppService.statusForLegacyPlist(at: plist),
               ancien: SMAppService.statusForLegacyPlist(at: plistAncien))
    }

    /// Libelle de l'etat, dans les Reglages.
    var libelle: String {
        switch self {
        case .absent: String(localized: "Absent")
        case .aApprouver: String(localized: "Désactivé dans Réglages Système")
        case .actif: String(localized: "Actif")
        case .ancien: String(localized: "halo-routes, son ancien nom, est encore installé")
        }
    }

    /// Ce qu'il reste a faire ; rien quand il est actif.
    var consigne: String? {
        switch self {
        case .absent: String(localized: "Pour l'installer : sh outils/thread-route/installer.sh (mot de passe administrateur).")
        case .aApprouver: String(localized: "L'autoriser dans Réglages Système, Général, Ouverture et extensions.")
        case .actif: nil
        case .ancien: String(localized: "Pour le remplacer : sh outils/thread-route/installer.sh (mot de passe administrateur).")
        }
    }
}
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
import SwiftUI
```

par :

```swift
import ServiceManagement
import SwiftUI
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
    @State private var messageLangue: String?
```

par :

```swift
    @State private var messageLangue: String?
    @State private var etatThreadRoute = EtatThreadRoute.lire()
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
            case .diagnostic: page { diagnostic }
            }
```

par :

```swift
            case .diagnostic:
                page {
                    diagnostic
                    threadRoute
                }
            }
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
        .onAppear { if onglet == .general { ouverture.actualiser() } }
    }
```

par :

```swift
        .onAppear {
            if onglet == .general { ouverture.actualiser() }
            // Thread Route installe ou approuve entre-temps : son etat est relu a chaque affichage de l'onglet.
            if onglet == .diagnostic { etatThreadRoute = EtatThreadRoute.lire() }
        }
    }
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
                Text(messageCapture).font(.caption).foregroundStyle(.secondary)
```

par :

```swift
                Text(messageCapture).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Onglet Diagnostic : Thread Route, le demon qui garde la route du Mac vers le reseau Thread (et vers la sonde
    /// par « Reseau Thread ») ; son etat, et ce qu'il reste a faire.
    private var threadRoute: some View {
        Section("Thread Route") {
            LabeledContent("État", value: etatThreadRoute.libelle)
            if let c = etatThreadRoute.consigne {
                Text(c).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if etatThreadRoute == .aApprouver {
                Button("Ouvrir Réglages Système…") { SMAppService.openSystemSettingsLoginItems() }
```

Dans `MaillageCoeur/Systeme/TableRoutage.swift`, remplacer :

```swift
/// de bordure (et ceux que pose l'assistant halo-routes).
public enum TableRoutage {
```

par :

```swift
/// de bordure (et ceux que pose Thread Route, l'assistant systeme, anciennement halo-routes).
public enum TableRoutage {
```

Run : la commande du step 4.

Expected : `Test run with 4 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 6 : les textes,** par les outils.

```bash
W=$S/deploiement-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" outils/synchroniser-textes.sh && /usr/bin/python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "Absent": "Absent",
    "Actif": "Active",
    "Désactivé dans Réglages Système": "Turned off in System Settings",
    "L'autoriser dans Réglages Système, Général, Ouverture et extensions.": "Allow it in System Settings, General, Login Items & Extensions.",
    "Ouvrir Réglages Système…": "Open System Settings…",
    "Pour l'installer : sh outils/thread-route/installer.sh (mot de passe administrateur).": "To install it: sh outils/thread-route/installer.sh (administrator password).",
    "Pour le remplacer : sh outils/thread-route/installer.sh (mot de passe administrateur).": "To replace it: sh outils/thread-route/installer.sh (administrator password).",
    "Thread Route": "Thread Route",
    "halo-routes, son ancien nom, est encore installé": "halo-routes, its former name, is still installed",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
/usr/bin/python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json && git diff --stat -- MaillageThread/Ressources outils/traductions
```

Expected : `Localizable.xcstrings` et `interface.json` changent (9 clés).

- [ ] **Step 7 : toute la suite.**

Run : `W=$S/deploiement-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" TMPDIR="$HOME/Library/Caches/deploiement-exec/" outils/tester.sh`

Expected : `Test run with 420 tests in 42 suites passed` et `Test run with 395 tests in 33 suites passed` (4 de plus, une suite), `** TEST SUCCEEDED **`, sans avertissement. `CataloguesTests` vérifie le catalogue.

- [ ] **Step 8 : la copie se teste comme sa source.**

Run : `P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec; cd "$W/maillage" && sh outils/thread-route/tests.sh > "$P/thread-route-copie.txt" 2>&1; echo "code $?"; grep -E "verification\(s\)" "$P/thread-route-copie.txt"`

Expected : `code 0` ; `thread-route : 47 verification(s), 0 echec(s)` ; `installation : 4 verification(s), 0 echec(s)`.

- [ ] **Step 9 : commit.**

```bash
W=$S/deploiement-exec; cd "$W/maillage" && git add outils/thread-route outils/thread-route.source outils/synchroniser-thread-route.sh outils/tests/test_thread_route.py MaillageThread/Surveillance/ThreadRoute.swift MaillageThread/Vues/FenetreReglages.swift MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json MaillageThreadTests/ThreadRouteTests.swift MaillageCoeur/Systeme/TableRoutage.swift && git commit -q -F - <<'EOF'
Garder une copie conforme de Thread Route et montrer son etat dans les Reglages de Maillage Thread

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `0`.

---

### Task 5: Sparkle 2 dans Maillage Thread

**Files :**
- Create : `MaillageThread/Surveillance/MisesAJour.swift`, `MaillageThreadTests/MisesAJourTests.swift`
- Modify : `project.yml`, `MaillageThread/Droits.entitlements`, `MaillageThread/MaillageThreadApp.swift`, `MaillageThread/Vues/ControleurReglages.swift`, `MaillageThread/Vues/MenuBarre.swift`, `MaillageThread/Vues/FenetreReglages.swift` (blocs) ; `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json` (outils)

**Interfaces:**
- Consumes : `Surveillance.sousTests` ; `ControleurReglages`, `FenetreReglages`, `MenuBarre` d'avant.
- Produces :
  - `@MainActor @Observable final class MisesAJour` : `init(demarrer: Bool)` ; `static private(set) weak var deLApp: MisesAJour?` ; `let demarre: Bool` ; `private(set) var peutRechercher: Bool` ; `var rechercheAuto: Bool`, `var installationAuto: Bool` (écrits dans Sparkle seulement si le moteur tourne) ; `static func demarrerAuLancement(demo: Bool) -> Bool` ; `func rechercher()` ;
  - `ControleurReglages.init(surveillance:ouverture:nomsMaison:sonde:misesAJour:)` ; `MisesAJour` dans l'environnement du menu et des Réglages ;
  - les réglages `FLUX_MISES_A_JOUR` et `CLE_MISES_A_JOUR` de la cible `MaillageThread` (tâches 7, 10 et 11), `MARKETING_VERSION` 1.0.0.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`).

`MaillageThreadTests/MisesAJourTests.swift` :

```swift
import Foundation
import Security
import Testing
@testable import MaillageThread

/// Les mises a jour (Sparkle 2) : ce que porte l'app, et le moteur jamais demarre sous les tests.
@MainActor
@Suite("Mises a jour : Sparkle")
struct MisesAJourTests {
    /// L'Info.plist : la version, le flux des versions publiees, la cle publique et les reglages de Sparkle.
    @Test func infoPlist() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["CFBundleShortVersionString"] as? String == "1.0.0")
        #expect(Int(info["CFBundleVersion"] as? String ?? "") != nil, "un nombre, que compare Sparkle")
        #expect(info["SUFeedURL"] as? String
                == "https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml")
        let cle = try #require(info["SUPublicEDKey"] as? String)
        #expect(Data(base64Encoded: cle)?.count == 32, "une cle publique Ed25519 : \(cle)")
        #expect(info["SUEnableAutomaticChecks"] as? Bool == true)
        #expect(info["SUScheduledCheckInterval"] as? Int == 86_400)
        #expect(info["SUAutomaticallyUpdate"] as? Bool == true)
        #expect(info["SUEnableInstallerLauncherService"] as? Bool == true)
    }

    /// Les droits du bac a sable : les deux services de Sparkle, rien de plus (le telechargement passe par
    /// `network.client`).
    @Test func droitsMachLookup() throws {
        let tache = try #require(SecTaskCreateFromSelf(nil))
        let cle = "com.apple.security.temporary-exception.mach-lookup.global-name" as CFString
        let valeur = SecTaskCopyValueForEntitlement(tache, cle, nil) as? [String] ?? []
        // Sous les tests, Xcode ajoute ceux de ses outils (com.apple…) a la compilation Debug.
        #expect(valeur.filter { !$0.hasPrefix("com.apple.") } == ["fr.djoko.maillage-spks", "fr.djoko.maillage-spki"])
        let bac = SecTaskCopyValueForEntitlement(tache, "com.apple.security.app-sandbox" as CFString, nil) as? Bool
        #expect(bac == true)
    }

    /// Celle de l'app, creee a son lancement, n'est pas demarree sous les tests : aucune recherche, aucun reseau.
    @Test func moteurArreteSousLesTests() throws {
        #expect(!MisesAJour.demarrerAuLancement(demo: false))
        let m = try #require(MisesAJour.deLApp, "creee au lancement de l'app")
        #expect(!m.demarre)
        #expect(!m.peutRechercher, "un moteur arrete ne recherche pas")
    }
}
```

Run : `W=$S/deploiement-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" TMPDIR="$HOME/Library/Caches/deploiement-exec/" outils/tester.sh MaillageThreadTests/MisesAJourTests`

Expected : `error: cannot find 'MisesAJour' in scope`, `** TEST FAILED **`.

- [ ] **Step 2 : Sparkle dans le projet, les droits, le moteur, le menu et les Réglages** (`--etapes 2`). La première compilation télécharge Sparkle 2.10.0 par le gestionnaire de paquets Swift (autorisé).

Dans `project.yml`, remplacer :

```yaml
  Release: Signature.xcconfig
```

par :

```yaml
  Release: Signature.xcconfig
# Sparkle 2 : les mises a jour de l'app, a une version figee (gestionnaire de paquets Swift).
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    exactVersion: 2.10.0
```

Dans `project.yml`, remplacer :

```yaml
    info:
      path: MaillageThread/Info.plist
```

par :

```yaml
      - package: Sparkle
    info:
      path: MaillageThread/Info.plist
```

Dans `project.yml`, remplacer :

```yaml
        LSApplicationCategoryType: public.app-category.utilities
```

par :

```yaml
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        # Mises a jour (Sparkle 2) : le flux des versions publiees et la cle publique Ed25519 (reglages ci-dessous) ;
        # recherche au demarrage puis toutes les 24 h, telechargement et installation automatiques ; installation
        # par le service de Sparkle, l'app restant dans le bac a sable.
        SUFeedURL: $(FLUX_MISES_A_JOUR)
        SUPublicEDKey: $(CLE_MISES_A_JOUR)
        SUEnableAutomaticChecks: true
        SUScheduledCheckInterval: 86400
        SUAutomaticallyUpdate: true
        SUEnableInstallerLauncherService: true
        LSApplicationCategoryType: public.app-category.utilities
```

Dans `project.yml`, remplacer :

```yaml
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        CODE_SIGN_ENTITLEMENTS: MaillageThread/Droits.entitlements
```

par :

```yaml
        # La version publiee (outils/publier.sh) ; le numero de compilation, que compare Sparkle, est donne a la
        # publication : le nombre de commits de main.
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        # Le flux des mises a jour (appcast.xml du depot, que publier.sh tient a jour, a son adresse brute) et la cle
        # publique ; la repetition les remplace en ligne de commande.
        FLUX_MISES_A_JOUR: https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml
        CLE_MISES_A_JOUR: lkPxEHj5erw+omLlr1AVsIoyhfz4YnoLa/N9147SNgc=
        CODE_SIGN_ENTITLEMENTS: MaillageThread/Droits.entitlements
```

Dans `MaillageThread/Droits.entitlements`, remplacer :

```xml
</dict>
```

par :

```xml
	<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
	<array>
		<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
		<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
	</array>
</dict>
```

`MaillageThread/Surveillance/MisesAJour.swift` :

```swift
import Combine
import Foundation
import Observation
import Sparkle

/// Les mises a jour de l'app, par Sparkle 2 : recherche au demarrage puis toutes les 24 h, telechargement et
/// installation automatiques, a la fermeture de l'app ou tout de suite par « Installer et relancer ». Le flux
/// (`SUFeedURL`), la cle publique (`SUPublicEDKey`) et ces choix par defaut sont dans l'Info.plist (project.yml).
/// L'app reste dans le bac a sable : Sparkle installe par son service (`SUEnableInstallerLauncherService`) ; les
/// textes de sa fenetre viennent de ses propres traductions.
///
/// Ni en demo, ni sous les tests, le moteur n'est demarre : aucune recherche, aucun acces au reseau, et les
/// reglages ne sont pas ecrits (les preferences sont celles de l'app de Djoko).
@MainActor
@Observable
final class MisesAJour {
    /// Celle de l'app, creee a son lancement.
    static private(set) weak var deLApp: MisesAJour?

    /// Le moteur est-il demarre ?
    let demarre: Bool
    /// « Rechercher les mises a jour… » est possible : le moteur tourne, et aucune recherche n'est en cours.
    private(set) var peutRechercher = false
    /// Reglage : rechercher automatiquement (au demarrage, puis toutes les 24 h).
    var rechercheAuto: Bool {
        didSet { if demarre { controleur.updater.automaticallyChecksForUpdates = rechercheAuto } }
    }
    /// Reglage : telecharger et installer automatiquement.
    var installationAuto: Bool {
        didSet { if demarre { controleur.updater.automaticallyDownloadsUpdates = installationAuto } }
    }

    @ObservationIgnored private let controleur: SPUStandardUpdaterController
    @ObservationIgnored private var abonnement: AnyCancellable?

    init(demarrer: Bool) {
        controleur = SPUStandardUpdaterController(startingUpdater: demarrer, updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        demarre = demarrer
        rechercheAuto = controleur.updater.automaticallyChecksForUpdates
        installationAuto = controleur.updater.automaticallyDownloadsUpdates
        abonnement = controleur.updater.publisher(for: \.canCheckForUpdates).sink { [weak self] peut in
            MainActor.assumeIsolated { self?.peutRechercher = peut }
        }
        Self.deLApp = self
    }

    /// Le moteur demarre au lancement de l'app, sauf en demo et sous les tests.
    static func demarrerAuLancement(demo: Bool) -> Bool {
        !demo && !Surveillance.sousTests
    }

    /// « Rechercher les mises a jour… » : la fenetre de Sparkle dit ce qu'elle trouve.
    func rechercher() {
        controleur.checkForUpdates(nil)
    }
}
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
    private let notifications = Notifications()
```

par :

```swift
    @State private var misesAJour: MisesAJour
    private let notifications = Notifications()
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
        _reglages = State(initialValue: ControleurReglages(surveillance: s, ouverture: o, nomsMaison: d, sonde: sm))
        let premier = !UserDefaults.standard.bool(forKey: Self.clePremierGraphe)
```

par :

```swift
        // Les mises a jour : ni en demo, ni sous les tests (aucune recherche, aucun reseau).
        let m = MisesAJour(demarrer: MisesAJour.demarrerAuLancement(demo: Self.demo))
        _misesAJour = State(initialValue: m)
        _reglages = State(initialValue: ControleurReglages(surveillance: s, ouverture: o, nomsMaison: d, sonde: sm,
                                                           misesAJour: m))
        let premier = !UserDefaults.standard.bool(forKey: Self.clePremierGraphe)
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
        } label: {
```

par :

```swift
                .environment(misesAJour)
        } label: {
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
            CommandGroup(replacing: .appSettings) {
```

par :

```swift
            CommandGroup(after: .appInfo) {
                Button("Rechercher les mises à jour…") { misesAJour.rechercher() }
                    .disabled(!misesAJour.peutRechercher)
            }
            CommandGroup(replacing: .appSettings) {
```

Dans `MaillageThread/Vues/ControleurReglages.swift`, remplacer :

```swift
    /// Creee a la premiere ouverture, puis gardee : elle rouvre sur le meme onglet.
```

par :

```swift
    @ObservationIgnored private let misesAJour: MisesAJour
    /// Creee a la premiere ouverture, puis gardee : elle rouvre sur le meme onglet.
```

Dans `MaillageThread/Vues/ControleurReglages.swift`, remplacer :

```swift
    init(surveillance: Surveillance, ouverture: OuvertureSession, nomsMaison: NomsInternes, sonde: SondeMaillage) {
        self.surveillance = surveillance
```

par :

```swift
    init(surveillance: Surveillance, ouverture: OuvertureSession, nomsMaison: NomsInternes, sonde: SondeMaillage,
         misesAJour: MisesAJour) {
        self.surveillance = surveillance
```

Dans `MaillageThread/Vues/ControleurReglages.swift`, remplacer :

```swift
        self.sonde = sonde
```

par :

```swift
        self.sonde = sonde
        self.misesAJour = misesAJour
```

Dans `MaillageThread/Vues/ControleurReglages.swift`, remplacer :

```swift
            // Sans `sizingOptions` : la page n'annonce pas de taille preferee, sinon le redimensionnement
```

par :

```swift
                .environment(misesAJour)
            // Sans `sizingOptions` : la page n'annonce pas de taille preferee, sinon le redimensionnement
```

Dans `MaillageThread/Vues/MenuBarre.swift`, remplacer :

```swift
    /// Fenetre du menu, pour le fermer apres « Ouvrir le graphe », « Journal… » et « Reglages… ».
```

par :

```swift
    @Environment(MisesAJour.self) private var misesAJour
    /// Fenetre du menu, pour le fermer apres « Ouvrir le graphe », « Journal… » et « Reglages… ».
```

Dans `MaillageThread/Vues/MenuBarre.swift`, remplacer :

```swift
                Button("Réglages…") { ouvrirReglages() }
```

par :

```swift
                Button("Rechercher les mises à jour…") { rechercherMisesAJour() }
                    .disabled(!misesAJour.peutRechercher)
                Button("Réglages…") { ouvrirReglages() }
```

Dans `MaillageThread/Vues/MenuBarre.swift`, remplacer :

```swift
        fenetreMenu.fenetre?.close()
    }
```

par :

```swift
        fenetreMenu.fenetre?.close()
    }

    /// La fenetre de Sparkle prend la place du menu, comme celle des reglages.
    private func rechercherMisesAJour() {
        misesAJour.rechercher()
        fenetreMenu.fenetre?.close()
    }
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
    @AppStorage(Notifications.cle(.scission)) private var scission = CategorieAlerte.scission.parDefaut
```

par :

```swift
    @Environment(MisesAJour.self) private var misesAJour
    @AppStorage(Notifications.cle(.scission)) private var scission = CategorieAlerte.scission.parDefaut
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
                    choixDeLangue
```

par :

```swift
                    sectionMisesAJour
                    choixDeLangue
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
                Text(e).foregroundStyle(.red)
            }
```

par :

```swift
                Text(e).foregroundStyle(.red)
            }
        }
    }

    /// Onglet General : les mises a jour (Sparkle), recherche et installation automatiques, cochees par defaut.
    private var sectionMisesAJour: some View {
        Section("Mises à jour") {
            Toggle("Rechercher automatiquement",
                   isOn: Binding(get: { misesAJour.rechercheAuto }, set: { misesAJour.rechercheAuto = $0 }))
            Toggle("Installer automatiquement",
                   isOn: Binding(get: { misesAJour.installationAuto }, set: { misesAJour.installationAuto = $0 }))
                .disabled(!misesAJour.rechercheAuto)
            Button("Rechercher les mises à jour…") { misesAJour.rechercher() }
                .disabled(!misesAJour.peutRechercher)
```

- [ ] **Step 3 : les voir passer.** La commande du step 1.

Expected : `Test run with 3 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

```bash
DDM=$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage; plutil -p "$DDM/Build/Products/Debug/Maillage Thread.app/Contents/Info.plist" | grep -E '"SU|ShortVersion'; ls "$DDM/Build/Products/Debug/Maillage Thread.app/Contents/Frameworks/"
```

Expected : `CFBundleShortVersionString` 1.0.0 ; `SUAutomaticallyUpdate`, `SUEnableAutomaticChecks`, `SUEnableInstallerLauncherService` à `true`, `SUFeedURL` du flux de la spec, `SUPublicEDKey` la clé provisoire, `SUScheduledCheckInterval` 86400 ; `MaillageCoeur.framework` et `Sparkle.framework`.

- [ ] **Step 4 : les textes,** par les outils.

```bash
W=$S/deploiement-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" outils/synchroniser-textes.sh && /usr/bin/python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "Installer automatiquement": "Install updates automatically",
    "Mises à jour": "Updates",
    "Rechercher automatiquement": "Check for updates automatically",
    "Rechercher les mises à jour…": "Check for Updates…",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
/usr/bin/python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json && git diff --stat -- MaillageThread/Ressources outils/traductions
```

- [ ] **Step 5 : toute la suite.**

Run : `W=$S/deploiement-exec; cd "$W/maillage" && DD="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" TMPDIR="$HOME/Library/Caches/deploiement-exec/" outils/tester.sh`

Expected : `Test run with 420 tests in 42 suites passed` et `Test run with 398 tests in 34 suites passed` (3 de plus, une suite), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
W=$S/deploiement-exec; cd "$W/maillage" && git add project.yml MaillageThread/Droits.entitlements MaillageThread/MaillageThreadApp.swift MaillageThread/Ressources/Localizable.xcstrings MaillageThread/Vues/ControleurReglages.swift MaillageThread/Vues/FenetreReglages.swift MaillageThread/Vues/MenuBarre.swift outils/traductions/interface.json MaillageThread/Surveillance/MisesAJour.swift MaillageThreadTests/MisesAJourTests.swift && git commit -q -F - <<'EOF'
Ajouter Sparkle 2 a Maillage Thread : recherche et installation automatiques, menu, Reglages, version 1.0.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `0`.

---

### Task 6: Sparkle 2 dans Halo Compagnon

**Files :**
- Create : `apps/macos/HaloCompagnon/Modele/MisesAJour.swift`, `apps/macos/HaloCompagnonTests/MisesAJourTests.swift`
- Modify : `apps/macos/project.yml`, `apps/macos/.gitignore`, `apps/macos/HaloCompagnon/HaloCompagnon.entitlements`, `apps/macos/HaloCompagnon/HaloCompagnonApp.swift`, `apps/macos/HaloCompagnon/Vues/Reglages.swift` (blocs) ; `apps/macos/HaloCompagnon/Ressources/Localizable.xcstrings` (outils)

**Interfaces:**
- Consumes : `tr(_:)`, `FenetreReglages`, `Reglages`, `SectionThreadRoute` (tâche 3).
- Produces : `MisesAJour`, comme dans Maillage Thread (tâche 5), sauf `static var demarrerAuLancement: Bool` (faux sous les tests seulement) ; l'Info.plist de XcodeGen `apps/macos/HaloCompagnon/Info.plist` (ignoré par git) ; `FLUX_MISES_A_JOUR`, `CLE_MISES_A_JOUR` de la cible `HaloCompagnon`, `MARKETING_VERSION` 1.0.0.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`, depuis `$W/halo`).

`apps/macos/HaloCompagnonTests/MisesAJourTests.swift` :

```swift
import Foundation
import Security
import Testing
@testable import HaloCompagnon

/// Les mises a jour (Sparkle 2) : ce que porte l'app, et le moteur jamais demarre sous les tests.
@MainActor
@Suite("Mises a jour : Sparkle")
struct MisesAJourTests {
    /// L'Info.plist : la version, le flux des versions publiees, la cle publique et les reglages de Sparkle.
    @Test func infoPlist() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["CFBundleShortVersionString"] as? String == "1.0.0")
        #expect(Int(info["CFBundleVersion"] as? String ?? "") != nil, "un nombre, que compare Sparkle")
        #expect(info["SUFeedURL"] as? String
                == "https://raw.githubusercontent.com/Djoko-cli/benq-screenbar-halo-matter/main/apps/macos/appcast.xml")
        let cle = try #require(info["SUPublicEDKey"] as? String)
        #expect(Data(base64Encoded: cle)?.count == 32, "une cle publique Ed25519 : \(cle)")
        #expect(info["SUEnableAutomaticChecks"] as? Bool == true)
        #expect(info["SUScheduledCheckInterval"] as? Int == 86_400)
        #expect(info["SUAutomaticallyUpdate"] as? Bool == true)
        #expect(info["SUEnableInstallerLauncherService"] as? Bool == true)
        // Ceux de la generation de l'Info.plist par Xcode restent.
        #expect(info["CFBundleDisplayName"] as? String == "Halo Compagnon")
        #expect(info["NSLocalNetworkUsageDescription"] as? String != nil)
    }

    /// Les droits du bac a sable : les deux services de Sparkle, rien de plus (le telechargement passe par
    /// `network.client`).
    @Test func droitsMachLookup() throws {
        let tache = try #require(SecTaskCreateFromSelf(nil))
        let cle = "com.apple.security.temporary-exception.mach-lookup.global-name" as CFString
        let valeur = SecTaskCopyValueForEntitlement(tache, cle, nil) as? [String] ?? []
        // Sous les tests, Xcode ajoute ceux de ses outils (com.apple…) a la compilation Debug.
        #expect(valeur.filter { !$0.hasPrefix("com.apple.") }
                == ["fr.djoko.halo.compagnon-spks", "fr.djoko.halo.compagnon-spki"])
        let bac = SecTaskCopyValueForEntitlement(tache, "com.apple.security.app-sandbox" as CFString, nil) as? Bool
        #expect(bac == true)
    }

    /// Celle de l'app, creee a son lancement, n'est pas demarree sous les tests : aucune recherche, aucun reseau.
    @Test func moteurArreteSousLesTests() throws {
        #expect(!MisesAJour.demarrerAuLancement)
        let m = try #require(MisesAJour.deLApp, "creee au lancement de l'app")
        #expect(!m.demarre)
        #expect(!m.peutRechercher, "un moteur arrete ne recherche pas")
    }
}
```

Run : la commande de Halo Compagnon, avec `-only-testing:HaloCompagnonTests/MisesAJourTests`.

Expected : `error: cannot find 'MisesAJour' in scope`, `** TEST FAILED **`.

- [ ] **Step 2 : Sparkle dans le projet, les droits, le moteur, le menu et les Réglages** (`--etapes 2`).

Dans `apps/macos/project.yml`, remplacer :

```yaml
  Release: Signature.xcconfig
```

par :

```yaml
  Release: Signature.xcconfig
# Sparkle 2 : les mises a jour de l'app, a une version figee (gestionnaire de paquets Swift).
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    exactVersion: 2.10.0
```

Dans `apps/macos/project.yml`, remplacer :

```yaml
    settings:
      base:
        PRODUCT_NAME: Halo Compagnon
```

par :

```yaml
      - package: Sparkle
    # Les cles que la generation de l'Info.plist par Xcode ne connait pas : ce fichier, genere par XcodeGen, est
    # complete par celles de INFOPLIST_KEY_ (GENERATE_INFOPLIST_FILE).
    info:
      path: HaloCompagnon/Info.plist
      properties:
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        # Mises a jour (Sparkle 2) : le flux des versions publiees et la cle publique Ed25519 (reglages ci-dessous) ;
        # recherche au demarrage puis toutes les 24 h, telechargement et installation automatiques ; installation
        # par le service de Sparkle, l'app restant dans le bac a sable.
        SUFeedURL: $(FLUX_MISES_A_JOUR)
        SUPublicEDKey: $(CLE_MISES_A_JOUR)
        SUEnableAutomaticChecks: true
        SUScheduledCheckInterval: 86400
        SUAutomaticallyUpdate: true
        SUEnableInstallerLauncherService: true
    settings:
      base:
        PRODUCT_NAME: Halo Compagnon
```

Dans `apps/macos/project.yml`, remplacer :

```yaml
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        CODE_SIGN_ENTITLEMENTS: HaloCompagnon/HaloCompagnon.entitlements
```

par :

```yaml
        # La version publiee (Outils/publier.sh) ; le numero de compilation, que compare Sparkle, est donne a la
        # publication : le nombre de commits de main.
        MARKETING_VERSION: "1.0.0"
        CURRENT_PROJECT_VERSION: "1"
        # Le flux des mises a jour (apps/macos/appcast.xml du depot, que publier.sh tient a jour, a son adresse brute)
        # et la cle publique ; la repetition les remplace en ligne de commande.
        FLUX_MISES_A_JOUR: https://raw.githubusercontent.com/Djoko-cli/benq-screenbar-halo-matter/main/apps/macos/appcast.xml
        CLE_MISES_A_JOUR: lkPxEHj5erw+omLlr1AVsIoyhfz4YnoLa/N9147SNgc=
        CODE_SIGN_ENTITLEMENTS: HaloCompagnon/HaloCompagnon.entitlements
```

Dans `apps/macos/.gitignore`, remplacer :

```text
Local.xcconfig

```

par :

```text
Local.xcconfig

# Genere par xcodegen depuis project.yml (info:)
HaloCompagnon/Info.plist

```

Dans `apps/macos/HaloCompagnon/HaloCompagnon.entitlements`, remplacer :

```xml
</dict>
```

par :

```xml
	<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
	<array>
		<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spks</string>
		<string>$(PRODUCT_BUNDLE_IDENTIFIER)-spki</string>
	</array>
</dict>
```

`apps/macos/HaloCompagnon/Modele/MisesAJour.swift` :

```swift
import Combine
import Foundation
import Observation
import Sparkle

/// Les mises a jour de l'app, par Sparkle 2 : recherche au demarrage puis toutes les 24 h, telechargement et
/// installation automatiques, a la fermeture de l'app ou tout de suite par « Installer et relancer ». Le flux
/// (`SUFeedURL`), la cle publique (`SUPublicEDKey`) et ces choix par defaut sont dans l'Info.plist (project.yml).
/// L'app reste dans le bac a sable : Sparkle installe par son service (`SUEnableInstallerLauncherService`) ; les
/// textes de sa fenetre viennent de ses propres traductions.
///
/// Sous les tests, le moteur n'est jamais demarre : aucune recherche, aucun acces au reseau, et les reglages ne
/// sont pas ecrits (les preferences sont celles de l'app installee).
@MainActor
@Observable
final class MisesAJour {
    /// Celle de l'app, creee a son lancement.
    static private(set) weak var deLApp: MisesAJour?

    /// Le moteur est-il demarre ?
    let demarre: Bool
    /// « Rechercher les mises a jour… » est possible : le moteur tourne, et aucune recherche n'est en cours.
    private(set) var peutRechercher = false
    /// Reglage : rechercher automatiquement (au demarrage, puis toutes les 24 h).
    var rechercheAuto: Bool {
        didSet { if demarre { controleur.updater.automaticallyChecksForUpdates = rechercheAuto } }
    }
    /// Reglage : telecharger et installer automatiquement.
    var installationAuto: Bool {
        didSet { if demarre { controleur.updater.automaticallyDownloadsUpdates = installationAuto } }
    }

    @ObservationIgnored private let controleur: SPUStandardUpdaterController
    @ObservationIgnored private var abonnement: AnyCancellable?

    init(demarrer: Bool) {
        controleur = SPUStandardUpdaterController(startingUpdater: demarrer, updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        demarre = demarrer
        rechercheAuto = controleur.updater.automaticallyChecksForUpdates
        installationAuto = controleur.updater.automaticallyDownloadsUpdates
        abonnement = controleur.updater.publisher(for: \.canCheckForUpdates).sink { [weak self] peut in
            MainActor.assumeIsolated { self?.peutRechercher = peut }
        }
        Self.deLApp = self
    }

    /// Le moteur demarre au lancement de l'app, sauf sous les tests.
    static var demarrerAuLancement: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    /// « Rechercher les mises a jour… » : la fenetre de Sparkle dit ce qu'elle trouve.
    func rechercher() {
        controleur.checkForUpdates(nil)
    }
}
```

Dans `apps/macos/HaloCompagnon/HaloCompagnonApp.swift`, remplacer :

```swift
    /// Lu dans `body` : un changement de langue reconstruit aussi les menus.
```

par :

```swift
    @State private var misesAJour: MisesAJour
    /// Lu dans `body` : un changement de langue reconstruit aussi les menus.
```

Dans `apps/macos/HaloCompagnon/HaloCompagnonApp.swift`, remplacer :

```swift
        ReglageLangue.appliquerAuLancement()
```

par :

```swift
        ReglageLangue.appliquerAuLancement()
        // Les mises a jour : jamais sous les tests (aucune recherche, aucun reseau).
        _misesAJour = State(initialValue: MisesAJour(demarrer: MisesAJour.demarrerAuLancement))
```

Dans `apps/macos/HaloCompagnon/HaloCompagnonApp.swift`, remplacer :

```swift
            CommandGroup(after: .newItem) {
```

par :

```swift
            CommandGroup(after: .appInfo) {
                Button(tr("Rechercher les mises à jour…")) { misesAJour.rechercher() }
                    .disabled(!misesAJour.peutRechercher)
            }
            CommandGroup(after: .newItem) {
```

Dans `apps/macos/HaloCompagnon/HaloCompagnonApp.swift`, remplacer :

```swift
                .langueDeLInterface()
        }
```

par :

```swift
                .environment(misesAJour)
                .langueDeLInterface()
        }
```

Dans `apps/macos/HaloCompagnon/Vues/Reglages.swift`, remplacer :

```swift
/// Onglet Général : langue de l'app, Thread Route.
struct Reglages: View {
    @AppStorage(ReglageLangue.cle) private var choix: ChoixLangue = .systeme

```

par :

```swift
/// Onglet Général : langue de l'app, mises a jour, Thread Route.
struct Reglages: View {
    @AppStorage(ReglageLangue.cle) private var choix: ChoixLangue = .systeme
    @Environment(MisesAJour.self) private var misesAJour

```

Dans `apps/macos/HaloCompagnon/Vues/Reglages.swift`, remplacer :

```swift
            }
            SectionThreadRoute()
```

par :

```swift
            }
            // Les mises a jour (Sparkle) : recherche et installation automatiques, cochees par defaut.
            Section("Mises à jour") {
                Toggle("Rechercher automatiquement",
                       isOn: Binding(get: { misesAJour.rechercheAuto }, set: { misesAJour.rechercheAuto = $0 }))
                Toggle("Installer automatiquement",
                       isOn: Binding(get: { misesAJour.installationAuto }, set: { misesAJour.installationAuto = $0 }))
                    .disabled(!misesAJour.rechercheAuto)
                Button("Rechercher les mises à jour…") { misesAJour.rechercher() }
                    .disabled(!misesAJour.peutRechercher)
            }
            SectionThreadRoute()
```

- [ ] **Step 3 : les voir passer.** La commande du step 1.

Expected : `Test run with 3 tests in 1 suite passed`, `** TEST SUCCEEDED **`. `git status --short` ne montre pas `HaloCompagnon/Info.plist` (ignoré).

- [ ] **Step 4 : les textes,** par les outils.

```bash
W=$S/deploiement-exec; DDH=$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-halo; T=$HOME/Library/Caches/deploiement-exec; cd "$W/halo/apps/macos" && I="$DDH/Build/Intermediates.noindex/HaloCompagnon.build/Debug" && xcrun xcstringstool sync HaloCompagnon/Ressources/*.xcstrings --stringsdata "$I"/HaloCompagnon.build/Objects-normal/arm64/*.stringsdata && cat > "$T/traductions-sparkle.json" <<'EOF'
{
  "Installer automatiquement": "Install updates automatically",
  "Mises à jour": "Updates",
  "Rechercher automatiquement": "Check for updates automatically",
  "Rechercher les mises à jour…": "Check for Updates…"
}
EOF
/usr/bin/python3 Outils/traduire.py HaloCompagnon/Ressources/Localizable.xcstrings "$T/traductions-sparkle.json" && git diff --stat HaloCompagnon/Ressources/
```

- [ ] **Step 5 : toute la suite.**

Expected : `Test run with 144 tests in 20 suites passed` et `Test run with 41 tests in 9 suites passed` (3 de plus, une suite), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
W=$S/deploiement-exec; cd "$W/halo/apps/macos" && git add .gitignore project.yml HaloCompagnon/HaloCompagnon.entitlements HaloCompagnon/HaloCompagnonApp.swift HaloCompagnon/Vues/Reglages.swift HaloCompagnon/Ressources/Localizable.xcstrings HaloCompagnon/Modele/MisesAJour.swift HaloCompagnonTests/MisesAJourTests.swift && git commit -q -F - <<'EOF'
Ajouter Sparkle 2 a Halo Compagnon : recherche et installation automatiques, menu, Reglages, version 1.0.0

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `0`.

---

### Task 7: `outils/publier.sh` dans Maillage Thread

**Files :**
- Create : `outils/tests/test_publication.py`, `outils/publication.py`, `outils/publier.sh`

**Interfaces:**
- Consumes : `MARKETING_VERSION`, `FLUX_MISES_A_JOUR`, `CLE_MISES_A_JOUR` de la cible (tâche 5) ; `NOTES-VERSIONS.md` (tâche 9) à la publication.
- Produces :
  - `outils/publier.sh X.Y.Z [--sans-bureau]` (étiquette `maillage-v`, flux `appcast.xml`) ; `outils/publier.sh X.Y.Z --repetition DOSSIER --url-base URL [--cle-privee FICHIER --cle-publique CLE] [--trousseau TROUSSEAU] [--sans-tests]` ; `SPARKLE_BIN`, `DD`, `IDENTITE_SIGNATURE` (par défaut `Djoko-cli Code Signing`), `NOTARISER`, `PROFIL_NOTARISATION` ;
  - dans `publication.py` : `Refus` ; `version_valide(v)` ; `reglage(projet_yml, cible, nom)` ; `systeme_minimum(projet_yml)` ; `numero_compilation(depot, git='git') -> int` ; `notes(chemin, version)` ; `notes_html(texte)` ; `item_flux(version, numero, url, taille, signature, systeme, notes_html_, date) -> str` (un `<item>`) ; `ajouter_au_flux(existant, titre, version, item) -> str` (un flux neuf si `existant` est `None`, sinon la version en tête ; refus si elle y est déjà) ; `message_flux(nom_app, version) -> str` ; `chemin_depot(chemin, racine_git) -> str` ; `notariser() -> bool` ; `code_imbrique(app) -> list` ; `signer(a, o, chemin, droits=True)` ; `Outils(env)` (`GIT`, `XCODEGEN`, `XCODEBUILD`, `HDIUTIL`, `CODESIGN`, `SECURITY`, `XCRUN`, `SPCTL`, `GH`, `SPARKLE_BIN`, `CONTROLE_ANONYMISATION`, `TABLE_ANONYMISATION`) ; `publier(a, o=None, maintenant=None) -> str` (le dossier des produits) ; `arguments(argv)` (`--identite`, `--etiquette` et `--flux` obligatoires, `--trousseau` en répétition) ;
  - les produits : `build/publication/X.Y.Z/` (`Maillage-Thread-X.Y.Z.dmg`, le nouveau flux `appcast.xml`, `notes.md`, `message-commit.txt`, `exigence.txt`, `compilation.log`, `tests-N.log`) ; le flux du dépôt, `appcast.xml`, commité sur `main` et poussé (dans la copie, sans être poussé, en répétition).

`publication.py` et ses tests sont les mêmes, à l'octet près, dans les deux dépôts (tâche 8).

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`). Ils montent un faux dépôt (et son origine), de fausses commandes qui notent leurs arguments, et ne touchent ni au réseau, ni au trousseau, ni au Bureau. Ils vérifient aussi le flux (neuf, une version de plus en tête d'un flux existant, une version déjà dedans refusée, l'adresse brute du dépôt), les étiquettes de l'app (celle d'une autre app ne gêne pas), le commit du flux (le seul fichier, le message, l'auteur à l'adresse noreply, poussé après la version publiée, jamais quand le contrôle d'anonymisation trouve quelque chose), l'ordre de la signature du code (le code imbriqué de Sparkle d'abord, l'app en dernier), et que la notarisation ne s'exécute pas par défaut, et s'arrête avant de compiler si on l'active sans profil.

`outils/tests/test_publication.py` :

```python
"""Tests de publication.py : les numeros, les notes, le flux appcast.xml a partir de valeurs inventees (nouveau, ou
une version de plus en tete d'un flux qui les garde toutes), les etiquettes propres a l'app, les controles avant
publication, le commit du flux, la signature du code et la notarisation (desactivee par defaut), sur un faux depot et de
fausses commandes (xcodebuild, codesign, security, hdiutil, sign_update, xcrun, gh...). Aucun reseau, aucun
trousseau, rien sur le Bureau.

  /usr/bin/python3 -m unittest discover -s <dossier de ces tests>
"""
import contextlib
import datetime
import io
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
import xml.etree.ElementTree as ET
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import publication as P  # noqa: E402

CLE = 'p7jaASHZk/U9YboWWSgw+Z4xEGYXOfUUhTKtZG7uQlE='
IDENTITE = 'Essai Inventee Signing'
AUTRE_CLE = 'lkPxEHj5erw+omLlr1AVsIoyhfz4YnoLa/N9147SNgc='
GIT_ENV = dict(os.environ, GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_SYSTEM='/dev/null',
               GIT_AUTHOR_NAME='Essai', GIT_AUTHOR_EMAIL='essai@example.invalid',
               GIT_COMMITTER_NAME='Essai', GIT_COMMITTER_EMAIL='essai@example.invalid')

PROJET = textwrap.dedent('''\
    name: Essai
    options:
      bundleIdPrefix: fr.exemple
      deploymentTarget:
        macOS: "26.0"
    targets:
      Compagnon:
        type: application
        settings:
          base:
            MARKETING_VERSION: "1.0"
      Essai:
        type: application
        settings:
          base:
            PRODUCT_NAME: Essai Inventee
            MARKETING_VERSION: "1.2.3"
            CURRENT_PROJECT_VERSION: "1"
            FLUX_MISES_A_JOUR: https://raw.githubusercontent.com/Exemple/essai/main/appcast.xml
            CLE_MISES_A_JOUR: %s
    ''' % CLE)

NOTES = textwrap.dedent('''\
    # Notes de version · Release notes

    ## 1.2.3

    **Français**

    - Une `commande` <nouvelle>,
      sur deux lignes.

    **English**

    - A new `command`.

    ## 1.2.2

    - Ancienne.
    ''')

# Les fausses commandes : elles notent leurs arguments dans FAUX_JOURNAL.
FAUX = {
    'xcodegen': 'import sys\n',
    'codesign': 'import sys\nif sys.argv[1:3] == ["-d", "-r-"]:\n'
                '    print(\'designated => identifier "fr.exemple.essai" and certificate leaf = H"0123abcd"\')\n',
    'security': 'import os\nprint(\'  1) 0123ABCD "%s" (CSSMERR_TP_NOT_TRUSTED)\' % os.environ.get("FAUSSE_IDENTITE", "Essai Inventee Signing"))\n',
    'xcrun': 'import sys\n',
    'spctl': 'import sys\n',
    'xcodebuild': textwrap.dedent('''\
        import os, plistlib, re, sys
        a = sys.argv[1:]
        dd = a[a.index('-derivedDataPath') + 1]
        reglages = dict(x.split('=', 1) for x in a if '=' in x and not x.startswith('-'))
        projet = open('project.yml').read()
        def lu(nom):
            return reglages.get(nom) or re.search(r'  Essai:\\n(?:.*\\n)*?\\s+%s: "?([^"\\n]+)"?' % nom, projet).group(1)
        app = os.path.join(dd, 'Build', 'Products', 'Release', 'Essai Inventee.app', 'Contents')
        os.makedirs(app, exist_ok=True)
        # Le code imbrique, comme celui de Sparkle : deux services XPC, une app, un executable, puis un autre cadre.
        b = os.path.join(app, 'Frameworks', 'Sparkle.framework', 'Versions', 'B')
        for d in ('XPCServices/Installer.xpc/Contents', 'XPCServices/Downloader.xpc/Contents', 'Updater.app/Contents'):
            os.makedirs(os.path.join(b, d), exist_ok=True)
        for f in ('Autoupdate', 'Sparkle'):
            open(os.path.join(b, f), 'w').close()
            os.chmod(os.path.join(b, f), 0o755)
        if not os.path.lexists(os.path.join(b, '..', 'Current')):
            os.symlink('B', os.path.join(b, '..', 'Current'))
        os.makedirs(os.path.join(app, 'Frameworks', 'Coeur.framework', 'Versions', 'A'), exist_ok=True)
        plistlib.dump({'CFBundleShortVersionString': lu('MARKETING_VERSION'),
                       'CFBundleVersion': reglages['CURRENT_PROJECT_VERSION'],
                       'SUFeedURL': lu('FLUX_MISES_A_JOUR'), 'SUPublicEDKey': lu('CLE_MISES_A_JOUR')},
                      open(os.path.join(app, 'Info.plist'), 'wb'))
        '''),
    'hdiutil': 'import sys\nopen(sys.argv[-1], "w").write("dmg invente " + " ".join(sys.argv[1:]))\n',
    'sign_update': 'import sys\nprint("U0lHTkFUVVJFLUlOVkVOVEVF")\n',
    'generate_keys': 'import os\nprint(os.environ["FAUSSE_CLE"])\n',
    'gh': 'import os, sys\nsys.exit(1 if sys.argv[1:3] == ["release", "view"] and not os.environ.get("FAUX_PUBLIEE") '
          'else 0)\n',
    'controles.py': 'import os, sys\nprint("trouve : " + os.environ.get("FAUX_TROUVE", "aucun"))\n'
                    'sys.exit(1 if os.environ.get("FAUX_TROUVE") else 0)\n',
}


def lire(chemin):
    with open(chemin, encoding='utf-8') as f:
        return f.read()


def ecrire(chemin, texte):
    with open(chemin, 'w', encoding='utf-8') as f:
        f.write(texte)


def git(depot, *args):
    return subprocess.run(['git', '-C', depot] + list(args), check=True, capture_output=True, text=True,
                          env=GIT_ENV).stdout.strip()


class Monde:
    """Un faux depot (et son origine), de fausses commandes, un dossier de produits."""

    def __init__(self, racine):
        self.racine = racine
        self.bin = os.path.join(racine, 'bin')
        self.journal = os.path.join(racine, 'journal.txt')
        os.makedirs(self.bin)
        for nom, corps in FAUX.items():
            chemin = os.path.join(self.bin, nom)
            ecrire(chemin, '#!/usr/bin/python3\nimport os, sys\n'
                           'open(os.environ["FAUX_JOURNAL"], "a").write(%r + " " + " ".join(sys.argv[1:]) + "\\n")\n'
                           % nom + corps)
            os.chmod(chemin, 0o755)
        self.origine = os.path.join(racine, 'origine.git')
        self.depot = os.path.join(racine, 'depot')
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', self.origine], check=True, env=GIT_ENV)
        subprocess.run(['git', 'clone', '-q', self.origine, self.depot], check=True, env=GIT_ENV,
                       capture_output=True)
        git(self.depot, 'config', 'user.name', 'Essai')
        git(self.depot, 'config', 'user.email', '0+essai@users.noreply.github.com')
        git(self.depot, 'checkout', '-q', '-b', 'main')
        ecrire(os.path.join(self.depot, 'project.yml'), PROJET)
        ecrire(os.path.join(self.depot, 'NOTES-VERSIONS.md'), NOTES)
        ecrire(os.path.join(self.depot, '.gitignore'), 'build/\n')
        for i in range(3):
            ecrire(os.path.join(self.depot, 'f%d.txt' % i), '%d\n' % i)
            git(self.depot, 'add', '-A')
            git(self.depot, 'commit', '-q', '-m', 'commit %d' % i)
        git(self.depot, 'push', '-q', 'origin', 'main')
        self.dd = os.path.join(racine, 'dd')
        self.env = {'GIT': 'git', 'XCODEGEN': self.bin + '/xcodegen', 'XCODEBUILD': self.bin + '/xcodebuild',
                    'HDIUTIL': self.bin + '/hdiutil', 'CODESIGN': self.bin + '/codesign', 'GH': self.bin + '/gh',
                    'SECURITY': self.bin + '/security', 'XCRUN': self.bin + '/xcrun', 'SPCTL': self.bin + '/spctl',
                    'SPARKLE_BIN': self.bin, 'CONTROLE_ANONYMISATION': self.bin + '/controles.py',
                    'TABLE_ANONYMISATION': self.journal}

    def appels(self):
        return lire(self.journal).splitlines() if os.path.exists(self.journal) else []

    def arguments(self, *extra):
        return P.arguments(['publier', '1.2.3', '--nom-app', 'Essai Inventee', '--fichier', 'Essai-Inventee',
                            '--depot-github', 'Exemple/essai', '--projet', 'Essai.xcodeproj', '--schema', 'Essai',
                            '--cible', 'Essai', '--textes', 'project.yml', '--sans-bureau', '--identite', IDENTITE,
                            '--etiquette', 'essai-v', '--flux', 'appcast.xml']
                           + list(extra))

    def publier(self, *extra, env=None):
        dedans = os.getcwd()
        os.chdir(self.depot)
        try:
            # Sans GIT_AUTHOR_* ni GIT_COMMITTER_* : le commit du flux prend l'auteur de la configuration du depot.
            e = {k: v for k, v in GIT_ENV.items() if not k.startswith(('GIT_AUTHOR', 'GIT_COMMITTER'))}
            e.update(FAUX_JOURNAL=self.journal, FAUSSE_CLE=CLE, DD=self.dd)
            e.update(env or {})
            with mock.patch.dict(os.environ, e, clear=True), contextlib.redirect_stdout(io.StringIO()):
                return P.publier(self.arguments(*extra), P.Outils(self.env),
                                 maintenant=datetime.datetime(2026, 10, 6, 12, 0, 0))
        finally:
            os.chdir(dedans)


class NumerosTests(unittest.TestCase):
    def test_version_valide(self):
        self.assertTrue(P.version_valide('1.0.0'))
        self.assertTrue(P.version_valide('12.30.4'))
        for v in ('1.0', 'v1.0.0', '1.0.0-beta', '1.0.0 ', ''):
            self.assertFalse(P.version_valide(v), v)

    def test_reglages_de_la_cible(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, 'project.yml')
            ecrire(p, PROJET)
            self.assertEqual(P.reglage(p, 'Essai', 'MARKETING_VERSION'), '1.2.3')
            self.assertEqual(P.reglage(p, 'Compagnon', 'MARKETING_VERSION'), '1.0', 'chaque cible la sienne')
            self.assertEqual(P.reglage(p, 'Essai', 'CLE_MISES_A_JOUR'), CLE)
            self.assertEqual(P.systeme_minimum(p), '26.0')
            with self.assertRaises(P.Refus):
                P.reglage(p, 'Absente', 'MARKETING_VERSION')
            with self.assertRaises(P.Refus):
                P.reglage(p, 'Compagnon', 'CLE_MISES_A_JOUR')

    def test_numero_de_compilation(self):
        with tempfile.TemporaryDirectory() as d:
            subprocess.run(['git', 'init', '-q', d], check=True, env=GIT_ENV)
            for i in range(4):
                git(d, 'commit', '-q', '--allow-empty', '-m', str(i))
            self.assertEqual(P.numero_compilation(d), 4)


class NotesEtFluxTests(unittest.TestCase):
    def test_notes_de_la_version(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, 'NOTES-VERSIONS.md')
            ecrire(p, NOTES)
            n = P.notes(p, '1.2.3')
            self.assertTrue(n.startswith('**Français**'))
            self.assertNotIn('Ancienne', n)
            self.assertEqual(P.notes(p, '1.2.2'), '- Ancienne.\n')
            with self.assertRaises(P.Refus):
                P.notes(p, '9.9.9')

    def test_notes_html(self):
        h = P.notes_html('**Français**\n\n- Une `commande` <nouvelle>,\n  sur deux lignes.\n\n**English**\n\n- B\n')
        self.assertEqual(h, '<p><strong>Français</strong></p>\n'
                            '<ul><li>Une <code>commande</code> &lt;nouvelle&gt;, sur deux lignes.</li></ul>\n'
                            '<p><strong>English</strong></p>\n<ul><li>B</li></ul>')

    def item(self, version='1.2.3', numero=57):
        return P.item_flux(version, numero, 'https://exemple.invalid/essai-v%s/Essai-Inventee-%s.dmg' % (version, version),
                           123456, 'U0lHTkFUVVJF', '26.0', '<p>Notes</p>', datetime.datetime(2026, 10, 6, 12, 0, 0))

    def test_flux_neuf_valeurs_inventees(self):
        xml = P.ajouter_au_flux(None, 'Essai Inventee', '1.2.3', self.item())
        self.assertEqual(xml, textwrap.dedent('''\
            <?xml version="1.0" encoding="utf-8"?>
            <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
              <channel>
                <title>Essai Inventee</title>
                <item>
                  <title>1.2.3</title>
                  <pubDate>Tue, 06 Oct 2026 12:00:00 +0000</pubDate>
                  <sparkle:version>57</sparkle:version>
                  <sparkle:shortVersionString>1.2.3</sparkle:shortVersionString>
                  <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
                  <description><![CDATA[
            <p>Notes</p>
            ]]></description>
                  <enclosure url="https://exemple.invalid/essai-v1.2.3/Essai-Inventee-1.2.3.dmg" length="123456" type="application/octet-stream" sparkle:edSignature="U0lHTkFUVVJF"/>
                </item>
              </channel>
            </rss>
            '''))
        s = '{%s}' % P.ESPACE_SPARKLE
        item = ET.fromstring(xml).find('channel/item')
        self.assertEqual(item.find(s + 'version').text, '57')
        self.assertEqual(item.find(s + 'shortVersionString').text, '1.2.3')
        self.assertEqual(item.find('enclosure').get(s + 'edSignature'), 'U0lHTkFUVVJF')
        self.assertEqual(item.find('description').text.strip(), '<p>Notes</p>')

    def test_une_version_de_plus_en_tete(self):
        """Le flux garde toutes les versions publiees, la nouvelle en tete."""
        un = P.ajouter_au_flux(None, 'Essai Inventee', '1.2.2', self.item('1.2.2', 56))
        deux = P.ajouter_au_flux(un, 'Essai Inventee', '1.2.3', self.item('1.2.3', 57))
        s = '{%s}' % P.ESPACE_SPARKLE
        items = ET.fromstring(deux).findall('channel/item')
        self.assertEqual([i.find(s + 'shortVersionString').text for i in items], ['1.2.3', '1.2.2'])
        self.assertEqual([i.find(s + 'version').text for i in items], ['57', '56'])
        self.assertEqual(deux.replace(self.item('1.2.3', 57), ''), un, 'le reste du flux ne change pas')
        with self.assertRaises(P.Refus):
            P.ajouter_au_flux(deux, 'Essai Inventee', '1.2.2', self.item('1.2.2', 58))


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.dossier = os.path.realpath(tempfile.mkdtemp())
        self.m = Monde(self.dossier)

    def tearDown(self):
        shutil.rmtree(self.dossier)

    def refuse(self, *extra, env=None, motif, etiquette=''):
        with self.assertRaises(P.Refus) as r:
            self.m.publier(*extra, env=env)
        self.assertIn(motif, str(r.exception))
        appels = self.m.appels()
        self.assertFalse([a for a in appels if a.startswith('gh release create')], 'rien de publie')
        self.assertEqual(git(self.m.depot, 'tag', '-l'), etiquette, 'aucune etiquette nouvelle')
        self.assertEqual(git(self.m.origine, 'tag', '-l'), '', 'rien de pousse')
        return appels

    def commit(self, fichier, texte):
        ecrire(os.path.join(self.m.depot, fichier), texte)
        git(self.m.depot, 'commit', '-q', '-am', 'changement')
        git(self.m.depot, 'push', '-q', 'origin', 'main')

    def test_repetition(self):
        sortie = os.path.join(self.dossier, 'repetition')
        self.m.publier('--repetition', sortie, '--url-base', 'http://127.0.0.1:8123', '--cle-privee', 'cle.txt',
                       '--cle-publique', AUTRE_CLE, '--sans-tests')
        flux = os.path.join(self.m.depot, 'appcast.xml')
        item = ET.parse(flux).getroot().find('channel/item')
        s = '{%s}' % P.ESPACE_SPARKLE
        self.assertEqual(item.find(s + 'version').text, '3', 'trois commits')
        enc = item.find('enclosure')
        self.assertEqual(enc.get('url'),
                         'http://127.0.0.1:8123/Exemple/essai/releases/download/essai-v1.2.3/Essai-Inventee-1.2.3.dmg')
        self.assertEqual(git(self.m.depot, 'log', '-1', '--format=%s'),
                         'Publier Essai Inventee 1.2.3 dans le flux des mises a jour', 'commite dans la copie')
        self.assertEqual(git(self.m.depot, 'status', '--porcelain'), '')
        self.assertEqual(git(self.m.origine, 'rev-list', '--count', 'main'), '3', 'rien de pousse')
        self.assertEqual(enc.get(s + 'edSignature'), 'U0lHTkFUVVJFLUlOVkVOVEVF')
        dmg = os.path.join(sortie, 'Essai-Inventee-1.2.3.dmg')
        self.assertEqual(int(enc.get('length')), os.path.getsize(dmg))
        self.assertIn('-volname Essai Inventee 1.2.3', lire(dmg))
        appels = self.m.appels()
        build = [a for a in appels if a.startswith('xcodebuild')][0]
        for r in ('-configuration Release', 'CURRENT_PROJECT_VERSION=3', 'CODE_SIGN_IDENTITY=-', 'DEVELOPMENT_TEAM= ',
                  'FLUX_MISES_A_JOUR=http://127.0.0.1:8123/Exemple/essai/main/appcast.xml',
                  'CLE_MISES_A_JOUR=' + AUTRE_CLE):
            self.assertIn(r, build)
        self.assertIn('sign_update --ed-key-file cle.txt -p ' + dmg, appels)
        self.assertFalse([a for a in appels if a.startswith(('gh ', 'generate_keys'))], 'ni GitHub ni trousseau')
        controle = [a for a in appels if a.startswith('controles.py')][0]
        self.assertIn('NOTES-VERSIONS.md', controle)
        self.assertIn(os.path.join(sortie, 'appcast.xml'), controle)
        self.assertIn('project.yml', controle)
        self.assertEqual(git(self.m.depot, 'tag', '-l'), '')

    def test_repetition_avec_la_cle_du_trousseau(self):
        """Sans paire d'essai : la cle publique de project.yml, celle du trousseau, et la signature par le trousseau."""
        sortie = os.path.join(self.dossier, 'repetition')
        self.m.publier('--repetition', sortie, '--url-base', 'http://127.0.0.1:8123', '--sans-tests')
        appels = self.m.appels()
        self.assertIn('generate_keys -p', appels)
        self.assertIn('sign_update -p ' + os.path.join(sortie, 'Essai-Inventee-1.2.3.dmg'), appels)
        build = [a for a in appels if a.startswith('xcodebuild')][0]
        self.assertIn('FLUX_MISES_A_JOUR=http://127.0.0.1:8123/Exemple/essai/main/appcast.xml', build)
        self.assertNotIn('CLE_MISES_A_JOUR=', build, 'la cle de project.yml')
        self.assertFalse([a for a in appels if a.startswith('gh ')])
        self.assertEqual(git(self.m.depot, 'tag', '-l'), '')

    def test_publication(self):
        self.m.publier()
        appels = self.m.appels()
        self.assertEqual(git(self.m.origine, 'tag', '-l'), 'essai-v1.2.3', 'etiquette de l\'app, poussee')
        dmg = os.path.join(self.m.depot, 'build', 'publication', '1.2.3', 'Essai-Inventee-1.2.3.dmg')
        cree = [a for a in appels if a.startswith('gh release create')]
        self.assertEqual(len(cree), 1)
        self.assertIn('essai-v1.2.3 %s -R Exemple/essai' % dmg, cree[0], 'le .dmg seul')
        self.assertIn('--title Essai Inventee 1.2.3', cree[0])
        self.assertIn('sign_update -p ' + dmg, appels, 'cle du trousseau')
        # Le flux, dans le depot, commite puis pousse sur main, apres la version publiee.
        flux = lire(os.path.join(self.m.depot, 'appcast.xml'))
        self.assertEqual(git(self.m.origine, 'show', 'main:appcast.xml') + '\n', flux)
        self.assertEqual(git(self.m.origine, 'log', '-1', '--format=%an %ae', 'main'),
                         'Essai 0+essai@users.noreply.github.com', 'l\'auteur du depot, adresse noreply')
        message = git(self.m.origine, 'log', '-1', '--format=%B', 'main')
        self.assertEqual(message, 'Publier Essai Inventee 1.2.3 dans le flux des mises a jour\n\n'
                                  'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')
        self.assertEqual(git(self.m.origine, 'show', '--name-only', '--format=', 'main'), 'appcast.xml')
        self.assertEqual(git(self.m.depot, 'status', '--porcelain'), '')
        controle = [a for a in appels if a.startswith('controles.py')][0]
        self.assertIn('message-commit.txt', controle, 'le message passe aussi le controle')
        self.assertIn('https://github.com/Exemple/essai/releases/download/essai-v1.2.3/Essai-Inventee-1.2.3.dmg', flux)
        self.assertIn('<li>A new <code>command</code>.</li>', flux)
        with open(os.path.join(self.m.dd, 'Build', 'Products', 'Release', 'Essai Inventee.app', 'Contents',
                               'Info.plist'), 'rb') as f:
            info = plistlib.load(f)
        self.assertEqual(info['CFBundleVersion'], '3')

    def signatures(self):
        """Les signatures du code, dans l'ordre : le chemin signe, depuis le dossier des produits."""
        base = os.path.join(self.m.dd, 'Build', 'Products', 'Release') + '/'
        return [a[a.index(base) + len(base):].replace('Essai Inventee.app/Contents/Frameworks/', '')
                for a in self.m.appels() if a.startswith('codesign --force')]

    def test_signature_du_code(self):
        """Le code imbrique d'abord, du plus profond au moins profond, chaque cadre apres son contenu, l'app en
        dernier ; avec l'identite donnee, le runtime renforce, les droits gardes ; puis l'exigence de signature."""
        self.m.publier()
        self.assertEqual(self.signatures(), [
            'Coeur.framework',
            'Sparkle.framework/Versions/Current/XPCServices/Downloader.xpc',
            'Sparkle.framework/Versions/Current/XPCServices/Installer.xpc',
            'Sparkle.framework/Versions/Current/Autoupdate',
            'Sparkle.framework/Versions/Current/Updater.app',
            'Sparkle.framework',
            'Essai Inventee.app'])
        appels = [a for a in self.m.appels() if a.startswith('codesign --force')]
        for a in appels:
            self.assertIn('--sign %s --options runtime --preserve-metadata=entitlements --timestamp=none' % IDENTITE, a)
            self.assertNotIn('--keychain', a)
        sortie = os.path.join(self.m.depot, 'build', 'publication', '1.2.3')
        self.assertIn('certificate leaf', lire(os.path.join(sortie, 'exigence.txt')))

    def test_signature_dans_un_trousseau_a_part(self):
        """En repetition, un certificat d'essai dans un trousseau a part : codesign et security y cherchent."""
        sortie = os.path.join(self.dossier, 'repetition')
        self.m.publier('--repetition', sortie, '--url-base', 'http://127.0.0.1:8123', '--cle-privee', 'cle.txt',
                       '--cle-publique', AUTRE_CLE, '--sans-tests', '--trousseau', '/tmp/essai.keychain-db')
        appels = self.m.appels()
        self.assertIn('security find-identity -p codesigning /tmp/essai.keychain-db', appels)
        signe = [a for a in appels if a.startswith('codesign --force')]
        self.assertEqual(len(signe), 7)
        self.assertTrue(all('--keychain /tmp/essai.keychain-db' in a for a in signe))

    def test_refus_identite_absente(self):
        appels = self.refuse(env={'FAUSSE_IDENTITE': 'Autre Signing'}, motif='identite de signature')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_notarisation_pas_par_defaut(self):
        self.m.publier()
        self.assertFalse([a for a in self.m.appels() if a.startswith(('xcrun', 'spctl'))])

    def test_refus_notarisation_sans_profil(self):
        appels = self.refuse(env={'NOTARISER': '1'}, motif='PROFIL_NOTARISATION')
        self.assertFalse([a for a in appels if a.startswith(('xcodebuild', 'xcrun'))], 'rien de compile ni soumis')

    def test_notarisation(self):
        """NOTARISER=1 : signatures horodatees, le .dmg signe, soumis, agrafe, evalue, puis signe par Sparkle (la
        signature Ed25519 porte sur le .dmg agrafe)."""
        self.m.publier(env={'NOTARISER': '1', 'PROFIL_NOTARISATION': 'profil-essai'})
        appels = self.m.appels()
        dmg = os.path.join(self.m.depot, 'build', 'publication', '1.2.3', 'Essai-Inventee-1.2.3.dmg')
        signe = [a for a in appels if a.startswith('codesign --force')]
        self.assertTrue(all('--timestamp ' in a and '--timestamp=none' not in a for a in signe))
        suite = [a for a in appels if a.startswith(('xcrun', 'spctl', 'sign_update')) or a.endswith(' ' + dmg)
                 and a.startswith('codesign')]
        self.assertEqual(suite, [
            'codesign --force --sign %s --timestamp %s' % (IDENTITE, dmg),
            'xcrun notarytool submit %s --keychain-profile profil-essai --wait' % dmg,
            'xcrun stapler staple %s' % dmg,
            'spctl --assess --type open --context context:primary-signature --verbose %s' % dmg,
            'sign_update -p %s' % dmg])

    def test_refus_version_differente(self):
        self.commit('project.yml', PROJET.replace('"1.2.3"', '"1.2.4"'))
        appels = self.refuse(motif='MARKETING_VERSION')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_refus_arbre_pas_propre(self):
        ecrire(os.path.join(self.m.depot, 'oubli.txt'), 'x\n')
        self.refuse(motif='propre')

    def test_refus_etiquette_existante(self):
        git(self.m.depot, 'tag', 'essai-v1.2.3')
        self.refuse(motif='existe deja', etiquette='essai-v1.2.3')

    def test_etiquette_d_une_autre_app(self):
        """L'etiquette d'une autre app du meme depot, au meme numero, ne gene pas."""
        git(self.m.depot, 'tag', 'autre-v1.2.3')
        git(self.m.depot, 'push', '-q', 'origin', 'autre-v1.2.3')
        self.m.publier()
        self.assertEqual(git(self.m.origine, 'tag', '-l').split(), ['autre-v1.2.3', 'essai-v1.2.3'])

    def test_ajout_a_un_flux_existant(self):
        """Le flux du depot garde les versions d'avant : la nouvelle s'ajoute en tete."""
        ancien = P.ajouter_au_flux(None, 'Essai Inventee', '1.2.2', P.item_flux(
            '1.2.2', 2, 'https://github.com/Exemple/essai/releases/download/essai-v1.2.2/Essai-Inventee-1.2.2.dmg',
            10, 'QU5DSUVOTkU=', '26.0', '<p>Ancienne</p>', datetime.datetime(2026, 10, 1)))
        ecrire(os.path.join(self.m.depot, 'appcast.xml'), ancien)
        git(self.m.depot, 'add', 'appcast.xml')
        git(self.m.depot, 'commit', '-q', '-m', 'flux')
        git(self.m.depot, 'push', '-q', 'origin', 'main')
        self.m.publier()
        s = '{%s}' % P.ESPACE_SPARKLE
        items = ET.fromstring(lire(os.path.join(self.m.depot, 'appcast.xml'))).findall('channel/item')
        self.assertEqual([i.find(s + 'shortVersionString').text for i in items], ['1.2.3', '1.2.2'])
        self.assertEqual(items[0].find(s + 'version').text, '4')

    def test_refus_auteur_sans_adresse_noreply(self):
        """Le commit du flux est public : son auteur porte l'adresse noreply de GitHub, jamais une vraie."""
        git(self.m.depot, 'config', 'user.email', 'essai@example.invalid')
        appels = self.refuse(motif='noreply')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_refus_version_deja_dans_le_flux(self):
        ancien = P.ajouter_au_flux(None, 'Essai Inventee', '1.2.3', P.item_flux(
            '1.2.3', 2, 'https://exemple.invalid/x.dmg', 10, 'QQ==', '26.0', '', datetime.datetime(2026, 10, 1)))
        ecrire(os.path.join(self.m.depot, 'appcast.xml'), ancien)
        git(self.m.depot, 'add', 'appcast.xml')
        git(self.m.depot, 'commit', '-q', '-m', 'flux')
        git(self.m.depot, 'push', '-q', 'origin', 'main')
        appels = self.refuse(motif='deja dans le flux')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_refus_adresse_du_flux(self):
        """L'app doit lire le flux a l'adresse brute du depot, celle ou publier.sh le pousse."""
        self.commit('project.yml', PROJET.replace('raw.githubusercontent.com/Exemple/essai/main/appcast.xml',
                                                  'github.com/Exemple/essai/releases/latest/download/appcast.xml'))
        self.refuse(motif='FLUX_MISES_A_JOUR')

    def test_refus_hors_de_main(self):
        git(self.m.depot, 'checkout', '-q', '-b', 'autre')
        self.refuse(motif='depuis main')

    def test_refus_main_pas_a_jour(self):
        ecrire(os.path.join(self.m.depot, 'f0.txt'), 'local\n')
        git(self.m.depot, 'commit', '-q', '-am', 'pas pousse')
        self.refuse(motif='a jour')

    def test_refus_deja_publiee(self):
        self.refuse(env={'FAUX_PUBLIEE': '1'}, motif='deja publiee')

    def test_refus_notes_absentes(self):
        self.commit('NOTES-VERSIONS.md', NOTES.replace('## 1.2.3', '## 1.2.1'))
        self.refuse(motif='pas de section 1.2.3')

    def test_refus_cle_du_trousseau_differente(self):
        appels = self.refuse(env={'FAUSSE_CLE': AUTRE_CLE}, motif='trousseau')
        self.assertIn('generate_keys -p', appels)

    def test_refus_tests_en_echec(self):
        appels = self.refuse('--test', 'exit 3', motif='tests en echec')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_refus_sans_tests_hors_repetition(self):
        self.refuse('--sans-tests', motif='repetition')

    def test_refus_controle_d_anonymisation(self):
        appels = self.refuse(env={'FAUX_TROUVE': '1'}, motif='anonymisation')
        self.assertTrue([a for a in appels if a.startswith('sign_update')], 'le controle passe apres la signature')
        self.assertFalse(os.path.exists(os.path.join(self.m.depot, 'appcast.xml')), 'le flux du depot ne change pas')
        self.assertEqual(git(self.m.depot, 'status', '--porcelain'), '')

    def test_controle_absent(self):
        self.m.env['CONTROLE_ANONYMISATION'] = os.path.join(self.dossier, 'absent.py')
        self.m.publier()
        self.assertEqual(git(self.m.origine, 'tag', '-l'), 'essai-v1.2.3')

    def test_arguments_de_la_repetition(self):
        with mock.patch('sys.stderr'):
            with self.assertRaises(SystemExit):
                P.arguments(['publier', '1.2.3', '--nom-app', 'A', '--fichier', 'A', '--depot-github', 'E/a',
                             '--projet', 'A.xcodeproj', '--schema', 'A', '--cible', 'A', '--repetition', 'x'])
            with self.assertRaises(SystemExit):
                P.arguments(['publier', '1.2.3', '--nom-app', 'A', '--fichier', 'A', '--depot-github', 'E/a',
                             '--projet', 'A.xcodeproj', '--schema', 'A', '--cible', 'A', '--repetition', 'x',
                             '--url-base', 'http://127.0.0.1:1', '--cle-privee', 'k'])
            with self.assertRaises(SystemExit):
                P.arguments(['publier', '1.2.3', '--nom-app', 'A', '--fichier', 'A', '--depot-github', 'E/a',
                             '--projet', 'A.xcodeproj', '--schema', 'A', '--cible', 'A', '--cle-privee', 'k',
                             '--cle-publique', CLE])


if __name__ == '__main__':
    unittest.main()
```

Run : `W=$S/deploiement-exec; cd "$W/maillage" && /usr/bin/python3 -m unittest discover -s outils/tests 2>&1 | tail -3`

Expected : `Ran 4 tests`, `FAILED (errors=1)` (pas de module `publication`).

- [ ] **Step 2 : la publication** (`--etapes 2`).

`outils/publication.py` :

```python
#!/usr/bin/env python3
"""Publication d'une version de l'app (spec du deploiement, section 3), appelee par publier.sh.

  publication.py publier X.Y.Z --nom-app N --fichier F --depot-github D --projet P --schema S --cible C
                 --identite NOM --etiquette PREFIXE --flux CHEMIN [--test CMD]... [--textes FICHIER]... [--sans-bureau]
                 [--repetition DOSSIER --url-base URL [--cle-privee FICHIER --cle-publique CLE] [--trousseau T]
                  [--sans-tests]]

Dans l'ordre, et rien n'est publie si une etape echoue :
  1. les verifications : la version est X.Y.Z, celle de MARKETING_VERSION ; l'arbre est propre ; main, a jour avec
     GitHub ; l'etiquette de l'app (PREFIXE suivi de X.Y.Z, par exemple maillage-v1.0.0) et sa version publiee
     n'existent pas, ni la version dans le flux ; l'app lit le flux a l'adresse brute du depot
     (https://raw.githubusercontent.com/<depot>/main/<CHEMIN>) ; NOTES-VERSIONS.md a sa section ; la cle publique
     de l'app est celle du trousseau ; l'identite de signature y est ; les tests passent ;
  2. les numeros : la version, et le numero de compilation, le nombre de commits de main ;
  3. la compilation Release, ad hoc (une equipe de Local.xcconfig n'y entre pas), puis signee avec l'identite
     donnee (un certificat auto-signe stable, plus tard un Developer ID) : le code imbrique d'abord, le runtime
     renforce, les droits gardes ; l'exigence de signature (codesign -d -r-) est ecrite dans exigence.txt ;
  4. le .dmg (hdiutil) : l'app et un raccourci vers Applications ; avec NOTARISER=1 seulement (desactive par
     defaut), le .dmg signe, soumis a Apple (notarytool, profil PROFIL_NOTARISATION du trousseau), agrafe
     (stapler) et evalue (spctl) ;
  5. la signature Ed25519 du .dmg (sign_update de Sparkle, cle du trousseau), puis le flux : le fichier CHEMIN du
     depot (appcast.xml), qui garde toutes les versions publiees, la nouvelle en tete ; l'adresse de chaque .dmg est
     celle de sa version publiee ;
  6. le controle d'anonymisation (prive), s'il est present, sur les notes, le flux, le message du commit du flux et
     les textes de l'app ;
  7. l'etiquette, poussee, puis la version publiee sur GitHub (gh release create), avec le .dmg ; puis le flux,
     commite sur main (git add de ce seul fichier) et pousse aussitot ;
  8. le .dmg copie sur le Bureau (sauf --sans-bureau).

En repetition (--repetition DOSSIER), ni GitHub, ni etiquette, ni Bureau : la branche peut etre une autre que main ;
--url-base tient lieu des deux adresses de GitHub (le flux : <URL>/<depot>/main/<CHEMIN> ; un .dmg :
<URL>/<depot>/releases/download/<etiquette>/<fichier>), comme les servirait un serveur local ; le flux est commite
dans la copie, sans etre pousse ; les produits vont dans DOSSIER. Avec --cle-privee et --cle-publique, une paire
d'essai, sans le trousseau : l'app porte cette cle publique, et le .dmg est signe avec la cle privee du fichier.
Sans elles, la cle du trousseau, comme pour la vraie publication. Avec --trousseau, l'identite de signature est
cherchee dans ce trousseau a part (un certificat d'essai), jamais dans celui de la session.

Les commandes externes se remplacent par l'environnement, pour les tests : XCODEGEN, XCODEBUILD, HDIUTIL, CODESIGN,
SECURITY, XCRUN, SPCTL, SPARKLE_BIN (dossier de sign_update et generate_keys), GH, GIT, CONTROLE_ANONYMISATION et
TABLE_ANONYMISATION. Aucun identifiant Apple, Team ID ni mot de passe n'est ecrit ici : la notarisation lit le
profil que notarytool store-credentials a range dans le trousseau.
"""
import argparse
import datetime
import html
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys

VERSION = re.compile(r'^\d+\.\d+\.\d+$')
ESPACE_SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
PRIVE = os.path.expanduser('~/Dev/maillage-thread/.superpowers/anonymisation')


class Refus(Exception):
    """Une verification qui arrete la publication, avant tout changement."""


def lire(chemin):
    with open(chemin, encoding='utf-8') as f:
        return f.read()


def ecrire(chemin, texte):
    with open(chemin, 'w', encoding='utf-8') as f:
        f.write(texte)


# --- les numeros ---------------------------------------------------------------------------------------------

def version_valide(v):
    return bool(VERSION.match(v))


def bloc_cible(projet_yml, cible):
    """Les lignes de la cible `cible` de project.yml (XcodeGen) : de « targets: », la cible a deux espaces de
    retrait, jusqu'a la suivante."""
    lignes = lire(projet_yml).splitlines()
    try:
        debut = lignes.index('targets:')
        i = lignes.index('  %s:' % cible, debut)
    except ValueError:
        raise Refus('cible %s introuvable dans %s' % (cible, projet_yml))
    bloc = []
    for l in lignes[i + 1:]:
        if re.match(r'^ {0,2}\S', l):
            break
        bloc.append(l)
    return bloc


def reglage(projet_yml, cible, nom):
    """La valeur d'un reglage de la cible (« NOM: valeur », guillemets otes)."""
    for l in bloc_cible(projet_yml, cible):
        m = re.match(r'^\s+%s:\s*(.+?)\s*$' % re.escape(nom), l)
        if m:
            return m.group(1).strip('"')
    raise Refus('%s absent de la cible %s' % (nom, cible))


def systeme_minimum(projet_yml):
    """La version minimale de macOS (options.deploymentTarget.macOS)."""
    m = re.search(r'^options:\n(?:  .*\n)*?  deploymentTarget:\n    macOS: "?([\d.]+)"?', lire(projet_yml), re.M)
    if not m:
        raise Refus('deploymentTarget.macOS absent de ' + projet_yml)
    return m.group(1)


def numero_compilation(depot, git='git'):
    """Le numero de compilation (CFBundleVersion), que compare Sparkle : le nombre de commits jusqu'a HEAD."""
    return int(subprocess.run([git, '-C', depot, 'rev-list', '--count', 'HEAD'], check=True, capture_output=True,
                              text=True).stdout.strip())


# --- les notes et le flux ------------------------------------------------------------------------------------

def notes(chemin, version):
    """La section « ## X.Y.Z » de NOTES-VERSIONS.md, sans son titre."""
    texte = lire(chemin)
    m = re.search(r'^## %s[ \t]*\n(.*?)(?=^## |\Z)' % re.escape(version), texte, re.M | re.S)
    if not m or not m.group(1).strip():
        raise Refus('pas de section %s dans %s' % (version, chemin))
    return m.group(1).strip() + '\n'


def en_ligne(t):
    t = html.escape(t, quote=False)
    t = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)
    return re.sub(r'`(.+?)`', r'<code>\1</code>', t)


def notes_html(texte):
    """Les notes en HTML simple, pour la fenetre de Sparkle : paragraphes, listes « - », gras et code."""
    sortie, liste, para = [], [], []

    def fermer():
        if para:
            sortie.append('<p>%s</p>' % en_ligne(' '.join(para)))
            para.clear()
        if liste:
            sortie.append('<ul>%s</ul>' % ''.join('<li>%s</li>' % en_ligne(e) for e in liste))
            liste.clear()

    for l in texte.splitlines():
        s = l.strip()
        if not s:
            fermer()
        elif s.startswith('- '):
            if para:
                fermer()
            liste.append(s[2:])
        elif liste and l.startswith('  '):
            liste[-1] += ' ' + s
        else:
            if liste:
                fermer()
            para.append(s)
    fermer()
    return '\n'.join(sortie)


def item_flux(version, numero, url, taille, signature, systeme, notes_html_, date):
    """Une version dans le flux de Sparkle : un <item>, avec son retrait et sa fin de ligne."""
    return '''    <item>
      <title>%s</title>
      <pubDate>%s</pubDate>
      <sparkle:version>%d</sparkle:version>
      <sparkle:shortVersionString>%s</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>%s</sparkle:minimumSystemVersion>
      <description><![CDATA[
%s
]]></description>
      <enclosure url="%s" length="%d" type="application/octet-stream" sparkle:edSignature="%s"/>
    </item>
''' % (html.escape(version), date.strftime('%a, %d %b %Y %H:%M:%S +0000'), numero, html.escape(version),
       html.escape(systeme), notes_html_.replace(']]>', ']]&gt;'), html.escape(url), taille, html.escape(signature))


def ajouter_au_flux(existant, titre, version, item):
    """Le flux (appcast.xml) avec une version de plus, en tete : il garde toutes les versions publiees. Sans flux
    existant (None), un flux neuf. Refus si la version y est deja."""
    if existant is None:
        return '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="%s">
  <channel>
    <title>%s</title>
%s  </channel>
</rss>
''' % (ESPACE_SPARKLE, html.escape(titre), item)
    if '<sparkle:shortVersionString>%s</sparkle:shortVersionString>' % html.escape(version) in existant:
        raise Refus('la version %s est deja dans le flux' % version)
    i = existant.find('    <item>')
    if i < 0:
        i = existant.find('  </channel>')
    if i < 0:
        raise Refus('flux illisible : ni <item>, ni </channel>')
    return existant[:i] + item + existant[i:]


def message_flux(nom_app, version):
    """Le message du commit du flux, en francais sans accents."""
    return ('Publier %s %s dans le flux des mises a jour\n\n'
            'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n' % (nom_app, version))


# --- la publication ------------------------------------------------------------------------------------------

class Outils:
    """Les commandes externes, remplacables par l'environnement (tests)."""

    def __init__(self, env=None):
        e = os.environ if env is None else env
        sparkle = e.get('SPARKLE_BIN', '')
        self.git = e.get('GIT', 'git')
        self.xcodegen = e.get('XCODEGEN', 'xcodegen')
        self.xcodebuild = e.get('XCODEBUILD', 'xcodebuild')
        self.hdiutil = e.get('HDIUTIL', 'hdiutil')
        self.codesign = e.get('CODESIGN', 'codesign')
        self.security = e.get('SECURITY', 'security')
        self.xcrun = e.get('XCRUN', 'xcrun')
        self.spctl = e.get('SPCTL', 'spctl')
        self.gh = e.get('GH', 'gh')
        self.sign_update = os.path.join(sparkle, 'sign_update') if sparkle else 'sign_update'
        self.generate_keys = os.path.join(sparkle, 'generate_keys') if sparkle else 'generate_keys'
        self.controle = e.get('CONTROLE_ANONYMISATION', os.path.join(PRIVE, 'outils', 'controles.py'))
        self.table = e.get('TABLE_ANONYMISATION', os.path.join(PRIVE, 'execution', 'table.json'))


def lancer(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw).stdout


def dire(texte):
    print(texte, flush=True)


def verifier(a, o, racine_git, version):
    """L'etape 1 : tout ce qui doit tenir avant de compiler. Leve Refus."""
    if not version_valide(version):
        raise Refus('version attendue sous la forme X.Y.Z : ' + version)
    marketing = reglage('project.yml', a.cible, 'MARKETING_VERSION')
    if marketing != version:
        raise Refus('MARKETING_VERSION de project.yml : %s, pas %s' % (marketing, version))
    if lancer([o.git, 'status', '--porcelain']).strip():
        raise Refus("l'arbre n'est pas propre (git status)")
    auteur = subprocess.run([o.git, 'config', 'user.email'], capture_output=True, text=True).stdout.strip()
    if not auteur.endswith('@users.noreply.github.com'):
        raise Refus("le commit du flux est public : l'adresse de l'auteur (git config user.email) doit etre "
                    "l'adresse noreply de GitHub")
    etiquette = a.etiquette + version
    if lancer([o.git, 'tag', '-l', etiquette]).strip():
        raise Refus("l'etiquette %s existe deja" % etiquette)
    if os.path.exists(a.flux):
        ajouter_au_flux(lire(a.flux), a.nom_app, version, '')
    adresse = 'https://raw.githubusercontent.com/%s/main/%s' % (a.depot_github, chemin_depot(a.flux, racine_git))
    if reglage('project.yml', a.cible, 'FLUX_MISES_A_JOUR') != adresse:
        raise Refus('FLUX_MISES_A_JOUR de project.yml : %s attendu (le flux du depot)' % adresse)
    if not a.repetition:
        branche = lancer([o.git, 'rev-parse', '--abbrev-ref', 'HEAD']).strip()
        if branche != 'main':
            raise Refus('la publication se fait depuis main, pas ' + branche)
        lancer([o.git, 'fetch', '-q', 'origin', 'main'])
        if lancer([o.git, 'rev-parse', 'HEAD']) != lancer([o.git, 'rev-parse', 'origin/main']):
            raise Refus("main n'est pas a jour avec GitHub (origin/main)")
        if lancer([o.git, 'ls-remote', '--tags', 'origin', etiquette]).strip():
            raise Refus("l'etiquette %s existe deja sur GitHub" % etiquette)
        if subprocess.run([o.gh, 'release', 'view', etiquette, '-R', a.depot_github],
                          capture_output=True).returncode == 0:
            raise Refus('la version %s est deja publiee sur GitHub' % etiquette)
    notes('NOTES-VERSIONS.md', version)
    cle = reglage('project.yml', a.cible, 'CLE_MISES_A_JOUR')
    if a.cle_publique:
        cle_attendue = a.cle_publique
    else:
        cle_attendue = lancer([o.generate_keys, '-p']).strip()
        if cle != cle_attendue:
            raise Refus('la cle publique de project.yml (CLE_MISES_A_JOUR) differe de celle du trousseau')
    if not re.match(r'^[A-Za-z0-9+/]{43}=$', cle_attendue or ''):
        raise Refus('cle publique Ed25519 invalide : %s' % cle_attendue)
    if a.sans_tests and not a.repetition:
        raise Refus('--sans-tests seulement en repetition')
    identites = lancer([o.security, 'find-identity', '-p', 'codesigning'] + ([a.trousseau] if a.trousseau else []))
    if '"%s"' % a.identite not in identites:
        raise Refus('identite de signature introuvable dans le trousseau : %s' % a.identite)
    if notariser() and not os.environ.get('PROFIL_NOTARISATION'):
        raise Refus('NOTARISER=1 demande PROFIL_NOTARISATION, le profil de notarytool store-credentials')
    return marketing


def chemin_depot(chemin, racine_git):
    """Le chemin d'un fichier depuis la racine du depot (celui de l'adresse brute du flux)."""
    return os.path.relpath(os.path.realpath(chemin), os.path.realpath(racine_git))


def notariser():
    """La notarisation (Developer ID), desactivee par defaut : NOTARISER=1 l'active."""
    return os.environ.get('NOTARISER') == '1'


def code_imbrique(app):
    """Le code a signer avant l'app, dans l'ordre : pour chaque cadre de Contents/Frameworks, ce qu'il contient
    (services XPC, apps, executables), du plus profond au moins profond, puis le cadre lui-meme."""
    cadres = os.path.join(app, 'Contents', 'Frameworks')
    liste = []
    for nom in sorted(os.listdir(cadres)) if os.path.isdir(cadres) else []:
        cadre = os.path.join(cadres, nom)
        if not nom.endswith('.framework'):
            liste.append(cadre)
            continue
        courante = os.path.join(cadre, 'Versions', 'Current')
        dedans = []
        if os.path.isdir(courante):
            for racine, dossiers, fichiers in os.walk(courante):
                for d in list(dossiers):
                    if d.endswith(('.app', '.xpc')):
                        dedans.append(os.path.join(racine, d))
                        dossiers.remove(d)
            for f in sorted(os.listdir(courante)):
                p = os.path.join(courante, f)
                if f != nom[:-len('.framework')] and os.path.isfile(p) and not os.path.islink(p) and os.access(p, os.X_OK):
                    dedans.append(p)
        liste += sorted(dedans, key=lambda p: (-p.count('/'), p))
        liste.append(cadre)
    return liste


def signer(a, o, chemin, droits=True):
    """Signe un code avec l'identite de la publication : runtime renforce, droits gardes, horodatage si notarise."""
    cmd = [o.codesign, '--force', '--sign', a.identite]
    if droits:
        cmd += ['--options', 'runtime', '--preserve-metadata=entitlements']
    cmd.append('--timestamp' if notariser() else '--timestamp=none')
    if a.trousseau:
        cmd += ['--keychain', a.trousseau]
    lancer(cmd + [chemin])


def publier(a, o=None, maintenant=None):
    o = o or Outils()
    version = a.version
    racine_git = lancer([o.git, 'rev-parse', '--show-toplevel']).strip()
    verifier(a, o, racine_git, version)
    sortie = os.path.abspath(a.repetition or os.path.join('build', 'publication', version))
    os.makedirs(sortie, exist_ok=True)
    dd = os.environ.get('DD', os.path.expanduser('~/Library/Developer/Xcode/DerivedData/%s-publication'
                                                  % a.fichier.lower()))
    if not a.sans_tests:
        for i, t in enumerate(a.test, 1):
            journal = os.path.join(sortie, 'tests-%d.log' % i)
            dire('tests %d/%d : %s (journal : %s)' % (i, len(a.test), t, journal))
            with open(journal, 'w') as j:
                if subprocess.run(t, shell=True, stdout=j, stderr=subprocess.STDOUT,
                                  env=dict(os.environ, DD=dd)).returncode != 0:
                    raise Refus('tests en echec : %s (voir %s)' % (t, journal))

    # 2. les numeros
    numero = numero_compilation(racine_git, o.git)
    systeme = systeme_minimum('project.yml')
    dire('version %s, numero de compilation %d, macOS %s minimum' % (version, numero, systeme))

    # 3. la compilation Release, ad hoc
    etiquette = a.etiquette + version
    chemin_flux_depot = chemin_depot(a.flux, racine_git)
    if a.repetition:
        flux = '%s/%s/main/%s' % (a.url_base, a.depot_github, chemin_flux_depot)
        url_dmg = '%s/%s/releases/download/%s' % (a.url_base, a.depot_github, etiquette)
    else:
        flux = None
        url_dmg = 'https://github.com/%s/releases/download/%s' % (a.depot_github, etiquette)
    reglages = ['CURRENT_PROJECT_VERSION=%d' % numero, 'CODE_SIGN_IDENTITY=-', 'DEVELOPMENT_TEAM=',
                'CODE_SIGN_STYLE=Manual']
    if a.repetition:
        reglages += ['FLUX_MISES_A_JOUR=' + flux]
    if a.cle_publique:
        reglages += ['CLE_MISES_A_JOUR=' + a.cle_publique]
    lancer([o.xcodegen, 'generate', '--quiet'])
    with open(os.path.join(sortie, 'compilation.log'), 'w') as j:
        if subprocess.run([o.xcodebuild, '-project', a.projet, '-scheme', a.schema, '-configuration', 'Release',
                           '-destination', 'generic/platform=macOS', '-derivedDataPath', dd] + reglages + ['build'],
                          stdout=j, stderr=subprocess.STDOUT).returncode != 0:
            raise Refus('compilation en echec (voir %s)' % j.name)
    app = os.path.join(dd, 'Build', 'Products', 'Release', a.nom_app + '.app')
    with open(os.path.join(app, 'Contents', 'Info.plist'), 'rb') as f:
        info = plistlib.load(f)
    attendu = {'CFBundleShortVersionString': version, 'CFBundleVersion': str(numero),
               'SUPublicEDKey': a.cle_publique or reglage('project.yml', a.cible, 'CLE_MISES_A_JOUR'),
               'SUFeedURL': flux or reglage('project.yml', a.cible, 'FLUX_MISES_A_JOUR')}
    for cle, valeur in attendu.items():
        if info.get(cle) != valeur:
            raise Refus('Info.plist de l\'app compilee : %s = %r, attendu %r' % (cle, info.get(cle), valeur))
    for chemin in code_imbrique(app) + [app]:
        signer(a, o, chemin)
    lancer([o.codesign, '--verify', '--deep', '--strict', app])
    exigence = subprocess.run([o.codesign, '-d', '-r-', app], check=True, capture_output=True,
                              text=True).stdout.strip()
    ecrire(os.path.join(sortie, 'exigence.txt'), exigence + '\n')
    dire('exigence de signature : ' + exigence)

    # 4. le .dmg
    nom_dmg = '%s-%s.dmg' % (a.fichier, version)
    dmg = os.path.join(sortie, nom_dmg)
    scene = os.path.join(sortie, 'dmg')
    shutil.rmtree(scene, ignore_errors=True)
    os.makedirs(scene)
    lancer(['ditto', app, os.path.join(scene, a.nom_app + '.app')])
    os.symlink('/Applications', os.path.join(scene, 'Applications'))
    if os.path.exists(dmg):
        os.remove(dmg)
    lancer([o.hdiutil, 'create', '-quiet', '-volname', '%s %s' % (a.nom_app, version), '-srcfolder', scene,
            '-fs', 'HFS+', '-format', 'UDZO', dmg])
    shutil.rmtree(scene)
    if notariser():
        # Avant la signature Ed25519 : l'agrafe change le .dmg.
        signer(a, o, dmg, droits=False)
        lancer([o.xcrun, 'notarytool', 'submit', dmg, '--keychain-profile', os.environ['PROFIL_NOTARISATION'],
                '--wait'])
        lancer([o.xcrun, 'stapler', 'staple', dmg])
        lancer([o.spctl, '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose', dmg])
        dire('notarise et agrafe : ' + dmg)

    # 5. la signature, puis le flux
    signe = [o.sign_update] + (['--ed-key-file', a.cle_privee] if a.cle_privee else []) + ['-p', dmg]
    signature = lancer(signe).strip()
    texte_notes = notes('NOTES-VERSIONS.md', version)
    item = item_flux(version, numero, '%s/%s' % (url_dmg, nom_dmg), os.path.getsize(dmg), signature, systeme,
                     notes_html(texte_notes), maintenant or datetime.datetime.utcnow())
    xml = ajouter_au_flux(lire(a.flux) if os.path.exists(a.flux) else None, a.nom_app, version, item)
    # Le nouveau flux, d'abord a cote : il n'entre dans le depot qu'apres le controle.
    chemin_flux = os.path.join(sortie, 'appcast.xml')
    ecrire(chemin_flux, xml)
    chemin_notes = os.path.join(sortie, 'notes.md')
    ecrire(chemin_notes, texte_notes)
    chemin_message = os.path.join(sortie, 'message-commit.txt')
    ecrire(chemin_message, message_flux(a.nom_app, version))
    dire('signe : %s (%d octets) ; flux : %s' % (dmg, os.path.getsize(dmg), chemin_flux))

    # 6. le controle d'anonymisation, s'il est present (prive)
    if os.path.exists(o.controle) and os.path.exists(o.table):
        textes = ['NOTES-VERSIONS.md', chemin_flux, chemin_notes, chemin_message] + a.textes
        r = subprocess.run(['/usr/bin/python3', o.controle, 'fichiers', '--table', o.table] + textes,
                           capture_output=True, text=True)
        dire('controle d\'anonymisation : ' + ' ; '.join(r.stdout.strip().splitlines()))
        if r.returncode != 0:
            raise Refus("le controle d'anonymisation a trouve des donnees reelles : rien n'est publie")
    else:
        dire("controle d'anonymisation absent de ce Mac : saute")

    # 7. la publication : l'etiquette et la version publiee, avec le .dmg ; puis le flux, commite et pousse
    if not a.repetition:
        lancer([o.git, 'tag', etiquette])
        lancer([o.git, 'push', 'origin', etiquette])
        lancer([o.gh, 'release', 'create', etiquette, dmg, '-R', a.depot_github, '--verify-tag',
                '--title', '%s %s' % (a.nom_app, version), '--notes-file', chemin_notes])
        dire('publie : https://github.com/%s/releases/tag/%s' % (a.depot_github, etiquette))
    shutil.copyfile(chemin_flux, a.flux)
    lancer([o.git, 'add', a.flux])
    lancer([o.git, 'commit', '-q', '-F', chemin_message])
    if a.repetition:
        dire('repetition : flux commite dans la copie (%s), ni etiquette, ni GitHub, ni Bureau ; produits dans %s'
             % (chemin_flux_depot, sortie))
        return sortie
    lancer([o.git, 'push', 'origin', 'main'])
    dire('flux commite et pousse sur main : https://raw.githubusercontent.com/%s/main/%s'
         % (a.depot_github, chemin_flux_depot))

    # 8. la remise
    if not a.sans_bureau:
        shutil.copy2(dmg, os.path.expanduser('~/Desktop'))
        dire('copie sur le Bureau : ' + nom_dmg)
    return sortie


def arguments(argv):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sous = p.add_subparsers(dest='commande', required=True)
    q = sous.add_parser('publier')
    q.add_argument('version')
    for nom in ('--nom-app', '--fichier', '--depot-github', '--projet', '--schema', '--cible'):
        q.add_argument(nom, required=True)
    q.add_argument('--test', action='append', default=[], help='commande de tests (shell), dans l\'ordre')
    q.add_argument('--textes', action='append', default=[], help="textes de l'app pour le controle d'anonymisation")
    q.add_argument('--identite', required=True, help='nom du certificat de signature, dans le trousseau')
    q.add_argument('--etiquette', required=True, help="debut de l'etiquette de l'app, suivi de X.Y.Z (maillage-v)")
    q.add_argument('--flux', required=True, help='le flux du depot (appcast.xml), depuis le dossier de publier.sh')
    q.add_argument('--trousseau', help='en repetition : un trousseau a part, ou chercher l\'identite')
    q.add_argument('--sans-bureau', action='store_true')
    q.add_argument('--repetition', metavar='DOSSIER')
    q.add_argument('--url-base')
    q.add_argument('--cle-privee')
    q.add_argument('--cle-publique')
    q.add_argument('--sans-tests', action='store_true')
    a = p.parse_args(argv)
    if a.repetition and not a.url_base:
        p.error('--repetition demande --url-base')
    if bool(a.cle_privee) != bool(a.cle_publique):
        p.error('--cle-privee et --cle-publique vont ensemble')
    if not a.repetition and (a.url_base or a.cle_privee or a.trousseau):
        p.error('--url-base, --cle-privee, --cle-publique et --trousseau seulement en repetition')
    return a


def main(argv=None):
    a = arguments(sys.argv[1:] if argv is None else argv)
    try:
        publier(a)
    except Refus as e:
        print('refus : %s' % e, file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print('echec : %s (code %d)\n%s' % (' '.join(map(shlex.quote, e.cmd)), e.returncode, (e.stderr or '')[-2000:]),
              file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
```

`outils/publier.sh` :

```sh
#!/bin/sh
# Publie une version de Maillage Thread sur GitHub (spec du deploiement, section 3) : verifications, numeros,
# compilation Release signee par le certificat de Djoko, .dmg signe par Sparkle (cle du trousseau), controle
# d'anonymisation, version publiee (etiquette maillage-vX.Y.Z, avec le .dmg), puis le flux des mises a jour
# (appcast.xml, qui garde toutes les versions) commite sur main et pousse aussitot, .dmg sur le Bureau.
# La logique est dans outils/publication.py, ses tests dans outils/tests.
#   outils/publier.sh X.Y.Z [--sans-bureau]
# La repetition, sans GitHub ni Bureau (spec, section 4), avec la cle du trousseau, ou une paire d'essai :
#   outils/publier.sh X.Y.Z --repetition DOSSIER --url-base URL [--cle-privee FICHIER --cle-publique CLE]
#                           [--trousseau TROUSSEAU] [--sans-tests]
# SPARKLE_BIN : le dossier bin de l'archive de Sparkle 2.10.0 (sign_update, generate_keys).
# NOTARISER=1 (desactive par defaut) : notarisation du .dmg, avec PROFIL_NOTARISATION, le profil que
# notarytool store-credentials a range dans le trousseau ; il faut alors un Developer ID pour IDENTITE_SIGNATURE.
# Produits : build/publication/X.Y.Z/ ; compilation dans DD (par defaut DerivedData/maillage-thread-publication).
set -eu
cd "$(dirname "$0")/.."
# L'identite de signature de la version publiee, a ce seul endroit : le certificat auto-signe de Djoko, trouve par
# son nom dans le trousseau (les compilations de travail et les tests restent ad hoc).
IDENTITE_SIGNATURE=${IDENTITE_SIGNATURE:-Djoko-cli Code Signing}
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage-thread-publication}
export DD
exec /usr/bin/python3 outils/publication.py publier "$@" --identite "$IDENTITE_SIGNATURE" \
  --etiquette maillage-v --flux appcast.xml \
  --nom-app "Maillage Thread" --fichier Maillage-Thread --depot-github Djoko-cli/maillage-thread \
  --projet MaillageThread.xcodeproj --schema MaillageThread --cible MaillageThread \
  --test 'outils/tester.sh' \
  --test 'xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination platform=macOS -derivedDataPath "$DD" -testLanguage en -testRegion US test' \
  --test '/usr/bin/python3 -m unittest discover -s outils/tests' \
  --test '/usr/bin/python3 -m unittest discover -s sonde/test && sh sonde/test/lancer.sh' \
  --test 'sh outils/thread-route/tests.sh' \
  --textes MaillageThread/Ressources/Localizable.xcstrings --textes MaillageThread/Ressources/InfoPlist.xcstrings
```

```bash
W=$S/deploiement-exec; cd "$W/maillage" && chmod 755 outils/publier.sh && /usr/bin/python3 -W error::ResourceWarning -m unittest discover -s outils/tests 2>&1 | tail -3; outils/publier.sh 2>&1 | tail -1; outils/publier.sh 1.0.0 --repetition /tmp/x 2>&1 | tail -1
```

Expected : `Ran 37 tests`, `OK` ; `publication.py publier: error: the following arguments are required: version` ; `publication.py: error: --repetition demande --url-base`.

- [ ] **Step 3 : commit.**

```bash
W=$S/deploiement-exec; cd "$W/maillage" && git add outils/publication.py outils/publier.sh outils/tests/test_publication.py && git commit -q -F - <<'EOF'
Ecrire outils/publier.sh : verifications, numeros, .dmg signe, appcast.xml, controle d'anonymisation, version publiee

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `0`.

---

### Task 8: `apps/macos/Outils/publier.sh` dans le pont Halo

**Files :**
- Create : `apps/macos/Outils/tests/test_publication.py`, `apps/macos/Outils/publication.py`, `apps/macos/Outils/publier.sh`

**Interfaces:**
- Consumes : `publication.py` et ses tests de la tâche 7, à l'identique.
- Produces : `apps/macos/Outils/publier.sh X.Y.Z …`, les mêmes options (étiquette `compagnon-v`, flux `apps/macos/appcast.xml`) ; les produits dans `apps/macos/build/publication/X.Y.Z/` ; le numéro de compilation compte les commits de tout le dépôt.

- [ ] **Step 1 : les tests d'abord** (`--etapes 1`, depuis `$W/halo`).

`apps/macos/Outils/tests/test_publication.py` :

```python
"""Tests de publication.py : les numeros, les notes, le flux appcast.xml a partir de valeurs inventees (nouveau, ou
une version de plus en tete d'un flux qui les garde toutes), les etiquettes propres a l'app, les controles avant
publication, le commit du flux, la signature du code et la notarisation (desactivee par defaut), sur un faux depot et de
fausses commandes (xcodebuild, codesign, security, hdiutil, sign_update, xcrun, gh...). Aucun reseau, aucun
trousseau, rien sur le Bureau.

  /usr/bin/python3 -m unittest discover -s <dossier de ces tests>
"""
import contextlib
import datetime
import io
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest
import xml.etree.ElementTree as ET
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import publication as P  # noqa: E402

CLE = 'p7jaASHZk/U9YboWWSgw+Z4xEGYXOfUUhTKtZG7uQlE='
IDENTITE = 'Essai Inventee Signing'
AUTRE_CLE = 'lkPxEHj5erw+omLlr1AVsIoyhfz4YnoLa/N9147SNgc='
GIT_ENV = dict(os.environ, GIT_CONFIG_GLOBAL='/dev/null', GIT_CONFIG_SYSTEM='/dev/null',
               GIT_AUTHOR_NAME='Essai', GIT_AUTHOR_EMAIL='essai@example.invalid',
               GIT_COMMITTER_NAME='Essai', GIT_COMMITTER_EMAIL='essai@example.invalid')

PROJET = textwrap.dedent('''\
    name: Essai
    options:
      bundleIdPrefix: fr.exemple
      deploymentTarget:
        macOS: "26.0"
    targets:
      Compagnon:
        type: application
        settings:
          base:
            MARKETING_VERSION: "1.0"
      Essai:
        type: application
        settings:
          base:
            PRODUCT_NAME: Essai Inventee
            MARKETING_VERSION: "1.2.3"
            CURRENT_PROJECT_VERSION: "1"
            FLUX_MISES_A_JOUR: https://raw.githubusercontent.com/Exemple/essai/main/appcast.xml
            CLE_MISES_A_JOUR: %s
    ''' % CLE)

NOTES = textwrap.dedent('''\
    # Notes de version · Release notes

    ## 1.2.3

    **Français**

    - Une `commande` <nouvelle>,
      sur deux lignes.

    **English**

    - A new `command`.

    ## 1.2.2

    - Ancienne.
    ''')

# Les fausses commandes : elles notent leurs arguments dans FAUX_JOURNAL.
FAUX = {
    'xcodegen': 'import sys\n',
    'codesign': 'import sys\nif sys.argv[1:3] == ["-d", "-r-"]:\n'
                '    print(\'designated => identifier "fr.exemple.essai" and certificate leaf = H"0123abcd"\')\n',
    'security': 'import os\nprint(\'  1) 0123ABCD "%s" (CSSMERR_TP_NOT_TRUSTED)\' % os.environ.get("FAUSSE_IDENTITE", "Essai Inventee Signing"))\n',
    'xcrun': 'import sys\n',
    'spctl': 'import sys\n',
    'xcodebuild': textwrap.dedent('''\
        import os, plistlib, re, sys
        a = sys.argv[1:]
        dd = a[a.index('-derivedDataPath') + 1]
        reglages = dict(x.split('=', 1) for x in a if '=' in x and not x.startswith('-'))
        projet = open('project.yml').read()
        def lu(nom):
            return reglages.get(nom) or re.search(r'  Essai:\\n(?:.*\\n)*?\\s+%s: "?([^"\\n]+)"?' % nom, projet).group(1)
        app = os.path.join(dd, 'Build', 'Products', 'Release', 'Essai Inventee.app', 'Contents')
        os.makedirs(app, exist_ok=True)
        # Le code imbrique, comme celui de Sparkle : deux services XPC, une app, un executable, puis un autre cadre.
        b = os.path.join(app, 'Frameworks', 'Sparkle.framework', 'Versions', 'B')
        for d in ('XPCServices/Installer.xpc/Contents', 'XPCServices/Downloader.xpc/Contents', 'Updater.app/Contents'):
            os.makedirs(os.path.join(b, d), exist_ok=True)
        for f in ('Autoupdate', 'Sparkle'):
            open(os.path.join(b, f), 'w').close()
            os.chmod(os.path.join(b, f), 0o755)
        if not os.path.lexists(os.path.join(b, '..', 'Current')):
            os.symlink('B', os.path.join(b, '..', 'Current'))
        os.makedirs(os.path.join(app, 'Frameworks', 'Coeur.framework', 'Versions', 'A'), exist_ok=True)
        plistlib.dump({'CFBundleShortVersionString': lu('MARKETING_VERSION'),
                       'CFBundleVersion': reglages['CURRENT_PROJECT_VERSION'],
                       'SUFeedURL': lu('FLUX_MISES_A_JOUR'), 'SUPublicEDKey': lu('CLE_MISES_A_JOUR')},
                      open(os.path.join(app, 'Info.plist'), 'wb'))
        '''),
    'hdiutil': 'import sys\nopen(sys.argv[-1], "w").write("dmg invente " + " ".join(sys.argv[1:]))\n',
    'sign_update': 'import sys\nprint("U0lHTkFUVVJFLUlOVkVOVEVF")\n',
    'generate_keys': 'import os\nprint(os.environ["FAUSSE_CLE"])\n',
    'gh': 'import os, sys\nsys.exit(1 if sys.argv[1:3] == ["release", "view"] and not os.environ.get("FAUX_PUBLIEE") '
          'else 0)\n',
    'controles.py': 'import os, sys\nprint("trouve : " + os.environ.get("FAUX_TROUVE", "aucun"))\n'
                    'sys.exit(1 if os.environ.get("FAUX_TROUVE") else 0)\n',
}


def lire(chemin):
    with open(chemin, encoding='utf-8') as f:
        return f.read()


def ecrire(chemin, texte):
    with open(chemin, 'w', encoding='utf-8') as f:
        f.write(texte)


def git(depot, *args):
    return subprocess.run(['git', '-C', depot] + list(args), check=True, capture_output=True, text=True,
                          env=GIT_ENV).stdout.strip()


class Monde:
    """Un faux depot (et son origine), de fausses commandes, un dossier de produits."""

    def __init__(self, racine):
        self.racine = racine
        self.bin = os.path.join(racine, 'bin')
        self.journal = os.path.join(racine, 'journal.txt')
        os.makedirs(self.bin)
        for nom, corps in FAUX.items():
            chemin = os.path.join(self.bin, nom)
            ecrire(chemin, '#!/usr/bin/python3\nimport os, sys\n'
                           'open(os.environ["FAUX_JOURNAL"], "a").write(%r + " " + " ".join(sys.argv[1:]) + "\\n")\n'
                           % nom + corps)
            os.chmod(chemin, 0o755)
        self.origine = os.path.join(racine, 'origine.git')
        self.depot = os.path.join(racine, 'depot')
        subprocess.run(['git', 'init', '-q', '--bare', '-b', 'main', self.origine], check=True, env=GIT_ENV)
        subprocess.run(['git', 'clone', '-q', self.origine, self.depot], check=True, env=GIT_ENV,
                       capture_output=True)
        git(self.depot, 'config', 'user.name', 'Essai')
        git(self.depot, 'config', 'user.email', '0+essai@users.noreply.github.com')
        git(self.depot, 'checkout', '-q', '-b', 'main')
        ecrire(os.path.join(self.depot, 'project.yml'), PROJET)
        ecrire(os.path.join(self.depot, 'NOTES-VERSIONS.md'), NOTES)
        ecrire(os.path.join(self.depot, '.gitignore'), 'build/\n')
        for i in range(3):
            ecrire(os.path.join(self.depot, 'f%d.txt' % i), '%d\n' % i)
            git(self.depot, 'add', '-A')
            git(self.depot, 'commit', '-q', '-m', 'commit %d' % i)
        git(self.depot, 'push', '-q', 'origin', 'main')
        self.dd = os.path.join(racine, 'dd')
        self.env = {'GIT': 'git', 'XCODEGEN': self.bin + '/xcodegen', 'XCODEBUILD': self.bin + '/xcodebuild',
                    'HDIUTIL': self.bin + '/hdiutil', 'CODESIGN': self.bin + '/codesign', 'GH': self.bin + '/gh',
                    'SECURITY': self.bin + '/security', 'XCRUN': self.bin + '/xcrun', 'SPCTL': self.bin + '/spctl',
                    'SPARKLE_BIN': self.bin, 'CONTROLE_ANONYMISATION': self.bin + '/controles.py',
                    'TABLE_ANONYMISATION': self.journal}

    def appels(self):
        return lire(self.journal).splitlines() if os.path.exists(self.journal) else []

    def arguments(self, *extra):
        return P.arguments(['publier', '1.2.3', '--nom-app', 'Essai Inventee', '--fichier', 'Essai-Inventee',
                            '--depot-github', 'Exemple/essai', '--projet', 'Essai.xcodeproj', '--schema', 'Essai',
                            '--cible', 'Essai', '--textes', 'project.yml', '--sans-bureau', '--identite', IDENTITE,
                            '--etiquette', 'essai-v', '--flux', 'appcast.xml']
                           + list(extra))

    def publier(self, *extra, env=None):
        dedans = os.getcwd()
        os.chdir(self.depot)
        try:
            # Sans GIT_AUTHOR_* ni GIT_COMMITTER_* : le commit du flux prend l'auteur de la configuration du depot.
            e = {k: v for k, v in GIT_ENV.items() if not k.startswith(('GIT_AUTHOR', 'GIT_COMMITTER'))}
            e.update(FAUX_JOURNAL=self.journal, FAUSSE_CLE=CLE, DD=self.dd)
            e.update(env or {})
            with mock.patch.dict(os.environ, e, clear=True), contextlib.redirect_stdout(io.StringIO()):
                return P.publier(self.arguments(*extra), P.Outils(self.env),
                                 maintenant=datetime.datetime(2026, 10, 6, 12, 0, 0))
        finally:
            os.chdir(dedans)


class NumerosTests(unittest.TestCase):
    def test_version_valide(self):
        self.assertTrue(P.version_valide('1.0.0'))
        self.assertTrue(P.version_valide('12.30.4'))
        for v in ('1.0', 'v1.0.0', '1.0.0-beta', '1.0.0 ', ''):
            self.assertFalse(P.version_valide(v), v)

    def test_reglages_de_la_cible(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, 'project.yml')
            ecrire(p, PROJET)
            self.assertEqual(P.reglage(p, 'Essai', 'MARKETING_VERSION'), '1.2.3')
            self.assertEqual(P.reglage(p, 'Compagnon', 'MARKETING_VERSION'), '1.0', 'chaque cible la sienne')
            self.assertEqual(P.reglage(p, 'Essai', 'CLE_MISES_A_JOUR'), CLE)
            self.assertEqual(P.systeme_minimum(p), '26.0')
            with self.assertRaises(P.Refus):
                P.reglage(p, 'Absente', 'MARKETING_VERSION')
            with self.assertRaises(P.Refus):
                P.reglage(p, 'Compagnon', 'CLE_MISES_A_JOUR')

    def test_numero_de_compilation(self):
        with tempfile.TemporaryDirectory() as d:
            subprocess.run(['git', 'init', '-q', d], check=True, env=GIT_ENV)
            for i in range(4):
                git(d, 'commit', '-q', '--allow-empty', '-m', str(i))
            self.assertEqual(P.numero_compilation(d), 4)


class NotesEtFluxTests(unittest.TestCase):
    def test_notes_de_la_version(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, 'NOTES-VERSIONS.md')
            ecrire(p, NOTES)
            n = P.notes(p, '1.2.3')
            self.assertTrue(n.startswith('**Français**'))
            self.assertNotIn('Ancienne', n)
            self.assertEqual(P.notes(p, '1.2.2'), '- Ancienne.\n')
            with self.assertRaises(P.Refus):
                P.notes(p, '9.9.9')

    def test_notes_html(self):
        h = P.notes_html('**Français**\n\n- Une `commande` <nouvelle>,\n  sur deux lignes.\n\n**English**\n\n- B\n')
        self.assertEqual(h, '<p><strong>Français</strong></p>\n'
                            '<ul><li>Une <code>commande</code> &lt;nouvelle&gt;, sur deux lignes.</li></ul>\n'
                            '<p><strong>English</strong></p>\n<ul><li>B</li></ul>')

    def item(self, version='1.2.3', numero=57):
        return P.item_flux(version, numero, 'https://exemple.invalid/essai-v%s/Essai-Inventee-%s.dmg' % (version, version),
                           123456, 'U0lHTkFUVVJF', '26.0', '<p>Notes</p>', datetime.datetime(2026, 10, 6, 12, 0, 0))

    def test_flux_neuf_valeurs_inventees(self):
        xml = P.ajouter_au_flux(None, 'Essai Inventee', '1.2.3', self.item())
        self.assertEqual(xml, textwrap.dedent('''\
            <?xml version="1.0" encoding="utf-8"?>
            <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
              <channel>
                <title>Essai Inventee</title>
                <item>
                  <title>1.2.3</title>
                  <pubDate>Tue, 06 Oct 2026 12:00:00 +0000</pubDate>
                  <sparkle:version>57</sparkle:version>
                  <sparkle:shortVersionString>1.2.3</sparkle:shortVersionString>
                  <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
                  <description><![CDATA[
            <p>Notes</p>
            ]]></description>
                  <enclosure url="https://exemple.invalid/essai-v1.2.3/Essai-Inventee-1.2.3.dmg" length="123456" type="application/octet-stream" sparkle:edSignature="U0lHTkFUVVJF"/>
                </item>
              </channel>
            </rss>
            '''))
        s = '{%s}' % P.ESPACE_SPARKLE
        item = ET.fromstring(xml).find('channel/item')
        self.assertEqual(item.find(s + 'version').text, '57')
        self.assertEqual(item.find(s + 'shortVersionString').text, '1.2.3')
        self.assertEqual(item.find('enclosure').get(s + 'edSignature'), 'U0lHTkFUVVJF')
        self.assertEqual(item.find('description').text.strip(), '<p>Notes</p>')

    def test_une_version_de_plus_en_tete(self):
        """Le flux garde toutes les versions publiees, la nouvelle en tete."""
        un = P.ajouter_au_flux(None, 'Essai Inventee', '1.2.2', self.item('1.2.2', 56))
        deux = P.ajouter_au_flux(un, 'Essai Inventee', '1.2.3', self.item('1.2.3', 57))
        s = '{%s}' % P.ESPACE_SPARKLE
        items = ET.fromstring(deux).findall('channel/item')
        self.assertEqual([i.find(s + 'shortVersionString').text for i in items], ['1.2.3', '1.2.2'])
        self.assertEqual([i.find(s + 'version').text for i in items], ['57', '56'])
        self.assertEqual(deux.replace(self.item('1.2.3', 57), ''), un, 'le reste du flux ne change pas')
        with self.assertRaises(P.Refus):
            P.ajouter_au_flux(deux, 'Essai Inventee', '1.2.2', self.item('1.2.2', 58))


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.dossier = os.path.realpath(tempfile.mkdtemp())
        self.m = Monde(self.dossier)

    def tearDown(self):
        shutil.rmtree(self.dossier)

    def refuse(self, *extra, env=None, motif, etiquette=''):
        with self.assertRaises(P.Refus) as r:
            self.m.publier(*extra, env=env)
        self.assertIn(motif, str(r.exception))
        appels = self.m.appels()
        self.assertFalse([a for a in appels if a.startswith('gh release create')], 'rien de publie')
        self.assertEqual(git(self.m.depot, 'tag', '-l'), etiquette, 'aucune etiquette nouvelle')
        self.assertEqual(git(self.m.origine, 'tag', '-l'), '', 'rien de pousse')
        return appels

    def commit(self, fichier, texte):
        ecrire(os.path.join(self.m.depot, fichier), texte)
        git(self.m.depot, 'commit', '-q', '-am', 'changement')
        git(self.m.depot, 'push', '-q', 'origin', 'main')

    def test_repetition(self):
        sortie = os.path.join(self.dossier, 'repetition')
        self.m.publier('--repetition', sortie, '--url-base', 'http://127.0.0.1:8123', '--cle-privee', 'cle.txt',
                       '--cle-publique', AUTRE_CLE, '--sans-tests')
        flux = os.path.join(self.m.depot, 'appcast.xml')
        item = ET.parse(flux).getroot().find('channel/item')
        s = '{%s}' % P.ESPACE_SPARKLE
        self.assertEqual(item.find(s + 'version').text, '3', 'trois commits')
        enc = item.find('enclosure')
        self.assertEqual(enc.get('url'),
                         'http://127.0.0.1:8123/Exemple/essai/releases/download/essai-v1.2.3/Essai-Inventee-1.2.3.dmg')
        self.assertEqual(git(self.m.depot, 'log', '-1', '--format=%s'),
                         'Publier Essai Inventee 1.2.3 dans le flux des mises a jour', 'commite dans la copie')
        self.assertEqual(git(self.m.depot, 'status', '--porcelain'), '')
        self.assertEqual(git(self.m.origine, 'rev-list', '--count', 'main'), '3', 'rien de pousse')
        self.assertEqual(enc.get(s + 'edSignature'), 'U0lHTkFUVVJFLUlOVkVOVEVF')
        dmg = os.path.join(sortie, 'Essai-Inventee-1.2.3.dmg')
        self.assertEqual(int(enc.get('length')), os.path.getsize(dmg))
        self.assertIn('-volname Essai Inventee 1.2.3', lire(dmg))
        appels = self.m.appels()
        build = [a for a in appels if a.startswith('xcodebuild')][0]
        for r in ('-configuration Release', 'CURRENT_PROJECT_VERSION=3', 'CODE_SIGN_IDENTITY=-', 'DEVELOPMENT_TEAM= ',
                  'FLUX_MISES_A_JOUR=http://127.0.0.1:8123/Exemple/essai/main/appcast.xml',
                  'CLE_MISES_A_JOUR=' + AUTRE_CLE):
            self.assertIn(r, build)
        self.assertIn('sign_update --ed-key-file cle.txt -p ' + dmg, appels)
        self.assertFalse([a for a in appels if a.startswith(('gh ', 'generate_keys'))], 'ni GitHub ni trousseau')
        controle = [a for a in appels if a.startswith('controles.py')][0]
        self.assertIn('NOTES-VERSIONS.md', controle)
        self.assertIn(os.path.join(sortie, 'appcast.xml'), controle)
        self.assertIn('project.yml', controle)
        self.assertEqual(git(self.m.depot, 'tag', '-l'), '')

    def test_repetition_avec_la_cle_du_trousseau(self):
        """Sans paire d'essai : la cle publique de project.yml, celle du trousseau, et la signature par le trousseau."""
        sortie = os.path.join(self.dossier, 'repetition')
        self.m.publier('--repetition', sortie, '--url-base', 'http://127.0.0.1:8123', '--sans-tests')
        appels = self.m.appels()
        self.assertIn('generate_keys -p', appels)
        self.assertIn('sign_update -p ' + os.path.join(sortie, 'Essai-Inventee-1.2.3.dmg'), appels)
        build = [a for a in appels if a.startswith('xcodebuild')][0]
        self.assertIn('FLUX_MISES_A_JOUR=http://127.0.0.1:8123/Exemple/essai/main/appcast.xml', build)
        self.assertNotIn('CLE_MISES_A_JOUR=', build, 'la cle de project.yml')
        self.assertFalse([a for a in appels if a.startswith('gh ')])
        self.assertEqual(git(self.m.depot, 'tag', '-l'), '')

    def test_publication(self):
        self.m.publier()
        appels = self.m.appels()
        self.assertEqual(git(self.m.origine, 'tag', '-l'), 'essai-v1.2.3', 'etiquette de l\'app, poussee')
        dmg = os.path.join(self.m.depot, 'build', 'publication', '1.2.3', 'Essai-Inventee-1.2.3.dmg')
        cree = [a for a in appels if a.startswith('gh release create')]
        self.assertEqual(len(cree), 1)
        self.assertIn('essai-v1.2.3 %s -R Exemple/essai' % dmg, cree[0], 'le .dmg seul')
        self.assertIn('--title Essai Inventee 1.2.3', cree[0])
        self.assertIn('sign_update -p ' + dmg, appels, 'cle du trousseau')
        # Le flux, dans le depot, commite puis pousse sur main, apres la version publiee.
        flux = lire(os.path.join(self.m.depot, 'appcast.xml'))
        self.assertEqual(git(self.m.origine, 'show', 'main:appcast.xml') + '\n', flux)
        self.assertEqual(git(self.m.origine, 'log', '-1', '--format=%an %ae', 'main'),
                         'Essai 0+essai@users.noreply.github.com', 'l\'auteur du depot, adresse noreply')
        message = git(self.m.origine, 'log', '-1', '--format=%B', 'main')
        self.assertEqual(message, 'Publier Essai Inventee 1.2.3 dans le flux des mises a jour\n\n'
                                  'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')
        self.assertEqual(git(self.m.origine, 'show', '--name-only', '--format=', 'main'), 'appcast.xml')
        self.assertEqual(git(self.m.depot, 'status', '--porcelain'), '')
        controle = [a for a in appels if a.startswith('controles.py')][0]
        self.assertIn('message-commit.txt', controle, 'le message passe aussi le controle')
        self.assertIn('https://github.com/Exemple/essai/releases/download/essai-v1.2.3/Essai-Inventee-1.2.3.dmg', flux)
        self.assertIn('<li>A new <code>command</code>.</li>', flux)
        with open(os.path.join(self.m.dd, 'Build', 'Products', 'Release', 'Essai Inventee.app', 'Contents',
                               'Info.plist'), 'rb') as f:
            info = plistlib.load(f)
        self.assertEqual(info['CFBundleVersion'], '3')

    def signatures(self):
        """Les signatures du code, dans l'ordre : le chemin signe, depuis le dossier des produits."""
        base = os.path.join(self.m.dd, 'Build', 'Products', 'Release') + '/'
        return [a[a.index(base) + len(base):].replace('Essai Inventee.app/Contents/Frameworks/', '')
                for a in self.m.appels() if a.startswith('codesign --force')]

    def test_signature_du_code(self):
        """Le code imbrique d'abord, du plus profond au moins profond, chaque cadre apres son contenu, l'app en
        dernier ; avec l'identite donnee, le runtime renforce, les droits gardes ; puis l'exigence de signature."""
        self.m.publier()
        self.assertEqual(self.signatures(), [
            'Coeur.framework',
            'Sparkle.framework/Versions/Current/XPCServices/Downloader.xpc',
            'Sparkle.framework/Versions/Current/XPCServices/Installer.xpc',
            'Sparkle.framework/Versions/Current/Autoupdate',
            'Sparkle.framework/Versions/Current/Updater.app',
            'Sparkle.framework',
            'Essai Inventee.app'])
        appels = [a for a in self.m.appels() if a.startswith('codesign --force')]
        for a in appels:
            self.assertIn('--sign %s --options runtime --preserve-metadata=entitlements --timestamp=none' % IDENTITE, a)
            self.assertNotIn('--keychain', a)
        sortie = os.path.join(self.m.depot, 'build', 'publication', '1.2.3')
        self.assertIn('certificate leaf', lire(os.path.join(sortie, 'exigence.txt')))

    def test_signature_dans_un_trousseau_a_part(self):
        """En repetition, un certificat d'essai dans un trousseau a part : codesign et security y cherchent."""
        sortie = os.path.join(self.dossier, 'repetition')
        self.m.publier('--repetition', sortie, '--url-base', 'http://127.0.0.1:8123', '--cle-privee', 'cle.txt',
                       '--cle-publique', AUTRE_CLE, '--sans-tests', '--trousseau', '/tmp/essai.keychain-db')
        appels = self.m.appels()
        self.assertIn('security find-identity -p codesigning /tmp/essai.keychain-db', appels)
        signe = [a for a in appels if a.startswith('codesign --force')]
        self.assertEqual(len(signe), 7)
        self.assertTrue(all('--keychain /tmp/essai.keychain-db' in a for a in signe))

    def test_refus_identite_absente(self):
        appels = self.refuse(env={'FAUSSE_IDENTITE': 'Autre Signing'}, motif='identite de signature')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_notarisation_pas_par_defaut(self):
        self.m.publier()
        self.assertFalse([a for a in self.m.appels() if a.startswith(('xcrun', 'spctl'))])

    def test_refus_notarisation_sans_profil(self):
        appels = self.refuse(env={'NOTARISER': '1'}, motif='PROFIL_NOTARISATION')
        self.assertFalse([a for a in appels if a.startswith(('xcodebuild', 'xcrun'))], 'rien de compile ni soumis')

    def test_notarisation(self):
        """NOTARISER=1 : signatures horodatees, le .dmg signe, soumis, agrafe, evalue, puis signe par Sparkle (la
        signature Ed25519 porte sur le .dmg agrafe)."""
        self.m.publier(env={'NOTARISER': '1', 'PROFIL_NOTARISATION': 'profil-essai'})
        appels = self.m.appels()
        dmg = os.path.join(self.m.depot, 'build', 'publication', '1.2.3', 'Essai-Inventee-1.2.3.dmg')
        signe = [a for a in appels if a.startswith('codesign --force')]
        self.assertTrue(all('--timestamp ' in a and '--timestamp=none' not in a for a in signe))
        suite = [a for a in appels if a.startswith(('xcrun', 'spctl', 'sign_update')) or a.endswith(' ' + dmg)
                 and a.startswith('codesign')]
        self.assertEqual(suite, [
            'codesign --force --sign %s --timestamp %s' % (IDENTITE, dmg),
            'xcrun notarytool submit %s --keychain-profile profil-essai --wait' % dmg,
            'xcrun stapler staple %s' % dmg,
            'spctl --assess --type open --context context:primary-signature --verbose %s' % dmg,
            'sign_update -p %s' % dmg])

    def test_refus_version_differente(self):
        self.commit('project.yml', PROJET.replace('"1.2.3"', '"1.2.4"'))
        appels = self.refuse(motif='MARKETING_VERSION')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_refus_arbre_pas_propre(self):
        ecrire(os.path.join(self.m.depot, 'oubli.txt'), 'x\n')
        self.refuse(motif='propre')

    def test_refus_etiquette_existante(self):
        git(self.m.depot, 'tag', 'essai-v1.2.3')
        self.refuse(motif='existe deja', etiquette='essai-v1.2.3')

    def test_etiquette_d_une_autre_app(self):
        """L'etiquette d'une autre app du meme depot, au meme numero, ne gene pas."""
        git(self.m.depot, 'tag', 'autre-v1.2.3')
        git(self.m.depot, 'push', '-q', 'origin', 'autre-v1.2.3')
        self.m.publier()
        self.assertEqual(git(self.m.origine, 'tag', '-l').split(), ['autre-v1.2.3', 'essai-v1.2.3'])

    def test_ajout_a_un_flux_existant(self):
        """Le flux du depot garde les versions d'avant : la nouvelle s'ajoute en tete."""
        ancien = P.ajouter_au_flux(None, 'Essai Inventee', '1.2.2', P.item_flux(
            '1.2.2', 2, 'https://github.com/Exemple/essai/releases/download/essai-v1.2.2/Essai-Inventee-1.2.2.dmg',
            10, 'QU5DSUVOTkU=', '26.0', '<p>Ancienne</p>', datetime.datetime(2026, 10, 1)))
        ecrire(os.path.join(self.m.depot, 'appcast.xml'), ancien)
        git(self.m.depot, 'add', 'appcast.xml')
        git(self.m.depot, 'commit', '-q', '-m', 'flux')
        git(self.m.depot, 'push', '-q', 'origin', 'main')
        self.m.publier()
        s = '{%s}' % P.ESPACE_SPARKLE
        items = ET.fromstring(lire(os.path.join(self.m.depot, 'appcast.xml'))).findall('channel/item')
        self.assertEqual([i.find(s + 'shortVersionString').text for i in items], ['1.2.3', '1.2.2'])
        self.assertEqual(items[0].find(s + 'version').text, '4')

    def test_refus_auteur_sans_adresse_noreply(self):
        """Le commit du flux est public : son auteur porte l'adresse noreply de GitHub, jamais une vraie."""
        git(self.m.depot, 'config', 'user.email', 'essai@example.invalid')
        appels = self.refuse(motif='noreply')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_refus_version_deja_dans_le_flux(self):
        ancien = P.ajouter_au_flux(None, 'Essai Inventee', '1.2.3', P.item_flux(
            '1.2.3', 2, 'https://exemple.invalid/x.dmg', 10, 'QQ==', '26.0', '', datetime.datetime(2026, 10, 1)))
        ecrire(os.path.join(self.m.depot, 'appcast.xml'), ancien)
        git(self.m.depot, 'add', 'appcast.xml')
        git(self.m.depot, 'commit', '-q', '-m', 'flux')
        git(self.m.depot, 'push', '-q', 'origin', 'main')
        appels = self.refuse(motif='deja dans le flux')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_refus_adresse_du_flux(self):
        """L'app doit lire le flux a l'adresse brute du depot, celle ou publier.sh le pousse."""
        self.commit('project.yml', PROJET.replace('raw.githubusercontent.com/Exemple/essai/main/appcast.xml',
                                                  'github.com/Exemple/essai/releases/latest/download/appcast.xml'))
        self.refuse(motif='FLUX_MISES_A_JOUR')

    def test_refus_hors_de_main(self):
        git(self.m.depot, 'checkout', '-q', '-b', 'autre')
        self.refuse(motif='depuis main')

    def test_refus_main_pas_a_jour(self):
        ecrire(os.path.join(self.m.depot, 'f0.txt'), 'local\n')
        git(self.m.depot, 'commit', '-q', '-am', 'pas pousse')
        self.refuse(motif='a jour')

    def test_refus_deja_publiee(self):
        self.refuse(env={'FAUX_PUBLIEE': '1'}, motif='deja publiee')

    def test_refus_notes_absentes(self):
        self.commit('NOTES-VERSIONS.md', NOTES.replace('## 1.2.3', '## 1.2.1'))
        self.refuse(motif='pas de section 1.2.3')

    def test_refus_cle_du_trousseau_differente(self):
        appels = self.refuse(env={'FAUSSE_CLE': AUTRE_CLE}, motif='trousseau')
        self.assertIn('generate_keys -p', appels)

    def test_refus_tests_en_echec(self):
        appels = self.refuse('--test', 'exit 3', motif='tests en echec')
        self.assertFalse([a for a in appels if a.startswith('xcodebuild')], 'rien de compile')

    def test_refus_sans_tests_hors_repetition(self):
        self.refuse('--sans-tests', motif='repetition')

    def test_refus_controle_d_anonymisation(self):
        appels = self.refuse(env={'FAUX_TROUVE': '1'}, motif='anonymisation')
        self.assertTrue([a for a in appels if a.startswith('sign_update')], 'le controle passe apres la signature')
        self.assertFalse(os.path.exists(os.path.join(self.m.depot, 'appcast.xml')), 'le flux du depot ne change pas')
        self.assertEqual(git(self.m.depot, 'status', '--porcelain'), '')

    def test_controle_absent(self):
        self.m.env['CONTROLE_ANONYMISATION'] = os.path.join(self.dossier, 'absent.py')
        self.m.publier()
        self.assertEqual(git(self.m.origine, 'tag', '-l'), 'essai-v1.2.3')

    def test_arguments_de_la_repetition(self):
        with mock.patch('sys.stderr'):
            with self.assertRaises(SystemExit):
                P.arguments(['publier', '1.2.3', '--nom-app', 'A', '--fichier', 'A', '--depot-github', 'E/a',
                             '--projet', 'A.xcodeproj', '--schema', 'A', '--cible', 'A', '--repetition', 'x'])
            with self.assertRaises(SystemExit):
                P.arguments(['publier', '1.2.3', '--nom-app', 'A', '--fichier', 'A', '--depot-github', 'E/a',
                             '--projet', 'A.xcodeproj', '--schema', 'A', '--cible', 'A', '--repetition', 'x',
                             '--url-base', 'http://127.0.0.1:1', '--cle-privee', 'k'])
            with self.assertRaises(SystemExit):
                P.arguments(['publier', '1.2.3', '--nom-app', 'A', '--fichier', 'A', '--depot-github', 'E/a',
                             '--projet', 'A.xcodeproj', '--schema', 'A', '--cible', 'A', '--cle-privee', 'k',
                             '--cle-publique', CLE])


if __name__ == '__main__':
    unittest.main()
```

Run : `W=$S/deploiement-exec; cd "$W/halo/apps/macos" && /usr/bin/python3 -m unittest discover -s Outils/tests 2>&1 | tail -3`

Expected : `Ran 1 test`, `FAILED (errors=1)`.

- [ ] **Step 2 : la publication** (`--etapes 2`).

`apps/macos/Outils/publication.py` :

```python
#!/usr/bin/env python3
"""Publication d'une version de l'app (spec du deploiement, section 3), appelee par publier.sh.

  publication.py publier X.Y.Z --nom-app N --fichier F --depot-github D --projet P --schema S --cible C
                 --identite NOM --etiquette PREFIXE --flux CHEMIN [--test CMD]... [--textes FICHIER]... [--sans-bureau]
                 [--repetition DOSSIER --url-base URL [--cle-privee FICHIER --cle-publique CLE] [--trousseau T]
                  [--sans-tests]]

Dans l'ordre, et rien n'est publie si une etape echoue :
  1. les verifications : la version est X.Y.Z, celle de MARKETING_VERSION ; l'arbre est propre ; main, a jour avec
     GitHub ; l'etiquette de l'app (PREFIXE suivi de X.Y.Z, par exemple maillage-v1.0.0) et sa version publiee
     n'existent pas, ni la version dans le flux ; l'app lit le flux a l'adresse brute du depot
     (https://raw.githubusercontent.com/<depot>/main/<CHEMIN>) ; NOTES-VERSIONS.md a sa section ; la cle publique
     de l'app est celle du trousseau ; l'identite de signature y est ; les tests passent ;
  2. les numeros : la version, et le numero de compilation, le nombre de commits de main ;
  3. la compilation Release, ad hoc (une equipe de Local.xcconfig n'y entre pas), puis signee avec l'identite
     donnee (un certificat auto-signe stable, plus tard un Developer ID) : le code imbrique d'abord, le runtime
     renforce, les droits gardes ; l'exigence de signature (codesign -d -r-) est ecrite dans exigence.txt ;
  4. le .dmg (hdiutil) : l'app et un raccourci vers Applications ; avec NOTARISER=1 seulement (desactive par
     defaut), le .dmg signe, soumis a Apple (notarytool, profil PROFIL_NOTARISATION du trousseau), agrafe
     (stapler) et evalue (spctl) ;
  5. la signature Ed25519 du .dmg (sign_update de Sparkle, cle du trousseau), puis le flux : le fichier CHEMIN du
     depot (appcast.xml), qui garde toutes les versions publiees, la nouvelle en tete ; l'adresse de chaque .dmg est
     celle de sa version publiee ;
  6. le controle d'anonymisation (prive), s'il est present, sur les notes, le flux, le message du commit du flux et
     les textes de l'app ;
  7. l'etiquette, poussee, puis la version publiee sur GitHub (gh release create), avec le .dmg ; puis le flux,
     commite sur main (git add de ce seul fichier) et pousse aussitot ;
  8. le .dmg copie sur le Bureau (sauf --sans-bureau).

En repetition (--repetition DOSSIER), ni GitHub, ni etiquette, ni Bureau : la branche peut etre une autre que main ;
--url-base tient lieu des deux adresses de GitHub (le flux : <URL>/<depot>/main/<CHEMIN> ; un .dmg :
<URL>/<depot>/releases/download/<etiquette>/<fichier>), comme les servirait un serveur local ; le flux est commite
dans la copie, sans etre pousse ; les produits vont dans DOSSIER. Avec --cle-privee et --cle-publique, une paire
d'essai, sans le trousseau : l'app porte cette cle publique, et le .dmg est signe avec la cle privee du fichier.
Sans elles, la cle du trousseau, comme pour la vraie publication. Avec --trousseau, l'identite de signature est
cherchee dans ce trousseau a part (un certificat d'essai), jamais dans celui de la session.

Les commandes externes se remplacent par l'environnement, pour les tests : XCODEGEN, XCODEBUILD, HDIUTIL, CODESIGN,
SECURITY, XCRUN, SPCTL, SPARKLE_BIN (dossier de sign_update et generate_keys), GH, GIT, CONTROLE_ANONYMISATION et
TABLE_ANONYMISATION. Aucun identifiant Apple, Team ID ni mot de passe n'est ecrit ici : la notarisation lit le
profil que notarytool store-credentials a range dans le trousseau.
"""
import argparse
import datetime
import html
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys

VERSION = re.compile(r'^\d+\.\d+\.\d+$')
ESPACE_SPARKLE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
PRIVE = os.path.expanduser('~/Dev/maillage-thread/.superpowers/anonymisation')


class Refus(Exception):
    """Une verification qui arrete la publication, avant tout changement."""


def lire(chemin):
    with open(chemin, encoding='utf-8') as f:
        return f.read()


def ecrire(chemin, texte):
    with open(chemin, 'w', encoding='utf-8') as f:
        f.write(texte)


# --- les numeros ---------------------------------------------------------------------------------------------

def version_valide(v):
    return bool(VERSION.match(v))


def bloc_cible(projet_yml, cible):
    """Les lignes de la cible `cible` de project.yml (XcodeGen) : de « targets: », la cible a deux espaces de
    retrait, jusqu'a la suivante."""
    lignes = lire(projet_yml).splitlines()
    try:
        debut = lignes.index('targets:')
        i = lignes.index('  %s:' % cible, debut)
    except ValueError:
        raise Refus('cible %s introuvable dans %s' % (cible, projet_yml))
    bloc = []
    for l in lignes[i + 1:]:
        if re.match(r'^ {0,2}\S', l):
            break
        bloc.append(l)
    return bloc


def reglage(projet_yml, cible, nom):
    """La valeur d'un reglage de la cible (« NOM: valeur », guillemets otes)."""
    for l in bloc_cible(projet_yml, cible):
        m = re.match(r'^\s+%s:\s*(.+?)\s*$' % re.escape(nom), l)
        if m:
            return m.group(1).strip('"')
    raise Refus('%s absent de la cible %s' % (nom, cible))


def systeme_minimum(projet_yml):
    """La version minimale de macOS (options.deploymentTarget.macOS)."""
    m = re.search(r'^options:\n(?:  .*\n)*?  deploymentTarget:\n    macOS: "?([\d.]+)"?', lire(projet_yml), re.M)
    if not m:
        raise Refus('deploymentTarget.macOS absent de ' + projet_yml)
    return m.group(1)


def numero_compilation(depot, git='git'):
    """Le numero de compilation (CFBundleVersion), que compare Sparkle : le nombre de commits jusqu'a HEAD."""
    return int(subprocess.run([git, '-C', depot, 'rev-list', '--count', 'HEAD'], check=True, capture_output=True,
                              text=True).stdout.strip())


# --- les notes et le flux ------------------------------------------------------------------------------------

def notes(chemin, version):
    """La section « ## X.Y.Z » de NOTES-VERSIONS.md, sans son titre."""
    texte = lire(chemin)
    m = re.search(r'^## %s[ \t]*\n(.*?)(?=^## |\Z)' % re.escape(version), texte, re.M | re.S)
    if not m or not m.group(1).strip():
        raise Refus('pas de section %s dans %s' % (version, chemin))
    return m.group(1).strip() + '\n'


def en_ligne(t):
    t = html.escape(t, quote=False)
    t = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', t)
    return re.sub(r'`(.+?)`', r'<code>\1</code>', t)


def notes_html(texte):
    """Les notes en HTML simple, pour la fenetre de Sparkle : paragraphes, listes « - », gras et code."""
    sortie, liste, para = [], [], []

    def fermer():
        if para:
            sortie.append('<p>%s</p>' % en_ligne(' '.join(para)))
            para.clear()
        if liste:
            sortie.append('<ul>%s</ul>' % ''.join('<li>%s</li>' % en_ligne(e) for e in liste))
            liste.clear()

    for l in texte.splitlines():
        s = l.strip()
        if not s:
            fermer()
        elif s.startswith('- '):
            if para:
                fermer()
            liste.append(s[2:])
        elif liste and l.startswith('  '):
            liste[-1] += ' ' + s
        else:
            if liste:
                fermer()
            para.append(s)
    fermer()
    return '\n'.join(sortie)


def item_flux(version, numero, url, taille, signature, systeme, notes_html_, date):
    """Une version dans le flux de Sparkle : un <item>, avec son retrait et sa fin de ligne."""
    return '''    <item>
      <title>%s</title>
      <pubDate>%s</pubDate>
      <sparkle:version>%d</sparkle:version>
      <sparkle:shortVersionString>%s</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>%s</sparkle:minimumSystemVersion>
      <description><![CDATA[
%s
]]></description>
      <enclosure url="%s" length="%d" type="application/octet-stream" sparkle:edSignature="%s"/>
    </item>
''' % (html.escape(version), date.strftime('%a, %d %b %Y %H:%M:%S +0000'), numero, html.escape(version),
       html.escape(systeme), notes_html_.replace(']]>', ']]&gt;'), html.escape(url), taille, html.escape(signature))


def ajouter_au_flux(existant, titre, version, item):
    """Le flux (appcast.xml) avec une version de plus, en tete : il garde toutes les versions publiees. Sans flux
    existant (None), un flux neuf. Refus si la version y est deja."""
    if existant is None:
        return '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="%s">
  <channel>
    <title>%s</title>
%s  </channel>
</rss>
''' % (ESPACE_SPARKLE, html.escape(titre), item)
    if '<sparkle:shortVersionString>%s</sparkle:shortVersionString>' % html.escape(version) in existant:
        raise Refus('la version %s est deja dans le flux' % version)
    i = existant.find('    <item>')
    if i < 0:
        i = existant.find('  </channel>')
    if i < 0:
        raise Refus('flux illisible : ni <item>, ni </channel>')
    return existant[:i] + item + existant[i:]


def message_flux(nom_app, version):
    """Le message du commit du flux, en francais sans accents."""
    return ('Publier %s %s dans le flux des mises a jour\n\n'
            'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n' % (nom_app, version))


# --- la publication ------------------------------------------------------------------------------------------

class Outils:
    """Les commandes externes, remplacables par l'environnement (tests)."""

    def __init__(self, env=None):
        e = os.environ if env is None else env
        sparkle = e.get('SPARKLE_BIN', '')
        self.git = e.get('GIT', 'git')
        self.xcodegen = e.get('XCODEGEN', 'xcodegen')
        self.xcodebuild = e.get('XCODEBUILD', 'xcodebuild')
        self.hdiutil = e.get('HDIUTIL', 'hdiutil')
        self.codesign = e.get('CODESIGN', 'codesign')
        self.security = e.get('SECURITY', 'security')
        self.xcrun = e.get('XCRUN', 'xcrun')
        self.spctl = e.get('SPCTL', 'spctl')
        self.gh = e.get('GH', 'gh')
        self.sign_update = os.path.join(sparkle, 'sign_update') if sparkle else 'sign_update'
        self.generate_keys = os.path.join(sparkle, 'generate_keys') if sparkle else 'generate_keys'
        self.controle = e.get('CONTROLE_ANONYMISATION', os.path.join(PRIVE, 'outils', 'controles.py'))
        self.table = e.get('TABLE_ANONYMISATION', os.path.join(PRIVE, 'execution', 'table.json'))


def lancer(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw).stdout


def dire(texte):
    print(texte, flush=True)


def verifier(a, o, racine_git, version):
    """L'etape 1 : tout ce qui doit tenir avant de compiler. Leve Refus."""
    if not version_valide(version):
        raise Refus('version attendue sous la forme X.Y.Z : ' + version)
    marketing = reglage('project.yml', a.cible, 'MARKETING_VERSION')
    if marketing != version:
        raise Refus('MARKETING_VERSION de project.yml : %s, pas %s' % (marketing, version))
    if lancer([o.git, 'status', '--porcelain']).strip():
        raise Refus("l'arbre n'est pas propre (git status)")
    auteur = subprocess.run([o.git, 'config', 'user.email'], capture_output=True, text=True).stdout.strip()
    if not auteur.endswith('@users.noreply.github.com'):
        raise Refus("le commit du flux est public : l'adresse de l'auteur (git config user.email) doit etre "
                    "l'adresse noreply de GitHub")
    etiquette = a.etiquette + version
    if lancer([o.git, 'tag', '-l', etiquette]).strip():
        raise Refus("l'etiquette %s existe deja" % etiquette)
    if os.path.exists(a.flux):
        ajouter_au_flux(lire(a.flux), a.nom_app, version, '')
    adresse = 'https://raw.githubusercontent.com/%s/main/%s' % (a.depot_github, chemin_depot(a.flux, racine_git))
    if reglage('project.yml', a.cible, 'FLUX_MISES_A_JOUR') != adresse:
        raise Refus('FLUX_MISES_A_JOUR de project.yml : %s attendu (le flux du depot)' % adresse)
    if not a.repetition:
        branche = lancer([o.git, 'rev-parse', '--abbrev-ref', 'HEAD']).strip()
        if branche != 'main':
            raise Refus('la publication se fait depuis main, pas ' + branche)
        lancer([o.git, 'fetch', '-q', 'origin', 'main'])
        if lancer([o.git, 'rev-parse', 'HEAD']) != lancer([o.git, 'rev-parse', 'origin/main']):
            raise Refus("main n'est pas a jour avec GitHub (origin/main)")
        if lancer([o.git, 'ls-remote', '--tags', 'origin', etiquette]).strip():
            raise Refus("l'etiquette %s existe deja sur GitHub" % etiquette)
        if subprocess.run([o.gh, 'release', 'view', etiquette, '-R', a.depot_github],
                          capture_output=True).returncode == 0:
            raise Refus('la version %s est deja publiee sur GitHub' % etiquette)
    notes('NOTES-VERSIONS.md', version)
    cle = reglage('project.yml', a.cible, 'CLE_MISES_A_JOUR')
    if a.cle_publique:
        cle_attendue = a.cle_publique
    else:
        cle_attendue = lancer([o.generate_keys, '-p']).strip()
        if cle != cle_attendue:
            raise Refus('la cle publique de project.yml (CLE_MISES_A_JOUR) differe de celle du trousseau')
    if not re.match(r'^[A-Za-z0-9+/]{43}=$', cle_attendue or ''):
        raise Refus('cle publique Ed25519 invalide : %s' % cle_attendue)
    if a.sans_tests and not a.repetition:
        raise Refus('--sans-tests seulement en repetition')
    identites = lancer([o.security, 'find-identity', '-p', 'codesigning'] + ([a.trousseau] if a.trousseau else []))
    if '"%s"' % a.identite not in identites:
        raise Refus('identite de signature introuvable dans le trousseau : %s' % a.identite)
    if notariser() and not os.environ.get('PROFIL_NOTARISATION'):
        raise Refus('NOTARISER=1 demande PROFIL_NOTARISATION, le profil de notarytool store-credentials')
    return marketing


def chemin_depot(chemin, racine_git):
    """Le chemin d'un fichier depuis la racine du depot (celui de l'adresse brute du flux)."""
    return os.path.relpath(os.path.realpath(chemin), os.path.realpath(racine_git))


def notariser():
    """La notarisation (Developer ID), desactivee par defaut : NOTARISER=1 l'active."""
    return os.environ.get('NOTARISER') == '1'


def code_imbrique(app):
    """Le code a signer avant l'app, dans l'ordre : pour chaque cadre de Contents/Frameworks, ce qu'il contient
    (services XPC, apps, executables), du plus profond au moins profond, puis le cadre lui-meme."""
    cadres = os.path.join(app, 'Contents', 'Frameworks')
    liste = []
    for nom in sorted(os.listdir(cadres)) if os.path.isdir(cadres) else []:
        cadre = os.path.join(cadres, nom)
        if not nom.endswith('.framework'):
            liste.append(cadre)
            continue
        courante = os.path.join(cadre, 'Versions', 'Current')
        dedans = []
        if os.path.isdir(courante):
            for racine, dossiers, fichiers in os.walk(courante):
                for d in list(dossiers):
                    if d.endswith(('.app', '.xpc')):
                        dedans.append(os.path.join(racine, d))
                        dossiers.remove(d)
            for f in sorted(os.listdir(courante)):
                p = os.path.join(courante, f)
                if f != nom[:-len('.framework')] and os.path.isfile(p) and not os.path.islink(p) and os.access(p, os.X_OK):
                    dedans.append(p)
        liste += sorted(dedans, key=lambda p: (-p.count('/'), p))
        liste.append(cadre)
    return liste


def signer(a, o, chemin, droits=True):
    """Signe un code avec l'identite de la publication : runtime renforce, droits gardes, horodatage si notarise."""
    cmd = [o.codesign, '--force', '--sign', a.identite]
    if droits:
        cmd += ['--options', 'runtime', '--preserve-metadata=entitlements']
    cmd.append('--timestamp' if notariser() else '--timestamp=none')
    if a.trousseau:
        cmd += ['--keychain', a.trousseau]
    lancer(cmd + [chemin])


def publier(a, o=None, maintenant=None):
    o = o or Outils()
    version = a.version
    racine_git = lancer([o.git, 'rev-parse', '--show-toplevel']).strip()
    verifier(a, o, racine_git, version)
    sortie = os.path.abspath(a.repetition or os.path.join('build', 'publication', version))
    os.makedirs(sortie, exist_ok=True)
    dd = os.environ.get('DD', os.path.expanduser('~/Library/Developer/Xcode/DerivedData/%s-publication'
                                                  % a.fichier.lower()))
    if not a.sans_tests:
        for i, t in enumerate(a.test, 1):
            journal = os.path.join(sortie, 'tests-%d.log' % i)
            dire('tests %d/%d : %s (journal : %s)' % (i, len(a.test), t, journal))
            with open(journal, 'w') as j:
                if subprocess.run(t, shell=True, stdout=j, stderr=subprocess.STDOUT,
                                  env=dict(os.environ, DD=dd)).returncode != 0:
                    raise Refus('tests en echec : %s (voir %s)' % (t, journal))

    # 2. les numeros
    numero = numero_compilation(racine_git, o.git)
    systeme = systeme_minimum('project.yml')
    dire('version %s, numero de compilation %d, macOS %s minimum' % (version, numero, systeme))

    # 3. la compilation Release, ad hoc
    etiquette = a.etiquette + version
    chemin_flux_depot = chemin_depot(a.flux, racine_git)
    if a.repetition:
        flux = '%s/%s/main/%s' % (a.url_base, a.depot_github, chemin_flux_depot)
        url_dmg = '%s/%s/releases/download/%s' % (a.url_base, a.depot_github, etiquette)
    else:
        flux = None
        url_dmg = 'https://github.com/%s/releases/download/%s' % (a.depot_github, etiquette)
    reglages = ['CURRENT_PROJECT_VERSION=%d' % numero, 'CODE_SIGN_IDENTITY=-', 'DEVELOPMENT_TEAM=',
                'CODE_SIGN_STYLE=Manual']
    if a.repetition:
        reglages += ['FLUX_MISES_A_JOUR=' + flux]
    if a.cle_publique:
        reglages += ['CLE_MISES_A_JOUR=' + a.cle_publique]
    lancer([o.xcodegen, 'generate', '--quiet'])
    with open(os.path.join(sortie, 'compilation.log'), 'w') as j:
        if subprocess.run([o.xcodebuild, '-project', a.projet, '-scheme', a.schema, '-configuration', 'Release',
                           '-destination', 'generic/platform=macOS', '-derivedDataPath', dd] + reglages + ['build'],
                          stdout=j, stderr=subprocess.STDOUT).returncode != 0:
            raise Refus('compilation en echec (voir %s)' % j.name)
    app = os.path.join(dd, 'Build', 'Products', 'Release', a.nom_app + '.app')
    with open(os.path.join(app, 'Contents', 'Info.plist'), 'rb') as f:
        info = plistlib.load(f)
    attendu = {'CFBundleShortVersionString': version, 'CFBundleVersion': str(numero),
               'SUPublicEDKey': a.cle_publique or reglage('project.yml', a.cible, 'CLE_MISES_A_JOUR'),
               'SUFeedURL': flux or reglage('project.yml', a.cible, 'FLUX_MISES_A_JOUR')}
    for cle, valeur in attendu.items():
        if info.get(cle) != valeur:
            raise Refus('Info.plist de l\'app compilee : %s = %r, attendu %r' % (cle, info.get(cle), valeur))
    for chemin in code_imbrique(app) + [app]:
        signer(a, o, chemin)
    lancer([o.codesign, '--verify', '--deep', '--strict', app])
    exigence = subprocess.run([o.codesign, '-d', '-r-', app], check=True, capture_output=True,
                              text=True).stdout.strip()
    ecrire(os.path.join(sortie, 'exigence.txt'), exigence + '\n')
    dire('exigence de signature : ' + exigence)

    # 4. le .dmg
    nom_dmg = '%s-%s.dmg' % (a.fichier, version)
    dmg = os.path.join(sortie, nom_dmg)
    scene = os.path.join(sortie, 'dmg')
    shutil.rmtree(scene, ignore_errors=True)
    os.makedirs(scene)
    lancer(['ditto', app, os.path.join(scene, a.nom_app + '.app')])
    os.symlink('/Applications', os.path.join(scene, 'Applications'))
    if os.path.exists(dmg):
        os.remove(dmg)
    lancer([o.hdiutil, 'create', '-quiet', '-volname', '%s %s' % (a.nom_app, version), '-srcfolder', scene,
            '-fs', 'HFS+', '-format', 'UDZO', dmg])
    shutil.rmtree(scene)
    if notariser():
        # Avant la signature Ed25519 : l'agrafe change le .dmg.
        signer(a, o, dmg, droits=False)
        lancer([o.xcrun, 'notarytool', 'submit', dmg, '--keychain-profile', os.environ['PROFIL_NOTARISATION'],
                '--wait'])
        lancer([o.xcrun, 'stapler', 'staple', dmg])
        lancer([o.spctl, '--assess', '--type', 'open', '--context', 'context:primary-signature', '--verbose', dmg])
        dire('notarise et agrafe : ' + dmg)

    # 5. la signature, puis le flux
    signe = [o.sign_update] + (['--ed-key-file', a.cle_privee] if a.cle_privee else []) + ['-p', dmg]
    signature = lancer(signe).strip()
    texte_notes = notes('NOTES-VERSIONS.md', version)
    item = item_flux(version, numero, '%s/%s' % (url_dmg, nom_dmg), os.path.getsize(dmg), signature, systeme,
                     notes_html(texte_notes), maintenant or datetime.datetime.utcnow())
    xml = ajouter_au_flux(lire(a.flux) if os.path.exists(a.flux) else None, a.nom_app, version, item)
    # Le nouveau flux, d'abord a cote : il n'entre dans le depot qu'apres le controle.
    chemin_flux = os.path.join(sortie, 'appcast.xml')
    ecrire(chemin_flux, xml)
    chemin_notes = os.path.join(sortie, 'notes.md')
    ecrire(chemin_notes, texte_notes)
    chemin_message = os.path.join(sortie, 'message-commit.txt')
    ecrire(chemin_message, message_flux(a.nom_app, version))
    dire('signe : %s (%d octets) ; flux : %s' % (dmg, os.path.getsize(dmg), chemin_flux))

    # 6. le controle d'anonymisation, s'il est present (prive)
    if os.path.exists(o.controle) and os.path.exists(o.table):
        textes = ['NOTES-VERSIONS.md', chemin_flux, chemin_notes, chemin_message] + a.textes
        r = subprocess.run(['/usr/bin/python3', o.controle, 'fichiers', '--table', o.table] + textes,
                           capture_output=True, text=True)
        dire('controle d\'anonymisation : ' + ' ; '.join(r.stdout.strip().splitlines()))
        if r.returncode != 0:
            raise Refus("le controle d'anonymisation a trouve des donnees reelles : rien n'est publie")
    else:
        dire("controle d'anonymisation absent de ce Mac : saute")

    # 7. la publication : l'etiquette et la version publiee, avec le .dmg ; puis le flux, commite et pousse
    if not a.repetition:
        lancer([o.git, 'tag', etiquette])
        lancer([o.git, 'push', 'origin', etiquette])
        lancer([o.gh, 'release', 'create', etiquette, dmg, '-R', a.depot_github, '--verify-tag',
                '--title', '%s %s' % (a.nom_app, version), '--notes-file', chemin_notes])
        dire('publie : https://github.com/%s/releases/tag/%s' % (a.depot_github, etiquette))
    shutil.copyfile(chemin_flux, a.flux)
    lancer([o.git, 'add', a.flux])
    lancer([o.git, 'commit', '-q', '-F', chemin_message])
    if a.repetition:
        dire('repetition : flux commite dans la copie (%s), ni etiquette, ni GitHub, ni Bureau ; produits dans %s'
             % (chemin_flux_depot, sortie))
        return sortie
    lancer([o.git, 'push', 'origin', 'main'])
    dire('flux commite et pousse sur main : https://raw.githubusercontent.com/%s/main/%s'
         % (a.depot_github, chemin_flux_depot))

    # 8. la remise
    if not a.sans_bureau:
        shutil.copy2(dmg, os.path.expanduser('~/Desktop'))
        dire('copie sur le Bureau : ' + nom_dmg)
    return sortie


def arguments(argv):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sous = p.add_subparsers(dest='commande', required=True)
    q = sous.add_parser('publier')
    q.add_argument('version')
    for nom in ('--nom-app', '--fichier', '--depot-github', '--projet', '--schema', '--cible'):
        q.add_argument(nom, required=True)
    q.add_argument('--test', action='append', default=[], help='commande de tests (shell), dans l\'ordre')
    q.add_argument('--textes', action='append', default=[], help="textes de l'app pour le controle d'anonymisation")
    q.add_argument('--identite', required=True, help='nom du certificat de signature, dans le trousseau')
    q.add_argument('--etiquette', required=True, help="debut de l'etiquette de l'app, suivi de X.Y.Z (maillage-v)")
    q.add_argument('--flux', required=True, help='le flux du depot (appcast.xml), depuis le dossier de publier.sh')
    q.add_argument('--trousseau', help='en repetition : un trousseau a part, ou chercher l\'identite')
    q.add_argument('--sans-bureau', action='store_true')
    q.add_argument('--repetition', metavar='DOSSIER')
    q.add_argument('--url-base')
    q.add_argument('--cle-privee')
    q.add_argument('--cle-publique')
    q.add_argument('--sans-tests', action='store_true')
    a = p.parse_args(argv)
    if a.repetition and not a.url_base:
        p.error('--repetition demande --url-base')
    if bool(a.cle_privee) != bool(a.cle_publique):
        p.error('--cle-privee et --cle-publique vont ensemble')
    if not a.repetition and (a.url_base or a.cle_privee or a.trousseau):
        p.error('--url-base, --cle-privee, --cle-publique et --trousseau seulement en repetition')
    return a


def main(argv=None):
    a = arguments(sys.argv[1:] if argv is None else argv)
    try:
        publier(a)
    except Refus as e:
        print('refus : %s' % e, file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as e:
        print('echec : %s (code %d)\n%s' % (' '.join(map(shlex.quote, e.cmd)), e.returncode, (e.stderr or '')[-2000:]),
              file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
```

`apps/macos/Outils/publier.sh` :

```sh
#!/bin/sh
# Publie une version de Halo Compagnon sur GitHub (spec du deploiement, section 3) : verifications, numeros,
# compilation Release signee par le certificat de Djoko, .dmg signe par Sparkle (cle du trousseau), controle
# d'anonymisation, version publiee (etiquette compagnon-vX.Y.Z, avec le .dmg), puis le flux des mises a jour
# (apps/macos/appcast.xml, qui garde toutes les versions) commite sur main et pousse aussitot, .dmg sur le Bureau.
# La logique est dans Outils/publication.py, ses tests dans Outils/tests.
#   apps/macos/Outils/publier.sh X.Y.Z [--sans-bureau]
# La repetition, sans GitHub ni Bureau (spec, section 4), avec la cle du trousseau, ou une paire d'essai :
#   apps/macos/Outils/publier.sh X.Y.Z --repetition DOSSIER --url-base URL [--cle-privee FICHIER --cle-publique CLE]
#                                      [--trousseau TROUSSEAU] [--sans-tests]
# SPARKLE_BIN : le dossier bin de l'archive de Sparkle 2.10.0 (sign_update, generate_keys).
# NOTARISER=1 (desactive par defaut) : notarisation du .dmg, avec PROFIL_NOTARISATION, le profil que
# notarytool store-credentials a range dans le trousseau ; il faut alors un Developer ID pour IDENTITE_SIGNATURE.
# Produits : apps/macos/build/publication/X.Y.Z/ ; compilation dans DD (par defaut, hors de ~/Documents :
# DerivedData/halo-compagnon-publication). Le numero de compilation compte les commits de tout le depot.
set -eu
cd "$(dirname "$0")/.."
# L'identite de signature de la version publiee, a ce seul endroit : le certificat auto-signe de Djoko, trouve par
# son nom dans le trousseau (les compilations de travail et les tests restent ad hoc).
IDENTITE_SIGNATURE=${IDENTITE_SIGNATURE:-Djoko-cli Code Signing}
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/halo-compagnon-publication}
export DD
exec /usr/bin/python3 Outils/publication.py publier "$@" --identite "$IDENTITE_SIGNATURE" \
  --etiquette compagnon-v --flux appcast.xml \
  --nom-app "Halo Compagnon" --fichier Halo-Compagnon --depot-github Djoko-cli/benq-screenbar-halo-matter \
  --projet HaloCompagnon.xcodeproj --schema HaloCompagnon --cible HaloCompagnon \
  --test 'xcodegen generate --quiet && xcodebuild -project HaloCompagnon.xcodeproj -scheme HaloCompagnon -destination platform=macOS -derivedDataPath "$DD" test' \
  --test 'xcodebuild -project HaloCompagnon.xcodeproj -scheme HaloCompagnon -destination platform=macOS -derivedDataPath "$DD" -testLanguage en -testRegion US test' \
  --test '/usr/bin/python3 -m unittest discover -s Outils/tests' \
  --test 'cd ../.. && sh tools/test_halo1.sh && /usr/bin/python3 tools/test_halo_udp.py && sh tools/macos/thread-route/tests.sh' \
  --textes HaloCompagnon/Ressources/Localizable.xcstrings --textes HaloCompagnon/Ressources/InfoPlist.xcstrings \
  --textes HaloCompagnon/Ressources/Titres.xcstrings
```

```bash
W=$S/deploiement-exec; cd "$W/halo/apps/macos" && chmod 755 Outils/publier.sh && /usr/bin/python3 -W error::ResourceWarning -m unittest discover -s Outils/tests 2>&1 | tail -3; cmp Outils/publication.py "$W/maillage/outils/publication.py" && cmp Outils/tests/test_publication.py "$W/maillage/outils/tests/test_publication.py" && echo identiques
```

Expected : `Ran 34 tests`, `OK` ; `identiques`.

- [ ] **Step 3 : commit.**

```bash
W=$S/deploiement-exec; cd "$W/halo" && git add apps/macos/Outils/publication.py apps/macos/Outils/publier.sh apps/macos/Outils/tests/test_publication.py && git commit -q -F - <<'EOF'
Ecrire apps/macos/Outils/publier.sh : verifications, numeros, .dmg signe, appcast.xml, controle d'anonymisation, version publiee

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `0`.

---

### Task 9: Les notes de la version 1.0.0 et les README, dans les deux dépôts

**Files :**
- Create : `NOTES-VERSIONS.md` (Maillage Thread), `apps/macos/NOTES-VERSIONS.md` (pont Halo)
- Modify : `README.md`, `README.fr.md` (Maillage Thread) ; `apps/macos/README.md`, `apps/macos/README.fr.md` (pont Halo) ; `docs/superpowers/specs/2026-10-06-deploiement-design.md` (les deux dépôts) (blocs)

**Interfaces:**
- Consumes : les sections `## X.Y.Z` que lit `publication.notes` (tâches 7 et 8).
- Produces : la section `## 1.0.0`, en français puis en anglais ; dans chaque README : installer depuis les versions publiées, Gatekeeper à la première ouverture (le certificat auto-signé, le mot de passe), la mise à jour automatique, Thread Route, publier (le certificat, la notarisation désactivée) ; pour Maillage Thread, le passeur compilé à part ; pour Halo Compagnon, le trousseau, gardé d'une version publiée à la suivante ; la spec corrigée, identique dans les deux dépôts (décisions de Djoko du 06/10 : le certificat, la distribution large ; et le résultat de l'essai).

- [ ] **Step 1 : Maillage Thread** (`--etapes 1`, depuis `$W/maillage`).

`NOTES-VERSIONS.md` :

```markdown
# Notes de version · Release notes

Maillage Thread : une section par version publiée, en français puis en anglais. `outils/publier.sh` en tire les
notes de la version publiée sur GitHub et celles de la fenêtre de mise à jour.

Maillage Thread: one section per published version, in French then in English. `outils/publier.sh` takes from it
the notes of the GitHub release and those of the update window.

## 1.0.0

**Français**

- Première version publiée : l'app de la barre des menus qui montre le réseau Thread vu depuis le Mac (routeurs
  de bordure, partitions, préfixes OMR, appareils), tient le journal des changements et notifie les alertes ; la
  vue par pièces en 2D et en 3D ; les noms de Maison par Passeur Noms ; le vrai maillage par la sonde, en USB ou
  par le réseau Thread.
- Mises à jour automatiques (Sparkle 2) : recherche au démarrage puis toutes les 24 heures, téléchargement et
  installation à la fermeture de l'app, ou tout de suite par « Installer et relancer ». « Rechercher les mises à
  jour… » est dans le menu ; Réglages, Général, « Mises à jour », permet de les arrêter.
- Thread Route, l'assistant système qui garde la route du Mac vers le réseau Thread (anciennement halo-routes) :
  son état est dans Réglages, Diagnostic ; il s'installe par `sh outils/thread-route/installer.sh`.

**English**

- First published version: the menu bar app that shows the Thread network as seen from the Mac (border routers,
  partitions, OMR prefixes, devices), keeps a log of changes and notifies the alerts; the room view in 2D and 3D;
  Home names through Passeur Noms; the real mesh through the probe, over USB or over the Thread network.
- Automatic updates (Sparkle 2): a check at launch and then every 24 hours, download, and installation when the
  app quits, or right away with "Install and Relaunch". "Check for Updates…" is in the menu; Settings, General,
  "Updates", can turn them off.
- Thread Route, the system helper that keeps the Mac's route to the Thread network (formerly halo-routes): its
  status is in Settings, Diagnostics; it installs with `sh outils/thread-route/installer.sh`.
```

Dans `README.md`, remplacer :

```markdown
in its own partition. The app shows that at a glance and remembers it.
```

par :

```markdown
in its own partition. The app shows that at a glance and remembers it.

## Installing

Download `Maillage-Thread-X.Y.Z.dmg` from the latest
[release](https://github.com/Djoko-cli/maillage-thread/releases) (`maillage-vX.Y.Z`),
open it, and drag **Maillage Thread** onto **Applications**. macOS 26 or later.

- **First launch (Gatekeeper).** The app is signed with a self-signed
  certificate, `Djoko-cli Code Signing`, not with an Apple Developer ID, and
  isn't notarized. macOS refuses to open it the first time: in System
  Settings, Privacy & Security, click "Open Anyway" next to Maillage Thread,
  then confirm with your password (since macOS 15, a right-click no longer
  does it). Only once.
- **Automatic updates** (Sparkle 2). The app checks for a new version at
  launch and then every 24 hours, downloads it, checks its Ed25519 signature,
  and installs it when the app quits, or right away with "Install and
  Relaunch". An update installed this way doesn't go back through Gatekeeper:
  the signature takes its place. "Check for Updates…" is in the menu; Settings,
  General, "Updates", has "Check for updates automatically" and "Install
  updates automatically", both on by default. A copy downloaded before the
  first version with Sparkle (1.0.0) doesn't update itself.
- **Thread Route.** To reach the probe over the Thread network, the Mac needs
  a route to it, which Thread Route keeps (see "Route to the Thread network"
  below). It installs from a copy of this repository:
  `sh outils/thread-route/installer.sh` (administrator password). Settings,
  Diagnostics, shows its status.
- **Passeur Noms is not distributed.** It is an app "Designed for iPad" that
  everyone builds and signs with their own Apple team: `outils/passeur.sh`
  (see "Home names" below).
```

Dans `README.md`, remplacer :

```markdown
No third-party dependency. The Xcode project is generated: only `project.yml`
is tracked.

```

par :

```markdown
One dependency, Sparkle 2 (2.10.0, the updates), through the Swift Package
Manager. The Xcode project is generated: only `project.yml` is tracked.

```

Dans `README.md`, remplacer :

```markdown
## Texts: French and English
```

par :

```markdown
### Publishing a version

`outils/publier.sh X.Y.Z` publishes version X.Y.Z, the `MARKETING_VERSION` of
`project.yml`, from an up-to-date `main`: it checks that the version doesn't
exist yet, runs all the tests, builds in Release, signs the app with the
`Djoko-cli Code Signing` certificate of the keychain (`IDENTITE_SIGNATURE`,
in `publier.sh` only: work builds and tests stay ad hoc), makes the `.dmg`
(the app and a shortcut to Applications), signs it with the Ed25519 key of
the keychain (`sign_update` from the Sparkle 2.10.0 archive, whose `bin`
folder is given by `SPARKLE_BIN`), adds the version, with the notes of
`NOTES-VERSIONS.md`, at the top of the update feed, `appcast.xml`, which keeps
every published version, runs the anonymization check if it is on the Mac (it
is private), tags `maillage-vX.Y.Z`, creates the GitHub release with the
`.dmg`, commits the feed on `main` and pushes it right away, and copies the
`.dmg` to the Desktop. The build number, which Sparkle compares, is the number
of commits of `main`. The app reads its feed in the repository, at
`https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml`;
each `.dmg` stays in its release.
With `--repetition`, the same without GitHub or Desktop, for a local trial,
with a test key pair and a test certificate in a separate keychain if given.
A notarization step (Developer ID) is written but off: `NOTARISER=1`, with
`PROFIL_NOTARISATION`, the keychain profile of `notarytool store-credentials`.
Tests: `/usr/bin/python3 -m unittest discover -s outils/tests`.

## Texts: French and English
```

Dans `README.md`, remplacer :

```markdown
| `MaillageThread/Surveillance/` | app model: surveys → tracking → log and notifications; sleep of the Mac; login item |
| `MaillageThread/Vues/` | menu bar, room view window (`Pieces/`: `Canvas` engine, glass overlays, captures), log window, settings (AppKit window with tabs: General, Notifications, Home, Probe, Diagnostics; ⌘,) |
```

par :

```markdown
| `MaillageThread/Surveillance/` | app model: surveys → tracking → log and notifications; sleep of the Mac; login item; updates (Sparkle); Thread Route status |
| `MaillageThread/Vues/` | menu bar, room view window (`Pieces/`: `Canvas` engine, glass overlays, captures), log window, settings (AppKit window with tabs: General, Notifications, Home, Probe, Diagnostics; ⌘,) |
```

Dans `README.md`, remplacer :

```markdown
| `docs/releves/` | real surveys (the fixture of the tests and the demo) |
```

par :

```markdown
| `outils/thread-route/` | Thread Route, an identical copy of its source (Halo bridge repository, `tools/macos/thread-route`), at the revision noted in `outils/thread-route.source`; `outils/synchroniser-thread-route.sh` copies it again, `outils/tests/test_thread_route.py` checks it |
| `outils/publier.sh`, `outils/publication.py` | publishing a version (see "Publishing a version"); tests in `outils/tests/` |
| `NOTES-VERSIONS.md` | release notes, in French and English |
| `docs/releves/` | real surveys (the fixture of the tests and the demo) |
```

Dans `README.md`, remplacer :

```markdown
routers that advertise it (setting one takes administrator rights). The
author uses a helper from another of their projects for this; it is not
part of this repository.

```

par :

```markdown
routers that advertise it (setting one takes administrator rights). Thread
Route keeps it: a root launchd daemon from the Halo bridge repository, of
which `outils/thread-route/` is an identical copy. It installs with
`sh outils/thread-route/installer.sh`, under your own account (the
administrator password is asked for the installation only); see its README.
The app can't install it itself: in the sandbox, `SMAppService` refuses a
daemon that isn't sandboxed (trial of Oct 6, 2026). Settings, Diagnostics,
shows its status: absent, turned off in System Settings, active, or still
under its former name, halo-routes, which the installer replaces.

```

Dans `README.fr.md`, remplacer :

```markdown
le garde en mémoire.
```

par :

```markdown
le garde en mémoire.

## Installer

Télécharger `Maillage-Thread-X.Y.Z.dmg` depuis la dernière
[version publiée](https://github.com/Djoko-cli/maillage-thread/releases) (`maillage-vX.Y.Z`),
l'ouvrir, et glisser **Maillage Thread** sur **Applications**. macOS 26 ou
plus.

- **Première ouverture (Gatekeeper).** L'app est signée par un certificat
  auto-signé, `Djoko-cli Code Signing`, sans Developer ID d'Apple ni
  notarisation. macOS refuse de l'ouvrir la première fois : dans Réglages
  Système, Confidentialité et sécurité, cliquer « Ouvrir quand même » en face
  de Maillage Thread, puis confirmer avec son mot de passe (depuis macOS 15, le
  clic droit ne suffit plus). Une seule fois.
- **Mises à jour automatiques** (Sparkle 2). L'app recherche une nouvelle
  version au démarrage puis toutes les 24 heures, la télécharge, vérifie sa
  signature Ed25519, et l'installe quand l'app se ferme, ou tout de suite par
  « Installer et relancer ». Une mise à jour installée ainsi ne repasse pas
  par Gatekeeper : la signature en tient lieu. « Rechercher les mises à
  jour… » est dans le menu ; Réglages, Général, « Mises à jour », porte
  « Rechercher automatiquement » et « Installer automatiquement », cochés par
  défaut. Une copie téléchargée avant la première version avec Sparkle
  (1.0.0) ne se met pas à jour seule.
- **Thread Route.** Pour joindre la sonde par le réseau Thread, il faut au
  Mac une route vers lui, que garde Thread Route (voir « Route vers le réseau
  Thread » plus bas). Il s'installe depuis une copie de ce dépôt :
  `sh outils/thread-route/installer.sh` (mot de passe administrateur).
  Réglages, Diagnostic, montre son état.
- **Passeur Noms n'est pas distribué.** C'est une app « conçue pour iPad »
  que chacun compile et signe avec sa propre équipe Apple :
  `outils/passeur.sh` (voir « Noms de Maison » plus bas).
```

Dans `README.fr.md`, remplacer :

```markdown
Aucune dépendance tierce. Le projet Xcode est généré : seul `project.yml` est
suivi.

```

par :

```markdown
Une dépendance, Sparkle 2 (2.10.0, les mises à jour), par le gestionnaire de
paquets Swift. Le projet Xcode est généré : seul `project.yml` est suivi.

```

Dans `README.fr.md`, remplacer :

```markdown
## Textes : français et anglais
```

par :

```markdown
### Publier une version

`outils/publier.sh X.Y.Z` publie la version X.Y.Z, le `MARKETING_VERSION` de
`project.yml`, depuis `main` à jour : il vérifie que la version n'existe pas
encore, lance tous les tests, compile en Release, signe l'app par le
certificat `Djoko-cli Code Signing` du trousseau (`IDENTITE_SIGNATURE`, dans
`publier.sh` seulement : les compilations de travail et les tests restent ad
hoc), fait le `.dmg`
(l'app et un raccourci vers Applications), le signe avec la clé Ed25519 du
trousseau (`sign_update` de l'archive de Sparkle 2.10.0, dont `SPARKLE_BIN`
donne le dossier `bin`), ajoute la version, avec les notes de
`NOTES-VERSIONS.md`, en tête du flux des mises à jour, `appcast.xml`, qui
garde toutes les versions publiées, passe le contrôle d'anonymisation s'il est
sur le Mac (il est privé), pose l'étiquette `maillage-vX.Y.Z`, crée la version
publiée sur GitHub avec le `.dmg`, commite le flux sur `main` et le pousse
aussitôt, et copie le `.dmg` sur le Bureau. Le numéro de compilation, que
compare Sparkle, est le nombre de commits de `main`. L'app lit son flux dans
le dépôt, à
`https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml` ;
chaque `.dmg` reste dans sa version publiée.
Avec `--repetition`, la même chose sans GitHub ni Bureau, pour un essai
local, avec une paire de clés d'essai et un certificat d'essai dans un
trousseau à part, s'ils sont donnés. Une étape de notarisation (Developer ID)
est écrite, désactivée : `NOTARISER=1`, avec `PROFIL_NOTARISATION`, le
profil du trousseau que range `notarytool store-credentials`.
Tests : `/usr/bin/python3 -m unittest discover -s outils/tests`.

## Textes : français et anglais
```

Dans `README.fr.md`, remplacer :

```markdown
| `MaillageThread/Surveillance/` | modèle de l'app : relevés → suivi → journal et notifications ; veille du Mac ; ouverture à la connexion |
| `MaillageThread/Vues/` | barre des menus, fenêtre de la vue par pièces (`Pieces/` : moteur `Canvas`, surcouches en verre, captures), journal, réglages (fenêtre AppKit à onglets : Général, Notifications, Maison, Sonde, Diagnostic ; ⌘,) |
```

par :

```markdown
| `MaillageThread/Surveillance/` | modèle de l'app : relevés → suivi → journal et notifications ; veille du Mac ; ouverture à la connexion ; mises à jour (Sparkle) ; état de Thread Route |
| `MaillageThread/Vues/` | barre des menus, fenêtre de la vue par pièces (`Pieces/` : moteur `Canvas`, surcouches en verre, captures), journal, réglages (fenêtre AppKit à onglets : Général, Notifications, Maison, Sonde, Diagnostic ; ⌘,) |
```

Dans `README.fr.md`, remplacer :

```markdown
| `docs/releves/` | relevés réels (les données des tests et de la démo) |
```

par :

```markdown
| `outils/thread-route/` | Thread Route, copie à l'identique de sa source (dépôt du pont Halo, `tools/macos/thread-route`), à la révision notée dans `outils/thread-route.source` ; `outils/synchroniser-thread-route.sh` la refait, `outils/tests/test_thread_route.py` la vérifie |
| `outils/publier.sh`, `outils/publication.py` | publication d'une version (voir « Publier une version ») ; tests dans `outils/tests/` |
| `NOTES-VERSIONS.md` | notes de version, en français et en anglais |
| `docs/releves/` | relevés réels (les données des tests et de la démo) |
```

Dans `README.fr.md`, remplacer :

```markdown
l'annoncent (la poser demande les droits d'administrateur). L'auteur utilise
pour cela un assistant de son autre projet, qui n'est pas dans ce dépôt.

```

par :

```markdown
l'annoncent (la poser demande les droits d'administrateur). Thread Route la
garde : un démon launchd (root) du dépôt du pont Halo, dont
`outils/thread-route/` est une copie à l'identique. Il s'installe par
`sh outils/thread-route/installer.sh`, sous son compte (le mot de passe
administrateur n'est demandé que pour l'installation) ; voir son README.
L'app ne peut pas l'installer elle-même : dans le bac à sable, `SMAppService`
refuse un démon qui n'y est pas (essai du 06/10/2026). Réglages, Diagnostic,
montre son état : absent, désactivé dans Réglages Système, actif, ou encore
sous son ancien nom, halo-routes, que l'installateur remplace.

```

- [ ] **Step 2 : les notes se lisent.**

Run : `W=$S/deploiement-exec; cd "$W/maillage" && /usr/bin/python3 -c "import sys; sys.path.insert(0, 'outils'); import publication as p; n = p.notes('NOTES-VERSIONS.md', '1.0.0'); print(n.splitlines()[0], len(p.notes_html(n)) > 0)"`

Expected : `**Français** True`.

- [ ] **Step 3 : commit.**

```bash
W=$S/deploiement-exec; cd "$W/maillage" && git add NOTES-VERSIONS.md README.md README.fr.md && git commit -q -F - <<'EOF'
Ecrire les notes de la version 1.0.0 et dire dans le README l'installation, Gatekeeper, les mises a jour et Thread Route

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `0`.

- [ ] **Step 4 : Halo Compagnon** (`--etapes 4`, depuis `$W/halo`).

`apps/macos/NOTES-VERSIONS.md` :

```markdown
# Notes de version · Release notes

Halo Compagnon : une section par version publiée, en français puis en anglais. `apps/macos/Outils/publier.sh` en
tire les notes de la version publiée sur GitHub et celles de la fenêtre de mise à jour.

Halo Compagnon: one section per published version, in French then in English. `apps/macos/Outils/publier.sh` takes
from it the notes of the GitHub release and those of the update window.

## 1.0.0

**Français**

- Première version publiée : l'app qui supervise le pont de la BenQ ScreenBar Halo 1, par l'USB ou par le réseau
  Thread (tableau de bord, trames en direct, graphiques, commandes et console), en français et en anglais, avec
  son mode démo.
- Mises à jour automatiques (Sparkle 2) : recherche au démarrage puis toutes les 24 heures, téléchargement et
  installation à la fermeture de l'app, ou tout de suite par « Installer et relancer ». « Rechercher les mises à
  jour… » est dans le menu Halo Compagnon ; Réglages, Général, « Mises à jour », permet de les arrêter.
- Thread Route, l'assistant système qui garde la route du Mac vers le réseau Thread (anciennement halo-routes) :
  son état est dans Réglages, Général ; il s'installe par `sh tools/macos/thread-route/installer.sh`.

**English**

- First published version: the app that supervises the BenQ ScreenBar Halo 1 bridge, over USB or over the Thread
  network (dashboard, live frames, charts, controls and console), in French and English, with its demo mode.
- Automatic updates (Sparkle 2): a check at launch and then every 24 hours, download, and installation when the
  app quits, or right away with "Install and Relaunch". "Check for Updates…" is in the Halo Compagnon menu;
  Settings, General, "Updates", can turn them off.
- Thread Route, the system helper that keeps the Mac's route to the Thread network (formerly halo-routes): its
  status is in Settings, General; it installs with `sh tools/macos/thread-route/installer.sh`.
```

Dans `apps/macos/README.md`, remplacer :

```markdown
## Build, Test, Run
```

par :

```markdown
## Installing

Download `Halo-Compagnon-X.Y.Z.dmg` from the latest Halo Compagnon
[release](https://github.com/Djoko-cli/benq-screenbar-halo-matter/releases) (`compagnon-vX.Y.Z`),
open it, and drag **Halo Compagnon** onto **Applications**. macOS 15 or later.

- **First launch (Gatekeeper).** The app is signed with a self-signed
  certificate, `Djoko-cli Code Signing`, not with an Apple Developer ID, and
  isn't notarized. macOS refuses to open it the first time: in System
  Settings, Privacy & Security, click "Open Anyway" next to Halo Compagnon,
  then confirm with your password (since macOS 15, a right-click no longer
  does it). Only once.
- **Automatic Updates** (Sparkle 2). The app checks for a new version at
  launch and then every 24 hours, downloads it, checks its Ed25519 signature,
  and installs it when the app quits, or right away with "Install and
  Relaunch". An update installed this way doesn't go back through Gatekeeper:
  the signature takes its place. "Check for Updates…" is in the Halo
  Compagnon menu; Settings, General, "Updates", has "Check for updates
  automatically" and "Install updates automatically", both on by default. A
  copy downloaded before the first version with Sparkle (1.0.0) doesn't
  update itself.
- **Keychain.** Every published version is signed by the same certificate:
  an update keeps access to the bridge's key in the keychain (network
  source). macOS will likely ask again only when switching between a work
  build, signed ad hoc, and a published version.
- **Thread Route.** The network source needs the Mac's route to the Thread
  network, which Thread Route keeps (see "No IPv6 route" under "Network
  Source"). It installs from a copy of this repository:
  `sh tools/macos/thread-route/installer.sh` (administrator password).
  Settings, General, shows its status.

## Build, Test, Run
```

Dans `apps/macos/README.md`, remplacer :

```markdown
No third-party dependencies. The Xcode project is generated: only
`project.yml` is tracked.

```

par :

```markdown
One dependency, Sparkle 2 (2.10.0, the updates), through the Swift Package
Manager. The Xcode project is generated: only `project.yml` is tracked.

```

Dans `apps/macos/README.md`, remplacer :

```markdown

## Languages: French and English
```

par :

```markdown

### Publishing a Version

`apps/macos/Outils/publier.sh X.Y.Z` publishes version X.Y.Z, the
`MARKETING_VERSION` of `project.yml`, from an up-to-date `main`: it checks
that the version doesn't exist yet, runs all the tests (the app in French and
English, the host tests of the bridge, Thread Route), builds in Release,
signs the app with the `Djoko-cli Code Signing` certificate of the
keychain (`IDENTITE_SIGNATURE`, in `publier.sh` only: work builds and tests
stay ad hoc), makes the `.dmg` (the app and a shortcut to Applications), signs it
with the Ed25519 key of the keychain (`sign_update` from the Sparkle 2.10.0
archive, whose `bin` folder is given by `SPARKLE_BIN`), adds the version,
with the notes of `NOTES-VERSIONS.md`, at the top of the update feed,
`apps/macos/appcast.xml`, which keeps every published version, runs the
anonymization check if it is on the Mac (it is private), tags
`compagnon-vX.Y.Z` (the app's own tags, apart from the bridge's), creates the
GitHub release with the `.dmg`, commits the feed on `main` and pushes it
right away, and copies the `.dmg` to the Desktop. The build number, which
Sparkle compares, is the number of commits of `main` (the whole repository).
The app reads its feed in the repository, at
`https://raw.githubusercontent.com/Djoko-cli/benq-screenbar-halo-matter/main/apps/macos/appcast.xml`;
each `.dmg` stays in its release.
With `--repetition`, the same without GitHub or Desktop, for a local trial,
with a test key pair and a test certificate in a separate keychain if given.
A notarization step (Developer ID) is written but off: `NOTARISER=1`, with
`PROFIL_NOTARISATION`, the keychain profile of `notarytool store-credentials`.
Tests: `/usr/bin/python3 -m unittest discover -s Outils/tests`.

## Languages: French and English
```

Dans `apps/macos/README.md`, remplacer :

```markdown
│   ├── Modele/                  Pont (@Observable, main actor): connects transport, receiver, engine, state, logs; language setting; network source and key creation
│   ├── Reseau/                  Trousseau (this Mac's session keychain, service fr.djoko.halo.pont), AlerteReseau (banner, "No IPv6 route" message)
│   ├── Vues/                    the four screens, their components, Settings
```

par :

```markdown
│   ├── Modele/                  Pont (@Observable, main actor): connects transport, receiver, engine, state, logs; language setting; network source and key creation; updates (MisesAJour, Sparkle)
│   ├── Reseau/                  Trousseau (this Mac's session keychain, service fr.djoko.halo.pont), AlerteReseau (banner, "No IPv6 route" message), ThreadRoute (Thread Route status)
│   ├── Vues/                    the four screens, their components, Settings
```

Dans `apps/macos/README.md`, remplacer :

```markdown
├── HaloCompagnonTests/          end-to-end on the simulated board (connection, delivered command, refusal, whole timeline sped up, restart, source change), app language
└── Outils/generer_demo.py       demo timeline generator
```

par :

```markdown
├── HaloCompagnonTests/          end-to-end on the simulated board (connection, delivered command, refusal, whole timeline sped up, restart, source change), app language
├── NOTES-VERSIONS.md            release notes, in French and English
└── Outils/                      generer_demo.py (demo timeline generator), publier.sh and publication.py (publishing a version, tests in Outils/tests)
```

Dans `apps/macos/README.fr.md`, remplacer :

```markdown
## Construire, tester, lancer
```

par :

```markdown
## Installer

Télécharger `Halo-Compagnon-X.Y.Z.dmg` depuis la dernière
[version publiée](https://github.com/Djoko-cli/benq-screenbar-halo-matter/releases) de Halo Compagnon (`compagnon-vX.Y.Z`),
l'ouvrir, et glisser **Halo Compagnon** sur **Applications**. macOS 15 ou plus.

- **Première ouverture (Gatekeeper).** L'app est signée par un certificat
  auto-signé, `Djoko-cli Code Signing`, sans Developer ID d'Apple ni
  notarisation. macOS refuse de l'ouvrir la première fois : dans Réglages
  Système, Confidentialité et sécurité, cliquer « Ouvrir quand même » en face
  de Halo Compagnon, puis confirmer avec son mot de passe (depuis macOS 15, le
  clic droit ne suffit plus). Une seule fois.
- **Mises à jour automatiques** (Sparkle 2). L'app recherche une nouvelle
  version au démarrage puis toutes les 24 heures, la télécharge, vérifie sa
  signature Ed25519, et l'installe quand l'app se ferme, ou tout de suite par
  « Installer et relancer ». Une mise à jour installée ainsi ne repasse pas
  par Gatekeeper : la signature en tient lieu. « Rechercher les mises à
  jour… » est dans le menu Halo Compagnon ; Réglages, Général, « Mises à
  jour », porte « Rechercher automatiquement » et « Installer
  automatiquement », cochés par défaut. Une copie téléchargée avant la
  première version avec Sparkle (1.0.0) ne se met pas à jour seule.
- **Trousseau.** Toutes les versions publiées sont signées par le même
  certificat : une mise à jour garde l'accès à la clé du pont dans le
  trousseau (source réseau). macOS le redemandera sans doute seulement au
  passage d'une compilation de travail, signée ad hoc, à une version publiée,
  et inversement.
- **Thread Route.** La source réseau demande la route du Mac vers le réseau
  Thread, que garde Thread Route (voir « Pas de route » dans « Source
  réseau »). Il s'installe depuis une copie de ce dépôt :
  `sh tools/macos/thread-route/installer.sh` (mot de passe administrateur).
  Réglages, Général, montre son état.

## Construire, tester, lancer
```

Dans `apps/macos/README.fr.md`, remplacer :

```markdown
Aucune dépendance tierce. Le projet Xcode est généré : seul `project.yml` est suivi.

```

par :

```markdown
Une dépendance, Sparkle 2 (2.10.0, les mises à jour), par le gestionnaire de
paquets Swift. Le projet Xcode est généré : seul `project.yml` est suivi.

```

Dans `apps/macos/README.fr.md`, remplacer :

```markdown

## Langues : français et anglais
```

par :

```markdown

### Publier une version

`apps/macos/Outils/publier.sh X.Y.Z` publie la version X.Y.Z, le
`MARKETING_VERSION` de `project.yml`, depuis `main` à jour : il vérifie que la
version n'existe pas encore, lance tous les tests (l'app en français et en
anglais, les tests hôte du pont, Thread Route), compile en Release, signe
l'app par le certificat `Djoko-cli Code Signing` du trousseau
(`IDENTITE_SIGNATURE`, dans `publier.sh` seulement : les compilations de
travail et les tests restent ad hoc),
fait le `.dmg` (l'app et un raccourci vers Applications), le signe avec la
clé Ed25519 du trousseau (`sign_update` de l'archive de Sparkle 2.10.0, dont
`SPARKLE_BIN` donne le dossier `bin`), ajoute la version, avec les notes de
`NOTES-VERSIONS.md`, en tête du flux des mises à jour,
`apps/macos/appcast.xml`, qui garde toutes les versions publiées, passe le
contrôle d'anonymisation s'il est sur le Mac (il est privé), pose l'étiquette
`compagnon-vX.Y.Z` (les étiquettes propres à l'app, à part de celles du pont),
crée la version publiée sur GitHub avec le `.dmg`, commite le flux sur `main`
et le pousse aussitôt, et copie le `.dmg` sur le Bureau. Le numéro de
compilation, que compare Sparkle, est le nombre de commits de `main` (tout le
dépôt). L'app lit son flux dans le dépôt, à
`https://raw.githubusercontent.com/Djoko-cli/benq-screenbar-halo-matter/main/apps/macos/appcast.xml` ;
chaque `.dmg` reste dans sa version publiée.
Avec `--repetition`, la même chose sans GitHub ni Bureau, pour un essai
local, avec une paire de clés d'essai et un certificat d'essai dans un
trousseau à part, s'ils sont donnés. Une étape de notarisation (Developer ID)
est écrite, désactivée : `NOTARISER=1`, avec `PROFIL_NOTARISATION`, le
profil du trousseau que range `notarytool store-credentials`.
Tests : `/usr/bin/python3 -m unittest discover -s Outils/tests`.

## Langues : français et anglais
```

Dans `apps/macos/README.fr.md`, remplacer :

```markdown
│   ├── Modele/                  Pont (@Observable, acteur principal) : relie transport, récepteur, moteur, état, journaux ; réglage de la langue ; source réseau et création de clé
│   ├── Reseau/                  Trousseau (trousseau de session macOS, service fr.djoko.halo.pont), AlerteReseau (bandeau, message "pas de route")
│   ├── Vues/                    les quatre écrans, leurs composants, les Réglages
```

par :

```markdown
│   ├── Modele/                  Pont (@Observable, acteur principal) : relie transport, récepteur, moteur, état, journaux ; réglage de la langue ; source réseau et création de clé ; mises à jour (MisesAJour, Sparkle)
│   ├── Reseau/                  Trousseau (trousseau de session macOS, service fr.djoko.halo.pont), AlerteReseau (bandeau, message "pas de route"), ThreadRoute (état de Thread Route)
│   ├── Vues/                    les quatre écrans, leurs composants, les Réglages
```

Dans `apps/macos/README.fr.md`, remplacer :

```markdown
├── HaloCompagnonTests/          bout en bout sur la carte simulée (connexion, commande livrée, refus, chronologie entière accélérée, redémarrage, changement de source), langue de l'app
└── Outils/generer_demo.py       générateur de la chronologie de démo
```

par :

```markdown
├── HaloCompagnonTests/          bout en bout sur la carte simulée (connexion, commande livrée, refus, chronologie entière accélérée, redémarrage, changement de source), langue de l'app
├── NOTES-VERSIONS.md            notes de version, en français et en anglais
└── Outils/                      generer_demo.py (générateur de la chronologie de démo), publier.sh et publication.py (publication d'une version, tests dans Outils/tests)
```

- [ ] **Step 5 : commit.**

```bash
W=$S/deploiement-exec; cd "$W/halo" && /usr/bin/python3 -c "import sys; sys.path.insert(0, 'apps/macos/Outils'); import publication as p; print(p.notes('apps/macos/NOTES-VERSIONS.md', '1.0.0').splitlines()[0])" && git add apps/macos/NOTES-VERSIONS.md apps/macos/README.md apps/macos/README.fr.md && git commit -q -F - <<'EOF'
Ecrire les notes de la version 1.0.0 de Halo Compagnon et dire dans son README l'installation, Gatekeeper, les mises a jour et Thread Route

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status --short | wc -l
```

Expected : `**Français**` ; `0`.

- [ ] **Step 6 : la spec corrigée, dans Maillage Thread** (`--etapes 6`, depuis `$W/maillage`) : les décisions de Djoko du 06/10 : la signature (sections 0, 3 et 6) ; le flux dans le dépôt et les étiquettes par app (sections 0, 1, 3 et 4) ; Thread Route par son installateur (sections 0, 2, 4 et 5) ; macOS 15.0 pour Halo Compagnon (section 3) ; la distribution large (section 7) ; et les tests nouveaux (section 5).

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
Spec du 06/10/2026. Djoko a validé la conception le même jour. Une copie identique se trouve dans le dépôt du pont Halo (`docs/superpowers/specs/2026-10-06-deploiement-design.md`).

```

par :

```markdown
Spec du 06/10/2026. Djoko a validé la conception le même jour, puis l'a complétée le même jour : la signature des versions publiées par un certificat auto-signé stable ; la préparation d'une distribution large (section 7) ; le flux de versions dans le dépôt, avec des étiquettes propres à chaque app ; Thread Route installé par son installateur, après l'essai (section 2). Une copie identique se trouve dans le dépôt du pont Halo (`docs/superpowers/specs/2026-10-06-deploiement-design.md`).

```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
| Gatekeeper | **la signature Ed25519 le remplace pour les mises à jour** : une mise à jour installée par l'app ne repasse pas par Gatekeeper ; la première installation, depuis le navigateur, y passe |
| Démon | renommé **Thread Route** (`thread-route`, étiquette `fr.djoko.thread.route`) |
| Livraison du démon | **installé par l'app**, avec l'approbation de Djoko dans Réglages Système ; mis à jour avec l'app |
| Porteur du démon | **les deux apps savent l'installer, une seule le fait** ; une seule source, dans le dépôt du pont Halo |
| Premières versions | Maillage Thread **1.0.0**, Halo Compagnon **1.0.0** |
```

par :

```markdown
| Signature du code | les versions publiées sont signées par **un certificat auto-signé stable**, `Djoko-cli Code Signing`, le même pour toutes les apps de Djoko ; les compilations de travail et les tests restent ad hoc |
| Gatekeeper | **la signature Ed25519 le remplace pour les mises à jour** : une mise à jour installée par l'app ne repasse pas par Gatekeeper ; la première installation, depuis le navigateur, y passe |
| Démon | renommé **Thread Route** (`thread-route`, étiquette `fr.djoko.thread.route`) |
| Livraison du démon | **installé par son installateur** (`installer.sh`), avec le mot de passe administrateur, qui fait aussi la migration depuis `halo-routes` ; les deux apps affichent son état et la commande |
| Source du démon | une seule, dans le dépôt du pont Halo ; Maillage Thread en garde une copie à l'identique |
| Flux de versions | **dans le dépôt** (`appcast.xml`), lu à son adresse brute sur `main` ; il garde toutes les versions publiées |
| Étiquettes | **propres à chaque app** : `maillage-vX.Y.Z` et `compagnon-vX.Y.Z` |
| Premières versions | Maillage Thread **1.0.0**, Halo Compagnon **1.0.0** |
```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
- les apps restent signées ad hoc : pas de certificat Developer ID, pas de notarisation, jamais de `Local.xcconfig`, aucun identifiant d'équipe dans un fichier commité ;
- elles restent dans le bac à sable ;
```

par :

```markdown
- **le certificat de signature** est auto-signé, de nom neutre (`Djoko-cli Code Signing` : ni nom, ni adresse, ni équipe), valide 10 ans ; sa clé privée est dans le trousseau de Djoko, jamais dans un dépôt. Seule la compilation de publication (`publier.sh`) signe avec lui ; elle le trouve par son nom dans le trousseau, au moment de publier. Le dépôt peut écrire ce nom ; jamais une empreinte ni un identifiant d'équipe. Djoko le crée une fois, et en garde un `.p12` protégé en lieu sûr, avec la clé Ed25519 ;
- les compilations de travail et les tests restent signés ad hoc ; pas de certificat Developer ID, pas de notarisation (elle est préparée, désactivée : section 7), jamais de `Local.xcconfig`, aucun identifiant d'équipe dans un fichier commité ;
- elles restent dans le bac à sable ;
```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
- **Le flux de versions** est un fichier `appcast.xml`, joint à chaque version publiée sur GitHub. L'app le lit à une adresse stable :
  `https://github.com/Djoko-cli/<dépôt>/releases/latest/download/appcast.xml`.
- **La clé publique Ed25519** (`SUPublicEDKey`) est inscrite dans l'`Info.plist` de chaque app. Les deux apps partagent une seule paire de clés. La clé privée est créée par l'outil de Sparkle (`generate_keys`), qui la range dans le trousseau de Djoko.
```

par :

```markdown
- **Le flux de versions** est un fichier `appcast.xml` du dépôt : `appcast.xml` à la racine de Maillage Thread, `apps/macos/appcast.xml` dans le pont Halo. L'app le lit à une adresse fixe, celle du fichier brut sur `main` :
  - `https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml` ;
  - `https://raw.githubusercontent.com/Djoko-cli/benq-screenbar-halo-matter/main/apps/macos/appcast.xml`.

  Il garde toutes les versions publiées, la plus récente en tête. Les `.dmg` restent dans les versions publiées sur GitHub : l'adresse de chacun, dans le flux, est celle de sa version publiée.
- **La clé publique Ed25519** (`SUPublicEDKey`) est inscrite dans l'`Info.plist` de chaque app. Les deux apps partagent une seule paire de clés. La clé privée est créée par l'outil de Sparkle (`generate_keys`), qui la range dans le trousseau de Djoko.
```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
- **L'installation par l'app :**
  - le démon est compilé dans le paquet de l'app (`Contents/Library/LaunchDaemons/` et son programme) ;
  - il s'installe par `SMAppService.daemon`, et Djoko l'approuve une fois dans Réglages Système ;
  - l'app propose « Installer Thread Route » et affiche son état : absent, à approuver, actif, installé par l'autre app ;
  - une mise à jour de l'app par Sparkle apporte la nouvelle version du démon.
- **Une seule installation pour les deux apps :** une app qui voit Thread Route déjà actif, installé par l'autre, ne l'installe pas à son tour. Le moyen de le voir depuis le bac à sable est à établir par l'essai ci-dessous.
- **Une seule source :** le code du démon vit dans le dépôt du pont Halo. Maillage Thread en garde une copie à l'identique, avec un script de synchronisation et un test qui vérifie que la copie correspond à sa source, à une révision notée.
- **L'essai d'abord.** Le plan commence par un essai jetable, qui répond à trois questions :
  1. `SMAppService.daemon` accepte-t-il un démon dans une app signée ad hoc et dans le bac à sable ?
  2. Une app peut-elle savoir, depuis le bac à sable, que le démon est déjà actif ?
  3. Le démon garde-t-il ses droits root et son comportement ?
  
  Si la réponse à la question 1 est non, Thread Route reste installé par `installer.sh`, renommé, et le README le dit. Djoko en est informé avant la suite.

```

par :

```markdown
- **L'installation par son installateur** (décision de Djoko du 06/10, après l'essai ci-dessous) :
  - `installer.sh`, renommé, compile et teste le démon, puis le pose avec le mot de passe administrateur ; c'est Djoko qui le lance ;
  - les deux apps affichent son état, lu auprès de macOS depuis le bac à sable (`SMAppService.statusForLegacyPlist`) : actif, désactivé dans Réglages Système, absent, ou `halo-routes` encore installé ; et la commande d'installation ;
  - une nouvelle version du démon s'installe en relançant `installer.sh` : la mise à jour d'une app ne le touche pas.
- **Une seule source :** le code du démon vit dans le dépôt du pont Halo. Maillage Thread en garde une copie à l'identique, avec un script de synchronisation et un test qui vérifie que la copie correspond à sa source, à une révision notée.
- **L'essai (06/10).** Un essai jetable a montré que, dans une app du bac à sable, macOS refuse tout de suite d'inscrire un démon qui n'y est pas (« SMAppService target executable must be sandboxed because the app is sandboxed »), que l'app soit signée ad hoc ou par un certificat auto-signé. Une app du bac à sable voit en revanche l'état d'un démon posé par un installateur. D'où le repli ci-dessus, que Djoko a validé.

```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
Un script par dépôt, `outils/publier.sh X.Y.Z`. Pour le pont Halo, il se trouve dans `apps/macos/outils/` ; le plan en fixe la place.

1. **Les vérifications :** `main` est propre et à jour avec GitHub, la version n'existe pas encore, les tests passent.
2. **Les numéros :**
```

par :

```markdown
Un script par dépôt, `outils/publier.sh X.Y.Z`. Pour le pont Halo, il se trouve dans `apps/macos/Outils/`.

1. **Les vérifications :** `main` est propre et à jour avec GitHub, l'étiquette de la version n'existe pas encore, ni la version dans le flux, les tests passent.
2. **Les numéros :**
```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
3. **La compilation** se fait en Release, avec la même signature ad hoc qu'aujourd'hui, Thread Route compris.
4. **Le `.dmg`,** créé par `hdiutil`, contient l'app et un raccourci vers Applications. Il s'appelle `Maillage-Thread-X.Y.Z.dmg` ou `Halo-Compagnon-X.Y.Z.dmg`.
5. **La signature :** `sign_update` de Sparkle signe le `.dmg` avec la clé du trousseau. Puis `appcast.xml` est produit, avec l'adresse du `.dmg` dans la version publiée, sa taille, sa signature, les deux numéros, la version minimale du système (macOS 26.0) et les notes de version.
6. **Le contrôle d'anonymisation** passe sur les notes, `appcast.xml` et les textes de l'app.
7. **La publication sur GitHub :** l'étiquette `vX.Y.Z`, puis `gh release create`, avec le `.dmg` et `appcast.xml`.
8. **La remise :** le `.dmg` est copié sur le Bureau.
```

par :

```markdown
3. **La compilation** se fait en Release. Puis l'app est signée par le certificat `Djoko-cli Code Signing`, son code imbriqué d'abord (Sparkle et ses services), avec le runtime renforcé ; `publier.sh` règle l'identité en un seul endroit, une variable. L'exigence de signature de l'app (`codesign -d -r-` : son identifiant et ce certificat) est alors la même d'une version à l'autre. Une étape de notarisation est écrite, désactivée par défaut (section 7).
4. **Le `.dmg`,** créé par `hdiutil`, contient l'app et un raccourci vers Applications. Il s'appelle `Maillage-Thread-X.Y.Z.dmg` ou `Halo-Compagnon-X.Y.Z.dmg`.
5. **La signature :** `sign_update` de Sparkle signe le `.dmg` avec la clé du trousseau. Puis la version entre en tête du flux du dépôt, avec l'adresse du `.dmg` dans sa version publiée, sa taille, sa signature, les deux numéros, la version minimale du système (macOS 26.0 pour Maillage Thread, 15.0 pour Halo Compagnon) et les notes de version ; les versions d'avant restent.
6. **Le contrôle d'anonymisation** passe sur les notes, le flux, le message du commit du flux et les textes de l'app.
7. **La publication sur GitHub :** l'étiquette de l'app (`maillage-vX.Y.Z` ou `compagnon-vX.Y.Z`), puis `gh release create`, avec le `.dmg`. Puis le flux est commité sur `main` (un `git add` de ce seul fichier, un message en français sans accents terminé par la ligne Co-Authored-By) et poussé aussitôt.
8. **La remise :** le `.dmg` est copié sur le Bureau.
```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
- un petit serveur HTTP local sert un faux flux et une fausse version 1.0.1, signée avec la vraie clé ;
- une app 1.0.0, compilée avec ce flux local, trouve la mise à jour, vérifie la signature, l'installe et redémarre en 1.0.1 ;
- un `.dmg` mal signé est refusé ;
- Thread Route installé par une app est vu par l'autre.

```

par :

```markdown
- un petit serveur HTTP local sert le flux comme le ferait l'adresse brute du dépôt, et les `.dmg` comme les versions publiées ; il sert une version 1.0.1, signée avec la vraie clé et le vrai certificat ;
- une app 1.0.0, compilée avec ce flux local, trouve la mise à jour, vérifie la signature, l'installe et redémarre en 1.0.1 ;
- un `.dmg` mal signé est refusé ;
- Thread Route, posé par son installateur, est vu par les deux apps.

```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
  - la production d'`appcast.xml` à partir de valeurs inventées ;
  - l'état de Thread Route, dans ses quatre cas ;
```

par :

```markdown
  - la signature du code, dans l'ordre, et la notarisation, qui ne s'exécute pas par défaut et s'arrête proprement si on l'active sans profil ;
  - la production d'`appcast.xml` à partir de valeurs inventées, l'ajout d'une version à un flux existant, les étiquettes propres à l'app ;
  - l'état de Thread Route, dans ses quatre cas ;
```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
  - l'installation de Thread Route et son approbation ;
  - la migration depuis `halo-routes` ;
```

par :

```markdown
  - l'installation de Thread Route par son installateur, et son état dans les deux apps ;
  - la migration depuis `halo-routes` ;
```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
- **Halo Compagnon** redemandera sans doute l'accès à sa clé du trousseau après une mise à jour, car la signature ad hoc change à chaque compilation.
- **Le passeur de Maillage Thread n'est pas distribué.** C'est une app « conçue pour iPad », que chacun signe avec sa propre équipe.
```

par :

```markdown
- **Halo Compagnon** redemandera sans doute l'accès à sa clé du trousseau au passage d'une compilation de travail, signée ad hoc, à une version publiée, signée par le certificat (et inversement). D'une version publiée à la suivante, l'exigence de signature ne change pas.
- **Le passeur de Maillage Thread n'est pas distribué.** C'est une app « conçue pour iPad », que chacun signe avec sa propre équipe.
```

Dans `docs/superpowers/specs/2026-10-06-deploiement-design.md`, remplacer :

```markdown
- **Une copie de l'app déjà téléchargée par quelqu'un d'autre** ne se met à jour qu'à partir de la première version qui contient Sparkle.

```

par :

```markdown
- **Une copie de l'app déjà téléchargée par quelqu'un d'autre** ne se met à jour qu'à partir de la première version qui contient Sparkle.

## 7. Distribution large

Préparée, pas activée. Seule l'étape de notarisation de `publier.sh` est écrite, désactivée par défaut (`NOTARISER=1` l'active, avec `PROFIL_NOTARISATION`, le profil que `notarytool store-credentials` range dans le trousseau : jamais d'identifiant Apple, de Team ID ni de mot de passe dans un fichier commité). Elle signe et soumet le `.dmg` (`xcrun notarytool submit --wait`), l'agrafe (`xcrun stapler staple`) et l'évalue (`spctl --assess`), avant la signature Ed25519.

Ce qu'une distribution au-delà du Mac de Djoko demande :
- **Une app non notarisée** doit être autorisée dans Réglages Système, Confidentialité et sécurité, « Ouvrir quand même », puis le mot de passe : depuis macOS 15, le clic droit ne suffit plus.
- **Ed25519 ne protège pas la première installation :** un compte GitHub volé suffirait à remplacer le `.dmg` qu'installent les nouveaux venus.
- **Thread Route sur d'autres Macs** dépend probablement d'une signature Apple.
- **Le passeur n'est pas distribuable.**
- **Les Macs Intel** demandent un binaire universel, ou d'annoncer Apple Silicon seulement. La compilation de publication est déjà universelle (`arm64` et `x86_64`), mais elle n'a jamais été essayée sur un Mac Intel.
- **La marche suivante** est le programme développeur d'Apple : Developer ID et notarisation. La transition est transparente par Sparkle, puisque la clé Ed25519 ne change pas.
- **À prévoir :** un déploiement progressif, un canal bêta, les mises à jour delta, la licence et les crédits de Sparkle, une mention de confidentialité (GitHub voit les adresses IP), et les tickets GitHub pour les signalements.

```

- [ ] **Step 7 : la même dans le pont, puis les deux commits.**

```bash
W=$S/deploiement-exec; cp "$W/maillage/docs/superpowers/specs/2026-10-06-deploiement-design.md" "$W/halo/docs/superpowers/specs/2026-10-06-deploiement-design.md" && for d in "$W/maillage" "$W/halo"; do cd "$d" && git add docs/superpowers/specs/2026-10-06-deploiement-design.md && git commit -q -F - <<'EOF'
Corriger la spec du deploiement : certificat auto-signe stable, flux dans le depot, etiquettes par app, Thread Route par son installateur, distribution large

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git log --oneline -1 --stat | tail -1; done; cmp "$W/maillage/docs/superpowers/specs/2026-10-06-deploiement-design.md" "$W/halo/docs/superpowers/specs/2026-10-06-deploiement-design.md" && echo "specs identiques"
```

Expected : deux fois `1 file changed, 43 insertions(+), 29 deletions(-)` ; `specs identiques`.

---
### Task 10: Toutes les suites, les images, et la répétition avec une paire et un certificat d'essai

**Files (privés) :**
- Create : `.superpowers/deploiement/repetition.sh`, `.superpowers/deploiement/trousseau-essai.py` (depuis `~/Dev/maillage-thread`) ; `$P/sparkle/` (téléchargé, compilé) ; `$P/cle-essai/` (par `openssl`) ; `$P/certificat-essai/` (par `trousseau-essai.py`, détruit au step 8)

**Interfaces:**
- Consumes : les deux branches `deploiement` au bout de la tâche 9 ; `publier.sh --repetition` (tâches 7 et 8).
- Produces : `sh repetition.sh <maillage> <halo> <sortie>`, avec `SPARKLE_BIN`, `SPARKLE_CLI`, `AUTRE_CLE`, `DD_MAILLAGE`, `DD_HALO` ; `CLE_PRIVEE` et `CLE_PUBLIQUE` pour une paire d'essai, `IDENTITE_SIGNATURE` et `TROUSSEAU` pour un certificat d'essai (sans eux : la clé et le certificat de Djoko, tâche 12) ; `/usr/bin/python3 trousseau-essai.py creer|detruire <dossier>`.

Aucun commit : cette tâche vérifie.

- [ ] **Step 1 : toutes les suites, en français et en anglais.** Maillage Thread : la commande de la tâche 4, step 7, puis celle en anglais (Global Constraints) ; Halo Compagnon : sa commande, puis en anglais. Puis :

```bash
P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec; cd "$W/maillage" && /usr/bin/python3 -m unittest discover -s outils/tests 2>&1 | tail -1; /usr/bin/python3 -m unittest discover -s sonde/test 2>&1 | tail -1; sh sonde/test/lancer.sh 2>&1 | grep verification; sh outils/thread-route/tests.sh > "$P/thread-route-m.txt" 2>&1; echo "code $?"; grep -E "verification\(s\)" "$P/thread-route-m.txt"; cd "$W/halo" && (cd apps/macos && /usr/bin/python3 -m unittest discover -s Outils/tests 2>&1 | tail -1); TMPDIR="$HOME/Library/Caches/deploiement-exec/" sh tools/test_halo1.sh 2>&1 | grep -E 'verification|ligne\(s\) machine' | cut -c1-70; /usr/bin/python3 tools/test_halo_udp.py 2>&1 | tail -1; sh tools/macos/thread-route/tests.sh > "$P/thread-route-h.txt" 2>&1; echo "code $?"; grep -E "verification\(s\)" "$P/thread-route-h.txt"; (cd apps/macos && /usr/bin/python3 Outils/generer_demo.py > /dev/null; echo "demo $?"); git status --short | wc -l
```

Expected :
- Maillage Thread, en français comme en anglais : `Test run with 420 tests in 42 suites passed` et `Test run with 398 tests in 34 suites passed` ; Halo Compagnon : `Test run with 144 tests in 20 suites passed` et `Test run with 41 tests in 9 suites passed` ; `** TEST SUCCEEDED **` chaque fois, sans avertissement ;
- Maillage Thread : `OK` (37 tests), `OK` (141), `test_h1 : 121 verification(s), 0 echec(s)` et `test_distant : 145 verification(s), 0 echec(s)`, `code 0`, `thread-route : 47 verification(s), 0 echec(s)` et `installation : 4 verification(s), 0 echec(s)` ; pont Halo : `OK` (34), `2232508 verification(s), 0 echec(s)`, `301 verification(s) JSON, 0 echec(s)`, `test_h1 : 121 verification(s), 0 echec(s)` et deux lignes `… ligne(s) machine, 0 erreur(s), 0 avertissement(s)`, `OK` (8), `code 0` et les deux lignes de Thread Route, `demo 0`, `0` (la démo régénérée est identique).

- [ ] **Step 2 : les images de démo, identiques à celles de la base** (tâche 4, step 1), rendues avec l'app de la suite du step 1 (la dernière compilée en Debug dans `$DDM`).

```bash
B="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-deploiement-base"; D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-deploiement-fin"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D" | wc -l
pgrep -f "[d]eploiement-exec-maillage/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitte"
for f in $(ls "$B"); do cmp -s "$D/$f" "$B/$f" && echo "$f identique" || echo "$f differe"; done | awk '{print $2}' | sort | uniq -c
```

Expected : `21` ; `l'app a quitte` ; `21 identique`. La spec n'impose aucune image nouvelle : en démo, le moteur de mise à jour ne démarre pas, et les Réglages ne sont pas dans les images.

- [ ] **Step 3 : les outils de Sparkle 2.10.0** (téléchargements autorisés par Djoko le 06/10) : l'archive, et `sparkle-cli` compilé depuis la source de la même version, signé ad hoc.

```bash
P=$HOME/Dev/maillage-thread/.superpowers/deploiement; mkdir -p "$P/sparkle" && cd "$P/sparkle" && curl -sSL -o Sparkle-2.10.0.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.10.0/Sparkle-2.10.0.tar.xz && curl -sSL -o Sparkle-2.10.0-source.tar.gz https://github.com/sparkle-project/Sparkle/archive/refs/tags/2.10.0.tar.gz && shasum -a 256 Sparkle-2.10.0.tar.xz Sparkle-2.10.0-source.tar.gz && tar -xJf Sparkle-2.10.0.tar.xz && tar -xzf Sparkle-2.10.0-source.tar.gz && (cd Sparkle-2.10.0 && xcodebuild -project Sparkle.xcodeproj -scheme sparkle-cli -configuration Release -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-sparkle" CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= CODE_SIGN_STYLE=Manual build > ../sparkle-cli.log 2>&1; echo "sparkle-cli $?") && cp -R "$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-sparkle/Build/Products/Release/sparkle.app" . && ls bin && ./sparkle.app/Contents/MacOS/sparkle 2>&1 | sed -n 2p | cut -c1-60
```

Expected : les deux empreintes des Global Constraints ; `sparkle-cli 0` ; `BinaryDelta generate_appcast generate_keys old_dsa_scripts sign_update` ; `Usage: …/sparkle bundle [--application app-path]…`.

- [ ] **Step 4 : la paire d'essai, et l'autre clé,** dans des fichiers, jamais dans le trousseau.

```bash
P=$HOME/Dev/maillage-thread/.superpowers/deploiement; mkdir -p "$P/cle-essai" && cd "$P/cle-essai" && for n in essai autre; do openssl genpkey -algorithm ed25519 -out $n.pem && openssl pkey -in $n.pem -outform DER | tail -c 32 | base64 > $n-privee.txt && openssl pkey -in $n.pem -pubout -outform DER | tail -c 32 | base64 > $n-publique.txt; done; chmod 600 ./*.pem ./*-privee.txt; head -c 5000 /dev/urandom > essai.bin && SIG=$("$P/sparkle/bin/sign_update" --ed-key-file essai-privee.txt -p essai.bin) && echo "$SIG" | base64 -d > essai.sig && openssl pkey -in essai.pem -pubout -out essai-pub.pem && openssl pkeyutl -verify -pubin -inkey essai-pub.pem -rawin -in essai.bin -sigfile essai.sig
```

Expected : `Signature Verified Successfully` : `sign_update` lit la clé du fichier, et sa signature se vérifie avec la clé publique du fichier.

- [ ] **Step 5 : les scripts de la répétition et du trousseau d'essai** (`--etapes 5`, depuis `~/Dev/maillage-thread`), puis le certificat d'essai, dans un trousseau à part.

`.superpowers/deploiement/repetition.sh` :

```sh
#!/bin/sh
# Repetition de la mise a jour, sans GitHub (spec du deploiement, section 4). Pour chaque app : une copie 1.0.0 et
# une version 1.0.1, compilees par publier.sh --repetition ; chaque publication ajoute sa version au flux du depot
# (commite dans le clone). Un serveur local (127.0.0.1) sert ce flux comme le ferait l'adresse brute du depot
# (/<depot>/main/<chemin>) et les .dmg comme les versions publiees (/<depot>/releases/download/<etiquette>/) ;
# sparkle-cli met a jour la copie 1.0.0, comme le ferait l'app. Trois cas, dans l'ordre :
#   - le flux d'apres la 1.0.0, qui ne propose rien de plus recent : rien ne change (code 4) ;
#   - le flux d'apres la 1.0.1, sa signature remplacee par celle d'une autre cle : refuse (erreur 4005) ;
#   - le flux d'apres la 1.0.1 (les deux versions, la 1.0.1 en tete) : la copie passe en 1.0.1, sa signature reste valide, avec la meme exigence de signature
#     (codesign -d -r-) qu'en 1.0.0, et que celle des deux compilations.
#   sh repetition.sh <copie Maillage Thread> <copie pont Halo> <dossier de sortie, neuf>
# Les copies : des depots git propres, a la revision a publier (elles sont clonees, jamais modifiees).
# SPARKLE_BIN : bin de l'archive de Sparkle 2.10.0 ; SPARKLE_CLI : sparkle-cli, compile depuis sa source.
# CLE_PRIVEE et CLE_PUBLIQUE : une paire d'essai, en fichier et en clair ; sans elles, la cle du trousseau.
# AUTRE_CLE : une autre cle privee d'essai (fichier), pour le .dmg mal signe. PORT : 8765 par defaut.
# IDENTITE_SIGNATURE et TROUSSEAU : un certificat d'essai dans un trousseau a part ; sans eux, le certificat de
# Djoko (Djoko-cli Code Signing), dans son trousseau.
# DD_MAILLAGE et DD_HALO : les dossiers de produits. Rien n'est publie ; aucun fichier hors de <dossier>, sauf les
# preferences que sparkle-cli ecrit hors du conteneur des apps (SULastCheckTime, ~/Library/Preferences).
set -eu
M=$(cd "$1" && pwd); H=$(cd "$2" && pwd); R=$3
PORT=${PORT:-8765}
mkdir "$R"
R=$(cd "$R" && pwd)
: "${SPARKLE_BIN:?}" "${SPARKLE_CLI:?}" "${AUTRE_CLE:?}" "${DD_MAILLAGE:?}" "${DD_HALO:?}"
CLES=""
if [ -n "${CLE_PRIVEE:-}" ]; then CLES="--cle-privee $CLE_PRIVEE --cle-publique $CLE_PUBLIQUE"; fi
if [ -n "${TROUSSEAU:-}" ]; then CLES="$CLES --trousseau $TROUSSEAU"; fi
mkdir -p "$R/serveur" "$R/installe" "$R/montage"
/usr/bin/python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$R/serveur" > "$R/serveur.log" 2>&1 &
SERVEUR=$!
trap 'kill $SERVEUR 2>/dev/null || true' EXIT
BILAN=0

# Une app : $1 nom court, $2 depot, $3 dossier de l'app dans le depot, $4 publier.sh (relatif), $5 nom de l'app,
# $6 nom du .dmg sans version, $7 dossier de produits, $8 depot GitHub, $9 debut de l'etiquette.
repeter() {
  court=$1; depot=$2; sous=$3; publier=$4; nom=$5; fichier=$6; dd=$7; github=$8; etiquette=$9
  flux=$sous/appcast.xml
  [ "$sous" = . ] && flux=appcast.xml
  git clone -q "$depot" "$R/$court"
  # L'auteur du commit du flux : celui du depot d'origine (Djoko-cli, adresse noreply), comme pour la publication.
  git -C "$R/$court" config user.name "$(git -C "$depot" config user.name)"
  git -C "$R/$court" config user.email "$(git -C "$depot" config user.email)"
  for v in 1.0.0 1.0.1; do
    if [ "$v" = 1.0.1 ]; then
      (cd "$R/$court/$sous" &&
        sed -i '' 's/        MARKETING_VERSION: "1.0.0"/        MARKETING_VERSION: "1.0.1"/' project.yml &&
        /usr/bin/python3 -c "import sys; p='NOTES-VERSIONS.md'; s=open(p, encoding='utf-8').read(); open(p, 'w', encoding='utf-8').write(s.replace('## 1.0.0\n', '## 1.0.1\n\n**Français**\n\n- Version de répétition, jamais publiée.\n\n**English**\n\n- Rehearsal version, never published.\n\n## 1.0.0\n', 1))" &&
        git -c user.name=Repetition -c user.email=repetition@example.invalid commit -q -am "Repetition : 1.0.1")
    fi
    # shellcheck disable=SC2086
    (cd "$R/$court/$sous" && DD="$dd" "$publier" "$v" --repetition "$R/sortie-$court-$v" \
      --url-base "http://127.0.0.1:$PORT" $CLES --sans-tests > "$R/publier-$court-$v.txt" 2>&1)
    mkdir -p "$R/serveur/$github/releases/download/$etiquette$v"
    cp "$R/sortie-$court-$v/$fichier-$v.dmg" "$R/serveur/$github/releases/download/$etiquette$v/"
    # Le flux du depot apres cette publication (commite dans le clone).
    cp "$R/$court/$flux" "$R/flux-$court-$v.xml"
    echo "$court $v : $(git -C "$R/$court" log -1 --format=%s) ; $(grep -c '<item>' "$R/flux-$court-$v.xml") version(s) dans le flux"
  done
  mkdir -p "$R/serveur/$github/main/$(dirname "$flux")"
  hdiutil attach -quiet -nobrowse -readonly -mountpoint "$R/montage" "$R/sortie-$court-1.0.0/$fichier-1.0.0.dmg"
  ditto "$R/montage/$nom.app" "$R/installe/$nom.app"
  hdiutil detach -quiet "$R/montage"
  app="$R/installe/$nom.app"
  exigence=$(codesign -d -r- "$app" 2>/dev/null)
  if cmp -s "$R/sortie-$court-1.0.0/exigence.txt" "$R/sortie-$court-1.0.1/exigence.txt"; then
    echo "$court : exigence de signature identique en 1.0.0 et 1.0.1 : $(cut -c1-60 "$R/sortie-$court-1.0.0/exigence.txt")…"
  else
    echo "$court : exigences de signature differentes"; BILAN=1
  fi
  bon=$(grep -o 'edSignature="[^"]*"' "$R/flux-$court-1.0.1.xml" | head -n 1 | cut -d'"' -f2)
  mauvais=$("$SPARKLE_BIN/sign_update" --ed-key-file "$AUTRE_CLE" -p "$R/sortie-$court-1.0.1/$fichier-1.0.1.dmg")
  sed "s|$bon|$mauvais|" "$R/flux-$court-1.0.1.xml" > "$R/flux-$court-mal-signe.xml"
  servi="$R/serveur/$github/main/$flux"
  for cas in rien mal-signe bon; do
    case $cas in
      rien) cp "$R/flux-$court-1.0.0.xml" "$servi"; attendu=1.0.0;;
      mal-signe) cp "$R/flux-$court-mal-signe.xml" "$servi"; attendu=1.0.0;;
      bon) cp "$R/flux-$court-1.0.1.xml" "$servi"; attendu=1.0.1;;
    esac
    code=0
    "$SPARKLE_CLI" "$app" --check-immediately --verbose --user-agent-name repetition > "$R/cli-$court-$cas.txt" 2>&1 || code=$?
    lu=$(plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
    numero=$(plutil -extract CFBundleVersion raw "$app/Contents/Info.plist")
    dit=$(grep -v -e Extracting -e Downloaded "$R/cli-$court-$cas.txt" | tail -n 1 | cut -c1-90)
    echo "$court $cas : code $code ; $dit ; version $lu ($numero)"
    [ "$lu" = "$attendu" ] || BILAN=1
  done
  codesign --verify --deep --strict "$app" && echo "$court : signature valide apres la mise a jour ($(codesign -dvv "$app" 2>&1 | grep -m1 '^Authority=' || echo ad hoc))" || BILAN=1
  if [ "$(codesign -d -r- "$app" 2>/dev/null)" = "$exigence" ]; then
    echo "$court : meme exigence de signature avant et apres la mise a jour"
  else
    echo "$court : exigence changee par la mise a jour"; BILAN=1
  fi
}

repeter maillage "$M" . outils/publier.sh "Maillage Thread" Maillage-Thread "$DD_MAILLAGE" Djoko-cli/maillage-thread maillage-v
repeter halo "$H" apps/macos Outils/publier.sh "Halo Compagnon" Halo-Compagnon "$DD_HALO" \
  Djoko-cli/benq-screenbar-halo-matter compagnon-v
[ "$BILAN" -eq 0 ] && echo "repetition reussie" || { echo "repetition en echec"; exit 1; }
```

`.superpowers/deploiement/trousseau-essai.py` :

```python
#!/usr/bin/env python3
"""Un certificat de signature d'essai, auto-signe, dans un trousseau a part, pour la repetition : jamais le
trousseau de la session.
  /usr/bin/python3 trousseau-essai.py creer DOSSIER     DOSSIER/essai.keychain-db, « Djoko-cli Code Signing (essai) »
  /usr/bin/python3 trousseau-essai.py detruire DOSSIER
`security create-keychain` ajoute le trousseau a la liste de recherche de la session : le script la remet aussitot
telle qu'elle etait (ses chemins ont des espaces : jamais par le shell) et verifie qu'elle n'a pas change. Le mot de
passe de ce trousseau jetable est « essai ».
"""
import os
import re
import subprocess
import sys

NOM = 'Djoko-cli Code Signing (essai)'
MOT = 'essai'


def liste():
    sortie = subprocess.run(['security', 'list-keychains', '-d', 'user'], check=True, capture_output=True,
                            text=True).stdout
    return [re.match(r'\s*"(.*)"\s*$', l).group(1) for l in sortie.splitlines() if l.strip()]


def lancer(*cmd):
    subprocess.run(list(cmd), check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL if cmd[0] == 'openssl' else None)


def creer(dossier):
    os.makedirs(dossier, exist_ok=True)
    tr = os.path.join(dossier, 'essai.keychain-db')
    cle, cert, p12 = (os.path.join(dossier, n) for n in ('cle.pem', 'cert.pem', 'essai.p12'))
    lancer('openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-keyout', cle, '-out', cert, '-days', '3650', '-nodes',
           '-subj', '/CN=' + NOM, '-addext', 'keyUsage=critical,digitalSignature',
           '-addext', 'extendedKeyUsage=critical,codeSigning', '-addext', 'basicConstraints=critical,CA:false')
    lancer('openssl', 'pkcs12', '-export', '-legacy', '-inkey', cle, '-in', cert, '-out', p12, '-passout',
           'pass:' + MOT, '-name', NOM)
    os.chmod(cle, 0o600)
    os.chmod(p12, 0o600)
    avant = liste()
    try:
        lancer('security', 'create-keychain', '-p', MOT, tr)
    finally:
        lancer('security', 'list-keychains', '-d', 'user', '-s', *avant)
    assert liste() == avant, 'liste de recherche changee'
    lancer('security', 'unlock-keychain', '-p', MOT, tr)
    lancer('security', 'set-keychain-settings', tr)
    lancer('security', 'import', p12, '-k', tr, '-P', MOT, '-T', '/usr/bin/codesign')
    lancer('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', MOT, tr)
    identites = subprocess.run(['security', 'find-identity', '-p', 'codesigning', tr], check=True,
                               capture_output=True, text=True).stdout
    assert '"%s"' % NOM in identites, identites
    assert liste() == avant, 'liste de recherche changee'
    print('trousseau : %s ; identite : %s ; liste de recherche inchangee' % (tr, NOM))


def detruire(dossier):
    tr = os.path.join(dossier, 'essai.keychain-db')
    avant = liste()
    lancer('security', 'delete-keychain', tr)
    apres = liste()
    assert apres == [c for c in avant if c != tr], 'liste de recherche changee'
    print('trousseau detruit : %s ; liste de recherche inchangee' % tr)


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('creer', 'detruire'):
        sys.exit(__doc__)
    {'creer': creer, 'detruire': detruire}[sys.argv[1]](sys.argv[2])
```

Run : `P=$HOME/Dev/maillage-thread/.superpowers/deploiement; /usr/bin/python3 "$P/trousseau-essai.py" creer "$P/certificat-essai"`

Expected : `trousseau : …/certificat-essai/essai.keychain-db ; identite : Djoko-cli Code Signing (essai) ; liste de recherche inchangee`.

- [ ] **Step 6 : la répétition avec la paire et le certificat d'essai** (spec, section 4), en tâche de fond (une quinzaine de minutes : quatre compilations Release).

```bash
P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec; IDENTITE_SIGNATURE="Djoko-cli Code Signing (essai)" TROUSSEAU="$P/certificat-essai/essai.keychain-db" SPARKLE_BIN="$P/sparkle/bin" SPARKLE_CLI="$P/sparkle/sparkle.app/Contents/MacOS/sparkle" CLE_PRIVEE="$P/cle-essai/essai-privee.txt" CLE_PUBLIQUE="$(cat "$P/cle-essai/essai-publique.txt")" AUTRE_CLE="$P/cle-essai/autre-privee.txt" DD_MAILLAGE="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" DD_HALO="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-halo" sh "$P/repetition.sh" "$W/maillage" "$W/halo" "$W/repetition-essai" > "$W/repetition-essai.txt" 2>&1; echo "code $?" >> "$W/repetition-essai.txt"; cat "$W/repetition-essai.txt"
```

Expected (les numéros de compilation : le nombre de commits de chaque branche, puis un de plus) :

```text
maillage 1.0.0 : Publier Maillage Thread 1.0.0 dans le flux des mises a jour ; 1 version(s) dans le flux
maillage 1.0.1 : Publier Maillage Thread 1.0.1 dans le flux des mises a jour ; 2 version(s) dans le flux
maillage : exigence de signature identique en 1.0.0 et 1.0.1 : designated => identifier "fr.djoko.maillage" and certificate…
maillage rien : code 4 ; No new update available! ; version 1.0.0 (428)
maillage mal-signe : code 1 ; Error: Update has failed due to error 4005 (SUSparkleErrorDomain). The update is improperl ; version 1.0.0 (428)
maillage bon : code 0 ; Exiting. ; version 1.0.1 (430)
maillage : signature valide apres la mise a jour (Authority=Djoko-cli Code Signing (essai))
maillage : meme exigence de signature avant et apres la mise a jour
halo 1.0.0 : Publier Halo Compagnon 1.0.0 dans le flux des mises a jour ; 1 version(s) dans le flux
halo 1.0.1 : Publier Halo Compagnon 1.0.1 dans le flux des mises a jour ; 2 version(s) dans le flux
halo : exigence de signature identique en 1.0.0 et 1.0.1 : designated => identifier "fr.djoko.halo.compagnon" and certi…
halo rien : code 4 ; No new update available! ; version 1.0.0 (153)
halo mal-signe : code 1 ; Error: Update has failed due to error 4005 (SUSparkleErrorDomain). The update is improperl ; version 1.0.0 (153)
halo bon : code 0 ; Exiting. ; version 1.0.1 (155)
halo : signature valide apres la mise a jour (Authority=Djoko-cli Code Signing (essai))
halo : meme exigence de signature avant et apres la mise a jour
repetition reussie
code 0
```

Chaque `publier-*.txt` du dossier dit aussi `exigence de signature : designated => identifier "…" and certificate leaf = H"…"` et `controle d'anonymisation : trouve : aucun`.

- [ ] **Step 7 : ranger.** `sparkle-cli` a écrit `SULastCheckTime` hors du conteneur des apps ; ces deux fichiers n'existaient pas avant la répétition (sinon, les laisser).

```bash
for f in fr.djoko.maillage fr.djoko.halo.compagnon; do plutil -p ~/Library/Preferences/$f.plist; done; mkdir -p ~/.Trash/deploiement-preferences && mv ~/Library/Preferences/fr.djoko.maillage.plist ~/Library/Preferences/fr.djoko.halo.compagnon.plist ~/.Trash/deploiement-preferences/; W=$S/deploiement-exec; LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister; for a in "$W"/repetition-essai/installe/*.app; do "$LSR" -u "$a"; done; lsof -nP -iTCP:8765 -sTCP:LISTEN 2>/dev/null | grep -c Python
```

Expected : chaque fichier ne porte que `"SULastCheckTime" => …` ; `0` (le serveur est arrêté).

- [ ] **Step 8 : détruire le trousseau d'essai.**

Run : `P=$HOME/Dev/maillage-thread/.superpowers/deploiement; /usr/bin/python3 "$P/trousseau-essai.py" detruire "$P/certificat-essai"`

Expected : `trousseau detruit : … ; liste de recherche inchangee`.

---

### Task 11: La vraie clé et le certificat, dans le trousseau de Djoko (avec Djoko)

**Files :**
- Modify : `project.yml` (Maillage Thread), `apps/macos/project.yml` (pont Halo) : `CLE_MISES_A_JOUR`

**Interfaces:**
- Consumes : la clé provisoire des tâches 5 et 6.
- Produces : la clé publique Ed25519 de Djoko dans les deux apps ; sa clé privée dans son trousseau (compte `ed25519`), où la lisent `sign_update` et `publier.sh` ; le certificat `Djoko-cli Code Signing` et sa clé privée dans son trousseau, où `publier.sh` le trouve par son nom ; une copie `.p12` protégée et une copie de la clé Ed25519, que Djoko range en lieu sûr.

- [ ] **Step 1 (avec Djoko, accord) : créer la clé.** Le geste : `generate_keys` crée la paire de clés de Sparkle et range la clé privée dans le trousseau de Djoko ; macOS peut lui demander d'autoriser l'accès. Une seule paire sert aux deux apps (spec). La clé privée ne quitte jamais le trousseau ; Djoko peut, s'il le veut, en garder une copie à lui (`generate_keys -x <fichier>`, à mettre en lieu sûr) : sans elle, perdue, plus aucune mise à jour ne serait acceptée par les copies installées.

```bash
P=$HOME/Dev/maillage-thread/.superpowers/deploiement; "$P/sparkle/bin/generate_keys" | tail -4; "$P/sparkle/bin/generate_keys" -p
```

Expected : la clé publique, 44 caractères en base64, finissant par `=` (la même deux fois).

- [ ] **Step 1 bis (avec Djoko, accord) : créer le certificat.** Le geste : Djoko crée lui-même, dans Trousseaux d'accès, Assistant de certification, « Créer un certificat… » : nom `Djoko-cli Code Signing` ; type d'identité « Racine auto-signée » ; type de certificat « Signature de code » ; « Me laisser modifier les valeurs par défaut » coché, période de validité 3650 jours ; aucune adresse, aucun nom de personne ni d'organisation ; rangé dans le trousseau « session ». Puis il l'exporte (clic droit, « Exporter… », format `.p12`, avec un mot de passe) et le range en lieu sûr, avec une copie de la clé Ed25519 (`"$P/sparkle/bin/generate_keys" -x <fichier>`). Ni le `.p12` ni la clé ne vont dans un dépôt.

Run : `security find-identity -p codesigning | grep -c '"Djoko-cli Code Signing"'`

Expected : `1` (suivi de `CSSMERR_TP_NOT_TRUSTED` : un certificat auto-signé n'est pas approuvé, et `codesign` le prend quand même). Au premier `codesign` avec ce certificat (tâche 12), macOS demande à Djoko l'accès à sa clé : « Toujours autoriser ».

- [ ] **Step 2 : l'inscrire dans les deux apps.**

```bash
P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec; CLE=$("$P/sparkle/bin/generate_keys" -p) && echo "$CLE" | grep -Eq '^[A-Za-z0-9+/]{43}=$' && for f in "$W/maillage/project.yml" "$W/halo/apps/macos/project.yml"; do sed -i '' "s|        CLE_MISES_A_JOUR: lkPxEHj5erw+omLlr1AVsIoyhfz4YnoLa/N9147SNgc=|        CLE_MISES_A_JOUR: $CLE|" "$f"; grep -c "CLE_MISES_A_JOUR: $CLE" "$f"; done
```

Expected : `1` et `1`.

- [ ] **Step 3 : les tests de Sparkle.** `MisesAJourTests` de chaque app (la commande de la tâche 5, step 1 ; celle de la tâche 6, step 1).

Expected : `Test run with 3 tests in 1 suite passed`, deux fois.

- [ ] **Step 4 : commits.**

```bash
W=$S/deploiement-exec; for d in "$W/maillage" "$W/halo"; do cd "$d" && f=$(git diff --name-only) && git add $f && git commit -q -F - <<'EOF'
Inscrire la cle publique Ed25519 des mises a jour, celle du trousseau de Djoko

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git log --oneline -1 --stat | tail -2; done
```

Expected : `project.yml | 2 +-` puis `apps/macos/project.yml | 2 +-`.

---

### Task 12: La répétition avec la vraie clé et le vrai certificat (avec Djoko)

**Interfaces:**
- Consumes : `repetition.sh` (tâche 10), la vraie clé (tâche 11).
- Produces : la preuve, avant toute version publiée, que la vraie clé et le vrai certificat signent des mises à jour que les apps acceptent, à exigence de signature constante (spec, section 4) ; les copies 1.0.0 de la répétition, gardées pour la tâche 17.

- [ ] **Step 1 (avec Djoko, accord) : répéter avec la clé et le certificat du trousseau.** Le geste : quatre compilations Release avec un flux local, signées par `codesign` avec le certificat `Djoko-cli Code Signing`, quatre `.dmg` signés par `sign_update` avec la clé Ed25519 (macOS demande à Djoko d'autoriser `codesign` et `sign_update` : « Toujours autoriser »), puis `sparkle-cli` sur les copies 1.0.0. Rien n'est publié.

```bash
P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec; SPARKLE_BIN="$P/sparkle/bin" SPARKLE_CLI="$P/sparkle/sparkle.app/Contents/MacOS/sparkle" AUTRE_CLE="$P/cle-essai/autre-privee.txt" DD_MAILLAGE="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" DD_HALO="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-halo" sh "$P/repetition.sh" "$W/maillage" "$W/halo" "$W/repetition" > "$W/repetition.txt" 2>&1; echo "code $?" >> "$W/repetition.txt"; cat "$W/repetition.txt"
```

Expected : les mêmes lignes qu'à la tâche 10, step 6, un commit plus loin (la clé), avec `Authority=Djoko-cli Code Signing`, puis `repetition reussie` et `code 0`. Si `security find-identity`, `codesign`, `generate_keys -p` ou `sign_update` échoue (accès refusé), s'arrêter et le dire à Djoko.

- [ ] **Step 2 : ranger,** comme à la tâche 10, step 7, sans désinscrire les copies de `$W/repetition/installe/` : la tâche 17 s'en sert.

---

### Task 13: La migration de halo-routes vers Thread Route (avec Djoko)

**Interfaces:**
- Consumes : `tools/macos/thread-route/installer.sh` (tâche 2), dans `$W/halo`.
- Produces : Thread Route installé et actif ; `halo-routes` retiré (son journal gardé).

- [ ] **Step 1 : ce que l'installation fera.**

Run : `W=$S/deploiement-exec; sh "$W/halo/tools/macos/thread-route/installer.sh" --plan`

Expected : `launchctl bootout system/fr.djoko.halo.routes`, `rm -f /Library/PrivilegedHelperTools/fr.djoko.halo.routes /Library/LaunchDaemons/fr.djoko.halo.routes.plist`, puis les cinq lignes de Thread Route (`bootout`, `install -d`, deux `install`, `bootstrap`).

- [ ] **Step 2 (avec Djoko, accord) : migrer.** Le geste : Djoko lance lui-même, dans son Terminal, `sh <chemin de $W/halo>/tools/macos/thread-route/installer.sh`, et tape son mot de passe administrateur (l'agent n'utilise jamais `sudo`). L'installateur compile, teste, montre l'essai, puis retire `halo-routes` avant de poser Thread Route.

- [ ] **Step 3 : vérifier.**

```bash
launchctl print system/fr.djoko.thread.route 2>&1 | grep -E "^\s+state = "; launchctl print system/fr.djoko.halo.routes 2>&1 | tail -1; ls /Library/LaunchDaemons /Library/PrivilegedHelperTools | grep -c "fr.djoko.halo.routes"; grep -c "thread-route : demarre" /Library/Logs/fr.djoko.thread.route.log; sfltool dumpbtm 2>/dev/null | grep -A3 "Name: fr.djoko.thread.route" | grep Disposition
```

Expected : `state = running` ; `Could not find service "fr.djoko.halo.routes" in domain for system` ; `0` ; `1` (ou plus) ; `Disposition: [enabled, allowed, …]`. Le contenu du journal porte les préfixes du réseau : on n'en montre que des comptes.

---

### Task 14: La fusion et le push (avec Djoko)

**Files :**
- Create : `docs/superpowers/plans/2026-10-06-deploiement.md` (Maillage Thread, ce plan, tel quel)

**Interfaces:**
- Consumes : les deux branches `deploiement` (tâches 2 à 11).
- Produces : `main` à jour dans les deux dépôts de travail et sur GitHub.

- [ ] **Step 1 : le plan, sur la branche.**

```bash
W=$S/deploiement-exec; cd "$W/maillage" && git show deploiement-brouillon:docs/superpowers/plans/2026-10-06-deploiement.md > docs/superpowers/plans/2026-10-06-deploiement.md && git add docs/superpowers/plans/2026-10-06-deploiement.md && git commit -q -F - <<'EOF'
Ecrire le plan du deploiement : Sparkle 2, publier.sh, Thread Route, repetition, etapes avec Djoko

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git log --oneline main..deploiement | wc -l
```

Expected : `7` (les tâches 4, 5 et 7, les deux commits de la tâche 9, la tâche 11, et le plan).

- [ ] **Step 2 (avec Djoko, accord) : fusionner dans les dépôts de travail.** Le geste : `main` avance d'un coup (`--ff-only`) sur `deploiement`, dans `~/Dev/maillage-thread` et dans `~/Documents/Dev/esp32/benq`.

```bash
git -C ~/Dev/maillage-thread status --short | wc -l; git -C ~/Dev/maillage-thread merge -q --ff-only deploiement && git -C ~/Dev/maillage-thread log --oneline -1; git -C ~/Documents/Dev/esp32/benq status --short | wc -l; git -C ~/Documents/Dev/esp32/benq merge -q --ff-only deploiement && git -C ~/Documents/Dev/esp32/benq log --oneline -1; sleep 5; git -C ~/Documents/Dev/esp32/benq status --short | wc -l
```

Expected : `0`, le commit du plan ; `0`, le commit de la clé ; `0` après quelques secondes (le dépôt du pont est sous iCloud : relire `git status` après une fusion ; un fichier rendu par iCloud se restaure par `git checkout -- <fichier>`).

- [ ] **Step 3 (avec Djoko, accord) : pousser.** Le geste : `git push origin main`, dans chaque dépôt.

```bash
git -C ~/Dev/maillage-thread push -q origin main && git -C ~/Dev/maillage-thread status -sb | head -1; git -C ~/Documents/Dev/esp32/benq push -q origin main && git -C ~/Documents/Dev/esp32/benq status -sb | head -1
```

Expected : `## main...origin/main`, deux fois, sans `ahead`.

---

### Task 15: Les deux publications sur GitHub (avec Djoko)

**Interfaces:**
- Consumes : `main` sur GitHub (tâche 14), la vraie clé (tâche 11).
- Produces : les versions publiées `maillage-v1.0.0` de `Djoko-cli/maillage-thread` et `compagnon-v1.0.0` de `Djoko-cli/benq-screenbar-halo-matter`, chacune avec son `.dmg` ; les flux `appcast.xml` et `apps/macos/appcast.xml`, commités sur `main` et poussés ; les dépôts de travail à jour.

Les publications se font depuis des clones neufs de GitHub, hors d'iCloud et sans `Local.xcconfig` (précision 6). Le commit du flux est fait à la demande de Djoko : `publier.sh` le pousse aussitôt, après le contrôle d'anonymisation des fichiers et du message ; son auteur est celui des dépôts de travail (Djoko-cli, adresse noreply), posé dans chaque clone au step 1.

- [ ] **Step 1 : les clones.**

```bash
W=$S/deploiement-exec; git clone -q https://github.com/Djoko-cli/maillage-thread "$W/publication-maillage" && git clone -q https://github.com/Djoko-cli/benq-screenbar-halo-matter "$W/publication-halo" && for c in maillage:$HOME/Dev/maillage-thread halo:$HOME/Documents/Dev/esp32/benq; do n=${c%%:*}; d=${c#*:}; git -C "$W/publication-$n" config user.name "$(git -C "$d" config user.name)"; git -C "$W/publication-$n" config user.email "$(git -C "$d" config user.email)"; git -C "$W/publication-$n" config user.email | grep -c "@users.noreply.github.com$"; git -C "$W/publication-$n" log --oneline -1; done
```

Expected : pour chaque clone, `1` (l'adresse noreply) et la tête de `main` de la tâche 14.

- [ ] **Step 2 (avec Djoko, accord) : publier Maillage Thread 1.0.0.** Le geste : `publier.sh` vérifie, lance tous les tests (une vingtaine de minutes), compile, signe le `.dmg` avec la clé du trousseau, ajoute la version au flux, passe le contrôle d'anonymisation (fichiers et message), pose et pousse l'étiquette `maillage-v1.0.0`, crée la version publiée avec le `.dmg`, puis commite le flux `appcast.xml` sur `main` et le pousse aussitôt. En tâche de fond.

```bash
P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec; cd "$W/publication-maillage" && SPARKLE_BIN="$P/sparkle/bin" DD="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-maillage" outils/publier.sh 1.0.0 --sans-bureau > "$W/publication-maillage.txt" 2>&1; echo "code $?" >> "$W/publication-maillage.txt"; grep -v "^tests " "$W/publication-maillage.txt"
```

Expected : `version 1.0.0, numero de compilation <commits de main>, macOS 26.0 minimum` ; `exigence de signature : designated => identifier "fr.djoko.maillage" and certificate leaf = H"…"` ; `signe : …/Maillage-Thread-1.0.0.dmg (… octets)` ; `controle d'anonymisation : trouve : aucun ; faux positifs connus : …` ; `publie : https://github.com/Djoko-cli/maillage-thread/releases/tag/maillage-v1.0.0` ; `flux commite et pousse sur main : https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml` ; `code 0`. Un `refus : …` n'a rien publié : le lire, corriger, recommencer. Un échec après `publie :` (le push du flux) laisse la version publiée sans flux : pousser le commit du flux à la main (`git -C "$W/publication-maillage" push origin main`), avec l'accord de Djoko.

- [ ] **Step 3 (avec Djoko, accord) : publier Halo Compagnon 1.0.0,** le même geste : l'étiquette `compagnon-v1.0.0`, le flux `apps/macos/appcast.xml`.

```bash
P=$HOME/Dev/maillage-thread/.superpowers/deploiement; W=$S/deploiement-exec; cd "$W/publication-halo/apps/macos" && SPARKLE_BIN="$P/sparkle/bin" DD="$HOME/Library/Developer/Xcode/DerivedData/deploiement-exec-halo" Outils/publier.sh 1.0.0 --sans-bureau > "$W/publication-halo.txt" 2>&1; echo "code $?" >> "$W/publication-halo.txt"; grep -v "^tests " "$W/publication-halo.txt"
```

Expected : `version 1.0.0, numero de compilation <commits de main>, macOS 15.0 minimum`, puis comme au step 2, avec `https://github.com/Djoko-cli/benq-screenbar-halo-matter/releases/tag/compagnon-v1.0.0` et `https://raw.githubusercontent.com/Djoko-cli/benq-screenbar-halo-matter/main/apps/macos/appcast.xml`.

- [ ] **Step 4 : les flux en ligne.**

```bash
for c in maillage-thread:maillage-v1.0.0:appcast.xml benq-screenbar-halo-matter:compagnon-v1.0.0:apps/macos/appcast.xml; do r=${c%%:*}; e=${c#*:}; e=${e%%:*}; f=${c##*:}; gh release view $e -R Djoko-cli/$r --json assets -q '.assets[].name'; curl -sL https://raw.githubusercontent.com/Djoko-cli/$r/main/$f | grep -E "shortVersionString|enclosure" | cut -c1-120; done
```

Expected : pour chaque dépôt, le seul `.dmg` ; dans le flux, `<sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>` et l'`enclosure` vers `https://github.com/Djoko-cli/…/releases/download/maillage-v1.0.0/Maillage-Thread-1.0.0.dmg` (ou `compagnon-v1.0.0/Halo-Compagnon-1.0.0.dmg`). L'adresse brute peut mettre quelques minutes à suivre `main`.

- [ ] **Step 5 (avec Djoko, accord) : les dépôts de travail à jour.** Le geste : `git pull --ff-only` dans `~/Dev/maillage-thread` et `~/Documents/Dev/esp32/benq`, pour y recevoir le commit du flux.

```bash
for d in ~/Dev/maillage-thread ~/Documents/Dev/esp32/benq; do git -C "$d" pull -q --ff-only && git -C "$d" log --oneline -1; done; sleep 5; git -C ~/Documents/Dev/esp32/benq status --short | wc -l
```

Expected : `Publier Maillage Thread 1.0.0 dans le flux des mises a jour`, puis `Publier Halo Compagnon 1.0.0 dans le flux des mises a jour` ; `0` (sous iCloud, relire `git status` après une fusion).

---

### Task 16: La remise des .dmg sur le Bureau (avec Djoko)

- [ ] **Step 1 (avec Djoko, accord) : copier les deux .dmg sur son Bureau.**

```bash
W=$S/deploiement-exec; cp "$W/publication-maillage/build/publication/1.0.0/Maillage-Thread-1.0.0.dmg" "$W/publication-halo/apps/macos/build/publication/1.0.0/Halo-Compagnon-1.0.0.dmg" ~/Desktop/ && ls -la ~/Desktop/*-1.0.0.dmg && shasum -a 256 ~/Desktop/Maillage-Thread-1.0.0.dmg ~/Desktop/Halo-Compagnon-1.0.0.dmg
```

Expected : les deux fichiers, aux tailles que disent les flux (tâche 15, step 4).

---

### Task 17: La vérification en vrai (avec Djoko, spec, section 5)

Ce que seule une vraie session avec Djoko peut voir : l'installation et Gatekeeper, la fenêtre de Sparkle, « Installer et relancer », Thread Route vu par les deux apps, le trousseau de Halo Compagnon après une mise à jour. Chaque point a son accord ; le contrôleur note ce que Djoko voit.

- [ ] **Step 1 : l'installation depuis le Bureau, et Gatekeeper.** Djoko quitte lui-même ses instances de développement, ouvre chaque `.dmg`, glisse l'app dans Applications, l'ouvre : macOS refuse ; Réglages Système, Confidentialité et sécurité, « Ouvrir quand même », puis confirmer avec son mot de passe (depuis macOS 15, le clic droit ne suffit plus). L'app s'ouvre ; à la seconde ouverture, plus rien. Pour Maillage Thread, Réglages, Général, « Ouvrir à la connexion » : vérifier qu'il vise bien l'app d'Applications (le basculer s'il le faut).

- [ ] **Step 2 : « Rechercher les mises à jour… ».** Dans le menu de chaque app (Maillage Thread : le menu de la barre ; Halo Compagnon : le menu Halo Compagnon) : la fenêtre de Sparkle dit, en français, que la version 1.0.0 est la plus récente. Réglages, Général, « Mises à jour » : les deux cases cochées.

- [ ] **Step 3 : Thread Route, vu par les deux apps.** Maillage Thread, Réglages, Diagnostic : « Thread Route » : « Actif » ; Halo Compagnon, Réglages, Général : « Actif ». Facultatif : Djoko le désactive dans Réglages Système, « Autoriser en arrière-plan » : les deux apps disent « Désactivé dans Réglages Système » et proposent « Ouvrir Réglages Système… » ; il le réactive.

- [ ] **Step 4 : « Installer et relancer », et le trousseau de Halo Compagnon.** Avec les copies 1.0.0 de la répétition (tâche 12, signées par la vraie clé, flux local) : relancer le serveur local sur le dossier de la répétition (`/usr/bin/python3 -m http.server 8765 --bind 127.0.0.1 --directory "$W/repetition/serveur"`, en tâche de fond), y remettre le flux d'après la 1.0.1 (`cp "$W/repetition/flux-halo-1.0.1.xml" "$W/repetition/serveur/Djoko-cli/benq-screenbar-halo-matter/main/apps/macos/appcast.xml"`), et remettre la copie de Halo Compagnon en 1.0.0 : mettre à la corbeille celle que `sparkle-cli` a passée en 1.0.1, puis recopier la 1.0.0 depuis le `.dmg` 1.0.0 de la répétition (`hdiutil attach -nobrowse -readonly`, `ditto`, `hdiutil detach`). Djoko quitte son Halo Compagnon, ouvre la copie 1.0.0, « Rechercher les mises à jour… » : la fenêtre de Sparkle propose 1.0.1 avec ses notes ; « Installer et relancer » : l'app se relance en 1.0.1 (À propos de Halo Compagnon). Sur une source réseau, macOS demande sans doute l'accès à la clé du pont au premier lancement de la copie 1.0.0 (elle est signée par le certificat, l'app de développement ne l'était pas : spec, section 6) : Djoko l'autorise ; **après la mise à jour en 1.0.1, il ne le redemande plus** (même exigence de signature) : c'est ce que ce step vérifie. Puis arrêter le serveur (`kill` sur son PID), mettre la copie à la corbeille et la désinscrire de LaunchServices (`lsregister -u`), et rouvrir l'app d'Applications. Pour Maillage Thread, le même geste ne se fait que si Djoko le demande : la copie tourne en mode direct.

- [ ] **Step 5 : la migration,** déjà vue à la tâche 13 : `halo-routes` n'est plus dans « Autoriser en arrière-plan », Thread Route y est.

- [ ] **Step 6 : ranger.** Les DD de ce plan (`deploiement-exec-*`), `$W/repetition*`, `$W/publication-*` et `$HOME/Library/Caches/deploiement-exec` vont à la corbeille ; les deux worktrees aussi, après leur fusion (leurs commits sont dans `main`), puis `git worktree prune` dans chaque dépôt. Rien ne s'efface définitivement.
