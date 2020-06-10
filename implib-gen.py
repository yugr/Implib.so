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
  """Emits a nicely-decorated warning."""
  sys.stderr.write('%s: warning: %s\n' % (me, msg))

def error(msg):
  """Emits a nicely-decorated error and exits."""
  sys.stderr.write('%s: error: %s\n' % (me, msg))
  sys.exit(1)

def run(args, input=''):
  """Runs external program and aborts on error."""
  p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE)
  out, err = p.communicate(input=input.encode('utf-8'))
  out = out.decode('utf-8')
  err = err.decode('utf-8')
  if p.returncode != 0 or err:
    error("%s failed with retcode %d:\n%s" % (args[0], p.returncode, err))
  return out, err

def make_toc(words):
  return {i: n for i, n in enumerate(words)}

def parse_row(words, toc, hex_keys):
  vals = {k: (words[i] if i < len(words) else '') for i, k in toc.items()}
  for k in hex_keys:
    if vals[k]:
      vals[k] = int(vals[k], 16)
  return vals

def collect_syms(f):
  """Collect ELF dynamic symtab."""

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
      # Colons are different across readelf versions so get rid of them.
      toc = make_toc(map(lambda n: n.replace(':', ''), words))
    elif toc is not None:
      sym = parse_row(words, toc, ['Value'])
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

def collect_relocs(f):
  """Collect ELF dynamic relocs."""

  out, err = run(["readelf", "-r", f])

  toc = None
  rels = []
  for line in out.splitlines():
    line = line.strip()
    if not line:
      continue
    if re.match(r'^\s*Offset', line):  # Header?
      if toc is not None:
        error("multiple headers in output of readelf")
      words = re.split(r'\s\s+', line)  # "Sym. Name + Addend"
      toc = make_toc(words)
    elif toc is not None:
      line = re.sub(r' \+ ', '+', line)
      words = re.split(r'\s+', line)
      rel = parse_row(words, toc, ['Offset', 'Info'])
      rels.append(rel)
      # Split symbolic representation
      sym_name = 'Sym. Name + Addend'
      if rel[sym_name]:
        p = rel[sym_name].split('+')
        if len(p) == 1:
          p = ['', p[0]]
        rel[sym_name] = (p[0], int(p[1], 16))

  if toc is None:
    error("failed to analyze %s" % f)

  return rels

def collect_sections(f):
  """Collect section info from ELF."""

  out, err = run(["readelf", "-SW", f])

  toc = None
  sections = []
  for line in out.splitlines():
    line = line.strip()
    if not line:
      continue
    line = re.sub(r'\[\s+', '[', line)
    words = re.split(r' +', line)
    if line.startswith('[Nr]'):  # Header?
      if toc is not None:
        error("multiple headers in output of readelf")
      toc = make_toc(words)
    elif line.startswith('[') and toc is not None:
      sec = parse_row(words, toc, ['Address', 'Off', 'Size'])
      if 'A' in sec['Flg']:  # Allocatable section?
        sections.append(sec)

  if toc is None:
    error("failed to analyze %s" % f)

  return sections

def read_unrelocate_data(f, chunks):
  """Collect unrelocated data from ELF."""

  secs = collect_sections(f)
  secs.sort(key=lambda s: s['Address'])

  # TODO: read bytes for each chunk (via -x)
  data = []

  return data

def main():
  parser = argparse.ArgumentParser(description="Generate wrappers for shared library functions.",
                                   formatter_class=argparse.RawDescriptionHelpFormatter,
                                   epilog="""\
Examples:
  $ python3 {0} /usr/lib/x86_64-linux-gnu/libaccountsservice.so.0
  Generating libaccountsservice.so.0.tramp.S...
  Generating libaccountsservice.so.0.init.c...
""".format(me))

  parser.add_argument('library',
                      metavar='LIB',
                      help="Library to be wrapped.")
  parser.add_argument('--verbose', '-v',
                      help="Print diagnostic info",
                      action='count',
                      default=0)
  parser.add_argument('--dlopen-callback',
                      help="Call user-provided custom callback to load library instead of dlopen",
                      default='')
  parser.add_argument('--dlopen',
                      help="Emit dlopen call (default)",
                      dest='dlopen', action='store_true', default=True)
  parser.add_argument('--no-dlopen',
                      help="Do not emit dlopen call (user must load library himself)",
                      dest='dlopen', action='store_false')
  parser.add_argument('--library-load-name',
                      help="Use custom name for dlopened library (default is LIB)")
  parser.add_argument('--lazy-load',
                      help="Load library lazily on first call to one of it's functions (default)",
                      dest='lazy_load', action='store_true', default=True)
  parser.add_argument('--no-lazy-load',
                      help="Load library eagerly at program start",
                      dest='lazy_load', action='store_false')
  parser.add_argument('--vtables',
                      help="Intercept virtual tables (EXPERIMENTAL)",
                      dest='vtables', action='store_true', default=False)
  parser.add_argument('--no-vtables',
                      help="Do not intercept virtual tables (default)",
                      dest='vtables', action='store_false')
  parser.add_argument('--target',
                      help="Target platform triple e.g. x86_64-unknown-linux-gnu or arm-none-eabi (atm x86_64, i[0-9]86, arm/armhf and aarch64 are supported)",
                      default='x86_64')
  parser.add_argument('--symbol-list',
                      help="Path to file with symbols that should be present in wrapper (all by default)")
  parser.add_argument('--symbol-prefix',
                      metavar='PFX',
                      help="Prefix wrapper symbols with PFX",
                      default='')
  parser.add_argument('-q', '--quiet',
                      help="Do not print progress info",
                      action='store_true')
  parser.add_argument('--outdir', '-o',
                      help="Path to create wrapper at",
                      default='./')

  args = parser.parse_args()

  input_name = args.library
  verbose = args.verbose
  dlopen_callback = args.dlopen_callback
  dlopen = args.dlopen
  lazy_load = args.lazy_load
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

  def is_exported(s):
    return (s['Type'] != 'LOCAL'
            and s['Ndx'] != 'UND'
            and s['Name'] not in ['', '_init', '_fini'])

  syms = list(filter(is_exported, collect_syms(input_name)))

  exported_data = [s['Name'] for s in syms if s['Type'] == 'OBJECT' and not s['Name'].startswith('_')]
  if exported_data:
    warn("library '%s' contains data symbols which won't be intercepted: %s" % (input_name, ', '.join(exported_data)))

  # Collect functions
  # TODO: warn if user-specified functions are missing

  if funs is None:
    orig_funs = filter(lambda s: s['Type'] == 'FUNC', syms)

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

  if args.vtables:
    vtabs = {}

    for s in syms:
      m = re.match(r'^(vtable|typeinfo|typeinfo name) for (.*)', s['Demangled Name'])
      if m is not None and is_exported(s):
        typ, cls = m.groups()
        vtabs.setdefault(cls, {})[typ] = s

    rels = collect_relocs(input_name)
    secs = collect_sections(input_name)

    # TODO: collect vtable raw contents and relocations

    if verbose:
      print("Exported vtables:")
      for i, (cls, _) in enumerate(sorted(vtabs.items())):
        print("  {0}: {1}".format(i, cls))
      print("Relocs:")
      for rel in rels:
        print("  {0}: {1}".format(rel['Offset'], rel['Sym. Name + Addend']))
      print("Sections:")
      for sec in secs:
        print("  {}: [{:x}, {:x}), at {:x}".format(sec['Name'], sec['Address'], sec['Address'] + sec['Size'], sec['Off']))

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
        no_dlopen=not int(dlopen),
        lazy_load=int(lazy_load),
        sym_names=',\n  '.join('"%s"' % name for name in funs))
    f.write(init_text)

if __name__ == '__main__':
  main()
