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

#define PUSH_REG(reg) pushq %reg ; .cfi_adjust_cfa_offset 8; .cfi_rel_offset reg, 0
#define POP_REG(reg) popq %reg ; .cfi_adjust_cfa_offset -8; .cfi_restore reg

  // Slow path which calls dlsym, taken only on first call.
  // We store all registers to handle arbitrary calling conventions.
  // We don't save XMM regs, hopefully compiler isn't crazy enough to use them in resolving code.
  // For Dwarf directives, read https://www.imperialviolet.org/2017/01/18/cfi.html.

  PUSH_REG(rdi)
  mov 0x10(%rsp), %rdi
  PUSH_REG(rax)
  PUSH_REG(rbx)
  PUSH_REG(rcx)
  PUSH_REG(rdx)
  PUSH_REG(rbp)
  PUSH_REG(rsi)
  PUSH_REG(r8)
  PUSH_REG(r9)
  PUSH_REG(r10)
  PUSH_REG(r11)
  PUSH_REG(r12)
  PUSH_REG(r13)
  PUSH_REG(r14)
  PUSH_REG(r15)

  call _${sym_suffix}_tramp_resolve  // Stack will be aligned at 16 in call

  POP_REG(r15)
  POP_REG(r14)
  POP_REG(r13)
  POP_REG(r12)
  POP_REG(r11)
  POP_REG(r10)
  POP_REG(r9)
  POP_REG(r8)
  POP_REG(rsi)
  POP_REG(rbp)
  POP_REG(rdx)
  POP_REG(rcx)
  POP_REG(rbx)
  POP_REG(rax)
  POP_REG(rdi)

  ret

  .cfi_endproc

