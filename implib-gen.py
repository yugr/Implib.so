#!/usr/bin/python3

# Copyright 2017-2020 Yury Gribov
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
import string
import configparser

me = os.path.basename(__file__)
root = os.path.dirname(__file__)

def warn(msg):
  sys.stderr.write('%s: warning: %s\n' % (me, msg))

def error(msg):
  sys.stderr.write('%s: error: %s\n' % (me, msg))
  sys.exit(1)

def run(args, input=''):
  p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
  out, err = p.communicate(input=input.encode('utf-8'))
  out = out.decode('utf-8')
  err = err.decode('utf-8')
  if p.returncode != 0 or err:
    error("%s failed with retcode %d:\n%s" % (args[0], p.returncode, err))
  return out, err

def collect_syms(f):
  out, err = run(["readelf", "-W", "--dyn-syms", f])

  toc = None
  syms = []
  for line in out.splitlines():
    line = line.strip()
    if not line:
      continue
    words = re.split(r' +', line)
    if line.startswith('Num'):  # Header?
      if toc is not None:
        error("multiple headers in output of readelf")
      toc = {}
      for i, n in enumerate(words):
        # Colons are different across readelf versions so get rid of them.
        n = n.replace(':', '')
        toc[i] = n
    elif toc is not None:
      sym = {k: (words[i] if i < len(words) else '') for i, k in toc.items()}
      name = sym['Name']
      if '@' in name:
        sym['Default'] = '@@' in name
        name, ver = re.split(r'@+', name)
        sym['Name'] = name
        sym['Version'] = ver
      else:
        sym['Default'] = True
        sym['Version'] = None
      syms.append(sym)

  if toc is None:
    error("failed to analyze %s" % f)

  # Also collected demangled names
  if syms:
    out, err = run(['c++filt'], '\n'.join((sym['Name'] for sym in syms)))
    for i, name in enumerate(out.split("\n")):
      syms[i]['Demangled Name'] = name

  return syms

def main():
  parser = argparse.ArgumentParser(description="Generate wrappers for shared library functions.")
  parser.add_argument('library',
                      metavar='LIB',
                      help="Library to be wrapped.")
  parser.add_argument('--verbose', '-v',
                      help="Print diagnostic info.",
                      action='count',
                      default=0)
  parser.add_argument('--dlopen-callback',
                      help="Call user-provided custom callback to dlopen library.",
                      default='')
  parser.add_argument('--no-dlopen',
                      help="Do not emit dlopen call (user must load library himself).",
                      action='store_true')
  parser.add_argument('--library-load-name',
                      help="Use custom name for dlopened library (default is LIB).")
  parser.add_argument('--no-lazy-load',
                      help="Load library at program start (by default library is loaded on first call to one of it's functions).",
                      action='store_true')
  parser.add_argument('--target',
                      help="Target platform triple e.g. x86_64-unknown-linux-gnu or arm-none-eabi (atm x86_64, i[0-9]86, arm/armhf and aarch64 are supported).",
                      default='x86_64')
  parser.add_argument('--symbol-list',
                      help="Path to file with symbols that should be present in wrapper (all by default).")
  parser.add_argument('--symbol-prefix',
                      metavar='PFX',
                      help="Prefix wrapper symbols with PFX.",
                      default='')
  parser.add_argument('-q', '--quiet',
                      help="Do not print progress info.",
                      action='store_true')
  parser.add_argument('--outdir', '-o',
                      help="Path to create wrapper at",
                      default='./')

  args = parser.parse_args()

  input_name = args.library
  verbose = args.verbose
  dlopen_callback = args.dlopen_callback
  no_dlopen = args.no_dlopen
  lazy_load = not args.no_lazy_load
  load_name = args.library_load_name if args.library_load_name is not None else os.path.basename(input_name)
  if args.target.startswith('arm'):
    target = 'arm'  # Handle armhf-...
  elif re.match(r'^i[0-9]86', args.target):
      target = 'i386'
  else:
    target = args.target.split('-')[0]
  quiet = args.quiet
  outdir = args.outdir

  if args.symbol_list is None:
    funs = None
  else:
    with open(args.symbol_list, 'r') as f:
      funs = []
      for line in re.split(r'\r?\n', f.read()):
        line = re.sub(r'#.*', '', line)
        line = line.strip()
        if line:
          funs.append(line)

  # Collect target info

  target_dir = os.path.join(root, 'arch', target)

  if not os.path.exists(target_dir):
    error("unknown architecture '%s'" % target)

  cfg = configparser.ConfigParser(inline_comment_prefixes=';')
  cfg.read(target_dir + '/config.ini')

  ptr_size = int(cfg['Arch']['PointerSize'])

  orig_syms = collect_syms(input_name)

  def is_public(s):
    return (s['Type'] != 'LOCAL'
            and s['Ndx'] != 'UND'
            and s['Name'] not in ['', '_init', '_fini'])

  # Collect functions
  # TODO: detect public data symbols and issue warning

  if funs is None:

    def is_public_fun(s):
      return s['Type'] == 'FUNC' and is_public(s)
    orig_funs = list(filter(is_public_fun, orig_syms))

    funs = []
    warn_versioned = False
    for s in orig_funs:
      if s['Version'] is not None:
        # TODO: support versions
        if not warn_versioned:
          warn("library %s contains versioned symbols which are NYI" % input_name)
          warn_versioned = True
        if verbose:
          print("Skipping versioned symbol %s" % s['Name'])
        continue
      funs.append(s['Name'])

    if not funs and not quiet:
      print("no public functions were found in %s" % input_name)

  if verbose:
    print("Exported functions:")
    for i, fun in enumerate(funs):
      print("  {0}: {1}".format(i, fun))

  # Collect vtables

  vtabs = {}

  for s in orig_syms:
    m = re.match(r'^(vtable|typeinfo|typeinfo name) for (.*)', s['Demangled Name'])
    if m is not None and is_public(s):
      typ, cls = m.groups()
      vtabs.setdefault(cls, {})[typ] = s

  # TODO: collect vtable raw contents and relocations

  if verbose:
    print("Exported vtables:")
    for i, (cls, _) in enumerate(sorted(vtabs.items())):
      print("  {0}: {1}".format(i, cls))

  # Generate assembly code

  suffix = os.path.basename(load_name)
  lib_suffix = re.sub(r'[^a-zA-Z_0-9]+', '_', suffix)

  tramp_file = '%s.tramp.S' % suffix
  with open(os.path.join(outdir, tramp_file), 'w') as f:
    if not quiet:
      print("Generating %s..." % tramp_file)
    with open(target_dir + '/table.S.tpl', 'r') as t:
      table_text = string.Template(t.read()).substitute(
        lib_suffix=lib_suffix,
        table_size=ptr_size*(len(funs) + 1))
    f.write(table_text)

    with open(target_dir + '/trampoline.S.tpl', 'r') as t:
      tramp_tpl = string.Template(t.read())

    for i, name in enumerate(funs):
      tramp_text = tramp_tpl.substitute(
        lib_suffix=lib_suffix,
        sym=args.symbol_prefix + name,
        offset=i*ptr_size,
        number=i)
      f.write(tramp_text)

  # Generate C code

  init_file = '%s.init.c' % suffix
  with open(os.path.join(outdir, init_file), 'w') as f:
    if not quiet:
      print("Generating %s..." % init_file)
    with open(os.path.join(root, 'arch/common/init.c.tpl'), 'r') as t:
      init_text = string.Template(t.read()).substitute(
        lib_suffix=lib_suffix,
        load_name=load_name,
        dlopen_callback=dlopen_callback,
        has_dlopen_callback=int(bool(dlopen_callback)),
        no_dlopen=int(no_dlopen),
        lazy_load=int(lazy_load),
        sym_names=',\n  '.join('"%s"' % name for name in funs))
    f.write(init_text)

if __name__ == '__main__':
  main()
