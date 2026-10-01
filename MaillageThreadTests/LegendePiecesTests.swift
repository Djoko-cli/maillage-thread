import AppKit
import Foundation
import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : la legende")
struct LegendePiecesTests {
    typealias Entree = LegendePieces.Entree
    typealias Lecture = LegendePieces.Lecture

    static func radio(_ qualite: Int?) -> ScenePieces.Lien {
        ScenePieces.Lien(de: "rloc:0400", vers: "rloc:5000", genre: .radio, qualite: qualite)
    }

    /// Une scene inventee par signe : chacune ne contient que lui, et la legende n'a que son entree. Un
    /// noeud que la sonde seule connait, routeur ou enfant, est « non identifie » ; un appareil d'etat
    /// inconnu, gris lui aussi, n'a pas d'entree.
    @Test func uneEntreeParSigne() {
        let cas: [(Lecture, Set<Entree>)] = [
            (Lecture(couleurs: ["Apple TV 4K": .routeur(principale: true)]), [.routeur]),
            (Lecture(couleurs: ["rloc:5000": .routeurInconnu], inconnus: ["rloc:5000"]), [.nonIdentifie]),
            (Lecture(couleurs: ["rloc:041F": .appareil(.inconnu)], inconnus: ["rloc:041F"]), [.nonIdentifie]),
            (Lecture(couleurs: ["Aqara": .routeur(principale: false)]), [.autrePartition]),
            (Lecture(chefs: ["Apple TV 4K"]), [.chef]),
            (Lecture(couleurs: ["E000000000000001": .appareil(.joignable)]), [.joignable]),
            (Lecture(couleurs: ["E000000000000002": .appareil(.partitionCoupee)]), [.partitionCoupee]),
            (Lecture(couleurs: ["E000000000000003": .appareil(.sansAdresse)]), [.sansAdresse]),
            (Lecture(couleurs: ["E000000000000004": .appareil(.disparu)]), [.disparu]),
            (Lecture(endormis: ["E000000000000005"]), [.endormi]),
            (Lecture(piles: ["E000000000000006"]), [.pile]),
            (Lecture(liens: [Self.radio(3)]), [.bonne]),
            (Lecture(liens: [Self.radio(2)]), [.moyenne]),
            (Lecture(liens: [Self.radio(1)]), [.faible]),
            (Lecture(liens: [Self.radio(nil)]), [.inconnue]),
            (Lecture(liens: [Self.radio(0)]), [.inconnue]),
            (Lecture(liens: [ScenePieces.Lien(de: "E000000000000001", vers: "rloc:5000", genre: .parent, qualite: 3)]),
             [.versParent]),
            (Lecture(liens: [ScenePieces.Lien(de: "E000000000000001", vers: "Apple TV 4K")]), [.rattachement]),
            (Lecture(ailleurs: true), [.ailleurs]),
            (Lecture(candidats: ["rloc:0400"]), [.candidats]),
            (Lecture(couleurs: ["E000000000000007": .appareil(.inconnu)]), []),
            (Lecture(), []),
        ]
        for (lecture, attendu) in cas {
            #expect(LegendePieces.entrees(lecture) == attendu, "\(attendu)")
        }
    }

    /// Les groupes dans l'ordre de la grille (routeurs, appareils, liens radio, autres), leurs entrees
    /// dans l'ordre de la spec ; un groupe sans entree disparait, et une scene vide n'a pas de legende.
    @Test func groupesEtOrdre() {
        let tout = Lecture(couleurs: ["a": .routeur(principale: true), "b": .routeur(principale: false),
                                      "c": .appareil(.joignable), "d": .appareil(.partitionCoupee),
                                      "e": .appareil(.sansAdresse), "f": .appareil(.disparu)],
                           inconnus: ["g"], chefs: ["a"], endormis: ["c"], piles: ["c"], candidats: ["g"],
                           liens: [Self.radio(3), Self.radio(2), Self.radio(1), Self.radio(nil),
                                   ScenePieces.Lien(de: "c", vers: "a", genre: .parent),
                                   ScenePieces.Lien(de: "d", vers: "a")],
                           ailleurs: true)
        #expect(LegendePieces.rubriques(tout) == LegendePieces.Groupe.allCases.map {
            LegendePieces.Rubrique(groupe: $0, entrees: $0.entrees)
        })
        #expect(Set(LegendePieces.Groupe.allCases.flatMap(\.entrees)) == Set(Entree.allCases), "chaque entree a son groupe")
        let sansLiens = Lecture(couleurs: ["c": .appareil(.joignable)], chefs: ["a"], ailleurs: true)
        #expect(LegendePieces.rubriques(sansLiens) == [
            LegendePieces.Rubrique(groupe: .routeurs, entrees: [.chef]),
            LegendePieces.Rubrique(groupe: .appareils, entrees: [.joignable]),
            LegendePieces.Rubrique(groupe: .autres, entrees: [.ailleurs]),
        ])
        #expect(LegendePieces.rubriques(Lecture()).isEmpty)
    }

    /// La scene de la demo, lue telle que la fenetre la dessine : avec la sonde, puis sans (plus de liens
    /// radio : le groupe disparait) ; une piece isolee qui pose des reperes « ailleurs ».
    @Test func legendeDeLaDemo() throws {
        let (s, _, e) = try NomsSceneTests.demo()
        let avec = LegendePieces.entrees(Lecture(e, ailleurs: false))
        #expect(avec == [.routeur, .nonIdentifie, .autrePartition, .chef, .joignable, .sansAdresse, .disparu, .endormi,
                         .pile, .bonne, .moyenne, .faible, .versParent, .rattachement])
        #expect(LegendePieces.entrees(Lecture(e, ailleurs: true)).contains(.ailleurs))
        s.oublierMaillage()
        let sans = try #require(FenetrePiecesTests.entree(s))
        #expect(sans.maillage == nil)
        let rubriques = LegendePieces.rubriques(Lecture(sans, ailleurs: false))
        #expect(rubriques.map(\.groupe) == [.routeurs, .appareils, .autres])
        #expect(rubriques.last?.entrees == [.rattachement])
    }

    /// Les signes de la legende reprennent ceux de la scene : la pastille d'une pile (« 12 % »), un
    /// routeur et ses deux candidats (« A ou B · 0400 »).
    @Test func exemples() {
        #expect(LegendePieces.exemplePile == String(localized: "\(12)\u{202F}%"))
        #expect(LegendePieces.exempleCandidats
                == String(localized: "\(["A", "B"].formatted(.list(type: .or))) · \("0400")"))
        #expect(LegendePieces.exempleAilleurs == String(localized: "→ Salon"))
    }

    /// Deux colonnes de meme largeur : la moitie d'un panneau de 440 pt, ou celle du groupe le plus large.
    @Test func colonnes() {
        #expect(GrilleLegende.largeurColonne([120, 150]) == 199)
        #expect(GrilleLegende.largeurColonne([251, 120]) == 251)
        #expect(GrilleLegende.largeurColonne([]) == 199)
    }

    /// Le repli est garde dans les preferences (`legendeRepliee`), par la ligne du bas : repliee, il ne
    /// reste que l'etiquette ; un etat impose (captures) passe avant, sans ecrire la preference.
    @Test func repliGarde() throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let (_, _, e) = try NomsSceneTests.demo()
        #expect(LegendePieces.cleRepliee == "legendeRepliee")
        func taille(_ v: LigneDuBas) -> CGSize {
            NSHostingView(rootView: v.defaultAppStorage(p)).fittingSize
        }
        let ouverte = taille(LigneDuBas(moteur: MoteurPieces(), entree: e))
        p.set(true, forKey: LegendePieces.cleRepliee)
        let repliee = taille(LigneDuBas(moteur: MoteurPieces(), entree: e))
        #expect(repliee.height < 40 && ouverte.height > 4 * repliee.height, "\(repliee) \(ouverte)")
        #expect(taille(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false)) == ouverte)
        p.set(false, forKey: LegendePieces.cleRepliee)
        #expect(taille(LigneDuBas(moteur: MoteurPieces(), entree: e)) == ouverte)
        #expect(taille(LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: true)) == repliee)
        #expect(p.bool(forKey: LegendePieces.cleRepliee) == false, "l'etat impose n'ecrit rien")
        let tout = LegendePieces.Groupe.allCases.map { LegendePieces.Rubrique(groupe: $0, entrees: $0.entrees) }
        func legende(_ r: [LegendePieces.Rubrique]) -> CGSize {
            NSHostingView(rootView: LegendePieces(rubriques: r, repliee: .constant(false))).fittingSize
        }
        #expect(legende(tout).width >= GrilleLegende.largeurPanneau)
        #expect(legende([]) == .zero, "sans entree, pas de legende")
    }

    /// La marge du bas suit la legende ouverte (decision de Djoko du 01/10) : la hauteur mesuree de la
    /// ligne du bas (la legende et la ligne de niveau), le bord et l'espacement ; repliee, la marge d'avant,
    /// 30 pt ; une fiche ouverte, qui cache la legende, garde ses 190 ou 360 pt.
    @Test func margeDuBas() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let h = NSHostingView(rootView: LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false))
            .fittingSize.height
        #expect(h > 150, "la legende de la demo, ouverte : \(h)")
        #expect(FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: h)
                == FenetrePieces.bord + ceil(h) + FenetrePieces.espacement)
        #expect(FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: nil) == 30, "repliee")
        #expect(FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: 2) == 30)
        #expect(FenetrePieces.margeBas(fiche: true, courbes: false, legendeOuverte: h) == 190)
        #expect(FenetrePieces.margeBas(fiche: true, courbes: true, legendeOuverte: h) == 360)
    }

    /// La vue d'ensemble se cadre au-dessus de la legende ouverte : dans une fenetre de 1440 x 900, aucun
    /// bloc, aucune pastille ni aucun nom de piece de la demo ne descend sous son bord du haut, en 2D
    /// comme en 3D.
    @Test(arguments: [false, true]) func vueAuDessusDeLaLegende(_ troisD: Bool) throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let h = NSHostingView(rootView: LigneDuBas(moteur: MoteurPieces(), entree: e, legendeForcee: false))
            .fittingSize.height
        let taille = CGSize(width: 1440, height: 900)
        let m = MoteurPieces(troisD: troisD)
        m.fige = true
        m.marges = (FenetrePieces.margeHaut(bas: 90), FenetrePieces.margeBas(fiche: false, courbes: false, legendeOuverte: h))
        m.poserTaille(taille)
        m.installerMaintenant(e)
        m.poserTaille(taille)
        MoteurPiecesTests.dessiner(m, taille: taille)
        let haut = taille.height - FenetrePieces.bord - h
        let p = try #require(m.projetee)
        #expect(!p.blocs.isEmpty && !p.disques.isEmpty)
        #expect(p.blocs.allSatisfy { b in b.faces.allSatisfy { f in f.points.allSatisfy { $0.y <= haut } } })
        #expect(p.disques.allSatisfy { $0.centre.y + $0.rayon <= haut })
        #expect(p.ancresPieces.values.allSatisfy { $0.maxY <= haut })
    }

    /// « Releve de la sonde ancien » n'est plus dans la legende : c'est une pastille a cote de la ligne de
    /// niveau, quand le releve est ancien, fiche ouverte ou non.
    @Test func pastilleDuReleveAncien() throws {
        let (_, _, e) = try NomsSceneTests.demo()
        let m = MoteurPieces()
        func largeur(_ v: LigneDuBas) -> CGFloat { NSHostingView(rootView: v).fittingSize.width }
        let sansFiche = largeur(LigneDuBas(moteur: m, entree: e, legendeForcee: false))
        #expect(largeur(LigneDuBas(moteur: m, entree: e, ancien: true, legendeForcee: false)) > sansFiche)
        let fiche = largeur(LigneDuBas(moteur: m, entree: e, legende: false))
        #expect(fiche < sansFiche, "fiche ouverte : sans la legende")
        #expect(largeur(LigneDuBas(moteur: m, entree: e, legende: false, ancien: true)) > fiche)
    }
}
