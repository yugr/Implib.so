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
  move $$25, $$AT
  j $$AT
  nop

3:
  // Slow path

  addiu $$sp, $$sp, -4; .cfi_adjust_cfa_offset 4
  sw $$25, 4($$sp); .cfi_rel_offset $$25, 0
  addiu $$sp, $$sp, -4; .cfi_adjust_cfa_offset 4
  sw $$ra, 4($$sp); .cfi_rel_offset $$ra, 0

  li $$AT, $number
  lw $$25, %call16(_${lib_suffix}_save_regs_and_resolve)($$gp)
  .reloc  4f, R_MIPS_JALR, _${lib_suffix}_save_regs_and_resolve
4: jalr $$25
  nop

  addiu $$sp, $$sp, 4; .cfi_adjust_cfa_offset 4
  lw $$ra, 0($$sp); .cfi_restore $$ra, 0
  addiu $$sp, $$sp, 4; .cfi_adjust_cfa_offset 4
  lw $$25, 0($$sp); .cfi_restore $$25

  j 1b
  nop

  .set macro
  .set reorder

  .cfi_endproc
