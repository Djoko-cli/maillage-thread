import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Envoi du releve du passeur par la boucle locale")
struct EnvoiPasseurTests {
    static let jeton = String(repeating: "5a", count: 32)
    static let json = Data(#"{"accessoires":[],"date":"2026-09-30T12:00:00.000Z","statut":"ok","version":1}"#.utf8)

    /// Lit des octets arrives en paquets de `taille` : la premiere issue connue, ou celle de la
    /// fermeture de la connexion apres le dernier paquet.
    static func lire(_ octets: Data, par taille: Int, jeton: String = jeton) -> EnvoiPasseur.Lecture.Issue {
        var l = EnvoiPasseur.Lecture(jeton: jeton)
        var i = octets.startIndex
        while i < octets.endIndex {
            let j = min(i + taille, octets.endIndex)
            let issue = l.ajouter(octets[i..<j])
            if issue != .incomplete { return issue }
            i = j
        }
        return l.fin()
    }

    /// Lit un texte comme l'URL du passeur. Un texte qui n'est meme pas une URL fait echouer le
    /// test : sans cela, une faute de frappe passerait pour une URL refusee.
    static func cible(url texte: String) -> EnvoiPasseur.Cible? {
        guard let url = URL(string: texte) else {
            Issue.record("texte qui n'est pas une URL : \(texte)")
            return nil
        }
        return EnvoiPasseur.Cible(url: url)
    }

    /// Port et jeton passent par l'URL que l'app ouvre avec le passeur, et s'y relisent : le
    /// texte exact de l'URL, puis l'aller-retour.
    @Test func url() {
        let c = EnvoiPasseur.Cible(port: 54_321, jeton: Self.jeton)
        #expect(c.url.absoluteString == "maillage-passeur://releve?port=54321&jeton=\(Self.jeton)")
        #expect(EnvoiPasseur.Cible(url: c.url) == c)
        for port: UInt16 in [1, 80, 65_535] {
            let autre = EnvoiPasseur.Cible(port: port, jeton: Self.jeton)
            #expect(EnvoiPasseur.Cible(url: autre.url) == autre, "port \(port)")
        }
    }

    /// Une URL qui n'est pas celle du passeur ne donne pas de cible : autre schema, autre hote,
    /// jeton absent ou vide, port absent, vide, nul, trop grand, illisible ou signe.
    @Test func urlRefusee() {
        let j = Self.jeton
        #expect(Self.cible(url: "https://releve?port=54321&jeton=\(j)") == nil, "autre schema")
        #expect(Self.cible(url: "maillage-passeur://autre?port=54321&jeton=\(j)") == nil, "autre hote")
        #expect(Self.cible(url: "maillage-passeur://releve?port=54321") == nil, "sans jeton")
        #expect(Self.cible(url: "maillage-passeur://releve?port=54321&jeton=") == nil, "jeton vide")
        #expect(Self.cible(url: "maillage-passeur://releve?jeton=\(j)") == nil, "sans port")
        #expect(Self.cible(url: "maillage-passeur://releve") == nil, "sans requete")
        for port in ["", "0", "70000", "abc", "-1"] {
            #expect(Self.cible(url: "maillage-passeur://releve?port=\(port)&jeton=\(j)") == nil, "port « \(port) »")
        }
    }

    /// Le reste de l'URL ne gene pas la lecture : un parametre de plus, l'autre ordre, le schema
    /// et l'hote en majuscules.
    @Test func urlTolerante() {
        let c = EnvoiPasseur.Cible(port: 54_321, jeton: Self.jeton)
        #expect(Self.cible(url: c.url.absoluteString + "&x=1") == c, "un parametre de plus")
        #expect(Self.cible(url: "maillage-passeur://releve?x=1&jeton=\(Self.jeton)&port=54321") == c, "autre ordre")
        #expect(Self.cible(url: "MAILLAGE-PASSEUR://RELEVE?port=54321&jeton=\(Self.jeton)") == c, "majuscules")
    }

    /// Jeton a usage unique : 32 octets aleatoires, en 64 chiffres hexadecimaux, neuf a chaque tirage.
    @Test func jeton() {
        let a = EnvoiPasseur.nouveauJeton()
        #expect(a.count == 64)
        #expect(a.allSatisfy { "0123456789abcdef".contains($0) })
        #expect(a != EnvoiPasseur.nouveauJeton())
    }

    /// Trame : le jeton sur une ligne, la longueur du JSON sur une ligne, puis le JSON. Elle se
    /// relit quel que soit son decoupage en paquets ; ce qui suit le JSON est ignore.
    @Test func trameLueParMorceaux() {
        let t = EnvoiPasseur.trame(jeton: Self.jeton, json: Self.json)
        #expect(t == Data("\(Self.jeton)\n\(Self.json.count)\n".utf8) + Self.json)
        for taille in [1, 2, 7, 64, 65, 66, 1000, t.count] {
            #expect(Self.lire(t, par: taille) == .json(Self.json), "paquets de \(taille)")
        }
        #expect(Self.lire(t + Data("reste".utf8), par: 5) == .json(Self.json))
    }

    /// Jeton faux : un autre de meme longueur, un plus court ou plus long, une ligne sans fin,
    /// ou une connexion fermee avant la fin du jeton.
    @Test func jetonFaux() {
        let autre = String(repeating: "5a", count: 31) + "5b"
        #expect(Self.lire(EnvoiPasseur.trame(jeton: autre, json: Self.json), par: 1000) == .jetonFaux)
        #expect(Self.lire(EnvoiPasseur.trame(jeton: String(Self.jeton.dropLast()), json: Self.json), par: 1000) == .jetonFaux)
        #expect(Self.lire(EnvoiPasseur.trame(jeton: Self.jeton + "0", json: Self.json), par: 1000) == .jetonFaux)
        #expect(Self.lire(Data(String(repeating: "5a", count: 40).utf8), par: 3) == .jetonFaux, "80 octets sans fin de ligne")
        #expect(Self.lire(Data(Self.jeton.prefix(10).utf8), par: 3) == .jetonFaux, "fermee avant la fin du jeton")
        #expect(Self.lire(Data(), par: 1) == .jetonFaux, "fermee sans rien envoyer")
    }

    /// Un jeton attendu vide ne laisse rien passer : une trame dont la premiere ligne est vide est
    /// un jeton faux, quel que soit son decoupage en paquets.
    @Test func jetonAttenduVide() {
        let vide = EnvoiPasseur.trame(jeton: "", json: Self.json)
        for taille in [1, 1000] {
            #expect(Self.lire(vide, par: taille, jeton: "") == .jetonFaux, "paquets de \(taille)")
        }
        #expect(Self.lire(Data("\n5\nabcde".utf8), par: 1000, jeton: "") == .jetonFaux, "premiere ligne vide, puis 5 octets de JSON")
        #expect(Self.lire(Data(), par: 1, jeton: "") == .jetonFaux, "fermee sans rien envoyer")
    }

    /// Longueur fausse : illisible, signee, nulle, au-dela de 8 Mo, sans fin de ligne, ou trame
    /// plus courte qu'annoncee. Au-dela de 8 Mo, elle est refusee avant l'arrivee du JSON.
    @Test func longueurFausse() {
        func trame(_ longueur: String, _ json: Data = Self.json) -> Data {
            Data("\(Self.jeton)\n\(longueur)\n".utf8) + json
        }
        for l in ["", "abc", "-5", "+5", " 5", "0", String(EnvoiPasseur.tailleMax + 1)] {
            #expect(Self.lire(trame(l), par: 1000) == .longueurFausse, "longueur « \(l) »")
        }
        #expect(Self.lire(Data("\(Self.jeton)\n12345678901234567".utf8), par: 1000) == .longueurFausse, "17 chiffres sans fin")
        #expect(Self.lire(trame(String(Self.json.count + 1)), par: 1000) == .longueurFausse, "trame plus courte")
        #expect(Self.lire(Data("\(Self.jeton)\n".utf8), par: 1000) == .longueurFausse, "fermee avant la longueur")
        var l = EnvoiPasseur.Lecture(jeton: Self.jeton)
        #expect(l.ajouter(Data("\(Self.jeton)\n\(EnvoiPasseur.tailleMax + 1)\n".utf8)) == .longueurFausse)
        let max = Data(count: EnvoiPasseur.tailleMax)
        #expect(Self.lire(trame(String(EnvoiPasseur.tailleMax), max), par: 65_536) == .json(max), "8 Mo tout juste")
    }

    /// Une fois l'issue connue, elle ne change plus.
    @Test func issueDefinitive() {
        var l = EnvoiPasseur.Lecture(jeton: Self.jeton)
        #expect(l.ajouter(Data("faux\n".utf8)) == .jetonFaux)
        #expect(l.ajouter(Data("\(Self.jeton)\n".utf8)) == .jetonFaux)
        #expect(l.fin() == .jetonFaux)
    }
}
