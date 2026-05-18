#!/bin/sh

set -eu

rm -f libs.txt
for lib in $(find /lib /usr/lib /usr/local/lib -name \*.so\*); do
  if file $lib | grep -q 'ELF .* LSB shared object'; then
    echo $lib >> libs.txt
  fi
done

tic=$(date +%s)
for lib in $(cat libs.txt); do
  ./implib-gen.py -q --vtables $lib
done
toc=$(date +%s)

echo $((toc - tic))
