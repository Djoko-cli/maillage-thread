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
| `_matter._tcp` | one instance per device and fabric (`<fabric>-<node>`), grouped by host; `ICD`, or `SII` above 2 s: sleepy device |
| `_hap._udp` | HomeKit accessories (their name) |
| host addresses | OMR prefix → partition; local network → IP device; none → "no address" |
| Mac routing table | which border router routes which OMR prefix |

"Reachable" means *announced with a Thread address in the main partition*,
not "answers": the app never probes. A disappearance is only kept after 2
minutes of absence and is dated from the first absence. Real links (child →
parent, router ↔ router, link quality) will come from a dedicated ESP32-C6
probe (step 2, separate project).

Devices are placed by the OMR prefix of their address. When two partitions
announce the same OMR prefix (seen on September 28: an isolated hub had
picked up the main partition's prefix), the Mac cannot tell which side a
device is on: the app gives the prefix to the partition with the most border
routers and marks it "shared" in the graph and on the device card.

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
A menu bar manager (Bartender, Pelmet…) may hide its icon: new icons land on
the hidden side.

### Demo mode

```sh
open "…/Maillage Thread.app" --args -demo
open "…/Maillage Thread.app" --args -demo -selection 86E8EDA04DCFDE3F   # card open
```

The demo replays the September 27 outage, rebuilt from the real survey of
September 28 (`docs/releves/2026-09-28/`): nothing is written, nothing is
notified. Home names in the demo are made up.

### Signing

`Signature.xcconfig` (tracked) signs ad hoc: the repository builds and tests
anywhere, without an Apple account, but the local network permission does
not survive a rebuild. To sign Maillage Thread with your team, create
`Local.xcconfig` (ignored by git):

```
DEVELOPMENT_TEAM = <team, 10 characters>
CODE_SIGN_IDENTITY = Apple Development
```

If an ad hoc install already exists, switching to team signing makes macOS
warn once that the app differs from previously opened versions, and the local
network permission is asked again. Passeur Noms is signed with the team only
by `outils/passeur.sh` (see below).

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
| `MaillageThread/Noms/` | Home names: folder chosen once (security-scoped bookmark), reading `noms.json`, last names kept, launching Passeur Noms |
| `MaillageThread/Recenseur/` | NWBrowser (three service types) and dns_sd (hosts, addresses) → `Annonces` |
| `MaillageThread/Surveillance/` | app model: surveys → tracking → log and notifications; sleep of the Mac; login item |
| `MaillageThread/Vues/` | menu bar, graph window (Canvas, glass overlays), log window, settings |
| `Passeur/` | Passeur Noms: iOS app run on the Mac (Designed for iPad) that reads Home and writes `noms.json` |
| `docs/releves/` | real surveys (the fixture of the tests and the demo) |
| `docs/superpowers/` | design (spec) and implementation plans |

## Home names (Passeur Noms)

HomeKit does not exist in native macOS, and a free Apple developer team cannot
give it to a Mac Catalyst app. So Home names come from **Passeur Noms**, a small
iOS app run on the Mac ("Designed for iPad"): it reads Home (names, rooms,
manufacturers, `matterNodeID`), writes `noms.json` in a folder you choose once,
and quits.

```sh
outils/passeur.sh          # build with your team (Xcode account), wrap, launch
```

- The team comes from your "Apple Development" certificate (`EQUIPE=` to force
  it). A free team gets a 7-day profile: run the script again to refresh names.
  Only Passeur Noms is signed with the team; Maillage Thread stays ad hoc.
- First launch of each build: macOS says the app is "damaged". Click Cancel,
  then System Settings › Privacy & Security › "Open Anyway". Then allow Home
  access.
- Choose a folder **outside iCloud and outside this repository** (for example
  `~/Maillage Thread`); "Change folder…" stays available for 10 s after writing.
  `noms.json` is ignored by git: never commit it.
- In Maillage Thread: Settings › Home names › Choose… (the same folder). Names
  are reread when Passeur Noms quits; "Refresh Home names" (menu or settings)
  launches it again. Priority: nickname > Home > HomeKit (`_hap._udp`) > host.
