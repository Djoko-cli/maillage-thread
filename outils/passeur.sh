#!/bin/sh
# Passeur Noms, le demon de Maison, se compile desormais depuis le depot maillage-iot (spec de Maillage IoT,
# section 4.2) : Maillage Thread 1.4.0 est la derniere version de cette app, remplacee par Maillage IoT.
# Ce script ne compile plus rien : relance depuis ce depot, il remplacerait le demon installe par une compilation
# plus ancienne, que Maillage IoT refuserait.
#
#   git clone https://github.com/Djoko-cli/maillage-iot.git && maillage-iot/outils/passeur.sh
cat >&2 <<'FIN'
Passeur Noms se compile desormais depuis le depot maillage-iot :
  https://github.com/Djoko-cli/maillage-iot  (outils/passeur.sh)
Ce depot-ci installerait une version plus ancienne du demon : rien n'a ete fait.
FIN
exit 1
