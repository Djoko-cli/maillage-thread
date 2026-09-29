# Maillage Thread : conception de la sonde (vrais liens du maillage)

> **Statut : conception validée** par Djoko le 28/09/2026, section par
> section (1 à 4). Deux plans d'implémentation :
> - **3a**, la sonde et la vue en direct ;
> - **3b**, le journal des parents et l'historique des qualités.
>
> Un essai sur la carte précède le plan 3a (section 7). Le plan 2 (les noms
> de Maison, spec de l'étape 1, section 5) passe avant.
>
> **Plan 3a :** `docs/superpowers/plans/2026-09-29-maillage-thread-plan3a-sonde.md`.
>
> **Révision du 29/09 pendant l'exécution du plan 3a :** des relectures ont
> corrigé plusieurs comportements par rapport au texte du plan. La section 3
> en tient compte pour la trame ; la section 4, pour le BBR principal, la
> liste des routeurs, le balayage, les identités des enfants et la fraîcheur
> du maillage affiché. Les autres corrections ne changent pas la spec : le
> code la rejoint pour l'épaisseur des liens (section 5) et pour
> l'interrupteur « Sonde maillage », gardé après un redémarrage (section 2) ;
> la sérialisation de la connexion à la sonde est un détail d'implémentation
> que la spec ne décrit pas. Chaque correction est listée dans la section
> « Écarts d'exécution (29/09) » du plan.
>
> **Révision du 29/09 après l'essai** (section 8) : les routeurs de bordure
> d'Apple ne répondent pas au diagnostic. La tournée (section 4) en tient
> compte : les liens et les enfants viennent des routeurs qui répondent, et
> les enfants des routeurs muets se trouvent par balayage de leurs RLOC16.
>
> **Révision du 29/09 pendant la vérification sur la carte** (demandes de
> Djoko) : la sonde a un nom, donné par la carte, et `bonjour` donne toujours
> son code d'appairage et son QR code (section 3, firmware 1.0.1). Réglages ›
> Sonde la montre sous ce nom, avec son QR code et son code ; la tournée en
> cours se voit, avec son étape et son compteur, dans le graphe, les Réglages
> et le menu ; le bouton rafraîchir du graphe lance aussi le passeur des noms
> de Maison, sans relancer une tournée en cours (sections 4 et 5).
>
> **Sonde 1.0.2 (29/09, demande de Djoko pendant la vérification) :** la
> sonde est FED et donne sa table des routeurs (`routeurs`) ; l'app retient
> les identités des routeurs et affiche honnêtement ceux qu'elle ne peut pas
> identifier (section 4) ; la sonde est joignable par le réseau Thread, comme
> le pont Halo, pour la débrancher du Mac et la promener dans la maison
> (section 3 bis).

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
  trois écrans. Hors de la maison, il n'y a pas de relevé. (Depuis la 1.0.2,
  elle peut aussi être jointe par le réseau Thread : section 3 bis.)
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
  donc pas le maillage qu'elle observe. (FED depuis la 1.0.2, jamais
  éligible routeur : même garantie, et elle entend les routeurs voisins ;
  section 3 bis.)
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
   - boucle de tournée, intégration à `Surveillance` ;
   - depuis la 1.0.2, le canal par le réseau Thread (`Sonde/Reseau/`, repris
     de Halo Compagnon : transport UDP, enveloppe H1, trousseau ; section
     3 bis).

Sans sonde, l'app marche exactement comme à l'étape 1.

## 2. La sonde (validée)

- **Entrée dans le réseau.** La sonde est appairée à Maison par Bluetooth,
  comme le pont Halo. Maison lui transmet les identifiants Thread ; personne
  ne manipule la clé du réseau.
  - Le code d'appairage et le QR code passent par l'USB (message `bonjour`),
    jamais par le réseau.
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
    l'essai. Par le réseau (1.0.2), une réponse fait 1100 octets au plus
    (section 3 bis).

## 3. Protocole USB (validée)

**Trame.** Celle du pont Halo : RS (0x1E), JSON compact, fin de ligne ;
ASCII imprimable seulement ; 4096 octets au plus ; `v` (version) et `t`
(type) en tête. La ligne machine est retrouvée au dernier RS de la ligne,
comme le récepteur du pont Halo : ce qui le précède (queue d'un journal sans
fin de ligne, invite, ligne coupée) est abandonné. À l'ouverture du port,
régler DTR et RTS **d'un seul coup** : sinon le C6 peut redémarrer, c'est le
piège décrit dans benq.

**Commandes du Mac** (texte, une par ligne) :
- `bonjour` : produit, version, nom, état d'appairage, code d'appairage et
  charge du QR code, toujours (firmware 1.0.1 ; la 1.0.0 ne donnait le code
  qu'avant l'appairage) ;
- `nom <texte>` : change le nom de la sonde et le garde ; réponse : un
  `bonjour` à jour, ou l'erreur `syntaxe` (nom refusé) ou `ecriture` (mémoire
  qui refuse l'écriture) ;
- `etat` : l'état de la sonde dans le réseau ;
- `voisins` : ce que la sonde entend ;
- `diag <cible> <tlv,tlv,…> <id> [<délai ms>]` : `<cible>` est un RLOC16 en
  4 hexa (la sonde forme l'adresse RLOC à partir du préfixe du réseau maillé)
  ou une adresse IPv6 du réseau maillé. Le délai borne l'attente d'une
  réponse ; au-delà, la requête échoue en `delai` ;
- `routeurs` (1.0.2) : la table des routeurs de la sonde (section 4) ;
- `cle nouvelle <64 HEXA> <id>`, `cle`, `cle efface` (1.0.2, USB
  seulement) : la clé de l'accès par le réseau (section 3 bis).

**Messages de la sonde :**
- `bonjour` :
  `{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.1","nom":"SONDE-01","mac":"<MAC>","appairee":true,"code":"<11 chiffres>","qr":"MT:<…>"}`.
  - `nom` : 1 à 32 caractères parmi les lettres ASCII, les chiffres, `-`,
    `_` et `.` (rien à échapper) ; « SONDE-01 » par défaut. La carte le
    garde à côté de l'état de l'interrupteur : il la suit d'un Mac à
    l'autre. Un firmware 1.0.0 ne l'envoie pas.
  - `code` (code d'appairage manuel) et `qr` (charge du QR code, `MT:…`),
    appairée ou non ; `null` si Matter n'a pas pu les former, et toujours
    par le réseau (1.0.2).
  - `hote` (1.0.2) : le nom d'hôte SRP de la sonde, sans `.local` (celui que
    Matter enregistre) ; `null` tant qu'il n'est pas connu.
- `etat` : `role`, `rloc16`, `parent` (`rloc16`, `ext`, `lqIn`, `lqOut`,
  `rssi`), `partition`, `chef` (identifiant du routeur chef), `canal`,
  `prefixeMaille`, `xp`, `suspendue`.
- `voisins` : `liste` d'objets `rloc16`, `ext`, `rssi`, `lqi`, `routeur`.
- `diag`, en cas de succès :
  `{"v":1,"t":"diag","id":7,"cible":"4800","ok":true,"ms":123,"tlv":"<hexa>"}`
- `diag`, en cas d'échec : `"ok":false` et `"erreur"` valant `delai`,
  `suspendue`, `occupee` (8 requêtes déjà en vol) ou `envoi` ; par le réseau
  seulement, `trop_long` (section 3 bis).
- `routeurs` (1.0.2) :
  `{"v":1,"t":"routeurs","liste":[{"id":…,"rloc16":"XXXX","ext":"<16 HEXA>"|null,"lqIn":…,"lqOut":…,"age":…,"lien":…}],"suite":true|false}`,
  sur plusieurs lignes si besoin, la dernière avec `"suite":false`.
- `cle` (1.0.2) : `{"v":1,"t":"cle","id":<id>,"cle":"<64 HEXA>","empreinte":"<8 hexa>","hote":"<nom>"|null}`
  en réponse à `cle nouvelle`, la seule fois où la clé sort ; l'empreinte
  seule en réponse à `cle`.

**Choix du port.** L'app n'ouvre **aucun port qu'on ne lui a pas désigné**.
Le pont Halo est lui aussi un C6 : l'ouvrir par erreur peut le redémarrer.
- **Réglages › Sonde :** choix du port parmi les `/dev/cu.usbmodem*`.
- **Mémoire :** le numéro de série USB est retenu, pour se reconnecter seul.
- **Vérification :** une sonde répond à `bonjour` avec
  `"produit":"sonde-maillage"`, sinon le port est refusé.
- **Nom :** à chaque `bonjour`, l'app retient le nom de la sonde à côté de
  son numéro de série, et la montre sous ce nom (section 5). Le port, lui, ne
  peut pas changer de nom : le nom de produit USB et le numéro de série (la
  MAC) du C6 sont fixés par la puce. Avant la première connexion, l'app ne
  sait pas qu'un port est une sonde.

## 3 bis. Accès par le réseau Thread (sonde 1.0.2, 29/09)

**Origine.** Demande de Djoko pendant la vérification sur la carte : pouvoir
débrancher la sonde du Mac et la promener dans la maison, pour un relevé
complet (elle n'entend pas les mêmes routeurs d'une pièce à l'autre). Tout
existe déjà pour le pont Halo de benq : l'accès reprend son infrastructure
telle quelle, sans nouveau design (contrat commun du 29/09, d'après le
résumé de l'accès réseau de Halo).

**Rôle.** En 1.0.2, la sonde est **FED** (enfant complet, mode `rdn`, jamais
éligible routeur) : comme en MED, elle ne devient jamais routeur ni parent et
ne relaie rien ; mais elle entend les routeurs voisins et leur demande un
lien, d'où leur ExtMac (`routeurs`, section 4).

**Transport.**
- UDP sur IPv6, port fixe **5480** (socket OpenThread), vers
  `<hote>.local:5480` : le nom d'hôte SRP que Matter enregistre auprès des
  routeurs de bordure (`bonjour.hote`, appris par l'USB), résolu à chaque
  connexion ; l'adresse OMR de la sonde suit donc les changements de préfixe.
- La route IPv6 du Mac vers le préfixe OMR vient de l'assistant `halo-routes`
  de benq (un bug du noyau de macOS la retire) ; sans elle, l'app le dit
  (« Pas de route IPv6… »). Résoudre un nom `.local` demande l'autorisation
  « Réseau local » de macOS.
- Un datagramme, une charge. Requête de l'app : `<rid> <commande>` (rid
  décimal, croissant, jamais remis à zéro à une reconnexion ; commande = le
  même texte que sur l'USB, sans fin de ligne). Réponse : `<rid> <ligne JSON>`
  (la ligne de l'USB, sans RS ni LF). Une réponse `routeurs` peut compter
  plusieurs lignes sous le même rid.
- Une charge de réponse fait 1100 octets au plus : au-delà, `routeurs` se
  coupe (`suite`) et un `diag` répond `trop_long`, à distance seulement. La
  tournée ne compte pas un routeur `trop_long` comme muet : elle refait une
  fois sa requête en deux moitiés de TLV et les réunit ; une moitié encore trop
  longue est laissée, ce qu'on a est gardé.

**Enveloppe H1**, celle du pont Halo, identique : poignée de main
`SALUT`/`DEFI` signée (`kid` = 8 premiers hexa de SHA-256 de la clé, `na` et
`nc`), clé de session `Ks`, messages `H1 <sid> <ctr> <mac> <charge>` avec le
sens `A` (app vers carte) ou `C` (carte vers app), fenêtre anti-rejeu de 32,
2 DEFI par seconde au total, 2 sessions et 1 provisoire, comparaisons en temps
constant, texte canonique strict. **Authentifiée, non chiffrée :** la
topologie (routeurs, liens, enfants, adresses) circule en clair sur le réseau
local. Sans clé, la carte se tait : ni réponse, ni ICMP.

**Clé.**
- Créée par l'USB seulement : Réglages › Sonde › « Autoriser l'accès réseau »,
  la sonde retenue branchée et connectée, hors tournée. L'app tire 32 octets
  et envoie `cle nouvelle <64 HEXA> <id>` ; la carte tire les siens, calcule
  `HMAC-SHA256(clé = aléa de l'app, message = aléa de la carte)`, la garde en
  NVS et la rend une seule fois (`cle`, avec l'empreinte et le nom d'hôte).
- L'app vérifie l'empreinte, puis range la clé dans le trousseau du Mac :
  service `fr.djoko.maillage.sonde`, compte = nom d'hôte (sans `.local`),
  commentaire = empreinte. Jamais dans un journal, une préférence ou un
  fichier ; les tests n'utilisent jamais le vrai trousseau.
- « Oublier la sonde » efface la clé de ce Mac (la carte garde la sienne). Une
  nouvelle autorisation remplace la clé de la carte et fait tomber les
  sessions réseau en cours ; le désappairage (`oubli`) l'efface côté carte.

**Liste blanche à distance :** `bonjour`, `etat`, `voisins`, `routeurs`,
`diag`. Tout le reste (`cle…`, `nom`, `oubli`) est refusé
(`{"v":1,"t":"erreur","erreur":"refuse"}`). Par le réseau, `bonjour` ne donne
ni code d'appairage ni QR code : qui les lirait pourrait ajouter la sonde à
son propre contrôleur. Réglages › Sonde met une note à leur place : les voir
demande l'USB.

**Fiabilité, côté app.**
- Une commande sans réponse repart avec le même rid à 2 s puis à 4 s ; la
  carte ne relance rien : elle renvoie la réponse gardée (les 8 dernières par
  session, dans la limite de 4096 octets par session ; au-delà, un rid répété
  relance la commande, une lecture), ou se tait si la commande est encore en
  cours. Un `diag`, muet côté carte pendant son vol (son délai, 6 à 8 s),
  repart ensuite 1 s après la fin du vol, puis toutes les 3 s, le dernier au
  plus tard 1 s avant l'échéance de `SondeUSB` (délai du diag plus 5 s) : 2,
  4, 7 et 10 s pour un diag de 6000 ms, 2, 4, 9 et 12 s pour 8000 ms. Les
  renvois fixes de 2 et 4 s partent encore pendant le vol ; ceux d'après le
  vol n'y tombent plus (la file de la carte n'a que 4 places).
- Une ligne identique sous le même rid (réponse renvoyée) est écartée ; les
  lignes différentes d'une même réponse passent toutes.
- **Cadence :** la carte accepte 20 commandes par seconde glissante et par
  session, et se tait au-delà (le renvoi de 2 s rattrape). L'app envoie au
  plus 18 nouveaux rid par seconde glissante, dans l'ordre : les suivants
  attendent dans une file, sans rien bloquer d'autre que l'envoi suivant. Les
  renvois ne comptent pas et partent à l'heure ; la veille compte.
- `SondeUSB` attend une réponse 6 s par le réseau, au-delà du renvoi de 4 s,
  et 3 s en USB, comme Halo ; chaque attente a sa propre échéance.
- **Veille :** après 10 s sans aucune ligne, le canal envoie un `etat` de
  veille, dont la réponse reste dans le canal (comme le ping de Halo). Sans
  aucune ligne dans les 6 s, il se ferme et l'app se reconnecte (nouvelle
  poignée de main) à 1, 2, 5 et 10 s, puis toutes les 30 s ; sans clé, sans
  nom d'hôte, ou si la sonde refuse l'accès (port injoignable), elle attend
  l'USB. La carte donne la place d'une session muette depuis 30 s à un nouveau
  client : la veille garde celle de l'app.
- Pendant une session réseau, l'app tient une activité : App Nap retarderait
  la veille et les tournées.

**Liaison (Réglages › Sonde).** Le choix « Liaison » (USB ou Réseau Thread)
paraît quand une clé existe. Par le réseau, la liaison USB est fermée (le port
libéré), l'app se connecte seule à la sonde retenue par son nom d'hôte et se
reconnecte ; un port branché n'est jamais ouvert. Retour à l'USB : la session
réseau se ferme et le port de la sonde retenue, et lui seul, est rouvert. La
dernière perte de la session réseau (depuis quand, et sa cause) reste affichée
jusqu'à la connexion suivante réussie.

**Limites connues.**
- Pas de fin de session (le `json 0` de Halo) : une place de la carte reste
  prise jusqu'à 30 s après la dernière activité. Deux reconnexions rapides
  peuvent faire attendre la suivante ; la reprise automatique le répare.
- La file de réception de la carte a 4 places, comme celle de Halo : un envoi
  groupé de 8 `diag` peut en voir attendre le renvoi à 2 s.
- Une ligne `routeurs` perdue en route donne une table partielle, ou aucune si
  la dernière (`"suite":false`) se perd : rien ne la redemande.

## 4. Tournée (révisée le 29/09 : après l'essai, à l'exécution du plan 3a, puis pour les identités des routeurs, sonde 1.0.2)

**Quand :**
- la tournée courte, toutes les 5 minutes et au bouton rafraîchir, sauf
  pendant une tournée : le bouton ne la relance pas, et la suivante part
  toujours 5 minutes après la fin de celle-ci. `etat` n'est pas surveillé
  entre deux tournées : un autre chef ou une autre partition est vu à la
  tournée suivante. Une autre partition remet à zéro la mémoire de la
  tournée, car les identifiants de routeur y sont redistribués ;
- le balayage, toutes les 30 minutes, et quand l'ensemble des routeurs à
  balayer change.

**Tournée courte :**
1. `etat` de la sonde : partition, chef, préfixe du réseau maillé, parent
   (RLOC16 et ExtMac). Puis, si elle est attachée et non suspendue,
   `routeurs` : la table des routeurs de la sonde (firmware 1.0.2, en FED ;
   requête locale, sans délai réseau). Elle donne le RLOC16 de chaque routeur
   de la partition, et l'ExtMac de ceux que la sonde entend (voir
   « Rapprochement »). Sans table (firmware 1.0.1, sonde occupée), la tournée
   continue sans elle.
2. **Liste des routeurs :** Route64 (5) et Leader Data (6), demandés jusqu'à
   ce que l'un réponde avec une Route64 :
   - au chef, sauf s'il est muet : il passe alors après les autres ;
   - aux routeurs qui ont répondu à la dernière tournée où l'un a répondu, un
     à un ;
   - sinon, aux autres identifiants de routeur, de 0 à 62, par groupes de 8
     dans l'ordre croissant. Au premier groupe où l'un donne une Route64, on
     prend celle du plus petit identifiant et on s'arrête ;
   - **sans Route64, pas de nouveau maillage :** la mémoire d'avant est
     gardée (remise à zéro dans une autre partition), avec les identités
     apprises au point 1 (parent, table des routeurs) : une sonde promenée ne
     les perd pas. Le dernier maillage reste affiché en vieillissant (« Sonde
     muette », plus bas). Si rien ne répond, la recherche coûte au plus 63
     requêtes, de l'ordre d'une minute, à chaque tournée.
3. **Rôles :** Network Data (7) à un routeur qui répond. On y lit :
   - les routeurs de bordure (préfixes, routes, service SRP) ;
   - le BBR principal (service 01), choisi comme OpenThread : l'entrée du
     chef d'abord, puis le numéro de séquence le plus haut (comparaison
     simple), puis le RLOC16 le plus haut. Un serveur dont les données font
     moins de 7 octets est ignoré ;
   - celui qui publie l'OMR.

   Les dernières Network Data lues sont gardées dans la mémoire de la
   tournée (remise à zéro dans une autre partition). Quand la requête échoue,
   ou qu'aucun routeur ne répond, elles marquent encore les routeurs de
   bordure et le BBR principal, pour les seuls routeurs de la liste : sans
   elles, ces routeurs et leurs candidats disparaîtraient d'une tournée à
   l'autre.
4. **À chaque routeur qui répond** (RLOC16 = identifiant << 10) :
   - Ext MAC (0), Address16 (1), Route64 (5), Child Table (16), IPv6 Address
     List (8), Version (24) ;
   - par le réseau, une réponse `trop_long` n'est pas un silence : la même
     requête, une fois, en deux moitiés de TLV (0, 1, 5 puis 16, 8, 24),
     réunies ; une moitié encore trop longue est laissée, sans échec ni
     balayage (section 3 bis). L'avancement de l'étape compte ces deux
     requêtes de plus ;
   - un routeur qui répond sans son ExtMac (une moitié sans réponse) garde
     l'identité connue de sa paire, comme un muet, lue après toutes les
     réponses de la tournée (une ExtMac passée à un autre routeur a fait
     oublier la paire périmée) ;
   - une fois, les TLV 25 à 28 : on ne garde que la version de la pile (28) ;
     25 à 27 étaient vides à l'essai (écart 1 du plan).
5. **Routeur muet :** un routeur qui ne répond pas deux tournées de suite est
   muet, et on ne l'interroge plus qu'une fois par heure. Les routeurs de
   bordure d'Apple le sont tous. Le maillage rendu marque « muet »
   (`RouteurMaillage.muet`) tout routeur sans réponse à la tournée, dès le
   premier échec ; aucune vue ne lit encore ce drapeau.
6. **Identité des enfants des tables :** Ext MAC (0) et IPv6 Address List (8),
   demandés à chaque enfant lu dans une Child Table, au plus une fois par
   demi-heure (voir « Appareils endormis »).

**Balayage des enfants des routeurs qui ne répondent pas :**
- **Cibles :** les routeurs sans réponse à la tournée qui sont muets (deux
  tournées de suite) ou n'ont jamais répondu depuis le début de la mémoire,
  comme ceux d'Apple dès la première tournée. Un routeur qui rate une seule
  tournée n'est pas balayé. Pour chacun, les RLOC16 d'enfant de 1 à 32, avec
  Ext MAC (0), Address16 (1), Mode (2) et IPv6 Address List (8). On s'arrête 8
  numéros après le dernier qui a répondu.
- **Cadence :** 8 requêtes en vol et 8 s de délai. Les endormis répondent à
  leur réveil ; ceux de l'essai l'ont fait en 1,5 à 5 s.
- **Charge :** environ 160 requêtes, 2 à 3 minutes.
- **Résultat :** l'enfant et son parent (le RLOC16 le donne), sans qualité de
  lien ; le routeur muet ne dit rien.
- **Entre deux balayages,** les enfants trouvés sont gardés, et affichés sous
  leur parent tant qu'il ne répond pas.

**Appareils endormis :** le balayage les interroge sous les routeurs qui ne
répondent pas. Sous un routeur qui répond, leur lien (parent, qualité) se lit
dans sa Child Table, mais elle ne donne pas leur ExtMac : l'identité de chaque
enfant des tables (ExtMac, adresses) est donc demandée au plus une fois par
demi-heure, endormis compris. C'est un écart assumé à « sans les réveiller » :
au plus deux réveils par heure et par appareil endormi. Une identité obtenue
est gardée jusqu'à une nouvelle réponse.

**Rapprochement :**
- **Appareil Matter :** son ExtMac est son nom d'hôte mDNS, donc
  l'identifiant de l'appareil dans l'instantané.
- **Routeur de bordure et ExtMac :** l'ExtMac est le `xa` de son TXT
  `_meshcop._udp`. Mais un routeur muet ne donne pas son ExtMac. Son
  RLOC16 se relie à son `xa` :
  - s'il est le parent de la sonde : `etat` donne les deux. La paire est
    retenue, et la sonde en apprend d'autres quand elle change de parent ;
  - s'il est entendu par la sonde : sa table des routeurs (`routeurs`)
    donne la paire. En FED, la sonde demande un lien aux routeurs qu'elle
    entend et apprend ainsi leur ExtMac, jamais celle de son parent ; la
    paire est retenue comme celle du parent. Déplacée dans la maison, la
    sonde finit par entendre tous les routeurs ;
  - s'il est le BBR principal, encore non identifié : les Network Data
    donnent son RLOC16, et le bit `bbrPrimaire` de `sb` désigne son annonce ;
  - s'il est le chef, routeur de bordure encore non identifié : `etat` donne
    son identifiant, et le rôle (bits 9-10 de `sb`, Thread 1.4) désigne
    l'annonce du chef dans la même partition. Les routeurs de bordure
    d'Apple remplissent ce rôle (relevé du 28/09 : l'Apple TV est chef) ;
  - **par élimination :** s'il reste exactement un routeur de bordure non
    identifié dans le maillage et exactement une annonce de routeur de
    bordure non reprise dans la même partition, c'est le même. Cette
    déduction n'est pas retenue : elle se refait à chaque affichage. La fiche
    du routeur dit qu'il est reconnu par élimination.

  Les identifications par l'ExtMac (le `xa` d'une annonce, l'hôte d'un
  appareil) passent d'abord. Les règles du BBR principal et du chef ne
  s'appliquent que s'il reste une seule annonce de ce rôle, non reprise,
  dans la partition : un cache périmé peut en garder une seconde, avec le
  même `pt`, et le routeur reste alors non identifié, avec les deux pour
  candidates. Ces deux règles, l'élimination et les candidats (plus bas)
  écartent une annonce si l'ExtMac du routeur et le `xa` de l'annonce sont
  connus tous deux et différents, ou si ce `xa` est l'ExtMac connue d'un
  autre routeur (une annonce en double de celui-ci).

  **Mémoire des identités :** les paires retenues (parent de la sonde,
  routeurs qui répondent, routeurs entendus) sont gardées d'un lancement à
  l'autre avec leur partition, dans `identites-routeurs.json` du dossier de
  l'app. Elles ne sont jamais lues ni écrites en démo, ni sous les tests
  hors d'un dossier temporaire. Une autre partition les efface à la première
  tournée, comme le reste de la mémoire. Une ExtMac n'a qu'un RLOC16 : un
  routeur qui change d'identifiant perd l'ancienne paire. Dès que la tournée
  a la Route64, les paires des routeurs sortis de la liste (routeur disparu,
  identifiant libéré) sont oubliées. Un échec d'écriture du fichier est
  consigné dans le journal du Mac (Console, sous-système
  `fr.djoko.maillage`, sans données du réseau) ; les identités restent en
  mémoire et l'écriture est retentée à la tournée suivante.

  **Affichage honnête** d'un routeur de bordure non identifié, un seul nœud
  par routeur :
  - il s'affiche avec ses candidats, sous leur nom : les annonces de sa
    partition qu'aucun routeur n'a reprises, sauf celles qu'écarte la
    comparaison de l'ExtMac et du `xa` (plus haut) ; par exemple
    « HomePod Avant ou HomePod Palier · 0400 » ;
  - un seul candidat, sans élimination possible :
    « HomePod salon ? · 0400 », car ce n'est peut-être pas lui ;
  - tant que la sonde donne un maillage de la partition, les annonces
    candidates ne sont plus dessinées à part : ce nœud les porte. Le centre
    de la zone reste dessiné, candidat ou non ; avec les règles du BBR
    principal et du chef, il ne l'est plus que rarement (rôle inconnu en
    Thread 1.3, annonce périmée, Network Data jamais lues) ;
  - sa fiche liste les candidats ; chacun est un bouton qui ouvre la fiche
    de son annonce (rôle, adresses, journal, « Renommer… »), tant que
    l'instantané la connaît ;
  - sans candidat, il s'affiche « Routeur de bordure · B400 ».

  Sans sonde (ou quand son maillage est périmé), rien ne change : toutes les
  annonces sont dessinées.
- **Autre appareil** (HomeKit sur Thread, par exemple) : une adresse OMR
  commune entre sa liste d'adresses et celles de l'instantané.
- Sinon, « non identifié ».

**Sonde muette, ou tournée sans Route64 :** le dernier maillage reste affiché
15 min, marqué « ancien » au bout de 6 min, puis on revient aux pointillés.
Ces durées se comptent depuis la réception du maillage, à la fin de sa
tournée. Pendant une tournée, il n'est pas marqué « ancien » : le suivant
arrive. En marche normale, il ne l'est donc jamais.

**Avancement :** la tournée signale le début de chaque étape qu'elle
atteint (état de la sonde, liste des routeurs, routeurs, pile et Network
Data, balayage, identité des enfants), puis chaque requête revenue : les
requêtes faites sur le total prévu de l'étape, 0 si elle n'a rien à faire. Ce
total ne baisse jamais :
- état de la sonde : `etat` puis `routeurs`, soit 2 ; l'étape s'arrête à 1
  si la sonde n'est pas attachée, ou suspendue ;
- liste des routeurs : le chef et les secours, puis, s'il faut chercher,
  tous les autres identifiants ; l'étape s'arrête à la première Route64,
  souvent avant son total ;
- balayage : pour chaque routeur, les numéros jusqu'à 8 après le dernier
  enfant trouvé. Le total grandit quand un enfant répond loin, et finit égal
  aux requêtes envoyées (48 à la première tournée rejouée sur la capture de
  l'essai).

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

**Barre d'outils du graphe.**
- Pendant une tournée, sur une ligne à part, centrée sous la barre et sous le
  bandeau d'un réseau scindé : un petit indicateur de progression et
  « Balayage des routeurs muets · 24/48 · 0:42 » (l'étape, les requêtes
  revenues sur le total prévu, section 4, et la durée, à jour chaque
  seconde). La capsule a la largeur de la plus longue étape, la barre garde
  la sienne : rien ne bouge sous le pointeur.
- La place de cette ligne est gardée en haut du graphe tant qu'une sonde est
  retenue, pendant une tournée ou non : le graphe ne bouge ni au début ni à la
  fin d'une tournée (seulement quand une sonde est retenue ou oubliée), et la
  ligne ne recouvre pas les titres des zones.
- Le bouton rafraîchir relit le réseau, lance une tournée (pas pendant une
  tournée) et le passeur des noms de Maison, en mode direct et seulement si
  un dossier des noms est choisi (« Rafraîchir depuis Maison », lui, demande
  le dossier s'il manque). Il n'est jamais désactivé. Son aide dit ce qu'il
  lancera vraiment : le réseau toujours, une tournée si la sonde est
  connectée et libre, les noms de Maison si le passeur sera lancé.

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

**Menu.** Une ligne sous le nom de la sonde retenue quand l'état la concerne :
« SONDE-01 : connectée · relevé il y a 2 minutes », « SONDE-01 : absente » ;
pendant une tournée, son étape et son compteur, « SONDE-01 : Routeurs 3/7… ».
Sinon (nom pas encore connu, connexion, refus ou erreur d'un autre port
choisi) : « Sonde : … ».

**Réglages › Sonde :**
- le port : la sonde retenue sous son nom seul (« SONDE-01 ») ; tout autre
  port sous son nom et son numéro de série USB (« usbmodem11301 · » suivi du
  numéro ; la MAC, pour un C6) : seul moyen de distinguer la sonde du pont
  Halo avant la première connexion ;
- l'état, précédé du nom de la sonde retenue quand il la concerne
  (« SONDE-01 · connectée »), l'état seul pour un autre port choisi (refus,
  erreur) ; partition, dernier relevé ; pendant une tournée, « Tournée :
  Balayage des routeurs muets · 24/48 · depuis 42 s » ;
- le QR code Matter de la sonde (noir sur blanc, agrandi sans lissage) et son
  code d'appairage mis en forme 4-3-4, même quand elle est dans Maison ; par
  le réseau, qui ne les transmet pas, une note dit de brancher la sonde en
  USB pour les afficher ;
- l'interrupteur « Sonde maillage » (lecture seule) ;
- l'accès par le réseau (1.0.2, section 3 bis) : « Accès réseau : autorisé ·
  clé <empreinte> » ou « non autorisé », le bouton « Autoriser l'accès
  réseau » (en USB), le choix de la liaison, le nom d'hôte visé par le réseau
  à la place du port, et la dernière perte de la session réseau
  (« Dernière perte », depuis quand, et sa cause).

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
comme Halo Compagnon. Il n'y a rien de nouveau côté réseau : l'accès à la
sonde par le réseau Thread (1.0.2) se contente de
`com.apple.security.network.client`, déjà là, et de l'autorisation « Réseau
local » que macOS demande à la résolution de `<hote>.local` ; la clé va dans
le trousseau, que macOS peut demander d'autoriser (signature ad hoc).

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

**Vérifié avec Djoko les 29 et 30/09** (plan 3a ; firmwares 1.0.0, 1.0.1 puis
1.0.2, flashés sans effacement sur `/dev/cu.usbmodem11301`, l'interrupteur
« Sonde maillage » allumé avant chaque flash) :
- **Liaison USB :** sonde choisie une fois dans Réglages › Sonde, puis reprise
  seule après un débranchement, sans « port occupé » ; nom « SONDE-01 » et QR
  code Matter affichés (1.0.1).
- **Maillage :** 7 routeurs, dont 5 muets (les routeurs de bordure d'Apple) ;
  7 liens radio, tous mesurés par les deux routeurs qui répondent (`5000`, et
  `6000`, le chef). Les liens entre deux routeurs d'Apple restent inconnus.
- **Identités (1.0.2, FED) :** la sonde, alimentée ailleurs et promenée d'une
  pièce à l'autre par la liaison réseau, a donné l'ExtMac des 7 routeurs ; les
  5 routeurs de bordure sont rapprochés de leur annonce, sans doublon ni
  candidat restant. Signal vu par la sonde posée contre l'appareil : `AC00` à
  −41 dBm, `0400` à −39 dBm (devenu son parent), `B400` à −27 dBm à 10 cm.
- **Accès réseau (1.0.2) :** clé créée par « Autoriser l'accès réseau » ; sonde
  jointe par son adresse OMR (route de l'assistant `halo-routes`) ; commandes
  interdites refusées à distance ; silence total face à des datagrammes sans
  enveloppe ; clé gardée au redémarrage.
- **Suspension :** « Sonde maillage » éteint, la sonde est suspendue, encore
  après un redémarrage ; rallumé, les tournées reprennent (une tournée
  ordinaire dure moins d'une seconde par l'USB).

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
