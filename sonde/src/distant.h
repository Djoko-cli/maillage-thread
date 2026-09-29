#pragma once
// ===========================================================================
//  Commandes recues par le reseau : briques pures (contrat de la 1.0.2)
//
//  Charge d'un message H1 de l'app : "<rid> <commande>". rid : entier
//  decimal choisi par l'app (0..4294967295, sans zero de tete), commande :
//  le meme texte que sur l'USB. Charge d'une reponse : "<rid> <ligne JSON>".
//
//  - Liste blanche : bonjour, etat, voisins, routeurs, diag. Tout le reste
//    (cle..., nom, oubli, commande inconnue) : refuse a distance.
//  - Reponses gardees : un rid repete dans la meme session ne relance rien,
//    la reponse gardee repart (les 8 dernieres par session, lignes comprises,
//    comme le cache des 8 dernieres reponses d'une session reseau du pont
//    Halo, benq src/json_out.h, ReplyCache).
//  - Cadence : 20 commandes par seconde glissante et par session au plus
//    (Cadence, copie de celle du pont Halo) ; au-dela, rien (l'app renvoie).
//
//  Pur et sans Arduino : teste sur l'hote.
// ===========================================================================
#include <stddef.h>
#include <stdint.h>

namespace distant {

// Chiffres d'un rid : 4294967295 au plus.
constexpr size_t kRidMax = 10;

// "<rid> <commande>" (C, termine par 0). true : *rid lu et *commande pointe
// apres l'espace qui suit le rid (commande vide si la charge s'arrete au rid).
// false : pas de rid canonique (vide, zero de tete, trop grand, autre chose
// qu'un chiffre avant l'espace) ; la charge est ignoree, sans reponse.
bool lireRid(char *charge, uint32_t *rid, char **commande);

// Texte canonique du rid (decimal, sans zero de tete), 0 final compris dans
// out ; rend le nombre de chiffres.
size_t texteRid(uint32_t rid, char out[kRidMax + 1]);

// Commande permise a distance (espaces de tete sautes, comme l'aiguillage) :
// "bonjour", "etat", "voisins", "routeurs" exactement, ou "diag " suivi des
// arguments.
bool permise(const char *commande);

// Reponses gardees d'une session reseau : les kReponses dernieres (par rid),
// toutes leurs lignes (JSON sans RS ni LF, sans le rid), dans kOctets.
// Une reponse qui ne tient pas dans kOctets n'est pas gardee du tout (jamais
// une partie) : un rid repete la relance alors (lectures seulement).
class Gardees {
 public:
  static constexpr size_t kReponses = 8;
  static constexpr size_t kOctets = 4096;

  void vider();
  // Reponse de rid : les lignes qui suivent (ajouter) sont les siennes. Une
  // reponse deja gardee sous ce rid est oubliee.
  void commencer(uint32_t rid);
  // Ligne de la reponse commencee, gardee a la suite des precedentes ; sans
  // reponse commencee (ou apres terminer), ignoree.
  void ajouter(const uint8_t *ligne, size_t n);
  void terminer();
  // Lignes gardees sous rid, dans l'ordre, passees a f. false : rien de garde.
  typedef void (*Rendu)(void *contexte, const uint8_t *ligne, size_t n);
  bool rendre(uint32_t rid, Rendu f, void *contexte) const;
  // Pour les tests : reponses et octets gardes.
  size_t reponses() const;
  size_t octets() const { return n_; }

 private:
  // Enregistrement : rid (4 octets), longueur (2), ligne. Les lignes d'une
  // reponse se suivent ; les reponses, dans l'ordre de leur premiere ligne.
  static constexpr size_t kEntete = 6;
  uint32_t ridA(size_t i) const;
  size_t longueurA(size_t i) const;
  void retirer(size_t debut, size_t fin);
  void retirerPremiere();
  void retirerRid(uint32_t rid);
  bool gardee(uint32_t rid) const;

  uint8_t o_[kOctets] = {};
  size_t n_ = 0;
  uint32_t rid_ = 0;
  bool ouverte_ = false;     // une reponse est commencee
  bool abandonnee_ = false;  // trop grande : rien n'en est garde
};

// Au plus kLines lignes acceptees par kWindowMs glissantes : copie de la
// classe Cadence du pont Halo (benq src/json_out.h et json_out.cpp, section
// 6.5 de son protocole), jugee ici par session reseau.
class Cadence {
 public:
  static constexpr uint8_t kLines = 20;
  static constexpr uint32_t kWindowMs = 1000;
  bool allow(uint32_t now);  // true : ligne acceptee et comptee

 private:
  uint32_t at_[kLines] = {};
  uint8_t idx_ = 0, n_ = 0;
};

}  // namespace distant
