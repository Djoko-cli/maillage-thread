#!/bin/sh
# Genere le projet puis lance les tests : tous, ou ceux passes en arguments
#   outils/tester.sh MaillageCoeurTests/AdressesTests MaillageThreadTests
# Affiche les erreurs, les tests en echec et le bilan ; journal complet dans
# $TMPDIR/maillage-tests.log. Produits de compilation hors du depot (DD).
set -u
cd "$(dirname "$0")/.."
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage}
JOURNAL=${TMPDIR:-/tmp}/maillage-tests.log
xcodegen generate --quiet || exit 1
FILTRES=""
for t in "$@"; do FILTRES="$FILTRES -only-testing:$t"; done
# shellcheck disable=SC2086
xcodebuild -project MaillageThread.xcodeproj -scheme MaillageThread -destination 'platform=macOS' \
  -derivedDataPath "$DD" test $FILTRES > "$JOURNAL" 2>&1
CODE=$?
grep -E "(error|warning): |✘|Test run with|\*\* TEST" "$JOURNAL" | grep -v -e appintentsmetadataprocessor -e "\[Connection\]"
echo "journal complet : $JOURNAL (code $CODE)"
exit $CODE
