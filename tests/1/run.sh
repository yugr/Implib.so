#!/bin/sh

# Copyright 2017-2019 Yury Gribov
#
# The MIT License (MIT)
# 
# Use of this source code is governed by MIT license that can be
# found in the LICENSE.txt file.

# This is a simple test for Implib.so functionality.
# Run it like
#   ./run.sh ARCH
# where ARCH stands for any supported arch (arm, x86_64, etc., see `implib-gen -h' for full list).
# Note that you may need to install qemu-user for respective platform
# (i386 also needs gcc-multilib).

set -eu

cd $(dirname $0)

#CFLAGS='-gdwarf-2 -O0'
#CFLAGS='-DNDEBUG -O2'
CFLAGS='-g -O2'

case "${1:-}" in
arm*)
  # To run tests for ARM install
  # $ sudo apt-get install gcc-arm-linux-gnueabi qemu-user
  TARGET=arm
  PREFIX=arm-linux-gnueabi-
  INTERP="qemu-arm -L /usr/arm-linux-gnueabi -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  ;;
aarch64*)
  # To run tests for AArch64 install
  # sudo apt-get install gcc-aarch64-linux-gnu qemu-user
  TARGET=aarch64
  PREFIX=aarch64-linux-gnu-
  INTERP="qemu-aarch64 -L /usr/aarch64-linux-gnu -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  ;;
i[0-9]86)
  # To run tests for AArch64 install
  # sudo apt-get install gcc-aarch64-linux-gnu qemu-user
  TARGET=i686
  PREFIX=
  INTERP=
  CFLAGS="$CFLAGS -m32"
  ;;
'' | x86_64* | host)
  TARGET=x86_64
  PREFIX=
  INTERP=
  ;;
*)
  echo >&2 "Unsupported target: $1"
  exit 1
  ;;
esac

CC=${PREFIX}gcc

if uname -o | grep -q FreeBSD; then
  LIBS=
else
  LIBS=-ldl
fi

# Build shlib to test against
$CC $CFLAGS -shared -fPIC interposed.c -o libinterposed.so

# Standalone executables

for ADD_CFLAGS in '-no-pie' '-fPIE'; do
  # Check for older compilers
  case "$ADD_CFLAGS" in
  -no-pie)
    (strings $(which $CC) | grep -q no-pie) || continue
    ;;
  esac

  for ADD_GFLAGS in '' '--no-lazy-load'; do
    echo "Standalone executable: GFLAGS += '$ADD_GFLAGS', CFLAGS += '$ADD_CFLAGS'"

    # Prepare implib
    ../../implib-gen.py -q --target $TARGET $ADD_GFLAGS libinterposed.so

    # Build app
    $CC $CFLAGS $ADD_CFLAGS main.c test.c libinterposed.so.tramp.S libinterposed.so.init.c $LIBS

    LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out > a.out.log
    diff test.ref a.out.log
  done
done

# Shlibs

for ADD_GFLAGS in '' '--no-lazy-load'; do
  echo "Shared library: GFLAGS += '$ADD_GFLAGS'"

  # Prepare implib
  ../../implib-gen.py -q --target $TARGET $ADD_GFLAGS libinterposed.so

  # Build shlib
  $CC $CFLAGS -shared -fPIC shlib.c test.c libinterposed.so.tramp.S libinterposed.so.init.c $LIBS -o shlib.so

  # Build app
  $CC $CFLAGS $ADD_CFLAGS main.c shlib.so

  LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out > a.out.log
  diff test.ref a.out.log
done

echo SUCCESS
