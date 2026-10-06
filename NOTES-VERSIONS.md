# Notes de version · Release notes

Maillage Thread : une section par version publiée, en français puis en anglais. `outils/publier.sh` en tire les
notes de la version publiée sur GitHub et celles de la fenêtre de mise à jour.

Maillage Thread: one section per published version, in French then in English. `outils/publier.sh` takes from it
the notes of the GitHub release and those of the update window.

## 1.0.0

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

**English**

- First published version: the menu bar app that shows the Thread network as seen from the Mac (border routers,
  partitions, OMR prefixes, devices), keeps a log of changes and notifies the alerts; the room view in 2D and 3D;
  Home names through Passeur Noms; the real mesh through the probe, over USB or over the Thread network.
- Automatic updates (Sparkle 2): a check at launch and then every 24 hours, download, and installation when the
  app quits, or right away with "Install and Relaunch". "Check for Updates…" is in the menu; Settings, General,
  "Updates", can turn them off.
- Thread Route, the system helper that keeps the Mac's route to the Thread network (formerly halo-routes): its
  status is in Settings, Diagnostics; it installs with `sh outils/thread-route/installer.sh`.
