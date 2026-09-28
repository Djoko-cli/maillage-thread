import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Noms : surnoms, Maison, HomeKit, hote")
struct NomsTests {
    let instantane = Instantane(annonces: Releve20260928.annonces)

    @Test func fabriqueDApple() {
        let n = ResolveurNoms(maison: NomsDemo.maison)
        #expect(NomsDemo.maison.accessoires.count == 24)
        #expect(n.fabriqueApple(appareils: instantane.appareils + instantane.appareilsIP) == "309BEA1CCA0C1569")
        #expect(ResolveurNoms().fabriqueApple(appareils: instantane.appareils) == nil, "sans Maison")
    }

    @Test func noeudMatter() {
        #expect(AccessoireMaison.noeud(nil) == nil)
        #expect(AccessoireMaison.noeud(0) == nil, "accessoire non Matter")
        #expect(AccessoireMaison.noeud(0x4F55E160) == "000000004F55E160")
        #expect(AccessoireMaison.noeud(0xFEDCBA9876543210) == "FEDCBA9876543210")
    }

    /// Un pont porte plusieurs accessoires sur un seul noeud : le noeud prend
    /// le nom du pont, sinon du premier par nom.
    @Test func pont() throws {
        let halo = try #require(instantane.appareil("561F9A6463953778"))
        let f = "309BEA1CCA0C1569"
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
        let halo = try #require(instantane.appareil("561F9A6463953778"))
        let f = "309BEA1CCA0C1569"
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
        b.appareil("AAAA000000000001", noeud: 0, adresses: ["fd2d:3b27:72b8::11"])
        let a = try #require(Instantane(annonces: b.annonces).appareil("AAAA000000000001"))
        let n = ResolveurNoms(maison: NomsMaison(date: Date(timeIntervalSince1970: 1_790_000_000), accessoires: [
            AccessoireMaison(nom: "Camera IP", noeudMatter: "0000000000000000"),
        ]))
        #expect(n.fabriqueApple(appareils: [a]) == nil)
        #expect(n.accessoire(de: a, fabriqueApple: "309BEA1CCA0C1569") == nil)
        #expect(n.nom(appareil: a, fabriqueApple: "309BEA1CCA0C1569") == "AAAA000000000001")
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

    @Test func priorite() throws {
        let halo = try #require(instantane.appareil("561F9A6463953778"))
        let f = "309BEA1CCA0C1569"
        #expect(ResolveurNoms().nom(appareil: halo, fabriqueApple: f) == "561F9A6463953778", "l'hote a defaut")
        let maison = ResolveurNoms(maison: NomsDemo.maison)
        #expect(maison.nom(appareil: halo, fabriqueApple: f) == "Halo")
        #expect(maison.accessoire(de: halo, fabriqueApple: f)?.piece == "Bureau")
        #expect(maison.nom(appareil: halo, fabriqueApple: "20A842B5C3C38A0D") == "561F9A6463953778",
                "autre fabrique : autres numeros de noeud")
        let surnom = ResolveurNoms(surnoms: ["561F9A6463953778": "Pont du bureau"], maison: NomsDemo.maison)
        #expect(surnom.nom(appareil: halo, fabriqueApple: f) == "Pont du bureau")
        #expect(ResolveurNoms(surnoms: ["561F9A6463953778": ""]).nom(appareil: halo, fabriqueApple: nil)
                == "561F9A6463953778", "surnom vide ignore")

        var b = Banc()
        b.hap.append(AnnonceService(instance: "Eve Door 4A3B", hote: "Eve-Door-4A3B.local"))
        b.adresses["Eve-Door-4A3B.local"] = ["fd2d:3b27:72b8::44"]
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
        try Surnoms.ecrire(["561F9A6463953778": "Halo"], dans: url)
        #expect(Surnoms.lire(url) == ["561F9A6463953778": "Halo"])
        try Data("pas du json".utf8).write(to: url)
        #expect(Surnoms.lire(url) == [:], "illisible")
    }
}
