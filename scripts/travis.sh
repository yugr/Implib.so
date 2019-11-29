#!/bin/sh

# Copyright 2019 Yury Gribov
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

tests/1/run.sh $ARCH
tests/2/run.sh $ARCH
