import MaillageCoeur
import SwiftUI

/// Fiche du noeud choisi : carte de verre en bas de la fenetre.
struct FicheNoeud: View {
    @Environment(Surveillance.self) private var surveillance
    @Environment(\.colorScheme) private var apparence
    /// Pieces choisies pour les noeuds que Maison ne place pas : la vue par pieces seule les donne.
    @Environment(PiecesChoisies.self) private var piecesChoisies: PiecesChoisies?
    let id: String
    /// La scene du meme rendu (`EntreeScene`), avec ce dont elle est faite : la fiche y lit le maillage
    /// rapproche, et « Placer dans une piece… » le graphe, sans rien reconstruire ; nil sans reseau.
    let entree: EntreeScene?
    /// Heure de la fenetre du graphe (sa `TimelineView`, chaque minute ; la fin de la panne en demo) :
    /// les durees de la fiche (« vu il y a... ») suivent l'heure sans autre evenement.
    let instant: Date
    @Binding var aRenommer: NoeudChoisi?
    /// Choisit un autre noeud (la fiche d'un candidat).
    var choisir: (String) -> Void = { _ in }
    var fermer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    .boutonDeFiche()
                    .help("Fermer")
                    if Self.renommable(id, dans: surveillance) {
                        Button("Renommer…") { aRenommer = NoeudChoisi(id: id) }
                            .boutonDeFiche()
                    }
                    if let piecesChoisies, let entree,
                       let placement = PiecesChoisies.placement(id, dans: surveillance, entree: entree) {
                        MenuPlacer(placement: placement, domicile: surveillance.noms.maison?.domicile ?? "",
                                   choisies: piecesChoisies)
                    }
                }
            }
            if Self.courbesVisibles(dans: surveillance) {
                CourbesFiche(id: id, instant: instant)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FondDeFiche())
    }

    /// Le noeud est couronne : un chef de la scene du meme rendu (`EntreeScene.chefs`), routeur de
    /// bordure ou noeud que la sonde seule connait ; la fiche couronne les memes noeuds que la scene.
    static func couronne(_ id: String, entree: EntreeScene?) -> Bool {
        entree?.chefs.contains(id) == true
    }

    /// Courbes de l'historique sous les colonnes, pour tout noeud, des que l'historique de la
    /// sonde a un releve (jamais en demo) : la fiche garde sa hauteur d'un noeud a l'autre.
    static func courbesVisibles(dans surveillance: Surveillance) -> Bool {
        !surveillance.historique.isEmpty
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
            if Self.couronne(a.id, entree: entree) {
                PastilleChef()
            }
            HStack(spacing: 6) {
                PointEtat(couleur: couleur(a, disparu: disparu), pulse: !disparu && a.etat == .joignable)
                Text(etat(a, disparu: disparu))
                if let vu = vuLe(a, disparu: disparu) {
                    Text("· vu \(Self.relatif(vu, instant))").foregroundStyle(.secondary)
                }
            }
            if let b = maison?.batterie {
                HStack(spacing: 6) {
                    Image(systemName: Self.symboleBatterie(b))
                        .foregroundStyle(b.faible ? orange : b.charge == .enCharge ? Color.green : Color.primary)
                    Text(Self.ligneBatterie(b)).foregroundStyle(b.faible ? orange : Color.primary)
                    if let releve = surveillance.noms.maison?.date {
                        Text("· relevé \(Self.relatif(releve, instant))").foregroundStyle(.secondary)
                    }
                }
            }
            lignesSonde(a.id)
        }
        .frame(minWidth: 200, alignment: .leading)
        .colonneDuChef(Self.couronne(a.id, entree: entree))
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
        // L'heure de la fiche est un debut de minute (TimelineView de la fenetre) : une date plus
        // recente, d'un releve fait depuis, se lirait « dans 20 secondes ». Jamais dans le futur :
        // « maintenant » jusqu'a la minute suivante (la spec admet une minute de retard).
        return f.localizedString(for: d, relativeTo: max(d, reference))
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

    /// Maillage de la sonde pour le reseau affiche : celui de la scene.
    private var sonde: MaillageAffiche? { entree?.maillage }

    /// Ce que la sonde sait du noeud : son parent (enfant), ses voisins et ses enfants (routeur) ; puis, pour un routeur,
    /// chaque lien avec sa source et son age, et s'il n'a jamais ete entendu par la sonde (spec de la sonde tout-en-un,
    /// section 2.4).
    @ViewBuilder
    private func lignesSonde(_ id: String) -> some View {
        if let m = sonde, let n = m.noeud(id) {
            Text(Self.ligneSonde(n, maillage: m, nom: nomNoeud, instant: instant)).foregroundStyle(.secondary)
            ForEach(Self.lignesLiens(n, maillage: m, nom: nomNoeud, instant: instant), id: \.self) { ligne in
                Text(ligne).font(.caption).foregroundStyle(.secondary)
            }
            if m.jamaisEntendu(id) {
                Text(Self.texteJamaisEntendu).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Noeud que seule la sonde connait (routeur de bordure muet sans identite, avec ses
    /// candidats ; enfant inconnu).
    @ViewBuilder
    private func colonnesSonde(_ n: NoeudSonde, _ m: MaillageAffiche) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LibellesNoeuds.inconnu(n, noms: nomsRouteurs)).font(.title3.weight(.semibold))
            if Self.couronne(n.id, entree: entree) {
                PastilleChef()
            }
            lignesSonde(n.id)
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
        surveillance.nomNoeud(id, maillage: sonde) ?? id
    }

    /// « RLOC16 5004 · parent HomePod bureau, qualite 3 · diagnostic » ; un enfant resolu sous un routeur Apple, dont le
    /// RLOC16 est invente (`EnfantMaillage.bitInvente`), sans lui : « parent HomePod bureau, qualite inconnue · resolu
    /// il y a 12 minutes · acces au canal refuses : 0,7 % » ; « RLOC16 5000 · voisins : 4 · enfants : 2 ».
    static func ligneSonde(_ n: NoeudSonde, maillage m: MaillageAffiche, nom: (String) -> String,
                           instant: Date = .now) -> String {
        let rloc = String(format: "%04X", n.rloc16)
        switch n.genre {
        case .enfant:
            guard let p = m.parent(de: n.id) else { return String(localized: "RLOC16 \(rloc)") }
            let lien = m.liens.first { $0.genre == .parent && $0.de == n.id }
            let q = lien?.qualite
            let ligne = n.rloc16 & EnfantMaillage.bitInvente == 0
                ? String(localized: "RLOC16 \(rloc) · parent \(nom(p)), \(texteQualite(q))")
                : String(localized: "parent \(nom(p)), \(texteQualite(q))")
            return ([ligne] + (lien?.origine.map { [texteOrigine($0, instant)] } ?? [])).joined(separator: " · ")
        case .routeur:
            let voisins = m.liens.filter { $0.genre == .radio && ($0.de == n.id || $0.vers == n.id) }.count
            let enfants = m.liens.filter { $0.genre == .parent && $0.vers == n.id }.count
            return String(localized: "RLOC16 \(rloc) · voisins : \(voisins) · enfants : \(enfants)")
        }
    }

    /// « qualite 3 » ; « qualite inconnue » sous un routeur muet.
    static func texteQualite(_ q: Int?) -> String {
        q.map { String(localized: "qualité \($0)") } ?? String(localized: "qualité inconnue")
    }

    /// Liens radio d'un routeur, chacun avec sa source et son age : « HomePod salon : qualite 3 · entendu il y a 3
    /// minutes » ; un lien sans source (maillage de demo) n'a pas de ligne.
    static func lignesLiens(_ n: NoeudSonde, maillage m: MaillageAffiche, nom: (String) -> String,
                            instant: Date) -> [String] {
        guard n.genre == .routeur else { return [] }
        return m.liens.filter { $0.genre == .radio && ($0.de == n.id || $0.vers == n.id) }.compactMap { l in
            guard let o = l.origine else { return nil }
            let voisin = l.de == n.id ? l.vers : l.de
            return String(localized: "\(nom(voisin)) : \(texteQualite(l.qualite)) · \(texteOrigine(o, instant))")
        }.sorted()
    }

    /// Source et age d'un lien : « diagnostic », « entendu il y a 3 minutes », « resolu il y a 12 minutes »,
    /// « acces au canal refuses : 0,7 % », « donne par la sonde » ; plusieurs, separes par « · ».
    static func texteOrigine(_ o: OrigineLien, _ instant: Date) -> String {
        var parties: [String] = []
        if o.sonde { parties.append(String(localized: "donné par la sonde")) }
        if o.diagnostic { parties.append(String(localized: "diagnostic")) }
        if let d = o.entendu { parties.append(String(localized: "entendu \(relatif(d, instant))")) }
        if let d = o.resolu { parties.append(String(localized: "résolu \(relatif(d, instant))")) }
        if let e = o.echecs { parties.append(texteAccesCanal(e)) }
        return parties.joined(separator: " · ")
    }

    /// « acces au canal refuses : 0,7 % » : les acces au canal refuses a l'enfant rapportes a ses envois, au dixieme de
    /// pour cent, a titre d'information (`AccesCanal` : ce n'est pas la qualite de son lien).
    static func texteAccesCanal(_ taux: Double) -> String {
        String(localized: "accès au canal refusés : \(taux.formatted(.percent.precision(.fractionLength(1))))")
    }

    /// Un routeur muet que la sonde n'entend pas (`MaillageAffiche.jamaisEntendu`).
    static var texteJamaisEntendu: String {
        String(localized: "jamais entendu par la sonde ; liens vus seulement par ses voisins")
    }

    // MARK: Routeur

    @ViewBuilder
    private func colonnesRouteur(_ r: RouteurBordure) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(surveillance.nom(r)).font(.title3.weight(.semibold))
            let description = [r.fabricant, r.modele, r.versionThread.map { "Thread \($0)" }].compactMap { $0 }
                .joined(separator: " · ")
            Text(description).foregroundStyle(.secondary)
            if Self.couronne(r.instance, entree: entree) {
                PastilleChef()
            }
            HStack(spacing: 6) {
                Circle().fill(.blue).frame(width: 8, height: 8)
                Text(role(r))
                if let bbr = bbr(r) { Text("· \(bbr)").foregroundStyle(.secondary) }
            }
        }
        .frame(minWidth: 200, alignment: .leading)
        .colonneDuChef(Self.couronne(r.instance, entree: entree))
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

extension View {
    /// Bouton de verre de la fiche ; dans une capture, qui ne rend pas le verre, celui des capsules.
    func boutonDeFiche() -> some View {
        modifier(BoutonDeFiche())
    }

    /// Colonne de la fiche qui porte la pastille du chef : elle passe avant les autres. La pastille garde
    /// sa ligne (`PastilleChef`), mais le `.frame(minWidth:)` de la colonne ne la fait pas plus large que la
    /// place que la fiche lui propose : quand les colonnes se serrent, la pastille deborderait sur la
    /// colonne voisine.
    func colonneDuChef(_ couronne: Bool) -> some View {
        layoutPriority(couronne ? 1 : 0)
    }
}

private struct BoutonDeFiche: ViewModifier {
    @Environment(\.capturePieces) private var capture

    func body(content: Content) -> some View {
        if capture {
            content.buttonStyle(StyleBoutonCapsule())
        } else {
            content.buttonStyle(.glass)
        }
    }
}

/// Fond de la fiche : du verre aux coins de 22 pt (le Liquid Glass de macOS). Une capture, qui ne rend pas
/// le verre, dessine a sa place un fond proche de celui de la maquette de la fiche (rgba(40, 48, 72, 0,40),
/// filet de 0,5 pt blanc a 0,22, ombre noire a 0,4), avec deux ecarts : l'ombre est posee sur ce fond
/// translucide, donc multipliee par son opacite (0,4) ; et l'ombre interne de la maquette (un lisere clair
/// d'un point en haut) n'y est pas. Ce dessin ne sert qu'aux captures.
private struct FondDeFiche: ViewModifier {
    @Environment(\.capturePieces) private var capture

    func body(content: Content) -> some View {
        if capture {
            content
                .background(RoundedRectangle(cornerRadius: 22).fill(fondVerreCapture.opacity(0.4))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 8))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
    }
}

/// « 👑 Chef du reseau Thread, elu automatiquement », sous le nom d'un noeud couronne (polissage B,
/// section 3 ; maquette de la fiche, `.chef`) : 10,5 pt, marges de 2 x 8 pt, en capsule, sur une ligne : les
/// colonnes de la fiche, serrees dans une fenetre etroite, ne la font pas passer a la ligne.
struct PastilleChef: View {
    var body: some View {
        Text("👑 Chef du réseau Thread, élu automatiquement")
            .font(.system(size: 10.5))
            .foregroundStyle(Palette.texteChef)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(Palette.jauneChef.opacity(0.16)))
            .overlay(Capsule().strokeBorder(Palette.jauneChef.opacity(0.5), lineWidth: 0.5))
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
