import Foundation

/// L'export pour Maillage IoT (spec de Maillage IoT, section 4.2), sans interface : un dossier que
/// `ContratExport.verifierDossier` relit sans erreur. Le contrat dit quoi copier et comment le decrire ; ici, on le fait :
/// - lister les fichiers de `Application Support/<app>/` (un lien symbolique n'est jamais suivi : il est cite) ;
/// - copier ceux que `ContratExport.classerFichiers` retient, sous le meme chemin, octet pour octet (le contenu seul,
///   sans les attributs etendus, qui laisseraient des fichiers `._<nom>` sur un volume FAT ou exFAT) ;
/// - ecrire `reglages.json`, puis decrire chaque COPIE (jamais l'original, que l'app continue d'ecrire) ;
/// - ecrire `manifeste.json`, puis relire tout le dossier avant de rendre le manifeste.
/// Le dossier de l'app est seulement lu : l'app continue de marcher comme avant.
public enum ExportReprise {
    public enum Erreur: Error, Equatable, Sendable {
        /// Quelque chose existe deja a la destination : l'export ne le touche jamais (l'app le met a la Corbeille
        /// avant, apres la confirmation du panneau d'enregistrement).
        case destinationExistante
        /// La destination est le dossier de l'app, ou dedans, ou le contient : refusee avant toute ecriture.
        case destinationDansLeDossierDeLApp
        /// Un dossier sous celui de l'app n'a pas pu etre parcouru (son chemin relatif) : rien n'est perdu en silence.
        case dossierIllisible(String)
    }

    /// Ecrit l'export de `app` dans `destination`, un dossier qui ne doit pas exister. `source` : le dossier de
    /// l'app sous `Application Support` (absent : seuls les reglages sont exportes). Rend le manifeste relu par
    /// `verifierDossier`. En cas d'erreur apres la creation du dossier, celui-ci (et lui seul : jamais un element qui
    /// etait deja la) est passe a `mettreDeCote` (la Corbeille dans l'app), puis l'erreur est rendue.
    public static func exporter(app: ContratExport.AppSource, source: URL, reglages: ContratExport.Reglages,
                                versionApp: String, date: Date = Date(), identifiant: UUID = UUID(),
                                vers destination: URL,
                                mettreDeCote: (URL) -> Void = { try? FileManager.default.trashItem(at: $0, resultingItemURL: nil) })
        throws -> ContratExport.Manifeste {
        let fm = FileManager.default
        guard !chevauche(source, destination) else { throw Erreur.destinationDansLeDossierDeLApp }
        if fm.fileExists(atPath: destination.path)
            || (try? destination.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            throw Erreur.destinationExistante
        }
        let (fichiers, liens) = try fichiersVus(dans: source)
        let classe = try ContratExport.classerFichiers(vus: fichiers, de: app)
        // Les noms reserves a la racine sont ecartes, comme le contrat le fait pour les fichiers ordinaires.
        let nonRepris = classe.nonRepris + liens.filter { !estReserve($0) }
            .map { ContratExport.FichierNonRepris(chemin: $0, raison: .horsContrat) }

        try fm.createDirectory(at: destination, withIntermediateDirectories: false)
        do {
            var decrits: [ContratExport.Fichier] = []
            for chemin in classe.aCopier {
                let cible = try ContratExport.resoudre(chemin, dans: destination)
                try fm.createDirectory(at: cible.deletingLastPathComponent(), withIntermediateDirectories: true)
                do {
                    try copier(source.appendingPathComponent(chemin), vers: cible)
                } catch CocoaError.fileReadNoSuchFile where ContratExport.mois(de: chemin) != nil {
                    // Un mois purge par l'app pendant l'export (plus de 90 jours) : elle l'a voulu, il n'est plus la.
                    try? fm.removeItem(at: cible)
                    continue
                }
                decrits.append(try ContratExport.Fichier.decrire(chemin: chemin, dans: destination))
            }
            try ContratExport.ecrire(reglages).write(to: try ContratExport.resoudre(ContratExport.nomReglages,
                                                                                    dans: destination))
            decrits.append(try ContratExport.Fichier.decrire(chemin: ContratExport.nomReglages, dans: destination))

            let manifeste = ContratExport.Manifeste(identifiant: identifiant, app: app, versionApp: versionApp,
                                                    date: date, fichiers: decrits, fichiersNonRepris: nonRepris)
            try ContratExport.ecrire(manifeste).write(to: try ContratExport.resoudre(ContratExport.nomManifeste,
                                                                                     dans: destination))
            return try ContratExport.verifierDossier(destination).0
        } catch {
            mettreDeCote(destination)
            throw error
        }
    }

    /// `manifeste.json` ou `reglages.json` a la racine, a la casse et a la normalisation Unicode pres.
    static func estReserve(_ chemin: String) -> Bool {
        [ContratExport.nomManifeste, ContratExport.nomReglages]
            .contains(chemin.precomposedStringWithCanonicalMapping.lowercased())
    }

    /// Les deux chemins sont le meme dossier, ou l'un est dans l'autre (liens symboliques resolus).
    public static func chevauche(_ a: URL, _ b: URL) -> Bool {
        let x = a.resolvingSymlinksInPath().standardizedFileURL.path
        let y = b.resolvingSymlinksInPath().standardizedFileURL.path
        return x == y || x.hasPrefix(y.hasSuffix("/") ? y : y + "/") || y.hasPrefix(x.hasSuffix("/") ? x : x + "/")
    }

    /// Copie le contenu de `source` dans `cible` (nouveau fichier), par blocs de 1 Mio, sans les attributs.
    static func copier(_ source: URL, vers cible: URL) throws {
        let lecteur: FileHandle
        do {
            lecteur = try FileHandle(forReadingFrom: source)
        } catch let e as NSError where e.domain == NSCocoaErrorDomain && e.code == NSFileReadNoSuchFileError {
            throw CocoaError(.fileReadNoSuchFile)
        }
        defer { try? lecteur.close() }
        guard FileManager.default.createFile(atPath: cible.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: cible.path])
        }
        let ecrivain = try FileHandle(forWritingTo: cible)
        defer { try? ecrivain.close() }
        while try autoreleasepool(invoking: {
            guard let bloc = try lecteur.read(upToCount: 1 << 20), !bloc.isEmpty else { return false }
            try ecrivain.write(contentsOf: bloc)
            return true
        }) {}
    }

    /// Les fichiers ordinaires sous `dossier` et les autres elements qui ne sont pas des dossiers (liens symboliques
    /// surtout), en chemins relatifs avec des `/`, fichiers caches compris (`.DS_Store` doit etre cite). Un lien vers
    /// un dossier est cite, jamais parcouru. Dossier absent : deux listes vides. Un sous-dossier illisible fait
    /// echouer (`Erreur.dossierIllisible`).
    static func fichiersVus(dans dossier: URL) throws -> (fichiers: [String], liens: [String]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dossier.path) else { return ([], []) }
        let base = dossier.resolvingSymlinksInPath().standardizedFileURL
        func relatif(_ url: URL) -> String { String(url.standardizedFileURL.path.dropFirst(base.path.count + 1)) }
        let cles: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        var illisible: String?
        guard let e = fm.enumerator(at: base, includingPropertiesForKeys: cles, errorHandler: { url, _ in
            illisible = illisible ?? relatif(url)
            return false
        }) else { throw Erreur.dossierIllisible("") }
        var fichiers: [String] = [], liens: [String] = []
        for case let url as URL in e {
            let v = try url.resourceValues(forKeys: Set(cles))
            if v.isDirectory == true, v.isSymbolicLink != true { continue }
            if v.isSymbolicLink != true, v.isRegularFile == true { fichiers.append(relatif(url)) } else { liens.append(relatif(url)) }
        }
        if let illisible { throw Erreur.dossierIllisible(illisible) }
        return (fichiers.sorted(), liens.sorted())
    }

    /// Nom propose par le panneau d'enregistrement : « Export Maillage Thread 2026-10-17 », la date du jour dans
    /// le fuseau du Mac.
    public static func nomDossier(app: ContratExport.AppSource, date: Date = Date(), fuseau: TimeZone = .current) -> String {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = fuseau
        let c = calendrier.dateComponents([.year, .month, .day], from: date)
        return String(format: "Export %@ %04d-%02d-%02d", app.nomApp, c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
