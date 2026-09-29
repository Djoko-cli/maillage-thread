#!/bin/sh
# Tests hote purs de la sonde, sans carte : enveloppe H1 (test_h1.cpp, repris
# du pont Halo de benq) et commandes a distance (test_distant.cpp : rid, liste
# blanche, reponses gardees, cadence).
#
#   sh sonde/test/lancer.sh
#
# clang++ de Xcode (CommonCrypto pour la crypto de H1), ASan et UBSan. Les
# binaires vont dans un dossier temporaire : rien ne reste dans le depot.
set -e
ICI=$(cd "$(dirname "$0")" && pwd)
SRC="$ICI/../src"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DRAPEAUX="-std=gnu++17 -g -O1 -Wall -Wextra -fsanitize=address,undefined -fno-sanitize-recover=undefined -fno-omit-frame-pointer"
clang++ $DRAPEAUX -I"$SRC" "$ICI/test_h1.cpp" "$SRC/h1_proto.cpp" -o "$TMP/test_h1"
clang++ $DRAPEAUX -I"$SRC" "$ICI/test_distant.cpp" "$SRC/distant.cpp" -o "$TMP/test_distant"
"$TMP/test_h1"
"$TMP/test_distant"
