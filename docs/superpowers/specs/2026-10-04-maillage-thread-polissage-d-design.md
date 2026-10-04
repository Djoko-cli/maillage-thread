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

## 1. Le glissement d'une disposition à l'autre

**Quand :** chaque fois que le moteur installe une nouvelle disposition. Il y en a quatre sources :
- un relevé ;
- un appareil placé dans une pièce ;
- une pièce glissée par Djoko ;
- un choix de niveau.

Les plateaux qui changent de niveau gardent leur glissement de C, avec les mêmes 0,9 s.

**Ce qui glisse, reconnu par sa clé :**
- les pièces : leur centre et leur taille ;
- les appareils : leur position dans le monde ;
- les plateaux : leur centre.

Chacun va de sa pose affichée à sa pose nouvelle, en **0,9 s**, en cubique entrée-sortie. Un appareil qui change de pièce glisse en ligne droite, d'un étage à l'autre s'il le faut, en 2D comme en 3D. Ses liens le suivent.

**Ce qui apparaît ou disparaît :**
- un élément présent seulement dans la nouvelle disposition (pièce, appareil, lien) apparaît en **fondu de 0,3 s** à sa place ;
- un élément présent seulement dans l'ancienne s'efface en 0,3 s, à sa dernière place.

**Une nouvelle disposition pendant un glissement** repart de la pose affichée à cet instant, sans saut. Il en va de même pour un isolement ou un vol de caméra en cours : la caméra suit ce qu'elle regarde, comme pour la grille de C.

**Une pièce glissée par Djoko** n'est pas animée à son relâchement : elle est déjà à sa place. Seules les autres pièces que le recalcul déplace glissent.

**« Réduire les animations »** : tout est immédiat, sans fondu.

**Horloge :** l'horloge du rendu tourne pendant le glissement, puis s'arrête. Aucune image au repos.

## 2. Les badges ne déplacent plus les pièces

Le triage A, n° 6, constatait ceci : un changement d'état change le nom affiché, donc la largeur de la carte et la clé de disposition. Il pouvait réarranger un étage.

**Ce qui change :**
- la mesure d'une carte (`CartesPieces`) compte, pour chaque nom, la place de ses badges possibles : ☾, ⚠︎, 👑 et la pastille de pile faible (« ⚠︎ 12 % »), qu'ils soient affichés ou non ;
- la clé de disposition ne contient plus les badges, seulement les noms nus ;
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

## 5. L'allègement du moteur

`MoteurPieces` compte 1 686 lignes. Deux machines d'états y sont mêlées au rendu et aux gestes. Elles sortent dans le cœur, en types purs et testables sans fenêtre ni `ImageRenderer` :
- **l'isolement :** l'état (maison, étage, pièce avec sa provenance), les transitions (isoler, aller à un étage, remonter, retour à la vue d'ensemble), le recalage quand une scène arrive, et la règle des clics sur un disque ;
- **la politique de la grille :** la demande, l'attente de la vue d'ensemble, l'hystérésis, la taille nulle, les durées (2,6 s, 0,9 s, 0,4 s) ;
- **la transition de la section 1,** écrite directement dans le cœur.

Le moteur garde le rendu, les gestes, l'horloge et les vols, et appelle ces types.

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
- **l'ordre des étages,** avec un absent qui garde son rang.

**Tests de l'app :**
- la molette au-dessus de la fiche et de la légende ;
- Échap dans les trois cas ;
- le menu qui revient à la fin de l'envol ;
- la grille rechoisie quand les rayons changent ;
- une nouvelle disposition qui glisse au lieu de sauter.

**Avec Djoko, en vrai :**
- « Placer dans une pièce… » sur un appareil : il glisse jusqu'à sa nouvelle pièce, en 2D et en 3D ;
- une pièce glissée à la main : les autres glissent si elles bougent ;
- un badge qui change ne fait plus bouger l'étage ;
- la molette sur la fiche et la légende ; Échap ;
- « Réduire les animations » ;
- le reste de la vue, inchangé.

## 7. Hors de D

Rien n'est reporté : D clôt le polissage. Restent à part :
- l'anonymisation de l'option C avant tout push ;
- les essais sur les réglages de sensibilité des capteurs ;
- les points en attente du 4a et du passeur.
