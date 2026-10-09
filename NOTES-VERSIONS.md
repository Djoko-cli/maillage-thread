# Release notes · Notes de version

Maillage Thread: one section per published version, in English then in French. `outils/publier.sh` takes from it
the notes of the GitHub release and those of the update window.

Maillage Thread : une section par version publiée, en anglais puis en français. `outils/publier.sh` en tire les
notes de la version publiée sur GitHub et celles de la fenêtre de mise à jour.

## 1.2.0

**English**

- Radio-only map: a link between two routers that both advertise TREL (Thread over the local network, like Apple's)
  is no longer drawn. Their routing table can't say whether a link uses the radio, and a passive 802.15.4 listen
  confirmed that Apple routers exchange no radio frames with each other. Third-party routers and children keep their
  radio links; the card of an Apple router says its TREL links are not shown.
- Focus mode: selecting a node keeps its parent, its children, its radio links and the mesh leader sharp, and fades
  the rest. Click it again, click an empty spot or press Esc to get the full view back.
- The node card has four columns: identity; role and parent, with the node's journal; children; radio neighbors,
  summarized ("5 neighbors · 2 good · 2 medium · 1 low") with a list to expand.
- A readable history: a wide band, up to six curves (radio links, then children, the weakest first) and an "all
  links" checkbox, legend chips that highlight a curve, a named axis, the quality on hover, and parent changes as thin
  markers, grouped and read on hover. A router also shows the curve of each of its children.
- A grouped journal: the parent changes of a node within an hour fit on one line, with their relays ("A → B → C ·
  ends on C") and the details to expand, in the card and in the journal window.
- Routers that are not border routers get a blue ring, and the legend now says "border router", "border router in
  another partition" and "router"; the probe shows radio waves on both sides; the menu bar icon and the app icon
  carry the Thread symbol.
- The probe firmware is unchanged (1.1.0).

**Français**

- Carte radio seulement : un lien entre deux routeurs qui annoncent tous deux TREL (Thread par le réseau local, comme
  ceux d'Apple) n'est plus dessiné. Leur table de routage ne dit pas si un lien passe par la radio, et une écoute
  802.15.4 passive a confirmé que les routeurs d'Apple ne s'échangent aucune trame radio. Les routeurs tiers et les
  enfants gardent leurs liens radio ; la fiche d'un routeur d'Apple dit que ses liens TREL ne sont pas montrés.
- Mode focus : choisir un nœud garde nets son parent, ses enfants, ses liens radio et le chef du maillage, et estompe
  le reste. Un second clic sur lui, un clic dans le vide ou Échap rendent la vue entière.
- La fiche d'un nœud a quatre colonnes : identité ; rôle et parent, avec le journal du nœud ; enfants ; voisins
  radio, résumés (« 5 voisins · 2 bons · 2 moyens · 1 faible ») avec une liste à déplier.
- Un historique lisible : une bande large, six courbes au plus (les liens radio, puis les enfants, du plus faible au
  meilleur) et une case « tous les liens », une légende en pastilles qui met une courbe en avant, un axe nommé, la
  qualité au survol, et les changements de parent en traits fins, regroupés et lus au survol. Un routeur montre aussi
  la courbe de chacun de ses enfants.
- Un journal regroupé : les changements de parent d'un nœud dans la même heure tiennent sur une ligne, avec leurs
  relais (« A → B → C · finit sur C ») et le détail à déplier, dans la fiche et dans la fenêtre du journal.
- Les routeurs qui ne sont pas de bordure ont un cercle bleu, et la légende dit « routeur de bordure », « routeur de
  bordure d'une autre partition » et « routeur » ; la sonde a des ondes de part et d'autre ; l'icône de la barre des
  menus et celle de l'app portent le symbole de Thread.
- Le firmware de la sonde ne change pas (1.1.0).

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
