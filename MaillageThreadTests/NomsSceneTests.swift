import AppKit
import Foundation
@testable import MaillageCoeur
import SwiftUI
import Testing
@testable import MaillageThread

@MainActor
@Suite("Vue par pieces : noms, apparences et scene de l'app")
struct NomsSceneTests {
    /// La demo : la panne rejouee, ses noms de Maison (pieces et etages de la maquette) et son
    /// maillage de sonde invente.
    static func demo() throws -> (Surveillance, Reseau, EntreeScene) {
        let s = Surveillance(mode: .demo, dossier: nil)
        s.demarrer()
        let r = try #require(s.reseau)
        return (s, r, EntreeScene(surveillance: s, reseau: r, places: PlacesGardees()))
    }

    /// La maison de demo sans les accessoires de ses routeurs de bordure : comme chez Djoko, Maison ne
    /// donne ni les HomePod ni l'Apple TV.
    static func maisonSansRouteurs(_ s: Surveillance) -> NomsMaison? {
        guard var m = s.noms.maison, let r = s.reseau else { return nil }
        let routeurs = Set(r.routeurs.map(\.instance))
        m.accessoires.removeAll { routeurs.contains($0.nom) }
        return m
    }

    /// Libelle d'un noeud : le nom coupe a 40 caracteres, la couronne du chef (celui de la partition
    /// et celui de la sonde), ☾ endormi, ⚠︎ sans adresse ou disparu ; la pastille d'une batterie faible.
    @Test func libelles() throws {
        let (s, r, e) = try Self.demo()
        #expect(e.libelles["Apple TV 4K"]?.texte == "Apple TV 4K 👑")
        #expect(e.libelles["86E7BD1A75F28E6D"] == LibellesNoeuds.Libelle(texte: "Nuki Ultra ☾"))
        #expect(e.libelles["7AF0B6D5006CF95F"]?.texte == "Prise salon ☾ ⚠︎", "disparue")
        #expect(e.libelles["3A5DFAFCAB581AAF"]?.pastille == String(localized: "\(12)\u{202F}%"))
        #expect(e.libelles["rloc:041F"]?.texte == String(localized: "Non identifié · \("041F")"))
        let m = try #require(s.maillageAffiche(pour: r))
        #expect(LibellesNoeuds.chefs(reseau: r, maillage: s.maillage, affiche: m) == ["Apple TV 4K"])
        #expect(LibellesNoeuds.pastilleBatterie(BatterieMaison(alerte: true)) == String(localized: "faible"))
        #expect(LibellesNoeuds.pastilleBatterie(BatterieMaison(niveau: 52)) == nil)
        #expect(LibellesNoeuds.inconnu(NoeudSonde(id: "rloc:5000", rloc16: 0x5000, genre: .routeur, reconnu: false,
                                                  bordure: false)) == String(localized: "Routeur · \("5000")"))
    }

    /// Pieces : celle de l'accessoire d'un appareil ; celle de l'accessoire du nom de l'annonce d'un
    /// routeur de bordure. Noms des etages, des pieces, compte, repere « ailleurs ».
    @Test func piecesEtNoms() throws {
        let (s, r, e) = try Self.demo()
        let pieces = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: s.noms.maison)
        #expect(pieces["Apple TV 4K"] == "Salon" && pieces["HomePod mini chambre"] == "Chambre")
        #expect(pieces["56B1E064401F74EF"] == "Bureau")
        #expect(pieces["1E5019DAC2638F92"] == nil)
        #expect(LibellesNoeuds.nom(ScenePieces.NomEtage.zone("Étage")) == "Étage")
        #expect(LibellesNoeuds.nom(ScenePieces.NomEtage.maison) == String(localized: "Maison"))
        #expect(LibellesNoeuds.nom(ScenePieces.NomPiece.sansPiece, libelles: [:]) == String(localized: "Sans pièce"))
        #expect(LibellesNoeuds.nom(.routeur("Apple TV 4K"), libelles: e.libelles) == "Apple TV 4K 👑")
        #expect(LibellesNoeuds.compte(1) == String(localized: "1 appareil"))
        #expect(LibellesNoeuds.compte(6) == String(localized: "\(6) appareils"))
        let salon = try #require(e.scene.pieces.firstIndex { $0.nom == .maison("Salon") })
        let reperes = SceneProjetee.reperes(e.scene, focus: salon)
        let volet = try #require(reperes.first { $0.enfant == "724CC16B32D8F820" })
        #expect(LibellesNoeuds.ailleurs(volet, scene: e.scene, libelles: e.libelles)
                == "↑ HomePod mini chambre · Chambre, Étage")
    }

    /// Routeurs de bordure que Maison ne place pas : la piece de leur nom (« HomePod mini chambre »), sinon
    /// celle qu'on leur a choisie, qui passe avant ; les autres vont dans « Sans piece ». Un routeur que
    /// Maison place garde sa piece.
    @Test func piecesDesRouteurs() throws {
        let (s, r, _) = try Self.demo()
        let maison = try #require(Self.maisonSansRouteurs(s))
        #expect(!maison.accessoires.contains { $0.nom == "Apple TV 4K" })
        let noms = s.nomsRouteurs(pour: r)
        var pieces = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: maison,
                                           nomsRouteurs: noms)
        #expect(pieces["HomePod mini chambre"] == "Chambre" && pieces["HomePod mini bureau"] == "Bureau")
        #expect(pieces["HomePod Palier"] == nil && pieces["HomePod Avant"] == nil && pieces["Apple TV 4K"] == nil)
        var choix = PiecesRouteurs()
        choix.choisir("Salon", routeur: "HomePod Palier", domicile: maison.domicile ?? "")
        choix.choisir("Bureau", routeur: "HomePod mini chambre", domicile: maison.domicile ?? "")
        pieces = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: maison,
                                       nomsRouteurs: noms, choix: choix)
        #expect(pieces["HomePod Palier"] == "Salon" && pieces["HomePod mini chambre"] == "Bureau")
        let avecMaison = LibellesNoeuds.pieces(reseau: r, appareils: s.appareilsAffiches(pour: r), maison: s.noms.maison,
                                               nomsRouteurs: noms, choix: choix)
        #expect(avecMaison["HomePod mini chambre"] == "Chambre", "Maison passe avant le choix")
        s.noms.maison = maison
        let e = EntreeScene(surveillance: s, reseau: r, places: PlacesGardees(), choix: choix)
        let gauche = try #require(e.scene.noeud("HomePod Palier"))
        #expect(e.scene.pieces[gauche.piece].nom == .maison("Salon"))
        let atv = try #require(e.scene.noeud("Apple TV 4K"))
        #expect(e.scene.pieces[atv.piece].nom == .sansPiece)
    }

    /// La maison de demo : les deux etages et les huit pieces de la maquette, « Sans piece » sur le
    /// plateau du bas ; les apparences du graphe d'avant.
    @Test func sceneDeLaDemo() throws {
        let (_, _, e) = try Self.demo()
        #expect(e.scene.etages.map(\.nom) == [.zone("Rez-de-chaussée"), .zone("Étage")])
        let bas = e.scene.etages[0].pieces.map { e.scene.pieces[$0].nom }
        #expect(bas == [.maison("Buanderie"), .maison("Cuisine"), .maison("Entrée"), .maison("Salon"), .sansPiece])
        let haut = e.scene.etages[1].pieces.map { e.scene.pieces[$0].nom }
        #expect(haut == [.maison("Bureau"), .maison("Chambre"), .maison("Chambre d'amis"), .maison("Salle de bain")])
        #expect(!e.scene.sansPiecesMaison)
        #expect(e.domicile == "Maison (démo)")
        #expect(e.apparences["Apple TV 4K"] == DessinNoeud.Apparence(forme: .sphere(halo: 10),
                                                                    couleur: .routeur(principale: true)))
        #expect(e.apparences["HomePod Avant"]?.forme == .sphere(halo: 5))
        #expect(e.apparences["Aqara HubM100 #DFEB"]?.couleur == .routeur(principale: false))
        #expect(e.apparences["7AF0B6D5006CF95F"] == DessinNoeud.Apparence(forme: .anneau, couleur: .appareil(.disparu)))
        #expect(e.apparences["56B1E064401F74EF"] == DessinNoeud.Apparence(forme: .pastille, couleur: .appareil(.joignable)))
        #expect(e.apparences["rloc:041F"]?.couleur == .appareil(.inconnu))
    }

    /// La cle de la disposition ne change pas avec l'etat d'un noeud ; elle change avec son nom.
    @Test func cleDeLaDisposition() throws {
        let (s, r, e) = try Self.demo()
        #expect(EntreeScene(surveillance: s, reseau: r, places: PlacesGardees()).cleDisposition == e.cleDisposition)
        s.renommer("56B1E064401F74EF", en: "Pont Halo")
        #expect(EntreeScene(surveillance: s, reseau: r, places: PlacesGardees()).cleDisposition != e.cleDisposition)
    }

    /// Sur la maison de demo, avec les noms mesures par l'app : aucun lien ne passe sur une piece
    /// autre que celles de ses bouts, aucune carte n'en recouvre une autre.
    @Test func demoSansTraversee() throws {
        let (_, _, e) = try Self.demo()
        let mesure = MesureNoms()
        var largeurs: [String: Double] = [:]
        for n in e.scene.noeuds {
            largeurs[n.id] = mesure.noeud(try #require(e.libelles[n.id]), routeur: n.rang <= 2).width
        }
        let cartes = CartesPieces.cartes(e.scene, largeurs: largeurs)
        let d = DispositionPieces(scene: e.scene, cartes: cartes)
        let calcul = DispositionPieces.Calcul(scene: e.scene, cartes: cartes, fixees: [:])
        #expect(calcul.traversees(d.positions) == 0)
        #expect(d.cout < d.coutDepart)
        for et in e.scene.etages {
            for (k, a) in et.pieces.enumerated() {
                for b in et.pieces[(k + 1)...] {
                    let dx = abs(d.positions[b].x - d.positions[a].x), dz = abs(d.positions[b].y - d.positions[a].y)
                    let px = (cartes[a].largeur + cartes[b].largeur) / 2 + DispositionPieces.gap - dx
                    let pz = (cartes[a].profondeur + cartes[b].profondeur) / 2 + DispositionPieces.gap + DispositionPieces.lab - dz
                    #expect(!(px > 1e-6 && pz > 1e-6), "\(e.scene.pieces[a].id) / \(e.scene.pieces[b].id)")
                }
            }
        }
    }

    /// Tailles des textes rendues par `Canvas` a l'echelle 1, 2 et 3.
    static func taillesDessinees(_ textes: [Text], echelle: CGFloat) -> [CGSize] {
        final class Boite: @unchecked Sendable { var tailles: [CGSize] = [] }
        let boite = Boite()
        let rendu = ImageRenderer(content: Canvas { ctx, _ in
            boite.tailles = textes.map { ctx.resolve($0).measure(in: StylesNoms.grand) }
        }.frame(width: 10, height: 10))
        rendu.scale = echelle
        _ = rendu.cgImage
        return boite.tailles
    }

    /// La taille mesuree hors du `Canvas` couvre le texte dessine, a toute echelle : un nom ne deborde
    /// pas de la place que le placement lui donne (moins d'un point pres).
    @Test func tailleMesureeCommeDessinee() {
        let mesure = MesureNoms()
        let noms = ["Détecteur de passage lingerie sud ☾", "HomePod mini chambre", "Apple TV 4K 👑", "Salon"]
        for echelle in [1.0, 2.0, 3.0] {
            for n in noms {
                for routeur in [false, true] {
                    let dessinee = Self.taillesDessinees([StylesNoms.noeud(n, routeur: routeur, fort: true)],
                                                         echelle: echelle)[0]
                    let place = mesure.noeud(LibellesNoeuds.Libelle(texte: n), routeur: routeur)
                    #expect(dessinee.width + 10 <= place.width + 1 && dessinee.height <= place.height + 1,
                            "\(n) a \(echelle) : \(dessinee) dans \(place)")
                }
                let t = Self.taillesDessinees([StylesNoms.etage(n)], echelle: echelle)[0]
                let e = mesure.etage(n)
                #expect(t.width <= e.width + 1 && t.height <= e.height + 1)
            }
        }
    }
}
