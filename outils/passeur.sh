#!/bin/sh
# Passeur des noms de Maison : app iOS lancee sur le Mac (« concue pour
# iPad »). HomeKit n'est pas offert aux apps Mac signees Developer ID (capacite
# reservee a l'App Store) : le passeur reste une app de developpement, signee par
# l'equipe de Djoko pour son Mac enregistre.
# Compile, enveloppe l'app comme Xcode (Wrapper/ et WrappedBundle), puis la
# lance. Seul le passeur est signe avec l'equipe (l'app reste ad hoc : changer
# sa signature ferait redemander ses autorisations).
# Lance ainsi, a la main, le passeur lit Maison et n'envoie rien : ce premier
# lancement de chaque compilation passe Gatekeeper et, la premiere fois, la
# demande d'acces a Maison. Ensuite, Maillage Thread le lance lui-meme, avec un
# port et un jeton, et recoit le releve par la boucle locale (127.0.0.1).
# Equipe payante (depuis le 12/10/2026) : profil de developpement d'un an ;
# relancer ce script pour le renouveler. (L'equipe gratuite ne donnait que 7 jours.)
#
#   outils/passeur.sh [--sans-lancer]
#
#   --sans-lancer  compile et enveloppe, sans lancer.
#   APP=...        paquet a creer, en .app (defaut : ~/Applications/Passeur Noms.app).
#                  Un paquet existant n'est remplace que si c'est une enveloppe
#                  faite par ce script (lien WrappedBundle vers Wrapper/Passeur Noms.app).
#   DD=...         produits de compilation (defaut :
#                  ~/Library/Developer/Xcode/DerivedData/maillage-passeur).
#   EQUIPE=...     equipe de signature, 10 caracteres (defaut : celle du premier
#                  certificat « Apple Development » encore valide du trousseau,
#                  sinon celle du certificat « Developer ID Application », la meme
#                  equipe payante : Xcode cree alors le certificat Apple Development).
#                  Jamais affichee.
set -eu
USAGE="usage : outils/passeur.sh [--sans-lancer]"
LANCER=oui
for a in "$@"; do
  case "$a" in
    --sans-lancer) LANCER=non ;;
    *) echo "argument inconnu : $a" >&2; echo "$USAGE" >&2; exit 1 ;;
  esac
done
cd "$(dirname "$0")/.."
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage-passeur}
APP=${APP:-"$HOME/Applications/Passeur Noms.app"}
# Gardes, avant de toucher au disque : l'enveloppe est effacee puis refaite.
case "$APP" in
  *.app) ;;
  *) echo "APP : chemin d'un paquet .app (par exemple ~/Applications/Passeur Noms.app), pas « $APP »" >&2
     exit 1 ;;
esac
if [ -e "$APP" ] && [ "$(readlink "$APP/WrappedBundle" 2>/dev/null)" != "Wrapper/Passeur Noms.app" ]; then
  echo "$APP existe mais n'est pas une enveloppe faite par ce script (lien WrappedBundle) : rien n'est effacé." >&2
  exit 1
fi
# Equipe : celle du premier certificat « Apple Development » encore valide (le
# trousseau peut garder des certificats expires).
equipe() {
  pem=""
  security find-certificate -a -c "Apple Development" -p 2>/dev/null | while IFS= read -r ligne; do
    pem="$pem$ligne
"
    case "$ligne" in
      *"END CERTIFICATE"*)
        if printf '%s' "$pem" | openssl x509 -noout -checkend 0 >/dev/null 2>&1; then
          printf '%s' "$pem" | openssl x509 -noout -subject 2>/dev/null |
            sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p'
          break
        fi
        pem="" ;;
    esac
  done
}
# Repli : l'equipe du certificat « Developer ID Application » (une seule identite de ce nom dans le trousseau).
equipeDeveloperID() {
  security find-certificate -c "Developer ID Application" -p 2>/dev/null |
    openssl x509 -noout -subject -nameopt RFC2253 2>/dev/null | sed -nE 's/.*OU=([A-Z0-9]{10}).*/\1/p'
}
EQUIPE=${EQUIPE:-$(equipe | head -1)}
[ -n "$EQUIPE" ] || EQUIPE=$(equipeDeveloperID)
if [ -z "$EQUIPE" ]; then
  echo "Pas de certificat Apple Development ni Developer ID : ajouter un compte Apple dans Xcode (Réglages > Comptes), ou EQUIPE=XXXXXXXXXX" >&2
  exit 1
fi
JOURNAL=${TMPDIR:-/tmp}/maillage-passeur.log
xcodegen generate --quiet
if ! xcodebuild -project MaillageThread.xcodeproj -scheme Passeur \
    -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
    -derivedDataPath "$DD" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$EQUIPE" build > "$JOURNAL" 2>&1; then
  # Les erreurs, sans le nom du titulaire ni l'equipe.
  grep -E "error:" "$JOURNAL" | sed -E 's/(Apple Development|Developer ID Application): [^(]*\(([A-Z0-9]{10})\)/\1: <titulaire> (<equipe>)/g; s/[A-Z0-9]{10}/<id>/g' >&2 || true
  echo "échec de la compilation, journal complet : $JOURNAL" >&2
  exit 1
fi
PRODUIT="$DD/Build/Products/Debug-iphoneos/Passeur Noms.app"
if [ ! -d "$PRODUIT" ]; then
  echo "Produit de compilation introuvable : $PRODUIT ($APP n'est pas touché)" >&2
  exit 1
fi
# Enveloppe : un paquet Mac qui contient l'app iOS, comme Xcode l'installe.
rm -rf "$APP"
mkdir -p "$APP/Wrapper"
cp -R "$PRODUIT" "$APP/Wrapper/"
ln -s "Wrapper/Passeur Noms.app" "$APP/WrappedBundle"
if [ "$LANCER" = non ]; then
  echo "Passeur Noms prêt (non lancé) : $APP"
else
  open "$APP"
  echo "Passeur Noms lancé : $APP"
fi
