import Foundation
@testable import MaillageCoeur
import Testing
@testable import MaillageThread

/// Appareil qui n'annonce plus d'adresse, verifie par la sonde (12/10) : trouve par la resolution, il est joignable,
/// rattache a son parent, sans alerte ni evenement ; pas trouve, son adresse est « non annoncee ». Valeurs inventees.
@MainActor
@Suite("Adresse non annoncee, verifiee par la sonde (app)")
struct AdresseVerifieeAppTests {
    static let partition = "0000AAAA"
    static let routeur = "Routeur inventé"
    /// Appareil Matter : son hote est son ExtMac.
    static let matter = "0000000000000001"
    /// Appareil dont l'hote n'est pas l'ExtMac (accessoire HomeKit) : reconnu a son adresse.
    static let hap = "Prise-inventee"
    static let temoin = "0000000000000003"

    static func adresse(_ n: Int) -> String { "fd00:aaaa:bbbb:1::\(n)" }

    /// Le chef de la partition, qui publie fd00:aaaa:bbbb:1::/64, et trois appareils ; `muets` : sans adresse ;
    /// `partis` : n'annoncent plus rien.
    static func annonces(_ date: Date, muets: Set<String> = [], partis: Set<String> = []) -> Annonces {
        let txt = ChampsTXT([
            "nn": Data("Maison inventee".utf8), "xp": Data([0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]),
            "tv": Data("1.4.0".utf8), "pt": Data([0, 0, 0xAA, 0xAA]), "sb": Data([0, 0, 0x07, 0xB1]),
            "omr": Data([0x40, 0xFD, 0x00, 0xAA, 0xAA, 0xBB, 0xBB, 0x00, 0x01]),
            "xa": Data([0xE1, 0, 0, 0, 0, 0, 0, 0xA1]),
        ])
        var a = Annonces(date: date, routeurs: [AnnonceService(instance: routeur, hote: "Routeur-invente.local",
                                                                port: 49153, txt: txt)],
                         adresses: ["Routeur-invente.local": ["fe80::1"]])
        for (n, id) in [matter, hap, temoin].enumerated() where !partis.contains(id) {
            a.matter.append(AnnonceService(instance: String(format: "0000000000000F01-%016X", n + 1),
                                           hote: id + ".local", port: 5540))
            a.adresses[id + ".local"] = muets.contains(id) ? [] : [adresse(n + 1)]
        }
        return a
    }

    /// Mode direct sans dossier : le depart il y a 15 min, puis `muets` et `partis` au-dela du sursis de 2 min.
    static func surveillance(muets: Set<String> = [], partis: Set<String> = [], maintenant: Date) -> Surveillance {
        let s = Surveillance(mode: .direct, dossier: nil)
        s.integrer(annonces(maintenant - 900))
        s.integrer(annonces(maintenant - 840, muets: muets, partis: partis))
        s.integrer(annonces(maintenant - 700, muets: muets, partis: partis))
        return s
    }

    /// Maillage de la sonde : le chef (routeur 3, son ExtMac est le `xa` de l'annonce), muet, et sous lui les
    /// enfants trouves par la resolution (numeros inventes, comme sous un routeur Apple) ; `resolus` : ce que porte
    /// le maillage. `places` faux : sans ces enfants, comme la tournee pour une resolution anterieure a la perte de
    /// l'annonce.
    static func maillage(_ date: Date, resolus: [String: Date], places: Bool = true) -> Maillage {
        var c = ConstructionMaillage(date: date, partition: partition)
        c.routeurs(Route64(sequence: 1, routes: [RouteRouteur(idRouteur: 3, qualiteSortante: 0, qualiteEntrante: 0,
                                                              cout: 0)]), chef: 3)
        c.muet(3)
        c.identite("E1000000000000A1", routeur: 3)
        let ext: [String: String?] = [matter: matter, hap: nil]
        for (k, id) in [matter, hap].enumerated() {
            guard places, let d = resolus[id], let ad = AdresseIPv6(adresse(k + 1)) else { continue }
            c.enfant(EnfantMaillage(rloc16: 0x0C00 | EnfantMaillage.bitInvente | UInt16(k), extMac: ext[id] ?? nil,
                                    adresses: [ad], source: .resolution, resolu: d))
        }
        var m = c.maillage()
        m.resolution = resolus.values.max()
        m.resolus = resolus
        return m
    }

    /// Trouves par la sonde : le sans adresse (Matter et HomeKit) est joignable, rattache a son parent sur la carte,
    /// sans alerte ; sa fiche dit « joignable, adresse plus annoncee » et l'age de la verification. Aucun evenement
    /// ni notification nouveaux, ni au maillage ni au releve suivant.
    @Test func trouveParLaSonde() throws {
        let maintenant = Date()
        let s = Self.surveillance(muets: [Self.matter, Self.hap], maintenant: maintenant)
        #expect(s.evenements.filter { $0.type == .appareilSansAdresse }.count == 2, "l'evenement existant reste")
        #expect(s.appareilsAResoudre().map(\.id) == [Self.matter, Self.temoin, Self.hap].sorted())
        #expect(s.appareilsAResoudre().first { $0.id == Self.hap }?.adresse == AdresseIPv6(Self.adresse(2)))
        var alertes: [AlerteAEnvoyer] = []
        s.surAlertes = { alertes += $0 }
        let avant = s.evenements
        let trouve = maintenant - 120
        s.recevoir(Self.maillage(maintenant - 150, resolus: [Self.matter: trouve, Self.hap: trouve]),
                   a: maintenant - 60)

        let r = try #require(s.reseau)
        let affiches = s.appareilsAffiches(pour: r)
        #expect(affiches.first { $0.id == Self.matter }?.etat == .joignable)
        #expect(affiches.first { $0.id == Self.hap }?.etat == .joignable)
        #expect(s.resume?.injoignables == 0)
        #expect(s.verification(Self.matter, a: maintenant) == trouve)
        #expect(s.verification(Self.temoin, a: maintenant) == nil, "il annonce son adresse : rien a verifier")
        let m = try #require(s.maillageAffiche(pour: r))
        #expect(m.parent(de: Self.matter) == Self.routeur, "par son ExtMac")
        #expect(m.parent(de: Self.hap) == Self.routeur, "par sa derniere adresse")
        let graphe = GrapheReseau(reseau: r, appareils: affiches, maillage: m)
        #expect(graphe.parent(de: Self.hap) == Self.routeur)
        #expect(graphe.liens.contains { $0.de == Self.hap && $0.genre == .parent })

        #expect(FicheNoeud.texteEtat(.sansAdresse, disparu: false, verifie: true)
                == String(localized: "joignable, adresse plus annoncée"))
        #expect(FicheNoeud.texteVerification(trouve, maintenant)
                == String(localized: "vérifié par la sonde \(FicheNoeud.relatif(trouve, maintenant))"))

        #expect(s.evenements == avant, "aucun evenement nouveau")
        s.integrer(Self.annonces(maintenant - 30, muets: [Self.matter, Self.hap]))
        #expect(s.evenements == avant, "ni au releve suivant")
        #expect(alertes.isEmpty, "aucune notification")
    }

    /// Pas trouve par la sonde (l'introuvable n'est pas dans la memoire de la tournee), ou sans sonde : « adresse non
    /// annoncee », en alerte comme avant ; une verification de plus de 2 resolutions ou un maillage perime ne comptent
    /// pas.
    @Test func pasTrouve() throws {
        let maintenant = Date()
        let s = Self.surveillance(muets: [Self.hap], maintenant: maintenant)
        let r = try #require(s.reseau)
        #expect(s.verification(Self.hap, a: maintenant) == nil, "sans sonde")
        #expect(s.appareilsAffiches(pour: r).first { $0.id == Self.hap }?.etat == .sansAdresse)
        s.recevoir(Self.maillage(maintenant - 150, resolus: [:]), a: maintenant - 60)
        #expect(s.verification(Self.hap, a: maintenant) == nil)
        #expect(s.appareilsAffiches(pour: r).first { $0.id == Self.hap }?.etat == .sansAdresse)
        #expect(s.resume?.injoignables == 1)
        #expect(s.maillageAffiche(pour: r)?.parent(de: Self.hap) == nil)
        #expect(FicheNoeud.texteEtat(.sansAdresse, disparu: false, verifie: false)
                == String(localized: "adresse non annoncée"))

        let vieille = maintenant - Surveillance.ageMaxVerification - 60
        s.recevoir(Self.maillage(maintenant - 150, resolus: [Self.hap: vieille]), a: maintenant - 60)
        #expect(s.verification(Self.hap, a: maintenant) == nil, "resolution trop ancienne")
        s.recevoir(Self.maillage(maintenant - 1100, resolus: [Self.hap: maintenant - 1100]), a: maintenant - 16 * 60)
        #expect(s.verification(Self.hap, a: maintenant) == nil, "maillage perime")
        #expect(s.appareilsAffiches(pour: r).first { $0.id == Self.hap }?.etat == .sansAdresse)
    }

    /// Un disparu demande a la sonde avec sa derniere adresse, et trouve : joignable, a sa place, sans alerte.
    @Test func disparuTrouve() throws {
        let maintenant = Date()
        let s = Self.surveillance(partis: [Self.matter], maintenant: maintenant)
        #expect(s.suivi.disparus[Self.matter] != nil)
        #expect(s.appareilsAResoudre().first { $0.id == Self.matter }
                == AppareilAResoudre(id: Self.matter, partition: Self.partition,
                                     adresse: try #require(AdresseIPv6(Self.adresse(1))),
                                     derniereAnnonce: s.suivi.dernieresAnnonces[Self.matter], disparu: true))
        let r = try #require(s.reseau)
        #expect(s.appareilsAffiches(pour: r).first { $0.id == Self.matter }?.etat == .disparu)
        s.recevoir(Self.maillage(maintenant - 150, resolus: [Self.matter: maintenant - 120]), a: maintenant - 60)
        let affiche = try #require(s.appareilsAffiches(pour: r).first { $0.id == Self.matter })
        #expect(affiche.etat == .joignable && affiche.partition == Self.partition)
        #expect(s.maillageAffiche(pour: r)?.parent(de: Self.matter) == Self.routeur)
        #expect(FicheNoeud.texteEtat(.joignable, disparu: true, verifie: true)
                == String(localized: "joignable, adresse plus annoncée"))
        #expect(FicheNoeud.texteEtat(.joignable, disparu: true, verifie: false) == String(localized: "disparu"))
    }

    /// Une resolution faite avant la perte de l'annonce ne prouve rien (l'appareil annoncait encore son adresse),
    /// egale a la derniere annonce non plus : l'appareil reste « adresse non annoncee » ou « disparu ». Posterieure
    /// a la perte, elle le montre joignable.
    @Test func resolutionAnterieureALaPerte() throws {
        let maintenant = Date()
        let s = Self.surveillance(muets: [Self.hap], partis: [Self.matter], maintenant: maintenant)
        let r = try #require(s.reseau)
        let annonceHap = try #require(s.suivi.dernieresAnnonces[Self.hap])
        let annonceMatter = try #require(s.suivi.dernieresAnnonces[Self.matter])
        #expect(s.appareilsAResoudre().first { $0.id == Self.hap }?.derniereAnnonce == annonceHap)
        #expect(s.appareilsAResoudre().first { $0.id == Self.matter }?.derniereAnnonce == annonceMatter)

        for (hap, matter) in [(annonceHap - 60, annonceMatter - 60), (annonceHap, annonceMatter)] {
            s.recevoir(Self.maillage(maintenant - 150, resolus: [Self.hap: hap, Self.matter: matter], places: false),
                       a: maintenant - 60)
            #expect(s.verification(Self.hap, a: maintenant) == nil)
            #expect(s.verification(Self.matter, a: maintenant) == nil)
            #expect(s.appareilsAffiches(pour: r).first { $0.id == Self.hap }?.etat == .sansAdresse)
            #expect(s.appareilsAffiches(pour: r).first { $0.id == Self.matter }?.etat == .disparu)
            #expect(s.resume?.injoignables == 2)
            let carte = s.maillageAffiche(pour: r)
            #expect(carte?.parent(de: Self.hap) == nil && carte?.parent(de: Self.matter) == nil)
            #expect(carte?.inconnus.isEmpty == true, "pas de noeud fantome sous le routeur")
        }

        let apres = maintenant - 120
        s.recevoir(Self.maillage(maintenant - 150, resolus: [Self.hap: apres, Self.matter: apres]), a: maintenant - 60)
        #expect(s.verification(Self.hap, a: maintenant) == apres)
        #expect(s.verification(Self.matter, a: maintenant) == apres)
        #expect(s.appareilsAffiches(pour: r).first { $0.id == Self.hap }?.etat == .joignable)
        #expect(s.appareilsAffiches(pour: r).first { $0.id == Self.matter }?.etat == .joignable)
        #expect(s.resume?.injoignables == 0)
    }

    /// Les textes dans la langue du lancement des tests (`-testLanguage fr`, puis `en`).
    @Test func textesFrancaisEtAnglais() throws {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let francais = ThreadRouteTests.langue == "fr"
        guard francais || ThreadRouteTests.langue == "en" else {
            throw ThreadRouteTests.ErreurLangue(langue: ThreadRouteTests.langue)
        }
        #expect(FicheNoeud.texteEtat(.sansAdresse, disparu: false, verifie: false)
                == (francais ? "adresse non annoncée" : "address not advertised"))
        #expect(LegendePieces.Entree.sansAdresse.texte
                == (francais ? "adresse non annoncée" : "address not advertised"))
        #expect(FicheNoeud.texteEtat(.sansAdresse, disparu: false, verifie: true)
                == (francais ? "joignable, adresse plus annoncée" : "reachable, address no longer advertised"))
        let verifie = FicheNoeud.texteVerification(t - 600, t)
        #expect(verifie.hasPrefix(francais ? "vérifié par la sonde " : "checked by the probe "))
        #expect(verifie.hasSuffix(FicheNoeud.relatif(t - 600, t)))
        let e = Evenement(date: t, type: .appareilSansAdresse, sujet: Sujet(id: "x", nom: "Prise"))
        #expect(TexteEvenement.titre(e)
                == (francais ? "Prise n'annonce plus d'adresse" : "Prise no longer advertises an address"))
    }
}
