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
        #expect(resume == ResumeReseau(nom: "MyHome1520326503", partitions: 2, routeurs: 6, appareils: 24, injoignables: 5))
        #expect(s.alerte, "reseau scinde")
        let r = try #require(s.reseau)
        let affiches = s.appareilsAffiches(pour: r)
        #expect(affiches.filter { $0.etat == .disparu }.map(\.nom).sorted()
                == ["Ampoule entrée", "Prise bureau", "Prise salon", "Thermo chambre"])
        #expect(affiches.first { $0.id == "46D9C54DAA6079AC" }?.partition == "7C6A2A68", "disparu a sa derniere place")
        #expect(affiches.first { $0.id == "561F9A6463953778" }?.piece == "Bureau")
        #expect(affiches.first { $0.id == "86E8EDA04DCFDE3F" }?.batterie
                == BatterieMaison(niveau: 52, charge: .horsCharge, alerte: false), "batterie de Maison")
        #expect(affiches.filter { $0.batterie?.faible == true }.map(\.nom).sorted() == ["Eve Motion", "Fenêtre chambre"])
        #expect(s.evenements(de: "46D9C54DAA6079AC").first?.type == .appareilDisparu)
        #expect(s.derniereScission(r)?.date == ScenarioPanne.date(4, 14))
        #expect(s.appareil("46D9C54DAA6079AC") != nil, "un disparu reste consultable")
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

        s.renommer("561F9A6463953778", en: "  Pont du bureau ")
        let halo = try #require(s.appareil("561F9A6463953778"))
        #expect(s.nom(halo) == "Pont du bureau")
        let relu = Surveillance(mode: .direct, dossier: dossier)
        #expect(relu.noms.surnoms == ["561F9A6463953778": "Pont du bureau"])
        s.renommer("561F9A6463953778", en: "")
        #expect(s.nom(halo) == "561F9A6463953778")

        let capture = try #require(try s.captureJSON())
        let lue = try CodageJSON.decodeur().decode(Annonces.self, from: capture)
        #expect(lue.date == ScenarioPanne.releves[11].date)
    }

    /// Deux reseaux Thread : un appareil devenu sans adresse ne va qu'au reseau
    /// de sa derniere partition, pas aussi au premier.
    @Test func deuxReseaux() throws {
        let debut = Releve20260928.annonces.date
        func annonces(_ t: TimeInterval, adresse: Bool) -> Annonces {
            var a = Releve20260928.annonces
            a.date = debut.addingTimeInterval(t)
            // Second reseau : un chef (autre xp, partition BBBBBBBB) qui publie son prefixe OMR.
            a.routeurs.append(AnnonceService(instance: "Voisin", hote: "Voisin.local", port: 49153, txt: ChampsTXT([
                "nn": Data("Voisin".utf8), "xp": Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]),
                "tv": Data("1.4.0".utf8), "pt": Data([0xBB, 0xBB, 0xBB, 0xBB]), "sb": Data([0, 0, 0x07, 0xB1]),
                "omr": Data([0x40, 0xFD, 0x99, 0, 0, 0, 0, 0, 0x01]),
            ])))
            a.adresses["Voisin.local"] = ["fe80::99"]
            a.matter.append(AnnonceService(instance: "309BEA1CCA0C1569-00000000000000BB", hote: "BBBB000000000001.local"))
            a.adresses["BBBB000000000001.local"] = adresse ? ["fd99:0:0:1::5"] : []
            return a
        }
        let s = Surveillance(mode: .direct, dossier: nil)
        s.integrer(annonces(0, adresse: true))
        s.integrer(annonces(60, adresse: false))
        s.integrer(annonces(180, adresse: false))
        let i = try #require(s.instantane)
        #expect(i.reseaux.map(\.nom) == ["MyHome1520326503", "Voisin"])
        #expect(i.appareil("BBBB000000000001")?.etat == .sansAdresse)
        let maison = try #require(i.reseaux.first)
        let voisin = try #require(i.reseaux.last)
        #expect(!s.appareilsAffiches(pour: maison).contains { $0.id == "BBBB000000000001" }, "pas dans le premier reseau")
        #expect(s.appareilsAffiches(pour: voisin).map(\.id) == ["BBBB000000000001"])
        #expect(s.appareilsAffiches(pour: voisin).first?.partition == "BBBBBBBB")
        #expect(s.resume?.appareils == 24, "le premier reseau ne compte pas l'appareil du voisin")
    }

    @Test func veilleDuMac() {
        let s = Surveillance(mode: .direct, dossier: nil)
        s.integrer(ScenarioPanne.releves[0])
        s.noterVeille(debut: ScenarioPanne.date(3, 56), fin: ScenarioPanne.date(3, 55))
        #expect(s.evenements.last?.type == .veille)
        #expect(s.evenements.last?.periode?.duration == 0, "fin avant le debut : ramenee au debut")
    }

    /// Le Mac n'entend plus rien : aucun evenement, l'instantane reste, et la
    /// date du premier releve vide est gardee jusqu'au prochain releve non vide.
    @Test func reseauLocalMuet() throws {
        let s = Surveillance(mode: .direct, dossier: nil)
        s.integrer(Annonces(date: ScenarioPanne.debut))
        #expect(s.rienVuDepuis == nil, "pas encore d'instantane")
        s.integrer(ScenarioPanne.releves[0])
        let evenements = s.evenements
        let date = try #require(s.instantane?.date)
        let muet = ScenarioPanne.releves[0].date.addingTimeInterval(300)
        s.integrer(Annonces(date: muet))
        #expect(s.evenements == evenements, "aucun evenement")
        #expect(s.rienVuDepuis == muet)
        #expect(s.instantane?.date == date)
        #expect(s.dernierReleve?.date == muet, "le dernier releve recu, pour le diagnostic")
        s.integrer(Annonces(date: muet.addingTimeInterval(60)))
        #expect(s.rienVuDepuis == muet, "date du premier releve vide")
        var retour = ScenarioPanne.releves[0]
        retour.date = muet.addingTimeInterval(120)
        s.integrer(retour)
        #expect(s.rienVuDepuis == nil)
    }

    /// Scissions deja notifiees, gardees d'un lancement a l'autre (mode direct, lues
    /// au demarrage) : la scission trouvee de nouveau au lancement suivant n'est pas
    /// notifiee, mais reste au journal ; une reunion l'oublie. La demo n'ecrit rien,
    /// ni une surveillance pas demarree. Preferences jetables, jamais celles de l'app.
    @Test func scissionsNotifieesGardees() throws {
        // Domaine jetable, vide avant et apres ; toujours le meme : le systeme garde
        // son fichier (vide) dans le conteneur de l'app, un seul donc. L'ecriture est
        // attendue : l'app de test s'arrete aussitot apres.
        let domaine = "maillage-tests-scissions"
        let preferences = try #require(UserDefaults(suiteName: domaine))
        preferences.removePersistentDomain(forName: domaine)
        defer {
            preferences.removePersistentDomain(forName: domaine)
            preferences.synchronize()
        }
        let cle = Surveillance.cleScissionsNotifiees
        let scinde = Releve20260928.annonces  // l'Aqara seul dans E6A6AD72
        var envoyees: [CategorieAlerte] = []
        /// Un lancement : les scissions notifiees sont lues comme au demarrage, sans ecouter le reseau.
        func lancement() -> Surveillance {
            let s = Surveillance(mode: .direct, dossier: nil, preferences: preferences)
            s.surAlertes = { envoyees += $0.map(\.categorie) }
            s.chargerScissionsNotifiees()
            return s
        }

        Surveillance(mode: .demo, dossier: nil, preferences: preferences).demarrer()
        #expect(preferences.object(forKey: cle) == nil, "la demo (une scission a 04:14) n'ecrit rien")

        lancement().integrer(scinde)
        #expect(envoyees == [.scission], "premier lancement : constatee et notifiee")
        #expect(preferences.stringArray(forKey: cle) == ["4B5D376D942B480E|7C6A2A68,E6A6AD72"])

        envoyees = []
        let second = lancement()
        second.integrer(scinde)
        #expect(envoyees.isEmpty, "toujours scinde au lancement suivant : pas de seconde notification")
        #expect(second.evenements.contains { $0.type == .reseauScinde && $0.constate }, "le journal la note toujours")

        // L'Aqara rejoint la partition Apple : reunion, la signature est oubliee.
        var reuni = scinde
        reuni.date = scinde.date.addingTimeInterval(60)
        let aqara = try #require(reuni.routeurs.firstIndex { $0.instance == "Aqara HubM100 #80E0" })
        var txt = reuni.routeurs[aqara].txt.valeurs
        txt["pt"] = Data([0x7C, 0x6A, 0x2A, 0x68])
        reuni.routeurs[aqara].txt = ChampsTXT(txt)
        second.integrer(reuni)
        #expect(second.evenements.last?.type == .reseauReuni)
        #expect(preferences.stringArray(forKey: cle) == [])

        Surveillance(mode: .direct, dossier: nil, preferences: preferences).integrer(scinde)
        #expect(preferences.stringArray(forKey: cle) == [], "pas demarree (comme les autres tests) : rien n'est ecrit")
    }
}
