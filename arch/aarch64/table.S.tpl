/*
 * Copyright 2018-2019 Yury Gribov
 *
 * The MIT License (MIT)
 *
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

  .data

  .globl _${lib_suffix}_tramp_table
  .hidden _${lib_suffix}_tramp_table
_${lib_suffix}_tramp_table:
  .zero $table_size

  .text

  .globl _${lib_suffix}_tramp_resolve
  .hidden _${lib_suffix}_tramp_resolve

  .globl _${lib_suffix}_save_regs_and_resolve
  .hidden _${lib_suffix}_save_regs_and_resolve
_${lib_suffix}_save_regs_and_resolve:
  .cfi_startproc

  // Slow path which calls dlsym, taken only on first call.
  // All registers are stored to handle arbitrary calling conventions
  // (except FPU/NEON regs in hope they are not used in resolving code).
  // For Dwarf directives, read https://www.imperialviolet.org/2017/01/18/cfi.html.

  // Stack is aligned at 16 bytes

  // Save only arguments (and lr)
  stp x0, x1, [sp, #-16]!; .cfi_adjust_cfa_offset 16; .cfi_rel_offset x0, 0; .cfi_rel_offset x1, 8
  stp x2, x3, [sp, #-16]!; .cfi_adjust_cfa_offset 16; .cfi_rel_offset x2, 0; .cfi_rel_offset x3, 8
  stp x4, x5, [sp, #-16]!; .cfi_adjust_cfa_offset 16; .cfi_rel_offset x4, 0; .cfi_rel_offset x5, 8
  stp x6, x7, [sp, #-16]!; .cfi_adjust_cfa_offset 16; .cfi_rel_offset x6, 0; .cfi_rel_offset x7, 8
  stp x8, lr, [sp, #-16]!; .cfi_adjust_cfa_offset 16; .cfi_rel_offset x8, 0; .cfi_rel_offset lr, 8
  ldr x0, [sp, #80]

  // Stack is aligned at 16 bytes

  bl _${lib_suffix}_tramp_resolve

  // TODO: pop pc?
  ldp x8, lr, [sp], #16; .cfi_adjust_cfa_offset -16; .cfi_restore lr; .cfi_restore x8
  ldp x6, x7, [sp], #16; .cfi_adjust_cfa_offset -16; .cfi_restore x7; .cfi_restore x6
  ldp x4, x5, [sp], #16; .cfi_adjust_cfa_offset -16; .cfi_restore x5; .cfi_restore x4
  ldp x2, x3, [sp], #16; .cfi_adjust_cfa_offset -16; .cfi_restore x3; .cfi_restore x2
  ldp x0, x1, [sp], #16; .cfi_adjust_cfa_offset -16; .cfi_restore x1; .cfi_restore x0

  br lr

  .cfi_endproc

