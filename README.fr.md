[English](README.md) · **Français**

# Maillage Thread

App macOS native de la barre des menus (SwiftUI, Liquid Glass) qui montre le
réseau Thread vu depuis le Mac : routeurs de bordure, partitions et leur
chef, préfixes OMR, appareils Matter et HomeKit et la partition où ils se
trouvent. Elle tient un journal des changements (réseau scindé, routeur de
bordure qui redémarre ou disparaît, appareils perdus) et notifie les alertes.

Elle est née d'une vraie panne : le 27 septembre 2026, cinq appareils Thread
ont cessé de répondre à 04:14. À la main, depuis le Mac : le chef (une Apple
TV) avait publié un nouveau préfixe OMR à 04:04, et un hub Aqara s'était
retrouvé seul dans sa propre partition. L'app le montre d'un coup d'œil et
le garde en mémoire.

## Ce que le Mac peut voir

Le Mac n'a pas de radio Thread : l'app **écoute** seulement le réseau local.

| Source | Donne |
|---|---|
| `_meshcop._udp` (TXT) | routeurs de bordure : nom et identifiant du réseau (`nn`, `xp`), partition (`pt`), rôle (Thread 1.4 et plus, bits 9-10 de `sb`), BBR, jeu actif, préfixe OMR publié |
| `_matter._tcp` | une instance par appareil et par fabrique (`<fabrique>-<nœud>`), regroupées par hôte ; `ICD`, ou `SII` de plus de 2 s : appareil endormi |
| `_hap._udp` | accessoires HomeKit (leur nom) |
| adresses des hôtes | préfixe OMR → partition ; réseau local → appareil IP ; aucune → « sans adresse » |
| table de routage du Mac | quel routeur de bordure route quel préfixe OMR |

« Joignable » veut dire *annoncé avec une adresse Thread dans la partition
principale*, pas « répond » : la joignabilité ne vient jamais de la sonde. Une
disparition n'est retenue qu'après 2 minutes d'absence et datée de la première
absence. Les vrais liens (enfant → parent, routeur ↔ routeur, qualité)
viennent de la sonde, un ESP32-C6 branché au Mac ou joint par le réseau
Thread (voir « Sonde » plus bas).

Les appareils sont placés d'après le préfixe OMR de leur adresse. Quand deux
partitions annoncent le même préfixe OMR (vu le 28 septembre : un hub isolé
avait repris le préfixe de la partition principale), le Mac ne peut pas
savoir de quel côté est un appareil : l'app donne le préfixe à la partition
qui a le plus de routeurs de bordure, et la fiche de l'appareil dit sa
partition « incertaine : préfixe partagé ».

## Construire, tester, lancer

Prérequis : macOS 26 ou plus, Xcode 26 ou plus (développé avec Xcode 27),
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
Aucune dépendance tierce. Le projet Xcode est généré : seul `project.yml` est
suivi.

```sh
outils/tester.sh                                   # génère, compile, tous les tests
outils/tester.sh MaillageCoeurTests/SuiviTests     # une suite
outils/mesurer.sh                                  # temps de calcul de la vue par pièces, en Release
```

Les produits de compilation vont dans `~/Library/Developer/Xcode/DerivedData/maillage`
(`DD` pour en changer). Swift 6, concurrence stricte complète, avertissements
traités comme des erreurs.

Lancer : `Maillage Thread.app` dans `…/DerivedData/maillage/Build/Products/Debug/`.
L'app vit dans la barre des menus ; la vue par pièces s'ouvre depuis son menu
(« Ouvrir le graphe », et d'elle-même au tout premier lancement).
Un gestionnaire de barre des menus (Bartender, Pelmet…) peut masquer son
icône : les nouvelles icônes arrivent du côté masqué.

### Mode démo

```sh
open "…/Maillage Thread.app" --args -demo
open "…/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D   # fiche ouverte
open "…/Maillage Thread.app" --args -demo -captures ~/Library/Containers/fr.djoko.maillage/Data/tmp/captures
```

Avec `-captures <dossier>`, l'app écrit vingt images PNG de la vue par
pièces (2D, envol, 3D, zooms, pièces isolées, survol, la fiche du chef, la
légende repliée ; puis les étages : la grille 2 × 2 dans une fenêtre carrée,
la même fenêtre en rangée, la 3D avec le jardin dans la maison, un étage isolé
en 2D et en 3D, une pièce isolée depuis son étage), puis quitte, sans fenêtre.
Son rendu ne dessine ni la fenêtre ni le verre : le haut de la fenêtre, la
légende et la fiche y sont dessinés comme dans leurs maquettes, avec les trois
boutons de la fenêtre à leur place. L'app vit dans un bac à sable : le dossier
doit être dans son conteneur.

La démo rejoue la panne du 27 septembre, reconstituée à partir du relevé réel
du 28 septembre (`docs/releves/2026-09-28/`) : rien n'est écrit, rien n'est
notifié. Les noms de Maison de la démo sont inventés, comme le maillage de la
sonde dessiné sur les mêmes nœuds.

### Signature

`Signature.xcconfig` (suivi) signe ad hoc : le dépôt compile et teste
partout, sans compte Apple, mais l'autorisation « réseau local » ne tient pas
d'une compilation à l'autre. Pour signer Maillage Thread avec son équipe,
créer `Local.xcconfig` (ignoré par git) :

```
DEVELOPMENT_TEAM = <équipe, 10 caractères>
CODE_SIGN_IDENTITY = Apple Development
```

Si une installation ad hoc existe déjà, passer à la signature d'équipe fait
dire une fois à macOS « L'app diffère des versions précédemment ouvertes », et
l'autorisation « réseau local » est redemandée. Passeur Noms n'est signé avec
l'équipe que par `outils/passeur.sh` (voir plus bas).

## Textes : français et anglais

Le français est la langue de développement (les clés des catalogues sont les
textes français), l'anglais est complet. Après un changement de texte :

```sh
outils/tester.sh                      # compilation : le compilateur extrait les clés
outils/synchroniser-textes.sh         # ajoute ou marque les clés du catalogue
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/<fichier>.json
```

`CataloguesTests` vérifie que chaque clé a son anglais et que le code et le
catalogue vont ensemble.

## Code

| Dossier ou fichier | Rôle |
|---|---|
| `MaillageCoeur/` | framework sans interface : décodage des TXT, instantané (réseaux, partitions, préfixes, appareils), suivi et événements du journal, journal en fichiers, noms, table de routage ; testé sur le relevé réel et sur la panne rejouée |
| `MaillageCoeur/Scene/` | vue par pièces, sans interface : nœuds et liens, étages et pièces, cartes, disposition (déterministe, avec budget), places gardées, caméra et envol, placement des noms et zoom sémantique, projection vers le moteur `Canvas` ; optimisé même en Debug |
| `MaillageCoeur/Maillage/` | sonde : TLV du diagnostic, Network Data, protocole USB, modèle du maillage, tournée (routeurs, balayage des routeurs muets), identités des routeurs gardées, rapprochement avec l'instantané (élimination, candidats), journal des parents et des routeurs Thread, historique des tournées et courbes ; testé sur une capture anonymisée |
| `MaillageThread/Sonde/` | liaison avec la sonde : port série sans redémarrer le C6, ports USB, accès par le réseau Thread (`Reseau/` : transport UDP et enveloppe H1 du pont Halo, clé dans le trousseau, rid et renvois), `SondeUSB` (requêtes appariées par id et par cible, chacune avec son échéance), modèle de l'app (sonde retenue par son numéro de série USB, liaison USB ou réseau, une tournée toutes les 5 minutes) |
| `MaillageThread/Noms/` | noms de Maison : lancement de Passeur Noms, réception de son relevé par la boucle locale (écoute TCP sur 127.0.0.1, jeton à usage unique), derniers noms valides gardés dans le conteneur de l'app |
| `MaillageThread/Recenseur/` | NWBrowser (trois types de service) et dns_sd (hôtes, adresses) → `Annonces` |
| `MaillageThread/Surveillance/` | modèle de l'app : relevés → suivi → journal et notifications ; veille du Mac ; ouverture à la connexion |
| `MaillageThread/Vues/` | barre des menus, fenêtre de la vue par pièces (`Pieces/` : moteur `Canvas`, surcouches en verre, captures), journal, réglages (fenêtre AppKit à onglets : Général, Notifications, Maison, Sonde, Diagnostic ; ⌘,) |
| `Passeur/` | Passeur Noms : app iOS lancée sur le Mac (« conçue pour iPad ») qui lit Maison et envoie ses noms, pièces et zones à l'app par la boucle locale |
| `sonde/` | firmware de la sonde (ESP32-C6, PlatformIO) et outils d'essai |
| `outils/anonymiser-sonde.py` | anonymise une capture de la sonde avant d'en faire des données de test |
| `outils/mesurer.sh` | temps de calcul de la vue par pièces (disposition, placement des noms), en Release |
| `docs/releves/` | relevés réels (les données des tests et de la démo) |
| `docs/superpowers/` | conception (spec) et plans d'implémentation |

## Vue par pièces (2D et 3D)

La fenêtre montre le réseau dans la maison : un plateau rond par étage ou par
zone, une carte de verre par pièce avec une ligne par appareil, et les vrais
liens radio par-dessus. Elle reste sombre, comme sa maquette, même quand le Mac
est en clair. Conception :
`docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, et
pour les étages `docs/superpowers/specs/2026-10-03-maillage-thread-polissage-c-design.md`.

- **La fenêtre** n'a pas de barre de titre : la vue monte jusqu'en haut, sous
  les trois boutons de la fenêtre. Une barre d'outils vide et invisible, comme
  dans Plans, abaisse ces boutons et laisse de l'air au-dessus des deux
  capsules de verre, posées sur leur ligne : celle du réseau (menu du réseau,
  appareils IP, journal, rafraîchir) juste après les boutons, celle de la vue
  (2D / 3D, rotation lente) contre le bord droit. Glisser la bande vide entre
  elles déplace la fenêtre ; un double-clic y fait ce que fait un double-clic
  sur une barre de titre sur ce Mac (réglages Bureau et Dock). Dessous, contre
  le bord gauche, comme la légende : la ligne de la tournée, le bandeau d'un
  réseau scindé, le fil « Maison » et, juste sous lui, la ligne de niveau
  (une seule ligne, coupée si elle est trop longue). Le bouton vert passe en
  plein écran : la barre d'outils invisible s'y retire, les boutons s'y cachent
  jusqu'au survol du haut, qui les montre dans une barre de titre sombre
  (elle couvre la capsule le temps du survol), et la capsule du réseau prend
  leur place, contre le bord gauche. 820 × 732 points au moins, soit 680 sous
  la barre de titre cachée.
- **Légende** en bas à gauche, en verre : routeurs, appareils, liens radio
  par qualité et autres signes, seulement ceux que la vue montre, dessinés
  comme dans la scène ; la couronne du chef et la lune d'un endormi y sont
  seules, sans la pastille sombre des noms. Ouverte, la vue d'ensemble se
  cadre au-dessus d'elle ; son chevron (⌄) la replie sur son étiquette, qui
  rend la place, et le chevron de l'étiquette (⌃) la rouvre ; elle reste comme
  on l'a laissée. Une fiche ouverte la laisse visible, au-dessus d'elle ; si la
  fenêtre est trop basse pour les deux, elle se replie d'elle-même jusqu'à la
  fermeture de la fiche. Quand le relevé de la sonde est ancien, une pastille
  orange le dit, à côté de la ligne de niveau, en haut à gauche.
- **Étages et pièces.** Les étages sont les zones de Maison, dans leur ordre
  (le premier en bas) ; une pièce dans plusieurs zones va dans la première,
  les pièces hors zone forment « Autres pièces », et une maison sans zones n'a
  qu'un plateau « Maison ». Un appareil prend la pièce de son accessoire de
  Maison ; un routeur de bordure, celle de l'accessoire de Maison qui porte le
  nom de son annonce. Maison ne donne ni les HomePod ni l'Apple TV : un tel
  routeur va dans la pièce dont le nom figure dans le sien (« HomePod mini
  chambre » dans « Chambre » : en mots entiers, sans égard à la casse ni aux
  accents ; le nom de pièce le plus long gagne, une égalité ne place rien).
  La fiche de tout routeur de bordure que Maison ne place pas, même s'il est
  déjà placé par son nom, propose « Placer dans une pièce… » : ce choix
  l'emporte sur le nom, et il est gardé sous le nom de son annonce
  (`pieces-routeurs.json` dans le dossier de l'app, jamais en démo).
  « Placer dans une pièce… » sert aussi aux appareils que la sonde connaît
  mais que Maison ne reconnaît pas, par exemple un appareil Matter à pile
  dont l'annonce a expiré : le choix est gardé sous l'ExtMac de l'appareil,
  et « Sans pièce » l'efface. Les nœuds qui restent sans pièce vont dans
  « Sans pièce », sur le plateau du bas. Sans aucune pièce de Maison (Passeur
  Noms jamais passé), une carte par routeur, avec ses enfants.
- **Niveaux.** Une zone peut se mettre au niveau d'un étage, à côté de lui,
  dans la maison ou hors d'elle, comme un jardin à côté du rez-de-chaussée ;
  ce choix est gardé avec l'ordre des étages (`positions-pieces.json`, jamais
  en démo), et une zone dont l'étage disparaît redevient un étage.
- **2D et 3D** (capsule de droite ; le mode est gardé d'un lancement à
  l'autre) : la 2D est une vue de dessus, les plateaux en grille, remplie
  depuis le bas, ou en rangée (Réglages › Général › Vue par pièces › Étages en
  2D). La grille se choisit sur la zone visible, la fenêtre moins son haut et
  la légende, pour que la vue soit la plus grande possible : 2 × 2 dans une
  fenêtre carrée ou haute, souvent la rangée dans une fenêtre large, la légende
  ouverte. La 3D empile les niveaux dans la sphère de la maison, les zones à
  côté d'un étage à sa hauteur, dans la sphère ou autour d'elle, avec une
  rotation lente qu'on peut couper. La bascule est un envol de 2,6 s ; les
  plateaux glissent vers leur place quand la fenêtre change de taille, quand la
  légende s'ouvre ou se replie, quand le réglage change, et après un changement
  de niveau.
- **Gestes.** Molette ou pincement : zoom, vers le curseur en 2D. Glisser le
  fond : déplacer la vue en 2D, tourner autour de la maison en 3D. Glisser une
  pièce : la déplacer dans son étage ; sa place est gardée
  (`positions-pieces.json` dans le dossier de l'app, jamais en démo). Clic sur
  une pièce ou sur son nom : l'isoler (les autres s'estompent, un repère
  montre un parent situé ailleurs) ; clic sur un étage, son nom ou son
  disque : l'isoler de même. Clic à côté ou Échap : remonter d'un cran, d'une
  pièce à son étage si on l'a ouverte depuis lui, sinon à la maison ; le fil
  « Maison › Étage › Pièce » y mène aussi. En 3D, ⌥ + glisser déplace la vue
  dans le plan de l'écran. Double-clic sur le fond : retour à la vue
  d'ensemble, zoom et déplacement annulés. Clic sur un appareil ou sur son nom : sa fiche, qui
  glisse depuis le bas pendant que la vue se relève ; la fiche du chef du
  réseau Thread porte « 👑 Chef du réseau Thread, élu automatiquement ». Le
  premier clic agit aussi quand la fenêtre est inactive.
- **Clics droits** : sur le nom ou le disque d'un étage, le menu de son
  niveau, sous son nom : « Monter d'un étage » et « Descendre d'un étage »
  (tout le niveau), « Au même niveau que ▸ », « Hors de la maison » et « Sur
  son propre niveau » ; sur le fond, « Replacer les pièces automatiquement »
  (les places gardées partent, pas l'ordre des étages ni les niveaux) ; sur
  une pièce (sa boîte ou son nom) ou un appareil, aucun menu.
- **Zoom sémantique** : de loin, les pièces seules ; puis les routeurs ; de
  près, tous les noms qui tiennent. La ligne en haut à gauche, sous
  « Maison », dit le niveau, ou combien de noms sont masqués faute de place.
- « Réduire les animations » (accessibilité de macOS) : l'envol et le retour
  par double-clic deviennent un fondu, les autres vols de caméra sont
  immédiats, la rotation lente est coupée, la fiche, la légende et les
  bandeaux du haut vont et viennent par un simple fondu, et la vue se recadre
  par un fondu.
- La disposition des pièces est calculée hors du fil principal : quelques
  centièmes de seconde pour la démo, moins d'une seconde pour 20 pièces et 100
  appareils (`outils/mesurer.sh`).

## Noms de Maison (Passeur Noms)

HomeKit n'existe pas en macOS natif, et une équipe de développement Apple
gratuite ne peut pas le donner à une app Mac Catalyst. Les noms de Maison
viennent donc de **Passeur Noms**, une petite app iOS lancée sur le Mac
(« conçue pour iPad ») : elle lit Maison (noms, pièces, zones, fabricants,
`matterNodeID`, batteries), passe le relevé à Maillage Thread par la boucle
locale du Mac, et se ferme. Aucun dossier à choisir.

```sh
outils/passeur.sh          # compile avec ton équipe (compte Xcode), enveloppe, lance
```

- L'équipe vient de ton certificat « Apple Development » (`EQUIPE=` pour
  l'imposer). Une équipe gratuite a un profil de 7 jours : au-delà, Maillage
  Thread ne peut plus lancer Passeur Noms ; relancer le script. Seul Passeur
  Noms est signé avec l'équipe ; Maillage Thread reste ad hoc.
- Au premier lancement de chaque compilation, macOS dit que l'app est
  « endommagée » : cliquer Annuler, puis Réglages Système › Confidentialité et
  sécurité › « Ouvrir quand même ». Autoriser ensuite l'accès à Maison. Ouvert
  ainsi à la main, Passeur Noms lit Maison, montre ce qu'il a lu et se ferme
  après 10 s. Il n'envoie rien, sauf si Maillage Thread le demande pendant
  ces 10 s.
- Un relevé : Maillage Thread écoute sur `127.0.0.1` (TCP, sur un port choisi
  par le système), tire un jeton à usage unique et ouvre Passeur Noms en
  arrière-plan avec l'URL `maillage-passeur://releve?port=…&jeton=…` (une app
  du bac à sable ne peut pas passer d'arguments de lancement : macOS les
  retire). Passeur Noms lit Maison, se connecte, envoie le jeton, la longueur
  du JSON puis le JSON, et se ferme dès que l'app a tout lu. L'app vérifie le
  jeton, lit au plus 8 Mo et écrit `noms.json` dans son conteneur (écriture
  atomique). La boucle locale ne demande pas l'accès au réseau local. Limite
  connue : toute app de ce Mac peut ouvrir cette URL avec son propre port et
  recevrait le relevé ; rien ne sort du Mac.
- Priorité des noms : surnom > Maison > HomeKit (`_hap._udp`) > hôte.
- Le dernier relevé valide est gardé. Un échec (par exemple Passeur Noms
  introuvable ou refusé, rien en 2 minutes, jeton faux, longueur ou JSON
  illisible, accès à Maison refusé) le garde et se lit dans Réglages › Maison
  et dans le menu ; au-delà de 7 jours, les Réglages disent de relancer
  `outils/passeur.sh`. Passeur Noms note au journal pourquoi il
  s'est fermé :
  `/usr/bin/log show --last 10m --predicate 'subsystem == "fr.djoko.maillage.passeur"'`.
- Rafraîchissement : la fenêtre de la vue par pièces lance Passeur Noms à son
  ouverture (si le relevé et la dernière demande ont plus de 15 min), puis
  toutes les heures ; « Rafraîchir depuis Maison » (menu ou réglages) et le
  bouton rafraîchir de sa capsule du réseau le font à la demande. Un relevé à
  la fois : une demande pendant un relevé est ignorée. La fenêtre de Passeur
  Noms ne fait que passer derrière les autres.
- Zones : les zones de Maison (en général les étages) et leurs pièces, dans
  l'ordre de Maison ; Réglages › Maison en liste les noms. Un relevé d'avant
  les zones n'en a pas.
- Le `noms.json` écrit dans un dossier choisi par un ancien Passeur Noms (à la
  racine de ce dépôt, par exemple) n'est plus lu : l'effacer (git l'ignore).
- Batteries : niveau, état de charge et alerte de l'accessoire lui-même, pour
  chaque accessoire de Maison qui a une batterie. La fiche de l'appareil les
  montre avec l'âge du relevé ; dans la vue, une pastille orange en
  surbrillance, au bout du nom, signale une batterie faible (l'accessoire le
  dit, ou son niveau est de 20 % ou moins).

## Sonde (le vrai maillage)

Le Mac n'a pas de radio Thread. La **sonde** est un ESP32-C6 SuperMini branché
au Mac en USB et ajouté à Maison comme appareil Matter sur Thread (une prise
« Sonde maillage »). C'est un enfant qui ne devient jamais routeur (FED depuis
le firmware 1.0.2) : elle écoute en permanence mais ne relaie rien, donc elle
n'est le parent de personne. Elle envoie pour l'app les requêtes de
diagnostic Thread (`DIAG_GET`) et lui rend les réponses brutes, par l'USB ou,
une fois l'accès autorisé, par le réseau Thread ; l'app les décode et
reconstruit le maillage.

Le **pont Halo** est l'autre projet ESP32-C6 de l'auteur, un pont Matter sur
Thread pour une lampe ScreenBar Halo, dans un autre dépôt. L'accès de la sonde
par le réseau est celui du pont, tel quel, **enveloppe H1** comprise : une
poignée de main signée, puis des messages qui portent chacun un compteur et un
HMAC.

```sh
cd sonde && pio run        # compiler ; flasher et appairer : sonde/README.md
```

- Dans Maillage Thread : Réglages › Sonde › Port. L'app n'ouvre que le port
  choisi : un autre ESP32-C6 branché (le pont Halo, par exemple) n'est jamais
  ouvert. La sonde est retenue par son numéro de série USB et s'affiche sous
  son nom, « SONDE-01 » par défaut : le firmware le garde, il suit donc la
  carte d'un Mac à l'autre (le nom USB du C6 est fixé par la puce). Branchée,
  elle est reprise seule ; si elle démarre trop lentement, l'app réessaie une
  fois 5 s plus tard. Tout autre port s'affiche avec son numéro de série USB
  (« usbmodem… · » suivi du numéro), seul moyen de distinguer la sonde du pont
  Halo avant la première connexion. La ligne du menu prend aussi
  ce nom (« SONDE-01 : connectée · relevé il y a 2 minutes »), comme l'état
  dans Réglages › Sonde (« SONDE-01 · connectée ») ; pas pour un autre port
  en essai.
- Réglages › Sonde montre le QR code Matter de la sonde et son code
  d'appairage (4-3-4), même une fois dans Maison, en USB seulement : ils ne
  passent jamais par le réseau, et une note le dit à leur place.
- **Accès par le réseau Thread** (firmware 1.0.2, comme le pont Halo), pour
  débrancher la sonde du Mac et la promener dans la maison afin d'entendre
  tous les routeurs. Sonde branchée et connectée, « Autoriser l'accès
  réseau » (Réglages › Sonde) crée par l'USB une clé qui reste dans le
  trousseau de ce Mac ; le bouton devient ensuite « Régénérer une clé » (une
  nouvelle clé remplace l'ancienne), et le choix « Liaison » (USB ou Réseau
  Thread) paraît. Par le réseau, l'app ferme le port, se connecte seule à
  `<nom d'hôte>.local`, port UDP 5480, et se reconnecte ; une veille part
  après 10 s de silence, et Réglages › Sonde garde la cause de la dernière
  perte jusqu'à la connexion suivante. L'enveloppe H1 de Halo authentifie les
  messages sans les chiffrer : la topologie circule en clair sur le réseau
  local. Le Mac doit avoir une route IPv6 vers le préfixe OMR (voir
  « Route vers le réseau Thread » plus bas). « Oublier la sonde » retire la
  clé de ce Mac, le relevé de la sonde dans les Réglages et son maillage : la
  vue revient aussitôt aux pointillés.
  Limites : pas de fin de session (une place de la carte reste prise 30 s,
  la reprise automatique le répare) ; la file de réception de la carte n'a
  que 4 places (un envoi groupé de 8 `diag` peut en voir attendre le renvoi à
  2 s) ; une ligne `routeurs` perdue donne une table partielle, ou aucune si
  la dernière (`"suite":false`) se perd ; détails dans la spec (section
  3 bis).
- Une tournée toutes les 5 minutes, et au rafraîchissement : le bouton
  rafraîchir de la capsule du réseau relit le réseau, lance une tournée (sauf
  s'il y en a déjà une) et Passeur Noms ; son aide dit lesquels il lancera
  vraiment. Pendant une tournée, une ligne en haut à gauche, sous les capsules
  (au-dessus du bandeau d'un réseau scindé), montre son étape, un compteur de
  requêtes et sa durée (« Balayage des routeurs muets · 24/48 · 0:42 »). Elle
  n'est là que pendant la tournée : le bandeau et le fil remontent quand elle
  disparaît, et redescendent quand elle paraît. La vue, elle, ne bouge pas :
  sa marge du haut garde la place de la ligne tant qu'une sonde est retenue,
  pour ne pas se recadrer toutes les 5 minutes. Réglages › Sonde et la ligne
  du menu montrent aussi l'étape et le compteur.
- La liste des routeurs vient du chef ; s'il se tait, d'un routeur qui a déjà
  répondu ; sinon des autres routeurs de la table de la sonde, puis d'une
  recherche sur tous les identifiants de routeur (pas de nouveau dans les 30
  minutes qui suivent une recherche vaine). Sans liste, pas de nouveau
  maillage : le dernier vieillit.
- La tournée demande ensuite à chaque routeur qui répond ses liens (avec la
  qualité dans chaque sens) et ses enfants, lit les routeurs de bordure dans
  les Network Data, et demande à chaque enfant listé dans la table d'un
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
  les efface, et la paire d'un routeur sorti de la liste des routeurs est
  oubliée) : déplacée dans la maison, la sonde les apprend toutes. Le chef,
  s'il est un routeur de bordure, est l'annonce de sa partition dont le rôle
  est chef, si elle est la seule ; avec deux (un cache périmé), il reste non
  identifié, avec les deux pour candidates. S'il ne reste qu'un routeur de
  bordure non identifié pour une seule annonce, c'est lui, par élimination.
  Sinon, il s'affiche avec ses candidats,
  « HomePod Avant ou HomePod Palier · 0400 » (« HomePod salon ? · 0400 »
  pour un seul), et ces annonces ne sont plus dessinées à part : un seul nœud
  par routeur. Sa fiche liste les candidats ; chacun ouvre la fiche de son
  annonce. Sans sonde, toutes les annonces restent dessinées.
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
  orange toutes les 5 s (firmware 1.0.3). Après un `oubli`, la commande USB
  qui désappaire la sonde (voir `sonde/README.md`), la sonde revient allumée,
  comme à sa première mise en service.
- **Journal et historique** (plan 3b). Chaque tournée compare son maillage à
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
  l'endroit où elle est posée). Rien de tout cela en démo.
- Les captures de la sonde contiennent les adresses du réseau de la maison :
  `outils/anonymiser-sonde.py` les réécrit de façon cohérente avant qu'elles ne
  deviennent des données de test (`docs/releves/2026-09-29/`) : ExtMac et nom
  d'hôte SRP, préfixes, adresses, MAC, nom et empreinte de la clé de la sonde
  (plan 3b). Il connaît les messages du firmware 1.0.3 et ceux de cette
  capture, la forme de chaque champ et les TLV de diagnostic que la tournée
  demande, jusque dans la Network Data ; il échoue devant tout le reste, sans
  rien écrire. Une capture déjà anonymisée ressort telle quelle. Les textes
  libres (fabricant, modèle, versions, messages de la sonde) sont refusés au
  moindre motif d'identifiant, adresse ou chiffres hexa même coupés par des
  séparateurs : une date ISO peut l'être aussi. Un identifiant déguisé exprès
  dans une chaîne d'un firmware (hexa coupé par d'autres lettres) passerait.

### Route vers le réseau Thread

Par le réseau, l'app joint la sonde à son adresse dans le préfixe OMR, un /64
que les routeurs de bordure (HomePod, Apple TV…) annoncent au réseau local.
macOS n'installe pas toujours la route vers ce préfixe, et peut la perdre en
changeant de routeur de bordure sans la remettre : la sonde est alors
injoignable, et l'app dit « Pas de route IPv6 vers le réseau Thread ». Il
faut au Mac une route vers ce /64 par l'un des routeurs de bordure qui
l'annoncent (la poser demande les droits d'administrateur). L'auteur utilise
pour cela un assistant de son autre projet, qui n'est pas dans ce dépôt.
