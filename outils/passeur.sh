#!/bin/sh
# Passeur des noms de Maison : app iOS lancee sur le Mac (« concue pour
# iPad »), seule forme qui ait HomeKit avec une equipe Apple gratuite.
# Compile, enveloppe l'app comme Xcode (Wrapper/ et WrappedBundle) dans
# ~/Applications, puis la lance. Seul le passeur est signe avec l'equipe (l'app
# reste ad hoc : changer sa signature ferait redemander ses autorisations).
# Equipe : celle du certificat « Apple Development » (ou EQUIPE=XXXXXXXXXX).
# Equipe gratuite : profil de 7 jours ; relancer ce script pour rafraichir.
set -eu
cd "$(dirname "$0")/.."
EQUIPE=${EQUIPE:-$(security find-certificate -c "Apple Development" -p 2>/dev/null |
  openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1)}
if [ -z "$EQUIPE" ]; then
  echo "Pas de certificat Apple Development : ajouter un compte Apple dans Xcode (Réglages > Comptes), ou EQUIPE=XXXXXXXXXX" >&2
  exit 1
fi
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage-passeur}
APP=${APP:-"$HOME/Applications/Passeur Noms.app"}
JOURNAL=${TMPDIR:-/tmp}/maillage-passeur.log
xcodegen generate --quiet
if ! xcodebuild -project MaillageThread.xcodeproj -scheme Passeur \
    -destination 'platform=macOS,arch=arm64,variant=Designed for iPad' \
    -derivedDataPath "$DD" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    DEVELOPMENT_TEAM="$EQUIPE" build > "$JOURNAL" 2>&1; then
  grep -E "error:" "$JOURNAL" >&2 || true
  echo "échec de la compilation, journal complet : $JOURNAL" >&2
  exit 1
fi
# Enveloppe : un paquet Mac qui contient l'app iOS, comme Xcode l'installe.
mkdir -p "$HOME/Applications"
rm -rf "$APP"
mkdir -p "$APP/Wrapper"
cp -R "$DD/Build/Products/Debug-iphoneos/Passeur Noms.app" "$APP/Wrapper/"
ln -s "Wrapper/Passeur Noms.app" "$APP/WrappedBundle"
if [ "${1:-}" = "--sans-lancer" ]; then
  echo "Passeur Noms prêt (non lancé) : $APP"
else
  open "$APP"
  echo "Passeur Noms lancé : $APP"
fi
