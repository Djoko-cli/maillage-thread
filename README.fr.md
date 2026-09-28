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
principale*, pas « répond » : l'app ne sonde jamais. Une disparition n'est
retenue qu'après 2 minutes d'absence et datée de la première absence. Les
vrais liens (enfant → parent, routeur ↔ routeur, qualité) viendront d'une
sonde ESP32-C6 dédiée (étape 2, projet séparé).

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
notifié. Les noms de Maison de la démo sont inventés.

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
| `MaillageThread/Noms/` | noms de Maison : dossier choisi une fois (signet à portée de sécurité), lecture de `noms.json`, derniers noms gardés, lancement de Passeur Noms |
| `MaillageThread/Recenseur/` | NWBrowser (trois types de service) et dns_sd (hôtes, adresses) → `Annonces` |
| `MaillageThread/Surveillance/` | modèle de l'app : relevés → suivi → journal et notifications ; veille du Mac ; ouverture à la connexion |
| `MaillageThread/Vues/` | barre des menus, fenêtre du graphe (Canvas, surcouches en verre), journal, réglages |
| `Passeur/` | Passeur Noms : app iOS lancée sur le Mac (« conçue pour iPad ») qui lit Maison et écrit `noms.json` |
| `docs/releves/` | relevés réels (les données des tests et de la démo) |
| `docs/superpowers/` | conception (spec) et plans d'implémentation |

## Noms de Maison (Passeur Noms)

HomeKit n'existe pas en macOS natif, et une équipe de développement Apple
gratuite ne peut pas le donner à une app Mac Catalyst. Les noms de Maison
viennent donc de **Passeur Noms**, une petite app iOS lancée sur le Mac
(« conçue pour iPad ») : elle lit Maison (noms, pièces, fabricants,
`matterNodeID`), écrit `noms.json` dans un dossier choisi une fois, et se
ferme.

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
  `~/Maillage Thread`) ; « Changer de dossier… » reste proposé 10 s après
  l'écriture. `noms.json` est ignoré par git : ne jamais le commiter.
- Dans Maillage Thread : Réglages › Noms de Maison › Choisir… (le même
  dossier). Les noms sont relus quand Passeur Noms se ferme ; « Rafraîchir les
  noms de Maison » (menu ou réglages) le relance. Priorité : surnom > Maison >
  HomeKit (`_hap._udp`) > hôte.
