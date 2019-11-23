/*
 * Copyright 2019 Yury Gribov
 *
 * The MIT License (MIT)
 *
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

  .globl $sym
  .p2align 4
$sym:
  .cfi_startproc
  // x86 has no support for PC-relative addressing so code is not very efficient.
  // We also trash EAX here (it's call-clobbered in cdecl).
  call __implib.x86.get_pc_thunk.ax
  addl $$_GLOBAL_OFFSET_TABLE_, %eax
  movl $offset+_${lib_suffix}_tramp_table@GOTOFF(%eax), %eax
  cmp $$0, %eax
  je 2f
1:
  jmp *%eax
2:
  mov $$$number, %eax
  call _${lib_suffix}_save_regs_and_resolve
  jmp $sym
  .cfi_endproc
