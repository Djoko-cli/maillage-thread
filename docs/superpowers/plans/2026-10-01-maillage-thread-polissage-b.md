# Maillage Thread, polissage B : la fenêtre et la légende : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Note du 02/10 :** ce plan est le journal de l'exécution du 01/10, gardé tel quel. Un de ses choix a été remplacé à la vérification en vrai : la barre de titre ne passe plus par le crochet AppKit de la fenêtre (`FenetrePieces.sansBarreDeTitre`, posé par `SondeFenetre`), que SwiftUI défaisait, mais par le style de la scène, `.windowStyle(.hiddenTitleBar)` ; le crochet ne gardait que la fenêtre sombre (`assombrir`), retiré à la ronde finale du 02/10 au profit de `.preferredColorScheme(.dark)`. Les passages ci-dessous qui décrivent ce crochet (architecture, précision 1, tâche 1) sont donc dépassés : voir la spec, section 6. De même, les 820 × 680 pt du plan sont la taille du contenu sous la barre de titre cachée : la fenêtre ne descend pas sous 820 × 732 pt, la barre de titre faisant 52 pt avec la barre d'outils invisible (spec, section 3). Les capsules ne sont plus à 1,5 pt du bord, mais à 11 pt (spec, section 1).

**Goal :** livrer le sous-projet B du polissage, tel que Djoko l'a validé le 01/10 sur ses trois maquettes : une fenêtre de la vue par pièces sans barre de titre, avec deux capsules de verre sur la ligne de ses trois boutons et la bande vide du haut qui la déplace ; la légende A, contextuelle et repliable, à la place de la petite légende des liens, la vue d'ensemble cadrée au-dessus d'elle quand elle est ouverte ; une fiche qui glisse depuis le bas, avec la pastille du chef ; des bandeaux du haut qui glissent ; une marge du haut mesurée ; une fenêtre d'au moins 820 × 680 pt.

**Architecture :**
- **Le haut de la fenêtre** (`MaillageThread/Vues/Pieces/BandeauPieces.swift`, nouveau) :
  - `FenetrePieces.sansBarreDeTitre` passe par le crochet AppKit de la fenêtre (`SondeFenetre`, à côté d'`assombrir`) ;
  - `CadreFeux` lit le cadre des trois boutons (`standardWindowButton`) ;
  - `HautPieces` pose la ligne des capsules (`BarreOutils` à gauche, `CommandesVue` à droite, la bande `BandeFenetre` entre elles), puis, sous la capsule de gauche, la tournée, les bandeaux et le fil ; sa hauteur mesurée donne la marge du haut (`FenetrePieces.margeHaut(bas:)`) ;
  - les styles de la maquette (`StyleBoutonCapsule`, `SelecteurVue`, `StyleBasculeCapsule`, `capsuleDeVerre`, `piluleDuHaut`) ; le rendu des captures (`capturePieces`, `FeuxDeCapture`).
- **La légende** (`LegendePieces.swift`, nouveau) : `LegendePieces.rubriques(_:)`, une fonction pure, lit la scène affichée (`Lecture`) ; la vue `LegendePieces` et sa grille (`GrilleLegende`) ; `PastilleAncien`. `LigneDuBas` (dans `FenetrePieces.swift`) pose la légende, la ligne de niveau et la pastille, garde le repli, et donne la hauteur de la légende ouverte : la marge du bas (`FenetrePieces.margeBas(fiche:courbes:legendeOuverte:)`).
- **Les apparitions** (`Apparition.swift`, nouveau) : la fiche et les bandeaux glissent (`Glisse`), ou se fondent ; le moteur fait glisser les marges de la vue avec eux, ou les change par un fondu (`MoteurPieces.margesDuCadre`).
- **La fiche** (`FicheNoeud.swift`) : `PastilleChef`, pour les chefs de la scène (`FicheNoeud.couronne`).
- **Les images de démo** (`CapturesPieces.swift`) : quatorze, dont la fiche du chef et la légende repliée.
- Le cœur (`MaillageCoeur/`) ne change pas.

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI (Liquid Glass, `Layout`, `Transition`, `onGeometryChange`, `AppStorage`), AppKit (`NSWindow`, `NSView`), Swift Testing, XcodeGen, `xcodebuild`, `xcstringstool`.

**Spec :** `docs/superpowers/specs/2026-10-01-maillage-thread-polissage-b-design.md` (validée par Djoko le 01/10, section par section), et ses trois maquettes, choisies par Djoko, qui se livrent telles quelles : `docs/superpowers/specs/maquettes/polissage-b-bandeau.html` (carte C), `polissage-b-legende.html` (colonne de droite) et `polissage-b-fiche-animee.html` (carte A). Pour la vue par pièces : `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`.

**Décisions de Djoko du 01/10, sur les premières images de ce plan :**
- **les capsules restent centrées sur les trois boutons**, collées en haut de la fenêtre (à 1,5 pt du bord) : le rendu de la tâche 1 est gardé tel quel (précision 2) ;
- **la marge du bas suit la légende ouverte**, comme celle du haut suit le bandeau : la vue d'ensemble se cadre au-dessus d'elle, d'après la hauteur mesurée de la légende et de la ligne de niveau (`FenetrePieces.margeBas`, une fonction testable) ; repliée, la marge reprend sa valeur d'avant (30 pt) ; une fiche ouverte, qui cache la légende, garde ses 190 ou 360 pt. Un changement de marge recadre la vue d'ensemble comme avant, sauf si Djoko a zoomé ou isolé une pièce ; le repli et l'ouverture la recadrent avec l'animation de la fiche, ou par un fondu avec « Réduire les animations » (précisions 7 et 17). Dans l'image `01-2d`, aucune pièce n'est plus sous la légende.

La spec de B le dit (sections 1, 2 et 5), par la tâche 4.

**Quand l'exécuter.** Après le sous-projet A : ce plan est écrit et validé sur le `main` du 01/10 (`82e86ee`). **Les numéros de ligne cités sont indicatifs : l'exécutant se repère aux noms (types, fonctions, commentaires) et aux textes cités.** Si un texte à remplacer n'est plus exactement le même, il applique le même changement au texte du moment et le dit dans son rapport.

## Code validé, faits établis et précisions

**Code validé avant exécution.** Le 01/10, tout le code de ce plan a été écrit, compilé et testé dans une copie de `main` (`82e86ee`) :
- toute la suite passe, en français et en anglais : 346 tests en 36 suites pour le cœur et 287 en 29 pour l'app (avant ce plan : 346 en 36 et 269 en 28), sans avertissement ;
- les temps de la vue par pièces, en Release, ne bougent pas : la disposition de la grande maison inventée en 0,25 s (3 000 coups), 150 noms en 0,31 ms, 150 noms très serrés en 2,83 ms ; les tests Python de la sonde passent : ce plan n'y touche pas ;
- les images de démo ont été rendues et regardées, à côté des maquettes : elles changent toutes à la tâche 1 (le bandeau), puis à la tâche 2 (la légende, et la vue d'ensemble cadrée au-dessus d'elle) ; la tâche 3 n'en change aucune, octet pour octet ; la tâche 4 en ajoute deux.

Le plan a ensuite été rejoué tâche par tâche sur une copie neuve de `main` (`82e86ee`), ses blocs appliqués par l'outil du contrôleur (`appliquer-blocs.py`, sur le brief de chaque tâche, découpé par `task-brief`), ses scripts de traduction lancés par le même outil (`--traductions`) : le rouge, le vert, le catalogue, la suite entière, les images, un commit par tâche. Les résultats attendus ci-dessous viennent de ce rejeu. L'arbre final est identique à la copie validée. D'autres changements de `main` changeraient ces totaux : chaque tâche donne donc ses effectifs par suite, et l'écart des totaux.

Exécuter une tâche, c'est transcrire les fichiers et les blocs donnés, compiler et tester. Si un fichier doit s'écarter du texte donné, l'exécutant le dit dans son rapport, avec la raison.

**Blocs de modification.** Un fichier existant est modifié soit en entier (« fichier entier »), soit par blocs « remplacer … par … ». Chaque texte à remplacer apparaît une seule fois dans le fichier au moment où on l'applique. Les blocs s'appliquent dans l'ordre, du haut vers le bas, au texte exact, espaces compris. Un fichier créé l'est tel quel. Le catalogue (`Localizable.xcstrings`) et `outils/traductions/interface.json` ne changent que par les outils (tâches 2 et 3). Ce plan ne déplace ni ne supprime aucun fichier.

**Faits établis** (Xcode 27, macOS 27, copie validée et rejeu, 01/10) :
- **La barre de titre.** Sans barre d'outils, elle fait 32 pt ; les trois boutons font 14 pt, en x = 9, 32 et 55 (le bord droit du bouton agrandir à 69 pt), de 9 à 23 pt du haut (milieu à 16 pt). Avec `fullSizeContentView`, la marge de sécurité du haut du contenu vaut 32 pt : le contenu l'ignore (`ignoresSafeArea`) pour monter jusqu'en haut.
- **Les clics dans la bande du titre** vont au contenu SwiftUI (l'`NSHostingView`), sauf les 2 premiers points du haut (le cadre de la fenêtre, pour la redimensionner) et les trois boutons. Sans vue à elle, la bande ne déplacerait donc pas la fenêtre, et la scène y recevrait ses gestes. Une vue d'AppKit posée dans le contenu reçoit, elle, les clics de son cadre (test `bandeEntreLesCapsules`).
- **`ImageRenderer`**, qui rend les images de démo, ne rend ni la fenêtre (barre, boutons), ni le verre (`glassEffect` : rien, contenu compris), ni un bouton `.glass` (vide), ni un `Picker` segmenté ou un `Menu` sans bordure (un carré jaune). Un `Menu` en `.menuStyle(.button)` avec un `ButtonStyle` à soi, un `Button` ou un `Toggle` à style à soi sont dessinés par SwiftUI, donc rendus. Un tel `Menu` n'a pas d'indicateur : « ▾ » est dans son texte, comme dans la maquette.
- **`ProgressView` circulaire :** en `.mini`, 10 pt sans valeur et 16 pt avec ; en `.small`, 16 pt dans les deux cas. La ligne de la tournée garde donc `.small`, pour sa largeur fixe d'une étape à l'autre (`capsuleDeLargeurFixe`).
- **Le double-clic sur une barre de titre** suit `AppleActionOnDoubleClick` (réglages Bureau et Dock) : `Fill`, `Maximize`, `Minimize` ou `None`. AppKit n'a pas d'API publique pour remplir l'écran ; `WindowDragGesture` déplace la fenêtre, sans le double-clic.
- **Sous les tests,** l'accessibilité d'une `NSHostingView` est vide, même dans une fenêtre hors écran : la pastille du chef se vérifie par la taille de la fiche.
- **Dans une capture,** les cadres posés par `onGeometryChange` (`obstacle`) arrivent avant la seconde passe : les noms évitent le bandeau et la légende.
- **La légende de la maquette**, rendue par Coup d'œil (`qlmanage`), déborde de son panneau de 440 px quand toutes ses entrées y sont : ses colonnes `1fr` prennent au moins la largeur de leurs entrées, qui ne passent pas à la ligne.

**Précisions.** Ce sont les choix faits à l'écriture du plan, là où la spec, le brief et les maquettes laissaient la main. Djoko peut les revoir à la tâche 5.
1. **Sans barre de titre** (spec 1) : par le crochet AppKit de la fenêtre (`SondeFenetre`), comme `assombrir` : `fullSizeContentView`, barre transparente, titre masqué. « Maillage Thread » reste le titre de la fenêtre. Pas de barre d'outils.
2. **La capsule de gauche** commence à 13 pt du bouton agrandir (la maquette : 72 − 59), et se centre sur le milieu des boutons ; leur cadre est lu sur la fenêtre (`CadreFeux(fenetre:)`, `standardWindowButton`). `CadreFeux.defaut` (69 pt, milieu à 16 pt), mesuré sous macOS 27, sert avant que la fenêtre soit connue, et aux captures. La capsule de droite est à 12 pt du bord (la maquette). Centrée sur des boutons à 16 pt du haut, une capsule d'environ 29 pt arrive à 1,5 pt du bord du haut : Djoko garde ce rendu (décision du 01/10).
3. **Les commandes des capsules** sont celles d'aujourd'hui, mêmes actions, dessinées comme la maquette : `StyleBoutonCapsule` (`.b`), `SelecteurVue` (`.seg` : deux boutons, lu par VoiceOver comme le choix « Vue »), `StyleBasculeCapsule`. Le menu du réseau reste un `Menu`, dessiné comme un bouton, avec « ▾ ». « Rotation lente » allumée prend le dessin du segment choisi ; éteinte, celui d'un bouton ; coupée par « Réduire les animations », à 45 %.
4. **La bande** est une vue d'AppKit (`BandeFenetre.Vue`), entre les capsules, sur la hauteur de la barre de titre (32 pt) : un clic glissé déplace la fenêtre (`performDrag`) ; un double-clic suit le réglage du Mac (`Minimize` réduit, `None` ne fait rien ; `Maximize`, `Fill` et un réglage absent agrandissent, par `performZoom`) ; le premier clic agit dans une fenêtre inactive, comme sur une barre de titre. Elle prend les clics avant la scène : ni ses gestes ni son double-clic de recadrage ne s'y appliquent. Toute la ligne est un obstacle pour les noms (« ligne »).
5. **Sous la capsule de gauche,** alignés sur elle et en plus petit (la `.pilule` de la maquette : 10 pt, 3 × 10 pt, verre) : la ligne de la tournée, le bandeau de scission (verre teinté d'orange), celui d'une maison sans pièces (son bouton en 10 pt), puis le fil. La place de la tournée reste gardée tant qu'une sonde est retenue (`LigneTournee.place`), comme au plan 4b (précision 21) : rien ne bouge au début ni à la fin d'une tournée ; hors tournée, cette place est vide sous la capsule.
6. **La marge du haut** est mesurée : `FenetrePieces.margeHaut(bas:)` est le bas du haut de la fenêtre (`HautPieces`, par `onGeometryChange`), arrondi au point, plus l'espacement (10 pt). Elle compte le fil, comme les 72 pt d'avant. Les captures la mesurent de même (`NSHostingView.fittingSize`).
7. **La vue se relève avec la fiche, au-dessus de la légende ouverte, et descend sous un bandeau :** les marges du cadre rejoignent en 0,3 s, sur la courbe de la fiche, celles que la vue pose (`MoteurPieces.margesDuCadre`) ; avec « Réduire les animations », par un fondu de 0,3 s (la scène s'efface, les marges sautent à mi-chemin, elle revient : `opaciteMarges`) ; tout de suite avant la première disposition et pour une capture. La vue d'ensemble se recadre à chaque image du glissement, sauf si Djoko a zoomé ou isolé une pièce, comme avant.
8. **Les apparitions** (`Apparition`) : la fiche glisse de 110 % de sa hauteur depuis le bas, un bandeau depuis le haut, avec un fondu, en 0,3 s, sur `cubic-bezier(.2, .8, .2, 1)` (maquette de la fiche) ; avec « Réduire les animations », un fondu simple de 0,3 s. La fiche ne glisse qu'à l'ouverture et à la fermeture (`selection == nil`) : d'un nœud à l'autre, son contenu change sur place. Le décalage ne touche que le dessin : l'obstacle de la fiche est sa place d'arrivée.
9. **Les entrées de la légende** viennent de la scène affichée (`LegendePieces.Lecture`) : la couleur de chaque nœud, ceux que la sonde seule connaît, les chefs, les endormis, les piles, les routeurs montrés avec leurs candidats, les liens, et les repères « ailleurs » posés (pièce isolée). « non identifié » vaut pour un nœud que la sonde seule connaît, routeur ou enfant, tous deux gris ; un appareil d'état inconnu, gris lui aussi, n'a pas d'entrée, comme dans la spec. « candidats » vaut pour un routeur montré avec un ou plusieurs candidats. Elle suit la scène, et non le zoom sémantique : de loin, un ☾ ou une pile masqués avec les noms gardent leur entrée (sinon la légende changerait à chaque cran de molette). Elle reste cachée sous une fiche ouverte, comme avant.
10. **La grille** a deux colonnes de même largeur (`1fr 1fr`), au moins la moitié d'un panneau de 440 pt, et la largeur du groupe le plus large (l'entrée du chef, environ 250 pt) : complète, la légende fait environ 550 pt. La ligne de niveau s'aligne sur la dernière ligne de la légende.
11. **Le repli** est gardé par `@AppStorage("legendeRepliee")`, dans la ligne du bas (`LigneDuBas`), qui le passe à la légende (`LegendePieces(rubriques:repliee:)`) : « Légende ⌄ » repliée, « Légende ⌃ » ouverte ; un clic sur l'en-tête bascule. Les captures imposent l'état (`legendeForcee`), sans dépendre de la préférence ni l'écrire : l'instance de démo partage le conteneur, donc les préférences, de l'app de Djoko.
12. **Les signes de la légende** prennent les couleurs de `Palette`. Les exemples sont ceux de la scène : « 12 % » (le format de la pastille d'une pile) et « A ou B · 0400 » (le libellé d'un routeur et de ses candidats) ; « → Salon » est le texte de la maquette, traduit (« → Living room »). Couleurs nouvelles : `Palette.fondLegende` (le fond de la vue à 0,92), `texteLegende`, `titreLegende` (rgb(148, 163, 190)), `jauneChef` (le jaune des liens moyens), `texteChef` (rgb(253, 224, 120)).
13. **« Relevé de la sonde ancien »** est une pastille à côté de la ligne de niveau, fiche ouverte ou non, quand le relevé a plus de 6 minutes : le dessin de la pastille du chef (10,5 pt, capsule teintée à 0,16, filet à 0,5), en orange. La spec n'en donne pas de maquette.
14. **La pastille du chef** se pose sous le nom et la description de tout nœud de `EntreeScene.chefs` : routeur de bordure, routeur que la sonde seule connaît, et appareil qui serait couronné (`FicheNoeud.couronne`).
15. **La taille minimale** est `FenetrePieces.tailleMinimale`, 820 × 680 pt. Le contenu couvrant toute la fenêtre, c'est aussi celle de la fenêtre (avant : 820 × 560 de contenu, sous 32 pt de barre).
16. **Les captures** (`capturePieces`, une valeur d'environnement) dessinent le verre comme les maquettes (`.verre`, `.pilule`, `.fiche`, sans flou), les boutons de la fiche comme ceux des capsules, et les trois boutons de la fenêtre (`FeuxDeCapture`, aux couleurs de la maquette, à la place de `CadreFeux.defaut`). Elles passent de 12 à 14 images : `13-2d-fiche-du-chef`, `14-2d-legende-repliee`.
17. **La marge du bas suit la légende ouverte** (décision de Djoko du 01/10) : `FenetrePieces.margeBas(fiche:courbes:legendeOuverte:)` vaut le bord, la hauteur mesurée de la ligne du bas (la légende et la ligne de niveau, rendue par `LigneDuBas.surHauteurOuverte`, par `onGeometryChange`), arrondie, et l'espacement, au moins 30 pt ; repliée, 30 pt, la marge d'avant ; une fiche ouverte, 190 ou 360 pt : elle cache la légende, dont la dernière mesure reste pour sa fermeture. Les images la mesurent de même : la légende ouverte (images 01 à 12), repliée (14), sous la fiche (13).
18. **La doc :** la phrase « sans partition en gris » de la spec de la vue par pièces (section 8) est corrigée (spec de B, section 2) ; le README, en anglais et en français, décrit la fenêtre, la légende, la fiche et les quatorze images.

**Écarts aux maquettes**, imposés par la plateforme ou par le contenu, montrés à Djoko à la tâche 5 :
- **Le verre** est le Liquid Glass de macOS (`glassEffect`), non l'imitation CSS des maquettes (fond `rgba(40, 48, 72, …)`, flou de 14 px) ; les captures, qui ne rendent pas le verre, reprennent l'imitation, sans flou.
- **La hauteur de la ligne des capsules :** centrée sur les boutons de la fenêtre (milieu à 16 pt), la capsule commence à 1,5 pt du bord du haut ; dans la maquette, à 8 px, sous des boutons plus petits (11 px, de 11 à 22 px). Laisser de l'air au-dessus demanderait une barre d'outils vide, qui descend les boutons (`unified` : milieu à 26 pt, capsule à 11,5 pt du haut) : écarté, la spec voulant la fenêtre sans barre. Djoko garde ce rendu (décision du 01/10).
- **Les boutons de la fenêtre** font 14 pt, en x = 9 à 69, contre 11 px, de 12 à 59, dans la maquette : la capsule de gauche commence donc à 82 pt.
- **« Rotation lente »** allumée prend le dessin du segment choisi : la maquette ne dit pas son état.
- **⟳** est le symbole `arrow.clockwise` de SF Symbols.
- **La ligne de la tournée** montre la tournée en cours (indicateur et étape), comme aujourd'hui ; « Tournée de la sonde : il y a 2 min » est un texte de croquis (la maquette : « seule la place du bandeau compte »).
- **La légende complète** fait environ 550 pt de large, contre 440 px dans la maquette, qui déborde alors de son panneau (faits établis).
- **La fiche** garde son contenu et son dessin d'aujourd'hui ; la carte A de la maquette en est un croquis, pour l'animation et la ligne du chef.

## Global Constraints

- **Plateformes :** app en macOS 26.0 minimum, développée avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`.
- **Code :** identifiants et commentaires en français **sans accents** ; textes affichés avec accents ; tests en Swift Testing. Les nouveaux fichiers (`BandeauPieces.swift`, `LegendePieces.swift`, `Apparition.swift`, `LegendePiecesTests.swift`) sont pris par les sources de `project.yml` sans le modifier : ce plan ne touche pas `project.yml`.
- **Le cœur ne change pas :** `MaillageCoeur/` et ses tests restent tels quels ; tout est dans l'app (`MaillageThread/`).
- **Les maquettes se livrent telles quelles :** mesures et couleurs de leur CSS, couleurs exactes de `Palette` ; un écart imposé par la plateforme est dit (écarts ci-dessus), jamais réinterprété.
- **Déterminisme :** aucun hasard ; les images de démo ne dépendent ni de l'heure ni des préférences (états imposés).
- **Textes de l'app :** tout texte nouveau est au catalogue (`MaillageThread/Ressources/Localizable.xcstrings`), avec son anglais, par les outils : compiler, `outils/synchroniser-textes.sh`, le script de la tâche (`python3 - <<'EOF' … EOF`, qui écrit `outils/traductions/interface.json`), puis `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`. `CataloguesTests` refuse une clé sans anglais, absente ou inutilisée.
- **Tests indépendants de la langue :** une attente sur un texte affiché reprend la même clé que le code (`String(localized: "Sans pièce")`), jamais une chaîne française figée. Les tests passent en anglais :

  ```bash
  xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-polB/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-polB/maillage-tests-en.log"
  ```
- **Commandes,** depuis la racine du dépôt, toujours avec un dossier de produits (`DD`) et un dossier temporaire (`TMPDIR`) propres à ce plan : une autre compilation (l'app de Djoko, une autre session) ne partage ni ses produits ni son journal. Le shell d'un agent ne garde pas ses variables d'une commande à l'autre : chaque commande les porte. Une fois, avant la tâche 1 :

  ```bash
  mkdir -p "$HOME/Library/Caches/maillage-polB"
  ```

  Puis, par exemple :

  ```bash
  DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh MaillageThreadTests/LegendePiecesTests
  ```

  `outils/tester.sh [cibles…]` génère le projet, compile et lance les tests, en Debug ; les produits vont dans `DD`, le journal complet dans `$TMPDIR/maillage-tests.log` ; une cible qui ne lance aucun test fait échouer le script (un test de Swift Testing se nomme avec ses parenthèses). `outils/mesurer.sh` lance les trois tests de temps en Release, dans le même `DD`, journal dans `$TMPDIR/maillage-mesures.log`. La première compilation dans ce `DD` neuf prend quelques minutes. **Jamais** les `DD` `maillage`, `maillage-plan4b…` ni `maillage-polA` : l'app de Djoko tourne depuis `maillage-polA`.
- **Une suite de tests de l'app à la fois** sur ce Mac : si un test sans rapport échoue avec `Test crashed with signal term`, vérifier qu'aucune autre session ne teste l'app (`pgrep -fl xcodebuild`), puis relancer la suite.
- **L'app :** de la tâche 1 à la tâche 4, un agent ne la lance qu'en mode démo, pour ses images, en instance à part : `open -n -g -W "$DD/Build/Products/Debug/Maillage Thread.app" --args -demo -captures <dossier du conteneur>`. Elle écrit ses images sans fenêtre et quitte d'elle-même (`-W` attend qu'elle ait quitté) ; l'agent vérifie qu'elle ne tourne plus. Jamais en mode direct, jamais de `screencapture`, et l'app de Djoko n'est jamais quittée. La tâche 5 se fait avec Djoko, par le contrôleur.
- **Les préférences de l'app** sont celles de l'app de Djoko (même conteneur) : un test n'écrit jamais dans `UserDefaults.standard` (il prend un domaine à lui, `SondeMaillageTests.preferences()`), et les images de démo imposent l'état de la légende.
- **Données personnelles** (le dépôt est public sur GitHub, `Djoko-cli/maillage-thread`) :
  - `noms.json` n'est jamais commité, ni lu par un test ; aucun agent ne lit le conteneur de l'app hors des dossiers d'images de ce plan ;
  - les tests utilisent des données inventées ou celles de la démo : ExtMac en `E0…`, noms de la démo.
- **Signature :** l'app reste ad hoc (`Signature.xcconfig`). **Ne jamais créer `Local.xcconfig`.** Aucun identifiant d'équipe, empreinte de certificat ni adresse électronique dans un fichier commité.
- **Commits :**
  - un par tâche, message en français sans accents, terminé par une ligne vide puis la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - `git add` avec la liste de fichiers de la tâche, **jamais `git add -A` ni `git add .`** ;
  - jamais de push.
- **Interdits pour les agents :** `sudo` ; ouvrir un port série ou flasher ; lancer l'app en mode direct ; `screencapture` ; lancer le passeur ou `outils/passeur.sh` ; réveiller l'écran ; quitter l'app de Djoko.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `MaillageThread/Vues/Pieces/BandeauPieces.swift` (nouveau) | `CadreFeux`, `ActionDoubleClic`, `BandeFenetre`, `HautPieces` ; styles des capsules ; `capsuleDeVerre`, `piluleDuHaut` ; `capturePieces`, `FeuxDeCapture` | 1, 3, 4 |
| `MaillageThread/Vues/Pieces/FenetrePieces.swift` | `sansBarreDeTitre`, `margeHaut(bas:)`, la mise en page du haut et du bas ; `CommandesVue`, `BandeauSansPieces`, `FilPieces` restylés ; `LigneDuBas` ; la fiche qui glisse ; `tailleMinimale` | 1, 2, 3 |
| `MaillageThread/Vues/Pieces/MorceauxFenetre.swift` | `BarreOutils` restylée ; `LigneTournee` (sa place gardée), `IndicateurTournee`, `BandeauScission` en plus petit ; `LegendeLiens` retirée | 1, 2 |
| `MaillageThread/Vues/Pieces/CapturesPieces.swift`, `MaillageThread/MaillageThreadApp.swift` | les images de démo : le haut de la fenêtre, la légende, la fiche ; quatorze images | 1, 2, 4 |
| `MaillageThread/Vues/Pieces/LegendePieces.swift` (nouveau) | la légende : entrées (`Lecture`, `entrees`, `rubriques`), vue, grille (`GrilleLegende`), `PastilleAncien` | 2 |
| `MaillageThread/Vues/Pieces/Palette.swift` | couleurs de la légende et de la pastille du chef | 2, 3 |
| `MaillageThread/Vues/Pieces/Apparition.swift` (nouveau) | glisser avec un fondu, ou un fondu ; la courbe de la maquette | 3 |
| `MaillageThread/Vues/Pieces/MoteurPieces.swift` | les marges du cadre glissent (`margesDuCadre`) | 3 |
| `MaillageThread/Vues/Pieces/FicheNoeud.swift` | `PastilleChef`, `couronne` ; boutons et fond dans les captures | 3, 4 |
| `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json` | 17 textes nouveaux, 3 retirés (par les outils) | 2, 3 |
| `MaillageThreadTests/FenetrePiecesTests.swift`, `FenetreTests.swift`, `MoteurPiecesTests.swift` | fenêtre sans barre, bande, marges, place de la tournée, taille minimale, apparitions, pastille du chef, marges qui glissent, images | 1 à 4 |
| `MaillageThreadTests/LegendePiecesTests.swift` (nouveau) | une entrée par signe, groupes, démo, exemples, colonnes, repli gardé, pastille d'un relevé ancien | 2 |
| `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` | section 8 : un appareil sans partition prend la couleur de son état | 4 |
| `README.md`, `README.fr.md` | la fenêtre, la légende, la fiche, les quatorze images | 4 |

---

### Task 1: La fenêtre et le bandeau : sans barre de titre, deux capsules de verre, la bande qui déplace la fenêtre, la marge du haut mesurée

**Files:**
- Create: `MaillageThread/Vues/Pieces/BandeauPieces.swift`
- Modify: `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/Pieces/CapturesPieces.swift`, `MaillageThread/MaillageThreadApp.swift` (blocs ci-dessous)
- Test: `MaillageThreadTests/FenetrePiecesTests.swift`, `MaillageThreadTests/FenetreTests.swift`, `MaillageThreadTests/MoteurPiecesTests.swift`

**Interfaces:**
- Consumes :
  - `SondeFenetre` (le crochet AppKit de la fenêtre), `FenetrePieces.assombrir`, `.obstacle(_:_:)`, `VuePieces.espace`, `BarreOutils`, `CommandesVue`, `LigneTournee`, `BandeauScission`, `BandeauSansPieces`, `FilPieces`, existants ;
  - AppKit : `NSWindow.standardWindowButton`, `performDrag(with:)`, `performZoom`, `performMiniaturize` ; la préférence `AppleActionOnDoubleClick` ;
  - dans les tests : `SondeMaillageTests.preferences()`, `canalRetenu`, `port`, `listeRetenue`, `attendre`, existants.
- Produces :
  - `FenetrePieces.sansBarreDeTitre(_:)` ; `FenetrePieces.margeHaut(bas:) -> CGFloat` (le bas mesuré, arrondi, plus `espacement`), à la place de `margeHaut(scinde:sondeRetenue:sansPieces:)` ; `FenetrePieces.margeHautInitiale` ;
  - `CadreFeux` (`droite`, `milieu`, `init?(fenetre:)`, `defaut`) ; `ActionDoubleClic` (`.agrandir`, `.reduire`, `.rien` ; `init(reglage:)`, `cle`, `duMac`, `appliquer(_:)`) ; `BandeFenetre` et sa vue `BandeFenetre.Vue` (`glisser`, `doubleCliquer`) ;
  - `HautPieces(moteur:troisD:sansPieces:feux:)` (`ecartFeux` = 13, `bordDroit` = 12), qui remplace `EnTetePieces` ;
  - `StyleBoutonCapsule(taille:allume:)`, `StyleBasculeCapsule`, `SelecteurVue(troisD:)` ; `View.capsuleDeVerre()`, `View.piluleDuHaut(teinte:)` ; `EnvironmentValues.capturePieces` ; `FeuxDeCapture` ;
  - `LigneTournee.place(serie:avancement:debut:) -> LigneTournee.Place` (`.indicateur`, `.gardee`, `.aucune`) ; `IndicateurTournee(avancement:debut:)`, `debut` optionnel ;
  - `CapturesPieces.ecrire(dans:surveillance:sonde:nomsMaison:)` ; `View.pourCapture(_:_:_:)`.

**Le bandeau, carte C** (spec, section 1 ; maquette du bandeau). La fenêtre perd sa barre de titre par le crochet AppKit qui la garde déjà sombre ; le titre « Maillage Thread » reste le sien. Le haut de la fenêtre devient `HautPieces` : deux capsules de verre sur la ligne des trois boutons (précisions 2 à 4), la bande entre elles, et sous la capsule de gauche la tournée, les bandeaux et le fil, en plus petit (précision 5). La bande est une vue d'AppKit : les clics de la bande du titre allant au contenu (faits établis), elle déplace elle-même la fenêtre, et fait le double-clic d'une barre de titre selon le réglage du Mac ; `WindowDragGesture` ne le ferait pas.

**La marge du haut mesurée** (précision 6) remplace les valeurs fixes du plan 4b (précision 21) : la hauteur de `HautPieces`, par `onGeometryChange`. La place de la tournée reste gardée tant qu'une sonde est retenue.

**Les images de démo** montrent le bandeau : `ImageRenderer` ne rend ni la fenêtre ni le verre (faits établis), donc les commandes sont dessinées par SwiftUI, et une capture (`capturePieces`) pose l'imitation du verre de la maquette et les trois boutons de la fenêtre (`FeuxDeCapture`). Elles changent toutes : le bandeau, la marge du haut.

- [ ] **Step 1 : écrire les tests.** Les tests de la fenêtre sans barre de titre, de la bande et de la marge mesurée ; la place de la tournée ; le test des noms prend une marge du haut réaliste.

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// Le haut de la fenetre (barre, bandeaux, tournee, fil) tient dans la marge du haut de la vue
    /// d'ensemble, dans tous les cas ; la fiche la plus haute de la demo, avec la ligne de niveau,
    /// dans la marge du bas ; avec les courbes de l'historique, dans la marge du bas avec courbes.
```

par :

```swift
    /// La marge du haut de la vue d'ensemble suit la hauteur mesuree du haut de la fenetre (la ligne des
    /// capsules, la tournee, les bandeaux, le fil) : son bas, arrondi, et l'espacement ; un bandeau ou la
    /// ligne de la tournee la font grandir. La fiche la plus haute de la demo, avec la ligne de niveau,
    /// tient dans la marge du bas ; avec les courbes de l'historique, dans la marge du bas avec courbes.
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
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
```

par :

```swift
            let vue = HautPieces(moteur: MoteurPieces(), troisD: .constant(true), sansPieces: sansPieces)
            return NSHostingView(rootView: vue.environment(s).environment(sonde).environment(noms)).fittingSize.height
        }
        #expect(FenetrePieces.margeHaut(bas: 57.2) == 58 + FenetrePieces.espacement, "le bas arrondi, et l'espacement")
        #expect(demo.reseau?.estScinde == true, "la demo : reseau scinde, bandeau affiche")
        let seul = haut(sansReseau, sansPieces: false)
        let scinde = haut(demo, sansPieces: false)
        #expect(seul > 2 * CadreFeux.defaut.milieu, "la ligne des capsules, puis le fil")
        #expect(scinde > seul, "le bandeau de scission")
        #expect(haut(demo, sansPieces: true) > scinde, "le bandeau d'une maison sans pieces")
        await sonde.connecter(SondeMaillageTests.port, choisi: true)
        await journal.attendre(SondeMaillageTests.listeRetenue)
        await SondeMaillageTests.attendre { sonde.avancement != nil }
        #expect(haut(demo, sansPieces: false) > scinde, "la ligne de la tournee")
        #expect(FenetrePieces.margeHaut(bas: haut(demo, sansPieces: false)) > FenetrePieces.margeHaut(bas: scinde))
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// La fenetre reste sombre, meme quand le Mac est en clair : sa barre, ses menus, sa fiche et ses
```

par :

```swift
    /// Sans barre de titre : le contenu couvre toute la fenetre, la barre de titre est transparente et le
    /// titre masque ; il reste celui de la fenetre. Les trois boutons restent : la capsule de gauche
    /// commence apres eux, centree sur eux ; sous macOS 27, a leur place de `CadreFeux.defaut`.
    @Test func fenetreSansBarreDeTitre() throws {
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
                               defer: false)
        fenetre.isReleasedWhenClosed = false
        fenetre.title = "Maillage Thread"
        FenetrePieces.sansBarreDeTitre(fenetre)
        #expect(fenetre.styleMask.contains(.fullSizeContentView))
        #expect(fenetre.titlebarAppearsTransparent)
        #expect(fenetre.titleVisibility == .hidden)
        #expect(fenetre.title == "Maillage Thread")
        let feux = try #require(CadreFeux(fenetre: fenetre))
        let agrandir = try #require(fenetre.standardWindowButton(.zoomButton))
        #expect(feux.droite == agrandir.convert(agrandir.bounds, to: nil).maxX)
        #expect(feux == CadreFeux.defaut)
        FenetrePieces.sansBarreDeTitre(nil)
    }

    /// La bande du haut : un clic, glisse, deplace la fenetre ; un double-clic fait ce que dit le reglage
    /// du Mac (agrandir, reduire ou rien ; « Remplir », sans API publique, agrandit). Elle agit aussi dans
    /// une fenetre inactive, et seule : AppKit ne deplace pas la fenetre a sa place.
    @Test func bandeDeLaFenetre() throws {
        #expect(ActionDoubleClic.cle == "AppleActionOnDoubleClick")
        #expect(ActionDoubleClic(reglage: "Maximize") == .agrandir)
        #expect(ActionDoubleClic(reglage: "Fill") == .agrandir)
        #expect(ActionDoubleClic(reglage: nil) == .agrandir)
        #expect(ActionDoubleClic(reglage: "Minimize") == .reduire)
        #expect(ActionDoubleClic(reglage: "None") == .rien)
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled],
                               backing: .buffered, defer: false)
        fenetre.isReleasedWhenClosed = false
        let bande = BandeFenetre.Vue(frame: NSRect(x: 0, y: 0, width: 200, height: 32))
        fenetre.contentView?.addSubview(bande)
        var glissers = 0
        var doubles = 0
        bande.glisser = { f, _ in if f === fenetre { glissers += 1 } }
        bande.doubleCliquer = { f in if f === fenetre { doubles += 1 } }
        func clic(_ n: Int) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 20, y: 10), modifierFlags: [],
                                            timestamp: 0, windowNumber: fenetre.windowNumber, context: nil,
                                            eventNumber: 0, clickCount: n, pressure: 1))
        }
        bande.mouseDown(with: try clic(1))
        #expect(glissers == 1 && doubles == 0, "un clic : la fenetre suit le glisser")
        bande.mouseDown(with: try clic(2))
        #expect(glissers == 1 && doubles == 1, "le second clic : le double-clic")
        #expect(bande.acceptsFirstMouse(for: nil))
        #expect(!bande.mouseDownCanMoveWindow)
    }

    /// Sur la ligne des trois boutons, la bande, et elle seule, recoit les clics entre les deux capsules :
    /// ni les capsules, ni la scene dessous.
    @Test func bandeEntreLesCapsules() throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let sonde = SondeMaillage(preferences: p, actif: false)
        let noms = NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit)
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                               styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
                               defer: false)
        fenetre.isReleasedWhenClosed = false
        let vue = ZStack(alignment: .topLeading) {
            Color.black.onTapGesture {}
            HautPieces(moteur: MoteurPieces(), troisD: .constant(true))
        }
        let hote = NSHostingView(rootView: vue.ignoresSafeArea().environment(s).environment(sonde).environment(noms))
        fenetre.contentView = hote
        FenetrePieces.sansBarreDeTitre(fenetre)
        hote.layoutSubtreeIfNeeded()
        fenetre.layoutIfNeeded()
        let cadre = try #require(hote.superview)
        func sous(_ x: CGFloat, _ y: CGFloat) -> NSView? { cadre.hitTest(NSPoint(x: x, y: fenetre.frame.height - y)) }
        let milieu = CadreFeux.defaut.milieu
        #expect(sous(500, milieu) is BandeFenetre.Vue, "entre les capsules")
        #expect(sous(500, 2) !== hote, "au bord du haut : le cadre de la fenetre")
        #expect(!(sous(CadreFeux.defaut.droite + HautPieces.ecartFeux + 20, milieu) is BandeFenetre.Vue), "la capsule de gauche")
        #expect(!(sous(1000 - HautPieces.bordDroit - 20, milieu) is BandeFenetre.Vue), "la capsule de droite")
        #expect(!(sous(500, 200) is BandeFenetre.Vue), "la scene")
    }

    /// La fenetre reste sombre, meme quand le Mac est en clair : sa barre, ses menus, sa fiche et ses
```

Dans `MaillageThreadTests/FenetreTests.swift`, remplacer :

```swift
    /// Pendant une tournee, la barre d'outils garde sa largeur : le bouton rafraichir ne bouge
    /// pas sous le pointeur. L'indicateur est sur sa propre ligne, qui ne prend aucune place
    /// hors tournee (pas meme l'espacement de la pile).
```

par :

```swift
    /// La place de la tournee : l'indicateur pendant une tournee ; hors tournee, sa place, de la meme
    /// taille, tant qu'une sonde est retenue (rien ne bouge au debut ni a la fin d'une tournee) ; rien
    /// sans sonde.
    @Test func placeDeLaTournee() {
        let a = AvancementTournee(etape: .balayage, fait: 24, total: 48)
        let debut = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(LigneTournee.place(serie: "A0:00:00:00:00:01", avancement: a, debut: debut) == .indicateur(a, debut: debut))
        #expect(LigneTournee.place(serie: "A0:00:00:00:00:01", avancement: nil, debut: nil) == .gardee)
        #expect(LigneTournee.place(serie: nil, avancement: nil, debut: nil) == .aucune)
        let tournee = NSHostingView(rootView: IndicateurTournee(avancement: a, debut: debut)).fittingSize
        let place = NSHostingView(rootView: IndicateurTournee(avancement: AvancementTournee(etape: .etatSonde, fait: 0, total: 1),
                                                              debut: nil).hidden()).fittingSize
        #expect(place == tournee)
    }

    /// Pendant une tournee, la capsule du reseau garde sa largeur : le bouton rafraichir ne bouge
    /// pas sous le pointeur. L'indicateur est sur sa propre ligne, qui ne prend aucune place
    /// sans sonde retenue (pas meme l'espacement de la pile).
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
        let (_, r, e) = try NomsSceneTests.demo()
```

par :

```swift
        let (_, _, e) = try NomsSceneTests.demo()
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
            m.marges = (FenetrePieces.margeHaut(scinde: r.estScinde, sondeRetenue: false, sansPieces: false),
                        FenetrePieces.margeBas(fiche: false, courbes: false))
```

par :

```swift
            // Le haut de la fenetre de la demo : la ligne des capsules, le bandeau de scission et le fil.
            m.marges = (FenetrePieces.margeHaut(bas: 90), FenetrePieces.margeBas(fiche: false, courbes: false))
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/FenetreTests MaillageThreadTests/MoteurPiecesTests`
Expected: la compilation des tests de l'app échoue (`FenetrePiecesTests.swift`, `FenetreTests.swift`), par exemple avec `error: type 'LigneTournee' has no member 'place'` et `error: 'nil' is not compatible with expected argument type 'Date'` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** Le fichier du haut de la fenêtre, puis la capsule du réseau et les lignes du dessous, la fenêtre, les images, l'app.

`MaillageThread/Vues/Pieces/BandeauPieces.swift` (fichier entier) :

```swift
import AppKit
import MaillageCoeur
import SwiftUI

// Haut de la fenetre de la vue par pieces, sans barre de titre (polissage B, section 1 ; maquette du
// bandeau, carte C) : deux capsules de verre sur la ligne des trois boutons de la fenetre, le reseau a
// gauche (`BarreOutils`), la vue a droite (`CommandesVue`) ; entre elles, la bande qui deplace la
// fenetre ; sous la capsule de gauche, en plus petit, la tournee, les bandeaux et le fil.

extension EnvironmentValues {
    /// Rendu d'une capture (`CapturesPieces`, par `ImageRenderer`) : ni le verre, ni les vues d'AppKit
    /// n'y sont dessines ; les vues posent a leur place le dessin de la maquette.
    @Entry var capturePieces = false
}

/// Cadre des trois boutons de la fenetre (fermer, reduire, agrandir), dans l'espace de la vue, dont
/// l'origine est le coin haut gauche de la fenetre (le contenu la couvre en entier) : la capsule de
/// gauche commence juste apres eux, et se centre sur leur milieu.
struct CadreFeux: Equatable {
    /// Bord droit du bouton agrandir (pt, depuis le bord gauche).
    var droite: CGFloat
    /// Milieu des boutons (pt, depuis le haut).
    var milieu: CGFloat

    /// Celui d'une fenetre sans barre d'outils, mesure sous macOS 27 (barre de titre de 32 pt) : trois
    /// boutons de 14 pt, en x = 9, 32 et 55, de 9 a 23 pt du haut. Avant que la fenetre soit connue,
    /// et pour les captures, qui ne rendent pas la fenetre.
    static let defaut = CadreFeux(droite: 69, milieu: 16)

    init(droite: CGFloat, milieu: CGFloat) {
        self.droite = droite
        self.milieu = milieu
    }

    /// Lu sur la fenetre : les cadres des boutons fermer et agrandir, ramenes au coin haut gauche de la
    /// fenetre ; nil sans ces boutons.
    @MainActor
    init?(fenetre: NSWindow) {
        guard let fermer = fenetre.standardWindowButton(.closeButton),
              let agrandir = fenetre.standardWindowButton(.zoomButton) else { return nil }
        let f = fermer.convert(fermer.bounds, to: nil)
        let a = agrandir.convert(agrandir.bounds, to: nil)
        self.init(droite: a.maxX, milieu: fenetre.frame.height - f.midY)
    }
}

/// Ce que fait un double-clic sur la bande du haut : celui d'une barre de titre, selon le reglage du Mac
/// (Bureau et Dock, « Double-cliquer sur la barre de titre d'une fenetre pour »), lu dans
/// `AppleActionOnDoubleClick` : « Fill », « Maximize », « Minimize » ou « None ».
enum ActionDoubleClic: Equatable {
    /// Remplir l'ecran ou agrandir (« Fill », « Maximize », et le reglage absent) : `performZoom`.
    /// AppKit n'a pas d'API publique pour remplir ; le zoom d'une fenetre redimensionnable prend l'ecran.
    case agrandir
    case reduire
    case rien

    init(reglage: String?) {
        switch reglage {
        case "Minimize": self = .reduire
        case "None": self = .rien
        default: self = .agrandir
        }
    }

    static let cle = "AppleActionOnDoubleClick"

    /// Celle du Mac, lue a chaque double-clic : un reglage change s'applique tout de suite.
    static var duMac: ActionDoubleClic { ActionDoubleClic(reglage: UserDefaults.standard.string(forKey: cle)) }

    @MainActor
    func appliquer(_ fenetre: NSWindow) {
        switch self {
        case .agrandir: fenetre.performZoom(nil)
        case .reduire: fenetre.performMiniaturize(nil)
        case .rien: break
        }
    }
}

/// Bande vide du haut, entre les deux capsules : la glisser deplace la fenetre ; un double-clic y fait
/// ce que fait un double-clic sur une barre de titre (`ActionDoubleClic`). C'est une vue d'AppKit, posee
/// sur la scene : elle recoit ses clics avant elle, et les gestes de la scene (tourner, deplacer, le
/// double-clic qui recadre) ne s'y appliquent pas. `WindowDragGesture` deplacerait la fenetre, mais
/// sans le double-clic de la barre de titre. Une capture ne la dessine pas.
struct BandeFenetre: View {
    @Environment(\.capturePieces) private var capture

    var body: some View {
        if capture {
            Color.clear
        } else {
            Representation()
        }
    }

    struct Representation: NSViewRepresentable {
        func makeNSView(context: Context) -> Vue { Vue() }
        func updateNSView(_ nsView: Vue, context: Context) {}
    }

    final class Vue: NSView {
        /// Deplacer la fenetre au glisser ; l'action du double-clic. Remplacees par les tests.
        var glisser: @MainActor (NSWindow, NSEvent) -> Void = { $0.performDrag(with: $1) }
        var doubleCliquer: @MainActor (NSWindow) -> Void = { ActionDoubleClic.duMac.appliquer($0) }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            switch event.clickCount {
            case 1: glisser(window, event)
            case 2: doubleCliquer(window)
            default: break
            }
        }

        /// Comme une barre de titre : le premier clic agit aussi dans une fenetre inactive.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        /// La fenetre est deplacee ici (`performDrag`), et par elle seule.
        override var mouseDownCanMoveWindow: Bool { false }
    }
}

/// Haut de la fenetre, pose sur la scene : la ligne des capsules, centree sur les trois boutons de la
/// fenetre (le reseau juste apres eux, la vue contre le bord droit, la bande entre elles) ; sous la
/// capsule de gauche, alignes sur elle, la ligne de la tournee (sa place gardee tant qu'une sonde est
/// retenue), le bandeau de scission, celui d'une maison sans pieces, et le fil. Sa hauteur mesuree donne
/// la marge du haut de la vue d'ensemble (`FenetrePieces.margeHaut`).
struct HautPieces: View {
    @Environment(Surveillance.self) private var surveillance
    let moteur: MoteurPieces
    @Binding var troisD: Bool
    /// Maison n'a encore aucune piece : le bandeau du passeur.
    var sansPieces = false
    var feux = CadreFeux.defaut

    /// Ecart entre le bouton agrandir et la capsule de gauche, et entre la capsule de droite et le bord
    /// de la fenetre (pt) : ceux de la maquette (72 - 59, et 12).
    static let ecartFeux: CGFloat = 13
    static let bordDroit: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
            HStack(spacing: 0) {
                BarreOutils()
                    .capsuleDeVerre()
                BandeFenetre()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                CommandesVue(moteur: moteur, troisD: $troisD)
                    .capsuleDeVerre()
            }
            .frame(height: 2 * feux.milieu)
            .obstacle("ligne", moteur)
            VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                LigneTournee()
                if let r = surveillance.reseau, r.estScinde {
                    BandeauScission(reseau: r)
                }
                if sansPieces {
                    BandeauSansPieces()
                }
                FilPieces(moteur: moteur)
            }
            .obstacle("colonne", moteur)
        }
        .padding(.leading, feux.droite + Self.ecartFeux)
        .padding(.trailing, Self.bordDroit)
    }
}

/// Bouton d'une capsule du haut (maquette du bandeau, `.b`) : texte de 11 pt (10 sous la capsule) blanc
/// a 0,92, marges de 3 x 9 pt, pastille blanche a 0,10 (0,20 enfoncee) au filet de 0,5 pt blanc a 0,16 ;
/// `allume` : la pastille blanche a 0,28 et le texte blanc, comme le segment choisi de 2D / 3D.
struct StyleBoutonCapsule: ButtonStyle {
    var taille: CGFloat = 11
    var allume = false

    func makeBody(configuration: Configuration) -> some View {
        Corps(etiquette: configuration.label, enfonce: configuration.isPressed, taille: taille, allume: allume)
    }

    private struct Corps<Etiquette: View>: View {
        @Environment(\.isEnabled) private var actif
        let etiquette: Etiquette
        let enfonce: Bool
        let taille: CGFloat
        let allume: Bool

        var body: some View {
            etiquette
                .font(.system(size: taille))
                .foregroundStyle(Color.white.opacity(allume ? 1 : 0.92))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(allume ? 0.28 : enfonce ? 0.2 : 0.1)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
                .contentShape(Capsule())
                .opacity(actif ? 1 : 0.45)
        }
    }
}

/// Bouton a deux etats d'une capsule du haut (« Rotation lente ») : celui de `StyleBoutonCapsule`,
/// allume quand il est actif.
struct StyleBasculeCapsule: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
        }
        .buttonStyle(StyleBoutonCapsule(allume: configuration.isOn))
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}

/// Interrupteur 2D / 3D (maquette du bandeau, `.seg`) : deux segments de 11 pt blancs a 0,8, marges de
/// 3 x 10 pt, dans une pastille blanche a 0,08 au filet de 0,5 pt blanc a 0,16 ; le segment choisi sur
/// une pastille blanche a 0,28, en blanc. Pour VoiceOver, un choix « Vue » a deux segments.
struct SelecteurVue: View {
    @Binding var troisD: Bool

    var body: some View {
        HStack(spacing: 0) {
            segment("2D", choisi: !troisD) { troisD = false }
            segment("3D", choisi: troisD) { troisD = true }
        }
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
        .accessibilityRepresentation {
            Picker("Vue", selection: $troisD) {
                Text("2D").tag(false)
                Text("3D").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    private func segment(_ titre: LocalizedStringKey, choisi: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titre)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(choisi ? 1 : 0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(choisi ? 0.28 : 0)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

extension View {
    /// Capsule de verre du haut (maquette du bandeau, `.verre` de la carte C) : 5 pt autour du contenu,
    /// du verre en capsule. Une capture, qui ne rend pas le verre, pose a sa place le fond de la
    /// maquette : rgba(40, 48, 72, 0,38), filet de 0,5 pt blanc a 0,22, ombre noire a 0,35.
    func capsuleDeVerre() -> some View {
        modifier(CapsuleDeVerre())
    }

    /// Ligne sous la capsule de gauche, en plus petit (maquette du bandeau, `.pilule`) : texte de 10 pt
    /// blanc a 0,75, marges de 3 x 10 pt, en capsule de verre, teintee pour un bandeau d'alerte. Une
    /// capture pose a sa place le fond de la maquette : rgba(40, 48, 72, 0,32) (ou la teinte), filet de
    /// 0,5 pt blanc a 0,16.
    func piluleDuHaut(teinte: Color? = nil) -> some View {
        modifier(PiluleDuHaut(teinte: teinte))
    }
}

/// Fond d'une capsule de verre dans une capture : celui de la maquette.
private let fondVerreCapture = Color(.sRGB, red: 40 / 255, green: 48 / 255, blue: 72 / 255)

private struct CapsuleDeVerre: ViewModifier {
    @Environment(\.capturePieces) private var capture

    func body(content: Content) -> some View {
        let c = content.padding(5)
        if capture {
            c.background(Capsule().fill(fondVerreCapture.opacity(0.38)).shadow(color: .black.opacity(0.35), radius: 9, y: 6))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
        } else {
            c.glassEffect(.regular, in: .capsule)
        }
    }
}

private struct PiluleDuHaut: ViewModifier {
    @Environment(\.capturePieces) private var capture
    let teinte: Color?

    func body(content: Content) -> some View {
        let c = content
            .font(.system(size: 10))
            .foregroundStyle(Color.white.opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
        if capture {
            c.background(Capsule().fill(teinte ?? fondVerreCapture.opacity(0.32)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
        } else {
            c.glassEffect(teinte.map { Glass.regular.tint($0) } ?? .regular, in: .capsule)
        }
    }
}

/// Les trois boutons de la fenetre, dessines dans une capture seulement (qui ne rend pas la fenetre) :
/// a leur place (`CadreFeux.defaut`), aux couleurs de la maquette.
struct FeuxDeCapture: View {
    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(Color(.sRGB, red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255))
            Circle().fill(Color(.sRGB, red: 0xFE / 255, green: 0xBC / 255, blue: 0x2E / 255))
            Circle().fill(Color(.sRGB, red: 0x28 / 255, green: 0xC8 / 255, blue: 0x40 / 255))
        }
        .frame(width: 3 * 14 + 2 * 9, height: 14)
        .offset(x: 9, y: CadreFeux.defaut.milieu - 7)
        .accessibilityHidden(true)
    }
}
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
/// Barre d'outils flottante : reseau, appareils IP, journal, rafraichir.
```

par :

```swift
/// Capsule de gauche du haut de la fenetre : reseau, appareils IP, journal, rafraichir.
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 6) {
                Menu {
                    ForEach(surveillance.instantane?.reseaux ?? []) { r in
                        Button(r.nom) { surveillance.reseauChoisi = r.id }
                    }
                } label: {
                    Text(surveillance.reseau?.nom ?? String(localized: "Aucun réseau Thread"))
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .fixedSize()
                Button {
                    appareilsIP = true
                } label: {
                    Text("Appareils IP · \(surveillance.instantane?.appareilsIP.count ?? 0)")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $appareilsIP) { ListeAppareilsIP() }
                Button("Journal") {
                    openWindow(id: "journal")
                }
                .buttonStyle(.glass)
                // Pendant une tournee : le reseau et les noms, sans seconde tournee.
                Button {
                    surveillance.rafraichir()
                    sonde.rafraichir()
                    if Self.lancePasseur(mode: surveillance.mode) {
                        nomsMaison.lancerPasseur()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .help(Self.aideRafraichir(tournee: sonde.tourneeAuRafraichir,
                                          passeur: Self.lancePasseur(mode: surveillance.mode)))
            }
```

par :

```swift
        HStack(spacing: 5) {
            // « Reseau demo ▾ » : le menu, dessine comme les autres boutons de la capsule.
            Menu {
                ForEach(surveillance.instantane?.reseaux ?? []) { r in
                    Button(r.nom) { surveillance.reseauChoisi = r.id }
                }
            } label: {
                Text(verbatim: (surveillance.reseau?.nom ?? String(localized: "Aucun réseau Thread")) + " ▾")
            }
            .menuStyle(.button)
            .buttonStyle(StyleBoutonCapsule())
            .fixedSize()
            Button {
                appareilsIP = true
            } label: {
                Text("Appareils IP · \(surveillance.instantane?.appareilsIP.count ?? 0)")
            }
            .buttonStyle(StyleBoutonCapsule())
            .popover(isPresented: $appareilsIP) { ListeAppareilsIP() }
            Button("Journal") {
                openWindow(id: "journal")
            }
            .buttonStyle(StyleBoutonCapsule())
            // Pendant une tournee : le reseau et les noms, sans seconde tournee.
            Button {
                surveillance.rafraichir()
                sonde.rafraichir()
                if Self.lancePasseur(mode: surveillance.mode) {
                    nomsMaison.lancerPasseur()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(StyleBoutonCapsule())
            .help(Self.aideRafraichir(tournee: sonde.tourneeAuRafraichir,
                                      passeur: Self.lancePasseur(mode: surveillance.mode)))
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
/// Ligne de la tournee en cours, centree sous la barre d'outils (et le bandeau d'un reseau
/// scinde) : la barre garde sa largeur, son bouton rafraichir ne bouge pas sous le pointeur.
/// Rien hors tournee. Vue a part : seule elle se redessine a chaque pas de la tournee, pas la
/// fenetre de la vue.
struct LigneTournee: View {
    @Environment(SondeMaillage.self) private var sonde

    var body: some View {
        if let a = sonde.avancement, let debut = sonde.debutTournee {
            IndicateurTournee(avancement: a, debut: debut)
```

par :

```swift
/// Ligne de la tournee en cours, sous la capsule de gauche, en plus petit : la capsule garde sa
/// largeur, son bouton rafraichir ne bouge pas sous le pointeur. Hors tournee, sa place reste gardee
/// tant qu'une sonde est retenue : ni la scene ni ce qui est dessous ne bougent au debut ou a la fin
/// d'une tournee (precision 21 du plan 4b). Vue a part : seule elle se redessine a chaque pas de la
/// tournee, pas la fenetre de la vue.
struct LigneTournee: View {
    @Environment(SondeMaillage.self) private var sonde

    /// Ce que montre la ligne : l'indicateur pendant une tournee, sa place (vide) tant qu'une sonde
    /// est retenue, rien sinon.
    enum Place: Equatable {
        case indicateur(AvancementTournee, debut: Date)
        case gardee
        case aucune
    }

    static func place(serie: String?, avancement: AvancementTournee?, debut: Date?) -> Place {
        if let avancement, let debut { return .indicateur(avancement, debut: debut) }
        return serie != nil ? .gardee : .aucune
    }

    var body: some View {
        switch Self.place(serie: sonde.serie, avancement: sonde.avancement, debut: sonde.debutTournee) {
        case .indicateur(let a, let debut):
            IndicateurTournee(avancement: a, debut: debut)
        case .gardee:
            IndicateurTournee(avancement: AvancementTournee(etape: .etatSonde, fait: 0, total: 1), debut: nil)
                .hidden()
                .accessibilityHidden(true)
        case .aucune:
            EmptyView()
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
/// routeurs muets · 24/48 · 0:42 », la duree a jour chaque seconde.
struct IndicateurTournee: View {
    let avancement: AvancementTournee
    let debut: Date

    var body: some View {
        HStack(spacing: 8) {
```

par :

```swift
/// routeurs muets · 24/48 · 0:42 », la duree a jour chaque seconde. Sans debut : la place de la
/// ligne, sans horloge.
struct IndicateurTournee: View {
    let avancement: AvancementTournee
    let debut: Date?

    var body: some View {
        HStack(spacing: 6) {
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
                TimelineView(.periodic(from: debut, by: 1)) { contexte in
                    Text(TexteTournee.barre(avancement, debut: debut, maintenant: contexte.date))
```

par :

```swift
                if let debut {
                    TimelineView(.periodic(from: debut, by: 1)) { contexte in
                        Text(TexteTournee.barre(avancement, debut: debut, maintenant: contexte.date))
                    }
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
```

par :

```swift
        .piluleDuHaut()
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(.orange.opacity(0.35)), in: .capsule)
```

par :

```swift
            .piluleDuHaut(teinte: .orange.opacity(0.35))
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
/// Fenetre de la vue par pieces (spec de la vue par pieces, sections 1 et 7) : la scene occupe toute
/// la fenetre ; la barre d'outils (avec 2D / 3D et « Rotation lente »), les bandeaux, la ligne de la
/// tournee et le fil flottent en haut ; la ligne de niveau, la legende et la fiche en bas. Elle reste
/// sombre, comme la maquette, meme quand le Mac est en clair (precision 15 du plan 4b).
struct FenetrePieces: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(NomsInternes.self) private var nomsMaison
    @Environment(SondeMaillage.self) private var sonde
```

par :

```swift
/// Fenetre de la vue par pieces (spec de la vue par pieces, sections 1 et 7 ; polissage B, section 1) :
/// sans barre de titre, la scene occupe toute la fenetre, jusque sous ses trois boutons ; en haut, les
/// deux capsules du bandeau, la bande qui deplace la fenetre, la ligne de la tournee, les bandeaux et
/// le fil (`HautPieces`) ; en bas, la ligne de niveau, la legende et la fiche. Elle reste sombre, comme
/// la maquette, meme quand le Mac est en clair (precision 15 du plan 4b).
struct FenetrePieces: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(NomsInternes.self) private var nomsMaison
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    @State private var aRenommer: NoeudChoisi?
```

par :

```swift
    @State private var aRenommer: NoeudChoisi?
    /// Les trois boutons de la fenetre, lus sur elle : la capsule de gauche commence apres eux.
    @State private var feux = CadreFeux.defaut
    /// Marge du haut de la vue d'ensemble, d'apres la hauteur mesuree du haut de la fenetre.
    @State private var margeHautMesuree = FenetrePieces.margeHautInitiale
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    /// Places des pieces, a cote des identites des routeurs ; ni en demo ni sous les tests.
```

par :

```swift
    /// Sans barre de titre (polissage B, section 1) : le contenu couvre toute la fenetre, sous la barre
    /// de titre devenue transparente, dont les trois boutons restent poses sur la scene. Le titre
    /// « Maillage Thread » reste celui de la fenetre (Mission Control, menu Fenetre), sans etre affiche.
    static func sansBarreDeTitre(_ fenetre: NSWindow?) {
        guard let fenetre else { return }
        fenetre.styleMask.insert(.fullSizeContentView)
        fenetre.titlebarAppearsTransparent = true
        fenetre.titleVisibility = .hidden
    }

    /// Places des pieces, a cote des identites des routeurs ; ni en demo ni sous les tests.
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    /// Marge du haut de la vue d'ensemble (pt) : la barre d'outils et le fil, puis une ligne de 40 pt
    /// pour le bandeau d'un reseau scinde, une pour la tournee tant qu'une sonde est retenue (rien ne
    /// bouge au debut ni a la fin d'une tournee), et 44 pt pour le bandeau d'une maison sans pieces.
    static func margeHaut(scinde: Bool, sondeRetenue: Bool, sansPieces: Bool) -> CGFloat {
        72 + (scinde ? 40 : 0) + (sondeRetenue ? 40 : 0) + (sansPieces ? 44 : 0)
    }

    /// Marge du bas de la vue d'ensemble (pt) : la legende et la ligne de niveau (elles debordent un
```

par :

```swift
    /// Marge du haut de la vue d'ensemble (pt) : le bas de ce qui est pose en haut de la fenetre, mesure
    /// (`HautPieces` : la ligne des capsules, la place de la tournee tant qu'une sonde est retenue, les
    /// bandeaux presents, le fil), puis l'espacement. Elle remplace les valeurs fixes du plan 4b
    /// (precision 21).
    static func margeHaut(bas: CGFloat) -> CGFloat {
        ceil(bas) + espacement
    }

    /// Avant la premiere mesure : la ligne des capsules, l'espacement et le fil.
    static let margeHautInitiale = margeHaut(bas: 2 * CadreFeux.defaut.milieu + espacement + 16)

    /// Marge du bas de la vue d'ensemble (pt) : la legende et la ligne de niveau (elles debordent un
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                    .ignoresSafeArea()
                if let r = surveillance.reseau, let entree {
                    VuePieces(moteur: moteur, entree: entree, palette: palette,
                              marges: (Self.margeHaut(scinde: r.estScinde, sondeRetenue: sonde.serie != nil,
                                                      sansPieces: entree.scene.sansPiecesMaison),
                                       Self.margeBas(fiche: moteur.selection != nil,
                                                     courbes: FicheNoeud.courbesVisibles(dans: surveillance))))
```

par :

```swift
                if let entree {
                    VuePieces(moteur: moteur, entree: entree, palette: palette,
                              marges: (margeHautMesuree, Self.margeBas(fiche: moteur.selection != nil,
                                                                courbes: FicheNoeud.courbesVisibles(dans: surveillance))))
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                VStack(alignment: .leading, spacing: Self.espacement) {
                    EnTetePieces(moteur: moteur, troisD: $troisD, sansPieces: entree?.scene.sansPiecesMaison == true)
                        .frame(maxWidth: .infinity)
                        .obstacle("en-tete", moteur)
                    FilPieces(moteur: moteur)
                        .obstacle("fil", moteur)
```

par :

```swift
                HautPieces(moteur: moteur, troisD: $troisD, sansPieces: entree?.scene.sansPiecesMaison == true,
                           feux: feux)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(VuePieces.espace)).maxY } action: {
                        margeHautMesuree = Self.margeHaut(bas: $0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                VStack(alignment: .leading, spacing: Self.espacement) {
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
            .coordinateSpace(.named(VuePieces.espace))
```

par :

```swift
            .coordinateSpace(.named(VuePieces.espace))
            .ignoresSafeArea()
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        .background(SondeFenetre { Self.assombrir($0) })
```

par :

```swift
        .background(SondeFenetre { fenetre in
            Self.assombrir(fenetre)
            Self.sansBarreDeTitre(fenetre)
            // Hors de la mise a jour de la vue en cours.
            if let fenetre, let c = CadreFeux(fenetre: fenetre) {
                Task { @MainActor in feux = c }
            }
        })
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
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
```

par :

```swift
/// Capsule de droite du haut de la fenetre : l'interrupteur 2D / 3D, puis « Rotation lente », en 3D
/// seulement (coupee par « Reduire les animations »).
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
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
```

par :

```swift
        HStack(spacing: 5) {
            SelecteurVue(troisD: Binding(get: { moteur.troisD }, set: { v in
                moteur.basculer(troisD: v)
                troisD = v
            }))
            if moteur.troisD {
                Toggle("Rotation lente", isOn: Binding(get: { moteur.rotation && !moteur.reduire },
                                                       set: { _ in moteur.basculerRotation() }))
                    .toggleStyle(StyleBasculeCapsule())
                    .disabled(moteur.reduire)
                    .help(moteur.reduire ? String(localized: "Coupée par « Réduire les animations »") : "")
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
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
```

par :

```swift
        HStack(spacing: 8) {
            Label("Pas encore de pièces de Maison : lance le passeur", systemImage: "house")
            Button("Rafraîchir depuis Maison") { nomsMaison.lancerPasseur() }
                .buttonStyle(StyleBoutonCapsule(taille: 10))
                .disabled(surveillance.mode == .demo)
        }
        .piluleDuHaut()
    }
}

/// Fil, sous la capsule de gauche : « Maison », puis « › Salon » en piece isolee ; « Maison » y
/// ramene. Une capture le dessine sans bouton.
struct FilPieces: View {
    @Environment(\.capturePieces) private var capture
    let moteur: MoteurPieces
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
/// pieces isolees, survol. Sans fenetre ni capture d'ecran ; l'app quitte ensuite.
```

par :

```swift
/// pieces isolees, survol. Sans fenetre ni capture d'ecran ; l'app quitte ensuite. `ImageRenderer` ne
/// rend ni la fenetre ni le verre : le haut de la fenetre y est dessine comme dans la maquette du
/// bandeau (`capturePieces`), avec les trois boutons de la fenetre a leur place (`FeuxDeCapture`).
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
    static func ecrire(dans dossier: String, surveillance s: Surveillance) -> [String] {
        try? FileManager.default.createDirectory(atPath: dossier, withIntermediateDirectories: true)
        guard let r = s.reseau else { return [] }
        let palette = Palette(sombre: true)
        let marges = (FenetrePieces.margeHaut(scinde: r.estScinde, sondeRetenue: false, sansPieces: false),
                      FenetrePieces.margeBas(fiche: false, courbes: false))
```

par :

```swift
    static func ecrire(dans dossier: String, surveillance s: Surveillance, sonde: SondeMaillage,
                       nomsMaison: NomsInternes) -> [String] {
        try? FileManager.default.createDirectory(atPath: dossier, withIntermediateDirectories: true)
        guard let r = s.reseau else { return [] }
        let palette = Palette(sombre: true)
        // Marge du haut : la hauteur du haut de la fenetre, mesuree comme dans la fenetre.
        let haut = NSHostingView(rootView: HautPieces(moteur: MoteurPieces(), troisD: .constant(false))
            .pourCapture(s, sonde, nomsMaison)).fittingSize.height
        let marges = (FenetrePieces.margeHaut(bas: haut), FenetrePieces.margeBas(fiche: false, courbes: false))
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
                let rendu = ImageRenderer(content: VueCapture(moteur: m, palette: palette).frame(width: taille.width,
                                                                                                height: taille.height))
```

par :

```swift
                let rendu = ImageRenderer(content: VueCapture(moteur: m, palette: palette)
                    .frame(width: taille.width, height: taille.height)
                    .pourCapture(s, sonde, nomsMaison))
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
/// La vue d'une capture : le fond, la scene, le fil et la ligne de niveau, sans horloge ni geste.
```

par :

```swift
/// La vue d'une capture : le fond, la scene, le haut de la fenetre (avec ses trois boutons) et la
/// ligne de niveau, sans horloge ni geste.
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
            VStack(alignment: .leading) {
                FilPieces(moteur: moteur, capture: true)
                    .padding(.top, 56)
```

par :

```swift
            HautPieces(moteur: moteur, troisD: .constant(moteur.troisD))
            FeuxDeCapture()
            VStack(alignment: .leading) {
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
        .environment(\.colorScheme, .dark)
```

par :

```swift
        .coordinateSpace(.named(VuePieces.espace))
    }
}

extension View {
    /// Ce qu'une vue de la fenetre lit dans une capture : la surveillance, la sonde et les noms de la
    /// demo, l'apparence sombre, et le rendu de capture.
    func pourCapture(_ s: Surveillance, _ sonde: SondeMaillage, _ noms: NomsInternes) -> some View {
        environment(\.capturePieces, true)
            .environment(\.colorScheme, .dark)
            .environment(s)
            .environment(sonde)
            .environment(noms)
```

Dans `MaillageThread/MaillageThreadApp.swift`, remplacer :

```swift
            CapturesPieces.ecrire(dans: dossier, surveillance: s)
```

par :

```swift
            CapturesPieces.ecrire(dans: dossier, surveillance: s, sonde: sm, nomsMaison: d)
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/FenetreTests MaillageThreadTests/MoteurPiecesTests`
Expected: `Test run with 40 tests in 3 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh`
Expected: `Test run with 346 tests in 36 suites passed` (cœur) et `Test run with 273 tests in 28 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 4 tests de plus pour l'app. Les quatre tests de la tâche s'ajoutent à l'app.

- [ ] **Step 6 : les images de démo, avec le bandeau.** L'app, en mode démo seulement, écrit ses images de 1440 × 900 points en 2x dans son conteneur, sans fenêtre, puis quitte ; `open -W` attend qu'elle ait quitté. Elles changent toutes : le bandeau, et la marge du haut.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polB-t1"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polB/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polB/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
```

Expected : 12 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`) ; « l'app a quitté ».

Regarder `01-2d.png` et `05-3d.png` (outil Read) : les trois boutons de la fenêtre en haut à gauche, la capsule du réseau juste après eux (« ▾ », « Appareils IP », « Journal », ⟳), la capsule de la vue contre le bord droit (2D / 3D, et « Rotation lente » en 3D), le bandeau de scission puis « Maison » sous la capsule de gauche ; la vue d'ensemble dessous.

- [ ] **Step 7 : commit.**

```bash
git add MaillageThreadTests/FenetrePiecesTests.swift MaillageThreadTests/FenetreTests.swift MaillageThreadTests/MoteurPiecesTests.swift MaillageThread/Vues/Pieces/BandeauPieces.swift MaillageThread/Vues/Pieces/MorceauxFenetre.swift MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/Pieces/CapturesPieces.swift MaillageThread/MaillageThreadApp.swift
git commit -m "Oter la barre de titre de la vue par pieces, poser le bandeau en deux capsules de verre sur la ligne des boutons, deplacer la fenetre par la bande du haut, et mesurer la marge du haut

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: La légende : contextuelle, repliable et gardée ; la pastille d'un relevé ancien

**Files:**
- Create: `MaillageThread/Vues/Pieces/LegendePieces.swift`
- Modify: `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/Pieces/MorceauxFenetre.swift` (retire `LegendeLiens`), `MaillageThread/Vues/Pieces/Palette.swift`, `MaillageThread/Vues/Pieces/CapturesPieces.swift` (blocs ci-dessous)
- Modify (par les outils) : `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json`
- Test: `MaillageThreadTests/LegendePiecesTests.swift` (nouveau), `MaillageThreadTests/FenetrePiecesTests.swift`

**Interfaces:**
- Consumes :
  - `EntreeScene` (`scene`, `apparences`, `appareils`, `libelles`, `maillage`), `DessinNoeud.Couleur`, `Palette.NiveauLien`, `ScenePieces.Lien`, `LibellesNoeuds.inconnu`, `MoteurPieces.isolee` et `textes.ailleurs`, `Surveillance.maillageAncien`, existants ;
  - dans les tests : `NomsSceneTests.demo()`, `FenetrePiecesTests.entree(_:)`, `SondeMaillageTests.preferences()`, existants.
- Produces :
  - `LegendePieces(rubriques:forcee:)` (`cleRepliee` = `legendeRepliee`) ; `LegendePieces.Entree` (dix-huit entrées, `texte`), `LegendePieces.Groupe` (`routeurs`, `appareils`, `liens`, `autres` ; `entrees`, `titre`), `LegendePieces.Rubrique` ;
  - `LegendePieces.Lecture` (`couleurs`, `inconnus`, `chefs`, `endormis`, `piles`, `candidats`, `liens`, `ailleurs` ; `init(_:ailleurs:)` depuis une `EntreeScene`) ; `LegendePieces.entrees(_:) -> Set<Entree>`, `LegendePieces.rubriques(_:) -> [Rubrique]` ; `exemplePile`, `exempleAilleurs`, `exempleCandidats` ;
  - `GrilleLegende` (`Layout` : `largeurColonne(_:)`, `largeurPanneau` = 440) ; `PastilleAncien` ; `View.fondDeLegende()` ;
  - `LigneDuBas(moteur:entree:legende:ancien:legendeForcee:surHauteurOuverte:)`, qui garde le repli (`@AppStorage`) et rend la hauteur de la ligne, la légende ouverte (nil, repliée ; rien sous une fiche) ; `LegendePieces(rubriques:repliee:)` ;
  - `FenetrePieces.margeBas(fiche:courbes:legendeOuverte:) -> CGFloat` : la fiche (190 ou 360), la légende ouverte (le bord, sa hauteur mesurée, l'espacement ; au moins 30), sinon 30 ;
  - `Palette.fondLegende`, `texteLegende`, `titreLegende` ;
  - le catalogue : 16 textes nouveaux, 3 retirés.

**La légende A, adaptée** (spec, section 2 ; maquette de la légende, colonne de droite). Elle remplace `LegendeLiens`, à la même place, en bas à gauche, à côté de la ligne de niveau. Ses entrées viennent d'une fonction pure, `LegendePieces.rubriques`, qui lit la scène affichée (précision 9) : une entrée n'est montrée que si la scène la contient, un groupe sans entrée disparaît, et une légende sans entrée n'est pas montrée. Son aspect est celui de la maquette (précisions 10 à 12), et son repli est gardé (précision 11). « Relevé de la sonde ancien » en sort, pour une pastille à côté de la ligne de niveau (précision 13).

**La vue d'ensemble se cadre au-dessus de la légende ouverte** (décision de Djoko du 01/10, précision 17) : la ligne du bas, qui garde le repli, rend sa hauteur quand la légende est ouverte, et la marge du bas la suit ; repliée, la marge d'avant. Dans cette tâche, la vue se recadre d'un coup ; la tâche 3 la fait glisser.

**Les images de démo** montrent la légende ouverte, et la vue d'ensemble au-dessus d'elle : elles changent toutes.

- [ ] **Step 1 : écrire les tests.** Un fichier de tests nouveau (dont la marge du bas, et la vue au-dessus de la légende ouverte), et la légende dans la fenêtre redessinée chaque minute.

`MaillageThreadTests/LegendePiecesTests.swift` (fichier entier) :

```swift
import AppKit
import Foundation
import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : la legende")
struct LegendePiecesTests {
    typealias Entree = LegendePieces.Entree
    typealias Lecture = LegendePieces.Lecture

    static func radio(_ qualite: Int?) -> ScenePieces.Lien {
        ScenePieces.Lien(de: "rloc:0400", vers: "rloc:5000", genre: .radio, qualite: qualite)
    }

    /// Une scene inventee par signe : chacune ne contient que lui, et la legende n'a que son entree. Un
    /// noeud que la sonde seule connait, routeur ou enfant, est « non identifie » ; un appareil d'etat
    /// inconnu, gris lui aussi, n'a pas d'entree.
    @Test func uneEntreeParSigne() {
        let cas: [(Lecture, Set<Entree>)] = [
            (Lecture(couleurs: ["Apple TV 4K": .routeur(principale: true)]), [.routeur]),
            (Lecture(couleurs: ["rloc:5000": .routeurInconnu], inconnus: ["rloc:5000"]), [.nonIdentifie]),
            (Lecture(couleurs: ["rloc:041F": .appareil(.inconnu)], inconnus: ["rloc:041F"]), [.nonIdentifie]),
            (Lecture(couleurs: ["Aqara": .routeur(principale: false)]), [.autrePartition]),
            (Lecture(chefs: ["Apple TV 4K"]), [.chef]),
            (Lecture(couleurs: ["E000000000000001": .appareil(.joignable)]), [.joignable]),
            (Lecture(couleurs: ["E000000000000002": .appareil(.partitionCoupee)]), [.partitionCoupee]),
            (Lecture(couleurs: ["E000000000000003": .appareil(.sansAdresse)]), [.sansAdresse]),
            (Lecture(couleurs: ["E000000000000004": .appareil(.disparu)]), [.disparu]),
            (Lecture(endormis: ["E000000000000005"]), [.endormi]),
            (Lecture(piles: ["E000000000000006"]), [.pile]),
            (Lecture(liens: [Self.radio(3)]), [.bonne]),
            (Lecture(liens: [Self.radio(2)]), [.moyenne]),
            (Lecture(liens: [Self.radio(1)]), [.faible]),
            (Lecture(liens: [Self.radio(nil)]), [.inconnue]),
            (Lecture(liens: [Self.radio(0)]), [.inconnue]),
            (Lecture(liens: [ScenePieces.Lien(de: "E000000000000001", vers: "rloc:5000", genre: .parent, qualite: 3)]),
             [.versParent]),
            (Lecture(liens: [ScenePieces.Lien(de: "E000000000000001", vers: "Apple TV 4K")]), [.rattachement]),
            (Lecture(ailleurs: true), [.ailleurs]),
            (Lecture(candidats: ["rloc:0400"]), [.candidats]),
            (Lecture(couleurs: ["E000000000000007": .appareil(.inconnu)]), []),
            (Lecture(), []),
        ]
        for (lecture, attendu) in cas {
            #expect(LegendePieces.entrees(lecture) == attendu, "\(attendu)")
        }
    }

    /// Les groupes dans l'ordre de la grille (routeurs, appareils, liens radio, autres), leurs entrees
    /// dans l'ordre de la spec ; un groupe sans entree disparait, et une scene vide n'a pas de legende.
    @Test func groupesEtOrdre() {
        let tout = Lecture(couleurs: ["a": .routeur(principale: true), "b": .routeur(principale: false),
                                      "c": .appareil(.joignable), "d": .appareil(.partitionCoupee),
                                      "e": .appareil(.sansAdresse), "f": .appareil(.disparu)],
                           inconnus: ["g"], chefs: ["a"], endormis: ["c"], piles: ["c"], candidats: ["g"],
                           liens: [Self.radio(3), Self.radio(2), Self.radio(1), Self.radio(nil),
                                   ScenePieces.Lien(de: "c", vers: "a", genre: .parent),
                                   ScenePieces.Lien(de: "d", vers: "a")],
                           ailleurs: true)
        #expect(LegendePieces.rubriques(tout) == LegendePieces.Groupe.allCases.map {
            LegendePieces.Rubrique(groupe: $0, entrees: $0.entrees)
        })
        #expect(Set(LegendePieces.Groupe.allCases.flatMap(\.entrees)) == Set(Entree.allCases), "chaque entree a son groupe")
        let sansLiens = Lecture(couleurs: ["c": .appareil(.joignable)], chefs: ["a"], ailleurs: true)
        #expect(LegendePieces.rubriques(sansLiens) == [
            LegendePieces.Rubrique(groupe: .routeurs, entrees: [.chef]),
            LegendePieces.Rubrique(groupe: .appareils, entrees: [.joignable]),
            LegendePieces.Rubrique(groupe: .autres, entrees: [.ailleurs]),
        ])
        #expect(LegendePieces.rubriques(Lecture()).isEmpty)
    }

    /// La scene de la demo, lue telle que la fenetre la dessine : avec la sonde, puis sans (plus de liens
    /// radio : le groupe disparait) ; une piece isolee qui pose des reperes « ailleurs ».
    @Test func legendeDeLaDemo() throws {
        let (s, _, e) = try NomsSceneTests.demo()
        let avec = LegendePieces.entrees(Lecture(e, ailleurs: false))
        #expect(avec == [.routeur, .nonIdentifie, .autrePartition, .chef, .joignable, .sansAdresse, .disparu, .endormi,
                         .pile, .bonne, .moyenne, .faible, .versParent, .rattachement])
        #expect(LegendePieces.entrees(Lecture(e, ailleurs: true)).contains(.ailleurs))
        s.oublierMaillage()
        let sans = try #require(FenetrePiecesTests.entree(s))
        #expect(sans.maillage == nil)
        let rubriques = LegendePieces.rubriques(Lecture(sans, ailleurs: false))
        #expect(rubriques.map(\.groupe) == [.routeurs, .appareils, .autres])
        #expect(rubriques.last?.entrees == [.rattachement])
    }

    /// Les signes de la legende reprennent ceux de la scene : la pastille d'une pile (« 12 % »), un
    /// routeur et ses deux candidats (« A ou B · 0400 »).
    @Test func exemples() {
        #expect(LegendePieces.exemplePile == String(localized: "\(12)\u{202F}%"))
        #expect(LegendePieces.exempleCandidats
                == String(localized: "\(["A", "B"].formatted(.list(type: .or))) · \("0400")"))
        #expect(LegendePieces.exempleAilleurs == String(localized: "→ Salon"))
    }

    /// Deux colonnes de meme largeur : la moitie d'un panneau de 440 pt, ou celle du groupe le plus large.
    @Test func colonnes() {
        #expect(GrilleLegende.largeurColonne([120, 150]) == 199)
        #expect(GrilleLegende.largeurColonne([251, 120]) == 251)
        #expect(GrilleLegende.largeurColonne([]) == 199)
    }

    /// Le repli est garde dans les preferences (`legendeRepliee`), par la ligne du bas : repliee, il ne
    /// reste que l'etiquette ; un etat impose (captures) passe avant, sans ecrire la preference.
    @Test func repliGarde() throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let (_, _, e) = try NomsSceneTests.demo()
        #expect(LegendePieces.cleRepliee == "legendeRepliee")
        func taille(_ v: LigneDuBas) -> CGSize {
            NSHostingView(rootView: v.defaultAppStorage(p)).fittingSize
        }
        let ouverte = taille(LigneDuBas(moteur: MoteurPieces(), entree: e))
        p.set(true, forKey: LegendePieces.cleRepliee)
        let repliee = taille(LigneDuBas(moteur: MoteurPieces(), entree: e))
        #expect(repliee.height < 40 && ouverte.height > 4 * repliee.height, "\(repliee) \(ouverte)")
        #expect(taille(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false)) == ouverte)
        p.set(false, forKey: LegendePieces.cleRepliee)
        #expect(taille(LigneDuBas(moteur: MoteurPieces(), entree: e)) == ouverte)
        #expect(taille(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: true)) == repliee)
        #expect(p.bool(forKey: LegendePieces.cleRepliee) == false, "l'etat impose n'ecrit rien")
        let tout = LegendePieces.Groupe.allCases.map { LegendePieces.Rubrique(groupe: $0, entrees: $0.entrees) }
        func legende(_ r: [LegendePieces.Rubrique]) -> CGSize {
            NSHostingView(rootView: LegendePieces(rubriques: r, repliee: .constant(false))).fittingSize
        }
        #expect(legende(tout).width >= GrilleLegende.largeurPanneau)
        #expect(legende([]) == .zero, "sans entree, pas de legende")
    }

    /// La marge du bas suit la legende ouverte (decision de Djoko du 01/10) : la hauteur mesuree de la
    /// ligne du bas (la legende et la ligne de niveau), le bord et l'espacement ; repliee, la marge d'avant,
    /// 30 pt ; une fiche ouverte, qui cache la legende, garde ses 190 ou 360 pt.
    @Test func margeDuBas() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let h = NSHostingView(rootView: LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false))
            .fittingSize.height
        #expect(h > 150, "la legende de la demo, ouverte : \(h)")
        #expect(FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: h)
                == FenetrePieces.bord + ceil(h) + FenetrePieces.espacement)
        #expect(FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: nil) == 30, "repliee")
        #expect(FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: 2) == 30)
        #expect(FenetrePieces.margeBas(fiche: true, courbes: false, legendeOuverte: h) == 190)
        #expect(FenetrePieces.margeBas(fiche: true, courbes: true, legendeOuverte: h) == 360)
    }

    /// La vue d'ensemble se cadre au-dessus de la legende ouverte : dans une fenetre de 1440 x 900, aucun
    /// bloc, aucune pastille ni aucun nom de piece de la demo ne descend sous son bord du haut, en 2D
    /// comme en 3D.
    @Test(arguments: [false, true]) func vueAuDessusDeLaLegende(_ troisD: Bool) throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let h = NSHostingView(rootView: LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false))
            .fittingSize.height
        let taille = CGSize(width: 1440, height: 900)
        let m = MoteurPieces(troisD: troisD)
        m.fige = true
        m.marges = (FenetrePieces.margeHaut(bas: 90), FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: h))
        m.poserTaille(taille)
        m.installerMaintenant(e)
        m.poserTaille(taille)
        MoteurPiecesTests.dessiner(m, taille: taille)
        let haut = taille.height - FenetrePieces.bord - h
        let p = try #require(m.projetee)
        #expect(!p.blocs.isEmpty && !p.disques.isEmpty)
        #expect(p.blocs.allSatisfy { b in b.faces.allSatisfy { f in f.points.allSatisfy { $0.y <= haut } } })
        #expect(p.disques.allSatisfy { $0.centre.y + $0.rayon <= haut })
        #expect(p.ancresPieces.values.allSatisfy { $0.maxY <= haut })
    }

    /// « Releve de la sonde ancien » n'est plus dans la legende : c'est une pastille a cote de la ligne de
    /// niveau, quand le releve est ancien, fiche ouverte ou non.
    @Test func pastilleDuReleveAncien() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces()
        func largeur(_ v: LigneDuBas) -> CGFloat { NSHostingView(rootView: v).fittingSize.width }
        let sansFiche = largeur(LigneDuBas(moteur: m, entree: e, legendeForcee: false))
        #expect(largeur(LigneDuBas(moteur: m, entree: e, ancien: true, legendeForcee: false)) > sansFiche)
        let fiche = largeur(LigneDuBas(moteur: m, entree: e, legende: false))
        #expect(fiche < sansFiche, "fiche ouverte : sans la legende")
        #expect(largeur(LigneDuBas(moteur: m, entree: e, legende: false, ancien: true)) > fiche)
    }
}
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// dedans tout ce qui lit l'heure (la legende, la scene, la fiche).
```

par :

```swift
    /// dedans tout ce qui lit l'heure (le bas de la fenetre et sa pastille d'un releve ancien, la scene,
    /// la fiche).
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
        for vue in ["LegendeLiens", "VuePieces", "FicheNoeud"] {
```

par :

```swift
        for vue in ["LigneDuBas", "VuePieces", "FicheNoeud"] {
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh MaillageThreadTests/LegendePiecesTests MaillageThreadTests/FenetrePiecesTests`
Expected: la compilation des tests de l'app échoue (`LegendePiecesTests.swift`), par exemple avec `error: cannot find type 'LegendePieces' in scope` et `error: reference to member 'routeur' cannot be resolved without a contextual type` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** La légende, puis la fenêtre (`LigneDuBas`, la marge du bas), le retrait de l'ancienne légende, les couleurs, les images (la marge du bas mesurée).

`MaillageThread/Vues/Pieces/LegendePieces.swift` (fichier entier) :

```swift
import MaillageCoeur
import SwiftUI

/// Legende de la vue par pieces (polissage B, section 2 ; maquette de la legende, colonne de droite) :
/// en bas a gauche, a cote de la ligne de niveau ; quatre groupes en grille de deux colonnes, qui ne
/// montrent que ce que la scene affichee contient. Repliee, il ne reste que l'etiquette « Legende » ;
/// son etat est garde d'un lancement a l'autre, par la ligne du bas (`LigneDuBas`). Une legende sans
/// entree n'est pas montree.
struct LegendePieces: View {
    let rubriques: [Rubrique]
    /// Repliee ou ouverte : un clic sur l'en-tete bascule.
    @Binding var repliee: Bool

    /// La preference qui garde le repli.
    static let cleRepliee = "legendeRepliee"

    var body: some View {
        if !rubriques.isEmpty {
            if repliee {
                etiquette
            } else {
                panneau
            }
        }
    }

    /// « Legende ⌄ » : 11,5 pt semi-gras, marges de 6 x 12 pt.
    private var etiquette: some View {
        Button {
            repliee = false
        } label: {
            HStack(spacing: 8) {
                Text("Légende")
                Text(verbatim: "⌄").accessibilityHidden(true)
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Palette.texteLegende)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .fondDeLegende()
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// En-tete « Legende ⌃ » (7 pt dessous), puis la grille ; marges de 9, 12, 11 et 12 pt. La largeur
    /// est celle de la grille : l'en-tete s'y etend, sans elargir le panneau.
    private var panneau: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                repliee = true
            } label: {
                HStack {
                    Text("Légende")
                    Spacer(minLength: 8)
                    Text(verbatim: "⌃").accessibilityHidden(true)
                }
                .font(.system(size: 11.5, weight: .semibold))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            GrilleLegende {
                ForEach(rubriques, id: \.groupe) { r in
                    groupe(r)
                }
            }
        }
        .fixedSize()
        .font(.system(size: 11))
        .foregroundStyle(Palette.texteLegende)
        .padding(EdgeInsets(top: 9, leading: 12, bottom: 11, trailing: 12))
        .fondDeLegende()
    }

    /// Un groupe : son titre (10 pt semi-gras, gris bleute), 4 pt, puis ses entrees, a 3 pt l'une de
    /// l'autre, et 3 pt dessous.
    private func groupe(_ r: Rubrique) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(r.groupe.titre)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(Palette.titreLegende)
                .padding(.bottom, 1)
            ForEach(r.entrees, id: \.self) { e in
                ligne(e)
            }
        }
        .padding(.bottom, 3)
        .fixedSize()
    }

    /// Une entree : son signe, 7 pt, son texte ; la couronne et la lune sont dans le texte.
    @ViewBuilder
    private func ligne(_ e: Entree) -> some View {
        let palette = Palette(sombre: true)
        switch e {
        case .chef, .endormi:
            Text(e.texte)
        default:
            HStack(spacing: 7) {
                signe(e, palette)
                    .accessibilityHidden(true)
                Text(e.texte)
            }
        }
    }

    @ViewBuilder
    private func signe(_ e: Entree, _ palette: Palette) -> some View {
        switch e {
        case .routeur: point(palette.routeur(principale: true))
        case .nonIdentifie: point(palette.routeurInconnu)
        case .autrePartition: point(palette.routeur(principale: false))
        case .joignable: point(palette.appareil(.joignable))
        case .partitionCoupee: point(palette.appareil(.partitionCoupee))
        case .sansAdresse: point(palette.appareil(.sansAdresse))
        case .disparu:
            Circle().strokeBorder(palette.appareil(.disparu), lineWidth: 1.6).frame(width: 9, height: 9)
        case .pile:
            Text(verbatim: LegendePieces.exemplePile)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(palette.texteBatterieFaible)
                .padding(.horizontal, 4)
                .background(RoundedRectangle(cornerRadius: 4).fill(palette.batterieFaible))
        case .bonne: trait(palette.lienSonde(3))
        case .moyenne: trait(palette.lienSonde(2))
        case .faible: trait(palette.lienSonde(1))
        case .inconnue: trait(palette.lienSonde(nil))
        case .versParent:
            Rectangle().fill(palette.encre.opacity(0.28)).frame(width: 22, height: 1)
        case .rattachement:
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0.6))
                p.addLine(to: CGPoint(x: 22, y: 0.6))
            }
            .stroke(palette.encre.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, dash: [2, 4]))
            .frame(width: 22, height: 1.2)
        case .ailleurs:
            Text(verbatim: LegendePieces.exempleAilleurs)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.8))
                .padding(.horizontal, 5)
                .background(RoundedRectangle(cornerRadius: 4).fill(palette.fondAilleurs))
        case .candidats:
            Text(verbatim: LegendePieces.exempleCandidats)
                .font(.system(size: 10))
                .padding(.horizontal, 5)
                .background(RoundedRectangle(cornerRadius: 4).fill(palette.fondNom))
        case .chef, .endormi:
            EmptyView()
        }
    }

    /// Point de 9 pt.
    private func point(_ c: Color) -> some View {
        Circle().fill(c).frame(width: 9, height: 9)
    }

    /// Trait de 22 x 2 pt, arrondi : un lien radio, de la couleur de sa qualite.
    private func trait(_ c: Color) -> some View {
        RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 22, height: 2)
    }

    /// Exemples des signes, comme dans la scene : la pastille d'une pile a 12 %, un repere « ailleurs »,
    /// un routeur et ses deux candidats.
    static var exemplePile: String { String(localized: "\(12)\u{202F}%") }
    static var exempleAilleurs: String { String(localized: "→ Salon") }
    static var exempleCandidats: String {
        LibellesNoeuds.inconnu(NoeudSonde(id: "rloc:0400", rloc16: 0x0400, genre: .routeur, reconnu: false,
                                          bordure: true, candidats: ["A", "B"]))
    }
}

extension LegendePieces {
    /// Une entree de la legende : un signe et son texte (spec du polissage B, section 2).
    enum Entree: Hashable, CaseIterable {
        case routeur, nonIdentifie, autrePartition, chef
        case joignable, partitionCoupee, sansAdresse, disparu, endormi, pile
        case bonne, moyenne, faible, inconnue
        case versParent, rattachement, ailleurs, candidats

        var texte: String {
            switch self {
            case .routeur: String(localized: "routeur")
            case .nonIdentifie: String(localized: "non identifié")
            case .autrePartition: String(localized: "autre partition")
            case .chef: "👑 " + String(localized: "chef du réseau Thread, élu automatiquement")
            case .joignable: String(localized: "joignable")
            case .partitionCoupee: String(localized: "partition coupée")
            case .sansAdresse: String(localized: "sans adresse")
            case .disparu: String(localized: "disparu")
            case .endormi: "☾ " + String(localized: "endormi")
            case .pile: String(localized: "pile")
            case .bonne: String(localized: "bonne")
            case .moyenne: String(localized: "moyenne")
            case .faible: String(localized: "faible")
            case .inconnue: String(localized: "inconnue")
            case .versParent: String(localized: "vers son parent")
            case .rattachement: String(localized: "rattachement supposé")
            case .ailleurs: String(localized: "parent dans une autre pièce")
            case .candidats: String(localized: "candidats")
            }
        }
    }

    /// Les quatre groupes, dans l'ordre de la grille, et leurs entrees, dans l'ordre.
    enum Groupe: Hashable, CaseIterable {
        case routeurs, appareils, liens, autres

        var entrees: [Entree] {
            switch self {
            case .routeurs: [.routeur, .nonIdentifie, .autrePartition, .chef]
            case .appareils: [.joignable, .partitionCoupee, .sansAdresse, .disparu, .endormi, .pile]
            case .liens: [.bonne, .moyenne, .faible, .inconnue]
            case .autres: [.versParent, .rattachement, .ailleurs, .candidats]
            }
        }

        var titre: String {
            switch self {
            case .routeurs: String(localized: "Routeurs")
            case .appareils: String(localized: "Appareils")
            case .liens: String(localized: "Liens radio (qualité)")
            case .autres: String(localized: "Autres")
            }
        }
    }

    /// Un groupe montre, et ses entrees presentes.
    struct Rubrique: Equatable {
        var groupe: Groupe
        var entrees: [Entree]
    }

    /// Ce que la legende lit de la scene affichee : la couleur de chaque noeud, ceux que la sonde seule
    /// connait, les chefs, les endormis, les piles, les noeuds montres avec leurs candidats, les liens, et
    /// si des reperes « ailleurs » sont poses (piece isolee).
    struct Lecture {
        var couleurs: [String: DessinNoeud.Couleur] = [:]
        var inconnus: Set<String> = []
        var chefs: Set<String> = []
        var endormis: Set<String> = []
        var piles: Set<String> = []
        var candidats: Set<String> = []
        var liens: [ScenePieces.Lien] = []
        var ailleurs = false
    }

    /// Les entrees que la scene contient (spec du polissage B, section 2) : chaque couleur de noeud ; un
    /// noeud que la sonde seule connait, routeur ou enfant, en gris (« non identifie ») ; un chef, un
    /// endormi, une pile ; chaque qualite d'un lien radio trace ; un lien vers un parent, un rattachement
    /// suppose ; un repere « ailleurs » ; un routeur montre avec ses candidats. Un appareil d'etat
    /// inconnu, en gris, n'a pas d'entree.
    static func entrees(_ l: Lecture) -> Set<Entree> {
        var r = Set<Entree>()
        for c in l.couleurs.values {
            switch c {
            case .routeur(principale: true): r.insert(.routeur)
            case .routeur(principale: false): r.insert(.autrePartition)
            case .appareil(.joignable): r.insert(.joignable)
            case .appareil(.partitionCoupee): r.insert(.partitionCoupee)
            case .appareil(.sansAdresse): r.insert(.sansAdresse)
            case .appareil(.disparu): r.insert(.disparu)
            case .routeurInconnu, .appareil(.inconnu): break
            }
        }
        if !l.inconnus.isEmpty { r.insert(.nonIdentifie) }
        if !l.chefs.isEmpty { r.insert(.chef) }
        if !l.endormis.isEmpty { r.insert(.endormi) }
        if !l.piles.isEmpty { r.insert(.pile) }
        if !l.candidats.isEmpty { r.insert(.candidats) }
        for lien in l.liens {
            switch lien.genre {
            case .radio:
                switch Palette.NiveauLien(lien.qualite) {
                case .bon: r.insert(.bonne)
                case .moyen: r.insert(.moyenne)
                case .faible: r.insert(.faible)
                case .inconnu: r.insert(.inconnue)
                }
            case .parent: r.insert(.versParent)
            case .rattachement: r.insert(.rattachement)
            }
        }
        if l.ailleurs { r.insert(.ailleurs) }
        return r
    }

    /// Les groupes a montrer, dans l'ordre, chacun avec ses entrees presentes ; un groupe sans entree
    /// disparait.
    static func rubriques(_ l: Lecture) -> [Rubrique] {
        let presentes = entrees(l)
        return Groupe.allCases.compactMap { g in
            let e = g.entrees.filter(presentes.contains)
            return e.isEmpty ? nil : Rubrique(groupe: g, entrees: e)
        }
    }
}

extension LegendePieces.Lecture {
    /// Lecture de la scene d'un rendu (`EntreeScene`) ; `ailleurs` : des reperes « ailleurs » sont
    /// poses.
    init(_ e: EntreeScene, ailleurs: Bool) {
        let ids = e.scene.noeuds.map(\.id)
        couleurs = Dictionary(ids.compactMap { id in e.apparences[id].map { (id, $0.couleur) } },
                              uniquingKeysWith: { a, _ in a })
        inconnus = Set(e.scene.noeuds.filter(\.inconnu).map(\.id))
        chefs = Set(e.scene.noeuds.filter(\.chef).map(\.id))
        endormis = Set(ids.filter { e.appareils[$0]?.endormi == true })
        piles = Set(ids.filter { e.libelles[$0]?.pastille != nil })
        candidats = Set(ids.filter { id in
            e.maillage?.noeud(id).map { $0.genre == .routeur && !$0.candidats.isEmpty } == true
        })
        liens = e.scene.liens
        self.ailleurs = ailleurs
    }
}

/// Grille de la legende (maquette : `grid-template-columns: 1fr 1fr ; gap: 9px 18px`) : deux colonnes
/// de meme largeur, celle du groupe le plus large, et au moins la moitie d'un panneau de 440 pt ; les
/// groupes se rangent deux par deux, dans l'ordre. La maquette borne le panneau a 440 pt, et ses
/// entrees, qui ne passent jamais a la ligne, en debordent quand elles y sont toutes : la grille
/// s'elargit plutot.
struct GrilleLegende: Layout {
    static let largeurPanneau: CGFloat = 440
    /// Marges du panneau, a gauche et a droite.
    static let marges: CGFloat = 24
    static let ecartColonnes: CGFloat = 18
    static let ecartRangs: CGFloat = 9

    /// Largeur des deux colonnes, d'apres la largeur de chaque groupe.
    static func largeurColonne(_ largeurs: [CGFloat]) -> CGFloat {
        max((largeurPanneau - marges - ecartColonnes) / 2, largeurs.max() ?? 0)
    }

    private struct Mise {
        var colonne: CGFloat
        var tailles: [CGSize]
        var rangs: [CGFloat]
    }

    private func mise(_ subviews: Subviews) -> Mise {
        let tailles = subviews.map { $0.sizeThatFits(.unspecified) }
        let rangs = stride(from: 0, to: tailles.count, by: 2).map { i in
            max(tailles[i].height, i + 1 < tailles.count ? tailles[i + 1].height : 0)
        }
        return Mise(colonne: Self.largeurColonne(tailles.map(\.width)), tailles: tailles, rangs: rangs)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let m = mise(subviews)
        return CGSize(width: 2 * m.colonne + Self.ecartColonnes,
                      height: m.rangs.reduce(0, +) + Self.ecartRangs * CGFloat(max(0, m.rangs.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let m = mise(subviews)
        var y = bounds.minY
        for (k, hauteur) in m.rangs.enumerated() {
            for c in 0..<2 where 2 * k + c < subviews.count {
                let i = 2 * k + c
                subviews[i].place(at: CGPoint(x: bounds.minX + CGFloat(c) * (m.colonne + Self.ecartColonnes), y: y),
                                  proposal: ProposedViewSize(m.tailles[i]))
            }
            y += hauteur + Self.ecartRangs
        }
    }

    /// Derniere ligne de base : la plus basse du dernier rang, pour y aligner la ligne de niveau.
    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? {
        guard guide == .lastTextBaseline, !subviews.isEmpty else { return nil }
        let m = mise(subviews)
        let haut = m.rangs.dropLast().reduce(bounds.minY) { $0 + $1 + Self.ecartRangs }
        let dernier = (m.rangs.count - 1) * 2
        return (dernier..<min(dernier + 2, subviews.count)).map { i in
            haut + subviews[i].dimensions(in: ProposedViewSize(m.tailles[i]))[VerticalAlignment.lastTextBaseline]
        }.max()
    }
}

/// « Releve de la sonde ancien » : une petite pastille orange, a cote de la ligne de niveau, quand le
/// releve de la sonde a plus de 6 minutes (polissage B, section 2). Le dessin de la pastille du chef de
/// la fiche (10,5 pt, marges de 2 x 8 pt, capsule teintee a 0,16 au filet de 0,5 pt a 0,5), en orange.
struct PastilleAncien: View {
    var body: some View {
        Text("Relevé de la sonde ancien")
            .font(.system(size: 10.5))
            .foregroundStyle(Palette(sombre: true).appareil(.partitionCoupee))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(Palette(sombre: true).appareil(.partitionCoupee).opacity(0.16)))
            .overlay(Capsule().strokeBorder(Palette(sombre: true).appareil(.partitionCoupee).opacity(0.5), lineWidth: 0.5))
    }
}

extension View {
    /// Fond de la legende (maquette) : le fond de la vue a 0,92, coins de 10 pt, filet de 0,5 pt blanc a
    /// 0,18.
    func fondDeLegende() -> some View {
        background(RoundedRectangle(cornerRadius: 10).fill(Palette.fondLegende))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
    }
}
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    @State private var margeHautMesuree = FenetrePieces.margeHautInitiale
```

par :

```swift
    @State private var margeHautMesuree = FenetrePieces.margeHautInitiale
    /// Hauteur mesuree de la ligne du bas, la legende ouverte ; nil, repliee (la derniere mesure reste
    /// sous une fiche ouverte, qui cache la legende).
    @State private var hauteurLegende: CGFloat?
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    /// Marge du bas de la vue d'ensemble (pt) : la legende et la ligne de niveau (elles debordent un
    /// peu sur la vue, comme la legende du graphe d'avant), ou la fiche ouverte, plus haute avec les
    /// courbes de l'historique (plan 3b) : la vue ne bouge pas d'un noeud a l'autre.
    static func margeBas(fiche: Bool, courbes: Bool) -> CGFloat {
        guard fiche else { return 30 }
        return courbes ? 360 : 190
```

par :

```swift
    /// Marge du bas de la vue d'ensemble (pt) : la fiche ouverte, plus haute avec les courbes de
    /// l'historique (plan 3b), qui cache la legende : la vue ne bouge pas d'un noeud a l'autre ; la legende
    /// ouverte (decision de Djoko du 01/10) : comme en haut, la hauteur mesuree de la ligne du bas (la
    /// legende et la ligne de niveau), le bord et l'espacement, la vue d'ensemble se cadrant au-dessus
    /// d'elle ; sinon 30 pt : la legende repliee et la ligne de niveau debordent un peu sur la vue.
    static func margeBas(fiche: Bool, courbes: Bool, legendeOuverte: CGFloat? = nil) -> CGFloat {
        if fiche { return courbes ? 360 : 190 }
        guard let h = legendeOuverte else { return 30 }
        return max(30, bord + ceil(h) + espacement)
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                                                                courbes: FicheNoeud.courbesVisibles(dans: surveillance))))
```

par :

```swift
                                                                courbes: FicheNoeud.courbesVisibles(dans: surveillance),
                                                                legendeOuverte: hauteurLegende)))
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                    if moteur.selection == nil {
                        HStack(alignment: .center, spacing: 12) {
                            if let entree {
                                LegendeLiens(sonde: entree.maillage != nil, ancien: surveillance.maillageAncien)
                                    .obstacle("legende", moteur)
                            }
                            LigneNiveauVue(ligne: moteur.ligneNiveau)
                                .obstacle("niveau", moteur)
                        }
                    } else {
                        LigneNiveauVue(ligne: moteur.ligneNiveau)
                            .obstacle("niveau", moteur)
                    }
```

par :

```swift
                    LigneDuBas(moteur: moteur, entree: entree, legende: moteur.selection == nil,
                               ancien: surveillance.maillageAncien) { hauteurLegende = $0 }
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
/// Ligne de niveau, en bas a gauche : pieces seules, routeurs, noms masques, piece isolee.
```

par :

```swift
/// Bas a gauche de la fenetre : la legende (cachee sous une fiche ouverte), la ligne de niveau, et la
/// pastille d'un releve de la sonde ancien. La ligne de niveau s'aligne sur la derniere ligne de la
/// legende. Elle garde le repli de la legende, d'un lancement a l'autre, et donne sa hauteur quand la
/// legende est ouverte (nil, repliee) : la marge du bas de la vue d'ensemble (`FenetrePieces.margeBas`).
struct LigneDuBas: View {
    let moteur: MoteurPieces
    let entree: EntreeScene?
    var legende = true
    var ancien = false
    /// Legende repliee ou ouverte, imposee (captures) : la preference n'est alors ni ecrite, ni suivie.
    var legendeForcee: Bool?
    /// Hauteur de la ligne, la legende ouverte ; nil, repliee. Rien sous une fiche, qui cache la legende.
    var surHauteurOuverte: (CGFloat?) -> Void = { _ in }
    @AppStorage(LegendePieces.cleRepliee) private var repliee = false

    var body: some View {
        // Des reperes « ailleurs » sont poses dans une piece isolee (lue avec elle : `isolee`).
        let ailleurs = moteur.isolee != nil && !moteur.textes.ailleurs.isEmpty
        let rubriques = legende ? entree.map { LegendePieces.rubriques(LegendePieces.Lecture($0, ailleurs: ailleurs)) } ?? [] : []
        let estRepliee = legendeForcee ?? repliee
        let ouverte = !rubriques.isEmpty && !estRepliee
        HStack(alignment: .lastTextBaseline, spacing: 12) {
            if !rubriques.isEmpty {
                LegendePieces(rubriques: rubriques, repliee: Binding(get: { estRepliee }, set: { r in
                    if legendeForcee == nil { repliee = r }
                }))
                .obstacle("legende", moteur)
            }
            LigneNiveauVue(ligne: moteur.ligneNiveau)
                .obstacle("niveau", moteur)
            if ancien {
                PastilleAncien()
                    .obstacle("ancien", moteur)
            }
        }
        .onGeometryChange(for: CGFloat?.self) { ouverte ? $0.size.height : nil } action: { h in
            if legende { surHauteurOuverte(h) }
        }
    }
}

/// Ligne de niveau, en bas a gauche : pieces seules, routeurs, noms masques, piece isolee.
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
// la tournee, bandeau de scission, legende des liens, ecran d'attente, appareils IP, « Renommer… ».
```

par :

```swift
// la tournee, bandeau de scission, ecran d'attente, appareils IP, « Renommer… ».
```

Dans `MaillageThread/Vues/Pieces/MorceauxFenetre.swift`, remplacer :

```swift
/// Legende des liens (en bas a gauche, cachee sous une fiche) : avec la sonde,
/// traits pleins (lien radio, colore par la qualite) et pointilles (rattachement
/// suppose) ; « ancien » si la sonde ne repond plus.
struct LegendeLiens: View {
    var sonde = false
    var ancien = false

    var body: some View {
        HStack(spacing: 8) {
            if sonde {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 1))
                    p.addLine(to: CGPoint(x: 22, y: 1))
                }
                .stroke(Palette(sombre: true).lienSonde(3),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 22, height: 2)
                .accessibilityHidden(true)
                Text("lien radio (qualité)")
            }
            Path { p in
                p.move(to: CGPoint(x: 0, y: 1))
                p.addLine(to: CGPoint(x: 22, y: 1))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            .frame(width: 22, height: 2)
            .accessibilityHidden(true)
            Text(sonde ? "rattachement supposé" : "rattachement, pas un lien radio")
            if ancien {
                Text("· relevé de la sonde ancien").foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}

/// Ecran d'attente ou d'erreur, quand il n'y a pas de reseau a dessiner.
```

par :

```swift
/// Ecran d'attente ou d'erreur, quand il n'y a pas de reseau a dessiner.
```

Dans `MaillageThread/Vues/Pieces/Palette.swift`, remplacer :

```swift
    /// Lisere de la sphere : l'alpha de la maquette, force (0,02 + 0,45 (1 - |n.v|)^2,5), ou |n.v| vaut
```

par :

```swift
    // MARK: Legende (polissage B, section 2 ; maquette de la legende)

    /// Fond de la legende : le fond de la vue (son deuxieme arret, rgb(15, 23, 41)) a 0,92.
    static let fondLegende = Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.92)
    /// Texte de la legende : blanc a 0,88 ; titres de ses groupes, gris bleute : rgb(148, 163, 190).
    static let texteLegende = Color(white: 1, opacity: 0.88)
    static let titreLegende = Color(.sRGB, red: 148 / 255, green: 163 / 255, blue: 190 / 255)

    /// Lisere de la sphere : l'alpha de la maquette, force (0,02 + 0,45 (1 - |n.v|)^2,5), ou |n.v| vaut
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
            m.installerMaintenant(e)
```

par :

```swift
            m.installerMaintenant(e)
            // La vue d'ensemble se cadre au-dessus de la legende ouverte : la hauteur mesuree de la ligne du
            // bas, comme dans la fenetre.
            let legende = NSHostingView(rootView: LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false)
                .pourCapture(s, sonde, nomsMaison)).fittingSize.height
            m.marges.bas = FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: legende)
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
/// La vue d'une capture : le fond, la scene, le haut de la fenetre (avec ses trois boutons) et la
/// ligne de niveau, sans horloge ni geste.
```

par :

```swift
/// La vue d'une capture : le fond, la scene, le haut de la fenetre (avec ses trois boutons), la legende
/// ouverte et la ligne de niveau, sans horloge ni geste.
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
                LigneNiveauVue(ligne: moteur.ligneNiveau)
```

par :

```swift
                LigneDuBas(moteur: moteur, entree: moteur.entree, legendeForcee: false)
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh MaillageThreadTests/LegendePiecesTests MaillageThreadTests/FenetrePiecesTests`
Expected: `Test run with 22 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes, en français et en anglais.** Le Step 4 a compilé : mettre le catalogue à jour avec les clés que le compilateur a extraites.

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" outils/synchroniser-textes.sh
```

Expected : `Localizable.xcstrings` reçoit exactement ces 16 clés : « Autres », « Liens radio (qualité) », « Légende », « Relevé de la sonde ancien », « autre partition », « bonne », « candidats », « chef du réseau Thread, élu automatiquement », « inconnue », « moyenne », « non identifié », « parent dans une autre pièce », « partition coupée », « pile », « vers son parent », « → Salon » ; et ces 3, de l'ancienne légende, deviennent périmées : « lien radio (qualité) », « rattachement, pas un lien radio », « · relevé de la sonde ancien ».

Puis les traductions, par ce script, qui retire de `interface.json` les clés de l'ancienne légende, ajoute les nouvelles et garde le fichier trié au format de l'outil ; `outils/traduire.py` retire ensuite du catalogue les clés périmées et donne l'anglais aux nouvelles :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
for cle in ["lien radio (qualité)", "rattachement, pas un lien radio", "· relevé de la sonde ancien"]:
    del d[cle]
d.update({
    "Autres": "Other",
    "Liens radio (qualité)": "Radio links (quality)",
    "Légende": "Legend",
    "Relevé de la sonde ancien": "Probe survey is old",
    "autre partition": "other partition",
    "bonne": "good",
    "candidats": "candidates",
    "chef du réseau Thread, élu automatiquement": "Thread network leader, elected automatically",
    "inconnue": "unknown",
    "moyenne": "medium",
    "non identifié": "unidentified",
    "parent dans une autre pièce": "parent in another room",
    "partition coupée": "split partition",
    "pile": "battery",
    "vers son parent": "to its parent",
    "→ Salon": "→ Living room",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

Expected : aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh`
Expected: `Test run with 346 tests in 36 suites passed` (cœur) et `Test run with 282 tests in 29 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 9 tests et 1 suite de plus pour l'app. Les neuf tests de `LegendePiecesTests`, une suite de plus, s'ajoutent à l'app.

- [ ] **Step 7 : les images de démo, avec la légende.** Elles changent toutes : la légende ouverte en bas à gauche.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polB-t2"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polB/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polB/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
```

Expected : 12 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`) ; « l'app a quitté ».

Regarder `01-2d.png` et `10-3d-isolee-salon.png` : la légende en bas à gauche, quatre groupes en deux colonnes (routeurs, appareils, liens radio, autres), et la vue d'ensemble au-dessus d'elle (aucune pièce dessous, la Buanderie comprise) ; dans la pièce isolée, « parent dans une autre pièce » ; la ligne de niveau sur la dernière ligne de la légende.

- [ ] **Step 8 : commit.**

```bash
git add MaillageThreadTests/LegendePiecesTests.swift MaillageThreadTests/FenetrePiecesTests.swift MaillageThread/Vues/Pieces/LegendePieces.swift MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/Pieces/MorceauxFenetre.swift MaillageThread/Vues/Pieces/Palette.swift MaillageThread/Vues/Pieces/CapturesPieces.swift MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
git commit -m "Remplacer la legende des liens par la legende A contextuelle, repliable et gardee, cadrer la vue au-dessus d'elle ouverte, et poser une pastille quand le releve de la sonde est ancien

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Les apparitions : la fiche et les bandeaux glissent, la vue se relève ; la pastille du chef ; la taille minimale

**Files:**
- Create: `MaillageThread/Vues/Pieces/Apparition.swift`
- Modify: `MaillageThread/Vues/Pieces/FenetrePieces.swift`, `MaillageThread/Vues/Pieces/BandeauPieces.swift`, `MaillageThread/Vues/Pieces/FicheNoeud.swift`, `MaillageThread/Vues/Pieces/Palette.swift`, `MaillageThread/Vues/Pieces/MoteurPieces.swift` (blocs ci-dessous)
- Modify (par les outils) : `MaillageThread/Ressources/Localizable.xcstrings`, `outils/traductions/interface.json`
- Test: `MaillageThreadTests/FenetrePiecesTests.swift`, `MaillageThreadTests/MoteurPiecesTests.swift`

**Interfaces:**
- Consumes :
  - `MoteurPieces.marges`, `pret`, `fige`, `reduire`, `anime`, `reveiller()`, `doitContinuer(_:)`, `poserTaille(_:)`, `image(_:taille:echelle:palette:)`, `EntreeScene.chefs`, `FicheNoeud`, `HautPieces`, existants ;
  - dans les tests : `NomsSceneTests.demoAvecRouteurThread()` (le routeur Thread 45, « rloc:B400 », que la sonde seule connaît), `MoteurPiecesTests.moteur()`, existants.
- Produces :
  - `Apparition` (`.glisse(Edge)`, `.fondu` ; `pour(_:reduire:)`, `duree` = 0,3, `transition`, `animation`, `courbe(_:)`) ; `Glisse` (`Transition`) ;
  - `MoteurPieces.margesDuCadre(_:) -> (haut:bas:)`, `margesEnRoute` et `opaciteMarges` (le fondu, avec « Réduire les animations ») ; `doitContinuer` continue tant que les marges changent ; `poserTaille` les pose tout de suite ;
  - `FicheNoeud.couronne(_:entree:) -> Bool` ; `PastilleChef` ; `Palette.jauneChef`, `texteChef` ;
  - `FenetrePieces.tailleMinimale` (820 × 680) ;
  - le catalogue : 1 texte nouveau.

**La fiche, carte A** (spec, section 3 ; maquette de la fiche). La fiche glisse depuis le bas avec un fondu, en 0,3 s, à l'ouverture comme à la fermeture ; d'un nœud à l'autre, son contenu change sur place ; avec « Réduire les animations », un fondu simple (précision 8). La vue se relève en même temps (précision 7). Le repli et l'ouverture de la légende la recadrent de même (décision de Djoko du 01/10) ; avec « Réduire les animations », par un fondu. Les bandeaux du haut (scission, sans pièces) font de même, depuis le haut (spec, section 1).

**Le chef** : une pastille « 👑 Chef du réseau Thread, élu automatiquement » sous le nom de tout nœud couronné de la scène (précision 14). **La taille minimale** passe à 820 × 680 pt (précision 15) ; le test des noms sans chevauchement prend cette plus petite fenêtre.

**Les images de démo ne changent pas** : elles sont figées (`fige`) et sans fiche.

- [ ] **Step 1 : écrire les tests.** Le test des noms prend la nouvelle taille minimale ; les marges qui glissent ; la taille minimale, les apparitions et la pastille du chef.

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
import MaillageCoeur
```

par :

```swift
@testable import MaillageCoeur
```

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// Ligne de niveau : pieces seules, routeurs, noms masques (un, plusieurs), piece isolee.
```

par :

```swift
    /// Taille minimale de la fenetre : 820 x 680 pt.
    @Test func tailleMinimale() throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let s = Surveillance(mode: .direct, dossier: nil)
        let vue = FenetrePieces(fichierPlaces: nil)
            .environment(s)
            .environment(NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit))
            .environment(SondeMaillage(preferences: p, actif: false))
        #expect(FenetrePieces.tailleMinimale == CGSize(width: 820, height: 680))
        #expect(NSHostingView(rootView: vue).fittingSize == FenetrePieces.tailleMinimale)
    }

    /// La fiche et les bandeaux du haut glissent avec un fondu, en 0,3 s, sur la courbe de la maquette
    /// (`cubic-bezier(.2, .8, .2, 1)`) : la fiche depuis le bas, un bandeau depuis le haut ; avec
    /// « Reduire les animations », un fondu simple.
    @Test func apparitions() {
        #expect(Apparition.pour(.bottom, reduire: false) == .glisse(.bottom))
        #expect(Apparition.pour(.top, reduire: false) == .glisse(.top))
        #expect(Apparition.pour(.bottom, reduire: true) == .fondu)
        #expect(Apparition.pour(.top, reduire: true) == .fondu)
        #expect(Apparition.duree == 0.3)
        #expect(Apparition.courbe(0) == 0 && Apparition.courbe(1) == 1)
        #expect(abs(Apparition.courbe(0.5) - 0.946) < 0.002, "\(Apparition.courbe(0.5))")
        let points = stride(from: 0.0, through: 1, by: 0.05).map(Apparition.courbe)
        #expect(zip(points, points.dropFirst()).allSatisfy { $0 < $1 }, "croissante")
    }

    /// La pastille du chef : sur la fiche d'un noeud couronne, et seulement lui, les memes que la scene
    /// (`EntreeScene.chefs`) : un routeur de bordure (le chef de la demo), un routeur que la sonde seule
    /// connait (le chef de son maillage). La fiche d'un chef a la pastille en plus : elle est plus haute
    /// ou plus large que sans couronne ; celle d'un autre noeud ne change pas.
    @Test func pastilleDuChef() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        for n in e.scene.noeuds {
            #expect(FicheNoeud.couronne(n.id, entree: e) == n.chef, "\(n.id)")
        }
        #expect(FicheNoeud.couronne("Apple TV 4K", entree: e))
        #expect(!FicheNoeud.couronne("Apple TV 4K", entree: nil))
        let (s, _) = try NomsSceneTests.demoAvecRouteurThread()
        let m = try #require(s.maillage)
        let routeurs = m.routeurs.map { r in
            var r = r
            r.chef = r.id == 45
            return r
        }
        s.recevoir(Maillage(date: m.date, partition: m.partition, routeurs: routeurs, liens: m.liens, enfants: m.enfants,
                            signaux: m.signaux), a: s.maintenant)
        let thread = try #require(Self.entree(s))
        #expect(thread.chefs == ["Apple TV 4K", "rloc:B400"], "le chef de la partition, et celui du maillage")
        for n in thread.scene.noeuds {
            #expect(FicheNoeud.couronne(n.id, entree: thread) == n.chef, "\(n.id)")
        }
        func taille(_ id: String, _ e: EntreeScene) -> CGSize {
            let fiche = FicheNoeud(id: id, entree: e, instant: Date(), aRenommer: .constant(nil)) {}
            return NSHostingView(rootView: fiche.environment(s).environment(PiecesChoisies(fichier: nil))).fittingSize
        }
        var sansCouronne = thread
        sansCouronne.chefs = []
        for id in ["Apple TV 4K", "rloc:B400"] {
            let avec = taille(id, thread)
            let sans = taille(id, sansCouronne)
            #expect(avec != sans && avec.width >= sans.width && avec.height >= sans.height, "\(id) : \(avec), \(sans)")
        }
        #expect(taille("HomePod Avant", thread) == taille("HomePod Avant", sansCouronne))
    }

    /// Ligne de niveau : pieces seules, routeurs, noms masques (un, plusieurs), piece isolee.
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
    /// une fenetre de 820 x 560 ou de 1400 x 900, en 2D et en 3D, a k = 0,5, 1 et 2,5 vers le salon (la
    /// piece la plus chargee) : aucun nom pose ne chevauche un autre (hors noms d'etage, poses meme s'ils
    /// chevauchent), tous restent dans le cadre, et aucun ne touche une pastille opaque.
    @Test(arguments: [CGSize(width: 820, height: 560), CGSize(width: 1400, height: 900)], [false, true])
```

par :

```swift
    /// une fenetre de 820 x 680 (la plus petite) ou de 1400 x 900, en 2D et en 3D, a k = 0,5, 1 et 2,5 vers le salon (la
    /// piece la plus chargee) : aucun nom pose ne chevauche un autre (hors noms d'etage, poses meme s'ils
    /// chevauchent), tous restent dans le cadre, et aucun ne touche une pastille opaque.
    @Test(arguments: [CGSize(width: 820, height: 680), CGSize(width: 1400, height: 900)], [false, true])
```

Dans `MaillageThreadTests/MoteurPiecesTests.swift`, remplacer :

```swift
    /// Clic sur une piece : elle s'isole (le fil la nomme) ; sur un appareil : sa fiche ; a cote : la
```

par :

```swift
    /// La vue se releve avec la fiche, au-dessus de la legende ouverte, et descend sous un bandeau : quand
    /// les marges changent, le cadre les rejoint en 0,3 s, sur la courbe de la fiche qui glisse ; l'horloge
    /// tourne jusqu'au bout. Avec « Reduire les animations », par un fondu : la scene s'efface, les marges
    /// sautent a mi-chemin, la scene revient. Tout de suite avant la premiere disposition, et pour une
    /// capture.
    @Test func margesQuiGlissent() throws {
        let avant = MoteurPieces()
        avant.marges = (84, 50)
        #expect(avant.margesDuCadre(0).bas == 50)
        avant.marges = (84, 190)
        #expect(avant.margesDuCadre(0).bas == 190 && !avant.margesEnRoute, "avant la premiere disposition")
        let (m, _) = try Self.moteur()
        let t = MoteurPieces.maintenant()
        #expect(m.margesDuCadre(t).haut == 84 && m.margesDuCadre(t).bas == 50)
        m.marges = (84, 190)
        #expect(m.margesDuCadre(t).bas == 50, "le depart")
        #expect(m.margesEnRoute && m.doitContinuer(t + 0.15))
        let mi = m.margesDuCadre(t + 0.15).bas
        #expect(mi > 50 + 0.9 * 140 && mi < 190, "a mi-temps, presque arrivee : la courbe de la fiche (\(mi))")
        #expect(m.margesDuCadre(t + 0.3).bas == 190 && !m.margesEnRoute)
        m.marges = (84, 50)
        _ = m.margesDuCadre(t + 1)
        let enRoute = m.margesDuCadre(t + 1.1).bas
        #expect(enRoute > 50 && enRoute < 190)
        m.marges = (120, 50)
        let detour = m.margesDuCadre(t + 1.1)
        #expect(detour.haut == 84 && detour.bas == enRoute, "un autre changement repart d'ou il en est")
        #expect(m.margesDuCadre(t + 1.4).haut == 120 && m.margesDuCadre(t + 1.4).bas == 50)
        m.reduire = true
        m.marges = (84, 190)
        #expect(m.margesDuCadre(t + 2).bas == 50 && m.margesEnRoute && m.opaciteMarges == 1,
                "« Reduire les animations » : un fondu")
        #expect(m.margesDuCadre(t + 2.1).bas == 50 && abs(m.opaciteMarges - 1.0 / 3) < 1e-6, "la scene s'efface")
        #expect(m.margesDuCadre(t + 2.2).bas == 190 && abs(m.opaciteMarges - 1.0 / 3) < 1e-6,
                "a mi-chemin, les marges sautent ; la scene revient")
        #expect(m.margesDuCadre(t + 2.3).bas == 190 && m.opaciteMarges == 1 && !m.margesEnRoute)
        m.reduire = false
        m.fige = true
        m.marges = (100, 50)
        #expect(m.margesDuCadre(t + 3).haut == 100 && !m.margesEnRoute, "une capture : tout de suite")
    }

    /// Clic sur une piece : elle s'isole (le fil la nomme) ; sur un appareil : sa fiche ; a cote : la
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/MoteurPiecesTests`
Expected: la compilation des tests de l'app échoue (`FenetrePiecesTests.swift`, `MoteurPiecesTests.swift`), par exemple avec `error: type 'FenetrePieces' has no member 'tailleMinimale'` et `error: cannot find 'Apparition' in scope` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** Les apparitions, puis la fenêtre (la fiche, la taille minimale), les bandeaux, la fiche (la pastille), les couleurs, le moteur (les marges qui glissent, ou se fondent).

`MaillageThread/Vues/Pieces/Apparition.swift` (fichier entier) :

```swift
import SwiftUI

/// Apparition d'un element pose sur la vue (polissage B ; maquette de la fiche, carte A) : la fiche
/// glisse depuis le bas, un bandeau du haut depuis le haut, avec un fondu, en 0,3 s, sur la courbe de
/// la maquette (`cubic-bezier(.2, .8, .2, 1)`) ; ils repartent de meme. Avec « Reduire les
/// animations », un fondu simple.
enum Apparition: Equatable {
    /// Glisse depuis ce bord, de 110 % de sa hauteur, avec un fondu.
    case glisse(Edge)
    case fondu

    static let duree = 0.3

    static func pour(_ bord: Edge, reduire: Bool) -> Apparition {
        reduire ? .fondu : .glisse(bord)
    }

    var transition: AnyTransition {
        switch self {
        case .glisse(let bord): AnyTransition(Glisse(bord: bord))
        case .fondu: .opacity
        }
    }

    var animation: Animation {
        switch self {
        case .glisse: .timingCurve(0.2, 0.8, 0.2, 1, duration: Self.duree)
        case .fondu: .easeInOut(duration: Self.duree)
        }
    }

    /// La courbe de la maquette, `cubic-bezier(.2, .8, .2, 1)` : l'avancement en fonction du temps, de 0
    /// a 1. Le moteur y fait glisser les marges de la vue avec la fiche et les bandeaux.
    static func courbe(_ temps: Double) -> Double {
        if temps <= 0 { return 0 }
        if temps >= 1 { return 1 }
        let x = temps
        func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
            3 * (1 - t) * (1 - t) * t * a + 3 * (1 - t) * t * t * b + t * t * t
        }
        // L'abscisse croit avec t : on la resout par dichotomie.
        var bas = 0.0
        var haut = 1.0
        for _ in 0..<40 {
            let t = (bas + haut) / 2
            if bezier(t, 0.2, 0.2) < x { bas = t } else { haut = t }
        }
        return bezier((bas + haut) / 2, 0.8, 1)
    }
}

/// Glisse depuis un bord, de 110 % de sa hauteur, avec un fondu (maquette : `translateY(110%)`). Le
/// decalage ne touche que le dessin : la place de l'element, et l'obstacle qu'il fait aux noms, sont
/// ceux d'arrivee.
struct Glisse: Transition {
    let bord: Edge

    func body(content: Content, phase: TransitionPhase) -> some View {
        let hors = !phase.isIdentity
        let sens: CGFloat = bord == .top ? -1 : 1
        content
            .visualEffect { c, g in c.offset(y: hors ? sens * 1.1 * g.size.height : 0) }
            .opacity(hors ? 0 : 1)
    }
}
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
    /// Bord des elements poses sur la vue, et ecart entre eux (pt).
```

par :

```swift
    /// Taille minimale de la fenetre (polissage B, section 3) : avec la fiche et ses courbes, la scene
    /// garde environ 230 pt de haut (88 pour 820 x 560, tri du sous-projet A, n° 11).
    static let tailleMinimale = CGSize(width: 820, height: 680)
    /// Bord des elements poses sur la vue, et ecart entre eux (pt).
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                    if let selection = moteur.selection {
```

par :

```swift
                    // La fiche glisse depuis le bas a l'ouverture et a la fermeture (fondu simple avec
                    // « Reduire les animations ») ; d'un noeud a l'autre, son contenu change sur place.
                    if let selection = moteur.selection {
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
                    }
                }
                .padding(Self.bord)
```

par :

```swift
                        .transition(Apparition.pour(.bottom, reduire: reduire).transition)
                    }
                }
                .animation(Apparition.pour(.bottom, reduire: reduire).animation, value: moteur.selection == nil)
                .padding(Self.bord)
```

Dans `MaillageThread/Vues/Pieces/FenetrePieces.swift`, remplacer :

```swift
        .frame(minWidth: 820, minHeight: 560)
```

par :

```swift
        .frame(minWidth: Self.tailleMinimale.width, minHeight: Self.tailleMinimale.height)
```

Dans `MaillageThread/Vues/Pieces/BandeauPieces.swift`, remplacer :

```swift
    let moteur: MoteurPieces
```

par :

```swift
    @Environment(\.accessibilityReduceMotion) private var reduire
    let moteur: MoteurPieces
```

Dans `MaillageThread/Vues/Pieces/BandeauPieces.swift`, remplacer :

```swift
            VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
```

par :

```swift
            // Un bandeau qui parait glisse depuis le haut, et repart de meme (fondu simple avec « Reduire
            // les animations ») ; ce qui est dessous descend avec lui.
            VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
```

Dans `MaillageThread/Vues/Pieces/BandeauPieces.swift`, remplacer :

```swift
                }
                if sansPieces {
                    BandeauSansPieces()
                }
                FilPieces(moteur: moteur)
            }
```

par :

```swift
                        .transition(apparition.transition)
                }
                if sansPieces {
                    BandeauSansPieces()
                        .transition(apparition.transition)
                }
                FilPieces(moteur: moteur)
            }
            .animation(apparition.animation, value: surveillance.reseau?.estScinde == true)
            .animation(apparition.animation, value: sansPieces)
```

Dans `MaillageThread/Vues/Pieces/BandeauPieces.swift`, remplacer :

```swift
        .padding(.trailing, Self.bordDroit)
    }
```

par :

```swift
        .padding(.trailing, Self.bordDroit)
    }

    private var apparition: Apparition { Apparition.pour(.top, reduire: reduire) }
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
    /// Courbes de l'historique sous les colonnes, pour tout noeud, des que l'historique de la
```

par :

```swift
    /// Le noeud est couronne : un chef de la scene du meme rendu (`EntreeScene.chefs`), routeur de
    /// bordure ou noeud que la sonde seule connait ; la fiche couronne les memes noeuds que la scene.
    static func couronne(_ id: String, entree: EntreeScene?) -> Bool {
        entree?.chefs.contains(id) == true
    }

    /// Courbes de l'historique sous les colonnes, pour tout noeud, des que l'historique de la
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
                Text(description).foregroundStyle(.secondary)
```

par :

```swift
                Text(description).foregroundStyle(.secondary)
            }
            if Self.couronne(a.id, entree: entree) {
                PastilleChef()
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
            Text(LibellesNoeuds.inconnu(n, noms: nomsRouteurs)).font(.title3.weight(.semibold))
```

par :

```swift
            Text(LibellesNoeuds.inconnu(n, noms: nomsRouteurs)).font(.title3.weight(.semibold))
            if Self.couronne(n.id, entree: entree) {
                PastilleChef()
            }
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
            HStack(spacing: 6) {
                Circle().fill(.blue).frame(width: 8, height: 8)
```

par :

```swift
            if Self.couronne(r.instance, entree: entree) {
                PastilleChef()
            }
            HStack(spacing: 6) {
                Circle().fill(.blue).frame(width: 8, height: 8)
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
/// Point d'etat de la fiche. Joignable, il pulse doucement : un halo s'elargit
```

par :

```swift
/// « 👑 Chef du reseau Thread, elu automatiquement », sous le nom d'un noeud couronne (polissage B,
/// section 3 ; maquette de la fiche, `.chef`) : 10,5 pt, marges de 2 x 8 pt, en capsule.
struct PastilleChef: View {
    var body: some View {
        Text("👑 Chef du réseau Thread, élu automatiquement")
            .font(.system(size: 10.5))
            .foregroundStyle(Palette.texteChef)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(Palette.jauneChef.opacity(0.16)))
            .overlay(Capsule().strokeBorder(Palette.jauneChef.opacity(0.5), lineWidth: 0.5))
    }
}

/// Point d'etat de la fiche. Joignable, il pulse doucement : un halo s'elargit
```

Dans `MaillageThread/Vues/Pieces/Palette.swift`, remplacer :

```swift
    /// Lisere de la sphere : l'alpha de la maquette, force (0,02 + 0,45 (1 - |n.v|)^2,5), ou |n.v| vaut
```

par :

```swift
    /// Pastille du chef dans la fiche (maquette de la fiche) : capsule jaune a 0,16, filet jaune a 0,5 (le
    /// jaune des liens moyens, rgb(250, 204, 51)), texte rgb(253, 224, 120).
    static let jauneChef = Color(red: 0.98, green: 0.8, blue: 0.2)
    static let texteChef = Color(.sRGB, red: 253 / 255, green: 224 / 255, blue: 120 / 255)

    /// Lisere de la sphere : l'alpha de la maquette, force (0,02 + 0,45 (1 - |n.v|)^2,5), ou |n.v| vaut
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Marges du haut (barre, bandeaux) et du bas (legende, fiche) : la place utile de la vue d'ensemble.
    @ObservationIgnored var marges: (haut: CGFloat, bas: CGFloat) = (0, 0)
```

par :

```swift
    /// Marges du haut (le haut de la fenetre, mesure) et du bas (legende ouverte, fiche), posees par la
    /// vue : la place utile de la vue d'ensemble. Le cadre les rejoint en 0,3 s, sur la courbe de la fiche
    /// qui glisse (`Apparition`) : la vue se releve avec elle, au-dessus de la legende ouverte, ou descend
    /// sous un bandeau ; avec « Reduire les animations », par un fondu.
    @ObservationIgnored var marges: (haut: CGFloat, bas: CGFloat) = (0, 0)
    /// Marges du cadre, et leur glissement en cours vers `marges`.
    @ObservationIgnored private var margesCadre: (haut: CGFloat, bas: CGFloat)?
    @ObservationIgnored private var glissement: GlissementMarges?
    /// Opacite de la scene pendant le fondu des marges (« Reduire les animations ») ; 1 sinon.
    @ObservationIgnored private(set) var opaciteMarges = 1.0
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    /// Fondu de 0,3 s par le fond (« Reduire les animations ») : la scene s'efface, la camera saute a
```

par :

```swift
    /// Glissement des marges du cadre, de `depart` a `arrivee`, depuis `debut` ; `fondu` : avec « Reduire
    /// les animations », un fondu par le fond, les marges sautant a mi-chemin.
    private struct GlissementMarges {
        var depart: (haut: CGFloat, bas: CGFloat)
        var arrivee: (haut: CGFloat, bas: CGFloat)
        var debut: Double
        var fondu: Bool
    }

    /// Fondu de 0,3 s par le fond (« Reduire les animations ») : la scene s'efface, la camera saute a
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        let voulu = CGRect(x: 0, y: marges.haut, width: nouvelle.width,
                           height: max(1, nouvelle.height - marges.haut - marges.bas))
```

par :

```swift
        let now = Self.maintenant()
        let m = margesDuCadre(now)
        let voulu = CGRect(x: 0, y: m.haut, width: nouvelle.width, height: max(1, nouvelle.height - m.haut - m.bas))
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        let now = Self.maintenant()
        if !fige { avancer(now) }
```

par :

```swift
        if !fige { avancer(now) }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        g.opacity = opaciteFondu
```

par :

```swift
        g.opacity = opaciteFondu * opaciteMarges
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
    private func ligne(_ niveau: NiveauZoom, ancres: [CGRect?]) -> LigneNiveau {
```

par :

```swift
    /// Marges du cadre a l'instant `now` : les marges visees, ou en route vers elles pendant 0,3 s quand
    /// elles changent ; avec « Reduire les animations », par un fondu de 0,3 s (la scene s'efface, les
    /// marges sautent a mi-chemin, la scene revient : `opaciteMarges`) ; tout de suite avant la premiere
    /// disposition et pour une capture.
    func margesDuCadre(_ now: Double) -> (haut: CGFloat, bas: CGFloat) {
        let actuelles = margesCadre ?? marges
        let visees = glissement?.arrivee ?? actuelles
        if marges.haut != visees.haut || marges.bas != visees.bas {
            if pret, !fige, margesCadre != nil {
                glissement = GlissementMarges(depart: actuelles, arrivee: marges, debut: now, fondu: reduire)
                // Le glissement demande des images : l'horloge repart, hors du rendu.
                if !anime { Task { @MainActor [weak self] in self?.reveiller() } }
            } else {
                glissement = nil
            }
        }
        guard let g = glissement else {
            margesCadre = marges
            opaciteMarges = 1
            return marges
        }
        let q = min(1, max(0, (now - g.debut) / Apparition.duree))
        let m: (haut: CGFloat, bas: CGFloat)
        if g.fondu {
            m = q < 0.5 ? g.depart : g.arrivee
            opaciteMarges = abs(1 - 2 * q)
        } else {
            let e = CGFloat(Apparition.courbe(q))
            m = (haut: g.depart.haut + (g.arrivee.haut - g.depart.haut) * e,
                 bas: g.depart.bas + (g.arrivee.bas - g.depart.bas) * e)
        }
        if q >= 1 {
            glissement = nil
            opaciteMarges = 1
        }
        margesCadre = m
        return m
    }

    /// Les marges du cadre sont en route.
    var margesEnRoute: Bool { glissement != nil }

    private func ligne(_ niveau: NiveauZoom, ancres: [CGRect?]) -> LigneNiveau {
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        if enMouvement || s != sCible || (attente != nil && geste == nil) { return true }
```

par :

```swift
        if enMouvement || s != sCible || margesEnRoute || (attente != nil && geste == nil) { return true }
```

Dans `MaillageThread/Vues/Pieces/MoteurPieces.swift`, remplacer :

```swift
        cadre = CGRect(x: 0, y: marges.haut, width: nouvelle.width,
```

par :

```swift
        margesCadre = marges
        glissement = nil
        cadre = CGRect(x: 0, y: marges.haut, width: nouvelle.width,
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests MaillageThreadTests/MoteurPiecesTests`
Expected: `Test run with 39 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes, en français et en anglais.** Le Step 4 a compilé : mettre le catalogue à jour avec les clés que le compilateur a extraites.

```bash
DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" outils/synchroniser-textes.sh
```

Expected : `Localizable.xcstrings` reçoit exactement une clé : « 👑 Chef du réseau Thread, élu automatiquement ».

Puis les traductions, par ce script, qui ajoute la nouvelle à `interface.json` et garde le fichier trié au format de l'outil ; `outils/traduire.py` retire ensuite du catalogue les clés périmées et donne l'anglais aux nouvelles :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "👑 Chef du réseau Thread, élu automatiquement": "👑 Thread network leader, elected automatically",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

Expected : aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh`
Expected: `Test run with 346 tests in 36 suites passed` (cœur) et `Test run with 286 tests in 29 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 4 tests de plus pour l'app. Les quatre tests de la tâche s'ajoutent à l'app.

- [ ] **Step 7 : les images de démo, identiques.** Cette tâche ne change pas le rendu des images (figées, sans fiche) : chacune est identique, octet pour octet, à celle de la tâche 2.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polB-t3"
R="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polB-t2"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polB/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polB/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
n=0; for f in "$R"/*.png; do cmp -s "$f" "$D/$(basename "$f")" && n=$((n+1)) || echo "différente : $(basename "$f")"; done; echo "$n identiques sur $(ls "$R" | wc -l | tr -d ' ')"
```

Expected : 12 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`) ; « l'app a quitté » ; « 12 identiques sur 12 ». Si une image diffère, s'arrêter : la tâche a changé le rendu.

- [ ] **Step 8 : commit.**

```bash
git add MaillageThreadTests/FenetrePiecesTests.swift MaillageThreadTests/MoteurPiecesTests.swift MaillageThread/Vues/Pieces/Apparition.swift MaillageThread/Vues/Pieces/FenetrePieces.swift MaillageThread/Vues/Pieces/BandeauPieces.swift MaillageThread/Vues/Pieces/FicheNoeud.swift MaillageThread/Vues/Pieces/Palette.swift MaillageThread/Vues/Pieces/MoteurPieces.swift MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
git commit -m "Faire glisser la fiche et les bandeaux du haut, relever la vue avec eux, couronner le chef dans sa fiche, et porter la fenetre a 820 x 680 au minimum

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Les images et la doc : la fiche du chef et la légende repliée parmi les images de démo ; les specs ; le README

**Files:**
- Modify: `MaillageThread/Vues/Pieces/CapturesPieces.swift`, `MaillageThread/Vues/Pieces/BandeauPieces.swift`, `MaillageThread/Vues/Pieces/FicheNoeud.swift` (blocs ci-dessous)
- Modify: `docs/superpowers/specs/2026-10-01-maillage-thread-polissage-b-design.md` (sections 1, 2 et 5), `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md` (section 8), `README.md`, `README.fr.md` (blocs ci-dessous)
- Test: `MaillageThreadTests/FenetrePiecesTests.swift`

**Interfaces:**
- Consumes :
  - `CapturesPieces`, `VueCapture`, `LigneDuBas`, `FicheNoeud`, `capturePieces`, `StyleBoutonCapsule`, existants ;
  - dans les tests : `NomsSceneTests.demo()`, `FicheNoeud.couronne`, existants.
- Produces :
  - `CapturesPieces.Cas` (`nom`, `poser`, `legendeRepliee`), `CapturesPieces.cas` (quatorze images), `CapturesPieces.piece(_:_:)` ;
  - `VueCapture(moteur:palette:legendeRepliee:)`, qui montre la fiche du nœud choisi ;
  - `View.boutonDeFiche()` ; le fond de la fiche dans une capture ; `fondVerreCapture`, interne ;
  - la spec de B (les décisions de Djoko du 01/10), la spec de la vue par pièces (section 8) et le README, à jour.

**Les images de démo** montrent les deux états nouveaux (spec, section 5) : la fiche ouverte du chef de la démo, avec sa pastille et la vue relevée au-dessus d'elle, et la légende repliée. La fiche y est dessinée comme la maquette (précision 16). Les douze images d'avant ne changent pas. Djoko les regarde à la tâche 5, à côté des maquettes.

**La doc** : la spec de B reçoit les deux décisions de Djoko du 01/10 (section 1 : les capsules centrées sur les boutons ; section 2 : la vue cadrée au-dessus de la légende ouverte ; section 5 : leurs tests et leur vérification) ; la phrase « sans partition en gris » de la spec de la vue par pièces (spec de B, section 2) ; le README (précision 18).

- [ ] **Step 1 : écrire les tests.** Les quatorze images de démo.

Dans `MaillageThreadTests/FenetrePiecesTests.swift`, remplacer :

```swift
    /// Places des pieces : a cote des identites des routeurs, ni en demo ni sous les tests.
```

par :

```swift
    /// Les images de la demo : les douze de la vue par pieces, puis la fiche du chef, avec sa pastille, et
    /// la legende repliee. La fiche est celle d'un noeud couronne de la demo.
    @Test func imagesDeDemo() throws {
        #expect(CapturesPieces.cas.map(\.nom) == [
            "01-2d", "02-envol-30", "03-envol-55", "04-envol-80", "05-3d", "06-3d-tournee", "07-2d-zoom-salon",
            "08-2d-mi-distance", "09-2d-loin", "10-3d-isolee-salon", "11-2d-isolee-chambre", "12-2d-survol",
            "13-2d-fiche-du-chef", "14-2d-legende-repliee",
        ])
        #expect(CapturesPieces.cas.filter(\.legendeRepliee).map(\.nom) == ["14-2d-legende-repliee"])
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces()
        try #require(CapturesPieces.cas.first { $0.nom == "13-2d-fiche-du-chef" }).poser(m, e.scene)
        let choisi = try #require(m.selection)
        #expect(FicheNoeud.couronne(choisi, entree: e))
    }

    /// Places des pieces : a cote des identites des routeurs, ni en demo ni sous les tests.
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests`
Expected: la compilation des tests de l'app échoue (`FenetrePiecesTests.swift`), par exemple avec `error: type 'CapturesPieces' has no member 'cas'` et `error: cannot infer key path type from context; consider explicitly specifying a root type` : `** TEST FAILED **`. Le code de la tâche n'existe pas encore.

- [ ] **Step 3 : écrire le code.** Les images (la marge du bas selon la légende et la fiche), puis le fond du verre des captures, la fiche dans les captures.

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
/// pieces isolees, survol. Sans fenetre ni capture d'ecran ; l'app quitte ensuite. `ImageRenderer` ne
/// rend ni la fenetre ni le verre : le haut de la fenetre y est dessine comme dans la maquette du
/// bandeau (`capturePieces`), avec les trois boutons de la fenetre a leur place (`FeuxDeCapture`).
```

par :

```swift
/// pieces isolees, survol, la fiche du chef, la legende repliee. Sans fenetre ni capture d'ecran ;
/// l'app quitte ensuite. `ImageRenderer` ne rend ni la fenetre ni le verre : le haut de la fenetre et la
/// fiche y sont dessines comme dans les maquettes (`capturePieces`), avec les trois boutons de la
/// fenetre a leur place (`FeuxDeCapture`).
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
    /// Ecrit les images dans `dossier` ; rend leurs noms.
```

par :

```swift
    /// Une image : son nom, l'etat a poser sur le moteur, et la legende repliee.
    struct Cas {
        var nom: String
        var poser: (MoteurPieces, ScenePieces) -> Void
        var legendeRepliee = false
    }

    /// Indice d'une piece de Maison de la scene (la premiere, sans elle).
    static func piece(_ scene: ScenePieces, _ nom: String) -> Int {
        scene.pieces.firstIndex { $0.nom == .maison(nom) } ?? 0
    }

    /// Les images, dans l'ordre : 2D, envol, 3D, zooms, pieces isolees, survol ; puis la fiche du chef de
    /// la demo, avec sa pastille, la vue relevee au-dessus d'elle ; et la legende repliee.
    static let cas: [Cas] = [
        Cas(nom: "01-2d") { _, _ in },
        Cas(nom: "02-envol-30") { m, _ in m.poserBascule(0.3) },
        Cas(nom: "03-envol-55") { m, _ in m.poserBascule(0.55) },
        Cas(nom: "04-envol-80") { m, _ in m.poserBascule(0.8) },
        Cas(nom: "05-3d") { m, _ in m.poserBascule(1) },
        Cas(nom: "06-3d-tournee") { m, _ in
            m.poserBascule(1)
            m.poserAzimut(-1.9)
        },
        Cas(nom: "07-2d-zoom-salon") { m, sc in m.poserZoom(echelle: 2.2, vers: m.centrePiece(piece(sc, "Salon"))) },
        Cas(nom: "08-2d-mi-distance") { m, _ in m.poserZoom(echelle: 0.5, vers: nil) },
        Cas(nom: "09-2d-loin") { m, _ in m.poserZoom(echelle: 0.36, vers: nil) },
        Cas(nom: "10-3d-isolee-salon") { m, sc in
            m.poserBascule(1)
            m.poserIsolement(piece(sc, "Salon"))
        },
        Cas(nom: "11-2d-isolee-chambre") { m, sc in m.poserIsolement(piece(sc, "Chambre")) },
        Cas(nom: "12-2d-survol") { m, _ in m.poserSurvol("9A28601B74FF90A7") },
        Cas(nom: "13-2d-fiche-du-chef") { m, _ in m.selection = "Apple TV 4K" },
        Cas(nom: "14-2d-legende-repliee", poser: { _, _ in }, legendeRepliee: true),
    ]

    /// Ecrit les images dans `dossier` ; rend leurs noms.
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
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
```

par :

```swift
        var noms: [String] = []
        for c in cas {
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
            // bas, comme dans la fenetre.
            let legende = NSHostingView(rootView: LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false)
                .pourCapture(s, sonde, nomsMaison)).fittingSize.height
            m.marges.bas = FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: legende)
            m.poserTaille(taille)
            preparer(m, e.scene)
            // Deux passages : le premier pose les noms, le second les dessine a leur place.
            var image: CGImage?
            for _ in 0..<2 {
                let rendu = ImageRenderer(content: VueCapture(moteur: m, palette: palette)
```

par :

```swift
            // bas, comme dans la fenetre ; repliee, la marge d'avant.
            if !c.legendeRepliee {
                let legende = NSHostingView(rootView: LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false)
                    .pourCapture(s, sonde, nomsMaison)).fittingSize.height
                m.marges.bas = FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: legende)
            }
            m.poserTaille(taille)
            c.poser(m, e.scene)
            if m.selection != nil {
                m.marges.bas = FenetrePieces.margeBas(fiche: true, courbes: false)
                m.poserTaille(taille)
            }
            // Deux passages : le premier pose les noms, le second les dessine a leur place.
            var image: CGImage?
            for _ in 0..<2 {
                let rendu = ImageRenderer(content: VueCapture(moteur: m, palette: palette, legendeRepliee: c.legendeRepliee)
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
            ecrire(image, vers: (dossier as NSString).appendingPathComponent(nom + ".png"))
            noms.append(nom)
```

par :

```swift
            ecrire(image, vers: (dossier as NSString).appendingPathComponent(c.nom + ".png"))
            noms.append(c.nom)
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
/// ouverte et la ligne de niveau, sans horloge ni geste.
struct VueCapture: View {
    let moteur: MoteurPieces
    let palette: Palette
```

par :

```swift
/// (ouverte, ou repliee) et la ligne de niveau, ou la fiche du noeud choisi ; sans horloge ni geste.
struct VueCapture: View {
    @Environment(Surveillance.self) private var surveillance
    let moteur: MoteurPieces
    let palette: Palette
    var legendeRepliee = false
```

Dans `MaillageThread/Vues/Pieces/CapturesPieces.swift`, remplacer :

```swift
            VStack(alignment: .leading) {
                Spacer()
                LigneDuBas(moteur: moteur, entree: moteur.entree, legendeForcee: false)
```

par :

```swift
            VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                Spacer()
                LigneDuBas(moteur: moteur, entree: moteur.entree, legende: moteur.selection == nil,
                           legendeForcee: legendeRepliee)
                if let id = moteur.selection {
                    FicheNoeud(id: id, entree: moteur.entree, instant: surveillance.maintenant,
                               aRenommer: .constant(nil)) {}
                }
```

Dans `MaillageThread/Vues/Pieces/BandeauPieces.swift`, remplacer :

```swift
/// Fond d'une capsule de verre dans une capture : celui de la maquette.
private let fondVerreCapture = Color(.sRGB, red: 40 / 255, green: 48 / 255, blue: 72 / 255)
```

par :

```swift
/// Fond du verre dans une capture (capsules, fiche) : celui des maquettes.
let fondVerreCapture = Color(.sRGB, red: 40 / 255, green: 48 / 255, blue: 72 / 255)
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
                    .buttonStyle(.glass)
                    .help("Fermer")
                    if Self.renommable(id, dans: surveillance) {
                        Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                            .buttonStyle(.glass)
```

par :

```swift
                    .boutonDeFiche()
                    .help("Fermer")
                    if Self.renommable(id, dans: surveillance) {
                        Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                            .boutonDeFiche()
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
```

par :

```swift
        .modifier(FondDeFiche())
```

Dans `MaillageThread/Vues/Pieces/FicheNoeud.swift`, remplacer :

```swift
/// « 👑 Chef du reseau Thread, elu automatiquement », sous le nom d'un noeud couronne (polissage B,
```

par :

```swift
extension View {
    /// Bouton de verre de la fiche ; dans une capture, qui ne rend pas le verre, celui des capsules.
    func boutonDeFiche() -> some View {
        modifier(BoutonDeFiche())
    }
}

private struct BoutonDeFiche: ViewModifier {
    @Environment(\.capturePieces) private var capture

    func body(content: Content) -> some View {
        if capture {
            content.buttonStyle(StyleBoutonCapsule())
        } else {
            content.buttonStyle(.glass)
        }
    }
}

/// Fond de la fiche : du verre aux coins de 22 pt ; dans une capture, celui de la maquette de la fiche
/// (rgba(40, 48, 72, 0,40), filet de 0,5 pt blanc a 0,22, ombre noire a 0,4).
private struct FondDeFiche: ViewModifier {
    @Environment(\.capturePieces) private var capture

    func body(content: Content) -> some View {
        if capture {
            content
                .background(RoundedRectangle(cornerRadius: 22).fill(fondVerreCapture.opacity(0.4))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 8))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
    }
}

/// « 👑 Chef du reseau Thread, elu automatiquement », sous le nom d'un noeud couronne (polissage B,
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh MaillageThreadTests/FenetrePiecesTests`
Expected: `Test run with 17 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : la doc.** La spec de B (les décisions de Djoko du 01/10), celle de la vue par pièces (section 8), puis le README, en anglais et en français.

Dans `docs/superpowers/specs/2026-10-01-maillage-thread-polissage-b-design.md`, remplacer :

```markdown
**Sous la capsule de gauche**, en plus petit et alignés sur elle :
```

par :

```markdown
**Les capsules se centrent sur les trois boutons**, et restent donc collées en haut de la fenêtre : centrées sur des boutons à 16 pt du haut, elles commencent à 1,5 pt du bord (choix de Djoko du 01/10, sur les premières images ; la maquette les pose plus bas, sous des boutons plus petits).

**Sous la capsule de gauche**, en plus petit et alignés sur elle :
```

Dans `docs/superpowers/specs/2026-10-01-maillage-thread-polissage-b-design.md`, remplacer :

```markdown
**Aspect**, comme la maquette A :
```

par :

```markdown
**La vue d'ensemble se cadre au-dessus de la légende ouverte** (choix de Djoko du 01/10, sur les premières images, où la légende cachait des pièces) :
- la marge du bas suit la hauteur **mesurée** de la légende et de la ligne de niveau, comme la marge du haut suit le bandeau ;
- repliée, la légende rend la place : la marge reprend sa valeur d'avant ;
- une fiche ouverte, qui cache la légende, garde ses marges (190 ou 360 pt) ;
- un changement de marge recadre la vue d'ensemble comme aujourd'hui, sauf si Djoko a zoomé ou isolé une pièce. Le repli et l'ouverture la recadrent avec l'animation de la fiche, ou par un fondu avec « Réduire les animations ».

**Aspect**, comme la maquette A :
```

Dans `docs/superpowers/specs/2026-10-01-maillage-thread-polissage-b-design.md`, remplacer :

```markdown
- la marge du haut mesurée ;
```

par :

```markdown
- la marge du haut mesurée ; celle du bas, sous la légende ouverte ;
```

Dans `docs/superpowers/specs/2026-10-01-maillage-thread-polissage-b-design.md`, remplacer :

```markdown
- la légende contextuelle et son repli gardé ;
```

par :

```markdown
- la légende contextuelle et son repli gardé, la vue cadrée au-dessus d'elle ;
```

Dans `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`, remplacer :

```markdown
- **Plusieurs partitions :** couleur des nœuds (principale en bleu, les autres en ambre, sans partition en gris), et bandeau de scission.
```

par :

```markdown
- **Plusieurs partitions :** couleur des nœuds (principale en bleu, les autres en ambre ; un appareil sans partition prend la couleur de son état, comme le dit la légende, correction du polissage B), et bandeau de scission.
```

Dans `README.md`, remplacer :

```markdown
With `-captures <folder>`, the app writes twelve PNG images of the room view
(2D, flight, 3D, zooms, isolated rooms, hover), then quits, with no window.
The app is sandboxed: the folder must be inside its container.
```

par :

```markdown
With `-captures <folder>`, the app writes fourteen PNG images of the room view
(2D, flight, 3D, zooms, isolated rooms, hover, the leader's card, the folded
legend), then quits, with no window. Its renderer draws neither the window nor
glass: the top of the window and the card are drawn as in their mockups, with
the window's three buttons in place. The app is sandboxed: the folder must be
inside its container.
```

Dans `README.md`, remplacer :

```markdown
- **Floors and rooms.** Floors are the Home zones, in their order (the first
```

par :

```markdown
- **The window** has no title bar: the view goes up to the top, under the
  window's three buttons. Two glass capsules sit on their line: the network
  one (network menu, IP devices, Log, refresh) right after the buttons, the
  view one (2D / 3D, slow rotation) against the right edge. Drag the empty
  band between them to move the window; a double-click there does what a
  double-click on a title bar does on your Mac (Desktop & Dock settings). At
  least 820 × 680 points.
- **Legend** at the bottom left: routers, devices, radio links by quality and
  the other signs, only those the view shows. Open, the overview is framed
  above it; it folds to its label, giving the room back, and stays as you left
  it. When the probe's survey is old, an orange tag says so next to the level
  line.
- **Floors and rooms.** Floors are the Home zones, in their order (the first
```

Dans `README.md`, remplacer :

```markdown
- **2D and 3D** (toolbar; the mode is kept from one launch to the next): 2D is
  a top view, floors side by side; 3D stacks them inside the house sphere,
  with a slow rotation you can turn off. Switching is a 2.6 s flight.
```

par :

```markdown
- **2D and 3D** (right capsule; the mode is kept from one launch to the next):
  2D is a top view, floors side by side; 3D stacks them inside the house
  sphere, with a slow rotation you can turn off. Switching is a 2.6 s flight.
```

Dans `README.md`, remplacer :

```markdown
  undone. Click a device or its name: its card.
```

par :

```markdown
  undone. Click a device or its name: its card, which slides up from the
  bottom as the view rises; the card of the Thread network's leader shows
  "👑 Thread network leader, elected automatically".
```

Dans `README.md`, remplacer :

```markdown
  is off.
```

par :

```markdown
  is off, the card and the top banners come and go with a plain fade, and the
  view reframes itself through a fade.
```

Dans `README.md`, remplacer :

```markdown
- A tour every 5 minutes, and on refresh: the refresh button of the toolbar
  rereads the network, starts a tour (unless one is running) and launches
  Passeur Noms; its help tag says which of these it will actually start. While
  a tour runs, a line under the toolbar (and under the split-network banner)
  shows its step, a counter of requests and its duration ("Scan of silent
  routers · 24/48 · 0:42"); its place stays reserved above the view while a
  probe is remembered, so nothing moves when a tour starts or ends.
```

par :

```markdown
- A tour every 5 minutes, and on refresh: the refresh button of the network
  capsule rereads the network, starts a tour (unless one is running) and
  launches Passeur Noms; its help tag says which of these it will actually
  start. While a tour runs, a line under that capsule (above the split-network
  banner) shows its step, a counter of requests and its duration ("Scan of
  silent routers · 24/48 · 0:42"); its place stays reserved while a probe is
  remembered, so nothing moves when a tour starts or ends.
```

Dans `README.fr.md`, remplacer :

```markdown
Avec `-captures <dossier>`, l'app écrit douze images PNG de la vue par pièces
(2D, envol, 3D, zooms, pièces isolées, survol), puis quitte, sans fenêtre.
L'app vit dans un bac à sable : le dossier doit être dans son conteneur.
```

par :

```markdown
Avec `-captures <dossier>`, l'app écrit quatorze images PNG de la vue par
pièces (2D, envol, 3D, zooms, pièces isolées, survol, la fiche du chef, la
légende repliée), puis quitte, sans fenêtre. Son rendu ne dessine ni la
fenêtre ni le verre : le haut de la fenêtre et la fiche y sont dessinés comme
dans leurs maquettes, avec les trois boutons de la fenêtre à leur place. L'app
vit dans un bac à sable : le dossier doit être dans son conteneur.
```

Dans `README.fr.md`, remplacer :

```markdown
- **Étages et pièces.** Les étages sont les zones de Maison, dans leur ordre
```

par :

```markdown
- **La fenêtre** n'a pas de barre de titre : la vue monte jusqu'en haut, sous
  les trois boutons de la fenêtre. Deux capsules de verre sont posées sur leur
  ligne : celle du réseau (menu du réseau, appareils IP, journal, rafraîchir)
  juste après les boutons, celle de la vue (2D / 3D, rotation lente) contre le
  bord droit. Glisser la bande vide entre elles déplace la fenêtre ; un
  double-clic y fait ce que fait un double-clic sur une barre de titre sur ce
  Mac (réglages Bureau et Dock). 820 × 680 points au moins.
- **Légende** en bas à gauche : routeurs, appareils, liens radio par qualité
  et autres signes, seulement ceux que la vue montre. Ouverte, la vue
  d'ensemble se cadre au-dessus d'elle ; elle se replie sur son étiquette, qui
  rend la place, et reste comme on l'a laissée. Quand le relevé de la sonde
  est ancien, une pastille orange le dit, à côté de la ligne de niveau.
- **Étages et pièces.** Les étages sont les zones de Maison, dans leur ordre
```

Dans `README.fr.md`, remplacer :

```markdown
- **2D et 3D** (barre d'outils ; le mode est gardé d'un lancement à l'autre) :
  la 2D est une vue de dessus, les étages côte à côte ; la 3D les empile dans
  la sphère de la maison, avec une rotation lente qu'on peut couper. La
  bascule est un envol de 2,6 s.
```

par :

```markdown
- **2D et 3D** (capsule de droite ; le mode est gardé d'un lancement à
  l'autre) : la 2D est une vue de dessus, les étages côte à côte ; la 3D les
  empile dans la sphère de la maison, avec une rotation lente qu'on peut
  couper. La bascule est un envol de 2,6 s.
```

Dans `README.fr.md`, remplacer :

```markdown
  annulés. Clic sur un appareil ou sur son nom : sa fiche.
```

par :

```markdown
  annulés. Clic sur un appareil ou sur son nom : sa fiche, qui glisse depuis le
  bas pendant que la vue se relève ; la fiche du chef du réseau Thread porte
  « 👑 Chef du réseau Thread, élu automatiquement ».
```

Dans `README.fr.md`, remplacer :

```markdown
  immédiats, la rotation lente est coupée.
```

par :

```markdown
  immédiats, la rotation lente est coupée, la fiche et les bandeaux du haut
  vont et viennent par un simple fondu, et la vue se recadre par un fondu.
```

Dans `README.fr.md`, remplacer :

```markdown
  rafraîchir de la barre d'outils relit le réseau, lance une tournée (sauf
  s'il y en a déjà une) et Passeur Noms ; son aide dit lesquels il lancera
  vraiment. Pendant une tournée, une ligne sous la barre d'outils (et sous le
  bandeau d'un réseau scindé) montre son étape, un compteur de requêtes et sa
  durée (« Balayage des routeurs muets · 24/48 · 0:42 ») ; sa place reste
  gardée au-dessus de la vue tant qu'une sonde est retenue : rien ne bouge au
  début ni à la fin d'une tournée. Réglages › Sonde et la ligne du menu
```

par :

```markdown
  rafraîchir de la capsule du réseau relit le réseau, lance une tournée (sauf
  s'il y en a déjà une) et Passeur Noms ; son aide dit lesquels il lancera
  vraiment. Pendant une tournée, une ligne sous cette capsule (au-dessus du
  bandeau d'un réseau scindé) montre son étape, un compteur de requêtes et sa
  durée (« Balayage des routeurs muets · 24/48 · 0:42 ») ; sa place reste
  gardée tant qu'une sonde est retenue : rien ne bouge au début ni à la fin
  d'une tournée. Réglages › Sonde et la ligne du menu
```

- [ ] **Step 6 : toute la suite.**

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/tester.sh`
Expected: `Test run with 346 tests in 36 suites passed` (cœur) et `Test run with 287 tests in 29 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement ; le cœur inchangé, 1 test de plus pour l'app. Le test de la tâche s'ajoute à l'app.

- [ ] **Step 7 : la suite en anglais.**

```bash
xcodegen generate --quiet && xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" -testLanguage en -testRegion US test > "$HOME/Library/Caches/maillage-polB/maillage-tests-en.log" 2>&1; grep -E "Test run with|\*\* TEST" "$HOME/Library/Caches/maillage-polB/maillage-tests-en.log"
```

Expected: `Test run with 346 tests in 36 suites passed` et `Test run with 287 tests in 29 suites passed`, `** TEST SUCCEEDED **` : les effectifs du Step 6.

- [ ] **Step 8 : les tests Python de la sonde, et les temps.** Ce plan ne touche ni à la sonde ni au cœur : rien ne doit changer.

```bash
python3 -m unittest discover -s sonde/test 2>&1 | tail -3
/usr/bin/python3 -m unittest discover -s sonde/test 2>&1 | tail -3
```

Expected : `Ran 141 tests` puis `OK`, deux fois.

Run: `DD="$HOME/Library/Developer/Xcode/DerivedData/maillage-polB" TMPDIR="$HOME/Library/Caches/maillage-polB/" outils/mesurer.sh`
Expected: `mesure : disposition de la grande maison en 0.254780042 s, 3000 coups` ; `mesure : placement de 150 noms en 0.31428334999999996 ms, 150 poses` ; `mesure : placement de 150 noms tres serres en 2.82565 ms, 30 poses` (ces temps-ci au rejeu, qui varient d'une machine à l'autre ; les coups et les poses, non), puis `Test run with 19 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 9 : les quatorze images de démo.** Les douze d'avant restent identiques, octet pour octet, à celles de la tâche 3 ; deux s'ajoutent.

```bash
D="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polB"
R="$HOME/Library/Containers/fr.djoko.maillage/Data/tmp/captures-polB-t3"
rm -rf "$D"
open -n -g -W "$HOME/Library/Developer/Xcode/DerivedData/maillage-polB/Build/Products/Debug/Maillage Thread.app" --args -demo -captures "$D"
ls "$D"
pgrep -f "maillage-polB/Build/Products/Debug/Maillage Thread.app" || echo "l'app a quitté"
n=0; for f in "$R"/*.png; do cmp -s "$f" "$D/$(basename "$f")" && n=$((n+1)) || echo "différente : $(basename "$f")"; done; echo "$n identiques sur $(ls "$R" | wc -l | tr -d ' ')"
```

Expected : 14 images (`01-2d.png`, `02-envol-30.png`, `03-envol-55.png`, `04-envol-80.png`, `05-3d.png`, `06-3d-tournee.png`, `07-2d-zoom-salon.png`, `08-2d-mi-distance.png`, `09-2d-loin.png`, `10-3d-isolee-salon.png`, `11-2d-isolee-chambre.png`, `12-2d-survol.png`, `13-2d-fiche-du-chef.png`, `14-2d-legende-repliee.png`) ; « l'app a quitté » ; « 12 identiques sur 12 ». Si une image diffère, s'arrêter : la tâche a changé le rendu.

Regarder `13-2d-fiche-du-chef.png` (la fiche de l'Apple TV 4K, sa pastille du chef sous la description, la vue relevée) et `14-2d-legende-repliee.png` (« Légende ⌄ » à côté de la ligne de niveau, la vue rendue à toute la hauteur), à côté des maquettes de la fiche (carte A) et de la légende.

- [ ] **Step 10 : commit.**

```bash
git add MaillageThreadTests/FenetrePiecesTests.swift MaillageThread/Vues/Pieces/CapturesPieces.swift MaillageThread/Vues/Pieces/BandeauPieces.swift MaillageThread/Vues/Pieces/FicheNoeud.swift docs/superpowers/specs/2026-10-01-maillage-thread-polissage-b-design.md docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md README.md README.fr.md
git commit -m "Rendre la fiche du chef et la legende repliee parmi les images de demo, dessiner la fiche dans les captures, et decrire la fenetre et la legende dans le README et la spec

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Vérification avec Djoko (par le contrôleur, pas par un sous-agent)

**Files:** aucun.

**Interfaces:**
- Consumes : tout le plan ; l'app compilée dans le `DD` du plan ; les images de `captures-polB` et les trois maquettes.
- Produces : la vérification de B avec Djoko (spec, section 5), et ses choix sur les points ouverts.

Ce qui ne se voit qu'en vrai : `ImageRenderer` ne rend ni la fenêtre, ni le verre, ni les animations. Chaque action sur l'app de Djoko attend son accord.

- [ ] **Step 1 : les images, à côté des maquettes.** Montrer à Djoko `captures-polB/01-2d.png`, `05-3d.png`, `10-3d-isolee-salon.png`, `13-2d-fiche-du-chef.png` et `14-2d-legende-repliee.png`, à côté des maquettes du bandeau (carte C), de la légende (colonne de droite) et de la fiche (carte A), avec les écarts de ce plan. Le verre et les trois boutons y sont dessinés comme dans les maquettes : le vrai verre se voit au Step 2.
- [ ] **Step 2 : dans l'app.** Recompiler (`outils/tester.sh`, avec le `DD` et le `TMPDIR` du plan), puis, avec lui, quitter l'app qui tourne et lancer celle du `DD` en mode direct : `open "$HOME/Library/Developer/Xcode/DerivedData/maillage-polB/Build/Products/Debug/Maillage Thread.app"`. Avec Djoko :
  1. **Les boutons de la fenêtre et les capsules.** Plus de barre de titre ; les trois boutons sur la scène ; la capsule du réseau juste après eux, sur leur ligne ; celle de la vue contre le bord droit. Le verre ; la capsule à 1,5 pt du bord du haut, comme Djoko l'a gardée. Le titre « Maillage Thread » dans le menu Fenêtre et Mission Control.
  2. **Déplacer la fenêtre** en glissant la bande vide entre les capsules, et seulement là : ailleurs, glisser le fond tourne ou déplace la scène. Fenêtre inactive : le premier glisser la déplace.
  3. **Double-clic sur la bande** : ce que dit le réglage du Mac (Réglages Système › Bureau et Dock › « Double-cliquer sur la barre de titre d'une fenêtre pour ») ; jamais le recadrage de la scène. « Remplir » agrandit (`performZoom`) : est-ce la même chose ?
  4. **Les commandes** : le menu du réseau, « Appareils IP » (sa fenêtre surgissante), « Journal », ⟳ et son aide ; 2D / 3D ; « Rotation lente » (allumée, éteinte, coupée par « Réduire les animations »).
  5. **Les gestes de la scène** : zoom, glisser, isoler une pièce, double-clic sur le fond, clic droit ; inchangés, y compris sous les capsules.
  6. **La fiche qui glisse** : ouverture et fermeture depuis le bas, en 0,3 s, la vue qui se relève avec elle ; d'un nœud à l'autre, pas de nouveau glissement.
  7. **La légende contextuelle** : ses entrées suivent la scène (une pièce isolée ajoute « parent dans une autre pièce ») ; la vue d'ensemble se cadre au-dessus d'elle ; la replier rend la place à la vue, en glissant (en fondu avec « Réduire les animations »), et l'ouvrir la reprend ; zoomé ou une pièce isolée, la vue ne se recadre pas ; quitter, relancer : elle reste comme on l'a laissée.
  8. **La pastille du chef** sur la fiche du chef : routeur de bordure, ou routeur que la sonde seule connaît.
  9. **« Relevé de la sonde ancien »** : la pastille orange à côté de la ligne de niveau, quand la sonde se tait plus de 6 minutes (si l'occasion se présente).
  10. **Une tournée** : sa ligne sous la capsule de gauche ; rien ne bouge au début ni à la fin.
  11. **Le Mac en clair** : la fenêtre reste sombre, capsules et légende comprises.
  12. **« Réduire les animations »** : la fiche et les bandeaux par un simple fondu, la vue recadrée par un fondu, sans glissement.
  13. **La petite fenêtre** : la réduire au minimum (820 × 680) ; avec la fiche et ses courbes, la scène garde environ 230 pt.
  14. **L'annotation des courbes** (spec, section 3 ; tri A, n° 12) : sur une fiche à courbes, « → Nom » d'un changement de parent chevauche-t-il le titre du graphique ? Si oui, elle descend sous le titre (à faire en dehors de ce plan).
  15. **Plein écran** : les trois boutons s'y cachent ; la capsule de gauche garde sa place après eux.
  16. **Retour.** Des comptes seulement, jamais un nom.
- [ ] **Step 3 : rendre l'app.** Quitter l'app du `DD` et relancer l'app habituelle de Djoko, s'il le souhaite. Puis reporter dans les specs, comme au polissage A, les précisions que Djoko valide, et la note de vérification.

---

## Couverture des exigences

| Exigence (spec de B, et brief du plan) | Tâche | Preuve |
|---|---|---|
| Sans barre de titre, par le crochet AppKit ; titre gardé ; les trois boutons restent | 1 | `fenetreSansBarreDeTitre` ; images 01 et 05 ; vérification 1 |
| La capsule de gauche juste après les boutons, centrée sur eux (`standardWindowButton`) ; la droite contre le bord | 1 | `fenetreSansBarreDeTitre` (`CadreFeux`) ; `bandeEntreLesCapsules` ; vérification 1 |
| Commandes d'aujourd'hui, sans changement de comportement | 1 | `rafraichirLanceLePasseurEnModeDirect`, `aideDuBoutonRafraichir`, `barreImmobilePendantUneTournee` ; vérification 4 |
| Sous la capsule de gauche, en plus petit : tournée, scission, sans pièces | 1 | `placeDeLaTournee`, `marges` ; image 01 |
| Déplacer la fenêtre par la bande, et seulement là ; double-clic selon le Mac, jamais le recadrage | 1 | `bandeDeLaFenetre`, `bandeEntreLesCapsules` ; vérifications 2 et 3 |
| Marge du haut mesurée, fonction testable, à la place des valeurs fixes | 1 | `marges` (`margeHaut(bas:)`) |
| Légende A : aspect, quatre groupes, mots, couleurs de `Palette` | 2 | `uneEntreeParSigne`, `groupesEtOrdre`, `exemples`, `colonnes` ; images 01 et 10 |
| Légende contextuelle, fonction pure ; groupe vide, légende vide | 2 | `uneEntreeParSigne`, `groupesEtOrdre`, `legendeDeLaDemo` |
| Repli gardé (`@AppStorage`) | 2 | `repliGarde` ; image 14 ; vérification 7 |
| `LegendeLiens` remplacée ; « Relevé de la sonde ancien » en pastille | 2 | `redessinChaqueMinute`, `pastilleDuReleveAncien` |
| La marge du bas suit la légende ouverte, fonction testable ; repliée, 30 pt ; fiche, 190 ou 360 pt (décision de Djoko) | 2 | `margeDuBas`, `vueAuDessusDeLaLegende` ; image 01 (aucune pièce sous la légende) et 14 |
| Le repli et l'ouverture recadrent avec l'animation de la fiche, ou par un fondu avec « Réduire les animations » | 3 | `margesQuiGlissent` ; vérifications 7 et 12 |
| Les capsules restent centrées sur les boutons (décision de Djoko) | 1 | `fenetreSansBarreDeTitre` ; vérification 1 |
| La fiche glisse en 0,3 s, ouverture et fermeture, pas d'un nœud à l'autre ; fondu avec « Réduire les animations » ; la vue se relève | 3 | `apparitions`, `margesQuiGlissent` ; vérifications 6 et 12 |
| Les bandeaux du haut glissent, ou se fondent | 3 | `apparitions` ; vérification 12 |
| Pastille du chef pour tout nœud de `EntreeScene.chefs` (routeur de bordure, nœud de la sonde) | 3 | `pastilleDuChef` ; image 13 ; vérification 8 |
| Taille minimale 820 × 680 pt | 3 | `tailleMinimale`, `demoSansChevauchement` ; vérification 13 |
| Spec de la vue par pièces, section 8 ; spec de B, les décisions du 01/10 | 4 | blocs des specs |
| Catalogue : tous les textes, avec leur anglais | 2, 3 | `CataloguesTests` ; la suite en anglais |
| Les images de démo : les douze, et les deux états nouveaux | 1 à 4 | `imagesDeDemo` ; `captures-polB` |
| Vérification avec Djoko (spec, section 5) | 5 | Step 2 |
