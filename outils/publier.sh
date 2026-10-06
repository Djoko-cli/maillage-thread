#!/bin/sh
# Publie une version de Maillage Thread sur GitHub (spec du deploiement, section 3) : verifications, numeros,
# compilation Release signee par le certificat de Djoko, .dmg signe par Sparkle (cle du trousseau), controle
# d'anonymisation, version publiee (etiquette maillage-vX.Y.Z, avec le .dmg), puis le flux des mises a jour
# (appcast.xml, qui garde toutes les versions) commite sur main et pousse aussitot, .dmg sur le Bureau.
# La logique est dans outils/publication.py, ses tests dans outils/tests.
#   outils/publier.sh X.Y.Z [--sans-bureau]
# La repetition, sans GitHub ni Bureau (spec, section 4), avec la cle du trousseau, ou une paire d'essai :
#   outils/publier.sh X.Y.Z --repetition DOSSIER --url-base URL [--cle-privee FICHIER --cle-publique CLE]
#                           [--trousseau TROUSSEAU] [--sans-tests]
# SPARKLE_BIN : le dossier bin de l'archive de Sparkle 2.10.0 (sign_update, generate_keys).
# NOTARISER=1 (desactive par defaut) : notarisation du .dmg, avec PROFIL_NOTARISATION, le profil que
# notarytool store-credentials a range dans le trousseau ; il faut alors un Developer ID pour IDENTITE_SIGNATURE.
# Produits : build/publication/X.Y.Z/ ; compilation dans DD (par defaut DerivedData/maillage-thread-publication).
set -eu
cd "$(dirname "$0")/.."
# L'identite de signature de la version publiee, a ce seul endroit : le certificat auto-signe de Djoko, trouve par
# son nom dans le trousseau (les compilations de travail et les tests restent ad hoc).
IDENTITE_SIGNATURE=${IDENTITE_SIGNATURE:-Djoko-cli Code Signing}
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage-thread-publication}
export DD
exec /usr/bin/python3 outils/publication.py publier "$@" --identite "$IDENTITE_SIGNATURE" \
  --etiquette maillage-v --flux appcast.xml \
  --nom-app "Maillage Thread" --fichier Maillage-Thread --depot-github Djoko-cli/maillage-thread \
  --projet MaillageThread.xcodeproj --schema MaillageThread --cible MaillageThread \
  --test 'outils/tester.sh' \
  --test 'xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination platform=macOS -derivedDataPath "$DD" -testLanguage en -testRegion US test' \
  --test '/usr/bin/python3 -m unittest discover -s outils/tests' \
  --test '/usr/bin/python3 -m unittest discover -s sonde/test && sh sonde/test/lancer.sh' \
  --test 'sh outils/thread-route/tests.sh' \
  --textes MaillageThread/Ressources/Localizable.xcstrings --textes MaillageThread/Ressources/InfoPlist.xcstrings
