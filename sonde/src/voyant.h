#pragma once
// ===========================================================================
//  LED de la carte (WS2812 de la SuperMini, sur IO8 ; sonde 1.0.3)
//
//  La couleur a montrer a chaque instant, d'apres l'interrupteur « Sonde
//  maillage » de Maison :
//  - allume : deux eclairs verts rapides ;
//  - eteint : un eclair orange d'une demi-seconde ;
//  - tant que la sonde est suspendue : un bref eclair orange toutes les 5 s,
//    aussi apres un redemarrage (le premier des le demarrage) ;
//  - sinon, eteinte.
//  main.cpp la pilote dans loop(), jamais sous le verrou OpenThread ni depuis
//  le rappel Matter (qui ne fait que poser l'etat). Instants de millis() :
//  des ecarts non signes, et une sequence finie est oubliee au premier appel
//  qui la voit finie, si bien que le retour a zero de millis() ne ranime rien.
//
//  Pur et sans Arduino, tout dans cet en-tete : teste sur l'hote par
//  sonde/test/test_distant.cpp ; lancer : sh sonde/test/lancer.sh.
// ===========================================================================
#include <stdint.h>

class Voyant {
 public:
  enum Couleur : uint8_t { kNoire, kVerte, kOrange };
  static constexpr uint32_t kVertMs = 100;        // chaque eclair vert, et la pause entre eux
  static constexpr uint32_t kExtinctionMs = 500;  // eclair orange quand l'interrupteur s'eteint
  static constexpr uint32_t kBrefMs = 100;        // bref eclair orange de la suspension...
  static constexpr uint32_t kPeriodeMs = 5000;    // ... toutes les 5 s (choix de Djoko, 30/09)

  // Demarrage, avec l'etat relu de la NVS : aucun eclair de changement ;
  // suspendue, un bref eclair tout de suite.
  void demarrer(bool suspendue, uint32_t maintenant) {
    sequence_ = kAucune;
    suspendue_ = suspendue;
    prochain_ = maintenant;
  }

  // L'interrupteur vient de changer : eclairs verts ou eclair orange, puis,
  // suspendue, le premier bref eclair une periode plus tard.
  void changer(bool suspendue, uint32_t maintenant) {
    sequence_ = suspendue ? kOrangeLong : kDeuxVerts;
    debut_ = maintenant;
    suspendue_ = suspendue;
    prochain_ = maintenant + kPeriodeMs;
  }

  // Couleur a montrer maintenant ; a appeler a chaque tour de loop().
  Couleur couleur(uint32_t maintenant) {
    const uint32_t t = maintenant - debut_;
    if (sequence_ == kDeuxVerts) {
      // Vert, pause, vert, d'une duree kVertMs chacun.
      if (t < 3 * kVertMs) return t / kVertMs == 1 ? kNoire : kVerte;
      sequence_ = kAucune;
    } else if (sequence_ == kOrangeLong) {
      if (t < kExtinctionMs) return kOrange;
      sequence_ = kAucune;
    }
    if (!suspendue_) return kNoire;
    // Ecart depuis le prochain bref eclair : au-dela de 2^31 ms, il est encore
    // a venir (prochain_ n'est jamais a plus d'une periode en avance).
    const uint32_t e = maintenant - prochain_;
    if (e >= 0x80000000u) return kNoire;
    if (e % kPeriodeMs < kBrefMs) return kOrange;
    // Eclair fini (plusieurs si loop() a ete retenue) : le suivant, sur la
    // meme grille de 5 s.
    prochain_ += (e / kPeriodeMs + 1) * kPeriodeMs;
    return kNoire;
  }

 private:
  enum Sequence : uint8_t { kAucune, kDeuxVerts, kOrangeLong };
  Sequence sequence_ = kAucune;
  uint32_t debut_ = 0;  // debut de la sequence
  bool suspendue_ = false;
  uint32_t prochain_ = 0;  // debut du prochain bref eclair, ou de celui en cours
};
