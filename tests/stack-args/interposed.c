/*
 * Copyright 2024 Yury Gribov
 *
 * The MIT License (MIT)
 * 
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

#include <stdio.h>
#include "interposed.h"

__attribute__((visibility("default")))
void foo(int x0, int x1, int x2, int x3, int x4, int x5, int x6, int x7, int x8, int x9, int x10, int x11, int x12, int x13, int x14, int x15) {
  printf("%d ", x0);
  printf("%d ", x1);
  printf("%d ", x2);
  printf("%d ", x3);
  printf("%d ", x4);
  printf("%d ", x5);
  printf("%d ", x6);
  printf("%d ", x7);
  printf("%d ", x8);
  printf("%d ", x9);
  printf("%d ", x10);
  printf("%d ", x11);
  printf("%d ", x12);
  printf("%d ", x13);
  printf("%d ", x14);
  printf("%d\n", x15);
}
