This is a simple specification for Implib.so with `-DIMPLIB_EXPORT_SHIMS`.
It's an abstracton of arch/common/init.c.tpl.

I have no idea why I didn't use PlusCal to write this...

To run
- download tla2tools.jar from https://github.com/tlaplus/tlaplus
- execute
```
$ rm -rf states
$ java -jar tla2tools.jar -workers $(nproc) Init.tla
```
(add `-coverage 1` for coverage stats).
