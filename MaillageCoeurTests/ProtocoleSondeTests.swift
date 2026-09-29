import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Protocole USB de la sonde")
struct ProtocoleSondeTests {
    static func messages() throws -> [MessageSonde] {
        try CaptureSonde.lignes().compactMap { MessageSonde.lire(Data($0.utf8)) }
    }

    /// Toute la capture se relit : 2 bonjour, 9 etat, 53 diag.
    @Test func capture() throws {
        let m = try Self.messages()
        #expect(m.count == 64)
        let bonjours = m.compactMap { if case .bonjour(let b) = $0 { b } else { nil } }
        #expect(bonjours.count == 2)
        #expect(bonjours.allSatisfy { $0.estSonde })
        #expect(bonjours.first?.version == "0.1.0-essai")
        #expect(bonjours.first?.appairee == false)
        #expect(bonjours.allSatisfy { $0.nom == nil }, "firmware d'essai : pas de nom")
        let etats = m.compactMap { if case .etat(let e) = $0 { e } else { nil } }
        #expect(etats.count == 9)
        #expect(etats.filter(\.estAttachee).count == 4, "5 releves avant l'appairage")
        let diags = m.compactMap { if case .diag(let d) = $0 { d } else { nil } }
        #expect(diags.count == 53)
    }

    /// Etat attache : parent, partition, chef, prefixe du reseau maille.
    @Test func etatAttache() throws {
        let e = try #require(try Self.messages().compactMap { if case .etat(let e) = $0, e.estAttachee { e } else { nil } }.first)
        #expect(e.role == "child")
        #expect(e.rloc16Valeur == 0xE401)
        #expect(e.parent == ParentSonde(rloc16: "E400", ext: "E000000000000001", lqIn: 3, lqOut: 3, rssi: -76))
        #expect(e.partition == "46CBEBCD")
        #expect(e.chef == 24)
        #expect(e.prefixeMaille == "FD00111122220C87")
        #expect(!e.suspendue)
        #expect(e.ext == nil, "firmware d'essai : pas d'ExtMac")
        let v1 = #"{"v":1,"t":"etat","role":"child","rloc16":"AC09","ext":"E0000000000000FF","mode":"rn","parent":null,"partition":"46CBEBCD","chef":24,"canal":25,"prefixeMaille":null,"xp":null,"suspendue":true}"#
        guard case .etat(let e1)? = MessageSonde.lire(Data(v1.utf8)) else {
            Issue.record("etat 1.0.0 illisible")
            return
        }
        #expect(e1.ext == "E0000000000000FF")
        #expect(e1.suspendue)
    }

    /// bonjour du firmware 1.0.1 : nom, code et QR code, meme appairee (valeurs inventees) ;
    /// celui de la 1.0.0 n'a pas de nom.
    @Test func bonjourNom() {
        let v101 = #"{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.1","nom":"SONDE-01","mac":"A00000000001","appairee":true,"code":"12345678901","qr":"MT:ABCDEFGHIJ0123456789"}"#
        guard case .bonjour(let b)? = MessageSonde.lire(Data(v101.utf8)) else {
            Issue.record("bonjour 1.0.1 illisible")
            return
        }
        #expect(b.nom == "SONDE-01")
        #expect(b.appairee)
        #expect(b.code == "12345678901")
        #expect(b.qr == "MT:ABCDEFGHIJ0123456789")
        let v100 = #"{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.0","mac":"A00000000001","appairee":true,"code":null,"qr":null}"#
        guard case .bonjour(let a)? = MessageSonde.lire(Data(v100.utf8)) else {
            Issue.record("bonjour 1.0.0 illisible")
            return
        }
        #expect(a.estSonde)
        #expect(a.nom == nil)
        #expect(a.code == nil && a.qr == nil)
    }

    /// bonjour du firmware 1.0.2 : nom d'hote SRP, sans `.local` (valeur inventee), nul tant
    /// qu'il n'est pas connu ; absent des firmwares precedents.
    @Test func bonjourHote() {
        let base = #""v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.2","nom":"SONDE-01","mac":"A00000000001","appairee":true,"code":"12345678901","qr":"MT:ABCDEFGHIJ0123456789""#
        guard case .bonjour(let b)? = MessageSonde.lire(Data(("{" + base + #","hote":"0123456789ABCDEF"}"#).utf8)),
              case .bonjour(let inconnu)? = MessageSonde.lire(Data(("{" + base + #","hote":null}"#).utf8)),
              case .bonjour(let ancien)? = MessageSonde.lire(Data(("{" + base + "}").utf8)) else {
            Issue.record("bonjour 1.0.2 illisible")
            return
        }
        #expect(b.hote == "0123456789ABCDEF")
        #expect(inconnu.hote == nil, "pas encore enregistre par SRP")
        #expect(ancien.hote == nil, "firmware 1.0.1")
    }

    /// Cle des vecteurs H1 (00..1F) et son empreinte (8 premiers hexa de SHA-256).
    static let cleVecteurs = "000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F"

    /// `cle` : reponse a `cle nouvelle` (la cle, une seule fois, avec l'id de la demande et le
    /// nom d'hote) et a `cle` (l'empreinte seule, nulle sans cle).
    @Test func messageCle() {
        let nouvelle = #"{"v":1,"t":"cle","id":7,"cle":"\#(Self.cleVecteurs)","empreinte":"630DCD29","hote":"0123456789ABCDEF"}"#
        guard case .cle(let r)? = MessageSonde.lire(Data(nouvelle.utf8)) else {
            Issue.record("cle illisible")
            return
        }
        #expect(r.id == 7)
        #expect(r.cle == Self.cleVecteurs)
        #expect(r.empreinte == "630DCD29")
        #expect(r.hote == "0123456789ABCDEF")
        let sansHote = #"{"v":1,"t":"cle","id":8,"cle":"\#(Self.cleVecteurs)","empreinte":"630DCD29","hote":null}"#
        guard case .cle(let s)? = MessageSonde.lire(Data(sansHote.utf8)) else {
            Issue.record("cle sans hote illisible")
            return
        }
        #expect(s.hote == nil)
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"cle","empreinte":"630DCD29"}"#.utf8))
                == .cle(ReponseCle(id: nil, cle: nil, empreinte: "630DCD29", hote: nil)))
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"cle","empreinte":null}"#.utf8))
                == .cle(ReponseCle(id: nil, cle: nil, empreinte: nil, hote: nil)))
    }

    /// La cle n'apparait dans aucune description (journal, console, message d'erreur) :
    /// ni celle de la reponse, ni celle du message, ni un dump.
    @Test func cleMasquee() {
        let r = ReponseCle(id: 7, cle: Self.cleVecteurs, empreinte: "630DCD29", hote: "0123456789ABCDEF")
        var vidage = ""
        dump(r, to: &vidage)
        var vidageMessage = ""
        dump(MessageSonde.cle(r), to: &vidageMessage)
        let textes = [String(describing: r), String(reflecting: r), "\(r)", vidage, vidageMessage,
                      String(describing: MessageSonde.cle(r)), String(reflecting: MessageSonde.cle(r))]
        for t in textes {
            #expect(!t.contains("000102030405"), "cle visible")
        }
        #expect(String(describing: r).contains("630DCD29"), "l'empreinte reste")
    }

    /// Firmware 1.0.2 : `code` et `qr` nuls (par le reseau), `etat.eligible`, `udp` et `tas` dans
    /// la reponse `cle` : tout se lit.
    @Test func toleranceDuFirmware102() {
        let bonjour = #"{"v":1,"t":"bonjour","produit":"sonde-maillage","version":"1.0.2","nom":"SONDE-01","mac":"A00000000001","appairee":true,"code":null,"qr":null,"hote":"0123456789ABCDEF"}"#
        let etat = #"{"v":1,"t":"etat","role":"child","rloc16":"AC09","ext":"E0000000000000FF","mode":"rdn","eligible":false,"parent":null,"partition":"46CBEBCD","chef":24,"canal":25,"prefixeMaille":null,"xp":null,"suspendue":false}"#
        let cle = #"{"v":1,"t":"cle","id":7,"cle":"\#(Self.cleVecteurs)","empreinte":"630DCD29","hote":"0123456789ABCDEF","udp":{"port":5480,"ouvert":true},"tas":123456}"#
        guard case .bonjour(let b)? = MessageSonde.lire(Data(bonjour.utf8)),
              case .etat(let e)? = MessageSonde.lire(Data(etat.utf8)),
              case .cle(let r)? = MessageSonde.lire(Data(cle.utf8)) else {
            Issue.record("message 1.0.2 illisible")
            return
        }
        #expect(b.code == nil && b.qr == nil && b.hote == "0123456789ABCDEF")
        #expect(e.mode == "rdn" && e.partition == "46CBEBCD")
        #expect(r.id == 7 && r.empreinte == "630DCD29" && r.hote == "0123456789ABCDEF")
    }

    /// Diag : reussi (TLV decodees) et echoue (delai, occupee).
    @Test func diag() throws {
        let diags = try Self.messages().compactMap { if case .diag(let d) = $0 { d } else { nil } }
        let ok = try #require(diags.first { $0.id == 104 })
        #expect(ok.ok && ok.ms == 73 && ok.code == "2.04")
        #expect(ok.reponse?.rloc16 == 0x5000)
        let delai = try #require(diags.first { $0.id == 102 })
        #expect(!delai.ok && delai.erreur == "delai" && delai.reponse == nil)
        #expect(diags.first { $0.id == 402 }?.erreur == "occupee")
    }

    @Test func autres() {
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"voisins","liste":[{"rloc16":"AC00","ext":"E000000000000007","rssi":-89,"lqi":3,"routeur":true}]}"#.utf8))
                == .voisins([VoisinSonde(rloc16: "AC00", ext: "E000000000000007", rssi: -89, lqi: 3, routeur: true)]))
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"erreur","erreur":"commande inconnue"}"#.utf8)) == .erreur("commande inconnue"))
        #expect(MessageSonde.lire(Data(#"{"v":1,"t":"nouveau"}"#.utf8)) == .inconnu("nouveau"))
        #expect(MessageSonde.lire(Data(#"{"v":2,"t":"etat"}"#.utf8)) == nil, "autre version")
        #expect(MessageSonde.lire(Data("pas du json".utf8)) == nil)
    }

    @Test func commandes() {
        #expect(CommandeSonde.bonjour.ligne == "bonjour\n")
        #expect(CommandeSonde.etat.ligne == "etat\n")
        #expect(CommandeSonde.diag(cible: 0x5000, tlv: [0, 1, 5, 16, 8, 24], id: 12, delaiMs: 6000).ligne
                == "diag 5000 0,1,5,16,8,24 12 6000\n")
        #expect(CommandeSonde.diag(cible: 0x0400, tlv: [7], id: 3, delaiMs: nil).ligne == "diag 0400 7 3\n")
        // Alea de l'app en 64 hexa MAJUSCULES, id decimal obligatoire.
        let alea = Data((0..<32).map { UInt8(0xE0 &+ $0) })
        #expect(CommandeSonde.cleNouvelle(alea: alea, id: 12).ligne
                == "cle nouvelle E0E1E2E3E4E5E6E7E8E9EAEBECEDEEEFF0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF 12\n")
    }

    /// Lignes machine seulement, meme coupees en morceaux ; lignes humaines et trop longues ignorees.
    @Test func decoupage() {
        var d = DecoupeurLignes()
        #expect(d.ajouter(Data("I (123) chip: log\n\u{1E}{\"v\":1,".utf8)).isEmpty)
        let l = d.ajouter(Data("\"t\":\"etat\"}\r\n\u{1E}{}\n".utf8))
        #expect(l == [Data(#"{"v":1,"t":"etat"}"#.utf8), Data("{}".utf8)])
        var long = Data([ProtocoleSonde.separateur]) + Data(repeating: 0x41, count: 5000)
        long.append(0x0A)
        #expect(d.ajouter(long + Data("\u{1E}{}\n".utf8)) == [Data("{}".utf8)])
    }

    // Une ligne machine commence au dernier RS de la ligne, comme dans le pont Halo (le JSON est de
    // l'ASCII imprimable : jamais de RS dedans) ; ce qui precede le RS sur la ligne est abandonne.

    /// Du texte sans fin de ligne juste avant le RS (queue d'un log coupe, invite d'une session humaine) :
    /// la ligne machine intacte est retrouvee, dans le meme morceau ou dans le suivant.
    @Test func decoupageTexteAvantLeRS() {
        let json = #"{"v":1,"t":"erreur","erreur":"occupee"}"#
        var d = DecoupeurLignes()
        #expect(d.ajouter(Data("E (48213) chip[DL]: fin d'un log\u{1E}\(json)\n".utf8)) == [Data(json.utf8)],
                "queue de log et ligne machine dans le meme morceau")
        #expect(d.ajouter(Data("> ".utf8)).isEmpty)
        #expect(d.ajouter(Data("\u{1E}\(json)\r\n".utf8)) == [Data(json.utf8)], "invite, puis la ligne dans le morceau suivant")
    }

    /// Ligne machine coupee (RS et debut du JSON) suivie d'une ligne complete : seule la complete sort,
    /// et non les deux collees en une ligne que `lire` refuserait, la bonne perdue avec elle.
    @Test func decoupageLigneCoupee() {
        let coupee = #"{"v":1,"t":"diag","id":11,"cible":"5000","ok":true,"ms":73,"code":"2.04","tlv":"0E08"#
        let complete = #"{"v":1,"t":"erreur","erreur":"occupee"}"#
        var d = DecoupeurLignes()
        let l = d.ajouter(Data("\u{1E}\(coupee)\u{1E}\(complete)\n".utf8))
        #expect(l == [Data(complete.utf8)], "la coupee et la complete dans le meme morceau")
        #expect(l.compactMap { MessageSonde.lire($0) } == [.erreur("occupee")])
        #expect(d.ajouter(Data("\u{1E}\(coupee)".utf8)).isEmpty)
        #expect(d.ajouter(Data("\u{1E}\(complete)\n".utf8)) == [Data(complete.utf8)], "la complete dans le morceau suivant")
    }

    /// Un RS remet a zero l'etat "ligne trop longue" : la ligne machine qui le suit est retrouvee.
    @Test func decoupageRSApresUneLigneTropLongue() {
        let trop = Data(repeating: 0x41, count: 5000)
        var d = DecoupeurLignes()
        #expect(d.ajouter(Data([ProtocoleSonde.separateur]) + trop + Data("\u{1E}{}\n".utf8)) == [Data("{}".utf8)],
                "ligne machine trop longue, coupee")
        #expect(d.ajouter(trop + Data("\u{1E}{}\n".utf8)) == [Data("{}".utf8)], "texte trop long, sans fin de ligne")
    }
}
