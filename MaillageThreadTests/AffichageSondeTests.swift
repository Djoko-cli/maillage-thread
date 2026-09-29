import Foundation
import MaillageCoeur
import Testing
@testable import MaillageThread

@MainActor
@Suite("Affichage de la sonde : noms, qualites, fiche, menu, reglages")
struct AffichageSondeTests {
    /// Les attentes reprennent les memes cles interpolees que le code : elles suivent la
    /// langue de l'hote. (Un litteral sans interpolation n'est pas une cle du catalogue :
    /// il resterait en francais.)
    @Test func libelles() {
        #expect(GrapheCanvas.libelleInconnu(NoeudSonde(id: "rloc:B400", rloc16: 0xB400, genre: .routeur, reconnu: false,
                                                       bordure: true)) == String(localized: "Routeur de bordure · \("B400")"))
        #expect(GrapheCanvas.libelleInconnu(NoeudSonde(id: "rloc:5000", rloc16: 0x5000, genre: .routeur, reconnu: false,
                                                       bordure: false)) == String(localized: "Routeur · \("5000")"))
        #expect(GrapheCanvas.libelleInconnu(NoeudSonde(id: "rloc:AC05", rloc16: 0xAC05, genre: .enfant, reconnu: false,
                                                       bordure: false)) == String(localized: "Non identifié · \("AC05")"))
    }

    @Test func niveaux() {
        #expect(Palette.NiveauLien(3) == .bon)
        #expect(Palette.NiveauLien(2) == .moyen)
        #expect(Palette.NiveauLien(1) == .faible)
        #expect(Palette.NiveauLien(0) == .inconnu)
        #expect(Palette.NiveauLien(nil) == .inconnu)
    }

    /// Epaisseur d'un lien de la sonde : le lien radio s'epaissit avec la qualite (la couleur
    /// seule se lit mal en daltonisme rouge-vert) ; de l'enfant a son parent : 1 pt, sans egard
    /// a la qualite.
    @Test func epaisseurs() {
        #expect(GrapheCanvas.epaisseurLienSonde(.radio, qualite: 3) == 3)
        #expect(GrapheCanvas.epaisseurLienSonde(.radio, qualite: 2) == 2.2)
        #expect(GrapheCanvas.epaisseurLienSonde(.radio, qualite: 1) == 1.4)
        #expect(GrapheCanvas.epaisseurLienSonde(.radio, qualite: 0) == 1.4, "inconnue : comme faible")
        #expect(GrapheCanvas.epaisseurLienSonde(.radio, qualite: nil) == 1.4, "inconnue : comme faible")
        for qualite in [3, 2, 1, 0, nil] as [Int?] {
            #expect(GrapheCanvas.epaisseurLienSonde(.parent, qualite: qualite) == 1)
        }
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
        // Le chef du maillage de demo (routeur 1, RLOC16 0400) : 5 voisins et 4 enfants.
        let chef = try #require(m.routeurs[1])
        let voisins = 5
        let enfants = 4
        #expect(FicheNoeud.ligneSonde(chef, maillage: m, nom: { $0 })
                    == String(localized: "RLOC16 \("0400") · voisins : \(voisins) · enfants : \(enfants)"))
        #expect(FicheNoeud.texteQualite(nil) == String(localized: "qualité inconnue"))
        #expect(FicheNoeud.texteQualite(3) == String(localized: "qualité \(3)"))
    }

    /// « Renommer… » : pour un routeur de l'instantane ou un appareil connu, pas pour un noeud
    /// que la sonde seule connait (son RLOC16 est volatil : rien ne lirait le surnom).
    @Test func renommable() throws {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let r = try #require(s.reseau)
        let m = try #require(s.maillageAffiche(pour: r))
        let routeur = try #require(r.routeurs.first)
        let appareil = try #require(s.instantane?.appareils.first)
        let inconnu = try #require(m.inconnus.first)
        #expect(m.noeud(inconnu.id) != nil, "connu de la sonde")
        #expect(FicheNoeud.renommable(routeur.instance, dans: s))
        #expect(FicheNoeud.renommable(appareil.id, dans: s))
        #expect(!FicheNoeud.renommable(inconnu.id, dans: s))
        #expect(!FicheNoeud.renommable("rloc:5000", dans: s), "ni la sonde ni l'instantane : « Ce nœud n'est plus visible. »")
    }

    @Test func menuEtReglages() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(MenuBarre.ligneSonde(.sansSonde, derniere: nil, maintenant: t) == nil)
        #expect(MenuBarre.ligneSonde(.absente, derniere: nil, maintenant: t) == String(localized: "Sonde : absente"))
        #expect(MenuBarre.ligneSonde(.erreur("x"), derniere: nil, maintenant: t) == String(localized: "Sonde : erreur (voir les Réglages)"))
        #expect(FenetreReglages.texteEtatSonde(.refusee("pas une sonde")) == String(localized: "refusée : \("pas une sonde")"))
    }
}
