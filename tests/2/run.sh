#!/bin/sh

# Copyright 2019 Yury Gribov
#
# The MIT License (MIT)
# 
# Use of this source code is governed by MIT license that can be
# found in the LICENSE.txt file.

# This test checks that exceptions are successfully propagated
# through implib wrappers.

cd $(dirname $0)

export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH

g++ -shared -fPIC interposed.cpp -o libinterposed.so
g++ main.cpp -L. -linterposed
./a.out 2>&1 | tee ref.log

../../implib-gen.py -q libinterposed.so
g++ main.cpp libinterposed.so.tramp.S libinterposed.so.init.c -ldl
./a.out 2>&1 | tee new.log

if ! diff ref.log new.log; then
  echo "Exceptions do NOT propagate through implibs"
  exit 1
fi
