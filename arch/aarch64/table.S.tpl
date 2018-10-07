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

#define PUSH_REG(reg) str reg, [sp,#-8]!; .cfi_adjust_cfa_offset 8; .cfi_rel_offset reg, 0
#define POP_REG(reg) ldr reg, [sp], #8; .cfi_adjust_cfa_offset -8; .cfi_restore reg

  // Slow path which calls dlsym, taken only on first call.
  // We store all registers to handle arbitrary calling conventions.
  // We don't save FPU/NEON regs, hopefully compiler isn't crazy enough to use them in resolving code.
  // For Dwarf directives, read https://www.imperialviolet.org/2017/01/18/cfi.html.

  // Stack is aligned at 16 bytes

  // Save only arguments (and lr)
  PUSH_REG(x0)
  ldr x0, [sp, #16]
  PUSH_REG(x1)
  PUSH_REG(x2)
  PUSH_REG(x3)
  PUSH_REG(x4)
  PUSH_REG(x5)
  PUSH_REG(x6)
  PUSH_REG(x7)
  PUSH_REG(x8)
  PUSH_REG(lr)

  // Stack is aligned at 16 bytes

  bl _${sym_suffix}_tramp_resolve

  POP_REG(lr)  // TODO: pop pc?
  POP_REG(x8)
  POP_REG(x7)
  POP_REG(x6)
  POP_REG(x5)
  POP_REG(x4)
  POP_REG(x3)
  POP_REG(x2)
  POP_REG(x1)
  POP_REG(x0)

  br lr

  .cfi_endproc

