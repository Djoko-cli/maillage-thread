#!/usr/bin/env python3
"""Essai de la sonde de maillage : commandes USB, capture et decodage.

  python3 sonde_essai.py <port> <capture.jsonl> <commande> [<commande> ...]

Commandes : bonjour, etat, voisins, "diag <cible> <t,t,...> <id>", ecoute:<s>
(lit <s> secondes sans rien envoyer). Chaque ligne machine (RS + JSON) est
ajoutee a la capture avec l'heure ; les reponses diag sont decodees a l'ecran.
Ouverture sure du C6 (comme benq tools/halo_udp.py) : DTR = RTS = 0 en un
seul appel, jamais RTS=1 DTR=0 qui le redemarre.
"""
import fcntl, ipaddress, json, os, select, struct, sys, termios, time


def ouvrir(chemin):
    fd = os.open(chemin, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    fcntl.ioctl(fd, termios.TIOCEXCL)
    fcntl.ioctl(fd, termios.TIOCMSET, struct.pack("I", 0))
    i, o, c, l, _, _, cc = termios.tcgetattr(fd)
    i &= ~(termios.IGNBRK | termios.BRKINT | termios.PARMRK | termios.ISTRIP | termios.INLCR | termios.IGNCR
           | termios.ICRNL | termios.IXON)
    o &= ~termios.OPOST
    l &= ~(termios.ECHO | termios.ECHONL | termios.ICANON | termios.ISIG | termios.IEXTEN)
    c &= ~(termios.CSIZE | termios.PARENB | termios.HUPCL)
    c |= termios.CS8 | termios.CLOCAL | termios.CREAD
    termios.tcsetattr(fd, termios.TCSANOW, [i, o, c, l, termios.B115200, termios.B115200, cc])
    return fd


class Lecteur:
    def __init__(self, fd, capture):
        self.fd, self.capture, self.tampon = fd, capture, b""

    def lignes(self, jusqua):
        """Lignes machine decodees jusqu'a l'echeance ; les autres sont affichees telles quelles."""
        while time.time() < jusqua:
            r, _, _ = select.select([self.fd], [], [], 0.1)
            if r:
                try:
                    self.tampon += os.read(self.fd, 4096)
                except BlockingIOError:
                    pass
            while b"\n" in self.tampon:
                brut, self.tampon = self.tampon.split(b"\n", 1)
                brut = brut.rstrip(b"\r")
                if brut.startswith(b"\x1e"):
                    try:
                        m = json.loads(brut[1:].decode("ascii"))
                    except (ValueError, UnicodeDecodeError):
                        print("?? ligne machine illisible :", brut[:120])
                        continue
                    with open(self.capture, "a") as f:
                        f.write(json.dumps({"heure": time.strftime("%Y-%m-%dT%H:%M:%S"), **m}) + "\n")
                    yield m
                elif brut.strip():
                    print("   |", brut.decode("ascii", "replace")[:160])


def nom_tlv(t):
    return {0: "ExtMac", 1: "Address16", 2: "Mode", 3: "Timeout", 4: "Connectivity", 5: "Route64", 6: "LeaderData",
            7: "NetworkData", 8: "IPv6", 9: "MacCounters", 14: "Batterie", 15: "Tension", 16: "ChildTable",
            17: "ChannelPages", 19: "MaxChildTimeout", 24: "Version", 25: "VendorName", 26: "VendorModel",
            27: "VendorSwVersion", 28: "ThreadStackVersion", 29: "Child", 30: "ChildIpv6", 31: "RouterNeighbor",
            34: "MleCounters", 35: "VendorAppUrl"}.get(t, f"TLV{t}")


def mode_texte(m):
    return ("r" if m & 0x08 else "-") + ("d" if m & 0x02 else "-") + ("n" if m & 0x01 else "-")


def decoder(hexa):
    o, i, res = bytes.fromhex(hexa), 0, []
    while i + 2 <= len(o):
        t, n = o[i], o[i + 1]
        v = o[i + 2:i + 2 + n]
        i += 2 + n
        if t == 0:
            d = v.hex().upper()
        elif t == 1:
            d = f"{int.from_bytes(v, 'big'):04X}"
        elif t == 2:
            d = mode_texte(v[0]) if v else "?"
        elif t == 5 and len(v) >= 9:
            masque = int.from_bytes(v[1:9], "big")
            ids = [r for r in range(64) if masque & (1 << (63 - r))]
            routes = []
            for r, b in zip(ids, v[9:]):
                routes.append(f"{r}(out{b >> 6} in{(b >> 4) & 3} cout{b & 15})")
            d = f"seq {v[0]} ; " + " ".join(routes)
        elif t == 6 and len(v) >= 8:
            d = f"partition {v[0:4].hex().upper()} poids {v[4]} version {v[5]}/{v[6]} chef {v[7]}"
        elif t == 8:
            d = ", ".join(str(ipaddress.IPv6Address(v[k:k + 16])) for k in range(0, len(v) - 15, 16))
        elif t == 16:
            e = []
            for k in range(0, len(v) - 2, 3):
                x = int.from_bytes(v[k:k + 2], "big")
                e.append(f"id{x & 0x1FF}(lq{(x >> 9) & 3} delai2^{(x >> 11) - 4}s {mode_texte(v[k + 2])})")
            d = f"{len(e)} enfant(s) : " + " ".join(e)
        elif t == 24:
            d = str(int.from_bytes(v, "big"))
        elif t in (25, 26, 27, 28, 35):
            d = repr(v.decode("utf-8", "replace"))
        else:
            d = v.hex().upper()
        res.append(f"{nom_tlv(t)}: {d}")
    return res


def main():
    port, capture, commandes = sys.argv[1], sys.argv[2], sys.argv[3:]
    fd = ouvrir(port)
    lecteur = Lecteur(fd, capture)
    try:
        for c in commandes:
            if c.startswith("ecoute:"):
                for m in lecteur.lignes(time.time() + float(c.split(":")[1])):
                    print(json.dumps(m, ensure_ascii=False))
                continue
            print(f">> {c}")
            os.write(fd, (c + "\n").encode("ascii"))
            attendu = c.split()[0]
            delai = 50 if attendu == "diag" else 5
            for m in lecteur.lignes(time.time() + delai):
                if m.get("t") == "diag" and m.get("ok") and "tlv" in m:
                    print(f"<< diag {m['cible']} : {m['ms']} ms, code {m.get('code')}, {len(m['tlv']) // 2} octets")
                    for ligne in decoder(m["tlv"]):
                        print("     ", ligne)
                else:
                    print("<<", json.dumps(m, ensure_ascii=False))
                if m.get("t") == "erreur":
                    break
                if m.get("t") == attendu and (attendu != "diag" or m.get("id") == int(c.split()[3])):
                    break
    finally:
        os.close(fd)


if __name__ == "__main__":
    main()


def network_data(o):
    """Network Data (TLV 7) : prefixes, routeurs de bordure, routes et services, par RLOC16."""
    res, i = [], 0
    while i + 2 <= len(o):
        t, n = o[i] >> 1, o[i + 1]
        v = o[i + 2:i + 2 + n]
        i += 2 + n
        if t == 1 and len(v) >= 2:  # Prefix
            bits = v[1]
            pre = v[2:2 + (bits + 7) // 8]
            pre16 = pre + bytes(16 - len(pre))
            texte = f"{ipaddress.IPv6Address(pre16)}/{bits}"
            j = 2 + (bits + 7) // 8
            while j + 2 <= len(v):
                st, sn = v[j] >> 1, v[j + 1]
                sv = v[j + 2:j + 2 + sn]
                j += 2 + sn
                if st == 2:
                    res.append(f"prefixe {texte} : routeurs de bordure " + " ".join(f"{int.from_bytes(sv[k:k+2],'big'):04X}" for k in range(0, len(sv) - 3, 4)))
                elif st == 0:
                    res.append(f"prefixe {texte} : route par " + " ".join(f"{int.from_bytes(sv[k:k+2],'big'):04X}" for k in range(0, len(sv) - 2, 3)))
        elif t == 5 and len(v) >= 1:  # Service
            j = 1 if v[0] & 0x80 else 5
            if j >= len(v):
                continue
            dl = v[j]
            donnees = v[j + 1:j + 1 + dl]
            j += 1 + dl
            serveurs = []
            while j + 2 <= len(v):
                st, sn = v[j] >> 1, v[j + 1]
                if st == 6 and sn >= 2:
                    serveurs.append(f"{int.from_bytes(v[j+2:j+4],'big'):04X}")
                j += 2 + sn
            res.append(f"service {donnees.hex()} : serveurs " + " ".join(serveurs))
    return res
