# Release notes · Notes de version

Maillage Thread: one section per published version, in English then in French. `outils/publier.sh` takes from it
the notes of the GitHub release and those of the update window.

Maillage Thread : une section par version publiée, en anglais puis en français. `outils/publier.sh` en tire les
notes de la version publiée sur GitHub et celles de la fenêtre de mise à jour.

## 1.1.0

**English**

- The probe listens (firmware 1.1.0, to flash without erasing: the probe stays in Home): it hears the MLE
  advertisements of the routers within its radio range and decrypts them on the board, and the app draws their
  links, between Apple border routers too, which never answer diagnostics. For each direction of a link, the most
  recent measure wins, diagnostics or listening.
- Parent resolution replaces the scan of silent routers: every 30 minutes, and when a device appears, the probe
  resolves the Thread address of each Matter or HomeKit device, and the answer gives its parent, under an Apple
  router too.
- The children of Apple routers keep an unknown quality. Their MAC counters count channel access failures, not
  missed acknowledgements: they don't measure the link with the parent, and are only shown for information.
- The node card gives the source and age of each link ("heard 3 minutes ago", "diagnostics", "resolved 12 minutes
  ago", and for a child of an Apple router "channel access refused: 0.7%"); Settings, Probe, gives the coverage of
  the listening ("routers heard: 5 of 7").
- The history keeps the source of each link and the children's channel access refused rate, for information; older
  files read as before.
- With a firmware older than 1.1.0, the app keeps to diagnostics.

**Français**

- La sonde écoute (firmware 1.1.0, à flasher sans effacement : la sonde reste dans Maison) : elle entend les
  annonces MLE des routeurs à portée de sa radio et les déchiffre sur la carte, et l'app dessine leurs liens, entre
  routeurs de bordure d'Apple aussi, qui ne répondent jamais au diagnostic. Pour chaque sens d'un lien, la mesure la
  plus récente l'emporte, diagnostic ou écoute.
- La résolution des parents remplace le balayage des routeurs muets : toutes les 30 minutes, et quand un appareil
  paraît, la sonde résout l'adresse Thread de chaque appareil Matter ou HomeKit, et la réponse donne son parent, sous
  un routeur d'Apple aussi.
- Les enfants des routeurs d'Apple restent en qualité inconnue. Leurs compteurs MAC comptent les échecs d'accès au
  canal, pas les accusés manquants : ils ne mesurent pas le lien avec le parent, et ne sont montrés qu'à titre
  d'information.
- La fiche d'un nœud donne la source et l'âge de chaque lien (« entendu il y a 3 minutes », « diagnostic », « résolu
  il y a 12 minutes », et pour un enfant d'un routeur d'Apple « accès au canal refusés : 0,7 % ») ; Réglages, Sonde,
  donne la couverture de l'écoute (« routeurs entendus : 5 sur 7 »).
- L'historique garde la source de chaque lien et le taux d'accès au canal refusés des enfants, à titre
  d'information ; les fichiers d'avant se lisent comme avant.
- Avec un firmware antérieur à 1.1.0, l'app s'en tient au diagnostic.

## 1.0.0

**English**

- First published version: the menu bar app that shows the Thread network as seen from the Mac (border routers,
  partitions, OMR prefixes, devices), keeps a log of changes and notifies the alerts; the room view in 2D and 3D;
  Home names through Passeur Noms; the real mesh through the probe, over USB or over the Thread network.
- Automatic updates (Sparkle 2): a check at launch and then every 24 hours, download, and installation when the
  app quits, or right away with "Install and Relaunch". "Check for Updates…" is in the menu; Settings, General,
  "Updates", can turn them off.
- Thread Route, the system helper that keeps the Mac's route to the Thread network (formerly halo-routes): its
  status is in Settings, Diagnostics; it installs with `sh outils/thread-route/installer.sh`.

**Français**

- Première version publiée : l'app de la barre des menus qui montre le réseau Thread vu depuis le Mac (routeurs
  de bordure, partitions, préfixes OMR, appareils), tient le journal des changements et notifie les alertes ; la
  vue par pièces en 2D et en 3D ; les noms de Maison par Passeur Noms ; le vrai maillage par la sonde, en USB ou
  par le réseau Thread.
- Mises à jour automatiques (Sparkle 2) : recherche au démarrage puis toutes les 24 heures, téléchargement et
  installation à la fermeture de l'app, ou tout de suite par « Installer et relancer ». « Rechercher les mises à
  jour… » est dans le menu ; Réglages, Général, « Mises à jour », permet de les arrêter.
- Thread Route, l'assistant système qui garde la route du Mac vers le réseau Thread (anciennement halo-routes) :
  son état est dans Réglages, Diagnostic ; il s'installe par `sh outils/thread-route/installer.sh`.
