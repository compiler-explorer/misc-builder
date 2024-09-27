#!/bin/bash

set -ex
source common.sh

VERSION=$1

URL=https://github.com/KDE/heaptrack.git

ARCH=$(uname -m)

FULLNAME=heaptrack-${ARCH}-${VERSION}.tar.xz
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

BUILDDIR=${DIR}/heaptrack/build
mkdir "${BUILDDIR}"
cd "${BUILDDIR}"


PREFIX=$(pwd)/heaptrack

cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --target heaptrack_unwind heaptrack_preload heaptrack_print heaptrack_interpret heaptrack_inject

mkdir -p ${PREFIX}/bin ${PREFIX}/lib ${PREFIX}/libexec
cp ${BUILDDIR}/bin/heaptrack ${PREFIX}/bin
cp ${BUILDDIR}/bin/heaptrack_print ${PREFIX}/bin
cp ${BUILDDIR}/lib/heaptrack/libheaptrack_preload.so ${PREFIX}/lib
cp ${BUILDDIR}/lib/heaptrack/libheaptrack_inject.so ${PREFIX}/lib
cp ${BUILDDIR}/lib/heaptrack/libexec/heaptrack_interpret ${PREFIX}/libexec
cp /lib/${ARCH}-linux-gnu/libboost_iostreams.* ${PREFIX}/lib
cp /lib/${ARCH}-linux-gnu/libboost_program_options.* ${PREFIX}/lib
cp /lib/${ARCH}-linux-gnu/libboost_filesystem.* ${PREFIX}/lib

complete "${PREFIX}" "heaptrack-${ARCH}-${VERSION}" "${OUTPUT}"
