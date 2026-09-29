# Maillage Thread, plan 3a : la sonde et le vrai maillage : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** dessiner les vrais liens du réseau Thread au lieu des pointillés vers le chef : entre routeurs, avec la qualité dans chaque sens, et de chaque enfant vers son parent. Une sonde ESP32-C6 branchée en USB les relève.

**Architecture :**
- **La sonde** (`sonde/`, firmware 1.0.0) : un ESP32-C6 en MED, appairé à Maison. Elle envoie les `DIAG_GET` que l'app lui demande (CoAP `POST d/dg` au port TMF 61631), jusqu'à 8 à la fois, et rend les TLV bruts par l'USB.
- **Le cœur** (`MaillageCoeur/Maillage/`, Swift pur, testé sur la capture anonymisée de l'essai) :
  - décodage des TLV et des Network Data ;
  - protocole USB ;
  - tournée : routeurs qui répondent, et balayage des enfants des routeurs muets ;
  - construction du maillage et rapprochement avec l'instantané de l'étape 1 ;
  - disposition du graphe.
- **L'app** (`MaillageThread/Sonde/`) :
  - liaison série sans redémarrer le C6 ;
  - port choisi dans les Réglages et retenu par son numéro de série USB ;
  - une tournée toutes les 5 minutes, dont le maillage va à `Surveillance`. Le graphe, la fiche, le menu et les Réglages l'affichent.

**Tech Stack :**
- **App :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI, Observation, Synchronization (`Mutex`), IOKit (ports USB), termios, Swift Testing, XcodeGen.
- **Firmware :** PlatformIO pioarduino `55.03.312-1` (Arduino-ESP32 3.3.12, ESP-IDF 5.5.5, Matter 1.5), CoAP d'OpenThread.

**Spec :** `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, révisée le 29/09 après l'essai (section 8), à lire avec ce plan. Ce plan couvre 3a ; le journal et l'historique (section 6) seront le plan 3b.

**Code validé avant exécution.** Le 29/09, tout le code de ce plan a été écrit, compilé et testé dans une copie du dépôt :
- 122 tests pour le cœur et 55 pour l'app, tous verts ;
- le firmware 1.0.0 compile ;
- le plan a ensuite été rejoué tâche par tâche sur une copie neuve de `essai-sonde`. Les résultats attendus ci-dessous viennent de ce rejeu : l'erreur avant le code, les tests après, et la liste du `git add`, qui couvre chaque fichier touché. L'arbre final est identique à la copie validée.

Ces effectifs et ces blocs sont ceux d'avant l'exécution : des relectures ont ensuite corrigé le code. La section « Écarts d'exécution (29/09) », à la fin du plan, liste ces corrections, les blocs qu'elles dépassent et les effectifs de tests à jour.

Exécuter une tâche, c'est transcrire les fichiers et les blocs donnés, compiler et tester. Si un fichier doit s'écarter du texte donné, l'exécutant le dit dans son rapport, avec la raison.

**Blocs de modification.** Un fichier existant est modifié soit en entier (« fichier entier ci-dessous »), soit par blocs « remplacer … par … ». Chaque texte à remplacer apparaît une seule fois dans le fichier au moment où on l'applique. Les blocs s'appliquent dans l'ordre, du haut vers le bas, au texte exact, espaces compris (outil Edit).

**Faits établis par l'essai (29/09), utiles à l'exécution :**
- **Diagnostic :**
  - les 5 routeurs de bordure d'Apple ne répondent jamais au `DIAG_GET` ;
  - les routeurs EFR32 répondent en 40 à 120 ms ;
  - les enfants répondent à leur RLOC16, en 0,2 à 5 s pour un endormi, mais jamais à leur adresse OMR (le TMF n'accepte que les adresses du réseau maillé).
- **Balayage :** balayer les RLOC16 d'enfant sous un routeur muet marche ; un numéro vide échoue au bout du délai.
- **TLV :** 25 à 27 vides, 28 (la pile) remplie, 29 à 31 absentes.
- **Identité :** l'ExtMac d'un appareil Matter est son nom d'hôte mDNS.
- **Port série :** TIOCEXCL, puis DTR = RTS = 0 **en un seul** `TIOCMSET`, puis termios brut sans HUPCL. RTS = 1 avec DTR = 0 redémarre le C6.

**Écarts à la spec (assumés) :**
1. **Pas de nom « fabricant et modèle »** (spec, section 5, noms, 3ᵉ priorité), car les TLV 25 à 27 sont vides. Un nœud que seule la sonde connaît s'appelle « Routeur de bordure · B400 », « Routeur · 5000 » ou « Non identifié · AC05 ». La version de la pile (TLV 28) est gardée par routeur (`RouteurMaillage.pile`).
2. **Fiche en une ligne :**
   - un enfant : « RLOC16 5004 · parent HomePod bureau, qualité 3 » ;
   - un routeur : « RLOC16 5000 · voisins : 4 · enfants : 2 ».

   Plus tard : le détail de chaque voisin avec la qualité dans chaque sens, le délai d'un endormi et la version de Thread. Les couleurs des liens du graphe montrent déjà les qualités.
3. **Changement de chef ou de partition :** il est vu à la tournée suivante, 5 minutes au plus ; `etat` n'est pas surveillé entre deux tournées. Une autre partition remet la mémoire de la tournée à zéro, car les identifiants de routeur y sont redistribués.
4. **Cibles :** l'app n'envoie que des RLOC16. Le firmware accepte aussi une adresse IPv6 du réseau maillé, qui a servi à l'essai.
5. **`voisins` :** la commande est dans le firmware et décodée par `MessageSonde`, mais la tournée ne s'en sert pas.

## Global Constraints

- **Plateformes :** app en macOS 26.0 minimum, développée avec Xcode 27 sous macOS 27 ; XcodeGen 2.45 ou plus.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`. Notamment, `Text + Text` est déprécié dans le SDK de macOS 26, donc refusé.
- **Code :** identifiants et commentaires en français **sans accents** ; textes affichés avec accents ; tests en Swift Testing. Les nouveaux dossiers (`MaillageCoeur/Maillage/`, `MaillageThread/Sonde/`) sont pris par les sources de `project.yml` sans le modifier.
- **Textes de l'app :** catalogue `MaillageThread/Ressources/Localizable.xcstrings`, français source et anglais obligatoire. Une tâche qui ajoute des textes synchronise elle-même le catalogue, dans cet ordre :
  1. compiler ;
  2. `outils/synchroniser-textes.sh` ;
  3. ajouter les traductions à `outils/traductions/interface.json` ;
  4. `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`.

  Le test `CataloguesTests` refuse une clé absente comme une clé morte.
- **Commandes,** depuis la racine du dépôt :
  - `outils/tester.sh [cibles…]` génère le projet, compile et lance les tests. Les produits vont dans `$HOME/Library/Developer/Xcode/DerivedData/maillage` (variable `DD`), le journal dans `$TMPDIR/maillage-tests.log` ;
  - le firmware se compile par `pio run` dans `sonde/` (`~/.platformio/penv/bin/pio` si `pio` n'est pas dans le `PATH`).
- **Carte et ports série :** de la tâche 1 à la tâche 11, **aucun agent n'ouvre un port série ni ne flashe** :
  - pas de `pio run -t upload`, ni de `pio device monitor`, ni d'`esptool` ;
  - pas de `sonde/sonde_essai.py`, ni de `sonde/tournee_essai.py` ;
  - l'app n'est jamais lancée en mode direct.

  Le pont Halo, branché au même Mac, est lui aussi un ESP32-C6 : l'ouvrir peut le redémarrer. Le flash de la sonde se fait à la tâche 12, par le contrôleur, avec Djoko, sur le port qu'il désigne.
- **Données personnelles** (le dépôt est public sur GitHub, `Djoko-cli/maillage-thread`) :
  - les captures brutes (`docs/releves/**/capture-*-essai.jsonl`) ne sont jamais commitées, et `.gitignore` les exclut dès la tâche 1 ;
  - les données de test viennent seulement de la capture anonymisée ;
  - aucune ExtMac, aucun préfixe, aucune MAC ni aucun code d'appairage du vrai réseau dans un fichier commité ;
  - `noms.json` et `passeur-demande.json` ne sont jamais commités.
- **Signature :** l'app reste ad hoc (`Signature.xcconfig`). **Ne jamais créer `Local.xcconfig`.** Aucun identifiant d'équipe, empreinte de certificat ni adresse électronique dans un fichier commité.
- **Commits :**
  - un par tâche, message en français sans accents, terminé par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ;
  - `git add` avec la liste de fichiers de la tâche, **jamais `git add -A` ni `git add .`** ;
  - jamais de push.
- **Interdits pour les agents :**
  - `sudo` ;
  - ouvrir un port série ou flasher (voir plus haut) ;
  - lancer l'app en mode direct ;
  - lancer le passeur ;
  - réveiller l'écran.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `outils/anonymiser-sonde.py`, `docs/releves/2026-09-29/` | anonymisation de la capture de l'essai ; capture anonymisée et son README | 1 |
| `sonde/sonde_essai.py`, `sonde/tournee_essai.py` | outils d'essai par l'USB (jamais lancés par un agent) | 1 |
| `MaillageCoeur/Maillage/DiagnosticThread.swift` | TLV du diagnostic : Route64, Leader Data, Child Table, adresses, version, pile | 2 |
| `MaillageCoeurTests/Banc.swift` | `CaptureSonde` (2), `routeur(… xa:)` (7) | 2, 7 |
| `MaillageCoeur/Maillage/DonneesReseau.swift` | Network Data : routeurs de bordure, BBR, OMR | 3 |
| `MaillageCoeur/Maillage/ProtocoleSonde.swift` | protocole USB : messages, commandes, découpe des lignes | 4 |
| `MaillageCoeur/Maillage/Maillage.swift` | modèle du maillage et sa construction | 5 |
| `MaillageCoeur/Maillage/Tournee.swift` | tournée, mémoire, balayage des routeurs muets | 6 |
| `MaillageCoeur/Maillage/Rapprochement.swift` | ids du graphe pour les nœuds de la sonde | 7 |
| `MaillageCoeur/Disposition/Disposition.swift` | anneaux avec les routeurs de la sonde, liens radio et enfant-parent | 7 |
| `sonde/src/main.cpp`, `sonde/platformio.ini`, `sonde/README.md` | firmware 1.0.0 | 8 |
| `MaillageThread/Sonde/PortSerie.swift`, `LiaisonSerie.swift`, `PortsUSB.swift` | port série, liaison, ports USB | 9 |
| `MaillageThread/Droits.entitlements` | `com.apple.security.device.serial` | 9 |
| `MaillageThread/Sonde/SondeUSB.swift`, `SondeMaillage.swift` | la sonde : commandes, tournée toutes les 5 min, état pour l'app | 10 |
| `MaillageCoeur/Demo/MaillageDemo.swift` | maillage inventé de la démo | 10 |
| `MaillageThread/Surveillance/Surveillance.swift`, `MaillageThread/MaillageThreadApp.swift` | maillage et fraîcheur ; branchement de la sonde | 10 |
| `MaillageThread/Vues/Graphe/Palette.swift`, `GrapheCanvas.swift`, `FenetreGraphe.swift`, `FicheNoeud.swift` | liens colorés, noms des nœuds inconnus, légende, fiche | 11 |
| `MaillageThread/Vues/MenuBarre.swift`, `MaillageThread/Vues/FenetreReglages.swift` | ligne du menu, Réglages › Sonde | 11 |
| `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` | anglais des nouveaux textes | 9, 10, 11 |
| `README.md`, `README.fr.md`, spec de la sonde | mode d'emploi, lien vers ce plan, vérification | 12 |

---

### Task 1: Données de test : capture anonymisée, outils d'essai

**Files:**
- Create: `outils/anonymiser-sonde.py`, `docs/releves/2026-09-29/README.md`, `sonde/sonde_essai.py`, `sonde/tournee_essai.py`
- Modify: `.gitignore` (blocs ci-dessous)
- Create (par l'anonymiseur) : `docs/releves/2026-09-29/capture-sonde.jsonl`

**Interfaces:**
- Consumes : la capture brute `docs/releves/2026-09-29/capture-sonde-essai.jsonl`, écrite pendant l'essai par `sonde/sonde_essai.py`. Elle n'existe que dans le dépôt principal, sur le Mac de Djoko, et **n'est jamais commitée**.
- Produces :
  - `docs/releves/2026-09-29/capture-sonde.jsonl` : 64 messages anonymisés, lus par `CaptureSonde` (tâche 2) et rejoués par `SondeRejouee` (tâche 6). Les réponses `diag` s'y repèrent par leur `id` (voir le README du dossier) ;
  - `outils/anonymiser-sonde.py <brute> <anonyme>` ;
  - les outils d'essai `sonde/sonde_essai.py` et `sonde/tournee_essai.py`, qui parlent à la sonde par l'USB. Aucun agent ne les lance ;
  - la règle `.gitignore` des captures brutes.

- [ ] **Step 1 : exclure les captures brutes du dépôt, puis écrire les outils et le README des données.**

Dans `.gitignore`, remplacer :

```gitignore
sonde/.vscode/
```

par :

```gitignore
sonde/.vscode/

# Captures brutes de la sonde (adresses du reseau de la maison) : jamais dans le depot
docs/releves/**/capture-*-essai.jsonl
```

`outils/anonymiser-sonde.py` :

```python
#!/usr/bin/env python3
"""Anonymise une capture de la sonde (JSON Lines) avant d'en faire des donnees de test.

  python3 outils/anonymiser-sonde.py <capture brute.jsonl> <capture anonyme.jsonl>

Remplace, de facon coherente d'une ligne a l'autre et jusque dans les TLV de
diagnostic :
- les ExtMac (TLV 0, parent de `etat`), et les adresses lien-local qui en
  derivent ;
- les prefixes IPv6 (/48 : reseau maille, OMR, NAT64...) et les identifiants
  d'interface, sauf ceux des RLOC et ALOC (0000:00ff:fe00:xxxx), gardes ;
- le `xp`, la MAC de la sonde, le code d'appairage ;
- les adresses des Network Data (prefixes, donnees de serveur).
Garde les RLOC16, partitions, qualites, delais et versions de pile.
Aucune valeur reelle n'est ecrite dans ce script : il les repere dans la
capture. A la fin, il verifie qu'aucune ne reste dans la sortie.
"""
import ipaddress
import json
import sys

MAILLE_RLOC = bytes.fromhex("000000fffe00")


class Anonymiseur:
    def __init__(self):
        self.exts = {}      # ExtMac reelle (8 octets) -> factice
        self.iids = {}      # identifiant d'interface reel -> factice
        self.p48 = {}       # /48 reel (6 octets) -> factice
        self.xp = {}
        self.macs = {}

    # --- Tables de correspondance ------------------------------------------

    def ext(self, e):
        if e not in self.exts:
            self.exts[e] = bytes.fromhex("E0%014X" % (len(self.exts) + 1))
        return self.exts[e]

    def iid(self, i):
        if i not in self.iids:
            self.iids[i] = bytes.fromhex("0A00%012X" % (len(self.iids) + 1))
        return self.iids[i]

    def prefixe48(self, p):
        if p not in self.p48:
            n = len(self.p48)
            self.p48[p] = bytes.fromhex("FD00%04X%04X" % (0x1111 * (2 * n + 1) & 0xFFFF, 0x1111 * (2 * n + 2) & 0xFFFF))
        return self.p48[p]

    def adresse(self, a):
        """Adresse IPv6 de 16 octets."""
        if a[:8] == bytes.fromhex("FE80000000000000"):
            # Lien-local Thread : identifiant tire de l'ExtMac (bit U/L inverse).
            e = bytes([a[8] ^ 0x02]) + a[9:]
            f = self.ext(e)
            return a[:8] + bytes([f[0] ^ 0x02]) + f[1:]
        tete = self.prefixe48(a[:6]) + a[6:8]
        if a[8:14] == MAILLE_RLOC:
            return tete + a[8:]
        return tete + self.iid(a[8:])

    # --- TLV de diagnostic -------------------------------------------------

    def tlv(self, hexa):
        o, i, sortie = bytes.fromhex(hexa), 0, b""
        while i + 2 <= len(o):
            t, n = o[i], o[i + 1]
            v = o[i + 2:i + 2 + n]
            if t == 0 and n == 8:
                v = self.ext(v)
            elif t == 8:
                v = b"".join(self.adresse(v[k:k + 16]) for k in range(0, n - 15, 16))
            elif t == 7:
                v = self.donnees_reseau(v)
            sortie += bytes([t, n]) + v
            i += 2 + n
        return sortie.hex().upper()

    def donnees_reseau(self, o):
        """Network Data : prefixes des TLV Prefix, adresses des donnees de serveur."""
        i, sortie = 0, b""
        while i + 2 <= len(o):
            t, n = o[i] >> 1, o[i + 1]
            v = bytearray(o[i + 2:i + 2 + n])
            if t == 1 and len(v) >= 2:  # Prefix : domaine, longueur en bits, prefixe, sous-TLV
                octets = (v[1] + 7) // 8
                if octets >= 6:
                    v[2:8] = self.prefixe48(bytes(v[2:8]))
            elif t == 5 and len(v) >= 1:  # Service : donnees, puis sous-TLV Server
                j = 1 if v[0] & 0x80 else 5
                if j < len(v):
                    j += 1 + v[j]
                    while j + 2 <= len(v):
                        st, sn = v[j] >> 1, v[j + 1]
                        if st == 6 and sn >= 2 + 16:  # Server : RLOC16, puis une adresse
                            v[j + 4:j + 20] = self.adresse(bytes(v[j + 4:j + 20]))
                        j += 2 + sn
            sortie += bytes([o[i], n]) + bytes(v)
            i += 2 + n
        return sortie

    # --- Messages de la sonde ----------------------------------------------

    def message(self, m):
        m = dict(m)
        t = m.get("t")
        if t == "bonjour":
            if m.get("mac"):
                mac = m["mac"]
                self.macs.setdefault(mac, "A0000000%04X" % (len(self.macs) + 1))
                m["mac"] = self.macs[mac]
            m["code"] = None
            m["qr"] = None
        elif t == "etat":
            if m.get("xp"):
                self.xp.setdefault(m["xp"], "A0A1A2A3A4A5A6A7")
                m["xp"] = self.xp[m["xp"]]
            if m.get("prefixeMaille"):
                p = bytes.fromhex(m["prefixeMaille"])
                m["prefixeMaille"] = (self.prefixe48(p[:6]) + p[6:8]).hex().upper()
            if m.get("parent") and m["parent"].get("ext"):
                par = dict(m["parent"])
                par["ext"] = self.ext(bytes.fromhex(par["ext"])).hex().upper()
                m["parent"] = par
        elif t == "diag":
            cible = m.get("cible", "")
            if ":" in cible:
                m["cible"] = str(ipaddress.IPv6Address(self.adresse(ipaddress.IPv6Address(cible).packed)))
            if m.get("tlv"):
                m["tlv"] = self.tlv(m["tlv"])
        return m

    def secrets(self):
        """Valeurs reelles, en texte, a ne plus trouver dans la sortie."""
        s = set()
        for e in self.exts:
            s.add(e.hex())
            s.add((bytes([e[0] ^ 0x02]) + e[1:]).hex())
        for i in self.iids:
            s.add(i.hex())
        for p in self.p48:
            s.add(p.hex())
            s.add(str(ipaddress.IPv6Address(p + bytes(10))).split("::")[0])
        s.update(x.lower() for x in self.xp)
        s.update(x.lower() for x in self.macs)
        return {x.lower() for x in s if len(x) >= 8}


def main():
    entree, sortie = sys.argv[1], sys.argv[2]
    a = Anonymiseur()
    messages = [json.loads(l) for l in open(entree, encoding="utf-8") if l.strip()]
    # Le prefixe du reseau maille (sonde attachee) d'abord : il recoit toujours
    # le premier /48 factice.
    for m in messages:
        if m.get("t") == "etat" and m.get("prefixeMaille") and m.get("role") in ("child", "router", "leader"):
            a.prefixe48(bytes.fromhex(m["prefixeMaille"])[:6])
            break
    lignes = [json.dumps(a.message(m), ensure_ascii=False, sort_keys=True) for m in messages]
    texte = "\n".join(lignes) + "\n"
    minuscule = texte.lower()
    brut = texte.lower().replace(":", "")
    fuites = [s for s in a.secrets() if s in minuscule or s in brut]
    if fuites:
        sys.exit("fuite : %d valeur(s) reelle(s) encore presente(s)" % len(fuites))
    open(sortie, "w", encoding="utf-8").write(texte)
    print("%d lignes ; %d ExtMac, %d identifiants, %d prefixes /48 remplaces" %
          (len(lignes), len(a.exts), len(a.iids), len(a.p48)))


if __name__ == "__main__":
    main()
```

`docs/releves/2026-09-29/README.md` :

```markdown
# Capture de la sonde, nuit du 28 au 29/09/2026 (23:44-00:30, heure du Mac)

Essai préalable au plan 3a (spec de la sonde, sections 7 et 8) : la troisième
carte ESP32-C6, avec le firmware d'essai de `sonde/`, appairée à Maison, puis
interrogée par l'USB. Données des tests de `MaillageCoeur/Maillage`.

| Fichier | Contenu | Obtenu par |
|---|---|---|
| `capture-sonde.jsonl` | 64 messages de la sonde (2 `bonjour`, 9 `etat`, 53 `diag`), un par ligne, avec l'heure de réception : tournée d'essai (chef, 7 routeurs, 3 enfants), Network Data, essais vers les adresses OMR, balayage des enfants de `AC00` | `sonde/sonde_essai.py` et `sonde/tournee_essai.py`, puis `outils/anonymiser-sonde.py` |

**Anonymisée** (décision de Djoko, 29/09). Les valeurs d'origine sont
remplacées de façon cohérente d'une ligne à l'autre, jusque dans les TLV :
- les ExtMac, en `E0…`, et les adresses lien-local qui en dérivent ;
- les préfixes /48, en `fd00:…` :
  - `fd00:1111:2222` pour le réseau maillé ;
  - `fd00:5555:6666` pour l'OMR et le NAT64 ;
  - `fd00:3333:4444` pour le préfixe par défaut d'OpenThread, avant l'appairage ;
- les identifiants d'interface, sauf ceux des RLOC et ALOC ;
- le `xp`, la MAC de la sonde et le code d'appairage, retirés.

Les RLOC16, partitions, qualités de lien, délais et versions de pile sont
gardés. La capture brute n'est pas dans le dépôt.

Ce que la capture montre (spec de la sonde, section 8) :
- **Les 5 routeurs de bordure d'Apple ne répondent jamais** : `0400`, `AC00`,
  `B400`, `CC00` et `E400`.
- **Le chef `6000` et le routeur `5000`**, deux appareils Matter EFR32,
  répondent en 40 à 120 ms.
- **Les enfants répondent à leur RLOC** en 0,2 à 5 s, mais **jamais à leur
  adresse OMR** (ids 301 à 309).
- **Le balayage sous `AC00`** : 6 enfants de `AC03` à `AC08` (ids 501 à 512).
- **La sonde change de parent** : `E400`, puis `AC00`.
```

`sonde/sonde_essai.py` :

```python
#!/usr/bin/env python3
"""Essai de la sonde de maillage : commandes USB, capture et decodage.

  python3 sonde_essai.py <port> <capture.jsonl> <commande> [<commande> ...]

Commandes : bonjour, etat, voisins, "diag <cible> <t,t,...> <id>", ecoute:<s>
(lit <s> secondes sans rien envoyer). Chaque ligne machine (RS + JSON) est
ajoutee a la capture avec l'heure ; les reponses diag sont decodees a l'ecran.
Ouverture sure du C6 (comme benq tools/halo_udp.py) : DTR = RTS = 0 en un
seul appel, jamais RTS=1 DTR=0 qui le redemarre.
"""
import fcntl, ipaddress, json, os, select, struct, sys, termios, time


def ouvrir(chemin):
    fd = os.open(chemin, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    fcntl.ioctl(fd, termios.TIOCEXCL)
    fcntl.ioctl(fd, termios.TIOCMSET, struct.pack("I", 0))
    i, o, c, l, _, _, cc = termios.tcgetattr(fd)
    i &= ~(termios.IGNBRK | termios.BRKINT | termios.PARMRK | termios.ISTRIP | termios.INLCR | termios.IGNCR
           | termios.ICRNL | termios.IXON)
    o &= ~termios.OPOST
    l &= ~(termios.ECHO | termios.ECHONL | termios.ICANON | termios.ISIG | termios.IEXTEN)
    c &= ~(termios.CSIZE | termios.PARENB | termios.HUPCL)
    c |= termios.CS8 | termios.CLOCAL | termios.CREAD
    termios.tcsetattr(fd, termios.TCSANOW, [i, o, c, l, termios.B115200, termios.B115200, cc])
    return fd


class Lecteur:
    def __init__(self, fd, capture):
        self.fd, self.capture, self.tampon = fd, capture, b""

    def lignes(self, jusqua):
        """Lignes machine decodees jusqu'a l'echeance ; les autres sont affichees telles quelles."""
        while time.time() < jusqua:
            r, _, _ = select.select([self.fd], [], [], 0.1)
            if r:
                try:
                    self.tampon += os.read(self.fd, 4096)
                except BlockingIOError:
                    pass
            while b"\n" in self.tampon:
                brut, self.tampon = self.tampon.split(b"\n", 1)
                brut = brut.rstrip(b"\r")
                if brut.startswith(b"\x1e"):
                    try:
                        m = json.loads(brut[1:].decode("ascii"))
                    except (ValueError, UnicodeDecodeError):
                        print("?? ligne machine illisible :", brut[:120])
                        continue
                    with open(self.capture, "a") as f:
                        f.write(json.dumps({"heure": time.strftime("%Y-%m-%dT%H:%M:%S"), **m}) + "\n")
                    yield m
                elif brut.strip():
                    print("   |", brut.decode("ascii", "replace")[:160])


def nom_tlv(t):
    return {0: "ExtMac", 1: "Address16", 2: "Mode", 3: "Timeout", 4: "Connectivity", 5: "Route64", 6: "LeaderData",
            7: "NetworkData", 8: "IPv6", 9: "MacCounters", 14: "Batterie", 15: "Tension", 16: "ChildTable",
            17: "ChannelPages", 19: "MaxChildTimeout", 24: "Version", 25: "VendorName", 26: "VendorModel",
            27: "VendorSwVersion", 28: "ThreadStackVersion", 29: "Child", 30: "ChildIpv6", 31: "RouterNeighbor",
            34: "MleCounters", 35: "VendorAppUrl"}.get(t, f"TLV{t}")


def mode_texte(m):
    return ("r" if m & 0x08 else "-") + ("d" if m & 0x02 else "-") + ("n" if m & 0x01 else "-")


def decoder(hexa):
    o, i, res = bytes.fromhex(hexa), 0, []
    while i + 2 <= len(o):
        t, n = o[i], o[i + 1]
        v = o[i + 2:i + 2 + n]
        i += 2 + n
        if t == 0:
            d = v.hex().upper()
        elif t == 1:
            d = f"{int.from_bytes(v, 'big'):04X}"
        elif t == 2:
            d = mode_texte(v[0]) if v else "?"
        elif t == 5 and len(v) >= 9:
            masque = int.from_bytes(v[1:9], "big")
            ids = [r for r in range(64) if masque & (1 << (63 - r))]
            routes = []
            for r, b in zip(ids, v[9:]):
                routes.append(f"{r}(out{b >> 6} in{(b >> 4) & 3} cout{b & 15})")
            d = f"seq {v[0]} ; " + " ".join(routes)
        elif t == 6 and len(v) >= 8:
            d = f"partition {v[0:4].hex().upper()} poids {v[4]} version {v[5]}/{v[6]} chef {v[7]}"
        elif t == 8:
            d = ", ".join(str(ipaddress.IPv6Address(v[k:k + 16])) for k in range(0, len(v) - 15, 16))
        elif t == 16:
            e = []
            for k in range(0, len(v) - 2, 3):
                x = int.from_bytes(v[k:k + 2], "big")
                e.append(f"id{x & 0x1FF}(lq{(x >> 9) & 3} delai2^{(x >> 11) - 4}s {mode_texte(v[k + 2])})")
            d = f"{len(e)} enfant(s) : " + " ".join(e)
        elif t == 24:
            d = str(int.from_bytes(v, "big"))
        elif t in (25, 26, 27, 28, 35):
            d = repr(v.decode("utf-8", "replace"))
        else:
            d = v.hex().upper()
        res.append(f"{nom_tlv(t)}: {d}")
    return res


def main():
    port, capture, commandes = sys.argv[1], sys.argv[2], sys.argv[3:]
    fd = ouvrir(port)
    lecteur = Lecteur(fd, capture)
    try:
        for c in commandes:
            if c.startswith("ecoute:"):
                for m in lecteur.lignes(time.time() + float(c.split(":")[1])):
                    print(json.dumps(m, ensure_ascii=False))
                continue
            print(f">> {c}")
            os.write(fd, (c + "\n").encode("ascii"))
            attendu = c.split()[0]
            delai = 50 if attendu == "diag" else 5
            for m in lecteur.lignes(time.time() + delai):
                if m.get("t") == "diag" and m.get("ok") and "tlv" in m:
                    print(f"<< diag {m['cible']} : {m['ms']} ms, code {m.get('code')}, {len(m['tlv']) // 2} octets")
                    for ligne in decoder(m["tlv"]):
                        print("     ", ligne)
                else:
                    print("<<", json.dumps(m, ensure_ascii=False))
                if m.get("t") == "erreur":
                    break
                if m.get("t") == attendu and (attendu != "diag" or m.get("id") == int(c.split()[3])):
                    break
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()


def network_data(o):
    """Network Data (TLV 7) : prefixes, routeurs de bordure, routes et services, par RLOC16."""
    res, i = [], 0
    while i + 2 <= len(o):
        t, n = o[i] >> 1, o[i + 1]
        v = o[i + 2:i + 2 + n]
        i += 2 + n
        if t == 1 and len(v) >= 2:  # Prefix
            bits = v[1]
            pre = v[2:2 + (bits + 7) // 8]
            pre16 = pre + bytes(16 - len(pre))
            texte = f"{ipaddress.IPv6Address(pre16)}/{bits}"
            j = 2 + (bits + 7) // 8
            while j + 2 <= len(v):
                st, sn = v[j] >> 1, v[j + 1]
                sv = v[j + 2:j + 2 + sn]
                j += 2 + sn
                if st == 2:
                    res.append(f"prefixe {texte} : routeurs de bordure " + " ".join(f"{int.from_bytes(sv[k:k+2],'big'):04X}" for k in range(0, len(sv) - 3, 4)))
                elif st == 0:
                    res.append(f"prefixe {texte} : route par " + " ".join(f"{int.from_bytes(sv[k:k+2],'big'):04X}" for k in range(0, len(sv) - 2, 3)))
        elif t == 5 and len(v) >= 1:  # Service
            j = 1 if v[0] & 0x80 else 5
            if j >= len(v):
                continue
            dl = v[j]
            donnees = v[j + 1:j + 1 + dl]
            j += 1 + dl
            serveurs = []
            while j + 2 <= len(v):
                st, sn = v[j] >> 1, v[j + 1]
                if st == 6 and sn >= 2:
                    serveurs.append(f"{int.from_bytes(v[j+2:j+4],'big'):04X}")
                j += 2 + sn
            res.append(f"service {donnees.hex()} : serveurs " + " ".join(serveurs))
    return res
```

`sonde/tournee_essai.py` :

```python
#!/usr/bin/env python3
"""Tournee d'essai de la sonde (spec sonde, section 4), port deja designe.

  python3 tournee_essai.py <port> <capture.jsonl> [enfants_max]

1. etat : partition, chef, prefixe du reseau maille ;
2. au chef : Route64 (5) et Leader Data (6) : routeurs actifs ;
3. a chaque routeur (RLOC16 = id << 10) : 0,1,5,16,8,24 puis 25,26,27,28 ;
4. a quelques enfants lus dans les Child Table : 0,8,2 puis 25,26,27,28.
Tout est capture ; un resume s'affiche a la fin.
"""
import json, sys, time

import sonde_essai as s


class Sonde:
    def __init__(self, port, capture):
        self.fd = s.ouvrir(port)
        self.lecteur = s.Lecteur(self.fd, capture)
        self.id = 100

    def commande(self, texte, attendu, delai=5):
        s.os.write(self.fd, (texte + "\n").encode("ascii"))
        for m in self.lecteur.lignes(time.time() + delai):
            if m.get("t") == attendu or m.get("t") == "erreur":
                return m
        return None

    def diag(self, cible, tlv):
        self.id += 1
        t0 = time.time()
        m = self.commande(f"diag {cible} {','.join(map(str, tlv))} {self.id}", "diag", 55)
        return m, time.time() - t0


def tlv_brut(hexa):
    o, i, res = bytes.fromhex(hexa), 0, {}
    while i + 2 <= len(o):
        t, n = o[i], o[i + 1]
        res[t] = o[i + 2:i + 2 + n]
        i += 2 + n
    return res


def routeurs_de(route64):
    masque = int.from_bytes(route64[1:9], "big")
    return [r for r in range(64) if masque & (1 << (63 - r))]


def enfants_de(table, rloc_parent):
    res = []
    for k in range(0, len(table) - 2, 3):
        x = int.from_bytes(table[k:k + 2], "big")
        res.append({"rloc16": f"{rloc_parent | (x & 0x1FF):04X}", "endormi": not (table[k + 2] & 0x08)})
    return res


def afficher(titre, m, duree):
    if not m:
        print(f"   {titre} : pas de reponse ({duree:.1f} s)")
        return
    if not m.get("ok"):
        print(f"   {titre} : echec {m.get('erreur')} ({m.get('ms')} ms)")
        return
    print(f"   {titre} : {m['ms']} ms, {len(m['tlv']) // 2} octets, code {m.get('code')}")
    for ligne in s.decoder(m["tlv"]):
        print("      ", ligne[:220])


def main():
    port, capture = sys.argv[1], sys.argv[2]
    enfants_max = int(sys.argv[3]) if len(sys.argv) > 3 else 6
    sonde = Sonde(port, capture)
    etat = sonde.commande("etat", "etat")
    print("etat :", json.dumps(etat, ensure_ascii=False))
    if not etat or etat.get("chef") is None:
        print("sonde non attachee : rien a faire")
        return
    chef = f"{etat['chef'] << 10:04X}"
    m, d = sonde.diag(chef, [5, 6])
    afficher(f"chef {chef} (Route64, LeaderData)", m, d)
    if not m or not m.get("ok"):
        return
    routeurs = routeurs_de(tlv_brut(m["tlv"]).get(5, b"\0" * 9))
    print(f"routeurs actifs : {routeurs}")
    enfants = []
    for r in routeurs:
        rloc = r << 10
        m, d = sonde.diag(f"{rloc:04X}", [0, 1, 5, 16, 8, 24])
        afficher(f"routeur {rloc:04X}", m, d)
        if m and m.get("ok"):
            enfants += enfants_de(tlv_brut(m["tlv"]).get(16, b""), rloc)
        m, d = sonde.diag(f"{rloc:04X}", [25, 26, 27, 28])
        afficher(f"routeur {rloc:04X} (fabricant)", m, d)
    print(f"enfants vus : {len(enfants)} dont {sum(e['endormi'] for e in enfants)} endormis")
    # Quelques eveilles et quelques endormis, pour les delais.
    choix = [e for e in enfants if not e["endormi"]][:enfants_max // 2] + [e for e in enfants if e["endormi"]][:enfants_max // 2]
    for e in choix:
        m, d = sonde.diag(e["rloc16"], [0, 8, 2, 25, 26, 27, 28])
        afficher(f"enfant {e['rloc16']} ({'endormi' if e['endormi'] else 'eveille'})", m, d)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2 : amener la capture brute dans la copie de travail**, si elle n'y est pas (worktree), et vérifier qu'elle est ignorée.

```bash
PRINCIPAL=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
test -f docs/releves/2026-09-29/capture-sonde-essai.jsonl || cp "$PRINCIPAL/docs/releves/2026-09-29/capture-sonde-essai.jsonl" docs/releves/2026-09-29/
git check-ignore -q docs/releves/2026-09-29/capture-sonde-essai.jsonl && echo ignoree
```

Expected: `ignoree`. Sans la capture brute (hors du Mac de Djoko), s'arrêter et le dire : les tâches suivantes ont besoin de la capture anonymisée.

- [ ] **Step 3 : anonymiser.**

Run: `python3 outils/anonymiser-sonde.py docs/releves/2026-09-29/capture-sonde-essai.jsonl docs/releves/2026-09-29/capture-sonde.jsonl`
Expected: `64 lignes ; 14 ExtMac, 18 identifiants, 3 prefixes /48 remplaces`

Run: `shasum -a 256 docs/releves/2026-09-29/capture-sonde.jsonl`
Expected: `d77853f1759925819d4ad4f4c1ee3aa07e26e689d75833e5af85a51df5424832`. C'est l'empreinte de la capture anonymisée validée ; les tests des tâches suivantes en dépendent.

- [ ] **Step 4 : les scripts se compilent.**

Run: `python3 -m py_compile outils/anonymiser-sonde.py sonde/sonde_essai.py sonde/tournee_essai.py`
Expected: aucune sortie. Ne pas lancer `sonde_essai.py` ni `tournee_essai.py`, qui ouvrent le port de la sonde.

- [ ] **Step 5 : commit.** Après le `git add`, et avant le commit, `git status --short` ne montre en `A` ou `M` que les 6 fichiers de la liste, et jamais `capture-sonde-essai.jsonl`.

```bash
git add .gitignore outils/anonymiser-sonde.py docs/releves/2026-09-29/capture-sonde.jsonl docs/releves/2026-09-29/README.md sonde/sonde_essai.py sonde/tournee_essai.py
git commit -m "Anonymiser la capture de la sonde pour les tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Cœur : TLV du diagnostic Thread

**Files:**
- Create: `MaillageCoeur/Maillage/DiagnosticThread.swift`
- Modify: `MaillageCoeurTests/Banc.swift` (blocs ci-dessous)
- Test: `MaillageCoeurTests/DiagnosticThreadTests.swift`

**Interfaces:**
- Consumes : `Data(hexa:)` et `Data.hexa` (`MaillageCoeur/Annonces/ChampsTXT.swift`), `AdresseIPv6` (étape 1), la capture de la tâche 1.
- Produces :
  - `enum TypeTLV` : `extMac` 0, `address16` 1, `mode` 2, `route64` 5, `donneesChef` 6, `donneesReseau` 7, `adresses` 8, `tableEnfants` 16, `version` 24, `fabricant` 25, `modele` 26, `versionLogicielle` 27, `pile` 28 ;
  - `ModeThread(brut:)` : `recepteurActif`, `appareilComplet`, `donneesCompletes`, `endormi` ;
  - `RouteRouteur` (`idRouteur`, `qualiteSortante`, `qualiteEntrante`, `cout`, `estVoisin`), `Route64` (`sequence`, `routes`, `routeurs`, `route(vers:)`), `DonneesChef` (`partition` en 8 hexa, `poids`, `version`, `versionStable`, `idChef`), `EntreeEnfant` (`idEnfant`, `qualite`, `delai`, `mode`, `rloc16(parent:)`) ;
  - `ReponseDiagnostic(hexa:)`, nil si les TLV sont tronqués : `extMac`, `rloc16`, `mode`, `route64`, `chef`, `donneesReseau: [UInt8]?`, `adresses: [AdresseIPv6]`, `enfants`, `version`, `fabricant`, `modele`, `versionLogicielle`, `pile` (une chaîne vide donne nil) ;
  - dans le banc des tests : `CaptureSonde.lignes()` et `CaptureSonde.tlv(_ id: Int) throws -> String`.

Le banc (`Banc.swift`) gagne `CaptureSonde`, qui lit la capture de la tâche 1 à partir de `#filePath`. Le paramètre `xa` du banc vient à la tâche 7.

- [ ] **Step 1 : écrire les tests.**

Dans `MaillageCoeurTests/Banc.swift`, remplacer :

```swift
        try CodageJSON.decodeur().decode(Annonces.self, from: Data(contentsOf: dossier.appendingPathComponent(fichier)))
    }
}
```

par :

```swift
        try CodageJSON.decodeur().decode(Annonces.self, from: Data(contentsOf: dossier.appendingPathComponent(fichier)))
    }
}

/// Capture anonymisee de la sonde (`docs/releves/2026-09-29/capture-sonde.jsonl`) :
/// un message par ligne, tel que la sonde l'a envoye, avec l'heure de reception.
enum CaptureSonde {
    static let fichier = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // MaillageCoeurTests
        .deletingLastPathComponent()  // racine du depot
        .appendingPathComponent("docs/releves/2026-09-29/capture-sonde.jsonl")

    /// Les lignes JSON, dans l'ordre.
    static func lignes() throws -> [String] {
        try String(contentsOf: fichier, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    /// TLV (hexa) de la reponse `diag` d'identifiant `id`.
    static func tlv(_ id: Int) throws -> String {
        for l in try lignes() {
            guard let m = try JSONSerialization.jsonObject(with: Data(l.utf8)) as? [String: Any] else { continue }
            if m["t"] as? String == "diag", m["id"] as? Int == id, let t = m["tlv"] as? String { return t }
        }
        throw ErreurCapture(id: id)
    }

    struct ErreurCapture: Error {
        let id: Int
    }
}
```

`MaillageCoeurTests/DiagnosticThreadTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Diagnostic Thread : TLV des reponses")
struct DiagnosticThreadTests {
    /// Routeur 5000 (EFR32) : identite, liens avec qualite et cout, enfants, adresses, version.
    @Test func routeurQuiRepond() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(104)))
        #expect(r.extMac == "E000000000000002")
        #expect(r.rloc16 == 0x5000)
        let route = try #require(r.route64)
        #expect(route.sequence == 186)
        #expect(route.routeurs == [1, 20, 24, 43, 45, 51, 57])
        #expect(route.route(vers: 24) == RouteRouteur(idRouteur: 24, qualiteSortante: 3, qualiteEntrante: 3, cout: 1))
        #expect(route.route(vers: 51) == RouteRouteur(idRouteur: 51, qualiteSortante: 1, qualiteEntrante: 2, cout: 3))
        #expect(route.route(vers: 43)?.estVoisin == false, "pas voisin : joint par une route de cout 3")
        let enfants = try #require(r.enfants)
        #expect(enfants.map(\.idEnfant) == [4, 1])
        #expect(enfants[0].qualite == 2)
        #expect(enfants[0].delai == 256)
        #expect(enfants[0].mode.endormi)
        #expect(enfants[0].rloc16(parent: 0x5000) == 0x5004)
        #expect(r.adresses.map(\.description).contains("fd00:1111:2222:c87:0:ff:fe00:5000"), "son RLOC")
        #expect(r.version == 5, "Thread 1.4")
        #expect(r.chef == nil)
        #expect(r.mode == nil)
    }

    /// TLV fabricant : 25 a 27 presentes mais vides (nil), 28 remplie.
    @Test func fabricantVide() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(105)))
        #expect(r.fabricant == nil)
        #expect(r.modele == nil)
        #expect(r.versionLogicielle == nil)
        #expect(r.pile == "SL-OPENTHREAD/2.5.1.0_GitHub-1fceb225b; EFR32; Sep 18 2024 19:39")
    }

    /// Chef (routeur 24) : Route64 et Leader Data.
    @Test func chef() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(101)))
        #expect(r.chef == DonneesChef(partition: "46CBEBCD", poids: 64, version: 108, versionStable: 186, idChef: 24))
        #expect(r.route64?.routeurs.count == 7)
        #expect(r.extMac == nil)
    }

    /// Enfant endormi interroge a son RLOC (5004) : ExtMac, adresses, mode.
    @Test func enfant() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(116)))
        #expect(r.extMac == "E000000000000004")
        let mode = try #require(r.mode)
        #expect(mode.endormi)
        #expect(!mode.appareilComplet)
        #expect(r.adresses.count == 4)
    }

    /// Reponse vide, hexa invalide, TLV tronquee ; chaine vide.
    @Test func casLimites() throws {
        let vide = try #require(ReponseDiagnostic(hexa: ""))
        #expect(vide.extMac == nil)
        #expect(vide.adresses.isEmpty)
        #expect(ReponseDiagnostic(hexa: "0G") == nil)
        #expect(ReponseDiagnostic(hexa: "0008AABB") == nil, "longueur annoncee 8, 2 octets presents")
        #expect(ReponseDiagnostic(hexa: "1900")?.fabricant == nil)
        #expect(ReponseDiagnostic(hexa: "1A03457665")?.modele == "Eve")
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageCoeurTests/DiagnosticThreadTests`
Expected: la compilation échoue, par exemple avec `error: cannot find 'DonneesChef' in scope` et `error: cannot find 'ReponseDiagnostic' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Maillage/DiagnosticThread.swift` :

```swift
import Foundation

/// Types de TLV du diagnostic reseau Thread (`DIAG_GET`) utilises par la sonde.
public enum TypeTLV {
    public static let extMac: UInt8 = 0
    public static let address16: UInt8 = 1
    public static let mode: UInt8 = 2
    public static let route64: UInt8 = 5
    public static let donneesChef: UInt8 = 6
    public static let donneesReseau: UInt8 = 7
    public static let adresses: UInt8 = 8
    public static let tableEnfants: UInt8 = 16
    public static let version: UInt8 = 24
    public static let fabricant: UInt8 = 25
    public static let modele: UInt8 = 26
    public static let versionLogicielle: UInt8 = 27
    public static let pile: UInt8 = 28
}

/// Mode d'un noeud Thread (TLV Mode, octet de mode d'une Child Table).
public struct ModeThread: Hashable, Sendable, Codable {
    public let brut: UInt8

    public init(brut: UInt8) { self.brut = brut }

    /// R : recepteur actif au repos. Faux : appareil endormi, qui ne recoit qu'a son reveil.
    public var recepteurActif: Bool { brut & 0x08 != 0 }
    /// D : appareil Thread complet (il peut devenir routeur).
    public var appareilComplet: Bool { brut & 0x02 != 0 }
    /// N : donnees reseau completes.
    public var donneesCompletes: Bool { brut & 0x01 != 0 }
    public var endormi: Bool { !recepteurActif }
}

/// Un routeur tel que le voit celui qui repond (entree de la TLV Route64).
public struct RouteRouteur: Hashable, Sendable, Codable {
    public let idRouteur: Int
    /// Qualite du lien de celui qui repond vers ce routeur, de 0 (pas voisin) a 3.
    public let qualiteSortante: Int
    /// Qualite du lien de ce routeur vers celui qui repond, de 0 a 3.
    public let qualiteEntrante: Int
    /// Cout de la route (0 : pas de route).
    public let cout: Int

    /// Voisin radio direct : une qualite non nulle dans un sens au moins.
    public var estVoisin: Bool { qualiteSortante > 0 || qualiteEntrante > 0 }
}

/// TLV Route64 : les routeurs actifs de la partition.
public struct Route64: Hashable, Sendable, Codable {
    public let sequence: UInt8
    /// Par identifiant de routeur croissant.
    public let routes: [RouteRouteur]

    public var routeurs: [Int] { routes.map(\.idRouteur) }
    public func route(vers id: Int) -> RouteRouteur? { routes.first { $0.idRouteur == id } }
}

/// TLV Leader Data.
public struct DonneesChef: Hashable, Sendable, Codable {
    /// Identifiant de partition, 8 hexa majuscules.
    public let partition: String
    public let poids: UInt8
    public let version: UInt8
    public let versionStable: UInt8
    public let idChef: Int
}

/// Entree d'une Child Table : un enfant du routeur qui repond.
public struct EntreeEnfant: Hashable, Sendable, Codable {
    public let idEnfant: Int
    /// Qualite du lien de l'enfant vers son parent, de 0 a 3.
    public let qualite: Int
    /// Delai de supervision de l'enfant, en secondes (2^(t-4)).
    public let delai: Int
    public let mode: ModeThread

    /// RLOC16 de l'enfant : identifiant de routeur du parent, puis son numero.
    public func rloc16(parent: UInt16) -> UInt16 { (parent & 0xFC00) | UInt16(idEnfant) }
}

/// Reponse a un `DIAG_GET` : les TLV reconnues, decodees ; les autres ignorees.
/// Une chaine vide (fabricant, modele...) vaut nil.
public struct ReponseDiagnostic: Hashable, Sendable {
    public private(set) var extMac: String?
    public private(set) var rloc16: UInt16?
    public private(set) var mode: ModeThread?
    public private(set) var route64: Route64?
    public private(set) var chef: DonneesChef?
    /// Network Data brutes (TLV 7), decodees par `DonneesReseau`.
    public private(set) var donneesReseau: [UInt8]?
    public private(set) var adresses: [AdresseIPv6] = []
    public private(set) var enfants: [EntreeEnfant]?
    public private(set) var version: Int?
    public private(set) var fabricant: String?
    public private(set) var modele: String?
    public private(set) var versionLogicielle: String?
    public private(set) var pile: String?

    /// TLV en hexa, telles que la sonde les transmet ; nil si l'hexa ou une TLV est tronque.
    public init?(hexa: String) {
        guard let d = Data(hexa: hexa) else { return nil }
        let o = [UInt8](d)
        var i = 0
        while i < o.count {
            guard i + 2 <= o.count, i + 2 + Int(o[i + 1]) <= o.count else { return nil }
            let t = o[i], v = Array(o[(i + 2)..<(i + 2 + Int(o[i + 1]))])
            i += 2 + v.count
            switch t {
            case TypeTLV.extMac where v.count == 8: extMac = Data(v).hexa
            case TypeTLV.address16 where v.count == 2: rloc16 = UInt16(v[0]) << 8 | UInt16(v[1])
            case TypeTLV.mode where v.count == 1: mode = ModeThread(brut: v[0])
            case TypeTLV.route64: route64 = Self.route64(v)
            case TypeTLV.donneesChef where v.count == 8:
                chef = DonneesChef(partition: Data(v[0..<4]).hexa, poids: v[4], version: v[5], versionStable: v[6],
                                   idChef: Int(v[7]))
            case TypeTLV.donneesReseau: donneesReseau = v
            case TypeTLV.adresses:
                adresses = stride(from: 0, to: v.count - 15, by: 16).compactMap { AdresseIPv6(octets: Array(v[$0..<($0 + 16)])) }
            case TypeTLV.tableEnfants: enfants = Self.enfants(v)
            case TypeTLV.version where v.count == 2: version = Int(v[0]) << 8 | Int(v[1])
            case TypeTLV.fabricant: fabricant = Self.texte(v)
            case TypeTLV.modele: modele = Self.texte(v)
            case TypeTLV.versionLogicielle: versionLogicielle = Self.texte(v)
            case TypeTLV.pile: pile = Self.texte(v)
            default: break
            }
        }
    }

    /// Octet de sequence, masque de 64 bits des routeurs actifs, puis un octet par
    /// routeur : qualite sortante (2 bits), entrante (2 bits), cout (4 bits).
    static func route64(_ v: [UInt8]) -> Route64? {
        guard v.count >= 9 else { return nil }
        let masque = v[1...8].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        let ids = (0..<64).filter { masque & (UInt64(1) << (63 - $0)) != 0 }
        guard v.count >= 9 + ids.count else { return nil }
        let routes = ids.enumerated().map { k, id in
            let b = v[9 + k]
            return RouteRouteur(idRouteur: id, qualiteSortante: Int(b >> 6), qualiteEntrante: Int((b >> 4) & 3),
                                cout: Int(b & 0x0F))
        }
        return Route64(sequence: v[0], routes: routes)
    }

    /// Trois octets par enfant : delai (5 bits), qualite (2 bits), numero (9 bits), mode.
    static func enfants(_ v: [UInt8]) -> [EntreeEnfant] {
        stride(from: 0, to: v.count - 2, by: 3).map { k in
            let x = Int(v[k]) << 8 | Int(v[k + 1])
            let t = x >> 11
            return EntreeEnfant(idEnfant: x & 0x1FF, qualite: (x >> 9) & 3, delai: t >= 4 ? 1 << (t - 4) : 0,
                                mode: ModeThread(brut: v[k + 2]))
        }
    }

    static func texte(_ v: [UInt8]) -> String? {
        let s = String(decoding: v, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        return s.isEmpty ? nil : s
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageCoeurTests/DiagnosticThreadTests`
Expected: `Test run with 5 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `outils/tester.sh`
Expected: `Test run with 99 tests in 14 suites passed` (cœur) et `Test run with 38 tests in 13 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeurTests/Banc.swift MaillageCoeurTests/DiagnosticThreadTests.swift MaillageCoeur/Maillage/DiagnosticThread.swift
git commit -m "Decoder les TLV du diagnostic Thread

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Cœur : Network Data

**Files:**
- Create: `MaillageCoeur/Maillage/DonneesReseau.swift`
- Test: `MaillageCoeurTests/DonneesReseauTests.swift`

**Interfaces:**
- Consumes : `ReponseDiagnostic.donneesReseau` (tâche 2), `CaptureSonde.tlv(206)`.
- Produces : `DonneesReseau(_ o: [UInt8])`, nil si une TLV dépasse la fin :
  - `routeursDeBordure: Set<UInt16>` : préfixe en Border Router, route en Has Route, ou service SRP ;
  - `bbr: [UInt16]` : serveurs du service 01, le principal d'abord ;
  - `publientOMR: [UInt16]`.

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/DonneesReseauTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Network Data : routeurs de bordure, BBR, OMR")
struct DonneesReseauTests {
    /// Network Data de la partition d'Apple, lues au routeur 5000 : les 5 routeurs
    /// de bordure (route fc00::/7, service SRP), B400 principal (BBR, OMR).
    @Test func partitionApple() throws {
        let r = try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(206)))
        let brutes = try #require(r.donneesReseau)
        let d = try #require(DonneesReseau(brutes))
        #expect(d.routeursDeBordure == [0x0400, 0xAC00, 0xB400, 0xCC00, 0xE400])
        #expect(d.bbr == [0xB400])
        #expect(d.publientOMR == [0xB400])
    }

    /// Prefixe /64 publie par un routeur de bordure, route seule par un autre.
    @Test func construites() throws {
        // Prefix (stable) fd00:1:2:3::/64 : Border Router 4800 ; Prefix ::/0 : Has Route 5C00.
        let omr: [UInt8] = [0x03, 16, 0x00, 64, 0xFD, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00, 0x03,
                            0x04, 4, 0x48, 0x00, 0x00, 0x00]
        let route: [UInt8] = [0x03, 7, 0x00, 0, 0x00, 3, 0x5C, 0x00, 0x00]
        let d = try #require(DonneesReseau(omr + route))
        #expect(d.routeursDeBordure == [0x4800, 0x5C00])
        #expect(d.publientOMR == [0x4800])
        #expect(d.bbr.isEmpty)
    }

    @Test func tronquees() {
        #expect(DonneesReseau([0x03, 10, 0x00]) == nil)
        #expect(DonneesReseau([]) == DonneesReseau([0x10, 0]), "vides, ou TLV inconnue : rien")
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageCoeurTests/DonneesReseauTests`
Expected: la compilation échoue, par exemple avec `error: cannot find 'DonneesReseau' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Maillage/DonneesReseau.swift` :

```swift
import Foundation

/// Network Data d'une partition (TLV 7) : ce qui sert a la sonde, par RLOC16.
/// Chaque TLV : type (7 bits) et bit stable, longueur, valeur.
public struct DonneesReseau: Hashable, Sendable {
    /// Routeurs de bordure : ceux qui publient un prefixe (Border Router), une
    /// route (Has Route) ou le service SRP.
    public private(set) var routeursDeBordure: Set<UInt16> = []
    /// Serveurs du service BBR (donnees 01), dans l'ordre : le principal d'abord.
    public private(set) var bbr: [UInt16] = []
    /// Ceux qui publient un prefixe /64 en Border Router (le prefixe OMR).
    public private(set) var publientOMR: [UInt16] = []

    static let prefixe: UInt8 = 1, service: UInt8 = 5
    static let aUneRoute: UInt8 = 0, routeurDeBordure: UInt8 = 2, serveur: UInt8 = 6
    /// Donnees de service : BBR (Thread 1.2), SRP en anycast et en unicast.
    static let serviceBBR: UInt8 = 0x01, serviceSRPAnycast: UInt8 = 0x5C, serviceSRPUnicast: UInt8 = 0x5D

    /// nil si une TLV depasse la fin des donnees.
    public init?(_ o: [UInt8]) {
        guard let tlv = Self.tlv(o) else { return nil }
        for (t, v) in tlv {
            switch t {
            case Self.prefixe: prefixe(v)
            case Self.service: service(v)
            default: break
            }
        }
    }

    /// Prefix : domaine, longueur en bits, prefixe, puis ses sous-TLV.
    private mutating func prefixe(_ v: [UInt8]) {
        guard v.count >= 2 else { return }
        let bits = Int(v[1]), debut = 2 + (bits + 7) / 8
        guard debut <= v.count, let sous = Self.tlv(Array(v[debut...])) else { return }
        for (t, s) in sous {
            switch t {
            case Self.routeurDeBordure:
                let r = stride(from: 0, to: s.count - 3, by: 4).map { UInt16(s[$0]) << 8 | UInt16(s[$0 + 1]) }
                routeursDeBordure.formUnion(r)
                if bits == 64 { publientOMR += r.filter { !publientOMR.contains($0) } }
            case Self.aUneRoute:
                routeursDeBordure.formUnion(stride(from: 0, to: s.count - 2, by: 3).map { UInt16(s[$0]) << 8 | UInt16(s[$0 + 1]) })
            default: break
            }
        }
    }

    /// Service : T et identifiant, numero d'entreprise (si T vaut 0), donnees, puis ses serveurs.
    private mutating func service(_ v: [UInt8]) {
        guard let premier = v.first else { return }
        var j = premier & 0x80 != 0 ? 1 : 5
        guard j < v.count else { return }
        let longueur = Int(v[j])
        guard j + 1 + longueur <= v.count else { return }
        let donnees = Array(v[(j + 1)..<(j + 1 + longueur)])
        j += 1 + longueur
        guard let sous = Self.tlv(Array(v[j...])) else { return }
        let serveurs = sous.filter { $0.type == Self.serveur && $0.valeur.count >= 2 }
            .map { UInt16($0.valeur[0]) << 8 | UInt16($0.valeur[1]) }
        switch donnees.first {
        case Self.serviceBBR?: bbr += serveurs
        case Self.serviceSRPAnycast?, Self.serviceSRPUnicast?: routeursDeBordure.formUnion(serveurs)
        default: break
        }
    }

    /// Suite de TLV (type sans le bit stable, valeur) ; nil si l'une deborde.
    static func tlv(_ o: [UInt8]) -> [(type: UInt8, valeur: [UInt8])]? {
        var res: [(type: UInt8, valeur: [UInt8])] = []
        var i = 0
        while i < o.count {
            guard i + 2 <= o.count, i + 2 + Int(o[i + 1]) <= o.count else { return nil }
            res.append((o[i] >> 1, Array(o[(i + 2)..<(i + 2 + Int(o[i + 1]))])))
            i += 2 + Int(o[i + 1])
        }
        return res
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageCoeurTests/DonneesReseauTests`
Expected: `Test run with 3 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `outils/tester.sh`
Expected: `Test run with 102 tests in 15 suites passed` (cœur) et `Test run with 38 tests in 13 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeurTests/DonneesReseauTests.swift MaillageCoeur/Maillage/DonneesReseau.swift
git commit -m "Lire les routeurs de bordure dans les Network Data

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Cœur : protocole USB de la sonde

**Files:**
- Create: `MaillageCoeur/Maillage/ProtocoleSonde.swift`
- Test: `MaillageCoeurTests/ProtocoleSondeTests.swift`

**Interfaces:**
- Consumes : rien de nouveau.
- Produces :
  - `ProtocoleSonde.separateur` (0x1E), `longueurMax` (4096), `produit` (« sonde-maillage ») ;
  - les messages `Bonjour` (`estSonde`), `ParentSonde`, `EtatSonde` (`ext` facultatif, `estAttachee`, `rloc16Valeur`), `VoisinSonde`, `ResultatDiag` (`init(id:cible:ok:ms:code:tlv:erreur:)`, `reponse: ReponseDiagnostic?`) ;
  - `MessageSonde.lire(_ json: Data) -> MessageSonde?` : `.bonjour`, `.etat`, `.voisins`, `.diag`, `.erreur`, `.inconnu`, et nil hors version 1 ;
  - `CommandeSonde` (`.bonjour`, `.etat`, `.voisins`, `.diag(cible:tlv:id:delaiMs:)`) et sa `ligne`, par exemple `diag 5000 0,1,5 7 6000` suivi d'une fin de ligne ;
  - `DecoupeurLignes().ajouter(_ d: Data) -> [Data]` : les lignes machine (préfixe RS), sans RS ni fin de ligne. Le reste, le journal du firmware, est ignoré.

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/ProtocoleSondeTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Protocole USB de la sonde")
struct ProtocoleSondeTests {
    static func messages() throws -> [MessageSonde] {
        try CaptureSonde.lignes().compactMap { MessageSonde.lire(Data($0.utf8)) }
    }

    /// Toute la capture se relit : 2 bonjour, 9 etat, 53 diag.
    @Test func capture() throws {
        let m = try Self.messages()
        #expect(m.count == 64)
        let bonjours = m.compactMap { if case .bonjour(let b) = $0 { b } else { nil } }
        #expect(bonjours.count == 2)
        #expect(bonjours.allSatisfy { $0.estSonde })
        #expect(bonjours.first?.version == "0.1.0-essai")
        #expect(bonjours.first?.appairee == false)
        let etats = m.compactMap { if case .etat(let e) = $0 { e } else { nil } }
        #expect(etats.count == 9)
        #expect(etats.filter(\.estAttachee).count == 4, "5 releves avant l'appairage")
        let diags = m.compactMap { if case .diag(let d) = $0 { d } else { nil } }
        #expect(diags.count == 53)
    }

    /// Etat attache : parent, partition, chef, prefixe du reseau maille.
    @Test func etatAttache() throws {
        let e = try #require(try Self.messages().compactMap { if case .etat(let e) = $0, e.estAttachee { e } else { nil } }.first)
        #expect(e.role == "child")
        #expect(e.rloc16Valeur == 0xE401)
        #expect(e.parent == ParentSonde(rloc16: "E400", ext: "E000000000000001", lqIn: 3, lqOut: 3, rssi: -76))
        #expect(e.partition == "46CBEBCD")
        #expect(e.chef == 24)
        #expect(e.prefixeMaille == "FD00111122220C87")
        #expect(!e.suspendue)
        #expect(e.ext == nil, "firmware d'essai : pas d'ExtMac")
        let v1 = #"{"v":1,"t":"etat","role":"child","rloc16":"AC09","ext":"E0000000000000FF","mode":"rn","parent":null,"partition":"46CBEBCD","chef":24,"canal":25,"prefixeMaille":null,"xp":null,"suspendue":true}"#
        guard case .etat(let e1)? = MessageSonde.lire(Data(v1.utf8)) else {
            Issue.record("etat 1.0.0 illisible")
            return
        }
        #expect(e1.ext == "E0000000000000FF")
        #expect(e1.suspendue)
    }

    /// Diag : reussi (TLV decodees) et echoue (delai, occupee).
    @Test func diag() throws {
        let diags = try Self.messages().compactMap { if case .diag(let d) = $0 { d } else { nil } }
        let ok = try #require(diags.first { $0.id == 104 })
        #expect(ok.ok && ok.ms == 73 && ok.code == "2.04")
        #expect(ok.reponse?.rloc16 == 0x5000)
        let delai = try #require(diags.first { $0.id == 102 })
        #expect(!delai.ok && delai.erreur == "delai" && delai.reponse == nil)
        #expect(diags.first { $0.id == 402 }?.erreur == "occupee")
    }

    @Test func autres() {
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"voisins","liste":[{"rloc16":"AC00","ext":"E000000000000007","rssi":-89,"lqi":3,"routeur":true}]}"#.utf8))
                == .voisins([VoisinSonde(rloc16: "AC00", ext: "E000000000000007", rssi: -89, lqi: 3, routeur: true)]))
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"erreur","erreur":"commande inconnue"}"#.utf8)) == .erreur("commande inconnue"))
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"nouveau"}"#.utf8)) == .inconnu("nouveau"))
        #expect(MessageSonde.lire(Data(#"{"v":2,"t":"etat"}"#.utf8)) == nil, "autre version")
        #expect(MessageSonde.lire(Data("pas du json".utf8)) == nil)
    }

    @Test func commandes() {
        #expect(CommandeSonde.bonjour.ligne == "bonjour\n")
        #expect(CommandeSonde.etat.ligne == "etat\n")
        #expect(CommandeSonde.diag(cible: 0x5000, tlv: [0, 1, 5, 16, 8, 24], id: 12, delaiMs: 6000).ligne
                == "diag 5000 0,1,5,16,8,24 12 6000\n")
        #expect(CommandeSonde.diag(cible: 0x0400, tlv: [7], id: 3, delaiMs: nil).ligne == "diag 0400 7 3\n")
    }

    /// Lignes machine seulement, meme coupees en morceaux ; lignes humaines et trop longues ignorees.
    @Test func decoupage() {
        var d = DecoupeurLignes()
        #expect(d.ajouter(Data("I (123) chip: log\n\u{1E}{\"v\":1,".utf8)).isEmpty)
        let l = d.ajouter(Data("\"t\":\"etat\"}\r\n\u{1E}{}\n".utf8))
        #expect(l == [Data(#"{"v":1,"t":"etat"}"#.utf8), Data("{}".utf8)])
        var long = Data([ProtocoleSonde.separateur]) + Data(repeating: 0x41, count: 5000)
        long.append(0x0A)
        #expect(d.ajouter(long + Data("\u{1E}{}\n".utf8)) == [Data("{}".utf8)])
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageCoeurTests/ProtocoleSondeTests`
Expected: la compilation échoue, par exemple avec `error: cannot find 'MessageSonde' in scope` et `error: cannot find 'ParentSonde' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Maillage/ProtocoleSonde.swift` :

```swift
import Foundation

/// Protocole USB de la sonde, v1 (spec de la sonde, section 3) : une commande
/// texte par ligne vers la sonde ; en retour, des lignes machine RS (0x1E),
/// JSON compact en ASCII, LF, 4096 octets au plus, `v` et `t` en tete.
public enum ProtocoleSonde {
    public static let separateur: UInt8 = 0x1E
    public static let longueurMax = 4096
    /// `bonjour.produit` d'une sonde : tout autre port est refuse.
    public static let produit = "sonde-maillage"
}

/// Reponse a `bonjour`.
public struct Bonjour: Hashable, Sendable, Codable {
    public let produit: String
    public let version: String
    public let mac: String?
    public let appairee: Bool
    /// Code d'appairage manuel, tant que la sonde n'est pas dans Maison.
    public let code: String?
    public let qr: String?

    public var estSonde: Bool { produit == ProtocoleSonde.produit }
}

/// Parent de la sonde, tel qu'elle le voit.
public struct ParentSonde: Hashable, Sendable, Codable {
    public let rloc16: String
    public let ext: String
    public let lqIn: Int
    public let lqOut: Int
    public let rssi: Int
}

/// Reponse a `etat`.
public struct EtatSonde: Hashable, Sendable, Codable {
    public let role: String
    public let rloc16: String
    /// ExtMac de la sonde (firmware 1.0.0 et suivants) : la sonde se retrouve dans l'instantane.
    public let ext: String?
    public let mode: String?
    public let parent: ParentSonde?
    public let partition: String?
    /// Identifiant de routeur du chef.
    public let chef: Int?
    public let canal: Int?
    /// Prefixe du reseau maille, 16 hexa.
    public let prefixeMaille: String?
    public let xp: String?
    public let suspendue: Bool

    /// Attachee au reseau : enfant, routeur ou chef.
    public var estAttachee: Bool { ["child", "router", "leader"].contains(role) && partition != nil && chef != nil }
    public var rloc16Valeur: UInt16? { UInt16(rloc16, radix: 16) }
}

/// Voisin entendu par la sonde (son parent, pour un MED).
public struct VoisinSonde: Hashable, Sendable, Codable {
    public let rloc16: String
    public let ext: String
    public let rssi: Int
    public let lqi: Int
    public let routeur: Bool
}

/// Reponse a `diag` : les TLV en hexa, ou l'erreur (`delai`, `suspendue`, `occupee`, `envoi`...).
public struct ResultatDiag: Hashable, Sendable, Codable {
    public let id: Int
    public let cible: String
    public let ok: Bool
    public let ms: Int?
    public let code: String?
    public let tlv: String?
    public let erreur: String?

    public init(id: Int, cible: String, ok: Bool, ms: Int? = nil, code: String? = nil, tlv: String? = nil,
                erreur: String? = nil) {
        self.id = id
        self.cible = cible
        self.ok = ok
        self.ms = ms
        self.code = code
        self.tlv = tlv
        self.erreur = erreur
    }

    /// TLV decodees d'une reponse reussie.
    public var reponse: ReponseDiagnostic? { ok ? tlv.flatMap { ReponseDiagnostic(hexa: $0) } : nil }
}

/// Message d'une ligne machine.
public enum MessageSonde: Hashable, Sendable {
    case bonjour(Bonjour)
    case etat(EtatSonde)
    case voisins([VoisinSonde])
    case diag(ResultatDiag)
    case erreur(String)
    /// Type inconnu (version plus recente de la sonde) : ignore.
    case inconnu(String)

    private struct Entete: Decodable {
        let v: Int
        let t: String
    }

    private struct Voisins: Decodable {
        let liste: [VoisinSonde]
    }

    private struct Erreur: Decodable {
        let erreur: String
    }

    /// JSON d'une ligne machine, sans RS ni LF ; nil si illisible ou d'une autre version.
    public static func lire(_ json: Data) -> MessageSonde? {
        let d = JSONDecoder()
        guard let e = try? d.decode(Entete.self, from: json), e.v == 1 else { return nil }
        switch e.t {
        case "bonjour": return (try? d.decode(Bonjour.self, from: json)).map { .bonjour($0) }
        case "etat": return (try? d.decode(EtatSonde.self, from: json)).map { .etat($0) }
        case "voisins": return (try? d.decode(Voisins.self, from: json)).map { .voisins($0.liste) }
        case "diag": return (try? d.decode(ResultatDiag.self, from: json)).map { .diag($0) }
        case "erreur": return (try? d.decode(Erreur.self, from: json)).map { .erreur($0.erreur) }
        default: return .inconnu(e.t)
        }
    }
}

/// Commande envoyee a la sonde.
public enum CommandeSonde: Hashable, Sendable {
    case bonjour
    case etat
    case voisins
    /// `diag <RLOC16> <t,t,...> <id> [<delai ms>]`
    case diag(cible: UInt16, tlv: [UInt8], id: Int, delaiMs: Int?)

    /// Ligne a envoyer, fin de ligne comprise.
    public var ligne: String {
        switch self {
        case .bonjour: return "bonjour\n"
        case .etat: return "etat\n"
        case .voisins: return "voisins\n"
        case .diag(let cible, let tlv, let id, let delai):
            var l = String(format: "diag %04X ", cible) + tlv.map(String.init).joined(separator: ",") + " \(id)"
            if let delai { l += " \(delai)" }
            return l + "\n"
        }
    }
}

/// Decoupe le flux USB en lignes machine (RS ... LF), sans le RS ; le reste
/// (journaux de la pile, lignes humaines) est ignore, comme une ligne trop longue.
public struct DecoupeurLignes: Sendable {
    private var tampon: [UInt8] = []
    private var tropLongue = false

    public init() {}

    public mutating func ajouter(_ d: Data) -> [Data] {
        var lignes: [Data] = []
        for o in d {
            if o == 0x0A {
                if !tropLongue, tampon.first == ProtocoleSonde.separateur {
                    var l = tampon.dropFirst()
                    if l.last == 0x0D { l = l.dropLast() }
                    lignes.append(Data(l))
                }
                tampon.removeAll(keepingCapacity: true)
                tropLongue = false
            } else if tampon.count < ProtocoleSonde.longueurMax {
                tampon.append(o)
            } else {
                tropLongue = true
            }
        }
        return lignes
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageCoeurTests/ProtocoleSondeTests`
Expected: `Test run with 6 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `outils/tester.sh`
Expected: `Test run with 108 tests in 16 suites passed` (cœur) et `Test run with 38 tests in 13 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeurTests/ProtocoleSondeTests.swift MaillageCoeur/Maillage/ProtocoleSonde.swift
git commit -m "Decoder le protocole USB de la sonde

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Cœur : le maillage et sa construction

**Files:**
- Create: `MaillageCoeur/Maillage/Maillage.swift`
- Test: `MaillageCoeurTests/MaillageTests.swift`

**Interfaces:**
- Consumes : `Route64`, `ReponseDiagnostic`, `EntreeEnfant` (tâche 2), `DonneesReseau` (tâche 3).
- Produces :
  - `RouteurMaillage` (`id`, `extMac`, `bordure`, `bbrPrincipal`, `chef`, `muet`, `version`, `pile`, `rloc16`) ;
  - `LienRadio` (`a` < `b`, `qualiteAB`, `qualiteBA`, `qualite` = la plus faible des deux connues) ;
  - `SourceEnfant` (`.tableEnfants`, `.balayage`, `.sonde`) ;
  - `EnfantMaillage(rloc16:extMac:qualite:delai:endormi:adresses:source:)`, dont le `parent` vaut `rloc16 >> 10` ;
  - `Maillage` (`date`, `partition`, `routeurs`, `liens`, `enfants` ; `routeur(_:)`, `liens(de:)`, `enfants(de:)`, `chef`) ;
  - `ConstructionMaillage(date:partition:)` : `routeurs(_:chef:)`, `reseau(_:)`, `reponse(_:routeur:)`, `identite(_:routeur:)`, `pile(_:routeur:)`, `muet(_:)`, `enfant(_:)` (fusionne avec ce qui est déjà connu), `enfantsSansIdentite`, `maillage()`. Aucun de ces types n'est `Codable`.

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/MaillageTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Maillage : construction depuis les reponses d'une tournee")
struct MaillageTests {
    static func reponse(_ id: Int) throws -> ReponseDiagnostic {
        try #require(ReponseDiagnostic(hexa: try CaptureSonde.tlv(id)))
    }

    /// Tournee de la capture : Route64 du chef (6000), 5000 et 6000 qui repondent,
    /// les 5 routeurs de bordure muets, Network Data, balayage sous AC00, la sonde.
    static func tournee() throws -> Maillage {
        var c = ConstructionMaillage(date: Date(timeIntervalSince1970: 1_790_000_000), partition: "46CBEBCD")
        c.routeurs(try #require(try reponse(204).route64), chef: 24)
        c.reponse(try reponse(104), routeur: 20)
        c.pile(try reponse(105).pile, routeur: 20)
        c.reponse(try reponse(106), routeur: 24)
        c.pile(try reponse(107).pile, routeur: 24)
        for id in [1, 43, 45, 51, 57] { c.muet(id) }
        let brutes = try #require(try reponse(206).donneesReseau)
        c.reseau(try #require(DonneesReseau(brutes)))
        for id in 503...508 {
            let r = try reponse(id)
            c.enfant(EnfantMaillage(rloc16: try #require(r.rloc16), extMac: r.extMac, endormi: r.mode?.endormi,
                                    source: .balayage))
        }
        c.enfant(EnfantMaillage(rloc16: 0xAC09, qualite: 3, source: .sonde))
        c.identite("E000000000000007", routeur: 43)
        c.identite("FFFFFFFFFFFFFFFF", routeur: 20)
        return c.maillage()
    }

    /// Routeurs : chef, bordures (Network Data), BBR principal, muets, identite de ceux qui repondent.
    @Test func routeurs() throws {
        let m = try Self.tournee()
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        #expect(m.chef?.id == 24)
        #expect(m.routeurs.filter(\.bordure).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m.routeurs.filter(\.bbrPrincipal).map(\.id) == [45])
        #expect(m.routeurs.filter(\.muet).map(\.id) == [1, 43, 45, 51, 57])
        let r = try #require(m.routeur(20))
        #expect(r.extMac == "E000000000000002", "sa propre reponse passe avant une identite apprise")
        #expect(r.version == 5)
        #expect(r.pile?.hasPrefix("SL-OPENTHREAD/2.5.1.0") == true)
        #expect(m.routeur(24)?.extMac == "E000000000000003")
        #expect(m.routeur(43)?.extMac == "E000000000000007", "muet : ExtMac apprise (parent de la sonde)")
        #expect(r.rloc16 == 0x5000)
    }

    /// Liens entre voisins seulement, vus par 5000 et 6000, qualite dans chaque sens.
    @Test func liens() throws {
        let m = try Self.tournee()
        #expect(m.liens.map { [$0.a, $0.b] } == [[1, 20], [1, 24], [20, 24], [20, 45], [20, 51], [24, 45], [24, 51]])
        let l = try #require(m.liens.first { $0.a == 20 && $0.b == 51 })
        #expect(l.qualiteAB == 1, "de 20 vers 51")
        #expect(l.qualiteBA == 2, "de 51 vers 20")
        #expect(l.qualite == 1)
        #expect(m.liens.first { $0.a == 20 && $0.b == 24 }?.qualite == 3)
        #expect(m.liens(de: 45).count == 2, "muet : ses liens viennent des autres")
    }

    /// Enfants : tables de 5000 et 6000, balayage sous AC00, la sonde.
    @Test func enfants() throws {
        let m = try Self.tournee()
        #expect(m.enfants.count == 13)
        let de20 = m.enfants(de: 20)
        #expect(de20.map(\.rloc16) == [0x5001, 0x5004])
        #expect(de20.allSatisfy { $0.source == .tableEnfants && $0.qualite != nil && $0.endormi == true })
        let de43 = m.enfants(de: 43)
        #expect(de43.map(\.rloc16) == [0xAC03, 0xAC04, 0xAC05, 0xAC06, 0xAC07, 0xAC08, 0xAC09])
        let ac04 = try #require(de43.first { $0.rloc16 == 0xAC04 })
        #expect(ac04.extMac == "E00000000000000A")
        #expect(ac04.qualite == nil, "sous un routeur muet")
        #expect(ac04.source == .balayage)
        #expect(de43.last?.source == .sonde)
        #expect(m.enfants(de: 24).count == 4)
    }

    /// Un enfant vu dans une table puis interroge : l'identite complete l'entree.
    @Test func fusion() throws {
        var c = ConstructionMaillage(date: .now, partition: "46CBEBCD")
        c.reponse(try Self.reponse(104), routeur: 20)
        #expect(c.enfantsSansIdentite == [0x5001, 0x5004])
        let adresse = try #require(AdresseIPv6("fd00:5555:6666:0:a00::7"))
        c.enfant(EnfantMaillage(rloc16: 0x5004, extMac: "E000000000000004", endormi: true, adresses: [adresse],
                                source: .balayage))
        #expect(c.enfantsSansIdentite == [0x5001])
        let e = try #require(c.maillage().enfants.first { $0.rloc16 == 0x5004 })
        #expect(e.extMac == "E000000000000004")
        #expect(e.adresses == [adresse])
        #expect(e.qualite == 2, "qualite de la table gardee")
        #expect(e.source == .tableEnfants)
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageCoeurTests/MaillageTests`
Expected: la compilation échoue, par exemple avec `error: cannot find 'ConstructionMaillage' in scope` et `error: cannot find 'EnfantMaillage' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Maillage/Maillage.swift` :

```swift
import Foundation

/// Routeur Thread vu par la sonde.
public struct RouteurMaillage: Hashable, Sendable, Identifiable {
    /// Identifiant de routeur, de 0 a 62 : son RLOC16 est `id << 10`.
    public let id: Int
    public var extMac: String?
    /// Publie un prefixe, une route ou le service SRP (Network Data).
    public var bordure = false
    public var bbrPrincipal = false
    public var chef = false
    /// N'a pas repondu a la tournee : ses liens et ses enfants ne viennent que des autres.
    public var muet = false
    public var version: Int?
    /// Version de la pile (TLV 28).
    public var pile: String?

    public init(id: Int) { self.id = id }

    public var rloc16: UInt16 { UInt16(id) << 10 }
}

/// Lien radio entre deux routeurs voisins (a < b), avec la qualite dans chaque
/// sens, de 0 a 3 ; nil : inconnue.
public struct LienRadio: Hashable, Sendable {
    public let a: Int
    public let b: Int
    /// Qualite du lien de a vers b.
    public var qualiteAB: Int?
    /// Qualite du lien de b vers a.
    public var qualiteBA: Int?

    /// La moins bonne des qualites connues.
    public var qualite: Int? { [qualiteAB, qualiteBA].compactMap { $0 }.min() }
}

/// D'ou vient un enfant.
public enum SourceEnfant: String, Hashable, Sendable {
    /// Child Table de son parent, un routeur qui repond.
    case tableEnfants
    /// Trouve par balayage sous un routeur muet.
    case balayage
    /// La sonde elle-meme.
    case sonde
}

/// Enfant d'un routeur (appareil endormi ou non, ou la sonde).
public struct EnfantMaillage: Hashable, Sendable, Identifiable {
    public let rloc16: UInt16
    public var extMac: String?
    /// Qualite du lien de l'enfant vers son parent, de 0 a 3 ; nil sous un routeur muet.
    public var qualite: Int?
    /// Delai de supervision, en secondes.
    public var delai: Int?
    public var endormi: Bool?
    /// Adresses donnees par l'enfant (TLV 8), pour le reconnaitre par son adresse OMR.
    public var adresses: [AdresseIPv6]
    public var source: SourceEnfant

    public init(rloc16: UInt16, extMac: String? = nil, qualite: Int? = nil, delai: Int? = nil, endormi: Bool? = nil,
                adresses: [AdresseIPv6] = [], source: SourceEnfant) {
        self.rloc16 = rloc16
        self.extMac = extMac
        self.qualite = qualite
        self.delai = delai
        self.endormi = endormi
        self.adresses = adresses
        self.source = source
    }

    public var id: UInt16 { rloc16 }
    /// Identifiant de routeur du parent.
    public var parent: Int { Int(rloc16 >> 10) }
}

/// Le maillage d'une partition, tel qu'une tournee de la sonde le voit.
public struct Maillage: Hashable, Sendable {
    public let date: Date
    public let partition: String
    /// Par identifiant croissant.
    public let routeurs: [RouteurMaillage]
    /// Par (a, b) croissants.
    public let liens: [LienRadio]
    /// Par RLOC16 croissant.
    public let enfants: [EnfantMaillage]

    public func routeur(_ id: Int) -> RouteurMaillage? { routeurs.first { $0.id == id } }
    public func liens(de id: Int) -> [LienRadio] { liens.filter { $0.a == id || $0.b == id } }
    public func enfants(de id: Int) -> [EnfantMaillage] { enfants.filter { $0.parent == id } }
    public var chef: RouteurMaillage? { routeurs.first(where: \.chef) }
}

/// Assemble un `Maillage` au fil des reponses d'une tournee.
public struct ConstructionMaillage: Sendable {
    private let date: Date
    private let partition: String
    private var routeurs: [Int: RouteurMaillage] = [:]
    private var liens: [Int: LienRadio] = [:]
    private var enfants: [UInt16: EnfantMaillage] = [:]

    public init(date: Date, partition: String) {
        self.date = date
        self.partition = partition
    }

    /// Routeurs actifs de la partition (Route64 du chef, ou d'un routeur qui repond).
    public mutating func routeurs(_ r: Route64, chef: Int) {
        for id in r.routeurs where routeurs[id] == nil { routeurs[id] = RouteurMaillage(id: id) }
        routeurs[chef, default: RouteurMaillage(id: chef)].chef = true
    }

    /// Roles lus dans les Network Data.
    public mutating func reseau(_ d: DonneesReseau) {
        for rloc in d.routeursDeBordure { routeurs[Int(rloc >> 10), default: RouteurMaillage(id: Int(rloc >> 10))].bordure = true }
        if let principal = d.bbr.first { routeurs[Int(principal >> 10), default: RouteurMaillage(id: Int(principal >> 10))].bbrPrincipal = true }
    }

    /// Reponse d'un routeur : identite, version, ses liens (Route64) et ses enfants (Child Table).
    public mutating func reponse(_ r: ReponseDiagnostic, routeur id: Int) {
        var routeur = routeurs[id, default: RouteurMaillage(id: id)]
        routeur.extMac = r.extMac ?? routeur.extMac
        routeur.version = r.version ?? routeur.version
        routeur.muet = false
        routeurs[id] = routeur
        for route in r.route64?.routes ?? [] where route.idRouteur != id {
            if routeurs[route.idRouteur] == nil { routeurs[route.idRouteur] = RouteurMaillage(id: route.idRouteur) }
            guard route.estVoisin else { continue }
            lien(id, route.idRouteur, sortante: route.qualiteSortante, entrante: route.qualiteEntrante)
        }
        for e in r.enfants ?? [] {
            enfant(EnfantMaillage(rloc16: e.rloc16(parent: routeur.rloc16), qualite: e.qualite, delai: e.delai,
                                  endormi: e.mode.endormi, source: .tableEnfants))
        }
    }

    /// ExtMac apprise ailleurs (parent de la sonde, tournee precedente) : pour un
    /// routeur muet, qui ne la donne pas lui-meme.
    public mutating func identite(_ ext: String, routeur id: Int) {
        var r = routeurs[id, default: RouteurMaillage(id: id)]
        r.extMac = r.extMac ?? ext
        routeurs[id] = r
    }

    public mutating func pile(_ p: String?, routeur id: Int) {
        routeurs[id, default: RouteurMaillage(id: id)].pile = p
    }

    /// Routeur qui n'a pas repondu.
    public mutating func muet(_ id: Int) {
        routeurs[id, default: RouteurMaillage(id: id)].muet = true
    }

    /// Enfant trouve (table, balayage, sonde) ; complete celui qui est deja connu.
    public mutating func enfant(_ e: EnfantMaillage) {
        guard var connu = enfants[e.rloc16] else {
            enfants[e.rloc16] = e
            return
        }
        connu.extMac = connu.extMac ?? e.extMac
        connu.qualite = connu.qualite ?? e.qualite
        connu.delai = connu.delai ?? e.delai
        connu.endormi = connu.endormi ?? e.endormi
        if connu.adresses.isEmpty { connu.adresses = e.adresses }
        if e.source == .sonde { connu.source = .sonde }
        enfants[e.rloc16] = connu
    }

    /// Roles poses a la main (maillage de demo).
    mutating func marquer(_ id: Int, bordure: Bool, bbrPrincipal: Bool = false) {
        var r = routeurs[id, default: RouteurMaillage(id: id)]
        r.bordure = bordure
        r.bbrPrincipal = bbrPrincipal
        routeurs[id] = r
    }

    /// Lien vu par `de` : qualite sortante (de -> vers) et entrante (vers -> de).
    mutating func lien(_ de: Int, _ vers: Int, sortante: Int, entrante: Int) {
        let (a, b) = (min(de, vers), max(de, vers))
        var l = liens[a * 64 + b] ?? LienRadio(a: a, b: b)
        if de == a {
            l.qualiteAB = sortante
            l.qualiteBA = entrante
        } else {
            l.qualiteAB = entrante
            l.qualiteBA = sortante
        }
        liens[a * 64 + b] = l
    }

    /// Enfants des tables encore sans ExtMac, par RLOC16 : a identifier (la sonde exceptee).
    public var enfantsSansIdentite: [UInt16] {
        enfants.values.filter { $0.extMac == nil && $0.source != .sonde }.map(\.rloc16).sorted()
    }

    public func maillage() -> Maillage {
        Maillage(date: date, partition: partition,
                 routeurs: routeurs.values.sorted { $0.id < $1.id },
                 liens: liens.values.sorted { ($0.a, $0.b) < ($1.a, $1.b) },
                 enfants: enfants.values.sorted { $0.rloc16 < $1.rloc16 })
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageCoeurTests/MaillageTests`
Expected: `Test run with 4 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `outils/tester.sh`
Expected: `Test run with 112 tests in 17 suites passed` (cœur) et `Test run with 38 tests in 13 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeurTests/MaillageTests.swift MaillageCoeur/Maillage/Maillage.swift
git commit -m "Construire le maillage depuis les reponses de la sonde

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 6: Cœur : la tournée

**Files:**
- Create: `MaillageCoeur/Maillage/Tournee.swift`
- Test: `MaillageCoeurTests/TourneeTests.swift`

**Interfaces:**
- Consumes : `EtatSonde`, `ResultatDiag`, `MessageSonde` (tâche 4), `ConstructionMaillage`, `EnfantMaillage` (tâche 5), `DonneesReseau` (tâche 3), `CaptureSonde` (tâche 2).
- Produces :
  - `protocol InterlocuteurSonde: Sendable` : `etat() async throws -> EtatSonde`, `diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag` ;
  - `MemoireTournee` : `echecs`, `muetInterroge`, `piles`, `identites`, `balayes`, `identifies`, `dernierBalayage`, `muetsBalayes`, `repondants`, `partition` ; `estMuet(_:)`, vrai à partir de 2 échecs de suite. Une autre partition remet tout à zéro ;
  - `Tournee.executer(_:memoire:maintenant:) async throws -> (maillage: Maillage, memoire: MemoireTournee)?`, nil si la sonde n'est pas attachée ou si elle est suspendue ;
  - les constantes de `Tournee` : `tlvChef`, `tlvRouteur`, `tlvPile`, `tlvReseau`, `tlvBalayage`, `tlvIdentite`, `delaiRouteur` (6000), `delaiBalayage` et `delaiEnfant` (8000), `enVol` (8), `numerosMax` (32), `apresDernier` (8), `periodeBalayage` (30 min), `periodeMuet` (1 h) ;
  - dans les tests, `SondeRejouee`, la capture rejouée, qui note les requêtes.

La tournée ne dépend que de `InterlocuteurSonde` : les tests rejouent la capture, sans sonde ni port.

- [ ] **Step 1 : écrire les tests.**

`MaillageCoeurTests/TourneeTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

/// Sonde rejouee : repond avec les TLV de la capture, echoue en `delai` pour le reste,
/// et note ses requetes.
struct SondeRejouee: InterlocuteurSonde {
    actor Registre {
        var requetes: [String] = []
        func noter(_ r: String) { requetes.append(r) }
    }

    let etatSonde: EtatSonde
    /// "<cible>|<tlv,...>" -> TLV hexa.
    let reponses: [String: String]
    let registre = Registre()

    func etat() async throws -> EtatSonde { etatSonde }

    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        let cle = String(format: "%04X|", cible) + tlv.map(String.init).joined(separator: ",")
        await registre.noter(cle)
        guard let t = reponses[cle] else {
            return ResultatDiag(id: 0, cible: String(format: "%04X", cible), ok: false, ms: delaiMs, erreur: "delai")
        }
        return ResultatDiag(id: 0, cible: String(format: "%04X", cible), ok: true, ms: 50, code: "2.04", tlv: t)
    }

    /// Etat de la capture apres le changement de parent : AC09, enfant de AC00 (muet).
    static func capture(chef: Int = 24, reponsesEnPlus: [String: String] = [:]) throws -> SondeRejouee {
        let base = #"{"v":1,"t":"etat","role":"child","rloc16":"AC09","mode":"rn","parent":{"rloc16":"AC00","ext":"E000000000000007","lqIn":3,"lqOut":3,"rssi":-89},"partition":"46CBEBCD","chef":\#(chef),"canal":25,"prefixeMaille":"FD00111122220C87","xp":"A0A1A2A3A4A5A6A7","suspendue":false}"#
        guard case .etat(let e)? = MessageSonde.lire(Data(base.utf8)) else { throw CaptureSonde.ErreurCapture(id: 0) }
        var r: [String: String] = [
            "6000|5,6": try CaptureSonde.tlv(204),
            "5000|0,1,5,16,8,24": try CaptureSonde.tlv(104),
            "6000|0,1,5,16,8,24": try CaptureSonde.tlv(106),
            "5000|25,26,27,28": try CaptureSonde.tlv(105),
            "6000|25,26,27,28": try CaptureSonde.tlv(107),
            "5000|7": try CaptureSonde.tlv(206),
            "AC01|0,1,2,8": try CaptureSonde.tlv(411),
            "5004|0,8": try CaptureSonde.tlv(116),
            "5001|0,8": try CaptureSonde.tlv(117),
            "6003|0,8": try CaptureSonde.tlv(118),
        ]
        for (n, id) in zip(3...8, 503...508) { r[String(format: "AC%02X|0,1,2,8", n)] = try CaptureSonde.tlv(id) }
        r.merge(reponsesEnPlus) { _, b in b }
        return SondeRejouee(etatSonde: e, reponses: r)
    }
}

@Suite("Tournee de la sonde")
struct TourneeTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    /// Premiere tournee : routeurs, roles, liens, enfants des tables et du balayage, memoire.
    @Test func premiere() async throws {
        let sonde = try SondeRejouee.capture()
        let (m, mem) = try #require(try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        #expect(m.partition == "46CBEBCD")
        #expect(m.routeurs.map(\.id) == [1, 20, 24, 43, 45, 51, 57])
        #expect(m.chef?.id == 24)
        #expect(m.routeurs.filter(\.muet).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m.routeurs.filter(\.bordure).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m.routeur(45)?.bbrPrincipal == true)
        #expect(m.routeur(43)?.extMac == "E000000000000007", "parent de la sonde")
        #expect(m.routeur(20)?.pile?.hasPrefix("SL-OPENTHREAD") == true)
        #expect(m.liens.count == 7)
        #expect(m.enfants(de: 43).map(\.rloc16) == [0xAC01, 0xAC03, 0xAC04, 0xAC05, 0xAC06, 0xAC07, 0xAC08, 0xAC09])
        #expect(m.enfants(de: 43).last?.source == .sonde)
        #expect(m.enfants.count == 14)
        let de20 = m.enfants(de: 20)
        #expect(de20.map(\.extMac) == ["E000000000000005", "E000000000000004"], "tables : identifies une fois")
        #expect(de20.first?.adresses.count == 4)
        #expect(m.enfants(de: 24).filter { $0.extMac == nil }.map(\.rloc16) == [0x6002, 0x6005, 0x6006], "sans reponse")
        #expect(mem.echecs[43] == 1)
        #expect(!mem.estMuet(43), "muet a partir de 2 echecs de suite")
        #expect(mem.repondants == [20, 24])
        #expect(mem.identites[0xAC00] == "E000000000000007")
        #expect(mem.identites[0x5000] == "E000000000000002")
        #expect(mem.dernierBalayage == Self.t0)
        #expect(mem.muetsBalayes == [1, 43, 45, 51, 57])
        let requetes = await sonde.registre.requetes
        #expect(requetes.filter { $0.hasSuffix("|0,1,2,8") }.count == 48, "AC00 : 1 a 17 sauf 9 ; les autres : 1 a 8")
        #expect(requetes.filter { $0.hasSuffix("|25,26,27,28") }.count == 2)
        #expect(requetes.filter { $0.hasSuffix("|0,8") }.count == 6, "les 6 enfants des tables")
        #expect(mem.identifies.count == 3)
    }

    /// Deuxieme tournee (5 min) : les muets le deviennent ; pas de nouveau balayage ;
    /// pile deja connue. Troisieme (10 min) : les muets ne sont plus interroges.
    @Test func suivantes() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let avant2 = await sonde.registre.requetes.count
        let (m2, mem2) = try #require(try await Tournee.executer(sonde, memoire: mem1, maintenant: Self.t0 + 300))
        let requetes2 = await sonde.registre.requetes.dropFirst(avant2)
        #expect(requetes2.count == 12, "chef, 7 routeurs, Network Data, 3 enfants toujours inconnus")
        #expect(mem2.estMuet(43))
        #expect(mem2.muetInterroge[43] == Self.t0 + 300)
        #expect(m2.enfants(de: 43).count == 8, "enfants du balayage garde")

        let avant3 = await sonde.registre.requetes.count
        let (m3, _) = try #require(try await Tournee.executer(sonde, memoire: mem2, maintenant: Self.t0 + 600))
        let requetes3 = Array(await sonde.registre.requetes.dropFirst(avant3))
        #expect(requetes3.first == "6000|5,6", "la liste des routeurs d'abord")
        #expect(requetes3.sorted() == ["5000|0,1,5,16,8,24", "5000|7", "6000|0,1,5,16,8,24", "6000|5,6",
                                       "6002|0,8", "6005|0,8", "6006|0,8"], "en parallele : dans le desordre")
        #expect(m3.routeurs.filter(\.muet).map(\.id) == [1, 43, 45, 51, 57])
        #expect(m3.enfants.count == 14)
    }

    /// Balayage de nouveau apres 30 min.
    @Test func balayageDu() async throws {
        let sonde = try SondeRejouee.capture()
        let (_, mem1) = try #require(try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0))
        let avant = await sonde.registre.requetes.count
        _ = try await Tournee.executer(sonde, memoire: mem1, maintenant: Self.t0 + 1800)
        let requetes = await sonde.registre.requetes.dropFirst(avant)
        #expect(requetes.filter { $0.hasSuffix("|0,1,2,8") }.count == 48)
        #expect(requetes.filter { $0.hasSuffix("|0,8") }.count == 6, "identites revues avec le balayage")
    }

    /// Chef muet : Route64 d'un routeur qui a repondu a la tournee precedente.
    @Test func chefMuet() async throws {
        let sonde = try SondeRejouee.capture(chef: 45, reponsesEnPlus: ["5000|5,6": try CaptureSonde.tlv(104)])
        var mem = MemoireTournee()
        mem.echecs[45] = 2
        mem.repondants = [20]
        let (m, _) = try #require(try await Tournee.executer(sonde, memoire: mem, maintenant: Self.t0))
        #expect(m.routeurs.count == 7)
        #expect(m.chef?.id == 45)
        #expect(await sonde.registre.requetes.first == "5000|5,6")
    }

    /// Autre partition (panne, fusion) : les identifiants de routeur y sont
    /// redistribues ; ce qui etait retenu de l'ancienne ne sert plus.
    @Test func autrePartition() async throws {
        let sonde = try SondeRejouee.capture()
        var mem = MemoireTournee()
        mem.partition = "73586B68"
        mem.identites[0xB400] = "E0000000000000EE"
        mem.echecs[20] = 2
        mem.muetInterroge[20] = Self.t0
        mem.dernierBalayage = Self.t0
        mem.muetsBalayes = [1, 43, 45, 51, 57]
        let (m, mem2) = try #require(try await Tournee.executer(sonde, memoire: mem, maintenant: Self.t0 + 60))
        #expect(mem2.partition == "46CBEBCD")
        #expect(m.routeur(45)?.extMac == nil, "B400 : pas l'ExtMac retenu dans l'autre partition")
        #expect(m.routeur(20)?.muet == false, "5000 interroge de nouveau")
        #expect(mem2.dernierBalayage == Self.t0 + 60, "balayage refait")
    }

    /// Sonde suspendue (interrupteur eteint dans Maison) : pas de tournee, aucune requete.
    @Test func suspendue() async throws {
        let base = #"{"v":1,"t":"etat","role":"child","rloc16":"AC09","mode":"rn","parent":null,"partition":"46CBEBCD","chef":24,"canal":25,"prefixeMaille":null,"xp":null,"suspendue":true}"#
        guard case .etat(let e)? = MessageSonde.lire(Data(base.utf8)) else {
            Issue.record("etat illisible")
            return
        }
        let sonde = SondeRejouee(etatSonde: e, reponses: [:])
        #expect(try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0) == nil)
        #expect(await sonde.registre.requetes.isEmpty)
    }

    /// Sonde pas encore dans le reseau.
    @Test func nonAttachee() async throws {
        let base = #"{"v":1,"t":"etat","role":"disabled","rloc16":"FFFE","mode":"rn","parent":null,"partition":null,"chef":null,"canal":11,"prefixeMaille":null,"xp":null,"suspendue":false}"#
        guard case .etat(let e)? = MessageSonde.lire(Data(base.utf8)) else {
            Issue.record("etat illisible")
            return
        }
        let sonde = SondeRejouee(etatSonde: e, reponses: [:])
        #expect(try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: Self.t0) == nil)
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageCoeurTests/TourneeTests`
Expected: la compilation échoue, par exemple avec `error: cannot find 'MemoireTournee' in scope` et `error: cannot find 'Tournee' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Maillage/Tournee.swift` :

```swift
import Foundation

/// Ce que la tournee demande a la sonde : la liaison USB dans l'app, une sonde
/// rejouee dans les tests.
public protocol InterlocuteurSonde: Sendable {
    func etat() async throws -> EtatSonde
    /// `DIAG_GET` vers un RLOC16 : la reponse, ou l'echec (`delai`, `occupee`...).
    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag
}

/// Ce que la tournee retient d'une fois sur l'autre (spec de la sonde, section 4).
public struct MemoireTournee: Hashable, Sendable {
    /// Echecs de suite, par routeur : muet a partir de 2.
    public var echecs: [Int: Int] = [:]
    /// Derniere interrogation d'un routeur muet : une fois par heure.
    public var muetInterroge: [Int: Date] = [:]
    /// Pile (TLV 28), demandee une fois par routeur qui repond ; "" : aucune.
    public var piles: [Int: String] = [:]
    /// ExtMac des routeurs, par RLOC16 : parents successifs de la sonde, routeurs qui repondent.
    public var identites: [UInt16: String] = [:]
    /// Enfants des routeurs muets trouves au dernier balayage.
    public var balayes: [UInt16: EnfantMaillage] = [:]
    /// Enfants des tables deja identifies (ExtMac, adresses), par RLOC16 : revus a chaque balayage.
    public var identifies: [UInt16: EnfantMaillage] = [:]
    public var dernierBalayage: Date?
    /// Routeurs muets au dernier balayage : un autre ensemble relance le balayage.
    public var muetsBalayes: Set<Int> = []
    /// Routeurs qui ont repondu a la derniere tournee : Route64 de secours quand le chef est muet.
    public var repondants: [Int] = []
    /// Partition de ce qui est retenu : une autre remet tout a zero.
    public var partition: String?

    public init() {}

    public func estMuet(_ id: Int) -> Bool { (echecs[id] ?? 0) >= 2 }
}

/// Tournee de la sonde : liste des routeurs, routeurs qui repondent, roles,
/// puis balayage des enfants des routeurs muets.
public enum Tournee {
    public static let tlvChef: [UInt8] = [TypeTLV.route64, TypeTLV.donneesChef]
    public static let tlvRouteur: [UInt8] = [TypeTLV.extMac, TypeTLV.address16, TypeTLV.route64, TypeTLV.tableEnfants,
                                             TypeTLV.adresses, TypeTLV.version]
    public static let tlvPile: [UInt8] = [TypeTLV.fabricant, TypeTLV.modele, TypeTLV.versionLogicielle, TypeTLV.pile]
    public static let tlvReseau: [UInt8] = [TypeTLV.donneesReseau]
    public static let tlvBalayage: [UInt8] = [TypeTLV.extMac, TypeTLV.address16, TypeTLV.mode, TypeTLV.adresses]
    public static let tlvIdentite: [UInt8] = [TypeTLV.extMac, TypeTLV.adresses]
    public static let delaiRouteur = 6000
    public static let delaiBalayage = 8000
    /// Requetes en vol a la fois (la sonde en tient 8).
    public static let enVol = 8
    /// Delai d'un enfant : un endormi ne repond qu'a son reveil.
    public static let delaiEnfant = 8000
    /// Numeros d'enfant balayes sous un routeur muet : de 1 a 32, et 8 apres le dernier trouve.
    public static let numerosMax = 32
    public static let apresDernier = 8
    public static let periodeBalayage: TimeInterval = 30 * 60
    public static let periodeMuet: TimeInterval = 3600

    /// Une tournee, et le balayage s'il est du ; nil si la sonde n'est pas attachee,
    /// ou suspendue dans Maison (ses requetes echoueraient toutes : aucun routeur
    /// ne doit passer pour muet).
    public static func executer(_ sonde: some InterlocuteurSonde, memoire: MemoireTournee,
                                maintenant: Date) async throws -> (maillage: Maillage, memoire: MemoireTournee)? {
        var mem = memoire
        let etat = try await sonde.etat()
        guard etat.estAttachee, !etat.suspendue, let partition = etat.partition, let chef = etat.chef,
              let moi = etat.rloc16Valeur else { return nil }
        // Autre partition : les identifiants de routeur y sont redistribues, rien ne vaut plus.
        if let ancienne = mem.partition, ancienne != partition { mem = MemoireTournee() }
        mem.partition = partition
        var c = ConstructionMaillage(date: maintenant, partition: partition)
        if let p = etat.parent, let rp = UInt16(p.rloc16, radix: 16) {
            mem.identites[rp] = p.ext
            c.enfant(EnfantMaillage(rloc16: moi, extMac: etat.ext, qualite: p.lqOut, source: .sonde))
        }

        // 1. Liste des routeurs : Route64 du chef ; s'il est muet, d'un routeur qui a repondu.
        let secours = mem.repondants.filter { $0 != chef }
        var route64: Route64?
        for id in mem.estMuet(chef) ? secours + [chef] : [chef] + secours {
            if let r = try await sonde.diag(rloc16(id), tlvChef, delaiMs: delaiRouteur).reponse?.route64 {
                route64 = r
                break
            }
        }
        guard let route64 else { return (c.maillage(), mem) }
        c.routeurs(route64, chef: chef)

        // 2. Chaque routeur, en parallele, sauf un muet deja interroge dans l'heure.
        let aInterroger = route64.routeurs.filter { id in
            guard mem.estMuet(id), let quand = mem.muetInterroge[id] else { return true }
            return maintenant.timeIntervalSince(quand) >= periodeMuet
        }
        var repondants: [Int] = []
        for (id, r) in try await parallele(aInterroger, { try await sonde.diag(rloc16($0), tlvRouteur, delaiMs: delaiRouteur) }) {
            if let rep = r.reponse {
                c.reponse(rep, routeur: id)
                mem.echecs[id] = 0
                mem.muetInterroge[id] = nil
                if let ext = rep.extMac { mem.identites[rloc16(id)] = ext }
                repondants.append(id)
            } else {
                mem.echecs[id, default: 0] += 1
                if mem.estMuet(id) { mem.muetInterroge[id] = maintenant }
            }
        }
        mem.repondants = repondants
        let muets = Set(route64.routeurs).subtracting(repondants)
        for id in muets.sorted() {
            c.muet(id)
            if let ext = mem.identites[rloc16(id)] { c.identite(ext, routeur: id) }
        }

        // 3. Pile, une fois ; Network Data, a un routeur qui repond.
        for id in repondants where mem.piles[id] == nil {
            if let rep = try await sonde.diag(rloc16(id), tlvPile, delaiMs: delaiRouteur).reponse {
                mem.piles[id] = rep.pile ?? ""
            }
        }
        for id in repondants {
            c.pile(mem.piles[id].flatMap { $0.isEmpty ? nil : $0 }, routeur: id)
        }
        if let id = repondants.first,
           let brutes = try await sonde.diag(rloc16(id), tlvReseau, delaiMs: delaiRouteur).reponse?.donneesReseau,
           let d = DonneesReseau(brutes) {
            c.reseau(d)
        }

        // 4. Balayage des enfants des routeurs muets : toutes les 30 min, ou si les muets
        // changent. Les identites des enfants des tables sont alors revues aussi.
        let du = mem.dernierBalayage.map { maintenant.timeIntervalSince($0) >= periodeBalayage } ?? true
        if du || (!muets.isEmpty && muets != mem.muetsBalayes) {
            var trouves: [UInt16: EnfantMaillage] = [:]
            for m in muets.sorted() {
                for e in try await balayer(sonde, routeur: m, sauf: moi) { trouves[e.rloc16] = e }
            }
            mem.balayes = trouves
            mem.identifies = [:]
            mem.dernierBalayage = maintenant
            mem.muetsBalayes = muets
        }
        for e in mem.balayes.values.sorted(by: { $0.rloc16 < $1.rloc16 }) where muets.contains(e.parent) {
            c.enfant(e)
        }

        // 5. Enfants des tables encore inconnus : ExtMac et adresses, une fois.
        let aIdentifier = c.enfantsSansIdentite.filter { mem.identifies[$0] == nil }
        for (cible, r) in try await parallele(aIdentifier, { try await sonde.diag($0, tlvIdentite, delaiMs: delaiEnfant) }) {
            guard let rep = r.reponse else { continue }
            mem.identifies[cible] = EnfantMaillage(rloc16: cible, extMac: rep.extMac, adresses: rep.adresses, source: .tableEnfants)
        }
        for cible in c.enfantsSansIdentite {
            if let e = mem.identifies[cible] { c.enfant(e) }
        }
        return (c.maillage(), mem)
    }

    static func rloc16(_ routeur: Int) -> UInt16 { UInt16(routeur) << 10 }

    /// Enfants d'un routeur muet, numero par numero, 8 en vol : de 1 a 32, en
    /// s'arretant 8 numeros apres le dernier trouve (la sonde compte, sans etre interrogee).
    static func balayer(_ sonde: some InterlocuteurSonde, routeur m: Int, sauf moi: UInt16) async throws -> [EnfantMaillage] {
        var trouves: [EnfantMaillage] = []
        var dernier = moi >> 10 == UInt16(m) ? Int(moi & 0x1FF) : 0
        var debut = 1
        while debut <= min(numerosMax, dernier + apresDernier) {
            let fin = min(debut + enVol - 1, numerosMax, dernier + apresDernier)
            let cibles = (debut...fin).map { rloc16(m) | UInt16($0) }.filter { $0 != moi }
            for (cible, r) in try await parallele(cibles, { try await sonde.diag($0, tlvBalayage, delaiMs: delaiBalayage) }) {
                guard let rep = r.reponse else { continue }
                trouves.append(EnfantMaillage(rloc16: cible, extMac: rep.extMac, endormi: rep.mode?.endormi,
                                              adresses: rep.adresses, source: .balayage))
                dernier = max(dernier, Int(cible & 0x1FF))
            }
            debut = fin + 1
        }
        return trouves
    }

    /// Au plus `enVol` requetes a la fois ; resultats dans l'ordre des elements.
    static func parallele<E: Sendable>(_ elements: [E],
                                       _ requete: @escaping @Sendable (E) async throws -> ResultatDiag) async throws -> [(E, ResultatDiag)] {
        var resultats: [(Int, E, ResultatDiag)] = []
        try await withThrowingTaskGroup(of: (Int, E, ResultatDiag).self) { groupe in
            var suivant = 0
            func lancer() {
                let i = suivant
                suivant += 1
                let e = elements[i]
                groupe.addTask { (i, e, try await requete(e)) }
            }
            while suivant < min(enVol, elements.count) { lancer() }
            while let r = try await groupe.next() {
                resultats.append(r)
                if suivant < elements.count { lancer() }
            }
        }
        return resultats.sorted { $0.0 < $1.0 }.map { ($0.1, $0.2) }
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageCoeurTests/TourneeTests`
Expected: `Test run with 7 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `outils/tester.sh`
Expected: `Test run with 119 tests in 18 suites passed` (cœur) et `Test run with 38 tests in 13 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeurTests/TourneeTests.swift MaillageCoeur/Maillage/Tournee.swift
git commit -m "Faire la tournee de la sonde et balayer les routeurs muets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 7: Cœur : rapprochement et disposition avec la sonde

**Files:**
- Create: `MaillageCoeur/Maillage/Rapprochement.swift`
- Modify: `MaillageCoeurTests/Banc.swift` (blocs ci-dessous), `MaillageCoeur/Disposition/Disposition.swift` (fichier entier ci-dessous)
- Test: `MaillageCoeurTests/RapprochementTests.swift`

**Interfaces:**
- Consumes : `Maillage` (tâche 5) ; de l'étape 1, `Reseau` (partitions et routeurs de bordure, avec leurs champs TXT `xa` et `sb`), `Appareil` (id = nom d'hôte, adresses), `AppareilAffiche`, `Disposition`.
- Produces :
  - `NoeudSonde` (`id`, `rloc16`, `genre` `.routeur` ou `.enfant`, `reconnu`, `bordure`, `init` public) et `LienAffiche` (`de`, `vers`, `genre` `.radio` ou `.parent`, `qualite`) ;
  - `MaillageAffiche(maillage:reseau:appareils:)`. Il donne à chaque nœud l'id du graphe :
    - l'instance d'un routeur de bordure, par son `xa` ou comme BBR principal ;
    - l'id d'un appareil, par l'ExtMac (le nom d'hôte d'un appareil Matter) ou par une adresse commune ;
    - sinon « rloc:5000 ».

    Il offre aussi `noeud(_:)`, `inconnus`, `parent(de:)` et `idsRouteurs` ;
  - `Disposition(reseau:appareils:maillage: MaillageAffiche? = nil)`, avec `Disposition.Lien.genre` (`.rattachement` par défaut, `.radio`, `.parent`) et `Disposition.Lien.qualite`. Sans maillage, la disposition de l'étape 1 ne change pas ;
  - dans le banc, `routeur(… xa:)`.

`Disposition.swift` est donné en entier : la construction des anneaux est réorganisée pour placer les routeurs de la sonde et ranger les enfants près de leur parent.

- [ ] **Step 1 : écrire les tests.**

Dans `MaillageCoeurTests/Banc.swift`, 2 blocs, dans l'ordre :

1. Remplacer :

```swift
    /// Routeur de bordure ; `role` nil : Thread 1.3 (role inconnu).
    mutating func routeur(_ nom: String, partition: String = "73586B68", role: RoleThread? = .routeur,
                          primaire: Bool = false, lien: String, omr: String? = nil,
                          xp: String = "4B36A2B7FEFB200B", nn: String = "MyHome1482620090") {
```

   par :

```swift
    /// Routeur de bordure ; `role` nil : Thread 1.3 (role inconnu) ; `xa` : son ExtMac.
    mutating func routeur(_ nom: String, partition: String = "73586B68", role: RoleThread? = .routeur,
                          primaire: Bool = false, lien: String, omr: String? = nil,
                          xp: String = "4B36A2B7FEFB200B", nn: String = "MyHome1482620090", xa: String? = nil) {
```

2. Remplacer :

```swift
        if let omr, let p = PrefixeIPv6(omr) { txt["omr"] = Data([64] + p.octets) }
```

   par :

```swift
        if let omr, let p = PrefixeIPv6(omr) { txt["omr"] = Data([64] + p.octets) }
        if let xa { txt["xa"] = Data(hexa: xa)! }
```

`MaillageCoeurTests/RapprochementTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Rapprochement du maillage et disposition avec la sonde")
struct RapprochementTests {
    static let omr = "fd00:5555:6666::/64"

    /// Partition 46CBEBCD : l'Apple TV (BBR principal), le HomePod du bureau (parent
    /// de la sonde, `xa` connu), un HomePod que la sonde ne reconnait pas ; les
    /// appareils de la capture par leur ExtMac, un appareil HomeKit reconnu par son
    /// adresse OMR, un appareil que la sonde ne voit pas.
    static func instantane() -> Instantane {
        var b = Banc()
        b.routeur("Apple TV", partition: "46CBEBCD", primaire: true, lien: "fe80::1", omr: omr, xa: "E0000000000000A1")
        b.routeur("HomePod bureau", partition: "46CBEBCD", lien: "fe80::2", omr: omr, xa: "E000000000000007")
        b.routeur("HomePod salon", partition: "46CBEBCD", lien: "fe80::3", omr: omr, xa: "E0000000000000A2")
        for (i, ext) in ["E000000000000002", "E000000000000003", "E000000000000004", "E000000000000005",
                         "E000000000000009", "E00000000000000A"].enumerated() {
            b.appareil(ext, noeud: i + 1, adresses: ["fd00:5555:6666:0:b00::\(i + 1)"])
        }
        b.appareil("Eve-HAP", noeud: 20, adresses: ["fd00:5555:6666:0:a00::9"])
        b.appareil("Absent", noeud: 21, adresses: ["fd00:5555:6666:0:b00::99"])
        return Instantane(annonces: b.annonces)
    }

    static func maillage() async throws -> Maillage {
        let sonde = try SondeRejouee.capture()
        return try #require(try await Tournee.executer(sonde, memoire: MemoireTournee(), maintenant: .now)).maillage
    }

    static func affiches(_ i: Instantane) -> [AppareilAffiche] {
        i.appareils.map { AppareilAffiche(id: $0.id, nom: $0.id, partition: $0.partition, etat: .joignable) }
    }

    /// Routeurs : par `xa`, BBR principal, appareil qui route, inconnu ; enfants : par
    /// ExtMac, par adresse, inconnus ; liens radio et enfant-parent.
    @Test func rapprochement() async throws {
        let i = Self.instantane()
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await Self.maillage(), reseau: r, appareils: i.appareils)
        #expect(m.routeurs[43]?.id == "HomePod bureau", "par son xa")
        #expect(m.routeurs[45]?.id == "Apple TV", "BBR principal")
        #expect(m.routeurs[20]?.id == "E000000000000002", "appareil qui route")
        #expect(m.routeurs[24]?.id == "E000000000000003")
        #expect(m.routeurs[1] == NoeudSonde(id: "rloc:0400", rloc16: 0x0400, genre: .routeur, reconnu: false, bordure: true))
        #expect(m.enfants[0x5004]?.id == "E000000000000004")
        #expect(m.enfants[0x6003]?.id == "Eve-HAP", "par son adresse OMR")
        #expect(m.enfants[0x6002]?.id == "rloc:6002")
        #expect(m.enfants[0xAC09]?.id == "rloc:AC09", "la sonde, sans ExtMac (firmware d'essai)")
        #expect(m.inconnus.filter { $0.genre == .routeur }.map(\.id) == ["rloc:0400", "rloc:CC00", "rloc:E400"])
        #expect(m.inconnus.count == 12)
        #expect(m.liens.contains(LienAffiche(de: "E000000000000002", vers: "E000000000000003", genre: .radio, qualite: 3)))
        #expect(m.liens.contains(LienAffiche(de: "E000000000000004", vers: "E000000000000002", genre: .parent, qualite: 2)))
        #expect(m.liens.contains(LienAffiche(de: "E00000000000000A", vers: "HomePod bureau", genre: .parent, qualite: nil)))
        #expect(m.parent(de: "E000000000000005") == "E000000000000002")
        #expect(m.noeud("Apple TV")?.rloc16 == 0xB400)
    }

    /// Anneau interieur : routeurs de bordure hors centre, appareils qui routent,
    /// routeurs inconnus ; enfants pres de leur parent ; liens de la sonde, et le
    /// rattachement pour les noeuds qu'elle ne relie pas.
    @Test func disposition() async throws {
        let i = Self.instantane()
        let r = try #require(i.reseaux.first)
        let m = MaillageAffiche(maillage: try await Self.maillage(), reseau: r, appareils: i.appareils)
        let d = Disposition(reseau: r, appareils: Self.affiches(i), maillage: m)
        #expect(d.noeud("Apple TV")?.genre == .centre)
        let interieur = d.noeuds.filter { abs($0.position.distance(Point2D(0, 0)) - Disposition.rayonInterieur) < 0.001 }
        #expect(interieur.map(\.id) == ["HomePod bureau", "HomePod salon", "E000000000000002", "E000000000000003",
                                        "rloc:0400", "rloc:CC00", "rloc:E400"])
        #expect(d.noeud("E000000000000002")?.genre == .appareil)
        #expect(d.noeud("E000000000000002")?.rayon == 9)
        #expect(d.noeud("rloc:0400")?.genre == .routeur)
        #expect(d.noeud("rloc:6002")?.genre == .appareil, "enfant inconnu : sur l'anneau exterieur")
        #expect(d.liens.filter { $0.genre == .radio }.count == 7)
        #expect(d.liens.contains(Disposition.Lien(de: "E000000000000004", vers: "E000000000000002", genre: .parent, qualite: 2)))
        #expect(d.liens.contains(Disposition.Lien(de: "HomePod salon", vers: "Apple TV")), "sans lien connu : rattachement")
        #expect(d.liens.contains(Disposition.Lien(de: "Absent", vers: "Apple TV")))
        #expect(!d.liens.contains { $0.de == "E000000000000004" && $0.genre == .rattachement })
        // Les deux enfants de 5000 (E...04 et E...05) cote a cote sur l'anneau exterieur.
        let exterieur = d.noeuds.filter { $0.genre == .appareil && !interieur.contains($0) }.map(\.id)
        let i4 = try #require(exterieur.firstIndex(of: "E000000000000004"))
        let i5 = try #require(exterieur.firstIndex(of: "E000000000000005"))
        #expect(abs(i4 - i5) == 1)
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageCoeurTests/RapprochementTests MaillageCoeurTests/DispositionTests`
Expected: la compilation échoue, par exemple avec `error: cannot find 'LienAffiche' in scope` et `error: cannot find 'MaillageAffiche' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageCoeur/Maillage/Rapprochement.swift` :

```swift
import Foundation

/// Noeud de la sonde place dans le graphe.
public struct NoeudSonde: Hashable, Sendable, Identifiable {
    public enum Genre: String, Hashable, Sendable {
        case routeur, enfant
    }

    /// Id du noeud du graphe : instance du routeur de bordure, id de l'appareil, ou
    /// "rloc:B400" quand l'instantane ne le connait pas.
    public let id: String
    public let rloc16: UInt16
    public let genre: Genre
    /// Retrouve dans l'instantane.
    public let reconnu: Bool
    /// Routeur de bordure (Network Data).
    public let bordure: Bool

    public init(id: String, rloc16: UInt16, genre: Genre, reconnu: Bool, bordure: Bool) {
        self.id = id
        self.rloc16 = rloc16
        self.genre = genre
        self.reconnu = reconnu
        self.bordure = bordure
    }
}

/// Lien de la sonde entre deux noeuds du graphe.
public struct LienAffiche: Hashable, Sendable {
    public enum Genre: String, Hashable, Sendable {
        /// Entre deux routeurs voisins.
        case radio
        /// De l'enfant vers son parent.
        case parent
    }

    public let de: String
    public let vers: String
    public let genre: Genre
    /// De 0 a 3 ; nil : inconnue (parent muet).
    public let qualite: Int?
}

/// Maillage de la sonde rapproche de l'instantane (spec de la sonde, section 4) :
/// ce que le graphe dessine.
public struct MaillageAffiche: Hashable, Sendable {
    public let partition: String
    public let date: Date
    /// Routeurs, par identifiant de routeur.
    public let routeurs: [Int: NoeudSonde]
    /// Enfants, par RLOC16.
    public let enfants: [UInt16: NoeudSonde]
    public let liens: [LienAffiche]

    /// Rapproche le maillage des routeurs de bordure de sa partition et des appareils :
    /// - routeur de bordure : son ExtMac est le `xa` de son annonce ; a defaut, le
    ///   BBR principal des Network Data est celui dont `sb` le dit ;
    /// - autre routeur ou enfant : son ExtMac est l'hote de l'appareil ; a defaut
    ///   (enfant), une adresse commune ;
    /// - sinon "rloc:XXXX", inconnu de l'instantane.
    public init(maillage: Maillage, reseau: Reseau, appareils: [Appareil]) {
        partition = maillage.partition
        date = maillage.date
        let bordures = reseau.partitions.first { $0.id == maillage.partition }?.routeurs ?? []
        let parId = Dictionary(appareils.map { ($0.id.uppercased(), $0) }, uniquingKeysWith: { a, _ in a })
        func rloc(_ r: UInt16) -> String { String(format: "rloc:%04X", r) }

        var routeurs: [Int: NoeudSonde] = [:]
        var pris: Set<String> = []
        for r in maillage.routeurs {
            var id: String?
            if let ext = r.extMac, let br = bordures.first(where: { $0.adresseEtendue == ext }) {
                id = br.instance
            } else if r.bbrPrincipal, let br = bordures.first(where: { $0.etat?.bbrPrimaire == true }),
                      !maillage.routeurs.contains(where: { $0.extMac == br.adresseEtendue && $0.id != r.id }) {
                id = br.instance
            } else if let ext = r.extMac, let a = parId[ext] {
                id = a.id
            }
            if let i = id, pris.contains(i) { id = nil }
            if let i = id { pris.insert(i) }
            routeurs[r.id] = NoeudSonde(id: id ?? rloc(r.rloc16), rloc16: r.rloc16, genre: .routeur, reconnu: id != nil,
                                        bordure: r.bordure)
        }

        var enfants: [UInt16: NoeudSonde] = [:]
        for e in maillage.enfants {
            var id = e.extMac.flatMap { parId[$0]?.id }
            if id == nil, !e.adresses.isEmpty {
                let adresses = Set(e.adresses)
                id = appareils.first { !adresses.isDisjoint(with: $0.adresses) }?.id
            }
            if let i = id, pris.contains(i) { id = nil }
            if let i = id { pris.insert(i) }
            enfants[e.rloc16] = NoeudSonde(id: id ?? rloc(e.rloc16), rloc16: e.rloc16, genre: .enfant, reconnu: id != nil,
                                           bordure: false)
        }

        var liens = maillage.liens.compactMap { l -> LienAffiche? in
            guard let a = routeurs[l.a], let b = routeurs[l.b] else { return nil }
            return LienAffiche(de: a.id, vers: b.id, genre: .radio, qualite: l.qualite)
        }
        for e in maillage.enfants {
            guard let enfant = enfants[e.rloc16], let parent = routeurs[e.parent] else { continue }
            liens.append(LienAffiche(de: enfant.id, vers: parent.id, genre: .parent, qualite: e.qualite))
        }
        self.routeurs = routeurs
        self.enfants = enfants
        self.liens = liens
    }

    /// Noeud du graphe, routeur ou enfant.
    public func noeud(_ id: String) -> NoeudSonde? {
        routeurs.values.first { $0.id == id } ?? enfants.values.first { $0.id == id }
    }

    /// Noeuds que l'instantane n'a pas, a ajouter au graphe : routeurs, puis enfants, par RLOC16.
    public var inconnus: [NoeudSonde] {
        let r = routeurs.values.filter { !$0.reconnu }.sorted { $0.rloc16 < $1.rloc16 }
        let e = enfants.values.filter { !$0.reconnu }.sorted { $0.rloc16 < $1.rloc16 }
        return r + e
    }

    /// Parent d'un noeud enfant (id de noeud), s'il est connu.
    public func parent(de id: String) -> String? {
        liens.first { $0.genre == .parent && $0.de == id }?.vers
    }

    /// Ids des noeuds routeurs.
    public var idsRouteurs: Set<String> { Set(routeurs.values.map(\.id)) }
}
```

`MaillageCoeur/Disposition/Disposition.swift` :

```swift
import Foundation

/// Point du plan du graphe (unites libres ; y vers le bas, comme a l'ecran).
public struct Point2D: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    public func distance(_ p: Point2D) -> Double { hypot(x - p.x, y - p.y) }
}

/// Etat d'un appareil tel que le graphe le montre.
public enum EtatAffiche: String, Hashable, Sendable {
    case joignable, partitionCoupee, sansAdresse, disparu, inconnu
}

/// Appareil a dessiner : nom deja choisi, partition courante ou derniere connue.
public struct AppareilAffiche: Hashable, Sendable, Identifiable {
    public var id: String
    public var nom: String
    public var piece: String?
    public var partition: String?
    public var etat: EtatAffiche
    public var endormi: Bool
    /// Batterie selon Maison, pour un appareil qui en a une.
    public var batterie: BatterieMaison?

    public init(id: String, nom: String, piece: String? = nil, partition: String?, etat: EtatAffiche,
                endormi: Bool = false, batterie: BatterieMaison? = nil) {
        self.id = id
        self.nom = nom
        self.piece = piece
        self.partition = partition
        self.etat = etat
        self.endormi = endormi
        self.batterie = batterie
    }
}

/// Disposition stable du graphe d'un reseau : memes noeuds, memes positions.
/// Une zone par partition (la principale au centre, les autres en colonne a sa
/// droite) ; dans une zone : le centre (chef, sinon BBR primaire), les autres
/// routeurs sur un anneau interieur, les appareils sur un anneau exterieur
/// (tries par piece puis par nom), et un lien de chaque noeud vers le centre
/// (rattachement, pas un lien radio). Les appareils sans partition connue vont
/// dans une zone sans centre, sous la principale.
///
/// Avec la sonde, dans sa partition : les appareils qui routent et les routeurs
/// inconnus rejoignent l'anneau interieur, les enfants se rangent pres de leur
/// parent, et les liens sont ceux de la sonde (radio entre routeurs, enfant vers
/// parent) ; un noeud sans lien connu garde son rattachement.
public struct Disposition: Hashable, Sendable {
    public enum Genre: String, Hashable, Sendable {
        case centre, routeur, appareil
    }

    public struct Zone: Hashable, Sendable, Identifiable {
        /// Identifiant de la partition ; "" pour les appareils sans partition connue.
        public var id: String
        public var centre: Point2D
        public var rayon: Double
        public var principale: Bool
        /// Prefixes attribues a la partition.
        public var prefixes: [PrefixeIPv6]
        /// Prefixes partages de la partition (`Partition.prefixesPartages`).
        public var prefixesPartages: [PrefixeIPv6]

        /// Prefixes du titre : ceux de la partition, plus les partages qu'elle
        /// revendique sans les avoir eus ; tries.
        public var prefixesTitre: [PrefixeIPv6] { Set(prefixes + prefixesPartages).sorted() }
    }

    public struct Noeud: Hashable, Sendable, Identifiable {
        /// Instance du routeur ou identifiant de l'appareil.
        public var id: String
        public var genre: Genre
        public var zone: String
        public var position: Point2D
        public var rayon: Double
    }

    public struct Lien: Hashable, Sendable {
        public enum Genre: String, Hashable, Sendable {
            /// Pointille vers le centre : rattachement suppose, pas un lien radio.
            case rattachement
            /// Lien radio entre deux routeurs, vu par la sonde.
            case radio
            /// De l'enfant vers son parent, vu par la sonde.
            case parent
        }

        public var de: String
        public var vers: String
        public var genre: Genre = .rattachement
        /// De 0 a 3 ; nil : inconnue.
        public var qualite: Int?
    }

    public static let rayonInterieur = 90.0
    public static let rayonExterieurMin = 170.0
    /// Arc minimal entre deux appareils voisins sur l'anneau.
    public static let arcAppareil = 36.0
    public static let marge = 40.0
    public static let ecart = 60.0
    public static let rayonZoneSeule = 60.0

    public private(set) var zones: [Zone] = []
    public private(set) var noeuds: [Noeud] = []
    public private(set) var liens: [Lien] = []

    public init(reseau: Reseau, appareils: [AppareilAffiche], maillage: MaillageAffiche? = nil) {
        let connues = Set(reseau.partitions.map(\.id))
        let parZone = Dictionary(grouping: appareils) { a in
            a.partition.flatMap { connues.contains($0) ? $0 : nil } ?? ""
        }
        func tries(_ l: [AppareilAffiche]) -> [AppareilAffiche] {
            l.sorted { ($0.piece ?? "\u{10FFFF}", $0.nom, $0.id) < ($1.piece ?? "\u{10FFFF}", $1.nom, $1.id) }
        }
        func rayonAppareils(_ n: Int) -> Double {
            max(Self.rayonExterieurMin, Double(n) * Self.arcAppareil / (2 * .pi))
        }
        func rayonZone(_ routeurs: Int, _ apps: Int) -> Double {
            if apps == 0 { return routeurs <= 1 ? Self.rayonZoneSeule : Self.rayonInterieur + Self.marge }
            return rayonAppareils(apps) + Self.marge
        }

        // Anneaux de chaque zone : routeurs (hors centre) a l'interieur, appareils a l'exterieur.
        struct Anneaux {
            var interieur: [(id: String, genre: Genre, rayon: Double)] = []
            var exterieur: [String] = []
            var sonde: MaillageAffiche?
        }
        let anneaux = reseau.partitions.map { p -> Anneaux in
            let apps = tries(parZone[p.id] ?? [])
            var a = Anneaux()
            a.interieur = p.routeurs.dropFirst().map { ($0.instance, Genre.routeur, 15.0) }
            guard let m = maillage, m.partition == p.id else {
                a.exterieur = apps.map(\.id)
                return a
            }
            a.sonde = m
            let routeurs = m.idsRouteurs
            a.interieur += apps.filter { routeurs.contains($0.id) }.map { ($0.id, Genre.appareil, 9.0) }
            a.interieur += m.inconnus.filter { $0.genre == .routeur }.map { ($0.id, Genre.routeur, 12.0) }
            a.exterieur = apps.filter { !routeurs.contains($0.id) }.map(\.id) + m.inconnus.filter { $0.genre == .enfant }.map(\.id)
            return a
        }

        // Rayons, puis centres : la principale en (0, 0), les autres en colonne a droite.
        let rayons = zip(reseau.partitions, anneaux).map { rayonZone($0.routeurs.count, $1.exterieur.count) }
        let r0 = rayons.first ?? Self.rayonZoneSeule
        let secondaires = Array(rayons.dropFirst())
        var y = -(secondaires.reduce(0) { $0 + 2 * $1 } + Self.ecart * Double(max(secondaires.count - 1, 0))) / 2
        var centres = [Point2D(0, 0)]
        for r in secondaires {
            centres.append(Point2D(r0 + Self.ecart + r, y + r))
            y += 2 * r + Self.ecart
        }

        for (k, p) in reseau.partitions.enumerated() {
            let centre = centres[k]
            zones.append(Zone(id: p.id, centre: centre, rayon: rayons[k], principale: p.estPrincipale, prefixes: p.prefixes,
                              prefixesPartages: p.prefixesPartages))
            guard let premier = p.routeurs.first else { continue }
            noeuds.append(Noeud(id: premier.instance, genre: .centre, zone: p.id, position: centre, rayon: 22))
            let a = anneaux[k]
            var positions = [premier.instance: centre]
            for (i, r) in a.interieur.enumerated() {
                let pos = Self.surAnneau(centre, Self.rayonInterieur, i, a.interieur.count)
                positions[r.id] = pos
                noeuds.append(Noeud(id: r.id, genre: r.genre, zone: p.id, position: pos, rayon: r.rayon))
            }
            // Avec la sonde, chaque enfant pres de son parent : par angle du parent, puis dans l'ordre des appareils.
            var exterieur = a.exterieur
            if let m = a.sonde {
                // Les enfants du centre en fin d'anneau : ils ne se melent pas a ceux du premier routeur.
                func angle(_ id: String) -> Double {
                    guard let pere = m.parent(de: id), let pos = positions[pere] else { return 10 }
                    if pere == premier.instance { return 3 * .pi / 2 }
                    let t = atan2(pos.y - centre.y, pos.x - centre.x)
                    return t < -.pi / 2 ? t + 2 * .pi : t
                }
                let rang = Dictionary(exterieur.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
                exterieur.sort { (angle($0), rang[$0] ?? 0) < (angle($1), rang[$1] ?? 0) }
            }
            for (j, id) in exterieur.enumerated() {
                let pos = Self.surAnneau(centre, rayonAppareils(exterieur.count), j, exterieur.count)
                positions[id] = pos
                noeuds.append(Noeud(id: id, genre: .appareil, zone: p.id, position: pos, rayon: 7))
            }
            // Liens : ceux de la sonde entre noeuds de la zone ; le rattachement au centre pour les autres.
            var relies: Set<String> = [premier.instance]
            for l in a.sonde?.liens ?? [] where positions[l.de] != nil && positions[l.vers] != nil {
                liens.append(Lien(de: l.de, vers: l.vers, genre: l.genre == .radio ? .radio : .parent, qualite: l.qualite))
                relies.insert(l.de)
                relies.insert(l.vers)
            }
            for id in a.interieur.map(\.id) + exterieur where !relies.contains(id) {
                liens.append(Lien(de: id, vers: premier.instance))
            }
        }

        // Appareils sans partition connue : sous la principale, sans centre.
        let orphelins = tries(parZone[""] ?? [])
        if !orphelins.isEmpty {
            let rAnneau = max(Self.rayonZoneSeule, Double(orphelins.count) * Self.arcAppareil / (2 * .pi))
            let rayon = rAnneau + Self.marge
            let centre = Point2D(0, r0 + Self.ecart + rayon)
            zones.append(Zone(id: "", centre: centre, rayon: rayon, principale: false, prefixes: [], prefixesPartages: []))
            for (j, a) in orphelins.enumerated() {
                noeuds.append(Noeud(id: a.id, genre: .appareil, zone: "",
                                    position: Self.surAnneau(centre, rAnneau, j, orphelins.count), rayon: 7))
            }
        }
    }

    /// i-eme de n positions sur un cercle, en partant du haut, dans le sens horaire.
    static func surAnneau(_ c: Point2D, _ r: Double, _ i: Int, _ n: Int) -> Point2D {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(max(n, 1))
        return Point2D(c.x + r * cos(angle), c.y + r * sin(angle))
    }

    /// Rectangle qui contient toutes les zones.
    public var cadre: (min: Point2D, max: Point2D) {
        guard !zones.isEmpty else { return (Point2D(-100, -100), Point2D(100, 100)) }
        return (Point2D(zones.map { $0.centre.x - $0.rayon }.min()!, zones.map { $0.centre.y - $0.rayon }.min()!),
                Point2D(zones.map { $0.centre.x + $0.rayon }.max()!, zones.map { $0.centre.y + $0.rayon }.max()!))
    }

    public func noeud(_ id: String) -> Noeud? { noeuds.first { $0.id == id } }

    /// Noeud le plus proche d'un point, s'il est a moins de son rayon (+ tolerance).
    public func noeud(a p: Point2D, tolerance: Double = 6) -> Noeud? {
        noeuds.filter { $0.position.distance(p) <= $0.rayon + tolerance }
            .min { $0.position.distance(p) < $1.position.distance(p) }
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageCoeurTests/RapprochementTests MaillageCoeurTests/DispositionTests`
Expected: `Test run with 7 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `outils/tester.sh`
Expected: `Test run with 121 tests in 19 suites passed` (cœur) et `Test run with 38 tests in 13 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeurTests/Banc.swift MaillageCoeurTests/RapprochementTests.swift MaillageCoeur/Maillage/Rapprochement.swift MaillageCoeur/Disposition/Disposition.swift
git commit -m "Rapprocher le maillage de l'instantane et le disposer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 8: Firmware de la sonde 1.0.0

**Files:**
- Create: `sonde/README.md`
- Modify: `sonde/src/main.cpp` (fichier entier ci-dessous), `sonde/platformio.ini` (blocs ci-dessous)

**Interfaces:**
- Consumes : le firmware d'essai de `essai-sonde` (`sonde/src/main.cpp`). Il porte le rôle MED par `--wrap` de `_SetThreadDeviceType`, et la table `huge_app.csv`.
- Produces : le firmware 1.0.0, conforme à la section 3 de la spec :
  - `bonjour`, avec `version` « 1.0.0 » ;
  - `etat`, avec `ext` (l'ExtMac de la sonde) ;
  - `voisins` ;
  - `diag <cible> <tlv,…> <id> [<délai ms>]` : jusqu'à 8 requêtes en vol, et `occupee` au-delà ; délai de 3 à 60 s, 45 s par défaut.

  `MessageSonde` (tâche 4) et `SondeUSB` (tâche 10) lisent ces messages.

Le firmware n'a pas de tests automatiques : il est vérifié par sa compilation ici, puis sur la carte avec Djoko (tâche 12). `main.cpp` est donné en entier : ses changements (requêtes en vol par `id`, délai par requête, `ext`) touchent tout le fichier.

- [ ] **Step 1 : écrire le firmware.**

`sonde/src/main.cpp` :

```cpp
// ===========================================================================
//  Sonde de maillage Thread, firmware 1.0.0 (spec de la sonde, sections 2 et 3)
//
//  Noeud Matter sur Thread, en MED : il recoit en permanence mais ne relaie
//  rien, et ne devient jamais le parent de personne. Maison lui donne les
//  identifiants du reseau a l'appairage par Bluetooth.
//
//  La pile OpenThread precompilee d'Arduino n'a pas de client de diagnostic :
//  la sonde fabrique elle-meme la requete DIAG_GET (CoAP POST d/dg, TLV
//  Type List) et l'envoie au port TMF 61631 du noeud vise. La reponse revient
//  sur le port CoAP de la sonde ; ses TLV partent en hexa, sans decodage :
//  c'est l'app qui decode. Jusqu'a 8 requetes en vol, reperees par leur id.
//
//  USB : une commande par ligne ; chaque reponse est une ligne machine,
//  RS (0x1E) + JSON compact en ASCII + LF, 4096 octets au plus.
//    bonjour                          produit, version, appairage (code tant
//                                     que la sonde n'est pas dans Maison)
//    etat                             role, RLOC16, ExtMac, parent, partition...
//    voisins                          table des voisins (le parent, pour un MED)
//    diag <cible> <t,t,...> <id> [ms] DIAG_GET vers <cible> : RLOC16 en 4 hexa
//                                     (adresse RLOC formee sur le prefixe du
//                                     reseau maille) ou adresse IPv6 ; delai de
//                                     3 a 60 s, 45 s par defaut
//    oubli                            desappaire la sonde et redemarre
//
//  Dans Maison : un interrupteur « Sonde maillage », allume par defaut.
//  Eteint, la sonde refuse les requetes (erreur « suspendue »).
// ===========================================================================

#include <Arduino.h>
#include <Matter.h>
#include <app/server/Server.h>
#include <esp_mac.h>
#include <esp_openthread.h>
#include <esp_openthread_lock.h>
#include <openthread/coap.h>
#include <openthread/ip6.h>
#include <openthread/link.h>
#include <openthread/message.h>
#include <openthread/thread.h>
#include <stdarg.h>

static const char *const kVersion = "1.0.0";

// ---------------------------------------------------------------------------
//  MED des l'init de Thread (repris du pont Halo, benq matter_bridge.cpp) :
//  esp_matter::start demande « routeur » ; l'enveloppe le remplace par MED.
//  Lien : -Wl,--wrap=<symbole> dans platformio.ini.
// ---------------------------------------------------------------------------

using ThreadDeviceType = chip::DeviceLayer::ConnectivityManager::ThreadDeviceType;

extern "C" CHIP_ERROR
__real__ZN4chip11DeviceLayer8Internal40GenericThreadStackManagerImpl_OpenThreadINS0_22ThreadStackManagerImplEE20_SetThreadDeviceTypeENS0_19ConnectivityManager16ThreadDeviceTypeE(
    void *self, ThreadDeviceType type);

extern "C" CHIP_ERROR
__wrap__ZN4chip11DeviceLayer8Internal40GenericThreadStackManagerImpl_OpenThreadINS0_22ThreadStackManagerImplEE20_SetThreadDeviceTypeENS0_19ConnectivityManager16ThreadDeviceTypeE(
    void *self, ThreadDeviceType type) {
  if (type == chip::DeviceLayer::ConnectivityManager::kThreadDeviceType_Router)
    type = chip::DeviceLayer::ConnectivityManager::kThreadDeviceType_MinimalEndDevice;
  return __real__ZN4chip11DeviceLayer8Internal40GenericThreadStackManagerImpl_OpenThreadINS0_22ThreadStackManagerImplEE20_SetThreadDeviceTypeENS0_19ConnectivityManager16ThreadDeviceTypeE(
      self, type);
}

// ---------------------------------------------------------------------------
//  Etat partage
// ---------------------------------------------------------------------------

static MatterOnOffPlugin sInterrupteur;  // « Sonde maillage »
static volatile bool sSuspendue = false;
static bool sThreadPret = false;  // pile Thread creee par Matter.begin()
static char sMac[13] = "?";

// Verrou OpenThread, delai total borne. REGLE (benq) : sous ce verrou, aucun
// appel Matter/CHIP ; la tache CHIP prend le verrou OT en tenant le sien.
static bool verrouOt(uint32_t ms) { return sThreadPret && esp_openthread_lock_acquire(pdMS_TO_TICKS(ms / 2)); }
static void libereOt() { esp_openthread_lock_release(); }

// ---------------------------------------------------------------------------
//  Ligne machine : RS + JSON + LF, 4096 octets au plus
// ---------------------------------------------------------------------------

static char sLigne[4096];
static size_t sLong = 0;
static bool sTropLong = false;

static void ajoute(const char *fmt, ...) {
  if (sTropLong) return;
  va_list ap;
  va_start(ap, fmt);
  const size_t reste = sizeof(sLigne) - sLong - 2;  // place pour '}' et LF
  const int n = vsnprintf(sLigne + sLong, reste, fmt, ap);
  va_end(ap);
  if (n < 0 || (size_t)n >= reste) {
    sTropLong = true;
    return;
  }
  sLong += (size_t)n;
}

static void debut(const char *type) {
  sLong = 0;
  sTropLong = false;
  sLigne[sLong++] = 0x1E;
  ajoute("{\"v\":1,\"t\":\"%s\"", type);
}

static void fin() {
  if (sTropLong) {
    debut("erreur");
    ajoute(",\"erreur\":\"ligne trop longue\"");
  }
  sLigne[sLong++] = '}';
  sLigne[sLong++] = '\n';
  Serial.write((const uint8_t *)sLigne, sLong);
}

static void hexa(const char *cle, const uint8_t *o, size_t n) {
  ajoute(",\"%s\":\"", cle);
  for (size_t i = 0; i < n && !sTropLong; i++) ajoute("%02X", o[i]);
  ajoute("\"");
}

// ---------------------------------------------------------------------------
//  Matter
// ---------------------------------------------------------------------------

static bool surInterrupteur(bool allume) {
  sSuspendue = !allume;
  return true;
}

static void demarrerMatter() {
  uint8_t mac[8] = {};
  if (esp_read_mac(mac, ESP_MAC_BASE) == ESP_OK)
    snprintf(sMac, sizeof(sMac), "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  // Avant le premier begin() d'accessoire : c'est lui qui cree le noeud.
  if (!Matter.selectNetwork(MATTER_NETWORK_THREAD)) Serial.println("!! selectNetwork(THREAD) refuse");
  sInterrupteur.begin(true);
  sInterrupteur.onChangeOnOff(surInterrupteur);
  char serie[20];
  snprintf(serie, sizeof(serie), "SONDE-%s", sMac);
  Matter.setVendorName("Maillage Thread");
  Matter.setProductName("Sonde maillage");
  Matter.setDeviceName("Sonde maillage");
  Matter.setSerialNumber(serie);
  Matter.begin();
  sThreadPret = chip::DeviceLayer::ThreadStackMgrImpl().OTInstance() != nullptr;
  if (!sThreadPret) Serial.println("!! pile Thread absente");
}

// ---------------------------------------------------------------------------
//  Commandes simples
// ---------------------------------------------------------------------------

static void cmdBonjour() {
  const bool appairee = Matter.isDeviceCommissioned();
  debut("bonjour");
  ajoute(",\"produit\":\"sonde-maillage\",\"version\":\"%s\",\"mac\":\"%s\",\"appairee\":%s", kVersion, sMac,
         appairee ? "true" : "false");
  if (appairee) {
    ajoute(",\"code\":null,\"qr\":null");
  } else {
    // L'URL du QR code porte la charge utile « MT:... » apres « data= ».
    String url = Matter.getOnboardingQRCodeUrl();
    const int i = url.indexOf("data=");
    String qr = i >= 0 ? url.substring(i + 5) : url;
    qr.replace("%3A", ":");
    ajoute(",\"code\":\"%s\",\"qr\":\"%s\"", Matter.getManualPairingCode().c_str(), qr.c_str());
  }
  fin();
}

static void cmdEtat() {
  debut("etat");
  if (!verrouOt(200)) {
    ajoute(",\"erreur\":\"occupee\"");
    fin();
    return;
  }
  otInstance *ot = esp_openthread_get_instance();
  const otDeviceRole role = otThreadGetDeviceRole(ot);
  ajoute(",\"role\":\"%s\",\"rloc16\":\"%04X\"", otThreadDeviceRoleToString(role), otThreadGetRloc16(ot));
  const otExtAddress *ext = otLinkGetExtendedAddress(ot);
  if (ext) hexa("ext", ext->m8, sizeof(ext->m8));
  const otLinkModeConfig mode = otThreadGetLinkMode(ot);
  ajoute(",\"mode\":\"%s%s%s\"", mode.mRxOnWhenIdle ? "r" : "", mode.mDeviceType ? "d" : "", mode.mNetworkData ? "n" : "");
  otRouterInfo parent;
  if (role == OT_DEVICE_ROLE_CHILD && otThreadGetParentInfo(ot, &parent) == OT_ERROR_NONE) {
    int8_t moyen = 0;
    otThreadGetParentAverageRssi(ot, &moyen);
    ajoute(",\"parent\":{\"rloc16\":\"%04X\"", parent.mRloc16);
    hexa("ext", parent.mExtAddress.m8, sizeof(parent.mExtAddress.m8));
    ajoute(",\"lqIn\":%u,\"lqOut\":%u,\"rssi\":%d}", parent.mLinkQualityIn, parent.mLinkQualityOut, moyen);
  } else {
    ajoute(",\"parent\":null");
  }
  const bool attachee = role == OT_DEVICE_ROLE_CHILD || role == OT_DEVICE_ROLE_ROUTER || role == OT_DEVICE_ROLE_LEADER;
  if (attachee) {
    ajoute(",\"partition\":\"%08lX\",\"chef\":%u", (unsigned long)otThreadGetPartitionId(ot),
           otThreadGetLeaderRouterId(ot));
  } else {
    ajoute(",\"partition\":null,\"chef\":null");
  }
  ajoute(",\"canal\":%u", otLinkGetChannel(ot));
  const otMeshLocalPrefix *ml = otThreadGetMeshLocalPrefix(ot);
  if (ml) hexa("prefixeMaille", ml->m8, sizeof(ml->m8));
  const otExtendedPanId *xp = otThreadGetExtendedPanId(ot);
  if (xp) hexa("xp", xp->m8, sizeof(xp->m8));
  libereOt();
  ajoute(",\"suspendue\":%s", sSuspendue ? "true" : "false");
  fin();
}

static void cmdVoisins() {
  debut("voisins");
  if (!verrouOt(200)) {
    ajoute(",\"erreur\":\"occupee\"");
    fin();
    return;
  }
  otInstance *ot = esp_openthread_get_instance();
  otNeighborInfoIterator it = OT_NEIGHBOR_INFO_ITERATOR_INIT;
  otNeighborInfo v;
  ajoute(",\"liste\":[");
  bool premier = true;
  while (otThreadGetNextNeighborInfo(ot, &it, &v) == OT_ERROR_NONE) {
    ajoute("%s{\"rloc16\":\"%04X\"", premier ? "" : ",", v.mRloc16);
    hexa("ext", v.mExtAddress.m8, sizeof(v.mExtAddress.m8));
    ajoute(",\"rssi\":%d,\"lqi\":%u,\"routeur\":%s}", v.mAverageRssi, v.mLinkQualityIn, v.mIsChild ? "false" : "true");
    premier = false;
  }
  ajoute("]");
  libereOt();
  fin();
}

// ---------------------------------------------------------------------------
//  DIAG_GET par CoAP, 8 en vol
// ---------------------------------------------------------------------------

static constexpr uint16_t kPortTmf = 61631;
static constexpr uint8_t kTlvTypeList = 18;
static constexpr size_t kTlvMax = 32;
static constexpr size_t kEnVol = 8;
static constexpr uint32_t kDelaiDefaut = 45000, kDelaiMin = 3000, kDelaiMax = 60000;

static bool sCoapDemarre = false;

// Un emplacement par requete en vol. `enVol` et `finie` passent de la tache
// OpenThread (rappel CoAP) a celle de loop() ; le reste est ecrit avant.
struct Requete {
  volatile bool enVol;
  volatile bool finie;
  uint32_t id;
  char cible[48];
  uint32_t debutMs, finMs;
  otError erreur;
  uint8_t code;  // code CoAP de la reponse
  uint8_t charge[1024];
  uint16_t longueur;
  bool tronquee;
};
static Requete sRequetes[kEnVol];

static void surReponse(void *contexte, otMessage *msg, const otMessageInfo *, otError erreur) {
  Requete &r = sRequetes[(uintptr_t)contexte];
  r.finMs = millis();
  r.erreur = erreur;
  r.longueur = 0;
  r.tronquee = false;
  if (erreur == OT_ERROR_NONE && msg) {
    r.code = (uint8_t)otCoapMessageGetCode(msg);
    const uint16_t debutCharge = otMessageGetOffset(msg);
    const uint16_t total = otMessageGetLength(msg) - debutCharge;
    const uint16_t n = total > sizeof(r.charge) ? sizeof(r.charge) : total;
    r.longueur = otMessageRead(msg, debutCharge, r.charge, n);
    r.tronquee = n < total;
  }
  r.finie = true;
}

// Reprises CoAP reglees pour que l'echec tombe au bout du delai demande :
// attente totale = accuse x (2^(reprises+1) - 1), facteur aleatoire de 1.
static otCoapTxParameters parametres(uint32_t delaiMs) {
  const uint8_t reprises = delaiMs < 10000 ? 1 : 3;
  const uint32_t facteur = (1u << (reprises + 1)) - 1;
  uint32_t accuse = delaiMs / facteur;
  if (accuse < 1000) accuse = 1000;  // plancher d'OpenThread
  otCoapTxParameters p = {accuse, 1, 1, reprises};
  return p;
}

static void repondreDiagErreur(uint32_t id, const char *cible, const char *erreur) {
  debut("diag");
  ajoute(",\"id\":%lu,\"cible\":\"%s\",\"ok\":false,\"erreur\":\"%s\"", (unsigned long)id, cible, erreur);
  fin();
}

// diag <cible> <t,t,...> <id> [<delai ms>]
static void cmdDiag(char *args) {
  char *cible = strtok(args, " ");
  char *liste = strtok(nullptr, " ");
  char *idTexte = strtok(nullptr, " ");
  char *delaiTexte = strtok(nullptr, " ");
  const uint32_t id = idTexte ? strtoul(idTexte, nullptr, 10) : 0;
  if (!cible || !liste || !idTexte || strlen(cible) >= sizeof(sRequetes[0].cible)) {
    repondreDiagErreur(id, "", "syntaxe");
    return;
  }
  if (sSuspendue) return repondreDiagErreur(id, cible, "suspendue");
  uint32_t delai = delaiTexte ? strtoul(delaiTexte, nullptr, 10) : kDelaiDefaut;
  if (delai < kDelaiMin) delai = kDelaiMin;
  if (delai > kDelaiMax) delai = kDelaiMax;

  size_t libre = kEnVol;
  for (size_t i = 0; i < kEnVol; i++)
    if (!sRequetes[i].enVol) {
      libre = i;
      break;
    }
  if (libre == kEnVol) return repondreDiagErreur(id, cible, "occupee");

  uint8_t types[kTlvMax];
  size_t nTypes = 0;
  for (char *t = strtok(liste, ","); t && nTypes < kTlvMax; t = strtok(nullptr, ",")) {
    const long v = strtol(t, nullptr, 10);
    if (v < 0 || v > 255) return repondreDiagErreur(id, cible, "syntaxe");
    types[nTypes++] = (uint8_t)v;
  }
  if (nTypes == 0) return repondreDiagErreur(id, cible, "syntaxe");

  if (!verrouOt(500)) return repondreDiagErreur(id, cible, "occupee");
  otInstance *ot = esp_openthread_get_instance();
  otIp6Address adresse;
  bool adresseOk = false;
  if (strlen(cible) == 4 && strspn(cible, "0123456789abcdefABCDEF") == 4) {
    // Adresse RLOC : prefixe du reseau maille + 0000:00ff:fe00:<rloc16>.
    const otMeshLocalPrefix *ml = otThreadGetMeshLocalPrefix(ot);
    if (ml) {
      const uint16_t rloc16 = (uint16_t)strtoul(cible, nullptr, 16);
      memset(&adresse, 0, sizeof(adresse));
      memcpy(adresse.mFields.m8, ml->m8, 8);
      adresse.mFields.m8[11] = 0xFF;
      adresse.mFields.m8[12] = 0xFE;
      adresse.mFields.m8[14] = (uint8_t)(rloc16 >> 8);
      adresse.mFields.m8[15] = (uint8_t)rloc16;
      adresseOk = true;
    }
  } else {
    adresseOk = otIp6AddressFromString(cible, &adresse) == OT_ERROR_NONE;
  }
  if (!adresseOk) {
    libereOt();
    return repondreDiagErreur(id, cible, "cible");
  }
  if (!sCoapDemarre) sCoapDemarre = otCoapStart(ot, OT_DEFAULT_COAP_PORT) == OT_ERROR_NONE;
  otMessage *msg = sCoapDemarre ? otCoapNewMessage(ot, nullptr) : nullptr;
  otError e = msg ? OT_ERROR_NONE : OT_ERROR_NO_BUFS;
  if (msg) {
    otCoapMessageInit(msg, OT_COAP_TYPE_CONFIRMABLE, OT_COAP_CODE_POST);
    otCoapMessageGenerateToken(msg, OT_COAP_DEFAULT_TOKEN_LENGTH);
    e = otCoapMessageAppendUriPathOptions(msg, "d/dg");
    if (e == OT_ERROR_NONE) e = otCoapMessageSetPayloadMarker(msg);
    const uint8_t entete[2] = {kTlvTypeList, (uint8_t)nTypes};
    if (e == OT_ERROR_NONE) e = otMessageAppend(msg, entete, sizeof(entete));
    if (e == OT_ERROR_NONE) e = otMessageAppend(msg, types, (uint16_t)nTypes);
  }
  if (e == OT_ERROR_NONE) {
    otMessageInfo info;
    memset(&info, 0, sizeof(info));
    info.mPeerAddr = adresse;
    info.mPeerPort = kPortTmf;
    const otCoapTxParameters p = parametres(delai);
    Requete &r = sRequetes[libre];
    r.id = id;
    snprintf(r.cible, sizeof(r.cible), "%s", cible);
    r.debutMs = millis();
    r.finie = false;
    r.enVol = true;
    e = otCoapSendRequestWithParameters(ot, msg, &info, surReponse, (void *)(uintptr_t)libre, &p);
    if (e != OT_ERROR_NONE) r.enVol = false;
  }
  if (e != OT_ERROR_NONE && msg) otMessageFree(msg);
  libereOt();
  if (e != OT_ERROR_NONE) {
    char texte[24];
    snprintf(texte, sizeof(texte), "envoi %s", otThreadErrorToString(e));
    repondreDiagErreur(id, cible, texte);
  }
}

static void imprimerDiag(const Requete &r) {
  debut("diag");
  ajoute(",\"id\":%lu,\"cible\":\"%s\",\"ms\":%lu", (unsigned long)r.id, r.cible, (unsigned long)(r.finMs - r.debutMs));
  if (r.erreur == OT_ERROR_NONE) {
    ajoute(",\"ok\":true,\"code\":\"%u.%02u\"", r.code >> 5, r.code & 0x1F);
    hexa("tlv", r.charge, r.longueur);
    if (r.tronquee) ajoute(",\"tronquee\":true");
  } else {
    ajoute(",\"ok\":false,\"erreur\":\"%s\"",
           r.erreur == OT_ERROR_RESPONSE_TIMEOUT ? "delai" : otThreadErrorToString(r.erreur));
  }
  fin();
}

// ---------------------------------------------------------------------------
//  Boucle
// ---------------------------------------------------------------------------

static char sCommande[200];
static size_t sCmdLong = 0;

static void executer(char *c) {
  while (*c == ' ') c++;
  if (!strcmp(c, "bonjour")) return cmdBonjour();
  if (!strcmp(c, "etat")) return cmdEtat();
  if (!strcmp(c, "voisins")) return cmdVoisins();
  if (!strncmp(c, "diag ", 5)) return cmdDiag(c + 5);
  if (!strcmp(c, "oubli")) {
    debut("oubli");
    fin();
    Serial.flush();
    Matter.decommission();  // efface l'appairage et redemarre
    return;
  }
  if (!*c) return;
  debut("erreur");
  ajoute(",\"erreur\":\"commande inconnue\"");
  fin();
}

void setup() {
  Serial.begin(115200);
  demarrerMatter();
  cmdBonjour();
}

void loop() {
  while (Serial.available()) {
    const int o = Serial.read();
    if (o == '\n' || o == '\r') {
      sCommande[sCmdLong] = 0;
      if (sCmdLong) executer(sCommande);
      sCmdLong = 0;
    } else if (o >= 0x20 && o < 0x7F && sCmdLong < sizeof(sCommande) - 1) {
      sCommande[sCmdLong++] = (char)o;
    }
  }
  for (Requete &r : sRequetes) {
    if (r.enVol && r.finie) {
      imprimerDiag(r);
      r.finie = false;
      r.enVol = false;
    }
  }
  delay(5);
}
```

Dans `sonde/platformio.ini`, remplacer :

```ini
; Sonde de maillage Thread : firmware D'ESSAI, prealable au plan 3a
; (docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md, section 7).
```

par :

```ini
; Sonde de maillage Thread, firmware 1.0.0 (spec :
; docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md).
```

`sonde/README.md` :

````markdown
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
d'appairage tant qu'elle n'est pas dans Maison. Maillage Thread l'affiche aussi,
dans Réglages › Sonde.
1. Dans Maison sur l'iPhone : « + » › Ajouter un accessoire › Plus d'options.
2. Saisir le code, ou scanner le QR code.
3. Maison dit « accessoire non certifié » : ajouter quand même.

La sonde apparaît comme une prise « Sonde maillage », allumée par défaut.
Éteinte, elle refuse les requêtes de diagnostic (`suspendue`).

`oubli` la désappaire et la redémarre.

## Protocole USB

Une commande par ligne. En retour, des lignes machine : RS (0x1E), JSON
compact en ASCII, LF, 4096 octets au plus. Pour ouvrir le port sans redémarrer
le C6, il faut mettre DTR et RTS à 0 dans un seul appel (voir benq).

| Commande | Réponse |
|---|---|
| `bonjour` | produit (`sonde-maillage`), version, MAC, appairée ou non, code d'appairage |
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
````

- [ ] **Step 2 : compiler, sans flasher.**

Run: `cd sonde && pio run`
Expected: `[SUCCESS]`, avec une ligne proche de `Flash: [========  ]  75.6% (used 2376630 bytes from 3145728 bytes)`. La première compilation télécharge la chaîne pioarduino si elle manque (plusieurs minutes).

Ne jamais ajouter `-t upload`, ni lancer `pio device monitor` : le flash se fait à la tâche 12, avec Djoko.

- [ ] **Step 3 : commit.**

```bash
git add sonde/src/main.cpp sonde/platformio.ini sonde/README.md
git commit -m "Firmware de la sonde 1.0.0 : 8 requetes en vol et ExtMac

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 9: App : liaison série

**Files:**
- Create: `MaillageThread/Sonde/PortSerie.swift`, `MaillageThread/Sonde/LiaisonSerie.swift`, `MaillageThread/Sonde/PortsUSB.swift`
- Modify: `MaillageThread/Droits.entitlements` (blocs ci-dessous)
- Modify (par les outils) : `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings`
- Test: `MaillageThreadTests/LiaisonSerieTests.swift`

**Interfaces:**
- Consumes : rien du cœur.
- Produces :
  - `PortSerie.ouvrir(_ chemin: String) throws -> Int32` et `ErreurPort` ;
  - `LiaisonSerie(chemin:)` : `ouvrir() throws -> AsyncStream<EvenementLiaison>` (`.donnees(Data)`, `.ferme(String)`), `envoyer(_ donnees: Data)`, `fermer()` ;
  - `PortUSB` (`chemin`, `vid`, `pid`, `serie`, `produit`, `estEspressif`, `libelle`) ;
  - `@MainActor final class PortsUSB` : `changement`, `demarrer()`, `arreter()`, `nonisolated static lister()`, `trier(_:)` ;
  - l'autorisation `com.apple.security.device.serial`.

- [ ] **Step 1 : écrire les tests.**

`MaillageThreadTests/LiaisonSerieTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageThread

@Suite("Liaison serie de la sonde")
struct LiaisonSerieTests {
    /// Seuls les /dev/cu.* s'ouvrent : un /dev/tty.* attendrait DCD.
    @Test func cheminCu() {
        #expect(throws: ErreurPort.self) { try PortSerie.ouvrir("/dev/tty.maillage-inexistant") }
        do {
            _ = try PortSerie.ouvrir("/dev/tty.maillage-inexistant")
        } catch {
            #expect("\(error)".contains("/dev/cu.*"))
        }
    }

    /// Un port absent echoue proprement, sans descripteur laisse ouvert.
    @Test func portAbsent() {
        let l = LiaisonSerie(chemin: "/dev/cu.maillage-inexistant")
        #expect(throws: ErreurPort.self) { _ = try l.ouvrir() }
    }

    @Test func ports() {
        let c6 = PortUSB(chemin: "/dev/cu.usbmodem11301", vid: 0x303A, pid: 0x1001, serie: "A0:00:00:00:00:01",
                         produit: "USB JTAG/serial debug unit")
        let ecran = PortUSB(chemin: "/dev/cu.usbmodemECRAN0001", vid: 0x043E, pid: 0x9A39, serie: "ECRAN-FACTICE-01",
                            produit: "LG Monitor Controls")
        #expect(c6.estEspressif)
        #expect(!ecran.estEspressif)
        #expect(c6.libelle == "usbmodem11301 · A0:00:00:00:00:01")
        #expect(PortsUSB.trier([ecran, c6]) == [c6, ecran], "Espressif en tete")
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageThreadTests/LiaisonSerieTests`
Expected: la compilation échoue, par exemple avec `error: cannot find 'ErreurPort' in scope` et `error: cannot find 'LiaisonSerie' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageThread/Sonde/PortSerie.swift` :

```swift
import Darwin
import Foundation

/// Ouverture du port serie USB du C6 sans jamais le redemarrer (repris de Halo
/// Compagnon, benq).
///
/// Le peripherique USB Serial/JTAG lit DTR et RTS comme esptool : RTS=1 et
/// DTR=0, meme un instant, REDEMARRE LA PUCE. D'ou :
/// - DTR et RTS poses a 0 ensemble, en un seul `ioctl(TIOCMSET)`, juste apres
///   l'ouverture (passage direct 1,1 -> 0,0), et plus jamais touches ;
/// - `HUPCL` retire : a la fermeture, le pilote ne baisse pas DTR avant RTS.
enum PortSerie {
    // Macros de sys/ttycom.h non importees en Swift (_IO, _IOR, _IOW).
    /// `_IO('t', 13)` : acces exclusif.
    static let tiocexcl: UInt = 0x2000_740D
    /// `_IOR('t', 106, int)` : lire les lignes de controle.
    static let tiocmget: UInt = 0x4004_746A
    /// `_IOW('t', 109, int)` : ecrire les lignes de controle, toutes a la fois.
    static let tiocmset: UInt = 0x8004_746D

    static let debit: speed_t = 115_200

    static func erreur(_ quoi: String) -> ErreurPort {
        ErreurPort(quoi: quoi, errno: errno)
    }

    /// Ouvre `/dev/cu.*` (jamais `/dev/tty.*`, qui attend DCD) ; renvoie le descripteur.
    static func ouvrir(_ chemin: String) throws -> Int32 {
        guard chemin.hasPrefix("/dev/cu.") else {
            throw ErreurPort(quoi: String(localized: "chemin \(chemin) : /dev/cu.* attendu"), errno: 0)
        }
        let fd = open(chemin, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else { throw erreur(String(localized: "ouverture de \(chemin)")) }
        do {
            // 1. Acces exclusif.
            guard ioctl(fd, tiocexcl) != -1 else { throw erreur(String(localized: "accès exclusif (TIOCEXCL)")) }

            // 2. DTR = RTS = 0 dans un seul appel : jamais l'etat RTS=1, DTR=0.
            var lignes: Int32 = 0
            guard withUnsafeMutablePointer(to: &lignes, { ioctl(fd, tiocmget, $0) }) != -1 else {
                throw erreur(String(localized: "lecture de DTR et RTS (TIOCMGET)"))
            }
            lignes &= ~(TIOCM_DTR | TIOCM_RTS)
            guard withUnsafeMutablePointer(to: &lignes, { ioctl(fd, tiocmset, $0) }) != -1 else {
                throw erreur(String(localized: "DTR et RTS à 0 (TIOCMSET)"))
            }

            // 3. Mode brut, 8N1, CLOCAL | CREAD, HUPCL retire, 115200 (ignore par l'USB natif).
            var t = termios()
            guard tcgetattr(fd, &t) != -1 else { throw erreur(String(localized: "lecture des réglages (tcgetattr)")) }
            cfmakeraw(&t)
            t.c_cflag |= tcflag_t(CLOCAL | CREAD | CS8)
            t.c_cflag &= ~tcflag_t(HUPCL | PARENB | CSTOPB | CRTSCTS)
            t.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY)
            guard cfsetspeed(&t, debit) != -1 else { throw erreur(String(localized: "débit (cfsetspeed)")) }
            guard tcsetattr(fd, TCSANOW, &t) != -1 else { throw erreur(String(localized: "réglages (tcsetattr)")) }
            return fd
        } catch {
            // Ouvrir a pose DTR = RTS = 1 : les baisser ensemble et retirer HUPCL
            // avant de fermer, pour que la fermeture ne passe jamais par RTS=1, DTR=0.
            desarmer(fd)
            close(fd)
            throw error
        }
    }

    /// Au mieux, sur un chemin d'erreur : DTR = RTS = 0 en un seul `TIOCMSET`, puis `HUPCL` retire.
    static func desarmer(_ fd: Int32) {
        var lignes: Int32 = 0
        if withUnsafeMutablePointer(to: &lignes, { ioctl(fd, tiocmget, $0) }) == -1 { lignes = 0 }
        lignes &= ~(TIOCM_DTR | TIOCM_RTS)
        _ = withUnsafeMutablePointer(to: &lignes, { ioctl(fd, tiocmset, $0) })
        var t = termios()
        if tcgetattr(fd, &t) != -1 {
            t.c_cflag &= ~tcflag_t(HUPCL)
            _ = tcsetattr(fd, TCSANOW, &t)
        }
    }
}

struct ErreurPort: Error, LocalizedError, CustomStringConvertible {
    var quoi: String
    var errno: Int32

    var description: String {
        guard errno != 0 else { return quoi }
        if errno == EBUSY {
            return String(localized: "\(quoi) : port occupé (pio device monitor ou une autre app le tient)")
        }
        return "\(quoi) : \(String(cString: strerror(errno)))"
    }

    var errorDescription: String? { description }
}
```

`MaillageThread/Sonde/LiaisonSerie.swift` :

```swift
import Darwin
import Foundation
import Synchronization

/// Ce qui arrive sur la liaison : des octets, ou la fermeture et sa raison.
enum EvenementLiaison: Sendable {
    case donnees(Data)
    case ferme(String)
}

/// Port serie POSIX lu par une source Dispatch (repris de Halo Compagnon, benq).
/// Lectures et ecritures passent par une meme file serie : l'ordre des lignes
/// envoyees est garanti, et la file principale ne bloque jamais.
final class LiaisonSerie: Sendable {
    let chemin: String

    private struct Etat {
        var fd: Int32 = -1
        var source: (any DispatchSourceRead)?
        var suite: AsyncStream<EvenementLiaison>.Continuation?
    }

    private let file = DispatchQueue(label: "fr.djoko.maillage.sonde", qos: .userInitiated)
    private let etat = Mutex(Etat())

    init(chemin: String) {
        self.chemin = chemin
    }

    func ouvrir() throws -> AsyncStream<EvenementLiaison> {
        let fd = try PortSerie.ouvrir(chemin)
        let (flux, suite) = AsyncStream.makeStream(of: EvenementLiaison.self, bufferingPolicy: .unbounded)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: file)
        source.setEventHandler { [weak self] in self?.lire() }
        source.setCancelHandler {
            // DTR et RTS sont deja a 0 et HUPCL est retire : fermer ne change rien aux lignes.
            close(fd)
        }
        etat.withLock { e in
            e.fd = fd
            e.source = source
            e.suite = suite
        }
        suite.onTermination = { [weak self] _ in self?.fermer() }
        source.resume()
        return flux
    }

    /// Sur la file serie : tout ce qui est disponible.
    private func lire() {
        let fd = etat.withLock { $0.fd }
        guard fd >= 0 else { return }
        var tampon = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = tampon.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
            if n > 0 {
                let donnees = Data(tampon[0..<n])
                _ = etat.withLock { $0.suite?.yield(.donnees(donnees)) }
                continue
            }
            if n == 0 {
                terminer(String(localized: "port fermé (EOF) : la sonde a peut-être redémarré"))
                return
            }
            let code = errno
            if code == EAGAIN || code == EWOULDBLOCK { return }
            if code == EINTR { continue }
            terminer(String(localized: "lecture impossible : \(String(cString: strerror(code)))"))
            return
        }
    }

    func envoyer(_ donnees: Data) {
        file.async { [weak self] in self?.ecrire(donnees) }
    }

    /// Sur la file serie. Quelques essais si le tampon est plein.
    private func ecrire(_ donnees: Data) {
        let fd = etat.withLock { $0.fd }
        guard fd >= 0 else { return }
        var reste = donnees[...]
        var essais = 0
        while !reste.isEmpty {
            let n = reste.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
            if n > 0 {
                reste = reste.dropFirst(n)
                continue
            }
            let code = errno
            if n < 0, code == EAGAIN || code == EINTR, essais < 50 {
                essais += 1
                usleep(2000)
                continue
            }
            terminer(String(localized: "écriture impossible : \(String(cString: strerror(code)))"))
            return
        }
    }

    private func terminer(_ raison: String) {
        let (source, suite) = etat.withLock { e -> ((any DispatchSourceRead)?, AsyncStream<EvenementLiaison>.Continuation?) in
            let r = (e.source, e.suite)
            e.source = nil
            e.suite = nil
            e.fd = -1
            return r
        }
        source?.cancel()
        suite?.yield(.ferme(raison))
        suite?.finish()
    }

    func fermer() {
        file.async { [weak self] in self?.terminer(String(localized: "port fermé par l'app")) }
    }
}
```

`MaillageThread/Sonde/PortsUSB.swift` :

```swift
import Foundation
import IOKit
import IOKit.serial

/// Un port serie vu par IOKit.
struct PortUSB: Identifiable, Hashable, Sendable {
    var id: String { chemin }
    /// `/dev/cu.*`
    let chemin: String
    let vid: Int?
    let pid: Int?
    /// Numero de serie USB : l'adresse MAC de la puce pour un C6.
    let serie: String?
    let produit: String?

    /// VID Espressif : l'USB Serial/JTAG du C6 est 303A:1001.
    var estEspressif: Bool { vid == 0x303A }

    var libelle: String {
        var s = chemin.replacingOccurrences(of: "/dev/cu.", with: "")
        if let serie, !serie.isEmpty { s += " · \(serie)" }
        return s
    }
}

/// Liste des ports et notifications d'arrivee et de depart (IOKit,
/// `IOServiceAddMatchingNotification` sur `IOSerialBSDClient`) ; repris de
/// Halo Compagnon (benq).
@MainActor
final class PortsUSB {
    /// Appele sur la file principale a chaque arrivee ou depart d'un port.
    var changement: (([PortUSB]) -> Void)?

    // Liberes aussi par deinit (non isole) : sans cela, un rappel IOKit viserait un objet detruit.
    nonisolated(unsafe) private var portNotification: IONotificationPortRef?
    nonisolated(unsafe) private var iterateurs: [io_iterator_t] = []

    deinit {
        for i in iterateurs { IOObjectRelease(i) }
        if let portNotification { IONotificationPortDestroy(portNotification) }
    }

    func demarrer() {
        guard portNotification == nil, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        portNotification = port
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        let contexte = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterateur: io_iterator_t = 0
            let resultat = IOServiceAddMatchingNotification(port, type, Self.critere(), { contexte, iterateur in
                // Rappel C, sur la file principale (IONotificationPortSetDispatchQueue).
                PortsUSB.vider(iterateur)
                guard let contexte else { return }
                MainActor.assumeIsolated {
                    let moi = Unmanaged<PortsUSB>.fromOpaque(contexte).takeUnretainedValue()
                    moi.changement?(PortsUSB.lister())
                }
            }, contexte, &iterateur)
            if resultat == KERN_SUCCESS {
                // Vider l'iterateur arme la notification.
                Self.vider(iterateur)
                iterateurs.append(iterateur)
            }
        }
    }

    func arreter() {
        for i in iterateurs { IOObjectRelease(i) }
        iterateurs.removeAll()
        if let portNotification { IONotificationPortDestroy(portNotification) }
        portNotification = nil
    }

    private nonisolated static func vider(_ iterateur: io_iterator_t) {
        while case let objet = IOIteratorNext(iterateur), objet != 0 {
            IOObjectRelease(objet)
        }
    }

    private nonisolated static func critere() -> CFDictionary {
        let d = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary
        d[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes
        return d as CFDictionary
    }

    /// Ports `/dev/cu.*`, ceux d'Espressif en tete.
    nonisolated static func lister() -> [PortUSB] {
        var iterateur: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, critere(), &iterateur) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterateur) }
        var ports: [PortUSB] = []
        while case let service = IOIteratorNext(iterateur), service != 0 {
            defer { IOObjectRelease(service) }
            guard let chemin = propriete(service, kIOCalloutDeviceKey, parents: false) as? String,
                  chemin.hasPrefix("/dev/cu.") else { continue }
            ports.append(PortUSB(
                chemin: chemin,
                vid: propriete(service, "idVendor") as? Int,
                pid: propriete(service, "idProduct") as? Int,
                serie: propriete(service, "USB Serial Number") as? String,
                produit: propriete(service, "USB Product Name") as? String))
        }
        return trier(ports)
    }

    /// Espressif en tete, puis par chemin.
    nonisolated static func trier(_ ports: [PortUSB]) -> [PortUSB] {
        ports.sorted { a, b in
            if a.estEspressif != b.estEspressif { return a.estEspressif }
            return a.chemin < b.chemin
        }
    }

    private nonisolated static func propriete(_ service: io_object_t, _ cle: String, parents: Bool = true) -> Any? {
        if parents {
            return IORegistryEntrySearchCFProperty(service, kIOServicePlane, cle as CFString, kCFAllocatorDefault,
                                                   IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents))
        }
        return IORegistryEntryCreateCFProperty(service, cle as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
```

Dans `MaillageThread/Droits.entitlements`, remplacer :

```xml
	<key>com.apple.security.files.bookmarks.app-scope</key>
	<true/>
```

par :

```xml
	<key>com.apple.security.files.bookmarks.app-scope</key>
	<true/>
	<key>com.apple.security.device.serial</key>
	<true/>
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageThreadTests/LiaisonSerieTests`
Expected: `Test run with 3 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes au catalogue.**

Run: `outils/synchroniser-textes.sh`, puis :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "%@ : port occupé (pio device monitor ou une autre app le tient)": "%@: port busy (pio device monitor or another app holds it)",
    "DTR et RTS à 0 (TIOCMSET)": "DTR and RTS to 0 (TIOCMSET)",
    "accès exclusif (TIOCEXCL)": "exclusive access (TIOCEXCL)",
    "chemin %@ : /dev/cu.* attendu": "path %@: /dev/cu.* expected",
    "débit (cfsetspeed)": "speed (cfsetspeed)",
    "lecture de DTR et RTS (TIOCMGET)": "reading DTR and RTS (TIOCMGET)",
    "lecture des réglages (tcgetattr)": "reading settings (tcgetattr)",
    "lecture impossible : %@": "cannot read: %@",
    "ouverture de %@": "opening %@",
    "port fermé (EOF) : la sonde a peut-être redémarré": "port closed (EOF): the probe may have restarted",
    "port fermé par l'app": "port closed by the app",
    "réglages (tcsetattr)": "settings (tcsetattr)",
    "écriture impossible : %@": "cannot write: %@",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
```

Run: `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`
Expected: aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `outils/tester.sh`
Expected: `Test run with 121 tests in 19 suites passed` (cœur) et `Test run with 41 tests in 14 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement (`CataloguesTests` compris).

- [ ] **Step 7 : commit.**

```bash
git add MaillageThreadTests/LiaisonSerieTests.swift MaillageThread/Sonde/PortSerie.swift MaillageThread/Sonde/LiaisonSerie.swift MaillageThread/Sonde/PortsUSB.swift MaillageThread/Droits.entitlements outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Ouvrir le port de la sonde sans redemarrer le C6

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 10: App : la sonde, sa tournée et la surveillance

**Files:**
- Create: `MaillageThread/Sonde/SondeUSB.swift`, `MaillageThread/Sonde/SondeMaillage.swift`, `MaillageCoeur/Demo/MaillageDemo.swift`
- Modify: `MaillageThread/Surveillance/Surveillance.swift` (blocs ci-dessous), `MaillageThread/MaillageThreadApp.swift` (blocs ci-dessous)
- Modify (par les outils) : `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings`
- Test: `MaillageThreadTests/SondeTests.swift`, `MaillageCoeurTests/MaillageDemoTests.swift`

**Interfaces:**
- Consumes : `InterlocuteurSonde`, `Tournee`, `MemoireTournee` (tâche 6) ; `MessageSonde`, `CommandeSonde`, `DecoupeurLignes` (tâche 4) ; `LiaisonSerie`, `PortsUSB`, `PortUSB` (tâche 9) ; `MaillageAffiche` (tâche 7) ; `Surveillance` (étape 1).
- Produces :
  - `protocol CanalSonde: Sendable` (`ouvrir() throws -> AsyncStream<Data>`, `envoyer(_ ligne: String)`, `fermer()`) et `CanalSerie(liaison:)` ;
  - `actor SondeUSB: InterlocuteurSonde` : `init(canal:marge:)`, `demarrer(surFermeture:)`, `bonjour()`, `etat()`, `diag(_:_:delaiMs:)` (réponses rangées par `id`), `fermer()`, `bonjourSpontane`, `Erreur` (`.fermee`, `.sansReponse`) ;
  - `@MainActor @Observable final class SondeMaillage` :
    - `Etat` (`.sansSonde`, `.absente`, `.connexion`, `.connectee(Bonjour)`, `.refusee`, `.erreur`) ;
    - les propriétés `etat`, `ports`, `serie`, `etatSonde`, `derniereTournee`, `tourneeEnCours`, `erreurTournee` et `surMaillage` ;
    - `init(preferences:actif:ouvrirCanal:)`, `demarrer()`, `choisir(_:)`, `oublier()`, `rafraichir()`, `portsChanges(_:)`, `connecter(_:choisi:)`, `uneTournee()` ;
    - `cleSerie` (« sondeSerieUSB ») et `periode` (300 s) ;
  - `MaillageDemo.maillage(_:date:) -> Maillage?` dans le cœur ;
  - dans `Surveillance` :
    - `maillage` ;
    - `Fraicheur` : `frais` jusqu'à 6 min, `ancien` jusqu'à 15 min, puis `perime` ;
    - `fraicheur(_:maintenant:)`, `maillageAffiche(pour:)`, `maillageAncien` ;
  - `SondeMaillage` dans l'environnement du menu, du graphe et des réglages.

`SondeMaillage` n'ouvre un port que dans l'app en mode direct (`actif`). En mode démo et sous les tests, elle ne lit ni les ports ni les préférences.

- [ ] **Step 1 : écrire les tests.**

`MaillageThreadTests/SondeTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Synchronization
import Testing
@testable import MaillageThread

/// Canal rejoue : chaque commande envoyee produit les lignes que `repondre` donne.
final class CanalRejoue: CanalSonde {
    private struct Etat {
        var suite: AsyncStream<Data>.Continuation?
        var envoyes: [String] = []
    }

    private let etat = Mutex(Etat())
    let repondre: @Sendable (String) -> [String]

    init(repondre: @escaping @Sendable (String) -> [String]) {
        self.repondre = repondre
    }

    func ouvrir() throws -> AsyncStream<Data> {
        let (flux, suite) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .unbounded)
        etat.withLock { $0.suite = suite }
        return flux
    }

    func envoyer(_ ligne: String) {
        let reponses = repondre(ligne)
        etat.withLock { e in
            e.envoyes.append(ligne)
            for r in reponses { e.suite?.yield(Data(r.utf8)) }
        }
    }

    /// Lignes spontanees de la sonde.
    func emettre(_ lignes: [String]) {
        etat.withLock { e in
            for r in lignes { e.suite?.yield(Data(r.utf8)) }
        }
    }

    func fermer() {
        etat.withLock { $0.suite?.finish() }
    }

    var envoyes: [String] { etat.withLock { $0.envoyes } }

    static let bonjour = #"{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.0","mac":"A00000000001","appairee":true,"code":null,"qr":null}"#
    static let etatDetache = #"{"v":1,"t":"etat","role":"detached","rloc16":"FFFE","mode":"rn","parent":null,"partition":null,"chef":null,"canal":25,"prefixeMaille":null,"xp":null,"suspendue":false}"#

    static func diag(_ id: Int, _ cible: String, tlv: String) -> String {
        #"{"v":1,"t":"diag","id":\#(id),"cible":"\#(cible)","ms":40,"ok":true,"code":"2.04","tlv":"\#(tlv)"}"#
    }
}

@Suite("Sonde USB : commandes et reponses")
struct SondeUSBTests {
    /// bonjour et etat, dans l'ordre.
    @Test func bonjourEtat() async throws {
        let canal = CanalRejoue { l in
            l == "bonjour\n" ? [CanalRejoue.bonjour] : l == "etat\n" ? [CanalRejoue.etatDetache] : []
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        let b = try await s.bonjour()
        #expect(b.estSonde && b.version == "1.0.0")
        let e = try await s.etat()
        #expect(e.role == "detached" && !e.estAttachee)
        #expect(canal.envoyes == ["bonjour\n", "etat\n"])
    }

    /// Deux diag en vol : la seconde reponse arrive avant la premiere, chacune va a son id.
    @Test func diagDansLeDesordre() async throws {
        let canal = CanalRejoue { l in
            // La reponse a la premiere requete ne part qu'avec la seconde.
            l.hasPrefix("diag 0400") ? [CanalRejoue.diag(2, "0400", tlv: "01020400"), CanalRejoue.diag(1, "5000", tlv: "01025000")] : []
        }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        async let a = s.diag(0x5000, [1], delaiMs: 3000)
        try await Task.sleep(for: .milliseconds(50))
        async let b = s.diag(0x0400, [1], delaiMs: 3000)
        let (ra, rb) = try await (a, b)
        #expect(ra.reponse?.rloc16 == 0x5000)
        #expect(rb.reponse?.rloc16 == 0x0400)
        #expect(canal.envoyes == ["diag 5000 1 1 3000\n", "diag 0400 1 2 3000\n"])
    }

    /// Sans reponse de la sonde : `delai` apres le delai donne et la marge.
    @Test func delai() async throws {
        let s = SondeUSB(canal: CanalRejoue { _ in [] }, marge: .milliseconds(50))
        try await s.demarrer {}
        let r = try await s.diag(0x5000, [1], delaiMs: 0)
        #expect(!r.ok && r.erreur == "delai")
        await #expect(throws: SondeUSB.Erreur.sansReponse("bonjour")) { try await s.bonjour() }
    }

    /// Liaison fermee : les attentes sont liberees, les commandes suivantes refusees.
    @Test func fermeture() async throws {
        let canal = CanalRejoue { _ in [] }
        let s = SondeUSB(canal: canal)
        let fermee = Mutex(false)
        try await s.demarrer { fermee.withLock { $0 = true } }
        let requete = Task { try await s.diag(0x5000, [1], delaiMs: 30000) }
        try await Task.sleep(for: .milliseconds(50))
        canal.fermer()
        await #expect(throws: SondeUSB.Erreur.fermee) { _ = try await requete.value }
        await #expect(throws: SondeUSB.Erreur.fermee) { _ = try await s.etat() }
        try await Task.sleep(for: .milliseconds(50))
        #expect(fermee.withLock { $0 })
    }

    /// Un bonjour non demande : la sonde vient de redemarrer.
    @Test func bonjourSpontane() async throws {
        let canal = CanalRejoue { _ in [] }
        let s = SondeUSB(canal: canal)
        try await s.demarrer {}
        canal.emettre([CanalRejoue.bonjour])
        try await Task.sleep(for: .milliseconds(50))
        #expect(await s.bonjourSpontane?.version == "1.0.0")
    }
}

@MainActor
@Suite("Sonde dans l'app : port retenu, refus, fraicheur du maillage")
struct SondeMaillageTests {
    static func preferences() throws -> (UserDefaults, String) {
        let domaine = "fr.djoko.maillage.tests.sonde.\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: domaine)), domaine)
    }

    static let port = PortUSB(chemin: "/dev/cu.usbmodem11301", vid: 0x303A, pid: 0x1001, serie: "A0:00:00:00:00:01",
                              produit: "USB JTAG/serial debug unit")

    /// Un port qui repond en sonde est retenu (numero de serie USB) ; oublier le retire.
    @Test func retenue() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let canal = CanalRejoue { l in l == "bonjour\n" ? [CanalRejoue.bonjour] : l == "etat\n" ? [CanalRejoue.etatDetache] : [] }
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in canal })
        await s.connecter(Self.port, choisi: true)
        guard case .connectee(let b) = s.etat else {
            Issue.record("etat \(s.etat)")
            return
        }
        #expect(b.version == "1.0.0")
        #expect(p.string(forKey: SondeMaillage.cleSerie) == "A0:00:00:00:00:01")
        s.oublier()
        #expect(s.etat == .sansSonde)
        #expect(p.string(forKey: SondeMaillage.cleSerie) == nil)
    }

    /// Un autre C6 (le pont Halo) n'est pas une sonde : refuse, rien de retenu.
    @Test func refusee() async throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let halo = #"{"v":1,"t":"bonjour","produit":"pont-halo","version":"0.4.0","mac":null,"appairee":true,"code":null,"qr":null}"#
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in CanalRejoue { _ in [halo] } })
        await s.connecter(Self.port, choisi: true)
        guard case .refusee(let m) = s.etat else {
            Issue.record("etat \(s.etat)")
            return
        }
        #expect(m.contains("pont-halo"))
        #expect(p.string(forKey: SondeMaillage.cleSerie) == nil)
    }

    /// La sonde retenue debranchee : absente.
    @Test func debranchee() throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        let s = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in CanalRejoue { _ in [] } })
        s.portsChanges([])
        #expect(s.etat == .absente)
    }

    /// En demo et sous tests : rien de lu.
    @Test func inactive() throws {
        let (p, domaine) = try Self.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        p.set("A0:00:00:00:00:01", forKey: SondeMaillage.cleSerie)
        #expect(SondeMaillage(preferences: p, actif: false).serie == nil)
    }

    @Test func fraicheur() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(Surveillance.fraicheur(t, maintenant: t + 300) == .frais)
        #expect(Surveillance.fraicheur(t, maintenant: t + 7 * 60) == .ancien)
        #expect(Surveillance.fraicheur(t, maintenant: t + 16 * 60) == .perime)
    }
}
```

`MaillageCoeurTests/MaillageDemoTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Maillage de demo")
struct MaillageDemoTests {
    /// Sur le releve du 28/09 : les routeurs de bordure de la principale, dont un
    /// muet, deux appareils qui routent, les autres en enfants, un enfant inconnu.
    @Test func surLeReleve() throws {
        let i = Instantane(annonces: Releve20260928.annonces)
        let r = try #require(i.reseaux.first)
        let p = try #require(r.principale)
        let m = try #require(MaillageDemo.maillage(i, date: Releve20260928.annonces.date))
        #expect(m.partition == p.id)
        #expect(m.routeurs.count == p.routeurs.count + 2)
        #expect(m.routeurs.filter(\.muet).count == 1)
        #expect(m.routeurs.filter(\.bordure).count == p.routeurs.count)
        #expect(m.chef?.id == 1)
        #expect(!m.liens.isEmpty)
        let affiche = MaillageAffiche(maillage: m, reseau: r, appareils: i.appareils)
        #expect(affiche.inconnus.map(\.id) == ["rloc:041F"], "tous les routeurs reconnus ; un enfant inconnu")
        #expect(affiche.routeurs.values.filter { $0.bordure }.allSatisfy { $0.reconnu })
        let muet = try #require(m.routeurs.first { $0.muet })
        #expect(m.enfants(de: muet.id).allSatisfy { $0.qualite == nil && $0.source == .balayage })
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageThreadTests/SondeUSBTests MaillageThreadTests/SondeMaillageTests MaillageCoeurTests/MaillageDemoTests`
Expected: la compilation échoue, par exemple avec `error: cannot find 'MaillageDemo' in scope` et `error: cannot find 'SondeMaillage' in scope`.

- [ ] **Step 3 : écrire le code.**

`MaillageThread/Sonde/SondeUSB.swift` :

```swift
import Foundation
import MaillageCoeur

/// Lignes machine de la sonde et envoi des commandes : la liaison serie dans
/// l'app, un canal rejoue dans les tests.
protocol CanalSonde: Sendable {
    /// Lignes machine (JSON, sans RS ni LF) ; le flux finit quand le port se ferme.
    func ouvrir() throws -> AsyncStream<Data>
    func envoyer(_ ligne: String)
    func fermer()
}

/// Canal sur la liaison serie : le flux USB decoupe en lignes machine.
struct CanalSerie: CanalSonde {
    let liaison: LiaisonSerie

    func ouvrir() throws -> AsyncStream<Data> {
        let flux = try liaison.ouvrir()
        let (lignes, suite) = AsyncStream.makeStream(of: Data.self, bufferingPolicy: .unbounded)
        let lecture = Task {
            var decoupeur = DecoupeurLignes()
            for await e in flux {
                guard case .donnees(let d) = e else { break }
                for l in decoupeur.ajouter(d) { suite.yield(l) }
            }
            suite.finish()
        }
        suite.onTermination = { _ in lecture.cancel() }
        return lignes
    }

    func envoyer(_ ligne: String) { liaison.envoyer(Data(ligne.utf8)) }
    func fermer() { liaison.fermer() }
}

/// Sonde branchee en USB : envoie les commandes et apparie les reponses, par
/// ordre pour `bonjour` et `etat`, par id pour `diag` (8 en vol, dans le desordre).
actor SondeUSB: InterlocuteurSonde {
    enum Erreur: Error, LocalizedError, Equatable {
        case fermee
        case sansReponse(String)

        var errorDescription: String? {
            switch self {
            case .fermee: String(localized: "liaison avec la sonde fermée")
            case .sansReponse(let commande): String(localized: "la sonde ne répond pas à « \(commande) »")
            }
        }
    }

    /// Attente de `bonjour` et `etat`.
    static let delaiCommande: Duration = .seconds(3)

    private let canal: any CanalSonde
    /// Au-dela du delai donne a la sonde, elle a du repondre (elle echoue elle-meme en `delai`).
    private let marge: Duration
    private var prochainId = 1
    private var attenteDiag: [Int: (cible: UInt16, suite: CheckedContinuation<ResultatDiag, Never>)] = [:]
    private var attenteEtat: [CheckedContinuation<EtatSonde?, Never>] = []
    private var attenteBonjour: [CheckedContinuation<Bonjour?, Never>] = []
    private var lecture: Task<Void, Never>?
    private(set) var fermee = false
    /// Dernier `bonjour` recu sans l'avoir demande : la sonde vient de (re)demarrer.
    private(set) var bonjourSpontane: Bonjour?

    init(canal: any CanalSonde, marge: Duration = .seconds(5)) {
        self.canal = canal
        self.marge = marge
    }

    /// Ouvre le canal et lit ses lignes ; `surFermeture` quand il se ferme.
    func demarrer(surFermeture: @escaping @Sendable () -> Void) throws {
        let lignes = try canal.ouvrir()
        lecture = Task {
            for await l in lignes { self.recevoir(l) }
            self.clore()
            surFermeture()
        }
    }

    func fermer() {
        canal.fermer()
    }

    func bonjour() async throws -> Bonjour {
        guard !fermee else { throw Erreur.fermee }
        let b = await withCheckedContinuation { c in
            attenteBonjour.append(c)
            canal.envoyer(CommandeSonde.bonjour.ligne)
            Task {
                try? await Task.sleep(for: Self.delaiCommande)
                self.expirerBonjour()
            }
        }
        guard let b else { throw fermee ? Erreur.fermee : Erreur.sansReponse("bonjour") }
        return b
    }

    func etat() async throws -> EtatSonde {
        guard !fermee else { throw Erreur.fermee }
        let e = await withCheckedContinuation { c in
            attenteEtat.append(c)
            canal.envoyer(CommandeSonde.etat.ligne)
            Task {
                try? await Task.sleep(for: Self.delaiCommande)
                self.expirerEtat()
            }
        }
        guard let e else { throw fermee ? Erreur.fermee : Erreur.sansReponse("etat") }
        return e
    }

    func diag(_ cible: UInt16, _ tlv: [UInt8], delaiMs: Int) async throws -> ResultatDiag {
        guard !fermee else { throw Erreur.fermee }
        let id = prochainId
        prochainId += 1
        let r = await withCheckedContinuation { c in
            attenteDiag[id] = (cible, c)
            canal.envoyer(CommandeSonde.diag(cible: cible, tlv: tlv, id: id, delaiMs: delaiMs).ligne)
            Task {
                try? await Task.sleep(for: .milliseconds(delaiMs) + self.marge)
                self.expirerDiag(id)
            }
        }
        if r.erreur == "fermee" { throw Erreur.fermee }
        return r
    }

    private func expirerBonjour() {
        if !attenteBonjour.isEmpty { attenteBonjour.removeFirst().resume(returning: nil) }
    }

    private func expirerEtat() {
        if !attenteEtat.isEmpty { attenteEtat.removeFirst().resume(returning: nil) }
    }

    private func expirerDiag(_ id: Int) {
        guard let a = attenteDiag.removeValue(forKey: id) else { return }
        a.suite.resume(returning: ResultatDiag(id: id, cible: String(format: "%04X", a.cible), ok: false, erreur: "delai"))
    }

    private func recevoir(_ ligne: Data) {
        switch MessageSonde.lire(ligne) {
        case .diag(let r)?:
            attenteDiag.removeValue(forKey: r.id)?.suite.resume(returning: r)
        case .etat(let e)?:
            if !attenteEtat.isEmpty { attenteEtat.removeFirst().resume(returning: e) }
        case .bonjour(let b)?:
            if attenteBonjour.isEmpty {
                bonjourSpontane = b
            } else {
                attenteBonjour.removeFirst().resume(returning: b)
            }
        default:
            break
        }
    }

    /// Liaison fermee : toutes les attentes sont liberees.
    private func clore() {
        fermee = true
        for (id, a) in attenteDiag {
            a.suite.resume(returning: ResultatDiag(id: id, cible: String(format: "%04X", a.cible), ok: false, erreur: "fermee"))
        }
        attenteDiag = [:]
        attenteEtat.forEach { $0.resume(returning: nil) }
        attenteEtat = []
        attenteBonjour.forEach { $0.resume(returning: nil) }
        attenteBonjour = []
    }
}
```

`MaillageThread/Sonde/SondeMaillage.swift` :

```swift
import Foundation
import MaillageCoeur
import Observation

/// La sonde vue par l'app : port retenu (par son numero de serie USB),
/// connexion, tournee toutes les 5 minutes, dernier maillage. L'app n'ouvre
/// jamais un port qu'on ne lui a pas designe (spec de la sonde, section 3).
@MainActor
@Observable
final class SondeMaillage {
    enum Etat: Equatable {
        /// Aucune sonde choisie dans les Reglages.
        case sansSonde
        /// La sonde retenue n'est pas branchee.
        case absente
        case connexion
        case connectee(Bonjour)
        /// Le port choisi n'est pas une sonde, ou ne repond pas.
        case refusee(String)
        case erreur(String)
    }

    /// Numero de serie USB de la sonde retenue (l'adresse MAC du C6).
    static let cleSerie = "sondeSerieUSB"
    static let periode: Duration = .seconds(300)

    private(set) var etat: Etat = .sansSonde
    /// Ports Espressif branches (la sonde, ou un autre C6 comme le pont Halo).
    private(set) var ports: [PortUSB] = []
    private(set) var serie: String?
    private(set) var etatSonde: EtatSonde?
    private(set) var derniereTournee: Date?
    private(set) var tourneeEnCours = false
    /// Derniere erreur d'une tournee (la liaison reste ouverte).
    private(set) var erreurTournee: String?
    /// Appele a chaque nouveau maillage.
    @ObservationIgnored var surMaillage: ((Maillage) -> Void)?

    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let actif: Bool
    @ObservationIgnored private let ouvrirCanal: (String) -> any CanalSonde
    @ObservationIgnored private var sonde: SondeUSB?
    @ObservationIgnored private var memoire = MemoireTournee()
    @ObservationIgnored private var boucle: Task<Void, Never>?
    @ObservationIgnored private var surveillantPorts: PortsUSB?

    /// `actif` faux (mode demo, tests) : ni port, ni preferences lues.
    init(preferences: UserDefaults = .standard, actif: Bool,
         ouvrirCanal: @escaping (String) -> any CanalSonde = { CanalSerie(liaison: LiaisonSerie(chemin: $0)) }) {
        self.preferences = preferences
        self.actif = actif
        self.ouvrirCanal = ouvrirCanal
        serie = actif ? preferences.string(forKey: Self.cleSerie) : nil
    }

    /// Suit les ports ; reprend la sonde retenue des qu'elle est branchee.
    func demarrer() {
        guard actif, surveillantPorts == nil else { return }
        let p = PortsUSB()
        p.changement = { [weak self] l in self?.portsChanges(l) }
        p.demarrer()
        surveillantPorts = p
        portsChanges(PortsUSB.lister())
    }

    /// Choix d'un port dans les Reglages : retenu seulement s'il repond en sonde.
    func choisir(_ port: PortUSB) {
        guard actif else { return }
        Task { await connecter(port, choisi: true) }
    }

    /// Oublie la sonde retenue et ferme la liaison.
    func oublier() {
        preferences.removeObject(forKey: Self.cleSerie)
        serie = nil
        deconnecter(.sansSonde)
    }

    /// Tournee tout de suite (bouton rafraichir).
    func rafraichir() {
        guard sonde != nil else { return }
        lancerBoucle()
    }

    /// Ports branches : la sonde retenue revient, ou s'en va.
    func portsChanges(_ liste: [PortUSB]) {
        ports = liste.filter(\.estEspressif)
        guard let serie else { return }
        if let p = ports.first(where: { $0.serie == serie }) {
            if sonde == nil && etat != .connexion { Task { await connecter(p, choisi: false) } }
        } else if sonde != nil || etat != .absente {
            deconnecter(.absente)
        }
    }

    func connecter(_ port: PortUSB, choisi: Bool) async {
        deconnecter(.connexion)
        let s = SondeUSB(canal: ouvrirCanal(port.chemin))
        do {
            try await s.demarrer { [weak self] in
                Task { @MainActor in self?.liaisonFermee(s) }
            }
            let b = try await s.bonjour()
            guard b.estSonde else {
                await s.fermer()
                etat = .refusee(String(localized: "\(port.libelle) n'est pas une sonde (« \(b.produit) »)"))
                return
            }
            sonde = s
            etat = .connectee(b)
            if choisi, let serieUSB = port.serie {
                preferences.set(serieUSB, forKey: Self.cleSerie)
                serie = serieUSB
            }
            lancerBoucle()
        } catch {
            await s.fermer()
            etat = choisi ? .refusee(error.localizedDescription) : .erreur(error.localizedDescription)
        }
    }

    private func liaisonFermee(_ s: SondeUSB) {
        guard sonde === s else { return }
        deconnecter(.absente)
    }

    private func deconnecter(_ nouveau: Etat) {
        boucle?.cancel()
        boucle = nil
        if let s = sonde { Task { await s.fermer() } }
        sonde = nil
        etat = nouveau
    }

    private func lancerBoucle() {
        boucle?.cancel()
        boucle = Task { [weak self] in
            while !Task.isCancelled {
                await self?.uneTournee()
                try? await Task.sleep(for: Self.periode)
            }
        }
    }

    /// Etat de la sonde, puis une tournee ; le maillage part a la surveillance.
    func uneTournee() async {
        guard let sonde, !tourneeEnCours else { return }
        tourneeEnCours = true
        defer { tourneeEnCours = false }
        do {
            etatSonde = try await sonde.etat()
            if let r = try await Tournee.executer(sonde, memoire: memoire, maintenant: Date()) {
                memoire = r.memoire
                derniereTournee = r.maillage.date
                surMaillage?(r.maillage)
            }
            erreurTournee = nil
        } catch SondeUSB.Erreur.fermee {
            // La liaison est fermee : `liaisonFermee` s'en occupe.
        } catch {
            erreurTournee = error.localizedDescription
        }
    }
}
```

`MaillageCoeur/Demo/MaillageDemo.swift` :

```swift
import Foundation

/// Maillage de la sonde en mode demo : invente, sur les vrais noeuds du releve
/// du 28/09 (partition principale), pour voir les vrais liens sans sonde.
/// Les routeurs de bordure (par leur `xa`), dont le dernier muet ; deux
/// appareils qui routent ; les autres appareils joignables en enfants, repartis
/// entre eux ; un enfant que l'instantane ne connait pas.
public enum MaillageDemo {
    public static func maillage(_ i: Instantane, date: Date) -> Maillage? {
        guard let p = i.reseaux.first?.principale else { return nil }
        var c = ConstructionMaillage(date: date, partition: p.id)
        let bordures = p.routeurs.filter { $0.adresseEtendue != nil }
        let appareils = i.appareils.filter { $0.partition == p.id && $0.etat == .joignable }.sorted { $0.id < $1.id }
        let qui = Array(appareils.prefix(2))
        let enfants = Array(appareils.dropFirst(2))
        // Identifiants de routeur : 1, 5, 9... ; le premier routeur de bordure est le chef.
        let ids = (0..<(bordures.count + qui.count)).map { 1 + 4 * $0 }
        guard let chef = ids.first else { return nil }
        c.routeurs(Route64(sequence: 1, routes: ids.map { RouteRouteur(idRouteur: $0, qualiteSortante: 0, qualiteEntrante: 0, cout: 1) }),
                   chef: chef)
        for (k, r) in bordures.enumerated() {
            c.identite(r.adresseEtendue!, routeur: ids[k])
            c.marquer(ids[k], bordure: true, bbrPrincipal: r.etat?.bbrPrimaire == true)
        }
        for (k, a) in qui.enumerated() { c.identite(a.id, routeur: ids[bordures.count + k]) }
        let muet = bordures.count > 1 ? ids[bordures.count - 1] : nil
        if let muet { c.muet(muet) }
        // Liens : le chef avec chacun ; chaque appareil qui route avec deux routeurs de bordure.
        let qualites = [3, 3, 2, 1]
        for (k, id) in ids.dropFirst().enumerated() where id != muet {
            c.lien(chef, id, sortante: qualites[k % 4], entrante: qualites[(k + 1) % 4])
        }
        for (k, a) in ids.suffix(qui.count).enumerated() where bordures.count > 1 {
            c.lien(a, ids[1 + k % (bordures.count - 1)], sortante: 2, entrante: 1)
        }
        // Enfants, a tour de role ; sous le routeur muet, sans qualite.
        for (k, a) in enfants.enumerated() {
            let parent = ids[k % ids.count]
            c.enfant(EnfantMaillage(rloc16: UInt16(parent) << 10 | UInt16(1 + k / ids.count), extMac: a.id,
                                    qualite: parent == muet ? nil : qualites[k % 4], endormi: a.endormi,
                                    source: parent == muet ? .balayage : .tableEnfants))
        }
        c.enfant(EnfantMaillage(rloc16: UInt16(chef) << 10 | 0x1F, extMac: "E0000000000000FF", qualite: 1, endormi: true,
                                source: .tableEnfants))
        return c.maillage()
    }
}
```

Dans `MaillageThread/Surveillance/Surveillance.swift`, 3 blocs, dans l'ordre :

1. Remplacer :

```swift
    var reseauChoisi: String?
```

   par :

```swift
    var reseauChoisi: String?
    /// Dernier maillage de la sonde ; nil sans sonde.
    var maillage: Maillage?

    /// Age du maillage de la sonde : frais jusqu'a 6 min (une tournee toutes les
    /// 5), ancien jusqu'a 15, perime ensuite (retour aux pointilles).
    enum Fraicheur: Equatable {
        case frais, ancien, perime
    }
```

2. Remplacer :

```swift
            for a in ScenarioPanne.releves { integrer(a) }
```

   par :

```swift
            for a in ScenarioPanne.releves { integrer(a) }
            maillage = instantane.flatMap { MaillageDemo.maillage($0, date: maintenant) }
```

3. Remplacer :

```swift
        return liste
    }
```

   par :

```swift
        return liste
    }

    nonisolated static func fraicheur(_ date: Date, maintenant: Date) -> Fraicheur {
        let age = maintenant.timeIntervalSince(date)
        if age <= 6 * 60 { return .frais }
        return age <= 15 * 60 ? .ancien : .perime
    }

    /// Maillage de la sonde rapproche d'un reseau ; nil sans sonde ou s'il est perime.
    func maillageAffiche(pour r: Reseau) -> MaillageAffiche? {
        guard let m = maillage, let i = instantane, Self.fraicheur(m.date, maintenant: maintenant) != .perime else {
            return nil
        }
        return MaillageAffiche(maillage: m, reseau: r, appareils: i.appareils + Array(suivi.disparus.values))
    }

    /// Le maillage affiche date de plus de 6 min : la sonde ne repond plus.
    var maillageAncien: Bool {
        maillage.map { Self.fraicheur($0.date, maintenant: maintenant) == .ancien } ?? false
    }
```

Dans `MaillageThread/MaillageThreadApp.swift`, 6 blocs, dans l'ordre :

1. Remplacer :

```swift
    @State private var nomsMaison: DossierNoms
```

   par :

```swift
    @State private var nomsMaison: DossierNoms
    @State private var sonde: SondeMaillage
```

2. Remplacer :

```swift
        _nomsMaison = State(initialValue: d)
```

   par :

```swift
        _nomsMaison = State(initialValue: d)
        // Inerte en demo et sous tests : aucun port ouvert.
        let sm = SondeMaillage(actif: !Self.demo && !Surveillance.sousTests)
        _sonde = State(initialValue: sm)
```

3. Remplacer :

```swift
            d.demarrer()
```

   par :

```swift
            d.demarrer()
            sm.surMaillage = { [weak s] m in s?.maillage = m }
            sm.demarrer()
```

4. Remplacer :

```swift
            MenuBarre()
                .environment(surveillance)
                .environment(ouverture)
                .environment(nomsMaison)
```

   par :

```swift
            MenuBarre()
                .environment(surveillance)
                .environment(ouverture)
                .environment(nomsMaison)
                .environment(sonde)
```

5. Remplacer :

```swift
                .environment(surveillance)
                .environment(nomsMaison)
```

   par :

```swift
                .environment(surveillance)
                .environment(nomsMaison)
                .environment(sonde)
```

6. Remplacer :

```swift
            FenetreReglages()
                .environment(surveillance)
                .environment(ouverture)
                .environment(nomsMaison)
```

   par :

```swift
            FenetreReglages()
                .environment(surveillance)
                .environment(ouverture)
                .environment(nomsMaison)
                .environment(sonde)
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageThreadTests/SondeUSBTests MaillageThreadTests/SondeMaillageTests MaillageCoeurTests/MaillageDemoTests`
Expected: `Test run with 1 test in 1 suite passed` et `Test run with 10 tests in 2 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes au catalogue.**

Run: `outils/synchroniser-textes.sh`, puis :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "%@ n'est pas une sonde (« %@ »)": "%1$@ is not a probe (“%2$@”)",
    "la sonde ne répond pas à « %@ »": "the probe does not answer “%@”",
    "liaison avec la sonde fermée": "link with the probe closed",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
```

Run: `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`
Expected: aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `outils/tester.sh`
Expected: `Test run with 122 tests in 20 suites passed` (cœur) et `Test run with 51 tests in 16 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement (`CataloguesTests` compris).

- [ ] **Step 7 : commit.**

```bash
git add MaillageThreadTests/SondeTests.swift MaillageCoeurTests/MaillageDemoTests.swift MaillageThread/Sonde/SondeUSB.swift MaillageThread/Sonde/SondeMaillage.swift MaillageCoeur/Demo/MaillageDemo.swift MaillageThread/Surveillance/Surveillance.swift MaillageThread/MaillageThreadApp.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Brancher la sonde : tournee toutes les 5 minutes, maillage a la surveillance

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 11: App : affichage (graphe, fiche, menu, Réglages › Sonde)

**Files:**
- Modify: `MaillageThread/Vues/Graphe/Palette.swift` (blocs ci-dessous), `MaillageThread/Vues/Graphe/GrapheCanvas.swift` (blocs ci-dessous), `MaillageThread/Vues/Graphe/FenetreGraphe.swift` (blocs ci-dessous), `MaillageThread/Vues/Graphe/FicheNoeud.swift` (blocs ci-dessous), `MaillageThread/Vues/MenuBarre.swift` (blocs ci-dessous), `MaillageThread/Vues/FenetreReglages.swift` (blocs ci-dessous)
- Modify (par les outils) : `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings`
- Test: `MaillageThreadTests/AffichageSondeTests.swift`

**Interfaces:**
- Consumes : `MaillageAffiche`, `NoeudSonde`, `LienAffiche`, `Disposition(reseau:appareils:maillage:)` (tâche 7) ; `Surveillance.maillageAffiche(pour:)`, `maillageAncien` et `SondeMaillage` dans l'environnement (tâche 10).
- Produces :
  - `Palette.NiveauLien`, `lienSonde(_:)` (3 vert, 2 jaune, 1 orange, gris si inconnue), `routeurInconnu` ;
  - `GrapheCanvas.maillage` et `GrapheCanvas.libelleInconnu(_:)`. Les liens sont en traits pleins, 2,2 pt pour un lien radio et 1 pt d'un enfant à son parent, et s'éclairent au survol ;
  - `LegendeLiens(sonde:ancien:)` ;
  - `FicheNoeud.ligneSonde(_:maillage:nom:)` et `texteQualite(_:)` ;
  - `MenuBarre.ligneSonde(_:derniere:maintenant:)` ;
  - Réglages › Sonde et `FenetreReglages.texteEtatSonde(_:)`.

- [ ] **Step 1 : écrire les tests.**

`MaillageThreadTests/AffichageSondeTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Affichage de la sonde : noms, qualites, fiche, menu, reglages")
struct AffichageSondeTests {
    @Test func libelles() {
        #expect(GrapheCanvas.libelleInconnu(NoeudSonde(id: "rloc:B400", rloc16: 0xB400, genre: .routeur, reconnu: false,
                                                       bordure: true)) == String(localized: "Routeur de bordure · B400"))
        #expect(GrapheCanvas.libelleInconnu(NoeudSonde(id: "rloc:5000", rloc16: 0x5000, genre: .routeur, reconnu: false,
                                                       bordure: false)) == String(localized: "Routeur · 5000"))
        #expect(GrapheCanvas.libelleInconnu(NoeudSonde(id: "rloc:AC05", rloc16: 0xAC05, genre: .enfant, reconnu: false,
                                                       bordure: false)) == String(localized: "Non identifié · AC05"))
    }

    @Test func niveaux() {
        #expect(Palette.NiveauLien(3) == .bon)
        #expect(Palette.NiveauLien(2) == .moyen)
        #expect(Palette.NiveauLien(1) == .faible)
        #expect(Palette.NiveauLien(0) == .inconnu)
        #expect(Palette.NiveauLien(nil) == .inconnu)
    }

    /// Mode demo : maillage de demo ; fiche d'un enfant et d'un routeur.
    @Test func ficheEtDemo() throws {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let r = try #require(s.reseau)
        let m = try #require(s.maillageAffiche(pour: r))
        #expect(!s.maillageAncien)
        let enfant = try #require(m.enfants.values.first { $0.reconnu && m.parent(de: $0.id) != nil })
        let ligne = FicheNoeud.ligneSonde(enfant, maillage: m, nom: { "P[\($0)]" })
        #expect(ligne.hasPrefix(String(format: "RLOC16 %04X", enfant.rloc16)))
        #expect(ligne.contains("P["))
        let chef = try #require(m.routeurs[1])
        #expect(FicheNoeud.ligneSonde(chef, maillage: m, nom: { $0 }).contains(String(localized: "voisins : ")) )
        #expect(FicheNoeud.texteQualite(nil) == String(localized: "qualité inconnue"))
        #expect(FicheNoeud.texteQualite(3) == String(localized: "qualité \(3)"))
    }

    @Test func menuEtReglages() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(MenuBarre.ligneSonde(.sansSonde, derniere: nil, maintenant: t) == nil)
        #expect(MenuBarre.ligneSonde(.absente, derniere: nil, maintenant: t) == String(localized: "Sonde : absente"))
        #expect(MenuBarre.ligneSonde(.erreur("x"), derniere: nil, maintenant: t) == String(localized: "Sonde : erreur (voir les Réglages)"))
        #expect(FenetreReglages.texteEtatSonde(.refusee("pas une sonde")) == String(localized: "refusée : \("pas une sonde")"))
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageThreadTests/AffichageSondeTests`
Expected: la compilation échoue, par exemple avec `error: type 'FenetreReglages' has no member 'texteEtatSonde'` et `error: type 'FicheNoeud' has no member 'ligneSonde'`.

- [ ] **Step 3 : écrire le code.**

Dans `MaillageThread/Vues/Graphe/Palette.swift`, remplacer :

```swift
        return z.principale ? Color(red: 0.23, green: 0.51, blue: 0.96) : Color(red: 0.96, green: 0.62, blue: 0.04)
    }
```

par :

```swift
        return z.principale ? Color(red: 0.23, green: 0.51, blue: 0.96) : Color(red: 0.96, green: 0.62, blue: 0.04)
    }

    /// Qualite d'un lien vu par la sonde : 3 bon, 2 moyen, 1 faible ; 0 ou inconnue.
    enum NiveauLien: Equatable {
        case bon, moyen, faible, inconnu

        init(_ qualite: Int?) {
            switch qualite {
            case 3?: self = .bon
            case 2?: self = .moyen
            case 1?: self = .faible
            default: self = .inconnu
            }
        }
    }

    /// Lien de la sonde : vert, jaune, orange ; gris si la qualite est inconnue (parent muet).
    func lienSonde(_ qualite: Int?) -> Color {
        switch NiveauLien(qualite) {
        case .bon: Color(red: 0.29, green: 0.87, blue: 0.5)
        case .moyen: Color(red: 0.98, green: 0.8, blue: 0.2)
        case .faible: .orange
        case .inconnu: sombre ? Color(white: 0.6) : Color(white: 0.5)
        }
    }

    /// Routeur que l'instantane ne connait pas (routeur de bordure muet sans identite).
    var routeurInconnu: Color { Color(white: 0.62) }
```

Dans `MaillageThread/Vues/Graphe/GrapheCanvas.swift`, 8 blocs, dans l'ordre :

1. Remplacer :

```swift
/// Dessin du graphe : zones des partitions, pointilles vers le centre de
/// chaque zone (rattachement, pas un lien radio), routeurs et appareils.
```

   par :

```swift
/// Dessin du graphe : zones des partitions, liens (ceux de la sonde en traits
/// pleins colores par la qualite, sinon des pointilles vers le centre de la
/// zone : rattachement, pas un lien radio), routeurs et appareils.
```

2. Remplacer :

```swift
    let nomsRouteurs: [String: String]
```

   par :

```swift
    let nomsRouteurs: [String: String]
    /// Maillage de la sonde : noms des noeuds qu'elle seule connait.
    var maillage: MaillageAffiche?
```

3. Remplacer :

```swift
        for l in disposition.liens {
```

   par :

```swift
        // Rattachements dessous, puis enfant-parent, puis liens radio.
        let ordre: [Disposition.Lien.Genre] = [.rattachement, .parent, .radio]
        for l in disposition.liens.sorted(by: { ordre.firstIndex(of: $0.genre)! < ordre.firstIndex(of: $1.genre)! }) {
```

4. Remplacer :

```swift
            let eclaire = l.de == selection || l.de == survol
            ctx.stroke(p, with: .color(eclaire ? palette.lienEclaire : palette.lien),
                       style: StrokeStyle(lineWidth: eclaire ? 1.6 : 1, dash: [2, 4]))
```

   par :

```swift
            switch l.genre {
            case .rattachement:
                let eclaire = l.de == selection || l.de == survol
                ctx.stroke(p, with: .color(eclaire ? palette.lienEclaire : palette.lien),
                           style: StrokeStyle(lineWidth: eclaire ? 1.6 : 1, dash: [2, 4]))
            case .radio, .parent:
                let eclaire = [l.de, l.vers].contains { $0 == selection || $0 == survol }
                let epaisseur = l.genre == .radio ? 2.2 : 1.0
                ctx.stroke(p, with: .color(palette.lienSonde(l.qualite).opacity(eclaire ? 1 : 0.75)),
                           style: StrokeStyle(lineWidth: eclaire ? epaisseur + 1.2 : epaisseur, lineCap: .round))
            }
```

5. Remplacer :

```swift
                let couleur = palette.routeur(principale: principales.contains(n.zone))
```

   par :

```swift
                let inconnu = nomsRouteurs[n.id] == nil && maillage?.noeud(n.id) != nil
                let couleur = inconnu ? palette.routeurInconnu : palette.routeur(principale: principales.contains(n.zone))
```

6. Remplacer :

```swift
                libelle = nomsRouteurs[n.id] ?? n.id
```

   par :

```swift
                libelle = nomsRouteurs[n.id] ?? maillage?.noeud(n.id).map(Self.libelleInconnu) ?? n.id
```

7. Remplacer :

```swift
                libelle = a?.nom ?? n.id
```

   par :

```swift
                libelle = a?.nom ?? maillage?.noeud(n.id).map(Self.libelleInconnu) ?? n.id
```

8. Remplacer :

```swift
                }
            }
        }
    }
```

   par :

```swift
                }
            }
        }
    }

    /// Nom d'un noeud que seule la sonde connait : « Routeur de bordure · B400 »,
    /// « Routeur · 5000 », « Non identifié · AC05 ».
    static func libelleInconnu(_ n: NoeudSonde) -> String {
        let rloc = String(format: "%04X", n.rloc16)
        switch n.genre {
        case .routeur:
            return n.bordure ? String(localized: "Routeur de bordure · \(rloc)") : String(localized: "Routeur · \(rloc)")
        case .enfant:
            return String(localized: "Non identifié · \(rloc)")
        }
    }
```

Dans `MaillageThread/Vues/Graphe/FenetreGraphe.swift`, 7 blocs, dans l'ordre :

1. Remplacer :

```swift
                if surveillance.reseau != nil && selection == nil {
                    LegendeLiens()
```

   par :

```swift
                if let r = surveillance.reseau, selection == nil {
                    LegendeLiens(sonde: surveillance.maillageAffiche(pour: r) != nil, ancien: surveillance.maillageAncien)
```

2. Remplacer :

```swift
        let disposition = Disposition(reseau: r, appareils: affiches)
```

   par :

```swift
        let maillage = surveillance.maillageAffiche(pour: r)
        let disposition = Disposition(reseau: r, appareils: affiches, maillage: maillage)
```

3. Remplacer :

```swift
                         projection: projection, selection: selection, survol: survol, palette: palette)
```

   par :

```swift
                         maillage: maillage, projection: projection, selection: selection, survol: survol,
                         palette: palette)
```

4. Remplacer :

```swift
struct BarreOutils: View {
    @Environment(Surveillance.self) private var surveillance
```

   par :

```swift
struct BarreOutils: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(SondeMaillage.self) private var sonde
```

5. Remplacer :

```swift
                    surveillance.rafraichir()
```

   par :

```swift
                    surveillance.rafraichir()
                    sonde.rafraichir()
```

6. Remplacer :

```swift
/// Legende des pointilles du graphe (en bas a gauche, cachee sous une fiche).
struct LegendeLiens: View {
    var body: some View {
        HStack(spacing: 8) {
```

   par :

```swift
/// Legende des liens du graphe (en bas a gauche, cachee sous une fiche) : avec
/// la sonde, traits pleins (lien radio, colore par la qualite) et pointilles
/// (rattachement suppose) ; « ancien » si la sonde ne repond plus.
struct LegendeLiens: View {
    var sonde = false
    var ancien = false

    var body: some View {
        HStack(spacing: 8) {
            if sonde {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 1))
                    p.addLine(to: CGPoint(x: 22, y: 1))
                }
                .stroke(Palette(sombre: true).lienSonde(3), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: 22, height: 2)
                .accessibilityHidden(true)
                Text("lien radio (qualité)")
            }
```

7. Remplacer :

```swift
            Text("rattachement, pas un lien radio")
```

   par :

```swift
            Text(sonde ? "rattachement supposé" : "rattachement, pas un lien radio")
            if ancien {
                Text("· relevé de la sonde ancien").foregroundStyle(.orange)
            }
```

Dans `MaillageThread/Vues/Graphe/FicheNoeud.swift`, 4 blocs, dans l'ordre :

1. Remplacer :

```swift
                colonnesAppareil(a)
```

   par :

```swift
                colonnesAppareil(a)
            } else if let m = sonde, let n = m.noeud(id) {
                colonnesSonde(n, m)
```

2. Remplacer :

```swift
                        Text("· relevé \(Self.relatif(releve, surveillance.maintenant))").foregroundStyle(.secondary)
                    }
                }
            }
```

   par :

```swift
                        Text("· relevé \(Self.relatif(releve, surveillance.maintenant))").foregroundStyle(.secondary)
                    }
                }
            }
            lignesSonde(a.id)
```

3. Remplacer :

```swift
        return morceaux.joined(separator: " · ")
    }
```

   par :

```swift
        return morceaux.joined(separator: " · ")
    }

    // MARK: Sonde

    /// Maillage de la sonde pour le reseau affiche.
    private var sonde: MaillageAffiche? { surveillance.reseau.flatMap { surveillance.maillageAffiche(pour: $0) } }

    /// Ce que la sonde sait du noeud : son parent (enfant), ses voisins et ses enfants (routeur).
    @ViewBuilder
    private func lignesSonde(_ id: String) -> some View {
        if let m = sonde, let n = m.noeud(id) {
            Text(Self.ligneSonde(n, maillage: m, nom: nomNoeud)).foregroundStyle(.secondary)
        }
    }

    /// Noeud que seule la sonde connait (routeur de bordure muet sans identite, enfant inconnu).
    @ViewBuilder
    private func colonnesSonde(_ n: NoeudSonde, _ m: MaillageAffiche) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(GrapheCanvas.libelleInconnu(n)).font(.title3.weight(.semibold))
            Text(Self.ligneSonde(n, maillage: m, nom: nomNoeud)).foregroundStyle(.secondary)
            Text(n.genre == .routeur ? "Vu par la sonde, sans annonce reconnue sur le réseau local."
                                     : "Vu par la sonde : son ExtMac ne correspond à aucun appareil annoncé.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 200, alignment: .leading)
    }

    /// Nom d'un noeud du graphe : routeur de bordure, appareil, ou noeud de la sonde.
    private func nomNoeud(_ id: String) -> String {
        if let r = surveillance.instantane?.routeur(id) { return surveillance.nom(r) }
        if let a = surveillance.appareil(id) { return surveillance.nom(a) }
        if let n = sonde?.noeud(id) { return GrapheCanvas.libelleInconnu(n) }
        return id
    }

    /// « RLOC16 5004 · parent HomePod bureau, qualité 3 » ; « RLOC16 5000 · voisins : 4 · enfants : 2 ».
    static func ligneSonde(_ n: NoeudSonde, maillage m: MaillageAffiche, nom: (String) -> String) -> String {
        let rloc = String(format: "%04X", n.rloc16)
        switch n.genre {
        case .enfant:
            guard let p = m.parent(de: n.id) else { return String(localized: "RLOC16 \(rloc)") }
            let q = m.liens.first { $0.genre == .parent && $0.de == n.id }?.qualite
            return String(localized: "RLOC16 \(rloc) · parent \(nom(p)), \(texteQualite(q))")
        case .routeur:
            let voisins = m.liens.filter { $0.genre == .radio && ($0.de == n.id || $0.vers == n.id) }.count
            let enfants = m.liens.filter { $0.genre == .parent && $0.vers == n.id }.count
            return String(localized: "RLOC16 \(rloc) · voisins : \(voisins) · enfants : \(enfants)")
        }
    }

    /// « qualité 3 » ; « qualité inconnue » sous un routeur muet.
    static func texteQualite(_ q: Int?) -> String {
        q.map { String(localized: "qualité \($0)") } ?? String(localized: "qualité inconnue")
    }
```

4. Remplacer :

```swift
            Text("Routeur de bordure").foregroundStyle(.secondary)
```

   par :

```swift
            Text("Routeur de bordure").foregroundStyle(.secondary)
            lignesSonde(r.instance)
```

Dans `MaillageThread/Vues/MenuBarre.swift`, 2 blocs, dans l'ordre :

1. Remplacer :

```swift
    @Environment(DossierNoms.self) private var nomsMaison
```

   par :

```swift
    @Environment(DossierNoms.self) private var nomsMaison
    @Environment(SondeMaillage.self) private var sonde
```

2. Remplacer :

```swift
            Text("Mode démo : panne du 27/09 rejouée").font(.caption).foregroundStyle(.secondary)
```

   par :

```swift
            Text("Mode démo : panne du 27/09 rejouée").font(.caption).foregroundStyle(.secondary)
        } else if let t = Self.ligneSonde(sonde.etat, derniere: sonde.derniereTournee, maintenant: Date()) {
            Text(t).font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Ligne de la sonde ; rien tant qu'aucune n'est choisie.
    static func ligneSonde(_ e: SondeMaillage.Etat, derniere: Date?, maintenant: Date) -> String? {
        switch e {
        case .sansSonde: return nil
        case .absente: return String(localized: "Sonde : absente")
        case .connexion: return String(localized: "Sonde : connexion…")
        case .connectee:
            guard let d = derniere else { return String(localized: "Sonde : connectée") }
            return String(localized: "Sonde : connectée · relevé \(FicheNoeud.relatif(d, maintenant))")
        case .refusee, .erreur: return String(localized: "Sonde : erreur (voir les Réglages)")
```

Dans `MaillageThread/Vues/FenetreReglages.swift`, 3 blocs, dans l'ordre :

1. Remplacer :

```swift
    @Environment(DossierNoms.self) private var nomsMaison
```

   par :

```swift
    @Environment(DossierNoms.self) private var nomsMaison
    @Environment(SondeMaillage.self) private var sonde
```

2. Remplacer :

```swift
                    .disabled(surveillance.mode == .demo)
            }
```

   par :

```swift
                    .disabled(surveillance.mode == .demo)
            }
            Section("Sonde") {
                if surveillance.mode == .demo {
                    Text("Mode démo : pas de sonde.").foregroundStyle(.secondary)
                } else {
                    Picker("Port", selection: Binding(
                        get: { sonde.ports.first { $0.serie != nil && $0.serie == sonde.serie }?.chemin ?? "" },
                        set: { c in if let p = sonde.ports.first(where: { $0.chemin == c }) { sonde.choisir(p) } })) {
                        Text("—").tag("")
                        ForEach(sonde.ports) { p in Text(verbatim: p.libelle).tag(p.chemin) }
                    }
                    LabeledContent("État", value: Self.texteEtatSonde(sonde.etat))
                    if case .connectee(let b) = sonde.etat {
                        LabeledContent("Firmware", value: b.version)
                        if !b.appairee, let code = b.code {
                            LabeledContent("Code d'appairage", value: code)
                            Text("Dans Maison : + › Ajouter un accessoire › Plus d'options, puis ce code.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let e = sonde.etatSonde {
                        LabeledContent("Partition", value: e.partition ?? "—")
                        if e.suspendue {
                            Text("Sonde suspendue dans Maison (interrupteur « Sonde maillage » éteint) : pas de relevé.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    if let d = sonde.derniereTournee {
                        LabeledContent("Dernier relevé", value: d.formatted(date: .omitted, time: .standard))
                    }
                    if let e = sonde.erreurTournee {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }
                    if sonde.serie != nil {
                        Button("Oublier la sonde") { sonde.oublier() }
                    }
                    Text("Seul le port choisi est ouvert. Le pont Halo est aussi un ESP32-C6 : ne le choisissez pas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
```

3. Remplacer :

```swift
        .onAppear { ouverture.actualiser() }
```

   par :

```swift
        .onAppear { ouverture.actualiser() }
    }

    static func texteEtatSonde(_ e: SondeMaillage.Etat) -> String {
        switch e {
        case .sansSonde: String(localized: "aucune sonde choisie")
        case .absente: String(localized: "absente (débranchée ?)")
        case .connexion: String(localized: "connexion…")
        case .connectee: String(localized: "connectée")
        case .refusee(let m): String(localized: "refusée : \(m)")
        case .erreur(let m): String(localized: "erreur : \(m)")
        }
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageThreadTests/AffichageSondeTests`
Expected: `Test run with 4 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : les textes au catalogue.**

Run: `outils/synchroniser-textes.sh`, puis :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "Code d'appairage": "Pairing code",
    "Dans Maison : + › Ajouter un accessoire › Plus d'options, puis ce code.": "In Home: + › Add Accessory › More options, then this code.",
    "Firmware": "Firmware",
    "Mode démo : pas de sonde.": "Demo mode: no probe.",
    "Non identifié · %@": "Unidentified · %@",
    "Oublier la sonde": "Forget the probe",
    "Partition": "Partition",
    "Port": "Port",
    "RLOC16 %@": "RLOC16 %@",
    "RLOC16 %@ · parent %@, %@": "RLOC16 %@ · parent %@, %@",
    "RLOC16 %@ · voisins : %lld · enfants : %lld": "RLOC16 %@ · neighbors: %lld · children: %lld",
    "Routeur de bordure · %@": "Border router · %@",
    "Routeur · %@": "Router · %@",
    "Seul le port choisi est ouvert. Le pont Halo est aussi un ESP32-C6 : ne le choisissez pas.": "Only the chosen port is opened. The Halo bridge is also an ESP32-C6: don't choose it.",
    "Sonde": "Probe",
    "Sonde : absente": "Probe: absent",
    "Sonde : connectée": "Probe: connected",
    "Sonde : connectée · relevé %@": "Probe: connected · read %@",
    "Sonde : connexion…": "Probe: connecting…",
    "Sonde : erreur (voir les Réglages)": "Probe: error (see Settings)",
    "Sonde suspendue dans Maison (interrupteur « Sonde maillage » éteint) : pas de relevé.": "Probe suspended in Home (“Sonde maillage” switch off): no survey.",
    "Vu par la sonde : son ExtMac ne correspond à aucun appareil annoncé.": "Seen by the probe: its ExtMac matches no announced device.",
    "Vu par la sonde, sans annonce reconnue sur le réseau local.": "Seen by the probe, with no recognized announcement on the local network.",
    "absente (débranchée ?)": "absent (unplugged?)",
    "aucune sonde choisie": "no probe chosen",
    "connectée": "connected",
    "connexion…": "connecting…",
    "erreur : %@": "error: %@",
    "lien radio (qualité)": "radio link (quality)",
    "qualité %lld": "quality %lld",
    "qualité inconnue": "unknown quality",
    "rattachement supposé": "assumed attachment",
    "refusée : %@": "refused: %@",
    "· relevé de la sonde ancien": "· probe survey is old",
    "État": "State",
    "—": "—",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
```

Run: `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`
Expected: aucune erreur.

- [ ] **Step 6 : toute la suite.**

Run: `outils/tester.sh`
Expected: `Test run with 122 tests in 20 suites passed` (cœur) et `Test run with 55 tests in 17 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement (`CataloguesTests` compris).

- [ ] **Step 7 : commit.**

```bash
git add MaillageThreadTests/AffichageSondeTests.swift MaillageThread/Vues/Graphe/Palette.swift MaillageThread/Vues/Graphe/GrapheCanvas.swift MaillageThread/Vues/Graphe/FenetreGraphe.swift MaillageThread/Vues/Graphe/FicheNoeud.swift MaillageThread/Vues/MenuBarre.swift MaillageThread/Vues/FenetreReglages.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Dessiner le vrai maillage : liens, fiche, menu, reglages

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 12: Documentation et vérification avec Djoko (par le contrôleur, pas par un sous-agent)

**Files:**
- Modify: `README.md`, `README.fr.md` (blocs ci-dessous), `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md` (lien vers ce plan ; vérification du jour)

- [ ] **Step 1 : les README et la spec.**

Dans `README.md`, remplacer :

```markdown
parent, router ↔ router, link quality) will come from a dedicated ESP32-C6
probe (step 2, separate project).
```

par :

```markdown
parent, router ↔ router, link quality) come from the probe, an ESP32-C6
plugged into the Mac (see "Probe" below).
```

Dans `README.md`, remplacer :

```markdown
notified. Home names in the demo are made up.
```

par :

```markdown
notified. Home names in the demo are made up, and so is the probe mesh drawn
on the same nodes.
```

Dans `README.md`, après la ligne :

```markdown
| `MaillageCoeur/` | framework without UI: TXT decoding, snapshot (networks, partitions, prefixes, devices), tracking and log events, file log, names, graph layout, routing table; tested on the real survey and on the replayed outage |
```

insérer :

```markdown
| `MaillageCoeur/Maillage/` | probe: diagnostic TLVs, Network Data, USB protocol, mesh model, tour (routers, scan of silent routers), matching with the snapshot; tested on an anonymized capture |
| `MaillageThread/Sonde/` | probe link: serial port without resetting the C6, USB ports, `SondeUSB` (requests matched by id), app model (probe remembered by its USB serial number, a tour every 5 minutes) |
```

Dans `README.md`, après la ligne :

```markdown
| `Passeur/` | Passeur Noms: iOS app run on the Mac (Designed for iPad) that reads Home and writes `noms.json` |
```

insérer :

```markdown
| `sonde/` | probe firmware (ESP32-C6, PlatformIO) and trial tools |
| `outils/anonymiser-sonde.py` | anonymizes a probe capture before it becomes test data |
```

À la fin de `README.md`, ajouter :

````markdown

## Probe (real mesh)

The Mac has no Thread radio. The **probe** is an ESP32-C6 SuperMini plugged
into the Mac by USB and added to Home as a Matter over Thread device (a
"Sonde maillage" plug). It is a minimal end device: it listens all the time but
never relays, so it never changes the mesh it observes. It sends Thread
network diagnostics (`DIAG_GET`) for the app and passes the raw answers back
over USB; the app decodes them and rebuilds the mesh.

```sh
cd sonde && pio run        # build; flashing and pairing: sonde/README.md
```

- In Maillage Thread: Settings › Probe › Port. Only the chosen port is ever
  opened (the Halo bridge is also an ESP32-C6). The probe is remembered by its
  USB serial number; its pairing code shows there until it is in Home.
- A tour every 5 minutes, and on refresh: the routers from the leader, then
  every router that answers (links with the quality in both directions, its
  children), the border routers from the Network Data, and each new child's
  identity (a Matter device's ExtMac is its host name).
- **Apple's border routers never answer diagnostics.** Their children are
  found by scanning their possible RLOC16s, every 30 minutes; the quality of
  those links stays unknown, and a link between two Apple routers is never
  drawn.
- In the graph, solid lines are radio links colored by quality (green 3,
  yellow 2, orange 1, grey unknown); dotted lines stay for what the probe does
  not see. Devices that route move to the inner ring, and children sit near
  their parent. The card gives the parent and the quality, or a router's
  neighbors and children. A mesh older than 6 minutes is marked old; after 15
  minutes the graph goes back to dotted lines.
- Switching "Sonde maillage" off in Home suspends the probe: no tour.
- Probe captures hold the home network's addresses:
  `outils/anonymiser-sonde.py` rewrites them consistently before they become
  test data (`docs/releves/2026-09-29/`).
````

Dans `README.fr.md`, remplacer :

```markdown
vrais liens (enfant → parent, routeur ↔ routeur, qualité) viendront d'une
sonde ESP32-C6 dédiée (étape 2, projet séparé).
```

par :

```markdown
vrais liens (enfant → parent, routeur ↔ routeur, qualité) viennent de la
sonde, un ESP32-C6 branché au Mac (voir « Sonde » plus bas).
```

Dans `README.fr.md`, remplacer :

```markdown
notifié. Les noms de Maison de la démo sont inventés.
```

par :

```markdown
notifié. Les noms de Maison de la démo sont inventés, comme le maillage de la
sonde dessiné sur les mêmes nœuds.
```

Dans `README.fr.md`, après la ligne :

```markdown
| `MaillageCoeur/` | framework sans interface : décodage des TXT, instantané (réseaux, partitions, préfixes, appareils), suivi et événements du journal, journal en fichiers, noms, disposition du graphe, table de routage ; testé sur le relevé réel et sur la panne rejouée |
```

insérer :

```markdown
| `MaillageCoeur/Maillage/` | sonde : TLV du diagnostic, Network Data, protocole USB, modèle du maillage, tournée (routeurs, balayage des routeurs muets), rapprochement avec l'instantané ; testé sur une capture anonymisée |
| `MaillageThread/Sonde/` | liaison avec la sonde : port série sans redémarrer le C6, ports USB, `SondeUSB` (requêtes appariées par id), modèle de l'app (sonde retenue par son numéro de série USB, une tournée toutes les 5 minutes) |
```

Dans `README.fr.md`, après la ligne :

```markdown
| `Passeur/` | Passeur Noms : app iOS lancée sur le Mac (« conçue pour iPad ») qui lit Maison et écrit `noms.json` |
```

insérer :

```markdown
| `sonde/` | firmware de la sonde (ESP32-C6, PlatformIO) et outils d'essai |
| `outils/anonymiser-sonde.py` | anonymise une capture de la sonde avant d'en faire des données de test |
```

À la fin de `README.fr.md`, ajouter :

````markdown

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
  numéro de série USB ; son code d'appairage s'y affiche tant qu'elle n'est pas
  dans Maison.
- Une tournée toutes les 5 minutes, et au rafraîchissement : les routeurs, par
  le chef, puis chaque routeur qui répond (ses liens avec la qualité dans
  chaque sens, ses enfants), les routeurs de bordure par les Network Data, et
  l'identité de chaque nouvel enfant (l'ExtMac d'un appareil Matter est son nom
  d'hôte).
- **Les routeurs de bordure d'Apple ne répondent jamais au diagnostic.** Leurs
  enfants se trouvent en balayant leurs RLOC16 possibles, toutes les 30
  minutes ; la qualité de ces liens reste inconnue, et un lien entre deux
  routeurs Apple n'est jamais dessiné.
- Dans le graphe, les traits pleins sont les liens radio, colorés par la
  qualité (vert 3, jaune 2, orange 1, gris inconnue) ; les pointillés restent
  pour ce que la sonde ne voit pas. Les appareils qui routent passent sur
  l'anneau intérieur, les enfants se rangent près de leur parent. La fiche donne
  le parent et la qualité, ou les voisins et les enfants d'un routeur. Un
  maillage de plus de 6 minutes est marqué ancien ; après 15 minutes, le graphe
  revient aux pointillés.
- Éteindre « Sonde maillage » dans Maison suspend la sonde : pas de tournée.
- Les captures de la sonde contiennent les adresses du réseau de la maison :
  `outils/anonymiser-sonde.py` les réécrit de façon cohérente avant qu'elles ne
  deviennent des données de test (`docs/releves/2026-09-29/`).
````

Dans `docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, après la ligne :

```markdown
> de Maison, spec de l'étape 1, section 5) passe avant.
```

insérer :

```markdown
>
> **Plan 3a :** `docs/superpowers/plans/2026-09-29-maillage-thread-plan3a-sonde.md`.
```

- [ ] **Step 2 : la suite ne change pas.**

Run: `outils/tester.sh`
Expected: `Test run with 122 tests in 20 suites passed` (cœur) et `Test run with 55 tests in 17 suites passed` (app), `** TEST SUCCEEDED **`, sans avertissement.

- [ ] **Step 3 : commit.**

```bash
git add README.md README.fr.md docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md
git commit -m "Documenter la sonde

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4 : vérification sur la carte, avec Djoko.** Chaque action sur une carte ou un port attend l'accord de Djoko.

1. **Carte.** Djoko désigne le port de la sonde, la troisième carte. Le pont Halo, s'il est branché, ne doit jamais être ouvert.
2. **Flash.** Flasher le firmware 1.0.0 **sans effacement**, pour que la sonde reste dans Maison :

   ```bash
   cd sonde && pio run -t upload --upload-port <port désigné>
   ```

   La MAC affichée par le flash doit être celle que Djoko a relevée pour la sonde, jamais celle du pont Halo. Sinon, arrêter.

   Avant de flasher, « Sonde maillage » doit être allumé dans Maison : le firmware garde l'état de l'interrupteur d'un démarrage à l'autre, et son premier démarrage, sans état gardé, part allumé.
3. **Liaison.** Recompiler l'app (`outils/tester.sh`), quitter celle qui tourne et lancer la nouvelle en mode direct, avec Djoko. Au démarrage, elle ne doit ouvrir aucun port. Dans Réglages › Sonde › Port, Djoko choisit la sonde. Attendu :
   - État « connectée », firmware 1.0.0 ;
   - la partition du réseau d'Apple ;
   - pas d'avertissement de suspension.
4. **Première tournée,** qui dure 2 à 3 minutes avec le balayage. Dans le graphe :
   - les liens entre routeurs en traits pleins colorés ;
   - les enfants reliés à leur parent, en gris sous les routeurs d'Apple ;
   - les nœuds inconnus nommés « Routeur de bordure · … » ou « Non identifié · … » ;
   - les pointillés gardés pour ce que la sonde ne voit pas (l'Aqara, s'il a sa partition).

   Survoler un routeur éclaire ses liens. La fiche d'un appareil donne son parent et la qualité. La ligne du menu dit « Sonde : connectée ».
5. **Marche normale,** pendant au moins trois tournées (un quart d'heure), balayage compris : la légende du graphe ne dit jamais « relevé de la sonde ancien ».
6. **Suspension.** Djoko éteint « Sonde maillage » dans Maison. Les Réglages montrent l'avertissement de suspension et la tournée s'arrête. Il la laisse éteinte, débranche la sonde et la rebranche : `etat` dit toujours `suspendue` (avertissement dans les Réglages) et Maison montre « éteint ». Il la rallume.
7. **Débranchement.** Djoko débranche la sonde : le menu dit « Sonde : absente ». Il la rebranche : l'app la reprend seule, par son numéro de série, sans rien toucher dans les Réglages. Puis « Oublier la sonde » et la choisir de nouveau dans Réglages › Sonde › Port : elle se reconnecte. Ni ici ni au rebranchement, aucune erreur « port occupé » causée par l'app.
8. **Retour.** Noter le nombre de routeurs, de liens et d'enfants, et les nœuds non identifiés.

- [ ] **Step 5 : spec, section 8.** À la fin de la section 8, ajouter le paragraphe suivant, en remplaçant `<…>` par les valeurs du Step 4. Ce sont des comptes et des RLOC16, jamais une ExtMac ni une adresse.

```markdown
**Vérifié le <date> avec Djoko** (firmware 1.0.0, plan 3a) : sonde choisie
dans Réglages › Sonde et reprise seule après débranchement ; <n> routeurs
(dont <m> muets), <l> liens radio, <e> enfants, dont <b> par balayage, et
<i> nœuds non identifiés ; suspension par « Sonde maillage » vérifiée, et
gardée après un redémarrage ; ni « ancien » en marche normale, ni « port
occupé » causé par l'app.
```

Commit : `git add docs/superpowers/specs/2026-09-28-maillage-thread-sonde-design.md`, message « Noter la verification de la sonde avec Djoko », terminé par la ligne `Co-Authored-By`.

---

## Couverture de la spec

| Spec | Tâches |
|---|---|
| 1. Firmware `sonde/` : pioarduino, MED, nœud Matter, client CoAP de diagnostic | 8 (sur la base de l'essai, branche `essai-sonde`) |
| 1. `MaillageCoeur/Maillage/` : TLV, tournée, maillage, rapprochement | 2 à 7 |
| 1. `MaillageThread/Sonde/` : liaison série, choix du port, numéro de série, boucle de tournée, `Surveillance` | 9, 10 |
| 1. Sans sonde, l'app marche comme à l'étape 1 | 7 (disposition inchangée sans maillage), 10 |
| 2. Appairage par Bluetooth, code d'appairage par `bonjour` | 8 (firmware de l'essai), 11 (Réglages) |
| 2. Interrupteur « Sonde maillage », réponse `suspendue` | 8, 6 (pas de tournée), 11 (avertissement) |
| 2. 8 requêtes en vol, délai par requête (45 s par défaut), lignes de 4 Ko | 8, 4, 10 |
| 3. Trame RS + JSON ; DTR et RTS d'un seul coup | 4, 9 |
| 3. Commandes et messages (`bonjour`, `etat`, `voisins`, `diag`) | 4, 8, 10 (écarts 4 et 5) |
| 3. Aucun port non désigné ; numéro de série retenu ; vérification par `bonjour` | 10, 11 |
| 4. Tournée courte : `etat` ; Route64 et Leader Data du chef (après les autres s'il est muet), des routeurs qui ont répondu à la dernière tournée, sinon des identifiants 0 à 62 par groupes de 8 ; sans Route64, pas de nouveau maillage ; Network Data ; routeurs ; pile une fois | 6 |
| 4. Tournée toutes les 5 min et au bouton ; un autre chef ou une autre partition vu à la tournée suivante ; autre partition : mémoire remise à zéro | 10, 11 (bouton) ; 6 (mémoire remise à zéro, écart 3) |
| 4. Routeur muet : 2 tournées de suite, puis une fois par heure ; « muet » dans le maillage rendu dès le premier échec | 5, 6 |
| 4. Balayage des routeurs à balayer (sans réponse à la tournée, et muets ou n'ayant jamais répondu) : de 1 à 32, 8 après le dernier, 8 en vol, 8 s ; toutes les 30 min ou quand l'ensemble des routeurs à balayer change ; enfants gardés entre deux balayages | 6 |
| 4. Identité des enfants des tables (ExtMac, adresses) : au plus une fois par demi-heure, endormis compris | 6 |
| 4. Rapprochement : ExtMac = nom d'hôte ; `xa` par le parent de la sonde et par le BBR principal ; adresse commune ; sinon « non identifié » | 6 (identités), 7 |
| 4. Sonde muette ou tournée sans Route64 : dernier maillage affiché 15 min, « ancien » au bout de 6 min (comptées depuis sa réception ; jamais pendant une tournée), puis les pointillés | 10, 11 |
| 5. Graphe : anneaux ; traits pleins selon la qualité ; trait fin gris sous un routeur muet ; pas de lien entre deux muets ; pointillés sinon ; légende ; survol | 7, 11 |
| 5. Fiche, noms, menu, Réglages › Sonde | 11 (écarts 1 et 2) |
| 6. Journal des parents, historique des qualités | plan 3b |
| 7. Données de test anonymisées ; autorisation `device.serial` ; firmware vérifié par compilation puis sur la carte | 1, 9, 8, 12 |
| 9. Vue spatiale 3D | plus tard |

## Écarts d'exécution (29/09)

Des relectures ont corrigé plusieurs comportements pendant l'exécution, par rapport au texte de ce plan. **Les blocs de code des tâches 2 à 11, et les textes des README des tâches 8 (la sonde) et 12, sont donc dépassés par les commits ci-dessous : le dépôt fait foi.** (Les corrections des tâches 3 et 10 touchent aussi des fichiers des tâches 5 et 9 ; celles de la revue finale, des fichiers des tâches 2, 5, 8, 9, 10 et 12.) Les effectifs de tests attendus ont aussi changé : à la fin de la revue finale, le cœur comptait 142 tests en 20 suites et l'app 69 en 17 suites, au lieu de 122 et 55 ; après les demandes de Djoko pendant la vérification sur la carte, dont la sonde 1.0.2 (dernière entrée), le cœur compte 180 tests en 21 suites et l'app 197 en 24 suites.

- **Tâche 3, BBR principal** (`f875378`, qui touche aussi `Maillage.swift` et `MaillageTests.swift`, de la tâche 5).
  - Défaut : `bbr` gardait l'ordre des Network Data alors que `ConstructionMaillage.reseau(_:)` en prenait le premier comme BBR principal, ce qui est faux dès qu'il y a deux entrées BBR.
  - Fait : la règle d'OpenThread (l'entrée du chef d'abord, puis le numéro de séquence le plus haut, puis le RLOC16 le plus haut ; serveurs aux données de moins de 7 octets ignorés), avec le tri dans `DonneesReseau` et le chef pris en compte par `ConstructionMaillage.reseau(_:)` ; 8 tests.
- **Tâche 4, ligne machine au dernier RS** (`10f6148`).
  - Défaut : `DecoupeurLignes` ne reconnaissait une ligne machine que si le RS était le premier octet de la ligne : du texte sans fin de ligne avant le RS, ou une ligne coupée suivie d'une complète, faisait perdre la réponse (fausse erreur « délai », faux routeur muet).
  - Fait : la ligne machine commence au dernier RS de la ligne, comme dans le récepteur du pont Halo (un RS recommence le tampon) ; 3 tests.
- **Tâche 6, tournée** (`25e4769`), trois corrections :
  - Route64 sans chef. Défaut : avec le chef muet et une mémoire neuve (lancement de l'app), la Route64 n'était jamais obtenue et la tournée n'aboutissait plus, une liste de répondants vide écrasant les secours. Fait : la Route64 vient du chef, puis des répondants de la dernière tournée, puis d'une recherche sur les identifiants 0 à 62 par groupes de 8 ; sans Route64, la tournée ne rend rien et le dernier maillage vieillit.
  - Balayage des muets confirmés. Défaut : un routeur était traité en muet et balayé dès un seul échec, alors que la spec dit deux tournées de suite, d'où des balayages complets sous des routeurs qui répondent. Fait : balayage seulement sous les routeurs sans réponse qui sont muets (deux échecs de suite) ou n'ont jamais répondu (`dejaRepondu`).
  - Identités des enfants, une fois par demi-heure. Défaut : l'identité des enfants des tables était redemandée à chaque tournée quand ils ne répondaient pas, et vidée à chaque balayage. Fait : elle est demandée au plus une fois par demi-heure et par enfant, qu'il ait répondu ou non, et gardée jusqu'à une nouvelle réponse ; écart assumé à la spec (« sans les réveiller »), car la Child Table ne donne pas l'ExtMac.
  - 5 tests ajoutés, 2 adaptés.
- **Tâche 7, tests du rangement des enfants** (`bba957d`).
  - Défaut : aucune assertion ne distinguait le tri des enfants par parent (le test passait sans le tri), et le repli d'angle, le parent inconnu et les enfants du centre n'étaient pas couverts.
  - Fait : des tests seulement (`RapprochementTests.swift`), une assertion discriminante et un mini-maillage construit à la main, avec le rouge prouvé en neutralisant le tri ; 4 tests ajoutés, code inchangé.
- **Tâche 9, données de test inventées** (`603b55c`).
  - Défaut : `LiaisonSerieTests.swift` portait ce qui semble être le numéro de série d'un écran branché au Mac et un chemin de port plausible.
  - Fait : valeurs inventées (`ECRAN-FACTICE-01`, `/dev/cu.usbmodemECRAN0001`, `/dev/tty.maillage-inexistant`), dans le commit de la tâche avant son intégration et dans le bloc de test de la tâche 9 ci-dessus.
- **Tâche 10, connexion sérialisée et fermeture attendue** (`6492daf`, qui touche aussi `LiaisonSerie.swift`, de la tâche 9).
  - Défaut : `SondeMaillage.connecter` n'était pas sérialisé : deux changements de ports rapprochés ouvraient deux connexions, une connexion en cours échappait à `deconnecter` (« Oublier » ou un autre choix pouvait être annulé, le port rester ouvert, l'état contredire la liaison), et l'ancienne liaison se fermait sans être attendue, d'où un « port occupé » trompeur en rouvrant le même port.
  - Fait : un numéro d'essai qu'incrémente `deconnecter` (une connexion périmée ferme sa liaison et sort sans toucher à l'état), `.connexion` posé avant de lancer la tâche, un choix du port déjà connecté sans effet, et `connecter` qui attend la fermeture réelle de l'ancienne liaison (`LiaisonSerie` finit son flux après `close(fd)`, `SondeUSB.fermer()` attend la fin de sa lecture) ; 6 tests.
- **Tâche 11, épaisseur des liens, tests indépendants de la langue, « Renommer… »** (`da283d5`), trois corrections :
  - Épaisseur. Défaut : l'épaisseur des liens radio ne dépendait pas de la qualité (spec, section 5). Fait : 3 pt pour la qualité 3, 2,2 pt pour 2, 1,4 pt pour 1 ou inconnue, et 1 pt de l'enfant à son parent, par une fonction pure testée (`GrapheCanvas.epaisseurLienSonde`).
  - Langue. Défaut : `AffichageSondeTests` ne passait que sur un hôte en français. Fait : les attentes reprennent les mêmes clés interpolées que le code.
  - « Renommer… ». Défaut : le bouton était inerte pour un nœud que seule la sonde connaît (surnom orphelin, indexé par un RLOC16 volatil). Fait : il est masqué pour un tel nœud (`FicheNoeud.renommable`).
  - 2 tests ajoutés.
- **Tâche 12, documentation** (`d8f067c`, puis le commit « Documenter la sonde telle qu'executee et noter les ecarts du plan 3a »).
  - Défaut : la première passe laissait « l'app ne sonde jamais », faux depuis la sonde, et décrivait la tournée du plan plutôt que celle du code : identité de chaque nouvel enfant, liste des routeurs donnée par le chef seul, balayage sans la règle des routeurs qui n'ont jamais répondu ou sont muets deux tournées de suite.
  - Fait : les README (les deux langues) et cette section disent ce que fait le code ; la spec aussi, dans son en-tête, sa section 3 (la trame) et sa section 4 (la tournée), sauf pour la connexion à la sonde, un détail d'implémentation qu'elle ne décrit pas (l'épaisseur des liens y était déjà, en section 5 : c'est le code qui l'a rejointe) ; le bloc de test de la tâche 9 reprend les valeurs inventées.
- **Revue finale, vague de corrections** (`4d68062`, `568a074`, `7c2aa2c`, `cc2c1aa`, puis le commit « Documenter la vague de corrections de la revue finale »), cinq corrections :
  - Fraîcheur du maillage (`4d68062`, tâche 10). Défaut : le maillage était daté du début de sa tournée et la pause de 5 minutes courait depuis la fin : il passait « ancien » (plus de 6 minutes) dès que deux tournées de suite duraient plus de 60 s en tout, dès la première tournée au lancement et autour de chaque balayage, alors que la spec (section 4) réserve « ancien » à une sonde muette. Fait : l'âge du maillage se compte depuis sa réception, à la fin de sa tournée (`SondeMaillage.surMaillage` donne l'heure de réception, `Surveillance.recevoir(_:a:)` la garde) ; pendant une tournée (`SondeMaillage.surTournee`, `Surveillance.tourneeEnCours`), il n'est pas « ancien » ; le passage à « périmé » (15 minutes, retour aux pointillés) ne change pas ; API du cœur inchangée ; 3 tests ajoutés, 1 complété.
  - Interrupteur « Sonde maillage » (`7c2aa2c`, tâche 8). Défaut : après un redémarrage, la sonde repartait allumée (`sSuspendue` à faux, `begin(true)`), quel que soit l'état montré par Maison, alors que la spec (section 2) garantit qu'éteinte, elle refuse les requêtes. Fait : le schéma de l'exemple `MatterOnOffPlugin` d'Arduino-ESP32 3.3.12 : l'état est gardé dans `Preferences` (allumé par défaut), relu avant `begin(état)`, appliqué par `updateAccessory()` après `Matter.begin()`, et sauvé par le rappel (`onChange`, que `updateAccessory()` appelle) ; vérifié par la compilation ; `sonde/README.md` le dit.
  - Aucun port non désigné (`568a074`, tâche 10). Défaut : aucun test ne tenait l'invariant de la spec (section 3). Fait : 2 tests (sans sonde retenue, un C6 branché n'est pas ouvert ; avec une sonde retenue, un autre C6 ne l'est pas), dont le rouge est prouvé par une mutation de `portsChanges`.
  - `errno` et commentaires (`cc2c1aa`, tâches 2, 5 et 9). Défaut : `PortSerie.erreur` lisait `errno` après avoir construit le message (`String(localized:)`, qui peut le changer), d'où un message ou un « port occupé » faussé ; le délai d'un enfant était décrit comme un délai de supervision. Fait : `errno` lu d'abord (message en `@autoclosure`), 1 test ; commentaires : c'est le Child Timeout, le délai d'expiration de l'enfant.
  - Documentation (le dernier commit). La spec (en-tête, section 4 : le drapeau `muet` du maillage rendu, qu'aucune vue ne lit encore, et la fraîcheur comptée depuis la réception), les README (les deux langues) et ce plan (en-tête, tâche 12 : vérifications sur la carte, couverture de la spec, cette section).
- **Sonde 1.0.2** (demande de Djoko pendant la vérification sur la carte, 29/09 ; un contrat commun, trois chantiers relus, puis intégrés : fusions `982421a` et `2cf48ff`, corrections d'intégration de `fda62ba` à `6f15e84`, puis le commit « Documenter l'acces reseau de la sonde 1.0.2 et les limites connues » ; après la relecture de l'intégration, `c026219` à `457e72a`, puis `61ef9f3` à `c3849aa`).
  - Demande : garder la sonde en FED (l'essai l'a montré : elle entend alors les routeurs voisins), afficher honnêtement les routeurs de bordure qu'elle ne peut pas identifier, et la joindre par le réseau Thread comme le pont Halo, pour la débrancher du Mac et la promener dans la maison.
  - Firmware 1.0.2 (`sonde/`, fusionné à part) : FED, `routeurs`, nom d'hôte dans `bonjour`, clé créée par l'USB, accès UDP au port 5480 avec l'enveloppe H1 de Halo.
  - Identités des routeurs : table des routeurs lue à chaque tournée, paires gardées d'un lancement à l'autre (`identites-routeurs.json`), règles du BBR principal et du chef (une seule annonce de ce rôle), élimination, candidats affichés et cliquables (spec, section 4).
  - Accès réseau : `MaillageThread/Sonde/Reseau/`, repris de Halo Compagnon (transport UDP, enveloppe H1, trousseau) ; canal réseau (rid, renvois, doublons, veille) ; clé par « Autoriser l'accès réseau » ; choix de la liaison ; reprise ; activité tenue pendant la session (spec, section 3 bis).
  - Corrections d'intégration, une par commit : échéances de `SondeUSB` liées à leur requête (deux `etat` lents de suite par le réseau n'échouent plus) ; `routeurs` sur plusieurs lignes, testé de bout en bout par le réseau ; une note à la place du code Matter, qui ne passe pas par le réseau ; dernière perte de la session réseau gardée dans Réglages › Sonde ; marges élargies de deux tests du canal ; veille après 10 s de silence au lieu de 30 (la carte donne la place d'une session muette depuis 30 s) ; un `diag` sans réponse redemandé après son vol, jusqu'à son échéance ; un routeur `trop_long` n'est plus compté muet (sa requête est refaite en deux moitiés de TLV). Après la relecture : le premier renvoi d'un `diag` après son vol est calé sur son délai (ceux d'après le vol ne tombent plus pendant le vol ; les renvois fixes de 2 et 4 s, si) ; un routeur qui répond sans son ExtMac garde son identité connue ; deux tests rendus sûrs (moitiés d'un `trop_long` comparées sans ordre, annulation du renvoi suivant prouvée) ; limites complétées dans les README et la spec. Après le second face-à-face (app contre simulation du firmware) : au plus 18 nouvelles commandes par seconde glissante, sous la cadence de la carte (20) ; l'identité connue d'un routeur qui répond sans ExtMac lue après toutes les réponses ; renvois pendant le vol et table `routeurs` perdue décrits plus justement, jusque dans `sonde/` (documentation seulement).
  - Effectifs : 180 tests en 21 suites pour le cœur, 197 en 24 suites pour l'app, verts en français et en anglais.
