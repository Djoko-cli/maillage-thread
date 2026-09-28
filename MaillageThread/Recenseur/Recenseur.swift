import Foundation
import MaillageCoeur

/// Ecoute le reseau local et produit des releves (`Annonces`) : le premier
/// 10 s apres le demarrage (le temps que les reponses arrivent), puis a chaque
/// changement des services (apres 2 s de calme) et au moins toutes les 60 s.
@MainActor
final class Recenseur {
    enum Etat: Equatable, Sendable {
        case demarrage, actif, reseauLocalRefuse
        case erreur(String)
    }

    static let types = ["_meshcop._udp", "_matter._tcp", "_hap._udp"]
    static let miseEnRoute: Duration = .seconds(10)
    static let calme: Duration = .seconds(2)
    static let periode: Duration = .seconds(60)

    private(set) var etat: Etat = .demarrage
    /// La table de routage a-t-elle pu etre lue au dernier releve (nil : pas encore de releve).
    private(set) var routesLisibles: Bool?
    private(set) var dernierReleve: Annonces?
    var surReleve: ((Annonces) -> Void)?
    var surEtat: ((Etat) -> Void)?

    private var navigateurs: [NavigateurBonjour] = []
    /// "type|instance" -> derniere cible resolue, gardee tant que l'instance est listee.
    private var cibles: [String: ResolveurDNSSD.Cible] = [:]
    private var demarre = false
    private var enRoute = false
    private var releveEnCours = false
    private var releveEnAttente = false
    private var tachePeriodique: Task<Void, Never>?
    private var tacheCalme: Task<Void, Never>?
    /// Demande de resoudre de nouveau toutes les instances listees, consommee au debut du prochain releve.
    private var toutResoudre = false

    func demarrer() {
        guard !demarre else { return }
        demarre = true
        navigateurs = Self.types.map { type in
            let n = NavigateurBonjour(type: type)
            n.surChangement = { [weak self] in self?.changement() }
            n.demarrer()
            return n
        }
        tachePeriodique = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.miseEnRoute)
            while !Task.isCancelled {
                guard let self else { return }
                self.enRoute = true
                await self.releve()
                try? await Task.sleep(for: Self.periode)
            }
        }
    }

    func arreter() {
        tachePeriodique?.cancel()
        tacheCalme?.cancel()
        navigateurs.forEach { $0.arreter() }
        navigateurs = []
        demarre = false
        enRoute = false
    }

    /// Releve immediat (bouton rafraichir, reveil du Mac). Au releve suivant, chaque
    /// instance listee est resolue de nouveau : une reussite remplace sa cible, un
    /// echec garde la precedente. Un releve en cours n'est pas interrompu : celui-ci
    /// le suit. Avant la mise en route, rien n'est lance.
    func rafraichir() {
        toutResoudre = true
        guard enRoute else { return }
        Task { @MainActor [weak self] in await self?.releve() }
    }

    private func changement() {
        mettreAJourEtat()
        guard enRoute else { return }
        tacheCalme?.cancel()
        tacheCalme = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.calme)
            guard !Task.isCancelled else { return }
            await self?.releve()
        }
    }

    private func mettreAJourEtat() {
        let etats = navigateurs.map(\.etat)
        let nouveau: Etat
        if etats.contains(.refuse) {
            nouveau = .reseauLocalRefuse
        } else if let e = etats.lazy.compactMap({ if case .erreur(let m) = $0 { m } else { nil } }).first {
            nouveau = .erreur(e)
        } else if !etats.isEmpty && etats.allSatisfy({ $0 == .pret }) {
            nouveau = .actif
        } else {
            nouveau = .demarrage
        }
        guard nouveau != etat else { return }
        etat = nouveau
        surEtat?(nouveau)
    }

    /// Un releve a la fois ; une demande pendant un releve en relance un apres.
    private func releve() async {
        guard !releveEnCours else {
            releveEnAttente = true
            return
        }
        releveEnCours = true
        repeat {
            releveEnAttente = false
            let a = await faireReleve()
            dernierReleve = a
            surReleve?(a)
        } while releveEnAttente
        releveEnCours = false
    }

    private func faireReleve() async -> Annonces {
        // 1. Instances listees, et leur cible (hote, port) : resolue une fois par
        //    instance, et de nouveau pour toutes apres rafraichir().
        var vues: [InstanceListee] = []
        for n in navigateurs {
            for (instance, txt) in n.instances { vues.append(InstanceListee(type: n.type, instance: instance, txt: txt)) }
        }
        let tout = toutResoudre
        toutResoudre = false
        let aResoudre = vues.filter { tout || cibles[Self.cle($0.type, $0.instance)] == nil }
        let resolues = await withTaskGroup(of: (String, ResolveurDNSSD.Cible?).self) { groupe in
            for v in aResoudre {
                let cle = Self.cle(v.type, v.instance)
                groupe.addTask { (cle, await ResolveurDNSSD.resoudre(instance: v.instance, type: v.type)) }
            }
            var r: [String: ResolveurDNSSD.Cible] = [:]
            for await (cle, cible) in groupe { if let cible { r[cle] = cible } }
            return r
        }
        cibles = Self.retenir(cibles: cibles, resolues: resolues, listees: Set(vues.map { Self.cle($0.type, $0.instance) }))

        // 2. Adresses de chaque hote, a chaque releve.
        let hotes = Set(cibles.values.map(\.hote))
        let adresses = await withTaskGroup(of: (String, [String]).self) { groupe in
            for hote in hotes {
                groupe.addTask { (hote, await ResolveurDNSSD.adresses(hote: hote)) }
            }
            var r: [String: [String]] = [:]
            for await (hote, liste) in groupe { r[hote] = liste }
            return r
        }

        // 3. Routes et prefixes du Mac.
        let routes = TableRoutage.lire()
        routesLisibles = routes != nil

        // 4. Le releve : seules les instances dont la cible est connue y entrent.
        return Self.assembler(vues: vues, cibles: cibles, adresses: adresses, routes: routes ?? [],
                              prefixesLocaux: InterfacesLocales.prefixes(), date: Date())
    }
}
