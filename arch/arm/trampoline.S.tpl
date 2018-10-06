  .globl $sym
$sym:
  .cfi_startproc

1:
  // Load address
  // TODO: can we do this faster on newer ARMs?
  ldr ip, ${sym}_offset
${sym}_dummy:
  add ip, pc, ip
  ldr ip, [ip, #$offset]

  cmp ip, #0

  // Fast path
  bxne ip

  // Slow path
  ldr ip, =$number
  push {ip}
  .cfi_adjust_cfa_offset 4
  PUSH_REG(lr)
  bl save_regs_and_resolve
  POP_REG(lr)
  add sp, #4
  .cfi_adjust_cfa_offset -4
  b 1b
  .cfi_endproc

${sym}_offset:
  .word _${sym_suffix}_tramp_table - (${sym}_dummy + 8)

