# Maillage Thread, polissage B : la fenêtre et la légende

Spec du 01/10/2026, validée par Djoko section par section le même jour. Mise à jour le 02/10 avec ses décisions de la vérification en vrai, puis de la revérification (section 6).

## 0. Contexte et décisions

Le polissage suit le plan 4b (vue par pièces). Il se fait en quatre sous-projets, dans l'ordre choisi par Djoko :
- A, mineurs et robustesse (fusionné le 01/10) ;
- **B, la fenêtre et la légende (cette spec)** ;
- C, les étages ;
- D, les gestes et les animations.

Les trois choix visuels de Djoko sont faits sur des maquettes, et **se livrent tels quels** :

| Sujet | Choix | Maquette |
|---|---|---|
| Bandeau | **C** : deux capsules de verre sur une seule ligne | `maquettes/polissage-b-bandeau.html`, carte C |
| Légende | la maquette A du 30/09, adaptée, **avec les mots** | `maquettes/polissage-b-legende.html`, colonne de droite |
| Fiche | **A** : elle glisse depuis le bas | `maquettes/polissage-b-fiche-animee.html`, carte A |

Les maquettes sont des fragments affichés dans le cadre du compagnon visuel. Les noms y sont inventés.

## 1. La fenêtre et le bandeau

**Sans barre de titre.** La fenêtre de la vue par pièces (`Window` « graphe ») n'a plus de barre de titre visible :
- la scène monte jusqu'en haut ;
- les trois boutons de la fenêtre restent posés sur la scène, en haut à gauche ;
- le titre « Maillage Thread » reste celui de la fenêtre, pour Mission Control et le menu Fenêtre, mais il n'est plus affiché.

La scène de la fenêtre porte le style `.windowStyle(.hiddenTitleBar)` : SwiftUI pose lui-même la barre de titre transparente, le titre masqué et `fullSizeContentView`, et les garde à chaque mise à jour de la fenêtre. **Ce qui change (02/10) :** le crochet AppKit d'abord prévu (`SondeFenetre`) posait ces réglages une fois, et SwiftUI les défaisait aussitôt, puis à chaque mise à jour : la barre restait opaque, une bande gris foncé de 32 pt sur les capsules. Le crochet ne gardait que la fenêtre sombre (`assombrir`). **Ce qui change (ronde finale du 02/10) :** SwiftUI défaisait aussi cette apparence sombre, à chaque mise à jour de la fenêtre (relevé dans l'app, en démo) : la fenêtre suivait l'apparence du Mac, et seule la vue était sombre. La vue demande donc l'apparence sombre à SwiftUI (`.preferredColorScheme(.dark)`), qui la pose et la garde ; le crochet est retiré. Les autres fenêtres de l'app ne changent pas.

**Deux capsules de verre, sur une seule ligne**, en haut, au niveau des trois boutons :
- **à gauche**, juste après les trois boutons : le menu du réseau, « Appareils IP · N », « Journal », puis ⟳ (rafraîchir). Ce sont les commandes d'aujourd'hui (`BarreOutils`), sans changement de comportement ;
- **à droite**, contre le bord : 2D / 3D, puis « Rotation lente » en 3D (`CommandesVue`), sans changement de comportement.

Chaque capsule prend la taille de son contenu. Entre les deux, la scène reste visible.

**De l'air en haut** (revérification du 02/10). Une barre d'outils vide et invisible, du style automatique que choisit SwiftUI, comme dans Plans, porte la barre de titre à 52 pt et abaisse les trois boutons : 14 pt, en x = 19, 42 et 65, de 19 à 33 pt du haut. **Les capsules se centrent sur eux**, à 26 pt du haut : leur haut est à 11 pt du bord. Ce sont des vues de l'app, posées sur la scène, et non des éléments de la barre. La barre ne contient qu'un espace souple, sans fond (`.toolbar { ToolbarSpacer(.flexible) }` et `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`) : SwiftUI la garde à chaque mise à jour de la fenêtre, et la bande entre les capsules reçoit toujours ses clics. **Ce qui change :** centrées sur des boutons à 16 pt du haut, les capsules commençaient à 1,5 pt du bord. Djoko avait d'abord choisi de les garder ainsi (01/10, sur les premières images), puis il a annulé ce choix à la revérification.

**Le vrai plein écran** (revérification du 02/10). Le bouton vert passe la fenêtre en plein écran. **Ce qui change :** il ne faisait qu'agrandir la fenêtre, car SwiftUI pose `fullScreenAuxiliary` ou `fullScreenNone` à la fenêtre d'une app de la barre des menus, et `.windowFullScreenBehavior(.enabled)` n'y change rien. La fenêtre reçoit donc `fullScreenPrimary`, et la vue le remet chaque fois que SwiftUI le défait : au lancement, puis à l'entrée et à la sortie du plein écran. En plein écran (ronde finale du 02/10) :
- la barre d'outils invisible se retire, et revient à la sortie. Elle ne sert qu'à abaisser les boutons hors plein écran ;
- les trois boutons se cachent, et ne paraissent qu'au survol du haut, avec la barre des menus, dans la barre de titre du plein écran. Cette barre est sombre, comme la fenêtre ;
- la capsule de gauche prend la place des boutons (décision de Djoko du 02/10) : elle va contre le bord gauche, à 12 pt, la même marge que la capsule de droite contre le bord droit, à la même hauteur, au lieu de garder le vide qu'ils laissent. La barre de titre que le survol du haut fait paraître la couvre le temps du survol : c'est accepté. Hors plein écran, rien ne change : la capsule reste après les boutons. À la sortie, elle y revient ;
- les capsules restent visibles et reçoivent leurs clics.

**Ce qui change :** sur un Mac en clair, le survol du haut faisait descendre une bande blanche, la barre de titre et la barre d'outils, sur la ligne des capsules. Sa fenêtre, à part, prend l'apparence de la fenêtre du graphe, que SwiftUI laissait à celle du Mac : son fond était blanc (relevé dans l'app : 1, 1, 1). Il est maintenant gris très foncé (0,12). La barre d'outils ne paraît de toute façon qu'au survol du haut (`.windowToolbarFullScreenVisibility(.onHover)`) : sinon, sa fenêtre couvrirait les capsules et prendrait leurs clics.

**Sous la ligne des capsules, contre le bord gauche** de la fenêtre, à la marge de la légende (16 pt), en plus petit :
- la ligne de la tournée de la sonde, pendant une tournée seulement ;
- le bandeau de scission, s'il y a lieu ;
- le bandeau « pas encore de pièces de Maison », s'il y a lieu ;
- le fil « Maison » ;
- la ligne de niveau, juste sous le fil (décision de Djoko du 02/10), avec la pastille « relevé de la sonde ancien » à côté d'elle.

**Ce qui change (ronde finale du 02/10) :** ils étaient alignés sous la capsule de gauche, à 92 pt du bord. La ligne de niveau était en bas, à côté de la légende : elle monte dans cette colonne (« Vue d'ensemble : les pièces », « Mi-distance : … », « N noms masqués… », « Pièce isolée : … »). Une seule ligne, coupée par des points de suspension si elle est trop longue : la colonne ne change jamais de hauteur au fil des zooms. Elle garde son style (11 pt, plus pâle). La rangée a toujours la hauteur de la pastille, qu'elle soit là ou non : ni la ligne ni la marge du haut ne bougent quand la pastille paraît ou repart. Cette pastille se fond sur l'animation de conteneur de la colonne : avec « Réduire les animations », elle prend sa place d'un coup.

Un bandeau qui apparaît glisse depuis le haut avec un fondu, en 0,3 s. Il repart de même. Avec « Réduire les animations », c'est un simple fondu. La ligne de la tournée fait de même : quand elle disparaît, le bandeau et le fil remontent ; quand elle paraît, ils redescendent. **Ce qui change (ronde finale du 02/10) :** hors tournée, sa place restait gardée, vide, tant qu'une sonde était retenue (précision 21 du plan 4b).

**Déplacer la fenêtre.** Sans barre de titre, glisser le fond tourne ou déplace la scène. La fenêtre se déplace donc en glissant **la bande vide du haut, entre les deux capsules**, et seulement là. Le double-clic sur cette bande fait ce que fait un double-clic sur une barre de titre selon les réglages du Mac. Sur cette bande, le double-clic de recadrage de la scène ne s'applique donc pas. Ailleurs, les gestes de la scène ne changent pas, avec deux ajouts du 02/10 :
- **le premier clic agit aussi dans une fenêtre inactive** (choix de Djoko) : il active la fenêtre et isole la pièce, ouvre la fiche ou commence un glisser. Avant, macOS gardait ce clic pour activer la fenêtre, et la pièce ne s'isolait qu'au second clic ;
- **un clic sur le nom d'une pièce l'isole** (son étiquette : son nom et le compte de ses appareils), comme un clic sur sa carte ou sa boîte : en 3D, les boîtes sont petites, et l'on clique volontiers sur le nom. Le nom l'emporte sur la boîte d'une autre pièce qu'il recouvre. Un clic sur le nom d'un appareil ouvre toujours sa fiche. Un clic droit sur le nom d'une pièce n'ouvre aucun menu, comme sur sa boîte (avant, il ouvrait celui du fond, « Replacer les pièces automatiquement »). C'est une proposition de la ronde, à confirmer avec Djoko.

**Marge du haut.** La place laissée en haut de la vue d'ensemble suit la hauteur **mesurée** de ce qui est posé en haut : la ligne des capsules, puis la tournée et les bandeaux présents, le fil « Maison » et la ligne de niveau juste dessous (toujours là, de la hauteur de la pastille). Avec de l'air en haut, elle grandit de 20 pt, puis de 21 pt avec la ligne de niveau (4 pt d'écart et la hauteur de la pastille) : 139 pt dans la démo, au lieu de 98. Elle remplace les valeurs fixes d'aujourd'hui (72 pt, plus 40 pour la scission, 40 pour la tournée et 44 sans pièces ; précision 21 du plan 4b). Une marge qui change recadre la vue d'ensemble comme aujourd'hui, sauf si Djoko a zoomé ou isolé une pièce.

**La scène ne bouge pas avec la tournée** (décision de Djoko, ronde finale du 02/10). Tant qu'une sonde est retenue, la marge du haut compte toujours la place d'une ligne de tournée et de son espacement, que la ligne soit montrée ou non : seuls les éléments posés en haut bougent quand elle paraît ou disparaît. Sans cela, la vue d'ensemble se recadrerait au début et à la fin de chaque tournée, toutes les 5 minutes.

## 2. La légende A, adaptée

**Elle remplace la petite légende des liens d'aujourd'hui** (`LegendeLiens`), à la même place, en bas à gauche.

**La vue d'ensemble se cadre au-dessus de tout ce qui est posé en bas** (choix de Djoko du 01/10 pour la légende ouverte, sur les premières images, où la légende cachait des pièces ; du 02/10 pour la fiche) :
- la marge du bas suit la hauteur **mesurée** de la pile du bas, comme la marge du haut suit le bandeau : de haut en bas, la légende, puis la fiche quand elle est ouverte. La ligne de niveau n'y est plus : elle est en haut, dans la colonne de gauche (section 1) ;
- repliée, sans fiche, la légende rend la place : la marge reprend sa valeur d'avant (30 pt) ;
- **une fiche ouverte ne cache plus la légende** (02/10) : la légende reste visible et monte au-dessus de la fiche. Ce qui change : avant, elle disparaissait sous la fiche, qui gardait des marges fixes de 190 ou 360 pt ; ces valeurs fixes disparaissent ;
- un changement de marge recadre la vue d'ensemble comme aujourd'hui, sauf si Djoko a zoomé ou isolé une pièce ;
- **le repli et l'ouverture de la légende durent 0,45 s** (02/10 : Djoko trouvait l'ouverture « un poil trop fugace » à 0,3 s) : le panneau paraît depuis l'étiquette, en bas à gauche, avec un fondu et un léger grossissement, sur la courbe de la fiche, et le recadrage qui l'accompagne prend la même durée. La fiche et les bandeaux restent à 0,3 s. Avec « Réduire les animations », la règle ne change pas : un fondu pour ce qui paraît ou disparaît, la vue recadrée par un fondu, et rien ne glisse.

**Petite fenêtre** (02/10). Sous une fiche ouverte, si la légende ouverte ne laissait à la scène que moins de **230 pt**, elle se replie d'elle-même, tant que la fiche est ouverte, et se rouvre à sa fermeture. Elle ne se replie que si c'est nécessaire, et son repli gardé ne change pas ; un clic sur son étiquette la rouvre pour cette fiche. Le seuil est la hauteur que la section 3 garde à la scène dans la plus petite fenêtre, avec la fiche et ses courbes : environ 230 pt. Mesuré sur la démo, avec une marge du haut de 139 pt (de l'air en haut, le fil et la ligne de niveau ; mesures refaites le 02/10 après la ligne de niveau montée sous le fil) :
- fenêtre par défaut (1100 × 760) : sous la fiche de l'Apple TV 4K, la légende ouverte laisse 250 pt à la scène, et reste ouverte, comme sous 20 des 31 fiches de la démo (235 pt de scène au moins) ; sous les 11 autres (de 143 à 179 pt), elle n'en laisserait que 183 à 219 : elle se replie, et la scène retrouve 380 à 416 pt. Avec les courbes de l'historique, elle se replie aussi. Sans fiche, la scène a 372 pt, la légende ouverte (591 pt, repliée) ;
- plus petite fenêtre (820 × 732 pt, soit 680 pt sous la barre de titre cachée) : sous la fiche de l'Apple TV 4K et sous la plus haute (179 pt), elle laisserait 184 et 155 pt ; elle se replie, comme sous 28 autres fiches (elle ne reste ouverte que sous la plus courte, de 88 pt), et la scène garde 381 et 352 pt. Sans fiche, la scène a 344 pt, la légende ouverte (563 pt, repliée). Avec la fiche et ses courbes (284 à 292 pt de haut, la légende repliée), elle garde 234 pt.
- la ligne de niveau a coûté 21 pt de scène dans toutes les fenêtres (Djoko a validé le rendu en vrai, sans agrandir la fenêtre minimale) : avant, le seuil ne repliait la légende que sous 3 fiches sur 31 dans la fenêtre par défaut (sous 28 fiches, elle restait ouverte), et sous 20 sur 31 dans la plus petite.

**Aspect**, comme la maquette A, sauf le fond :
- **en Liquid Glass** (02/10), le verre des capsules du haut, en rectangle aux coins de 10 pt. Ce qui change : la maquette A dessine un panneau sombre (le fond de la vue à environ 92 %, filet de 0,5 px blanc à environ 18 %). Djoko choisit cet écart à la maquette en connaissance de cause. Le texte, clair, reste lisible sur la scène sombre. Les images de démo, qui ne rendent pas le verre, le dessinent comme celui des capsules ;
- texte d'environ 11 pt ;
- en-tête « Légende » avec un chevron, qui montre ce que fait un clic (revérification du 02/10, choix de Djoko) : vers le bas (⌄) quand la légende est ouverte, pour la replier ; vers le haut (⌃) quand elle est repliée, pour l'ouvrir. C'est l'inverse de la maquette A. Le chevron est un symbole, centré sur la ligne de l'étiquette : le caractère ⌄ de la maquette tombait 3,5 pt trop bas.

La disposition, les groupes, les entrées, l'en-tête, le repli gardé et le contexte ne changent pas.

Repliée, il ne reste que l'étiquette « Légende ». Son état, replié ou ouvert, est gardé d'un lancement à l'autre.

**Quatre groupes en grille 2 × 2**, aux titres discrets, gris bleuté. Les couleurs sont celles de `Palette`.

**Les signes sont dessinés comme dans la scène** (02/10), par les mêmes fonctions que le rendu (`DessinNoeud`, `RenduCanvas`). Ce qui change : la maquette A les dessine en points plats et en traits, et le routeur s'y confondait avec la pastille d'une pièce.
- Un nœud a la taille d'un nœud de la scène dans la vue d'ensemble (celle de la démo à la taille des images, 1440 × 900, en 2D), au plus la hauteur d'une ligne de la légende : 6,9 pt de rayon pour un routeur, 3,7 pt pour un appareil.
- Les liens ont l'épaisseur, la couleur, le trait et l'opacité d'un lien au repos dans la scène.

| Groupe | Entrée | Signe |
|---|---|---|
| Routeurs | routeur | sphère brillante bleue, avec halo et reflet |
| | non identifié | la même sphère, grise |
| | autre partition | la même sphère, ambre |
| | chef du réseau Thread, élu automatiquement | 👑, le glyphe des noms de la scène, sans leur pastille sombre |
| Appareils | joignable | pastille verte, avec son halo |
| | partition coupée | pastille orange |
| | sans adresse | pastille rouge |
| | disparu | anneau rouge |
| | endormi | ☾, de même, sans pastille |
| | pile | pastille orange « ⚠ 12 % », lumineuse, comme dans la scène |
| Liens radio (qualité) | bonne | trait vert de 2 pt, bouts ronds |
| | moyenne | trait jaune de 2 pt |
| | faible | trait orange de 2 pt |
| | inconnue | trait gris de 2 pt |
| Autres | vers son parent | trait d'un pixel, blanc à 0,28, comme le lien enfant → parent |
| | rattachement supposé | pointillé blanc à 0,28 |
| | parent dans une autre pièce | repère « → Salon », bordé de tirets |
| | candidats | nom « A ou B · 0400 » |

**Écarts à la maquette A du 30/09**, et seulement ceux-là :
- les liens radio sont tous en 2 pt, et seule la couleur dit la qualité. Les mots remplacent les chiffres 3, 2 et 1 ;
- « partition » (cercle de zone) est retirée, car la vue par pièces n'en dessine pas ;
- « vers son parent » et « parent dans une autre pièce » sont ajoutés ;
- le texte du chef est celui validé le 01/10 ;
- le fond en verre, au lieu du panneau sombre (02/10) ;
- les signes dessinés comme dans la scène (02/10) ;
- le chevron inversé, ⌄ ouverte et ⌃ repliée (revérification du 02/10) ;
- 👑 et ☾ sans la pastille sombre des noms (revérification du 02/10). Dans la scène, les noms la gardent ;
- 👑 et ☾ centrés sur la place d'un nœud de leur groupe, un routeur pour la couronne, un appareil pour la lune : leurs textes s'alignent sur ceux des autres signes (ronde finale du 02/10). Ils étaient décalés d'environ 3,5 pt vers la droite. Seule la pastille d'une pile, plus large, garde sa place.

**Contextuelle.** Une entrée n'est montrée que si la scène affichée la contient :
- « autre partition » s'il y a plus d'une partition ;
- « pile » s'il y a une pastille de pile ;
- « endormi » s'il y a un ☾ ;
- une qualité de lien si un lien radio de cette qualité est tracé ;
- « parent dans une autre pièce » si un repère « ailleurs » est posé ;
- et ainsi de suite.

Un groupe sans entrée disparaît. Une légende sans aucune entrée n'est pas montrée.

**« Relevé de la sonde ancien »**, que la petite légende d'aujourd'hui montrait en orange, sort de la légende. Il devient une petite pastille orange, à côté de la ligne de niveau (en haut à gauche, section 1), quand le relevé de la sonde est ancien.

**Spec de la vue par pièces, section 8.** La phrase « sans partition en gris » est corrigée : couleur des routeurs (principale en bleu, les autres en ambre, un routeur que la sonde seule connaît en gris). Un appareil prend la couleur de son état, comme le dit la légende.

## 3. La fiche

**Apparition.** La fiche d'un nœud glisse depuis le bas, avec un fondu, en 0,3 s. La vue se relève en même temps pour lui laisser la place : la marge du bas suit la pile mesurée, la légende au-dessus de la fiche (section 2). Ce qui change (02/10) : avant, la fiche cachait la légende et prenait une marge fixe de 190 ou 360 pt. À la fermeture, elle repart vers le bas. Passer d'une fiche à une autre ne la refait pas glisser : son contenu change sur place. Avec « Réduire les animations », elle apparaît et disparaît par un simple fondu.

**Le chef.** Sur la fiche d'un routeur couronné, une pastille « 👑 Chef du réseau Thread, élu automatiquement » se pose sous le nom. Cela vaut pour un routeur de bordure comme pour un routeur que seule la sonde connaît. La fiche lit les chefs de la scène (`EntreeScene.chefs`, polissage A) : elle couronne exactement les mêmes nœuds que la scène.

**Taille minimale.** La fenêtre ne descend pas sous **820 × 732 pt**, soit 680 pt sous la barre de titre cachée, de 52 pt avec la barre d'outils invisible (avant : 820 × 560 pt sous la barre de titre, alors visible ; 820 × 712 pt avant l'air en haut). Avec la fiche et ses courbes, la scène garde ainsi environ 230 pt de haut (234 mesurés, la légende repliée, ligne de niveau comprise), contre 88 aujourd'hui (tri A, n° 11). Sans fiche, elle en garde 344, la légende ouverte (563 pt, repliée).

**À vérifier avec Djoko** (tri A, n° 12). L'annotation « → Nom » d'un changement de parent, au-dessus des courbes, peut chevaucher le titre du graphique. Si c'est le cas à l'écran, elle descend sous le titre.

## 4. Hors de B

- **C :** une zone au même niveau qu'un étage ; la 2D en grille ; isoler un étage ; et les n° 8 et 9 du tri A.
- **D :** ⌥ + glisser ; un appareil qui glisse d'une pièce à l'autre ; un étage qui se réarrange après un changement d'état (n° 6 du tri A) ; la molette et Échap (n° 7).

## 5. Tests et vérification

**Tests.** Ils passent en français et en anglais. Tous les textes sont au catalogue.
- les entrées de la légende selon la scène : une scène inventée par cas, une entrée par signe, et un groupe vide qui disparaît ;
- le repli gardé ;
- la pastille du chef, sur un routeur de bordure et sur un routeur de la sonde, mêmes chefs que la scène ;
- la marge du haut mesurée ; celle du bas, mesurée elle aussi, fiche ouverte ou fermée, légende ouverte ou repliée ;
- la taille minimale de la fenêtre ;
- les capsules du haut : chacune à la largeur de son contenu, même à la taille minimale de la fenêtre, en 2D et en 3D (la bande vide prend la place qui reste) ;
- ajoutés à la ronde finale du 02/10 : la colonne de gauche au bord, la tournée sans place réservée, le bandeau et le fil qui remontent, la marge du haut inchangée à la fin d'une tournée (`tourneeSansPlaceReservee`) et à son apparition, une sonde déjà retenue (`tourneeQuiParaitSansBouger`) ; en plein écran, la barre d'outils retirée puis rendue, et la capsule de gauche au bord, puis de nouveau après les boutons (`pleinEcran`) ; la ligne de niveau sous le fil, à gauche, une seule ligne, la marge du haut stable au fil des zooms, d'une pièce isolée et de la pastille (`ligneDeNiveauSousLeFil`, `ligneDeNiveauSurUneLigne`, `pastilleDuReleveAncien`), la pastille qui part sans délai avec « Réduire les animations » (`pastilleDuHautPrendSaPlaceAvecReduire`), la marge du bas qui ne compte que la légende (`rangeeDuBasAGauche`, `margeDuBas`) ; la fenêtre sombre demandée à SwiftUI ; les textes de 👑 et ☾ alignés (`couronneEtLuneAlignees`) ;
- ajoutés à la revérification du 02/10 : la barre d'outils invisible, les boutons abaissés et la marge du haut qui suit (`deLAirEnHaut`) ; le plein écran gardé (`pleinEcran`) ; le chevron selon l'état, et son centrage, lus sur l'encre du rendu ; 👑 et ☾ sans pastille ; le menu de la barre qui se referme après « Ouvrir le graphe » et « Journal… » ;
- ajoutés le 02/10 : la scène du graphe sans barre de titre (son style) ; le premier clic dans une fenêtre inactive ; le clic sur le nom d'une pièce, en 2D et en 3D ; la légende au-dessus de la fiche ; son repli faute de place, le repli gardé intact ; ses signes dessinés par les fonctions de la scène, et leur taille ; la durée de 0,45 s, de la légende et de son recadrage.

**Captures de démo.** Elles changent toutes, puisque la fenêtre change, et deux images s'y ajoutent : la fiche du chef, avec sa pastille, et la légende repliée (quatorze en tout). Les nouvelles sont montrées à Djoko à côté des maquettes.

**Avec Djoko, à la fin :**
- déplacer la fenêtre par la bande du haut ;
- les capsules, centrées sur les trois boutons abaissés, à 11 pt du bord ;
- les gestes de la scène ;
- la fiche qui glisse ;
- la légende contextuelle et son repli gardé, la vue cadrée au-dessus d'elle ;
- la pastille du chef ;
- le Mac en clair ;
- « Réduire les animations » ;
- la petite fenêtre, avec ses capsules entières ;
- l'annotation des courbes.

**Ronde finale du 02/10, à voir en vrai** (section 6) : la colonne de gauche au bord, avec la ligne de niveau sous le fil ; une tournée qui paraît et disparaît, la scène immobile ; le plein écran, sur un Mac en clair : la capsule contre le bord gauche, et le survol du haut qui la couvre le temps du survol ; 👑 et ☾ alignés.

**Vérification du 02/10, à refaire en vrai** (section 6) : la barre de titre transparente et le plein écran ; le premier clic dans une fenêtre inactive ; le clic sur le nom d'une pièce ; la légende en verre et ses signes ; son ouverture en 0,45 s ; la légende au-dessus de la fiche, et son repli dans la petite fenêtre.

## 6. Vérification du 02/10 : les décisions de Djoko

La vérification en vrai a trouvé deux défauts, et Djoko a demandé quatre retouches de la légende. Chaque point dit ce qui change ; le détail est dans les sections 1 à 3.
- **La barre de titre** (section 1) : elle restait opaque, car SwiftUI défaisait le crochet AppKit. Elle passe par le style de la scène, `.hiddenTitleBar`, que SwiftUI garde.
- **Le premier clic** (section 1) : il agit aussi dans une fenêtre inactive, au lieu de seulement l'activer.
- **Le nom d'une pièce** (section 1) : un clic sur lui isole la pièce, et un clic droit n'ouvre aucun menu, comme sur la boîte. Proposé par la ronde, à confirmer avec Djoko.
- **La légende en verre** (section 2) : au lieu du panneau sombre de la maquette A, un écart choisi par Djoko.
- **Ses signes comme dans la scène** (section 2) : la sphère brillante du routeur, les pastilles, l'anneau, la couronne, la lune, la pastille de pile et les liens de la scène, par les mêmes fonctions.
- **Son ouverture et son repli** (section 2) : 0,45 s au lieu de 0,3 s, avec le recadrage qui les accompagne.
- **La légende au-dessus de la fiche** (sections 2 et 3) : elle reste visible, la marge du bas suit la pile mesurée au lieu des 190 et 360 pt fixes, et elle se replie d'elle-même dans une fenêtre trop basse (seuil de 230 pt).

### Revérification du 02/10

Djoko a revérifié la fenêtre en vrai et demandé cinq retouches. Chaque point dit ce qui change ; le détail est dans les sections 1 et 2.
- **De l'air en haut** (section 1) : une barre d'outils vide et invisible abaisse les trois boutons, et les capsules, centrées sur eux, ont leur haut à 11 pt du bord, au lieu de 1,5 pt. Djoko annule son choix du 01/10 de les garder collées en haut. La marge du haut, mesurée, grandit de 20 pt, et la fenêtre minimale passe à 820 × 732 pt.
- **Le vrai plein écran** (section 1) : le bouton vert passe en plein écran, au lieu d'agrandir la fenêtre. En plein écran, la barre d'outils ne paraît qu'au survol du haut (la capsule de gauche : voir la ronde finale, où elle prend la place des boutons).
- **Le chevron de la légende** (section 2) : vers le bas ouverte, vers le haut repliée, à l'inverse de la maquette A ; centré sur la ligne de l'étiquette repliée.
- **👑 et ☾ dans la légende** (section 2) : sans la pastille sombre des noms, « une ombre disgracieuse et inutile ». Dans la scène, les noms la gardent.
- **Le menu de la barre** : « Ouvrir le graphe » et « Journal… » le referment, comme « Réglages… » depuis le 30/09. L'app inactive, il restait ouvert.

La vérification dans l'app, en démo et en instance à part, avec des relevés de la fenêtre à 0,2, 1, 3 et 6 s, puis après une activation et un passage en plein écran, a montré :
- la barre transparente et la barre d'outils, toujours en place ;
- les boutons abaissés et les capsules alignées sur eux ;
- la bande entre les capsules qui reçoit ses clics ;
- le plein écran gardé, et la fenêtre de la barre d'outils qui ne couvre plus les capsules au repos (au survol du haut, voir la ronde finale).

Le verre et le survol du haut en plein écran restent à juger à l'écran.

### Ronde finale du 02/10

Après la troisième vérification en vrai, Djoko a demandé quatre retouches. Le détail est dans les sections 1 et 2.
- **La colonne de gauche au bord** (section 1) : la ligne de la tournée, les bandeaux et le fil « Maison » vont contre le bord gauche de la fenêtre, à 16 pt comme la légende et la ligne de niveau, et non plus sous la capsule de gauche.
- **La tournée sans place réservée** (section 1) : sa ligne n'est là que pendant la tournée. Le bandeau et le fil remontent quand elle disparaît, et redescendent quand elle paraît, avec l'animation des bandeaux. **La scène, elle, reste stable** : la marge du haut compte toujours la place de la ligne tant qu'une sonde est retenue. Sans cela, la vue d'ensemble se recadrerait à chaque tournée, toutes les 5 minutes.
- **Le plein écran** (section 1) : la barre d'outils invisible se retire, la barre de titre que le survol fait paraître est sombre, et la capsule de gauche prend la place des boutons, contre le bord gauche (décision de Djoko du 02/10, qui a préféré cela au vide laissé après eux : un premier essai l'avait gardée après les boutons, ce qui laisse un vide). Sur un Mac en clair, le survol faisait descendre une bande blanche sur les capsules. La cause de la bande : SwiftUI défaisait l'apparence sombre de la fenêtre, que la barre du plein écran reprend. La fenêtre la demande donc à SwiftUI (`.preferredColorScheme(.dark)`).
- **👑 et ☾ alignés** (section 2) : leurs textes commencent avec ceux des autres signes de leur groupe.

La vérification dans l'app, en démo et en instance à part, avec un passage en plein écran, a montré :
- la barre d'outils retirée en plein écran, sans que SwiftUI la remette, puis rendue à la sortie, avec les boutons de nouveau à 19, 42 et 65 pt ;
- la fenêtre et la barre de titre du plein écran en apparence sombre, le fond de cette barre à 0,12 au lieu de 1 ;
- la capsule de gauche à {92, 11} avant et après le plein écran (cette position précède la décision de Djoko : en plein écran, elle va désormais à 12 pt), et ses clics reçus par la fenêtre du graphe ;
- les fenêtres de la barre des menus inchangées.

La barre de titre du plein écran reste opaque : au survol du haut, elle couvre encore le haut des capsules, en sombre, le temps du survol. Aucune API publique ne la rend transparente. Le survol lui-même reste à juger à l'écran.

### Retouche du plein écran et ligne de niveau en haut (02/10, après la 4e vérification)

Djoko a décidé deux retouches. Le détail est dans la section 1.
- **En plein écran, la capsule de gauche prend la place des boutons** : contre le bord gauche, à 12 pt, comme la capsule de droite contre le bord droit. La barre de titre que le survol du haut fait paraître la couvre le temps du survol : c'est accepté. Hors plein écran, rien ne change. Quand le bouton vert est pressé, `SuiviFenetre` donne aux boutons un cadre « caché » (`CadreFeux.pleinEcran`), et la capsule suit. Comme SwiftUI remet la barre d'outils à jour, et la rend visible, quand la capsule change de place, `SuiviFenetre` la retire de nouveau tant que la fenêtre est en plein écran (observation de `toolbar.isVisible`).
- **La ligne de niveau monte en haut à gauche**, sous le fil « Maison », dans la colonne de gauche, avec la pastille « relevé de la sonde ancien ». Une seule ligne, coupée par des points de suspension si elle est trop longue ; style inchangé. Le bas ne garde que la légende : la marge du bas suit la légende seule, ou la légende et la fiche. La marge du haut compte la ligne de niveau, qui est toujours là, et reste stable au fil des zooms et des tournées : la rangée a la hauteur de la pastille, qu'elle soit là ou non. Les obstacles des noms de la scène suivent les nouvelles places.

### Dernière ronde du 02/10 (après la 5e relecture)

- **La sortie du plein écran ne laisse plus la capsule sur les boutons.** `SuiviFenetre` garde le dernier cadre des boutons lu hors plein écran. Si la lecture rate à la sortie (les boutons ne sont pas encore revenus dans la fenêtre), la capsule de gauche retrouve ce cadre au lieu de rester au bord, sur eux ; une seconde lecture, 0,25 s plus tard, corrige une valeur de passage. Une vue remise dans une autre fenêtre repart hors plein écran.
- **Les mesures de la petite fenêtre sont refaites** (section 2) avec la marge du haut de 139 pt ; la fenêtre minimale ne change pas. La scène y garde 344 pt sans fiche et 234 pt avec la fiche et ses courbes, mais la légende se replie sous presque toutes les fiches (30 sur 31).

### Vérifié avec Djoko le 02/10 (fin de B)

Après cinq vérifications en vrai, toutes les demandes sont tenues :
- la fenêtre sans barre de titre, avec de l'air en haut ;
- les deux capsules ;
- la bande qui déplace la fenêtre et son double-clic ;
- le vrai plein écran, avec la capsule de gauche au bord et une barre sombre au survol ;
- la colonne de gauche contre le bord, avec la tournée sans place réservée et une scène stable ;
- la ligne de niveau sous « Maison » ;
- la légende en verre, avec les signes de la scène, une ouverture en 0,45 s, le chevron inversé et centré, 👑 et ☾ sans pastille, et la légende au-dessus de la fiche ;
- le premier clic qui agit, et le nom d'une pièce qui l'isole ;
- le menu de la barre qui se referme sur « Ouvrir le graphe » et « Journal… ».

Restent pour la suite :
- isoler une zone (C) ;
- ⌥ + glisser (D).
