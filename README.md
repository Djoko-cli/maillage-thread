**English** · [Français](README.fr.md)

# Maillage Thread

<p align="center"><img src="docs/images/vue-3d.png" alt="The room view in 3D: the house, its floors, rooms, routers and radio links" width="100%"></p>

<p align="center">
  <img src="docs/images/vue-2d-3d.gif" alt="From 2D to 3D" width="49%">
  <img src="docs/images/zoom.gif" alt="Zooming in on a floor and a room, then back" width="49%">
</p>

<p align="center">
  <img src="docs/images/vue-2d.png" alt="The room view in 2D" width="32%">
  <img src="docs/images/etage-isole.png" alt="An isolated floor, with a router's card" width="32%">
  <img src="docs/images/piece-isolee.png" alt="An isolated room, with a device's card" width="32%">
</p>

<p align="center"><sub>Demo mode: made-up names, and a made-up probe mesh on the nodes of a real survey.</sub></p>

Native macOS menu bar app (SwiftUI, Liquid Glass) that shows the Thread
network as seen from the Mac: border routers, partitions and their leader,
OMR prefixes, Matter and HomeKit devices and the partition they sit in. It
keeps a log of changes (a split network, a border router that restarts or
disappears, devices lost) and notifies the alerts.

It was born from a real outage: on September 27, 2026, five Thread devices
stopped responding at 04:14. By hand, from the Mac, the leader (an Apple TV)
had published a new OMR prefix at 04:04 and an Aqara hub had ended up alone
in its own partition. The app shows that at a glance and remembers it.

## Installing

Download `Maillage-Thread-X.Y.Z.dmg` from the latest
[release](https://github.com/Djoko-cli/maillage-thread/releases) (`maillage-vX.Y.Z`),
open it, and drag **Maillage Thread** onto **Applications**. macOS 26 or later.

- **First launch (Gatekeeper).** The app is signed with a self-signed
  certificate, `Djoko-cli Code Signing`, not with an Apple Developer ID, and
  isn't notarized. macOS refuses to open it the first time: in System
  Settings, Privacy & Security, click "Open Anyway" next to Maillage Thread,
  then confirm with your password (since macOS 15, a right-click no longer
  does it). Only once.
- **Automatic updates** (Sparkle 2). The app checks for a new version at
  launch and then every 24 hours, downloads it, checks its Ed25519 signature,
  and installs it when the app quits, or right away with "Install and
  Relaunch". An update installed this way doesn't go back through Gatekeeper:
  the signature takes its place. "Check for Updates…" is in the menu; Settings,
  General, "Updates", has "Check for updates automatically" and "Install
  updates automatically", both on by default. A copy downloaded before the
  first version with Sparkle (1.0.0) doesn't update itself.
- **Thread Route.** To reach the probe over the Thread network, the Mac needs
  a route to it, which Thread Route keeps (see "Route to the Thread network"
  below). It installs from a copy of this repository:
  `sh outils/thread-route/installer.sh` (administrator password). Settings,
  Diagnostics, shows its status.
- **Passeur Noms is not distributed.** It is an app "Designed for iPad" that
  everyone builds and signs with their own Apple team: `outils/passeur.sh`
  (see "Home names" below).

## Credits

The app embeds [Sparkle](https://sparkle-project.org) 2.10.0 (automatic updates), under the MIT
license; the text of the license is shipped in the `.dmg`, next to the app (`Sparkle-LICENSE.txt`).

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
probe, an ESP32-C6 plugged into the Mac or reached over the Thread network
(see "Probe" below).

Devices are placed by the OMR prefix of their address. When two partitions
announce the same OMR prefix (seen on September 28: an isolated hub had
picked up the main partition's prefix), the Mac cannot tell which side a
device is on: the app gives the prefix to the partition with the most border
routers, and the device card says its partition is "uncertain: shared
prefix".

## Build, test, run

Requirements: macOS 26 or later, Xcode 26 or later (developed with Xcode 27),
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
One dependency, Sparkle 2 (2.10.0, the updates), through the Swift Package
Manager. The Xcode project is generated: only `project.yml` is tracked.

```sh
outils/tester.sh                                   # generate, build, all tests
outils/tester.sh MaillageCoeurTests/SuiviTests     # one suite
outils/mesurer.sh                                  # timings of the room view, in Release
```

Build products go to `~/Library/Developer/Xcode/DerivedData/maillage`
(`DD` to change it). Swift 6 with complete strict concurrency, warnings as
errors.

Run: `Maillage Thread.app` in `…/DerivedData/maillage/Build/Products/Debug/`.
The app lives in the menu bar; the room view opens from its menu ("Open
Graph", and by itself on the very first launch).
A menu bar manager (Bartender, Pelmet…) may hide its icon: new icons land on
the hidden side.

### Demo mode

```sh
open "…/Maillage Thread.app" --args -demo
open "…/Maillage Thread.app" --args -demo -selection 86E7BD1A75F28E6D   # card open
open "…/Maillage Thread.app" --args -demo -captures ~/Library/Containers/fr.djoko.maillage/Data/tmp/captures
```

With `-captures <folder>`, the app writes twenty-one PNG images of the room
view (2D, flight, 3D, zooms, isolated rooms, hover, the leader's card, the
folded legend; then the floors: the 2 × 2 grid in a square window, the same
window in a row, 3D with the garden inside the house, a floor isolated in 2D
and in 3D, a room isolated from its floor; last, a device halfway through its
slide to the kitchen), then quits, with no window. Its renderer
draws neither the window nor glass: the top of the window, the legend and the
card are drawn as in their mockups, with the window's three buttons in place.
The app is sandboxed: the folder must be inside its container.

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

### Publishing a version

`outils/publier.sh X.Y.Z` publishes version X.Y.Z, the `MARKETING_VERSION` of
`project.yml`, from an up-to-date `main`. Before any test, it checks that the
tag and the version in the feed don't exist yet (and that the version is
higher than the head of the feed), that the tree is clean, that the Git author and
committer are `Djoko-cli` at the GitHub noreply address, that the keychain holds a
single `Djoko-cli Code Signing` certificate whose subject is only that name,
and that the anonymization check is on the Mac (it is private): outside a
rehearsal, without it, nothing is published. Then it runs all the tests,
builds in Release without debug symbols and with neutral source paths, signs
the app with that certificate (`IDENTITE_SIGNATURE`, in `publier.sh` only:
work builds and tests stay ad hoc), and makes the `.dmg` (the app, a shortcut
to Applications and Sparkle's license). It refuses any binary (Sparkle's
included) that carries the home folder, `/Users/` or the account name, and any
real data found by the anonymization check. It signs the `.dmg` with the
Ed25519 key of the keychain (`sign_update` from the Sparkle 2.10.0 archive,
whose `bin` folder is given by `SPARKLE_BIN`), then adds the version, with the
notes of `NOTES-VERSIONS.md`, at the top of the update feed, `appcast.xml`,
which keeps every published version. Just before the first public step it
reads the state again (`main` unchanged and up to date, `gh` logged in,
`git push --dry-run` passing, release absent). It then creates the GitHub
release with `gh release create --target`, which also creates the
`maillage-vX.Y.Z` tag on the checked commit, with the `.dmg`; commits the feed
on `main` and pushes it right away; and copies the `.dmg` to the Desktop. Each
step done is noted in `gestes.txt`, in `build/publication/X.Y.Z/`: if the
script stops halfway, the rest is resumed from that file and that folder,
step by step, not by running the script again. The build number, which Sparkle
compares, is the number of commits of `main`. The app reads its feed in the
repository, at
`https://raw.githubusercontent.com/Djoko-cli/maillage-thread/main/appcast.xml`;
each `.dmg` stays in its release.
With `--repetition`, the same without GitHub or Desktop, for a local trial,
with a test key pair and a test certificate in a separate keychain if given;
only there may the anonymization check be missing.
A notarization step (Developer ID) is written but off: `NOTARISER=1`, with
`PROFIL_NOTARISATION`, the keychain profile of `notarytool store-credentials`.
Tests: `/usr/bin/python3 -m unittest discover -s outils/tests`.

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

| Folder or file | Role |
|---|---|
| `MaillageCoeur/` | framework without UI: TXT decoding, snapshot (networks, partitions, prefixes, devices), tracking and log events, file log, names, routing table; tested on the real survey and on the replayed outage |
| `MaillageCoeur/Scene/` | room view without UI: nodes and links, floors and rooms, cards, layout (deterministic, with a budget), kept places, camera and flight, label placement and semantic zoom, projection for the `Canvas` engine; optimized even in Debug |
| `MaillageCoeur/Maillage/` | probe: diagnostic TLVs, Network Data, USB protocol, mesh model, tour (routers, MLE advertisements heard, parent resolution, children's MAC counters), kept router identities, matching with the snapshot (elimination, candidates), log of parents and Thread routers, tour history and curves; tested on an anonymized capture |
| `MaillageThread/Sonde/` | probe link: serial port without resetting the C6, USB ports, access over the Thread network (`Reseau/`: UDP transport and H1 envelope from the Halo bridge, key in the keychain, rid and resends), `SondeUSB` (requests matched by id and target, each with its own deadline), app model (probe remembered by its USB serial number, USB or network link, a tour every 5 minutes) |
| `MaillageThread/Noms/` | Home names: launching Passeur Noms, receiving its reading over the loopback (TCP listener on 127.0.0.1, one-time token), last valid names kept in the app's container |
| `MaillageThread/Recenseur/` | NWBrowser (three service types) and dns_sd (hosts, addresses) → `Annonces` |
| `MaillageThread/Surveillance/` | app model: surveys → tracking → log and notifications; sleep of the Mac; login item; updates (Sparkle); Thread Route status |
| `MaillageThread/Vues/` | menu bar, room view window (`Pieces/`: `Canvas` engine, glass overlays, captures), log window, settings (AppKit window with tabs: General, Notifications, Home, Probe, Diagnostics; ⌘,) |
| `Passeur/` | Passeur Noms: iOS app run on the Mac (Designed for iPad) that reads Home and sends its names, rooms and zones to the app over the loopback |
| `sonde/` | probe firmware (ESP32-C6, PlatformIO) and trial tools |
| `outils/anonymiser-sonde.py` | anonymizes a probe capture before it becomes test data |
| `outils/mesurer.sh` | timings of the room view (layout, label placement), in Release |
| `outils/thread-route/` | Thread Route, an identical copy of its source (Halo bridge repository, `tools/macos/thread-route`), at the revision noted in `outils/thread-route.source`; `outils/synchroniser-thread-route.sh` copies it again, `outils/tests/test_thread_route.py` checks it |
| `outils/publier.sh`, `outils/publication.py` | publishing a version (see "Publishing a version"); tests in `outils/tests/` |
| `NOTES-VERSIONS.md` | release notes, in French and English |
| `docs/releves/` | real surveys (the fixture of the tests and the demo) |
| `docs/superpowers/` | design (spec) and implementation plans |

## Room view (2D and 3D)

The window shows the network in the house: a round platform per floor or zone,
a glass card per room with one line per device, and the real radio links on
top. It stays dark, like its mockup, even when the Mac is in light mode.
Design: `docs/superpowers/specs/2026-09-30-maillage-thread-vue-pieces-design.md`,
and for the floors `docs/superpowers/specs/2026-10-03-maillage-thread-polissage-c-design.md`
(in French).

- **The window** has no title bar: the view goes up to the top, under the
  window's three buttons. An empty, invisible toolbar, as in Maps, lowers
  these buttons and leaves some room above the two glass capsules, which sit
  on their line: the network one (network menu, IP devices, Log, refresh)
  right after the buttons, the view one (2D / 3D, slow rotation) against the
  right edge. Drag the empty band between them to move the window; a
  double-click there does what a double-click on a title bar does on your Mac
  (Desktop & Dock settings). Below, against the left edge, like the legend:
  the tour line, the split-network banner, the "Home" path and, right under it,
  the level line (a single line, cut off if it is too long). The green
  button goes full screen: the invisible toolbar goes away there, the buttons
  hide until you hover over the top, which shows them in a dark title bar (it
  covers the capsule while you hover), and the network capsule takes their
  place, against the left edge. At least 820 × 732 points,
  that is 680 below the hidden title bar.
- **Legend** at the bottom left, in glass: routers, devices, radio links by
  quality and the other signs, only those the view shows, drawn as in the
  view; the leader's crown and a sleepy device's moon stand alone there,
  without the dark tag of the names. Open, the overview is framed above it;
  its chevron (⌄) folds it to its label, giving the room back, and the label's
  chevron (⌃) opens it again; it stays as you left it. An open card keeps it visible,
  above the card; if the window is too short for both, it folds by itself
  until the card closes. When the probe's survey is old, an orange tag says so
  next to the level line, at the top left.
- **Floors and rooms.** Floors are the Home zones, in their order (the first
  at the bottom); a room in several zones goes to the first one, rooms outside
  any zone make "Other rooms", and a house without zones has a single "Home"
  platform. A device takes the room of its Home accessory; a border router,
  the room of the Home accessory named like its announcement. Home gives
  neither the HomePods nor the Apple TV: such a router goes to the room whose
  name is in its own ("HomePod mini chambre" to "Chambre": whole words,
  ignoring case and accents; the longest room name wins, a tie places
  nothing). The card of any border router that Home doesn't place, even one
  already placed by its name, offers "Place in a room…": this choice wins over
  the name, and is kept under the name of its announcement
  (`pieces-routeurs.json` in the app folder, never in the demo). "Place in a
  room…" also serves devices that the probe knows but Home doesn't recognize,
  for example a battery-powered Matter device whose announcement has expired:
  the choice is kept under the device's ExtMac, and "No room" clears it. Nodes
  still without a room go to "No room", on the bottom platform. With no Home
  room at all (Passeur Noms never ran), one card per router, with its children.
- **Levels.** A zone can sit on a floor's level, next to it, inside or outside
  the house, like a garden next to the ground floor; this choice is kept with
  the floor order (`positions-pieces.json`, never in the demo), and a zone
  whose floor disappears becomes a floor again.
- **2D and 3D** (right capsule; the mode is kept from one launch to the next):
  2D is a top view, the platforms in a grid filled from the bottom, or in a
  row (Settings › General › Room view › Floors in 2D). The grid is chosen on
  the visible area, the window minus its top and the legend, so that the view
  is as large as possible: 2 × 2 in a square or tall window, often the row in
  a wide window with the legend open. 3D stacks the levels inside the house
  sphere, the zones next to a floor at its height, inside the sphere or around
  it, with a slow rotation you can turn off, which goes on around an isolated
  room or floor and stops during a gesture. Switching is a 2.6 s flight; the
  platforms slide to their place when the window is resized, when the legend
  opens or folds, when the setting changes, and after a level change.
- **Slides.** A new layout (a survey, a device placed in a room, a level
  choice) slides in 0.9 s: rooms and devices go from their shown place to the
  new one, a device in a straight line from room to room, from floor to floor
  if need be; the platforms slide with them in 3D, but in 2D, after a level
  change, in 0.4 s; what appears or disappears fades in 0.3 s, and links
  follow. The view follows what it looks at. A changing badge (☾, ⚠︎, 👑, low
  battery) no longer moves the floor: each card keeps room for the possible
  badges of its names, the battery dot only for a device whose battery is
  known. An unidentified border router whose candidates are all in the same
  room goes to that room.
- **Gestures.** Scroll wheel or pinch: zoom, towards the pointer in 2D; over
  the card, the legend or the top of the window, the wheel goes to them. Drag
  the background: pan in 2D, orbit around the house in 3D. Drag a room: move
  it within its floor, with nothing else moving (the other rooms only move at
  the next layout); its place is kept (`positions-pieces.json` in the app
  folder, never in the demo). Click a room or its name: isolate it (the others
  fade, a tag points to a parent elsewhere); click a floor's name or disc:
  isolate it the same way. Esc first closes the open card; otherwise, like a
  click outside, it goes up one step, from a room to its floor if you opened
  it from there, otherwise to the house, and brings a zoomed view back to the
  overview; there, it is not taken and goes its way. The "Home › Floor ›
  Room" path also leads to each step. In 3D, ⌥ + drag pans the view in the
  screen plane. Double-click the background or a disc: back to the overview,
  zoom and pan undone. Click a device or its name: its card, which slides up
  from the bottom as the view rises; the card of the Thread network's leader
  shows "👑 Thread network leader, elected automatically". The first click
  works even when the window is inactive.
- **Right clicks**: on a floor's name or disc, the menu of its level, under
  its name: "Move up one floor" and "Move down one floor" (the whole level),
  "On the same level as ▸", "Outside the house" and "On its own level"; on the
  background, "Arrange rooms automatically" (kept places go, not the floor
  order nor the levels); on a room (its box or its name) or a device, no menu.
- **Semantic zoom**: from afar, rooms only; then routers; up close, every name
  that fits. The line at the top left, under "Home", gives the level, or how
  many names are hidden for lack of room.
- "Reduce motion" (macOS accessibility): the flight and the double-click
  return become a fade, other camera flights are immediate, as are the slides
  from one layout to the next, the slow rotation is off, the card, the legend
  and the top banners come and go with a plain fade, and the view reframes
  itself through a fade.
- The room layout is computed off the main thread: a few hundredths of a
  second for the demo, under a second for 20 rooms and 100 devices
  (`outils/mesurer.sh`).

## Home names (Passeur Noms)

HomeKit does not exist in native macOS, and a free Apple developer team cannot
give it to a Mac Catalyst app. So Home names come from **Passeur Noms**, a small
iOS app run on the Mac ("Designed for iPad"): it reads Home (names, rooms,
zones, manufacturers, `matterNodeID`, batteries), hands the reading to
Maillage Thread over the Mac's loopback, and quits. There is no folder to
choose.

```sh
outils/passeur.sh          # build with your team (Xcode account), wrap, launch
```

- The team comes from your "Apple Development" certificate (`EQUIPE=` to force
  it). A free team gets a 7-day profile: after that, Maillage Thread can no
  longer launch Passeur Noms; run the script again. Only Passeur Noms is
  signed with the team; Maillage Thread stays ad hoc.
- First launch of each build: macOS says the app is "damaged". Click Cancel,
  then System Settings › Privacy & Security › "Open Anyway". Then allow Home
  access. Opened by hand like this, Passeur Noms reads Home, shows what it
  read and quits after 10 s. It sends nothing, unless Maillage Thread asks
  during those 10 s.
- A reading: Maillage Thread listens on `127.0.0.1` (TCP, on a port chosen by
  the system), generates a one-time token and opens Passeur Noms in the
  background with the URL `maillage-passeur://releve?port=…&jeton=…` (a
  sandboxed app cannot pass launch arguments: macOS drops them). Passeur Noms
  reads Home, connects, sends the token, the length of the JSON, then the
  JSON, and quits once the app has read it all. The app checks the token,
  reads at most 8 MB and writes `noms.json` in its own container (atomic
  write). The loopback needs no local network permission. Known limit: any
  app on this Mac can open that URL with its own port and would get the
  reading; nothing leaves the Mac.
- Priority of names: nickname > Home > HomeKit (`_hap._udp`) > host.
- The last valid reading is kept. A failure (for example Passeur Noms not
  found or refused, nothing within 2 minutes, wrong token, unreadable length
  or JSON, Home access denied) keeps it and shows in Settings › Home and in
  the menu; after 7 days, Settings says to run `outils/passeur.sh` again. Passeur Noms logs why it quit:
  `/usr/bin/log show --last 10m --predicate 'subsystem == "fr.djoko.maillage.passeur"'`.
- Refreshing: the room view window launches Passeur Noms when it opens (if
  the last reading and the last request are older than 15 min), then every
  hour; "Refresh from Home" (menu or settings) and the refresh button of its
  network capsule do it on demand. One reading at a time: a request during a
  reading is ignored. The window of Passeur Noms only flashes behind the
  others.
- Zones: Home's zones (usually floors) and their rooms, in Home's order;
  Settings › Home lists the zone names. A reading from before zones has none.
- The `noms.json` written in a chosen folder by an older Passeur Noms (at the
  root of this repository, for example) is no longer read: delete it (git
  ignores it).
- Batteries: level, charging state and the accessory's own low-battery alert,
  for every Home accessory with a battery. The device card shows them with the
  age of the reading; in the view, a glowing orange badge at the end of the
  name marks a low battery (the accessory says so, or its level is 20 % or
  less).

## Probe (real mesh)

The Mac has no Thread radio. The **probe** is an ESP32-C6 SuperMini plugged
into the Mac by USB and added to Home as a Matter over Thread device (a
"Sonde maillage" plug). It is an end device that never becomes a router (FED
since firmware 1.0.2): it listens all the time but never relays, so it is
nobody's parent. It sends Thread network diagnostics (`DIAG_GET`) for the app
and passes the raw answers back, over USB or, once access is allowed, over
the Thread network; the app decodes them and rebuilds the mesh. Since
firmware 1.1.0, it also hears the MLE advertisements of the routers around
it and resolves the parent of each device (see below).

The **Halo bridge** is the author's other ESP32-C6 project, a Matter over
Thread bridge for a ScreenBar Halo lamp, in another repository. The probe's
network access is the bridge's, unchanged, including its **H1 envelope**: a
signed handshake, then messages that each carry a counter and an HMAC.

```sh
cd sonde && pio run        # build; flashing and pairing: sonde/README.md
```

- In Maillage Thread: Settings › Probe › Port. Only the chosen port is ever
  opened: another plugged-in ESP32-C6 (the Halo bridge, for example) never
  is. The probe is remembered by its USB serial number and shows under its
  name, "SONDE-01" by default: the firmware keeps it, so it follows the board
  from one Mac to another (the C6's USB name is fixed by the chip). Once
  plugged in, the probe is picked up on its own; if it starts too slowly, the
  app tries once more 5 s later. Any other port shows with its USB
  serial number ("usbmodem… · " then the number), the only way to tell the
  probe from the Halo bridge before the first connection. The menu line uses
  the name too ("SONDE-01: connected · updated 2 minutes ago"), and so does
  the state in Settings › Probe ("SONDE-01 · connected"); not for another
  port being tried.
- Settings › Probe shows the probe's Matter QR code and its pairing code
  (4-3-4), even once it is in Home, over USB only: they never travel over the
  network, and a note says so in their place.
- **Access over the Thread network** (firmware 1.0.2, like the Halo bridge),
  to unplug the probe from the Mac and walk it around the house so that it
  hears every router. With the probe plugged in and connected, "Allow Network
  Access" (Settings › Probe) creates over USB a key that stays in this Mac's
  keychain; the button then becomes "Regenerate Key" (a new key replaces the
  old one), and the "Link" choice (USB or Thread Network) appears. Over the
  network, the app closes the port, connects by itself to `<host name>.local`,
  UDP port 5480, and reconnects; a keepalive goes out after 10 s of silence,
  and Settings › Probe keeps the cause of the last disconnection until the
  next connection. Halo's H1 envelope authenticates the messages without
  encrypting them: the topology travels in clear on the local network. The
  Mac needs an IPv6 route to the OMR prefix (see "Route to the Thread
  network" below). "Forget the probe" removes this Mac's key, the probe's
  survey in Settings and its mesh: the view goes straight back to dotted
  lines. Limits: no end of session (a place on the board stays taken 30 s,
  the automatic retry fixes it); the board's receive queue has only 4 places
  (a batch of 8 `diag` may see some of them wait for the 2 s resend); a lost
  `routeurs` line gives a partial table, or none if the last one
  (`"suite":false`) is lost; details in the spec (section 3 bis).
- A tour every 5 minutes, and on refresh: the refresh button of the network
  capsule rereads the network, starts a tour (unless one is running) and
  launches Passeur Noms; its help tag says which of these it will actually
  start. While a tour runs, a line at the top left, under the capsules (above
  the split-network banner), shows its step, a counter of requests and its
  duration ("Parent resolution · 12/26 · 0:42"). It is only there during
  the tour: the banner and the path move up when it goes, and back down
  when it comes. The view itself does not move: its top margin keeps the
  line's room while a probe is remembered, so as not to reframe every 5
  minutes. Settings › Probe and the menu line show the step and the counter
  too.
- The list of routers comes from the leader; if it is silent, from a router
  that has already answered; otherwise from the other routers in the probe's
  router table, then from a search over every router id (not again for 30
  minutes after a search that found nothing). With no list there is no new
  mesh: the last one gets older.
- The tour then asks every router that answers for its links (with the
  quality in both directions) and its children, reads the border routers from
  the Network Data, and asks each child listed in a router's child table for
  its identity (ExtMac, addresses) at most once every half hour, sleepy ones
  included (a Matter device's ExtMac is its host name).
- **Apple's border routers never answer diagnostics.** Since firmware 1.1.0,
  the probe makes up for it in three ways, below: listening, parent
  resolution and the children's MAC counters. They replace the scan of
  possible child RLOC16s, which missed the children that don't answer
  diagnostics.
- **Listening.** The probe hears the MLE advertisements of the routers within
  its radio range and decrypts them on the board: it derives the MLE key from
  the network key, which never leaves the board and is wiped right after.
  Each advertisement carries the router's routing table (Route64), so its
  links in both directions with every other router, Apple's included. After
  the probe's state, its router table and its neighbors, the tour asks for
  them (`annonces`; without an answer, it goes on without them) and keeps
  the routers of its partition: those heard from another partition (an Aqara
  hub's, for example) are set aside. For each pair of routers, each
  direction keeps the most recent measure, diagnostics or listening, dated
  by the age the probe gives; a link known from one end only is shown. Each
  advertisement also ties a RLOC16 to an ExtMac, like the probe's parent.
- **Parent resolution**, every 30 minutes and when a device appears: for each
  Matter or HomeKit device on Thread that the app knows with an address on
  its partition's OMR prefix, the probe has OpenThread resolve that address
  (`resoudre`, 8 in flight). The parent answers for its sleepy child, and the
  probe's address cache gives the RLOC16 found: without its 10 low bits, it
  is the parent's. Apple routers answer with their own RLOC16, third-party
  routers with the child's. The child is attached to its parent, dated
  (under a router that answers diagnostics, its child table prevails); a
  device that isn't resolved stays dotted ("assumed attachment"), as before.
- **Quality of the children of Apple routers.** At each resolution, the app
  asks each child of a silent router (Apple's) for its MAC counters (TLV 9,
  at its ML-EID, which the address cache gives: diagnostics are only
  accepted on the network's internal addresses). Between two readings,
  failed sends over unicast sends give the quality: under 1 %, 3; from 1 to
  5 %, 2; above, 1. Under 50 frames sent between the two readings, the
  quality is unknown; a counter that goes down (the device restarted) starts
  the readings over. A child that doesn't answer keeps an unknown quality;
  under a third-party router, the quality comes from its child table, as
  before.
- **What listening brings, and its limits.** The probe only hears the
  routers within its radio range; a single router heard gives all its
  links, and a link shows as soon as one of its two ends is heard. A badly
  placed probe never brings less than before: diagnostics, resolution and
  counters don't depend on where it sits. Settings › Probe shows the
  coverage, "routers heard: 5 of 7" (out of the routers of its partition);
  moving the probe changes it. The quality seen by an Apple parent stays
  unknown: only the child's, if it answers diagnostics, is measured.
  Resolution doesn't cross partitions: the children of another partition
  stay unknown. The mesh is a dated photo: links and parents change, and the
  card gives the age of each piece of information. With a firmware older
  than 1.1.0, the tour keeps to diagnostics.
- **Border router identities.** A silent Apple router does not give its
  ExtMac, so not the name of its announcement either. The probe (firmware
  1.0.2) learns the ExtMac of the routers it hears: each tour reads its router
  table (`routeurs`) and, since firmware 1.1.0, their MLE advertisements, and
  keeps every RLOC16 ↔ ExtMac pair, like the one of its parent, even when the
  tour gets no mesh. These identities are kept from one
  launch to the next with their partition (`identites-routeurs.json` in the
  app folder; another partition erases them, and the pair of a router that
  left the router list is forgotten): moved around the house, the probe
  learns them all. The leader, when it is a border router, is the
  announcement of its partition whose role is leader, if it is the only one;
  with two (a stale cache), it stays unidentified, with both as candidates.
  If a single border router is left unidentified for a single announcement,
  it is that one, by elimination.
  Otherwise it shows with its candidates,
  "HomePod Avant or HomePod Palier · 0400" ("HomePod salon? · 0400" for a
  single one), and those announcements are no longer drawn apart: one node per
  router. Its card lists the candidates; each one opens its announcement's
  card. Without a probe, every announcement stays drawn.
- In the room view, solid lines between routers are radio links (2 points,
  colored by quality: green 3, yellow 2, orange 1, grey unknown); a child's
  line to its parent stays thin. A link is a link: same line and same color
  whatever its source. Dotted lines stay for what the probe does not see. The
  mesh leader wears the crown. The card gives the parent and the quality, or
  a router's number of neighbors and children, and the source and age of
  each link ("diagnostics", "heard 3 minutes ago", "resolved 12 minutes
  ago", "child's counters: 0.7% failed"); for a router the probe has never
  heard, "never heard by the probe; links seen only by its neighbors". If
  the probe stops answering, the last mesh is marked old 6 minutes after it
  was received (never during a tour); after 15 minutes the view goes back to
  dotted lines. The view redraws every minute: both changes show up within a
  minute, with no other event needed, and so do the open card's "seen … ago"
  and curves.
- Switching "Sonde maillage" off in Home suspends the probe: no tour, even
  after the probe restarts. The board's LED then gives a short orange flash
  every 5 s (firmware 1.0.3). After `oubli`, the USB command that unpairs
  the probe (see `sonde/README.md`), the probe comes back on, as when first
  set up.
- **Log and history** (plan 3b). Each tour compares its mesh with the
  previous one and writes to the log ("Mesh" family): "X changed parent:
  A → B", "X has no parent anymore" (missing from two tours where its absence
  is certain; for a child known only by resolution, under an Apple border
  router, missing from two distinct resolutions, usually 30 to 60 min apart)
  and a Thread router other than a border router appearing or disappearing;
  parent changes of one node within the hour fit on one line ("X changed
  parent 4 times within 1 h"). Only identified children (ExtMac) are
  followed. No notification by default ("Other changes"). Each tour also
  adds a line to `maillage-AAAA-MM.jsonl` in the app folder (kept 90 days,
  about 8 MB a month for 7 routers and 20 children, up to 12 MB with the
  links heard and their sources): the quality of every link and, since
  1.1.0, its source (diagnostics or listening) and the quality the counters
  give the children (older files read as before), and the signal of every
  router the probe hears (`voisins`) and of its parent (`etat`). A node's
  card draws its curves over 24 h, 7 d or 30 d: the quality of its links,
  parent changes marked, and for a router the "Signal seen by the probe",
  with the probe's own parent changes marked (the signal depends first on
  where the probe sits); its scale, in tens of dBm, always has its ticks,
  even for a single reading, and hovering gives the value and time of the
  nearest reading. None of this in demo mode.
- Probe captures hold the home network's addresses:
  `outils/anonymiser-sonde.py` rewrites them consistently before they become
  test data (`docs/releves/2026-09-29/`): ExtMacs and the SRP host name,
  prefixes, addresses, the probe's MAC, name and key fingerprint (plan 3b).
  It knows the messages of firmware 1.0.3 and of that capture, the form of
  every field, and the diagnostic TLVs the tour asks for, down to the Network
  Data; it fails on anything else, the new messages of firmware 1.1.0
  included (`annonces`, `resoudre`, the listening counters, TLV 9), without
  writing anything. An already anonymized capture comes out unchanged. Free
  texts (vendor, model, versions, the probe's messages) are refused at the
  slightest identifier pattern, an address or hex digits even when split by
  separators: an ISO date may be refused too. An identifier deliberately
  disguised in a firmware string (hex split by other letters) would still
  pass.

### Route to the Thread network

Over the network, the app reaches the probe at its address in the OMR
prefix, a /64 that the border routers (HomePod, Apple TV…) advertise on the
local network. macOS does not always install the route to that prefix, and
may lose it when it switches border routers without putting it back: the
probe is then unreachable, and the app says "No IPv6 route to the Thread
network". The Mac needs a route to that /64 through one of the border
routers that advertise it (setting one takes administrator rights). Thread
Route keeps it: a root launchd daemon from the Halo bridge repository, of
which `outils/thread-route/` is an identical copy. It installs with
`sh outils/thread-route/installer.sh`, under your own account (the
administrator password is asked for the installation only); see its README.
The app can't install it itself: in the sandbox, `SMAppService` refuses a
daemon that isn't sandboxed (trial of Oct 6, 2026). Settings, Diagnostics,
shows its status: absent, turned off in System Settings, active, or still
under its former name, halo-routes, which the installer replaces: it stops it,
waits (up to 25 s) until launchd has unloaded it, and only then removes its
files; if the wait runs out, it stops with nothing removed.
