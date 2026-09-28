# Maillage Thread, étape 1 (vue depuis le Mac) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** une app macOS de la barre des menus qui montre le réseau Thread vu depuis le Mac (routeurs de bordure, partitions, chef, préfixes OMR, appareils et leur partition), tient un journal des changements et notifie les alertes.

**Architecture:** un framework `MaillageCoeur` sans interface (décodage des annonces, instantané, suivi et événements, journal en fichiers, noms, disposition du graphe, table de routage) entièrement testé sur le relevé réel du 28/09 et sur la panne du 27/09 rejouée ; une app `Maillage Thread` (bac à sable) : recenseur Bonjour + dns_sd, modèle `Surveillance`, notifications, barre des menus, fenêtre du graphe en Canvas avec surcouches Liquid Glass, fenêtre du journal, réglages.

**Tech Stack:** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI (macOS 26 : `glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `MenuBarExtra`), Observation, Network (`NWBrowser`), dns_sd, ServiceManagement (`SMAppService`), UserNotifications, Swift Testing, XcodeGen ; Python 3 pour l'outil de traduction.

**Spec:** `docs/superpowers/specs/2026-09-28-maillage-thread-design.md` (à lire avec ce plan) ; relevé réel : `docs/releves/2026-09-28/` ; maquettes : `docs/superpowers/specs/maquettes/`.

**Code validé avant exécution.** Tout le code de ce plan a été écrit, compilé et testé le 28/09 : simulation tâche par tâche dans un dépôt vierge (chaque tâche compile sans avertissement et passe ses tests dans l'ordre du plan), puis l'app lancée en mode démo et vérifiée sur capture d'écran. Exécuter une tâche, c'est donc transcrire les fichiers donnés, compiler et tester. Si un fichier doit s'écarter du texte donné (SDK différent, erreur), l'exécutant le dit dans son rapport, avec la raison.

**Hors de ce plan (plan 2, à écrire ensuite) :** le passeur Mac Catalyst des noms de Maison (spec, section 5 : cible `Passeur Noms`, HomeKit, groupe partagé, `noms.json`, « Rafraîchir les noms de Maison »). Le modèle des noms (`NomsMaison`, `ResolveurNoms`) est déjà dans ce plan et sert au mode démo ; sans passeur, les noms sont : surnom > nom HomeKit > hôte.

**Écarts à la spec (assumés) :**
1. **Passeur Catalyst dans un plan à part** (voir ci-dessus) : c'est le morceau le plus incertain (capacité HomeKit de l'équipe, groupe partagé Catalyst) ; l'app de ce plan marche sans lui.
2. **Endormi** : `ICD` annoncé, ou `SII` d'au moins 5000 ms (la spec disait d'abord « SII/ICD ⇒ endormi » ; corrigée le 28/09). La capture réelle montre `SII` sur presque tous les appareils Thread, dont le pont Halo, alimenté (`SII=2000`).
3. **Regroupement des pertes à l'affichage** : le journal garde chaque événement (la fiche d'un appareil montre le sien) ; la fenêtre du journal et la barre des menus regroupent les pertes d'une même fenêtre de 10 min en une ligne ; la notification groupée est remplacée sur place (même identifiant) à chaque nouvelle perte.
4. **Sursis de 2 min pour tout ce qui manque** : services (routeurs et appareils) et adresses d'un hôte ; l'événement est daté de la première absence.
5. **Relevé des tests** : la capture réelle du 28/09 à 02:15 (`docs/releves/2026-09-28/capture-0215.json`), faite par le code du recenseur de ce plan, et non le relevé de 00:42 : même réseau scindé, mais 2 hôtes sans adresse (`1E5019DAC2638F92` et `724CC16B32D8F820`). Ajoutée à la section 8 de la spec le 28/09.
6. **Fenêtre du graphe au lancement** : en mode démo et au tout premier lancement seulement ; jamais à l'ouverture de session ensuite.
7. **Ouverture à la connexion** inscrite une fois, au premier lancement (choix de la spec, section 1) ; décochable dans le menu et les réglages.

## Global Constraints

- macOS **26.0** minimum (`MACOSX_DEPLOYMENT_TARGET: "26.0"`) ; Xcode 26 ou plus (développé avec Xcode 27, SDK MacOSX27.0) ; XcodeGen 2.45 ou plus.
- Swift 6 (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` : tout avertissement casse la compilation.
- Identifiants : app `fr.djoko.maillage` (produit « Maillage Thread », module `MaillageThread`), framework `fr.djoko.maillage.coeur`, tests `fr.djoko.maillage.coeur.tests` et `fr.djoko.maillage.tests`.
- Délais : premier relevé 10 s après le démarrage ; relevé 2 s après un changement ; au moins toutes les 60 s ; sursis d'une absence 120 s ; regroupement des pertes 600 s depuis la première ; notification groupée à partir de 3 pertes ; datation « pendant la veille » jusqu'à 240 s après le réveil ; journal : un fichier par mois, supprimé 90 jours après la fin de son mois.
- Endormi : `ICD` présent, ou `SII` ≥ 5000 ms.
- Code : identifiants et commentaires en français **sans accents** ; textes affichés avec accents. Tests en Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`).
- Textes : catalogue `MaillageThread/Ressources/Localizable.xcstrings` (français = source, anglais obligatoire), `MaillageThread/Ressources/InfoPlist.xcstrings` ; synchronisation et traduction à la tâche 18 seulement (les tâches 12 à 17 ajoutent des textes sans toucher au catalogue).
- Commandes, depuis la racine du dépôt : `outils/tester.sh` (génère le projet, compile, lance tous les tests ; `outils/tester.sh MaillageCoeurTests/SuiviTests` pour une suite). Produits de compilation hors du dépôt : `$HOME/Library/Developer/Xcode/DerivedData/maillage` (variable `DD`). Après ajout ou retrait d'un fichier, `outils/tester.sh` régénère le projet.
- Signature : ad hoc par défaut (`Signature.xcconfig`) ; `Local.xcconfig` (équipe) jamais commité ; aucun identifiant d'équipe, empreinte de certificat ni adresse électronique dans un fichier commité.
- Commits : un par tâche, message en français sans accents, terminé par la ligne `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` ; **seulement si Djoko a autorisé les commits pour cette exécution**. Jamais de push, jamais de dépôt GitHub créé sans sa demande.
- Interdits pour les agents : `sudo` ; changer une route ou un réglage réseau ; lancer l'app en mode direct (hors `-demo`) : invite « réseau local », demande de notifications et inscription à l'ouverture de session sur le Mac de Djoko. La tâche 19 le fait avec Djoko présent.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `project.yml`, `Signature.xcconfig` | projet XcodeGen (framework, app, deux cibles de tests), signature ad hoc | 1 |
| `outils/tester.sh`, `outils/synchroniser-textes.sh`, `outils/traduire.py` | tests ; catalogue des textes | 1 |
| `MaillageCoeur/Adresses/` | `AdresseIPv6`, `PrefixeIPv6` (/64, `omr`, préfixe tiré de `xp`) | 1 |
| `MaillageCoeur/Annonces/` | `ChampsTXT`, `AnnonceService`, `RouteIPv6`, `Annonces` (format des captures), `CodageJSON` | 2 |
| `MaillageCoeur/Decodage/` | `RouteurBordure` (`_meshcop._udp`), `InstanceMatter`, `ProprietesMatter`, `AccessoireHAP` | 3 |
| `MaillageCoeur/Demo/` | relevé réel du 28/09, noms de démo, scénario de la panne du 27/09 | 4, 6, 8 |
| `MaillageCoeur/Instantane/` | `Instantane`, `Reseau`, `Partition`, `Appareil` et leur calcul | 5 |
| `MaillageCoeur/Noms/` | `NomsMaison` (contrat de `noms.json`), `ResolveurNoms`, `Surnoms` | 6 |
| `MaillageCoeur/Suivi/` | `Evenement`, `MemoireAnnonces` (sursis), `Suivi`, `Regroupement`, `Alertes` | 7, 8 |
| `MaillageCoeur/Journal/` | `JournalFichiers` (JSON Lines mensuel, rétention) | 9 |
| `MaillageCoeur/Disposition/` | `Disposition` du graphe, `AppareilAffiche` | 10 |
| `MaillageCoeur/Systeme/` | `TableRoutage` (sysctl), `InterfacesLocales` (getifaddrs) | 11 |
| `MaillageThread/Recenseur/` | `ResolveurDNSSD`, `NavigateurBonjour`, `Recenseur` | 12 |
| `MaillageThread/Surveillance/` | `Surveillance`, `TexteEvenement`, `Notifications`, `OuvertureSession` | 13, 14, 17 |
| `MaillageThread/Vues/` | graphe (Canvas, verre, fiche), journal, barre des menus, réglages | 15, 16, 17 |
| `MaillageThread/MaillageThreadApp.swift` | squelette (tâche 1), puis scènes définitives | 1, 17 |
| `MaillageCoeurTests/`, `MaillageThreadTests/` | tests (le framework hors bac à sable, l'app hébergée) | toutes |
| `README.md`, `README.fr.md` | présentation, construction, démo, textes | 19 |

Les dossiers du dépôt : `.gitignore` et `docs/` existent déjà (spec, maquettes, relevé).

---

### Task 1: Projet, squelette de l'app, adresses IPv6

**Files:**
- Create: `project.yml`, `Signature.xcconfig`, `outils/tester.sh`, `outils/synchroniser-textes.sh`, `outils/traduire.py`
- Create: `MaillageThread/MaillageThreadApp.swift` (squelette), `MaillageThread/Droits.entitlements`, `MaillageThread/Ressources/Localizable.xcstrings`, `MaillageThread/Ressources/InfoPlist.xcstrings`
- Create: `MaillageCoeur/Adresses/AdresseIPv6.swift`, `MaillageCoeur/Adresses/PrefixeIPv6.swift`
- Test: `MaillageCoeurTests/AdressesTests.swift`, `MaillageCoeurTests/CataloguesTests.swift`, `MaillageThreadTests/DemarrageTests.swift`
- Modify: `.gitignore` (Info.plist généré)

**Interfaces:**
- Produces: `AdresseIPv6` (`init?(_ texte: String)`, `init?(octets: [UInt8])`, `octets`, `description`, `estLienLocal`, `prefixe: PrefixeIPv6`, `static func estIPv4(_:) -> Bool`, `Comparable`) ; `PrefixeIPv6` (`init?(_ texte:)` accepte `…/64` ou sans longueur, `init?(octets:)` 8 octets, `init?(omr: Data)`, `init?(reseauLocalDe xp: [UInt8])`, `init(huitOctets:)` interne, `contient(_:)`, `description` « fd19:961f:2db3::/64 », `Codable` en texte, `Comparable`) ; `outils/tester.sh [Cible/Suite …]`.

- [ ] **Step 1: Projet XcodeGen et signature**

`project.yml` :

```yaml
name: MaillageThread
options:
  bundleIdPrefix: fr.djoko.maillage
  deploymentTarget:
    macOS: "26.0"
  developmentLanguage: fr
  createIntermediateGroups: true
  generateEmptyDirectories: false
configFiles:
  Debug: Signature.xcconfig
  Release: Signature.xcconfig
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    SWIFT_TREAT_WARNINGS_AS_ERRORS: YES
    GCC_TREAT_WARNINGS_AS_ERRORS: YES
    ENABLE_USER_SCRIPT_SANDBOXING: YES
    DEAD_CODE_STRIPPING: YES
    MACOSX_DEPLOYMENT_TARGET: "26.0"
    # Textes : catalogues .xcstrings (francais, langue de developpement, et
    # anglais), cles extraites par le compilateur.
    SWIFT_EMIT_LOC_STRINGS: YES
    LOCALIZATION_PREFERS_STRING_CATALOGS: YES
    STRING_CATALOG_GENERATE_SYMBOLS: NO
targets:
  MaillageCoeur:
    type: framework
    platform: macOS
    sources:
      - path: MaillageCoeur
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: fr.djoko.maillage.coeur
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_NSHumanReadableCopyright: ""
        SKIP_INSTALL: YES
        DEFINES_MODULE: YES
  MaillageThread:
    type: application
    platform: macOS
    sources:
      - path: MaillageThread
    dependencies:
      - target: MaillageCoeur
    info:
      path: MaillageThread/Info.plist
      properties:
        CFBundleDisplayName: Maillage Thread
        LSApplicationCategoryType: public.app-category.utilities
        LSUIElement: true
        NSHumanReadableCopyright: ""
        NSLocalNetworkUsageDescription: "Maillage Thread écoute les annonces du réseau local (routeurs de bordure Thread, appareils Matter et HomeKit) pour dessiner le réseau Thread."
        NSBonjourServices:
          - _meshcop._udp
          - _matter._tcp
          - _hap._udp
    settings:
      base:
        PRODUCT_NAME: Maillage Thread
        PRODUCT_MODULE_NAME: MaillageThread
        PRODUCT_BUNDLE_IDENTIFIER: fr.djoko.maillage
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        CODE_SIGN_ENTITLEMENTS: MaillageThread/Droits.entitlements
        ENABLE_HARDENED_RUNTIME: YES
  MaillageCoeurTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: MaillageCoeurTests
    dependencies:
      - target: MaillageCoeur
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: fr.djoko.maillage.coeur.tests
        GENERATE_INFOPLIST_FILE: YES
  MaillageThreadTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: MaillageThreadTests
    dependencies:
      - target: MaillageThread
      - target: MaillageCoeur
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: fr.djoko.maillage.tests
        GENERATE_INFOPLIST_FILE: YES
        # Le produit s'appelle "Maillage Thread" (avec une espace), pas comme la cible.
        TEST_HOST: "$(BUILT_PRODUCTS_DIR)/Maillage Thread.app/Contents/MacOS/Maillage Thread"
        BUNDLE_LOADER: "$(TEST_HOST)"
schemes:
  MaillageThread:
    build:
      targets:
        MaillageThread: all
        MaillageCoeur: all
        MaillageCoeurTests: [test]
        MaillageThreadTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - MaillageCoeurTests
        - MaillageThreadTests
    archive:
      config: Release
```

`Signature.xcconfig` :

```text
// Signature de l'app et des tests.
// Par defaut : ad hoc (le depot compile partout, sans compte Apple). Pour que
// l'autorisation "reseau local" tienne d'une compilation a l'autre, signer
// avec son equipe : creer Local.xcconfig (ignore par git) avec
//   DEVELOPMENT_TEAM = <equipe, 10 caracteres>
//   CODE_SIGN_IDENTITY = Apple Development
// L'equipe : security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject (champ OU).
CODE_SIGN_IDENTITY = -
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM =
#include? "Local.xcconfig"
```

`MaillageThread/Droits.entitlements` (bac à sable, client réseau, fichiers choisis par l'utilisateur pour les captures) :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
</dict>
</plist>
```

Ajouter à la fin de `.gitignore` (xcodegen écrit `MaillageThread/Info.plist` depuis `project.yml`) :

```gitignore
# Genere par xcodegen depuis project.yml (info:)
MaillageThread/Info.plist
```

- [ ] **Step 2: Outils**

`outils/tester.sh` (puis `chmod +x outils/*.sh`) :

```sh
#!/bin/sh
# Genere le projet puis lance les tests : tous, ou ceux passes en arguments
#   outils/tester.sh MaillageCoeurTests/AdressesTests MaillageThreadTests
# Affiche les erreurs, les tests en echec et le bilan ; journal complet dans
# $TMPDIR/maillage-tests.log. Produits de compilation hors du depot (DD).
set -u
cd "$(dirname "$0")/.."
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage}
JOURNAL=${TMPDIR:-/tmp}/maillage-tests.log
xcodegen generate --quiet || exit 1
FILTRES=""
for t in "$@"; do FILTRES="$FILTRES -only-testing:$t"; done
# shellcheck disable=SC2086
xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' \
  -derivedDataPath "$DD" test $FILTRES > "$JOURNAL" 2>&1
CODE=$?
grep -E "(error|warning): |✘|Test run with|\*\* TEST" "$JOURNAL" | grep -v -e appintentsmetadataprocessor -e "\[Connection\]"
echo "journal complet : $JOURNAL (code $CODE)"
exit $CODE
```

`outils/synchroniser-textes.sh` :

```sh
#!/bin/sh
# Met le catalogue de l'app a jour avec les textes extraits par le compilateur
# (a lancer apres une compilation, par exemple outils/tester.sh) : ajoute les
# nouvelles cles, marque "stale" celles qui ont disparu du code. Ensuite :
#   python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/<fichier>.json
set -eu
cd "$(dirname "$0")/.."
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage}
I="$DD/Build/Intermediates.noindex/MaillageThread.build/Debug/MaillageThread.build/Objects-normal"
xcrun xcstringstool sync MaillageThread/Ressources/Localizable.xcstrings --stringsdata "$I"/*/*.stringsdata
```

`outils/traduire.py` (repris de Halo Compagnon) :

```python
#!/usr/bin/env python3
"""Traductions d'un catalogue .xcstrings, au format exact de Xcode.

  python3 outils/traduire.py <catalogue.xcstrings> <traductions.json>

traductions.json : {"<cle francaise>": "<anglais>", ...}. Chaque cle recoit
son anglais et son francais (la cle elle-meme), en specificateurs numerotes
(%1$@, %2$lld...) des qu'il y en a deux et qu'aucun ne l'est deja. Les cles
perimees laissees par `xcstringstool sync` (extractionState "stale") sont
retirees : les tests de LocalisationTests les refusent.

Numerotation : chaque langue est numerotee selon l'ordre d'apparition de ses
propres specificateurs, ce qui suppose que l'anglais garde l'ordre des
valeurs du francais. Si l'anglais permute les valeurs, numeroter soi-meme
les specificateurs dans la traduction de traductions.json (ex : "%2$@ ...
%1$@" pour les inverser) : l'outil ne renumerote jamais une chaine qui l'est
deja.

Pluriel : si une cle ciblee existe deja dans le catalogue avec des
`variations` (pluriel) sur au moins une de ses localisations, l'outil
s'arrete (code de sortie non nul) sans rien ecrire : ca se traduit a la main
dans Xcode, pas avec cet outil.
"""
import json
import re
import sys

SPEC = re.compile(r"%(?:\d+\$)?(lld|ld|d|@|lf|f)")


def numeroter(s):
    if re.search(r"%\d+\$", s) or len(SPEC.findall(s)) < 2:
        return s
    rang = iter(range(1, 100))
    return SPEC.sub(lambda m: f"%{next(rang)}${m.group(1)}", s)


def unite(valeur):
    return {"stringUnit": {"state": "translated", "value": valeur}}


def est_plurielle(entree):
    """Une localisation existante de la cle porte des `variations` (pluriel)."""
    return any("variations" in loc for loc in entree.get("localizations", {}).values())


def main(chemin, fichier):
    with open(chemin, encoding="utf-8") as f:
        d = json.load(f)
    with open(fichier, encoding="utf-8") as f:
        traductions = json.load(f)
    cles = d["strings"]
    # Valide tout traductions.json avant la moindre ecriture (rien de partiel).
    pluriels = sorted(c for c in traductions if c in cles and est_plurielle(cles[c]))
    if pluriels:
        sys.exit("pluriel : a traduire a la main dans Xcode : " + ", ".join(pluriels))
    for k in [k for k, e in cles.items() if e.get("extractionState") == "stale"]:
        del cles[k]
    for cle, anglais in traductions.items():
        locs = cles.setdefault(cle, {}).setdefault("localizations", {})
        locs["fr"] = unite(numeroter(cle))
        locs["en"] = unite(numeroter(anglais))
    texte = json.dumps(d, ensure_ascii=False, indent=2, separators=(",", " : "), sort_keys=True)
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(texte + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
```

- [ ] **Step 3: Squelette de l'app et catalogues**

`MaillageThread/MaillageThreadApp.swift` :

```swift
import SwiftUI

/// Squelette : l'icone de la barre des menus et "Quitter". Les scenes
/// definitives (graphe, journal, reglages) arrivent a la tache 17.
@main
struct MaillageThreadApp: App {
    var body: some Scene {
        MenuBarExtra("Maillage Thread", systemImage: "point.3.connected.trianglepath.dotted") {
            Button("Quitter") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
```

`MaillageThread/Ressources/Localizable.xcstrings` :

```json
{
  "sourceLanguage" : "fr",
  "strings" : {
    "Maillage Thread" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Maillage Thread"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Maillage Thread"
          }
        }
      }
    },
    "Quitter" : {
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Quit"
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Quitter"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

`MaillageThread/Ressources/InfoPlist.xcstrings` :

```json
{
  "sourceLanguage" : "fr",
  "strings" : {
    "NSLocalNetworkUsageDescription" : {
      "comment" : "Autorisation reseau local (ecoute Bonjour des routeurs de bordure et des appareils).",
      "extractionState" : "manual",
      "localizations" : {
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Maillage Thread listens to local network announcements (Thread border routers, Matter and HomeKit devices) to draw the Thread network."
          }
        },
        "fr" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Maillage Thread écoute les annonces du réseau local (routeurs de bordure Thread, appareils Matter et HomeKit) pour dessiner le réseau Thread."
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 4: Écrire les tests**

`MaillageCoeurTests/AdressesTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Adresses et prefixes IPv6")
struct AdressesTests {
    @Test func lectureEtEcriture() throws {
        let a = try #require(AdresseIPv6("fd19:961f:2db3:0000:34a9:8acf:e48d:c424"))
        #expect(a.description == "fd19:961f:2db3:0:34a9:8acf:e48d:c424", "un seul zero : pas de ::")
        #expect(AdresseIPv6("fe80::5a:d5f3:dc72:e7d6%en0")?.description == "fe80::5a:d5f3:dc72:e7d6", "zone ignoree")
        #expect(AdresseIPv6("192.0.2.25") == nil)
        #expect(AdresseIPv6("") == nil)
        #expect(AdresseIPv6(octets: [1, 2]) == nil)
        #expect(AdresseIPv6("fe80::5a:d5f3:dc72:e7d6")?.estLienLocal == true)
        #expect(!a.estLienLocal)
        #expect(AdresseIPv6.estIPv4("192.0.2.25"))
        #expect(!AdresseIPv6.estIPv4("fe80::1"))
    }

    @Test func prefixes() throws {
        let p = try #require(PrefixeIPv6("fd19:961f:2db3::/64"))
        #expect(p.description == "fd19:961f:2db3::/64")
        #expect(PrefixeIPv6("fd19:961f:2db3::")?.description == "fd19:961f:2db3::/64")
        #expect(PrefixeIPv6("fd19:961f:2db3::/48") == nil)
        let dedans = try #require(AdresseIPv6("fd19:961f:2db3:0:34a9:8acf:e48d:c424"))
        let dehors = try #require(AdresseIPv6("fd03:54f0:5de:1::5"))
        #expect(p.contient(dedans))
        #expect(!p.contient(dehors))
        #expect(dedans.prefixe == p)
        #expect(dehors.prefixe.description == "fd03:54f0:5de:1::/64")
    }

    @Test func champOMR() {
        // Aqara HubM100, releve du 28/09 : omr=40FD0354F005DE0001
        let omr = Data([0x40, 0xFD, 0x03, 0x54, 0xF0, 0x05, 0xDE, 0x00, 0x01])
        #expect(PrefixeIPv6(omr: omr)?.description == "fd03:54f0:5de:1::/64")
        #expect(PrefixeIPv6(omr: Data([0x30] + [UInt8](repeating: 0, count: 8))) == nil, "longueur 48 refusee")
        #expect(PrefixeIPv6(omr: Data([0x40, 0xFD])) == nil)
    }

    @Test func reseauLocalTireDuXP() {
        // xp=4B36A2B7FEFB200B -> fd4b:36a2:b7fe:200b::/64 (table de routage du Mac, 28/09)
        let xp: [UInt8] = [0x4B, 0x36, 0xA2, 0xB7, 0xFE, 0xFB, 0x20, 0x0B]
        #expect(PrefixeIPv6(reseauLocalDe: xp)?.description == "fd4b:36a2:b7fe:200b::/64")
        #expect(PrefixeIPv6(reseauLocalDe: [0x01]) == nil)
    }

    @Test func ordreEtJSON() throws {
        let a = try #require(PrefixeIPv6("fd03:54f0:5de:1::/64"))
        let b = try #require(PrefixeIPv6("fd19:961f:2db3::/64"))
        #expect([b, a].sorted() == [a, b])
        let encodeur = JSONEncoder()
        encodeur.outputFormatting = .withoutEscapingSlashes
        let json = try encodeur.encode([a])
        #expect(String(decoding: json, as: UTF8.self) == "[\"fd03:54f0:5de:1::/64\"]")
        #expect(try JSONDecoder().decode([PrefixeIPv6].self, from: json) == [a])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([PrefixeIPv6].self, from: Data("[\"pas un prefixe\"]".utf8))
        }
    }
}
```

`MaillageCoeurTests/CataloguesTests.swift` (l'alignement avec le code viendra à la tâche 18) :

```swift
import Foundation
import Testing

/// Catalogues de textes de l'app, lus dans le depot. Ces tests vivent ici (et
/// non dans MaillageThreadTests) : les tests de l'app tournent dans l'app
/// sandboxee, qui ne peut pas lire le depot. L'alignement avec le code vient
/// a la tache 18.
enum Catalogues {
    static let racine = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // MaillageCoeurTests
        .deletingLastPathComponent()  // racine du depot

    static let textes = racine.appendingPathComponent("MaillageThread/Ressources/Localizable.xcstrings")
    static let infoPlist = racine.appendingPathComponent("MaillageThread/Ressources/InfoPlist.xcstrings")

    static func entrees(_ chemin: URL) throws -> (source: String, cles: [String: [String: Any]]) {
        let d = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: chemin)) as? [String: Any])
        let cles = try #require(d["strings"] as? [String: [String: Any]])
        return (d["sourceLanguage"] as? String ?? "", cles)
    }

    /// Specificateurs d'un format, sans leur position (`%1$@` -> `@`), dans l'ordre.
    static func specificateurs(_ s: String) -> [String] {
        let motif = /%(?:\d+\$)?(lld|ld|d|@|lf|f|%)/
        return s.matches(of: motif).map { String($0.output.1) }
    }

    /// Unites de texte d'une localisation : simple, ou formes du pluriel.
    static func unites(_ loc: [String: Any]) -> [String: [String: Any]] {
        if let u = loc["stringUnit"] as? [String: Any] { return ["": u] }
        let pluriel = (loc["variations"] as? [String: Any])?["plural"] as? [String: [String: Any]] ?? [:]
        return pluriel.compactMapValues { $0["stringUnit"] as? [String: Any] }
    }
}

@Suite("Catalogues de textes (francais source, anglais complet)")
struct CataloguesTests {
    @Test(arguments: [Catalogues.textes, Catalogues.infoPlist])
    func chaqueCleATraductionAnglaise(_ chemin: URL) throws {
        let (source, cles) = try Catalogues.entrees(chemin)
        #expect(source == "fr", "le francais est la langue de developpement")
        #expect(!cles.isEmpty)
        for (cle, entree) in cles {
            #expect(entree["extractionState"] as? String != "stale", "cle perimee : \(cle)")
            let locs = entree["localizations"] as? [String: [String: Any]] ?? [:]
            let en = try #require(locs["en"], "pas d'anglais : \(cle)")
            let unites = Catalogues.unites(en)
            #expect(!unites.isEmpty, "anglais vide : \(cle)")
            if unites.keys.contains(where: { !$0.isEmpty }) {
                #expect(unites["one"] != nil && unites["other"] != nil, "pluriel incomplet : \(cle)")
            }
            let attendus = Catalogues.specificateurs(cle)
            for (forme, u) in unites {
                #expect(u["state"] as? String == "translated", "anglais non valide (\(forme)) : \(cle)")
                let valeur = u["value"] as? String ?? ""
                #expect(!valeur.isEmpty, "anglais vide (\(forme)) : \(cle)")
                #expect(Catalogues.specificateurs(valeur).sorted() == attendus.sorted(),
                        "specificateurs differents : \(cle) -> \(valeur)")
            }
        }
    }
}
```

`MaillageThreadTests/DemarrageTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageThread

@Suite("Demarrage de l'app (tests heberges)")
struct DemarrageTests {
    @Test func identite() {
        #expect(Bundle.main.bundleIdentifier == "fr.djoko.maillage")
        #expect(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true, "app de la barre des menus")
        let services = Bundle.main.object(forInfoDictionaryKey: "NSBonjourServices") as? [String]
        #expect(services == ["_meshcop._udp", "_matter._tcp", "_hap._udp"])
    }
}
```

- [ ] **Step 5: Lancer les tests : échec attendu**

Run: `outils/tester.sh`
Expected: FAIL à la compilation de `MaillageCoeurTests` (`cannot find 'AdresseIPv6' in scope`). S'il manque un fichier source au framework, xcodegen peut aussi refuser une cible vide : c'est le même échec attendu.

- [ ] **Step 6: Écrire les adresses**

`MaillageCoeur/Adresses/AdresseIPv6.swift` :

```swift
import Darwin

/// Adresse IPv6 : 16 octets. Lue depuis le texte (avec ou sans zone "%en0"),
/// ecrite sous la forme courte de inet_ntop ("fd19:961f:2db3:0:2c97:...").
public struct AdresseIPv6: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let octets: [UInt8]

    public init?(octets: [UInt8]) {
        guard octets.count == 16 else { return nil }
        self.octets = octets
    }

    public init?(_ texte: String) {
        let sansZone = String(texte.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        var brut = in6_addr()
        guard inet_pton(AF_INET6, sansZone, &brut) == 1 else { return nil }
        octets = withUnsafeBytes(of: brut) { Array($0) }
    }

    public var description: String {
        var brut = in6_addr()
        withUnsafeMutableBytes(of: &brut) { $0.copyBytes(from: octets) }
        var tampon = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        let taille = socklen_t(tampon.count)
        guard inet_ntop(AF_INET6, &brut, &tampon, taille) != nil else { return "::" }
        return tampon.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    /// fe80::/10 : adresse de lien, jamais routee.
    public var estLienLocal: Bool { octets[0] == 0xFE && (octets[1] & 0xC0) == 0x80 }

    /// Prefixe /64 de l'adresse.
    public var prefixe: PrefixeIPv6 { PrefixeIPv6(huitOctets: Array(octets[0..<8])) }

    public static func < (a: AdresseIPv6, b: AdresseIPv6) -> Bool {
        a.octets.lexicographicallyPrecedes(b.octets)
    }

    /// Texte d'une adresse IPv4 valide ("192.0.2.25").
    public static func estIPv4(_ texte: String) -> Bool {
        var brut = in_addr()
        return inet_pton(AF_INET, texte, &brut) == 1
    }
}
```

`MaillageCoeur/Adresses/PrefixeIPv6.swift` :

```swift
import Foundation

/// Prefixe IPv6 de longueur 64 (prefixes OMR, reseau local) : ses 8 premiers
/// octets. En texte et en JSON : "fd19:961f:2db3::/64".
public struct PrefixeIPv6: Hashable, Comparable, Sendable, CustomStringConvertible, Codable {
    public let octets: [UInt8]

    init(huitOctets: [UInt8]) {
        precondition(huitOctets.count == 8)
        octets = huitOctets
    }

    public init?(octets: [UInt8]) {
        guard octets.count == 8 else { return nil }
        self.octets = octets
    }

    /// "fd19:961f:2db3::/64" ou "fd19:961f:2db3::" ; une autre longueur que 64 est refusee.
    public init?(_ texte: String) {
        let morceaux = texte.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        if morceaux.count == 2 && morceaux[1] != "64" { return nil }
        guard let adresse = AdresseIPv6(String(morceaux[0])) else { return nil }
        octets = Array(adresse.octets[0..<8])
    }

    /// Champ TXT `omr` d'un routeur de bordure : longueur en bits (0x40) puis le prefixe.
    public init?(omr: Data) {
        let o = [UInt8](omr)
        guard o.count >= 9, o[0] == 64 else { return nil }
        octets = Array(o[1...8])
    }

    /// Prefixe on-link des routeurs de bordure, tire de l'identifiant etendu du
    /// reseau (`xp`, 8 octets) : fd + 5 premiers octets + 2 derniers.
    public init?(reseauLocalDe xp: [UInt8]) {
        guard xp.count == 8 else { return nil }
        octets = [0xFD] + Array(xp[0..<5]) + Array(xp[6..<8])
    }

    public func contient(_ adresse: AdresseIPv6) -> Bool {
        Array(adresse.octets[0..<8]) == octets
    }

    public var description: String {
        (AdresseIPv6(octets: octets + [UInt8](repeating: 0, count: 8))?.description ?? "::") + "/64"
    }

    public static func < (a: PrefixeIPv6, b: PrefixeIPv6) -> Bool {
        a.octets.lexicographicallyPrecedes(b.octets)
    }

    public init(from decoder: Decoder) throws {
        let texte = try decoder.singleValueContainer().decode(String.self)
        guard let p = PrefixeIPv6(texte) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "prefixe IPv6 invalide : \(texte)"))
        }
        self = p
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(description)
    }
}
```

- [ ] **Step 7: Lancer les tests**

Run: `outils/tester.sh`
Expected: PASS, `✔ Test run with 6 tests in 2 suites passed` (framework : adresses 5, catalogues 1, paramétré sur 2 fichiers) puis `✔ Test run with 1 test in 1 suite passed` (app hébergée), et `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit**

```bash
git add project.yml Signature.xcconfig .gitignore outils MaillageCoeur MaillageCoeurTests MaillageThread MaillageThreadTests
git commit -m "Creer le projet, le squelette de l'app et les adresses IPv6

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Champs TXT et format des captures

**Files:**
- Create: `MaillageCoeur/Annonces/ChampsTXT.swift`, `MaillageCoeur/Annonces/Annonces.swift`, `MaillageCoeur/Annonces/CodageJSON.swift`
- Test: `MaillageCoeurTests/AnnoncesTests.swift`

**Interfaces:**
- Consumes: rien de neuf.
- Produces: `ChampsTXT` (`init(_ valeurs: [String: Data])`, `init(brut: Data)` RFC 6763, `subscript(cle:) -> Data?`, `texte(_:)`, `entier(_:)`, `valeurs`, `estVide` ; Codable : texte ASCII imprimable, sinon `"hex:…"`) ; `Data(hexa:)` et `Data.hexa` (internes) ; `AnnonceService(instance:hote:port:txt:)` ; `RouteIPv6(prefixe:passerelle:interface:)` ; `Annonces(date:routeurs:matter:hap:adresses:routes:prefixesLocaux:note:)`, `adresses(de hote: String?) -> [String]` ; `CodageJSON.encodeur(lisible:)`, `CodageJSON.decodeur()` (dates ISO 8601 UTC avec millisecondes, lecture aussi sans).

- [ ] **Step 1: Écrire le test**

`MaillageCoeurTests/AnnoncesTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

/// Enregistrement TXT brut : chaque chaine precedee de sa longueur.
func txtBrut(_ chaines: [[UInt8]]) -> Data {
    Data(chaines.flatMap { [UInt8($0.count)] + $0 })
}

@Suite("Champs TXT et format des captures")
struct AnnoncesTests {
    @Test func lectureDuBrut() throws {
        let xp: [UInt8] = [0x4B, 0x36, 0xA2, 0xB7, 0xFE, 0xFB, 0x20, 0x0B]
        let brut = txtBrut([
            Array("vn=Apple".utf8),
            Array("xp=".utf8) + xp,
            Array("Tv=1.4.0".utf8),       // cle en majuscules : gardee en minuscules
            Array("vn=Autre".utf8),       // doublon : la premiere occurrence compte
            Array("drapeau".utf8),        // cle sans "=" : valeur vide
            [],                           // chaine vide : ignoree
            Array("=sanscle".utf8),       // pas de cle : ignoree
        ])
        let t = ChampsTXT(brut: brut)
        #expect(t.texte("vn") == "Apple")
        #expect(t["xp"] == Data(xp))
        #expect(t["XP"] == Data(xp), "cles insensibles a la casse")
        #expect(t.texte("tv") == "1.4.0")
        #expect(t["drapeau"] == Data())
        #expect(t.valeurs.count == 4)
        #expect(ChampsTXT(brut: Data([5, 0x61])).estVide, "longueur qui deborde : lecture arretee")
        #expect(ChampsTXT(brut: txtBrut([Array("SII=6000".utf8)])).entier("sii") == 6000)
    }

    @Test func formatDesCaptures() throws {
        let t = ChampsTXT(["vn": Data("Apple".utf8),
                           "xp": Data([0x4B, 0x36, 0x00]),
                           "piege": Data("hex:41".utf8)])
        let json = try CodageJSON.encodeur().encode(t)
        #expect(String(decoding: json, as: UTF8.self)
                == #"{"piege":"hex:6865783A3431","vn":"Apple","xp":"hex:4B3600"}"#)
        #expect(try CodageJSON.decodeur().decode(ChampsTXT.self, from: json) == t)
        #expect(throws: DecodingError.self) {
            try CodageJSON.decodeur().decode(ChampsTXT.self, from: Data(#"{"xp":"hex:4B5"}"#.utf8))
        }
        #expect(Data(hexa: "4b36") == Data([0x4B, 0x36]))
        #expect(Data(hexa: "zz") == nil)
    }

    @Test func allerRetourDUneCapture() throws {
        let date = try Date("2026-09-27T20:42:09Z", strategy: .iso8601).addingTimeInterval(0.5)
        let a = Annonces(
            date: date,
            routeurs: [AnnonceService(instance: "Apple TV 4K", hote: "Apple-TV-4K.local", port: 49153,
                                      txt: ChampsTXT(["nn": Data("MyHome1482620090".utf8)]))],
            matter: [AnnonceService(instance: "30FC8F95E0E1A385-00000000F89487F7")],
            adresses: ["Apple-TV-4K.local": ["fe80::5a:d5f3:dc72:e7d6"]],
            routes: [RouteIPv6(prefixe: "fd19:961f:2db3::/64", passerelle: "fe80::5a:d5f3:dc72:e7d6", interface: "en0")],
            prefixesLocaux: ["fd4b:36a2:b7fe:200b::/64"],
            note: "essai")
        let json = try CodageJSON.encodeur(lisible: true).encode(a)
        let texte = String(decoding: json, as: UTF8.self)
        #expect(texte.contains(#""date" : "2026-09-27T20:42:09.500Z""#), "UTC, millisecondes")
        #expect(try CodageJSON.decodeur().decode(Annonces.self, from: json) == a)
        #expect(a.adresses(de: "Apple-TV-4K.local") == ["fe80::5a:d5f3:dc72:e7d6"])
        #expect(a.adresses(de: nil) == [])
        let sansMs = Data(#"{"date":"2026-09-27T20:42:09Z","routeurs":[],"matter":[],"hap":[],"adresses":{},"routes":[],"prefixesLocaux":[]}"#.utf8)
        #expect(try CodageJSON.decodeur().decode(Annonces.self, from: sansMs).date == date.addingTimeInterval(-0.5))
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/AnnoncesTests`
Expected: FAIL à la compilation (`cannot find 'ChampsTXT' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageCoeur/Annonces/ChampsTXT.swift` :

```swift
import Foundation

/// Champs d'un enregistrement TXT DNS-SD (RFC 6763, section 6) : cle -> octets.
/// Les cles sont gardees en minuscules (insensibles a la casse) ; une cle sans
/// "=" a une valeur vide.
public struct ChampsTXT: Hashable, Sendable {
    public private(set) var valeurs: [String: Data]

    public init(_ valeurs: [String: Data] = [:]) {
        self.valeurs = Dictionary(valeurs.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a })
    }

    /// Enregistrement brut : suite de chaines, chacune precedee de sa longueur
    /// (1 octet). La premiere occurrence d'une cle est retenue ; une chaine vide
    /// ou sans cle est ignoree ; une longueur qui deborde arrete la lecture.
    public init(brut: Data) {
        var v: [String: Data] = [:]
        let o = [UInt8](brut)
        var i = 0
        while i < o.count {
            let n = Int(o[i])
            i += 1
            guard i + n <= o.count else { break }
            let chaine = o[i..<(i + n)]
            i += n
            let egal = chaine.firstIndex(of: UInt8(ascii: "="))
            let octetsCle = chaine[chaine.startIndex..<(egal ?? chaine.endIndex)]
            guard !octetsCle.isEmpty, let cle = String(bytes: octetsCle, encoding: .utf8)?.lowercased() else { continue }
            let valeur = egal.map { Data(chaine[chaine.index(after: $0)...]) } ?? Data()
            if v[cle] == nil { v[cle] = valeur }
        }
        valeurs = v
    }

    public subscript(cle: String) -> Data? { valeurs[cle.lowercased()] }

    /// Valeur en texte UTF-8 (nil si absente ou invalide).
    public func texte(_ cle: String) -> String? {
        self[cle].flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Valeur entiere ecrite en decimal ("6000"), nil sinon.
    public func entier(_ cle: String) -> Int? {
        texte(cle).flatMap { Int($0) }
    }

    public var estVide: Bool { valeurs.isEmpty }
}

extension ChampsTXT: Codable {
    /// Format des captures : une valeur faite d'ASCII imprimable s'ecrit en texte
    /// (sauf si elle commence par "hex:"), toute autre en "hex:" + hexadecimal.
    public init(from decoder: Decoder) throws {
        let brut = try decoder.singleValueContainer().decode([String: String].self)
        var v: [String: Data] = [:]
        for (cle, texte) in brut {
            if texte.hasPrefix("hex:") {
                guard let d = Data(hexa: String(texte.dropFirst(4))) else {
                    throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                            debugDescription: "hexadecimal invalide pour \(cle)"))
                }
                v[cle.lowercased()] = d
            } else {
                v[cle.lowercased()] = Data(texte.utf8)
            }
        }
        valeurs = v
    }

    public func encode(to encoder: Encoder) throws {
        var brut: [String: String] = [:]
        for (cle, d) in valeurs {
            let texte = String(decoding: d, as: UTF8.self)
            let imprimable = d.allSatisfy { (0x20...0x7E).contains($0) } && !texte.hasPrefix("hex:")
            brut[cle] = imprimable ? texte : "hex:" + d.hexa
        }
        var c = encoder.singleValueContainer()
        try c.encode(brut)
    }
}

extension Data {
    /// "4B36A2" -> [0x4B, 0x36, 0xA2] ; nil si longueur impaire ou caractere invalide.
    init?(hexa: String) {
        var octets: [UInt8] = []
        var haut: UInt8?
        for c in hexa.utf8 {
            let v: UInt8
            switch c {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): v = c - UInt8(ascii: "0")
            case UInt8(ascii: "a")...UInt8(ascii: "f"): v = c - UInt8(ascii: "a") + 10
            case UInt8(ascii: "A")...UInt8(ascii: "F"): v = c - UInt8(ascii: "A") + 10
            default: return nil
            }
            if let h = haut {
                octets.append(h << 4 | v)
                haut = nil
            } else {
                haut = v
            }
        }
        guard haut == nil else { return nil }
        self.init(octets)
    }

    /// Hexadecimal majuscule ("4B36A2").
    var hexa: String { map { String(format: "%02X", $0) }.joined() }
}
```

`MaillageCoeur/Annonces/Annonces.swift` :

```swift
import Foundation

/// Service DNS-SD vu sur le reseau local.
public struct AnnonceService: Codable, Hashable, Sendable {
    /// Nom de l'instance ("Apple TV 4K", "30FC8F95E0E1A385-00000000F89487F7").
    public var instance: String
    /// Hote de la cible SRV, sans point final ("Apple-TV-4K.local") ; nil si non resolu.
    public var hote: String?
    public var port: UInt16?
    public var txt: ChampsTXT

    public init(instance: String, hote: String? = nil, port: UInt16? = nil, txt: ChampsTXT = ChampsTXT()) {
        self.instance = instance
        self.hote = hote
        self.port = port
        self.txt = txt
    }
}

/// Route IPv6 du Mac vers un prefixe /64, par un routeur (passerelle lien-local).
public struct RouteIPv6: Codable, Hashable, Sendable {
    /// "fd19:961f:2db3::/64"
    public var prefixe: String
    /// "fe80::5a:d5f3:dc72:e7d6" (sans zone)
    public var passerelle: String?
    /// "en0"
    public var interface: String?

    public init(prefixe: String, passerelle: String?, interface: String? = nil) {
        self.prefixe = prefixe
        self.passerelle = passerelle
        self.interface = interface
    }
}

/// Tout ce que le Mac voit a un instant : la matiere d'un instantane, et le
/// format des captures (tests, mode demo, option de capture de l'app).
public struct Annonces: Codable, Equatable, Sendable {
    public var date: Date
    /// `_meshcop._udp` : routeurs de bordure.
    public var routeurs: [AnnonceService]
    /// `_matter._tcp` : une instance par appareil et par fabrique.
    public var matter: [AnnonceService]
    /// `_hap._udp` : accessoires HomeKit.
    public var hap: [AnnonceService]
    /// Adresses resolues de chaque hote (cle : `AnnonceService.hote`), en texte.
    public var adresses: [String: [String]]
    /// Routes IPv6 /64 du Mac par un routeur lien-local (vide si illisibles).
    public var routes: [RouteIPv6]
    /// Prefixes /64 des interfaces du Mac, en texte.
    public var prefixesLocaux: [String]
    /// Remarque libre (origine d'une capture reconstituee...).
    public var note: String?

    public init(date: Date, routeurs: [AnnonceService] = [], matter: [AnnonceService] = [],
                hap: [AnnonceService] = [], adresses: [String: [String]] = [:],
                routes: [RouteIPv6] = [], prefixesLocaux: [String] = [], note: String? = nil) {
        self.date = date
        self.routeurs = routeurs
        self.matter = matter
        self.hap = hap
        self.adresses = adresses
        self.routes = routes
        self.prefixesLocaux = prefixesLocaux
        self.note = note
    }

    /// Adresses d'un hote (vide si inconnu).
    public func adresses(de hote: String?) -> [String] {
        hote.flatMap { adresses[$0] } ?? []
    }
}
```

`MaillageCoeur/Annonces/CodageJSON.swift` :

```swift
import Foundation

/// JSON des captures et du journal : cles triees, dates ISO 8601 en UTC avec
/// les millisecondes ("2026-09-27T00:14:00.000Z"). La lecture accepte aussi
/// les dates sans millisecondes.
public enum CodageJSON {
    static let avecMillisecondes = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    static let sansMillisecondes = Date.ISO8601FormatStyle()

    public static func encodeur(lisible: Bool = false) -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = lisible ? [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
                                     : [.sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(date.formatted(avecMillisecondes))
        }
        return e
    }

    public static func decodeur() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let texte = try c.decode(String.self)
            if let date = (try? avecMillisecondes.parse(texte)) ?? (try? sansMillisecondes.parse(texte)) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "date invalide : \(texte)")
        }
        return d
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageCoeurTests/AnnoncesTests`
Expected: PASS, `✔ Test run with 3 tests in 1 suite passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Annonces MaillageCoeurTests/AnnoncesTests.swift
git commit -m "Lire les champs TXT et fixer le format des captures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Décodage : routeurs de bordure, instances Matter, accessoires HomeKit

**Files:**
- Create: `MaillageCoeur/Decodage/RouteurBordure.swift`, `MaillageCoeur/Decodage/InstanceMatter.swift`, `MaillageCoeur/Decodage/AccessoireHAP.swift`
- Test: `MaillageCoeurTests/DecodageTests.swift`

**Interfaces:**
- Consumes: `ChampsTXT`, `AnnonceService`, `AdresseIPv6`, `PrefixeIPv6`, `Data.hexa`.
- Produces: `RoleThread` (`detache`, `enfant`, `routeur`, `chef`) ; `InterfaceThread` ; `EtatAgent` (`init(brut:)`, `init?(_ d: Data)`, `interface`, `bbrActif`, `bbrPrimaire`) ; `RouteurBordure(annonce:adresses:)` avec `instance`, `hote`, `fabricant`, `modele`, `versionThread`, `nomReseau`, `idReseau` (16 hexa), `adresseEtendue`, `partition` (8 hexa), `jeuActif`, `etat`, `prefixeOMR`, `prefixeReseauLocal`, `adresses`, `adressesLien`, `role: RoleThread?` (nil si Thread < 1.4), `static versionAuMoins(_:_:_:)` ; `InstanceMatter(instance:)` (`fabrique`, `noeud`, `nom`, `Comparable`) ; `ProprietesMatter(txt:)` (`sii`, `sai`, `icd`, `endormi`) ; `AccessoireHAP(annonce:)` (`nom`, `modele`, `categorie`, `identifiant`, `appaire`).

- [ ] **Step 1: Écrire le test**

`MaillageCoeurTests/DecodageTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Decodage des annonces")
struct DecodageTests {
    /// TXT d'un routeur de bordure comme le 28/09 (octets bas de `sb` reconstitues).
    static func txtRouteur(tv: String, sb: [UInt8], pt: [UInt8], omr: [UInt8]? = nil) -> ChampsTXT {
        var v: [String: Data] = [
            "vn": Data("Apple".utf8), "mn": Data("BorderRouter".utf8), "tv": Data(tv.utf8),
            "nn": Data("MyHome1482620090".utf8),
            "xp": Data([0x4B, 0x36, 0xA2, 0xB7, 0xFE, 0xFB, 0x20, 0x0B]),
            "xa": Data([0x2A, 0, 0, 0, 0, 0, 0, 0x01]),
            "sb": Data(sb), "pt": Data(pt),
            "at": Data([0x00, 0x00, 0x66, 0xCE, 0xC7, 0x00, 0x00, 0x00]),
        ]
        if let omr { v["omr"] = Data(omr) }
        return ChampsTXT(v)
    }

    @Test func chef() throws {
        let annonce = AnnonceService(instance: "Apple TV 4K", hote: "Apple-TV-4K.local", port: 49153,
                                     txt: Self.txtRouteur(tv: "1.4.0", sb: [0, 0, 0x0F, 0xB1], pt: [0x73, 0x58, 0x6B, 0x68]))
        let r = RouteurBordure(annonce: annonce, adresses: ["fe80::5a:d5f3:dc72:e7d6", "192.0.2.25",
                                                            "fd4b:36a2:b7fe:200b:3:fd31:8a5a:34f5"])
        #expect(r.id == "Apple TV 4K")
        #expect(r.nomReseau == "MyHome1482620090")
        #expect(r.idReseau == "4B36A2B7FEFB200B")
        #expect(r.adresseEtendue == "2A00000000000001")
        #expect(r.partition == "73586B68")
        #expect(r.jeuActif == Date(timeIntervalSince1970: 1_724_827_392), "2024-08-28T06:43:12Z")
        #expect(r.role == .chef)
        #expect(r.etat?.interface == .active)
        #expect(r.etat?.bbrActif == true)
        #expect(r.etat?.bbrPrimaire == true)
        #expect(r.prefixeOMR == nil)
        #expect(r.prefixeReseauLocal?.description == "fd4b:36a2:b7fe:200b::/64")
        #expect(r.adresses.count == 2, "l'IPv4 n'est pas une adresse IPv6")
        #expect(r.adressesLien.map(\.description) == ["fe80::5a:d5f3:dc72:e7d6"])
    }

    @Test func routeurEtThread13() {
        let homepod = RouteurBordure(annonce: AnnonceService(instance: "HomePod Palier",
            txt: Self.txtRouteur(tv: "1.4.0", sb: [0, 0, 0x0C, 0xB1], pt: [0x73, 0x58, 0x6B, 0x68])), adresses: [])
        #expect(homepod.role == .routeur)
        #expect(homepod.etat?.bbrActif == true)
        #expect(homepod.etat?.bbrPrimaire == false)

        // Aqara HubM100 : Thread 1.3.0, bits de role a 0 : role inconnu, pas "detache".
        let aqara = RouteurBordure(annonce: AnnonceService(instance: "Aqara HubM100 #DFEB",
            txt: Self.txtRouteur(tv: "1.3.0", sb: [0, 0, 0x01, 0xB1], pt: [0xE2, 0xE7, 0x9F, 0xFC],
                                 omr: [0x40, 0xFD, 0x03, 0x54, 0xF0, 0x05, 0xDE, 0x00, 0x01])), adresses: [])
        #expect(aqara.role == nil)
        #expect(aqara.etat?.bbrPrimaire == true)
        #expect(aqara.partition == "E2E79FFC")
        #expect(aqara.prefixeOMR?.description == "fd03:54f0:5de:1::/64")

        let sansRien = RouteurBordure(annonce: AnnonceService(instance: "X"), adresses: [])
        #expect(sansRien.role == nil && sansRien.idReseau == nil && sansRien.partition == nil && sansRien.jeuActif == nil)
    }

    @Test func versions() {
        #expect(RouteurBordure.versionAuMoins("1.4.0", 1, 4))
        #expect(RouteurBordure.versionAuMoins("1.10", 1, 4))
        #expect(RouteurBordure.versionAuMoins("2.0", 1, 4))
        #expect(!RouteurBordure.versionAuMoins("1.3.0", 1, 4))
        #expect(!RouteurBordure.versionAuMoins("1", 1, 4))
        #expect(!RouteurBordure.versionAuMoins(nil, 1, 4))
    }

    @Test func instancesMatter() throws {
        let i = try #require(InstanceMatter(instance: "30fc8f95e0e1a385-00000000F89487F7"))
        #expect(i.fabrique == "30FC8F95E0E1A385")
        #expect(i.noeud == "00000000F89487F7")
        #expect(i.nom == "30FC8F95E0E1A385-00000000F89487F7")
        #expect(InstanceMatter(instance: "30FC8F95E0E1A385") == nil)
        #expect(InstanceMatter(instance: "30FC8F95E0E1A385-XYZ") == nil)
        #expect(InstanceMatter(instance: "30FC8F95E0E1A38Z-00000000F89487F7") == nil)
        #expect(InstanceMatter(instance: "A-B-C") == nil)
    }

    @Test func proprietesMatter() {
        #expect(ProprietesMatter(txt: ChampsTXT(["SII": Data("6000".utf8)])).endormi, "1E5019DAC2638F92, 28/09")
        #expect(!ProprietesMatter(txt: ChampsTXT(["SII": Data("2000".utf8), "SAI": Data("2000".utf8)])).endormi,
                "pont Halo, alimente")
        #expect(!ProprietesMatter(txt: ChampsTXT(["SII": Data("300".utf8)])).endormi)
        #expect(ProprietesMatter(txt: ChampsTXT(["ICD": Data("0".utf8)])).endormi)
        #expect(!ProprietesMatter(txt: ChampsTXT()).endormi)
        #expect(ProprietesMatter(txt: ChampsTXT(["SAI": Data("800".utf8)])).sai == 800)
    }

    @Test func accessoireHAP() {
        let a = AccessoireHAP(annonce: AnnonceService(instance: "Eve Door 4A3B", hote: "Eve-Door-4A3B.local",
            txt: ChampsTXT(["md": Data("Eve Door".utf8), "ci": Data("10".utf8),
                            "id": Data("AA:BB:CC:DD:EE:FF".utf8), "sf": Data("0".utf8)])))
        #expect(a.nom == "Eve Door 4A3B")
        #expect(a.modele == "Eve Door")
        #expect(a.categorie == 10)
        #expect(a.identifiant == "AA:BB:CC:DD:EE:FF")
        #expect(a.appaire == true)
        #expect(AccessoireHAP(annonce: AnnonceService(instance: "Neuf", txt: ChampsTXT(["sf": Data("1".utf8)]))).appaire == false)
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/DecodageTests`
Expected: FAIL à la compilation (`cannot find 'RouteurBordure' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageCoeur/Decodage/RouteurBordure.swift` :

```swift
import Foundation

/// Role d'un routeur dans sa partition Thread.
public enum RoleThread: String, Codable, Hashable, Sendable {
    case detache, enfant, routeur, chef
}

/// Etat de l'interface Thread d'un agent de bordure.
public enum InterfaceThread: String, Codable, Hashable, Sendable {
    case nonInitialisee, inactive, active
}

/// Bits d'etat d'un agent de bordure (TXT `sb`, 32 bits, gros-boutiste).
public struct EtatAgent: Hashable, Sendable {
    public let brut: UInt32

    public init(brut: UInt32) { self.brut = brut }

    public init?(_ d: Data) {
        guard d.count == 4 else { return nil }
        brut = d.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    }

    /// Bits 3-4.
    public var interface: InterfaceThread {
        switch (brut >> 3) & 3 {
        case 0: .nonInitialisee
        case 1: .inactive
        default: .active
        }
    }

    /// Bit 7 : routeur de dorsale (BBR) actif.
    public var bbrActif: Bool { (brut >> 7) & 1 == 1 }
    /// Bit 8 : BBR primaire de sa partition.
    public var bbrPrimaire: Bool { (brut >> 8) & 1 == 1 }
    /// Bits 9-10, sens garanti a partir de Thread 1.4 : lire `RouteurBordure.role`.
    var bitsRole: UInt32 { (brut >> 9) & 3 }
}

/// Routeur de bordure Thread tel qu'il s'annonce (`_meshcop._udp`).
public struct RouteurBordure: Hashable, Sendable, Identifiable {
    public var id: String { instance }
    /// Nom de l'instance mDNS ("Apple TV 4K").
    public let instance: String
    public let hote: String?
    /// `vn`, `mn`
    public let fabricant: String?
    public let modele: String?
    /// `tv` : version de Thread ("1.4.0").
    public let versionThread: String?
    /// `nn` : nom du reseau.
    public let nomReseau: String?
    /// `xp` : identifiant etendu du reseau, 16 hexa majuscules.
    public let idReseau: String?
    /// `xa` : adresse etendue du routeur, 16 hexa majuscules.
    public let adresseEtendue: String?
    /// `pt` : identifiant de partition, 8 hexa majuscules.
    public let partition: String?
    /// `at` : date du jeu de parametres actif (48 bits de secondes).
    public let jeuActif: Date?
    /// `sb`
    public let etat: EtatAgent?
    /// `omr` : prefixe OMR publie (quand le routeur l'annonce).
    public let prefixeOMR: PrefixeIPv6?
    /// Prefixe du reseau local tire de `xp`.
    public let prefixeReseauLocal: PrefixeIPv6?
    /// Adresses de l'hote, triees.
    public let adresses: [AdresseIPv6]

    public init(annonce: AnnonceService, adresses textes: [String]) {
        let t = annonce.txt
        instance = annonce.instance
        hote = annonce.hote
        fabricant = t.texte("vn")
        modele = t.texte("mn")
        versionThread = t.texte("tv")
        nomReseau = t.texte("nn")
        let xp = t["xp"].flatMap { $0.count == 8 ? $0 : nil }
        idReseau = xp?.hexa
        adresseEtendue = t["xa"].flatMap { $0.count == 8 ? $0.hexa : nil }
        partition = t["pt"].flatMap { $0.count == 4 ? $0.hexa : nil }
        jeuActif = t["at"].flatMap(Self.dateJeuActif)
        etat = t["sb"].flatMap { EtatAgent($0) }
        prefixeOMR = t["omr"].flatMap { PrefixeIPv6(omr: $0) }
        prefixeReseauLocal = xp.flatMap { PrefixeIPv6(reseauLocalDe: [UInt8]($0)) }
        adresses = Array(Set(textes.compactMap { AdresseIPv6($0) })).sorted()
    }

    /// Adresses lien-local (fe80::/10) : celles qu'on retrouve comme passerelles des routes.
    public var adressesLien: [AdresseIPv6] { adresses.filter(\.estLienLocal) }

    /// Role dans la partition. Les bits de role n'existent qu'a partir de
    /// Thread 1.4 : avant, ils valent 0 sans rien dire, et le role est inconnu
    /// (nil), jamais "detache".
    public var role: RoleThread? {
        guard let etat, Self.versionAuMoins(versionThread, 1, 4) else { return nil }
        switch etat.bitsRole {
        case 0: return .detache
        case 1: return .enfant
        case 2: return .routeur
        default: return .chef
        }
    }

    /// `at` : 6 octets de secondes depuis 1970, puis 2 octets (ticks, U).
    static func dateJeuActif(_ d: Data) -> Date? {
        guard d.count == 8 else { return nil }
        let secondes = d.prefix(6).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        guard secondes > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(secondes))
    }

    /// "1.4.0" >= (1, 4)
    static func versionAuMoins(_ v: String?, _ majeure: Int, _ mineure: Int) -> Bool {
        guard let v else { return false }
        let n = v.split(separator: ".").compactMap { Int($0) }
        guard n.count >= 2 else { return false }
        return (n[0], n[1]) >= (majeure, mineure)
    }
}
```

`MaillageCoeur/Decodage/InstanceMatter.swift` :

```swift
import Foundation

/// Instance `_matter._tcp` : un appareil sur une fabrique, nommee
/// "<fabrique>-<noeud>" (16 hexa chacun).
public struct InstanceMatter: Hashable, Comparable, Sendable {
    /// Identifiant compresse de la fabrique, 16 hexa majuscules.
    public let fabrique: String
    /// Identifiant du noeud sur cette fabrique, 16 hexa majuscules.
    public let noeud: String

    public init?(instance: String) {
        let m = instance.split(separator: "-", omittingEmptySubsequences: false)
        guard m.count == 2, m.allSatisfy({ $0.count == 16 && $0.allSatisfy(\.isHexDigit) }) else { return nil }
        fabrique = m[0].uppercased()
        noeud = m[1].uppercased()
    }

    public var nom: String { "\(fabrique)-\(noeud)" }

    public static func < (a: InstanceMatter, b: InstanceMatter) -> Bool {
        (a.fabrique, a.noeud) < (b.fabrique, b.noeud)
    }
}

/// Proprietes Matter annoncees dans le TXT d'une instance operationnelle.
public struct ProprietesMatter: Hashable, Sendable {
    /// `SII` : intervalle de repos (ms).
    public let sii: Int?
    /// `SAI` : intervalle actif (ms).
    public let sai: Int?
    /// `ICD` : mode de l'appareil a faible consommation (0 SIT, 1 LIT).
    public let icd: Int?

    public init(txt: ChampsTXT) {
        sii = txt.entier("sii")
        sai = txt.entier("sai")
        icd = txt.entier("icd")
    }

    /// Endormi (appareil a faible consommation) : ICD annonce, ou repos d'au
    /// moins 5 s. SII seul ne suffit pas : presque tous les appareils Thread
    /// l'annoncent (le pont Halo, alimente, annonce 2000 ; releve du 28/09).
    public var endormi: Bool { icd != nil || (sii ?? 0) >= 5000 }
}
```

`MaillageCoeur/Decodage/AccessoireHAP.swift` :

```swift
import Foundation

/// Accessoire HomeKit (`_hap._udp`) : son nom est celui de l'instance.
public struct AccessoireHAP: Hashable, Sendable {
    /// Nom de l'instance ("Eve Door 4A3B").
    public let nom: String
    /// `md` : modele.
    public let modele: String?
    /// `ci` : categorie HomeKit (5 ampoule, 6 serrure, 7 prise...).
    public let categorie: Int?
    /// `id` : identifiant de l'accessoire ("AA:BB:CC:DD:EE:FF").
    public let identifiant: String?
    /// `sf` bit 0 : 0 = appaire.
    public let appaire: Bool?

    public init(annonce: AnnonceService) {
        let t = annonce.txt
        nom = annonce.instance
        modele = t.texte("md")
        categorie = t.entier("ci")
        identifiant = t.texte("id")
        appaire = t.entier("sf").map { $0 & 1 == 0 }
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageCoeurTests/DecodageTests`
Expected: PASS, `✔ Test run with 6 tests in 1 suite passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Decodage MaillageCoeurTests/DecodageTests.swift
git commit -m "Decoder les routeurs de bordure, les instances Matter et HomeKit

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Relevé réel du 28/09

**Files:**
- Create: `MaillageCoeur/Demo/releve-2026-09-28.json` (copie de `docs/releves/2026-09-28/capture-0215.json`), `MaillageCoeur/Demo/Releve20260928.swift`
- Test: `MaillageCoeurTests/ReleveTests.swift`

**Interfaces:**
- Consumes: `Annonces`, `CodageJSON`, `RouteurBordure`.
- Produces: `Releve20260928.annonces: Annonces` (ressource du framework, 6 routeurs, 57 instances Matter sur 28 hôtes, 2 routes, préfixe local `fd4b:36a2:b7fe:200b::/64`).

- [ ] **Step 1: Écrire le test**

`MaillageCoeurTests/ReleveTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Releve reel du 28/09 (donnees du mode demo et des tests)")
struct ReleveTests {
    let a = Releve20260928.annonces

    @Test func contenu() {
        #expect(a.routeurs.count == 6)
        #expect(a.matter.count == 57)
        #expect(a.hap.isEmpty)
        #expect(Set(a.matter.compactMap(\.hote)).count == 28)
        #expect(a.routes.count == 2)
        #expect(a.prefixesLocaux == ["fd4b:36a2:b7fe:200b::/64"])
        #expect(abs(a.date.timeIntervalSince1970 - 1_790_547_354.126) < 0.001, "2026-09-27T22:15:54.126Z")
    }

    @Test func routeursDecodes() throws {
        let routeurs = a.routeurs.map { RouteurBordure(annonce: $0, adresses: a.adresses(de: $0.hote)) }
        let parNom = Dictionary(uniqueKeysWithValues: routeurs.map { ($0.instance, $0) })
        let atv = try #require(parNom["Apple TV 4K"])
        #expect(atv.role == .chef)
        #expect(atv.partition == "73586B68")
        #expect(atv.adressesLien.map(\.description) == ["fe80::5a:d5f3:dc72:e7d6"])
        let aqara = try #require(parNom["Aqara HubM100 #DFEB"])
        #expect(aqara.partition == "E2E79FFC")
        #expect(aqara.role == nil, "Thread 1.3.0")
        #expect(aqara.prefixeOMR?.description == "fd03:54f0:5de:1::/64")
        #expect(Set(routeurs.compactMap(\.idReseau)) == ["4B36A2B7FEFB200B"])
        #expect(routeurs.filter { $0.role == .routeur }.count == 4)
    }

    @Test func horsAdresse() {
        let sans = a.matter.compactMap(\.hote).filter { a.adresses(de: $0).isEmpty }
        #expect(Set(sans) == ["1E5019DAC2638F92.local", "724CC16B32D8F820.local"])
    }

    @Test func allerRetour() throws {
        let json = try CodageJSON.encodeur().encode(a)
        #expect(try CodageJSON.decodeur().decode(Annonces.self, from: json) == a)
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/ReleveTests`
Expected: FAIL à la compilation (`cannot find 'Releve20260928' in scope`).

- [ ] **Step 3: Copier le relevé et écrire son chargement**

```bash
cp docs/releves/2026-09-28/capture-0215.json MaillageCoeur/Demo/releve-2026-09-28.json
```

xcodegen range le `.json` dans les ressources du framework.

`MaillageCoeur/Demo/Releve20260928.swift` :

```swift
import Foundation

/// Releve reel du 28/09/2026 a 02:15 (heure du Mac) : reseau MyHome1482620090
/// scinde (Aqara HubM100 seul dans la partition E2E79FFC), 6 routeurs de
/// bordure, 57 instances Matter sur 28 hotes, dont 2 sans adresse. Sert aux
/// tests et au mode demo.
public enum Releve20260928 {
    public static let annonces: Annonces = {
        guard let url = Bundle(for: Ancre.self).url(forResource: "releve-2026-09-28", withExtension: "json"),
              let donnees = try? Data(contentsOf: url),
              let a = try? CodageJSON.decodeur().decode(Annonces.self, from: donnees) else {
            preconditionFailure("releve-2026-09-28.json absent ou illisible du framework MaillageCoeur")
        }
        return a
    }()

    private final class Ancre {}
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageCoeurTests/ReleveTests`
Expected: PASS, `✔ Test run with 4 tests in 1 suite passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Demo MaillageCoeurTests/ReleveTests.swift
git commit -m "Ajouter le releve reel du 28/09 comme donnees de test et de demo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Calcul de l'instantané

**Files:**
- Create: `MaillageCoeur/Instantane/Instantane.swift`, `MaillageCoeur/Instantane/CalculInstantane.swift`
- Test: `MaillageCoeurTests/Banc.swift` (petit réseau de test, réutilisé ensuite), `MaillageCoeurTests/InstantaneTests.swift`

**Interfaces:**
- Consumes: `Annonces`, `RouteurBordure`, `InstanceMatter`, `ProprietesMatter`, `AccessoireHAP`, `AdresseIPv6`, `PrefixeIPv6`.
- Produces: `GenreAppareil` (`thread`, `ip`, `sansAdresse`) ; `EtatAppareil` (`joignable`, `partitionCoupee`, `sansAdresse`, `inconnu`) ; `Appareil` (`id`, `hote`, `instances`, `servicesMatter`, `proprietes`, `hap`, `adresses`, `adressesIPv4`, `genre`, `idReseau`, `partition`, `prefixe`, `etat`, `endormi`, `fabriques`) ; `Partition` (`id`, `routeurs` centre d'abord, `prefixes`, `appareils`, `estPrincipale`, `chef`, `bbrPrimaire`, `centre`) ; `Reseau` (`id`, `nom`, `partitions` principale d'abord, `prefixeLocal`, `estScinde`, `principale`, `routeurs`, `prefixes`) ; `Instantane(annonces:)` (`date`, `reseaux`, `appareils`, `appareilsIP`, `prefixesSansPartition`, `routeurs`, `prefixes`, `appareil(_:)`, `routeur(_:)`, `reseau(_:)`) ; `Instantane.idAppareil(hote:instance:)` et `Instantane.ordonner(_:)` (internes) ; `ClePartition` (interne). Test : `Banc` (`routeur(_:partition:role:primaire:lien:omr:xp:)`, `appareil(_:noeud:fabriques:adresses:sii:)`, `retirer(_:)`, `route(_:via:)`, `annonces`).

- [ ] **Step 1: Écrire le banc et le test**

`MaillageCoeurTests/Banc.swift` :

```swift
import Foundation
@testable import MaillageCoeur

/// Petit reseau Thread de test, construit a la main.
struct Banc {
    var date: Date
    var routeurs: [AnnonceService] = []
    var matter: [AnnonceService] = []
    var hap: [AnnonceService] = []
    var adresses: [String: [String]] = [:]
    var routes: [RouteIPv6] = []
    var locaux: [String] = ["fd4b:36a2:b7fe:200b::/64"]

    init(date: Date = Date(timeIntervalSince1970: 1_790_000_000)) {
        self.date = date
    }

    /// Routeur de bordure ; `role` nil : Thread 1.3 (role inconnu).
    mutating func routeur(_ nom: String, partition: String = "73586B68", role: RoleThread? = .routeur,
                          primaire: Bool = false, lien: String, omr: String? = nil,
                          xp: String = "4B36A2B7FEFB200B") {
        let bitsRole: UInt32 = switch role {
        case .detache?: 0
        case .enfant?: 1
        case .routeur?: 2
        case .chef?: 3
        case nil: 0
        }
        let sb: UInt32 = 0x01 | 0x10 | 0x20 | 0x80 | (primaire ? 0x100 : 0) | bitsRole << 9
        var txt: [String: Data] = [
            "nn": Data("MyHome1482620090".utf8), "xp": Data(hexa: xp)!, "tv": Data((role == nil ? "1.3.0" : "1.4.0").utf8),
            "pt": Data(hexa: partition)!, "sb": Data(withUnsafeBytes(of: sb.bigEndian) { Array($0) }),
            "at": Data([0x00, 0x00, 0x66, 0xCE, 0xC7, 0x00, 0x00, 0x00]),
        ]
        if let omr, let p = PrefixeIPv6(omr) { txt["omr"] = Data([64] + p.octets) }
        let hote = nom.replacingOccurrences(of: " ", with: "-") + ".local"
        routeurs.append(AnnonceService(instance: nom, hote: hote, port: 49153, txt: ChampsTXT(txt)))
        adresses[hote] = [lien]
    }

    /// Appareil Matter present sur une ou plusieurs fabriques.
    mutating func appareil(_ id: String, noeud: Int = 1, fabriques: [String] = ["30FC8F95E0E1A385"],
                           adresses liste: [String], sii: Int? = nil) {
        let hote = id + ".local"
        for f in fabriques {
            var txt: [String: Data] = [:]
            if let sii { txt["SII"] = Data(String(sii).utf8) }
            matter.append(AnnonceService(instance: f + "-" + String(format: "%016X", noeud), hote: hote,
                                         port: 5540, txt: ChampsTXT(txt)))
        }
        adresses[hote] = liste
    }

    /// Retire un appareil (toutes ses instances et ses adresses).
    mutating func retirer(_ id: String) {
        matter.removeAll { $0.hote == id + ".local" }
        hap.removeAll { $0.hote == id + ".local" }
        adresses[id + ".local"] = nil
    }

    mutating func route(_ prefixe: String, via lien: String) {
        routes.append(RouteIPv6(prefixe: prefixe, passerelle: lien, interface: "en0"))
    }

    var annonces: Annonces {
        Annonces(date: date, routeurs: routeurs, matter: matter, hap: hap, adresses: adresses,
                 routes: routes, prefixesLocaux: locaux)
    }
}
```

`MaillageCoeurTests/InstantaneTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Calcul de l'instantane")
struct InstantaneTests {
    @Test func releveReel() throws {
        let i = Instantane(annonces: Releve20260928.annonces)
        #expect(i.reseaux.count == 1)
        let r = try #require(i.reseaux.first)
        #expect(r.id == "4B36A2B7FEFB200B")
        #expect(r.nom == "MyHome1482620090")
        #expect(r.estScinde)
        #expect(r.partitions.map(\.id) == ["73586B68", "E2E79FFC"])
        #expect(r.prefixeLocal?.description == "fd4b:36a2:b7fe:200b::/64")
        let p = try #require(r.principale)
        #expect(p.estPrincipale)
        #expect(p.routeurs.map(\.instance) == ["Apple TV 4K", "HomePod Avant", "HomePod Palier",
                                              "HomePod mini bureau", "HomePod mini chambre"])
        #expect(p.chef?.instance == "Apple TV 4K")
        #expect(p.bbrPrimaire?.instance == "Apple TV 4K")
        #expect(p.prefixes.map(\.description) == ["fd19:961f:2db3::/64"])
        #expect(p.appareils.count == 22)
        let coupee = r.partitions[1]
        #expect(!coupee.estPrincipale)
        #expect(coupee.routeurs.map(\.instance) == ["Aqara HubM100 #DFEB"])
        #expect(coupee.chef == nil, "role inconnu (Thread 1.3.0)")
        #expect(coupee.prefixes.map(\.description) == ["fd03:54f0:5de:1::/64"])
        #expect(coupee.appareils.isEmpty)

        #expect(i.appareils.count == 24)
        #expect(i.appareils.filter { $0.etat == .joignable }.count == 22)
        #expect(i.appareils.filter { $0.etat == .sansAdresse }.map(\.id) == ["1E5019DAC2638F92", "724CC16B32D8F820"])
        let halo = try #require(i.appareil("56B1E064401F74EF"))
        #expect(halo.fabriques == ["20D00941B54CEF76", "30FC8F95E0E1A385"])
        #expect(halo.genre == .thread)
        #expect(halo.partition == "73586B68")
        #expect(halo.idReseau == "4B36A2B7FEFB200B")
        #expect(halo.prefixe?.description == "fd19:961f:2db3::/64")
        #expect(!halo.endormi, "pont alimente : SII 2000")
        #expect(halo.servicesMatter.count == 2)
        #expect(i.appareil("1E5019DAC2638F92")?.endormi == true)
        #expect(i.appareilsIP.map(\.id) == ["54EF4497B8820000", "A013F03091F3", "C4299622387B", "C4E7AE91A29B"])
        #expect(i.appareilsIP.allSatisfy { $0.etat == .joignable && $0.genre == .ip })
        #expect(i.prefixesSansPartition.isEmpty)
        #expect(i.prefixes.map(\.description) == ["fd03:54f0:5de:1::/64", "fd19:961f:2db3::/64"])
    }

    @Test func sansTableDeRoutage() throws {
        // Bac a sable sans routes : fd19 par elimination (l'Aqara publie fd03 dans son TXT).
        var a = Releve20260928.annonces
        a.routes = []
        let i = Instantane(annonces: a)
        #expect(i.reseaux.first?.principale?.prefixes.map(\.description) == ["fd19:961f:2db3::/64"])
        #expect(i.appareils.filter { $0.etat == .joignable }.count == 22)
    }

    @Test func unePartitionPrendTousLesPrefixes() {
        var b = Banc()
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Second", lien: "fe80::2")
        b.appareil("AAAA000000000001", adresses: ["fd19:961f:2db3::11"])
        b.appareil("AAAA000000000002", noeud: 2, adresses: ["fd4f:9c:ed42::12"])
        let i = Instantane(annonces: b.annonces)
        #expect(i.reseaux.first?.partitions.count == 1)
        #expect(i.reseaux.first?.prefixes.map(\.description) == ["fd19:961f:2db3::/64", "fd4f:9c:ed42::/64"])
        #expect(i.appareils.allSatisfy { $0.etat == .joignable })
    }

    @Test func routeDuMac() {
        var b = Banc()
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Isole", partition: "E2E79FFC", role: nil, primaire: true, lien: "fe80::2")
        b.route("fd03:54f0:5de:1::/64", via: "fe80::2")
        b.route("fd19:961f:2db3::/64", via: "fe80::1")
        b.route("fd4b:36a2:b7fe:200b::/64", via: "fe80::1")   // prefixe local : ignore
        b.appareil("AAAA000000000001", adresses: ["fd03:54f0:5de:1::5"])
        b.appareil("AAAA000000000002", noeud: 2, adresses: ["fd19:961f:2db3::6"])
        b.appareil("AAAA000000000003", noeud: 3, adresses: ["fd19:961f:2db3::7"])
        let i = Instantane(annonces: b.annonces)
        #expect(i.reseaux.first?.partitions.map(\.id) == ["73586B68", "E2E79FFC"], "3 noeuds contre 2")
        #expect(i.appareil("AAAA000000000001")?.etat == .partitionCoupee)
        #expect(i.appareil("AAAA000000000001")?.partition == "E2E79FFC")
        #expect(i.appareil("AAAA000000000002")?.etat == .joignable)
    }

    @Test func prefixesSansPartition() {
        var b = Banc()
        b.routeur("Chef", role: .chef, lien: "fe80::1")
        b.routeur("Isole", partition: "E2E79FFC", role: nil, lien: "fe80::2")
        b.appareil("AAAA000000000001", adresses: ["fd03:54f0:5de:1::5"])
        b.appareil("AAAA000000000002", noeud: 2, adresses: ["fd19:961f:2db3::6"])
        let i = Instantane(annonces: b.annonces)
        #expect(i.prefixesSansPartition.map(\.description) == ["fd03:54f0:5de:1::/64", "fd19:961f:2db3::/64"])
        #expect(i.appareils.allSatisfy { $0.etat == .inconnu && $0.genre == .thread && $0.partition == nil })
    }

    @Test func principaleAEgalite() {
        var b = Banc()
        b.routeur("B", partition: "11111111", role: .routeur, lien: "fe80::1")
        b.routeur("A", partition: "22222222", role: .chef, lien: "fe80::2")
        let i = Instantane(annonces: b.annonces)
        #expect(i.reseaux.first?.partitions.map(\.id) == ["22222222", "11111111"], "a egalite : celle du chef")
    }

    @Test func centreDePartition() {
        var b = Banc()
        b.routeur("Zeta", role: nil, lien: "fe80::1")
        b.routeur("Beta", role: nil, primaire: true, lien: "fe80::2")
        b.routeur("Alpha", role: nil, lien: "fe80::3")
        let p = Instantane(annonces: b.annonces).reseaux.first?.principale
        #expect(p?.routeurs.map(\.instance) == ["Beta", "Alpha", "Zeta"], "sans chef connu : le BBR primaire au centre")
        #expect(p?.chef == nil)
    }

    @Test func hotesEtHAP() {
        var b = Banc()
        b.routeur("Chef", role: .chef, lien: "fe80::1")
        b.matter.append(AnnonceService(instance: "30FC8F95E0E1A385-0000000000000009"))
        b.hap.append(AnnonceService(instance: "Eve Door 4A3B", hote: "Eve-Door-4A3B.local",
                                    txt: ChampsTXT(["md": Data("Eve Door".utf8)])))
        b.adresses["Eve-Door-4A3B.local"] = ["fd19:961f:2db3::44"]
        let i = Instantane(annonces: b.annonces)
        #expect(i.appareil("instance:30FC8F95E0E1A385-0000000000000009")?.etat == .sansAdresse)
        let eve = i.appareil("Eve-Door-4A3B")
        #expect(eve?.hap?.modele == "Eve Door")
        #expect(eve?.etat == .joignable)
        #expect(Instantane.idAppareil(hote: "56B1E064401F74EF.local.", instance: "x") == "56B1E064401F74EF")
        #expect(Instantane.idAppareil(hote: "", instance: "x") == "instance:x")
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/InstantaneTests`
Expected: FAIL à la compilation (`cannot find 'Instantane' in scope`).

- [ ] **Step 3: Écrire le modèle et le calcul**

`MaillageCoeur/Instantane/Instantane.swift` :

```swift
import Foundation

/// Ou se trouve un appareil, d'apres ses adresses.
public enum GenreAppareil: String, Codable, Hashable, Sendable {
    /// Adresse dans un prefixe OMR (reseau Thread).
    case thread
    /// Adresses du reseau local seulement (Wi-Fi, Ethernet).
    case ip
    /// Aucune adresse resolue.
    case sansAdresse
}

/// Etat d'un appareil dans un instantane (l'etat "disparu" vient du suivi).
public enum EtatAppareil: String, Codable, Hashable, Sendable {
    /// Annonce avec une adresse Thread dans la partition principale, ou sur le
    /// reseau local : annonce, pas forcement "repond" (l'app ecoute sans sonder).
    case joignable
    /// Adresse Thread dans une partition qui n'est pas la principale.
    case partitionCoupee
    /// Aucune adresse.
    case sansAdresse
    /// Adresse dans un prefixe dont la partition est inconnue.
    case inconnu
}

/// Appareil Matter ou HomeKit : ses instances regroupees par hote.
public struct Appareil: Hashable, Sendable, Identifiable {
    /// Hote sans ".local" ("56B1E064401F74EF") ; "instance:<nom>" si l'hote est inconnu.
    public let id: String
    public let hote: String?
    /// Instances Matter (une par fabrique), triees.
    public let instances: [InstanceMatter]
    /// Noms des instances `_matter._tcp`, tels qu'annonces.
    public let servicesMatter: [String]
    public let proprietes: ProprietesMatter?
    public let hap: AccessoireHAP?
    /// Adresses IPv6 hors lien-local, triees.
    public let adresses: [AdresseIPv6]
    public let adressesIPv4: [String]
    public let genre: GenreAppareil
    public let idReseau: String?
    public let partition: String?
    /// Prefixe OMR de son adresse Thread.
    public let prefixe: PrefixeIPv6?
    public let etat: EtatAppareil

    public var endormi: Bool { proprietes?.endormi ?? false }
    /// Fabriques ou l'appareil est present, triees.
    public var fabriques: [String] { Array(Set(instances.map(\.fabrique))).sorted() }
}

/// Partition d'un reseau Thread.
public struct Partition: Hashable, Sendable, Identifiable {
    /// Identifiant `pt` (8 hexa), "?" s'il manque.
    public let id: String
    /// Centre d'abord (chef, sinon BBR primaire, sinon le premier par nom), puis par nom.
    public let routeurs: [RouteurBordure]
    public let prefixes: [PrefixeIPv6]
    /// Identifiants des appareils Thread de la partition, tries.
    public let appareils: [String]
    public let estPrincipale: Bool

    public var chef: RouteurBordure? { routeurs.first { $0.role == .chef } }
    public var bbrPrimaire: RouteurBordure? { routeurs.first { $0.etat?.bbrPrimaire == true } }
    public var centre: RouteurBordure? { routeurs.first }
}

/// Reseau Thread (un `xp`), et ses partitions.
public struct Reseau: Hashable, Sendable, Identifiable {
    /// `xp` (16 hexa), ou "nn:<nom>" s'il manque.
    public let id: String
    public let nom: String
    /// La principale d'abord : le plus de noeuds, puis un chef connu, puis l'identifiant.
    public let partitions: [Partition]
    public let prefixeLocal: PrefixeIPv6?

    public var estScinde: Bool { partitions.count > 1 }
    public var principale: Partition? { partitions.first }
    public var routeurs: [RouteurBordure] { partitions.flatMap(\.routeurs) }
    public var prefixes: [PrefixeIPv6] { partitions.flatMap(\.prefixes) }
}

/// Le reseau Thread tel qu'on le voit a un instant, calcule a partir des annonces.
public struct Instantane: Hashable, Sendable {
    public let date: Date
    public let reseaux: [Reseau]
    /// Appareils Thread et sans adresse, tries par identifiant.
    public let appareils: [Appareil]
    /// Appareils du reseau local (hors Thread), tries par identifiant.
    public let appareilsIP: [Appareil]
    /// Prefixes OMR vus sans partition connue.
    public let prefixesSansPartition: [PrefixeIPv6]

    public var routeurs: [RouteurBordure] { reseaux.flatMap(\.routeurs) }
    public var prefixes: [PrefixeIPv6] { (reseaux.flatMap(\.prefixes) + prefixesSansPartition).sorted() }

    public func appareil(_ id: String) -> Appareil? {
        appareils.first { $0.id == id } ?? appareilsIP.first { $0.id == id }
    }

    public func routeur(_ instance: String) -> RouteurBordure? {
        routeurs.first { $0.instance == instance }
    }

    public func reseau(_ id: String) -> Reseau? {
        reseaux.first { $0.id == id }
    }
}
```

`MaillageCoeur/Instantane/CalculInstantane.swift` :

```swift
import Foundation

/// Cle d'une partition : son reseau et son identifiant.
struct ClePartition: Hashable, Sendable {
    let reseau: String
    let partition: String
}

/// Appareil en cours de construction (instances regroupees par hote).
private struct Brouillon {
    var hote: String?
    var services: [String] = []
    var instances: [InstanceMatter] = []
    var proprietes: ProprietesMatter?
    var hap: AccessoireHAP?
}

/// Place d'un appareil d'apres ses adresses.
private struct Place {
    var genre: GenreAppareil
    var cle: ClePartition?
    var prefixe: PrefixeIPv6?
}

extension Instantane {
    /// Calcule l'instantane a partir des annonces : routeurs groupes en
    /// reseaux (`xp`) et partitions (`pt`), prefixes OMR attribues, appareils places.
    ///
    /// Prefixe OMR -> partition, dans l'ordre : champ `omr` d'un routeur ; route
    /// du Mac dont la passerelle est une adresse lien-local d'un routeur ; enfin,
    /// par elimination, si un seul reseau est visible : il n'a qu'une partition,
    /// ou une seule de ses partitions n'a pas de prefixe et un seul prefixe reste.
    /// Sinon le prefixe reste sans partition (ses appareils : etat inconnu).
    /// Les prefixes du reseau local (interfaces du Mac, prefixe tire de `xp`) ne
    /// sont jamais des prefixes OMR.
    public init(annonces a: Annonces) {
        let routeurs = a.routeurs.map { RouteurBordure(annonce: $0, adresses: a.adresses(de: $0.hote)) }
        let cleDe: (RouteurBordure) -> ClePartition = {
            ClePartition(reseau: $0.idReseau ?? "nn:" + ($0.nomReseau ?? $0.instance), partition: $0.partition ?? "?")
        }
        var locaux = Set(a.prefixesLocaux.compactMap { PrefixeIPv6($0) })
        locaux.formUnion(routeurs.compactMap(\.prefixeReseauLocal))

        // 1. Prefixes OMR : champ omr, puis routes du Mac.
        var attribution: [PrefixeIPv6: ClePartition] = [:]
        for r in routeurs {
            if let p = r.prefixeOMR { attribution[p] = cleDe(r) }
        }
        var parLien: [AdresseIPv6: RouteurBordure] = [:]
        for r in routeurs {
            for l in r.adressesLien where parLien[l] == nil { parLien[l] = r }
        }
        for route in a.routes {
            guard let p = PrefixeIPv6(route.prefixe), attribution[p] == nil, !locaux.contains(p),
                  let g = route.passerelle.flatMap({ AdresseIPv6($0) }), let r = parLien[g] else { continue }
            attribution[p] = cleDe(r)
        }

        // 2. Appareils : instances Matter et accessoires HAP regroupes par hote.
        var brouillons: [String: Brouillon] = [:]
        for s in a.matter {
            let id = Self.idAppareil(hote: s.hote, instance: s.instance)
            var b = brouillons[id] ?? Brouillon(hote: s.hote)
            b.services.append(s.instance)
            if let i = InstanceMatter(instance: s.instance) { b.instances.append(i) }
            let p = ProprietesMatter(txt: s.txt)
            if b.proprietes == nil || (b.proprietes?.endormi == false && p.endormi) { b.proprietes = p }
            brouillons[id] = b
        }
        for s in a.hap {
            let id = Self.idAppareil(hote: s.hote, instance: s.instance)
            var b = brouillons[id] ?? Brouillon(hote: s.hote)
            b.hap = AccessoireHAP(annonce: s)
            brouillons[id] = b
        }
        let adressesDe: [String: [String]] = brouillons.mapValues { a.adresses(de: $0.hote) }

        // 3. Elimination, pour les prefixes des appareils restes sans partition.
        var restants = Set(adressesDe.values.joined().compactMap { AdresseIPv6($0) }
            .filter { !$0.estLienLocal }.map(\.prefixe))
            .subtracting(locaux).filter { attribution[$0] == nil }
        let partitions = Set(routeurs.map(cleDe))
        if Set(partitions.map(\.reseau)).count == 1 && !restants.isEmpty {
            let sansPrefixe = partitions.subtracting(Set(attribution.values))
            if partitions.count == 1, let seule = partitions.first {
                for p in restants { attribution[p] = seule }
                restants = []
            } else if sansPrefixe.count == 1, restants.count == 1,
                      let cle = sansPrefixe.first, let p = restants.first {
                attribution[p] = cle
                restants = []
            }
        }

        // 4. Place de chaque appareil.
        var places: [String: Place] = [:]
        for id in brouillons.keys {
            let textes = adressesDe[id] ?? []
            let v6 = textes.compactMap { AdresseIPv6($0) }
            let horsLien = v6.filter { !$0.estLienLocal }
            let v4 = textes.filter { AdresseIPv6.estIPv4($0) }
            if let ad = horsLien.first(where: { attribution[$0.prefixe] != nil }) {
                places[id] = Place(genre: .thread, cle: attribution[ad.prefixe], prefixe: ad.prefixe)
            } else if let ad = horsLien.first(where: { restants.contains($0.prefixe) }) {
                places[id] = Place(genre: .thread, cle: nil, prefixe: ad.prefixe)
            } else if !v6.isEmpty || !v4.isEmpty {
                places[id] = Place(genre: .ip, cle: nil, prefixe: nil)
            } else {
                places[id] = Place(genre: .sansAdresse, cle: nil, prefixe: nil)
            }
        }

        // 5. Reseaux et partitions ; la principale : le plus de noeuds (routeurs
        //    et appareils), puis un chef connu, puis l'identifiant.
        var reseaux: [Reseau] = []
        var principales = Set<ClePartition>()
        for (idReseau, duReseau) in Dictionary(grouping: routeurs, by: { cleDe($0).reseau }) {
            var groupes: [(cle: ClePartition, routeurs: [RouteurBordure], appareils: [String])] = []
            for rs in Dictionary(grouping: duReseau, by: { cleDe($0).partition }).values {
                let cle = cleDe(rs[0])
                let apps = places.filter { $0.value.cle == cle }.map(\.key).sorted()
                groupes.append((cle, Self.ordonner(rs), apps))
            }
            groupes.sort { g1, g2 in
                let n1 = g1.routeurs.count + g1.appareils.count
                let n2 = g2.routeurs.count + g2.appareils.count
                if n1 != n2 { return n1 > n2 }
                let c1 = g1.routeurs.contains { $0.role == .chef }
                let c2 = g2.routeurs.contains { $0.role == .chef }
                if c1 != c2 { return c1 }
                return g1.cle.partition < g2.cle.partition
            }
            if let p = groupes.first?.cle { principales.insert(p) }
            let parts = groupes.enumerated().map { i, g in
                Partition(id: g.cle.partition, routeurs: g.routeurs,
                          prefixes: attribution.filter { $0.value == g.cle }.map(\.key).sorted(),
                          appareils: g.appareils, estPrincipale: i == 0)
            }
            reseaux.append(Reseau(id: idReseau, nom: duReseau.compactMap(\.nomReseau).first ?? idReseau,
                                  partitions: parts, prefixeLocal: duReseau.compactMap(\.prefixeReseauLocal).first))
        }
        reseaux.sort { ($0.nom, $0.id) < ($1.nom, $1.id) }

        // 6. Appareils.
        var threads: [Appareil] = []
        var ips: [Appareil] = []
        for (id, b) in brouillons {
            let place = places[id] ?? Place(genre: .sansAdresse, cle: nil, prefixe: nil)
            let textes = adressesDe[id] ?? []
            let etat: EtatAppareil
            switch place.genre {
            case .sansAdresse: etat = .sansAdresse
            case .ip: etat = .joignable
            case .thread:
                if let cle = place.cle {
                    etat = principales.contains(cle) ? .joignable : .partitionCoupee
                } else {
                    etat = .inconnu
                }
            }
            let appareil = Appareil(
                id: id, hote: b.hote, instances: b.instances.sorted(), servicesMatter: b.services.sorted(),
                proprietes: b.proprietes, hap: b.hap,
                adresses: Array(Set(textes.compactMap { AdresseIPv6($0) }.filter { !$0.estLienLocal })).sorted(),
                adressesIPv4: textes.filter { AdresseIPv6.estIPv4($0) }.sorted(),
                genre: place.genre, idReseau: place.cle?.reseau, partition: place.cle?.partition,
                prefixe: place.prefixe, etat: etat)
            if place.genre == .ip { ips.append(appareil) } else { threads.append(appareil) }
        }

        date = a.date
        self.reseaux = reseaux
        appareils = threads.sorted { $0.id < $1.id }
        appareilsIP = ips.sorted { $0.id < $1.id }
        prefixesSansPartition = restants.sorted()
    }

    /// Centre d'abord (chef, sinon BBR primaire, sinon le premier par nom), puis par nom.
    static func ordonner(_ rs: [RouteurBordure]) -> [RouteurBordure] {
        let tries = rs.sorted { $0.instance < $1.instance }
        guard let centre = tries.first(where: { $0.role == .chef })
                ?? tries.first(where: { $0.etat?.bbrPrimaire == true }) ?? tries.first else { return [] }
        return [centre] + tries.filter { $0.instance != centre.instance }
    }

    /// Identifiant d'un appareil : son hote sans ".local" ni point final.
    static func idAppareil(hote: String?, instance: String) -> String {
        guard var h = hote, !h.isEmpty else { return "instance:" + instance }
        if h.hasSuffix(".") { h.removeLast() }
        if h.lowercased().hasSuffix(".local") { h.removeLast(6) }
        return h
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageCoeurTests/InstantaneTests`
Expected: PASS, `✔ Test run with 8 tests in 1 suite passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Instantane MaillageCoeurTests/Banc.swift MaillageCoeurTests/InstantaneTests.swift
git commit -m "Calculer l'instantane : reseaux, partitions, prefixes, appareils

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Noms : surnoms, contrat de noms.json, fabrique d'Apple

**Files:**
- Create: `MaillageCoeur/Noms/NomsMaison.swift`, `MaillageCoeur/Noms/ResolveurNoms.swift`, `MaillageCoeur/Demo/NomsDemo.swift`
- Test: `MaillageCoeurTests/NomsTests.swift`

**Interfaces:**
- Consumes: `Appareil`, `RouteurBordure`, `InstanceMatter`, `Releve20260928`, `Instantane.idAppareil`, `CodageJSON`.
- Produces: `StatutPasseur` (`ok`, `refuse`, `indisponible`, `erreur`) ; `AccessoireMaison(nom:piece:fabricant:modele:categorie:noeudMatter:)` ; `NomsMaison(version:date:statut:message:domicile:accessoires:)`, `NomsMaison.versionActuelle = 1`, `NomsMaison.lire(_ donnees: Data) throws`, `donnees() throws -> Data`, `NomsMaison.Erreur.versionTropRecente(Int)` ; `ResolveurNoms(surnoms:maison:)` (`fabriqueApple(appareils:) -> String?`, `accessoire(de:fabriqueApple:) -> AccessoireMaison?`, `nom(appareil:fabriqueApple:) -> String`, `nom(routeur:) -> String`) ; `Surnoms.lire(_ url: URL) -> [String: String]`, `Surnoms.ecrire(_:dans:) throws` ; `NomsDemo.maison: NomsMaison` (24 accessoires inventés), `NomsDemo.fabrique = "30FC8F95E0E1A385"`.

- [ ] **Step 1: Écrire le test**

`MaillageCoeurTests/NomsTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Noms : surnoms, Maison, HomeKit, hote")
struct NomsTests {
    let instantane = Instantane(annonces: Releve20260928.annonces)

    @Test func fabriqueDApple() {
        let n = ResolveurNoms(maison: NomsDemo.maison)
        #expect(NomsDemo.maison.accessoires.count == 24)
        #expect(n.fabriqueApple(appareils: instantane.appareils + instantane.appareilsIP) == "30FC8F95E0E1A385")
        #expect(ResolveurNoms().fabriqueApple(appareils: instantane.appareils) == nil, "sans Maison")
    }

    @Test func priorite() throws {
        let halo = try #require(instantane.appareil("56B1E064401F74EF"))
        let f = "30FC8F95E0E1A385"
        #expect(ResolveurNoms().nom(appareil: halo, fabriqueApple: f) == "56B1E064401F74EF", "l'hote a defaut")
        let maison = ResolveurNoms(maison: NomsDemo.maison)
        #expect(maison.nom(appareil: halo, fabriqueApple: f) == "Halo")
        #expect(maison.accessoire(de: halo, fabriqueApple: f)?.piece == "Bureau")
        #expect(maison.nom(appareil: halo, fabriqueApple: "20D00941B54CEF76") == "56B1E064401F74EF",
                "autre fabrique : autres numeros de noeud")
        let surnom = ResolveurNoms(surnoms: ["56B1E064401F74EF": "Pont du bureau"], maison: NomsDemo.maison)
        #expect(surnom.nom(appareil: halo, fabriqueApple: f) == "Pont du bureau")
        #expect(ResolveurNoms(surnoms: ["56B1E064401F74EF": ""]).nom(appareil: halo, fabriqueApple: nil)
                == "56B1E064401F74EF", "surnom vide ignore")

        var b = Banc()
        b.hap.append(AnnonceService(instance: "Eve Door 4A3B", hote: "Eve-Door-4A3B.local"))
        b.adresses["Eve-Door-4A3B.local"] = ["fd19:961f:2db3::44"]
        let eve = try #require(Instantane(annonces: b.annonces).appareil("Eve-Door-4A3B"))
        #expect(ResolveurNoms().nom(appareil: eve, fabriqueApple: nil) == "Eve Door 4A3B", "nom HomeKit")

        let atv = try #require(instantane.routeur("Apple TV 4K"))
        #expect(ResolveurNoms().nom(routeur: atv) == "Apple TV 4K")
        #expect(ResolveurNoms(surnoms: ["Apple TV 4K": "Salon"]).nom(routeur: atv) == "Salon")
    }

    @Test func fichierNomsJSON() throws {
        let d = try NomsDemo.maison.donnees()
        #expect(try NomsMaison.lire(d) == NomsDemo.maison)
        var futur = NomsDemo.maison
        futur.version = 2
        #expect(throws: NomsMaison.Erreur.versionTropRecente(2)) { try NomsMaison.lire(try futur.donnees()) }
        let refus = NomsMaison(date: Date(timeIntervalSince1970: 0), statut: .refuse, message: "acces refuse")
        #expect(try NomsMaison.lire(try refus.donnees()).statut == .refuse)
    }

    @Test func fichierSurnoms() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let url = dossier.appendingPathComponent("sous/surnoms.json")
        #expect(Surnoms.lire(url) == [:], "absent")
        try Surnoms.ecrire(["56B1E064401F74EF": "Halo"], dans: url)
        #expect(Surnoms.lire(url) == ["56B1E064401F74EF": "Halo"])
        try Data("pas du json".utf8).write(to: url)
        #expect(Surnoms.lire(url) == [:], "illisible")
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/NomsTests`
Expected: FAIL à la compilation (`cannot find 'ResolveurNoms' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageCoeur/Noms/NomsMaison.swift` :

```swift
import Foundation

/// Issue de la derniere lecture de Maison par le passeur.
public enum StatutPasseur: String, Codable, Hashable, Sendable {
    case ok
    /// L'utilisateur a refuse l'acces a Maison.
    case refuse
    /// HomeKit indisponible (capacite absente de la signature).
    case indisponible
    case erreur
}

/// Accessoire de Maison, tel que le passeur le releve.
public struct AccessoireMaison: Codable, Hashable, Sendable {
    public var nom: String
    public var piece: String?
    public var fabricant: String?
    public var modele: String?
    public var categorie: String?
    /// `HMAccessory.matterNodeID` en 16 hexa majuscules : son noeud sur la fabrique d'Apple.
    public var noeudMatter: String?

    public init(nom: String, piece: String? = nil, fabricant: String? = nil, modele: String? = nil,
                categorie: String? = nil, noeudMatter: String? = nil) {
        self.nom = nom
        self.piece = piece
        self.fabricant = fabricant
        self.modele = modele
        self.categorie = categorie
        self.noeudMatter = noeudMatter
    }
}

/// Contrat du fichier `noms.json`, ecrit d'un coup par le passeur (Mac
/// Catalyst) dans le conteneur partage, lu par l'app.
public struct NomsMaison: Codable, Hashable, Sendable {
    public static let versionActuelle = 1

    public var version: Int
    public var date: Date
    public var statut: StatutPasseur
    public var message: String?
    public var domicile: String?
    public var accessoires: [AccessoireMaison]

    public init(version: Int = NomsMaison.versionActuelle, date: Date, statut: StatutPasseur = .ok,
                message: String? = nil, domicile: String? = nil, accessoires: [AccessoireMaison] = []) {
        self.version = version
        self.date = date
        self.statut = statut
        self.message = message
        self.domicile = domicile
        self.accessoires = accessoires
    }

    public enum Erreur: Error, Equatable {
        case versionTropRecente(Int)
    }

    /// Lit `noms.json` ; refuse une version plus recente que celle de l'app.
    public static func lire(_ donnees: Data) throws -> NomsMaison {
        let n = try CodageJSON.decodeur().decode(NomsMaison.self, from: donnees)
        guard n.version <= versionActuelle else { throw Erreur.versionTropRecente(n.version) }
        return n
    }

    public func donnees() throws -> Data {
        try CodageJSON.encodeur(lisible: true).encode(self)
    }
}
```

`MaillageCoeur/Noms/ResolveurNoms.swift` :

```swift
import Foundation

/// Nom affiche d'un noeud, par priorite : surnom (donne dans l'app) > nom dans
/// Maison (noeud sur la fabrique d'Apple) > nom HomeKit (`_hap._udp`) > hote.
public struct ResolveurNoms: Hashable, Sendable {
    /// Identifiant de noeud (appareil ou instance de routeur) -> surnom.
    public var surnoms: [String: String]
    public var maison: NomsMaison?

    public init(surnoms: [String: String] = [:], maison: NomsMaison? = nil) {
        self.surnoms = surnoms
        self.maison = maison
    }

    /// Fabrique d'Apple : celle dont les noeuds recouvrent le plus de
    /// `noeudMatter` de Maison (au moins un) ; a egalite, la plus petite.
    public func fabriqueApple(appareils: [Appareil]) -> String? {
        let connus = Set(maison?.accessoires.compactMap { $0.noeudMatter?.uppercased() } ?? [])
        guard !connus.isEmpty else { return nil }
        var scores: [String: Int] = [:]
        for a in appareils {
            for i in a.instances where connus.contains(i.noeud) { scores[i.fabrique, default: 0] += 1 }
        }
        return scores.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }

    /// Accessoire de Maison d'un appareil (par son noeud sur la fabrique d'Apple).
    public func accessoire(de a: Appareil, fabriqueApple f: String?) -> AccessoireMaison? {
        guard let f, let maison, let noeud = a.instances.first(where: { $0.fabrique == f })?.noeud else { return nil }
        return maison.accessoires.first { $0.noeudMatter?.uppercased() == noeud }
    }

    public func nom(appareil a: Appareil, fabriqueApple f: String?) -> String {
        if let s = surnoms[a.id], !s.isEmpty { return s }
        if let m = accessoire(de: a, fabriqueApple: f)?.nom, !m.isEmpty { return m }
        if let h = a.hap?.nom, !h.isEmpty { return h }
        return a.id
    }

    public func nom(routeur r: RouteurBordure) -> String {
        if let s = surnoms[r.instance], !s.isEmpty { return s }
        return r.instance
    }
}

/// Surnoms donnes dans l'app ("Renommer..."), gardes dans un fichier JSON.
public enum Surnoms {
    /// Vide si le fichier manque ou est illisible.
    public static func lire(_ url: URL) -> [String: String] {
        guard let d = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return s
    }

    public static func ecrire(_ surnoms: [String: String], dans url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        try e.encode(surnoms).write(to: url, options: .atomic)
    }
}
```

`MaillageCoeur/Demo/NomsDemo.swift` (noms inventés, sur les vrais nœuds du relevé) :

```swift
import Foundation

/// Noms de Maison du mode demo : inventes (ce ne sont pas les vrais noms de la
/// maison), attaches aux vrais noeuds du releve du 28/09 sur la fabrique
/// 30FC8F95E0E1A385, qui joue la fabrique d'Apple.
public enum NomsDemo {
    public static let fabrique = "30FC8F95E0E1A385"

    /// Hote -> (nom, piece, fabricant, modele, categorie).
    static let table: [String: (String, String, String, String, String)] = [
        "56B1E064401F74EF": ("Halo", "Bureau", "Djoko-CLI", "Pont ScreenBar Halo", "Ampoule"),
        "86E7BD1A75F28E6D": ("Nuki Ultra", "Entrée", "Nuki", "Smart Lock Ultra", "Serrure"),
        "02A8C3C5600F136B": ("Eve Door", "Entrée", "Eve Systems", "Eve Door & Window", "Capteur"),
        "3A5DFAFCAB581AAF": ("Eve Motion", "Couloir", "Eve Systems", "Eve Motion", "Capteur"),
        "C656F369B620027F": ("Thermo salon", "Salon", "Eve Systems", "Eve Thermo", "Thermostat"),
        "D661EE20B3E97C66": ("Thermo chambre", "Chambre", "Eve Systems", "Eve Thermo", "Thermostat"),
        "DAEF22ACB58F651C": ("Météo terrasse", "Terrasse", "Eve Systems", "Eve Weather", "Capteur"),
        "0A84D1254BD246AD": ("Capteur salon", "Salon", "Aqara", "Climate Sensor W100", "Capteur"),
        "327DF9C45C82BBD6": ("Détecteur couloir", "Couloir", "Aqara", "Motion Sensor P2", "Capteur"),
        "462DA5B311AFFCC7": ("Fenêtre chambre", "Chambre", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "7A3D0C7512F8E0A5": ("Capteur salle de bain", "Salle de bain", "Aqara", "Climate Sensor W100", "Capteur"),
        "8A7E6F2665F737C6": ("Porte-fenêtre", "Salon", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "9A5C1F9FDFAB242D": ("Fumée cuisine", "Cuisine", "Aqara", "Smoke Detector", "Capteur"),
        "AA3D322B8A4500C4": ("Bouton chevet", "Chambre", "Aqara", "Wireless Mini Switch", "Interrupteur"),
        "C663573E49A1EC90": ("Capteur bureau", "Bureau", "Aqara", "Climate Sensor W100", "Capteur"),
        "46F77B36E071F8D0": ("Prise bureau", "Bureau", "Eve Systems", "Eve Energy", "Prise"),
        "7AF0B6D5006CF95F": ("Prise salon", "Salon", "Eve Systems", "Eve Energy", "Prise"),
        "82570DF21CF3784B": ("Volet chambre", "Chambre", "Nanoleaf", "Blinds", "Store"),
        "724CC16B32D8F820": ("Volet salon", "Salon", "Nanoleaf", "Blinds", "Store"),
        "9A28601B74FF90A7": ("Lampe chevet", "Chambre", "Nanoleaf", "Essentials A19", "Ampoule"),
        "D6ECDD6EF9C0CB0C": ("Interrupteur cuisine", "Cuisine", "Eve Systems", "Eve Light Switch", "Interrupteur"),
        "FA15027BC681BB16": ("Ampoule entrée", "Entrée", "Nanoleaf", "Essentials A19", "Ampoule"),
        "C4299622387B": ("Passerelle salon", "Salon", "Eve Systems", "Eve Play", "Pont"),
        "C4E7AE91A29B": ("Prise Wi-Fi bureau", "Bureau", "Meross", "Smart Plug", "Prise"),
    ]

    public static let maison: NomsMaison = {
        var accessoires: [AccessoireMaison] = []
        for s in Releve20260928.annonces.matter {
            guard let i = InstanceMatter(instance: s.instance), i.fabrique == fabrique,
                  let hote = s.hote, let e = table[Instantane.idAppareil(hote: hote, instance: s.instance)] else { continue }
            accessoires.append(AccessoireMaison(nom: e.0, piece: e.1, fabricant: e.2, modele: e.3,
                                                categorie: e.4, noeudMatter: i.noeud))
        }
        return NomsMaison(date: Releve20260928.annonces.date, domicile: "Maison (démo)",
                          accessoires: accessoires.sorted { $0.nom < $1.nom })
    }()
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageCoeurTests/NomsTests`
Expected: PASS, `✔ Test run with 4 tests in 1 suite passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Noms MaillageCoeur/Demo/NomsDemo.swift MaillageCoeurTests/NomsTests.swift
git commit -m "Nommer les noeuds : surnoms, contrat de noms.json, fabrique d'Apple

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Suivi et événements du journal

**Files:**
- Create: `MaillageCoeur/Suivi/Evenement.swift`, `MaillageCoeur/Suivi/MemoireAnnonces.swift`, `MaillageCoeur/Suivi/Suivi.swift`
- Test: `MaillageCoeurTests/SuiviTests.swift`

**Interfaces:**
- Consumes: `Annonces`, `Instantane`, `ResolveurNoms`, `Banc` (tests).
- Produces: `TypeEvenement` (18 cas, `gravite` par défaut) ; `Gravite` (`info` < `attention` < `alerte`) ; `Sujet(id:nom:)` ; `Evenement(date:type:gravite:reseau:sujet:avant:apres:periode:constate:details:)` (Codable tolérant, `id`) ; `MemoireAnnonces` (interne : `sursis = 120`, `completer(_:)`, `abandons`, `adressesAbandonnees`) ; `Suivi` (`init()`, `integrer(_:noms:) -> [Evenement]`, `noterVeille(_: DateInterval) -> [Evenement]`, `instantane`, `disparus: [String: Appareil]`, `dernieresPartitions: [String: String]`, `Suivi.apresReveil = 240`).

- [ ] **Step 1: Écrire le test**

`MaillageCoeurTests/SuiviTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Suivi : evenements du journal")
struct SuiviTests {
    static let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    static let a1 = "AAAA000000000001"
    static let a2 = "AAAA000000000002"

    /// Reseau de base : un chef, un routeur, deux appareils dans fd19.
    static func banc(_ date: Date) -> Banc {
        var b = Banc(date: date)
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Second", lien: "fe80::2")
        b.route("fd19:961f:2db3::/64", via: "fe80::1")
        b.appareil(a1, noeud: 1, adresses: ["fd19:961f:2db3::11"])
        b.appareil(a2, noeud: 2, adresses: ["fd19:961f:2db3::12"], sii: 6000)
        return b
    }

    static func demarre() -> Suivi {
        var s = Suivi()
        _ = s.integrer(banc(t0).annonces)
        return s
    }

    @Test func lancement() {
        var s = Suivi()
        let ev = s.integrer(Self.banc(Self.t0).annonces)
        #expect(ev.map(\.type) == [.surveillanceDemarree])
        #expect(ev.first?.details == ["routeurs": "2", "appareils": "2"])
        #expect(ev.first?.gravite == .info)
        #expect(s.integrer(Self.banc(Self.t0 + 60).annonces).isEmpty, "rien n'a change")
        #expect(s.dernieresPartitions[Self.a1] == "73586B68")
    }

    @Test func lancementSurUnReseauScinde() throws {
        var b = Self.banc(Self.t0)
        b.routeur("Isole", partition: "E2E79FFC", role: nil, primaire: true, lien: "fe80::3")
        var s = Suivi()
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.surveillanceDemarree, .reseauScinde])
        let scission = try #require(ev.last)
        #expect(scission.constate)
        #expect(scission.gravite == .alerte)
        #expect(scission.details["E2E79FFC"] == "Isole")
        #expect(scission.details["73586B68"] == "Chef, Second")
    }

    @Test func disparitionConfirmeeApresDeuxMinutes() throws {
        var s = Self.demarre()
        var b = Self.banc(Self.t0 + 60)
        b.retirer(Self.a2)
        #expect(s.integrer(b.annonces).isEmpty, "absence constatee, pas encore retenue")
        b.date = Self.t0 + 120
        #expect(s.integrer(b.annonces).isEmpty, "60 s d'absence")
        b.date = Self.t0 + 180
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.appareilDisparu])
        let e = try #require(ev.first)
        #expect(e.date == Self.t0 + 60, "datee de la premiere absence")
        #expect(e.sujet == Sujet(id: Self.a2, nom: Self.a2))
        #expect(e.avant == "73586B68")
        #expect(e.gravite == .attention)
        #expect(Array(s.disparus.keys) == [Self.a2])

        let retour = s.integrer(Self.banc(Self.t0 + 240).annonces)
        #expect(retour.map(\.type) == [.appareilRevenu])
        #expect(s.disparus.isEmpty)
    }

    @Test func retourAvantConfirmation() {
        var s = Self.demarre()
        var b = Self.banc(Self.t0 + 60)
        b.retirer(Self.a2)
        #expect(s.integrer(b.annonces).isEmpty)
        #expect(s.instantane?.appareil(Self.a2)?.etat == .joignable, "en sursis : toujours la")
        #expect(s.integrer(Self.banc(Self.t0 + 120).annonces).isEmpty)
        #expect(s.integrer(Self.banc(Self.t0 + 300).annonces).isEmpty, "le sursis a ete leve")
    }

    @Test func sansAdresse() throws {
        var s = Self.demarre()
        var b = Self.banc(Self.t0 + 60)
        b.adresses[Self.a2 + ".local"] = []
        #expect(s.integrer(b.annonces).isEmpty)
        b.date = Self.t0 + 180
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.appareilSansAdresse])
        #expect(ev.first?.date == Self.t0 + 60)
        #expect(s.instantane?.appareil(Self.a2)?.etat == .sansAdresse)
        #expect(s.dernieresPartitions[Self.a2] == "73586B68", "derniere partition connue gardee")
        #expect(s.integrer(Self.banc(Self.t0 + 240).annonces).map(\.type) == [.appareilRevenu])
    }

    @Test func routeurs() throws {
        var s = Self.demarre()
        // Nouvelle adresse de lien du chef (redemarrage probable), la route suit.
        var b = Self.banc(Self.t0 + 60)
        b.adresses["Chef.local"] = ["fe80::a"]
        b.routes = [RouteIPv6(prefixe: "fd19:961f:2db3::/64", passerelle: "fe80::a")]
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.routeurNouvelleAdresseLien])
        #expect(ev.first?.avant == "fe80::1")
        #expect(ev.first?.apres == "fe80::a")

        // Le second disparait : alerte, datee de la premiere absence.
        b.routeurs.removeAll { $0.instance == "Second" }
        b.date = Self.t0 + 120
        #expect(s.integrer(b.annonces).isEmpty)
        b.date = Self.t0 + 240
        let d = s.integrer(b.annonces)
        #expect(d.map(\.type) == [.routeurDisparu])
        #expect(d.first?.gravite == .alerte)
        #expect(d.first?.date == Self.t0 + 120)

        // Il revient.
        var c = Self.banc(Self.t0 + 300)
        c.adresses["Chef.local"] = ["fe80::a"]
        c.routes = b.routes
        #expect(s.integrer(c.annonces).map(\.type) == [.routeurApparu])
    }

    @Test func roleEtChef() {
        var s = Self.demarre()
        var b = Banc(date: Self.t0 + 60)
        b.routeur("Chef", role: .routeur, primaire: true, lien: "fe80::1")
        b.routeur("Second", role: .chef, lien: "fe80::2")
        b.route("fd19:961f:2db3::/64", via: "fe80::1")
        b.appareil(Self.a1, noeud: 1, adresses: ["fd19:961f:2db3::11"])
        b.appareil(Self.a2, noeud: 2, adresses: ["fd19:961f:2db3::12"], sii: 6000)
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.chefChange, .routeurRoleChange, .routeurRoleChange])
        #expect(ev.first?.avant == "Chef")
        #expect(ev.first?.apres == "Second")
    }

    @Test func scissionEtReunion() throws {
        var s = Self.demarre()
        var b = Banc(date: Self.t0 + 60)
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Second", partition: "E2E79FFC", role: .chef, primaire: true, lien: "fe80::2")
        b.route("fd19:961f:2db3::/64", via: "fe80::1")
        b.appareil(Self.a1, noeud: 1, adresses: ["fd19:961f:2db3::11"])
        b.appareil(Self.a2, noeud: 2, adresses: ["fd19:961f:2db3::12"], sii: 6000)
        let ev = s.integrer(b.annonces)
        let scission = try #require(ev.first)
        #expect(scission.type == .reseauScinde)
        #expect(scission.avant == "1")
        #expect(scission.apres == "2")
        #expect(!scission.constate)
        #expect(scission.details["E2E79FFC"] == "Second")
        #expect(s.integrer(Self.banc(Self.t0 + 120).annonces).map(\.type) == [.reseauReuni, .routeurRoleChange],
                "le chef de la partition isolee redevient simple routeur")
    }

    @Test func changementDePartitionEtPrefixes() throws {
        var s = Self.demarre()
        var b = Banc(date: Self.t0 + 60)
        b.routeur("Chef", role: .chef, primaire: true, lien: "fe80::1")
        b.routeur("Second", role: .routeur, lien: "fe80::2")
        b.routeur("Isole", partition: "E2E79FFC", role: nil, primaire: true, lien: "fe80::3",
                  omr: "fd03:54f0:5de:1::/64")
        b.route("fd19:961f:2db3::/64", via: "fe80::1")
        b.appareil(Self.a1, noeud: 1, adresses: ["fd19:961f:2db3::11"])
        b.appareil(Self.a2, noeud: 2, adresses: ["fd03:54f0:5de:1::12"], sii: 6000)
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.reseauScinde, .routeurApparu, .prefixeNouveau, .appareilChangePartition])
        let change = try #require(ev.last)
        #expect(change.avant == "73586B68")
        #expect(change.apres == "E2E79FFC")
        #expect(change.details["coupee"] == "oui")
        #expect(change.gravite == .attention)
        #expect(ev[2].sujet?.id == "fd03:54f0:5de:1::/64")
    }

    @Test func veilleDuMac() throws {
        var s = Self.demarre()
        let veille = DateInterval(start: Self.t0 + 60, end: Self.t0 + 6 * 3600)
        let v = s.noterVeille(veille)
        #expect(v.map(\.type) == [.veille])
        #expect(v.first?.date == veille.end)
        #expect(v.first?.periode == veille)

        var b = Self.banc(veille.end + 10)
        b.retirer(Self.a2)
        #expect(s.integrer(b.annonces).isEmpty)
        b.date = veille.end + 130
        let ev = s.integrer(b.annonces)
        #expect(ev.map(\.type) == [.appareilDisparu])
        #expect(ev.first?.periode == veille, "pendant la veille, pas au reveil")

        // Loin du reveil : datation normale.
        var c = Self.banc(veille.end + 600)
        c.retirer(Self.a1)
        c.retirer(Self.a2)
        _ = s.integrer(c.annonces)
        c.date = veille.end + 720
        let tard = s.integrer(c.annonces)
        #expect(tard.map(\.type) == [.appareilDisparu])
        #expect(tard.first?.periode == nil)
        #expect(tard.first?.date == veille.end + 600)
    }

    @Test func formatJSON() throws {
        let e = Evenement(date: Self.t0, type: .reseauScinde, reseau: "4B36A2B7FEFB200B",
                          sujet: Sujet(id: "4B36A2B7FEFB200B", nom: "MyHome1482620090"), avant: "1", apres: "2",
                          periode: DateInterval(start: Self.t0 - 60, end: Self.t0), constate: true,
                          details: ["E2E79FFC": "Aqara HubM100 #DFEB"])
        let json = try CodageJSON.encodeur().encode(e)
        #expect(try CodageJSON.decodeur().decode(Evenement.self, from: json) == e)
        let ancien = Data(#"{"date":"2026-09-27T00:14:00Z","type":"appareilDisparu"}"#.utf8)
        let lu = try CodageJSON.decodeur().decode(Evenement.self, from: ancien)
        #expect(lu.gravite == .attention && !lu.constate && lu.details.isEmpty, "champs manquants : valeurs par defaut")
        #expect(e.id == "1790000000000-reseauScinde-4B36A2B7FEFB200B")
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/SuiviTests`
Expected: FAIL à la compilation (`cannot find 'Suivi' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageCoeur/Suivi/Evenement.swift` :

```swift
import Foundation

/// Nature d'un evenement du journal.
public enum TypeEvenement: String, Codable, Hashable, Sendable, CaseIterable {
    // Surveillance
    case surveillanceDemarree, veille
    // Reseau
    case reseauScinde, reseauReuni, chefChange, bbrPrimaireChange, jeuActifChange
    // Routeurs de bordure
    case routeurApparu, routeurDisparu, routeurRoleChange, routeurNouvelleAdresseLien
    // Prefixes OMR
    case prefixeNouveau, prefixeRetire
    // Appareils
    case appareilNouveau, appareilDisparu, appareilRevenu, appareilSansAdresse, appareilChangePartition

    /// Gravite par defaut.
    public var gravite: Gravite {
        switch self {
        case .reseauScinde, .routeurDisparu:
            .alerte
        case .chefChange, .jeuActifChange, .routeurNouvelleAdresseLien, .prefixeRetire,
             .appareilDisparu, .appareilSansAdresse, .appareilChangePartition:
            .attention
        default:
            .info
        }
    }
}

public enum Gravite: String, Codable, Hashable, Sendable, CaseIterable, Comparable {
    case info, attention, alerte

    var rang: Int {
        switch self {
        case .info: 0
        case .attention: 1
        case .alerte: 2
        }
    }

    public static func < (a: Gravite, b: Gravite) -> Bool { a.rang < b.rang }
}

/// Ce dont parle un evenement : identifiant et nom affiche a ce moment.
public struct Sujet: Codable, Hashable, Sendable {
    /// Instance d'un routeur, identifiant d'un appareil, `xp` d'un reseau, texte d'un prefixe.
    public var id: String
    public var nom: String

    public init(id: String, nom: String) {
        self.id = id
        self.nom = nom
    }
}

/// Evenement du journal (une ligne JSON par evenement).
public struct Evenement: Codable, Hashable, Sendable, Identifiable {
    /// Moment du changement (premiere absence pour une disparition).
    public var date: Date
    public var type: TypeEvenement
    public var gravite: Gravite
    /// `xp` du reseau concerne.
    public var reseau: String?
    public var sujet: Sujet?
    public var avant: String?
    public var apres: String?
    /// Date incertaine : le changement a eu lieu pendant cette periode (veille du Mac).
    public var periode: DateInterval?
    /// Etat trouve au lancement, pas un changement observe.
    public var constate: Bool
    /// Complements ("routeurs": "6", partition -> routeurs, "coupee": "oui"...).
    public var details: [String: String]

    public init(date: Date, type: TypeEvenement, gravite: Gravite? = nil, reseau: String? = nil,
                sujet: Sujet? = nil, avant: String? = nil, apres: String? = nil, periode: DateInterval? = nil,
                constate: Bool = false, details: [String: String] = [:]) {
        self.date = date
        self.type = type
        self.gravite = gravite ?? type.gravite
        self.reseau = reseau
        self.sujet = sujet
        self.avant = avant
        self.apres = apres
        self.periode = periode
        self.constate = constate
        self.details = details
    }

    public var id: String {
        "\(Int64((date.timeIntervalSince1970 * 1000).rounded()))-\(type.rawValue)-\(sujet?.id ?? reseau ?? "")"
    }

    enum CodingKeys: String, CodingKey {
        case date, type, gravite, reseau, sujet, avant, apres, periode, constate, details
    }

    /// Lecture tolerante : `gravite`, `constate` et `details` peuvent manquer.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        type = try c.decode(TypeEvenement.self, forKey: .type)
        gravite = try c.decodeIfPresent(Gravite.self, forKey: .gravite) ?? type.gravite
        reseau = try c.decodeIfPresent(String.self, forKey: .reseau)
        sujet = try c.decodeIfPresent(Sujet.self, forKey: .sujet)
        avant = try c.decodeIfPresent(String.self, forKey: .avant)
        apres = try c.decodeIfPresent(String.self, forKey: .apres)
        periode = try c.decodeIfPresent(DateInterval.self, forKey: .periode)
        constate = try c.decodeIfPresent(Bool.self, forKey: .constate) ?? false
        details = try c.decodeIfPresent([String: String].self, forKey: .details) ?? [:]
    }
}
```

`MaillageCoeur/Suivi/MemoireAnnonces.swift` :

```swift
import Foundation

/// Garde un temps ce qui manque a un releve : un service absent reste present
/// `sursis` secondes avec ses derniers champs ; passe ce delai, il est
/// abandonne et la date de sa premiere absence est gardee. De meme pour les
/// adresses d'un hote qui ne se resolvent plus. Une absence n'est donc retenue
/// que si elle dure (anti-fausses alertes).
struct MemoireAnnonces: Sendable {
    static let sursis: TimeInterval = 120

    enum Famille: String, Hashable, Sendable {
        case routeur, matter, hap
    }

    struct Cle: Hashable, Sendable {
        let famille: Famille
        let instance: String
    }

    private var services: [Cle: AnnonceService] = [:]
    private var absences: [Cle: Date] = [:]
    private var adresses: [String: [String]] = [:]
    private var absencesAdresses: [String: Date] = [:]
    /// Services abandonnes au dernier releve -> date de leur premiere absence.
    private(set) var abandons: [Cle: Date] = [:]
    /// Hotes dont les adresses ont ete abandonnees au dernier releve -> premiere absence.
    private(set) var adressesAbandonnees: [String: Date] = [:]

    /// Le releve, complete de ce qui est encore en sursis.
    mutating func completer(_ releve: Annonces) -> Annonces {
        abandons = [:]
        adressesAbandonnees = [:]
        var sortie = releve
        let presents = Self.services(de: releve)
        for (cle, s) in presents {
            services[cle] = s
            absences[cle] = nil
        }
        let absents = services.filter { presents[$0.key] == nil }
            .sorted { ($0.key.famille.rawValue, $0.key.instance) < ($1.key.famille.rawValue, $1.key.instance) }
        for (cle, s) in absents {
            let debut = absences[cle] ?? releve.date
            if releve.date.timeIntervalSince(debut) >= Self.sursis {
                abandons[cle] = debut
                services[cle] = nil
                absences[cle] = nil
            } else {
                absences[cle] = debut
                switch cle.famille {
                case .routeur: sortie.routeurs.append(s)
                case .matter: sortie.matter.append(s)
                case .hap: sortie.hap.append(s)
                }
            }
        }

        // Adresses des hotes encore la (vus ou en sursis).
        let hotes = Set((sortie.routeurs + sortie.matter + sortie.hap).compactMap(\.hote))
        for hote in hotes {
            let vues = releve.adresses[hote] ?? []
            if !vues.isEmpty {
                adresses[hote] = vues
                absencesAdresses[hote] = nil
            } else if let anciennes = adresses[hote] {
                let debut = absencesAdresses[hote] ?? releve.date
                if releve.date.timeIntervalSince(debut) >= Self.sursis {
                    adressesAbandonnees[hote] = debut
                    adresses[hote] = nil
                    absencesAdresses[hote] = nil
                    sortie.adresses[hote] = []
                } else {
                    absencesAdresses[hote] = debut
                    sortie.adresses[hote] = anciennes
                }
            }
        }
        for hote in adresses.keys where !hotes.contains(hote) {
            adresses[hote] = nil
            absencesAdresses[hote] = nil
        }
        return sortie
    }

    static func services(de a: Annonces) -> [Cle: AnnonceService] {
        var r: [Cle: AnnonceService] = [:]
        for s in a.routeurs { r[Cle(famille: .routeur, instance: s.instance)] = s }
        for s in a.matter { r[Cle(famille: .matter, instance: s.instance)] = s }
        for s in a.hap { r[Cle(famille: .hap, instance: s.instance)] = s }
        return r
    }
}
```

`MaillageCoeur/Suivi/Suivi.swift` :

```swift
import Foundation

/// Suit le reseau de releve en releve et en tire les evenements du journal.
///
/// - Au premier releve : un seul point de depart (`surveillanceDemarree`), et
///   une scission deja la est notee comme constatee, sans autre comparaison.
/// - Ensuite : differences entre deux instantanes. Une absence (service ou
///   adresses) n'est retenue qu'apres 2 min (`MemoireAnnonces`) et datee de la
///   premiere absence.
/// - Apres une veille du Mac, ce qui est constate dans les 4 min qui suivent le
///   reveil est date de la veille (`periode`), jamais du reveil.
public struct Suivi: Sendable {
    public static let apresReveil: TimeInterval = 240

    public private(set) var instantane: Instantane?
    /// Appareils disparus depuis le lancement (dernier etat connu), jusqu'a leur retour.
    public private(set) var disparus: [String: Appareil] = [:]
    /// Derniere partition connue de chaque appareil (pour placer un appareil sans adresse ou disparu).
    public private(set) var dernieresPartitions: [String: String] = [:]
    private var memoire = MemoireAnnonces()
    private var derniereVeille: DateInterval?

    public init() {}

    /// Note une veille du Mac et rend son evenement.
    public mutating func noterVeille(_ periode: DateInterval) -> [Evenement] {
        derniereVeille = periode
        return [Evenement(date: periode.end, type: .veille, periode: periode)]
    }

    /// Integre un releve et rend les evenements qu'il fait apparaitre.
    public mutating func integrer(_ releve: Annonces, noms: ResolveurNoms = ResolveurNoms()) -> [Evenement] {
        let nouveau = Instantane(annonces: memoire.completer(releve))
        let date = releve.date
        var ev: [Evenement] = []
        if let ancien = instantane {
            let fabrique = noms.fabriqueApple(appareils: nouveau.appareils + nouveau.appareilsIP + ancien.appareils)
            ev += Self.evenementsReseaux(ancien, nouveau, date, noms)
            ev += evenementsRouteurs(ancien, nouveau, date, noms)
            ev += Self.evenementsPrefixes(ancien, nouveau, date)
            ev += evenementsAppareils(ancien, nouveau, date, noms, fabrique)
        } else {
            ev.append(Evenement(date: date, type: .surveillanceDemarree,
                                details: ["routeurs": String(nouveau.routeurs.count),
                                          "appareils": String(nouveau.appareils.count)]))
            for r in nouveau.reseaux where r.estScinde {
                ev.append(Evenement(date: date, type: .reseauScinde, reseau: r.id, sujet: Sujet(id: r.id, nom: r.nom),
                                    apres: String(r.partitions.count), constate: true,
                                    details: Self.detailsPartitions(r, noms)))
            }
        }
        instantane = nouveau
        for a in nouveau.appareils {
            if let p = a.partition { dernieresPartitions[a.id] = p }
        }
        return ev.map(dater)
    }

    /// Partition -> noms de ses routeurs, pour dire qui est isole.
    static func detailsPartitions(_ r: Reseau, _ noms: ResolveurNoms) -> [String: String] {
        Dictionary(r.partitions.map { ($0.id, $0.routeurs.map { noms.nom(routeur: $0) }.joined(separator: ", ")) },
                   uniquingKeysWith: { a, _ in a })
    }

    static func evenementsReseaux(_ ancien: Instantane, _ nouveau: Instantane, _ date: Date,
                                  _ noms: ResolveurNoms) -> [Evenement] {
        var ev: [Evenement] = []
        for r in nouveau.reseaux {
            guard let a = ancien.reseau(r.id) else { continue }
            let s = Sujet(id: r.id, nom: r.nom)
            if r.estScinde && r.partitions.count > a.partitions.count {
                ev.append(Evenement(date: date, type: .reseauScinde, reseau: r.id, sujet: s,
                                    avant: String(a.partitions.count), apres: String(r.partitions.count),
                                    details: detailsPartitions(r, noms)))
            } else if r.partitions.count < a.partitions.count {
                ev.append(Evenement(date: date, type: .reseauReuni, reseau: r.id, sujet: s,
                                    avant: String(a.partitions.count), apres: String(r.partitions.count)))
            }
            if let c1 = a.principale?.chef, let c2 = r.principale?.chef, c1.instance != c2.instance {
                ev.append(Evenement(date: date, type: .chefChange, reseau: r.id, sujet: s,
                                    avant: noms.nom(routeur: c1), apres: noms.nom(routeur: c2)))
            }
            if let b1 = a.principale?.bbrPrimaire, let b2 = r.principale?.bbrPrimaire, b1.instance != b2.instance {
                ev.append(Evenement(date: date, type: .bbrPrimaireChange, reseau: r.id, sujet: s,
                                    avant: noms.nom(routeur: b1), apres: noms.nom(routeur: b2)))
            }
            if let j1 = a.routeurs.compactMap(\.jeuActif).max(), let j2 = r.routeurs.compactMap(\.jeuActif).max(), j1 != j2 {
                ev.append(Evenement(date: date, type: .jeuActifChange, reseau: r.id, sujet: s,
                                    avant: j1.formatted(.iso8601), apres: j2.formatted(.iso8601)))
            }
        }
        return ev
    }

    private func evenementsRouteurs(_ ancien: Instantane, _ nouveau: Instantane, _ date: Date,
                                    _ noms: ResolveurNoms) -> [Evenement] {
        var ev: [Evenement] = []
        let anciens = Dictionary(ancien.routeurs.map { ($0.instance, $0) }, uniquingKeysWith: { a, _ in a })
        let nouveaux = Dictionary(nouveau.routeurs.map { ($0.instance, $0) }, uniquingKeysWith: { a, _ in a })
        for r in nouveau.routeurs {
            let s = Sujet(id: r.instance, nom: noms.nom(routeur: r))
            guard let a = anciens[r.instance] else {
                ev.append(Evenement(date: date, type: .routeurApparu, reseau: r.idReseau, sujet: s, apres: r.partition))
                continue
            }
            if let ra = a.role, let rn = r.role, ra != rn {
                ev.append(Evenement(date: date, type: .routeurRoleChange, reseau: r.idReseau, sujet: s,
                                    avant: ra.rawValue, apres: rn.rawValue))
            }
            let la = Set(a.adressesLien)
            let ln = Set(r.adressesLien)
            if !la.isEmpty && !ln.isEmpty && !ln.isSubset(of: la) {
                ev.append(Evenement(date: date, type: .routeurNouvelleAdresseLien, reseau: r.idReseau, sujet: s,
                                    avant: la.sorted().map(\.description).joined(separator: ", "),
                                    apres: ln.sorted().map(\.description).joined(separator: ", ")))
            }
        }
        for a in ancien.routeurs where nouveaux[a.instance] == nil {
            let debut = memoire.abandons[.init(famille: .routeur, instance: a.instance)] ?? date
            ev.append(Evenement(date: debut, type: .routeurDisparu, reseau: a.idReseau,
                                sujet: Sujet(id: a.instance, nom: noms.nom(routeur: a)), avant: a.partition))
        }
        return ev
    }

    static func evenementsPrefixes(_ ancien: Instantane, _ nouveau: Instantane, _ date: Date) -> [Evenement] {
        let pa = Set(ancien.prefixes)
        let pn = Set(nouveau.prefixes)
        func reseau(_ p: PrefixeIPv6, _ i: Instantane) -> String? { i.reseaux.first { $0.prefixes.contains(p) }?.id }
        return pn.subtracting(pa).sorted().map {
            Evenement(date: date, type: .prefixeNouveau, reseau: reseau($0, nouveau),
                      sujet: Sujet(id: $0.description, nom: $0.description))
        } + pa.subtracting(pn).sorted().map {
            Evenement(date: date, type: .prefixeRetire, reseau: reseau($0, ancien),
                      sujet: Sujet(id: $0.description, nom: $0.description))
        }
    }

    private mutating func evenementsAppareils(_ ancien: Instantane, _ nouveau: Instantane, _ date: Date,
                                              _ noms: ResolveurNoms, _ fabrique: String?) -> [Evenement] {
        var ev: [Evenement] = []
        let anciens = Dictionary(ancien.appareils.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let nouveaux = Dictionary(nouveau.appareils.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for n in nouveau.appareils {
            let s = Sujet(id: n.id, nom: noms.nom(appareil: n, fabriqueApple: fabrique))
            if let a = anciens[n.id] {
                if a.genre != .sansAdresse && n.genre == .sansAdresse {
                    let debut = n.hote.flatMap { memoire.adressesAbandonnees[$0] } ?? date
                    ev.append(Evenement(date: debut, type: .appareilSansAdresse, reseau: a.idReseau, sujet: s,
                                        avant: a.partition))
                } else if a.genre == .sansAdresse && n.genre != .sansAdresse {
                    ev.append(Evenement(date: date, type: .appareilRevenu, reseau: n.idReseau, sujet: s,
                                        apres: n.partition))
                } else if let p1 = a.partition, let p2 = n.partition, p1 != p2 {
                    let coupee = n.etat == .partitionCoupee
                    ev.append(Evenement(date: date, type: .appareilChangePartition, gravite: coupee ? .attention : .info,
                                        reseau: n.idReseau, sujet: s, avant: p1, apres: p2,
                                        details: coupee ? ["coupee": "oui"] : [:]))
                }
            } else if disparus[n.id] != nil {
                disparus[n.id] = nil
                ev.append(Evenement(date: date, type: .appareilRevenu, reseau: n.idReseau, sujet: s, apres: n.partition))
            } else {
                ev.append(Evenement(date: date, type: .appareilNouveau, reseau: n.idReseau, sujet: s, apres: n.partition))
            }
        }
        for a in ancien.appareils where nouveaux[a.id] == nil {
            var dates = a.servicesMatter.compactMap { memoire.abandons[.init(famille: .matter, instance: $0)] }
            if let h = a.hap, let d = memoire.abandons[.init(famille: .hap, instance: h.nom)] { dates.append(d) }
            ev.append(Evenement(date: dates.max() ?? date, type: .appareilDisparu, reseau: a.idReseau,
                                sujet: Sujet(id: a.id, nom: noms.nom(appareil: a, fabriqueApple: fabrique)),
                                avant: a.partition ?? dernieresPartitions[a.id]))
            disparus[a.id] = a
        }
        return ev
    }

    /// Ce qui est constate peu apres un reveil est date de la veille.
    private func dater(_ e: Evenement) -> Evenement {
        guard let v = derniereVeille, e.type != .veille, e.periode == nil,
              e.date >= v.end, e.date <= v.end.addingTimeInterval(Self.apresReveil) else { return e }
        var c = e
        c.periode = v
        return c
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageCoeurTests/SuiviTests`
Expected: PASS, `✔ Test run with 11 tests in 1 suite passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Suivi MaillageCoeurTests/SuiviTests.swift
git commit -m "Suivre le reseau et tirer les evenements du journal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Panne du 27/09 rejouée, regroupement des pertes, alertes

**Files:**
- Create: `MaillageCoeur/Demo/ScenarioPanne.swift`, `MaillageCoeur/Suivi/Regroupement.swift`, `MaillageCoeur/Suivi/Alertes.swift`
- Test: `MaillageCoeurTests/ScenarioPanneTests.swift`

**Interfaces:**
- Consumes: `Releve20260928`, `NomsDemo`, `Suivi`, `Evenement`, `ChampsTXT`.
- Produces: `ScenarioPanne` (`fuseau` Asia/Tbilisi, `date(_:_:_:)`, `debut`, `fin`, `releves: [Annonces]` de 03:55 à 04:30, `annonces(a:)`, `sansAdresse`, `perdus`) ; `LigneJournal` (`.evenement`, `.pertes`, `id`, `date`, `evenements`, `gravite`) ; `Regroupement.fenetre = 600`, `Regroupement.estPerte(_:)`, `Regroupement.lignes(_:) -> [LigneJournal]` (plus récentes d'abord) ; `CategorieAlerte` (`scission`, `routeurDisparu`, `pertes`, `informations`, `parDefaut`) ; `AlerteAEnvoyer(categorie:identifiant:evenements:)` ; `Alertes` (`seuilPertes = 3`, `traiter(_:) -> [AlerteAEnvoyer]`).

- [ ] **Step 1: Écrire le test**

`MaillageCoeurTests/ScenarioPanneTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Panne du 27/09 rejouee")
struct ScenarioPanneTests {
    typealias D = ScenarioPanne

    /// Rejoue le scenario : (date du releve, evenements) a chaque releve.
    static func rejouer() -> (suivi: Suivi, pas: [(Date, [Evenement])]) {
        var s = Suivi()
        let noms = ResolveurNoms(maison: NomsDemo.maison)
        let pas = D.releves.map { a in (a.date, s.integrer(a, noms: noms)) }
        return (s, pas)
    }

    @Test func evenements() {
        let tous = Self.rejouer().pas.flatMap(\.1)
        let attendus: [(TypeEvenement, Date)] = [
            (.surveillanceDemarree, D.date(3, 55)),
            (.routeurNouvelleAdresseLien, D.date(4, 5)),
            (.prefixeNouveau, D.date(4, 5)),
            (.prefixeRetire, D.date(4, 6)),
            (.reseauScinde, D.date(4, 14)),
            (.appareilSansAdresse, D.date(4, 14)),
            (.appareilDisparu, D.date(4, 15)),
            (.appareilDisparu, D.date(4, 16)),
            (.appareilDisparu, D.date(4, 18)),
            (.appareilDisparu, D.date(4, 20)),
        ]
        #expect(tous.map(\.type) == attendus.map(\.0))
        #expect(tous.map(\.date) == attendus.map(\.1))
        #expect(tous.first?.details == ["routeurs": "6", "appareils": "24"])
        #expect(tous[1].sujet?.nom == "Apple TV 4K")
        #expect(tous[2].sujet?.id == "fd19:961f:2db3::/64")
        #expect(tous[3].sujet?.id == "fd4f:9c:ed42::/64")
        #expect(tous[4].details["E2E79FFC"] == "Aqara HubM100 #DFEB")
        #expect(tous[5].sujet?.id == D.sansAdresse)
        #expect(tous.suffix(4).map { $0.sujet?.nom ?? "" }
                == ["Prise bureau", "Prise salon", "Thermo chambre", "Ampoule entrée"], "noms de la demo")
    }

    @Test func detectionApresDeuxMinutes() {
        let pas = Self.rejouer().pas
        let quand = pas.filter { !$0.1.isEmpty }.map(\.0)
        #expect(quand == [D.date(3, 55), D.date(4, 5), D.date(4, 6), D.date(4, 14), D.date(4, 16),
                          D.date(4, 17), D.date(4, 18), D.date(4, 20), D.date(4, 22)])
    }

    @Test func etatFinal() throws {
        let s = Self.rejouer().suivi
        let i = try #require(s.instantane)
        #expect(i.reseaux.first?.partitions.map(\.id) == ["73586B68", "E2E79FFC"])
        #expect(i.appareil(D.sansAdresse)?.etat == .sansAdresse)
        #expect(Set(s.disparus.keys) == Set(D.perdus.map(\.hote)))
        #expect(s.dernieresPartitions["46F77B36E071F8D0"] == "73586B68")
        #expect(i.appareils.filter { $0.etat == .joignable }.count == 19)
    }

    @Test func uneLigneDePertes() throws {
        let lignes = Regroupement.lignes(Self.rejouer().pas.flatMap(\.1))
        #expect(lignes.count == 6)
        guard case .pertes(let pertes) = lignes.first else {
            Issue.record("la ligne la plus recente devrait regrouper les pertes")
            return
        }
        #expect(pertes.count == 5)
        #expect(pertes.first?.date == D.date(4, 14))
        #expect(pertes.last?.date == D.date(4, 20))
        #expect(lignes.first?.date == D.date(4, 20))
        #expect(lignes.first?.gravite == .attention)
        #expect(lignes.map(\.evenements.first?.type) == [.appareilSansAdresse, .reseauScinde, .prefixeRetire,
                                                          .prefixeNouveau, .routeurNouvelleAdresseLien,
                                                          .surveillanceDemarree])
    }

    @Test func notifications() {
        var alertes = Alertes()
        var envoyees: [(Date, AlerteAEnvoyer)] = []
        for (date, ev) in Self.rejouer().pas {
            for a in alertes.traiter(ev) { envoyees.append((date, a)) }
        }
        let importantes = envoyees.filter { $0.1.categorie != .informations }
        #expect(importantes.map(\.1.categorie) == [.scission, .pertes, .pertes, .pertes])
        #expect(importantes.map(\.0) == [D.date(4, 14), D.date(4, 18), D.date(4, 20), D.date(4, 22)])
        #expect(importantes.dropFirst().map(\.1.evenements.count) == [3, 4, 5])
        #expect(Set(importantes.dropFirst().map(\.1.identifiant)).count == 1, "la meme notification, mise a jour")
        #expect(envoyees.filter { $0.1.categorie == .informations }.count == 3)
        #expect(CategorieAlerte.allCases.filter(\.parDefaut) == [.scission, .routeurDisparu, .pertes])
    }

    @Test func regroupementSepareLesFenetres() {
        let t = D.date(4, 0)
        func perte(_ minutes: Double) -> Evenement {
            Evenement(date: t.addingTimeInterval(minutes * 60), type: .appareilDisparu,
                      sujet: Sujet(id: "\(minutes)", nom: "\(minutes)"))
        }
        let lignes = Regroupement.lignes([perte(0), perte(5), perte(12), perte(30), perte(31)])
        #expect(lignes.map(\.evenements.count) == [2, 1, 2], "10 min comptees depuis la premiere perte")
        let isole = Evenement(date: t, type: .appareilChangePartition, details: ["coupee": "oui"])
        #expect(Regroupement.estPerte(isole))
        #expect(!Regroupement.estPerte(Evenement(date: t, type: .appareilChangePartition)))
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/ScenarioPanneTests`
Expected: FAIL à la compilation (`cannot find 'ScenarioPanne' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageCoeur/Demo/ScenarioPanne.swift` :

```swift
import Foundation

/// Panne du 27/09/2026 (heures du Mac, Asia/Tbilisi), reconstituee a partir du releve
/// du 28/09 et du journal de halo-routes, pour les tests et le mode demo :
/// - 03:55 : reseau sain, une partition, prefixe OMR fd4f:9c:ed42::/64 ;
/// - 04:04:03 : l'Apple TV (chef) change d'adresse de lien (redemarrage) et
///   publie fd19:961f:2db3::/64 ; a 04:06 les appareils y passent, fd4f part ;
/// - 04:14 : l'Aqara HubM100 se retrouve seul dans la partition E2E79FFC ;
///   1E5019DAC2638F92 perd son adresse ;
/// - 04:15, 04:16, 04:18, 04:20 : quatre appareils disparaissent.
/// Illustratif : les appareils perdus, leurs heures et l'ancienne adresse de
/// lien de l'Apple TV sont choisis, pas releves.
public enum ScenarioPanne {
    public static let fuseau = TimeZone(secondsFromGMT: 4 * 3600)!

    /// 27/09/2026 a h:m:s, heure du Mac.
    public static func date(_ h: Int, _ m: Int, _ s: Int = 0) -> Date {
        var c = DateComponents(year: 2026, month: 9, day: 27, hour: h, minute: m, second: s)
        c.timeZone = fuseau
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    public static let debut = date(3, 55)
    public static let fin = date(4, 30)

    /// Releves toutes les 60 s, de 03:55 a 04:30.
    public static var releves: [Annonces] {
        (0...35).map { annonces(a: debut.addingTimeInterval(TimeInterval($0) * 60)) }
    }

    public static let sansAdresse = "1E5019DAC2638F92"
    /// Appareils qui disparaissent, et quand.
    public static let perdus: [(hote: String, absentDes: Date)] = [
        ("46F77B36E071F8D0", date(4, 15)), ("7AF0B6D5006CF95F", date(4, 16)),
        ("D661EE20B3E97C66", date(4, 18)), ("FA15027BC681BB16", date(4, 20)),
    ]

    static let lienAncienATV = "fe80::5a:d5f3:dc72:c700"
    static let lienATV = "fe80::5a:d5f3:dc72:e7d6"
    static let lienHomePodMiniBureau = "fe80::e14:1eca:d086:9a92"
    static let lienHomePodGauche = "fe80::ae:f065:37ea:3d33"
    static let lienAqara = "fe80::56ef:44ff:fe97:b882"
    static let fd4f = "fd4f:9c:ed42:0:"
    static let fd19 = "fd19:961f:2db3:0:"

    public static func annonces(a t: Date) -> Annonces {
        var a = Releve20260928.annonces
        a.date = t
        a.note = "Scénario reconstitué de la panne du 27/09/2026."
        let redemarrage = date(4, 4, 3)
        let bascule = date(4, 6)
        let scission = date(4, 14)
        let prefixe = t < bascule ? fd4f : fd19

        // Routeurs : adresse de lien de l'Apple TV, partition et etat de l'Aqara.
        let ancienLien = t < redemarrage ? lienAncienATV : lienATV
        a.adresses["Apple-TV-4K.local"] = a.adresses["Apple-TV-4K.local"]?.map { $0 == lienATV ? ancienLien : $0 }
        a.adresses["HomePod-mini-bureau.local"] = a.adresses["HomePod-mini-bureau.local"]?
            .map { $0.hasPrefix("fe80::") ? lienHomePodMiniBureau : $0 }
        if t < scission, let i = a.routeurs.firstIndex(where: { $0.instance == "Aqara HubM100 #DFEB" }) {
            var v = a.routeurs[i].txt.valeurs
            v["pt"] = Data([0x73, 0x58, 0x6B, 0x68])
            v["sb"] = Data([0x00, 0x00, 0x00, 0xB1])   // BBR actif, pas primaire
            a.routeurs[i].txt = ChampsTXT(v)
        }

        // Routes du Mac.
        var routes: [RouteIPv6] = []
        if t < bascule { routes.append(RouteIPv6(prefixe: "fd4f:9c:ed42::/64", passerelle: lienHomePodMiniBureau, interface: "en0")) }
        if t >= redemarrage { routes.append(RouteIPv6(prefixe: "fd19:961f:2db3::/64", passerelle: lienATV, interface: "en0")) }
        routes.append(RouteIPv6(prefixe: "fd03:54f0:5de:1::/64", passerelle: t < scission ? lienHomePodGauche : lienAqara,
                                interface: "en0"))
        a.routes = routes

        // Appareils : prefixe courant, 724C avec son adresse de 00:42, 1E50, perdus.
        a.adresses["724CC16B32D8F820.local"] = [fd19 + "a2b6:12e8:48c5:dee3"]
        a.adresses[sansAdresse + ".local"] = t < scission ? [fd19 + "1e50:19da:c263:8f92"] : []
        for (hote, liste) in a.adresses where !liste.isEmpty {
            a.adresses[hote] = liste.map { $0.hasPrefix(fd19) ? prefixe + $0.dropFirst(fd19.count) : $0 }
        }
        for (hote, absentDes) in perdus where t >= absentDes {
            a.matter.removeAll { $0.hote == hote + ".local" }
            a.adresses[hote + ".local"] = nil
        }
        return a
    }
}
```

`MaillageCoeur/Suivi/Regroupement.swift` :

```swift
import Foundation

/// Ligne du journal affiche : un evenement, ou des pertes regroupees.
public enum LigneJournal: Hashable, Sendable, Identifiable {
    case evenement(Evenement)
    /// Au moins 2 pertes dans une meme fenetre de 10 min, de la plus ancienne a la plus recente.
    case pertes([Evenement])

    public var id: String {
        switch self {
        case .evenement(let e): e.id
        case .pertes(let l): "pertes-" + (l.first?.id ?? "")
        }
    }

    /// Date de l'evenement, ou de la plus recente des pertes.
    public var date: Date {
        switch self {
        case .evenement(let e): e.date
        case .pertes(let l): l.last?.date ?? .distantPast
        }
    }

    public var evenements: [Evenement] {
        switch self {
        case .evenement(let e): [e]
        case .pertes(let l): l
        }
    }

    public var gravite: Gravite { evenements.map(\.gravite).max() ?? .info }
}

/// Regroupement des pertes pour l'affichage (le journal garde chaque evenement).
public enum Regroupement {
    /// Fenetre de regroupement, comptee depuis la premiere perte.
    public static let fenetre: TimeInterval = 600

    /// Perte : un appareil joignable devient sans adresse, disparait, ou passe
    /// dans une partition coupee.
    public static func estPerte(_ e: Evenement) -> Bool {
        switch e.type {
        case .appareilDisparu, .appareilSansAdresse: true
        case .appareilChangePartition: e.details["coupee"] == "oui"
        default: false
        }
    }

    /// Lignes du journal, les plus recentes d'abord : les pertes survenues dans
    /// une meme fenetre de 10 min forment une seule ligne.
    public static func lignes(_ evenements: [Evenement]) -> [LigneJournal] {
        let tries = evenements.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element)
        var lignes: [LigneJournal] = []
        var groupe: [Evenement] = []
        func fermer() {
            if groupe.count >= 2 {
                lignes.append(.pertes(groupe))
            } else if let e = groupe.first {
                lignes.append(.evenement(e))
            }
            groupe = []
        }
        for e in tries {
            if estPerte(e) {
                if let premiere = groupe.first, e.date.timeIntervalSince(premiere.date) >= fenetre { fermer() }
                groupe.append(e)
            } else {
                lignes.append(.evenement(e))
            }
        }
        fermer()
        return lignes.enumerated().sorted { ($0.element.date, $0.offset) > ($1.element.date, $1.offset) }.map(\.element)
    }
}
```

`MaillageCoeur/Suivi/Alertes.swift` :

```swift
import Foundation

/// Categories de notifications (cases des reglages).
public enum CategorieAlerte: String, Codable, Hashable, Sendable, CaseIterable {
    /// Reseau scinde (par defaut : oui).
    case scission
    /// Routeur de bordure disparu (par defaut : oui).
    case routeurDisparu
    /// Au moins 3 appareils perdus en 10 min, une notification groupee (par defaut : oui).
    case pertes
    /// Le reste (par defaut : non).
    case informations

    public var parDefaut: Bool { self != .informations }
}

/// Notification a presenter ; un meme identifiant remplace la precedente.
public struct AlerteAEnvoyer: Hashable, Sendable {
    public var categorie: CategorieAlerte
    public var identifiant: String
    public var evenements: [Evenement]

    public init(categorie: CategorieAlerte, identifiant: String, evenements: [Evenement]) {
        self.categorie = categorie
        self.identifiant = identifiant
        self.evenements = evenements
    }
}

/// Decide des notifications a partir des nouveaux evenements.
public struct Alertes: Sendable {
    public static let seuilPertes = 3

    private var debutFenetre: Date?
    private var pertes: [Evenement] = []

    public init() {}

    public mutating func traiter(_ evenements: [Evenement]) -> [AlerteAEnvoyer] {
        var sortie: [AlerteAEnvoyer] = []
        var pertesModifiees = false
        for e in evenements {
            if Regroupement.estPerte(e) {
                if let d = debutFenetre, abs(e.date.timeIntervalSince(d)) < Regroupement.fenetre {
                    pertes.append(e)
                    debutFenetre = min(d, e.date)
                } else {
                    debutFenetre = e.date
                    pertes = [e]
                }
                pertesModifiees = true
            } else {
                switch e.type {
                case .reseauScinde:
                    sortie.append(AlerteAEnvoyer(categorie: .scission, identifiant: e.id, evenements: [e]))
                case .routeurDisparu:
                    sortie.append(AlerteAEnvoyer(categorie: .routeurDisparu, identifiant: e.id, evenements: [e]))
                case .surveillanceDemarree, .veille:
                    break
                default:
                    sortie.append(AlerteAEnvoyer(categorie: .informations, identifiant: e.id, evenements: [e]))
                }
            }
        }
        if pertesModifiees, let d = debutFenetre, pertes.count >= Self.seuilPertes {
            sortie.append(AlerteAEnvoyer(categorie: .pertes, identifiant: "pertes-\(Int(d.timeIntervalSince1970))",
                                         evenements: pertes.sorted { $0.date < $1.date }))
        }
        return sortie
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageCoeurTests/ScenarioPanneTests`
Expected: PASS, `✔ Test run with 6 tests in 1 suite passed`. Le rejeu donne exactement 10 événements (démarrage 03:55 ; Apple TV nouvelle adresse de lien et nouveau préfixe fd19 à 04:05 ; fd4f retiré à 04:06 ; scission à 04:14 ; 1E50 sans adresse daté 04:14 ; quatre disparitions datées 04:15, 04:16, 04:18, 04:20), une seule ligne « 5 appareils perdus entre 04:14 et 04:20 », et la notification groupée à 3, 4 puis 5 pertes sous le même identifiant.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Demo/ScenarioPanne.swift MaillageCoeur/Suivi/Regroupement.swift MaillageCoeur/Suivi/Alertes.swift MaillageCoeurTests/ScenarioPanneTests.swift
git commit -m "Rejouer la panne du 27/09, regrouper les pertes, decider des alertes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Journal en fichiers mensuels

**Files:**
- Create: `MaillageCoeur/Journal/JournalFichiers.swift`
- Test: `MaillageCoeurTests/JournalTests.swift`

**Interfaces:**
- Consumes: `Evenement`, `CodageJSON`.
- Produces: `JournalFichiers(dossier:calendrier:)` (`conservation` 90 jours, `nomFichier(_:)`, `ajouter(_:) throws`, `lire() throws -> [Evenement]`, `purger(maintenant:) throws -> [String]`, `fichiers()` et `finDuMois(_:)` internes).

- [ ] **Step 1: Écrire le test**

`MaillageCoeurTests/JournalTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Journal en fichiers mensuels")
struct JournalTests {
    static var calendrier: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 4 * 3600)!
        return c
    }

    static func date(_ texte: String) -> Date {
        try! Date(texte, strategy: .iso8601)
    }

    static func dossier() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("journal-\(UUID().uuidString)")
    }

    @Test func ajouterEtLire() throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        let j = JournalFichiers(dossier: d, calendrier: Self.calendrier)
        #expect(try j.lire().isEmpty, "dossier absent")
        let a = Evenement(date: Self.date("2026-09-27T00:14:00Z"), type: .appareilDisparu,
                          sujet: Sujet(id: "46F77B36E071F8D0", nom: "Prise bureau"))
        let b = Evenement(date: Self.date("2026-09-30T21:00:00Z"), type: .veille,
                          periode: DateInterval(start: Self.date("2026-09-30T20:00:00Z"), end: Self.date("2026-09-30T21:00:00Z")))
        let c = Evenement(date: Self.date("2026-09-27T00:10:00Z"), type: .reseauScinde, reseau: "4B36A2B7FEFB200B")
        try j.ajouter([a, b])
        try j.ajouter([c])
        // 30/09 21:00 UTC = 01/10 01:00 a Asia/Tbilisi : fichier d'octobre.
        #expect(try j.fichiers().map(\.lastPathComponent) == ["journal-2026-09.jsonl", "journal-2026-10.jsonl"])
        #expect(try j.lire() == [c, a, b], "tries par date")
        let lignes = try String(contentsOf: d.appendingPathComponent("journal-2026-09.jsonl"), encoding: .utf8)
            .split(separator: "\n")
        #expect(lignes.count == 2, "une ligne par evenement, ajoutees a la fin")
    }

    @Test func ligneIllisibleIgnoree() throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        let j = JournalFichiers(dossier: d, calendrier: Self.calendrier)
        let e = Evenement(date: Self.date("2026-09-27T00:14:00Z"), type: .prefixeNouveau)
        try j.ajouter([e])
        let url = d.appendingPathComponent("journal-2026-09.jsonl")
        let f = try FileHandle(forWritingTo: url)
        try f.seekToEnd()
        try f.write(contentsOf: Data("{pas du json\n".utf8))
        try f.close()
        try Data("autre".utf8).write(to: d.appendingPathComponent("notes.txt"))
        #expect(try j.lire() == [e])
    }

    @Test func purge() throws {
        let d = Self.dossier()
        defer { try? FileManager.default.removeItem(at: d) }
        let j = JournalFichiers(dossier: d, calendrier: Self.calendrier)
        try j.ajouter([Evenement(date: Self.date("2026-09-10T00:00:00Z"), type: .veille),
                       Evenement(date: Self.date("2026-10-10T00:00:00Z"), type: .veille)])
        // Le 05/01/2027 : septembre fini le 01/10 (96 jours), octobre le 01/11 (65 jours).
        let supprimes = try j.purger(maintenant: Self.date("2027-01-05T12:00:00Z"))
        #expect(supprimes == ["journal-2026-09.jsonl"])
        #expect(try j.fichiers().map(\.lastPathComponent) == ["journal-2026-10.jsonl"])
        #expect(j.finDuMois("journal-2026-12.jsonl") == Self.date("2026-12-31T20:00:00Z"), "01/01/2027 00:00 a Asia/Tbilisi")
        #expect(j.finDuMois("autre.jsonl") == nil)
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/JournalTests`
Expected: FAIL à la compilation (`cannot find 'JournalFichiers' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageCoeur/Journal/JournalFichiers.swift` :

```swift
import Foundation

/// Journal sur disque : JSON Lines, un fichier par mois ("journal-2026-09.jsonl",
/// mois du calendrier local), un fichier supprime quand son mois est fini depuis
/// plus de 90 jours.
public struct JournalFichiers: Sendable {
    public static let conservation: TimeInterval = 90 * 24 * 3600

    public let dossier: URL
    public let calendrier: Calendar

    public init(dossier: URL, calendrier: Calendar = .current) {
        self.dossier = dossier
        self.calendrier = calendrier
    }

    /// Nom du fichier du mois d'une date.
    public func nomFichier(_ date: Date) -> String {
        let c = calendrier.dateComponents([.year, .month], from: date)
        return String(format: "journal-%04d-%02d.jsonl", c.year ?? 0, c.month ?? 0)
    }

    /// Ajoute les evenements a la fin du fichier de leur mois.
    public func ajouter(_ evenements: [Evenement]) throws {
        guard !evenements.isEmpty else { return }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let encodeur = CodageJSON.encodeur()
        for (nom, groupe) in Dictionary(grouping: evenements, by: { nomFichier($0.date) }) {
            var donnees = Data()
            for e in groupe {
                donnees.append(try encodeur.encode(e))
                donnees.append(0x0A)
            }
            let url = dossier.appendingPathComponent(nom)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let f = try FileHandle(forWritingTo: url)
            defer { try? f.close() }
            try f.seekToEnd()
            try f.write(contentsOf: donnees)
        }
    }

    /// Tous les evenements gardes, du plus ancien au plus recent ; une ligne
    /// illisible est ignoree.
    public func lire() throws -> [Evenement] {
        let decodeur = CodageJSON.decodeur()
        var tous: [Evenement] = []
        for url in try fichiers() {
            let texte = try String(contentsOf: url, encoding: .utf8)
            for ligne in texte.split(separator: "\n") where !ligne.isEmpty {
                if let e = try? decodeur.decode(Evenement.self, from: Data(ligne.utf8)) { tous.append(e) }
            }
        }
        return tous.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }.map(\.element)
    }

    /// Supprime les fichiers des mois finis depuis plus de 90 jours ; rend leurs noms.
    @discardableResult
    public func purger(maintenant: Date) throws -> [String] {
        var supprimes: [String] = []
        for url in try fichiers() {
            guard let fin = finDuMois(url.lastPathComponent),
                  maintenant.timeIntervalSince(fin) > Self.conservation else { continue }
            try FileManager.default.removeItem(at: url)
            supprimes.append(url.lastPathComponent)
        }
        return supprimes
    }

    /// Fichiers du journal, dans l'ordre des mois.
    func fichiers() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: dossier.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: dossier, includingPropertiesForKeys: nil)
            .filter { finDuMois($0.lastPathComponent) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Debut du mois suivant pour "journal-AAAA-MM.jsonl", nil pour un autre nom.
    func finDuMois(_ nom: String) -> Date? {
        let m = nom.wholeMatch(of: /journal-(\d{4})-(\d{2})\.jsonl/)
        guard let m, let annee = Int(m.output.1), let mois = Int(m.output.2),
              let debut = calendrier.date(from: DateComponents(year: annee, month: mois, day: 1)) else { return nil }
        return calendrier.date(byAdding: .month, value: 1, to: debut)
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageCoeurTests/JournalTests`
Expected: PASS, `✔ Test run with 3 tests in 1 suite passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Journal MaillageCoeurTests/JournalTests.swift
git commit -m "Garder le journal en fichiers JSON Lines mensuels, 90 jours

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Disposition du graphe

**Files:**
- Create: `MaillageCoeur/Disposition/Disposition.swift`
- Test: `MaillageCoeurTests/DispositionTests.swift`

**Interfaces:**
- Consumes: `Reseau`, `Partition`, `PrefixeIPv6`, `Instantane` et `Banc` (tests).
- Produces: `Point2D(_:_:)` (`distance`) ; `EtatAffiche` (`joignable`, `partitionCoupee`, `sansAdresse`, `disparu`, `inconnu`) ; `AppareilAffiche(id:nom:piece:partition:etat:endormi:)` ; `Disposition(reseau:appareils:)` (`zones`, `noeuds`, `liens`, `cadre`, `noeud(_ id:)`, `noeud(a:tolerance:)`, `Disposition.Genre` `centre`/`routeur`/`appareil`, constantes `rayonInterieur` 90, `rayonExterieurMin` 170, `arcAppareil` 36, `marge` 40, `ecart` 60, `rayonZoneSeule` 60).

- [ ] **Step 1: Écrire le test**

`MaillageCoeurTests/DispositionTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Disposition du graphe")
struct DispositionTests {
    static let instantane = Instantane(annonces: Releve20260928.annonces)

    static func affiches(_ i: Instantane) -> [AppareilAffiche] {
        i.appareils.map {
            AppareilAffiche(id: $0.id, nom: $0.id, partition: $0.partition,
                            etat: $0.etat == .sansAdresse ? .sansAdresse : .joignable, endormi: $0.endormi)
        }
    }

    @Test func releveReel() throws {
        let r = try #require(Self.instantane.reseaux.first)
        let d = Disposition(reseau: r, appareils: Self.affiches(Self.instantane))
        #expect(d.zones.map(\.id) == ["73586B68", "E2E79FFC", ""])
        let principale = d.zones[0]
        #expect(principale.centre == Point2D(0, 0))
        #expect(principale.rayon == 210, "22 appareils : anneau de 170, plus la marge")
        #expect(principale.principale)
        #expect(d.zones[1].centre == Point2D(330, 0), "210 + 60 + 60, centree a la hauteur de la principale")
        #expect(d.zones[1].rayon == 60)
        #expect(d.zones[2].centre == Point2D(0, 370), "sous la principale : 210 + 60 + 100")

        let atv = try #require(d.noeud("Apple TV 4K"))
        #expect(atv.genre == .centre)
        #expect(atv.position == Point2D(0, 0))
        let homepods = d.noeuds.filter { $0.genre == .routeur }
        #expect(homepods.count == 4)
        #expect(homepods.allSatisfy { abs($0.position.distance(Point2D(0, 0)) - 90) < 1e-9 })
        #expect(abs(homepods[0].position.x) < 1e-9 && abs(homepods[0].position.y + 90) < 1e-9, "le premier en haut")
        #expect(d.noeud("Aqara HubM100 #DFEB")?.position == Point2D(330, 0))
        let dansPrincipale = d.noeuds.filter { $0.genre == .appareil && $0.zone == "73586B68" }
        #expect(dansPrincipale.count == 22)
        #expect(dansPrincipale.allSatisfy { abs($0.position.distance(Point2D(0, 0)) - 170) < 1e-9 })
        #expect(d.noeuds.filter { $0.zone == "" }.map(\.id).sorted() == ["1E5019DAC2638F92", "724CC16B32D8F820"])
        #expect(d.liens.count == 26, "4 routeurs et 22 appareils vers l'Apple TV")
        #expect(d.liens.allSatisfy { $0.vers == "Apple TV 4K" })
        #expect(d.cadre.min == Point2D(-210, -210))
        #expect(d.cadre.max == Point2D(390, 470))
    }

    @Test func stable() throws {
        let r = try #require(Self.instantane.reseaux.first)
        let apps = Self.affiches(Self.instantane)
        let d1 = Disposition(reseau: r, appareils: apps)
        #expect(Disposition(reseau: r, appareils: apps.reversed()) == d1, "l'ordre d'arrivee ne compte pas")
        // Un appareil disparu reste a sa place.
        var avecDisparu = apps
        let i = try #require(avecDisparu.firstIndex { $0.id == "56B1E064401F74EF" })
        avecDisparu[i].etat = .disparu
        #expect(Disposition(reseau: r, appareils: avecDisparu).noeud("56B1E064401F74EF") == d1.noeud("56B1E064401F74EF"))
    }

    @Test func triParPieceEtNom() throws {
        var b = Banc()
        b.routeur("Chef", role: .chef, lien: "fe80::1")
        let r = try #require(Instantane(annonces: b.annonces).reseaux.first)
        let apps = [
            AppareilAffiche(id: "3", nom: "Zeta", piece: nil, partition: "73586B68", etat: .joignable),
            AppareilAffiche(id: "2", nom: "Beta", piece: "Salon", partition: "73586B68", etat: .joignable),
            AppareilAffiche(id: "1", nom: "Alpha", piece: "Salon", partition: "73586B68", etat: .joignable),
            AppareilAffiche(id: "4", nom: "Gamma", piece: "Bureau", partition: "73586B68", etat: .joignable),
        ]
        let d = Disposition(reseau: r, appareils: apps)
        let ordre = d.noeuds.filter { $0.genre == .appareil }.map(\.id)
        #expect(ordre == ["4", "1", "2", "3"], "Bureau, puis Salon (Alpha, Beta), puis sans piece")
        #expect(d.zones.first?.rayon == 210)
    }

    @Test func clic() throws {
        let r = try #require(Self.instantane.reseaux.first)
        let d = Disposition(reseau: r, appareils: Self.affiches(Self.instantane))
        #expect(d.noeud(a: Point2D(3, 4))?.id == "Apple TV 4K")
        #expect(d.noeud(a: Point2D(1000, 1000)) == nil)
        let halo = try #require(d.noeud("56B1E064401F74EF"))
        #expect(d.noeud(a: Point2D(halo.position.x + 5, halo.position.y))?.id == "56B1E064401F74EF")
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/DispositionTests`
Expected: FAIL à la compilation (`cannot find 'Disposition' in scope`).

- [ ] **Step 3: Écrire le code**

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

    public init(id: String, nom: String, piece: String? = nil, partition: String?, etat: EtatAffiche,
                endormi: Bool = false) {
        self.id = id
        self.nom = nom
        self.piece = piece
        self.partition = partition
        self.etat = etat
        self.endormi = endormi
    }
}

/// Disposition stable du graphe d'un reseau : memes noeuds, memes positions.
/// Une zone par partition (la principale au centre, les autres en colonne a sa
/// droite) ; dans une zone : le centre (chef, sinon BBR primaire), les autres
/// routeurs sur un anneau interieur, les appareils sur un anneau exterieur
/// (tries par piece puis par nom), et un lien de chaque noeud vers le centre
/// (rattachement, pas un lien radio). Les appareils sans partition connue vont
/// dans une zone sans centre, sous la principale.
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
        public var prefixes: [PrefixeIPv6]
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
        public var de: String
        public var vers: String
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

    public init(reseau: Reseau, appareils: [AppareilAffiche]) {
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

        // Rayons, puis centres : la principale en (0, 0), les autres en colonne a droite.
        let rayons = reseau.partitions.map { rayonZone($0.routeurs.count, parZone[$0.id]?.count ?? 0) }
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
            zones.append(Zone(id: p.id, centre: centre, rayon: rayons[k], principale: p.estPrincipale, prefixes: p.prefixes))
            guard let premier = p.routeurs.first else { continue }
            noeuds.append(Noeud(id: premier.instance, genre: .centre, zone: p.id, position: centre, rayon: 22))
            let autres = Array(p.routeurs.dropFirst())
            for (i, r) in autres.enumerated() {
                noeuds.append(Noeud(id: r.instance, genre: .routeur, zone: p.id,
                                    position: Self.surAnneau(centre, Self.rayonInterieur, i, autres.count), rayon: 15))
                liens.append(Lien(de: r.instance, vers: premier.instance))
            }
            let apps = tries(parZone[p.id] ?? [])
            for (j, a) in apps.enumerated() {
                noeuds.append(Noeud(id: a.id, genre: .appareil, zone: p.id,
                                    position: Self.surAnneau(centre, rayonAppareils(apps.count), j, apps.count), rayon: 7))
                liens.append(Lien(de: a.id, vers: premier.instance))
            }
        }

        // Appareils sans partition connue : sous la principale, sans centre.
        let orphelins = tries(parZone[""] ?? [])
        if !orphelins.isEmpty {
            let rAnneau = max(Self.rayonZoneSeule, Double(orphelins.count) * Self.arcAppareil / (2 * .pi))
            let rayon = rAnneau + Self.marge
            let centre = Point2D(0, r0 + Self.ecart + rayon)
            zones.append(Zone(id: "", centre: centre, rayon: rayon, principale: false, prefixes: []))
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

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageCoeurTests/DispositionTests`
Expected: PASS, `✔ Test run with 4 tests in 1 suite passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Disposition MaillageCoeurTests/DispositionTests.swift
git commit -m "Disposer le graphe : zones, anneaux, liens vers le centre

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Table de routage et préfixes du Mac

**Files:**
- Create: `MaillageCoeur/Systeme/TableRoutage.swift`, `MaillageCoeur/Systeme/InterfacesLocales.swift`
- Test: `MaillageCoeurTests/SystemeTests.swift`

**Interfaces:**
- Consumes: `RouteIPv6`, `PrefixeIPv6`, `AdresseIPv6`.
- Produces: `TableRoutage.lire() -> [RouteIPv6]?` (nil si le système refuse) ; `TableRoutage.analyser(_:nomInterface:)` et `longueurMasque(_:debut:fin:)` (internes) ; `InterfacesLocales.prefixes() -> [String]`.

- [ ] **Step 1: Écrire le test**

`MaillageCoeurTests/SystemeTests.swift` :

```swift
import Darwin
import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Systeme : table de routage et prefixes du Mac")
struct SystemeTests {
    /// sockaddr_in6 complet ; `portee` : zone glissee par le noyau dans les octets 2-3.
    static func adresse(_ texte: String, portee: UInt16 = 0) -> [UInt8] {
        var o = [UInt8](repeating: 0, count: 28)
        o[0] = 28
        o[1] = UInt8(AF_INET6)
        o.replaceSubrange(8..<24, with: AdresseIPv6(texte)!.octets)
        if portee != 0 {
            o[10] = UInt8(portee >> 8)
            o[11] = UInt8(portee & 0xFF)
        }
        return o
    }

    /// Masque tronque comme le noyau l'ecrit, complete a 4 octets.
    static func masque(_ bits: Int) -> [UInt8] {
        let n = (bits + 7) / 8
        var o = [UInt8](repeating: 0, count: 8 + n)
        o[0] = UInt8(8 + n)
        for i in 0..<n {
            let reste = bits - 8 * i
            o[8 + i] = reste >= 8 ? 0xFF : UInt8((0xFF << (8 - reste)) & 0xFF)
        }
        return o + [UInt8](repeating: 0, count: (4 - o.count % 4) % 4)
    }

    static func message(drapeaux: Int32, index: UInt16 = 7, adresses: [[UInt8]],
                        bits: Int32 = RTA_DST | RTA_GATEWAY | RTA_NETMASK) -> [UInt8] {
        let corps = adresses.flatMap { $0 }
        var h = rt_msghdr()
        h.rtm_msglen = UInt16(MemoryLayout<rt_msghdr>.size + corps.count)
        h.rtm_version = UInt8(RTM_VERSION)
        h.rtm_type = UInt8(RTM_GET)
        h.rtm_index = index
        h.rtm_flags = drapeaux
        h.rtm_addrs = bits
        return withUnsafeBytes(of: h) { Array($0) } + corps
    }

    @Test func analyse() {
        let passerelle = Self.adresse("fe80::5a:d5f3:dc72:e7d6", portee: 7)
        let tampon = Self.message(drapeaux: RTF_UP | RTF_GATEWAY,
                                  adresses: [Self.adresse("fd19:961f:2db3::"), passerelle, Self.masque(64)])
            + Self.message(drapeaux: RTF_UP | RTF_GATEWAY | RTF_HOST,
                           adresses: [Self.adresse("fd19:961f:2db3::1"), passerelle, Self.masque(128)])
            + Self.message(drapeaux: RTF_UP | RTF_GATEWAY,
                           adresses: [Self.adresse("fd7a:115c:a1e0::"), passerelle, Self.masque(48)])
            + Self.message(drapeaux: RTF_UP,
                           adresses: [Self.adresse("fd4b:36a2:b7fe:200b::"), passerelle, Self.masque(64)])
            + Self.message(drapeaux: RTF_UP | RTF_GATEWAY, index: 9,
                           adresses: [Self.adresse("fd03:54f0:5de:1::"), Self.adresse("fe80::56ef:44ff:fe97:b882", portee: 9),
                                      Self.masque(64)])
        let routes = TableRoutage.analyser(tampon) { "if\($0)" }
        #expect(routes == [
            RouteIPv6(prefixe: "fd19:961f:2db3::/64", passerelle: "fe80::5a:d5f3:dc72:e7d6", interface: "if7"),
            RouteIPv6(prefixe: "fd03:54f0:5de:1::/64", passerelle: "fe80::56ef:44ff:fe97:b882", interface: "if9"),
        ], "hote, /48 et sans passerelle ignores ; zone retiree de l'adresse lien-local")
        #expect(TableRoutage.analyser(Array(tampon.prefix(50))) { _ in nil } == [], "tampon tronque")
        #expect(TableRoutage.longueurMasque([0xFF, 0xFF, 0xF0, 0x00], debut: 0, fin: 4) == 20)
    }

    @Test func tableDuMac() throws {
        // Hors bac a sable (tests du framework) : la table se lit.
        let routes = try #require(TableRoutage.lire())
        for r in routes {
            #expect(PrefixeIPv6(r.prefixe) != nil)
            #expect(r.passerelle.flatMap { AdresseIPv6($0) }?.estLienLocal == true)
        }
        #expect(InterfacesLocales.prefixes().allSatisfy { PrefixeIPv6($0) != nil })
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/SystemeTests`
Expected: FAIL à la compilation (`cannot find 'TableRoutage' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageCoeur/Systeme/TableRoutage.swift` :

```swift
import Darwin

/// Routes IPv6 du Mac (sysctl NET_RT_DUMP) : les prefixes /64 routes par un
/// routeur lien-local, c'est-a-dire les prefixes OMR annonces par les routeurs
/// de bordure (et ceux que pose l'assistant halo-routes).
public enum TableRoutage {
    /// Lit la table ; nil si le systeme refuse (bac a sable) ou echoue.
    public static func lire() -> [RouteIPv6]? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET6, NET_RT_DUMP, 0]
        let n = UInt32(mib.count)
        var taille = 0
        guard sysctl(&mib, n, nil, &taille, nil, 0) == 0, taille > 0 else { return nil }
        var tampon = [UInt8](repeating: 0, count: taille)
        guard sysctl(&mib, n, &tampon, &taille, nil, 0) == 0 else { return nil }
        return analyser(Array(tampon.prefix(taille)), nomInterface: nomInterface)
    }

    static func nomInterface(_ index: UInt16) -> String? {
        var nom = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        guard if_indextoname(UInt32(index), &nom) != nil else { return nil }
        return nom.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    /// Analyse le tampon de NET_RT_DUMP : des messages `rt_msghdr`, chacun suivi
    /// de ses adresses (sockaddr arrondis a 4 octets, dans l'ordre des bits de
    /// `rtm_addrs`). Garde les routes par passerelle, de longueur 64, dont la
    /// passerelle est lien-local ; retire la zone que le noyau glisse dans les
    /// octets 2-3 des adresses lien-local.
    static func analyser(_ o: [UInt8], nomInterface: (UInt16) -> String?) -> [RouteIPv6] {
        var routes: [RouteIPv6] = []
        let tailleEntete = MemoryLayout<rt_msghdr>.size
        var i = 0
        while i + tailleEntete <= o.count {
            let entete = o.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i, as: rt_msghdr.self) }
            let longueur = Int(entete.rtm_msglen)
            guard longueur >= tailleEntete, i + longueur <= o.count else { break }
            let debut = i
            let fin = i + longueur
            i = fin
            guard entete.rtm_flags & RTF_GATEWAY != 0, entete.rtm_flags & RTF_HOST == 0 else { continue }
            var j = debut + tailleEntete
            var destination: [UInt8]?
            var passerelle: [UInt8]?
            var masque = 128
            for bit in 0..<8 where entete.rtm_addrs & (1 << bit) != 0 {
                guard j + 1 < fin else { break }
                let longueurSa = Int(o[j])
                let famille = Int32(o[j + 1])
                switch Int32(1 << bit) {
                case RTA_DST where famille == AF_INET6 && longueurSa >= 24 && j + 24 <= fin:
                    destination = Array(o[(j + 8)..<(j + 24)])
                case RTA_GATEWAY where famille == AF_INET6 && longueurSa >= 24 && j + 24 <= fin:
                    passerelle = Array(o[(j + 8)..<(j + 24)])
                case RTA_NETMASK:
                    masque = longueurMasque(o, debut: j + 8, fin: min(j + longueurSa, j + 24, fin))
                default:
                    break
                }
                j += longueurSa == 0 ? 4 : (longueurSa + 3) & ~3
            }
            guard masque == 64, let d = destination, var g = passerelle,
                  let prefixe = PrefixeIPv6(octets: Array(d[0..<8])) else { continue }
            g[2] = 0
            g[3] = 0
            guard let adresse = AdresseIPv6(octets: g), adresse.estLienLocal else { continue }
            routes.append(RouteIPv6(prefixe: prefixe.description, passerelle: adresse.description,
                                    interface: nomInterface(entete.rtm_index)))
        }
        return routes
    }

    /// Nombre de bits a 1 en tete du masque (octets absents = 0).
    static func longueurMasque(_ o: [UInt8], debut: Int, fin: Int) -> Int {
        var n = 0
        var k = debut
        while k < fin {
            let b = o[k]
            if b == 0xFF {
                n += 8
                k += 1
                continue
            }
            n += (~b).leadingZeroBitCount
            break
        }
        return n
    }
}
```

`MaillageCoeur/Systeme/InterfacesLocales.swift` :

```swift
import Darwin

/// Prefixes du reseau local, vus depuis les interfaces du Mac.
public enum InterfacesLocales {
    /// Prefixes /64 des adresses IPv6 (hors lien-local) des interfaces actives
    /// du Mac, hors boucle locale, tries.
    public static func prefixes() -> [String] {
        var tete: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&tete) == 0, let premiere = tete else { return [] }
        defer { freeifaddrs(tete) }
        var resultat = Set<PrefixeIPv6>()
        for p in sequence(first: premiere, next: { $0.pointee.ifa_next }) {
            let i = p.pointee
            guard i.ifa_flags & UInt32(IFF_UP) != 0, i.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                  let sa = i.ifa_addr, Int32(sa.pointee.sa_family) == AF_INET6 else { continue }
            let octets = sa.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { s in
                withUnsafeBytes(of: s.pointee.sin6_addr) { Array($0) }
            }
            guard let adresse = AdresseIPv6(octets: octets), !adresse.estLienLocal else { continue }
            resultat.insert(adresse.prefixe)
        }
        return resultat.sorted().map(\.description)
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh`
Expected: PASS, framework `✔ Test run with 57 tests in 12 suites passed` (tout `MaillageCoeur`), app `✔ Test run with 1 test in 1 suite passed`. Le test `tableDuMac` lit la vraie table de routage : hors bac à sable, elle se lit.

- [ ] **Step 5: Commit**

```bash
git add MaillageCoeur/Systeme MaillageCoeurTests/SystemeTests.swift
git commit -m "Lire la table de routage IPv6 et les prefixes du Mac

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Recenseur (Bonjour et dns_sd)

**Files:**
- Create: `MaillageThread/Recenseur/ResolveurDNSSD.swift`, `MaillageThread/Recenseur/NavigateurBonjour.swift`, `MaillageThread/Recenseur/Recenseur.swift`
- Test: `MaillageThreadTests/RecenseurTests.swift`

**Interfaces:**
- Consumes: `Annonces`, `AnnonceService`, `ChampsTXT(brut:)`, `TableRoutage.lire()`, `InterfacesLocales.prefixes()`.
- Produces: `ResolveurDNSSD.resoudre(instance:type:domaine:duree:) async -> Cible?` (`Cible` : `hote` sans point final, `port`, `txt`), `ResolveurDNSSD.adresses(hote:duree:) async -> [String]` ; `NavigateurBonjour(type:)` (`@MainActor`, `instances: [String: Data]`, `etat` `demarrage`/`pret`/`refuse`/`erreur`, `surChangement`, `demarrer()`, `arreter()`, `static etat(_ erreur: NWError)`) ; `Recenseur` (`@MainActor`, `Recenseur.types`, `etat` `demarrage`/`actif`/`reseauLocalRefuse`/`erreur`, `routesLisibles: Bool?`, `dernierReleve`, `surReleve: ((Annonces) -> Void)?`, `surEtat`, `demarrer()`, `arreter()`, `rafraichir()`).

Le recenseur a été validé sur le vrai réseau le 28/09 (prototype en ligne de commande, même code) : 6 routeurs, 57 instances, 34 hôtes, 2 routes, en 4 s environ ; c'est lui qui a produit `capture-0215.json`. Dans l'app, il ne tourne qu'à la tâche 19 (les tests ne l'ouvrent pas).

- [ ] **Step 1: Écrire le test**

`MaillageThreadTests/RecenseurTests.swift` :

```swift
import Foundation
import Network
import dnssd
import Testing
@testable import MaillageThread

@MainActor
@Suite("Recenseur : refus du reseau local")
struct RecenseurTests {
    @Test func refusDuReseauLocal() {
        #expect(NavigateurBonjour.etat(.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))) == .refuse)
        if case .erreur = NavigateurBonjour.etat(.dns(DNSServiceErrorType(kDNSServiceErr_NoSuchRecord))) {} else {
            Issue.record("une autre erreur DNS n'est pas un refus")
        }
        if case .erreur = NavigateurBonjour.etat(.posix(.ENETDOWN)) {} else {
            Issue.record("reseau coupe : erreur, pas refus")
        }
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageThreadTests/RecenseurTests`
Expected: FAIL à la compilation (`cannot find 'NavigateurBonjour' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageThread/Recenseur/ResolveurDNSSD.swift` :

```swift
import Foundation
import dnssd

/// Resolutions DNS-SD ponctuelles (API dns_sd) : chaque requete est ecoutee
/// pendant une fenetre courte, puis fermee.
enum ResolveurDNSSD {
    /// Cible SRV d'une instance, et son TXT brut.
    struct Cible: Equatable, Sendable {
        /// Hote sans point final ("Apple-TV-4K.local").
        let hote: String
        let port: UInt16
        let txt: Data
    }

    /// Hote, port et TXT d'une instance ; nil sans reponse dans la fenetre.
    static func resoudre(instance: String, type: String, domaine: String = "local.",
                         duree: TimeInterval = 2) async -> Cible? {
        let collecte = Collecte<Cible>()
        let reponses = await collecte.executer(duree: duree) { contexte in
            var ref: DNSServiceRef?
            let erreur = DNSServiceResolve(&ref, 0, 0, instance, type, domaine, { _, _, _, erreur, _, hote, port, longueurTXT, txt, contexte in
                guard erreur == kDNSServiceErr_NoError, let hote, let contexte else { return }
                let collecte = Unmanaged<Collecte<Cible>>.fromOpaque(contexte).takeUnretainedValue()
                let octets = txt.map { Data(bytes: $0, count: Int(longueurTXT)) } ?? Data()
                collecte.ajouter(Cible(hote: ResolveurDNSSD.sansPointFinal(String(cString: hote)),
                                       port: UInt16(bigEndian: port), txt: octets))
                collecte.terminer()
            }, contexte)
            return (erreur, ref)
        }
        return reponses.first
    }

    /// Adresses IPv6 et IPv4 d'un hote, en texte, triees ; vide sans reponse.
    static func adresses(hote: String, duree: TimeInterval = 1.5) async -> [String] {
        let collecte = Collecte<String>()
        let reponses = await collecte.executer(duree: duree) { contexte in
            var ref: DNSServiceRef?
            let protocoles = DNSServiceProtocol(kDNSServiceProtocol_IPv6 | kDNSServiceProtocol_IPv4)
            let erreur = DNSServiceGetAddrInfo(&ref, 0, 0, protocoles, hote, { _, drapeaux, _, erreur, _, adresse, _, contexte in
                guard erreur == kDNSServiceErr_NoError, drapeaux & DNSServiceFlags(kDNSServiceFlagsAdd) != 0,
                      let adresse, let contexte else { return }
                let collecte = Unmanaged<Collecte<String>>.fromOpaque(contexte).takeUnretainedValue()
                if let texte = ResolveurDNSSD.texte(adresse) { collecte.ajouter(texte) }
            }, contexte)
            return (erreur, ref)
        }
        return Array(Set(reponses)).sorted()
    }

    static func sansPointFinal(_ hote: String) -> String {
        hote.hasSuffix(".") ? String(hote.dropLast()) : hote
    }

    /// Texte d'une adresse IPv6 (sans zone) ou IPv4.
    static func texte(_ adresse: UnsafePointer<sockaddr>) -> String? {
        var tampon = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        let taille = socklen_t(tampon.count)
        switch Int32(adresse.pointee.sa_family) {
        case AF_INET6:
            var a = adresse.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee.sin6_addr }
            guard inet_ntop(AF_INET6, &a, &tampon, taille) != nil else { return nil }
        case AF_INET:
            var a = adresse.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            guard inet_ntop(AF_INET, &a, &tampon, taille) != nil else { return nil }
        default:
            return nil
        }
        return tampon.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }
}

/// Reponses d'une requete dns_sd, recues sur une file serie qui lui est propre :
/// tout l'etat n'est touche que sur cette file (d'ou @unchecked Sendable).
private final class Collecte<Resultat: Sendable>: @unchecked Sendable {
    private let file = DispatchQueue(label: "fr.djoko.maillage.dnssd")
    private var ref: DNSServiceRef?
    private var reponses: [Resultat] = []
    private var continuation: CheckedContinuation<[Resultat], Never>?
    private var fini = false

    /// Sur la file (rappel de dns_sd).
    func ajouter(_ r: Resultat) { reponses.append(r) }

    /// Lance la requete sur la file et rend les reponses recues pendant `duree`.
    func executer(duree: TimeInterval,
                  demarrer: @escaping @Sendable (UnsafeMutableRawPointer) -> (DNSServiceErrorType, DNSServiceRef?)) async -> [Resultat] {
        await withCheckedContinuation { c in
            file.async {
                self.continuation = c
                let (erreur, ref) = demarrer(Unmanaged.passUnretained(self).toOpaque())
                guard erreur == kDNSServiceErr_NoError, let ref else {
                    self.terminer()
                    return
                }
                self.ref = ref
                DNSServiceSetDispatchQueue(ref, self.file)
                self.file.asyncAfter(deadline: .now() + duree) { self.terminer() }
            }
        }
    }

    /// Sur la file : ferme la requete et rend les reponses (une seule fois).
    func terminer() {
        guard !fini else { return }
        fini = true
        if let ref {
            DNSServiceRefDeallocate(ref)
            self.ref = nil
        }
        continuation?.resume(returning: reponses)
        continuation = nil
    }
}
```

`MaillageThread/Recenseur/NavigateurBonjour.swift` :

```swift
import Foundation
import Network
import dnssd

/// Ecoute Bonjour d'un type de service (NWBrowser, avec les TXT) : garde la
/// liste des instances vues et le TXT brut de chacune.
@MainActor
final class NavigateurBonjour {
    enum Etat: Equatable, Sendable {
        case demarrage, pret, refuse
        case erreur(String)
    }

    let type: String
    /// Instance -> TXT brut (vide si le navigateur n'en a pas donne).
    private(set) var instances: [String: Data] = [:]
    private(set) var etat: Etat = .demarrage
    /// Appele sur le fil principal a chaque changement d'instances ou d'etat.
    var surChangement: (() -> Void)?
    private var navigateur: NWBrowser?

    init(type: String) {
        self.type = type
    }

    func demarrer() {
        let n = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: "local."), using: NWParameters())
        n.stateUpdateHandler = { [weak self] etat in
            MainActor.assumeIsolated { self?.changerEtat(etat) }
        }
        n.browseResultsChangedHandler = { [weak self] resultats, _ in
            MainActor.assumeIsolated { self?.noter(resultats) }
        }
        navigateur = n
        n.start(queue: .main)
    }

    func arreter() {
        navigateur?.cancel()
        navigateur = nil
    }

    private func noter(_ resultats: Set<NWBrowser.Result>) {
        var vus: [String: Data] = [:]
        for r in resultats {
            // Un meme service est vu une fois par interface (en0, en18...) : une seule entree.
            guard case let .service(nom, _, _, _) = r.endpoint else { continue }
            var txt = Data()
            if case let .bonjour(enregistrement) = r.metadata { txt = enregistrement.data }
            if vus[nom]?.isEmpty ?? true { vus[nom] = txt }
        }
        guard vus != instances else { return }
        instances = vus
        surChangement?()
    }

    private func changerEtat(_ e: NWBrowser.State) {
        let nouveau: Etat
        switch e {
        case .setup, .cancelled: nouveau = .demarrage
        case .ready: nouveau = .pret
        case .waiting(let erreur), .failed(let erreur): nouveau = Self.etat(erreur)
        @unknown default: nouveau = .demarrage
        }
        if case .failed = e {
            // Relance dans 10 s (le reseau revient souvent seul).
            arreter()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                self?.demarrer()
            }
        }
        guard nouveau != etat else { return }
        etat = nouveau
        surChangement?()
    }

    /// Refus du reseau local : le navigateur attend avec l'erreur DNS PolicyDenied.
    static func etat(_ erreur: NWError) -> Etat {
        if case .dns(let code) = erreur, code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied) { return .refuse }
        return .erreur(erreur.debugDescription)
    }
}
```

`MaillageThread/Recenseur/Recenseur.swift` :

```swift
import Foundation
import MaillageCoeur

/// Ecoute le reseau local et produit des releves (`Annonces`) : le premier
/// 10 s apres le demarrage (le temps que les reponses arrivent), puis a chaque
/// changement des services (apres 2 s de calme) et au moins toutes les 60 s.
@MainActor
final class Recenseur {
    enum Etat: Equatable, Sendable {
        case demarrage, actif, reseauLocalRefuse
        case erreur(String)
    }

    static let types = ["_meshcop._udp", "_matter._tcp", "_hap._udp"]
    static let miseEnRoute: Duration = .seconds(10)
    static let calme: Duration = .seconds(2)
    static let periode: Duration = .seconds(60)

    private(set) var etat: Etat = .demarrage
    /// La table de routage a-t-elle pu etre lue au dernier releve (nil : pas encore de releve).
    private(set) var routesLisibles: Bool?
    private(set) var dernierReleve: Annonces?
    var surReleve: ((Annonces) -> Void)?
    var surEtat: ((Etat) -> Void)?

    private var navigateurs: [NavigateurBonjour] = []
    /// "type|instance" -> cible resolue.
    private var cibles: [String: ResolveurDNSSD.Cible] = [:]
    private var demarre = false
    private var enRoute = false
    private var releveEnCours = false
    private var releveEnAttente = false
    private var tachePeriodique: Task<Void, Never>?
    private var tacheCalme: Task<Void, Never>?

    func demarrer() {
        guard !demarre else { return }
        demarre = true
        navigateurs = Self.types.map { type in
            let n = NavigateurBonjour(type: type)
            n.surChangement = { [weak self] in self?.changement() }
            n.demarrer()
            return n
        }
        tachePeriodique = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.miseEnRoute)
            while !Task.isCancelled {
                guard let self else { return }
                self.enRoute = true
                await self.releve()
                try? await Task.sleep(for: Self.periode)
            }
        }
    }

    func arreter() {
        tachePeriodique?.cancel()
        tacheCalme?.cancel()
        navigateurs.forEach { $0.arreter() }
        navigateurs = []
        demarre = false
        enRoute = false
    }

    /// Releve immediat (bouton rafraichir, reveil du Mac) : resout tout a nouveau.
    func rafraichir() {
        cibles = [:]
        Task { @MainActor [weak self] in await self?.releve() }
    }

    private func changement() {
        mettreAJourEtat()
        guard enRoute else { return }
        tacheCalme?.cancel()
        tacheCalme = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.calme)
            guard !Task.isCancelled else { return }
            await self?.releve()
        }
    }

    private func mettreAJourEtat() {
        let etats = navigateurs.map(\.etat)
        let nouveau: Etat
        if etats.contains(.refuse) {
            nouveau = .reseauLocalRefuse
        } else if let e = etats.lazy.compactMap({ if case .erreur(let m) = $0 { m } else { nil } }).first {
            nouveau = .erreur(e)
        } else if !etats.isEmpty && etats.allSatisfy({ $0 == .pret }) {
            nouveau = .actif
        } else {
            nouveau = .demarrage
        }
        guard nouveau != etat else { return }
        etat = nouveau
        surEtat?(nouveau)
    }

    /// Un releve a la fois ; une demande pendant un releve en relance un apres.
    private func releve() async {
        guard !releveEnCours else {
            releveEnAttente = true
            return
        }
        releveEnCours = true
        repeat {
            releveEnAttente = false
            let a = await faireReleve()
            dernierReleve = a
            surReleve?(a)
        } while releveEnAttente
        releveEnCours = false
    }

    private func faireReleve() async -> Annonces {
        // 1. Instances vues, et leur cible (hote, port) : resolue une fois par instance.
        var vues: [(type: String, instance: String, txt: Data)] = []
        for n in navigateurs {
            for (instance, txt) in n.instances { vues.append((n.type, instance, txt)) }
        }
        let cles = Set(vues.map { "\($0.type)|\($0.instance)" })
        cibles = cibles.filter { cles.contains($0.key) }
        let aResoudre = vues.filter { cibles["\($0.type)|\($0.instance)"] == nil }.map { ($0.type, $0.instance) }
        let resolues = await withTaskGroup(of: (String, ResolveurDNSSD.Cible?).self) { groupe in
            for (type, instance) in aResoudre {
                groupe.addTask { ("\(type)|\(instance)", await ResolveurDNSSD.resoudre(instance: instance, type: type)) }
            }
            var r: [String: ResolveurDNSSD.Cible] = [:]
            for await (cle, cible) in groupe { if let cible { r[cle] = cible } }
            return r
        }
        cibles.merge(resolues) { _, nouvelle in nouvelle }

        // 2. Adresses de chaque hote, a chaque releve.
        let hotes = Set(cibles.values.map(\.hote))
        let adresses = await withTaskGroup(of: (String, [String]).self) { groupe in
            for hote in hotes {
                groupe.addTask { (hote, await ResolveurDNSSD.adresses(hote: hote)) }
            }
            var r: [String: [String]] = [:]
            for await (hote, liste) in groupe { r[hote] = liste }
            return r
        }

        // 3. Routes et prefixes du Mac.
        let routes = TableRoutage.lire()
        routesLisibles = routes != nil

        func services(_ type: String) -> [AnnonceService] {
            vues.filter { $0.type == type }.map { v in
                let cible = cibles["\(type)|\(v.instance)"]
                let txt = v.txt.isEmpty ? (cible?.txt ?? Data()) : v.txt
                return AnnonceService(instance: v.instance, hote: cible?.hote, port: cible?.port, txt: ChampsTXT(brut: txt))
            }.sorted { $0.instance < $1.instance }
        }
        return Annonces(date: Date(), routeurs: services("_meshcop._udp"), matter: services("_matter._tcp"),
                        hap: services("_hap._udp"), adresses: adresses, routes: routes ?? [],
                        prefixesLocaux: InterfacesLocales.prefixes())
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageThreadTests`
Expected: PASS, `✔ Test run with 2 tests in 2 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageThread/Recenseur MaillageThreadTests/RecenseurTests.swift
git commit -m "Recenser le reseau local : Bonjour, dns_sd, routes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Modèle de l'app (Surveillance), mode démo, veille, capture

**Files:**
- Create: `MaillageThread/Surveillance/Surveillance.swift`
- Test: `MaillageThreadTests/SurveillanceTests.swift`

**Interfaces:**
- Consumes: `Recenseur`, `Suivi`, `JournalFichiers`, `Alertes`, `Regroupement`, `ResolveurNoms`, `Surnoms`, `NomsDemo`, `ScenarioPanne`, `AppareilAffiche`, `EtatAffiche`, `CodageJSON`.
- Produces: `ResumeReseau` (`nom`, `partitions`, `routeurs`, `appareils`, `injoignables`) ; `Surveillance` (`@MainActor @Observable` ; `init(mode: .direct | .demo, dossier: URL?)`, `demarrer()`, `arreter()`, `rafraichir()`, `integrer(_:)`, `noterVeille(debut:fin:)`, `renommer(_:en:)`, `captureJSON() throws -> Data?` ; lus par les vues : `mode`, `etatEcoute` (`demarrage`, `active`, `reseauLocalRefuse`, `demo`, `erreur`), `suivi`, `evenements`, `dernierReleve`, `routesLisibles`, `erreurJournal`, `noms`, `reseauChoisi`, `instantane`, `maintenant`, `reseau`, `fabriqueApple`, `nom(_: Appareil)`, `nom(_: RouteurBordure)`, `accessoire(_:)`, `appareil(_:)`, `appareilsAffiches(pour:)`, `resume`, `alerte`, `lignesJournal`, `derniereScission(_:)`, `evenements(de:)` ; `surAlertes: (([AlerteAEnvoyer]) -> Void)?` ; `Surveillance.sousTests`, `Surveillance.dossierParDefaut`).

- [ ] **Step 1: Écrire le test**

`MaillageThreadTests/SurveillanceTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Surveillance (modele de l'app)")
struct SurveillanceTests {
    static func demo() -> Surveillance {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        return s
    }

    @Test func modeDemo() throws {
        let s = Self.demo()
        #expect(s.etatEcoute == .demo)
        #expect(s.evenements.count == 10)
        guard case .pertes(let pertes) = s.lignesJournal.first else {
            Issue.record("les pertes regroupees en tete du journal")
            return
        }
        #expect(pertes.count == 5)
        let resume = try #require(s.resume)
        #expect(resume == ResumeReseau(nom: "MyHome1482620090", partitions: 2, routeurs: 6, appareils: 24, injoignables: 5))
        #expect(s.alerte, "reseau scinde")
        let r = try #require(s.reseau)
        let affiches = s.appareilsAffiches(pour: r)
        #expect(affiches.filter { $0.etat == .disparu }.map(\.nom).sorted()
                == ["Ampoule entrée", "Prise bureau", "Prise salon", "Thermo chambre"])
        #expect(affiches.first { $0.id == "46F77B36E071F8D0" }?.partition == "73586B68", "disparu a sa derniere place")
        #expect(affiches.first { $0.id == "56B1E064401F74EF" }?.piece == "Bureau")
        #expect(s.evenements(de: "46F77B36E071F8D0").first?.type == .appareilDisparu)
        #expect(s.derniereScission(r)?.date == ScenarioPanne.date(4, 14))
        #expect(s.appareil("46F77B36E071F8D0") != nil, "un disparu reste consultable")
        #expect(s.routesLisibles == true)
    }

    @Test func journalEtSurnomsSurDisque() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("maillage-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dossier) }
        let s = Surveillance(mode: .direct, dossier: dossier)
        for a in ScenarioPanne.releves.prefix(12) { s.integrer(a) }
        #expect(s.evenements.map(\.type) == [.surveillanceDemarree, .routeurNouvelleAdresseLien, .prefixeNouveau,
                                             .prefixeRetire])
        let journal = JournalFichiers(dossier: dossier.appendingPathComponent("Journal"))
        #expect(try journal.lire().count == 4)

        s.renommer("56B1E064401F74EF", en: "  Pont du bureau ")
        let halo = try #require(s.appareil("56B1E064401F74EF"))
        #expect(s.nom(halo) == "Pont du bureau")
        let relu = Surveillance(mode: .direct, dossier: dossier)
        #expect(relu.noms.surnoms == ["56B1E064401F74EF": "Pont du bureau"])
        s.renommer("56B1E064401F74EF", en: "")
        #expect(s.nom(halo) == "56B1E064401F74EF")

        let capture = try #require(try s.captureJSON())
        let lue = try CodageJSON.decodeur().decode(Annonces.self, from: capture)
        #expect(lue.date == ScenarioPanne.releves[11].date)
    }

    @Test func veilleDuMac() {
        let s = Surveillance(mode: .direct, dossier: nil)
        s.integrer(ScenarioPanne.releves[0])
        s.noterVeille(debut: ScenarioPanne.date(3, 56), fin: ScenarioPanne.date(3, 55))
        #expect(s.evenements.last?.type == .veille)
        #expect(s.evenements.last?.periode?.duration == 0, "fin avant le debut : ramenee au debut")
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageThreadTests/SurveillanceTests`
Expected: FAIL à la compilation (`cannot find 'Surveillance' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageThread/Surveillance/Surveillance.swift` :

```swift
import AppKit
import MaillageCoeur
import Observation

/// Chiffres du reseau affiche, pour la barre des menus.
struct ResumeReseau: Equatable {
    var nom: String
    var partitions: Int
    var routeurs: Int
    var appareils: Int
    /// Appareils Thread qui ne sont pas joignables (sans adresse, isoles, inconnus) ou disparus.
    var injoignables: Int
}

/// Modele de l'app : releves -> suivi -> journal et notifications ; noms ;
/// etat lu par les vues.
@MainActor
@Observable
final class Surveillance {
    enum Mode: Equatable {
        /// Ecoute du reseau local, journal sur disque, notifications.
        case direct
        /// Panne du 27/09 rejouee, rien sur disque, pas de notification.
        case demo
    }

    enum EtatEcoute: Equatable {
        case demarrage, active, reseauLocalRefuse, demo
        case erreur(String)
    }

    let mode: Mode
    private(set) var etatEcoute: EtatEcoute
    private(set) var suivi = Suivi()
    /// Journal : evenements gardes (90 jours) puis ceux de la session, du plus ancien au plus recent.
    private(set) var evenements: [Evenement] = []
    private(set) var dernierReleve: Annonces?
    private(set) var routesLisibles: Bool?
    private(set) var erreurJournal: String?
    var noms: ResolveurNoms
    /// Reseau affiche (`xp`) ; nil : le premier.
    var reseauChoisi: String?

    /// Branche sur les notifications (mode direct seulement).
    @ObservationIgnored var surAlertes: (([AlerteAEnvoyer]) -> Void)?
    @ObservationIgnored private let recenseur: Recenseur?
    @ObservationIgnored private let journal: JournalFichiers?
    @ObservationIgnored private let fichierSurnoms: URL?
    @ObservationIgnored private var alertes = Alertes()
    @ObservationIgnored private var debutVeille: Date?
    @ObservationIgnored private var observateurs: [NSObjectProtocol] = []

    /// Lance par les tests (heberges dans l'app) : ne rien ecouter ni ecrire.
    static var sousTests: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }

    /// Dossier de l'app : Application Support/Maillage Thread (dans le conteneur du bac a sable).
    static var dossierParDefaut: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Maillage Thread")
    }

    /// `dossier` : ou garder le journal et les surnoms (nil : nulle part).
    init(mode: Mode, dossier: URL?) {
        self.mode = mode
        switch mode {
        case .direct:
            etatEcoute = .demarrage
            recenseur = Recenseur()
            journal = dossier.map { JournalFichiers(dossier: $0.appendingPathComponent("Journal")) }
            fichierSurnoms = dossier?.appendingPathComponent("surnoms.json")
            noms = ResolveurNoms(surnoms: fichierSurnoms.map(Surnoms.lire) ?? [:])
        case .demo:
            etatEcoute = .demo
            recenseur = nil
            journal = nil
            fichierSurnoms = nil
            noms = ResolveurNoms(maison: NomsDemo.maison)
        }
    }

    func demarrer() {
        switch mode {
        case .demo:
            for a in ScenarioPanne.releves { integrer(a) }
        case .direct:
            if let journal {
                do {
                    try journal.purger(maintenant: Date())
                    evenements = try journal.lire()
                } catch {
                    erreurJournal = error.localizedDescription
                }
            }
            recenseur?.surReleve = { [weak self] a in self?.integrer(a) }
            recenseur?.surEtat = { [weak self] e in self?.noterEtat(e) }
            recenseur?.demarrer()
            observerVeille()
        }
    }

    func arreter() {
        recenseur?.arreter()
        observateurs.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observateurs = []
    }

    /// Releve immediat.
    func rafraichir() {
        recenseur?.rafraichir()
    }

    /// Integre un releve : evenements, journal, notifications.
    func integrer(_ a: Annonces) {
        dernierReleve = a
        routesLisibles = mode == .demo ? true : recenseur?.routesLisibles
        let nouveaux = suivi.integrer(a, noms: noms)
        ajouter(nouveaux)
    }

    /// Veille du Mac (appele au reveil).
    func noterVeille(debut: Date, fin: Date) {
        ajouter(suivi.noterVeille(DateInterval(start: debut, end: max(fin, debut))))
    }

    /// Donne (ou retire, avec nil ou "") un surnom a un noeud.
    func renommer(_ id: String, en surnom: String?) {
        let s = surnom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        noms.surnoms[id] = s.isEmpty ? nil : s
        guard let fichierSurnoms else { return }
        do {
            try Surnoms.ecrire(noms.surnoms, dans: fichierSurnoms)
        } catch {
            erreurJournal = error.localizedDescription
        }
    }

    /// Dernier releve en JSON (option de capture).
    func captureJSON() throws -> Data? {
        try dernierReleve.map { try CodageJSON.encodeur(lisible: true).encode($0) }
    }

    private func ajouter(_ nouveaux: [Evenement]) {
        guard !nouveaux.isEmpty else { return }
        evenements.append(contentsOf: nouveaux)
        do {
            try journal?.ajouter(nouveaux)
        } catch {
            erreurJournal = error.localizedDescription
        }
        let envoyer = alertes.traiter(nouveaux)
        if mode == .direct && !envoyer.isEmpty { surAlertes?(envoyer) }
    }

    private func noterEtat(_ e: Recenseur.Etat) {
        switch e {
        case .demarrage: etatEcoute = .demarrage
        case .actif: etatEcoute = .active
        case .reseauLocalRefuse: etatEcoute = .reseauLocalRefuse
        case .erreur(let m): etatEcoute = .erreur(m)
        }
    }

    private func observerVeille() {
        let nc = NSWorkspace.shared.notificationCenter
        observateurs.append(nc.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.debutVeille = Date() }
        })
        observateurs.append(nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let debut = self.debutVeille else { return }
                self.debutVeille = nil
                self.noterVeille(debut: debut, fin: Date())
                self.recenseur?.rafraichir()
            }
        })
    }

    // MARK: - Pour les vues

    var instantane: Instantane? { suivi.instantane }

    /// Reference des durees affichees ("vu il y a...") : la fin de la panne rejouee en demo.
    var maintenant: Date { mode == .demo ? (dernierReleve?.date ?? Date()) : Date() }

    var reseau: Reseau? {
        guard let i = instantane else { return nil }
        return reseauChoisi.flatMap { i.reseau($0) } ?? i.reseaux.first
    }

    var fabriqueApple: String? {
        guard let i = instantane else { return nil }
        return noms.fabriqueApple(appareils: i.appareils + i.appareilsIP + Array(suivi.disparus.values))
    }

    func nom(_ a: Appareil) -> String { noms.nom(appareil: a, fabriqueApple: fabriqueApple) }
    func nom(_ r: RouteurBordure) -> String { noms.nom(routeur: r) }
    func accessoire(_ a: Appareil) -> AccessoireMaison? { noms.accessoire(de: a, fabriqueApple: fabriqueApple) }

    /// Appareil par identifiant, present ou disparu.
    func appareil(_ id: String) -> Appareil? { instantane?.appareil(id) ?? suivi.disparus[id] }

    /// Appareils a dessiner pour un reseau : presents, puis disparus (a leur place).
    func appareilsAffiches(pour r: Reseau) -> [AppareilAffiche] {
        guard let i = instantane else { return [] }
        let partitions = Set(r.partitions.map(\.id))
        let premier = i.reseaux.first?.id == r.id
        func appartient(_ a: Appareil) -> Bool {
            if let x = a.idReseau { return x == r.id }
            if let p = suivi.dernieresPartitions[a.id], partitions.contains(p) { return true }
            return premier
        }
        func affiche(_ a: Appareil, _ etat: EtatAffiche) -> AppareilAffiche {
            AppareilAffiche(id: a.id, nom: nom(a), piece: accessoire(a)?.piece,
                            partition: a.partition ?? suivi.dernieresPartitions[a.id], etat: etat, endormi: a.endormi)
        }
        var liste = i.appareils.filter(appartient).map { a in
            let etat: EtatAffiche = switch a.etat {
            case .joignable: .joignable
            case .partitionCoupee: .partitionCoupee
            case .sansAdresse: .sansAdresse
            case .inconnu: .inconnu
            }
            return affiche(a, etat)
        }
        liste += suivi.disparus.values.filter(appartient).map { affiche($0, .disparu) }
        return liste
    }

    /// Chiffres du reseau affiche.
    var resume: ResumeReseau? {
        guard let i = instantane, let r = reseau else { return nil }
        let affiches = appareilsAffiches(pour: r)
        return ResumeReseau(nom: r.nom, partitions: r.partitions.count, routeurs: r.routeurs.count,
                            appareils: affiches.count,
                            injoignables: affiches.filter { $0.etat != .joignable }.count
                                + i.appareilsIP.filter { $0.etat != .joignable }.count)
    }

    /// Alerte en cours : un reseau scinde, ou un evenement grave dans l'heure.
    var alerte: Bool {
        if instantane?.reseaux.contains(where: \.estScinde) == true { return true }
        let recent = Date().addingTimeInterval(-3600)
        return evenements.reversed().prefix { $0.date >= recent }.contains { $0.gravite == .alerte }
    }

    var lignesJournal: [LigneJournal] { Regroupement.lignes(evenements) }

    /// Derniere scission du reseau (pour le bandeau : "depuis" ou "constate a").
    func derniereScission(_ r: Reseau) -> Evenement? {
        evenements.last { $0.type == .reseauScinde && $0.reseau == r.id }
    }

    /// 5 derniers evenements d'un noeud, du plus recent au plus ancien.
    func evenements(de id: String) -> [Evenement] {
        Array(evenements.reversed().filter { $0.sujet?.id == id }.prefix(5))
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageThreadTests`
Expected: PASS, `✔ Test run with 5 tests in 3 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageThread/Surveillance/Surveillance.swift MaillageThreadTests/SurveillanceTests.swift
git commit -m "Relier releves, suivi, journal et surnoms dans le modele de l'app

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Textes des événements et notifications

**Files:**
- Create: `MaillageThread/Surveillance/TexteEvenement.swift`, `MaillageThread/Surveillance/Notifications.swift`
- Test: `MaillageThreadTests/TexteEvenementTests.swift`

**Interfaces:**
- Consumes: `Evenement`, `LigneJournal`, `AlerteAEnvoyer`, `CategorieAlerte`, `RoleThread`, `Surveillance` (tests).
- Produces: `TexteEvenement.heure(_:)`, `quand(_:)`, `role(_:)`, `titre(_: Evenement)`, `titre(_: LigneJournal)`, `isoles(_:)`, `notification(_:) -> (titre: String, corps: String)` ; `Notifications` (`@MainActor` ; `cle(_:)`, `active(_:preferences:)`, `demanderAutorisation()`, `presenter(_:)`).

- [ ] **Step 1: Écrire le test**

`MaillageThreadTests/TexteEvenementTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Textes des evenements et des notifications")
struct TexteEvenementTests {
    static func demo() -> Surveillance {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        return s
    }

    @Test func textes() {
        let t = ScenarioPanne.date(4, 14)
        for type in TypeEvenement.allCases {
            let e = Evenement(date: t, type: type, sujet: Sujet(id: "x", nom: "Nuki Ultra"), avant: "chef", apres: "routeur",
                              periode: type == .veille ? DateInterval(start: t, end: t.addingTimeInterval(60)) : nil)
            #expect(!TexteEvenement.titre(e).isEmpty, "\(type)")
        }
        let s = Self.demo()
        guard case .pertes(let pertes)? = s.lignesJournal.first else { return }
        let titre = TexteEvenement.titre(LigneJournal.pertes(pertes))
        #expect(titre.contains("5"))
        #expect(titre.contains(TexteEvenement.heure(ScenarioPanne.date(4, 20))))
        let scission = s.evenements.first { $0.type == .reseauScinde }!
        #expect(TexteEvenement.isoles(scission) == "Aqara HubM100 #DFEB")
        let notification = TexteEvenement.notification(AlerteAEnvoyer(categorie: .pertes, identifiant: "p", evenements: pertes))
        #expect(notification.corps.contains("Prise bureau"))
        #expect(Notifications.active(.scission, preferences: UserDefaults(suiteName: "vide-\(UUID())")!))
        #expect(!Notifications.active(.informations, preferences: UserDefaults(suiteName: "vide-\(UUID())")!))
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageThreadTests/TexteEvenementTests`
Expected: FAIL à la compilation (`cannot find 'TexteEvenement' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageThread/Surveillance/TexteEvenement.swift` :

```swift
import Foundation
import MaillageCoeur

/// Textes affiches des evenements, des lignes du journal et des notifications.
enum TexteEvenement {
    static func heure(_ d: Date) -> String {
        d.formatted(date: .omitted, time: .shortened)
    }

    /// Quand : date et heure, ou la periode de veille si la date est incertaine.
    static func quand(_ e: Evenement) -> String {
        if let p = e.periode {
            return String(localized: "entre \(heure(p.start)) et \(heure(p.end)) (Mac en veille)")
        }
        return e.date.formatted(date: .abbreviated, time: .shortened)
    }

    static func role(_ brut: String?) -> String {
        switch brut.flatMap(RoleThread.init(rawValue:)) {
        case .chef?: String(localized: "chef")
        case .routeur?: String(localized: "routeur")
        case .enfant?: String(localized: "enfant")
        case .detache?: String(localized: "détaché")
        case nil: String(localized: "inconnu")
        }
    }

    static func titre(_ e: Evenement) -> String {
        let nom = e.sujet?.nom ?? ""
        let avant = e.avant ?? "?"
        let apres = e.apres ?? "?"
        switch e.type {
        case .surveillanceDemarree:
            let r = e.details["routeurs"] ?? "0"
            let a = e.details["appareils"] ?? "0"
            return String(localized: "Surveillance démarrée (routeurs : \(r), appareils : \(a))")
        case .veille:
            guard let p = e.periode else { return String(localized: "Mac en veille") }
            return String(localized: "Mac en veille de \(heure(p.start)) à \(heure(p.end))")
        case .reseauScinde:
            if e.constate { return String(localized: "Réseau \(nom) scindé (constaté au lancement)") }
            return String(localized: "Réseau \(nom) scindé en \(apres) partitions")
        case .reseauReuni:
            return String(localized: "Réseau \(nom) réuni")
        case .chefChange:
            return String(localized: "Nouveau chef : \(apres) (avant : \(avant))")
        case .bbrPrimaireChange:
            return String(localized: "Nouveau BBR primaire : \(apres) (avant : \(avant))")
        case .jeuActifChange:
            return String(localized: "Réseau \(nom) : nouveau jeu de paramètres actif")
        case .routeurApparu, .appareilNouveau:
            return String(localized: "\(nom) est apparu")
        case .routeurDisparu, .appareilDisparu:
            return String(localized: "\(nom) a disparu")
        case .routeurRoleChange:
            return String(localized: "\(nom) : rôle \(role(e.avant)) → \(role(e.apres))")
        case .routeurNouvelleAdresseLien:
            return String(localized: "\(nom) : nouvelle adresse de lien (redémarrage probable)")
        case .prefixeNouveau:
            return String(localized: "Nouveau préfixe \(nom)")
        case .prefixeRetire:
            return String(localized: "Préfixe \(nom) retiré")
        case .appareilRevenu:
            return String(localized: "\(nom) est revenu")
        case .appareilSansAdresse:
            return String(localized: "\(nom) n'a plus d'adresse")
        case .appareilChangePartition:
            if e.details["coupee"] == "oui" { return String(localized: "\(nom) est isolé dans la partition \(apres)") }
            return String(localized: "\(nom) a rejoint la partition \(apres)")
        }
    }

    static func titre(_ l: LigneJournal) -> String {
        switch l {
        case .evenement(let e):
            return titre(e)
        case .pertes(let p):
            let debut = heure(p.first?.date ?? .distantPast)
            let fin = heure(p.last?.date ?? .distantPast)
            return String(localized: "\(p.count) appareils perdus entre \(debut) et \(fin)")
        }
    }

    /// Routeurs des partitions a part (toutes sauf la plus grande), d'apres les details d'une scission.
    static func isoles(_ e: Evenement) -> String {
        let groupes = e.details.map { (partition: $0.key, routeurs: $0.value) }
            .sorted { ($0.routeurs.components(separatedBy: ", ").count, $1.partition)
                    > ($1.routeurs.components(separatedBy: ", ").count, $0.partition) }
        return groupes.dropFirst().map(\.routeurs).joined(separator: " ; ")
    }

    /// Titre et texte d'une notification.
    static func notification(_ a: AlerteAEnvoyer) -> (titre: String, corps: String) {
        guard let e = a.evenements.first else { return ("", "") }
        switch a.categorie {
        case .scission:
            let nom = e.sujet?.nom ?? ""
            return (String(localized: "Réseau Thread scindé"),
                    String(localized: "\(nom) — partition à part : \(isoles(e))"))
        case .routeurDisparu:
            return (String(localized: "Routeur de bordure disparu"), titre(e) + " · " + quand(e))
        case .pertes:
            let noms = a.evenements.compactMap { $0.sujet?.nom }.joined(separator: ", ")
            let debut = heure(a.evenements.first?.date ?? .distantPast)
            let fin = heure(a.evenements.last?.date ?? .distantPast)
            return (String(localized: "\(a.evenements.count) appareils Thread perdus"),
                    String(localized: "Entre \(debut) et \(fin) : \(noms)"))
        case .informations:
            return (titre(e), quand(e))
        }
    }
}
```

`MaillageThread/Surveillance/Notifications.swift` :

```swift
import Foundation
import MaillageCoeur
import UserNotifications

/// Notifications du systeme (le mode Concentration s'applique de lui-meme).
/// Une categorie se coupe dans les reglages ; une notification de meme
/// identifiant remplace la precedente (pertes groupees).
@MainActor
final class Notifications {
    static func cle(_ c: CategorieAlerte) -> String { "notification.\(c.rawValue)" }

    static func active(_ c: CategorieAlerte, preferences: UserDefaults = .standard) -> Bool {
        preferences.object(forKey: cle(c)) as? Bool ?? c.parDefaut
    }

    func demanderAutorisation() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func presenter(_ alertes: [AlerteAEnvoyer]) {
        for a in alertes where Self.active(a.categorie) {
            let (titre, corps) = TexteEvenement.notification(a)
            let contenu = UNMutableNotificationContent()
            contenu.title = titre
            contenu.body = corps
            if a.categorie != .informations { contenu.sound = .default }
            let requete = UNNotificationRequest(identifier: a.identifiant, content: contenu, trigger: nil)
            UNUserNotificationCenter.current().add(requete) { _ in }
        }
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageThreadTests`
Expected: PASS, `✔ Test run with 6 tests in 4 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageThread/Surveillance/TexteEvenement.swift MaillageThread/Surveillance/Notifications.swift MaillageThreadTests/TexteEvenementTests.swift
git commit -m "Ecrire les textes des evenements et presenter les notifications

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Fenêtre du graphe (Canvas, surcouches Liquid Glass, fiche)

**Files:**
- Create: `MaillageThread/Vues/FenetresDeLApp.swift`, `MaillageThread/Vues/Graphe/Projection.swift`, `MaillageThread/Vues/Graphe/Palette.swift`, `MaillageThread/Vues/Graphe/GrapheCanvas.swift`, `MaillageThread/Vues/Graphe/FenetreGraphe.swift`, `MaillageThread/Vues/Graphe/FicheNoeud.swift`
- Test: `MaillageThreadTests/GrapheTests.swift`

**Interfaces:**
- Consumes: `Surveillance`, `TexteEvenement`, `Disposition`, `AppareilAffiche`, `Reseau`, `RouteurBordure`, `Appareil`.
- Produces: `PolitiqueActivation` et `View.fenetreDeLApp()` (icône du Dock tant qu'une fenêtre de l'app est ouverte) ; `Projection(cadre:taille:marges:zoom:decalage:)` (`echelle`, `origine`, `vue(_:)`, `plan(_:)`) ; `Palette(sombre:)` ; `GrapheCanvas` ; `FenetreGraphe` (lit `-selection <id>` dans les préférences : fiche ouverte au lancement) ; `BarreOutils`, `BandeauScission`, `EtatVide`, `ListeAppareilsIP`, `FeuilleRenommer`, `NoeudChoisi` ; `FicheNoeud(id:aRenommer:fermer:)`. La fenêtre a l'identifiant `graphe` (scène déclarée à la tâche 17) ; la barre d'outils ouvre `journal`.

- [ ] **Step 1: Écrire le test**

`MaillageThreadTests/GrapheTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Graphe : projection du plan vers la vue")
struct GrapheTests {
    @Test func projection() {
        let cadre = (min: Point2D(-210, -210), max: Point2D(390, 470))
        let p = Projection(cadre: cadre, taille: CGSize(width: 1000, height: 800),
                           marges: (haut: 70, bas: 30, cotes: 60))
        // Place libre : 880 x 700 pour un cadre de 600 x 680 : la hauteur decide.
        #expect(abs(p.echelle - 700.0 / 680.0) < 1e-9)
        let centre = p.vue(Point2D(90, 130))
        #expect(abs(centre.x - 500) < 1e-9 && abs(centre.y - 420) < 1e-9, "centre du cadre au centre de la place libre")
        let q = p.plan(p.vue(Point2D(12, -34)))
        #expect(abs(q.x - 12) < 1e-9 && abs(q.y + 34) < 1e-9)
        let zoom = Projection(cadre: cadre, taille: CGSize(width: 1000, height: 800),
                              marges: (haut: 70, bas: 30, cotes: 60), zoom: 2, decalage: CGSize(width: 10, height: -5))
        #expect(abs(zoom.echelle - 2 * p.echelle) < 1e-9)
        let c2 = zoom.vue(Point2D(90, 130))
        #expect(abs(c2.x - 510) < 1e-9 && abs(c2.y - 415) < 1e-9)
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageThreadTests/GrapheTests`
Expected: FAIL à la compilation (`cannot find 'Projection' in scope`).

- [ ] **Step 3: Écrire les vues**

`MaillageThread/Vues/FenetresDeLApp.swift` :

```swift
import AppKit
import SwiftUI

/// App de la barre des menus : pas d'icone dans le Dock, sauf tant qu'une de
/// ses fenetres (graphe, journal) est ouverte.
@MainActor
enum PolitiqueActivation {
    private static var ouvertes = 0

    static func ouverte() {
        ouvertes += 1
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    static func fermee() {
        ouvertes = max(0, ouvertes - 1)
        if ouvertes == 0 { NSApp.setActivationPolicy(.accessory) }
    }
}

extension View {
    /// Fenetre de l'app : l'icone du Dock et le menu de l'app tant qu'elle est ouverte.
    func fenetreDeLApp() -> some View {
        onAppear { PolitiqueActivation.ouverte() }
            .onDisappear { PolitiqueActivation.fermee() }
    }
}
```

`MaillageThread/Vues/Graphe/Projection.swift` :

```swift
import CoreGraphics
import MaillageCoeur

/// Passage du plan de la disposition a la vue : le cadre des zones tient dans
/// la place libre (hors marges), puis zoom et decalage de l'utilisateur.
struct Projection: Equatable {
    let echelle: CGFloat
    /// Point de la vue ou tombe l'origine du plan.
    let origine: CGPoint

    init(cadre: (min: Point2D, max: Point2D), taille: CGSize, marges: (haut: CGFloat, bas: CGFloat, cotes: CGFloat),
         zoom: CGFloat = 1, decalage: CGSize = .zero) {
        let largeur = max(taille.width - 2 * marges.cotes, 1)
        let hauteur = max(taille.height - marges.haut - marges.bas, 1)
        let l = max(cadre.max.x - cadre.min.x, 1)
        let h = max(cadre.max.y - cadre.min.y, 1)
        echelle = min(largeur / l, hauteur / h) * zoom
        let centreVue = CGPoint(x: marges.cotes + largeur / 2 + decalage.width,
                                y: marges.haut + hauteur / 2 + decalage.height)
        let centrePlan = CGPoint(x: (cadre.min.x + cadre.max.x) / 2, y: (cadre.min.y + cadre.max.y) / 2)
        origine = CGPoint(x: centreVue.x - centrePlan.x * echelle, y: centreVue.y - centrePlan.y * echelle)
    }

    func vue(_ p: Point2D) -> CGPoint {
        CGPoint(x: origine.x + p.x * echelle, y: origine.y + p.y * echelle)
    }

    func plan(_ v: CGPoint) -> Point2D {
        Point2D((v.x - origine.x) / echelle, (v.y - origine.y) / echelle)
    }
}
```

`MaillageThread/Vues/Graphe/Palette.swift` :

```swift
import MaillageCoeur
import SwiftUI

/// Couleurs du graphe, en mode sombre (fond profond) et clair (fond pale).
struct Palette {
    let sombre: Bool

    var fond: Gradient {
        sombre ? Gradient(colors: [Color(red: 0.12, green: 0.23, blue: 0.54), Color(red: 0.06, green: 0.09, blue: 0.16),
                                   Color(red: 0.01, green: 0.02, blue: 0.09)])
               : Gradient(colors: [Color(red: 0.86, green: 0.91, blue: 1.0), Color(red: 0.95, green: 0.96, blue: 0.99),
                                   Color.white])
    }

    var texte: Color { sombre ? Color(white: 0.9) : Color(white: 0.2) }
    var texteDiscret: Color { sombre ? Color(white: 0.7) : Color(white: 0.4) }
    var lien: Color { sombre ? Color.white.opacity(0.28) : Color.black.opacity(0.22) }
    var lienEclaire: Color { sombre ? Color.white.opacity(0.85) : Color.black.opacity(0.7) }
    var selection: Color { sombre ? .white : .black }

    /// La principale en bleu, les autres en ambre, les sans-partition en gris.
    func zone(_ z: Disposition.Zone) -> Color {
        if z.id.isEmpty { return .gray }
        return z.principale ? Color(red: 0.23, green: 0.51, blue: 0.96) : Color(red: 0.96, green: 0.62, blue: 0.04)
    }

    func routeur(principale: Bool) -> Color {
        principale ? Color(red: 0.38, green: 0.65, blue: 0.98) : Color(red: 0.98, green: 0.75, blue: 0.14)
    }

    func appareil(_ e: EtatAffiche) -> Color {
        switch e {
        case .joignable: Color(red: 0.29, green: 0.87, blue: 0.5)
        case .partitionCoupee: .orange
        case .sansAdresse, .disparu: Color(red: 0.97, green: 0.44, blue: 0.44)
        case .inconnu: .gray
        }
    }
}
```

`MaillageThread/Vues/Graphe/GrapheCanvas.swift` :

```swift
import MaillageCoeur
import SwiftUI

/// Dessin du graphe : zones des partitions, pointilles vers le centre de
/// chaque zone (rattachement, pas un lien radio), routeurs et appareils.
struct GrapheCanvas: View {
    let disposition: Disposition
    let reseau: Reseau
    /// Identifiant -> appareil affiche (etat, nom).
    let appareils: [String: AppareilAffiche]
    /// Instance -> nom affiche du routeur.
    let nomsRouteurs: [String: String]
    let projection: Projection
    let selection: String?
    let survol: String?
    let palette: Palette

    var body: some View {
        Canvas { ctx, _ in
            dessinerZones(&ctx)
            dessinerLiens(&ctx)
            dessinerNoeuds(&ctx)
        }
    }

    private func dessinerZones(_ ctx: inout GraphicsContext) {
        for z in disposition.zones {
            let c = projection.vue(z.centre)
            let r = z.rayon * projection.echelle
            let cercle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            let couleur = palette.zone(z)
            if z.id.isEmpty {
                ctx.stroke(cercle, with: .color(couleur.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            } else {
                ctx.fill(cercle, with: .radialGradient(Gradient(colors: [couleur.opacity(0.26), couleur.opacity(0.08)]),
                                                       center: c, startRadius: 0, endRadius: r))
                ctx.stroke(cercle, with: .color(couleur.opacity(0.45)), lineWidth: 1)
            }
            let prefixes = z.prefixes.map(\.description).joined(separator: ", ")
            let titre: String
            if z.id.isEmpty {
                titre = String(localized: "Sans partition connue")
            } else if prefixes.isEmpty {
                titre = String(localized: "Partition \(z.id)")
            } else {
                titre = String(localized: "Partition \(z.id) · \(prefixes)")
            }
            ctx.draw(Text(titre).font(.caption).foregroundStyle(couleur.opacity(0.95)),
                     at: CGPoint(x: c.x, y: c.y - r - 6), anchor: .bottom)
        }
    }

    private func dessinerLiens(_ ctx: inout GraphicsContext) {
        let positions = Dictionary(disposition.noeuds.map { ($0.id, $0.position) }, uniquingKeysWith: { a, _ in a })
        for l in disposition.liens {
            guard let a = positions[l.de], let b = positions[l.vers] else { continue }
            var p = Path()
            p.move(to: projection.vue(a))
            p.addLine(to: projection.vue(b))
            let eclaire = l.de == selection || l.de == survol
            ctx.stroke(p, with: .color(eclaire ? palette.lienEclaire : palette.lien),
                       style: StrokeStyle(lineWidth: eclaire ? 1.6 : 1, dash: [2, 4]))
        }
    }

    private func dessinerNoeuds(_ ctx: inout GraphicsContext) {
        let chefs = Set(reseau.partitions.compactMap { $0.chef?.instance })
        let principales = Set(disposition.zones.filter(\.principale).map(\.id))
        let centres = Dictionary(disposition.zones.map { ($0.id, $0.centre) }, uniquingKeysWith: { a, _ in a })
        for n in disposition.noeuds {
            let c = projection.vue(n.position)
            // Les noeuds suivent le zoom, sans enfler dans une grande fenetre.
            let r = max(n.rayon * min(projection.echelle, 1.1), 3)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            var libelle: String
            switch n.genre {
            case .centre, .routeur:
                let couleur = palette.routeur(principale: principales.contains(n.zone))
                ctx.drawLayer { l in
                    l.addFilter(.shadow(color: couleur.opacity(0.8), radius: n.genre == .centre ? 10 : 5))
                    l.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [.white.opacity(0.9), couleur]),
                                                                        center: CGPoint(x: c.x - r / 3, y: c.y - r / 3),
                                                                        startRadius: 0, endRadius: r * 1.3))
                }
                libelle = nomsRouteurs[n.id] ?? n.id
                if chefs.contains(n.id) { libelle += " 👑" }
            case .appareil:
                let a = appareils[n.id]
                let couleur = palette.appareil(a?.etat ?? .inconnu)
                if a?.etat == .disparu {
                    ctx.stroke(Path(ellipseIn: rect), with: .color(couleur), lineWidth: 2)
                } else {
                    ctx.drawLayer { l in
                        l.addFilter(.shadow(color: couleur.opacity(0.8), radius: 4))
                        l.fill(Path(ellipseIn: rect), with: .color(couleur))
                    }
                }
                libelle = a?.nom ?? n.id
                if a?.endormi == true { libelle += " 🔋" }
                if a?.etat == .sansAdresse || a?.etat == .disparu { libelle += " ⚠︎" }
            }
            if n.id == selection {
                ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(palette.selection), lineWidth: 2)
            }
            let fort = n.id == selection || n.id == survol
            let texte = Text(libelle).font(n.genre == .appareil ? .caption2 : .caption)
                .fontWeight(fort ? .semibold : .regular).foregroundStyle(fort ? palette.selection : palette.texte)
            // Libelle vers l'exterieur de la zone : a droite ou a gauche sur les
            // cotes, au-dessus ou au-dessous en haut et en bas ; sous le centre.
            let centreZone = centres[n.zone] ?? n.position
            let angle = atan2(n.position.y - centreZone.y, n.position.x - centreZone.x)
            if n.genre == .centre {
                ctx.draw(texte, at: CGPoint(x: c.x, y: c.y + r + 4), anchor: .top)
            } else if cos(angle) > 0.35 {
                ctx.draw(texte, at: CGPoint(x: c.x + r + 4, y: c.y), anchor: .leading)
            } else if cos(angle) < -0.35 {
                ctx.draw(texte, at: CGPoint(x: c.x - r - 4, y: c.y), anchor: .trailing)
            } else if sin(angle) < 0 {
                ctx.draw(texte, at: CGPoint(x: c.x, y: c.y - r - 3), anchor: .bottom)
            } else {
                ctx.draw(texte, at: CGPoint(x: c.x, y: c.y + r + 3), anchor: .top)
            }
        }
    }
}
```

`MaillageThread/Vues/Graphe/FenetreGraphe.swift` (fenêtre, barre d'outils, bandeau, état vide, appareils IP, surnom) :

```swift
import MaillageCoeur
import SwiftUI

/// Noeud choisi pour une feuille (surnom).
struct NoeudChoisi: Identifiable {
    let id: String
}

/// Fenetre du graphe : le graphe occupe toute la fenetre ; barre d'outils,
/// bandeau d'alerte et fiche flottent par-dessus, en verre.
struct FenetreGraphe: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.colorScheme) private var apparence
    /// `--args -selection <id>` : fiche ouverte au lancement (captures d'ecran).
    @State private var selection: String? = UserDefaults.standard.string(forKey: "selection")
    @State private var survol: String?
    @State private var zoom: CGFloat = 1
    @State private var zoomEnCours: CGFloat = 1
    @State private var decalage: CGSize = .zero
    @State private var decalageEnCours: CGSize = .zero
    @State private var aRenommer: NoeudChoisi?

    var body: some View {
        let palette = Palette(sombre: apparence == .dark)
        ZStack {
            RadialGradient(gradient: palette.fond, center: UnitPoint(x: 0.3, y: 0.35), startRadius: 0, endRadius: 900)
                .ignoresSafeArea()
            if let r = surveillance.reseau {
                graphe(r, palette)
            } else {
                EtatVide()
            }
            VStack(spacing: 10) {
                BarreOutils()
                if let r = surveillance.reseau, r.estScinde {
                    BandeauScission(reseau: r)
                }
                Spacer()
                if let selection {
                    FicheNoeud(id: selection, aRenommer: $aRenommer) { self.selection = nil }
                }
            }
            .padding(16)
        }
        .frame(minWidth: 820, minHeight: 560)
        .sheet(item: $aRenommer) { FeuilleRenommer(id: $0.id) }
        .fenetreDeLApp()
    }

    private func graphe(_ r: Reseau, _ palette: Palette) -> some View {
        let affiches = surveillance.appareilsAffiches(pour: r)
        let disposition = Disposition(reseau: r, appareils: affiches)
        let parId = Dictionary(affiches.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let nomsRouteurs = Dictionary(r.routeurs.map { ($0.instance, surveillance.nom($0)) }, uniquingKeysWith: { a, _ in a })
        return GeometryReader { geo in
            let projection = Projection(cadre: disposition.cadre, taille: geo.size,
                                        marges: (haut: r.estScinde ? 110 : 70, bas: selection == nil ? 30 : 190, cotes: 60),
                                        zoom: zoom * zoomEnCours,
                                        decalage: CGSize(width: decalage.width + decalageEnCours.width,
                                                         height: decalage.height + decalageEnCours.height))
            GrapheCanvas(disposition: disposition, reseau: r, appareils: parId, nomsRouteurs: nomsRouteurs,
                         projection: projection, selection: selection, survol: survol, palette: palette)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let p): survol = disposition.noeud(a: projection.plan(p))?.id
                    case .ended: survol = nil
                    }
                }
                .onTapGesture(count: 2) {
                    zoom = 1
                    decalage = .zero
                }
                .simultaneousGesture(SpatialTapGesture().onEnded { v in
                    selection = disposition.noeud(a: projection.plan(v.location))?.id
                })
                .gesture(MagnifyGesture()
                    .onChanged { zoomEnCours = $0.magnification }
                    .onEnded { v in
                        zoom = min(max(zoom * v.magnification, 0.4), 5)
                        zoomEnCours = 1
                    })
                .simultaneousGesture(DragGesture(minimumDistance: 4)
                    .onChanged { decalageEnCours = $0.translation }
                    .onEnded { v in
                        decalage.width += v.translation.width
                        decalage.height += v.translation.height
                        decalageEnCours = .zero
                    })
        }
    }
}

/// Barre d'outils flottante : reseau, appareils IP, journal, rafraichir.
struct BarreOutils: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.openWindow) private var openWindow
    @State private var appareilsIP = false

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 6) {
                Menu {
                    ForEach(surveillance.instantane?.reseaux ?? []) { r in
                        Button(r.nom) { surveillance.reseauChoisi = r.id }
                    }
                } label: {
                    Text(surveillance.reseau?.nom ?? String(localized: "Aucun réseau Thread"))
                }
                .menuStyle(.button)
                .buttonStyle(.glass)
                .fixedSize()
                Button {
                    appareilsIP = true
                } label: {
                    Text("Appareils IP · \(surveillance.instantane?.appareilsIP.count ?? 0)")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $appareilsIP) { ListeAppareilsIP() }
                Button("Journal") {
                    openWindow(id: "journal")
                }
                .buttonStyle(.glass)
                Button {
                    surveillance.rafraichir()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)
                .help("Rafraîchir")
            }
        }
    }
}

/// Bandeau ambre d'un reseau scinde : depuis quand (ou constate au lancement), et qui est a part.
struct BandeauScission: View {
    @Environment(Surveillance.self) private var surveillance
    let reseau: Reseau

    var body: some View {
        Label(texte, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(.orange.opacity(0.35)), in: .capsule)
    }

    private var texte: String {
        let n = reseau.partitions.count
        let aPart = reseau.partitions.dropFirst().flatMap(\.routeurs).map { surveillance.nom($0) }.joined(separator: ", ")
        guard let e = surveillance.derniereScission(reseau) else {
            return String(localized: "Réseau scindé en \(n) partitions · à part : \(aPart)")
        }
        let quand = e.date.formatted(date: .abbreviated, time: .shortened)
        if e.constate {
            return String(localized: "Réseau scindé en \(n) partitions, constaté le \(quand) · à part : \(aPart)")
        }
        return String(localized: "Réseau scindé en \(n) partitions depuis le \(quand) · à part : \(aPart)")
    }
}

/// Ecran d'attente ou d'erreur, quand il n'y a pas de reseau a dessiner.
struct EtatVide: View {
    @Environment(Surveillance.self) private var surveillance

    var body: some View {
        if surveillance.etatEcoute == .reseauLocalRefuse {
            ContentUnavailableView {
                Label("Accès au réseau local refusé", systemImage: "network.slash")
            } description: {
                Text("Autorisez Maillage Thread dans Réglages Système › Confidentialité et sécurité › Réseau local.")
            } actions: {
                Button("Ouvrir les Réglages Système") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } else if surveillance.instantane != nil {
            ContentUnavailableView("Aucun réseau Thread visible sur ce réseau local",
                                   systemImage: "point.3.connected.trianglepath.dotted")
        } else {
            ProgressView("Écoute du réseau local…")
        }
    }
}

/// Appareils du reseau local, hors Thread.
struct ListeAppareilsIP: View {
    @Environment(Surveillance.self) private var surveillance

    var body: some View {
        let appareils = surveillance.instantane?.appareilsIP ?? []
        VStack(alignment: .leading, spacing: 10) {
            Text("Appareils du réseau local (hors Thread)").font(.headline)
            if appareils.isEmpty {
                Text("Aucun").foregroundStyle(.secondary)
            }
            ForEach(appareils) { a in
                VStack(alignment: .leading, spacing: 2) {
                    Text(surveillance.nom(a))
                    Text((a.adresses.map(\.description) + a.adressesIPv4).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
        .frame(width: 380, alignment: .leading)
    }
}

/// Surnom d'un noeud : reste sur ce Mac, passe avant le nom de Maison.
struct FeuilleRenommer: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.dismiss) private var fermer
    let id: String
    @State private var texte = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Renommer « \(id) »").font(.headline)
            TextField("Surnom", text: $texte)
            Text("Le surnom reste sur ce Mac et passe avant le nom de Maison.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Retirer le surnom") {
                    surveillance.renommer(id, en: nil)
                    fermer()
                }
                Spacer()
                Button("Annuler", role: .cancel) { fermer() }
                Button("Enregistrer") {
                    surveillance.renommer(id, en: texte)
                    fermer()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear { texte = surveillance.noms.surnoms[id] ?? "" }
    }
}
```

`MaillageThread/Vues/Graphe/FicheNoeud.swift` :

```swift
import MaillageCoeur
import SwiftUI

/// Fiche du noeud choisi : carte de verre en bas de la fenetre.
struct FicheNoeud: View {
    @Environment(Surveillance.self) private var surveillance
    let id: String
    @Binding var aRenommer: NoeudChoisi?
    var fermer: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            if let r = surveillance.instantane?.routeur(id) {
                colonnesRouteur(r)
            } else if let a = surveillance.appareil(id) {
                colonnesAppareil(a)
            } else {
                Text("Ce nœud n'est plus visible.").foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    fermer()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .help("Fermer")
                Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                    .buttonStyle(.glass)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: Appareil

    @ViewBuilder
    private func colonnesAppareil(_ a: Appareil) -> some View {
        let disparu = surveillance.suivi.disparus[a.id] != nil
        let maison = surveillance.accessoire(a)
        VStack(alignment: .leading, spacing: 4) {
            Text(surveillance.nom(a)).font(.title3.weight(.semibold))
            let description = [maison?.piece, maison?.fabricant ?? a.hap?.modele, maison?.modele]
                .compactMap { $0 }.joined(separator: " · ")
            if !description.isEmpty {
                Text(description).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Circle().fill(couleur(a, disparu: disparu)).frame(width: 8, height: 8)
                Text(etat(a, disparu: disparu))
                if let vu = vuLe(a, disparu: disparu) {
                    Text("· vu \(Self.relatif(vu, surveillance.maintenant))").foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 200, alignment: .leading)
        VStack(alignment: .leading, spacing: 4) {
            Text(genre(a)).foregroundStyle(.secondary)
            if !a.fabriques.isEmpty {
                Text("Fabriques : \(a.fabriques.count)").foregroundStyle(.secondary)
            }
            ForEach(a.adresses.prefix(2), id: \.self) { ad in
                Text(ad.description).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Text(a.id).font(.caption.monospaced()).foregroundStyle(.tertiary).textSelection(.enabled)
        }
        colonneJournal(partition: a.partition ?? surveillance.suivi.dernieresPartitions[a.id], prefixe: a.prefixe)
    }

    private func etat(_ a: Appareil, disparu: Bool) -> String {
        if disparu { return String(localized: "disparu") }
        switch a.etat {
        case .joignable: return String(localized: "joignable")
        case .partitionCoupee: return String(localized: "isolé (partition coupée)")
        case .sansAdresse: return String(localized: "sans adresse")
        case .inconnu: return String(localized: "partition inconnue")
        }
    }

    private func couleur(_ a: Appareil, disparu: Bool) -> Color {
        if disparu { return .red }
        switch a.etat {
        case .joignable: return .green
        case .partitionCoupee: return .orange
        case .sansAdresse: return .red
        case .inconnu: return .gray
        }
    }

    /// "il y a 12 secondes", "maintenant".
    static func relatif(_ d: Date, _ reference: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.dateTimeStyle = .named
        f.unitsStyle = .full
        return f.localizedString(for: d, relativeTo: reference)
    }

    /// Present : le dernier releve ; disparu : sa premiere absence.
    private func vuLe(_ a: Appareil, disparu: Bool) -> Date? {
        if disparu { return surveillance.evenements(de: a.id).first { $0.type == .appareilDisparu }?.date }
        return surveillance.dernierReleve?.date
    }

    private func genre(_ a: Appareil) -> String {
        var morceaux: [String] = []
        if !a.instances.isEmpty { morceaux.append("Matter") }
        if a.hap != nil { morceaux.append("HomeKit") }
        if a.endormi {
            if let sii = a.proprietes?.sii {
                morceaux.append(String(localized: "endormi (réveil \(sii / 1000) s)"))
            } else {
                morceaux.append(String(localized: "endormi"))
            }
        }
        return morceaux.joined(separator: " · ")
    }

    // MARK: Routeur

    @ViewBuilder
    private func colonnesRouteur(_ r: RouteurBordure) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(surveillance.nom(r)).font(.title3.weight(.semibold))
            let description = [r.fabricant, r.modele, r.versionThread.map { "Thread \($0)" }].compactMap { $0 }
                .joined(separator: " · ")
            Text(description).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Circle().fill(.blue).frame(width: 8, height: 8)
                Text(role(r))
                if let bbr = bbr(r) { Text("· \(bbr)").foregroundStyle(.secondary) }
            }
        }
        .frame(minWidth: 200, alignment: .leading)
        VStack(alignment: .leading, spacing: 4) {
            Text("Routeur de bordure").foregroundStyle(.secondary)
            if let nn = r.nomReseau { Text("Réseau \(nn)").foregroundStyle(.secondary) }
            ForEach(r.adressesLien, id: \.self) { ad in
                Text(ad.description).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        colonneJournal(partition: r.partition, prefixe: r.prefixeOMR)
    }

    private func role(_ r: RouteurBordure) -> String {
        guard let role = r.role else { return String(localized: "rôle inconnu (Thread \(r.versionThread ?? "?"))") }
        return TexteEvenement.role(role.rawValue)
    }

    private func bbr(_ r: RouteurBordure) -> String? {
        guard let e = r.etat, e.bbrActif else { return nil }
        return e.bbrPrimaire ? String(localized: "BBR primaire") : String(localized: "BBR actif")
    }

    // MARK: Journal du noeud

    private func colonneJournal(partition: String?, prefixe: PrefixeIPv6?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let partition {
                Text("Partition \(partition)").foregroundStyle(.secondary)
            }
            if let prefixe {
                Text(prefixe.description).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            ForEach(surveillance.evenements(de: id)) { e in
                Text("\(TexteEvenement.quand(e)) · \(TexteEvenement.titre(e))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageThreadTests`
Expected: PASS, `✔ Test run with 7 tests in 5 suites passed`. La fenêtre ne s'ouvre qu'à la tâche 17 (scènes de l'app).

- [ ] **Step 5: Commit**

```bash
git add MaillageThread/Vues MaillageThreadTests/GrapheTests.swift
git commit -m "Dessiner le graphe en Canvas, avec barre, bandeau et fiche en verre

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Fenêtre du journal

**Files:**
- Create: `MaillageThread/Vues/Journal/FenetreJournal.swift`
- Test: `MaillageThreadTests/JournalVueTests.swift`

**Interfaces:**
- Consumes: `Surveillance`, `TexteEvenement`, `LigneJournal`, `Gravite`, `TypeEvenement`, `View.fenetreDeLApp()`.
- Produces: `FamilleEvenement` (`toutes`, `reseau`, `routeurs`, `prefixes`, `appareils`, `titre`, `contient(_:)`) ; `FiltreJournal(famille:graviteMinimale:recherche:)` (`appliquer(_:)`) ; `FenetreJournal` (fenêtre `journal`, scène déclarée à la tâche 17) ; `LigneJournalVue(ligne:)`.

- [ ] **Step 1: Écrire le test**

`MaillageThreadTests/JournalVueTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Journal : filtre des lignes")
struct JournalVueTests {
    @Test func filtreDuJournal() {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let lignes = s.lignesJournal
        #expect(FiltreJournal().appliquer(lignes).count == 6)
        #expect(FiltreJournal(famille: .appareils).appliquer(lignes).count == 1, "la ligne des pertes")
        #expect(FiltreJournal(famille: .prefixes).appliquer(lignes).count == 2)
        #expect(FiltreJournal(graviteMinimale: .alerte).appliquer(lignes).map { $0.evenements.first?.type }
                == [.reseauScinde])
        #expect(FiltreJournal(recherche: "prise bureau").appliquer(lignes).count == 1, "nom d'un appareil du groupe")
        #expect(FiltreJournal(recherche: "4B36A2B7FEFB200B").appliquer(lignes).isEmpty == false, "identifiant du reseau")
        #expect(FiltreJournal(recherche: "introuvable").appliquer(lignes).isEmpty)
        #expect(FamilleEvenement.reseau.contient(.veille))
        #expect(!FamilleEvenement.routeurs.contient(.appareilDisparu))
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageThreadTests/JournalVueTests`
Expected: FAIL à la compilation (`cannot find 'FiltreJournal' in scope`).

- [ ] **Step 3: Écrire la fenêtre**

`MaillageThread/Vues/Journal/FenetreJournal.swift` :

```swift
import MaillageCoeur
import SwiftUI

/// Familles d'evenements, pour le filtre du journal.
enum FamilleEvenement: String, CaseIterable, Identifiable {
    case toutes, reseau, routeurs, prefixes, appareils

    var id: String { rawValue }

    var titre: String {
        switch self {
        case .toutes: String(localized: "Tous")
        case .reseau: String(localized: "Réseau")
        case .routeurs: String(localized: "Routeurs")
        case .prefixes: String(localized: "Préfixes")
        case .appareils: String(localized: "Appareils")
        }
    }

    func contient(_ t: TypeEvenement) -> Bool {
        switch self {
        case .toutes:
            true
        case .reseau:
            [.surveillanceDemarree, .veille, .reseauScinde, .reseauReuni, .chefChange, .bbrPrimaireChange,
             .jeuActifChange].contains(t)
        case .routeurs:
            [.routeurApparu, .routeurDisparu, .routeurRoleChange, .routeurNouvelleAdresseLien].contains(t)
        case .prefixes:
            [.prefixeNouveau, .prefixeRetire].contains(t)
        case .appareils:
            [.appareilNouveau, .appareilDisparu, .appareilRevenu, .appareilSansAdresse, .appareilChangePartition].contains(t)
        }
    }
}

/// Filtre du journal : famille, gravite minimale, recherche dans le titre et le sujet.
struct FiltreJournal: Equatable {
    var famille: FamilleEvenement = .toutes
    var graviteMinimale: Gravite = .info
    var recherche = ""

    func appliquer(_ lignes: [LigneJournal]) -> [LigneJournal] {
        let r = recherche.trimmingCharacters(in: .whitespaces)
        return lignes.filter { l in
            let ev = l.evenements
            guard ev.contains(where: { famille.contient($0.type) }), l.gravite >= graviteMinimale else { return false }
            guard !r.isEmpty else { return true }
            return TexteEvenement.titre(l).localizedCaseInsensitiveContains(r)
                || ev.contains { ($0.sujet?.id ?? "").localizedCaseInsensitiveContains(r)
                    || ($0.sujet?.nom ?? "").localizedCaseInsensitiveContains(r) }
        }
    }
}

/// Fenetre du journal : evenements dates, filtres par famille et gravite, recherche.
struct FenetreJournal: View {
    @Environment(Surveillance.self) private var surveillance
    @State private var filtre = FiltreJournal()

    var body: some View {
        let lignes = filtre.appliquer(surveillance.lignesJournal)
        List(lignes) { ligne in
            LigneJournalVue(ligne: ligne)
        }
        .overlay {
            if lignes.isEmpty {
                ContentUnavailableView("Aucun événement", systemImage: "list.bullet.rectangle")
            }
        }
        .searchable(text: $filtre.recherche)
        .toolbar {
            Picker("Famille", selection: $filtre.famille) {
                ForEach(FamilleEvenement.allCases) { Text($0.titre).tag($0) }
            }
            Picker("Gravité", selection: $filtre.graviteMinimale) {
                Text("Tout").tag(Gravite.info)
                Text("Attention et alertes").tag(Gravite.attention)
                Text("Alertes").tag(Gravite.alerte)
            }
        }
        .navigationTitle("Journal")
        .frame(minWidth: 560, minHeight: 360)
        .fenetreDeLApp()
    }
}

/// Une ligne : pastille de gravite, titre, quand ; le detail des pertes regroupees.
struct LigneJournalVue: View {
    let ligne: LigneJournal

    var body: some View {
        switch ligne {
        case .evenement(let e):
            contenu(TexteEvenement.titre(e), quand: TexteEvenement.quand(e), gravite: e.gravite)
        case .pertes(let pertes):
            DisclosureGroup {
                ForEach(pertes) { e in
                    Text("\(TexteEvenement.heure(e.date)) · \(TexteEvenement.titre(e))")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } label: {
                contenu(TexteEvenement.titre(ligne), quand: pertes.first.map(TexteEvenement.quand) ?? "",
                        gravite: ligne.gravite)
            }
        }
    }

    private func contenu(_ titre: String, quand: String, gravite: Gravite) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(Self.couleur(gravite)).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(titre)
                Text(quand).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    static func couleur(_ g: Gravite) -> Color {
        switch g {
        case .info: .secondary
        case .attention: .orange
        case .alerte: .red
        }
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh MaillageThreadTests`
Expected: PASS, `✔ Test run with 8 tests in 6 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add MaillageThread/Vues/Journal MaillageThreadTests/JournalVueTests.swift
git commit -m "Afficher le journal : lignes regroupees, filtres, recherche

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 17: Barre des menus, réglages, ouverture à la connexion, scènes de l'app

**Files:**
- Create: `MaillageThread/Surveillance/OuvertureSession.swift`, `MaillageThread/Vues/MenuBarre.swift`, `MaillageThread/Vues/FenetreReglages.swift`
- Modify: `MaillageThread/MaillageThreadApp.swift` (remplacé en entier)
- Test: `MaillageThreadTests/MenuTests.swift`

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces: `OuvertureSession` (`@MainActor @Observable` ; `etat`, `active`, `approbationRequise`, `erreur`, `basculer(_:)`, `proposerAuPremierLancement(preferences:)`, `ouvrirReglagesSysteme()`) ; `IconeBarre(ouvrirGraphe:)` (`static image(alerte:) -> NSImage`) ; `MenuBarre` ; `FenetreReglages` ; `MaillageThreadApp` (scènes `MenuBarExtra` style fenêtre, `Window` `graphe` et `journal` non ouvertes au lancement, `Settings` ; `--args -demo`).

- [ ] **Step 1: Écrire le test**

`MaillageThreadTests/MenuTests.swift` :

```swift
import Foundation
import Testing
@testable import MaillageThread

@MainActor
@Suite("Barre des menus : icone")
struct MenuTests {
    @Test func icone() {
        #expect(IconeBarre.image(alerte: false).isTemplate)
        #expect(!IconeBarre.image(alerte: true).isTemplate, "orange : pas une image modele")
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageThreadTests/MenuTests`
Expected: FAIL à la compilation (`cannot find 'IconeBarre' in scope`).

- [ ] **Step 3: Écrire le code**

`MaillageThread/Surveillance/OuvertureSession.swift` :

```swift
import Foundation
import Observation
import ServiceManagement

/// Ouverture a la connexion (SMAppService) : proposee une fois au premier
/// lancement, puis a la main dans le menu et les reglages.
@MainActor
@Observable
final class OuvertureSession {
    private(set) var etat: SMAppService.Status = SMAppService.mainApp.status
    private(set) var erreur: String?

    static let clePremierLancement = "ouvertureSessionProposee"

    var active: Bool { etat == .enabled }
    var approbationRequise: Bool { etat == .requiresApproval }

    func basculer(_ oui: Bool) {
        do {
            if oui {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            erreur = nil
        } catch {
            erreur = error.localizedDescription
        }
        etat = SMAppService.mainApp.status
    }

    /// Au premier lancement : ouvrir a la connexion (choix de la spec), une seule fois.
    func proposerAuPremierLancement(preferences: UserDefaults = .standard) {
        guard !preferences.bool(forKey: Self.clePremierLancement) else { return }
        preferences.set(true, forKey: Self.clePremierLancement)
        if etat == .notRegistered { basculer(true) }
    }

    func ouvrirReglagesSysteme() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
```

`MaillageThread/Vues/MenuBarre.swift` :

```swift
import AppKit
import MaillageCoeur
import SwiftUI

/// Icone de la barre des menus : orange quand il y a une alerte. Ouvre le
/// graphe au lancement quand on le lui demande (mode demo, premier lancement).
struct IconeBarre: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.openWindow) private var openWindow
    let ouvrirGraphe: Bool
    private static var grapheOuvert = false

    var body: some View {
        Image(nsImage: Self.image(alerte: surveillance.alerte))
            .task {
                guard ouvrirGraphe, !Self.grapheOuvert else { return }
                Self.grapheOuvert = true
                openWindow(id: "graphe")
                NSApp.activate()
            }
    }

    static func image(alerte: Bool) -> NSImage {
        let base = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted",
                           accessibilityDescription: "Maillage Thread") ?? NSImage()
        guard alerte, let orange = base.withSymbolConfiguration(.init(paletteColors: [.systemOrange])) else {
            base.isTemplate = true
            return base
        }
        orange.isTemplate = false
        return orange
    }
}

/// Contenu de la barre des menus : etat d'un coup d'oeil, 3 derniers
/// evenements, et les actions.
struct MenuBarre: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(OuvertureSession.self) private var ouverture
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            entete
            if surveillance.etatEcoute == .reseauLocalRefuse {
                Label("Accès au réseau local refusé", systemImage: "network.slash")
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            Divider()
            ForEach(surveillance.lignesJournal.prefix(3)) { l in
                VStack(alignment: .leading, spacing: 1) {
                    Text(TexteEvenement.titre(l)).font(.callout).lineLimit(2)
                    Text(l.evenements.first.map(TexteEvenement.quand) ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }
            Divider()
            Group {
                Button("Ouvrir le graphe") { ouvrir("graphe") }
                Button("Journal…") { ouvrir("journal") }
                Toggle("Ouvrir à la connexion", isOn: Binding(get: { ouverture.active }, set: { ouverture.basculer($0) }))
                    .toggleStyle(.checkbox)
                if ouverture.approbationRequise {
                    Button("Approuver dans Réglages Système…") { ouverture.ouvrirReglagesSysteme() }
                }
                Button("Réglages…") {
                    NSApp.activate()
                    openSettings()
                }
                Button("Quitter Maillage Thread") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
    }

    @ViewBuilder
    private var entete: some View {
        let alerte = surveillance.alerte
        HStack(spacing: 8) {
            Image(systemName: alerte ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(alerte ? .orange : .green)
            Text(titre).font(.headline)
        }
        if let r = surveillance.resume {
            Text("\(r.nom) · partitions : \(r.partitions)").font(.caption).foregroundStyle(.secondary)
            Text("Routeurs : \(r.routeurs) · appareils : \(r.appareils) · injoignables : \(r.injoignables)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if surveillance.mode == .demo {
            Text("Mode démo : panne du 27/09 rejouée").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var titre: String {
        if surveillance.instantane == nil { return String(localized: "Écoute du réseau local…") }
        guard let r = surveillance.reseau else { return String(localized: "Aucun réseau Thread visible") }
        if r.estScinde { return String(localized: "Réseau scindé") }
        return surveillance.alerte ? String(localized: "Alerte dans l'heure") : String(localized: "Réseau Thread normal")
    }

    private func ouvrir(_ id: String) {
        openWindow(id: id)
        NSApp.activate()
    }
}
```

`MaillageThread/Vues/FenetreReglages.swift` :

```swift
import AppKit
import MaillageCoeur
import SwiftUI
import UniformTypeIdentifiers

/// Reglages : notifications par categorie, ouverture a la connexion, diagnostic et capture.
struct FenetreReglages: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(OuvertureSession.self) private var ouverture
    @AppStorage(Notifications.cle(.scission)) private var scission = CategorieAlerte.scission.parDefaut
    @AppStorage(Notifications.cle(.routeurDisparu)) private var routeurDisparu = CategorieAlerte.routeurDisparu.parDefaut
    @AppStorage(Notifications.cle(.pertes)) private var pertes = CategorieAlerte.pertes.parDefaut
    @AppStorage(Notifications.cle(.informations)) private var informations = CategorieAlerte.informations.parDefaut
    @State private var messageCapture: String?

    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Réseau scindé", isOn: $scission)
                Toggle("Routeur de bordure disparu", isOn: $routeurDisparu)
                Toggle("Au moins 3 appareils perdus en 10 min (une notification groupée)", isOn: $pertes)
                Toggle("Autres changements", isOn: $informations)
            }
            Section("Ouverture") {
                Toggle("Ouvrir à la connexion", isOn: Binding(get: { ouverture.active }, set: { ouverture.basculer($0) }))
                if ouverture.approbationRequise {
                    Button("Approuver dans Réglages Système…") { ouverture.ouvrirReglagesSysteme() }
                }
                if let e = ouverture.erreur {
                    Text(e).foregroundStyle(.red)
                }
            }
            Section("Diagnostic") {
                LabeledContent("Écoute", value: etatEcoute)
                LabeledContent("Dernier relevé",
                               value: surveillance.dernierReleve?.date.formatted(date: .abbreviated, time: .standard) ?? "—")
                if let a = surveillance.dernierReleve {
                    LabeledContent("Services vus", value: "_meshcop._udp \(a.routeurs.count) · _matter._tcp \(a.matter.count) · _hap._udp \(a.hap.count)")
                    LabeledContent("Préfixes du Mac", value: a.prefixesLocaux.joined(separator: ", "))
                }
                LabeledContent("Table de routage", value: routes)
                if let e = surveillance.erreurJournal {
                    LabeledContent("Journal", value: e)
                }
                HStack {
                    Button("Enregistrer une capture…") { enregistrerCapture() }
                        .disabled(surveillance.dernierReleve == nil)
                    Button("Afficher le journal dans le Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting(
                            [Surveillance.dossierParDefaut.appendingPathComponent("Journal")])
                    }
                    .disabled(surveillance.mode == .demo)
                }
                if let messageCapture {
                    Text(messageCapture).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
    }

    private var etatEcoute: String {
        switch surveillance.etatEcoute {
        case .demarrage: String(localized: "démarrage")
        case .active: String(localized: "active")
        case .reseauLocalRefuse: String(localized: "accès au réseau local refusé")
        case .demo: String(localized: "mode démo")
        case .erreur(let m): m
        }
    }

    private var routes: String {
        switch surveillance.routesLisibles {
        case true?: String(localized: "lue")
        case false?: String(localized: "illisible : préfixes tirés des adresses")
        case nil: "—"
        }
    }

    private func enregistrerCapture() {
        guard let donnees = try? surveillance.captureJSON() else { return }
        let panneau = NSSavePanel()
        panneau.allowedContentTypes = [.json]
        panneau.nameFieldStringValue = "capture-maillage.json"
        guard panneau.runModal() == .OK, let url = panneau.url else { return }
        do {
            try donnees.write(to: url, options: .atomic)
            messageCapture = String(localized: "Capture enregistrée : \(url.lastPathComponent)")
        } catch {
            messageCapture = error.localizedDescription
        }
    }
}
```

`MaillageThread/MaillageThreadApp.swift` (remplace le squelette) :

```swift
import MaillageCoeur
import SwiftUI

/// App de la barre des menus : ecoute le reseau local en permanence, tient
/// le journal, notifie ; graphe et journal dans leurs fenetres.
/// `--args -demo` : rejoue la panne du 27/09, sans rien ecrire ni notifier.
@main
struct MaillageThreadApp: App {
    @State private var surveillance: Surveillance
    @State private var ouverture: OuvertureSession
    private let notifications = Notifications()
    private static let demo = CommandLine.arguments.contains("-demo")
    /// Le graphe s'ouvre au lancement en mode demo et au tout premier lancement
    /// (jamais a l'ouverture de session ensuite).
    private let ouvrirGraphe: Bool
    static let clePremierGraphe = "grapheDejaOuvert"

    init() {
        let s = Surveillance(mode: Self.demo ? .demo : .direct, dossier: Self.demo ? nil : Surveillance.dossierParDefaut)
        let o = OuvertureSession()
        _surveillance = State(initialValue: s)
        _ouverture = State(initialValue: o)
        let premier = !UserDefaults.standard.bool(forKey: Self.clePremierGraphe)
        ouvrirGraphe = !Surveillance.sousTests && (Self.demo || premier)
        guard !Surveillance.sousTests else { return }
        if !Self.demo {
            UserDefaults.standard.set(true, forKey: Self.clePremierGraphe)
            let n = notifications
            s.surAlertes = { n.presenter($0) }
            n.demanderAutorisation()
            o.proposerAuPremierLancement()
        }
        s.demarrer()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarre()
                .environment(surveillance)
                .environment(ouverture)
        } label: {
            IconeBarre(ouvrirGraphe: ouvrirGraphe)
                .environment(surveillance)
        }
        .menuBarExtraStyle(.window)

        Window("Maillage Thread", id: "graphe") {
            FenetreGraphe()
                .environment(surveillance)
        }
        .defaultSize(width: 1100, height: 760)
        .defaultLaunchBehavior(.suppressed)

        Window("Journal", id: "journal") {
            FenetreJournal()
                .environment(surveillance)
        }
        .defaultSize(width: 720, height: 560)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            FenetreReglages()
                .environment(surveillance)
                .environment(ouverture)
        }
    }
}
```

- [ ] **Step 4: Lancer les tests**

Run: `outils/tester.sh`
Expected: PASS, framework `✔ Test run with 57 tests in 12 suites passed`, app `✔ Test run with 9 tests in 7 suites passed`.

- [ ] **Step 5: Vérifier l'app en mode démo (sans réseau, rien d'écrit)**

```bash
APP="$HOME/Library/Developer/Xcode/DerivedData/maillage/Build/Products/Debug/Maillage Thread.app"
open -n "$APP" --args -demo -selection 86E7BD1A75F28E6D
```

Attendu, dans la fenêtre « Maillage Thread » (capture d'écran à joindre au rapport, par exemple `screencapture -x -o -l <numéro de fenêtre>`) :
- fond profond, zone bleue « Partition 73586B68 · fd19:961f:2db3::/64 » avec « Apple TV 4K 👑 » au centre et les quatre HomePod sur l'anneau intérieur ; zone ambre « Partition E2E79FFC · fd03:54f0:5de:1::/64 » à droite avec l'Aqara ;
- appareils verts, `1E5019DAC2638F92` en rouge plein avec ⚠︎, quatre disparus en anneau rouge (Prise bureau, Prise salon, Thermo chambre, Ampoule entrée), 🔋 sur les endormis ;
- barre d'outils en verre (réseau, « Appareils IP · 4 », « Journal », ↻), bandeau ambre « Réseau scindé en 2 partitions depuis le 27 sept. 2026 à 4:14 · à part : Aqara HubM100 #DFEB » (format de date du système) ;
- fiche de verre en bas : « Nuki Ultra », « Entrée · Nuki · Smart Lock Ultra », « ● joignable · vu maintenant », « Matter · endormi (réveil 6 s) », « Fabriques : 3 ».
Puis quitter l'app (menu de la barre des menus › Quitter Maillage Thread).

- [ ] **Step 6: Commit**

```bash
git add MaillageThread MaillageThreadTests/MenuTests.swift
git commit -m "Ajouter la barre des menus, les reglages et les scenes de l'app

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 18: Textes anglais et catalogue aligné sur le code

**Files:**
- Create: `outils/traductions/interface.json`
- Modify: `MaillageCoeurTests/CataloguesTests.swift` (remplacé en entier), `MaillageThread/Ressources/Localizable.xcstrings` (par les outils)

**Interfaces:**
- Consumes: les textes des tâches 12 à 17.
- Produces: catalogue de 117 clés, anglais complet ; test `codeEtCatalogueAlignes`.

- [ ] **Step 1: Écrire le test d'alignement**

`MaillageCoeurTests/CataloguesTests.swift` (remplace la version de la tâche 1) :

```swift
import Foundation
import Testing

/// Catalogues de textes de l'app, lus dans le depot. Ces tests vivent ici (et
/// non dans MaillageThreadTests) : les tests de l'app tournent dans l'app
/// sandboxee, qui ne peut pas lire le depot.
enum Catalogues {
    static let racine = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // MaillageCoeurTests
        .deletingLastPathComponent()  // racine du depot

    static let textes = racine.appendingPathComponent("MaillageThread/Ressources/Localizable.xcstrings")
    static let infoPlist = racine.appendingPathComponent("MaillageThread/Ressources/InfoPlist.xcstrings")

    static func entrees(_ chemin: URL) throws -> (source: String, cles: [String: [String: Any]]) {
        let d = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: chemin)) as? [String: Any])
        let cles = try #require(d["strings"] as? [String: [String: Any]])
        return (d["sourceLanguage"] as? String ?? "", cles)
    }

    /// Dossier des produits (`.../Build/Products/Debug`) : celui de ce paquet de test.
    private final class Ancre {}
    static var produits: URL { Bundle(for: Ancre.self).bundleURL.deletingLastPathComponent() }

    /// `.stringsdata` de l'app : `Build/Intermediates.noindex/MaillageThread.build/<config>/MaillageThread.build/Objects-normal/<arch>/`.
    static var stringsdata: [URL] {
        let config = produits.lastPathComponent
        let objets = produits.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Intermediates.noindex/MaillageThread.build")
            .appendingPathComponent(config)
            .appendingPathComponent("MaillageThread.build/Objects-normal")
        let fm = FileManager.default
        var fichiers: [URL] = []
        for arch in (try? fm.contentsOfDirectory(at: objets, includingPropertiesForKeys: nil)) ?? [] {
            for f in (try? fm.contentsOfDirectory(at: arch, includingPropertiesForKeys: nil)) ?? []
            where f.pathExtension == "stringsdata" {
                fichiers.append(f)
            }
        }
        return fichiers
    }

    static var stringsdataDisponibles: Bool { !stringsdata.isEmpty }

    /// Cles extraites du code de l'app (table Localizable).
    static func clesExtraites() throws -> Set<String> {
        var cles = Set<String>()
        for f in stringsdata {
            let d = try JSONSerialization.jsonObject(with: Data(contentsOf: f)) as? [String: Any]
            let tables = d?["tables"] as? [String: [[String: Any]]] ?? [:]
            for e in tables["Localizable"] ?? [] {
                if let k = e["key"] as? String { cles.insert(k) }
            }
        }
        return cles
    }

    /// Specificateurs d'un format, sans leur position (`%1$@` -> `@`), dans l'ordre.
    static func specificateurs(_ s: String) -> [String] {
        let motif = /%(?:\d+\$)?(lld|ld|d|@|lf|f|%)/
        return s.matches(of: motif).map { String($0.output.1) }
    }

    /// Unites de texte d'une localisation : simple, ou formes du pluriel.
    static func unites(_ loc: [String: Any]) -> [String: [String: Any]] {
        if let u = loc["stringUnit"] as? [String: Any] { return ["": u] }
        let pluriel = (loc["variations"] as? [String: Any])?["plural"] as? [String: [String: Any]] ?? [:]
        return pluriel.compactMapValues { $0["stringUnit"] as? [String: Any] }
    }
}

@Suite("Catalogues de textes (francais source, anglais complet)")
struct CataloguesTests {
    @Test(arguments: [Catalogues.textes, Catalogues.infoPlist])
    func chaqueCleATraductionAnglaise(_ chemin: URL) throws {
        let (source, cles) = try Catalogues.entrees(chemin)
        #expect(source == "fr", "le francais est la langue de developpement")
        #expect(!cles.isEmpty)
        for (cle, entree) in cles {
            #expect(entree["extractionState"] as? String != "stale", "cle perimee : \(cle)")
            let locs = entree["localizations"] as? [String: [String: Any]] ?? [:]
            let en = try #require(locs["en"], "pas d'anglais : \(cle)")
            let unites = Catalogues.unites(en)
            #expect(!unites.isEmpty, "anglais vide : \(cle)")
            if unites.keys.contains(where: { !$0.isEmpty }) {
                #expect(unites["one"] != nil && unites["other"] != nil, "pluriel incomplet : \(cle)")
            }
            let attendus = Catalogues.specificateurs(cle)
            for (forme, u) in unites {
                #expect(u["state"] as? String == "translated", "anglais non valide (\(forme)) : \(cle)")
                let valeur = u["value"] as? String ?? ""
                #expect(!valeur.isEmpty, "anglais vide (\(forme)) : \(cle)")
                #expect(Catalogues.specificateurs(valeur).sorted() == attendus.sorted(),
                        "specificateurs differents : \(cle) -> \(valeur)")
            }
        }
    }

    /// Le code et le catalogue vont ensemble : aucune cle du code ne manque,
    /// aucune cle du catalogue n'est morte (apres un changement de texte :
    /// outils/synchroniser-textes.sh puis outils/traduire.py).
    @Test(.enabled(if: Catalogues.stringsdataDisponibles, "produits de compilation introuvables"))
    func codeEtCatalogueAlignes() throws {
        let extraites = try Catalogues.clesExtraites()
        let catalogue = Set(try Catalogues.entrees(Catalogues.textes).cles.keys)
        #expect(!extraites.isEmpty)
        #expect(extraites.subtracting(catalogue).sorted() == [], "absentes du catalogue")
        #expect(catalogue.subtracting(extraites).sorted() == [], "inutilisees")
    }
}
```

- [ ] **Step 2: Lancer le test : échec attendu**

Run: `outils/tester.sh MaillageCoeurTests/CataloguesTests`
Expected: FAIL, `codeEtCatalogueAlignes` : clés « absentes du catalogue » (les textes des tâches 12 à 17) et « inutilisées » (`Quitter`).

- [ ] **Step 3: Synchroniser et traduire**

`outils/traductions/interface.json` :

```json
{
  "%@ : nouvelle adresse de lien (redémarrage probable)": "%@: new link-local address (probable restart)",
  "%@ : rôle %@ → %@": "%1$@: role %2$@ → %3$@",
  "%@ a disparu": "%@ disappeared",
  "%@ a rejoint la partition %@": "%1$@ joined partition %2$@",
  "%@ est apparu": "%@ appeared",
  "%@ est isolé dans la partition %@": "%1$@ is isolated in partition %2$@",
  "%@ est revenu": "%@ is back",
  "%@ n'a plus d'adresse": "%@ has no address anymore",
  "%@ · %@": "%1$@ · %2$@",
  "%@ · partitions : %lld": "%1$@ · partitions: %2$lld",
  "%@ — partition à part : %@": "%1$@ — separate partition: %2$@",
  "%lld appareils Thread perdus": "%lld Thread devices lost",
  "%lld appareils perdus entre %@ et %@": "%1$lld devices lost between %2$@ and %3$@",
  "Accès au réseau local refusé": "Local network access denied",
  "Afficher le journal dans le Finder": "Show Log in Finder",
  "Alerte dans l'heure": "Alert in the last hour",
  "Alertes": "Alerts",
  "Annuler": "Cancel",
  "Appareils": "Devices",
  "Appareils IP · %lld": "IP devices · %lld",
  "Appareils du réseau local (hors Thread)": "Local network devices (not Thread)",
  "Approuver dans Réglages Système…": "Approve in System Settings…",
  "Attention et alertes": "Warnings and alerts",
  "Au moins 3 appareils perdus en 10 min (une notification groupée)": "At least 3 devices lost within 10 min (one grouped notification)",
  "Aucun": "None",
  "Aucun réseau Thread": "No Thread network",
  "Aucun réseau Thread visible": "No Thread network visible",
  "Aucun réseau Thread visible sur ce réseau local": "No Thread network visible on this local network",
  "Aucun événement": "No events",
  "Autorisez Maillage Thread dans Réglages Système › Confidentialité et sécurité › Réseau local.": "Allow Maillage Thread in System Settings › Privacy & Security › Local Network.",
  "Autres changements": "Other changes",
  "BBR actif": "active BBR",
  "BBR primaire": "primary BBR",
  "Capture enregistrée : %@": "Capture saved: %@",
  "Ce nœud n'est plus visible.": "This node is no longer visible.",
  "Dernier relevé": "Last survey",
  "Diagnostic": "Diagnostics",
  "Enregistrer": "Save",
  "Enregistrer une capture…": "Save a Capture…",
  "Entre %@ et %@ : %@": "Between %1$@ and %2$@: %3$@",
  "Fabriques : %lld": "Fabrics: %lld",
  "Famille": "Category",
  "Fermer": "Close",
  "Gravité": "Severity",
  "Journal": "Log",
  "Journal…": "Log…",
  "Le surnom reste sur ce Mac et passe avant le nom de Maison.": "The nickname stays on this Mac and takes precedence over the Home name.",
  "Mac en veille": "Mac asleep",
  "Mac en veille de %@ à %@": "Mac asleep from %1$@ to %2$@",
  "Mode démo : panne du 27/09 rejouée": "Demo mode: replay of the September 27 outage",
  "Notifications": "Notifications",
  "Nouveau BBR primaire : %@ (avant : %@)": "New primary BBR: %1$@ (previously %2$@)",
  "Nouveau chef : %@ (avant : %@)": "New leader: %1$@ (previously %2$@)",
  "Nouveau préfixe %@": "New prefix %@",
  "Ouverture": "Startup",
  "Ouvrir le graphe": "Open Graph",
  "Ouvrir les Réglages Système": "Open System Settings",
  "Ouvrir à la connexion": "Open at Login",
  "Partition %@": "Partition %@",
  "Partition %@ · %@": "Partition %1$@ · %2$@",
  "Préfixe %@ retiré": "Prefix %@ withdrawn",
  "Préfixes": "Prefixes",
  "Préfixes du Mac": "Mac prefixes",
  "Quitter Maillage Thread": "Quit Maillage Thread",
  "Rafraîchir": "Refresh",
  "Renommer « %@ »": "Rename “%@”",
  "Renommer…": "Rename…",
  "Retirer le surnom": "Remove Nickname",
  "Routeur de bordure": "Border router",
  "Routeur de bordure disparu": "Border router disappeared",
  "Routeurs": "Routers",
  "Routeurs : %lld · appareils : %lld · injoignables : %lld": "Routers: %1$lld · devices: %2$lld · unreachable: %3$lld",
  "Réglages…": "Settings…",
  "Réseau": "Network",
  "Réseau %@": "Network %@",
  "Réseau %@ : nouveau jeu de paramètres actif": "Network %@: new active dataset",
  "Réseau %@ réuni": "Network %@ rejoined",
  "Réseau %@ scindé (constaté au lancement)": "Network %@ split (found at launch)",
  "Réseau %@ scindé en %@ partitions": "Network %1$@ split into %2$@ partitions",
  "Réseau Thread normal": "Thread network OK",
  "Réseau Thread scindé": "Thread network split",
  "Réseau scindé": "Network split",
  "Réseau scindé en %lld partitions depuis le %@ · à part : %@": "Network split into %1$lld partitions since %2$@ · separate: %3$@",
  "Réseau scindé en %lld partitions · à part : %@": "Network split into %1$lld partitions · separate: %2$@",
  "Réseau scindé en %lld partitions, constaté le %@ · à part : %@": "Network split into %1$lld partitions, found on %2$@ · separate: %3$@",
  "Sans partition connue": "No known partition",
  "Services vus": "Services seen",
  "Surnom": "Nickname",
  "Surveillance démarrée (routeurs : %@, appareils : %@)": "Monitoring started (routers: %1$@, devices: %2$@)",
  "Table de routage": "Routing table",
  "Tous": "All",
  "Tout": "Everything",
  "accès au réseau local refusé": "local network access denied",
  "active": "active",
  "chef": "leader",
  "disparu": "disappeared",
  "démarrage": "starting",
  "détaché": "detached",
  "endormi": "sleepy",
  "endormi (réveil %lld s)": "sleepy (wakes every %lld s)",
  "enfant": "child",
  "entre %@ et %@ (Mac en veille)": "between %1$@ and %2$@ (Mac asleep)",
  "illisible : préfixes tirés des adresses": "unreadable: prefixes taken from addresses",
  "inconnu": "unknown",
  "isolé (partition coupée)": "isolated (split partition)",
  "joignable": "reachable",
  "lue": "read",
  "mode démo": "demo mode",
  "partition inconnue": "unknown partition",
  "routeur": "router",
  "rôle inconnu (Thread %@)": "unknown role (Thread %@)",
  "sans adresse": "no address",
  "· %@": "· %@",
  "· vu %@": "· seen %@",
  "Écoute": "Listening",
  "Écoute du réseau local…": "Listening to the local network…"
}
```

```bash
outils/synchroniser-textes.sh
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json
```

`xcstringstool` ajoute les 116 clés du code et marque `Quitter` « stale » ; `traduire.py` retire la clé périmée et écrit français et anglais (spécificateurs numérotés dès qu'il y en a deux). Le catalogue compte alors 117 clés.

- [ ] **Step 4: Lancer tous les tests**

Run: `outils/tester.sh`
Expected: PASS, framework `✔ Test run with 58 tests in 12 suites passed`, app `✔ Test run with 9 tests in 7 suites passed`.

- [ ] **Step 5: Commit**

```bash
git add outils/traductions MaillageCoeurTests/CataloguesTests.swift MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Traduire l'interface en anglais et aligner le catalogue sur le code

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 19: README et vérification sur le vrai réseau (avec Djoko)

**Files:**
- Create: `README.md`, `README.fr.md`
- Modify: `docs/superpowers/specs/2026-09-28-maillage-thread-design.md` (résultats des vérifications du jour 1, en fin de section 6)

**Interfaces:**
- Consumes: l'app complète.
- Produces: la documentation ; les résultats du jour 1.

- [ ] **Step 1: Écrire les README**

`README.md` :

````markdown
**English** · [Français](README.fr.md)

# Maillage Thread

Native macOS menu bar app (SwiftUI, Liquid Glass) that shows the Thread
network as seen from the Mac: border routers, partitions and their leader,
OMR prefixes, Matter and HomeKit devices and the partition they sit in. It
keeps a log of changes (a split network, a border router that restarts or
disappears, devices lost) and notifies the alerts.

It was born from a real outage: on September 27, 2026, five Thread devices
stopped responding at 04:14. By hand, from the Mac, the leader (an Apple TV)
had published a new OMR prefix at 04:04 and an Aqara hub had ended up alone
in its own partition. The app shows that at a glance and remembers it.

## What the Mac can see

The Mac has no Thread radio: the app only **listens** to the local network.

| Source | Gives |
|---|---|
| `_meshcop._udp` (TXT) | border routers: network name and id (`nn`, `xp`), partition (`pt`), role (Thread 1.4 and later, `sb` bits 9-10), BBR, active dataset, published OMR prefix |
| `_matter._tcp` | one instance per device and fabric (`<fabric>-<node>`), grouped by host; `ICD`, or `SII` of 5 s or more: sleepy device |
| `_hap._udp` | HomeKit accessories (their name) |
| host addresses | OMR prefix → partition; local network → IP device; none → "no address" |
| Mac routing table | which border router routes which OMR prefix |

"Reachable" means *announced with a Thread address in the main partition*,
not "answers": the app never probes. A disappearance is only kept after 2
minutes of absence and is dated from the first absence. Real links (child →
parent, router ↔ router, link quality) will come from a dedicated ESP32-C6
probe (step 2, separate project).

## Build, test, run

Requirements: macOS 26 or later, Xcode 26 or later (developed with Xcode 27),
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
No third-party dependency. The Xcode project is generated: only `project.yml`
is tracked.

```sh
outils/tester.sh                                   # generate, build, all tests
outils/tester.sh MaillageCoeurTests/SuiviTests     # one suite
```

Build products go to `~/Library/Developer/Xcode/DerivedData/maillage`
(`DD` to change it). Swift 6 with complete strict concurrency, warnings as
errors.

Run: `Maillage Thread.app` in `…/DerivedData/maillage/Build/Products/Debug/`.
The app lives in the menu bar; the graph opens from its menu (and by itself on
the very first launch).

### Demo mode

```sh
open "…/Maillage Thread.app" --args -demo
open "…/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D   # card open
```

The demo replays the September 27 outage, rebuilt from the real survey of
September 28 (`docs/releves/2026-09-28/`): nothing is written, nothing is
notified. Home names in the demo are made up.

### Signing

`Signature.xcconfig` (tracked) signs ad hoc: the repository builds and tests
anywhere, without an Apple account, but the local network permission does
not survive a rebuild. To sign with your team, create `Local.xcconfig`
(ignored by git):

```
DEVELOPMENT_TEAM = <team, 10 characters>
CODE_SIGN_IDENTITY = Apple Development
```

## Texts: French and English

French is the development language (catalog keys are the French texts),
English is complete. After changing a text:

```sh
outils/tester.sh                      # build: the compiler extracts the keys
outils/synchroniser-textes.sh         # adds/marks keys in the catalog
python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/<file>.json
```

`CataloguesTests` checks that every key has its English and that code and
catalog match.

## Code

| Folder | Role |
|---|---|
| `MaillageCoeur/` | framework without UI: TXT decoding, snapshot (networks, partitions, prefixes, devices), tracking and log events, file log, names, graph layout, routing table; tested on the real survey and on the replayed outage |
| `MaillageThread/Recenseur/` | NWBrowser (three service types) and dns_sd (hosts, addresses) → `Annonces` |
| `MaillageThread/Surveillance/` | app model: surveys → tracking → log and notifications; sleep of the Mac; login item |
| `MaillageThread/Vues/` | menu bar, graph window (Canvas, glass overlays), log window, settings |
| `docs/releves/` | real surveys (the fixture of the tests and the demo) |
| `docs/superpowers/` | design (spec) and implementation plans |

Not in this step yet: Home names read through a Mac Catalyst helper (HomeKit
does not exist in native macOS). Without it, names are: nickname > HomeKit
name > host.
````

`README.fr.md` :

````markdown
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
| `_matter._tcp` | une instance par appareil et par fabrique (`<fabrique>-<nœud>`), regroupées par hôte ; `ICD`, ou `SII` d'au moins 5 s : appareil endormi |
| `_hap._udp` | accessoires HomeKit (leur nom) |
| adresses des hôtes | préfixe OMR → partition ; réseau local → appareil IP ; aucune → « sans adresse » |
| table de routage du Mac | quel routeur de bordure route quel préfixe OMR |

« Joignable » veut dire *annoncé avec une adresse Thread dans la partition
principale*, pas « répond » : l'app ne sonde jamais. Une disparition n'est
retenue qu'après 2 minutes d'absence et datée de la première absence. Les
vrais liens (enfant → parent, routeur ↔ routeur, qualité) viendront d'une
sonde ESP32-C6 dédiée (étape 2, projet séparé).

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
d'une compilation à l'autre. Pour signer avec son équipe, créer
`Local.xcconfig` (ignoré par git) :

```
DEVELOPMENT_TEAM = <équipe, 10 caractères>
CODE_SIGN_IDENTITY = Apple Development
```

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
| `MaillageThread/Recenseur/` | NWBrowser (trois types de service) et dns_sd (hôtes, adresses) → `Annonces` |
| `MaillageThread/Surveillance/` | modèle de l'app : relevés → suivi → journal et notifications ; veille du Mac ; ouverture à la connexion |
| `MaillageThread/Vues/` | barre des menus, fenêtre du graphe (Canvas, surcouches en verre), journal, réglages |
| `docs/releves/` | relevés réels (les données des tests et de la démo) |
| `docs/superpowers/` | conception (spec) et plans d'implémentation |

Pas encore dans cette étape : les noms de Maison, lus par un passeur Mac
Catalyst (HomeKit n'existe pas en macOS natif). Sans lui, les noms sont :
surnom > nom HomeKit > hôte.
````

- [ ] **Step 2: Lancer tous les tests**

Run: `outils/tester.sh`
Expected: PASS, 58 tests (framework) et 9 tests (app), `** TEST SUCCEEDED **`.

- [ ] **Step 3: Vérification du jour 1, sur le vrai réseau : par le contrôleur, avec Djoko présent (pas par un sous-agent)**

Lancer l'app sans `-demo` :

```bash
open -n "$HOME/Library/Developer/Xcode/DerivedData/maillage/Build/Products/Debug/Maillage Thread.app"
```

Djoko répond aux invites du système :
1. **Réseau local** : « Autoriser ». Refuser une fois d'abord (option) pour voir l'écran « Accès au réseau local refusé » et la ligne rouge du menu, puis autoriser dans Réglages Système › Confidentialité et sécurité › Réseau local.
2. **Notifications** : « Autoriser ».
3. **Ouverture à la connexion** : notification du système « élément ajouté » ; vérifier la case du menu.

À vérifier et à noter (le graphe s'ouvre au premier lancement) :
- le graphe montre le réseau réel (6 routeurs de bordure, partitions telles qu'elles sont ce jour-là) ; le menu donne le résumé ;
- Réglages › Diagnostic : « Table de routage » : **lue** ou **illisible** dans le bac à sable (point ouvert de la spec, section 6). Si elle est illisible, les préfixes restent attribués par élimination (test `sansTableDeRoutage`) ;
- Réglages › Diagnostic › « Enregistrer une capture… » : le fichier JSON se relit (`CodageJSON.decodeur()`), à garder dans `docs/releves/` si Djoko le veut ;
- une veille courte du Mac (menu Pomme › Suspendre, 1 min) : au réveil, une ligne « Mac en veille de … à … » dans le journal.

Ajouter les résultats à la fin de la section 6 de la spec (« Vérifié le … : table de routage lue/illisible dans le bac à sable ; … »).

- [ ] **Step 4: Commit**

```bash
git add README.md README.fr.md docs/superpowers/specs/2026-09-28-maillage-thread-design.md
git commit -m "Documenter l'app et noter les verifications du jour 1

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Couverture de la spec

| Spec | Tâches |
|---|---|
| 1. Architecture : `MaillageCoeur`, app, bac à sable, réseau local ; recenseur ; journal 90 jours ; notifications ; barre des menus, graphe, journal ; ouverture à la connexion | 1-11 ; 12 ; 9, 13 ; 14 ; 15-17 ; 17 |
| 1. Passeur Noms (Catalyst) | plan 2 |
| 2. Données : TXT MeshCoP, rôle seulement ≥ 1.4, réseaux et partitions, préfixes OMR (omr, routes, élimination), appareils, états, délais, noms par priorité | 3, 5, 6, 11, 12 |
| 3. Interface : graphe plein cadre en verre, bandeau (depuis / constaté à), fiche, disposition stable, disparus à leur place, zoom et déplacement, survol et clic ; barre des menus ; journal ; FR/EN ; mode clair | 10, 15, 16, 17, 18 |
| 4. Journal et notifications : événements, sursis de 2 min, pertes groupées sur 10 min, point de départ au lancement, veille, JSON Lines mensuel, catégories | 7, 8, 9, 13, 14, 17 |
| 5. Noms : contrat de `noms.json`, fabrique d'Apple, surnoms | 6 (modèle), 13, 15 (surnoms) ; passeur : plan 2 |
| 6. Permissions, erreurs visibles, tests sur relevés, panne rejouée, captures, mode démo, projet | 1, 12, 13, 15, 17, 18, 19 |
| 8. Faits réels du 28/09 | 4 (capture réelle), 5, 8 |

## Écarts d'exécution

Plan exécuté en sous-agents le 28/09/2026, sur la branche `etape-1`, relu
tâche par tâche puis dans son ensemble, et vérifié sur le vrai réseau avec
Djoko (tâche 19). Les blocs de code des tâches ci-dessus sont ceux du plan ;
ces commits les ont modifiés ensuite, chacun avec ses tests :

| Où | Écart | Commits |
|---|---|---|
| Tâche 1 | ligne `Co-Authored-By` du commit corrigée | `6aca310` |
| Tâche 12 | `rafraichir()` : nouvelle résolution différée au prochain relevé, sans effet avant la mise en route | `06c862f` |
| Tâche 13 | un appareil sans réseau va au réseau de sa dernière partition connue (deux réseaux Thread visibles) | `fab25e7` |
| Tâche 14 | refus et échecs des notifications consignés (`Logger`) | `0ecdbf7` |
| Tâche 17 | erreur d'une capture impossible à sérialiser affichée | `fab9f15` |
| Relecture finale | jamais d'instance non résolue dans un relevé, dernière cible gardée ; relevés vides ignorés ; point de départ propre à chaque réseau découvert ; premier relevé quand l'écoute est prête ; « Rien de visible sur le réseau local » ; identifiant figé des pertes groupées ; notifications au premier plan ; légende des pointillés ; test des textes sans sortie silencieuse | `e92a93d` à `05e1de7` |
| Tâche 19 | préfixe OMR partagé par deux partitions ; calme des annonces avant le premier relevé ; inscription à l'ouverture de session quand le système ne connaît pas l'app, case relue à l'affichage ; une notification par scission constatée (décision de Djoko) ; scission d'un réseau qui revient, texte « trouvé scindé » ; sursis repris au réveil | `871b74d` à `31f5154` |

À la fin : 82 tests (framework, 13 suites) et 21 tests (app, 10 suites).
