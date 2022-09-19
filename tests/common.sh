if test -n "${TRAVIS:-}"; then
  set -x
fi

if test -z "${ARCH:-}"; then
  ARCH=$(uname -m)
fi

CFLAGS="-Wall -Wextra -Werror ${CFLAGS:-}"

if test $ARCH = $(uname -m); then
  # Native
  TARGET=$ARCH
  PREFIX=
  INTERP=
else
  # Simulate
  # (see .github/workflows/ci.yml for list of needed packages)
  case "$ARCH" in
  arm*hf | armhf-*)
    TARGET=armhf
    PREFIX=arm-linux-gnueabihf-
    INTERP="qemu-arm -L /usr/arm-linux-gnueabihf -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    CFLAGS="$CFLAGS -mthumb-interwork"
    ;;
  arm | arm-* | armel-*)
    TARGET=arm
    PREFIX=arm-linux-gnueabi-
    INTERP="qemu-arm -L /usr/arm-linux-gnueabi -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  aarch64*)
    TARGET=aarch64
    PREFIX=aarch64-linux-gnu-
    INTERP="qemu-aarch64 -L /usr/aarch64-linux-gnu -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  i[0-9]86*)
    TARGET=i686
    PREFIX=
    INTERP=
    CFLAGS="$CFLAGS -m32"
    ;;
  mips | mips-*)
    TARGET=mips
    PREFIX=mips-linux-gnu-
    INTERP="qemu-mips -L /usr/mips-linux-gnu -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  mipsel | mipsel-*)
    TARGET=mipsel
    PREFIX=mipsel-linux-gnu-
    INTERP="qemu-mipsel -L /usr/mipsel-linux-gnu -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  mips64el | mips64el-*)
    TARGET=mips64el
    PREFIX=mips64el-linux-gnuabi64-
    INTERP="qemu-mips64el -L /usr/mips64el-linux-gnuabi64 -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  *)
    echo >&2 "Unsupported target: $ARCH"
    exit 1
    ;;
  esac
fi

CFLAGS="-Wall -Wextra -Werror ${CFLAGS:-}"
CC=$PREFIX${CC:-gcc}
CXX=$PREFIX${CXX:-g++}

if uname -o | grep -q FreeBSD; then
  LIBS=
else
  LIBS=-ldl
fi
