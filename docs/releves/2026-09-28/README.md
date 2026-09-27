# Relevé du réseau Thread, 28/09/2026 (00:42-00:49, heure du Mac)

Relevé fait à la main depuis le Mac pendant le diagnostic de la panne du
27/09 (5 appareils muets vers 04:14-04:20). Il sert de source à la première
fixture des tests de `MaillageCoeur` (spec, sections 6 et 8), en attendant
les captures enregistrées par l'app.

| Fichier | Contenu | Obtenu par |
|---|---|---|
| `routeurs-de-bordure.txt` | les 6 routeurs de bordure, TXT `_meshcop._udp` décodés | `outils/meshcop.swift` (`NWBrowser`, 5 s) |
| `matter-hotes.txt` | 57 instances `_matter._tcp`, regroupées par hôte, avec adresses | `outils/matter_prefixes.py` (`dns-sd` par pseudo-terminal) |
| `routes.txt` | journal de halo-routes (dont 04:04:03 le 27/09) et routes IPv6 du Mac | `grep` du journal, `netstat -rn -f inet6` |
| `capture-0215.json` | capture complète à 02:15 au format `Annonces` de l'app (TXT en octets, hôtes, adresses, routes) : données des tests et du mode démo | prototype du recenseur de l'app (NWBrowser, dns_sd, sysctl), préfixes locaux réduits à celui du réseau local |

Limites :

- dans les fichiers texte, les octets bruts des TXT ne sont pas conservés,
  seulement leur décodage (le `dns-sd` en texte les abîme) ; la capture de
  02:15 les garde ;
- `matter_prefixes.py` classe les hôtes par préfixe : « Apple (fd19) » est la
  partition principale, « autre / aucune » mélange les appareils IP (préfixe
  du réseau local `fd4b:36a2:b7fe:200b::/64`) et l'hôte sans adresse ;
- le rôle « detache/desactive » de l'Aqara est faux : Thread 1.3.0 n'a pas de
  bits de rôle, il faut lire « rôle inconnu ».
