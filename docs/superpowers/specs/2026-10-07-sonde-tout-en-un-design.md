# Sonde tout-en-un : écoute des annonces MLE, résolution des parents, compteurs des enfants

Spec du 07/10/2026. Djoko a validé la conception le même jour, partie par partie. Révisée le même jour après la relecture finale : les compteurs MAC des enfants ne donnent plus de qualité (section 2.3).

## 0. Contexte et décisions

Aujourd'hui, Maillage Thread connaît le maillage par le diagnostic Thread (`DIAG_GET`) que la sonde envoie. Les routeurs tiers y répondent : leur Route64 donne leurs liens avec tous les routeurs, et leur table des enfants donne leurs enfants avec la qualité. **Les routeurs de bordure Apple n'y répondent pas.** Il manque donc :
- les liens entre routeurs Apple ;
- l'identité (ExtMac) des routeurs Apple que la sonde n'a jamais eus pour parent ;
- les enfants des routeurs Apple qui ne répondent pas au diagnostic, que le balayage des RLOC16 ne trouve pas ;
- la qualité des liens entre un enfant et son parent Apple.

**L'essai du 07/10**, sur une seconde carte C6 avec un firmware jetable (branche `essai-ecoute`, jamais fusionnée), a établi :
- **L'écoute.** Une sonde en FED reçoit les annonces MLE de ses voisins à un saut, sans mode promiscuité : `otLinkSetPcapCallback`, présent dans la bibliothèque OpenThread précompilée d'Arduino, donne les trames brutes. La carte dérive la clé MLE de la clé réseau (`otThreadGetNetworkKey`, sans référence de clé dans cette bibliothèque) et déchiffre (AES-CCM, MIC de 4 octets) : des centaines de messages déchiffrés, aucun échec. Les annonces des routeurs Apple portent leur Route64 : leurs liens réels, dans les deux sens. Deux points d'écoute ont suffi pour entendre tous les routeurs Apple d'une maison à deux niveaux.
- **La résolution d'adresse.** Une requête vers l'adresse Thread d'un appareil fait résoudre cette adresse par OpenThread. Le parent répond à la place de son enfant endormi, et le cache d'adresses (`otThreadGetNextCacheEntry`) donne le RLOC16 trouvé : 20 appareils sur 26, tous muets au diagnostic, ont obtenu leur parent. Les routeurs Apple répondent avec leur propre RLOC16 ; les routeurs tiers, avec celui de l'enfant.
- **Les compteurs MAC.** Un enfant qui répond au diagnostic rend sa TLV 9 (compteurs MAC). L'essai a établi qu'elle est rendue, pas ce qu'elle mesure : la relecture finale a montré dans les sources d'OpenThread que son `ifOutErrors` compte les échecs d'accès au canal, pas les accusés manquants (section 2.3). La TLV 4 (Connectivity) n'est pas rendue par un appareil endormi.
- **Le diagnostic n'est accepté que sur les adresses internes du réseau** (RLOC, ML-EID), pas sur les adresses publiques (OMR).

**Décisions de Djoko (07/10) :**

| Sujet | Décision |
|---|---|
| Périmètre | écoute, résolution, noms des routeurs Apple **et** compteurs MAC des enfants (d'abord pour leur qualité ; à titre d'information seulement depuis la décision qui suit) |
| Compteurs MAC (après la relecture finale) | **ils ne donnent plus de qualité** : les enfants des routeurs Apple restent en qualité inconnue ; la fiche montre seulement « accès au canal refusés : x % », à titre d'information (section 2.3) |
| Balayage des enfants | **remplacé** par la résolution d'adresse |
| Qui décode les annonces | **la sonde déchiffre, l'app décode** la Route64 avec son décodeur existant |
| Affichage | **un lien est un lien** : même trait, même couleur de qualité quelle que soit la source ; la fiche dit la source et l'âge |
| Carte d'essai | retirée de Maison et effacée à la fin du chantier |

## 1. Le firmware de la sonde, version 1.1.0

### 1.1 L'écoute

- Au démarrage de la pile Thread, la sonde pose `otLinkSetPcapCallback`. Le rappel, dans la tâche OpenThread, ne fait qu'un tri (trames de données sans sécurité MAC) et une copie dans une file FreeRTOS (16 trames ; une file pleine est comptée, jamais bloquante). Le décodage se fait dans `loop()`.
- **Décodage :** en-tête 802.15.4 aux formats 2003/2006 et 2015 (numéro de séquence supprimé, PAN selon le tableau 7-2, IE d'en-tête jusqu'à HT1 ou HT2) ; 6LoWPAN IPHC sans contexte ; UDP vers le port MLE 19788 ; source lien-local.
- **Déchiffrement :** suite de sécurité 0, contrôle `0x15` (niveau 5, clé en mode 2), compteur de trame petit-boutiste, séquence de clé gros-boutiste dans la source de clé. La clé MLE est les 128 premiers bits de HMAC-SHA256(clé réseau, séquence ‖ « Thread »). Nonce : ExtMac de l'émetteur (tiré de l'identifiant d'interface lien-local), compteur de trame gros-boutiste, niveau. Données associées : adresses IPv6 source et destination, puis les 10 octets de l'en-tête de sécurité.
- **Clé réseau :** lue sous le verrou OpenThread seulement pour dériver une clé MLE, puis effacée. Deux clés MLE dérivées sont gardées (la séquence courante et la suivante, à la rotation). Aucune commande ne rend ni la clé réseau ni une clé dérivée.
- **Table des routeurs entendus,** par ExtMac, 32 entrées : RLOC16 (TLV Source Address), partition (TLV Leader Data), **dernière Route64 brute** (valeur de la TLV 9, au plus 72 octets), signal (dernier, minimum et maximum depuis l'entrée), nombre de messages, âge du dernier. Un routeur muet depuis 10 minutes sort de la table. Seuls les émetteurs dont le RLOC16 est celui d'un routeur (`xx00`) y entrent.

### 1.2 Les commandes nouvelles

Toutes permises par l'USB et par le réseau (liste blanche de `distant.cpp`), sans changement de l'enveloppe H1.

- **`annonces`** : une ligne par routeur entendu, `"suite":true` sauf sur la dernière ; sans routeur, une seule ligne `"vide":true`. Champs : `rloc16`, `ext`, `partition`, `route64` (hexa), `seq`, `rssi`, `rssi_min`, `rssi_max`, `nb`, `age_s`. Une ligne fait moins de 400 octets : elle passe par le réseau (1100 octets au plus).
- **`resoudre <ipv6> <id>`** : au plus 8 en vol, comme `diag`. La sonde envoie une demande d'écho ICMPv6 (`otIcmp6SendEchoRequest`) à l'adresse, puis lit son cache d'adresses toutes les 250 ms, 15 s au plus. Réponse : `rloc16` et `mleid` (si le cache les donne), ou l'erreur `introuvable`. Une adresse mal formée : `syntaxe`.
- **`etat`** gagne `ecoute` : trames, MLE déchiffrés, échecs, file pleine (depuis le démarrage).
- `diag` accepte déjà une adresse IPv6 : l'app l'envoie au ML-EID pour la TLV 9.

### 1.3 Ce qui ne change pas

FED non éligible routeur, clé d'accès réseau H1, LED, appairage Matter, cadence de 20 commandes par seconde. Flash sans effacement : la sonde reste dans Maison. Place : 76 % de la flash et 55 % de la RAM à l'essai.

## 2. L'app

### 2.1 Tournée courte (toutes les 5 minutes)

- Après `etat`, `routeurs` et `voisins`, l'app demande `annonces` (sans réponse : la tournée continue sans).
- Elle garde les routeurs de sa partition, décode chaque Route64 avec `DiagnosticThread.route64` et en tire des liens de source « écoute », datés de l'âge donné par la sonde.
- **Fusion avec le diagnostic :** pour une paire de routeurs, chaque sens prend la mesure la plus récente, diagnostic ou écoute. Un lien connu d'un seul côté est affiché : une Route64 donne les deux sens.
- **Identités :** chaque annonce relie un RLOC16 à un ExtMac ; le rapprochement (`Rapprochement.swift`) l'utilise comme le parent de la sonde. Les noms des routeurs Apple viennent de `_meshcop` (champ `xa`), que l'app lit déjà.

### 2.2 Résolution des parents (toutes les 30 minutes, et quand un appareil apparaît)

- Elle **remplace le balayage** (`Tournee.swift`, cas `balayage`) et sa mémoire.
- Pour chaque appareil Matter ou HomeKit sur Thread que l'app connaît avec une adresse sur le préfixe de sa partition : `resoudre`, 8 en vol.
- Le parent est le RLOC16 rendu, sans ses 10 bits de poids faible. L'enfant lui est rattaché, source « résolution », daté. Le ML-EID est gardé en mémoire (pas dans l'historique).
- Un appareil non résolu reste en « rattachement supposé », comme aujourd'hui.

### 2.3 Compteurs MAC des enfants de routeurs Apple, à titre d'information

- À chaque résolution, pour chaque enfant d'un routeur Apple qui a un ML-EID : `diag <ML-EID> 9`.
- L'app garde le dernier relevé de chaque enfant, par appareil, en mémoire, et calcule entre deux relevés le taux Δ `ifOutErrors` / Δ `ifOutUcastPkts` :
  - moins de 50 trames envoyées entre les deux relevés : pas de valeur ;
  - un compteur qui baisse (l'appareil a redémarré) : pas de valeur, et le relevé repart de zéro.
- **Ce que ce taux mesure.** Dans OpenThread (`network_diagnostic.cpp`), `ifOutErrors` vaut `mTxErrCca` : les échecs d'accès au canal (CCA), comptés à chaque tentative d'envoi ; `ifOutUcastPkts` compte les trames unicast, une fois chacune. Les accusés manquants, les reprises et les trames acquittées ne figurent pas dans la TLV 9. Le taux dit donc l'occupation du canal autour de l'enfant (Wi-Fi voisin, trafic), pas la qualité de son lien avec son parent : un enfant qui perd ses accusés dans un canal calme garde un taux proche de 0. La première version de cette section en tirait une qualité (moins de 1 % : 3 ; de 1 à 5 % : 2 ; au-delà : 1) ; la relecture finale l'a relevé.
- **Décision de Djoko (07/10) :**
  - le taux ne donne plus de qualité : l'enfant d'un routeur Apple reste en qualité inconnue (gris) ;
  - la fiche le montre seulement, à titre d'information, sur la ligne du parent de l'enfant : « accès au canal refusés : 0,7 % » (en anglais, « channel access refused: 0.7% ») ;
  - l'historique garde le taux dans son champ, au même encodage (la 1.0.0 le lit), sans qualité.
- Un enfant qui ne répond pas : pas de valeur. Sous un routeur tiers, la qualité vient de sa table des enfants, comme aujourd'hui. Une vraie mesure du lien reste à chercher (par exemple la TLV 34 de Thread 1.4, compteurs MLE : changements de parent, tentatives de rattachement).

### 2.4 Affichage

- **Vue par pièces :** même trait et même couleur de qualité pour tous les liens. Un lien trop vieux pâlit, comme aujourd'hui. Légende inchangée.
- **Fiche du nœud** (`FicheNoeud.swift`) : pour chaque lien, sa source et son âge (« entendu il y a 3 min », « diagnostic », « accès au canal refusés : 0,7 % »). Un routeur jamais entendu par la sonde : « jamais entendu par la sonde ; liens vus seulement par ses voisins ».
- **Réglages › Sonde :** couverture, « routeurs entendus : n sur m » (m : les routeurs de la partition).
- Textes en français et en anglais, par le catalogue.

### 2.5 Historique

`maillage-AAAA-MM.jsonl` gagne des champs facultatifs : la source de chaque lien et de chaque enfant, et le taux d'accès au canal refusés des enfants, à titre d'information (il ne donne pas de qualité, section 2.3). Les fichiers existants se lisent comme avant.

### 2.6 Ce qui ne change pas

Le mode démo, la partition Aqara (montrée comme aujourd'hui ; ses annonces entendues sont écartées), le reste de la tournée.

## 3. Sécurité et confidentialité

- La clé réseau ne quitte jamais la carte et n'est gardée en mémoire que le temps d'une dérivation.
- `annonces` et `resoudre` ne rendent que des adresses et des liens du réseau, que le diagnostic donne déjà.
- Aucune donnée réelle dans le dépôt : tests à clé et adresses inventées ; captures réelles jamais commitées ; contrôle d'anonymisation avant chaque push.

## 4. Tests

- **Firmware (tests hôte, `sonde/test/lancer.sh`) :** décodage 802.15.4 (2006 et 2015, IE d'en-tête, PAN), IPHC (sources et destinations courantes), UDP compressé ou non, déchiffrement AES-CCM et refus d'un MIC faux, dérivation de la clé MLE, lecture des TLV. Vecteurs produits par un script avec une clé inventée.
- **App (cœur) :** fusion des liens (deux sources, âges, un seul côté connu, partition étrangère écartée), parent tiré du RLOC16 (réponse Apple et réponse tierce), `introuvable`, taux d'accès au canal refusés (deux relevés, seuil de 50 trames, compteur qui baisse, enfant muet ; aucune qualité), lecture de l'ancien historique, couverture.
- Les suites existantes restent vertes, en français et en anglais.

## 5. Au banc, avec Djoko

1. Flash de la sonde en 1.1.0, sans effacement, sur le port que Djoko désigne, MAC vérifiée.
2. La sonde à sa place habituelle ; après une tournée et une résolution, la vue de l'app comparée aux relevés de l'essai : liens entre routeurs Apple, parents résolus, taux d'accès au canal refusés d'un enfant qui répond (une information, pas une qualité).
3. Couverture affichée vérifiée, et le déplacement de la sonde qui la fait varier.

**Vérifié le 08/10/2026 avec Djoko** (firmware 1.1.0 flashé sans effacement, app 1.1.0 de travail) : à sa place habituelle, la sonde entend 6 routeurs sur 7 ; les 10 liens possibles entre les 5 routeurs Apple sont dessinés ; 22 appareils sont rattachés à leur parent par la résolution, tous sous un routeur Apple. Le taux d'accès au canal refusés, qui demande deux résolutions à 30 minutes d'écart, et le déplacement de la sonde n'ont pas été vus au banc.

**Correction du 08/10/2026 (test de Djoko) :** un HomePod mini enfermé dans de l'aluminium puis une casserole perd 8 à 15 dB à la sonde, mais tous ses liens avec les autres routeurs Apple restent à 3. Les 5 routeurs Apple annoncent TREL (`_trel._udp`) : ils peuvent se parler par le réseau local, et une entrée de leur Route64 ne prouve aucun lien radio. Les « 10 liens Apple ↔ Apple » du banc n'en sont donc pas la preuve. Décision de Djoko : carte exclusivement radio ; l'app ne dessine plus le lien entre deux routeurs qui annoncent TREL (leur `xa`). Découvrir leurs vrais liens radio (écoute 802.15.4 en promiscuité) est au backlog.

**Écoute passive du 09/10/2026 :** une carte d'essai en promiscuité sur le canal du réseau, sans le rejoindre ni émettre, n'a lu que les en-têtes MAC (en clair). En deux endroits de la maison (6 et 14 minutes, plus de 90 000 trames), elle n'a entendu aucune trame unicast radio entre deux routeurs d'Apple, alors qu'elle les entendait tous ; la seule paire de routeurs en radio était un routeur d'Apple et un routeur tiers, un lien déjà sur la carte. Les routeurs d'Apple s'entendent mais passent par TREL : la carte radio seule de l'app est la vérité, et l'écoute en promiscuité n'a pas à entrer dans la sonde.

## 6. Fin de l'essai

- Djoko retire « Sonde essai » de Maison.
- La carte d'essai est effacée (`erase`), avec son accord, sur son port désigné : ni clé réseau ni appairage ne restent.
- Les captures privées de l'essai et la branche `essai-ecoute` vont à la corbeille.

## 7. Publication

Version 1.1.0 de Maillage Thread, notes de version en anglais puis en français. Les README (anglais puis français) disent ce que l'écoute apporte et ses limites. Contrôle d'anonymisation avant le push.

## 8. Limites

- L'écoute n'entend que les routeurs à portée radio de la sonde ; un seul routeur entendu donne tous ses liens, et un lien apparaît dès que l'un de ses deux bouts est entendu. Une sonde mal placée n'apporte jamais moins qu'avant ce chantier : le diagnostic, la résolution et les compteurs ne dépendent pas de sa position.
- La qualité du lien entre un enfant et son parent Apple reste inconnue : le parent ne la donne pas, et les compteurs MAC de l'enfant ne la mesurent pas (section 2.3).
- La résolution ne traverse pas les partitions : les enfants de la partition Aqara restent inconnus.
- Le maillage est une photo datée : les liens et les parents changent, l'âge de chaque information est affiché.
