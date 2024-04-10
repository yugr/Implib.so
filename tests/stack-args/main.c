/*
 * Copyright 2024 Yury Gribov
 *
 * The MIT License (MIT)
 * 
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

#include "interposed.h"

#include <string.h>
#include <stdio.h>

int main(int argc, char *argv[]) {
  if (argc != 2)
    return 1;

  if (0 == strcmp(argv[1], "int")) {
    foo(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  } else if (0 == strcmp(argv[1], "float")) {
    bar(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15);
  } else {
    fprintf(stderr, "Invalid option: %s\n", argv[1]);
    return 1;
  }

  return 0;
}
