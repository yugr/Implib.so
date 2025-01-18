/*
 * Copyright 2025 Yury Gribov
 *
 * The MIT License (MIT)
 * 
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

#include <dlfcn.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>

#include <pthread.h>
#include <unistd.h>

#include "interposed.h"

void *run(void *arg_) {
  int *arg = (int *)arg_;

  int (*foo)(int);
  switch(*arg % 10) {
    case 0:
      foo = foo0;
      break;
    case 1:
      foo = foo1;
      break;
    case 2:
      foo = foo2;
      break;
    case 3:
      foo = foo3;
      break;
    case 4:
      foo = foo4;
      break;
    case 5:
      foo = foo5;
      break;
    case 6:
      foo = foo6;
      break;
    case 7:
      foo = foo7;
      break;
    case 8:
      foo = foo8;
      break;
    case 9:
      foo = foo9;
      break;
    default:
      abort();
  }

  *arg = foo(*arg);

  return 0;
}

#define N 128

int args[N];
pthread_t tids[N];

int main() {
  int exp = 0;
  for (int i = 0; i < N; ++i) {
    args[i] = i;
    exp += i + (i % 10);
  }

  for (int i = 0; i < N; ++i) {
    if (0 != pthread_create(&tids[i], 0, run, &args[i]))
      abort();
  }

  for (int i = 0; i < N; ++i) {
    if (0 != pthread_join(tids[i], 0))
      abort();
  }

  int res = 0;
  for (int i = 0; i < N; ++i)
    res += args[i];

  if (res == exp)
    printf("Correct result\n");

  return 0;
}
