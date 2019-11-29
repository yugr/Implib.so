if test -n "${TRAVIS:-}"; then
  set -x
fi

if test -z "${ARCH:-}"; then
  ARCH=$(uname -m)
fi

CFLAGS="-Wall -Wextra -Werror ${CFLAGS:-}"
case "${ARCH:-}" in
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
  # To run tests for AArch64 install
  # sudo apt-get install gcc-aarch64-linux-gnu qemu-user
  TARGET=i686
  PREFIX=
  INTERP=
  CFLAGS="$CFLAGS -m32"
  ;;
'' | x86_64* | host)
  TARGET=x86_64
  PREFIX=
  INTERP=
  ;;
*)
  echo >&2 "Unsupported target: $ARCH"
  exit 1
  ;;
esac

CC=$PREFIX${CC:-gcc}
CXX=$PREFIX${CXX:-g++}

if uname -o | grep -q FreeBSD; then
  LIBS=
else
  LIBS=-ldl
fi
