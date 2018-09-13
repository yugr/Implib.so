#!/bin/sh

# Copyright 2017 Yury Gribov
#
# The MIT License (MIT)
# 
# Use of this source code is governed by MIT license that can be
# found in the LICENSE.txt file.

set -eu

cd $(dirname $0)

#CFLAGS⇔'-gdwarf-2 -O0'
CFLAGS='-DNDEBUG -O2'

if uname -o | grep -q FreeBSD; then
  LIBS=
else
  LIBS=-ldl
fi

# Build shlib
gcc $CFLAGS -shared -fPIC test.c -o libtest.so

for flags in '' '--no-lazy-load'; do
  # Prepare implib
  ../../implib-gen.py $flags libtest.so

  # Build app
  gcc $CFLAGS main.c libtest.so.tramp.S libtest.so.init.c $LIBS

  LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} ./a.out
done
