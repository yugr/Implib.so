/*
 * Copyright 2025 Yury Gribov
 *
 * The MIT License (MIT)
 * 
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

#include <stdio.h>
#include "interposed.h"

__attribute__((visibility("default")))
int foo0(int x) {
  return x + 0;
}

__attribute__((visibility("default")))
int foo1(int x) {
  return x + 1;
}

__attribute__((visibility("default")))
int foo2(int x) {
  return x + 2;
}

__attribute__((visibility("default")))
int foo3(int x) {
  return x + 3;
}

__attribute__((visibility("default")))
int foo4(int x) {
  return x + 4;
}

__attribute__((visibility("default")))
int foo5(int x) {
  return x + 5;
}

__attribute__((visibility("default")))
int foo6(int x) {
  return x + 6;
}

__attribute__((visibility("default")))
int foo7(int x) {
  return x + 7;
}

__attribute__((visibility("default")))
int foo8(int x) {
  return x + 8;
}

__attribute__((visibility("default")))
int foo9(int x) {
  return x + 9;
}
