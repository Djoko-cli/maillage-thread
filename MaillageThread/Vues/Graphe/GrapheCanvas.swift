import MaillageCoeur
import SwiftUI

/// Dessin du graphe : zones des partitions, liens (ceux de la sonde en traits
/// pleins colores et epaissis par la qualite, sinon des pointilles vers le centre
/// de la zone : rattachement, pas un lien radio), routeurs et appareils, et leurs
/// libelles, chacun dans la place calculee par `PlacementLibelles` (la meme que
/// pour le clic) ; un libelle ecarte est relie a son point par un trait fin.
struct GrapheCanvas: View {
    let disposition: Disposition
    /// Identifiant -> appareil affiche (etat, nom).
    let appareils: [String: AppareilAffiche]
    /// Instance -> nom affiche du routeur.
    let nomsRouteurs: [String: String]
    /// Maillage de la sonde : noms des noeuds qu'elle seule connait.
    var maillage: MaillageAffiche?
    /// Texte et pastille du libelle de chaque noeud (`libelles(...)`).
    let libelles: [String: Libelle]
    /// Place de chaque libelle, en coordonnees de la vue.
    let placement: PlacementLibelles
    let projection: Projection
    let selection: String?
    let survol: String?
    let palette: Palette

    /// Couches du dessin.
    enum Couche: CaseIterable {
        case zones, liens, traits, titres, points, fonds, selection, libelles
    }

    /// Ordre du dessin, de la couche la plus basse a la plus haute : les fonds des libelles et
    /// les titres des zones passent sur les liens et les traits (aucun ne barre un texte) ; les
    /// fonds, les titres et les traits sous les points (un fond ne rogne pas le halo d'un
    /// point) ; l'anneau de selection sur les fonds ; les libelles au-dessus de tout.
    static let couches: [Couche] = [.zones, .liens, .traits, .fonds, .titres, .points, .selection, .libelles]

    var body: some View {
        Canvas { ctx, _ in
            for c in Self.couches {
                switch c {
                case .zones: dessinerZones(&ctx)
                case .liens: dessinerLiens(&ctx)
                case .traits: dessinerTraits(&ctx)
                case .titres: dessinerTitres(&ctx)
                case .points: dessinerPoints(&ctx)
                case .fonds: dessinerFonds(&ctx)
                case .selection: dessinerSelection(&ctx)
                case .libelles: dessinerLibelles(&ctx)
                }
            }
        }
    }

    private func dessinerZones(_ ctx: inout GraphicsContext) {
        for z in disposition.zones {
            let c = projection.vue(z.centre)
            let r = z.rayon * projection.echelle
            let cercle = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            let couleur = palette.zone(z)
            if z.id.isEmpty {
                ctx.stroke(cercle, with: .color(couleur.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            } else {
                ctx.fill(cercle, with: .radialGradient(Gradient(colors: [couleur.opacity(0.26), couleur.opacity(0.08)]),
                                                       center: c, startRadius: 0, endRadius: r))
                ctx.stroke(cercle, with: .color(couleur.opacity(0.45)), lineWidth: 1)
            }
        }
    }

    private func dessinerLiens(_ ctx: inout GraphicsContext) {
        let positions = Dictionary(disposition.noeuds.map { ($0.id, $0.position) }, uniquingKeysWith: { a, _ in a })
        // Rattachements dessous, puis enfant-parent, puis liens radio.
        let ordre: [Disposition.Lien.Genre] = [.rattachement, .parent, .radio]
        for l in disposition.liens.sorted(by: { ordre.firstIndex(of: $0.genre)! < ordre.firstIndex(of: $1.genre)! }) {
            guard let a = positions[l.de], let b = positions[l.vers] else { continue }
            var p = Path()
            p.move(to: projection.vue(a))
            p.addLine(to: projection.vue(b))
            switch l.genre {
            case .rattachement:
                let eclaire = l.de == selection || l.de == survol
                ctx.stroke(p, with: .color(eclaire ? palette.lienEclaire : palette.lien),
                           style: StrokeStyle(lineWidth: eclaire ? 1.6 : 1, dash: [2, 4]))
            case .radio, .parent:
                let eclaire = [l.de, l.vers].contains { $0 == selection || $0 == survol }
                let epaisseur = Self.epaisseurLienSonde(l.genre, qualite: l.qualite)
                ctx.stroke(p, with: .color(palette.lienSonde(l.qualite).opacity(eclaire ? 1 : 0.75)),
                           style: StrokeStyle(lineWidth: eclaire ? epaisseur + 1.2 : epaisseur, lineCap: .round))
            }
        }
    }

    /// Titre de chaque zone, sur un fond discret comme les libelles : par-dessus les liens et
    /// les traits (aucun ne le barre), sous les points (aucun n'est cache). Dans l'obstacle
    /// que les libelles evitent (`MemoirePlacement`).
    private func dessinerTitres(_ ctx: inout GraphicsContext) {
        for z in disposition.zones {
            let a = Self.ancreTitre(centre: projection.vue(z.centre), rayon: z.rayon * projection.echelle)
            let resolu = ctx.resolve(Self.texteTitre(Self.titre(z)).foregroundStyle(palette.zone(z).opacity(0.95)))
            let t = resolu.measure(in: Self.propositionTexte)
            let fond = CGRect(x: a.x - t.width / 2, y: a.y - t.height, width: t.width, height: t.height)
                .insetBy(dx: -PlacementLibelles.margeFond.width, dy: -PlacementLibelles.margeFond.height)
            ctx.fill(Path(roundedRect: fond, cornerRadius: PlacementLibelles.rayonFond, style: .circular),
                     with: .color(palette.fondLibelle))
            ctx.draw(resolu, at: a, anchor: .bottom)
        }
    }

    /// Trait fin de chaque libelle ecarte, du bord de son point au bord du libelle.
    private func dessinerTraits(_ ctx: inout GraphicsContext) {
        for n in placement.noeuds {
            guard let t = placement.places[n.id]?.trait else { continue }
            var p = Path()
            p.move(to: t.depart)
            p.addLine(to: t.arrivee)
            ctx.stroke(p, with: .color(palette.texteDiscret.opacity(0.8)), lineWidth: 0.75)
        }
    }

    private func dessinerPoints(_ ctx: inout GraphicsContext) {
        let principales = Set(disposition.zones.filter(\.principale).map(\.id))
        for n in disposition.noeuds {
            let c = projection.vue(n.position)
            let r = Self.rayonPoint(n.rayon, echelle: projection.echelle)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            switch n.genre {
            case .centre, .routeur:
                let inconnu = nomsRouteurs[n.id] == nil && maillage?.noeud(n.id) != nil
                let couleur = inconnu ? palette.routeurInconnu : palette.routeur(principale: principales.contains(n.zone))
                ctx.drawLayer { l in
                    l.addFilter(.shadow(color: couleur.opacity(0.8), radius: n.genre == .centre ? 10 : 5))
                    l.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [.white.opacity(0.9), couleur]),
                                                                        center: CGPoint(x: c.x - r / 3, y: c.y - r / 3),
                                                                        startRadius: 0, endRadius: r * 1.3))
                }
            case .appareil:
                let a = appareils[n.id]
                let couleur = palette.appareil(a?.etat ?? .inconnu)
                if a?.etat == .disparu {
                    ctx.stroke(Path(ellipseIn: rect), with: .color(couleur), lineWidth: 2)
                } else {
                    ctx.drawLayer { l in
                        l.addFilter(.shadow(color: couleur.opacity(0.8), radius: 4))
                        l.fill(Path(ellipseIn: rect), with: .color(couleur))
                    }
                }
            }
        }
    }

    /// Fond discret de chaque libelle (texte et pastille), coins arrondis : dessine apres
    /// les liens et les traits, il les cache sous le texte ; avant les points, il ne rogne
    /// pas leurs halos.
    private func dessinerFonds(_ ctx: inout GraphicsContext) {
        for n in placement.noeuds {
            guard let f = placement.places[n.id]?.fond else { continue }
            ctx.fill(Path(roundedRect: f, cornerRadius: PlacementLibelles.rayonFond, style: .circular),
                     with: .color(palette.fondLibelle))
        }
    }

    /// Anneau du noeud selectionne : sur les fonds (aucun ne le cache), sous les libelles.
    private func dessinerSelection(_ ctx: inout GraphicsContext) {
        for n in disposition.noeuds where n.id == selection {
            let c = projection.vue(n.position)
            let r = Self.rayonPoint(n.rayon, echelle: projection.echelle) + 4
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                       with: .color(palette.selection), lineWidth: 2)
        }
    }

    /// Libelles, au-dessus de tout : aucun ne recoupe un point ni un autre libelle.
    private func dessinerLibelles(_ ctx: inout GraphicsContext) {
        for n in placement.noeuds {
            guard let place = placement.places[n.id], let l = libelles[n.id] else { continue }
            dessinerLibelle(&ctx, l, place, genre: n.genre, fort: n.id == selection || n.id == survol)
        }
    }

    /// Texte dans sa place, contre le cote du point : hors survol, en graisse normale, il
    /// est un peu plus court que la place (reservee en semi-gras). La pastille suit le
    /// texte, du cote oppose au point ; elle reste dans le cadre du libelle.
    private func dessinerLibelle(_ ctx: inout GraphicsContext, _ l: Libelle, _ place: PlacementLibelles.Place,
                                 genre: Disposition.Genre, fort: Bool) {
        let resolu = ctx.resolve(Self.texteLibelle(l.texte, genre: genre, fort: fort)
            .foregroundStyle(fort ? palette.selection : palette.texte))
        let t = resolu.measure(in: Self.propositionTexte)
        let r = place.texte
        let ecart = PlacementLibelles.ecartPastille
        switch place.sens {
        case .droite:
            ctx.draw(resolu, at: CGPoint(x: r.minX, y: r.midY), anchor: .leading)
            if let p = l.pastille {
                dessinerPastille(&ctx, p, at: CGPoint(x: r.minX + t.width + ecart.cote, y: r.midY), anchor: .leading)
            }
        case .gauche:
            ctx.draw(resolu, at: CGPoint(x: r.maxX, y: r.midY), anchor: .trailing)
            if let p = l.pastille {
                dessinerPastille(&ctx, p, at: CGPoint(x: r.maxX - t.width - ecart.cote, y: r.midY), anchor: .trailing)
            }
        case .dessus:
            ctx.draw(resolu, at: CGPoint(x: r.midX, y: r.maxY), anchor: .bottom)
            if let p = l.pastille {
                dessinerPastille(&ctx, p, at: CGPoint(x: r.midX, y: r.maxY - t.height - ecart.dessus), anchor: .bottom)
            }
        case .dessous:
            ctx.draw(resolu, at: CGPoint(x: r.midX, y: r.minY), anchor: .top)
            if let p = l.pastille {
                dessinerPastille(&ctx, p, at: CGPoint(x: r.midX, y: r.minY + t.height + ecart.dessus), anchor: .top)
            }
        }
    }

    /// Epaisseur (pt) d'un lien de la sonde. Le lien radio s'epaissit avec la qualite : 3 pt
    /// pour 3, 2,2 pt pour 2, 1,4 pt pour 1 ou inconnue (nil ou 0). La couleur seule ne
    /// suffit pas : vert et orange se distinguent mal en daltonisme rouge-vert. De l'enfant a
    /// son parent : 1 pt, quelle que soit la qualite. (Le survol y ajoute 1,2 pt.)
    static func epaisseurLienSonde(_ genre: Disposition.Lien.Genre, qualite: Int?) -> CGFloat {
        switch genre {
        case .radio:
            switch Palette.NiveauLien(qualite) {
            case .bon: 3
            case .moyen: 2.2
            case .faible, .inconnu: 1.4
            }
        case .parent, .rattachement:
            1
        }
    }

    /// Nom d'un noeud que seule la sonde connait : « Routeur de bordure · B400 »,
    /// « Routeur · 5000 », « Non identifié · AC05 ».
    static func libelleInconnu(_ n: NoeudSonde) -> String {
        let rloc = String(format: "%04X", n.rloc16)
        switch n.genre {
        case .routeur:
            return n.bordure ? String(localized: "Routeur de bordure · \(rloc)") : String(localized: "Routeur · \(rloc)")
        case .enfant:
            return String(localized: "Non identifié · \(rloc)")
        }
    }

    /// Texte de la pastille d'une batterie faible : son niveau, sinon « faible » ;
    /// nil si elle ne l'est pas.
    static func pastilleBatterie(_ b: BatterieMaison?) -> String? {
        guard let b, b.faible else { return nil }
        return b.niveau.map { String(localized: "\($0)\u{202F}%") } ?? String(localized: "faible")
    }

    /// Pastille orange en surbrillance : petit triangle et texte, dans une capsule
    /// qui luit. (Triangle et texte sont dessines a part : `Text + Text` est
    /// deprecie, et une interpolation ferait une cle de traduction.)
    private func dessinerPastille(_ ctx: inout GraphicsContext, _ texte: String, at p: CGPoint, anchor: UnitPoint) {
        let icone = ctx.resolve(Self.iconePastille.foregroundStyle(palette.texteBatterieFaible))
        let valeur = ctx.resolve(Self.textePastille(texte).foregroundStyle(palette.texteBatterieFaible))
        let ti = icone.measure(in: Self.propositionTexte)
        let tv = valeur.measure(in: Self.propositionTexte)
        let taille = Self.taillePastille(icone: ti, valeur: tv)
        let cadre = CGRect(origin: CGPoint(x: p.x - anchor.x * taille.width, y: p.y - anchor.y * taille.height),
                           size: taille)
        let capsule = Path(roundedRect: cadre, cornerRadius: taille.height / 2)
        ctx.drawLayer { l in
            l.addFilter(.shadow(color: palette.batterieFaible.opacity(0.9), radius: 6))
            l.fill(capsule, with: .color(palette.batterieFaible))
        }
        ctx.draw(icone, at: CGPoint(x: cadre.minX + 6, y: cadre.midY), anchor: .leading)
        ctx.draw(valeur, at: CGPoint(x: cadre.minX + 6 + ti.width + 3, y: cadre.midY), anchor: .leading)
    }
}

extension GrapheCanvas {
    /// Libelle d'un noeud : son texte, et la pastille de sa batterie faible.
    struct Libelle: Equatable {
        var texte: String
        var pastille: String?
    }

    /// Place proposee pour mesurer un texte d'une ligne.
    static let propositionTexte = CGSize(width: 10_000, height: 10_000)

    /// Libelle de chaque noeud : nom (routeur couronne s'il est chef), ☾ endormi,
    /// ⚠︎ sans adresse ou disparu ; pastille d'une batterie faible.
    static func libelles(disposition: Disposition, reseau: Reseau, appareils: [String: AppareilAffiche],
                         nomsRouteurs: [String: String], maillage: MaillageAffiche?) -> [String: Libelle] {
        let chefs = Set(reseau.partitions.compactMap { $0.chef?.instance })
        var libelles: [String: Libelle] = [:]
        for n in disposition.noeuds where libelles[n.id] == nil {
            switch n.genre {
            case .centre, .routeur:
                var texte = nomsRouteurs[n.id] ?? maillage?.noeud(n.id).map(libelleInconnu) ?? n.id
                if chefs.contains(n.id) { texte += " 👑" }
                libelles[n.id] = Libelle(texte: texte)
            case .appareil:
                let a = appareils[n.id]
                var texte = a?.nom ?? maillage?.noeud(n.id).map(libelleInconnu) ?? n.id
                if a?.endormi == true { texte += " ☾" }
                if a?.etat == .sansAdresse || a?.etat == .disparu { texte += " ⚠︎" }
                libelles[n.id] = Libelle(texte: texte, pastille: pastilleBatterie(a?.batterie))
            }
        }
        return libelles
    }

    /// Texte d'un libelle : `.caption` pour les routeurs, `.caption2` pour les appareils ;
    /// semi-gras (`fort`) au survol et a la selection.
    static func texteLibelle(_ texte: String, genre: Disposition.Genre, fort: Bool) -> Text {
        Text(texte).font(genre == .appareil ? .caption2 : .caption).fontWeight(fort ? .semibold : .regular)
    }

    /// Titre d'une zone : sa partition et ses prefixes ; un prefixe revendique par
    /// plusieurs partitions est marque, sur chacune.
    static func titre(_ z: Disposition.Zone) -> String {
        let prefixes = z.prefixesTitre.map { p in
            z.prefixesPartages.contains(p) ? String(localized: "\(p.description) (partagé)") : p.description
        }.joined(separator: ", ")
        if z.id.isEmpty { return String(localized: "Sans partition connue") }
        if prefixes.isEmpty { return String(localized: "Partition \(z.id)") }
        return String(localized: "Partition \(z.id) · \(prefixes)")
    }

    static func texteTitre(_ titre: String) -> Text {
        Text(titre).font(.caption)
    }

    /// Point ou pose le bas du titre d'une zone : 6 pt au-dessus de son cercle.
    static func ancreTitre(centre: CGPoint, rayon: CGFloat) -> CGPoint {
        CGPoint(x: centre.x, y: centre.y - rayon - 6)
    }

    static let policePastille = Font.caption2.weight(.semibold)

    static var iconePastille: Text {
        Text(Image(systemName: "exclamationmark.triangle.fill")).font(policePastille)
    }

    static func textePastille(_ valeur: String) -> Text {
        Text(verbatim: valeur).font(policePastille)
    }

    /// Capsule de la pastille : 6 pt, l'icone, 3 pt, la valeur, 6 pt ; 2 pt dessus et dessous.
    static func taillePastille(icone: CGSize, valeur: CGSize) -> CGSize {
        CGSize(width: 6 + icone.width + 3 + valeur.width + 6, height: max(icone.height, valeur.height) + 4)
    }

    /// Rayon dessine d'un noeud : il suit le zoom sans enfler dans une grande fenetre.
    static func rayonPoint(_ rayon: Double, echelle: CGFloat) -> CGFloat {
        max(rayon * min(echelle, 1.1), 3)
    }
}
