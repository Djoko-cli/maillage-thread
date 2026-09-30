#!/usr/bin/env python3
"""Anonymise une capture de la sonde (JSON Lines) avant d'en faire des donnees de test.

  python3 outils/anonymiser-sonde.py <capture brute.jsonl> <capture anonyme.jsonl>

Remplace, de facon coherente d'une ligne a l'autre et jusque dans les TLV de
diagnostic :
- les ExtMac (TLV 0, parent de `etat`), et les adresses lien-local qui en
  derivent ;
- les prefixes IPv6 (/48 : reseau maille, OMR, NAT64...) et les identifiants
  d'interface, sauf ceux des RLOC et ALOC (0000:00ff:fe00:xxxx), gardes ;
- le `xp`, la MAC de la sonde, le code d'appairage ;
- les adresses des Network Data (prefixes, donnees de serveur).
Garde les RLOC16, partitions, qualites, delais et versions de pile.
Aucune valeur reelle n'est ecrite dans ce script : il les repere dans la
capture. A la fin, il verifie qu'aucune ne reste dans la sortie.

Garde : l'outil ne connait que les messages bonjour, etat et diag de la
capture du 29/09/2026 (tables CHAMPS_CONNUS, CHAMPS_PARENT, TLV_CONNUS), et ne
traite que les TLV 0, 7 et 8. Il echoue AVANT toute ecriture, avec la liste de
ce qu'il ne connait pas (des noms, jamais une valeur), devant :
- un type de message, un champ ou un TLV inconnu, un TLV a longueur etendue ou
  tronque, un TLV 0 qui n'a pas 8 octets, un TLV 8 qui n'est pas fait
  d'adresses entieres ;
- dans la Network Data (TLV 7), autre chose que des Prefix de 96 bits au plus,
  des Service et une Commissioning Data qui ne porte qu'une Commissioner
  Session ID (16 bits, quelle que soit sa valeur), ou une donnee de service de
  plus de 2 octets : donnees_reseau() ne remplace que les 6 premiers octets des
  Prefix et l'adresse des Server d'un Service ;
- un champ connu qui porte un objet ou une liste (hors parent).
Une valeur illisible dans un champ connu (adresse, hexa) le fait sortir avec le
seul numero de ligne, jamais la valeur (la trace d'une exception la citerait).
Une valeur qu'il ne connait pas pourrait etre une ExtMac, une adresse ou un
nom, et le controle final ne porte que sur les valeurs qu'il a reperees. Une
capture de la sonde 1.0.2 est donc refusee (etat.ext, bonjour.hote,
bonjour.nom, messages voisins et routeurs...) tant que l'anonymiseur ne les
traite pas. Pour ajouter un champ : verifier qu'il ne porte rien d'identifiant,
sinon le traiter dans message() ; puis l'inscrire dans la table.
"""
import ipaddress
import json
import re
import sys

MAILLE_RLOC = bytes.fromhex("000000fffe00")

# Ce que l'outil connait (voir la garde dans la docstring). Les champs sont ceux de
# la capture du 29/09 : les traiter ou verifier qu'ils ne portent rien d'identifiant.
CHAMPS_COMMUNS = frozenset({"t", "v", "heure"})  # type, version du protocole, heure ajoutee par sonde_essai.py
CHAMPS_CONNUS = {
    "bonjour": frozenset({"produit", "version", "mac", "appairee", "code", "qr"}),
    "etat": frozenset({"role", "rloc16", "mode", "parent", "partition", "chef", "canal", "prefixeMaille", "xp",
                       "suspendue"}),
    "diag": frozenset({"id", "cible", "ms", "ok", "code", "erreur", "tlv"}),
}
CHAMPS_PARENT = frozenset({"rloc16", "ext", "lqIn", "lqOut", "rssi", "rssiDernier", "age"})
# TLV de diagnostic : 0, 7 et 8 sont traites ; les autres n'ont ni ExtMac ni adresse.
TLV_CONNUS = frozenset({0, 1, 2, 5, 6, 7, 8, 16, 24, 25, 26, 27, 28})
# Network Data (TLV 7), premier niveau : les Prefix (1) et les Service (5) sont traites par donnees_reseau() ; la
# Commissioning Data (4) n'est acceptee que si elle ne porte qu'un sous-TLV Commissioner Session ID (MeshCoP 11,
# longueur 2), quelle que soit sa valeur : un identifiant de session sur 16 bits n'est pas une donnee personnelle.
DONNEES_RESEAU_CONNUES = frozenset({1, 4, 5})
# Une donnee de service de plus de 2 octets (la capture : 01, 5d, 5cc5) pourrait porter une adresse.
DONNEE_SERVICE_MAX = 2
# donnees_reseau() ne remplace que les 6 premiers octets d'un Prefix : au-dela de 96 bits (le /96 NAT64 de la capture
# passe), l'identifiant d'interface resterait en clair.
PREFIXE_MAX_BITS = 96


class Anonymiseur:
    def __init__(self):
        self.exts = {}      # ExtMac reelle (8 octets) -> factice
        self.iids = {}      # identifiant d'interface reel -> factice
        self.p48 = {}       # /48 reel (6 octets) -> factice
        self.xp = {}
        self.macs = {}

    # --- Tables de correspondance ------------------------------------------

    def ext(self, e):
        if e not in self.exts:
            self.exts[e] = bytes.fromhex("E0%014X" % (len(self.exts) + 1))
        return self.exts[e]

    def iid(self, i):
        if i not in self.iids:
            self.iids[i] = bytes.fromhex("0A00%012X" % (len(self.iids) + 1))
        return self.iids[i]

    def prefixe48(self, p):
        if p not in self.p48:
            n = len(self.p48)
            self.p48[p] = bytes.fromhex("FD00%04X%04X" % (0x1111 * (2 * n + 1) & 0xFFFF, 0x1111 * (2 * n + 2) & 0xFFFF))
        return self.p48[p]

    def adresse(self, a):
        """Adresse IPv6 de 16 octets."""
        if a[:8] == bytes.fromhex("FE80000000000000"):
            # Lien-local Thread : identifiant tire de l'ExtMac (bit U/L inverse).
            e = bytes([a[8] ^ 0x02]) + a[9:]
            f = self.ext(e)
            return a[:8] + bytes([f[0] ^ 0x02]) + f[1:]
        tete = self.prefixe48(a[:6]) + a[6:8]
        if a[8:14] == MAILLE_RLOC:
            return tete + a[8:]
        return tete + self.iid(a[8:])

    # --- TLV de diagnostic -------------------------------------------------

    def tlv(self, hexa):
        o, i, sortie = bytes.fromhex(hexa), 0, b""
        while i + 2 <= len(o):
            t, n = o[i], o[i + 1]
            v = o[i + 2:i + 2 + n]
            if t == 0 and n == 8:
                v = self.ext(v)
            elif t == 8:
                v = b"".join(self.adresse(v[k:k + 16]) for k in range(0, n - 15, 16))
            elif t == 7:
                v = self.donnees_reseau(v)
            sortie += bytes([t, n]) + v
            i += 2 + n
        return sortie.hex().upper()

    def donnees_reseau(self, o):
        """Network Data : prefixes des TLV Prefix, adresses des donnees de serveur."""
        i, sortie = 0, b""
        while i + 2 <= len(o):
            t, n = o[i] >> 1, o[i + 1]
            v = bytearray(o[i + 2:i + 2 + n])
            if t == 1 and len(v) >= 2:  # Prefix : domaine, longueur en bits, prefixe, sous-TLV
                octets = (v[1] + 7) // 8
                if octets >= 6:
                    v[2:8] = self.prefixe48(bytes(v[2:8]))
            elif t == 5 and len(v) >= 1:  # Service : donnees, puis sous-TLV Server
                j = 1 if v[0] & 0x80 else 5
                if j < len(v):
                    j += 1 + v[j]
                    while j + 2 <= len(v):
                        st, sn = v[j] >> 1, v[j + 1]
                        if st == 6 and sn >= 2 + 16:  # Server : RLOC16, puis une adresse
                            v[j + 4:j + 20] = self.adresse(bytes(v[j + 4:j + 20]))
                        j += 2 + sn
            sortie += bytes([o[i], n]) + bytes(v)
            i += 2 + n
        return sortie

    # --- Messages de la sonde ----------------------------------------------

    def message(self, m):
        m = dict(m)
        t = m.get("t")
        if t == "bonjour":
            if m.get("mac"):
                mac = m["mac"]
                self.macs.setdefault(mac, "A0000000%04X" % (len(self.macs) + 1))
                m["mac"] = self.macs[mac]
            m["code"] = None
            m["qr"] = None
        elif t == "etat":
            if m.get("xp"):
                self.xp.setdefault(m["xp"], "A0A1A2A3A4A5A6A7")
                m["xp"] = self.xp[m["xp"]]
            if m.get("prefixeMaille"):
                p = bytes.fromhex(m["prefixeMaille"])
                m["prefixeMaille"] = (self.prefixe48(p[:6]) + p[6:8]).hex().upper()
            if m.get("parent") and m["parent"].get("ext"):
                par = dict(m["parent"])
                par["ext"] = self.ext(bytes.fromhex(par["ext"])).hex().upper()
                m["parent"] = par
        elif t == "diag":
            cible = m.get("cible", "")
            if ":" in cible:
                m["cible"] = str(ipaddress.IPv6Address(self.adresse(ipaddress.IPv6Address(cible).packed)))
            if m.get("tlv"):
                m["tlv"] = self.tlv(m["tlv"])
        return m

    def secrets(self):
        """Valeurs reelles, en texte, a ne plus trouver dans la sortie."""
        s = set()
        for e in self.exts:
            s.add(e.hex())
            s.add((bytes([e[0] ^ 0x02]) + e[1:]).hex())
        for i in self.iids:
            s.add(i.hex())
        for p in self.p48:
            s.add(p.hex())
            s.add(str(ipaddress.IPv6Address(p + bytes(10))).split("::")[0])
        s.update(x.lower() for x in self.xp)
        s.update(x.lower() for x in self.macs)
        return {x.lower() for x in s if len(x) >= 8}


def nom_sur(x):
    """Nom de champ ou de type pour un message d'erreur : jamais une valeur. Un nom abime peut porter une ExtMac, une
    MAC, un /48 ou un code d'appairage : 8 hexa de suite, et il devient "(illisible)"."""
    ok = isinstance(x, str) and re.fullmatch(r"[A-Za-z0-9_]{1,32}", x) and not re.search(r"[0-9A-Fa-f]{8}", x)
    return x if ok else "(illisible)"


def controler_donnees_reseau(o):
    """Pourquoi la Network Data (TLV 7) n'est pas connue (liste vide si elle l'est) : donnees_reseau() ne remplace
    que le /48 des Prefix et l'adresse des Server d'un Service ; le reste passerait en clair."""
    raisons, i = [], 0
    while i < len(o):
        if i + 2 > len(o) or i + 2 + o[i + 1] > len(o):
            return raisons + ["Network Data tronquee (diag.tlv)"]
        t, n = o[i] >> 1, o[i + 1]  # le bit de poids faible est le drapeau "stable"
        v = o[i + 2:i + 2 + n]
        if t not in DONNEES_RESEAU_CONNUES:
            raisons.append("sous-TLV inconnu de la Network Data : %d (diag.tlv)" % t)
        elif t == 1 and len(v) >= 2 and v[1] > PREFIXE_MAX_BITS:  # v[1] : longueur du prefixe, en bits
            raisons.append("prefixe de plus de %d bits dans la Network Data (diag.tlv)" % PREFIXE_MAX_BITS)
        elif t == 4 and not (len(v) == 4 and v[0] == 11 and v[1] == 2):  # un seul sous-TLV, la valeur est libre
            raisons.append("Commissioning Data inconnue dans la Network Data (diag.tlv)")
        elif t == 5 and len(v) >= 1:
            j = 1 if v[0] & 0x80 else 5  # un numero d'entreprise (4 octets) suit si le bit T est a 0
            if j < len(v) and v[j] > DONNEE_SERVICE_MAX:
                raisons.append("donnee de service de plus de %d octets dans la Network Data (diag.tlv)"
                               % DONNEE_SERVICE_MAX)
        i += 2 + n
    return raisons


def controler_tlv(hexa):
    """Pourquoi la charge TLV d'un diag n'est pas connue (liste vide si elle l'est)."""
    try:
        o = bytes.fromhex(hexa)
    except (TypeError, ValueError):
        return ["tlv illisible (diag.tlv)"]
    raisons, i = [], 0
    while i < len(o):
        if i + 2 > len(o):
            return raisons + ["TLV tronque (diag.tlv)"]
        t, n = o[i], o[i + 1]
        if n == 0xFF:
            return raisons + ["TLV a longueur etendue (diag.tlv)"]
        if i + 2 + n > len(o):
            return raisons + ["TLV tronque (diag.tlv)"]
        if t not in TLV_CONNUS:
            raisons.append("TLV inconnu : %d (diag.tlv)" % t)
        elif t == 0 and n != 8:
            raisons.append("TLV 0 de longueur inattendue (diag.tlv)")
        elif t == 8 and n % 16 != 0:
            raisons.append("TLV 8 de longueur inattendue (diag.tlv)")
        elif t == 7:
            raisons += controler_donnees_reseau(o[i + 2:i + 2 + n])
        i += 2 + n
    return raisons


def controler(numerotes):
    """La garde. `numerotes` : [(numero de ligne, message)]. Rend {raison: [numeros de ligne]}, vide si tout est
    connu. Ne cite jamais une valeur de la capture, seulement des noms de type et de champ (nom_sur). Une raison
    repetee sur une meme ligne ne compte qu'une fois."""
    inconnu = {}

    def noter(raison, numero):
        numeros = inconnu.setdefault(raison, [])
        if numero not in numeros:
            numeros.append(numero)

    for numero, m in numerotes:
        if not isinstance(m, dict):
            noter("ligne qui n'est pas un objet JSON", numero)
            continue
        t = m.get("t")
        if not isinstance(t, str) or t not in CHAMPS_CONNUS:
            noter("type de message inconnu : %s" % nom_sur(t), numero)
            continue
        for champ, valeur in m.items():
            if champ not in CHAMPS_COMMUNS and champ not in CHAMPS_CONNUS[t]:
                noter("champ inconnu : %s.%s" % (t, nom_sur(champ)), numero)
            elif isinstance(valeur, (dict, list)) and not (t == "etat" and champ == "parent"):
                noter("forme inconnue : %s.%s" % (t, champ), numero)  # un scalaire est attendu
        parent = m.get("parent") if t == "etat" else None
        if isinstance(parent, dict):
            for champ, valeur in parent.items():
                if champ not in CHAMPS_PARENT:
                    noter("champ inconnu : etat.parent.%s" % nom_sur(champ), numero)
                elif isinstance(valeur, (dict, list)):
                    noter("forme inconnue : etat.parent.%s" % champ, numero)
        elif parent is not None:
            noter("forme inconnue : etat.parent", numero)
        tlv = m.get("tlv") if t == "diag" else None
        if tlv is not None and not isinstance(tlv, (dict, list)):  # un objet ou une liste : deja "forme inconnue"
            for raison in controler_tlv(tlv):
                noter(raison, numero)
    return inconnu


def texte_refus(inconnu):
    lignes = ["refus : la capture contient ce que l'anonymiseur ne connait pas ; rien n'a ete ecrit."]
    for raison, numeros in inconnu.items():
        lignes.append("  %s (%d ligne(s), la premiere : %d)" % (raison, len(numeros), numeros[0]))
    lignes.append("Un champ ou un message inconnu peut porter une ExtMac, une adresse ou un nom : le traiter dans "
                  "l'anonymiseur (message(), puis les tables CHAMPS_CONNUS et TLV_CONNUS) avant de lui confier "
                  "cette capture.")
    return "\n".join(lignes)


def lire(chemin):
    """Les messages de la capture avec leur numero de ligne (les lignes vides sont sautees)."""
    res = []
    with open(chemin, encoding="utf-8") as f:
        for numero, ligne in enumerate(f, 1):
            if ligne.strip():
                try:
                    res.append((numero, json.loads(ligne)))
                except ValueError:
                    sys.exit("refus : la ligne %d n'est pas du JSON ; rien n'a ete ecrit." % numero)
    return res


def valeur_illisible(numero):
    """Sort avec le seul numero de ligne : la trace d'une exception (AddressValueError...) citerait la valeur."""
    raise SystemExit("refus : la ligne %d porte une valeur que l'anonymiseur ne sait pas lire ; rien n'a ete ecrit."
                     % numero) from None


def main():
    entree, sortie = sys.argv[1], sys.argv[2]
    a = Anonymiseur()
    numerotes = lire(entree)
    inconnu = controler(numerotes)
    if inconnu:
        sys.exit(texte_refus(inconnu))
    # Le prefixe du reseau maille (sonde attachee) d'abord : il recoit toujours
    # le premier /48 factice.
    for numero, m in numerotes:
        if m.get("t") == "etat" and m.get("prefixeMaille") and m.get("role") in ("child", "router", "leader"):
            try:
                a.prefixe48(bytes.fromhex(m["prefixeMaille"])[:6])
            except (ValueError, TypeError):
                valeur_illisible(numero)
            break
    lignes = []
    for numero, m in numerotes:
        try:
            lignes.append(json.dumps(a.message(m), ensure_ascii=False, sort_keys=True))
        except (ValueError, TypeError):
            valeur_illisible(numero)
    texte = "\n".join(lignes) + "\n"
    minuscule = texte.lower()
    brut = texte.lower().replace(":", "")
    fuites = [s for s in a.secrets() if s in minuscule or s in brut]
    if fuites:
        sys.exit("fuite : %d valeur(s) reelle(s) encore presente(s)" % len(fuites))
    open(sortie, "w", encoding="utf-8").write(texte)
    print("%d lignes ; %d ExtMac, %d identifiants, %d prefixes /48 remplaces" %
          (len(lignes), len(a.exts), len(a.iids), len(a.p48)))


if __name__ == "__main__":
    main()
