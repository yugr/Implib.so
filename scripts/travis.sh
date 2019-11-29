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

tests/1/run.sh ${ARCH:-}

# TODO: all platforms
case "${ARCH:-}" in
'' | x86_64)
  tests/2/run.sh
  ;;
esac
