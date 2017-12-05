/*
 * Copyright 2017 Yury Gribov
 *
 * The MIT License (MIT)
 * 
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

#include <stdio.h>
#include "test.h"

int main() {
  int x = foo(),
    y = bar();
  printf("Results: %x %x\n", x, y);
  return 0;
}
