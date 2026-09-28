# Maillage Thread : conception de la sonde (vrais liens du maillage)

> **Statut : conception validée** par Djoko le 28/09/2026, section par
> section (1 à 4). Deux plans d'implémentation :
> - **3a**, la sonde et la vue en direct ;
> - **3b**, le journal des parents et l'historique des qualités.
>
> Un essai sur la carte précède le plan 3a (section 7). Le plan 2 (les noms
> de Maison, spec de l'étape 1, section 5) passe avant.
>
> **Révision du 29/09 après l'essai** (section 8) : les routeurs de bordure
> d'Apple ne répondent pas au diagnostic. La tournée (section 4) en tient
> compte : les liens et les enfants viennent des routeurs qui répondent, et
> les enfants des routeurs muets se trouvent par balayage de leurs RLOC16.

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

**Faits de l'essai (29/09),** détaillés en section 8 :
- **Les routeurs de bordure d'Apple sont muets.** Ils ne répondent jamais au
  `DIAG_GET`.
- **Les autres routeurs répondent en 40 à 120 ms.** Ce sont des appareils
  Matter à puce EFR32 ; le chef du réseau en fait partie.
- **Les enfants répondent** quand on les vise à leur RLOC, même endormis, en
  0,2 à 5 s.
- **Le diagnostic ne passe que par les adresses du réseau maillé :** RLOC,
  ALOC, ML-EID ou lien-local. L'adresse OMR ne marche pas.
- **Les TLV fabricant, modèle et version logicielle (25 à 27) sont vides.**
  Seule la version de la pile (28) est remplie.
- **L'ExtMac d'un appareil Matter est son nom d'hôte mDNS.** On l'identifie
  donc directement par l'instantané de l'étape 1.

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
- **Limites (révisées le 29/09) :**
  - jusqu'à 8 requêtes en vol, repérées par leur `id` ; les réponses peuvent
    arriver dans le désordre ;
  - délai par requête donné par l'app, 45 s par défaut ;
  - lignes USB de 4 Ko au plus. Une réponse fait au plus 142 octets à
    l'essai.

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
- `diag <cible> <tlv,tlv,…> <id> [<délai ms>]` : `<cible>` est un RLOC16 en
  4 hexa (la sonde forme l'adresse RLOC à partir du préfixe du réseau maillé)
  ou une adresse IPv6 du réseau maillé. Le délai borne l'attente d'une
  réponse ; au-delà, la requête échoue en `delai`.

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
  `suspendue`, `occupee` (8 requêtes déjà en vol) ou `envoi`.

**Choix du port.** L'app n'ouvre **aucun port qu'on ne lui a pas désigné**.
Le pont Halo est lui aussi un C6 : l'ouvrir par erreur peut le redémarrer.
- **Réglages › Sonde :** choix du port parmi les `/dev/cu.usbmodem*`.
- **Mémoire :** le numéro de série USB est retenu, pour se reconnecter seul.
- **Vérification :** une sonde répond à `bonjour` avec
  `"produit":"sonde-maillage"`, sinon le port est refusé.

## 4. Tournée (révisée le 29/09 après l'essai)

**Quand :**
- la tournée courte, toutes les 5 minutes, au bouton rafraîchir, et quand
  `etat` montre un autre chef ou une autre partition ;
- le balayage, toutes les 30 minutes, et quand l'ensemble des routeurs muets
  change.

**Tournée courte :**
1. `etat` de la sonde : partition, chef, préfixe du réseau maillé, parent
   (RLOC16 et ExtMac).
2. **Liste des routeurs :** Route64 (5) et Leader Data (6) au chef. S'il est
   muet, à un routeur qui a déjà répondu.
3. **Rôles :** Network Data (7) à un routeur qui répond. On y lit :
   - les routeurs de bordure (préfixes, routes, service SRP) ;
   - le BBR principal (service 01) ;
   - celui qui publie l'OMR.
4. **À chaque routeur qui répond** (RLOC16 = identifiant << 10) :
   - Ext MAC (0), Address16 (1), Route64 (5), Child Table (16), IPv6 Address
     List (8), Version (24) ;
   - une fois, les TLV 25 à 28 : on garde la version de la pile (28), et les
     autres s'ils ne sont pas vides.
5. **Routeur muet :** un routeur qui ne répond pas deux tournées de suite est
   marqué muet, et on ne l'interroge plus qu'une fois par heure. Les routeurs
   de bordure d'Apple le sont tous.

**Balayage des enfants des routeurs muets :**
- **Cibles :** pour chaque routeur muet, les RLOC16 d'enfant de 1 à 32, avec
  Ext MAC (0), Address16 (1) et Mode (2). On s'arrête 8 numéros après le
  dernier qui a répondu.
- **Cadence :** 8 requêtes en vol et 8 s de délai. Les endormis répondent à
  leur réveil ; ceux de l'essai l'ont fait en 1,5 à 5 s.
- **Charge :** environ 160 requêtes, 2 à 3 minutes.
- **Résultat :** l'enfant et son parent (le RLOC16 le donne), sans qualité de
  lien ; le routeur muet ne dit rien.
- **Entre deux balayages,** les enfants trouvés sont gardés.

**Appareils endormis :** seul le balayage les interroge, et seulement sous les
routeurs muets. Sous un routeur qui répond, leur lien se lit dans sa Child
Table, sans les réveiller.

**Rapprochement :**
- **Appareil Matter :** son ExtMac est son nom d'hôte mDNS, donc
  l'identifiant de l'appareil dans l'instantané.
- **Routeur de bordure et ExtMac :** l'ExtMac est le `xa` de son TXT
  `_meshcop._udp`. Mais un routeur muet ne donne pas son ExtMac. Son
  RLOC16 se relie à son `xa` :
  - s'il est le parent de la sonde : `etat` donne les deux. La paire est
    retenue, et la sonde en apprend d'autres quand elle change de parent ;
  - s'il est le BBR principal : les Network Data donnent son RLOC16, et le
    bit `bbrPrimaire` de `sb` désigne son annonce.

  Sinon, il s'affiche « Routeur de bordure · B400 ».
- **Autre appareil** (HomeKit sur Thread, par exemple) : une adresse OMR
  commune entre sa liste d'adresses et celles de l'instantané.
- Sinon, « non identifié ».

**Sonde muette :** le dernier maillage reste affiché 15 min, marqué
« ancien », puis on revient aux pointillés.

**Sortie :** un instantané de maillage daté, comprenant :
- la partition ;
- les routeurs : RLOC16, Ext MAC s'il est connu, identité, rôle (bordure,
  BBR principal, chef), muet ou non, version, pile ;
- les liens entre routeurs, avec la qualité dans chaque sens, lue aux deux
  bouts ou à un seul ;
- les enfants : parent, qualité (inconnue sous un routeur muet), délai,
  endormi ou non, identité ;
- les nœuds non identifiés.

## 5. Affichage (plan 3a, validée)

**Graphe.** La disposition reste stable, par zones et par anneaux.
- **Anneau intérieur :** les routeurs Thread (de bordure et appareils qui
  relaient).
- **Anneau extérieur :** les enfants, rangés près de leur parent.
- **Traits pleins entre routeurs :** épaisseur et couleur selon la qualité
  (3 vert, 2 jaune, 1 orange).
- **Traits pleins fins** de l'enfant vers son parent. Sous un routeur muet,
  la qualité est inconnue : trait fin gris.
- **Lien entre deux routeurs muets :** inconnu, jamais dessiné.
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

**Tests.** Les réponses brutes capturées pendant l'essai, **anonymisées**,
deviennent les données de test (décision de Djoko, 29/09). Les ExtMac, les
préfixes (réseau maillé, OMR), les adresses et le `xp` sont remplacés par des
valeurs inventées, de façon cohérente d'une réponse à l'autre. Elles servent à : décodage des TLV, reconstruction du maillage, tournée
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

## 8. Résultats de l'essai (nuit du 28 au 29/09)

**Montage.** Troisième carte : ESP32-C6FH4, 4 Mo, sur `/dev/cu.usbmodem11301`
(port désigné par Djoko). Firmware d'essai : branche `essai-sonde`, dossier
`sonde/`. Appairée à Maison avec le code d'essai. Mode `rn` (MED) dès le
premier démarrage.

**Réseau vu.**
- Partition `46CBEBCD`, canal 25.
- 7 routeurs actifs.
- Chef : le routeur 24 (`6000`), un appareil Matter EFR32.
- 5 routeurs de bordure, `0400`, `AC00`, `B400`, `CC00` et `E400`, identifiés
  par les Network Data : route `fc00::/7` et service SRP pour tous. `B400`
  publie en plus l'OMR, le NAT64 et le BBR.

**Réponses aux questions posées avant l'essai :**
- **Les routeurs d'Apple répondent-ils à un `DIAG_GET` venu d'un port CoAP
  d'application ?** Non, et à aucune forme essayée : ni par RLOC, ni en
  lien-local, ni avec une seule TLV.
  - Les routeurs EFR32 (pile SL-OpenThread 2.5.1) répondent en 40 à 120 ms,
    et à la première requête vers eux en 2,8 s.
  - Les TLV 29 à 31 (Thread 1.4) ne reviennent pas.
- **Quels TLV sont présents ?**
  - Ext MAC, Address16, Route64, Child Table, IPv6, Version (5, soit
    Thread 1.4), Network Data et Connectivity.
  - 25 à 27 : présents mais vides. 28 : rempli, par exemple
    « SL-OPENTHREAD/2.5.1.0 … EFR32 ».
- **Taille des réponses :** 142 octets au plus, loin des 4 Ko.
- **Appareils endormis :** ils répondent à leur RLOC en 0,2 à 5 s.
- **Adresse OMR :** jamais de réponse ; le diagnostic TMF n'accepte que les
  adresses du réseau maillé.
- **Balayage sous `AC00` :** 6 enfants endormis, de `AC03` à `AC08`, ont donné
  leur ExtMac. Un numéro vide échoue en 35 à 45 s, d'où le délai court et les
  requêtes en parallèle de la section 4.
- **Parent de la sonde :** elle en change seule (`E400` à −76 dBm, puis `AC00`
  à −89 dBm). Les requêtes lancées pendant le changement échouent en `delai`.
- **Deux C6 en USB :** non vérifié, le pont Halo n'était pas branché au Mac.

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
