#!/bin/sh

# Copyright 2019-2020 Yury Gribov
#
# The MIT License (MIT)
# 
# Use of this source code is governed by MIT license that can be
# found in the LICENSE.txt file.

set -eu

if test -n "${TRAVIS:-}"; then
  set -x
fi

cd $(dirname $0)/..

ARCH=${ARCH:-}
export PYTHON="${PYTHON:-python3}"

tests/basic/run.sh $ARCH
tests/exceptions/run.sh $ARCH
tests/data-warnings/run.sh $ARCH
test -n "$ARCH" || tests/ld/run.sh  # TODO: enable for other targets
