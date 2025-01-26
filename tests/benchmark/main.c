/*
 * Copyright 2025 Yury Gribov
 *
 * The MIT License (MIT)
 * 
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

#include "interposed.h"

#define NITER 1000000000L

int main() {
  for (long i = 0; i < NITER; ++i)
#ifdef BASELINE
    asm volatile("");
#else
    foo();
#endif

  return 0;
}
