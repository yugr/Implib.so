#!/bin/sh

# Copyright 2025 Yury Gribov
#
# The MIT License (MIT)
# 
# Use of this source code is governed by MIT license that can be
# found in the LICENSE.txt file.

# This is a test for manual loading of destination library (--no-dlopen flag).
# Run it like
#   ./run.sh ARCH
# where ARCH stands for any supported arch (arm, x86_64, etc., see `implib-gen -h' for full list).
# Note that you may need to install qemu-user for respective platform
# (i386 also needs gcc-multilib).

set -eu

cd $(dirname $0)

if test -n "${1:-}"; then
  ARCH="$1"
fi

. ../common.sh

CFLAGS="-g -O2 $CFLAGS"

# Build shlib to test against
$CC $CFLAGS -shared -fPIC interposed.c -o libinterposed.so

# Prepare implib
${PYTHON:-} ../../implib-gen.py -q --target $TARGET libinterposed.so

# Test without export shims

$CC $CFLAGS -fPIE main.c libinterposed.so.tramp.S libinterposed.so.init.c $LIBS

for i in $(seq 1 10); do
  LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out > a.out.log
  diff test.ref a.out.log
done

# Test with export shims

$CC $CFLAGS -DIMPLIB_EXPORT_SHIMS -fPIE main.c libinterposed.so.tramp.S libinterposed.so.init.c $LIBS

for i in $(seq 1 10); do
  LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out > a.out.log
  diff test.ref a.out.log
done

# Test with Tsan
# (do not bother with non-amd64 targets)

if test -z "$INTERP" -a uname | grep -q Linux; then
  # ASLR keeps breaking Tsan mmaps
  if test $(cat /proc/sys/kernel/randomize_va_space) != 0; then
    echo 0 | sudo tee /proc/sys/kernel/randomize_va_space
  fi

  $CC $CFLAGS -g -fsanitize=thread -fPIE main.c libinterposed.so.tramp.S libinterposed.so.init.c $LIBS
fi

for i in $(seq 1 10); do
  LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out > a.out.log
  diff test.ref a.out.log
done

echo SUCCESS
