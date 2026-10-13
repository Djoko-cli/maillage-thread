# Démon Passeur Noms : Maison en arrière-plan, sans fenêtre ni Dock

Spec du 12/10/2026. Djoko a validé la conception le même jour, section par section, après cinq essais de faisabilité et un essai d'Identifier.

## 0. Contexte et décisions

Aujourd'hui, Passeur Noms est une app iOS « conçue pour iPad », lancée sur le Mac dans une enveloppe (`Wrapper/` et `WrappedBundle`). Maillage Thread et Maillage Zigbee l'ouvrent avec l'URL `maillage-passeur://releve?port=<port>&jeton=<jeton>` (`EnvoiPasseur`). Il lit Maison, envoie un relevé (`NomsMaison`) sur la boucle locale (127.0.0.1), puis se ferme. Il montre toujours une fenêtre et une icône dans le Dock, et ne sait rien faire d'autre qu'un relevé ponctuel.

**Ce que les essais du 12/10 ont établi** (code archivé, privé : `.superpowers/archives/essai-demon-1210/` et `essai-identifier-1210/`) :
- **HomeKit est refusé aux apps Mac signées Developer ID** : c'est une capacité réservée à l'App Store, et Xcode refuse l'export Developer ID d'une app Catalyst qui la demande. Le démon reste donc une compilation **de développement**, signée par l'équipe payante de Djoko pour son Mac enregistré, avec un profil d'un an.
- **App iOS sur le Mac** (forme actuelle) : HomeKit répond, mais la fenêtre et l'icône du Dock restent, et `requestSceneSessionDestruction` est ignoré.
- **App Catalyst** : HomeKit répond **en arrière-plan** (143 accessoires, dont 142 joignables, dès la première seconde, pendant 4 minutes), et `LSUIElement` supprime l'icône du Dock. Catalyst + HomeKit n'est accepté qu'une fois l'App ID créé avec la capacité HomeKit (sinon : « Entitlement com.apple.developer.homekit not found »).
- **macOS 27 impose une scène** : une app UIKit sans scène s'arrête au lancement (`UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`), et la fenêtre de la scène reste visible même détruite dès sa connexion.
- **Un module AppKit chargé par l'app** (`setActivationPolicy(.accessory)`, `orderOut` des fenêtres sur les notifications d'AppKit) réduit cette fenêtre à un éclair d'une fraction de seconde au lancement : les notifications arrivent après l'affichage.
- **Cinquième essai : plus aucun éclair.** Le module intercepte les initialiseurs de `NSWindow` dès son chargement (avant la connexion de la scène) : toute fenêtre de l'app naît transparente et inerte, avant tout affichage. Djoko n'a vu ni fenêtre ni éclair ; HomeKit répond toujours (143 accessoires dès la première seconde, en arrière-plan, 4 minutes).
- **`HMAccessory.identify()` fonctionne** : depuis une app Catalyst, un détecteur de présence a clignoté.

**Décisions de Djoko (12/10) :**

| Sujet | Décision |
|---|---|
| Pour qui | Maillage Thread **et** Maillage Zigbee, appelées à fusionner en une seule app |
| Fonctions de la première version | remplacer le Passeur à l'identique ; noms tenus à jour en continu ; bouton « Identifier » ; lancement à l'ouverture de session, avec un interrupteur dans chaque app |
| Échange | approche A : faire évoluer le contrat actuel (l'app écoute, le démon se connecte), avec un abonnement qui reste ouvert |
| Signature | développement, équipe payante, profil d'un an ; jamais de .dmg |

## 1. Composants et emplacement

- **Le démon garde l'identité du Passeur** : identifiant `fr.djoko.maillage.passeur`, schéma d'URL `maillage-passeur`, nom « Passeur Noms ». Les deux apps le trouvent sans changement, et l'accès à Maison accordé à cet identifiant a des chances de rester valable. Seule sa forme change : une app Mac Catalyst (`SUPPORTS_MACCATALYST = YES`, `LSUIElement = YES`), sans enveloppe.
- **Dans le dépôt de Maillage Thread**, à la place de la cible `Passeur` actuelle :
  - `Passeur` : l'app Catalyst (HomeKit, bac à sable, `network.client`) ;
  - `Masqueur` : un paquet AppKit (`Masqueur.bundle`, dans `Contents/PlugIns`, filtre de plateforme macOS) que l'app charge au démarrage.
- **Signature et installation** : `outils/passeur.sh` compile, signe en développement (équipe payante, profil d'un an, Mac enregistré), installe `~/Applications/Passeur Noms.app` et l'enregistre auprès de LaunchServices. Le démon n'est jamais publié en .dmg ni notarisé.
- **Le contrat d'échange** : un fichier Swift commun, `MaillageCoeur/Noms/ProtocolePasseur.swift`, gardé **identique à l'octet** dans Maillage Thread et Maillage Zigbee (comme `publication.py`). Il remplace `EnvoiPasseur.swift` et le contient (l'URL `releve` y reste). Chaque dépôt le teste.
- **Côté apps** : `NomsInternes` (Thread) et `NomsPasseur` (Zigbee) deviennent des clients abonnés ; chaque app gagne l'interrupteur d'ouverture de session et le bouton « Identifier ». Maillage Zigbee est fait par sa propre session, d'après cette spec.

## 2. L'échange entre les apps et le démon

### 2.1 Les URL

| URL | Effet |
|---|---|
| `maillage-passeur://releve?port=<port>&jeton=<jeton>` | inchangée : un relevé ponctuel, puis la connexion est fermée |
| `maillage-passeur://abonner?port=<port>&jeton=<jeton>` | nouvelle : le démon se connecte et **garde la connexion ouverte** |

Lecture stricte, comme aujourd'hui : port de 1 à 65535, jeton de 64 chiffres hexadécimaux en minuscules, rien d'autre dans la requête. L'app ouvre l'URL sans activer le démon (`activates = false`), l'URL étant le seul moyen de lui passer quelque chose (macOS retire les arguments de lancement d'une app du bac à sable).

- **Banc du 13/10 :** HomeKit refuse un démon lancé à froid *par* une URL : homed coupe sa connexion XPC au premier sync (« Connection to daemon was interrupted », `NSCocoaErrorDomain` 4097) et ne livre jamais les maisons ; le démon répond à `etat` mais n'envoie aucun `releve`. Lancé *sans* URL (`open -g <app>`, ou à l'ouverture de session), il reçoit les maisons en 0,2 s et les URL envoyées ensuite fonctionnent. Règle : toute app cliente (Maillage Zigbee comprise) lance d'abord le démon sans URL, attend qu'il tourne puis 1,5 s, et seulement ensuite envoie l'URL (`abonner` ou `releve`).

### 2.2 La connexion et les trames

1. L'app écoute sur 127.0.0.1, sur un port choisi par le système, et tire un jeton à usage unique (32 octets aléatoires).
2. Le démon se connecte et écrit le jeton sur une ligne (`<64 hexa>\n`). L'app le compare en temps constant ; un mauvais jeton ferme la connexion.
3. Ensuite, **dans les deux sens**, une suite de messages : `<longueur décimale>\n<JSON UTF-8 de cette longueur>`, 8 Mo au plus par message (`tailleMax`).
4. Chaque JSON a la forme `{"v":1,"t":"<type>", …}`. Un type inconnu est ignoré, pour qu'une version suivante ne casse pas une ancienne. Une trame mal formée (longueur illisible ou trop grande, JSON illisible) ferme la connexion.

Avec l'URL `releve`, le démon envoie le jeton puis `<longueur>\n<JSON de NomsMaison>`, exactement comme le Passeur d'aujourd'hui, et ferme.

### 2.3 Les messages

Du démon vers l'app :

| `t` | Champs | Quand |
|---|---|---|
| `etat` | `version` (texte), `acces` (`"attente"`, `"autorise"`, `"refuse"`), `ouvertureSession` (`"active"`, `"inactive"`, `"aApprouver"`, `"indisponible"`), `profilExpire` (date ISO 8601 ou `null`) | à la connexion, puis à chaque changement |
| `releve` | `noms` : le `NomsMaison` complet | à la connexion, puis à chaque changement dans Maison, et sur demande |
| `identifie` | `demande` (entier), `ok` (booléen), `erreur` (`"inconnu"`, `"nonIdentifiable"` ou le texte de HomeKit) | réponse à `identifier` |

De l'app vers le démon :

| `t` | Champs | Effet |
|---|---|---|
| `relire` | — | relevé immédiat, batteries comprises |
| `identifier` | `demande` (entier choisi par l'app), `accessoire` (UUID) | `identify()` sur cet accessoire |
| `ouvertureSession` | `actif` (booléen) | le démon s'inscrit ou se désinscrit à l'ouverture de session |

`ouvertureSession` reprend `SMAppService.Status` : `enabled` → `"active"`, `notRegistered` → `"inactive"`, `requiresApproval` → `"aApprouver"` (refusé ou pas encore accepté dans Réglages > Général > Ouverture), `notFound` → `"indisponible"`.

### 2.4 Le relevé gagne l'identifiant des accessoires

`AccessoireMaison` gagne un champ facultatif `id` : `HMAccessory.uniqueIdentifier`, en texte (UUID). C'est par lui que l'app demande « Identifier ». `NomsMaison.version` passe à 2 ; un relevé de version 1 (sans `id`) se lit toujours.

### 2.5 Sécurité

Le jeton authentifie le démon auprès de l'app : un autre processus ne peut pas se faire passer pour lui sans le connaître. En sens inverse, le démon ne peut pas reconnaître l'app (ni App Group ni secret partagé entre une app Developer ID et une app de développement) : comme aujourd'hui, toute app locale qui ouvre l'URL peut recevoir le relevé (noms, pièces, zones, fabricants, batteries). Elle peut aussi demander « Identifier » ou changer l'ouverture de session, sans autre dommage qu'un appareil qui clignote ou un démarrage de plus. Rien ne sort du Mac : le démon ne se connecte qu'à 127.0.0.1.

## 3. Le fonctionnement du démon

### 3.1 Démarrage et masquage

- Lancé par une URL (LaunchServices le démarre s'il ne tourne pas) ou à l'ouverture de session.
- Il charge `Masqueur.bundle` **dans `application(_:didFinishLaunchingWithOptions:)`**, avant que UIKit connecte la scène :
  - le module échange les initialiseurs de `NSWindow` (`init(contentRect:styleMask:backing:defer:)` et sa variante avec `screen:`) contre des versions qui rendent toute fenêtre de l'app invisible dès sa création : `alphaValue = 0`, `ignoresMouseEvents`, sans ombre, `collectionBehavior` `.transient` et `.ignoresCycle` (hors de Mission Control et du cycle des fenêtres) ;
  - politique d'activation `.accessory` ;
  - par sécurité, `orderOut` de toute fenêtre de l'app sur les notifications d'AppKit (devient clé, principale, mise à jour, exposée).
  Validé au cinquième essai : ni fenêtre ni éclair.
- La scène imposée par UIKit est déclarée, sans contenu, et refermée dès sa connexion.
- Il crée le `HMHomeManager` et attend l'autorisation ; `acces` suit `authorizationStatus`.

### 3.2 Suivi de Maison

- Délégués de HomeKit : maisons ajoutées ou retirées, maison principale, accessoires ajoutés ou retirés, nom d'un accessoire, d'une pièce ou d'une zone, accessoire changé de pièce, services d'un accessoire mis à jour.
- À chaque changement, le démon attend **2 s** que les modifications groupées se terminent, refait le relevé, et l'envoie à tous les abonnés **s'il diffère** du dernier envoyé (date du relevé mise à part).
- Les **batteries** sont relues toutes les heures, et sur `relire` ; pas d'abonnement aux caractéristiques, pour ne pas solliciter les appareils.
- La joignabilité ne déclenche aucun envoi.

### 3.3 Durée de vie

- Inscrit à l'ouverture de session (`ouvertureSession` `"active"`) : il reste lancé en permanence.
- Sinon : il reste lancé tant qu'au moins une app est abonnée, et se ferme **10 minutes** après le départ de la dernière.
- Une demande `releve` sans abonné le ferme juste après l'envoi, comme le Passeur d'aujourd'hui.

### 3.4 Ouverture de session

Sur `ouvertureSession`, le démon appelle `SMAppService.mainApp.register()` ou `unregister()`, puis envoie `etat` à tous les abonnés. À la première inscription, macOS montre la notification « Élément d'arrière-plan ajouté ». Si Djoko l'a refusé dans les réglages, l'état est `"aApprouver"` et l'app explique où l'accepter.

### 3.5 Identifier

Sur `identifier`, le démon cherche l'accessoire par son UUID dans toutes les maisons. Inconnu : `identifie` avec `erreur` `"inconnu"`. `supportsIdentify` faux : `"nonIdentifiable"`. Sinon il appelle `identify()` et répond avec le résultat, ou le texte de l'erreur de HomeKit.

### 3.6 Expiration du profil

Le démon lit la date d'expiration de son propre profil (`embedded.provisionprofile` de son paquet, message CMS décodé) et l'envoie dans `etat` (`profilExpire`). Illisible : `null`.

### 3.7 Journal

Chaque décision importante va au journal du Mac, sous-système `fr.djoko.maillage.passeur` : lancement, autorisation, abonné accepté ou parti, relevé envoyé (nombre d'accessoires), identification (résultat), ouverture de session, fermeture et sa raison. **Jamais un nom de la maison, ni un UUID d'accessoire.**

## 4. Ce qui change dans les apps

### 4.1 Maillage Thread

- **Abonnement** : en mode direct, au lancement, `NomsInternes` ouvre une écoute persistante et l'URL `abonner`. Elle reçoit `etat` et `releve`, garde le dernier relevé dans `noms.json` comme aujourd'hui, et le dernier `etat` en mémoire.
- **Réabonnement** : connexion fermée, ou aucun démon connecté dans le délai, et l'app rouvre l'URL après 5 s, 10 s, 30 s, puis toutes les minutes. Le premier délai d'attente reste de 2 minutes, le temps d'une demande d'accès à Maison.
- La relance du Passeur à l'ouverture de la fenêtre des pièces (relevé de plus de 15 min) disparaît. « Actualiser depuis Maison » envoie `relire`.
- **Réglages › Maison** :
  - l'interrupteur **« Ouvrir Passeur Noms à l'ouverture de session »**, qui reflète `ouvertureSession` et envoie la commande ; grisé si le démon n'est pas connecté ; `"aApprouver"` : une ligne qui dit d'accepter Passeur Noms dans Réglages > Général > Ouverture ;
  - l'état du démon : connecté ou non, version, accès à Maison ;
  - l'expiration du profil : un avertissement **30 jours** avant `profilExpire`, avec `outils/passeur.sh` à relancer ; il remplace l'heuristique des noms de plus de 7 jours ;
  - démon introuvable : le message actuel, qui renvoie à `outils/passeur.sh`.
- **Fiche d'un appareil** : le bouton **« Identifier »** pour un appareil relié à un accessoire de Maison (par son nœud ou par association manuelle) qui a un `id`. Il envoie `identifier` et montre brièvement le résultat (« Identification demandée » ou l'erreur). Grisé si le démon n'est pas connecté ou si l'accessoire n'a pas d'`id`.
- **Mode démo** : jamais de démon.

### 4.2 Maillage Zigbee

Les mêmes ajouts, faits par la session Zigbee : `ProtocolePasseur.swift` recopié à l'octet, `NomsPasseur` en client abonné (relevé gardé dans `releve-maison.json`), l'interrupteur dans ses Réglages, et « Identifier » pour les appareils du pont retrouvés dans Maison (`FusionNoms`).

## 5. Erreurs

| Cas | Démon | App |
|---|---|---|
| Démon pas installé | — | message actuel : `outils/passeur.sh` |
| Profil expiré | macOS ne le lance plus | URL refusée : « profil du passeur expiré ? relance outils/passeur.sh » ; avertissement 30 jours avant |
| Accès à Maison refusé | `acces` `"refuse"`, relevé `statut` refusé | Réglages › Maison le dit, dernier relevé gardé |
| Mauvais jeton, trame mal formée | ferme la connexion | réabonnement, avec délai croissant |
| Démon fermé ou planté | — | réabonnement, dernier relevé gardé |
| Accessoire inconnu ou non identifiable | `identifie` en erreur | message bref dans la fiche |
| Ouverture de session refusée | `"aApprouver"` | ligne d'explication dans Réglages |
| Ancienne app (relevé ponctuel) | URL `releve` servie à l'identique | inchangée |

## 6. Tests et banc

**Tests automatiques :**
- `ProtocolePasseur` (dans les deux dépôts) : URL et lecture stricte, jeton, trames dans les deux sens, longueur limite, types inconnus ignorés, trame mal formée, relevé version 1 et version 2.
- Logique du démon, sans HomeKit, derrière une façade imitée (`SourceMaison`) : délai de regroupement de 2 s, envoi seulement si le relevé diffère, liste des abonnés, fermeture 10 min après le dernier abonné, relevé ponctuel puis fermeture, états `ouvertureSession`, réponses à `identifier` (inconnu, non identifiable, erreur, succès).
- Client de chaque app contre un faux démon sur la boucle locale : abonnement, relevés successifs, réabonnement avec délais, commandes envoyées, interrupteur et bouton grisés au bon moment.

**Banc avec Djoko :**
1. Installation par `outils/passeur.sh` : pas d'icône dans le Dock, au plus un éclair de fenêtre.
2. Les deux apps abonnées ; un accessoire renommé dans Maison change de nom dans les deux apps en quelques secondes.
3. « Identifier » depuis la fiche : l'appareil réagit.
4. L'interrupteur d'ouverture de session, vérifié par une déconnexion puis une reconnexion de la session.
5. Le démon fermé (par PID) puis relancé : les apps se réabonnent seules.
6. Maillage Thread 1.2.2 (relevé ponctuel) marche avec le nouveau démon.

## 7. Installation et livraison

- `outils/passeur.sh` compile `Passeur` et `Masqueur` en Catalyst, signe en développement, et remplace `~/Applications/Passeur Noms.app` seulement si c'est une installation faite par le script (enveloppe actuelle ou nouvelle app : marqueur vérifié). Il enregistre l'app auprès de LaunchServices et désinscrit l'ancienne. L'accès à Maison peut être redemandé une fois.
- **Ordre :**
  1. `ProtocolePasseur.swift` et le démon, dans Maillage Thread ;
  2. le client, les Réglages et « Identifier » dans Maillage Thread : version **1.3.0** ;
  3. la session Zigbee recopie `ProtocolePasseur.swift` à l'octet et fait sa partie, dans sa propre version.

## 8. Hors périmètre et limites

- **Distribution du démon** : il reste à compiler soi-même (`outils/passeur.sh`), comme le Passeur aujourd'hui ; pas de .dmg, pas d'App Store.
- **Commandes HomeKit** : seulement « Identifier » ; ni allumer, ni éteindre, ni piloter.
- **Renouvellement annuel** du profil : relancer `outils/passeur.sh`, que l'app rappelle 30 jours avant.
- **L'interception des initialiseurs de `NSWindow`** repose sur le comportement actuel d'UIKit pour Mac (macOS 27) : à revérifier à chaque version majeure de macOS (premier point du banc après une mise à jour).
- **Les changements reçus en arrière-plan** sont attendus d'après les essais (HomeKit répond en arrière-plan), mais non vérifiés en direct : c'est le premier point du banc.
