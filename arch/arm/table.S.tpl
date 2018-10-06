  .data

  .globl _${sym_suffix}_tramp_table
_${sym_suffix}_tramp_table:
  .zero $table_size

  .text

#define PUSH_REG(reg) push {reg}; .cfi_adjust_cfa_offset 4; .cfi_rel_offset reg, 0
#define POP_REG(reg) pop {reg} ; .cfi_adjust_cfa_offset -4; .cfi_restore reg

  // Slow path which calls dlsym, taken only on first call.
  // We store all registers to handle arbitrary calling conventions.
  // We don't save XMM regs, hopefully compiler isn't crazy enough to use them in resolving code.
  // For Dwarf directives, read https://www.imperialviolet.org/2017/01/18/cfi.html.
save_regs_and_resolve:
  .cfi_startproc

  PUSH_REG(r0)
  ldr r0, [sp, #8]
  PUSH_REG(r1)
  PUSH_REG(r2)
  PUSH_REG(r3)
  PUSH_REG(r4)
  PUSH_REG(r5)
  PUSH_REG(r6)
  PUSH_REG(r7)
  PUSH_REG(r8)
  PUSH_REG(r9)
  PUSH_REG(r10)
  PUSH_REG(r11)
  PUSH_REG(lr)
  PUSH_REG(lr)  // Align to 8 bytes

  bl _${sym_suffix}_tramp_resolve(PLT)

  POP_REG(lr)
  POP_REG(lr)
  POP_REG(r11)
  POP_REG(r10)
  POP_REG(r9)
  POP_REG(r8)
  POP_REG(r7)
  POP_REG(r6)
  POP_REG(r5)
  POP_REG(r4)
  POP_REG(r3)
  POP_REG(r2)
  POP_REG(r1)
  POP_REG(r0)

  bx lr

  .cfi_endproc

