#!/bin/sh

# Runs implib-gen on all installed libraries

set -eu

if test "${1:-}" != noscan; then
  rm -f libs.txt
  for lib in $(find /lib /usr/lib /usr/local/lib -name \*.so\*); do
    if file $lib | grep -q 'ELF .* LSB shared object'; then
      echo $lib >> libs.txt
    fi
  done
fi

for lib in $(cat libs.txt); do
  echo "Checking $lib..."
  ./implib-gen.py $lib
  # TODO: run with --vtables
  rm $(basename $lib)*
done
