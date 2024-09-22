#!/bin/bash

set -ex
source common.sh

VERSION=$1

URL=https://github.com/KDE/heaptrack.git

FULLNAME=heaptrack-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="heaptrack-${VERSION}"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

ROOT=$(pwd)
DIR=$(pwd)/build
INFRA=$(pwd)/infra

mkdir "${DIR}"
cd "${DIR}"

if [[ $VERSION == 'trunk' ]]; then
    git clone --depth 1 ${URL}
else
    git clone --depth 1 ${URL} -b "${VERSION}"
fi;

cd "${ROOT}"
git clone https://github.com/compiler-explorer/infra
cd "${INFRA}"
make ce
mkdir -p /opt/compiler-explorer/staging
bin/ce_install install 'gcc/arm64 13.2.0'

BUILDDIR=${DIR}/heaptrack/build
mkdir "${BUILDDIR}"
cd "${BUILDDIR}"


PREFIX=$(pwd)/amd64

# cmake -DCMAKE_BUILD_TYPE=Release ..
# cmake --build . --target heaptrack_unwind heaptrack_preload heaptrack_print heaptrack_interpret heaptrack_inject

# mkdir -p ${PREFIX}/bin ${PREFIX}/lib ${PREFIX}/libexec
# cp ${BUILDDIR}/bin/heaptrack ${PREFIX}/bin
# cp ${BUILDDIR}/bin/heaptrack_print ${PREFIX}/bin
# cp ${BUILDDIR}/lib/heaptrack/libheaptrack_preload.so ${PREFIX}/lib
# cp ${BUILDDIR}/lib/heaptrack/libheaptrack_inject.so ${PREFIX}/lib
# cp ${BUILDDIR}/lib/heaptrack/libexec/heaptrack_interpret ${PREFIX}/libexec
# cp /lib/x86_64-linux-gnu/libboost_iostreams.* ${PREFIX}/lib
# cp /lib/x86_64-linux-gnu/libboost_program_options.* ${PREFIX}/lib
# cp /lib/x86_64-linux-gnu/libboost_filesystem.* ${PREFIX}/lib


# rm -Rf *

curl -sL -o boost.tgz https://conan.compiler-explorer.com/downloadpkg/boost_bin/1.85.0/arm64g1320
curl -sL -o zlib.tgz https://conan.compiler-explorer.com/downloadpkg/zlib/1.3.1/arm64g1320
curl -sL -o libunwind.zip https://github.com/libunwind/libunwind/archive/refs/tags/v1.8.1.zip
curl -sL -o elfutils.tar.bz2 https://sourceware.org/elfutils/ftp/0.191/elfutils-0.191.tar.bz2

mkdir -p /usr/local/boost
tar -xzf boost.tgz -C /usr/local/boost

mkdir -p /usr/local/zlib
tar -xzf zlib.tgz -C /usr/local/zlib

mkdir -p /usr/local/elfutils/src
tar -xjf elfutils.tar.bz2 -C /usr/local/elfutils/src

mkdir -p /usr/local/libunwind/src
cd /usr/local/libunwind/src
unzip -q "${BUILDDIR}/libunwind.zip"

PREFIX=$(pwd)/aarch64
export CXX=/opt/compiler-explorer/arm64/gcc-13.2.0/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-g++
export CC=/opt/compiler-explorer/arm64/gcc-13.2.0/aarch64-unknown-linux-gnu/bin/aarch64-unknown-linux-gnu-gcc

export TARGET=aarch64-linux-gnu

cd /usr/local/libunwind/src/libunwind*
autoreconf -i
./configure --prefix=/usr/local/libunwind --build=x86_64-linux-gnu --host=aarch64-linux-gnu
make
make install

cd /usr/local/elfutils/src/elfutils*

export LDFLAGS="-Wl,-rpath=/usr/local/zlib/lib"
./configure "CC=$CC -L/usr/local/zlib/lib -I/usr/local/zlib/include -Wl,-rpath=/usr/local/zlib/lib -lz" "CXX=$CXX -L/usr/local/zlib/lib -I/usr/local/zlib/include -Wl,-rpath=/usr/local/zlib/lib -lz" --with-zlib --disable-debuginfod --disable-libdebuginfod --prefix=/usr/local/elfutils --build=x86_64-linux-gnu --host=aarch64-linux-gnu || /bin/true
make --trace
make install

ls -l /usr/local/elfutils

cd "${BUILDDIR}"

TOPDIR=/usr/local/boost/lib/cmake
DIRS=$(ls -1p "$TOPDIR")
CMAKEDIRS=$(echo "${DIRS}" | grep / | xargs echo | sed 's/\/ /:/g' | sed 's/\///g' | sed 's/:/\:\/usr\/local\/boost\/lib\/cmake\//g' | sed 's/^/\/usr\/local\/boost\/lib\/cmake\//g')

export CMAKE_PREFIX_PATH=$CMAKEDIRS

cmake -DCMAKE_VERBOSE_MAKEFILE=ON \
      -DLIBDW_LIBRARIES=/usr/local/libunwind/lib/libdw.a \
      -DLIBDW_INCLUDE_DIRS=/usr/local/libunwind/include \
      -DLIBUNWIND_LIBRARY=/usr/local/libunwind/lib/libunwind-aarch64.a \
      -DLIBUNWIND_INCLUDE_DIR=/usr/local/libunwind/include \
      -DLIBUNWIND_HAS_UNW_BACKTRACE=ON \
      -DZLIB_LIBRARY=/usr/local/zlib/lib/libz.a \
      -DCMAKE_CROSSCOMPILING=ON \
      -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
      -DCMAKE_CXX_COMPILER_TARGET=aarch64-linux-gnu \
      -DCMAKE_C_COMPILER_TARGET=aarch64-linux-gnu \
      -DCMAKE_ASM_COMPILER_TARGET=aarch64-linux-gnu \
      -DCMAKE_BUILD_TYPE=Release \
      ..
cmake --build . --target heaptrack_unwind heaptrack_preload heaptrack_print heaptrack_interpret heaptrack_inject

mkdir -p "${PREFIX}/bin" "${PREFIX}/lib" "${PREFIX}/libexec"
cp "${BUILDDIR}/bin/heaptrack" "${PREFIX}/bin"
cp "${BUILDDIR}/bin/heaptrack_print" "${PREFIX}/bin"
cp "${BUILDDIR}/lib/heaptrack/libheaptrack_preload.so" "${PREFIX}/lib"
cp "${BUILDDIR}/lib/heaptrack/libheaptrack_inject.so" "${PREFIX}/lib"
cp "${BUILDDIR}/lib/heaptrack/libexec/heaptrack_interpret" "${PREFIX}/libexec"
cp /usr/local/boost/lib/libboost_iostreams.* "${PREFIX}/lib"
cp /usr/local/boost/lib/libboost_program_options.* "${PREFIX}/lib"
cp /usr/local/boost/lib/libboost_filesystem.* "${PREFIX}/lib"

complete "${PREFIX}" "heaptrack-${VERSION}" "${OUTPUT}"
