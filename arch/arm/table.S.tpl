/*
 * Copyright 2018-2019 Yury Gribov
 *
 * The MIT License (MIT)
 *
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

  .data

  .globl _${sym_suffix}_tramp_table
  .hidden _${sym_suffix}_tramp_table
_${sym_suffix}_tramp_table:
  .zero $table_size

  .text

  .globl _${sym_suffix}_tramp_resolve
  .hidden _${sym_suffix}_tramp_resolve

  .globl _${sym_suffix}_save_regs_and_resolve
  .hidden _${sym_suffix}_save_regs_and_resolve
_${sym_suffix}_save_regs_and_resolve:
  .cfi_startproc

#define PUSH_REG(reg) push {reg}; .cfi_adjust_cfa_offset 4; .cfi_rel_offset reg, 0
#define POP_REG(reg) pop {reg} ; .cfi_adjust_cfa_offset -4; .cfi_restore reg

  // Slow path which calls dlsym, taken only on first call.
  // We store all registers to handle arbitrary calling conventions.
  // We don't save FPU/NEON regs, hopefully compiler isn't crazy enough to use them in resolving code.
  // For Dwarf directives, read https://www.imperialviolet.org/2017/01/18/cfi.html.

  // Stack is aligned at 16 bytes at this point

  // Save only arguments (and lr)
  PUSH_REG(r0)
  ldr r0, [sp, #8]
  PUSH_REG(r1)
  PUSH_REG(r2)
  PUSH_REG(r3)
  PUSH_REG(lr)
  PUSH_REG(lr)  // Align to 8 bytes

  bl _${sym_suffix}_tramp_resolve(PLT)

  POP_REG(lr)  // TODO: pop pc?
  POP_REG(lr)
  POP_REG(r3)
  POP_REG(r2)
  POP_REG(r1)
  POP_REG(r0)

  bx lr

  .cfi_endproc

