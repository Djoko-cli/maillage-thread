# Maillage Thread : conception de la vue par pièces (2D et 3D)

> **Statut : conception validée** par Djoko le 30/09/2026, section par section.
>
> - **Brainstorming visuel :** maquettes successives jusqu'à la v13, validée (« c'est parfait »).
> - **Technique de rendu :** deux prototypes natifs comparés. **A** : un `Canvas` SwiftUI et une projection 3D faite maison. **C** : RealityKit. Choix : **A**, avec la scène séparée du moteur de rendu.
> - **Ce que cette spec remplace :** la section 9 de la spec de la sonde, qui prévoyait RealityKit.
>
> **Maquette de référence :** `docs/superpowers/specs/maquettes/vue-pieces-v13.html`. Maison et noms sont inventés ; ouvrir la page dans un navigateur, qui télécharge three.js. C'est elle qu'il faut livrer. Les valeurs qu'elle porte sont recopiées ci-dessous, et **la spec fait foi** en cas d'écart.
>
> **Deux plans d'implémentation (section 11) :**
> - **4a** : le passeur sans dossier, et les zones de Maison (`docs/superpowers/plans/2026-09-30-maillage-thread-plan4a-passeur-interne.md`) ;
> - **4b** : la vue par pièces ; plan : `docs/superpowers/plans/2026-10-01-maillage-thread-plan4b-vue-pieces.md`.

## 0. Contexte, but, décisions

Aujourd'hui, la fenêtre du graphe range le réseau Thread par partition : un cercle par partition, le chef au centre, les autres routeurs sur un anneau et les appareils en couronne.

Djoko veut voir son réseau **dans sa maison** : par étage et par pièce, avec les vrais liens radio par-dessus. Il veut aussi une **bascule 2D / 3D**, avec un changement de caméra entre les deux modes.

Décisions de Djoko pendant la conception, dans l'ordre :

- La vue par pièces **remplace le graphe actuel**. Les partitions se lisent à la couleur des nœuds et au bandeau de scission.
- **Pièces :**
  - blocs de verre **espacés** (pas jointifs, pas en rangées), disposés de façon **organique** ;
  - en 2D, une pièce est une **carte qui liste ses appareils**, une ligne par appareil (pastille puis nom), et sa taille suit ses noms ;
  - on peut **les déplacer** en les faisant glisser, et leur place est gardée.
- **Étages :** des **plateaux ronds**, côte à côte en 2D, empilés en 3D.
- **La maison** est une **vraie sphère**, qui n'apparaît qu'en 3D : un liseré lumineux, sans reflets.
- **Vraie 2D :** une vue de dessus sans perspective. La 3D en est la même scène, vue autrement. La bascule est un **envol** : inclinaison, orbite et perspective en 2,6 s.
- **En 3D**, une **rotation lente**, qu'on peut couper.
- **Lisibilité** avant tout, au niveau du graphe actuel :
  - beaucoup d'air, et la vue prend toute la fenêtre ;
  - aucun nom n'en chevauche un autre ;
  - un **zoom sémantique** : très loin, les pièces seules ; plus près, les routeurs ; de près, tous les noms.
- **Placement :** il limite les liens qui passent sur une autre pièce ou qui se croisent.
- **Pièce isolée** au clic :
  - les autres pièces s'estompent ;
  - un repère montre un parent situé ailleurs ;
  - un clic sur une autre pièce y mène, un clic à côté ramène à la maison.
- **Aspect :** le fond, les sphères de routeur, les pastilles et les couleurs d'état sont **ceux de l'app** : même dégradé radial, même code de dessin.
- **Rendu :** A, le `Canvas` SwiftUI avec une projection maison. La scène (modèle, disposition, caméra, noms, zoom, transitions) est **séparée du moteur** qui la dessine : un moteur RealityKit pourra s'ajouter plus tard, pour de la vraie 3D, un iPad ou un Vision Pro.
- **Le JSON du passeur** est stocké dans les données de l'app, **sans dossier à choisir**.
- **Feuille de route :** la vue par pièces passe **avant le polissage visuel**, qui portera sur elle. L'ordre devient : vague de mineurs, plan 3b, vue par pièces, puis polissage.

## 1. Place dans l'app

- La vue par pièces prend la place du graphe dans sa fenêtre.
- **La barre du haut** garde le choix du réseau, « Appareils IP », « Journal » et « Rafraîchir ». Elle gagne l'interrupteur **2D / 3D**, puis **Rotation lente**, visible en 3D seulement.
- **On garde :**
  - le bandeau de scission ;
  - la ligne de tournée de la sonde ;
  - la fiche d'un nœud, ouverte en bas au clic sur un appareil ;
  - « Renommer… » ;
  - la sélection, marquée d'un anneau autour du nœud ;
  - la pastille de batterie faible au bout du nom.
- **La légende** actuelle des liens reste jusqu'au polissage. La légende A, contextuelle, choisie par Djoko le 30/09, sera alors adaptée à cette vue.
- **Le mode 2D ou 3D** est gardé d'un lancement à l'autre.
- **La fenêtre reste sombre**, comme la maquette, même quand le Mac est en clair : la barre, les menus, la fiche et les feuilles aussi (ajout du 01/10, choix de Djoko du 30/09).
- **Maillage de démo :** il reçoit des pièces et des étages inventés, ceux de la maquette, pour les captures et les tests.

## 2. Données

### 2.1 Étages

- Les étages sont les **zones de Maison** (`HMHome.zones`). Le passeur les exporte (section 3).
- Une pièce qui appartient à **plusieurs zones** va dans la première qui la contient, dans l'ordre des zones de Maison.
- Les pièces **hors de toute zone**, s'il y en a, forment un plateau « **Autres pièces** ».
- **Maison sans zones**, ou fichier de noms d'avant les zones : un seul plateau, « **Maison** ».
- **Ordre des étages** (lequel est en haut en 3D, lequel à gauche en 2D) : par défaut, l'ordre des zones de Maison, le premier en bas. Un clic droit sur le nom d'un étage propose « **Monter d'un étage** » ou « **Descendre d'un étage** ». L'ordre choisi est gardé (section 2.4).

### 2.2 Pièces

- Ce sont les pièces de Maison : le champ `piece` de chaque accessoire de `noms.json`, qui existe déjà.
- On ne montre que les pièces qui ont **au moins un nœud** de la vue.
- **Couleur d'une pièce :** prise dans une palette de 8 teintes, `#3b82f5`, `#22c55e`, `#f59e0b`, `#94a3b8`, `#a855f7`, `#06b6d4`, `#ec4899`, `#818cf8`, selon cette règle :
  - dans chaque étage, les pièces sont rangées par nom ;
  - chacune prend la teinte d'indice (FNV-1a sur 32 bits de son nom en UTF-8) modulo 8 ;
  - si cette teinte est déjà prise dans l'étage, elle prend la suivante libre.

  Les teintes restent donc stables d'un lancement à l'autre, et différentes dans un même étage jusqu'à 8 pièces. Dans une maison sans pièces (section 2.3), la carte d'un routeur est rangée et teintée d'après l'identifiant du routeur, et non d'après son nom affiché, que la couronne, la lune ou l'alerte changent (ajout du 01/10).

### 2.3 Nœuds et liens

- **Nœuds :** tous ceux du graphe actuel.
  - routeurs de bordure d'Apple, routeurs Matter, enfants, la sonde elle-même ;
  - chacun avec son **état** et ses couleurs actuelles : joignable, disparu, sans adresse, partition coupée ;
  - batterie faible, endormi (☾), chef (👑).
- **Pièce d'un nœud :** celle de l'accessoire de Maison qui lui correspond, par la correspondance du plan 2 (fabrique d'Apple, nœud Matter, pont).
- **Pièce d'un routeur de bordure** (ajout du 01/10, choix de Djoko du 30/09) : celle de l'accessoire de Maison qui porte le nom de son annonce. HomeKit ne donne à une app tierce ni les HomePod ni l'Apple TV ; pour un routeur sans pièce de Maison, dans cet ordre :
  - **le choix** : sa fiche propose « Placer dans une pièce… », un menu des pièces de la maison, avec « D'après son nom » pour revenir à la règle du nom. Le choix est gardé (section 2.4) ; il passe avant le nom ; une pièce qui n'est plus dans Maison ne compte plus ;
  - **le nom** du routeur, celui qu'affiche l'app (son surnom, sinon son annonce) : il va dans la pièce de Maison dont le nom y figure. La comparaison ignore la casse et les accents, et porte sur des mots entiers, qui doivent se suivre (« HomePod mini chambre » → « Chambre », mais « HomePod salons » → rien). Le nom de pièce le plus long gagne (« Chambre d'amis » avant « Chambre ») ; si deux pièces ont cette longueur, le routeur n'est placé nulle part.
- **Pièce d'un autre nœud que Maison ne place pas** (ajout du 01/10, précision 27, demande de Djoko) : un appareil Matter à pile dont l'annonce `_matter._tcp` a expiré marche encore, car le concentrateur garde une session avec lui ; mais l'app, qui ne le relie à son accessoire de Maison que par cette annonce, ne sait plus qui il est. Sa fiche propose alors « Placer dans une pièce… » :
  - **pour qui** : tout nœud sans pièce de Maison, dans une maison qui a des pièces, dont l'ExtMac est connue, par la sonde ou par son nom d'hôte Matter. Ce sont les appareils que la sonde seule connaît, les appareils annoncés que Maison ne reconnaît pas, et les routeurs Thread qui ne sont pas des routeurs de bordure. Les routeurs de bordure gardent les règles ci-dessus : celui que la sonde seule connaît, sans annonce reconnue, n'a pas de choix (précision 25). Un nœud sans ExtMac connue n'en a pas non plus ;
  - **le menu** : « Sans pièce » d'abord, qui efface le choix, puis les pièces de la maison, triées comme pour les routeurs ; le choix en cours est coché ;
  - **la priorité** : la pièce de Maison, puis le choix, puis « Sans pièce » ; il n'y a pas de règle du nom. Quand l'annonce revient et que Maison donne une pièce, Maison l'emporte, et le choix reste dans le fichier, sans effet. Une pièce choisie qui n'est plus dans Maison ne compte plus ;
  - **la clé** : l'ExtMac, par maison (section 2.4). Elle ne change ni avec le parent, ni avec le RLOC16, ni au redémarrage, ni quand l'appareil passe de « connu de la sonde seule » à « annoncé ». Le choix ne s'applique que tant que l'ExtMac du nœud est connue : après un changement de parent (nouveau RLOC16), ou au lancement de l'app, un appareil endormi sous un routeur qui répond reste « Sans pièce » jusqu'à ce que la sonde lise son ExtMac : dans la même tournée s'il répond dans les 8 s, sinon jusqu'à 30 minutes plus tard. Le choix reste dans le fichier.
- **Nœud sans pièce :** un appareil que Maison ne connaît pas et qu'aucun choix ne place, ou un routeur connu seulement par son RLOC16 et qu'aucun choix ne place. Il va dans une carte « **Sans pièce** », sur le plateau du bas.
- **Liens :** les mêmes que le graphe actuel.
  - liens radio entre routeurs : couleur de qualité, 2 pt ;
  - rattachements enfant → parent : trait fin ;
  - rattachements supposés : pointillés, comme aujourd'hui.
- **Pas encore de pièces de Maison** (le passeur n'est jamais passé, ou n'a jamais réussi) :
  - un seul plateau « Maison » ;
  - les nœuds y sont **groupés par routeur parent** : une carte par routeur, qui porte le nom du routeur et ses enfants dedans ;
  - les nœuds sans parent connu vont dans « Sans pièce » ;
  - un bandeau dit « Pas encore de pièces de Maison : lance le passeur », avec le bouton.

### 2.4 Places gardées

- **Fichier :** `positions-pieces.json`, dans le conteneur de l'app, à côté de `identites-routeurs.json`.
- **Contenu :** par maison (`domicile`), l'ordre des étages, et, pour chaque étage, la position `x, z` de chaque pièce que Djoko a déplacée. Les positions sont données par rapport au centre du plateau, en unités de la scène.
- Une pièce déplacée est **fixée** : le placement automatique ne la bouge plus.
- Une pièce **renommée**, ou passée dans un autre étage dans Maison, ne retrouve plus sa place gardée. Elle est replacée automatiquement ; les autres ne bougent pas.
- Un clic droit sur le fond propose « **Replacer les pièces automatiquement** » : il efface les places gardées de la maison, sauf l'ordre des étages.
- **Pièces choisies des routeurs** (section 2.3) : `pieces-routeurs.json`, à côté de `positions-pieces.json`. Par maison (`domicile`), la pièce de chaque routeur, sous l'**instance de son annonce** : le nom sous lequel l'app garde déjà ses surnoms, qui ne change ni avec son RLOC16 ni à son redémarrage. Il ne change que si le routeur est renommé dans Maison ; son choix se perd alors, comme son surnom.
- **Pièces choisies des autres nœuds** (section 2.3, précision 27) : dans le même fichier, sous un champ facultatif `appareils`. Par maison (`domicile`), la pièce de chaque nœud, sous son **ExtMac**, en 16 hexadécimaux majuscules. Un fichier d'avant, qui n'a que les routeurs, se lit sans perte ; la version reste 1, pour qu'une app d'avant lise encore les choix des routeurs d'un fichier d'après. En démo et sous les tests, rien n'est écrit, comme pour les routeurs.

## 3. Passeur : sans dossier, avec les zones (plan 4a)

### 3.1 Transport

Le passeur est l'app iOS « conçue pour iPad » lancée sur le Mac, avec l'équipe gratuite et sans App Group. La voie a été validée par l'essai du passeur-démon (30/09), sauf le point 2, revu à la vérification réelle du même jour (note ci-dessous) :

1. L'app ouvre une écoute TCP sur `127.0.0.1`, sur un port choisi par le système. Elle tire un **jeton à usage unique** : 32 octets aléatoires, en hexa.
2. Elle ouvre le passeur sans l'activer, avec l'URL `maillage-passeur://releve?port=<port>&jeton=<jeton>`, par `NSWorkspace.open(_:withApplicationAt:configuration:)`.
3. Le passeur lit Maison, se connecte à `127.0.0.1:<port>` et envoie :
   - le jeton, sur une ligne ;
   - puis la longueur du JSON (entier décimal), sur une ligne ;
   - puis le JSON de `NomsMaison`, puis il se ferme.
4. L'app vérifie le jeton, en comparaison à temps constant, et lit au plus 8 Mo. Elle décode le JSON, puis l'écrit dans son conteneur (`Application Support/…/noms.json`) par une écriture atomique, et ferme l'écoute.

**Révision du 30/09, à la vérification :** le relevé réel a montré que macOS retire les arguments de lancement passés par une app du bac à sable (le passeur n'a reçu que le chemin de son exécutable) ; l'essai du passeur-démon ne l'avait pas vu, car il lançait depuis le shell. Le port et le jeton passent donc par l'URL, et un passeur déjà ouvert la reçoit aussi : il envoie alors le relevé qu'il vient de montrer.

**Compromis connu :** toute app du Mac, même dans le bac à sable, peut ouvrir cette URL avec son propre port, et le passeur lui enverrait le relevé. Rien ne sort du Mac, mais le passeur ne peut pas reconnaître l'app, faute de secret partagé.

**Échecs :** passeur introuvable, lancement refusé, aucune connexion dans le délai, jeton faux, longueur ou JSON illisible.
- Le **délai** est de 120 s : le premier lancement attend la réponse de Djoko à la demande d'accès à Maison.
- L'app garde le **dernier relevé valide**. L'erreur s'affiche là où l'app montre déjà l'état du passeur, et l'alerte au-delà de 7 jours (profil gratuit) reste.
- Une seule écoute à la fois : une demande pendant un relevé en cours est ignorée.

**Ce qui disparaît :**
- le choix du dossier et le signet de `DossierNoms` ;
- le fichier `passeur-demande.json` ;
- la lecture de `noms.json` dans un dossier choisi.

Le `noms.json` écrit par l'ancien passeur à la racine du dépôt devient inutile. Djoko peut l'effacer : il est ignoré par git.

L'app reste ad hoc, et le passeur garde son équipe gratuite. **Aucune invite « réseau local »** : l'essai l'a vérifié, la boucle locale n'en demande pas.

### 3.2 Zones

- `NomsMaison` gagne un champ **optionnel** `zones: [ZoneMaison]?`, où `ZoneMaison` vaut `{ nom: String, pieces: [String] }`. Les zones et leurs pièces sont dans l'ordre de Maison.
- Un fichier sans ce champ, écrit par un ancien passeur, reste lisible : il donne une maison sans zones (section 2.1).
- `versionActuelle` ne change pas : le champ est additif.

**Vérifié le 30/09 avec Djoko** (plan 4a) : un relevé sans dossier, par la
boucle locale ; 133 accessoires et 4 zones (13 pièces) reçus, zones
affichées dans Réglages › Noms de Maison, dans l'ordre de Maison, et noms
des appareils dans le graphe ; passeur fermé aussitôt ; aucune invite
« réseau local » ni du coupe-feu ; noms relus au relancement de l'app. Le
premier essai, par les arguments de lancement, n'a rien reçu : l'écoute
s'est fermée au bout des 120 s ; d'où l'URL (section 3.1). Un passeur ouvert
à la main, puis appelé par l'app pendant ses 10 s, a envoyé son relevé.

## 4. Scène et disposition

### 4.1 Unités

- Une **unité** de la scène vaut **24 px** à l'échelle naturelle de la 2D (`PX = 24`).
- L'axe y monte : les étages s'empilent sur y en 3D. Le plan de chaque étage est x, z.

### 4.2 Cartes de pièce

Chaque pièce est une carte qui liste ses nœuds, une ligne par nœud.

- **Ordre des lignes :** le chef d'abord, puis les routeurs d'Apple, les autres routeurs, et enfin les autres nœuds ; dans chaque groupe, par nom.
- **Rayon naturel des pastilles, en px :**
  - 15 pour le routeur de bordure principal : le chef s'il est routeur de bordure, sinon le BBR principal. C'est le « centre » du graphe actuel, l'Apple TV chez Djoko ;
  - 13 pour les autres routeurs d'Apple ;
  - 8 pour les autres routeurs ;
  - 7 pour les autres nœuds.
- **Hauteur d'une ligne :** `max(30, 2·r + 12)` px.
- **Colonnes :** de 1 à 3, remplies dans l'ordre des lignes, sans colonne vide.
  - Largeur d'une colonne : `14 + 2·rmax + 9 + largeur du nom le plus long + 14` px, où `rmax` est le plus grand rayon de la colonne.
  - Hauteur de la carte : `somme des lignes de la plus haute colonne + 16` px.
  - On garde le nombre de colonnes dont le rapport largeur / hauteur est le plus proche de 1,3, au sens de `|log(l/h/1,3)|`.
- **Place d'une pastille :** centrée à `14 + rmax` px du bord gauche de sa colonne, et au milieu de sa ligne, qui commence à 8 px du haut. Son nom est posé à droite (section 6).
- **Largeur des noms :** mesurée par l'app, avec la police et la taille réelles, et passée au cœur. Un nom de plus de 40 caractères est coupé, avec « … ».

### 4.3 Disposition des pièces d'un étage

Constantes, en px, à diviser par `PX` :
- écart entre cartes : `GAP = 80` ;
- bande du nom au-dessus d'une carte : `LAB = 28` ;
- marge du plateau : `MARGE = 56` ;
- écart entre plateaux en 2D : `ESP = 140`.

**Séparation.** Deux cartes A et B se recouvrent quand `px > 0` et `pz > 0`, avec :
- `px = (wA + wB)/2 + GAP − |dx|` ;
- `pz = (dA + dB)/2 + GAP + LAB − |dz|`.

On les écarte alors sur l'axe où la pénétration est la plus faible, de moitié chacune. Deux cartes reliées par un lien, sans recouvrement, se rapprochent de 0,3 % de leur écart.

**Tassement :**
- 900 tours de séparation, chacun suivi d'une homothétie de facteur 0,996 vers le centre ;
- puis 60 tours de séparation seule ;
- puis un recentrage sur la boîte des cartes, bande des noms comprise.

**Départ :** les cartes sont triées par aire décroissante. La carte i part de l'angle `phase + i·2,39996` et du rayon `√(i + 0,5)·6`, où `phase = essai·1,047`.

**Rayon du plateau :** la plus grande distance du centre à un coin de carte (bande du nom comprise), plus `MARGE`.

**Coût d'une disposition**, calculé sur la vue 2D des deux étages côte à côte :
- somme des rayons des plateaux ;
- plus 0,3 × la longueur de chaque lien ;
- plus, pour chaque lien qui traverse une carte autre que celles de ses deux bouts (bande du nom comprise), 6 + 4 × la longueur traversée (découpage de Liang-Barsky) ;
- plus 5 par croisement de deux liens sans bout commun ;
- plus, pour chaque lien entre étages, 0,1 × son écart horizontal une fois les étages empilés.

**Optimisation :**
- 6 départs (`essai` de 0 à 5) ;
- à chaque tour, pour chaque étage, on essaie :
  - les 7 symétries du carré, rotations et retournements, appliquées aux positions ;
  - l'échange de chaque paire de cartes non fixées.
- Chaque coup est suivi d'un tassement court (200 tours à 0,998, puis 60 de séparation seule, puis recentrage). On garde le meilleur coup qui fait baisser le coût, et on s'arrête quand aucun ne le fait, ou après 25 tours.
- On retient la meilleure disposition des 6 départs.
- **Pièces fixées** (section 2.4) : elles restent à leur place et servent d'obstacles. Les coups ne touchent que les autres pièces. Sans pièce libre, il n'y a pas d'optimisation.
- **Dégagement** (ajout du 01/10, après la relecture de la tâche 4) : si la disposition retenue garde un recouvrement à cause des fixées, une étape finale déplace chaque pièce libre en cause vers la place libre la plus proche, en tours comptés ; les fixées ne bougent jamais. On garde la moins coûteuse de cette disposition dégagée et du meilleur départ sans recouvrement. Sans recouvrement, rien ne change, au bit près. Deux fixées qui se recouvrent entre elles ne sont pas corrigées.

**Budget :** au plus 3 000 coups évalués par calcul, tous départs compris. Au-delà, on garde la meilleure disposition trouvée. Ce budget ne compte pas le temps, donc le résultat reste le même sur toutes les machines.

**Déterminisme :** aucun hasard. Mêmes entrées, même disposition.

**Quand on la calcule :** seulement quand l'ensemble des étages, des pièces, des nœuds ou de leurs noms change. Le calcul se fait **hors du fil principal**, et l'ancienne disposition reste affichée pendant ce temps.

### 4.4 Étages en 2D et en 3D

- **Centre des plateaux en 2D :** côte à côte sur x, dans l'ordre des étages. Deux plateaux voisins sont séparés de `ESP` entre leurs bords. La même règle s'étend à N étages.
- **En 3D :** tous centrés sur x = z = 0, empilés sur y avec un pas `ETAGE = 1,5 × RMAX`, où `RMAX` est le plus grand rayon de plateau.
- **Hauteur des blocs :** `h(u) = 0,04 + 2,4·u`, où `u` va de 0 (2D) à 1 (3D).
- **Sphère de la maison :**
  - centre `(0, (Y_haut + 2,4)/2, 0)`, où `Y_haut = (n − 1)·ETAGE` est la hauteur du dernier des n étages ;
  - rayon `R3 = hypot(RMAX + 0,8, (Y_haut + 2,4)/2 + 1,4) + 0,4`.
- **Boîte de cadrage 2D :** les plateaux, plus 34 px au-dessus pour les noms d'étage.

## 5. Rendu (moteur `Canvas`)

- **Horloge :** le dessin tourne dans une `TimelineView(.animation(paused:))`, en marche seulement pendant un mouvement : envol, vol de caméra, rotation lente, amorti du zoom ou du glisser, et 0,6 s après la dernière action, le temps que les noms trouvent leur place. **Aucune image au repos.**
- **Ordre des couches**, sans tri de profondeur global, comme la maquette :
  1. plateaux et équateur ;
  2. blocs, triés du plus loin au plus proche, en ne dessinant que les faces tournées vers l'œil ;
  3. liens enfant → parent ;
  4. liens entre routeurs ;
  5. pastilles ;
  6. liseré de la sphère ;
  7. traits de rappel des noms ;
  8. noms.
- **Fond :** le dégradé radial de l'app (`Palette.fond`), derrière le `Canvas`.
- **Plateaux :**
  - polygone projeté de 128 points ;
  - remplissage en dégradé radial, de la couleur de zone de l'app à 0,26 au centre vers 0,08 au bord ;
  - contour de 1 px à 0,45.
- **Blocs :**
  - chaque face visible est remplie de la couleur de la pièce, éclairée comme dans la maquette : `(2,2 + 1,6·n·l)/π`, calculé en linéaire, avec la lumière venant de `(−10, 30, 14)` ;
  - opacité de 0,13 en 2D à 0,18 en 3D ;
  - arêtes de 1 px à 0,75.
- **Pastilles :** le dessin des nœuds du graphe actuel (halo, dégradé des routeurs, état, anneau de sélection, pastille de batterie), sorti dans une fonction partagée.
  - Le rayon suit l'échelle, sans dépasser 1,1 × le rayon naturel, et sans descendre sous 3 px.
  - En 3D, une pastille est à mi-hauteur de son bloc.
- **Liens :**
  - entre routeurs : 2 pt, couleurs de qualité de l'app, bouts ronds ;
  - enfant → parent : 1 px, blanc à 0,28 ;
  - un lien s'éclaire à 0,85 au survol d'un de ses bouts.
- **Sphère :**
  - le contour est l'**ellipse exacte** de la sphère projetée, intersection du cône tangent et du plan de l'image ;
  - il est rempli d'un dégradé qui suit le profil de la maquette : `force · (0,02 + 0,45·(1 − |n·v|)^2,5)`, couleur `(0,55 ; 0,72 ; 1,0)`, avec `force = u²` ;
  - équateur à `0,18·u` d'opacité ;
  - rayon `R3·(0,8 + 0,2·u)`.
- **Noms :** dessinés dans le `Canvas` (`resolve(Text)` gardé en cache, puis pastille arrondie).
  - Un nom immobile est aligné sur les pixels ; un nom qui bouge garde sa position fractionnaire.

## 6. Noms et zoom sémantique

**Styles :**
- **appareil :** 11 pt (`caption2`), blanc à 0,9, sur une pastille `rgba(6, 10, 26, 0,72)` de rayon 4, marges 0 × 5 ;
- **routeur :** 12 pt (`caption`) ;
- **au survol :** semi-gras, blanc ;
- **pièce :** « ● Salon  6 appareils », en 12 pt. Le point a la couleur de la pièce, le compte est en 11 pt `#9fb0d0`, sur une pastille `rgba(14, 22, 48, 0,78)` avec une bordure de la couleur de la pièce à 0,6 ;
- **étage :** en 12 pt, dans la couleur de zone de l'app ;
- **« ⌂ Maison » :** en 13 pt, en 3D seulement, sous le haut de la sphère.

**Placement :** glouton, dans l'espace de l'écran. On traite les noms par priorité croissante, et chacun essaie ses places candidates dans l'ordre. Il prend la première qui est dans le cadre (4 px du bord) et qui ne chevauche, à 2 px près, ni un nom déjà posé, ni une pastille, ni l'interface.

- **Places candidates :** les anneaux 3, 14, 28, 44 et 62 px autour du rectangle de l'objet. Sur chaque anneau, 8 directions ; une diagonale se place à 0,7 × l'anneau.
  - appareil : droite, gauche, haut, bas, puis les diagonales ;
  - pièce : haut, bas, droite, gauche, puis les diagonales ;
  - étage : haut, bas, droite, gauche ;
  - maison : bas, droite, gauche, haut (sous le haut de la sphère d'abord).
- **Priorités :**
  - 0 : maison ;
  - 1 : étages, qui sont fixes (posés même s'ils chevauchent) ;
  - 2 : appareil survolé ;
  - 3 : repères « ailleurs » ;
  - 4 : pièces ;
  - 5 : chef ;
  - 6 : routeurs ;
  - 7 : autres ;
  - 8 : pièces estompées.
- **Stabilité :** un nom garde sa place tant qu'elle reste libre. Il ne rejoint une place meilleure qu'après l'avoir trouvée libre **0,5 s**.
- **Trait de rappel :** dès le deuxième anneau, un trait de 1 px `rgba(230, 236, 250, 0,45)` relie le nom à son objet.
- **Faute de place :** un nom qui ne trouve aucune place est masqué. Une ligne en bas à gauche le dit : « N noms masqués faute de place : rapprochez-vous (molette) ».

**Zoom sémantique**, selon l'échelle `k` = px par unité à la cible de la caméra, divisés par 24 :
- sous 0,42 : **les pièces seules**, avec leur nombre d'appareils ; la ligne dit « Vue d'ensemble : les pièces » ;
- de 0,42 à 0,6 : **les pièces et les routeurs** ;
- au-delà : **tous les noms qui tiennent**.

Le survol montre toujours le nom de l'appareil survolé. En pièce isolée, tous les noms de la pièce sont voulus.

## 7. Caméra, envol, interactions

**Caméra :** une orbite (cible, distance, azimut, inclinaison, champ), avec une projection en perspective et un plan proche à 0,5.

**Vue d'ensemble :**
- **2D :** champ de 2°, vue de dessus. La hauteur de vue est `max(hauteur de boîte·1,1 ; largeur de boîte·1,05 / aspect)`, centrée sur la boîte de cadrage.
- **3D :** champ de 40°, inclinaison 0,95 rad, orbite −0,75 rad. La hauteur de vue est `2,4·R3·max(1, 1/aspect)`, centrée sur la sphère.

**Aspect** (largeur / hauteur de la fenêtre ; ajout du 01/10) : un aspect non fini, nul ou négatif, celui d'un cadre vide pendant une mise en page, vaut 1,6 ; les autres sont bornés de 0,05 à 20. La caméra reste ainsi toujours finie ; entre 0,05 et 20, rien ne change.

**Envol**, 2,6 s, en cubique entrée-sortie :
- il interpole le champ (`2 + 38·u^1,6`), l'inclinaison, l'orbite, la cible et la distance ;
- il part de la vue courante, zoomée ou tournée, sans saut ;
- les plateaux passent de côte à côte à empilés, les blocs montent, la sphère apparaît.

**Rotation lente :** en 3D, un tour en 2 min, réglé en temps et non en images. Elle s'arrête pendant un geste ou une pièce isolée.

**Gestes :**
- **molette ou pincement :** zoom amorti ; en 2D, le point sous le curseur reste immobile. Les bornes vont de 3 unités de hauteur de vue à 3 × la vue d'ensemble en 2D, et de 5 unités de distance à 2,5 × la vue d'ensemble en 3D ;
- **glisser le fond :** déplace la vue en 2D ; tourne autour de la maison en 3D, avec un amorti de 5 % par image, l'inclinaison bornée de 0,15 à 1,45 rad ;
- **glisser une pièce :** la déplace dans son étage, bornée à `rayon du plateau − ½ diagonale de la carte`. Les liens suivent, et la place est gardée au relâchement (section 2.4). Un relevé reçu pendant le geste attend le relâchement : la place glissée est gardée d'abord, puis le relevé s'applique ;
- **clic sur une pièce, sans glisser :** l'**isole** (voir plus bas) ;
- **clic sur un appareil :** ouvre sa fiche ;
- **survol d'un appareil :** nom en semi-gras, liens éclairés.

**Pièce isolée :**
- la caméra y vole en 1,3 s, à la hauteur de vue `max(largeur/aspect, profondeur)·1,3·1,8 + 6` unités ;
- la pièce grandit de 1,3 × ;
- les autres pièces s'estompent jusqu'à 15 %, et leurs nappes et liens aussi ; leurs noms restent visibles en pâle (0,45), pour qu'on puisse y aller ;
- tous les noms de la pièce sont affichés ;
- **repères « ailleurs » :** pour chaque enfant dont le parent est dans une autre pièce, un pointillé vert part de l'enfant vers un repère posé au bord de la pièce, du côté du parent. Le repère porte « ↗ Nom du parent · Pièce ». La flèche devient ↓ ou ↑, avec « , rez-de-chaussée » ou le nom de l'étage, si le parent est à un autre étage ;
- **clic sur une autre pièce :** on y va, en fondu propre à chaque pièce (l'isolement passe d'une pièce à l'autre en 0,3 s environ) ;
- **clic à côté des pièces, Échap, ou « Maison » dans le fil :** retour à la vue d'ensemble ;
- le fil en haut à gauche dit « Maison › Salon ».

**Double-clic sur le fond** (ajout du 01/10, choix de Djoko du 30/09) : retour d'un geste à la vue d'ensemble, pièce isolée relâchée, zoom et déplacement annulés, par le vol de 1,3 s. Le premier clic agit seul, comme un clic à côté : il ferme la fiche et la pièce isolée.

**Clics droits :**
- sur un nom d'étage : « Monter d'un étage », « Descendre d'un étage » ;
- sur le fond : « Replacer les pièces automatiquement ».

**Redimensionnement :** la vue d'ensemble se recadre, sauf si Djoko a zoomé ou isolé une pièce.

**« Réduire les animations »** (accessibilité de macOS) :
- l'envol devient un fondu de 0,3 s par le fond : la scène s'efface, bascule à mi-chemin, puis revient ;
- le retour par double-clic aussi ;
- les autres vols de caméra sont immédiats ;
- la rotation lente est coupée.

**Pas de travail lourd sur le fil principal pendant un mouvement.** Un relevé qui arrive pendant l'envol, un vol, le fondu ou le glisser d'une pièce s'applique à la fin du mouvement.

## 8. Cas limites

- **Pas encore de pièces de Maison :** groupement par routeur parent (section 2.3).
- **Passeur en échec :** section 3.1.
- **Grande maison**, 20 pièces et 100 appareils par exemple : la disposition est calculée hors du fil principal (section 4.3), et le zoom sémantique garde la vue lisible.
- **Sans sonde :** pas de liens radio mesurés. Les rattachements supposés sont en pointillés, et aucune pièce ne manque.
- **Plusieurs partitions :** couleur des nœuds (principale en bleu, les autres en ambre, sans partition en gris), et bandeau de scission.
- **Fenêtre petite :** le zoom sémantique et le compteur de noms masqués.

## 9. Architecture et fichiers

**Cœur, `MaillageCoeur/Scene/`, Swift pur, sans SwiftUI :**
- `ScenePieces` : le modèle (étages, pièces, nœuds, liens), construit depuis le maillage, les annonces et `NomsMaison`, zones comprises. C'est là qu'on applique les règles de la section 2.
- `CartesPieces` : la taille des cartes et la place des nœuds (section 4.2), à partir des largeurs de noms mesurées par l'app.
- `DispositionPieces` : la séparation, le tassement, le coût, l'optimisation, le rayon des plateaux et les pièces fixées (section 4.3).
- `CameraScene` : l'orbite, la projection, l'envol, les vols, le zoom vers le curseur, les bornes, le cadrage (sections 4.4 et 7).
- `PlacementNoms` : le placement glouton, les priorités, la stabilité, les traits de rappel et le zoom sémantique (section 6).
- `PlacesGardees` : lecture et écriture de `positions-pieces.json` (section 2.4).
- `SceneProjetee` : ce que la caméra rend à un moteur, en coordonnées de l'écran. On y trouve :
  - les polygones des plateaux et des faces de blocs, avec leur couleur et leur opacité ;
  - les segments des liens, les disques des pastilles avec leur état ;
  - l'ellipse de la sphère ;
  - les noms placés.

  C'est le **contrat entre la scène et le moteur**. Un moteur RealityKit prendrait plutôt `ScenePieces` et la caméra ; `SceneProjetee` est celui du moteur `Canvas`.

**App, `MaillageThread/Vues/Pieces/` :**
- `FenetrePieces` : barre, horloge, gestes, fil, ligne de niveau, fiche, clics droits. Elle remplace `FenetreGraphe`, et garde ses morceaux communs : barre d'outils, bandeau, ligne de tournée, fiche, « Renommer… ».
- `RenduCanvas` : le dessin de `SceneProjetee` (section 5).
- `DessinNoeud` : le dessin d'un nœud, sorti de `GrapheCanvas`.
- La mesure des noms reprend `MesureLibelles`.

**Passeur et noms :** `DossierNoms` devient `NomsInternes` : l'écoute, le jeton, le lancement, la lecture, l'écriture atomique et le dernier relevé valide (section 3.1). `Passeur/PasseurApp.swift` exporte les zones et envoie le JSON par TCP.

**Ce qui disparaît :** `Disposition`, `GrapheCanvas`, `PlacementLibelles`, `Projection` et leurs tests. Les tests qui restent vrais sont repris dans le nouveau cœur : le placement des noms et l'ordre des couches.

## 10. Tests

**Cœur, en Swift Testing :**
- **`ScenePieces` :** une pièce dans plusieurs zones, des pièces hors zone, une maison sans zones, un fichier d'avant les zones. Seulement les pièces avec un nœud. La carte « Sans pièce ». Le groupement par routeur parent sans pièces.
- **`CartesPieces` :** la taille à partir de largeurs données, le choix du nombre de colonnes, la place des nœuds, un nom coupé à 40 caractères.
- **`DispositionPieces` :**
  - aucun recouvrement, avec les écarts `GAP` et `LAB` ;
  - déterminisme ;
  - sur la maison de démo, **aucun lien ne traverse une pièce autre que celles de ses bouts** ;
  - une pièce fixée ne bouge pas, et une nouvelle se place sans recouvrement, même quand toutes les autres sont fixées (maisons de 8 et de 20 pièces, et des fixées à 10, 30, 50 et 80 %) ;
  - le coût de la disposition retenue est au plus celui du départ.
- **`CameraScene` :**
  - projection de points connus ;
  - début et fin de l'envol : cadrage 2D, puis sphère cadrée ;
  - le zoom vers le curseur garde le point sous le curseur à moins de 10⁻⁶ unité ;
  - bornes du zoom, vol vers une pièce.
- **`PlacementNoms` :**
  - aucun chevauchement entre noms posés ;
  - noms dans le cadre, priorités respectées ;
  - stabilité (un nom ne change pas de place avant 0,5 s) ;
  - seuils du zoom sémantique.
- **`PlacesGardees` :** aller-retour sur disque, une pièce renommée, l'ordre des étages.
- **Pièce des routeurs** (section 2.3) : mots entiers, casse et accents ignorés, le nom de pièce le plus long, l'égalité, le choix avant le nom, un choix dont la pièce a disparu, aller-retour sur disque.
- **Pièce des autres nœuds** (section 2.3, précision 27) :
  - la clé ExtMac : un choix place l'appareil que la sonde seule connaît, et le routeur Thread qui n'est pas de bordure, mais pas un routeur de bordure ; le même appareil garde son choix sous un autre RLOC16, ou quand son annonce revient ;
  - la priorité de Maison : sa pièce passe avant le choix, qui reste dans le fichier ;
  - pas de choix ni de menu sans ExtMac ; « Sans pièce » efface le choix ;
  - le fichier : un ancien fichier (les routeurs seuls) relu sans perte, puis réécrit sans perdre les routeurs ; un champ `appareils` mal formé, qui ne fait pas perdre les choix des routeurs.
- **Temps de calcul**, sur une grande maison inventée (20 pièces, 100 appareils) :
  - la disposition tient **sous 1 s**, en Release ;
  - le placement de 150 noms tient sous 2 ms, en Release, dans une fenêtre ordinaire : c'est le cas que mesure son premier test ;
  - au pire cas mesuré, 150 noms très serrés, il tient sous 4 ms : un second test le mesure ;
  - c'est sans effet visible, puisqu'une image dispose de 16,7 ms. Décidé avec Djoko le 01/10.

**App :**
- **`NomsInternes`**, face à un faux passeur (un client TCP de test sur 127.0.0.1) :
  - un bon jeton : le relevé est retenu et écrit ;
  - un mauvais jeton, une longueur fausse, un JSON illisible, ou un délai dépassé : le dernier relevé valide est gardé ;
  - une seule écoute à la fois.
- **Menu « Placer dans une pièce… »** (précision 27) : proposé pour un nœud sans pièce de Maison dont l'ExtMac est connue, pas pour un nœud sans ExtMac ni pour un appareil que Maison place ; « Sans pièce » d'abord pour un appareil, « D'après son nom » pour un routeur de bordure ; un choix dont la pièce a disparu ne coche que ce premier article ; un nœud placé passe dans sa pièce dans la scène.
- **Rendu de démo :** PNG en 2D, pendant l'envol, en 3D, en pièce isolée, et au survol, produits par un argument de lancement comme les captures actuelles. Ce sont des images de relecture, sans comparaison au pixel.
- **Catalogue :** nouveaux textes en français et en anglais, avec `CataloguesTests`.

**Avec Djoko, à la fin :**
- sa maison, ses zones, ses pièces ;
- 2D et 3D, pièce isolée ;
- glisser une pièce, puis relancer l'app pour retrouver sa place ;
- l'ordre des étages ;
- un relevé du passeur sans dossier ;
- « Réduire les animations ».

**Vérifié le 01/10 avec Djoko** (plan 4b) : sa maison en 4 étages (ses
zones) et 13 pièces, dont 10 montrées, celles qui ont un appareil Thread,
plus la carte « Sans pièce » ; aucun nom ne se chevauche, et la ligne
de niveau suit le zoom et la taille de la fenêtre (« Vue d'ensemble : les
pièces » à la vue d'ensemble). Ses
routeurs de bordure dont le nom contient une pièce y sont placés, à la bonne
pièce ; les trois autres sont placés par un choix, gardé après un redémarrage, et « D'après son nom » les rend à la
règle du nom. Il reste dans « Sans pièce » un appareil joignable mais non
identifié. 2D et 3D, envol et rotation lente ; pièce isolée, retour par un
clic à côté, Échap et « Maison » ; double-clic sur le fond ; une pièce
glissée et l'ordre des étages retrouvés après un redémarrage ; fiche et
courbes ; fenêtre sombre avec le Mac en clair, tout lisible ; relevé du
passeur ; « Réduire les animations ». Demandes notées pour la suite : une
zone au même niveau qu'un étage, la 2D en grille selon la
forme de la fenêtre, ⌃ + glisser pour la verticale, isoler un étage,
l'animation d'un appareil qui change de pièce, l'apparition animée du
bandeau, 2D/3D et « Rotation lente » sur une deuxième ligne.

## 11. Découpage en plans

- **Plan 4a, passeur sans dossier et zones** (section 3) : il ne dépend pas de la vue. Il peut passer avant ou pendant le 4b.
- **Plan 4b, vue par pièces** (sections 1, 2 et 4 à 10) : il suppose les zones du 4a, mais il reste utilisable sans elles (maison sans zones).

**Hors périmètre :**
- le moteur RealityKit, l'iPad et le Vision Pro ;
- les murs et les plans réels des pièces ;
- la légende A (au polissage) ;
- la description VoiceOver de la scène, que le graphe actuel n'a pas non plus.

**Références locales, non publiées :** `.superpowers/archives/vue-pieces/` contient :
- les maquettes v12 et v13 d'origine ;
- les prototypes A et C, avec leurs rapports ;
- la scène de démo en JSON.

Le code de A (projection, ellipse exacte de la sphère, placement des noms porté en Swift, éclairage des faces) sert de départ au plan 4b.
