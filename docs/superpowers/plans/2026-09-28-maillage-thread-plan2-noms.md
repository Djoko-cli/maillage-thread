# Maillage Thread, plan 2 : les noms de Maison (passeur) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** afficher dans l'app les noms, pièces et fabricants de Maison. Un passeur, une app iOS lancée sur le Mac, lit HomeKit et écrit `noms.json` ; l'app le relit et le rapproche des appareils Matter.

**Architecture :**
- **Le passeur** `Passeur Noms` est une cible iOS du même projet XcodeGen, compilée pour « Designed for iPad ». Il lit Maison (`HMHomeManager`), écrit `noms.json` au format `NomsMaison` (partagé avec le cœur) dans un dossier choisi une fois (signet), puis se ferme.
- **Le script** `outils/passeur.sh` le compile avec l'équipe du certificat « Apple Development », l'enveloppe comme Xcode, puis le lance.
- **L'app** garde l'accès au dossier par un signet à portée de sécurité. Elle relit le fichier quand le passeur se ferme et quand elle revient au premier plan. Elle garde les derniers noms réussis.
- **Le cœur** choisit l'accessoire d'un nœud : le pont d'abord, un nœud nul ne désignant personne.

**Tech Stack :** Swift 6 (concurrence stricte complète, avertissements = erreurs), SwiftUI, HomeKit (iOS, `HMAccessory.matterNodeID`), AppKit (`NSOpenPanel`, `NSWorkspace`), signets à portée de sécurité, Swift Testing, XcodeGen, `xcodebuild` avec `-allowProvisioningUpdates`.

**Spec :** `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, section 5 (révisée le 28/09 après essai), à lire avec ce plan.

**Code validé avant exécution.** Tout le code de ce plan a été écrit, compilé et testé le 28/09 dans une copie du dépôt :
- 86 tests pour le cœur, 27 pour l'app, tous verts ;
- le passeur a été compilé et signé avec l'équipe gratuite de Djoko ;
- il a été lancé une fois pour de vrai avec Djoko : Gatekeeper, puis le choix du dossier, puis 131 accessoires écrits.

Exécuter une tâche, c'est transcrire les fichiers donnés, compiler et tester. Si un fichier doit s'écarter du texte donné, l'exécutant le dit dans son rapport, avec la raison.

**Faits établis par l'essai du 28/09 :**
- **HomeKit :** l'équipe de Djoko est gratuite (« Personal Team »). HomeKit est refusé à une app Catalyst, mais accepté pour une app iOS « Designed for iPad » (profil de 7 jours).
- **`matterNodeID`** est un `UInt64?` en Swift iOS.
- **Lancement :**
  - `open` sur le paquet iOS brut échoue ; il faut l'envelopper comme Xcode, avec `Wrapper/` et le lien `WrappedBundle` ;
  - au premier lancement de chaque compilation, Gatekeeper dit « endommagé ». Il faut cliquer Annuler, puis Réglages Système › Confidentialité et sécurité › « Ouvrir quand même ».
- **Pas d'App Group** avec une équipe gratuite.
- **Ne jamais signer l'app Mac avec l'équipe.** Son conteneur a été créé par les versions ad hoc : une version signée par l'équipe déclenche « L'app diffère des versions précédemment ouvertes » et bloque les tests hébergés. Seul le passeur est signé avec l'équipe, par la ligne de commande de `outils/passeur.sh`.
- **Dans la Maison de Djoko** (131 accessoires) :
  - 61 ont un `matterNodeID` à 0 ;
  - 45 accessoires partagent un nœud, celui du Hue Bridge (un pont, par IP) ;
  - 22 des 23 nœuds de la fabrique d'Apple vus en mDNS retrouvent leur nom.

**Écarts à la spec (assumés) :**
1. **Textes du passeur en français seulement.** Le passeur est un auxiliaire visible quelques secondes, il n'a donc pas de catalogue anglais. L'app, elle, reste en français et en anglais.
2. **Dossier conseillé : hors iCloud et hors du dépôt**, par exemple `~/Maillage Thread`. La spec disait Documents/Maillage Thread, mais Documents est synchronisé par iCloud chez Djoko, qui y a déjà perdu des fichiers. Lors de l'essai, le dossier choisi était la racine du dépôt, un dépôt public. D'où `noms.json` dans `.gitignore`, et un bouton « Changer de dossier… » dans le passeur, avec un compte à rebours de 10 s avant sa fermeture.

## Global Constraints

- **Plateformes :** l'app en macOS 26.0 minimum ; le passeur en iOS 18.0, lancé sur un Mac Apple Silicon « Designed for iPad ». Xcode 26 ou plus (développé avec Xcode 27), XcodeGen 2.45 ou plus.
- **Swift 6** (`SWIFT_VERSION: "6.0"`), `SWIFT_STRICT_CONCURRENCY: complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES`.
- **Identifiants :** app `fr.djoko.maillage` ; passeur `fr.djoko.maillage.passeur`, produit « Passeur Noms », module `Passeur`.
- **Contrat de `noms.json` :** `NomsMaison` version 1 (le cœur), avec `AccessoireMaison.noeudMatter` en 16 hexa majuscules et `pont` facultatif.
- **Code :**
  - identifiants et commentaires en français **sans accents** ;
  - textes affichés avec accents ;
  - tests en Swift Testing.
- **Textes de l'app :** catalogue `MaillageThread/Ressources/Localizable.xcstrings`, français source et anglais obligatoire. Une tâche qui ajoute des textes synchronise elle-même le catalogue : compiler, puis `outils/synchroniser-textes.sh`, puis ajouter les traductions à `outils/traductions/interface.json`, puis `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`. Le test `CataloguesTests.codeEtCatalogueAlignes` refuse une clé absente comme une clé morte.
- **Commandes,** depuis la racine du dépôt :
  - `outils/tester.sh` génère le projet, compile et lance les tests ; les produits vont dans `$HOME/Library/Developer/Xcode/DerivedData/maillage` (variable `DD`) ;
  - `outils/passeur.sh --sans-lancer` compile et enveloppe le passeur sans le lancer (variable `APP` pour l'installer ailleurs que dans `~/Applications`).
- **Signature :**
  - l'app reste ad hoc (`Signature.xcconfig`) ;
  - **ne jamais créer `Local.xcconfig`** pour ce plan : il signerait aussi l'app avec l'équipe ;
  - le passeur est signé avec l'équipe par `outils/passeur.sh` (`DEVELOPMENT_TEAM=` en ligne de commande, lu dans le certificat « Apple Development ») ;
  - aucun identifiant d'équipe, empreinte de certificat ni adresse électronique dans un fichier commité.
- **Données personnelles :** `noms.json` ne va jamais dans le dépôt, qui est public sur GitHub (`Djoko-cli/maillage-thread`). Pas de fixture de test tirée des vrais noms.
- **Commits :** un par tâche, message en français sans accents, terminé par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Seulement si Djoko a autorisé les commits ; jamais de push sans sa demande.
- **Interdits pour les agents :**
  - `sudo` ;
  - lancer le passeur (pas de `open`, toujours `--sans-lancer`) ;
  - installer le passeur dans `~/Applications` (toujours `APP=` vers un dossier temporaire) ;
  - lancer l'app en mode direct ;
  - réveiller l'écran.

  La tâche 5 se fait avec Djoko.

## Carte des fichiers

| Fichier | Rôle | Tâche |
|---|---|---|
| `MaillageCoeur/Noms/NomsMaison.swift` | contrat : `pont`, `AccessoireMaison.noeud(_:)` | 1 |
| `MaillageCoeur/Noms/ResolveurNoms.swift` | nœud nul ignoré, pont d'abord, sinon premier par nom | 1 |
| `MaillageCoeurTests/NomsTests.swift` | tests des noms | 1 |
| `Passeur/PasseurApp.swift`, `Passeur/Passeur.entitlements` | passeur iOS (HomeKit, choix du dossier, écriture, fermeture) | 2 |
| `project.yml`, `.gitignore` | cible et schéma `Passeur` ; `Passeur/Info.plist` et `noms.json` ignorés | 2 |
| `outils/passeur.sh` | compile avec l'équipe, enveloppe, lance (ou `--sans-lancer`) | 2 |
| `MaillageThread/Noms/DossierNoms.swift` | dossier des noms (signet), lecture, mémoire, lancement du passeur | 3 |
| `MaillageThreadTests/DossierNomsTests.swift` | tests du dossier des noms | 3 |
| `MaillageThread/Droits.entitlements` | `files.bookmarks.app-scope` | 3 |
| `MaillageThread/MaillageThreadApp.swift` | `DossierNoms` branché sur `Surveillance` | 3 |
| `MaillageThread/Vues/FenetreReglages.swift`, `MaillageThread/Vues/MenuBarre.swift` | section « Noms de Maison », « Rafraîchir les noms de Maison » | 4 |
| `outils/traductions/interface.json`, `MaillageThread/Ressources/Localizable.xcstrings` | anglais des nouveaux textes | 3, 4 |
| `README.md`, `README.fr.md`, spec section 5 | mode d'emploi du passeur, résultats | 5 |

---

### Task 1: Contrat et correspondance des noms (cœur)

**Files:**
- Modify: `MaillageCoeur/Noms/NomsMaison.swift` (fichier entier ci-dessous)
- Modify: `MaillageCoeur/Noms/ResolveurNoms.swift` (fichier entier ci-dessous)
- Test: `MaillageCoeurTests/NomsTests.swift` (fichier entier ci-dessous : 4 tests ajoutés)

**Interfaces:**
- Consumes : `NomsMaison`, `AccessoireMaison`, `ResolveurNoms`, `Instantane`, le `Banc` des tests (tout existe déjà).
- Produces :
  - `AccessoireMaison.pont: Bool?` et `AccessoireMaison.init(nom:piece:fabricant:modele:categorie:noeudMatter:pont:)`, où `pont` vaut `nil` par défaut ;
  - `static func AccessoireMaison.noeud(_ id: UInt64?) -> String?`, qui rend 16 hexa majuscules, ou `nil` pour `nil` ou 0 ;
  - `ResolveurNoms.accessoire(de:fabriqueApple:)`, qui rend l'accessoire `pont == true` d'un nœud, sinon le premier par nom, et `nil` pour le nœud `0000000000000000`. `fabriqueApple(appareils:)` ignore ce nœud.

- [ ] **Step 1 : écrire les tests.**

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

    @Test func noeudMatter() {
        #expect(AccessoireMaison.noeud(nil) == nil)
        #expect(AccessoireMaison.noeud(0) == nil, "accessoire non Matter")
        #expect(AccessoireMaison.noeud(0x4F63C86C) == "000000004F63C86C")
        #expect(AccessoireMaison.noeud(0xFEDCBA9876543210) == "FEDCBA9876543210")
    }

    /// Un pont porte plusieurs accessoires sur un seul noeud : le noeud prend
    /// le nom du pont, sinon du premier par nom.
    @Test func pont() throws {
        let halo = try #require(instantane.appareil("56B1E064401F74EF"))
        let f = "30FC8F95E0E1A385"
        let noeud = try #require(halo.instances.first { $0.fabrique == f }?.noeud)
        var maison = NomsMaison(date: Date(timeIntervalSince1970: 1_790_000_000), accessoires: [
            AccessoireMaison(nom: "Lampe 2", noeudMatter: noeud),
            AccessoireMaison(nom: "Pont Hue", categorie: "Bridge", noeudMatter: noeud, pont: true),
            AccessoireMaison(nom: "Lampe 1", noeudMatter: noeud),
        ])
        #expect(ResolveurNoms(maison: maison).nom(appareil: halo, fabriqueApple: f) == "Pont Hue")
        maison.accessoires[1].pont = nil
        #expect(ResolveurNoms(maison: maison).nom(appareil: halo, fabriqueApple: f) == "Lampe 1")
    }

    /// Un `matterNodeID` a 0 (accessoire non Matter) n'identifie personne.
    @Test func noeudNul() throws {
        var b = Banc()
        b.appareil("AAAA000000000001", noeud: 0, adresses: ["fd19:961f:2db3::11"])
        let a = try #require(Instantane(annonces: b.annonces).appareil("AAAA000000000001"))
        let n = ResolveurNoms(maison: NomsMaison(date: Date(timeIntervalSince1970: 1_790_000_000), accessoires: [
            AccessoireMaison(nom: "Camera IP", noeudMatter: "0000000000000000"),
        ]))
        #expect(n.fabriqueApple(appareils: [a]) == nil)
        #expect(n.accessoire(de: a, fabriqueApple: "30FC8F95E0E1A385") == nil)
        #expect(n.nom(appareil: a, fabriqueApple: "30FC8F95E0E1A385") == "AAAA000000000001")
    }

    /// `pont` est facultatif : un fichier sans ce champ se lit.
    @Test func contratSansPont() throws {
        let json = #"{"accessoires":[{"nom":"Halo","noeudMatter":"00000000000002E9"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        let n = try NomsMaison.lire(Data(json.utf8))
        #expect(n.accessoires.first?.pont == nil)
        #expect(n.accessoires.first?.noeudMatter == "00000000000002E9")
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

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageCoeurTests/NomsTests`
Expected: la compilation échoue avec `error: type 'AccessoireMaison' has no member 'noeud'`.

- [ ] **Step 3 : écrire le contrat et le résolveur.**

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
    /// Accessoire de categorie pont : il donne son nom au noeud qu'il partage
    /// avec les accessoires qu'il porte (absent des fichiers anciens).
    public var pont: Bool?

    public init(nom: String, piece: String? = nil, fabricant: String? = nil, modele: String? = nil,
                categorie: String? = nil, noeudMatter: String? = nil, pont: Bool? = nil) {
        self.nom = nom
        self.piece = piece
        self.fabricant = fabricant
        self.modele = modele
        self.categorie = categorie
        self.noeudMatter = noeudMatter
        self.pont = pont
    }

    /// `matterNodeID` en 16 hexa majuscules ; nil pour un accessoire non Matter (absent ou 0).
    public static func noeud(_ id: UInt64?) -> String? {
        guard let id, id != 0 else { return nil }
        return String(format: "%016llX", id)
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

    /// Noeud a 0 : accessoire non Matter, il n'identifie personne.
    static let noeudNul = "0000000000000000"

    /// Fabrique d'Apple : celle dont les noeuds recouvrent le plus de
    /// `noeudMatter` de Maison (au moins un) ; a egalite, la plus petite.
    public func fabriqueApple(appareils: [Appareil]) -> String? {
        let connus = Set(maison?.accessoires.compactMap { $0.noeudMatter?.uppercased() } ?? []).subtracting([Self.noeudNul])
        guard !connus.isEmpty else { return nil }
        var scores: [String: Int] = [:]
        for a in appareils {
            for i in a.instances where connus.contains(i.noeud) { scores[i.fabrique, default: 0] += 1 }
        }
        return scores.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }

    /// Accessoire de Maison d'un appareil (par son noeud sur la fabrique d'Apple).
    /// Un pont porte plusieurs accessoires sur un seul noeud : le noeud prend
    /// le nom du pont, sinon du premier par nom.
    public func accessoire(de a: Appareil, fabriqueApple f: String?) -> AccessoireMaison? {
        guard let f, let maison, let noeud = a.instances.first(where: { $0.fabrique == f })?.noeud,
              noeud != Self.noeudNul else { return nil }
        let candidats = maison.accessoires.filter { $0.noeudMatter?.uppercased() == noeud }
        return candidats.first { $0.pont == true } ?? candidats.min { $0.nom < $1.nom }
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

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageCoeurTests/NomsTests`
Expected: `Test run with 8 tests in 1 suite passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 5 : toute la suite.**

Run: `outils/tester.sh`
Expected: `86 tests in 13 suites passed` (cœur) et `23 tests in 11 suites passed` (app), sans avertissement.

- [ ] **Step 6 : commit.**

```bash
git add MaillageCoeur/Noms/NomsMaison.swift MaillageCoeur/Noms/ResolveurNoms.swift MaillageCoeurTests/NomsTests.swift
git commit -m "Retenir le pont et ignorer les noeuds nuls dans les noms de Maison

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 2: Le passeur (app iOS) et `outils/passeur.sh`

**Files:**
- Create: `Passeur/PasseurApp.swift`, `Passeur/Passeur.entitlements`, `outils/passeur.sh` (exécutable)
- Modify: `project.yml` (cible et schéma `Passeur`), `.gitignore` (`Passeur/Info.plist`, `noms.json`) (fichiers entiers ci-dessous)

**Interfaces:**
- Consumes : `NomsMaison`, `AccessoireMaison`, `AccessoireMaison.noeud(_:)` et `CodageJSON` (tâche 1). Les sources `MaillageCoeur/Noms/NomsMaison.swift` et `MaillageCoeur/Annonces/CodageJSON.swift` sont compilées **dans** la cible du passeur, qui ne lie pas le framework (macOS seulement).
- Produces :
  - l'app « Passeur Noms » (`fr.djoko.maillage.passeur`) ;
  - le fichier `noms.json` dans le dossier choisi (signet dans ses préférences, clé `dossierNoms`) ;
  - `outils/passeur.sh [--sans-lancer]` (variables `APP`, `DD`, `EQUIPE`) ;
  - le schéma XcodeGen `Passeur`. Le schéma `MaillageThread` ne change pas : `outils/tester.sh` ne compile pas le passeur.

**Notes :**
- Le passeur n'a pas de tests automatiques : il appelle HomeKit, et la conversion qu'il fait tient dans `AccessoireMaison.noeud(_:)`, testée à la tâche 1.
- Sa compilation demande qu'un compte Apple soit ouvert dans Xcode. L'équipe gratuite suffit ; le profil de 7 jours est créé ou renouvelé par `-allowProvisioningUpdates`.

- [ ] **Step 1 : écrire les fichiers.**

`Passeur/PasseurApp.swift` :

```swift
import HomeKit
import SwiftUI

/// Passeur des noms de Maison : app iOS lancee sur le Mac (« concue pour
/// iPad »), seule forme qui ait HomeKit avec une equipe gratuite. Elle lit
/// Maison, ecrit `noms.json` dans le dossier choisi une fois, puis se ferme.
@main
struct PasseurApp: App {
    @State private var passeur = Passeur()

    var body: some Scene {
        WindowGroup {
            VuePasseur()
                .environment(passeur)
        }
    }
}

struct VuePasseur: View {
    @Environment(Passeur.self) private var passeur
    @State private var choisir = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Passeur Noms").font(.title2.bold())
            Text(passeur.etat).multilineTextAlignment(.center)
            if passeur.dossierManquant {
                Button("Choisir le dossier des noms…") { choisir = true }
                    .buttonStyle(.borderedProminent)
            } else if let dossier = passeur.dossierUtilise {
                Text("Dossier : \(dossier)").font(.caption).foregroundStyle(.secondary)
                Button("Changer de dossier…") {
                    passeur.suspendreFermeture()
                    choisir = true
                }
                if let n = passeur.fermetureDans {
                    Text("Fermeture dans \(n) s").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Choisis un dossier hors iCloud et hors du dépôt, par exemple « Maillage Thread » dans ton dossier personnel. Maillage Thread lira noms.json dans ce même dossier.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(minWidth: 420)
        .fileImporter(isPresented: $choisir, allowedContentTypes: [.folder]) { passeur.dossierChoisi($0) }
        .onChange(of: choisir) { _, ouvert in
            if !ouvert { passeur.reprendreFermeture() }
        }
        .task { passeur.demarrer() }
    }
}

@MainActor
@Observable
final class Passeur: NSObject, HMHomeManagerDelegate {
    static let cleDossier = "dossierNoms"
    static let fichier = "noms.json"

    private(set) var etat = "Lecture de Maison…"
    private(set) var dossierManquant = false
    /// Dossier ou `noms.json` a ete ecrit (chemin affiche).
    private(set) var dossierUtilise: String?
    /// Secondes avant la fermeture, apres une ecriture reussie.
    private(set) var fermetureDans: Int?
    @ObservationIgnored private var gestionnaire: HMHomeManager?
    /// Releve en attente d'un dossier.
    @ObservationIgnored private var enAttente: NomsMaison?
    /// Dernier releve ecrit : reecrit ailleurs si l'on change de dossier.
    @ObservationIgnored private var dernier: NomsMaison?
    @ObservationIgnored private var compteARebours: Task<Void, Never>?

    func demarrer() {
        guard gestionnaire == nil else { return }
        let g = HMHomeManager()
        g.delegate = self
        gestionnaire = g
    }

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        MainActor.assumeIsolated { self.relever(manager) }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        MainActor.assumeIsolated { self.autorisation(status) }
    }

    private func autorisation(_ s: HMHomeManagerAuthorizationStatus) {
        guard s.contains(.determined), !s.contains(.authorized) else { return }
        ecrire(NomsMaison(date: .now, statut: .refuse,
                          message: "Accès à Maison refusé : Réglages Système › Confidentialité et sécurité › Maison."))
    }

    private func relever(_ manager: HMHomeManager) {
        guard manager.authorizationStatus.contains(.authorized) else { return }
        let accessoires = manager.homes.flatMap(\.accessories).map { a in
            AccessoireMaison(nom: a.name, piece: a.room?.name, fabricant: a.manufacturer, modele: a.model,
                             categorie: a.category.localizedDescription,
                             noeudMatter: AccessoireMaison.noeud(a.matterNodeID),
                             pont: a.category.categoryType == HMAccessoryCategoryTypeBridge ? true : nil)
        }.sorted { $0.nom < $1.nom }
        let domicile = manager.homes.map(\.name).joined(separator: " + ")
        ecrire(NomsMaison(date: .now, statut: .ok, domicile: domicile.isEmpty ? nil : domicile, accessoires: accessoires))
    }

    func dossierChoisi(_ r: Result<URL, any Error>) {
        guard case .success(let url) = r else { return }
        let acces = url.startAccessingSecurityScopedResource()
        defer { if acces { url.stopAccessingSecurityScopedResource() } }
        guard let signet = try? url.bookmarkData() else {
            etat = "Ce dossier n'est pas utilisable."
            return
        }
        UserDefaults.standard.set(signet, forKey: Self.cleDossier)
        dossierManquant = false
        if let n = enAttente ?? dernier { ecrire(n) }
    }

    private func dossier() -> URL? {
        guard let signet = UserDefaults.standard.data(forKey: Self.cleDossier) else { return nil }
        var perime = false
        guard let url = try? URL(resolvingBookmarkData: signet, options: [], relativeTo: nil,
                                 bookmarkDataIsStale: &perime) else { return nil }
        if perime, let nouveau = try? url.bookmarkData() { UserDefaults.standard.set(nouveau, forKey: Self.cleDossier) }
        return url
    }

    /// Ecrit `noms.json` dans le dossier choisi, puis ferme l'app 10 s plus tard.
    private func ecrire(_ n: NomsMaison) {
        guard let dossier = dossier() else {
            enAttente = n
            dossierManquant = true
            etat = "\(n.accessoires.count) accessoires lus. Choisis le dossier où écrire noms.json."
            return
        }
        let acces = dossier.startAccessingSecurityScopedResource()
        defer { if acces { dossier.stopAccessingSecurityScopedResource() } }
        do {
            try n.donnees().write(to: dossier.appendingPathComponent(Self.fichier), options: .atomic)
            enAttente = nil
            dernier = n
            dossierUtilise = dossier.path(percentEncoded: false)
            etat = n.statut == .ok
                ? "\(n.accessoires.count) accessoires écrits dans \(Self.fichier)."
                : (n.message ?? "Accès à Maison refusé.")
            reprendreFermeture()
        } catch {
            enAttente = n
            dossierManquant = true
            etat = "Écriture impossible : \(error.localizedDescription)"
        }
    }

    /// Le compte a rebours s'arrete pendant le choix d'un autre dossier.
    func suspendreFermeture() {
        compteARebours?.cancel()
        compteARebours = nil
        fermetureDans = nil
    }

    /// Ferme l'app 10 s apres la derniere ecriture reussie.
    func reprendreFermeture() {
        guard dernier != nil, !dossierManquant else { return }
        compteARebours?.cancel()
        compteARebours = Task { [weak self] in
            for n in stride(from: 10, to: 0, by: -1) {
                self?.fermetureDans = n
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            exit(0)
        }
    }
}
```

`Passeur/Passeur.entitlements` :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.homekit</key>
	<true/>
</dict>
</plist>
```

`outils/passeur.sh` :

```sh
#!/bin/sh
# Passeur des noms de Maison : app iOS lancee sur le Mac (« concue pour
# iPad »), seule forme qui ait HomeKit avec une equipe Apple gratuite.
# Compile, enveloppe l'app comme Xcode (Wrapper/ et WrappedBundle) dans
# ~/Applications, puis la lance. Seul le passeur est signe avec l'equipe (l'app
# reste ad hoc : changer sa signature ferait redemander ses autorisations).
# Equipe : celle du certificat « Apple Development » (ou EQUIPE=XXXXXXXXXX).
# Equipe gratuite : profil de 7 jours ; relancer ce script pour rafraichir.
set -eu
cd "$(dirname "$0")/.."
EQUIPE=${EQUIPE:-$(security find-certificate -c "Apple Development" -p 2>/dev/null |
  openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1)}
if [ -z "$EQUIPE" ]; then
  echo "Pas de certificat Apple Development : ajouter un compte Apple dans Xcode (Réglages > Comptes), ou EQUIPE=XXXXXXXXXX" >&2
  exit 1
fi
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage-passeur}
APP=${APP:-"$HOME/Applications/Passeur Noms.app"}
JOURNAL=${TMPDIR:-/tmp}/maillage-passeur.log
xcodegen generate --quiet
if ! xcodebuild -project MaillageThread.xcodeproj -scheme Passeur \
    -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
    -derivedDataPath "$DD" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$EQUIPE" build > "$JOURNAL" 2>&1; then
  grep -E "error:" "$JOURNAL" >&2 || true
  echo "échec de la compilation, journal complet : $JOURNAL" >&2
  exit 1
fi
# Enveloppe : un paquet Mac qui contient l'app iOS, comme Xcode l'installe.
mkdir -p "$HOME/Applications"
rm -rf "$APP"
mkdir -p "$APP/Wrapper"
cp -R "$DD/Build/Products/Debug-iphoneos/Passeur Noms.app" "$APP/Wrapper/"
ln -s "Wrapper/Passeur Noms.app" "$APP/WrappedBundle"
if [ "${1:-}" = "--sans-lancer" ]; then
  echo "Passeur Noms prêt (non lancé) : $APP"
else
  open "$APP"
  echo "Passeur Noms lancé : $APP"
fi
```

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
  Passeur:
    type: application
    platform: iOS
    deploymentTarget: "18.0"
    sources:
      - path: Passeur
      - path: MaillageCoeur/Noms/NomsMaison.swift
      - path: MaillageCoeur/Annonces/CodageJSON.swift
    info:
      path: Passeur/Info.plist
      properties:
        CFBundleDisplayName: Passeur Noms
        NSHomeKitUsageDescription: "Passeur Noms lit les noms, pièces et fabricants de vos accessoires Maison pour Maillage Thread. Rien ne sort de ce Mac."
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationPortraitUpsideDown
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
    settings:
      base:
        PRODUCT_NAME: Passeur Noms
        PRODUCT_MODULE_NAME: Passeur
        PRODUCT_BUNDLE_IDENTIFIER: fr.djoko.maillage.passeur
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "1"
        CODE_SIGN_ENTITLEMENTS: Passeur/Passeur.entitlements
        # HomeKit exige un profil : signature automatique avec l'equipe de
        # Local.xcconfig (equipe gratuite : app iOS « concue pour iPad »).
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: Apple Development
        SUPPORTS_MACCATALYST: NO
        SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: YES
        TARGETED_DEVICE_FAMILY: "1,2"
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
  Passeur:
    build:
      targets:
        Passeur: all
    run:
      config: Debug
```

`.gitignore` :

```gitignore
# Projet genere par xcodegen (project.yml fait foi)
*.xcodeproj/
*.xcworkspace/
# Produits de compilation
build/
DerivedData/
.build/
*.xcresult
*.dmg
# Fichiers propres a l'utilisateur
xcuserdata/
*.xcuserstate
.swiftpm/
.DS_Store
__pycache__/
# Espace de travail des outils de conception (maquettes, suivi d'execution)
.superpowers/

# Signature propre au poste (equipe Apple Development), jamais commitee
Local.xcconfig

# Genere par xcodegen depuis project.yml (info:)
MaillageThread/Info.plist
Passeur/Info.plist

# Noms de Maison ecrits par le passeur : jamais dans le depot (depot public)
noms.json
```

Run: `chmod +x outils/passeur.sh`

- [ ] **Step 2 : la suite de l'app ne change pas.**

Run: `outils/tester.sh`
Expected: `86 tests in 13 suites passed` et `23 tests in 11 suites passed`, `** TEST SUCCEEDED **`.

- [ ] **Step 3 : compiler et envelopper le passeur, sans le lancer ni l'installer dans `~/Applications`.**

Run: `APP="$TMPDIR/passeur-essai/Passeur Noms.app" outils/passeur.sh --sans-lancer`
Expected: `Passeur Noms prêt (non lancé) : …/passeur-essai/Passeur Noms.app`

Run: `ls "$TMPDIR/passeur-essai/Passeur Noms.app"`
Expected: `Wrapper` et `WrappedBundle`.

Run: `codesign -d --entitlements - --xml "$TMPDIR/passeur-essai/Passeur Noms.app/Wrapper/Passeur Noms.app" | plutil -p - | grep -c homekit`
Expected: `1`.

Run: `grep "warning:" "$TMPDIR/maillage-passeur.log" | grep -v appintentsmetadataprocessor | grep -c .`
Expected: `0`. La ligne d'`appintentsmetadataprocessor` (« Metadata extraction skipped ») est un bruit connu, que `outils/tester.sh` filtre aussi.

Ensuite : `rm -rf "$TMPDIR/passeur-essai"`.

- [ ] **Step 4 : commit.**

```bash
git add Passeur/PasseurApp.swift Passeur/Passeur.entitlements outils/passeur.sh project.yml .gitignore
git commit -m "Ajouter le passeur des noms de Maison, app iOS lancee sur le Mac

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 3: Lire les noms dans l'app (`DossierNoms`)

**Files:**
- Create: `MaillageThread/Noms/DossierNoms.swift`, `MaillageThreadTests/DossierNomsTests.swift`
- Modify: `MaillageThread/Droits.entitlements`, `MaillageThread/MaillageThreadApp.swift` (fichiers entiers ci-dessous) ; `outils/traductions/interface.json` et `MaillageThread/Ressources/Localizable.xcstrings` (par les outils, step 5)

**Interfaces:**
- Consumes : `NomsMaison.lire(_:)`, `NomsMaison.donnees()`, `StatutPasseur`, `Surveillance.noms` (`ResolveurNoms`, `maison` modifiable), `Surveillance.dossierParDefaut`, `Surveillance.sousTests`.
- Produces : `@MainActor @Observable final class DossierNoms`, avec :
  - `init(preferences: UserDefaults = .standard, cache: URL?)` ;
  - `dossier: URL?`, `noms: NomsMaison?`, `probleme: String?` ;
  - `surNoms: ((NomsMaison?) -> Void)?` ;
  - `demarrer()`, `choisir()`, `lire()`, `integrer(_:)`, `lancerPasseur()` ;
  - les statiques `retenir(_:ancien:) -> (NomsMaison?, String?)`, `estAncien(_:maintenant:) -> Bool`, `lire(dans:) -> Result<NomsMaison, ErreurNoms>`, et les constantes `fichier` (« noms.json »), `idPasseur`, `validite` (7 jours).

  L'app lui passe `cache` : `Application Support/Maillage Thread/noms-maison.json` en mode direct, `nil` en mode démo. Elle la branche sur `surveillance.noms.maison` et l'injecte dans l'environnement du menu et des réglages, qui s'en servent à la tâche 4.

- [ ] **Step 1 : écrire les tests.**

`MaillageThreadTests/DossierNomsTests.swift` :

```swift
import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Noms de Maison : dossier du passeur")
struct DossierNomsTests {
    static let date = Date(timeIntervalSince1970: 1_790_000_000)

    static func noms(_ statut: StatutPasseur = .ok, nom: String = "Halo") -> NomsMaison {
        NomsMaison(date: date, statut: statut, message: statut == .ok ? nil : "Accès refusé",
                   accessoires: statut == .ok ? [AccessoireMaison(nom: nom, noeudMatter: "00000000000002E9")] : [])
    }

    /// Un releve reussi remplace les noms ; un echec du passeur les garde et dit pourquoi.
    @Test func echecGardeLesNoms() {
        let ancien = Self.noms(nom: "Halo")
        let (garde, probleme) = DossierNoms.retenir(Self.noms(.refuse), ancien: ancien)
        #expect(garde == ancien)
        #expect(probleme == "Accès refusé")
        let (neuf, rien) = DossierNoms.retenir(Self.noms(nom: "Pont"), ancien: ancien)
        #expect(neuf?.accessoires.first?.nom == "Pont")
        #expect(rien == nil)
    }

    /// Au-dela de 7 jours, le profil gratuit du passeur a expire.
    @Test func ancien() {
        #expect(!DossierNoms.estAncien(Self.noms(), maintenant: Self.date + 6 * 86_400))
        #expect(DossierNoms.estAncien(Self.noms(), maintenant: Self.date + 8 * 86_400))
    }

    @Test func lectureDansUnDossier() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("noms-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        guard case .failure(.absent) = DossierNoms.lire(dans: dossier) else {
            Issue.record("sans noms.json : absent")
            return
        }
        try Self.noms().donnees().write(to: dossier.appendingPathComponent(DossierNoms.fichier))
        #expect(try DossierNoms.lire(dans: dossier).get() == Self.noms())
        try Data("pas du json".utf8).write(to: dossier.appendingPathComponent(DossierNoms.fichier))
        guard case .failure(.illisible) = DossierNoms.lire(dans: dossier) else {
            Issue.record("fichier abime : illisible")
            return
        }
    }

    /// Les derniers noms retenus sont gardes dans le dossier de l'app et relus au lancement.
    @Test func memoireDesNoms() throws {
        let domaine = "maillage-tests-noms"
        let preferences = try #require(UserDefaults(suiteName: domaine))
        defer { preferences.removePersistentDomain(forName: domaine) }
        let cache = FileManager.default.temporaryDirectory
            .appendingPathComponent("noms-\(UUID().uuidString)").appendingPathComponent("noms-maison.json")
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }

        let d = DossierNoms(preferences: preferences, cache: cache)
        #expect(d.noms == nil)
        var recus: [NomsMaison?] = []
        d.surNoms = { recus.append($0) }
        d.integrer(Self.noms())
        d.integrer(Self.noms(.refuse))
        #expect(d.noms == Self.noms(), "l'echec n'efface pas les noms")
        #expect(d.probleme == "Accès refusé")
        #expect(recus == [Self.noms()], "un seul changement")
        #expect(DossierNoms(preferences: preferences, cache: cache).noms == Self.noms(), "relus au lancement")
    }
}
```

- [ ] **Step 2 : vérifier qu'ils échouent.**

Run: `outils/tester.sh MaillageThreadTests/DossierNomsTests`
Expected: la compilation échoue avec `error: cannot find 'DossierNoms' in scope`.

- [ ] **Step 3 : écrire `DossierNoms`, le droit aux signets et le branchement.**

`MaillageThread/Noms/DossierNoms.swift` :

```swift
import AppKit
import Foundation
import MaillageCoeur
import Observation

/// Noms de Maison ecrits par le passeur (`noms.json`) dans un dossier choisi
/// une fois (signet a portee de securite, garde dans les preferences). Les
/// derniers noms lus avec succes sont gardes dans le dossier de l'app : un
/// fichier d'echec du passeur (acces a Maison refuse) ne les efface pas.
@MainActor
@Observable
final class DossierNoms {
    enum ErreurNoms: LocalizedError {
        case absent
        case illisible(String)

        var errorDescription: String? {
            switch self {
            case .absent: String(localized: "Pas encore de noms.json dans ce dossier : lance le passeur.")
            case .illisible(let m): String(localized: "noms.json illisible : \(m)")
            }
        }
    }

    nonisolated static let cleSignet = "dossierNoms"
    nonisolated static let fichier = "noms.json"
    nonisolated static let idPasseur = "fr.djoko.maillage.passeur"
    /// Profil gratuit du passeur : 7 jours ; au-dela, il faut le recompiler.
    nonisolated static let validite: TimeInterval = 7 * 24 * 3600

    private(set) var dossier: URL?
    /// Derniers noms lus avec succes.
    private(set) var noms: NomsMaison?
    /// Dernier probleme : acces refuse par Maison, fichier absent ou illisible, passeur introuvable.
    private(set) var probleme: String?
    /// Appele a chaque changement des noms retenus.
    @ObservationIgnored var surNoms: ((NomsMaison?) -> Void)?

    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let cache: URL?
    @ObservationIgnored private var observateurs: [NSObjectProtocol] = []

    /// `cache` : ou garder les derniers noms (nil : nulle part, mode demo).
    init(preferences: UserDefaults = .standard, cache: URL?) {
        self.preferences = preferences
        self.cache = cache
        noms = cache.flatMap { try? NomsMaison.lire(Data(contentsOf: $0)) }
        dossier = Self.resoudre(preferences.data(forKey: Self.cleSignet))
    }

    /// Donne les noms gardes, relit le dossier, puis le relit quand le passeur
    /// se ferme et quand l'app revient au premier plan.
    func demarrer() {
        surNoms?(noms)
        lire()
        observateurs.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] n in
            let id = (n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated {
                if id == Self.idPasseur { self?.lire() }
            }
        })
        observateurs.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lire() }
        })
    }

    /// Choix du dossier ou le passeur ecrit `noms.json`.
    func choisir() {
        let panneau = NSOpenPanel()
        panneau.canChooseDirectories = true
        panneau.canChooseFiles = false
        panneau.allowsMultipleSelection = false
        panneau.canCreateDirectories = true
        panneau.message = String(localized: "Dossier où le passeur écrit noms.json, hors iCloud et hors du dépôt (par exemple « Maillage Thread » dans ton dossier personnel).")
        NSApp.activate()
        guard panneau.runModal() == .OK, let url = panneau.url else { return }
        do {
            let signet = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            preferences.set(signet, forKey: Self.cleSignet)
            dossier = Self.resoudre(signet)
            lire()
        } catch {
            probleme = error.localizedDescription
        }
    }

    /// Relit `noms.json` dans le dossier choisi.
    func lire() {
        guard let dossier else { return }
        let acces = dossier.startAccessingSecurityScopedResource()
        defer { if acces { dossier.stopAccessingSecurityScopedResource() } }
        switch Self.lire(dans: dossier) {
        case .success(let n): integrer(n)
        case .failure(let e): probleme = e.errorDescription
        }
    }

    /// Retient un fichier lu : les noms s'il est reussi, sinon le probleme.
    func integrer(_ n: NomsMaison) {
        let (garde, p) = Self.retenir(n, ancien: noms)
        probleme = p
        guard garde != noms else { return }
        noms = garde
        if let garde, let cache {
            do {
                try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
                try garde.donnees().write(to: cache, options: .atomic)
            } catch {
                probleme = error.localizedDescription
            }
        }
        surNoms?(garde)
    }

    /// Lance le passeur (installe par outils/passeur.sh) ; il ecrit puis se ferme.
    func lancerPasseur() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.idPasseur) else {
            probleme = String(localized: "Passeur Noms introuvable : lance outils/passeur.sh.")
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, erreur in
            guard let erreur else { return }
            let m = erreur.localizedDescription
            Task { @MainActor in self?.probleme = m }
        }
    }

    /// Un releve reussi remplace les noms ; un echec les garde et dit pourquoi.
    nonisolated static func retenir(_ nouveau: NomsMaison, ancien: NomsMaison?) -> (NomsMaison?, String?) {
        switch nouveau.statut {
        case .ok: (nouveau, nil)
        case .refuse: (ancien, nouveau.message ?? String(localized: "Accès à Maison refusé au passeur."))
        case .indisponible: (ancien, nouveau.message ?? String(localized: "HomeKit indisponible pour le passeur."))
        case .erreur: (ancien, nouveau.message ?? String(localized: "Le passeur a échoué."))
        }
    }

    /// Noms de plus de 7 jours : le profil gratuit du passeur a expire.
    nonisolated static func estAncien(_ n: NomsMaison, maintenant: Date) -> Bool {
        maintenant.timeIntervalSince(n.date) > validite
    }

    /// Lit `noms.json` dans un dossier deja accessible.
    nonisolated static func lire(dans dossier: URL) -> Result<NomsMaison, ErreurNoms> {
        guard let d = try? Data(contentsOf: dossier.appendingPathComponent(fichier)) else { return .failure(.absent) }
        do {
            return .success(try NomsMaison.lire(d))
        } catch {
            return .failure(.illisible(error.localizedDescription))
        }
    }

    private static func resoudre(_ signet: Data?) -> URL? {
        guard let signet else { return nil }
        var perime = false
        return try? URL(resolvingBookmarkData: signet, options: .withSecurityScope, relativeTo: nil,
                        bookmarkDataIsStale: &perime)
    }
}
```

`MaillageThread/Droits.entitlements` :

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
	<key>com.apple.security.files.bookmarks.app-scope</key>
	<true/>
</dict>
</plist>
```

`MaillageThread/MaillageThreadApp.swift` :

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
    @State private var nomsMaison: DossierNoms
    private let notifications = Notifications()
    private static let demo = CommandLine.arguments.contains("-demo")
    /// Le graphe s'ouvre au lancement en mode demo et au tout premier lancement
    /// (jamais a l'ouverture de session ensuite).
    private let ouvrirGraphe: Bool
    static let clePremierGraphe = "grapheDejaOuvert"

    init() {
        let s = Surveillance(mode: Self.demo ? .demo : .direct, dossier: Self.demo ? nil : Surveillance.dossierParDefaut)
        let o = OuvertureSession()
        let d = DossierNoms(cache: Self.demo ? nil : Surveillance.dossierParDefaut.appendingPathComponent("noms-maison.json"))
        _surveillance = State(initialValue: s)
        _ouverture = State(initialValue: o)
        _nomsMaison = State(initialValue: d)
        let premier = !UserDefaults.standard.bool(forKey: Self.clePremierGraphe)
        ouvrirGraphe = !Surveillance.sousTests && (Self.demo || premier)
        guard !Surveillance.sousTests else { return }
        if !Self.demo {
            UserDefaults.standard.set(true, forKey: Self.clePremierGraphe)
            let n = notifications
            s.surAlertes = { n.presenter($0) }
            n.demanderAutorisation()
            o.proposerAuPremierLancement()
            d.surNoms = { [weak s] m in s?.noms.maison = m }
            d.demarrer()
        }
        s.demarrer()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarre()
                .environment(surveillance)
                .environment(ouverture)
                .environment(nomsMaison)
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
                .environment(nomsMaison)
        }
    }
}
```

- [ ] **Step 4 : vérifier qu'ils passent.**

Run: `outils/tester.sh MaillageThreadTests/DossierNomsTests`
Expected: `Test run with 4 tests in 1 suite passed`.

- [ ] **Step 5 : les textes de `DossierNoms` dans le catalogue.**

Run: `outils/synchroniser-textes.sh`, puis :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "Pas encore de noms.json dans ce dossier : lance le passeur.": "No noms.json in this folder yet: run the name bridge.",
    "noms.json illisible : %@": "Unreadable noms.json: %@",
    "Dossier où le passeur écrit noms.json, hors iCloud et hors du dépôt (par exemple « Maillage Thread » dans ton dossier personnel).": "Folder where the name bridge writes noms.json, outside iCloud and the repository (for example “Maillage Thread” in your home folder).",
    "Passeur Noms introuvable : lance outils/passeur.sh.": "Passeur Noms not found: run outils/passeur.sh.",
    "Accès à Maison refusé au passeur.": "The name bridge was denied access to Home.",
    "HomeKit indisponible pour le passeur.": "HomeKit is unavailable to the name bridge.",
    "Le passeur a échoué.": "The name bridge failed.",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
```

Run: `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`

- [ ] **Step 6 : toute la suite.**

Run: `outils/tester.sh`
Expected: `86 tests in 13 suites passed` et `27 tests in 12 suites passed`, sans avertissement (`CataloguesTests` compris).

- [ ] **Step 7 : commit.**

```bash
git add MaillageThread/Noms/DossierNoms.swift MaillageThreadTests/DossierNomsTests.swift MaillageThread/Droits.entitlements MaillageThread/MaillageThreadApp.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Lire les noms de Maison ecrits par le passeur

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 4: Réglages et menu des noms

**Files:**
- Modify: `MaillageThread/Vues/FenetreReglages.swift`, `MaillageThread/Vues/MenuBarre.swift` (fichiers entiers ci-dessous) ; `outils/traductions/interface.json` et `MaillageThread/Ressources/Localizable.xcstrings` (par les outils)

**Interfaces:**
- Consumes : `DossierNoms` dans l'environnement (tâche 3) : `dossier`, `noms`, `probleme`, `choisir()`, `lancerPasseur()`, `estAncien(_:maintenant:)` ; `Surveillance.mode`.
- Produces :
  - dans les Réglages, une section « Noms de Maison » : dossier et « Choisir… », « Noms lus » (nombre et date), avertissement au-delà de 7 jours, problème, « Rafraîchir les noms de Maison » (désactivé en démo) ;
  - dans le menu, « Rafraîchir les noms de Maison » (mode direct seulement).

- [ ] **Step 1 : écrire les vues.**

`MaillageThread/Vues/FenetreReglages.swift` :

```swift
import AppKit
import MaillageCoeur
import SwiftUI
import UniformTypeIdentifiers

/// Reglages : notifications par categorie, ouverture a la connexion, langue,
/// noms de Maison (dossier du passeur), diagnostic et capture.
struct FenetreReglages: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(OuvertureSession.self) private var ouverture
    @Environment(DossierNoms.self) private var nomsMaison
    @AppStorage(Notifications.cle(.scission)) private var scission = CategorieAlerte.scission.parDefaut
    @AppStorage(Notifications.cle(.routeurDisparu)) private var routeurDisparu = CategorieAlerte.routeurDisparu.parDefaut
    @AppStorage(Notifications.cle(.pertes)) private var pertes = CategorieAlerte.pertes.parDefaut
    @AppStorage(Notifications.cle(.informations)) private var informations = CategorieAlerte.informations.parDefaut
    @State private var messageCapture: String?
    @State private var langue = LangueApp.lire()
    @State private var messageLangue: String?

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
            Section {
                Picker("Langue", selection: $langue) {
                    Text("Celle du Mac").tag(LangueApp.systeme)
                    Text(verbatim: "Français").tag(LangueApp.francais)
                    Text(verbatim: "English").tag(LangueApp.anglais)
                }
                .onChange(of: langue) { _, l in LangueApp.ecrire(l) }
                if langue != LangueApp.auLancement {
                    HStack {
                        Text("La langue change au prochain lancement.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Relancer maintenant") {
                            Task {
                                do { try await LangueApp.relancer() } catch { messageLangue = error.localizedDescription }
                            }
                        }
                    }
                }
                if let messageLangue {
                    Text(messageLangue).foregroundStyle(.red)
                }
            }
            Section("Noms de Maison") {
                LabeledContent("Dossier des noms") {
                    HStack {
                        Text(nomsMaison.dossier?.path(percentEncoded: false) ?? "—")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choisir…") { nomsMaison.choisir() }
                    }
                }
                if let n = nomsMaison.noms {
                    LabeledContent("Noms lus",
                                   value: String(localized: "\(n.accessoires.count) accessoires · \(n.date.formatted(date: .abbreviated, time: .shortened))"))
                    if DossierNoms.estAncien(n, maintenant: .now) {
                        Text("Noms du \(n.date.formatted(date: .abbreviated, time: .omitted)) : relance outils/passeur.sh pour les rafraîchir.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let p = nomsMaison.probleme {
                    Text(p).font(.caption).foregroundStyle(.red)
                }
                Button("Rafraîchir les noms de Maison") { nomsMaison.lancerPasseur() }
                    .disabled(surveillance.mode == .demo)
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
        // Etat de l'ouverture a la connexion relu a chaque ouverture (Reglages Systeme).
        .onAppear { ouverture.actualiser() }
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
        let donnees: Data
        do {
            guard let d = try surveillance.captureJSON() else { return }
            donnees = d
        } catch {
            messageCapture = error.localizedDescription
            return
        }
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
    @Environment(DossierNoms.self) private var nomsMaison
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
                if surveillance.mode == .direct {
                    Button("Rafraîchir les noms de Maison") { nomsMaison.lancerPasseur() }
                }
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
        // Etat de l'ouverture a la connexion relu a chaque ouverture du menu (Reglages Systeme).
        .onAppear { ouverture.actualiser() }
    }

    @ViewBuilder
    private var entete: some View {
        let alerte = surveillance.alerte
        HStack(spacing: 8) {
            if muet != nil {
                Image(systemName: "wifi.slash").foregroundStyle(.secondary)
            } else {
                Image(systemName: alerte ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(alerte ? .orange : .green)
            }
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

    /// Le Mac n'entend plus rien depuis cette date ; le resume montre le dernier etat connu.
    private var muet: Date? {
        surveillance.instantane == nil ? nil : surveillance.rienVuDepuis
    }

    private var titre: String {
        if surveillance.instantane == nil { return String(localized: "Écoute du réseau local…") }
        if let d = muet { return String(localized: "Rien de visible sur le réseau local depuis \(TexteEvenement.heure(d))") }
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

- [ ] **Step 2 : compiler, puis mettre les textes au catalogue.**

Run: `outils/tester.sh MaillageThreadTests/DossierNomsTests`, qui compile ; attendu `4 tests in 1 suite passed`.

Run: `outils/synchroniser-textes.sh`, puis :

```bash
python3 - <<'EOF'
import json
p = 'outils/traductions/interface.json'
d = json.load(open(p, encoding='utf-8'))
d.update({
    "Noms de Maison": "Home names",
    "Dossier des noms": "Names folder",
    "Choisir…": "Choose…",
    "Noms lus": "Names read",
    "%lld accessoires · %@": "%1$lld accessories · %2$@",
    "Noms du %@ : relance outils/passeur.sh pour les rafraîchir.": "Names from %@: run outils/passeur.sh again to refresh them.",
    "Rafraîchir les noms de Maison": "Refresh Home names",
})
open(p, 'w', encoding='utf-8').write(json.dumps(dict(sorted(d.items())), ensure_ascii=False, indent=2) + '\n')
EOF
```

Run: `python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/interface.json`

- [ ] **Step 3 : toute la suite.**

Run: `outils/tester.sh`
Expected: `86 tests in 13 suites passed` et `27 tests in 12 suites passed`, sans avertissement.

- [ ] **Step 4 : commit.**

```bash
git add MaillageThread/Vues/FenetreReglages.swift MaillageThread/Vues/MenuBarre.swift outils/traductions/interface.json MaillageThread/Ressources/Localizable.xcstrings
git commit -m "Choisir le dossier des noms et rafraichir les noms de Maison

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

### Task 5: Mode d'emploi et vérification avec Djoko (par le contrôleur, pas par un sous-agent)

**Files:**
- Modify: `README.md`, `README.fr.md` (nouvelle section, et remplacement de la phrase « Not in this step yet » / « Pas encore dans cette étape ») ; `docs/superpowers/specs/2026-09-28-maillage-thread-design.md` (section 5 : dossier conseillé, « Changer de dossier… », résultats du jour).

- [ ] **Step 1 : README.**

Dans `README.md`, remplacer le dernier paragraphe (« Not in this step yet: Home names read through a Mac Catalyst helper … ») par :

````markdown
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
````

Dans `README.fr.md`, remplacer le dernier paragraphe (« Pas encore dans cette étape : les noms de Maison, lus par un passeur Mac Catalyst … ») par :

````markdown
## Noms de Maison (Passeur Noms)

HomeKit n'existe pas en macOS natif, et une équipe de développement Apple
gratuite ne peut pas le donner à une app Mac Catalyst. Les noms de Maison
viennent donc de **Passeur Noms**, une petite app iOS lancée sur le Mac
(« conçue pour iPad ») : elle lit Maison (noms, pièces, fabricants,
`matterNodeID`), écrit `noms.json` dans un dossier choisi une fois, et se
ferme.

```sh
outils/passeur.sh          # compile avec ton équipe (compte Xcode), enveloppe, lance
```

- L'équipe vient de ton certificat « Apple Development » (`EQUIPE=` pour
  l'imposer). Une équipe gratuite a un profil de 7 jours : relancer le script
  pour rafraîchir les noms. Seul Passeur Noms est signé avec l'équipe ;
  Maillage Thread reste ad hoc.
- Au premier lancement de chaque compilation, macOS dit que l'app est
  « endommagée » : cliquer Annuler, puis Réglages Système › Confidentialité et
  sécurité › « Ouvrir quand même ». Autoriser ensuite l'accès à Maison.
- Choisir un dossier **hors iCloud et hors de ce dépôt** (par exemple
  `~/Maillage Thread`) ; « Changer de dossier… » reste proposé 10 s après
  l'écriture. `noms.json` est ignoré par git : ne jamais le commiter.
- Dans Maillage Thread : Réglages › Noms de Maison › Choisir… (le même
  dossier). Les noms sont relus quand Passeur Noms se ferme ; « Rafraîchir les
  noms de Maison » (menu ou réglages) le relance. Priorité : surnom > Maison >
  HomeKit (`_hap._udp`) > hôte.
````

- [ ] **Step 2 : vérification avec Djoko.**

1. Lancer `outils/passeur.sh`. Il installe dans `~/Applications` et lance.
2. Djoko autorise Gatekeeper, puis Maison si l'invite revient.
3. Si le passeur écrit encore dans l'ancien dossier de l'essai (la racine du dépôt), Djoko clique « Changer de dossier… » avant la fin du compte à rebours et choisit `~/Maillage Thread`, créé au besoin. Vérifier `git status` : `noms.json` ne doit pas apparaître.
4. Recompiler l'app (`outils/tester.sh`), la quitter et la relancer en français. Dans Réglages › Noms de Maison › Choisir…, Djoko choisit le même dossier. « Noms lus » doit montrer le nombre d'accessoires.
5. Dans le graphe, les appareils de la fabrique d'Apple portent leur nom de Maison, et la fiche leur pièce. Le nœud du Hue Bridge, un appareil IP, porte le nom du pont.
6. Quitter et relancer l'app : les noms restent, grâce à la mémoire.
7. « Rafraîchir les noms de Maison » relance le passeur, qui écrit puis se ferme, et l'app relit.

- [ ] **Step 3 : spec, section 5.** À la fin de la section 5 de `docs/superpowers/specs/2026-09-28-maillage-thread-design.md`, ajouter (en remplaçant `<…>` par les valeurs relevées au Step 2) :

```markdown
- **Dossier conseillé (révision du 28/09, après essai)** : hors iCloud et hors
  du dépôt, par exemple `~/Maillage Thread` (Documents est synchronisé par
  iCloud ; à l'essai, la racine du dépôt public avait été choisie) ; le
  passeur montre le dossier utilisé et « Changer de dossier… » pendant les
  10 s qui précèdent sa fermeture ; `noms.json` est ignoré par git.
- **Vérifié le <date> avec Djoko** : `outils/passeur.sh` (Gatekeeper
  autorisé), <n> accessoires écrits dans `<dossier>` ; dans l'app, <m> nœuds
  de la fabrique d'Apple nommés, pièce sur la fiche, nœud du Hue Bridge nommé
  d'après le pont ; noms gardés après relancement ; « Rafraîchir les noms de
  Maison » relance le passeur et l'app relit.
```

- [ ] **Step 4 : commit.**

```bash
git add README.md README.fr.md docs/superpowers/specs/2026-09-28-maillage-thread-design.md
git commit -m "Documenter le passeur des noms de Maison

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Couverture de la spec (section 5)

| Spec | Tâches |
|---|---|
| App iOS « Designed for iPad », `fr.djoko.maillage.passeur`, HomeKit, profil gratuit de 7 jours | 2 |
| `outils/passeur.sh` : compile avec `-allowProvisioningUpdates`, enveloppe comme Xcode, lance | 2 |
| Gatekeeper au premier lancement d'une compilation | 5 (mode d'emploi, vérification) |
| Relevé : nom, pièce, fabricant, modèle, catégorie, `matterNodeID`, domicile ; `noms.json` écrit d'un coup | 1 (contrat), 2 |
| Dossier choisi une fois (signet) ; le passeur se ferme | 2 |
| L'app lit après un choix unique (signet à portée de sécurité), relit quand il change, garde les derniers noms avec leur date ; message au-delà de 7 jours | 3, 4 |
| Correspondance : fabrique d'Apple trouvée seule ; `matterNodeID` à 0 ignoré ; nœud d'un pont : nom du pont, sinon premier par nom | 1 |
| Accès refusé : l'app le dit et continue ; rien ne sort du Mac | 2 (fichier « refusé »), 3 (noms gardés, problème affiché) |
| Pas d'App Group | 2, 3 (dossier choisi et signets) |

## Écarts d'exécution

Plan exécuté en sous-agents le 28/09/2026 (branche `plan2-noms`). Chaque tâche a été relue. La relecture finale a suivi, puis une vague de correction, relue à son tour. Enfin, une vérification en direct avec Djoko.

| Où | Écart | Commits |
|---|---|---|
| Tâches 1 à 4 | code identique au plan (transcrit, relu) | `8ba0087` à `5ad4056` |
| Relecture finale (I1) | dossier des noms résolu à chaque lecture, signet périmé renouvelé, dossier introuvable ou inaccessible signalé ; l'app est inerte en démo et sous tests | `58029b7` |
| Relecture finale (I2, M9) | `outils/passeur.sh` : `APP` doit être un `.app` et l'enveloppe existante la sienne ; produit vérifié avant l'effacement ; certificat valide ; arguments inconnus refusés | `9d35e68` |
| Relecture finale (M2 à M4) | passeur : renouvellement du signet sous accès, pas de supposition sur le fil de HomeKit, refus déjà acquis, maison vide et délai de 30 s traités | `c07150b` |
| Décision de Djoko | « endormi » = `ICD`, ou `SII` de plus de 2 s (secteur ≤ 2000 ms, pile ≥ 2800 ms sur ses relevés) | `0656fa2` |
| Décision de Djoko | version du firmware des accessoires dans la fiche (`AccessoireMaison.firmware`) | `0a166e9` |
| Relecture finale (M7, M8) | textes anglais « Passeur Noms » et guillemets typographiques, commentaires, pont choisi par nom | `7a4522f` |
| Tâche 5 | README, spec (sections 2, 5 et 6), suite spatiale 3D dans la spec de la sonde | `f9e5b17` |

**Vérifié en direct avec Djoko le 28/09 :**
- noms, pièces et firmware dans le graphe et la fiche ;
- dossier des noms toujours reconnu après une recompilation de l'app ;
- 🔋 sur les appareils sur pile ;
- « Rafraîchir les noms de Maison » ;
- noms gardés après relancement.

**Choix de Djoko :** le dossier des noms reste la racine du dépôt, où `noms.json` est ignoré par git.

**Constat du jour :**
- 4 accessoires n'annonçaient plus leur identité Apple. Un redémarrage des routeurs de bordure (Apple TV et HomePod) les a fait revenir sans réappairage.
- L'Aqara refonde toujours sa propre partition, en reprenant le préfixe OMR de la partition Apple.

À la fin : 88 tests (framework, 13 suites) et 32 tests (app, 13 suites).

