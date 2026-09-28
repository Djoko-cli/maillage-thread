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
    /// "type|instance" -> cible resolue.
    private var cibles: [String: ResolveurDNSSD.Cible] = [:]
    private var demarre = false
    private var enRoute = false
    private var releveEnCours = false
    private var releveEnAttente = false
    private var tachePeriodique: Task<Void, Never>?
    private var tacheCalme: Task<Void, Never>?

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

    /// Releve immediat (bouton rafraichir, reveil du Mac) : resout tout a nouveau.
    func rafraichir() {
        cibles = [:]
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
        // 1. Instances vues, et leur cible (hote, port) : resolue une fois par instance.
        var vues: [(type: String, instance: String, txt: Data)] = []
        for n in navigateurs {
            for (instance, txt) in n.instances { vues.append((n.type, instance, txt)) }
        }
        let cles = Set(vues.map { "\($0.type)|\($0.instance)" })
        cibles = cibles.filter { cles.contains($0.key) }
        let aResoudre = vues.filter { cibles["\($0.type)|\($0.instance)"] == nil }.map { ($0.type, $0.instance) }
        let resolues = await withTaskGroup(of: (String, ResolveurDNSSD.Cible?).self) { groupe in
            for (type, instance) in aResoudre {
                groupe.addTask { ("\(type)|\(instance)", await ResolveurDNSSD.resoudre(instance: instance, type: type)) }
            }
            var r: [String: ResolveurDNSSD.Cible] = [:]
            for await (cle, cible) in groupe { if let cible { r[cle] = cible } }
            return r
        }
        cibles.merge(resolues) { _, nouvelle in nouvelle }

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

        func services(_ type: String) -> [AnnonceService] {
            vues.filter { $0.type == type }.map { v in
                let cible = cibles["\(type)|\(v.instance)"]
                let txt = v.txt.isEmpty ? (cible?.txt ?? Data()) : v.txt
                return AnnonceService(instance: v.instance, hote: cible?.hote, port: cible?.port, txt: ChampsTXT(brut: txt))
            }.sorted { $0.instance < $1.instance }
        }
        return Annonces(date: Date(), routeurs: services("_meshcop._udp"), matter: services("_matter._tcp"),
                        hap: services("_hap._udp"), adresses: adresses, routes: routes ?? [],
                        prefixesLocaux: InterfacesLocales.prefixes())
    }
}
