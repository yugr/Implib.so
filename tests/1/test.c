#include <stdio.h>
#include "test.h"

int foo(void) {
  printf("Calling foo from libtest\n");
  return 0xf00;
}

int bar(void) {
  printf("Calling bar from libtest\n");
  return 0xba7;
}
