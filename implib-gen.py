#!/usr/bin/python3

# Copyright 2017-2018 Yury Gribov
#
# The MIT License (MIT)
#
# Use of this source code is governed by MIT license that can be
# found in the LICENSE.txt file.

import sys
import os.path
import re
import subprocess
import argparse

me = os.path.basename(__file__)

def warn(msg):
  sys.stderr.write('%s: warning: %s\n' % (me, msg))

def error(msg):
  sys.stderr.write('%s: error: %s\n' % (me, msg))
  sys.exit(1)

def main():
  parser = argparse.ArgumentParser(description="Generate wrappers for shared library functions.")
  parser.add_argument('library', metavar='LIB', help="Library to be wrapped.")
  parser.add_argument('--verbose', '-v', action='count', help="Print diagnostic info.", default=0)
  parser.add_argument('--dlopen-callback', help="Call user-provided custom callback to dlopen library.", default='')
  parser.add_argument('--no-dlopen', help="Do not emit dlopen call (user must load library himself).", action='store_true')
  parser.add_argument('--library-load-name', help="Use custom name for dlopened library (default is LIB).")
  parser.add_argument('--no-lazy-load', help="Load library at program start (by default library is loaded on first call to one of it's functions).", action='store_true')

  args = parser.parse_args()

  input_name = args.library
  verbose = args.verbose
  dlopen_callback = args.dlopen_callback
  no_dlopen = args.no_dlopen
  lazy_load = not args.no_lazy_load
  load_name = args.library_load_name if args.library_load_name is not None else os.path.basename(input_name)

  ptr_size = 8  # TODO: parameterize

  # Get info from readelf

  p = subprocess.Popen(["readelf", "-sDW", input_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  (out, err) = p.communicate()
  out = out.decode('utf-8')
  err = err.decode('utf-8')
  if p.returncode != 0 or err:
    error("readelf failed with retcode %d: %s" % (p.returncode, err))

  hdr = None
  syms = []
  warn_versioned = False
  for line in out.splitlines():
    line = line.strip()
    if not line:
      continue
    words = re.split(r' +', line)
    if line.startswith('Num'):  # Header?
      if hdr is not None:
        error("multiple headers in output of readelf")
      hdr = {}
      for i, n in enumerate(words):
        # Colons are different across readelf versions so get rid of them.
        n = n.replace(':', '')
        hdr[i] = n
    elif hdr is not None:
      sym = {(k, words[i]) for i, k in hdr.items()}
      if sym['Name'].find('@') >= 0:
        name, ver = sym['Name'].split('@')
        sym['Name'] = name
        sym['Version'] = ver
        if not warn_versioned:
          # TODO
          warn("library %s contains versioned symbols which are NYI" % input_name)
          warn_versioned = True
          continue
      else:
        sym['Version'] = None
#      for k, v in dict(sym).items():
#        if k in ['Num', 'Buc', 'Size', 'Ndx'] and v is not None:
#          sym[k] = int(v)
      syms.append(sym)

  def is_public_fun(s):
    return (s['Type'] == 'FUNC'
      and s['Type'] != 'LOCAL'
      and s['Ndx'] != 'UND'
      and s['Name'] not in ['_init', '_fini'])

  # TODO: detect public data symbols and issue warning

  funs = list(filter(is_public_fun, syms))

  suffix = os.path.basename(load_name)
  sym_suffix = re.sub(r'[^a-zA-Z_0-9]+', '_', suffix)

  if verbose:
    print("Extracted functions from {0}:".format(load_name))
    for i, fun in enumerate(funs):
      print("{0}: {1}".format(i, str(fun)))

  # Generate trampoline code
  # TODO: support PIC code

  tramp_file = '%s.tramp.S' % suffix
  with open(tramp_file, 'w') as f:
    print("Generating %s..." % tramp_file)
    # TODO: pusha/popa will puzzle gdb (add DWARF directives)
    # TODO: we may move code below to a function to save space and L1i.
    print('''\
  .data

  .globl _{0}_tramp_table
_{0}_tramp_table:
  .zero {1}

  .text

#define PUSH_REG(reg) pushq %reg ; .cfi_adjust_cfa_offset 8; .cfi_rel_offset reg, 0
#define POP_REG(reg) popq %reg ; .cfi_adjust_cfa_offset -8; .cfi_restore reg

  // Slow path which calls dlsym, taken only on first call.
  // We store all registers to handle arbitrary calling conventions.
  // We don't save XMM regs, hopefully compiler isn't crazy enough to use them in resolving code.
  // For Dwarf directives, read https://www.imperialviolet.org/2017/01/18/cfi.html.
save_regs_and_resolve:
  .cfi_startproc

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

  call _{0}_tramp_resolve  // Stack will be aligned at 16 in call

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
'''.format(sym_suffix, ptr_size*(len(funs) + 1)), file=f)

    for i, sym in enumerate(funs):
      # Intel opt. manual says to
      # "make the fall-through code following a conditional branch be the likely target for a branch with a forward target"
      # to hint static predictor.
      print('''\
  .globl {1}
{1}:
  .cfi_startproc
  cmp $0, _{0}_tramp_table+{2}(%rip)
  je 2f
1:
  jmp *_{0}_tramp_table+{2}
2:
  pushq ${3}
  .cfi_adjust_cfa_offset 8
  call save_regs_and_resolve
  addq $8, %rsp
  .cfi_adjust_cfa_offset -8
  jmp 1b
  .cfi_endproc
'''.format(sym_suffix, sym['Name'], i*ptr_size, i), file=f)

  init_file = '%s.init.c' % suffix
  with open(init_file, 'w') as f:
    print("Generating %s..." % init_file)
    print('''\
#include <dlfcn.h>
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>

#define CHECK(cond, fmt, ...) do {{ \\
    if(!(cond)) {{ \\
      fprintf(stderr, "implib-gen: " fmt "\\n", ##__VA_ARGS__); \\
      exit(1); \\
    }} \\
  }} while(0)

#define CALL_USER_CALLBACK {3}
#define NO_DLOPEN {4}
#define LAZY_LOAD {5}

static void *lib_handle;

static void *load_library() {{
  if(lib_handle)
    return lib_handle;

  // TODO: dlopen and users callback must be protected w/ critical section (to avoid dlopening lib twice)
#if NO_DLOPEN
  CHECK(0, "internal error"); // We shouldn't get here
#elif CALL_USER_CALLBACK
  extern void *{2}(const char *lib_name);
  lib_handle = {2}("{1}");
  CHECK(lib_handle, "callback '{2}' failed to load library");
#else
  lib_handle = dlopen("{1}", RTLD_LAZY | RTLD_GLOBAL);
  CHECK(lib_handle, "failed to load library '{1}': %s", dlerror());
#endif

  return lib_handle;
}}

#if ! NO_DLOPEN && ! LAZY_LOAD
static void __attribute__((constructor)) load_lib() {{
  load_library();
}}
#endif

static void __attribute__((destructor)) unload_lib() {{
  if(lib_handle)
    dlclose(lib_handle);
}}

// TODO: convert to single 0-separated string
static const char *const sym_names[] = {{'''.format(sym_suffix,
                                                    load_name,
                                                    dlopen_callback,
                                                    int(bool(dlopen_callback)),
                                                    int(no_dlopen),
                                                    int(lazy_load)), file=f)

    for sym in funs:
      print('  "%s",' % sym['Name'], file=f)

    print('''\
  0,
}};

extern void *_{0}_tramp_table[];

// Can be sped up by manually parsing library symtab...
void _{0}_tramp_resolve(int i) {{
  assert(i < sizeof(sym_names) / sizeof(sym_names[0]) - 1);

  void *h = 0;
#if NO_DLOPEN
  // FIXME: instead of RTLD_NEXT we should search for loaded lib_handle
  // as in https://github.com/jethrogb/ssltrace/blob/bf17c150a7/ssltrace.cpp#L74-L112
  h = RTLD_NEXT;
#elif LAZY_LOAD
  h = load_library();
#else
  h = lib_handle;
  CHECK(h, "failed to resolve symbol '%s': library '{1}' was not loaded", sym_names[i]);
#endif

  // Dlsym is thread-safe so don't need to protect it.
  _{0}_tramp_table[i] = dlsym(h, sym_names[i]);
  CHECK(_{0}_tramp_table[i], "failed to resolve symbol '%s' in library '{1}'", sym_names[i]);
}}

// Helper for user to resolve all symbols
void _{0}_tramp_resolve_all(void) {{
  int i;
  for(i = 0; i < sizeof(sym_names) / sizeof(sym_names[0]) - 1; ++i)
    _{0}_tramp_resolve(i);
}} '''.format(sym_suffix,
              load_name), file=f)

if __name__ == '__main__':
  main()
