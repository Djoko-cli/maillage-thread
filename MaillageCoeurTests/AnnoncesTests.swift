import Foundation
import Testing
@testable import MaillageCoeur

/// Enregistrement TXT brut : chaque chaine precedee de sa longueur.
func txtBrut(_ chaines: [[UInt8]]) -> Data {
    Data(chaines.flatMap { [UInt8($0.count)] + $0 })
}

@Suite("Champs TXT et format des captures")
struct AnnoncesTests {
    @Test func lectureDuBrut() throws {
        let xp: [UInt8] = [0x4B, 0x5D, 0x37, 0x6D, 0x94, 0x2B, 0x48, 0x0E]
        let brut = txtBrut([
            Array("vn=Apple".utf8),
            Array("xp=".utf8) + xp,
            Array("Tv=1.4.0".utf8),       // cle en majuscules : gardee en minuscules
            Array("vn=Autre".utf8),       // doublon : la premiere occurrence compte
            Array("drapeau".utf8),        // cle sans "=" : valeur vide
            [],                           // chaine vide : ignoree
            Array("=sanscle".utf8),       // pas de cle : ignoree
        ])
        let t = ChampsTXT(brut: brut)
        #expect(t.texte("vn") == "Apple")
        #expect(t["xp"] == Data(xp))
        #expect(t["XP"] == Data(xp), "cles insensibles a la casse")
        #expect(t.texte("tv") == "1.4.0")
        #expect(t["drapeau"] == Data())
        #expect(t.valeurs.count == 4)
        #expect(ChampsTXT(brut: Data([5, 0x61])).estVide, "longueur qui deborde : lecture arretee")
        #expect(ChampsTXT(brut: txtBrut([Array("SII=6000".utf8)])).entier("sii") == 6000)
    }

    @Test func formatDesCaptures() throws {
        let t = ChampsTXT(["vn": Data("Apple".utf8),
                           "xp": Data([0x4B, 0x5D, 0x00]),
                           "piege": Data("hex:41".utf8)])
        let json = try CodageJSON.encodeur().encode(t)
        #expect(String(decoding: json, as: UTF8.self)
                == #"{"piege":"hex:6865783A3431","vn":"Apple","xp":"hex:4B5D00"}"#)
        #expect(try CodageJSON.decodeur().decode(ChampsTXT.self, from: json) == t)
        #expect(throws: DecodingError.self) {
            try CodageJSON.decodeur().decode(ChampsTXT.self, from: Data(#"{"xp":"hex:4B5"}"#.utf8))
        }
        #expect(Data(hexa: "4b5d") == Data([0x4B, 0x5D]))
        #expect(Data(hexa: "zz") == nil)
    }

    @Test func allerRetourDUneCapture() throws {
        let date = try Date("2026-09-27T20:42:09Z", strategy: .iso8601).addingTimeInterval(0.5)
        let a = Annonces(
            date: date,
            routeurs: [AnnonceService(instance: "Apple TV 4K", hote: "Apple-TV-4K.local", port: 49153,
                                      txt: ChampsTXT(["nn": Data("MyHome1520326503".utf8)]))],
            matter: [AnnonceService(instance: "309BEA1CCA0C1569-00000000F8EDDF49")],
            adresses: ["Apple-TV-4K.local": ["fe80::4e:ff54:91ca:c791"]],
            routes: [RouteIPv6(prefixe: "fd2d:3b27:72b8::/64", passerelle: "fe80::4e:ff54:91ca:c791", interface: "en0")],
            prefixesLocaux: ["fd4b:5d37:6d94:480e::/64"],
            note: "essai")
        let json = try CodageJSON.encodeur(lisible: true).encode(a)
        let texte = String(decoding: json, as: UTF8.self)
        #expect(texte.contains(#""date" : "2026-09-27T20:42:09.500Z""#), "UTC, millisecondes")
        #expect(try CodageJSON.decodeur().decode(Annonces.self, from: json) == a)
        #expect(a.adresses(de: "Apple-TV-4K.local") == ["fe80::4e:ff54:91ca:c791"])
        #expect(a.adresses(de: nil) == [])
        let sansMs = Data(#"{"date":"2026-09-27T20:42:09Z","routeurs":[],"matter":[],"hap":[],"adresses":{},"routes":[],"prefixesLocaux":[]}"#.utf8)
        #expect(try CodageJSON.decodeur().decode(Annonces.self, from: sansMs).date == date.addingTimeInterval(-0.5))
    }
}
