import Charts
import MaillageCoeur
import SwiftUI

/// Courbes de l'historique dans la fiche (spec de la sonde, section 6), sur 24 h, 7 j ou 30 j :
/// la qualite des liens du noeud (d'un routeur avec ses voisins, d'un enfant vers son parent,
/// ses changements de parent marques) et, pour un routeur, le signal que la sonde en recoit,
/// avec les changements de parent de la sonde marques (ce signal depend d'abord de l'endroit ou
/// elle est posee). Le signal a toujours une echelle, et sa valeur se lit au survol (polissage D,
/// section 4.3).
struct CourbesFiche: View {
    @Environment(Surveillance.self) private var surveillance
    let id: String
    /// Fin des courbes : l'heure de la fiche (`FicheNoeud.instant`), qui avance chaque minute.
    let instant: Date
    @State private var periode: PeriodeCourbes = .jour

    var body: some View {
        let courbes = surveillance.courbes(noeud: id, periode: periode, fin: instant)
        let noms = courbes.map { c in
            surveillance.nomsHistorique(Set(c.liens.map(\.id) + (c.parents + c.parentsSonde).map(\.parent)))
        } ?? [:]
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("Historique de la sonde").font(.headline)
                Picker("Période", selection: $periode) {
                    ForEach(PeriodeCourbes.allCases) { Text(Self.titre($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            if let c = courbes, !c.estVide {
                HStack(alignment: .top, spacing: 24) {
                    if !c.liens.isEmpty || !c.parents.isEmpty { qualite(c, noms) }
                    if !c.signal.isEmpty { GrapheSignal(c: c, noms: noms, periode: periode) }
                }
            } else {
                Text("Pas encore d'historique de la sonde pour ce nœud sur cette période.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    static func titre(_ p: PeriodeCourbes) -> String {
        switch p {
        case .jour: String(localized: "24 h")
        case .semaine: String(localized: "7 j")
        case .mois: String(localized: "30 j")
        }
    }

    /// « Qualité du lien vers le parent » pour un enfant, « Qualité des liens » pour un routeur.
    static func titreQualite(_ c: CourbesNoeud) -> String {
        c.liens.allSatisfy { $0.id == CourbesNoeud.cleParent }
            ? String(localized: "Qualité du lien vers le parent") : String(localized: "Qualité des liens")
    }

    /// Nom d'une courbe de lien : le voisin, ou « Parent » pour le lien d'un enfant.
    static func nomLien(_ cle: String, _ noms: [String: String]) -> String {
        cle == CourbesNoeud.cleParent ? String(localized: "Parent") : noms[cle] ?? cle
    }

    /// Troncons d'un seul point : une ligne a besoin de deux points, ceux-la sont dessines en point
    /// (juste apres la premiere tournee, ou un point isole entre deux trous ; ajout du controleur,
    /// relecture de la tache 9).
    static func tronconsSeuls(_ points: [PointCourbe]) -> Set<Int> {
        Set(Dictionary(grouping: points, by: \.troncon).filter { $0.value.count == 1 }.keys)
    }

    private func qualite(_ c: CourbesNoeud, _ noms: [String: String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.titreQualite(c)).font(.caption).foregroundStyle(.secondary)
            Chart {
                ForEach(c.liens) { l in
                    let seuls = Self.tronconsSeuls(l.points)
                    ForEach(l.points, id: \.date) { p in
                        LineMark(x: .value("Heure", p.date), y: .value("Qualité", p.valeur),
                                 series: .value("Tronçon", "\(l.id)#\(p.troncon)"))
                            .foregroundStyle(by: .value("Lien", Self.nomLien(l.id, noms)))
                            .interpolationMethod(.stepEnd)
                        if seuls.contains(p.troncon) {
                            PointMark(x: .value("Heure", p.date), y: .value("Qualité", p.valeur))
                                .foregroundStyle(by: .value("Lien", Self.nomLien(l.id, noms)))
                                .symbolSize(16)
                        }
                    }
                }
                ForEach(c.parents, id: \.date) { ch in
                    RuleMark(x: .value("Heure", ch.date))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(verbatim: "→ " + (noms[ch.parent] ?? ch.parent)).font(.caption2)
                        }
                }
            }
            .chartXScale(domain: c.debut ... c.fin)
            .chartYScale(domain: 0 ... 3)
            .chartYAxis { AxisMarks(values: [0, 1, 2, 3]) }
            .chartLegend(c.liens.allSatisfy { $0.id == CourbesNoeud.cleParent } ? .hidden : .visible)
            .frame(width: 320, height: 120)
        }
    }

    /// L'echelle du signal (polissage D, section 4.3) : son domaine, des dizaines de dBm autour de ses valeurs, et ses
    /// graduations ; sans valeur, de -100 a -40 dBm.
    static func echelle(_ c: CourbesNoeud) -> (domaine: ClosedRange<Double>, graduations: [Double]) {
        let d = EchelleSignal.domaine(c.signal.map(\.valeur)) ?? -100 ... -40
        return (d, EchelleSignal.graduations(d))
    }
}

/// Le graphe du signal vu par la sonde, avec sa valeur au survol (polissage D, section 4.3). Une vue a part : le survol
/// change `survole` quand le releve sous le pointeur change, et seul ce graphe se recalcule, non les courbes de
/// `CourbesFiche` (qui relisent l'historique de la periode).
struct GrapheSignal: View {
    @Environment(\.locale) private var langue
    let c: CourbesNoeud
    let noms: [String: String]
    let periode: PeriodeCourbes
    /// L'heure du releve sous le pointeur ; nil, ailleurs. L'etat disparait avec le graphe, et se remet a zero quand la
    /// periode change.
    @State private var survole: Date?

    /// Ce que la vue affiche, decide sans fenetre : l'echelle, le releve sous l'heure survolee (aucun dans un trou), et
    /// le cote de son etiquette (a gauche du trait dans la moitie droite du graphe, a droite sinon).
    struct Affichage {
        let domaine: ClosedRange<Double>
        let graduations: [Double]
        let releve: PointCourbe?
        let alignement: Alignment
    }

    static func affichage(_ c: CourbesNoeud, survole: Date?, periode: PeriodeCourbes) -> Affichage {
        let echelle = CourbesFiche.echelle(c)
        let releve = survole.flatMap { EchelleSignal.plusProche(c.signal, de: $0, periode: periode) }
        let aGauche = releve.map { EchelleSignal.aGauche($0.date, debut: c.debut, fin: c.fin) } ?? false
        return Affichage(domaine: echelle.domaine, graduations: echelle.graduations, releve: releve,
                         alignement: aGauche ? .trailing : .leading)
    }

    /// L'heure survolee apres un evenement du pointeur : celle du releve le plus proche de sa position (`convertir`,
    /// nil hors de la zone de trace), nil dans un trou de la courbe et quand il sort. Elle ne change que lorsque ce
    /// releve change : le graphe ne se refait pas a chaque pixel (relecture finale, Mineur 4).
    static func heureSurvolee(_ phase: HoverPhase, signal: [PointCourbe], periode: PeriodeCourbes,
                              convertir: (CGPoint) -> Date?) -> Date? {
        switch phase {
        case .active(let position):
            convertir(position).flatMap { EchelleSignal.plusProche(signal, de: $0, periode: periode)?.date }
        case .ended: nil
        }
    }

    var body: some View {
        let a = Self.affichage(c, survole: survole, periode: periode)
        VStack(alignment: .leading, spacing: 2) {
            Text("Signal vu par la sonde (dBm)").font(.caption).foregroundStyle(.secondary)
            Chart {
                let seuls = CourbesFiche.tronconsSeuls(c.signal)
                ForEach(c.signal, id: \.date) { p in
                    LineMark(x: .value("Heure", p.date), y: .value("Signal", p.valeur),
                             series: .value("Tronçon", p.troncon))
                    if seuls.contains(p.troncon) {
                        PointMark(x: .value("Heure", p.date), y: .value("Signal", p.valeur))
                            .symbolSize(16)
                    }
                }
                ForEach(c.parentsSonde, id: \.date) { ch in
                    RuleMark(x: .value("Heure", ch.date))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(verbatim: "→ " + (noms[ch.parent] ?? ch.parent)).font(.caption2)
                        }
                }
                // Le releve survole : un trait a son heure, un point sur sa valeur, son etiquette, dans le cadre.
                if let r = a.releve {
                    RuleMark(x: .value("Heure", r.date))
                        .foregroundStyle(.primary.opacity(0.5))
                        .annotation(position: .top, alignment: a.alignement, spacing: 0,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            Text(verbatim: EchelleSignal.etiquette(r, periode: periode, locale: langue,
                                                                   fuseau: .current))
                                .font(.caption2.monospacedDigit())
                                .padding(.horizontal, 4)
                                .background(.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 3))
                        }
                    PointMark(x: .value("Heure", r.date), y: .value("Signal", r.valeur))
                        .symbolSize(30)
                }
            }
            .chartXScale(domain: c.debut ... c.fin)
            .chartYScale(domain: a.domaine)
            .chartYAxis { AxisMarks(values: a.graduations) }
            .chartOverlay { proxy in
                GeometryReader { g in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            let heure = Self.heureSurvolee(phase, signal: c.signal, periode: periode) { position in
                                proxy.plotFrame.flatMap { cadre in
                                    proxy.value(atX: position.x - g[cadre].origin.x, as: Date.self)
                                }
                            }
                            if heure != survole { survole = heure }
                        }
                }
            }
            .frame(width: 320, height: 120)
            if !c.parentsSonde.isEmpty {
                Text("Pointillé : la sonde change de parent.").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .onChange(of: periode) { survole = nil }
    }
}
