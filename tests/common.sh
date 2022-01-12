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
  case "$ARCH" in
  arm*hf | armhf-*)
    # To run tests for ARM install
    # $ sudo apt-get install gcc-arm-linux-gnueabi qemu-user
    TARGET=armhf
    PREFIX=arm-linux-gnueabihf-
    INTERP="qemu-arm -L /usr/arm-linux-gnueabihf -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    CFLAGS="$CFLAGS -mthumb-interwork"
    ;;
  arm | arm-* | armel-*)
    # To run tests for ARM install
    # $ sudo apt-get install gcc-arm-linux-gnueabi qemu-user
    TARGET=arm
    PREFIX=arm-linux-gnueabi-
    INTERP="qemu-arm -L /usr/arm-linux-gnueabi -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  aarch64*)
    # To run tests for AArch64 install
    # sudo apt-get install gcc-aarch64-linux-gnu qemu-user
    TARGET=aarch64
    PREFIX=aarch64-linux-gnu-
    INTERP="qemu-aarch64 -L /usr/aarch64-linux-gnu -E LD_LIBRARY_PATH=.${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    ;;
  i[0-9]86*)
    # To run tests for x86 install
    # sudo apt-get install gcc-multilib g++-multilib
    TARGET=i686
    PREFIX=
    INTERP=
    CFLAGS="$CFLAGS -m32"
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
