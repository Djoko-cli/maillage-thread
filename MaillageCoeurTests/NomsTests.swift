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

    /// Plusieurs ponts sur un meme noeud : le premier par nom, quel que soit
    /// l'ordre du fichier.
    @Test func plusieursPonts() throws {
        let halo = try #require(instantane.appareil("56B1E064401F74EF"))
        let f = "30FC8F95E0E1A385"
        let noeud = try #require(halo.instances.first { $0.fabrique == f }?.noeud)
        let maison = NomsMaison(date: Date(timeIntervalSince1970: 1_790_000_000), accessoires: [
            AccessoireMaison(nom: "Pont B", noeudMatter: noeud, pont: true),
            AccessoireMaison(nom: "Lampe", noeudMatter: noeud),
            AccessoireMaison(nom: "Pont A", noeudMatter: noeud, pont: true),
        ])
        #expect(ResolveurNoms(maison: maison).nom(appareil: halo, fabriqueApple: f) == "Pont A")
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

    /// `firmware` est facultatif : un fichier ancien, sans ce champ, se lit ;
    /// un fichier qui l'a le garde.
    @Test func contratFirmware() throws {
        let ancien = #"{"accessoires":[{"nom":"Halo","noeudMatter":"00000000000002E9"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        #expect(try NomsMaison.lire(Data(ancien.utf8)).accessoires.first?.firmware == nil)
        let avec = #"{"accessoires":[{"firmware":"1.4.2","nom":"Halo","noeudMatter":"00000000000002E9"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        #expect(try NomsMaison.lire(Data(avec.utf8)).accessoires.first?.firmware == "1.4.2")
        let n = NomsMaison(date: Date(timeIntervalSince1970: 1_790_000_000),
                           accessoires: [AccessoireMaison(nom: "Halo", modele: "Halo", firmware: "1.4.2")])
        #expect(try NomsMaison.lire(try n.donnees()) == n)
    }

    /// `batterie` est facultatif : un fichier ancien, sans ce champ, se lit ;
    /// un fichier qui l'a le garde.
    @Test func contratBatterie() throws {
        let ancien = #"{"accessoires":[{"nom":"Halo"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        #expect(try NomsMaison.lire(Data(ancien.utf8)).accessoires.first?.batterie == nil)
        let avec = #"{"accessoires":[{"batterie":{"alerte":false,"charge":"enCharge","niveau":81},"nom":"Store"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        #expect(try NomsMaison.lire(Data(avec.utf8)).accessoires.first?.batterie
                == BatterieMaison(niveau: 81, charge: .enCharge, alerte: false))
        let n = NomsMaison(date: Date(timeIntervalSince1970: 1_790_000_000), accessoires: [
            AccessoireMaison(nom: "Serrure", batterie: BatterieMaison(niveau: 52, charge: .horsCharge, alerte: false)),
            AccessoireMaison(nom: "Interrupteur", batterie: BatterieMaison(alerte: true)),
        ])
        #expect(try NomsMaison.lire(try n.donnees()) == n)
    }

    /// Un etat de charge inconnu (passeur plus recent que l'app) ne rend pas le
    /// fichier illisible : seule la charge est perdue.
    @Test func chargeInconnue() throws {
        let json = #"{"accessoires":[{"batterie":{"charge":"sansFil","niveau":40},"nom":"Store"}],"date":"2026-09-28T12:00:00.000Z","statut":"ok","version":1}"#
        #expect(try NomsMaison.lire(Data(json.utf8)).accessoires.first?.batterie == BatterieMaison(niveau: 40))
    }

    /// Faible : l'accessoire le signale, ou son niveau est a 20 % ou moins.
    @Test func batterieFaible() {
        #expect(BatterieMaison(niveau: 20).faible)
        #expect(!BatterieMaison(niveau: 21).faible)
        #expect(BatterieMaison(niveau: 90, alerte: true).faible, "l'accessoire le signale")
        #expect(BatterieMaison(alerte: true).faible, "alerte sans niveau")
        #expect(!BatterieMaison(alerte: false).faible)
        #expect(!BatterieMaison().faible)
    }

    /// Valeurs de HomeKit (NSNumber) : niveau de 0 a 100 ; charge 0 (hors
    /// charge), 1 (en charge) ou 2 (non rechargeable) ; alerte 0 ou 1. Une
    /// valeur hors de ces bornes est ignoree ; rien de lisible : pas de batterie.
    @Test func batterieDepuisHomeKit() {
        #expect(BatterieMaison.depuisHomeKit(niveau: NSNumber(value: 99), charge: NSNumber(value: 0),
                                             alerte: NSNumber(value: 0))
                == BatterieMaison(niveau: 99, charge: .horsCharge, alerte: false))
        #expect(BatterieMaison.depuisHomeKit(niveau: nil, charge: NSNumber(value: 1), alerte: NSNumber(value: 1))
                == BatterieMaison(charge: .enCharge, alerte: true))
        #expect(BatterieMaison.depuisHomeKit(niveau: NSNumber(value: 100), charge: NSNumber(value: 2), alerte: nil)
                == BatterieMaison(niveau: 100, charge: .nonRechargeable))
        #expect(BatterieMaison.depuisHomeKit(niveau: NSNumber(value: 250), charge: NSNumber(value: 7),
                                             alerte: NSNumber(value: 1))
                == BatterieMaison(alerte: true), "hors bornes")
        #expect(BatterieMaison.depuisHomeKit(niveau: "99", charge: nil, alerte: nil) == nil, "pas un nombre")
        #expect(BatterieMaison.depuisHomeKit(niveau: nil, charge: nil, alerte: nil) == nil)
    }

    /// Le passeur consomme la demande apres son ecriture : il la retire dans
    /// tous les cas, et ne se ferme aussitot que si elle est recente.
    @Test func demandeConsommee() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("demande-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dossier) }
        let fichier = dossier.appendingPathComponent(DemandePasseur.fichier)
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(!DemandePasseur.consommer(dans: dossier, maintenant: t), "pas de demande : ouvert a la main")
        try DemandePasseur(date: t).donnees().write(to: fichier)
        #expect(DemandePasseur.consommer(dans: dossier, maintenant: t.addingTimeInterval(3)))
        #expect(!FileManager.default.fileExists(atPath: fichier.path))
        try DemandePasseur(date: t).donnees().write(to: fichier)
        #expect(!DemandePasseur.consommer(dans: dossier, maintenant: t.addingTimeInterval(600)), "un reste")
        #expect(!FileManager.default.fileExists(atPath: fichier.path))
        try Data("pas du json".utf8).write(to: fichier)
        #expect(!DemandePasseur.consommer(dans: dossier, maintenant: t))
        #expect(!FileManager.default.fileExists(atPath: fichier.path))
    }

    /// Demande de l'app au passeur : relue telle quelle, recente 2 min seulement.
    @Test func demandePasseur() throws {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let d = DemandePasseur(date: t)
        #expect(try DemandePasseur.lire(try d.donnees()) == d)
        #expect(d.estRecente(t.addingTimeInterval(119)))
        #expect(!d.estRecente(t.addingTimeInterval(121)), "reste d'un passeur qui ne s'est pas lance")
        #expect(DemandePasseur.fichier == "passeur-demande.json")
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
