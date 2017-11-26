# Motivation

In a nutshell, Implib.so is a simple equivalent of [Windows DLL import libraries](http://www.digitalmars.com/ctg/implib.html) for POSIX shared libraries.

On Linux, if you link against shared library you normally use `-lxyz` compiler option which makes your application depend on `libxyz.so`. This would cause `libxyz.so` to be forcedly loaded at program startup (and its constructors to be executed) even if you never call any of its functions.

If you instead want to delay loading of `libxyz.so` (e.g. its unlikely to be used and you don't want to waste resources on it or you want to select best implementation at runtime), you can remove dependency from `LDFLAGS` and issue `dlopen` call manually. But this would cause `ld` to err because it won't be able to statically resolve symbols which are supposed to come from this shared library. At this point you have only two choices:
* emit normal calls to library functions and suppress link errors from `ld` via `-Wl,-z,nodefs`; this is undesired because you loose ability to detect link errors for other libraries statically
* load necessary function addresses at runtime via `dlsym` and call them via function pointers; this isn't very convenient because you have to keep track which symbols your program uses and also somehow manage global function pointers

Implib.so provides an easy solution - link your program with a _wrapper_ which
* provides all necessary symbols to make linker happy
* loads wrapped library on first call to any of its functions
* redirects calls to library symbols
Generated wrapper code is analogous to Windows import libraries which achieve the same functionality for DLLs.

Implib.so was originally inspired by Stackoverflow question [Is there an elegant way to avoid dlsym when using dlopen in C?](https://stackoverflow.com/questions/45917816/is-there-an-elegant-way-to-avoid-dlsym-when-using-dlopen-in-c/47221180).

For some related reading:
* [Wikipedia on Windows Import Libraries](https://en.wikipedia.org/wiki/Dynamic-link_library#Import_libraries)
* [MSDN on Linker Support for Delay-Loaded DLLs](https://msdn.microsoft.com/en-us/library/151kt790.aspx)

# Usage

A typical use-case would look like this:

```
$ gen-implib.py libxyz.so
```

This will generate two files: `libxyz.tramp.S` and `libxyz.init.c` which need to be linked to your application. Your application can then freely call functions from `libxyz.so` _without linking to it_. Library will be loaded (via `dlopen`) on first call to any of its functions. If you want to forcedly resolve all symbols (e.g. if you want to avoid delays further on) you can call `void libxyz_init_all()`.

If you don't want `dlopen` to be called automatically and prefer to load library yourself at program startup, run script as

```
$ gen-implib.py --no-dlopen libxys.so
```

If you do want to load library automatically on first use but would prefer to call `dlopen` yourself (e.g. with custom parameters), run script as

```
$ gen-implib.py --dlopen-callback=mycallback
```

(callback must have signature `void *(*)(const char *lib_name)` and return handle of loaded library).

# Overhead

Implib.so adds the following on top of normal shlib call (which is direct jump to stub, load from PLT and predictable indirect jump):
* untaken direct branch
* load from trampoline table
* predictable indirect jump
so it should be twice as slow (and still quite fast overall, provided that branch predictor does its work). It of course increases the pressure on branch predictor and L1s.

# Limitations

The tool does not transparently support all features of POSIX shared libraries. In particular it can not provide wrappers for data symbols.

Also note that the tool is meant to be a PoC. In particular I didn't implement the following very important features:
* proper support for multi-threading
* support any targets beyond x86\_64 (need at least i386, ARM and AArch64)
* symbol versions are not handled at all
None of these should be hard to add so let me know if you need it.

Finally tool is only lightly tested and minor TODOs are scattered all over the code.
