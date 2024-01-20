#!/bin/bash

set -ex
source common.sh

VERSION=$1
if [[ "${VERSION}" = "trunk" ]]; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=main
else
    BRANCH=V${VERSION}
fi

URL=https://github.com/jeremy-rifkin/wyrm.git

FULLNAME=wyrm-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="wyrm-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DIR=$(pwd)/wyrm

git clone "${URL}" "${DIR}"

cd "${DIR}/transpiler"

mkdir build
cd build
export CXX=/opt/compiler-explorer/gcc-12.1.0/bin/g++
export CC=/opt/compiler-explorer/gcc-12.1.0/bin/gcc
cmake .. -GNinja -DCMAKE_BUILD_TYPE=Debug
ninja

mkdir -p "${PREFIX}"
cd ..
mv build "${PREFIX}/build"

complete "${PREFIX}" "wyrm-${VERSION}" "${OUTPUT}"
