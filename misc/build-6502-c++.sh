#!/bin/bash

set -ex
source common.sh

VERSION=$1
if [[ "${VERSION}" = "trunk" ]]; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
else
    BRANCH=V${VERSION}
fi

URL=https://github.com/lefticus/6502-cpp.git

FULLNAME=6502-c++-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="6502-c++-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

pip3 install conan==1.59.0

PREFIX=$(pwd)/prefix
DIR=$(pwd)/6502-c++
BUILDDIR=${DIR}/build

git clone "${URL}" "${DIR}"

mkdir "${BUILDDIR}"
cd "${BUILDDIR}"

GXXPATH=/opt/compiler-explorer/gcc-12.1.0
CXX=${GXXPATH}/bin/g++ cmake ..
make "-j$(nproc)" 6502-c++

patchelf --set-rpath "${GXXPATH}/lib64" bin/6502-c++

mkdir -p "${PREFIX}"
mv bin "${PREFIX}/bin"

complete "${PREFIX}" "6502-c++-${VERSION}" "${OUTPUT}"
