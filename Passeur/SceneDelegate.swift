import UIKit

/// La scene que macOS 27 impose (une app UIKit sans scene s'arrete au lancement) : sans contenu, refermee des sa
/// connexion. Elle porte aussi les URL des apps : a la connexion d'une scene neuve (`urlContexts`), ou a une scene
/// encore la (`openURLContexts`).
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        transmettre(options.urlContexts)
        UIApplication.shared.requestSceneSessionDestruction(session, options: nil) { erreur in
            journal.error("scène non refermée : \(String(describing: erreur), privacy: .public)")
        }
    }

    func scene(_ scene: UIScene, openURLContexts contextes: Set<UIOpenURLContext>) {
        transmettre(contextes)
    }

    private func transmettre(_ contextes: Set<UIOpenURLContext>) {
        guard !contextes.isEmpty else { return }
        (UIApplication.shared.delegate as? AppDelegate)?.recevoir(contextes.map(\.url))
    }
}
