[English](README.md) · **Français**

# Maillage Thread

App macOS native de la barre des menus (SwiftUI, Liquid Glass) qui montre le
réseau Thread vu depuis le Mac : routeurs de bordure, partitions et leur
chef, préfixes OMR, appareils Matter et HomeKit et la partition où ils se
trouvent. Elle tient un journal des changements (réseau scindé, routeur de
bordure qui redémarre ou disparaît, appareils perdus) et notifie les alertes.

Elle est née d'une vraie panne : le 27 septembre 2026, cinq appareils Thread
ont cessé de répondre à 04:14. À la main, depuis le Mac : le chef (une Apple
TV) avait publié un nouveau préfixe OMR à 04:04, et un hub Aqara s'était
retrouvé seul dans sa propre partition. L'app le montre d'un coup d'œil et
le garde en mémoire.

## Ce que le Mac peut voir

Le Mac n'a pas de radio Thread : l'app **écoute** seulement le réseau local.

| Source | Donne |
|---|---|
| `_meshcop._udp` (TXT) | routeurs de bordure : nom et identifiant du réseau (`nn`, `xp`), partition (`pt`), rôle (Thread 1.4 et plus, bits 9-10 de `sb`), BBR, jeu actif, préfixe OMR publié |
| `_matter._tcp` | une instance par appareil et par fabrique (`<fabrique>-<nœud>`), regroupées par hôte ; `ICD`, ou `SII` de plus de 2 s : appareil endormi |
| `_hap._udp` | accessoires HomeKit (leur nom) |
| adresses des hôtes | préfixe OMR → partition ; réseau local → appareil IP ; aucune → « sans adresse » |
| table de routage du Mac | quel routeur de bordure route quel préfixe OMR |

« Joignable » veut dire *annoncé avec une adresse Thread dans la partition
principale*, pas « répond » : la joignabilité ne vient jamais de la sonde. Une
disparition n'est retenue qu'après 2 minutes d'absence et datée de la première
absence. Les vrais liens (enfant → parent, routeur ↔ routeur, qualité)
viennent de la sonde, un ESP32-C6 branché au Mac ou joint par le réseau
Thread (voir « Sonde » plus bas).

Les appareils sont placés d'après le préfixe OMR de leur adresse. Quand deux
partitions annoncent le même préfixe OMR (vu le 28 septembre : un hub isolé
avait repris le préfixe de la partition principale), le Mac ne peut pas
savoir de quel côté est un appareil : l'app donne le préfixe à la partition
qui a le plus de routeurs de bordure et le marque « partagé » dans le graphe
et sur la fiche de l'appareil.

## Construire, tester, lancer

Prérequis : macOS 26 ou plus, Xcode 26 ou plus (développé avec Xcode 27),
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
Aucune dépendance tierce. Le projet Xcode est généré : seul `project.yml` est
suivi.

```sh
outils/tester.sh                                   # génère, compile, tous les tests
outils/tester.sh MaillageCoeurTests/SuiviTests     # une suite
```

Les produits de compilation vont dans `~/Library/Developer/Xcode/DerivedData/maillage`
(`DD` pour en changer). Swift 6, concurrence stricte complète, avertissements
traités comme des erreurs.

Lancer : `Maillage Thread.app` dans `…/DerivedData/maillage/Build/Products/Debug/`.
L'app vit dans la barre des menus ; le graphe s'ouvre depuis son menu (et de
lui-même au tout premier lancement).
Un gestionnaire de barre des menus (Bartender, Pelmet…) peut masquer son
icône : les nouvelles icônes arrivent du côté masqué.

### Mode démo

```sh
open "…/Maillage Thread.app" --args -demo
open "…/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D   # fiche ouverte
```

La démo rejoue la panne du 27 septembre, reconstituée à partir du relevé réel
du 28 septembre (`docs/releves/2026-09-28/`) : rien n'est écrit, rien n'est
notifié. Les noms de Maison de la démo sont inventés, comme le maillage de la
sonde dessiné sur les mêmes nœuds.

### Signature

`Signature.xcconfig` (suivi) signe ad hoc : le dépôt compile et teste
partout, sans compte Apple, mais l'autorisation « réseau local » ne tient pas
d'une compilation à l'autre. Pour signer Maillage Thread avec son équipe,
créer `Local.xcconfig` (ignoré par git) :

```
DEVELOPMENT_TEAM = <équipe, 10 caractères>
CODE_SIGN_IDENTITY = Apple Development
```

Si une installation ad hoc existe déjà, passer à la signature d'équipe fait
dire une fois à macOS « L'app diffère des versions précédemment ouvertes », et
l'autorisation « réseau local » est redemandée. Passeur Noms n'est signé avec
l'équipe que par `outils/passeur.sh` (voir plus bas).

## Textes : français et anglais

Le français est la langue de développement (les clés des catalogues sont les
textes français), l'anglais est complet. Après un changement de texte :

```sh
outils/tester.sh                      # compilation : le compilateur extrait les clés
outils/synchroniser-textes.sh         # ajoute ou marque les clés du catalogue
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/<fichier>.json
```

`CataloguesTests` vérifie que chaque clé a son anglais et que le code et le
catalogue vont ensemble.

## Code

| Dossier ou fichier | Rôle |
|---|---|
| `MaillageCoeur/` | framework sans interface : décodage des TXT, instantané (réseaux, partitions, préfixes, appareils), suivi et événements du journal, journal en fichiers, noms, disposition du graphe, table de routage ; testé sur le relevé réel et sur la panne rejouée |
| `MaillageCoeur/Maillage/` | sonde : TLV du diagnostic, Network Data, protocole USB, modèle du maillage, tournée (routeurs, balayage des routeurs muets), identités des routeurs gardées, rapprochement avec l'instantané (élimination, candidats) ; testé sur une capture anonymisée |
| `MaillageThread/Sonde/` | liaison avec la sonde : port série sans redémarrer le C6, ports USB, accès par le réseau Thread (`Reseau/` : transport UDP et enveloppe H1 du pont Halo, clé dans le trousseau, rid et renvois), `SondeUSB` (requêtes appariées par id et par cible, chacune avec son échéance), modèle de l'app (sonde retenue par son numéro de série USB, liaison USB ou réseau, une tournée toutes les 5 minutes) |
| `MaillageThread/Noms/` | noms de Maison : lancement de Passeur Noms, réception de son relevé par la boucle locale (écoute TCP sur 127.0.0.1, jeton à usage unique), derniers noms valides gardés dans le conteneur de l'app |
| `MaillageThread/Recenseur/` | NWBrowser (trois types de service) et dns_sd (hôtes, adresses) → `Annonces` |
| `MaillageThread/Surveillance/` | modèle de l'app : relevés → suivi → journal et notifications ; veille du Mac ; ouverture à la connexion |
| `MaillageThread/Vues/` | barre des menus, fenêtre du graphe (Canvas, surcouches en verre), journal, réglages |
| `Passeur/` | Passeur Noms : app iOS lancée sur le Mac (« conçue pour iPad ») qui lit Maison et envoie ses noms, pièces et zones à l'app par la boucle locale |
| `sonde/` | firmware de la sonde (ESP32-C6, PlatformIO) et outils d'essai |
| `outils/anonymiser-sonde.py` | anonymise une capture de la sonde avant d'en faire des données de test |
| `docs/releves/` | relevés réels (les données des tests et de la démo) |
| `docs/superpowers/` | conception (spec) et plans d'implémentation |

## Noms de Maison (Passeur Noms)

HomeKit n'existe pas en macOS natif, et une équipe de développement Apple
gratuite ne peut pas le donner à une app Mac Catalyst. Les noms de Maison
viennent donc de **Passeur Noms**, une petite app iOS lancée sur le Mac
(« conçue pour iPad ») : elle lit Maison (noms, pièces, zones, fabricants,
`matterNodeID`, batteries), passe le relevé à Maillage Thread par la boucle
locale du Mac, et se ferme. Aucun dossier à choisir.

```sh
outils/passeur.sh          # compile avec ton équipe (compte Xcode), enveloppe, lance
```

- L'équipe vient de ton certificat « Apple Development » (`EQUIPE=` pour
  l'imposer). Une équipe gratuite a un profil de 7 jours : au-delà, Maillage
  Thread ne peut plus lancer Passeur Noms ; relancer le script. Seul Passeur
  Noms est signé avec l'équipe ; Maillage Thread reste ad hoc.
- Au premier lancement de chaque compilation, macOS dit que l'app est
  « endommagée » : cliquer Annuler, puis Réglages Système › Confidentialité et
  sécurité › « Ouvrir quand même ». Autoriser ensuite l'accès à Maison. Ouvert
  ainsi à la main, Passeur Noms lit Maison, montre ce qu'il a lu, n'envoie
  rien et se ferme après 10 s.
- Un relevé : Maillage Thread écoute sur `127.0.0.1` (TCP, sur un port choisi
  par le système), tire un jeton à usage unique et lance Passeur Noms en
  arrière-plan avec `--port` et `--jeton`. Passeur Noms lit Maison, se
  connecte, envoie le jeton, la longueur du JSON puis le JSON, et se ferme
  dès que l'app a tout lu. L'app vérifie le jeton, lit au plus 8 Mo et écrit
  `noms.json` dans son conteneur (écriture atomique). La boucle locale ne
  demande pas l'accès au réseau local.
- Priorité des noms : surnom > Maison > HomeKit (`_hap._udp`) > hôte.
- Le dernier relevé valide est gardé. Un échec (par exemple Passeur Noms
  introuvable ou refusé, rien en 2 minutes, jeton faux, longueur ou JSON
  illisible, accès à Maison refusé) le garde et se lit dans Réglages › Noms
  de Maison et dans le menu ; au-delà de 7 jours, les Réglages disent de
  relancer `outils/passeur.sh`. Passeur Noms note au journal pourquoi il
  s'est fermé :
  `/usr/bin/log show --last 10m --predicate 'subsystem == "fr.djoko.maillage.passeur"'`.
- Rafraîchissement : la fenêtre du graphe lance Passeur Noms à son ouverture
  (si le relevé et la dernière demande ont plus de 15 min), puis toutes les
  heures ; « Rafraîchir depuis Maison » (menu ou réglages) et le bouton
  rafraîchir du graphe le font à la demande. Un relevé à la fois : une
  demande pendant un relevé est ignorée. La fenêtre de Passeur Noms ne fait
  que passer derrière les autres.
- Zones : les zones de Maison (en général les étages) et leurs pièces, dans
  l'ordre de Maison ; Réglages › Noms de Maison en liste les noms. Un relevé
  d'avant les zones n'en a pas.
- Le `noms.json` écrit dans un dossier choisi par un ancien Passeur Noms (à la
  racine de ce dépôt, par exemple) n'est plus lu : l'effacer (git l'ignore).
- Batteries : niveau, état de charge et alerte de l'accessoire lui-même, pour
  chaque accessoire de Maison qui a une batterie. La fiche de l'appareil les
  montre avec l'âge du relevé ; dans le graphe, une pastille orange en
  surbrillance signale une batterie faible (l'accessoire le dit, ou son niveau
  est de 20 % ou moins).

## Sonde (le vrai maillage)

Le Mac n'a pas de radio Thread. La **sonde** est un ESP32-C6 SuperMini branché
au Mac en USB et ajouté à Maison comme appareil Matter sur Thread (une prise
« Sonde maillage »). C'est un enfant qui ne devient jamais routeur (FED depuis
le firmware 1.0.2) : elle écoute en permanence mais ne relaie rien, donc elle
n'est le parent de personne. Elle envoie pour l'app les requêtes de
diagnostic Thread (`DIAG_GET`) et lui rend les réponses brutes, par l'USB ou,
une fois l'accès autorisé, par le réseau Thread ; l'app les décode et
reconstruit le maillage.

Le **pont Halo** est l'autre projet ESP32-C6 de l'auteur, un pont Matter sur
Thread pour une lampe ScreenBar Halo, dans un autre dépôt. L'accès de la sonde
par le réseau est celui du pont, tel quel, **enveloppe H1** comprise : une
poignée de main signée, puis des messages qui portent chacun un compteur et un
HMAC.

```sh
cd sonde && pio run        # compiler ; flasher et appairer : sonde/README.md
```

- Dans Maillage Thread : Réglages › Sonde › Port. L'app n'ouvre que le port
  choisi : un autre ESP32-C6 branché (le pont Halo, par exemple) n'est jamais
  ouvert. La sonde est retenue par son numéro de série USB et s'affiche sous
  son nom, « SONDE-01 » par défaut : le firmware le garde, il suit donc la
  carte d'un Mac à l'autre (le nom USB du C6 est fixé par la puce). Branchée,
  elle est reprise seule ; si elle démarre trop lentement, l'app réessaie une
  fois 5 s plus tard. Tout autre port s'affiche avec son numéro de série USB
  (« usbmodem… · » suivi du numéro), seul moyen de distinguer la sonde du pont
  Halo avant la première connexion. La ligne du menu prend aussi
  ce nom (« SONDE-01 : connectée · relevé il y a 2 minutes »), comme l'état
  dans Réglages › Sonde (« SONDE-01 · connectée ») ; pas pour un autre port
  en essai.
- Réglages › Sonde montre le QR code Matter de la sonde et son code
  d'appairage (4-3-4), même une fois dans Maison, en USB seulement : ils ne
  passent jamais par le réseau, et une note le dit à leur place.
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
- La liste des routeurs vient du chef ; s'il se tait, d'un routeur qui a déjà
  répondu ; sinon des autres routeurs de la table de la sonde, puis d'une
  recherche sur tous les identifiants de routeur (pas de nouveau dans les 30
  minutes qui suivent une recherche vaine). Sans liste, pas de nouveau
  maillage : le dernier vieillit.
- La tournée demande ensuite à chaque routeur qui répond ses liens (avec la
  qualité dans chaque sens) et ses enfants, lit les routeurs de bordure dans
  les Network Data, et demande à chaque enfant listé dans la table d'un
  routeur son identité (ExtMac, adresses), au plus une fois par demi-heure,
  endormis compris (l'ExtMac d'un appareil Matter est son nom d'hôte).
- **Les routeurs de bordure d'Apple ne répondent jamais au diagnostic.** Le
  balayage des RLOC16 d'enfant possibles vise les routeurs qui n'ont jamais
  répondu (ceux d'Apple) ou qui se sont tus deux tournées de suite (un refus
  de la sonde, ou une réponse illisible, n'est pas un silence), toutes les 30
  minutes ou quand cet ensemble change ; la qualité de ces liens reste
  inconnue, et un lien entre deux routeurs Apple n'est jamais dessiné.
- **Identité des routeurs de bordure.** Muet, un routeur d'Apple ne donne pas
  son ExtMac, donc pas le nom de son annonce. La sonde (firmware 1.0.2)
  apprend celle des routeurs qu'elle entend : chaque tournée lit sa table des
  routeurs (`routeurs`) et retient chaque paire RLOC16 ↔ ExtMac, comme celle
  de son parent, même quand la tournée n'aboutit pas. Ces identités sont
  gardées d'un lancement à l'autre avec leur partition
  (`identites-routeurs.json` dans le dossier de l'app ; une autre partition
  les efface, et la paire d'un routeur sorti de la liste des routeurs est
  oubliée) : déplacée dans la maison, la sonde les apprend toutes. Le chef,
  s'il est un routeur de bordure, est l'annonce de sa partition dont le rôle
  est chef, si elle est la seule ; avec deux (un cache périmé), il reste non
  identifié, avec les deux pour candidates. S'il ne reste qu'un routeur de
  bordure non identifié pour une seule annonce, c'est lui, par élimination.
  Sinon, il s'affiche avec ses candidats,
  « HomePod Avant ou HomePod Palier · 0400 » (« HomePod salon ? · 0400 »
  pour un seul), et ces annonces ne sont plus dessinées à part : un seul nœud
  par routeur. Sa fiche liste les candidats ; chacun ouvre la fiche de son
  annonce. Sans sonde, toutes les annonces restent dessinées.
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
  événement.
- Éteindre « Sonde maillage » dans Maison suspend la sonde : pas de tournée,
  même après un redémarrage de la sonde. Sa LED donne alors un bref éclair
  orange toutes les 5 s (firmware 1.0.3). Après un `oubli`, la commande USB
  qui désappaire la sonde (voir `sonde/README.md`), la sonde revient allumée,
  comme à sa première mise en service.
- Les captures de la sonde contiennent les adresses du réseau de la maison :
  `outils/anonymiser-sonde.py` les réécrit de façon cohérente avant qu'elles ne
  deviennent des données de test (`docs/releves/2026-09-29/`). L'anonymiseur
  échoue devant tout type de message, champ ou TLV inconnu, sans rien écrire :
  il ne connaît que les messages `bonjour`, `etat` et `diag` de cette capture,
  si bien qu'une capture du firmware 1.0.2 ou plus récent (`etat.ext`,
  `bonjour.hote`, `routeurs`…) est refusée tant qu'il ne les traite pas.

### Route vers le réseau Thread

Par le réseau, l'app joint la sonde à son adresse dans le préfixe OMR, un /64
que les routeurs de bordure (HomePod, Apple TV…) annoncent au réseau local.
macOS n'installe pas toujours la route vers ce préfixe, et peut la perdre en
changeant de routeur de bordure sans la remettre : la sonde est alors
injoignable, et l'app dit « Pas de route IPv6 vers le réseau Thread ». Il
faut au Mac une route vers ce /64 par l'un des routeurs de bordure qui
l'annoncent (la poser demande les droits d'administrateur). L'auteur utilise
pour cela un assistant de son autre projet, qui n'est pas dans ce dépôt.
