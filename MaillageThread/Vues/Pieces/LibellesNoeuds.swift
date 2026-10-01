import Foundation
import MaillageCoeur

/// Textes de la vue par pieces : le libelle de chaque noeud (nom, couronne, lune, alerte) et la
/// pastille de sa batterie faible ; les noms des pieces et des etages ; le compte d'une piece ; le
/// texte d'un repere « ailleurs ».
enum LibellesNoeuds {
    /// Libelle d'un noeud : son texte, et la pastille de sa batterie faible.
    struct Libelle: Hashable {
        var texte: String
        var pastille: String?
    }

    /// Nom d'un noeud que seule la sonde connait : « Routeur de bordure · B400 »,
    /// « Routeur · 5000 », « Non identifie · AC05 ». Un routeur de bordure non identifie
    /// montre ses candidats, sous leur nom (`noms`, par instance ; l'instance a defaut) :
    /// « HomePod Avant ou HomePod Palier · 0400 » ; un seul, sans elimination possible :
    /// « HomePod salon ? · 0400 », car ce n'est peut-etre pas lui.
    static func inconnu(_ n: NoeudSonde, noms: [String: String] = [:]) -> String {
        let rloc = String(format: "%04X", n.rloc16)
        switch n.genre {
        case .routeur:
            let candidats = n.candidats.map { noms[$0] ?? $0 }
            if candidats.count > 1 { return String(localized: "\(candidats.formatted(.list(type: .or))) · \(rloc)") }
            if let seul = candidats.first { return String(localized: "\(seul)\u{202F}? · \(rloc)") }
            return n.bordure ? String(localized: "Routeur de bordure · \(rloc)") : String(localized: "Routeur · \(rloc)")
        case .enfant:
            return String(localized: "Non identifié · \(rloc)")
        }
    }

    /// Texte de la pastille d'une batterie faible : son niveau, sinon « faible » ; nil si elle ne
    /// l'est pas.
    static func pastilleBatterie(_ b: BatterieMaison?) -> String? {
        guard let b, b.faible else { return nil }
        return b.niveau.map { String(localized: "\($0)\u{202F}%") } ?? String(localized: "faible")
    }

    /// Noeuds couronnes : le chef de chaque partition (son annonce), et celui du maillage de la sonde.
    static func chefs(reseau: Reseau, maillage: Maillage?, affiche: MaillageAffiche?) -> Set<String> {
        var c = Set(reseau.partitions.compactMap { $0.chef?.instance })
        if let chef = maillage?.chef, let n = affiche?.routeurs[chef.id] { c.insert(n.id) }
        return c
    }

    /// Libelle de chaque noeud : son nom (coupe a 40 caracteres), la couronne du chef, ☾ endormi,
    /// ⚠︎ sans adresse ou disparu ; la pastille d'une batterie faible.
    static func libelles(graphe: GrapheReseau, appareils: [String: AppareilAffiche], nomsRouteurs: [String: String],
                         maillage: MaillageAffiche?, chefs: Set<String>) -> [String: Libelle] {
        func inconnu(_ n: NoeudSonde) -> String { Self.inconnu(n, noms: nomsRouteurs) }
        var libelles: [String: Libelle] = [:]
        for n in graphe.noeuds {
            let a = appareils[n.id]
            let nom = a?.nom ?? nomsRouteurs[n.id] ?? maillage?.noeud(n.id).map(inconnu) ?? n.id
            var texte = CartesPieces.couper(nom)
            if chefs.contains(n.id) { texte += " 👑" }
            if a?.endormi == true { texte += " ☾" }
            if a?.etat == .sansAdresse || a?.etat == .disparu { texte += " ⚠︎" }
            libelles[n.id] = Libelle(texte: texte, pastille: pastilleBatterie(a?.batterie))
        }
        return libelles
    }

    /// Piece de Maison de chaque noeud : celle de son accessoire (appareil), ou, pour un routeur de
    /// bordure, celle de l'accessoire de Maison qui porte le nom de son annonce. Un routeur de bordure
    /// que Maison ne place pas (HomePod, Apple TV) prend la piece choisie pour lui, sinon celle de son
    /// nom (`nomsRouteurs`, par instance ; `PiecesRouteurs`).
    static func pieces(reseau: Reseau, appareils: [AppareilAffiche], maison: NomsMaison?,
                       nomsRouteurs: [String: String] = [:], choix: PiecesRouteurs = PiecesRouteurs()) -> [String: String] {
        var pieces: [String: String] = [:]
        for a in appareils {
            if let p = a.piece, !p.isEmpty { pieces[a.id] = p }
        }
        let toutes = PiecesRouteurs.pieces(de: maison)
        let domicile = maison?.domicile ?? ""
        for r in reseau.routeurs {
            if let p = pieceDeMaison(routeur: r.instance, maison: maison) {
                pieces[r.instance] = p
            } else if let p = choix.piece(routeur: r.instance, nom: nomsRouteurs[r.instance] ?? r.instance, parmi: toutes,
                                          domicile: domicile) {
                pieces[r.instance] = p
            }
        }
        return pieces
    }

    /// Piece de Maison d'un routeur de bordure (son instance) : celle de l'accessoire qui porte son nom.
    static func pieceDeMaison(routeur: String, maison: NomsMaison?) -> String? {
        maison?.accessoires.first { $0.nom == routeur && $0.piece?.isEmpty == false }?.piece
    }

    static func nom(_ e: ScenePieces.NomEtage) -> String {
        switch e {
        case .zone(let n): n
        case .autresPieces: String(localized: "Autres pièces")
        case .maison: String(localized: "Maison")
        }
    }

    static func nom(_ p: ScenePieces.NomPiece, libelles: [String: Libelle]) -> String {
        switch p {
        case .maison(let n): n
        case .routeur(let id): libelles[id]?.texte ?? id
        case .sansPiece: String(localized: "Sans pièce")
        }
    }

    /// « 1 appareil », « 6 appareils ».
    static func compte(_ n: Int) -> String {
        n == 1 ? String(localized: "1 appareil") : String(localized: "\(n) appareils")
    }

    /// Repere « ailleurs » : « ↗ HomePod Palier · Salon », « ↓ … · Salon, Rez-de-chaussée » si le
    /// parent est a un autre etage (sans la couronne du chef).
    static func ailleurs(_ a: Ailleurs, scene: ScenePieces, libelles: [String: Libelle]) -> String {
        let fleche = switch a.sens {
        case .memeEtage: "↗"
        case .dessous: "↓"
        case .dessus: "↑"
        }
        let parent = (libelles[a.parent]?.texte ?? a.parent).replacingOccurrences(of: " 👑", with: "")
        let piece = nom(scene.pieces[a.piece].nom, libelles: libelles)
        guard a.sens != .memeEtage else { return "\(fleche) \(parent) · \(piece)" }
        return "\(fleche) \(parent) · \(piece), \(nom(scene.etages[a.etage].nom))"
    }
}
