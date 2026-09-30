import Foundation

/// Envoi du releve du passeur a l'app par la boucle locale du Mac (TCP sur 127.0.0.1), sans
/// dossier partage ni App Group :
/// 1. l'app ecoute sur 127.0.0.1, sur un port choisi par le systeme, et tire un jeton a usage unique ;
/// 2. elle lance le passeur sans l'activer, avec `--port <port> --jeton <jeton>` (`Cible`) ;
/// 3. le passeur lit Maison, se connecte et envoie la trame : le jeton sur une ligne, la longueur
///    du JSON (entier decimal) sur une ligne, puis le JSON de `NomsMaison` ; puis il se ferme ;
/// 4. l'app verifie le jeton, en comparaison a temps constant, et lit au plus `tailleMax` octets
///    de JSON (`Lecture`).
/// Commun a l'app et au passeur, qui compile ce fichier (`project.yml`).
public enum EnvoiPasseur {
    /// JSON lu au plus par l'app : 8 Mo (le releve du 30/09, 133 accessoires, en fait 32 Ko).
    public static let tailleMax = 8 * 1024 * 1024
    /// Jeton : autant d'octets aleatoires, en chiffres hexadecimaux (64).
    public static let octetsJeton = 32

    /// Ou le passeur envoie le releve : port et jeton, donnes par ses arguments de lancement.
    public struct Cible: Hashable, Sendable {
        public var port: UInt16
        public var jeton: String

        public init(port: UInt16, jeton: String) {
            self.port = port
            self.jeton = jeton
        }

        /// Arguments de lancement du passeur.
        public var arguments: [String] { ["--port", String(port), "--jeton", jeton] }

        /// Lue dans les arguments du passeur, parmi d'autres ; nil s'il a ete ouvert a la main
        /// (ni port ni jeton), ou si l'un d'eux est illisible.
        public init?(arguments: [String]) {
            func valeur(_ option: String) -> String? {
                guard let i = arguments.firstIndex(of: option), i + 1 < arguments.count else { return nil }
                return arguments[i + 1]
            }
            guard let port = valeur("--port").flatMap({ UInt16($0) }), port != 0,
                  let jeton = valeur("--jeton"), !jeton.isEmpty else { return nil }
            self.init(port: port, jeton: jeton)
        }
    }

    /// Jeton neuf : `octetsJeton` octets du generateur aleatoire du systeme (cryptographique),
    /// en hexadecimal minuscule.
    public static func nouveauJeton() -> String {
        var generateur = SystemRandomNumberGenerator()
        let chiffres = Array("0123456789abcdef")
        var jeton = ""
        for _ in 0..<octetsJeton {
            let o = UInt8.random(in: .min ... .max, using: &generateur)
            jeton.append(chiffres[Int(o >> 4)])
            jeton.append(chiffres[Int(o & 0x0F)])
        }
        return jeton
    }

    /// Trame envoyee par le passeur.
    public static func trame(jeton: String, json: Data) -> Data {
        Data("\(jeton)\n\(json.count)\n".utf8) + json
    }

    /// Lecture d'une trame par l'app, au fil des octets recus.
    public struct Lecture: Sendable {
        public enum Issue: Equatable, Sendable {
            /// Il faut d'autres octets.
            case incomplete
            /// Le JSON, de la longueur annoncee ; ce qui le suit est ignore.
            case json(Data)
            /// Premiere ligne autre que le jeton attendu, ou connexion fermee avant sa fin.
            case jetonFaux
            /// Longueur illisible, nulle ou au-dela de `tailleMax`, ou trame plus courte qu'annoncee.
            case longueurFausse
        }

        private enum Etape: Sendable {
            case jeton, longueur
            case json(Int)
            case finie(Issue)
        }

        private enum Ligne {
            case manque, tropLongue
            case ligne([UInt8])
        }

        /// Chiffres d'une longueur, au plus (`tailleMax` en a 7). Seize chiffres valent moins de
        /// 10^16, sous `Int.max` (19 chiffres en 64 bits) : le calcul de `entier` ne deborde pas.
        static let chiffresMax = 16

        private let attendu: [UInt8]
        private var tampon = Data()
        private var etape = Etape.jeton

        public init(jeton: String) {
            attendu = Array(jeton.utf8)
        }

        /// Ajoute des octets recus ; rend l'issue, `incomplete` tant qu'il en faut d'autres.
        /// Une fois connue, l'issue ne change plus.
        public mutating func ajouter(_ octets: Data) -> Issue {
            if case .finie(let issue) = etape { return issue }
            tampon.append(octets)
            while true {
                switch etape {
                case .finie(let issue):
                    return issue
                case .jeton:
                    switch prendreLigne(auPlus: attendu.count) {
                    case .manque: return .incomplete
                    case .tropLongue: return finir(.jetonFaux)
                    case .ligne(let l):
                        guard Self.egaux(l, attendu) else { return finir(.jetonFaux) }
                        etape = .longueur
                    }
                case .longueur:
                    switch prendreLigne(auPlus: Self.chiffresMax) {
                    case .manque: return .incomplete
                    case .tropLongue: return finir(.longueurFausse)
                    case .ligne(let l):
                        guard let n = Self.entier(l), n > 0, n <= EnvoiPasseur.tailleMax else {
                            return finir(.longueurFausse)
                        }
                        etape = .json(n)
                    }
                case .json(let n):
                    guard tampon.count >= n else { return .incomplete }
                    return finir(.json(Data(tampon.prefix(n))))
                }
            }
        }

        /// La connexion s'est fermee : une trame inachevee est fausse.
        public func fin() -> Issue {
            switch etape {
            case .finie(let issue): issue
            case .jeton: .jetonFaux
            case .longueur, .json: .longueurFausse
            }
        }

        /// Premiere ligne du tampon, sans sa fin, retiree du tampon : au plus `max` octets.
        private mutating func prendreLigne(auPlus max: Int) -> Ligne {
            guard let fin = tampon.firstIndex(of: 0x0A) else {
                return tampon.count > max ? .tropLongue : .manque
            }
            let ligne = Array(tampon[tampon.startIndex..<fin])
            tampon.removeSubrange(tampon.startIndex...fin)
            return ligne.count > max ? .tropLongue : .ligne(ligne)
        }

        private mutating func finir(_ issue: Issue) -> Issue {
            etape = .finie(issue)
            tampon = Data()
            return issue
        }

        /// Entier ecrit en chiffres decimaux seuls (ni signe ni espace).
        static func entier(_ l: [UInt8]) -> Int? {
            guard !l.isEmpty, l.count <= chiffresMax, l.allSatisfy({ (0x30...0x39).contains($0) }) else { return nil }
            return l.reduce(0) { $0 * 10 + Int($1 - 0x30) }
        }

        /// Comparaison a temps constant : sa duree ne depend pas de la place du premier ecart.
        /// Jamais vraie face a un jeton attendu vide : il ne laisse rien passer.
        static func egaux(_ a: [UInt8], _ b: [UInt8]) -> Bool {
            guard !b.isEmpty else { return false }
            guard a.count == b.count else { return false }
            var ecart: UInt8 = 0
            for (x, y) in zip(a, b) { ecart |= x ^ y }
            return ecart == 0
        }
    }
}
