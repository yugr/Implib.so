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

__attribute__((visibility("default")))
void bar(float x0, float x1, float x2, float x3, float x4, float x5, float x6, float x7, float x8, float x9, float x10, float x11, float x12, float x13, float x14, float x15) {
  printf("%g ", x0);
  printf("%g ", x1);
  printf("%g ", x2);
  printf("%g ", x3);
  printf("%g ", x4);
  printf("%g ", x5);
  printf("%g ", x6);
  printf("%g ", x7);
  printf("%g ", x8);
  printf("%g ", x9);
  printf("%g ", x10);
  printf("%g ", x11);
  printf("%g ", x12);
  printf("%g ", x13);
  printf("%g ", x14);
  printf("%g\n", x15);
}
