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

PREFIX=$(pwd)/prefix
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

complete "${PREFIX}" "heaptrack-${VERSION}" "${OUTPUT}"
