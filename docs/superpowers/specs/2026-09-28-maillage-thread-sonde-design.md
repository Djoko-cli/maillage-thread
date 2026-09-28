# Maillage Thread : conception de la sonde (vrais liens du maillage)

> **Statut : conception validée** par Djoko le 28/09/2026, section par
> section (1 à 4). Deux plans d'implémentation :
> - **3a**, la sonde et la vue en direct ;
> - **3b**, le journal des parents et l'historique des qualités.
>
> Un essai sur la carte précède le plan 3a (section 7). Le plan 2 (les noms
> de Maison, spec de l'étape 1, section 5) passe avant.

## 0. Contexte, but, décisions

**Origine.** L'étape 1 montre les partitions, mais les traits du graphe vont
tous vers le chef de la partition : c'est un rattachement supposé, pas un lien
radio. Le Mac n'a pas de radio Thread ; les annonces du réseau local ne disent
pas qui est relié à qui.

**But.** Relever les vrais liens radio :
- entre routeurs, avec la qualité dans chaque sens ;
- de chaque enfant vers son parent.

Relever aussi le fabricant et le modèle de chaque nœud qui les donne. Les
dessiner, les noter au journal et garder l'historique des qualités.

**Décisions de Djoko (28/09).**
- **Approche A : une sonde relais, l'intelligence dans l'app.** La sonde
  exécute des requêtes de diagnostic et renvoie les réponses brutes. L'app
  choisit qui interroger, décode, reconstruit le maillage, tient le journal
  et l'historique.
- **La sonde est branchée au Mac en USB.** Le MacBook est à poste fixe, avec
  trois écrans. Hors de la maison, il n'y a pas de relevé.
- **Usage : vue, plus journal des parents, plus historique des qualités.**
- **Deux plans,** 3a puis 3b.
- **Matériel :** un ESP32-C6 dédié, la troisième carte ; les deux autres
  servent à un banc de test.
- **Dans le même dépôt** que l'app, pour que le protocole et l'app évoluent
  ensemble.

**Faits établis (28/09).**
- **Il manque le client de diagnostic.** La pile OpenThread précompilée
  d'Arduino-ESP32 (pioarduino, la même que le pont Halo de benq) n'a ni client
  de diagnostic réseau (`otThreadSendDiagnosticGet`) ni diagnostic de maillage
  (`otMeshDiag*`) : les objets sont compilés vides.
- **Ce qu'elle a :**
  - `otCoapStart` et `otCoapSendRequest` ;
  - `otUdpOpen`, `otUdpBind` et `otUdpSend` ;
  - `otThreadGetParentInfo`, `otThreadGetRloc16` et
    `otThreadGetPartitionId` ;
  - `otThreadGetLeaderData`, `otThreadGetRouterInfo` et
    `otThreadGetNextNeighborInfo` ;
  - `otThreadGetMeshLocalPrefix`, `otIp6GetUnicastAddresses` et
    `otNetDataGet` ;
  - `otThreadGetVendorName` et `otLinkGetChannel`.
- **D'où la méthode.** La sonde fabrique elle-même la requête `DIAG_GET`
  (CoAP `POST d/dg`, liste des TLV voulus) et l'envoie au port TMF 61631 du
  nœud visé. Tout routeur Thread y répond.
- **Seule la forme requête-réponse est utilisable.** Les requêtes
  `DIAG_GET.qry` et `DIAG_GET.ans` répondent sur le port TMF du demandeur,
  que la pile d'Arduino ne sert pas pour le diagnostic.
- **Rôle MED, comme le pont Halo.** La sonde reçoit en permanence mais ne
  relaie rien ; elle ne devient jamais le parent de quelqu'un et ne modifie
  donc pas le maillage qu'elle observe.
- **La sonde ne voit que sa propre partition**, celle d'Apple en pratique. Une
  partition isolée (l'Aqara) reste connue par les annonces, comme à l'étape 1.

## 1. Architecture (validée)

1. **`sonde/`, le firmware.**
   - **Chaîne :** un projet PlatformIO calé sur benq (pioarduino
     `55.03.312-1` : Arduino-ESP32 3.3.12, ESP-IDF 5.5.5, Matter 1.5) ;
     environnement ESP32-C6 Thread.
   - **Rôle MED :** repris du pont Halo, qui intercepte l'appel d'esp_matter
     fixant le type de nœud.
   - **Code :** un nœud Matter, un client CoAP de diagnostic, les commandes
     USB.
2. **`MaillageCoeur/Maillage/`, en Swift pur, testé.**
   - décodeur des TLV de diagnostic ;
   - planificateur de tournée ;
   - reconstruction du maillage ;
   - rapprochement avec l'instantané de l'étape 1 (routeurs de bordure,
     appareils Matter).
3. **`MaillageThread/Sonde/`, dans l'app.**
   - liaison série, reprise de `PortSerie` de Halo Compagnon ;
   - choix du port et mémoire du numéro de série USB ;
   - boucle de tournée, intégration à `Surveillance`.

Sans sonde, l'app marche exactement comme à l'étape 1.

## 2. La sonde (validée)

- **Entrée dans le réseau.** La sonde est appairée à Maison par Bluetooth,
  comme le pont Halo. Maison lui transmet les identifiants Thread ; personne
  ne manipule la clé du réseau.
  - Le code d'appairage passe par l'USB (message `bonjour`), jamais par le
    réseau.
  - Le premier flash se fait avec effacement (usage de benq).
  - Seul le port de la sonde est flashé, désigné par Djoko.
- **Dans Maison,** un interrupteur « Sonde maillage » (prise On/Off), allumé
  par défaut. Éteint, la sonde refuse les requêtes de diagnostic et répond
  « suspendue » : on peut ainsi vérifier qu'elle n'influe sur rien.
- **Limites :**
  - une requête à la fois ;
  - délai de 3 s vers un routeur, de 60 s vers un appareil endormi (il répond
    à son prochain réveil) ;
  - lignes USB de 4 Ko au plus.

## 3. Protocole USB (validée)

**Trame.** Celle du pont Halo : RS (0x1E), JSON compact, fin de ligne ;
ASCII imprimable seulement ; 4096 octets au plus ; `v` (version) et `t`
(type) en tête. À l'ouverture du port, régler DTR et RTS **d'un seul coup** :
sinon le C6 peut redémarrer, c'est le piège décrit dans benq.

**Commandes du Mac** (texte, une par ligne) :
- `bonjour` : produit, version, état d'appairage, code d'appairage s'il
  n'est pas encore appairé ;
- `etat` : l'état de la sonde dans le réseau ;
- `voisins` : ce que la sonde entend ;
- `diag <cible> <tlv,tlv,…> <id>` : `<cible>` est un RLOC16 en 4 hexa (la
  sonde forme l'adresse RLOC à partir du préfixe du réseau maillé) ou une
  adresse IPv6.

**Messages de la sonde :**
- `bonjour` :
  `{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.0","appairee":true,"code":null}`
- `etat` : `role`, `rloc16`, `parent` (`rloc16`, `ext`, `lqIn`, `lqOut`,
  `rssi`), `partition`, `chef` (identifiant du routeur chef), `canal`,
  `prefixeMaille`, `xp`, `suspendue`.
- `voisins` : `liste` d'objets `rloc16`, `ext`, `rssi`, `lqi`, `routeur`.
- `diag`, en cas de succès :
  `{"v":1,"t":"diag","id":7,"cible":"4800","ok":true,"ms":123,"tlv":"<hexa>"}`
- `diag`, en cas d'échec : `"ok":false` et `"erreur"` valant `delai`,
  `suspendue`, `occupee` ou `envoi`.

**Choix du port.** L'app n'ouvre **aucun port qu'on ne lui a pas désigné**.
Le pont Halo est lui aussi un C6 : l'ouvrir par erreur peut le redémarrer.
- **Réglages › Sonde :** choix du port parmi les `/dev/cu.usbmodem*`.
- **Mémoire :** le numéro de série USB est retenu, pour se reconnecter seul.
- **Vérification :** une sonde répond à `bonjour` avec
  `"produit":"sonde-maillage"`, sinon le port est refusé.

## 4. Tournée (validée)

**Quand :** toutes les 5 minutes, au bouton rafraîchir, et quand `etat`
montre un autre chef ou une autre partition.

**Déroulé :**
1. `etat` de la sonde : partition, chef, préfixe du réseau maillé.
2. **Au chef :** Route64 (5) et Leader Data (6), pour la liste des routeurs
   actifs.
3. **À chaque routeur** (RLOC16 = identifiant << 10) :
   - à chaque tournée : Ext MAC (0), Address16 (1), Route64 (5), Child Table
     (16), IPv6 Address List (8), Version (24) ;
   - **une fois** : Vendor Name (25), Vendor Model (26), Vendor SW Version
     (27), Thread Stack Version (28).
4. **Aux enfants nouveaux seulement,** pour les identifier une fois : Ext MAC
   (0), IPv6 Address List (8), Mode (2), TLV fabricant (25 à 28).

**Appareils endormis** (Mode : récepteur coupé au repos) : **jamais
réinterrogés**. Leur lien se lit dans la Child Table de leur parent, sans les
réveiller. Un enfant qui change de parent change de RLOC16 et sera identifié à
nouveau.

**Rapprochement :**
- routeur Thread et routeur de bordure : l'Ext MAC égale le `xa` du TXT
  `_meshcop._udp` ;
- autre routeur (appareil qui relaie) ou enfant, et appareil Matter : une
  adresse OMR commune entre sa liste d'adresses et celles de l'instantané ;
- sinon « non identifié ».

**Charge :** une dizaine de requêtes par tournée.

**Sonde muette :** le dernier maillage reste affiché 15 min, marqué
« ancien », puis on revient aux pointillés.

**Sortie :** un instantané de maillage daté, comprenant :
- la partition ;
- les routeurs : RLOC16, Ext MAC, identité, fabricant, modèle, version ;
- les liens entre routeurs, avec la qualité dans chaque sens (lue aux deux
  bouts) ;
- les enfants : parent, qualité, délai, endormi ou non, identité ;
- les nœuds non identifiés.

## 5. Affichage (plan 3a, validée)

**Graphe.** La disposition reste stable, par zones et par anneaux.
- **Anneau intérieur :** les routeurs Thread (de bordure et appareils qui
  relaient).
- **Anneau extérieur :** les enfants, rangés près de leur parent.
- **Traits pleins entre routeurs :** épaisseur et couleur selon la qualité
  (3 vert, 2 jaune, 1 orange).
- **Traits pleins fins** de l'enfant vers son parent.
- **Pointillés vers le chef** pour ce que la sonde ne voit pas : autre
  partition, appareil sans parent connu. Sans sonde, tout est comme à
  l'étape 1.
- **Légende :** « trait : lien radio (qualité) · pointillé : rattachement
  supposé ».
- **Survol :** les liens du nœud s'éclairent.

**Fiche.**
- Appareil : parent et qualité, endormi ou non (délai), fabricant, modèle,
  version de Thread, RLOC16.
- Routeur : ses voisins routeurs avec la qualité dans chaque sens, et son
  nombre d'enfants.

**Noms,** par priorité :
1. le surnom ;
2. le nom de Maison (plan 2) ;
3. **fabricant et modèle**, par exemple « Eve Energy », avec un suffixe court
   s'il y en a plusieurs, comme « Eve Energy · 8A13 » ;
4. l'hôte.

**Menu.** Une ligne « Sonde : connectée » ou « Sonde : absente ».

**Réglages › Sonde :**
- le port ;
- l'état : partition, dernier relevé ;
- le code d'appairage tant que la sonde n'est pas dans Maison ;
- l'interrupteur « Sonde maillage » (lecture seule).

## 6. Journal et historique (plan 3b, validée)

**Journal.**
- Événements :
  - « X a changé de parent : A → B » ;
  - « X n'a plus de parent » ;
  - « un routeur Thread (hors routeurs de bordure) apparaît ou disparaît ».
- Les changements de parent répétés sont regroupés : « X a changé 4 fois de
  parent en 1 h ».
- Pas de notification par défaut : ces événements relèvent de la catégorie
  « Autres changements ».

**Historique.**
- Contenu : à chaque tournée, la qualité de chaque lien, entre routeurs et
  d'enfant à parent.
- Stockage : JSON Lines mensuel (`maillage-AAAA-MM.jsonl`) dans le dossier de
  l'app, gardé 90 jours comme le journal ; environ 5 Mo par mois.
- Affichage : courbes dans la fiche (Swift Charts) sur 24 h, 7 j et 30 j,
  avec les changements de parent marqués.

## 7. Tests, permissions, essai préalable (validée)

**Tests.** Les réponses brutes capturées pendant l'essai deviennent les
données de test : décodage des TLV, reconstruction du maillage, tournée
(qui interroger, appareils endormis), rapprochement, et pour 3b les écarts du
journal et l'historique. Le firmware est vérifié par sa compilation, puis sur
la carte avec Djoko.

**Permissions.** L'app ajoute l'autorisation `com.apple.security.device.serial`,
comme Halo Compagnon. Il n'y a rien de nouveau côté réseau.

**Essai préalable au plan 3a,** sur la troisième carte :
1. Un firmware minimal : MED, appairage, commandes `bonjour`, `etat` et
   `diag`.
2. L'appairage dans Maison : Djoko scanne le code.
3. Des requêtes au chef, aux routeurs et à quelques enfants.
4. La capture des réponses, qui deviennent les données de test.

Le plan 3a s'écrit ensuite à partir de ces faits.

## 8. À vérifier à l'essai

- **Réponse des routeurs Apple :** acceptent-ils un `DIAG_GET` envoyé depuis
  un port CoAP d'application, et non depuis le port TMF ?
- **TLV présents :** fabricant et modèle (25 à 28), Version (24), Child Table
  (16) ; lesquels répondent ?
- **Taille des réponses :** tiennent-elles dans des lignes de 4 Ko ?
- **Appareils endormis :** délai réel de réponse d'un appareil endormi à qui
  l'on écrit.
- **Deux C6 en USB :** l'app ne touche jamais au port du pont Halo.

## 9. Suite prévue : vue spatiale (souhait de Djoko, 28/09)

Après le plan 3a : une représentation du réseau **par pièce et par étage**,
avec les vrais liens radio par-dessus. Les pièces viennent de Maison (plan
2) ; les étages, des zones de Maison (`HMHome.zones`, à exporter par le
passeur). Rendu **3D** (RealityKit, `RealityView`) : étages en dalles
translucides empilées, pièces en tuiles (disposées automatiquement,
déplaçables plus tard), appareils en sphères, routeurs plus gros (couronne
pour le chef), liens radio en fils colorés selon la qualité, qui traversent
les dalles ; rotation, zoom, clic pour la fiche. À concevoir quand les liens
existent.
