import Foundation
import MaillageCoeur
import Network
import Synchronization
import Testing
@testable import MaillageThread

/// Faux passeur des tests : un client TCP sur 127.0.0.1. Il envoie des octets et ferme son
/// cote, puis attend que l'app ferme la connexion, comme le vrai passeur ; vrai si elle l'a
/// fermee, faux si la connexion a echoue (rien n'ecoute sur ce port).
enum FauxPasseur {
    static func envoyer(_ octets: Data, port: UInt16) async -> Bool {
        guard let p = NWEndpoint.Port(rawValue: port) else { return false }
        let c = NWConnection(host: "127.0.0.1", port: p, using: .tcp)
        let fermee = await withCheckedContinuation { (suite: CheckedContinuation<Bool, Never>) in
            let reprise = Reprise(suite)
            c.stateUpdateHandler = { etat in
                switch etat {
                case .ready:
                    c.send(content: octets, contentContext: .finalMessage, isComplete: true,
                           completion: .contentProcessed { erreur in
                        guard erreur == nil else { return reprise.reprendre(false) }
                        c.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, fin, e in
                            reprise.reprendre(fin || e != nil)
                        }
                    })
                case .waiting, .failed: reprise.reprendre(false)
                default: break
                }
            }
            c.start(queue: .global())
        }
        c.cancel()
        return fermee
    }

    /// Reprend la continuation une seule fois, depuis n'importe quel fil.
    final class Reprise: Sendable {
        private let suite: Mutex<CheckedContinuation<Bool, Never>?>

        init(_ suite: CheckedContinuation<Bool, Never>) {
            self.suite = Mutex(suite)
        }

        func reprendre(_ fermee: Bool) {
            suite.withLock { $0.take() }?.resume(returning: fermee)
        }
    }
}

/// Lancements du passeur demandes par l'app, dans l'ordre (leurs arguments).
final class LancementsPasseur: Sendable {
    private let liste = Mutex<[[String]]>([])

    func noter(_ arguments: [String]) {
        liste.withLock { $0.append(arguments) }
    }

    var tous: [[String]] { liste.withLock { $0 } }
    /// Port et jeton du dernier lancement.
    var cible: EnvoiPasseur.Cible? { tous.last.flatMap { EnvoiPasseur.Cible(arguments: $0) } }
}

@MainActor
@Suite("Noms de Maison : releve du passeur par la boucle locale", .timeLimit(.minutes(1)))
struct NomsInternesTests {
    static let date = Date(timeIntervalSince1970: 1_790_000_000)

    static func noms(_ statut: StatutPasseur = .ok, nom: String = "Halo", message: String? = nil) -> NomsMaison {
        NomsMaison(date: date, statut: statut, message: message,
                   accessoires: statut == .ok ? [AccessoireMaison(nom: nom, noeudMatter: "00000000000002E9")] : [],
                   zones: statut == .ok ? [ZoneMaison(nom: "Étage", pieces: ["Bureau"])] : nil)
    }

    /// `noms.json` dans un dossier temporaire unique, a effacer apres le test.
    static func cache() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("noms-\(UUID().uuidString)")
            .appendingPathComponent(NomsInternes.fichier)
    }

    /// Faux lanceur : note chaque lancement ; puis, comme le passeur, envoie a l'ecoute les
    /// octets que `trame` tire du jeton recu (nil : il ne se connecte pas). `probleme` : le
    /// lancement echoue, rien n'est envoye.
    static func lanceur(_ lancements: LancementsPasseur, probleme: String? = nil,
                        trame: (@Sendable (String) -> Data)? = nil) -> NomsInternes.Lanceur {
        { arguments in
            lancements.noter(arguments)
            if let probleme { return probleme }
            if let trame, let cible = EnvoiPasseur.Cible(arguments: arguments) {
                Task.detached { _ = await FauxPasseur.envoyer(trame(cible.jeton), port: cible.port) }
            }
            return nil
        }
    }

    /// Trame du vrai passeur, avec le jeton recu.
    static func bonneTrame(_ n: NomsMaison) throws -> @Sendable (String) -> Data {
        let json = try n.donnees()
        return { EnvoiPasseur.trame(jeton: $0, json: json) }
    }

    /// Demande un releve et attend sa fin, au plus `delai`.
    static func releve(_ n: NomsInternes, delai: Duration = .seconds(10)) async {
        n.lancerPasseur()
        let fin = ContinuousClock.now + delai
        while n.releveEnCours, ContinuousClock.now < fin { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(!n.releveEnCours, "releve fini")
    }

    /// Textes de l'app, dans la langue de l'hote des tests.
    static let refus = String(localized: "Accès à Maison refusé au passeur : Réglages Système › Confidentialité et sécurité › Maison.")
    static let jetonFaux = String(localized: "Relevé de Maison refusé : jeton faux.")
    static let longueurFausse = String(localized: "Relevé de Maison illisible : longueur fausse.")

    /// Un releve reussi remplace les noms ; un echec du passeur les garde et dit
    /// pourquoi, avec les textes de l'app : le message du passeur (en francais
    /// seulement) n'est que le detail d'une erreur.
    @Test func echecGardeLesNoms() {
        let ancien = Self.noms(nom: "Halo")
        let (garde, probleme) = NomsInternes.retenir(Self.noms(.refuse, message: "Accès refusé"), ancien: ancien)
        #expect(garde == ancien)
        #expect(probleme == Self.refus)
        let (_, indisponible) = NomsInternes.retenir(Self.noms(.indisponible, message: "Capacité absente"), ancien: ancien)
        #expect(indisponible == String(localized: "HomeKit indisponible pour le passeur."))
        let (gardeAussi, erreur) = NomsInternes.retenir(Self.noms(.erreur, message: "Aucun domicile dans Maison"), ancien: ancien)
        #expect(gardeAussi == ancien)
        #expect(erreur == String(localized: "Le passeur a échoué : \("Aucun domicile dans Maison")"))
        let (_, sansDetail) = NomsInternes.retenir(Self.noms(.erreur), ancien: nil)
        #expect(sansDetail == String(localized: "Le passeur a échoué."))
        let (neuf, rien) = NomsInternes.retenir(Self.noms(nom: "Pont"), ancien: ancien)
        #expect(neuf?.accessoires.first?.nom == "Pont")
        #expect(rien == nil)
    }

    /// Au-dela de 7 jours, le profil gratuit du passeur a expire.
    @Test func ancien() {
        #expect(!NomsInternes.estAncien(Self.noms(), maintenant: Self.date + 6 * 86_400))
        #expect(NomsInternes.estAncien(Self.noms(), maintenant: Self.date + 8 * 86_400))
    }

    /// Les noms retenus sont ecrits dans le conteneur et relus au lancement ; un echec ne les
    /// efface pas.
    @Test func memoireDesNoms() throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let n = NomsInternes(cache: cache)
        #expect(n.noms == nil)
        var recus: [NomsMaison?] = []
        n.surNoms = { recus.append($0) }
        n.integrer(Self.noms())
        n.integrer(Self.noms(.refuse, message: "Accès refusé"))
        #expect(n.noms == Self.noms(), "l'echec n'efface pas les noms")
        #expect(n.probleme == Self.refus)
        #expect(recus == [Self.noms()], "un seul changement")
        #expect(NomsInternes(cache: cache).noms == Self.noms(), "relus au lancement")
    }

    /// Relance a l'ouverture du graphe : releve absent ou de plus de 15 min, et
    /// pas de demande dans les 15 dernieres minutes (pas de relance en boucle).
    @Test func aRafraichir() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(NomsInternes.aRafraichir(releve: nil, demande: nil, maintenant: t))
        #expect(!NomsInternes.aRafraichir(releve: t.addingTimeInterval(-14 * 60), demande: nil, maintenant: t))
        #expect(NomsInternes.aRafraichir(releve: t.addingTimeInterval(-16 * 60), demande: nil, maintenant: t))
        #expect(!NomsInternes.aRafraichir(releve: t.addingTimeInterval(-3600), demande: t.addingTimeInterval(-60),
                                          maintenant: t), "demande recente : le passeur ne s'est peut-etre pas lance")
        #expect(NomsInternes.aRafraichir(releve: t.addingTimeInterval(-3600), demande: t.addingTimeInterval(-16 * 60),
                                         maintenant: t))
    }

    /// Sans memoire (demo, tests) : l'ouverture du graphe ne lance jamais le passeur, meme avec
    /// un releve ancien ; le bouton non plus.
    @Test func sansMemoire() {
        let t = Date(timeIntervalSince1970: 1_790_000_000)
        let ancien = t.addingTimeInterval(-3600)
        #expect(NomsInternes.doitRafraichir(memoire: true, releve: ancien, demande: nil, maintenant: t))
        #expect(!NomsInternes.doitRafraichir(memoire: false, releve: ancien, demande: nil, maintenant: t))
        #expect(!NomsInternes.doitRafraichir(memoire: true, releve: t, demande: nil, maintenant: t))
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: nil, lanceur: Self.lanceur(lancements))
        n.rafraichirSiAncien()
        n.lancerPasseur()
        #expect(!n.releveEnCours)
        #expect(lancements.tous.isEmpty)
    }

    /// Un bon jeton : le passeur est lance avec le port de l'ecoute et un jeton de 64 chiffres ;
    /// le releve est retenu, ecrit dans le conteneur et relu au lancement ; l'ecoute est fermee.
    @Test func bonJeton() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(lancements, trame: try Self.bonneTrame(Self.noms())))
        var recus: [NomsMaison?] = []
        n.surNoms = { recus.append($0) }
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == nil)
        #expect(recus == [Self.noms()])
        #expect(try NomsMaison.lire(Data(contentsOf: cache)) == Self.noms(), "ecrit dans le conteneur")
        #expect(NomsInternes(cache: cache).noms == Self.noms(), "relu au lancement")
        let cible = try #require(lancements.cible)
        #expect(lancements.tous.count == 1)
        #expect(cible.jeton.count == 64)
        #expect(await !FauxPasseur.envoyer(Data("encore".utf8), port: cible.port), "ecoute fermee")
    }

    /// Le passeur a pu lire Maison, mais l'acces lui est refuse : les noms gardes restent.
    @Test func refusDeMaison() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(LancementsPasseur(),
                                                                trame: try Self.bonneTrame(Self.noms(.refuse, message: "Accès refusé"))))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == Self.refus)
    }

    /// Un mauvais jeton : rien n'est retenu ni ecrit, le dernier releve valide reste.
    @Test func mauvaisJeton() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let json = try Self.noms(nom: "Intrus").donnees()
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(LancementsPasseur(), trame: { jeton in
            EnvoiPasseur.trame(jeton: String(jeton.reversed()), json: json)
        }))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == Self.jetonFaux)
        #expect(try NomsMaison.lire(Data(contentsOf: cache)) == Self.noms(), "fichier inchange")
    }

    /// Une longueur fausse (illisible, au-dela de 8 Mo, ou plus longue que la trame) : le
    /// dernier releve valide reste.
    @Test func longueurFausse() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let json = try Self.noms(nom: "Intrus").donnees()
        for longueur in ["abc", String(EnvoiPasseur.tailleMax + 1), String(json.count + 10)] {
            let n = NomsInternes(cache: cache, lanceur: Self.lanceur(LancementsPasseur(), trame: { jeton in
                Data("\(jeton)\n\(longueur)\n".utf8) + json
            }))
            n.integrer(Self.noms())
            await Self.releve(n)
            #expect(n.noms == Self.noms(), "longueur \(longueur)")
            #expect(n.probleme == Self.longueurFausse, "longueur \(longueur)")
        }
    }

    /// Un JSON illisible : le dernier releve valide reste, et le detail est dit.
    @Test func jsonIllisible() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(LancementsPasseur(), trame: { jeton in
            EnvoiPasseur.trame(jeton: jeton, json: Data("pas du json".utf8))
        }))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        let debut = String(localized: "Relevé de Maison illisible : \("")")
        #expect(n.probleme?.hasPrefix(debut) == true && n.probleme != Self.longueurFausse, "\(n.probleme ?? "")")
    }

    /// Rien dans le delai (le passeur ne se connecte pas) : le dernier releve valide reste, et
    /// l'ecoute est fermee. (Delai d'une seconde : l'ecoute est prete bien avant.)
    @Test func delaiDepasse() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: cache, delai: .seconds(1), lanceur: Self.lanceur(lancements))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == String(localized: "Passeur Noms n'a rien envoyé en 2 minutes."))
        let cible = try #require(lancements.cible)
        #expect(await !FauxPasseur.envoyer(try Self.bonneTrame(Self.noms(nom: "Tard"))(cible.jeton), port: cible.port),
                "ecoute fermee")
        #expect(n.noms == Self.noms())
    }

    /// Passeur introuvable, ou lancement refuse : le probleme est dit, l'ecoute fermee, les noms gardes.
    @Test func lancementRefuse() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let introuvable = String(localized: "Passeur Noms introuvable : lance outils/passeur.sh.")
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(lancements, probleme: introuvable))
        n.integrer(Self.noms())
        await Self.releve(n)
        #expect(n.noms == Self.noms())
        #expect(n.probleme == introuvable)
        let cible = try #require(lancements.cible)
        #expect(await !FauxPasseur.envoyer(Data("x".utf8), port: cible.port), "ecoute fermee")
    }

    /// Une seule ecoute a la fois : une demande pendant un releve est ignoree ; une fois le
    /// releve fini, une autre demande lance de nouveau le passeur, avec un autre jeton.
    @Test func uneSeuleEcoute() async throws {
        let cache = Self.cache()
        defer { try? FileManager.default.removeItem(at: cache.deletingLastPathComponent()) }
        let lancements = LancementsPasseur()
        let n = NomsInternes(cache: cache, lanceur: Self.lanceur(lancements))
        n.lancerPasseur()
        let premiere = n.derniereDemande
        let fin = ContinuousClock.now + .seconds(10)
        while lancements.tous.isEmpty, ContinuousClock.now < fin { try? await Task.sleep(for: .milliseconds(5)) }
        n.lancerPasseur()
        n.rafraichirSiAncien(maintenant: .now + 3600)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(lancements.tous.count == 1, "demandes ignorees pendant le releve")
        #expect(n.derniereDemande == premiere)
        let cible = try #require(lancements.cible)
        #expect(await FauxPasseur.envoyer(try Self.bonneTrame(Self.noms())(cible.jeton), port: cible.port))
        #expect(!n.releveEnCours)
        #expect(n.noms == Self.noms())
        n.lancerPasseur()
        #expect(n.releveEnCours)
        while lancements.tous.count < 2, ContinuousClock.now < fin { try? await Task.sleep(for: .milliseconds(5)) }
        let seconde = try #require(lancements.cible)
        #expect(seconde.jeton != cible.jeton, "jeton a usage unique")
        #expect(await FauxPasseur.envoyer(try Self.bonneTrame(Self.noms(nom: "Pont"))(seconde.jeton), port: seconde.port))
        #expect(n.noms == Self.noms(nom: "Pont"))
    }

    /// Reglages › Noms de Maison : les zones lues, dans l'ordre de Maison.
    @Test func zonesDansLesReglages() {
        #expect(FenetreReglages.texteZones([ZoneMaison(nom: "Rez-de-chaussée"), ZoneMaison(nom: "Étage")])
                == "Rez-de-chaussée, Étage")
        #expect(FenetreReglages.texteZones([]) == String(localized: "aucune zone dans Maison"))
    }
}
