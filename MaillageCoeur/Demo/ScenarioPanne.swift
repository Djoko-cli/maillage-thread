import Foundation

/// Panne du 27/09/2026 (heures du Mac, UTC+4), reconstituee a partir du releve
/// du 28/09 et du journal de halo-routes, pour les tests et le mode demo :
/// - 03:55 : reseau sain, une partition, prefixe OMR fd77:9e:f4bb::/64 ;
/// - 04:04:03 : l'Apple TV (chef) change d'adresse de lien (redemarrage) et
///   publie fd2d:3b27:72b8::/64 ; a 04:06 les appareils y passent, fd77 part ;
/// - 04:14 : l'Aqara HubM100 se retrouve seul dans la partition E6A6AD72 ;
///   1EA39E8E72FC9ADA perd son adresse ;
/// - 04:15, 04:16, 04:18, 04:20 : quatre appareils disparaissent.
/// Illustratif : les appareils perdus, leurs heures et l'ancienne adresse de
/// lien de l'Apple TV sont choisis, pas releves.
public enum ScenarioPanne {
    public static let fuseau = TimeZone(secondsFromGMT: 4 * 3600)!

    /// 27/09/2026 a h:m:s, heure du Mac.
    public static func date(_ h: Int, _ m: Int, _ s: Int = 0) -> Date {
        var c = DateComponents(year: 2026, month: 9, day: 27, hour: h, minute: m, second: s)
        c.timeZone = fuseau
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    public static let debut = date(3, 55)
    public static let fin = date(4, 30)

    /// Releves toutes les 60 s, de 03:55 a 04:30.
    public static var releves: [Annonces] {
        (0...35).map { annonces(a: debut.addingTimeInterval(TimeInterval($0) * 60)) }
    }

    public static let sansAdresse = "1EA39E8E72FC9ADA"
    /// Appareils qui disparaissent, et quand.
    public static let perdus: [(hote: String, absentDes: Date)] = [
        ("46D9C54DAA6079AC", date(4, 15)), ("7A9DABB000AD621D", date(4, 16)),
        ("D60E698E80D7DA48", date(4, 18)), ("FAD7066DD54C259D", date(4, 20)),
    ]

    static let lienAncienATV = "fe80::4e:ff54:91ca:c700"
    static let lienATV = "fe80::4e:ff54:91ca:c791"
    static let lienHomePodMiniBureau = "fe80::cb5:8b5f:9a0a:cf65"
    static let lienHomePodGauche = "fe80::8f:a8ba:71c8:122b"
    static let lienAqara = "fe80::56ef:44ff:fe8d:15e5"
    static let fd77 = "fd77:9e:f4bb:0:"
    static let fd2d = "fd2d:3b27:72b8:0:"

    public static func annonces(a t: Date) -> Annonces {
        var a = Releve20260928.annonces
        a.date = t
        a.note = "Scénario reconstitué de la panne du 27/09/2026."
        let redemarrage = date(4, 4, 3)
        let bascule = date(4, 6)
        let scission = date(4, 14)
        let prefixe = t < bascule ? fd77 : fd2d

        // Routeurs : adresse de lien de l'Apple TV, partition et etat de l'Aqara.
        let ancienLien = t < redemarrage ? lienAncienATV : lienATV
        a.adresses["Apple-TV-4K.local"] = a.adresses["Apple-TV-4K.local"]?.map { $0 == lienATV ? ancienLien : $0 }
        a.adresses["HomePod-mini-bureau.local"] = a.adresses["HomePod-mini-bureau.local"]?
            .map { $0.hasPrefix("fe80::") ? lienHomePodMiniBureau : $0 }
        if t < scission, let i = a.routeurs.firstIndex(where: { $0.instance == "Aqara HubM100 #80E0" }) {
            var v = a.routeurs[i].txt.valeurs
            v["pt"] = Data([0x7C, 0x6A, 0x2A, 0x68])
            v["sb"] = Data([0x00, 0x00, 0x00, 0xB1])   // BBR actif, pas primaire
            a.routeurs[i].txt = ChampsTXT(v)
        }

        // Routes du Mac.
        var routes: [RouteIPv6] = []
        if t < bascule { routes.append(RouteIPv6(prefixe: "fd77:9e:f4bb::/64", passerelle: lienHomePodMiniBureau, interface: "en0")) }
        if t >= redemarrage { routes.append(RouteIPv6(prefixe: "fd2d:3b27:72b8::/64", passerelle: lienATV, interface: "en0")) }
        routes.append(RouteIPv6(prefixe: "fd0d:eec8:5ef:1::/64", passerelle: t < scission ? lienHomePodGauche : lienAqara,
                                interface: "en0"))
        a.routes = routes

        // Appareils : prefixe courant, 72FB avec son adresse de 00:42, 1EA3, perdus.
        a.adresses["72FBDA00C4A43024.local"] = [fd2d + "9761:3362:c2d8:3da5"]
        a.adresses[sansAdresse + ".local"] = t < scission ? [fd2d + "1ea3:9e8e:72fc:9ada"] : []
        for (hote, liste) in a.adresses where !liste.isEmpty {
            a.adresses[hote] = liste.map { $0.hasPrefix(fd2d) ? prefixe + $0.dropFirst(fd2d.count) : $0 }
        }
        for (hote, absentDes) in perdus where t >= absentDes {
            a.matter.removeAll { $0.hote == hote + ".local" }
            a.adresses[hote + ".local"] = nil
        }
        return a
    }
}
