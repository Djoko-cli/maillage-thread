# Sonde de maillage Thread (firmware)

Un ESP32-C6 SuperMini (flash de 4 Mo), branché au Mac en USB, ou alimenté
seul et joint par le réseau Thread. La sonde entre dans le réseau Thread
comme **nœud Matter en FED non éligible routeur** (Full End Device) : elle
reçoit en permanence mais ne relaie rien, ne devient jamais routeur ni chef,
et ne devient jamais le parent de personne. Elle fabrique les requêtes de
diagnostic Thread (`DIAG_GET`, CoAP `POST d/dg` vers le port TMF 61631) que
Maillage Thread lui demande, et renvoie les réponses brutes. C'est l'app qui
les décode.

En FED (depuis la 1.0.2 ; MED jusqu'à la 1.0.1), OpenThread tient la table
des routeurs de la partition et apprend l'ExtMac de ceux qu'il entend :
commande `routeurs`.

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

Pour passer une sonde déjà appairée à une nouvelle version, flasher **sans**
effacement (`-t upload` seul) : l'appairage Maison, le réseau Thread, le nom
et la clé d'accès réseau sont gardés. De la 1.0.1 à la 1.0.2, la sonde passe
de MED (`rn`) à FED (`rdn`) au démarrage et se rattache.

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
après un redémarrage ou un débranchement. Sa LED le montre (voir « LED »).

`oubli` efface la clé d'accès réseau, désappaire la sonde et la redémarre
allumée, interrupteur compris, comme à sa première mise en service (depuis
la 1.0.3 ; avant, une sonde éteinte revenait éteinte, donc suspendue après
un nouvel appairage). Retirée de Maison sans `oubli`, elle efface aussi sa
clé (un nouveau propriétaire ne garde pas l'accès de l'ancien), mais garde
l'état de son interrupteur.

## LED

Depuis la 1.0.3, la LED couleur de la carte (WS2812, sur IO8) montre
l'interrupteur « Sonde maillage », à faible intensité (24/255 au plus par
canal, comme le voyant du pont Halo) :

| LED | Signification |
|---|---|
| deux éclairs verts rapides (100 ms, 100 ms de pause) | l'interrupteur vient de s'allumer dans Maison |
| un éclair orange d'une demi-seconde | l'interrupteur vient de s'éteindre |
| un bref éclair orange (100 ms) toutes les 10 s | la sonde est suspendue ; dès le démarrage si elle l'était avant |
| éteinte | la sonde est allumée |

Seule la boucle principale écrit la LED, jamais sous le verrou d'OpenThread :
le rappel de Matter ne fait que noter l'état de l'interrupteur.

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
| `bonjour` | produit (`sonde-maillage`), version, nom, MAC, appairée ou non, code d'appairage (`code`) et charge du QR code (`qr`, `MT:…`), toujours ; nom d'hôte SRP (`hote`, sans `.local`, `null` tant qu'il n'est pas connu) |
| `nom <texte>` | change le nom et le garde ; un `bonjour` à jour, ou l'erreur `syntaxe` (nom refusé) ou `ecriture` (mémoire qui refuse l'écriture) |
| `etat` | rôle, RLOC16, ExtMac, mode (`rdn`), `eligible` (`false`), parent (RLOC16, ExtMac, qualités, RSSI), partition, chef, canal, préfixe du réseau maillé, `xp`, suspendue |
| `voisins` | routeurs voisins à lien établi (le parent n'y est pas : voir `etat`) |
| `routeurs` | table des routeurs d'OpenThread : `{"v":1,"t":"routeurs","liste":[{"id":…,"rloc16":"XXXX","ext":"<16 hexa>"\|null,"lqIn":…,"lqOut":…,"age":…,"lien":…}],"suite":…}`, plusieurs lignes si besoin (`"suite":true` sur toutes sauf la dernière) |
| `diag <cible> <t,t,…> <id> [<délai ms>]` | TLV de la réponse en hexa, ou l'erreur : `delai`, `suspendue`, `occupee` (8 requêtes en vol), `envoi…` |
| `cle` | `{"v":1,"t":"cle","empreinte":"<8 hexa>"\|null,…}`, avec `effacement_en_echec`, le nom d'hôte, les compteurs du transport (`udp`, dont `lignes_perdues` et `refus_cadence`) et le tas (`tas`) |
| `cle efface` | efface la clé (plus d'accès réseau) ; la réponse de `cle`, ou l'erreur `ecriture` |
| `cle nouvelle <64 HEXA> <id>` | nouvelle clé (réservé à l'app) : `{"v":1,"t":"cle","id":<id>,"cle":"<64 HEXA>","empreinte":"<8 hexa>","hote":…}`, **une seule fois** ; sans `id` : erreur `syntaxe` ; clé écrite mais pas chargée : un `msg` en plus |
| `oubli` | efface la clé, désappaire et redémarre : `{"v":1,"t":"oubli","cle_effacee":true\|false}` |

`<cible>` est un RLOC16 en 4 hexa, ou une adresse IPv6 du réseau maillé :
chiffres hexa, `:` et `.` seulement, sinon `syntaxe`. `<id>` et
`<délai ms>` sont des entiers décimaux de 10 chiffres au plus (4294967295
au plus), sinon `syntaxe` (depuis la 1.0.3). Le délai va de 3 à 60 s, 45 s
par défaut ; l'échec `delai` tombe à son terme (depuis la 1.0.3 : un délai
de 10 à 15 s n'est plus arrondi à 15 s).

Si la mémoire (NVS) refuse d'effacer la clé (`cle efface`, retrait de Maison),
la clé quitte la mémoire vive (plus d'accès réseau) mais reviendrait au
démarrage : `cle` le dit (`effacement_en_echec`), et la sonde réessaie toutes
les 500 ms. `oubli` le dit par `cle_effacee` (`false` : la clé reviendra après
le redémarrage ; `cle efface` ensuite).

En FED, `routeurs` donne tous les routeurs de la partition (leur RLOC16),
l'ExtMac de ceux que la sonde entend : trois viennent en quelques secondes,
les autres au fil des minutes. L'entrée du parent n'a jamais d'ExtMac (voir
`etat`). `age` n'a de sens que pour un routeur entendu.

## Accès par le réseau Thread

Repris tel quel du pont Halo de benq (`src/net_udp.cpp`, `src/h1_proto.cpp`,
`docs/PROTOCOLE-JSON.md`, section 10) : la sonde peut être débranchée du Mac
et promenée dans la maison, l'app la joint par le réseau.

- **UDP sur IPv6, port 5480**, socket d'OpenThread, par l'adresse OMR de la
  sonde, à travers les routeurs de bordure. L'app vise `<hote>.local:5480`
  (`hote` : le nom d'hôte SRP que Matter enregistre, donné par `bonjour`). Le
  Mac a besoin d'une route vers le préfixe OMR : voir « Route vers le réseau
  Thread » dans le README du dépôt.
- **Clé** de 32 octets, créée par l'USB seulement (`cle nouvelle`) :
  `cle = HMAC-SHA256(clé = aléa de l'app, message = aléa de la carte)`,
  gardée en NVS, rendue une seule fois, jamais imprimée ailleurs. Une
  nouvelle clé ou son effacement fait tomber toutes les sessions.
- **Enveloppe H1** du pont Halo : poignée de main `SALUT`/`DEFI`, puis
  messages `H1 <sid> <ctr> <mac> <charge>` (HMAC-SHA256 tronqué, sens `A`/`C`,
  fenêtre de 32 contre le rejeu, 2 `DEFI` par seconde au plus, 2 sessions et
  une provisoire, comparaisons en temps constant). Intégrité et authenticité,
  **pas de confidentialité** : le trafic se lit sur le réseau local.
- **Charges** : vers la sonde `<rid> <commande>` (le même texte que sur
  l'USB) ; en retour `<rid> <ligne JSON>` (la ligne de l'USB sans RS ni LF),
  1100 octets au plus. `routeurs` se coupe plus tôt (`suite`) : une ligne
  perdue en route donne une table partielle, ou aucune si la dernière
  (`"suite":false`) se perd ; l'app en tient compte. Un
  `diag` trop long répond `{"v":1,"t":"diag","id":…,"cible":…,"ok":false,"erreur":"trop_long"}` ;
  `voisins` au-delà de 1100 octets répond
  `{"v":1,"t":"erreur","erreur":"ligne trop longue"}` (entier sur l'USB).
- **Permis à distance** : `bonjour` (sans code d'appairage ni QR code :
  `null`), `etat`, `voisins`, `routeurs`, `diag`. Tout le reste répond
  `{"v":1,"t":"erreur","erreur":"refuse"}`.
- **Un rid répété** dans la même session ne relance rien : la sonde renvoie
  la réponse gardée (les 8 dernières réponses, dans la limite de 4096 octets
  par session ; au-delà, un rid répété relance la commande, une lecture), ou
  ne dit rien si un `diag` de ce rid est encore en vol. Prendre un rid neuf
  par requête.
- **Cadence** : 20 commandes par seconde glissante et par session au plus
  (comme Halo) ; au-delà, rien n'est exécuté ni répondu, l'app renvoie.
  L'app, elle, envoie au plus 18 nouvelles commandes par seconde glissante ;
  ses renvois ne comptent pas dans ces 18. La carte compte ses refus depuis
  le démarrage (`udp.refus_cadence` de `cle`, depuis la 1.0.3) : ce compteur
  dit si la marge suffit.
- **Sans clé : silence total**, ni réponse ni ICMPv6 « port injoignable »
  (le port reste tenu par OpenThread).
- Débit plafonné comme Halo (3000 octets/s, priorité basse, réserve de
  tampons OpenThread). Une réponse que la file d'émission ne prend pas est
  perdue en route (`udp.lignes_perdues` de `cle`) mais gardée : le renvoi
  du rid la rattrape.

## Outils d'essai

- `sonde_essai.py <port> <capture.jsonl> <commande>…` : envoie des commandes
  par l'USB, garde les réponses, décode les TLV et la table des routeurs.
  `"cle nouvelle"` : l'outil tire l'aléa et range la clé dans le fichier
  `SONDE_CLE` (0600) ; il ne lit alors rien à l'écran de ce qui arrive. La
  clé n'est jamais affichée ni capturée : toute ligne reçue affichée telle
  quelle (abîmée, journal de la carte) a ses suites de 16 hexa ou plus
  masquées.
- `sonde_essai.py udp:<hote> <capture.jsonl> <commande>…` : les mêmes
  commandes par le réseau (H1, renvoi du même rid à 2 s et 4 s). Clé :
  `SONDE_CLE`, sinon le trousseau (service `fr.djoko.maillage.sonde`, compte
  = nom d'hôte, la clé de l'app). `refus` vérifie le port (DELAI attendu,
  avec ou sans clé).
- `tournee_essai.py <port> <capture.jsonl>` : une tournée à la main par
  l'USB (chef, routeurs, quelques enfants).

Les captures brutes contiennent les adresses du réseau de la maison. À passer
par `outils/anonymiser-sonde.py` avant de les mettre dans le dépôt.

## Tests sur le Mac

`sh sonde/test/lancer.sh` : les tests hôte purs, sans carte (clang, ASan et
UBSan ; ce ne sont pas des tests `pio test`) : l'enveloppe H1
(`test_h1.cpp`, repris de benq) et les briques pures de `distant.cpp`
(`test_distant.cpp` : rid, liste blanche, réponses gardées, cadence ; depuis
la 1.0.3, lecture des entiers, reprises CoAP d'un `diag` et séquence de la
LED).
