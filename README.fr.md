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
viennent de la sonde, un ESP32-C6 branché au Mac (voir « Sonde » plus bas).

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

| Dossier | Rôle |
|---|---|
| `MaillageCoeur/` | framework sans interface : décodage des TXT, instantané (réseaux, partitions, préfixes, appareils), suivi et événements du journal, journal en fichiers, noms, disposition du graphe, table de routage ; testé sur le relevé réel et sur la panne rejouée |
| `MaillageCoeur/Maillage/` | sonde : TLV du diagnostic, Network Data, protocole USB, modèle du maillage, tournée (routeurs, balayage des routeurs muets), identités des routeurs gardées, rapprochement avec l'instantané (élimination, candidats) ; testé sur une capture anonymisée |
| `MaillageThread/Sonde/` | liaison avec la sonde : port série sans redémarrer le C6, ports USB, `SondeUSB` (requêtes appariées par id), modèle de l'app (sonde retenue par son numéro de série USB, une tournée toutes les 5 minutes) |
| `MaillageThread/Noms/` | noms de Maison : dossier choisi une fois (signet à portée de sécurité), lecture de `noms.json`, derniers noms gardés, lancement de Passeur Noms |
| `MaillageThread/Recenseur/` | NWBrowser (trois types de service) et dns_sd (hôtes, adresses) → `Annonces` |
| `MaillageThread/Surveillance/` | modèle de l'app : relevés → suivi → journal et notifications ; veille du Mac ; ouverture à la connexion |
| `MaillageThread/Vues/` | barre des menus, fenêtre du graphe (Canvas, surcouches en verre), journal, réglages |
| `Passeur/` | Passeur Noms : app iOS lancée sur le Mac (« conçue pour iPad ») qui lit Maison et écrit `noms.json` |
| `sonde/` | firmware de la sonde (ESP32-C6, PlatformIO) et outils d'essai |
| `outils/anonymiser-sonde.py` | anonymise une capture de la sonde avant d'en faire des données de test |
| `docs/releves/` | relevés réels (les données des tests et de la démo) |
| `docs/superpowers/` | conception (spec) et plans d'implémentation |

## Noms de Maison (Passeur Noms)

HomeKit n'existe pas en macOS natif, et une équipe de développement Apple
gratuite ne peut pas le donner à une app Mac Catalyst. Les noms de Maison
viennent donc de **Passeur Noms**, une petite app iOS lancée sur le Mac
(« conçue pour iPad ») : elle lit Maison (noms, pièces, fabricants,
`matterNodeID`, batteries), écrit `noms.json` dans un dossier choisi une
fois, et se ferme.

```sh
outils/passeur.sh          # compile avec ton équipe (compte Xcode), enveloppe, lance
```

- L'équipe vient de ton certificat « Apple Development » (`EQUIPE=` pour
  l'imposer). Une équipe gratuite a un profil de 7 jours : relancer le script
  pour rafraîchir les noms. Seul Passeur Noms est signé avec l'équipe ;
  Maillage Thread reste ad hoc.
- Au premier lancement de chaque compilation, macOS dit que l'app est
  « endommagée » : cliquer Annuler, puis Réglages Système › Confidentialité et
  sécurité › « Ouvrir quand même ». Autoriser ensuite l'accès à Maison.
- Choisir un dossier **hors iCloud et hors de ce dépôt** (par exemple
  `~/Maillage Thread`) ; ouvert à la main, Passeur Noms propose « Changer de
  dossier… » pendant 10 s après l'écriture. `noms.json` est ignoré par git :
  ne jamais le commiter.
- Dans Maillage Thread : Réglages › Noms de Maison › Choisir… (le même
  dossier). Les noms sont relus quand Passeur Noms se ferme.
  Priorité : surnom > Maison > HomeKit (`_hap._udp`) > hôte.
- Rafraîchissement : la fenêtre du graphe lance Passeur Noms en arrière-plan à
  son ouverture (si le relevé a plus de 15 min), puis toutes les heures ;
  « Rafraîchir depuis Maison » (menu ou réglages) le fait à la demande, comme
  le bouton rafraîchir du graphe dès qu'un dossier des noms est choisi. L'app
  dépose d'abord `passeur-demande.json` dans le dossier : Passeur Noms écrit
  et se ferme aussitôt, sa fenêtre ne fait que passer derrière les autres.
- Batteries : niveau, état de charge et alerte de l'accessoire lui-même, pour
  chaque accessoire de Maison qui a une batterie. La fiche de l'appareil les
  montre avec l'âge du relevé ; dans le graphe, une pastille orange en
  surbrillance signale une batterie faible (l'accessoire le dit, ou son niveau
  est de 20 % ou moins).

## Sonde (le vrai maillage)

Le Mac n'a pas de radio Thread. La **sonde** est un ESP32-C6 SuperMini branché
au Mac en USB et ajouté à Maison comme appareil Matter sur Thread (une prise
« Sonde maillage »). C'est un enfant minimal : elle écoute en permanence mais
ne relaie rien, donc elle ne change jamais le maillage qu'elle observe. Elle
envoie pour l'app les requêtes de diagnostic Thread (`DIAG_GET`) et lui rend
les réponses brutes par l'USB ; l'app les décode et reconstruit le maillage.

```sh
cd sonde && pio run        # compiler ; flasher et appairer : sonde/README.md
```

- Dans Maillage Thread : Réglages › Sonde › Port. L'app n'ouvre que le port
  choisi (le pont Halo est aussi un ESP32-C6). La sonde est retenue par son
  numéro de série USB et s'affiche sous son nom, « SONDE-01 » par défaut : le
  firmware le garde, il suit donc la carte d'un Mac à l'autre (le nom USB du
  C6 est fixé par la puce). Tout autre port s'affiche avec son numéro de
  série USB (« usbmodem… · » suivi du numéro), seul moyen de distinguer la
  sonde du pont Halo avant la première connexion. La ligne du menu prend aussi
  ce nom (« SONDE-01 : connectée · relevé il y a 2 minutes »), comme l'état
  dans Réglages › Sonde (« SONDE-01 · connectée ») ; pas pour un autre port
  en essai.
- Réglages › Sonde montre le QR code Matter de la sonde et son code
  d'appairage (4-3-4), même une fois dans Maison.
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
  répondu ; sinon d'une recherche sur tous les identifiants de routeur. Sans
  liste, pas de nouveau maillage : le dernier vieillit.
- La tournée demande ensuite à chaque routeur qui répond ses liens (avec la
  qualité dans chaque sens) et ses enfants, lit les routeurs de bordure dans
  les Network Data, et demande à chaque enfant listé dans la table d'un
  routeur son identité (ExtMac, adresses), au plus une fois par demi-heure,
  endormis compris (l'ExtMac d'un appareil Matter est son nom d'hôte).
- **Les routeurs de bordure d'Apple ne répondent jamais au diagnostic.** Le
  balayage des RLOC16 d'enfant possibles vise les routeurs qui n'ont jamais
  répondu (ceux d'Apple) ou qui se sont tus deux tournées de suite, toutes les
  30 minutes ou quand cet ensemble change ; la qualité de ces liens reste
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
  s'il est un routeur de bordure, est l'annonce dont le rôle est chef. S'il
  ne reste qu'un routeur de bordure non identifié pour une seule annonce,
  c'est lui, par élimination. Sinon, il s'affiche avec ses candidats,
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
  graphe revient aux pointillés.
- Éteindre « Sonde maillage » dans Maison suspend la sonde : pas de tournée,
  même après un redémarrage de la sonde.
- Les captures de la sonde contiennent les adresses du réseau de la maison :
  `outils/anonymiser-sonde.py` les réécrit de façon cohérente avant qu'elles ne
  deviennent des données de test (`docs/releves/2026-09-29/`).
