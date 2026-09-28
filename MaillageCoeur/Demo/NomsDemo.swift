import Foundation

/// Noms de Maison du mode demo : inventes (ce ne sont pas les vrais noms de la
/// maison), attaches aux vrais noeuds du releve du 28/09 sur la fabrique
/// 309BEA1CCA0C1569, qui joue la fabrique d'Apple.
public enum NomsDemo {
    public static let fabrique = "309BEA1CCA0C1569"

    /// Hote -> (nom, piece, fabricant, modele, categorie).
    static let table: [String: (String, String, String, String, String)] = [
        "561F9A6463953778": ("Halo", "Bureau", "Djoko-CLI", "Pont ScreenBar Halo", "Ampoule"),
        "86E8EDA04DCFDE3F": ("Nuki Ultra", "Entrée", "Nuki", "Smart Lock Ultra", "Serrure"),
        "02A271A6D5FC4CB9": ("Eve Door", "Entrée", "Eve Systems", "Eve Door & Window", "Capteur"),
        "3AA21A204E668543": ("Eve Motion", "Couloir", "Eve Systems", "Eve Motion", "Capteur"),
        "C6A566044F350DFD": ("Thermo salon", "Salon", "Eve Systems", "Eve Thermo", "Thermostat"),
        "D60E698E80D7DA48": ("Thermo chambre", "Chambre", "Eve Systems", "Eve Thermo", "Thermostat"),
        "DA41BDE63CF37320": ("Météo terrasse", "Terrasse", "Eve Systems", "Eve Weather", "Capteur"),
        "0A87C94AB92DEC89": ("Capteur salon", "Salon", "Aqara", "Climate Sensor W100", "Capteur"),
        "32E1CCA9C1A0F448": ("Détecteur couloir", "Couloir", "Aqara", "Motion Sensor P2", "Capteur"),
        "4608101CB826BD90": ("Fenêtre chambre", "Chambre", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "7A550C85AFFF5F14": ("Capteur salle de bain", "Salle de bain", "Aqara", "Climate Sensor W100", "Capteur"),
        "8AD56494F325575D": ("Porte-fenêtre", "Salon", "Aqara", "Door and Window Sensor P2", "Capteur"),
        "9AD3C6E5296BEAF9": ("Fumée cuisine", "Cuisine", "Aqara", "Smoke Detector", "Capteur"),
        "AA106FAEB4980093": ("Bouton chevet", "Chambre", "Aqara", "Wireless Mini Switch", "Interrupteur"),
        "C6A7BFBB152E6B99": ("Capteur bureau", "Bureau", "Aqara", "Climate Sensor W100", "Capteur"),
        "46D9C54DAA6079AC": ("Prise bureau", "Bureau", "Eve Systems", "Eve Energy", "Prise"),
        "7A9DABB000AD621D": ("Prise salon", "Salon", "Eve Systems", "Eve Energy", "Prise"),
        "8251013C2EAB1BB9": ("Volet chambre", "Chambre", "Nanoleaf", "Blinds", "Store"),
        "72FBDA00C4A43024": ("Volet salon", "Salon", "Nanoleaf", "Blinds", "Store"),
        "9A952C5F437861C5": ("Lampe chevet", "Chambre", "Nanoleaf", "Essentials A19", "Ampoule"),
        "D61B585F32E9C793": ("Interrupteur cuisine", "Cuisine", "Eve Systems", "Eve Light Switch", "Interrupteur"),
        "FAD7066DD54C259D": ("Ampoule entrée", "Entrée", "Nanoleaf", "Essentials A19", "Ampoule"),
        "C42996C911BF": ("Passerelle salon", "Salon", "Eve Systems", "Eve Play", "Pont"),
        "C4E7AE1CCF31": ("Prise Wi-Fi bureau", "Bureau", "Meross", "Smart Plug", "Prise"),
    ]

    /// Hote -> batterie : une faible par son niveau, une par l'alerte seule, un volet en charge.
    static let batteries: [String: BatterieMaison] = [
        "86E8EDA04DCFDE3F": BatterieMaison(niveau: 52, charge: .horsCharge, alerte: false),
        "02A271A6D5FC4CB9": BatterieMaison(niveau: 88, alerte: false),
        "3AA21A204E668543": BatterieMaison(niveau: 12, alerte: false),
        "C6A566044F350DFD": BatterieMaison(niveau: 45, alerte: false),
        "D60E698E80D7DA48": BatterieMaison(niveau: 40, alerte: false),
        "32E1CCA9C1A0F448": BatterieMaison(niveau: 100, alerte: false),
        "4608101CB826BD90": BatterieMaison(alerte: true),
        "9AD3C6E5296BEAF9": BatterieMaison(niveau: 97, charge: .nonRechargeable, alerte: false),
        "AA106FAEB4980093": BatterieMaison(alerte: false),
        "8251013C2EAB1BB9": BatterieMaison(niveau: 81, charge: .enCharge, alerte: false),
        "72FBDA00C4A43024": BatterieMaison(niveau: 64, charge: .horsCharge, alerte: false),
    ]

    public static let maison: NomsMaison = {
        var accessoires: [AccessoireMaison] = []
        for s in Releve20260928.annonces.matter {
            guard let i = InstanceMatter(instance: s.instance), i.fabrique == fabrique, let hote = s.hote else { continue }
            let id = Instantane.idAppareil(hote: hote, instance: s.instance)
            guard let e = table[id] else { continue }
            accessoires.append(AccessoireMaison(nom: e.0, piece: e.1, fabricant: e.2, modele: e.3,
                                                categorie: e.4, noeudMatter: i.noeud, batterie: batteries[id]))
        }
        // Dans le temps de la demo (la fin de la panne rejouee) : « releve il y a 5 minutes ».
        return NomsMaison(date: ScenarioPanne.fin.addingTimeInterval(-5 * 60), domicile: "Maison (démo)",
                          accessoires: accessoires.sorted { $0.nom < $1.nom })
    }()
}
