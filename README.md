[![Build Status](https://travis-ci.org/yugr/Implib.so.svg?branch=master)](https://travis-ci.org/yugr/Implib.so)

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

# Usage

A typical use-case would look like this:

```
$ implib-gen.py libxyz.so
```

This will generate two files: `libxyz.tramp.S` and `libxyz.init.c` which need to be linked to your application (instead of `-lxyz`):

```
$ gcc myapp.c libxyz.tramp.S libxyz.init.c ...
```

Application can then freely call functions from `libxyz.so` _without linking to it_. Library will be loaded (via `dlopen`) on first call to any of its functions. If you want to forcedly resolve all symbols (e.g. if you want to avoid delays further on) you can call `void libxyz_init_all()`.

Above command would perform a _lazy load_ i.e. load library on first call to one of it's symbols. If you want to load it at startup, run

```
$ implib-gen.py --no-lazy-load libxyz.so
```

If you don't want `dlopen` to be called automatically and prefer to load library yourself at program startup, run script as

```
$ implib-gen.py --no-dlopen libxys.so
```

If you do want to load library via `dlopen` but would prefer to call it yourself (e.g. with custom parameters or with modified library name), run script as

```
$ implib-gen.py --dlopen-callback=mycallback libxyz.so
```

(callback must have signature `void *(*)(const char *lib_name)` and return handle of loaded library).

Finally to force library load and resolution of all symbols, call

    void _LIBNAME_tramp_resolve_all(void);

# Overhead

Implib.so overhead on a fast path boils down to
* predictable direct jump to wrapper
* predictable untaken direct branch to initialization code
* load from trampoline table
* predictable indirect jump to real function

This is very similar to normal shlib call:
* predictable direct jump to PLT stub
* load from GOT
* predictable indirect jump to real function

so it should have equivalent performance.

# Limitations

The tool does not transparently support all features of POSIX shared libraries. In particular
* it can not provide wrappers for data symbols
* it makes first call to wrapped functions asynch signal unsafe (as it will call `dlopen` and library constructors)
* it may change semantics if there are multiple definitions of same symbol in different loaded shared objects (runtime symbol interposition is considered a bad practice though)
* it may change semantics because shared library constructors are delayed until when library is loaded

Also note that the tool is meant to be a PoC. In particular I didn't implement the following very important features:
* proper support for multi-threading
* support any targets beyond x86\_64 (need at least i386, ARM and AArch64)
* symbol versions are not handled at all

None of these should be hard to add so let me know if you need it.

Finally tool is only lightly tested and minor TODOs are scattered all over the code.

# Related work

As mentioned in introduction import libraries are first class citizens on Windows platform:
* [Wikipedia on Windows Import Libraries](https://en.wikipedia.org/wiki/Dynamic-link_library#Import_libraries)
* [MSDN on Linker Support for Delay-Loaded DLLs](https://msdn.microsoft.com/en-us/library/151kt790.aspx)

Lazy loading is supported by Solaris shared libraries but was never implemented in Linux. There have been [some discussions](https://www.sourceware.org/ml/libc-help/2013-02/msg00017.html) in libc-alpha but no patches were posted.

Implib.so-like functionality is used in [OpenGL loading libraries](https://www.khronos.org/opengl/wiki/OpenGL_Loading_Library) e.g. [GLEW](http://glew.sourceforge.net/) via custom project-specific scripts.
