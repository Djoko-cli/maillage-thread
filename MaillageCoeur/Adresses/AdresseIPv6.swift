import Darwin

/// Adresse IPv6 : 16 octets. Lue depuis le texte (avec ou sans zone "%en0"),
/// ecrite sous la forme courte de inet_ntop ("fd2d:3b27:72b8:0:2c97:...").
public struct AdresseIPv6: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let octets: [UInt8]

    public init?(octets: [UInt8]) {
        guard octets.count == 16 else { return nil }
        self.octets = octets
    }

    public init?(_ texte: String) {
        let sansZone = String(texte.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
        var brut = in6_addr()
        guard inet_pton(AF_INET6, sansZone, &brut) == 1 else { return nil }
        octets = withUnsafeBytes(of: brut) { Array($0) }
    }

    public var description: String {
        var brut = in6_addr()
        withUnsafeMutableBytes(of: &brut) { $0.copyBytes(from: octets) }
        var tampon = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        let taille = socklen_t(tampon.count)
        guard inet_ntop(AF_INET6, &brut, &tampon, taille) != nil else { return "::" }
        return tampon.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    /// fe80::/10 : adresse de lien, jamais routee.
    public var estLienLocal: Bool { octets[0] == 0xFE && (octets[1] & 0xC0) == 0x80 }

    /// Prefixe /64 de l'adresse.
    public var prefixe: PrefixeIPv6 { PrefixeIPv6(huitOctets: Array(octets[0..<8])) }

    public static func < (a: AdresseIPv6, b: AdresseIPv6) -> Bool {
        a.octets.lexicographicallyPrecedes(b.octets)
    }

    /// Texte d'une adresse IPv4 valide ("192.168.1.19").
    public static func estIPv4(_ texte: String) -> Bool {
        var brut = in_addr()
        return inet_pton(AF_INET, texte, &brut) == 1
    }
}
