# Maillage Thread, polissage C : les étages

Spec du 03/10/2026. Djoko a conçu C sur les maquettes v1 à v5 des 02 et 03/10, puis l'a validé le 03/10 : la maquette v5 et la conception en huit points.

## 0. Contexte et décisions

Le polissage se fait en quatre sous-projets, dans l'ordre choisi par Djoko :
- A, mineurs et robustesse (fusionné le 01/10) ;
- B, la fenêtre et la légende (fusionné le 02/10) ;
- **C, les étages (cette spec)** ;
- D, les gestes et les animations.

**Demandes de Djoko** (vérification du 4b le 01/10, puis le 02/10) :
- une zone au même niveau qu'un étage, comme un extérieur à côté du rez-de-chaussée ;
- la 2D en grille selon la forme de la fenêtre, **comme mode par défaut**. La rangée d'aujourd'hui reste au choix dans les Réglages ;
- isoler une zone comme on isole une pièce.

Le 03/10, Djoko a aussi demandé **⌥ + glisser** en 3D, prévu pour D : il passe dans C (section 6).

**Maquette de référence :** `maquettes/polissage-c-etages.html`, la v5. Elle reprend le moteur three.js de la maquette v13 de la vue par pièces, et ses noms sont inventés. **Elle se livre telle quelle**, pour tout ce qu'elle montre de la vue. Deux de ses outils ne passent pas dans l'app :
- le groupe « Fenêtre » (Navigateur, Carrée, Ordinaire, Large), qui simule le cadre de l'app ;
- son texte d'aide ;
- sa ligne d'état « Grille : 2 × 2 » ou « Rangée », sous sa barre, ajoutée pour expliquer la grille dans un onglet large.

Ses paramètres d'URL de relecture (`vue=3d`, `rot=0`, `rangee=1`, `etage=N`, `jardin=a|b`, `fenetre=…`) ne servent qu'à la relire.

**Décisions de Djoko pendant la conception :**

| Sujet | Décision |
|---|---|
| Revenir d'un isolement | Échap et le clic à côté **remontent d'où l'on vient** : d'une pièce à l'étage si on l'a ouverte depuis l'étage, sinon à la maison ; d'un étage à la maison (v1 puis v3). |
| Mettre une zone au niveau d'un étage | **par le clic droit** sur son nom, ou sur son disque (v2) |
| Dans ou hors de la maison | **les deux**, au choix de chaque zone (v2) |
| Isoler un étage | clic sur son nom **ou sur son disque** (v2) |
| Vitesse de ⌥ + glisser | **0,7 fois** celle du pointeur (v4) |
| Passage grille ↔ rangée | **2,6 s, comme l'envol 2D/3D**, qui sert de référence (v5) |
| Glissade au redimensionnement | 0,4 s, sur ma recommandation : 2,6 s traînerait derrière la souris |
| Disposition des pièces | indépendante de la fenêtre et du mode 2D (section 4) |
| Choix de la grille (03/10, au plan) | **sur la zone visible** de la vue, et non sur la forme de la fenêtre : la vue est toujours la plus grande possible (section 3.3) |
| « ⌂ Maison » en 3D (03/10, au plan) | il **évite les noms d'étage**, qu'il chevauchait dans la maquette (section 2) |
| Légende (03/10, au plan) | elle garde la taille de B |

## 1. Les niveaux

### 1.1 Le modèle

Chaque plateau est l'une des deux choses suivantes :
- un **étage**, sur son propre niveau ;
- une **zone à côté** d'un étage. Elle partage le niveau de cet étage, appelé l'étage principal, et elle est soit **dans la maison**, soit **hors de la maison**.

**Les niveaux :**
- ils vont du bas vers le haut, dans l'ordre des étages (spec de la vue par pièces, section 2.1) ;
- dans un niveau, l'étage principal vient d'abord, puis ses zones à côté, dans l'ordre des étages gardé.

**Tous les plateaux peuvent se mettre à côté** : les zones de Maison comme « Autres pièces ». Une maison d'un seul plateau n'a ni niveau à régler, ni étage à isoler.

### 1.2 Le choix gardé

- **Fichier :** `positions-pieces.json`. `PlacesGardees.Maison` gagne un champ facultatif `aCote`. C'est un dictionnaire : à la clé d'un plateau, il associe `{ etage, dehors }`, où `etage` est la clé de l'étage principal et `dehors` vaut vrai si la zone est hors de la maison.
- **La version reste 1**, comme pour `appareils` (polissage A) :
  - une app plus ancienne relit encore l'ordre et les places, et ignore le champ ;
  - un fichier sans ce champ donne des étages seulement, comme aujourd'hui.
- **L'ordre des étages gardé** (`ordreEtages`) reste la liste de tous les plateaux, du bas vers le haut, zones à côté comprises. Quand une zone se met à côté d'un étage, elle passe juste après le groupe de cet étage : les zones déjà à côté gardent leur place, et la nouvelle vient en dernier. Écart voulu à la maquette, qui la mettait juste après l'étage principal ; il ne se voit que dans un niveau qui a déjà une zone à côté.
- **Résolution des cas tordus :**
  - **étage principal absent de la scène** (plus de pièce montrée, renommé, retiré de Maison) : la zone redevient un étage, à sa place dans l'ordre. Son choix reste dans le fichier ;
  - **chaîne** (A à côté de B, B à côté de C) : A et B sont à côté de C ;
  - **boucle** : les plateaux de la boucle redeviennent des étages ;
  - **une zone à côté d'elle-même** : ignorée.
- **« Replacer les pièces automatiquement »** garde l'ordre des étages et les choix de niveau. Il n'oublie que les places des pièces.
- **En démo et sous les tests**, rien n'est écrit, comme aujourd'hui.

### 1.3 Le menu du clic droit

Il s'ouvre sur le **nom ou le disque** d'un plateau. Le disque est nouveau : jusqu'ici, seul le nom ouvrait le menu. En tête vient le nom de la zone, grisé. Puis :

- **« Monter d'un étage »** et **« Descendre d'un étage »** :
  - pour un étage, ils échangent son **niveau entier**, zones à côté comprises, avec le niveau voisin ;
  - ils sont grisés en haut et en bas de la pile, et toujours grisés pour une zone à côté.
- **« Au même niveau que ▸ »** :
  - un sous-menu des autres niveaux, chacun nommé par son étage principal ;
  - coché, celui où la zone est déjà à côté ;
  - la zone y passe à côté, **dans la maison**. Ses propres zones à côté la suivent.
- **« Hors de la maison »** : une case à cocher, pour une zone à côté seulement. Cochée, la zone sort de la sphère ; décochée, elle revient dedans.
- **« Sur son propre niveau »**, pour une zone à côté seulement : elle redevient un étage, juste au-dessus du niveau qu'elle partageait.

Le menu du fond ne change pas : « Replacer les pièces automatiquement ».

**Après un choix :**
- le choix est gardé ;
- la disposition des pièces se recalcule hors du fil principal (section 4), et l'ancienne reste affichée pendant ce temps ;
- **en 3D**, les plateaux, la sphère et le cadrage glissent vers leur nouvelle place en **0,9 s** (cubique entrée-sortie) ;
- **en 2D**, les plateaux glissent vers leur nouvelle case en 0,4 s.

Avec « Réduire les animations », le changement est immédiat.

## 2. La 3D

Elle remplace la partie 3D de la section 4.4 de la spec de la vue par pièces. Avec des étages seulement, elle donne la même vue qu'aujourd'hui.

**Notations :** `r(e)` est le rayon du plateau `e`, `ESP` l'écart entre plateaux (140 px, spec de la vue par pièces, section 4.3) et `H3 = 2,4` la hauteur des blocs en 3D.

**La pile :**
- `RMAX` est le plus grand rayon des plateaux **dans la maison** : étages et zones à côté dans la maison. Les zones hors de la maison n'y comptent pas.
- `ETAGE = 1,5 × RMAX` est le pas entre deux niveaux.
- Un plateau du niveau `n` (0 en bas) est à la hauteur `y = n × ETAGE`.
- `hh = ((nombre de niveaux − 1) × ETAGE + H3) / 2`.
- Les étages sont centrés sur l'axe x = z = 0.

**Zones à côté, dans la maison :**
- dans un niveau, la première se place à droite (+x) de l'étage principal, la deuxième à gauche (−x), puis on alterne, de plus en plus loin ;
- `ESP` sépare les bords ;
- toutes sont à la hauteur de leur niveau, avec z = 0.

**La sphère de la maison :**
- elle englobe les plateaux dans la maison ;
- soit `x0` et `x1` les bords extrêmes de ces plateaux sur x ;
- son centre est `((x0 + x1)/2, hh, 0)` ;
- son rayon est `R = hypot((x1 − x0)/2 + 0,8, hh + 1,4) + 0,4`. Avec des étages seulement, c'est la formule d'aujourd'hui.

**Zones hors de la maison :**
- elles se placent à la hauteur de leur niveau, autour de l'axe vertical du centre de la sphère ;
- leurs directions se suivent dans l'ordre +x, −x, +z, −z, puis recommencent ;
- dans une direction, la première zone est à la distance `R + ESP + r` de l'axe, mesurée à plat ; la suivante dans la même direction se place plus loin, avec `ESP` entre les bords.

**Le cadrage :**
- `R_cadre` est le plus grand de `R` et des distances à l'axe des bords extérieurs des zones hors de la maison ;
- la hauteur de la vue d'ensemble 3D est `2,4 × R_cadre × max(1, 1/aspect)`, centrée sur la sphère ;
- les bornes du zoom 3D se règlent sur cette vue ;
- la rotation lente tourne autour de l'axe vertical du centre de la sphère : les zones hors de la maison tournent autour d'elle ;
- « ⌂ Maison » reste sous le haut de la sphère. **Ce qui change** (décision de Djoko, 03/10, au plan) : il se pose après les noms d'étage et les évite, avec ses places candidates habituelles. Dans la maquette, comme au plan 4b, il se posait avant eux et pouvait chevaucher le nom de l'étage du haut quand une zone est hors de la maison. Il se pose aussi après le nom d'un appareil survolé ou choisi, et l'évite de même.

## 3. La 2D

Elle remplace la partie 2D de la section 4.4 de la spec de la vue par pièces.

### 3.1 Le réglage

Réglages › Général gagne une section **« Vue par pièces »**, avec un menu **« Étages en 2D »** et deux choix :
- **« En grille »**, par défaut ;
- **« En rangée »**.

Le choix est gardé d'un lancement à l'autre et s'applique tout de suite à la vue ouverte (section 3.5).

### 3.2 L'ordre des plateaux

C'est l'ordre des niveaux, du bas vers le haut. Dans un niveau : l'étage principal, puis ses zones à côté, dans la maison ou non.

### 3.3 La grille

**Remplissage :**
- elle se remplit **depuis la rangée du bas**, de gauche à droite : les étages hauts sont en haut, comme en 3D ;
- la rangée du haut, si elle est incomplète, est centrée.

**Taille des cases :**
- largeur d'une colonne : le plus grand diamètre de la colonne ;
- hauteur d'une rangée : le plus grand diamètre de la rangée, plus la bande des noms d'étage (34 px) ;
- `ESP` entre les cases ;
- chaque plateau est centré dans sa case, bande comprise.

**Choix du nombre de colonnes `c`, de 1 à n :**
- l'échelle d'une grille est `min(largeur / largeur de la grille, hauteur / hauteur de la grille)`, prise sur le cadre de la vue, c'est-à-dire la fenêtre moins les marges mesurées du haut et du bas (polissage B) ;
- parmi les grilles **à moins de 10 % de la plus grande échelle**, on prend celle qui a **le moins de cases vides**, puis le moins de rangées ;
- **hystérésis au redimensionnement** : la grille en place reste tant que son échelle est à moins de 5 % de celle du choix ;
- **une taille de 1 pt ou moins ne choisit rien** : on garde la disposition en place, ou on attend une vraie taille. Ce cas arrive pour une vue cachée ou en cours de mise en page. Dans la maquette v2, il bloquait la grille sur la rangée ;
- à la première vraie taille, la grille se calcule et la vue d'ensemble se cadre, sans autre condition ;
- **ouvrir ou replier la légende** change le cadre : la grille se recalcule comme au redimensionnement ;
- **ouvrir une fiche ne change pas la grille** : la zone visible ne compte ni la fiche, ni le repli automatique de la légende sous elle. Sinon, les plateaux glisseraient à chaque clic sur un appareil (précision du plan, 03/10).

**La zone visible, et non la forme de la fenêtre** (décision de Djoko, 03/10, au plan). Dans l'app, le haut de la fenêtre (capsules, fil, ligne de niveau) et la légende ouverte réduisent la hauteur du cadre, ce que la maquette ne montrait pas. Choisie sur la forme de la fenêtre, la grille 2 × 2 de la démo était près de deux fois plus petite que la rangée, à 1440 × 900, la légende ouverte. Sur la zone visible, la vue est toujours la plus grande possible. La grille se voit donc dans une fenêtre carrée ou haute, ou la légende repliée. Dans une fenêtre large, la légende ouverte, c'est souvent la rangée.

**Exemple de la maison de démo de la maquette**, 4 plateaux, sur le cadre de la maquette, sans légende :
- 2 × 2 dans une fenêtre carrée ou ordinaire (1100 × 760) ;
- la rangée dans une fenêtre large (2,4 : 1).

### 3.4 La rangée

C'est la grille d'une seule rangée : les plateaux côte à côte sur x, `ESP` entre les bords, dans l'ordre de la section 3.2. Avec des étages seulement, c'est la rangée d'aujourd'hui.

### 3.5 Quand la disposition change

- **Changement du réglage** : les plateaux glissent vers leur nouvelle case en **2,6 s**, en cubique entrée-sortie, comme l'envol 2D/3D. La vue d'ensemble se recadre en même temps.
- **Redimensionnement**, à la vue d'ensemble : la grille se recalcule, les plateaux glissent en **0,4 s**, et la vue se recadre à chaque image.
- **Zoomé ou isolé** : la grille attend le retour à la vue d'ensemble.
- **« Réduire les animations »** : le changement est immédiat.
- **L'envol 2D ↔ 3D** part de la place 2D de chaque plateau, en grille comme en rangée.
- **La boîte de cadrage 2D** est celle de la grille ou de la rangée, avec la bande des noms d'étage.

## 4. La disposition des pièces

La disposition des pièces dans leurs plateaux (spec de la vue par pièces, section 4.3) **ne dépend plus ni de la fenêtre, ni du mode 2D**. Elle reste calculée hors du fil principal, de façon déterministe, avec le même budget. Seul son coût change.

**Pourquoi :**
- une disposition qui dépendrait de la grille serait à recalculer à chaque changement de grille : jusqu'à 1 s de calcul, et des pièces qui sautent ;
- aujourd'hui, le coût voit les étages en rangée, une vue qui n'est plus celle par défaut.

**Vue de référence du coût :** la maison vue de dessus, niveau par niveau. Chaque niveau est une rangée : son étage principal, puis ses zones à côté, `ESP` entre les bords, centrée sur l'étage principal. Les niveaux sont superposés.

**Le coût est la somme de :**
- les rayons des plateaux ;
- pour chaque lien dont les deux bouts sont **au même niveau** :
  - 0,3 × sa longueur ;
  - 6 + 4 × la longueur traversée, pour chaque carte de ce niveau autre que ses bouts qu'il traverse (bande du nom comprise) ;
  - 5 par croisement avec un autre lien du même niveau, sans bout commun ;
- pour chaque lien **entre deux niveaux** : 0,1 × son écart horizontal dans la vue de référence.

Pour une maison d'un seul plateau, c'est le coût d'aujourd'hui.

**Conséquence, à dire à Djoko :** les pièces qu'il n'a pas déplacées peuvent changer de place une fois, à la première ouverture après C. Celles qu'il a déplacées, qui sont fixées, ne bougent pas.

**Recalcul :** la disposition se recalcule quand les étages, les pièces, les nœuds ou leurs noms changent, comme aujourd'hui, et aussi quand le regroupement des niveaux change, c'est-à-dire quelles zones partagent un niveau. L'ordre des niveaux et « Hors de la maison » ne changent pas le coût, donc pas la disposition.

## 5. L'isolement

### 5.1 Isoler un étage

- **Pour isoler un étage :** un clic sur **son nom ou son disque**.
- **Priorité des clics**, du plus fort au plus faible : appareil, pièce (bloc ou nom), nom d'étage, disque, fond. En 3D, c'est le disque le plus proche sur le rayon qui compte.
- **Le vol**, de 1,3 s, cadre le plateau, bande de son nom comprise :
  - **en 2D**, vue de dessus, dans le cadre de la vue (marges mesurées du polissage B) ;
  - **en 3D**, même azimut et même inclinaison. La cible est le centre du plateau, à sa hauteur, et la hauteur de vue vaut `max((2 r + bande) × 1,1 ; 2 r × 1,05 / aspect)`.
- **Ce qui s'estompe** : les autres plateaux, avec leurs nappes, leurs pièces, leurs pastilles et leurs liens, descendent à **15 %**. Leurs noms restent visibles en pâle (0,45) et cliquables.
- **Ce qui s'efface** : la sphère et « ⌂ Maison ».
- **Ce qui s'arrête** : la rotation lente, comme pour une pièce isolée.
- **Liens** : un lien qui touche l'étage isolé reste visible, même s'il va vers un autre étage.
- **Noms** : seuls ceux des appareils de l'étage isolé s'affichent, selon le zoom sémantique.
- **Glisser une pièce** : c'est permis pour les pièces de l'étage isolé. Les pièces des autres étages se cliquent, mais ne se glissent pas.
- **Ligne de niveau** : « Étage isolé : *nom* · clic sur une pièce ou un autre étage pour y aller, clic à côté ou Échap pour revenir ».

### 5.2 Isoler une pièce

C'est la pièce isolée d'aujourd'hui, avec quatre ajouts :
- **les disques des autres étages** restent visibles à 15 % : on peut cliquer dessus ;
- **le fil est complet** (section 5.3) ;
- **la provenance est retenue** (section 5.4) ;
- **les repères « ailleurs »** : ↗ pour un parent au même niveau ; avec le nom de sa zone si elle est différente. ↓ ou ↑ pour un parent à un autre niveau, avec le nom de son étage.

### 5.3 Le fil

- **« Maison › Étage › Pièce »** : chaque élément est cliquable et mène à son niveau.
- **Une pièce isolée depuis la vue d'ensemble** a aussi son fil complet.
- **Maison d'un seul plateau** : « Maison › Pièce ».

### 5.4 Remonter

- **Depuis une pièce isolée**, Échap et le clic à côté ramènent **d'où l'on vient** :
  - pièce ouverte depuis la vue d'ensemble : retour à la maison, d'un seul vol ;
  - pièce ouverte depuis un étage isolé : retour à l'étage de la pièce, celui du fil. C'est le même si la pièce est sur l'étage isolé ; sinon c'est son propre étage, comme dans la maquette ;
  - passer d'une pièce à une autre garde la provenance, sauf vers une pièce d'un autre étage depuis un étage isolé : la provenance devient alors la maison.
- **Depuis un étage isolé**, Échap et le clic à côté ramènent à la maison.
- **Le clic à côté** est un clic sur le fond, hors de tout disque, pièce, nom et appareil.
- **Clic sur un disque**, selon l'état de la vue :
  - en pièce isolée, le disque de son étage isole cet étage : c'est un geste explicite, pas une remontée ;
  - en étage isolé, son propre disque, entre les pièces, ne fait rien ;
  - le disque d'un autre étage y mène.
- **Le double-clic**, sur le fond ou sur un disque, ramène à la vue d'ensemble de partout, par un vol qui part de la pose courante.
- **« Réduire les animations »** : les vols sont immédiats, comme aujourd'hui.

### 5.5 Deux défauts relevés au polissage A

Ces deux points (triage A, n° 8 et 9) se règlent en passant, puisque C réécrit l'isolement :
- **n° 8** : pendant le retour d'un isolement (1,3 s), les noms des appareils suivent l'état d'arrivée, et la ligne de niveau ne dit plus « Tous les noms sont lisibles » à tort ;
- **n° 9** : les fondus de l'isolement sont gardés par clé, de pièce comme d'étage, et non par indice. Un relevé reçu pendant un fondu, avec « Réduire les animations », ne remet plus la pièce à pleine taille.

## 6. ⌥ + glisser en 3D

- **En 3D**, ⌥ maintenue au moment de l'appui, un glisser **déplace la vue dans le plan de l'écran** au lieu de tourner. La cible et la caméra glissent ensemble, parallèlement à l'écran, sans tourner, à **0,7 fois** la vitesse du pointeur, mesurée à la cible.
- **Le geste part** du fond, d'un disque ou d'une pièce. ⌥ passe avant le glisser d'une pièce : avec ⌥, la pièce ne bouge pas.
- **Le mode est fixé à l'appui** : relâcher ⌥ en cours de route ne change rien.
- **Curseur** : une main ouverte tant que ⌥ est maintenue au-dessus de la vue en 3D, et une main fermée pendant le geste.
- **Rotation lente** : elle s'arrête pendant le geste et reprend après, comme pour les autres gestes.
- **Retour** : le double-clic ramène à la vue d'ensemble, déplacement compris.
- **Plus de saut** : l'envol 2D ↔ 3D, les vols et le double-clic partent de la pose exacte de la caméra (position, cible, champ, azimut de la rotation lente). Avant la maquette v4, l'envol après un ⌥ + glisser commençait par un saut.
- **En 2D**, le glisser déplace déjà la vue : ⌥ n'y change rien.

## 7. Démo et captures

**Maison de démo :**
- elle gagne deux zones, aux pièces inventées de la maquette :
  - « Combles » : « Grenier » et « Salle de jeux » ;
  - « Jardin » : « Terrasse » et « Abri » ;
- les pièces sont remplies avec des nœuds de la démo actuelle, sans nouvelle donnée radio, au plus près de la maquette : un routeur dans « Salle de jeux » et dans « Terrasse », des liens entre niveaux et au même niveau ;
- le Jardin est **au niveau du Rez-de-chaussée, hors de la maison**. C'est un choix en mémoire, puisque la démo n'écrit rien ;
- avec la règle de la zone visible (section 3.3), la grille montre 4 plateaux en 2 × 2 dans une fenêtre carrée de 1000 pt, la légende ouverte, ou de 900 pt, la légende repliée. Dans les fenêtres ordinaires (1100 × 760, 1440 × 900), légende ouverte ou repliée, c'est la rangée, plus grande.

**Captures de démo :** elles changent toutes. Il s'en ajoute au moins :
- la grille dans une fenêtre carrée ;
- la rangée ;
- la 3D avec le Jardin dans la maison ;
- un étage isolé en 2D et en 3D ;
- une pièce isolée depuis un étage, avec le fil complet.

Le plan fixe leurs noms et leur liste exacte.

**Catalogue :** tous les nouveaux textes, avec leur anglais :
- « Au même niveau que », « Hors de la maison », « Sur son propre niveau » ;
- « Vue par pièces », « Étages en 2D », « En grille », « En rangée » ;
- la ligne de niveau de l'étage isolé ;
- le fil.

## 8. Tests et vérification

**Cœur, en Swift Testing :**
- **les niveaux :**
  - un fichier sans `aCote` ;
  - une zone à côté, dans et hors de la maison ;
  - un étage principal absent, une chaîne, une boucle, une zone à côté d'elle-même ;
  - « Monter » et « Descendre » d'un niveau entier ;
  - « Sur son propre niveau » ;
  - l'aller-retour sur disque, en gardant l'ordre et les places, avec la version 1 ;
- **la géométrie 3D** :
  - avec des étages seulement, exactement celle d'aujourd'hui ;
  - zones dans la maison, alternées à droite puis à gauche ;
  - sphère qui les englobe ;
  - zones hors de la maison, hors de la sphère et dans le cadre sur un tour de rotation ;
- **la grille** :
  - les exemples de la section 3.3 ;
  - le remplissage par le bas, la rangée incomplète centrée ;
  - la règle des 10 % et des cases vides, l'hystérésis de 5 % ;
  - une taille nulle, puis la première vraie taille ;
  - la rangée égale à celle d'aujourd'hui avec des étages seulement ;
- **la disposition des pièces** :
  - même disposition pour toutes les tailles de fenêtre et les deux modes 2D ;
  - coût d'aujourd'hui pour un seul plateau ;
  - les tests actuels de la section 10 de la spec de la vue par pièces restent verts ;
- **la caméra** :
  - le cadrage d'un étage isolé, en 2D et en 3D ;
  - l'envol qui part de la pose exacte après un déplacement, à 10⁻⁶ près.

**App :**
- la provenance de l'isolement :
  - maison → pièce → Échap : maison ;
  - maison → étage → pièce → Échap : étage, puis maison ;
- la priorité des clics ;
- le menu du clic droit, article par article, sur le nom et sur le disque ;
- le réglage « Étages en 2D » ;
- les n° 8 et 9 du triage A ;
- les captures de démo ;
- le catalogue, avec `CataloguesTests`.

**Avec Djoko, à la fin, en vrai, sur sa maison :**
- grille et rangée, par le réglage et en redimensionnant la fenêtre ;
- son extérieur au niveau du rez-de-chaussée, dans puis hors de la maison, gardé après un redémarrage ;
- « Monter » et « Descendre » d'un niveau entier ;
- isoler un étage par son nom et par son disque, en 2D et en 3D ;
- remonter d'une pièce, selon sa provenance ;
- ⌥ + glisser, puis l'envol sans saut ;
- « Réduire les animations ».

## 9. Hors de C

Ces points restent à D :
- triage A, n° 6 : un étage réarrangé par un changement d'état ;
- triage A, n° 7 : la capture de la molette et d'Échap ;
- l'animation d'un appareil qui change de pièce.

## 10. Fichiers concernés

Liste indicative, le plan fait foi.

**Cœur :**
- `PlacesGardees` : `aCote` ;
- `ScenePieces` : les niveaux ;
- `CameraScene` et `GeometrieMaison` : la grille, les niveaux, les cadrages et la pose exacte ;
- `DispositionPieces` : le coût de référence.

**App :**
- `MoteurPieces` : l'isolement d'un étage, la provenance, ⌥ + glisser, les fondus par clé, la grille au redimensionnement ;
- `FenetrePieces` : le menu, le fil, la ligne de niveau ;
- `FenetreReglages` : le réglage ;
- `NomsDemo` et la démo ;
- `CapturesPieces` ;
- le catalogue.
