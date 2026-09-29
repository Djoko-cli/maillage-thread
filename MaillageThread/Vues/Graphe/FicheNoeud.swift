import MaillageCoeur
import SwiftUI

/// Fiche du noeud choisi : carte de verre en bas de la fenetre.
struct FicheNoeud: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.colorScheme) private var apparence
    let id: String
    @Binding var aRenommer: NoeudChoisi?
    /// Choisit un autre noeud (la fiche d'un candidat).
    var choisir: (String) -> Void = { _ in }
    var fermer: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            if let r = surveillance.instantane?.routeur(id) {
                colonnesRouteur(r)
            } else if let a = surveillance.appareil(id) {
                colonnesAppareil(a)
            } else if let m = sonde, let n = m.noeud(id) {
                colonnesSonde(n, m)
            } else {
                Text("Ce nœud n'est plus visible.").foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    fermer()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.glass)
                .help("Fermer")
                if Self.renommable(id, dans: surveillance) {
                    Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                        .buttonStyle(.glass)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    /// « Renommer… » : le surnom est indexe par l'instance d'un routeur de l'instantane ou
    /// par l'id d'un appareil connu. Un noeud que la sonde seule connait n'a qu'un RLOC16,
    /// volatil : rien ne lirait son surnom.
    static func renommable(_ id: String, dans surveillance: Surveillance) -> Bool {
        surveillance.instantane?.routeur(id) != nil || surveillance.appareil(id) != nil
    }

    // MARK: Appareil

    @ViewBuilder
    private func colonnesAppareil(_ a: Appareil) -> some View {
        let disparu = surveillance.suivi.disparus[a.id] != nil
        let maison = surveillance.accessoire(a)
        VStack(alignment: .leading, spacing: 4) {
            Text(surveillance.nom(a)).font(.title3.weight(.semibold))
            let description = Self.ligneDescription(maison: maison, modeleHomeKit: a.hap?.modele)
            if !description.isEmpty {
                Text(description).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                PointEtat(couleur: couleur(a, disparu: disparu), pulse: !disparu && a.etat == .joignable)
                Text(etat(a, disparu: disparu))
                if let vu = vuLe(a, disparu: disparu) {
                    Text("· vu \(Self.relatif(vu, surveillance.maintenant))").foregroundStyle(.secondary)
                }
            }
            if let b = maison?.batterie {
                HStack(spacing: 6) {
                    Image(systemName: Self.symboleBatterie(b))
                        .foregroundStyle(b.faible ? orange : b.charge == .enCharge ? Color.green : Color.primary)
                    Text(Self.ligneBatterie(b)).foregroundStyle(b.faible ? orange : Color.primary)
                    if let releve = surveillance.noms.maison?.date {
                        Text("· relevé \(Self.relatif(releve, surveillance.maintenant))").foregroundStyle(.secondary)
                    }
                }
            }
            lignesSonde(a.id)
        }
        .frame(minWidth: 200, alignment: .leading)
        VStack(alignment: .leading, spacing: 4) {
            Text(genre(a)).foregroundStyle(.secondary)
            if !a.fabriques.isEmpty {
                Text("Fabriques : \(a.fabriques.count)").foregroundStyle(.secondary)
            }
            ForEach(a.adresses.prefix(2), id: \.self) { ad in
                Text(ad.description).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Text(a.id).font(.caption.monospaced()).foregroundStyle(.tertiary).textSelection(.enabled)
        }
        colonneJournal(partition: a.partition ?? surveillance.suivi.dernieresPartitions[a.id], prefixe: a.prefixe,
                       incertaine: surveillance.instantane?.partitionIncertaine(a) == true)
    }

    /// Piece, fabricant (sinon modele HomeKit), modele, et firmware quand Maison le donne.
    static func ligneDescription(maison: AccessoireMaison?, modeleHomeKit: String?) -> String {
        let firmware = maison?.firmware.flatMap { $0.isEmpty ? nil : String(localized: "firmware \($0)") }
        return [maison?.piece, maison?.fabricant ?? modeleHomeKit, maison?.modele, firmware]
            .compactMap { $0 }.joined(separator: " · ")
    }

    /// Niveau, puis l'etat de charge ; faible, « batterie faible » (et « en
    /// charge » seulement) ; sans niveau, l'alerte : « batterie OK » seulement
    /// si l'accessoire le dit.
    static func ligneBatterie(_ b: BatterieMaison) -> String {
        var parties: [String] = []
        if let n = b.niveau {
            parties.append(String(localized: "\(n)\u{202F}%"))
            if b.faible { parties.append(String(localized: "batterie faible")) }
        } else if b.faible {
            parties.append(String(localized: "batterie faible"))
        } else if b.alerte == false {
            parties.append(String(localized: "batterie OK"))
        }
        switch b.charge {
        case .enCharge: parties.append(String(localized: "en charge"))
        case .horsCharge where !b.faible: parties.append(String(localized: "sur batterie"))
        case .nonRechargeable where !b.faible: parties.append(String(localized: "non rechargeable"))
        default: break
        }
        return parties.joined(separator: " · ")
    }

    /// Triangle si faible, eclair en charge, sinon le niveau par quart.
    static func symboleBatterie(_ b: BatterieMaison) -> String {
        if b.faible { return "exclamationmark.triangle.fill" }
        if b.charge == .enCharge { return "battery.100percent.bolt" }
        switch b.niveau ?? 100 {
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    /// Orange de la batterie faible, assez fonce en mode clair pour se lire sur le verre pale.
    private var orange: Color { apparence == .dark ? .orange : Color(red: 0.72, green: 0.36, blue: 0) }

    private func etat(_ a: Appareil, disparu: Bool) -> String {
        if disparu { return String(localized: "disparu") }
        switch a.etat {
        case .joignable: return String(localized: "joignable")
        case .partitionCoupee: return String(localized: "isolé (partition coupée)")
        case .sansAdresse: return String(localized: "sans adresse")
        case .inconnu: return String(localized: "partition inconnue")
        }
    }

    private func couleur(_ a: Appareil, disparu: Bool) -> Color {
        if disparu { return .red }
        switch a.etat {
        case .joignable: return .green
        case .partitionCoupee: return .orange
        case .sansAdresse: return .red
        case .inconnu: return .gray
        }
    }

    /// "il y a 12 secondes", "maintenant".
    static func relatif(_ d: Date, _ reference: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.dateTimeStyle = .named
        f.unitsStyle = .full
        return f.localizedString(for: d, relativeTo: reference)
    }

    /// Present : l'instantane integre (un releve vide ne compte pas) ; disparu : sa premiere absence.
    private func vuLe(_ a: Appareil, disparu: Bool) -> Date? {
        if disparu { return surveillance.evenements(de: a.id).first { $0.type == .appareilDisparu }?.date }
        return surveillance.instantane?.date
    }

    private func genre(_ a: Appareil) -> String {
        var morceaux: [String] = []
        if !a.instances.isEmpty { morceaux.append("Matter") }
        if a.hap != nil { morceaux.append("HomeKit") }
        if a.endormi {
            if let sii = a.proprietes?.sii {
                morceaux.append(String(localized: "endormi (réveil \(sii / 1000) s)"))
            } else {
                morceaux.append(String(localized: "endormi"))
            }
        }
        return morceaux.joined(separator: " · ")
    }

    // MARK: Sonde

    /// Maillage de la sonde pour le reseau affiche.
    private var sonde: MaillageAffiche? { surveillance.reseau.flatMap { surveillance.maillageAffiche(pour: $0) } }

    /// Ce que la sonde sait du noeud : son parent (enfant), ses voisins et ses enfants (routeur).
    @ViewBuilder
    private func lignesSonde(_ id: String) -> some View {
        if let m = sonde, let n = m.noeud(id) {
            Text(Self.ligneSonde(n, maillage: m, nom: nomNoeud)).foregroundStyle(.secondary)
        }
    }

    /// Noeud que seule la sonde connait (routeur de bordure muet sans identite, avec ses
    /// candidats ; enfant inconnu).
    @ViewBuilder
    private func colonnesSonde(_ n: NoeudSonde, _ m: MaillageAffiche) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(GrapheCanvas.libelleInconnu(n, noms: nomsRouteurs)).font(.title3.weight(.semibold))
            Text(Self.ligneSonde(n, maillage: m, nom: nomNoeud)).foregroundStyle(.secondary)
            if !n.candidats.isEmpty {
                // Chaque candidat ouvre la fiche de son annonce, pas dessinee a part.
                HStack(spacing: 8) {
                    Text("Candidats :")
                    ForEach(n.candidats, id: \.self) { c in
                        let choix = Self.selection(candidat: c, dans: surveillance)
                        Button(nomsRouteurs[c] ?? c) {
                            if let choix { choisir(choix) }
                        }
                        .buttonStyle(.link)
                        .disabled(choix == nil)
                    }
                }
            }
            Text(Self.explication(n))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 200, alignment: .leading)
    }

    /// Noeud a choisir pour un candidat : son annonce, si l'instantane la connait encore (sa
    /// fiche : role, adresses, journal, « Renommer… ») ; nil sinon.
    static func selection(candidat: String, dans surveillance: Surveillance) -> String? {
        surveillance.instantane?.routeur(candidat) != nil ? candidat : nil
    }

    /// Ce que la sonde sait d'un noeud qu'elle seule connait.
    static func explication(_ n: NoeudSonde) -> String {
        switch n.genre {
        case .routeur where !n.candidats.isEmpty:
            String(localized: "Vu par la sonde sans son identité : sans doute l'une de ces annonces du réseau local, qu'aucun nœud ne reprend.")
        case .routeur:
            String(localized: "Vu par la sonde, sans annonce reconnue sur le réseau local.")
        case .enfant:
            String(localized: "Vu par la sonde : son ExtMac ne correspond à aucun appareil annoncé.")
        }
    }

    /// Fiche d'un routeur de bordure reconnu par elimination (`NoeudSonde.deduit`).
    static var texteElimination: String {
        String(localized: "Reconnu par élimination : seul routeur de bordure sans identité, seule annonce restante.")
    }

    /// Nom affiche de chaque routeur de bordure du reseau affiche, par instance (candidats d'un
    /// routeur de bordure non identifie).
    private var nomsRouteurs: [String: String] {
        surveillance.reseau.map(surveillance.nomsRouteurs) ?? [:]
    }

    /// Nom d'un noeud du graphe : routeur de bordure, appareil, ou noeud de la sonde.
    private func nomNoeud(_ id: String) -> String {
        if let r = surveillance.instantane?.routeur(id) { return surveillance.nom(r) }
        if let a = surveillance.appareil(id) { return surveillance.nom(a) }
        if let n = sonde?.noeud(id) { return GrapheCanvas.libelleInconnu(n, noms: nomsRouteurs) }
        return id
    }

    /// « RLOC16 5004 · parent HomePod bureau, qualité 3 » ; « RLOC16 5000 · voisins : 4 · enfants : 2 ».
    static func ligneSonde(_ n: NoeudSonde, maillage m: MaillageAffiche, nom: (String) -> String) -> String {
        let rloc = String(format: "%04X", n.rloc16)
        switch n.genre {
        case .enfant:
            guard let p = m.parent(de: n.id) else { return String(localized: "RLOC16 \(rloc)") }
            let q = m.liens.first { $0.genre == .parent && $0.de == n.id }?.qualite
            return String(localized: "RLOC16 \(rloc) · parent \(nom(p)), \(texteQualite(q))")
        case .routeur:
            let voisins = m.liens.filter { $0.genre == .radio && ($0.de == n.id || $0.vers == n.id) }.count
            let enfants = m.liens.filter { $0.genre == .parent && $0.vers == n.id }.count
            return String(localized: "RLOC16 \(rloc) · voisins : \(voisins) · enfants : \(enfants)")
        }
    }

    /// « qualité 3 » ; « qualité inconnue » sous un routeur muet.
    static func texteQualite(_ q: Int?) -> String {
        q.map { String(localized: "qualité \($0)") } ?? String(localized: "qualité inconnue")
    }

    // MARK: Routeur

    @ViewBuilder
    private func colonnesRouteur(_ r: RouteurBordure) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(surveillance.nom(r)).font(.title3.weight(.semibold))
            let description = [r.fabricant, r.modele, r.versionThread.map { "Thread \($0)" }].compactMap { $0 }
                .joined(separator: " · ")
            Text(description).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Circle().fill(.blue).frame(width: 8, height: 8)
                Text(role(r))
                if let bbr = bbr(r) { Text("· \(bbr)").foregroundStyle(.secondary) }
            }
        }
        .frame(minWidth: 200, alignment: .leading)
        VStack(alignment: .leading, spacing: 4) {
            Text("Routeur de bordure").foregroundStyle(.secondary)
            lignesSonde(r.instance)
            if sonde?.noeud(r.instance)?.deduit == true {
                Text(Self.texteElimination).font(.caption).foregroundStyle(.secondary)
            }
            if let nn = r.nomReseau { Text("Réseau \(nn)").foregroundStyle(.secondary) }
            ForEach(r.adressesLien, id: \.self) { ad in
                Text(ad.description).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        colonneJournal(partition: r.partition, prefixe: r.prefixeOMR)
    }

    private func role(_ r: RouteurBordure) -> String {
        guard let role = r.role else { return String(localized: "rôle inconnu (Thread \(r.versionThread ?? "?"))") }
        return TexteEvenement.role(role.rawValue)
    }

    private func bbr(_ r: RouteurBordure) -> String? {
        guard let e = r.etat, e.bbrActif else { return nil }
        return e.bbrPrimaire ? String(localized: "BBR primaire") : String(localized: "BBR actif")
    }

    // MARK: Journal du noeud

    /// `incertaine` : partition d'un appareil tiree d'un prefixe partage (voir `Instantane.partitionIncertaine`).
    private func colonneJournal(partition: String?, prefixe: PrefixeIPv6?, incertaine: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let partition {
                if incertaine {
                    Text("Partition \(partition) (incertaine : préfixe partagé)").foregroundStyle(.secondary)
                } else {
                    Text("Partition \(partition)").foregroundStyle(.secondary)
                }
            }
            if let prefixe {
                Text(prefixe.description).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            ForEach(surveillance.evenements(de: id)) { e in
                Text("\(TexteEvenement.quand(e)) · \(TexteEvenement.titre(e))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

/// Point d'etat de la fiche. Joignable, il pulse doucement : un halo s'elargit
/// et s'efface toutes les 2 s, sauf si « Reduire les animations » est active.
private struct PointEtat: View {
    let couleur: Color
    let pulse: Bool
    @Environment(\.accessibilityReduceMotion) private var reduire

    var body: some View {
        Circle().fill(couleur).frame(width: 8, height: 8)
            .background {
                if pulse && !reduire {
                    Circle().fill(couleur)
                        .phaseAnimator([false, true]) { halo, etendu in
                            halo.scaleEffect(etendu ? 2.6 : 1).opacity(etendu ? 0 : 0.55)
                        } animation: { etendu in
                            etendu ? .easeOut(duration: 2) : nil
                        }
                }
            }
    }
}
