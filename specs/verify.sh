#!/bin/sh

set -eu
set -x

rm -rf states
java -jar ~/Downloads/tla2tools.jar -workers `nproc` -coverage 0 Init.tla

for inv in never_0 Prop; do
  spin -run -ltl $inv Init.pml
done
