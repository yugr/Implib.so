#!/bin/sh

# Copyright 2017-2018 Yury Gribov
#
# The MIT License (MIT)
# 
# Use of this source code is governed by MIT license that can be
# found in the LICENSE.txt file.

set -eu

cd $(dirname $0)

#CFLAGS='-gdwarf-2 -O0'
#CFLAGS='-DNDEBUG -O2'
CFLAGS='-g -O2'

if uname -o | grep -q FreeBSD; then
  LIBS=
else
  LIBS=-ldl
fi

case "${1:-}" in
arm)
  # To run tests for ARM install
  # $ sudo apt-get install gcc-arm-linux-gnueabi qemu-user
  TARGET=arm
  PREFIX=arm-linux-gnueabi-
  INTERP="qemu-arm -L /usr/arm-linux-gnueabi -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  ;;
aarch64)
  # To run tests for AArch64 install
  # sudo apt-get install gcc-aarch64-linux-gnu qemu-user
  TARGET=aarch64
  PREFIX=aarch64-linux-gnu-
  INTERP="qemu-aarch64 -L /usr/aarch64-linux-gnu -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  ;;
'' | x86_64 | host)
  TARGET=x86_64
  PREFIX=
  INTERP=
  ;;
*)
  echo >&2 "Unsupported target: $1"
  exit 1
  ;;
esac


# Build shlib
${PREFIX}gcc $CFLAGS -shared -fPIC test.c -o libtest.so

for flags in '' '--no-lazy-load'; do
  echo "Testing config: ${flags:-default}."

  # Prepare implib
  ../../implib-gen.py --target $TARGET $flags libtest.so

  # Build app
  ${PREFIX}gcc $CFLAGS main.c libtest.so.tramp.S libtest.so.init.c $LIBS

  LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out | tee a.out.log
  diff test.ref a.out.log
done

echo SUCCESS
