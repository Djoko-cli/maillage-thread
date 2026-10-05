# Anonymisation des dépôts Maillage Thread et pont Halo

Spec du 05/10/2026. Djoko a validé la conception le même jour, en six sections. Elle met en œuvre l'option C décidée le 30/09 : anonymiser les données réelles avec des valeurs inventées cohérentes, réécrire l'historique, puis publier l'historique propre.

**Cette spec ne contient aucune valeur réelle.** Les valeurs réelles et leurs remplaçantes sont dans des fichiers privés, jamais commités (section 2).

## 0. Contexte et décisions

Deux dépôts publics sur GitHub sont concernés :

| Dépôt | Commits | Sur GitHub |
|---|---|---|
| Maillage Thread (`~/Dev/maillage-thread`) | 419 sur `main` | public depuis le 28/09 ; aucune étoile, aucun fork, aucun ticket |
| pont Halo (`~/Documents/Dev/esp32/benq`, sous iCloud) | 143 sur `main` | public ; 9 étoiles, aucun fork, aucun ticket |

Les inventaires du 05/10 ont parcouru chaque version de chaque fichier, les chemins et les messages de commit. Ils sont privés, dans `.superpowers/anonymisation/` de chaque dépôt.

**Décisions de Djoko (05/10) :**

| Sujet | Décision |
|---|---|
| Historique | chaque commit est réécrit ; les 419 et 143 commits restent, avec leurs messages |
| Copie d'origine | une archive privée de chaque historique d'origine, hors des dépôts, jamais poussée |
| Périmètre | les deux dépôts, dans un seul chantier |
| Adresse radio de la lampe | **gardée publique**, avec tout le protocole (trames, CRC, balise) |
| Auteur des commits | Djoko-cli, avec l'adresse « noreply » que GitHub donne au compte |
| Prénom | remplacé par « Djoko », partout, chemins compris |
| Fuseau horaire | le nom du fuseau des tests devient un autre fuseau au même décalage, sans heure d'été ; les dates des commits ne changent pas |
| GitHub, Maillage Thread | le dépôt est supprimé par Djoko, puis recréé avec le même nom et la même description |
| GitHub, pont Halo | push forcé sur le même dépôt, qui garde ses étoiles, puis demande de purge au support GitHub |
| Noms réels | tirés de `noms.json` (passeur), par script : les 23 noms trouvés dans l'historique sont remplacés ; les 9 mots courants de pièce sont gardés |

**Limite connue :** les dépôts sont publics depuis plusieurs jours. Une copie déjà faite, par un clone ou par une archive automatique comme Software Heritage, ne peut pas être rappelée. L'anonymisation retire les données de GitHub et de tout clone à venir.

## 1. Ce qu'on change, et ce qu'on garde

**Remplacé par une valeur inventée, dans les deux dépôts :**
- le nom du réseau Thread, l'identifiant étendu (xp), les partitions, l'horodatage du dataset et le suffixe du nom du réseau qui en dérive ;
- les préfixes et les adresses IPv6 (OMR, ULA, lien-local, maillage local), et les adresses IPv4 du réseau local ;
- les adresses matérielles, les ExtMac et les noms d'hôte qui en dérivent, pont Halo compris ;
- les identifiants Matter : fabriques, nœuds, instances, identifiants d'agent de bordure, instances meshcop ;
- les noms d'hôte lisibles des appareils ;
- les noms réels de pièces, de zones et d'appareils, et le nom du domicile, sauf les mots courants de pièce ;
- le numéro de série USB d'un écran ;
- l'adresse électronique et le nom d'auteur des en-têtes de commit ;
- le prénom, dans le texte, les messages et les chemins absolus (`/Users/…`, et leurs formes encodées comme `-Users-…-`) ;
- le nom du fuseau horaire des tests ;
- trois empreintes de clé de test d'origine inconnue, du pont Halo, par précaution.

**Retiré de l'historique :**
- le fichier Python compilé (`__pycache__/*.pyc`) du pont Halo : son contenu ne se réécrit pas ;
- les profils ICC incorporés dans les captures PNG du pont Halo. Les pixels ne changent pas.

**Gardé :**
- l'adresse radio de la lampe, la balise d'appairage, les trames et leurs CRC, et les constantes du protocole ;
- le pseudonyme et les identifiants de paquet qui le portent, déjà publics avec le compte GitHub. Ainsi, rien ne change pour le trousseau, le conteneur, le réseau local ou le démon `halo-routes` ;
- les mots courants de pièce, qui n'identifient personne ;
- les dates et heures des commits ;
- les versions publiques de firmware des appareils tiers.

## 2. La table des remplacements

Un générateur produit la table, à partir d'une graine fixe. La même valeur réelle a la même remplaçante dans les deux dépôts.

**Fichiers privés, ignorés par git :**
- les valeurs réelles, venues des inventaires et de `noms.json` ;
- la table, valeur réelle → valeur inventée, avec toutes les écritures de chaque valeur.

Ils sont rangés dans `~/Dev/maillage-thread/.superpowers/anonymisation/`.

**Règles du générateur :**
- **Même forme.** Même longueur, mêmes séparateurs, même casse.
  - Une adresse matérielle garde ses bits « locale/universelle » et « multidiffusion ».
  - Un préfixe ULA reste en `fd` : les 40 bits suivants sont tirés au sort.
  - Un préfixe public de fournisseur passe dans la plage réservée à la documentation, `2001:db8::/32`.
  - Une adresse IPv4 locale passe dans `192.0.2.0/24`.
  - Le nom du réseau garde sa forme : le même mot, puis un horodatage Unix inventé.
  - Le fuseau de remplacement est un fuseau réel, au même décalage, sans heure d'été.
- **Les valeurs dérivées sont recalculées à partir des nouvelles valeurs primaires,** et non remplacées une à une :
  - lien-local et identifiant d'interface tirés d'une ExtMac ou d'une MAC (EUI-64, bit U/L inversé) ;
  - préfixe du lien d'infrastructure tiré du xp ;
  - champ TXT `omr` (longueur puis préfixe) ;
  - partition écrite à l'envers ou en octets ASCII (`pt`) ;
  - partition dans le TLV Leader Data des flux TLV ;
  - préfixe OMR ou ULA logé dans l'identifiant d'interface d'une adresse ;
  - instance meshcop qui finit par la fin d'un xa ;
  - instance Matter, faite de la fabrique et du nœud ;
  - date du dataset écrite en clair.
- **Toutes les écritures d'une valeur :**
  - majuscules ou minuscules, avec ou sans séparateurs, abrégée ou complète, avec une zone (`%en0`) ;
  - en tableau d'octets (`0x..`), en `hex:`, échappée en JSON ;
  - en fragments recollés dans le code.
  
  Les fragments courts de 4 à 8 chiffres, et les noms de variables Swift tirés d'un préfixe, sont dans la table.
- **L'ordre est gardé** là où un test en dépend :
  - le tri relatif des valeurs d'une même liste ;
  - l'ordre lexical des fabriques ;
  - la fabrique d'Apple, qui reste celle d'Apple.
- **Aucune collision :** avec une valeur déjà inventée des tests (ExtMac en `E0…`, noms de la démo), avec une autre valeur réelle ou inventée, avec une constante du protocole.
- **Les noms inventés** sont des noms de pièce ou d'appareil plausibles, en français. Ils ne doivent figurer ni dans `noms.json` ni dans l'historique.

## 3. La réécriture

1. **L'archive d'origine.** Pour chaque dépôt, `git bundle create --all` produit un fichier, rangé dans `~/Documents/Archives-anonymisation/`. Il est vérifié par `git bundle verify`, et l'on relit le dernier commit d'une copie restaurée.
2. **Les copies de travail.** La réécriture se fait sur des clones miroirs, dans le scratchpad de la session, hors d'iCloud. Les dépôts de travail ne bougent pas avant la section 6.
3. **Le filtre.** Il lit `git fast-export --all` et écrit dans `git fast-import`, vers un dépôt neuf. Un script Python, sans dépendance, fait le travail entre les deux :
   - il applique la table au contenu de chaque fichier texte, à chaque chemin et à chaque message de commit ;
   - il remplace l'auteur et le committer de chaque commit, et garde leurs dates ;
   - il retire le fichier Python compilé, et le profil ICC (le segment `iCCP`) des PNG ;
   - il laisse intacts les autres fichiers binaires, mais les balaie (section 4).
4. **Les identifiants de commit cités** dans les fichiers et les messages sont remplacés par les nouveaux, quand ils désignent un commit déjà réécrit. Le moyen est `get-mark` de `fast-import`. Si ce n'est pas faisable proprement, ils restent tels quels. Dans les deux cas, le plan doit dire lequel.

## 4. Le contrôle, avant toute publication

1. **Le balayage.** Dans chaque commit réécrit (fichiers, chemins, messages, en-têtes), on cherche :
   - chaque valeur réelle de la table, sous chacune de ses écritures ;
   - tout fragment hexadécimal de 6 caractères ou plus tiré d'une valeur réelle ;
   - chaque nom réel, en mot entier ;
   - le prénom, quelle que soit la casse ;
   - l'adresse électronique, le nom du fuseau, le numéro de série et le nom d'utilisateur des chemins.
   
   Il ne doit rien trouver. Un faux positif connu est listé, avec sa raison.
2. **Un second balayage par une autre méthode :** les scripts des deux inventaires, relancés sur les dépôts réécrits.
3. **La réversibilité.** On applique la table à l'envers sur chaque fichier réécrit, et l'on doit retrouver l'original à l'octet près. Seuls font exception le fichier retiré, les PNG sans profil (leurs pixels sont comparés) et les identifiants de commit remplacés.
4. **La forme.** Chaque dépôt garde le même nombre de commits, les mêmes chemins (au fichier retiré près), les mêmes dates, et le même graphe de parents.

## 5. La remise en état du code

Seul l'état final doit compiler et passer ses tests. Les anciens commits ne sont pas tenus de le faire.

- **Un commit de remise en état**, par dépôt, posé sur l'historique réécrit. Il recalcule ce qui se déduit d'un fichier et ne se remplace donc pas, comme l'empreinte SHA-256 de la capture anonymisée de la sonde, citée par les plans et les tests. Il corrige aussi ce que les tests révèlent.
- **Une valeur réelle dont le code a besoin pour fonctionner chez Djoko** passe dans un réglage local, non commité, comme la clé du pont. Le dépôt garde la valeur inventée. Le plan recense ces cas ; l'inventaire n'en a trouvé aucun hors de l'adresse radio, qui est gardée.
- **Les tests à faire passer :**
  - Maillage Thread : la suite entière, en français et en anglais, les tests Python et `outils/mesurer.sh` ;
  - pont Halo : la compilation du firmware dans ses deux variantes, les tests hôte, la compilation et les tests des outils macOS. Aucun flashage, aucun port série.
- **Le README de la capture anonymisée de la sonde** est corrigé : ce qu'elle garde de réel doit être dit. Après la réécriture, elle ne garde plus rien.

## 6. Le remplacement local et la publication

Chaque étape attend l'accord de Djoko.

1. **Les dépôts de travail.** Chacun reçoit l'historique réécrit :
   - sa branche `main` est remplacée, et l'arbre de travail remis à jour ;
   - ses références distantes sont retirées ;
   - son reflog est vidé, et `git gc --prune=now` efface l'ancien historique du dépôt local, commit orphelin compris. Il ne reste alors que dans l'archive.
   
   Pour le pont Halo, qui est sous iCloud, on relit ensuite `git status` et l'arbre : iCloud a déjà annulé des fichiers après une fusion.
2. **La configuration git locale** des deux dépôts passe à Djoko-cli et à l'adresse « noreply » du compte.
3. **Maillage Thread.** Djoko supprime le dépôt sur GitHub, lui-même : c'est une suppression définitive. Ensuite, avec son accord :
   - le dépôt est recréé, public, avec le même nom et la même description ;
   - `main` y est poussé.
4. **Pont Halo.** Avec l'accord de Djoko :
   - `main` est poussé en force sur le même dépôt ;
   - une demande au support GitHub est rédigée dans un fichier privé, et c'est Djoko qui l'envoie. Elle demande de purger les anciens commits, les vues en cache et les références qui y mènent.
5. **La vérification sur GitHub.** Un ancien identifiant de commit ne doit plus rien donner : tout de suite pour Maillage Thread, après la réponse du support pour le pont Halo. Le balayage de la section 4 est relancé sur un clone neuf de chaque dépôt publié.

**Retour arrière :** tant que rien n'est poussé, tout se défait depuis l'archive. La publication est le seul geste irréversible.

## 7. Hors du chantier

- les fichiers locaux ignorés par git (`.superpowers/`), qui contiennent des données réelles et les anciens identifiants de commit : ils restent sur le Mac ;
- les données de l'app, son historique et `noms.json` ;
- la mémoire des sessions, mise à jour après la publication avec les nouveaux identifiants de commit.
