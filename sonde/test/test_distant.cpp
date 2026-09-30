// Tests hote de sonde/src/distant.{h,cpp} : rid, liste blanche, reponses
// gardees, cadence ; entiers des commandes, reprises CoAP d'un diag, LED de
// la carte (1.0.3). Lancer : sh sonde/test/lancer.sh
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

static bool entier(const char *texte, uint32_t attendu) {
  uint32_t v = 12345;
  return lireEntier(texte, &v) && v == attendu;
}

static bool pasEntier(const char *texte) {
  uint32_t v = 12345;
  return !lireEntier(texte, &v) && v == 12345;  // refuse, et v intact
}

// Attente totale d'un diag avant l'echec « delai » : accuse x (2^(r+1) - 1).
static uint64_t attente(Reprises r) { return (uint64_t)r.accuseMs * ((1u << (r.reprises + 1)) - 1); }

// Couleurs de la LED sur [de, a), lues a chaque milliseconde (loop() les lit
// toutes les 5 ms environ) ; a peut suivre le retour a zero. true si toutes
// valent c.
static bool couleurs(Voyant &v, uint32_t de, uint32_t a, Voyant::Couleur c) {
  bool ok = true;
  for (uint32_t t = de; t != a; t++) ok = v.couleur(t) == c && ok;
  return ok;
}

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

  // Entiers des commandes (1.0.3) : id et delai de diag, id de cle nouvelle.
  CHECK(entier("0", 0) && entier("7", 7) && entier("45000", 45000), "entiers simples");
  CHECK(entier("007", 7) && entier("0000000000", 0), "zeros de tete permis");
  CHECK(entier("4294967295", 4294967295u), "max");
  const char *pasEntiers[] = {"", "4294967296", "99999999999", "00000000001", "-1", "+1", " 1",
                              "1 ", "12x", "x", "0x10", "1.5", "6000ms"};
  for (const char *x : pasEntiers) CHECK(pasEntier(x), "pas un entier : '%s'", x);

  // Reprises CoAP d'un diag (1.0.3) : l'echec tombe au bout du delai demande.
  const Reprises r6 = reprisesDiag(6000), r8 = reprisesDiag(8000);
  CHECK(r6.reprises == 1 && r6.accuseMs == 2000 && r8.reprises == 1 && r8.accuseMs == 2666,
        "6 et 8 s (ceux de l'app) : inchanges");
  CHECK(attente(reprisesDiag(10000)) == 9999 && attente(reprisesDiag(12000)) == 12000,
        "10 a 15 s : plus arrondi a 15 s");
  CHECK(reprisesDiag(14999).reprises == 1 && attente(reprisesDiag(14999)) == 14997, "14999 ms : une reprise");
  CHECK(reprisesDiag(15000).reprises == 3 && reprisesDiag(15000).accuseMs == 1000, "15 s : trois reprises");
  CHECK(reprisesDiag(45000).accuseMs == 3000 && reprisesDiag(60000).accuseMs == 4000, "45 et 60 s");
  CHECK(reprisesDiag(3000).accuseMs == 1000 && attente(reprisesDiag(3000)) == 3000, "3 s : accuse de 1 s");
  CHECK(reprisesDiag(0).accuseMs == 1000 && reprisesDiag(2999).accuseMs == 1000,
        "sous 3 s (main.cpp borne avant) : accuse jamais sous 1 s");
  // Tout delai permis : accuse d'au moins 1 s, attente au plus le delai, a l'arrondi pres.
  uint32_t fautif = 0;
  for (uint32_t d = 3000; d <= 60000 && !fautif; d++) {
    const Reprises rd = reprisesDiag(d);
    const uint64_t a = attente(rd), facteur = (1u << (rd.reprises + 1)) - 1;
    if (rd.accuseMs < 1000 || a > d || d - a >= facteur) fautif = d;
  }
  CHECK(!fautif, "delai %u ms : attente hors du delai", (unsigned)fautif);

  // LED de la carte (1.0.3). V : eclair vert, E : eclair de l'extinction,
  // B : bref eclair de la suspension, P : sa periode.
  const uint32_t V = Voyant::kVertMs, E = Voyant::kExtinctionMs, B = Voyant::kBrefMs, P = Voyant::kPeriodeMs;
  CHECK(V == 100 && E == 500 && B == 100 && P == 10000, "durees : 100, 500, 100 ms et 10 s");
  Voyant neuf;
  CHECK(neuf.couleur(0) == Voyant::kNoire, "LED neuve : eteinte");
  Voyant v;
  v.demarrer(false, 1000);
  CHECK(couleurs(v, 1000, 30000, Voyant::kNoire), "allumee au demarrage : eteinte, aucun eclair");
  // Interrupteur allume : deux eclairs verts rapides, puis rien.
  v.changer(false, 40000);
  CHECK(couleurs(v, 40000, 40000 + V, Voyant::kVerte), "premier eclair vert");
  CHECK(couleurs(v, 40000 + V, 40000 + 2 * V, Voyant::kNoire), "pause entre les eclairs verts");
  CHECK(couleurs(v, 40000 + 2 * V, 40000 + 3 * V, Voyant::kVerte), "second eclair vert");
  CHECK(couleurs(v, 40000 + 3 * V, 80000, Voyant::kNoire), "apres les eclairs verts : eteinte");
  // Eteint : un eclair orange d'une demi-seconde, puis un bref toutes les 10 s.
  v.changer(true, 100000);
  CHECK(couleurs(v, 100000, 100000 + E, Voyant::kOrange), "extinction : orange 500 ms");
  CHECK(couleurs(v, 100000 + E, 100000 + P, Voyant::kNoire), "puis rien jusqu'a 10 s");
  CHECK(couleurs(v, 100000 + P, 100000 + P + B, Voyant::kOrange), "bref eclair orange a 10 s");
  CHECK(couleurs(v, 100000 + P + B, 100000 + 2 * P, Voyant::kNoire), "puis rien jusqu'a 20 s");
  CHECK(couleurs(v, 100000 + 2 * P, 100000 + 2 * P + B, Voyant::kOrange), "bref eclair orange a 20 s");
  // Rallume pendant la suspension : les eclairs verts, puis plus d'orange.
  v.changer(false, 125000);
  CHECK(couleurs(v, 125000, 125000 + V, Voyant::kVerte), "rallumee : vert tout de suite");
  CHECK(couleurs(v, 125000 + 3 * V, 200000, Voyant::kNoire), "rallumee : plus d'eclair orange");
  // Eteint pendant les eclairs verts : l'orange tout de suite.
  v.changer(false, 300000);
  CHECK(v.couleur(300000) == Voyant::kVerte, "eclairs verts en cours");
  v.changer(true, 300000 + V / 2);
  CHECK(couleurs(v, 300000 + V / 2, 300000 + V / 2 + E, Voyant::kOrange), "eteinte pendant le vert : orange");
  // Suspendue au demarrage (etat garde) : un bref eclair des le demarrage, puis toutes les 10 s.
  Voyant s;
  s.demarrer(true, 5000);
  CHECK(couleurs(s, 5000, 5000 + B, Voyant::kOrange), "suspendue au demarrage : bref eclair tout de suite");
  CHECK(couleurs(s, 5000 + B, 5000 + P, Voyant::kNoire), "suspendue au demarrage : puis rien");
  CHECK(couleurs(s, 5000 + P, 5000 + P + B, Voyant::kOrange), "suspendue au demarrage : et a 10 s");
  // loop() retenue : l'eclair en cours se voit encore, les echeances passees sont sautees.
  Voyant lent;
  lent.demarrer(true, 0);
  CHECK(lent.couleur(0) == Voyant::kOrange, "premier eclair");
  CHECK(lent.couleur(3 * P + B / 2) == Voyant::kOrange, "retenue 30 s : l'eclair en cours");
  CHECK(lent.couleur(3 * P + B) == Voyant::kNoire && lent.couleur(4 * P - 1) == Voyant::kNoire,
        "retenue : rien jusqu'au suivant");
  CHECK(lent.couleur(4 * P) == Voyant::kOrange, "retenue : le suivant a l'heure");
  CHECK(lent.couleur(7 * P + P / 2) == Voyant::kNoire && lent.couleur(8 * P) == Voyant::kOrange,
        "retenue entre deux eclairs : recalee sur la periode");
  // Retour a zero de millis() : les eclairs continuent ; une sequence finie ne revient pas.
  Voyant z;
  z.demarrer(true, 0xFFFFFF00u);
  CHECK(z.couleur(0xFFFFFF00u) == Voyant::kOrange, "zero : eclair juste avant");
  CHECK(couleurs(z, 0xFFFFFF00u + B, 0xFFFFFF00u + P, Voyant::kNoire), "zero : rien en passant par 0");
  CHECK(couleurs(z, 0xFFFFFF00u + P, 0xFFFFFF00u + P + B, Voyant::kOrange), "zero : eclair a l'heure apres");
  Voyant y;
  y.changer(false, 0xFFFFFFF0u);
  CHECK(couleurs(y, 0xFFFFFFF0u, 0xFFFFFFF0u + V, Voyant::kVerte), "zero : eclair vert a cheval");
  CHECK(couleurs(y, 0xFFFFFFF0u + 3 * V, 1000, Voyant::kNoire), "zero : fin des eclairs verts");
  CHECK(couleurs(y, 0xFFFFFFF0u, 0xFFFFFFF0u + 3 * V, Voyant::kNoire),
        "sequence finie : pas ranimee quand millis() repasse par les memes valeurs");
  // Suspendue plus de 49,7 jours, un tour toutes les 5 s : un eclair toutes les
  // 10 s de temps reel, avant, pendant et apres le retour a zero de millis().
  Voyant longue;
  longue.demarrer(true, 0);
  uint64_t horsDeLHeure = 0, eclairs = 0;
  for (uint64_t reel = 0; reel < (1ull << 32) + 3 * P; reel += 5000) {
    const bool orange = longue.couleur((uint32_t)reel) == Voyant::kOrange;
    eclairs += orange;
    if (orange != (reel % P == 0)) horsDeLHeure++;
  }
  CHECK(!horsDeLHeure && eclairs == ((1ull << 32) + 3 * P - 1) / P + 1,
        "suspendue 50 jours : %llu tour(s) hors de l'heure, %llu eclairs", (unsigned long long)horsDeLHeure,
        (unsigned long long)eclairs);

  printf("test_distant : %d verification(s), %d echec(s)\n", gChecks, gFails);
  return gFails ? 1 : 0;
}
