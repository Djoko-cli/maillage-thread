// ===========================================================================
//  Sonde de maillage Thread, firmware 1.0.3 (spec de la sonde, sections 2 et
//  3 ; contrat de la 1.0.2 : FED, routeurs, acces reseau comme le pont Halo ;
//  1.0.3 : LED, retour allume apres oubli, refus de la cadence comptes)
//
//  Noeud Matter sur Thread, en FED non eligible routeur (Full End Device) :
//  il recoit en permanence mais ne relaie rien, ne devient jamais routeur ni
//  chef, et ne devient jamais le parent de personne. En FED, OpenThread tient
//  la table des routeurs de la partition et apprend l'ExtMac de ceux qu'il
//  entend (commande routeurs). Maison lui donne les identifiants du reseau a
//  l'appairage par Bluetooth.
//
//  La pile OpenThread precompilee d'Arduino n'a pas de client de diagnostic :
//  la sonde fabrique elle-meme la requete DIAG_GET (CoAP POST d/dg, TLV
//  Type List) et l'envoie au port TMF 61631 du noeud vise. La reponse revient
//  sur le port CoAP de la sonde ; ses TLV partent en hexa, sans decodage :
//  c'est l'app qui decode. Jusqu'a 8 requetes en vol, reperees par leur id.
//
//  USB : une commande par ligne ; chaque reponse est une ligne machine,
//  RS (0x1E) + JSON compact en ASCII + LF, 4096 octets au plus.
//    bonjour                          produit, version, nom, MAC, appairage,
//                                     code d'appairage et charge du QR code
//                                     (toujours, meme dans Maison), nom
//                                     d'hote SRP (hote, null tant qu'inconnu)
//    nom <texte>                      change le nom et le garde : 1 a 32
//                                     caracteres (lettres ASCII, chiffres,
//                                     - _ .) ; repond par un bonjour a jour,
//                                     sinon erreur « syntaxe » (nom refuse)
//                                     ou « ecriture » (NVS qui refuse)
//    etat                             role, RLOC16, ExtMac, mode, eligible,
//                                     parent, partition...
//    voisins                          routeurs voisins a lien etabli (le
//                                     parent n'y est pas : voir etat)
//    routeurs                         table des routeurs d'OpenThread
//                                     (otThreadGetRouterInfo), entrees
//                                     allouees ; plusieurs lignes si besoin
//                                     ("suite":true sur toutes sauf la
//                                     derniere)
//    diag <cible> <t,t,...> <id> [ms] DIAG_GET vers <cible> : RLOC16 en 4 hexa
//                                     (adresse RLOC formee sur le prefixe du
//                                     reseau maille) ou adresse IPv6 (hexa,
//                                     ':' et '.' seulement) ; id et delai en
//                                     decimal, sinon « syntaxe » ; delai de
//                                     3 a 60 s, 45 s par defaut
//    cle                              empreinte de la cle d'acces reseau
//                                     (null sans cle), effacement_en_echec,
//                                     hote, compteurs udp (lignes_perdues et
//                                     refus_cadence compris), tas libre et
//                                     minimum
//    cle efface                       efface la cle : plus d'acces reseau
//    cle nouvelle <64 HEXA> <id>      nouvelle cle (alea de l'app), rendue
//                                     UNE fois, dans la reponse ; sans id :
//                                     erreur « syntaxe », jamais de cle
//    oubli                            efface la cle (cle_effacee dans la
//                                     reponse), desappaire la sonde et
//                                     redemarre ; elle revient allumee
//
//  Reseau (reseau.h) : UDP sur IPv6, port 5480, enveloppe H1 du pont Halo,
//  cle creee par l'USB. Charge d'un message : "<rid> <commande>" ; reponse :
//  "<rid> <ligne JSON>" (la ligne de l'USB sans RS ni LF), 1100 octets au
//  plus. Permis : bonjour (sans code ni QR code), etat, voisins, routeurs,
//  diag ; le reste : erreur « refuse ». Un rid repete ne relance rien (les 8
//  dernieres reponses, dans la limite de 4096 octets par session) ; 20
//  commandes par seconde et par session au plus (au-dela, rien, et le refus
//  est compte : udp.refus_cadence de cle). Sans cle : silence total.
//
//  Dans Maison : un interrupteur « Sonde maillage », allume par defaut.
//  Eteint, la sonde refuse les requetes (erreur « suspendue »). Son etat est
//  garde d'un demarrage a l'autre, comme le nom de la sonde (« SONDE-01 » par
//  defaut) : il suit la carte d'un Mac a l'autre. Apres un oubli, la sonde
//  revient allumee, comme a sa premiere mise en service.
//
//  LED de la carte (WS2812 sur IO8), a faible intensite : deux eclairs verts
//  rapides quand l'interrupteur s'allume, un eclair orange d'une demi-seconde
//  quand il s'eteint, puis un bref eclair orange toutes les 10 s tant que la
//  sonde est suspendue, aussi apres un redemarrage.
// ===========================================================================

#include <Arduino.h>
#include <Matter.h>
#include <Preferences.h>
#include <app/server/Server.h>
#include <esp_mac.h>
#include <esp_openthread.h>
#include <esp_openthread_lock.h>
#include <esp_system.h>
#include <openthread/coap.h>
#include <openthread/ip6.h>
#include <openthread/link.h>
#include <openthread/message.h>
#include <openthread/thread.h>
#include <openthread/thread_ftd.h>
#include <stdarg.h>

#include <atomic>

#include "distant.h"
#include "h1_proto.h"
#include "reseau.h"

static const char *const kVersion = "1.0.3";

// ---------------------------------------------------------------------------
//  FED des la creation de la pile Thread, jamais eligible routeur (repris de
//  l'essai FED du 29/09 (spec, section 8))
//
//  esp_matter::start : _InitThreadStack (esp_openthread_init cree l'instance
//  et relit sa NVS, puis CHIP relance Thread si le reseau est connu), puis
//  _SetThreadDeviceType(Router), puis _StartThreadTask. Avant cette tache,
//  OpenThread ne traite ni message MLE ni minuteur.
//
//  Trois enveloppes, -Wl,--wrap=<symbole> dans platformio.ini (une enveloppe
//  sans son drapeau, ou l'inverse, ne lie pas) :
//  1. esp_openthread_init : des la creation de l'instance, avant que Thread
//     soit relance, la sonde passe en FED (imposerFed).
//  2. _SetThreadDeviceType : toute demande devient FullEndDevice. CHIP appelle
//     alors otThreadSetRouterEligible(false) avant otThreadSetLinkMode(r+d)
//     (objdump). Puis le FED est impose de nouveau, avec n.
//  3. otThreadSetRouterEligible : toujours false, quel que soit l'appelant
//     (CHIP, CLI OpenThread, ce fichier). Dans les bibliotheques, seuls
//     _SetThreadDeviceType et la CLI y font reference, et OpenThread ne rend
//     jamais l'eligibilite de lui-meme (nm, objdump).
//  Non eligible, OpenThread refuse de devenir routeur ou chef, ne repond pas
//  aux Parent Request, refuse les Child ID Request et n'emet ni balise ni
//  annonce MLE.
// ---------------------------------------------------------------------------

extern "C" otError __real_otThreadSetRouterEligible(otInstance *instance, bool eligible);

extern "C" otError __wrap_otThreadSetRouterEligible(otInstance *instance, bool eligible) {
  (void)eligible;
  return __real_otThreadSetRouterEligible(instance, false);
}

// Non eligible d'abord (jamais FTD et eligible a la fois), puis mode rdn :
// reception permanente, appareil complet, donnees reseau completes. Verrou
// OT sans limite, comme CHIP a ces deux endroits : il est recursif, et la
// tache OpenThread n'existe pas encore. Aucun appel CHIP dessous.
static void imposerFed(otInstance *ot) {
  esp_openthread_lock_acquire(portMAX_DELAY);
  otThreadSetRouterEligible(ot, false);
  otLinkModeConfig mode = otThreadGetLinkMode(ot);
  if (!mode.mRxOnWhenIdle || !mode.mDeviceType || !mode.mNetworkData) {
    mode.mRxOnWhenIdle = true;
    mode.mDeviceType = true;
    mode.mNetworkData = true;
    otThreadSetLinkMode(ot, mode);
  }
  esp_openthread_lock_release();
}

extern "C" esp_err_t __real_esp_openthread_init(const esp_openthread_platform_config_t *config);

// Echec : ni instance ni verrou surs, on n'y touche pas.
extern "C" esp_err_t __wrap_esp_openthread_init(const esp_openthread_platform_config_t *config) {
  const esp_err_t e = __real_esp_openthread_init(config);
  if (e == ESP_OK) imposerFed(esp_openthread_get_instance());
  return e;
}

using ThreadDeviceType = chip::DeviceLayer::ConnectivityManager::ThreadDeviceType;

extern "C" CHIP_ERROR
__real__ZN4chip11DeviceLayer8Internal40GenericThreadStackManagerImpl_OpenThreadINS0_22ThreadStackManagerImplEE20_SetThreadDeviceTypeENS0_19ConnectivityManager16ThreadDeviceTypeE(
    void *self, ThreadDeviceType type);

extern "C" CHIP_ERROR
__wrap__ZN4chip11DeviceLayer8Internal40GenericThreadStackManagerImpl_OpenThreadINS0_22ThreadStackManagerImplEE20_SetThreadDeviceTypeENS0_19ConnectivityManager16ThreadDeviceTypeE(
    void *self, ThreadDeviceType type) {
  (void)type;
  const CHIP_ERROR e =
      __real__ZN4chip11DeviceLayer8Internal40GenericThreadStackManagerImpl_OpenThreadINS0_22ThreadStackManagerImplEE20_SetThreadDeviceTypeENS0_19ConnectivityManager16ThreadDeviceTypeE(
          self, chip::DeviceLayer::ConnectivityManager::kThreadDeviceType_FullEndDevice);
  // Echec (pas d'instance OpenThread) : rien a imposer.
  if (e == CHIP_NO_ERROR) imposerFed(esp_openthread_get_instance());
  return e;
}

// ---------------------------------------------------------------------------
//  Etat partage
// ---------------------------------------------------------------------------

static MatterOnOffPlugin sInterrupteur;  // « Sonde maillage »
// Etat de l'interrupteur, garde dans la NVS comme dans l'exemple
// MatterOnOffPlugin d'Arduino-ESP32 : relu au demarrage, allume par defaut.
static Preferences sPreferences;
static const char *const kCleInterrupteur = "interrupteur";
// Pose par demarrerMatter(), puis par le rappel Matter (tache CHIP) ; lu par
// loop(), qui en tire aussi la LED.
static std::atomic<bool> sSuspendue{false};
static bool sThreadPret = false;  // pile Thread creee par Matter.begin()
static char sMac[13] = "?";
// Nom de la sonde, garde dans la NVS a cote de l'interrupteur (commande `nom`).
static const char *const kCleNom = "nom";
static const char *const kNomDefaut = "SONDE-01";
static constexpr size_t kNomMax = 32;
static char sNom[kNomMax + 1] = "SONDE-01";

// 1 a 32 caracteres parmi les lettres ASCII, les chiffres, « - », « _ » et « . » :
// rien a echapper dans le JSON.
static bool nomValide(const char *s) {
  const size_t n = strlen(s);
  if (n == 0 || n > kNomMax) return false;
  for (size_t i = 0; i < n; i++) {
    const char c = s[i];
    const bool permis = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' ||
                        c == '_' || c == '.';
    if (!permis) return false;
  }
  return true;
}

// Verrou OpenThread, delai total borne. REGLE (benq) : sous ce verrou, aucun
// appel Matter/CHIP ; la tache CHIP prend le verrou OT en tenant le sien.
static bool verrouOt(uint32_t ms) { return sThreadPret && esp_openthread_lock_acquire(pdMS_TO_TICKS(ms / 2)); }
static void libereOt() { esp_openthread_lock_release(); }

// Pour reseau.cpp : verrou pris SANS attente (emission, socket, nom d'hote).
bool reseauVerrouEssai() { return verrouOt(0); }
void reseauVerrouLibere() { libereOt(); }

// ---------------------------------------------------------------------------
//  Ligne machine : RS + JSON + LF, 4096 octets au plus sur l'USB
// ---------------------------------------------------------------------------

// Destination des lignes : l'USB, ou une session reseau (place, generation de
// la place, rid de la requete). Posee le temps d'une commande recue par le
// reseau, et pour la reponse d'un diag qui en venait.
struct Sortie {
  bool reseau = false;
  uint8_t place = 0;
  uint32_t generation = 0;
  uint32_t rid = 0;
};
static Sortie sSortie;

// Reponses gardees de chaque session reseau (un rid repete ne relance rien),
// et cadence de chaque session (20 commandes par seconde au plus).
static distant::Gardees sGardees[kPlacesReseau];
static distant::Cadence sCadences[kPlacesReseau];
// Lignes pour le reseau que la file d'emission n'a pas prises (pleine) :
// perdues en route, mais gardees pour un rid repete (Halo : json_perdus).
static uint32_t sLignesPerdues = 0;
// Commandes du reseau que la cadence a refusees (plus de 20 dans la seconde),
// toutes sessions confondues, depuis le demarrage : pour mesurer la cadence
// de l'app (18 par seconde).
static uint32_t sRefusCadence = 0;

static char sLigne[4096];
static size_t sLong = 0;
static bool sTropLong = false;
static size_t sLimite = sizeof(sLigne);

// Taille de sLigne permise pour la destination en cours (RS, LF et le 0
// final de vsnprintf compris) : 4096 sur l'USB ; sur le reseau, la charge
// "<rid> <ligne JSON>" tient en kChargeMax octets (JSON <= sLimite - 3).
static size_t limiteSortie() {
  if (!sSortie.reseau) return sizeof(sLigne);
  char rid[distant::kRidMax + 1];
  return kChargeMax - (distant::texteRid(sSortie.rid, rid) + 1) + 3;
}

static void ajoute(const char *fmt, ...) {
  if (sTropLong) return;
  va_list ap;
  va_start(ap, fmt);
  const size_t reste = sLimite - sLong - 2;  // place pour '}' et LF
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
  sLimite = limiteSortie();
  sLigne[sLong++] = 0x1E;
  ajoute("{\"v\":1,\"t\":\"%s\"", type);
}

// Ligne pour une session reseau : gardee (pour un rid repete), puis envoyee
// "<rid> <ligne JSON>", sans RS ni LF. Session partie entre-temps : rien.
// File d'emission pleine : perdue, mais gardee, l'app renverra le rid.
static void sortieReseau(const uint8_t *json, size_t n) {
  if (!reseauSessionActive(sSortie.place, sSortie.generation)) return;
  sGardees[sSortie.place].ajouter(json, n);
  char prefixe[distant::kRidMax + 2];
  size_t np = distant::texteRid(sSortie.rid, prefixe);
  prefixe[np++] = ' ';
  if (!reseauEnvoyer(sSortie.place, prefixe, np, json, n)) sLignesPerdues++;
}

static void fin() {
  if (sTropLong) {
    debut("erreur");
    ajoute(",\"erreur\":\"ligne trop longue\"");
  }
  sLigne[sLong++] = '}';
  sLigne[sLong++] = '\n';
  if (sSortie.reseau) sortieReseau((const uint8_t *)sLigne + 1, sLong - 2);
  else Serial.write((const uint8_t *)sLigne, sLong);
}

static void hexa(const char *cle, const uint8_t *o, size_t n) {
  ajoute(",\"%s\":\"", cle);
  for (size_t i = 0; i < n && !sTropLong; i++) ajoute("%02X", o[i]);
  ajoute("\"");
}

static void repondreErreur(const char *erreur) {
  debut("erreur");
  ajoute(",\"erreur\":\"%s\"", erreur);
  fin();
}

// Nom d'hote SRP, sans .local ; null tant qu'il n'est pas connu.
static void ajouteHote() {
  char hote[64];
  if (reseauHote(hote)) ajoute(",\"hote\":\"%s\"", hote);
  else ajoute(",\"hote\":null");
}

// ---------------------------------------------------------------------------
//  Matter
// ---------------------------------------------------------------------------

// Maison change l'interrupteur, updateAccessory() applique l'etat relu au
// demarrage, ou oubli le rallume (setOnOff) : l'etat est garde pour le
// prochain demarrage. Jamais la LED ici : loop() voit sSuspendue changer et
// la pilote (voyantTour).
static bool surInterrupteur(bool allume) {
  sSuspendue = !allume;
  sPreferences.putBool(kCleInterrupteur, allume);
  return true;
}

static void demarrerMatter() {
  uint8_t mac[8] = {};
  if (esp_read_mac(mac, ESP_MAC_BASE) == ESP_OK)
    snprintf(sMac, sizeof(sMac), "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  // Avant le premier begin() d'accessoire : c'est lui qui cree le noeud.
  if (!Matter.selectNetwork(MATTER_NETWORK_THREAD)) Serial.println("!! selectNetwork(THREAD) refuse");
  // Etat garde de l'interrupteur (allume au premier demarrage) : la sonde reste
  // suspendue apres un redemarrage si « Sonde maillage » est eteint dans Maison.
  sPreferences.begin("sonde", false);
  // Nom garde (« SONDE-01 » au premier demarrage, ou s'il etait illisible).
  const String nom = sPreferences.getString(kCleNom, kNomDefaut);
  if (nomValide(nom.c_str())) snprintf(sNom, sizeof(sNom), "%s", nom.c_str());
  const bool allume = sPreferences.getBool(kCleInterrupteur, true);
  sSuspendue = !allume;
  sInterrupteur.begin(allume);
  // onChange, et non onChangeOnOff : updateAccessory() n'appelle que ce rappel-la.
  sInterrupteur.onChange(surInterrupteur);
  char serie[20];
  snprintf(serie, sizeof(serie), "SONDE-%s", sMac);
  Matter.setVendorName("Maillage Thread");
  Matter.setProductName("Sonde maillage");
  Matter.setDeviceName("Sonde maillage");
  Matter.setSerialNumber(serie);
  Matter.begin();
  sThreadPret = chip::DeviceLayer::ThreadStackMgrImpl().OTInstance() != nullptr;
  if (!sThreadPret) Serial.println("!! pile Thread absente");
  // Comme l'exemple officiel : l'etat relu passe par le rappel une fois Matter demarre.
  sInterrupteur.updateAccessory();
}

// ---------------------------------------------------------------------------
//  Commandes simples
// ---------------------------------------------------------------------------

// Chaine JSON, ou null si elle est vide (code que Matter n'a pas pu former).
static void chaineOuNull(const char *cle, const String &valeur) {
  if (valeur.length()) {
    ajoute(",\"%s\":\"%s\"", cle, valeur.c_str());
  } else {
    ajoute(",\"%s\":null", cle);
  }
}

// Code d'appairage et QR code toujours sur l'USB, appairee ou non : Maillage
// Thread les montre dans ses Reglages (Matter les forme une fois, au
// demarrage). A distance, jamais : null, comme le pont Halo (le trafic H1
// n'est pas chiffre ; qui les lirait pourrait ajouter la sonde a son propre
// controleur des que l'appairage est ouvert).
static void cmdBonjour() {
  const bool appairee = Matter.isDeviceCommissioned();
  String code, qr;
  if (!sSortie.reseau) {
    // L'URL du QR code porte la charge utile « MT:... » apres « data= ».
    const String url = Matter.getOnboardingQRCodeUrl();
    const int i = url.indexOf("data=");
    qr = i >= 0 ? url.substring(i + 5) : url;
    qr.replace("%3A", ":");
    code = Matter.getManualPairingCode();
  }
  debut("bonjour");
  ajoute(",\"produit\":\"sonde-maillage\",\"version\":\"%s\",\"nom\":\"%s\",\"mac\":\"%s\",\"appairee\":%s", kVersion,
         sNom, sMac, appairee ? "true" : "false");
  chaineOuNull("code", code);
  chaineOuNull("qr", qr);
  ajouteHote();
  fin();
}

// nom <texte> : change le nom et le garde ; repond par un bonjour a jour. Nom
// refuse : erreur « syntaxe » ; NVS qui refuse l'ecriture : « ecriture ».
// USB seulement (la liste blanche la refuse deja au reseau).
static void cmdNom(char *texte) {
  if (sSortie.reseau) return repondreErreur("refuse");
  while (*texte == ' ') texte++;
  size_t n = strlen(texte);
  while (n > 0 && texte[n - 1] == ' ') texte[--n] = 0;
  const char *erreur = nullptr;
  if (!nomValide(texte)) {
    erreur = "syntaxe";
  } else if (sPreferences.putString(kCleNom, texte) == 0) {
    erreur = "ecriture";
  }
  if (erreur) {
    debut("erreur");
    ajoute(",\"erreur\":\"%s\"", erreur);
    fin();
    return;
  }
  snprintf(sNom, sizeof(sNom), "%s", texte);
  cmdBonjour();
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
  // Routeur ou chef permis (FTD, eligible, politique de securite) : false attendu.
  ajoute(",\"eligible\":%s", otThreadIsRouterEligible(ot) ? "true" : "false");
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
//  routeurs : table des routeurs d'OpenThread (repris de l'essai FED)
// ---------------------------------------------------------------------------

// Une entree allouee d'otThreadGetRouterInfo, copiee sous le verrou OT pour
// ecrire les lignes hors verrou.
struct Routeur {
  uint8_t id;
  uint16_t rloc16;
  uint8_t ext[8];
  uint8_t lqIn, lqOut, age;
  bool lien;
};
static constexpr size_t kRouteursMax = 64;  // identifiants 0 a 62
static Routeur sRouteurs[kRouteursMax];

// Une entree de `liste`, precedee d'une virgule sauf en tete de liste.
// ExtMac nulle (OpenThread ne l'a pas relevee pour ce routeur) : null.
static int formaterRouteur(char *b, size_t taille, const Routeur &r, bool premier) {
  bool nulle = true;
  for (uint8_t o : r.ext) nulle = nulle && o == 0;
  char ext[19] = "null";
  if (!nulle)
    snprintf(ext, sizeof(ext), "\"%02X%02X%02X%02X%02X%02X%02X%02X\"", r.ext[0], r.ext[1], r.ext[2], r.ext[3],
             r.ext[4], r.ext[5], r.ext[6], r.ext[7]);
  return snprintf(b, taille, "%s{\"id\":%u,\"rloc16\":\"%04X\",\"ext\":%s,\"lqIn\":%u,\"lqOut\":%u,\"age\":%u,\"lien\":%s}",
                  premier ? "" : ",", (unsigned)r.id, (unsigned)r.rloc16, ext, (unsigned)r.lqIn, (unsigned)r.lqOut,
                  (unsigned)r.age, r.lien ? "true" : "false");
}

// Entrees allouees, de l'identifiant 0 a otThreadGetMaxRouterId(). Une ligne,
// ou plusieurs si elle depasserait la taille permise (4096 octets sur l'USB,
// une charge de 1100 octets sur le reseau) : "suite":true sur chaque ligne
// sauf la derniere ("suite":false), coupees entre deux entrees.
static void cmdRouteurs() {
  if (!verrouOt(200)) {
    debut("routeurs");
    ajoute(",\"erreur\":\"occupee\"");
    fin();
    return;
  }
  otInstance *ot = esp_openthread_get_instance();
  const uint8_t maxId = otThreadGetMaxRouterId(ot);
  size_t n = 0;
  for (uint16_t id = 0; id <= maxId && n < kRouteursMax; id++) {
    otRouterInfo info;
    if (otThreadGetRouterInfo(ot, id, &info) != OT_ERROR_NONE || !info.mAllocated) continue;
    Routeur &r = sRouteurs[n++];
    r.id = info.mRouterId;
    r.rloc16 = info.mRloc16;
    memcpy(r.ext, info.mExtAddress.m8, sizeof(r.ext));
    r.lqIn = info.mLinkQualityIn;
    r.lqOut = info.mLinkQualityOut;
    r.age = info.mAge;
    r.lien = info.mLinkEstablished;
  }
  libereOt();

  static const char kFinDerniere[] = "],\"suite\":false";  // la plus longue des deux fins
  debut("routeurs");
  ajoute(",\"liste\":[");
  bool premier = true;
  for (size_t i = 0; i < n; i++) {
    char entree[160];
    int l = formaterRouteur(entree, sizeof(entree), sRouteurs[i], premier);
    // ajoute() reussit si sLong + longueur + 3 <= sLimite (NUL, '}' et LF) :
    // l'entree puis la fin de ligne doivent encore tenir, sinon ligne suivante.
    if (!premier && sLong + (size_t)l + (sizeof(kFinDerniere) - 1) + 3 > sLimite) {
      ajoute("],\"suite\":true");
      fin();
      debut("routeurs");
      ajoute(",\"liste\":[");
      premier = true;
      l = formaterRouteur(entree, sizeof(entree), sRouteurs[i], premier);
    }
    ajoute("%s", entree);
    premier = false;
  }
  ajoute("%s", kFinDerniere);
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

// Un emplacement par requete en vol. loop() le remplit (id, cible, sortie,
// debut), pose finie a faux puis enVol, sous le verrou OT, avant l'envoi. Le
// rappel CoAP (tache OpenThread) ecrit la reponse (fin, erreur, code, charge,
// longueur, tronquee), puis pose finie. loop() ne lit la reponse qu'apres
// avoir vu finie, puis libere l'emplacement (finie et enVol a faux). finie
// est atomique : son ecriture ne passe pas avant celles de la reponse, ce que
// volatile ne garantissait pas. enVol ne quitte pas la tache de loop().
struct Requete {
  std::atomic<bool> enVol;
  std::atomic<bool> finie;
  uint32_t id;
  char cible[48];
  uint32_t debutMs, finMs;
  otError erreur;
  uint8_t code;  // code CoAP de la reponse
  uint8_t charge[1024];
  uint16_t longueur;
  bool tronquee;
  Sortie sortie;  // qui attend la reponse : l'USB, ou une session reseau et son rid
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

// Reprises CoAP reglees pour que l'echec tombe au bout du delai demande
// (distant::reprisesDiag), facteur aleatoire de 1.
static otCoapTxParameters parametres(uint32_t delaiMs) {
  const distant::Reprises r = distant::reprisesDiag(delaiMs);
  otCoapTxParameters p = {r.accuseMs, 1, 1, r.reprises};
  return p;
}

static void repondreDiagErreur(uint32_t id, const char *cible, const char *erreur) {
  debut("diag");
  ajoute(",\"id\":%lu,\"cible\":\"%s\",\"ok\":false,\"erreur\":\"%s\"", (unsigned long)id, cible, erreur);
  fin();
}

// Cible : RLOC16 en 4 hexa, ou adresse IPv6 (hexa, ':', et '.' d'une IPv4
// incluse). Rien d'autre : la cible repart telle quelle dans la ligne JSON
// (sans echappement), qui doit rester valide, sur l'USB comme a distance.
static const char kCaracteresCible[] = "0123456789abcdefABCDEF:.";

// diag <cible> <t,t,...> <id> [<delai ms>]. id et delai en decimal
// (distant::lireEntier), sinon « syntaxe », avec l'id s'il a pu etre lu (0
// sinon).
static void cmdDiag(char *args) {
  char *cible = strtok(args, " ");
  char *liste = strtok(nullptr, " ");
  char *idTexte = strtok(nullptr, " ");
  char *delaiTexte = strtok(nullptr, " ");
  uint32_t id = 0, delai = kDelaiDefaut;
  const bool idLu = idTexte && distant::lireEntier(idTexte, &id);
  const bool delaiLu = !delaiTexte || distant::lireEntier(delaiTexte, &delai);
  if (!cible || !liste || !idLu || !delaiLu || strlen(cible) >= sizeof(sRequetes[0].cible) ||
      strspn(cible, kCaracteresCible) != strlen(cible)) {
    repondreDiagErreur(id, "", "syntaxe");
    return;
  }
  if (sSuspendue) return repondreDiagErreur(id, cible, "suspendue");
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
    r.sortie = sSortie;
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
  // A distance, une reponse qui ne tient pas dans un datagramme : trop_long.
  if (sTropLong && sSortie.reseau) {
    debut("diag");
    ajoute(",\"id\":%lu,\"cible\":\"%s\",\"ok\":false,\"erreur\":\"trop_long\"", (unsigned long)r.id, r.cible);
  }
  fin();
}

// Reponses arrivees. Pour une session reseau : partie entre-temps, la reponse
// tombe ; sinon elle attend une place dans la file d'emission (jamais perdue
// faute de place), puis elle est gardee pour un rid repete.
static void diagsFinis() {
  for (Requete &r : sRequetes) {
    if (!r.enVol || !r.finie) continue;
    if (r.sortie.reseau) {
      if (!reseauSessionActive(r.sortie.place, r.sortie.generation)) {
        r.finie = false;
        r.enVol = false;
        continue;
      }
      if (!reseauPlacesLibres()) continue;
      sGardees[r.sortie.place].commencer(r.sortie.rid);
    }
    sSortie = r.sortie;
    imprimerDiag(r);
    sSortie = Sortie();
    if (r.sortie.reseau) sGardees[r.sortie.place].terminer();
    r.finie = false;
    r.enVol = false;
  }
}

// ---------------------------------------------------------------------------
//  Cle d'acces reseau (USB seulement)
// ---------------------------------------------------------------------------

// Ligne de reponse a cle nouvelle, au plus : RS, {"v":1,"t":"cle","id":<10>,
// "cle":"<64>","empreinte":"<8>","hote":"<63>"}, LF : 204 octets. Avec le msg
// d'une cle non chargee (kMsgNonChargee, rare) : 252, sous les 256 du tampon.
// La place libre exigee couvre le cas le plus long : la reponse est la seule
// copie de la cle.
static constexpr int kLigneCleMax = 252;
static const char *const kMsgNonChargee = "cle non chargee : active au redemarrage";

// Effacement de la cle refuse par la NVS : la cle n'est plus en memoire (plus
// d'acces reseau), mais elle reviendrait au demarrage. Jamais tu : la reponse
// a cle le dit (effacement_en_echec), et un nouvel essai part a chaque tour
// de surveillerAppairage (500 ms) jusqu'a ce que la NVS accepte.
static bool sEffacementEnEchec = false;

// Deux essais, comme Halo (matterDecommissionNow). true : plus aucune cle en
// NVS (effacee, ou il n'y en avait pas).
static bool effacerCle() {
  const bool ok = reseauCleEfface() || reseauCleEfface();
  sEffacementEnEchec = !ok;
  return ok;
}

// {"v":1,"t":"cle","empreinte":"<8 hexa>"|null} ; aussi le nom d'hote, les
// compteurs du transport (bloc reseau.ip.udp du pont Halo, plus les lignes
// perdues faute de place dans la file d'emission et les commandes refusees
// par la cadence) et le tas (libre, minimum depuis le demarrage : la 1.0.2
// prend ~18 Ko de RAM de plus).
static void repondreCle() {
  char kid[h1::kKidHex + 1];
  CompteursReseau c;
  reseauCompteurs(&c);
  const uint32_t tasLibre = esp_get_free_heap_size(), tasMin = esp_get_minimum_free_heap_size();
  debut("cle");
  if (reseauEmpreinte(kid)) ajoute(",\"empreinte\":\"%s\"", kid);
  else ajoute(",\"empreinte\":null");
  // Cle sortie de la memoire mais pas de la NVS : elle reviendrait au demarrage.
  ajoute(",\"effacement_en_echec\":%s", sEffacementEnEchec ? "true" : "false");
  ajouteHote();
  ajoute(",\"udp\":{\"port\":%u,\"ouvert\":%s,\"sessions\":%u,\"provisoire\":%s,\"rx\":%lu,\"rejets\":%lu,"
         "\"rx_perdus\":%lu,\"defis\":%lu,\"tx\":%lu,\"tx_perdus\":%lu,\"tx_erreurs\":%lu",
         (unsigned)kPortReseau, c.ouvert ? "true" : "false", (unsigned)c.sessions, c.provisoire ? "true" : "false",
         (unsigned long)c.rx, (unsigned long)c.rejets, (unsigned long)c.rxPerdus, (unsigned long)c.defis,
         (unsigned long)c.tx, (unsigned long)c.txPerdus, (unsigned long)c.txErreurs);
  if (c.tamponsMinConnu) ajoute(",\"tampons_min\":%u", (unsigned)c.tamponsMin);
  else ajoute(",\"tampons_min\":null");
  ajoute(",\"lignes_perdues\":%lu,\"refus_cadence\":%lu}", (unsigned long)sLignesPerdues,
         (unsigned long)sRefusCadence);
  ajoute(",\"tas\":{\"libre\":%lu,\"min\":%lu}", (unsigned long)tasLibre, (unsigned long)tasMin);
  fin();
}

// cle nouvelle <64 HEXA> <id> : cle = HMAC-SHA256(cle = alea de l'app,
// message = alea de la carte), gardee en NVS et rendue une seule fois, dans
// cette reponse. La cle n'est jamais imprimee ailleurs ; sans id : syntaxe.
static void cleNouvelle(const char *hex, const char *idTexte) {
  uint8_t alea[32];
  uint32_t id = 0;
  // 64 hexa MAJUSCULES (h1::fromHex refuse les minuscules), comme Halo.
  const bool ok = strlen(hex) == 64 && h1::fromHex(hex, sizeof(alea), alea) && distant::lireEntier(idTexte, &id);
  if (!ok) {
    h1::wipe(alea, sizeof(alea));
    return repondreErreur("syntaxe");
  }
  // La reponse est la seule copie de la cle : pas de cle neuve si elle ne
  // peut pas partir tout de suite (tampon d'emission USB occupe).
  if (Serial.availableForWrite() < kLigneCleMax) {
    h1::wipe(alea, sizeof(alea));
    return repondreErreur("occupee");
  }
  char cleHex[65], kid[h1::kKidHex + 1];
  const ResultatCle res = reseauCleNouvelle(alea, cleHex, kid);
  h1::wipe(alea, sizeof(alea));
  if (res == ResultatCle::Crypto) return repondreErreur("crypto");
  if (res == ResultatCle::Nvs) return repondreErreur("ecriture");
  // La nouvelle cle a remplace l'ancienne en NVS : plus rien a effacer.
  sEffacementEnEchec = false;
  debut("cle");
  ajoute(",\"id\":%lu,\"cle\":\"%s\",\"empreinte\":\"%s\"", (unsigned long)id, cleHex, kid);
  ajouteHote();
  // Cle ecrite mais pas chargee : elle vaut au prochain demarrage, l'app doit
  // la connaitre ; la reponse le dit (msg, comme Halo).
  if (res == ResultatCle::Chargement) ajoute(",\"msg\":\"%s\"", kMsgNonChargee);
  fin();
  h1::wipe(cleHex, sizeof(cleHex));
  h1::wipe(sLigne, sizeof(sLigne));
}

// cle | cle efface | cle nouvelle <64 HEXA> <id> : USB seulement. La liste
// blanche les refuse deja au reseau ; refusees ici aussi (defense en
// profondeur : la reponse de nouvelle porte la cle).
static void cmdCle(char *args) {
  if (sSortie.reseau) return repondreErreur("refuse");
  char *mots[4];
  size_t n = 0;
  for (char *m = strtok(args, " "); m && n < 4; m = strtok(nullptr, " ")) mots[n++] = m;
  if (n == 0) return repondreCle();
  if (n == 1 && !strcmp(mots[0], "efface")) {
    if (!effacerCle()) return repondreErreur("ecriture");
    return repondreCle();
  }
  if (n == 3 && !strcmp(mots[0], "nouvelle")) return cleNouvelle(mots[1], mots[2]);
  repondreErreur("syntaxe");
}

// oubli : la cle part aussi (deux essais : un echec la laisserait revenir au
// demarrage), sinon l'ancien proprietaire garderait l'acces reseau apres un
// nouvel appairage (comme Halo, matterDecommissionNow). Matter n'efface que
// ses propres espaces NVS. La reponse dit si la cle est bien partie
// (cle_effacee false : la NVS a refuse, la cle reviendra au redemarrage ;
// cle efface ensuite). USB seulement.
// La sonde revient allumee, comme a sa premiere mise en service (1.0.3) :
// setOnOff(true) allume l'interrupteur dans Matter et passe par le rappel
// (surInterrupteur), qui garde l'etat dans la NVS de la sonde, que
// decommission() n'efface pas. Deja allume : rien a faire.
static void cmdOubli() {
  if (sSortie.reseau) return repondreErreur("refuse");
  const bool effacee = effacerCle();
  debut("oubli");
  ajoute(",\"cle_effacee\":%s", effacee ? "true" : "false");
  fin();
  Serial.flush();
  sInterrupteur.setOnOff(true);
  Matter.decommission();  // efface l'appairage et redemarre
}

// Plus aucun controleur (sonde retiree de Maison sans oubli) : Matter rouvre
// l'appairage ; la cle part aussi, sinon l'ancien proprietaire garderait
// l'acces reseau apres qu'un autre a ajoute la sonde (comme Halo, ownerPoll).
// Seul un passage observe de « appairee » a « plus appairee » compte (pas
// l'etat au demarrage). Un effacement refuse par la NVS (ici ou par cle
// efface) est retente a chaque tour, et dit par la reponse a cle.
static void surveillerAppairage(uint32_t maintenant) {
  static int8_t sVu = -1;  // -1 : pas encore lu
  static uint32_t sA = 0;
  if (sVu >= 0 && maintenant - sA < 500) return;
  sA = maintenant;
  const bool appairee = Matter.isDeviceCommissioned();
  char kid[h1::kKidHex + 1];
  if ((sVu == 1 && !appairee && reseauEmpreinte(kid)) || sEffacementEnEchec) effacerCle();
  sVu = appairee ? 1 : 0;
}

// ---------------------------------------------------------------------------
//  Commandes recues par le reseau (reseau.cpp)
// ---------------------------------------------------------------------------

void reseauSessionPartie(uint8_t place) {
  if (place >= kPlacesReseau) return;
  sGardees[place].vider();
  sCadences[place] = distant::Cadence();
}

// Une ligne gardee repart vers l'app, "<rid> <ligne JSON>".
struct Renvoi {
  uint8_t place;
  char prefixe[distant::kRidMax + 2];
  size_t n;
};

static void renvoyerLigne(void *contexte, const uint8_t *ligne, size_t n) {
  const Renvoi &r = *(const Renvoi *)contexte;
  if (!reseauEnvoyer(r.place, r.prefixe, r.n, ligne, n)) sLignesPerdues++;
}

static void executer(char *c);

// "<rid> <commande>" d'une session etablie. Sans rid lisible, aucune reponse
// possible : ignoree. Un rid deja servi ne relance rien : la reponse gardee
// repart, ou rien si un diag de ce rid est encore en vol. Puis la cadence,
// comme Halo apres l'id (benq cli.cpp) : plus de 20 commandes dans la seconde,
// rien, sans reponse (l'app renvoie), mais le refus est compte
// (sRefusCadence). Hors liste blanche : erreur « refuse ».
void reseauRecu(uint8_t place, char *charge) {
  uint32_t rid = 0;
  char *commande = nullptr;
  if (place >= kPlacesReseau || !distant::lireRid(charge, &rid, &commande)) return;
  const uint32_t generation = reseauGeneration(place);
  for (const Requete &r : sRequetes)
    if (r.enVol && r.sortie.reseau && r.sortie.place == place && r.sortie.generation == generation &&
        r.sortie.rid == rid)
      return;
  Renvoi renvoi;
  renvoi.place = place;
  renvoi.n = distant::texteRid(rid, renvoi.prefixe);
  renvoi.prefixe[renvoi.n++] = ' ';
  if (sGardees[place].rendre(rid, renvoyerLigne, &renvoi)) return;
  if (!sCadences[place].allow(millis())) {
    sRefusCadence++;
    return;
  }

  sSortie.reseau = true;
  sSortie.place = place;
  sSortie.generation = generation;
  sSortie.rid = rid;
  sGardees[place].commencer(rid);
  if (distant::permise(commande)) executer(commande);
  else repondreErreur("refuse");
  sGardees[place].terminer();
  sSortie = Sortie();
}

// ---------------------------------------------------------------------------
//  LED de la carte (1.0.3)
// ---------------------------------------------------------------------------

// WS2812 de la SuperMini, sur IO8 : rien d'autre n'y touche dans ce firmware.
// Faible intensite, comme le voyant du pont Halo sur la meme carte : 24/255 au
// plus par canal ; orange : un quart de vert (le vert d'une WS2812 parait bien
// plus fort que son rouge). Ordre GRB par defaut de rgbLedWrite.
static constexpr uint8_t kBrocheVoyant = 8;
static constexpr uint8_t kVoyantMax = 24;
static distant::Voyant sVoyant;
static bool sVoyantSuspendue = false;  // etat de l'interrupteur que la LED montre
static int sVoyantEcrit = -1;          // couleur ecrite ; -1 : rien encore

// rgbLedWrite (Arduino-ESP32 3.x) : 24 bits par le RMT, environ 30 us ; le
// canal RMT est cree au premier appel, puis reutilise. Seulement si la
// couleur change.
static void ecrireVoyant(distant::Voyant::Couleur c) {
  if ((int)c == sVoyantEcrit) return;
  sVoyantEcrit = (int)c;
  switch (c) {
    case distant::Voyant::kVerte: rgbLedWrite(kBrocheVoyant, 0, kVoyantMax, 0); break;
    case distant::Voyant::kOrange: rgbLedWrite(kBrocheVoyant, kVoyantMax, kVoyantMax / 4, 0); break;
    default: rgbLedWrite(kBrocheVoyant, 0, 0, 0); break;
  }
}

// Dans loop() seulement, hors de tout verrou : le rappel Matter ne fait que
// poser sSuspendue, et un changement vu ici lance les eclairs de
// l'interrupteur. Sans attente : la sequence se lit sur millis().
static void voyantTour(uint32_t maintenant) {
  const bool suspendue = sSuspendue;
  if (suspendue != sVoyantSuspendue) {
    sVoyantSuspendue = suspendue;
    sVoyant.changer(suspendue, maintenant);
  }
  ecrireVoyant(sVoyant.couleur(maintenant));
}

// ---------------------------------------------------------------------------
//  Boucle
// ---------------------------------------------------------------------------

static char sCommande[200];
static size_t sCmdLong = 0;

static void executer(char *c) {
  while (*c == ' ') c++;
  if (!strcmp(c, "bonjour")) return cmdBonjour();
  // « nom » seul : nom vide, refuse (syntaxe).
  if (!strcmp(c, "nom") || !strncmp(c, "nom ", 4)) return cmdNom(c + 3);
  if (!strcmp(c, "etat")) return cmdEtat();
  if (!strcmp(c, "voisins")) return cmdVoisins();
  if (!strcmp(c, "routeurs")) return cmdRouteurs();
  if (!strncmp(c, "diag ", 5)) return cmdDiag(c + 5);
  if (!strcmp(c, "cle") || !strncmp(c, "cle ", 4)) return cmdCle(c + 3);
  if (!strcmp(c, "oubli")) return cmdOubli();
  if (!*c) return;
  debut("erreur");
  ajoute(",\"erreur\":\"commande inconnue\"");
  fin();
}

void setup() {
  Serial.begin(115200);
  // LED au noir d'abord : une WS2812 garde sa couleur a travers un redemarrage
  // (son alimentation ne coupe pas). IO8, broche de strapping, est deja
  // echantillonnee a ce stade.
  ecrireVoyant(distant::Voyant::kNoire);
  demarrerMatter();
  reseauDebut();
  // Etat relu de la NVS : suspendue, un bref eclair orange des le premier tour.
  sVoyantSuspendue = sSuspendue;
  sVoyant.demarrer(sVoyantSuspendue, millis());
  cmdBonjour();
}

void loop() {
  while (Serial.available()) {
    const int o = Serial.read();
    if (o == '\n' || o == '\r') {
      sCommande[sCmdLong] = 0;
      if (sCmdLong) {
        executer(sCommande);
        // Rien ne reste de la ligne (l'alea de cle nouvelle).
        h1::wipe(sCommande, sizeof(sCommande));
      }
      sCmdLong = 0;
    } else if (o >= 0x20 && o < 0x7F && sCmdLong < sizeof(sCommande) - 1) {
      sCommande[sCmdLong++] = (char)o;
    }
  }
  diagsFinis();
  reseauTour();
  surveillerAppairage(millis());
  voyantTour(millis());
  delay(5);
}
