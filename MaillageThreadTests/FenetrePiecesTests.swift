import AppKit
import Foundation
import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : la fenetre")
struct FenetrePiecesTests {
    /// Ce qui est entre les chevrons de la premiere `nom<…>` d'un type imprime, chevrons imbriques
    /// compris ; nil sans `nom<` ni chevron fermant.
    static func entreChevrons(_ nom: String, dans type: String) -> Substring? {
        guard let ouverture = type.range(of: nom + "<") else { return nil }
        var profondeur = 1
        var i = ouverture.upperBound
        while i < type.endIndex {
            switch type[i] {
            case "<": profondeur += 1
            case ">":
                profondeur -= 1
                if profondeur == 0 { return type[ouverture.upperBound..<i] }
            default: break
            }
            i = type.index(after: i)
        }
        return nil
    }

    /// « Ancien » (6 min) et « perime » (15 min) ne dependent que de l'heure, que rien n'observe : la
    /// fenetre est une `TimelineView` qui se redessine chaque minute (`FenetrePieces.horloge`), avec
    /// dedans tout ce qui lit l'heure (la legende, la scene, la fiche).
    @Test func redessinChaqueMinute() throws {
        let horloge = String(reflecting: type(of: FenetrePieces.horloge))
        let corps = String(reflecting: FenetrePieces.Body.self)
        let dedans = try #require(Self.entreChevrons("TimelineView", dans: corps), "le corps est une TimelineView")
        #expect(dedans.hasPrefix(horloge), "sur l'horloge")
        for vue in ["LegendeLiens", "VuePieces", "FicheNoeud"] {
            #expect(dedans.contains(vue), "\(vue) est dans la TimelineView, pas a cote")
        }
        let recu = Date(timeIntervalSince1970: 1_790_000_000)
        let redessins = FenetrePieces.horloge.entries(from: recu, mode: .normal).prefix(20).filter { $0 >= recu }
        #expect(zip(redessins, redessins.dropFirst()).allSatisfy { $1.timeIntervalSince($0) <= 60 })
    }

    /// Le haut de la fenetre (barre, bandeaux, tournee, fil) tient dans la marge du haut de la vue
    /// d'ensemble, dans tous les cas ; la fiche la plus haute de la demo, avec la ligne de niveau,
    /// dans la marge du bas ; avec les courbes de l'historique, dans la marge du bas avec courbes.
    @Test(.timeLimit(.minutes(1))) func marges() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        let sonde = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in SondeMaillageTests.canalRetenu(journal) })
        let noms = NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit)
        let demo = Surveillance(mode: .demo, dossier: nil)
        demo.demarrer()
        let sansReseau = Surveillance(mode: .direct, dossier: nil)
        func haut(_ s: Surveillance, sansPieces: Bool) -> CGFloat {
            let m = MoteurPieces()
            let vue = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                EnTetePieces(moteur: m, troisD: .constant(true), sansPieces: sansPieces)
                FilPieces(moteur: m)
            }
            return FenetrePieces.bord + NSHostingView(rootView: vue.environment(s).environment(sonde).environment(noms))
                .fittingSize.height
        }
        #expect(demo.reseau?.estScinde == true, "la demo : reseau scinde, bandeau affiche")
        for (s, scinde) in [(sansReseau, false), (demo, true)] {
            #expect(haut(s, sansPieces: false) <= FenetrePieces.margeHaut(scinde: scinde, sondeRetenue: false, sansPieces: false))
        }
        await sonde.connecter(SondeMaillageTests.port, choisi: true)
        await journal.attendre(SondeMaillageTests.listeRetenue)
        await SondeMaillageTests.attendre { sonde.avancement != nil }
        for (s, scinde) in [(sansReseau, false), (demo, true)] {
            #expect(haut(s, sansPieces: false) <= FenetrePieces.margeHaut(scinde: scinde, sondeRetenue: true, sansPieces: false))
        }
        #expect(haut(demo, sansPieces: true) <= FenetrePieces.margeHaut(scinde: true, sondeRetenue: true, sansPieces: true))
        await sonde.oublier()
        var fiche: CGFloat = 0
        let sansRouteurs = Surveillance(mode: .demo, dossier: nil)
        sansRouteurs.demarrer()
        sansRouteurs.noms.maison = NomsSceneTests.maisonSansRouteurs(sansRouteurs)
        #expect(PiecesChoisies.pieces(aPlacer: "Apple TV 4K", dans: sansRouteurs) != nil, "avec « Placer dans une pièce… »")
        for (s, id) in [(demo, "Apple TV 4K"), (demo, "3A5DFAFCAB581AAF"), (demo, "rloc:041F"), (demo, "7AF0B6D5006CF95F"),
                        (sansRouteurs, "Apple TV 4K")] {
            let v = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
                LigneNiveauVue(ligne: .lisibles)
                FicheNoeud(id: id, instant: Date(), aRenommer: .constant(nil)) {}
            }
            let hote = NSHostingView(rootView: v.environment(s).environment(PiecesChoisies(fichier: nil)))
            fiche = max(fiche, hote.fittingSize.height + FenetrePieces.bord)
        }
        #expect(fiche <= FenetrePieces.margeBas(fiche: true, courbes: false), "\(fiche)")
        let historique = try CourbesFicheTests.surveillance()
        #expect(FicheNoeud.courbesVisibles(dans: historique))
        let courbes = VStack(alignment: .leading, spacing: FenetrePieces.espacement) {
            LigneNiveauVue(ligne: .lisibles)
            FicheNoeud(id: JournalMaillageTests.appareil, instant: Date(), aRenommer: .constant(nil)) {}
        }
        let avecCourbes = NSHostingView(rootView: courbes.environment(historique)).fittingSize.height + FenetrePieces.bord
        #expect(avecCourbes <= FenetrePieces.margeBas(fiche: true, courbes: true), "\(avecCourbes)")
    }

    /// Ligne de niveau : pieces seules, routeurs, noms masques (un, plusieurs), piece isolee.
    @Test func ligneDeNiveau() {
        #expect(LigneNiveauVue.texte(.pieces) == String(localized: "Vue d'ensemble : les pièces"))
        #expect(LigneNiveauVue.texte(.routeurs) == String(localized: "Mi-distance : les pièces et les routeurs"))
        #expect(LigneNiveauVue.texte(.masques(1)) == String(localized: "1 nom masqué faute de place : rapprochez-vous (molette)"))
        #expect(LigneNiveauVue.texte(.masques(3))
                == String(localized: "\(3) noms masqués faute de place : rapprochez-vous (molette)"))
        #expect(LigneNiveauVue.texte(.isolee("Salon")).contains("Salon"))
        #expect(LigneNiveauVue.texte(.lisibles) == String(localized: "Tous les noms sont lisibles"))
    }

    /// La fenetre reste sombre, meme quand le Mac est en clair : sa barre, ses menus, sa fiche et ses
    /// feuilles en apparence sombre.
    @Test func fenetreToujoursSombre() {
        let fenetre = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled],
                               backing: .buffered, defer: true)
        fenetre.isReleasedWhenClosed = false
        fenetre.appearance = NSAppearance(named: .aqua)
        FenetrePieces.assombrir(fenetre)
        #expect(fenetre.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        FenetrePieces.assombrir(nil)
    }

    /// « Placer dans une piece… » : pour un routeur de bordure que Maison ne place pas seulement, les
    /// pieces de la maison, par nom ; le choix se garde sur disque, ou en memoire sans fichier (demo).
    @Test func placerUnRouteur() throws {
        let (s, _, _) = try NomsSceneTests.demo()
        #expect(PiecesChoisies.pieces(aPlacer: "HomePod Palier", dans: s) == nil, "Maison le place au salon")
        s.noms.maison = NomsSceneTests.maisonSansRouteurs(s)
        let pieces = try #require(PiecesChoisies.pieces(aPlacer: "HomePod Palier", dans: s))
        #expect(pieces == ["Buanderie", "Bureau", "Chambre", "Chambre d'amis", "Cuisine", "Entrée", "Salle de bain", "Salon"])
        #expect(PiecesChoisies.pieces(aPlacer: "56B1E064401F74EF", dans: s) == nil, "un appareil")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("routeurs-\(UUID().uuidString)/pieces-routeurs.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let choisies = PiecesChoisies(fichier: url)
        choisies.choisir("Salon", routeur: "HomePod Palier", domicile: "Maison (démo)")
        #expect(PiecesChoisies(fichier: url).choix.choix(routeur: "HomePod Palier", domicile: "Maison (démo)") == "Salon")
        let memoire = PiecesChoisies(fichier: nil)
        memoire.choisir("Salon", routeur: "HomePod Palier", domicile: "")
        #expect(memoire.choix.choix(routeur: "HomePod Palier", domicile: "") == "Salon")
        #expect(PiecesChoisies.fichier(demo: true, sousTests: false) == nil)
        #expect(PiecesChoisies.fichier(demo: false, sousTests: true) == nil)
        #expect(PiecesChoisies.fichier(demo: false, sousTests: false)
                == Surveillance.dossierParDefaut.appendingPathComponent("pieces-routeurs.json"))
    }

    /// Places des pieces : a cote des identites des routeurs, ni en demo ni sous les tests.
    @Test func fichierDesPlaces() {
        #expect(FenetrePieces.fichierPlaces(demo: true, sousTests: false) == nil)
        #expect(FenetrePieces.fichierPlaces(demo: false, sousTests: true) == nil)
        #expect(FenetrePieces.fichierPlaces(demo: false, sousTests: false)?.lastPathComponent == "positions-pieces.json")
        #expect(FenetrePieces.fichierPlaces(demo: false, sousTests: false)?.deletingLastPathComponent()
                == Surveillance.dossierParDefaut)
    }
}
