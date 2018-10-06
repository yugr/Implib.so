  .globl $sym
  .p2align 4
$sym:
  .cfi_startproc
  // Intel opt. manual says to
  // "make the fall-through code following a conditional branch be the likely target for a branch with a forward target"
  // to hint static predictor.
  cmp $$0, _${sym_suffix}_tramp_table+$offset(%rip)
  je 2f
1:
  jmp *_${sym_suffix}_tramp_table+$offset(%rip)
2:
  pushq $$$number
  .cfi_adjust_cfa_offset 8
  call _${sym_suffix}_save_regs_and_resolve
  addq $$8, %rsp
  .cfi_adjust_cfa_offset -8
  jmp 1b
  .cfi_endproc

