# Maillage Thread, plan 4b : la vue par pièces (2D et 3D) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** remplacer le graphe par la vue par pièces : le réseau Thread rangé par étage et par pièce, en vraie 2D (vue de dessus) et en 3D (plateaux empilés dans la sphère de la maison), avec l'envol de l'une à l'autre, le zoom sémantique, la pièce isolée et les places gardées ; avec les recos validées par Djoko le 30/09 : la pièce des routeurs d'Apple (d'après leur nom, ou au choix), une fenêtre toujours sombre, le double-clic sur le fond.

**Architecture :**
- **Le cœur** (`MaillageCoeur/Scene/`, Swift pur, sans SwiftUI ni AppKit, testé) porte la scène, séparée du moteur qui la dessine (spec, section 9) :
  - `GrapheReseau` : les nœuds et les liens d'un réseau, repris de `Disposition`, sans ses anneaux ;
  - `ScenePieces` : les étages, les pièces et les nœuds, selon les règles de la section 2 ;
  - `CartesPieces` : la taille des cartes et la place des nœuds, à partir des largeurs de noms mesurées par l'app ;
  - `DispositionPieces` : séparation, tassement, coût, optimisation, pièces fixées, budget de 3 000 coups ;
  - `PlacesGardees` : le fichier `positions-pieces.json` ;
  - `PiecesRouteurs` : la pièce d'un routeur de bordure que Maison ne place pas, d'après son nom ou au choix, et le fichier `pieces-routeurs.json` ;
  - `CameraScene` : orbite, projection, envol, vols, zoom vers le curseur, bornes ;
  - `PlacementNoms` : placement glouton des noms, priorités, stabilité, traits de rappel, zoom sémantique ;
  - `SceneProjetee` : ce que la caméra rend au moteur, en coordonnées de l'écran. C'est le contrat entre la scène et le moteur.
- **L'app** (`MaillageThread/Vues/Pieces/`) :
  - `LibellesNoeuds`, `DessinNoeud`, `StylesNoms`, `MesureNoms`, `EntreeScene` : les noms des nœuds, leur dessin (sorti de `GrapheCanvas`), leur mesure, et la scène tirée de la surveillance ;
  - `MoteurPieces` et `RenduCanvas` : le moteur `Canvas` (horloge, gestes, animations, disposition hors du fil principal, dessin en huit couches) ;
  - `FenetrePieces` : la fenêtre, toujours sombre (barre, 2D/3D, rotation lente, fil, ligne de niveau, fiche, clics droits, bandeau « sans pièces ») ; `PiecesChoisies` : les pièces choisies des routeurs et « Placer dans une pièce… » de la fiche ; `CapturesPieces` : les images de démo (`-captures`).
- **Ce qui disparaît** (tâche 13) : `Disposition`, `GrapheCanvas`, `PlacementLibelles`, `Projection`, `MesureLibelles`, `FenetreGraphe` et leurs tests. Les morceaux communs de l'ancienne fenêtre (barre d'outils, ligne de la tournée, bandeau de scission, légende, « Renommer… ») restent, dans `MorceauxFenetre.swift` ; la fiche et ses courbes (plan 3b) passent dans `Vues/Pieces/`.
- **Un défaut corrigé en passant** (tâche 1) : un enfant vu deux fois par la sonde (il a changé de parent) n'est plus qu'un nœud, au lieu d'un second nœud « rloc:XXXX » inconnu.

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI (`Canvas`, `TimelineView`, `ImageRenderer`), Observation, simd, AppKit (molette, Échap, fenêtre), Swift Testing, XcodeGen, catalogue de textes (`.xcstrings`).

**Spec :** `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, sections 1, 2 et 4 à 10, à lire avec ce plan ; la section 3 (le passeur et les zones) est le plan 4a, déjà passé. Maquette de référence : `docs/superpowers/specs/maquettes/vue-pieces-v13.html`. Le code part du prototype A (`.superpowers/archives/vue-pieces/A-canvas/`, local, non publié) : projection, ellipse exacte de la sphère, éclairage des faces et placement des noms, réorganisés en cœur et en app.

**Validé par Djoko le 01/10** (« ok pour tes recos ») : les précisions 23 à 25, le double-clic en fondu seul avec « Réduire les animations », l'aspect du menu « Placer dans une pièce… » à regarder à la tâche 15.

**Quand l'exécuter.** Maintenant : ce plan est écrit et validé sur le `main` du 01/10 (`14f3e89`), où les plans 3b et 4a sont passés, avec la ronde de correctifs de la relecture finale du 3b. Il remplace la version du 30/09 (`2026-09-30-maillage-thread-plan4b-vue-pieces.md`, écrite sur `3c46889`, jamais commitée sur `main`). **Les numéros de ligne cités sont indicatifs : l'exécutant se repère aux noms (types, fonctions, commentaires) et aux textes cités.** Si un texte à remplacer n'est plus exactement le même, il applique le même changement au texte du moment et le dit dans son rapport.

## Plans 3b et 4a : passés

La version du 30/09 de ce plan portait deux sections, « À rejouer après le plan 3b » et « Points de contact avec le plan 4a ». Les deux plans sont passés sur `main` : leurs points de contact sont maintenant dans les tâches elles-mêmes, vérifiés au rejeu du 01/10. En bref :
- **plan 3b** : la fiche reçoit l'heure de la fenêtre et montre les courbes de l'historique (tâche 12 : `FenetrePieces`, ses marges et leur test) ; `CourbesFiche.swift` suit la fiche dans `Vues/Pieces/`, `CourbesFicheTests` teste `FenetrePieces.margeBas`, et `Surveillance` nomme les nœuds de la sonde par `LibellesNoeuds.inconnu` (tâche 13) ; les README parlent des courbes (tâche 14) ;
- **plan 4a** : le contrat des zones est là (plus de Step 0 à la tâche 1) ; `NomsInternes` remplace `DossierNoms` (tâche 12) ; les README décrivent le rafraîchissement sans dossier (tâche 14).

## Code validé, faits établis et précisions

**Code validé avant exécution.** Le 01/10, tout le code de ce plan a été écrit, compilé et testé dans une copie de `main` (`14f3e89`) :
- toute la suite passe, en français et en anglais : 319 tests en 34 suites pour le cœur et 248 en 28 pour l'app (avant ce plan : 277 en 26 et 247 en 27) ;
- les temps de la section 10, en Release : la disposition de la grande maison inventée en 0,25 s, budget de 3 000 coups atteint, et le placement de 150 noms en 0,31 ms ;
- les tests Python de la sonde passent (`python3 -m unittest discover -s sonde/test`, puis avec `/usr/bin/python3`) : ce plan n'y touche pas ;
- les douze images de démo de la tâche 12 sont identiques, octet pour octet, à celles du 30/09, relues alors à côté de la maquette v13 ; deux d'entre elles ont été relues de nouveau.

Le plan a ensuite été rejoué tâche par tâche sur une copie neuve de `main` (`14f3e89`) : l'erreur avant le code, les tests après, la suite entière. Les résultats attendus ci-dessous viennent de ce rejeu, comme la liste du `git add` de chaque tâche. L'arbre final est identique à la copie validée. D'autres changements de `main` changeraient ces totaux : chaque tâche donne donc ses effectifs par suite, et l'écart des totaux.

Exécuter une tâche, c'est transcrire les fichiers et les blocs donnés, compiler et tester. Si un fichier doit s'écarter du texte donné, l'exécutant le dit dans son rapport, avec la raison.

**Blocs de modification.** Un fichier existant est modifié soit en entier (« fichier entier »), soit par blocs « remplacer … par … ». Chaque texte à remplacer apparaît une seule fois dans le fichier au moment où on l'applique. Les blocs s'appliquent dans l'ordre, du haut vers le bas, au texte exact, espaces compris (outil Edit). Un fichier créé l'est tel quel ; un fichier déplacé l'est par `git mv`, puis modifié à sa nouvelle place ; un fichier supprimé l'est par `git rm`. Les changements trop longs pour des blocs (tâche 13) passent par un script Python, lancé depuis la racine du dépôt : il vérifie chaque texte avant de le remplacer et s'arrête au premier qui manque (`git diff` montre alors ce qu'il a déjà écrit).

**Faits établis, utiles à l'exécution** (copies validées, 30/09 et 01/10) :
- **Temps de calcul.** En Debug non optimisé, la disposition de la grande maison prend 25 s et le placement de 150 noms 4,9 ms, contre 0,25 s et 0,31 ms en Release. D'où :
  - les deux tests de temps ne tournent qu'en Release, par `outils/mesurer.sh` (tâche 4) ; en Debug, `outils/tester.sh` les saute, et le journal complet le dit : `Test tempsGrandeMaison() skipped: "mesure en Release (outils/mesurer.sh)"` ;
  - le cœur est compilé optimisé même en Debug (`SWIFT_OPTIMIZATION_LEVEL: "-O"`, tâche 4) : sans cela, dans l'app de développement, la disposition de la démo prend 2,8 s au lieu de 0,04 s.
- **Mesures en Release.** Le schéma de l'app ne sert pas : en Release, l'édition des liens des tests de l'app échoue (un descripteur opaque de `View.task`, atteint par réflexion à travers le corps de `FenetrePieces`). `outils/mesurer.sh` passe donc par un schéma `MaillageCoeur`, le cœur et ses tests seuls, avec `ENABLE_TESTABILITY=YES` pour `@testable import`, et `ONLY_ACTIVE_ARCH=YES` : sinon, l'édition des liens pour x86_64 avertit, et les avertissements sont des erreurs.
- **Bac à sable.** L'app ne peut écrire que dans son conteneur : le dossier de `-captures` est sous `~/Library/Containers/fr.djoko.maillage/Data/`.
- **`ImageRenderer`** rend un `Button` en gabarit vide : dans les captures, le fil est un texte (`FilPieces(capture: true)`).
- **Démo** (tâches 9 et 10) : sa disposition n'a aucun lien qui traverse une pièce ; 1 140 coups, coût de 764,49 au départ, 312,24 retenu.
- **Tailles de texte.** Sur macOS, `caption` et `caption2` font 10 pt : les 11 et 12 pt de la spec sont écrits en points (`.system(size:)`).
- **Tests de l'app,** qui tournent dans l'app : deux sessions en même temps sur ce Mac peuvent s'interrompre l'une l'autre (`Test crashed with signal term` sur un test sans rapport). Relancer alors la suite, seule.
- **Le `noms.json` de Djoko** (des comptes seulement, rien de copié) : 133 accessoires, dont aucun d'Apple. HomeKit ne donne à une app tierce ni les HomePod ni l'Apple TV : ses routeurs de bordure n'ont pas de pièce par Maison, d'où les précisions 23 et 24.
- **Fenêtre sombre** (tâche 12) : l'apparence sombre posée sur la `NSWindow` passe à ses feuilles (« Renommer… ») et à ses menus ; vérifié hors écran, sur une fenêtre partie en clair.
- **Un enfant vu deux fois** (tâche 1) : sur le `main` du 01/10, le rapprochement en faisait encore un second nœud, « rloc:XXXX », inconnu (le test de la tâche 1 échoue sans le bloc de `Rapprochement.swift`).

**Précisions à la spec.** Les précisions 1 à 22 datent du 30/09 ; Djoko a validé le 30/09 les recos qui changent les précisions 15 et 17 et ajoutent les précisions 23 et 24 (« ok pour tes recos »), que la tâche 14 écrit aussi dans la spec ; leurs règles de détail (le nom de la précision 23, la clé et le fichier de la précision 24, le fondu de la précision 17) ont été fixées le 01/10. La précision 25 en découle ; la précision 26 corrige un défaut relevé pendant le plan 3a. Tout ce qui n'a pas été validé reste assumé, à faire valider par Djoko (tâche 15).
1. **Pièce d'un routeur de bordure** (spec 2.3, « par la correspondance du plan 2 ») : celle de l'accessoire de Maison qui porte le nom de son annonce (« HomePod salon »). Un appareil prend la pièce de son accessoire (`AppareilAffiche.piece`, plan 2). Sans un tel accessoire : les précisions 23 et 24.
2. **Couronne 👑** : le chef de chaque partition (son annonce), et le chef du maillage de la sonde.
3. **« Routeurs d'Apple »** (ordre des lignes et rayons, spec 4.2) : les routeurs de bordure. Le rayon de 15 px va au « centre » du graphe actuel (le premier routeur de la partition : son chef s'il est routeur de bordure, sinon le BBR primaire) ; 13 px aux autres routeurs de bordure, annoncés ou vus par la sonde ; 8 px aux autres routeurs (ceux de la sonde, et les appareils qui routent) ; 7 px aux autres nœuds.
4. **« Sans pièce »** : sa teinte (FNV-1a) et son rang dans l'étage viennent de son nom français, quelle que soit la langue : les couleurs ne changent pas avec la langue de l'app.
5. **Tailles des noms,** en points : 11 (appareil, compte d'une pièce, repère « ailleurs »), 12 (routeur, pièce, étage), 13 (« ⌂ Maison »), puisque `caption2` et `caption` font 10 pt sur macOS.
6. **2D** : la rangée des plateaux est centrée sur x = 0 (la spec dit « côte à côte sur x »).
7. **Ligne de niveau** (en bas à gauche) : « Vue d'ensemble : les pièces » sous k = 0,42 ; « Mi-distance : les pièces et les routeurs » jusqu'à 0,6 ; au-delà, « N noms masqués faute de place : rapprochez-vous (molette) », ou « Tous les noms sont lisibles » ; en pièce isolée, « Pièce isolée : Salon · clic sur une autre pièce pour y aller, clic à côté ou Échap pour revenir ». Ne comptent comme masqués que les noms dont l'objet est à l'écran.
8. **Fil** « Maison › Salon » : sous la barre d'outils, à gauche ; « Maison » y est un lien en pièce isolée.
9. **Clic à côté des pièces** : il ferme aussi la fiche. **Échap** ramène aussi à la vue d'ensemble après un zoom ou un déplacement, sans pièce isolée.
10. **Liens éclairés** : au survol d'un de leurs bouts, et pour le nœud sélectionné (fiche ouverte).
11. **Rattachements supposés et fils « ailleurs »** : dans la couche 3, avec les liens enfant → parent.
12. **« Réduire les animations »** : l'envol devient un fondu de 0,3 s par le fond (la scène s'efface, bascule à mi-chemin, revient) ; la spec dit « un fondu entre les deux vues finales ».
13. **Pièces fixées** : un étage qui en a une n'est pas recentré après le tassement, pour que les places gardées restent justes par rapport au centre du plateau.
14. **Cœur optimisé en Debug** (voir les faits établis).
15. **Fenêtre toujours sombre** (reco validée le 30/09) : la maquette est sombre ; la fenêtre de la vue par pièces reste en apparence sombre même quand le Mac est en clair, au lieu de mêler un fond clair et des pastilles sombres. `FenetrePieces.assombrir` pose `NSAppearance(named: .darkAqua)` sur sa fenêtre (barre, menus, fiche, feuilles « Renommer… ») et la vue prend `colorScheme` sombre et `Palette(sombre: true)`. Les autres fenêtres (journal, réglages, menu de la barre) suivent le Mac.
16. **Liens radio** : 2 pt quelle que soit la qualité (spec 2.3 et 5). L'épaisseur selon la qualité du graphe (3, 2,2 et 1,4 pt) disparaît, avec son test.
17. **Double-clic sur le fond** (reco validée le 30/09) : il ramène d'un geste à la vue d'ensemble, pièce isolée relâchée, zoom et déplacement annulés, par le vol de 1,3 s ; avec « Réduire les animations », par un fondu de 0,3 s par le fond, comme la bascule (précision 12 ; la spec dit les autres vols immédiats, et ils le restent). Le clic simple « à côté » n'attend pas : il ferme la fiche et la pièce isolée tout de suite, et le second clic, à moins de l'intervalle du double-clic de macOS et de 5 points, fait le reste. Deux clics trop espacés, dans le temps ou sur l'écran, restent deux clics simples ; sur une pièce ou un nœud, le double-clic ne fait rien de plus que ses deux clics.
18. **Rotation lente** : allumée à chaque lancement ; seul le mode 2D ou 3D est gardé d'un lancement à l'autre (préférence `vuePieces3D`).
19. **Menu** : l'article « Ouvrir le graphe » garde son nom, et ouvre la vue par pièces.
20. **Repère « ailleurs »** : le nom du parent, sans sa couronne ; ☾ et ⚠︎ restent.
21. **Marges de la scène** (la place de l'interface autour) : en haut 72 pt, plus 40 avec le bandeau de scission, 40 avec la ligne de la tournée et 44 avec le bandeau « sans pièces » ; en bas 30 pt, 190 avec la fiche, 360 avec la fiche et ses courbes (plan 3b).
22. **`-captures`** n'est lu qu'avec `-demo`, et écrit dans le conteneur de l'app.
23. **Pièce d'un routeur d'Apple d'après son nom** (reco validée le 30/09 ; `PiecesRouteurs.piece(nom:parmi:)`). Pour un routeur de bordure sans pièce de Maison (précision 1), et seulement pour lui :
    - **le nom** est celui qu'affiche l'app : son surnom, sinon l'instance de son annonce (`Surveillance.nomsRouteurs(pour:)`) ;
    - **les pièces** sont celles de Maison : celles des accessoires et celles des zones, sans nom vide ;
    - **la comparaison** ignore la casse, les accents et la largeur (`folding`), et porte sur des mots entiers : suites de lettres ou de chiffres, qui doivent se suivre (« HomePod mini chambre » → « Chambre » ; « HomePod-salle-de-bain » → « Salle de bain » ; « HomePod Salons » ou « Bureautique » → rien) ;
    - **le nom de pièce le plus long gagne**, en caractères, sans casse ni accents (« HomePod chambre d'amis » → « Chambre d'amis », pas « Chambre ») ;
    - **une égalité ambiguë ne place rien** : si deux pièces différentes ont cette longueur (« HomePod bureau entrée »), ou le même nom sans les accents (« Entrée » et « Entree »), le routeur va dans « Sans pièce ».
24. **Pièce d'un routeur d'Apple au choix** (reco validée le 30/09). La fiche d'un routeur de bordure sans pièce de Maison, dans une maison qui a des pièces, propose « Placer dans une pièce… » : un menu avec « D'après son nom » (la précision 23), puis les pièces de la maison par nom ; le choix en cours est coché. Le choix :
    - **prime** sur le nom ; une pièce choisie qui n'est plus dans Maison ne compte plus (le nom reprend la main, le choix reste dans le fichier) ;
    - **est gardé** dans `pieces-routeurs.json`, dans le conteneur de l'app, à côté de `positions-pieces.json`, jamais dans le dépôt ; en démo et sous les tests, en mémoire seulement ;
    - **par maison** (`domicile`), **sous l'instance de l'annonce** du routeur : c'est l'identité que l'app garde déjà pour lui (ses surnoms, dans `surnoms.json`, et son id de nœud). Elle ne change ni avec son RLOC16 ni à son redémarrage, et se lit sans la sonde. Elle change seulement si le routeur est renommé dans Maison : son choix se perd alors, comme son surnom. Les autres identités ne vont pas : l'ExtMac n'est connue qu'avec la sonde (ou par le `xa` de l'annonce) et `identites-routeurs.json` les range par RLOC16, effacées au changement de partition ; le RLOC16 change avec le rôle et la partition.
    
    Le calcul est dans le cœur (`PiecesRouteurs`, testé) ; le stockage et le menu dans l'app (`PiecesChoisies`, `MenuPlacer`), comme les places gardées.
25. **Routeur que la sonde seule connaît** (« rloc:XXXX », avec ses annonces candidates) : ni nom ni choix, faute d'une identité stable ; il reste dans « Sans pièce » (spec 2.3).
26. **Un enfant vu deux fois** (défaut relevé pendant le plan 3a) : quand un enfant passe d'un routeur muet à un routeur qui répond, l'ancienne entrée du balayage reste jusqu'à 30 minutes, en plus de la Child Table. Le rapprochement (`MaillageAffiche`) ne garde, par ExtMac, que l'entrée que retient `Maillage.enfantsIdentifies` (la sonde, puis une table, puis le balayage) : l'autre n'est ni un nœud ni un lien. Le graphe, la fiche et la vue le voient ainsi.
27. **Pièce d'un autre nœud au choix** (demande de Djoko, 01/10 ; spec 2.3 et 2.4). Tout nœud sans pièce de Maison, dans une maison qui a des pièces, dont l'ExtMac est connue (par la sonde ou par son nom d'hôte Matter) peut être placé par sa fiche, « Placer dans une pièce… » : un appareil que la sonde seule connaît, une annonce que Maison ne reconnaît pas, un routeur Thread qui n'est pas de bordure. Un routeur de bordure garde les précisions 23 à 25 ; un nœud sans ExtMac n'a ni choix ni menu. Le menu commence par « Sans pièce », qui efface le choix. Priorité : la pièce de Maison, puis le choix, puis « Sans pièce » (pas de règle du nom). Le choix est gardé par maison sous l'ExtMac (16 hexadécimaux majuscules), dans `pieces-routeurs.json`, champ facultatif `appareils` : la version reste 1, un fichier d'avant se lit sans perte, une app d'avant lit encore les routeurs. Sa limite : voir « Limites connues ».

**Limites connues :**
- Chez Djoko, un HomePod ou une Apple TV dont le nom ne contient aucune pièce (« HomePod Palier », « Apple TV ») reste dans « Sans pièce » jusqu'à ce qu'il le place (précision 24).
- Le choix ne s'applique que tant que l'ExtMac du nœud est connue : après un changement de parent (nouveau RLOC16), ou au lancement de l'app, un appareil endormi sous un routeur qui répond reste « Sans pièce » jusqu'à ce que la sonde lise son ExtMac : dans la même tournée s'il répond dans les 8 s, sinon jusqu'à 30 minutes plus tard. Le choix reste dans le fichier (précision 27).
- La légende des liens reste celle du graphe jusqu'au polissage (spec, section 1 : la légende A).
- Pas de description VoiceOver de la scène (spec, section 11), comme le graphe.
- Un calcul de disposition déjà lancé va jusqu'au bout, même quand la scène change entre-temps : un nouveau calcul part aussitôt, et le résultat de l'ancien est jeté.

## Global Constraints

- **Plateformes :** app en macOS 26.0 minimum, développée avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`. Notamment, `Text + Text` est déprécié dans le SDK de macOS 26, donc refusé.
- **Code :** identifiants et commentaires en français **sans accents** ; textes affichés avec accents ; tests en Swift Testing. Les nouveaux dossiers (`MaillageCoeur/Scene/`, `MaillageThread/Vues/Pieces/`) sont pris par les sources de `project.yml` sans le modifier ; la tâche 4 ne touche `project.yml` que pour optimiser le cœur en Debug et ajouter le schéma des mesures.
- **La scène séparée du moteur** (spec, section 9) : `MaillageCoeur/Scene/` n'importe que Foundation, simd et CoreGraphics, jamais SwiftUI ni AppKit. Un moteur RealityKit pourrait plus tard prendre `ScenePieces` et la caméra ; `SceneProjetee` est le contrat du moteur `Canvas`.
- **Valeurs de la spec**, recopiées telles quelles :
  - unités : `PX = 24` ; `GAP = 80`, `LAB = 28`, `MARGE = 56`, `ESP = 140` px ;
  - cartes : rayons 15, 13, 8 et 7 px, lignes de `max(30, 2·r + 12)` px, colonne de `14 + 2·rmax + 9 + nom + 14` px, 1 à 3 colonnes au rapport le plus proche de 1,3, noms coupés à 40 caractères ;
  - disposition : 900 tours à 0,996 puis 60 ; tassement court 200 tours à 0,998 puis 60 ; départs à l'angle `phase + i·2,39996` et au rayon `√(i + 0,5)·6`, `phase = essai·1,047` ; coût : rayons, 0,3 × longueur, 6 + 4 × longueur traversée, 5 par croisement, 0,1 × écart entre étages ; 6 départs, 25 tours, **budget de 3 000 coups** ;
  - étages : `ETAGE = 1,5 × RMAX`, blocs de `0,04 + 2,4·u`, sphère de rayon `hypot(RMAX + 0,8, (Y_haut + 2,4)/2 + 1,4) + 0,4`, 34 px au-dessus des plateaux pour leurs noms ;
  - rendu : plateaux de 128 points, dégradé de 0,26 à 0,08, contour à 0,45 ; faces en `(2,2 + 1,6·n·l)/π` en linéaire, lumière de `(−10, 30, 14)`, verre de 0,13 à 0,18, arêtes à 0,75 ; liens radio 2 pt, enfant → parent 1 px blanc à 0,28, éclairés à 0,85 ; sphère `force · (0,02 + 0,45·(1 − |n·v|)^2,5)`, couleur `(0,55 ; 0,72 ; 1,0)`, `force = u²`, équateur à `0,18·u`, rayon `R3·(0,8 + 0,2·u)` ; pastilles au plus 1,1 × leur rayon, au moins 3 px ;
  - noms : anneaux 3, 14, 28, 44 et 62 px, 8 directions, diagonales à 0,7 ; priorités 0 à 8 ; 2 px de jeu, 4 px de bord ; 0,5 s de stabilité ; traits de rappel dès le deuxième anneau, `rgba(230, 236, 250, 0,45)` ; zoom sémantique à k = 0,42 et 0,6 ;
  - caméra : plan proche à 0,5 ; 2D : champ de 2°, vue `max(h·1,1 ; l·1,05 / aspect)` ; 3D : champ de 40°, inclinaison 0,95 rad, orbite −0,75 rad, vue `2,4·R3·max(1, 1/aspect)` ; envol de 2,6 s en cubique, champ `2 + 38·u^1,6` ; vol de 1,3 s ; un tour en 2 min ; bornes : 3 unités à 3 × la vue d'ensemble en 2D, 5 unités à 2,5 × en 3D, inclinaison de 0,15 à 1,45 rad, amorti de 5 % par image ; pièce isolée : hauteur `max(l/aspect, p)·1,3·1,8 + 6`, pièce grandie de 1,3 ×, les autres à 15 %, leurs noms à 0,45 ;
  - teintes : `#3b82f5`, `#22c55e`, `#f59e0b`, `#94a3b8`, `#a855f7`, `#06b6d4`, `#ec4899`, `#818cf8`, par FNV-1a sur 32 bits du nom en UTF-8, modulo 8, puis la suivante libre de l'étage.
- **Temps de calcul** (spec, section 10) : sur une grande maison inventée (20 pièces, 100 appareils), la disposition tient **sous 1 s** et le placement de 150 noms **sous 2 ms**, en **Release**. Ils se mesurent par `outils/mesurer.sh` (tâche 4), jamais par `outils/tester.sh`, qui compile en Debug et saute ces tests (faits établis ci-dessus). La borne de 2 ms vaut pour une fenêtre ordinaire, le cas du test. Au pire cas mesuré, 150 noms très serrés, le placement tient sous 4 ms, sans effet visible : une image dispose de 16,7 ms. Décidé avec Djoko le 01/10, après la relecture finale ; un troisième test de temps le mesure.
- **Déterminisme :** aucun hasard dans la scène ; mêmes entrées, même disposition, sur toutes les machines. Le budget compte des coups, pas du temps.
- **Pas de travail lourd sur le fil principal pendant un mouvement** (spec, section 7) : la disposition se calcule hors du fil principal ; un relevé reçu pendant l'envol ou un vol s'applique à la fin du mouvement.
- **Textes de l'app :** catalogue `MaillageThread/Ressources/Localizable.xcstrings`, français source et anglais obligatoire. Une tâche qui change des textes synchronise elle-même le catalogue, dans cet ordre :
  1. compiler ;
  2. `outils/synchroniser-textes.sh` ;
  3. dans `outils/traductions/interface.json`, retirer les clés que le code n'a plus et ajouter les nouvelles (la tâche donne le script). Une clé morte laissée là, `outils/traduire.py` la remettrait au catalogue ;
  4. `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`.

  Le test `CataloguesTests` refuse une clé absente comme une clé morte.
- **Tests indépendants de la langue :** une attente sur un texte affiché reprend la même clé que le code (`String(localized: "Vue d'ensemble : les pièces")`), jamais une chaîne française figée. Les tests passent en anglais (vérifié le 01/10) :

  ```bash
  xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-plan4b/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-plan4b/maillage-tests-en.log"
  ```
- **Commandes,** depuis la racine du dépôt, toujours avec un dossier de produits (`DD`) et un dossier temporaire (`TMPDIR`) propres à ce plan : une autre compilation (l'app de Djoko, une autre session) ne partage ni ses produits ni son journal. Le shell d'un agent ne garde pas ses variables d'une commande à l'autre : chaque commande les porte. Une fois, avant la tâche 1 :

  ```bash
  mkdir -p "$HOME/Library/Caches/maillage-plan4b"
  ```

  Puis, par exemple :

  ```bash
  DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/ScenePiecesTests
  ```

  `outils/tester.sh [cibles…]` génère le projet, compile et lance les tests, en Debug ; les produits vont dans `DD`, le journal complet dans `$TMPDIR/maillage-tests.log`. `outils/mesurer.sh` (tâche 4) lance les deux tests de temps en Release, dans le même `DD`, journal dans `$TMPDIR/maillage-mesures.log`. `outils/synchroniser-textes.sh` lit les produits dans le même `DD`. La première compilation dans ce `DD` neuf prend quelques minutes.
- **Une suite de tests de l'app à la fois** sur ce Mac (faits établis) : si un test sans rapport échoue avec `Test crashed with signal term`, vérifier qu'aucune autre session ne teste l'app (`pgrep -fl xcodebuild`), puis relancer la suite.
- **L'app :** de la tâche 1 à la tâche 14, un agent ne la lance qu'en mode démo, pour ses captures (tâche 12) : `open -n -g -W "$DD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures <dossier du conteneur>`. Elle écrit ses images sans fenêtre et quitte d'elle-même (`-W` attend qu'elle ait quitté) ; l'agent vérifie qu'elle ne tourne plus. Jamais en mode direct, jamais de `screencapture`. La tâche 15 se fait avec Djoko, par le contrôleur.
- **Données personnelles** (le dépôt est public sur GitHub, `Djoko-cli/maillage-thread`) :
  - `noms.json` n'est jamais commité, ni lu par un test : les données de test sont inventées (la maison de démo de la maquette, des maisons inventées) ;
  - aucun nom d'accessoire, de pièce ni de zone de la maison de Djoko dans un fichier commité ; la vérification (tâche 15) ne note que des comptes ;
  - `positions-pieces.json` et `pieces-routeurs.json` vivent dans le conteneur de l'app, jamais dans le dépôt ;
  - les noms de routeurs, de pièces et de zones des tests et du plan sont inventés (ceux de la démo).
- **Signature :** l'app reste ad hoc (`Signature.xcconfig`). **Ne jamais créer `Local.xcconfig`.** Aucun identifiant d'équipe, empreinte de certificat ni adresse électronique dans un fichier commité.
- **Commits :**
  - un par tâche, message en français sans accents, terminé par la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - `git add` avec la liste de fichiers de la tâche (un fichier déplacé ou supprimé l'est déjà par `git mv` ou `git rm`), **jamais `git add -A` ni `git add .`** ;
  - jamais de push.
- **Interdits pour les agents :** `sudo` ; ouvrir un port série ou flasher ; lancer l'app en mode direct ; `screencapture` ; lancer le passeur ou `outils/passeur.sh` ; réveiller l'écran.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `MaillageCoeur/Scene/GrapheReseau.swift` | nœuds et liens d'un réseau ; `EtatAffiche`, `AppareilAffiche` (sortis de `Disposition.swift`) | 1 |
| `MaillageCoeur/Maillage/Rapprochement.swift` | un enfant vu deux fois n'est qu'un nœud (1) ; un commentaire (13) | 1, 13 |
| `MaillageCoeur/Scene/ScenePieces.swift` | étages, pièces, nœuds, teintes (spec 2) | 2 |
| `MaillageCoeur/Scene/CartesPieces.swift` | cartes des pièces (spec 4.2) | 3 |
| `MaillageCoeur/Scene/DispositionPieces.swift` | disposition des pièces d'un étage (spec 4.3) | 4 |
| `project.yml`, `outils/mesurer.sh` | cœur optimisé en Debug ; schéma et script des mesures en Release | 4 |
| `MaillageCoeurTests/MaisonInventee.swift`, `MaillageCoeurTests/Compilation.swift` | maisons inventées des tests ; Debug ou Release | 4 |
| `MaillageCoeur/Scene/PlacesGardees.swift` | `positions-pieces.json` (spec 2.4) | 5 |
| `MaillageCoeur/Scene/PiecesRouteurs.swift` | pièce d'un routeur de bordure que Maison ne place pas : d'après son nom, au choix ; `pieces-routeurs.json` (précisions 23 et 24) | 5 |
| `MaillageCoeur/Scene/CameraScene.swift` | orbite, projection, géométrie de la maison, envol, vols, zoom, bornes (spec 4.4 et 7) | 6 |
| `MaillageCoeur/Scene/PlacementNoms.swift` | placement des noms, zoom sémantique (spec 6) | 7 |
| `MaillageCoeur/Scene/SceneProjetee.swift` | la scène projetée, contrat du moteur (spec 5 et 9) | 8 |
| `MaillageCoeur/Demo/NomsDemo.swift` | pièces, routeurs et zones de la maquette pour la démo | 9 |
| `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, `StylesNoms.swift`, `DessinNoeud.swift`, `MesureNoms.swift`, `EntreeScene.swift` | noms, styles, dessin des nœuds, mesure des noms, scène de l'app | 10 |
| `MaillageThread/Vues/Graphe/Palette.swift` (puis `Vues/Pieces/`) | couleurs de la vue par pièces (10) ; celles du graphe retirées (13) | 10, 13 |
| `MaillageThread/Vues/Pieces/RenduCanvas.swift`, `MoteurPieces.swift` | le moteur `Canvas` : dessin en huit couches ; état, animations, gestes (dont le double-clic sur le fond), disposition hors du fil principal | 11 |
| `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `PiecesChoisies.swift`, `CapturesPieces.swift`, `MaillageThread/MaillageThreadApp.swift` | la fenêtre, toujours sombre ; les pièces choisies des routeurs et leur menu ; les captures de démo ; le branchement | 12 |
| `MaillageThread/Vues/Graphe/FicheNoeud.swift` (puis `Vues/Pieces/`) | « Placer dans une pièce… » (12) ; déplacée, le nom des nœuds de la sonde par `LibellesNoeuds` (13) | 12, 13 |
| `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, `Palette.swift`, `CourbesFiche.swift` | déplacés depuis `Vues/Graphe/` ; `FenetreGraphe` retirée | 13 |
| `MaillageThread/Surveillance/Surveillance.swift` | le nom des nœuds de la sonde par `LibellesNoeuds.inconnu` | 13 |
| `Disposition.swift`, `GrapheCanvas.swift`, `PlacementLibelles.swift`, `Projection.swift`, `MesureLibelles.swift`, `DispositionTests.swift`, `PlacementLibellesTests.swift` | supprimés | 13 |
| `MaillageCoeurTests/RapprochementTests.swift`, `MaillageThreadTests/AffichageSondeTests.swift`, `MaillageThreadTests/CourbesFicheTests.swift`, `MaillageThreadTests/GrapheTests.swift` (devenu `FenetreTests.swift`) | sans l'ancienne disposition ; tests repris | 13 |
| `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` | 23 textes nouveaux (10 à 12), 3 retirés (13) | 10 à 13 |
| `README.md`, `README.fr.md`, spec de la vue par pièces | mode d'emploi, mesures, captures, recos du 30/09 ; lien vers ce plan | 14 |

---

### Task 1: Cœur : nœuds et liens d'un réseau, un enfant vu deux fois

**Files:**
- Create: `MaillageCoeur/Scene/GrapheReseau.swift`
- Modify: `MaillageCoeur/Disposition/Disposition.swift` (bloc ci-dessous : `EtatAffiche` et `AppareilAffiche` en sortent)
- Modify: `MaillageCoeur/Maillage/Rapprochement.swift` (bloc ci-dessous : un enfant vu deux fois n'est qu'un nœud)
- Test: `MaillageCoeurTests/GrapheReseauTests.swift`

**Interfaces:**
- Consumes :
  - `Reseau` et `Partition` (`id`, `routeurs`, dont le premier est le centre), `MaillageAffiche` (`partition`, `annoncesCandidates`, `idsRouteurs`, `inconnus`, `liens`), `NoeudSonde`, `BatterieMaison`, `Maillage.enfantsIdentifies` (un enfant par ExtMac : la sonde, puis une table, puis le balayage ; plan 3b), existants ;
  - dans les tests : `Banc`, `Instantane`, `ConstructionMaillage` et les relevés de `RapprochementTests`, existants.
- Produces :
  - `EtatAffiche` et `AppareilAffiche`, inchangés, dans `GrapheReseau.swift` ;
  - `public struct GrapheReseau: Hashable, Sendable` : `init(reseau: Reseau, appareils: [AppareilAffiche], maillage: MaillageAffiche? = nil)`, `noeuds: [Noeud]`, `liens: [Lien]`, `noeud(_ id: String) -> Noeud?`, `parent(de id: String) -> String?` (le parent vu par la sonde) ;
  - `GrapheReseau.Genre` (`centre`, `routeur`, `appareil`) ; `GrapheReseau.Noeud` (`id`, `genre`, `partition`, `routeur`, `bordure`, `inconnu`) ; `GrapheReseau.Lien` (`de`, `vers`, `genre` : `.rattachement`, `.radio` ou `.parent`, `qualite: Int?`) ;
  - `MaillageAffiche(maillage:reseau:appareils:)` : pour un enfant vu deux fois (même ExtMac), seule l'entrée que retient `Maillage.enfantsIdentifies` donne un nœud et un lien (précision 26).

Le graphe actuel (`Disposition`) mêle les nœuds, les liens et leur géométrie en anneaux. La vue par pièces garde les nœuds et les liens, avec les mêmes règles (plan 3a, tâche 7), et laisse la géométrie à la scène. `GrapheReseau` reprend donc ce calcul sans les anneaux : par partition, son centre, ses autres routeurs de bordure (sauf les annonces candidates d'un routeur non identifié), ses appareils, puis les nœuds que seule la sonde connaît ; les liens de la sonde entre nœuds de la partition, et un rattachement supposé au centre pour les nœuds sans lien ; les appareils sans partition connue à la fin, sans lien. `Disposition` reste jusqu'à la tâche 13, qui la retire avec l'ancien graphe ; ses tests de nœuds et de liens sont repris ici, sur les mêmes relevés.

**Un enfant vu deux fois** (précision 26) : quand un enfant passe d'un routeur muet à un routeur qui répond, l'ancienne entrée du balayage reste jusqu'à 30 minutes, en plus de la Child Table ; le rapprochement donnait l'ExtMac à la première entrée, et faisait de la seconde un nœud « rloc:XXXX » inconnu, rattaché à un parent faux ou périmé. Le bloc de `Rapprochement.swift` écarte l'entrée que `Maillage.enfantsIdentifies` ne retient pas, dans le même ordre de priorité. Le test `enfantVuDeuxFois` couvre trois cas ; sans le bloc, il échoue (vérifié le 01/10).

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/GrapheReseauTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : noeuds et liens d'un reseau")
struct GrapheReseauTests {
    static let instantane = Instantane(annonces: Releve20260928.annonces)

    static func affiches(_ i: Instantane) -> [AppareilAffiche] {
        i.appareils.map {
            AppareilAffiche(id: $0.id, nom: $0.id, partition: $0.partition,
                            etat: $0.etat == .sansAdresse ? .sansAdresse : .joignable, endormi: $0.endormi)
        }
    }

    /// Releve du 28/09 sans sonde : le centre (Apple TV), les 4 HomePod, 22 appareils rattaches au
    /// centre ; la partition de l'Aqara, son centre seul ; deux appareils sans partition connue.
    @Test func releveReel() throws {
        let r = try #require(Self.instantane.reseaux.first)
        let g = GrapheReseau(reseau: r, appareils: Self.affiches(Self.instantane))
        let atv = try #require(g.noeud("Apple TV 4K"))
        #expect(atv.genre == .centre && atv.routeur && atv.bordure && atv.partition == "73586B68")
        let homepods = g.noeuds.filter { $0.genre == .routeur }
        #expect(homepods.map(\.id) == ["HomePod Avant", "HomePod Palier", "HomePod mini bureau", "HomePod mini chambre"])
        #expect(homepods.allSatisfy { $0.bordure && !$0.inconnu })
        #expect(g.noeuds.filter { $0.genre == .appareil && $0.partition == "73586B68" }.count == 22)
        #expect(g.noeud("Aqara HubM100 #DFEB")?.genre == .centre)
        #expect(g.noeuds.filter { $0.partition.isEmpty }.map(\.id) == ["1E5019DAC2638F92", "724CC16B32D8F820"])
        #expect(g.liens.count == 26, "4 routeurs et 22 appareils vers l'Apple TV")
        #expect(g.liens.allSatisfy { $0.vers == "Apple TV 4K" && $0.genre == .rattachement })
        #expect(g.parent(de: "56B1E064401F74EF") == nil, "sans sonde : pas de parent connu")
    }

    /// L'ordre d'arrivee des appareils ne compte pas ; un appareil disparu reste un noeud.
    @Test func stable() throws {
        let r = try #require(Self.instantane.reseaux.first)
        let apps = Self.affiches(Self.instantane)
        let g = GrapheReseau(reseau: r, appareils: apps)
        #expect(GrapheReseau(reseau: r, appareils: apps.reversed()) == g)
        var avecDisparu = apps
        let i = try #require(avecDisparu.firstIndex { $0.id == "56B1E064401F74EF" })
        avecDisparu[i].etat = .disparu
        #expect(GrapheReseau(reseau: r, appareils: avecDisparu) == g)
    }

    /// Avec la sonde (capture anonymisee) : routeurs reconnus ou inconnus, appareil qui route, enfant
    /// inconnu ; liens de la sonde, et le rattachement au centre des noeuds qu'elle ne relie pas.
    /// L'annonce du HomePod du salon, candidate des routeurs de bordure non identifies, n'est pas un
    /// noeud a part.
    @Test func avecLaSonde() async throws {
        let i = RapprochementTests.instantane()
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await RapprochementTests.maillage(), reseau: r, appareils: i.appareils)
        let g = GrapheReseau(reseau: r, appareils: RapprochementTests.affiches(i), maillage: m)
        #expect(g.noeud("Apple TV")?.genre == .centre)
        #expect(g.noeud("HomePod salon") == nil, "candidate : portee par les routeurs non identifies")
        #expect(g.noeud("HomePod bureau")?.genre == .routeur)
        let routeurAppareil = try #require(g.noeud("E000000000000002"))
        #expect(routeurAppareil.genre == .appareil && routeurAppareil.routeur && !routeurAppareil.bordure)
        let inconnu = try #require(g.noeud("rloc:0400"))
        #expect(inconnu.genre == .routeur && inconnu.inconnu && inconnu.bordure)
        #expect(g.noeud("rloc:6002")?.genre == .appareil && g.noeud("rloc:6002")?.inconnu == true)
        #expect(g.liens.filter { $0.genre == .radio }.count == 7)
        #expect(g.liens.contains(GrapheReseau.Lien(de: "E000000000000004", vers: "E000000000000002", genre: .parent,
                                                   qualite: 2)))
        #expect(g.parent(de: "E000000000000004") == "E000000000000002")
        #expect(g.liens.contains(GrapheReseau.Lien(de: "rloc:E400", vers: "Apple TV")), "sans lien connu : rattachement")
        #expect(g.liens.contains(GrapheReseau.Lien(de: "Absent", vers: "Apple TV")))
        #expect(!g.liens.contains { $0.de == "E000000000000004" && $0.genre == .rattachement })
    }

    /// Un enfant vu deux fois (il a change de parent ; l'ancienne entree du balayage d'un routeur muet
    /// peut rester 30 minutes) n'est qu'un noeud, pas un « rloc:XXXX » inconnu de plus : il est
    /// rattache par l'entree que retient `Maillage.enfantsIdentifies` (la sonde, puis la table d'un
    /// routeur qui repond, puis le balayage), quel que soit l'ordre des RLOC16.
    @Test(arguments: [
        // (source de l'entree sous le routeur 0 ; source de l'entree sous le routeur 1 ; parent attendu)
        (SourceEnfant.balayage, SourceEnfant.tableEnfants, "rloc:0400"),
        (.tableEnfants, .balayage, "rloc:0000"),
        (.tableEnfants, .sonde, "rloc:0400"),
    ])
    func enfantVuDeuxFois(premiere: SourceEnfant, seconde: SourceEnfant, attendu: String) throws {
        let i = RapprochementTests.instantane()
        let r = try #require(i.reseaux.first)
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.routeurs(Route64(sequence: 1, routes: [RouteRouteur(idRouteur: 0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1),
                                                 RouteRouteur(idRouteur: 1, qualiteSortante: 3, qualiteEntrante: 3, cout: 1)]),
                   chef: 0)
        c.enfant(EnfantMaillage(rloc16: 0x0002, extMac: "E000000000000004", qualite: 3, source: premiere))
        c.enfant(EnfantMaillage(rloc16: 0x0405, extMac: "E000000000000004", qualite: 2, source: seconde))
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        let g = GrapheReseau(reseau: r, appareils: RapprochementTests.affiches(i), maillage: m)
        #expect(!g.noeuds.contains { $0.inconnu && $0.genre == .appareil }, "pas de noeud en double")
        #expect(g.noeud("rloc:0002") == nil && g.noeud("rloc:0405") == nil)
        #expect(g.liens.filter { $0.de == "E000000000000004" }.count == 1)
        #expect(g.parent(de: "E000000000000004") == attendu)
    }

    /// Elimination : le HomePod palier, reconnu par elimination, est un seul noeud.
    @Test func elimination() async throws {
        let i = RapprochementTests.instantane(autres: [("HomePod bureau", "E000000000000007"),
                                                       ("HomePod chambre", "E0000000000000E4"),
                                                       ("HomePod palier", "E0000000000000D2"),
                                                       ("HomePod salon", "E0000000000000CC")])
        let r = try #require(i.reseaux.first)
        let maillage = try await RapprochementTests.maillage(entendus: [0xE400: "E0000000000000E4",
                                                                        0xCC00: "E0000000000000CC"])
        let m = MaillageAffiche(maillage: maillage, reseau: r, appareils: i.appareils)
        let g = GrapheReseau(reseau: r, appareils: RapprochementTests.affiches(i), maillage: m)
        #expect(g.noeuds.filter { $0.id == "HomePod palier" }.count == 1)
        #expect(!g.noeuds.contains { $0.inconnu && $0.genre == .routeur })
    }

    /// Deux routeurs de bordure non identifies, deux annonces candidates : elles ne sont pas des
    /// noeuds ; sans sonde, rien ne change, les annonces sont des noeuds.
    @Test func candidats() async throws {
        let i = RapprochementTests.instantane(autres: [("HomePod bureau", "E000000000000007"),
                                                       ("HomePod chambre", "E0000000000000E4"),
                                                       ("HomePod avant", "E0000000000000D1"),
                                                       ("HomePod palier", "E0000000000000D2")])
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await RapprochementTests.maillage(entendus: [0xE400: "E0000000000000E4"]),
                                reseau: r, appareils: i.appareils)
        let g = GrapheReseau(reseau: r, appareils: RapprochementTests.affiches(i), maillage: m)
        #expect(g.noeud("HomePod avant") == nil && g.noeud("HomePod palier") == nil)
        #expect(g.noeud("rloc:0400") != nil && g.noeud("rloc:CC00") != nil)
        let sans = GrapheReseau(reseau: r, appareils: RapprochementTests.affiches(i))
        #expect(sans.noeud("HomePod avant") != nil && sans.noeud("HomePod palier") != nil)
    }

    /// Reseau scinde : seules les annonces candidates de la partition de la sonde ne sont pas des
    /// noeuds ; l'autre partition garde les siennes.
    @Test func autrePartition() async throws {
        let i = RapprochementTests.instantane(ailleurs: [("Aqara", "E0000000000000AA"), ("HomePod isole", "E0000000000000A9")])
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await RapprochementTests.maillage(), reseau: r, appareils: i.appareils)
        let g = GrapheReseau(reseau: r, appareils: RapprochementTests.affiches(i), maillage: m)
        #expect(g.noeud("HomePod salon") == nil)
        #expect(g.noeud("Aqara")?.partition == "73586B68" && g.noeud("HomePod isole")?.partition == "73586B68")
        #expect(g.noeud("Aqara")?.genre == .centre)
    }

    /// Le centre peut etre candidat : il reste un noeud, au centre ; l'autre annonce candidate, non.
    @Test func centreCandidat() throws {
        var b = Banc()
        b.routeur("Alpha", partition: "46CBEBCD", role: nil, lien: "fe80::1", xa: "E0000000000000C1")
        b.routeur("HomePod avant", partition: "46CBEBCD", role: nil, lien: "fe80::2", xa: "E0000000000000D1")
        let i = Instantane(annonces: b.annonces)
        let r = try #require(i.reseaux.first)
        let m = try RapprochementTests.deuxRouteurs(i)
        let g = GrapheReseau(reseau: r, appareils: [], maillage: m)
        #expect(g.noeud("Alpha")?.genre == .centre)
        #expect(g.noeud("HomePod avant") == nil)
        #expect(g.noeuds.map(\.id) == ["Alpha", "rloc:0400", "rloc:0800"])
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/GrapheReseauTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find 'GrapheReseau' in scope`.

- [ ] **Step 3 : écrire le code.** `GrapheReseau.swift` reprend `EtatAffiche` et `AppareilAffiche`, que `Disposition.swift` perd (même module : rien d'autre ne change) ; le bloc de `Rapprochement.swift` écarte l'entrée d'un enfant vu deux fois que `Maillage.enfantsIdentifies` ne retient pas.

`MaillageCoeur/Scene/GrapheReseau.swift` (fichier entier) :

```swift
import Foundation

/// Etat d'un appareil tel que la vue le montre.
public enum EtatAffiche: String, Hashable, Sendable {
    case joignable, partitionCoupee, sansAdresse, disparu, inconnu
}

/// Appareil a dessiner : nom deja choisi, partition courante ou derniere connue.
public struct AppareilAffiche: Hashable, Sendable, Identifiable {
    public var id: String
    public var nom: String
    public var piece: String?
    public var partition: String?
    public var etat: EtatAffiche
    public var endormi: Bool
    /// Batterie selon Maison, pour un appareil qui en a une.
    public var batterie: BatterieMaison?

    public init(id: String, nom: String, piece: String? = nil, partition: String?, etat: EtatAffiche,
                endormi: Bool = false, batterie: BatterieMaison? = nil) {
        self.id = id
        self.nom = nom
        self.piece = piece
        self.partition = partition
        self.etat = etat
        self.endormi = endormi
        self.batterie = batterie
    }
}

/// Noeuds et liens d'un reseau, tels que la vue les montre, sans geometrie (spec de la vue par
/// pieces, section 2.3). Par partition : son centre (chef, sinon BBR primaire), ses autres routeurs
/// de bordure, ses appareils. Avec la sonde, dans sa partition : les routeurs et les enfants
/// qu'elle seule connait, et ses liens (radio entre routeurs, enfant vers parent) ; un noeud sans
/// lien connu est rattache au centre de sa partition (rattachement suppose, pas un lien radio).
/// Les appareils sans partition connue n'ont pas de lien.
///
/// Un seul noeud par routeur : l'annonce candidate d'un routeur de bordure non identifie n'est
/// pas un noeud a part, ce routeur la porte (`MaillageAffiche.annoncesCandidates`) ; le centre
/// reste le centre, candidat ou non. Ordre des noeuds : partition par partition, le centre, les
/// autres routeurs de bordure (ordre de la partition), les appareils par identifiant, puis les
/// inconnus de la sonde (routeurs, enfants, par RLOC16) ; les appareils sans partition a la fin.
public struct GrapheReseau: Hashable, Sendable {
    public enum Genre: String, Hashable, Sendable {
        /// Centre d'une partition : son premier routeur de bordure (chef, sinon BBR primaire).
        case centre
        /// Autre routeur de bordure, ou routeur que seule la sonde connait.
        case routeur
        /// Appareil (Matter, HomeKit), ou enfant que seule la sonde connait.
        case appareil
    }

    public struct Noeud: Hashable, Sendable, Identifiable {
        public var id: String
        public var genre: Genre
        /// Partition ; "" : sans partition connue.
        public var partition: String
        /// Route : routeur de bordure, routeur de la sonde, appareil qui route.
        public var routeur: Bool
        /// Routeur de bordure : annonce, ou routeur de bordure que seule la sonde connait.
        public var bordure: Bool
        /// Connu de la sonde seule ("rloc:...").
        public var inconnu: Bool

        public init(id: String, genre: Genre, partition: String, routeur: Bool, bordure: Bool, inconnu: Bool) {
            self.id = id
            self.genre = genre
            self.partition = partition
            self.routeur = routeur
            self.bordure = bordure
            self.inconnu = inconnu
        }
    }

    public struct Lien: Hashable, Sendable {
        public enum Genre: String, Hashable, Sendable {
            /// Vers le centre de la partition : rattachement suppose, pas un lien radio.
            case rattachement
            /// Lien radio entre deux routeurs, vu par la sonde.
            case radio
            /// De l'enfant vers son parent, vu par la sonde.
            case parent
        }

        public var de: String
        public var vers: String
        public var genre: Genre
        /// De 0 a 3 ; nil : inconnue.
        public var qualite: Int?

        public init(de: String, vers: String, genre: Genre = .rattachement, qualite: Int? = nil) {
            self.de = de
            self.vers = vers
            self.genre = genre
            self.qualite = qualite
        }
    }

    public private(set) var noeuds: [Noeud] = []
    public private(set) var liens: [Lien] = []

    public init(reseau: Reseau, appareils: [AppareilAffiche], maillage: MaillageAffiche? = nil) {
        let connues = Set(reseau.partitions.map(\.id))
        let parPartition = Dictionary(grouping: appareils) { a in
            a.partition.flatMap { connues.contains($0) ? $0 : nil } ?? ""
        }
        func tries(_ l: [AppareilAffiche]) -> [AppareilAffiche] { l.sorted { $0.id < $1.id } }
        for p in reseau.partitions {
            guard let centre = p.routeurs.first else { continue }
            let sonde = maillage.flatMap { $0.partition == p.id ? $0 : nil }
            var ids: [String] = []
            func ajouter(_ n: Noeud) {
                noeuds.append(n)
                ids.append(n.id)
            }
            ajouter(Noeud(id: centre.instance, genre: .centre, partition: p.id, routeur: true, bordure: true,
                          inconnu: false))
            for r in p.routeurs.dropFirst() where sonde?.annoncesCandidates.contains(r.instance) != true {
                ajouter(Noeud(id: r.instance, genre: .routeur, partition: p.id, routeur: true, bordure: true,
                              inconnu: false))
            }
            let routeursSonde = sonde?.idsRouteurs ?? []
            for a in tries(parPartition[p.id] ?? []) {
                ajouter(Noeud(id: a.id, genre: .appareil, partition: p.id, routeur: routeursSonde.contains(a.id),
                              bordure: false, inconnu: false))
            }
            for n in sonde?.inconnus ?? [] {
                ajouter(Noeud(id: n.id, genre: n.genre == .routeur ? .routeur : .appareil, partition: p.id,
                              routeur: n.genre == .routeur, bordure: n.bordure, inconnu: true))
            }
            // Liens de la sonde entre noeuds de la partition ; le rattachement au centre pour les autres.
            let presents = Set(ids)
            var relies: Set<String> = [centre.instance]
            for l in sonde?.liens ?? [] where presents.contains(l.de) && presents.contains(l.vers) {
                liens.append(Lien(de: l.de, vers: l.vers, genre: l.genre == .radio ? .radio : .parent,
                                  qualite: l.qualite))
                relies.insert(l.de)
                relies.insert(l.vers)
            }
            for id in ids where !relies.contains(id) {
                liens.append(Lien(de: id, vers: centre.instance))
            }
        }
        for a in tries(parPartition[""] ?? []) {
            noeuds.append(Noeud(id: a.id, genre: .appareil, partition: "", routeur: false, bordure: false,
                                inconnu: false))
        }
    }

    public func noeud(_ id: String) -> Noeud? { noeuds.first { $0.id == id } }

    /// Parent d'un noeud vu par la sonde (lien enfant-parent) ; nil sinon.
    public func parent(de id: String) -> String? {
        liens.first { $0.genre == .parent && $0.de == id }?.vers
    }
}
```

Dans `MaillageCoeur/Disposition/Disposition.swift`, remplacer :

```swift
/// Etat d'un appareil tel que le graphe le montre.
public enum EtatAffiche: String, Hashable, Sendable {
    case joignable, partitionCoupee, sansAdresse, disparu, inconnu
}

/// Appareil a dessiner : nom deja choisi, partition courante ou derniere connue.
public struct AppareilAffiche: Hashable, Sendable, Identifiable {
    public var id: String
    public var nom: String
    public var piece: String?
    public var partition: String?
    public var etat: EtatAffiche
    public var endormi: Bool
    /// Batterie selon Maison, pour un appareil qui en a une.
    public var batterie: BatterieMaison?

    public init(id: String, nom: String, piece: String? = nil, partition: String?, etat: EtatAffiche,
                endormi: Bool = false, batterie: BatterieMaison? = nil) {
        self.id = id
        self.nom = nom
        self.piece = piece
        self.partition = partition
        self.etat = etat
        self.endormi = endormi
        self.batterie = batterie
    }
}

/// Disposition stable du graphe d'un reseau
```

par :

```swift
/// Disposition stable du graphe d'un reseau
```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
        var enfants: [UInt16: NoeudSonde] = [:]
        for e in maillage.enfants {
            var id = e.extMac.flatMap { parId[$0]?.id }
```

par :

```swift
        // Un enfant vu deux fois (il a change de parent, et l'ancienne entree du balayage d'un routeur
        // muet peut rester 30 minutes) n'est qu'un noeud : l'entree que retient
        // `Maillage.enfantsIdentifies` (la sonde, puis une table, puis le balayage) ; l'autre est
        // ecartee, sans noeud ni lien.
        let retenus = maillage.enfantsIdentifies
        var enfants: [UInt16: NoeudSonde] = [:]
        for e in maillage.enfants {
            if let x = e.extMac, retenus[x] != e { continue }
            var id = e.extMac.flatMap { parId[$0]?.id }
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/GrapheReseauTests`
Expected: `Test run with 8 tests in 1 suite passed` (`GrapheReseauTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 285 tests in 27 suites passed` (cœur) et `Test run with 247 tests in 27 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 8 tests et 1 suite de plus pour le cœur, l'app inchangée.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Disposition/Disposition.swift MaillageCoeur/Maillage/Rapprochement.swift MaillageCoeur/Scene/GrapheReseau.swift MaillageCoeurTests/GrapheReseauTests.swift
git commit -m "Tenir les noeuds et les liens d'un reseau pour la vue par pieces, sans enfant en double

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Cœur : la scène (étages, pièces, nœuds)

**Files:**
- Create: `MaillageCoeur/Scene/ScenePieces.swift`
- Test: `MaillageCoeurTests/ScenePiecesTests.swift`

**Interfaces:**
- Consumes :
  - `GrapheReseau` (tâche 1) ; `ZoneMaison` et `NomsMaison.zones` (plan 4a, existants).
- Produces :
  - `public struct ScenePieces: Hashable, Sendable` : `init(graphe: GrapheReseau, libelles: [String: String], piecesNoeuds: [String: String], zones: [ZoneMaison]?, chefs: Set<String>, piecesMaison: Bool, ordreEtages: [String] = [])` ; `etages: [Etage]`, `pieces: [Piece]`, `noeuds: [Noeud]`, `liens: [Lien]` (`Lien` = `GrapheReseau.Lien`), `sansPiecesMaison: Bool` ; `noeud(_ id: String) -> Noeud?`, `indice(_ id: String) -> Int?` ;
  - `static let teintes: [UInt32]` (les 8 de la spec), `static let nomSansPiece = "Sans pièce"`, `static func fnv1a(_ nom: String) -> UInt32` ;
  - `NomEtage` : `.zone(String)`, `.autresPieces`, `.maison`, et sa `cle` : `"zone:<nom>"`, `"autres-pieces"`, `"maison"` ;
  - `NomPiece` : `.maison(String)`, `.routeur(String)` (la carte d'un routeur, sans pièces de Maison), `.sansPiece`, et sa `cle` : `"piece:<nom>"`, `"routeur:<id>"`, `"sans-piece"` ;
  - `Etage` (`nom`, `pieces: [Int]`, `id` = la clé), `Piece` (`nom`, `etage`, `teinte` de 0 à 7, `noeuds: [String]` dans l'ordre des lignes, `id` = la clé), `Noeud` (`id`, `libelle`, `genre`, `partition`, `routeur`, `bordure`, `inconnu`, `chef`, `rang` de 0 à 3, `rayon` en px, `piece`) ;
  - dans les tests : `ScenePiecesTests.graphe(sonde:)` et `ScenePiecesTests.libelles`, que les tests des tâches 3, 5, 7 et 8 reprennent.

Les règles de la section 2 de la spec :
- **étages :** les zones de Maison, dans leur ordre, le premier en bas ; une pièce de plusieurs zones va dans la première ; une zone sans pièce montrée n'est pas un étage ; les pièces hors zone forment « Autres pièces » ; sans zones (ou fichier d'avant les zones), un seul étage, « Maison » ; l'ordre gardé (`ordreEtages`, clés du bas vers le haut) passe d'abord, les étages qu'il ne connaît pas gardant l'ordre de Maison ;
- **pièces :** celles qui ont au moins un nœud ; la carte « Sans pièce » va sur l'étage du bas ; sans aucune pièce de Maison (`piecesMaison` faux), une carte par routeur parent, qui porte son nom, et les nœuds sans parent connu dans « Sans pièce » ;
- **teintes :** dans chaque étage, pièces rangées par nom ; FNV-1a sur 32 bits du nom en UTF-8, modulo 8 ; la suivante libre si elle est prise ;
- **lignes d'une carte :** le chef (rang 0), les routeurs de bordure (1), les autres routeurs (2), les autres nœuds (3), puis par libellé et par identifiant ; rayons de 15 px (le centre), 13 (routeur de bordure), 8 (autre routeur), 7.

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/ScenePiecesTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : etages, pieces et noeuds")
struct ScenePiecesTests {
    static let partition = "46CBEBCD"

    /// Petit reseau : l'Apple TV (chef, BBR primaire) et le HomePod, routeurs de bordure ; quatre
    /// appareils. Avec la sonde : le routeur 3 est l'appareil E...04 (un appareil qui route), E...02
    /// est l'enfant de l'Apple TV, E...03 celui du HomePod ; E...05 n'a pas de parent connu.
    static func graphe(sonde: Bool) throws -> GrapheReseau {
        var b = Banc()
        let omr = "fd00:5555:6666::/64"
        b.routeur("Apple TV", partition: partition, role: .chef, primaire: true, lien: "fe80::1", omr: omr,
                  xa: "E0000000000000A1")
        b.routeur("HomePod", partition: partition, lien: "fe80::2", omr: omr, xa: "E0000000000000A2")
        for k in 2...5 {
            b.appareil(String(format: "E00000000000000%d", k), noeud: k, adresses: ["fd00:5555:6666:0:b00::\(k)"])
        }
        let i = Instantane(annonces: b.annonces)
        let r = try #require(i.reseaux.first)
        let apps = i.appareils.map { AppareilAffiche(id: $0.id, nom: $0.id, partition: $0.partition, etat: .joignable) }
        guard sonde else { return GrapheReseau(reseau: r, appareils: apps) }
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: partition)
        c.routeurs(Route64(sequence: 0, routes: (1...3).map {
            RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1)
        }), chef: 1)
        c.identite("E0000000000000A1", routeur: 1)
        c.identite("E0000000000000A2", routeur: 2)
        c.identite("E000000000000004", routeur: 3)
        c.marquer(1, bordure: true, bbrPrincipal: true)
        c.marquer(2, bordure: true)
        c.lien(1, 2, sortante: 3, entrante: 2)
        c.lien(1, 3, sortante: 2, entrante: 2)
        c.enfant(EnfantMaillage(rloc16: 0x0401, extMac: "E000000000000002", qualite: 3, source: .tableEnfants))
        c.enfant(EnfantMaillage(rloc16: 0x0801, extMac: "E000000000000003", qualite: 2, source: .tableEnfants))
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        return GrapheReseau(reseau: r, appareils: apps, maillage: m)
    }

    static let libelles = ["Apple TV": "Apple TV 👑", "HomePod": "HomePod", "E000000000000002": "Lampe salon",
                           "E000000000000003": "Capteur", "E000000000000004": "Prise", "E000000000000005": "Bouton"]

    static func noms(_ s: ScenePieces, etage e: Int) -> [ScenePieces.NomPiece] {
        s.etages[e].pieces.map { s.pieces[$0].nom }
    }

    static func piece(_ s: ScenePieces, _ nom: ScenePieces.NomPiece) throws -> ScenePieces.Piece {
        try #require(s.pieces.first { $0.nom == nom })
    }

    /// Zones : une piece dans deux zones va dans la premiere ; une zone sans piece montree n'est pas un
    /// etage ; les pieces hors zone forment « Autres pieces » ; une piece sans noeud n'est pas montree.
    @Test func zones() throws {
        let g = try Self.graphe(sonde: false)
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre", "E000000000000002": "Bureau",
                      "E000000000000003": "Garage", "E000000000000004": "Salon", "E000000000000005": "Chambre"]
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Chambre"]),
                     ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau"]),
                     ZoneMaison(nom: "Grenier", pieces: ["Débarras"])]
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                            piecesMaison: true)
        #expect(s.etages.map(\.nom) == [.zone("Rez-de-chaussée"), .zone("Étage"), .autresPieces])
        #expect(Self.noms(s, etage: 0) == [.maison("Chambre"), .maison("Salon")], "Chambre : la premiere zone")
        #expect(Self.noms(s, etage: 1) == [.maison("Bureau")])
        #expect(Self.noms(s, etage: 2) == [.maison("Garage")])
        #expect(!s.pieces.contains { $0.nom == .maison("Cuisine") || $0.nom == .maison("Débarras") })
        #expect(try Self.piece(s, .maison("Salon")).noeuds == ["Apple TV", "E000000000000004"])
        #expect(s.etages.map(\.id) == ["zone:Rez-de-chaussée", "zone:Étage", "autres-pieces"])
        #expect(!s.sansPiecesMaison)
    }

    /// Maison sans zones, ou fichier d'avant les zones (le champ manque : nil) : un seul plateau.
    @Test func sansZones() throws {
        let g = try Self.graphe(sonde: false)
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre"]
        for zones in [nil, []] as [[ZoneMaison]?] {
            let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                                piecesMaison: true)
            #expect(s.etages.map(\.nom) == [.maison])
            #expect(Self.noms(s, etage: 0) == [.maison("Chambre"), .maison("Salon"), .sansPiece])
        }
        let ancien = """
        {"version": 1, "date": "2026-09-28T10:00:00Z", "statut": "ok", "accessoires": [{"nom": "Lampe", "piece": "Salon"}]}
        """
        let n = try NomsMaison.lire(Data(ancien.utf8))
        #expect(n.zones == nil)
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: n.zones, chefs: [],
                            piecesMaison: true)
        #expect(s.etages.map(\.nom) == [.maison])
    }

    /// « Sans piece » : les noeuds que Maison ne place pas, sur le plateau du bas, celui de l'ordre
    /// garde s'il y en a un ; une cle inconnue de l'ordre garde est ignoree.
    @Test func sansPieceSurLePlateauDuBas() throws {
        let g = try Self.graphe(sonde: false)
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre"]
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre"])]
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                            piecesMaison: true)
        #expect(Self.noms(s, etage: 0) == [.maison("Salon"), .sansPiece])
        #expect(try Self.piece(s, .sansPiece).noeuds == ["E000000000000005", "E000000000000003", "E000000000000002",
                                                          "E000000000000004"], "par libelle")
        let inverse = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                                  piecesMaison: true, ordreEtages: ["zone:Étage", "inconnu", "zone:Rez-de-chaussée"])
        #expect(inverse.etages.map(\.nom) == [.zone("Étage"), .zone("Rez-de-chaussée")])
        #expect(Self.noms(inverse, etage: 0) == [.maison("Chambre"), .sansPiece])
        #expect(try Self.piece(inverse, .sansPiece).etage == 0)
    }

    /// Pas encore de pieces de Maison : un plateau « Maison », une carte par routeur avec ses enfants
    /// (vus par la sonde) ; sans parent connu, « Sans piece ». Sans sonde, aucun parent : chaque
    /// routeur seul dans sa carte.
    @Test func groupementParRouteur() throws {
        let s = ScenePieces(graphe: try Self.graphe(sonde: true), libelles: Self.libelles, piecesNoeuds: [:], zones: nil,
                            chefs: [], piecesMaison: false)
        #expect(s.sansPiecesMaison)
        #expect(s.etages.map(\.nom) == [.maison])
        #expect(try Self.piece(s, .routeur("Apple TV")).noeuds == ["Apple TV", "E000000000000002"])
        #expect(try Self.piece(s, .routeur("HomePod")).noeuds == ["HomePod", "E000000000000003"])
        #expect(try Self.piece(s, .routeur("E000000000000004")).noeuds == ["E000000000000004"], "appareil qui route")
        #expect(try Self.piece(s, .sansPiece).noeuds == ["E000000000000005"])
        let sans = ScenePieces(graphe: try Self.graphe(sonde: false), libelles: Self.libelles, piecesNoeuds: [:],
                               zones: nil, chefs: [], piecesMaison: false)
        #expect(try Self.piece(sans, .routeur("Apple TV")).noeuds == ["Apple TV"])
        #expect(try Self.piece(sans, .sansPiece).noeuds.count == 4)
    }

    /// Lignes d'une carte : le chef, les routeurs de bordure, les autres routeurs, puis les autres
    /// noeuds, par libelle ; rayons 15 (centre), 13, 8 et 7.
    @Test func lignesEtRayons() throws {
        let g = try Self.graphe(sonde: true)
        let tous = Dictionary(uniqueKeysWithValues: g.noeuds.map { ($0.id, "Salon") })
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: tous, zones: nil, chefs: ["HomePod"],
                            piecesMaison: true)
        #expect(try Self.piece(s, .maison("Salon")).noeuds
                == ["HomePod", "Apple TV", "E000000000000004", "E000000000000005", "E000000000000003", "E000000000000002"])
        #expect(s.noeud("HomePod")?.rang == 0 && s.noeud("HomePod")?.rayon == 13)
        #expect(s.noeud("Apple TV")?.rang == 1 && s.noeud("Apple TV")?.rayon == 15)
        #expect(s.noeud("E000000000000004")?.rang == 2 && s.noeud("E000000000000004")?.rayon == 8)
        #expect(s.noeud("E000000000000002")?.rang == 3 && s.noeud("E000000000000002")?.rayon == 7)
        #expect(s.noeud("E000000000000002")?.libelle == "Lampe salon")
        #expect(s.liens == g.liens)
    }

    /// Teintes : FNV-1a 32 bits du nom, modulo 8 ; dans un etage, la suivante libre si elle est prise
    /// (Chambre, Salle de bain et Cellier donnent 3) ; d'un etage a l'autre, pas de conflit.
    @Test func teintes() throws {
        #expect(ScenePieces.fnv1a("") == 0x811C_9DC5)
        #expect(ScenePieces.fnv1a("a") == 0xE40C_292C)
        #expect(ScenePieces.fnv1a("foobar") == 0xBF9C_F968)
        let g = try Self.graphe(sonde: false)
        let pieces = ["Apple TV": "Salle de bain", "HomePod": "Chambre", "E000000000000002": "Cellier",
                      "E000000000000003": "Salon", "E000000000000004": "Chambre", "E000000000000005": "Salon"]
        let zones = [ZoneMaison(nom: "Étage", pieces: ["Salle de bain", "Chambre", "Cellier"]),
                     ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"])]
        let s = ScenePieces(graphe: g, libelles: Self.libelles, piecesNoeuds: pieces, zones: zones, chefs: [],
                            piecesMaison: true)
        #expect(try Self.piece(s, .maison("Cellier")).teinte == 3, "premier par nom")
        #expect(try Self.piece(s, .maison("Chambre")).teinte == 4)
        #expect(try Self.piece(s, .maison("Salle de bain")).teinte == 5)
        #expect(try Self.piece(s, .maison("Salon")).teinte == 2)
        #expect(ScenePieces.teintes.count == 8 && ScenePieces.teintes[0] == 0x3B82F5)
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/ScenePiecesTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find type 'ScenePieces' in scope` et `error: cannot find 'ScenePieces' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Scene/ScenePieces.swift` (fichier entier) :

```swift
import Foundation

/// Scene de la vue par pieces, sans geometrie (spec de la vue par pieces, section 2) : les
/// etages, les pieces qui ont au moins un noeud, les noeuds et les liens.
///
/// - Etages : les zones de Maison, dans leur ordre (le premier en bas) ; une piece dans plusieurs
///   zones va dans la premiere ; les pieces hors zone forment « Autres pieces ». Sans zones (ou
///   fichier d'avant les zones), un seul plateau « Maison ». Un ordre garde passe avant.
/// - Pieces : celles de Maison (le champ `piece` de l'accessoire du noeud) ; un noeud sans piece va
///   dans « Sans piece », sur le plateau du bas. Sans aucune piece dans Maison, un seul plateau
///   « Maison » et une carte par routeur, avec ses enfants (parents vus par la sonde).
/// - Teinte d'une piece : dans chaque etage, les pieces rangees par nom prennent chacune la teinte
///   d'indice FNV-1a 32 bits de leur nom, modulo 8, ou la suivante libre dans l'etage.
/// - Noeuds d'une carte : le chef, les routeurs de bordure, les autres routeurs, les autres
///   noeuds ; par libelle dans chaque groupe. Rayon naturel : 15 px pour le centre d'une
///   partition, 13 pour un autre routeur de bordure, 8 pour un autre routeur, 7 sinon.
public struct ScenePieces: Hashable, Sendable {
    public enum NomEtage: Hashable, Sendable {
        /// Zone de Maison.
        case zone(String)
        /// Pieces hors de toute zone.
        case autresPieces
        /// Plateau unique : maison sans zones, ou sans pieces.
        case maison

        /// Cle de l'etage (ordre garde, places gardees).
        public var cle: String {
            switch self {
            case .zone(let n): "zone:" + n
            case .autresPieces: "autres-pieces"
            case .maison: "maison"
            }
        }
    }

    public enum NomPiece: Hashable, Sendable {
        /// Piece de Maison.
        case maison(String)
        /// Carte d'un routeur et de ses enfants (maison sans pieces), par l'id du routeur.
        case routeur(String)
        /// Noeuds sans piece.
        case sansPiece

        /// Cle de la piece (places gardees).
        public var cle: String {
            switch self {
            case .maison(let n): "piece:" + n
            case .routeur(let id): "routeur:" + id
            case .sansPiece: "sans-piece"
            }
        }
    }

    public struct Etage: Hashable, Sendable, Identifiable {
        public var nom: NomEtage
        /// Indices de ses pieces, par nom.
        public var pieces: [Int]

        public var id: String { nom.cle }
    }

    public struct Piece: Hashable, Sendable, Identifiable {
        public var nom: NomPiece
        public var etage: Int
        /// Indice de sa teinte dans `ScenePieces.teintes`.
        public var teinte: Int
        /// Ses noeuds, dans l'ordre des lignes de sa carte.
        public var noeuds: [String]

        public var id: String { nom.cle }
    }

    public struct Noeud: Hashable, Sendable, Identifiable {
        public var id: String
        /// Nom affiche, avec la couronne, la lune et l'alerte ; deja coupe (`CartesPieces.couper`).
        public var libelle: String
        public var genre: GrapheReseau.Genre
        public var partition: String
        public var routeur: Bool
        public var bordure: Bool
        public var inconnu: Bool
        public var chef: Bool
        /// Rang dans sa carte : 0 chef, 1 routeur de bordure, 2 autre routeur, 3 autre noeud.
        public var rang: Int
        /// Rayon naturel de sa pastille (px).
        public var rayon: Double
        public var piece: Int
    }

    public typealias Lien = GrapheReseau.Lien

    /// Palette des pieces : 8 teintes (spec, section 2.2).
    public static let teintes: [UInt32] = [0x3B82F5, 0x22C55E, 0xF59E0B, 0x94A3B8, 0xA855F7, 0x06B6D4, 0xEC4899, 0x818CF8]
    /// Nom de la carte « Sans piece » pour le rang et la teinte : le meme dans toutes les langues.
    public static let nomSansPiece = "Sans pièce"

    public private(set) var etages: [Etage] = []
    public private(set) var pieces: [Piece] = []
    public private(set) var noeuds: [Noeud] = []
    public private(set) var liens: [Lien] = []
    /// Maison n'a encore aucune piece : cartes par routeur, et le bandeau du passeur.
    public private(set) var sansPiecesMaison: Bool
    private var indices: [String: Int] = [:]

    /// `libelles` : nom affiche de chaque noeud (son id a defaut) ; `piecesNoeuds` : piece de Maison
    /// de chaque noeud qui en a une ; `zones` : celles de Maison (nil : fichier d'avant les zones) ;
    /// `chefs` : noeuds couronnes ; `piecesMaison` : Maison a au moins une piece ; `ordreEtages` :
    /// cles des etages dans l'ordre garde, du bas vers le haut.
    public init(graphe: GrapheReseau, libelles: [String: String], piecesNoeuds: [String: String],
                zones: [ZoneMaison]?, chefs: Set<String>, piecesMaison: Bool, ordreEtages: [String] = []) {
        sansPiecesMaison = !piecesMaison
        func libelle(_ id: String) -> String { libelles[id] ?? id }
        // Piece de chaque noeud.
        var nomPiece: [String: NomPiece] = [:]
        for n in graphe.noeuds {
            if piecesMaison {
                if let p = piecesNoeuds[n.id], !p.isEmpty {
                    nomPiece[n.id] = .maison(p)
                } else {
                    nomPiece[n.id] = .sansPiece
                }
            } else if n.routeur {
                nomPiece[n.id] = .routeur(n.id)
            } else if let p = graphe.parent(de: n.id), graphe.noeud(p)?.routeur == true {
                nomPiece[n.id] = .routeur(p)
            } else {
                nomPiece[n.id] = .sansPiece
            }
        }
        // Etages : les zones qui ont une piece montree, puis « Autres pieces » ; sinon « Maison ».
        let montrees = Set(nomPiece.values.compactMap { p -> String? in
            if case .maison(let n) = p { return n }
            return nil
        })
        var noms: [NomEtage] = []
        var etageDe: [String: Int] = [:]
        if piecesMaison, let zones, !zones.isEmpty {
            var restantes = montrees
            for z in zones {
                let dedans = z.pieces.filter { restantes.contains($0) }
                guard !dedans.isEmpty else { continue }
                for p in dedans {
                    etageDe[p] = noms.count
                    restantes.remove(p)
                }
                noms.append(.zone(z.nom))
            }
            if !restantes.isEmpty {
                for p in restantes { etageDe[p] = noms.count }
                noms.append(.autresPieces)
            }
        }
        if noms.isEmpty { noms = [.maison] }
        // Ordre garde d'abord ; un etage qu'il ne connait pas garde son rang, au-dessus.
        let rang = Dictionary(ordreEtages.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let ordre = noms.indices.sorted {
            (rang[noms[$0].cle] ?? Int.max, $0) < (rang[noms[$1].cle] ?? Int.max, $1)
        }
        let nouveau = Dictionary(uniqueKeysWithValues: ordre.enumerated().map { ($1, $0) })
        etages = ordre.map { Etage(nom: noms[$0], pieces: []) }
        func etage(_ p: NomPiece) -> Int {
            if case .maison(let n) = p, let e = etageDe[n] { return nouveau[e] ?? 0 }
            return 0
        }
        func nomTri(_ p: NomPiece) -> String {
            switch p {
            case .maison(let n): n
            case .routeur(let id): libelle(id)
            case .sansPiece: Self.nomSansPiece
            }
        }
        // Pieces, etage par etage, par nom ; teintes.
        let distinctes = Set(nomPiece.values)
        for e in etages.indices {
            let ici = distinctes.filter { etage($0) == e }.sorted { (nomTri($0), $0.cle) < (nomTri($1), $1.cle) }
            var prises = Set<Int>()
            for p in ici {
                var t = Int(Self.fnv1a(nomTri(p)) % 8)
                if prises.count < 8 {
                    while prises.contains(t) { t = (t + 1) % 8 }
                }
                prises.insert(t)
                etages[e].pieces.append(pieces.count)
                pieces.append(Piece(nom: p, etage: e, teinte: t, noeuds: []))
            }
        }
        let indicePiece = Dictionary(uniqueKeysWithValues: pieces.enumerated().map { ($1.nom, $0) })
        // Noeuds, puis les lignes de chaque carte.
        for n in graphe.noeuds {
            guard let p = nomPiece[n.id].flatMap({ indicePiece[$0] }) else { continue }
            let chef = chefs.contains(n.id)
            let rang = chef ? 0 : n.bordure ? 1 : n.routeur ? 2 : 3
            let rayon: Double = n.genre == .centre ? 15 : n.bordure ? 13 : n.routeur ? 8 : 7
            indices[n.id] = noeuds.count
            noeuds.append(Noeud(id: n.id, libelle: libelle(n.id), genre: n.genre, partition: n.partition,
                                routeur: n.routeur, bordure: n.bordure, inconnu: n.inconnu, chef: chef, rang: rang,
                                rayon: rayon, piece: p))
        }
        for i in pieces.indices {
            pieces[i].noeuds = noeuds.filter { $0.piece == i }
                .sorted { ($0.rang, $0.libelle, $0.id) < ($1.rang, $1.libelle, $1.id) }
                .map(\.id)
        }
        liens = graphe.liens
    }

    public func noeud(_ id: String) -> Noeud? { indices[id].map { noeuds[$0] } }

    /// Indice d'un noeud dans `noeuds`.
    public func indice(_ id: String) -> Int? { indices[id] }

    /// FNV-1a sur 32 bits, du nom en UTF-8.
    public static func fnv1a(_ nom: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for b in nom.utf8 {
            h ^= UInt32(b)
            h = h &* 16_777_619
        }
        return h
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/ScenePiecesTests`
Expected: `Test run with 6 tests in 1 suite passed` (`ScenePiecesTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 291 tests in 28 suites passed` (cœur) et `Test run with 247 tests in 27 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 6 tests et 1 suite de plus pour le cœur, l'app inchangée.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Scene/ScenePieces.swift MaillageCoeurTests/ScenePiecesTests.swift
git commit -m "Construire la scene de la vue par pieces : etages, pieces, noeuds

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Cœur : les cartes des pièces

**Files:**
- Create: `MaillageCoeur/Scene/CartesPieces.swift`
- Test: `MaillageCoeurTests/CartesPiecesTests.swift`

**Interfaces:**
- Consumes :
  - `ScenePieces` (tâche 2) ; dans les tests, `ScenePiecesTests.graphe(sonde:)` et `ScenePiecesTests.libelles`.
- Produces :
  - `public enum CartesPieces` : `static let px = 24.0`, `static let longueurMax = 40` ; `static func couper(_ nom: String) -> String` (39 caractères et « … » au-delà de 40) ; `static func hauteurLigne(_ rayon: Double) -> Double` ; `static func carte(_ lignes: [Ligne]) -> Carte` ; `static func cartes(_ scene: ScenePieces, largeurs: [String: Double]) -> [Carte]` (une par pièce, dans l'ordre de `scene.pieces`) ;
  - `CartesPieces.Ligne` (`rayon`, `largeurNom`, en px, `init(rayon:largeurNom:)`) ; `CartesPieces.Carte` (`largeur` et `profondeur` en unités, `colonnes`, `places: [SIMD2<Double>]` : la pastille de chaque ligne, en unités, depuis le centre de la carte).

La section 4.2 de la spec : hauteur d'une ligne, colonnes (1 à 3, sans colonne vide, au rapport le plus proche de 1,3), place de chaque pastille. Les largeurs des noms viennent de l'app, qui les mesure avec la police réelle (tâche 10) ; les tests les donnent.

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/CartesPiecesTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : cartes des pieces")
struct CartesPiecesTests {
    typealias Ligne = CartesPieces.Ligne

    static func proche(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    /// Le salon de la maquette : six lignes (le chef, trois routeurs d'Apple, un routeur, un appareil),
    /// le nom le plus long de 143 px : une colonne de 210 x 224 px, 8,75 x 9,33 unites.
    @Test func tailleDepuisLesLargeurs() {
        let c = CartesPieces.carte([Ligne(rayon: 8, largeurNom: 100), Ligne(rayon: 15, largeurNom: 80),
                                    Ligne(rayon: 13, largeurNom: 95), Ligne(rayon: 13, largeurNom: 100),
                                    Ligne(rayon: 8, largeurNom: 90), Ligne(rayon: 7, largeurNom: 143)])
        #expect(c.colonnes == 1)
        #expect(Self.proche(c.largeur * 24, 210) && Self.proche(c.profondeur * 24, 224))
        #expect(Self.proche(c.places[0].x, -76.0 / 24) && Self.proche(c.places[0].y, -89.0 / 24), "14 + rmax du bord")
        let milieu: Double = 8 + 30 + 21
        #expect(Self.proche(c.places[1].y, (milieu - 112) / 24), "au milieu de sa ligne de 42 px")
        #expect(c.places.allSatisfy { Self.proche($0.x, c.places[0].x) })
    }

    /// Nombre de colonnes : le rapport largeur / hauteur le plus proche de 1,3 ; douze lignes de 30 px
    /// et des noms de 60 px : deux colonnes (1,13), plutot qu'une (0,30) ou trois (2,45).
    @Test func choixDesColonnes() {
        let c = CartesPieces.carte(Array(repeating: Ligne(rayon: 7, largeurNom: 60), count: 12))
        #expect(c.colonnes == 2)
        #expect(Self.proche(c.largeur * 24, 222) && Self.proche(c.profondeur * 24, 196))
        #expect(Self.proche(c.places[0].x, -90.0 / 24) && Self.proche(c.places[6].x, 21.0 / 24))
        #expect(Self.proche(c.places[0].y, -75.0 / 24) && Self.proche(c.places[6].y, c.places[0].y), "en haut de la 2e")
        let sixieme: Double = 8 + 5 * 30 + 15
        #expect(Self.proche(c.places[5].y, (sixieme - 98) / 24))
    }

    /// Jamais de colonne vide : quatre lignes ne font pas trois colonnes (2 + 2 + 0) ; sept en font
    /// trois (3 + 3 + 1), remplies dans l'ordre des lignes.
    @Test func sansColonneVide() {
        let haute = Ligne(rayon: 15, largeurNom: 0)
        #expect(CartesPieces.carte(Array(repeating: haute, count: 4)).colonnes == 2)
        let sept = CartesPieces.carte(Array(repeating: haute, count: 7))
        #expect(sept.colonnes == 3)
        #expect(sept.places.count == 7)
        #expect(sept.places[0].x < sept.places[3].x && sept.places[3].x < sept.places[6].x)
        #expect(Self.proche(sept.places[2].x, sept.places[0].x) && Self.proche(sept.places[6].y, sept.places[0].y))
        #expect(CartesPieces.carte([haute]).colonnes == 1)
    }

    /// Un nom de plus de 40 caracteres est coupe : ses 39 premiers, puis « … » ; 40, tel quel.
    @Test func nomCoupe() {
        let quarante = String(repeating: "a", count: 40)
        #expect(CartesPieces.couper(quarante) == quarante)
        let long = "Détecteur de passage allée de la chambre d'amis ☾"
        let coupe = CartesPieces.couper(long)
        #expect(coupe.count == 40 && coupe.hasSuffix("…") && long.hasPrefix(String(coupe.dropLast())))
        #expect(CartesPieces.couper(String(repeating: "👑", count: 41)).count == 40)
    }

    /// Une carte par piece de la scene, dans l'ordre de ses lignes ; les largeurs viennent de l'app.
    @Test func cartesDeLaScene() throws {
        let g = try ScenePiecesTests.graphe(sonde: false)
        let s = ScenePieces(graphe: g, libelles: ScenePiecesTests.libelles, piecesNoeuds: ["Apple TV": "Salon"], zones: nil,
                            chefs: [], piecesMaison: true)
        let cartes = CartesPieces.cartes(s, largeurs: ["Apple TV": 70])
        #expect(cartes.count == s.pieces.count)
        let salon = try #require(s.pieces.firstIndex { $0.nom == .maison("Salon") })
        let largeur: Double = 14 + 30 + 9 + 70 + 14
        #expect(Self.proche(cartes[salon].largeur * 24, largeur))
        #expect(Self.proche(cartes[salon].profondeur * 24, 58))
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/CartesPiecesTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find type 'CartesPieces' in scope` et `error: cannot find 'CartesPieces' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Scene/CartesPieces.swift` (fichier entier) :

```swift
import Foundation

/// Cartes des pieces (spec de la vue par pieces, section 4.2) : chaque piece est une carte qui liste
/// ses noeuds, une ligne par noeud, en 1 a 3 colonnes. Les largeurs des noms sont mesurees par
/// l'app (police et taille reelles) et passees ici, en px a l'echelle naturelle de la 2D.
public enum CartesPieces {
    /// Px par unite de la scene, a l'echelle naturelle de la 2D.
    public static let px = 24.0
    /// Au-dela, un nom est coupe, avec « … ».
    public static let longueurMax = 40

    public struct Carte: Hashable, Sendable {
        /// Largeur (x) et profondeur (z) de la carte, en unites.
        public var largeur: Double
        public var profondeur: Double
        public var colonnes: Int
        /// Centre de la pastille de chaque ligne (x, z), par rapport au centre de la carte, en unites.
        public var places: [SIMD2<Double>]
    }

    /// Une ligne : le rayon naturel de la pastille et la largeur de son nom, en px.
    public struct Ligne: Hashable, Sendable {
        public var rayon: Double
        public var largeurNom: Double

        public init(rayon: Double, largeurNom: Double) {
            self.rayon = rayon
            self.largeurNom = largeurNom
        }
    }

    /// Un nom de plus de 40 caracteres : ses 39 premiers, puis « … ».
    public static func couper(_ nom: String) -> String {
        nom.count > longueurMax ? String(nom.prefix(longueurMax - 1)) + "…" : nom
    }

    /// Hauteur d'une ligne (px).
    public static func hauteurLigne(_ rayon: Double) -> Double { max(30, 2 * rayon + 12) }

    /// Carte d'une piece, ses lignes dans l'ordre. Colonnes remplies dans l'ordre des lignes, sans
    /// colonne vide ; largeur d'une colonne : 14 + 2 rmax + 9 + le nom le plus long + 14 px ;
    /// hauteur : les lignes de la plus haute colonne + 16 px. On garde le nombre de colonnes dont le
    /// rapport largeur / hauteur est le plus proche de 1,3 (au sens de |log(l / h / 1,3)|). Une
    /// pastille est a 14 + rmax px du bord gauche de sa colonne, au milieu de sa ligne ; la
    /// premiere ligne commence a 8 px du haut.
    public static func carte(_ lignes: [Ligne]) -> Carte {
        guard !lignes.isEmpty else { return Carte(largeur: 1, profondeur: 1, colonnes: 1, places: []) }
        var meilleur: (score: Double, colonnes: [[Int]], larg: [Double], w: Double, h: Double)?
        for n in 1...min(3, lignes.count) {
            let parColonne = (lignes.count + n - 1) / n
            if (n - 1) * parColonne >= lignes.count { continue }
            let colonnes = (0..<n).map { c in Array((c * parColonne)..<min((c + 1) * parColonne, lignes.count)) }
            let larg = colonnes.map { c in
                14 + 2 * c.map { lignes[$0].rayon }.max()! + 9 + c.map { lignes[$0].largeurNom }.max()! + 14
            }
            let h = colonnes.map { c in c.reduce(0) { $0 + hauteurLigne(lignes[$1].rayon) } }.max()! + 16
            let w = larg.reduce(0, +)
            let score = abs(log(w / h / 1.3))
            if meilleur.map({ score < $0.score }) ?? true { meilleur = (score, colonnes, larg, w, h) }
        }
        let m = meilleur!
        var places = [SIMD2<Double>](repeating: .zero, count: lignes.count)
        var x0 = 0.0
        for (c, colonne) in m.colonnes.enumerated() {
            let rmax = colonne.map { lignes[$0].rayon }.max()!
            var y = 8.0
            for i in colonne {
                let h = hauteurLigne(lignes[i].rayon)
                places[i] = SIMD2((x0 + 14 + rmax - m.w / 2) / px, (y + h / 2 - m.h / 2) / px)
                y += h
            }
            x0 += m.larg[c]
        }
        return Carte(largeur: m.w / px, profondeur: m.h / px, colonnes: m.colonnes.count, places: places)
    }

    /// Carte de chaque piece de la scene ; `largeurs` : largeur du nom de chaque noeud (px), 0 a
    /// defaut.
    public static func cartes(_ scene: ScenePieces, largeurs: [String: Double]) -> [Carte] {
        scene.pieces.map { p in
            carte(p.noeuds.map { id in
                Ligne(rayon: scene.noeud(id)?.rayon ?? 7, largeurNom: largeurs[id] ?? 0)
            })
        }
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/CartesPiecesTests`
Expected: `Test run with 5 tests in 1 suite passed` (`CartesPiecesTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 296 tests in 29 suites passed` (cœur) et `Test run with 247 tests in 27 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 5 tests et 1 suite de plus pour le cœur, l'app inchangée.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Scene/CartesPieces.swift MaillageCoeurTests/CartesPiecesTests.swift
git commit -m "Mesurer les cartes des pieces

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Cœur : la disposition des pièces (tassement, coût, optimisation, pièces fixées, budget)

**Files:**
- Create: `MaillageCoeur/Scene/DispositionPieces.swift`
- Create: `outils/mesurer.sh` (exécutable)
- Modify: `project.yml` (blocs ci-dessous : le cœur optimisé en Debug, le schéma `MaillageCoeur` des mesures)
- Test: `MaillageCoeurTests/DispositionPiecesTests.swift`, `MaillageCoeurTests/MaisonInventee.swift` (maisons inventées), `MaillageCoeurTests/Compilation.swift` (Debug ou Release)

**Interfaces:**
- Consumes :
  - `ScenePieces` (tâche 2), `CartesPieces` (tâche 3) ; dans les tests, `Banc`, `Instantane` et `ConstructionMaillage`, existants.
- Produces :
  - `public struct DispositionPieces: Hashable, Sendable` : `init(scene: ScenePieces, cartes: [CartesPieces.Carte], fixees: [Int: SIMD2<Double>] = [:], budget: Int = DispositionPieces.budget)` ; `positions: [SIMD2<Double>]` (centre de chaque pièce dans son plateau, x et z en unités), `rayons: [Double]` (un par étage), `coutDepart`, `cout`, `coups: Int` ;
  - `static let gap`, `lab`, `marge`, `esp` (en unités), `budget = 3000`, `departs = 6`, `toursMax = 25` ; `static func centres2D(rayons: [Double]) -> [Double]` (x du centre de chaque plateau en 2D, rangée centrée sur 0) ;
  - pour les tests : `DispositionPieces.dedans(_:_:_:)` (longueur d'un segment dans une carte, Liang-Barsky), `croise(_:_:_:_:)`, `Rect` ;
  - `MaisonInventee.graphe(pieces:routeurs:appareils:)` et `MaisonInventee.scene(pieces:appareils:routeurs:) -> (scene: ScenePieces, cartes: [CartesPieces.Carte])` ; `Compilation.optimisee` ;
  - `outils/mesurer.sh` : les deux tests de temps, en Release (le second arrive à la tâche 7).

La section 4.3 de la spec : séparation, tassement, départs, rayon des plateaux, coût, optimisation, pièces fixées, budget, déterminisme. Deux choix d'implémentation :
- le coût se calcule sur la vue 2D des étages côte à côte, avec des bornes rapides (boîtes des segments) avant le découpage de Liang-Barsky ;
- le budget de 3 000 coups vaut pour tout le calcul, les 6 départs compris : sur la grande maison inventée, il est atteint, et la disposition tient en 0,27 s en Release.

**Mesure des temps** (spec, section 10) : en Release, jamais en Debug. `tempsGrandeMaison` ne tourne que si `Compilation.optimisee` (pas de `DEBUG`) ; `outils/tester.sh` le saute, `outils/mesurer.sh` le lance, par le schéma `MaillageCoeur` (le cœur et ses tests, en Release) que cette tâche ajoute à `project.yml`. Le cœur est aussi compilé en `-O` en Debug : l'app de développement, puis les tests de l'app, disposent la démo en 0,04 s au lieu de 2,8 s.

- [ ] **Step 1 : écrire les tests.** `MaisonInventee` et `Compilation` servent aussi aux tests de la tâche 7.

`MaillageCoeurTests/MaisonInventee.swift` (fichier entier) :

```swift
import Foundation
@testable import MaillageCoeur

/// Maison inventee pour les tests de la scene : `pieces` pieces reparties sur deux etages,
/// `routeurs` routeurs de bordure relies en chaine (le premier est le chef), le routeur k dans la
/// piece k ; `appareils` appareils, l'appareil j dans la piece j modulo `pieces`, enfant du routeur
/// de numero (sa piece) modulo `routeurs`. Noms : 7 px par caractere, plus 10 px de marges.
enum MaisonInventee {
    static let partition = "0000000A"

    static func routeur(_ k: Int) -> String { String(format: "Routeur %02d", k) }
    static func appareil(_ j: Int) -> String { String(format: "E2%014X", j) }
    static func extMacRouteur(_ k: Int) -> String { String(format: "E1%014X", k) }

    static func graphe(pieces: Int, routeurs: Int, appareils: Int) -> GrapheReseau {
        var b = Banc()
        let omr = "fd00:5555:6666::/64"
        for k in 0..<routeurs {
            b.routeur(routeur(k), partition: partition, role: k == 0 ? .chef : .routeur, primaire: k == 0,
                      lien: "fe80::\(k + 1)", omr: omr, xa: extMacRouteur(k))
        }
        for j in 0..<appareils {
            b.appareil(appareil(j), noeud: j + 1, adresses: [String(format: "fd00:5555:6666:0:b00::%x", j + 1)])
        }
        let i = Instantane(annonces: b.annonces)
        let r = i.reseaux[0]
        let apps = i.appareils.map { AppareilAffiche(id: $0.id, nom: $0.id, partition: $0.partition, etat: .joignable) }
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: partition)
        c.routeurs(Route64(sequence: 0, routes: (1...routeurs).map {
            RouteRouteur(idRouteur: $0, qualiteSortante: 3, qualiteEntrante: 3, cout: 1)
        }), chef: 1)
        for k in 0..<routeurs {
            c.identite(extMacRouteur(k), routeur: k + 1)
            c.marquer(k + 1, bordure: true, bbrPrincipal: k == 0)
            if k > 0 { c.lien(k, k + 1, sortante: 3, entrante: 2) }
        }
        var enfants = [Int](repeating: 0, count: routeurs + 1)
        for j in 0..<appareils {
            let parent = (j % pieces) % routeurs + 1
            enfants[parent] += 1
            c.enfant(EnfantMaillage(rloc16: UInt16(parent) << 10 | UInt16(enfants[parent]), extMac: appareil(j), qualite: 2,
                                    source: .tableEnfants))
        }
        let m = MaillageAffiche(maillage: c.maillage(), reseau: r, appareils: i.appareils)
        return GrapheReseau(reseau: r, appareils: apps, maillage: m)
    }

    /// La scene et ses cartes.
    static func scene(pieces: Int, appareils: Int, routeurs: Int) -> (scene: ScenePieces, cartes: [CartesPieces.Carte]) {
        let g = graphe(pieces: pieces, routeurs: routeurs, appareils: appareils)
        func nomPiece(_ p: Int) -> String { String(format: "Pièce %02d", p) }
        var piecesNoeuds: [String: String] = [:]
        var libelles: [String: String] = [:]
        for k in 0..<routeurs {
            piecesNoeuds[routeur(k)] = nomPiece(k % pieces)
            libelles[routeur(k)] = routeur(k)
        }
        for j in 0..<appareils {
            piecesNoeuds[appareil(j)] = nomPiece(j % pieces)
            libelles[appareil(j)] = "Appareil \(j)"
        }
        let bas = (0..<pieces / 2).map(nomPiece)
        let haut = (pieces / 2..<pieces).map(nomPiece)
        let s = ScenePieces(graphe: g, libelles: libelles, piecesNoeuds: piecesNoeuds,
                            zones: [ZoneMaison(nom: "Bas", pieces: bas), ZoneMaison(nom: "Haut", pieces: haut)],
                            chefs: [routeur(0)], piecesMaison: true)
        let largeurs = libelles.mapValues { Double($0.count) * 7 + 10 }
        return (s, CartesPieces.cartes(s, largeurs: largeurs))
    }
}
```

`MaillageCoeurTests/Compilation.swift` (fichier entier) :

```swift
/// Configuration de la compilation des tests : les temps de calcul de la scene ne se mesurent
/// qu'optimises (Release, `outils/mesurer.sh`) ; en Debug, ces tests sont sautes.
enum Compilation {
    static var optimisee: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }
}
```

`MaillageCoeurTests/DispositionPiecesTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : disposition des pieces")
struct DispositionPiecesTests {
    /// Paires de cartes d'un meme etage qui se recouvrent, ecarts `gap` et `lab` compris (a 1e-6 pres).
    static func recouvrements(_ s: ScenePieces, _ c: [CartesPieces.Carte], _ d: DispositionPieces) -> [String] {
        var r: [String] = []
        for e in s.etages {
            for (k, a) in e.pieces.enumerated() {
                for b in e.pieces[(k + 1)...] {
                    let dx = d.positions[b].x - d.positions[a].x, dz = d.positions[b].y - d.positions[a].y
                    let px = (c[a].largeur + c[b].largeur) / 2 + DispositionPieces.gap - abs(dx)
                    let pz = (c[a].profondeur + c[b].profondeur) / 2 + DispositionPieces.gap + DispositionPieces.lab - abs(dz)
                    if px > 1e-6 && pz > 1e-6 { r.append("\(s.pieces[a].id) / \(s.pieces[b].id)") }
                }
            }
        }
        return r
    }

    /// Maison inventee : 8 pieces, 30 appareils, 4 routeurs ; aucun recouvrement, chaque carte dans son
    /// plateau, et le cout retenu au plus celui du depart.
    @Test func aucunRecouvrement() {
        let (s, c) = MaisonInventee.scene(pieces: 8, appareils: 30, routeurs: 4)
        let d = DispositionPieces(scene: s, cartes: c)
        #expect(Self.recouvrements(s, c, d) == [])
        #expect(d.rayons.count == s.etages.count)
        for (i, p) in s.pieces.enumerated() {
            let coin = SIMD2(abs(d.positions[i].x) + c[i].largeur / 2, abs(d.positions[i].y) + c[i].profondeur / 2)
            #expect((coin.x * coin.x + coin.y * coin.y).squareRoot() <= d.rayons[p.etage], "\(p.id) dans son plateau")
        }
        #expect(d.cout <= d.coutDepart)
        #expect(d.coups > 0 && d.coups <= DispositionPieces.budget)
    }

    /// Memes entrees, meme disposition.
    @Test func deterministe() {
        let (s, c) = MaisonInventee.scene(pieces: 6, appareils: 20, routeurs: 3)
        let a = DispositionPieces(scene: s, cartes: c)
        let b = DispositionPieces(scene: s, cartes: c)
        #expect(a == b)
    }

    /// Une piece fixee ne bouge pas, et sert d'obstacle : les autres se placent sans la recouvrir, ni
    /// se recouvrir entre elles. Tout fixe : aucune optimisation.
    @Test func pieceFixee() {
        let (s, c) = MaisonInventee.scene(pieces: 6, appareils: 20, routeurs: 3)
        let place = SIMD2(4.5, -3.0)
        let d = DispositionPieces(scene: s, cartes: c, fixees: [0: place])
        #expect(d.positions[0] == place)
        #expect(Self.recouvrements(s, c, d) == [])
        let toutes = Dictionary(uniqueKeysWithValues: d.positions.enumerated().map { ($0, $1) })
        let figee = DispositionPieces(scene: s, cartes: c, fixees: toutes)
        #expect(figee.positions == d.positions)
        #expect(figee.coups == 0)
    }

    /// Budget : au plus `budget` coups ; le resultat reste sans recouvrement, et au plus le cout du depart.
    @Test func budget() {
        let (s, c) = MaisonInventee.scene(pieces: 8, appareils: 30, routeurs: 4)
        let d = DispositionPieces(scene: s, cartes: c, budget: 40)
        #expect(d.coups == 40)
        #expect(Self.recouvrements(s, c, d) == [])
        #expect(d.cout <= d.coutDepart)
    }

    /// Plateaux cote a cote en 2D : `esp` entre les bords de deux voisins, la rangee centree sur x = 0.
    @Test func centres2D() {
        let x = DispositionPieces.centres2D(rayons: [10, 4, 6])
        #expect(abs((x[1] - 4) - (x[0] + 10) - DispositionPieces.esp) < 1e-9)
        #expect(abs((x[2] - 6) - (x[1] + 4) - DispositionPieces.esp) < 1e-9)
        #expect(abs((x[0] - 10) + (x[2] + 6)) < 1e-9)
        #expect(DispositionPieces.centres2D(rayons: [7]) == [0])
    }

    /// Temps de calcul, en Release : sur une grande maison inventee (20 pieces, 100 appareils, 6
    /// routeurs de bordure), la disposition tient sous 1 s.
    @Test(.enabled(if: Compilation.optimisee, "mesure en Release (outils/mesurer.sh)"))
    func tempsGrandeMaison() {
        let (s, c) = MaisonInventee.scene(pieces: 20, appareils: 100, routeurs: 6)
        #expect(s.pieces.count == 20 && s.noeuds.count == 106)
        let debut = DispatchTime.now().uptimeNanoseconds
        let d = DispositionPieces(scene: s, cartes: c)
        let secondes = Double(DispatchTime.now().uptimeNanoseconds - debut) / 1e9
        print("mesure : disposition de la grande maison en \(secondes) s, \(d.coups) coups")
        #expect(secondes < 1, "\(secondes) s pour \(d.coups) coups")
        #expect(Self.recouvrements(s, c, d) == [])
    }

    /// Longueur traversee (Liang-Barsky) et croisements stricts.
    @Test func geometrie() {
        let r = DispositionPieces.Rect(x0: 0, x1: 2, z0: 0, z1: 1)
        #expect(abs(DispositionPieces.dedans(SIMD2(-1, 0.5), SIMD2(3, 0.5), r) - 2) < 1e-12)
        #expect(DispositionPieces.dedans(SIMD2(-1, 2), SIMD2(3, 2), r) == 0)
        #expect(abs(DispositionPieces.dedans(SIMD2(1, 0.5), SIMD2(1, 3), r) - 0.5) < 1e-12)
        #expect(DispositionPieces.croise(SIMD2(0, 0), SIMD2(2, 2), SIMD2(0, 2), SIMD2(2, 0)))
        #expect(!DispositionPieces.croise(SIMD2(0, 0), SIMD2(1, 1), SIMD2(1, 1), SIMD2(2, 0)), "bout commun")
        #expect(!DispositionPieces.croise(SIMD2(0, 0), SIMD2(1, 0), SIMD2(0, 1), SIMD2(1, 1)))
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/DispositionPiecesTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find type 'DispositionPieces' in scope` et `error: cannot find 'DispositionPieces' in scope`.

- [ ] **Step 3 : écrire le code.** La disposition, le script des mesures, puis `project.yml` : le cœur optimisé en Debug, et le schéma `MaillageCoeur` des mesures.

`MaillageCoeur/Scene/DispositionPieces.swift` (fichier entier) :

```swift
import Foundation

/// Disposition des pieces dans leurs etages (spec de la vue par pieces, section 4.3) : cartes
/// espacees, tassees de facon organique, puis placees pour que les liens evitent les autres pieces
/// et se croisent peu. Deterministe : memes entrees, meme disposition, sur toutes les machines (le
/// budget compte des coups, pas du temps). Calcul hors du fil principal : il peut prendre une
/// fraction de seconde.
public struct DispositionPieces: Hashable, Sendable {
    /// Ecart entre cartes, bande du nom au-dessus d'une carte, marge du plateau, ecart entre plateaux
    /// en 2D (unites).
    public static let gap = 80 / CartesPieces.px
    public static let lab = 28 / CartesPieces.px
    public static let marge = 56 / CartesPieces.px
    public static let esp = 140 / CartesPieces.px
    /// Coups evalues au plus par calcul, tous departs compris.
    public static let budget = 3000
    public static let departs = 6
    public static let toursMax = 25

    /// Centre de chaque piece (x, z) par rapport au centre de son plateau, en unites.
    public var positions: [SIMD2<Double>]
    /// Rayon de chaque plateau, dans l'ordre des etages.
    public var rayons: [Double]
    /// Cout du premier depart, apres son tassement ; cout de la disposition retenue.
    public var coutDepart: Double
    public var cout: Double
    /// Coups evalues.
    public var coups: Int

    /// `fixees` : places gardees des pieces deplacees (indice de piece -> position) ; elles ne bougent
    /// pas et servent d'obstacles.
    public init(scene: ScenePieces, cartes: [CartesPieces.Carte], fixees: [Int: SIMD2<Double>] = [:],
                budget: Int = DispositionPieces.budget) {
        let calcul = Calcul(scene: scene, cartes: cartes, fixees: fixees)
        let n = scene.pieces.count
        guard n > 0, calcul.fixe.contains(false) else {
            let pos = (0..<n).map { fixees[$0] ?? .zero }
            positions = pos
            rayons = (0..<calcul.nbEtages).map { calcul.rayon(pos, $0) }
            coutDepart = calcul.cout(pos)
            cout = coutDepart
            coups = 0
            return
        }
        var joues = 0
        var retenu: [SIMD2<Double>] = []
        var coutRetenu = Double.infinity
        var depart = 0.0
        var epuise = false
        for essai in 0..<Self.departs where !epuise {
            var pos = calcul.depart(essai, fixees: fixees)
            for e in 0..<calcul.nbEtages { calcul.tasser(&pos, e, tours: 900, facteur: 0.996) }
            var courant = pos
            var c = calcul.cout(courant)
            if essai == 0 { depart = c }
            for _ in 0..<Self.toursMax {
                var mieux: [SIMD2<Double>]?
                var cm = c
                for e in 0..<calcul.nbEtages where !epuise {
                    for coup in calcul.coups(e) {
                        guard joues < budget else {
                            epuise = true
                            break
                        }
                        joues += 1
                        var p = courant
                        calcul.jouer(coup, &p, etage: e)
                        calcul.tasser(&p, e, tours: 200, facteur: 0.998)
                        let cc = calcul.cout(p)
                        if cc < cm - 1e-6 {
                            cm = cc
                            mieux = p
                        }
                    }
                }
                if let m = mieux {
                    courant = m
                    c = cm
                }
                if epuise || mieux == nil { break }
            }
            if c < coutRetenu {
                coutRetenu = c
                retenu = courant
            }
        }
        positions = retenu
        rayons = (0..<calcul.nbEtages).map { calcul.rayon(retenu, $0) }
        coutDepart = depart
        cout = coutRetenu
        coups = joues
    }

    /// Centre x de chaque plateau en 2D : cote a cote, `esp` entre les bords de deux voisins, la
    /// rangee centree sur x = 0.
    public static func centres2D(rayons: [Double]) -> [Double] {
        guard let r0 = rayons.first, let rn = rayons.last else { return [] }
        var x = [0.0]
        for i in rayons.indices.dropFirst() { x.append(x[i - 1] + rayons[i - 1] + esp + rayons[i]) }
        let milieu = ((x[0] - r0) + (x[x.count - 1] + rn)) / 2
        return x.map { $0 - milieu }
    }

    /// Longueur d'un segment a l'interieur d'un rectangle (decoupage de Liang et Barsky).
    static func dedans(_ p: SIMD2<Double>, _ q: SIMD2<Double>, _ r: Rect) -> Double {
        if max(p.x, q.x) <= r.x0 || min(p.x, q.x) >= r.x1 || max(p.y, q.y) <= r.z0 || min(p.y, q.y) >= r.z1 { return 0 }
        var t0 = 0.0
        var t1 = 1.0
        let d = q - p
        // Une borne du rectangle : faux si le segment est tout entier dehors.
        func borne(_ pp: Double, _ qq: Double) -> Bool {
            if pp == 0 { return qq >= 0 }
            let u = qq / pp
            if pp < 0 {
                if u > t1 { return false }
                if u > t0 { t0 = u }
            } else {
                if u < t0 { return false }
                if u < t1 { t1 = u }
            }
            return true
        }
        guard borne(-d.x, p.x - r.x0), borne(d.x, r.x1 - p.x), borne(-d.y, p.y - r.z0), borne(d.y, r.z1 - p.y) else {
            return 0
        }
        return t1 > t0 ? (t1 - t0) * (d.x * d.x + d.y * d.y).squareRoot() : 0
    }

    static func sens(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ c: SIMD2<Double>) -> Double {
        let v = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        return v > 0 ? 1 : v < 0 ? -1 : 0
    }

    /// Deux segments se coupent (strictement).
    static func croise(_ p: SIMD2<Double>, _ q: SIMD2<Double>, _ r: SIMD2<Double>, _ w: SIMD2<Double>) -> Bool {
        sens(p, q, r) * sens(p, q, w) < 0 && sens(r, w, p) * sens(r, w, q) < 0
    }

    /// Rectangle d'une carte en 2D, bande du nom comprise (au-dessus : vers -z).
    struct Rect {
        var x0, x1, z0, z1: Double
    }

    /// Donnees du calcul : tailles des cartes, etages, liens entre noeuds places dans leurs cartes.
    struct Calcul {
        enum Coup {
            case symetrie(Int)
            case echange(Int, Int)
        }

        struct Lien {
            var pa, pb: Int
            var la, lb: SIMD2<Double>
            var na, nb: Int
        }

        let w: [Double]
        let d: [Double]
        let etage: [Int]
        let nbEtages: Int
        /// Pieces de chaque etage, par aire decroissante.
        let parEtage: [[Int]]
        let fixe: [Bool]
        let lie: [[Bool]]
        let liens: [Lien]

        init(scene: ScenePieces, cartes: [CartesPieces.Carte], fixees: [Int: SIMD2<Double>]) {
            let n = scene.pieces.count
            let largeurs = cartes.map(\.largeur), profondeurs = cartes.map(\.profondeur)
            let aire = (0..<n).map { largeurs[$0] * profondeurs[$0] }
            w = largeurs
            d = profondeurs
            etage = scene.pieces.map(\.etage)
            nbEtages = scene.etages.count
            fixe = (0..<n).map { fixees[$0] != nil }
            parEtage = scene.etages.map { e in e.pieces.sorted { (-aire[$0], $0) < (-aire[$1], $1) } }
            // Place de chaque noeud dans sa carte.
            var place: [String: (piece: Int, local: SIMD2<Double>, indice: Int)] = [:]
            for (i, p) in scene.pieces.enumerated() {
                for (k, id) in p.noeuds.enumerated() {
                    place[id] = (i, k < cartes[i].places.count ? cartes[i].places[k] : .zero, scene.indice(id) ?? 0)
                }
            }
            var liens: [Lien] = []
            var lie = [[Bool]](repeating: [Bool](repeating: false, count: n), count: n)
            for l in scene.liens {
                guard let a = place[l.de], let b = place[l.vers] else { continue }
                liens.append(Lien(pa: a.piece, pb: b.piece, la: a.local, lb: b.local, na: a.indice, nb: b.indice))
                if a.piece != b.piece {
                    lie[a.piece][b.piece] = true
                    lie[b.piece][a.piece] = true
                }
            }
            self.liens = liens
            self.lie = lie
        }

        /// Depart `essai` : les cartes libres de chaque etage, par aire decroissante, sur une spirale
        /// (angle phase + i 2,39996, rayon racine(i + 0,5) 6, phase = essai 1,047) ; les fixees a leur place.
        func depart(_ essai: Int, fixees: [Int: SIMD2<Double>]) -> [SIMD2<Double>] {
            var pos = [SIMD2<Double>](repeating: .zero, count: w.count)
            for liste in parEtage {
                var i = 0
                for p in liste {
                    if let f = fixees[p] {
                        pos[p] = f
                        continue
                    }
                    let a = Double(essai) * 1.047 + Double(i) * 2.39996
                    let r = (Double(i) + 0.5).squareRoot() * 6
                    pos[p] = SIMD2(cos(a) * r, sin(a) * r)
                    i += 1
                }
            }
            return pos
        }

        /// Ecarte deux cartes qui se recouvrent (ecarts `gap` et `lab` compris) sur l'axe ou la
        /// penetration est la plus faible, de moitie chacune (toute pour une carte libre face a une
        /// fixee) ; rapproche de 0,3 % de leur ecart deux cartes reliees par un lien.
        func separer(_ pos: inout [SIMD2<Double>], _ e: Int, attirer: Bool) {
            let liste = parEtage[e]
            for i in liste.indices {
                for j in liste.indices where j > i {
                    let a = liste[i], b = liste[j]
                    if fixe[a] && fixe[b] { continue }
                    let dx = pos[b].x - pos[a].x, dz = pos[b].y - pos[a].y
                    let px = (w[a] + w[b]) / 2 + gap - abs(dx)
                    let pz = (d[a] + d[b]) / 2 + gap + lab - abs(dz)
                    let fa = fixe[a] ? 0.0 : fixe[b] ? 1.0 : 0.5
                    let fb = 1 - fa
                    if px > 0 && pz > 0 {
                        if px < pz {
                            let m = (dx < 0 ? -1.0 : 1.0) * px
                            pos[a].x -= m * fa
                            pos[b].x += m * fb
                        } else {
                            let m = (dz < 0 ? -1.0 : 1.0) * pz
                            pos[a].y -= m * fa
                            pos[b].y += m * fb
                        }
                    } else if attirer && lie[a][b] {
                        let v = SIMD2(dx, dz) * 0.003
                        if !fixe[a] { pos[a] += v }
                        if !fixe[b] { pos[b] -= v }
                    }
                }
            }
        }

        /// Recentre les cartes d'un etage sur leur boite, bande des noms comprise.
        func recentrer(_ pos: inout [SIMD2<Double>], _ e: Int) {
            var x0 = Double.infinity, x1 = -Double.infinity, z0 = Double.infinity, z1 = -Double.infinity
            for p in parEtage[e] {
                x0 = min(x0, pos[p].x - w[p] / 2)
                x1 = max(x1, pos[p].x + w[p] / 2)
                z0 = min(z0, pos[p].y - d[p] / 2 - lab)
                z1 = max(z1, pos[p].y + d[p] / 2)
            }
            let c = SIMD2((x0 + x1) / 2, (z0 + z1) / 2)
            for p in parEtage[e] { pos[p] -= c }
        }

        /// `tours` de separation, chacun suivi d'une homothetie de `facteur` vers le centre ; puis 60
        /// de separation seule ; puis le recentrage (sauf si l'etage a une carte fixee).
        func tasser(_ pos: inout [SIMD2<Double>], _ e: Int, tours: Int, facteur: Double) {
            let libres = parEtage[e].filter { !fixe[$0] }
            for _ in 0..<tours {
                separer(&pos, e, attirer: true)
                for p in libres { pos[p] *= facteur }
            }
            for _ in 0..<60 { separer(&pos, e, attirer: false) }
            if libres.count == parEtage[e].count { recentrer(&pos, e) }
        }

        /// Plus grande distance du centre a un coin de carte (bande du nom comprise), plus la marge.
        func rayon(_ pos: [SIMD2<Double>], _ e: Int) -> Double {
            var r = 0.0
            for p in parEtage[e] {
                let x = abs(pos[p].x) + w[p] / 2
                let z = max(abs(pos[p].y - d[p] / 2 - lab), abs(pos[p].y + d[p] / 2))
                r = max(r, (x * x + z * z).squareRoot())
            }
            return r + marge
        }

        /// Coups d'un etage : les 7 symetries du carre appliquees aux cartes libres, puis l'echange
        /// de chaque paire de cartes libres.
        func coups(_ e: Int) -> [Coup] {
            let libres = parEtage[e].filter { !fixe[$0] }
            guard !libres.isEmpty else { return [] }
            var c = (1...7).map { Coup.symetrie($0) }
            for i in libres.indices {
                for j in libres.indices where j > i { c.append(.echange(libres[i], libres[j])) }
            }
            return c
        }

        func jouer(_ coup: Coup, _ pos: inout [SIMD2<Double>], etage e: Int) {
            switch coup {
            case .symetrie(let o):
                for p in parEtage[e] where !fixe[p] {
                    let v = pos[p]
                    switch o {
                    case 1: pos[p] = SIMD2(-v.y, v.x)
                    case 2: pos[p] = SIMD2(-v.x, -v.y)
                    case 3: pos[p] = SIMD2(v.y, -v.x)
                    case 4: pos[p] = SIMD2(-v.x, v.y)
                    case 5: pos[p] = SIMD2(v.y, v.x)
                    case 6: pos[p] = SIMD2(v.x, -v.y)
                    default: pos[p] = SIMD2(-v.y, -v.x)
                    }
                }
            case .echange(let a, let b):
                pos.swapAt(a, b)
            }
        }

        /// Rectangles des cartes et extremites des liens dans la vue 2D des etages cote a cote.
        func vue2D(_ pos: [SIMD2<Double>]) -> (rayons: [Double], rects: [Rect], segments: [(SIMD2<Double>, SIMD2<Double>)]) {
            let rayons = (0..<nbEtages).map { rayon(pos, $0) }
            let cx = DispositionPieces.centres2D(rayons: rayons)
            let rects = pos.indices.map { i in
                let x = cx[etage[i]] + pos[i].x, z = pos[i].y
                return Rect(x0: x - w[i] / 2, x1: x + w[i] / 2, z0: z - d[i] / 2 - lab, z1: z + d[i] / 2)
            }
            let segments = liens.map { l in
                (SIMD2(cx[etage[l.pa]], 0) + pos[l.pa] + l.la, SIMD2(cx[etage[l.pb]], 0) + pos[l.pb] + l.lb)
            }
            return (rayons, rects, segments)
        }

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
                    if s.na == t.na || s.na == t.nb || s.nb == t.na || s.nb == t.nb { continue }
                    let (r, u) = v.segments[j]
                    if max(p.x, q.x) < min(r.x, u.x) || max(r.x, u.x) < min(p.x, q.x)
                        || max(p.y, q.y) < min(r.y, u.y) || max(r.y, u.y) < min(p.y, q.y) { continue }
                    if DispositionPieces.croise(p, q, r, u) { c += 5 }
                }
            }
            return c
        }

        /// Liens qui passent sur une carte autre que celles de leurs bouts (tests).
        func traversees(_ pos: [SIMD2<Double>]) -> Int {
            let v = vue2D(pos)
            var n = 0
            for (k, l) in liens.enumerated() {
                let (p, q) = v.segments[k]
                for (r, rect) in v.rects.enumerated() where r != l.pa && r != l.pb
                    && DispositionPieces.dedans(p, q, rect) > 0 {
                    n += 1
                }
            }
            return n
        }
    }
}
```

`outils/mesurer.sh` (fichier entier) :

```sh
#!/bin/sh
# Temps de calcul de la vue par pieces, en Release (spec de la vue par pieces, section 10) : la
# disposition d'une grande maison inventee (sous 1 s) et le placement de 150 noms (sous 2 ms).
# En Debug (outils/tester.sh), ces deux tests sont sautes. Schema MaillageCoeur : le coeur et ses
# tests seuls. Journal complet dans $TMPDIR/maillage-mesures.log. Produits de compilation hors du
# depot (DD).
set -u
cd "$(dirname "$0")/.."
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage}
JOURNAL=${TMPDIR:-/tmp}/maillage-mesures.log
xcodegen generate --quiet || exit 1
xcodebuild -project MaillageThread.xcodeproj -scheme MaillageCoeur -destination 'platform=macOS' \
  -derivedDataPath "$DD" -configuration Release ENABLE_TESTABILITY=YES ONLY_ACTIVE_ARCH=YES test \
  -only-testing:MaillageCoeurTests/DispositionPiecesTests -only-testing:MaillageCoeurTests/PlacementNomsTests \
  > "$JOURNAL" 2>&1
CODE=$?
grep -E "(error|warning): |✘|mesure : |Test run with|\*\* TEST" "$JOURNAL" | grep -v -e appintentsmetadataprocessor -e "\[Connection\]"
echo "journal complet : $JOURNAL (code $CODE)"
exit $CODE
```

```bash
chmod +x outils/mesurer.sh
```

Dans `project.yml`, remplacer :

```yaml
        SKIP_INSTALL: YES
        DEFINES_MODULE: YES
  MaillageThread:
```

par :

```yaml
        SKIP_INSTALL: YES
        DEFINES_MODULE: YES
      configs:
        # Le coeur est optimise aussi en Debug : non optimisee, la disposition des pieces prend
        # quelques secondes (80 a 100 fois plus). Il n'a ni assert ni code propre au Debug.
        Debug:
          SWIFT_OPTIMIZATION_LEVEL: "-O"
  MaillageThread:
```

Dans `project.yml`, remplacer :

```yaml
  Passeur:
    build:
      targets:
        Passeur: all
    run:
      config: Debug
```

par :

```yaml
  Passeur:
    build:
      targets:
        Passeur: all
    run:
      config: Debug
  # Le coeur seul : les temps de calcul de la vue par pieces, en Release (outils/mesurer.sh).
  MaillageCoeur:
    build:
      targets:
        MaillageCoeur: all
        MaillageCoeurTests: [test]
    test:
      config: Release
      targets:
        - MaillageCoeurTests
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/DispositionPiecesTests`
Expected: `Test run with 7 tests in 1 suite passed` (`DispositionPiecesTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les temps, en Release.** La disposition de la grande maison inventée (20 pièces, 100 appareils, 6 routeurs de bordure) doit tenir sous 1 s ; `tempsDePlacement` arrive à la tâche 7, et le filtre du script l'attend déjà.

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/mesurer.sh`
Expected: `mesure : disposition de la grande maison en 0.252626833 s, 3000 coups` (ce temps-ci au rejeu, qui varie d'une machine à l'autre ; les coups, non), puis `Test run with 7 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 303 tests in 30 suites passed` (cœur) et `Test run with 247 tests in 27 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 7 tests et 1 suite de plus pour le cœur, l'app inchangée. En Debug, `tempsGrandeMaison` est sauté (le journal complet le dit) mais compté.

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Scene/DispositionPieces.swift MaillageCoeurTests/MaisonInventee.swift MaillageCoeurTests/Compilation.swift MaillageCoeurTests/DispositionPiecesTests.swift outils/mesurer.sh project.yml
git commit -m "Disposer les pieces dans leurs etages

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Cœur : les places gardées, et la pièce des routeurs d'Apple

**Files:**
- Create: `MaillageCoeur/Scene/PlacesGardees.swift`, `MaillageCoeur/Scene/PiecesRouteurs.swift`
- Test: `MaillageCoeurTests/PlacesGardeesTests.swift`, `MaillageCoeurTests/PiecesRouteursTests.swift`

**Interfaces:**
- Consumes :
  - `ScenePieces` (tâche 2) ; `NomsMaison` (`accessoires`, `zones`), `AccessoireMaison`, `ZoneMaison`, existants ; dans les tests, `ScenePiecesTests.graphe(sonde:)` et `ScenePiecesTests.libelles`.
- Produces :
  - `public struct PlacesGardees: Hashable, Sendable, Codable` : `version` (1), `maisons: [String: Maison]` (par domicile) ; `init()` ; `static func lire(_ url: URL) -> PlacesGardees` (vide si le fichier manque, est illisible ou d'une version plus récente) ; `func ecrire(dans url: URL) throws` (JSON à clés triées, écriture atomique, dossier créé) ; `func maison(_ domicile: String) -> Maison` ; `mutating func garder(_ place: SIMD2<Double>, piece: String, etage: String, domicile: String)` ; `mutating func ordonner(_ etages: [String], domicile: String)` ; `mutating func replacer(domicile: String)` (efface les places, garde l'ordre des étages) ; `func fixees(_ scene: ScenePieces, domicile: String) -> [Int: SIMD2<Double>]` ;
  - `PlacesGardees.Maison` (`ordreEtages: [String]`, `etages: [String: [String: Place]]`, par clé d'étage puis de pièce) ; `PlacesGardees.Place` (`x`, `z`) ;
  - `public struct PiecesRouteurs: Hashable, Sendable, Codable` : `version` (1), `maisons: [String: [String: String]]` (par domicile, l'instance de l'annonce vers la pièce choisie) ; `init()` ; `static func lire(_ url: URL) -> PiecesRouteurs` (vide si le fichier manque, est illisible ou d'une version plus récente) ; `func ecrire(dans url: URL) throws` ; `func choix(routeur: String, domicile: String) -> String?` ; `mutating func choisir(_ piece: String?, routeur: String, domicile: String)` (nil : la règle du nom) ; `func piece(routeur: String, nom: String, parmi pieces: [String], domicile: String) -> String?` (le choix s'il est encore une pièce, sinon le nom) ; `static func piece(nom: String, parmi pieces: [String]) -> String?` (précision 23) ; `static func pieces(de maison: NomsMaison?) -> [String]` (celles des accessoires et des zones, sans doublon, triées) ; `static func mots(_ s: String) -> [String]`.

La section 2.4 de la spec. Les places sont rangées par clé d'étage et de pièce (`NomEtage.cle`, `NomPiece.cle`) : une pièce renommée, ou passée dans un autre étage, ne retrouve plus sa place, et se replace seule sans bouger les autres. Le fichier est `positions-pieces.json`, à côté de `identites-routeurs.json` (tâche 12).

**La pièce des routeurs d'Apple** (précisions 23 et 24, recos validées le 30/09) : HomeKit ne donne à une app tierce ni les HomePod ni l'Apple TV. Pour un routeur de bordure sans pièce de Maison, `PiecesRouteurs` rend la pièce choisie pour lui (tant qu'elle est dans Maison), sinon celle de son nom : mots entiers qui se suivent, sans casse ni accents, le nom de pièce le plus long, rien à égalité. Le choix est gardé par maison sous l'instance de l'annonce, l'identité sous laquelle l'app garde déjà les surnoms. `PlacesGardees` et `PiecesRouteurs` sont deux fichiers, à côté : l'un porte la géométrie de la vue, l'autre la pièce d'un routeur, que la scène lit comme celle de Maison. L'app s'en sert à la tâche 10 (`LibellesNoeuds.pieces`) et à la tâche 12 (le menu, le fichier).

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/PlacesGardeesTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : places gardees")
struct PlacesGardeesTests {
    static func fichier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("positions-\(UUID().uuidString)/positions-pieces.json")
    }

    static func scene(zones: [ZoneMaison]) throws -> ScenePieces {
        ScenePieces(graphe: try ScenePiecesTests.graphe(sonde: false), libelles: ScenePiecesTests.libelles,
                    piecesNoeuds: ["Apple TV": "Salon", "HomePod": "Chambre"], zones: zones, chefs: [], piecesMaison: true)
    }

    /// Aller-retour sur disque : places et ordre des etages, par maison ; un fichier absent ou
    /// illisible donne des places vides.
    @Test func allerRetour() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var p = PlacesGardees()
        p.garder(SIMD2(1.5, -2.25), piece: "piece:Salon", etage: "zone:Rez-de-chaussée", domicile: "Maison")
        p.ordonner(["zone:Étage", "zone:Rez-de-chaussée"], domicile: "Maison")
        p.garder(SIMD2(3, 4), piece: "piece:Salon", etage: "maison", domicile: "Chalet")
        try p.ecrire(dans: url)
        let relu = PlacesGardees.lire(url)
        #expect(relu == p)
        #expect(relu.maison("Maison").ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
        #expect(relu.maison("Maison").etages["zone:Rez-de-chaussée"]?["piece:Salon"] == PlacesGardees.Place(x: 1.5, z: -2.25))
        #expect(PlacesGardees.lire(url.appendingPathExtension("absent")) == PlacesGardees())
        try Data("pas du json".utf8).write(to: url)
        #expect(PlacesGardees.lire(url) == PlacesGardees())
    }

    /// Pieces fixees : celles qui ont une place gardee dans leur etage. Renommee, ou passee dans un
    /// autre etage, une piece perd sa place ; les autres la gardent.
    @Test func pieceRenommeeOuDeplacee() throws {
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre"])]
        let s = try Self.scene(zones: zones)
        var p = PlacesGardees()
        p.garder(SIMD2(1, 2), piece: "piece:Salon", etage: "zone:Rez-de-chaussée", domicile: "")
        p.garder(SIMD2(3, 4), piece: "piece:Chambre", etage: "zone:Étage", domicile: "")
        let salon = try #require(s.pieces.firstIndex { $0.nom == .maison("Salon") })
        let chambre = try #require(s.pieces.firstIndex { $0.nom == .maison("Chambre") })
        #expect(p.fixees(s, domicile: "") == [salon: SIMD2(1, 2), chambre: SIMD2(3, 4)])
        #expect(p.fixees(s, domicile: "Autre").isEmpty)
        // La chambre passe au rez-de-chaussee : elle perd sa place, le salon garde la sienne.
        let deplacee = try Self.scene(zones: [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Chambre"])])
        let salon2 = try #require(deplacee.pieces.firstIndex { $0.nom == .maison("Salon") })
        #expect(p.fixees(deplacee, domicile: "") == [salon2: SIMD2(1, 2)])
    }

    /// Ordre des etages garde, puis « Replacer les pieces automatiquement » : les places partent,
    /// l'ordre reste.
    @Test func ordreDesEtagesEtReplacement() throws {
        var p = PlacesGardees()
        p.ordonner(["zone:Étage", "zone:Rez-de-chaussée"], domicile: "")
        p.garder(SIMD2(1, 2), piece: "piece:Salon", etage: "zone:Rez-de-chaussée", domicile: "")
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre"])]
        let s = ScenePieces(graphe: try ScenePiecesTests.graphe(sonde: false), libelles: [:],
                            piecesNoeuds: ["Apple TV": "Salon", "HomePod": "Chambre"], zones: zones, chefs: [],
                            piecesMaison: true, ordreEtages: p.maison("").ordreEtages)
        #expect(s.etages.map(\.id) == ["zone:Étage", "zone:Rez-de-chaussée"])
        p.replacer(domicile: "")
        #expect(p.maison("").etages.isEmpty)
        #expect(p.maison("").ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
    }
}
```

`MaillageCoeurTests/PiecesRouteursTests.swift` (fichier entier) :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : piece des routeurs que Maison ne place pas")
struct PiecesRouteursTests {
    /// Pieces d'une maison inventee.
    static let pieces = ["Bureau", "Chambre", "Chambre d'amis", "Entrée", "Salle de bain", "Salon"]

    static func fichier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("routeurs-\(UUID().uuidString)/pieces-routeurs.json")
    }

    /// D'apres le nom : en mots entiers, sans egard a la casse ni aux accents.
    @Test(arguments: [
        ("HomePod mini chambre", "Chambre"),
        ("HomePod mini bureau", "Bureau"),
        ("HOMEPOD ENTREE", "Entrée"),
        ("Apple TV (salon)", "Salon"),
        ("HomePod-salle-de-bain", "Salle de bain"),
    ])
    func dApresLeNom(nom: String, attendue: String) {
        #expect(PiecesRouteurs.piece(nom: nom, parmi: Self.pieces) == attendue)
    }

    /// Rien sans piece dans le nom : un mot entier, pas un bout de mot (« Salons », « Bureautique ») ;
    /// les mots de la piece doivent se suivre.
    @Test(arguments: ["HomePod Palier", "HomePod Avant", "Apple TV", "HomePod Salons", "Bureautique",
                      "HomePod salle, bain"])
    func sansPieceDansLeNom(nom: String) {
        #expect(PiecesRouteurs.piece(nom: nom, parmi: Self.pieces) == nil)
    }

    /// Le nom de piece le plus long gagne ; a egalite de longueur entre deux pieces, aucune.
    @Test func plusLongueOuAucune() {
        #expect(PiecesRouteurs.piece(nom: "HomePod chambre d'amis", parmi: Self.pieces) == "Chambre d'amis")
        #expect(PiecesRouteurs.piece(nom: "HomePod bureau entrée", parmi: Self.pieces) == nil, "Bureau et Entrée : 6 lettres")
        #expect(PiecesRouteurs.piece(nom: "HomePod salon chambre", parmi: Self.pieces) == "Chambre")
        #expect(PiecesRouteurs.piece(nom: "HomePod entree", parmi: ["Entrée", "Entree"]) == nil, "deux pieces, meme nom")
        #expect(PiecesRouteurs.piece(nom: "HomePod", parmi: []) == nil)
    }

    /// Le choix passe avant le nom ; un choix dont la piece n'est plus dans Maison ne compte pas ; nil
    /// revient a la regle du nom. Par maison.
    @Test func choixAvantLeNom() {
        var p = PiecesRouteurs()
        #expect(p.piece(routeur: "HomePod mini chambre", nom: "HomePod mini chambre", parmi: Self.pieces,
                        domicile: "Maison") == "Chambre")
        p.choisir("Salon", routeur: "HomePod mini chambre", domicile: "Maison")
        #expect(p.piece(routeur: "HomePod mini chambre", nom: "HomePod mini chambre", parmi: Self.pieces,
                        domicile: "Maison") == "Salon")
        #expect(p.piece(routeur: "HomePod mini chambre", nom: "HomePod mini chambre", parmi: Self.pieces,
                        domicile: "Chalet") == "Chambre", "une autre maison")
        #expect(p.piece(routeur: "HomePod mini chambre", nom: "HomePod mini chambre", parmi: ["Chambre"],
                        domicile: "Maison") == "Chambre", "le salon n'est plus dans Maison")
        p.choisir(nil, routeur: "HomePod mini chambre", domicile: "Maison")
        #expect(p == PiecesRouteurs())
    }

    /// Pieces de Maison : celles des accessoires et celles des zones, sans doublon ni nom vide.
    @Test func piecesDeLaMaison() {
        let maison = NomsMaison(date: Date(timeIntervalSince1970: 1_790_000_000), accessoires: [
            AccessoireMaison(nom: "Lampe", piece: "Salon"), AccessoireMaison(nom: "Prise", piece: ""),
            AccessoireMaison(nom: "Pont"),
        ], zones: [ZoneMaison(nom: "Étage", pieces: ["Chambre", "Salon"])])
        #expect(PiecesRouteurs.pieces(de: maison) == ["Chambre", "Salon"])
        #expect(PiecesRouteurs.pieces(de: nil).isEmpty)
    }

    /// Aller-retour sur disque ; un fichier absent, illisible ou d'une version plus recente donne des
    /// choix vides.
    @Test func allerRetour() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var p = PiecesRouteurs()
        p.choisir("Salon", routeur: "HomePod Palier", domicile: "Maison")
        p.choisir("Bureau", routeur: "Apple TV", domicile: "")
        try p.ecrire(dans: url)
        #expect(PiecesRouteurs.lire(url) == p)
        #expect(PiecesRouteurs.lire(url).choix(routeur: "HomePod Palier", domicile: "Maison") == "Salon")
        #expect(PiecesRouteurs.lire(url.appendingPathExtension("absent")) == PiecesRouteurs())
        try Data(#"{"version":2,"maisons":{}}"#.utf8).write(to: url)
        #expect(PiecesRouteurs.lire(url) == PiecesRouteurs())
        try Data("pas du json".utf8).write(to: url)
        #expect(PiecesRouteurs.lire(url) == PiecesRouteurs())
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/PlacesGardeesTests MaillageCoeurTests/PiecesRouteursTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find 'PlacesGardees' in scope` et `error: cannot find 'PiecesRouteurs' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Scene/PlacesGardees.swift` (fichier entier) :

```swift
import Foundation

/// Places gardees de la vue par pieces (spec de la vue par pieces, section 2.4), dans
/// `positions-pieces.json` : par maison (`domicile` de Maison), l'ordre des etages et, par etage, la
/// place (x, z) de chaque piece deplacee, par rapport au centre du plateau, en unites. Une piece est
/// reconnue par la cle de son etage et la sienne : renommee, ou passee dans un autre etage, elle
/// perd sa place.
public struct PlacesGardees: Hashable, Sendable, Codable {
    public static let versionActuelle = 1

    public struct Place: Hashable, Sendable, Codable {
        public var x: Double
        public var z: Double

        public init(x: Double, z: Double) {
            self.x = x
            self.z = z
        }
    }

    public struct Maison: Hashable, Sendable, Codable {
        /// Cles des etages, du bas vers le haut.
        public var ordreEtages: [String] = []
        /// Cle d'etage -> cle de piece -> place.
        public var etages: [String: [String: Place]] = [:]

        public init(ordreEtages: [String] = [], etages: [String: [String: Place]] = [:]) {
            self.ordreEtages = ordreEtages
            self.etages = etages
        }
    }

    public var version = PlacesGardees.versionActuelle
    /// Par domicile ("" : maison sans nom).
    public var maisons: [String: Maison] = [:]

    public init() {}

    /// Vide si le fichier manque, est illisible, ou d'une version plus recente.
    public static func lire(_ url: URL) -> PlacesGardees {
        guard let d = try? Data(contentsOf: url), let p = try? JSONDecoder().decode(PlacesGardees.self, from: d),
              p.version <= versionActuelle else { return PlacesGardees() }
        return p
    }

    public func ecrire(dans url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try e.encode(self).write(to: url, options: .atomic)
    }

    public func maison(_ domicile: String) -> Maison { maisons[domicile] ?? Maison() }

    /// Garde la place d'une piece deplacee : elle est desormais fixee.
    public mutating func garder(_ place: SIMD2<Double>, piece: String, etage: String, domicile: String) {
        maisons[domicile, default: Maison()].etages[etage, default: [:]][piece] = Place(x: place.x, z: place.y)
    }

    /// Garde l'ordre des etages (cles, du bas vers le haut).
    public mutating func ordonner(_ etages: [String], domicile: String) {
        maisons[domicile, default: Maison()].ordreEtages = etages
    }

    /// « Replacer les pieces automatiquement » : oublie les places de la maison, garde l'ordre des etages.
    public mutating func replacer(domicile: String) {
        maisons[domicile]?.etages = [:]
    }

    /// Pieces fixees d'une scene : indice de piece -> place gardee, pour les pieces qui en ont une dans
    /// leur etage.
    public func fixees(_ scene: ScenePieces, domicile: String) -> [Int: SIMD2<Double>] {
        let m = maison(domicile)
        var r: [Int: SIMD2<Double>] = [:]
        for (i, p) in scene.pieces.enumerated() {
            if let place = m.etages[scene.etages[p.etage].id]?[p.id] { r[i] = SIMD2(place.x, place.z) }
        }
        return r
    }
}
```

`MaillageCoeur/Scene/PiecesRouteurs.swift` (fichier entier) :

```swift
import Foundation

/// Piece d'un routeur de bordure que Maison ne place pas (precisions 23 et 24 du plan 4b) : HomeKit
/// ne donne a une app tierce ni les HomePod ni l'Apple TV, leur annonce n'a donc pas d'accessoire de
/// Maison. Un routeur qui en a un garde sa piece ; pour les autres, dans cet ordre :
/// - **le choix** (« Placer dans une piece… », dans la fiche du routeur), garde par maison
///   (`domicile`) sous l'instance de l'annonce, dans `pieces-routeurs.json` ; un choix dont la piece
///   n'est plus dans Maison ne compte pas ;
/// - **le nom** du routeur, celui qu'affiche l'app (son surnom, sinon son annonce) : la piece de
///   Maison dont le nom y figure, en mots entiers, sans egard a la casse ni aux accents ; le nom de
///   piece le plus long gagne ; si deux pieces ont cette longueur, aucune.
public struct PiecesRouteurs: Hashable, Sendable, Codable {
    public static let versionActuelle = 1

    public var version = PiecesRouteurs.versionActuelle
    /// Par domicile ("" : maison sans nom) : instance de l'annonce -> piece choisie.
    public var maisons: [String: [String: String]] = [:]

    public init() {}

    /// Vide si le fichier manque, est illisible, ou d'une version plus recente.
    public static func lire(_ url: URL) -> PiecesRouteurs {
        guard let d = try? Data(contentsOf: url), let p = try? JSONDecoder().decode(PiecesRouteurs.self, from: d),
              p.version <= versionActuelle else { return PiecesRouteurs() }
        return p
    }

    public func ecrire(dans url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try e.encode(self).write(to: url, options: .atomic)
    }

    /// Piece choisie pour un routeur (son instance) ; nil : la regle du nom.
    public func choix(routeur: String, domicile: String) -> String? {
        maisons[domicile]?[routeur]
    }

    /// Garde le choix d'une piece pour un routeur ; nil revient a la regle du nom.
    public mutating func choisir(_ piece: String?, routeur: String, domicile: String) {
        maisons[domicile, default: [:]][routeur] = piece
        if maisons[domicile]?.isEmpty == true { maisons[domicile] = nil }
    }

    /// Piece d'un routeur que Maison ne place pas : son choix, s'il est encore une piece de la maison,
    /// sinon d'apres son nom ; nil : « Sans piece ».
    public func piece(routeur: String, nom: String, parmi pieces: [String], domicile: String) -> String? {
        if let c = choix(routeur: routeur, domicile: domicile), pieces.contains(c) { return c }
        return Self.piece(nom: nom, parmi: pieces)
    }

    /// Piece d'apres un nom : celle dont les mots se suivent dans les siens ; la plus longue (en
    /// caracteres, sans casse ni accents) ; nil sans piece, ou a egalite entre deux pieces.
    public static func piece(nom: String, parmi pieces: [String]) -> String? {
        let motsNom = mots(nom)
        var meilleure: (piece: String, longueur: Int)?
        var egalite = false
        for p in pieces {
            let m = mots(p)
            guard !m.isEmpty, contient(motsNom, m) else { continue }
            let longueur = m.joined(separator: " ").count
            if let b = meilleure, b.longueur > longueur { continue }
            if let b = meilleure, b.longueur == longueur {
                if b.piece != p { egalite = true }
                continue
            }
            meilleure = (p, longueur)
            egalite = false
        }
        return egalite ? nil : meilleure?.piece
    }

    /// Pieces de Maison : celles des accessoires et celles des zones, sans doublon, par nom.
    public static func pieces(de maison: NomsMaison?) -> [String] {
        guard let maison else { return [] }
        var toutes = Set(maison.accessoires.compactMap(\.piece))
        for z in maison.zones ?? [] { toutes.formUnion(z.pieces) }
        return toutes.filter { !$0.isEmpty }.sorted()
    }

    /// Mots d'un nom : suites de lettres ou de chiffres, sans casse ni accents (« Chambre d'amis » :
    /// chambre, d, amis).
    static func mots(_ s: String) -> [String] {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    /// Les mots `m` se suivent dans `nom`.
    private static func contient(_ nom: [String], _ m: [String]) -> Bool {
        guard m.count <= nom.count else { return false }
        return (0...(nom.count - m.count)).contains { Array(nom[$0..<($0 + m.count)]) == m }
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/PlacesGardeesTests MaillageCoeurTests/PiecesRouteursTests`
Expected: `Test run with 9 tests in 2 suites passed` (`PlacesGardeesTests`, `PiecesRouteursTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 312 tests in 32 suites passed` (cœur) et `Test run with 247 tests in 27 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 9 tests et 2 suites de plus pour le cœur, l'app inchangée.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Scene/PlacesGardees.swift MaillageCoeur/Scene/PiecesRouteurs.swift MaillageCoeurTests/PlacesGardeesTests.swift MaillageCoeurTests/PiecesRouteursTests.swift
git commit -m "Garder la place des pieces deplacees, l'ordre des etages et la piece des routeurs d'Apple

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Cœur : la caméra (orbite, projection, envol, vols, zoom, bornes)

**Files:**
- Create: `MaillageCoeur/Scene/CameraScene.swift`
- Test: `MaillageCoeurTests/CameraSceneTests.swift`

**Interfaces:**
- Consumes :
  - `DispositionPieces.centres2D(rayons:)`, `DispositionPieces.esp` (tâche 4), `CartesPieces.px` (tâche 3).
- Produces :
  - `public struct Orbite: Hashable, Sendable` : `cible: SIMD3<Double>`, `distance`, `azimut`, `inclinaison`, `champ` (degrés) ; `init(cible:distance:azimut:inclinaison:champ:)` ; `arriere`, `droite`, `haut`, `oeil` ; `mutating func placer(oeil:cible:)` ; `static func distance(pourHauteur:champ:) -> Double` ;
  - `public struct ProjectionScene: Sendable` : `init(_ o: Orbite, cadre: CGRect)` (le cadre donne le point principal et la focale) ; `static let proche = 0.5` ; `camera(_:)`, `ecran(camera:)`, `ecran(_:) -> CGPoint?`, `profondeur(_:)`, `pxParUnite(_:)`, `polygone(_:) -> [CGPoint]?` et `segment(_:_:)` découpés au plan proche (Sutherland-Hodgman), `polyligne(_:fermee:) -> [[CGPoint]]`, `sol(_ point: CGPoint, hauteur: Double) -> SIMD3<Double>?`, `disque(_:_:) -> CGAffineTransform?` (un disque horizontal projeté), `contourSphere(_:_:) -> CGAffineTransform?` (l'ellipse exacte, par le cône tangent) ;
  - `public struct GeometrieMaison: Hashable, Sendable` : `init(rayons: [Double])` ; `rayons`, `centres2D`, `pasEtage` (1,5 × RMAX), `centreSphere`, `rayonSphere`, `boite` (`Boite` : `x0`, `x1`, `z0`, `z1`), `cible2D` ; `centrePlateau(_ e: Int, _ u: Double) -> SIMD3<Double>` ; `static func hauteurBloc(_ u: Double) -> Double` ; `static let hauteurBloc3D = 2.4`, `bandeNomsEtages` ;
  - `public enum CameraScene` : `champ2D`, `champ3D`, `inclinaison3D`, `orbite3D`, `dureeEnvol` (2,6), `dureeVol` (1,3), `dureeFondu` (0,3), `dureeTour` (120) ; `rampe(_:)` (cubique entrée-sortie) ; `vue2D`, `vue3D`, `vue(_:aspect:u:)`, `champ(_ u:)`, `canonique(_:aspect:u:) -> Orbite`, `bornes(_:aspect:troisD:champ:) -> ClosedRange<Double>`, `zoomer(_:facteur:ancre:bornes:) -> Orbite`, `directionVue(_:troisD:)`, `volVersPiece(_:centre:largeur:profondeur:aspect:troisD:) -> Vol`, `volVersEnsemble(_:_:aspect:u:troisD:) -> Vol` ;
  - `public struct Vol` : `init(depuis:oeil:cible:)`, `orbite(_ q: Double, depuis: Orbite) -> Orbite` ; `public struct Envol` : `init(depuis:t:vers:geometrie:aspect:)`, `pose(_ q: Double, geometrie:aspect:) -> (t: Double, orbite: Orbite)` : l'écart à la pose canonique, pris au départ, s'efface pendant l'envol (pas de saut).

Les sections 4.4 et 7 de la spec, reprises du prototype A. Les tests posent leur propre boîte de cadrage : ils ne dépendent pas de `SceneProjetee` (tâche 8).

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/CameraSceneTests.swift` (fichier entier) :

```swift
import CoreGraphics
import Foundation
import simd
import Testing
@testable import MaillageCoeur

@Suite("Scene : camera, envol, zoom")
struct CameraSceneTests {
    /// La maison de la maquette : deux plateaux, dans une fenetre de 1600 x 972.
    static let geometrie = GeometrieMaison(rayons: [15.2, 16.0])
    static let cadre = CGRect(x: 0, y: 0, width: 1600, height: 972)
    static let aspect = 1600.0 / 972

    static func proche(_ a: CGPoint, _ b: CGPoint, _ e: Double = 1e-6) -> Bool {
        abs(a.x - b.x) < e && abs(a.y - b.y) < e
    }

    /// Vue de dessus, a 10 unites, champ de 90 degres : 30 points par unite ; -z monte a l'ecran.
    /// Le point principal est le centre du cadre, meme decale. Derriere l'oeil : rien.
    @Test func projectionDePointsConnus() throws {
        let o = Orbite(cible: .zero, distance: 10, azimut: 0, inclinaison: 0, champ: 90)
        let p = ProjectionScene(o, cadre: CGRect(x: 0, y: 0, width: 800, height: 600))
        #expect(abs(p.focale - 300) < 1e-9)
        #expect(Self.proche(try #require(p.ecran(.zero)), CGPoint(x: 400, y: 300)))
        #expect(Self.proche(try #require(p.ecran(SIMD3(1, 0, 0))), CGPoint(x: 430, y: 300)))
        #expect(Self.proche(try #require(p.ecran(SIMD3(0, 0, -1))), CGPoint(x: 400, y: 270)))
        #expect(abs(p.pxParUnite(.zero) - 30) < 1e-9)
        #expect(p.ecran(SIMD3(0, 20, 0)) == nil)
        let decale = ProjectionScene(o, cadre: CGRect(x: 100, y: 50, width: 800, height: 600))
        #expect(Self.proche(try #require(decale.ecran(.zero)), CGPoint(x: 500, y: 350)))
        let sol = try #require(decale.sol(CGPoint(x: 530, y: 350), hauteur: 0))
        #expect(abs(sol.x - 1) < 1e-9 && abs(sol.z) < 1e-9)
    }

    /// Debut de l'envol : la vue d'ensemble 2D, la boite de cadrage dans le cadre, marges comprises ;
    /// fin : la sphere cadree, au centre, sur environ 2 / 2,4 de la hauteur.
    @Test func debutEtFinDeLEnvol() throws {
        let g = Self.geometrie
        let e = Envol(depuis: CameraScene.canonique(g, aspect: Self.aspect, u: 0), t: 0, vers: 1, geometrie: g,
                      aspect: Self.aspect)
        let (t0, o0) = e.pose(0, geometrie: g, aspect: Self.aspect)
        #expect(t0 == 0 && o0.champ == 2)
        let p0 = ProjectionScene(o0, cadre: Self.cadre)
        let coins = [SIMD3(g.boite.x0, 0, g.boite.z0), SIMD3(g.boite.x1, 0, g.boite.z1)].compactMap { p0.ecran($0) }
        #expect(coins.count == 2)
        let boite = CGRect(x: coins[0].x, y: coins[0].y, width: 0, height: 0).union(CGRect(origin: coins[1], size: .zero))
        #expect(Self.cadre.contains(boite))
        #expect(boite.width / 1600 > 0.9 || boite.height / 972 > 0.85, "la boite remplit le cadre : \(boite)")
        let (t1, o1) = e.pose(1, geometrie: g, aspect: Self.aspect)
        #expect(t1 == 1 && o1 == CameraScene.canonique(g, aspect: Self.aspect, u: 1))
        let m = try #require(ProjectionScene(o1, cadre: Self.cadre).contourSphere(g.centreSphere, g.rayonSphere))
        let ellipse = CGRect(x: -1, y: -1, width: 2, height: 2).applying(m)
        #expect(Self.cadre.contains(ellipse))
        #expect(ellipse.height / 972 > 0.8 && ellipse.height / 972 < 0.9, "\(ellipse)")
        #expect(abs(ellipse.midX - 800) < 1 && abs(ellipse.midY - 486) < 1)
        let (tm, _) = e.pose(0.5, geometrie: g, aspect: Self.aspect)
        #expect(abs(tm - 0.5) < 1e-12, "rampe cubique : la moitie a mi-temps")
    }

    /// L'envol part de la vue courante, zoomee ou tournee, sans saut, et finit sur la pose canonique.
    @Test func envolSansSaut() {
        let g = Self.geometrie
        var o = CameraScene.canonique(g, aspect: Self.aspect, u: 1)
        o.azimut += 1.3
        o.distance *= 0.6
        o.cible += SIMD3(2, 0, -1)
        let e = Envol(depuis: o, t: 1, vers: 0, geometrie: g, aspect: Self.aspect)
        let (t, debut) = e.pose(0, geometrie: g, aspect: Self.aspect)
        #expect(t == 1)
        #expect(simd_distance(debut.oeil, o.oeil) < 1e-9 && simd_distance(debut.cible, o.cible) < 1e-9)
        #expect(e.pose(1, geometrie: g, aspect: Self.aspect).orbite == CameraScene.canonique(g, aspect: Self.aspect, u: 0))
    }

    /// Le zoom vers le curseur garde le point sous le curseur, a moins de 1e-6 unite, en 2D comme en 3D.
    @Test func zoomVersLeCurseur() throws {
        let g = Self.geometrie
        for u in [0.0, 1.0] {
            let o = CameraScene.canonique(g, aspect: Self.aspect, u: u)
            let curseur = CGPoint(x: 420, y: 610)
            let ancre = try #require(ProjectionScene(o, cadre: Self.cadre).sol(curseur, hauteur: o.cible.y))
            let bornes = CameraScene.bornes(g, aspect: Self.aspect, troisD: u == 1, champ: o.champ)
            let z = CameraScene.zoomer(o, facteur: -0.4, ancre: ancre, bornes: bornes)
            #expect(z.distance < o.distance)
            let apres = try #require(ProjectionScene(z, cadre: Self.cadre).sol(curseur, hauteur: o.cible.y))
            #expect(simd_distance(apres, ancre) < 1e-6, "u = \(u) : \(simd_distance(apres, ancre))")
        }
    }

    /// Bornes du zoom : 3 unites de hauteur de vue a 3 fois la vue d'ensemble en 2D ; 5 unites de
    /// distance a 2,5 fois la vue d'ensemble en 3D.
    @Test func bornesDuZoom() {
        let g = Self.geometrie
        let o2 = CameraScene.canonique(g, aspect: Self.aspect, u: 0)
        let b2 = CameraScene.bornes(g, aspect: Self.aspect, troisD: false, champ: o2.champ)
        #expect(CameraScene.zoomer(o2, facteur: -20, ancre: nil, bornes: b2).distance
                == Orbite.distance(pourHauteur: 3, champ: 2))
        #expect(CameraScene.zoomer(o2, facteur: 20, ancre: nil, bornes: b2).distance
                == Orbite.distance(pourHauteur: CameraScene.vue2D(g, aspect: Self.aspect) * 3, champ: 2))
        let o3 = CameraScene.canonique(g, aspect: Self.aspect, u: 1)
        let b3 = CameraScene.bornes(g, aspect: Self.aspect, troisD: true, champ: o3.champ)
        #expect(CameraScene.zoomer(o3, facteur: -20, ancre: nil, bornes: b3).distance == 5)
        #expect(abs(CameraScene.zoomer(o3, facteur: 20, ancre: nil, bornes: b3).distance
                    - Orbite.distance(pourHauteur: CameraScene.vue3D(g, aspect: Self.aspect) * 2.5, champ: 40)) < 1e-9)
    }

    /// Vol vers une piece : la cible au centre de la piece, a la hauteur de vue
    /// max(largeur / aspect, profondeur) 1,3 1,8 + 6 ; il part de la camera, sans saut.
    @Test func volVersUnePiece() {
        let o = CameraScene.canonique(Self.geometrie, aspect: Self.aspect, u: 0)
        let centre = SIMD3(-12.0, 0.5, 3.0)
        let v = CameraScene.volVersPiece(o, centre: centre, largeur: 8.75, profondeur: 9.3, aspect: Self.aspect,
                                         troisD: false)
        let debut = v.orbite(0, depuis: o)
        #expect(simd_distance(debut.oeil, o.oeil) < 1e-9 && simd_distance(debut.cible, o.cible) < 1e-9)
        let fin = v.orbite(1, depuis: o)
        #expect(simd_distance(fin.cible, centre) < 1e-9)
        let attendue = Orbite.distance(pourHauteur: max(8.75 / Self.aspect, 9.3) * 1.3 * 1.8 + 6, champ: 2)
        #expect(abs(fin.distance - attendue) < 1e-6)
        #expect(fin.champ == o.champ)
    }

    /// Geometrie : plateaux empiles de 1,5 fois le plus grand rayon ; sphere et boite de la spec.
    @Test func geometrie() {
        let g = Self.geometrie
        #expect(g.pasEtage == 24)
        #expect(g.centreSphere == SIMD3(0, (24 + 2.4) / 2, 0))
        #expect(abs(g.rayonSphere - (hypot(16.8, 13.2 + 1.4) + 0.4)) < 1e-12)
        #expect(g.centrePlateau(1, 1) == SIMD3(0, 24, 0))
        #expect(g.centrePlateau(0, 0).x == g.centres2D[0])
        #expect(abs(g.boite.z0 - (-16 - 34.0 / 24)) < 1e-12 && g.boite.z1 == 16)
        #expect(GeometrieMaison.hauteurBloc(0) == 0.04 && abs(GeometrieMaison.hauteurBloc(1) - 2.44) < 1e-12)
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/CameraSceneTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find 'GeometrieMaison' in scope` et `error: cannot find 'Orbite' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Scene/CameraScene.swift` (fichier entier) :

```swift
import CoreGraphics
import Foundation
import simd

/// Camera en orbite autour de sa cible (spec de la vue par pieces, section 7) : distance, azimut
/// (autour de y, 0 quand l'oeil est du cote +z), inclinaison depuis la verticale, champ vertical en
/// degres. L'axe y monte.
public struct Orbite: Hashable, Sendable {
    public var cible: SIMD3<Double>
    public var distance: Double
    public var azimut: Double
    public var inclinaison: Double
    public var champ: Double

    public init(cible: SIMD3<Double>, distance: Double, azimut: Double, inclinaison: Double, champ: Double) {
        self.cible = cible
        self.distance = distance
        self.azimut = azimut
        self.inclinaison = inclinaison
        self.champ = champ
    }

    /// De la cible vers l'oeil : l'axe z de la camera (elle regarde vers -z).
    public var arriere: SIMD3<Double> {
        SIMD3(sin(inclinaison) * sin(azimut), cos(inclinaison), sin(inclinaison) * cos(azimut))
    }

    /// Axe x de la camera, defini meme a la verticale.
    public var droite: SIMD3<Double> { SIMD3(cos(azimut), 0, -sin(azimut)) }
    public var haut: SIMD3<Double> { simd_cross(arriere, droite) }
    public var oeil: SIMD3<Double> { cible + arriere * distance }

    /// Place l'oeil et la cible (vol de camera) ; l'azimut reste continu.
    public mutating func placer(oeil: SIMD3<Double>, cible c: SIMD3<Double>) {
        let v = oeil - c
        let d = simd_length(v)
        guard d > 1e-9 else { return }
        cible = c
        distance = d
        inclinaison = acos(min(1, max(-1, v.y / d)))
        if abs(v.x) + abs(v.z) > 1e-9 * d {
            let a = atan2(v.x, v.z)
            azimut = a + 2 * .pi * ((azimut - a) / (2 * .pi)).rounded()
        }
    }

    /// Distance a laquelle un champ vertical de `champ` degres couvre `hauteur` unites.
    public static func distance(pourHauteur hauteur: Double, champ: Double) -> Double {
        hauteur / (2 * tan(champ * .pi / 360))
    }
}

/// Projection d'une image : du monde a la camera par une matrice, puis perspective vers l'ecran
/// (points, origine en haut a gauche). Le cadre est la place utile de la vue : son centre est le
/// point principal, sa hauteur regle la focale. Plan proche a 0,5.
public struct ProjectionScene: Sendable {
    public static let proche = 0.5
    public let vue: simd_double4x4
    /// Points par unite a une profondeur de 1.
    public let focale: Double
    public let centre: CGPoint
    let droite, haut, arriere, oeil: SIMD3<Double>

    public init(_ o: Orbite, cadre: CGRect) {
        let x = o.droite, y = o.haut, z = o.arriere, e = o.oeil
        vue = simd_double4x4(rows: [
            SIMD4(x.x, x.y, x.z, -simd_dot(x, e)),
            SIMD4(y.x, y.y, y.z, -simd_dot(y, e)),
            SIMD4(z.x, z.y, z.z, -simd_dot(z, e)),
            SIMD4(0, 0, 0, 1),
        ])
        focale = Double(cadre.height) / 2 / tan(o.champ * .pi / 360)
        centre = CGPoint(x: cadre.midX, y: cadre.midY)
        droite = x
        haut = y
        arriere = z
        oeil = e
    }

    /// Coordonnees camera : x a droite, y en haut, z vers l'arriere (profondeur = -z).
    public func camera(_ p: SIMD3<Double>) -> SIMD3<Double> {
        let v = vue * SIMD4(p.x, p.y, p.z, 1)
        return SIMD3(v.x, v.y, v.z)
    }

    public func ecran(camera q: SIMD3<Double>) -> CGPoint {
        let d = -q.z
        return CGPoint(x: Double(centre.x) + q.x * focale / d, y: Double(centre.y) - q.y * focale / d)
    }

    /// Point de l'ecran, ou nil s'il est derriere le plan proche.
    public func ecran(_ p: SIMD3<Double>) -> CGPoint? {
        let q = camera(p)
        return -q.z >= Self.proche ? ecran(camera: q) : nil
    }

    public func profondeur(_ p: SIMD3<Double>) -> Double { -camera(p).z }

    /// Points de l'ecran par unite du monde, a la profondeur de `p`.
    public func pxParUnite(_ p: SIMD3<Double>) -> Double { focale / max(0.01, profondeur(p)) }

    /// Polygone plan du monde, coupe par le plan proche (Sutherland-Hodgman) ; nil s'il n'en reste rien.
    public func polygone(_ pts: [SIMD3<Double>]) -> [CGPoint]? {
        let q = pts.map(camera)
        var sortie: [SIMD3<Double>] = []
        sortie.reserveCapacity(q.count + 2)
        for i in q.indices {
            let a = q[i], b = q[(i + 1) % q.count]
            let da = -a.z - Self.proche, db = -b.z - Self.proche
            if da >= 0 { sortie.append(a) }
            if (da >= 0) != (db >= 0) { sortie.append(a + (b - a) * (da / (da - db))) }
        }
        return sortie.count >= 3 ? sortie.map { ecran(camera: $0) } : nil
    }

    /// Segment du monde coupe par le plan proche.
    public func segment(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> (CGPoint, CGPoint)? {
        var qa = camera(a), qb = camera(b)
        let da = -qa.z - Self.proche, db = -qb.z - Self.proche
        if da < 0 && db < 0 { return nil }
        if da < 0 {
            qa += (qb - qa) * (da / (da - db))
        } else if db < 0 {
            qb += (qa - qb) * (db / (db - da))
        }
        return (ecran(camera: qa), ecran(camera: qb))
    }

    /// Ligne brisee (fermee ou non), en morceaux devant le plan proche.
    public func polyligne(_ pts: [SIMD3<Double>], fermee: Bool) -> [[CGPoint]] {
        var morceaux: [[CGPoint]] = []
        var courant: [CGPoint] = []
        let n = fermee ? pts.count : pts.count - 1
        for i in 0..<max(0, n) {
            guard let (a, b) = segment(pts[i], pts[(i + 1) % pts.count]) else {
                if !courant.isEmpty { morceaux.append(courant) }
                courant = []
                continue
            }
            if let f = courant.last, abs(f.x - a.x) + abs(f.y - a.y) < 0.01 {
                courant.append(b)
            } else {
                if !courant.isEmpty { morceaux.append(courant) }
                courant = [a, b]
            }
        }
        if !courant.isEmpty { morceaux.append(courant) }
        return morceaux
    }

    /// Point du plan horizontal y = `hauteur` vise par un point de l'ecran ; nil s'il est derriere l'oeil.
    public func sol(_ point: CGPoint, hauteur h: Double) -> SIMD3<Double>? {
        let dir = droite * ((Double(point.x) - Double(centre.x)) / focale)
            + haut * ((Double(centre.y) - Double(point.y)) / focale) - arriere
        guard abs(dir.y) > 1e-12 else { return nil }
        let s = (h - oeil.y) / dir.y
        return s > 0 ? oeil + dir * s : nil
    }

    /// Affine qui envoie le disque unite sur l'ellipse, projetee, d'un disque horizontal (degrade d'un
    /// plateau) ; nil si un point cardinal est derriere l'oeil ou si l'ellipse est plate.
    public func disque(_ c: SIMD3<Double>, _ r: Double) -> CGAffineTransform? {
        guard let o = ecran(c), let xp = ecran(c + SIMD3(r, 0, 0)), let xm = ecran(c - SIMD3(r, 0, 0)),
              let zp = ecran(c + SIMD3(0, 0, r)), let zm = ecran(c - SIMD3(0, 0, r)) else { return nil }
        let m = CGAffineTransform(a: (xp.x - xm.x) / 2, b: (xp.y - xm.y) / 2, c: (zp.x - zm.x) / 2,
                                  d: (zp.y - zm.y) / 2, tx: o.x, ty: o.y)
        return abs(m.a * m.d - m.b * m.c) > 1e-3 ? m : nil
    }

    /// Contour exact d'une sphere en perspective : l'ellipse ou le cone tangent depuis l'oeil coupe le
    /// plan de l'image (un cercle seulement dans l'axe). Rend l'affine qui envoie le disque unite sur
    /// cette ellipse ; nil si l'oeil est dans la sphere ou trop pres d'elle.
    public func contourSphere(_ c: SIMD3<Double>, _ r: Double) -> CGAffineTransform? {
        let q = camera(c)
        let d = simd_length(q)
        guard d > r * 1.0001, -q.z > Self.proche else { return nil }
        let sinA = r / d, cosA = (1 - sinA * sinA).squareRoot()
        let cosT = -q.z / d, sinT = max(0, 1 - cosT * cosT).squareRoot()
        let den = cosT * cosT - sinA * sinA
        guard den > 1e-4 else { return nil }
        let decalage = focale * sinT * cosT / den, a = focale * sinA * cosA / den, b = focale * sinA / den.squareRoot()
        var u = SIMD2(q.x, -q.y)
        u = simd_length(u) > 1e-9 ? simd_normalize(u) : SIMD2(1, 0)
        return CGAffineTransform(a: u.x * a, b: u.y * a, c: -u.y * b, d: u.x * b,
                                 tx: Double(centre.x) + u.x * decalage, ty: Double(centre.y) + u.y * decalage)
    }
}

/// Geometrie de la maison pour la camera (spec, section 4.4) : plateaux cote a cote en 2D, empiles
/// en 3D, sphere de la maison, boite de cadrage de la 2D.
public struct GeometrieMaison: Hashable, Sendable {
    public static let hauteurBloc3D = 2.4
    /// Bande des noms d'etage au-dessus des plateaux, en 2D (34 px).
    public static let bandeNomsEtages = 34 / CartesPieces.px

    public let rayons: [Double]
    public let centres2D: [Double]
    /// Pas entre deux etages en 3D : 1,5 fois le plus grand rayon.
    public let pasEtage: Double
    public let centreSphere: SIMD3<Double>
    public let rayonSphere: Double
    public let boite: Boite
    public let cible2D: SIMD3<Double>

    public struct Boite: Hashable, Sendable {
        public var x0, x1, z0, z1: Double
    }

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
    }

    /// Centre du plateau `e` a l'avancement `u` de la bascule (0 : 2D, 1 : 3D).
    public func centrePlateau(_ e: Int, _ u: Double) -> SIMD3<Double> {
        let a = SIMD3(centres2D[e], 0, 0), b = SIMD3(0, Double(e) * pasEtage, 0)
        return a + (b - a) * u
    }

    /// Hauteur des blocs : 0,04 en 2D, 2,44 en 3D.
    public static func hauteurBloc(_ u: Double) -> Double { 0.04 + hauteurBloc3D * u }
}

/// Camera de la vue (spec, section 7) : vues d'ensemble, envol, vols, zoom vers le curseur, bornes.
public enum CameraScene {
    public static let champ2D = 2.0
    public static let champ3D = 40.0
    public static let inclinaison3D = 0.95
    public static let orbite3D = -0.75
    public static let dureeEnvol = 2.6
    public static let dureeVol = 1.3
    /// « Reduire les animations » : l'envol devient un fondu.
    public static let dureeFondu = 0.3
    /// Rotation lente : un tour en deux minutes.
    public static let dureeTour = 120.0

    /// Rampe de la maquette : cubique entree-sortie.
    public static func rampe(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    /// Hauteur de vue de la vue d'ensemble 2D, centree sur la boite de cadrage.
    public static func vue2D(_ g: GeometrieMaison, aspect: Double) -> Double {
        max((g.boite.z1 - g.boite.z0) * 1.1, (g.boite.x1 - g.boite.x0) * 1.05 / aspect)
    }

    /// Hauteur de vue de la vue d'ensemble 3D, centree sur la sphere.
    public static func vue3D(_ g: GeometrieMaison, aspect: Double) -> Double {
        2.4 * g.rayonSphere * max(1, 1 / aspect)
    }

    public static func vue(_ g: GeometrieMaison, aspect: Double, u: Double) -> Double {
        vue2D(g, aspect: aspect) + (vue3D(g, aspect: aspect) - vue2D(g, aspect: aspect)) * u
    }

    /// Champ a l'avancement u de la bascule : 2 + 38 u^1,6 degres.
    public static func champ(_ u: Double) -> Double { champ2D + (champ3D - champ2D) * pow(u, 1.6) }

    /// Pose canonique a l'avancement u de la bascule : vue d'ensemble 2D (u = 0), 3D (u = 1).
    public static func canonique(_ g: GeometrieMaison, aspect: Double, u: Double) -> Orbite {
        let f = champ(u)
        return Orbite(cible: g.cible2D + (g.centreSphere - g.cible2D) * u,
                      distance: Orbite.distance(pourHauteur: vue(g, aspect: aspect, u: u), champ: f),
                      azimut: orbite3D * u, inclinaison: 0.0001 + inclinaison3D * u, champ: f)
    }

    /// Bornes de la distance : de 3 unites de hauteur de vue a 3 fois la vue d'ensemble en 2D ; de 5
    /// unites a 2,5 fois la vue d'ensemble en 3D.
    public static func bornes(_ g: GeometrieMaison, aspect: Double, troisD: Bool, champ: Double) -> ClosedRange<Double> {
        if troisD {
            return 5...max(5, Orbite.distance(pourHauteur: vue3D(g, aspect: aspect) * 2.5, champ: champ))
        }
        let bas = Orbite.distance(pourHauteur: 3, champ: champ)
        return bas...max(bas, Orbite.distance(pourHauteur: vue2D(g, aspect: aspect) * 3, champ: champ))
    }

    /// Zoom d'un pas (`facteur` : log du rapport des distances), borne ; vers `ancre` si elle est donnee
    /// (le point du monde sous le curseur, qui reste sous le curseur).
    public static func zoomer(_ o: Orbite, facteur: Double, ancre: SIMD3<Double>?, bornes: ClosedRange<Double>) -> Orbite {
        var r = o
        let d = min(bornes.upperBound, max(bornes.lowerBound, o.distance * exp(facteur)))
        if let a = ancre { r.cible = a + (o.cible - a) * (d / o.distance) }
        r.distance = d
        return r
    }

    /// Direction de l'oeil pour un vol : celle de la camera en 3D, la verticale en 2D.
    public static func directionVue(_ o: Orbite, troisD: Bool) -> SIMD3<Double> {
        troisD ? o.arriere : simd_normalize(SIMD3(0, 1, 0.0001))
    }

    /// Vol vers une piece isolee : hauteur de vue max(largeur / aspect, profondeur) 1,3 1,8 + 6 unites.
    public static func volVersPiece(_ o: Orbite, centre: SIMD3<Double>, largeur: Double, profondeur: Double,
                                    aspect: Double, troisD: Bool) -> Vol {
        let d = Orbite.distance(pourHauteur: max(largeur / aspect, profondeur) * 1.3 * 1.8 + 6, champ: o.champ)
        return Vol(depuis: o, oeil: centre + directionVue(o, troisD: troisD) * d, cible: centre)
    }

    /// Vol de retour a la vue d'ensemble, a l'avancement u de la bascule.
    public static func volVersEnsemble(_ o: Orbite, _ g: GeometrieMaison, aspect: Double, u: Double, troisD: Bool) -> Vol {
        let c = g.cible2D + (g.centreSphere - g.cible2D) * u
        let d = Orbite.distance(pourHauteur: vue(g, aspect: aspect, u: u), champ: o.champ)
        return Vol(depuis: o, oeil: c + directionVue(o, troisD: troisD) * d, cible: c)
    }
}

/// Vol de camera (isolement d'une piece, retour a la maison) : oeil et cible interpoles, en rampe.
public struct Vol: Hashable, Sendable {
    public var oeil0, cible0, oeil1, cible1: SIMD3<Double>

    public init(depuis o: Orbite, oeil: SIMD3<Double>, cible: SIMD3<Double>) {
        oeil0 = o.oeil
        cible0 = o.cible
        oeil1 = oeil
        cible1 = cible
    }

    /// Camera a l'avancement q (0 a 1, en temps) du vol.
    public func orbite(_ q: Double, depuis o: Orbite) -> Orbite {
        let e = CameraScene.rampe(min(1, max(0, q)))
        var r = o
        r.placer(oeil: oeil0 + (oeil1 - oeil0) * e, cible: cible0 + (cible1 - cible0) * e)
        return r
    }
}

/// Envol entre la 2D et la 3D (spec, section 7) : 2,6 s en rampe cubique ; il part de la vue
/// courante, zoomee ou tournee, sans saut : l'ecart a la pose canonique s'efface pendant l'envol.
public struct Envol: Hashable, Sendable {
    public var depart: Double
    public var arrivee: Double
    public var ecartCible: SIMD3<Double>
    public var ecartLogDistance: Double
    public var ecartAzimut: Double
    public var ecartInclinaison: Double

    public init(depuis o: Orbite, t: Double, vers arrivee: Double, geometrie g: GeometrieMaison, aspect: Double) {
        let c = CameraScene.canonique(g, aspect: aspect, u: t)
        depart = t
        self.arrivee = arrivee
        ecartCible = o.cible - c.cible
        ecartLogDistance = log(o.distance / c.distance)
        ecartAzimut = remainder(o.azimut - c.azimut, 2 * .pi)
        ecartInclinaison = o.inclinaison - c.inclinaison
    }

    /// Avancement t de la bascule et camera, a l'avancement q (0 a 1, en temps) de l'envol.
    public func pose(_ q: Double, geometrie g: GeometrieMaison, aspect: Double) -> (t: Double, orbite: Orbite) {
        let e = CameraScene.rampe(min(1, max(0, q)))
        let t = depart + (arrivee - depart) * e
        var o = CameraScene.canonique(g, aspect: aspect, u: t)
        let r = 1 - e
        o.cible += ecartCible * r
        o.distance *= exp(ecartLogDistance * r)
        o.azimut += ecartAzimut * r
        o.inclinaison += ecartInclinaison * r
        return (t, o)
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/CameraSceneTests`
Expected: `Test run with 7 tests in 1 suite passed` (`CameraSceneTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 319 tests in 33 suites passed` (cœur) et `Test run with 247 tests in 27 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 7 tests et 1 suite de plus pour le cœur, l'app inchangée.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Scene/CameraScene.swift MaillageCoeurTests/CameraSceneTests.swift
git commit -m "Ajouter la camera de la vue par pieces : orbite, envol, vols, zoom

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: Cœur : le placement des noms et le zoom sémantique

**Files:**
- Create: `MaillageCoeur/Scene/PlacementNoms.swift`
- Test: `MaillageCoeurTests/PlacementNomsTests.swift`

**Interfaces:**
- Consumes :
  - `ScenePieces` (tâche 2), `CameraScene.rampe` (tâche 6) ; dans les tests, `ScenePiecesTests.graphe(sonde:)`, `Compilation.optimisee` (tâche 4).
- Produces :
  - `public enum NiveauZoom: Int` : `pieces`, `routeurs`, `tous` ; `init(echelle k: Double)` (seuils 0,42 et 0,6) ;
  - `public struct Candidat` (`dx`, `dy`, `ecart`, `anneau`) ; `public enum Candidats` : `anneaux`, `appareil`, `piece`, `etage`, `maison` (l'ordre des places de chaque sorte) ;
  - `public struct Etiquette: Sendable` : `init(_ genre: Genre, taille: CGSize)` ; `Genre` : `.noeud(String)`, `.piece(Int)`, `.etage(Int)`, `.maison`, `.ailleurs(String)` ; `candidats`, `fixe`, `prio`, `voulu`, `pale`, `fort`, `taille`, `place`, `envie`, `vu`, `rect`, `rectAvant`, `immobile` ;
  - `public enum PlacementNoms` : `patience` (0,5 s), `bord` (4), `jeu` (2) ; `Trait` (`depart`, `arrivee`) ; `rect(_:_:_:)`, `chevauche(_:_:)`, `dansCadre(_:_:)` ; `placer(_ etiquettes: inout [Etiquette], ancres: [CGRect?], obstacles: [CGRect], cadre: CGSize, dt: Double) -> [Trait]` ; `regler(_ etiquettes: inout [Etiquette], scene: ScenePieces, niveau: NiveauZoom, survol: String?, selection: String?, focus: Int?, isolee: Bool, fk: [Double], s: Double, t: Double)` ; `masques(_ etiquettes: [Etiquette], ancres: [CGRect?], cadre: CGSize) -> Int` (seuls comptent les noms dont l'objet est dans le cadre).

La section 6 de la spec : placement glouton dans l'espace de l'écran, par priorité croissante, places candidates sur cinq anneaux, stabilité de 0,5 s, traits de rappel dès le deuxième anneau, zoom sémantique. Le placement de 150 noms se mesure en Release, comme la disposition (`tempsDePlacement`, par `outils/mesurer.sh`).

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/PlacementNomsTests.swift` (fichier entier) :

```swift
import CoreGraphics
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Scene : placement des noms et zoom semantique")
struct PlacementNomsTests {
    static let cadre = CGSize(width: 800, height: 600)

    static func noeud(_ id: String, largeur: CGFloat = 80) -> Etiquette {
        Etiquette(.noeud(id), taille: CGSize(width: largeur, height: 15))
    }

    static func pastille(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat = 7) -> CGRect {
        CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
    }

    /// Paires de noms poses (hors noms d'etage) qui se chevauchent a 2 px pres.
    static func chevauchements(_ e: [Etiquette]) -> Int {
        let poses = e.filter { $0.vu && !$0.fixe }
        var n = 0
        for i in poses.indices {
            for j in poses.indices where j > i && PlacementNoms.chevauche(poses[i].rect, poses[j].rect) { n += 1 }
        }
        return n
    }

    /// Quarante noms serres : aucun chevauchement entre noms poses, ni avec une pastille ; tous dans le
    /// cadre ; ceux qui ne trouvent pas de place sont masques et comptes, pas ceux d'un objet hors de
    /// la vue.
    @Test func sansChevauchementDansLeCadre() {
        var e = (0..<40).map { Self.noeud("n\($0)", largeur: 60 + CGFloat($0 % 5) * 10) }
        let ancres: [CGRect?] = (0..<40).map { Self.pastille(380 + CGFloat($0 % 8) * 12, 280 + CGFloat($0 / 8) * 12) }
        let obstacles = ancres.compactMap { $0 }
        _ = PlacementNoms.placer(&e, ancres: ancres, obstacles: obstacles, cadre: Self.cadre, dt: 0)
        #expect(Self.chevauchements(e) == 0)
        let poses = e.filter(\.vu)
        #expect(!poses.isEmpty)
        #expect(poses.allSatisfy { PlacementNoms.dansCadre($0.rect, Self.cadre) })
        #expect(poses.allSatisfy { p in !obstacles.contains { PlacementNoms.chevauche(p.rect, $0) } })
        #expect(PlacementNoms.masques(e, ancres: ancres, cadre: Self.cadre) == 40 - poses.count)
        var hors = [Self.noeud("loin")]
        let loin: [CGRect?] = [Self.pastille(2000, 300)]
        _ = PlacementNoms.placer(&hors, ancres: loin, obstacles: [], cadre: Self.cadre, dt: 0)
        #expect(!hors[0].vu && PlacementNoms.masques(hors, ancres: loin, cadre: Self.cadre) == 0, "hors de la vue")
    }

    /// Priorites : a place egale, la plus forte (le plus petit nombre) passe d'abord et prend la
    /// premiere place ; un nom d'etage (fixe) se pose meme sur un obstacle.
    @Test func prioritesRespectees() {
        var faible = Self.noeud("faible")
        faible.prio = 7
        var fort = Self.noeud("fort")
        fort.prio = 2
        var e = [faible, fort, Etiquette(.etage(0), taille: CGSize(width: 300, height: 15))]
        let a = Self.pastille(300, 300), b = Self.pastille(600, 500)
        _ = PlacementNoms.placer(&e, ancres: [a, a, CGRect(x: 600, y: 520, width: 0, height: 0)], obstacles: [a, b],
                                 cadre: Self.cadre, dt: 0)
        #expect(e[1].place == 0, "le plus fort a droite")
        #expect(e[0].vu && e[0].place == 1, "le plus faible a gauche")
        #expect(e[2].vu && e[2].place == 0 && PlacementNoms.chevauche(e[2].rect, b), "etage : pose sur la pastille")
    }

    /// Stabilite : un nom deplace par un obstacle garde sa nouvelle place tant qu'elle est libre ; il
    /// ne revient a sa place preferee qu'apres l'avoir trouvee libre 0,5 s.
    @Test func stabilite() {
        var e = [Self.noeud("n")]
        let a = Self.pastille(400, 300)
        let droite = PlacementNoms.rect(e[0].taille, a, Candidats.appareil[0])
        _ = PlacementNoms.placer(&e, ancres: [a], obstacles: [droite], cadre: Self.cadre, dt: 0.1)
        #expect(e[0].place == 1, "a gauche : la droite est prise")
        for _ in 0..<4 {
            _ = PlacementNoms.placer(&e, ancres: [a], obstacles: [], cadre: Self.cadre, dt: 0.1)
            #expect(e[0].place == 1, "moins de 0,5 s : il reste")
        }
        _ = PlacementNoms.placer(&e, ancres: [a], obstacles: [], cadre: Self.cadre, dt: 0.1)
        #expect(e[0].place == 0, "0,5 s : il rejoint sa place")
        #expect(e[0].envie == 0)
    }

    /// Trait de rappel des le deuxieme anneau ; un nom immobile d'une image a l'autre.
    @Test func traitsEtImmobilite() {
        var e = [Self.noeud("n")]
        let a = Self.pastille(400, 300)
        let premier = Candidats.appareil.prefix(8).map { PlacementNoms.rect(e[0].taille, a, $0) }
        let traits = PlacementNoms.placer(&e, ancres: [a], obstacles: premier, cadre: Self.cadre, dt: 0)
        #expect(e[0].vu && e[0].place >= 8)
        #expect(traits.count == 1)
        _ = PlacementNoms.placer(&e, ancres: [a], obstacles: premier, cadre: Self.cadre, dt: 0.1)
        #expect(e[0].immobile)
    }

    /// Seuils du zoom semantique : sous 0,42 les pieces seules, jusqu'a 0,6 les routeurs en plus, puis
    /// tous ; le survol montre toujours le nom survole ; en piece isolee, tous les noms de la piece.
    @Test func seuilsDuZoomSemantique() throws {
        #expect(NiveauZoom(echelle: 0.41) == .pieces)
        #expect(NiveauZoom(echelle: 0.42) == .routeurs)
        #expect(NiveauZoom(echelle: 0.59) == .routeurs)
        #expect(NiveauZoom(echelle: 0.6) == .tous)
        let g = try ScenePiecesTests.graphe(sonde: true)
        let s = ScenePieces(graphe: g, libelles: ScenePiecesTests.libelles, piecesNoeuds: ["Apple TV": "Salon"], zones: nil,
                            chefs: ["Apple TV"], piecesMaison: true)
        var e = s.noeuds.map { Etiquette(.noeud($0.id), taille: CGSize(width: 50, height: 15)) }
        e.append(Etiquette(.piece(0), taille: CGSize(width: 90, height: 20)))
        func voulus(_ niveau: NiveauZoom, survol: String? = nil) -> Set<String> {
            PlacementNoms.regler(&e, scene: s, niveau: niveau, survol: survol, selection: nil, focus: nil, isolee: false,
                                 fk: Array(repeating: 0, count: s.pieces.count), s: 0, t: 0)
            return Set(e.compactMap { l in
                if case .noeud(let id) = l.genre, l.voulu { return id }
                return nil
            })
        }
        #expect(voulus(.pieces).isEmpty)
        #expect(voulus(.routeurs) == ["Apple TV", "HomePod", "E000000000000004"])
        #expect(voulus(.tous).count == s.noeuds.count)
        #expect(voulus(.pieces, survol: "E000000000000005") == ["E000000000000005"])
        #expect(e.last?.voulu == true, "les pieces toujours")
        #expect(e.first { $0.genre == .noeud("Apple TV") }?.prio == 5, "chef")
        #expect(e.first { $0.genre == .noeud("E000000000000005") }?.prio == 2, "survole")
        let salon = try #require(s.pieces.firstIndex { $0.nom == .maison("Salon") })
        var fk = Array(repeating: 0.0, count: s.pieces.count)
        fk[salon] = 1
        PlacementNoms.regler(&e, scene: s, niveau: .pieces, survol: nil, selection: nil, focus: salon, isolee: true, fk: fk,
                             s: 1, t: 0)
        #expect(e.filter(\.voulu).count == 1 + 1, "l'Apple TV, seul noeud du salon, et le nom de la piece")
    }

    /// Temps de calcul, en Release : le placement de 150 noms tient sous 2 ms (moyenne de 20 images).
    @Test(.enabled(if: Compilation.optimisee, "mesure en Release (outils/mesurer.sh)"))
    func tempsDePlacement() {
        var e = (0..<150).map { Self.noeud("n\($0)", largeur: 60 + CGFloat($0 % 7) * 12) }
        let ancres: [CGRect?] = (0..<150).map { Self.pastille(60 + CGFloat($0 % 15) * 90, 60 + CGFloat($0 / 15) * 80) }
        let obstacles = ancres.compactMap { $0 }
        let cadre = CGSize(width: 1440, height: 900)
        _ = PlacementNoms.placer(&e, ancres: ancres, obstacles: obstacles, cadre: cadre, dt: 0)
        let debut = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<20 { _ = PlacementNoms.placer(&e, ancres: ancres, obstacles: obstacles, cadre: cadre, dt: 1.0 / 60) }
        let ms = Double(DispatchTime.now().uptimeNanoseconds - debut) / 20 / 1e6
        print("mesure : placement de 150 noms en \(ms) ms, \(e.count { $0.vu }) poses")
        #expect(ms < 2, "\(ms) ms")
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/PlacementNomsTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find type 'Etiquette' in scope` et `error: cannot find 'Etiquette' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Scene/PlacementNoms.swift` (fichier entier) :

```swift
import CoreGraphics
import Foundation

/// Niveau du zoom semantique (spec de la vue par pieces, section 6), selon l'echelle k (points par
/// unite a la cible de la camera, divises par 24) : sous 0,42, les pieces seules ; jusqu'a 0,6, les
/// pieces et les routeurs ; au-dela, tous les noms qui tiennent.
public enum NiveauZoom: Int, Hashable, Sendable {
    case pieces = 0, routeurs = 1, tous = 2

    public init(echelle k: Double) {
        self = k < 0.42 ? .pieces : k < 0.6 ? .routeurs : .tous
    }
}

/// Place candidate d'un nom autour de son objet : une direction (dx, dy), un ecart (px), l'indice
/// de son anneau.
public struct Candidat: Hashable, Sendable {
    public let dx, dy: Int
    public let ecart: Double
    public let anneau: Int
}

/// Places candidates : les anneaux 3, 14, 28, 44 et 62 px autour de l'objet, et sur chacun huit
/// directions dans un ordre propre a chaque genre de nom.
public enum Candidats {
    static let directions = [(0, -1), (1, 0), (-1, 0), (0, 1), (1, -1), (-1, -1), (1, 1), (-1, 1)]
    public static let anneaux: [Double] = [3, 14, 28, 44, 62]

    static func ordre(_ ds: [Int]) -> [Candidat] {
        anneaux.enumerated().flatMap { i, a in
            ds.map { Candidat(dx: directions[$0].0, dy: directions[$0].1, ecart: a, anneau: i) }
        }
    }

    /// Droite, gauche, haut, bas, puis les diagonales.
    public static let appareil = ordre([1, 2, 0, 3, 4, 6, 5, 7])
    /// Haut, bas, droite, gauche, puis les diagonales.
    public static let piece = ordre([0, 3, 1, 2, 4, 5, 6, 7])
    /// Haut, bas, droite, gauche.
    public static let etage = ordre([0, 3, 1, 2])
    /// Bas, droite, gauche, haut.
    public static let maison = ordre([3, 1, 2, 0])
}

/// Un nom et son etat de placement, garde d'une image a l'autre (stabilite).
public struct Etiquette: Sendable {
    public enum Genre: Hashable, Sendable {
        case noeud(String)
        case piece(Int)
        case etage(Int)
        case maison
        /// Repere « ailleurs » de la piece isolee, par l'id de l'enfant.
        case ailleurs(String)
    }

    public let genre: Genre
    public let candidats: [Candidat]
    /// Les noms d'etage sont poses meme s'ils chevauchent.
    public let fixe: Bool
    public var prio: Int
    public var voulu = true
    /// Piece estompee : son nom en pale.
    public var pale = false
    /// Survol ou selection : semi-gras.
    public var fort = false
    public var taille: CGSize
    /// Place retenue (indice du candidat) ; -1 : masque.
    public var place = -1
    /// Temps passe a garder l'ancienne place alors qu'une meilleure est libre (s).
    public var envie = 0.0
    public var vu = false
    public var rect = CGRect.zero
    /// Place de l'image precedente (`CGRect.null` si le nom n'etait pas vu).
    public var rectAvant = CGRect.null

    public init(_ genre: Genre, taille: CGSize) {
        self.genre = genre
        self.taille = taille
        switch genre {
        case .noeud:
            candidats = Candidats.appareil
            fixe = false
            prio = 7
        case .piece:
            candidats = Candidats.piece
            fixe = false
            prio = 4
        case .etage:
            candidats = Candidats.etage
            fixe = true
            prio = 1
        case .maison:
            candidats = Candidats.maison
            fixe = false
            prio = 0
        case .ailleurs:
            candidats = Candidats.appareil
            fixe = false
            prio = 3
        }
    }

    /// Le nom n'a pas bouge depuis l'image precedente : il s'aligne sur les pixels.
    public var immobile: Bool {
        rectAvant.isNull || (abs(rect.minX - rectAvant.minX) < 0.01 && abs(rect.minY - rectAvant.minY) < 0.01)
    }
}

/// Placement glouton des noms, dans l'espace de l'ecran (spec, section 6).
public enum PlacementNoms {
    /// Temps pendant lequel une meilleure place doit rester libre avant qu'un nom la rejoigne (s).
    public static let patience = 0.5
    /// Marge des noms au bord du cadre, et jeu entre deux rectangles (px).
    public static let bord: CGFloat = 4
    public static let jeu: CGFloat = 2

    /// Trait de rappel d'un nom ecarte de son objet : de l'objet au nom.
    public struct Trait: Hashable, Sendable {
        public var depart: CGPoint
        public var arrivee: CGPoint
    }

    /// Rectangle d'un nom de taille `taille` pose au candidat `c` autour de l'ancre `a` ; une
    /// diagonale se place a 0,7 fois l'anneau.
    public static func rect(_ taille: CGSize, _ a: CGRect, _ c: Candidat) -> CGRect {
        let m = c.dx != 0 && c.dy != 0 ? c.ecart * 0.7 : c.ecart
        let w = taille.width, h = taille.height
        let x = c.dx > 0 ? a.maxX + m : c.dx < 0 ? a.minX - m - w : a.midX - w / 2
        let y = c.dy > 0 ? a.maxY + m : c.dy < 0 ? a.minY - m - h : a.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Deux rectangles a moins de `jeu` l'un de l'autre.
    public static func chevauche(_ r: CGRect, _ q: CGRect) -> Bool {
        r.minX - jeu < q.maxX && q.minX - jeu < r.maxX && r.minY - jeu < q.maxY && q.minY - jeu < r.maxY
    }

    public static func dansCadre(_ r: CGRect, _ t: CGSize) -> Bool {
        r.minX >= bord && r.minY >= bord && r.maxX <= t.width - bord && r.maxY <= t.height - bord
    }

    /// Pose les noms par priorite croissante (puis dans leur ordre) : chacun prend la premiere place
    /// candidate dans le cadre qui ne chevauche ni un nom deja pose, ni un obstacle (pastilles,
    /// interface) ; un nom d'etage (`fixe`) est pose meme s'il chevauche. Un nom garde sa place tant
    /// qu'elle reste libre, et ne rejoint une meilleure qu'apres l'avoir trouvee libre `patience`
    /// secondes ; sans place, il est masque. Rend le trait de rappel de chaque nom pose des le
    /// deuxieme anneau. `ancres` : l'objet de chaque nom, a l'ecran (nil : pas a l'ecran) ; `dt` :
    /// temps depuis l'image precedente.
    public static func placer(_ etiquettes: inout [Etiquette], ancres: [CGRect?], obstacles: [CGRect], cadre: CGSize,
                              dt: Double) -> [Trait] {
        var pris = obstacles
        var traits: [Trait] = []
        let ordre = etiquettes.indices.sorted { (etiquettes[$0].prio, $0) < (etiquettes[$1].prio, $1) }
        for j in ordre {
            var l = etiquettes[j]
            defer { etiquettes[j] = l }
            guard l.voulu, j < ancres.count, let a = ancres[j] else {
                l.vu = false
                l.place = -1
                l.envie = 0
                continue
            }
            func libre(_ k: Int) -> CGRect? {
                let r = rect(l.taille, a, l.candidats[k])
                return dansCadre(r, cadre) && (l.fixe || !pris.contains { chevauche(r, $0) }) ? r : nil
            }
            var k = -1
            var r = CGRect.zero
            for c in l.candidats.indices {
                if let q = libre(c) {
                    k = c
                    r = q
                    break
                }
            }
            guard k >= 0 else {
                l.vu = false
                l.place = -1
                l.envie = 0
                continue
            }
            if l.place >= 0 && l.place != k, let q = libre(l.place), l.envie + dt < patience {
                l.envie += max(dt, 1e-3)
                k = l.place
                r = q
            } else {
                l.envie = 0
            }
            l.place = k
            l.rectAvant = l.vu ? l.rect : .null
            l.vu = true
            l.rect = r
            pris.append(r)
            if l.candidats[k].anneau > 0 {
                let px = min(max(r.midX, a.minX), a.maxX), py = min(max(r.midY, a.minY), a.maxY)
                traits.append(Trait(depart: CGPoint(x: px, y: py),
                                    arrivee: CGPoint(x: min(max(px, r.minX), r.maxX), y: min(max(py, r.minY), r.maxY))))
            }
        }
        return traits
    }

    /// Zoom semantique et priorites (spec, section 6) : noms voulus, priorites, pales et forts, selon
    /// le niveau du zoom, le survol, la selection et l'isolement d'une piece. `fk` : part propre a
    /// chaque piece de l'isolement ; `s` : isolement general (0 a 1) ; `t` : bascule (0 : 2D, 1 : 3D).
    public static func regler(_ etiquettes: inout [Etiquette], scene: ScenePieces, niveau: NiveauZoom,
                              survol: String?, selection: String?, focus: Int?, isolee: Bool, fk: [Double],
                              s: Double, t: Double) {
        let fo = 1 - CameraScene.rampe(s)
        for j in etiquettes.indices {
            switch etiquettes[j].genre {
            case .noeud(let id):
                guard let n = scene.noeud(id) else {
                    etiquettes[j].voulu = false
                    continue
                }
                let part = n.piece < fk.count ? fk[n.piece] : 0
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
            case .ailleurs:
                etiquettes[j].voulu = focus.map { $0 < fk.count && fk[$0] > 0.6 } ?? false
            }
        }
    }

    /// Noms d'appareils voulus mais masques faute de place : leur objet est dans le cadre (un appareil
    /// hors de la vue, apres un zoom, ne compte pas).
    public static func masques(_ etiquettes: [Etiquette], ancres: [CGRect?], cadre: CGSize) -> Int {
        let vue = CGRect(origin: .zero, size: cadre)
        return etiquettes.indices.count { j in
            guard case .noeud = etiquettes[j].genre, etiquettes[j].voulu, !etiquettes[j].vu,
                  j < ancres.count, let a = ancres[j] else { return false }
            return vue.intersects(a)
        }
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/PlacementNomsTests`
Expected: `Test run with 6 tests in 1 suite passed` (`PlacementNomsTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les temps, en Release.** Le placement de 150 noms doit tenir sous 2 ms (moyenne de 20 images), et la disposition toujours sous 1 s.

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/mesurer.sh`
Expected: `mesure : disposition de la grande maison en 0.254607333 s, 3000 coups` et `mesure : placement de 150 noms en 0.308475 ms, 150 poses` (ce temps-ci au rejeu, qui varie d'une machine à l'autre ; les coups, non), puis `Test run with 13 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 325 tests in 34 suites passed` (cœur) et `Test run with 247 tests in 27 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 6 tests et 1 suite de plus pour le cœur, l'app inchangée. En Debug, `tempsDePlacement` est sauté, comme `tempsGrandeMaison`.

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Scene/PlacementNoms.swift MaillageCoeurTests/PlacementNomsTests.swift
git commit -m "Placer les noms de la vue par pieces et regler le zoom semantique

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 8: Cœur : la projection vers le moteur (`SceneProjetee`)

**Files:**
- Create: `MaillageCoeur/Scene/SceneProjetee.swift`
- Test: `MaillageCoeurTests/SceneProjeteeTests.swift`

**Interfaces:**
- Consumes :
  - `ScenePieces` (tâche 2), `CartesPieces` (tâche 3), `DispositionPieces` (tâche 4), `Orbite`, `ProjectionScene`, `GeometrieMaison`, `CameraScene` (tâche 6), `NiveauZoom` (tâche 7).
- Produces :
  - `public struct Teinte` (`r`, `g`, `b` en sRGB, `init(hexa:)`, `eclairee(_:)` : le facteur de Lambert appliqué en linéaire) ;
  - `public struct EtatAnime` : `t` (bascule, 0 en 2D, 1 en 3D), `s` (isolement), `fk: [Double]` (isolement de chaque pièce), `focus: Int?`, `survol: String?`, `selection: String?` ;
  - `public struct Ailleurs` (`enfant`, `parent`, `piece`, `etage`, `sens` : `.memeEtage`, `.dessous`, `.dessus`) ;
  - `public struct SceneProjetee: Sendable` : `init(scene:cartes:positions:geometrie:etat:orbite:cadre:)` ; `plateaux`, `equateur`, `blocs` (du plus loin au plus proche, faces tournées vers l'œil), `liensEnfants`, `liensRouteurs`, `fils` (repères « ailleurs »), `disques`, `sphere`, `niveau`, `echelle`, `ancresNoeuds`, `ancresPieces`, `ancresEtages`, `ancreMaison`, `ancresAilleurs`, `ailleurs`, `centresNoeuds` ; `static let lambert` ; `static func reperes(_ scene: ScenePieces, focus i: Int) -> [Ailleurs]` ; `piece(sous:) -> Int?`, `noeud(sous:marge:) -> String?` ; `static func contient(_:_:)`, `static func boite(_:)`.

Le contrat entre la scène et le moteur (spec, sections 5 et 9) : tout ce que le `Canvas` dessine, en coordonnées de l'écran, avec couleurs et opacités ; ce qui est sous le curseur ; les ancres des noms. L'éclairage des faces (`(2,2 + 1,6·n·l)/π`, lumière de `(−10, 30, 14)`), le disque des plateaux et le dégradé de la sphère viennent du prototype A.

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/SceneProjeteeTests.swift` (fichier entier) :

```swift
import CoreGraphics
import Foundation
import simd
import Testing
@testable import MaillageCoeur

@Suite("Scene : projection vers le moteur")
struct SceneProjeteeTests {
    static let cadre = CGRect(x: 0, y: 0, width: 1200, height: 800)

    /// Trois pieces sur deux etages : le salon au rez-de-chaussee (l'Apple TV, E...04, E...05), la
    /// chambre (le HomePod) et le bureau (E...02, enfant de l'Apple TV ; E...03, enfant du HomePod) a
    /// l'etage. Liens de la sonde : Apple TV - HomePod et Apple TV - E...04 (radio), E...02 et E...03
    /// vers leur parent ; E...05, rattache au centre.
    static func scene() throws -> (ScenePieces, [CartesPieces.Carte], DispositionPieces, GeometrieMaison) {
        let pieces = ["Apple TV": "Salon", "HomePod": "Chambre", "E000000000000002": "Bureau",
                      "E000000000000003": "Bureau", "E000000000000004": "Salon", "E000000000000005": "Salon"]
        let zones = [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon"]), ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau"])]
        let s = ScenePieces(graphe: try ScenePiecesTests.graphe(sonde: true), libelles: ScenePiecesTests.libelles,
                            piecesNoeuds: pieces, zones: zones, chefs: ["Apple TV"], piecesMaison: true)
        let c = CartesPieces.cartes(s, largeurs: [:])
        let d = DispositionPieces(scene: s, cartes: c)
        return (s, c, d, GeometrieMaison(rayons: d.rayons))
    }

    static func projeter(t: Double, _ etat: (inout EtatAnime) -> Void = { _ in }) throws
        -> (ScenePieces, SceneProjetee) {
        let (s, c, d, g) = try Self.scene()
        var e = EtatAnime(t: t, fk: Array(repeating: 0, count: s.pieces.count))
        etat(&e)
        let o = CameraScene.canonique(g, aspect: 1.5, u: t)
        return (s, SceneProjetee(scene: s, cartes: c, positions: d.positions, geometrie: g, etat: e, orbite: o, cadre: Self.cadre))
    }

    static func indice(_ s: ScenePieces, _ nom: String) throws -> Int {
        try #require(s.pieces.firstIndex { $0.nom == .maison(nom) })
    }

    /// En 2D : les plateaux, le dessus de chaque bloc (et au plus deux cotes, vus par la tranche), ni
    /// sphere ni equateur ; les ancres de tous les noms ; les liens entre routeurs a part des autres.
    @Test func vueDeDessus() throws {
        let (s, p) = try Self.projeter(t: 0)
        #expect(p.plateaux.count == 2)
        #expect(p.blocs.count == 3 && p.blocs.allSatisfy { !$0.faces.isEmpty && $0.faces.count <= 3 })
        #expect(p.sphere == nil && p.equateur == nil)
        #expect(p.ancresNoeuds.count == s.noeuds.count && p.ancresPieces.count == 3 && p.ancresEtages.count == 2)
        #expect(p.ancreMaison != nil)
        #expect(p.liensRouteurs.count == 2 && p.liensEnfants.count == 3)
        #expect(p.liensEnfants.filter { $0.genre == .rattachement }.count == 1)
        #expect(p.disques.count == s.noeuds.count)
        #expect(zip(p.disques, p.disques.dropFirst()).allSatisfy { $0.profondeur >= $1.profondeur })
        #expect(p.blocs.allSatisfy { abs($0.opaciteVerre - 0.13) < 1e-12 && abs($0.opaciteAretes - 0.75) < 1e-12 })
    }

    /// En 3D : la sphere et son equateur ; plusieurs faces par bloc ; les blocs du plus loin au plus proche.
    @Test func vueEn3D() throws {
        let (_, p) = try Self.projeter(t: 1)
        #expect(p.sphere != nil && p.equateur != nil)
        #expect(p.blocs.allSatisfy { $0.faces.count >= 2 && $0.faces.count <= 3 })
        #expect(zip(p.blocs, p.blocs.dropFirst()).allSatisfy { $0.profondeur >= $1.profondeur })
        #expect(p.blocs.allSatisfy { abs($0.opaciteVerre - 0.18) < 1e-12 })
    }

    /// Clic et survol : la piece et le noeud sous le curseur ; rien sur le fond.
    @Test func sousLeCurseur() throws {
        let (s, p) = try Self.projeter(t: 0)
        for (i, a) in p.ancresPieces {
            let coin = CGPoint(x: a.minX + 2, y: a.maxY - 2)
            #expect(p.piece(sous: coin) == i, "\(s.pieces[i].id)")
        }
        for d in p.disques { #expect(p.noeud(sous: d.centre) == d.noeud) }
        #expect(p.piece(sous: CGPoint(x: 3, y: 3)) == nil && p.noeud(sous: CGPoint(x: 3, y: 3)) == nil)
    }

    /// Piece isolee (le bureau) : les autres s'estompent a 15 % ; un repere « ailleurs » par enfant dont
    /// le parent est dans une autre piece, avec son sens (meme etage, dessous) et son fil.
    @Test func pieceIsolee() throws {
        let (s0, _) = try Self.projeter(t: 0)
        let bureau = try Self.indice(s0, "Bureau")
        let (s, p) = try Self.projeter(t: 0) { e in
            e.s = 1
            e.focus = bureau
            e.fk[bureau] = 1
        }
        let reperes = p.ailleurs.sorted { $0.enfant < $1.enfant }
        let salon = try Self.indice(s, "Salon"), chambre = try Self.indice(s, "Chambre")
        #expect(reperes.map(\.parent) == ["Apple TV", "HomePod"])
        #expect(reperes[0].sens == .dessous && reperes[0].piece == salon)
        #expect(reperes[1].sens == .memeEtage && reperes[1].piece == chambre)
        #expect(p.fils.count == 2 && p.fils.allSatisfy { abs($0.opacite - 0.8) < 1e-12 })
        #expect(p.ancresAilleurs.count == 2)
        for b in p.blocs {
            let attendue = b.piece == bureau ? 0.13 : 0.15 * 0.13
            #expect(abs(b.opaciteVerre - attendue) < 1e-12)
        }
        #expect(p.plateaux.allSatisfy { $0.opacite == 0 })
    }

    /// Survol d'un appareil : ses liens enfant-parent s'eclairent a 0,85 ; les autres restent a 0,28.
    @Test func survol() throws {
        let (_, p) = try Self.projeter(t: 0) { $0.survol = "E000000000000002" }
        let eclaires = p.liensEnfants.filter(\.eclaire)
        #expect(eclaires.count == 1 && abs(eclaires[0].opacite - 0.85) < 1e-12)
        #expect(p.liensEnfants.filter { !$0.eclaire }.allSatisfy { abs($0.opacite - 0.28) < 1e-12 })
        #expect(p.liensRouteurs.allSatisfy { abs($0.opacite - 0.95) < 1e-12 && !$0.eclaire })
    }

    /// Eclairage des faces : (2,2 + 1,6 n.l) / pi, en lineaire ; un facteur 1 ne change rien.
    @Test func eclairage() {
        let l = simd_normalize(SIMD3<Double>(-10, 30, 14))
        #expect(abs(SceneProjetee.lambert[2] - (2.2 + 1.6 * l.y) / .pi) < 1e-12)
        #expect(abs(SceneProjetee.lambert[0] - 2.2 / .pi) < 1e-12, "+x : la lumiere vient de -x")
        let bleu = Teinte(hexa: 0x3B82F5)
        let meme = bleu.eclairee(1)
        #expect(abs(meme.r - bleu.r) < 1e-9 && abs(meme.g - bleu.g) < 1e-9 && abs(meme.b - bleu.b) < 1e-9)
        #expect(bleu.eclairee(0.5).b < bleu.b)
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/SceneProjeteeTests`
Expected: la compilation des tests du cœur échoue, par exemple avec `error: cannot find type 'SceneProjetee' in scope` et `error: cannot find type 'EtatAnime' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Scene/SceneProjetee.swift` (fichier entier) :

```swift
import CoreGraphics
import Foundation
import simd

/// Couleur sRGB, composantes de 0 a 1.
public struct Teinte: Hashable, Sendable {
    public var r, g, b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    public init(hexa v: UInt32) {
        self.init(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255, b: Double(v & 0xFF) / 255)
    }

    /// Eclairee comme dans la maquette : la couleur passe en lineaire, y est multipliee par `k`, puis
    /// revient en sRGB.
    public func eclairee(_ k: Double) -> Teinte {
        func lineaire(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        func srgb(_ c: Double) -> Double {
            let c = min(1, max(0, c))
            return c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
        }
        return Teinte(r: srgb(lineaire(r) * k), g: srgb(lineaire(g) * k), b: srgb(lineaire(b) * k))
    }
}

/// Etat anime de la vue, pose a chaque image : ce que la projection lit en plus de la scene.
public struct EtatAnime: Hashable, Sendable {
    /// Bascule, adoucie : 0 en 2D, 1 en 3D.
    public var t: Double
    /// Isolement general d'une piece : 0 a 1, lineaire (la projection l'adoucit).
    public var s: Double
    /// Part propre a chaque piece de l'isolement : 0 a 1.
    public var fk: [Double]
    /// Piece isolee (ou qui l'etait, pendant le retour).
    public var focus: Int?
    public var survol: String?
    public var selection: String?

    public init(t: Double = 0, s: Double = 0, fk: [Double], focus: Int? = nil, survol: String? = nil,
                selection: String? = nil) {
        self.t = t
        self.s = s
        self.fk = fk
        self.focus = focus
        self.survol = survol
        self.selection = selection
    }
}

/// Repere « ailleurs » d'un enfant de la piece isolee dont le parent est dans une autre piece.
public struct Ailleurs: Hashable, Sendable {
    public enum Sens: Hashable, Sendable {
        /// Parent au meme etage (↗), a un etage en dessous (↓), au-dessus (↑).
        case memeEtage, dessous, dessus
    }

    public var enfant: String
    public var parent: String
    public var piece: Int
    public var etage: Int
    public var sens: Sens
}

/// Ce que la camera rend au moteur `Canvas` (spec, section 9), en coordonnees de l'ecran : le contrat
/// entre la scene et le moteur. Couches, sans tri de profondeur global : plateaux et equateur, blocs
/// (du plus loin au plus proche, faces tournees vers l'oeil), liens enfant-parent (avec les
/// rattachements et les fils « ailleurs »), liens entre routeurs, pastilles, liseré de la sphere ;
/// puis les traits de rappel et les noms, que le moteur pose avec `PlacementNoms`.
public struct SceneProjetee: Sendable {
    public struct Plateau: Sendable {
        public var etage: Int
        public var polygone: [CGPoint]
        public var contour: [[CGPoint]]
        /// Envoie le disque unite sur l'ellipse du plateau (degrade radial) ; nil si degenere.
        public var disque: CGAffineTransform?
        public var opacite: Double
        public var profondeur: Double
    }

    public struct Equateur: Sendable {
        public var contour: [[CGPoint]]
        public var opacite: Double
        public var profondeur: Double
    }

    public struct Face: Sendable {
        public var points: [CGPoint]
        public var teinte: Teinte
    }

    public struct Bloc: Sendable {
        public var piece: Int
        /// Faces tournees vers l'oeil, eclairees.
        public var faces: [Face]
        public var aretes: [(CGPoint, CGPoint)]
        public var teinte: Teinte
        public var opaciteVerre: Double
        public var opaciteAretes: Double
        public var profondeur: Double
    }

    public struct Lien: Sendable {
        public var a, b: CGPoint
        public var genre: GrapheReseau.Lien.Genre
        public var qualite: Int?
        public var opacite: Double
        public var eclaire: Bool
    }

    public struct Fil: Sendable {
        public var a, b: CGPoint
        public var opacite: Double
    }

    public struct Disque: Sendable {
        public var noeud: String
        public var centre: CGPoint
        public var rayon: Double
        public var opacite: Double
        public var profondeur: Double
    }

    public struct Sphere: Sendable {
        /// Envoie le disque unite sur le contour exact de la sphere.
        public var transfo: CGAffineTransform
        public var force: Double
    }

    /// Eclairage des faces de la maquette : ambiante 2,2 et directionnelle 1,6 venant de
    /// (-10, 30, 14), sur un materiau de Lambert, (2,2 + 1,6 n.l) / pi ; faces +x, -x, +y, -y, +z, -z.
    public static let lambert: [Double] = {
        let l = simd_normalize(SIMD3<Double>(-10, 30, 14))
        let normales: [SIMD3<Double>] = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]
        return normales.map { (2.2 + 1.6 * max(0, simd_dot($0, l))) / .pi }
    }()

    static let aretesBloc = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)]

    public var plateaux: [Plateau] = []
    public var equateur: Equateur?
    /// Du plus loin au plus proche.
    public var blocs: [Bloc] = []
    public var liensEnfants: [Lien] = []
    public var liensRouteurs: [Lien] = []
    public var fils: [Fil] = []
    /// Du plus loin au plus proche.
    public var disques: [Disque] = []
    public var sphere: Sphere?
    public var niveau: NiveauZoom = .tous
    /// Echelle k du zoom semantique : points par unite a la cible, divises par 24.
    public var echelle = 1.0
    public var ancresNoeuds: [String: CGRect] = [:]
    public var ancresPieces: [Int: CGRect] = [:]
    public var ancresEtages: [Int: CGRect] = [:]
    public var ancreMaison: CGRect?
    public var ancresAilleurs: [String: CGRect] = [:]
    /// Reperes « ailleurs » de la piece isolee.
    public var ailleurs: [Ailleurs] = []
    /// Centre de chaque noeud dans le monde.
    public var centresNoeuds: [String: SIMD3<Double>] = [:]

    public init() {}

    /// Pose la scene a l'etat `etat` et la projette par `orbite` dans `cadre` (la place utile de la
    /// vue). `positions` : centre de chaque piece dans son plateau (celles de la disposition, ou la
    /// piece qu'on glisse).
    public init(scene: ScenePieces, cartes: [CartesPieces.Carte], positions: [SIMD2<Double>], geometrie g: GeometrieMaison,
                etat: EtatAnime, orbite: Orbite, cadre: CGRect) {
        let proj = ProjectionScene(orbite, cadre: cadre)
        let t = etat.t
        let h = GeometrieMaison.hauteurBloc(t)
        let es = CameraScene.rampe(etat.s), fo = 1 - es
        let oeil = orbite.oeil

        // Plateaux : polygone exact de 128 points ; degrade par l'affine du disque.
        for e in g.rayons.indices {
            let c = g.centrePlateau(e, t), r = g.rayons[e]
            let pts = Self.cercle(c, r, 128)
            guard let poly = proj.polygone(pts) else { continue }
            plateaux.append(Plateau(etage: e, polygone: poly, contour: proj.polyligne(pts, fermee: true),
                                    disque: proj.disque(c, r), opacite: fo, profondeur: proj.profondeur(c)))
        }

        // Sphere de la maison : liseré et equateur, pendant l'envol et en 3D.
        let rs = g.rayonSphere * (0.8 + 0.2 * t)
        if 0.18 * t * fo > 0.002 {
            equateur = Equateur(contour: proj.polyligne(Self.cercle(g.centreSphere, rs, 192), fermee: true),
                                opacite: 0.18 * t * fo, profondeur: proj.profondeur(g.centreSphere))
        }
        let force = t * t * fo
        if force > 0.002, let m = proj.contourSphere(g.centreSphere, rs) {
            sphere = Sphere(transfo: m, force: force)
        }

        // Pieces : blocs de verre ; noeuds a mi-hauteur de leur bloc en 3D.
        var voiles = [Double](repeating: 1, count: scene.pieces.count)
        var mondes: [String: SIMD3<Double>] = [:]
        var centres = [SIMD3<Double>](repeating: .zero, count: scene.pieces.count)
        var echelles = [Double](repeating: 1, count: scene.pieces.count)
        for (i, pc) in scene.pieces.enumerated() where i < cartes.count && i < positions.count {
            let c = g.centrePlateau(pc.etage, t)
            let fe = CameraScene.rampe(i < etat.fk.count ? etat.fk[i] : 0)
            let voile = 1 - es * (1 - fe), f = 1 + 0.3 * fe
            voiles[i] = voile
            echelles[i] = f
            let vis = 1 - 0.85 * (1 - voile)
            let bx = c.x + positions[i].x, bz = c.z + positions[i].y
            let y0 = c.y + 0.02, y1 = y0 + h
            let x0 = bx - cartes[i].largeur * f / 2, x1 = bx + cartes[i].largeur * f / 2
            let z0 = bz - cartes[i].profondeur * f / 2, z1 = bz + cartes[i].profondeur * f / 2
            centres[i] = SIMD3(bx, (y0 + y1) / 2, bz)
            let k: [SIMD3<Double>] = [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1],
                                      [x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]]
            let teinte = Teinte(hexa: ScenePieces.teintes[pc.teinte % ScenePieces.teintes.count])
            var faces: [Face] = []
            func face(_ q: [Int], _ n: Int) {
                guard let p = proj.polygone(q.map { k[$0] }) else { return }
                faces.append(Face(points: p, teinte: teinte.eclairee(Self.lambert[n])))
            }
            if oeil.x > x1 { face([1, 2, 6, 5], 0) }
            if oeil.x < x0 { face([0, 4, 7, 3], 1) }
            if oeil.y > y1 { face([4, 5, 6, 7], 2) }
            if oeil.y < y0 { face([0, 3, 2, 1], 3) }
            if oeil.z > z1 { face([3, 7, 6, 2], 4) }
            if oeil.z < z0 { face([0, 1, 5, 4], 5) }
            let aretes = Self.aretesBloc.compactMap { proj.segment(k[$0.0], k[$0.1]) }
            blocs.append(Bloc(piece: i, faces: faces, aretes: aretes, teinte: teinte, opaciteVerre: vis * (0.13 + 0.05 * t),
                              opaciteAretes: vis * 0.75, profondeur: proj.profondeur(centres[i])))
            let coins = k.compactMap { proj.ecran($0) }
            if coins.count == 8 { ancresPieces[i] = Self.boite(coins) }
            for (r, id) in pc.noeuds.enumerated() where r < cartes[i].places.count {
                let l = cartes[i].places[r]
                mondes[id] = SIMD3(bx + l.x * f, c.y + 0.1 + 0.5 * h * t, bz + l.y * f)
            }
        }
        blocs.sort { $0.profondeur > $1.profondeur }
        centresNoeuds = mondes

        // Pastilles : le rayon suit l'echelle, sans depasser 1,1 fois le rayon naturel, 3 px au moins.
        for n in scene.noeuds {
            guard let p = mondes[n.id], let e = proj.ecran(p) else { continue }
            let r = min(n.rayon * 1.1, max(3, n.rayon * proj.pxParUnite(p) / CartesPieces.px))
            disques.append(Disque(noeud: n.id, centre: e, rayon: r, opacite: 1 - 0.8 * (1 - voiles[n.piece]),
                                  profondeur: proj.profondeur(p)))
            ancresNoeuds[n.id] = CGRect(x: Double(e.x) - r, y: Double(e.y) - r, width: 2 * r, height: 2 * r)
        }
        disques.sort { $0.profondeur > $1.profondeur }

        // Liens : estompes avec leurs pieces ; eclaires au survol (ou a la selection) d'un bout.
        for l in scene.liens {
            guard let a = mondes[l.de], let b = mondes[l.vers], let (pa, pb) = proj.segment(a, b),
                  let na = scene.noeud(l.de), let nb = scene.noeud(l.vers) else { continue }
            let poids = 1 - 0.85 * (1 - max(voiles[na.piece], voiles[nb.piece]))
            let eclaire = [l.de, l.vers].contains { $0 == etat.survol || $0 == etat.selection }
            if l.genre == .radio {
                liensRouteurs.append(Lien(a: pa, b: pb, genre: .radio, qualite: l.qualite, opacite: 0.95 * poids,
                                          eclaire: eclaire))
            } else {
                liensEnfants.append(Lien(a: pa, b: pb, genre: l.genre, qualite: l.qualite,
                                         opacite: eclaire ? 0.85 : 0.28 * poids, eclaire: eclaire))
            }
        }

        // Reperes « ailleurs » de la piece isolee : un fil vers le bord de la piece, du cote du parent.
        if let i = etat.focus, i < scene.pieces.count, i < cartes.count {
            let fe = CameraScene.rampe(i < etat.fk.count ? etat.fk[i] : 0)
            ailleurs = Self.reperes(scene, focus: i)
            for a in ailleurs {
                guard let e = mondes[a.enfant], let pp = mondes[a.parent] else { continue }
                var dir = pp - centres[i]
                dir.y = 0
                dir = simd_length_squared(dir) < 1e-6 ? SIMD3(1, 0, 0) : simd_normalize(dir)
                var m = centres[i] + dir * (max(cartes[i].largeur, cartes[i].profondeur) * echelles[i] / 2 + 2.6)
                m.y = e.y
                if let (pa, pb) = proj.segment(e, m) { fils.append(Fil(a: pa, b: pb, opacite: 0.8 * fe)) }
                if let q = proj.ecran(m) { ancresAilleurs[a.enfant] = CGRect(x: q.x - 3, y: q.y - 3, width: 6, height: 6) }
            }
        }

        // Zoom semantique, noms d'etage (au bord du plateau, en haut de l'ecran) et de la maison.
        echelle = proj.pxParUnite(orbite.cible) / CartesPieces.px
        niveau = NiveauZoom(echelle: echelle)
        var hh = orbite.haut
        hh.y = 0
        let hautHorizontal = simd_length_squared(hh) < 1e-8 ? SIMD3<Double>(0, 0, -1) : simd_normalize(hh)
        for e in g.rayons.indices {
            if let p = proj.ecran(g.centrePlateau(e, t) + hautHorizontal * g.rayons[e]) {
                ancresEtages[e] = CGRect(origin: p, size: .zero)
            }
        }
        ancreMaison = proj.ecran(g.centreSphere + orbite.haut * rs).map { CGRect(origin: $0, size: .zero) }
    }

    /// Reperes « ailleurs » d'une piece isolee : ses enfants dont le parent (vu par la sonde) est dans
    /// une autre piece, dans l'ordre de ses lignes.
    public static func reperes(_ scene: ScenePieces, focus i: Int) -> [Ailleurs] {
        let pc = scene.pieces[i]
        return pc.noeuds.compactMap { id in
            guard let parent = scene.liens.first(where: { $0.genre == .parent && $0.de == id })?.vers,
                  let np = scene.noeud(parent), np.piece != i else { return nil }
            let ep = scene.pieces[np.piece].etage
            return Ailleurs(enfant: id, parent: parent, piece: np.piece, etage: ep,
                            sens: ep == pc.etage ? .memeEtage : ep < pc.etage ? .dessous : .dessus)
        }
    }

    /// Piece sous un point de l'ecran : la plus proche dont une face le contient.
    public func piece(sous p: CGPoint) -> Int? {
        blocs.reversed().first { b in b.faces.contains { Self.contient($0.points, p) } }?.piece
    }

    /// Noeud sous un point de l'ecran : la pastille la plus proche, a `marge` points pres de son bord.
    public func noeud(sous p: CGPoint, marge: Double = 8) -> String? {
        var meilleur: (String, Double)?
        for d in disques where d.opacite > 0.5 {
            let e = hypot(Double(d.centre.x - p.x), Double(d.centre.y - p.y))
            if e <= d.rayon + marge, e < meilleur?.1 ?? .infinity { meilleur = (d.noeud, e) }
        }
        return meilleur?.0
    }

    /// Point dans un polygone (regle pair-impair).
    public static func contient(_ poly: [CGPoint], _ p: CGPoint) -> Bool {
        var dedans = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { dedans.toggle() }
            j = i
        }
        return dedans
    }

    static func cercle(_ c: SIMD3<Double>, _ r: Double, _ n: Int) -> [SIMD3<Double>] {
        (0..<n).map { i in
            let a = Double(i) / Double(n) * 2 * .pi
            return c + SIMD3(r * cos(a), 0, r * sin(a))
        }
    }

    /// Boite englobante de points de l'ecran.
    public static func boite(_ pts: [CGPoint]) -> CGRect {
        var x0 = CGFloat.infinity, y0 = CGFloat.infinity, x1 = -CGFloat.infinity, y1 = -CGFloat.infinity
        for p in pts {
            x0 = min(x0, p.x)
            y0 = min(y0, p.y)
            x1 = max(x1, p.x)
            y1 = max(y1, p.y)
        }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/SceneProjeteeTests`
Expected: `Test run with 6 tests in 1 suite passed` (`SceneProjeteeTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 331 tests in 35 suites passed` (cœur) et `Test run with 247 tests in 27 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 6 tests et 1 suite de plus pour le cœur, l'app inchangée.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Scene/SceneProjetee.swift MaillageCoeurTests/SceneProjeteeTests.swift
git commit -m "Projeter la scene pour le moteur Canvas

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 9: Démo : la maison de la maquette (pièces et étages)

**Files:**
- Modify: `MaillageCoeur/Demo/NomsDemo.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/NomsTests.swift` (blocs ci-dessous)

**Interfaces:**
- Consumes :
  - `NomsMaison(… zones:)` et `ZoneMaison` (plan 4a, existants).
- Produces :
  - la maison de démo reçoit les pièces et les étages de la maquette v13 : quelques accessoires changent de pièce pour tomber dans ses huit pièces (Salon, Cuisine, Entrée, Buanderie ; Chambre, Bureau, Salle de bain, Chambre d'amis) ; les six routeurs de bordure de la démo deviennent des accessoires du nom de leur annonce (`NomsDemo.routeurs`), qui leur donnent leur pièce ;
  - `public static let zones: [ZoneMaison]` dans `NomsDemo` : « Rez-de-chaussée » puis « Étage », passées à `NomsMaison(… zones:)`.

La spec (section 1) demande des pièces et des étages inventés, ceux de la maquette, pour les captures et les tests. Tout est inventé : aucun nom de la maison de Djoko.

- [ ] **Step 1 : écrire les tests.** La démo compte maintenant 30 accessoires (ses 24 appareils et les 6 routeurs de bordure), et sa maison est celle de la maquette.

Dans `MaillageCoeurTests/NomsTests.swift`, remplacer :

```swift
        #expect(NomsDemo.maison.accessoires.count == 24)
```

par :

```swift
        #expect(NomsDemo.maison.accessoires.count == 30, "24 appareils et 6 routeurs de bordure")
```

Dans `MaillageCoeurTests/NomsTests.swift`, remplacer :

```swift
    @Test func noeudMatter() {
```

par :

```swift
    /// Maison de demo : les zones et les pieces de la maquette de la vue par pieces ; chaque piece a un
    /// accessoire ; les routeurs de bordure y sont des accessoires du nom de leur annonce, sans noeud Matter.
    @Test func maisonDeDemo() {
        let m = NomsDemo.maison
        #expect(m.zones == [ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie"]),
                            ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"])])
        let pieces = Set(m.accessoires.compactMap(\.piece))
        #expect(pieces == Set((m.zones ?? []).flatMap(\.pieces)))
        let routeurs = Set(instantane.routeurs.map(\.instance))
        let accessoiresRouteurs = m.accessoires.filter { routeurs.contains($0.nom) }
        #expect(accessoiresRouteurs.count == 6 && accessoiresRouteurs.allSatisfy { $0.noeudMatter == nil && $0.piece != nil })
    }

    @Test func noeudMatter() {
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/NomsTests`
Expected: `Test run with 16 tests in 1 suite failed … with 4 issues` : `fabriqueDApple()` (`Expectation failed: NomsDemo.maison.accessoires.count == 30`) et `maisonDeDemo()`, trois attentes (les zones de la maquette, les pièces de ces zones, les accessoires des six routeurs de bordure).

- [ ] **Step 3 : écrire le code.**

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
/// 30FC8F95E0E1A385, qui joue la fabrique d'Apple.
public enum NomsDemo {
```

par :

```swift
/// 30FC8F95E0E1A385, qui joue la fabrique d'Apple. Les pieces et les etages sont
/// ceux de la maquette de la vue par pieces ; les routeurs de bordure y sont des
/// accessoires du nom de leur annonce, qui leur donnent leur piece.
public enum NomsDemo {
```

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
        "3A5DFAFCAB581AAF": ("Eve Motion", "Couloir", "Eve Systems", "Eve Motion", "Capteur"),
```

par :

```swift
        "3A5DFAFCAB581AAF": ("Eve Motion", "Buanderie", "Eve Systems", "Eve Motion", "Capteur"),
```

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
        "DAEF22ACB58F651C": ("Météo terrasse", "Terrasse", "Eve Systems", "Eve Weather", "Capteur"),
```

par :

```swift
        "DAEF22ACB58F651C": ("Météo terrasse", "Salon", "Eve Systems", "Eve Weather", "Capteur"),
```

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
        "327DF9C45C82BBD6": ("Détecteur couloir", "Couloir", "Aqara", "Motion Sensor P2", "Capteur"),
```

par :

```swift
        "327DF9C45C82BBD6": ("Détecteur couloir", "Entrée", "Aqara", "Motion Sensor P2", "Capteur"),
```

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
        "9A28601B74FF90A7": ("Lampe chevet", "Chambre", "Nanoleaf", "Essentials A19", "Ampoule"),
```

par :

```swift
        "9A28601B74FF90A7": ("Lampe chambre d'amis", "Chambre d'amis", "Nanoleaf", "Essentials A19", "Ampoule"),
```

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
    public static let maison: NomsMaison = {
```

par :

```swift
    /// Routeurs de bordure (instance de l'annonce) -> (piece, fabricant, modele).
    static let routeurs: [String: (String, String, String)] = [
        "Apple TV 4K": ("Salon", "Apple", "Apple TV 4K"),
        "HomePod Palier": ("Salon", "Apple", "HomePod"),
        "HomePod Avant": ("Salon", "Apple", "HomePod"),
        "HomePod mini bureau": ("Bureau", "Apple", "HomePod mini"),
        "HomePod mini chambre": ("Chambre", "Apple", "HomePod mini"),
        "Aqara HubM100 #DFEB": ("Buanderie", "Aqara", "Hub M100"),
    ]

    /// Zones de la maquette, dans l'ordre de Maison : le rez-de-chaussee, puis l'etage.
    public static let zones = [
        ZoneMaison(nom: "Rez-de-chaussée", pieces: ["Salon", "Cuisine", "Entrée", "Buanderie"]),
        ZoneMaison(nom: "Étage", pieces: ["Chambre", "Bureau", "Salle de bain", "Chambre d'amis"]),
    ]

    public static let maison: NomsMaison = {
```

Dans `MaillageCoeur/Demo/NomsDemo.swift`, remplacer :

```swift
                                                categorie: e.4, noeudMatter: i.noeud, batterie: batteries[id]))
        }
        // Dans le temps de la demo (la fin de la panne rejouee) : « releve il y a 5 minutes ».
        return NomsMaison(date: ScenarioPanne.fin.addingTimeInterval(-5 * 60), domicile: "Maison (démo)",
                          accessoires: accessoires.sorted { $0.nom < $1.nom })
```

par :

```swift
                                                categorie: e.4, noeudMatter: i.noeud, batterie: batteries[id]))
        }
        for (nom, r) in routeurs {
            accessoires.append(AccessoireMaison(nom: nom, piece: r.0, fabricant: r.1, modele: r.2, categorie: "Concentrateur"))
        }
        // Dans le temps de la demo (la fin de la panne rejouee) : « releve il y a 5 minutes ».
        return NomsMaison(date: ScenarioPanne.fin.addingTimeInterval(-5 * 60), domicile: "Maison (démo)",
                          accessoires: accessoires.sorted { $0.nom < $1.nom }, zones: zones)
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/NomsTests`
Expected: `Test run with 16 tests in 1 suite passed` (`NomsTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 332 tests in 35 suites passed` (cœur) et `Test run with 247 tests in 27 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 1 test de plus pour le cœur, l'app inchangée.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Demo/NomsDemo.swift MaillageCoeurTests/NomsTests.swift
git commit -m "Donner a la maison de demo les pieces et les etages de la maquette

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 10: App : noms, dessin partagé des nœuds et scène de l'app

**Files:**
- Create: `MaillageThread/Vues/Pieces/LibellesNoeuds.swift`, `MaillageThread/Vues/Pieces/StylesNoms.swift`, `MaillageThread/Vues/Pieces/DessinNoeud.swift`, `MaillageThread/Vues/Pieces/MesureNoms.swift`, `MaillageThread/Vues/Pieces/EntreeScene.swift`
- Modify: `MaillageThread/Vues/Graphe/Palette.swift` (bloc ci-dessous)
- Modify (par les outils) : `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings`
- Test: `MaillageThreadTests/NomsSceneTests.swift`

**Interfaces:**
- Consumes :
  - `GrapheReseau` (1), `ScenePieces` (2), `CartesPieces` (3), `DispositionPieces` (4), `PlacesGardees` et `PiecesRouteurs` (5), la démo de la tâche 9 ;
  - dans l'app, existants : `Surveillance` (`appareilsAffiches(pour:)`, `maillageAffiche(pour:)`, `maillage`, `nomsRouteurs(pour:)`, `noms.maison`), `Palette`, `NoeudSonde`, `MaillageAffiche`.
- Produces :
  - `enum LibellesNoeuds` : `Libelle` (`texte`, `pastille: String?`) ; `inconnu(_ n: NoeudSonde, noms: [String: String] = [:]) -> String` (le nom d'un nœud que seule la sonde connaît, repris de `GrapheCanvas.libelleInconnu`) ; `pastilleBatterie(_:) -> String?` ; `chefs(reseau:maillage:affiche:) -> Set<String>` ; `libelles(graphe:appareils:nomsRouteurs:maillage:chefs:) -> [String: Libelle]` ; `pieces(reseau:appareils:maison:nomsRouteurs: [String: String] = [:], choix: PiecesRouteurs = PiecesRouteurs()) -> [String: String]` (précisions 1, 23 et 24) ; `pieceDeMaison(routeur:maison:) -> String?` (la pièce de l'accessoire qui porte le nom de l'annonce) ; `nom(_: ScenePieces.NomEtage) -> String`, `nom(_: ScenePieces.NomPiece, libelles:) -> String`, `compte(_ n: Int) -> String`, `ailleurs(_:scene:libelles:) -> String` ;
  - `enum StylesNoms` : `grand`, `noeud(_:routeur:fort:) -> Text`, `nomPiece(_:)`, `comptePiece(_:)`, `etage(_:)`, `maison(_:)`, `ailleurs(_:)` (11, 12 et 13 pt) ;
  - `enum DessinNoeud` : `Couleur` (`.routeur(principale:)`, `.routeurInconnu`, `.appareil(EtatAffiche)`), `Forme` (`.sphere(halo:)`, `.pastille`, `.anneau`), `Apparence` (`forme`, `couleur`) ; `apparence(_:etat:principale:) -> Apparence`, `couleur(_:palette:) -> Color`, `dessiner(_:centre:rayon:apparence:palette:)`, `dessinerSelection(_:centre:rayon:palette:)`, `dessinerPastille(_:_:gauche:palette:)`, `taillePastille(icone:valeur:)` : le dessin des nœuds du graphe, sorti dans une fonction partagée ;
  - `@MainActor final class MesureNoms` : `noeud(_:routeur:) -> CGSize`, `pastille(_:)`, `piece(nom:compte:)`, `etage(_:)`, `maison(_:)`, `ailleurs(_:)` (mesurés par SwiftUI, gardés en cache) ;
  - `struct EntreeScene: Equatable` : `init(surveillance: Surveillance, reseau: Reseau, places: PlacesGardees, choix: PiecesRouteurs = PiecesRouteurs())` ; `scene`, `libelles`, `apparences`, `domicile` ; `cleDisposition` (ce qui oblige à recalculer la disposition) ;
  - `Palette` gagne les couleurs de la vue : `zone`, `encre`, `couleur(_: Teinte)`, `teintePiece(_:)`, `texteNom`, `fondNom`, `texteNomPiece`, `comptePiece`, `fondNomPiece`, `texteAilleurs`, `fondAilleurs`, `filAilleurs`, `trait`, `texteMaison`, `bulle`, `equateur`, `degradeBulle(force:)`.

Ce que la vue montre d'un réseau, tiré de la surveillance : les libellés (nom coupé à 40 caractères, 👑, ☾, ⚠︎, pastille de batterie), la pièce de chaque nœud (précision 1 ; pour un routeur de bordure que Maison ne place pas, le choix puis le nom, précisions 23 et 24), l'apparence de chaque nœud, et la scène. Les tests passent sur la démo de la tâche 9 : aucun lien n'y traverse une pièce, et la taille mesurée d'un nom est celle du texte dessiné. `NomsSceneTests.maisonSansRouteurs(_:)` retire de la maison de démo les accessoires de ses routeurs, comme chez Djoko : « HomePod mini chambre » va alors dans « Chambre » par son nom, « HomePod Palier » dans « Sans pièce », ou au salon si on l'y place.

- [ ] **Step 1 : écrire les tests.**

`MaillageThreadTests/NomsSceneTests.swift` (fichier entier) :

```swift
import AppKit
import Foundation
@testable import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : noms, apparences et scene de l'app")
struct NomsSceneTests {
    /// La demo : la panne rejouee, ses noms de Maison (pieces et etages de la maquette) et son
    /// maillage de sonde invente.
    static func demo() throws -> (Surveillance, Reseau, EntreeScene) {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let r = try #require(s.reseau)
        return (s, r, EntreeScene(surveillance: s, reseau: r, places: PlacesGardees()))
    }

    /// La maison de demo sans les accessoires de ses routeurs de bordure : comme chez Djoko, Maison ne
    /// donne ni les HomePod ni l'Apple TV.
    static func maisonSansRouteurs(_ s: Surveillance) -> NomsMaison? {
        guard var m = s.noms.maison, let r = s.reseau else { return nil }
        let routeurs = Set(r.routeurs.map(\.instance))
        m.accessoires.removeAll { routeurs.contains($0.nom) }
        return m
    }

    /// Libelle d'un noeud : le nom coupe a 40 caracteres, la couronne du chef (celui de la partition
    /// et celui de la sonde), ☾ endormi, ⚠︎ sans adresse ou disparu ; la pastille d'une batterie faible.
    @Test func libelles() throws {
        let (s, r, e) = try Self.demo()
        #expect(e.libelles["Apple TV 4K"]?.texte == "Apple TV 4K 👑")
        #expect(e.libelles["86E7BD1A75F28E6D"] == LibellesNoeuds.Libelle(texte: "Nuki Ultra ☾"))
        #expect(e.libelles["7AF0B6D5006CF95F"]?.texte == "Prise salon ☾ ⚠︎", "disparue")
        #expect(e.libelles["3A5DFAFCAB581AAF"]?.pastille == String(localized: "\(12)\u{202F}%"))
        #expect(e.libelles["rloc:041F"]?.texte == String(localized: "Non identifié · \("041F")"))
        let m = try #require(s.maillageAffiche(pour: r))
        #expect(LibellesNoeuds.chefs(reseau: r, maillage: s.maillage, affiche: m) == ["Apple TV 4K"])
        #expect(LibellesNoeuds.pastilleBatterie(BatterieMaison(alerte: true)) == String(localized: "faible"))
        #expect(LibellesNoeuds.pastilleBatterie(BatterieMaison(niveau: 52)) == nil)
        #expect(LibellesNoeuds.inconnu(NoeudSonde(id: "rloc:5000", rloc16: 0x5000, genre: .routeur, reconnu: false,
                                                  bordure: false)) == String(localized: "Routeur · \("5000")"))
    }

    /// Pieces : celle de l'accessoire d'un appareil ; celle de l'accessoire du nom de l'annonce d'un
    /// routeur de bordure. Noms des etages, des pieces, compte, repere « ailleurs ».
    @Test func piecesEtNoms() throws {
        let (s, r, e) = try Self.demo()
        let pieces = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: s.noms.maison)
        #expect(pieces["Apple TV 4K"] == "Salon" && pieces["HomePod mini chambre"] == "Chambre")
        #expect(pieces["56B1E064401F74EF"] == "Bureau")
        #expect(pieces["1E5019DAC2638F92"] == nil)
        #expect(LibellesNoeuds.nom(ScenePieces.NomEtage.zone("Étage")) == "Étage")
        #expect(LibellesNoeuds.nom(ScenePieces.NomEtage.maison) == String(localized: "Maison"))
        #expect(LibellesNoeuds.nom(ScenePieces.NomPiece.sansPiece, libelles: [:]) == String(localized: "Sans pièce"))
        #expect(LibellesNoeuds.nom(.routeur("Apple TV 4K"), libelles: e.libelles) == "Apple TV 4K 👑")
        #expect(LibellesNoeuds.compte(1) == String(localized: "1 appareil"))
        #expect(LibellesNoeuds.compte(6) == String(localized: "\(6) appareils"))
        let salon = try #require(e.scene.pieces.firstIndex { $0.nom == .maison("Salon") })
        let reperes = SceneProjetee.reperes(e.scene, focus: salon)
        let volet = try #require(reperes.first { $0.enfant == "724CC16B32D8F820" })
        #expect(LibellesNoeuds.ailleurs(volet, scene: e.scene, libelles: e.libelles)
                == "↑ HomePod mini chambre · Chambre, Étage")
    }

    /// Routeurs de bordure que Maison ne place pas : la piece de leur nom (« HomePod mini chambre »), sinon
    /// celle qu'on leur a choisie, qui passe avant ; les autres vont dans « Sans piece ». Un routeur que
    /// Maison place garde sa piece.
    @Test func piecesDesRouteurs() throws {
        let (s, r, _) = try Self.demo()
        let maison = try #require(Self.maisonSansRouteurs(s))
        #expect(!maison.accessoires.contains { $0.nom == "Apple TV 4K" })
        let noms = s.nomsRouteurs(pour: r)
        var pieces = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: maison,
                                           nomsRouteurs: noms)
        #expect(pieces["HomePod mini chambre"] == "Chambre" && pieces["HomePod mini bureau"] == "Bureau")
        #expect(pieces["HomePod Palier"] == nil && pieces["HomePod Avant"] == nil && pieces["Apple TV 4K"] == nil)
        var choix = PiecesRouteurs()
        choix.choisir("Salon", routeur: "HomePod Palier", domicile: maison.domicile ?? "")
        choix.choisir("Bureau", routeur: "HomePod mini chambre", domicile: maison.domicile ?? "")
        pieces = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: maison,
                                       nomsRouteurs: noms, choix: choix)
        #expect(pieces["HomePod Palier"] == "Salon" && pieces["HomePod mini chambre"] == "Bureau")
        let avecMaison = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: s.noms.maison,
                                               nomsRouteurs: noms, choix: choix)
        #expect(avecMaison["HomePod mini chambre"] == "Chambre", "Maison passe avant le choix")
        s.noms.maison = maison
        let e = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees(), choix: choix)
        let gauche = try #require(e.scene.noeud("HomePod Palier"))
        #expect(e.scene.pieces[gauche.piece].nom == .maison("Salon"))
        let atv = try #require(e.scene.noeud("Apple TV 4K"))
        #expect(e.scene.pieces[atv.piece].nom == .sansPiece)
    }

    /// La maison de demo : les deux etages et les huit pieces de la maquette, « Sans piece » sur le
    /// plateau du bas ; les apparences du graphe d'avant.
    @Test func sceneDeLaDemo() throws {
        let (_, _, e) = try Self.demo()
        #expect(e.scene.etages.map(\.nom) == [.zone("Rez-de-chaussée"), .zone("Étage")])
        let bas = e.scene.etages[0].pieces.map { e.scene.pieces[$0].nom }
        #expect(bas == [.maison("Buanderie"), .maison("Cuisine"), .maison("Entrée"), .maison("Salon"), .sansPiece])
        let haut = e.scene.etages[1].pieces.map { e.scene.pieces[$0].nom }
        #expect(haut == [.maison("Bureau"), .maison("Chambre"), .maison("Chambre d'amis"), .maison("Salle de bain")])
        #expect(!e.scene.sansPiecesMaison)
        #expect(e.domicile == "Maison (démo)")
        #expect(e.apparences["Apple TV 4K"] == DessinNoeud.Apparence(forme: .sphere(halo: 10),
                                                                    couleur: .routeur(principale: true)))
        #expect(e.apparences["HomePod Avant"]?.forme == .sphere(halo: 5))
        #expect(e.apparences["Aqara HubM100 #DFEB"]?.couleur == .routeur(principale: false))
        #expect(e.apparences["7AF0B6D5006CF95F"] == DessinNoeud.Apparence(forme: .anneau, couleur: .appareil(.disparu)))
        #expect(e.apparences["56B1E064401F74EF"] == DessinNoeud.Apparence(forme: .pastille, couleur: .appareil(.joignable)))
        #expect(e.apparences["rloc:041F"]?.couleur == .appareil(.inconnu))
    }

    /// La cle de la disposition ne change pas avec l'etat d'un noeud ; elle change avec son nom.
    @Test func cleDeLaDisposition() throws {
        let (s, r, e) = try Self.demo()
        #expect(EntreeScene(surveillance: s, reseau: r, places: PlacesGardees()).cleDisposition == e.cleDisposition)
        s.renommer("56B1E064401F74EF", en: "Pont Halo")
        #expect(EntreeScene(surveillance: s, reseau: r, places: PlacesGardees()).cleDisposition != e.cleDisposition)
    }

    /// Sur la maison de demo, avec les noms mesures par l'app : aucun lien ne passe sur une piece
    /// autre que celles de ses bouts, aucune carte n'en recouvre une autre.
    @Test func demoSansTraversee() throws {
        let (_, _, e) = try Self.demo()
        let mesure = MesureNoms()
        var largeurs: [String: Double] = [:]
        for n in e.scene.noeuds {
            largeurs[n.id] = mesure.noeud(try #require(e.libelles[n.id]), routeur: n.rang <= 2).width
        }
        let cartes = CartesPieces.cartes(e.scene, largeurs: largeurs)
        let d = DispositionPieces(scene: e.scene, cartes: cartes)
        let calcul = DispositionPieces.Calcul(scene: e.scene, cartes: cartes, fixees: [:])
        #expect(calcul.traversees(d.positions) == 0)
        #expect(d.cout < d.coutDepart)
        for et in e.scene.etages {
            for (k, a) in et.pieces.enumerated() {
                for b in et.pieces[(k + 1)...] {
                    let dx = abs(d.positions[b].x - d.positions[a].x), dz = abs(d.positions[b].y - d.positions[a].y)
                    let px = (cartes[a].largeur + cartes[b].largeur) / 2 + DispositionPieces.gap - dx
                    let pz = (cartes[a].profondeur + cartes[b].profondeur) / 2 + DispositionPieces.gap + DispositionPieces.lab - dz
                    #expect(!(px > 1e-6 && pz > 1e-6), "\(e.scene.pieces[a].id) / \(e.scene.pieces[b].id)")
                }
            }
        }
    }

    /// Tailles des textes rendues par `Canvas` a l'echelle 1, 2 et 3.
    static func taillesDessinees(_ textes: [Text], echelle: CGFloat) -> [CGSize] {
        final class Boite: @unchecked Sendable { var tailles: [CGSize] = [] }
        let boite = Boite()
        let rendu = ImageRenderer(content: Canvas { ctx, _ in
            boite.tailles = textes.map { ctx.resolve($0).measure(in: StylesNoms.grand) }
        }.frame(width: 10, height: 10))
        rendu.scale = echelle
        _ = rendu.cgImage
        return boite.tailles
    }

    /// La taille mesuree hors du `Canvas` couvre le texte dessine, a toute echelle : un nom ne deborde
    /// pas de la place que le placement lui donne (moins d'un point pres).
    @Test func tailleMesureeCommeDessinee() {
        let mesure = MesureNoms()
        let noms = ["Détecteur de passage lingerie sud ☾", "HomePod mini chambre", "Apple TV 4K 👑", "Salon"]
        for echelle in [1.0, 2.0, 3.0] {
            for n in noms {
                for routeur in [false, true] {
                    let dessinee = Self.taillesDessinees([StylesNoms.noeud(n, routeur: routeur, fort: true)],
                                                         echelle: echelle)[0]
                    let place = mesure.noeud(LibellesNoeuds.Libelle(texte: n), routeur: routeur)
                    #expect(dessinee.width + 10 <= place.width + 1 && dessinee.height <= place.height + 1,
                            "\(n) a \(echelle) : \(dessinee) dans \(place)")
                }
                let t = Self.taillesDessinees([StylesNoms.etage(n)], echelle: echelle)[0]
                let e = mesure.etage(n)
                #expect(t.width <= e.width + 1 && t.height <= e.height + 1)
            }
        }
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageThreadTests/NomsSceneTests`
Expected: la compilation des tests de l'app échoue, par exemple avec `error: cannot find type 'EntreeScene' in scope` et `error: cannot find 'EntreeScene' in scope`.

- [ ] **Step 3 : écrire le code.** Le bloc de `Palette.swift` ajoute les couleurs de la vue par pièces (spec, sections 5 et 6).

`MaillageThread/Vues/Pieces/LibellesNoeuds.swift` (fichier entier) :

```swift
import Foundation
import MaillageCoeur

/// Textes de la vue par pieces : le libelle de chaque noeud (nom, couronne, lune, alerte) et la
/// pastille de sa batterie faible ; les noms des pieces et des etages ; le compte d'une piece ; le
/// texte d'un repere « ailleurs ».
enum LibellesNoeuds {
    /// Libelle d'un noeud : son texte, et la pastille de sa batterie faible.
    struct Libelle: Hashable {
        var texte: String
        var pastille: String?
    }

    /// Nom d'un noeud que seule la sonde connait : « Routeur de bordure · B400 »,
    /// « Routeur · 5000 », « Non identifie · AC05 ». Un routeur de bordure non identifie
    /// montre ses candidats, sous leur nom (`noms`, par instance ; l'instance a defaut) :
    /// « HomePod Avant ou HomePod Palier · 0400 » ; un seul, sans elimination possible :
    /// « HomePod salon ? · 0400 », car ce n'est peut-etre pas lui.
    static func inconnu(_ n: NoeudSonde, noms: [String: String] = [:]) -> String {
        let rloc = String(format: "%04X", n.rloc16)
        switch n.genre {
        case .routeur:
            let candidats = n.candidats.map { noms[$0] ?? $0 }
            if candidats.count > 1 { return String(localized: "\(candidats.formatted(.list(type: .or))) · \(rloc)") }
            if let seul = candidats.first { return String(localized: "\(seul)\u{202F}? · \(rloc)") }
            return n.bordure ? String(localized: "Routeur de bordure · \(rloc)") : String(localized: "Routeur · \(rloc)")
        case .enfant:
            return String(localized: "Non identifié · \(rloc)")
        }
    }

    /// Texte de la pastille d'une batterie faible : son niveau, sinon « faible » ; nil si elle ne
    /// l'est pas.
    static func pastilleBatterie(_ b: BatterieMaison?) -> String? {
        guard let b, b.faible else { return nil }
        return b.niveau.map { String(localized: "\($0)\u{202F}%") } ?? String(localized: "faible")
    }

    /// Noeuds couronnes : le chef de chaque partition (son annonce), et celui du maillage de la sonde.
    static func chefs(reseau: Reseau, maillage: Maillage?, affiche: MaillageAffiche?) -> Set<String> {
        var c = Set(reseau.partitions.compactMap { $0.chef?.instance })
        if let chef = maillage?.chef, let n = affiche?.routeurs[chef.id] { c.insert(n.id) }
        return c
    }

    /// Libelle de chaque noeud : son nom (coupe a 40 caracteres), la couronne du chef, ☾ endormi,
    /// ⚠︎ sans adresse ou disparu ; la pastille d'une batterie faible.
    static func libelles(graphe: GrapheReseau, appareils: [String: AppareilAffiche], nomsRouteurs: [String: String],
                         maillage: MaillageAffiche?, chefs: Set<String>) -> [String: Libelle] {
        func inconnu(_ n: NoeudSonde) -> String { Self.inconnu(n, noms: nomsRouteurs) }
        var libelles: [String: Libelle] = [:]
        for n in graphe.noeuds {
            let a = appareils[n.id]
            let nom = a?.nom ?? nomsRouteurs[n.id] ?? maillage?.noeud(n.id).map(inconnu) ?? n.id
            var texte = CartesPieces.couper(nom)
            if chefs.contains(n.id) { texte += " 👑" }
            if a?.endormi == true { texte += " ☾" }
            if a?.etat == .sansAdresse || a?.etat == .disparu { texte += " ⚠︎" }
            libelles[n.id] = Libelle(texte: texte, pastille: pastilleBatterie(a?.batterie))
        }
        return libelles
    }

    /// Piece de Maison de chaque noeud : celle de son accessoire (appareil), ou, pour un routeur de
    /// bordure, celle de l'accessoire de Maison qui porte le nom de son annonce. Un routeur de bordure
    /// que Maison ne place pas (HomePod, Apple TV) prend la piece choisie pour lui, sinon celle de son
    /// nom (`nomsRouteurs`, par instance ; `PiecesRouteurs`).
    static func pieces(reseau: Reseau, appareils: [AppareilAffiche], maison: NomsMaison?,
                       nomsRouteurs: [String: String] = [:], choix: PiecesRouteurs = PiecesRouteurs()) -> [String: String] {
        var pieces: [String: String] = [:]
        for a in appareils {
            if let p = a.piece, !p.isEmpty { pieces[a.id] = p }
        }
        let toutes = PiecesRouteurs.pieces(de: maison)
        let domicile = maison?.domicile ?? ""
        for r in reseau.routeurs {
            if let p = pieceDeMaison(routeur: r.instance, maison: maison) {
                pieces[r.instance] = p
            } else if let p = choix.piece(routeur: r.instance, nom: nomsRouteurs[r.instance] ?? r.instance, parmi: toutes,
                                          domicile: domicile) {
                pieces[r.instance] = p
            }
        }
        return pieces
    }

    /// Piece de Maison d'un routeur de bordure (son instance) : celle de l'accessoire qui porte son nom.
    static func pieceDeMaison(routeur: String, maison: NomsMaison?) -> String? {
        maison?.accessoires.first { $0.nom == routeur && $0.piece?.isEmpty == false }?.piece
    }

    static func nom(_ e: ScenePieces.NomEtage) -> String {
        switch e {
        case .zone(let n): n
        case .autresPieces: String(localized: "Autres pièces")
        case .maison: String(localized: "Maison")
        }
    }

    static func nom(_ p: ScenePieces.NomPiece, libelles: [String: Libelle]) -> String {
        switch p {
        case .maison(let n): n
        case .routeur(let id): libelles[id]?.texte ?? id
        case .sansPiece: String(localized: "Sans pièce")
        }
    }

    /// « 1 appareil », « 6 appareils ».
    static func compte(_ n: Int) -> String {
        n == 1 ? String(localized: "1 appareil") : String(localized: "\(n) appareils")
    }

    /// Repere « ailleurs » : « ↗ HomePod Palier · Salon », « ↓ … · Salon, Rez-de-chaussée » si le
    /// parent est a un autre etage (sans la couronne du chef).
    static func ailleurs(_ a: Ailleurs, scene: ScenePieces, libelles: [String: Libelle]) -> String {
        let fleche = switch a.sens {
        case .memeEtage: "↗"
        case .dessous: "↓"
        case .dessus: "↑"
        }
        let parent = (libelles[a.parent]?.texte ?? a.parent).replacingOccurrences(of: " 👑", with: "")
        let piece = nom(scene.pieces[a.piece].nom, libelles: libelles)
        guard a.sens != .memeEtage else { return "\(fleche) \(parent) · \(piece)" }
        return "\(fleche) \(parent) · \(piece), \(nom(scene.etages[a.etage].nom))"
    }
}
```

`MaillageThread/Vues/Pieces/StylesNoms.swift` (fichier entier) :

```swift
import SwiftUI

/// Styles des noms de la vue par pieces (spec de la vue par pieces, section 6), les memes pour la
/// mesure (`MesureNoms`) et le dessin (`RenduCanvas`).
enum StylesNoms {
    /// Place proposee pour mesurer un texte d'une ligne.
    static let grand = CGSize(width: 10_000, height: 10_000)

    /// Appareil en 11 points, routeur en 12 ; semi-gras au survol et a la selection.
    static func noeud(_ texte: String, routeur: Bool, fort: Bool) -> Text {
        Text(verbatim: texte).font(.system(size: routeur ? 12 : 11, weight: fort ? .semibold : .regular))
    }

    /// Nom d'une piece en 12 points, son compte en 11.
    static func nomPiece(_ nom: String) -> Text { Text(verbatim: nom).font(.system(size: 12)) }
    static func comptePiece(_ compte: String) -> Text { Text(verbatim: compte).font(.system(size: 11)) }

    /// Nom d'un etage en 12 points ; « ⌂ Maison » en 13 ; repere « ailleurs » en 11.
    static func etage(_ nom: String) -> Text { Text(verbatim: nom).font(.system(size: 12)) }
    static func maison(_ texte: String) -> Text { Text(verbatim: texte).font(.system(size: 13)) }
    static func ailleurs(_ texte: String) -> Text { Text(verbatim: texte).font(.system(size: 11)) }
}
```

`MaillageThread/Vues/Pieces/DessinNoeud.swift` (fichier entier) :

```swift
import MaillageCoeur
import SwiftUI

/// Dessin d'un noeud, le meme que celui du graphe d'avant (spec de la vue par pieces, section 5) :
/// routeur en sphere brillante (degrade du blanc vers sa couleur, decale en haut a gauche) avec un
/// halo, appareil en pastille pleine de la couleur de son etat avec un halo, appareil disparu en
/// anneau ; anneau blanc de la selection ; pastille orange d'une batterie faible.
enum DessinNoeud {
    /// Couleur d'un noeud, resolue par la palette au dessin.
    enum Couleur: Hashable {
        case routeur(principale: Bool)
        /// Routeur que seule la sonde connait.
        case routeurInconnu
        case appareil(EtatAffiche)
    }

    enum Forme: Hashable {
        /// Sphere brillante et son halo (rayon de l'ombre, en points).
        case sphere(halo: CGFloat)
        case pastille
        /// Appareil disparu.
        case anneau
    }

    struct Apparence: Hashable {
        var forme: Forme
        var couleur: Couleur
    }

    /// Apparence d'un noeud : sphere pour un routeur de bordure ou un routeur que seule la sonde
    /// connait (halo de 10 pour le centre, 5 sinon), pastille pour un appareil (qui route ou non),
    /// anneau pour un appareil disparu. `etat` : celui de l'appareil ; `principale` : la partition du
    /// noeud est la principale.
    static func apparence(_ n: ScenePieces.Noeud, etat: EtatAffiche?, principale: Bool) -> Apparence {
        switch n.genre {
        case .centre, .routeur:
            return Apparence(forme: .sphere(halo: n.genre == .centre ? 10 : 5),
                             couleur: n.inconnu ? .routeurInconnu : .routeur(principale: principale))
        case .appareil:
            let e = etat ?? .inconnu
            return Apparence(forme: e == .disparu ? .anneau : .pastille, couleur: .appareil(e))
        }
    }

    static func couleur(_ c: Couleur, palette: Palette) -> Color {
        switch c {
        case .routeur(let p): palette.routeur(principale: p)
        case .routeurInconnu: palette.routeurInconnu
        case .appareil(let e): palette.appareil(e)
        }
    }

    /// Le noeud, centre en `centre`, de rayon `rayon`.
    static func dessiner(_ ctx: inout GraphicsContext, centre c: CGPoint, rayon r: CGFloat, apparence: Apparence,
                         palette: Palette) {
        let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
        let couleur = couleur(apparence.couleur, palette: palette)
        switch apparence.forme {
        case .sphere(let halo):
            ctx.drawLayer { l in
                l.addFilter(.shadow(color: couleur.opacity(0.8), radius: halo))
                l.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [.white.opacity(0.9), couleur]),
                                                                    center: CGPoint(x: c.x - r / 3, y: c.y - r / 3),
                                                                    startRadius: 0, endRadius: r * 1.3))
            }
        case .pastille:
            ctx.drawLayer { l in
                l.addFilter(.shadow(color: couleur.opacity(0.8), radius: 4))
                l.fill(Path(ellipseIn: rect), with: .color(couleur))
            }
        case .anneau:
            ctx.stroke(Path(ellipseIn: rect), with: .color(couleur), lineWidth: 2)
        }
    }

    /// Anneau du noeud selectionne, 4 points autour de sa pastille.
    static func dessinerSelection(_ ctx: inout GraphicsContext, centre c: CGPoint, rayon r: CGFloat, palette: Palette) {
        let a = r + 4
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - a, y: c.y - a, width: 2 * a, height: 2 * a)),
                   with: .color(palette.selection), lineWidth: 2)
    }

    static let policePastille = Font.caption2.weight(.semibold)

    static var iconePastille: Text {
        Text(Image(systemName: "exclamationmark.triangle.fill")).font(policePastille)
    }

    static func textePastille(_ valeur: String) -> Text {
        Text(verbatim: valeur).font(policePastille)
    }

    /// Capsule de la pastille : 6 pt, l'icone, 3 pt, la valeur, 6 pt ; 2 pt dessus et dessous.
    static func taillePastille(icone: CGSize, valeur: CGSize) -> CGSize {
        CGSize(width: 6 + icone.width + 3 + valeur.width + 6, height: max(icone.height, valeur.height) + 4)
    }

    /// Pastille orange en surbrillance d'une batterie faible : petit triangle et texte, dans une
    /// capsule qui luit ; le milieu de son bord gauche en `gauche`.
    static func dessinerPastille(_ ctx: inout GraphicsContext, _ texte: String, gauche: CGPoint, palette: Palette) {
        let icone = ctx.resolve(iconePastille.foregroundStyle(palette.texteBatterieFaible))
        let valeur = ctx.resolve(textePastille(texte).foregroundStyle(palette.texteBatterieFaible))
        let ti = icone.measure(in: StylesNoms.grand)
        let tv = valeur.measure(in: StylesNoms.grand)
        let taille = taillePastille(icone: ti, valeur: tv)
        let cadre = CGRect(x: gauche.x, y: gauche.y - taille.height / 2, width: taille.width, height: taille.height)
        let capsule = Path(roundedRect: cadre, cornerRadius: cadre.height / 2)
        ctx.drawLayer { l in
            l.addFilter(.shadow(color: palette.batterieFaible.opacity(0.9), radius: 6))
            l.fill(capsule, with: .color(palette.batterieFaible))
        }
        ctx.draw(icone, at: CGPoint(x: cadre.minX + 6, y: cadre.midY), anchor: .leading)
        ctx.draw(valeur, at: CGPoint(x: cadre.minX + 6 + ti.width + 3, y: cadre.midY), anchor: .leading)
    }
}
```

`MaillageThread/Vues/Pieces/MesureNoms.swift` (fichier entier) :

```swift
import AppKit
import MaillageCoeur
import SwiftUI

/// Tailles des noms de la vue par pieces, mesurees hors du `Canvas` avec les memes `Text` que le
/// dessin (`StylesNoms`) : SwiftUI les met en page comme le `Canvas`, a l'echelle d'ecran 1,
/// arrondies au point entier superieur. Une taille par texte, gardee (spec, section 4.2 : les
/// largeurs des noms passent au coeur).
@MainActor
final class MesureNoms {
    private enum Nature: Hashable {
        case noeud(routeur: Bool), nomPiece, comptePiece, etage, maison, ailleurs, icone, valeur
    }

    private struct Cle: Hashable {
        var texte: String
        var nature: Nature
    }

    private var hote: NSHostingController<AnyView>?
    private var tailles: [Cle: CGSize] = [:]

    /// Boite du nom d'un noeud : le texte en semi-gras (sa place ne change pas au survol), 5 points de
    /// chaque cote, puis la pastille d'une batterie faible, 5 points apres.
    func noeud(_ l: LibellesNoeuds.Libelle, routeur: Bool) -> CGSize {
        let t = mesurer(Cle(texte: l.texte, nature: .noeud(routeur: routeur))) {
            StylesNoms.noeud(l.texte, routeur: routeur, fort: true)
        }
        var taille = CGSize(width: t.width + 10, height: t.height)
        if let p = l.pastille {
            let c = pastille(p)
            taille.width += c.width + 5
            taille.height = max(taille.height, c.height)
        }
        return taille
    }

    /// Capsule de la pastille d'une batterie faible.
    func pastille(_ valeur: String) -> CGSize {
        DessinNoeud.taillePastille(icone: mesurer(Cle(texte: "", nature: .icone)) { DessinNoeud.iconePastille },
                                   valeur: mesurer(Cle(texte: valeur, nature: .valeur)) { DessinNoeud.textePastille(valeur) })
    }

    /// Nom d'une piece : bordure 1, marge 7, point 8, 6, nom, 6, compte, marge 7, bordure 1 ; 20 de haut.
    func piece(nom: String, compte: String) -> CGSize {
        let n = mesurer(Cle(texte: nom, nature: .nomPiece)) { StylesNoms.nomPiece(nom) }
        let c = mesurer(Cle(texte: compte, nature: .comptePiece)) { StylesNoms.comptePiece(compte) }
        return CGSize(width: n.width + c.width + 36, height: 20)
    }

    func etage(_ nom: String) -> CGSize {
        mesurer(Cle(texte: nom, nature: .etage)) { StylesNoms.etage(nom) }
    }

    func maison(_ texte: String) -> CGSize {
        mesurer(Cle(texte: texte, nature: .maison)) { StylesNoms.maison(texte) }
    }

    /// Repere « ailleurs » : 5 points de marge et 1 de bordure de chaque cote.
    func ailleurs(_ texte: String) -> CGSize {
        let t = mesurer(Cle(texte: texte, nature: .ailleurs)) { StylesNoms.ailleurs(texte) }
        return CGSize(width: t.width + 12, height: t.height + 2)
    }

    private func mesurer(_ cle: Cle, _ texte: () -> Text) -> CGSize {
        if let t = tailles[cle] { return t }
        let hote = self.hote ?? NSHostingController(rootView: AnyView(EmptyView()))
        self.hote = hote
        hote.rootView = AnyView(texte().environment(\.displayScale, 1))
        let s = hote.sizeThatFits(in: StylesNoms.grand)
        let t = CGSize(width: ceil(s.width), height: ceil(s.height))
        tailles[cle] = t
        return t
    }
}
```

`MaillageThread/Vues/Pieces/EntreeScene.swift` (fichier entier) :

```swift
import MaillageCoeur
import SwiftUI

/// Ce que la vue par pieces montre d'un reseau, tire de la surveillance (spec de la vue par pieces,
/// section 2) : la scene, le libelle et l'apparence de chaque noeud, et la maison de ses places
/// gardees.
struct EntreeScene: Equatable {
    var scene: ScenePieces
    var libelles: [String: LibellesNoeuds.Libelle]
    var apparences: [String: DessinNoeud.Apparence]
    /// Domicile de Maison ("" sans nom) : la cle de ses places gardees.
    var domicile: String

    /// `places` : les places gardees, dont l'ordre des etages de la maison ; `choix` : les pieces
    /// choisies pour les routeurs de bordure que Maison ne place pas.
    @MainActor
    init(surveillance: Surveillance, reseau r: Reseau, places: PlacesGardees, choix: PiecesRouteurs = PiecesRouteurs()) {
        let affiches = surveillance.appareilsAffiches(pour: r)
        let maillage = surveillance.maillageAffiche(pour: r)
        let graphe = GrapheReseau(reseau: r, appareils: affiches, maillage: maillage)
        let parId = Dictionary(affiches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let chefs = LibellesNoeuds.chefs(reseau: r, maillage: surveillance.maillage, affiche: maillage)
        let libelles = LibellesNoeuds.libelles(graphe: graphe, appareils: parId,
                                               nomsRouteurs: surveillance.nomsRouteurs(pour: r), maillage: maillage,
                                               chefs: chefs)
        let maison = surveillance.noms.maison
        let domicile = maison?.domicile ?? ""
        let pieces = LibellesNoeuds.pieces(reseau: r, appareils: affiches, maison: maison,
                                           nomsRouteurs: surveillance.nomsRouteurs(pour: r), choix: choix)
        let scene = ScenePieces(graphe: graphe, libelles: libelles.mapValues(\.texte), piecesNoeuds: pieces,
                                zones: maison?.zones, chefs: chefs,
                                piecesMaison: maison?.accessoires.contains { $0.piece?.isEmpty == false } == true,
                                ordreEtages: places.maison(domicile).ordreEtages)
        let principale = r.partitions.first(where: \.estPrincipale)?.id
        self.scene = scene
        self.libelles = libelles
        self.domicile = domicile
        apparences = Dictionary(uniqueKeysWithValues: scene.noeuds.map { n in
            (n.id, DessinNoeud.apparence(n, etat: parId[n.id]?.etat, principale: n.partition == principale))
        })
    }

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
        }
        return c
    }
}
```

Dans `MaillageThread/Vues/Graphe/Palette.swift`, remplacer :

```swift
    func appareil(_ e: EtatAffiche) -> Color {
        switch e {
        case .joignable: Color(red: 0.29, green: 0.87, blue: 0.5)
        case .partitionCoupee: .orange
        case .sansAdresse, .disparu: Color(red: 0.97, green: 0.44, blue: 0.44)
        case .inconnu: .gray
        }
    }
}
```

par :

```swift
    func appareil(_ e: EtatAffiche) -> Color {
        switch e {
        case .joignable: Color(red: 0.29, green: 0.87, blue: 0.5)
        case .partitionCoupee: .orange
        case .sansAdresse, .disparu: Color(red: 0.97, green: 0.44, blue: 0.44)
        case .inconnu: .gray
        }
    }

    // MARK: Vue par pieces (spec de la vue par pieces, sections 5 et 6)

    /// Couleur de zone de l'app (celle de la partition principale) : plateaux et noms d'etage.
    var zone: Color { Color(red: 0.23, green: 0.51, blue: 0.96) }
    /// Encre des liens enfant-parent et des rattachements (leur opacite vient de la scene).
    var encre: Color { sombre ? .white : .black }

    /// Teinte d'une piece (`ScenePieces.teintes`), eclairee ou non.
    static func couleur(_ t: Teinte) -> Color { Color(.sRGB, red: t.r, green: t.g, blue: t.b) }

    static func teintePiece(_ i: Int) -> Color {
        couleur(Teinte(hexa: ScenePieces.teintes[i % ScenePieces.teintes.count]))
    }

    /// Noms des appareils : blanc a 0,9 sur une pastille rgba(6, 10, 26, 0,72).
    var texteNom: Color { Color(white: 1, opacity: 0.9) }
    var fondNom: Color { Color(.sRGB, red: 6 / 255, green: 10 / 255, blue: 26 / 255, opacity: 0.72) }
    /// Noms des pieces : #eef3ff, compte #9fb0d0, sur rgba(14, 22, 48, 0,78).
    var texteNomPiece: Color { Color(.sRGB, red: 0xEE / 255, green: 0xF3 / 255, blue: 1) }
    var comptePiece: Color { Color(.sRGB, red: 0x9F / 255, green: 0xB0 / 255, blue: 0xD0 / 255) }
    var fondNomPiece: Color { Color(.sRGB, red: 14 / 255, green: 22 / 255, blue: 48 / 255, opacity: 0.78) }
    /// Reperes « ailleurs » : #b8c4dc sur rgba(6, 10, 26, 0,78), bordure en tirets a 0,5 ; fil vert.
    var texteAilleurs: Color { Color(.sRGB, red: 0xB8 / 255, green: 0xC4 / 255, blue: 0xDC / 255) }
    var fondAilleurs: Color { Color(.sRGB, red: 6 / 255, green: 10 / 255, blue: 26 / 255, opacity: 0.78) }
    var filAilleurs: Color { appareil(.joignable) }
    /// Traits de rappel des noms : rgba(230, 236, 250, 0,45).
    var trait: Color { Color(.sRGB, red: 230 / 255, green: 236 / 255, blue: 250 / 255, opacity: 0.45) }
    /// « ⌂ Maison » : blanc a 0,9, ombre noire.
    var texteMaison: Color { Color(white: 1, opacity: 0.9) }
    /// Sphere de la maison : liseré (0,55 ; 0,72 ; 1,0) et equateur #dfe6f3.
    var bulle: Color { Color(.sRGB, red: 0.55, green: 0.72, blue: 1.0) }
    var equateur: Color { Color(.sRGB, red: 0xDF / 255, green: 0xE6 / 255, blue: 0xF3 / 255) }

    /// Liseré de la sphere : l'alpha de la maquette, force (0,02 + 0,45 (1 - |n.v|)^2,5), ou |n.v| vaut
    /// racine(1 - rho^2) a la distance rho du centre du disque ; echantillonne plus serre vers le bord.
    func degradeBulle(force: Double) -> Gradient {
        let rhos: [Double] = [0, 0.35, 0.55, 0.68, 0.77, 0.84, 0.89, 0.925, 0.95, 0.968, 0.98, 0.989, 0.995, 1]
        return Gradient(stops: rhos.map { rho in
            let f = pow(1 - (max(0, 1 - rho * rho)).squareRoot(), 2.5)
            return Gradient.Stop(color: bulle.opacity(force * (0.02 + 0.45 * f)), location: rho)
        })
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageThreadTests/NomsSceneTests`
Expected: `Test run with 7 tests in 1 suite passed` (`NomsSceneTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes, en français et en anglais.** Le Step 4 a compilé : mettre le catalogue à jour avec les clés que le compilateur a extraites.

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" outils/synchroniser-textes.sh
```

Expected : `Localizable.xcstrings` reçoit exactement ces 5 clés : « %lld appareils », « 1 appareil », « Autres pièces », « Maison », « Sans pièce ».

Puis les traductions, par ce script, qui ajoute les nouvelles à `interface.json` et garde le fichier trié au format de l'outil ; `outils/traduire.py` retire ensuite du catalogue les clés périmées et donne l'anglais aux nouvelles :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "%lld appareils": "%lld devices",
    "1 appareil": "1 device",
    "Autres pièces": "Other rooms",
    "Maison": "Home",
    "Sans pièce": "No room",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

Expected : aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 332 tests in 35 suites passed` (cœur) et `Test run with 254 tests in 28 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 7 tests et 1 suite de plus pour l'app.

- [ ] **Step 7 : commit.**

```bash
git add MaillageThread/Vues/Pieces/LibellesNoeuds.swift MaillageThread/Vues/Pieces/StylesNoms.swift MaillageThread/Vues/Pieces/DessinNoeud.swift MaillageThread/Vues/Pieces/MesureNoms.swift MaillageThread/Vues/Pieces/EntreeScene.swift MaillageThread/Vues/Graphe/Palette.swift MaillageThreadTests/NomsSceneTests.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Nommer, dessiner et mesurer les noeuds de la vue par pieces

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 11: App : le moteur `Canvas` (rendu, horloge, gestes, double-clic, disposition hors du fil principal)

**Files:**
- Create: `MaillageThread/Vues/Pieces/RenduCanvas.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift`
- Modify (par les outils) : `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings`
- Test: `MaillageThreadTests/MoteurPiecesTests.swift`

**Interfaces:**
- Consumes :
  - tout le cœur de la scène (tâches 2 à 8) ; `LibellesNoeuds`, `StylesNoms`, `DessinNoeud`, `MesureNoms`, `EntreeScene`, `Palette` (tâche 10) ; dans les tests, `NomsSceneTests.demo()`.
- Produces :
  - `struct TextesScene`, `struct ImagePieces`, `@MainActor final class CacheTextes` (`resolu(_:_:echelle:_:)`) ; `@MainActor enum RenduCanvas` : `Couche` et `couches` (l'ordre de la spec : plateaux, blocs, liens enfant → parent, liens entre routeurs, pastilles, sphère, traits, noms), `dessiner(_:_:palette:cache:)` ;
  - `enum LigneNiveau` (`.isolee(String)`, `.pieces`, `.routeurs`, `.masques(Int)`, `.lisibles`) ; `enum CibleMenu` (`.aucune`, `.etage(Int)`, `.fond`) ;
  - `@MainActor @Observable final class MoteurPieces` : `init(troisD: Bool = false, fichierPlaces: URL? = nil, selection: String? = nil)` ; lus par les vues : `troisD`, `rotation`, `anime`, `isolee`, `selection`, `ligneNiveau`, `cibleMenu`, `places`, `pret`, `reduire` ; `recevoir(_:)` (disposition hors du fil principal, scène en attente pendant un mouvement), `installerMaintenant(_:)` ; `deplacerEtage(_:de:)`, `peutDeplacerEtage(_:de:)`, `replacerPieces()`, `recadrer()`, `basculer(troisD:)`, `isoler(_:)`, `sortir(enFondu: Bool = false)`, `doubleCliquer()`, `basculerRotation()` ; `image(_:taille:echelle:palette:)` (une image : avance l'état, projette, place les noms, dessine) ; `doitContinuer(_:)`, `reveiller()` ; gestes : `survoler(_:)`, `cible(en:) -> CibleMenu`, `glisser(_:depart:)`, `relacher(_:a instant: Double = MoteurPieces.maintenant())` (un second clic sur le fond, à moins de `NSEvent.doubleClickInterval` et de 5 points, est un double-clic), `cliquer(_:)`, `molette(_:precis:)`, `pincer(_:en:)`, `finPincement()`, `ecouter()` et `arreterEcoute()` (molette et Échap de sa fenêtre seulement) ; pour les captures et les tests : `fige`, `marges`, `poserBascule(_:)`, `poserIsolement(_:)`, `poserSurvol(_:)`, `poserAzimut(_:)`, `centrePiece(_:)`, `poserZoom(echelle:vers:)`, `poserTaille(_:)`, `projetee`.

Le moteur de la vue (spec, sections 4.3, 5 et 7). Ce que les vues SwiftUI observent est peu de chose (mode, rotation, horloge, pièce isolée, sélection, ligne de niveau, menu, places) ; le reste change à chaque image sans relancer leur corps (`@ObservationIgnored`). L'horloge ne tourne que pendant un mouvement et 0,6 s après : aucune image au repos. Une scène qui arrive pendant l'envol ou un vol attend la fin du mouvement ; si sa structure change, la disposition se calcule dans une tâche détachée, l'ancienne restant affichée.

**Double-clic sur le fond** (précision 17, reco validée le 30/09) : `relacher` garde l'instant et le point du dernier clic sur le fond ; le premier clic agit tout de suite comme un clic à côté (fiche fermée, pièce isolée relâchée), le second fait `doubleCliquer()`, c'est-à-dire `sortir(enFondu: true)` : zoom et déplacement annulés, par le vol de 1,3 s, ou, avec « Réduire les animations », par le fondu de 0,3 s de la bascule (`Fondu`, qui porte alors la caméra d'arrivée). Le test pose les instants à la main.

- [ ] **Step 1 : écrire les tests.**

`MaillageThreadTests/MoteurPiecesTests.swift` (fichier entier) :

```swift
import AppKit
import Foundation
import MaillageCoeur
import simd
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : moteur et rendu")
struct MoteurPiecesTests {
    static let taille = CGSize(width: 1200, height: 800)

    /// Un moteur sur la demo, dispose, et une premiere image dessinee (hors fenetre).
    static func moteur(fichier: URL? = nil) throws -> (MoteurPieces, EntreeScene) {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces(fichierPlaces: fichier)
        m.marges = (84, 50)
        m.poserTaille(taille)
        m.installerMaintenant(e)
        dessiner(m)
        return (m, e)
    }

    static func dessiner(_ m: MoteurPieces) {
        let rendu = ImageRenderer(content: Canvas { ctx, t in
            m.image(&ctx, taille: t, echelle: 1, palette: Palette(sombre: true))
        }.frame(width: taille.width, height: taille.height))
        _ = rendu.cgImage
    }

    static func fichier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("pieces-\(UUID().uuidString)/positions-pieces.json")
    }

    /// Un point d'une piece, hors de ses pastilles et des noms : pres du coin bas droit de son dessus.
    static func pointDePiece(_ m: MoteurPieces, _ i: Int) throws -> CGPoint {
        let a = try #require(m.projetee?.ancresPieces[i])
        return CGPoint(x: a.maxX - 3, y: a.maxY - 3)
    }

    static func indice(_ e: EntreeScene, _ nom: String) throws -> Int {
        try #require(e.scene.pieces.firstIndex { $0.nom == .maison(nom) })
    }

    /// Disposition installee, premiere image : un nom par noeud, etage et piece, et « ⌂ Maison » ;
    /// la ligne de niveau suit le zoom.
    @Test func installerEtDessiner() throws {
        let (m, e) = try Self.moteur()
        #expect(m.pret)
        #expect(m.positions.count == e.scene.pieces.count && m.geometrie.rayons.count == 2)
        #expect(m.etiquettes.count == e.scene.noeuds.count + e.scene.etages.count + e.scene.pieces.count + 1)
        #expect(m.projetee?.blocs.count == e.scene.pieces.count)
        #expect(m.etiquettes.contains { $0.vu })
        m.fige = true
        Self.dessiner(m)
        #expect(m.ligneNiveau != .isolee(""))
    }

    /// Clic sur une piece : elle s'isole (le fil la nomme) ; sur un appareil : sa fiche ; a cote : la
    /// fiche se ferme et la vue revient a la maison.
    @Test func clics() throws {
        let (m, e) = try Self.moteur()
        let salon = try Self.indice(e, "Salon")
        m.cliquer(try Self.pointDePiece(m, salon))
        #expect(m.estIsolee && m.focus == salon && m.isolee == "Salon")
        let disque = try #require(m.projetee?.disques.first { $0.noeud == "Apple TV 4K" })
        m.cliquer(disque.centre)
        #expect(m.selection == "Apple TV 4K")
        m.cliquer(CGPoint(x: 5, y: Self.taille.height / 2))
        #expect(m.selection == nil && !m.estIsolee && m.isolee == nil)
    }

    /// Glisser une piece la deplace dans son etage, sans sortir du plateau ; au relachement, sa place
    /// est gardee sur disque.
    @Test func glisserUnePiece() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.moteur(fichier: url)
        let cuisine = try Self.indice(e, "Cuisine")
        let avant = m.positions[cuisine]
        let depart = try Self.pointDePiece(m, cuisine)
        m.glisser(depart, depart: depart)
        m.glisser(CGPoint(x: depart.x + 30, y: depart.y), depart: depart)
        m.glisser(CGPoint(x: depart.x + 5000, y: depart.y), depart: depart)
        m.relacher(CGPoint(x: depart.x + 5000, y: depart.y))
        let apres = m.positions[cuisine]
        #expect(apres.x > avant.x)
        let r = m.geometrie.rayons[e.scene.pieces[cuisine].etage]
            - 0.5 * hypot(m.cartes[cuisine].largeur, m.cartes[cuisine].profondeur)
        #expect(simd_length(apres) <= r + 1e-9, "borne au plateau")
        #expect(!m.estIsolee, "un glisser n'isole pas")
        let gardee = PlacesGardees.lire(url).maison(e.domicile).etages["zone:Rez-de-chaussée"]?["piece:Cuisine"]
        #expect(gardee == PlacesGardees.Place(x: apres.x, z: apres.y))
    }

    /// Clics droits : l'ordre des etages change et se garde ; « Replacer les pieces automatiquement »
    /// oublie les places, pas l'ordre.
    @Test func etagesEtReplacement() throws {
        let url = Self.fichier()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let (m, e) = try Self.moteur(fichier: url)
        #expect(m.peutDeplacerEtage(0, de: 1) && !m.peutDeplacerEtage(1, de: 1) && !m.peutDeplacerEtage(0, de: -1))
        m.deplacerEtage(0, de: 1)
        #expect(m.places.maison(e.domicile).ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
        let depart = try Self.pointDePiece(m, 0)
        m.glisser(depart, depart: depart)
        m.glisser(CGPoint(x: depart.x + 20, y: depart.y), depart: depart)
        m.relacher(CGPoint(x: depart.x + 20, y: depart.y))
        #expect(!m.places.maison(e.domicile).etages.isEmpty)
        m.replacerPieces()
        #expect(m.places.maison(e.domicile).etages.isEmpty)
        #expect(PlacesGardees.lire(url).maison(e.domicile).ordreEtages == ["zone:Étage", "zone:Rez-de-chaussée"])
    }

    /// Bascule : un envol, ou un fondu si « Reduire les animations » ; une piece isolee est relachee.
    /// Une scene recue pendant le mouvement attend sa fin.
    @Test func basculeEtAttente() throws {
        let (m, e) = try Self.moteur()
        m.cliquer(try Self.pointDePiece(m, try Self.indice(e, "Salon")))
        m.basculer(troisD: true)
        #expect(m.troisD && m.enMouvement && m.focus == nil && m.isolee == nil)
        var autre = e
        autre.libelles["56B1E064401F74EF"] = LibellesNoeuds.Libelle(texte: "Pont Halo")
        m.recevoir(autre)
        #expect(m.entree == e, "pendant l'envol, la scene attend")
        let r = MoteurPieces(troisD: true)
        r.reduire = true
        r.marges = (84, 50)
        r.poserTaille(Self.taille)
        r.installerMaintenant(e)
        #expect(r.t == 1)
        r.basculer(troisD: false)
        #expect(!r.troisD && r.enMouvement)
    }

    /// Une scene qui change de noms : sa disposition se calcule hors du fil principal, et l'ancienne
    /// scene reste affichee pendant ce temps ; la nouvelle vient ensuite, avec ses cartes.
    @Test(.timeLimit(.minutes(1))) func nouvelleDisposition() async throws {
        let (m, e) = try Self.moteur()
        var autre = e
        autre.libelles["56B1E064401F74EF"] = LibellesNoeuds.Libelle(texte: "Pont du bureau, sous la lampe de l'écran")
        #expect(autre.cleDisposition != e.cleDisposition)
        m.recevoir(autre)
        #expect(m.entree == e, "l'ancienne disposition reste affichee")
        while m.entree != autre { try await Task.sleep(for: .milliseconds(10)) }
        let bureau = try Self.indice(autre, "Bureau")
        #expect(m.cartes[bureau].largeur > 0 && m.positions.count == autre.scene.pieces.count)
    }

    /// Zoom : la vue est touchee, un redimensionnement ne la recadre plus ; Echap y ramene.
    @Test func zoomEtRetour() throws {
        let (m, _) = try Self.moteur()
        let avant = m.orbite
        m.molette(-20, precis: false)
        #expect(m.vueTouchee)
        m.sortir()
        #expect(!m.vueTouchee && m.enMouvement)
        #expect(m.orbite == avant, "le vol part de la vue courante")
    }

    /// Double-clic sur le fond : retour a la vue d'ensemble d'un geste, zoom et deplacement annules, par
    /// le vol ; le premier clic a agi seul (clic a cote). Deux clics trop espaces, dans le temps ou sur
    /// l'ecran, ne sont que deux clics. « Reduire les animations » : un fondu, la camera ne saute qu'a
    /// mi-chemin.
    @Test func doubleClicSurLeFond() throws {
        let fond = CGPoint(x: 5, y: Self.taille.height / 2)
        let (m, e) = try Self.moteur()
        m.molette(-20, precis: false)
        m.relacher(fond, a: 100)
        #expect(m.vueTouchee, "un clic simple a cote ne recadre pas")
        m.relacher(fond, a: 100 + NSEvent.doubleClickInterval + 0.05)
        #expect(m.vueTouchee, "trop tard : un autre clic simple")
        m.relacher(CGPoint(x: fond.x + 8, y: fond.y), a: 100 + NSEvent.doubleClickInterval + 0.1)
        #expect(m.vueTouchee, "trop loin : un autre clic simple")
        m.relacher(CGPoint(x: fond.x + 8, y: fond.y), a: 100 + NSEvent.doubleClickInterval + 0.2)
        #expect(!m.vueTouchee && m.enMouvement, "double-clic : le vol vers la vue d'ensemble")
        // Piece isolee et fiche ouverte : le premier clic les ferme, le second ne relance rien.
        let (n, _) = try Self.moteur()
        n.cliquer(try Self.pointDePiece(n, try Self.indice(e, "Salon")))
        n.selection = "Apple TV 4K"
        n.relacher(fond, a: 200)
        #expect(n.selection == nil && !n.estIsolee && n.isolee == nil)
        n.relacher(fond, a: 200.1)
        #expect(!n.vueTouchee && !n.estIsolee)
        // « Reduire les animations » : un fondu depuis la vue courante.
        let (r, _) = try Self.moteur()
        r.reduire = true
        r.molette(-20, precis: false)
        let zoomee = r.orbite
        r.relacher(fond, a: 300)
        r.relacher(fond, a: 300.1)
        #expect(!r.vueTouchee && r.enMouvement)
        #expect(r.orbite == zoomee, "la camera ne saute qu'a mi-chemin du fondu")
    }

    /// Ordre des couches : plateaux et equateur, blocs, liens enfant -> parent, liens entre routeurs,
    /// pastilles, liseré de la sphere, traits, noms.
    @Test func ordreDesCouches() {
        #expect(RenduCanvas.couches == [.plateaux, .blocs, .liensEnfants, .liensRouteurs, .pastilles, .sphere, .traits, .noms])
        #expect(Set(RenduCanvas.couches) == Set(RenduCanvas.Couche.allCases))
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageThreadTests/MoteurPiecesTests`
Expected: la compilation des tests de l'app échoue, par exemple avec `error: cannot find type 'MoteurPieces' in scope` et `error: cannot find 'MoteurPieces' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageThread/Vues/Pieces/RenduCanvas.swift` (fichier entier) :

```swift
import MaillageCoeur
import SwiftUI

/// Textes d'une image : ce que chaque nom affiche.
struct TextesScene: Equatable {
    struct Piece: Equatable {
        var nom: String
        var compte: String
    }

    var noeuds: [String: LibellesNoeuds.Libelle] = [:]
    /// Nom et compte de chaque piece, par indice.
    var pieces: [Int: Piece] = [:]
    var etages: [Int: String] = [:]
    var maison = ""
    /// Repere « ailleurs », par id de l'enfant.
    var ailleurs: [String: String] = [:]
}

/// Ce qu'une image dessine : la scene projetee, les noms poses et leurs textes.
struct ImagePieces {
    var projetee: SceneProjetee
    var etiquettes: [Etiquette]
    var traits: [PlacementNoms.Trait]
    var textes: TextesScene
    var apparences: [String: DessinNoeud.Apparence]
    /// Noeuds routeurs : leur nom en 12 points.
    var routeurs: Set<String>
    var teintesPieces: [Int: Int]
    var selection: String?
    /// Pixels par point de l'ecran.
    var echelle: Double
}

/// Textes resolus, gardes d'une image a l'autre pour une echelle d'ecran : la mise en forme d'un
/// texte est ce qui coute le plus dans une image.
@MainActor
final class CacheTextes {
    private var textes: [String: GraphicsContext.ResolvedText] = [:]
    private var echelle = 0.0

    func resolu(_ ctx: GraphicsContext, _ cle: String, echelle e: Double, _ texte: () -> Text) -> GraphicsContext.ResolvedText {
        if e != echelle {
            textes.removeAll()
            echelle = e
        }
        if let r = textes[cle] { return r }
        let r = ctx.resolve(texte())
        textes[cle] = r
        return r
    }
}

/// Dessin d'une image de la vue par pieces dans un `Canvas` (spec, section 5), couche par couche,
/// sans tri de profondeur global.
@MainActor
enum RenduCanvas {
    enum Couche: CaseIterable {
        case plateaux, blocs, liensEnfants, liensRouteurs, pastilles, sphere, traits, noms
    }

    /// Ordre des couches, de la plus basse a la plus haute : plateaux et equateur, blocs, liens enfant
    /// -> parent (avec les rattachements et les fils « ailleurs »), liens entre routeurs, pastilles (et
    /// l'anneau de la selection), liseré de la sphere, traits de rappel, noms.
    static let couches: [Couche] = [.plateaux, .blocs, .liensEnfants, .liensRouteurs, .pastilles, .sphere, .traits, .noms]

    private static let grand = StylesNoms.grand

    static func dessiner(_ ctx: inout GraphicsContext, _ image: ImagePieces, palette: Palette, cache: CacheTextes) {
        for c in couches {
            switch c {
            case .plateaux: dessinerPlateaux(&ctx, image, palette)
            case .blocs: dessinerBlocs(&ctx, image)
            case .liensEnfants: dessinerLiensEnfants(&ctx, image, palette)
            case .liensRouteurs: dessinerLiensRouteurs(&ctx, image, palette)
            case .pastilles: dessinerPastilles(&ctx, image, palette)
            case .sphere: dessinerSphere(&ctx, image, palette)
            case .traits: dessinerTraits(&ctx, image, palette)
            case .noms: dessinerNoms(&ctx, image, palette, cache)
            }
        }
    }

    static func chemin(_ points: [CGPoint], ferme: Bool) -> Path {
        var p = Path()
        p.addLines(points)
        if ferme { p.closeSubpath() }
        return p
    }

    static func segment(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        return p
    }

    /// Plateaux (degrade radial de la couleur de zone, 0,26 au centre, 0,08 au bord ; contour d'un
    /// pixel a 0,45) et equateur, du plus loin au plus proche.
    private static func dessinerPlateaux(_ ctx: inout GraphicsContext, _ image: ImagePieces, _ palette: Palette) {
        let pixel = 1 / image.echelle
        let p = image.projetee
        var fond = p.plateaux.indices.map { (p.plateaux[$0].profondeur, $0) }
        if let eq = p.equateur { fond.append((eq.profondeur, -1)) }
        let degrade = Gradient(colors: [palette.zone.opacity(0.26), palette.zone.opacity(0.08)])
        for (_, i) in fond.sorted(by: { $0.0 > $1.0 }) {
            if i < 0, let eq = p.equateur {
                for m in eq.contour {
                    ctx.stroke(chemin(m, ferme: false), with: .color(palette.equateur.opacity(eq.opacite)), lineWidth: pixel)
                }
                continue
            }
            let pl = p.plateaux[i]
            var g = ctx
            g.opacity = pl.opacite
            let forme = chemin(pl.polygone, ferme: true)
            if let m = pl.disque {
                var d = g
                d.concatenate(m)
                d.fill(forme.applying(m.inverted()), with: .radialGradient(degrade, center: .zero, startRadius: 0, endRadius: 1))
            }
            for m in pl.contour {
                g.stroke(chemin(m, ferme: false), with: .color(palette.zone.opacity(0.45)), lineWidth: pixel)
            }
        }
    }

    /// Blocs de verre, du plus loin au plus proche : faces visibles eclairees, puis aretes d'un pixel.
    private static func dessinerBlocs(_ ctx: inout GraphicsContext, _ image: ImagePieces) {
        let pixel = 1 / image.echelle
        for b in image.projetee.blocs {
            for f in b.faces {
                ctx.fill(chemin(f.points, ferme: true), with: .color(Palette.couleur(f.teinte).opacity(b.opaciteVerre)))
            }
            var aretes = Path()
            for (a, c) in b.aretes {
                aretes.move(to: a)
                aretes.addLine(to: c)
            }
            ctx.stroke(aretes, with: .color(Palette.couleur(b.teinte).opacity(b.opaciteAretes)), lineWidth: pixel)
        }
    }

    /// Liens enfant -> parent d'un pixel ; rattachements supposes en pointilles ; fils « ailleurs »
    /// en tirets verts.
    private static func dessinerLiensEnfants(_ ctx: inout GraphicsContext, _ image: ImagePieces, _ palette: Palette) {
        let pixel = 1 / image.echelle
        for l in image.projetee.liensEnfants {
            let couleur = palette.encre.opacity(l.opacite)
            if l.genre == .rattachement {
                ctx.stroke(segment(l.a, l.b), with: .color(couleur),
                           style: StrokeStyle(lineWidth: l.eclaire ? 1.6 : 1, dash: [2, 4]))
            } else {
                ctx.stroke(segment(l.a, l.b), with: .color(couleur), lineWidth: pixel)
            }
        }
        for f in image.projetee.fils {
            ctx.stroke(segment(f.a, f.b), with: .color(palette.filAilleurs.opacity(f.opacite)),
                       style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
    }

    /// Liens radio entre routeurs : 2 points, couleurs de qualite, bouts ronds.
    private static func dessinerLiensRouteurs(_ ctx: inout GraphicsContext, _ image: ImagePieces, _ palette: Palette) {
        for l in image.projetee.liensRouteurs {
            ctx.stroke(segment(l.a, l.b), with: .color(palette.lienSonde(l.qualite).opacity(l.opacite)),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// Pastilles, du plus loin au plus proche, puis l'anneau de la selection.
    private static func dessinerPastilles(_ ctx: inout GraphicsContext, _ image: ImagePieces, _ palette: Palette) {
        for d in image.projetee.disques {
            guard let a = image.apparences[d.noeud] else { continue }
            var g = ctx
            g.opacity = d.opacite
            DessinNoeud.dessiner(&g, centre: d.centre, rayon: d.rayon, apparence: a, palette: palette)
            if d.noeud == image.selection {
                DessinNoeud.dessinerSelection(&g, centre: d.centre, rayon: d.rayon, palette: palette)
            }
        }
    }

    /// Liseré de la sphere : transparent au centre, lumineux au bord de son contour exact.
    private static func dessinerSphere(_ ctx: inout GraphicsContext, _ image: ImagePieces, _ palette: Palette) {
        guard let sp = image.projetee.sphere else { return }
        var g = ctx
        g.concatenate(sp.transfo)
        g.fill(Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
               with: .radialGradient(palette.degradeBulle(force: sp.force), center: .zero, startRadius: 0, endRadius: 1))
    }

    private static func dessinerTraits(_ ctx: inout GraphicsContext, _ image: ImagePieces, _ palette: Palette) {
        var traits = Path()
        for t in image.traits {
            traits.move(to: t.depart)
            traits.addLine(to: t.arrivee)
        }
        ctx.stroke(traits, with: .color(palette.trait), lineWidth: 1)
    }

    /// Aligne sur les pixels de l'ecran : un texte net.
    private static func aligner(_ v: CGFloat, _ echelle: Double) -> CGFloat { (v * echelle).rounded() / echelle }

    /// Noms poses : immobiles, alignes sur les pixels ; en mouvement, a leur place fractionnaire.
    private static func dessinerNoms(_ ctx: inout GraphicsContext, _ image: ImagePieces, _ palette: Palette,
                                     _ cache: CacheTextes) {
        let e = image.echelle
        for l in image.etiquettes where l.vu {
            var g = ctx
            if l.pale { g.opacity = 0.45 }
            let r = l.immobile
                ? CGRect(x: aligner(l.rect.minX, e), y: aligner(l.rect.minY, e), width: l.rect.width, height: l.rect.height)
                : l.rect
            switch l.genre {
            case .noeud(let id):
                guard let libelle = image.textes.noeuds[id] else { continue }
                let routeur = image.routeurs.contains(id)
                let texte = cache.resolu(g, "n|\(routeur)|\(l.fort)|" + libelle.texte, echelle: e) {
                    StylesNoms.noeud(libelle.texte, routeur: routeur, fort: l.fort)
                        .foregroundStyle(l.fort ? .white : palette.texteNom)
                }
                g.fill(Path(roundedRect: r, cornerRadius: 4), with: .color(palette.fondNom))
                g.draw(texte, at: CGPoint(x: r.minX + 5, y: r.midY), anchor: .leading)
                if let p = libelle.pastille {
                    let largeur = ceil(texte.measure(in: grand).width)
                    DessinNoeud.dessinerPastille(&g, p, gauche: CGPoint(x: r.minX + 5 + largeur + 5, y: r.midY),
                                                 palette: palette)
                }
            case .piece(let i):
                guard let t = image.textes.pieces[i] else { continue }
                let couleur = Palette.teintePiece(image.teintesPieces[i] ?? 0)
                g.fill(Path(roundedRect: r, cornerRadius: 6), with: .color(palette.fondNomPiece))
                g.stroke(Path(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 5.5),
                         with: .color(couleur.opacity(0.6)), lineWidth: 1)
                let nom = cache.resolu(g, "pn|" + t.nom, echelle: e) {
                    StylesNoms.nomPiece(t.nom).foregroundStyle(palette.texteNomPiece)
                }
                let compte = cache.resolu(g, "pc|" + t.compte, echelle: e) {
                    StylesNoms.comptePiece(t.compte).foregroundStyle(palette.comptePiece)
                }
                let tn = nom.measure(in: grand)
                let haut = l.immobile ? aligner(r.midY - tn.height / 2, e) : r.midY - tn.height / 2
                let ligne = haut + nom.firstBaseline(in: grand)
                let x = r.minX + 8
                // Le point pose sur la ligne de base, comme dans la maquette.
                g.fill(Path(ellipseIn: CGRect(x: x, y: ligne - 8, width: 8, height: 8)), with: .color(couleur))
                g.draw(nom, at: CGPoint(x: x + 14, y: haut), anchor: .topLeading)
                g.draw(compte, at: CGPoint(x: x + 14 + ceil(tn.width) + 6, y: ligne - compte.firstBaseline(in: grand)),
                       anchor: .topLeading)
            case .etage(let i):
                guard let nom = image.textes.etages[i] else { continue }
                let texte = cache.resolu(g, "e|" + nom, echelle: e) {
                    StylesNoms.etage(nom).foregroundStyle(palette.zone.opacity(0.95))
                }
                g.draw(texte, at: r.origin, anchor: .topLeading)
            case .maison:
                let texte = image.textes.maison
                g.drawLayer { c in
                    c.addFilter(.shadow(color: .black, radius: 1.5, x: 0, y: 1))
                    let resolu = cache.resolu(c, "m|" + texte, echelle: e) {
                        StylesNoms.maison(texte).foregroundStyle(palette.texteMaison)
                    }
                    c.draw(resolu, at: r.origin, anchor: .topLeading)
                }
            case .ailleurs(let id):
                guard let texte = image.textes.ailleurs[id] else { continue }
                let forme = Path(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 4)
                g.fill(forme, with: .color(palette.fondAilleurs))
                g.stroke(forme, with: .color(palette.texteAilleurs.opacity(0.5)),
                         style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                let resolu = cache.resolu(g, "a|" + texte, echelle: e) {
                    StylesNoms.ailleurs(texte).foregroundStyle(palette.texteAilleurs)
                }
                g.draw(resolu, at: CGPoint(x: r.minX + 6, y: r.midY), anchor: .leading)
            }
        }
    }
}
```

`MaillageThread/Vues/Pieces/MoteurPieces.swift` (fichier entier) :

```swift
import AppKit
import MaillageCoeur
import os
import QuartzCore
import SwiftUI
import simd

/// Ligne de niveau, en bas a gauche de la vue (spec de la vue par pieces, section 6).
enum LigneNiveau: Equatable {
    case isolee(String)
    case pieces
    case routeurs
    case masques(Int)
    case lisibles
}

/// Cible d'un clic droit : un nom d'etage, ou le fond (spec, section 7).
enum CibleMenu: Equatable {
    case aucune
    case etage(Int)
    case fond
}

/// Moteur de la vue par pieces (spec, sections 4 a 7) : la scene recue et sa disposition, calculee
/// hors du fil principal ; la camera et ses animations (envol, vols, isolement, rotation lente,
/// amortis) ; les gestes ; les places gardees ; et chaque image du `Canvas`. SwiftUI n'observe que ce
/// que les vues autour lisent (mode, rotation, horloge, piece isolee, selection, ligne de niveau,
/// menu, places) : le reste change a chaque image sans relancer leur corps.
@MainActor
@Observable
final class MoteurPieces {
    /// Mode vise : 3D ou 2D (l'envol peut etre en cours).
    private(set) var troisD: Bool
    var rotation = true
    /// Horloge en marche : seulement pendant un mouvement, et 0,6 s apres.
    private(set) var anime = true
    /// Nom de la piece isolee (le fil) ; nil sinon.
    private(set) var isolee: String?
    var selection: String?
    private(set) var ligneNiveau = LigneNiveau.lisibles
    private(set) var cibleMenu = CibleMenu.aucune
    private(set) var places: PlacesGardees
    /// La premiere disposition est calculee.
    private(set) var pret = false
    /// « Reduire les animations » (accessibilite de macOS).
    var reduire = false {
        didSet { reveiller() }
    }

    nonisolated static let journal = Logger(subsystem: "fr.djoko.maillage", category: "pieces")

    // MARK: Etat non observe

    @ObservationIgnored private let fichierPlaces: URL?
    /// Scene affichee, posee sur sa disposition.
    @ObservationIgnored private(set) var entree: EntreeScene?
    /// Scene recue pendant un mouvement : appliquee a sa fin.
    @ObservationIgnored private var attente: EntreeScene?
    /// Scene dont la disposition se calcule : `entree` reste affichee jusqu'a la fin du calcul.
    @ObservationIgnored private var enCalcul: EntreeScene?
    @ObservationIgnored private var calcul: Task<Void, Never>?
    @ObservationIgnored private var cleCalculee: [String: [String: [String]]]?
    @ObservationIgnored private var placesCalculees: [String: SIMD2<Double>] = [:]
    @ObservationIgnored private var rayonsCalcules: [String: Double] = [:]
    @ObservationIgnored private var cartesCalculees: [String: CartesPieces.Carte] = [:]
    @ObservationIgnored private(set) var cartes: [CartesPieces.Carte] = []
    @ObservationIgnored private(set) var positions: [SIMD2<Double>] = []
    @ObservationIgnored private(set) var geometrie = GeometrieMaison(rayons: [])
    @ObservationIgnored private(set) var orbite = Orbite(cible: .zero, distance: 1000, azimut: 0, inclinaison: 0.0001, champ: 2)
    @ObservationIgnored private var taille = CGSize.zero
    /// Marges du haut (barre, bandeaux) et du bas (legende, fiche) : la place utile de la vue d'ensemble.
    @ObservationIgnored var marges: (haut: CGFloat, bas: CGFloat) = (0, 0)
    @ObservationIgnored private(set) var cadre = CGRect(x: 0, y: 0, width: 1, height: 1)
    /// Bascule adoucie : 0 en 2D, 1 en 3D.
    @ObservationIgnored private(set) var t: Double
    @ObservationIgnored private var envol: Envol?
    @ObservationIgnored private var debutEnvol = 0.0
    /// « Reduire les animations » : l'envol, et le retour a la vue d'ensemble par double-clic, sont un
    /// fondu ; la camera saute a mi-chemin.
    @ObservationIgnored private var fondu: Fondu?
    @ObservationIgnored private var opaciteFondu = 1.0
    /// Isolement : `s` general, `fk` propre a chaque piece.
    @ObservationIgnored private(set) var s = 0.0
    @ObservationIgnored private var sCible = 0.0
    @ObservationIgnored private var sDepart = 0.0
    @ObservationIgnored private var sDebut = 0.0
    @ObservationIgnored private(set) var focus: Int?
    @ObservationIgnored private(set) var fk: [Double] = []
    @ObservationIgnored private var vol: Vol?
    @ObservationIgnored private var debutVol = 0.0
    @ObservationIgnored private(set) var survol: String?
    @ObservationIgnored private var curseur: CGPoint?
    @ObservationIgnored private var zoomEnAttente = 0.0
    @ObservationIgnored private var ancreZoom: SIMD3<Double>?
    @ObservationIgnored private var dernierPincement = 1.0
    @ObservationIgnored private var rotationEnAttente = SIMD2<Double>.zero
    @ObservationIgnored private var geste: Geste?
    @ObservationIgnored private var bouge = false
    @ObservationIgnored private var precedent = CGPoint.zero
    @ObservationIgnored private var derniereActivite = 0.0
    @ObservationIgnored private var instant: Double?
    @ObservationIgnored private var dt = 0.0
    /// Djoko a zoome ou deplace la vue : un redimensionnement ne la recadre plus.
    @ObservationIgnored private(set) var vueTouchee = false
    @ObservationIgnored private(set) var etiquettes: [Etiquette] = []
    @ObservationIgnored private(set) var textes = TextesScene()
    /// Noeuds routeurs (leur nom en 12 points) et teinte de chaque piece, pour le dessin.
    @ObservationIgnored private var routeurs: Set<String> = []
    @ObservationIgnored private var teintes: [Int: Int] = [:]
    @ObservationIgnored private(set) var projetee: SceneProjetee?
    @ObservationIgnored private var traits: [PlacementNoms.Trait] = []
    /// Cles des pieces et des etages de la scene des noms : un nom garde son etat d'une scene a l'autre.
    @ObservationIgnored private var clesPieces: [String] = []
    @ObservationIgnored private var clesEtages: [String] = []
    @ObservationIgnored private let cache = CacheTextes()
    @ObservationIgnored private let mesure = MesureNoms()
    /// Ce qui est pose sur la vue (barre, fil, ligne de niveau, legende, fiche), par element : les noms
    /// l'evitent.
    @ObservationIgnored var cadresInterface: [String: CGRect] = [:]
    /// Fenetre de la vue : la molette et Echap ne valent que pour elle.
    @ObservationIgnored weak var fenetre: NSWindow?
    @ObservationIgnored private var moniteur: Any?
    /// Captures : l'etat est pose a la main, l'horloge n'avance pas.
    @ObservationIgnored var fige = false

    /// Dernier clic sur le fond (instant, point) : un second, assez pres et assez tot, est un double-clic.
    @ObservationIgnored private var clicFond: (instant: Double, point: CGPoint)?

    private enum Geste {
        case fond
        /// Une piece qu'on glisse, sur le plan horizontal y = `hauteur`.
        case piece(Int, hauteur: Double)
    }

    /// Fondu de 0,3 s par le fond (« Reduire les animations ») : la scene s'efface, la camera saute a
    /// mi-chemin, la scene revient.
    private struct Fondu {
        var debut: Double
        /// Avancement de la bascule vise : 0 en 2D, 1 en 3D (le meme pour un retour a la vue d'ensemble).
        var arrivee: Double
        /// Camera a mi-chemin : la fin du vol (retour a la vue d'ensemble) ; nil : la vue d'ensemble du
        /// mode vise (bascule).
        var orbite: Orbite?
        var saute = false
    }

    /// `troisD` : le mode garde ; `fichierPlaces` : `positions-pieces.json` (nil : ni lu ni ecrit).
    init(troisD: Bool = false, fichierPlaces: URL? = nil, selection: String? = nil) {
        self.troisD = troisD
        t = troisD ? 1 : 0
        self.fichierPlaces = fichierPlaces
        places = fichierPlaces.map(PlacesGardees.lire) ?? PlacesGardees()
        self.selection = selection
    }

    static func maintenant() -> Double { CACurrentMediaTime() }

    var scene: ScenePieces? { entree?.scene }
    var aspect: Double { cadre.height > 0 ? Double(cadre.width / cadre.height) : 1.6 }
    /// Une piece est isolee (et non en train d'etre quittee).
    var estIsolee: Bool { focus != nil && sCible == 1 }
    var enMouvement: Bool { envol != nil || fondu != nil || vol != nil }

    // MARK: Scene et disposition

    /// Nouvelle scene : appliquee tout de suite, ou a la fin du mouvement en cours (envol, vol). Si
    /// ses etages, ses pieces, ses noeuds ou leurs noms changent, la disposition est recalculee hors
    /// du fil principal ; l'ancienne reste affichee pendant ce temps.
    func recevoir(_ e: EntreeScene) {
        if enMouvement {
            attente = e
            return
        }
        appliquer(e)
    }

    private func appliquer(_ e: EntreeScene) {
        attente = nil
        let cle = e.cleDisposition
        if cle == cleCalculee {
            calcul?.cancel()
            enCalcul = nil
            installer(e)
            return
        }
        // Meme structure que la disposition en calcul : elle vaudra pour cette scene.
        if enCalcul?.cleDisposition == cle {
            enCalcul = e
            return
        }
        calcul?.cancel()
        enCalcul = e
        let cartes = cartesPour(e)
        let fixees = places.fixees(e.scene, domicile: e.domicile)
        let scene = e.scene
        calcul = Task { [weak self] in
            let d = await Task.detached(priority: .userInitiated) {
                DispositionPieces(scene: scene, cartes: cartes, fixees: fixees)
            }.value
            guard !Task.isCancelled, let self else { return }
            self.retenir(d, cartes: cartes, cle: cle)
        }
    }

    /// La meme chose, sur le fil principal (captures, tests).
    func installerMaintenant(_ e: EntreeScene) {
        calcul?.cancel()
        let cartes = cartesPour(e)
        let d = DispositionPieces(scene: e.scene, cartes: cartes, fixees: places.fixees(e.scene, domicile: e.domicile))
        enCalcul = e
        retenir(d, cartes: cartes, cle: e.cleDisposition)
    }

    /// Cartes des pieces d'une scene, d'apres les noms mesures des noeuds.
    private func cartesPour(_ e: EntreeScene) -> [CartesPieces.Carte] {
        var largeurs: [String: Double] = [:]
        for n in e.scene.noeuds {
            guard let l = e.libelles[n.id] else { continue }
            largeurs[n.id] = mesure.noeud(l, routeur: n.rang <= 2).width
        }
        return CartesPieces.cartes(e.scene, largeurs: largeurs)
    }

    /// Une disposition calculee : gardee par cles (piece, etage), puis posee avec sa scene, si une
    /// scene plus recente ne l'a pas depassee ; a la fin du mouvement en cours, s'il y en a un.
    private func retenir(_ d: DispositionPieces, cartes: [CartesPieces.Carte], cle: [String: [String: [String]]]) {
        guard let e = enCalcul, e.cleDisposition == cle else { return }
        let scene = e.scene
        placesCalculees = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { (scene.pieces[$0].id, d.positions[$0]) })
        rayonsCalcules = Dictionary(uniqueKeysWithValues: scene.etages.indices.map { (scene.etages[$0].id, d.rayons[$0]) })
        cartesCalculees = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { (scene.pieces[$0].id, cartes[$0]) })
        cleCalculee = cle
        enCalcul = nil
        if enMouvement {
            if attente == nil { attente = e }
            return
        }
        installer(e)
    }

    /// Pose une scene sur la disposition gardee : positions et rayons retrouves par cles, noms,
    /// piece isolee.
    private func installer(_ e: EntreeScene) {
        let scene = e.scene
        let ancienFocus = focus.flatMap { $0 < clesPieces.count ? clesPieces[$0] : nil }
        entree = e
        cartes = scene.pieces.map { cartesCalculees[$0.id] ?? CartesPieces.carte([]) }
        positions = scene.pieces.map { placesCalculees[$0.id] ?? .zero }
        geometrie = GeometrieMaison(rayons: scene.etages.map { rayonsCalcules[$0.id] ?? DispositionPieces.marge })
        fk = Array(repeating: 0, count: scene.pieces.count)
        if let cle = ancienFocus, let i = scene.pieces.firstIndex(where: { $0.id == cle }) {
            focus = i
            fk[i] = 1
        } else if focus != nil {
            focus = nil
            s = 0
            sCible = 0
            isolee = nil
        }
        textes = Self.textes(e, focus: focus)
        routeurs = Set(scene.noeuds.filter { $0.rang <= 2 }.map(\.id))
        teintes = Dictionary(uniqueKeysWithValues: scene.pieces.indices.map { ($0, scene.pieces[$0].teinte) })
        construireEtiquettes()
        if !pret {
            pret = true
            orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        } else if !vueTouchee && focus == nil {
            recadrer()
        }
        reveiller()
    }

    /// Textes des noms : libelles, pieces (nom, compte), etages, maison, reperes « ailleurs ».
    static func textes(_ e: EntreeScene, focus: Int?) -> TextesScene {
        var t = TextesScene()
        t.noeuds = e.libelles
        for (i, p) in e.scene.pieces.enumerated() {
            t.pieces[i] = TextesScene.Piece(nom: LibellesNoeuds.nom(p.nom, libelles: e.libelles),
                                            compte: LibellesNoeuds.compte(p.noeuds.count))
        }
        for (i, et) in e.scene.etages.enumerated() { t.etages[i] = LibellesNoeuds.nom(et.nom) }
        t.maison = String(localized: "⌂ Maison")
        if let f = focus {
            for a in SceneProjetee.reperes(e.scene, focus: f) {
                t.ailleurs[a.enfant] = LibellesNoeuds.ailleurs(a, scene: e.scene, libelles: e.libelles)
            }
        }
        return t
    }

    /// Cle d'un nom, qui ne depend pas des indices de la scene.
    private func cle(_ g: Etiquette.Genre) -> String {
        switch g {
        case .noeud(let id): "n:" + id
        case .piece(let i): "p:" + (i < clesPieces.count ? clesPieces[i] : "")
        case .etage(let i): "e:" + (i < clesEtages.count ? clesEtages[i] : "")
        case .maison: "m"
        case .ailleurs(let id): "a:" + id
        }
    }

    /// Noms de la scene, dans l'ordre de la maquette (appareils, etages, pieces, maison, reperes) ;
    /// chacun garde son etat de placement d'une scene a l'autre.
    private func construireEtiquettes() {
        guard let scene else { return }
        var anciennes: [String: Etiquette] = [:]
        for l in etiquettes { anciennes[cle(l.genre)] = l }
        clesPieces = scene.pieces.map(\.id)
        clesEtages = scene.etages.map(\.id)
        var l: [Etiquette] = []
        func ajouter(_ genre: Etiquette.Genre, _ taille: CGSize) {
            var e = Etiquette(genre, taille: taille)
            if let a = anciennes[cle(genre)] {
                e.place = a.place
                e.envie = a.envie
                e.vu = a.vu
                e.rect = a.rect
                e.rectAvant = a.rectAvant
            }
            l.append(e)
        }
        for n in scene.noeuds {
            ajouter(.noeud(n.id), mesure.noeud(textes.noeuds[n.id] ?? LibellesNoeuds.Libelle(texte: n.id), routeur: n.rang <= 2))
        }
        for i in scene.etages.indices { ajouter(.etage(i), mesure.etage(textes.etages[i] ?? "")) }
        for i in scene.pieces.indices {
            let t = textes.pieces[i] ?? TextesScene.Piece(nom: "", compte: "")
            ajouter(.piece(i), mesure.piece(nom: t.nom, compte: t.compte))
        }
        ajouter(.maison, mesure.maison(textes.maison))
        for (id, texte) in textes.ailleurs.sorted(by: { $0.key < $1.key }) { ajouter(.ailleurs(id), mesure.ailleurs(texte)) }
        etiquettes = l
    }

    // MARK: Places gardees et ordre des etages

    private func enregistrer() {
        guard let fichierPlaces else { return }
        do {
            try places.ecrire(dans: fichierPlaces)
        } catch {
            Self.journal.error("places des pieces non ecrites : \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Garde la place d'une piece qu'on vient de glisser : elle est desormais fixee.
    private func garder(_ i: Int) {
        guard let e = entree, i < e.scene.pieces.count else { return }
        let p = e.scene.pieces[i]
        places.garder(positions[i], piece: p.id, etage: e.scene.etages[p.etage].id, domicile: e.domicile)
        placesCalculees[p.id] = positions[i]
        enregistrer()
    }

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
    }

    /// « Replacer les pieces automatiquement » : oublie les places gardees de la maison (pas l'ordre
    /// des etages) et recalcule la disposition ; l'ancienne reste affichee pendant ce temps.
    func replacerPieces() {
        guard let e = enCalcul ?? entree else { return }
        places.replacer(domicile: e.domicile)
        enregistrer()
        cleCalculee = nil
        enCalcul = nil
        appliquer(e)
    }

    // MARK: Camera

    /// Cadre la vue d'ensemble a l'avancement courant, en gardant l'orbite en 3D.
    func recadrer() {
        var c = CameraScene.canonique(geometrie, aspect: aspect, u: t)
        if t == 1 {
            c.azimut = orbite.azimut
            c.inclinaison = orbite.inclinaison
        }
        orbite = c
    }

    /// Bascule 2D / 3D : un envol de 2,6 s depuis la vue courante (un fondu de 0,3 s si « Reduire
    /// les animations ») ; une piece isolee est relachee.
    func basculer(troisD v: Bool) {
        guard v != troisD else { return }
        troisD = v
        focus = nil
        isolee = nil
        s = 0
        sCible = 0
        fk = fk.map { _ in 0 }
        vol = nil
        zoomEnAttente = 0
        rotationEnAttente = .zero
        vueTouchee = false
        textes = entree.map { Self.textes($0, focus: nil) } ?? textes
        construireEtiquettes()
        let arrivee = v ? 1.0 : 0.0
        if reduire {
            fondu = Fondu(debut: Self.maintenant(), arrivee: arrivee)
        } else {
            envol = Envol(depuis: orbite, t: t, vers: arrivee, geometrie: geometrie, aspect: aspect)
            debutEnvol = Self.maintenant()
        }
        reveiller()
    }

    /// Isole une piece : la camera y vole en 1,3 s (tout de suite si « Reduire les animations »), les
    /// autres s'estompent, ses reperes « ailleurs » apparaissent.
    func isoler(_ i: Int) {
        guard let scene, i < scene.pieces.count, !(focus == i && sCible == 1) else { return }
        focus = i
        isolee = textes.pieces[i]?.nom
        if sCible != 1 {
            sDepart = s
            sCible = 1
            sDebut = Self.maintenant()
        }
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        if let v = volVersPiece(i) { voler(v) }
    }

    /// Vol vers une piece, a la hauteur de vue de la spec (section 7).
    private func volVersPiece(_ i: Int) -> Vol? {
        guard let c = centrePiece(i) else { return nil }
        return CameraScene.volVersPiece(orbite, centre: c, largeur: cartes[i].largeur, profondeur: cartes[i].profondeur,
                                        aspect: aspect, troisD: t == 1)
    }

    /// Retour a la vue d'ensemble (clic a cote, Echap, « Maison » dans le fil, double-clic sur le fond) :
    /// la piece isolee est relachee, le zoom et le deplacement annules, par un vol de 1,3 s. « Reduire
    /// les animations » : tout de suite, ou par un fondu de 0,3 s (`enFondu`, le double-clic).
    func sortir(enFondu: Bool = false) {
        if focus != nil, sCible != 0 {
            sDepart = s
            sCible = 0
            sDebut = Self.maintenant()
            isolee = nil
        } else if !vueTouchee {
            return
        }
        vueTouchee = false
        voler(CameraScene.volVersEnsemble(orbite, geometrie, aspect: aspect, u: t, troisD: t == 1), enFondu: enFondu)
    }

    /// Double-clic sur le fond (precision 17 du plan 4b) : retour a la vue d'ensemble d'un geste. Le
    /// premier clic a deja ferme la fiche et relache la piece isolee (clic a cote) ; le second annule le
    /// zoom et le deplacement.
    func doubleCliquer() {
        sortir(enFondu: true)
    }

    private func voler(_ v: Vol, enFondu: Bool = false) {
        zoomEnAttente = 0
        rotationEnAttente = .zero
        if reduire && enFondu {
            fondu = Fondu(debut: Self.maintenant(), arrivee: t, orbite: v.orbite(1, depuis: orbite))
            vol = nil
        } else if reduire {
            orbite = v.orbite(1, depuis: orbite)
            vol = nil
        } else {
            vol = v
            debutVol = Self.maintenant()
        }
        reveiller()
    }

    func basculerRotation() {
        rotation.toggle()
        reveiller()
    }

    // MARK: Image

    /// Une image du `Canvas` : avance l'etat, projette la scene, place les noms, dessine.
    func image(_ ctx: inout GraphicsContext, taille nouvelle: CGSize, echelle: Double, palette: Palette) {
        // Taille ou marges changees : la vue d'ensemble se recadre, sauf si Djoko a zoome ou isole une piece.
        taille = nouvelle
        let voulu = CGRect(x: 0, y: marges.haut, width: nouvelle.width,
                           height: max(1, nouvelle.height - marges.haut - marges.bas))
        if voulu != cadre {
            cadre = voulu
            if pret && !enMouvement && !vueTouchee && focus == nil && !fige { recadrer() }
        }
        let now = Self.maintenant()
        if !fige { avancer(now) }
        guard pret, let scene else { return }
        let etat = EtatAnime(t: t, s: s, fk: fk, focus: focus, survol: survol, selection: selection)
        let p = SceneProjetee(scene: scene, cartes: cartes, positions: positions, geometrie: geometrie, etat: etat,
                              orbite: orbite, cadre: cadre)
        PlacementNoms.regler(&etiquettes, scene: scene, niveau: p.niveau, survol: survol, selection: selection, focus: focus,
                             isolee: estIsolee, fk: fk, s: s, t: t)
        let ancres: [CGRect?] = etiquettes.map { l in
            switch l.genre {
            case .noeud(let id): p.ancresNoeuds[id]
            case .piece(let i): p.ancresPieces[i]
            case .etage(let i): p.ancresEtages[i]
            case .maison: p.ancreMaison
            case .ailleurs(let id): p.ancresAilleurs[id]
            }
        }
        var obstacles = p.disques.filter { $0.opacite > 0.5 }.map { d in
            CGRect(x: Double(d.centre.x) - d.rayon, y: Double(d.centre.y) - d.rayon, width: 2 * d.rayon, height: 2 * d.rayon)
        }
        obstacles += cadresInterface.values.map { $0.insetBy(dx: -4, dy: -4) }
        traits = PlacementNoms.placer(&etiquettes, ancres: ancres, obstacles: obstacles, cadre: taille, dt: dt)
        projetee = p
        var g = ctx
        g.opacity = opaciteFondu
        RenduCanvas.dessiner(&g, ImagePieces(projetee: p, etiquettes: etiquettes, traits: traits, textes: textes,
                                             apparences: entree?.apparences ?? [:], routeurs: routeurs,
                                             teintesPieces: teintes, selection: selection, echelle: echelle),
                             palette: palette, cache: cache)
        let nouvelle = ligne(p.niveau, ancres: ancres)
        if nouvelle != ligneNiveau {
            // Hors du rendu, sauf pour une capture (rendue d'un trait).
            if fige {
                ligneNiveau = nouvelle
            } else {
                Task { @MainActor [weak self] in self?.ligneNiveau = nouvelle }
            }
        }
        if !fige && !doitContinuer(now) { endormir() }
    }

    private func ligne(_ niveau: NiveauZoom, ancres: [CGRect?]) -> LigneNiveau {
        if estIsolee, let nom = isolee { return .isolee(nom) }
        switch niveau {
        case .pieces: return .pieces
        case .routeurs: return .routeurs
        case .tous:
            let n = PlacementNoms.masques(etiquettes, ancres: ancres, cadre: taille)
            return n > 0 ? .masques(n) : .lisibles
        }
    }

    private func avancer(_ now: Double) {
        dt = instant.map { min(0.1, max(0, now - $0)) } ?? 0
        instant = now
        if let e = envol {
            let q = min(1, max(0, (now - debutEnvol) / CameraScene.dureeEnvol))
            (t, orbite) = e.pose(q, geometrie: geometrie, aspect: aspect)
            if q >= 1 {
                envol = nil
                t = e.arrivee
            }
        }
        if let f = fondu {
            let q = min(1, max(0, (now - f.debut) / CameraScene.dureeFondu))
            if q >= 0.5 && !f.saute {
                t = f.arrivee
                orbite = f.orbite ?? CameraScene.canonique(geometrie, aspect: aspect, u: t)
                fondu?.saute = true
            }
            opaciteFondu = abs(1 - 2 * q)
            if q >= 1 {
                fondu = nil
                opaciteFondu = 1
            }
        }
        if s != sCible {
            let r = min(1, max(0, (now - sDebut) / CameraScene.dureeVol))
            s = sDepart + (sCible - sDepart) * r
            if r >= 1 {
                s = sCible
                if s == 0 {
                    focus = nil
                    if let e = entree { textes = Self.textes(e, focus: nil) }
                    construireEtiquettes()
                }
            }
        }
        for i in fk.indices {
            let c: Double = focus == i && sCible == 1 ? 1 : 0
            fk[i] += (c - fk[i]) * min(1, dt * 3.5)
            if abs(c - fk[i]) < 1e-3 { fk[i] = c }
        }
        if let v = vol {
            let q = min(1, max(0, (now - debutVol) / CameraScene.dureeVol))
            orbite = v.orbite(q, depuis: orbite)
            if q >= 1 { vol = nil }
        } else if envol == nil && fondu == nil {
            controles()
        }
        if !enMouvement, let e = attente { appliquer(e) }
    }

    /// Rotation lente, rotation amortie, zoom amorti.
    private func controles() {
        if troisD && t == 1 && rotation && !reduire && focus == nil && geste == nil {
            orbite.azimut -= 2 * .pi / CameraScene.dureeTour * dt
        }
        if rotationEnAttente != .zero {
            let pas = rotationEnAttente * (1 - pow(0.95, 60 * dt))
            orbite.azimut += pas.x
            orbite.inclinaison = min(1.45, max(0.15, orbite.inclinaison + pas.y))
            rotationEnAttente -= pas
            if simd_length(rotationEnAttente) < 1e-5 { rotationEnAttente = .zero }
        }
        if zoomEnAttente != 0 {
            var pas = zoomEnAttente * (1 - exp(-dt * 16))
            if abs(zoomEnAttente) < 0.002 { pas = zoomEnAttente }
            let bornes = CameraScene.bornes(geometrie, aspect: aspect, troisD: t == 1, champ: orbite.champ)
            orbite = CameraScene.zoomer(orbite, facteur: pas, ancre: ancreZoom, bornes: bornes)
            zoomEnAttente -= pas
            if orbite.distance <= bornes.lowerBound || orbite.distance >= bornes.upperBound { zoomEnAttente = 0 }
        }
    }

    // MARK: Horloge

    func doitContinuer(_ now: Double) -> Bool {
        if enMouvement || s != sCible || attente != nil { return true }
        if fk.contains(where: { $0 != 0 && $0 != 1 }) { return true }
        if troisD && t == 1 && rotation && !reduire && focus == nil { return true }
        if zoomEnAttente != 0 || rotationEnAttente != .zero || (geste != nil && bouge) { return true }
        if now - derniereActivite < 0.6 { return true }
        return etiquettes.contains { $0.envie > 0 }
    }

    /// Arrete l'horloge apres l'image (pas pendant le rendu).
    private func endormir() {
        guard anime else { return }
        Task { @MainActor [weak self] in
            guard let self, !self.doitContinuer(Self.maintenant()) else { return }
            self.anime = false
        }
    }

    func reveiller() {
        derniereActivite = Self.maintenant()
        if !anime {
            // Pas de temps nul a la premiere image : sinon le zoom amorti ferait un bond.
            instant = nil
            anime = true
        }
    }

    // MARK: Souris et clavier

    /// Noeud sous un point : sa pastille, a 8 points pres, sinon son nom.
    func noeudSous(_ p: CGPoint) -> String? {
        if let n = projetee?.noeud(sous: p, marge: 8) { return n }
        for l in etiquettes where l.vu && l.rect.contains(p) {
            if case .noeud(let id) = l.genre { return id }
        }
        return nil
    }

    func survoler(_ p: CGPoint?) {
        curseur = p
        let n = p.flatMap(noeudSous)
        if n != survol {
            survol = n
            reveiller()
        }
        let cible = p.map(cible(en:)) ?? .aucune
        if cible != cibleMenu { cibleMenu = cible }
    }

    /// Clic droit : un nom d'etage, ou le fond (ni piece, ni noeud).
    func cible(en p: CGPoint) -> CibleMenu {
        for l in etiquettes where l.vu && l.rect.insetBy(dx: -2, dy: -2).contains(p) {
            if case .etage(let i) = l.genre { return .etage(i) }
        }
        if noeudSous(p) == nil && projetee?.piece(sous: p) == nil { return .fond }
        return .aucune
    }

    func glisser(_ p: CGPoint, depart d: CGPoint) {
        if geste == nil {
            bouge = false
            precedent = d
            if !estIsolee, !enMouvement, let i = projetee?.piece(sous: d), let c = centrePiece(i) {
                geste = .piece(i, hauteur: c.y)
            } else {
                geste = .fond
            }
        }
        if !bouge && hypot(p.x - d.x, p.y - d.y) < 5 { return }
        bouge = true
        defer { precedent = p }
        guard !enMouvement, let geste else { return }
        let proj = ProjectionScene(orbite, cadre: cadre)
        switch geste {
        case .piece(let i, let h):
            guard let scene, let a = proj.sol(precedent, hauteur: h), let b = proj.sol(p, hauteur: h) else { return }
            var pos = positions[i] + SIMD2(b.x - a.x, b.z - a.z)
            let r = max(0, geometrie.rayons[scene.pieces[i].etage] - 0.5 * hypot(cartes[i].largeur, cartes[i].profondeur))
            if simd_length(pos) > r { pos = simd_length(pos) > 0 ? simd_normalize(pos) * r : .zero }
            positions[i] = pos
        case .fond:
            if t == 0 {
                if let a = proj.sol(precedent, hauteur: orbite.cible.y), let b = proj.sol(p, hauteur: orbite.cible.y) {
                    orbite.cible += a - b
                    vueTouchee = true
                }
            } else {
                let h = max(1, Double(taille.height))
                rotationEnAttente.x -= 2 * .pi * Double(p.x - precedent.x) / h
                rotationEnAttente.y -= 2 * .pi * Double(p.y - precedent.y) / h
            }
        }
        reveiller()
    }

    /// Fin d'un glisser, ou clic. Deux clics sur le fond, a moins de l'intervalle du double-clic de
    /// macOS et de 5 points : le second est un double-clic ; le premier a agi comme un clic simple.
    func relacher(_ p: CGPoint, a instant: Double = MoteurPieces.maintenant()) {
        let g = geste
        let clic = !bouge
        geste = nil
        bouge = false
        if case .piece(let i, _)? = g, !clic {
            garder(i)
        } else if clic {
            let fond = noeudSous(p) == nil && projetee?.piece(sous: p) == nil
            if fond, let c = clicFond, instant - c.instant <= NSEvent.doubleClickInterval,
               hypot(p.x - c.point.x, p.y - c.point.y) <= 5 {
                clicFond = nil
                if envol == nil, fondu == nil { doubleCliquer() }
            } else {
                clicFond = fond ? (instant, p) : nil
                cliquer(p)
            }
        }
        reveiller()
    }

    /// Clic sans glisser : un appareil ouvre sa fiche ; une piece s'isole (en piece isolee, une autre
    /// piece y mene, meme pendant le vol) ; a cote des pieces, la fiche se ferme et la vue revient a la
    /// maison. Rien pendant l'envol.
    func cliquer(_ p: CGPoint) {
        guard envol == nil, fondu == nil else { return }
        if let n = noeudSous(p) {
            selection = n
            return
        }
        let i = projetee?.piece(sous: p)
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
    }

    func molette(_ dy: Double, precis: Bool) {
        guard !enMouvement else { return }
        zoomer(precis ? -dy * 0.004 : -dy * 0.08, en: curseur)
    }

    func pincer(_ m: Double, en p: CGPoint) {
        guard !enMouvement else { return }
        let l = -log(max(0.05, m) / max(0.05, dernierPincement))
        dernierPincement = m
        zoomer(l, en: p)
    }

    func finPincement() { dernierPincement = 1 }

    /// Zoom amorti ; en 2D, vers le point sous le curseur.
    private func zoomer(_ l: Double, en p: CGPoint?) {
        ancreZoom = nil
        if t == 0, let p { ancreZoom = ProjectionScene(orbite, cadre: cadre).sol(p, hauteur: orbite.cible.y) }
        zoomEnAttente += l
        vueTouchee = true
        reveiller()
    }

    /// Molette et Echap, dans la fenetre de la vue seulement : un moniteur local (SwiftUI n'a pas
    /// d'evenement de molette brut).
    func ecouter() {
        guard moniteur == nil else { return }
        moniteur = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak self] e in
            guard let self else { return e }
            let pourMoi = MainActor.assumeIsolated { e.window != nil && e.window === self.fenetre }
            guard pourMoi else { return e }
            switch e.type {
            case .scrollWheel:
                let dy = Double(e.scrollingDeltaY), precis = e.hasPreciseScrollingDeltas
                MainActor.assumeIsolated { self.molette(dy, precis: precis) }
                return nil
            case .keyDown where e.keyCode == 53:
                MainActor.assumeIsolated { self.sortir() }
                return nil
            default:
                return e
            }
        }
    }

    func arreterEcoute() {
        if let m = moniteur { NSEvent.removeMonitor(m) }
        moniteur = nil
    }

    // MARK: Etats poses a la main (captures, tests)

    func poserBascule(_ q: Double) {
        t = CameraScene.rampe(q)
        troisD = q > 0
        orbite = CameraScene.canonique(geometrie, aspect: aspect, u: t)
    }

    func poserIsolement(_ i: Int) {
        guard let scene, i < scene.pieces.count else { return }
        focus = i
        isolee = textes.pieces[i]?.nom
        s = 1
        sCible = 1
        fk[i] = 1
        if let e = entree { textes = Self.textes(e, focus: i) }
        construireEtiquettes()
        if let v = volVersPiece(i) { orbite = v.orbite(1, depuis: orbite) }
    }

    func poserSurvol(_ id: String?) { survol = id }

    func poserAzimut(_ decalage: Double) { orbite.azimut += decalage }

    /// Centre du bloc d'une piece, dans le monde.
    func centrePiece(_ i: Int) -> SIMD3<Double>? {
        guard let scene, i < scene.pieces.count, i < positions.count else { return nil }
        let c = geometrie.centrePlateau(scene.pieces[i].etage, t)
        return SIMD3(c.x + positions[i].x, c.y + 0.02 + GeometrieMaison.hauteurBloc(t) / 2, c.z + positions[i].y)
    }

    /// Zoom a l'echelle `k` (points par unite a la cible, divises par 24), vers le point `vers`.
    func poserZoom(echelle k: Double, vers a: SIMD3<Double>?) {
        let k0 = ProjectionScene(orbite, cadre: cadre).pxParUnite(orbite.cible) / CartesPieces.px
        let f = k0 / k
        if let a { orbite.cible = a + (orbite.cible - a) * f }
        orbite.distance *= f
        vueTouchee = true
    }

    /// Pose le cadre sans image (captures, tests).
    func poserTaille(_ nouvelle: CGSize) {
        taille = nouvelle
        cadre = CGRect(x: 0, y: marges.haut, width: nouvelle.width,
                       height: max(1, nouvelle.height - marges.haut - marges.bas))
        if pret { recadrer() }
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageThreadTests/MoteurPiecesTests`
Expected: `Test run with 9 tests in 1 suite passed` (`MoteurPiecesTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes, en français et en anglais.** Le Step 4 a compilé : mettre le catalogue à jour avec les clés que le compilateur a extraites.

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" outils/synchroniser-textes.sh
```

Expected : `Localizable.xcstrings` reçoit exactement cette clé : « ⌂ Maison ».

Puis les traductions, par ce script, qui ajoute les nouvelles à `interface.json` et garde le fichier trié au format de l'outil ; `outils/traduire.py` retire ensuite du catalogue les clés périmées et donne l'anglais aux nouvelles :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "⌂ Maison": "⌂ Home",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

Expected : aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 332 tests in 35 suites passed` (cœur) et `Test run with 263 tests in 29 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 9 tests et 1 suite de plus pour l'app.

- [ ] **Step 7 : commit.**

```bash
git add MaillageThread/Vues/Pieces/RenduCanvas.swift MaillageThread/Vues/Pieces/MoteurPieces.swift MaillageThreadTests/MoteurPiecesTests.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Ajouter le moteur Canvas de la vue par pieces

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 12: App : la fenêtre de la vue par pièces, toujours sombre ; « Placer dans une pièce… » ; les captures de démo

**Files:**
- Create: `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/Pieces/PiecesChoisies.swift`, `MaillageThread/Vues/Pieces/CapturesPieces.swift`
- Modify: `MaillageThread/MaillageThreadApp.swift` (blocs ci-dessous)
- Modify: `MaillageThread/Vues/Graphe/FicheNoeud.swift` (blocs ci-dessous : « Placer dans une pièce… »)
- Modify (par les outils) : `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings`
- Test: `MaillageThreadTests/FenetrePiecesTests.swift`

**Interfaces:**
- Consumes :
  - `MoteurPieces`, `LigneNiveau`, `CibleMenu`, `RenduCanvas` (tâche 11) ; `EntreeScene`, `LibellesNoeuds.pieceDeMaison`, `Palette` (tâche 10) ; `PiecesRouteurs` (tâche 5) ;
  - les morceaux de l'ancienne fenêtre, encore dans `FenetreGraphe.swift` : `BarreOutils`, `LigneTournee`, `BandeauScission`, `LegendeLiens`, `EtatVide`, `FeuilleRenommer`, `NoeudChoisi`, `View.fenetreDeLApp()` ; `FicheNoeud` (avec `instant` et `courbesVisibles(dans:)`, plan 3b) ; `NomsInternes` (`rafraichirSiAncien()`, `lancerPasseur()`, `lanceurInterdit`, plan 4a), `SondeMaillage`, `Surveillance.dossierParDefaut`, `Surveillance.sousTests`, `Surveillance.maintenant(a:)` (plan 3b) ;
  - dans les tests : `SondeMaillageTests` (préférences, canal retenu), `JournalCanaux`, `CourbesFicheTests.surveillance()`, `JournalMaillageTests.appareil` (plan 3b), `NomsSceneTests.demo()` et `maisonSansRouteurs(_:)` (tâche 10), existants.
- Produces :
  - `struct FenetrePieces: View` : `init(fichierPlaces: URL?, fichierPieces: URL? = nil)` ; `static func assombrir(_ fenetre: NSWindow?)` (apparence sombre, précision 15) ; `static let cleMode = "vuePieces3D"`, `bord` (16), `espacement` (10), `horloge` (`EveryMinuteTimelineSchedule`) ; `static func fichierPlaces(demo:sousTests:) -> URL?` (`positions-pieces.json` à côté de `identites-routeurs.json`, rien en démo ni sous les tests) ; `static func margeHaut(scinde:sondeRetenue:sansPieces:) -> CGFloat` ; `static func margeBas(fiche:courbes:) -> CGFloat` (30, 190, 360) ;
  - `VuePieces` (le `Canvas`, son horloge, ses gestes, ses menus), `MenuPieces`, `EnTetePieces(moteur:troisD:sansPieces:)`, `CommandesVue` (2D/3D et « Rotation lente »), `BandeauSansPieces`, `FilPieces(moteur:capture:)`, `LigneNiveauVue` (`static func texte(_: LigneNiveau) -> String`), `SondeFenetre`, `View.obstacle(_:_:)` (la place de l'interface, pour le placement des noms) ;
  - `@MainActor @Observable final class PiecesChoisies` : `init(fichier: URL?)`, `choix: PiecesRouteurs`, `choisir(_ piece: String?, routeur: String, domicile: String)` (écrit le fichier) ; `static func fichier(demo:sousTests:) -> URL?` (`pieces-routeurs.json` à côté de `positions-pieces.json`, rien en démo ni sous les tests) ; `static func pieces(aPlacer id: String, dans: Surveillance) -> [String]?` (les pièces du menu, pour un routeur de bordure que Maison ne place pas) ; `struct MenuPlacerRouteur: View` (« Placer dans une pièce… ») ;
  - `FicheNoeud` lit `PiecesChoisies` dans l'environnement, s'il y est (la vue par pièces seule l'y met), et montre alors le menu sous « Renommer… » ;
  - `@MainActor enum CapturesPieces` : `ecrire(dans dossier: String, surveillance: Surveillance) -> [String]` ; `VueCapture` ;
  - l'app : la fenêtre « graphe » montre `FenetrePieces`, avec ses deux fichiers ; `--args -demo -captures <dossier>` écrit les douze images, puis quitte.

La fenêtre remplace `FenetreGraphe` (qui reste jusqu'à la tâche 13, sans être montrée). Elle garde la barre d'outils, le bandeau de scission, la ligne de la tournée, la légende, la fiche et « Renommer… », et gagne l'interrupteur 2D/3D, « Rotation lente » (en 3D, coupée par « Réduire les animations »), le fil, la ligne de niveau, les clics droits (étages, fond) et le bandeau « Pas encore de pièces de Maison ». Le mode 2D ou 3D est gardé d'un lancement à l'autre. La fiche garde sa place en bas avec ses courbes (plan 3b) : la fenêtre lui passe l'heure de sa `TimelineView` (`instant: surveillance.maintenant(a: contexte.date)`), et `margeBas(fiche:courbes:)` rend 30, 190 ou 360 pt ; le rafraîchissement passe par `NomsInternes` (plan 4a).

**Toujours sombre** (précision 15, reco validée le 30/09) : `Palette(sombre: true)`, `colorScheme` sombre pour la vue, et `FenetrePieces.assombrir` sur la `NSWindow` (par `SondeFenetre`, qui la rapporte) : la barre, les menus, la fiche et la feuille « Renommer… » restent lisibles quand le Mac est en clair.

**« Placer dans une pièce… »** (précision 24, reco validée le 30/09) : `PiecesChoisies` garde les choix et les écrit ; `FenetrePieces` les passe à `EntreeScene` et met `PiecesChoisies` dans l'environnement ; la fiche d'un routeur de bordure que Maison ne place pas montre le menu : « D'après son nom », puis les pièces de la maison. Le test des marges couvre cette fiche.

- [ ] **Step 1 : écrire les tests.**

`MaillageThreadTests/FenetrePiecesTests.swift` (fichier entier) :

```swift
import AppKit
import Foundation
import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : la fenetre")
struct FenetrePiecesTests {
    /// Ce qui est entre les chevrons de la premiere `nom<…>` d'un type imprime, chevrons imbriques
    /// compris ; nil sans `nom<` ni chevron fermant.
    static func entreChevrons(_ nom: String, dans type: String) -> Substring? {
        guard let ouverture = type.range(of: nom + "<") else { return nil }
        var profondeur = 1
        var i = ouverture.upperBound
        while i < type.endIndex {
            switch type[i] {
            case "<": profondeur += 1
            case ">":
                profondeur -= 1
                if profondeur == 0 { return type[ouverture.upperBound..<i] }
            default: break
            }
            i = type.index(after: i)
        }
        return nil
    }

    /// « Ancien » (6 min) et « perime » (15 min) ne dependent que de l'heure, que rien n'observe : la
    /// fenetre est une `TimelineView` qui se redessine chaque minute (`FenetrePieces.horloge`), avec
    /// dedans tout ce qui lit l'heure (la legende, la scene, la fiche).
    @Test func redessinChaqueMinute() throws {
        let horloge = String(reflecting: type(of: FenetrePieces.horloge))
        let corps = String(reflecting: FenetrePieces.Body.self)
        let dedans = try #require(Self.entreChevrons("TimelineView", dans: corps), "le corps est une TimelineView")
        #expect(dedans.hasPrefix(horloge), "sur l'horloge")
        for vue in ["LegendeLiens", "VuePieces", "FicheNoeud"] {
            #expect(dedans.contains(vue), "\(vue) est dans la TimelineView, pas a cote")
        }
        let recu = Date(timeIntervalSince1970: 1_790_000_000)
        let redessins = FenetrePieces.horloge.entries(from: recu, mode: .normal).prefix(20).filter { $0 >= recu }
        #expect(zip(redessins, redessins.dropFirst()).allSatisfy { $1.timeIntervalSince($0) <= 60 })
    }

    /// Le haut de la fenetre (barre, bandeaux, tournee, fil) tient dans la marge du haut de la vue
    /// d'ensemble, dans tous les cas ; la fiche la plus haute de la demo, avec la ligne de niveau,
    /// dans la marge du bas ; avec les courbes de l'historique, dans la marge du bas avec courbes.
    @Test(.timeLimit(.minutes(1))) func marges() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        let sonde = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in SondeMaillageTests.canalRetenu(journal) })
        let noms = NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let sansReseau = Surveillance(mode: .direct, dossier: nil)
        func haut(_ s: Surveillance, sansPieces: Bool) -> CGFloat {
            let m = MoteurPieces()
            let vue = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                EnTetePieces(moteur: m, troisD: .constant(true), sansPieces: sansPieces)
                FilPieces(moteur: m)
            }
            return FenetrePieces.bord + NSHostingView(rootView: vue.environment(s).environment(sonde).environment(noms))
                .fittingSize.height
        }
        #expect(demo.reseau?.estScinde == true, "la demo : reseau scinde, bandeau affiche")
        for (s, scinde) in [(sansReseau, false), (demo, true)] {
            #expect(haut(s, sansPieces: false) <= FenetrePieces.margeHaut(scinde: scinde, sondeRetenue: false, sansPieces: false))
        }
        await sonde.connecter(SondeMaillageTests.port, choisi: true)
        await journal.attendre(SondeMaillageTests.listeRetenue)
        await SondeMaillageTests.attendre { sonde.avancement != nil }
        for (s, scinde) in [(sansReseau, false), (demo, true)] {
            #expect(haut(s, sansPieces: false) <= FenetrePieces.margeHaut(scinde: scinde, sondeRetenue: true, sansPieces: false))
        }
        #expect(haut(demo, sansPieces: true) <= FenetrePieces.margeHaut(scinde: true, sondeRetenue: true, sansPieces: true))
        await sonde.oublier()
        var fiche: CGFloat = 0
        let sansRouteurs = Surveillance(mode: .demo, dossier: nil)
        sansRouteurs.demarrer()
        sansRouteurs.noms.maison = NomsSceneTests.maisonSansRouteurs(sansRouteurs)
        #expect(PiecesChoisies.pieces(aPlacer: "Apple TV 4K", dans: sansRouteurs) != nil, "avec « Placer dans une pièce… »")
        for (s, id) in [(demo, "Apple TV 4K"), (demo, "3A5DFAFCAB581AAF"), (demo, "rloc:041F"), (demo, "7AF0B6D5006CF95F"),
                        (sansRouteurs, "Apple TV 4K")] {
            let v = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                LigneNiveauVue(ligne: .lisibles)
                FicheNoeud(id: id, instant: Date(), aRenommer: .constant(nil)) {}
            }
            let hote = NSHostingView(rootView: v.environment(s).environment(PiecesChoisies(fichier: nil)))
            fiche = max(fiche, hote.fittingSize.height + FenetrePieces.bord)
        }
        #expect(fiche <= FenetrePieces.margeBas(fiche: true, courbes: false), "\(fiche)")
        let historique = try CourbesFicheTests.surveillance()
        #expect(FicheNoeud.courbesVisibles(dans: historique))
        let courbes = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
            LigneNiveauVue(ligne: .lisibles)
            FicheNoeud(id: JournalMaillageTests.appareil, instant: Date(), aRenommer: .constant(nil)) {}
        }
        let avecCourbes = NSHostingView(rootView: courbes.environment(historique)).fittingSize.height + FenetrePieces.bord
        #expect(avecCourbes <= FenetrePieces.margeBas(fiche: true, courbes: true), "\(avecCourbes)")
    }

    /// Ligne de niveau : pieces seules, routeurs, noms masques (un, plusieurs), piece isolee.
    @Test func ligneDeNiveau() {
        #expect(LigneNiveauVue.texte(.pieces) == String(localized: "Vue d'ensemble : les pièces"))
        #expect(LigneNiveauVue.texte(.routeurs) == String(localized: "Mi-distance : les pièces et les routeurs"))
        #expect(LigneNiveauVue.texte(.masques(1)) == String(localized: "1 nom masqué faute de place : rapprochez-vous (molette)"))
        #expect(LigneNiveauVue.texte(.masques(3))
                == String(localized: "\(3) noms masqués faute de place : rapprochez-vous (molette)"))
        #expect(LigneNiveauVue.texte(.isolee("Salon")).contains("Salon"))
        #expect(LigneNiveauVue.texte(.lisibles) == String(localized: "Tous les noms sont lisibles"))
    }

    /// La fenetre reste sombre, meme quand le Mac est en clair : sa barre, ses menus, sa fiche et ses
    /// feuilles en apparence sombre.
    @Test func fenetreToujoursSombre() {
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled],
                               backing: .buffered, defer: true)
        fenetre.isReleasedWhenClosed = false
        fenetre.appearance = NSAppearance(named: .aqua)
        FenetrePieces.assombrir(fenetre)
        #expect(fenetre.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        FenetrePieces.assombrir(nil)
    }

    /// « Placer dans une piece… » : pour un routeur de bordure que Maison ne place pas seulement, les
    /// pieces de la maison, par nom ; le choix se garde sur disque, ou en memoire sans fichier (demo).
    @Test func placerUnRouteur() throws {
        let (s, _, _) = try NomsSceneTests.demo()
        #expect(PiecesChoisies.pieces(aPlacer: "HomePod Palier", dans: s) == nil, "Maison le place au salon")
        s.noms.maison = NomsSceneTests.maisonSansRouteurs(s)
        let pieces = try #require(PiecesChoisies.pieces(aPlacer: "HomePod Palier", dans: s))
        #expect(pieces == ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain", "Salon"])
        #expect(PiecesChoisies.pieces(aPlacer: "56B1E064401F74EF", dans: s) == nil, "un appareil")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("routeurs-\(UUID().uuidString)/pieces-routeurs.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let choisies = PiecesChoisies(fichier: url)
        choisies.choisir("Salon", routeur: "HomePod Palier", domicile: "Maison (démo)")
        #expect(PiecesChoisies(fichier: url).choix.choix(routeur: "HomePod Palier", domicile: "Maison (démo)") == "Salon")
        let memoire = PiecesChoisies(fichier: nil)
        memoire.choisir("Salon", routeur: "HomePod Palier", domicile: "")
        #expect(memoire.choix.choix(routeur: "HomePod Palier", domicile: "") == "Salon")
        #expect(PiecesChoisies.fichier(demo: true, sousTests: false) == nil)
        #expect(PiecesChoisies.fichier(demo: false, sousTests: true) == nil)
        #expect(PiecesChoisies.fichier(demo: false, sousTests: false)
                == Surveillance.dossierParDefaut.appendingPathComponent("pieces-routeurs.json"))
    }

    /// Places des pieces : a cote des identites des routeurs, ni en demo ni sous les tests.
    @Test func fichierDesPlaces() {
        #expect(FenetrePieces.fichierPlaces(demo: true, sousTests: false) == nil)
        #expect(FenetrePieces.fichierPlaces(demo: false, sousTests: true) == nil)
        #expect(FenetrePieces.fichierPlaces(demo: false, sousTests: false)?.lastPathComponent == "positions-pieces.json")
        #expect(FenetrePieces.fichierPlaces(demo: false, sousTests: false)?.deletingLastPathComponent()
                == Surveillance.dossierParDefaut)
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests`
Expected: la compilation des tests de l'app échoue, par exemple avec `error: cannot find 'FenetrePieces' in scope` et `error: cannot find 'EnTetePieces' in scope`.

- [ ] **Step 3 : écrire le code.** La fenêtre, les pièces choisies des routeurs, les captures, puis le branchement dans l'app (la fenêtre « graphe » montre la vue par pièces, et `-captures` écrit les images de démo) et « Placer dans une pièce… » dans la fiche, encore dans `Vues/Graphe/`.

`MaillageThread/Vues/Pieces/FenetrePieces.swift` (fichier entier) :

```swift
import AppKit
import MaillageCoeur
import SwiftUI

/// Fenetre de la vue par pieces (spec de la vue par pieces, sections 1 et 7) : la scene occupe toute
/// la fenetre ; la barre d'outils (avec 2D / 3D et « Rotation lente »), les bandeaux, la ligne de la
/// tournee et le fil flottent en haut ; la ligne de niveau, la legende et la fiche en bas. Elle reste
/// sombre, comme la maquette, meme quand le Mac est en clair (precision 15 du plan 4b).
struct FenetrePieces: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(NomsInternes.self) private var nomsMaison
    @Environment(SondeMaillage.self) private var sonde
    @Environment(\.accessibilityReduceMotion) private var reduire
    /// Le mode 2D ou 3D, garde d'un lancement a l'autre.
    @AppStorage(FenetrePieces.cleMode) private var troisD = false
    @State private var moteur: MoteurPieces
    @State private var piecesChoisies: PiecesChoisies
    @State private var aRenommer: NoeudChoisi?

    /// Preference du mode 2D ou 3D.
    static let cleMode = "vuePieces3D"
    /// Bord des elements poses sur la vue, et ecart entre eux (pt).
    static let bord: CGFloat = 16
    static let espacement: CGFloat = 10

    /// `fichierPlaces` : `positions-pieces.json` (`fichierPlaces(demo:sousTests:)`) ; `fichierPieces` :
    /// `pieces-routeurs.json` (`PiecesChoisies.fichier(demo:sousTests:)`) ; nil : ni lu ni ecrit.
    /// `--args -selection <id>` : fiche ouverte au lancement (captures d'ecran).
    init(fichierPlaces: URL?, fichierPieces: URL? = nil) {
        _moteur = State(initialValue: MoteurPieces(troisD: UserDefaults.standard.bool(forKey: Self.cleMode),
                                                   fichierPlaces: fichierPlaces,
                                                   selection: UserDefaults.standard.string(forKey: "selection")))
        _piecesChoisies = State(initialValue: PiecesChoisies(fichier: fichierPieces))
    }

    /// La fenetre reste sombre : barre, menus, fiche et feuilles en apparence sombre, quelle que soit
    /// celle du Mac.
    static func assombrir(_ fenetre: NSWindow?) {
        fenetre?.appearance = NSAppearance(named: .darkAqua)
    }

    /// Places des pieces, a cote des identites des routeurs ; ni en demo ni sous les tests.
    static func fichierPlaces(demo: Bool, sousTests: Bool) -> URL? {
        demo || sousTests ? nil : Surveillance.dossierParDefaut.appendingPathComponent("positions-pieces.json")
    }

    /// Redessin de la fenetre au debut de chaque minute. « Ancien » (6 min) et « perime » (15 min)
    /// ne dependent que de l'heure (`Surveillance.maintenant`), que rien n'observe : quand la sonde
    /// se tait, aucun evenement ne redessine la vue ; l'etat parait avec une minute de retard au
    /// plus, et le redessin n'a lieu que dans cette fenetre, tant qu'elle est ouverte.
    static let horloge = EveryMinuteTimelineSchedule()

    /// Marge du haut de la vue d'ensemble (pt) : la barre d'outils et le fil, puis une ligne de 40 pt
    /// pour le bandeau d'un reseau scinde, une pour la tournee tant qu'une sonde est retenue (rien ne
    /// bouge au debut ni a la fin d'une tournee), et 44 pt pour le bandeau d'une maison sans pieces.
    static func margeHaut(scinde: Bool, sondeRetenue: Bool, sansPieces: Bool) -> CGFloat {
        72 + (scinde ? 40 : 0) + (sondeRetenue ? 40 : 0) + (sansPieces ? 44 : 0)
    }

    /// Marge du bas de la vue d'ensemble (pt) : la legende et la ligne de niveau (elles debordent un
    /// peu sur la vue, comme la legende du graphe d'avant), ou la fiche ouverte, plus haute avec les
    /// courbes de l'historique (plan 3b) : la vue ne bouge pas d'un noeud a l'autre.
    static func margeBas(fiche: Bool, courbes: Bool) -> CGFloat {
        guard fiche else { return 30 }
        return courbes ? 360 : 190
    }

    var body: some View {
        let palette = Palette(sombre: true)
        // Redessin chaque minute (`horloge`) : la scene et la fiche lisent l'heure, que rien n'observe. La
        // fiche la recoit (`instant`) : sinon SwiftUI la sauterait, ses entrees n'ayant pas change.
        TimelineView(Self.horloge) { contexte in
            let entree = surveillance.reseau.map {
                EntreeScene(surveillance: surveillance, reseau: $0, places: moteur.places, choix: piecesChoisies.choix)
            }
            ZStack {
                RadialGradient(gradient: palette.fond, center: UnitPoint(x: 0.3, y: 0.35), startRadius: 0, endRadius: 900)
                    .ignoresSafeArea()
                if let r = surveillance.reseau, let entree {
                    VuePieces(moteur: moteur, entree: entree, palette: palette,
                              marges: (Self.margeHaut(scinde: r.estScinde, sondeRetenue: sonde.serie != nil,
                                                      sansPieces: entree.scene.sansPiecesMaison),
                                       Self.margeBas(fiche: moteur.selection != nil,
                                                     courbes: FicheNoeud.courbesVisibles(dans: surveillance))))
                    if !moteur.pret {
                        ProgressView().controlSize(.small)
                    }
                } else {
                    EtatVide()
                }
                VStack(alignment: .leading, spacing: Self.espacement) {
                    EnTetePieces(moteur: moteur, troisD: $troisD, sansPieces: entree?.scene.sansPiecesMaison == true)
                        .frame(maxWidth: .infinity)
                        .obstacle("en-tete", moteur)
                    FilPieces(moteur: moteur)
                        .obstacle("fil", moteur)
                    Spacer()
                    if moteur.selection == nil {
                        HStack(alignment: .center, spacing: 12) {
                            if let r = surveillance.reseau {
                                LegendeLiens(sonde: surveillance.maillageAffiche(pour: r) != nil,
                                             ancien: surveillance.maillageAncien)
                                    .obstacle("legende", moteur)
                            }
                            LigneNiveauVue(ligne: moteur.ligneNiveau)
                                .obstacle("niveau", moteur)
                        }
                    } else {
                        LigneNiveauVue(ligne: moteur.ligneNiveau)
                            .obstacle("niveau", moteur)
                    }
                    if let selection = moteur.selection {
                        FicheNoeud(id: selection, instant: surveillance.maintenant(a: contexte.date),
                                   aRenommer: $aRenommer, choisir: { moteur.selection = $0 }) {
                            moteur.selection = nil
                        }
                        .obstacle("fiche", moteur)
                    }
                }
                .padding(Self.bord)
            }
            .coordinateSpace(.named(VuePieces.espace))
        }
        .frame(minWidth: 820, minHeight: 560)
        .environment(piecesChoisies)
        .environment(\.colorScheme, .dark)
        .background(SondeFenetre { Self.assombrir($0) })
        .sheet(item: $aRenommer) { FeuilleRenommer(id: $0.id) }
        .onChange(of: reduire, initial: true) { _, r in moteur.reduire = r }
        .task {
            // Batteries de Maison a jour tant que la vue est ouverte.
            while !Task.isCancelled {
                nomsMaison.rafraichirSiAncien()
                try? await Task.sleep(for: .seconds(3600))
            }
        }
        .fenetreDeLApp()
    }
}

extension View {
    /// Cadre de cet element de l'interface, dans l'espace de la vue : les noms de la scene l'evitent ;
    /// retire quand l'element disparait.
    func obstacle(_ cle: String, _ moteur: MoteurPieces) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(VuePieces.espace)) } action: { r in
            moteur.cadresInterface[cle] = r
            moteur.reveiller()
        }
        .onDisappear { moteur.cadresInterface[cle] = nil }
    }
}

/// La scene : un `Canvas` redessine a chaque image pendant un mouvement (`MoteurPieces.anime`), plus
/// du tout au repos ; gestes, molette, clics droits.
struct VuePieces: View {
    let moteur: MoteurPieces
    let entree: EntreeScene
    let palette: Palette
    let marges: (haut: CGFloat, bas: CGFloat)
    @Environment(\.displayScale) private var echelle

    /// Espace de coordonnees de la vue et de ce qui est pose dessus.
    nonisolated static let espace = "pieces"

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !moteur.anime)) { contexte in
            Canvas { ctx, taille in
                _ = contexte.date
                moteur.marges = marges
                moteur.image(&ctx, taille: taille, echelle: echelle, palette: palette)
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let p): moteur.survoler(p)
            case .ended: moteur.survoler(nil)
            }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { moteur.glisser($0.location, depart: $0.startLocation) }
            .onEnded { moteur.relacher($0.location) })
        .simultaneousGesture(MagnifyGesture()
            .onChanged { moteur.pincer($0.magnification, en: $0.startLocation) }
            .onEnded { _ in moteur.finPincement() })
        .contextMenu { MenuPieces(moteur: moteur) }
        .background(SondeFenetre { moteur.fenetre = $0 })
        .onChange(of: entree, initial: true) { _, e in moteur.recevoir(e) }
        .onAppear { moteur.ecouter() }
        .onDisappear { moteur.arreterEcoute() }
    }
}

/// Clics droits : sur un nom d'etage, « Monter d'un etage » et « Descendre d'un etage » ; sur le fond,
/// « Replacer les pieces automatiquement ».
struct MenuPieces: View {
    let moteur: MoteurPieces

    var body: some View {
        switch moteur.cibleMenu {
        case .etage(let i):
            Button("Monter d'un étage") { moteur.deplacerEtage(i, de: 1) }
                .disabled(!moteur.peutDeplacerEtage(i, de: 1))
            Button("Descendre d'un étage") { moteur.deplacerEtage(i, de: -1) }
                .disabled(!moteur.peutDeplacerEtage(i, de: -1))
        case .fond:
            Button("Replacer les pièces automatiquement") { moteur.replacerPieces() }
        case .aucune:
            EmptyView()
        }
    }
}

/// Haut de la fenetre, pose sur la vue : barre d'outils et commandes de la vue, bandeau d'un reseau
/// scinde, ligne de la tournee (sa place est gardee tant qu'une sonde est retenue :
/// `FenetrePieces.margeHaut`), bandeau d'une maison sans pieces.
struct EnTetePieces: View {
    @Environment(Surveillance.self) private var surveillance
    let moteur: MoteurPieces
    @Binding var troisD: Bool
    /// Maison n'a encore aucune piece : le bandeau du passeur.
    var sansPieces = false

    var body: some View {
        VStack(spacing: FenetrePieces.espacement) {
            HStack(spacing: 6) {
                BarreOutils()
                CommandesVue(moteur: moteur, troisD: $troisD)
            }
            if let r = surveillance.reseau, r.estScinde {
                BandeauScission(reseau: r)
            }
            LigneTournee()
            if sansPieces {
                BandeauSansPieces()
            }
        }
    }
}

/// Interrupteur 2D / 3D, puis « Rotation lente », en 3D seulement (coupee par « Reduire les
/// animations »).
struct CommandesVue: View {
    let moteur: MoteurPieces
    @Binding var troisD: Bool

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 6) {
                Picker("Vue", selection: Binding(get: { moteur.troisD }, set: { v in
                    moteur.basculer(troisD: v)
                    troisD = v
                })) {
                    Text("2D").tag(false)
                    Text("3D").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                if moteur.troisD {
                    Toggle("Rotation lente", isOn: Binding(get: { moteur.rotation && !moteur.reduire },
                                                           set: { _ in moteur.basculerRotation() }))
                        .toggleStyle(.button)
                        .buttonStyle(.glass)
                        .disabled(moteur.reduire)
                        .help(moteur.reduire ? String(localized: "Coupée par « Réduire les animations »") : "")
                }
            }
        }
    }
}

/// Bandeau d'une maison dont Maison n'a encore donne aucune piece (spec, section 2.3).
struct BandeauSansPieces: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(NomsInternes.self) private var nomsMaison

    var body: some View {
        HStack(spacing: 10) {
            Label("Pas encore de pièces de Maison : lance le passeur", systemImage: "house")
            Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                .buttonStyle(.glass)
                .disabled(surveillance.mode == .demo)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Fil, en haut a gauche : « Maison », puis « › Salon » en piece isolee ; « Maison » y ramene.
/// `capture` : sans bouton (une capture ne dessine pas les controles d'AppKit).
struct FilPieces: View {
    let moteur: MoteurPieces
    var capture = false

    var body: some View {
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
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.primary.opacity(0.9))
    }
}

/// Ligne de niveau, en bas a gauche : pieces seules, routeurs, noms masques, piece isolee.
struct LigneNiveauVue: View {
    let ligne: LigneNiveau

    var body: some View {
        Text(Self.texte(ligne))
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
    }

    static func texte(_ l: LigneNiveau) -> String {
        switch l {
        case .isolee(let nom):
            String(localized: "Pièce isolée : \(nom) · clic sur une autre pièce pour y aller, clic à côté ou Échap pour revenir")
        case .pieces: String(localized: "Vue d'ensemble : les pièces")
        case .routeurs: String(localized: "Mi-distance : les pièces et les routeurs")
        case .masques(1): String(localized: "1 nom masqué faute de place : rapprochez-vous (molette)")
        case .masques(let n): String(localized: "\(n) noms masqués faute de place : rapprochez-vous (molette)")
        case .lisibles: String(localized: "Tous les noms sont lisibles")
        }
    }
}

/// Rapporte la fenetre qui porte la vue (la molette et Echap ne valent que pour elle).
struct SondeFenetre: NSViewRepresentable {
    let rapporter: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView { Sonde(rapporter) }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Sonde: NSView {
        let rapporter: (NSWindow?) -> Void

        init(_ rapporter: @escaping (NSWindow?) -> Void) {
            self.rapporter = rapporter
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            rapporter(window)
        }
    }
}
```

`MaillageThread/Vues/Pieces/PiecesChoisies.swift` (fichier entier) :

```swift
import Foundation
import MaillageCoeur
import SwiftUI

/// Pieces choisies pour les routeurs de bordure que Maison ne place pas (« Placer dans une piece… »,
/// dans la fiche du routeur ; precision 24 du plan 4b) : sous l'instance de l'annonce, par maison,
/// dans `pieces-routeurs.json`, a cote des places des pieces ; en memoire seulement en demo et sous
/// les tests. Le calcul est dans le coeur (`PiecesRouteurs`).
@MainActor
@Observable
final class PiecesChoisies {
    private(set) var choix: PiecesRouteurs
    @ObservationIgnored private let fichier: URL?

    /// `fichier` : `pieces-routeurs.json` (`fichier(demo:sousTests:)`) ; nil : ni lu ni ecrit.
    init(fichier: URL?) {
        self.fichier = fichier
        choix = fichier.map(PiecesRouteurs.lire) ?? PiecesRouteurs()
    }

    /// A cote des places des pieces ; ni en demo ni sous les tests.
    static func fichier(demo: Bool, sousTests: Bool) -> URL? {
        demo || sousTests ? nil : Surveillance.dossierParDefaut.appendingPathComponent("pieces-routeurs.json")
    }

    /// Place un routeur (son instance) dans une piece de la maison ; nil : d'apres son nom.
    func choisir(_ piece: String?, routeur: String, domicile: String) {
        choix.choisir(piece, routeur: routeur, domicile: domicile)
        guard let fichier else { return }
        do {
            try choix.ecrire(dans: fichier)
        } catch {
            MoteurPieces.journal.error("pieces des routeurs non ecrites : \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension PiecesChoisies {
    /// Pieces proposees par « Placer dans une piece… » pour un noeud : celles de la maison, par nom,
    /// pour un routeur de bordure que Maison ne place pas ; nil pour un autre noeud, ou si Maison n'a
    /// encore aucune piece.
    static func pieces(aPlacer id: String, dans surveillance: Surveillance) -> [String]? {
        guard surveillance.instantane?.routeur(id) != nil else { return nil }
        let maison = surveillance.noms.maison
        guard LibellesNoeuds.pieceDeMaison(routeur: id, maison: maison) == nil else { return nil }
        let pieces = PiecesRouteurs.pieces(de: maison).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return pieces.isEmpty ? nil : pieces
    }
}

/// « Placer dans une piece… », dans la fiche d'un routeur de bordure que Maison ne place pas : « D'apres
/// son nom » (la regle du nom), puis les pieces de la maison ; le choix en cours est coche.
struct MenuPlacerRouteur: View {
    let routeur: String
    let pieces: [String]
    let domicile: String
    let choisies: PiecesChoisies

    var body: some View {
        Menu("Placer dans une pièce…") {
            Picker("Placer dans une pièce…", selection: Binding(
                get: { choisies.choix.choix(routeur: routeur, domicile: domicile) },
                set: { choisies.choisir($0, routeur: routeur, domicile: domicile) })) {
                Text("D'après son nom").tag(String?.none)
                ForEach(pieces, id: \.self) { Text(verbatim: $0).tag(String?.some($0)) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .fixedSize()
    }
}
```

`MaillageThread/Vues/Pieces/CapturesPieces.swift` (fichier entier) :

```swift
import AppKit
import ImageIO
import MaillageCoeur
import SwiftUI
import UniformTypeIdentifiers

/// Images de la vue par pieces rendues par l'app elle-meme, en mode demo (`--args -demo -captures
/// <dossier>`), pour la relecture (spec de la vue par pieces, section 10) : 2D, envol, 3D, zooms,
/// pieces isolees, survol. Sans fenetre ni capture d'ecran ; l'app quitte ensuite.
@MainActor
enum CapturesPieces {
    /// Contenu d'une fenetre de 1440 x 900, en 2x.
    static let taille = CGSize(width: 1440, height: 900)

    /// Ecrit les images dans `dossier` ; rend leurs noms.
    @discardableResult
    static func ecrire(dans dossier: String, surveillance s: Surveillance) -> [String] {
        try? FileManager.default.createDirectory(atPath: dossier, withIntermediateDirectories: true)
        guard let r = s.reseau else { return [] }
        let palette = Palette(sombre: true)
        let marges = (FenetrePieces.margeHaut(scinde: r.estScinde, sondeRetenue: false, sansPieces: false),
                      FenetrePieces.margeBas(fiche: false, courbes: false))
        func piece(_ scene: ScenePieces, _ nom: String) -> Int {
            scene.pieces.firstIndex { $0.nom == .maison(nom) } ?? 0
        }
        let cas: [(String, (MoteurPieces, ScenePieces) -> Void)] = [
            ("01-2d", { _, _ in }),
            ("02-envol-30", { m, _ in m.poserBascule(0.3) }),
            ("03-envol-55", { m, _ in m.poserBascule(0.55) }),
            ("04-envol-80", { m, _ in m.poserBascule(0.8) }),
            ("05-3d", { m, _ in m.poserBascule(1) }),
            ("06-3d-tournee", { m, _ in
                m.poserBascule(1)
                m.poserAzimut(-1.9)
            }),
            ("07-2d-zoom-salon", { m, sc in m.poserZoom(echelle: 2.2, vers: m.centrePiece(piece(sc, "Salon"))) }),
            ("08-2d-mi-distance", { m, _ in m.poserZoom(echelle: 0.5, vers: nil) }),
            ("09-2d-loin", { m, _ in m.poserZoom(echelle: 0.36, vers: nil) }),
            ("10-3d-isolee-salon", { m, sc in
                m.poserBascule(1)
                m.poserIsolement(piece(sc, "Salon"))
            }),
            ("11-2d-isolee-chambre", { m, sc in m.poserIsolement(piece(sc, "Chambre")) }),
            ("12-2d-survol", { m, _ in m.poserSurvol("9A28601B74FF90A7") }),
        ]
        var noms: [String] = []
        for (nom, preparer) in cas {
            let m = MoteurPieces()
            m.fige = true
            m.marges = marges
            m.poserTaille(taille)
            let e = EntreeScene(surveillance: s, reseau: r, places: m.places)
            m.installerMaintenant(e)
            m.poserTaille(taille)
            preparer(m, e.scene)
            // Deux passages : le premier pose les noms, le second les dessine a leur place.
            var image: CGImage?
            for _ in 0..<2 {
                let rendu = ImageRenderer(content: VueCapture(moteur: m, palette: palette).frame(width: taille.width,
                                                                                                height: taille.height))
                rendu.scale = 2
                image = rendu.cgImage
            }
            guard let image else { continue }
            ecrire(image, vers: (dossier as NSString).appendingPathComponent(nom + ".png"))
            noms.append(nom)
        }
        return noms
    }

    static func ecrire(_ image: CGImage, vers chemin: String) {
        guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: chemin) as CFURL,
                                                         UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}

/// La vue d'une capture : le fond, la scene, le fil et la ligne de niveau, sans horloge ni geste.
struct VueCapture: View {
    let moteur: MoteurPieces
    let palette: Palette

    var body: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(gradient: palette.fond, center: UnitPoint(x: 0.3, y: 0.35), startRadius: 0, endRadius: 900)
            Canvas { ctx, taille in moteur.image(&ctx, taille: taille, echelle: 2, palette: palette) }
            VStack(alignment: .leading) {
                FilPieces(moteur: moteur, capture: true)
                    .padding(.top, 56)
                Spacer()
                LigneNiveauVue(ligne: moteur.ligneNiveau)
            }
            .padding(FenetrePieces.bord)
        }
        .environment(\.colorScheme, .dark)
    }
}
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
        s.demarrer()
    }
```

par :

```swift
        s.demarrer()
        // `--args -demo -captures <dossier>` : images de la vue par pieces, puis l'app quitte.
        if Self.demo, let dossier = UserDefaults.standard.string(forKey: "captures") {
            CapturesPieces.ecrire(dans: dossier, surveillance: s)
            exit(0)
        }
    }
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
            FenetreGraphe()
```

par :

```swift
            FenetrePieces(fichierPlaces: FenetrePieces.fichierPlaces(demo: Self.demo, sousTests: Surveillance.sousTests),
                          fichierPieces: PiecesChoisies.fichier(demo: Self.demo, sousTests: Surveillance.sousTests))
```

Dans `MaillageThread/Vues/Graphe/FicheNoeud.swift`, remplacer :

```swift
    @Environment(\.colorScheme) private var apparence
    let id: String
```

par :

```swift
    @Environment(\.colorScheme) private var apparence
    /// Pieces choisies pour les routeurs de bordure : la vue par pieces seule les donne.
    @Environment(PiecesChoisies.self) private var piecesChoisies: PiecesChoisies?
    let id: String
```

Dans `MaillageThread/Vues/Graphe/FicheNoeud.swift`, remplacer :

```swift
                    if Self.renommable(id, dans: surveillance) {
                        Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                            .buttonStyle(.glass)
                    }
```

par :

```swift
                    if Self.renommable(id, dans: surveillance) {
                        Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                            .buttonStyle(.glass)
                    }
                    if let piecesChoisies, let pieces = PiecesChoisies.pieces(aPlacer: id, dans: surveillance) {
                        MenuPlacerRouteur(routeur: id, pieces: pieces, domicile: surveillance.noms.maison?.domicile ?? "",
                                          choisies: piecesChoisies)
                    }
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests`
Expected: `Test run with 6 tests in 1 suite passed` (`FenetrePiecesTests`), `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes, en français et en anglais.** Le Step 4 a compilé : mettre le catalogue à jour avec les clés que le compilateur a extraites.

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" outils/synchroniser-textes.sh
```

Expected : `Localizable.xcstrings` reçoit exactement ces 17 clés : « %lld noms masqués faute de place : rapprochez-vous (molette) », « 1 nom masqué faute de place : rapprochez-vous (molette) », « 2D », « 3D », « Coupée par « Réduire les animations » », « D'après son nom », « Descendre d'un étage », « Mi-distance : les pièces et les routeurs », « Monter d'un étage », « Pas encore de pièces de Maison : lance le passeur », « Pièce isolée : %@ · clic sur une autre pièce pour y aller, clic à côté ou Échap pour revenir », « Placer dans une pièce… », « Replacer les pièces automatiquement », « Rotation lente », « Tous les noms sont lisibles », « Vue », « Vue d'ensemble : les pièces ».

Puis les traductions, par ce script, qui ajoute les nouvelles à `interface.json` et garde le fichier trié au format de l'outil ; `outils/traduire.py` retire ensuite du catalogue les clés périmées et donne l'anglais aux nouvelles :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "%lld noms masqués faute de place : rapprochez-vous (molette)": "%lld names hidden for lack of room: zoom in (scroll)",
    "1 nom masqué faute de place : rapprochez-vous (molette)": "1 name hidden for lack of room: zoom in (scroll)",
    "2D": "2D",
    "3D": "3D",
    "Coupée par « Réduire les animations »": "Turned off by “Reduce motion”",
    "D'après son nom": "From its name",
    "Descendre d'un étage": "Move down one floor",
    "Mi-distance : les pièces et les routeurs": "Mid-distance: rooms and routers",
    "Monter d'un étage": "Move up one floor",
    "Pas encore de pièces de Maison : lance le passeur": "No rooms from Home yet: run Passeur Noms",
    "Pièce isolée : %@ · clic sur une autre pièce pour y aller, clic à côté ou Échap pour revenir": "Isolated room: %@ · click another room to go there, click outside or press Esc to come back",
    "Placer dans une pièce…": "Place in a room…",
    "Replacer les pièces automatiquement": "Arrange rooms automatically",
    "Rotation lente": "Slow rotation",
    "Tous les noms sont lisibles": "All names are readable",
    "Vue": "View",
    "Vue d'ensemble : les pièces": "Overview: rooms",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

Expected : aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 332 tests in 35 suites passed` (cœur) et `Test run with 269 tests in 30 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 6 tests et 1 suite de plus pour l'app.

- [ ] **Step 7 : les images de démo** (spec, section 10 : des images de relecture, sans comparaison au pixel). L'app, en mode démo seulement, écrit douze images de 1440 × 900 points en 2x dans son conteneur, sans fenêtre, puis quitte ; `open -W` attend qu'elle ait quitté.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-plan4b"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-plan4b/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
```

Expected : `01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png` ; « l'app a quitté ».

Relire chaque image (l'outil Read les montre) à côté de la maquette v13 (`docs/superpowers/specs/maquettes/vue-pieces-v13.html`, dans un navigateur). La démo a plus de nœuds que la maquette : ses cartes sont plus grandes, et la vue d'ensemble un peu plus loin.
- `01-2d` : vue de dessus ; les deux plateaux côte à côte, « Rez-de-chaussée » à gauche et « Étage » à droite ; neuf cartes de verre teintées (huit pièces et « Sans pièce »), une ligne par nœud, le nom de chaque pièce et son compte au-dessus ; les liens radio en couleur, les rattachements en traits fins ; aucun nom n'en chevauche un autre ; « Maison » en haut à gauche, la ligne de niveau en bas à gauche ;
- `02-envol-30`, `03-envol-55`, `04-envol-80` : l'envol, sans saut d'une image à l'autre : les plateaux s'inclinent et se rapprochent pour s'empiler, les blocs montent, la sphère apparaît ;
- `05-3d` : les plateaux empilés dans la sphère, le rez-de-chaussée en bas ; le liseré de la sphère et son équateur ; « ⌂ Maison » sous le haut de la sphère ;
- `06-3d-tournee` : la même vue, tournée autour de la maison ;
- `07-2d-zoom-salon` : de près, sur le Salon : tous ses noms, lisibles ;
- `08-2d-mi-distance` : les pièces et les routeurs seulement ;
- `09-2d-loin` : les pièces seules, avec leur nombre d'appareils, et « Vue d'ensemble : les pièces » ;
- `10-3d-isolee-salon` : le Salon isolé en 3D, grandi ; les autres pièces estompées, leurs noms pâles ; le fil « Maison › Salon » ;
- `11-2d-isolee-chambre` : la Chambre isolée en 2D ; les repères « ailleurs » au bout de pointillés verts (« ↓ HomePod Palier · Salon, Rez-de-chaussée ») ; « Pièce isolée : Chambre · … » en bas ;
- `12-2d-survol` : la vue d'ensemble en 2D, le nom de l'appareil survolé (« Lampe chambre d'amis ») en semi-gras et ses liens éclairés.

Si une image s'écarte de la maquette (un nom qui en chevauche un autre, une carte hors de son plateau, un saut entre deux images de l'envol), l'exécutant le dit dans son rapport, avec l'image. Ces images ne sont pas commitées.

- [ ] **Step 8 : commit.**

```bash
git add MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/Pieces/PiecesChoisies.swift MaillageThread/Vues/Pieces/CapturesPieces.swift MaillageThread/Vues/Graphe/FicheNoeud.swift MaillageThread/MaillageThreadApp.swift MaillageThreadTests/FenetrePiecesTests.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Remplacer le graphe par la vue par pieces dans sa fenetre, toujours sombre

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 13: Retrait de l'ancien graphe et reprise de ses tests utiles

**Files:**
- Move: `MaillageThread/Vues/Graphe/FenetreGraphe.swift` → `MaillageThread/Vues/Pieces/MorceauxFenetre.swift` (script ci-dessous : sans `FenetreGraphe` ni `EnTeteGraphe`)
- Move: `MaillageThread/Vues/Graphe/FicheNoeud.swift` → `MaillageThread/Vues/Pieces/FicheNoeud.swift` (script ci-dessous)
- Move: `MaillageThread/Vues/Graphe/Palette.swift` → `MaillageThread/Vues/Pieces/Palette.swift` (blocs ci-dessous : les couleurs du graphe retirées)
- Move: `MaillageThread/Vues/Graphe/CourbesFiche.swift` → `MaillageThread/Vues/Pieces/CourbesFiche.swift`
- Modify: `MaillageThread/Surveillance/Surveillance.swift` (script ci-dessous : `LibellesNoeuds.inconnu`)
- Delete: `MaillageThread/Vues/Graphe/GrapheCanvas.swift`, `MaillageThread/Vues/Graphe/PlacementLibelles.swift`, `MaillageThread/Vues/Graphe/Projection.swift`, `MaillageThread/Vues/Graphe/MesureLibelles.swift`, `MaillageCoeur/Disposition/Disposition.swift`
- Modify: `MaillageCoeur/Maillage/Rapprochement.swift` (bloc ci-dessous : un commentaire)
- Modify (par les outils) : `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` (3 textes retirés)
- Test: `MaillageThreadTests/GrapheTests.swift` → `MaillageThreadTests/FenetreTests.swift` ; `MaillageCoeurTests/RapprochementTests.swift`, `MaillageThreadTests/AffichageSondeTests.swift` (script ci-dessous) ; `MaillageThreadTests/CourbesFicheTests.swift` (blocs ci-dessous : `FenetrePieces.margeBas`) ; supprimés : `MaillageCoeurTests/DispositionTests.swift`, `MaillageThreadTests/PlacementLibellesTests.swift`

**Interfaces:**
- Consumes :
  - `FenetrePieces` et `EnTetePieces` (tâche 12), qui remplacent `FenetreGraphe` et `EnTeteGraphe` ; `LibellesNoeuds.inconnu` (tâche 10), qui remplace `GrapheCanvas.libelleInconnu` ; `GrapheReseauTests` (tâche 1), qui reprend les faits de `DispositionTests` sur les nœuds et les liens ; `PlacementNomsTests` et `MoteurPiecesTests.ordreDesCouches` (tâches 7 et 11), qui reprennent ceux de `PlacementLibellesTests` (placement des noms, ordre des couches).
- Produces :
  - plus de `Disposition`, `GrapheCanvas`, `PlacementLibelles`, `Projection`, `MesureLibelles`, `FenetreGraphe`, `EnTeteGraphe`, ni de `Palette.zone(_:)` ; `MaillageThread/Vues/Graphe/` disparaît ;
  - `MorceauxFenetre.swift` : `NoeudChoisi`, `BarreOutils`, `LigneTournee`, `IndicateurTournee`, `BandeauScission`, `LegendeLiens` (trait de 2 pt), `EtatVide`, `ListeAppareilsIP`, `FeuilleRenommer`, sans changement de comportement ;
  - les suites `FenetreTests` (barre d'outils, ligne de la tournée, fiche), `RapprochementTests` et `AffichageSondeTests`, sans ce qui ne vaut que pour l'ancien graphe (anneaux, épaisseur des liens selon la qualité) ; `CourbesFicheTests` sur `FenetrePieces.margeBas` (30, 190, 360).

Les tests d'abord : ce qui reste vrai de l'ancien graphe est déjà repris (nœuds et liens dans `GrapheReseauTests`, placement des noms dans `PlacementNomsTests`, ordre des couches dans `MoteurPiecesTests`) ; le reste part avec lui. Les tests adaptés passent encore avec l'ancien code (Step 2), puis sans lui (Step 4). Depuis le plan 3b, `Surveillance` nomme aussi les nœuds de la sonde par `GrapheCanvas.libelleInconnu`, et les courbes de la fiche sont dans `Vues/Graphe/` : elles suivent la fiche dans `Vues/Pieces/`.

- [ ] **Step 1 : écrire les tests.** Déplacer et retirer d'abord les tests de l'ancien graphe ; `CourbesFicheTests` teste ensuite les marges de `FenetrePieces` :

```bash
git mv MaillageThreadTests/GrapheTests.swift MaillageThreadTests/FenetreTests.swift
```

```bash
git rm MaillageCoeurTests/DispositionTests.swift MaillageThreadTests/PlacementLibellesTests.swift
```

Dans `MaillageThreadTests/CourbesFicheTests.swift`, remplacer :

```swift
    /// La fiche montre les courbes des qu'il y a un historique (jamais en demo), et le graphe lui
    /// garde plus de place en bas ; pour un noeud sans historique, une ligne de texte.
```

par :

```swift
    /// La fiche montre les courbes des qu'il y a un historique (jamais en demo), et la vue lui
    /// garde plus de place en bas ; pour un noeud sans historique, une ligne de texte.
```

Dans `MaillageThreadTests/CourbesFicheTests.swift`, remplacer :

```swift
        #expect(FenetreGraphe.margeBas(fiche: false, courbes: true) == 30)
        #expect(FenetreGraphe.margeBas(fiche: true, courbes: false) == 190)
        #expect(FenetreGraphe.margeBas(fiche: true, courbes: true) == 360)
```

par :

```swift
        #expect(FenetrePieces.margeBas(fiche: false, courbes: true) == 30)
        #expect(FenetrePieces.margeBas(fiche: true, courbes: false) == 190)
        #expect(FenetrePieces.margeBas(fiche: true, courbes: true) == 360)
```

Puis ce script, qui retire des tests ce qui ne vaut que pour l'ancien graphe : dans `RapprochementTests`, la disposition (ses anneaux ; les faits sur les nœuds sont dans `GrapheReseauTests`) ; dans `AffichageSondeTests`, les noms par `GrapheCanvas` (remplacés par `LibellesNoeuds.inconnu`) et l'épaisseur des liens selon la qualité ; dans `FenetreTests`, le nom de la suite et la marge du graphe (celles de la vue sont testées par `FenetrePiecesTests`) :

```bash
python3 - <<'EOF'
def couper(s, debut, fin):
    """Retire le texte de `debut` (compris) a `fin` (non compris)."""
    i = s.index(debut)
    j = s.index(fin, i)
    return s[:i] + s[j:]


def remplacer(s, ancien, nouveau, fois=1):
    assert s.count(ancien) == fois, (ancien[:70], s.count(ancien))
    return s.replace(ancien, nouveau)


# Rapprochement : sans la disposition du graphe (ses faits sur les noeuds sont dans GrapheReseauTests).
p = 'MaillageCoeurTests/RapprochementTests.swift'
s = open(p, encoding='utf-8').read()
s = remplacer(s, '@Suite("Rapprochement du maillage et disposition avec la sonde")',
              '@Suite("Rapprochement du maillage avec l\'instantane")')
s = couper(s, "    /// Anneau interieur de la zone principale, dans l'ordre.\n",
           "    static func affiches(_ i: Instantane) -> [AppareilAffiche] {")
s = couper(s, "    /// Anneau interieur : routeurs de bordure hors centre, appareils qui routent,\n",
           "    /// Elimination : la sonde entend CC00 et E400")
s = remplacer(s, """    /// annonce non reprise (le HomePod palier) : c'est lui. Un seul noeud pour ce routeur.""",
              """    /// annonce non reprise (le HomePod palier) : c'est lui (un seul noeud : `GrapheReseauTests`).""")
s = remplacer(s, """        #expect(m.inconnus.filter { $0.genre == .routeur }.isEmpty)
        let d = Disposition(reseau: r, appareils: Self.affiches(i), maillage: m)
        #expect(Self.interieur(d) == ["HomePod bureau", "HomePod chambre", "HomePod palier", "HomePod salon",
                                      "E000000000000002", "E000000000000003"])
    }""", """        #expect(m.inconnus.filter { $0.genre == .routeur }.isEmpty)
    }""")
s = remplacer(s, """    /// d'elimination ; chacun a les deux pour candidates, qui ne sont plus dessinees a part.
    /// Un seul noeud par routeur : le centre et six sur l'anneau interieur, pour 7 routeurs.""",
              """    /// d'elimination ; chacun a les deux pour candidates, qui ne sont plus des noeuds a part
    /// (`GrapheReseauTests`).""")
s = remplacer(s, """        #expect(m.annoncesCandidates == ["HomePod avant", "HomePod palier"])
        let d = Disposition(reseau: r, appareils: Self.affiches(i), maillage: m)
        #expect(Self.interieur(d) == ["HomePod bureau", "HomePod chambre", "E000000000000002", "E000000000000003",
                                      "rloc:0400", "rloc:CC00"])
        #expect(d.noeud("HomePod avant") == nil && d.noeud("HomePod palier") == nil)
        // Sans sonde, rien ne change : les annonces sont dessinees.
        let sans = Disposition(reseau: r, appareils: Self.affiches(i))
        #expect(Self.interieur(sans) == ["HomePod bureau", "HomePod chambre", "HomePod avant", "HomePod palier"])
    }""", """        #expect(m.annoncesCandidates == ["HomePod avant", "HomePod palier"])
    }""")
s = remplacer(s, """    /// Reseau scinde : les candidats ne viennent que de la partition de la sonde, et seules ses
    /// annonces candidates ne sont pas dessinees ; l'autre partition garde toutes les siennes, meme
    /// non reprises (ExtMac inventees).""",
              """    /// Reseau scinde : les candidats ne viennent que de la partition de la sonde (ExtMac inventees).""")
s = remplacer(s, """        #expect(m.routeurs[1]?.candidats == ["HomePod salon"])
        let d = Disposition(reseau: r, appareils: Self.affiches(i), maillage: m)
        #expect(d.noeud("HomePod salon") == nil)
        #expect(d.noeud("Aqara")?.zone == "73586B68" && d.noeud("HomePod isole")?.zone == "73586B68")
    }""", """        #expect(m.routeurs[1]?.candidats == ["HomePod salon"])
    }""")
s = remplacer(s, """        #expect(Disposition(reseau: r, appareils: Self.affiches(avecXa), maillage: m).noeud("HomePod avant") != nil)""",
              """        #expect(GrapheReseau(reseau: r, appareils: Self.affiches(avecXa), maillage: m).noeud("HomePod avant") != nil)""")
s = remplacer(s, """        #expect(Disposition(reseau: r, appareils: [], maillage: m).noeud("HomePod avant") != nil)""",
              """        #expect(GrapheReseau(reseau: r, appareils: [], maillage: m).noeud("HomePod avant") != nil)""")
s = remplacer(s, """    /// Le centre de la zone peut etre candidat (ici le premier par nom : annonces Thread 1.3, sans
    /// role) ; il reste dessine, au centre. L'autre annonce candidate, non.
    @Test func centreCandidat() throws {
        var b = Banc()
        b.routeur("Alpha", partition: "46CBEBCD", role: nil, lien: "fe80::1", xa: "E0000000000000C1")
        b.routeur("HomePod avant", partition: "46CBEBCD", role: nil, lien: "fe80::2", xa: "E0000000000000D1")
        let i = Instantane(annonces: b.annonces)
        let r = try #require(i.reseaux.first)
        let m = try Self.deuxRouteurs(i)
        #expect(m.routeurs[1]?.candidats == ["Alpha", "HomePod avant"] && m.routeurs[2]?.candidats == ["Alpha", "HomePod avant"])
        let d = Disposition(reseau: r, appareils: [], maillage: m)
        #expect(d.noeud("Alpha")?.genre == .centre)
        #expect(d.noeud("HomePod avant") == nil)
        #expect(Self.interieur(d) == ["rloc:0400", "rloc:0800"])
    }
""", """    /// Le centre de la partition peut etre candidat (ici le premier par nom : annonces Thread 1.3,
    /// sans role) ; il reste un noeud, au centre (`GrapheReseauTests`).
    @Test func centreCandidat() throws {
        var b = Banc()
        b.routeur("Alpha", partition: "46CBEBCD", role: nil, lien: "fe80::1", xa: "E0000000000000C1")
        b.routeur("HomePod avant", partition: "46CBEBCD", role: nil, lien: "fe80::2", xa: "E0000000000000D1")
        let m = try Self.deuxRouteurs(Instantane(annonces: b.annonces))
        #expect(m.routeurs[1]?.candidats == ["Alpha", "HomePod avant"] && m.routeurs[2]?.candidats == ["Alpha", "HomePod avant"])
    }
""")
# Les anneaux du graphe (rangement des enfants, rayon des zones, repli des angles) disparaissent avec lui.
i = s.index("    /// Mini-maillage a la main, pour les branches du rangement des enfants que la capture n'atteint pas.")
s = s[:i].rstrip() + "\n}\n"
assert "Disposition" not in s and "Point2D" not in s
open(p, 'w', encoding='utf-8').write(s)

# Affichage de la sonde : noms des noeuds inconnus par LibellesNoeuds ; plus d'epaisseurs par qualite
# (les liens radio font 2 pt) ; le redessin chaque minute est teste sur FenetrePieces.
p = 'MaillageThreadTests/AffichageSondeTests.swift'
s = open(p, encoding='utf-8').read()
s = remplacer(s, 'GrapheCanvas.libelleInconnu', 'LibellesNoeuds.inconnu', fois=7)
s = couper(s, "    /// Epaisseur d'un lien de la sonde : le lien radio s'epaissit avec la qualite (la couleur\n",
           "    /// Mode demo : maillage de demo ; fiche d'un enfant et d'un routeur.")
s = couper(s, "    /// Ce qui est entre les chevrons de la premiere `nom<…>` d'un type imprime, chevrons imbriques\n",
           "    /// « Renommer… » : pour un routeur de l'instantane, un appareil connu ou un appareil disparu")
s = remplacer(s, """    /// Noms des routeurs de bordure d'un reseau, par instance, en un seul endroit (libelles du
    /// graphe, fiche, candidats) : le surnom d'abord, l'instance sinon.""",
              """    /// Noms des routeurs de bordure d'un reseau, par instance, en un seul endroit (libelles de la
    /// vue, fiche, candidats) : le surnom d'abord, l'instance sinon.""")
assert "GrapheCanvas" not in s and "FenetreGraphe" not in s
open(p, 'w', encoding='utf-8').write(s)

# Barre d'outils, tournee et fiche : FenetreTests (ex-GrapheTests), sans la projection ni les titres des zones.
p = 'MaillageThreadTests/FenetreTests.swift'
s = open(p, encoding='utf-8').read()
s = couper(s, "    @Test func projection() {", "    /// Le bouton rafraichir du graphe lance aussi le passeur")
s = couper(s, "    /// La ligne de la tournee, sous la barre et le bandeau de scission, ne recouvre pas la bande\n",
           "    /// Pendant une tournee, la barre d'outils garde sa largeur")
s = remplacer(s, """@Suite("Graphe : projection du plan vers la vue")
struct GrapheTests {""", """@Suite("Fenetre : barre d'outils et ligne de la tournee")
struct FenetreTests {""")
s = remplacer(s, "    /// Le bouton rafraichir du graphe lance aussi le passeur",
              "    /// Le bouton rafraichir de la barre lance aussi le passeur")
s = remplacer(s, """    /// Pastille du graphe : seulement pour une batterie faible ; le niveau, sinon « faible ».""",
              """    /// Pastille d'un nom : seulement pour une batterie faible ; le niveau, sinon « faible ».""")
s = remplacer(s, 'GrapheCanvas.pastilleBatterie', 'LibellesNoeuds.pastilleBatterie', fois=5)
assert "GrapheCanvas" not in s and "Projection" not in s and "FenetreGraphe" not in s
open(p, 'w', encoding='utf-8').write(s)
EOF
```

- [ ] **Step 2 : vérifier qu'ils passent encore, avec l'ancien graphe.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/RapprochementTests MaillageCoeurTests/GrapheReseauTests MaillageThreadTests/AffichageSondeTests MaillageThreadTests/FenetreTests MaillageThreadTests/CourbesFicheTests`
Expected: `Test run with 21 tests in 2 suites passed` (cœur) et `Test run with 21 tests in 3 suites passed` (app) : `RapprochementTests`, `GrapheReseauTests`, `AffichageSondeTests`, `FenetreTests`, `CourbesFicheTests`, `** TEST SUCCEEDED **`. Rien d'eux ne dépend plus de l'ancien graphe.

- [ ] **Step 3 : écrire le code.** Déplacer, retirer, puis modifier :

```bash
git mv MaillageThread/Vues/Graphe/FenetreGraphe.swift MaillageThread/Vues/Pieces/MorceauxFenetre.swift
```

```bash
git mv MaillageThread/Vues/Graphe/FicheNoeud.swift MaillageThread/Vues/Pieces/FicheNoeud.swift
```

```bash
git mv MaillageThread/Vues/Graphe/Palette.swift MaillageThread/Vues/Pieces/Palette.swift
```

```bash
git mv MaillageThread/Vues/Graphe/CourbesFiche.swift MaillageThread/Vues/Pieces/CourbesFiche.swift
```

```bash
git rm MaillageThread/Vues/Graphe/GrapheCanvas.swift MaillageThread/Vues/Graphe/PlacementLibelles.swift MaillageThread/Vues/Graphe/Projection.swift MaillageThread/Vues/Graphe/MesureLibelles.swift MaillageCoeur/Disposition/Disposition.swift
```

Dans `MaillageThread/Vues/Pieces/Palette.swift`, remplacer :

```swift
/// Couleurs du graphe, en mode sombre (fond profond) et clair (fond pale).
```

par :

```swift
/// Couleurs de la vue par pieces, en mode sombre (fond profond) et clair (fond pale).
```

Dans `MaillageThread/Vues/Pieces/Palette.swift`, remplacer :

```swift
    var texte: Color { sombre ? Color(white: 0.9) : Color(white: 0.2) }
    var texteDiscret: Color { sombre ? Color(white: 0.7) : Color(white: 0.4) }
    var lien: Color { sombre ? Color.white.opacity(0.28) : Color.black.opacity(0.22) }
    var lienEclaire: Color { sombre ? Color.white.opacity(0.85) : Color.black.opacity(0.7) }
    var selection: Color { sombre ? .white : .black }
    /// Fond discret sous un libelle : la couleur du fond du graphe, un peu transparente.
    /// Dessine par-dessus les liens et les traits, il les cache sous le texte.
    var fondLibelle: Color {
        sombre ? Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.8) : Color(red: 0.95, green: 0.96, blue: 0.99).opacity(0.85)
    }
```

par :

```swift
    var selection: Color { sombre ? .white : .black }
```

Dans `MaillageThread/Vues/Pieces/Palette.swift`, remplacer :

```swift
    /// La principale en bleu, les autres en ambre, les sans-partition en gris.
    func zone(_ z: Disposition.Zone) -> Color {
        if z.id.isEmpty { return .gray }
        return z.principale ? Color(red: 0.23, green: 0.51, blue: 0.96) : Color(red: 0.96, green: 0.62, blue: 0.04)
    }

```

par :

```swift

```

Dans `MaillageCoeur/Maillage/Rapprochement.swift`, remplacer :

```swift
    /// elles ne sont pas dessinees a part (le centre de la zone excepte, voir `Disposition`).
```

par :

```swift
    /// elles ne sont pas des noeuds a part (le centre de la partition excepte, voir `GrapheReseau`).
```

Puis ce script : `MorceauxFenetre.swift` perd `FenetreGraphe` et `EnTeteGraphe` (remplacés par `FenetrePieces` et `EnTetePieces`), et sa légende trace les liens radio à 2 pt ; la fiche et `Surveillance` nomment les nœuds que seule la sonde connaît par `LibellesNoeuds.inconnu` :

```bash
python3 - <<'EOF'
def remplacer(s, ancien, nouveau, fois=1):
    assert s.count(ancien) == fois, (ancien[:70], s.count(ancien))
    return s.replace(ancien, nouveau)


# Morceaux de la fenetre : sans FenetreGraphe ni EnTeteGraphe (remplaces par FenetrePieces et EnTetePieces).
p = 'MaillageThread/Vues/Pieces/MorceauxFenetre.swift'
s = open(p, encoding='utf-8').read()
i = s.index("/// Fenetre du graphe : le graphe occupe toute la fenetre ; barre d'outils,")
j = s.index("/// Barre d'outils flottante : reseau, appareils IP, journal, rafraichir.", i)
s = s[:i] + s[j:]
s = remplacer(s, """/// Noeud choisi pour une feuille (surnom).
struct NoeudChoisi: Identifiable {""", """// Morceaux de la fenetre de la vue par pieces, repris de celle du graphe : barre d'outils, ligne de
// la tournee, bandeau de scission, legende des liens, ecran d'attente, appareils IP, « Renommer… ».

/// Noeud choisi pour une feuille (surnom).
struct NoeudChoisi: Identifiable {""")
s = remplacer(s, """/// Rien hors tournee. Vue a part : seule elle se redessine a chaque pas de la tournee, pas la
/// fenetre du graphe.""", """/// Rien hors tournee. Vue a part : seule elle se redessine a chaque pas de la tournee, pas la
/// fenetre de la vue.""")
s = remplacer(s, """/// Legende des liens du graphe (en bas a gauche, cachee sous une fiche) : avec
/// la sonde, traits pleins (lien radio, colore par la qualite) et pointilles
/// (rattachement suppose) ; « ancien » si la sonde ne repond plus.""", """/// Legende des liens (en bas a gauche, cachee sous une fiche) : avec la sonde,
/// traits pleins (lien radio, colore par la qualite) et pointilles (rattachement
/// suppose) ; « ancien » si la sonde ne repond plus.""")
s = remplacer(s, """                        style: StrokeStyle(lineWidth: GrapheCanvas.epaisseurLienSonde(.radio, qualite: 3), lineCap: .round))""",
              """                        style: StrokeStyle(lineWidth: 2, lineCap: .round))""")
assert "GrapheCanvas" not in s and "FenetreGraphe" not in s and "EnTeteGraphe" not in s
open(p, 'w', encoding='utf-8').write(s)

# Fiche et surveillance : le nom d'un noeud que seule la sonde connait vient de LibellesNoeuds.
p = 'MaillageThread/Vues/Pieces/FicheNoeud.swift'
s = open(p, encoding='utf-8').read()
s = remplacer(s, 'GrapheCanvas.libelleInconnu', 'LibellesNoeuds.inconnu', fois=1)
open(p, 'w', encoding='utf-8').write(s)
p = 'MaillageThread/Surveillance/Surveillance.swift'
s = open(p, encoding='utf-8').read()
s = remplacer(s, 'GrapheCanvas.libelleInconnu', 'LibellesNoeuds.inconnu', fois=2)
open(p, 'w', encoding='utf-8').write(s)
EOF
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh MaillageCoeurTests/RapprochementTests MaillageCoeurTests/GrapheReseauTests MaillageThreadTests/AffichageSondeTests MaillageThreadTests/FenetreTests MaillageThreadTests/CourbesFicheTests`
Expected: `Test run with 21 tests in 2 suites passed` (cœur) et `Test run with 21 tests in 3 suites passed` (app) : `RapprochementTests`, `GrapheReseauTests`, `AffichageSondeTests`, `FenetreTests`, `CourbesFicheTests`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes, en français et en anglais.** Le Step 4 a compilé : mettre le catalogue à jour avec les clés que le compilateur a extraites.

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" outils/synchroniser-textes.sh
```

Expected : ces 3 clés y sont marquées périmées (`"extractionState" : "stale"`) : « %@ (partagé) », « Partition %@ · %@ », « Sans partition connue ».

Puis les traductions, par ce script, qui retire de `interface.json` les clés mortes et garde le fichier trié au format de l'outil ; `outils/traduire.py` retire ensuite du catalogue les clés périmées et donne l'anglais aux nouvelles :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
for k in ["%@ (partagé)", "Partition %@ · %@", "Sans partition connue"]:
    del d[k]
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

Expected : aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 319 tests in 34 suites passed` (cœur) et `Test run with 248 tests in 28 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; 13 tests et 1 suite de moins pour le cœur, 21 tests et 2 suites de moins pour l'app. Pour le cœur, les tests de `DispositionTests` partent ; pour l'app, ceux de `PlacementLibellesTests` et ceux qui ne valaient que pour le graphe.

- [ ] **Step 7 : commit.**

```bash
git add MaillageCoeur/Maillage/Rapprochement.swift MaillageCoeurTests/RapprochementTests.swift MaillageThreadTests/AffichageSondeTests.swift MaillageThreadTests/FenetreTests.swift MaillageThreadTests/CourbesFicheTests.swift MaillageThread/Surveillance/Surveillance.swift MaillageThread/Vues/Pieces/MorceauxFenetre.swift MaillageThread/Vues/Pieces/FicheNoeud.swift MaillageThread/Vues/Pieces/Palette.swift MaillageThread/Vues/Pieces/CourbesFiche.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Retirer l'ancien graphe et reprendre ses tests utiles

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 14: Documentation

**Files:**
- Modify: `README.fr.md`, `README.md` (blocs ci-dessous)
- Modify: `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` (blocs ci-dessous : le lien vers ce plan ; les recos validées le 30/09, en sections 1, 2.3, 2.4, 7 et 10)

**Interfaces:**
- Consumes :
  - la vue par pièces des tâches 1 à 13, `outils/mesurer.sh` (tâche 4), `-captures` (tâche 12).
- Produces :
  - une section « Vue par pièces (2D et 3D) » dans chaque README, avant « Noms de Maison » : étages et pièces, 2D et 3D, zoom sémantique, pièce isolée, places gardées, clics droits, « Réduire les animations », temps de calcul ;
  - les passages qui parlaient du graphe (partition « partagée », rafraîchissement, liens de la sonde, carte du dépôt) disent la vue par pièces ; `outils/mesurer.sh` et `-captures` sont documentés ; la pièce des routeurs d'Apple (d'après leur nom, « Placer dans une pièce… »), la fenêtre sombre et le double-clic aussi ;
  - la spec pointe vers ce plan, et porte les recos validées le 30/09 (ajouts du 01/10) : fenêtre sombre (section 1), pièce d'un routeur de bordure (2.3), `pieces-routeurs.json` (2.4), double-clic sur le fond et « Réduire les animations » (7), tests de la pièce des routeurs (10).

- [ ] **Step 1 : les README et la spec.** Les blocs, dans l'ordre (le français, puis l'anglais, puis la spec).

Dans `README.fr.md`, remplacer :

```markdown
Les appareils sont placés d'après le préfixe OMR de leur adresse. Quand deux
partitions annoncent le même préfixe OMR (vu le 28 septembre : un hub isolé
avait repris le préfixe de la partition principale), le Mac ne peut pas
savoir de quel côté est un appareil : l'app donne le préfixe à la partition
qui a le plus de routeurs de bordure et le marque « partagé » dans le graphe
et sur la fiche de l'appareil.
```

par :

```markdown
Les appareils sont placés d'après le préfixe OMR de leur adresse. Quand deux
partitions annoncent le même préfixe OMR (vu le 28 septembre : un hub isolé
avait repris le préfixe de la partition principale), le Mac ne peut pas
savoir de quel côté est un appareil : l'app donne le préfixe à la partition
qui a le plus de routeurs de bordure, et la fiche de l'appareil dit sa
partition « incertaine : préfixe partagé ».
```

Dans `README.fr.md`, remplacer :

````markdown
```sh
outils/tester.sh                                   # génère, compile, tous les tests
outils/tester.sh MaillageCoeurTests/SuiviTests     # une suite
````

par :

````markdown
```sh
outils/tester.sh                                   # génère, compile, tous les tests
outils/tester.sh MaillageCoeurTests/SuiviTests     # une suite
outils/mesurer.sh                                  # temps de calcul de la vue par pièces, en Release
````

Dans `README.fr.md`, remplacer :

```markdown
Lancer : `Maillage Thread.app` dans `…/DerivedData/maillage/Build/Products/Debug/`.
L'app vit dans la barre des menus ; le graphe s'ouvre depuis son menu (et de
lui-même au tout premier lancement).
Un gestionnaire de barre des menus (Bartender, Pelmet…) peut masquer son
icône : les nouvelles icônes arrivent du côté masqué.
```

par :

```markdown
Lancer : `Maillage Thread.app` dans `…/DerivedData/maillage/Build/Products/Debug/`.
L'app vit dans la barre des menus ; la vue par pièces s'ouvre depuis son menu
(« Ouvrir le graphe », et d'elle-même au tout premier lancement).
Un gestionnaire de barre des menus (Bartender, Pelmet…) peut masquer son
icône : les nouvelles icônes arrivent du côté masqué.
```

Dans `README.fr.md`, remplacer :

````markdown
```sh
open "…/Maillage Thread.app" --args -demo
open "…/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D   # fiche ouverte
```
````

par :

````markdown
```sh
open "…/Maillage Thread.app" --args -demo
open "…/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D   # fiche ouverte
open "…/Maillage Thread.app" --args -demo -captures ~/Library/Containers/fr.djoko.maillage/Data/tmp/captures
```

Avec `-captures <dossier>`, l'app écrit douze images PNG de la vue par pièces
(2D, envol, 3D, zooms, pièces isolées, survol), puis quitte, sans fenêtre.
L'app vit dans un bac à sable : le dossier doit être dans son conteneur.
````

Dans `README.fr.md`, remplacer :

```markdown
| `MaillageCoeur/` | framework sans interface : décodage des TXT, instantané (réseaux, partitions, préfixes, appareils), suivi et événements du journal, journal en fichiers, noms, disposition du graphe, table de routage ; testé sur le relevé réel et sur la panne rejouée |
```

par :

```markdown
| `MaillageCoeur/` | framework sans interface : décodage des TXT, instantané (réseaux, partitions, préfixes, appareils), suivi et événements du journal, journal en fichiers, noms, table de routage ; testé sur le relevé réel et sur la panne rejouée |
| `MaillageCoeur/Scene/` | vue par pièces, sans interface : nœuds et liens, étages et pièces, cartes, disposition (déterministe, avec budget), places gardées, caméra et envol, placement des noms et zoom sémantique, projection vers le moteur `Canvas` ; optimisé même en Debug |
```

Dans `README.fr.md`, remplacer :

```markdown
| `MaillageThread/Vues/` | barre des menus, fenêtre du graphe (Canvas, surcouches en verre), journal, réglages (fenêtre AppKit à onglets : Général, Notifications, Maison, Sonde, Diagnostic ; ⌘,) |
```

par :

```markdown
| `MaillageThread/Vues/` | barre des menus, fenêtre de la vue par pièces (`Pieces/` : moteur `Canvas`, surcouches en verre, captures), journal, réglages (fenêtre AppKit à onglets : Général, Notifications, Maison, Sonde, Diagnostic ; ⌘,) |
```

Dans `README.fr.md`, remplacer :

```markdown
| `outils/anonymiser-sonde.py` | anonymise une capture de la sonde avant d'en faire des données de test |
```

par :

```markdown
| `outils/anonymiser-sonde.py` | anonymise une capture de la sonde avant d'en faire des données de test |
| `outils/mesurer.sh` | temps de calcul de la vue par pièces (disposition, placement des noms), en Release |
```

Dans `README.fr.md`, remplacer :

```markdown
| `docs/superpowers/` | conception (spec) et plans d'implémentation |
```

par :

```markdown
| `docs/superpowers/` | conception (spec) et plans d'implémentation |

## Vue par pièces (2D et 3D)

La fenêtre montre le réseau dans la maison : un plateau rond par étage, une
carte de verre par pièce avec une ligne par appareil, et les vrais liens radio
par-dessus. Elle reste sombre, comme sa maquette, même quand le Mac est en
clair. Conception :
`docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`.

- **Étages et pièces.** Les étages sont les zones de Maison, dans leur ordre
  (le premier en bas) ; une pièce dans plusieurs zones va dans la première,
  les pièces hors zone forment « Autres pièces », et une maison sans zones n'a
  qu'un plateau « Maison ». Un appareil prend la pièce de son accessoire de
  Maison ; un routeur de bordure, celle de l'accessoire de Maison qui porte le
  nom de son annonce. Maison ne donne ni les HomePod ni l'Apple TV : un tel
  routeur va dans la pièce dont le nom figure dans le sien (« HomePod mini
  chambre » dans « Chambre » : en mots entiers, sans égard à la casse ni aux
  accents ; le nom de pièce le plus long gagne, une égalité ne place rien).
  Pour les autres, sa fiche propose « Placer dans une pièce… » : le choix passe
  avant le nom, et il est gardé sous le nom de son annonce
  (`pieces-routeurs.json` dans le dossier de l'app, jamais en démo). Les
  nœuds qui restent sans pièce vont dans « Sans pièce », sur le plateau du
  bas. Sans aucune pièce de Maison (Passeur Noms jamais passé), une carte par
  routeur, avec ses enfants.
- **2D et 3D** (barre d'outils ; le mode est gardé d'un lancement à l'autre) :
  la 2D est une vue de dessus, les étages côte à côte ; la 3D les empile dans
  la sphère de la maison, avec une rotation lente qu'on peut couper. La
  bascule est un envol de 2,6 s.
- **Gestes.** Molette ou pincement : zoom, vers le curseur en 2D. Glisser le
  fond : déplacer la vue en 2D, tourner autour de la maison en 3D. Glisser une
  pièce : la déplacer dans son étage ; sa place est gardée
  (`positions-pieces.json` dans le dossier de l'app, jamais en démo). Clic sur
  une pièce : l'isoler (les autres s'estompent, un repère montre un parent
  situé ailleurs) ; clic à côté, Échap ou « Maison » dans le fil : revenir.
  Double-clic sur le fond : retour à la vue d'ensemble, zoom et déplacement
  annulés. Clic sur un appareil ou sur son nom : sa fiche.
- **Clics droits** : sur un nom d'étage, « Monter d'un étage » et « Descendre
  d'un étage » ; sur le fond, « Replacer les pièces automatiquement » (les
  places gardées partent, pas l'ordre des étages).
- **Zoom sémantique** : de loin, les pièces seules ; puis les routeurs ; de
  près, tous les noms qui tiennent. La ligne en bas à gauche dit le niveau, ou
  combien de noms sont masqués faute de place.
- « Réduire les animations » (accessibilité de macOS) : l'envol et le retour
  par double-clic deviennent un fondu, les autres vols de caméra sont
  immédiats, la rotation lente est coupée.
- La disposition des pièces est calculée hors du fil principal : quelques
  centièmes de seconde pour la démo, moins d'une seconde pour 20 pièces et 100
  appareils (`outils/mesurer.sh`).
```

Dans `README.fr.md`, remplacer :

```markdown
- Rafraîchissement : la fenêtre du graphe lance Passeur Noms à son ouverture
  (si le relevé et la dernière demande ont plus de 15 min), puis toutes les
  heures ; « Rafraîchir depuis Maison » (menu ou réglages) et le bouton
  rafraîchir du graphe le font à la demande. Un relevé à la fois : une
  demande pendant un relevé est ignorée. La fenêtre de Passeur Noms ne fait
  que passer derrière les autres.
```

par :

```markdown
- Rafraîchissement : la fenêtre de la vue par pièces lance Passeur Noms à son
  ouverture (si le relevé et la dernière demande ont plus de 15 min), puis
  toutes les heures ; « Rafraîchir depuis Maison » (menu ou réglages) et le
  bouton rafraîchir de sa barre le font à la demande. Un relevé à la fois :
  une demande pendant un relevé est ignorée. La fenêtre de Passeur Noms ne
  fait que passer derrière les autres.
```

Dans `README.fr.md`, remplacer :

```markdown
- Batteries : niveau, état de charge et alerte de l'accessoire lui-même, pour
  chaque accessoire de Maison qui a une batterie. La fiche de l'appareil les
  montre avec l'âge du relevé ; dans le graphe, une pastille orange en
  surbrillance signale une batterie faible (l'accessoire le dit, ou son niveau
  est de 20 % ou moins).
```

par :

```markdown
- Batteries : niveau, état de charge et alerte de l'accessoire lui-même, pour
  chaque accessoire de Maison qui a une batterie. La fiche de l'appareil les
  montre avec l'âge du relevé ; dans la vue, une pastille orange en
  surbrillance, au bout du nom, signale une batterie faible (l'accessoire le
  dit, ou son niveau est de 20 % ou moins).
```

Dans `README.fr.md`, remplacer :

```markdown
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
  clé de ce Mac, le relevé de la sonde dans les Réglages et son maillage : le
  graphe revient aussitôt aux pointillés.
  Limites : pas de fin de session (une place de la carte reste prise 30 s,
  la reprise automatique le répare) ; la file de réception de la carte n'a
  que 4 places (un envoi groupé de 8 `diag` peut en voir attendre le renvoi à
  2 s) ; une ligne `routeurs` perdue donne une table partielle, ou aucune si
  la dernière (`"suite":false`) se perd ; détails dans la spec (section
  3 bis).
- Une tournée toutes les 5 minutes, et au rafraîchissement : le bouton
  rafraîchir du graphe relit le réseau, lance une tournée (sauf s'il y en a
  déjà une) et Passeur Noms ; son aide dit lesquels il lancera vraiment.
  Pendant une tournée, une ligne sous la barre d'outils du graphe (et sous le
  bandeau d'un réseau scindé) montre son étape, un compteur de requêtes et sa
  durée (« Balayage des routeurs muets · 24/48 · 0:42 ») ; sa place reste
  gardée au-dessus du graphe tant qu'une sonde est retenue : rien ne bouge au
  début ni à la fin d'une tournée. Réglages › Sonde et la ligne du menu
  montrent aussi l'étape et le compteur.
```

par :

```markdown
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
  rafraîchir de la barre d'outils relit le réseau, lance une tournée (sauf
  s'il y en a déjà une) et Passeur Noms ; son aide dit lesquels il lancera
  vraiment. Pendant une tournée, une ligne sous la barre d'outils (et sous le
  bandeau d'un réseau scindé) montre son étape, un compteur de requêtes et sa
  durée (« Balayage des routeurs muets · 24/48 · 0:42 ») ; sa place reste
  gardée au-dessus de la vue tant qu'une sonde est retenue : rien ne bouge au
  début ni à la fin d'une tournée. Réglages › Sonde et la ligne du menu
  montrent aussi l'étape et le compteur.
```

Dans `README.fr.md`, remplacer :

```markdown
- Dans le graphe, les traits pleins sont les liens radio, colorés et épaissis
  par la qualité (vert 3, jaune 2, orange 1, gris inconnue) ; le trait d'un
  enfant vers son parent reste fin. Les pointillés restent pour ce que la
  sonde ne voit pas. Les appareils qui routent passent sur l'anneau
  intérieur, les enfants se rangent près de leur parent. La fiche donne le
  parent et la qualité, ou le nombre de voisins et d'enfants d'un routeur. Si
  la sonde ne répond plus, le dernier maillage est marqué ancien 6 minutes
  après sa réception (jamais pendant une tournée) ; après 15 minutes, le
  graphe revient aux pointillés. Le graphe se redessine chaque minute : ces
  deux changements y paraissent avec une minute de retard au plus, sans autre
  événement, comme le « vu il y a … » et les courbes de la fiche ouverte.
```

par :

```markdown
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
```

Dans `README.md`, remplacer :

```markdown
Devices are placed by the OMR prefix of their address. When two partitions
announce the same OMR prefix (seen on September 28: an isolated hub had
picked up the main partition's prefix), the Mac cannot tell which side a
device is on: the app gives the prefix to the partition with the most border
routers and marks it "shared" in the graph and on the device card.
```

par :

```markdown
Devices are placed by the OMR prefix of their address. When two partitions
announce the same OMR prefix (seen on September 28: an isolated hub had
picked up the main partition's prefix), the Mac cannot tell which side a
device is on: the app gives the prefix to the partition with the most border
routers, and the device card says its partition is "uncertain: shared
prefix".
```

Dans `README.md`, remplacer :

````markdown
```sh
outils/tester.sh                                   # generate, build, all tests
outils/tester.sh MaillageCoeurTests/SuiviTests     # one suite
````

par :

````markdown
```sh
outils/tester.sh                                   # generate, build, all tests
outils/tester.sh MaillageCoeurTests/SuiviTests     # one suite
outils/mesurer.sh                                  # timings of the room view, in Release
````

Dans `README.md`, remplacer :

```markdown
Run: `Maillage Thread.app` in `…/DerivedData/maillage/Build/Products/Debug/`.
The app lives in the menu bar; the graph opens from its menu (and by itself on
the very first launch).
A menu bar manager (Bartender, Pelmet…) may hide its icon: new icons land on
the hidden side.
```

par :

```markdown
Run: `Maillage Thread.app` in `…/DerivedData/maillage/Build/Products/Debug/`.
The app lives in the menu bar; the room view opens from its menu ("Open
Graph", and by itself on the very first launch).
A menu bar manager (Bartender, Pelmet…) may hide its icon: new icons land on
the hidden side.
```

Dans `README.md`, remplacer :

````markdown
```sh
open "…/Maillage Thread.app" --args -demo
open "…/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D   # card open
```
````

par :

````markdown
```sh
open "…/Maillage Thread.app" --args -demo
open "…/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D   # card open
open "…/Maillage Thread.app" --args -demo -captures ~/Library/Containers/fr.djoko.maillage/Data/tmp/captures
```

With `-captures <folder>`, the app writes twelve PNG images of the room view
(2D, flight, 3D, zooms, isolated rooms, hover), then quits, with no window.
The app is sandboxed: the folder must be inside its container.
````

Dans `README.md`, remplacer :

```markdown
| `MaillageCoeur/` | framework without UI: TXT decoding, snapshot (networks, partitions, prefixes, devices), tracking and log events, file log, names, graph layout, routing table; tested on the real survey and on the replayed outage |
```

par :

```markdown
| `MaillageCoeur/` | framework without UI: TXT decoding, snapshot (networks, partitions, prefixes, devices), tracking and log events, file log, names, routing table; tested on the real survey and on the replayed outage |
| `MaillageCoeur/Scene/` | room view without UI: nodes and links, floors and rooms, cards, layout (deterministic, with a budget), kept places, camera and flight, label placement and semantic zoom, projection for the `Canvas` engine; optimized even in Debug |
```

Dans `README.md`, remplacer :

```markdown
| `MaillageThread/Vues/` | menu bar, graph window (Canvas, glass overlays), log window, settings (AppKit window with tabs: General, Notifications, Home, Probe, Diagnostics; ⌘,) |
```

par :

```markdown
| `MaillageThread/Vues/` | menu bar, room view window (`Pieces/`: `Canvas` engine, glass overlays, captures), log window, settings (AppKit window with tabs: General, Notifications, Home, Probe, Diagnostics; ⌘,) |
```

Dans `README.md`, remplacer :

```markdown
| `outils/anonymiser-sonde.py` | anonymizes a probe capture before it becomes test data |
```

par :

```markdown
| `outils/anonymiser-sonde.py` | anonymizes a probe capture before it becomes test data |
| `outils/mesurer.sh` | timings of the room view (layout, label placement), in Release |
```

Dans `README.md`, remplacer :

```markdown
| `docs/superpowers/` | design (spec) and implementation plans |
```

par :

```markdown
| `docs/superpowers/` | design (spec) and implementation plans |

## Room view (2D and 3D)

The window shows the network in the house: a round platform per floor, a glass
card per room with one line per device, and the real radio links on top. It
stays dark, like its mockup, even when the Mac is in light mode. Design:
`docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` (in
French).

- **Floors and rooms.** Floors are the Home zones, in their order (the first
  at the bottom); a room in several zones goes to the first one, rooms outside
  any zone make "Other rooms", and a house without zones has a single "Home"
  platform. A device takes the room of its Home accessory; a border router,
  the room of the Home accessory named like its announcement. Home gives
  neither the HomePods nor the Apple TV: such a router goes to the room whose
  name is in its own ("HomePod mini chambre" to "Chambre": whole words,
  ignoring case and accents; the longest room name wins, a tie places
  nothing). For the others, its card offers "Place in a room…": the choice
  comes before the name, and is kept under the name of its announcement
  (`pieces-routeurs.json` in the app folder, never in the demo). Nodes still
  without a room go to "No room", on the bottom platform. With no Home room at
  all (Passeur Noms never ran), one card per router, with its children.
- **2D and 3D** (toolbar; the mode is kept from one launch to the next): 2D is
  a top view, floors side by side; 3D stacks them inside the house sphere,
  with a slow rotation you can turn off. Switching is a 2.6 s flight.
- **Gestures.** Scroll wheel or pinch: zoom, towards the pointer in 2D. Drag
  the background: pan in 2D, orbit around the house in 3D. Drag a room: move
  it within its floor; its place is kept (`positions-pieces.json` in the app
  folder, never in the demo). Click a room: isolate it (the others fade, a tag
  points to a parent elsewhere); click outside, Esc or "Home" in the path:
  come back. Double-click the background: back to the overview, zoom and pan
  undone. Click a device or its name: its card.
- **Right clicks**: on a floor name, "Move up one floor" and "Move down one
  floor"; on the background, "Arrange rooms automatically" (kept places go,
  not the floor order).
- **Semantic zoom**: from afar, rooms only; then routers; up close, every name
  that fits. The line at the bottom left gives the level, or how many names
  are hidden for lack of room.
- "Reduce motion" (macOS accessibility): the flight and the double-click
  return become a fade, other camera flights are immediate, the slow rotation
  is off.
- The room layout is computed off the main thread: a few hundredths of a
  second for the demo, under a second for 20 rooms and 100 devices
  (`outils/mesurer.sh`).
```

Dans `README.md`, remplacer :

```markdown
- Refreshing: the graph window launches Passeur Noms when it opens (if the
  last reading and the last request are older than 15 min), then every hour;
  "Refresh from Home" (menu or settings) and the refresh button of the graph
  do it on demand. One reading at a time: a request during a reading is
  ignored. The window of Passeur Noms only flashes behind the others.
```

par :

```markdown
- Refreshing: the room view window launches Passeur Noms when it opens (if
  the last reading and the last request are older than 15 min), then every
  hour; "Refresh from Home" (menu or settings) and the refresh button of its
  toolbar do it on demand. One reading at a time: a request during a reading
  is ignored. The window of Passeur Noms only flashes behind the others.
```

Dans `README.md`, remplacer :

```markdown
- Batteries: level, charging state and the accessory's own low-battery alert,
  for every Home accessory with a battery. The device card shows them with the
  age of the reading; in the graph, a glowing orange badge marks a low battery
  (the accessory says so, or its level is 20 % or less).
```

par :

```markdown
- Batteries: level, charging state and the accessory's own low-battery alert,
  for every Home accessory with a battery. The device card shows them with the
  age of the reading; in the view, a glowing orange badge at the end of the
  name marks a low battery (the accessory says so, or its level is 20 % or
  less).
```

Dans `README.md`, remplacer :

```markdown
- **Access over the Thread network** (firmware 1.0.2, like the Halo bridge),
  to unplug the probe from the Mac and walk it around the house so that it
  hears every router. With the probe plugged in and connected, "Allow Network
  Access" (Settings › Probe) creates over USB a key that stays in this Mac's
  keychain; the button then becomes "Regenerate Key" (a new key replaces the
  old one), and the "Link" choice (USB or Thread Network) appears. Over the
  network, the app closes the port, connects by itself to `<host name>.local`,
  UDP port 5480, and reconnects; a keepalive goes out after 10 s of silence,
  and Settings › Probe keeps the cause of the last disconnection until the
  next connection. Halo's H1 envelope authenticates the messages without
  encrypting them: the topology travels in clear on the local network. The
  Mac needs an IPv6 route to the OMR prefix (see "Route to the Thread
  network" below). "Forget the probe" removes this Mac's key, the probe's
  survey in Settings and its mesh: the graph goes straight back to dotted
  lines. Limits: no end of session (a place on the board stays taken 30 s,
  the automatic retry fixes it); the board's receive queue has only 4 places
  (a batch of 8 `diag` may see some of them wait for the 2 s resend); a lost
  `routeurs` line gives a partial table, or none if the last one
  (`"suite":false`) is lost; details in the spec (section 3 bis).
- A tour every 5 minutes, and on refresh: the refresh button of the graph
  rereads the network, starts a tour (unless one is running) and launches
  Passeur Noms; its help tag says which of these it will actually start. While
  a tour runs, a line under the graph's toolbar (and under the split-network
  banner) shows its step, a counter of requests and its duration ("Scan of
  silent routers · 24/48 · 0:42"); its place stays reserved above the graph
  while a probe is remembered, so nothing moves when a tour starts or ends.
  Settings › Probe and the menu line show the step and the counter too.
```

par :

```markdown
- **Access over the Thread network** (firmware 1.0.2, like the Halo bridge),
  to unplug the probe from the Mac and walk it around the house so that it
  hears every router. With the probe plugged in and connected, "Allow Network
  Access" (Settings › Probe) creates over USB a key that stays in this Mac's
  keychain; the button then becomes "Regenerate Key" (a new key replaces the
  old one), and the "Link" choice (USB or Thread Network) appears. Over the
  network, the app closes the port, connects by itself to `<host name>.local`,
  UDP port 5480, and reconnects; a keepalive goes out after 10 s of silence,
  and Settings › Probe keeps the cause of the last disconnection until the
  next connection. Halo's H1 envelope authenticates the messages without
  encrypting them: the topology travels in clear on the local network. The
  Mac needs an IPv6 route to the OMR prefix (see "Route to the Thread
  network" below). "Forget the probe" removes this Mac's key, the probe's
  survey in Settings and its mesh: the view goes straight back to dotted
  lines. Limits: no end of session (a place on the board stays taken 30 s,
  the automatic retry fixes it); the board's receive queue has only 4 places
  (a batch of 8 `diag` may see some of them wait for the 2 s resend); a lost
  `routeurs` line gives a partial table, or none if the last one
  (`"suite":false`) is lost; details in the spec (section 3 bis).
- A tour every 5 minutes, and on refresh: the refresh button of the toolbar
  rereads the network, starts a tour (unless one is running) and launches
  Passeur Noms; its help tag says which of these it will actually start. While
  a tour runs, a line under the toolbar (and under the split-network banner)
  shows its step, a counter of requests and its duration ("Scan of silent
  routers · 24/48 · 0:42"); its place stays reserved above the view while a
  probe is remembered, so nothing moves when a tour starts or ends.
  Settings › Probe and the menu line show the step and the counter too.
```

Dans `README.md`, remplacer :

```markdown
- In the graph, solid lines are radio links, colored and thickened by quality
  (green 3, yellow 2, orange 1, grey unknown); a child's line to its parent
  stays thin. Dotted lines stay for what the probe does not see. Devices that
  route move to the inner ring, and children sit near their parent. The card
  gives the parent and the quality, or a router's number of neighbors and
  children. If the probe stops answering, the last mesh is marked old 6
  minutes after it was received (never during a tour); after 15 minutes the
  graph goes back to dotted lines. The graph redraws every minute: both
  changes show up within a minute, with no other event needed, and so do the
  open card's "seen … ago" and curves.
```

par :

```markdown
- In the room view, solid lines between routers are radio links (2 points,
  colored by quality: green 3, yellow 2, orange 1, grey unknown); a child's
  line to its parent stays thin. Dotted lines stay for what the probe does not
  see. The mesh leader wears the crown. The card gives the parent and the
  quality, or a router's number of neighbors and children. If the probe stops
  answering, the last mesh is marked old 6 minutes after it was received
  (never during a tour); after 15 minutes the view goes back to dotted lines.
  The view redraws every minute: both changes show up within a minute, with
  no other event needed, and so do the open card's "seen … ago" and curves.
```

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
> - **4b** : la vue par pièces.
```

par :

```markdown
> - **4b** : la vue par pièces ; plan : `docs/superpowers/plans/2026-10-01-maillage-thread-plan4b-vue-pieces.md`.
```

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
- **Le mode 2D ou 3D** est gardé d'un lancement à l'autre.
```

par :

```markdown
- **Le mode 2D ou 3D** est gardé d'un lancement à l'autre.
- **La fenêtre reste sombre**, comme la maquette, même quand le Mac est en clair : la barre, les menus, la fiche et les feuilles aussi (ajout du 01/10, choix de Djoko du 30/09).
```

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
- **Pièce d'un nœud :** celle de l'accessoire de Maison qui lui correspond, par la correspondance du plan 2 (fabrique d'Apple, nœud Matter, pont).
```

par :

```markdown
- **Pièce d'un nœud :** celle de l'accessoire de Maison qui lui correspond, par la correspondance du plan 2 (fabrique d'Apple, nœud Matter, pont).
- **Pièce d'un routeur de bordure** (ajout du 01/10, choix de Djoko du 30/09) : celle de l'accessoire de Maison qui porte le nom de son annonce. HomeKit ne donne à une app tierce ni les HomePod ni l'Apple TV ; pour un routeur sans pièce de Maison, dans cet ordre :
  - **le choix** : sa fiche propose « Placer dans une pièce… », un menu des pièces de la maison, avec « D'après son nom » pour revenir à la règle du nom. Le choix est gardé (section 2.4) ; il passe avant le nom ; une pièce qui n'est plus dans Maison ne compte plus ;
  - **le nom** du routeur, celui qu'affiche l'app (son surnom, sinon son annonce) : il va dans la pièce de Maison dont le nom y figure. La comparaison ignore la casse et les accents, et porte sur des mots entiers, qui doivent se suivre (« HomePod mini chambre » → « Chambre », mais « HomePod salons » → rien). Le nom de pièce le plus long gagne (« Chambre d'amis » avant « Chambre ») ; si deux pièces ont cette longueur, le routeur n'est placé nulle part.
```

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
- Un clic droit sur le fond propose « **Replacer les pièces automatiquement** » : il efface les places gardées de la maison, sauf l'ordre des étages.
```

par :

```markdown
- Un clic droit sur le fond propose « **Replacer les pièces automatiquement** » : il efface les places gardées de la maison, sauf l'ordre des étages.
- **Pièces choisies des routeurs** (section 2.3) : `pieces-routeurs.json`, à côté de `positions-pieces.json`. Par maison (`domicile`), la pièce de chaque routeur, sous l'**instance de son annonce** : le nom sous lequel l'app garde déjà ses surnoms, qui ne change ni avec son RLOC16 ni à son redémarrage. Il ne change que si le routeur est renommé dans Maison ; son choix se perd alors, comme son surnom.
```

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
- le fil en haut à gauche dit « Maison › Salon ».

**Clics droits :**
```

par :

```markdown
- le fil en haut à gauche dit « Maison › Salon ».

**Double-clic sur le fond** (ajout du 01/10, choix de Djoko du 30/09) : retour d'un geste à la vue d'ensemble, pièce isolée relâchée, zoom et déplacement annulés, par le vol de 1,3 s. Le premier clic agit seul, comme un clic à côté : il ferme la fiche et la pièce isolée.

**Clics droits :**
```

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
- les vols de caméra sont immédiats ;
```

par :

```markdown
- le retour par double-clic aussi ;
- les autres vols de caméra sont immédiats ;
```

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
- **`PlacesGardees` :** aller-retour sur disque, une pièce renommée, l'ordre des étages.
```

par :

```markdown
- **`PlacesGardees` :** aller-retour sur disque, une pièce renommée, l'ordre des étages.
- **Pièce des routeurs** (section 2.3) : mots entiers, casse et accents ignorés, le nom de pièce le plus long, l'égalité, le choix avant le nom, un choix dont la pièce a disparu, aller-retour sur disque.
```

- [ ] **Step 2 : la suite ne change pas, en français et en anglais.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" TMPDIR="$HOME/Library/Caches/maillage-plan4b/" outils/tester.sh`
Expected: `Test run with 319 tests in 34 suites passed` (cœur) et `Test run with 248 tests in 28 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement : les effectifs de la fin de la tâche 13.

Puis en anglais :

```bash
xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-plan4b/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-plan4b/maillage-tests-en.log"
```

Expected: `Test run with 319 tests in 34 suites passed` et `Test run with 248 tests in 28 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 3 : commit.**

```bash
git add README.md README.fr.md docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md
git commit -m "Documenter la vue par pieces

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 15: Vérification avec Djoko (par le contrôleur, pas par un sous-agent)

**Files:**
- Modify: `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` (section 10 : la vérification du jour)

**Interfaces:**
- Consumes : tout le plan ; l'app compilée dans le `DD` du plan.
- Produces : la vérification de la section 10 de la spec (« Avec Djoko, à la fin »), notée en comptes seulement.

- [ ] **Step 1 : vérification avec Djoko.** Chaque action sur l'app de Djoko attend son accord. Recompiler (`outils/tester.sh`), puis, avec lui, quitter l'app qui tourne et lancer celle du `DD` en mode direct : `open "$HOME/Library/Developer/Xcode/DerivedData/maillage-plan4b/Build/Products/Debug/Maillage Thread.app"`. L'app peut lancer le passeur d'elle-même à l'ouverture de la fenêtre, si son relevé a plus de 15 minutes : c'est attendu.
  1. **Sa maison.** La fenêtre montre ses étages (ses zones de Maison, dans leur ordre) et ses pièces, en 2D ; aucun nom ne se chevauche ; la ligne de niveau dit ce qui est masqué, et la molette rapproche. Noter le nombre d'étages et de pièces, et le temps avant la première disposition.
  2. **Pièce des routeurs d'Apple, d'après leur nom** (précision 23). Compter ses routeurs de bordure, ceux que leur nom a placés, et ceux qui restent dans « Sans pièce » ; Djoko dit si chaque routeur placé par son nom est dans la bonne pièce. Compter aussi les nœuds de « Sans pièce ».
  3. **« Placer dans une pièce… »** (précision 24). Sur la fiche d'un routeur resté dans « Sans pièce » (« HomePod Palier », par exemple) : le menu montre « D'après son nom », puis les pièces de sa maison, par nom ; en choisir une : le routeur y passe, et la disposition suit. Rouvrir le menu : le choix est coché. Choisir une pièce pour un routeur que son nom avait placé : le choix l'emporte. Quitter l'app, la relancer : les choix sont gardés. Puis « D'après son nom » : le routeur revient à la règle du nom. Djoko garde les choix qu'il veut.
  4. **2D et 3D.** L'envol, sans saut, depuis une vue zoomée ; la sphère en 3D ; la rotation lente, que l'interrupteur coupe ; glisser le fond tourne autour de la maison, dans les bornes.
  5. **Pièce isolée.** Clic sur une pièce : la caméra y vole, les autres s'estompent, les repères « ailleurs » montrent les parents d'autres pièces ; clic sur une autre pièce ; retour par un clic à côté, par Échap, puis par « Maison » dans le fil.
  6. **Double-clic sur le fond** (précision 17). Zoomer et déplacer la vue, isoler une pièce et ouvrir une fiche, puis double-cliquer sur le fond : le premier clic ferme la fiche et la pièce isolée sans attendre, le second ramène à la vue d'ensemble par le vol de 1,3 s. Un clic simple à côté, seul, n'annule ni le zoom ni le déplacement. En 3D, même chose.
  7. **Glisser une pièce,** quitter l'app, la relancer : la pièce a gardé sa place. Clic droit sur le fond, « Replacer les pièces automatiquement » : elle reprend une place calculée.
  8. **Ordre des étages.** Clic droit sur le nom d'un étage, « Monter d'un étage » ou « Descendre d'un étage » ; relancer : l'ordre est gardé.
  9. **Fiche.** Clic sur un appareil : la fiche s'ouvre en bas, la vue lui laisse la place, ses courbes aussi ; « Renommer… » ; l'anneau de sélection et ses liens éclairés.
  10. **Fenêtre toujours sombre** (précision 15). Djoko passe son Mac en clair (Réglages Système › Apparence) : la fenêtre de la vue reste sombre ; la barre d'outils (2D/3D, « Rotation lente », menus du réseau), la fiche, le menu « Placer dans une pièce… », les clics droits et la feuille « Renommer… » restent lisibles ; le journal et les réglages, eux, passent en clair. Djoko remet l'apparence comme il l'avait.
  11. **Relevé du passeur sans dossier** : « Rafraîchir depuis Maison » ; les pièces et les étages suivent.
  12. **« Réduire les animations »** (Réglages Système › Accessibilité › Affichage) : l'envol devient un fondu, le retour par double-clic aussi, les autres vols sont immédiats, la rotation lente est coupée et son interrupteur grisé. Djoko remet le réglage comme il l'avait.
  13. **Retour.** Des comptes seulement, jamais un nom : étages, pièces, nœuds, nœuds dans « Sans pièce », routeurs de bordure (placés par leur nom, par un choix, restés sans pièce), noms masqués à la vue d'ensemble.

- [ ] **Step 2 : spec, section 10.** À la fin de la section 10, ajouter le paragraphe suivant, en remplaçant `<…>` par les valeurs du Step 1. Ce sont des comptes, jamais un nom de pièce, de zone ou d'accessoire.

```markdown
**Vérifié le <date> avec Djoko** (plan 4b) : sa maison en <e> étages et
<p> pièces, <n> nœuds, dont <s> dans « Sans pièce » ; <b> routeurs de
bordure, dont <bn> placés par leur nom, <bc> par un choix gardé après un
redémarrage, <bs> sans pièce ; 2D et 3D, envol et rotation lente ; pièce
isolée et repères « ailleurs » ; double-clic sur le fond ; une pièce glissée
retrouvée après un redémarrage ; ordre des étages gardé ; fenêtre sombre avec
le Mac en clair ; « Réduire les animations » vérifié ; <m> noms masqués à la
vue d'ensemble.
```

- [ ] **Step 3 : commit.**

```bash
git add docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md
git commit -m "Noter la verification de la vue par pieces avec Djoko

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Couverture de la spec

| Spec | Tâches |
|---|---|
| 1. La vue remplace le graphe ; barre avec 2D / 3D, puis « Rotation lente » en 3D ; bandeau de scission, ligne de la tournée, fiche, « Renommer… », anneau de sélection, pastille de batterie ; légende actuelle gardée ; mode 2D ou 3D gardé | 12, 13 ; 10 (pastille, dessin de la sélection) |
| 1. Fenêtre toujours sombre (ajout du 01/10, précision 15) | 12 ; 14 (spec) |
| 1. Démo avec les pièces et les étages de la maquette | 9 |
| 2.1 Étages : zones de Maison, première zone, « Autres pièces », « Maison », ordre gardé, « Monter / Descendre d'un étage » | 2 ; 5 (ordre gardé) ; 11, 12 (clic droit) |
| 2.2 Pièces : champ `piece`, au moins un nœud, 8 teintes par FNV-1a, la suivante libre dans l'étage | 2 ; 10 (pièce de chaque nœud, précision 1) |
| 2.3 Nœuds et liens du graphe, états et couleurs ; nœud sans pièce ; liens radio 2 pt, rattachements fins, supposés en pointillés ; sans pièces de Maison : cartes par routeur parent, « Sans pièce », bandeau et bouton ; un enfant vu deux fois, un seul nœud (précision 26) | 1, 2, 8, 10, 11 ; 12 (bandeau) |
| 2.3 Pièce d'un routeur de bordure (ajout du 01/10) : d'après son nom, au choix (« Placer dans une pièce… »), le choix avant le nom (précisions 23 à 25) | 5 ; 10 ; 12 (menu) ; 14 (spec) |
| 2.4 Places gardées : `positions-pieces.json`, pièces fixées, pièce renommée ou changée d'étage, « Replacer les pièces automatiquement » ; `pieces-routeurs.json` (ajout du 01/10) | 5 ; 4 (pièces fixées) ; 11, 12 |
| 3. Passeur sans dossier et zones | plan 4a (passé) |
| 4.1 Unités | 3 |
| 4.2 Cartes : ordre des lignes, rayons, hauteur, colonnes, place des pastilles, largeurs mesurées par l'app, noms coupés à 40 caractères | 2 (ordre, rayons), 3 ; 10 (mesure) |
| 4.3 Disposition : séparation, tassement, départ, rayon des plateaux, coût, optimisation, pièces fixées, budget, déterminisme ; calcul hors du fil principal, ancienne disposition affichée | 4 ; 11 |
| 4.4 Étages en 2D et en 3D, hauteur des blocs, sphère, boîte de cadrage 2D | 4 (centres en 2D), 6 |
| 5. Rendu : horloge sans image au repos, huit couches, fond, plateaux, blocs, pastilles (fonction partagée), liens, sphère (ellipse exacte), noms résolus en cache et alignés au pixel | 8 ; 10 ; 11 |
| 6. Styles, placement glouton, places candidates, priorités, stabilité, traits de rappel, noms masqués ; zoom sémantique | 7 ; 10 (styles) ; 11, 12 (ligne de niveau) |
| 7. Caméra, vue d'ensemble 2D et 3D, envol, rotation lente, gestes, pièce isolée, repères « ailleurs », clics droits, redimensionnement, « Réduire les animations », relevé appliqué à la fin d'un mouvement ; double-clic sur le fond (ajout du 01/10, précision 17) | 6 ; 8 ; 11 ; 12 |
| 8. Cas limites : pas encore de pièces, grande maison, sans sonde, plusieurs partitions, fenêtre petite | 2, 12 ; 4 et 7 (temps) ; 1 ; 10 (couleurs de partition) ; 7, 11 |
| 9. Architecture : `MaillageCoeur/Scene/`, `MaillageThread/Vues/Pieces/` ; ce qui disparaît | 1 à 12 ; 13 |
| 10. Tests du cœur : `ScenePieces`, `CartesPieces`, `DispositionPieces` (dont la démo sans traversée), `CameraScene`, `PlacementNoms`, `PlacesGardees` ; pièce des routeurs (ajout du 01/10) | 2, 3, 4 et 10, 6, 7, 5 ; 5 |
| 10. Temps de calcul, en Release | 4, 7 (`outils/mesurer.sh`) |
| 10. Tests de l'app : `NomsInternes` face à un faux passeur | plan 4a |
| 10. Rendu de démo en PNG, par un argument de lancement ; catalogue en français et en anglais | 12 ; 10 à 13 |
| 10. Avec Djoko, à la fin | 15 |
| 11. Deux plans ; le 4b utilisable sans les zones | tout le plan (maison sans zones : tâche 2) ; le 4a est passé |
