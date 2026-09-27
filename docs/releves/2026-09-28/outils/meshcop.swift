import Foundation
import Network

// Routeurs de bordure Thread (_meshcop._udp) : champs TXT decodes.
func hexa(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined() }
func u32(_ d: Data) -> UInt32 { d.reduce(0) { ($0 << 8) | UInt32($1) } }
let navigateur = NWBrowser(for: .bonjourWithTXTRecord(type: "_meshcop._udp", domain: nil), using: .udp)
var vus = [String: String]()
navigateur.browseResultsChangedHandler = { resultats, _ in
    for r in resultats {
        guard case .service(let nom, _, _, _) = r.endpoint, case .bonjour(let txt) = r.metadata else { continue }
        func d(_ k: String) -> Data? { if case .data(let v)? = txt.getEntry(for: k) { return v }; if case .string(let s)? = txt.getEntry(for: k) { return Data(s.utf8) }; return nil }
        func s(_ k: String) -> String { d(k).map { String(decoding: $0, as: UTF8.self) } ?? "-" }
        var ligne = "\(nom) | \(s("vn")) \(s("mn")) tv=\(s("tv")) | nn=\(s("nn")) xp=\(d("xp").map(hexa) ?? "-")"
        if let pt = d("pt") { ligne += " | partition=\(hexa(pt))" }
        if let at = d("at"), at.count == 8 {
            let sec = at.prefix(6).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            let date = Date(timeIntervalSince1970: TimeInterval(sec))
            ligne += " | jeu actif du \(date.formatted(.iso8601.year().month().day()))"
        }
        if let sb = d("sb") {
            let v = u32(sb)
            let role = ["detache/desactive", "enfant", "routeur", "CHEF (leader)"][Int((v >> 9) & 3)]
            let iface = ["non initialisee", "inactive", "active"][min(2, Int((v >> 3) & 3))]
            ligne += " | interface \(iface), role \(role), BBR \((v >> 7) & 1 == 1 ? ((v >> 8) & 1 == 1 ? "primaire" : "actif") : "non")"
        }
        if let omr = d("omr") { ligne += " | omr=\(hexa(omr))" }
        vus[nom] = ligne
    }
}
navigateur.start(queue: .main)
DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    for (_, l) in vus.sorted(by: { $0.key < $1.key }) { print(l) }
    exit(0)
}
dispatchMain()
