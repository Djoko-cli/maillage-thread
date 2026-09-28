import MaillageCoeur
import SwiftUI

/// Fiche du noeud choisi : carte de verre en bas de la fenetre.
struct FicheNoeud: View {
    @Environment(Surveillance.self) private var surveillance
    let id: String
    @Binding var aRenommer: NoeudChoisi?
    var fermer: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            if let r = surveillance.instantane?.routeur(id) {
                colonnesRouteur(r)
            } else if let a = surveillance.appareil(id) {
                colonnesAppareil(a)
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
                Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                    .buttonStyle(.glass)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    // MARK: Appareil

    @ViewBuilder
    private func colonnesAppareil(_ a: Appareil) -> some View {
        let disparu = surveillance.suivi.disparus[a.id] != nil
        let maison = surveillance.accessoire(a)
        VStack(alignment: .leading, spacing: 4) {
            Text(surveillance.nom(a)).font(.title3.weight(.semibold))
            let description = [maison?.piece, maison?.fabricant ?? a.hap?.modele, maison?.modele]
                .compactMap { $0 }.joined(separator: " · ")
            if !description.isEmpty {
                Text(description).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Circle().fill(couleur(a, disparu: disparu)).frame(width: 8, height: 8)
                Text(etat(a, disparu: disparu))
                if let vu = vuLe(a, disparu: disparu) {
                    Text("· vu \(Self.relatif(vu, surveillance.maintenant))").foregroundStyle(.secondary)
                }
            }
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
