#!/bin/sh

# Copyright 2019-2020 Yury Gribov
#
# The MIT License (MIT)
# 
# Use of this source code is governed by MIT license that can be
# found in the LICENSE.txt file.

set -eu
# TODO: use pipefail here and in test scripts

if test -n "${TRAVIS:-}"; then
  set -x
fi

cd $(dirname $0)/..

ARCH=${ARCH:-}
export PYTHON="${PYTHON:-python3}"

tests/basic/run.sh $ARCH
tests/exceptions/run.sh $ARCH
tests/data-warnings/run.sh $ARCH
tests/vtables/run.sh $ARCH
if test -z "$ARCH"; then
  # TODO: enable for other targets
  tests/ld/run.sh
fi
if ! echo "$ARCH" | grep -q 'i[0-9]86'; then
  # TODO: symtab on x86 seems to be corrupted
  tests/multilib/run.sh $ARCH
fi
