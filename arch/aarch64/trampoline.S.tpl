  .globl $sym
  .p2align 4
$sym:
  .cfi_startproc

1:
  // Load address
  // TODO: can we do this faster on newer ARMs?
  adrp ip0, _${sym_suffix}_tramp_table+$offset
  ldr ip0, [ip0, #:lo12:_${sym_suffix}_tramp_table+$offset]
 
  cbz ip0, 2f

  // Fast path
  br ip0

2:
  // Slow path
  mov ip0, $number
  str ip0, [sp, #-8]!
  .cfi_adjust_cfa_offset 8
  PUSH_REG(lr)
  bl _${sym_suffix}_save_regs_and_resolve
  POP_REG(lr)
  add sp, sp, #8
  .cfi_adjust_cfa_offset -8
  b 1b
  .cfi_endproc

