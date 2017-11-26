#!/bin/sh

set -eu

cd $(dirname $0)

#CFLAGS⇔'-gdwarf-2 -O0'
CFLAGS='-DNDEBUG -O2'

# Build shlib
gcc $CFLAGS -shared -fPIC test.c -o libtest.so

# Prepare implib
../../gen-implib.py libtest.so

# Build app
gcc $CFLAGS main.c libtest.so.tramp.S libtest.so.init.c

LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:-} ./a.out
