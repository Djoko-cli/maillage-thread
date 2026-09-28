import MaillageCoeur
import SwiftUI

/// Dessin du graphe : zones des partitions, pointilles vers le centre de
/// chaque zone (rattachement, pas un lien radio), routeurs et appareils.
struct GrapheCanvas: View {
    let disposition: Disposition
    let reseau: Reseau
    /// Identifiant -> appareil affiche (etat, nom).
    let appareils: [String: AppareilAffiche]
    /// Instance -> nom affiche du routeur.
    let nomsRouteurs: [String: String]
    let projection: Projection
    let selection: String?
    let survol: String?
    let palette: Palette

    var body: some View {
        Canvas { ctx, _ in
            dessinerZones(&ctx)
            dessinerLiens(&ctx)
            dessinerNoeuds(&ctx)
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
            let prefixes = z.prefixes.map(\.description).joined(separator: ", ")
            let titre: String
            if z.id.isEmpty {
                titre = String(localized: "Sans partition connue")
            } else if prefixes.isEmpty {
                titre = String(localized: "Partition \(z.id)")
            } else {
                titre = String(localized: "Partition \(z.id) · \(prefixes)")
            }
            ctx.draw(Text(titre).font(.caption).foregroundStyle(couleur.opacity(0.95)),
                     at: CGPoint(x: c.x, y: c.y - r - 6), anchor: .bottom)
        }
    }

    private func dessinerLiens(_ ctx: inout GraphicsContext) {
        let positions = Dictionary(disposition.noeuds.map { ($0.id, $0.position) }, uniquingKeysWith: { a, _ in a })
        for l in disposition.liens {
            guard let a = positions[l.de], let b = positions[l.vers] else { continue }
            var p = Path()
            p.move(to: projection.vue(a))
            p.addLine(to: projection.vue(b))
            let eclaire = l.de == selection || l.de == survol
            ctx.stroke(p, with: .color(eclaire ? palette.lienEclaire : palette.lien),
                       style: StrokeStyle(lineWidth: eclaire ? 1.6 : 1, dash: [2, 4]))
        }
    }

    private func dessinerNoeuds(_ ctx: inout GraphicsContext) {
        let chefs = Set(reseau.partitions.compactMap { $0.chef?.instance })
        let principales = Set(disposition.zones.filter(\.principale).map(\.id))
        let centres = Dictionary(disposition.zones.map { ($0.id, $0.centre) }, uniquingKeysWith: { a, _ in a })
        for n in disposition.noeuds {
            let c = projection.vue(n.position)
            // Les noeuds suivent le zoom, sans enfler dans une grande fenetre.
            let r = max(n.rayon * min(projection.echelle, 1.1), 3)
            let rect = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            var libelle: String
            switch n.genre {
            case .centre, .routeur:
                let couleur = palette.routeur(principale: principales.contains(n.zone))
                ctx.drawLayer { l in
                    l.addFilter(.shadow(color: couleur.opacity(0.8), radius: n.genre == .centre ? 10 : 5))
                    l.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [.white.opacity(0.9), couleur]),
                                                                        center: CGPoint(x: c.x - r / 3, y: c.y - r / 3),
                                                                        startRadius: 0, endRadius: r * 1.3))
                }
                libelle = nomsRouteurs[n.id] ?? n.id
                if chefs.contains(n.id) { libelle += " 👑" }
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
                libelle = a?.nom ?? n.id
                if a?.endormi == true { libelle += " 🔋" }
                if a?.etat == .sansAdresse || a?.etat == .disparu { libelle += " ⚠︎" }
            }
            if n.id == selection {
                ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(palette.selection), lineWidth: 2)
            }
            let fort = n.id == selection || n.id == survol
            let texte = Text(libelle).font(n.genre == .appareil ? .caption2 : .caption)
                .fontWeight(fort ? .semibold : .regular).foregroundStyle(fort ? palette.selection : palette.texte)
            // Libelle vers l'exterieur de la zone : a droite ou a gauche sur les
            // cotes, au-dessus ou au-dessous en haut et en bas ; sous le centre.
            let centreZone = centres[n.zone] ?? n.position
            let angle = atan2(n.position.y - centreZone.y, n.position.x - centreZone.x)
            if n.genre == .centre {
                ctx.draw(texte, at: CGPoint(x: c.x, y: c.y + r + 4), anchor: .top)
            } else if cos(angle) > 0.35 {
                ctx.draw(texte, at: CGPoint(x: c.x + r + 4, y: c.y), anchor: .leading)
            } else if cos(angle) < -0.35 {
                ctx.draw(texte, at: CGPoint(x: c.x - r - 4, y: c.y), anchor: .trailing)
            } else if sin(angle) < 0 {
                ctx.draw(texte, at: CGPoint(x: c.x, y: c.y - r - 3), anchor: .bottom)
            } else {
                ctx.draw(texte, at: CGPoint(x: c.x, y: c.y + r + 3), anchor: .top)
            }
        }
    }
}
