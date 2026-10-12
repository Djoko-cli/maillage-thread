"""Tests de l'outil de banc du passeur : trames et resumes, sans reseau."""
import importlib.util
import json
import pathlib
import unittest

CHEMIN = pathlib.Path(__file__).resolve().parent.parent / "verifier-passeur.py"
spec = importlib.util.spec_from_file_location("verifier_passeur", CHEMIN)
vp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vp)


def trame(objet):
    j = json.dumps(objet).encode()
    return str(len(j)).encode() + b"\n" + j


class Trames(unittest.TestCase):
    def test_plusieurs_et_reste(self):
        a, b = trame({"t": "relire", "v": 1}), trame({"t": "etat", "v": 1})
        trames, reste = vp.lire_trames(a + b + b"12\n{")
        self.assertEqual([json.loads(t)["t"] for t in trames], ["relire", "etat"])
        self.assertEqual(reste, b"12\n{")

    def test_longueur_fausse(self):
        with self.assertRaises(ValueError):
            vp.lire_trames(b"x\n{}")
        with self.assertRaises(ValueError):
            vp.lire_trames(b"0\n")


class Resumes(unittest.TestCase):
    def test_releve_sans_noms(self):
        noms = {"version": 2, "statut": "ok", "accessoires": [{"nom": "Secret", "id": "X"}, {"nom": "Autre"}],
                "zones": [{"nom": "Etage", "pieces": ["Chambre"]}]}
        texte = vp.resumer({"t": "releve", "v": 1, "noms": noms})
        self.assertIn("2 accessoires", texte)
        self.assertIn("1 avec id", texte)
        self.assertNotIn("Secret", texte)
        self.assertNotIn("Chambre", texte)

    def test_etat(self):
        texte = vp.resumer({"t": "etat", "v": 1, "version": "2.0", "acces": "autorise",
                            "ouvertureSession": "inactive", "profilExpire": None})
        self.assertIn("2.0", texte)
        self.assertIn("autorise", texte)

    def test_inconnu(self):
        self.assertIn("allumer", vp.resumer({"t": "allumer", "v": 1}))


if __name__ == "__main__":
    unittest.main()
