/*
 * Copyright 2017-2018 Yury Gribov
 *
 * The MIT License (MIT)
 * 
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

#include <stdio.h>
#include "interposed.h"

void test() {
  int x, y;
  // Slow path
  x = foo(),
  y = bar();
  printf("Results: %x %x\n", x, y);
  // Fast path
  x = foo();
  y = bar();
  printf("Results: %x %x\n", x, y);
}
