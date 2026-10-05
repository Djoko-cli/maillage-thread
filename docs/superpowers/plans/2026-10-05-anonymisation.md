# Anonymisation des dépôts Maillage Thread et pont Halo : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, par le contrôleur de la session lui-même, sans sous-agent (voir Global Constraints). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** remplacer, dans tout l'historique des deux dépôts publics, les données réelles du réseau et de la maison de Djoko par des valeurs inventées cohérentes, vérifier qu'il n'en reste rien, remettre le code en état, puis remplacer les dépôts de travail et republier, avec l'accord de Djoko à chaque geste qui touche ses dépôts ou GitHub.

**Architecture :**
- **Des outils privés**, en Python 3.9 sans dépendance, dans `~/Dev/maillage-thread/.superpowers/anonymisation/outils/` (ignoré par git, jamais commité) :
  - `table.py`, le générateur de la table (spec, section 2) : il lit les deux inventaires, `noms.json` et ses copies, et les historiques ; il écrit `table.json`, privé, où chaque valeur réelle a sa remplaçante et toutes leurs écritures ;
  - `filtre.py`, le filtre (spec, section 3) : il lit `git fast-export --all`, réécrit contenus, chemins, messages et auteurs, retire le `.pyc` et le segment `iCCP` des PNG, remplace les identifiants de commit cités par `get-mark`, et écrit dans `git fast-import` ;
  - `controles.py`, les contrôles (spec, section 4) : le balayage, le second balayage par les scripts des inventaires, la réversibilité et la forme ; il ne montre que des comptes ;
  - `remettre_en_etat.py`, la remise en état (spec, section 5), et `reecrire.sh`, qui enchaîne table, filtre et contrôles ;
  - leurs tests, sur un monde synthétique de valeurs inventées, et `mutants.py`.
- **La répétition générale a été faite le 05/10** sur des copies, dans le scratchpad de la session (`$S/anon-repetition/`) : archives, miroirs, réécriture, contrôles, remise en état, toutes les suites de tests, puis un rejeu sur des miroirs neufs, aux têtes identiques. L'exécution rejoue la réécriture sur des miroirs neufs et doit retrouver les mêmes têtes.
- **Les étapes avec Djoko** (tâches 2, 3 et 6 à 9) attendent chacune son accord explicite, donné dans la conversation.

**Tech Stack :** Python 3.9 (`/usr/bin/python3`, sans dépendance), git 2.54 (`fast-export`, `fast-import` et `get-mark`, `bundle`), `gh` (lecture ; création et push aux tâches 8 et 9, avec Djoko), XcodeGen et `xcodebuild` (Xcode 27), PlatformIO (fork pioarduino), clang.

**Spec :** `docs/superpowers/specs/2026-10-05-anonymisation-design.md`, validée par Djoko le 05/10. Djoko est ici le propriétaire des dépôts, nommé comme dans les dépôts réécrits. Le brief de ce plan est privé : `.superpowers/anonymisation/plan-brief.md`.

## La répétition générale du 05/10 : code validé, faits établis

**Les outils.** Le code de la tâche 1 est celui qui a tourné : 11 fichiers, 3 287 lignes. Ses tests passent : 25 tests, sur un monde synthétique construit par les tests (deux dépôts, deux inventaires, un `noms.json` et des décisions, toutes valeurs inventées). Les 14 mutants de `mutants.py` les font tous échouer :
- une écriture oubliée (hexa en minuscules) ;
- une valeur dérivée non recalculée (le préfixe tiré du xp réel) ;
- l'ordre perdu ;
- deux collisions : une remplaçante déjà dans l'historique, une valeur déjà prise ;
- un auteur non réécrit ;
- un fragment court manqué ;
- un PNG qui garde son profil ICC ;
- le `.pyc` gardé, même en objet orphelin ;
- les identifiants de commit laissés ;
- un nom de plusieurs mots gardé ;
- le sous-réseau réel, derrière un /48 factice de la sonde, oublié dans les tableaux d'octets ;
- une suite d'octets écrite en hexa oubliée ;
- le balayage qui ne cherche plus les fragments.

**Les archives.** `git bundle create --all` des deux dépôts de travail, dans `$S/anon-repetition/archives/` : `git bundle verify` les dit complets ; un clone de chacun retrouve `main` en `8297321` (420 commits) et en `e114cd5` (143 commits).

**La table.** 195 valeurs, 1 666 écritures et 169 suites d'octets. Par nature : 31 identifiants de 16 chiffres (ExtMac, xa, noms d'hôte), 3 noms d'hôte de 12 chiffres, 5 MAC, 3 fabriques, 57 nœuds, 6 identifiants d'agent, 35 IID, 10 préfixes /48, 3 préfixes /64, 4 partitions, le xp, l'horodatage du dataset, le nom du réseau, 8 adresses IPv4, 3 empreintes, le numéro de série, 6 instances meshcop et 6 noms d'hôte lisibles, 8 noms, l'adresse électronique, le prénom et l'étiquette du fuseau. Valeurs dérivées, recalculées et non tirées : le préfixe et le sous-réseau du lien d'infrastructure (du xp), un nom d'hôte MAC + `0000`, la partition écrite à l'envers, l'instance meshcop qui finit par la fin d'un xa, le nom d'hôte qui finit par la fin d'une MAC, cinq noms d'hôte tirés de leur instance, les liens-locaux EUI-64, les dates et entiers de l'horodatage, les instances Matter (fabrique et nœud).

**La réécriture.**
- **Pont Halo :** 143 commits ; 138 versions de fichiers texte, 14 messages et 16 PNG changés ; le `.pyc` retiré (il était dans 36 commits) ; 78 identifiants de commit cités remplacés, aucun laissé.
- **Maillage Thread :** 420 commits ; 603 versions de fichiers texte et 32 messages changés ; 181 identifiants de commit cités remplacés, et 7 du pont Halo, par sa carte.
- **Têtes :** pont Halo `a136f06ae06ce17ca14f5cfe70d39ffbc832a986`, Maillage Thread `21428e575e63276f8f1134657bc19a189da788ed`.

**Les contrôles,** sur les deux dépôts réécrits :
- **le balayage** ne trouve rien. Ses faux positifs connus :
  - un fragment de 6 chiffres, par hasard, dans un identifiant de commit réécrit, dans chaque dépôt, et un dans un identifiant d'arbre ou de parent d'un en-tête de Maillage Thread ;
  - 3 occurrences de deux noms réels dans le projet 3MF du boîtier, un binaire zip laissé intact : un nom de produit et un mot courant ;
  - les noms gardés par décision (précision 2) : les mots courants de pièce (30 occurrences dans le pont, 6 546 dans Maillage), les noms de produit (7 et 19), les noms d'un seul mot (5 148 et 5 547) ;
- **le second balayage** ne trouve rien. Le script de l'inventaire du pont ne retrouve plus aucune des valeurs remplacées ; il retrouve les graines gardées par décision : adresse radio, balise, charges, trames et CRC, canal, ports USB, VID et PID de l'écran, identifiants de paquet, pseudonyme, Tailscale, chemins `/private/tmp/claude-501` et identifiant de session. Le script des noms ne voit plus que les noms gardés : 10 dans le pont, 21 dans Maillage ;
- **la réversibilité** retrouve chaque fichier à l'octet près, dans chaque commit : 820 versions de fichiers texte et 27 PNG pour le pont, 1 511 et 2 pour Maillage, chaque message ; les seules différences admises sont le prénom devenu « Djoko », le `.pyc` retiré et le profil ICC ;
- **la forme** est gardée : mêmes commits, références, dates et parents, mêmes chemins (208 et 269), au `.pyc` près.

**La remise en état :** un commit par dépôt (tâche 5) ; aucune valeur réelle n'en a besoin pour fonctionner chez Djoko (précision 10).

**Les tests,** sur les clones de travail remis en état :
- **Maillage Thread :**
  - la suite entière, en français puis en anglais : 420 tests en 42 suites pour le cœur, 391 en 32 pour l'app ;
  - les tests Python de la sonde (141) et ses tests hôte (`test_h1` 121 vérifications, `test_distant` 145) ;
  - `outils/mesurer.sh` : 22 tests en 2 suites, la grande maison en 0,21 s, 150 noms en 0,32 ms, très serrés en 2,98 ms ;
- **pont Halo :**
  - `pio run` sur `esp32c6thread` et `esp32c6supermini` : SUCCESS ;
  - les tests hôte (`tools/test_halo1.sh`) : 2 232 498 vérifications du protocole, 301 du JSON, 121 de H1, et `json_check.py` sans erreur ;
  - `tools/test_halo_udp.py` (8 tests), `tools/macos/halo-routes/tests.sh` (47 vérifications) ;
  - `apps/macos/Outils/generer_demo.py` régénère la démo à l'identique ;
  - Halo Compagnon, en français puis en anglais : 144 tests en 20 suites pour HaloProtocole, 34 en 7 pour l'app.

**Le rejeu.** Sur des miroirs neufs, `reecrire.sh` redonne la même table, octet pour octet, les mêmes cartes des identifiants de commit et les mêmes têtes. `remettre_en_etat.py` redonne les mêmes arbres : Maillage Thread `719a0c32e78a0fd8112cf3fe0c813b054a2b4be3`, pont Halo `cae7c2e9a9b384c14b51fdf5ca614a4320f5cd41`.

**Faits établis :**
- `python3` est, dans le shell de la session, celui de PlatformIO (3.11) : les outils se lancent par `/usr/bin/python3`.
- `git bundle verify` exige un dépôt : il se lance depuis un dépôt vide, jamais depuis un dépôt de travail.
- `fast-import` ne répond à `get-mark` qu'entre deux commandes : le filtre n'écrit l'en-tête d'un commit qu'une fois son message réécrit.
- `tools/macos/halo-routes/tests.sh` finit par un passage en essai qui lit les routes du Mac : sa sortie porte le vrai préfixe du réseau. Elle va dans un fichier privé et ne se recopie jamais.
- Les copies `tmp/noms-*/noms.json` du conteneur de l'app sont écrites par ses tests : un des noms trouvés n'y vient que d'un cas de test.
- `premierClicDansUneFenetreInactive` (`FenetrePiecesTests`) échoue sous charge, quand une autre compilation tourne : on le relance seul, puis la suite entière sans autre charge.
- Sous zsh, `echo ====` échoue (expansion de `=mot`) : les séparateurs s'écrivent `== …`.

## Précisions

Ce sont les choix faits là où la spec laissait la main, ou là où l'historique l'a contredite. Djoko les valide à la tâche 2.

1. **Les identifiants de commit cités sont remplacés** (spec, section 3.4 : le cas retenu). C'est faisable proprement : `fast-export` émet les commits parents avant leurs enfants, et chaque blob juste avant le commit qui l'introduit ; un identifiant cité désigne donc un commit déjà importé, et `get-mark` donne son nouvel identifiant, tronqué à la longueur citée. Les identifiants du pont cités par Maillage Thread passent par la carte du pont, réécrit d'abord. Un identifiant ambigu ou inconnu reste tel quel : il n'y en a aucun.
2. **Les noms réels** (spec, section 2). La spec dit : les 23 noms trouvés sont remplacés, les 9 mots courants de pièce gardés. Lus en contexte, 12 de ces 23 noms sont un seul mot, et dans l'historique ce mot est un mot courant de la prose, un nom de type ou de fichier Swift, un nom générique de cas de test, ou le nom public du produit et du projet, que porte aussi le pont dans la démo. Les remplacer partout aurait renommé du code, des textes de l'interface et le projet lui-même. La règle appliquée, dans cet ordre :
   - un mot courant de pièce est gardé (9) ;
   - un nom d'un seul mot est gardé, comme un mot courant (12) ;
   - un nom qui contient une marque est un nom de produit, gardé (3) ;
   - tout autre nom, de plusieurs mots, est remplacé partout en entier (8), par un nom inventé du même genre d'appareil, de même initiale et de même longueur quand c'est possible, et dans le même ordre lexical que les noms réels : l'ordre des listes triées de l'app n'en change pas.

   Les listes de mots courants, de marques, de modèles et de genres d'appareil sont privées : `decisions-noms.json`. Djoko y met `remplacer` ou `garder` pour changer un nom de règle.
3. **Les instances meshcop et les noms d'hôte lisibles** (spec, section 1). Le modèle du fabricant est gardé ; ce qui le suit est traité ainsi :
   - un qualificatif donné par Djoko est remplacé (2), dans le même ordre et de même longueur ;
   - un mot courant de pièce est gardé (2) : l'app tire la pièce d'un routeur de son nom ;
   - un nom fait du seul modèle est gardé (1) ;
   - le suffixe tiré de la fin d'un xa ou d'une MAC est recalculé (2).

   Les noms d'hôte suivent leur instance.
4. **Ce que garde un identifiant remplacé,** pour que l'ordre des listes triées tienne aussi entre natures :
   - ses zéros de tête et les deux chiffres qui les suivent ;
   - l'OUI, pour une MAC ;
   - `fd`, pour un préfixe ULA ;
   - le premier chiffre, pour une partition.

   Dans une même nature, l'ordre est gardé, et chaque groupe IPv6 garde son nombre de chiffres et ses lettres. Aucune remplaçante ne contient 6 chiffres d'une valeur réelle, hors de ce qui est gardé.
5. **Le fuseau.** L'étiquette du fuseau des tests devient le nom d'un fuseau réel, au même décalage et sans heure d'été, tiré au sort parmi ceux de la base `tzdata` du Mac, hors de l'aire géographique du fuseau du Mac. Le balayage cherche aussi le nom du fuseau du Mac. Les dates des commits ne changent pas.
6. **Les adresses IPv4** passent dans `192.0.2.0/24`, dans le même ordre. Leur longueur peut changer : la spec fixe la plage.
7. **Gardé, parce que la spec ne le remplace pas :** le canal radio, les noms de port USB, le VID et le PID de l'écran, la mention de Tailscale, les chemins `/private/tmp/claude-501` et l'identifiant de session Claude, le pseudonyme, les identifiants de paquet, et l'adresse radio de la lampe avec tout le protocole. Le README de la capture anonymisée de la sonde le dit pour le canal (tâche 5).
8. **Le projet 3MF du boîtier,** un zip, est un binaire laissé intact (spec, section 3). Le balayage le décompresse et y trouve un nom de produit, qui est aussi dans `noms.json`, et un mot courant.
9. **Les anciens commits** gardent l'ancienne empreinte SHA-256 de la capture de la sonde ; seul l'état final la corrige (spec, section 5).
10. **Une valeur réelle dont le code a besoin chez Djoko :** aucune. Toutes les valeurs remplacées que lit du code hors des tests sont des exemples de commentaires, de l'aide de `tools/halo_udp.py` ou de la démo. L'adresse radio de la lampe est gardée ; le firmware lit sa MAC dans l'eFuse ; la clé du pont reste dans le trousseau, sous le même service.
11. **Le plan lui-même** est sur la branche `anon-plan`, partie de `8297321`. Il n'entre pas dans la réécriture, qui ne prend que `main` et les références distantes : les têtes restent celles de la répétition. Il est ajouté tel quel au nouveau `main` à la tâche 5 : il ne contient aucune valeur réelle (le balayage le vérifie), et ses identifiants de commit désignent exprès l'ancien historique, celui des archives.

## Global Constraints

- **Aucune valeur réelle** (identifiant réseau, adresse, nom de pièce ou d'appareil, prénom, adresse électronique, numéro de série, fuseau), même partielle ou masquée, dans un fichier commité, un message de commit, un rapport ou une réponse. Elles ne vivent que dans des fichiers privés, sous `~/Dev/maillage-thread/.superpowers/anonymisation/` (ignoré par git) ou dans le scratchpad de la session. Une commande qui en affiche une écrit dans un fichier privé, jamais à l'écran.
- **`noms.json`** et ses copies ne se lisent que par script, et ne s'affichent jamais.
- **Outils :** `/usr/bin/python3` (3.9), sans dépendance ; ils restent privés et ne sont jamais commités.
- **`$S`** est le scratchpad de la session, celui qui porte `anon-repetition/`. Son chemin n'est écrit ni dans ce plan ni dans un commit : il contient le nom d'utilisateur. Chaque commande porte ses variables, car le shell ne les garde pas d'une commande à l'autre :
  - `A=$HOME/Dev/maillage-thread/.superpowers/anonymisation`, `O=$A/outils`, `E=$A/execution` ;
  - `R=$S/anon-repetition`, la répétition, et `X=$S/anon-execution`, l'exécution.
- **Produits de compilation :** les DD `maillage-anon-exec` (Maillage Thread) et `maillage-anon-exec-halo` (Halo Compagnon), le `TMPDIR` `$HOME/Library/Caches/maillage-anon-exec/` ; jamais un autre DD, car l'app de Djoko tourne depuis l'un d'eux.
- **Les dépôts de travail** (`~/Dev/maillage-thread`, `~/Documents/Dev/esp32/benq`) ne changent pas avant la tâche 6 : ni branche, ni configuration, ni reflog. Les miroirs se font par `git clone --mirror --no-local`.
- **Étapes avec Djoko** (tâches 2, 3 et 6 à 9) : le contrôleur décrit le geste, attend un oui clair dans la conversation, puis l'exécute. Un accord vaut pour un geste.
- **Interdits :**
  - `sudo`, port série, flashage ;
  - lancer l'app Maillage Thread hors de ses tests, quitter l'app de Djoko, réveiller l'écran ;
  - un push ou un `gh` qui modifie quelque chose hors des tâches 8 et 9 ;
  - des sous-agents : le plan manipule des données privées.
- **Commits :** en français sans accents, terminés par une ligne vide puis `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ; `git add` avec une liste explicite. Les commits de la tâche 5 portent l'auteur `Djoko-cli` et l'adresse noreply.
- **Disque :** environ 12 Go libres. À la fin, les DD, les caches et `.pio` de l'exécution vont à la corbeille (`~/.Trash`) ; rien ne s'efface définitivement, sauf l'ancien historique des dépôts de travail, à la tâche 6.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `$O/commun.py` | lecture des dépôts, moteur de remplacement (formes par classe de bornes, suites d'octets `0xNN`), identifiants de commit, chemins de `fast-export`, PNG | 1 |
| `$O/inventaires.py` | lecture des deux inventaires privés, valeur par nature | 1 |
| `$O/table.py` | générateur de la table | 1, 4 |
| `$O/filtre.py` | filtre `fast-export` → `fast-import` | 1, 4 |
| `$O/controles.py` | balayage, second balayage, réversibilité, forme ; balayage de fichiers (le plan, un rapport) | 1, 4, 5, 10 |
| `$O/remettre_en_etat.py` | remise en état des deux clones de travail | 1, 5 |
| `$O/reecrire.sh` | table, filtre et contrôles sur deux miroirs | 1, 4 |
| `$O/mutants.py`, `$O/tests/monde.py`, `$O/tests/test_table.py`, `$O/tests/test_filtre.py` | tests sur valeurs inventées, mutants | 1 |
| `$A/decisions-noms.json` (privé, déjà là) | mots courants de pièce, marques, modèles, genres d'appareil, `remplacer`, `garder` | 2, 4 |
| `$A/table.json` (privé) | la table de la répétition | 2, 4 |
| `$A/scripts-inventaires/` (privé, déjà là) | `scan.py` de l'inventaire du pont, `chercher_noms.py` et `noms_reels.py` de celui des noms | 4 |
| `$E/` (privé, créé à la tâche 4) | adresse noreply, table et journaux de l'exécution | 4 à 10 |
| `docs/releves/2026-09-29/README.md`, deux plans de Maillage Thread, `docs/PLAN-PILOTE-HALO1*.md` du pont | remise en état | 5 |
| `docs/superpowers/plans/2026-10-05-anonymisation.md` | ce plan, ajouté au nouveau `main` | 5 |
| `~/Documents/Archives-anonymisation/` | les archives des historiques d'origine | 3 |
| `~/Documents/Dev/esp32/benq/.superpowers/anonymisation/demande-support.md` (privé) | la demande au support GitHub | 9 |

---

### Task 1: Les outils, vérifiés et testés

**Files:**
- Create (déjà là depuis la répétition) : `$O/commun.py`, `$O/inventaires.py`, `$O/table.py`, `$O/filtre.py`, `$O/controles.py`, `$O/remettre_en_etat.py`, `$O/reecrire.sh`, `$O/mutants.py`
- Test : `$O/tests/monde.py`, `$O/tests/test_table.py`, `$O/tests/test_filtre.py`

**Interfaces:**
- Consumes : les inventaires privés (`$A/inventaire.md`, `~/Documents/Dev/esp32/benq/.superpowers/anonymisation/inventaire.md`), `noms.json` et ses copies, `$A/decisions-noms.json`.
- Produces :
  - `table.py --inventaire-mt INV --inventaire-bq INV --noms N… --depot mt=M --depot bq=B --courriel-nouveau ADR --decisions-noms D --sortie T` : `table.json`, `{valeurs: [{nature, reel, nouveau, depots, derivee, garde, formes: [[classe, reel, nouveau, etiquette, depots]], octets: [[reel, nouveau, mode, depots]]}], noms: {nom: {portee, raison}}, noms_reels, zone_systeme, graine}` ;
  - `filtre.py --table T --nom-depot mt|bq --source MIROIR --cible NEUF.git --carte-sortie C [--carte-externe C2]` : le dépôt réécrit, et la carte `{ancien sha: nouveau sha}` ;
  - `controles.py balayage|second|reversibilite|forme|fichiers …` : des comptes ; code 1 si quelque chose n'est pas un faux positif connu ;
  - `remettre_en_etat.py maillage CLONE MIROIR` et `remettre_en_etat.py benq CLONE` : la liste des fichiers changés ;
  - `reecrire.sh SORTIE MIROIR_MT MIROIR_BQ TABLE`, avec `NOREPLY_FICHIER`, `INVENTAIRE_SCRIPTS` et `NOMS_SCRIPTS`.

Les outils existent déjà, tels qu'ils ont tourné à la répétition. Cette tâche vérifie qu'ils sont ceux de ce plan, puis les teste. Un fichier absent ou différent se recrée tel que donné ci-dessous.

- [ ] **Step 1 : les fichiers sont ceux du plan.**

Run :

```bash
cd ~/Dev/maillage-thread/.superpowers/anonymisation/outils && shasum -a 256 commun.py inventaires.py table.py filtre.py controles.py remettre_en_etat.py mutants.py reecrire.sh tests/monde.py tests/test_table.py tests/test_filtre.py
```

Expected :

```
4ebc5aea74b49962b1cfb6419bba3f9fb4a3ac4370232c8a967fcda108853537  commun.py
fa846a8a32dea2c95419c419ba9e0c4df93c6a57e0245c9159d233c68c883aa6  inventaires.py
03907d1f71af4edbbfaf667dec73c7ac7abba97f6a8df3209ec1dd671a2517a2  table.py
f62024f33f2408bda4d70dc8aa30dc22432218a5d687b3fb9bb83b4ae49a534e  filtre.py
d0cc13854898be6de5bf595af2f5a1982561fc8727f19fdf42ff4dea17e1e8cf  controles.py
8c25d6735a9bebd3b1bcb5436dd50a38020696f75d08d52852a01b5513381bc2  remettre_en_etat.py
9c317945818ad4b60cefb37c6fe47780cff1518aa117a96653ac0f60bd7d66e6  mutants.py
3b6cb8745e0dea6519502907d427b7fed0488fe37a71c8db95f4da9dabaa66e3  reecrire.sh
4c26b452f9e1f72015f864c52a3a9b27b4e352fc64d4996fab2166378a50fdf9  tests/monde.py
191c50f4d011c506b421df0b9e29ffa29e0ba79e82880d5c6468205c45e340e6  tests/test_table.py
e7b547f06fb15797607de6475d27804537f6f0338243a5f96f5e5549329dede5  tests/test_filtre.py
```

- [ ] **Step 2 : les tests passent.**

Run : `cd ~/Dev/maillage-thread/.superpowers/anonymisation/outils/tests && /usr/bin/python3 -m unittest > /dev/null 2> "$TMPDIR/anon-tests.txt"; echo "code $?"; tail -3 "$TMPDIR/anon-tests.txt"`

Expected : `code 0`, puis `Ran 25 tests in …` et `OK`.

- [ ] **Step 3 : les mutants échouent tous.**

Run : `/usr/bin/python3 ~/Dev/maillage-thread/.superpowers/anonymisation/outils/mutants.py | tail -1`

Expected : `mutants tues : 14 sur 14` (environ 2 minutes).

- [ ] **Step 4 : aucune valeur réelle dans les outils.**

Run : `A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; /usr/bin/python3 $A/outils/controles.py fichiers --table $A/table.json $A/outils/*.py $A/outils/reecrire.sh $A/outils/tests/*.py`

Expected : `trouve : aucun` ; en faux positifs connus, seulement des noms d'un seul mot gardés (le nom du projet).

Rien à commiter : les outils sont privés.

`$O/commun.py` (fichier entier) :

```python
"""Outils partages de l'anonymisation : lecture des depots, moteur de remplacement, formes.

Aucune valeur reelle dans ce fichier : elles vivent dans les fichiers prives (inventaires,
noms.json, table.json). Python 3.9, sans dependance.
"""
import os
import re
import subprocess
import unicodedata

CLASSES = ('brut', 'hexa', 'mot', 'ident', 'nombre', 'ipv4')
BORNES = {
    'brut': ('', ''),
    'hexa': ('(?<![0-9A-Fa-f])', '(?![0-9A-Fa-f])'),
    'mot': (r'(?<![\w])', r'(?![\w])'),
    'ident': ('(?<![0-9A-Za-z_])', '(?![0-9A-Za-z_])'),
    'nombre': ('(?<![0-9])', '(?![0-9])'),
    'ipv4': (r'(?<![0-9.])', '(?![0-9])'),
}
RUN = r'0[xX][0-9A-Fa-f]{2}(?![0-9A-Fa-f])(?:\s*,\s*0[xX][0-9A-Fa-f]{2}(?![0-9A-Fa-f]))+'
JETON_OCTET = re.compile(r'0[xX]([0-9A-Fa-f]{2})')
SHA = re.compile(r'(?<![0-9A-Za-z])[0-9a-f]{7,40}(?![0-9A-Za-z])')


# --- git -------------------------------------------------------------------------------------

def git(depot, *args, entree=None, octets=False):
    r = subprocess.run(['git', '-C', depot, *args], input=entree, capture_output=True,
                       text=not octets, check=True)
    return r.stdout


def commits(depot):
    """Tous les commits de toutes les references, du plus ancien au plus recent."""
    return git(depot, 'rev-list', '--all', '--topo-order', '--reverse').split()


def arbre(depot, commit):
    """{chemin: (mode, sha)} de l'arbre complet d'un commit."""
    sortie = git(depot, 'ls-tree', '-r', '-z', '--full-tree', commit)
    res = {}
    for entree in sortie.split('\0'):
        if entree:
            meta, chemin = entree.split('\t', 1)
            mode, _, sha = meta.split()
            res[chemin] = (mode, sha)
    return res


def lire_objets(depot, shas):
    """{sha: octets} par git cat-file --batch."""
    if not shas:
        return {}
    p = subprocess.run(['git', '-C', depot, 'cat-file', '--batch'], input=('\n'.join(shas) + '\n').encode(),
                       capture_output=True, check=True)
    sortie, i, res = p.stdout, 0, {}
    while i < len(sortie):
        j = sortie.index(b'\n', i)
        entete = sortie[i:j].split()
        i = j + 1
        if len(entete) < 3:
            continue
        taille = int(entete[2])
        res[entete[0].decode()] = sortie[i:i + taille]
        i += taille + 1
    return res


class Historique:
    """Tout ce que contient un depot : arbres, blobs, commits (en-tetes et messages), chemins."""

    def __init__(self, depot):
        self.depot = depot
        self.commits = commits(depot)
        self.arbres = {c: arbre(depot, c) for c in self.commits}
        blobs = sorted({sha for a in self.arbres.values() for mode, sha in a.values() if mode != '160000'})
        self.blobs = lire_objets(depot, blobs)
        self.objets_commit = lire_objets(depot, self.commits)
        self.chemins = sorted({p for a in self.arbres.values() for p in a})
        self.chemins_du_blob = {}
        for a in self.arbres.values():
            for p, (mode, sha) in a.items():
                self.chemins_du_blob.setdefault(sha, set()).add(p)

    def entetes_et_message(self, commit):
        brut = self.objets_commit[commit].decode('utf-8', 'replace')
        entetes, _, message = brut.partition('\n\n')
        return entetes, message

    def textes(self):
        """(nom, texte) de chaque blob texte, message et chemin."""
        for sha, b in self.blobs.items():
            t = texte_ou_none(b)
            if t is not None:
                yield 'blob:' + sha, t
        for c in self.commits:
            e, m = self.entetes_et_message(c)
            yield 'message:' + c, m
            yield 'entetes:' + c, e
        for p in self.chemins:
            yield 'chemin:' + p, p


def texte_ou_none(b):
    if b'\0' in b:
        return None
    try:
        return b.decode('utf-8')
    except UnicodeDecodeError:
        return None


# --- motifs ----------------------------------------------------------------------------------

def motif_trie(mots):
    """Expression qui reconnait chacun des mots, la plus longue d'abord a une meme position."""
    trie = {}
    for m in mots:
        n = trie
        for c in m:
            n = n.setdefault(c, {})
        n[''] = {}

    def gen(n):
        enfants = sorted((c, s) for c, s in n.items() if c != '')
        if not enfants:
            return ''
        alts = []
        for c, s in enfants:
            chaine = c
            while len(s) == 1 and '' not in s:
                (c2, s2), = s.items()
                chaine += c2
                s = s2
            alts.append(re.escape(chaine) + gen(s))
        corps = alts[0] if len(alts) == 1 else '(?:' + '|'.join(alts) + ')'
        if '' in n:
            return '(?:' + corps + ')?'
        return corps

    return gen(trie)


def style_casse(jeton):
    lettres = [c for c in jeton if c.isalpha()]
    if not lettres:
        return None
    if all(c.isupper() for c in lettres):
        return 'maj'
    if all(c.islower() for c in lettres):
        return 'min'
    return 'mixte'


def en_casse(texte, style):
    return texte.lower() if style == 'min' else texte.upper()


# --- moteur ----------------------------------------------------------------------------------

class Moteur:
    """Remplace en une passe : formes exactes par classe de bornes, et suites d'octets 0xNN.

    regles : [(classe, reel, nouveau)] ; octets : [(reel: bytes, nouveau: bytes, mode)] ou mode vaut
    'partout' (n'importe ou dans une suite d'octets) ou 'debut' (au debut d'une suite seulement).
    """

    def __init__(self, regles, octets=()):
        self.tables = {k: {} for k in CLASSES}
        for classe, reel, nouveau in regles:
            if not reel:
                continue
            deja = self.tables[classe].get(reel)
            if deja is not None and deja != nouveau:
                raise ValueError('forme en double avec deux remplacantes (%s)' % classe)
            self.tables[classe][reel] = nouveau
        vus = {}
        for classe, t in self.tables.items():
            for reel in t:
                if reel in vus and vus[reel] != classe:
                    raise ValueError('forme dans deux classes (%s, %s)' % (vus[reel], classe))
                vus[reel] = classe
        self.octets = {}
        for reel, nouveau, mode in octets:
            if len(reel) != len(nouveau):
                raise ValueError('suite d\'octets de longueurs differentes')
            self.octets.setdefault(reel[0], []).append((bytes(reel), bytes(nouveau), mode))
        for liste in self.octets.values():
            liste.sort(key=lambda x: -len(x[0]))
        parties = []
        if self.octets:
            parties.append('(?P<octets>' + RUN + ')')
        for classe in CLASSES:
            if self.tables[classe]:
                g, d = BORNES[classe]
                parties.append('(?P<%s>%s(?:%s)%s)' % (classe, g, motif_trie(self.tables[classe]), d))
        self.rx = re.compile('|'.join(parties)) if parties else None

    def _octets(self, run):
        jetons = list(JETON_OCTET.finditer(run))
        vals = [int(j.group(1), 16) for j in jetons]
        neufs = list(vals)
        i = 0
        while i < len(vals):
            pris = 0
            for reel, nouveau, mode in self.octets.get(vals[i], ()):
                if mode == 'debut' and i != 0:
                    continue
                if bytes(vals[i:i + len(reel)]) == reel:
                    neufs[i:i + len(reel)] = list(nouveau)
                    pris = len(reel)
                    break
            i += pris or 1
        if neufs == vals:
            return run
        styles = [style_casse(j.group(1)) for j in jetons]
        dominant = 'min' if styles.count('min') > styles.count('maj') else 'maj'
        morceaux, fin = [], 0
        for j, v, s in zip(jetons, neufs, styles):
            morceaux.append(run[fin:j.start(1)])
            morceaux.append(en_casse('%02X' % v, s if s in ('maj', 'min') else dominant))
            fin = j.end(1)
        morceaux.append(run[fin:])
        return ''.join(morceaux)

    def appliquer(self, texte):
        if self.rx is None:
            return texte

        def remplacer(m):
            classe = m.lastgroup
            if classe == 'octets':
                return self._octets(m.group(0))
            return self.tables[classe][m.group(0)]

        return self.rx.sub(remplacer, texte)

    def inverse(self):
        regles = [(k, n, r) for k, t in self.tables.items() for r, n in t.items()]
        octets = [(n, r, mode) for liste in self.octets.values() for r, n, mode in liste]
        return Moteur(regles, octets)


# --- identifiants de commit --------------------------------------------------------------------

def remplacer_shas(texte, resoudre):
    """Remplace chaque jeton hexa minuscule de 7 a 40 caracteres que `resoudre` connait.

    resoudre(jeton) -> nouveau jeton de meme longueur, ou None pour le laisser.
    """
    def f(m):
        j = m.group(0)
        if len(j) not in range(7, 41):
            return j
        n = resoudre(j)
        return n if n is not None else j
    return SHA.sub(f, texte)


class CarteCommits:
    """Prefixes uniques d'identifiants de commit : ancien -> nouveau (meme longueur)."""

    def __init__(self, paires):
        self.paires = dict(paires)
        self.tries = sorted(self.paires)

    def resoudre(self, jeton):
        import bisect
        i = bisect.bisect_left(self.tries, jeton)
        trouves = []
        while i < len(self.tries) and self.tries[i].startswith(jeton):
            trouves.append(self.tries[i])
            i += 1
            if len(trouves) > 1:
                return None
        if len(trouves) != 1:
            return None
        return self.paires[trouves[0]][:len(jeton)]

    def inverse(self):
        return CarteCommits({n: a for a, n in self.paires.items()})


# --- chemins de fast-export --------------------------------------------------------------------

ECHAPPEMENTS = {'"': '"', '\\': '\\', 'a': '\a', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r', 't': '\t', 'v': '\v'}


def dequoter(chemin):
    """Chemin de fast-export (octets) -> texte ; les guillemets suivent la convention C de git."""
    if not chemin.startswith(b'"'):
        return chemin.decode('utf-8', 'surrogateescape')
    s, i, res = chemin[1:-1], 0, bytearray()
    while i < len(s):
        c = s[i]
        if c == 0x5C:
            n = s[i + 1:i + 2].decode()
            if n in ECHAPPEMENTS:
                res += ECHAPPEMENTS[n].encode()
                i += 2
            else:
                res.append(int(s[i + 1:i + 4], 8))
                i += 4
        else:
            res.append(c)
            i += 1
    return bytes(res).decode('utf-8', 'surrogateescape')


def quoter(chemin):
    b = chemin.encode('utf-8', 'surrogateescape')
    besoin = any(c < 0x20 or c >= 0x7F or c in (0x22, 0x5C) for c in b) or b.startswith(b'"')
    if not besoin:
        return b
    res = bytearray(b'"')
    inv = {v.encode()[0]: k for k, v in ECHAPPEMENTS.items()}
    for c in b:
        if c in inv:
            res += b'\\' + inv[c].encode()
        elif c < 0x20 or c >= 0x7F:
            res += b'\\%03o' % c
        else:
            res.append(c)
    res += b'"'
    return bytes(res)


# --- PNG ---------------------------------------------------------------------------------------

PNG = b'\x89PNG\r\n\x1a\n'


def morceaux_png(b):
    """[(type, octets bruts du morceau)] ; None si ce n'est pas un PNG valide."""
    if not b.startswith(PNG):
        return None
    i, res = len(PNG), []
    while i + 8 <= len(b):
        n = int.from_bytes(b[i:i + 4], 'big')
        t = b[i + 4:i + 8]
        res.append((t.decode('latin-1'), b[i:i + 12 + n]))
        i += 12 + n
        if t == b'IEND':
            break
    return res


def png_sans_iccp(b):
    m = morceaux_png(b)
    if m is None:
        return b
    return PNG + b''.join(o for t, o in m if t != 'iCCP') + b[len(PNG) + sum(len(o) for _, o in m):]


# --- noms ----------------------------------------------------------------------------------------

def nfc(s):
    return unicodedata.normalize('NFC', s)


def echappe_json(s, majuscules=False):
    return ''.join(c if ord(c) < 128 else ('\\u%04X' if majuscules else '\\u%04x') % ord(c) for c in s)
```

`$O/inventaires.py` (fichier entier) :

```python
"""Lecture des deux inventaires prives : les valeurs reelles, rangees par nature.

Chaque inventaire range ses valeurs dans des tableaux Markdown, par section. On garde la premiere
cellule (la valeur) et la nature (deuxieme cellule, ou la description de la valeur), puis une regle
par nature dit ce qu'on en tire. Les natures gardees par la spec (adresse radio, canal, ports,
pseudonyme, identifiants de paquet...) ne donnent rien. Aucune valeur reelle dans ce fichier.
"""
import ipaddress
import re

HEX16 = re.compile(r'\b[0-9A-Fa-f]{16}\b')
HEX12 = re.compile(r'\b[0-9A-Fa-f]{12}\b')
HEX32 = re.compile(r'\b[0-9A-Fa-f]{32}\b')
HEX8 = re.compile(r'\b[0-9A-Fa-f]{8}\b')
MAC = re.compile(r'\b[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){5}\b')
IPV6 = re.compile(r'(?<![0-9A-Za-z:])[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{0,4}){2,7}(?:/\d{1,3})?')
IPV4 = re.compile(r'\b(?:\d{1,3}\.){3}\d{1,3}\b')
COURRIEL = re.compile(r'[\w.+-]+@[\w-]+\.[\w.]+')


def lignes_de_tableau(texte):
    """[(section, cellules)] pour chaque ligne de tableau (hors en-tete et separateur)."""
    section, res = '', []
    for ligne in texte.splitlines():
        if ligne.startswith('#'):
            section = ligne.lstrip('#').strip()
            continue
        if not ligne.startswith('|') or set(ligne) <= set('|-: '):
            continue
        cellules = [c.strip() for c in ligne.strip().strip('|').split('|')]
        if cellules and cellules[0] in ('Valeur', 'Valeur réelle', 'Fichier', 'Catégorie', 'Commit', 'Chemin'):
            continue
        res.append((section, cellules))
    return res


def ipv6_de(texte):
    """Adresses et prefixes IPv6 d'une cellule, analyses (les prefixes en reseau)."""
    res = []
    for m in IPV6.finditer(texte):
        jeton = m.group(0)
        try:
            if '/' in jeton:
                res.append(ipaddress.IPv6Network(jeton, strict=False))
            else:
                res.append(ipaddress.IPv6Address(jeton))
        except ValueError:
            pass
    return res


def section_num(section):
    m = re.match(r'(\d+)([a-z]?)\.?', section)
    return (m.group(1) + m.group(2)) if m else ''


def lire_maillage(texte):
    """[(nature, valeur)] de l'inventaire de Maillage Thread."""
    res = []
    for section, c in lignes_de_tableau(texte):
        if len(c) < 2:
            continue
        valeur, nature = c[0].strip('`'), c[1]
        num = section_num(section)
        if num == '1':
            m = re.search(r'([A-Za-z]+\d{10})', valeur)
            if m:
                res.append(('nom_reseau', m.group(1)))
        elif num == '2':
            if nature == 'xp':
                res.append(('xp', valeur.upper()))
            elif nature == 'partition':
                res.append(('partition', valeur.upper()))
            elif nature.startswith('at'):
                res.append(('at', valeur.upper()))
        elif num == '3a':
            for a in ipv6_de(valeur):
                res.append(('prefixe48', str(a.network_address if hasattr(a, 'network_address') else a)))
        elif num == '3b':
            for a in ipv6_de(valeur):
                res.append(('adresse', str(a)))
        elif num == '4':
            if 'MAC deduite' in nature or 'MAC de la sonde' in nature:
                res.append(('mac', valeur.upper()[:12]))
            elif 'nom d hote 12' in nature:
                res.append(('hote12', valeur.upper()))
            elif HEX16.fullmatch(valeur):
                res.append(('hote16', valeur.upper()))
        elif num == '5':
            if 'fabrique' in nature:
                res.append(('fabrique', valeur.upper()))
            elif 'node id' in nature:
                res.append(('noeud', valeur.upper()))
            elif 'id agent' in nature:
                res.append(('agent', valeur.upper()))
            elif '_meshcop' in nature:
                res.append(('meshcop', valeur))
            elif '_matter._tcp' in nature:
                res.append(('instance_matter', valeur.upper()))
        elif num == '6':
            if nature == 'nom d hote' and valeur.endswith('.local'):
                res.append(('hote_lisible', valeur[:-len('.local')]))
        elif num == '8':
            if 'adresse electronique' in nature:
                res.append(('courriel', valeur))
            elif nature.startswith('prenom'):
                res.append(('prenom', valeur))
            elif 'fuseau' in nature:
                res.append(('fuseau', valeur))
            elif 'IPv4' in nature:
                res.append(('ipv4', valeur))
    return res


def lire_benq(texte):
    """[(nature, valeur)] de l'inventaire du pont Halo."""
    res = []
    for section, c in lignes_de_tableau(texte):
        if len(c) < 2:
            continue
        cellule = c[0]
        valeurs = re.findall(r'\*\*(.+?)\*\*', cellule)
        if not valeurs:
            continue
        valeur, nature = valeurs[0], c[1]
        num = section_num(section)
        if num == '1':
            for m in MAC.finditer(valeur):
                res.append(('mac', m.group(0).replace(':', '').upper()))
            if not MAC.search(valeur):
                h = HEX16.search(valeur)
                if h and 'MAC' in nature:
                    m = MAC.search(cellule)
                    if m:
                        res.append(('mac', m.group(0).replace(':', '').upper()))
                elif h:
                    res.append(('hote16', h.group(0).upper()))
        elif num == '3':
            if 'Canal' in nature:
                continue
            if 'fabrique' in nature:
                for h in HEX16.findall(valeur):
                    res.append(('fabrique', h.upper()))
            elif 'Empreintes' in nature:
                for h in HEX8.findall(valeur):
                    res.append(('empreinte', h.upper()))
            else:
                for a in ipv6_de(valeur):
                    if hasattr(a, 'network_address'):
                        res.append(('prefixe48', str(a.network_address)))
                    else:
                        res.append(('adresse', str(a)))
        elif num == '4':
            if 'série' in nature.lower() and 'écran' in nature:
                res.append(('serie', valeur))
        elif num == '6.1' or section.startswith('6.1'):
            if '@' in valeur:
                res.append(('courriel', valeur))
        elif num == '6.2' or section.startswith('6.2'):
            if nature == 'Prénom':
                res.append(('prenom', valeur))
    return res


def section_num_benq(section):
    m = re.match(r'(\d+(?:\.\d+)?)', section)
    return m.group(1) if m else ''
```

`$O/table.py` (fichier entier) :

```python
#!/usr/bin/env python3
"""Generateur de la table des remplacements (spec de l'anonymisation, section 2).

Il lit les deux inventaires, noms.json (et ses copies) et les historiques ; ecrit table.json : chaque
valeur reelle, sa remplacante et toutes leurs ecritures. Deterministe (graine fixe). Les valeurs
derivees sont recalculees a partir des nouvelles valeurs primaires. L'ordre est garde dans chaque
nature. Aucune collision : ni entre remplacantes, ni avec l'historique, ni avec une valeur reelle.

    /usr/bin/python3 table.py --inventaire-mt INV --inventaire-bq INV --noms NOMS.json [--noms ...]
        --depot mt=CHEMIN --depot bq=CHEMIN --courriel-nouveau ADRESSE --sortie table.json
        --decisions-noms DECISIONS.json [--graine N] [--rapport RAPPORT.txt]
"""
import argparse
import datetime
import ipaddress
import json
import os
import random
import re
import sys
import unicodedata

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import commun  # noqa: E402
import inventaires  # noqa: E402

GRAINE = 20261005
PRENOM_NOUVEAU = 'Djoko'
HEX = '0123456789ABCDEF'
# /48 factices de l'anonymiseur de la sonde (outils/anonymiser-sonde.py, public) : il garde le
# sous-reseau reel derriere eux.
FACTICES_SONDE = ('fd00:1111:2222', 'fd00:3333:4444', 'fd00:5555:6666')
# Aires des fuseaux candidats au remplacement de l'etiquette du fuseau des tests.
AIRES = ('Africa', 'America', 'Asia', 'Atlantic', 'Australia', 'Europe', 'Indian', 'Pacific')
CLES_NOMS = {'nom', 'piece', 'pieces', 'domicile'}
# Vocabulaire des noms inventes : appareils, lieux et cotes plausibles, en francais.
APPAREILS = ['Capteur de passage', "Capteur d'ouverture", 'Capteur de fuite', 'Capteur de vibration',
             'Avertisseur de fumée', 'Capteur de lumière', 'Capteur de pluie', 'Volet roulant', 'Store banne',
             'Rideau motorisé', 'Variateur', 'Applique', 'Lampadaire', 'Ruban lumineux', 'Thermostat', 'Radiateur',
             'Sirène', 'Serrure', 'Passerelle', 'Répéteur', 'Enceinte', 'Ordinateur', 'Purificateur',
             'Chauffe-eau', 'Brise-soleil', 'Hotte', 'Télécommande', 'Portable']
LIEUX = ['véranda', 'atelier', 'palier', 'mezzanine', 'lingerie', 'bibliothèque', 'verrière', 'pergola', 'patio',
         'potager', 'serre', 'remise', 'allée', 'piano', 'canapé', 'porte vitrée', 'garde-robe', 'vestibule',
         'loggia', 'galerie', 'fournil', 'chaufferie']
COTES = ['nord', 'sud', 'est', 'ouest', 'avant', 'arrière', 'côté rue', 'côté cour', 'milieu', 'fond']
# Qualificatifs d'une enceinte ou d'un boitier (nom d'instance meshcop) : un mot, sans nom reel.
QUALIFS = ['Ouest', 'Nord', 'Sud', 'Est', 'Avant', 'Milieu', 'Arrière', 'atelier', 'palier', 'véranda',
           'mezzanine', 'lingerie', 'verrière', 'loggia', 'galerie', 'patio', 'vestibule', 'fournil']


LONGUEUR_LIBRE = ('ipv4', 'fuseau', 'nom', 'courriel', 'meshcop', 'hote_lisible')
NON_INVERSIBLES = ('prenom',)


class Echec(Exception):
    pass


# --- petites aides ---------------------------------------------------------------------------

def octets_hex(h):
    return bytes.fromhex(h)


def groupes(n, k):
    """Les k groupes de 16 bits d'un entier de 16k bits, du plus fort au plus faible."""
    return [(n >> (16 * (k - 1 - i))) & 0xFFFF for i in range(k)]


def seq(gs, plein=False):
    return ':'.join(('%04x' if plein else '%x') % g for g in gs)


def compresse(gs):
    """Ecriture abregee d'une suite de groupes avec '::' sur la plus longue suite de zeros (>= 2)."""
    meilleur, debut = (0, -1), -1
    for i, g in enumerate(gs + [1]):
        if g == 0 and debut < 0:
            debut = i
        elif g != 0 and debut >= 0:
            if i - debut > meilleur[0]:
                meilleur = (i - debut, debut)
            debut = -1
    n, d = meilleur
    if n < 2:
        return None
    gauche = ':'.join('%x' % g for g in gs[:d])
    droite = ':'.join('%x' % g for g in gs[d + n:])
    return gauche + '::' + droite


def chiffres(g):
    """Nombre de chiffres hexa significatifs d'un groupe (0 pour 0)."""
    return len('%x' % g) if g else 0


def fenetres(h, n=6):
    h = h.upper()
    return {h[i:i + n] for i in range(len(h) - n + 1)}


def fenetres_libres(h, garde, n=6):
    """Les fenetres qui depassent le prefixe garde (le prefixe garde est public ou structurel)."""
    h = h.upper()
    return {h[i:i + n] for i in range(len(h) - n + 1) if i + n > garde}


def triviale(f):
    """Fenetre pauvre : deux caracteres distincts au plus, ou un caractere repete quatre fois."""
    return len(set(f)) <= 2 or max(f.count(c) for c in set(f)) >= 4


def memes_lettres(gr, gn):
    """Une ecriture qui a des lettres garde des lettres (sinon MAJ et min se confondraient)."""
    return all(a_des_lettres(seq(gr[i:j])) <= a_des_lettres(seq(gn[i:j]))
               for i in range(len(gr)) for j in range(i + 1, len(gr) + 1))


def a_des_lettres(s):
    return any(c in 'ABCDEFabcdef' for c in s)


def prefixe_garde(h):
    """Ce qu'on garde d'un identifiant hexa : ses zeros de tete et les deux chiffres qui suivent. L'ordre
    lexical entre valeurs de natures differentes (ExtMac, MAC, noeud...) en depend dans les listes triees."""
    i = 0
    while i < len(h) - 2 and h[i] == '0':
        i += 1
    return h[:i + 2]


# --- la table --------------------------------------------------------------------------------

class Valeur:
    def __init__(self, nature, reel):
        self.nature, self.reel = nature, reel
        self.nouveau = None
        self.depots = set()
        self.derivee = ''
        self.garde = ''
        self.formes = []   # [classe, reel, nouveau, etiquette, depots ou None]
        self.octets = []   # [reel hex, nouveau hex, mode, depots ou None]

    def forme(self, classe, reel, nouveau, etiquette, depots=None):
        if reel and reel != nouveau:
            self.formes.append([classe, reel, nouveau, etiquette, sorted(depots) if depots else None])

    def forme_casse(self, classe, reel, nouveau, etiquette, depots=None):
        """L'ecriture en majuscules, et en minuscules si la valeur reelle a des lettres."""
        self.forme(classe, reel.upper(), nouveau.upper(), etiquette + ', MAJ', depots)
        if reel.lower() != reel.upper():
            self.forme(classe, reel.lower(), nouveau.lower(), etiquette + ', min', depots)

    def octet(self, reel, nouveau, mode='partout', depots=None):
        self.octets.append([reel.upper(), nouveau.upper(), mode, sorted(depots) if depots else None])

    def json(self):
        return {'nature': self.nature, 'reel': self.reel, 'nouveau': self.nouveau, 'depots': sorted(self.depots),
                'derivee': self.derivee, 'garde': self.garde, 'formes': self.formes, 'octets': self.octets}


class Generateur:
    def __init__(self, graine, corpus, noms_reels, decisions, courriel_nouveau, zone_systeme):
        self.rng = random.Random(graine)
        self.graine = graine
        self.corpus = corpus                  # {depot: Historique}
        self.noms_reels = noms_reels          # {nom: set(cles)}
        self.decisions = decisions
        self.courriel_nouveau = courriel_nouveau
        self.zone_systeme = zone_systeme
        self.valeurs = {}                     # (nature, reel) -> Valeur
        self.textes = {d: '\0'.join(t for _, t in h.textes()) for d, h in corpus.items()}
        self.textes_min = {d: t.lower() for d, t in self.textes.items()}
        self.runs = {d: list(re.finditer(commun.RUN, t)) for d, t in self.textes.items()}
        self.nouveaux_vus = set()
        self._presences = {}
        self.fenetres_reelles = set()
        self.journal = []

    # -- valeurs ------------------------------------------------------------------------------
    def valeur(self, nature, reel):
        cle = (nature, reel)
        if cle not in self.valeurs:
            self.valeurs[cle] = Valeur(nature, reel)
        return self.valeurs[cle]

    def presente(self, depot, *formes):
        cle = (depot,) + formes
        if cle not in self._presences:
            t = self.textes[depot]
            self._presences[cle] = any(f and f in t for f in formes)
        return self._presences[cle]

    def depots_de(self, *formes):
        return {d for d in self.corpus if self.presente(d, *formes)}

    def unique(self, nouveau):
        if nouveau in self.nouveaux_vus:
            return False
        self.nouveaux_vus.add(nouveau)
        return True

    # -- tirages ------------------------------------------------------------------------------
    def tirer_ordonne(self, reels, longueur, contrainte, fixes=None, garde=prefixe_garde):
        """Remplacantes hexa de meme longueur, dans le meme ordre que les valeurs reelles.

        garde(reel) -> prefixe garde ; contrainte(reel, candidat) -> bool ; fixes : {reel: nouveau}.
        """
        fixes = fixes or {}
        ordre = sorted(set(reels) | set(fixes), key=lambda h: int(h, 16))
        res, cur = {}, -1
        for i, r in enumerate(ordre):
            if r in fixes:
                n = int(fixes[r], 16)
                if n <= cur:
                    raise Echec('ordre impossible autour d\'une valeur derivee')
                res[r], cur = fixes[r], n
                continue
            g = garde(r)
            base = int(g.ljust(longueur, '0'), 16)
            haut = int(g.ljust(longueur, 'F'), 16) + 1
            prochain = next((int(fixes[x], 16) for x in ordre[i + 1:] if x in fixes), 1 << (4 * longueur))
            restants = 1
            for x in ordre[i + 1:]:
                if x in fixes or garde(x) != g:
                    break
                restants += 1
            lo, hi = max(base, cur + 1), min(haut, prochain)
            if lo >= hi:
                raise Echec('plus de place pour garder l\'ordre')
            pas = max(1, (hi - lo) // restants)
            for essai in range(20000):
                fen_hi = lo + pas if essai < 10000 else hi
                v = self.rng.randrange(lo, max(lo + 1, fen_hi))
                c = '%0*X' % (longueur, v)
                if c != r and c not in self.nouveaux_vus and not (fenetres_libres(c, len(g)) & self.fenetres_reelles) \
                        and (a_des_lettres(c) or not a_des_lettres(r)) and contrainte(r, c):
                    break
            else:
                raise Echec('aucun tirage ne convient (longueur %d, prefixe garde de %d chiffres, contrainte %s)' % (
                    longueur, len(g), contrainte.__qualname__.split('.')[1]))
            self.nouveaux_vus.add(c)
            res[r], cur = c, v
        return res

    def tirer_par_groupes(self, reels, k=4):
        """Remplacantes de k groupes de 16 bits : chaque groupe garde son nombre de chiffres et ses
        lettres, et l'ordre des valeurs est garde, groupe par groupe, du plus fort au plus faible."""
        def classe(g):
            n = chiffres(g)
            return (0, 1) if n == 0 else (16 ** (n - 1), 16 ** n)

        def tirer_niveau(tuples, i):
            if i == k:
                return {t: () for t in tuples}
            distincts = sorted({t[i] for t in tuples})
            neufs = {}
            par_classe = {}
            for g in distincts:
                par_classe.setdefault((classe(g), a_des_lettres('%x' % g)), []).append(g)
            for ((lo, hi), lettres), gs in sorted(par_classe.items()):
                tires = set()
                while len(tires) < len(gs):
                    c = self.rng.randrange(lo, hi)
                    if c == 0 or not lettres or a_des_lettres('%x' % c):
                        tires.add(c)
                for g, c in zip(gs, sorted(tires)):
                    neufs[g] = c
            # deux groupes de meme plage, l'un avec lettres et l'autre sans, peuvent s'entrelacer : on refait
            suite = [neufs[g] for g in distincts]
            if any(a >= b for a, b in zip(suite, suite[1:])):
                return None
            res = {}
            for g in distincts:
                sous = [t for t in tuples if t[i] == g]
                suite = tirer_niveau(sous, i + 1)
                if suite is None:
                    return None
                for t in sous:
                    res[t] = (neufs[g],) + suite[t]
            return res

        for _ in range(1000):
            tuples = {r: tuple(groupes(int(r, 16), k)) for r in reels}
            m = tirer_niveau(list(tuples.values()), 0)
            if m is None:
                continue
            res = {r: ''.join('%04X' % g for g in m[t]) for r, t in tuples.items()}
            if len(set(res.values())) < len(res) or \
                    any(c in self.nouveaux_vus or fenetres(c) & self.fenetres_reelles for c in res.values()):
                continue
            self.nouveaux_vus |= set(res.values())
            return res
        raise Echec('aucun tirage par groupes ne convient')

    # -- generation ---------------------------------------------------------------------------
    def generer(self, entrees):
        """entrees : [(nature, valeur, depot)] tirees des inventaires."""
        par = {}
        for nature, v, d in entrees:
            par.setdefault(nature, {}).setdefault(v, set()).add(d)
        self.par = par
        # fenetres de toutes les valeurs reelles hexa (pour qu'aucune remplacante n'en contienne)
        for nature in ('hote16', 'hote12', 'mac', 'fabrique', 'noeud', 'agent', 'xp', 'at', 'partition',
                       'empreinte'):
            for h in par.get(nature, {}):
                self.fenetres_reelles |= {f for f in fenetres(h) if not triviale(f)}
        for nature in ('adresse', 'prefixe48'):
            for a in par.get(nature, {}):
                h = '%032X' % int(ipaddress.IPv6Address(a))
                self.fenetres_reelles |= {f for f in fenetres(h) if not triviale(f)}
        self.gen_macs()
        self.gen_hotes16()
        self.gen_simples('fabrique', 16)
        self.gen_simples('noeud', 16)
        self.gen_simples('agent', 32)
        self.gen_empreintes()
        self.gen_xp()
        self.gen_partitions()
        self.gen_at()
        self.gen_prefixes()
        self.gen_adresses()
        self.gen_nom_reseau()
        self.gen_ipv4()
        self.gen_meshcop()
        self.gen_noms()
        self.gen_identite()
        self.gen_serie()
        self.presences()
        self.gen_fragments()
        self.verifier_instances()

    def depots_valeur(self, nature, v):
        return self.par.get(nature, {}).get(v, set())

    # MAC : OUI garde, partie propre tiree au sort ; ecritures EUI-64 ; hote MAC+0000.
    def gen_macs(self):
        macs = sorted(set(self.par.get('mac', {})) | set(self.par.get('hote12', {})))

        def contrainte(r, c):
            return chiffres(int(c[8:12], 16)) == chiffres(int(r[8:12], 16)) and memes_lettres(eui64(r), eui64(c))

        nouveaux = self.tirer_ordonne(macs, 12, contrainte, garde=lambda h: h[:6])
        for r in macs:
            nature = 'mac' if r in self.par.get('mac', {}) else 'hote12'
            v = self.valeur(nature, r)
            v.nouveau, v.garde = nouveaux[r], r[:6]
            v.depots = self.depots_valeur(nature, r)
            self.formes_hex(v, separateurs=True)
            if nature == 'mac':
                ri, ni = eui64(r), eui64(v.nouveau)
                self.formes_groupes(v, ri, ni, 'IID EUI-64')
                for d in (':', '-', ''):
                    v.forme_casse('hexa', sep(r[:10], d), sep(v.nouveau[:10], d), 'MAC tronquee a 5 octets')
                eu_r, eu_n = r[:6] + 'FFFE' + r[6:8], v.nouveau[:6] + 'FFFE' + v.nouveau[6:8]
                v.forme_casse('hexa', eu_r, eu_n, 'EUI-64 tronque a 6 octets')

    # Identifiants de 16 chiffres : ExtMac, xa, noms d'hote ; MAC+0000 derive de sa MAC.
    def gen_hotes16(self):
        hotes = sorted(self.par.get('hote16', {}))
        fixes = {}
        for h in hotes:
            mac = self.valeurs.get(('mac', h[:12]))
            if mac and h.endswith('0000'):
                fixes[h] = mac.nouveau + '0000'

        def contrainte(r, c):
            if (int(c[1], 16) & 3) != (int(r[1], 16) & 3):
                return False
            gr, gc = groupes(int(r, 16), 4), groupes(int(c, 16), 4)
            fr, fc = groupes(int(r, 16) ^ (2 << 56), 4), groupes(int(c, 16) ^ (2 << 56), 4)
            return [chiffres(g) for g in gr] == [chiffres(g) for g in gc] and \
                [chiffres(g) for g in fr] == [chiffres(g) for g in fc] and memes_lettres(gr, gc) and memes_lettres(fr, fc)

        nouveaux = self.tirer_ordonne([h for h in hotes if h not in fixes], 16, contrainte, fixes=fixes)
        for h in hotes:
            v = self.valeur('hote16', h)
            v.nouveau, v.garde = nouveaux[h], prefixe_garde(h)
            v.depots = self.depots_valeur('hote16', h)
            if h in fixes:
                v.derivee = 'MAC + 0000'
                v.garde = h[:6]
            self.formes_hex(v)
            n_r, n_n = int(h, 16), int(v.nouveau, 16)
            self.formes_groupes(v, groupes(n_r, 4), groupes(n_n, 4), 'IID egal a l\'ExtMac')
            self.formes_groupes(v, groupes(n_r ^ (2 << 56), 4), groupes(n_n ^ (2 << 56), 4), 'IID lien-local')

    def gen_simples(self, nature, longueur):
        reels = sorted(self.par.get(nature, {}))
        nouveaux = self.tirer_ordonne(reels, longueur, lambda r, c: True)
        for r in reels:
            v = self.valeur(nature, r)
            v.nouveau, v.garde = nouveaux[r], prefixe_garde(r)
            v.depots = self.depots_valeur(nature, r)
            self.formes_hex(v)

    def gen_empreintes(self):
        reels = sorted(self.par.get('empreinte', {}))
        for r in reels:
            v = self.valeur('empreinte', r)
            while True:
                c = ''.join(self.rng.choice(HEX) for _ in range(8))
                if a_des_lettres(c) and not (fenetres(c) & self.fenetres_reelles) and self.unique(c):
                    break
            v.nouveau, v.depots = c, self.depots_valeur('empreinte', r)
            v.forme_casse('hexa', r, c, 'hexa')

    # xp : tire au sort ; le prefixe du lien d'infrastructure en derive (gen_prefixes).
    def gen_xp(self):
        for r in sorted(self.par.get('xp', {})):
            def contrainte(r, c):
                return [chiffres(g) for g in groupes(int(infra(r), 16), 4)] == \
                    [chiffres(g) for g in groupes(int(infra(c), 16), 4)]
            n = self.tirer_ordonne([r], 16, contrainte)[r]
            v = self.valeur('xp', r)
            v.nouveau, v.garde, v.depots = n, prefixe_garde(r), self.depots_valeur('xp', r)
            self.formes_hex(v)

    # Partitions : une partition ecrite a l'envers est derivee de l'autre ; celles qui paraissent
    # en octets bruts (TXT pt) restent des caracteres imprimables.
    def gen_partitions(self):
        reels = sorted(self.par.get('partition', {}))
        inverses = {r: r2 for r in reels for r2 in reels if r2 != r and octets_hex(r2) == octets_hex(r)[::-1]}
        primaires = [r for r in reels if not (r in inverses and inverses[r] < r)]

        def ascii_vu(h):
            s = octets_hex(h).decode('latin-1')
            return s.isprintable() and any(self.presente(d, '"%s"' % s, '"%s"' % s[::-1]) for d in self.corpus)

        def contrainte(r, c):
            if ascii_vu(r):
                s = octets_hex(c).decode('latin-1')
                if not all(ch.isalnum() and ord(ch) < 128 for ch in s):
                    return False
                if r in inverses and c[6] != r[6]:
                    return False
            return True

        # une partition ne garde que son premier chiffre ; celle ecrite a l'envers garde donc le 7e de l'autre
        nouveaux = self.tirer_ordonne(primaires, 8, contrainte, garde=lambda h: h[:1])
        for r in reels:
            v = self.valeur('partition', r)
            v.depots = self.depots_valeur('partition', r)
            if r in nouveaux:
                v.nouveau, v.garde = nouveaux[r], r[:1]
            else:
                v.nouveau = octets_hex(nouveaux[inverses[r]])[::-1].hex().upper()
                v.derivee, v.garde = 'partition a l\'envers', r[:1]
                self.nouveaux_vus.add(v.nouveau)
            self.formes_hex(v)
            if ascii_vu(r):
                s_r, s_n = octets_hex(r).decode('latin-1'), octets_hex(v.nouveau).decode('latin-1')
                v.forme('brut', '"%s"' % s_r, '"%s"' % s_n, 'octets bruts en ASCII (TXT pt)')
        rs = sorted(reels)
        if sorted(rs, key=lambda x: self.valeurs[('partition', x)].nouveau) != rs:
            raise Echec('ordre des partitions perdu')

    # Horodatage actif du dataset : secondes tirees au sort ; dates et entiers derives.
    def gen_at(self):
        for r in sorted(self.par.get('at', {})):
            v = self.valeur('at', r)
            s_r = int(r[4:12], 16)
            debut = int(datetime.datetime(2023, 1, 1, tzinfo=datetime.timezone.utc).timestamp())
            fin = int(datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc).timestamp())
            while True:
                s = self.rng.randrange(debut, fin)
                if 600 < s % 86400 < 86400 - 600:
                    n = r[:4] + '%08X' % s + r[12:]
                    if (a_des_lettres(n) or not a_des_lettres(r)) and not (fenetres(n) & self.fenetres_reelles) \
                            and self.unique(n):
                        break
            v.nouveau, v.garde, v.depots = n, r[:4], self.depots_valeur('at', r)
            self.formes_hex(v)
            for sr, sn, quoi in ((s_r, s, 'secondes'), (s_r & ~0xFF, s & ~0xFF, 'secondes, octet bas a zero')):
                v.forme('nombre', str(sr), str(sn), quoi + ' en decimal')
                v.forme('nombre', '{:_}'.format(sr), '{:_}'.format(sn), quoi + ' en decimal groupe')
                v.forme('nombre', iso(sr), iso(sn), quoi + ' en date ISO')
            v.forme('nombre', iso(s_r)[:10], iso(s)[:10], 'date du jeu actif')
            v.octet(r[:10], n[:10], 'debut')

    # Prefixes ULA : fd puis 40 bits tires au sort, dans l'ordre ; le prefixe du lien
    # d'infrastructure est derive du xp ; un sous-reseau autre que 0 ou 1 est tire au sort.
    def gen_prefixes(self):
        p48 = set()
        for nature in ('prefixe48', 'adresse'):
            for a in self.par.get(nature, {}):
                n = int(ipaddress.IPv6Address(a))
                if n >> 120 == 0xFD:
                    p48.add(n >> 80)
        for e in self.par.get('prefixe64', {}):
            p48.add(int(ipaddress.IPv6Address(e)) >> 80)
        fixes = {}
        for xp in self.par.get('xp', {}):
            ri, ni = int(infra(xp), 16), int(infra(self.valeurs[('xp', xp)].nouveau), 16)
            fixes['%012X' % (ri >> 16)] = '%012X' % (ni >> 16)
        libres = sorted('%012X' % p for p in p48 if '%012X' % p not in fixes)

        idents = set()
        for t in self.textes.values():
            idents |= {x.lower() for x in re.findall(r'(?<![0-9A-Za-z_])[fF][dD][0-9A-Fa-f]{2}(?![0-9A-Za-z_])', t)}
        premiers = {('%012X' % int(n, 16))[:4].lower() for n in fixes.values()}

        def contrainte(r, c):
            if c[:4].lower() in idents or c[:4].lower() in premiers:
                return False
            gr, gc = groupes(int(r, 16), 3), groupes(int(c, 16), 3)
            if [chiffres(g) for g in gr] != [chiffres(g) for g in gc] or not memes_lettres(gr, gc):
                return False
            premiers.add(c[:4].lower())
            return True

        nouveaux = self.tirer_ordonne(libres, 12, contrainte, fixes=fixes, garde=lambda h: h[:2])
        self.p48 = {int(r, 16): int(n, 16) for r, n in nouveaux.items()}
        for r, n in sorted(nouveaux.items()):
            v = self.valeur('prefixe48', r)
            v.nouveau, v.garde = n, 'FD'
            v.depots = self.depots_de(seq(groupes(int(r, 16), 3)), seq(groupes(int(r, 16), 3), True))
            if r in fixes:
                v.derivee = 'prefixe du lien d\'infrastructure, tire du xp'
            gr, gn = groupes(int(r, 16), 3), groupes(int(n, 16), 3)
            self.formes_groupes(v, gr, gn, 'prefixe /48')
            v.forme('brut', r, n, '/48 en hexa contigu MAJ')
            v.forme('brut', r.lower(), n.lower(), '/48 en hexa contigu min')
            v.octet(r, n)
            v.forme('ident', '%04x' % gr[0], '%04x' % gn[0], 'premier groupe seul (nom de variable, libelle)')
            v.forme('ident', '%04X' % gr[0], '%04X' % gn[0], 'premier groupe seul, MAJ')
        # sous-reseaux
        self.sous_reseaux = {}
        for xp in self.par.get('xp', {}):
            ri, ni = int(infra(xp), 16), int(infra(self.valeurs[('xp', xp)].nouveau), 16)
            self.sous_reseaux[(ri >> 16, ri & 0xFFFF)] = ni & 0xFFFF
        a_tirer = set()
        for nature in ('adresse', 'prefixe64'):
            for a in self.par.get(nature, {}):
                n = int(ipaddress.IPv6Address(a))
                p, s = n >> 80, (n >> 64) & 0xFFFF
                if n >> 120 == 0xFD and s > 1 and (p, s) not in self.sous_reseaux:
                    a_tirer.add((p, s))
        for p, s in sorted(a_tirer):
            while True:
                c = self.rng.randrange(16 ** (chiffres(s) - 1) if chiffres(s) > 1 else 1, 16 ** chiffres(s))
                if chiffres(c) == chiffres(s) and c != s:
                    break
            self.sous_reseaux[(p, s)] = c
        for (p, s), c in sorted(self.sous_reseaux.items()):
            rp, np_ = (p << 16) | s, (self.p48.get(p, p) << 16) | c
            v = self.valeur('prefixe64', '%016X' % rp)
            v.nouveau = '%016X' % np_
            v.garde = 'FD'
            v.derivee = 'sous-reseau du lien d\'infrastructure, tire du xp' if (p, s) in self._infra_cles() else ''
            gr, gn = groupes(rp, 4), groupes(np_, 4)
            v.depots = self.depots_de(seq(gr), seq(gr, True), '%016X' % rp)
            self.formes_groupes(v, gr, gn, 'prefixe /64')
            v.forme('brut', '%016X' % rp, '%016X' % np_, '/64 en hexa contigu MAJ')
            v.forme('brut', '%016x' % rp, '%016x' % np_, '/64 en hexa contigu min')
            v.octet('%016X' % rp, '%016X' % np_)
            # le sous-reseau reel garde par l'anonymiseur de la sonde derriere ses /48 factices
            for f in FACTICES_SONDE:
                fg = [int(x, 16) for x in f.split(':')]
                self.formes_groupes(v, fg + [s], fg + [c], 'sous-reseau reel derriere un /48 factice de la sonde')
                fh = ''.join('%04X' % x for x in fg)
                v.forme('brut', fh + '%04X' % s, fh + '%04X' % c, 'idem, hexa contigu MAJ')
                v.octet(fh + '%04X' % s, fh + '%04X' % c)
                v.forme('brut', (fh + '%04X' % s).lower(), (fh + '%04X' % c).lower(), 'idem, hexa contigu min')

    def _infra_cles(self):
        return {(int(infra(x), 16) >> 16, int(infra(x), 16) & 0xFFFF) for x in self.par.get('xp', {})}

    # Adresses : chaque IID reel tire au sort, dans l'ordre de tous les IID, sauf ceux qui derivent
    # d'une MAC (EUI-64), d'une ExtMac, ou qui logent un /48, et les IID de structure (::1).
    def gen_adresses(self):
        macs = {eui64_int(m): m for m in self.par.get('mac', {})}
        hotes = {int(h, 16): h for h in self.par.get('hote16', {})}
        hotes_ll = {int(h, 16) ^ (2 << 56): h for h in self.par.get('hote16', {})}
        p48 = set(self.p48)
        par64 = {}
        for a in self.par.get('adresse', {}):
            n = int(ipaddress.IPv6Address(a))
            iid = n & ((1 << 64) - 1)
            if iid in macs or iid in hotes or iid in hotes_ll or (iid >> 48 < 0x100 and (iid & ((1 << 48) - 1)) in p48):
                continue
            if iid < 0x10000:
                continue
            par64.setdefault(0, set()).add('%016X' % iid)
        for p64, iids in sorted(par64.items()):
            nouveaux = self.tirer_par_groupes(sorted(iids))
            for r, c in nouveaux.items():
                v = self.valeur('iid', r)
                v.nouveau = c
                gr, gn = groupes(int(r, 16), 4), groupes(int(c, 16), 4)
                v.depots = self.depots_de(seq(gr), seq(gr, True))
                self.formes_groupes(v, gr, gn, 'IID')
                self.formes_groupes(v, gr[:3], gn[:3], 'trois premiers groupes de l\'IID')
                v.forme_casse('brut', r, c, 'IID en hexa contigu')
                v.octet(r, c)

    def gen_nom_reseau(self):
        for r in sorted(self.par.get('nom_reseau', {})):
            m = re.fullmatch(r'([A-Za-z]+)(\d{10})', r)
            debut = int(datetime.datetime(2016, 1, 1, tzinfo=datetime.timezone.utc).timestamp())
            fin = int(datetime.datetime(2023, 1, 1, tzinfo=datetime.timezone.utc).timestamp())
            while True:
                t = str(self.rng.randrange(debut, fin))
                if t != m.group(2) and not any(t in self.textes[d] for d in self.textes) and self.unique(t):
                    break
            v = self.valeur('nom_reseau', r)
            v.nouveau, v.depots = m.group(1) + t, self.depots_valeur('nom_reseau', r)
            v.forme('mot', r, v.nouveau, 'nom du reseau')
            v.forme('nombre', m.group(2), t, 'suffixe du nom du reseau (horodatage)')

    def gen_ipv4(self):
        reels = sorted(self.par.get('ipv4', {}), key=lambda a: int(ipaddress.IPv4Address(a)))
        hotes = sorted(self.rng.sample(range(1, 255), len(reels)))
        for r, h in zip(reels, hotes):
            v = self.valeur('ipv4', r)
            v.nouveau, v.depots = '192.0.2.%d' % h, self.depots_valeur('ipv4', r)
            v.forme('ipv4', r, v.nouveau, 'IPv4 en notation pointee')

    # Instances meshcop et noms d'hote lisibles : le nom donne est remplace, le modele du fabricant
    # garde ; un suffixe tire de la fin d'un xa ou d'une MAC est recalcule.
    def gen_meshcop(self):
        noms = sorted(self.par.get('meshcop', {}))
        hotes = sorted(self.par.get('hote_lisible', {}))
        xas = {h[-4:]: h for h in self.par.get('hote16', {})}
        macs = {m[-4:]: m for m in self.par.get('mac', {})}
        generiques = {commun.nfc(g).casefold() for g in self.decisions['generiques']}
        a_choisir = {}
        for nom in noms:
            v = self.valeur('meshcop', nom)
            v.depots = self.depots_valeur('meshcop', nom)
            modele = next((m for m in self.decisions['modeles'] if nom == m or nom.startswith(m + ' ')), '')
            reste = nom[len(modele):]
            m = re.fullmatch(r'([ #]+)([0-9A-F]{4})', reste)
            if m and m.group(2) in xas:
                xa = self.valeurs[('hote16', xas[m.group(2)])]
                v.nouveau, v.derivee = modele + m.group(1) + xa.nouveau[-4:], 'fin du xa'
                self.formes_nom(v, v.reel, v.nouveau)
            elif not reste.strip():
                v.nouveau, v.derivee = nom, 'modele du fabricant, garde'
                continue
            elif commun.nfc(reste[1:]).casefold() in generiques:
                v.nouveau, v.derivee = nom, 'modele du fabricant et mot courant de piece, gardes'
                continue
            else:
                a_choisir.setdefault(modele, []).append((reste[1:], v))
        for modele, liste in sorted(a_choisir.items()):
            choix = self.choisir_qualifs(modele, [q for q, _ in liste])
            for qual, v in liste:
                v.nouveau = modele + ' ' + choix[qual]
                self.formes_nom(v, v.reel, v.nouveau)
                # le qualificatif en minuscules ou en capitale, comme dans des cas de test
                for f in (str.lower, str.capitalize):
                    qr, qn = f(qual), f(choix[qual])
                    if modele + ' ' + qr != v.reel and any(modele + ' ' + qr in t for t in self.textes.values()):
                        v.forme('mot', modele + ' ' + qr, modele + ' ' + qn, 'qualificatif en autre casse')
        par_tirets = {n.replace(' ', '-'): self.valeurs[('meshcop', n)] for n in noms}
        for h in hotes:
            v = self.valeur('hote_lisible', h)
            v.depots = self.depots_valeur('hote_lisible', h)
            m = re.fullmatch(r'(.*-)([0-9A-F]{4})', h)
            if h in par_tirets:
                v.nouveau = par_tirets[h].nouveau.replace(' ', '-')
                v.derivee = 'nom de son instance meshcop, espaces en tirets'
            elif m and m.group(2) in macs:
                v.nouveau = m.group(1) + self.valeurs[('mac', macs[m.group(2)])].nouveau[-4:]
                v.derivee = 'fin de la MAC'
            else:
                raise Echec('nom d\'hote lisible sans origine connue')
            if v.nouveau == h:
                continue
            v.forme('mot', h, v.nouveau, 'nom d\'hote')
            v.forme('mot', h.lower(), v.nouveau.lower(), 'nom d\'hote en minuscules')

    def choisir_qualifs(self, modele, quals):
        """Qualificatifs inventes pour un modele : dans l'ordre des reels, de meme longueur si possible."""
        res, prec, pris = {}, '', set()
        reste = sorted(quals)
        for i, q in enumerate(reste):
            def forme(c):
                return c[:1].upper() + c[1:] if q[:1].isupper() else c
            valides = []
            for c in sorted({x.lower() for x in QUALIFS}):
                f = forme(c)
                if f > prec and c != q.lower() and c not in pris and not self.nom_reel_dans(c) \
                        and self.nom_libre(modele + ' ' + f) and self.nom_libre(modele + '-' + f.replace(' ', '-')):
                    valides.append(f)
            if not valides:
                raise Echec('aucun qualificatif invente ne convient')
            exacts = [c for c in valides if len(c) == len(q)]
            pool = exacts or sorted(valides, key=lambda c: (abs(len(c) - len(q)), c))[:3]
            pool = sorted(pool)[:max(1, len(pool) // (len(reste) - i))]
            c = pool[self.rng.randrange(len(pool))]
            res[q], prec = c, c
            pris.add(c.lower())
        return res

    def reels_noms(self):
        return [r for r, cles in self.noms_reels.items() if cles & CLES_NOMS]

    def nom_reel_dans(self, nom):
        n = nom.lower()
        return any(n == r.lower() or re.search(r'(?<![\w])' + re.escape(r.lower()) + r'(?![\w])', n)
                   for r in self.reels_noms())

    def nom_libre(self, nom):
        """Ni dans noms.json, ni dans l'historique, ni contenant un nom reel en mot entier."""
        if self.nom_reel_dans(nom):
            return False
        n = nom.lower()
        return not any(n in t for t in self.textes_min.values()) and \
            not any(commun.echappe_json(n) in t for t in self.textes_min.values())

    # Noms reels de noms.json : remplaces selon leur portee (plusieurs mots : partout, en entier ;
    # un seul mot : garde, comme les mots courants de piece), sauf decision contraire.
    def gen_noms(self):
        trouves = {}
        for nom in sorted(self.noms_reels):
            if not (self.noms_reels[nom] & CLES_NOMS):
                continue
            ds = {d for d in self.corpus if nom in self.textes[d]}
            if ds:
                trouves[nom] = ds
        generiques = {commun.nfc(g).casefold() for g in self.decisions['generiques']}
        self.portees = {}
        for nom, ds in trouves.items():
            if commun.nfc(nom).casefold() in generiques:
                self.portees[nom] = ('garde', 'mot courant de piece')
            elif nom in self.decisions.get('remplacer', []):
                self.portees[nom] = ('phrase', 'decision')
            elif nom in self.decisions.get('garder', []):
                self.portees[nom] = ('garde', 'decision')
            elif len(nom.split()) == 1:
                self.portees[nom] = ('garde', 'un seul mot : mot courant, identifiant de code ou nom de produit')
            elif any(m in nom.split() for m in self.decisions['marques']):
                self.portees[nom] = ('garde', 'nom de produit (marque et modele)')
            else:
                self.portees[nom] = ('phrase', 'nom de plusieurs mots')
        a_remplacer = sorted(n for n in trouves if self.portees[n][0] == 'phrase')
        prec = ''
        for i, nom in enumerate(a_remplacer):
            v = self.valeur('nom', nom)
            v.depots = trouves[nom]
            v.nouveau = self.inventer_nom(nom, prec, len(a_remplacer) - i)
            prec = v.nouveau
            self.formes_nom(v, nom, v.nouveau)

    def inventer_nom(self, nom, prec='', restants=1):
        """Un nom d'appareil plausible : meme genre d'appareil, meme premiere lettre et meme longueur si
        possible, apres le nom invente precedent (l'ordre des noms reels est garde), ni reel ni deja dans
        l'historique."""
        n = len(nom)
        appareils = next((liste for mot, liste in self.decisions['genres'] if re.search(r'\b' + mot + r'\b', nom)),
                         APPAREILS)
        cands = set(appareils)
        for a in appareils:
            for l in LIEUX:
                cands.add(a + ' ' + l)
                for c in COTES:
                    cands.add(a + ' ' + l + ' ' + c)
            for c in COTES:
                cands.add(a + ' ' + c)
        cands = sorted(c for c in cands if len(c.split()) == len(set(c.split())) and c > prec)
        paliers = [[c for c in cands if c[0] == nom[0] and len(c) == n],
                   sorted((c for c in cands if c[0] == nom[0]), key=lambda c: (abs(len(c) - n), c))[:20],
                   [c for c in cands if len(c) == n],
                   sorted(cands, key=lambda c: (abs(len(c) - n), c))[:20]]
        for palier in paliers:
            valides = [c for c in sorted(palier) if c.lower() != nom.lower() and self.nom_libre(c)
                       and 'nom:' + c.lower() not in self.nouveaux_vus]
            if valides:
                pool = valides[:max(1, len(valides) // restants)]
                c = pool[self.rng.randrange(len(pool))]
                self.nouveaux_vus.add('nom:' + c.lower())
                return c
        raise Echec('aucun nom invente ne convient')

    def formes_nom(self, v, r, n):
        vus = set()
        for rr, nn, quoi in ((r, n, 'texte exact'),
                             (unicodedata.normalize('NFD', r), unicodedata.normalize('NFD', n), 'NFD'),
                             (commun.echappe_json(r), commun.echappe_json(n), 'echappe JSON'),
                             (commun.echappe_json(r, True), commun.echappe_json(n, True), 'echappe JSON MAJ'),
                             (r.replace(' ', '-'), n.replace(' ', '-'), 'espaces en tirets'),
                             (r.replace("'", "\\'"), n.replace("'", "\\'"), 'apostrophe echappee'),
                             (r.replace("'", '’'), n.replace("'", '’'), 'apostrophe typographique')):
            if rr not in vus and rr != nn and (quoi == 'texte exact' or any(rr in t for t in self.textes.values())):
                vus.add(rr)
                v.forme('mot', rr, nn, quoi)

    def gen_identite(self):
        for r in sorted(self.par.get('courriel', {})):
            v = self.valeur('courriel', r)
            v.nouveau, v.depots = self.courriel_nouveau, set(self.corpus)
            v.forme('brut', r, v.nouveau, 'adresse electronique')
        for r in sorted(self.par.get('prenom', {})):
            v = self.valeur('prenom', r)
            v.nouveau, v.depots = PRENOM_NOUVEAU, self.depots_valeur('prenom', r)
            for f in (str.capitalize, str.upper, str.lower):
                v.forme('brut', f(r), f(PRENOM_NOUVEAU), 'prenom, toute casse')
        for r in sorted(self.par.get('fuseau', {})):
            v = self.valeur('fuseau', r)
            m = re.fullmatch(r'(?:UTC|GMT)([+-]\d{1,2})', r)
            if not m:
                raise Echec('etiquette de fuseau illisible')
            cands = zones_au_decalage(int(m.group(1)), self.zone_systeme)
            v.nouveau = cands[self.rng.randrange(len(cands))]
            v.depots = self.depots_valeur('fuseau', r)
            v.forme('nombre', r, v.nouveau, 'etiquette du fuseau des tests')

    def gen_serie(self):
        for r in sorted(self.par.get('serie', {})):
            while True:
                c = ''.join(self.rng.choice('0123456789') if ch.isdigit() else
                            self.rng.choice('ABCDEFGHJKLMNPQRSTUVWXYZ') if ch.isalpha() else ch for ch in r)
                if c != r and not any(c in t for t in self.textes.values()) and self.unique(c):
                    break
            v = self.valeur('serie', r)
            v.nouveau, v.depots = c, self.depots_valeur('serie', r)
            v.forme_casse('brut', r, c, 'numero de serie')

    def presences(self):
        """Ou parait chaque valeur ; une valeur absente des deux historiques n'a pas d'ecriture a
        remplacer (elle reste dans la table pour le balayage) ; une ecriture commune a deux valeurs
        n'est gardee que si elle est absente des historiques."""
        par_forme = {}
        for v in self.valeurs.values():
            for f in v.formes:
                par_forme.setdefault((f[0], f[1]), []).append(v)
        vus = {d: set() for d in self.textes}
        for classe in commun.CLASSES:
            formes = {r for (c, r) in par_forme if c == classe}
            if formes:
                g, dr = commun.BORNES[classe]
                rx = re.compile(g + '(?:' + commun.motif_trie(formes) + ')' + dr)
                for d, t in self.textes.items():
                    vus[d] |= {(classe, m.group(0)) for m in rx.finditer(t)}
        ambigues = {k for k, vals in par_forme.items()
                    if len({f[2] for v in vals for f in v.formes if (f[0], f[1]) == k}) > 1}
        for v in self.valeurs.values():
            v.depots = {d for d in self.textes
                        if any((f[0], f[1]) in vus[d] and (f[0], f[1]) not in ambigues for f in v.formes)}
            if not v.depots:
                v.formes = []
                v.octets = []
        for (c, r), vals in par_forme.items():
            restants = [v for v in vals if any(f[0] == c and f[1] == r for f in v.formes)]
            if len({f[2] for v in restants for f in v.formes if f[0] == c and f[1] == r}) > 1:
                if any((c, r) in vus[d] for d in vus):
                    raise Echec('une ecriture presente dans l\'historique appartient a deux valeurs (%s)' % c)
                for v in restants:
                    v.formes = [f for f in v.formes if not (f[0] == c and f[1] == r)]
                self.journal.append('ecriture commune a deux valeurs, absente des historiques : retiree')

    def gen_fragments(self):
        """Les fragments qui restent seuls une fois les ecritures longues remplacees : debuts et fins
        d'une valeur hexa, debuts de ses suites d'octets, la ou ils paraissent dans un depot ou la valeur
        parait."""
        regles = [(c, r, n) for v in self.valeurs.values() for c, r, n, _, _ in v.formes]
        octets = [(octets_hex(r), octets_hex(n), m) for v in self.valeurs.values() for r, n, m, _ in v.octets]
        moteur = commun.Moteur(regles, octets)
        restes = {d: moteur.appliquer(t) for d, t in self.textes.items()}
        cands = {}
        for v in list(self.valeurs.values()):
            if v.nature not in ('hote16', 'mac', 'xp', 'noeud', 'fabrique', 'agent', 'at'):
                continue
            r, n = v.reel, v.nouveau
            longueurs = range(4, len(r))
            for (cote, k), (fr, fn) in sorted({('debut', k): (r[:k], n[:k]) for k in longueurs}.items()) + \
                    sorted({('fin', k): (r[-k:], n[-k:]) for k in longueurs}.items()):
                if fr == fn or (cote == 'debut' and len(fr) <= len(v.garde)) or len(set(fr)) <= 2:
                    continue
                for casse in (str.upper, str.lower):
                    a, b = casse(fr), casse(fn)
                    if casse is str.lower and not a_des_lettres(a):
                        continue
                    cands.setdefault(a, []).append((v, b, 'fragment : %s, %d chiffres' % (cote, k)))
        if cands:
            rx = re.compile('(?<![0-9A-Fa-f])(?:' + commun.motif_trie(cands) + ')(?![0-9A-Fa-f])')
            for d, t in restes.items():
                trouves = {m.group(0) for m in rx.finditer(t)}
                for a in sorted(trouves):
                    if len({b for _, b, _ in cands[a]}) > 1:
                        self.journal.append('fragment ambigu, laisse au balayage : %d chiffres' % len(a))
                        continue
                    for v, b, quoi in cands[a]:
                        if d in v.depots:
                            existant = next((f for f in v.formes if f[0] == 'hexa' and f[1] == a), None)
                            if existant:
                                existant[4] = sorted(set(existant[4] or []) | {d})
                            else:
                                v.forme('hexa', a, b, quoi, {d})
        for v in list(self.valeurs.values()):
            if v.nature not in ('hote16', 'mac', 'xp', 'noeud', 'fabrique', 'agent', 'at'):
                continue
            r, n = v.reel, v.nouveau
            octs = octets_hex(r)
            for k in range(2, len(octs)):
                pre = octs[:k]
                if sum(1 for x in pre if x) < 2:
                    continue
                ds, suites = set(), set()
                for d in v.depots:
                    for m in self.runs[d]:
                        vals = bytes(int(x, 16) for x in commun.JETON_OCTET.findall(m.group(0)))
                        if vals[:k] == pre and vals[:len(octs)] != octs and not any(
                                vals[:j] == octs[:j] for j in range(k + 1, len(octs) + 1)):
                            ds.add(d)
                            suites.add(vals)
                if ds:
                    v.octet(r[:2 * k], n[:2 * k], 'debut', ds)
                    # la meme suite d'octets ecrite en hexa, dans une attente de test par exemple
                    for vals in sorted(suites):
                        ancien, neuf = vals.hex().upper(), n[:2 * k] + vals[k:].hex().upper()
                        if any(re.search('(?<![0-9A-Fa-f])' + ancien + '(?![0-9A-Fa-f])', self.textes[d]) for d in ds):
                            v.forme_casse('hexa', ancien, neuf, 'suite d\'octets commencant par la valeur, en hexa', ds)

    def verifier_instances(self):
        fab = {r: v.nouveau for (nat, r), v in self.valeurs.items() if nat == 'fabrique'}
        noe = {r: v.nouveau for (nat, r), v in self.valeurs.items() if nat == 'noeud'}
        for inst in self.par.get('instance_matter', {}):
            f, n = inst.split('-')
            if f not in fab or n not in noe:
                raise Echec('instance Matter non derivable de sa fabrique et de son noeud')

    # -- ecritures communes -------------------------------------------------------------------
    def formes_hex(self, v, separateurs=False):
        r, n = v.reel, v.nouveau
        classe = 'brut' if len(r) >= 12 or v.nature == 'partition' else 'hexa'
        v.forme(classe, r.upper(), n.upper(), 'hexa contigu MAJ')
        if a_des_lettres(r):
            v.forme(classe, r.lower(), n.lower(), 'hexa contigu min')
        v.octet(r, n)
        if separateurs or len(r) in (12, 16):
            for d in (':', '-', ' '):
                v.forme('hexa', sep(r, d), sep(n, d), 'octets separes par %r, MAJ' % d)
                if a_des_lettres(r):
                    v.forme('hexa', sep(r, d).lower(), sep(n, d).lower(), 'octets separes par %r, min' % d)

    def formes_groupes(self, v, gr, gn, quoi):
        for plein in (False, True):
            a, b = seq(gr, plein), seq(gn, plein)
            if len(gr) >= 3 or plein:
                v.forme('hexa', a, b, quoi + (' (groupes complets)' if plein else ' (groupes abreges)'))
                if a != a.upper():
                    v.forme('hexa', a.upper(), b.upper(), quoi + ', MAJ')
        c_r, c_n = compresse(list(gr)), compresse(list(gn))
        if c_r and c_n:
            v.forme('hexa', c_r, c_n, quoi + ' (abregee avec ::)')

    # -- controles ----------------------------------------------------------------------------
    def controler(self):
        regles, vus_r, vus_n = [], {}, {}
        for v in self.valeurs.values():
            for classe, r, n, quoi, ds in v.formes:
                if v.nature not in LONGUEUR_LIBRE and len(r) != len(n):
                    raise Echec('longueur changee : %s, %s' % (v.nature, quoi))
                if (classe, n) in vus_n and vus_n[(classe, n)] != r:
                    raise Echec('deux valeurs reelles ont la meme remplacante (%s)' % v.nature)
                if (classe, r) in vus_r and vus_r[(classe, r)] != n:
                    raise Echec('une ecriture a deux remplacantes (%s, %s)' % (v.nature, quoi))
                vus_n[(classe, n)], vus_r[(classe, r)] = r, n
                regles.append((classe, r, n, v.nature))
        reels = {r for _, r, _, _ in regles}
        for _, r, n, _ in regles:
            if n in reels and n != r:
                raise Echec('une remplacante est aussi une valeur reelle')
        # aucune remplacante dans l'historique, avec les memes bornes que le retour arriere ; le
        # prenom est l'exception connue : sa remplacante est le pseudonyme, deja public.
        octets = [(octets_hex(n), octets_hex(r), m) for v in self.valeurs.values() for r, n, m, _ in v.octets]
        inverse = commun.Moteur([(c, n, r) for c, r, n, nat in regles if nat not in NON_INVERSIBLES], octets)
        for d, t in self.textes.items():
            m = inverse.rx.search(t) if inverse.rx else None
            while m and m.lastgroup == 'octets' and inverse._octets(m.group(0)) == m.group(0):
                m = inverse.rx.search(t, m.end())
            if m:
                raise Echec('une remplacante parait deja dans l\'historique (%s, classe %s)' % (d, m.lastgroup))
        return [(c, r, n) for c, r, n, _ in regles]

    def noms_pour_balayage(self):
        return {nom: {'portee': p, 'raison': raison} for nom, (p, raison) in sorted(self.portees.items())}


def sep(h, d):
    return d.join(h[i:i + 2] for i in range(0, len(h), 2))


def eui64(mac):
    m = octets_hex(mac)
    return groupes(int.from_bytes(bytes([m[0] ^ 2]) + m[1:3] + b'\xff\xfe' + m[3:], 'big'), 4)


def eui64_int(mac):
    m = octets_hex(mac)
    return int.from_bytes(bytes([m[0] ^ 2]) + m[1:3] + b'\xff\xfe' + m[3:], 'big')


def infra(xp):
    """Prefixe /64 du lien d'infrastructure tire du xp (OpenThread) : fd, octets 0 a 4, octets 6 et 7."""
    b = octets_hex(xp)
    return ('FD' + b[0:5].hex() + b[6:8].hex()).upper()


def iso(s):
    return datetime.datetime.fromtimestamp(s, datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def zones_au_decalage(heures, zone_systeme):
    """Fuseaux reels a ce decalage constant, sans heure d'ete (2015-2030), hors de l'aire du fuseau du Mac."""
    from zoneinfo import ZoneInfo, available_timezones
    aire = (zone_systeme or '').split('/')[0]
    res = []
    for z in sorted(available_timezones()):
        if z.count('/') != 1 or z.split('/')[0] not in AIRES or z.split('/')[0] == aire:
            continue
        t = ZoneInfo(z)
        offs = {t.utcoffset(datetime.datetime(y, mois, 15)) for y in range(2015, 2031) for mois in (1, 4, 7, 10)}
        if offs == {datetime.timedelta(hours=heures)}:
            res.append(z)
    if not res:
        raise Echec('aucun fuseau a ce decalage')
    return res


def lire_noms(chemins):
    noms = {}

    def parcourir(x, cle=''):
        if isinstance(x, dict):
            for k, v in x.items():
                parcourir(v, k)
        elif isinstance(x, list):
            for v in x:
                parcourir(v, cle)
        elif isinstance(x, str) and x.strip():
            noms.setdefault(x.strip(), set()).add(cle)

    for c in chemins:
        with open(c, encoding='utf-8') as f:
            parcourir(json.load(f))
    return noms


def prose_prefixes64(texte):
    """Prefixes /64 cites dans la prose de la section 3a de l'inventaire de Maillage Thread."""
    m = re.search(r'### 3a\..*?(?=\n### )', texte, re.S)
    res = []
    for jeton in re.findall(r'`([0-9a-f:]+::/64)`', m.group(0) if m else ''):
        res.append(str(ipaddress.IPv6Network(jeton).network_address))
    return res


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('--inventaire-mt', required=True)
    p.add_argument('--inventaire-bq', required=True)
    p.add_argument('--noms', action='append', default=[])
    p.add_argument('--depot', action='append', required=True, help='nom=chemin')
    p.add_argument('--courriel-nouveau', required=True)
    p.add_argument('--decisions-noms', required=True)
    p.add_argument('--graine', type=int, default=GRAINE)
    p.add_argument('--zone-systeme', default=None)
    p.add_argument('--sortie', required=True)
    p.add_argument('--rapport')
    a = p.parse_args(argv)
    depots = dict(x.split('=', 1) for x in a.depot)
    corpus = {d: commun.Historique(c) for d, c in sorted(depots.items())}
    texte_mt = open(a.inventaire_mt, encoding='utf-8').read()
    texte_bq = open(a.inventaire_bq, encoding='utf-8').read()
    entrees = [(n, v, 'mt') for n, v in inventaires.lire_maillage(texte_mt)]
    entrees += [('prefixe64', v, 'mt') for v in prose_prefixes64(texte_mt)]
    entrees += [(n, v, 'bq') for n, v in inventaires.lire_benq(texte_bq)]
    decisions = json.load(open(a.decisions_noms, encoding='utf-8'))
    manquent = {'generiques', 'marques', 'modeles', 'genres', 'remplacer', 'garder'} - set(decisions)
    if manquent:
        raise Echec('decisions des noms incompletes : %s' % ', '.join(sorted(manquent)))
    zone = a.zone_systeme
    if zone is None and os.path.islink('/etc/localtime'):
        zone = os.readlink('/etc/localtime').split('zoneinfo/')[-1]
    g = Generateur(a.graine, corpus, lire_noms(a.noms), decisions, a.courriel_nouveau, zone)
    g.generer(entrees)
    regles = g.controler()
    table = {'version': 1, 'graine': a.graine, 'zone_systeme': zone,
             'valeurs': [v.json() for _, v in sorted(g.valeurs.items())],
             'noms': g.noms_pour_balayage(), 'noms_reels': sorted(n for n, c in g.noms_reels.items() if c & CLES_NOMS)}
    with open(a.sortie, 'w', encoding='utf-8') as f:
        json.dump(table, f, ensure_ascii=False, indent=1, sort_keys=True)
    comptes = {}
    for v in g.valeurs.values():
        comptes[v.nature] = comptes.get(v.nature, 0) + 1
    print('table : %d valeurs, %d ecritures, %d suites d\'octets' % (
        len(g.valeurs), len(regles), sum(len(v.octets) for v in g.valeurs.values())))
    print('par nature : ' + ', '.join('%s %d' % kv for kv in sorted(comptes.items())))
    portees = {}
    for p_, _ in g.portees.values():
        portees[p_] = portees.get(p_, 0) + 1
    print('noms trouves dans l\'historique : %d (%s)' % (len(g.portees), ', '.join('%s %d' % kv for kv in sorted(portees.items()))))
    print('notes du generateur : %d (ecritures communes ou fragments ambigus, laisses au balayage)' % len(g.journal))
    if a.rapport:
        ecrire_rapport(g, a.rapport)
    return 0


def ecrire_rapport(g, chemin):
    """Rapport prive : chaque ecriture et ses occurrences par depot (il contient des valeurs reelles)."""
    lignes = []
    for (nature, reel), v in sorted(g.valeurs.items()):
        lignes.append('== %s %s -> %s %s' % (nature, reel, v.nouveau, ('(' + v.derivee + ')') if v.derivee else ''))
        for classe, r, n, quoi, ds in v.formes:
            occ = {d: g.textes[d].count(r) for d in g.textes}
            lignes.append('   %-6s %-40s %s %s' % (classe, quoi[:40], occ, ds or ''))
    with open(chemin, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lignes) + '\n')


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Echec as e:
        print('echec : %s' % e, file=sys.stderr)
        sys.exit(2)
```

`$O/filtre.py` (fichier entier) :

```python
#!/usr/bin/env python3
"""Filtre entre git fast-export et git fast-import (spec de l'anonymisation, section 3).

Il reecrit le contenu des fichiers texte, les chemins et les messages par la table ; remplace
l'auteur et le committer de chaque commit en gardant leurs dates ; retire les fichiers Python
compiles (*.pyc) et le segment iCCP des PNG ; laisse intacts les autres binaires. Les identifiants
de commit cites dans les fichiers et les messages sont remplaces par les nouveaux quand ils designent
un commit deja reecrit : du meme depot (par get-mark de fast-import), ou d'un depot deja reecrit
(par sa carte, --carte-externe).

    /usr/bin/python3 filtre.py --table table.json --nom-depot mt --source MIROIR --cible NEUF.git
        --carte-sortie carte.json [--carte-externe autre-carte.json] [--auteur Djoko-cli]
"""
import argparse
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import commun  # noqa: E402

AUTEUR = 'Djoko-cli'


def moteur_du_depot(table, depot):
    regles, octets = [], []
    for v in table['valeurs']:
        for classe, r, n, _, ds in v['formes']:
            if ds is None or depot in ds:
                regles.append((classe, r, n))
        for r, n, mode, ds in v['octets']:
            if ds is None or depot in ds:
                octets.append((bytes.fromhex(r), bytes.fromhex(n), mode))
    return commun.Moteur(regles, octets)


def identite(table):
    courriels = {v['reel']: v['nouveau'] for v in table['valeurs'] if v['nature'] == 'courriel'}
    nouveaux = set(courriels.values())
    if len(nouveaux) != 1:
        raise SystemExit('la table doit donner une seule adresse de remplacement')
    return nouveaux.pop()


class Flux:
    """Lecture ligne a ligne du flux de fast-export, avec les blocs `data`."""

    def __init__(self, f):
        self.f = f
        self.suivante = None

    def ligne(self):
        if self.suivante is not None:
            l, self.suivante = self.suivante, None
            return l
        return self.f.readline()

    def remettre(self, l):
        self.suivante = l

    def donnees(self, entete):
        assert entete.startswith(b'data '), entete
        n = int(entete[5:].strip())
        d = self.f.read(n)
        assert len(d) == n
        return d


class Filtre:
    def __init__(self, table, depot, source, cible, carte_externe=None, auteur=AUTEUR):
        self.moteur = moteur_du_depot(table, depot)
        self.courriel = identite(table)
        self.auteur = auteur.encode()
        self.source, self.cible = source, cible
        self.commits_source = commun.commits(source)
        self.marques_commit = {}      # ancien sha -> marque
        self.originaux = {}           # marque -> ancien sha
        self.cache_marques = {}       # marque -> nouveau sha
        self.externe = commun.CarteCommits(carte_externe or {})
        self.internes = sorted(self.commits_source)
        self.pyc = self.blobs_pyc()
        self.retires = set()          # marques de blobs retires
        self.stats = {'blobs_textes_changes': 0, 'png_sans_iccp': 0, 'pyc_retires': 0, 'messages_changes': 0,
                      'chemins_changes': 0, 'identifiants_internes': 0, 'identifiants_externes': 0,
                      'identifiants_laisses': 0, 'commits': 0}

    def blobs_pyc(self):
        res = set()
        for c in self.commits_source:
            for p, (mode, sha) in commun.arbre(self.source, c).items():
                if p.endswith('.pyc'):
                    res.add(sha)
        return res

    # -- identifiants de commit ---------------------------------------------------------------
    def nouveau_sha(self, marque):
        if marque not in self.cache_marques:
            self.imp.stdin.write(b'get-mark :%d\n' % marque)
            self.imp.stdin.flush()
            r = self.reponses.readline().strip().decode()
            assert len(r) == 40, r
            self.cache_marques[marque] = r
        return self.cache_marques[marque]

    def resoudre(self, jeton):
        import bisect
        i = bisect.bisect_left(self.internes, jeton)
        trouves = []
        while i < len(self.internes) and self.internes[i].startswith(jeton) and len(trouves) < 2:
            trouves.append(self.internes[i])
            i += 1
        if len(trouves) == 1:
            ancien = trouves[0]
            if ancien in self.marques_commit:
                self.stats['identifiants_internes'] += 1
                return self.nouveau_sha(self.marques_commit[ancien])[:len(jeton)]
            self.stats['identifiants_laisses'] += 1
            return None
        if len(trouves) > 1:
            return None
        n = self.externe.resoudre(jeton)
        if n:
            self.stats['identifiants_externes'] += 1
        return n

    def texte(self, t):
        return commun.remplacer_shas(self.moteur.appliquer(t), self.resoudre)

    def chemin(self, brut):
        p = commun.dequoter(brut)
        n = self.moteur.appliquer(p)
        if n != p:
            self.stats['chemins_changes'] += 1
        return commun.quoter(n)

    # -- flux ---------------------------------------------------------------------------------
    def lancer(self, carte_sortie):
        subprocess.run(['git', 'init', '--quiet', '--bare', self.cible], check=True)
        marques_imp = os.path.join(self.cible, 'marques-import')
        r, w = os.pipe()
        self.imp = subprocess.Popen(['git', '-C', self.cible, 'fast-import', '--quiet', '--done',
                                     '--cat-blob-fd=%d' % w, '--export-marks=' + marques_imp],
                                    stdin=subprocess.PIPE, pass_fds=(w,))
        os.close(w)
        self.reponses = os.fdopen(r, 'rb')
        exp = subprocess.Popen(['git', '-C', self.source, 'fast-export', '--all', '--show-original-ids',
                                '--signed-tags=strip', '--tag-of-filtered-object=drop', '--reencode=yes',
                                '--use-done-feature'], stdout=subprocess.PIPE)
        flux = Flux(exp.stdout)
        sortie = self.imp.stdin
        while True:
            l = flux.ligne()
            if not l:
                break
            if l.startswith(b'blob'):
                self.blob(flux, sortie)
            elif l.startswith(b'commit '):
                self.commit(l, flux, sortie)
            elif l.startswith(b'done'):
                sortie.write(l)
                break
            else:
                sortie.write(l)
        sortie.close()
        if exp.wait() != 0 or self.imp.wait() != 0:
            raise SystemExit('fast-export ou fast-import a echoue')
        self.reponses.close()
        subprocess.run(['git', '-C', self.cible, 'symbolic-ref', 'HEAD', 'refs/heads/main'], check=True)
        nouveaux = {}
        with open(marques_imp) as f:
            for ligne in f:
                m, sha = ligne.split()
                nouveaux[int(m[1:])] = sha
        os.remove(marques_imp)
        carte = {self.originaux[m]: nouveaux[m] for m in self.originaux}
        with open(carte_sortie, 'w') as f:
            json.dump(carte, f, indent=1, sort_keys=True)
        return carte

    def blob(self, flux, sortie):
        marque = original = None
        while True:
            l = flux.ligne()
            if l.startswith(b'mark :'):
                marque = int(l[6:])
            elif l.startswith(b'original-oid '):
                original = l[13:].strip().decode()
            elif l.startswith(b'data '):
                donnees = flux.donnees(l)
                break
        fin = flux.ligne()
        if fin != b'\n':
            flux.remettre(fin)
        if original in self.pyc:
            self.retires.add(marque)
            self.stats['pyc_retires'] += 1
            return
        if donnees.startswith(commun.PNG):
            neuves = commun.png_sans_iccp(donnees)
            if neuves != donnees:
                self.stats['png_sans_iccp'] += 1
        else:
            t = commun.texte_ou_none(donnees)
            neuves = donnees
            if t is not None:
                n = self.texte(t)
                if n != t:
                    neuves = n.encode('utf-8')
                    self.stats['blobs_textes_changes'] += 1
        sortie.write(b'blob\nmark :%d\n' % marque)
        sortie.write(b'data %d\n' % len(neuves) + neuves + b'\n')

    def commit(self, entete, flux, sortie):
        # L'en-tete n'est ecrit qu'une fois le message reecrit : get-mark ne peut pas couper un commit.
        tampon = [entete]
        self.stats['commits'] += 1
        marque = None
        while True:
            l = flux.ligne()
            if l.startswith(b'mark :'):
                marque = int(l[6:])
                tampon.append(l)
            elif l.startswith(b'original-oid '):
                original = l[13:].strip().decode()
                self.originaux[marque] = original
            elif l.startswith(b'author ') or l.startswith(b'committer '):
                quoi, reste = l.split(b' ', 1)
                date = reste[reste.rindex(b'>') + 1:]
                tampon.append(quoi + b' ' + self.auteur + b' <' + self.courriel.encode() + b'>' + date)
            elif l.startswith(b'encoding '):
                tampon.append(l)
            elif l.startswith(b'data '):
                message = flux.donnees(l).decode('utf-8')
                n = self.texte(message)
                if n != message:
                    self.stats['messages_changes'] += 1
                b = n.encode('utf-8')
                tampon.append(b'data %d\n' % len(b) + b)
                break
            else:
                raise SystemExit('ligne inattendue dans un commit : %r' % l[:40])
        sortie.write(b''.join(tampon))
        # parents et changements de fichiers, jusqu'a la ligne vide
        while True:
            l = flux.ligne()
            if not l:
                break
            if l == b'\n':
                sortie.write(l)
                break
            if l.startswith(b'from ') or l.startswith(b'merge ') or l == b'deleteall\n':
                sortie.write(l)
            elif l.startswith(b'M '):
                _, mode, ref, chemin = l.rstrip(b'\n').split(b' ', 3)
                if chemin.endswith(b'.pyc') or chemin.endswith(b'.pyc"') or \
                        (ref.startswith(b':') and int(ref[1:]) in self.retires):
                    continue
                sortie.write(b'M ' + mode + b' ' + ref + b' ' + self.chemin(chemin) + b'\n')
            elif l.startswith(b'D '):
                chemin = l[2:].rstrip(b'\n')
                if chemin.endswith(b'.pyc') or chemin.endswith(b'.pyc"'):
                    continue
                sortie.write(b'D ' + self.chemin(chemin) + b'\n')
            elif l.startswith(b'commit ') or l.startswith(b'reset ') or l.startswith(b'blob') or l.startswith(b'done'):
                flux.remettre(l)
                sortie.write(b'\n')
                break
            else:
                raise SystemExit('changement de fichier non pris en charge : %r' % l[:40])
        sortie.flush()
        self.marques_commit[self.originaux[marque]] = marque


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('--table', required=True)
    p.add_argument('--nom-depot', required=True)
    p.add_argument('--source', required=True)
    p.add_argument('--cible', required=True)
    p.add_argument('--carte-sortie', required=True)
    p.add_argument('--carte-externe')
    p.add_argument('--auteur', default=AUTEUR)
    a = p.parse_args(argv)
    if os.path.exists(a.cible):
        raise SystemExit('la cible existe deja : %s' % a.cible)
    table = json.load(open(a.table, encoding='utf-8'))
    externe = json.load(open(a.carte_externe)) if a.carte_externe else None
    f = Filtre(table, a.nom_depot, a.source, a.cible, externe, a.auteur)
    carte = f.lancer(a.carte_sortie)
    tete = subprocess.run(['git', '-C', a.cible, 'rev-parse', 'refs/heads/main'], capture_output=True, text=True,
                          check=True).stdout.strip()
    print('commits reecrits : %d ; tete de main : %s' % (len(carte), tete))
    print(' ; '.join('%s %d' % kv for kv in sorted(f.stats.items())))
    return 0


if __name__ == '__main__':
    sys.exit(main())
```

`$O/controles.py` (fichier entier) :

```python
#!/usr/bin/env python3
"""Controles avant toute publication (spec de l'anonymisation, section 4).

    controles.py balayage      --table T --nom-depot mt --depot REECRIT [--carte C] [--carte-externe C2]
    controles.py second        --table T --depot REECRIT --scan SCAN.py --noms-bruts BRUTS.json
                               --chercher-noms CHERCHER.py
    controles.py reversibilite --table T --nom-depot mt --origine MIROIR --depot REECRIT --carte C
                               [--carte-externe C2]
    controles.py forme         --table T --nom-depot mt --origine MIROIR --depot REECRIT --carte C
    controles.py fichiers      --table T FICHIER...   (le plan, le rapport : memes recherches)

Chaque controle n'affiche que des comptes et des categories, jamais une valeur reelle. Il sort en
erreur (code 1) s'il trouve quelque chose qui n'est pas un faux positif connu.
"""
import argparse
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import commun  # noqa: E402

NOMS = ('nom', 'meshcop', 'hote_lisible')
NATURES_HEXA = ('hote16', 'hote12', 'mac', 'fabrique', 'noeud', 'agent', 'xp', 'at', 'partition', 'empreinte',
                'iid', 'prefixe48', 'prefixe64')
# Graines du script de l'inventaire du pont Halo gardees par decision (spec, section 1) ou faux
# positifs connus de l'inventaire : elles peuvent rester.
GRAINES_GARDEES = {'ADR_LIEN', 'ADR_APPAIRAGE', 'CHARGES_BALISE', 'THREAD_CANAL', 'PORTS_USB', 'VIDPID_LG',
                   'SESSION_CLAUDE', 'TMP_CLAUDE', 'PSEUDO', 'BUNDLE', 'TAILSCALE', 'TRAMES_CRC'}
RUN_CONTIGU = re.compile(r'[0-9A-Fa-f]{6,}')
RUN_SEPARE = re.compile(r'(?<![0-9A-Za-z])[0-9A-Fa-f]{2}(?:[:\- ][0-9A-Fa-f]{2}){2,}(?![0-9A-Za-z])')
IPV6 = re.compile(r'(?<![0-9A-Za-z:])[0-9A-Fa-f]{1,4}(?::[0-9A-Fa-f]{0,4}){2,7}')


def charger(chemin):
    with open(chemin, encoding='utf-8') as f:
        return json.load(f)


def valeurs(table, nature=None):
    return [v for v in table['valeurs'] if nature is None or v['nature'] == nature]


def hexa_de(v):
    """La valeur reelle d'une nature hexa, en chiffres contigus."""
    r = v['reel']
    return r.replace(':', '').upper()


def pauvre(f):
    """Fenetre pauvre, sans information : deux caracteres distincts au plus, ou un caractere repete
    quatre fois (les zeros de tete d'un noeud Matter, par exemple)."""
    return len(set(f)) <= 2 or max(f.count(c) for c in set(f)) >= 4


def fenetres_reelles(table):
    """{fenetre de 6 chiffres: nature} des valeurs reelles, hors prefixe garde et fenetres triviales."""
    res = {}
    for v in table['valeurs']:
        if v['nature'] not in NATURES_HEXA:
            continue
        h = hexa_de(v)
        g = len(v.get('garde') or '')
        for i in range(len(h) - 5):
            f = h[i:i + 6]
            if i + 6 > g and not pauvre(f):
                res.setdefault(f, v['nature'])
    return res


def runs_normalises(t):
    """Les suites hexa d'un texte, en chiffres contigus : suites contigues, octets separes, tableaux
    d'octets 0xNN, adresses IPv6 developpees."""
    import ipaddress
    for m in RUN_CONTIGU.finditer(t):
        yield m.start(), m.group(0).upper(), True
    for m in RUN_SEPARE.finditer(t):
        yield m.start(), re.sub('[^0-9A-Fa-f]', '', m.group(0)).upper(), False
    for m in re.finditer(commun.RUN, t):
        yield m.start(), ''.join(commun.JETON_OCTET.findall(m.group(0))).upper(), False
    for m in IPV6.finditer(t):
        try:
            yield m.start(), '%032X' % int(ipaddress.IPv6Address(m.group(0))), False
        except ValueError:
            yield m.start(), ''.join('%04X' % int(g, 16) for g in m.group(0).split(':') if g), False


def plus_long_commun(h, i, reels):
    """Longueur du plus long morceau de h, a partir de i, present dans une valeur reelle."""
    n = 6
    while i + n < len(h) and any(h[i:i + n + 1] in r for r in reels):
        n += 1
    return n


class Fichiers:
    """Des fichiers hors depot (le plan, le rapport), vus comme un depot d'un seul commit sans en-tete."""

    def __init__(self, chemins):
        self.chemins = chemins

        class H:
            blobs, chemins_du_blob, commits = {}, {}, []
        self.h = H()
        for c in chemins:
            with open(c, 'rb') as f:
                self.h.blobs[c] = f.read()
            self.h.chemins_du_blob[c] = {c}

    def documents(self):
        for c, b in self.h.blobs.items():
            t = commun.texte_ou_none(b)
            yield ('blob', c, t if t is not None else b.decode('latin-1'))


class Depot:
    def __init__(self, chemin):
        self.h = commun.Historique(chemin)

    def documents(self):
        """(sorte, cle, texte) : blobs (texte ou octets lus en latin-1), membres des zip, messages, en-tetes, chemins."""
        for sha, b in self.h.blobs.items():
            t = commun.texte_ou_none(b)
            yield ('blob', sha, t if t is not None else b.decode('latin-1'))
            if t is None and b[:4] == b'PK\x03\x04':
                try:
                    with zipfile.ZipFile(io.BytesIO(b)) as z:
                        for n in z.namelist():
                            yield ('zip', sha + ':' + n, n + '\n' + z.read(n).decode('latin-1'))
                except zipfile.BadZipFile:
                    pass
            m = commun.morceaux_png(b)
            if m:
                for typ, o in m:
                    if typ in ('zTXt', 'iTXt'):
                        try:
                            yield ('png', sha, zlib.decompress(o[8:-4].split(b'\0', 2)[-1][1:]).decode('latin-1'))
                        except zlib.error:
                            pass
        for c in self.h.commits:
            e, msg = self.h.entetes_et_message(c)
            yield ('message', c, msg)
            yield ('entetes', c, e)
        for p in self.h.chemins:
            yield ('chemin', p, p)


# --- balayage ----------------------------------------------------------------------------------

def balayage(table, depot, carte=None, carte_externe=None, fichiers=None):
    d = Fichiers(fichiers) if fichiers else Depot(depot)
    trouve = {}           # categorie -> nombre
    faux = {}             # (categorie, raison) -> nombre

    def compter(cat, n=1):
        trouve[cat] = trouve.get(cat, 0) + n

    def faux_positif(cat, raison, n=1):
        faux[(cat, raison)] = faux.get((cat, raison), 0) + n

    # 1. chaque valeur reelle, sous chacune de ses ecritures (toutes casses)
    # les noms se cherchent tels quels (en mot entier), le reste en toute casse
    formes = {}
    for v in table['valeurs']:
        if v['nature'] in ('prenom', 'courriel'):
            continue
        casse = v['nature'] in NOMS
        for classe, r, n, _, _ in v['formes']:
            formes.setdefault((classe, casse), {})[r if casse else r.lower()] = v['nature']
        if v['nature'] in NATURES_HEXA or v['nature'] in ('serie', 'ipv4', 'nom_reseau', 'fuseau'):
            classe = 'brut' if v['nature'] not in ('ipv4', 'fuseau') else ('ipv4' if v['nature'] == 'ipv4' else 'nombre')
            formes.setdefault((classe, False), {})[v['reel'].lower()] = v['nature']
    rx = {}
    for (classe, casse), t in formes.items():
        g, dr = commun.BORNES[classe]
        rx[(classe, casse)] = re.compile(g + '(?:' + commun.motif_trie(t) + ')' + dr, 0 if casse else re.I)
    # 2. fragments de 6 chiffres
    fen = fenetres_reelles(table)
    reels_hexa = [hexa_de(v) for v in table['valeurs'] if v['nature'] in NATURES_HEXA]
    nouveaux_shas = set()
    for c in (carte or {}, carte_externe or {}):
        nouveaux_shas |= {s.upper() for s in c.values()}
    # 3. noms reels, en mot entier
    portees = table.get('noms', {})
    noms = sorted(table.get('noms_reels', []), key=len, reverse=True)
    rx_noms = re.compile(r'(?<![\w])(?:' + commun.motif_trie(noms) + r')(?![\w])') if noms else None
    # 4. prenom (toute casse), adresse, nom de famille, fuseau, serie
    prenoms = [v['reel'] for v in valeurs(table, 'prenom')]
    courriels = [v['reel'] for v in valeurs(table, 'courriel')]
    morceaux = set()
    for c in courriels:
        morceaux |= {m for m in re.split(r'[._+-]', c.split('@')[0]) if len(m) >= 5}
    identite = sorted(set(prenoms) | morceaux | set(courriels), key=len, reverse=True)
    rx_identite = re.compile('|'.join(re.escape(x) for x in identite), re.I) if identite else None
    zone = table.get('zone_systeme') or ''
    rx_zone = None
    if zone:
        ville = zone.split('/')[-1].replace('_', ' ')
        rx_zone = re.compile(re.escape(zone) + '|' + r'(?<![\w])' + re.escape(ville) + r'(?![\w])')
    noreply = {v['nouveau'] for v in valeurs(table, 'courriel')}

    for sorte, cle, t in d.documents():
        for (classe, casse), r in rx.items():
            for m in r.finditer(t):
                compter('valeur reelle (%s)' % formes[(classe, casse)][m.group(0) if casse else m.group(0).lower()])
        vus_ici = set()
        for pos, h, contigu in runs_normalises(t):
            if contigu and h.isdigit() and (len(h) > 16 or t[pos - 1:pos] == '.' or t[pos + len(h):pos + len(h) + 1] == '.'):
                continue
            for i in range(len(h) - 5):
                f = h[i:i + 6]
                if f in fen and (pos, i, f) not in vus_ici:
                    vus_ici.add((pos, i, f))
                    n = plus_long_commun(h, i, reels_hexa)
                    if 7 <= len(h) <= 40 and any(s.startswith(h) for s in nouveaux_shas):
                        faux_positif('fragment hexa', 'dans un identifiant de commit reecrit (hasard)')
                    elif sorte == 'entetes' and len(h) == 40:
                        faux_positif('fragment hexa', 'dans un identifiant git d\'en-tete, arbre ou parent (hasard)')
                    elif n < 8:
                        faux_positif('fragment hexa', 'coincidence de %d chiffres dans une suite de %s chiffres' % (
                            n, '32 ou plus' if len(h) >= 32 else 'moins de 32'))
                    else:
                        compter('fragment hexa de %d chiffres ou plus (%s)' % (n, fen[f]))
        if rx_noms and sorte not in ('entetes',):
            binaire = sorte in ('zip', 'png') or (sorte == 'blob' and commun.texte_ou_none(d.h.blobs[cle]) is None)
            for m in rx_noms.finditer(t):
                nom = m.group(0)
                p = portees.get(nom) or ({'portee': 'garde', 'raison': 'un seul mot : mot courant, identifiant de code '
                                          'ou nom de produit'} if len(nom.split()) == 1 else None)
                if p and p['portee'] == 'garde':
                    faux_positif('nom reel en mot entier', 'garde par decision : ' + p['raison'])
                elif binaire:
                    faux_positif('nom reel en mot entier', 'dans un binaire laisse intact (%s)' % sorte)
                else:
                    compter('nom reel en mot entier')
        if rx_identite:
            for m in rx_identite.finditer(t):
                compter('prenom, nom ou adresse electronique')
        if rx_zone:
            for m in rx_zone.finditer(t):
                compter('nom du fuseau du Mac')
        if sorte == 'entetes':
            for l in t.splitlines():
                if l.startswith('author ') or l.startswith('committer '):
                    adr = l[l.index('<') + 1:l.index('>')]
                    if adr not in noreply:
                        compter('en-tete sans l\'adresse noreply')
    # binaires retires
    for sha, b in d.h.blobs.items():
        m = commun.morceaux_png(b)
        if m and any(typ == 'iCCP' for typ, _ in m):
            compter('PNG avec profil ICC')
    for p in (d.h.chemins if not fichiers else []):
        if p.endswith('.pyc'):
            compter('fichier .pyc')
    return trouve, faux


# --- second balayage --------------------------------------------------------------------------------

def second_balayage(depot, scan, bruts, chercher, table):
    """Les scripts des inventaires, relances sur un depot reecrit."""
    tmp = tempfile.mkdtemp(prefix='second-balayage-')
    try:
        os.makedirs(os.path.join(tmp, 'blobs'))
        h = commun.Historique(depot)
        principaux = commun.git(depot, 'rev-list', 'main').split()
        with open(os.path.join(tmp, 'commits.txt'), 'w') as f:
            f.write('\n'.join(principaux) + '\n')
        with open(os.path.join(tmp, 'tree_entries.txt'), 'w') as f:
            for c in principaux:
                for p, (mode, sha) in sorted(h.arbres[c].items()):
                    f.write('%s\t%s blob %s\t%s\n' % (c, mode, sha, p))
        for sha, b in h.blobs.items():
            with open(os.path.join(tmp, 'blobs', sha), 'wb') as f:
                f.write(b)
        with open(os.path.join(tmp, 'messages.txt'), 'w', encoding='utf-8') as f:
            for c in principaux:
                e, msg = h.entetes_et_message(c)
                f.write('==== %s\n%s\n' % (c, msg))
        shutil.copy(scan, os.path.join(tmp, 'scan.py'))
        subprocess.run([sys.executable, os.path.join(tmp, 'scan.py')], check=True, capture_output=True)
        res = json.load(open(os.path.join(tmp, 'resultats.json'), encoding='utf-8'))
        sortie_noms = os.path.join(tmp, 'noms.json')
        subprocess.run([sys.executable, chercher, bruts, sortie_noms, depot], check=True, capture_output=True)
        noms = json.load(open(sortie_noms, encoding='utf-8'))
    finally:
        shutil.rmtree(tmp)
    trouve, gardees = {}, {}
    for e in res:
        n = e['commits'] + len(e['messages']) + len(e['chemins'])
        if e['cat'] == 0:
            continue
        if e['id'] in GRAINES_GARDEES:
            if n:
                gardees[e['id']] = n
        elif n:
            trouve['graine %s (categorie %d)' % (e['id'], e['cat'])] = n
    portees = table.get('noms', {})
    for nom in list(noms['a_remplacer']) + list(noms['generiques_gardes']):
        p = portees.get(nom, {}).get('portee')
        if p != 'garde':
            trouve['nom reel (script des noms)'] = trouve.get('nom reel (script des noms)', 0) + 1
    noms_gardes = sum(1 for nom in list(noms['a_remplacer']) + list(noms['generiques_gardes'])
                      if portees.get(nom, {}).get('portee') == 'garde')
    return trouve, gardees, noms_gardes


# --- reversibilite ------------------------------------------------------------------------------------

def moteur(table, depot):
    regles, octets = [], []
    for v in table['valeurs']:
        for classe, r, n, _, ds in v['formes']:
            if ds is None or depot in ds:
                regles.append((classe, r, n, v['nature']))
        for r, n, mode, ds in v['octets']:
            if ds is None or depot in ds:
                octets.append((bytes.fromhex(r), bytes.fromhex(n), mode))
    aller = commun.Moteur([(c, r, n) for c, r, n, _ in regles], octets)
    retour = commun.Moteur([(c, n, r) for c, r, n, nat in regles if nat != 'prenom'],
                           [(n, r, m) for r, n, m in octets])
    prenom = commun.Moteur([(c, r, n) for c, r, n, nat in regles if nat == 'prenom'])
    return aller, retour, prenom


def reversibilite(table, depot_nom, origine, reecrit, carte, carte_externe=None):
    """Applique la table a l'envers sur chaque fichier, message et chemin reecrits."""
    _, retour, prenom = moteur(table, depot_nom)
    inverse = dict((n, a) for a, n in carte.items())
    if carte_externe:
        inverse.update((n, a) for a, n in carte_externe.items())
    shas_inverses = commun.CarteCommits(inverse)
    a, b = commun.Historique(origine), commun.Historique(reecrit)
    ecarts, vus, stats = {}, set(), {'blobs': 0, 'png': 0, 'messages': 0, 'pyc_retires': 0, 'chemins': 0}

    def defaire(t):
        return retour.appliquer(commun.remplacer_shas(t, shas_inverses.resoudre))

    def ecart(cat):
        ecarts[cat] = ecarts.get(cat, 0) + 1

    for ancien, nouveau in carte.items():
        ta, tb = a.arbres[ancien], b.arbres[nouveau]
        chemins_b = {defaire(p): p for p in tb}
        for p, (mode, sha) in ta.items():
            if p.endswith('.pyc'):
                if p in chemins_b:
                    ecart('fichier .pyc encore present')
                else:
                    stats['pyc_retires'] += 1
                continue
            if p not in chemins_b:
                ecart('chemin perdu ou mal reecrit')
                continue
            stats['chemins'] += 1
            sha_b = tb[chemins_b[p]][1]
            if (sha, sha_b) in vus:
                continue
            vus.add((sha, sha_b))
            ob, nb = a.blobs[sha], b.blobs[sha_b]
            if ob.startswith(commun.PNG):
                stats['png'] += 1
                if commun.png_sans_iccp(ob) != nb:
                    ecart('PNG different hors profil ICC')
                continue
            to = commun.texte_ou_none(ob)
            if to is None:
                if ob != nb:
                    ecart('binaire modifie')
                continue
            stats['blobs'] += 1
            if defaire(nb.decode('utf-8')) != prenom.appliquer(to):
                ecart('texte non retrouve a l\'octet pres')
        if len(chemins_b) != len([p for p in ta if not p.endswith('.pyc')]):
            ecart('nombre de fichiers different')
        ea, ma = a.entetes_et_message(ancien)
        eb, mb = b.entetes_et_message(nouveau)
        stats['messages'] += 1
        if defaire(mb) != prenom.appliquer(ma):
            ecart('message non retrouve')
    return stats, ecarts


# --- forme ----------------------------------------------------------------------------------------

def dates(entetes):
    res = []
    for l in entetes.splitlines():
        if l.startswith('author ') or l.startswith('committer '):
            res.append(l[l.rindex('>') + 2:])
    return res


def parents(entetes):
    return [l.split()[1] for l in entetes.splitlines() if l.startswith('parent ')]


def forme(table, depot_nom, origine, reecrit, carte):
    _, retour, _ = moteur(table, depot_nom)
    a, b = commun.Historique(origine), commun.Historique(reecrit)
    ecarts = {}

    def ecart(cat):
        ecarts[cat] = ecarts.get(cat, 0) + 1

    refs_a = dict(l.split() for l in commun.git(origine, 'for-each-ref', '--format=%(refname) %(objectname)').splitlines())
    refs_b = dict(l.split() for l in commun.git(reecrit, 'for-each-ref', '--format=%(refname) %(objectname)').splitlines())
    if set(refs_a) != set(refs_b):
        ecart('references differentes')
    for r in refs_a:
        if r in refs_b and carte.get(refs_a[r]) != refs_b[r]:
            ecart('reference qui ne pointe pas sur le commit reecrit')
        if r in refs_b and commun.git(origine, 'rev-list', '--count', r) != commun.git(reecrit, 'rev-list', '--count', r):
            ecart('nombre de commits different')
    if len(a.commits) != len(b.commits) or set(carte) != set(a.commits) or set(carte.values()) != set(b.commits):
        ecart('commits differents')
    for ancien, nouveau in carte.items():
        ea, _ = a.entetes_et_message(ancien)
        eb, _ = b.entetes_et_message(nouveau)
        if [carte.get(p) for p in parents(ea)] != parents(eb):
            ecart('graphe des parents different')
        if dates(ea) != dates(eb):
            ecart('dates differentes')
        pa = {p for p in a.arbres[ancien] if not p.endswith('.pyc')}
        pb = {retour.appliquer(p) for p in b.arbres[nouveau]}
        if pa != pb:
            ecart('chemins differents')
    stats = {'commits': len(carte), 'references': len(refs_b), 'chemins': len(b.chemins)}
    return stats, ecarts


# --- ligne de commande -----------------------------------------------------------------------------

def imprimer(titre, dico):
    print('%s : %s' % (titre, '; '.join('%s %d' % kv for kv in sorted(dico.items())) if dico else 'aucun'))


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('controle', choices=['balayage', 'second', 'reversibilite', 'forme', 'fichiers'])
    p.add_argument('--table', required=True)
    p.add_argument('--nom-depot')
    p.add_argument('--depot')
    p.add_argument('chemins', nargs='*', help='pour le controle fichiers : les fichiers a balayer')
    p.add_argument('--origine')
    p.add_argument('--carte')
    p.add_argument('--carte-externe')
    p.add_argument('--scan')
    p.add_argument('--noms-bruts')
    p.add_argument('--chercher-noms')
    a = p.parse_intermixed_args(argv)
    table = charger(a.table)
    carte = charger(a.carte) if a.carte else None
    externe = charger(a.carte_externe) if a.carte_externe else None
    if a.controle in ('balayage', 'fichiers'):
        trouve, faux = balayage(table, a.depot, carte, externe, a.chemins if a.controle == 'fichiers' else None)
        imprimer('trouve', trouve)
        print('faux positifs connus : %s' % ('; '.join('%s, %s : %d' % (c, r, n) for (c, r), n in sorted(faux.items()))
                                             or 'aucun'))
        return 1 if trouve else 0
    if a.controle == 'second':
        trouve, gardees, noms_gardes = second_balayage(a.depot, a.scan, a.noms_bruts, a.chercher_noms, table)
        imprimer('trouve', trouve)
        imprimer('graines gardees par decision (presentes)', gardees)
        print('noms gardes par decision, vus par le script des noms : %d' % noms_gardes)
        return 1 if trouve else 0
    if a.controle == 'reversibilite':
        stats, ecarts = reversibilite(table, a.nom_depot, a.origine, a.depot, carte, externe)
        imprimer('verifies', stats)
        imprimer('ecarts', ecarts)
        return 1 if ecarts else 0
    stats, ecarts = forme(table, a.nom_depot, a.origine, a.depot, carte)
    imprimer('verifies', stats)
    imprimer('ecarts', ecarts)
    return 1 if ecarts else 0


if __name__ == '__main__':
    sys.exit(main())
```

`$O/remettre_en_etat.py` (fichier entier) :

```python
#!/usr/bin/env python3
"""Remise en etat d'un clone de travail tire du depot reecrit (spec de l'anonymisation, section 5).

    /usr/bin/python3 remettre_en_etat.py maillage CLONE MIROIR_D_ORIGINE
    /usr/bin/python3 remettre_en_etat.py benq CLONE

Maillage Thread : l'empreinte SHA-256 de la capture anonymisee de la sonde change avec elle (les plans
la citent) ; le README de la capture dit ce que la reecriture a remplace. Pont Halo : le plan du pilote
dit que le .pyc de l'audit a ete retire de l'historique. Le script ne fait que des remplacements
exacts : il echoue si un texte attendu manque. Il n'affiche que des comptes.
"""
import hashlib
import os
import subprocess
import sys

CAPTURE = 'docs/releves/2026-09-29/capture-sonde.jsonl'
README = 'docs/releves/2026-09-29/README.md'
AVANT_README = """Les RLOC16, partitions, qualités de lien, délais et versions de pile sont
gardés, et les `id` des `diag` aussi : ils reprennent ceux des commandes
envoyées (`diag <cible> <TLV> <id>`), choisis à la main ou par
`sonde/tournee_essai.py`, qui numérote à partir de 101. Ce ne sont pas des
identifiants de la sonde. La capture brute n'est pas dans le dépôt.
"""
APRES_README = """Les RLOC16, qualités de lien, délais et versions de pile sont gardés, et les
`id` des `diag` aussi : ils reprennent ceux des commandes envoyées
(`diag <cible> <TLV> <id>`), choisis à la main ou par
`sonde/tournee_essai.py`, qui numérote à partir de 101. Ce ne sont pas des
identifiants de la sonde. La capture brute n'est pas dans le dépôt.

**Réécriture du 05/10/2026.** L'anonymiseur gardait deux identifiants réels :
la partition et le 4e groupe du préfixe de maillage local, derrière
`fd00:1111:2222`. L'historique du dépôt a été réécrit (spec de
l'anonymisation, `docs/superpowers/specs/2026-10-05-anonymisation-design.md`) :
ils sont désormais inventés, jusque dans les TLV, et la capture ne garde plus
aucun identifiant réel. Le canal radio est gardé, comme dans le reste du dépôt.
"""
PLAN_PILOTE = {
    'docs/PLAN-PILOTE-HALO1.fr.md': (
        "et ajouter `__pycache__/` au `.gitignore`.\n",
        "et ajouter `__pycache__/` au `.gitignore`. Ce `.pyc` a depuis été retiré de tout l'historique, à sa "
        "réécriture du 05/10/2026.\n"),
    'docs/PLAN-PILOTE-HALO1.md': (
        "and add `__pycache__/` to `.gitignore`.\n",
        "and add `__pycache__/` to `.gitignore`. This `.pyc` was later removed from the whole history when it "
        "was rewritten on 2026-10-05.\n"),
}


def remplacer(clone, chemin, avant, apres, fois=1):
    p = os.path.join(clone, chemin)
    with open(p, encoding='utf-8') as f:
        texte = f.read()
    if texte.count(avant) != fois:
        raise SystemExit('texte attendu absent ou multiple dans %s' % chemin)
    with open(p, 'w', encoding='utf-8') as f:
        f.write(texte.replace(avant, apres))


def maillage(clone, origine):
    ancien = hashlib.sha256(subprocess.run(['git', '-C', origine, 'show', 'main:' + CAPTURE], capture_output=True,
                                           check=True).stdout).hexdigest()
    with open(os.path.join(clone, CAPTURE), 'rb') as f:
        nouveau = hashlib.sha256(f.read()).hexdigest()
    if ancien == nouveau:
        raise SystemExit('la capture n\'a pas change : rien a recalculer ?')
    cites = subprocess.run(['git', '-C', clone, 'grep', '-l', ancien], capture_output=True, text=True).stdout.split()
    for chemin in cites:
        with open(os.path.join(clone, chemin), encoding='utf-8') as f:
            n = f.read().count(ancien)
        remplacer(clone, chemin, ancien, nouveau, n)
    remplacer(clone, README, AVANT_README, APRES_README)
    print('empreinte de la capture remplacee dans %d fichier(s) ; README de la capture corrige' % len(cites))
    return cites + [README]


def benq(clone):
    for chemin, (avant, apres) in PLAN_PILOTE.items():
        remplacer(clone, chemin, avant, apres)
    print('plan du pilote complete (2 fichiers)')
    return list(PLAN_PILOTE)


if __name__ == '__main__':
    if sys.argv[1:2] == ['maillage'] and len(sys.argv) == 4:
        print('\n'.join(maillage(sys.argv[2], sys.argv[3])))
    elif sys.argv[1:2] == ['benq'] and len(sys.argv) == 3:
        print('\n'.join(benq(sys.argv[2])))
    else:
        raise SystemExit(__doc__)
```

`$O/reecrire.sh` (fichier entier, exécutable) :

```bash
#!/bin/zsh
# Table, filtre et controles sur deux miroirs ; aucun depot de travail n'est touche.
#   outils/reecrire.sh <sortie> <miroir maillage-thread> <miroir benq> <table de sortie>
# Variables : NOREPLY_FICHIER (le fichier prive qui porte l'adresse noreply du compte) et
# INVENTAIRE_SCRIPTS (le dossier des scripts de l'inventaire du pont : scan.py, et chercher_noms.py a cote
# dans NOMS_SCRIPTS). Rien n'est affiche que des comptes.
set -u
SORTIE=$1 MT=$2 BQ=$3 TABLE=$4
A=$HOME/Dev/maillage-thread/.superpowers/anonymisation
O=$A/outils
C="$HOME/Library/Containers/fr.djoko.maillage/Data"
NOMS=( --noms "$C/Library/Application Support/Maillage Thread/noms.json" )
for f in "$C"/tmp/noms-*/noms.json(N); do NOMS+=( --noms "$f" ); done
mkdir -p $SORTIE/controles
/usr/bin/python3 $O/table.py --inventaire-mt $A/inventaire.md \
  --inventaire-bq $HOME/Documents/Dev/esp32/benq/.superpowers/anonymisation/inventaire.md "${NOMS[@]}" \
  --depot mt=$MT --depot bq=$BQ --courriel-nouveau "$(cat $NOREPLY_FICHIER)" \
  --decisions-noms $A/decisions-noms.json --sortie $TABLE || exit 1
/usr/bin/python3 $O/filtre.py --table $TABLE --nom-depot bq --source $BQ --cible $SORTIE/benq-reecrit.git \
  --carte-sortie $SORTIE/carte-benq.json || exit 1
/usr/bin/python3 $O/filtre.py --table $TABLE --nom-depot mt --source $MT --cible $SORTIE/maillage-thread-reecrit.git \
  --carte-sortie $SORTIE/carte-maillage-thread.json --carte-externe $SORTIE/carte-benq.json || exit 1
CODE=0
for d in bq mt; do
  if [ $d = bq ]; then N=benq; M=$BQ; X=(); else N=maillage-thread; M=$MT; X=(--carte-externe $SORTIE/carte-benq.json); fi
  RW=$SORTIE/$N-reecrit.git; K=$SORTIE/carte-$N.json
  /usr/bin/python3 $O/controles.py balayage --table $TABLE --nom-depot $d --depot $RW --carte $K "${X[@]}" \
    > $SORTIE/controles/$N-balayage.txt 2>&1 || CODE=1
  /usr/bin/python3 $O/controles.py forme --table $TABLE --nom-depot $d --origine $M --depot $RW --carte $K \
    > $SORTIE/controles/$N-forme.txt 2>&1 || CODE=1
  /usr/bin/python3 $O/controles.py reversibilite --table $TABLE --nom-depot $d --origine $M --depot $RW --carte $K "${X[@]}" \
    > $SORTIE/controles/$N-reversibilite.txt 2>&1 || CODE=1
  /usr/bin/python3 $O/controles.py second --table $TABLE --depot $RW --scan $INVENTAIRE_SCRIPTS/scan.py \
    --noms-bruts $A/noms-reels-bruts.json --chercher-noms $NOMS_SCRIPTS/chercher_noms.py \
    > $SORTIE/controles/$N-second.txt 2>&1 || CODE=1
done
for f in $SORTIE/controles/*.txt; do echo "== ${f:t}"; cat $f; done
exit $CODE
```

`$O/mutants.py` (fichier entier) :

```python
#!/usr/bin/env python3
"""Essaie des mutants plausibles des outils : chaque mutant doit faire echouer les tests.

    /usr/bin/python3 mutants.py

Copie les outils dans un dossier temporaire, applique un mutant (un remplacement de texte exact),
lance les tests ; un mutant qui laisse les tests verts est un trou dans les tests.
"""
import os
import shutil
import subprocess
import sys
import tempfile

ICI = os.path.dirname(os.path.abspath(__file__))

MUTANTS = [
    ('une ecriture oubliee (hexa en minuscules)', 'table.py',
     "            v.forme(classe, r.lower(), n.lower(), 'hexa contigu min')", '            pass'),
    ('une valeur derivee non recalculee (prefixe tire du xp reel)', 'table.py',
     "            ri, ni = int(infra(xp), 16), int(infra(self.valeurs[('xp', xp)].nouveau), 16)\n"
     "            fixes[", "            ri, ni = int(infra(xp), 16), int(infra(xp), 16) + 1\n            fixes["),
    ('l\'ordre perdu', 'table.py',
     '            res[r], cur = c, v\n        return res',
     '            res[r], cur = c, v\n        return dict(zip(sorted(res), [res[k] for k in sorted(res)][::-1]))'),
    ('une collision (remplacante deja dans l\'historique acceptee)', 'table.py',
     "            if m:\n                raise Echec('une remplacante parait deja",
     "            if False:\n                raise Echec('une remplacante parait deja"),
    ('une collision (valeur deja prise retiree)', 'table.py',
     'if c != r and c not in self.nouveaux_vus and', 'if c != r and'),
    ('un auteur non reecrit', 'filtre.py',
     "                tampon.append(quoi + b' ' + self.auteur + b' <' + self.courriel.encode() + b'>' + date)",
     '                tampon.append(l)'),
    ('un fragment court manque', 'table.py',
     "                    cands.setdefault(a, []).append((v, b, 'fragment : %s, %d chiffres' % (cote, k)))",
     '                    pass'),
    ('un PNG garde son profil ICC', 'filtre.py',
     '            neuves = commun.png_sans_iccp(donnees)', '            neuves = donnees'),
    ('le .pyc garde', 'filtre.py', '        if original in self.pyc:', '        if False:'),
    ('les identifiants de commit laisses', 'filtre.py',
     '        return commun.remplacer_shas(self.moteur.appliquer(t), self.resoudre)',
     '        return self.moteur.appliquer(t)'),
    ('un nom de plusieurs mots garde', 'table.py',
     "                self.portees[nom] = ('phrase', 'nom de plusieurs mots')",
     "                self.portees[nom] = ('garde', 'nom de plusieurs mots')"),
    ('le sous-reseau derriere un /48 factice oublie en octets', 'table.py',
     "                v.octet(fh + '%04X' % s, fh + '%04X' % c)\n", ''),
    ('une suite d\'octets en hexa oubliee', 'table.py',
     "                            v.forme_casse('hexa', ancien, neuf, 'suite d\\'octets commencant par la valeur, en hexa', ds)",
     '                            pass'),
    ('le balayage ne cherche plus les fragments', 'controles.py',
     '                if f in fen and (pos, i, f) not in vus_ici:', '                if False:'),
]


def lancer_tests(dossier):
    r = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', os.path.join(dossier, 'tests')],
                       cwd=dossier, capture_output=True, text=True)
    return r.returncode == 0


def main():
    resultats = []
    for nom, fichier, avant, apres in MUTANTS:
        tmp = tempfile.mkdtemp(prefix='mutant-')
        try:
            copie = os.path.join(tmp, 'outils')
            shutil.copytree(ICI, copie, ignore=shutil.ignore_patterns('__pycache__'))
            chemin = os.path.join(copie, fichier)
            texte = open(chemin, encoding='utf-8').read()
            if texte.count(avant) < 1:
                resultats.append((nom, 'mutant introuvable'))
                continue
            open(chemin, 'w', encoding='utf-8').write(texte.replace(avant, apres, 1))
            resultats.append((nom, 'survit' if lancer_tests(copie) else 'tue'))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    for nom, r in resultats:
        print('%-60s %s' % (nom, r))
    tues = sum(1 for _, r in resultats if r == 'tue')
    print('mutants tues : %d sur %d' % (tues, len(resultats)))
    return 0 if tues == len(resultats) else 1


if __name__ == '__main__':
    sys.exit(main())
```

`$O/tests/monde.py` (fichier entier) :

```python
"""Un petit monde synthetique pour les tests : deux depots, deux inventaires, un noms.json, des decisions.

Toutes les valeurs sont inventees. Les formes reprennent celles des vrais historiques : hexa contigu,
octets separes, tableaux 0xNN, groupes IPv6 abreges et complets, TXT pt en octets bruts, omr, EUI-64,
fragments, noms cites, prenom dans un chemin, fichier .pyc, PNG avec profil ICC, identifiants de commit.
"""
import json
import os
import struct
import subprocess
import sys
import tempfile
import zlib

ICI = os.path.dirname(os.path.abspath(__file__))
OUTILS = os.path.dirname(ICI)
sys.path.insert(0, OUTILS)

PYTHON = sys.executable
COURRIEL_NOUVEAU = '12345+Testeur@users.noreply.github.com'
ZONE_SYSTEME = 'Pacific/Nulle'

INVENTAIRE_MT = """# Inventaire synthetique

## 1. Nom du reseau Thread

| Valeur | Nature | Variantes vues | Commits |
|---|---|---|---|
| `Reseau1500000000` |  | texte exact | 1 |

## 2. Extended PAN ID, PAN ID, canal, partitions

| Valeur | Nature | Variantes vues | Commits |
|---|---|---|---|
| `1A2B3C4D5E6F7A8B` | xp | hexa | 1 |
| `channel 11` | canal | texte | 1 |
| `61727374` | partition | hexa | 1 |
| `74737261` | partition | hexa | 1 |
| `C1C2C3C4` | partition | hexa | 1 |
| `00005F5E10AB0000` | at (horodatage actif du dataset) | hexa | 1 |

## 3. Prefixes IPv6 et adresses

### 3a. Prefixes /48

Roles : `fd12:3456:789a::/64` = OMR ; `fdab:cdef:1234:5678::/64` = maillage local, absent.

| Valeur | Nature | Variantes vues | Commits |
|---|---|---|---|
| `fd12:3456:789a::/48` | prefixe /48 | groupes | 1 |
| `fd1a:2b3c:4d5e::/48` | prefixe /48 | groupes | 1 |

### 3b. Adresses

| Valeur | Nature | Variantes vues | Commits |
|---|---|---|---|
| `fd12:3456:789a:0:1111:2222:3333:4444` | adresse | toute ecriture | 1 |
| `fd1a:2b3c:4d5e:7a8b:2:fd12:3456:789a` | adresse | toute ecriture | 1 |
| `fe80::a1b2:c3d4:e5f6:789` | adresse | toute ecriture | 1 |
| `fe80::ae11:22ff:fe33:4455` | adresse | toute ecriture | 1 |

## 4. ExtMac et adresses MAC

| Valeur | Nature | Variantes vues | Commits |
|---|---|---|---|
| `2E3F405162738495` | nom d hote Matter | hexa | 1 |
| `9F8E7D6C5B4A3928` | xa routeur de bordure | hexa | 1 |
| `AC11223344550000` | nom d hote Matter | hexa | 1 |
| `B0C1D2E3F405` | nom d hote 12 hexa (MAC ?) | hexa | 1 |
| `AC1122334455` | MAC deduite : essai | hexa | 1 |

## 5. Matter : fabriques, noeuds, instances ; meshcop

| Valeur | Nature | Variantes vues | Commits |
|---|---|---|---|
| `2BADCAFE12345678` | fabrique Matter (compressed fabric id) | hexa | 1 |
| `3BEEF00D12ABCDEF` | fabrique Matter (compressed fabric id) | hexa | 1 |
| `0000000012345678` | node id Matter | hexa | 1 |
| `0000000087654321` | node id Matter | hexa | 1 |
| `2BADCAFE12345678-0000000012345678` | instance _matter._tcp | texte | 1 |
| `0F1E2D3C4B5A69788796A5B4C3D2E1F0` | id agent de bordure (TXT id) | hexa | 1 |
| `Enceinte Modele Pigeonnier` | instance _meshcop._udp | texte | 1 |
| `Borne Modele #3928` | instance _meshcop._udp | texte | 1 |

## 6. Noms d'hote et numeros de serie

| Valeur | Nature | Variantes vues | Commits |
|---|---|---|---|
| `Enceinte-Modele-Pigeonnier.local` | nom d hote | texte exact | 1 |
| `Borne-Modele-4455.local` | nom d hote | texte exact | 1 |

## 8. Autres identifiants personnels

| Valeur | Nature | Commits | Fichiers |
|---|---|---|---|
| `personne.test@example.org` | adresse electronique de l'auteur | 1 | 0 |
| `Testeur` | nom d'auteur (pseudo) | 1 | 0 |
| `Ninon` | prenom, dans des commentaires | 1 | 1 |
| `UTC+7` | fuseau horaire du Mac | 1 | 1 |
| `10.1.2.3` | IPv4 du reseau local | 1 | 1 |
"""

INVENTAIRE_BQ = """# Inventaire synthetique du pont

## 1. Adresses MAC et ExtMac

| Valeur réelle | Nature | Commits |
|---|---|---|
| **AC:DE:48:00:11:22** | MAC d'usine du pont | 1 |
| **2E3F405162738495** | ExtMac Thread du pont = nom d'hôte SRP | 1 |

## 3. Identifiants réseau

| Valeur réelle | Nature | Commits |
|---|---|---|
| **fd12:3456:789a::/64 ; pont : fd12:3456:789a:0:aaaa:bbbb:cccc:dddd** | Préfixe OMR du réseau Thread | 1 |
| **canal 11 (2405 MHz)** | Canal du réseau Thread | 1 |
| **ABCDEF12** | Empreintes de clé H1 non dérivées des clés de test (doute) | 1 |

## 4. Noms d'hôte et numéros de série

| Valeur réelle | Nature | Commits |
|---|---|---|
| **123ABCDEF456** | Numéro de série USB d'un écran | 1 |

### 6.1 Identité des commits (en-têtes)

| Valeur réelle | Où | Commits | Arbre actuel |
|---|---|---|---|
| **personne.test@example.org** (adresse électronique) | en-têtes Author et Committer | 2 sur 2 | sans objet |

### 6.2 Contenu des fichiers et des messages

| Valeur réelle | Nature | Commits |
|---|---|---|
| **Ninon** | Prénom | 1 |
"""

NOMS = {'version': 1, 'domicile': 'Chez Nous Test', 'accessoires': [
    {'nom': 'Veilleuse remise ouest', 'piece': 'Orangerie', 'pieces': ['Orangerie']},
    {'nom': 'Veilleuse', 'piece': 'Orangerie'},
    {'nom': 'Borne Modele Z9', 'modele': 'Z9'},
    {'nom': 'Applique double'}]}

DECISIONS = {'generiques': ['Orangerie'], 'marques': ['Modele'], 'modeles': ['Enceinte Modele', 'Borne Modele'],
             'genres': [['remise', ['Lampadaire', 'Applique']]], 'remplacer': [], 'garder': []}


def morceau(t, d):
    return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)


PNG_ICC = (b'\x89PNG\r\n\x1a\n' + morceau(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
           + morceau(b'iCCP', b'profil\0\0' + zlib.compress(b'profil de test, Ninon'))
           + morceau(b'IDAT', zlib.compress(b'\0\xff\x00\x00')) + morceau(b'IEND', b''))
PYC = b'\x6f\x0d\x0d\x0a' + b'\0' * 12 + b'/Users/Ninon/outil.py\0'

RELEVE = """{
  "reseau" : "Reseau1500000000",
  "xp" : "1A2B3C4D5E6F7A8B",
  "xa" : "9F8E7D6C5B4A3928",
  "pt" : "arst",
  "pt_envers" : "tsra",
  "partition" : "C1C2C3C4",
  "at" : "hex:00005F5E10AB0000",
  "omr" : "hex:40FD123456789A0000",
  "hotes" : ["2E3F405162738495.local", "AC11223344550000.local", "B0C1D2E3F405.local",
             "Enceinte-Modele-Pigeonnier.local", "Borne-Modele-4455.local"],
  "adresses" : ["fd12:3456:789a:0:1111:2222:3333:4444", "fd12:3456:789a::", "fe80::a1b2:c3d4:e5f6:789%en0",
                "fe80:0000:0000:0000:ae11:22ff:fe33:4455", "fd1a:2b3c:4d5e:7a8b:2:fd12:3456:789a", "10.1.2.3"],
  "instance" : "2BADCAFE12345678-0000000012345678",
  "fabrique_min" : "3beef00d12abcdef",
  "noeud" : "0000000087654321",
  "agent" : "0F1E2D3C4B5A69788796A5B4C3D2E1F0",
  "routeurs" : ["Enceinte Modele Pigeonnier", "Borne Modele #3928", "Enceinte Modele pigeonnier"],
  "nom" : "Veilleuse remise ouest",
  "seul" : "Veilleuse",
  "produit" : "Borne Modele Z9",
  "piece" : "Orangerie",
  "note" : "heure du Mac, UTC+7 ; jeu actif du 2020-09-13"
}
"""

TESTS_SWIFT = """let xp: [UInt8] = [0x1A, 0x2B, 0x3C, 0x4D,
                   0x5E, 0x6F, 0x7A, 0x8B]
let pt = Data([0x61, 0x72, 0x73, 0x74])
let at = Data([0x00, 0x00, 0x5F, 0x5E, 0x10, 0x00, 0x00, 0x00]) // 1_600_000_000, "2020-09-13T12:26:40Z"
let fd12 = "fd12:3456:789a::"
let libelle = "Essai (fd12)"
let extmac = "fd12:3456:789a:0:2e3f:4051:6273:8495"
let court = Data(hexa: "1a2b") == Data([0x1A, 0x2B]) // debut du xp : 1A2B3C
let invalide = "2E3F40516273849Z"
let noeud = noeud(0x87654321) == "0000000087654321"
let chemin = "/Users/Ninon/Dev"
let noms = ["Veilleuse remise ouest \\u{263E}", "Veilleuse", "Orangerie"]
let maille = "FD001111222256780000"
let mailleOctets: [UInt8] = [0xFD, 0x00, 0x11, 0x11, 0x22, 0x22, 0x56, 0x78, 0x00, 0x01]
let piege = Data([0x1A, 0x2B, 0x00]) // attendu : "hex:1A2B00"
"""


def git(depot, *args, env=None):
    e = dict(os.environ, GIT_AUTHOR_NAME='Testeur', GIT_AUTHOR_EMAIL='personne.test@example.org',
             GIT_COMMITTER_NAME='Testeur', GIT_COMMITTER_EMAIL='personne.test@example.org',
             GIT_AUTHOR_DATE='1700000000 +0700', GIT_COMMITTER_DATE='1700000000 +0700')
    e.update(env or {})
    return subprocess.run(['git', '-C', depot, *args], capture_output=True, text=True, check=True, env=e).stdout.strip()


def ecrire(depot, chemin, contenu):
    p = os.path.join(depot, chemin)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'wb') as f:
        f.write(contenu if isinstance(contenu, bytes) else contenu.encode('utf-8'))


def commit(depot, message, date):
    git(depot, 'add', '-A')
    git(depot, 'commit', '-q', '-m', message, env={'GIT_AUTHOR_DATE': '%d +0700' % date,
                                                     'GIT_COMMITTER_DATE': '%d +0700' % date})
    return git(depot, 'rev-parse', 'HEAD')


class Monde:
    """Construit le monde dans un dossier temporaire ; `chemins` donne tout ce qu'il faut aux outils."""

    def __init__(self):
        self.dossier = tempfile.mkdtemp(prefix='monde-anon-')
        d = self.dossier
        self.bq = os.path.join(d, 'bq')
        self.mt = os.path.join(d, 'mt')
        for depot in (self.bq, self.mt):
            subprocess.run(['git', 'init', '-q', '-b', 'main', depot], check=True)
        ecrire(self.bq, 'src/pont.cpp', '// pont de Ninon\nconst char *mac = "AC:DE:48:00:11:22"; // ACDE48001122\n'
               '// serie PONT1-ACDE48001122, EUI-64 ACDE48FFFE00..., MAC tronquee AC:DE:48:00:11\n'
               'const char *srp = "2E3F405162738495.local";\n'
               'const char *omr = "fd12:3456:789a::/64", *pont = "fd12:3456:789a:0:aaaa:bbbb:cccc:dddd";\n'
               '// empreinte ABCDEF12 ; port /dev/cu.usbmodem123ABCDEF4562 (serie 123ABCDEF456)\n')
        self.bq1 = commit(self.bq, 'Ajouter le pont', 1700000000)
        ecrire(self.bq, 'docs/notes.md', 'Voir %s pour la MAC ac-de-48-00-11-22.\n' % self.bq1[:7])
        self.bq2 = commit(self.bq, 'Noter la MAC, apres %s' % self.bq1[:8], 1700000100)
        ecrire(self.mt, 'docs/releve.json', RELEVE)
        ecrire(self.mt, 'Sources/Tests.swift', TESTS_SWIFT)
        self.mt1 = commit(self.mt, 'Premier releve de Ninon', 1700001000)
        ecrire(self.mt, 'outils/__pycache__/outil.cpython-311.pyc', PYC)
        self.mt2 = commit(self.mt, 'Ajouter un binaire compile', 1700001100)
        ecrire(self.mt, 'docs/capture.png', PNG_ICC)
        self.mt3 = commit(self.mt, 'Ajouter une capture', 1700001200)
        os.remove(os.path.join(self.mt, 'outils/__pycache__/outil.cpython-311.pyc'))
        ecrire(self.mt, 'docs/notes.md', 'Le releve vient de %s ; le pont, de %s. Veilleuse remise ouest.\n' % (
            self.mt1[:8], self.bq1[:10]))
        self.mt4 = commit(self.mt, 'Citer %s et la Veilleuse remise ouest' % self.mt1[:7], 1700001300)
        for nom, contenu in (('inventaire-mt.md', INVENTAIRE_MT), ('inventaire-bq.md', INVENTAIRE_BQ),
                             ('noms.json', json.dumps(NOMS, ensure_ascii=False)),
                             ('decisions.json', json.dumps(DECISIONS, ensure_ascii=False))):
            ecrire(d, nom, contenu)
        self.table = os.path.join(d, 'table.json')

    def args_table(self, sortie=None, graine=None):
        d = self.dossier
        a = ['--inventaire-mt', os.path.join(d, 'inventaire-mt.md'), '--inventaire-bq', os.path.join(d, 'inventaire-bq.md'),
             '--noms', os.path.join(d, 'noms.json'), '--depot', 'mt=' + self.mt, '--depot', 'bq=' + self.bq,
             '--courriel-nouveau', COURRIEL_NOUVEAU, '--decisions-noms', os.path.join(d, 'decisions.json'),
             '--zone-systeme', ZONE_SYSTEME, '--sortie', sortie or self.table]
        if graine is not None:
            a += ['--graine', str(graine)]
        return a

    def generer(self, sortie=None, graine=None):
        import table
        table.main(self.args_table(sortie, graine))
        with open(sortie or self.table, encoding='utf-8') as f:
            return json.load(f)

    def filtrer(self, nom, cible, carte, externe=None):
        import filtre
        args = ['--table', self.table, '--nom-depot', nom, '--source', self.bq if nom == 'bq' else self.mt,
                '--cible', cible, '--carte-sortie', carte, '--auteur', 'Djoko-cli']
        if externe:
            args += ['--carte-externe', externe]
        filtre.main(args)
        with open(carte) as f:
            return json.load(f)

    def nettoyer(self):
        import shutil
        shutil.rmtree(self.dossier, ignore_errors=True)
```

`$O/tests/test_table.py` (fichier entier) :

```python
"""Tests du generateur de la table, sur le monde synthetique (valeurs inventees)."""
import ipaddress
import os
import re
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import monde  # noqa: E402
import commun  # noqa: E402
import table  # noqa: E402


HEXA = ('hote16', 'hote12', 'mac', 'fabrique', 'noeud', 'agent', 'xp', 'at', 'partition', 'empreinte', 'iid',
        'prefixe48', 'prefixe64')


def par(t, nature, reel):
    return next(v for v in t['valeurs'] if v['nature'] == nature and v['reel'] == reel)


def formes(v):
    return {r: n for _, r, n, _, _ in v['formes']}


class GenerateurTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = monde.Monde()
        cls.t = cls.m.generer()

    @classmethod
    def tearDownClass(cls):
        cls.m.nettoyer()

    # -- toutes les ecritures --------------------------------------------------------------
    def test_ecritures_hexa(self):
        v = par(self.t, 'hote16', '2E3F405162738495')
        f, n = formes(v), v['nouveau']
        self.assertEqual(f['2E3F405162738495'], n)
        self.assertEqual(f['2e3f405162738495'], n.lower())
        self.assertEqual(f['2e3f:4051:6273:8495'], ':'.join(n[i:i + 4].lower().lstrip('0') or '0' for i in range(0, 16, 4)))
        self.assertIn('2E:3F:40:51:62:73:84:95', f)
        self.assertIn('2E3F40516273849', f, 'fragment de 15 chiffres, vu seul dans un cas de test')
        self.assertIn(['2E3F405162738495', n, 'partout', None], v['octets'])

    def test_ecritures_mac(self):
        v = par(self.t, 'mac', 'ACDE48001122')
        f, n = formes(v), v['nouveau']
        for d in (':', '-', ''):
            self.assertEqual(f[d.join(['AC', 'DE', '48', '00', '11', '22'])], d.join(n[i:i + 2] for i in range(0, 12, 2)))
        self.assertEqual(f['ac-de-48-00-11-22'], '-'.join(n[i:i + 2] for i in range(0, 12, 2)).lower())
        self.assertEqual(f['AC:DE:48:00:11'], ':'.join(n[i:i + 2] for i in range(0, 10, 2)), 'MAC tronquee')
        self.assertEqual(f['ACDE48FFFE00'], n[:6] + 'FFFE' + n[6:8], 'EUI-64 tronque')
        self.assertTrue(n.startswith('ACDE48'), 'OUI garde')

    def test_ecritures_ipv6(self):
        p = par(self.t, 'prefixe48', 'FD123456789A')
        f = formes(p)
        self.assertIn('fd12:3456:789a', f)
        self.assertIn('FD123456789A', f)
        self.assertIn('fd12', f, 'premier groupe seul (nom de variable)')
        self.assertIn(['FD123456789A', p['nouveau'], 'partout', None], p['octets'])
        i = par(self.t, 'iid', 'A1B2C3D4E5F60789')
        self.assertIn('a1b2:c3d4:e5f6:789', formes(i))
        self.assertIn('a1b2:c3d4:e5f6:0789', formes(i), 'groupes complets')
        self.assertIn('a1b2:c3d4:e5f6', formes(i), 'trois premiers groupes')

    def test_ecritures_textes(self):
        self.assertEqual(formes(par(self.t, 'nom_reseau', 'Reseau1500000000'))['1500000000'],
                         par(self.t, 'nom_reseau', 'Reseau1500000000')['nouveau'][6:])
        pt = par(self.t, 'partition', '61727374')
        self.assertIn('"arst"', formes(pt), 'TXT pt en octets bruts')
        ip = par(self.t, 'ipv4', '10.1.2.3')
        self.assertTrue(ipaddress.IPv4Address(ip['nouveau']) in ipaddress.IPv4Network('192.0.2.0/24'))
        pre = formes(par(self.t, 'prenom', 'Ninon'))
        self.assertEqual((pre['Ninon'], pre['NINON'], pre['ninon']), ('Djoko', 'DJOKO', 'djoko'))
        serie = par(self.t, 'serie', '123ABCDEF456')['nouveau']
        self.assertTrue(serie[:3].isdigit() and serie[3:9].isalpha() and serie[9:].isdigit())
        self.assertEqual(par(self.t, 'courriel', 'personne.test@example.org')['nouveau'], monde.COURRIEL_NOUVEAU)
        mesh = par(self.t, 'meshcop', 'Enceinte Modele Pigeonnier')
        self.assertIn('Enceinte Modele pigeonnier', formes(mesh), 'qualificatif en minuscules')

    # -- valeurs derivees ------------------------------------------------------------------
    def test_valeurs_derivees(self):
        xp = par(self.t, 'xp', '1A2B3C4D5E6F7A8B')['nouveau']
        self.assertEqual(par(self.t, 'prefixe64', 'FD1A2B3C4D5E7A8B')['nouveau'], table.infra(xp))
        mac = par(self.t, 'mac', 'AC1122334455')['nouveau']
        self.assertEqual(par(self.t, 'hote16', 'AC11223344550000')['nouveau'], mac + '0000')
        eui = formes(par(self.t, 'mac', 'AC1122334455'))['ae11:22ff:fe33:4455']
        self.assertEqual(eui, table.seq(table.eui64(mac)))
        xa = par(self.t, 'hote16', '9F8E7D6C5B4A3928')['nouveau']
        self.assertEqual(par(self.t, 'meshcop', 'Borne Modele #3928')['nouveau'], 'Borne Modele #' + xa[-4:])
        self.assertEqual(par(self.t, 'hote_lisible', 'Borne-Modele-4455')['nouveau'], 'Borne-Modele-' + mac[-4:])
        self.assertEqual(par(self.t, 'hote_lisible', 'Enceinte-Modele-Pigeonnier')['nouveau'],
                         par(self.t, 'meshcop', 'Enceinte Modele Pigeonnier')['nouveau'].replace(' ', '-'))
        p1 = par(self.t, 'partition', '61727374')['nouveau']
        self.assertEqual(par(self.t, 'partition', '74737261')['nouveau'], bytes.fromhex(p1)[::-1].hex().upper())
        at = par(self.t, 'at', '00005F5E10AB0000')
        s = int(at['nouveau'][4:12], 16)
        f = formes(at)
        self.assertEqual(f['2020-09-13'], table.iso(s)[:10])
        self.assertEqual(f['1_600_000_000'], '{:_}'.format(s & ~0xFF))
        self.assertEqual(f['2020-09-13T12:26:40Z'], table.iso(s & ~0xFF))
        aller = commun.Moteur([(c, r, n) for v in self.t['valeurs'] for c, r, n, _, _ in v['formes']])
        fab, noe = par(self.t, 'fabrique', '2BADCAFE12345678')['nouveau'], par(self.t, 'noeud', '0000000012345678')['nouveau']
        self.assertEqual(aller.appliquer('2BADCAFE12345678-0000000012345678'), fab + '-' + noe, 'instance Matter')
        maille = par(self.t, 'prefixe64', 'FDABCDEF12345678')
        self.assertEqual(formes(maille)['FD00111122225678'], 'FD0011112222' + maille['nouveau'][12:],
                         'sous-reseau reel derriere un /48 factice de la sonde')

    # -- ordre -------------------------------------------------------------------------------
    def test_ordre_garde(self):
        for nature in ('hote16', 'fabrique', 'noeud', 'partition', 'prefixe48', 'iid', 'mac'):
            vs = [v for v in self.t['valeurs'] if v['nature'] == nature and v['nouveau']]
            self.assertEqual(sorted(vs, key=lambda v: v['reel']), sorted(vs, key=lambda v: v['nouveau']), nature)
        ips = [v for v in self.t['valeurs'] if v['nature'] == 'ipv4']
        self.assertTrue(all(ipaddress.IPv4Address(v['nouveau']) for v in ips))
        fab = sorted(v['reel'] for v in self.t['valeurs'] if v['nature'] == 'fabrique')
        self.assertLess(par(self.t, 'fabrique', fab[0])['nouveau'], par(self.t, 'fabrique', fab[1])['nouveau'])

    # -- collisions --------------------------------------------------------------------------
    def test_aucune_collision(self):
        nouveaux = [(c, n) for v in self.t['valeurs'] if v['nature'] != 'prenom' for c, _, n, _, _ in v['formes']]
        reels = {r for v in self.t['valeurs'] for _, r, _, _, _ in v['formes']}
        corpus = '\0'.join(t for d in (self.m.mt, self.m.bq) for _, t in commun.Historique(d).textes())
        for c, n in nouveaux:
            self.assertNotIn(n, reels - {n})
            g, d = commun.BORNES[c]
            import re
            self.assertIsNone(re.search(g + re.escape(n) + d, corpus), 'une remplacante est deja dans un depot')
        fen = set()
        for v in self.t['valeurs']:
            if v['nature'] in ('hote16', 'mac', 'fabrique', 'noeud', 'agent', 'xp', 'partition'):
                fen |= table.fenetres_libres(v['reel'], len(v['garde'])) - {f for f in table.fenetres(v['reel']) if table.triviale(f)}
        for v in self.t['valeurs']:
            if v['nature'] in ('hote16', 'mac', 'fabrique', 'noeud', 'agent', 'xp', 'partition') and v['nouveau'] != v['reel']:
                self.assertFalse(table.fenetres_libres(v['nouveau'], len(v['garde'])) & fen, v['nature'])

    def test_controle_refuse_une_remplacante_deja_presente(self):
        g = table.Generateur(1, {'mt': commun.Historique(self.m.mt)}, {}, monde.DECISIONS, 'x@y.z', None)
        v = g.valeur('hote16', '2E3F405162738495')
        v.forme('brut', '2E3F405162738495', '1A2B3C4D5E6F7A8B', 'piege')
        with self.assertRaises(table.Echec):
            g.controler()

    def test_tirage_evite_une_valeur_deja_prise(self):
        g = table.Generateur(3, {'mt': commun.Historique(self.m.mt)}, {}, monde.DECISIONS, 'x@y.z', None)
        g.nouveaux_vus.add('A0')
        for _ in range(200):
            r = g.tirer_ordonne(['A5'], 2, lambda r, c: True, garde=lambda h: 'A')
            self.assertNotEqual(r['A5'], 'A0')
            g.nouveaux_vus.discard(r['A5'])

    # -- forme -------------------------------------------------------------------------------
    def test_memes_longueurs_et_casse(self):
        for v in self.t['valeurs']:
            if v['nature'] in table.LONGUEUR_LIBRE:
                continue
            for c, r, n, quoi, _ in v['formes']:
                self.assertEqual(len(r), len(n), (v['nature'], quoi))
                if v['nature'] in HEXA and re.fullmatch('[0-9A-Fa-f: -]+', r) and any(ch in 'abcdef' for ch in r) \
                        and not any(ch in 'ABCDEF' for ch in r):
                    self.assertEqual(n, n.lower(), (v['nature'], quoi))

    def test_noms(self):
        noms = self.t['noms']
        self.assertEqual(noms['Veilleuse remise ouest']['portee'], 'phrase')
        self.assertEqual(noms['Veilleuse']['portee'], 'garde')
        self.assertEqual(noms['Orangerie']['portee'], 'garde')
        self.assertEqual(noms['Borne Modele Z9']['portee'], 'garde')
        n = par(self.t, 'nom', 'Veilleuse remise ouest')['nouveau']
        self.assertEqual(len(n), len('Veilleuse remise ouest'))
        self.assertTrue(n.split()[0] in ('Lampadaire', 'Applique'), 'meme genre d\'appareil')
        self.assertNotIn(n.lower(), {x.lower() for x in self.t['noms_reels']})
        f = par(self.t, 'fuseau', 'UTC+7')['nouveau']
        self.assertIn(f, table.zones_au_decalage(7, monde.ZONE_SYSTEME))

    def test_deterministe(self):
        autre = os.path.join(self.m.dossier, 'table-bis.json')
        self.assertEqual(self.m.generer(autre), self.t)
        troisieme = os.path.join(self.m.dossier, 'table-ter.json')
        self.assertNotEqual(self.m.generer(troisieme, graine=7)['valeurs'], self.t['valeurs'])


if __name__ == '__main__':
    unittest.main()
```

`$O/tests/test_filtre.py` (fichier entier) :

```python
"""Tests du filtre et des controles, sur le monde synthetique (valeurs inventees)."""
import json
import os
import shutil
import subprocess
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import monde  # noqa: E402
import commun  # noqa: E402
import controles  # noqa: E402


class FiltreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = monde.Monde()
        cls.t = cls.m.generer()
        d = cls.m.dossier
        cls.bq, cls.mt = os.path.join(d, 'bq-reecrit.git'), os.path.join(d, 'mt-reecrit.git')
        cls.carte_bq = cls.m.filtrer('bq', cls.bq, os.path.join(d, 'carte-bq.json'))
        cls.carte_mt = cls.m.filtrer('mt', cls.mt, os.path.join(d, 'carte-mt.json'), os.path.join(d, 'carte-bq.json'))
        cls.h_mt, cls.h_bq = commun.Historique(cls.mt), commun.Historique(cls.bq)

    @classmethod
    def tearDownClass(cls):
        cls.m.nettoyer()

    def fichier(self, h, commit, chemin):
        return h.blobs[h.arbres[commit][chemin][1]].decode('utf-8')

    def test_contenu_chemins_messages(self):
        for depot, carte in ((self.mt, self.carte_mt), (self.bq, self.carte_bq)):
            trouve, faux = controles.balayage(self.t, depot, carte, self.carte_bq)
            self.assertEqual(trouve, {}, depot)
        tete = self.carte_mt[self.m.mt4]
        releve = self.fichier(self.h_mt, tete, 'docs/releve.json')
        for reel in ('1A2B3C4D5E6F7A8B', 'fd12:3456:789a', '"arst"', 'Veilleuse remise ouest', 'UTC+7', '10.1.2.3',
                     '2020-09-13', 'pigeonnier', 'Pigeonnier', '3beef00d12abcdef'):
            self.assertNotIn(reel, releve)
        self.assertIn('"Veilleuse"', releve, 'un nom d\'un seul mot est garde')
        self.assertIn('"Orangerie"', releve, 'un mot courant de piece est garde')
        swift = self.fichier(self.h_mt, tete, 'Sources/Tests.swift')
        for reel in ('0x1A, 0x2B, 0x3C, 0x4D,\n                   0x5E', '"1a2b"', '[0x1A, 0x2B]', '1A2B3C', '0x87654321',
                     '2E3F40516273849Z', 'Ninon', '1_600_000_000', 'fd12)', 'FD00111122225678',
                     '0x22, 0x22, 0x56, 0x78', '0x1A, 0x2B, 0x00', '"hex:1A2B00"'):
            self.assertNotIn(reel, swift)
        self.assertIn('/Users/Djoko/Dev', swift)

    def test_auteurs_et_dates(self):
        for h in (self.h_mt, self.h_bq):
            for c in h.commits:
                e, _ = h.entetes_et_message(c)
                for l in e.splitlines():
                    if l.startswith('author ') or l.startswith('committer '):
                        self.assertIn(' Djoko-cli <%s> ' % monde.COURRIEL_NOUVEAU, l)
        stats, ecarts = controles.forme(self.t, 'mt', self.m.mt, self.mt, self.carte_mt)
        self.assertEqual(ecarts, {})
        self.assertEqual(stats['commits'], 4)

    def test_pyc_et_png(self):
        self.assertFalse(any(p.endswith('.pyc') for p in self.h_mt.chemins))
        pyc = commun.arbre(self.m.mt, self.m.mt2)['outils/__pycache__/outil.cpython-311.pyc'][1]
        tous = commun.git(self.mt, 'cat-file', '--batch-all-objects', '--batch-check=%(objectname)').split()
        self.assertNotIn(pyc, tous, 'le .pyc n\'est meme pas un objet orphelin')
        png = self.h_mt.blobs[self.h_mt.arbres[self.carte_mt[self.m.mt3]]['docs/capture.png'][1]]
        self.assertEqual([t for t, _ in commun.morceaux_png(png)], ['IHDR', 'IDAT', 'IEND'])
        self.assertEqual(png, commun.png_sans_iccp(monde.PNG_ICC))

    def test_identifiants_de_commit(self):
        _, msg = self.h_mt.entetes_et_message(self.carte_mt[self.m.mt4])
        self.assertIn(self.carte_mt[self.m.mt1][:7], msg)
        self.assertNotIn(self.m.mt1[:7], msg)
        notes = self.fichier(self.h_mt, self.carte_mt[self.m.mt4], 'docs/notes.md')
        self.assertIn(self.carte_mt[self.m.mt1][:8], notes)
        self.assertIn(self.carte_bq[self.m.bq1][:10], notes, 'identifiant d\'un autre depot deja reecrit')
        _, msg = self.h_bq.entetes_et_message(self.carte_bq[self.m.bq2])
        self.assertIn(self.carte_bq[self.m.bq1][:8], msg)

    def test_reversibilite(self):
        stats, ecarts = controles.reversibilite(self.t, 'mt', self.m.mt, self.mt, self.carte_mt, self.carte_bq)
        self.assertEqual(ecarts, {})
        self.assertEqual(stats['pyc_retires'], 2, 'le .pyc etait dans deux commits')
        self.assertEqual(stats['png'], 1, 'un seul blob PNG, dans deux commits')
        stats, ecarts = controles.reversibilite(self.t, 'bq', self.m.bq, self.bq, self.carte_bq)
        self.assertEqual(ecarts, {})

    def test_deterministe(self):
        autre = os.path.join(self.m.dossier, 'mt-bis.git')
        carte = self.m.filtrer('mt', autre, os.path.join(self.m.dossier, 'carte-mt-bis.json'),
                               os.path.join(self.m.dossier, 'carte-bq.json'))
        self.assertEqual(carte, self.carte_mt)
        self.assertEqual(commun.git(autre, 'rev-parse', 'main'), commun.git(self.mt, 'rev-parse', 'main'))


class ControlesTests(unittest.TestCase):
    """Les controles trouvent ce qu'on y a mis expres."""

    @classmethod
    def setUpClass(cls):
        cls.m = monde.Monde()
        cls.t = cls.m.generer()
        d = cls.m.dossier
        cls.bq = os.path.join(d, 'bq-reecrit.git')
        cls.carte_bq = cls.m.filtrer('bq', cls.bq, os.path.join(d, 'carte-bq.json'))

    @classmethod
    def tearDownClass(cls):
        cls.m.nettoyer()

    def piege(self, chemin, contenu):
        """Un clone du depot reecrit, avec un commit de plus qui ajoute `contenu`."""
        d = os.path.join(self.m.dossier, 'piege-%d' % len(os.listdir(self.m.dossier)))
        subprocess.run(['git', 'clone', '-q', '--bare', self.bq, d], check=True)
        travail = d + '-travail'
        subprocess.run(['git', 'clone', '-q', d, travail], check=True)
        monde.ecrire(travail, chemin, contenu)
        monde.commit(travail, 'piege', 1700009999)
        subprocess.run(['git', '-C', travail, 'push', '-q', d, 'main'], check=True)
        shutil.rmtree(travail)
        return d

    def trouve(self, contenu, chemin='piege.txt'):
        trouve, _ = controles.balayage(self.t, self.piege(chemin, contenu), self.carte_bq)
        return trouve

    def test_rien_sur_le_depot_reecrit(self):
        self.assertEqual(controles.balayage(self.t, self.bq, self.carte_bq)[0], {})

    def test_valeur_reelle_toute_casse(self):
        self.assertIn('valeur reelle (hote16)', self.trouve('x 2e3f405162738495 y'))

    def test_fragment_de_huit_chiffres(self):
        self.assertTrue(any(k.startswith('fragment hexa de 12') for k in self.trouve('id 405162738495AB')))

    def test_nom_prenom_adresse(self):
        self.assertIn('nom reel en mot entier', self.trouve('« Veilleuse remise ouest »'))
        self.assertIn('prenom, nom ou adresse electronique', self.trouve('signe nINON'))
        self.assertIn('prenom, nom ou adresse electronique', self.trouve('ecrire a personne.test@example.org'))

    def test_fuseau_png_pyc(self):
        t = dict(self.t, zone_systeme='Pacific/Nulle')
        trouve, _ = controles.balayage(t, self.piege('note.txt', 'heure de Pacific/Nulle'), self.carte_bq)
        self.assertIn('nom du fuseau du Mac', trouve)
        self.assertIn('PNG avec profil ICC', self.trouve(monde.PNG_ICC, 'a.png'))
        self.assertIn('fichier .pyc', self.trouve(b'\0', 'x/__pycache__/a.pyc'))

    def test_reversibilite_voit_un_texte_abime(self):
        t = json.loads(json.dumps(self.t))
        v = next(v for v in t['valeurs'] if v['nature'] == 'empreinte')
        v['formes'] = [[c, r, n[:-1] + ('0' if n[-1] != '0' else '1'), q, d] for c, r, n, q, d in v['formes']]
        _, ecarts = controles.reversibilite(t, 'bq', self.m.bq, self.bq, self.carte_bq)
        self.assertIn('texte non retrouve a l\'octet pres', ecarts)

    def test_forme_voit_un_commit_en_moins(self):
        carte = dict(self.carte_bq)
        carte.pop(self.m.bq1)
        _, ecarts = controles.forme(self.t, 'bq', self.m.bq, self.bq, carte)
        self.assertIn('commits differents', ecarts)


if __name__ == '__main__':
    unittest.main()
```

---

### Task 2: Les décisions, avec Djoko

**Files:**
- Lire : `$A/decisions-noms.json`, `$A/table.json`
- Créer : `$A/decisions-resume.txt` (privé)

**Interfaces:**
- Consumes : la table de la répétition.
- Produces : `decisions-noms.json` validé ; s'il change, la table de la tâche 4 change aussi.

`decisions-noms.json` a six clés : `generiques` (les mots courants de pièce, gardés), `marques` (un nom qui en contient une est un nom de produit), `modeles` (les débuts de nom d'instance meshcop qui sont des modèles du fabricant), `genres` (`[mot, [appareils]]` : le genre d'appareil d'un nom inventé), `remplacer` et `garder` (les exceptions de Djoko). Exemple, aux valeurs inventées du monde des tests :

```json
{"generiques": ["Orangerie"], "marques": ["Modele"], "modeles": ["Enceinte Modele", "Borne Modele"],
 "genres": [["remise", ["Lampadaire", "Applique"]]], "remplacer": [], "garder": []}
```

- [ ] **Step 1 : le résumé privé, que Djoko lit lui-même.**

Run :

```bash
A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; /usr/bin/python3 - "$A" <<'EOF'
import json, sys
A = sys.argv[1]
t = json.load(open(A + '/table.json', encoding='utf-8'))
with open(A + '/decisions-resume.txt', 'w', encoding='utf-8') as f:
    for nom, p in sorted(t['noms'].items()):
        f.write('%-7s %s  (%s)\n' % (p['portee'], nom, p['raison']))
    f.write('\n')
    for v in t['valeurs']:
        if v['nature'] in ('nom', 'meshcop', 'hote_lisible', 'fuseau'):
            f.write('%s : %s -> %s  %s\n' % (v['nature'], v['reel'], v['nouveau'], v['derivee']))
print('resume ecrit')
EOF
```

Expected : `resume ecrit`.

- [ ] **Step 2 : avec Djoko.** Lui demander d'ouvrir `.superpowers/anonymisation/decisions-resume.txt` (dans Maillage Thread) et de valider, ou de corriger :
  1. la règle des noms (précision 2) : 8 remplacés, 24 gardés ;
  2. les instances meshcop et les noms d'hôte lisibles (précision 3) ;
  3. le fuseau de remplacement (précision 5) ;
  4. ce que la spec garde (précision 7), dont les noms de port USB et l'identifiant de session Claude, et le projet 3MF laissé intact (précision 8) ;
  5. les préfixes gardés (précision 4).

  Une correction de noms se fait dans `decisions-noms.json`, par `remplacer` ou `garder`, puis la table est régénérée par la tâche 4. Les têtes y différeront alors de la répétition, et toutes les suites de la tâche 5 deviennent la seule preuve.

Expected : l'accord de Djoko, ou ses corrections.

---

### Task 3: Les archives, avec Djoko

**Files:**
- Créer : `~/Documents/Archives-anonymisation/maillage-thread-<date>.bundle`, `~/Documents/Archives-anonymisation/benq-<date>.bundle`

**Interfaces:**
- Produces : la seule copie de l'ancien historique après la tâche 6 (spec, section 3.1).

`~/Documents` est synchronisé par iCloud : les archives y montent, privées.

- [ ] **Step 1 : avec l'accord de Djoko, créer les archives.**

Run :

```bash
D=$(date +%Y%m%d); mkdir -p ~/Documents/Archives-anonymisation && git -C ~/Dev/maillage-thread bundle create ~/Documents/Archives-anonymisation/maillage-thread-$D.bundle --all && git -C ~/Documents/Dev/esp32/benq bundle create ~/Documents/Archives-anonymisation/benq-$D.bundle --all; ls -l ~/Documents/Archives-anonymisation
```

Expected : deux fichiers d'environ 4 et 8 Mo.

- [ ] **Step 2 : les vérifier, et relire le dernier commit d'une copie restaurée.**

Run :

```bash
D=$(date +%Y%m%d); V=$(mktemp -d) && git init -q $V/vide && for b in maillage-thread benq; do git -C $V/vide bundle verify ~/Documents/Archives-anonymisation/$b-$D.bundle 2>&1 | tail -1; git clone -q ~/Documents/Archives-anonymisation/$b-$D.bundle $V/$b && echo "$b : $(git -C $V/$b log -1 --format='%h %s' main | cut -c1-50) ; $(git -C $V/$b rev-list --count main) commits"; done; mkdir -p ~/.Trash/anon-verif-archives-$D && mv $V ~/.Trash/anon-verif-archives-$D/
```

Expected : deux lignes `… is okay`, puis `maillage-thread : 8297321 Ecrire la spec de l'anonymisation des depots … ; 420 commits` et `benq : e114cd5 Retirer des README les condensateurs de decouplage… ; 143 commits`.

---

### Task 4: La réécriture, sur des miroirs neufs

**Files:**
- Créer : `$X/maillage-thread.git`, `$X/benq.git` (miroirs), `$X/*-reecrit.git`, `$X/carte-*.json`, `$X/controles/*.txt`, `$E/noreply.txt`, `$E/table.json`

**Interfaces:**
- Consumes : les outils (tâche 1), les décisions (tâche 2), les dépôts de travail, en lecture.
- Produces : `$X/maillage-thread-reecrit.git` et `$X/benq-reecrit.git`, leurs cartes, et la table de l'exécution.

- [ ] **Step 1 : les dépôts de travail sont ceux de la répétition.**

Run : `for d in ~/Dev/maillage-thread ~/Documents/Dev/esp32/benq; do echo "$(git -C $d rev-parse --short main) $(git -C $d status --short | wc -l | tr -d ' ')"; done; git -C ~/Dev/maillage-thread branch --format='%(refname:short)'`

Expected : `8297321 0` puis `e114cd5 0`, puis les branches `anon-plan` et `main`. Si `main` a bougé, s'arrêter : les inventaires ne couvrent pas les nouveaux commits (`git log 8297321..main --oneline`), et Djoko décide.

- [ ] **Step 2 : l'adresse noreply du compte, dans un fichier privé, jamais affichée.**

Run :

```bash
E=$HOME/Dev/maillage-thread/.superpowers/anonymisation/execution; mkdir -p $E && gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"' > $E/noreply.txt && grep -c '@users.noreply.github.com$' $E/noreply.txt && cmp -s $E/noreply.txt "$S/anon-repetition/noreply.txt" && echo "meme adresse qu'a la repetition"
```

Expected : `1`, puis `meme adresse qu'a la repetition`.

- [ ] **Step 3 : les miroirs ; le plan n'entre pas dans la réécriture.**

Run :

```bash
X=$S/anon-execution; mkdir -p $X && git clone --quiet --mirror --no-local ~/Dev/maillage-thread $X/maillage-thread.git && git clone --quiet --mirror --no-local ~/Documents/Dev/esp32/benq $X/benq.git && git -C $X/maillage-thread.git update-ref -d refs/heads/anon-plan && for m in maillage-thread benq; do git -C $X/$m.git for-each-ref --format='%(refname)'; done
```

Expected : `refs/heads/main`, `refs/remotes/origin/HEAD` et `refs/remotes/origin/main`, pour chaque miroir.

- [ ] **Step 4 : table, filtre et contrôles** (environ 6 minutes).

Run :

```bash
A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; X=$S/anon-execution; NOREPLY_FICHIER=$A/execution/noreply.txt INVENTAIRE_SCRIPTS=$A/scripts-inventaires NOMS_SCRIPTS=$A/scripts-inventaires $A/outils/reecrire.sh $X $X/maillage-thread.git $X/benq.git $A/execution/table.json > $X/reecrire.log 2>&1; echo "code $?"; grep -E '^(commits reecrits|trouve|ecarts)' $X/reecrire.log | cut -c1-80
```

Expected : `code 0` ; `commits reecrits : 143 ; tete de main : a136f06ae06ce17ca14f5cfe70d39ffbc832a986` et `commits reecrits : 420 ; tete de main : 21428e575e63276f8f1134657bc19a189da788ed` ; quatre `trouve : aucun` et quatre `ecarts : aucun`. Les comptes et faux positifs de `$X/controles/` sont ceux de la répétition (section du même nom, plus haut).

- [ ] **Step 5 : la même table et les mêmes têtes qu'à la répétition.**

Run :

```bash
A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; X=$S/anon-execution; R=$S/anon-repetition; cmp $A/execution/table.json $A/table.json && echo "table identique"; for n in benq maillage-thread; do [ "$(git -C $X/$n-reecrit.git rev-parse main)" = "$(git -C $R/$n-reecrit.git rev-parse main)" ] && echo "$n : tete identique" || echo "$n : TETE DIFFERENTE"; cmp -s $X/carte-$n.json $R/carte-$n.json && echo "$n : carte identique"; done
```

Expected : `table identique`, puis `tete identique` et `carte identique` pour les deux dépôts. Si Djoko a changé une décision à la tâche 2, la table et les têtes diffèrent : le dire, et continuer, car les contrôles du step 4 et les tests de la tâche 5 décident. Sinon, une différence arrête le plan : on la comprend d'abord (une copie de `noms.json` nouvelle, un outil modifié).

---

### Task 5: La remise en état, et les tests complets

**Files:**
- Modify (dans `$X/travail-maillage-thread`) : `docs/releves/2026-09-29/README.md`, `docs/superpowers/plans/2026-09-29-maillage-thread-plan3a-sonde.md`, `docs/superpowers/plans/2026-09-30-maillage-thread-plan3b-journal.md`
- Create (dans `$X/travail-maillage-thread`) : `docs/superpowers/plans/2026-10-05-anonymisation.md`
- Modify (dans `$X/travail-benq`) : `docs/PLAN-PILOTE-HALO1.fr.md`, `docs/PLAN-PILOTE-HALO1.md`

**Interfaces:**
- Consumes : les dépôts réécrits et leurs cartes (tâche 4), la branche `anon-plan`.
- Produces : les `main` définitifs, dans `$X/maillage-thread-reecrit.git` et `$X/benq-reecrit.git`.

**Ce que corrige le commit de remise en état** (spec, section 5) :
- **Maillage Thread :** l'empreinte SHA-256 de la capture anonymisée de la sonde change avec elle, et les plans 3a et 3b la citent ; le README de la capture dit que la réécriture a remplacé la partition et le 4e groupe du préfixe de maillage local, que l'anonymiseur gardait, et que le canal radio est gardé ;
- **pont Halo :** le plan du pilote demandait de ne pas commiter le `.pyc` de l'audit ; il dit maintenant que la réécriture l'a retiré de tout l'historique.

Les tests n'ont rien révélé d'autre : à la répétition, toutes les suites passent dès l'historique réécrit.

- [ ] **Step 1 : les clones de travail, et la remise en état.**

Run :

```bash
O=$HOME/Dev/maillage-thread/.superpowers/anonymisation/outils; X=$S/anon-execution; git clone -q $X/maillage-thread-reecrit.git $X/travail-maillage-thread && git clone -q $X/benq-reecrit.git $X/travail-benq && /usr/bin/python3 $O/remettre_en_etat.py maillage $X/travail-maillage-thread $X/maillage-thread.git && /usr/bin/python3 $O/remettre_en_etat.py benq $X/travail-benq; git -C $X/travail-maillage-thread add docs/releves/2026-09-29/README.md docs/superpowers/plans/2026-09-29-maillage-thread-plan3a-sonde.md docs/superpowers/plans/2026-09-30-maillage-thread-plan3b-journal.md && git -C $X/travail-benq add docs/PLAN-PILOTE-HALO1.fr.md docs/PLAN-PILOTE-HALO1.md && for n in maillage-thread benq; do echo "$n $(git -C $X/travail-$n write-tree)"; done
```

Expected : `empreinte de la capture remplacee dans 2 fichier(s) ; README de la capture corrige`, les trois chemins de Maillage Thread, `plan du pilote complete (2 fichiers)`, les deux chemins du pont, puis les arbres `maillage-thread 719a0c32e78a0fd8112cf3fe0c813b054a2b4be3` et `benq cae7c2e9a9b384c14b51fdf5ca614a4320f5cd41`, ceux de la répétition (si la table n'a pas changé). Les fichiers restent ajoutés à l'index pour le step 2.

- [ ] **Step 2 : les commits de remise en état.**

Run :

```bash
A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; X=$S/anon-execution; cd $X/travail-maillage-thread && git -c user.name=Djoko-cli -c user.email="$(cat $A/execution/noreply.txt)" commit -q -F - <<'EOF'
Remettre en etat le depot apres la reecriture de l'historique

L'empreinte SHA-256 de la capture anonymisee de la sonde change avec elle :
les plans 3a et 3b citent la nouvelle. Le README de la capture dit ce que la
reecriture a remplace (la partition et le 4e groupe du prefixe de maillage
local, que l'anonymiseur gardait) : la capture ne garde plus d'identifiant reel.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
cd $X/travail-benq && git -c user.name=Djoko-cli -c user.email="$(cat $A/execution/noreply.txt)" commit -q -F - <<'EOF'
Remettre en etat le depot apres la reecriture de l'historique

Le plan du pilote demandait de ne pas commiter le .pyc de l'audit : la
reecriture du 05/10 l'a retire de tout l'historique, le plan le dit.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git -C $X/travail-maillage-thread status --short | wc -l; git -C $X/travail-benq status --short | wc -l
```

Expected : `0` et `0`.

- [ ] **Step 3 : le plan, ajouté tel quel au nouveau `main`** (précision 11), avec le message de son dernier commit.

Run :

```bash
A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; X=$S/anon-execution; P=docs/superpowers/plans/2026-10-05-anonymisation.md; cd $X/travail-maillage-thread && git -C ~/Dev/maillage-thread show anon-plan:$P > $P && git -C ~/Dev/maillage-thread log -1 --format=%B anon-plan > $A/execution/message-plan.txt && /usr/bin/python3 $A/outils/controles.py fichiers --table $A/execution/table.json $P $A/execution/message-plan.txt && git add $P && git -c user.name=Djoko-cli -c user.email="$(cat $A/execution/noreply.txt)" commit -q -F $A/execution/message-plan.txt && git log -1 --format='%an %s' | cut -c1-60
```

Expected : `trouve : aucun` (et le nom du projet en faux positif connu), puis `Djoko-cli Ecrire le plan de l'anonymisation …`.

- [ ] **Step 4 : Maillage Thread, la suite entière en français, puis en anglais** (environ 12 minutes ; aucune autre compilation pendant ce temps).

Run :

```bash
X=$S/anon-execution; mkdir -p "$HOME/Library/Caches/maillage-anon-exec" && cd $X/travail-maillage-thread && DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-anon-exec" TMPDIR="$HOME/Library/Caches/maillage-anon-exec/" outils/tester.sh 2>&1 | grep -E "Test run with|\*\* TEST|code"; TMPDIR="$HOME/Library/Caches/maillage-anon-exec/" xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-anon-exec" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-anon-exec/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-anon-exec/maillage-tests-en.log"
```

Expected, deux fois : `✔ Test run with 420 tests in 42 suites passed`, `✔ Test run with 391 tests in 32 suites passed`, `** TEST SUCCEEDED **` (et `code 0` pour le français). Si seul `premierClicDansUneFenetreInactive()` échoue : faits établis.

- [ ] **Step 5 : Maillage Thread, les tests Python, les tests hôte de la sonde et les mesures.**

Run :

```bash
X=$S/anon-execution; cd $X/travail-maillage-thread && /usr/bin/python3 -m unittest discover -s sonde/test 2>&1 | tail -2; sh sonde/test/lancer.sh 2>&1 | tail -2; DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-anon-exec" TMPDIR="$HOME/Library/Caches/maillage-anon-exec/" outils/mesurer.sh 2>&1 | grep -E "mesure :|Test run with|code"
```

Expected : `OK` (141 tests) ; `test_h1 : 121 verification(s), 0 echec(s)` et `test_distant : 145 verification(s), 0 echec(s)` ; trois lignes `mesure :`, `22 tests in 2 suites passed`, `code 0`.

- [ ] **Step 6 : pont Halo, firmware et tests hôte.** La sortie des tests de `halo-routes` porte les routes réelles du Mac : elle va dans un fichier privé.

Run :

```bash
X=$S/anon-execution; mkdir -p "$HOME/Library/Caches/maillage-anon-exec/benq" && cd $X/travail-benq && pio run -e esp32c6thread -e esp32c6supermini > $X/pio.txt 2>&1; echo "pio $?"; grep -E '^esp32c6' $X/pio.txt; TMPDIR="$HOME/Library/Caches/maillage-anon-exec/benq/" sh tools/test_halo1.sh 2>&1 | grep -E 'verification|ligne\(s\) machine' | cut -c1-70; /usr/bin/python3 tools/test_halo_udp.py 2>&1 | tail -1; sh tools/macos/halo-routes/tests.sh > $X/routes.txt 2>&1; echo "halo-routes $?"; grep -o 'halo-routes : [0-9]* verification(s), [0-9]* echec(s)' $X/routes.txt; (cd apps/macos && /usr/bin/python3 Outils/generer_demo.py > /dev/null; echo "demo $?"); git status --short | wc -l
```

Expected : `pio 0`, `esp32c6supermini SUCCESS` et `esp32c6thread SUCCESS` ; `2232498 verification(s), 0 echec(s)`, `301 verification(s) JSON, 0 echec(s)`, `test_h1 : 121 verification(s), 0 echec(s)` et deux lignes `ligne(s) machine, 0 erreur(s)` ; `OK` ; `halo-routes 0` et `halo-routes : 47 verification(s), 0 echec(s)` ; `demo 0` et `0` (la démo régénérée est identique).

- [ ] **Step 7 : pont Halo, Halo Compagnon en français puis en anglais.**

Run :

```bash
X=$S/anon-execution; cd $X/travail-benq/apps/macos && xcodegen generate --quiet && for l in fr en; do if [ $l = en ]; then L=(-testLanguage en -testRegion US); else L=(); fi; TMPDIR="$HOME/Library/Caches/maillage-anon-exec/benq/" xcodebuild -project HaloCompagnon.xcodeproj -scheme HaloCompagnon -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-anon-exec-halo" "${L[@]}" test > "$HOME/Library/Caches/maillage-anon-exec/halo-$l.log" 2>&1; echo "$l $?"; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-anon-exec/halo-$l.log"; done
```

Expected, deux fois : `0`, `144 tests in 20 suites passed`, `34 tests in 7 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 8 : le balayage des clones de travail, puis les `main` définitifs dans les dépôts réécrits.**

Run :

```bash
A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; X=$S/anon-execution; T=$A/execution/table.json; /usr/bin/python3 $A/outils/controles.py balayage --table $T --depot $X/travail-benq --carte $X/carte-benq.json | head -1; /usr/bin/python3 $A/outils/controles.py balayage --table $T --depot $X/travail-maillage-thread --carte $X/carte-maillage-thread.json --carte-externe $X/carte-benq.json | head -1; for n in maillage-thread benq; do git -C $X/$n-reecrit.git fetch -q $X/travail-$n main:main && echo "$n : $(git -C $X/$n-reecrit.git rev-list --count main) commits"; done
```

Expected : deux `trouve : aucun`, puis `maillage-thread : 422 commits` et `benq : 144 commits`.

---

### Task 6: Les dépôts de travail, avec Djoko

**Files:**
- Modify : `~/Dev/maillage-thread/.git`, `~/Documents/Dev/esp32/benq/.git` (historique, références, reflog) et leurs arbres de travail

**Interfaces:**
- Consumes : les `main` définitifs (tâche 5), les archives (tâche 3).
- Produces : des dépôts de travail sans l'ancien historique (spec, section 6.1).

Le geste est sans retour hors de l'archive : l'accord de Djoko porte sur les deux dépôts, l'un après l'autre. Les fichiers ignorés (`.superpowers/`, `noms.json`, `Local.xcconfig`, `logs/`, `.pio/`…) ne bougent pas.

- [ ] **Step 1 : avec l'accord de Djoko, Maillage Thread.** Le worktree et la branche du plan partent : le plan est dans le nouveau `main`.

Run :

```bash
X=$S/anon-execution; cd ~/Dev/maillage-thread && test -z "$(git status --short)" && git worktree remove "$S/anon-plan" && git fetch -q $X/maillage-thread-reecrit.git main && git checkout -q -B main FETCH_HEAD && git branch -D anon-plan > /dev/null && git update-ref --no-deref -d refs/remotes/origin/HEAD && git update-ref -d refs/remotes/origin/main && git reflog expire --expire=now --all && git gc --prune=now --quiet && echo "$(git rev-list --count main) commits ; references : $(git for-each-ref --format='%(refname)' | tr '\n' ' ')"; git cat-file -e 8297321 2>/dev/null && echo "ANCIEN HISTORIQUE ENCORE LA" || echo "ancien historique efface"; git fsck --unreachable --no-reflogs 2>/dev/null | wc -l; git worktree list | wc -l
```

Expected : `422 commits ; references : refs/heads/main`, `ancien historique efface`, `0`, `1`.

- [ ] **Step 2 : avec l'accord de Djoko, le pont Halo,** sous iCloud.

Run :

```bash
X=$S/anon-execution; cd ~/Documents/Dev/esp32/benq && test -z "$(git status --short)" && git fetch -q $X/benq-reecrit.git main && git checkout -q -B main FETCH_HEAD && git update-ref --no-deref -d refs/remotes/origin/HEAD && git update-ref -d refs/remotes/origin/main && git reflog expire --expire=now --all && git gc --prune=now --quiet && echo "$(git rev-list --count main) commits ; references : $(git for-each-ref --format='%(refname)' | tr '\n' ' ')"; git cat-file -e e114cd5 2>/dev/null && echo "ANCIEN HISTORIQUE ENCORE LA" || echo "ancien historique efface"; git fsck --unreachable --no-reflogs 2>/dev/null | wc -l
```

Expected : `144 commits ; references : refs/heads/main`, `ancien historique efface`, `0`.

- [ ] **Step 3 : relire les deux arbres,** et celui du pont une minute plus tard : iCloud a déjà annulé des fichiers après une fusion.

Run :

```bash
X=$S/anon-execution; for d in ~/Dev/maillage-thread ~/Documents/Dev/esp32/benq; do git -C $d status --short | wc -l; git -C $d diff --quiet HEAD && echo "arbre conforme"; done; [ "$(git -C ~/Dev/maillage-thread rev-parse 'HEAD^{tree}')" = "$(git -C $X/maillage-thread-reecrit.git rev-parse 'main^{tree}')" ] && echo "maillage-thread : arbre du depot reecrit"; [ "$(git -C ~/Documents/Dev/esp32/benq rev-parse 'HEAD^{tree}')" = "$(git -C $X/benq-reecrit.git rev-parse 'main^{tree}')" ] && echo "benq : arbre du depot reecrit"
```

Expected : `0`, `arbre conforme`, deux fois, puis les deux lignes `arbre du depot reecrit`. Relancer la même commande une minute plus tard : même résultat.

---

### Task 7: La configuration git, avec Djoko

**Files:**
- Modify : la configuration locale des deux dépôts de travail

**Interfaces:**
- Consumes : `$E/noreply.txt`.
- Produces : les commits à venir portent `Djoko-cli` et l'adresse noreply (spec, section 6.2).

- [ ] **Step 1 : avec l'accord de Djoko, l'auteur des deux dépôts.** L'adresse n'est jamais affichée : on la compare au fichier.

Run :

```bash
E=$HOME/Dev/maillage-thread/.superpowers/anonymisation/execution; for d in ~/Dev/maillage-thread ~/Documents/Dev/esp32/benq; do git -C $d config user.name Djoko-cli && git -C $d config user.email "$(cat $E/noreply.txt)" && [ "$(git -C $d config user.email)" = "$(cat $E/noreply.txt)" ] && echo "$(git -C $d config user.name) : adresse noreply"; done
```

Expected : `Djoko-cli : adresse noreply`, deux fois.

---

### Task 8: Maillage Thread sur GitHub, avec Djoko

**Files:**
- Create : `$E/github-maillage-thread.json` (privé)

**Interfaces:**
- Consumes : le `main` définitif du dépôt de travail.
- Produces : le dépôt recréé, public, au même nom et à la même description (spec, section 6.3).

- [ ] **Step 1 : relever la fiche du dépôt, en lecture seule, avant sa suppression.**

Run :

```bash
E=$HOME/Dev/maillage-thread/.superpowers/anonymisation/execution; gh repo view Djoko-cli/maillage-thread --json name,description,homepageUrl,repositoryTopics,visibility,stargazerCount,forkCount > $E/github-maillage-thread.json && /usr/bin/python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d['visibility'], 'etoiles', d['stargazerCount'], 'forks', d['forkCount'], 'sujets', len(d['repositoryTopics'] or []))" $E/github-maillage-thread.json
```

Expected : `PUBLIC etoiles 0 forks 0 sujets …`. S'il y a un fork, le dire à Djoko avant d'aller plus loin : la suppression ne l'efface pas.

- [ ] **Step 2 : Djoko supprime le dépôt lui-même,** sur GitHub (Settings, Danger Zone, Delete this repository) : c'est une suppression définitive. Le contrôleur attend qu'il le dise, puis vérifie.

Run : `gh repo view Djoko-cli/maillage-thread > /dev/null 2>&1 && echo "le depot existe encore" || echo "depot supprime"`

Expected : `depot supprime`.

- [ ] **Step 3 : avec l'accord de Djoko, recréer le dépôt, public, au même nom et à la même description.**

Run :

```bash
E=$HOME/Dev/maillage-thread/.superpowers/anonymisation/execution; DESC=$(/usr/bin/python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['description'] or '')" $E/github-maillage-thread.json); PAGE=$(/usr/bin/python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['homepageUrl'] or '')" $E/github-maillage-thread.json); H=(); [ -n "$PAGE" ] && H=(--homepage "$PAGE"); gh repo create Djoko-cli/maillage-thread --public --description "$DESC" "${H[@]}" && for s in $(/usr/bin/python3 -c "import json,sys; print(' '.join(t['name'] for t in json.load(open(sys.argv[1]))['repositoryTopics'] or []))" $E/github-maillage-thread.json); do gh repo edit Djoko-cli/maillage-thread --add-topic "$s"; done; gh repo view Djoko-cli/maillage-thread --json visibility,description --jq '.visibility'
```

Expected : l'adresse du dépôt, puis `PUBLIC`.

- [ ] **Step 4 : avec l'accord de Djoko, pousser `main`.**

Run : `cd ~/Dev/maillage-thread && git remote get-url origin && git push -u origin main 2>&1 | tail -2 && [ "$(gh api repos/Djoko-cli/maillage-thread/commits/main --jq .sha)" = "$(git rev-parse main)" ] && echo "main publie"`

Expected : `https://github.com/Djoko-cli/maillage-thread.git`, puis `main publie`.

---

### Task 9: Le pont Halo sur GitHub, et la demande au support, avec Djoko

**Files:**
- Create : `~/Documents/Dev/esp32/benq/.superpowers/anonymisation/demande-support.md` (privé)

**Interfaces:**
- Consumes : le `main` définitif du dépôt de travail, l'archive du pont.
- Produces : le dépôt réécrit sur GitHub, qui garde ses étoiles ; la demande de purge, que Djoko envoie (spec, section 6.4).

- [ ] **Step 1 : avec l'accord de Djoko, le push forcé.**

Run : `cd ~/Documents/Dev/esp32/benq && git remote get-url origin && git push --force origin main 2>&1 | tail -2 && [ "$(gh api repos/Djoko-cli/benq-screenbar-halo-matter/commits/main --jq .sha)" = "$(git rev-parse main)" ] && echo "main publie"`

Expected : `https://github.com/Djoko-cli/benq-screenbar-halo-matter.git`, puis `main publie`.

- [ ] **Step 2 : la demande au support, dans un fichier privé.** Elle cite les anciens identifiants, tirés de l'archive : ce ne sont pas des données personnelles, et le support en a besoin.

Run :

```bash
D=$(ls ~/Documents/Archives-anonymisation/benq-*.bundle | tail -1); V=$(mktemp -d) && git clone -q $D $V/benq && F=~/Documents/Dev/esp32/benq/.superpowers/anonymisation/demande-support.md && { cat <<'EOF'
Subject: Purge of rewritten history for Djoko-cli/benq-screenbar-halo-matter

Hello,

I rewrote the whole history of my public repository
https://github.com/Djoko-cli/benq-screenbar-halo-matter to remove personal data
(home network identifiers, device names, my first name and email address), and
force-pushed the new main branch. The old commits must no longer be reachable.

Could you please:
- run a garbage collection on the repository, so that the old commits, and the
  trees and blobs only they reference, are removed;
- purge the cached views (commit pages, diffs, blame, compare and archive
  downloads) of these old commits;
- remove any reference, pull request ref or cached object that still points to them.

The repository has no fork and no pull request. The old commits are listed
below (the previous history of main, 143 commits, newest first).

Thank you.

EOF
git -C $V/benq rev-list main; } > $F && wc -l < $F; mkdir -p ~/.Trash/anon-support && mv $V ~/.Trash/anon-support/
```

Expected : `165` environ (le texte et 143 identifiants).

- [ ] **Step 3 : Djoko envoie la demande** par le formulaire du support GitHub (`https://support.github.com/request`, « Remove sensitive data »), avec le texte du fichier. Le contrôleur ne l'envoie pas.

---

### Task 10: La vérification sur GitHub

**Files:**
- Create : `$X/verif-maillage-thread`, `$X/verif-benq` (clones neufs) ; `$E/verification.txt`

**Interfaces:**
- Consumes : les dépôts publiés, la table et les cartes de l'exécution.
- Produces : la preuve qu'un clone neuf ne porte plus rien de réel (spec, section 6.5).

- [ ] **Step 1 : un ancien identifiant ne donne plus rien.** Tout de suite pour Maillage Thread ; pour le pont Halo, après la réponse du support (avant, la commande peut encore répondre).

Run :

```bash
A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; X=$S/anon-execution; gh api repos/Djoko-cli/maillage-thread/commits/$(/usr/bin/python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print(next(k for k in c if k.startswith('8297321')))" $X/carte-maillage-thread.json) > /dev/null 2>&1 && echo "maillage-thread : ancien commit ENCORE VISIBLE" || echo "maillage-thread : ancien commit introuvable"; gh api repos/Djoko-cli/benq-screenbar-halo-matter/commits/$(/usr/bin/python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print(next(k for k in c if k.startswith('e114cd5')))" $X/carte-benq.json) > /dev/null 2>&1 && echo "benq : ancien commit encore visible (attendre le support)" || echo "benq : ancien commit introuvable"
```

Expected : `maillage-thread : ancien commit introuvable` ; pour le pont, `introuvable` une fois la purge faite.

- [ ] **Step 2 : le balayage, relancé sur un clone neuf de chaque dépôt publié.**

Run :

```bash
A=$HOME/Dev/maillage-thread/.superpowers/anonymisation; X=$S/anon-execution; T=$A/execution/table.json; git clone -q https://github.com/Djoko-cli/maillage-thread.git $X/verif-maillage-thread && git clone -q https://github.com/Djoko-cli/benq-screenbar-halo-matter.git $X/verif-benq && { /usr/bin/python3 $A/outils/controles.py balayage --table $T --depot $X/verif-benq --carte $X/carte-benq.json; /usr/bin/python3 $A/outils/controles.py balayage --table $T --depot $X/verif-maillage-thread --carte $X/carte-maillage-thread.json --carte-externe $X/carte-benq.json; } > $A/execution/verification.txt 2>&1; grep -c '^trouve : aucun' $A/execution/verification.txt; for n in maillage-thread benq; do [ "$(git -C $X/verif-$n rev-parse HEAD)" = "$(git -C $X/$n-reecrit.git rev-parse main)" ] && echo "$n : tete publiee conforme"; done
```

Expected : `2`, puis les deux lignes `tete publiee conforme`.

- [ ] **Step 3 : ranger.** Les DD et caches de l'exécution, et les `.pio` des clones, vont à la corbeille ; les miroirs, les archives et le dossier privé restent.

Run :

```bash
X=$S/anon-execution; D=$HOME/.Trash/anon-execution-$(date +%Y%m%d); mkdir -p $D && for p in "$HOME/Library/Developer/Xcode/DerivedData/maillage-anon-exec" "$HOME/Library/Developer/Xcode/DerivedData/maillage-anon-exec-halo" "$HOME/Library/Caches/maillage-anon-exec" $X/travail-benq/.pio; do [ -e "$p" ] && mv "$p" $D/$(basename "$p")-$(date +%s); done; ls $D | wc -l
```

Expected : `4`.

Hors du chantier (spec, section 7) : la mémoire des sessions se met à jour après la publication, avec les nouveaux identifiants de commit.
