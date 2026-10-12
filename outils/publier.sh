#!/bin/sh
# Publie une version de Maillage Thread sur GitHub (spec du deploiement, section 3) : verifications, numeros,
# compilation Release signee par le Developer ID de Djoko et notarisee, .dmg signe par Sparkle (cle du trousseau), controle
# d'anonymisation, version publiee (etiquette maillage-vX.Y.Z, avec le .dmg), puis le flux des mises a jour
# (appcast.xml, qui garde toutes les versions) commite sur main et pousse aussitot, .dmg sur le Bureau.
# Le .dmg porte aussi la licence de Sparkle 2.10.0 (outils/Sparkle-LICENSE.txt, le fichier LICENSE de l'etiquette
# 2.10.0, entier) ; le commit du flux est signe Djoko-cli, a l'adresse noreply de GitHub.
# La logique est dans outils/publication.py, ses tests dans outils/tests.
#   outils/publier.sh X.Y.Z [--sans-bureau]
# La repetition, sans GitHub ni Bureau (spec, section 4), avec la cle du trousseau, ou une paire d'essai :
#   outils/publier.sh X.Y.Z --repetition DOSSIER --url-base URL [--cle-privee FICHIER --cle-publique CLE]
#                           [--trousseau TROUSSEAU] [--sans-tests]
# SPARKLE_BIN : le dossier bin de l'archive de Sparkle 2.10.0 (sign_update, generate_keys), obligatoire hors repetition.
# Depuis la 1.2.2 (decision de Djoko du 12/10/2026), les versions publiees sont signees par son Developer ID et
# notarisees : NOTARISER=1 et PROFIL_NOTARISATION=djoko-notarisation (le profil que notarytool store-credentials a
# range dans le trousseau) par defaut. Jusqu'a la 1.2.1, elles l'etaient par le certificat auto-signe
# « Djoko-cli Code Signing ». La logique (outils/publication.py) est identique a l'octet a celle d'Amaran Compagnon.
# Produits : build/publication/X.Y.Z/ ; compilation dans DD (par defaut DerivedData/maillage-thread-publication).
set -eu
cd "$(dirname "$0")/.."
# L'identite de signature de la version publiee, a ce seul endroit : le Developer ID de Djoko, trouve dans le
# trousseau par son prefixe (son nom complet porte le nom legal du titulaire : il n'est ecrit nulle part ici).
IDENTITE_SIGNATURE=${IDENTITE_SIGNATURE:-Developer ID Application}
NOTARISER=${NOTARISER:-1}
PROFIL_NOTARISATION=${PROFIL_NOTARISATION:-djoko-notarisation}
export NOTARISER PROFIL_NOTARISATION
# Le cliquet du Developer ID : depuis la 1.2.2, une version publiee n'est jamais signee autrement (un retour au
# certificat auto-signe ramenerait l'alerte « l'app differe » de macOS et le blocage de Gatekeeper). La repetition
# seule peut signer autrement.
repetition=0
for x in "$@"; do
  case $x in --repetition|--repetition=*) repetition=1;; esac
done
if [ $repetition = 0 ] && { [ "$IDENTITE_SIGNATURE" != "Developer ID Application" ] || [ "$NOTARISER" != 1 ]; }; then
  echo "publier.sh : une version publiee est signee par le Developer ID et notarisee (IDENTITE_SIGNATURE, NOTARISER)" >&2
  exit 1
fi
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage-thread-publication}
# Le numero de compilation compte les commits : un clone superficiel donnerait 1, que l'app prend pour une
# compilation de travail (jamais de mise a jour). Il faut un clone complet.
if [ "$(git rev-parse --is-shallow-repository)" != false ]; then
  echo "publier.sh : clone superficiel (ou hors git) ; publier depuis un clone complet" >&2
  exit 1
fi
export DD
exec /usr/bin/python3 outils/publication.py publier "$@" --identite "$IDENTITE_SIGNATURE" \
  --auteur Djoko-cli --etiquette maillage-v --flux appcast.xml --licence outils/Sparkle-LICENSE.txt \
  --nom-app "Maillage Thread" --fichier Maillage-Thread --depot-github Djoko-cli/maillage-thread \
  --projet MaillageThread.xcodeproj --schema MaillageThread --cible MaillageThread \
  --test 'outils/tester.sh' \
  --test 'xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination platform=macOS -derivedDataPath "$DD" -testLanguage en -testRegion US test' \
  --test '/usr/bin/python3 -m unittest discover -s outils/tests' \
  --test '/usr/bin/python3 -m unittest discover -s sonde/test && sh sonde/test/lancer.sh' \
  --test 'sh outils/thread-route/tests.sh' \
  --textes MaillageThread/Ressources/Localizable.xcstrings --textes MaillageThread/Ressources/InfoPlist.xcstrings
