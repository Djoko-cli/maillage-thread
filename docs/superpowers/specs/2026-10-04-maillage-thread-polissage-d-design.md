# Maillage Thread, polissage D : les gestes et les animations

Spec du 04/10/2026. Djoko a validé la conception en six points le même jour.

## 0. Contexte et décisions

Le polissage se fait en quatre sous-projets : A, B et C sont fusionnés ; **D (cette spec)** les clôt. ⌥ + glisser, d'abord prévu ici, est livré par C.

**Décisions de Djoko (04/10) :**

| Sujet | Décision |
|---|---|
| Périmètre | l'appareil qui glisse, la molette et Échap, les restes de C, l'allègement du moteur |
| Rythme des glissements | **0,9 s**, la durée et la courbe des changements de niveau de C ; apparitions et disparitions en fondu de 0,3 s |
| Un badge change (⚠︎, ☾, 👑, pastille de pile) | **l'étage ne bouge pas** : les cartes réservent la place des badges |
| Ajouts du 04/10, pendant le plan | un routeur dont tous les candidats sont dans la même pièce va dans cette pièce (section 4.1) ; la rotation lente continue quand une pièce ou un étage est isolé (section 4.2) ; le signal vu par la sonde a toujours une échelle, et sa valeur se lit au survol (section 4.3) |
| Points du plan, 05/10 | la pastille de pile n'est réservée qu'aux appareils dont la pile est connue ; une pièce glissée ne relance pas le calcul ; le chef garde sa place dans sa carte ; le moteur est découpé en fichiers dans D (section 5) |

## 1. Le glissement d'une disposition à l'autre

**Quand :** chaque fois que le moteur installe une nouvelle disposition. Il y en a trois sources :
- un relevé ;
- un appareil placé dans une pièce ;
- un choix de niveau.

Une pièce glissée par Djoko n'en est pas une : voir plus bas.

Les plateaux qui changent de niveau gardent leur glissement de C, avec les mêmes 0,9 s.

**Ce qui glisse, reconnu par sa clé :**
- les pièces : leur centre et leur taille ;
- les appareils : leur position dans le monde ;
- les plateaux : leur centre.

Chacun va de sa pose affichée à sa pose nouvelle, en **0,9 s**, en cubique entrée-sortie. Un appareil qui change de pièce glisse en ligne droite, d'un étage à l'autre s'il le faut, en 2D comme en 3D. Ses liens le suivent.

**Ce qui apparaît ou disparaît :**
- un élément présent seulement dans la nouvelle disposition (pièce, appareil, lien) apparaît en **fondu de 0,3 s** à sa place ;
- un élément présent seulement dans l'ancienne s'efface en 0,3 s, à sa dernière place.

**Une nouvelle disposition pendant un glissement** repart de la pose affichée à cet instant, sans saut. Il en va de même pour un isolement ou un vol de caméra en cours : la caméra suit ce qu'elle regarde, comme pour la grille de C. Une disposition qui arrive pendant un vol, l'envol ou un geste attend toujours la fin du mouvement (spec de la vue par pièces, section 7), puis glisse de la pose affichée : un délai, jamais un saut.

**Une pièce glissée par Djoko** n'est pas animée à son relâchement : elle est déjà à sa place. Le relâchement ne relance pas le calcul, comme avant : les autres pièces ne bougent pas, et ne glissent qu'à la disposition suivante (décision du 05/10). Un recalcul au relâchement pourrait réarranger toute la maison.

**« Réduire les animations »** : tout est immédiat, sans fondu.

**Horloge :** l'horloge du rendu tourne pendant le glissement, puis s'arrête. Aucune image au repos.

## 2. Les badges ne déplacent plus les pièces

Le triage A, n° 6, constatait ceci : un changement d'état change le nom affiché, donc la largeur de la carte et la clé de disposition. Il pouvait réarranger un étage.

**Ce qui change :**
- la mesure d'une carte (`CartesPieces`) compte, pour chaque nom, la place de ses badges possibles : ☾, ⚠︎ et 👑, qu'ils soient affichés ou non ;
- la place de la pastille de pile faible (« ⚠︎ 12 % ») n'est réservée qu'aux appareils dont la pile est connue (décision du 05/10). Une pile qui devient connue peut donc élargir la carte une fois ;
- le chef (👑) ne remonte plus en tête de sa carte : il garde sa place, avec sa couronne. Sinon, un changement de chef réordonnerait la carte. C'est un écart voulu à la spec de la vue par pièces, section 2.2 (décision du 05/10) ;
- la clé de disposition ne contient plus les badges, seulement les noms nus, le fait que la pile soit connue, et le fait que le nœud route (il ne prend pas ☾) ;
- un badge qui apparaît ou disparaît ne relance donc plus le calcul : rien ne bouge, seul le nom change.

Les cartes s'élargissent un peu, et toutes les images de démo changent une fois. Le placement des noms ne change pas.

## 3. La molette et Échap

C'est le triage A, n° 7. Le moniteur local prenait toute la molette et tout Échap.

**La molette :**
- au-dessus d'un élément posé sur la vue (la fiche, la légende, les capsules, la colonne du haut), l'événement leur revient ; la scène ne zoome pas ;
- au-dessus de la scène, rien ne change.

**Échap, dans cet ordre :**
1. une fiche ouverte se ferme ;
2. sinon, la vue remonte d'un cran, comme en C ;
3. sinon, à la vue d'ensemble sans zoom ni fiche, Échap n'est pas pris : l'événement suit son chemin.

## 4. Les restes de C

- **Un étage absent garde son rang.** Quand un choix du menu (spec de C, section 1.3) rend un nouvel ordre, il est fondu dans l'ordre gardé. Les plateaux absents de la scène y gardent leur rang relatif. Cela vaut aussi pour « Monter » et « Descendre ».
- **La grille est rechoisie quand les rayons changent.** C'est le cas d'une nouvelle disposition qui garde les niveaux. Le choix se fait à la vue d'ensemble, avec l'hystérésis de 5 % de C ; zoomée ou isolée, la vue attend.
- **Le menu du clic droit revient dès la fin de l'envol ou du fondu,** sans attendre un mouvement du pointeur.

## 4.1 Un routeur aux candidats d'une même pièce

Un routeur de bordure non identifié garde ses candidats, les annonces non reprises qui peuvent être la sienne (plan 3a). Son nom est alors « A ou B · RLOC16 », et il va dans « Sans pièce ». Chez Djoko, les deux HomePod d'une paire stéréo y tombent ensemble dès que la sonde perd leur ExtMac.

**La règle :**
- on cherche la pièce de chaque candidat, comme celle d'un routeur identifié qui porterait son annonce : par la même chaîne que pour un routeur identifié : la pièce donnée par Maison s'il y en a une, puis le choix de « Placer dans une pièce… », gardé sous l'instance de l'annonce, puis la règle du nom (spec de la vue par pièces, section 2.3) ;
- si tous les candidats ont une pièce, et que c'est la même, le routeur va dans cette pièce ;
- sinon, il reste dans « Sans pièce », comme aujourd'hui ;
- le nom ne change pas : « A ou B · RLOC16 » reste honnête ;
- la fiche ne propose pas « Placer dans une pièce… » pour un tel routeur, comme aujourd'hui.

## 4.2 La rotation lente continue pendant un isolement

Demande de Djoko du 04/10. Jusqu'ici, la rotation lente s'arrêtait pendant un isolement (spec de la vue par pièces, section 7 ; spec de C, section 5.1).

**Ce qui change :**
- en 3D, la rotation lente continue quand une pièce ou un étage est isolé. Elle tourne autour de l'axe vertical qui passe par la cible de la caméra, c'est-à-dire le centre de ce qui est isolé ;
- le vol vers l'objet isolé se fait d'abord ; la rotation reprend à la fin du vol, sans saut ;
- elle s'arrête toujours pendant un geste (glisser, molette, pincement, ⌥ + glisser), et reprend après ;
- « Rotation lente » décochée, ou « Réduire les animations » : pas de rotation, comme aujourd'hui ;
- les repères « ailleurs » d'une pièce isolée et les noms suivent la rotation, comme à la vue d'ensemble.

## 4.3 Le signal vu par la sonde, dans la fiche

Constat de Djoko du 04/10 : juste après la première tournée, la courbe « Signal vu par la sonde (dBm) » n'a qu'un point. Son axe vertical n'a alors aucune graduation, et le point ne dit rien. L'échelle automatique (`.automatic(includesZero: false)`, dans `CourbesFiche`) n'a pas d'étendue quand toutes les valeurs sont égales.

**L'échelle, toujours visible :**
- le domaine vertical est calculé dans le cœur, à partir des valeurs de la période : du minimum moins 5 dB, arrondi à la dizaine inférieure, au maximum plus 5 dB, arrondi à la dizaine supérieure ;
- il couvre donc au moins 10 dB, même pour un seul point ou des valeurs toutes égales ;
- les graduations tombent sur les dizaines de dBm, et l'axe en montre au moins deux ;
- exemple : un seul point à −67 dBm donne −80 … −60, gradué −80, −70, −60.

**La valeur au survol :**
- quand le pointeur passe sur la courbe du signal, le relevé le plus proche dans le temps est mis en avant : un trait vertical à son heure, un point sur sa valeur ;
- une étiquette donne sa valeur et son heure, par exemple « −67 dBm · 16:13 » en français, au format d'heure de la langue de l'app ; pour 7 j et 30 j, elle donne aussi le jour ;
- un relevé ne compte que s'il est à moins du plus petit de deux seuils, 2 % de la largeur de la période et l'écart qui coupe la courbe en tronçons (20 min sur 24 h, 90 min sur 7 j, 6 h sur 30 j) ; aux trois périodes, c'est l'écart, le plus petit. Au milieu d'un trou d'au moins deux écarts, rien n'est montré ; près des bords d'un trou, ou dans un trou plus court, le relevé le plus proche l'est encore ;
- le pointeur sorti de la courbe, l'étiquette disparaît ;
- l'étiquette reste dans le cadre du graphe, à gauche du trait quand il est près du bord droit.

La courbe de la qualité des liens garde son échelle fixe de 0 à 3, sans survol.

## 5. L'allègement du moteur

`MoteurPieces` compte 1 686 lignes. Deux machines d'états y sont mêlées au rendu et aux gestes. Elles sortent dans le cœur, en types purs et testables sans fenêtre ni `ImageRenderer` :
- **l'isolement :** l'état (maison, étage, pièce avec sa provenance), les transitions (isoler, aller à un étage, remonter, retour à la vue d'ensemble), le recalage quand une scène arrive, et la règle des clics sur un disque ;
- **la politique de la grille :** la demande, l'attente de la vue d'ensemble, l'hystérésis, la taille nulle, les durées (2,6 s, 0,9 s, 0,4 s) ;
- **la transition de la section 1,** écrite directement dans le cœur.

Le moteur garde le rendu, les gestes, l'horloge et les vols, et appelle ces types.

**Le moteur est aussi découpé en fichiers** (décision du 05/10, le moteur passant sinon de 1 724 à 1 877 lignes). C'est la dernière tâche de code de D, une fois tout le reste en place :
- `MoteurPieces` se répartit en extensions, par responsabilité : par exemple le rendu, les gestes, l'horloge et les vols, l'isolement et la grille, le menu ;
- aucun fichier ne dépasse environ 600 lignes ;
- le code est déplacé, sans être réécrit ; les tests ne changent pas, et les images de démo restent identiques, octet pour octet.

**Le comportement ne change pas.** Les tests du moteur, de la fenêtre et de l'isolement restent verts sans être affaiblis. Les règles écrites deux fois (relecture de la tâche 5 de C) n'ont plus qu'un endroit.

## 6. Démo, tests, vérification

**Captures de démo :**
- elles changent toutes une fois, à cause de la réserve des badges ;
- une image s'ajoute : un appareil au milieu de son glissement vers une autre pièce, posé à mi-course par un état de capture.

**Tests du cœur :**
- **la transition :**
  - les poses à 0, à la moitié et à la fin ;
  - la courbe ;
  - les fondus d'entrée et de sortie ;
  - une interruption qui repart de la pose affichée, sans saut ;
  - « Réduire les animations » ;
- **les badges :**
  - la largeur d'une carte ne dépend pas des badges affichés ;
  - la clé de disposition non plus ;
- **l'isolement et la politique de la grille, sortis du moteur :** leurs règles, testées à part ;
- **l'ordre des étages,** avec un absent qui garde son rang ;
- **la pièce d'un routeur aux candidats :** même pièce ; pièces différentes ; un candidat sans pièce ; le choix gardé avant la règle du nom ;
- **le signal de la fiche :**
  - le domaine pour un seul point, des valeurs égales, des valeurs étalées, et des valeurs déjà sur une dizaine ;
  - le relevé le plus proche du pointeur, le seuil des deux côtés, et un trou ;
  - le texte de l'étiquette en 24 h et en 7 j.

**Tests de l'app :**
- la molette au-dessus de la fiche et de la légende ;
- Échap dans les trois cas ;
- le menu qui revient à la fin de l'envol ;
- la grille rechoisie quand les rayons changent ;
- une nouvelle disposition qui glisse au lieu de sauter ;
- la rotation lente pendant un isolement : elle tourne autour de la cible, s'arrête pendant un geste, puis reprend.

**Avec Djoko, en vrai :**
- « Placer dans une pièce… » sur un appareil : il glisse jusqu'à sa nouvelle pièce, en 2D et en 3D ;
- une pièce glissée à la main : les autres glissent si elles bougent ;
- un badge qui change ne fait plus bouger l'étage ;
- la molette sur la fiche et la légende ; Échap ;
- la rotation lente autour d'une pièce, puis d'un étage isolés ;
- les deux HomePod de la paire dans leur pièce, même quand ils ne sont pas identifiés ;
- le signal vu par la sonde : l'échelle avec un seul point, puis la valeur au survol ;
- « Réduire les animations » ;
- le reste de la vue, inchangé.

## 7. Hors de D

Rien n'est reporté : D clôt le polissage. Restent à part :
- l'anonymisation de l'option C avant tout push ;
- les essais sur les réglages de sensibilité des capteurs ;
- les points en attente du 4a et du passeur.
