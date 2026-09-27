import Foundation
import Testing
@testable import MaillageCoeur

@Suite("Decodage des annonces")
struct DecodageTests {
    /// TXT d'un routeur de bordure comme le 28/09 (octets bas de `sb` reconstitues).
    static func txtRouteur(tv: String, sb: [UInt8], pt: [UInt8], omr: [UInt8]? = nil) -> ChampsTXT {
        var v: [String: Data] = [
            "vn": Data("Apple".utf8), "mn": Data("BorderRouter".utf8), "tv": Data(tv.utf8),
            "nn": Data("MyHome1520326503".utf8),
            "xp": Data([0x4B, 0x5D, 0x37, 0x6D, 0x94, 0x2B, 0x48, 0x0E]),
            "xa": Data([0x2A, 0, 0, 0, 0, 0, 0, 0x01]),
            "sb": Data(sb), "pt": Data(pt),
            "at": Data([0x00, 0x00, 0x67, 0x34, 0x5B, 0x00, 0x00, 0x00]),
        ]
        if let omr { v["omr"] = Data(omr) }
        return ChampsTXT(v)
    }

    @Test func chef() throws {
        let annonce = AnnonceService(instance: "Apple TV 4K", hote: "Apple-TV-4K.local", port: 49153,
                                     txt: Self.txtRouteur(tv: "1.4.0", sb: [0, 0, 0x0F, 0xB1], pt: [0x7C, 0x6A, 0x2A, 0x68]))
        let r = RouteurBordure(annonce: annonce, adresses: ["fe80::4e:ff54:91ca:c791", "192.168.1.19",
                                                            "fd4b:5d37:6d94:480e:3:fd43:a000:a708"])
        #expect(r.id == "Apple TV 4K")
        #expect(r.nomReseau == "MyHome1520326503")
        #expect(r.idReseau == "4B5D376D942B480E")
        #expect(r.adresseEtendue == "2A00000000000001")
        #expect(r.partition == "7C6A2A68")
        #expect(r.jeuActif == Date(timeIntervalSince1970: 1_731_484_416), "2024-11-13T07:53:36Z")
        #expect(r.role == .chef)
        #expect(r.etat?.interface == .active)
        #expect(r.etat?.bbrActif == true)
        #expect(r.etat?.bbrPrimaire == true)
        #expect(r.prefixeOMR == nil)
        #expect(r.prefixeReseauLocal?.description == "fd4b:5d37:6d94:480e::/64")
        #expect(r.adresses.count == 2, "l'IPv4 n'est pas une adresse IPv6")
        #expect(r.adressesLien.map(\.description) == ["fe80::4e:ff54:91ca:c791"])
    }

    @Test func routeurEtThread13() {
        let homepod = RouteurBordure(annonce: AnnonceService(instance: "HomePod Gauche",
            txt: Self.txtRouteur(tv: "1.4.0", sb: [0, 0, 0x0C, 0xB1], pt: [0x7C, 0x6A, 0x2A, 0x68])), adresses: [])
        #expect(homepod.role == .routeur)
        #expect(homepod.etat?.bbrActif == true)
        #expect(homepod.etat?.bbrPrimaire == false)

        // Aqara HubM100 : Thread 1.3.0, bits de role a 0 : role inconnu, pas "detache".
        let aqara = RouteurBordure(annonce: AnnonceService(instance: "Aqara HubM100 #80E0",
            txt: Self.txtRouteur(tv: "1.3.0", sb: [0, 0, 0x01, 0xB1], pt: [0xE6, 0xA6, 0xAD, 0x72],
                                 omr: [0x40, 0xFD, 0x0D, 0xEE, 0xC8, 0x05, 0xEF, 0x00, 0x01])), adresses: [])
        #expect(aqara.role == nil)
        #expect(aqara.etat?.bbrPrimaire == true)
        #expect(aqara.partition == "E6A6AD72")
        #expect(aqara.prefixeOMR?.description == "fd0d:eec8:5ef:1::/64")

        let sansRien = RouteurBordure(annonce: AnnonceService(instance: "X"), adresses: [])
        #expect(sansRien.role == nil && sansRien.idReseau == nil && sansRien.partition == nil && sansRien.jeuActif == nil)
    }

    @Test func versions() {
        #expect(RouteurBordure.versionAuMoins("1.4.0", 1, 4))
        #expect(RouteurBordure.versionAuMoins("1.10", 1, 4))
        #expect(RouteurBordure.versionAuMoins("2.0", 1, 4))
        #expect(!RouteurBordure.versionAuMoins("1.3.0", 1, 4))
        #expect(!RouteurBordure.versionAuMoins("1", 1, 4))
        #expect(!RouteurBordure.versionAuMoins(nil, 1, 4))
    }

    @Test func instancesMatter() throws {
        let i = try #require(InstanceMatter(instance: "309bea1cca0c1569-00000000F8EDDF49"))
        #expect(i.fabrique == "309BEA1CCA0C1569")
        #expect(i.noeud == "00000000F8EDDF49")
        #expect(i.nom == "309BEA1CCA0C1569-00000000F8EDDF49")
        #expect(InstanceMatter(instance: "309BEA1CCA0C1569") == nil)
        #expect(InstanceMatter(instance: "309BEA1CCA0C1569-XYZ") == nil)
        #expect(InstanceMatter(instance: "309BEA1CCA0C156Z-00000000F8EDDF49") == nil)
        #expect(InstanceMatter(instance: "A-B-C") == nil)
    }

    @Test func proprietesMatter() {
        #expect(ProprietesMatter(txt: ChampsTXT(["SII": Data("6000".utf8)])).endormi, "1EA39E8E72FC9ADA, 28/09")
        #expect(!ProprietesMatter(txt: ChampsTXT(["SII": Data("2000".utf8), "SAI": Data("2000".utf8)])).endormi,
                "pont Halo, alimente")
        #expect(!ProprietesMatter(txt: ChampsTXT(["SII": Data("300".utf8)])).endormi)
        #expect(ProprietesMatter(txt: ChampsTXT(["ICD": Data("0".utf8)])).endormi)
        #expect(!ProprietesMatter(txt: ChampsTXT()).endormi)
        #expect(ProprietesMatter(txt: ChampsTXT(["SAI": Data("800".utf8)])).sai == 800)
    }

    @Test func accessoireHAP() {
        let a = AccessoireHAP(annonce: AnnonceService(instance: "Eve Door 4A3B", hote: "Eve-Door-4A3B.local",
            txt: ChampsTXT(["md": Data("Eve Door".utf8), "ci": Data("10".utf8),
                            "id": Data("AA:BB:CC:DD:EE:FF".utf8), "sf": Data("0".utf8)])))
        #expect(a.nom == "Eve Door 4A3B")
        #expect(a.modele == "Eve Door")
        #expect(a.categorie == 10)
        #expect(a.identifiant == "AA:BB:CC:DD:EE:FF")
        #expect(a.appaire == true)
        #expect(AccessoireHAP(annonce: AnnonceService(instance: "Neuf", txt: ChampsTXT(["sf": Data("1".utf8)]))).appaire == false)
    }
}
