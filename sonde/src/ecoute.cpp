// Ecoute des messages MLE sur la carte : voir ecoute.h. Les briques pures
// (decodage, cles, table) sont dans mle.h, testees sur l'hote.
#include "ecoute.h"

#include <freertos/FreeRTOS.h>
#include <freertos/queue.h>
#include <openthread/link.h>
#include <openthread/platform/radio.h>
#include <string.h>

#include <atomic>

namespace ecoute {
namespace {

constexpr uint8_t kFile = 16;

struct Trame {
  uint8_t n;
  int8_t rssi;
  uint8_t psdu[mle::kPsduMax];
};

QueueHandle_t sFile = nullptr;
Trame sTrameOt;    // tampon du rappel (tache OpenThread seulement)
Trame sTrameLoop;  // tampon de la tache loop
// Ecrits par le rappel (tache OpenThread), lus par la tache loop.
std::atomic<uint32_t> sTrames{0};
std::atomic<uint32_t> sFilePleine{0};
// Tache loop seulement.
uint32_t sMle = 0, sEchecs = 0;
mle::TableEntendus sEntendus;
mle::ClesMle sCles;
Acces sAcces = {nullptr, nullptr};

// Tache OpenThread, verrou OpenThread tenu : le tri et la copie, rien d'autre.
// Les messages MLE ne sont pas chiffres au niveau MAC : seules les trames de
// donnees sans securite MAC sont gardees.
void surTrame(const otRadioFrame *f, bool emise, void *) {
  if (emise || f == nullptr || f->mPsdu == nullptr) return;
  sTrames.fetch_add(1, std::memory_order_relaxed);
  const uint16_t n = f->mLength;
  if (n < 3 || n > mle::kPsduMax) return;
  if ((f->mPsdu[0] & 0x07) != 0x01 || (f->mPsdu[0] & 0x08)) return;
  sTrameOt.n = (uint8_t)n;
  sTrameOt.rssi = f->mInfo.mRxInfo.mRssi;
  memcpy(sTrameOt.psdu, f->mPsdu, n);
  if (sFile == nullptr || xQueueSend(sFile, &sTrameOt, 0) != pdTRUE)
    sFilePleine.fetch_add(1, std::memory_order_relaxed);
}

// Cle MLE d'une sequence : gardee, ou derivee quand la sequence de la pile a
// change depuis la derniere derivation (rotation de cle). Une sequence
// etrangere (ni la courante ni la suivante) ne fait jamais relire la cle
// reseau. La cle reseau ne passe que par la pile de cette fonction, effacee.
bool fournir(void *, uint32_t sequence, uint8_t cle[mle::kCle]) {
  if (sCles.trouver(sequence, cle)) return true;
  uint32_t courante = 0;
  if (sAcces.sequence == nullptr || !sAcces.sequence(&courante)) return false;
  if (sCles.preparees() && courante == sCles.courante()) return false;
  uint8_t reseau[mle::kCle];
  const bool lue = sAcces.cleReseau != nullptr && sAcces.cleReseau(reseau);
  const bool preparees = lue && sCles.preparer(courante, reseau);
  mle::effacer(reseau, sizeof(reseau));
  return preparees && sCles.trouver(sequence, cle);
}

}  // namespace

void demarrer(otInstance *ot, const Acces &acces) {
  sAcces = acces;
  if (sFile == nullptr) sFile = xQueueCreate(kFile, sizeof(Trame));
  otLinkSetPcapCallback(ot, surTrame, nullptr);
}

void tour(uint32_t maintenant) {
  for (uint8_t k = 0; k < kFile && sFile != nullptr && xQueueReceive(sFile, &sTrameLoop, 0) == pdTRUE; k++) {
    mle::Message m;
    switch (mle::decoder(sTrameLoop.psdu, sTrameLoop.n, fournir, nullptr, &m)) {
      case mle::Issue::Dechiffree:
        sMle++;
        sEntendus.noter(m, sTrameLoop.rssi, maintenant);
        break;
      case mle::Issue::Echec:
        sEchecs++;
        break;
      case mle::Issue::Ignoree:
        break;
    }
  }
  sEntendus.oublier(maintenant);
}

Compteurs compteurs() {
  return {sTrames.load(std::memory_order_relaxed), sMle, sEchecs, sFilePleine.load(std::memory_order_relaxed)};
}

const mle::TableEntendus &entendus() { return sEntendus; }

}  // namespace ecoute
