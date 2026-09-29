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

    /// Ligne du menu : le nom de la sonde a la place de « Sonde » quand il est connu ;
    /// pendant une tournee, son etape et son compteur.
    @Test func menuEtReglages() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let sonde = String(localized: "Sonde")
        #expect(SondeMaillage.nomAffiche(nil) == sonde)
        #expect(SondeMaillage.nomAffiche("SONDE-01") == "SONDE-01")
        #expect(MenuBarre.ligneSonde(.sansSonde, nom: nil, derniere: nil, avancement: nil, maintenant: t) == nil)
        #expect(MenuBarre.ligneSonde(.absente, nom: nil, derniere: nil, avancement: nil, maintenant: t)
                == String(localized: "\(sonde) : absente"))
        #expect(MenuBarre.ligneSonde(.absente, nom: "SONDE-01", derniere: nil, avancement: nil, maintenant: t)
                == String(localized: "\("SONDE-01") : absente"))
        #expect(MenuBarre.ligneSonde(.connexion, nom: "SONDE-01", derniere: nil, avancement: nil, maintenant: t)
                == String(localized: "\("SONDE-01") : connexion…"))
        #expect(MenuBarre.ligneSonde(.erreur("x"), nom: "SONDE-01", derniere: nil, avancement: nil, maintenant: t)
                == String(localized: "\("SONDE-01") : erreur (voir les Réglages)"))
        guard case .bonjour(let b)? = MessageSonde.lire(Data(CanalRejoue.bonjourNomme.utf8)) else {
            Issue.record("bonjour illisible")
            return
        }
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: "SONDE-01", derniere: nil, avancement: nil, maintenant: t)
                == String(localized: "\("SONDE-01") : connectée"))
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: "SONDE-01", derniere: t - 120, avancement: nil, maintenant: t)
                == String(localized: "\("SONDE-01") : connectée · relevé \(FicheNoeud.relatif(t - 120, t))"))
        let balayage = AvancementTournee(etape: .balayage, fait: 24, total: 48)
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: "SONDE-01", derniere: t - 120, avancement: balayage, maintenant: t)
                == String(localized: "\("SONDE-01") : \(TexteTournee.etape(.balayage)) \(24)/\(48)…"))
        let rien = AvancementTournee(etape: .identites, fait: 0, total: 0)
        #expect(MenuBarre.ligneSonde(.connectee(b), nom: nil, derniere: nil, avancement: rien, maintenant: t)
                == String(localized: "\(sonde) : \(TexteTournee.etape(.identites))…"))
        #expect(FenetreReglages.texteEtatSonde(.refusee("pas une sonde")) == String(localized: "refusée : \("pas une sonde")"))
    }

    /// Choix du port : la sonde retenue sous son nom ; un autre port, un port sans numero de
    /// serie ou la sonde retenue sans nom connu (firmware 1.0.0), sous un libelle neutre.
    @Test func libellesDesPorts() {
        let retenue = PortUSB(chemin: "/dev/cu.usbmodem11301", vid: 0x303A, pid: 0x1001, serie: "A0:00:00:00:00:01",
                              produit: nil)
        let autre = PortUSB(chemin: "/dev/cu.usbmodemFACTICE02", vid: 0x303A, pid: 0x1001, serie: "B0:00:00:00:00:02",
                            produit: nil)
        let sansSerie = PortUSB(chemin: "/dev/cu.usbmodemFACTICE03", vid: 0x303A, pid: 0x1001, serie: nil, produit: nil)
        #expect(FenetreReglages.libellePort(retenue, serieRetenue: "A0:00:00:00:00:01", nom: "SONDE-01") == "SONDE-01")
        #expect(FenetreReglages.libellePort(retenue, serieRetenue: "A0:00:00:00:00:01", nom: nil) == "ESP32-C6 · usbmodem11301")
        #expect(FenetreReglages.libellePort(autre, serieRetenue: "A0:00:00:00:00:01", nom: "SONDE-01")
                == "ESP32-C6 · usbmodemFACTICE02")
        #expect(FenetreReglages.libellePort(retenue, serieRetenue: nil, nom: "SONDE-01") == "ESP32-C6 · usbmodem11301",
                "aucune sonde retenue")
        #expect(FenetreReglages.libellePort(sansSerie, serieRetenue: nil, nom: "SONDE-01") == "ESP32-C6 · usbmodemFACTICE03")
    }

    /// Textes de l'avancement : libelles d'etape distincts ; « etape · fait/total », l'etape
    /// seule quand elle n'a rien a faire ; duree en m:ss dans la barre du graphe, en unites
    /// dans les Reglages.
    @Test func texteAvancement() {
        let etapes = AvancementTournee.Etape.allCases.map(TexteTournee.etape)
        #expect(Set(etapes).count == etapes.count)
        #expect(!etapes.contains(""))
        let a = AvancementTournee(etape: .balayage, fait: 24, total: 48)
        #expect(TexteTournee.avancement(a) == String(localized: "\(TexteTournee.etape(.balayage)) · \(24)/\(48)"))
        #expect(TexteTournee.avancement(AvancementTournee(etape: .identites, fait: 0, total: 0))
                == TexteTournee.etape(.identites))
        #expect(TexteTournee.chrono(42) == "0:42")
        #expect(TexteTournee.chrono(600) == "10:00")
        #expect(TexteTournee.chrono(3723) == "1:02:03")
        #expect(TexteTournee.chrono(-3) == "0:00", "horloge qui recule")
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(TexteTournee.barre(a, debut: t, maintenant: t + 42) == String(localized: "\(TexteTournee.avancement(a)) · \("0:42")"))
        #expect(TexteTournee.reglages(a, debut: t, maintenant: t + 42)
                == String(localized: "\(TexteTournee.avancement(a)) · depuis \(TexteTournee.duree(42))"))
        #expect(TexteTournee.duree(42).contains("42"))
        #expect(TexteTournee.duree(90).contains("1") && TexteTournee.duree(90).contains("30"))
    }

    /// Code d'appairage mis en forme 4-3-4 (11 chiffres) ou 4-3-4-5-5 (21) ; deja mis en forme
    /// ou d'une autre longueur, tel quel. QR code d'une charge « MT:... » : une image carree
    /// d'au moins 21 modules (valeurs inventees).
    @Test func codeMatter() throws {
        #expect(CodeMatter.formater("12345678901") == "1234-567-8901")
        #expect(CodeMatter.formater("123456789012345678901") == "1234-567-8901-23456-78901")
        #expect(CodeMatter.formater("1234-567-8901") == "1234-567-8901")
        #expect(CodeMatter.formater("12345") == "12345")
        #expect(CodeMatter.formater("1234567890a") == "1234567890a")
        let image = try #require(CodeMatter.imageQR("MT:ABCDEFGHIJ0123456789"))
        #expect(image.width == image.height)
        #expect(image.width >= 21)
    }
}
