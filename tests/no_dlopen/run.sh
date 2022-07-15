#!/bin/sh

# Copyright 2022 Yury Gribov
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
LIBS='-ldl'

# Build shlib to test against
$CC $CFLAGS -shared -fPIC interposed.c -o libinterposed.so

##########################
# Standalone executables #
##########################

# Prepare implib
${PYTHON:-} ../../implib-gen.py -q --target $TARGET --no-dlopen libinterposed.so

# Build app
$CC $CFLAGS main.c test.c libinterposed.so.tramp.S libinterposed.so.init.c $LIBS
readelf -sW --dyn-syms a.out | grep -q GLOBAL.*foo

LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out > a.out.log
diff test.ref a.out.log

#########################################
# Standalone executables (hidden shims) #
#########################################

# Prepare implib
${PYTHON:-} ../../implib-gen.py -q --target $TARGET --no-dlopen libinterposed.so

# Build app
$CC $CFLAGS -DIMPLIB_HIDDEN_SHIMS main.c test.c libinterposed.so.tramp.S libinterposed.so.init.c $LIBS
! (readelf -sW --dyn-syms a.out | grep -q GLOBAL.*foo)

LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out > a.out.log
diff test.ref a.out.log

##########
# Shlibs #
##########

# Prepare implib
${PYTHON:-} ../../implib-gen.py -q --target $TARGET --no-dlopen libinterposed.so

# Build shlib
$CC $CFLAGS -shared -fPIC shlib.c test.c libinterposed.so.tramp.S libinterposed.so.init.c $LIBS -o shlib.so
readelf -sW --dyn-syms shlib.so | grep -q GLOBAL.*foo

# Build app
$CC $CFLAGS main.c shlib.so $LIBS

LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out > a.out.log
diff test.ref a.out.log

#########################
# Shlibs (hidden shims) #
#########################

# Prepare implib
${PYTHON:-} ../../implib-gen.py -q --target $TARGET --no-dlopen libinterposed.so

# Build shlib
$CC $CFLAGS -DIMPLIB_HIDDEN_SHIMS -shared -fPIC shlib.c test.c libinterposed.so.tramp.S libinterposed.so.init.c $LIBS -o shlib.so
! (readelf -sW --dyn-syms shlib.so | grep -q GLOBAL.*foo)

# Build app
$CC $CFLAGS main.c shlib.so $LIBS

LD_LIBRARY_PATH=.:${LD_LIBRARY_PATH:-} $INTERP ./a.out > a.out.log
diff test.ref a.out.log

echo SUCCESS
