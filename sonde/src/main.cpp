// ===========================================================================
//  Sonde de maillage Thread, firmware 1.0.0 (spec de la sonde, sections 2 et 3)
//
//  Noeud Matter sur Thread, en MED : il recoit en permanence mais ne relaie
//  rien, et ne devient jamais le parent de personne. Maison lui donne les
//  identifiants du reseau a l'appairage par Bluetooth.
//
//  La pile OpenThread precompilee d'Arduino n'a pas de client de diagnostic :
//  la sonde fabrique elle-meme la requete DIAG_GET (CoAP POST d/dg, TLV
//  Type List) et l'envoie au port TMF 61631 du noeud vise. La reponse revient
//  sur le port CoAP de la sonde ; ses TLV partent en hexa, sans decodage :
//  c'est l'app qui decode. Jusqu'a 8 requetes en vol, reperees par leur id.
//
//  USB : une commande par ligne ; chaque reponse est une ligne machine,
//  RS (0x1E) + JSON compact en ASCII + LF, 4096 octets au plus.
//    bonjour                          produit, version, appairage (code tant
//                                     que la sonde n'est pas dans Maison)
//    etat                             role, RLOC16, ExtMac, parent, partition...
//    voisins                          table des voisins (le parent, pour un MED)
//    diag <cible> <t,t,...> <id> [ms] DIAG_GET vers <cible> : RLOC16 en 4 hexa
//                                     (adresse RLOC formee sur le prefixe du
//                                     reseau maille) ou adresse IPv6 ; delai de
//                                     3 a 60 s, 45 s par defaut
//    oubli                            desappaire la sonde et redemarre
//
//  Dans Maison : un interrupteur « Sonde maillage », allume par defaut.
//  Eteint, la sonde refuse les requetes (erreur « suspendue »).
// ===========================================================================

#include <Arduino.h>
#include <Matter.h>
#include <app/server/Server.h>
#include <esp_mac.h>
#include <esp_openthread.h>
#include <esp_openthread_lock.h>
#include <openthread/coap.h>
#include <openthread/ip6.h>
#include <openthread/link.h>
#include <openthread/message.h>
#include <openthread/thread.h>
#include <stdarg.h>

static const char *const kVersion = "1.0.0";

// ---------------------------------------------------------------------------
//  MED des l'init de Thread (repris du pont Halo, benq matter_bridge.cpp) :
//  esp_matter::start demande « routeur » ; l'enveloppe le remplace par MED.
//  Lien : -Wl,--wrap=<symbole> dans platformio.ini.
// ---------------------------------------------------------------------------

using ThreadDeviceType = chip::DeviceLayer::ConnectivityManager::ThreadDeviceType;

extern "C" CHIP_ERROR
__real__ZN4chip11DeviceLayer8Internal40GenericThreadStackManagerImpl_OpenThreadINS0_22ThreadStackManagerImplEE20_SetThreadDeviceTypeENS0_19ConnectivityManager16ThreadDeviceTypeE(
    void *self, ThreadDeviceType type);

extern "C" CHIP_ERROR
__wrap__ZN4chip11DeviceLayer8Internal40GenericThreadStackManagerImpl_OpenThreadINS0_22ThreadStackManagerImplEE20_SetThreadDeviceTypeENS0_19ConnectivityManager16ThreadDeviceTypeE(
    void *self, ThreadDeviceType type) {
  if (type == chip::DeviceLayer::ConnectivityManager::kThreadDeviceType_Router)
    type = chip::DeviceLayer::ConnectivityManager::kThreadDeviceType_MinimalEndDevice;
  return __real__ZN4chip11DeviceLayer8Internal40GenericThreadStackManagerImpl_OpenThreadINS0_22ThreadStackManagerImplEE20_SetThreadDeviceTypeENS0_19ConnectivityManager16ThreadDeviceTypeE(
      self, type);
}

// ---------------------------------------------------------------------------
//  Etat partage
// ---------------------------------------------------------------------------

static MatterOnOffPlugin sInterrupteur;  // « Sonde maillage »
static volatile bool sSuspendue = false;
static bool sThreadPret = false;  // pile Thread creee par Matter.begin()
static char sMac[13] = "?";

// Verrou OpenThread, delai total borne. REGLE (benq) : sous ce verrou, aucun
// appel Matter/CHIP ; la tache CHIP prend le verrou OT en tenant le sien.
static bool verrouOt(uint32_t ms) { return sThreadPret && esp_openthread_lock_acquire(pdMS_TO_TICKS(ms / 2)); }
static void libereOt() { esp_openthread_lock_release(); }

// ---------------------------------------------------------------------------
//  Ligne machine : RS + JSON + LF, 4096 octets au plus
// ---------------------------------------------------------------------------

static char sLigne[4096];
static size_t sLong = 0;
static bool sTropLong = false;

static void ajoute(const char *fmt, ...) {
  if (sTropLong) return;
  va_list ap;
  va_start(ap, fmt);
  const size_t reste = sizeof(sLigne) - sLong - 2;  // place pour '}' et LF
  const int n = vsnprintf(sLigne + sLong, reste, fmt, ap);
  va_end(ap);
  if (n < 0 || (size_t)n >= reste) {
    sTropLong = true;
    return;
  }
  sLong += (size_t)n;
}

static void debut(const char *type) {
  sLong = 0;
  sTropLong = false;
  sLigne[sLong++] = 0x1E;
  ajoute("{\"v\":1,\"t\":\"%s\"", type);
}

static void fin() {
  if (sTropLong) {
    debut("erreur");
    ajoute(",\"erreur\":\"ligne trop longue\"");
  }
  sLigne[sLong++] = '}';
  sLigne[sLong++] = '\n';
  Serial.write((const uint8_t *)sLigne, sLong);
}

static void hexa(const char *cle, const uint8_t *o, size_t n) {
  ajoute(",\"%s\":\"", cle);
  for (size_t i = 0; i < n && !sTropLong; i++) ajoute("%02X", o[i]);
  ajoute("\"");
}

// ---------------------------------------------------------------------------
//  Matter
// ---------------------------------------------------------------------------

static bool surInterrupteur(bool allume) {
  sSuspendue = !allume;
  return true;
}

static void demarrerMatter() {
  uint8_t mac[8] = {};
  if (esp_read_mac(mac, ESP_MAC_BASE) == ESP_OK)
    snprintf(sMac, sizeof(sMac), "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  // Avant le premier begin() d'accessoire : c'est lui qui cree le noeud.
  if (!Matter.selectNetwork(MATTER_NETWORK_THREAD)) Serial.println("!! selectNetwork(THREAD) refuse");
  sInterrupteur.begin(true);
  sInterrupteur.onChangeOnOff(surInterrupteur);
  char serie[20];
  snprintf(serie, sizeof(serie), "SONDE-%s", sMac);
  Matter.setVendorName("Maillage Thread");
  Matter.setProductName("Sonde maillage");
  Matter.setDeviceName("Sonde maillage");
  Matter.setSerialNumber(serie);
  Matter.begin();
  sThreadPret = chip::DeviceLayer::ThreadStackMgrImpl().OTInstance() != nullptr;
  if (!sThreadPret) Serial.println("!! pile Thread absente");
}

// ---------------------------------------------------------------------------
//  Commandes simples
// ---------------------------------------------------------------------------

static void cmdBonjour() {
  const bool appairee = Matter.isDeviceCommissioned();
  debut("bonjour");
  ajoute(",\"produit\":\"sonde-maillage\",\"version\":\"%s\",\"mac\":\"%s\",\"appairee\":%s", kVersion, sMac,
         appairee ? "true" : "false");
  if (appairee) {
    ajoute(",\"code\":null,\"qr\":null");
  } else {
    // L'URL du QR code porte la charge utile « MT:... » apres « data= ».
    String url = Matter.getOnboardingQRCodeUrl();
    const int i = url.indexOf("data=");
    String qr = i >= 0 ? url.substring(i + 5) : url;
    qr.replace("%3A", ":");
    ajoute(",\"code\":\"%s\",\"qr\":\"%s\"", Matter.getManualPairingCode().c_str(), qr.c_str());
  }
  fin();
}

static void cmdEtat() {
  debut("etat");
  if (!verrouOt(200)) {
    ajoute(",\"erreur\":\"occupee\"");
    fin();
    return;
  }
  otInstance *ot = esp_openthread_get_instance();
  const otDeviceRole role = otThreadGetDeviceRole(ot);
  ajoute(",\"role\":\"%s\",\"rloc16\":\"%04X\"", otThreadDeviceRoleToString(role), otThreadGetRloc16(ot));
  const otExtAddress *ext = otLinkGetExtendedAddress(ot);
  if (ext) hexa("ext", ext->m8, sizeof(ext->m8));
  const otLinkModeConfig mode = otThreadGetLinkMode(ot);
  ajoute(",\"mode\":\"%s%s%s\"", mode.mRxOnWhenIdle ? "r" : "", mode.mDeviceType ? "d" : "", mode.mNetworkData ? "n" : "");
  otRouterInfo parent;
  if (role == OT_DEVICE_ROLE_CHILD && otThreadGetParentInfo(ot, &parent) == OT_ERROR_NONE) {
    int8_t moyen = 0;
    otThreadGetParentAverageRssi(ot, &moyen);
    ajoute(",\"parent\":{\"rloc16\":\"%04X\"", parent.mRloc16);
    hexa("ext", parent.mExtAddress.m8, sizeof(parent.mExtAddress.m8));
    ajoute(",\"lqIn\":%u,\"lqOut\":%u,\"rssi\":%d}", parent.mLinkQualityIn, parent.mLinkQualityOut, moyen);
  } else {
    ajoute(",\"parent\":null");
  }
  const bool attachee = role == OT_DEVICE_ROLE_CHILD || role == OT_DEVICE_ROLE_ROUTER || role == OT_DEVICE_ROLE_LEADER;
  if (attachee) {
    ajoute(",\"partition\":\"%08lX\",\"chef\":%u", (unsigned long)otThreadGetPartitionId(ot),
           otThreadGetLeaderRouterId(ot));
  } else {
    ajoute(",\"partition\":null,\"chef\":null");
  }
  ajoute(",\"canal\":%u", otLinkGetChannel(ot));
  const otMeshLocalPrefix *ml = otThreadGetMeshLocalPrefix(ot);
  if (ml) hexa("prefixeMaille", ml->m8, sizeof(ml->m8));
  const otExtendedPanId *xp = otThreadGetExtendedPanId(ot);
  if (xp) hexa("xp", xp->m8, sizeof(xp->m8));
  libereOt();
  ajoute(",\"suspendue\":%s", sSuspendue ? "true" : "false");
  fin();
}

static void cmdVoisins() {
  debut("voisins");
  if (!verrouOt(200)) {
    ajoute(",\"erreur\":\"occupee\"");
    fin();
    return;
  }
  otInstance *ot = esp_openthread_get_instance();
  otNeighborInfoIterator it = OT_NEIGHBOR_INFO_ITERATOR_INIT;
  otNeighborInfo v;
  ajoute(",\"liste\":[");
  bool premier = true;
  while (otThreadGetNextNeighborInfo(ot, &it, &v) == OT_ERROR_NONE) {
    ajoute("%s{\"rloc16\":\"%04X\"", premier ? "" : ",", v.mRloc16);
    hexa("ext", v.mExtAddress.m8, sizeof(v.mExtAddress.m8));
    ajoute(",\"rssi\":%d,\"lqi\":%u,\"routeur\":%s}", v.mAverageRssi, v.mLinkQualityIn, v.mIsChild ? "false" : "true");
    premier = false;
  }
  ajoute("]");
  libereOt();
  fin();
}

// ---------------------------------------------------------------------------
//  DIAG_GET par CoAP, 8 en vol
// ---------------------------------------------------------------------------

static constexpr uint16_t kPortTmf = 61631;
static constexpr uint8_t kTlvTypeList = 18;
static constexpr size_t kTlvMax = 32;
static constexpr size_t kEnVol = 8;
static constexpr uint32_t kDelaiDefaut = 45000, kDelaiMin = 3000, kDelaiMax = 60000;

static bool sCoapDemarre = false;

// Un emplacement par requete en vol. `enVol` et `finie` passent de la tache
// OpenThread (rappel CoAP) a celle de loop() ; le reste est ecrit avant.
struct Requete {
  volatile bool enVol;
  volatile bool finie;
  uint32_t id;
  char cible[48];
  uint32_t debutMs, finMs;
  otError erreur;
  uint8_t code;  // code CoAP de la reponse
  uint8_t charge[1024];
  uint16_t longueur;
  bool tronquee;
};
static Requete sRequetes[kEnVol];

static void surReponse(void *contexte, otMessage *msg, const otMessageInfo *, otError erreur) {
  Requete &r = sRequetes[(uintptr_t)contexte];
  r.finMs = millis();
  r.erreur = erreur;
  r.longueur = 0;
  r.tronquee = false;
  if (erreur == OT_ERROR_NONE && msg) {
    r.code = (uint8_t)otCoapMessageGetCode(msg);
    const uint16_t debutCharge = otMessageGetOffset(msg);
    const uint16_t total = otMessageGetLength(msg) - debutCharge;
    const uint16_t n = total > sizeof(r.charge) ? sizeof(r.charge) : total;
    r.longueur = otMessageRead(msg, debutCharge, r.charge, n);
    r.tronquee = n < total;
  }
  r.finie = true;
}

// Reprises CoAP reglees pour que l'echec tombe au bout du delai demande :
// attente totale = accuse x (2^(reprises+1) - 1), facteur aleatoire de 1.
static otCoapTxParameters parametres(uint32_t delaiMs) {
  const uint8_t reprises = delaiMs < 10000 ? 1 : 3;
  const uint32_t facteur = (1u << (reprises + 1)) - 1;
  uint32_t accuse = delaiMs / facteur;
  if (accuse < 1000) accuse = 1000;  // plancher d'OpenThread
  otCoapTxParameters p = {accuse, 1, 1, reprises};
  return p;
}

static void repondreDiagErreur(uint32_t id, const char *cible, const char *erreur) {
  debut("diag");
  ajoute(",\"id\":%lu,\"cible\":\"%s\",\"ok\":false,\"erreur\":\"%s\"", (unsigned long)id, cible, erreur);
  fin();
}

// diag <cible> <t,t,...> <id> [<delai ms>]
static void cmdDiag(char *args) {
  char *cible = strtok(args, " ");
  char *liste = strtok(nullptr, " ");
  char *idTexte = strtok(nullptr, " ");
  char *delaiTexte = strtok(nullptr, " ");
  const uint32_t id = idTexte ? strtoul(idTexte, nullptr, 10) : 0;
  if (!cible || !liste || !idTexte || strlen(cible) >= sizeof(sRequetes[0].cible)) {
    repondreDiagErreur(id, "", "syntaxe");
    return;
  }
  if (sSuspendue) return repondreDiagErreur(id, cible, "suspendue");
  uint32_t delai = delaiTexte ? strtoul(delaiTexte, nullptr, 10) : kDelaiDefaut;
  if (delai < kDelaiMin) delai = kDelaiMin;
  if (delai > kDelaiMax) delai = kDelaiMax;

  size_t libre = kEnVol;
  for (size_t i = 0; i < kEnVol; i++)
    if (!sRequetes[i].enVol) {
      libre = i;
      break;
    }
  if (libre == kEnVol) return repondreDiagErreur(id, cible, "occupee");

  uint8_t types[kTlvMax];
  size_t nTypes = 0;
  for (char *t = strtok(liste, ","); t && nTypes < kTlvMax; t = strtok(nullptr, ",")) {
    const long v = strtol(t, nullptr, 10);
    if (v < 0 || v > 255) return repondreDiagErreur(id, cible, "syntaxe");
    types[nTypes++] = (uint8_t)v;
  }
  if (nTypes == 0) return repondreDiagErreur(id, cible, "syntaxe");

  if (!verrouOt(500)) return repondreDiagErreur(id, cible, "occupee");
  otInstance *ot = esp_openthread_get_instance();
  otIp6Address adresse;
  bool adresseOk = false;
  if (strlen(cible) == 4 && strspn(cible, "0123456789abcdefABCDEF") == 4) {
    // Adresse RLOC : prefixe du reseau maille + 0000:00ff:fe00:<rloc16>.
    const otMeshLocalPrefix *ml = otThreadGetMeshLocalPrefix(ot);
    if (ml) {
      const uint16_t rloc16 = (uint16_t)strtoul(cible, nullptr, 16);
      memset(&adresse, 0, sizeof(adresse));
      memcpy(adresse.mFields.m8, ml->m8, 8);
      adresse.mFields.m8[11] = 0xFF;
      adresse.mFields.m8[12] = 0xFE;
      adresse.mFields.m8[14] = (uint8_t)(rloc16 >> 8);
      adresse.mFields.m8[15] = (uint8_t)rloc16;
      adresseOk = true;
    }
  } else {
    adresseOk = otIp6AddressFromString(cible, &adresse) == OT_ERROR_NONE;
  }
  if (!adresseOk) {
    libereOt();
    return repondreDiagErreur(id, cible, "cible");
  }
  if (!sCoapDemarre) sCoapDemarre = otCoapStart(ot, OT_DEFAULT_COAP_PORT) == OT_ERROR_NONE;
  otMessage *msg = sCoapDemarre ? otCoapNewMessage(ot, nullptr) : nullptr;
  otError e = msg ? OT_ERROR_NONE : OT_ERROR_NO_BUFS;
  if (msg) {
    otCoapMessageInit(msg, OT_COAP_TYPE_CONFIRMABLE, OT_COAP_CODE_POST);
    otCoapMessageGenerateToken(msg, OT_COAP_DEFAULT_TOKEN_LENGTH);
    e = otCoapMessageAppendUriPathOptions(msg, "d/dg");
    if (e == OT_ERROR_NONE) e = otCoapMessageSetPayloadMarker(msg);
    const uint8_t entete[2] = {kTlvTypeList, (uint8_t)nTypes};
    if (e == OT_ERROR_NONE) e = otMessageAppend(msg, entete, sizeof(entete));
    if (e == OT_ERROR_NONE) e = otMessageAppend(msg, types, (uint16_t)nTypes);
  }
  if (e == OT_ERROR_NONE) {
    otMessageInfo info;
    memset(&info, 0, sizeof(info));
    info.mPeerAddr = adresse;
    info.mPeerPort = kPortTmf;
    const otCoapTxParameters p = parametres(delai);
    Requete &r = sRequetes[libre];
    r.id = id;
    snprintf(r.cible, sizeof(r.cible), "%s", cible);
    r.debutMs = millis();
    r.finie = false;
    r.enVol = true;
    e = otCoapSendRequestWithParameters(ot, msg, &info, surReponse, (void *)(uintptr_t)libre, &p);
    if (e != OT_ERROR_NONE) r.enVol = false;
  }
  if (e != OT_ERROR_NONE && msg) otMessageFree(msg);
  libereOt();
  if (e != OT_ERROR_NONE) {
    char texte[24];
    snprintf(texte, sizeof(texte), "envoi %s", otThreadErrorToString(e));
    repondreDiagErreur(id, cible, texte);
  }
}

static void imprimerDiag(const Requete &r) {
  debut("diag");
  ajoute(",\"id\":%lu,\"cible\":\"%s\",\"ms\":%lu", (unsigned long)r.id, r.cible, (unsigned long)(r.finMs - r.debutMs));
  if (r.erreur == OT_ERROR_NONE) {
    ajoute(",\"ok\":true,\"code\":\"%u.%02u\"", r.code >> 5, r.code & 0x1F);
    hexa("tlv", r.charge, r.longueur);
    if (r.tronquee) ajoute(",\"tronquee\":true");
  } else {
    ajoute(",\"ok\":false,\"erreur\":\"%s\"",
           r.erreur == OT_ERROR_RESPONSE_TIMEOUT ? "delai" : otThreadErrorToString(r.erreur));
  }
  fin();
}

// ---------------------------------------------------------------------------
//  Boucle
// ---------------------------------------------------------------------------

static char sCommande[200];
static size_t sCmdLong = 0;

static void executer(char *c) {
  while (*c == ' ') c++;
  if (!strcmp(c, "bonjour")) return cmdBonjour();
  if (!strcmp(c, "etat")) return cmdEtat();
  if (!strcmp(c, "voisins")) return cmdVoisins();
  if (!strncmp(c, "diag ", 5)) return cmdDiag(c + 5);
  if (!strcmp(c, "oubli")) {
    debut("oubli");
    fin();
    Serial.flush();
    Matter.decommission();  // efface l'appairage et redemarre
    return;
  }
  if (!*c) return;
  debut("erreur");
  ajoute(",\"erreur\":\"commande inconnue\"");
  fin();
}

void setup() {
  Serial.begin(115200);
  demarrerMatter();
  cmdBonjour();
}

void loop() {
  while (Serial.available()) {
    const int o = Serial.read();
    if (o == '\n' || o == '\r') {
      sCommande[sCmdLong] = 0;
      if (sCmdLong) executer(sCommande);
      sCmdLong = 0;
    } else if (o >= 0x20 && o < 0x7F && sCmdLong < sizeof(sCommande) - 1) {
      sCommande[sCmdLong++] = (char)o;
    }
  }
  for (Requete &r : sRequetes) {
    if (r.enVol && r.finie) {
      imprimerDiag(r);
      r.finie = false;
      r.enVol = false;
    }
  }
  delay(5);
}
