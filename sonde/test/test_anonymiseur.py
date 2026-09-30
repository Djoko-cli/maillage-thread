#!/usr/bin/env python3
"""Tests de la garde de outils/anonymiser-sonde.py.

  python3 sonde/test/test_anonymiseur.py
  python3 -m unittest discover -s sonde/test        (tous les tests Python, depuis la racine du depot)

La garde : l'anonymiseur ne connait que les messages bonjour, etat et diag de la capture du 29/09/2026.
Tout autre type de message, champ ou TLV le fait echouer avant toute ecriture, avec un message clair
qui ne cite que des noms, jamais une valeur. Une capture de la sonde 1.0.2 (etat.ext, bonjour.hote,
voisins...) ne peut donc plus passer sans avoir ete vue.

Donnees inventees : les valeurs "reelles" de la capture brute ci-dessous n'ont jamais existe (ExtMac
DEADBEEF..., prefixes de documentation 2001:db8). La capture anonymisee du depot sert de reference.
"""
import importlib.util
import ipaddress
import json
import os
import subprocess
import sys
import tempfile
import unittest

ICI = os.path.dirname(os.path.abspath(__file__))
DEPOT = os.path.normpath(os.path.join(ICI, "..", ".."))
SCRIPT = os.path.join(DEPOT, "outils", "anonymiser-sonde.py")
CAPTURE_ANONYME = os.path.join(DEPOT, "docs", "releves", "2026-09-29", "capture-sonde.jsonl")

# Le nom du script a un tiret : on le charge par son chemin.
_spec = importlib.util.spec_from_file_location("anonymiser_sonde", SCRIPT)
anon = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(anon)

# Valeurs "reelles" inventees de la capture brute.
EXT_PARENT = "DEADBEEF00000001"
EXT_ROUTEUR = "DEADBEEF00000002"
EXT_INCONNU = "DEADBEEF00000003"  # celle d'un champ que l'anonymiseur ne connait pas
XP = "FEEDFACECAFEBEEF"
MAC = "DEADBEEF0001"
CODE, QR = "99988877766", "MT:FAUX0000000000000000"
PREFIXE_MAILLE, PREFIXE_OMR = "2001:db8:a1b2", "2001:db8:c3d4"
IID_OMR = "aabb:ccdd:eeff:1122"
# Tout ce qui ne doit plus se lire dans une sortie (minuscules, sans deux-points).
REEL = [EXT_PARENT, EXT_ROUTEUR, EXT_INCONNU, XP, MAC, CODE, "FAUX0000000000000000", "20010db8a1b2", "20010db8c3d4",
        "aabbccddeeff1122", "dcadbeef00000002"]  # dernier : l'IID lien-local de EXT_ROUTEUR (bit U/L inverse)


def tlv(t, valeur):
    return bytes([t, len(valeur)]) + valeur


def ipv6(texte):
    return ipaddress.IPv6Address(texte).packed


def charge_diag():
    """Charge TLV d'un diag de routeur : ExtMac, Address16, Network Data, adresses, version."""
    ext = bytes.fromhex(EXT_ROUTEUR)
    lien_local = ipv6("fe80::")[:8] + bytes([ext[0] ^ 0x02]) + ext[1:]
    omr = ipv6("%s:0:%s" % (PREFIXE_OMR, IID_OMR))
    rloc = ipv6("%s:0:0:ff:fe00:5000" % PREFIXE_MAILLE)
    reseau = (tlv(0x03, bytes([0, 64]) + ipv6(PREFIXE_OMR + "::")[:8] + tlv(0x05, bytes.fromhex("50000100")))
              + tlv(0x0B, bytes([0x81, 1, 0x5D]) + tlv(0x0D, bytes.fromhex("5000") + omr + bytes.fromhex("1680"))))
    return (tlv(0, ext) + tlv(1, bytes.fromhex("5000")) + tlv(7, reseau) + tlv(8, lien_local + omr + rloc)
            + tlv(24, b"\x04")).hex().upper()


def capture_inventee():
    """Une capture brute inventee, de la forme que sonde_essai.py ecrit : bonjour, etat, diag."""
    return [
        {"heure": "2026-09-28T23:44:56", "t": "bonjour", "v": 1, "produit": "sonde-maillage", "version": "0.1.0-essai",
         "mac": MAC, "appairee": False, "code": CODE, "qr": QR},
        {"heure": "2026-09-28T23:44:59", "t": "etat", "v": 1, "role": "child", "rloc16": "5005", "mode": "rn",
         "parent": {"rloc16": "5000", "ext": EXT_PARENT, "lqIn": 3, "lqOut": 3, "rssi": -60, "rssiDernier": -61,
                    "age": 4},
         "partition": "1A2B3C4D", "chef": 24, "canal": 15, "prefixeMaille": "20010DB8A1B20000", "xp": XP,
         "suspendue": False},
        {"heure": "2026-09-28T23:46:34", "t": "diag", "v": 1, "id": 101, "cible": "5000", "ms": 2782, "ok": True,
         "code": "2.04", "tlv": charge_diag()},
        {"heure": "2026-09-28T23:58:47", "t": "diag", "v": 1, "id": 301, "cible": "%s:0:%s" % (PREFIXE_OMR, IID_OMR),
         "ms": 30000, "ok": False, "erreur": "delai"},
    ]


def controle(*messages):
    """La garde sur ces messages, numerotes a partir de 1."""
    return anon.controler(list(enumerate(messages, 1)))


# ---------------------------------------------------------------------------
#  La garde, sans lancer l'outil
# ---------------------------------------------------------------------------


class Garde(unittest.TestCase):
    def test_la_capture_actuelle_passe(self):
        numerotes = anon.lire(CAPTURE_ANONYME)
        self.assertEqual({m["t"] for _, m in numerotes}, {"bonjour", "etat", "diag"}, "les trois types y sont")
        self.assertEqual(anon.controler(numerotes), {})

    def test_une_capture_brute_inventee_passe(self):
        self.assertEqual(controle(*capture_inventee()), {})

    def test_champs_apparus_depuis_la_capture_font_echouer(self):
        """Les champs que le firmware 1.0.2 ecrit et que la capture du 29/09 n'a pas."""
        de_base = {m["t"]: m for m in capture_inventee()}
        for t, champ in (("etat", "ext"), ("etat", "eligible"), ("bonjour", "nom"), ("bonjour", "hote"),
                         ("diag", "tronquee"), ("etat", "liste"), ("diag", "cle")):
            with self.subTest(champ="%s.%s" % (t, champ)):
                self.assertEqual(controle(dict(de_base[t], **{champ: EXT_INCONNU})),
                                 {"champ inconnu : %s.%s" % (t, champ): [1]})

    def test_champ_inconnu_du_parent(self):
        etat = capture_inventee()[1]
        etat["parent"] = dict(etat["parent"], hote="sonde-ab12")
        self.assertEqual(controle(etat), {"champ inconnu : etat.parent.hote": [1]})

    def test_parent_de_forme_inconnue(self):
        etat = capture_inventee()[1]
        for parent in ([EXT_INCONNU], EXT_INCONNU, 5, True):
            with self.subTest(parent=parent):
                self.assertEqual(controle(dict(etat, parent=parent)), {"forme inconnue : etat.parent": [1]})
        self.assertEqual(controle(dict(etat, parent=None)), {})  # sonde sans parent : connu

    def test_type_de_message_inconnu_fait_echouer(self):
        """voisins et routeurs (1.0.2), cle, erreur, oubli, et tout ce qui n'est pas un nom de type lisible."""
        for t in ("voisins", "routeurs", "cle", "erreur", "oubli", "inconnu", "ETAT", ""):
            with self.subTest(t=t):
                attendu = "type de message inconnu : %s" % (t or "(illisible)")
                self.assertEqual(controle({"t": t, "v": 1, "liste": []}), {attendu: [1]})
        for t in (None, 3, True, ["etat"], {"a": 1}):
            with self.subTest(t=t):
                self.assertEqual(controle({"t": t, "v": 1}), {"type de message inconnu : (illisible)": [1]})
        self.assertEqual(controle({"v": 1}), {"type de message inconnu : (illisible)": [1]})

    def test_type_inconnu_ne_dit_rien_de_ses_champs(self):
        self.assertEqual(controle({"t": "voisins", "v": 1, "liste": [{"ext": EXT_INCONNU}]}),
                         {"type de message inconnu : voisins": [1]})

    def test_ligne_qui_n_est_pas_un_objet(self):
        for ligne in ([1, 2], "texte", 5, None, True):
            with self.subTest(ligne=ligne):
                self.assertEqual(controle(ligne), {"ligne qui n'est pas un objet JSON": [1]})

    def test_raisons_regroupees_avec_les_numeros_de_ligne(self):
        etat = dict(capture_inventee()[1], ext=EXT_INCONNU)
        ok = capture_inventee()[0]
        inconnu = anon.controler([(2, etat), (5, ok), (9, etat), (12, {"t": "voisins"})])
        self.assertEqual(inconnu, {"champ inconnu : etat.ext": [2, 9], "type de message inconnu : voisins": [12]})
        self.assertEqual(list(inconnu), ["champ inconnu : etat.ext", "type de message inconnu : voisins"])

    # --- TLV du diag ---

    def diag_avec(self, charge):
        return dict(capture_inventee()[2], tlv=charge.hex().upper() if isinstance(charge, bytes) else charge)

    def test_tlv_inconnu_fait_echouer(self):
        """29 Child, 30 ChildIpv6 et 31 RouterNeighbor portent des ExtMac ou des adresses : jamais sans etre vus."""
        for t in (29, 30, 31, 9, 34, 35, 255):
            with self.subTest(tlv=t):
                self.assertEqual(controle(self.diag_avec(tlv(1, b"\x50\x00") + tlv(t, bytes.fromhex(EXT_INCONNU)))),
                                 {"TLV inconnu : %d (diag.tlv)" % t: [1]})

    def test_plusieurs_tlv_inconnus_sont_tous_dits(self):
        inconnu = controle(self.diag_avec(tlv(31, b"\x00") + tlv(1, b"\x00\x00") + tlv(29, b"\x00")))
        self.assertEqual(list(inconnu), ["TLV inconnu : 31 (diag.tlv)", "TLV inconnu : 29 (diag.tlv)"])

    def test_tlv_connus_passent(self):
        self.assertEqual(controle(self.diag_avec(b"".join(tlv(t, b"\x00") for t in sorted(anon.TLV_CONNUS)))), {})

    def test_les_tlv_connus_sont_ceux_de_la_capture_actuelle(self):
        vus = set()
        for _, m in anon.lire(CAPTURE_ANONYME):
            o, i = bytes.fromhex(m.get("tlv") or ""), 0
            while i + 2 <= len(o):
                vus.add(o[i])
                i += 2 + o[i + 1]
        inconnus = sorted(vus - anon.TLV_CONNUS)
        self.assertEqual(inconnus, [], "TLV de la capture que la garde ne connait pas")

    def test_tlv_a_longueur_etendue_fait_echouer(self):
        """Longueur 0xFF : la vraie longueur suit sur deux octets. L'anonymiseur ne sait pas la lire."""
        etendu = bytes([16, 0xFF, 0x01, 0x00]) + bytes(256)
        self.assertEqual(controle(self.diag_avec(tlv(1, b"\x50\x00") + etendu)),
                         {"TLV a longueur etendue (diag.tlv)": [1]})

    def test_tlv_tronque_fait_echouer(self):
        for nom, charge in (("valeur coupee", tlv(1, b"\x50\x00") + bytes([16, 9, 1, 2])),
                            ("octet seul", tlv(1, b"\x50\x00") + b"\x01"),
                            ("en-tete seul", bytes([16, 9]))):
            with self.subTest(charge=nom):
                self.assertEqual(controle(self.diag_avec(charge)), {"TLV tronque (diag.tlv)": [1]})

    def test_tlv_illisible_fait_echouer(self):
        for charge in ("ZZ", "123", "0 1", 12, ["00"], {"a": 1}, True):
            with self.subTest(tlv=charge):
                self.assertEqual(controle(self.diag_avec(charge)), {"tlv illisible (diag.tlv)": [1]})

    def test_tlv_vide_ou_absent_passe(self):
        self.assertEqual(controle(self.diag_avec("")), {})
        self.assertEqual(controle(self.diag_avec(None)), {})
        sans_tlv = capture_inventee()[3]
        self.assertNotIn("tlv", sans_tlv)
        self.assertEqual(controle(sans_tlv), {})

    # --- Ce que le refus dit ---

    def test_nom_sur_ne_rend_que_des_noms_courts(self):
        for nom in ("ext", "prefixeMaille", "a_b2", "x" * 32):
            self.assertEqual(anon.nom_sur(nom), nom)
        for nom in ("", "x" * 33, EXT_INCONNU, "cle" + EXT_INCONNU.lower(), "a b", "\u00e9t\u00e9", None, 5, ["ext"]):
            self.assertEqual(anon.nom_sur(nom), "(illisible)", repr(nom))

    def test_le_texte_de_refus_ne_cite_que_des_noms(self):
        """Ni valeur de champ, ni nom abime qui porterait une ExtMac."""
        etat = dict(capture_inventee()[1], ext=EXT_INCONNU)
        etat[EXT_INCONNU] = EXT_ROUTEUR
        texte = anon.texte_refus(anon.controler([(3, etat), (8, {"t": "voisins", "liste": [{"ext": EXT_INCONNU}]})]))
        for valeur in (EXT_INCONNU, EXT_ROUTEUR, XP, MAC):
            self.assertNotIn(valeur.lower(), texte.lower())
        self.assertEqual(texte.splitlines()[0], "refus : la capture contient ce que l'anonymiseur ne connait pas ; "
                                                "rien n'a ete ecrit.")
        self.assertIn("  champ inconnu : etat.ext (1 ligne(s), la premiere : 3)", texte)
        self.assertIn("  champ inconnu : etat.(illisible) (1 ligne(s), la premiere : 3)", texte)
        self.assertIn("  type de message inconnu : voisins (1 ligne(s), la premiere : 8)", texte)
        self.assertIn("CHAMPS_CONNUS", texte.splitlines()[-1])


# ---------------------------------------------------------------------------
#  L'outil, lance comme on le lance
# ---------------------------------------------------------------------------


class Outil(unittest.TestCase):
    def setUp(self):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        self.dossier = d.name
        self.entree = os.path.join(self.dossier, "brute.jsonl")
        self.sortie = os.path.join(self.dossier, "anonyme.jsonl")

    def ecrire(self, messages, brut=""):
        with open(self.entree, "w", encoding="utf-8") as f:
            f.write("".join(json.dumps(m) + "\n" for m in messages) + brut)

    def lancer(self, entree=None):
        return subprocess.run([sys.executable, SCRIPT, entree or self.entree, self.sortie], capture_output=True,
                              text=True, timeout=60)

    def assertRefus(self, r, *attendu):
        """Echec (code 1), message clair sur stderr, rien sur stdout, rien d'ecrit, aucune valeur citee."""
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertEqual(r.stdout, "")
        self.assertIn("refus : ", r.stderr)
        self.assertIn("rien n'a ete ecrit", r.stderr)
        for morceau in attendu:
            self.assertIn(morceau, r.stderr)
        self.assertFalse(os.path.exists(self.sortie), "la sortie ne doit pas etre creee")
        self.assertEqual(os.listdir(self.dossier), ["brute.jsonl"], "rien d'autre n'est ecrit")
        for valeur in REEL:
            self.assertNotIn(valeur.lower(), (r.stdout + r.stderr).lower().replace(":", ""))

    def test_champ_inconnu_echoue_sans_rien_ecrire(self):
        messages = capture_inventee()
        messages[1]["ext"] = EXT_INCONNU
        self.ecrire(messages)
        self.assertRefus(self.lancer(), "champ inconnu : etat.ext (1 ligne(s), la premiere : 2)")

    def test_type_de_message_inconnu_echoue_sans_rien_ecrire(self):
        messages = capture_inventee()
        messages.insert(2, {"heure": "2026-09-28T23:45:00", "t": "voisins", "v": 1,
                            "liste": [{"rloc16": "5000", "ext": EXT_INCONNU, "rssi": -60, "lqi": 3, "routeur": True}]})
        self.ecrire(messages)
        self.assertRefus(self.lancer(), "type de message inconnu : voisins (1 ligne(s), la premiere : 3)")

    def test_tlv_inconnu_echoue_sans_rien_ecrire(self):
        """Un TLV RouterNeighbor (31) porterait un ExtMac que l'anonymiseur laisserait passer."""
        messages = capture_inventee()
        messages[2]["tlv"] = (tlv(31, bytes.fromhex(EXT_INCONNU) + b"\x00") + bytes.fromhex(messages[2]["tlv"])).hex()
        self.ecrire(messages)
        self.assertRefus(self.lancer(), "TLV inconnu : 31 (diag.tlv) (1 ligne(s), la premiere : 3)")

    def test_une_capture_1_0_2_est_refusee(self):
        """Ce que la sonde 1.0.2 ecrit en plus : hote et nom, etat.ext et eligible, voisins, routeurs."""
        messages = capture_inventee()
        messages[0].update(nom="Sonde", hote="sonde-ab12")
        messages[1].update(ext=EXT_INCONNU, eligible=False)
        messages += [{"t": "voisins", "v": 1, "liste": []}, {"t": "routeurs", "v": 1, "liste": [], "suite": False}]
        self.ecrire(messages)
        r = self.lancer()
        self.assertRefus(r, "champ inconnu : bonjour.nom", "champ inconnu : bonjour.hote", "champ inconnu : etat.ext",
                         "champ inconnu : etat.eligible", "type de message inconnu : voisins",
                         "type de message inconnu : routeurs")

    def test_ne_touche_pas_a_une_sortie_qui_existe(self):
        messages = capture_inventee()
        messages[1]["ext"] = EXT_INCONNU
        self.ecrire(messages)
        with open(self.sortie, "w", encoding="utf-8") as f:
            f.write("sortie d'une autre capture\n")
        r = self.lancer()
        self.assertEqual(r.returncode, 1)
        with open(self.sortie, encoding="utf-8") as f:
            self.assertEqual(f.read(), "sortie d'une autre capture\n")

    def test_ligne_illisible_dit_son_numero_sans_la_citer(self):
        self.ecrire(capture_inventee()[:2], brut='{"t":"etat","ext":"%s"\n' % EXT_INCONNU)
        self.assertRefus(self.lancer(), "la ligne 3 n'est pas du JSON")

    def test_lignes_vides_sautees_mais_comptees(self):
        messages = capture_inventee()
        messages[1]["ext"] = EXT_INCONNU
        with open(self.entree, "w", encoding="utf-8") as f:
            f.write(json.dumps(messages[0]) + "\n\n\n" + json.dumps(messages[1]) + "\n")
        self.assertRefus(self.lancer(), "la premiere : 4")

    def test_capture_inventee_anonymisee_sans_valeur_reelle(self):
        messages = capture_inventee()
        self.ecrire(messages)
        r = self.lancer()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(r.stdout.startswith("4 lignes ;"), r.stdout)
        with open(self.sortie, encoding="utf-8") as f:
            texte = f.read()
        sorties = [json.loads(l) for l in texte.splitlines()]
        self.assertEqual(len(sorties), 4)
        bas = texte.lower().replace(":", "")
        for valeur in REEL:
            self.assertNotIn(valeur.lower(), bas)
        # Retire : le code d'appairage et le QR. Remplaces : la MAC, le xp, les ExtMac, les prefixes.
        self.assertEqual((sorties[0]["code"], sorties[0]["qr"]), (None, None))
        self.assertNotEqual(sorties[0]["mac"], MAC)
        self.assertNotEqual(sorties[1]["xp"], XP)
        self.assertNotEqual(sorties[1]["parent"]["ext"], EXT_PARENT)
        self.assertNotEqual(sorties[3]["cible"], messages[3]["cible"])
        # Gardes tels quels : RLOC16, partition, canal, delais, identifiants, erreurs.
        for avant, apres in zip(messages[1:], sorties[1:]):
            for champ in ("heure", "t", "v", "role", "rloc16", "mode", "partition", "chef", "canal", "suspendue", "id",
                          "ms", "ok", "code", "erreur"):
                if champ in avant:
                    self.assertEqual(apres[champ], avant[champ], champ)
        self.assertEqual(sorties[1]["parent"]["rloc16"], "5000")
        self.assertEqual(len(sorties[2]["tlv"]), len(messages[2]["tlv"]), "les TLV gardent leur longueur")

    def test_la_garde_ne_refuse_pas_la_capture_actuelle(self):
        """La capture du depot est deja anonymisee : le controle final peut la refuser (ses valeurs factices
        ressemblent a des valeurs reelles), mais pas la garde."""
        r = self.lancer(entree=CAPTURE_ANONYME)
        self.assertNotIn("ce que l'anonymiseur ne connait pas", r.stderr)


if __name__ == "__main__":
    unittest.main()
