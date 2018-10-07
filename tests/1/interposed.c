/*
 * Copyright 2017 Yury Gribov
 *
 * The MIT License (MIT)
 * 
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

#include <stdio.h>
#include "interposed.h"

__attribute__((visibility("default")))
int foo(void) {
  printf("Calling foo from libtest\n");
  return 0xf00;
}

__attribute__((visibility("default")))
int bar(void) {
  printf("Calling bar from libtest\n");
  return 0xba7;
}
