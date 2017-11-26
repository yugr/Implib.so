#!/bin/sh

# The MIT License (MIT)
# 
# Copyright (c) 2017 Yury Gribov
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
