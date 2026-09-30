# Maillage Thread : conception de l'étape 1 (vue depuis le Mac)

> **Statut : conception validée** par Djoko le 28/09/2026, section par
> section (1 à 6), spec relue et approuvée. Plan d'implémentation de l'app :
> `docs/superpowers/plans/2026-09-28-maillage-thread-etape-1.md` ; le passeur
> (section 5, révisée le 28/09 après essai : app iOS lancée sur le Mac, pas
> Catalyst) fera l'objet du plan 2 ; la sonde a sa propre spec
> (`2026-09-28-maillage-thread-sonde-design.md`).

## 0. Contexte, but, décisions

**Origine.** Le 27/09 vers 04:14-04:20, 5 appareils Thread ont cessé de
répondre dans Maison. Le diagnostic a été fait à la main depuis le Mac
(journal de l'assistant halo-routes, `dns-sd`, table de routage, TXT des
routeurs de bordure) : l'Apple TV 4K, chef du réseau, a publié un nouveau
préfixe OMR à 04:04:03 avec une nouvelle adresse de lien (redémarrage
probable) ; le hub Aqara M100 s'est retrouvé seul dans une autre partition.
Il faut un outil qui montre cela d'un coup d'œil et le garde en mémoire.

**But (étape 1).** App macOS qui montre le réseau Thread vu depuis le Mac :
routeurs de bordure, partitions, chef, préfixes, appareils Matter/HomeKit sur
Thread et leur partition, appareils sans adresse ; journal des changements ;
notifications.

**Hors périmètre (étape 2, sous-projet séparé, conçu plus tard).** Les vrais
liens du maillage (enfant → parent, routeur ↔ routeur, qualité) via une
**sonde ESP32-C6 dédiée** que Djoko fournira : client de diagnostic réseau
Thread (CoAP `d/dg` vers le port TMF 61631 : Route64, Child Table, Child IPv6
Address List, Vendor Name/Model). La sonde restera un appareil terminal (MED
ou SED) pour ne jamais devenir le parent de quelqu'un. Fait établi : la pile
OpenThread précompilée d'Arduino (pont Halo) n'a pas `otThreadSendDiagnosticGet`
(client netdiag non compilé) ; elle a `otThreadGetParentInfo`,
`otThreadGetRouterInfo`, `otThreadGetNextNeighborInfo`,
`otThreadGetLeaderRouterId`, `otNetDataGetNextOnMeshPrefix`.

**Décisions de Djoko (28/09).**
- Étapes : vue Mac d'abord, sonde ensuite.
- App **séparée** de Halo Compagnon, **nouveau dépôt** `~/Dev/maillage-thread`
  (hors iCloud ; public ou privé à décider à la création sur GitHub).
- **macOS natif SwiftUI** ; noms de Maison par un **passeur** (HomeKit
  n'existe pas en macOS natif ; révisé le 28/09 : app iOS lancée sur le Mac,
  section 5).
- **Vue + journal** : l'app tourne en permanence (barre des menus, ouverture
  à la connexion) et note les changements.
- Architecture **A** : une seule app (pas d'agent séparé), graphe en Canvas
  SwiftUI (pas de vue web).
- Graphe option **B** (maillage) ; à l'étape 1, **pointillés pâles vers le
  chef** de la partition (rattachement, pas un lien radio) ; **fiche en bas**
  au clic.
- Style **Liquid Glass** (macOS 26) ⇒ **macOS 26 minimum**.

## 1. Architecture et composants (validée)

Dépôt `~/Dev/maillage-thread`, XcodeGen, Swift Testing. Trois cibles :

1. **`MaillageCoeur`** (framework Swift pur, sans interface) : modèle
   (routeurs de bordure, partitions, appareils, préfixes, liens), calcul d'un
   **instantané** à partir des annonces, **différence** entre deux instantanés
   → événements du journal, disposition du graphe. Tout testé sans réseau, sur
   des annonces enregistrées (d'abord le relevé du 28/09, section 8).
2. **`Maillage Thread`** (`fr.djoko.maillage`, app macOS native, bac à sable,
   réseau local) :
   - **recenseur** : écoute en continu `_meshcop._udp` (routeurs de bordure,
     TXT), `_matter._tcp` et `_hap._udp` (appareils), résout les adresses, lit
     les préfixes annoncés ; instantané à chaque changement et au moins
     toutes les 60 s ;
   - **journal** (90 jours, conteneur de l'app) et **notifications** ;
   - **interface** : `MenuBarExtra` (état d'un coup d'œil), fenêtre
     **Graphe** (fiche en bas), fenêtre **Journal** ; ouverture à la
     connexion (`SMAppService.mainApp`).
3. **`Passeur Noms`** (app iOS lancée sur le Mac « conçue pour iPad »,
   capacité HomeKit ; section 5) : lancé à la demande, lit Maison, passe le
   relevé à l'app par la boucle locale du Mac, se ferme (sans dossier depuis
   le plan 4a, 30/09).

Flux : recenseur → instantané → journal et notifications ; instantané + noms
→ graphe. Le modèle prévoit dès l'étape 1 des **liens** (enfant → parent,
routeur ↔ routeur, qualité), vides tant que la sonde n'existe pas.

## 2. Données et interprétation (validée)

- **Routeurs de bordure** (`_meshcop._udp`, TXT) : `nn` (nom du réseau),
  `xp` (identifiant étendu), `xa` (adresse étendue), `pt` (partition), `at`
  (jeu actif), `vn`/`mn` (fabricant, modèle), `tv` (version Thread), `sb`
  (bits : interface, BBR actif/primaire, **rôle seulement à partir de Thread
  1.4** : bits 9-10), `omr` (préfixe OMR, si publié), `dn`, `sq`. Rôle inconnu
  (routeur < 1.4) : « rôle inconnu », jamais « détaché ».
- **Réseaux et partitions** : routeurs groupés par `xp`, puis par `pt` ; plus
  d'une partition dans un réseau ⇒ alerte « réseau scindé » ; chef couronné
  quand son rôle est connu.
- **Préfixes OMR → partition** : champ `omr` ; sinon routes annoncées sur le
  réseau local (préfixe → routeur annonceur → sa partition ; lecture de la
  table de routage depuis le bac à sable à vérifier au jour 1) ; à défaut,
  préfixe des adresses des appareils.
- **Appareils** : `_matter._tcp` (une instance par fabrique,
  `<fabrique>-<nœud>`, regroupées par nom d'hôte = un appareil à N
  fabriques ; `ICD`, ou `SII` de plus de 2 s ⇒ endormi : presque tous les
  appareils Thread annoncent `SII` ; relevé du 28/09 : au plus 2000 ms sur
  secteur, dont le pont Halo à 2000, et au moins 2800 ms sur pile : Zemismart
  2800, Eve Motion 3300, Nuki 3500, Aqara 6000 à 7000) ;
  `_hap._udp` (accessoires HomeKit sur
  Thread, avec leur nom). Adresses : dans un préfixe OMR ⇒ Thread, dans la
  partition du préfixe ; réseau local ⇒ appareil IP (liste à part) ; aucune ⇒
  « sans adresse ».
- **États** : joignable, sans adresse, dans une partition coupée, disparu.
  Aucune sonde active (écoute seulement) : « joignable » veut dire annoncé
  avec une adresse Thread dans une partition non coupée, pas « répond » ; un
  appareil éteint peut rester annoncé tant que son bail SRP court sur le
  routeur de bordure (la sonde de l'étape 2 donnera l'état réel).
- **Délais** : instantané à chaque annonce ; nouvelle résolution des adresses
  toutes les 60 s ; cache mDNS jusqu'à ~1 h ⇒ « vu pour la dernière fois à… ».
- **Noms**, par priorité : surnom (indexé par nom d'hôte Thread) > nom Maison
  (identifiant de nœud sur la fabrique d'Apple) > nom HAP > nom d'hôte.

## 3. Interface (validée, style Liquid Glass)

- Fenêtre « Maillage Thread » : le **graphe occupe toute la fenêtre** (fond
  profond, halos colorés par partition, routeurs en pastilles lumineuses).
  Par-dessus, en verre (`glassEffect`, `GlassEffectContainer`, boutons
  `.glass`) :
  - barre d'outils flottante en capsule : choix du réseau, « Appareils IP »,
    « Journal », rafraîchir ;
  - bandeau d'alerte en capsule ambrée si réseau scindé (heure de la coupure
    tirée du journal, ou « constaté à <heure> » si la scission précède le
    lancement) ;
  - **fiche** de l'appareil sélectionné, carte de verre en bas : nom, pièce,
    fabricant, modèle, type (routeur, Matter, HomeKit, endormi), fabriques,
    adresses, partition, état et « vu il y a… », 5 derniers événements du
    journal pour ce nœud, « Renommer… » ; batterie de Maison (niveau, état de
    charge, âge du relevé ; en orange si faible) ; le point vert « joignable »
    pulse doucement, sauf si « Réduire les animations » est activé (ajouts du
    28/09 au soir).
- Graphe (Canvas SwiftUI, disposition **stable** : mêmes nœuds ⇒ mêmes
  positions) : une zone par partition
  (la plus grande en bleu, les autres en ambre ; identifiant et préfixe) ;
  chef au centre, couronné si connu ; autres routeurs de bordure sur un
  anneau intérieur ; appareils sur un anneau extérieur (triés par pièce puis
  par nom) ; **pointillés pâles vers le chef** (ou le centre de la partition),
  légende « rattachement, pas un lien radio » ; états : vert joignable, rouge
  sans adresse/disparu, gris inconnu, ☾ endormi (🔋 jusqu'au 28/09) ; batterie faible : pastille
  orange en surbrillance au bout du nom (triangle et niveau, ou « faible ») ;
  un appareil disparu reste
  en rouge à sa place jusqu'à son retour ou au prochain lancement ; zoom et
  déplacement au trackpad ; survol = nom + lien éclairé ; clic = fiche.
- **Barre des menus** (même matériau) : icône orange si alerte ; résumé
  (réseau, partitions, routeurs, appareils, injoignables), 3 derniers
  événements, « Ouvrir le graphe », « Journal… », « Rafraîchir depuis
  Maison », « Ouvrir à la connexion », « Quitter ».
- Fenêtre **Journal** : événements datés, filtres par type et gravité,
  recherche.
- Langues : français et anglais (catalogues). Mode clair : fond pâle, verre
  plus clair.
- Étape 2 : les pointillés deviennent les vrais liens (couleur = qualité),
  la fiche montre le parent.
- Maquettes validées (fichiers HTML) : `maquettes/fenetre-liquid-glass.html`
  (fenêtre retenue) et `maquettes/menu-et-fenetre-v1.html` (contenu du menu
  de la barre des menus ; son style est remplacé par Liquid Glass).

## 4. Journal et notifications (validée)

- Événements (différence entre instantanés, dans `MaillageCoeur`) :
  - réseau : scission / réunification, changement de chef ou de BBR
    primaire, nouveau jeu actif ;
  - routeurs de bordure : apparu / disparu, rôle changé, **nouvelle adresse
    de lien** (redémarrage probable) ;
  - préfixes OMR : nouveau / retiré ;
  - appareils : nouveau, disparu, revenu, devenu sans adresse, changé de
    partition.
- Anti-fausses alertes :
  - un nœud est déclaré **disparu** quand il manque depuis au moins
    **2 min** (absence constatée, puis confirmée 2 min plus tard) ;
    l'événement porte l'heure de la première absence ;
  - les **pertes** (un appareil joignable devient sans adresse, disparu ou
    passe dans une partition coupée) survenues dans une même fenêtre de
    **10 min** sont **regroupées** en un seul événement (« 5 appareils perdus
    entre 04:14 et 04:20 ») ;
  - au lancement, un seul point de départ (« Surveillance démarrée :
    6 routeurs, 24 appareils »), sans comparaison avec la session
    précédente ;
  - les **trous de veille du Mac** sont marqués (« Mac en veille de 01:02 à
    07:45 »), jamais d'événement daté du réveil par erreur.
- Événement : heure, type, sujet (identifiant + nom à ce moment), avant /
  après, gravité (info, attention, alerte).
- Stockage : JSON Lines, un fichier par mois dans le conteneur de l'app ;
  un fichier est supprimé quand son mois est fini depuis plus de 90 jours.
- Notifications (autorisation au premier lancement, cases par catégorie) :
  par défaut **alerte** pour scission, routeur de bordure disparu, ≥ 3
  appareils perdus en 10 min (une notification groupée) ; rien pour les
  simples infos. Mode Concentration respecté.

## 5. Noms : le passeur (validée ; révisée le 28/09 après essai)

**Révision du 28/09, après essai.** L'équipe Xcode de Djoko est gratuite
(« Personal Team »).
- **Catalyst refusé.** Le provisionnement refuse HomeKit à une app Mac
  Catalyst : « Entitlement com.apple.developer.homekit not found and could not
  be included in profile ».
- **App iOS acceptée.** Il l'accepte pour une **app iOS lancée sur le Mac**,
  en mode « conçue pour iPad ».
- **Résultat de l'essai :**
  - 131 accessoires lus ;
  - `matterNodeID` présent ;
  - 61 accessoires à 0, parce qu'ils ne sont pas Matter ;
  - 45 accessoires au même nœud, celui d'un pont ;
  - 22 des 23 nœuds de la fabrique d'Apple vus en mDNS retrouvent leur nom.
- **Pas d'App Group :** une équipe gratuite n'y a pas droit.

**Le passeur.**
- **Forme.** `Passeur Noms` (`fr.djoko.maillage.passeur`) est une app iOS
  (SwiftUI), compilée pour « Designed for iPad » et lancée sur le Mac Apple
  Silicon.
- **Signature :** profil gratuit valable **7 jours**.
- **Lancement :** par `outils/passeur.sh`, qui compile avec
  `-allowProvisioningUpdates`, enveloppe l'app comme Xcode (`Wrapper/` et
  `WrappedBundle`), puis la lance. Ou par l'app, en arrière-plan, tant que la
  signature est valide : « Rafraîchir depuis Maison », et à l'ouverture de la
  fenêtre du graphe si le relevé a plus de 15 min, puis toutes les heures tant
  qu'elle reste ouverte (révision du 28/09 au soir, pour les batteries).
- **Gatekeeper :** au premier lancement d'une compilation, il demande une
  autorisation dans Réglages Système › Confidentialité et sécurité.

**Ce qu'il fait.**
- Il ouvre Maison (invite unique « … souhaite accéder à vos données Maison »).
- Il relève, pour chaque accessoire : nom, pièce, fabricant, modèle,
  catégorie, `matterNodeID` (`UInt64?` en Swift ; « node identifier used to
  identify the device on Apple's Matter fabric »), ainsi que le nom du
  domicile et, depuis le 30/09 (plan 4a), les zones de Maison avec leurs
  pièces, dans l'ordre de Maison (`ZoneMaison`, champ facultatif).
- **Batteries (ajout du 28/09 au soir).** Pour chaque accessoire qui a un
  service Batterie : niveau (0 à 100), état de charge (hors charge, en charge,
  non rechargeable) et alerte « batterie faible » de l'accessoire
  (`BatterieMaison`, champ facultatif). Maison répond depuis son cache
  (0,2 s pour 78 valeurs), sans réveiller les appareils ; un appareil
  injoignable garde sa dernière valeur connue. Essai du 28/09 : 46 accessoires
  avec batterie, tous avec l'alerte, 26 avec le niveau, 6 avec l'état de charge.
- **Révision du 30/09 (plan 4a ; spec de la vue par pièces, section 3) :
  plus de dossier.** L'app écoute sur `127.0.0.1` (TCP, port choisi par le
  système), tire un jeton à usage unique, puis ouvre le passeur sans
  l'activer, avec l'URL `maillage-passeur://releve?port=<port>&jeton=<jeton>`.
  Le passeur lit Maison, se connecte et envoie le jeton, la longueur du JSON
  puis le JSON (`NomsMaison`, trame `EnvoiPasseur`) ; il se ferme dès que
  l'app a tout lu (10 s d'envoi au plus). Ouvert à la main (sans URL), il
  montre ce qu'il a lu et se ferme 10 s plus tard ; il n'envoie rien, sauf si
  l'app l'appelle pendant ses 10 s. Sa fenêtre passe toujours un instant
  derrière les autres. Aucune invite « réseau local » : la boucle locale n'en
  demande pas (essai du passeur-démon, 30/09). Les arguments de lancement
  passés par une app du bac à sable n'arrivent pas : macOS les retire
  (vérifié avec Djoko le 30/09) ; d'où l'URL.
  Auparavant, il écrivait `noms.json` dans un dossier choisi une fois, et
  l'app y déposait `passeur-demande.json` avant de le lancer.

**Côté app.**
- Elle reçoit le relevé par la boucle locale (`NomsInternes`) : jeton
  vérifié à temps constant, au plus 8 Mo, 120 s d'attente (le premier
  lancement attend la réponse à la demande d'accès à Maison), une seule
  écoute à la fois. Elle écrit le dernier relevé valide dans son conteneur
  (`noms.json`, écriture atomique) ; un échec le garde et se dit dans les
  Réglages et le menu (révision du 30/09 ; auparavant, un fichier lu dans un
  dossier choisi une fois, avec un signet à portée de sécurité).
- Elle garde les derniers noms **indéfiniment**, avec leur date. Au-delà de
  7 jours, elle affiche : « Noms du <date> : relance outils/passeur.sh pour
  les rafraîchir. »
- Batterie faible : l'alerte de l'accessoire, ou un niveau de 20 % ou moins
  (décision de Djoko, 28/09).

**Correspondance.**
- L'app retrouve seule la fabrique d'Apple : celle dont les numéros de nœud
  correspondent le mieux aux `matterNodeID`.
- Un `matterNodeID` à 0 est ignoré.
- Un nœud porté par un pont (plusieurs accessoires au même `matterNodeID`,
  par exemple le hub Aqara et ses accessoires Zigbee) prend le nom de
  l'accessoire de catégorie pont ; sinon, celui du premier par nom.

**Si l'accès est refusé,** l'app le dit (Réglages Système › Confidentialité et
sécurité › Maison) et continue avec les surnoms, le fabricant et le modèle
(sonde), ou les noms d'hôte.

**Confidentialité.** Rien ne sort du Mac.

- **Dossier conseillé (révision du 28/09, après essai ; sans objet depuis le
  plan 4a, 30/09)** : hors iCloud et hors du dépôt. Djoko avait gardé la
  racine du dépôt ; le `noms.json` qui y reste n'est plus lu, et reste ignoré
  par git.
- **Vérifié le 28/09/2026 avec Djoko** : `outils/passeur.sh` (Gatekeeper
  autorisé), 131 accessoires écrits ; dans l'app, 22 des 23 nœuds visibles de
  la fabrique d'Apple nommés (le 23e n'est pas un accessoire de Maison), pièce
  sur la fiche ; noms gardés après relancement ; « Rafraîchir les noms de
  Maison » relance le passeur, qui écrit puis se ferme, et l'app relit.
- **Constat du jour** : 4 accessoires de Maison n'annoncent plus leur nœud sur
  la fabrique d'Apple (2 détecteurs, une serrure, un store) ; 3 sont « Sans
  réponse » dans Maison (le 4e répond, sans doute par une adresse gardée en
  cache) ; l'app les montre sans nom. Un redémarrage des routeurs de bordure
  (Apple TV puis HomePod) les fait revenir le soir même, sans réappairage.

## 6. Permissions, erreurs, tests, projet (validée)

- **Permissions** : réseau local (`NSLocalNetworkUsageDescription`,
  `NSBonjourServices` : `_meshcop._udp`, `_matter._tcp`, `_hap._udp`) ;
  notifications ; ouverture à la connexion (`SMAppService`, approbation dans
  Réglages Système › Général › Ouverture) ; HomeKit (passeur seulement) ;
  écoute TCP sur la boucle locale pour le relevé du passeur
  (`network.server`, plan 4a, 30/09 ; il remplace le signet du dossier des
  noms ; `files.user-selected` reste pour « Enregistrer une capture… »).
  Bac à sable avec `network.client` ; lecture de la table de routage par
  `sysctl` (à vérifier au jour 1, repli : préfixes tirés des adresses).
- **Erreurs visibles** : réseau local refusé (bandeau + état du menu, le
  refus se lit comme dans Halo Compagnon : `NoSuchRecord` rapide sur `.local`
  / navigateur `PolicyDenied`) ; aucun routeur de bordure vu (« aucun réseau
  Thread visible sur ce réseau local ») ; passeur absent ou refusé (derniers
  noms gardés, échec dit dans les Réglages et le menu, depuis le plan 4a du
  30/09 ; auparavant, noms désactivés, dit une fois).
- **Tests** : `MaillageCoeur` entièrement testé sur des **fichiers
  d'annonces** (relevé du 28/09, section 8 et `docs/releves/2026-09-28/` :
  6 routeurs de bordure avec leurs TXT, 57 instances `_matter._tcp` sur 28
  hôtes, routes) ; **scénario de la panne du 27/09 rejoué** (reconstitué
  depuis le journal de halo-routes : nouveau préfixe à 04:04, scission,
  5 pertes groupées) ; disposition du graphe déterministe ; journal :
  anti-rebond, regroupement, trous de veille ; contrat JSON du passeur. App :
  quelques tests hébergés (modèle ↔ vue) ; aucun test ne dépend du vrai
  réseau.
- **Captures d'annonces** : une option de débogage de l'app enregistre les
  annonces brutes (TXT en octets, instances, adresses, routes, horodatage)
  dans un fichier JSON ; les fixtures des tests en viennent. En attendant le
  recenseur, une première fixture est écrite à la main depuis la section 8 ;
  elle est remplacée par une vraie capture dès que le recenseur marche.
- **Mode démo** (`-demo`) : rejoue une capture, pour les captures d'écran et
  les essais sans réseau (comme Halo Compagnon).
- **Projet** : Swift 6, concurrence stricte, avertissements = erreurs,
  catalogues FR/EN, signature ad hoc par défaut (`Signature.xcconfig`) ;
  `Local.xcconfig` (équipe, jamais commité) signe l'app avec l'équipe, mais si
  une installation ad hoc existe déjà, macOS dit une fois « L'app diffère des
  versions précédemment ouvertes » et l'autorisation « réseau local » est
  redemandée ; le passeur n'est signé avec l'équipe que par
  `outils/passeur.sh` ; macOS 26 minimum, DMG plus tard. Dépôt hors iCloud
  dès le départ.
- **Vérifié le 28/09/2026 (jour 1, avec Djoko ; MacBook Pro en Wi-Fi et
  Ethernet, réseau réel scindé)** :
  - invites du premier lancement : réseau local, notifications ; ouverture à
    la connexion inscrite après correction (`SMAppService` répond `.notFound`,
    pas `.notRegistered`, pour une app jamais inscrite) ; la case suit
    Réglages Système dans les deux sens ;
  - table de routage **lue** dans le bac à sable ;
  - 6 routeurs de bordure, 2 partitions. L'Aqara HubM100 reste seul dans la
    sienne (au sous-sol, puis 8 min à côté d'un HomePod sans fusion) et a
    annoncé un temps le préfixe OMR de la partition Apple : un **préfixe
    partagé** par deux partitions ne dit pas où sont les appareils ; il va à
    la partition qui a le plus de routeurs de bordure et il est marqué
    « partagé » (capture `docs/releves/2026-09-28/capture-1228.json`) ;
  - premier relevé : attendre aussi 2 s de calme des annonces après l'invite
    « réseau local » (sinon « appareils : 0 », puis une rafale de nouveaux) ;
  - une scission constatée n'est notifiée qu'une fois par état (décision de
    Djoko) ; « trouvé scindé » vaut au lancement, à la découverte ou au
    retour d'un réseau ;
  - capture enregistrée depuis les réglages et relue par
    `CodageJSON.decodeur()` (test sur `capture-1228.json`) ;
  - veille d'une minute : ligne « Mac en veille » ; un relevé pendant
    l'endormissement faisait courir le sursis pendant la veille : il repart
    désormais du réveil ;
  - bouton rafraîchir : aucun faux événement ; textes anglais relus à
    l'écran ;
  - l'icône de la barre des menus peut être masquée par un gestionnaire de
    barre des menus (Pelmet chez Djoko) ;
  - reste à voir en vrai : coupure du réseau local du Mac (couverte par les
    tests) ; Mac portable sur un autre réseau local qui a ses propres
    services Matter ; revendication d'un préfixe par une route, à garder en
    sursis comme les services.

## 7. Étape 2 : la sonde

Conçue et validée le 28/09 dans `2026-09-28-maillage-thread-sonde-design.md` :
- une sonde ESP32-C6 en USB, qui sert de relais ;
- les requêtes `DIAG_GET` sont fabriquées à la main ;
- l'intelligence est dans l'app ;
- deux plans : 3a (la vue) et 3b (le journal et l'historique).

## 8. Faits réels relevés le 28/09 (pour les tests)

- Routeurs de bordure (`_meshcop._udp`) : Apple TV 4K (chef, BBR primaire),
  HomePod Palier, HomePod Avant, HomePod mini bureau, HomePod mini chambre
  (routeurs, BBR actif), tous `nn=MyHome1482620090`, `xp=4B36A2B7FEFB200B`,
  partition `73586B68`, jeu actif du 2024-08-28, `tv=1.4.0` ; **Aqara HubM100
  #DFEB** : même `nn`/`xp`, **partition `E2E79FFC`**, `tv=1.3.0` (bits de rôle
  à 0 = inconnu), BBR primaire, `omr=40FD0354F005DE0001` (fd03:54f0:5de:1::/64).
- Liens-locaux : Apple TV `fe80::5a:d5f3:dc72:e7d6` (a annoncé
  `fd19:961f:2db3::/64` à 04:04:03 le 27/09), HomePod Palier
  `fe80::ae:f065:37ea:3d33` (relayait `fd03:54f0:5de:1::/64` le 26/09 18:17),
  Aqara `fe80::56ef:44ff:fe97:b882` (MAC 54:EF:44, route kernel vers fd03) ;
  ancien préfixe `fd4f:9c:ed42::/64` via `fe80::e14:1eca:d086:9a92` (disparu).
- `_matter._tcp` : 57 instances ; 23 hôtes Thread en `fd19:` (dont le pont
  Halo `56B1E064401F74EF`), 1 hôte Thread **sans adresse**
  (`1E5019DAC2638F92`, `SII=6000`, fabrique `C3B8B0F28E0912FD`), 4 appareils
  IP (dont le hub Aqara `54EF4497B8820000`). Fabriques : `30FC8F95E0E1A385`
  (24 instances), `20D00941B54CEF76` (23), `C3B8B0F28E0912FD` (10) ; le pont
  Halo est dans `20D0…` et `30FC…`.
- Réseau local : préfixe `fd4b:36a2:b7fe:200b::/64`, le préfixe on-link des
  routeurs de bordure, dérivé du `xp` (`fd` + 5 premiers octets + 2 derniers).
  Le Mac y est sur **deux interfaces** (en0 et en18) : chaque routeur de
  bordure et chaque instance y est vu deux fois, à dédoublonner par nom
  d'instance.
- Pièges : `dns-sd` en fichier perd sa sortie tuée (bufferisation) → passer
  par un pseudo-terminal (`script -q /dev/null`) ou par Network.framework ;
  les champs TXT binaires s'échappent mal dans `dns-sd` ; décodage fiable par
  `NWBrowser(.bonjourWithTXTRecord)`.
- Relevé brut, scripts et limites : `docs/releves/2026-09-28/`.
- Capture complète par le recenseur à 02:15 (format `Annonces`) :
  `docs/releves/2026-09-28/capture-0215.json` : même réseau scindé, mais 2
  hôtes sans adresse (`1E5019DAC2638F92` et `724CC16B32D8F820`) ; ce sont
  les données des tests et du mode démo.
