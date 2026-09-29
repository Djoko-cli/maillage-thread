# Sonde de maillage Thread (firmware)

Un ESP32-C6 SuperMini (flash de 4 Mo), branché au Mac en USB. La sonde entre
dans le réseau Thread comme **nœud Matter en MED** : elle reçoit en permanence
mais ne relaie rien, et ne devient jamais le parent de personne. Elle fabrique
les requêtes de diagnostic Thread (`DIAG_GET`, CoAP `POST d/dg` vers le port
TMF 61631) que Maillage Thread lui demande, et renvoie les réponses brutes.
C'est l'app qui les décode.

Spec : `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`.

## Compiler et flasher

Chaîne calée sur benq : pioarduino `55.03.312-1` (Arduino-ESP32 3.3.12,
ESP-IDF 5.5.5, Matter 1.5).

```sh
cd sonde
pio run                                         # compile
pio run -t erase --upload-port /dev/cu.usbmodemXXXX    # premier flash : effacement
pio run -t upload --upload-port /dev/cu.usbmodemXXXX
```

**Toujours désigner le port de la sonde.** Le pont Halo de benq est lui
aussi un C6 : le flasher par erreur le remplacerait. Le numéro de série USB
d'un C6 est son adresse MAC (`ioreg -p IOUSB -l | grep "USB Serial Number"`).

## Appairer à Maison

Au démarrage, et à la commande `bonjour`, la sonde donne son code
d'appairage et la charge de son QR code (`MT:…`), même une fois dans Maison
(depuis la 1.0.1 ; la 1.0.0 ne les donnait qu'avant l'appairage). Maillage
Thread les montre dans Réglages › Sonde : le QR code, et le code mis en forme
4-3-4 (par exemple `1234-567-8901`).
1. Dans Maison sur l'iPhone : « + » › Ajouter un accessoire › Plus d'options.
2. Saisir le code, ou scanner le QR code.
3. Maison dit « accessoire non certifié » : ajouter quand même.

La sonde apparaît comme une prise « Sonde maillage », allumée par défaut.
Éteinte, elle refuse les requêtes de diagnostic (`suspendue`). Son état est
gardé d'un démarrage à l'autre : éteinte dans Maison, elle reste suspendue
après un redémarrage ou un débranchement.

`oubli` la désappaire et la redémarre.

## Nom

La sonde a un nom, « SONDE-01 » par défaut, gardé dans sa mémoire (NVS, à
côté de l'état de l'interrupteur) : il suit la carte d'un Mac à l'autre.
Maillage Thread le montre à la place du port (« SONDE-01 » plutôt que
« usbmodem11301 »). `nom <texte>` le change : 1 à 32 caractères parmi les
lettres ASCII, les chiffres, `-`, `_` et `.`. L'app n'a pas encore de quoi le
changer.

## Protocole USB

Une commande par ligne. En retour, des lignes machine : RS (0x1E), JSON
compact en ASCII, LF, 4096 octets au plus. Pour ouvrir le port sans redémarrer
le C6, il faut mettre DTR et RTS à 0 dans un seul appel (voir benq).

| Commande | Réponse |
|---|---|
| `bonjour` | produit (`sonde-maillage`), version, nom, MAC, appairée ou non, code d'appairage (`code`) et charge du QR code (`qr`, `MT:…`), toujours |
| `nom <texte>` | change le nom et le garde ; un `bonjour` à jour, ou l'erreur `syntaxe` (nom refusé) ou `ecriture` (mémoire qui refuse l'écriture) |
| `etat` | rôle, RLOC16, ExtMac, mode, parent (RLOC16, ExtMac, qualités, RSSI), partition, chef, canal, préfixe du réseau maillé, `xp`, suspendue |
| `voisins` | voisins entendus (le parent, pour un MED) |
| `diag <cible> <t,t,…> <id> [<délai ms>]` | TLV de la réponse en hexa, ou l'erreur : `delai`, `suspendue`, `occupee` (8 requêtes en vol), `envoi…` |
| `oubli` | désappaire et redémarre |

`<cible>` est un RLOC16 en 4 hexa, ou une adresse IPv6 du réseau maillé. Le
délai va de 3 à 60 s, 45 s par défaut.

## Outils d'essai

- `sonde_essai.py <port> <capture.jsonl> <commande>…` : envoie des commandes,
  garde les réponses, décode les TLV.
- `tournee_essai.py <port> <capture.jsonl>` : une tournée à la main (chef,
  routeurs, quelques enfants).

Les captures brutes contiennent les adresses du réseau de la maison. À passer
par `outils/anonymiser-sonde.py` avant de les mettre dans le dépôt.
