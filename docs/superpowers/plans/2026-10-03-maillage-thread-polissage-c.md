# Maillage Thread, polissage C : les étages : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** livrer le sous-projet C du polissage, les étages, tel que Djoko l'a validé le 03/10 sur la maquette v5 : une zone peut se mettre au niveau d'un étage, dans ou hors de la maison, par le clic droit sur son nom ou son disque ; la 2D montre les plateaux en grille, choisie sur la zone visible de la vue, par défaut, ou en rangée, au choix dans les Réglages ; la disposition des pièces ne dépend plus de la fenêtre ; un étage s'isole par son nom ou son disque, et Échap remonte d'où l'on vient ; ⌥ + glisser déplace la vue 3D dans le plan de l'écran.

**Architecture :**
- **Le cœur** (`MaillageCoeur/Scene/`) :
  - `Niveaux.swift` (nouveau) : `Niveaux` résout les choix gardés sur les plateaux de la scène (étage principal absent, chaîne, boucle, zone à côté d'elle-même) et range les niveaux ; `Rangement` et les opérations du menu (`deplacer`, `rejoindre`, `basculerDehors`, `propreNiveau`), des fonctions pures qui rendent le nouvel ordre et les nouveaux choix ;
  - `PlacesGardees` : `Maison.aCote`, facultatif, en version 1 ; `rangement(_:)` et `ranger(_:domicile:)` ;
  - `ScenePieces` : les niveaux de la scène (`niveaux`, `Etage.niveau`, `principal`, `dehors`), ses plateaux dans l'ordre des niveaux ;
  - `GeometrieMaison` (`CameraScene.swift`) : les plateaux par niveaux (`Plateau`), la grille 2D et son choix (`colonnes(rayons:taille:enPlace:)`), la 3D (les zones à côté dans ou hors de la maison, la sphère, `rayonCadre`), la boîte 2D, et le chemin d'une géométrie à une autre (`vers(_:k2:k3:)`) ; les cadrages d'un étage isolé (`vueEtage`, `volVersEtage`) ; ⌥ + glisser (`deplacerDansLEcran`) ;
  - `DispositionPieces` : le coût sur la vue de référence des niveaux (`vueReference`) ;
  - `SceneProjetee` et `PlacementNoms` : les voiles des plateaux (un étage isolé), les repères « ailleurs » par niveaux, les noms qui suivent l'état d'arrivée, « ⌂ Maison » posé après les noms d'étage.
- **L'app** (`MaillageThread/`) :
  - `MoteurPieces` : la géométrie visée et ses glissements (0,4 s, 2,6 s, 0,9 s), la grille sur la zone visible de la vue (`zoneVisible`, sans la fiche) et selon le réglage, qui attend la vue d'ensemble 2D ; l'isolement explicite (`Isolement` : la maison, un étage, une pièce avec sa provenance), le fil (`Fil`), la priorité des clics (`CibleClic`), le menu des niveaux (`MenuEtage`), les fondus gardés par clé ; ⌥ + glisser et les curseurs (`Curseur`) ;
  - `FenetrePieces` : le réglage (`@AppStorage("etagesEnGrille")`), la marge du bas de la zone visible (`margeBasGrille`), le menu natif du clic droit (`MenuPieces`), le fil à crans, la ligne de niveau d'un étage isolé, les curseurs ; `FenetreReglages` : la section « Vue par pièces » ;
  - `EntreeScene` : les choix de niveau, dans la scène et dans la clé de la disposition ;
  - la démo (`NomsDemo`) : les combles et le jardin ; vingt images (`CapturesPieces`).

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI (`contextMenu`, `Toggle`, `pointerStyle`, `AppStorage`), AppKit (`NSEvent`), Swift Testing, XcodeGen, `xcodebuild`, `xcstringstool`.

**Spec :** `docs/superpowers/specs/2026-10-03-maillage-thread-polissage-c-design.md` (validée par Djoko le 03/10), et sa maquette de référence, qui se livre telle quelle : `docs/superpowers/specs/maquettes/polissage-c-etages.html` (v5). Elle remplace la section 4.4 de la spec de la vue par pièces (`2026-09-30-maillage-thread-vue-pieces-design.md`), et en étend les sections 4.3 et 7.

**Décisions de Djoko du 03/10, sur la première version de ce plan** (la spec de C les note, au commit `f25b20c`) :
- **la grille se choisit sur la zone visible** de la vue, la fenêtre moins ses marges mesurées du haut et du bas, la légende ouverte ou repliée, et non sur la forme de la fenêtre : la vue d'ensemble est toujours la plus grande possible. Ouvrir ou replier la légende recalcule la grille comme un redimensionnement (précision 7). Dans la démo, la grille 2 × 2 se voit dans une fenêtre carrée (images `15-2d-carree-2x2` et `16-2d-carree-en-rangee`) ; dans la fenêtre des images (1440 × 900), c'est la rangée ;
- **« ⌂ Maison » évite les noms d'étage** : il se pose après eux (précision 25, image `05-3d`) ;
- **la légende garde la taille de B** (précision 23).

**Quand l'exécuter.** Après le polissage B : ce plan est écrit et validé sur le `main` du 03/10 (`f25b20c`). **Les numéros de ligne cités sont indicatifs : l'exécutant se repère aux noms (types, fonctions, commentaires) et aux textes cités.** Si un texte à remplacer n'est plus exactement le même, il applique le même changement au texte du moment et le dit dans son rapport.

## Code validé, faits établis et précisions

**Code validé avant exécution.** Le 03/10, tout le code de ce plan a été écrit, compilé et testé dans une copie de `main` (`f25b20c`) :
- toute la suite passe, en français et en anglais : 369 tests en 37 suites pour le cœur et 338 en 30 pour l'app (avant ce plan : 346 en 36 et 316 en 29), sans avertissement ;
- les temps de la vue par pièces, en Release : la disposition de la grande maison inventée en 0,20 s (3 000 coups), 150 noms en 0,31 ms, 150 noms très serrés en 2,77 ms ; les tests Python de la sonde passent : ce plan n'y touche pas ;
- les images de démo ont été rendues et regardées, à côté des rendus de la maquette : les tâches 1 et 2 n'en changent aucune, octet pour octet (la démo n'a encore que deux étages) ; la tâche 3 les change toutes (le coût de la disposition) ; la tâche 4 aucune ; la tâche 5 en change trois ; la tâche 6 aucune ; la tâche 7 les change toutes (la démo gagne deux zones) et en ajoute six.

Le plan a ensuite été rejoué tâche par tâche sur une copie neuve de `main` (`f25b20c`), ses blocs appliqués par l'outil du contrôleur (`appliquer-blocs.py`, sur le brief de chaque tâche, découpé par `task-brief`), ses scripts de traduction lancés par le même outil (`--traductions`) : le rouge, le vert, le catalogue, la suite entière, les images, un commit par tâche. Les résultats attendus ci-dessous viennent de ce rejeu. L'arbre final est identique à la copie validée. D'autres changements de `main` changeraient ces totaux : chaque tâche donne donc ses effectifs par suite, et l'écart des totaux.

Exécuter une tâche, c'est transcrire les fichiers et les blocs donnés, compiler et tester. Si un fichier doit s'écarter du texte donné, l'exécutant le dit dans son rapport, avec la raison.

**Blocs de modification.** Un fichier existant est modifié soit en entier (« fichier entier »), soit par blocs « remplacer … par … ». Chaque texte à remplacer apparaît une seule fois dans le fichier au moment où on l'applique. Les blocs s'appliquent dans l'ordre, du haut vers le bas, au texte exact, espaces compris. Un fichier créé l'est tel quel. Le catalogue (`Localizable.xcstrings`) et `outils/traductions/interface.json` ne changent que par les outils (tâches 4 et 5). Ce plan ne déplace ni ne supprime aucun fichier ; il en crée trois : `Niveaux.swift`, `NiveauxTests.swift` et `IsolementTests.swift`.

**Faits établis** (Xcode 27, macOS 27, copie validée et rejeu, 03/10) :
- **Les préférences sous les tests.** L'app qui accueille les tests porte l'identifiant de l'app de Djoko : `UserDefaults.standard` y est le sien. `FenetrePieces` y lit, à sa création, le mode 2D ou 3D gardé : un test qui ouvre la vraie fenêtre ne suppose ni l'un ni l'autre (`reglageEtagesEn2D`), et aucun test n'écrit dans `UserDefaults.standard`.
- **`DragGesture`** ne donne ni l'événement ni ses touches. Avec une distance minimale nulle, son premier `onChanged` arrive à l'appui : `NSEvent.modifierFlags` y dit si ⌥ est tenue. Le moniteur local du moteur (celui de la molette et d'Échap) reçoit aussi `.flagsChanged` : ⌥ pressée ou relâchée sans bouger le pointeur.
- **Les curseurs de SwiftUI** : `.pointerStyle(.grabIdle)` et `.grabActive` posent `NSCursor.openHand` et `closedHand` ; `.link`, la main d'un lien ; `nil`, la flèche.
- **`ImageRenderer`**, qui rend les images de démo, ne rend ni un menu ni le curseur : le menu natif et les mains ne se voient qu'en vrai.
- **Les marges de la vue (polissage B), dans la démo :** 139 pt en haut ; en bas, 249 pt la légende ouverte (sa rangée de 223 pt, le bord et l'espacement), 30 pt repliée. Dans une fenêtre de 1100 × 760, la zone visible fait donc 1100 × 372 pt, la légende ouverte, et 1100 × 591 pt, repliée.
- **La grille de la démo de C sur la zone visible,** avec k, l'échelle de sa vue d'ensemble 2D (points par unité à la cible, divisés par 24) : à 1100 × 760, la rangée (0,362), la légende ouverte comme repliée ; à 1440 × 900, la rangée (0,473), de même ; dans une fenêtre carrée de 900 pt, la rangée (0,296) la légende ouverte, 2 × 2 (0,388) repliée ; de 1000 pt, 2 × 2 (0,324 ouverte, 0,441 repliée) ; à 1824 × 760, la rangée ; dans la plus petite fenêtre (820 × 732), la rangée (0,269) la légende ouverte, 2 × 2 (0,298) repliée. La démo de deux étages de B était à 0,53 à 1440 × 900 ; choisie sur la forme de la fenêtre, comme dans la première version de ce plan, la grille 2 × 2 y était à 0,27.
- **Un nœud de la scène** a pour rayon min(1,1 n, max(3, n k)), où n vaut 13 pour un routeur de bordure et 7 pour un appareil : à k = 0,47, un routeur fait 6,1 pt et un appareil 3,3 pt.
- **Les plateaux de la démo de C** ont pour rayons 17,59 (rez-de-chaussée), 9,63 (jardin), 13,80 (étage) et 10,60 (combles). Quand 2 × 2 et 3 + 1 sont limitées par la hauteur, 2 × 2 est à 91 % de 3 + 1, donc à moins de 10 % : elle l'emporte par ses cases vides (aucune), dès que la rangée tombe sous 90 % de la meilleure échelle ; sinon, la rangée l'emporte par ses rangées.
- **Le rendu « ordinaire » de la maquette** (`v5-2d-ordinaire.png`, rendu en mode « Navigateur ») montre 3 + 1. Le rapport de la maquette v4 donne 2 × 2 dans son cadre « Ordinaire » (999 × 690), comme la spec, et la fonction du cœur aussi, sur les rayons de la maquette, à 1100 × 760 (`choixDesColonnes`) ; à 1440 × 900, 3 + 1.
- **En 3D, le jardin hors de la maison** fait de `R_cadre` 1,7 fois le rayon de la sphère dans la démo (1,9 dans la maquette) : la sphère n'occupe plus que la moitié environ de la hauteur de la vue d'ensemble.
- **Deux rendus du même dessin par `ImageRenderer`** peuvent différer de quelques octets : le flou d'un halo ou d'une ombre varie selon ce que le processus a rendu avant. `signesCommeLaScene` (polissage B) compare ainsi chaque signe de la légende à son dessin dans la scène : 0 octet d'écart après la scène de la démo de deux étages, jusqu'à 14 (la pastille d'une pile) après celle de la démo de C, quand ce test tourne seul ou avec ceux de la tâche 7 ; son seuil était de 8.

**Précisions.** Ce sont les choix faits à l'écriture du plan, là où la spec, le brief et la maquette laissaient la main. Djoko peut les revoir à la tâche 8.
1. **Les niveaux, des fonctions pures du cœur.** `Niveaux(_:aCote:)` résout les choix gardés sur les plateaux de la scène (spec 1.2) et range les niveaux : l'étage principal, puis ses zones à côté, dans l'ordre gardé. Les opérations du menu (`Niveaux.deplacer`, `rejoindre`, `basculerDehors`, `propreNiveau`) rendent le nouvel ordre et les nouveaux choix (`Rangement`), ou nil quand l'article est grisé ou déjà coché. Les choix des plateaux absents de la scène restent tels quels : un étage principal absent rend la zone à son étage, et son choix reste dans le fichier. Une chaîne est remise à plat au premier choix fait au menu ; une boucle et une zone à côté d'elle-même y sont oubliées.
2. **Le fichier.** `aCote` est facultatif : écrit seulement s'il n'est pas vide, et relu sans exiger sa forme (`try?`) : un champ abîmé n'efface ni l'ordre, ni les places, ni `appareils`. La version reste 1 : une app plus ancienne ignore le champ. « Replacer les pièces automatiquement » garde l'ordre et les choix de niveau.
3. **Les niveaux de la scène.** `ScenePieces` range ses plateaux dans l'ordre des niveaux (`Niveaux.plateaux`). « Sans pièce » reste sur le plateau du bas, l'étage principal du niveau 0. Le repère « ailleurs » d'une pièce isolée compare les niveaux : au même niveau, ↗ et le nom de la zone du parent (« Salon, Rez-de-chaussée ») ; dessous, ↓ ; dessus, ↑.
4. **La clé de la disposition** (`EntreeScene.CleDisposition`) compte les niveaux, l'étage principal et le rang de chaque plateau : un choix de niveau relance le calcul de la disposition, dont le coût en dépend (spec 4). L'ordre des étages seul ne le relance pas, comme au plan 4b.
5. **La géométrie** (`GeometrieMaison(rayons:plateaux:colonnes:)`) reçoit les rayons, les niveaux (`Plateau` : le niveau, étage principal ou non, dehors ou non) et les colonnes de la grille (nil : la rangée). Elle rend les centres 2D et 3D, le pas des niveaux, la sphère, `rayonCadre` et la boîte 2D. Avec des étages seulement et en rangée, ce sont les valeurs d'avant, au bit près (`etagesSeulementCommeAvant`). La rangée du bas de la grille est en z = 0, les suivantes vers le haut de l'écran.
6. **Le choix des colonnes** (`GeometrieMaison.colonnes(rayons:taille:enPlace:)`) est une fonction pure de la taille : la règle des 10 %, puis le moins de cases vides et de rangées ; l'hystérésis de 5 % pour la grille en place ; une taille de 1 pt ou moins ne choisit rien (nil, ou la grille en place).
7. **La grille se choisit sur la zone visible de la vue** (décision de Djoko du 03/10 ; spec 3.3) : la vue moins la marge du haut et la marge du bas de la grille (`MoteurPieces.zoneVisible`). Cette marge du bas est celle de la légende telle que Djoko l'a laissée, ouverte ou repliée (`FenetrePieces.margeBasGrille`), **sans la fiche**, qui va et vient d'un clic, ni le repli de la légende faute de place sous elle : ouvrir une fiche ne change pas la grille. Une autre zone visible (la taille de la fenêtre, la légende ouverte ou repliée, un bandeau) recalcule la grille comme un redimensionnement : à la vue d'ensemble 2D, avec l'hystérésis, les plateaux glissant en 0,4 s ; zoomée, isolée ou en 3D, elle attend. La vue d'ensemble y est toujours la plus grande possible : dans la démo, 2 × 2 dans une fenêtre carrée ou haute, la rangée dans une fenêtre ordinaire (faits établis).
8. **Le coût de référence** (spec 4) : `DispositionPieces.Calcul.vueReference` remplace `vue2D`. Les niveaux y sont superposés ; dans un niveau, l'étage principal en x = 0, puis ses zones à côté vers la droite, `ESP` entre les bords. Les termes d'un lien (longueur, cartes traversées, croisements) ne comptent que dans un même niveau ; un lien entre deux niveaux coûte 0,1 × son écart horizontal. Pour un seul plateau, le coût du plan 4b, au bit près (`coutDUnSeulPlateau`). La disposition ne dépend ni de la fenêtre, ni du réglage (`grilleSelonLaTaille`).
9. **Les glissements** (`MoteurPieces.viser`) : le moteur garde la géométrie visée, et celle de l'image la rejoint en cubique entrée-sortie (`GeometrieMaison.vers`) : en 2D, 0,4 s au redimensionnement et après un changement de niveau (`CameraScene.dureeCases`), 2,6 s au changement du réglage (`dureeEnvol`) ; en 3D, 0,9 s après un changement de niveau (`dureeNiveaux`). Un glissement en cours repart de l'image, avec le temps qui lui restait s'il est plus long. Avec « Réduire les animations », tout de suite. La vue d'ensemble se recadre à chaque image ; un vol en cours rejoint l'arrivée de ce qu'il vise.
10. **La grille attend la vue d'ensemble 2D** (`grilleEnAttente`) quand la vue est zoomée, déplacée, isolée, en 3D ou en mouvement : elle garde la plus longue durée demandée, et l'hystérésis seulement si toutes la demandent. La première vraie taille pose la grille et cadre la vue d'ensemble, sans autre condition ; l'envol vers la 2D se pose sur la grille de la taille du moment.
11. **Le réglage** : `@AppStorage("etagesEnGrille")`, vrai par défaut, lu par la fenêtre, qui le passe au moteur (`onChange(initial:)`, `MoteurPieces.reglerGrille`) ; Réglages › Général gagne la section « Vue par pièces », avec le menu « Étages en 2D » (« En grille », « En rangée »).
12. **L'isolement, un état explicite** (`MoteurPieces.isolement` : `.maison`, `.etage(cle)`, `.piece(cle, provenance:)`) : la provenance est l'étage isolé d'où l'on a ouvert la pièce, nil depuis la maison (spec 5.4). Échap et le clic à côté remontent d'un cran ; d'une pièce à une autre du même étage, la provenance reste ; vers une pièce d'un autre étage, elle devient la maison.
13. **Un étage isolé** (spec 5.1) : un vol de 1,3 s cadre son plateau, bande de son nom comprise (`CameraScene.volVersEtage`, `vueEtage`) ; les autres plateaux s'estompent à 15 % (`SceneProjetee.voilesEtages`), la sphère et « ⌂ Maison » s'effacent, la rotation lente s'arrête ; les noms des appareils de l'étage suivent la règle du zoom. Rien dans une maison d'un seul plateau, ni pendant l'envol.
14. **Le fil** (spec 5.3) : « Maison › Étage › Pièce », même pour une pièce isolée depuis la vue d'ensemble ; chaque cran au-dessus du dernier mène à son niveau ; « Maison › Pièce » dans une maison d'un seul plateau. **La ligne de niveau d'un étage isolé** est « Étage isolé : %@ · clic sur une pièce ou un autre étage pour y aller, clic à côté ou Échap pour revenir », sur le modèle de celle d'une pièce isolée (plan 4b) ; la maquette n'en montre que la première moitié, son aide donnant le reste.
15. **La priorité des clics** (spec 5.1, `CibleClic`) : un appareil, une pièce (son bloc ou son nom), le nom d'un étage, son disque (en 3D, le plus proche sur le rayon, au point où il le rencontre), le fond. Le disque de l'étage isolé, entre ses pièces, ne fait rien ; dans une maison d'un seul plateau, le disque ne sert qu'à remonter d'une pièce isolée ; un double-clic sur un disque ramène à la maison, comme sur le fond.
16. **Le survol**, comme dans la maquette : un disque cliquable s'éclaircit (son dégradé une fois et demie plus clair), le nom d'un étage se souligne, et la main d'un lien se pose sur ce qui se clique.
17. **Le menu du clic droit** (spec 1.3) est le menu natif de SwiftUI (`contextMenu`), construit depuis une valeur testable (`MoteurPieces.menuEtage(_:) -> MenuEtage`) : le nom de la zone en tête, grisé (un bouton désactivé) ; « Monter d'un étage » et « Descendre d'un étage » ; « Au même niveau que », un sous-menu des autres niveaux, nommés par leur étage principal, celui de la zone coché ; « Hors de la maison », une case à cocher (`Toggle`) ; « Sur son propre niveau ». Il s'ouvre sur le nom (à 2 pt près) ou sur le disque ; le fond garde « Replacer les pièces automatiquement » ; une pièce ou un appareil n'a pas de menu.
18. **Les n° 8 et 9 du triage A** : les parts de l'isolement sont gardées par clé, de pièce (`fk`) et d'étage (`ek`) : un relevé reçu pendant un fondu ne remet pas la pièce à pleine taille ; les noms des appareils suivent l'état d'arrivée (une pièce visée : les siens ; le nom de l'appareil survolé ou choisi est toujours voulu).
19. **⌥ + glisser** (spec 6) : ⌥ est lue à l'appui, par `NSEvent.modifierFlags` au premier `onChanged` du `DragGesture` de la vue (faits établis), et le moteur ne la lit qu'à l'appui : le mode est fixé pour tout le geste. Le `DragGesture` actuel reste : un geste d'AppKit à part dédoublerait le clic, le glisser d'une pièce et le double-clic. `CameraScene.deplacerDansLEcran` fait glisser la cible et la caméra ensemble, parallèlement à l'écran, à 0,7 fois la vitesse du pointeur mesurée à la cible (`vitesseDeplacement`). Avec ⌥, une pièce ne bouge pas ; la rotation lente s'arrête pendant le geste ; en 2D, ⌥ ne change rien. Les curseurs (`Curseur`) : la main ouverte tant que ⌥ est tenue au-dessus de la vue en 3D, la main fermée pendant le geste.
20. **La pose exacte** (spec 6) : l'envol, les vols et le double-clic partent de la caméra telle qu'elle est, position, cible et azimut de la rotation lente compris (`envolEtVolsDepuisLaPoseExacte`, à 10⁻⁶ près).
21. **La démo** (spec 7) gagne deux zones, aux pièces de la maquette : « Jardin » (« Terrasse », « Abri ») et « Combles » (« Grenier », « Salle de jeux »). Le jardin est au niveau du rez-de-chaussée, hors de la maison, en mémoire : `NomsDemo.places()`, que l'app passe à la fenêtre (`FenetrePieces(…, places:)`, `MoteurPieces(…, places:)`), la démo n'écrivant rien. Aucune donnée radio nouvelle : dix nœuds de la démo changent de nom et de pièce.
    - **Les deux routeurs** que la démo appelait « Eve Door » (`02A8C3C5600F136B`) et « Capteur salon » (`0A84D1254BD246AD`), des routeurs Thread nommés comme des capteurs, deviennent « Prise console », dans la salle de jeux, et « Prise terrasse », sur la terrasse (spec 7 : un routeur dans chacune). Leurs liens radio vont à l'Apple TV 4K et aux HomePod du salon : entre deux niveaux pour la salle de jeux, au même niveau pour la terrasse.
    - **Leurs enfants :** « Lampe arcade » (`AA3D322B8A4500C4`, l'ancien « Bouton chevet ») sous la prise console, dans la salle de jeux ; « Capteur porte de l'abri » (`C656F369B620027F`, l'ancien « Thermo salon ») et « Vanne d'arrosage » (`82570DF21CF3784B`, l'ancien « Volet chambre ») sous la prise terrasse, dans l'abri.
    - **Des enfants des routeurs du salon et de la chambre**, pour les repères « ailleurs » : « Météo terrasse » (`DAEF22ACB58F651C`) passe du salon à la terrasse (↗ HomePod Palier, au même niveau) ; au grenier, « Eve Motion » (`3A5DFAFCAB581AAF`, de la buanderie), « Capteur d'humidité » (`327DF9C45C82BBD6`, l'ancien « Détecteur couloir ») et « Détecteur de chaleur allée » (`9A5C1F9FDFAB242D`, l'ancien « Fumée cuisine ») ; dans la salle de jeux, « Capteur de lucarne » (`C663573E49A1EC90`, l'ancien « Capteur bureau »).
    - **Pourquoi ceux-là :** ils remplissent les pièces nouvelles comme la maquette (grenier 3 appareils, salle de jeux 3, terrasse 2, abri 2 ; la maquette : 2, 3, 2, 2), sans vider une pièce d'avant. Sur la zone visible, la grille de la démo est 2 × 2 dans une fenêtre carrée (spec 7) : de 1000 pt, la légende ouverte, de 900 pt, repliée ; la rangée dans une fenêtre ordinaire (faits établis).
22. **Les images de démo** passent de 14 à 20 (spec 7) : les quatorze d'avant changent toutes ; s'y ajoutent `15-2d-carree-2x2` (une fenêtre carrée de 1000 pt, la légende ouverte : la grille 2 × 2), `16-2d-carree-en-rangee` (la même fenêtre, le réglage « En rangée »), `17-3d-jardin-dedans` (le jardin dans la maison), `18-2d-etage-isole` et `19-3d-etage-isole` (l'étage), `20-3d-terrasse-depuis-le-jardin` (une pièce isolée depuis son étage, le fil complet). Dans la fenêtre des images (1440 × 900), la grille de la démo est la rangée, la légende ouverte (`01-2d`) comme repliée (`14-2d-legende-repliee`). `CapturesPieces.Cas` gagne la taille de la fenêtre, la grille et les places gardées ; chaque image pose ses marges, dont celle de la grille (`basGrille`), avant d'installer la scène.
23. **La légende garde la taille de B** (décision de Djoko du 03/10 ; `SigneLegende.zoomVueDEnsemble` = 0,53, mesuré sur la démo de deux étages) : la vue d'ensemble de la démo de C, en rangée à 1440 × 900, est à 0,47 ; ses nœuds y font 6,1 et 3,3 pt, ceux de la légende 6,9 et 3,7 pt. `tailleDesSignes` vérifie désormais la formule du rayon dans la scène, et les signes de B.
24. **Trois tests rendus plus robustes :** `reglageEtagesEn2D` vaut dans les deux modes gardés de l'app de Djoko (faits établis) ; `prioriteDesClics`, au nom d'un étage, attend l'appareil ou la pièce qui serait dessous, avant lui, et en 2D tous les noms d'étage libres ; `signesCommeLaScene` (polissage B) tolère 32 octets d'écart au lieu de 8 (faits établis) : un autre dessin en changerait bien plus.
25. **« ⌂ Maison » évite les noms d'étage** (décision de Djoko du 03/10 ; spec 2) : il se pose après eux (priorité 2 ; les noms d'étage, 1, se posent même s'ils chevauchent), à ses places candidates habituelles, sous son ancre d'abord (le haut de la sphère), puis à droite, à gauche, au-dessus. Dans la petite vue 3D de la démo, il passe au-dessus de « Combles » (`maisonEviteLesEtages`, le cas de l'image `05-3d`).

**Écarts à la maquette**, imposés par l'app ou par la plateforme, montrés à Djoko à la tâche 8 :
- **La taille des vues d'ensemble.** La vue d'ensemble se cadre sous le haut de la fenêtre (139 pt) et au-dessus de la légende ouverte (249 pt) : c'est le polissage B. La maquette n'a ni légende ni bandeau : ses vues sont plus grandes (images `01-2d`, `05-3d`, `17-3d-jardin-dedans` contre les rendus `v5-2d-ordinaire`, `v5-3d-jardin-dehors`, `v5-3d-jardin-dedans`). Dans la fenêtre des images, la zone visible est large : la grille de la démo y est la rangée (décision de Djoko du 03/10, précision 7) ; elle est 2 × 2 dans une fenêtre carrée (`15-2d-carree-2x2`, contre `v5-2d-carree`).
- **« ⌂ Maison » évite les noms d'étage**, qu'il pouvait chevaucher dans la maquette quand une zone est hors de la maison (décision de Djoko du 03/10, précision 25) : dans `05-3d`, il passe au-dessus de « Combles ».
- **3 + 1 dans le rendu « ordinaire » de la maquette :** la maquette elle-même donne 2 × 2 dans son cadre « Ordinaire » (faits établis) ; l'app, sur sa zone visible, sous le haut de la fenêtre et au-dessus de la légende, donne la rangée à 1100 × 760 (précision 7).
- **Le menu** est celui de macOS : son dessin n'est pas celui de la maquette ; le nom en tête est un article grisé.
- **Les curseurs** sont ceux de macOS (`openHand`, `closedHand`, la main d'un lien), non ceux du CSS (`grab`, `grabbing`, `pointer`).
- **La ligne de niveau d'un étage isolé** dit aussi comment revenir (précision 14).
- **La démo :** ses pièces et ses appareils viennent de la démo d'avant, sans donnée radio nouvelle : le grenier a 3 appareils (la maquette : 2), « Sans pièce » est sur le plateau du bas, et les noms des appareils diffèrent.
- **Le groupe « Fenêtre » et le texte d'aide** de la maquette ne passent pas dans l'app (spec, section 0).

## Global Constraints

- **Plateformes :** app en macOS 26.0 minimum, développée avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`.
- **Code :** identifiants et commentaires en français **sans accents** ; textes affichés avec accents ; tests en Swift Testing. Les nouveaux fichiers (`Niveaux.swift`, `NiveauxTests.swift`, `IsolementTests.swift`) sont pris par les sources de `project.yml` sans le modifier : ce plan ne touche pas `project.yml`.
- **Le cœur change** (`MaillageCoeur/Scene/`, et `MaillageCoeur/Demo/NomsDemo.swift`), avec ses tests : les tests d'avant y restent verts, sauf ceux de la démo, qui changent avec elle (tâche 7).
- **La maquette se livre telle quelle :** les règles et les valeurs de son JavaScript (`geometrie()`, `disposition()`, `colonnesVoulues()`, `cadre2D`, `vuePlateau`, `isoler`, `allerEtage`, `remonter`, `poser()`, `panEcran`, les durées) ; un écart imposé par l'app ou par la plateforme est dit (écarts ci-dessus), jamais réinterprété. Le groupe « Fenêtre », le texte d'aide et les paramètres d'URL n'y passent pas.
- **Déterminisme :** aucun hasard ; la disposition est la même pour toutes les tailles de fenêtre et les deux modes 2D ; les images de démo ne dépendent ni de l'heure ni des préférences.
- **Textes de l'app :** tout texte nouveau est au catalogue (`MaillageThread/Ressources/Localizable.xcstrings`), avec son anglais, par les outils : compiler, `outils/synchroniser-textes.sh`, le script de la tâche (`python3 - <<'EOF' … EOF`, qui écrit `outils/traductions/interface.json`), puis `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`. `CataloguesTests` refuse une clé sans anglais, absente ou inutilisée.
- **Tests indépendants de la langue :** une attente sur un texte affiché reprend la même clé que le code (`String(localized: "Sans pièce")`), jamais une chaîne française figée. Les tests passent en anglais :

  ```bash
  xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-polC/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-polC/maillage-tests-en.log"
  ```
- **Commandes,** depuis la racine du dépôt, toujours avec un dossier de produits (`DD`) et un dossier temporaire (`TMPDIR`) propres à ce plan : une autre compilation (l'app de Djoko, une autre session) ne partage ni ses produits ni son journal. Le shell d'un agent ne garde pas ses variables d'une commande à l'autre : chaque commande les porte. Une fois, avant la tâche 1 :

  ```bash
  mkdir -p "$HOME/Library/Caches/maillage-polC"
  ```

  Puis, par exemple :

  ```bash
  DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/NiveauxTests
  ```

  `outils/tester.sh [cibles…]` génère le projet, compile et lance les tests, en Debug ; les produits vont dans `DD`, le journal complet dans `$TMPDIR/maillage-tests.log` ; une cible qui ne lance aucun test fait échouer le script (un test de Swift Testing se nomme avec ses parenthèses). `outils/mesurer.sh` lance les trois tests de temps en Release, dans le même `DD`, journal dans `$TMPDIR/maillage-mesures.log`. La première compilation dans ce `DD` neuf prend quelques minutes. **Jamais un autre `DD` que `maillage-polC` :** l'app de Djoko tourne depuis l'un des autres.
- **Une suite de tests de l'app à la fois** sur ce Mac : si un test sans rapport échoue avec `Test crashed with signal term`, vérifier qu'aucune autre session ne teste l'app (`pgrep -fl xcodebuild`), puis relancer la suite.
- **L'app :** de la tâche 1 à la tâche 7, un agent ne la lance qu'en mode démo, pour ses images, en instance à part : `open -n -g -W "$DD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures <dossier du conteneur>`. Elle écrit ses images sans fenêtre et quitte d'elle-même (`-W` attend qu'elle ait quitté) ; l'agent vérifie qu'elle ne tourne plus. Pour l'arrêter, `kill` sur son PID seulement, jamais `osascript … quit` : l'app de Djoko porte le même identifiant. Jamais en mode direct, jamais de `screencapture`, et l'app de Djoko n'est jamais quittée. La tâche 8 se fait avec Djoko, par le contrôleur.
- **Les préférences de l'app** sont celles de l'app de Djoko (même identifiant) : un test n'écrit jamais dans `UserDefaults.standard` (il prend un domaine à lui, `SondeMaillageTests.preferences()`), et ne suppose pas le mode 2D ou 3D gardé (faits établis).
- **Données personnelles** (le dépôt est public sur GitHub, `Djoko-cli/maillage-thread`) :
  - `noms.json` n'est jamais commité, ni lu par un test ; aucun agent ne lit le conteneur de l'app hors des dossiers d'images de ce plan ;
  - les tests utilisent des données inventées ou celles de la démo : ExtMac en `E0…`, noms de la démo et des maquettes ; aucun nom réel de pièce ou de zone de la maison de Djoko.
- **Signature :** l'app reste ad hoc (`Signature.xcconfig`). **Ne jamais créer `Local.xcconfig`.** Aucun identifiant d'équipe, empreinte de certificat ni adresse électronique dans un fichier commité.
- **Commits :**
  - un par tâche, message en français sans accents, terminé par une ligne vide puis la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - `git add` avec la liste de fichiers de la tâche, **jamais `git add -A` ni `git add .`** ;
  - jamais de push.
- **Interdits pour les agents :** `sudo` ; ouvrir un port série ou flasher ; lancer l'app en mode direct ; `screencapture` ; lancer le passeur ou `outils/passeur.sh` ; un navigateur ; réveiller l'écran ; quitter l'app de Djoko.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `MaillageCoeur/Scene/Niveaux.swift` (nouveau) | `Niveaux` (résolution, niveaux, ordre), `Rangement`, les opérations du menu | 1 |
| `MaillageCoeur/Scene/PlacesGardees.swift` | `ACote`, `Maison.aCote` (facultatif, version 1), `rangement`, `ranger` | 1 |
| `MaillageCoeur/Scene/ScenePieces.swift` | les niveaux de la scène ; `Etage.niveau`, `principal`, `dehors` | 1 |
| `MaillageCoeur/Scene/SceneProjetee.swift` | repères « ailleurs » par niveaux ; voiles des plateaux, survol d'un disque | 1, 5 |
| `MaillageCoeur/Scene/CameraScene.swift` | `GeometrieMaison` : grille, niveaux, 3D, sphère, `rayonCadre`, boîte ; `colonnes` ; `vers` ; cadrages d'un étage ; durées ; `deplacerDansLEcran` | 2, 4, 6 |
| `MaillageCoeur/Scene/DispositionPieces.swift` | le coût sur la vue de référence | 3 |
| `MaillageCoeur/Scene/PlacementNoms.swift` | les noms pendant un isolement, l'état d'arrivée, le nom d'étage souligné ; « ⌂ Maison » après les noms d'étage | 5, 7 |
| `MaillageCoeur/Demo/NomsDemo.swift` | les combles et le jardin ; `places()` | 7 |
| `MaillageThread/Vues/Pieces/EntreeScene.swift`, `LibellesNoeuds.swift` | les choix de niveau dans la scène et dans la clé de la disposition ; le repère au même niveau | 1 |
| `MaillageThread/Vues/Pieces/MoteurPieces.swift` | la géométrie visée et ses glissements, la grille sur la zone visible, l'isolement, le fil, les clics, le menu, ⌥ + glisser, les curseurs | 1, 2, 4 à 7 |
| `MaillageThread/Vues/Pieces/FenetrePieces.swift` | le réglage, la marge du bas de la zone visible, le menu natif, le fil à crans, la ligne de niveau, les curseurs | 4 à 7 |
| `MaillageThread/Vues/FenetreReglages.swift` | la section « Vue par pièces » | 4 |
| `MaillageThread/Vues/Pieces/RenduCanvas.swift` | le disque éclairci, le nom d'étage souligné | 5 |
| `MaillageThread/Vues/Pieces/CapturesPieces.swift`, `MaillageThread/MaillageThreadApp.swift`, `SigneLegende.swift` | vingt images, la grille sur leur zone visible ; les places de la démo ; la légende garde la taille de B | 7 |
| `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json` | 8 textes nouveaux (par les outils) | 4, 5 |
| `MaillageCoeurTests/NiveauxTests.swift` (nouveau), `PlacesGardeesTests.swift`, `ScenePiecesTests.swift`, `SceneProjeteeTests.swift` | les niveaux, le fichier, la scène, les repères, les voiles | 1, 5 |
| `MaillageCoeurTests/CameraSceneTests.swift` | la géométrie, la grille, les cadrages, ⌥ + glisser, la pose exacte | 2, 6 |
| `MaillageCoeurTests/DispositionPiecesTests.swift`, `MaisonInventee.swift` | le coût de référence, un seul plateau | 3 |
| `MaillageCoeurTests/PlacementNomsTests.swift`, `NomsTests.swift` | les noms pendant un isolement ; la maison de démo | 5, 7 |
| `MaillageThreadTests/IsolementTests.swift` (nouveau) | provenance, fil, priorité des clics, clic sur un étage, survol, menu, étage isolé, n° 8 et 9 | 5 |
| `MaillageThreadTests/MoteurPiecesTests.swift`, `FenetrePiecesTests.swift`, `NomsSceneTests.swift`, `LegendePiecesTests.swift` | la grille sur la zone visible, le réglage, les glissements, ⌥ + glisser, la démo, « ⌂ Maison », les images, la légende | 1, 3 à 7 |
| `README.md`, `README.fr.md` | les niveaux, la grille, l'isolement d'un étage, ⌥ + glisser, le menu, les vingt images | 7 |

---

### Task 1: Les niveaux dans le cœur : les zones à côté d'un étage, gardées dans les places, résolues sur la scène ; les opérations du menu

**Files:**
- Create: `MaillageCoeur/Scene/Niveaux.swift`, `MaillageCoeurTests/NiveauxTests.swift`
- Modify: `MaillageCoeur/Scene/PlacesGardees.swift`, `MaillageCoeur/Scene/ScenePieces.swift`, `MaillageCoeur/Scene/SceneProjetee.swift`, `MaillageThread/Vues/Pieces/EntreeScene.swift`, `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/PlacesGardeesTests.swift`, `MaillageCoeurTests/ScenePiecesTests.swift`, `MaillageCoeurTests/SceneProjeteeTests.swift`, `MaillageThreadTests/NomsSceneTests.swift`

**Interfaces:**
- Consumes :
  - `PlacesGardees` (`Maison.ordreEtages`, `etages`, `appareils`, `lire`, `ecrire(dans:)`, `maison(_:)`), `ScenePieces` (ses étages, `ordreEtages`), `SceneProjetee.Ailleurs`, `EntreeScene.cleDisposition`, `LibellesNoeuds`, existants ;
  - dans les tests : `NomsSceneTests.demo()`, `ScenePiecesTests.graphe(sonde:)`, `libelles`, existants.
- Produces :
  - `Niveaux(_:aCote:)` (`liste`, `aCote`, `plateaux`, `niveau(_:)`, `estPrincipal(_:)`, `dehors(_:)`) ; `Rangement(ordre:aCote:)` ; `Niveaux.deplacer(_:de:choix:)`, `rejoindre(_:niveau:choix:)`, `basculerDehors(_:choix:)`, `propreNiveau(_:choix:) -> Rangement?` ;
  - `PlacesGardees.ACote(etage:dehors:)` ; `PlacesGardees.Maison.aCote` ; `PlacesGardees.rangement(_:) -> Rangement`, `ranger(_:domicile:)` ;
  - `ScenePieces(…, aCote:)`, `ScenePieces.niveaux`, `Etage.niveau`, `principal`, `dehors` ;
  - `SceneProjetee.Ailleurs.Sens` (`.memeNiveau`, `.dessous`, `.dessus`), selon les niveaux ;
  - `EntreeScene.CleDisposition` (les pièces et les niveaux) ; le repère « ailleurs » d'un parent au même niveau, avec le nom de sa zone (`LibellesNoeuds`).

**Les niveaux** (spec, section 1). Un plateau est un étage, sur son propre niveau, ou une zone à côté d'un étage, son étage principal, dans ou hors de la maison. Le choix se garde dans `positions-pieces.json` (`aCote`), sans changer de version (précision 2). Le cœur le résout sur les plateaux de la scène, en fonctions pures (précision 1) : les niveaux, leur ordre, et les opérations du menu, que la tâche 5 branche sur le clic droit. La scène range ses plateaux par niveaux (précision 3), et la clé de la disposition compte les niveaux (précision 4).

**Le repère « ailleurs »** compare les niveaux, non plus les étages : un parent au même niveau, dans une autre zone, est marqué ↗, avec le nom de sa zone.

**Les images de démo ne changent pas** : la démo n'a encore aucun choix de niveau.

- [ ] **Step 1 : écrire les tests.** Un fichier de tests nouveau (`NiveauxTests`) ; le fichier sans `aCote` et son aller-retour ; les niveaux de la scène ; les repères par niveaux ; la clé de la disposition.

`MaillageCoeurTests/NiveauxTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : niveaux de la maison")
struct NiveauxTests {
    typealias A = PlacesGardees.ACote

    /// Sans choix : un etage par plateau, chacun sur son niveau, dans l'ordre garde.
    @Test func etagesSeulement() {
        let n = Niveaux(["rdc", "etage", "combles"], aCote: [:])
        #expect(n.liste == [["rdc"], ["etage"], ["combles"]])
        #expect(n.aCote.isEmpty && n.plateaux == ["rdc", "etage", "combles"])
        #expect(n.niveau("combles") == 2 && n.estPrincipal("etage") && !n.dehors("etage"))
        #expect(n.niveau("absent") == nil)
    }

    /// Une zone a cote partage le niveau de son etage principal, apres lui, dans ou hors de la maison ; elle
    /// le rejoint meme rangee avant lui dans l'ordre garde.
    @Test func zoneACote() {
        let dehors = Niveaux(["rdc", "jardin", "etage"], aCote: ["jardin": A(etage: "rdc", dehors: true)])
        #expect(dehors.liste == [["rdc", "jardin"], ["etage"]])
        #expect(dehors.niveau("jardin") == 0 && !dehors.estPrincipal("jardin") && dehors.dehors("jardin"))
        let dedans = Niveaux(["jardin", "etage", "rdc"], aCote: ["jardin": A(etage: "rdc")])
        #expect(dedans.liste == [["etage"], ["rdc", "jardin"]])
        #expect(!dedans.dehors("jardin") && dedans.aCote == ["jardin": A(etage: "rdc")])
    }

    /// Les cas tordus (spec de C, section 1.2) : un etage principal absent, une chaine, une boucle, une zone a
    /// cote d'elle-meme.
    @Test func casTordus() {
        let absent = Niveaux(["rdc", "jardin"], aCote: ["jardin": A(etage: "zone:Ailleurs", dehors: true)])
        #expect(absent.liste == [["rdc"], ["jardin"]] && absent.aCote.isEmpty, "la zone redevient un etage, a sa place")
        let chaine = Niveaux(["a", "b", "c"], aCote: ["a": A(etage: "b", dehors: true), "b": A(etage: "c")])
        #expect(chaine.liste == [["c", "a", "b"]])
        #expect(chaine.aCote == ["a": A(etage: "c", dehors: true), "b": A(etage: "c")], "A et B a cote de C")
        let boucle = Niveaux(["a", "b", "c"], aCote: ["a": A(etage: "b"), "b": A(etage: "a"), "c": A(etage: "a")])
        #expect(boucle.liste == [["a", "c"], ["b"]], "la boucle redevient des etages ; C rejoint le premier qu'il atteint")
        let soi = Niveaux(["a", "b"], aCote: ["a": A(etage: "a")])
        #expect(soi.liste == [["a"], ["b"]] && soi.aCote.isEmpty)
    }

    /// « Monter » et « Descendre » d'un niveau entier, zones a cote comprises ; grises pour une zone a cote, en
    /// haut et en bas de la pile.
    @Test func monterEtDescendre() {
        let choix = ["jardin": A(etage: "rdc", dehors: true)]
        let n = Niveaux(["rdc", "jardin", "etage", "combles"], aCote: choix)
        #expect(n.deplacer("rdc", de: 1, choix: choix) == Rangement(ordre: ["etage", "rdc", "jardin", "combles"], aCote: choix))
        #expect(n.deplacer("combles", de: -1, choix: choix)?.ordre == ["rdc", "jardin", "combles", "etage"])
        #expect(n.deplacer("jardin", de: 1, choix: choix) == nil, "une zone a cote")
        #expect(n.deplacer("combles", de: 1, choix: choix) == nil && n.deplacer("rdc", de: -1, choix: choix) == nil)
    }

    /// « Au meme niveau que » : la zone passe a cote de l'etage principal du niveau choisi, dans la maison, apres
    /// le groupe de cet etage ; ses propres zones a cote la suivent, avec leur choix. Le niveau ou elle est deja
    /// (l'article coche) ne change rien, ni pour un etage son propre niveau.
    @Test func auMemeNiveauQue() throws {
        let choix = ["jardin": A(etage: "rdc", dehors: true), "abri": A(etage: "combles", dehors: true)]
        let n = Niveaux(["rdc", "jardin", "etage", "combles", "abri"], aCote: choix)
        let combles = try #require(n.rejoindre("combles", niveau: 0, choix: choix))
        #expect(combles.ordre == ["rdc", "jardin", "combles", "abri", "etage"])
        #expect(combles.aCote == ["jardin": A(etage: "rdc", dehors: true), "combles": A(etage: "rdc"),
                                  "abri": A(etage: "rdc", dehors: true)])
        let jardin = try #require(n.rejoindre("jardin", niveau: 1, choix: choix))
        #expect(jardin.ordre == ["rdc", "etage", "jardin", "combles", "abri"])
        #expect(jardin.aCote["jardin"] == A(etage: "etage"), "dans la maison")
        #expect(n.rejoindre("jardin", niveau: 0, choix: choix) == nil, "deja a ce niveau")
        #expect(n.rejoindre("etage", niveau: 1, choix: choix) == nil, "son propre niveau")
        #expect(n.rejoindre("etage", niveau: 3, choix: choix) == nil, "un niveau qui n'existe pas")
    }

    /// « Hors de la maison », une case a cocher pour une zone a cote ; « Sur son propre niveau » : la zone
    /// redevient un etage, juste au-dessus du niveau qu'elle partageait. Rien pour un etage.
    @Test func dehorsEtPropreNiveau() throws {
        let choix = ["jardin": A(etage: "rdc", dehors: true), "garage": A(etage: "rdc")]
        let n = Niveaux(["rdc", "jardin", "garage", "etage"], aCote: choix)
        let rentre = try #require(n.basculerDehors("jardin", choix: choix))
        #expect(rentre.aCote["jardin"] == A(etage: "rdc") && rentre.ordre == n.plateaux)
        #expect(n.basculerDehors("rdc", choix: choix) == nil)
        let propre = try #require(n.propreNiveau("jardin", choix: choix))
        #expect(propre.ordre == ["rdc", "garage", "jardin", "etage"] && propre.aCote == ["garage": A(etage: "rdc")])
        #expect(Niveaux(propre.ordre, aCote: propre.aCote).liste == [["rdc", "garage"], ["jardin"], ["etage"]])
        #expect(n.propreNiveau("etage", choix: choix) == nil)
    }

    /// Les choix rendus : ceux des plateaux de la scene remis a plat (une chaine resolue, une zone a cote
    /// d'elle-meme oubliee) ; celui d'une zone dont l'etage principal est absent reste, comme celui d'un
    /// plateau absent.
    @Test func choixRendus() throws {
        let choix = ["a": A(etage: "b", dehors: true), "b": A(etage: "c"), "d": A(etage: "d"),
                     "e": A(etage: "zone:Ailleurs"), "zone:Absente": A(etage: "c")]
        let n = Niveaux(["a", "b", "c", "d", "e"], aCote: choix)
        let r = try #require(n.deplacer("d", de: 1, choix: choix))
        #expect(r.aCote == ["a": A(etage: "c", dehors: true), "b": A(etage: "c"), "e": A(etage: "zone:Ailleurs"),
                            "zone:Absente": A(etage: "c")])
        #expect(r.ordre == ["c", "a", "b", "e", "d"])
    }
}
```

Dans `MaillageCoeurTests/PlacesGardeesTests.swift`, remplacer :

```swift
    /// Ordre des etages garde, puis « Replacer les pieces automatiquement » : les places partent,
```

par :

```swift
    /// Les zones a cote (polissage C, section 1.2), un champ facultatif de la version 1, comme `appareils` dans
    /// `pieces-routeurs.json` : sans zone a cote, il n'est pas ecrit, et le fichier reste celui d'avant ; un
    /// aller-retour sur disque garde l'ordre, les places et les choix ; une app d'avant relit l'ordre et les
    /// places d'un fichier d'apres ; un champ mal forme est ignore, sans perdre l'ordre ni les places.
    /// « Replacer les pieces automatiquement » garde l'ordre et les choix de niveau.
    @Test func zonesACote() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var p = PlacesGardees()
        p.garder(SIMD2(1.5, -2.25), piece: "piece:Salon", etage: "zone:Rez-de-chaussée", domicile: "Maison")
        p.ordonner(["zone:Rez-de-chaussée", "zone:Étage"], domicile: "Maison")
        try p.ecrire(dans: url)
        #expect(!String(decoding: try Data(contentsOf: url), as: UTF8.self).contains("aCote"), "un fichier d'avant")
        #expect(PlacesGardees.lire(url) == p && PlacesGardees.lire(url).maison("Maison").aCote.isEmpty)
        let r = Rangement(ordre: ["zone:Rez-de-chaussée", "zone:Jardin", "zone:Étage"],
                          aCote: ["zone:Jardin": PlacesGardees.ACote(etage: "zone:Rez-de-chaussée", dehors: true)])
        p.ranger(r, domicile: "Maison")
        try p.ecrire(dans: url)
        let relu = PlacesGardees.lire(url)
        #expect(relu == p && relu.version == PlacesGardees.versionActuelle && PlacesGardees.versionActuelle == 1)
        #expect(relu.rangement("Maison") == r && relu.maison("Maison").etages == p.maison("Maison").etages)
        // Une app d'avant : son schema, sans le champ.
        struct AncienneMaison: Decodable {
            var ordreEtages: [String]
            var etages: [String: [String: PlacesGardees.Place]]
        }
        struct Ancienne: Decodable {
            var version: Int
            var maisons: [String: AncienneMaison]
        }
        let ancienne = try JSONDecoder().decode(Ancienne.self, from: Data(contentsOf: url))
        #expect(ancienne.version == 1 && ancienne.maisons["Maison"]?.ordreEtages == r.ordre)
        #expect(ancienne.maisons["Maison"]?.etages == p.maison("Maison").etages)
        // Un champ mal forme.
        let texte = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        #expect(texte.contains("\"dehors\" : true"))
        try Data(texte.replacingOccurrences(of: "\"dehors\" : true", with: "\"dehors\" : \"oui\"").utf8).write(to: url)
        let abime = PlacesGardees.lire(url).maison("Maison")
        #expect(abime.aCote.isEmpty && abime.ordreEtages == r.ordre && abime.etages == p.maison("Maison").etages)
        p.replacer(domicile: "Maison")
        #expect(p.maison("Maison").etages.isEmpty && p.rangement("Maison") == r)
    }

    /// Ordre des etages garde, puis « Replacer les pieces automatiquement » : les places partent,
```

Dans `MaillageCoeurTests/ScenePiecesTests.swift`, remplacer :

```swift
    /// Deux zones de Maison du meme nom (inattendu) : un seul etage, a la place de la premiere, avec les
```

par :

```swift
    /// Niveaux (polissage C, section 1) : une zone a cote rejoint son etage principal, juste apres lui, meme
    /// rangee avant lui par Maison ; les plateaux sont ranges niveau par niveau. « Sans piece » va sur le
    /// plateau du bas, l'etage principal du premier niveau. Sans choix, l'ordre de Maison.
    @Test func niveaux() throws {
        let g = try Self.graphe(sonde: false)
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre", "E000000000000002": "Terrasse"]
        let zones = [ZoneMaison(nom: "Jardin", pieces: ["Terrasse"]), ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]),
                     ZoneMaison(nom: "Étage", pieces: ["Chambre"])]
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                            piecesMaison: true,
                            aCote: ["zone:Jardin": PlacesGardees.ACote(etage: "zone:Rez-de-chaussée", dehors: true)])
        #expect(s.etages.map(\.id) == ["zone:Rez-de-chaussée", "zone:Jardin", "zone:Étage"])
        #expect(s.etages.map(\.niveau) == [0, 0, 1] && s.etages.map(\.principal) == [true, false, true])
        #expect(s.etages.map(\.dehors) == [false, true, false])
        #expect(s.niveaux.liste == [["zone:Rez-de-chaussée", "zone:Jardin"], ["zone:Étage"]])
        #expect(Self.noms(s, etage: 0) == [.maison("Salon"), .sansPiece], "« Sans piece » sur le plateau du bas")
        #expect(Self.noms(s, etage: 1) == [.maison("Terrasse")])
        let sans = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                               piecesMaison: true)
        #expect(sans.etages.map(\.id) == ["zone:Jardin", "zone:Rez-de-chaussée", "zone:Étage"])
        #expect(sans.etages.map(\.niveau) == [0, 1, 2] && sans.etages.allSatisfy(\.principal))
    }

    /// Deux zones de Maison du meme nom (inattendu) : un seul etage, a la place de la premiere, avec les
```

Dans `MaillageCoeurTests/SceneProjeteeTests.swift`, remplacer :

```swift
        #expect(reperes[1].sens == .memeEtage && reperes[1].piece == chambre)
```

par :

```swift
        #expect(reperes[1].sens == .memeNiveau && reperes[1].piece == chambre)
```

Dans `MaillageCoeurTests/SceneProjeteeTests.swift`, remplacer :

```swift
    /// Survol d'un appareil : ses liens enfant-parent s'eclairent a 0,85 ; les autres restent a 0,28.
```

par :

```swift
    /// Le sens d'un repere « ailleurs » compare les niveaux (polissage C, section 5.2) : un parent dans l'etage
    /// principal d'une zone a cote est au meme niveau (↗) ; un parent a l'etage, au-dessus (↑). La zone mise sur
    /// son propre niveau, au-dessus des deux autres : ses parents sont en dessous.
    @Test func reperesParNiveau() throws {
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre", "E000000000000002": "Terrasse",
                      "E000000000000003": "Terrasse"]
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre"]),
                     ZoneMaison(nom: "Jardin", pieces: ["Terrasse"])]
        for aCote in [["zone:Jardin": PlacesGardees.ACote(etage: "zone:Rez-de-chaussée", dehors: true)], [:]] {
            let s = ScenePieces(graphe: try ScenePiecesTests.graphe(sonde: true), libelles: ScenePiecesTests.libelles,
                                piecesNoeuds: pieces, zones: zones, chefs: ["Apple TV"], piecesMaison: true, aCote: aCote)
            let terrasse = try Self.indice(s, "Terrasse")
            let sens = SceneProjetee.reperes(s, focus: terrasse).sorted { $0.enfant < $1.enfant }.map(\.sens)
            #expect(sens == (aCote.isEmpty ? [.dessous, .dessous] : [.memeNiveau, .dessus]), "\(aCote)")
        }
    }

    /// Survol d'un appareil : ses liens enfant-parent s'eclairent a 0,85 ; les autres restent a 0,28.
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
        let suite = a.sens == .memeEtage ? "" : ", " + LibellesNoeuds.nom(e.scene.etages[a.etage].nom)
        let fleche = switch a.sens {
        case .memeEtage: "↗"
```

par :

```swift
        let suite = a.sens == .memeNiveau ? "" : ", " + LibellesNoeuds.nom(e.scene.etages[a.etage].nom)
        let fleche = switch a.sens {
        case .memeNiveau: "↗"
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
    /// Routeurs de bordure que Maison ne place pas : la piece de leur nom (« HomePod mini chambre »), sinon
```

par :

```swift
    /// Repere « ailleurs » d'un parent au meme niveau, dans une autre zone (polissage C, section 5.2) : ↗, avec le
    /// nom de sa zone. L'entree mise dans un « Jardin » a cote du rez-de-chaussee : le parent du detecteur du
    /// couloir, l'Apple TV, est au salon. Sans le choix, le jardin est un etage au-dessus : ↓.
    @Test func repereAuMemeNiveau() throws {
        let (s, r, _) = try Self.demo()
        var maison = try #require(s.noms.maison)
        maison.zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Buanderie"]),
                        ZoneMaison(nom: "Jardin", pieces: ["Entrée"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"])]
        s.noms.maison = maison
        var places = PlacesGardees()
        places.ranger(Rangement(ordre: [], aCote: ["zone:Jardin": PlacesGardees.ACote(etage: "zone:Rez-de-chaussée")]),
                      domicile: maison.domicile ?? "")
        for (p, attendu) in [(places, "↗ Apple TV 4K · Salon, Rez-de-chaussée"), (PlacesGardees(), "↓ Apple TV 4K · Salon, Rez-de-chaussée")] {
            let e = EntreeScene(surveillance: s, reseau: r, places: p)
            let entree = try #require(e.scene.pieces.firstIndex { $0.nom == .maison("Entrée") })
            let a = try #require(SceneProjetee.reperes(e.scene, focus: entree).first { $0.enfant == "327DF9C45C82BBD6" })
            #expect(LibellesNoeuds.ailleurs(a, scene: e.scene, libelles: e.libelles) == attendu)
        }
    }

    /// Routeurs de bordure que Maison ne place pas : la piece de leur nom (« HomePod mini chambre »), sinon
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
    /// La cle de la disposition ne change pas avec l'etat d'un noeud ; elle change avec son nom.
    @Test func cleDeLaDisposition() throws {
        let (s, r, e) = try Self.demo()
        #expect(EntreeScene(surveillance: s, reseau: r, places: PlacesGardees()).cleDisposition == e.cleDisposition)
        s.renommer("56B1E064401F74EF", en: "Pont Halo")
        #expect(EntreeScene(surveillance: s, reseau: r, places: PlacesGardees()).cleDisposition != e.cleDisposition)
```

par :

```swift
    /// La cle de la disposition ne change pas avec l'etat d'un noeud ; elle change avec son nom. Elle suit les
    /// niveaux tels que les voit le cout (polissage C, section 4) : une zone mise a cote d'un etage la change ;
    /// l'ordre des niveaux au-dessus du plateau du bas (qui porte « Sans piece »), ou une zone sortie de la
    /// maison, non.
    @Test func cleDeLaDisposition() throws {
        let (s, r, e) = try Self.demo()
        #expect(EntreeScene(surveillance: s, reseau: r, places: PlacesGardees()).cleDisposition == e.cleDisposition)
        var maison = try #require(s.noms.maison)
        maison.zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Chambre d'amis"]),
                        ZoneMaison(nom: "Combles", pieces: ["Bureau", "Salle de bain"])]
        s.noms.maison = maison
        let domicile = maison.domicile ?? ""
        func cle(_ ordre: [String], _ aCote: [String: PlacesGardees.ACote]) -> EntreeScene.CleDisposition {
            var p = PlacesGardees()
            p.ranger(Rangement(ordre: ordre, aCote: aCote), domicile: domicile)
            return EntreeScene(surveillance: s, reseau: r, places: p).cleDisposition
        }
        let rdc = "zone:Rez-de-chaussée", etage = "zone:Étage", combles = "zone:Combles"
        let depart = cle([rdc, etage, combles], [:])
        let aCote = cle([rdc, etage, combles], [combles: PlacesGardees.ACote(etage: etage)])
        #expect(aCote != depart, "les combles a cote de l'etage")
        #expect(cle([rdc, combles, etage], [:]) == depart, "l'ordre des niveaux")
        #expect(cle([rdc, etage, combles], [combles: PlacesGardees.ACote(etage: etage, dehors: true)]) == aCote,
                "hors de la maison")
        s.renommer("56B1E064401F74EF", en: "Pont Halo")
        #expect(cle([rdc, etage, combles], [:]) != depart)
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/NiveauxTests MaillageCoeurTests/PlacesGardeesTests MaillageCoeurTests/ScenePiecesTests MaillageCoeurTests/SceneProjeteeTests MaillageThreadTests/NomsSceneTests`
Expected: la compilation des tests échoue (`NiveauxTests.swift`, `ScenePiecesTests.swift`), par exemple avec `error: 'ACote' is not a member type of struct 'MaillageCoeur.PlacesGardees'` et `error: cannot find 'Niveaux' in scope` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** Le fichier des niveaux, puis les places gardées, la scène, la projection, l'entrée de la scène, les libellés, le moteur.

`MaillageCoeur/Scene/Niveaux.swift` (fichier entier) :

```swift
import Foundation

/// Niveaux de la maison (polissage C, section 1) : chaque plateau est un etage, sur son propre niveau, ou
/// une zone a cote d'un etage, l'etage principal du niveau qu'elle partage, dans ou hors de la maison.
/// Les niveaux vont du bas vers le haut, dans l'ordre des etages ; dans un niveau, l'etage principal vient
/// d'abord, puis ses zones a cote, dans l'ordre garde.
///
/// Les choix gardes (`PlacesGardees.Maison.aCote`) sont resolus sur les plateaux de la scene :
/// - un etage principal absent de la scene : la zone redevient un etage, a sa place dans l'ordre (son choix
///   reste dans le fichier) ;
/// - une chaine (A a cote de B, B a cote de C) : A et B sont a cote de C ;
/// - une boucle : ses plateaux redeviennent des etages ;
/// - une zone a cote d'elle-meme : le choix est ignore.
public struct Niveaux: Hashable, Sendable {
    /// Plateaux de chaque niveau, du bas vers le haut : l'etage principal, puis ses zones a cote.
    public let liste: [[String]]
    /// Zones a cote, resolues : la cle de chacune -> son etage principal, et si elle est hors de la maison.
    public let aCote: [String: PlacesGardees.ACote]

    /// `cles` : les plateaux de la scene, dans l'ordre garde, du bas vers le haut ; `choix` : les choix gardes.
    public init(_ cles: [String], aCote choix: [String: PlacesGardees.ACote]) {
        let presents = Set(cles)
        // Le plateau dont `x` partage le niveau, d'apres son choix : ni lui-meme, ni un plateau absent.
        func suivant(_ x: String) -> String? {
            guard let a = choix[x], a.etage != x, presents.contains(a.etage) else { return nil }
            return a.etage
        }
        // Les plateaux d'une boucle redeviennent des etages.
        var boucles = Set<String>()
        for c in cles {
            var chemin: [String] = []
            var rang: [String: Int] = [:]
            var x: String? = c
            while let y = x, rang[y] == nil {
                rang[y] = chemin.count
                chemin.append(y)
                x = suivant(y)
            }
            if let y = x, let k = rang[y] { boucles.formUnion(chemin[k...]) }
        }
        // L'etage principal d'un plateau : le bout de sa chaine (lui-meme pour un etage).
        func principal(_ c: String) -> String {
            var x = c
            while !boucles.contains(x), let y = suivant(x) { x = y }
            return x
        }
        var resolus: [String: PlacesGardees.ACote] = [:]
        for c in cles {
            let p = principal(c)
            if p != c, let a = choix[c] { resolus[c] = PlacesGardees.ACote(etage: p, dehors: a.dehors) }
        }
        aCote = resolus
        liste = cles.filter { resolus[$0] == nil }.map { e in [e] + cles.filter { resolus[$0]?.etage == e } }
    }

    /// Tous les plateaux, niveau par niveau, du bas vers le haut.
    public var plateaux: [String] { liste.flatMap { $0 } }

    /// Le niveau d'un plateau (0 en bas) ; nil s'il n'est pas dans la scene.
    public func niveau(_ cle: String) -> Int? { liste.firstIndex { $0.contains(cle) } }

    /// Le plateau est un etage, l'etage principal de son niveau.
    public func estPrincipal(_ cle: String) -> Bool { liste.contains { $0.first == cle } }

    /// La zone a cote est hors de la maison.
    public func dehors(_ cle: String) -> Bool { aCote[cle]?.dehors == true }
}

/// Ce que les places gardent des niveaux d'une maison (polissage C, section 1.2) : l'ordre de ses plateaux,
/// du bas vers le haut, zones a cote comprises, et le choix de chaque zone a cote.
public struct Rangement: Hashable, Sendable {
    public var ordre: [String]
    public var aCote: [String: PlacesGardees.ACote]

    public init(ordre: [String], aCote: [String: PlacesGardees.ACote]) {
        self.ordre = ordre
        self.aCote = aCote
    }
}

/// Les operations du menu du clic droit (polissage C, section 1.3) : chacune rend le nouvel ordre des
/// plateaux de la scene et les nouveaux choix, ou nil quand elle n'a pas lieu (un article grise, ou deja
/// coche). Les choix des plateaux de la scene y sont ceux qui valent (`aCote`, resolus) : une chaine est
/// remise a plat, une boucle et une zone a cote d'elle-meme sont oubliees ; ceux des plateaux absents
/// restent tels quels.
extension Niveaux {
    /// « Monter d'un etage » (+1), « Descendre d'un etage » (-1) : le niveau entier de l'etage `cle`, zones a
    /// cote comprises, change de place avec le niveau voisin. Rien pour une zone a cote, ni en haut et en bas
    /// de la pile.
    public func deplacer(_ cle: String, de pas: Int, choix: [String: PlacesGardees.ACote]) -> Rangement? {
        guard estPrincipal(cle), let i = niveau(cle), liste.indices.contains(i + pas) else { return nil }
        var l = liste
        l.swapAt(i, i + pas)
        return Rangement(ordre: l.flatMap { $0 }, aCote: aPlat(choix))
    }

    /// « Au meme niveau que » l'etage principal du niveau `i` : la zone passe a cote de lui, dans la maison,
    /// juste apres le groupe de cet etage ; ses propres zones a cote la suivent. Rien pour le niveau ou la
    /// zone est deja (l'article coche), ni pour un etage et son propre niveau.
    public func rejoindre(_ cle: String, niveau i: Int, choix: [String: PlacesGardees.ACote]) -> Rangement? {
        guard let n = niveau(cle), liste.indices.contains(i), n != i else { return nil }
        let p = liste[i][0]
        let groupe = estPrincipal(cle) ? liste[n] : [cle]
        var r = aPlat(choix)
        r[cle] = PlacesGardees.ACote(etage: p, dehors: false)
        for z in groupe.dropFirst() { r[z] = PlacesGardees.ACote(etage: p, dehors: dehors(z)) }
        var l = liste
        l[i] += groupe
        l[n].removeAll { groupe.contains($0) }
        return Rangement(ordre: l.filter { !$0.isEmpty }.flatMap { $0 }, aCote: r)
    }

    /// « Hors de la maison » : une case a cocher, pour une zone a cote seulement.
    public func basculerDehors(_ cle: String, choix: [String: PlacesGardees.ACote]) -> Rangement? {
        guard let a = aCote[cle] else { return nil }
        var r = aPlat(choix)
        r[cle] = PlacesGardees.ACote(etage: a.etage, dehors: !a.dehors)
        return Rangement(ordre: plateaux, aCote: r)
    }

    /// « Sur son propre niveau », pour une zone a cote seulement : elle redevient un etage, juste au-dessus
    /// du niveau qu'elle partageait.
    public func propreNiveau(_ cle: String, choix: [String: PlacesGardees.ACote]) -> Rangement? {
        guard aCote[cle] != nil, let n = niveau(cle) else { return nil }
        var r = aPlat(choix)
        r[cle] = nil
        var l = liste
        l[n].removeAll { $0 == cle }
        l.insert([cle], at: n + 1)
        return Rangement(ordre: l.flatMap { $0 }, aCote: r)
    }

    /// Les choix gardes, ceux des plateaux de la scene remis a plat : ceux qui valent, resolus ; un choix
    /// ignore (a cote de soi-meme, d'une boucle) est oublie ; un etage principal absent garde son choix.
    func aPlat(_ choix: [String: PlacesGardees.ACote]) -> [String: PlacesGardees.ACote] {
        var r = choix
        let presents = Set(plateaux)
        for c in plateaux {
            if let a = aCote[c] {
                r[c] = a
            } else if let a = choix[c], presents.contains(a.etage) {
                r[c] = nil
            }
        }
        return r
    }
}
```

Dans `MaillageCoeur/Scene/PlacesGardees.swift`, remplacer :

```swift
/// perd sa place.
public struct PlacesGardees: Hashable, Sendable, Codable {
```

par :

```swift
/// perd sa place. Depuis le polissage C, le choix de niveau des zones a cote (`aCote`).
public struct PlacesGardees: Hashable, Sendable, Codable {
    /// Version 1 : l'ordre et les places, puis, depuis le polissage C, les zones a cote (`aCote`), un champ
    /// facultatif, comme `appareils` dans `pieces-routeurs.json`. Un fichier d'avant se lit sans perte ; une
    /// app d'avant lit encore l'ordre et les places d'un fichier d'apres, et ignore le champ.
```

Dans `MaillageCoeur/Scene/PlacesGardees.swift`, remplacer :

```swift
    public struct Maison: Hashable, Sendable, Codable {
        /// Cles des etages, du bas vers le haut.
        public var ordreEtages: [String] = []
        /// Cle d'etage -> cle de piece -> place.
        public var etages: [String: [String: Place]] = [:]

        public init(ordreEtages: [String] = [], etages: [String: [String: Place]] = [:]) {
            self.ordreEtages = ordreEtages
            self.etages = etages
```

par :

```swift
    /// Le choix d'une zone a cote (polissage C, section 1.2) : la cle de l'etage principal dont elle partage
    /// le niveau, et si elle est hors de la maison.
    public struct ACote: Hashable, Sendable, Codable {
        public var etage: String
        public var dehors: Bool

        public init(etage: String, dehors: Bool = false) {
            self.etage = etage
            self.dehors = dehors
        }
    }

    public struct Maison: Hashable, Sendable, Codable {
        /// Cles des plateaux, du bas vers le haut, zones a cote comprises.
        public var ordreEtages: [String] = []
        /// Cle d'etage -> cle de piece -> place.
        public var etages: [String: [String: Place]] = [:]
        /// Cle d'une zone a cote -> son choix ; un plateau qui n'y est pas est un etage.
        public var aCote: [String: ACote] = [:]

        public init(ordreEtages: [String] = [], etages: [String: [String: Place]] = [:], aCote: [String: ACote] = [:]) {
            self.ordreEtages = ordreEtages
            self.etages = etages
            self.aCote = aCote
        }

        private enum CodingKeys: String, CodingKey {
            case ordreEtages, etages, aCote
        }

        /// `aCote` manque aux fichiers d'avant le polissage C : des etages seulement. Mal forme, il est ignore
        /// de meme : un champ facultatif ne doit pas faire perdre l'ordre ni les places.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            ordreEtages = try c.decode([String].self, forKey: .ordreEtages)
            etages = try c.decode([String: [String: Place]].self, forKey: .etages)
            aCote = (try? c.decodeIfPresent([String: ACote].self, forKey: .aCote)) ?? [:]
        }

        /// Sans zone a cote, le champ n'est pas ecrit : le fichier reste celui d'avant le polissage C.
        public func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(ordreEtages, forKey: .ordreEtages)
            try c.encode(etages, forKey: .etages)
            if !aCote.isEmpty { try c.encode(aCote, forKey: .aCote) }
```

Dans `MaillageCoeur/Scene/PlacesGardees.swift`, remplacer :

```swift
    /// « Replacer les pieces automatiquement » : oublie les places de la maison, garde l'ordre des etages.
```

par :

```swift
    /// L'ordre des plateaux et les choix de niveau de la maison (polissage C, section 1.2).
    public func rangement(_ domicile: String) -> Rangement {
        let m = maison(domicile)
        return Rangement(ordre: m.ordreEtages, aCote: m.aCote)
    }

    /// Garde l'ordre des plateaux et les choix de niveau, apres un choix du menu du clic droit.
    public mutating func ranger(_ r: Rangement, domicile: String) {
        maisons[domicile, default: Maison()].ordreEtages = r.ordre
        maisons[domicile, default: Maison()].aCote = r.aCote
    }

    /// « Replacer les pieces automatiquement » : oublie les places de la maison, garde l'ordre des etages et
    /// les choix de niveau.
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
/// - Pieces : celles de Maison (le champ `piece` de l'accessoire du noeud) ; un noeud sans piece va
```

par :

```swift
/// - Niveaux (polissage C, section 1) : un plateau est un etage, ou une zone a cote d'un etage, dont elle
///   partage le niveau (`Niveaux`, d'apres les choix gardes). Les plateaux sont ranges niveau par niveau,
///   du bas vers le haut, et dans un niveau l'etage principal d'abord, puis ses zones a cote : l'ordre des
///   plateaux en 2D. Avec des etages seulement, c'est l'ordre garde.
/// - Pieces : celles de Maison (le champ `piece` de l'accessoire du noeud) ; un noeud sans piece va
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
        public var pieces: [Int]
```

par :

```swift
        public var pieces: [Int]
        /// Son niveau (0 en bas) ; un etage principal, ou une zone a cote de lui ; hors de la maison.
        public var niveau: Int
        public var principal: Bool
        public var dehors: Bool
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
    /// Maison n'a encore aucune piece : cartes par routeur, et le bandeau du passeur.
```

par :

```swift
    /// Les niveaux de ses plateaux (polissage C, section 1).
    public private(set) var niveaux: Niveaux
    /// Maison n'a encore aucune piece : cartes par routeur, et le bandeau du passeur.
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
    /// cles des etages dans l'ordre garde, du bas vers le haut.
    public init(graphe: GrapheReseau, libelles: [String: String], piecesNoeuds: [String: String],
                zones: [ZoneMaison]?, chefs: Set<String>, piecesMaison: Bool, ordreEtages: [String] = []) {
```

par :

```swift
    /// cles des etages dans l'ordre garde, du bas vers le haut ; `aCote` : les choix de niveau gardes.
    public init(graphe: GrapheReseau, libelles: [String: String], piecesNoeuds: [String: String],
                zones: [ZoneMaison]?, chefs: Set<String>, piecesMaison: Bool, ordreEtages: [String] = [],
                aCote: [String: PlacesGardees.ACote] = [:]) {
```

Dans `MaillageCoeur/Scene/ScenePieces.swift`, remplacer :

```swift
        // Ordre garde d'abord ; un etage qu'il ne connait pas garde son rang, au-dessus.
        let rang = Dictionary(ordreEtages.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let ordre = noms.indices.sorted {
            (rang[noms[$0].cle] ?? Int.max, $0) < (rang[noms[$1].cle] ?? Int.max, $1)
        }
        let nouveau = Dictionary(uniqueKeysWithValues: ordre.enumerated().map { ($1, $0) })
        etages = ordre.map { Etage(nom: noms[$0], pieces: []) }
```

par :

```swift
        // Ordre garde d'abord ; un etage qu'il ne connait pas garde son rang, au-dessus. Puis les niveaux :
        // chaque zone a cote rejoint son etage principal.
        let rang = Dictionary(ordreEtages.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let garde = noms.indices.sorted {
            (rang[noms[$0].cle] ?? Int.max, $0) < (rang[noms[$1].cle] ?? Int.max, $1)
        }
        let n = Niveaux(garde.map { noms[$0].cle }, aCote: aCote)
        let indiceNom = Dictionary(uniqueKeysWithValues: noms.indices.map { (noms[$0].cle, $0) })
        let ordre = n.plateaux.compactMap { indiceNom[$0] }
        let nouveau = Dictionary(uniqueKeysWithValues: ordre.enumerated().map { ($1, $0) })
        niveaux = n
        etages = ordre.map { i in
            let c = noms[i].cle
            return Etage(nom: noms[i], pieces: [], niveau: n.niveau(c) ?? 0, principal: n.estPrincipal(c),
                         dehors: n.dehors(c))
        }
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        /// Parent au meme etage (↗), a un etage en dessous (↓), au-dessus (↑).
        case memeEtage, dessous, dessus
```

par :

```swift
        /// Parent au meme niveau (↗), a un niveau en dessous (↓), au-dessus (↑) (polissage C, section 5.2).
        case memeNiveau, dessous, dessus
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
    /// une autre piece, dans l'ordre de ses lignes.
    public static func reperes(_ scene: ScenePieces, focus i: Int) -> [Ailleurs] {
        let pc = scene.pieces[i]
```

par :

```swift
    /// une autre piece, dans l'ordre de ses lignes ; leur sens compare les niveaux des deux plateaux.
    public static func reperes(_ scene: ScenePieces, focus i: Int) -> [Ailleurs] {
        let pc = scene.pieces[i]
        let ici = scene.etages[pc.etage].niveau
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
            return Ailleurs(enfant: id, parent: parent, piece: np.piece, etage: ep,
                            sens: ep == pc.etage ? .memeEtage : ep < pc.etage ? .dessous : .dessus)
```

par :

```swift
            let la = scene.etages[ep].niveau
            return Ailleurs(enfant: id, parent: parent, piece: np.piece, etage: ep,
                            sens: la == ici ? .memeNiveau : la < ici ? .dessous : .dessus)
```

Dans `MaillageThread/Vues/Pieces/EntreeScene.swift`, remplacer :

```swift
    /// `places` : les places gardees, dont l'ordre des etages de la maison ; `choix` : les pieces
    /// choisies pour les noeuds que Maison ne place pas, routeurs de bordure (sous leur instance) et
    /// autres noeuds (sous leur ExtMac, precision 27).
```

par :

```swift
    /// `places` : les places gardees, dont l'ordre des etages de la maison et ses choix de niveau ; `choix` :
    /// les pieces choisies pour les noeuds que Maison ne place pas, routeurs de bordure (sous leur instance)
    /// et autres noeuds (sous leur ExtMac, precision 27).
```

Dans `MaillageThread/Vues/Pieces/EntreeScene.swift`, remplacer :

```swift
                                ordreEtages: places.maison(domicile).ordreEtages)
```

par :

```swift
                                ordreEtages: places.maison(domicile).ordreEtages, aCote: places.maison(domicile).aCote)
```

Dans `MaillageThread/Vues/Pieces/EntreeScene.swift`, remplacer :

```swift
    /// Ce qui oblige a recalculer la disposition (spec, section 4.3) : les etages, leurs pieces, les
    /// noeuds de chacune et leurs noms. L'ordre des etages seul, ou l'etat d'un noeud, non.
    var cleDisposition: [String: [String: [String]]] {
        var c: [String: [String: [String]]] = [:]
        for e in scene.etages {
            for i in e.pieces {
                let p = scene.pieces[i]
                c[e.id, default: [:]][p.id] = p.noeuds.map { id in
                    [id, libelles[id]?.texte ?? "", libelles[id]?.pastille ?? ""].joined(separator: "|")
                }
            }
```

par :

```swift
    /// Ce qui oblige a recalculer la disposition (spec, section 4.3 ; polissage C, section 4).
    struct CleDisposition: Equatable {
        /// Etage -> piece -> ses noeuds et leurs noms.
        var pieces: [String: [String: [String]]] = [:]
        /// La place de chaque plateau dans la vue de reference du cout : l'etage principal de son niveau, et
        /// son rang dans le niveau.
        var niveaux: [String: String] = [:]
    }

    /// Les etages, leurs pieces, les noeuds de chacune et leurs noms, et les niveaux tels que les voit le cout :
    /// qui partage le niveau de qui, dans quel ordre. L'ordre des niveaux, une zone dans ou hors de la maison,
    /// ou l'etat d'un noeud, non.
    var cleDisposition: CleDisposition {
        var c = CleDisposition()
        for e in scene.etages {
            for i in e.pieces {
                let p = scene.pieces[i]
                c.pieces[e.id, default: [:]][p.id] = p.noeuds.map { id in
                    [id, libelles[id]?.texte ?? "", libelles[id]?.pastille ?? ""].joined(separator: "|")
                }
            }
        }
        for l in scene.niveaux.liste {
            for (k, cle) in l.enumerated() { c.niveaux[cle] = l[0] + "#" + String(k) }
```

Dans `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, remplacer :

```swift
    /// Repere « ailleurs » : « ↗ HomePod Palier · Salon », « ↓ … · Salon, Rez-de-chaussée » si le
    /// parent est a un autre etage (sans la couronne du chef).
    static func ailleurs(_ a: Ailleurs, scene: ScenePieces, libelles: [String: Libelle]) -> String {
        let fleche = switch a.sens {
        case .memeEtage: "↗"
```

par :

```swift
    /// Repere « ailleurs » (polissage C, section 5.2) : « ↗ HomePod Palier · Salon » pour un parent du meme
    /// plateau, « ↗ … · Terrasse, Jardin » pour un parent au meme niveau, dans une autre zone ; « ↓ … · Salon,
    /// Rez-de-chaussee » ou ↑ pour un parent a un autre niveau, avec le nom de son plateau (sans la couronne du
    /// chef).
    static func ailleurs(_ a: Ailleurs, scene: ScenePieces, libelles: [String: Libelle]) -> String {
        let fleche = switch a.sens {
        case .memeNiveau: "↗"
```

Dans `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, remplacer :

```swift
        guard a.sens != .memeEtage else { return "\(fleche) \(parent) · \(piece)" }
```

par :

```swift
        let ici = scene.noeud(a.enfant).map { scene.pieces[$0.piece].etage }
        guard a.etage != ici else { return "\(fleche) \(parent) · \(piece)" }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    @ObservationIgnored private var cleCalculee: [String: [String: [String]]]?
```

par :

```swift
    @ObservationIgnored private var cleCalculee: EntreeScene.CleDisposition?
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
                         cle: [String: [String: [String]]]) {
```

par :

```swift
                         cle: EntreeScene.CleDisposition) {
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/NiveauxTests MaillageCoeurTests/PlacesGardeesTests MaillageCoeurTests/ScenePiecesTests MaillageCoeurTests/SceneProjeteeTests MaillageThreadTests/NomsSceneTests`
Expected: `Test run with 29 tests in 4 suites passed` (cœur) et `Test run with 12 tests in 1 suite passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh`
Expected: `Test run with 356 tests in 37 suites passed` (cœur) et `Test run with 317 tests in 29 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 10 tests et 1 suite de plus pour le cœur, 1 test de plus pour l'app. `NiveauxTests` (sept tests, une suite de plus), `zonesACote`, `niveaux` et `reperesParNiveau` s'ajoutent au cœur ; `repereAuMemeNiveau` à l'app.

- [ ] **Step 6 : les images de démo, inchangées.** L'app, en mode démo seulement, écrit ses images de 1440 × 900 points en 2x dans son conteneur, sans fenêtre, puis quitte ; `open -W` attend qu'elle ait quitté. Elles ne changent pas : la démo n'a encore ni choix de niveau, ni troisième plateau (comparées à celles de `main` à l'écriture du plan : identiques, octet pour octet).

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t1"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polC/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
```

Expected : 14 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`, `13-2d-fiche-du-chef.png`, `14-2d-legende-repliee.png`) ; « l'app a quitté ».

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeurTests/NiveauxTests.swift MaillageCoeurTests/PlacesGardeesTests.swift MaillageCoeurTests/ScenePiecesTests.swift MaillageCoeurTests/SceneProjeteeTests.swift MaillageThreadTests/NomsSceneTests.swift MaillageCoeur/Scene/Niveaux.swift MaillageCoeur/Scene/PlacesGardees.swift MaillageCoeur/Scene/ScenePieces.swift MaillageCoeur/Scene/SceneProjetee.swift MaillageThread/Vues/Pieces/EntreeScene.swift MaillageThread/Vues/Pieces/LibellesNoeuds.swift MaillageThread/Vues/Pieces/MoteurPieces.swift
git commit -m "Poser les niveaux de la maison dans le coeur : les zones a cote d'un etage, gardees dans les places sans changer de version, resolues sur la scene, et les operations du menu qui rendent l'ordre et les choix

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: La géométrie de la maison : la grille 2D et son choix, les zones à côté en 3D, la sphère, les cadrages

**Files:**
- Modify: `MaillageCoeur/Scene/CameraScene.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/CameraSceneTests.swift`

**Interfaces:**
- Consumes :
  - `GeometrieMaison(rayons:)` du plan 4b, `GeometrieMaison.bandeNomsEtages`, `Boite`, `DispositionPieces.centres2D`, `DispositionPieces.esp`, `CameraScene.canonique`, `vue2D`, `vue3D`, `Orbite`, `Vol`, existants ;
  - `ScenePieces.Etage.niveau`, `principal`, `dehors` (tâche 1).
- Produces :
  - `GeometrieMaison.Plateau(niveau:principal:dehors:)` ; `GeometrieMaison(rayons:plateaux:colonnes:)` : `centres2D`, `centres3D`, `colonnes`, `pasEtage`, `centreSphere`, `rayonSphere`, `rayonCadre`, `boite`, `cible2D` ;
  - `GeometrieMaison.grille(_:colonnes:)` (interne) ; `GeometrieMaison.colonnes(rayons:taille:enPlace:) -> Int?` ;
  - `CameraScene.vue3D` sur `rayonCadre` ; `CameraScene.vueEtage(_:etage:aspect:)`, `volVersEtage(_:_:etage:aspect:u:troisD:) -> Vol`.

**La géométrie de la maison** (spec, sections 2 et 3.3) : la grille 2D, remplie depuis le bas, et le choix de ses colonnes, une fonction pure (précisions 5 et 6) ; en 3D, les zones à côté dans la maison, alternées à droite puis à gauche de leur étage, et hors de la maison, autour de l'axe de la sphère ; la sphère qui englobe la maison ; `R_cadre`, qui cadre la vue d'ensemble 3D, les zones dehors comprises. Avec des étages seulement et en rangée, les valeurs d'aujourd'hui, au bit près.

**Les cadrages d'un étage isolé**, en 2D et en 3D (spec 5.1), que la tâche 5 emploie. Le moteur ne fait encore que construire la géométrie avec la rangée : la grille arrive dans la vue à la tâche 4.

**Les images de démo ne changent pas.**

- [ ] **Step 1 : écrire les tests.** La géométrie : avec des étages seulement, celle d'avant ; les zones dans et hors de la maison ; la grille ; le choix des colonnes et l'hystérésis ; le cadrage d'un étage.

Dans `MaillageCoeurTests/CameraSceneTests.swift`, remplacer :

```swift
    /// camera finie : vue d'ensemble, bornes, zoom, envol et vols.
```

par :

```swift
    /// camera finie : vue d'ensemble, bornes, zoom, envol et vols, celui vers un etage compris.
```

Dans `MaillageCoeurTests/CameraSceneTests.swift`, remplacer :

```swift
            for q in [0.0, 0.5, 1.0] {
                #expect(Self.finie(piece.orbite(q, depuis: o)), "vol vers une piece, u = \(u), q = \(q)")
                #expect(Self.finie(ensemble.orbite(q, depuis: o)), "vol vers l'ensemble, u = \(u), q = \(q)")
```

par :

```swift
            let etage = CameraScene.volVersEtage(o, g, etage: 1, aspect: aspect, u: u, troisD: u == 1)
            for q in [0.0, 0.5, 1.0] {
                #expect(Self.finie(piece.orbite(q, depuis: o)), "vol vers une piece, u = \(u), q = \(q)")
                #expect(Self.finie(ensemble.orbite(q, depuis: o)), "vol vers l'ensemble, u = \(u), q = \(q)")
                #expect(Self.finie(etage.orbite(q, depuis: o)), "vol vers un etage, u = \(u), q = \(q)")
```

Dans `MaillageCoeurTests/CameraSceneTests.swift`, remplacer :

```swift
        #expect(g.centrePlateau(0, 0).x == g.centres2D[0])
        #expect(abs(g.boite.z0 - (-16 - 34.0 / 24)) < 1e-12 && g.boite.z1 == 16)
        #expect(GeometrieMaison.hauteurBloc(0) == 0.04 && abs(GeometrieMaison.hauteurBloc(1) - 2.44) < 1e-12)
```

par :

```swift
        #expect(g.centrePlateau(0, 0).x == g.centres2D[0].x)
        #expect(abs(g.boite.z0 - (-16 - 34.0 / 24)) < 1e-12 && g.boite.z1 == 16)
        #expect(GeometrieMaison.hauteurBloc(0) == 0.04 && abs(GeometrieMaison.hauteurBloc(1) - 2.44) < 1e-12)
    }

    /// Avec des etages seulement, en rangee (polissage C, sections 2 et 3.4) : exactement la geometrie du plan 4b,
    /// au bit pres, calculee ici par ses formules ; la vue d'ensemble 3D cadre la sphere.
    @Test(arguments: [[15.2, 16.0], [7.0], [10, 4, 6, 12.5], [9.94, 15.03, 11.39, 15.91, 8.2]])
    func etagesSeulementCommeAvant(_ r: [Double]) {
        let g = GeometrieMaison(rayons: r)
        let x = DispositionPieces.centres2D(rayons: r)
        let rmax = r.max() ?? 1, pas = 1.5 * rmax, yHaut = Double(r.count - 1) * pas
        #expect(g.colonnes == r.count && g.pasEtage == pas)
        #expect(g.centres2D == x.map { SIMD2($0, 0) })
        #expect(g.centres3D == r.indices.map { SIMD3(0, Double($0) * pas, 0) })
        #expect(g.centreSphere == SIMD3(0, (yHaut + GeometrieMaison.hauteurBloc3D) / 2, 0))
        #expect(g.rayonSphere == hypot(rmax + 0.8, (yHaut + GeometrieMaison.hauteurBloc3D) / 2 + 1.4) + 0.4)
        #expect(g.rayonCadre == g.rayonSphere)
        let boite = GeometrieMaison.Boite(x0: x[0] - r[0], x1: x[r.count - 1] + r[r.count - 1],
                                          z0: -rmax - GeometrieMaison.bandeNomsEtages, z1: rmax)
        #expect(g.boite == boite && g.cible2D == SIMD3((boite.x0 + boite.x1) / 2, 0, (boite.z0 + boite.z1) / 2))
        for e in r.indices {
            for u in [0, 0.3, 1.0] {
                let a = SIMD3(x[e], 0, 0), b = SIMD3(0, Double(e) * pas, 0)
                #expect(g.centrePlateau(e, u) == a + (b - a) * u)
            }
        }
        #expect(CameraScene.vue3D(g, aspect: Self.aspect) == 2.4 * g.rayonSphere * max(1, 1 / Self.aspect))
    }

    /// Plateaux de la maison des tests de C : le rez-de-chaussee (10) et ses zones a cote dans la maison (4, 5,
    /// 3), l'etage (12), et des zones hors de la maison au rez-de-chaussee (6, 5) et a l'etage (4, 3, 2).
    static let rayonsC: [Double] = [10, 4, 5, 3, 6, 5, 12, 4, 3, 2]
    static let plateauxC: [GeometrieMaison.Plateau] = [
        .init(niveau: 0), .init(niveau: 0, principal: false), .init(niveau: 0, principal: false),
        .init(niveau: 0, principal: false), .init(niveau: 0, principal: false, dehors: true),
        .init(niveau: 0, principal: false, dehors: true), .init(niveau: 1), .init(niveau: 1, principal: false, dehors: true),
        .init(niveau: 1, principal: false, dehors: true), .init(niveau: 1, principal: false, dehors: true),
    ]

    /// Zones dans la maison (polissage C, section 2) : a la hauteur de leur niveau, z = 0, la premiere a droite
    /// de l'etage principal, la deuxieme a gauche, la troisieme a droite apres la premiere, `esp` entre les bords ;
    /// le pas des niveaux suit le plus grand rayon dans la maison ; la sphere les englobe, centree sur leur boite.
    @Test func zonesDansLaMaison() {
        let g = GeometrieMaison(rayons: Self.rayonsC, plateaux: Self.plateauxC)
        let esp = DispositionPieces.esp
        #expect(g.pasEtage == 18, "1,5 fois 12, les zones hors de la maison n'y comptent pas")
        #expect(g.centres3D[0] == SIMD3(0, 0, 0) && g.centres3D[6] == SIMD3(0, 18, 0))
        #expect(g.centres3D[1] == SIMD3(10 + esp + 4, 0, 0))
        #expect(g.centres3D[2] == SIMD3(-(10 + esp + 5), 0, 0))
        #expect(g.centres3D[3] == SIMD3(10 + esp + 4 + 4 + esp + 3, 0, 0))
        let x0 = -(10 + esp + 5) - 5, x1 = 10 + esp + 4 + 4 + esp + 3 + 3, hh = (18 + GeometrieMaison.hauteurBloc3D) / 2
        #expect(abs(g.centreSphere.x - (x0 + x1) / 2) < 1e-12 && g.centreSphere.y == hh && g.centreSphere.z == 0)
        #expect(abs(g.rayonSphere - (hypot((x1 - x0) / 2 + 0.8, hh + 1.4) + 0.4)) < 1e-12)
        for e in Self.plateauxC.indices where !Self.plateauxC[e].dehors {
            let c = g.centres3D[e], r = Self.rayonsC[e]
            for p in [c + SIMD3(r, 0, 0), c - SIMD3(r, 0, 0), c + SIMD3(0, 0, r), c - SIMD3(0, 0, r),
                      c + SIMD3(r, GeometrieMaison.hauteurBloc3D, 0), c - SIMD3(r, -GeometrieMaison.hauteurBloc3D, 0)] {
                #expect(simd_distance(p, g.centreSphere) < g.rayonSphere, "plateau \(e) dans la sphere")
            }
        }
    }

    /// Zones hors de la maison : a la hauteur de leur niveau, autour de l'axe de la sphere, vers +x, -x, +z, -z,
    /// puis de nouveau +x, plus loin ; hors de la sphere ; le cadrage les couvre (`rayonCadre`), et la vue
    /// d'ensemble 3D les garde dans le cadre sur un tour de rotation lente.
    @Test func zonesHorsDeLaMaison() throws {
        let g = GeometrieMaison(rayons: Self.rayonsC, plateaux: Self.plateauxC)
        let esp = DispositionPieces.esp, c = g.centreSphere, rs = g.rayonSphere
        let attendus: [(Int, SIMD2<Double>, Double)] = [(4, [1, 0], rs + esp + 6), (5, [-1, 0], rs + esp + 5),
                                                        (7, [0, 1], rs + esp + 4), (8, [0, -1], rs + esp + 3),
                                                        (9, [1, 0], rs + esp + 6 + 6 + esp + 2)]
        for (e, d, dist) in attendus {
            let p = g.centres3D[e]
            #expect(abs(p.x - (c.x + d.x * dist)) < 1e-9 && abs(p.z - d.y * dist) < 1e-9, "plateau \(e)")
            #expect(p.y == Double(Self.plateauxC[e].niveau) * g.pasEtage)
            #expect(hypot(p.x - c.x, p.z) - Self.rayonsC[e] > rs, "plateau \(e) hors de la sphere")
        }
        #expect(abs(g.rayonCadre - (rs + esp + 6 + 6 + esp + 2 + 2)) < 1e-9)
        for k in 0..<24 {
            var o = CameraScene.canonique(g, aspect: Self.aspect, u: 1)
            o.azimut += Double(k) / 24 * 2 * .pi
            let proj = ProjectionScene(o, cadre: Self.cadre)
            for e in Self.rayonsC.indices {
                for a in stride(from: 0.0, to: 2 * .pi, by: .pi / 8) {
                    let p = g.centres3D[e] + SIMD3(Self.rayonsC[e] * cos(a), 0, Self.rayonsC[e] * sin(a))
                    let q = try #require(proj.ecran(p))
                    #expect(Self.cadre.contains(q), "plateau \(e), azimut \(k)")
                }
            }
        }
    }

    /// La grille (polissage C, section 3.3) : elle se remplit depuis la rangee du bas, de gauche a droite ; la
    /// rangee du haut, incomplete, est centree ; une colonne a le plus grand diametre de ses plateaux, une rangee
    /// le plus grand des siens plus la bande des noms, `esp` entre les cases ; chaque plateau est centre dans sa
    /// case, bande comprise.
    @Test func grille() {
        let g = GeometrieMaison(rayons: [10, 4, 6, 5, 3], colonnes: 2)
        let esp = DispositionPieces.esp, bande = GeometrieMaison.bandeNomsEtages
        #expect(g.colonnes == 2)
        #expect(abs(g.centres2D[0].x - (-(20 + esp + 10) / 2 + 10)) < 1e-9 && g.centres2D[0].y == 0)
        #expect(abs(g.centres2D[1].x - ((20 + esp + 10) / 2 - 5)) < 1e-9 && g.centres2D[1].y == 0, "en bas, a droite")
        let z1 = -(20.0 / 2 + bande + esp + 12.0 / 2)
        #expect(abs(g.centres2D[2].x - g.centres2D[0].x) < 1e-9 && abs(g.centres2D[2].y - z1) < 1e-9, "au-dessus")
        #expect(abs(g.centres2D[3].x - g.centres2D[1].x) < 1e-9 && abs(g.centres2D[3].y - z1) < 1e-9)
        let z2 = z1 - (12.0 / 2 + bande + esp + 6.0 / 2)
        #expect(abs(g.centres2D[4].x) < 1e-9 && abs(g.centres2D[4].y - z2) < 1e-9, "la rangee du haut, centree")
        #expect(abs(g.boite.x0 + (20 + esp + 10) / 2) < 1e-9 && abs(g.boite.x1 - (20 + esp + 10) / 2) < 1e-9)
        #expect(g.boite.z1 == 10 && abs(g.boite.z0 - (z2 - 3 - bande)) < 1e-9)
    }

    /// Le choix des colonnes (polissage C, section 3.3), sur les rayons de la maison de la maquette de C : 2 x 2
    /// dans une vue carree ou ordinaire (1100 x 760), la rangee dans une vue large (2,4 : 1) ; 3 + 1 en 1440 x 900,
    /// ou 2 x 2 est a plus de 10 % de la plus grande echelle. A moins de 10 %, le moins de cases vides : 2 x 2 avant
    /// 3 + 1 ; puis le moins de rangees : la rangee avant 2 x 2.
    @Test func choixDesColonnes() {
        let r = [15.91, 11.39, 15.03, 9.94]
        #expect(GeometrieMaison.colonnes(rayons: r, taille: CGSize(width: 1100, height: 760)) == 2)
        #expect(GeometrieMaison.colonnes(rayons: r, taille: CGSize(width: 760, height: 760)) == 2)
        #expect(GeometrieMaison.colonnes(rayons: r, taille: CGSize(width: 1824, height: 760)) == 4)
        #expect(GeometrieMaison.colonnes(rayons: r, taille: CGSize(width: 1440, height: 900)) == 3)
        #expect(GeometrieMaison.colonnes(rayons: [12, 12, 12, 12], taille: CGSize(width: 1600, height: 1000)) == 2)
        #expect(GeometrieMaison.colonnes(rayons: [12, 12, 12, 12], taille: CGSize(width: 1900, height: 1000)) == 4)
        #expect(GeometrieMaison.colonnes(rayons: [7], taille: CGSize(width: 800, height: 600)) == 1)
    }

    /// Hysteresis (polissage C, section 3.3) : la grille en place reste tant que son echelle est a moins de 5 % de
    /// celle du choix. Une taille de 1 pt ou moins ne choisit rien : la grille en place, ou rien ; la premiere
    /// vraie taille choisit.
    @Test func hysteresisEtTailleNulle() {
        let r = [12.0, 12, 12, 12]
        // Vers 1,8 : la rangee entre dans les 10 % de 2 x 2 et l'emporte (moins de rangees).
        let pres = CGSize(width: 1820, height: 1000)
        #expect(GeometrieMaison.colonnes(rayons: r, taille: pres) == 4)
        #expect(GeometrieMaison.colonnes(rayons: r, taille: pres, enPlace: 2) == 2, "2 x 2 en place, a moins de 5 %")
        #expect(GeometrieMaison.colonnes(rayons: r, taille: CGSize(width: 2200, height: 1000), enPlace: 2) == 4)
        #expect(GeometrieMaison.colonnes(rayons: r, taille: CGSize(width: 1, height: 600), enPlace: 2) == 2)
        #expect(GeometrieMaison.colonnes(rayons: r, taille: .zero) == nil, "attendre une vraie taille")
        #expect(GeometrieMaison.colonnes(rayons: r, taille: CGSize(width: 1100, height: 760)) == 2)
    }

    /// Cadrage d'un etage isole (polissage C, section 5.1) : en 2D, vue de dessus, la cible au centre de sa boite,
    /// bande du nom comprise, la boite dans le cadre ; en 3D, meme azimut et meme inclinaison, la cible au centre
    /// du plateau, a sa hauteur ; la hauteur de vue max((2 r + bande) 1,1 ; 2 r 1,05 / aspect).
    @Test func cadrageDUnEtage() throws {
        let g = GeometrieMaison(rayons: Self.rayonsC, plateaux: Self.plateauxC, colonnes: 4)
        let bande = GeometrieMaison.bandeNomsEtages
        for e in [0, 4, 6] {
            let r = Self.rayonsC[e], vue = max((2 * r + bande) * 1.1, 2 * r * 1.05 / Self.aspect)
            #expect(CameraScene.vueEtage(g, etage: e, aspect: Self.aspect) == vue)
            let o2 = CameraScene.canonique(g, aspect: Self.aspect, u: 0)
            let v2 = CameraScene.volVersEtage(o2, g, etage: e, aspect: Self.aspect, u: 0, troisD: false).orbite(1, depuis: o2)
            let c = g.centres2D[e]
            #expect(simd_distance(v2.cible, SIMD3(c.x, 0, c.y - bande / 2)) < 1e-9)
            #expect(abs(v2.distance - Orbite.distance(pourHauteur: vue, champ: 2)) < 1e-6 && v2.inclinaison < 1e-3)
            let p = ProjectionScene(v2, cadre: Self.cadre)
            for q in [SIMD3(c.x - r, 0, c.y - r - bande), SIMD3(c.x + r, 0, c.y + r)] {
                #expect(Self.cadre.contains(try #require(p.ecran(q))), "etage \(e) dans le cadre")
            }
            var o3 = CameraScene.canonique(g, aspect: Self.aspect, u: 1)
            o3.azimut += 0.4
            let v3 = CameraScene.volVersEtage(o3, g, etage: e, aspect: Self.aspect, u: 1, troisD: true).orbite(1, depuis: o3)
            #expect(simd_distance(v3.cible, g.centres3D[e]) < 1e-9)
            #expect(abs(v3.azimut - o3.azimut) < 1e-9 && abs(v3.inclinaison - o3.inclinaison) < 1e-9)
            #expect(abs(v3.distance - Orbite.distance(pourHauteur: vue, champ: 40)) < 1e-6)
        }
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/CameraSceneTests`
Expected: la compilation des tests échoue (`CameraSceneTests.swift`), par exemple avec `error: 'Plateau' is not a member type of struct 'MaillageCoeur.GeometrieMaison'` et `error: type 'CameraScene' has no member 'volVersEtage'` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** La géométrie de la maison et les cadrages, puis le moteur (la rangée en attendant la grille).

Dans `MaillageCoeur/Scene/CameraScene.swift`, remplacer :

```swift
/// Geometrie de la maison pour la camera (spec, section 4.4) : plateaux cote a cote en 2D, empiles
/// en 3D, sphere de la maison, boite de cadrage de la 2D.
```

par :

```swift
/// Geometrie de la maison pour la camera (spec de la vue par pieces, section 4.4, remplacee par le polissage C,
/// sections 2 et 3) : les plateaux en 2D, en grille ou en rangee ; en 3D, les niveaux empiles, les zones a cote
/// dans ou hors de la maison ; la sphere de la maison ; le rayon que cadre la vue d'ensemble 3D ; la boite de
/// cadrage de la 2D. Avec des etages seulement et en rangee, les valeurs du plan 4b, au bit pres.
```

Dans `MaillageCoeur/Scene/CameraScene.swift`, remplacer :

```swift
    public let rayons: [Double]
    public let centres2D: [Double]
    /// Pas entre deux etages en 3D : 1,5 fois le plus grand rayon.
    public let pasEtage: Double
    public let centreSphere: SIMD3<Double>
    public let rayonSphere: Double
    public let boite: Boite
    public let cible2D: SIMD3<Double>
```

par :

```swift
    /// La place d'un plateau dans les niveaux (`ScenePieces.Etage`) : son niveau (0 en bas), etage principal ou
    /// zone a cote, hors de la maison.
    public struct Plateau: Hashable, Sendable {
        public var niveau: Int
        public var principal: Bool
        public var dehors: Bool

        public init(niveau: Int, principal: Bool = true, dehors: Bool = false) {
            self.niveau = niveau
            self.principal = principal
            self.dehors = dehors
        }
    }

    public var rayons: [Double]
    /// Centre de chaque plateau en 2D (x, z), et en 3D.
    public var centres2D: [SIMD2<Double>]
    public var centres3D: [SIMD3<Double>]
    /// Colonnes de la grille 2D : de 1 au nombre de plateaux, la rangee.
    public var colonnes: Int
    /// Pas entre deux niveaux en 3D : 1,5 fois le plus grand rayon des plateaux dans la maison.
    public var pasEtage: Double
    public var centreSphere: SIMD3<Double>
    public var rayonSphere: Double
    /// Le rayon que cadre la vue d'ensemble 3D : le plus grand de la sphere et des distances a son axe des
    /// bords exterieurs des zones hors de la maison.
    public var rayonCadre: Double
    public var boite: Boite
```

Dans `MaillageCoeur/Scene/CameraScene.swift`, remplacer :

```swift
    public init(rayons: [Double]) {
        let r = rayons.isEmpty ? [DispositionPieces.marge] : rayons
        self.rayons = r
        centres2D = DispositionPieces.centres2D(rayons: r)
        let rmax = r.max() ?? 1
        pasEtage = 1.5 * rmax
        let yHaut = Double(r.count - 1) * pasEtage
        centreSphere = SIMD3(0, (yHaut + Self.hauteurBloc3D) / 2, 0)
        rayonSphere = hypot(rmax + 0.8, (yHaut + Self.hauteurBloc3D) / 2 + 1.4) + 0.4
        boite = Boite(x0: centres2D[0] - r[0], x1: centres2D[r.count - 1] + r[r.count - 1],
                      z0: -rmax - Self.bandeNomsEtages, z1: rmax)
        cible2D = SIMD3((boite.x0 + boite.x1) / 2, 0, (boite.z0 + boite.z1) / 2)
```

par :

```swift
    /// Le centre de la boite de cadrage de la 2D.
    public var cible2D: SIMD3<Double> { SIMD3((boite.x0 + boite.x1) / 2, 0, (boite.z0 + boite.z1) / 2) }

    /// `rayons` : ceux des plateaux, dans l'ordre de la scene (niveau par niveau) ; `plateaux` : leur place dans
    /// les niveaux (nil : un etage par plateau) ; `colonnes` : celles de la grille 2D (nil : la rangee).
    public init(rayons: [Double], plateaux: [Plateau]? = nil, colonnes: Int? = nil) {
        let r = rayons.isEmpty ? [DispositionPieces.marge] : rayons
        let p = plateaux.flatMap { $0.count == r.count ? $0 : nil } ?? r.indices.map { Plateau(niveau: $0) }
        self.rayons = r
        self.colonnes = max(1, min(r.count, colonnes ?? r.count))
        (centres2D, boite) = Self.grille(r, colonnes: self.colonnes)
        // La pile : les etages sur l'axe, au pas de 1,5 fois le plus grand rayon dans la maison.
        let dans = r.indices.filter { !p[$0].dehors }
        let rmax = dans.map { r[$0] }.max() ?? 1
        let pas = 1.5 * rmax
        let niveaux = (p.map(\.niveau).max() ?? 0) + 1
        let hh = (Double(niveaux - 1) * pas + Self.hauteurBloc3D) / 2
        var c3 = r.indices.map { SIMD3(0, Double(p[$0].niveau) * pas, 0) }
        // Les zones a cote dans la maison : la premiere a droite (+x) de l'etage principal, la deuxieme a
        // gauche (-x), puis en alternant, de plus en plus loin, `esp` entre les bords.
        for n in 0..<niveaux {
            guard let e0 = r.indices.first(where: { p[$0].niveau == n && p[$0].principal }) else { continue }
            var bord = [r[e0], r[e0]]
            for (k, e) in r.indices.filter({ p[$0].niveau == n && !p[$0].principal && !p[$0].dehors }).enumerated() {
                let cote = k % 2, x = bord[cote] + DispositionPieces.esp + r[e]
                c3[e].x = cote == 0 ? x : -x
                bord[cote] = x + r[e]
            }
        }
        // La sphere englobe les plateaux dans la maison.
        let x0 = dans.map { c3[$0].x - r[$0] }.min() ?? -1, x1 = dans.map { c3[$0].x + r[$0] }.max() ?? 1
        let centre = SIMD3((x0 + x1) / 2, hh, 0), rs = hypot((x1 - x0) / 2 + 0.8, hh + 1.4) + 0.4
        // Hors de la maison : autour de l'axe de la sphere, vers +x, -x, +z, -z, puis de nouveau, la premiere a
        // R + esp + r de l'axe, mesure a plat, la suivante plus loin, `esp` entre les bords.
        let directions: [SIMD2<Double>] = [[1, 0], [-1, 0], [0, 1], [0, -1]]
        var loin = [Double](repeating: rs, count: 4)
        var cadre = rs
        for (k, e) in r.indices.filter({ p[$0].dehors }).enumerated() {
            let d = k % 4, dist = loin[d] + DispositionPieces.esp + r[e]
            c3[e].x = centre.x + directions[d].x * dist
            c3[e].z = directions[d].y * dist
            loin[d] = dist + r[e]
            cadre = max(cadre, loin[d])
        }
        pasEtage = pas
        centres3D = c3
        centreSphere = centre
        rayonSphere = rs
        rayonCadre = cadre
    }

    /// La grille 2D (polissage C, section 3.3) : elle se remplit depuis la rangee du bas (vers +z), de gauche a
    /// droite ; la rangee du haut, incomplete, est centree. Une colonne a la largeur du plus grand diametre de ses
    /// plateaux ; une rangee, la hauteur du plus grand des siens, plus la bande des noms d'etage, au-dessus ;
    /// `esp` entre les cases ; chaque plateau est centre dans sa case, bande comprise. La rangee du bas est en
    /// z = 0, et une rangee est centree sur x = 0 comme la rangee du plan 4b (`DispositionPieces.centres2D`).
    static func grille(_ r: [Double], colonnes c: Int) -> (centres: [SIMD2<Double>], boite: Boite) {
        let rangees = stride(from: 0, to: r.count, by: c).map { Array($0..<min($0 + c, r.count)) }
        let d = r.map { 2 * $0 }
        let larg = (0..<c).map { k in rangees.map { k < $0.count ? d[$0[k]] : 0 }.max() ?? 0 }
        let dmax = rangees.map { $0.map { d[$0] }.max() ?? 0 }
        var centres = [SIMD2<Double>](repeating: .zero, count: r.count)
        var z = 0.0, x0 = Double.infinity, x1 = -Double.infinity
        for (i, rangee) in rangees.enumerated() {
            if i > 0 { z = z - dmax[i - 1] / 2 - bandeNomsEtages - DispositionPieces.esp - dmax[i] / 2 }
            let x = DispositionPieces.centres2D(rayons: rangee.indices.map { larg[$0] / 2 })
            for (k, e) in rangee.enumerated() { centres[e] = SIMD2(x[k], z) }
            x0 = min(x0, x[0] - larg[0] / 2)
            x1 = max(x1, x[rangee.count - 1] + larg[rangee.count - 1] / 2)
        }
        return (centres, Boite(x0: x0, x1: x1, z0: z - dmax[rangees.count - 1] / 2 - bandeNomsEtages, z1: dmax[0] / 2))
    }

    /// Le nombre de colonnes de la grille (polissage C, section 3.3) pour une vue de `taille` points. L'echelle
    /// d'une grille est min(largeur / sa largeur, hauteur / sa hauteur) ; parmi les grilles a moins de 10 % de la
    /// plus grande echelle, celle qui a le moins de cases vides, puis le moins de rangees. `enPlace` : la grille en
    /// place, qui reste tant que son echelle est a moins de 5 % de celle du choix (au redimensionnement). Une
    /// taille de 1 pt ou moins ne choisit rien : la grille en place, ou nil, attendre une vraie taille.
    public static func colonnes(rayons: [Double], taille: CGSize, enPlace: Int? = nil) -> Int? {
        let n = rayons.count
        guard n > 0, taille.width > 1, taille.height > 1 else { return enPlace }
        let candidats = (1...n).map { c -> (c: Int, echelle: Double, vides: Int, rangees: Int) in
            let b = grille(rayons, colonnes: c).boite
            let rangees = (n + c - 1) / c
            return (c, min(Double(taille.width) / (b.x1 - b.x0), Double(taille.height) / (b.z1 - b.z0)),
                    c * rangees - n, rangees)
        }
        let meilleure = candidats.map(\.echelle).max() ?? 0
        guard let choix = candidats.filter({ $0.echelle >= 0.9 * meilleure })
            .min(by: { ($0.vides, $0.rangees) < ($1.vides, $1.rangees) }) else { return enPlace }
        if let e = enPlace, let g = candidats.first(where: { $0.c == e }), g.echelle >= 0.95 * choix.echelle { return e }
        return choix.c
```

Dans `MaillageCoeur/Scene/CameraScene.swift`, remplacer :

```swift
        let a = SIMD3(centres2D[e], 0, 0), b = SIMD3(0, Double(e) * pasEtage, 0)
```

par :

```swift
        let a = SIMD3(centres2D[e].x, 0, centres2D[e].y), b = centres3D[e]
```

Dans `MaillageCoeur/Scene/CameraScene.swift`, remplacer :

```swift
    /// Hauteur de vue de la vue d'ensemble 3D, centree sur la sphere.
    public static func vue3D(_ g: GeometrieMaison, aspect: Double) -> Double {
        let aspect = aspectSur(aspect)
        return 2.4 * g.rayonSphere * max(1, 1 / aspect)
```

par :

```swift
    /// Hauteur de vue de la vue d'ensemble 3D, centree sur la sphere : elle cadre la sphere et les zones hors de
    /// la maison (polissage C, section 2).
    public static func vue3D(_ g: GeometrieMaison, aspect: Double) -> Double {
        let aspect = aspectSur(aspect)
        return 2.4 * g.rayonCadre * max(1, 1 / aspect)
```

Dans `MaillageCoeur/Scene/CameraScene.swift`, remplacer :

```swift
    /// Vol de retour a la vue d'ensemble, a l'avancement u de la bascule.
```

par :

```swift
    /// Hauteur de vue d'un etage isole (polissage C, section 5.1), bande de son nom comprise :
    /// max((2 r + bande) 1,1 ; 2 r 1,05 / aspect).
    public static func vueEtage(_ g: GeometrieMaison, etage e: Int, aspect: Double) -> Double {
        let aspect = aspectSur(aspect), r = g.rayons[e]
        return max((2 * r + GeometrieMaison.bandeNomsEtages) * 1.1, 2 * r * 1.05 / aspect)
    }

    /// Vol vers un etage isole, a l'avancement u de la bascule (polissage C, section 5.1) : en 2D, vue de dessus,
    /// la cible au centre de sa boite, bande du nom comprise ; en 3D, meme azimut et meme inclinaison, la cible
    /// au centre du plateau, a sa hauteur.
    public static func volVersEtage(_ o: Orbite, _ g: GeometrieMaison, etage e: Int, aspect: Double, u: Double,
                                    troisD: Bool) -> Vol {
        var c = g.centrePlateau(e, u)
        if !troisD { c.z -= GeometrieMaison.bandeNomsEtages / 2 }
        let d = Orbite.distance(pourHauteur: vueEtage(g, etage: e, aspect: aspect), champ: o.champ)
        return Vol(depuis: o, oeil: c + directionVue(o, troisD: troisD) * d, cible: c)
    }

    /// Vol de retour a la vue d'ensemble, a l'avancement u de la bascule.
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        geometrie = GeometrieMaison(rayons: scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge })
```

par :

```swift
        geometrie = GeometrieMaison(rayons: scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge },
                                    plateaux: scene.etages.map {
                                        GeometrieMaison.Plateau(niveau: $0.niveau, principal: $0.principal, dehors: $0.dehors)
                                    })
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/CameraSceneTests`
Expected: `Test run with 16 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh`
Expected: `Test run with 363 tests in 37 suites passed` (cœur) et `Test run with 317 tests in 29 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 7 tests de plus pour le cœur, l'app inchangée. Les sept tests de la géométrie s'ajoutent au cœur.

- [ ] **Step 6 : les images de démo, identiques.** Avec des étages seulement, la géométrie est celle d'avant, au bit près : chaque image est identique, octet pour octet, à celle de la tâche 1.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t2"
R="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t1"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polC/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
n=0; for f in "$R"/*.png; do cmp -s "$f" "$D/$(basename "$f")" && n=$((n+1)) || echo "différente : $(basename "$f")"; done; echo "$n identiques sur $(ls "$R" | wc -l | tr -d ' ')"
```

Expected : 14 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`, `13-2d-fiche-du-chef.png`, `14-2d-legende-repliee.png`) ; « l'app a quitté » ; « 14 identiques sur 14 ». Si une image diffère, s'arrêter : la tâche a changé le rendu.

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeurTests/CameraSceneTests.swift MaillageCoeur/Scene/CameraScene.swift MaillageThread/Vues/Pieces/MoteurPieces.swift
git commit -m "Placer les plateaux par niveaux dans la geometrie de la maison : la grille 2D et son choix de colonnes, les zones a cote dans ou hors de la maison en 3D, la sphere qui englobe la maison, le cadrage de la vue d'ensemble et d'un etage isole

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Le coût de la disposition sur la vue de référence des niveaux

**Files:**
- Modify: `MaillageCoeur/Scene/DispositionPieces.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/DispositionPiecesTests.swift`, `MaillageCoeurTests/MaisonInventee.swift`, `MaillageThreadTests/MoteurPiecesTests.swift`

**Interfaces:**
- Consumes :
  - `DispositionPieces.Calcul` (`cout`, `traversees`, la carte, les liens), `ScenePieces.Etage.niveau` (tâche 1), existants ;
  - dans les tests : `MaisonInventee`, `MoteurPiecesTests.pointDePiece`, existants.
- Produces :
  - `DispositionPieces.Calcul.vueReference(_:)`, à la place de `vue2D` ; le coût des niveaux (précision 8) ;
  - `MaisonInventee.scene(pieces:appareils:routeurs:unSeulPlateau:)` (tests) ; `MoteurPiecesTests.pointDePiece`, qui cherche un point libre de la pièce, où un clic l'isole et un glisser la prend.

**La disposition des pièces ne dépend plus de la fenêtre** (spec, section 4) : son coût se prend sur une vue de référence, la maison vue de dessus niveau par niveau, et non plus sur la rangée 2D (précision 8). Pour une maison d'un seul plateau, le coût du plan 4b, au bit près ; les tests de la section 10 de la spec de la vue par pièces restent verts.

**Les images de démo changent toutes** : le coût place autrement les pièces des deux étages de la démo. Les pièces que Djoko n'a pas déplacées peuvent changer de place une fois, à la première ouverture après C (spec 4) ; celles qu'il a déplacées ne bougent pas.

- [ ] **Step 1 : écrire les tests.** Le coût d'un seul plateau ; la vue de référence ; une maison inventée d'un seul plateau ; un point de pièce plus sûr dans les tests du moteur.

Dans `MaillageCoeurTests/DispositionPiecesTests.swift`, remplacer :

```swift
import Testing
```

par :

```swift
import simd
import Testing
```

Dans `MaillageCoeurTests/DispositionPiecesTests.swift`, remplacer :

```swift
    /// Longueur traversee (Liang-Barsky) et croisements stricts.
```

par :

```swift
    /// Le cout du plan 4b, recopie tel qu'il etait : la vue 2D des etages cote a cote (`centres2D`), tous les
    /// liens, toutes les cartes, tous les croisements.
    static func coutDuPlan4b(_ k: DispositionPieces.Calcul, _ pos: [SIMD2<Double>]) -> Double {
        let rayons = (0..<k.nbEtages).map { k.rayon(pos, $0) }
        let cx = DispositionPieces.centres2D(rayons: rayons)
        let rects = pos.indices.map { i in
            let x = cx[k.etage[i]] + pos[i].x, z = pos[i].y
            return DispositionPieces.Rect(x0: x - k.w[i] / 2, x1: x + k.w[i] / 2, z0: z - k.d[i] / 2 - DispositionPieces.lab,
                                          z1: z + k.d[i] / 2)
        }
        let segments = k.liens.map { l in
            (SIMD2(cx[k.etage[l.pa]], 0) + pos[l.pa] + l.la, SIMD2(cx[k.etage[l.pb]], 0) + pos[l.pb] + l.lb)
        }
        var c = rayons.reduce(0, +)
        for (n, l) in k.liens.enumerated() {
            let (p, q) = segments[n]
            let dl = q - p
            c += 0.3 * (dl.x * dl.x + dl.y * dl.y).squareRoot()
            for (r, rect) in rects.enumerated() where r != l.pa && r != l.pb {
                let t = DispositionPieces.dedans(p, q, rect)
                if t > 0 { c += 6 + 4 * t }
            }
            if k.etage[l.pa] != k.etage[l.pb] {
                let h = (pos[l.pa] + l.la) - (pos[l.pb] + l.lb)
                c += 0.1 * (h.x * h.x + h.y * h.y).squareRoot()
            }
        }
        for i in k.liens.indices {
            let s = k.liens[i], (p, q) = segments[i]
            for j in k.liens.indices where j > i {
                let t = k.liens[j]
                if s.na == t.na || s.na == t.nb || s.nb == t.na || s.nb == t.nb { continue }
                let (r, u) = segments[j]
                if max(p.x, q.x) < min(r.x, u.x) || max(r.x, u.x) < min(p.x, q.x)
                    || max(p.y, q.y) < min(r.y, u.y) || max(r.y, u.y) < min(p.y, q.y) { continue }
                if DispositionPieces.croise(p, q, r, u) { c += 5 }
            }
        }
        return c
    }

    /// Pour une maison d'un seul plateau, le cout de reference (polissage C, section 4) est celui du plan 4b, au
    /// bit pres : au depart de chaque essai, et sur la disposition retenue, qui est donc la meme.
    @Test func coutDUnSeulPlateau() {
        let (s, c) = MaisonInventee.scene(pieces: 8, appareils: 30, routeurs: 4, unSeulPlateau: true)
        #expect(s.etages.count == 1)
        let k = DispositionPieces.Calcul(scene: s, cartes: c, fixees: [:])
        let d = DispositionPieces(scene: s, cartes: c)
        for pos in (0..<DispositionPieces.departs).map({ k.depart($0, fixees: [:]) }) + [d.positions] {
            #expect(k.cout(pos) == Self.coutDuPlan4b(k, pos))
        }
        #expect(d.cout == Self.coutDuPlan4b(k, d.positions))
    }

    /// La vue de reference du cout (polissage C, section 4) : chaque niveau est une rangee, son etage principal en
    /// x = 0, ses zones a cote a droite, `esp` entre les bords. Un lien entre deux niveaux ne coute que 0,1 fois
    /// son ecart horizontal : ni longueur, ni carte traversee, ni croisement ; un lien du meme niveau, entre un
    /// etage et sa zone a cote, coute sa longueur dans cette vue.
    @Test func vueDeReference() throws {
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre", "E000000000000002": "Terrasse",
                      "E000000000000003": "Terrasse", "E000000000000004": "Salon", "E000000000000005": "Salon"]
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre"]),
                     ZoneMaison(nom: "Jardin", pieces: ["Terrasse"])]
        let s = ScenePieces(graphe: try ScenePiecesTests.graphe(sonde: true), libelles: ScenePiecesTests.libelles,
                            piecesNoeuds: pieces, zones: zones, chefs: ["Apple TV"], piecesMaison: true,
                            aCote: ["zone:Jardin": PlacesGardees.ACote(etage: "zone:Rez-de-chaussée", dehors: true)])
        #expect(s.etages.map(\.id) == ["zone:Rez-de-chaussée", "zone:Jardin", "zone:Étage"])
        let c = CartesPieces.cartes(s, largeurs: [:])
        let k = DispositionPieces.Calcul(scene: s, cartes: c, fixees: [:])
        let d = DispositionPieces(scene: s, cartes: c)
        let v = k.vueReference(d.positions)
        let terrasse = try #require(s.pieces.firstIndex { $0.nom == .maison("Terrasse") })
        let chambre = try #require(s.pieces.firstIndex { $0.nom == .maison("Chambre") })
        let cx = d.rayons[0] + DispositionPieces.esp + d.rayons[1]
        #expect(abs(v.rects[terrasse].x0 - (cx + d.positions[terrasse].x - c[terrasse].largeur / 2)) < 1e-12)
        #expect(abs(v.rects[chambre].x0 - (d.positions[chambre].x - c[chambre].largeur / 2)) < 1e-12, "l'etage, en x = 0")
        var attendu = v.rayons.reduce(0, +)
        for (n, l) in k.liens.enumerated() {
            let (p, q) = v.segments[n]
            if k.niveau[l.pa] == k.niveau[l.pb] {
                attendu += 0.3 * simd_length(q - p)
                for (r, rect) in v.rects.enumerated() where r != l.pa && r != l.pb && k.niveau[r] == k.niveau[l.pa] {
                    let t = DispositionPieces.dedans(p, q, rect)
                    if t > 0 { attendu += 6 + 4 * t }
                }
            } else {
                attendu += 0.1 * simd_length(p - q)
            }
        }
        #expect(abs(k.cout(d.positions) - attendu) < 1e-9, "aucun croisement dans cette petite maison")
        #expect(k.traversees(d.positions) == 0)
    }

    /// Longueur traversee (Liang-Barsky) et croisements stricts.
```

Dans `MaillageCoeurTests/MaisonInventee.swift`, remplacer :

```swift
/// Maison inventee pour les tests de la scene : `pieces` pieces reparties sur deux etages,
```

par :

```swift
/// Maison inventee pour les tests de la scene : `pieces` pieces reparties sur deux etages (ou sur un seul
/// plateau, `unSeulPlateau`),
```

Dans `MaillageCoeurTests/MaisonInventee.swift`, remplacer :

```swift
    static func scene(pieces: Int, appareils: Int, routeurs: Int) -> (scene: ScenePieces, cartes: [CartesPieces.Carte]) {
```

par :

```swift
    static func scene(pieces: Int, appareils: Int, routeurs: Int,
                      unSeulPlateau: Bool = false) -> (scene: ScenePieces, cartes: [CartesPieces.Carte]) {
```

Dans `MaillageCoeurTests/MaisonInventee.swift`, remplacer :

```swift
                            zones: [ZoneMaison(nom: "Bas", pieces: bas), ZoneMaison(nom: "Haut", pieces: haut)],
```

par :

```swift
                            zones: unSeulPlateau ? nil : [ZoneMaison(nom: "Bas", pieces: bas), ZoneMaison(nom: "Haut", pieces: haut)],
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
    /// Un point d'une piece, hors de ses pastilles et des noms : pres du coin bas droit de son dessus.
    static func pointDePiece(_ m: MoteurPieces, _ i: Int) throws -> CGPoint {
        let a = try #require(m.projetee?.ancresPieces[i])
        return CGPoint(x: a.maxX - 3, y: a.maxY - 3)
```

par :

```swift
    /// Un point d'une piece, hors de ses pastilles et des noms : pres du coin bas droit de son dessus, ou, si un
    /// nom ou une pastille l'y couvre, le plus proche de ce coin ou un clic l'isole et ou un glisser la prend.
    static func pointDePiece(_ m: MoteurPieces, _ i: Int) throws -> CGPoint {
        let a = try #require(m.projetee?.ancresPieces[i])
        let coin = CGPoint(x: a.maxX - 3, y: a.maxY - 3)
        let points = [coin] + stride(from: 0.95, through: 0.05, by: -0.05).flatMap { fy in
            stride(from: 0.95, through: 0.05, by: -0.05).map { fx in CGPoint(x: a.minX + a.width * fx, y: a.minY + a.height * fy) }
        }
        return try #require(points.first { p in
            m.noeudSous(p) == nil && m.pieceSous(p) == i && m.projetee?.piece(sous: p) == i
        })
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/DispositionPiecesTests MaillageThreadTests/MoteurPiecesTests`
Expected: la compilation des tests échoue (`DispositionPiecesTests.swift`), par exemple avec `error: value of type 'DispositionPieces.Calcul' has no member 'vueReference'` et `error: value of type 'DispositionPieces.Calcul' has no member 'niveau'` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** Le coût de la disposition.

Dans `MaillageCoeur/Scene/DispositionPieces.swift`, remplacer :

```swift
/// fraction de seconde.
```

par :

```swift
/// fraction de seconde. Depuis le polissage C (section 4), son cout voit la maison de dessus, niveau par
/// niveau : elle ne depend ni de la fenetre, ni de la disposition 2D des plateaux (grille ou rangee).
```

Dans `MaillageCoeur/Scene/DispositionPieces.swift`, remplacer :

```swift
        /// Pieces de chaque etage, par aire decroissante.
```

par :

```swift
        /// Niveau de chaque plateau, et de chaque piece (polissage C, section 1).
        let niveauEtage: [Int]
        let niveau: [Int]
        /// Pieces de chaque etage, par aire decroissante.
```

Dans `MaillageCoeur/Scene/DispositionPieces.swift`, remplacer :

```swift
            fixe = (0..<n).map { fixees[$0] != nil }
```

par :

```swift
            niveauEtage = scene.etages.map(\.niveau)
            niveau = scene.pieces.map { scene.etages[$0.etage].niveau }
            fixe = (0..<n).map { fixees[$0] != nil }
```

Dans `MaillageCoeur/Scene/DispositionPieces.swift`, remplacer :

```swift
        /// Rectangles des cartes et extremites des liens dans la vue 2D des etages cote a cote.
        func vue2D(_ pos: [SIMD2<Double>]) -> (rayons: [Double], rects: [Rect], segments: [(SIMD2<Double>, SIMD2<Double>)]) {
            let rayons = (0..<nbEtages).map { rayon(pos, $0) }
            let cx = DispositionPieces.centres2D(rayons: rayons)
```

par :

```swift
        /// Rectangles des cartes et extremites des liens dans la vue de reference du cout (polissage C, section 4) :
        /// la maison vue de dessus, niveau par niveau. Chaque niveau est une rangee : son etage principal en x = 0,
        /// puis ses zones a cote, a sa droite, `esp` entre les bords ; les niveaux sont superposes. Les plateaux d'un
        /// niveau se suivent dans la scene, l'etage principal d'abord.
        func vueReference(_ pos: [SIMD2<Double>]) -> (rayons: [Double], rects: [Rect], segments: [(SIMD2<Double>, SIMD2<Double>)]) {
            let rayons = (0..<nbEtages).map { rayon(pos, $0) }
            var cx = [Double](repeating: 0, count: nbEtages)
            for e in cx.indices.dropFirst() where niveauEtage[e] == niveauEtage[e - 1] {
                cx[e] = cx[e - 1] + rayons[e - 1] + DispositionPieces.esp + rayons[e]
            }
```

Dans `MaillageCoeur/Scene/DispositionPieces.swift`, remplacer :

```swift
        /// Cout d'une disposition, vue en 2D : la somme des rayons des plateaux ; 0,3 fois la longueur
        /// de chaque lien ; 6 + 4 fois la longueur traversee pour chaque lien qui passe sur une carte
        /// autre que celles de ses bouts ; 5 par croisement de deux liens sans bout commun ; 0,1 fois
        /// l'ecart horizontal de chaque lien entre etages, une fois les etages empiles.
        func cout(_ pos: [SIMD2<Double>]) -> Double {
            let v = vue2D(pos)
            var c = v.rayons.reduce(0, +)
            for (k, l) in liens.enumerated() {
                let (p, q) = v.segments[k]
                let dl = q - p
                c += 0.3 * (dl.x * dl.x + dl.y * dl.y).squareRoot()
                for (r, rect) in v.rects.enumerated() where r != l.pa && r != l.pb {
                    let t = DispositionPieces.dedans(p, q, rect)
                    if t > 0 { c += 6 + 4 * t }
                }
                if etage[l.pa] != etage[l.pb] {
                    let h = (pos[l.pa] + l.la) - (pos[l.pb] + l.lb)
                    c += 0.1 * (h.x * h.x + h.y * h.y).squareRoot()
                }
            }
            for i in liens.indices {
                let s = liens[i], (p, q) = v.segments[i]
                for j in liens.indices where j > i {
                    let t = liens[j]
```

par :

```swift
        /// Cout d'une disposition, dans la vue de reference (polissage C, section 4) : la somme des rayons des
        /// plateaux ; pour chaque lien dont les deux bouts sont au meme niveau, 0,3 fois sa longueur, et 6 + 4 fois
        /// la longueur traversee pour chaque carte de ce niveau autre que celles de ses bouts qu'il traverse ; 5 par
        /// croisement de deux liens du meme niveau sans bout commun ; pour chaque lien entre deux niveaux, 0,1 fois
        /// son ecart horizontal. Pour une maison d'un seul plateau, le cout du plan 4b, au bit pres.
        func cout(_ pos: [SIMD2<Double>]) -> Double {
            let v = vueReference(pos)
            var c = v.rayons.reduce(0, +)
            for (k, l) in liens.enumerated() {
                let (p, q) = v.segments[k]
                guard niveau[l.pa] == niveau[l.pb] else {
                    let h = p - q
                    c += 0.1 * (h.x * h.x + h.y * h.y).squareRoot()
                    continue
                }
                let dl = q - p
                c += 0.3 * (dl.x * dl.x + dl.y * dl.y).squareRoot()
                for (r, rect) in v.rects.enumerated() where r != l.pa && r != l.pb && niveau[r] == niveau[l.pa] {
                    let t = DispositionPieces.dedans(p, q, rect)
                    if t > 0 { c += 6 + 4 * t }
                }
            }
            for i in liens.indices where niveau[liens[i].pa] == niveau[liens[i].pb] {
                let s = liens[i], (p, q) = v.segments[i]
                for j in liens.indices where j > i {
                    let t = liens[j]
                    if niveau[t.pa] != niveau[s.pa] || niveau[t.pb] != niveau[s.pa] { continue }
```

Dans `MaillageCoeur/Scene/DispositionPieces.swift`, remplacer :

```swift
        /// Liens qui passent sur une carte autre que celles de leurs bouts (tests).
        func traversees(_ pos: [SIMD2<Double>]) -> Int {
            let v = vue2D(pos)
            var n = 0
            for (k, l) in liens.enumerated() {
                let (p, q) = v.segments[k]
                for (r, rect) in v.rects.enumerated() where r != l.pa && r != l.pb
```

par :

```swift
        /// Liens d'un niveau qui passent sur une carte de ce niveau autre que celles de leurs bouts, dans la vue
        /// de reference (tests).
        func traversees(_ pos: [SIMD2<Double>]) -> Int {
            let v = vueReference(pos)
            var n = 0
            for (k, l) in liens.enumerated() where niveau[l.pa] == niveau[l.pb] {
                let (p, q) = v.segments[k]
                for (r, rect) in v.rects.enumerated() where r != l.pa && r != l.pb && niveau[r] == niveau[l.pa]
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/DispositionPiecesTests MaillageThreadTests/MoteurPiecesTests`
Expected: `Test run with 14 tests in 1 suite passed` (cœur) et `Test run with 25 tests in 1 suite passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh`
Expected: `Test run with 365 tests in 37 suites passed` (cœur) et `Test run with 317 tests in 29 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 2 tests de plus pour le cœur, l'app inchangée. `coutDUnSeulPlateau` et `vueDeReference` s'ajoutent au cœur.

- [ ] **Step 6 : les images de démo, avec la disposition nouvelle.** Elles changent toutes : les pièces prennent d'autres places.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t3"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polC/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
```

Expected : 14 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`, `13-2d-fiche-du-chef.png`, `14-2d-legende-repliee.png`) ; « l'app a quitté ».

Regarder `01-2d.png` et `05-3d.png` (outil Read) : les pièces des deux étages ont changé de place ; aucune ne déborde de son plateau.

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeurTests/DispositionPiecesTests.swift MaillageCoeurTests/MaisonInventee.swift MaillageThreadTests/MoteurPiecesTests.swift MaillageCoeur/Scene/DispositionPieces.swift
git commit -m "Calculer le cout de la disposition des pieces sur la vue de reference des niveaux, independante de la fenetre et de la disposition 2D, et garder le cout du plan 4b pour une maison d'un seul plateau

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: La grille dans la vue : sur sa zone visible, le réglage « Étages en 2D », les glissements, l'attente de la vue d'ensemble

**Files:**
- Modify: `MaillageCoeur/Scene/CameraScene.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift`, `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/FenetreReglages.swift` (blocs ci-dessous)
- Modify (par les outils) : `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json`
- Test: `MaillageThreadTests/MoteurPiecesTests.swift`, `MaillageThreadTests/FenetrePiecesTests.swift`

**Interfaces:**
- Consumes :
  - `GeometrieMaison(rayons:plateaux:colonnes:)`, `GeometrieMaison.colonnes(rayons:taille:enPlace:)` (tâche 2) ; `MoteurPieces` (`installer`, `poserTaille`, `basculer(troisD:)`, `recadrer`, `reduire`, `fige`, `vueTouchee`, `envol`, `vol`, `marges`), `CameraScene.dureeEnvol`, `rampe`, `FenetrePieces.margeBas(pile:)`, `LegendePieces.cleRepliee`, existants ;
  - dans les tests : `NomsSceneTests.demo()`, `MoteurPiecesTests.moteur`, `dessiner`, `taille`, `FenetrePiecesTests.fenetre`, `SondeMaillageTests.preferences()`, existants.
- Produces :
  - `GeometrieMaison.vers(_:k2:k3:)` ; `CameraScene.dureeCases` (0,4 s), `dureeNiveaux` (0,9 s) ;
  - `MoteurPieces.geometrieVisee`, `glissementPlateaux` (`GlissementPlateaux`), `geometrie(a:)`, `grille`, `colonnes`, `grilleEnAttente` (`GrilleEnAttente`), `reglerGrille(_:)`, `aLaVueDEnsemble` ; `MoteurPieces.basGrille`, `zoneVisible` ;
  - `FenetrePieces.cleGrille` = `etagesEnGrille` ; `FenetrePieces.margeBasGrille(fiche:repliee:legende:legendeOuverte:) -> CGFloat` ; `VuePieces(…, basGrille:)` ; la section « Vue par pièces » de Réglages › Général ;
  - `MoteurPiecesTests.quatrePlateaux(_:)`, `large`, `carree`, `moteur(_:fichier:taille:)` (tests) ;
  - le catalogue : 4 textes nouveaux.

**La grille dans la vue** (spec, sections 3.1, 3.3 et 3.5) : le moteur choisit les colonnes sur la zone visible de la vue, la légende ouverte ou repliée, sans la fiche (précision 7 ; décision de Djoko du 03/10), pose la géométrie visée, et fait glisser les plateaux vers elle : 0,4 s au redimensionnement et quand la légende s'ouvre ou se replie, 2,6 s au changement du réglage, et après un changement de niveau 0,4 s en 2D ou 0,9 s en 3D (précision 9). Zoomée, isolée ou en 3D, la grille attend la vue d'ensemble 2D (précision 10). Le réglage « Étages en 2D » arrive dans Réglages › Général (précision 11).

**Les images de démo ne changent pas** : avec deux étages, la grille de la démo est la rangée.

- [ ] **Step 1 : écrire les tests.** La démo sur quatre plateaux ; la grille selon la zone visible, une vue carrée, la légende et la fiche, le redimensionnement, l'attente, le réglage, la première vraie taille, le glissement après un changement de niveau ; la marge du bas de la grille ; le réglage dans la vraie fenêtre.

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
    static func moteur(_ e: EntreeScene, fichier: URL? = nil) -> MoteurPieces {
```

par :

```swift
    static func moteur(_ e: EntreeScene, fichier: URL? = nil, taille: CGSize = MoteurPiecesTests.taille) -> MoteurPieces {
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        dessiner(m)
```

par :

```swift
        dessiner(m, taille: taille)
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
    /// Ordre des couches : plateaux et equateur, blocs, liens enfant -> parent, liens entre routeurs,
```

par :

```swift
    /// La demo sur quatre plateaux (polissage C) : le rez-de-chaussee, le jardin, l'etage et les combles, chacun sur
    /// son niveau, sans choix ; `places` : les places gardees, dont les choix de niveau.
    static func quatrePlateaux(_ places: PlacesGardees = PlacesGardees()) throws -> EntreeScene {
        let (s, r, _) = try NomsSceneTests.demo()
        var maison = try #require(s.noms.maison)
        maison.zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Buanderie"]),
                        ZoneMaison(nom: "Jardin", pieces: ["Entrée"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Salle de bain"]),
                        ZoneMaison(nom: "Combles", pieces: ["Bureau", "Chambre d'amis"])]
        s.noms.maison = maison
        return EntreeScene(surveillance: s, reseau: r, places: places)
    }

    /// Une vue large (2,4 : 1).
    static let large = CGSize(width: 1824, height: 760)
    /// Une vue carree : sur sa zone visible (1000 x 866, sous les marges des tests), la grille de quatre plateaux est
    /// 2 x 2.
    static let carree = CGSize(width: 1000, height: 1000)

    /// La grille suit la zone visible de la vue (polissage C, section 3.3) : la vue moins ses marges du haut et du bas,
    /// par la fonction du coeur, sur les rayons de la disposition ; 2 x 2 dans une vue carree, la rangee dans une vue
    /// large ; « En rangee », la rangee. La disposition des pieces, elle, ne depend ni de la taille, ni du reglage
    /// (section 4).
    @Test func grilleSelonLaTaille() throws {
        let e = try Self.quatrePlateaux()
        let m = Self.moteur(e, taille: Self.carree)
        #expect(m.grille && m.colonnes == 2 && m.geometrie.colonnes == 2)
        #expect(m.zoneVisible == CGSize(width: 1000, height: 1000 - 84 - 50))
        #expect(m.colonnes == GeometrieMaison.colonnes(rayons: m.geometrie.rayons, taille: m.zoneVisible))
        let l = MoteurPieces()
        l.marges = (84, 50)
        l.poserTaille(Self.large)
        l.installerMaintenant(e)
        #expect(l.colonnes == 4 && l.geometrie.colonnes == 4)
        let r = MoteurPieces()
        r.reglerGrille(false)
        r.marges = (84, 50)
        r.poserTaille(Self.carree)
        r.installerMaintenant(e)
        #expect(!r.grille && r.geometrie.colonnes == 4)
        for autre in [l, r] {
            #expect(autre.positions == m.positions && autre.cartes == m.cartes && autre.geometrie.rayons == m.geometrie.rayons)
        }
    }

    /// La zone visible change avec les marges sans la fiche (polissage C, section 3.3, decision de Djoko du 03/10) :
    /// ouvrir ou replier la legende recalcule la grille, a la vue d'ensemble, comme au redimensionnement, les plateaux
    /// glissant en 0,4 s ; une fiche ouverte, qui ne change que la marge du cadre, ne la change pas.
    @Test func grilleSurLaZoneVisible() throws {
        let m = Self.moteur(try Self.quatrePlateaux(), taille: Self.carree)
        #expect(m.colonnes == 2 && m.basGrille == nil)
        m.basGrille = 50
        m.marges.bas = 600
        Self.dessiner(m, taille: Self.carree)
        #expect(m.glissementPlateaux == nil && m.geometrieVisee.colonnes == 2, "une fiche ouverte : la grille reste")
        m.basGrille = 600
        Self.dessiner(m, taille: Self.carree)
        let g = try #require(m.glissementPlateaux)
        #expect(g.duree2D == CameraScene.dureeCases && m.geometrieVisee.colonnes == 4 && m.colonnes == 4)
        #expect(m.zoneVisible == CGSize(width: 1000, height: 1000 - 84 - 600))
    }

    /// Redimensionnement a la vue d'ensemble (polissage C, section 3.5) : la grille se recalcule, les plateaux glissent
    /// en 0,4 s, en cubique, et la vue se recadre a chaque image ; avec « Reduire les animations », tout de suite.
    @Test func redimensionnement() throws {
        let m = Self.moteur(try Self.quatrePlateaux(), taille: Self.carree)
        let depart = m.geometrie
        Self.dessiner(m, taille: Self.large)
        let g = try #require(m.glissementPlateaux)
        #expect(g.duree2D == CameraScene.dureeCases && g.duree3D == 0 && CameraScene.dureeCases == 0.4)
        #expect(m.geometrieVisee.colonnes == 4 && m.colonnes == 4)
        // A mi-temps, a mi-chemin (`(debut + 0,2) - debut` n'est pas exactement 0,2 : l'heure est grande).
        let mi = m.geometrie(a: g.debut + 0.2)
        let x0 = depart.centres2D[1].x, x1 = m.geometrieVisee.centres2D[1].x
        #expect(abs(mi.centres2D[1].x - (x0 + (x1 - x0) * 0.5)) < 1e-6 && abs(x1 - x0) > 1)
        #expect(m.geometrie(a: g.debut + 0.41) == m.geometrieVisee)
        #expect(m.orbite == CameraScene.canonique(m.geometrie, aspect: m.aspect, u: 0), "la vue se recadre a chaque image")
        let r = Self.moteur(try Self.quatrePlateaux(), taille: Self.carree)
        r.reduire = true
        Self.dessiner(r, taille: Self.large)
        #expect(r.glissementPlateaux == nil && r.geometrie == r.geometrieVisee && r.geometrie.colonnes == 4)
    }

    /// Zoomee ou isolee, la grille attend le retour a la vue d'ensemble (polissage C, section 3.5) ; elle s'y pose
    /// ensuite, avec l'hysteresis du redimensionnement.
    @Test func grilleQuiAttend() throws {
        let m = Self.moteur(try Self.quatrePlateaux(), taille: Self.carree)
        m.reduire = true
        m.molette(-20, precis: false)
        Self.dessiner(m, taille: Self.large)
        #expect(m.vueTouchee && m.geometrieVisee.colonnes == 2)
        #expect(m.grilleEnAttente == MoteurPieces.GrilleEnAttente(duree: CameraScene.dureeCases, hysteresis: true))
        m.sortir()
        Self.dessiner(m, taille: Self.large)
        #expect(m.grilleEnAttente == nil && m.geometrieVisee.colonnes == 4 && m.geometrie == m.geometrieVisee)
        let i = Self.moteur(try Self.quatrePlateaux(), taille: Self.carree)
        i.isoler(try Self.indice(try #require(i.entree), "Salon"))
        Self.dessiner(i, taille: Self.large)
        #expect(i.grilleEnAttente != nil && i.geometrieVisee.colonnes == 2, "isolee, la grille attend")
    }

    /// Le reglage « Etages en 2D » (polissage C, section 3.1) s'applique tout de suite a la vue ouverte : les plateaux
    /// glissent en 2,6 s, comme l'envol ; avec « Reduire les animations », tout de suite. En 3D, il attend la 2D : l'envol
    /// vers la 2D se pose sur la grille de la zone visible du moment.
    @Test func reglageDeLaGrille() throws {
        let m = Self.moteur(try Self.quatrePlateaux(), taille: Self.carree)
        m.reglerGrille(false)
        let g = try #require(m.glissementPlateaux)
        #expect(!m.grille && g.duree2D == CameraScene.dureeEnvol && g.duree3D == 0 && m.geometrieVisee.colonnes == 4)
        m.reglerGrille(true)
        #expect(m.geometrieVisee.colonnes == 2)
        let r = Self.moteur(try Self.quatrePlateaux(), taille: Self.carree)
        r.reduire = true
        r.reglerGrille(false)
        #expect(r.glissementPlateaux == nil && r.geometrie.colonnes == 4)
        let trois = MoteurPieces(troisD: true)
        trois.marges = (84, 50)
        trois.poserTaille(Self.carree)
        trois.installerMaintenant(try Self.quatrePlateaux())
        trois.reglerGrille(false)
        #expect(trois.glissementPlateaux == nil && trois.grilleEnAttente != nil && trois.geometrieVisee.colonnes == 2)
        trois.basculer(troisD: false)
        #expect(trois.grilleEnAttente == nil && trois.geometrieVisee.colonnes == 4 && trois.enMouvement)
    }

    /// Une taille nulle ne choisit rien (polissage C, section 3.3) : la rangee en attendant ; la premiere vraie taille
    /// pose la grille et cadre la vue d'ensemble, sans autre condition.
    @Test func premiereVraieTaille() throws {
        let m = MoteurPieces()
        m.marges = (84, 50)
        m.poserTaille(.zero)
        m.installerMaintenant(try Self.quatrePlateaux())
        #expect(m.pret && m.colonnes == nil && m.geometrie.colonnes == 4)
        Self.dessiner(m, taille: Self.carree)
        #expect(m.colonnes == 2 && m.geometrie.colonnes == 2 && m.glissementPlateaux == nil)
        #expect(m.orbite == CameraScene.canonique(m.geometrie, aspect: m.aspect, u: 0))
    }

    /// Des niveaux changes (une zone mise a cote d'un etage) : les plateaux glissent vers leur nouvelle place, en 0,4 s
    /// en 2D et en 0,9 s en 3D (polissage C, section 1.3) ; avec « Reduire les animations », tout de suite.
    @Test func glissementApresUnChangementDeNiveau() throws {
        let e = try Self.quatrePlateaux()
        var places = PlacesGardees()
        places.ranger(Rangement(ordre: [], aCote: ["zone:Jardin": PlacesGardees.ACote(etage: "zone:Rez-de-chaussée")]),
                      domicile: e.domicile)
        let aCote = try Self.quatrePlateaux(places)
        for reduire in [false, true] {
            let m = Self.moteur(e)
            m.reduire = reduire
            m.installerMaintenant(aCote)
            #expect(m.geometrieVisee.colonnes == m.colonnes)
            if reduire {
                #expect(m.glissementPlateaux == nil && m.geometrie == m.geometrieVisee)
            } else {
                let g = try #require(m.glissementPlateaux)
                #expect(g.duree2D == CameraScene.dureeCases && g.duree3D == CameraScene.dureeNiveaux && CameraScene.dureeNiveaux == 0.9)
            }
        }
    }

    /// Ordre des couches : plateaux et equateur, blocs, liens enfant -> parent, liens entre routeurs,
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// Places des pieces : a cote des identites des routeurs, ni en demo ni sous les tests.
```

par :

```swift
    /// La marge du bas de la zone visible ou se choisit la grille (polissage C, section 3.3, decision de Djoko du
    /// 03/10) : celle de la legende telle que Djoko l'a laissee, sans la fiche ; ouverte, sa hauteur mesuree ; repliee,
    /// 30 pt. Une fiche ouverte n'y change rien, ni le repli de la legende faute de place sous elle.
    @Test func margeDeLaGrille() {
        let ouverte = FenetrePieces.margeBas(pile: 223)
        #expect(FenetrePieces.margeBasGrille(fiche: false, repliee: false, legende: 223, legendeOuverte: 223) == ouverte)
        #expect(FenetrePieces.margeBasGrille(fiche: false, repliee: true, legende: nil, legendeOuverte: 223) == 30)
        #expect(FenetrePieces.margeBasGrille(fiche: true, repliee: false, legende: nil, legendeOuverte: 223) == ouverte,
                "la legende repliee faute de place sous la fiche")
        #expect(FenetrePieces.margeBasGrille(fiche: true, repliee: false, legende: 223, legendeOuverte: 223) == ouverte)
        #expect(FenetrePieces.margeBasGrille(fiche: true, repliee: true, legende: nil, legendeOuverte: 223) == 30)
    }

    /// Le reglage « Etages en 2D » (polissage C, section 3.1) : en grille par defaut ; change dans les preferences
    /// (Reglages › General), il s'applique tout de suite a la vue ouverte. La fenetre s'ouvre dans le mode garde de
    /// l'app (`UserDefaults.standard`, lu a sa creation) : en 3D, la rangee attend la vue d'ensemble 2D.
    @Test(.timeLimit(.minutes(1))) func reglageEtagesEn2D() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let (fenetre, moteur) = try Self.fenetre(demo, taille: CGSize(width: 1100, height: 760), preferences: p)
        defer { Self.fermer(fenetre) }
        try await MoteurPiecesTests.attendre { moteur.pret }
        #expect(FenetrePieces.cleGrille == "etagesEnGrille" && moteur.grille, "en grille par defaut")
        p.set(false, forKey: FenetrePieces.cleGrille)
        try await MoteurPiecesTests.attendre { !moteur.grille }
        #expect(!moteur.grille && (moteur.troisD ? moteur.grilleEnAttente?.duree == CameraScene.dureeEnvol
                                                 : moteur.geometrieVisee.colonnes == moteur.geometrieVisee.rayons.count))
        p.set(true, forKey: FenetrePieces.cleGrille)
        try await MoteurPiecesTests.attendre { moteur.grille }
        #expect(moteur.grille)
    }

    /// Places des pieces : a cote des identites des routeurs, ni en demo ni sous les tests.
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageThreadTests/MoteurPiecesTests MaillageThreadTests/FenetrePiecesTests`
Expected: la compilation des tests échoue (`FenetrePiecesTests.swift`, `MoteurPiecesTests.swift`), par exemple avec `error: type 'FenetrePieces' has no member 'margeBasGrille'` et `error: type 'FenetrePieces' has no member 'cleGrille'` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** Le chemin d'une géométrie à une autre et les durées, puis le moteur (la géométrie visée, la grille sur la zone visible, les glissements), la fenêtre (le réglage, la marge du bas de la grille), les Réglages.

Dans `MaillageCoeur/Scene/CameraScene.swift`, remplacer :

```swift
    /// Hauteur des blocs : 0,04 en 2D, 2,44 en 3D.
```

par :

```swift
    /// La geometrie en route de celle-ci, au depart, vers `b`, qui a les memes plateaux dans le meme ordre
    /// (polissage C, sections 1.3 et 3.5) : en 2D a l'avancement `k2` (les centres et la boite), en 3D a `k3`
    /// (les centres, le pas, la sphere et le cadrage) ; les rayons et les colonnes sont ceux de `b`.
    public func vers(_ b: GeometrieMaison, k2: Double, k3: Double) -> GeometrieMaison {
        func m(_ x: Double, _ y: Double, _ k: Double) -> Double { x + (y - x) * k }
        var g = b
        for i in g.rayons.indices where i < centres2D.count {
            g.centres2D[i] = centres2D[i] + (b.centres2D[i] - centres2D[i]) * k2
            g.centres3D[i] = centres3D[i] + (b.centres3D[i] - centres3D[i]) * k3
        }
        g.boite = Boite(x0: m(boite.x0, b.boite.x0, k2), x1: m(boite.x1, b.boite.x1, k2), z0: m(boite.z0, b.boite.z0, k2),
                        z1: m(boite.z1, b.boite.z1, k2))
        g.pasEtage = m(pasEtage, b.pasEtage, k3)
        g.centreSphere = centreSphere + (b.centreSphere - centreSphere) * k3
        g.rayonSphere = m(rayonSphere, b.rayonSphere, k3)
        g.rayonCadre = m(rayonCadre, b.rayonCadre, k3)
        return g
    }

    /// Hauteur des blocs : 0,04 en 2D, 2,44 en 3D.
```

Dans `MaillageCoeur/Scene/CameraScene.swift`, remplacer :

```swift
    /// « Reduire les animations » : l'envol devient un fondu.
```

par :

```swift
    /// Glissement des plateaux vers leur nouvelle case en 2D : au redimensionnement, et apres un changement de
    /// niveau (polissage C, sections 1.3 et 3.5) ; au changement du reglage, celui de l'envol (`dureeEnvol`).
    public static let dureeCases = 0.4
    /// Glissement des plateaux, de la sphere et du cadrage vers leur nouvelle place en 3D, apres un changement de
    /// niveau (polissage C, section 1.3).
    public static let dureeNiveaux = 0.9
    /// « Reduire les animations » : l'envol devient un fondu.
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    @ObservationIgnored private(set) var geometrie = GeometrieMaison(rayons: [])
```

par :

```swift
    /// La geometrie de l'image ; elle rejoint la geometrie visee (`geometrieVisee`) quand les plateaux glissent.
    @ObservationIgnored private(set) var geometrie = GeometrieMaison(rayons: [])
    /// La geometrie de la scene, avec les rayons de sa disposition et la grille du reglage.
    @ObservationIgnored private(set) var geometrieVisee = GeometrieMaison(rayons: [])
    @ObservationIgnored private(set) var glissementPlateaux: GlissementPlateaux?
    /// Etages en 2D (polissage C, section 3.1) : en grille, ou en rangee ; le reglage, pose par la fenetre.
    @ObservationIgnored private(set) var grille = true
    /// Colonnes de la grille ; nil : pas encore de vraie taille, la rangee en attendant.
    @ObservationIgnored private(set) var colonnes: Int?
    /// Une grille voulue attend la vue d'ensemble 2D (zoomee, isolee, en 3D, en mouvement).
    @ObservationIgnored private(set) var grilleEnAttente: GrilleEnAttente?
    /// Ce que vise le vol en cours : son arrivee suit les plateaux qui glissent.
    @ObservationIgnored private var viseeVol: Visee?
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Marges du cadre, et leur glissement en cours vers `marges`.
```

par :

```swift
    /// Marge du bas de la zone visible ou se choisit la grille (polissage C, section 3.3) : celle de la legende, ouverte
    /// ou repliee, sans la fiche, qui va et vient (`FenetrePieces.margeBasGrille`) ; nil : celle du cadre.
    @ObservationIgnored var basGrille: CGFloat?
    /// La zone visible de la derniere image : une autre recalcule la grille.
    @ObservationIgnored private var zoneGrille = CGSize.zero
    /// Marges du cadre, et leur glissement en cours vers `marges`.
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Fondu de 0,3 s par le fond (« Reduire les animations ») : la scene s'efface, la camera saute a
```

par :

```swift
    /// Glissement des plateaux (polissage C, sections 1.3 et 3.5) : de `depart`, la geometrie de l'image a son debut,
    /// remise dans l'ordre des plateaux de la scene, vers la geometrie visee ; en 2D en `duree2D`, en 3D en
    /// `duree3D` (0 : sans glissement), en cubique entree-sortie.
    struct GlissementPlateaux {
        var depart: GeometrieMaison
        var debut: Double
        var duree2D: Double
        var duree3D: Double
    }

    /// Une grille voulue qui attend la vue d'ensemble 2D : la duree du glissement de ses plateaux, et si elle garde
    /// la grille en place tant qu'elle est a moins de 5 % du choix (un redimensionnement).
    struct GrilleEnAttente: Equatable {
        var duree: Double
        var hysteresis: Bool
    }

    /// Ce que vise un vol : la vue d'ensemble, ou une piece (sa cle).
    private enum Visee {
        case ensemble
        case piece(String)
    }

    /// Fondu de 0,3 s par le fond (« Reduire les animations ») : la scene s'efface, la camera saute a
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Un mouvement, ou un glisser en cours (spec, sections 5 et 7) : une scene recue attend sa fin.
```

par :

```swift
    /// La vue est a la vue d'ensemble : ni zoomee, ni deplacee, ni isolee, ni en mouvement.
    var aLaVueDEnsemble: Bool { pret && !vueTouchee && focus == nil && !enMouvement }
    /// Un mouvement, ou un glisser en cours (spec, sections 5 et 7) : une scene recue attend sa fin.
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        entree = e
        cartes = scene.pieces.map { cartesCalculees[$0.id] ?? CartesPieces.carte([]) }
        positions = scene.pieces.map { placesCalculees[$0.id] ?? .zero }
        geometrie = GeometrieMaison(rayons: scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge },
                                    plateaux: scene.etages.map {
                                        GeometrieMaison.Plateau(niveau: $0.niveau, principal: $0.principal, dehors: $0.dehors)
                                    })
```

par :

```swift
        // Des niveaux changes (le menu du clic droit) : les plateaux glissent vers leur nouvelle place (polissage C,
        // section 1.3) ; a la vue d'ensemble 2D, la grille se recalcule, sinon elle l'attend.
        let anciens = entree?.scene.etages.map(\.id) ?? []
        let niveauxChanges = pret && entree?.scene.niveaux != scene.niveaux
        let ensemble = aLaVueDEnsemble && t == 0
        entree = e
        cartes = scene.pieces.map { cartesCalculees[$0.id] ?? CartesPieces.carte([]) }
        positions = scene.pieces.map { placesCalculees[$0.id] ?? .zero }
        if grille && (!pret || (niveauxChanges && ensemble)) {
            colonnes = colonnesVoulues(scene, enPlace: nil) ?? colonnes
        } else if niveauxChanges {
            attendreGrille(CameraScene.dureeCases, hysteresis: false)
        }
        viser(geometriePour(scene), depuis: anciens, duree2D: niveauxChanges ? CameraScene.dureeCases : 0,
              duree3D: niveauxChanges ? CameraScene.dureeNiveaux : 0)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    // MARK: Camera
```

par :

```swift
    // MARK: Plateaux

    /// La geometrie d'une scene : les rayons de sa disposition, ses niveaux, et la grille du reglage (en grille, les
    /// colonnes choisies, la rangee en attendant une vraie taille).
    private func geometriePour(_ scene: ScenePieces) -> GeometrieMaison {
        GeometrieMaison(rayons: scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge },
                        plateaux: scene.etages.map {
                            GeometrieMaison.Plateau(niveau: $0.niveau, principal: $0.principal, dehors: $0.dehors)
                        },
                        colonnes: grille ? colonnes : nil)
    }

    /// Les colonnes de la grille pour la zone visible de la vue (polissage C, section 3.3) ; nil sans vraie taille.
    private func colonnesVoulues(_ scene: ScenePieces, enPlace: Int?) -> Int? {
        GeometrieMaison.colonnes(rayons: scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge },
                                 taille: zoneVisible, enPlace: enPlace)
    }

    /// La zone visible ou se choisit la grille (polissage C, section 3.3, decision de Djoko du 03/10) : la vue moins la
    /// marge du haut et celle du bas, la legende ouverte ou repliee, sans la fiche (`basGrille`). La vue d'ensemble y est
    /// toujours la plus grande possible.
    var zoneVisible: CGSize {
        CGSize(width: taille.width, height: taille.height - marges.haut - (basGrille ?? marges.bas))
    }

    /// Pose la geometrie visee : tout de suite, ou en glissant (« Reduire les animations » : tout de suite) depuis la
    /// geometrie de l'image, remise dans l'ordre des plateaux de la scene (`anciens` : celui de l'image). Un
    /// glissement en cours repart de l'image, avec le temps qui lui restait s'il est plus long.
    private func viser(_ g: GeometrieMaison, depuis anciens: [String], duree2D: Double, duree3D: Double) {
        let now = Self.maintenant()
        var d2 = reduire ? 0 : duree2D
        var d3 = reduire ? 0 : duree3D
        if let gl = glissementPlateaux, !reduire {
            d2 = max(d2, gl.duree2D - (now - gl.debut))
            d3 = max(d3, gl.duree3D - (now - gl.debut))
        }
        geometrieVisee = g
        guard pret, d2 > 0 || d3 > 0, let cles = scene?.etages.map(\.id) else {
            geometrie = g
            glissementPlateaux = nil
            return
        }
        let image = geometrie
        var depart = g
        for (i, c) in cles.enumerated() {
            guard let j = anciens.firstIndex(of: c), j < image.centres2D.count else { continue }
            depart.centres2D[i] = image.centres2D[j]
            depart.centres3D[i] = image.centres3D[j]
        }
        depart.boite = image.boite
        depart.pasEtage = image.pasEtage
        depart.centreSphere = image.centreSphere
        depart.rayonSphere = image.rayonSphere
        depart.rayonCadre = image.rayonCadre
        geometrie = depart
        glissementPlateaux = GlissementPlateaux(depart: depart, debut: now, duree2D: d2, duree3D: d3)
        reveiller()
    }

    /// La geometrie de l'image a l'instant `now` : en route vers la geometrie visee, ou elle.
    func geometrie(a now: Double) -> GeometrieMaison {
        guard let gl = glissementPlateaux else { return geometrieVisee }
        let q2 = gl.duree2D > 0 ? min(1, max(0, (now - gl.debut) / gl.duree2D)) : 1
        let q3 = gl.duree3D > 0 ? min(1, max(0, (now - gl.debut) / gl.duree3D)) : 1
        if q2 >= 1 && q3 >= 1 { return geometrieVisee }
        return gl.depart.vers(geometrieVisee, k2: CameraScene.rampe(q2), k3: CameraScene.rampe(q3))
    }

    /// Le reglage « Etages en 2D » (polissage C, section 3.1) : en grille ou en rangee. Il s'applique tout de suite a
    /// la vue ouverte, les plateaux glissant comme l'envol, en 2,6 s ; zoomee, isolee ou en 3D, au retour a la vue
    /// d'ensemble 2D.
    func reglerGrille(_ g: Bool) {
        guard g != grille else { return }
        grille = g
        guard pret else { return }
        demanderGrille(CameraScene.dureeEnvol, hysteresis: false)
    }

    /// La zone visible a change (polissage C, sections 3.3 et 3.5) : la taille de la vue, ou ses marges sans la fiche
    /// (la legende ouverte ou repliee, un bandeau). La premiere vraie zone pose la grille et cadre la vue d'ensemble,
    /// sans autre condition ; ensuite, la grille se recalcule a la vue d'ensemble 2D, avec l'hysteresis, et les plateaux
    /// glissent en 0,4 s ; zoomee, isolee ou en 3D, elle attend.
    private func zoneChangee() {
        guard pret, let scene else { return }
        if grille && colonnes == nil {
            guard let c = colonnesVoulues(scene, enPlace: nil) else { return }
            colonnes = c
            viser(geometriePour(scene), depuis: scene.etages.map(\.id), duree2D: 0, duree3D: 0)
            vueTouchee = false
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
            return
        }
        demanderGrille(CameraScene.dureeCases, hysteresis: true)
    }

    /// Une grille voulue : posee a la vue d'ensemble 2D, ses plateaux glissant en `duree` ; sinon elle attend.
    private func demanderGrille(_ duree: Double, hysteresis: Bool) {
        if t == 0 && aLaVueDEnsemble {
            poserGrille(duree, hysteresis: hysteresis)
        } else {
            attendreGrille(duree, hysteresis: hysteresis)
        }
    }

    /// Une grille attend la vue d'ensemble 2D : la plus longue duree, et l'hysteresis si toutes la demandent.
    private func attendreGrille(_ duree: Double, hysteresis: Bool) {
        let a = grilleEnAttente
        grilleEnAttente = GrilleEnAttente(duree: max(a?.duree ?? 0, duree), hysteresis: (a?.hysteresis ?? true) && hysteresis)
    }

    private func poserGrille(_ duree: Double, hysteresis: Bool) {
        grilleEnAttente = nil
        guard let scene else { return }
        if grille, let c = colonnesVoulues(scene, enPlace: hysteresis ? colonnes : nil) { colonnes = c }
        let g = geometriePour(scene)
        guard g != geometrieVisee else { return }
        viser(g, depuis: scene.etages.map(\.id), duree2D: duree, duree3D: 0)
    }

    /// Ce que la vue regarde : la piece isolee, ou la cible de la vue d'ensemble.
    private func ancreCamera() -> SIMD3<Double> {
        if let i = focus, let c = centrePiece(i) { return c }
        return geometrie.cible2D + (geometrie.centreSphere - geometrie.cible2D) * t
    }

    /// Les plateaux glissent : un vol rejoint l'arrivee de ce qu'il vise ; a la vue d'ensemble, elle se recadre ; sinon,
    /// la vue suit ce qu'elle regarde (`ancre0` : sa place a l'image d'avant).
    private func suivre(depuis ancre0: SIMD3<Double>) {
        if vol != nil {
            if let v = viseeVol, let fin = volVers(v) {
                vol?.oeil1 = fin.oeil1
                vol?.cible1 = fin.cible1
            }
        } else if envol == nil && fondu == nil {
            if aLaVueDEnsemble {
                recadrer()
            } else {
                orbite.cible += ancreCamera() - ancre0
            }
        }
    }

    /// Le vol vers ce que l'on vise, depuis la camera du moment.
    private func volVers(_ v: Visee) -> Vol? {
        switch v {
        case .ensemble: CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1)
        case .piece(let cle): scene?.pieces.firstIndex { $0.id == cle }.flatMap(volVersPiece)
        }
    }

    // MARK: Camera
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        let arrivee = v ? 1.0 : 0.0
```

par :

```swift
        // Vers la 2D, l'envol se pose sur la grille de la zone visible du moment (polissage C, section 3.5).
        if !v, let scene {
            grilleEnAttente = nil
            if grille, let c = colonnesVoulues(scene, enPlace: nil) { colonnes = c }
            viser(geometriePour(scene), depuis: scene.etages.map(\.id), duree2D: 0, duree3D: 0)
        }
        let arrivee = v ? 1.0 : 0.0
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if let v = volVersPiece(i) { voler(v) }
```

par :

```swift
        if let v = volVersPiece(i) { voler(v, visee: .piece(scene.pieces[i].id)) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        voler(CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1), enFondu: enFondu)
```

par :

```swift
        voler(CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1), visee: .ensemble,
              enFondu: enFondu)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    private func voler(_ v: Vol, enFondu: Bool = false) {
        zoomEnAttente = 0
        rotationEnAttente = .zero
```

par :

```swift
    private func voler(_ v: Vol, visee: Visee, enFondu: Bool = false) {
        zoomEnAttente = 0
        rotationEnAttente = .zero
        viseeVol = nil
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            debutVol = Self.maintenant()
```

par :

```swift
            viseeVol = visee
            debutVol = Self.maintenant()
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        // Taille ou marges changees : la vue d'ensemble se recadre, sauf si Djoko a zoome ou isole une piece.
        taille = nouvelle
```

par :

```swift
        // Taille ou marges changees : la vue d'ensemble se recadre, sauf si Djoko a zoome ou isole une piece ; une
        // nouvelle zone visible recalcule la grille (polissage C, sections 3.3 et 3.5).
        taille = nouvelle
        let changee = zoneVisible != zoneGrille
        zoneGrille = zoneVisible
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if !fige { avancer(now) }
```

par :

```swift
        if changee && !fige { zoneChangee() }
        if !fige { avancer(now) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            if abs(c - fk[i]) < 1e-3 { fk[i] = c }
```

par :

```swift
            if abs(c - fk[i]) < 1e-3 { fk[i] = c }
        }
        if glissementPlateaux != nil {
            let ancre0 = ancreCamera()
            geometrie = geometrie(a: now)
            if geometrie == geometrieVisee { glissementPlateaux = nil }
            suivre(depuis: ancre0)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            if q >= 1 { vol = nil }
        } else if envol == nil && fondu == nil {
            controles()
        }
```

par :

```swift
            if q >= 1 {
                vol = nil
                viseeVol = nil
            }
        } else if envol == nil && fondu == nil {
            controles()
        }
        // Une grille qui attendait la vue d'ensemble 2D s'y pose.
        if let g = grilleEnAttente, t == 0, aLaVueDEnsemble { poserGrille(g.duree, hysteresis: g.hysteresis) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if enMouvement || s != sCible || margesEnRoute || (attente != nil && geste == nil) { return true }
```

par :

```swift
        if enMouvement || s != sCible || margesEnRoute || glissementPlateaux != nil || (attente != nil && geste == nil) {
            return true
        }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Pose le cadre sans image (captures, tests).
    func poserTaille(_ nouvelle: CGSize) {
        taille = nouvelle
```

par :

```swift
    /// Pose le cadre sans image, et la grille de cette zone visible, tout de suite (captures, tests).
    func poserTaille(_ nouvelle: CGSize) {
        taille = nouvelle
        zoneGrille = zoneVisible
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if pret { recadrer() }
```

par :

```swift
        guard pret, let scene else { return }
        if grille, let c = colonnesVoulues(scene, enPlace: colonnes) { colonnes = c }
        glissementPlateaux = nil
        grilleEnAttente = nil
        geometrieVisee = geometriePour(scene)
        geometrie = geometrieVisee
        recadrer()
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    @State private var moteur: MoteurPieces
```

par :

```swift
    /// Les etages en 2D, en grille (par defaut) ou en rangee (polissage C, section 3.1) : le reglage de Reglages ›
    /// General, garde d'un lancement a l'autre.
    @AppStorage(FenetrePieces.cleGrille) private var etagesEnGrille = true
    /// Le repli de la legende, tel que Djoko l'a laisse (la preference de `LigneDuBas`) : la zone visible de la grille.
    @AppStorage(LegendePieces.cleRepliee) private var legendeRepliee = false
    @State private var moteur: MoteurPieces
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    /// Taille minimale de la fenetre (polissage B, section 3) : avec la fiche et ses courbes, la scene
```

par :

```swift
    /// Preference des etages en 2D : en grille (vrai, par defaut) ou en rangee.
    static let cleGrille = "etagesEnGrille"
    /// Taille minimale de la fenetre (polissage B, section 3) : avec la fiche et ses courbes, la scene
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    /// Hauteur de scene en dessous de laquelle la legende ouverte se replie d'elle-meme sous une fiche (pt) : les
```

par :

```swift
    /// Marge du bas de la zone visible ou se choisit la grille (polissage C, section 3.3, decision de Djoko du 03/10) :
    /// celle de la legende telle que Djoko l'a laissee, ouverte ou repliee, sans la fiche, ni le repli de la legende
    /// faute de place sous elle, qui vont et viennent avec elle. `fiche` : une fiche est ouverte ; `repliee` : le repli
    /// garde ; `legende` : la hauteur mesuree de la rangee du bas, ouverte (nil : repliee) ; `legendeOuverte` : sa
    /// derniere mesure, ouverte. Ouvrir ou replier la legende change donc la grille ; ouvrir une fiche, non.
    static func margeBasGrille(fiche: Bool, repliee: Bool, legende: CGFloat?, legendeOuverte: CGFloat?) -> CGFloat {
        margeBas(pile: fiche ? (repliee ? nil : legendeOuverte) : legende)
    }

    /// Hauteur de scene en dessous de laquelle la legende ouverte se replie d'elle-meme sous une fiche (pt) : les
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                              marges: (margeHautMesuree, Self.margeBas(pile: hauteurPile ?? hauteurLegende)))
```

par :

```swift
                              marges: (margeHautMesuree, Self.margeBas(pile: hauteurPile ?? hauteurLegende)),
                              basGrille: Self.margeBasGrille(fiche: fiche, repliee: legendeRepliee, legende: hauteurLegende,
                                                             legendeOuverte: legendeOuverteMesuree))
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        // La fiche parait ou se ferme : la legende reprend son repli garde, et un « rouvert » anterieur ne vaut plus.
```

par :

```swift
        // Le reglage s'applique tout de suite a la vue ouverte.
        .onChange(of: etagesEnGrille, initial: true) { _, g in moteur.reglerGrille(g) }
        // La fiche parait ou se ferme : la legende reprend son repli garde, et un « rouvert » anterieur ne vaut plus.
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    @Environment(\.displayScale) private var echelle
```

par :

```swift
    /// Marge du bas de la zone visible ou se choisit la grille (`FenetrePieces.margeBasGrille`).
    let basGrille: CGFloat
    @Environment(\.displayScale) private var echelle
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                moteur.image(&ctx, taille: taille, echelle: echelle, palette: palette)
```

par :

```swift
                moteur.basGrille = basGrille
                moteur.image(&ctx, taille: taille, echelle: echelle, palette: palette)
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
    @State private var messageCapture: String?
```

par :

```swift
    @AppStorage(FenetrePieces.cleGrille) private var etagesEnGrille = true
    @State private var messageCapture: String?
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
                    choixDeLangue
```

par :

```swift
                    choixDeLangue
                    vueParPieces
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, remplacer :

```swift
    /// Onglet Maison : noms, pieces et zones releves par le passeur.
```

par :

```swift
    /// Onglet General : la vue par pieces (polissage C, section 3.1) ; les etages en 2D, en grille ou en rangee,
    /// s'appliquent tout de suite a la vue ouverte.
    private var vueParPieces: some View {
        Section("Vue par pièces") {
            Picker("Étages en 2D", selection: $etagesEnGrille) {
                Text("En grille").tag(true)
                Text("En rangée").tag(false)
            }
        }
    }

    /// Onglet Maison : noms, pieces et zones releves par le passeur.
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageThreadTests/MoteurPiecesTests MaillageThreadTests/FenetrePiecesTests`
Expected: `Test run with 70 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes, en français et en anglais.** Le Step 4 a compilé : mettre le catalogue à jour avec les clés que le compilateur a extraites.

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" outils/synchroniser-textes.sh
```

Expected : `Localizable.xcstrings` reçoit exactement ces 4 clés : « En grille », « En rangée », « Vue par pièces », « Étages en 2D » ; aucune ne devient périmée.

Puis les traductions, par ce script, qui ajoute les nouvelles à `interface.json` et garde le fichier trié au format de l'outil ; `outils/traduire.py` donne ensuite l'anglais aux nouvelles clés du catalogue :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "En grille": "In a grid",
    "En rangée": "In a row",
    "Vue par pièces": "Room view",
    "Étages en 2D": "Floors in 2D",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

Expected : aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh`
Expected: `Test run with 365 tests in 37 suites passed` (cœur) et `Test run with 326 tests in 29 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 9 tests de plus pour l'app. Les sept tests de la grille dans le moteur et les deux de la fenêtre (`margeDeLaGrille`, `reglageEtagesEn2D`) s'ajoutent à l'app.

- [ ] **Step 7 : les images de démo, identiques.** Avec deux étages, la grille de la démo est la rangée : chaque image est identique, octet pour octet, à celle de la tâche 3.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t4"
R="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t3"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polC/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
n=0; for f in "$R"/*.png; do cmp -s "$f" "$D/$(basename "$f")" && n=$((n+1)) || echo "différente : $(basename "$f")"; done; echo "$n identiques sur $(ls "$R" | wc -l | tr -d ' ')"
```

Expected : 14 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`, `13-2d-fiche-du-chef.png`, `14-2d-legende-repliee.png`) ; « l'app a quitté » ; « 14 identiques sur 14 ». Si une image diffère, s'arrêter : la tâche a changé le rendu.

- [ ] **Step 8 : commit.**

```bash
git add MaillageThreadTests/MoteurPiecesTests.swift MaillageThreadTests/FenetrePiecesTests.swift MaillageCoeur/Scene/CameraScene.swift MaillageThread/Vues/Pieces/MoteurPieces.swift MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/FenetreReglages.swift MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
git commit -m "Poser la grille 2D dans la vue selon sa zone visible, sans la fiche, avec le reglage Etages en 2D, faire glisser les plateaux au redimensionnement, a l'ouverture et au repli de la legende, au changement du reglage et apres un changement de niveau, et attendre la vue d'ensemble pour la grille

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: L'isolement d'un étage, la provenance, le fil, la priorité des clics, le menu natif ; les n° 8 et 9 du triage A

**Files:**
- Create: `MaillageThreadTests/IsolementTests.swift`
- Modify: `MaillageCoeur/Scene/PlacementNoms.swift`, `MaillageCoeur/Scene/SceneProjetee.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift`, `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/Pieces/RenduCanvas.swift` (blocs ci-dessous)
- Modify (par les outils) : `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json`
- Test: `MaillageCoeurTests/PlacementNomsTests.swift`, `MaillageCoeurTests/SceneProjeteeTests.swift`, `MaillageThreadTests/FenetrePiecesTests.swift`, `MaillageThreadTests/LegendePiecesTests.swift`

**Interfaces:**
- Consumes :
  - `Niveaux` et les opérations du menu (tâche 1), `CameraScene.vueEtage`, `volVersEtage` (tâche 2), la géométrie visée et ses glissements (tâche 4) ; `MoteurPieces` (`focus`, `isolee`, `s`, `poserIsolement`, `sortir`, `cliquer`, `relacher`, `survoler`, `cible(en:)`), `PlacementNoms.regler`, `SceneProjetee.EtatAnime`, `MenuPieces`, `FilPieces`, `LigneNiveau`, existants ;
  - dans les tests : `MoteurPiecesTests.quatrePlateaux(_:)`, `moteur`, `dessiner`, `indice`, `fichier()`, `NomsSceneTests.demo()`, existants.
- Produces :
  - `Isolement` (`.maison`, `.etage`, `.piece(_:provenance:)`), `MoteurPieces.isolement` ; `Fil` (`Cran`), `MoteurPieces.fil` ; `CibleClic`, `MoteurPieces.cibleClic(en:)`, `nomEtageSous(_:marge:)`, `disqueSous(_:)`, `disqueCliquable(_:)` ;
  - `MoteurPieces.allerEtage(_:)`, `versMaison(enFondu:)`, `remonter(clavier:)`, `indiceEtageIsole`, `poserEtageIsole(_:)`, `poserIsolement(_:depuisEtage:)`, `poserInclinaison(_:)` ;
  - `MenuEtage` (`Niveau`), `MoteurPieces.menuEtage(_:)`, `mettreAuNiveau(_:de:)`, `basculerDehors(_:)`, `mettreSurSonNiveau(_:)` ; `Curseur` (`.fleche`, `.main`), `MoteurPieces.curseurForme` ;
  - `SceneProjetee.EtatAnime.se`, `ek`, `survolEtage` ; `Plateau.eclaire` ; `SceneProjetee.voilesEtages` ;
  - `PlacementNoms.regler(…, se:voiles:etageIsole:survolNomEtage:)` ; `LigneNiveau.etageIsole(_:)` ;
  - le catalogue : 4 textes nouveaux.

**L'isolement d'un étage** (spec, section 5) : un clic sur son nom ou son disque l'isole (précision 13) ; le fil le dit, et ses crans mènent à chaque niveau (précision 14) ; Échap et le clic à côté remontent d'où l'on vient (précision 12). La priorité des clics passe par une cible explicite (précision 15) ; le survol éclaircit le disque et souligne le nom (précision 16).

**Le menu du clic droit** devient le menu natif des niveaux, sur le nom et sur le disque (précision 17) : il branche les opérations de la tâche 1. Les plateaux glissent vers leur nouvelle place (tâche 4).

**Les n° 8 et 9 du triage A** (précision 18) : les fondus gardés par clé, et les noms qui suivent l'état d'arrivée.

**Trois images de démo changent** : `10-3d-isolee-salon` et `11-2d-isolee-chambre` (le fil complet, les noms de la pièce visée), `13-2d-fiche-du-chef` (le nom de l'appareil choisi, toujours voulu). Les autres restent identiques, octet pour octet.

- [ ] **Step 1 : écrire les tests.** Un fichier de tests nouveau (`IsolementTests`) ; les noms pendant un isolement ; les voiles d'un étage isolé ; la ligne de niveau ; le menu de la fenêtre.

Dans `MaillageCoeurTests/PlacementNomsTests.swift`, remplacer :

```swift
    /// Temps de calcul, en Release, dans une fenetre ordinaire (noms espaces) : le placement de 150 noms
```

par :

```swift
    /// Les noms pendant un isolement (polissage C, section 5) : un etage isole ne montre que les noms de ses
    /// appareils, selon le zoom ; les noms d'etage restent, pales et cliquables, celui sous le pointeur souligne ;
    /// « ⌂ Maison » s'efface. Pendant le retour d'une piece a la maison (triage A, n° 8), les noms suivent l'etat
    /// d'arrivee : ceux de la maison, selon le zoom. Celui de l'appareil choisi (sa fiche) est toujours voulu.
    @Test func nomsPendantUnIsolement() throws {
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau"])]
        let s = ScenePieces(graphe: try ScenePiecesTests.graphe(sonde: true), libelles: ScenePiecesTests.libelles,
                            piecesNoeuds: ["Apple TV": "Salon", "HomePod": "Chambre", "E000000000000002": "Bureau",
                                           "E000000000000004": "Salon"],
                            zones: zones, chefs: ["Apple TV"], piecesMaison: true)
        let etage = try #require(s.etages.firstIndex { $0.nom == .zone("Étage") })
        var e = s.noeuds.map { Etiquette(.noeud($0.id), taille: CGSize(width: 50, height: 15)) }
        e += s.etages.indices.map { Etiquette(.etage($0), taille: CGSize(width: 60, height: 15)) }
        e.append(Etiquette(.maison, taille: CGSize(width: 60, height: 15)))
        let rien = Array(repeating: 0.0, count: s.pieces.count)
        let voiles = s.etages.indices.map { $0 == etage ? 1.0 : 0.15 }
        PlacementNoms.regler(&e, scene: s, niveau: .tous, survol: nil, selection: nil, focus: nil, isolee: false, fk: rien,
                             s: 0, t: 1, se: 1, voiles: voiles, etageIsole: etage, survolNomEtage: etage)
        let noeuds = e.compactMap { l -> String? in
            if case .noeud(let id) = l.genre, l.voulu { return id }
            return nil
        }
        #expect(Set(noeuds) == ["HomePod", "E000000000000002"], "les appareils de l'etage isole")
        let etages = e.filter { if case .etage = $0.genre { true } else { false } }
        #expect(etages.allSatisfy(\.voulu) && etages.map(\.pale) == s.etages.indices.map { $0 != etage })
        #expect(etages.map(\.fort) == s.etages.indices.map { $0 == etage }, "souligne sous le pointeur")
        #expect(e.last?.voulu == false, "« ⌂ Maison » s'efface")
        // Retour d'une piece (le salon) a la maison : la piece est encore en vue, plus visee.
        let salon = try #require(s.pieces.firstIndex { $0.nom == .maison("Salon") })
        var fk = rien
        fk[salon] = 0.9
        PlacementNoms.regler(&e, scene: s, niveau: .tous, survol: nil, selection: "E000000000000005", focus: salon,
                             isolee: false, fk: fk, s: 0.9, t: 0, se: 0.9, voiles: s.etages.indices.map { _ in 1.0 })
        let retour = e.filter { if case .noeud = $0.genre { $0.voulu } else { false } }.count
        #expect(retour == s.noeuds.count, "les noms de la maison, selon le zoom, pendant le retour")
        #expect(e.first { $0.genre == .noeud("E000000000000005") }.map { $0.prio == 2 && $0.fort } == true, "choisi")
    }

    /// Temps de calcul, en Release, dans une fenetre ordinaire (noms espaces) : le placement de 150 noms
```

Dans `MaillageCoeurTests/SceneProjeteeTests.swift`, remplacer :

```swift
    /// le parent est dans une autre piece, avec son sens (meme etage, dessous) et son fil.
```

par :

```swift
    /// le parent est dans une autre piece, avec son sens (meme etage, dessous) et son fil. Les disques des
    /// etages restent a 15 % : on peut cliquer dessus (polissage C, section 5.2).
```

Dans `MaillageCoeurTests/SceneProjeteeTests.swift`, remplacer :

```swift
        #expect(p.plateaux.allSatisfy { $0.opacite == 0 })
```

par :

```swift
        #expect(p.plateaux.allSatisfy { abs($0.opacite - 0.15) < 1e-12 })
    }

    /// Etage isole (polissage C, section 5.1), ici l'etage : les autres plateaux descendent a 15 %, avec leurs pieces,
    /// leurs pastilles et leurs liens ; un lien qui touche l'etage isole reste visible, meme vers un autre etage ; la
    /// sphere et l'equateur s'effacent. Le disque survole s'eclaircit.
    @Test func etageIsole() throws {
        let (s0, _) = try Self.projeter(t: 1)
        let etage = try #require(s0.etages.firstIndex { $0.nom == .zone("Étage") })
        let (s, p) = try Self.projeter(t: 1) { e in
            e.se = 1
            e.ek = s0.etages.indices.map { $0 == etage ? 1 : 0 }
            e.survolEtage = etage
        }
        #expect(p.voilesEtages.indices.allSatisfy { abs(p.voilesEtages[$0] - ($0 == etage ? 1 : 0.15)) < 1e-12 })
        for pl in p.plateaux {
            #expect(abs(pl.opacite - (pl.etage == etage ? 1 : 0.15)) < 1e-12 && pl.eclaire == (pl.etage == etage))
        }
        for b in p.blocs {
            let attendue = s.pieces[b.piece].etage == etage ? 0.18 : 0.15 * 0.18
            #expect(abs(b.opaciteVerre - attendue) < 1e-12)
        }
        for d in p.disques {
            let n = try #require(s.noeud(d.noeud))
            #expect(abs(d.opacite - (s.pieces[n.piece].etage == etage ? 1 : 0.15)) < 1e-12)
        }
        // Apple TV (rez-de-chaussee) - HomePod (etage) touche l'etage isole ; Apple TV - E...04 reste au rez-de-chaussee.
        let opacites = p.liensRouteurs.map(\.opacite).sorted()
        #expect(opacites.count == 2 && abs(opacites[0] - 0.95 * 0.15) < 1e-12 && abs(opacites[1] - 0.95) < 1e-12)
        #expect(p.sphere == nil && p.equateur == nil)
```

`MaillageThreadTests/IsolementTests.swift` (fichier entier) :

```swift
import AppKit
import Foundation
@testable import MaillageCoeur
import simd
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : etages isoles, provenance, clics et menu")
struct IsolementTests {
    static let rdc = "zone:Rez-de-chaussée", jardin = "zone:Jardin", etage = "zone:Étage", combles = "zone:Combles"

    /// La demo sur quatre plateaux (`MoteurPiecesTests.quatrePlateaux`), le jardin a cote du rez-de-chaussee, hors de
    /// la maison, gardes dans `fichier` ; son moteur, dispose, une premiere image dessinee.
    static func jardinDehors(_ fichier: URL, troisD: Bool = false) throws -> (MoteurPieces, EntreeScene) {
        let base = try MoteurPiecesTests.quatrePlateaux()
        var places = PlacesGardees()
        places.ranger(Rangement(ordre: [rdc, jardin, etage, combles], aCote: [jardin: PlacesGardees.ACote(etage: rdc, dehors: true)]),
                      domicile: base.domicile)
        try places.ecrire(dans: fichier)
        let e = try MoteurPiecesTests.quatrePlateaux(places)
        let m = MoteurPieces(troisD: troisD, fichierPlaces: fichier)
        m.marges = (84, 50)
        m.poserTaille(MoteurPiecesTests.taille)
        m.installerMaintenant(e)
        // La premiere image pose les noms, la seconde les garde a leur place.
        for _ in 0..<2 { MoteurPiecesTests.dessiner(m) }
        return (m, e)
    }

    static func indiceEtage(_ e: EntreeScene, _ cle: String) throws -> Int {
        try #require(e.scene.etages.firstIndex { $0.id == cle })
    }

    /// Le centre du nom d'un etage, pose.
    static func nomDEtage(_ m: MoteurPieces, _ e: Int) throws -> CGPoint {
        let l = try #require(m.etiquettes.first { $0.genre == .etage(e) && $0.vu })
        return CGPoint(x: l.rect.midX, y: l.rect.midY)
    }

    /// Un point du disque d'un etage, hors de ses pieces, de ses pastilles et des noms.
    static func pointDeDisque(_ m: MoteurPieces, _ e: Int) throws -> CGPoint {
        let pl = try #require(m.projetee?.plateaux.first { $0.etage == e })
        let b = SceneProjetee.boite(pl.polygone)
        let points = stride(from: 0.1, through: 0.9, by: 0.05).flatMap { fy in
            stride(from: 0.1, through: 0.9, by: 0.05).map { fx in CGPoint(x: b.minX + b.width * fx, y: b.minY + b.height * fy) }
        }
        return try #require(points.first { m.cibleClic(en: $0) == .disque(e) })
    }

    /// La provenance (polissage C, section 5.4) : maison, piece, Echap : la maison ; maison, etage, piece, Echap :
    /// l'etage, puis Echap : la maison. D'une piece a une autre du meme etage, la provenance reste ; vers une piece
    /// d'un autre etage, elle devient la maison. Le clic a cote remonte de meme.
    @Test func provenance() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        let salon = try MoteurPiecesTests.indice(e, "Salon"), cuisine = try MoteurPiecesTests.indice(e, "Cuisine")
        let chambre = try MoteurPiecesTests.indice(e, "Chambre"), rdc = try Self.indiceEtage(e, Self.rdc)
        m.isoler(salon)
        #expect(m.isolement == .piece("piece:Salon", provenance: nil) && m.estIsolee)
        m.sortir()
        #expect(m.isolement == .maison && !m.estIsolee, "maison, piece, Echap : la maison")
        m.allerEtage(rdc)
        #expect(m.isolement == .etage(Self.rdc))
        m.isoler(salon)
        #expect(m.isolement == .piece("piece:Salon", provenance: Self.rdc))
        m.isoler(cuisine)
        #expect(m.isolement == .piece("piece:Cuisine", provenance: Self.rdc), "une piece du meme etage : la provenance reste")
        m.sortir()
        #expect(m.isolement == .etage(Self.rdc) && !m.estIsolee, "maison, etage, piece, Echap : l'etage")
        m.sortir()
        #expect(m.isolement == .maison, "puis Echap : la maison")
        m.allerEtage(rdc)
        m.isoler(salon)
        m.isoler(chambre)
        #expect(m.isolement == .piece("piece:Chambre", provenance: nil), "une piece d'un autre etage : la maison")
        m.remonter(clavier: false)
        #expect(m.isolement == .maison, "le clic a cote")
    }

    /// Le fil (polissage C, section 5.3) : « Maison › Etage › Piece », meme pour une piece isolee depuis la vue
    /// d'ensemble ; « Maison › Etage » pour un etage isole ; « Maison » seul a la maison ; « Maison › Piece » dans une
    /// maison d'un seul plateau.
    @Test func fil() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        let salon = try MoteurPiecesTests.indice(e, "Salon"), rdc = try Self.indiceEtage(e, Self.rdc)
        let etage = try Self.indiceEtage(e, Self.etage)
        m.isoler(salon)
        #expect(m.fil == Fil(etage: Fil.Cran(nom: "Rez-de-chaussée", etage: rdc), piece: "Salon"))
        m.allerEtage(etage)
        #expect(m.fil == Fil(etage: Fil.Cran(nom: "Étage", etage: etage), piece: nil))
        m.versMaison()
        #expect(m.fil == Fil())
        let (s, r, _) = try NomsSceneTests.demo()
        s.noms.maison?.zones = nil
        let seul = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees())
        #expect(seul.scene.etages.count == 1)
        let n = MoteurPiecesTests.moteur(seul)
        n.isoler(try MoteurPiecesTests.indice(seul, "Salon"))
        #expect(n.fil == Fil(etage: nil, piece: "Salon"))
    }

    /// La priorite des clics (polissage C, section 5.1) : un appareil, une piece (son bloc ou son nom), le nom d'un
    /// etage, son disque, le fond. En 3D, vus d'assez haut pour que les disques se recouvrent a l'ecran : celui du
    /// niveau le plus haut, le plus proche sur le rayon ; un appareil ou une piece sous le nom d'un etage passe devant
    /// lui.
    @Test(arguments: [false, true]) func prioriteDesClics(troisD: Bool) throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url, troisD: troisD)
        if troisD {
            m.fige = true
            m.poserInclinaison(0.3)
            for _ in 0..<2 { MoteurPiecesTests.dessiner(m) }
        }
        let p = try #require(m.projetee)
        let pastille = try #require(p.disques.first { $0.opacite > 0.5 })
        #expect(m.cibleClic(en: pastille.centre) == .appareil(pastille.noeud))
        let nomPiece = try #require(m.etiquettes.first { if case .piece = $0.genre { $0.vu } else { false } })
        if case .piece(let i) = nomPiece.genre {
            #expect(m.cibleClic(en: CGPoint(x: nomPiece.rect.midX, y: nomPiece.rect.midY)) == .piece(i))
        }
        var nomsLibres = 0
        for k in e.scene.etages.indices {
            let q = try Self.nomDEtage(m, k)
            let attendu: CibleClic = if let n = m.noeudSous(q) { .appareil(n) } else if let i = m.pieceSous(q) {
                .piece(i)
            } else {
                .nomEtage(k)
            }
            #expect(m.cibleClic(en: q) == attendu, "le nom de l'etage \(k)")
            if attendu == .nomEtage(k) { nomsLibres += 1 }
        }
        #expect(troisD ? nomsLibres > 0 : nomsLibres == e.scene.etages.count, "\(nomsLibres) noms d'etage libres")
        #expect(m.cibleClic(en: CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3)) == .fond)
        var superposes = 0
        for x in stride(from: 10.0, to: MoteurPiecesTests.taille.width, by: 20) {
            for y in stride(from: 10.0, to: MoteurPiecesTests.taille.height, by: 20) {
                let q = CGPoint(x: x, y: y)
                guard case .disque(let k) = m.cibleClic(en: q) else { continue }
                let sous = p.plateaux.filter { SceneProjetee.contient($0.polygone, q) }.map(\.etage)
                #expect(sous.contains(k) && m.pieceSous(q) == nil && m.noeudSous(q) == nil && m.nomEtageSous(q) == nil)
                let haut = sous.map { m.geometrie.centrePlateau($0, m.t).y }.max() ?? 0
                #expect(m.geometrie.centrePlateau(k, m.t).y == haut, "le disque le plus haut, en \(q)")
                if sous.count > 1 { superposes += 1 }
            }
        }
        if troisD { #expect(superposes > 0, "des disques l'un sur l'autre a l'ecran") }
    }

    /// Clic sur le nom ou le disque d'un etage (polissage C, sections 5.1 et 5.4) : il l'isole ; son propre disque,
    /// entre les pieces, ne fait rien ; le disque d'un autre etage y mene ; le clic a cote ramene a la maison. En
    /// piece isolee, le disque de son etage isole cet etage. Un double-clic sur un disque ramene a la maison. Les clics
    /// visent la vue d'ensemble : le vol de chaque isolement ne commence qu'a l'image suivante.
    @Test func cliquerUnEtage() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        let rdc = try Self.indiceEtage(e, Self.rdc), etage = try Self.indiceEtage(e, Self.etage)
        let nom = try Self.nomDEtage(m, etage), disqueEtage = try Self.pointDeDisque(m, etage)
        let disqueRdc = try Self.pointDeDisque(m, rdc), fond = CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3)
        m.cliquer(nom)
        #expect(m.isolement == .etage(Self.etage) && m.fil.etage?.etage == etage)
        m.cliquer(disqueEtage)
        #expect(m.isolement == .etage(Self.etage) && m.enMouvement, "son propre disque : rien")
        m.cliquer(disqueRdc)
        #expect(m.isolement == .etage(Self.rdc), "le disque d'un autre etage")
        m.cliquer(fond)
        #expect(m.isolement == .maison, "le clic a cote")
        m.isoler(try MoteurPiecesTests.indice(e, "Salon"))
        m.cliquer(disqueRdc)
        #expect(m.isolement == .etage(Self.rdc), "depuis une piece, le disque de son etage l'isole")
        m.relacher(disqueEtage, a: 500)
        #expect(m.isolement == .etage(Self.etage))
        m.relacher(disqueEtage, a: 500.1)
        #expect(m.isolement == .maison, "le double-clic sur un disque : la maison")
        m.allerEtage(etage)
        m.fige = true
        MoteurPiecesTests.dessiner(m)
        #expect(m.ligneNiveau == .etageIsole("Étage"))
        #expect(LigneNiveauVue.texte(.etageIsole("Étage"))
                == String(localized: "Étage isolé : \("Étage") · clic sur une pièce ou un autre étage pour y aller, clic à côté ou Échap pour revenir"))
    }

    /// Le survol d'un disque cliquable l'eclaircit, le nom d'un etage se souligne, et la main dit ce qui se clique ;
    /// le disque de l'etage isole ne se clique pas.
    @Test func survol() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        let etage = try Self.indiceEtage(e, Self.etage)
        let disque = try Self.pointDeDisque(m, etage)
        m.survoler(disque)
        #expect(m.survolEtage == etage && m.curseurForme == .main && m.cibleMenu == .etage(etage))
        m.survoler(try Self.nomDEtage(m, etage))
        #expect(m.survolNomEtage == etage && m.survolEtage == nil && m.curseurForme == .main)
        m.survoler(CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3))
        #expect(m.survolEtage == nil && m.survolNomEtage == nil && m.curseurForme == .fleche && m.cibleMenu == .fond)
        m.allerEtage(etage)
        m.survoler(disque)
        #expect(m.survolEtage == nil && m.curseurForme == .fleche, "le disque de l'etage isole")
    }

    /// Le menu du clic droit (polissage C, section 1.3), article par article, sur le nom et sur le disque : le nom de la
    /// zone en tete ; « Monter » et « Descendre », grises en haut et en bas de la pile et pour une zone a cote ; « Au
    /// meme niveau que », les autres niveaux, coche celui de la zone ; « Hors de la maison » coche ; « Sur son propre
    /// niveau ». Rien sur une piece ; le fond ailleurs.
    @Test func menuDuClicDroit() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        let rdc = try Self.indiceEtage(e, Self.rdc), jardin = try Self.indiceEtage(e, Self.jardin)
        let etage = try Self.indiceEtage(e, Self.etage), combles = try Self.indiceEtage(e, Self.combles)
        for k in e.scene.etages.indices {
            let nom = try Self.nomDEtage(m, k), disque = try Self.pointDeDisque(m, k)
            #expect(m.cible(en: nom) == .etage(k) && m.cible(en: disque) == .etage(k), "le nom et le disque de l'etage \(k)")
        }
        #expect(m.cible(en: try MoteurPiecesTests.pointDePiece(m, try MoteurPiecesTests.indice(e, "Salon"))) == .aucune)
        #expect(m.cible(en: CGPoint(x: 3, y: MoteurPiecesTests.taille.height - 3)) == .fond)
        typealias N = MenuEtage.Niveau
        #expect(m.menuEtage(rdc) == MenuEtage(nom: "Rez-de-chaussée", monter: true, descendre: false,
                                              niveaux: [N(niveau: 1, nom: "Étage", coche: false), N(niveau: 2, nom: "Combles", coche: false)],
                                              aCote: false, dehors: false))
        #expect(m.menuEtage(jardin) == MenuEtage(nom: "Jardin", monter: false, descendre: false,
                                                 niveaux: [N(niveau: 0, nom: "Rez-de-chaussée", coche: true),
                                                           N(niveau: 1, nom: "Étage", coche: false),
                                                           N(niveau: 2, nom: "Combles", coche: false)],
                                                 aCote: true, dehors: true))
        #expect(m.menuEtage(combles).map { !$0.monter && $0.descendre } == true)
        #expect(m.menuEtage(etage).map { $0.monter && $0.descendre } == true)
        // Chaque choix est garde, dans le fichier ; la scene suivante le prend.
        func rangement() -> Rangement { PlacesGardees.lire(url).rangement(e.domicile) }
        m.basculerDehors(jardin)
        #expect(rangement().aCote[Self.jardin] == PlacesGardees.ACote(etage: Self.rdc, dehors: false))
        m.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(m.places))
        m.deplacerEtage(rdc, de: 1)
        #expect(rangement().ordre == [Self.etage, Self.rdc, Self.jardin, Self.combles], "le niveau entier, jardin compris")
        m.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(m.places))
        let c = try Self.indiceEtage(try #require(m.entree), Self.combles)
        m.mettreAuNiveau(c, de: 0)
        #expect(rangement().aCote[Self.combles] == PlacesGardees.ACote(etage: Self.etage), "a cote de l'etage, en bas")
        m.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(m.places))
        let j = try Self.indiceEtage(try #require(m.entree), Self.jardin)
        m.mettreSurSonNiveau(j)
        #expect(rangement().aCote[Self.jardin] == nil)
        m.installerMaintenant(try MoteurPiecesTests.quatrePlateaux(m.places))
        #expect(m.entree?.scene.niveaux.liste == [[Self.etage, Self.combles], [Self.rdc], [Self.jardin]])
    }

    /// Un etage isole (polissage C, section 5.1) : les autres plateaux a 15 %, la sphere effacee, la rotation lente
    /// arretee ; les pieces de l'etage isole se glissent, celles des autres etages seulement se cliquent.
    @Test func etageIsole() throws {
        let url = MoteurPiecesTests.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.jardinDehors(url)
        m.reduire = true
        let etage = try Self.indiceEtage(e, Self.etage)
        let salon = try MoteurPiecesTests.indice(e, "Salon"), chambre = try MoteurPiecesTests.indice(e, "Chambre")
        let pointSalon = try MoteurPiecesTests.pointDePiece(m, salon), pointChambre = try MoteurPiecesTests.pointDePiece(m, chambre)
        m.allerEtage(etage)
        #expect(!m.sansIsolement && m.indiceEtageIsole == etage)
        for (i, d) in [(salon, pointSalon), (chambre, pointChambre)] {
            let avant = m.positions[i]
            m.glisser(d, depart: d)
            m.glisser(CGPoint(x: d.x + 40, y: d.y), depart: d)
            m.relacher(CGPoint(x: d.x + 40, y: d.y))
            #expect((m.positions[i] != avant) == (i == chambre), "piece \(i)")
        }
        let t = MoteurPieces(troisD: true)
        t.marges = (84, 50)
        t.poserTaille(MoteurPiecesTests.taille)
        t.installerMaintenant(e)
        t.poserEtageIsole(etage)
        t.fige = true
        MoteurPiecesTests.dessiner(t)
        let p = try #require(t.projetee)
        #expect(p.plateaux.allSatisfy { abs($0.opacite - ($0.etage == etage ? 1 : 0.15)) < 1e-9 })
        #expect(p.sphere == nil && t.ligneNiveau == .etageIsole("Étage"))
        t.fige = false
        let azimut = t.orbite.azimut
        MoteurPiecesTests.dessiner(t)
        MoteurPiecesTests.dessiner(t)
        #expect(t.orbite.azimut == azimut, "la rotation lente s'arrete")
    }

    /// Triage A, n° 8 : pendant le retour d'une piece isolee, les noms des appareils suivent l'etat d'arrivee, et la
    /// ligne de niveau suit le zoom, au lieu de dire « Tous les noms sont lisibles » sans nom affiche.
    @Test func numero8() throws {
        let (m, e) = try MoteurPiecesTests.moteur()
        m.fige = true
        m.poserIsolement(try MoteurPiecesTests.indice(e, "Salon"))
        MoteurPiecesTests.dessiner(m)
        #expect(m.ligneNiveau == .isolee("Salon"))
        m.versMaison()
        MoteurPiecesTests.dessiner(m)
        #expect(m.focus != nil && m.s == 1 && !m.estIsolee, "en plein retour")
        let voulus = m.etiquettes.filter { if case .noeud = $0.genre { $0.voulu } else { false } }
        #expect(!voulus.isEmpty, "les noms de la maison, selon le zoom")
        let p = try #require(m.projetee)
        let ancres = m.etiquettes.map { l -> CGRect? in if case .noeud(let id) = l.genre { p.ancresNoeuds[id] } else { nil } }
        let masques = PlacementNoms.masques(m.etiquettes, ancres: ancres, cadre: MoteurPiecesTests.taille)
        #expect(m.ligneNiveau == (masques > 0 ? .masques(masques) : .lisibles), "la ligne suit les noms voulus")
    }

    /// Triage A, n° 9 : avec « Reduire les animations », un releve recu pendant le fondu d'un isolement ne remet pas la
    /// piece a pleine taille : sa part de l'isolement est gardee par cle.
    @Test func numero9() throws {
        let (m, e) = try MoteurPiecesTests.moteur()
        m.reduire = true
        m.isoler(try MoteurPiecesTests.indice(e, "Salon"))
        MoteurPiecesTests.dessiner(m)
        MoteurPiecesTests.dessiner(m)
        let part = try #require(m.fk["piece:Salon"])
        #expect(part > 0 && part < 1, "en plein fondu : \(part)")
        var autre = e
        autre.apparences["Apple TV 4K"] = DessinNoeud.Apparence(forme: .anneau, couleur: .appareil(.disparu))
        m.installerMaintenant(autre)
        #expect(m.entree == autre && m.fk["piece:Salon"] == part && m.estIsolee)
    }
}
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// Ligne de niveau : pieces seules, routeurs, noms masques (un, plusieurs), piece isolee.
```

par :

```swift
    /// Ligne de niveau : pieces seules, routeurs, noms masques (un, plusieurs), piece isolee, etage isole.
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        #expect(LigneNiveauVue.texte(.lisibles) == String(localized: "Tous les noms sont lisibles"))
```

par :

```swift
        #expect(LigneNiveauVue.texte(.etageIsole("Étage")).contains("Étage"))
        #expect(LigneNiveauVue.texte(.lisibles) == String(localized: "Tous les noms sont lisibles"))
```

Dans `MaillageThreadTests/LegendePiecesTests.swift`, remplacer :

```swift
        let lignes: [LigneNiveau] = [.pieces, .routeurs, .masques(1), .masques(12), .lisibles, .isolee("Salon")]
```

par :

```swift
        let lignes: [LigneNiveau] = [.pieces, .routeurs, .masques(1), .masques(12), .lisibles, .isolee("Salon"),
                                     .etageIsole("Rez-de-chaussée")]
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/PlacementNomsTests MaillageCoeurTests/SceneProjeteeTests MaillageThreadTests/IsolementTests MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/LegendePiecesTests`
Expected: la compilation des tests échoue (`IsolementTests.swift`, `PlacementNomsTests.swift`, `SceneProjeteeTests.swift`), par exemple avec `error: extra arguments at positions #11, #12, #13, #14 in call` et `error: value of type 'EtatAnime' has no member 'se'` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** Le placement des noms et la projection (les voiles), puis le moteur (l'isolement, le fil, les clics, le menu, les fondus par clé), la fenêtre (le menu natif, le fil, la ligne de niveau), le rendu (le disque éclairci, le nom souligné).

Dans `MaillageCoeur/Scene/PlacementNoms.swift`, remplacer :

```swift
    /// Zoom semantique et priorites (spec, section 6) : noms voulus, priorites, pales et forts, selon
    /// le niveau du zoom, le survol, la selection et l'isolement d'une piece. `fk` : part propre a
    /// chaque piece de l'isolement ; `s` : isolement general (0 a 1) ; `t` : bascule (0 : 2D, 1 : 3D).
    public static func regler(_ etiquettes: inout [Etiquette], scene: ScenePieces, niveau: NiveauZoom,
                              survol: String?, selection: String?, focus: Int?, isolee: Bool, fk: [Double],
                              s: Double, t: Double) {
        let fo = 1 - CameraScene.rampe(s)
```

par :

```swift
    /// Zoom semantique et priorites (spec, section 6 ; polissage C, section 5) : noms voulus, priorites, pales et
    /// forts, selon le niveau du zoom, le survol, la selection et l'isolement. `focus` : la piece en vue (isolee, ou
    /// qui l'etait, pendant le retour) ; `isolee` : une piece est visee ; `fk` : part propre a chaque piece de
    /// l'isolement ; `s` : isolement general (0 a 1) ; `t` : bascule (0 : 2D, 1 : 3D) ; `se` : isolement d'un
    /// etage ; `voiles` : le voile de chaque plateau (`SceneProjetee.voilesEtages`) ; `etageIsole` : l'etage vise ;
    /// `survolNomEtage` : le nom d'etage sous le pointeur, souligne.
    ///
    /// Les noms des appareils suivent l'etat d'arrivee (triage A, n° 8) : une piece visee, les siens ; sinon, selon le
    /// zoom, ceux de la maison, ou de l'etage vise seulement. Celui de l'appareil survole ou choisi est toujours voulu.
    /// Les noms d'etage restent voulus, pales et cliquables pendant un isolement.
    public static func regler(_ etiquettes: inout [Etiquette], scene: ScenePieces, niveau: NiveauZoom,
                              survol: String?, selection: String?, focus: Int?, isolee: Bool, fk: [Double],
                              s: Double, t: Double, se: Double = 0, voiles: [Double] = [], etageIsole: Int? = nil,
                              survolNomEtage: Int? = nil) {
        let fo = 1 - CameraScene.rampe(s)
        func voile(_ e: Int) -> Double { e < voiles.count ? voiles[e] : 1 }
```

Dans `MaillageCoeur/Scene/PlacementNoms.swift`, remplacer :

```swift
                etiquettes[j].voulu = survol == id
                    || (isolee ? part > 0.6 : focus == nil && (niveau == .tous || (niveau == .routeurs && n.rang <= 2)))
                etiquettes[j].prio = survol == id ? 2 : n.chef ? 5 : n.rang <= 2 ? 6 : 7
                etiquettes[j].fort = survol == id || selection == id
            case .piece(let i):
                let pale = focus != nil && (i < fk.count ? fk[i] : 0) < 0.5 && s > 0.3
                etiquettes[j].voulu = true
                etiquettes[j].pale = pale
                etiquettes[j].prio = pale ? 8 : 4
            case .etage:
                etiquettes[j].voulu = fo > 0.5
            case .maison:
                etiquettes[j].voulu = fo > 0.5 && t > 0.4
```

par :

```swift
                let vise = survol == id || selection == id
                let arrivee = etageIsole.map { $0 == scene.pieces[n.piece].etage } ?? true
                etiquettes[j].voulu = vise
                    || (isolee ? part > 0.6 : arrivee && (niveau == .tous || (niveau == .routeurs && n.rang <= 2)))
                etiquettes[j].prio = vise ? 2 : n.chef ? 5 : n.rang <= 2 ? 6 : 7
                etiquettes[j].fort = vise
            case .piece(let i):
                let pale = (focus != nil && (i < fk.count ? fk[i] : 0) < 0.5 && s > 0.3)
                    || (i < scene.pieces.count && voile(scene.pieces[i].etage) < 0.6)
                etiquettes[j].voulu = true
                etiquettes[j].pale = pale
                etiquettes[j].prio = pale ? 8 : 4
            case .etage(let e):
                etiquettes[j].voulu = true
                etiquettes[j].pale = voile(e) < 0.6 || (focus != nil && s > 0.3)
                etiquettes[j].fort = survolNomEtage == e
            case .maison:
                etiquettes[j].voulu = fo > 0.5 && CameraScene.rampe(se) < 0.5 && t > 0.4
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
    public var selection: String?

    public init(t: Double = 0, s: Double = 0, fk: [Double], focus: Int? = nil, survol: String? = nil,
                selection: String? = nil) {
```

par :

```swift
    public var selection: String?
    /// Isolement d'un etage (polissage C, section 5) : 0 a 1, lineaire ; part propre a chaque plateau, de 0 a 1. Une
    /// piece isolee isole aussi son etage, le cran « etage » du fil.
    public var se: Double
    public var ek: [Double]
    /// Disque cliquable sous le pointeur : il s'eclaircit.
    public var survolEtage: Int?

    public init(t: Double = 0, s: Double = 0, fk: [Double], focus: Int? = nil, survol: String? = nil,
                selection: String? = nil, se: Double = 0, ek: [Double] = [], survolEtage: Int? = nil) {
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        self.selection = selection
```

par :

```swift
        self.selection = selection
        self.se = se
        self.ek = ek
        self.survolEtage = survolEtage
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
    }

    public struct Equateur: Sendable {
```

par :

```swift
        /// Disque cliquable sous le pointeur : une fois et demie plus clair.
        public var eclaire: Bool
    }

    public struct Equateur: Sendable {
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
    public var equateur: Equateur?
```

par :

```swift
    /// Voile de chaque plateau dans l'isolement d'un etage : 1 net, 0,15 estompe (polissage C, section 5.1).
    public var voilesEtages: [Double] = []
    public var equateur: Equateur?
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        let oeil = orbite.oeil
```

par :

```swift
        let oeil = orbite.oeil
        // Isolement d'un etage (polissage C, section 5) : les autres plateaux, avec leurs pieces, leurs pastilles et
        // leurs liens, descendent a 15 % ; la sphere s'efface. Une piece isolee laisse les disques a 15 % : on peut
        // cliquer dessus.
        let ee = CameraScene.rampe(etat.se)
        let ve = g.rayons.indices.map { e in 1 - 0.85 * ee * (1 - CameraScene.rampe(e < etat.ek.count ? etat.ek[e] : 0)) }
        voilesEtages = ve
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
                                    disque: proj.disque(c, r), opacite: fo, profondeur: proj.profondeur(c)))
```

par :

```swift
                                    disque: proj.disque(c, r), opacite: min(ve[e], 1 - 0.85 * es),
                                    profondeur: proj.profondeur(c), eclaire: etat.survolEtage == e))
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        if 0.18 * t * fo > 0.002 {
            equateur = Equateur(contour: proj.polyligne(Self.cercle(g.centreSphere, rs, 192), fermee: true),
                                opacite: 0.18 * t * fo, profondeur: proj.profondeur(g.centreSphere))
        }
        let force = t * t * fo
```

par :

```swift
        if 0.18 * t * fo * (1 - ee) > 0.002 {
            equateur = Equateur(contour: proj.polyligne(Self.cercle(g.centreSphere, rs, 192), fermee: true),
                                opacite: 0.18 * t * fo * (1 - ee), profondeur: proj.profondeur(g.centreSphere))
        }
        let force = t * t * fo * (1 - ee)
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
            let vis = 1 - 0.85 * (1 - voile)
```

par :

```swift
            let vis = min(1 - 0.85 * (1 - voile), pc.etage < ve.count ? ve[pc.etage] : 1)
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        // Pastilles : le rayon suit l'echelle, sans depasser 1,1 fois le rayon naturel, 3 px au moins.
```

par :

```swift
        // Le voile de l'etage d'une piece.
        func voileEtage(_ piece: Int) -> Double {
            let e = scene.pieces[piece].etage
            return e < ve.count ? ve[e] : 1
        }

        // Pastilles : le rayon suit l'echelle, sans depasser 1,1 fois le rayon naturel, 3 px au moins.
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
            disques.append(Disque(noeud: n.id, centre: e, rayon: r, opacite: 1 - 0.8 * (1 - voiles[n.piece]),
```

par :

```swift
            disques.append(Disque(noeud: n.id, centre: e, rayon: r,
                                  opacite: min(1 - 0.8 * (1 - voiles[n.piece]), voileEtage(n.piece)),
```

Dans `MaillageCoeur/Scene/SceneProjetee.swift`, remplacer :

```swift
        // Liens : estompes avec leurs pieces ; eclaires au survol (ou a la selection) d'un bout.
        for l in scene.liens {
            guard let a = mondes[l.de], let b = mondes[l.vers], let (pa, pb) = proj.segment(a, b),
                  let na = scene.noeud(l.de), let nb = scene.noeud(l.vers) else { continue }
            let poids = 1 - 0.85 * (1 - max(voiles[na.piece], voiles[nb.piece]))
```

par :

```swift
        // Liens : estompes avec leurs pieces ; un lien qui touche l'etage isole reste visible, meme vers un autre
        // etage ; eclaires au survol (ou a la selection) d'un bout.
        for l in scene.liens {
            guard let a = mondes[l.de], let b = mondes[l.vers], let (pa, pb) = proj.segment(a, b),
                  let na = scene.noeud(l.de), let nb = scene.noeud(l.vers) else { continue }
            let poids = min(1 - 0.85 * (1 - max(voiles[na.piece], voiles[nb.piece])),
                            max(voileEtage(na.piece), voileEtage(nb.piece)))
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
/// Ligne de niveau, en bas a gauche de la vue (spec de la vue par pieces, section 6).
enum LigneNiveau: Equatable {
    case isolee(String)
```

par :

```swift
/// Ligne de niveau, en haut a gauche de la vue, sous le fil (spec de la vue par pieces, section 6 ; polissage C,
/// section 5.1).
enum LigneNiveau: Equatable {
    case isolee(String)
    case etageIsole(String)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
/// Cible d'un clic droit : un nom d'etage, ou le fond (spec, section 7).
```

par :

```swift
/// Cible d'un clic droit : le nom ou le disque d'un plateau, ou le fond (spec, section 7 ; polissage C, section 1.3).
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
/// Moteur de la vue par pieces (spec, sections 4 a 7) : la scene recue et sa disposition, calculee
```

par :

```swift
/// Ce que montre la vue (polissage C, section 5) : la maison, un etage isole (sa cle), ou une piece isolee (sa cle),
/// avec sa provenance : l'etage isole d'ou on l'a ouverte, nil depuis la maison.
enum Isolement: Equatable {
    case maison
    case etage(String)
    case piece(String, provenance: String?)
}

/// Ce que vise un clic, du plus fort au plus faible (polissage C, section 5.1) : un appareil, une piece (son bloc ou
/// son nom), le nom d'un etage, son disque (en 3D, le plus proche sur le rayon), le fond.
enum CibleClic: Equatable {
    case appareil(String)
    case piece(Int)
    case nomEtage(Int)
    case disque(Int)
    case fond
}

/// Le fil (polissage C, section 5.3) : « Maison », puis l'etage isole, ou l'etage et la piece isolee ; chaque cran
/// au-dessus du dernier mene a son niveau. Une maison d'un seul plateau n'a pas de cran « etage ».
struct Fil: Equatable {
    struct Cran: Equatable {
        var nom: String
        var etage: Int
    }

    var etage: Cran?
    var piece: String?
}

/// Le menu du clic droit sur le nom ou le disque d'un plateau (polissage C, section 1.3) : son nom, en tete ; « Monter
/// d'un etage » et « Descendre d'un etage », actifs pour un etage hors du haut et du bas de la pile ; « Au meme niveau
/// que », les autres niveaux, chacun nomme par son etage principal, celui de la zone coche ; « Hors de la maison » et
/// « Sur son propre niveau », pour une zone a cote.
struct MenuEtage: Equatable {
    struct Niveau: Equatable {
        var niveau: Int
        var nom: String
        var coche: Bool
    }

    var nom: String
    var monter: Bool
    var descendre: Bool
    var niveaux: [Niveau]
    var aCote: Bool
    var dehors: Bool
}

/// Le curseur au-dessus de la vue : une main sur ce qui se clique (polissage C, maquette).
enum Curseur: Equatable {
    case fleche
    case main
}

/// Moteur de la vue par pieces (spec, sections 4 a 7) : la scene recue et sa disposition, calculee
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Nom de la piece isolee (le fil) ; nil sinon.
    private(set) var isolee: String?
```

par :

```swift
    /// Nom de la piece isolee ; nil sinon.
    private(set) var isolee: String?
    /// Ce que montre la vue, et sa provenance (polissage C, section 5) ; le fil qui le dit.
    private(set) var isolement = Isolement.maison
    private(set) var fil = Fil()
    private(set) var curseurForme = Curseur.fleche
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    @ObservationIgnored private(set) var fk: [Double] = []
```

par :

```swift
    /// Part propre a chaque piece de l'isolement, gardee par cle (triage A, n° 9).
    @ObservationIgnored private(set) var fk: [String: Double] = [:]
    /// Isolement d'un etage (polissage C, section 5) : `se` general, `ek` propre a chaque plateau, par cle ; l'etage
    /// en vue (isole, celui de la piece isolee, ou qui l'etait, pendant le retour).
    @ObservationIgnored private(set) var se = 0.0
    @ObservationIgnored private var seCible = 0.0
    @ObservationIgnored private var seDepart = 0.0
    @ObservationIgnored private var seDebut = 0.0
    @ObservationIgnored private(set) var ek: [String: Double] = [:]
    @ObservationIgnored private(set) var etageEnVue: String?
    /// Disque cliquable et nom d'etage sous le pointeur.
    @ObservationIgnored private(set) var survolEtage: Int?
    @ObservationIgnored private(set) var survolNomEtage: Int?
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Ce que vise un vol : la vue d'ensemble, ou une piece (sa cle).
    private enum Visee {
        case ensemble
        case piece(String)
```

par :

```swift
    /// Ce que vise un vol : la vue d'ensemble, une piece ou un etage (sa cle).
    private enum Visee {
        case ensemble
        case piece(String)
        case etage(String)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    var aLaVueDEnsemble: Bool { pret && !vueTouchee && focus == nil && !enMouvement }
```

par :

```swift
    var aLaVueDEnsemble: Bool { pret && !vueTouchee && sansIsolement && !enMouvement }
    /// Ni piece ni etage isoles, ni en train d'etre quittes.
    var sansIsolement: Bool { isolement == .maison && focus == nil && etageEnVue == nil }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        fk = Array(repeating: 0, count: scene.pieces.count)
        if let cle = ancienFocus, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            focus = i
            fk[i] = 1
```

par :

```swift
        // Les parts de l'isolement sont gardees par cle (triage A, n° 9) : un releve recu pendant un fondu ne remet pas
        // la piece a pleine taille. Une piece ou un etage isoles qui disparaissent rendent la maison.
        let clesPieces = Set(scene.pieces.map(\.id)), clesEtages = Set(scene.etages.map(\.id))
        fk = fk.filter { clesPieces.contains($0.key) }
        ek = ek.filter { clesEtages.contains($0.key) }
        if let cle = ancienFocus, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            focus = i
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        }
        textes = Self.textes(e, focus: focus)
```

par :

```swift
            if case .piece = isolement { isolement = .maison }
        }
        if let k = etageEnVue, !clesEtages.contains(k) {
            etageEnVue = nil
            se = 0
            seCible = 0
            if case .etage = isolement { isolement = .maison }
        }
        textes = Self.textes(e, focus: focus)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if !pret {
            pret = true
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        } else if !vueTouchee && focus == nil {
```

par :

```swift
        majFil()
        if !pret {
            pret = true
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        } else if !vueTouchee && sansIsolement {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// « Monter d'un etage » (+1) ou « Descendre d'un etage » (-1) : echange l'etage avec son voisin,
    /// et garde l'ordre.
    func deplacerEtage(_ i: Int, de pas: Int) {
        guard let e = entree else { return }
        var ordre = e.scene.etages.map(\.id)
        let j = i + pas
        guard ordre.indices.contains(i), ordre.indices.contains(j) else { return }
        ordre.swapAt(i, j)
        places.ordonner(ordre, domicile: e.domicile)
        enregistrer()
    }

    func peutDeplacerEtage(_ i: Int, de pas: Int) -> Bool {
        guard let n = scene?.etages.count else { return false }
        return (0..<n).contains(i) && (0..<n).contains(i + pas)
```

par :

```swift
    // MARK: Menu du clic droit (polissage C, section 1.3)

    /// Le menu du nom ou du disque du plateau `e`.
    func menuEtage(_ e: Int) -> MenuEtage? {
        guard let scene, e < scene.etages.count else { return nil }
        let n = scene.niveaux, cle = scene.etages[e].id
        guard let niveau = n.niveau(cle) else { return nil }
        let principal = n.estPrincipal(cle)
        func nom(_ c: String) -> String {
            scene.etages.firstIndex { $0.id == c }.map { LibellesNoeuds.nom(scene.etages[$0].nom) } ?? c
        }
        let niveaux = n.liste.indices.filter { !(principal && $0 == niveau) }.map { i in
            MenuEtage.Niveau(niveau: i, nom: nom(n.liste[i][0]), coche: !principal && i == niveau)
        }
        return MenuEtage(nom: nom(cle), monter: principal && niveau < n.liste.count - 1, descendre: principal && niveau > 0,
                         niveaux: niveaux, aCote: !principal, dehors: n.dehors(cle))
    }

    /// Un choix du menu : le nouvel ordre des plateaux et les nouveaux choix de niveau, gardes ; la scene suivante les
    /// prend (`EntreeScene`), et les plateaux glissent vers leur nouvelle place.
    private func ranger(_ e: Int, _ operation: (Niveaux, String, [String: PlacesGardees.ACote]) -> Rangement?) {
        guard let entree, e < entree.scene.etages.count,
              let r = operation(entree.scene.niveaux, entree.scene.etages[e].id,
                                places.maison(entree.domicile).aCote) else { return }
        places.ranger(r, domicile: entree.domicile)
        enregistrer()
    }

    /// « Monter d'un etage » (+1) ou « Descendre d'un etage » (-1) : le niveau entier de l'etage, zones a cote
    /// comprises, change de place avec son voisin.
    func deplacerEtage(_ e: Int, de pas: Int) {
        ranger(e) { $0.deplacer($1, de: pas, choix: $2) }
    }

    func peutDeplacerEtage(_ e: Int, de pas: Int) -> Bool {
        menuEtage(e).map { pas > 0 ? $0.monter : $0.descendre } ?? false
    }

    /// « Au meme niveau que » l'etage principal du niveau `niveau`, dans la maison.
    func mettreAuNiveau(_ e: Int, de niveau: Int) {
        ranger(e) { $0.rejoindre($1, niveau: niveau, choix: $2) }
    }

    /// « Hors de la maison », coche ou non.
    func basculerDehors(_ e: Int) {
        ranger(e) { $0.basculerDehors($1, choix: $2) }
    }

    /// « Sur son propre niveau ».
    func mettreSurSonNiveau(_ e: Int) {
        ranger(e) { $0.propreNiveau($1, choix: $2) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Ce que la vue regarde : la piece isolee, ou la cible de la vue d'ensemble.
    private func ancreCamera() -> SIMD3<Double> {
        if let i = focus, let c = centrePiece(i) { return c }
```

par :

```swift
    /// Ce que la vue regarde : la piece isolee, l'etage isole, ou la cible de la vue d'ensemble.
    private func ancreCamera() -> SIMD3<Double> {
        if let i = focus, let c = centrePiece(i) { return c }
        if let k = etageEnVue, let e = scene?.etages.firstIndex(where: { $0.id == k }) { return geometrie.centrePlateau(e, t) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        case .piece(let cle): scene?.pieces.firstIndex { $0.id == cle }.flatMap(volVersPiece)
```

par :

```swift
        case .piece(let cle): scene?.pieces.firstIndex { $0.id == cle }.flatMap(volVersPiece)
        case .etage(let cle): scene?.etages.firstIndex { $0.id == cle }.map(volVersEtage)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        fk = fk.map { _ in 0 }
```

par :

```swift
        fk = [:]
        etageEnVue = nil
        se = 0
        seCible = 0
        ek = [:]
        isolement = .maison
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        // Vers la 2D, l'envol se pose sur la grille de la zone visible du moment (polissage C, section 3.5).
```

par :

```swift
        majFil()
        // Vers la 2D, l'envol se pose sur la grille de la zone visible du moment (polissage C, section 3.5).
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// autres s'estompent, ses reperes « ailleurs » apparaissent.
    func isoler(_ i: Int) {
        guard let scene, i < scene.pieces.count, !(focus == i && sCible == 1) else { return }
```

par :

```swift
    /// autres s'estompent, ses reperes « ailleurs » apparaissent. Son etage est celui du fil : les disques des
    /// autres etages restent a 15 %, cliquables (polissage C, section 5.2). La provenance (section 5.4) : depuis la
    /// maison ou un etage isole, ce que l'on quitte ; d'une piece a une autre, elle reste, sauf vers une piece d'un
    /// autre etage : la maison.
    func isoler(_ i: Int) {
        guard let scene, i < scene.pieces.count, !(focus == i && sCible == 1) else { return }
        let piece = scene.pieces[i], etage = scene.etages[piece.etage].id
        let provenance: String? = switch isolement {
        case .maison: nil
        case .etage(let k): k
        case .piece(_, let p): p == etage ? p : nil
        }
        isolement = .piece(piece.id, provenance: provenance)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        if let v = volVersPiece(i) { voler(v, visee: .piece(scene.pieces[i].id)) }
```

par :

```swift
        if scene.etages.count > 1 { viserEtage(etage) }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        majFil()
        if let v = volVersPiece(i) { voler(v, visee: .piece(piece.id)) }
    }

    /// Isole un etage (polissage C, section 5.1) : un vol de 1,3 s cadre son plateau, bande de son nom comprise ; les
    /// autres plateaux s'estompent a 15 %, la sphere et « ⌂ Maison » s'effacent, la rotation lente s'arrete. Une
    /// piece isolee est relachee. Rien dans une maison d'un seul plateau, ni pendant l'envol.
    func allerEtage(_ e: Int) {
        guard let scene, scene.etages.count > 1, e < scene.etages.count, envol == nil, fondu == nil else { return }
        quitterPiece()
        let cle = scene.etages[e].id
        isolement = .etage(cle)
        viserEtage(cle)
        majFil()
        voler(volVersEtage(e), visee: .etage(cle))
    }

    /// Vol vers un etage isole.
    private func volVersEtage(_ e: Int) -> Vol {
        CameraScene.volVersEtage(orbite, geometrie, etage: e, aspect: aspect, u: t, troisD: t == 1)
    }

    /// L'isolement d'etage vise `cle` : son plateau reste net.
    private func viserEtage(_ cle: String) {
        etageEnVue = cle
        if seCible != 1 {
            seDepart = se
            seCible = 1
            seDebut = Self.maintenant()
        }
    }

    /// La piece isolee est relachee : son isolement redescend en 1,3 s.
    private func quitterPiece() {
        guard focus != nil, sCible != 0 else { return }
        sDepart = s
        sCible = 0
        sDebut = Self.maintenant()
        isolee = nil
        // Retour lance avant la premiere image de l'isolement : `s` est deja a 0, et l'horloge ne
        // finirait jamais ce retour.
        if s == 0 { finirRetour() }
    }

    /// L'etage isole est relache.
    private func quitterEtage() {
        guard seCible != 0 else { return }
        seDepart = se
        seCible = 0
        seDebut = Self.maintenant()
        if se == 0 { etageEnVue = nil }
    }

    /// Le fil de ce que montre la vue.
    private func majFil() {
        var f = Fil()
        if let scene {
            func cran(_ e: Int) -> Fil.Cran { Fil.Cran(nom: textes.etages[e] ?? "", etage: e) }
            switch isolement {
            case .maison:
                break
            case .etage(let cle):
                f.etage = scene.etages.firstIndex { $0.id == cle }.map(cran)
            case .piece(let cle, _):
                if let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
                    f.piece = textes.pieces[i]?.nom
                    if scene.etages.count > 1 { f.etage = cran(scene.pieces[i].etage) }
                }
            }
        }
        if f != fil { fil = f }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Retour a la vue d'ensemble (clic a cote, Echap, « Maison » dans le fil, double-clic sur le fond) :
    /// la piece isolee est relachee, le zoom et le deplacement annules, par un vol de 1,3 s. « Reduire
    /// les animations » : tout de suite, ou par un fondu de 0,3 s (`enFondu`, le double-clic).
    func sortir(enFondu: Bool = false) {
        if focus != nil, sCible != 0 {
            sDepart = s
            sCible = 0
            sDebut = Self.maintenant()
            isolee = nil
            // Retour lance avant la premiere image de l'isolement : `s` est deja a 0, et l'horloge ne
            // finirait jamais ce retour.
            if s == 0 { finirRetour() }
        } else if !vueTouchee {
            return
        }
```

par :

```swift
    /// Retour a la maison (« Maison » dans le fil, double-clic, ou en remontant) : la piece et l'etage isoles sont
    /// relaches, le zoom et le deplacement annules, par un vol de 1,3 s qui part de la pose courante. « Reduire les
    /// animations » : tout de suite, ou par un fondu de 0,3 s (`enFondu`, le double-clic).
    func versMaison(enFondu: Bool = false) {
        guard isolement != .maison || focus != nil || etageEnVue != nil || vueTouchee else { return }
        quitterPiece()
        quitterEtage()
        isolement = .maison
        majFil()
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Fin du retour d'un isolement : plus de piece isolee, ni de reperes « ailleurs ».
```

par :

```swift
    /// Echap et le clic a cote remontent d'ou l'on vient (polissage C, section 5.4) : une piece ouverte depuis un etage
    /// isole, a l'etage de la piece ; une autre piece, ou un etage, a la maison. A la maison, Echap ramene une vue
    /// zoomee ou deplacee a la vue d'ensemble (`clavier`) ; le clic a cote ne fait rien. Rien pendant l'envol.
    func remonter(clavier: Bool = true) {
        guard envol == nil, fondu == nil else { return }
        switch isolement {
        case .piece(let cle, let provenance):
            if provenance != nil, let scene, scene.etages.count > 1, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
                allerEtage(scene.pieces[i].etage)
            } else {
                versMaison()
            }
        case .etage:
            versMaison()
        case .maison:
            if clavier { versMaison() }
        }
    }

    /// Echap.
    func sortir() {
        remonter(clavier: true)
    }

    /// Fin du retour d'un isolement : plus de piece isolee, ni de reperes « ailleurs ».
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Double-clic sur le fond (precision 17 du plan 4b) : retour a la vue d'ensemble d'un geste. Le
    /// premier clic a deja ferme la fiche et relache la piece isolee (clic a cote) ; le second annule le
    /// zoom et le deplacement.
    func doubleCliquer() {
        sortir(enFondu: true)
```

par :

```swift
    /// Double-clic sur le fond ou sur un disque (precision 17 du plan 4b ; polissage C, section 5.4) : retour a la vue
    /// d'ensemble d'un geste, de partout. Le premier clic a deja agi seul ; le second relache ce qui reste isole et
    /// annule le zoom et le deplacement.
    func doubleCliquer() {
        versMaison(enFondu: true)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            if pret && !enMouvement && !vueTouchee && focus == nil && !fige { recadrer() }
```

par :

```swift
            if aLaVueDEnsemble && !fige { recadrer() }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        let etat = EtatAnime(t: t, s: s, fk: fk, focus: focus, survol: survol, selection: selection)
        let p = SceneProjetee(scene: scene, cartes: cartes, positions: positions, geometrie: geometrie, etat: etat,
                              orbite: orbite, cadre: cadre)
        PlacementNoms.regler(&etiquettes, scene: scene, niveau: p.niveau, survol: survol, selection: selection, focus: focus,
                             isolee: estIsolee, fk: fk, s: s, t: t)
```

par :

```swift
        let parts = scene.pieces.map { fk[$0.id] ?? 0 }
        let etat = EtatAnime(t: t, s: s, fk: parts, focus: focus, survol: survol, selection: selection, se: se,
                             ek: scene.etages.map { ek[$0.id] ?? 0 }, survolEtage: survolEtage)
        let p = SceneProjetee(scene: scene, cartes: cartes, positions: positions, geometrie: geometrie, etat: etat,
                              orbite: orbite, cadre: cadre)
        PlacementNoms.regler(&etiquettes, scene: scene, niveau: p.niveau, survol: survol, selection: selection, focus: focus,
                             isolee: estIsolee, fk: parts, s: s, t: t, se: se, voiles: p.voilesEtages,
                             etageIsole: indiceEtageIsole, survolNomEtage: survolNomEtage)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    private func ligne(_ niveau: NiveauZoom, ancres: [CGRect?]) -> LigneNiveau {
        if estIsolee, let nom = isolee { return .isolee(nom) }
```

par :

```swift
    /// L'etage vise par l'isolement, dans la scene ; nil : la maison ou une piece.
    var indiceEtageIsole: Int? {
        guard case .etage(let cle) = isolement else { return nil }
        return scene?.etages.firstIndex { $0.id == cle }
    }

    private func ligne(_ niveau: NiveauZoom, ancres: [CGRect?]) -> LigneNiveau {
        if estIsolee, let nom = isolee { return .isolee(nom) }
        if let e = indiceEtageIsole, let nom = textes.etages[e] { return .etageIsole(nom) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        for i in fk.indices {
            let c: Double = focus == i && sCible == 1 ? 1 : 0
            fk[i] += (c - fk[i]) * min(1, dt * 3.5)
            if abs(c - fk[i]) < 1e-3 { fk[i] = c }
```

par :

```swift
        if se != seCible {
            let r = min(1, max(0, (now - seDebut) / CameraScene.dureeVol))
            se = seDepart + (seCible - seDepart) * r
            if r >= 1 {
                se = seCible
                if se == 0 { etageEnVue = nil }
            }
        }
        // Les parts propres, par cle : celle de la piece isolee et celle de l'etage en vue tendent vers 1.
        if let scene {
            let piece = focus.flatMap { $0 < scene.pieces.count && sCible == 1 ? scene.pieces[$0].id : nil }
            func tendre(_ x: Double?, vers c: Double) -> Double {
                var f = x ?? 0
                f += (c - f) * min(1, dt * 3.5)
                return abs(c - f) < 1e-3 ? c : f
            }
            for p in scene.pieces { fk[p.id] = tendre(fk[p.id], vers: p.id == piece ? 1 : 0) }
            for e in scene.etages { ek[e.id] = tendre(ek[e.id], vers: e.id == etageEnVue ? 1 : 0) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if troisD && t == 1 && rotation && !reduire && focus == nil && geste == nil {
```

par :

```swift
        if troisD && t == 1 && rotation && !reduire && sansIsolement && geste == nil {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if fk.contains(where: { $0 != 0 && $0 != 1 }) { return true }
        if troisD && t == 1 && rotation && !reduire && focus == nil { return true }
```

par :

```swift
        if se != seCible || fk.values.contains(where: { $0 != 0 && $0 != 1 }) || ek.values.contains(where: { $0 != 0 && $0 != 1 }) {
            return true
        }
        if troisD && t == 1 && rotation && !reduire && sansIsolement { return true }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    func survoler(_ p: CGPoint?) {
        curseur = p
        let n = p.flatMap(noeudSous)
        if n != survol {
            survol = n
            reveiller()
        }
```

par :

```swift
    /// Survol : le nom de l'appareil en semi-gras ; un disque cliquable s'eclaircit, le nom d'un etage se souligne ; la
    /// main sur ce qui se clique (polissage C, maquette). Rien pendant l'envol.
    func survoler(_ p: CGPoint?) {
        curseur = p
        let c = envol == nil && fondu == nil ? p.map(cibleClic(en:)) ?? .fond : .fond
        let n: String? = if case .appareil(let id) = c { id } else { nil }
        let disque: Int? = if case .disque(let e) = c, disqueCliquable(e) { e } else { nil }
        let nom: Int? = if case .nomEtage(let e) = c { e } else { nil }
        if n != survol || disque != survolEtage || nom != survolNomEtage {
            survol = n
            survolEtage = disque
            survolNomEtage = nom
            reveiller()
        }
        let main = switch c {
        case .appareil, .piece: true
        case .nomEtage: (scene?.etages.count ?? 0) > 1 || estIsolee
        case .disque(let e): disqueCliquable(e)
        case .fond: false
        }
        let forme: Curseur = main ? .main : .fleche
        if forme != curseurForme { curseurForme = forme }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Piece sous un point : son nom (le nom et le compte de ses appareils), sinon sa boite, la plus proche
```

par :

```swift
    /// Ce que vise un clic en `p`, du plus fort au plus faible (polissage C, section 5.1).
    func cibleClic(en p: CGPoint) -> CibleClic {
        if let n = noeudSous(p) { return .appareil(n) }
        if let i = pieceSous(p) { return .piece(i) }
        if let e = nomEtageSous(p) { return .nomEtage(e) }
        if let e = disqueSous(p) { return .disque(e) }
        return .fond
    }

    /// Nom d'etage sous un point (`marge` points autour).
    func nomEtageSous(_ p: CGPoint, marge: CGFloat = 0) -> Int? {
        for l in etiquettes where l.vu && l.rect.insetBy(dx: -marge, dy: -marge).contains(p) {
            if case .etage(let e) = l.genre { return e }
        }
        return nil
    }

    /// Disque d'un plateau sous un point : en 3D, le plus proche sur le rayon, au point ou il le rencontre.
    func disqueSous(_ p: CGPoint) -> Int? {
        guard let projetee else { return nil }
        let proj = ProjectionScene(orbite, cadre: cadre)
        var meilleur: (etage: Int, profondeur: Double)?
        for pl in projetee.plateaux where pl.etage < geometrie.rayons.count && SceneProjetee.contient(pl.polygone, p) {
            let point = proj.sol(p, hauteur: geometrie.centrePlateau(pl.etage, t).y)
            let d = point.map { proj.profondeur($0) } ?? pl.profondeur
            if d < meilleur?.profondeur ?? .infinity { meilleur = (pl.etage, d) }
        }
        return meilleur?.etage
    }

    /// Un clic sur ce disque fait quelque chose (polissage C, section 5.4) : sauf celui de l'etage isole, entre ses
    /// pieces ; dans une maison d'un seul plateau, seulement depuis une piece isolee, pour remonter.
    func disqueCliquable(_ e: Int) -> Bool {
        guard let scene, e < scene.etages.count else { return false }
        return scene.etages.count > 1 ? estIsolee || isolement != .etage(scene.etages[e].id) : estIsolee
    }

    /// Piece sous un point : son nom (le nom et le compte de ses appareils), sinon sa boite, la plus proche
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Clic droit : un nom d'etage, ou le fond (ni piece, ni son nom, ni noeud).
    func cible(en p: CGPoint) -> CibleMenu {
        for l in etiquettes where l.vu && l.rect.insetBy(dx: -2, dy: -2).contains(p) {
            if case .etage(let i) = l.genre { return .etage(i) }
        }
        if noeudSous(p) == nil && pieceSous(p) == nil { return .fond }
        return .aucune
```

par :

```swift
    /// Clic droit (polissage C, section 1.3) : le nom d'un etage, a 2 points pres, ou son disque, hors des pieces et
    /// des appareils ; le fond, hors de tout cela ; rien sur une piece ou un appareil.
    func cible(en p: CGPoint) -> CibleMenu {
        if let e = nomEtageSous(p, marge: 2) { return .etage(e) }
        if noeudSous(p) != nil || pieceSous(p) != nil { return .aucune }
        if let e = disqueSous(p) { return .etage(e) }
        return .fond
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            if !estIsolee, !enMouvement, let scene, let i = projetee?.piece(sous: d), i < scene.pieces.count,
               let c = centrePiece(i) {
```

par :

```swift
            // Les pieces de l'etage isole se glissent ; celles des autres etages se cliquent seulement.
            if !estIsolee, !enMouvement, let scene, let i = projetee?.piece(sous: d), i < scene.pieces.count,
               indiceEtageIsole.map({ $0 == scene.pieces[i].etage }) ?? true, let c = centrePiece(i) {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Fin d'un glisser, ou clic. Deux clics sur le fond, a moins de l'intervalle du double-clic de
    /// macOS et de 5 points : le second est un double-clic ; le premier a agi comme un clic simple. Une
```

par :

```swift
    /// Fin d'un glisser, ou clic. Deux clics sur le fond ou sur un disque, a moins de l'intervalle du double-clic
    /// de macOS et de 5 points : le second est un double-clic ; le premier a agi comme un clic simple. Une
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            let fond = noeudSous(p) == nil && pieceSous(p) == nil
```

par :

```swift
            let fond = switch cibleClic(en: p) {
            case .fond, .disque: true
            default: false
            }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Clic sans glisser : un appareil ou son nom ouvre sa fiche ; une piece ou son nom l'isole (en piece isolee,
    /// une autre piece y mene, meme pendant le vol) ; a cote des pieces, la fiche se ferme et la vue revient a la
    /// maison. Rien pendant l'envol.
    func cliquer(_ p: CGPoint) {
        guard envol == nil, fondu == nil else { return }
        if let n = noeudSous(p) {
            selection = n
            return
        }
        let i = pieceSous(p)
        if focus != nil {
            if let i {
                if i != focus || sCible == 0 { isoler(i) }
            } else {
                selection = nil
                sortir()
            }
        } else if let i {
            isoler(i)
        } else {
            selection = nil
        }
```

par :

```swift
    /// Clic sans glisser, selon sa cible (polissage C, sections 5.1 et 5.4) : un appareil ou son nom ouvre sa fiche ;
    /// une piece ou son nom l'isole (en piece isolee, une autre piece y mene, meme pendant le vol) ; le nom ou le
    /// disque d'un etage l'isole ; a cote, la fiche se ferme et la vue remonte d'ou elle vient. Rien pendant l'envol.
    func cliquer(_ p: CGPoint) {
        guard envol == nil, fondu == nil else { return }
        switch cibleClic(en: p) {
        case .appareil(let n):
            selection = n
        case .piece(let i):
            if !(focus == i && sCible == 1) { isoler(i) }
        case .nomEtage(let e):
            cliquerEtage(e, disque: false)
        case .disque(let e):
            cliquerEtage(e, disque: true)
        case .fond:
            selection = nil
            remonter(clavier: false)
        }
    }

    /// Clic sur le nom ou le disque d'un etage : il l'isole ; son propre disque, l'etage isole, entre les pieces, ne
    /// fait rien. Maison d'un seul plateau : seulement depuis une piece isolee, pour remonter a la maison.
    private func cliquerEtage(_ e: Int, disque: Bool) {
        guard let scene, e < scene.etages.count else { return }
        guard scene.etages.count > 1 else {
            if estIsolee { versMaison() }
            return
        }
        if disque, isolement == .etage(scene.etages[e].id) { return }
        allerEtage(e)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    func poserIsolement(_ i: Int) {
        guard let scene, i < scene.pieces.count else { return }
```

par :

```swift
    /// Une piece isolee, au bout de son vol ; `depuisEtage` : ouverte depuis son etage isole (sa provenance).
    func poserIsolement(_ i: Int, depuisEtage: Bool = false) {
        guard let scene, i < scene.pieces.count else { return }
        let etage = scene.etages[scene.pieces[i].etage].id
        isolement = .piece(scene.pieces[i].id, provenance: depuisEtage ? etage : nil)
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        fk[i] = 1
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        if let v = volVersPiece(i) { orbite = v.orbite(1, depuis: orbite) }
    }

    func poserSurvol(_ id: String?) { survol = id }
```

par :

```swift
        fk[scene.pieces[i].id] = 1
        if scene.etages.count > 1 {
            etageEnVue = etage
            se = 1
            seCible = 1
            ek[etage] = 1
        }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        majFil()
        if let v = volVersPiece(i) { orbite = v.orbite(1, depuis: orbite) }
    }

    /// Un etage isole, au bout de son vol.
    func poserEtageIsole(_ e: Int) {
        guard let scene, scene.etages.count > 1, e < scene.etages.count else { return }
        let cle = scene.etages[e].id
        isolement = .etage(cle)
        etageEnVue = cle
        se = 1
        seCible = 1
        ek[cle] = 1
        majFil()
        orbite = volVersEtage(e).orbite(1, depuis: orbite)
    }

    func poserSurvol(_ id: String?) { survol = id }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Centre du bloc d'une piece, dans le monde.
```

par :

```swift
    func poserInclinaison(_ i: Double) { orbite.inclinaison = i }

    /// Centre du bloc d'une piece, dans le monde.
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        .onContinuousHover { phase in
```

par :

```swift
        // La main sur ce qui se clique (polissage C, maquette).
        .pointerStyle(moteur.curseurForme == .main ? .link : nil)
        .onContinuousHover { phase in
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
/// Clics droits : sur un nom d'etage, « Monter d'un etage » et « Descendre d'un etage » ; sur le fond,
```

par :

```swift
/// Clics droits, un menu natif (polissage C, section 1.3) : sur le nom ou le disque d'un plateau, son nom en tete,
/// grise ; « Monter d'un etage » et « Descendre d'un etage » ; « Au meme niveau que », un sous-menu des autres niveaux,
/// celui de la zone coche ; « Hors de la maison », une case a cocher ; « Sur son propre niveau ». Sur le fond,
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
            Button("Monter d'un étage") { moteur.deplacerEtage(i, de: 1) }
                .disabled(!moteur.peutDeplacerEtage(i, de: 1))
            Button("Descendre d'un étage") { moteur.deplacerEtage(i, de: -1) }
                .disabled(!moteur.peutDeplacerEtage(i, de: -1))
```

par :

```swift
            if let m = moteur.menuEtage(i) {
                Button(m.nom) {}
                    .disabled(true)
                Button("Monter d'un étage") { moteur.deplacerEtage(i, de: 1) }
                    .disabled(!m.monter)
                Button("Descendre d'un étage") { moteur.deplacerEtage(i, de: -1) }
                    .disabled(!m.descendre)
                Divider()
                Menu("Au même niveau que") {
                    ForEach(m.niveaux, id: \.niveau) { n in
                        Toggle(n.nom, isOn: Binding(get: { n.coche }, set: { _ in moteur.mettreAuNiveau(i, de: n.niveau) }))
                    }
                }
                .disabled(m.niveaux.isEmpty)
                Toggle("Hors de la maison", isOn: Binding(get: { m.dehors }, set: { _ in moteur.basculerDehors(i) }))
                    .disabled(!m.aCote)
                Button("Sur son propre niveau") { moteur.mettreSurSonNiveau(i) }
                    .disabled(!m.aCote)
            }
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
/// Fil, dans la colonne de gauche, sous la ligne des capsules : « Maison », puis « › Salon » en piece
/// isolee ; « Maison » y ramene. Une capture le dessine sans bouton.
```

par :

```swift
/// Fil, dans la colonne de gauche, sous la ligne des capsules (polissage C, section 5.3) : « Maison », puis
/// « › Etage » en etage isole, « › Etage › Salon » en piece isolee (« › Salon » dans une maison d'un seul
/// plateau) ; chaque cran au-dessus du dernier mene a son niveau. Une capture le dessine sans bouton.
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        HStack(spacing: 4) {
            if let piece = moteur.isolee {
                if capture {
                    Text("Maison").foregroundStyle(.link)
                } else {
                    Button("Maison") { moteur.sortir() }
                        .buttonStyle(.link)
                }
                Text(verbatim: "› " + piece)
            } else {
                Text("Maison")
```

par :

```swift
        let fil = moteur.fil
        HStack(spacing: 4) {
            if fil.etage == nil && fil.piece == nil {
                Text("Maison")
            } else {
                lien(Text("Maison")) { moteur.versMaison() }
                if let e = fil.etage {
                    Text(verbatim: "›")
                    if fil.piece != nil {
                        lien(Text(verbatim: e.nom)) { moteur.allerEtage(e.etage) }
                    } else {
                        Text(verbatim: e.nom)
                    }
                }
                if let piece = fil.piece {
                    Text(verbatim: "› " + piece)
                }
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        .foregroundStyle(.primary.opacity(0.9))
```

par :

```swift
        .foregroundStyle(.primary.opacity(0.9))
    }

    /// Un cran qui mene a son niveau : un lien ; dans une capture, son texte, de la couleur d'un lien.
    @ViewBuilder
    private func lien(_ texte: Text, action: @escaping () -> Void) -> some View {
        if capture {
            texte.foregroundStyle(.link)
        } else {
            Button(action: action) { texte }
                .buttonStyle(.link)
        }
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        case .pieces: String(localized: "Vue d'ensemble : les pièces")
```

par :

```swift
        case .etageIsole(let nom):
            String(localized: "Étage isolé : \(nom) · clic sur une pièce ou un autre étage pour y aller, clic à côté ou Échap pour revenir")
        case .pieces: String(localized: "Vue d'ensemble : les pièces")
```

Dans `MaillageThread/Vues/Pieces/RenduCanvas.swift`, remplacer :

```swift
    /// pixel a 0,45) et equateur, du plus loin au plus proche.
```

par :

```swift
    /// pixel a 0,45 ; une fois et demie plus clairs sous le pointeur, quand on peut cliquer le disque) et
    /// equateur, du plus loin au plus proche.
```

Dans `MaillageThread/Vues/Pieces/RenduCanvas.swift`, remplacer :

```swift
        let degrade = Gradient(colors: [palette.zone.opacity(0.26), palette.zone.opacity(0.08)])
        for (_, i) in fond.sorted(by: { $0.0 > $1.0 }) {
```

par :

```swift
        for (_, i) in fond.sorted(by: { $0.0 > $1.0 }) {
```

Dans `MaillageThread/Vues/Pieces/RenduCanvas.swift`, remplacer :

```swift
            let forme = chemin(pl.polygone, ferme: true)
```

par :

```swift
            let k = pl.eclaire ? 1.5 : 1
            let degrade = Gradient(colors: [palette.zone.opacity(0.26 * k), palette.zone.opacity(0.08 * k)])
            let forme = chemin(pl.polygone, ferme: true)
```

Dans `MaillageThread/Vues/Pieces/RenduCanvas.swift`, remplacer :

```swift
                g.stroke(chemin(m, ferme: false), with: .color(palette.zone.opacity(0.45)), lineWidth: pixel)
```

par :

```swift
                g.stroke(chemin(m, ferme: false), with: .color(palette.zone.opacity(min(1, 0.45 * k))), lineWidth: pixel)
```

Dans `MaillageThread/Vues/Pieces/RenduCanvas.swift`, remplacer :

```swift
                guard let nom = image.textes.etages[i] else { continue }
                let texte = cache.resolu(g, "e|" + nom, echelle: e) {
                    StylesNoms.etage(nom).foregroundStyle(palette.zone.opacity(0.95))
```

par :

```swift
                // Souligne sous le pointeur : un clic l'isole (polissage C, section 5.1).
                guard let nom = image.textes.etages[i] else { continue }
                let texte = cache.resolu(g, "e|\(l.fort)|" + nom, echelle: e) {
                    StylesNoms.etage(nom).underline(l.fort).foregroundStyle(palette.zone.opacity(0.95))
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/PlacementNomsTests MaillageCoeurTests/SceneProjeteeTests MaillageThreadTests/IsolementTests MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/LegendePiecesTests`
Expected: `Test run with 16 tests in 2 suites passed` (cœur) et `Test run with 63 tests in 3 suites passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes, en français et en anglais.** Le Step 4 a compilé : mettre le catalogue à jour avec les clés que le compilateur a extraites.

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" outils/synchroniser-textes.sh
```

Expected : `Localizable.xcstrings` reçoit exactement ces 4 clés : « Au même niveau que », « Hors de la maison », « Sur son propre niveau », « Étage isolé : %@ · clic sur une pièce ou un autre étage pour y aller, clic à côté ou Échap pour revenir » ; aucune ne devient périmée.

Puis les traductions, par ce script, qui ajoute les nouvelles à `interface.json` et garde le fichier trié au format de l'outil ; `outils/traduire.py` donne ensuite l'anglais aux nouvelles clés du catalogue :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "Au même niveau que": "On the same level as",
    "Hors de la maison": "Outside the house",
    "Sur son propre niveau": "On its own level",
    "Étage isolé : %@ · clic sur une pièce ou un autre étage pour y aller, clic à côté ou Échap pour revenir":
        "Isolated floor: %@ · click a room or another floor to go there, click outside or press Esc to come back",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

Expected : aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh`
Expected: `Test run with 367 tests in 37 suites passed` (cœur) et `Test run with 335 tests in 30 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 2 tests de plus pour le cœur, 9 tests et 1 suite de plus pour l'app. `nomsPendantUnIsolement` et `etageIsole` s'ajoutent au cœur ; les neuf tests d'`IsolementTests`, une suite de plus, à l'app.

- [ ] **Step 7 : les images de démo : trois changent.** `10-3d-isolee-salon`, `11-2d-isolee-chambre` et `13-2d-fiche-du-chef` changent ; les onze autres restent identiques, octet pour octet, à celles de la tâche 4.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t5"
R="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t4"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polC/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
n=0; for f in "$R"/*.png; do cmp -s "$f" "$D/$(basename "$f")" && n=$((n+1)) || echo "différente : $(basename "$f")"; done; echo "$n identiques sur $(ls "$R" | wc -l | tr -d ' ')"
```

Expected : 14 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`, `13-2d-fiche-du-chef.png`, `14-2d-legende-repliee.png`) ; « l'app a quitté » ; « différente : 10-3d-isolee-salon.png », « différente : 11-2d-isolee-chambre.png », « différente : 13-2d-fiche-du-chef.png » ; « 11 identiques sur 14 ». Si une autre image diffère, s'arrêter : la tâche a changé le rendu.

Regarder `10-3d-isolee-salon.png` (« Maison › Rez-de-chaussée › Salon » dans le fil) et `11-2d-isolee-chambre.png` (« Maison › Étage › Chambre »).

- [ ] **Step 8 : commit.**

```bash
git add MaillageCoeurTests/PlacementNomsTests.swift MaillageCoeurTests/SceneProjeteeTests.swift MaillageThreadTests/IsolementTests.swift MaillageThreadTests/FenetrePiecesTests.swift MaillageThreadTests/LegendePiecesTests.swift MaillageCoeur/Scene/PlacementNoms.swift MaillageCoeur/Scene/SceneProjetee.swift MaillageThread/Vues/Pieces/MoteurPieces.swift MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/Pieces/RenduCanvas.swift MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
git commit -m "Isoler un etage par son nom ou son disque, remonter d'une piece selon sa provenance, donner le fil complet, regler la priorite des clics, ouvrir le menu natif des niveaux sur le nom et le disque, et garder les fondus par cle avec les noms qui suivent l'etat d'arrivee

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: ⌥ + glisser en 3D ; l'envol et les vols partent de la pose exacte de la caméra

**Files:**
- Modify: `MaillageCoeur/Scene/CameraScene.swift`, `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/CameraSceneTests.swift`, `MaillageThreadTests/MoteurPiecesTests.swift`

**Interfaces:**
- Consumes :
  - `Orbite`, `ProjectionScene`, `CameraScene.Envol`, `Vol`, `MoteurPieces.glisser(_:depart:)`, `survoler(_:)`, `ecouter()` (le moniteur local), `Curseur` (tâche 5), `VuePieces`, existants ;
  - dans les tests : `MoteurPiecesTests.moteur`, `dessiner`, `pointDePiece`, existants.
- Produces :
  - `CameraScene.vitesseDeplacement` (0,7), `CameraScene.deplacerDansLEcran(_:glisse:cadre:) -> Orbite` ;
  - `MoteurPieces.glisser(_:depart:option:)`, `survoler(_:option:)`, `changerOption(_:)` ; `Curseur.mainOuverte`, `mainFermee` ; `VuePieces.style(_:) -> PointerStyle?` ;
  - l'envol, les vols et le double-clic partent de la pose exacte de la caméra.

**⌥ + glisser en 3D** (spec, section 6 ; précision 19) : ⌥ lue à l'appui fixe le mode du geste, qui déplace la vue dans le plan de l'écran au lieu de tourner, à 0,7 fois la vitesse du pointeur ; la main ouverte, puis fermée. **La pose exacte** (précision 20) : plus de saut au début de l'envol, d'un vol ou du double-clic après un déplacement.

**Les images de démo ne changent pas.**

- [ ] **Step 1 : écrire les tests.** Le déplacement dans l'écran et la pose exacte, dans le cœur ; ⌥ + glisser dans le moteur.

Dans `MaillageCoeurTests/CameraSceneTests.swift`, remplacer :

```swift
    /// Geometrie : plateaux empiles de 1,5 fois le plus grand rayon ; sphere et boite de la spec.
```

par :

```swift
    /// ⌥ + glisser (polissage C, section 6) : la cible et l'oeil glissent ensemble, parallelement a l'ecran, sans
    /// tourner ; un point a la profondeur de la cible suit le pointeur a 0,7 fois sa vitesse.
    @Test func deplacerDansLEcran() throws {
        var o = CameraScene.canonique(Self.geometrie, aspect: Self.aspect, u: 1)
        o.azimut += 0.7
        let d = CameraScene.deplacerDansLEcran(o, glisse: CGSize(width: 120, height: -45), cadre: Self.cadre)
        #expect(d.distance == o.distance && d.azimut == o.azimut && d.inclinaison == o.inclinaison && d.champ == o.champ)
        #expect(simd_distance(d.oeil - o.oeil, d.cible - o.cible) < 1e-9, "l'oeil suit la cible")
        #expect(abs(simd_dot(d.cible - o.cible, o.arriere)) < 1e-9, "parallele a l'ecran")
        let avant = try #require(ProjectionScene(o, cadre: Self.cadre).ecran(o.cible))
        let apres = try #require(ProjectionScene(d, cadre: Self.cadre).ecran(o.cible))
        #expect(abs((apres.x - avant.x) - 0.7 * 120) < 1e-6 && abs((apres.y - avant.y) + 0.7 * 45) < 1e-6)
        #expect(CameraScene.vitesseDeplacement == 0.7)
    }

    /// Plus de saut (polissage C, section 6) : apres la rotation lente et ⌥ + glisser, l'envol et les vols partent de
    /// la pose exacte de la camera (oeil, cible, champ), a 1e-6 pres.
    @Test func envolEtVolsDepuisLaPoseExacte() {
        let g = Self.geometrie
        var o = CameraScene.canonique(g, aspect: Self.aspect, u: 1)
        o.azimut -= 2.3
        o = CameraScene.deplacerDansLEcran(o, glisse: CGSize(width: -260, height: 140), cadre: Self.cadre)
        let debut = Envol(depuis: o, t: 1, vers: 0, geometrie: g, aspect: Self.aspect).pose(0, geometrie: g, aspect: Self.aspect)
        #expect(debut.t == 1 && debut.orbite.champ == o.champ)
        #expect(simd_distance(debut.orbite.oeil, o.oeil) < 1e-6 && simd_distance(debut.orbite.cible, o.cible) < 1e-6)
        for v in [CameraScene.volVersEnsemble(o, g, aspect: Self.aspect, u: 1, troisD: true),
                  CameraScene.volVersEtage(o, g, etage: 1, aspect: Self.aspect, u: 1, troisD: true)] {
            let p = v.orbite(0, depuis: o)
            #expect(simd_distance(p.oeil, o.oeil) < 1e-6 && simd_distance(p.cible, o.cible) < 1e-6 && p.champ == o.champ)
        }
    }

    /// Geometrie : plateaux empiles de 1,5 fois le plus grand rayon ; sphere et boite de la spec.
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
    /// Ordre des couches : plateaux et equateur, blocs, liens enfant -> parent, liens entre routeurs,
```

par :

```swift
    /// ⌥ + glisser en 3D (polissage C, section 6) : le mode se fixe a l'appui ; ⌥ passe avant le glisser d'une piece,
    /// qui ne bouge pas ; la vue suit le pointeur a 0,7 fois sa vitesse, depuis l'orbite de l'appui ; relacher ⌥ en
    /// route ne change rien. La main ouverte tant que ⌥ est tenue, fermee pendant le geste ; la rotation lente s'arrete
    /// pendant le geste et reprend apres ; le double-clic ramene a la vue d'ensemble. En 2D, ⌥ ne change rien.
    @Test func optionGlisser() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces(troisD: true)
        m.marges = (84, 50)
        m.poserTaille(Self.taille)
        m.installerMaintenant(e)
        for _ in 0..<2 { Self.dessiner(m) }
        let salon = try Self.indice(e, "Salon")
        let d = try Self.pointDePiece(m, salon)
        let avant = m.positions[salon], depart = m.orbite
        m.survoler(d, option: true)
        #expect(m.curseurForme == .mainOuverte)
        m.glisser(d, depart: d, option: true)
        #expect(m.curseurForme == .mainFermee)
        m.glisser(CGPoint(x: d.x + 60, y: d.y + 20), depart: d, option: false)
        #expect(m.positions[salon] == avant, "la piece ne bouge pas")
        #expect(m.orbite == CameraScene.deplacerDansLEcran(depart, glisse: CGSize(width: 60, height: 20), cadre: m.cadre))
        #expect(m.vueTouchee)
        for _ in 0..<2 { Self.dessiner(m) }
        #expect(m.orbite.azimut == depart.azimut, "pas de rotation lente pendant le geste")
        m.relacher(CGPoint(x: d.x + 60, y: d.y + 20))
        #expect(m.curseurForme == .mainOuverte, "⌥ toujours tenue")
        m.changerOption(false)
        #expect(m.curseurForme != .mainOuverte && m.curseurForme != .mainFermee)
        for _ in 0..<2 { Self.dessiner(m) }
        #expect(m.orbite.azimut < depart.azimut, "la rotation lente reprend")
        let fond = CGPoint(x: 5, y: Self.taille.height / 2)
        m.relacher(fond, a: 100)
        m.relacher(fond, a: 100.1)
        #expect(!m.vueTouchee && m.enMouvement, "le double-clic : la vue d'ensemble, deplacement compris")
        let (n, e2) = try Self.moteur()
        let s2 = try Self.indice(e2, "Salon")
        let p2 = try Self.pointDePiece(n, s2)
        let avant2 = n.positions[s2]
        n.survoler(p2, option: true)
        #expect(n.curseurForme == .main, "en 2D, la main sur la piece")
        n.glisser(p2, depart: p2, option: true)
        n.glisser(CGPoint(x: p2.x + 30, y: p2.y), depart: p2, option: true)
        n.relacher(CGPoint(x: p2.x + 30, y: p2.y))
        #expect(n.positions[s2] != avant2, "en 2D, la piece glisse")
    }

    /// Ordre des couches : plateaux et equateur, blocs, liens enfant -> parent, liens entre routeurs,
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/CameraSceneTests MaillageThreadTests/MoteurPiecesTests`
Expected: la compilation des tests échoue (`CameraSceneTests.swift`), par exemple avec `error: type 'CameraScene' has no member 'deplacerDansLEcran'` et `error: type 'CameraScene' has no member 'vitesseDeplacement'` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** Le déplacement dans l'écran, puis la fenêtre (⌥ et les curseurs), le moteur (le geste, la pose exacte).

Dans `MaillageCoeur/Scene/CameraScene.swift`, remplacer :

```swift
    /// Direction de l'oeil pour un vol : celle de la camera en 3D, la verticale en 2D.
```

par :

```swift
    /// ⌥ + glisser en 3D (polissage C, section 6) : la vue suit le pointeur a 0,7 fois sa vitesse, mesuree a la cible.
    public static let vitesseDeplacement = 0.7

    /// La vue deplacee dans le plan de l'ecran, depuis l'orbite `o` de l'appui, pour un deplacement du pointeur de
    /// `glisse` points (vers la droite et vers le bas) : la cible et l'oeil glissent ensemble, parallelement a
    /// l'ecran, sans tourner ; un point a la profondeur de la cible suit le pointeur a 0,7 fois sa vitesse.
    public static func deplacerDansLEcran(_ o: Orbite, glisse: CGSize, cadre: CGRect) -> Orbite {
        let focale = Double(max(1, cadre.height)) / 2 / tan(o.champ * .pi / 360)
        let k = vitesseDeplacement * o.distance / focale
        var r = o
        r.cible += o.droite * (-Double(glisse.width) * k) + o.haut * (Double(glisse.height) * k)
        return r
    }

    /// Direction de l'oeil pour un vol : celle de la camera en 3D, la verticale en 2D.
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !moteur.anime)) { contexte in
```

par :

```swift
    /// Le style du pointeur pour un curseur du moteur : le lien (la main), la main ouverte, la main fermee.
    static func style(_ c: Curseur) -> PointerStyle? {
        switch c {
        case .fleche: nil
        case .main: .link
        case .mainOuverte: .grabIdle
        case .mainFermee: .grabActive
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !moteur.anime)) { contexte in
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        // La main sur ce qui se clique (polissage C, maquette).
        .pointerStyle(moteur.curseurForme == .main ? .link : nil)
        .onContinuousHover { phase in
            switch phase {
            case .active(let p): moteur.survoler(p)
            case .ended: moteur.survoler(nil)
            }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .updating($glisse) { _, g, _ in g = true }
            .onChanged { moteur.glisser($0.location, depart: $0.startLocation) }
```

par :

```swift
        // La main sur ce qui se clique ; en 3D, la main ouverte tant que ⌥ est tenue, fermee pendant ⌥ + glisser
        // (polissage C, section 6) : `NSCursor.openHand` et `closedHand`, que posent ces styles de SwiftUI.
        .pointerStyle(VuePieces.style(moteur.curseurForme))
        .onContinuousHover { phase in
            switch phase {
            case .active(let p): moteur.survoler(p, option: NSEvent.modifierFlags.contains(.option))
            case .ended: moteur.survoler(nil)
            }
        }
        // ⌥ est lue au debut du geste : `DragGesture` ne donne ni l'evenement ni ses touches, mais son premier
        // `onChanged` (distance minimale nulle) arrive a l'appui, et le moteur ne lit `option` qu'a l'appui.
        .gesture(DragGesture(minimumDistance: 0)
            .updating($glisse) { _, g, _ in g = true }
            .onChanged { moteur.glisser($0.location, depart: $0.startLocation, option: NSEvent.modifierFlags.contains(.option)) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
/// Le curseur au-dessus de la vue : une main sur ce qui se clique (polissage C, maquette).
enum Curseur: Equatable {
    case fleche
    case main
```

par :

```swift
/// Le curseur au-dessus de la vue : une main sur ce qui se clique (polissage C, maquette) ; en 3D, une main ouverte tant
/// que ⌥ est tenue, une main fermee pendant ⌥ + glisser (section 6).
enum Curseur: Equatable {
    case fleche
    case main
    case mainOuverte
    case mainFermee
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    }

    /// Glissement des marges du cadre, de `depart` a `arrivee`, depuis `debut`, en `duree` ; `fondu` : avec
```

par :

```swift
        /// ⌥ + glisser en 3D : la vue glisse dans le plan de l'ecran, depuis l'orbite de l'appui.
        case ecran(Orbite)
    }

    /// ⌥ est tenue (le survol et le moniteur des touches la suivent) ; ce que le pointeur vise est cliquable.
    @ObservationIgnored private var optionTenue = false
    @ObservationIgnored private var surCliquable = false

    /// Glissement des marges du cadre, de `depart` a `arrivee`, depuis `debut`, en `duree` ; `fondu` : avec
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    func survoler(_ p: CGPoint?) {
        curseur = p
```

par :

```swift
    func survoler(_ p: CGPoint?, option: Bool = false) {
        curseur = p
        optionTenue = option
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        let main = switch c {
```

par :

```swift
        surCliquable = switch c {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        let forme: Curseur = main ? .main : .fleche
        if forme != curseurForme { curseurForme = forme }
```

par :

```swift
        majCurseur()
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Ce que vise un clic en `p`, du plus fort au plus faible (polissage C, section 5.1).
```

par :

```swift
    /// ⌥ pressee ou relachee, le pointeur immobile (le moniteur des touches).
    func changerOption(_ option: Bool) {
        guard option != optionTenue else { return }
        optionTenue = option
        majCurseur()
    }

    /// Le curseur (polissage C, section 6) : une main fermee pendant ⌥ + glisser ; une main ouverte tant que ⌥ est
    /// tenue au-dessus de la vue en 3D ; sinon, une main sur ce qui se clique.
    private func majCurseur() {
        let forme: Curseur
        if case .ecran? = geste {
            forme = .mainFermee
        } else if optionTenue && curseur != nil && troisD && t == 1 && envol == nil && fondu == nil {
            forme = .mainOuverte
        } else {
            forme = surCliquable ? .main : .fleche
        }
        if forme != curseurForme { curseurForme = forme }
    }

    /// Ce que vise un clic en `p`, du plus fort au plus faible (polissage C, section 5.1).
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    func glisser(_ p: CGPoint, depart d: CGPoint) {
```

par :

```swift
    /// Un glisser, a chaque deplacement du pointeur ; `option` : ⌥ tenue, lue a l'appui seulement (polissage C,
    /// section 6) : en 3D, la vue glisse alors dans le plan de l'ecran, depuis le fond, un disque ou une piece, qui ne
    /// bouge pas ; un vol en cours s'arrete. Relacher ⌥ en route ne change rien. En 2D, ⌥ ne change rien.
    func glisser(_ p: CGPoint, depart d: CGPoint, option: Bool = false) {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            // Les pieces de l'etage isole se glissent ; celles des autres etages se cliquent seulement.
            if !estIsolee, !enMouvement, let scene, let i = projetee?.piece(sous: d), i < scene.pieces.count,
               indiceEtageIsole.map({ $0 == scene.pieces[i].etage }) ?? true, let c = centrePiece(i) {
```

par :

```swift
            if option && troisD && t == 1 && envol == nil && fondu == nil {
                vol = nil
                viseeVol = nil
                geste = .ecran(orbite)
            } else if !estIsolee, !enMouvement, let scene, let i = projetee?.piece(sous: d), i < scene.pieces.count,
                      indiceEtageIsole.map({ $0 == scene.pieces[i].etage }) ?? true, let c = centrePiece(i) {
                // Les pieces de l'etage isole se glissent ; celles des autres etages se cliquent seulement.
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        }
        if !bouge && hypot(p.x - d.x, p.y - d.y) < 5 { return }
```

par :

```swift
            majCurseur()
        }
        if !bouge && hypot(p.x - d.x, p.y - d.y) < 5 { return }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        case .piece(let id, let h):
```

par :

```swift
        case .ecran(let o):
            orbite = CameraScene.deplacerDansLEcran(o, glisse: CGSize(width: p.x - d.x, height: p.y - d.y), cadre: cadre)
            vueTouchee = true
        case .piece(let id, let h):
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if case .piece(let id, _)? = g, !clic {
```

par :

```swift
        majCurseur()
        if case .piece(let id, _)? = g, !clic {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        bouge = false
    }
```

par :

```swift
        bouge = false
        majCurseur()
    }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        moniteur = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak self] e in
```

par :

```swift
        moniteur = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown, .flagsChanged]) { [weak self] e in
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
            default:
                return e
```

par :

```swift
            case .flagsChanged:
                // ⌥ et la main ouverte (polissage C, section 6) : l'evenement continue son chemin.
                let option = e.modifierFlags.contains(.option)
                MainActor.assumeIsolated { self.changerOption(option) }
                return e
            default:
                return e
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/CameraSceneTests MaillageThreadTests/MoteurPiecesTests`
Expected: `Test run with 18 tests in 1 suite passed` (cœur) et `Test run with 33 tests in 1 suite passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh`
Expected: `Test run with 369 tests in 37 suites passed` (cœur) et `Test run with 336 tests in 30 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 2 tests de plus pour le cœur, 1 test de plus pour l'app. `deplacerDansLEcran` et `envolEtVolsDepuisLaPoseExacte` s'ajoutent au cœur ; `optionGlisser` à l'app.

- [ ] **Step 6 : les images de démo, identiques.** Cette tâche ne change pas le rendu des images (figées, sans geste) : chacune est identique, octet pour octet, à celle de la tâche 5.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t6"
R="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC-t5"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polC/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
n=0; for f in "$R"/*.png; do cmp -s "$f" "$D/$(basename "$f")" && n=$((n+1)) || echo "différente : $(basename "$f")"; done; echo "$n identiques sur $(ls "$R" | wc -l | tr -d ' ')"
```

Expected : 14 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`, `13-2d-fiche-du-chef.png`, `14-2d-legende-repliee.png`) ; « l'app a quitté » ; « 14 identiques sur 14 ». Si une image diffère, s'arrêter : la tâche a changé le rendu.

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeurTests/CameraSceneTests.swift MaillageThreadTests/MoteurPiecesTests.swift MaillageCoeur/Scene/CameraScene.swift MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/Pieces/MoteurPieces.swift
git commit -m "Deplacer la vue 3D dans le plan de l'ecran par Option et glisser, a 0,7 fois la vitesse du pointeur, le mode fixe a l'appui, avec la main ouverte puis fermee, et faire partir l'envol et les vols de la pose exacte de la camera

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: La démo et ses vingt images ; « ⌂ Maison » après les noms d'étage ; le README

**Files:**
- Modify: `MaillageCoeur/Demo/NomsDemo.swift`, `MaillageCoeur/Scene/PlacementNoms.swift`, `MaillageThread/MaillageThreadApp.swift`, `MaillageThread/Vues/Pieces/CapturesPieces.swift`, `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift`, `MaillageThread/Vues/Pieces/SigneLegende.swift` (blocs ci-dessous)
- Modify: `README.md`, `README.fr.md` (blocs ci-dessous)
- Test: `MaillageCoeurTests/NomsTests.swift`, `MaillageThreadTests/NomsSceneTests.swift`, `MaillageThreadTests/MoteurPiecesTests.swift`, `MaillageThreadTests/FenetrePiecesTests.swift`, `MaillageThreadTests/LegendePiecesTests.swift`

**Interfaces:**
- Consumes :
  - `NomsDemo` (`table`, `zones`, `maison`), `PlacesGardees.ranger(_:domicile:)`, `Rangement` (tâche 1), `MoteurPieces.reglerGrille(_:)`, `basGrille` (tâche 4), `poserEtageIsole(_:)`, `poserIsolement(_:depuisEtage:)` (tâche 5), `Etiquette` (`prio`), `PlacementNoms.chevauche(_:_:)`, `CapturesPieces`, `SigneLegende`, existants ;
  - dans les tests : `NomsSceneTests.demo()`, `MoteurPiecesTests.quatrePlateaux(_:)`, `large`, existants.
- Produces :
  - `NomsDemo.zones` (quatre), `NomsDemo.domicile`, `NomsDemo.places(dehors:) -> PlacesGardees` ;
  - `MoteurPieces(troisD:fichierPlaces:selection:places:)`, `FenetrePieces(fichierPlaces:fichierPieces:places:)` ;
  - `CapturesPieces.Cas` (`taille`, `grille`, `places`), `CapturesPieces.taille` (`nonisolated`), `CapturesPieces.carree`, `CapturesPieces.etage(_:_:)`, vingt images ;
  - le nom de la maison en priorité 2, après les noms d'étage ; `MoteurPiecesTests.margesDemo` (tests) ;
  - le README, en anglais et en français.

**La démo** gagne les combles et le jardin, le jardin au niveau du rez-de-chaussée, hors de la maison, en mémoire (spec, section 7 ; précision 21) ; dans une fenêtre carrée, sa grille est 2 × 2, dans une fenêtre ordinaire, la rangée. Les tests qui comptaient ses pièces et ses étages changent avec elle ; la légende garde la taille de B (précision 23).

**« ⌂ Maison » évite les noms d'étage** (décision de Djoko du 03/10 ; précision 25) : avec la démo à quatre plateaux, son jardin hors de la maison, la vue 3D est petite, et le nom de la maison tombait sur celui des combles.

**Les images de démo** passent à vingt (précision 22) : elles changent toutes, et Djoko les regarde à la tâche 8, à côté des rendus de la maquette.

**La doc** : le README décrit les niveaux, la grille et son réglage, l'isolement d'un étage, ⌥ + glisser, le menu du clic droit et les vingt images.

- [ ] **Step 1 : écrire les tests.** La maison de démo et sa scène ; la grille de la démo sur la zone visible ; « ⌂ Maison » qui évite les noms d'étage ; les tests qui comptaient ses pièces et ses étages ; les vingt images ; la taille des signes de la légende, et le seuil de leur comparaison à la scène (précision 24).

Dans `MaillageCoeurTests/NomsTests.swift`, remplacer :

```swift
    /// Maison de demo : les zones et les pieces de la maquette de la vue par pieces ; chaque piece a un
    /// accessoire ; les routeurs de bordure y sont des accessoires du nom de leur annonce, sans noeud Matter.
    @Test func maisonDeDemo() {
        let m = NomsDemo.maison
        #expect(m.zones == [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie"]),
                            ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"])])
```

par :

```swift
    /// Maison de demo : les zones et les pieces de la maquette de la vue par pieces, puis le jardin et les combles de
    /// la maquette des etages (polissage C) ; chaque piece a un accessoire ; les routeurs de bordure y sont des
    /// accessoires du nom de leur annonce, sans noeud Matter. Son choix de niveau, en memoire : le jardin a cote du
    /// rez-de-chaussee, hors de la maison.
    @Test func maisonDeDemo() {
        let m = NomsDemo.maison
        #expect(m.zones == [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie"]),
                            ZoneMaison(nom: "Jardin", pieces: ["Terrasse", "Abri"]),
                            ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"]),
                            ZoneMaison(nom: "Combles", pieces: ["Grenier", "Salle de jeux"])])
        #expect(m.domicile == NomsDemo.domicile)
        #expect(NomsDemo.places().rangement(NomsDemo.domicile)
                == Rangement(ordre: ["zone:Rez-de-chaussée", "zone:Jardin", "zone:Étage", "zone:Combles"],
                             aCote: ["zone:Jardin": PlacesGardees.ACote(etage: "zone:Rez-de-chaussée", dehors: true)]))
        #expect(NomsDemo.places(dehors: false).rangement(NomsDemo.domicile).aCote["zone:Jardin"]?.dehors == false)
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
    /// nom de sa zone. L'entree mise dans un « Jardin » a cote du rez-de-chaussee : le parent du detecteur du
    /// couloir, l'Apple TV, est au salon. Sans le choix, le jardin est un etage au-dessus : ↓.
```

par :

```swift
    /// nom de sa zone. L'entree mise dans un « Jardin » a cote du rez-de-chaussee : le parent de la serrure, l'Apple
    /// TV, est au salon. Sans le choix, le jardin est un etage au-dessus : ↓.
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"])]
```

par :

```swift
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"]),
                        ZoneMaison(nom: "Combles", pieces: ["Terrasse", "Abri", "Grenier", "Salle de jeux"])]
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
            let a = try #require(SceneProjetee.reperes(e.scene, focus: entree).first { $0.enfant == "327DF9C45C82BBD6" })
```

par :

```swift
            let a = try #require(SceneProjetee.reperes(e.scene, focus: entree).first { $0.enfant == "86E7BD1A75F28E6D" })
```

Dans `MaillageThreadTests/NomsSceneTests.swift`, remplacer :

```swift
    /// La maison de demo : les deux etages et les huit pieces de la maquette, « Sans piece » sur le
    /// plateau du bas ; les apparences du graphe d'avant.
    @Test func sceneDeLaDemo() throws {
        let (_, _, e) = try Self.demo()
        #expect(e.scene.etages.map(\.nom) == [.zone("Rez-de-chaussée"), .zone("Étage")])
        let bas = e.scene.etages[0].pieces.map { e.scene.pieces[$0].nom }
        #expect(bas == [.maison("Buanderie"), .maison("Cuisine"), .maison("Entrée"), .maison("Salon"), .sansPiece])
        let haut = e.scene.etages[1].pieces.map { e.scene.pieces[$0].nom }
        #expect(haut == [.maison("Bureau"), .maison("Chambre"), .maison("Chambre d'amis"), .maison("Salle de bain")])
```

par :

```swift
    /// La maison de demo (polissage C, section 7) : les quatre plateaux et les douze pieces des maquettes, « Sans piece »
    /// sur le plateau du bas ; avec son choix de niveau, le jardin au niveau du rez-de-chaussee, hors de la maison ; les
    /// apparences du graphe d'avant.
    @Test func sceneDeLaDemo() throws {
        let (s, r, e) = try Self.demo()
        #expect(e.scene.etages.map(\.nom) == [.zone("Rez-de-chaussée"), .zone("Jardin"), .zone("Étage"), .zone("Combles")])
        func pieces(_ k: Int) -> [ScenePieces.NomPiece] { e.scene.etages[k].pieces.map { e.scene.pieces[$0].nom } }
        #expect(pieces(0) == [.maison("Buanderie"), .maison("Cuisine"), .maison("Entrée"), .maison("Salon"), .sansPiece])
        #expect(pieces(1) == [.maison("Abri"), .maison("Terrasse")])
        #expect(pieces(2) == [.maison("Bureau"), .maison("Chambre"), .maison("Chambre d'amis"), .maison("Salle de bain")])
        #expect(pieces(3) == [.maison("Grenier"), .maison("Salle de jeux")])
        let niveaux = EntreeScene(surveillance: s, reseau: r, places: NomsDemo.places()).scene
        #expect(niveaux.niveaux.liste == [["zone:Rez-de-chaussée", "zone:Jardin"], ["zone:Étage"], ["zone:Combles"]])
        #expect(niveaux.etages.map(\.dehors) == [false, true, false, false])
        // Un routeur dans la salle de jeux et sur la terrasse ; des liens entre niveaux et au meme niveau.
        for (id, piece) in [("02A8C3C5600F136B", "Salle de jeux"), ("0A84D1254BD246AD", "Terrasse")] {
            let n = try #require(niveaux.noeud(id))
            #expect(n.routeur && niveaux.pieces[n.piece].nom == .maison(piece))
        }
        let niveau = { (id: String) in niveaux.noeud(id).map { niveaux.etages[niveaux.pieces[$0.piece].etage].niveau } }
        let liens = niveaux.liens.filter { $0.genre == .radio }.map { (niveau($0.de), niveau($0.vers)) }
        #expect(liens.contains { $0.0 != $0.1 } && liens.contains { $0.0 == $0.1 })
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        #expect(m.positions.count == e.scene.pieces.count && m.geometrie.rayons.count == 2)
```

par :

```swift
        #expect(m.positions.count == e.scene.pieces.count && m.geometrie.rayons.count == 4)
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        maison.zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"]),
```

par :

```swift
        maison.zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Terrasse", "Abri"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis",
                                                          "Grenier", "Salle de jeux"]),
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        let sdb = try Self.indice(e, "Salle de bain")
        #expect(sdb >= autre.scene.pieces.count, "son indice n'existe plus dans la nouvelle scene")
        let depart = try Self.pointDePiece(m, sdb)
```

par :

```swift
        let jeux = try Self.indice(e, "Salle de jeux")
        #expect(jeux >= autre.scene.pieces.count, "son indice n'existe plus dans la nouvelle scene")
        let depart = try Self.pointDePiece(m, jeux)
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        let fin = m.positions[sdb]
        m.relacher(CGPoint(x: depart.x + 40, y: depart.y))
        #expect(m.entree == autre && m.positions.count == autre.scene.pieces.count)
        #expect(m.positions[try Self.indice(autre, "Salle de bain")] == fin)
        // Releve recu pendant le geste : sa disposition, lancee au relachement, garde la place du geste.
        let (n, _) = try Self.moteur()
        let depart2 = try Self.pointDePiece(n, sdb)
```

par :

```swift
        let fin = m.positions[jeux]
        m.relacher(CGPoint(x: depart.x + 40, y: depart.y))
        #expect(m.entree == autre && m.positions.count == autre.scene.pieces.count)
        #expect(m.positions[try Self.indice(autre, "Salle de jeux")] == fin)
        // Releve recu pendant le geste : sa disposition, lancee au relachement, garde la place du geste.
        let (n, _) = try Self.moteur()
        let depart2 = try Self.pointDePiece(n, jeux)
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        let fin2 = n.positions[sdb]
        n.relacher(CGPoint(x: depart2.x + 40, y: depart2.y))
        while n.entree != autre { try await Task.sleep(for: .milliseconds(10)) }
        #expect(n.positions[try Self.indice(autre, "Salle de bain")] == fin2)
```

par :

```swift
        let fin2 = n.positions[jeux]
        n.relacher(CGPoint(x: depart2.x + 40, y: depart2.y))
        while n.entree != autre { try await Task.sleep(for: .milliseconds(10)) }
        #expect(n.positions[try Self.indice(autre, "Salle de jeux")] == fin2)
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        #expect(m.peutDeplacerEtage(0, de: 1) && !m.peutDeplacerEtage(1, de: 1) && !m.peutDeplacerEtage(0, de: -1))
        m.deplacerEtage(0, de: 1)
        #expect(m.places.maison(e.domicile).ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
```

par :

```swift
        #expect(m.peutDeplacerEtage(0, de: 1) && !m.peutDeplacerEtage(3, de: 1) && !m.peutDeplacerEtage(0, de: -1))
        m.deplacerEtage(0, de: 1)
        let ordre = ["zone:Jardin", "zone:Rez-de-chaussée", "zone:Étage", "zone:Combles"]
        #expect(m.places.maison(e.domicile).ordreEtages == ordre)
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        #expect(PlacesGardees.lire(url).maison(e.domicile).ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
```

par :

```swift
        #expect(PlacesGardees.lire(url).maison(e.domicile).ordreEtages == ordre)
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        maison.zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Chambre d'amis"]),
                        ZoneMaison(nom: "Combles", pieces: ["Bureau", "Salle de bain"])]
```

par :

```swift
        maison.zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie", "Terrasse",
                                                                    "Abri"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Chambre d'amis"]),
                        ZoneMaison(nom: "Combles", pieces: ["Bureau", "Salle de bain", "Grenier", "Salle de jeux"])]
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
    /// son niveau, sans choix ; `places` : les places gardees, dont les choix de niveau.
```

par :

```swift
    /// son niveau, sans choix ; `places` : les places gardees, dont les choix de niveau. Les zones prennent toutes les
    /// pieces de la demo, celles du jardin et des combles de sa maquette comprises.
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
                        ZoneMaison(nom: "Jardin", pieces: ["Entrée"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Salle de bain"]),
                        ZoneMaison(nom: "Combles", pieces: ["Bureau", "Chambre d'amis"])]
```

par :

```swift
                        ZoneMaison(nom: "Jardin", pieces: ["Entrée", "Terrasse", "Abri"]),
                        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Salle de bain"]),
                        ZoneMaison(nom: "Combles", pieces: ["Bureau", "Chambre d'amis", "Grenier", "Salle de jeux"])]
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
    /// Redimensionnement a la vue d'ensemble (polissage C, section 3.5) : la grille se recalcule, les plateaux glissent
```

par :

```swift
    /// Les marges de la demo, mesurees comme dans les images : le haut de la fenetre, puis le bas, la legende ouverte ou
    /// repliee.
    static let margesDemo = (haut: CGFloat(139), ouverte: CGFloat(249), repliee: CGFloat(30))

    /// La grille de la demo sur la zone visible (polissage C, sections 3.3 et 7), le jardin au niveau du
    /// rez-de-chaussee, hors de la maison : la rangee dans une fenetre ordinaire (1100 x 760) et dans celle des images
    /// (1440 x 900), la legende ouverte ou repliee, et dans une vue large (2,4 : 1) ; dans une fenetre carree de 900 pt,
    /// la rangee, la legende ouverte, 2 x 2 repliee ; dans une de 1000 pt, 2 x 2, la legende ouverte.
    @Test func grilleDeLaDemo() throws {
        let (s, r, _) = try NomsSceneTests.demo()
        let e = EntreeScene(surveillance: s, reseau: r, places: NomsDemo.places())
        let ordinaire = CGSize(width: 1100, height: 760), carree = CGSize(width: 900, height: 900)
        let cas: [(CGSize, Bool, Int)] = [(ordinaire, false, 4), (ordinaire, true, 4), (CapturesPieces.taille, false, 4),
                                         (CapturesPieces.taille, true, 4), (Self.large, false, 4), (carree, false, 4),
                                         (carree, true, 2), (CGSize(width: 1000, height: 1000), false, 2)]
        for (taille, repliee, colonnes) in cas {
            let m = MoteurPieces(places: NomsDemo.places())
            m.marges = (Self.margesDemo.haut, repliee ? Self.margesDemo.repliee : Self.margesDemo.ouverte)
            m.poserTaille(taille)
            m.installerMaintenant(e)
            #expect(m.colonnes == colonnes && m.geometrie.colonnes == colonnes, "\(taille), repliee : \(repliee)")
        }
    }

    /// « ⌂ Maison » evite les noms d'etage (polissage C, section 2, decision de Djoko du 03/10) : il se pose apres eux,
    /// a l'une de ses places candidates. Le cas de l'image `05-3d` : la demo en 3D, son jardin hors de la maison, dans
    /// la fenetre des images, la legende ouverte ; la maison y est petite, et son nom tombait sur celui des combles.
    @Test func maisonEviteLesEtages() throws {
        let (s, r, _) = try NomsSceneTests.demo()
        let e = EntreeScene(surveillance: s, reseau: r, places: NomsDemo.places())
        let m = MoteurPieces(places: NomsDemo.places())
        m.fige = true
        m.marges = (Self.margesDemo.haut, Self.margesDemo.ouverte)
        m.poserTaille(CapturesPieces.taille)
        m.installerMaintenant(e)
        m.poserTaille(CapturesPieces.taille)
        m.poserBascule(1)
        for _ in 0..<2 { Self.dessiner(m, taille: CapturesPieces.taille) }
        let maison = try #require(m.etiquettes.first { $0.genre == .maison && $0.vu })
        let etages = m.etiquettes.filter { if case .etage = $0.genre { $0.vu } else { false } }
        #expect(etages.count == e.scene.etages.count)
        for l in etages {
            #expect(!PlacementNoms.chevauche(l.rect, maison.rect), "\(l.genre) et la maison")
        }
    }

    /// Redimensionnement a la vue d'ensemble (polissage C, section 3.5) : la grille se recalcule, les plateaux glissent
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        #expect(pieces == ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain", "Salon"])
```

par :

```swift
        #expect(pieces == ["Abri", "Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Grenier",
                           "Salle de bain", "Salle de jeux", "Salon", "Terrasse"])
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        let pieces = ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain",
                      "Salon"]
```

par :

```swift
        let pieces = ["Abri", "Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Grenier",
                      "Salle de bain", "Salle de jeux", "Salon", "Terrasse"]
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// la legende repliee. La fiche est celle d'un noeud couronne de la demo.
```

par :

```swift
    /// la legende repliee ; puis les six des etages (polissage C, section 7). La fiche est celle d'un noeud couronne de
    /// la demo.
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
            "13-2d-fiche-du-chef", "14-2d-legende-repliee",
```

par :

```swift
            "13-2d-fiche-du-chef", "14-2d-legende-repliee", "15-2d-carree-2x2", "16-2d-carree-en-rangee",
            "17-3d-jardin-dedans", "18-2d-etage-isole", "19-3d-etage-isole", "20-3d-terrasse-depuis-le-jardin",
```

Dans `MaillageThreadTests/LegendePiecesTests.swift`, remplacer :

```swift
        // Chaque signe, et la fonction du rendu avec les parametres de la scene : les memes pixels, a un ou deux pixels
        // pres (le flou d'un halo peut varier d'un rendu a l'autre) ; un autre dessin en changerait des milliers.
```

par :

```swift
        // Chaque signe, et la fonction du rendu avec les parametres de la scene : les memes pixels, a quelques pixels
        // pres (le flou d'un halo ou d'une ombre varie d'un rendu a l'autre, selon ce que le processus a rendu avant :
        // jusqu'a 14 octets apres la scene de la demo de C) ; un autre dessin en changerait des milliers.
```

Dans `MaillageThreadTests/LegendePiecesTests.swift`, remplacer :

```swift
            #expect(ecarts <= 8, "\(signe) : \(ecarts) octets differents")
```

par :

```swift
            #expect(ecarts <= 32, "\(signe) : \(ecarts) octets differents")
```

Dans `MaillageThreadTests/LegendePiecesTests.swift`, remplacer :

```swift
    /// Les noeuds de la legende ont la taille d'un noeud de la scene dans la vue d'ensemble (verification du 02/10) :
    /// celle de la demo a la taille des images (1440 x 900, en 2D), ramenee au plus a la hauteur d'une ligne de la
    /// legende. Un routeur de bordure y mesure 13 fois le zoom, un appareil 7 fois.
```

par :

```swift
    /// Les noeuds de la legende ont la taille d'un noeud de la scene dans la vue d'ensemble (verification du 02/10),
    /// ramenee au plus a la hauteur d'une ligne de la legende : un routeur de bordure y mesure 13 fois le zoom, un
    /// appareil 7 fois (3 pt au moins dans la scene), au zoom de la vue d'ensemble de reference, celle de la demo de
    /// deux etages de B (0,53 a la taille des images, 1440 x 900, en 2D). La demo de C, a quatre plateaux, a une vue
    /// d'ensemble plus petite (0,47, en rangee) : la legende garde la taille de B (decision de Djoko du 03/10).
```

Dans `MaillageThreadTests/LegendePiecesTests.swift`, remplacer :

```swift
        #expect(abs(p.echelle - LegendePieces.zoomVueDEnsemble) < 0.02, "le zoom de la vue d'ensemble : \(p.echelle)")
```

par :

```swift
        #expect(p.echelle < LegendePieces.zoomVueDEnsemble, "la vue d'ensemble de la demo de C : \(p.echelle)")
```

Dans `MaillageThreadTests/LegendePiecesTests.swift`, remplacer :

```swift
        #expect(abs(LegendePieces.rayonRouteur - min(routeur, LegendePieces.hauteurLigne / 2)) < 0.15, "\(routeur)")
        #expect(abs(LegendePieces.rayonAppareil - min(appareil, LegendePieces.hauteurLigne / 2)) < 0.15, "\(appareil)")
```

par :

```swift
        #expect(abs(routeur - max(3, 13 * p.echelle)) < 0.15 && abs(appareil - max(3, 7 * p.echelle)) < 0.15,
                "\(routeur) et \(appareil) au zoom \(p.echelle)")
        #expect(abs(LegendePieces.rayonRouteur - min(13 * LegendePieces.zoomVueDEnsemble, LegendePieces.hauteurLigne / 2)) < 0.01)
        #expect(abs(LegendePieces.rayonAppareil - min(7 * LegendePieces.zoomVueDEnsemble, LegendePieces.hauteurLigne / 2)) < 0.01)
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/NomsTests MaillageThreadTests/NomsSceneTests MaillageThreadTests/MoteurPiecesTests MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/LegendePiecesTests`
Expected: la compilation des tests échoue (`NomsTests.swift`), par exemple avec `error: type 'NomsDemo' has no member 'domicile'` et `error: type 'NomsDemo' has no member 'places'` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** La démo, puis le placement des noms (« ⌂ Maison » après les noms d'étage), l'app (les places de la démo), les images (leurs marges posées avant la scène, la fenêtre carrée), la fenêtre et le moteur (les places de départ), la légende (son commentaire).

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
/// ceux de la maquette de la vue par pieces ; les routeurs de bordure y sont des
/// accessoires du nom de leur annonce, qui leur donnent leur piece.
```

par :

```swift
/// ceux de la maquette de la vue par pieces, et, depuis le polissage C, les combles et
/// le jardin de sa maquette, remplis avec des noeuds de la demo (aucune donnee radio
/// nouvelle) ; les routeurs de bordure y sont des accessoires du nom de leur annonce,
/// qui leur donnent leur piece.
```

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
        "02A8C3C5600F136B": ("Eve Door", "Entrée", "Eve Systems", "Eve Door & Window", "Capteur"),
        "3A5DFAFCAB581AAF": ("Eve Motion", "Buanderie", "Eve Systems", "Eve Motion", "Capteur"),
        "C656F369B620027F": ("Thermo salon", "Salon", "Eve Systems", "Eve Thermo", "Thermostat"),
        "D661EE20B3E97C66": ("Thermo chambre", "Chambre", "Eve Systems", "Eve Thermo", "Thermostat"),
        "DAEF22ACB58F651C": ("Météo terrasse", "Salon", "Eve Systems", "Eve Weather", "Capteur"),
        "0A84D1254BD246AD": ("Capteur salon", "Salon", "Aqara", "Climate Sensor W100", "Capteur"),
        "327DF9C45C82BBD6": ("Détecteur couloir", "Entrée", "Aqara", "Motion Sensor P2", "Capteur"),
        "462DA5B311AFFCC7": ("Fenêtre chambre", "Chambre", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "7A3D0C7512F8E0A5": ("Capteur salle de bain", "Salle de bain", "Aqara", "Climate Sensor W100", "Capteur"),
        "8A7E6F2665F737C6": ("Porte-fenêtre", "Salon", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "9A5C1F9FDFAB242D": ("Fumée cuisine", "Cuisine", "Aqara", "Smoke Detector", "Capteur"),
        "AA3D322B8A4500C4": ("Bouton chevet", "Chambre", "Aqara", "Wireless Mini Switch", "Interrupteur"),
        "C663573E49A1EC90": ("Capteur bureau", "Bureau", "Aqara", "Climate Sensor W100", "Capteur"),
        "46F77B36E071F8D0": ("Prise bureau", "Bureau", "Eve Systems", "Eve Energy", "Prise"),
        "7AF0B6D5006CF95F": ("Prise salon", "Salon", "Eve Systems", "Eve Energy", "Prise"),
        "82570DF21CF3784B": ("Volet chambre", "Chambre", "Nanoleaf", "Blinds", "Store"),
```

par :

```swift
        // Polissage C : un routeur dans la salle de jeux, et un enfant de lui.
        "02A8C3C5600F136B": ("Prise console", "Salle de jeux", "Eve Systems", "Eve Energy", "Prise"),
        "3A5DFAFCAB581AAF": ("Eve Motion", "Grenier", "Eve Systems", "Eve Motion", "Capteur"),
        // Polissage C : les deux enfants du routeur de la terrasse, a l'abri.
        "C656F369B620027F": ("Capteur porte de l'abri", "Abri", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "D661EE20B3E97C66": ("Thermo chambre", "Chambre", "Eve Systems", "Eve Thermo", "Thermostat"),
        "DAEF22ACB58F651C": ("Météo terrasse", "Terrasse", "Eve Systems", "Eve Weather", "Capteur"),
        // Polissage C : un routeur sur la terrasse.
        "0A84D1254BD246AD": ("Prise terrasse", "Terrasse", "Eve Systems", "Eve Energy Outdoor", "Prise"),
        // Polissage C : le grenier.
        "327DF9C45C82BBD6": ("Capteur d'humidité", "Grenier", "Aqara", "Climate Sensor W100", "Capteur"),
        "462DA5B311AFFCC7": ("Fenêtre chambre", "Chambre", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "7A3D0C7512F8E0A5": ("Capteur salle de bain", "Salle de bain", "Aqara", "Climate Sensor W100", "Capteur"),
        "8A7E6F2665F737C6": ("Porte-fenêtre", "Salon", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "9A5C1F9FDFAB242D": ("Détecteur de chaleur allée", "Grenier", "Aqara", "Smoke Detector", "Capteur"),
        "AA3D322B8A4500C4": ("Lampe arcade", "Salle de jeux", "Nanoleaf", "Essentials A19", "Ampoule"),
        "C663573E49A1EC90": ("Capteur de lucarne", "Salle de jeux", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "46F77B36E071F8D0": ("Prise bureau", "Bureau", "Eve Systems", "Eve Energy", "Prise"),
        "7AF0B6D5006CF95F": ("Prise salon", "Salon", "Eve Systems", "Eve Energy", "Prise"),
        "82570DF21CF3784B": ("Vanne d'arrosage", "Abri", "Eve Systems", "Eve Aqua", "Vanne"),
```

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
    /// Zones de la maquette, dans l'ordre de Maison : le rez-de-chaussee, puis l'etage.
    public static let zones = [
        ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie"]),
        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"]),
```

par :

```swift
    /// Zones des maquettes, dans l'ordre de Maison : le rez-de-chaussee, le jardin, l'etage, les combles.
    public static let zones = [
        ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie"]),
        ZoneMaison(nom: "Jardin", pieces: ["Terrasse", "Abri"]),
        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"]),
        ZoneMaison(nom: "Combles", pieces: ["Grenier", "Salle de jeux"]),
```

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
        return NomsMaison(date: ScenarioPanne.fin.addingTimeInterval(-5 * 60), domicile: "Maison (démo)",
                          accessoires: accessoires.sorted { $0.nom < $1.nom }, zones: zones)
    }()
```

par :

```swift
        return NomsMaison(date: ScenarioPanne.fin.addingTimeInterval(-5 * 60), domicile: domicile,
                          accessoires: accessoires.sorted { $0.nom < $1.nom }, zones: zones)
    }()

    public static let domicile = "Maison (démo)"

    /// Le choix de niveau de la demo (polissage C, section 7) : le jardin au niveau du rez-de-chaussee, hors de la
    /// maison ; en memoire, la demo n'ecrivant rien. `dehors` : faux, dans la maison.
    public static func places(dehors: Bool = true) -> PlacesGardees {
        var p = PlacesGardees()
        p.ranger(Rangement(ordre: zones.map { "zone:" + $0.nom },
                           aCote: ["zone:Jardin": PlacesGardees.ACote(etage: "zone:Rez-de-chaussée", dehors: dehors)]),
                 domicile: domicile)
        return p
    }
```

Dans `MaillageCoeur/Scene/PlacementNoms.swift`, remplacer :

```swift
            candidats = Candidats.maison
            fixe = false
            prio = 0
```

par :

```swift
            // Apres les noms d'etage, qu'il evite (polissage C, section 2, decision de Djoko du 03/10) : dans une petite
            // vue 3D, il tombait sur le nom de l'etage du haut.
            candidats = Candidats.maison
            fixe = false
            prio = 2
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
            FenetrePieces(fichierPlaces: FenetrePieces.fichierPlaces(demo: Self.demo, sousTests: Surveillance.sousTests),
                          fichierPieces: PiecesChoisies.fichier(demo: Self.demo, sousTests: Surveillance.sousTests))
```

par :

```swift
            // En demo, le jardin au niveau du rez-de-chaussee, hors de la maison (polissage C, section 7), en memoire.
            FenetrePieces(fichierPlaces: FenetrePieces.fichierPlaces(demo: Self.demo, sousTests: Surveillance.sousTests),
                          fichierPieces: PiecesChoisies.fichier(demo: Self.demo, sousTests: Surveillance.sousTests),
                          places: Self.demo ? NomsDemo.places() : nil)
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
/// pieces isolees, survol, la fiche du chef, la legende repliee. Sans fenetre ni capture d'ecran ;
```

par :

```swift
/// pieces isolees, survol, la fiche du chef, la legende repliee ; puis les etages (polissage C, section 7) :
/// la grille 2 x 2 dans une fenetre carree, la meme fenetre en rangee, le jardin dans la maison, un etage isole en 2D
/// et en 3D, une piece isolee depuis son etage. La maison de demo a son jardin au niveau du rez-de-chaussee, hors de
/// la maison (`NomsDemo.places()`) ; dans la fenetre des images, la legende ouverte ou repliee, sa grille est la
/// rangee (la zone visible, section 3.3). Sans fenetre ni capture d'ecran ;
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
    static let taille = CGSize(width: 1440, height: 900)

    /// Une image : son nom, l'etat a poser sur le moteur, et la legende repliee.
```

par :

```swift
    nonisolated static let taille = CGSize(width: 1440, height: 900)
    /// Une fenetre carree, ou la grille de la demo est 2 x 2, la legende ouverte (polissage C, sections 3.3 et 7).
    nonisolated static let carree = CGSize(width: 1000, height: 1000)

    /// Une image : son nom, l'etat a poser sur le moteur, et la legende repliee ; la taille de la fenetre, les etages
    /// en grille ou en rangee, et les places gardees, dont le choix de niveau du jardin.
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
        var legendeRepliee = false
```

par :

```swift
        var legendeRepliee = false
        var taille = CapturesPieces.taille
        var grille = true
        var places = NomsDemo.places()
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
    /// Les images, dans l'ordre : 2D, envol, 3D, zooms, pieces isolees, survol ; puis la fiche du chef de
```

par :

```swift
    /// Indice d'un etage, une zone de Maison, de la scene (le premier, sans elle).
    static func etage(_ scene: ScenePieces, _ nom: String) -> Int {
        scene.etages.firstIndex { $0.nom == .zone(nom) } ?? 0
    }

    /// Les images, dans l'ordre : 2D, envol, 3D, zooms, pieces isolees, survol ; puis la fiche du chef de
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
    ]
```

par :

```swift
        Cas(nom: "15-2d-carree-2x2", poser: { _, _ in }, taille: CapturesPieces.carree),
        Cas(nom: "16-2d-carree-en-rangee", poser: { _, _ in }, taille: CapturesPieces.carree, grille: false),
        Cas(nom: "17-3d-jardin-dedans", poser: { m, _ in m.poserBascule(1) }, places: NomsDemo.places(dehors: false)),
        Cas(nom: "18-2d-etage-isole") { m, sc in m.poserEtageIsole(etage(sc, "Étage")) },
        Cas(nom: "19-3d-etage-isole") { m, sc in
            m.poserBascule(1)
            m.poserEtageIsole(etage(sc, "Étage"))
        },
        Cas(nom: "20-3d-terrasse-depuis-le-jardin") { m, sc in
            m.poserBascule(1)
            m.poserIsolement(piece(sc, "Terrasse"), depuisEtage: true)
        },
    ]
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
            let m = MoteurPieces()
            m.fige = true
            m.marges = marges
            m.poserTaille(taille)
            let e = EntreeScene(surveillance: s, reseau: r, places: m.places)
            m.installerMaintenant(e)
            // La vue d'ensemble se cadre au-dessus de la legende ouverte : la hauteur mesuree de la rangee du bas,
            // comme dans la fenetre ; repliee, la marge d'avant.
            let ouverte = hauteur(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false))
            if !c.legendeRepliee {
                m.marges.bas = FenetrePieces.margeBas(pile: ouverte)
            }
```

par :

```swift
            let taille = c.taille
            let m = MoteurPieces(places: c.places)
            m.fige = true
            m.reglerGrille(c.grille)
            let e = EntreeScene(surveillance: s, reseau: r, places: m.places)
            // La vue d'ensemble se cadre au-dessus de la legende ouverte : la hauteur mesuree de la rangee du bas,
            // comme dans la fenetre ; repliee, la marge d'avant. La grille se choisit sur cette zone visible, sans la
            // fiche (polissage C, section 3.3).
            let ouverte = hauteur(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false))
            m.marges = (marges.0, c.legendeRepliee ? marges.1 : FenetrePieces.margeBas(pile: ouverte))
            m.basGrille = m.marges.bas
            m.poserTaille(taille)
            m.installerMaintenant(e)
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    /// `pieces-routeurs.json` (`PiecesChoisies.fichier(demo:sousTests:)`) ; nil : ni lu ni ecrit.
    /// `--args -selection <id>` : fiche ouverte au lancement (captures d'ecran).
    init(fichierPlaces: URL?, fichierPieces: URL? = nil) {
        _moteur = State(initialValue: MoteurPieces(troisD: UserDefaults.standard.bool(forKey: Self.cleMode),
                                                   fichierPlaces: fichierPlaces,
                                                   selection: UserDefaults.standard.string(forKey: "selection")))
```

par :

```swift
    /// `pieces-routeurs.json` (`PiecesChoisies.fichier(demo:sousTests:)`) ; nil : ni lu ni ecrit. `places` : sans
    /// fichier, celles de depart, en memoire (la demo : `NomsDemo.places()`).
    /// `--args -selection <id>` : fiche ouverte au lancement (captures d'ecran).
    init(fichierPlaces: URL?, fichierPieces: URL? = nil, places: PlacesGardees? = nil) {
        _moteur = State(initialValue: MoteurPieces(troisD: UserDefaults.standard.bool(forKey: Self.cleMode),
                                                   fichierPlaces: fichierPlaces,
                                                   selection: UserDefaults.standard.string(forKey: "selection"),
                                                   places: places))
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// `troisD` : le mode garde ; `fichierPlaces` : `positions-pieces.json` (nil : ni lu ni ecrit).
    init(troisD: Bool = false, fichierPlaces: URL? = nil, selection: String? = nil) {
        self.troisD = troisD
        t = troisD ? 1 : 0
        self.fichierPlaces = fichierPlaces
        places = fichierPlaces.map(PlacesGardees.lire) ?? PlacesGardees()
```

par :

```swift
    /// `troisD` : le mode garde ; `fichierPlaces` : `positions-pieces.json` (nil : ni lu ni ecrit) ; `places` : sans
    /// fichier, les places de depart, en memoire (la demo et son choix de niveau).
    init(troisD: Bool = false, fichierPlaces: URL? = nil, selection: String? = nil, places depart: PlacesGardees? = nil) {
        self.troisD = troisD
        t = troisD ? 1 : 0
        self.fichierPlaces = fichierPlaces
        places = fichierPlaces.map(PlacesGardees.lire) ?? depart ?? PlacesGardees()
```

Dans `MaillageThread/Vues/Pieces/SigneLegende.swift`, remplacer :

```swift
    /// Zoom de la vue d'ensemble de reference (k : points par unite a la cible, divises par 24) : celui de la demo a
    /// la taille des images (1440 x 900, en 2D), mesure (`LegendePiecesTests.tailleDesSignes`).
```

par :

```swift
    /// Zoom de la vue d'ensemble de reference (k : points par unite a la cible, divises par 24) : celui de la demo de
    /// deux etages de B a la taille des images (1440 x 900, en 2D), mesure le 02/10. La demo de C, a quatre plateaux, a
    /// une vue d'ensemble plus petite (0,47, en rangee) : la legende garde cette taille, decision de Djoko du 03/10
    /// (`LegendePiecesTests.tailleDesSignes`).
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh MaillageCoeurTests/NomsTests MaillageThreadTests/NomsSceneTests MaillageThreadTests/MoteurPiecesTests MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/LegendePiecesTests`
Expected: `Test run with 16 tests in 1 suite passed` (cœur) et `Test run with 101 tests in 4 suites passed` (app), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : la doc.** Le README, en anglais et en français : les niveaux, la grille et son réglage, l'isolement d'un étage, ⌥ + glisser, le menu du clic droit, les vingt images.

Dans `README.md`, remplacer :

```markdown
With `-captures <folder>`, the app writes fourteen PNG images of the room view
(2D, flight, 3D, zooms, isolated rooms, hover, the leader's card, the folded
legend), then quits, with no window. Its renderer draws neither the window nor
glass: the top of the window, the legend and the card are drawn as in their
mockups, with the window's three buttons in place. The app is sandboxed: the
folder must be inside its container.
```

par :

```markdown
With `-captures <folder>`, the app writes twenty PNG images of the room view
(2D, flight, 3D, zooms, isolated rooms, hover, the leader's card, the folded
legend; then the floors: the 2 × 2 grid in a square window, the same window
in a row, 3D with the garden inside the house, a floor isolated in 2D and in
3D, a room isolated from its floor), then quits, with no window. Its renderer
draws neither the window nor glass: the top of the window, the legend and the
card are drawn as in their mockups, with the window's three buttons in place.
The app is sandboxed: the folder must be inside its container.
```

Dans `README.md`, remplacer :

```markdown
The window shows the network in the house: a round platform per floor, a glass
card per room with one line per device, and the real radio links on top. It
stays dark, like its mockup, even when the Mac is in light mode. Design:
`docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` (in
French).
```

par :

```markdown
The window shows the network in the house: a round platform per floor or zone,
a glass card per room with one line per device, and the real radio links on
top. It stays dark, like its mockup, even when the Mac is in light mode.
Design: `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`,
and for the floors `docs/superpowers/specs/2026-10-03-maillage-thread-polissage-c-design.md`
(in French).
```

Dans `README.md`, remplacer :

```markdown
- **2D and 3D** (right capsule; the mode is kept from one launch to the next):
  2D is a top view, floors side by side; 3D stacks them inside the house
  sphere, with a slow rotation you can turn off. Switching is a 2.6 s flight.
```

par :

```markdown
- **Levels.** A zone can sit on a floor's level, next to it, inside or outside
  the house, like a garden next to the ground floor; this choice is kept with
  the floor order (`positions-pieces.json`, never in the demo), and a zone
  whose floor disappears becomes a floor again.
- **2D and 3D** (right capsule; the mode is kept from one launch to the next):
  2D is a top view, the platforms in a grid filled from the bottom, or in a
  row (Settings › General › Room view › Floors in 2D). The grid is chosen on
  the visible area, the window minus its top and the legend, so that the view
  is as large as possible: 2 × 2 in a square or tall window, often the row in
  a wide window with the legend open. 3D stacks the levels inside the house
  sphere, the zones next to a floor at its height, inside the sphere or around
  it, with a slow rotation you can turn off. Switching is a 2.6 s flight; the
  platforms slide to their place when the window is resized, when the legend
  opens or folds, when the setting changes, and after a level change.
```

Dans `README.md`, remplacer :

```markdown
  fade, a tag points to a parent elsewhere); click outside, Esc or "Home" in
  the path: come back. Double-click the background: back to the overview, zoom
```

par :

```markdown
  fade, a tag points to a parent elsewhere); click a floor, its name or its
  disc: isolate it the same way. Click outside or Esc: go up one step, from a
  room to its floor if you opened it from there, otherwise to the house; the
  "Home › Floor › Room" path leads there too. In 3D, ⌥ + drag pans the view in
  the screen plane. Double-click the background: back to the overview, zoom
```

Dans `README.md`, remplacer :

```markdown
- **Right clicks**: on a floor name, "Move up one floor" and "Move down one
  floor"; on the background, "Arrange rooms automatically" (kept places go,
  not the floor order); on a room (its box or its name) or a device, no menu.
```

par :

```markdown
- **Right clicks**: on a floor's name or disc, the menu of its level, under
  its name: "Move up one floor" and "Move down one floor" (the whole level),
  "On the same level as ▸", "Outside the house" and "On its own level"; on the
  background, "Arrange rooms automatically" (kept places go, not the floor
  order nor the levels); on a room (its box or its name) or a device, no menu.
```

Dans `README.fr.md`, remplacer :

```markdown
Avec `-captures <dossier>`, l'app écrit quatorze images PNG de la vue par
pièces (2D, envol, 3D, zooms, pièces isolées, survol, la fiche du chef, la
légende repliée), puis quitte, sans fenêtre. Son rendu ne dessine ni la
fenêtre ni le verre : le haut de la fenêtre, la légende et la fiche y sont
dessinés comme dans leurs maquettes, avec les trois boutons de la fenêtre à
leur place. L'app vit dans un bac à sable : le dossier doit être dans son
conteneur.
```

par :

```markdown
Avec `-captures <dossier>`, l'app écrit vingt images PNG de la vue par
pièces (2D, envol, 3D, zooms, pièces isolées, survol, la fiche du chef, la
légende repliée ; puis les étages : la grille 2 × 2 dans une fenêtre carrée,
la même fenêtre en rangée, la 3D avec le jardin dans la maison, un étage isolé
en 2D et en 3D, une pièce isolée depuis son étage), puis quitte, sans fenêtre.
Son rendu ne dessine ni la fenêtre ni le verre : le haut de la fenêtre, la
légende et la fiche y sont dessinés comme dans leurs maquettes, avec les trois
boutons de la fenêtre à leur place. L'app vit dans un bac à sable : le dossier
doit être dans son conteneur.
```

Dans `README.fr.md`, remplacer :

```markdown
La fenêtre montre le réseau dans la maison : un plateau rond par étage, une
carte de verre par pièce avec une ligne par appareil, et les vrais liens radio
par-dessus. Elle reste sombre, comme sa maquette, même quand le Mac est en
clair. Conception :
`docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`.
```

par :

```markdown
La fenêtre montre le réseau dans la maison : un plateau rond par étage ou par
zone, une carte de verre par pièce avec une ligne par appareil, et les vrais
liens radio par-dessus. Elle reste sombre, comme sa maquette, même quand le Mac
est en clair. Conception :
`docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, et
pour les étages `docs/superpowers/specs/2026-10-03-maillage-thread-polissage-c-design.md`.
```

Dans `README.fr.md`, remplacer :

```markdown
- **2D et 3D** (capsule de droite ; le mode est gardé d'un lancement à
  l'autre) : la 2D est une vue de dessus, les étages côte à côte ; la 3D les
  empile dans la sphère de la maison, avec une rotation lente qu'on peut
  couper. La bascule est un envol de 2,6 s.
```

par :

```markdown
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
```

Dans `README.fr.md`, remplacer :

```markdown
  montre un parent situé ailleurs) ; clic à côté, Échap ou « Maison » dans le
  fil : revenir. Double-clic sur le fond : retour à la vue d'ensemble, zoom et
  déplacement annulés. Clic sur un appareil ou sur son nom : sa fiche, qui
  glisse depuis le bas pendant que la vue se relève ; la fiche du chef du
  réseau Thread porte « 👑 Chef du réseau Thread, élu automatiquement ». Le
  premier clic agit aussi quand la fenêtre est inactive.
- **Clics droits** : sur un nom d'étage, « Monter d'un étage » et « Descendre
  d'un étage » ; sur le fond, « Replacer les pièces automatiquement » (les
  places gardées partent, pas l'ordre des étages) ; sur une pièce (sa boîte ou
  son nom) ou un appareil, aucun menu.
```

par :

```markdown
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
```

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/tester.sh`
Expected: `Test run with 369 tests in 37 suites passed` (cœur) et `Test run with 338 tests in 30 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 2 tests de plus pour l'app. `grilleDeLaDemo` et `maisonEviteLesEtages` s'ajoutent à l'app.

- [ ] **Step 7 : la suite en anglais.**

```bash
xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-polC/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-polC/maillage-tests-en.log"
```

Expected: `Test run with 369 tests in 37 suites passed` et `Test run with 338 tests in 30 suites passed`, `** TEST SUCCEEDED **` : les effectifs du Step 6.

- [ ] **Step 8 : les tests Python de la sonde, et les temps.** Ce plan ne touche pas à la sonde ; le coût de la disposition change, ses temps restent du même ordre.

```bash
python3 -m unittest discover -s sonde/test 2>&1 | tail -3
/usr/bin/python3 -m unittest discover -s sonde/test 2>&1 | tail -3
```

Expected : `Ran 141 tests` puis `OK`, deux fois.

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polC" TMPDIR="$HOME/Library/Caches/maillage-polC/" outils/mesurer.sh`
Expected: `mesure : disposition de la grande maison en 0.198646 s, 3000 coups` ; `mesure : placement de 150 noms en 0.3096625 ms, 150 poses` ; `mesure : placement de 150 noms tres serres en 2.77380835 ms, 30 poses` (ces temps-ci au rejeu, qui varient d'une machine à l'autre ; les coups et les poses, non), puis `Test run with 22 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 9 : les vingt images de démo.** Elles changent toutes : la démo gagne deux zones ; six s'ajoutent.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polC"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polC/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
```

Expected : 20 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`, `13-2d-fiche-du-chef.png`, `14-2d-legende-repliee.png`, `15-2d-carree-2x2.png`, `16-2d-carree-en-rangee.png`, `17-3d-jardin-dedans.png`, `18-2d-etage-isole.png`, `19-3d-etage-isole.png`, `20-3d-terrasse-depuis-le-jardin.png`) ; « l'app a quitté ».

Regarder (outil Read) : `01-2d.png` (la rangée, à mi-distance), `15-2d-carree-2x2.png` (la grille 2 × 2) et `16-2d-carree-en-rangee.png` (la même fenêtre en rangée), `05-3d.png` (le jardin hors de la maison, « ⌂ Maison » au-dessus de « Combles ») et `17-3d-jardin-dedans.png` (le jardin dans la maison), `18-2d-etage-isole.png` et `19-3d-etage-isole.png` (« Maison › Étage », la ligne « Étage isolé : Étage · … », les autres plateaux à 15 %), `20-3d-terrasse-depuis-le-jardin.png` (« Maison › Jardin › Terrasse », le repère « ↗ HomePod Palier · Salon, Rez-de-chaussée »). Le contrôleur les montre à Djoko à la tâche 8, à côté des rendus de la maquette.

- [ ] **Step 10 : commit.**

```bash
git add MaillageCoeurTests/NomsTests.swift MaillageThreadTests/NomsSceneTests.swift MaillageThreadTests/MoteurPiecesTests.swift MaillageThreadTests/FenetrePiecesTests.swift MaillageThreadTests/LegendePiecesTests.swift MaillageCoeur/Demo/NomsDemo.swift MaillageCoeur/Scene/PlacementNoms.swift MaillageThread/MaillageThreadApp.swift MaillageThread/Vues/Pieces/CapturesPieces.swift MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/Pieces/MoteurPieces.swift MaillageThread/Vues/Pieces/SigneLegende.swift README.md README.fr.md
git commit -m "Donner a la demo les combles et le jardin, le jardin au niveau du rez-de-chaussee et hors de la maison, poser le nom de la maison apres les noms d'etage, rendre vingt images de demo avec les etages, et decrire les niveaux, la grille et l'isolement d'un etage dans le README

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 8: Vérification avec Djoko (par le contrôleur, pas par un sous-agent)

**Files:** aucun.

**Interfaces:**
- Consumes : tout le plan ; l'app compilée dans le `DD` du plan ; les images de `captures-polC` et les rendus de la maquette.
- Produces : la vérification de C avec Djoko (spec, section 8), en vrai, des décisions du 03/10.

Ce qui ne se voit qu'en vrai : `ImageRenderer` ne rend ni les animations, ni le menu natif, ni les curseurs. Chaque action sur l'app de Djoko attend son accord.

- [ ] **Step 1 : les images, à côté de la maquette.** Montrer à Djoko, à côté des rendus PNG de la maquette v5, à 1100 × 760, que le contrôleur a reçus avec le brief de ce plan (`v5-2d-ordinaire.png`, `v5-2d-carree.png`, `v5-2d-rangee.png`, `v5-3d-jardin-dehors.png`, `v5-3d-jardin-dedans.png`, `v5-2d-etage-isole.png`, `v5-3d-etage-isole.png`) :
  1. `captures-polC/01-2d.png` (la rangée : la zone visible de la fenêtre des images, la légende ouverte, est large) avec `v5-2d-ordinaire.png`, et `14-2d-legende-repliee.png` (la rangée aussi, la légende repliée) ;
  2. `15-2d-carree-2x2.png` (une fenêtre carrée de 1000 pt, la légende ouverte : la grille 2 × 2) avec `v5-2d-carree.png`, et `16-2d-carree-en-rangee.png` (la même fenêtre, « En rangée ») avec `v5-2d-rangee.png` ;
  3. `05-3d.png` (le jardin hors de la maison) avec `v5-3d-jardin-dehors.png`, et `17-3d-jardin-dedans.png` avec `v5-3d-jardin-dedans.png` : la maison plus petite que dans la maquette (écarts), et « ⌂ Maison » au-dessus de « Combles » (précision 25) ;
  4. `18-2d-etage-isole.png` et `19-3d-etage-isole.png` avec `v5-2d-etage-isole.png` et `v5-3d-etage-isole.png` ;
  5. `20-3d-terrasse-depuis-le-jardin.png` : le fil complet, le repère au même niveau ;
  6. la légende : ses signes gardent la taille de B (précision 23).
- [ ] **Step 2 : dans l'app.** Recompiler (`outils/tester.sh`, avec le `DD` et le `TMPDIR` du plan), puis, avec son accord, quitter l'app qui tourne et lancer celle du `DD` en mode direct : `open "$HOME/Library/Developer/Xcode/DerivedData/maillage-polC/Build/Products/Debug/Maillage Thread.app"`. Avec Djoko, sur sa maison (spec, section 8) :
  1. **Grille et rangée** : Réglages › Général › Vue par pièces › « Étages en 2D » ; les plateaux glissent en 2,6 s vers leur nouvelle case. Redimensionner la fenêtre à la vue d'ensemble : la grille change de forme sur la zone visible, les plateaux glissent en 0,4 s, sans trembler près d'un seuil (l'hystérésis) ; ouvrir et replier la légende fait de même ; ouvrir une fiche ne change pas la grille (précision 7) ; zoomé, une pièce ou un étage isolés, ou en 3D, la grille attend le retour à la vue d'ensemble 2D. La grille de sa maison dans sa fenêtre habituelle.
  2. **Son extérieur au niveau du rez-de-chaussée** : clic droit sur son nom, puis sur son disque ; le menu natif (le nom grisé en tête, « Au même niveau que ▸ » et son sous-menu, la case « Hors de la maison », « Sur son propre niveau ») ; « Au même niveau que ▸ Rez-de-chaussée » (coché ensuite) : dans la maison, puis « Hors de la maison » ; en 3D, les plateaux, la sphère et le cadrage glissent en 0,9 s, en 2D en 0,4 s ; quitter et relancer l'app : le choix est gardé ; « Sur son propre niveau » le rend étage.
  3. **« Monter » et « Descendre »** d'un niveau entier, sa zone à côté comprise ; grisés en haut et en bas de la pile, et pour une zone à côté.
  4. **Isoler un étage** par son nom et par son disque, en 2D et en 3D : le disque s'éclaircit et le nom se souligne au survol, la main d'un lien ; les autres plateaux à 15 % ; un autre disque mène à son étage ; double-clic : la maison.
  5. **Remonter d'une pièce, selon sa provenance** : maison → pièce → Échap : la maison ; maison → étage → pièce → Échap : l'étage, puis la maison ; le clic à côté de même ; les crans du fil.
  6. **⌥ + glisser en 3D** : la main ouverte tant que ⌥ est tenue au-dessus de la vue, fermée pendant le geste ; la vue suit le pointeur à 0,7 fois sa vitesse ; relâcher ⌥ en route ne change rien ; avec ⌥, une pièce ne bouge pas ; la rotation lente s'arrête, puis reprend ; double-clic : la vue d'ensemble ; **puis l'envol vers la 2D, sans saut**.
  7. **« Réduire les animations »** : les glissements et les changements de niveau tout de suite, l'isolement d'un étage par un fondu.
  8. **La disposition** : les pièces qu'il n'a pas déplacées peuvent avoir changé de place, une fois ; celles qu'il a déplacées n'ont pas bougé.
  9. **« ⌂ Maison » et le nom de l'étage du haut**, en 3D, quand une zone est hors de la maison : ils ne se chevauchent plus (précision 25).
  10. **Retour.** Des comptes seulement, jamais un nom.
- [ ] **Step 3 : rendre l'app.** Quitter l'app du `DD` et relancer l'app habituelle de Djoko, s'il le souhaite. Puis reporter dans la spec de C, comme aux polissages A et B, les précisions que Djoko valide, et la note de vérification.

---

## Couverture des exigences

| Exigence (spec de C, et brief du plan) | Tâche | Preuve |
|---|---|---|
| Un fichier sans `aCote` ; l'aller-retour sur disque en version 1, ordre et places gardés | 1 | `zonesACote`, `etagesSeulement` |
| Une zone à côté, dans et hors de la maison ; étage principal absent, chaîne, boucle, zone à côté d'elle-même | 1 | `zoneACote`, `casTordus` |
| Les niveaux de la scène, dans leur ordre ; « Sans pièce » en bas | 1 | `niveaux`, `sceneDeLaDemo` |
| « Monter » et « Descendre » d'un niveau entier ; « Au même niveau que » ; « Hors de la maison » ; « Sur son propre niveau » | 1, 5 | `monterEtDescendre`, `auMemeNiveauQue`, `dehorsEtPropreNiveau`, `choixRendus`, `menuDuClicDroit` ; vérification 2 et 3 |
| Le repère « ailleurs » par niveaux, ↗ au même niveau avec le nom de la zone | 1 | `reperesParNiveau`, `repereAuMemeNiveau` ; image 20 |
| La 3D : étages seuls comme aujourd'hui ; zones dans la maison alternées ; la sphère qui les englobe ; zones hors de la maison, hors de la sphère et dans le cadre sur un tour | 2 | `etagesSeulementCommeAvant`, `zonesDansLaMaison`, `zonesHorsDeLaMaison` ; images 05 et 17 |
| La grille : exemples de 3.3, remplissage par le bas, rangée du haut centrée, 10 % et cases vides, hystérésis de 5 %, taille nulle, rangée d'aujourd'hui | 2 | `grille`, `choixDesColonnes`, `hysteresisEtTailleNulle`, `etagesSeulementCommeAvant` |
| La grille sur la zone visible, la légende ouverte ou repliée ; la légende recalcule la grille comme un redimensionnement (décision de Djoko du 03/10) | 4, 7 | `grilleSelonLaTaille`, `grilleSurLaZoneVisible`, `margeDeLaGrille`, `grilleDeLaDemo` ; images 01, 14, 15 et 16 ; vérification 1 |
| La disposition : même pour toutes les tailles et les deux modes 2D ; coût d'aujourd'hui pour un seul plateau ; tests de la section 10 verts | 3, 4 | `coutDUnSeulPlateau`, `vueDeReference`, `grilleSelonLaTaille` ; la suite |
| Le réglage « Étages en 2D », grille par défaut, tout de suite à la vue ouverte | 4 | `reglageEtagesEn2D`, `reglageDeLaGrille` ; vérification 1 |
| Glissements : 2,6 s au réglage, 0,4 s au redimensionnement, 0,9 s en 3D après un changement de niveau ; « Réduire les animations » | 4 | `redimensionnement`, `reglageDeLaGrille`, `glissementApresUnChangementDeNiveau` ; vérifications 1, 2 et 7 |
| La grille attend la vue d'ensemble ; la première vraie taille | 4 | `grilleQuiAttend`, `premiereVraieTaille` |
| Cadrage d'un étage isolé, en 2D et en 3D | 2, 5 | `cadrageDUnEtage`, `etageIsole` ; images 18 et 19 |
| Isoler un étage par son nom et son disque ; la provenance ; le fil | 5 | `cliquerUnEtage`, `provenance`, `fil` ; images 18 à 20 ; vérifications 4 et 5 |
| La priorité des clics ; le menu, article par article, sur le nom et sur le disque | 5 | `prioriteDesClics`, `menuDuClicDroit` ; vérification 2 |
| Les n° 8 et 9 du triage A | 5 | `numero8`, `numero9`, `nomsPendantUnIsolement` |
| ⌥ + glisser : mode à l'appui, 0,7 fois la vitesse, curseurs ; la pose exacte, à 10⁻⁶ | 6 | `deplacerDansLEcran`, `optionGlisser`, `envolEtVolsDepuisLaPoseExacte` ; vérification 6 |
| La démo : combles et jardin, le jardin au niveau du rez-de-chaussée hors de la maison ; 2 × 2 dans une fenêtre carrée | 7 | `maisonDeDemo`, `sceneDeLaDemo`, `grilleDeLaDemo` ; image 15 |
| « ⌂ Maison » évite les noms d'étage (décision de Djoko du 03/10) | 7 | `maisonEviteLesEtages` ; image 05 ; vérification 9 |
| La légende garde la taille de B (décision de Djoko du 03/10) | 7 | `tailleDesSignes` |
| Les captures de démo : toutes, et celles de la section 7 | 1 à 7 | `imagesDeDemo` ; `captures-polC` |
| Catalogue : tous les nouveaux textes, avec leur anglais | 4, 5 | `CataloguesTests` ; la suite en anglais |
| Vérification avec Djoko (spec, section 8) | 8 | Step 2 |
