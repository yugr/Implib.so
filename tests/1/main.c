#include <stdio.h>
#include "test.h"

int main() {
  int x = foo(),
    y = bar();
  printf("Results: %x %x\n", x, y);
  return 0;
}
