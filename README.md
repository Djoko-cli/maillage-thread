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
not "answers": reachability never comes from the probe. A disappearance is
only kept after 2 minutes of absence and is dated from the first absence.
Real links (child → parent, router ↔ router, link quality) come from the
probe, an ESP32-C6 plugged into the Mac (see "Probe" below).

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
open "…/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D   # card open
```

The demo replays the September 27 outage, rebuilt from the real survey of
September 28 (`docs/releves/2026-09-28/`): nothing is written, nothing is
notified. Home names in the demo are made up, and so is the probe mesh drawn
on the same nodes.

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
| `MaillageCoeur/Maillage/` | probe: diagnostic TLVs, Network Data, USB protocol, mesh model, tour (routers, scan of silent routers), kept router identities, matching with the snapshot (elimination, candidates); tested on an anonymized capture |
| `MaillageThread/Sonde/` | probe link: serial port without resetting the C6, USB ports, `SondeUSB` (requests matched by id), app model (probe remembered by its USB serial number, a tour every 5 minutes) |
| `MaillageThread/Noms/` | Home names: folder chosen once (security-scoped bookmark), reading `noms.json`, last names kept, launching Passeur Noms |
| `MaillageThread/Recenseur/` | NWBrowser (three service types) and dns_sd (hosts, addresses) → `Annonces` |
| `MaillageThread/Surveillance/` | app model: surveys → tracking → log and notifications; sleep of the Mac; login item |
| `MaillageThread/Vues/` | menu bar, graph window (Canvas, glass overlays), log window, settings |
| `Passeur/` | Passeur Noms: iOS app run on the Mac (Designed for iPad) that reads Home and writes `noms.json` |
| `sonde/` | probe firmware (ESP32-C6, PlatformIO) and trial tools |
| `outils/anonymiser-sonde.py` | anonymizes a probe capture before it becomes test data |
| `docs/releves/` | real surveys (the fixture of the tests and the demo) |
| `docs/superpowers/` | design (spec) and implementation plans |

## Home names (Passeur Noms)

HomeKit does not exist in native macOS, and a free Apple developer team cannot
give it to a Mac Catalyst app. So Home names come from **Passeur Noms**, a small
iOS app run on the Mac ("Designed for iPad"): it reads Home (names, rooms,
manufacturers, `matterNodeID`, batteries), writes `noms.json` in a folder you
choose once, and quits.

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
  `~/Maillage Thread`); opened by hand, Passeur Noms offers "Change folder…"
  for 10 s after writing. `noms.json` is ignored by git: never commit it.
- In Maillage Thread: Settings › Home names › Choose… (the same folder). Names
  are reread when Passeur Noms quits. Priority: nickname > Home > HomeKit
  (`_hap._udp`) > host.
- Refreshing: the graph window launches Passeur Noms in the background when it
  opens (if the last reading is older than 15 min), then every hour; "Refresh
  from Home" (menu or settings) does it on demand, and so does the refresh
  button of the graph once a names folder is chosen. The app first drops
  `passeur-demande.json` in the folder, so Passeur Noms writes and quits at
  once; its window only flashes behind the others.
- Batteries: level, charging state and the accessory's own low-battery alert,
  for every Home accessory with a battery. The device card shows them with the
  age of the reading; in the graph, a glowing orange badge marks a low battery
  (the accessory says so, or its level is 20 % or less).

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
  USB serial number and shows under its name, "SONDE-01" by default: the
  firmware keeps it, so it follows the board from one Mac to another (the
  C6's USB name is fixed by the chip). Any other port shows with its USB
  serial number ("usbmodem… · " then the number), the only way to tell the
  probe from the Halo bridge before the first connection. The menu line uses
  the name too ("SONDE-01: connected · updated 2 minutes ago"), and so does
  the state in Settings › Probe ("SONDE-01 · connected"); not for another
  port being tried.
- Settings › Probe shows the probe's Matter QR code and its pairing code
  (4-3-4), even once it is in Home.
- A tour every 5 minutes, and on refresh: the refresh button of the graph
  rereads the network, starts a tour (unless one is running) and launches
  Passeur Noms; its help tag says which of these it will actually start. While
  a tour runs, a line under the graph's toolbar (and under the split-network
  banner) shows its step, a counter of requests and its duration ("Scan of
  silent routers · 24/48 · 0:42"); its place stays reserved above the graph
  while a probe is remembered, so nothing moves when a tour starts or ends.
  Settings › Probe and the menu line show the step and the counter too.
- The list of routers comes from the leader; if it is silent, from a router
  that has already answered; otherwise from a search over every router id.
  With no list there is no new mesh: the last one gets older.
- The tour then asks every router that answers for its links (with the
  quality in both directions) and its children, reads the border routers from
  the Network Data, and asks each child listed in a router's child table for
  its identity (ExtMac, addresses) at most once every half hour, sleepy ones
  included (a Matter device's ExtMac is its host name).
- **Apple's border routers never answer diagnostics.** The scan of possible
  child RLOC16s targets the routers that never answered (Apple's) or that
  stayed silent two tours in a row, every 30 minutes or when that set changes;
  the quality of those links stays unknown, and a link between two Apple
  routers is never drawn.
- **Border router identities.** A silent Apple router does not give its
  ExtMac, so not the name of its announcement either. The probe (firmware
  1.0.2) learns the ExtMac of the routers it hears: each tour reads its router
  table (`routeurs`) and keeps every RLOC16 ↔ ExtMac pair, like the one of its
  parent. These identities are kept from one launch to the next with their
  partition (`identites-routeurs.json` in the app folder; another partition
  erases them): moved around the house, the probe learns them all. If a
  single border router is left unidentified for a single announcement, it is
  that one, by elimination. Otherwise it shows with its candidates,
  "HomePod Avant or HomePod Palier · 0400" ("HomePod salon? · 0400" for a
  single one), and those announcements are no longer drawn apart: one node per
  router. Its card lists the candidates. Without a probe, every announcement
  stays drawn.
- In the graph, solid lines are radio links, colored and thickened by quality
  (green 3, yellow 2, orange 1, grey unknown); a child's line to its parent
  stays thin. Dotted lines stay for what the probe does not see. Devices that
  route move to the inner ring, and children sit near their parent. The card
  gives the parent and the quality, or a router's number of neighbors and
  children. If the probe stops answering, the last mesh is marked old 6
  minutes after it was received (never during a tour); after 15 minutes the
  graph goes back to dotted lines.
- Switching "Sonde maillage" off in Home suspends the probe: no tour, even
  after the probe restarts.
- Probe captures hold the home network's addresses:
  `outils/anonymiser-sonde.py` rewrites them consistently before they become
  test data (`docs/releves/2026-09-29/`).
