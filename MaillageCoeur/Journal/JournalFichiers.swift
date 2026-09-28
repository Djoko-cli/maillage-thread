import Foundation

/// Journal sur disque : JSON Lines, un fichier par mois ("journal-2026-09.jsonl",
/// mois du calendrier local), un fichier supprime quand son mois est fini depuis
/// plus de 90 jours.
public struct JournalFichiers: Sendable {
    public static let conservation: TimeInterval = 90 * 24 * 3600

    public let dossier: URL
    public let calendrier: Calendar

    public init(dossier: URL, calendrier: Calendar = .current) {
        self.dossier = dossier
        self.calendrier = calendrier
    }

    /// Nom du fichier du mois d'une date.
    public func nomFichier(_ date: Date) -> String {
        let c = calendrier.dateComponents([.year, .month], from: date)
        return String(format: "journal-%04d-%02d.jsonl", c.year ?? 0, c.month ?? 0)
    }

    /// Ajoute les evenements a la fin du fichier de leur mois.
    public func ajouter(_ evenements: [Evenement]) throws {
        guard !evenements.isEmpty else { return }
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let encodeur = CodageJSON.encodeur()
        for (nom, groupe) in Dictionary(grouping: evenements, by: { nomFichier($0.date) }) {
            var donnees = Data()
            for e in groupe {
                donnees.append(try encodeur.encode(e))
                donnees.append(0x0A)
            }
            let url = dossier.appendingPathComponent(nom)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let f = try FileHandle(forWritingTo: url)
            defer { try? f.close() }
            try f.seekToEnd()
            try f.write(contentsOf: donnees)
        }
    }

    /// Tous les evenements gardes, du plus ancien au plus recent ; une ligne
    /// illisible est ignoree.
    public func lire() throws -> [Evenement] {
        let decodeur = CodageJSON.decodeur()
        var tous: [Evenement] = []
        for url in try fichiers() {
            let texte = try String(contentsOf: url, encoding: .utf8)
            for ligne in texte.split(separator: "\n") where !ligne.isEmpty {
                if let e = try? decodeur.decode(Evenement.self, from: Data(ligne.utf8)) { tous.append(e) }
            }
        }
        return tous.enumerated().sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }.map(\.element)
    }

    /// Supprime les fichiers des mois finis depuis plus de 90 jours ; rend leurs noms.
    @discardableResult
    public func purger(maintenant: Date) throws -> [String] {
        var supprimes: [String] = []
        for url in try fichiers() {
            guard let fin = finDuMois(url.lastPathComponent),
                  maintenant.timeIntervalSince(fin) > Self.conservation else { continue }
            try FileManager.default.removeItem(at: url)
            supprimes.append(url.lastPathComponent)
        }
        return supprimes
    }

    /// Fichiers du journal, dans l'ordre des mois.
    func fichiers() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: dossier.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: dossier, includingPropertiesForKeys: nil)
            .filter { finDuMois($0.lastPathComponent) != nil }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Debut du mois suivant pour "journal-AAAA-MM.jsonl", nil pour un autre nom.
    func finDuMois(_ nom: String) -> Date? {
        let m = nom.wholeMatch(of: /journal-(\d{4})-(\d{2})\.jsonl/)
        guard let m, let annee = Int(m.output.1), let mois = Int(m.output.2),
              let debut = calendrier.date(from: DateComponents(year: annee, month: mois, day: 1)) else { return nil }
        return calendrier.date(byAdding: .month, value: 1, to: debut)
    }
}
