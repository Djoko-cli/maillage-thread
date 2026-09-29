// Tests hote de sonde/src/distant.{h,cpp} : rid, liste blanche, reponses
// gardees, cadence. Lancer : sh sonde/test/lancer.sh
#include <stdio.h>
#include <string.h>

#include <string>
#include <vector>

#include "distant.h"

using namespace distant;

static int gChecks = 0, gFails = 0;
#define CHECK(cond, ...)                              \
  do {                                                \
    gChecks++;                                        \
    if (!(cond)) {                                    \
      gFails++;                                       \
      printf("ECHEC %s:%d : ", __FILE__, __LINE__);   \
      printf(__VA_ARGS__);                            \
      printf("\n");                                   \
    }                                                 \
  } while (0)

static bool rid(const char *texte, uint32_t *r, std::string *cmd) {
  std::vector<char> b(texte, texte + strlen(texte) + 1);
  char *c = nullptr;
  const bool ok = lireRid(b.data(), r, &c);
  if (ok) *cmd = c;
  return ok;
}

static std::vector<std::string> gRendu;
static void rendu(void *, const uint8_t *l, size_t n) { gRendu.emplace_back((const char *)l, n); }

static std::vector<std::string> rendre(Gardees &g, uint32_t r, bool *trouve = nullptr) {
  gRendu.clear();
  const bool t = g.rendre(r, rendu, nullptr);
  if (trouve) *trouve = t;
  return gRendu;
}

static void ajoute(Gardees &g, const std::string &s) { g.ajouter((const uint8_t *)s.data(), s.size()); }

int main() {
  uint32_t r = 0;
  std::string c;
  // rid
  CHECK(rid("0 etat", &r, &c) && r == 0 && c == "etat", "0");
  CHECK(rid("7 diag 0400 0,1 5", &r, &c) && r == 7 && c == "diag 0400 0,1 5", "7 diag");
  CHECK(rid("4294967295 bonjour", &r, &c) && r == 4294967295u, "max");
  CHECK(rid("12", &r, &c) && r == 12 && c.empty(), "rid seul : commande vide");
  CHECK(rid("12 ", &r, &c) && r == 12 && c.empty(), "rid et espace : commande vide");
  CHECK(rid("12  etat", &r, &c) && c == " etat", "deux espaces : la commande garde le second");
  CHECK(!rid("4294967296 etat", &r, &c), "trop grand");
  CHECK(!rid("99999999999 etat", &r, &c), "11 chiffres");
  CHECK(!rid("012 etat", &r, &c), "zero de tete");
  CHECK(!rid("00 etat", &r, &c), "00");
  CHECK(!rid("", &r, &c), "vide");
  CHECK(!rid(" 1 etat", &r, &c), "espace de tete");
  CHECK(!rid("1x etat", &r, &c), "1x");
  CHECK(!rid("-1 etat", &r, &c), "-1");
  CHECK(!rid("+1 etat", &r, &c), "+1");
  CHECK(!rid("1?etat", &r, &c), "1?");
  // texteRid
  char t[kRidMax + 1];
  CHECK(texteRid(0, t) == 1 && !strcmp(t, "0"), "texte 0");
  CHECK(texteRid(4294967295u, t) == 10 && !strcmp(t, "4294967295"), "texte max");
  CHECK(texteRid(1000, t) == 4 && !strcmp(t, "1000"), "texte 1000");
  // liste blanche
  const char *oui[] = {"bonjour", "etat", "voisins", "routeurs", "diag 0400 0 1", "diag ", "  etat", " diag x"};
  const char *non[] = {"", "cle", "cle nouvelle", "cle efface", "nom x", "oubli", "Bonjour", "etat ", "etatx",
                       "diag", "routeur", "voisins x", "bonjour\t", "diagx 1", "routeurs;oubli"};
  for (const char *x : oui) CHECK(permise(x), "permise : %s", x);
  for (const char *x : non) CHECK(!permise(x), "refusee : %s", x);

  // Reponses gardees
  static Gardees g;
  bool trouve = true;
  CHECK(rendre(g, 1, &trouve).empty() && !trouve, "vide");
  g.commencer(1);
  ajoute(g, "{\"a\":1}");
  g.terminer();
  CHECK(rendre(g, 1) == std::vector<std::string>{"{\"a\":1}"}, "une ligne");
  ajoute(g, "hors reponse");
  CHECK(rendre(g, 1).size() == 1 && g.reponses() == 1, "ligne hors reponse ignoree");
  g.commencer(2);
  ajoute(g, "L1");
  ajoute(g, "L2");
  ajoute(g, "L3");
  g.terminer();
  CHECK((rendre(g, 2) == std::vector<std::string>{"L1", "L2", "L3"}), "trois lignes dans l'ordre");
  CHECK(g.reponses() == 2, "2 reponses");
  // Commencer sans ligne : rien de garde (un diag qui part).
  g.commencer(3);
  g.terminer();
  CHECK(!(rendre(g, 3, &trouve), trouve) && g.reponses() == 2, "reponse sans ligne : rien");
  // Meme rid recommence : l'ancienne reponse est oubliee.
  g.commencer(1);
  ajoute(g, "neuf");
  g.terminer();
  CHECK(rendre(g, 1) == std::vector<std::string>{"neuf"}, "rid recommence : remplace");
  CHECK((rendre(g, 2) == std::vector<std::string>{"L1", "L2", "L3"}), "les autres restent");
  // 8 reponses au plus : la plus ancienne part.
  g.vider();
  for (uint32_t i = 10; i < 19; i++) {
    g.commencer(i);
    ajoute(g, "r" + std::to_string(i));
    g.terminer();
  }
  CHECK(g.reponses() == 8, "8 au plus (%zu)", g.reponses());
  CHECK(!(rendre(g, 10, &trouve), trouve), "la plus ancienne partie");
  CHECK(rendre(g, 11) == std::vector<std::string>{"r11"} && rendre(g, 18) == std::vector<std::string>{"r18"},
        "les 8 dernieres");
  // Place : les plus anciennes partent, jamais une partie de la reponse en cours.
  g.vider();
  const std::string mille(1000, 'x');
  for (uint32_t i = 20; i < 24; i++) {
    g.commencer(i);
    ajoute(g, mille);
    g.terminer();
  }
  CHECK(g.reponses() == 4 && g.octets() == 4 * 1006, "4 x 1006 octets");
  g.commencer(24);
  ajoute(g, mille);
  g.terminer();
  CHECK(g.reponses() == 4 && !(rendre(g, 20, &trouve), trouve) && rendre(g, 24).size() == 1,
        "la plus ancienne chassee pour la place");
  // Reponse plus grande que kOctets : rien n'en est garde, les autres partent.
  g.commencer(30);
  for (int i = 0; i < 5; i++) ajoute(g, mille);
  g.terminer();
  CHECK(!(rendre(g, 30, &trouve), trouve), "reponse trop grande : pas gardee du tout");
  CHECK(g.octets() <= Gardees::kOctets, "octets bornes (%zu)", g.octets());
  // ... et apres l'abandon, les lignes suivantes de ce rid ne reviennent pas.
  g.commencer(31);
  ajoute(g, "a");
  g.terminer();
  CHECK(rendre(g, 31) == std::vector<std::string>{"a"}, "reponse suivante gardee");
  // Ligne seule plus grande que kOctets.
  g.commencer(32);
  ajoute(g, std::string(Gardees::kOctets, 'y'));
  g.terminer();
  CHECK(!(rendre(g, 32, &trouve), trouve) && rendre(g, 31).size() == 1, "ligne geante : ignoree");
  // Remplissage exact : 4096 octets tout juste.
  g.vider();
  g.commencer(40);
  ajoute(g, std::string(Gardees::kOctets - 6, 'z'));
  g.terminer();
  CHECK(g.octets() == Gardees::kOctets && rendre(g, 40).size() == 1, "remplissage exact");
  g.commencer(41);
  ajoute(g, "b");
  g.terminer();
  CHECK(!(rendre(g, 40, &trouve), trouve) && rendre(g, 41).size() == 1, "le suivant chasse le plein");
  // rid 0 et rid max
  g.vider();
  g.commencer(0);
  ajoute(g, "zero");
  g.commencer(4294967295u);
  ajoute(g, "max");
  g.terminer();
  CHECK(rendre(g, 0) == std::vector<std::string>{"zero"} && rendre(g, 4294967295u) == std::vector<std::string>{"max"},
        "rid 0 et max");
  // Lignes vides
  g.commencer(5);
  ajoute(g, "");
  g.terminer();
  CHECK(rendre(g, 5) == std::vector<std::string>{""}, "ligne vide gardee");
  // Cadence (copie de Halo) : 20 lignes par seconde glissante.
  Cadence k;
  for (uint32_t i = 0; i < 20; i++) CHECK(k.allow(1000 + i), "ligne %u acceptee", (unsigned)i);
  CHECK(!k.allow(1100), "21e ligne dans la seconde : refusee");
  CHECK(!k.allow(1999), "encore refusee a 999 ms de la premiere");
  CHECK(k.allow(2000), "acceptee une seconde apres la premiere");
  CHECK(!k.allow(2000), "puis refusee (la deuxieme est a 1001)");
  CHECK(k.allow(2001), "acceptee une seconde apres la deuxieme");
  Cadence w;  // retour a zero de millis()
  for (uint32_t i = 0; i < 20; i++) w.allow(0xFFFFFF00u + i);
  CHECK(!w.allow(0xFFFFFFF0u), "retour a zero : refusee dans la seconde");
  CHECK(w.allow(0xFFFFFF00u + 1000u), "retour a zero : acceptee une seconde apres (millis repasse par 0)");
  printf("test_distant : %d verification(s), %d echec(s)\n", gChecks, gFails);
  return gFails ? 1 : 0;
}
