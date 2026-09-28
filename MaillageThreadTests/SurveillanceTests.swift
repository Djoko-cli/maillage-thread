import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Surveillance (modele de l'app)")
struct SurveillanceTests {
    static func demo() -> Surveillance {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        return s
    }

    @Test func modeDemo() throws {
        let s = Self.demo()
        #expect(s.etatEcoute == .demo)
        #expect(s.evenements.count == 10)
        guard case .pertes(let pertes) = s.lignesJournal.first else {
            Issue.record("les pertes regroupees en tete du journal")
            return
        }
        #expect(pertes.count == 5)
        let resume = try #require(s.resume)
        #expect(resume == ResumeReseau(nom: "MyHome1482620090", partitions: 2, routeurs: 6, appareils: 24, injoignables: 5))
        #expect(s.alerte, "reseau scinde")
        let r = try #require(s.reseau)
        let affiches = s.appareilsAffiches(pour: r)
        #expect(affiches.filter { $0.etat == .disparu }.map(\.nom).sorted()
                == ["Ampoule entrée", "Prise bureau", "Prise salon", "Thermo chambre"])
        #expect(affiches.first { $0.id == "46F77B36E071F8D0" }?.partition == "73586B68", "disparu a sa derniere place")
        #expect(affiches.first { $0.id == "56B1E064401F74EF" }?.piece == "Bureau")
        #expect(s.evenements(de: "46F77B36E071F8D0").first?.type == .appareilDisparu)
        #expect(s.derniereScission(r)?.date == ScenarioPanne.date(4, 14))
        #expect(s.appareil("46F77B36E071F8D0") != nil, "un disparu reste consultable")
        #expect(s.routesLisibles == true)
    }

    @Test func journalEtSurnomsSurDisque() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent("maillage-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dossier) }
        let s = Surveillance(mode: .direct, dossier: dossier)
        for a in ScenarioPanne.releves.prefix(12) { s.integrer(a) }
        #expect(s.evenements.map(\.type) == [.surveillanceDemarree, .routeurNouvelleAdresseLien, .prefixeNouveau,
                                             .prefixeRetire])
        let journal = JournalFichiers(dossier: dossier.appendingPathComponent("Journal"))
        #expect(try journal.lire().count == 4)

        s.renommer("56B1E064401F74EF", en: "  Pont du bureau ")
        let halo = try #require(s.appareil("56B1E064401F74EF"))
        #expect(s.nom(halo) == "Pont du bureau")
        let relu = Surveillance(mode: .direct, dossier: dossier)
        #expect(relu.noms.surnoms == ["56B1E064401F74EF": "Pont du bureau"])
        s.renommer("56B1E064401F74EF", en: "")
        #expect(s.nom(halo) == "56B1E064401F74EF")

        let capture = try #require(try s.captureJSON())
        let lue = try CodageJSON.decodeur().decode(Annonces.self, from: capture)
        #expect(lue.date == ScenarioPanne.releves[11].date)
    }

    @Test func veilleDuMac() {
        let s = Surveillance(mode: .direct, dossier: nil)
        s.integrer(ScenarioPanne.releves[0])
        s.noterVeille(debut: ScenarioPanne.date(3, 56), fin: ScenarioPanne.date(3, 55))
        #expect(s.evenements.last?.type == .veille)
        #expect(s.evenements.last?.periode?.duration == 0, "fin avant le debut : ramenee au debut")
    }
}
