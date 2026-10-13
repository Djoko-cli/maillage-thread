import Foundation

/// Le nom d'un accessoire tel que Maison l'affiche sur sa vignette. Maison montre le nom du service principal de
/// l'accessoire, et renommer une vignette change le nom de ce service, pas celui de l'accessoire (banc du 13/10).
/// Le releve prend donc le nom du service principal, et celui de l'accessoire a defaut.
enum NomAccessoire {
    static func affiche(accessoire: String, servicePrincipal: String?) -> String {
        guard let service = servicePrincipal,
              !service.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return accessoire }
        return service
    }
}
