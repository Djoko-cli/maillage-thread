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
