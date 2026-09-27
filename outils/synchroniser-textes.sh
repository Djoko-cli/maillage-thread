#!/bin/sh
# Met le catalogue de l'app a jour avec les textes extraits par le compilateur
# (a lancer apres une compilation, par exemple outils/tester.sh) : ajoute les
# nouvelles cles, marque "stale" celles qui ont disparu du code. Ensuite :
#   python3 outils/traduire.py MaillageThread/Ressources/Localizable.xcstrings outils/traductions/<fichier>.json
set -eu
cd "$(dirname "$0")/.."
DD=${DD:-$HOME/Library/Developer/Xcode/DerivedData/maillage}
I="$DD/Build/Intermediates.noindex/MaillageThread.build/Debug/MaillageThread.build/Objects-normal"
xcrun xcstringstool sync MaillageThread/Ressources/Localizable.xcstrings --stringsdata "$I"/*/*.stringsdata
