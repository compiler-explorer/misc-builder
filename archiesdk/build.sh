#!/bin/bash

## $1 : version (e.g. "Release-1")
## $2 : destination directory
## $3 : last revision successfully built

set -ex
source common.sh

VERSION="${1}"
LAST_REVISION="${3:-}"

GCC_URL="https://gitlab.com/_targz/gcc.git"
BINUTILS_URL="https://gitlab.com/_targz/binutils.git"
SDK_URL="https://gitlab.com/_targz/archiesdk.git"

GCC_REVISION=$(get_remote_revision "${GCC_URL}" "heads/master")
BINUTILS_REVISION=$(get_remote_revision "${BINUTILS_URL}" "heads/master")
SDK_REVISION=$(get_remote_revision "${SDK_URL}" "tags/${VERSION}")

# Revision captures all three upstream sources
REVISION="${VERSION}-gcc${GCC_REVISION:0:8}-bi${BINUTILS_REVISION:0:8}-sdk${SDK_REVISION:0:8}"

FULLNAME="archiesdk-${VERSION}"
OUTPUT=$(realpath "$2/${FULLNAME}.tar.xz")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

# Build to the final CE install path so the sysroot baked into GCC is correct at runtime
INSTALL_PREFIX="/opt/compiler-explorer/archiesdk/${VERSION}"
SYSROOT="${INSTALL_PREFIX}/SDK"
mkdir -p "${SYSROOT}/include" "${SYSROOT}/lib"

NCPU=$(nproc)

# Clone archiesdk at the tagged version
git clone --depth 1 --branch "${VERSION}" "${SDK_URL}" archiesdk-src
ARCHIESDK=$(realpath archiesdk-src)

# Install SDK headers into the sysroot
cp -r "${ARCHIESDK}/SDK/include/." "${SYSROOT}/include/"

# Clone binutils and GCC from master
git clone --depth 1 "${BINUTILS_URL}" binutils-src
git clone --depth 1 "${GCC_URL}" gcc-src

# Fetch GCC build prerequisites (gmp, mpc, mpfr, isl)
cd gcc-src
./contrib/download_prerequisites
cd ..

# Build binutils
mkdir -p build-binutils
cd build-binutils
../binutils-src/configure \
    --prefix="${INSTALL_PREFIX}" \
    --target=arm-archie \
    --with-sysroot="${SYSROOT}" \
    --with-build-sysroot="${SYSROOT}" \
    --disable-nls \
    --disable-multilib
make -j"${NCPU}" configure-host
make -j"${NCPU}"
make install
cd ..

# Build GCC cross-compiler + libgcc
mkdir -p build-gcc
cd build-gcc
../gcc-src/configure \
    --prefix="${INSTALL_PREFIX}" \
    --target=arm-archie \
    --with-sysroot="${SYSROOT}" \
    --with-build-sysroot="${SYSROOT}" \
    --disable-nls \
    --disable-shared \
    --enable-languages=c \
    --disable-multilib \
    --disable-threads \
    --disable-decimal-float \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libssp \
    --disable-libatomic \
    --disable-libquadmath \
    --with-cpu=arm2 \
    --with-float=soft
make -j"${NCPU}" all-gcc all-target-libgcc \
    CFLAGS_FOR_TARGET='-msoft-float -mcpu=arm2 -mno-thumb-interwork -O2 -ffreestanding'
make install-gcc install-target-libgcc
cd ..

# Build SDK libraries (libc.a, libm.a, libarchie.a, crt0.o, crtheap.o)
# Override tool paths to use our freshly built cross-compiler
cd "${ARCHIESDK}/SDK"
make sdk \
    ARCHIESDK="${ARCHIESDK}" \
    ARCHIECC="${INSTALL_PREFIX}/bin/arm-archie-gcc" \
    ARCHIEAS="${INSTALL_PREFIX}/bin/arm-archie-as" \
    ARCHIEAR="${INSTALL_PREFIX}/bin/arm-archie-ar" \
    ARCHIEOBJCOPY="${INSTALL_PREFIX}/bin/arm-archie-objcopy"
cp lib/*.a lib/*.o "${SYSROOT}/lib/"
cd -

complete "${INSTALL_PREFIX}" "${FULLNAME}" "${OUTPUT}"
