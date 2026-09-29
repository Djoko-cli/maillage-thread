import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Affichage de la sonde : noms, qualites, fiche, menu, reglages")
struct AffichageSondeTests {
    @Test func libelles() {
        #expect(GrapheCanvas.libelleInconnu(NoeudSonde(id: "rloc:B400", rloc16: 0xB400, genre: .routeur, reconnu: false,
                                                       bordure: true)) == String(localized: "Routeur de bordure · B400"))
        #expect(GrapheCanvas.libelleInconnu(NoeudSonde(id: "rloc:5000", rloc16: 0x5000, genre: .routeur, reconnu: false,
                                                       bordure: false)) == String(localized: "Routeur · 5000"))
        #expect(GrapheCanvas.libelleInconnu(NoeudSonde(id: "rloc:AC05", rloc16: 0xAC05, genre: .enfant, reconnu: false,
                                                       bordure: false)) == String(localized: "Non identifié · AC05"))
    }

    @Test func niveaux() {
        #expect(Palette.NiveauLien(3) == .bon)
        #expect(Palette.NiveauLien(2) == .moyen)
        #expect(Palette.NiveauLien(1) == .faible)
        #expect(Palette.NiveauLien(0) == .inconnu)
        #expect(Palette.NiveauLien(nil) == .inconnu)
    }

    /// Mode demo : maillage de demo ; fiche d'un enfant et d'un routeur.
    @Test func ficheEtDemo() throws {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let r = try #require(s.reseau)
        let m = try #require(s.maillageAffiche(pour: r))
        #expect(!s.maillageAncien)
        let enfant = try #require(m.enfants.values.first { $0.reconnu && m.parent(de: $0.id) != nil })
        let ligne = FicheNoeud.ligneSonde(enfant, maillage: m, nom: { "P[\($0)]" })
        #expect(ligne.hasPrefix(String(format: "RLOC16 %04X", enfant.rloc16)))
        #expect(ligne.contains("P["))
        let chef = try #require(m.routeurs[1])
        #expect(FicheNoeud.ligneSonde(chef, maillage: m, nom: { $0 }).contains(String(localized: "voisins : ")) )
        #expect(FicheNoeud.texteQualite(nil) == String(localized: "qualité inconnue"))
        #expect(FicheNoeud.texteQualite(3) == String(localized: "qualité \(3)"))
    }

    @Test func menuEtReglages() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(MenuBarre.ligneSonde(.sansSonde, derniere: nil, maintenant: t) == nil)
        #expect(MenuBarre.ligneSonde(.absente, derniere: nil, maintenant: t) == String(localized: "Sonde : absente"))
        #expect(MenuBarre.ligneSonde(.erreur("x"), derniere: nil, maintenant: t) == String(localized: "Sonde : erreur (voir les Réglages)"))
        #expect(FenetreReglages.texteEtatSonde(.refusee("pas une sonde")) == String(localized: "refusée : \("pas une sonde")"))
    }
}
