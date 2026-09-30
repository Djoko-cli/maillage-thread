import AppKit
import Foundation
import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Graphe : projection du plan vers la vue")
struct GrapheTests {
    @Test func projection() {
        let cadre = (min: Point2D(-210, -210), max: Point2D(390, 470))
        let p = Projection(cadre: cadre, taille: CGSize(width: 1000, height: 800),
                           marges: (haut: 70, bas: 30, cotes: 60))
        // Place libre : 880 x 700 pour un cadre de 600 x 680 : la hauteur decide.
        #expect(abs(p.echelle - 700.0 / 680.0) < 1e-9)
        let centre = p.vue(Point2D(90, 130))
        #expect(abs(centre.x - 500) < 1e-9 && abs(centre.y - 420) < 1e-9, "centre du cadre au centre de la place libre")
        let q = p.plan(p.vue(Point2D(12, -34)))
        #expect(abs(q.x - 12) < 1e-9 && abs(q.y + 34) < 1e-9)
        let zoom = Projection(cadre: cadre, taille: CGSize(width: 1000, height: 800),
                              marges: (haut: 70, bas: 30, cotes: 60), zoom: 2, decalage: CGSize(width: 10, height: -5))
        #expect(abs(zoom.echelle - 2 * p.echelle) < 1e-9)
        let c2 = zoom.vue(Point2D(90, 130))
        #expect(abs(c2.x - 510) < 1e-9 && abs(c2.y - 415) < 1e-9)
    }

    /// Le bouton rafraichir du graphe lance aussi le passeur des noms de Maison, en mode direct
    /// seulement : plus de dossier des noms a choisir.
    @Test func rafraichirLanceLePasseurEnModeDirect() {
        #expect(BarreOutils.lancePasseur(mode: .direct))
        #expect(!BarreOutils.lancePasseur(mode: .demo))
    }

    /// L'aide du bouton rafraichir dit ce qu'il lancera vraiment : le reseau toujours, une
    /// tournee si la sonde est connectee et libre, les noms de Maison si le passeur sera lance.
    @Test func aideDuBoutonRafraichir() {
        #expect(BarreOutils.aideRafraichir(tournee: true, passeur: true)
                == String(localized: "Rafraîchir : réseau, tournée de la sonde et noms de Maison"))
        #expect(BarreOutils.aideRafraichir(tournee: true, passeur: false)
                == String(localized: "Rafraîchir : réseau et tournée de la sonde"))
        #expect(BarreOutils.aideRafraichir(tournee: false, passeur: true)
                == String(localized: "Rafraîchir : réseau et noms de Maison"))
        #expect(BarreOutils.aideRafraichir(tournee: false, passeur: false) == String(localized: "Rafraîchir : réseau"))
    }

    /// La capsule de la tournee garde la meme largeur a chaque etape (celle de la plus longue,
    /// compteur et duree compris) : elle ne change pas de taille a chaque pas.
    @Test func capsuleDeLargeurFixe() {
        let debut = Date(timeIntervalSinceNow: -42)
        let avancements = AvancementTournee.Etape.allCases.flatMap { e in
            [AvancementTournee(etape: e, fait: 0, total: 0), AvancementTournee(etape: e, fait: 3, total: 7),
             AvancementTournee(etape: e, fait: 24, total: 48), AvancementTournee(etape: e, fait: 160, total: 160)]
        }
        let largeurs = avancements.map {
            NSHostingView(rootView: IndicateurTournee(avancement: $0, debut: debut)).fittingSize.width
        }
        #expect(Set(largeurs).count == 1, "\(largeurs)")
    }

    /// La ligne de la tournee, sous la barre et le bandeau de scission, ne recouvre pas la bande
    /// des titres des zones : la marge du haut du graphe lui garde sa place tant qu'une sonde est
    /// retenue, pendant une tournee ou non. Pire cas : graphe limite par la hauteur, son haut sur
    /// la marge (zoom 1). Sans sonde, la barre et le bandeau seuls tiennent aussi au-dessus.
    @Test(.timeLimit(.minutes(1))) func enTeteAuDessusDesTitres() async throws {
        let demo = try LibellesGrapheTests.demo()
        #expect(demo.scinde, "la demo : reseau scinde, bandeau affiche")
        let scinde = Surveillance(mode: .demo, dossier: nil)
        scinde.demarrer()
        let sansReseau = Surveillance(mode: .direct, dossier: nil)
        let noms = NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit)
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let journal = JournalCanaux()
        let sonde = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in SondeMaillageTests.canalRetenu(journal) })
        func hauteur(_ s: Surveillance) -> CGFloat {
            NSHostingView(rootView: EnTeteGraphe().environment(s).environment(sonde).environment(noms)).fittingSize.height
        }
        func hautDesTitres(marge: CGFloat) -> CGFloat {
            let projection = Projection(cadre: demo.disposition.cadre, taille: CGSize(width: 4000, height: 700),
                                        marges: (haut: marge, bas: 30, cotes: 60))
            let placement = MemoirePlacement().placement(demo.disposition, libelles: demo.libelles,
                                                         echelle: projection.echelle).decale(projection.origine)
            return (placement.obstacles.map(\.minY).min() ?? .infinity) - PlacementLibelles.margeFond.height
        }
        for (s, estScinde) in [(sansReseau, false), (scinde, true)] {
            let bas = FenetreGraphe.bord + hauteur(s)
            let haut = hautDesTitres(marge: FenetreGraphe.margeHaut(scinde: estScinde, sondeRetenue: false))
            #expect(bas <= haut, "sans sonde, scinde \(estScinde) : en-tete jusqu'a \(bas), titres des \(haut)")
        }
        await sonde.connecter(SondeMaillageTests.port, choisi: true)
        await journal.attendre(SondeMaillageTests.listeRetenue)
        await SondeMaillageTests.attendre { sonde.avancement != nil }
        for (s, estScinde) in [(sansReseau, false), (scinde, true)] {
            let bas = FenetreGraphe.bord + hauteur(s)
            let haut = hautDesTitres(marge: FenetreGraphe.margeHaut(scinde: estScinde, sondeRetenue: sonde.serie != nil))
            #expect(bas <= haut, "tournee, scinde \(estScinde) : en-tete jusqu'a \(bas), titres des \(haut)")
        }
        await sonde.oublier()
    }

    /// Pendant une tournee, la barre d'outils garde sa largeur : le bouton rafraichir ne bouge
    /// pas sous le pointeur. L'indicateur est sur sa propre ligne, qui ne prend aucune place
    /// hors tournee (pas meme l'espacement de la pile).
    @Test(.timeLimit(.minutes(1))) func barreImmobilePendantUneTournee() async throws {
        let (p, domaine) = try SondeMaillageTests.preferences()
        defer { p.removePersistentDomain(forName: domaine) }
        let surveillance = Surveillance(mode: .direct, dossier: nil)
        let noms = NomsInternes(cache: nil, lanceur: NomsInternes.lanceurInterdit)
        let journal = JournalCanaux()
        let sonde = SondeMaillage(preferences: p, actif: true, ouvrirCanal: { _ in SondeMaillageTests.canalRetenu(journal) })
        func taille(_ vue: some View) -> CGSize {
            NSHostingView(rootView: vue.environment(surveillance).environment(sonde).environment(noms)).fittingSize
        }
        func pile() -> CGSize {
            taille(VStack(spacing: 10) {
                Color.clear.frame(width: 10, height: 10)
                LigneTournee()
                Color.clear.frame(width: 10, height: 10)
            })
        }
        let barre = taille(BarreOutils())
        #expect(pile().height == 30, "hors tournee : rien")
        await sonde.connecter(SondeMaillageTests.port, choisi: true)
        await journal.attendre(SondeMaillageTests.listeRetenue)
        await SondeMaillageTests.attendre { sonde.avancement != nil }
        #expect(taille(BarreOutils()) == barre)
        #expect(pile().height > 30, "pendant la tournee : la ligne de l'indicateur")
        await sonde.oublier()
    }
}

@MainActor
@Suite("Fiche d'un appareil")
struct FicheTests {
    /// Piece, fabricant (sinon modele HomeKit), modele, puis firmware quand Maison le donne.
    @Test func ligneDescription() {
        let maison = AccessoireMaison(nom: "Capteur", piece: "Salon", fabricant: "Acme", modele: "Capteur 2",
                                      firmware: "1.4.2")
        #expect(FicheNoeud.ligneDescription(maison: maison, modeleHomeKit: nil)
                == "Salon · Acme · Capteur 2 · firmware 1.4.2")
        var sansFirmware = maison
        sansFirmware.firmware = nil
        #expect(FicheNoeud.ligneDescription(maison: sansFirmware, modeleHomeKit: nil) == "Salon · Acme · Capteur 2")
        sansFirmware.firmware = ""
        #expect(FicheNoeud.ligneDescription(maison: sansFirmware, modeleHomeKit: nil) == "Salon · Acme · Capteur 2")
        #expect(FicheNoeud.ligneDescription(maison: nil, modeleHomeKit: "Eve Door") == "Eve Door")
        #expect(FicheNoeud.ligneDescription(maison: nil, modeleHomeKit: nil) == "")
    }

    /// Textes de l'app, dans la langue de l'hote des tests.
    static func pourcent(_ n: Int) -> String { String(localized: "\(n)\u{202F}%") }
    static let surBatterie = String(localized: "sur batterie")
    static let enCharge = String(localized: "en charge")
    static let nonRechargeable = String(localized: "non rechargeable")
    static let faible = String(localized: "batterie faible")
    static let ok = String(localized: "batterie OK")

    /// Niveau, puis l'etat de charge ; faible, « batterie faible » (et « en
    /// charge » seulement) ; sans niveau, l'alerte seule, et « batterie OK »
    /// seulement si l'accessoire le dit.
    @Test func ligneBatterie() {
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(niveau: 52, charge: .horsCharge))
                == "\(Self.pourcent(52)) · \(Self.surBatterie)")
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(niveau: 81, charge: .enCharge))
                == "\(Self.pourcent(81)) · \(Self.enCharge)")
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(niveau: 97, charge: .nonRechargeable))
                == "\(Self.pourcent(97)) · \(Self.nonRechargeable)")
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(niveau: 88)) == Self.pourcent(88))
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(niveau: 12, charge: .horsCharge))
                == "\(Self.pourcent(12)) · \(Self.faible)")
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(niveau: 15, charge: .enCharge))
                == "\(Self.pourcent(15)) · \(Self.faible) · \(Self.enCharge)")
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(alerte: true)) == Self.faible)
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(alerte: false)) == Self.ok)
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(charge: .enCharge, alerte: false))
                == "\(Self.ok) · \(Self.enCharge)")
        #expect(FicheNoeud.ligneBatterie(BatterieMaison(charge: .enCharge)) == Self.enCharge, "alerte inconnue")
        #expect(Self.pourcent(52).contains("\u{202F}") || !Self.pourcent(52).contains(" "),
                "pas d'espace secable avant %")
    }

    /// Triangle si faible, eclair en charge, sinon le niveau par quart.
    @Test func symboleBatterie() {
        #expect(FicheNoeud.symboleBatterie(BatterieMaison(niveau: 12)) == "exclamationmark.triangle.fill")
        #expect(FicheNoeud.symboleBatterie(BatterieMaison(alerte: true)) == "exclamationmark.triangle.fill")
        #expect(FicheNoeud.symboleBatterie(BatterieMaison(niveau: 81, charge: .enCharge)) == "battery.100percent.bolt")
        #expect(FicheNoeud.symboleBatterie(BatterieMaison(niveau: 30)) == "battery.25percent")
        #expect(FicheNoeud.symboleBatterie(BatterieMaison(niveau: 52)) == "battery.50percent")
        #expect(FicheNoeud.symboleBatterie(BatterieMaison(niveau: 64)) == "battery.75percent")
        #expect(FicheNoeud.symboleBatterie(BatterieMaison(niveau: 100)) == "battery.100percent")
        #expect(FicheNoeud.symboleBatterie(BatterieMaison(alerte: false)) == "battery.100percent")
    }

    /// Pastille du graphe : seulement pour une batterie faible ; le niveau, sinon « faible ».
    @Test func pastilleBatterie() {
        #expect(GrapheCanvas.pastilleBatterie(BatterieMaison(niveau: 12)) == Self.pourcent(12))
        #expect(GrapheCanvas.pastilleBatterie(BatterieMaison(alerte: true)) == String(localized: "faible"))
        #expect(GrapheCanvas.pastilleBatterie(BatterieMaison(niveau: 90, alerte: true)) == Self.pourcent(90))
        #expect(GrapheCanvas.pastilleBatterie(BatterieMaison(niveau: 52)) == nil)
        #expect(GrapheCanvas.pastilleBatterie(nil) == nil)
    }
}
