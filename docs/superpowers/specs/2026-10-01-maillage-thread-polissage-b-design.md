# Maillage Thread, polissage B : la fenêtre et la légende

Spec du 01/10/2026, validée par Djoko section par section le même jour. Mise à jour le 02/10 avec ses décisions de la vérification en vrai (section 6).

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

La scène de la fenêtre porte le style `.windowStyle(.hiddenTitleBar)` : SwiftUI pose lui-même la barre de titre transparente, le titre masqué et `fullSizeContentView`, et les garde à chaque mise à jour de la fenêtre. **Ce qui change (02/10) :** le crochet AppKit d'abord prévu (`SondeFenetre`) posait ces réglages une fois, et SwiftUI les défaisait aussitôt, puis à chaque mise à jour : la barre restait opaque, une bande gris foncé de 32 pt sur les capsules. Le crochet ne garde que la fenêtre sombre (`assombrir`). Les autres fenêtres de l'app ne changent pas.

**Deux capsules de verre, sur une seule ligne**, en haut, au niveau des trois boutons :
- **à gauche**, juste après les trois boutons : le menu du réseau, « Appareils IP · N », « Journal », puis ⟳ (rafraîchir). Ce sont les commandes d'aujourd'hui (`BarreOutils`), sans changement de comportement ;
- **à droite**, contre le bord : 2D / 3D, puis « Rotation lente » en 3D (`CommandesVue`), sans changement de comportement.

Chaque capsule prend la taille de son contenu. Entre les deux, la scène reste visible.

**Les capsules se centrent sur les trois boutons**, et restent donc collées en haut de la fenêtre : centrées sur des boutons à 16 pt du haut, elles commencent à 1,5 pt du bord (choix de Djoko du 01/10, sur les premières images ; la maquette les pose plus bas, sous des boutons plus petits).

**Sous la capsule de gauche**, en plus petit et alignés sur elle :
- la ligne de la tournée de la sonde ;
- le bandeau de scission, s'il y a lieu ;
- le bandeau « pas encore de pièces de Maison », s'il y a lieu.

Un bandeau qui apparaît glisse depuis le haut avec un fondu, en 0,3 s. Il repart de même. Avec « Réduire les animations », c'est un simple fondu.

**Déplacer la fenêtre.** Sans barre de titre, glisser le fond tourne ou déplace la scène. La fenêtre se déplace donc en glissant **la bande vide du haut, entre les deux capsules**, et seulement là. Le double-clic sur cette bande fait ce que fait un double-clic sur une barre de titre selon les réglages du Mac. Sur cette bande, le double-clic de recadrage de la scène ne s'applique donc pas. Ailleurs, les gestes de la scène ne changent pas, avec deux ajouts du 02/10 :
- **le premier clic agit aussi dans une fenêtre inactive** (choix de Djoko) : il active la fenêtre et isole la pièce, ouvre la fiche ou commence un glisser. Avant, macOS gardait ce clic pour activer la fenêtre, et la pièce ne s'isolait qu'au second clic ;
- **un clic sur le nom d'une pièce l'isole** (son étiquette : son nom et le compte de ses appareils), comme un clic sur sa carte ou sa boîte : en 3D, les boîtes sont petites, et l'on clique volontiers sur le nom. Le nom l'emporte sur la boîte d'une autre pièce qu'il recouvre. Un clic sur le nom d'un appareil ouvre toujours sa fiche. Un clic droit sur le nom d'une pièce n'ouvre aucun menu, comme sur sa boîte (avant, il ouvrait celui du fond, « Replacer les pièces automatiquement »). C'est une proposition de la ronde, à confirmer avec Djoko.

**Marge du haut.** La place laissée en haut de la vue d'ensemble suit la hauteur **mesurée** de ce qui est posé en haut : la ligne des capsules, puis la tournée et les bandeaux présents. Elle remplace les valeurs fixes d'aujourd'hui (72 pt, plus 40 pour la scission, 40 pour la tournée et 44 sans pièces ; précision 21 du plan 4b). Une marge qui change recadre la vue d'ensemble comme aujourd'hui, sauf si Djoko a zoomé ou isolé une pièce.

## 2. La légende A, adaptée

**Elle remplace la petite légende des liens d'aujourd'hui** (`LegendeLiens`), à la même place, en bas à gauche, à côté de la ligne de niveau.

**La vue d'ensemble se cadre au-dessus de tout ce qui est posé en bas** (choix de Djoko du 01/10 pour la légende ouverte, sur les premières images, où la légende cachait des pièces ; du 02/10 pour la fiche) :
- la marge du bas suit la hauteur **mesurée** de la pile du bas, comme la marge du haut suit le bandeau : de haut en bas, la légende et la ligne de niveau, puis la fiche quand elle est ouverte ;
- repliée, sans fiche, la légende rend la place : la marge reprend sa valeur d'avant (30 pt) ;
- **une fiche ouverte ne cache plus la légende** (02/10) : la légende reste visible et monte au-dessus de la fiche. Ce qui change : avant, elle disparaissait sous la fiche, qui gardait des marges fixes de 190 ou 360 pt ; ces valeurs fixes disparaissent ;
- un changement de marge recadre la vue d'ensemble comme aujourd'hui, sauf si Djoko a zoomé ou isolé une pièce ;
- **le repli et l'ouverture de la légende durent 0,45 s** (02/10 : Djoko trouvait l'ouverture « un poil trop fugace » à 0,3 s) : le panneau paraît depuis l'étiquette, en bas à gauche, avec un fondu et un léger grossissement, sur la courbe de la fiche, et le recadrage qui l'accompagne prend la même durée. La fiche et les bandeaux restent à 0,3 s. Avec « Réduire les animations », la règle ne change pas : un fondu pour ce qui paraît ou disparaît, la vue recadrée par un fondu, et rien ne glisse.

**Petite fenêtre** (02/10). Sous une fiche ouverte, si la légende ouverte ne laissait à la scène que moins de **230 pt**, elle se replie d'elle-même, tant que la fiche est ouverte, et se rouvre à sa fermeture. Elle ne se replie que si c'est nécessaire, et son repli gardé ne change pas ; un clic sur son étiquette la rouvre pour cette fiche. Le seuil est la hauteur que la section 3 garde à la scène dans la plus petite fenêtre, avec la fiche et ses courbes : environ 230 pt. Mesuré sur la démo :
- fenêtre par défaut (1100 × 760) : sous la fiche de l'Apple TV 4K, la légende ouverte laisse 291 pt à la scène, et reste ouverte, comme sous la plupart des fiches de la démo (30 sur 31, 240 pt de scène au moins) ; sous la plus haute (179 pt), elle n'en laisserait que 224 : elle se replie, et la scène retrouve 421 pt. Avec les courbes de l'historique, elle se replie aussi ;
- plus petite fenêtre (820 × 712 pt, soit 680 pt sous la barre de titre cachée) : sous la fiche de l'Apple TV 4K et sous la plus haute, elle laisserait 205 et 176 pt ; elle se replie, et la scène retrouve 402 et 373 pt. Sous une fiche courte, elle reste ouverte.

**Aspect**, comme la maquette A, sauf le fond :
- **en Liquid Glass** (02/10), le verre des capsules du haut, en rectangle aux coins de 10 pt. Ce qui change : la maquette A dessine un panneau sombre (le fond de la vue à environ 92 %, filet de 0,5 px blanc à environ 18 %). Djoko choisit cet écart à la maquette en connaissance de cause. Le texte, clair, reste lisible sur la scène sombre. Les images de démo, qui ne rendent pas le verre, le dessinent comme celui des capsules ;
- texte d'environ 11 pt ;
- en-tête « Légende » avec un chevron.

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
| | chef du réseau Thread, élu automatiquement | 👑, dans un nom de nœud comme ceux de la scène |
| Appareils | joignable | pastille verte, avec son halo |
| | partition coupée | pastille orange |
| | sans adresse | pastille rouge |
| | disparu | anneau rouge |
| | endormi | ☾, dans un nom de nœud |
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
- les signes dessinés comme dans la scène (02/10).

**Contextuelle.** Une entrée n'est montrée que si la scène affichée la contient :
- « autre partition » s'il y a plus d'une partition ;
- « pile » s'il y a une pastille de pile ;
- « endormi » s'il y a un ☾ ;
- une qualité de lien si un lien radio de cette qualité est tracé ;
- « parent dans une autre pièce » si un repère « ailleurs » est posé ;
- et ainsi de suite.

Un groupe sans entrée disparaît. Une légende sans aucune entrée n'est pas montrée.

**« Relevé de la sonde ancien »**, que la petite légende d'aujourd'hui montrait en orange, sort de la légende. Il devient une petite pastille orange, à côté de la ligne de niveau, quand le relevé de la sonde est ancien.

**Spec de la vue par pièces, section 8.** La phrase « sans partition en gris » est corrigée : couleur des routeurs (principale en bleu, les autres en ambre, un routeur que la sonde seule connaît en gris). Un appareil prend la couleur de son état, comme le dit la légende.

## 3. La fiche

**Apparition.** La fiche d'un nœud glisse depuis le bas, avec un fondu, en 0,3 s. La vue se relève en même temps pour lui laisser la place : la marge du bas suit la pile mesurée, la légende et la ligne de niveau au-dessus de la fiche (section 2). Ce qui change (02/10) : avant, la fiche cachait la légende et prenait une marge fixe de 190 ou 360 pt. À la fermeture, elle repart vers le bas. Passer d'une fiche à une autre ne la refait pas glisser : son contenu change sur place. Avec « Réduire les animations », elle apparaît et disparaît par un simple fondu.

**Le chef.** Sur la fiche d'un routeur couronné, une pastille « 👑 Chef du réseau Thread, élu automatiquement » se pose sous le nom. Cela vaut pour un routeur de bordure comme pour un routeur que seule la sonde connaît. La fiche lit les chefs de la scène (`EntreeScene.chefs`, polissage A) : elle couronne exactement les mêmes nœuds que la scène.

**Taille minimale.** La fenêtre ne descend pas sous **820 × 712 pt**, soit 680 pt sous la barre de titre cachée (avant : 820 × 560 pt sous la barre de titre, alors visible). Avec la fiche et ses courbes, la scène garde ainsi environ 230 pt de haut, contre 88 aujourd'hui (tri A, n° 11).

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
- ajoutés le 02/10 : la scène du graphe sans barre de titre (son style) ; le premier clic dans une fenêtre inactive ; le clic sur le nom d'une pièce, en 2D et en 3D ; la légende au-dessus de la fiche ; son repli faute de place, le repli gardé intact ; ses signes dessinés par les fonctions de la scène, et leur taille ; la durée de 0,45 s, de la légende et de son recadrage.

**Captures de démo.** Elles changent toutes, puisque la fenêtre change, et deux images s'y ajoutent : la fiche du chef, avec sa pastille, et la légende repliée (quatorze en tout). Les nouvelles sont montrées à Djoko à côté des maquettes.

**Avec Djoko, à la fin :**
- déplacer la fenêtre par la bande du haut ;
- les capsules, centrées sur les trois boutons, à 1,5 pt du bord ;
- les gestes de la scène ;
- la fiche qui glisse ;
- la légende contextuelle et son repli gardé, la vue cadrée au-dessus d'elle ;
- la pastille du chef ;
- le Mac en clair ;
- « Réduire les animations » ;
- la petite fenêtre, avec ses capsules entières ;
- l'annotation des courbes.

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
