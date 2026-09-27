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

Limites :

- les octets bruts des TXT ne sont pas conservés, seulement leur décodage
  (le `dns-sd` en texte les abîme) ;
- `matter_prefixes.py` classe les hôtes par préfixe : « Apple (fd2d) » est la
  partition principale, « autre / aucune » mélange les appareils IP (préfixe
  du réseau local `fd4b:5d37:6d94:480e::/64`) et l'hôte sans adresse ;
- le rôle « detache/desactive » de l'Aqara est faux : Thread 1.3.0 n'a pas de
  bits de rôle, il faut lire « rôle inconnu ».
