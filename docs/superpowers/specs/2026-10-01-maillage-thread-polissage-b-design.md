# Maillage Thread, polissage B : la fenêtre et la légende

Spec du 01/10/2026, validée par Djoko section par section le même jour.

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

Elle passe par le crochet AppKit qui force déjà la fenêtre en sombre (`SondeFenetre`, `assombrir`) : `titlebarAppearsTransparent`, titre masqué, `fullSizeContentView`. Les autres fenêtres de l'app ne changent pas.

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

**Déplacer la fenêtre.** Sans barre de titre, glisser le fond tourne ou déplace la scène. La fenêtre se déplace donc en glissant **la bande vide du haut, entre les deux capsules**, et seulement là. Le double-clic sur cette bande fait ce que fait un double-clic sur une barre de titre selon les réglages du Mac. Sur cette bande, le double-clic de recadrage de la scène ne s'applique donc pas. Ailleurs, les gestes de la scène ne changent pas.

**Marge du haut.** La place laissée en haut de la vue d'ensemble suit la hauteur **mesurée** de ce qui est posé en haut : la ligne des capsules, puis la tournée et les bandeaux présents. Elle remplace les valeurs fixes d'aujourd'hui (72 pt, plus 40 pour la scission, 40 pour la tournée et 44 sans pièces ; précision 21 du plan 4b). Une marge qui change recadre la vue d'ensemble comme aujourd'hui, sauf si Djoko a zoomé ou isolé une pièce.

## 2. La légende A, adaptée

**Elle remplace la petite légende des liens d'aujourd'hui** (`LegendeLiens`), à la même place, en bas à gauche, à côté de la ligne de niveau.

**La vue d'ensemble se cadre au-dessus de la légende ouverte** (choix de Djoko du 01/10, sur les premières images, où la légende cachait des pièces) :
- la marge du bas suit la hauteur **mesurée** de la légende et de la ligne de niveau, comme la marge du haut suit le bandeau ;
- repliée, la légende rend la place : la marge reprend sa valeur d'avant ;
- une fiche ouverte, qui cache la légende, garde ses marges (190 ou 360 pt) ;
- un changement de marge recadre la vue d'ensemble comme aujourd'hui, sauf si Djoko a zoomé ou isolé une pièce. Le repli et l'ouverture la recadrent avec l'animation de la fiche, ou par un fondu avec « Réduire les animations ».

**Aspect**, comme la maquette A :
- panneau sombre (fond de la vue à environ 92 %) ;
- filet de 0,5 px blanc à environ 18 % ;
- coins d'environ 10 pt ;
- texte d'environ 11 pt ;
- en-tête « Légende » avec un chevron.

Repliée, il ne reste que l'étiquette « Légende ». Son état, replié ou ouvert, est gardé d'un lancement à l'autre.

**Quatre groupes en grille 2 × 2**, aux titres discrets, gris bleuté. Les couleurs sont celles de `Palette`.

| Groupe | Entrée | Signe |
|---|---|---|
| Routeurs | routeur | point bleu |
| | non identifié | point gris |
| | autre partition | point ambre |
| | chef du réseau Thread, élu automatiquement | 👑 |
| Appareils | joignable | point vert |
| | partition coupée | point orange |
| | sans adresse | point rouge |
| | disparu | anneau rouge |
| | endormi | ☾ |
| | pile | pastille orange « 12 % » |
| Liens radio (qualité) | bonne | trait vert de 2 pt |
| | moyenne | trait jaune de 2 pt |
| | faible | trait orange de 2 pt |
| | inconnue | trait gris de 2 pt |
| Autres | vers son parent | trait fin blanc, comme le lien enfant → parent |
| | rattachement supposé | pointillé |
| | parent dans une autre pièce | repère « → Salon » |
| | candidats | libellé « A ou B · 0400 » |

**Écarts à la maquette A du 30/09**, et seulement ceux-là :
- les liens radio sont tous en 2 pt, et seule la couleur dit la qualité. Les mots remplacent les chiffres 3, 2 et 1 ;
- « partition » (cercle de zone) est retirée, car la vue par pièces n'en dessine pas ;
- « vers son parent » et « parent dans une autre pièce » sont ajoutés ;
- le texte du chef est celui validé le 01/10.

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

**Apparition.** La fiche d'un nœud glisse depuis le bas, avec un fondu, en 0,3 s. La vue se relève en même temps pour lui laisser la place (marge du bas de 190 ou 360 pt, comme aujourd'hui). À la fermeture, elle repart vers le bas. Passer d'une fiche à une autre ne la refait pas glisser : son contenu change sur place. Avec « Réduire les animations », elle apparaît et disparaît par un simple fondu.

**Le chef.** Sur la fiche d'un routeur couronné, une pastille « 👑 Chef du réseau Thread, élu automatiquement » se pose sous le nom. Cela vaut pour un routeur de bordure comme pour un routeur que seule la sonde connaît. La fiche lit les chefs de la scène (`EntreeScene.chefs`, polissage A) : elle couronne exactement les mêmes nœuds que la scène.

**Taille minimale.** La fenêtre passe de 820 × 560 à **820 × 680** pt au minimum. Avec la fiche et ses courbes, la scène garde ainsi environ 230 pt de haut, contre 88 aujourd'hui (tri A, n° 11).

**À vérifier avec Djoko** (tri A, n° 12). L'annotation « → Nom » d'un changement de parent, au-dessus des courbes, peut chevaucher le titre du graphique. Si c'est le cas à l'écran, elle descend sous le titre.

## 4. Hors de B

- **C :** une zone au même niveau qu'un étage ; la 2D en grille ; isoler un étage ; et les n° 8 et 9 du tri A.
- **D :** ⌥ + glisser ; un appareil qui glisse d'une pièce à l'autre ; un étage qui se réarrange après un changement d'état (n° 6 du tri A) ; la molette et Échap (n° 7).

## 5. Tests et vérification

**Tests.** Ils passent en français et en anglais. Tous les textes sont au catalogue.
- les entrées de la légende selon la scène : une scène inventée par cas, une entrée par signe, et un groupe vide qui disparaît ;
- le repli gardé ;
- la pastille du chef, sur un routeur de bordure et sur un routeur de la sonde, mêmes chefs que la scène ;
- la marge du haut mesurée ; celle du bas, sous la légende ouverte ;
- la taille minimale de la fenêtre ;
- les capsules du haut : chacune à la largeur de son contenu, même à la taille minimale de la fenêtre, en 2D et en 3D (la bande vide prend la place qui reste).

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
