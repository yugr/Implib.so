/*
 * Copyright 2023 Yury Gribov
 *
 * The MIT License (MIT)
 * 
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

extern int foo8192();

int main() {
  return foo8192() == 8192 ? 0 : 1;
}
