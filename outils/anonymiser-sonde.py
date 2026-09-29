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
"""
import ipaddress
import json
import sys

MAILLE_RLOC = bytes.fromhex("000000fffe00")


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


def main():
    entree, sortie = sys.argv[1], sys.argv[2]
    a = Anonymiseur()
    messages = [json.loads(l) for l in open(entree, encoding="utf-8") if l.strip()]
    # Le prefixe du reseau maille (sonde attachee) d'abord : il recoit toujours
    # le premier /48 factice.
    for m in messages:
        if m.get("t") == "etat" and m.get("prefixeMaille") and m.get("role") in ("child", "router", "leader"):
            a.prefixe48(bytes.fromhex(m["prefixeMaille"])[:6])
            break
    lignes = [json.dumps(a.message(m), ensure_ascii=False, sort_keys=True) for m in messages]
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
