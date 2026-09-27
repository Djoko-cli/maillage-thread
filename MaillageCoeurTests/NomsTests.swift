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
