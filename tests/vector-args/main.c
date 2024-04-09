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

#if VECTOR_SIZE == 1
# define VECTOR_INIT {1}
#elif VECTOR_SIZE == 2
# define VECTOR_INIT {1, 2}
#elif VECTOR_SIZE == 4
# define VECTOR_INIT {1, 2, 3, 4}
#elif VECTOR_SIZE == 8
# define VECTOR_INIT {1, 2, 3, 4, 5, 6, 7, 8}
#elif VECTOR_SIZE == 16
# define VECTOR_INIT {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}
#else
# error "Unsupported vector size"
#endif

int main() {
  vector_type x = VECTOR_INIT, res = foo(x), ref = 3 * x;
  int i;
  for (i = 0; i < VECTOR_SIZE; ++i) {
    if (res[i] != ref[i]) {
      printf("NOT OK\n");
      return 1;
    }
  }
  return 0;
}
