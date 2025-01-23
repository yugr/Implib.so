This directory contains formal models of Implib.so internal logic
which should help with verification.

# Initialization

This is a model of Implib.so initialization logic with `-DIMPLIB_EXPORT_SHIMS`
and is based on arch/common/init.c.tpl.

I have no idea why I didn't use PlusCal to write this...

To run
- download tla2tools.jar from https://github.com/tlaplus/tlaplus
- execute
```
$ rm -rf states
$ java -jar tla2tools.jar -workers $(nproc) Init.tla
```
(add `-coverage 1` for coverage stats).
