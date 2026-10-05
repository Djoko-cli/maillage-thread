import Foundation

/// Cles des routeurs dans une liste de releves de l'historique (verification du 05/10). La sonde peut perdre puis
/// retrouver l'ExtMac d'un routeur : sans elle, `ReleveMaillage.cle(routeur:)` le range sous "rloc:XXXX", et ses
/// courbes se coupent en deux. Ici, dans un releve ou le routeur d'identifiant `id` n'a pas d'ExtMac, sa cle est
/// l'ExtMac du meme `id`, dans la meme partition, au releve suivant le plus proche qui en a une ; a defaut, au precedent
/// le plus proche ; a defaut des deux, "rloc:XXXX". Une ExtMac que tient deja un autre routeur du releve n'est pas
/// prise (un routeur qui a change d'identifiant, l'ancien encore liste) : deux routeurs d'un releve n'ont jamais la
/// meme cle. Un `id` hors de 0...62 rend "rloc:?".
///
/// Calculee une fois pour toute la liste, et non pour la seule periode affichee : un routeur identifie juste apres la
/// fin de la periode compte. Un passage sur les releves range, par partition et par `id`, les releves qui ont une
/// ExtMac ; une cle se trouve ensuite par dichotomie dans cette liste.
public struct ClesHistorique: Sendable {
    /// Un routeur d'une partition.
    private struct Routeur: Hashable, Sendable {
        let partition: String
        let id: Int
    }

    /// Un releve de la liste ou le routeur a une ExtMac.
    private struct Identifie: Sendable {
        let releve: Int
        let extMac: String
    }

    private let releves: [ReleveMaillage]
    /// Par partition et identifiant : les releves ou le routeur a une ExtMac, par indice croissant.
    private let identifies: [Routeur: [Identifie]]

    /// `releves` : du plus ancien au plus recent.
    public init(releves: [ReleveMaillage]) {
        var identifies: [Routeur: [Identifie]] = [:]
        for (i, r) in releves.enumerated() {
            for x in r.routeurs where ReleveMaillage.identifiantsRouteur.contains(x.id) {
                guard let e = x.extMac else { continue }
                identifies[Routeur(partition: r.partition, id: x.id), default: []].append(Identifie(releve: i, extMac: e))
            }
        }
        self.releves = releves
        self.identifies = identifies
    }

    /// Cle du routeur `id` au releve d'indice `i` de la liste : son ExtMac dans ce releve, sinon celle que donne la
    /// regle (voir le type). Fonction totale : un releve hors de la liste rend "rloc:XXXX".
    public func cle(releve i: Int, routeur id: Int) -> String {
        guard ReleveMaillage.identifiantsRouteur.contains(id) else { return "rloc:?" }
        let rloc = String(format: "rloc:%04X", UInt16(id) << 10)
        guard releves.indices.contains(i), let liste = identifies[Routeur(partition: releves[i].partition, id: id)]
        else { return rloc }
        // Le premier releve de la liste a l'indice `i` ou apres : ce releve lui-meme, ou le suivant le plus proche.
        var bas = 0, haut = liste.count
        while bas < haut {
            let milieu = (bas + haut) / 2
            if liste[milieu].releve < i { bas = milieu + 1 } else { haut = milieu }
        }
        if bas < liste.count, liste[bas].releve == i {
            // Son ExtMac dans ce releve (le premier routeur de cet identifiant, comme `ReleveMaillage.cle(routeur:)`).
            return releves[i].routeurs.first { $0.id == id }?.extMac ?? rloc
        }
        let e = bas < liste.count ? liste[bas].extMac : liste[bas - 1].extMac
        return releves[i].routeurs.contains { $0.extMac == e } ? rloc : e
    }
}
