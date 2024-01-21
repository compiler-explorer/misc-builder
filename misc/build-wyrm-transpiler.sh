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

DIR=$(pwd)/wyrm
STAGING_DIR=/opt/compiler-explorer/wyrm-${VERSION}

git clone "${URL}" "${DIR}"

cd "${DIR}/transpiler"

mkdir build
cd build
export CXX=/opt/compiler-explorer/gcc-12.1.0/bin/g++
export CC=/opt/compiler-explorer/gcc-12.1.0/bin/gcc
cmake .. -GNinja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX="$STAGING_DIR"
ninja install

cp -v libplugin.so "${STAGING_DIR}"

patchelf --set-rpath '$ORIGIN/lib:/opt/compiler-explorer/gcc-12.1.0/lib64/' "${STAGING_DIR}/libplugin.so"

complete "${STAGING_DIR}" "wyrm-${VERSION}" "${OUTPUT}"
