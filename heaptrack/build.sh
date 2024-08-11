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

DIR=$(pwd)/build

mkdir "${DIR}"
cd "${DIR}"

if [[ $VERSION == 'trunk' ]]; then
    git clone --depth 1 ${URL}
else
    git clone --depth 1 ${URL} -b ${VERSION}
fi;

BUILDDIR=${DIR}/heaptrack/build
mkdir "${BUILDDIR}"
cd "${BUILDDIR}"


PREFIX=$(pwd)/amd64

cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --target heaptrack_unwind heaptrack_preload heaptrack_print heaptrack_interpret heaptrack_inject

mkdir -p ${PREFIX}/bin ${PREFIX}/lib ${PREFIX}/libexec
cp ${BUILDDIR}/bin/heaptrack ${PREFIX}/bin
cp ${BUILDDIR}/bin/heaptrack_print ${PREFIX}/bin
cp ${BUILDDIR}/lib/heaptrack/libheaptrack_preload.so ${PREFIX}/lib
cp ${BUILDDIR}/lib/heaptrack/libheaptrack_inject.so ${PREFIX}/lib
cp ${BUILDDIR}/lib/heaptrack/libexec/heaptrack_interpret ${PREFIX}/libexec
cp /lib/x86_64-linux-gnu/libboost_iostreams.* ${PREFIX}/lib
cp /lib/x86_64-linux-gnu/libboost_program_options.* ${PREFIX}/lib
cp /lib/x86_64-linux-gnu/libboost_filesystem.* ${PREFIX}/lib


rm -Rf *

curl -sL -o boost.tgz https://conan.compiler-explorer.com/downloadpkg/boost_bin/1.85.0/arm64g1320
curl -sL -o zlib.tgz https://zlib.net/current/zlib.tar.gz
curl -sL -o libunwind.zip https://github.com/libunwind/libunwind/archive/refs/tags/v1.8.1.zip

mkdir -p /usr/local/boost
tar -xzf boost.tgz -C /usr/local/boost

mkdir -p /usr/local/zlib/src
tar -xzf zlib.tgz -C /usr/local/zlib/src

mkdir -p /usr/local/libunwind/src
cd /usr/local/libunwind/src
unzip -q "${BUILDDIR}/libunwind.zip"


PREFIX=$(pwd)/aarch64
export CXX=$(which aarch64-linux-gnu-g++)
export CC=$(which aarch64-linux-gnu-gcc)

cd /usr/local/zlib/src/zlib*
./configure --prefix=/usr/local/zlib
make
make install

export TARGET=aarch64-linux-gnu
cd /usr/local/libunwind/src/libunwind*
autoreconf -i
./configure --prefix=/usr/local/libunwind --build=x86_64-linux-gnu --host=aarch64-linux-gnu
make
make install

export PKG_CONFIG=$(which pkg-config)
export PKG_CONFIG_PATH=/usr/local/zlib/lib/pkgconfig


mkdir -p /usr/local/elfutils
cd /usr/local/elfutils
git clone git://sourceware.org/git/elfutils.git src
cd src
git checkout elfutils-0.191
autoreconf -i -f
./configure --with-zlib --prefix=/usr/local/elfutils --build=x86_64-linux-gnu --host=aarch64-linux-gnu
make
make install

ls -l /usr/local/elfutils

cd "${BUILDDIR}"

cmake -DCMAKE_MODULE_PATH=/usr/local/boost/cmake -DLIBUNWIND_LIBRARY=/usr/local/libunwind/lib/libunwind-aarch64.a -DLIBUNWIND_INCLUDE_DIR=/usr/local/libunwind/include -DLIBUNWIND_HAS_UNW_BACKTRACE=ON -DZLIB_LIBRARY=/usr/local/zlib -DCMAKE_CROSSCOMPILING=ON -DCMAKE_SYSTEM_PROCESSOR=aarch64 -DCMAKE_CXX_COMPILER_TARGET=aarch64-linux-gnu -DCMAKE_C_COMPILER_TARGET=aarch64-linux-gnu -DCMAKE_ASM_COMPILER_TARGET=aarch64-linux-gnu -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --target heaptrack_unwind heaptrack_preload heaptrack_print heaptrack_interpret heaptrack_inject

mkdir -p ${PREFIX}/bin ${PREFIX}/lib ${PREFIX}/libexec
cp ${BUILDDIR}/bin/heaptrack ${PREFIX}/bin
cp ${BUILDDIR}/bin/heaptrack_print ${PREFIX}/bin
cp ${BUILDDIR}/lib/heaptrack/libheaptrack_preload.so ${PREFIX}/lib
cp ${BUILDDIR}/lib/heaptrack/libheaptrack_inject.so ${PREFIX}/lib
cp ${BUILDDIR}/lib/heaptrack/libexec/heaptrack_interpret ${PREFIX}/libexec
cp /usr/local/boost/lib/libboost_iostreams.* ${PREFIX}/lib
cp /usr/local/boost/lib/libboost_program_options.* ${PREFIX}/lib
cp /usr/local/boost/lib/libboost_filesystem.* ${PREFIX}/lib

complete "${PREFIX}" "heaptrack-${VERSION}" "${OUTPUT}"
