import Foundation
import MaillageCoeur
import ServiceManagement
import Testing
@testable import MaillageThread

/// L'export pour Maillage IoT, cote app : ce que le contrat suppose de l'app, la proposition de ne plus s'ouvrir a
/// l'ouverture de session, et les causes d'echec montrees.
@MainActor
@Suite("Export pour Maillage IoT : l'app")
struct ExportMaillageIoTTests {
    /// Le contrat lit les reglages du domaine `identifiantBundle` et les fichiers du dossier `dossierDonnees` : ce
    /// doivent etre ceux de l'app, sinon l'export « reussirait » avec des reglages vides ou un autre dossier.
    @Test func lAppEstCelleDuContrat() {
        #expect(Bundle.main.bundleIdentifier == ContratExport.AppSource.maillageThread.identifiantBundle)
        #expect(Surveillance.dossierParDefaut.lastPathComponent == ContratExport.AppSource.maillageThread.dossierDonnees)
    }

    @Test func propositionSeulementSiLAppSOuvreALaSession() {
        #expect(ExportMaillageIoT.proposerDesinscription(.enabled))
        #expect(ExportMaillageIoT.proposerDesinscription(.requiresApproval))
        #expect(!ExportMaillageIoT.proposerDesinscription(.notRegistered))
        #expect(!ExportMaillageIoT.proposerDesinscription(.notFound))
    }

    /// Une phrase par cause, avec un nom de fichier au plus.
    @Test func causes() {
        let f = "surnoms.json"
        let cas: [(Error, String)] = [
            (ExportReprise.Erreur.destinationExistante, String(localized: "Un dossier porte déjà ce nom.")),
            (ExportReprise.Erreur.destinationDansLeDossierDeLApp,
             String(localized: "Le dossier d'export ne peut pas être dans le dossier des données de Maillage Thread.")),
            (ExportReprise.Erreur.dossierIllisible("Journal"),
             String(localized: "Le dossier « \("Journal") » des données de Maillage Thread est illisible.")),
            (ContratExport.Erreur.fichierManquant(f), String(localized: "Le fichier « \(f) » manque dans l'export.")),
            (ContratExport.Erreur.empreinteFausse(f), String(localized: "Le fichier « \(f) » a changé pendant l'export.")),
            (ContratExport.Erreur.tailleFausse(f), String(localized: "Le fichier « \(f) » a changé pendant l'export.")),
            (ContratExport.Erreur.lienSymbolique("lien"), String(localized: "« \("lien") » est un lien symbolique.")),
            (ContratExport.Erreur.appDifferente, String(localized: "L'export a été écrit, mais sa vérification a échoué.")),
        ]
        for (erreur, texte) in cas {
            #expect(ExportMaillageIoT.cause(erreur) == texte)
        }
    }
}
