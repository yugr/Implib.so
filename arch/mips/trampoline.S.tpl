/*
 * Copyright 2022 Yury Gribov
 *
 * The MIT License (MIT)
 *
 * Use of this source code is governed by MIT license that can be
 * found in the LICENSE.txt file.
 */

  .globl $sym
  .p2align 4
  .type $sym, %function
#ifndef IMPLIB_EXPORT_SHIMS
  .hidden $sym
#endif
$sym:
  .cfi_startproc

  .set noreorder
  .cpload $$25
  .set nomacro
  .set noat

1:
  // Load address
  lw $$AT, %got(_${lib_suffix}_tramp_table)($$gp)
  lw $$AT, $offset($$AT)

  beq $$AT, $$0, 3f
  nop

2:
  // Fast path
  j $$AT
  move $$25, $$AT

3:
  // Slow path

  PUSH_REG($$25)
  PUSH_REG($$ra)

  // Reserve space for 4 operands according to ABI
  addiu $$sp, $$sp, -16; .cfi_adjust_cfa_offset 16

  li $$AT, $number
  lw $$25, %call16(_${lib_suffix}_save_regs_and_resolve)($$gp)
  .reloc  4f, R_MIPS_JALR, _${lib_suffix}_save_regs_and_resolve
4: jalr $$25
  nop

  addiu $$sp, $$sp, 16; .cfi_adjust_cfa_offset -16

  POP_REG($$ra)
  POP_REG($$25)

  j 1b
  nop

  .set macro
  .set reorder

  .cfi_endproc
