import AppKit
import MaillageCoeur
import Observation
import ServiceManagement

/// « Exporter pour Maillage IoT… » (spec de Maillage IoT, section 4.2) : un panneau d'enregistrement choisit ou ecrire
/// le dossier d'export ; `ExportReprise` le remplit et le relit ; puis l'app dit le resultat. Rien ne change dans l'app :
/// son dossier est seulement lu, ses reglages aussi (le domaine propre a l'app, jamais les reglages globaux du Mac). Un
/// dossier remplace (le panneau l'a fait confirmer) part a la Corbeille, comme un export commence qui echoue : rien
/// n'est efface pour de bon. Un seul export a la fois : le bandeau et le menu le montrent en cours.
@MainActor
@Observable
final class ExportMaillageIoT {
    static let partage = ExportMaillageIoT()

    /// Lien de telechargement de Maillage IoT, dans le bandeau. Un seul endroit : la phase 5 de la fusion le fixe.
    nonisolated static let lienTelechargement = URL(string: "https://github.com/Djoko-cli/maillage-iot/releases/latest")!

    /// Du panneau d'enregistrement a la derniere alerte.
    private(set) var enCours = false

    /// Montre le panneau d'enregistrement, puis exporte a l'emplacement choisi. Sans effet pendant un export.
    func lancer(ouverture: OuvertureSession) {
        guard !enCours else { return }
        enCours = true
        NSApp.activate()
        let panneau = NSSavePanel()
        panneau.title = String(localized: "Exporter pour Maillage IoT")
        panneau.message = String(localized: "Le dossier d'export reprend l'historique, le journal, les surnoms, les pièces, les noms de Maison et les réglages de Maillage Thread, sans aucun mot de passe ni clé.")
        panneau.prompt = String(localized: "Exporter")
        panneau.nameFieldStringValue = ExportReprise.nomDossier(app: .maillageThread)
        panneau.canCreateDirectories = true
        guard panneau.runModal() == .OK, let url = panneau.url else {
            enCours = false
            return
        }
        Task {
            await exporter(vers: url, ouverture: ouverture)
            enCours = false
        }
    }

    private func exporter(vers url: URL, ouverture: OuvertureSession) async {
        let fm = FileManager.default
        let source = Surveillance.dossierParDefaut
        guard !ExportReprise.chevauche(source, url) else {
            Self.montrerEchec(ExportReprise.Erreur.destinationDansLeDossierDeLApp)
            return
        }
        // Le panneau a fait confirmer le remplacement : l'ancien dossier part a la Corbeille.
        if fm.fileExists(atPath: url.path) {
            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
            } catch {
                Self.montrerEchec(error)
                return
            }
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let reglages = ContratExport.reglagesPersistants(de: .maillageThread)
        // Un echec met de cote (a la Corbeille) le seul dossier que l'export a cree.
        let resultat = await Task.detached(priority: .userInitiated) {
            Result {
                try ExportReprise.exporter(app: .maillageThread, source: source, reglages: reglages, versionApp: version,
                                           vers: url)
            }
        }.value
        switch resultat {
        case .success: Self.montrerReussite(dossier: url, ouverture: ouverture)
        case .failure(let erreur): Self.montrerEchec(erreur)
        }
    }

    /// Proposer « Ne plus ouvrir Maillage Thread a l'ouverture de session » : seulement si l'app s'y ouvre (ou attend
    /// l'approbation dans Reglages Systeme).
    nonisolated static func proposerDesinscription(_ etat: SMAppService.Status) -> Bool {
        etat == .enabled || etat == .requiresApproval
    }

    /// « Export réussi », avec « Ne plus ouvrir Maillage Thread à l'ouverture de session » coche si l'app s'y ouvre :
    /// les deux apps ne doivent pas se disputer la sonde USB au demarrage.
    private static func montrerReussite(dossier: URL, ouverture: OuvertureSession) {
        ouverture.actualiser()
        let alerte = NSAlert()
        alerte.messageText = String(localized: "Export réussi")
        let proposer = proposerDesinscription(ouverture.etat)
        alerte.informativeText = proposer
            ? String(localized: "« \(dossier.lastPathComponent) » est prêt pour Maillage IoT. Maillage Thread continue de marcher comme avant ; s'il s'ouvre encore à l'ouverture de session, les deux apps se disputeront la sonde USB au démarrage.")
            : String(localized: "« \(dossier.lastPathComponent) » est prêt pour Maillage IoT. Maillage Thread continue de marcher comme avant.")
        alerte.addButton(withTitle: String(localized: "OK"))
        alerte.addButton(withTitle: String(localized: "Afficher dans le Finder"))
        if proposer {
            alerte.showsSuppressionButton = true
            alerte.suppressionButton?.title = String(localized: "Ne plus ouvrir Maillage Thread à l'ouverture de session")
            alerte.suppressionButton?.state = .on
        }
        NSApp.activate()
        let reponse = alerte.runModal()
        if reponse == .alertSecondButtonReturn { NSWorkspace.shared.activateFileViewerSelecting([dossier]) }
        guard proposer, alerte.suppressionButton?.state == .on else { return }
        ouverture.basculer(false)
        if let e = ouverture.erreur {
            let echec = NSAlert()
            echec.alertStyle = .warning
            echec.messageText = String(localized: "Maillage Thread s'ouvre encore à l'ouverture de session")
            echec.informativeText = String(localized: "\(e) Le retirer dans Réglages Système › Général › Ouverture et extensions.")
            echec.runModal()
        }
    }

    private static func montrerEchec(_ erreur: Error) {
        let alerte = NSAlert()
        alerte.alertStyle = .warning
        alerte.messageText = String(localized: "L'export n'a pas abouti")
        alerte.informativeText = String(localized: "\(cause(erreur)) Rien n'a changé dans Maillage Thread.")
        NSApp.activate()
        alerte.runModal()
    }

    /// La cause d'un echec, en une phrase : un nom de fichier au plus, jamais un contenu.
    nonisolated static func cause(_ erreur: Error) -> String {
        switch erreur {
        case ExportReprise.Erreur.destinationExistante:
            return String(localized: "Un dossier porte déjà ce nom.")
        case ExportReprise.Erreur.destinationDansLeDossierDeLApp:
            return String(localized: "Le dossier d'export ne peut pas être dans le dossier des données de Maillage Thread.")
        case ExportReprise.Erreur.dossierIllisible(let chemin):
            return String(localized: "Le dossier « \(chemin) » des données de Maillage Thread est illisible.")
        case let e as ContratExport.Erreur:
            switch e {
            case .fichierManquant(let chemin):
                return String(localized: "Le fichier « \(chemin) » manque dans l'export.")
            case .tailleFausse(let chemin), .empreinteFausse(let chemin):
                return String(localized: "Le fichier « \(chemin) » a changé pendant l'export.")
            case .lienSymbolique(let chemin):
                return String(localized: "« \(chemin) » est un lien symbolique.")
            default:
                return String(localized: "L'export a été écrit, mais sa vérification a échoué.")
            }
        default:
            return erreur.localizedDescription
        }
    }
}
