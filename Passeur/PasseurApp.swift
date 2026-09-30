import HomeKit
import Network
import os
import SwiftUI

/// Passeur des noms de Maison : app iOS lancee sur le Mac (« concue pour
/// iPad »), seule forme qui ait HomeKit avec une equipe gratuite. Elle lit
/// Maison (noms, pieces, zones, batteries). Lancee par Maillage Thread avec
/// `--port` et `--jeton`, elle lui envoie le releve par la boucle locale du Mac
/// (TCP sur 127.0.0.1, `EnvoiPasseur`), puis se ferme aussitot. Ouverte a la
/// main, elle n'envoie rien : elle montre ce qu'elle a lu, puis se ferme apres 10 s.
/// Chaque lancement et chaque sortie laissent une trace au journal du Mac (`quitter`).
@main
struct PasseurApp: App {
    @State private var passeur = Passeur(cible: EnvoiPasseur.Cible(arguments: ProcessInfo.processInfo.arguments))

    var body: some Scene {
        WindowGroup {
            VuePasseur()
                .environment(passeur)
        }
    }
}

struct VuePasseur: View {
    @Environment(Passeur.self) private var passeur

    var body: some View {
        VStack(spacing: 16) {
            Text("Passeur Noms").font(.title2.bold())
            Text(passeur.etat).multilineTextAlignment(.center)
            if let n = passeur.fermetureDans {
                Text("Fermeture dans \(n) s").font(.caption).foregroundStyle(.secondary)
            }
            Text("Maillage Thread lance Passeur Noms quand il lui faut les noms de Maison : le relevé lui arrive par la boucle locale du Mac, sans dossier. Rien ne sort de ce Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(minWidth: 420)
        .task { passeur.demarrer() }
    }
}

@MainActor
@Observable
final class Passeur: NSObject, HMHomeManagerDelegate {
    private(set) var etat = "Lecture de Maison…"
    /// Ouvert a la main : secondes avant la fermeture, apres le releve.
    private(set) var fermetureDans: Int?
    /// Ou envoyer le releve : donne par Maillage Thread ; nil ouvert a la main.
    @ObservationIgnored private let cible: EnvoiPasseur.Cible?
    @ObservationIgnored private var gestionnaire: HMHomeManager?
    /// Un releve est parti (envoye, ou montre) : un seul par lancement.
    @ObservationIgnored private var livre = false
    /// Maison a donne ses domiciles : avant `homeManagerDidUpdateHomes`, la
    /// liste est vide (HMHomeManager.h).
    @ObservationIgnored private var maisonChargee = false
    /// Delai de secours : sans reponse de Maison, le dire plutot qu'attendre sans fin. Assez
    /// long pour la demande d'acces du premier lancement, plus court que l'attente de l'app (120 s).
    static let delaiMaison: Duration = .seconds(100)
    /// Lectures des batteries : Maison repond depuis son cache (0,2 s pour 78
    /// valeurs le 28/09) ; au-dela, le releve part avec les valeurs deja connues.
    static let delaiLectures: Duration = .seconds(5)
    /// Envoi a l'app, au plus : le passeur se ferme ensuite quoi qu'il arrive.
    static let delaiEnvoi: Duration = .seconds(10)
    /// Lectures en cours : a la fin, `apresLectures` livre le releve.
    @ObservationIgnored private var cycle = 0
    @ObservationIgnored private var lecturesRestantes = 0
    @ObservationIgnored private var apresLectures: (@MainActor () -> Void)?

    init(cible: EnvoiPasseur.Cible?) {
        self.cible = cible
        super.init()
    }

    func demarrer() {
        guard gestionnaire == nil else { return }
        // Premiere trace du lancement : la cible est-elle arrivee ? Le port seulement, jamais le jeton.
        // Sans cible, le nombre d'arguments dit si ceux du lancement ne sont pas arrives (1 : le
        // chemin de l'executable seul) ou s'ils sont arrives sans etre lisibles (plus de 1).
        if let cible {
            journal.notice("démarrage : cible reçue, port \(cible.port)")
        } else {
            journal.notice("démarrage : aucune cible (arguments de lancement : \(ProcessInfo.processInfo.arguments.count))")
        }
        let g = HMHomeManager()
        g.delegate = self
        gestionnaire = g
        Task { [weak self] in
            try? await Task.sleep(for: Self.delaiMaison)
            // Rien de livre, ni lecture en cours : Maison n'a pas repondu.
            guard let self, !self.livre, self.apresLectures == nil else { return }
            self.livrer(NomsMaison(date: .now, statut: .erreur, message: "Maison n'a pas répondu"))
        }
    }

    // HomeKit ne dit pas sur quel fil il appelle son delegue : passer par l'acteur principal.
    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.maisonChargee = true
            self.relever(manager)
        }
    }

    nonisolated func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        Task { @MainActor in self.autorisation(status) }
    }

    /// Acces refuse : releve « refuse ». Acces accorde : releve, des que Maison
    /// a donne ses domiciles (sinon `homeManagerDidUpdateHomes` le fera). L'ordre
    /// des deux rappels ne compte pas.
    private func autorisation(_ s: HMHomeManagerAuthorizationStatus) {
        if s.contains(.authorized) {
            if maisonChargee, let g = gestionnaire { relever(g) }
        } else if s.contains(.determined) {
            livrer(NomsMaison(date: .now, statut: .refuse,
                              message: "Accès à Maison refusé : Réglages Système › Confidentialité et sécurité › Maison."))
        }
    }

    private func relever(_ manager: HMHomeManager) {
        guard manager.authorizationStatus.contains(.authorized) else {
            // Au relancement apres un refus, le statut peut ne jamais etre annonce comme un changement.
            autorisation(manager.authorizationStatus)
            return
        }
        guard !manager.homes.isEmpty else {
            // Jamais un « ok » vide : il effacerait les noms gardes par l'app.
            livrer(NomsMaison(date: .now, statut: .erreur, message: "Aucun domicile dans Maison"))
            return
        }
        // Un releve a la fois : les deux rappels de HomeKit peuvent arriver pendant les lectures.
        guard apresLectures == nil, !livre else { return }
        let caracteristiques = manager.homes.flatMap(\.accessories).compactMap(Self.batterie)
            .flatMap { [$0.niveau, $0.charge, $0.alerte].compactMap { $0 } }
        lire(caracteristiques) { self.livrerReleve(manager) }
    }

    private func livrerReleve(_ manager: HMHomeManager) {
        let accessoires = manager.homes.flatMap(\.accessories).map { a in
            let b = Self.batterie(a)
            return AccessoireMaison(nom: a.name, piece: a.room?.name, fabricant: a.manufacturer, modele: a.model,
                                    firmware: a.firmwareVersion, categorie: a.category.localizedDescription,
                                    noeudMatter: AccessoireMaison.noeud(a.matterNodeID),
                                    pont: a.category.categoryType == HMAccessoryCategoryTypeBridge ? true : nil,
                                    batterie: b.flatMap {
                                        BatterieMaison.depuisHomeKit(niveau: $0.niveau?.value, charge: $0.charge?.value,
                                                                     alerte: $0.alerte?.value)
                                    })
        }.sorted { $0.nom < $1.nom }
        // Zones et pieces dans l'ordre de Maison.
        let zones = manager.homes.flatMap(\.zones).map { ZoneMaison(nom: $0.name, pieces: $0.rooms.map(\.name)) }
        let domicile = manager.homes.map(\.name).joined(separator: " + ")
        livrer(NomsMaison(date: .now, statut: .ok, domicile: domicile.isEmpty ? nil : domicile,
                          accessoires: accessoires, zones: zones))
    }

    /// Service Batterie d'un accessoire : niveau, etat de charge, alerte.
    private static func batterie(_ a: HMAccessory)
        -> (niveau: HMCharacteristic?, charge: HMCharacteristic?, alerte: HMCharacteristic?)? {
        guard let s = a.services.first(where: { $0.serviceType == HMServiceTypeBattery }) else { return nil }
        func c(_ type: String) -> HMCharacteristic? { s.characteristics.first { $0.characteristicType == type } }
        return (c(HMCharacteristicTypeBatteryLevel), c(HMCharacteristicTypeChargingState),
                c(HMCharacteristicTypeStatusLowBattery))
    }

    /// Lit les valeurs, puis appelle `fin` une fois : a la derniere lecture ou au
    /// delai. (Appels a rappel hors d'une fonction async : pas d'avertissement.)
    private func lire(_ caracteristiques: [HMCharacteristic], puis fin: @escaping @MainActor () -> Void) {
        cycle += 1
        let n = cycle
        apresLectures = fin
        lecturesRestantes = caracteristiques.count
        for c in caracteristiques {
            c.readValue { @Sendable _ in
                Task { @MainActor in self.lectureFinie(n) }
            }
        }
        Task {
            try? await Task.sleep(for: Self.delaiLectures)
            self.terminerLectures(n)
        }
        if caracteristiques.isEmpty { terminerLectures(n) }
    }

    private func lectureFinie(_ n: Int) {
        guard n == cycle else { return }
        lecturesRestantes -= 1
        if lecturesRestantes == 0 { terminerLectures(n) }
    }

    private func terminerLectures(_ n: Int) {
        guard n == cycle, let fin = apresLectures else { return }
        apresLectures = nil
        fin()
    }

    /// Livre le releve, une fois : a Maillage Thread, puis fermeture ; ouvert a la main, il le
    /// montre, sans rien envoyer, et se ferme 10 s plus tard.
    private func livrer(_ n: NomsMaison) {
        guard !livre else { return }
        livre = true
        guard let cible else {
            etat = n.statut == .ok
                ? "\(n.accessoires.count) accessoires et \(n.zones?.count ?? 0) zones lus dans Maison. Ouvert à la main, Passeur Noms n'envoie rien : Maillage Thread le lance lui-même."
                : (n.message ?? "Accès à Maison refusé.")
            fermerApres(secondes: 10)
            return
        }
        etat = "Envoi à Maillage Thread…"
        let json: Data
        do {
            json = try n.donnees()
        } catch {
            quitter("relevé impossible à encoder, rien envoyé", erreur: error)
        }
        Self.envoyer(EnvoiPasseur.trame(jeton: cible.jeton, json: json), port: cible.port)
    }

    /// Envoie la trame a 127.0.0.1:<port> et ferme son cote, attend que l'app ferme la
    /// connexion (elle a tout lu), puis quitte. L'app injoignable (ecoute deja fermee) : quitte
    /// aussi. Jamais plus de `delaiEnvoi` : un passeur qui resterait ouvert ne recevrait pas les
    /// arguments du lancement suivant. Chaque sortie passe par `quitter`, qui dit pourquoi.
    private static func envoyer(_ trame: Data, port: UInt16) {
        guard let p = NWEndpoint.Port(rawValue: port) else { quitter("port \(port) invalide", echec: true) }
        let c = NWConnection(host: "127.0.0.1", port: p, using: .tcp)
        c.stateUpdateHandler = { etat in
            switch etat {
            case .ready:
                c.send(content: trame, contentContext: .finalMessage, isComplete: true,
                       completion: .contentProcessed { erreur in
                    if let erreur { quitter("envoi de la trame impossible", erreur: erreur) }
                    c.receive(minimumIncompleteLength: 1, maximumLength: 1) { _, _, _, erreur in
                        if let erreur { quitter("connexion coupée après l'envoi", erreur: erreur) }
                        quitter("l'app a fermé la connexion après l'envoi")
                    }
                })
            case .waiting(let erreur):
                quitter("connexion au port \(port) impossible (en attente)", erreur: erreur)
            case .failed(let erreur):
                quitter("connexion au port \(port) échouée", erreur: erreur)
            default:
                break
            }
        }
        c.start(queue: .main)
        Task {
            try? await Task.sleep(for: delaiEnvoi)
            quitter("délai de \(delaiEnvoi.components.seconds) s dépassé, connexion : \(c.state)", echec: true)
        }
    }

    /// Ouvert a la main : fermeture apres un compte a rebours.
    private func fermerApres(secondes: Int) {
        Task { [weak self] in
            for n in stride(from: secondes, to: 0, by: -1) {
                self?.fermetureDans = n
                try? await Task.sleep(for: .seconds(1))
            }
            quitter("ouvert à la main : relevé montré, rien envoyé")
        }
    }
}

/// Journal du passeur, a lire apres coup avec
/// `/usr/bin/log show --last 10m --predicate 'subsystem == "fr.djoko.maillage.passeur"'`
/// (en zsh, `log` seul est une commande interne : donner le chemin complet).
/// Jamais le jeton, jamais de donnees de Maison : des raisons et des erreurs de reseau seulement.
private let journal = Logger(subsystem: "fr.djoko.maillage.passeur", category: "releve")

/// Seule sortie du passeur : la raison au journal, puis `exit(0)` (l'app n'attend aucun code de
/// retour). Fin normale en `.notice` ; echec en `.error`, avec l'erreur (celle de Network par
/// exemple) quand il y en a une. Sans cette trace, un echec (connexion refusee, delai) ressemble
/// a une fin normale : l'app ne voit que l'absence de releve. `privacy: .public` est necessaire :
/// sinon le journal masque les chaines (`<private>`).
private func quitter(_ raison: String, erreur: (any Error)? = nil, echec: Bool = false) -> Never {
    if let erreur {
        journal.error("échec : \(raison, privacy: .public) ; erreur : \(String(describing: erreur), privacy: .public)")
    } else if echec {
        journal.error("échec : \(raison, privacy: .public)")
    } else {
        journal.notice("fin : \(raison, privacy: .public)")
    }
    exit(0)
}
