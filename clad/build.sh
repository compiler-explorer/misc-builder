#!/bin/bash

set -euxo pipefail
source common.sh

VERSION=$1
if [[ "${VERSION}" = "trunk" ]]; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
    REMOTE=heads/${BRANCH}
else
    BRANCH=v${VERSION}
    REMOTE=tags/${BRANCH}
fi

URL=https://github.com/vgvassilev/clad
CLANG_VERSION=18

FULLNAME=clad-${VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz

REVISION="$(get_remote_revision "${URL}" "${REMOTE}")"

REVISION="clad-${REVISION}"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

bash -c "$(curl https://apt.llvm.org/llvm.sh)" "${CLANG_VERSION}"
apt install libclang-${CLANG_VERSION}-dev

PREFIX=$(pwd)/prefix
BUILD=$(pwd)/build
SOURCE=$(pwd)/clad

git clone --depth 1 -b "${BRANCH}" "${URL}" "${SOURCE}"

mkdir "${BUILD}"
cd "${BUILD}"
cmake "${SOURCE}" \
    -DClang_DIR=/usr/lib/llvm-${CLANG_VERSION} \
    -DLLVM_DIR=/usr/lib/llvm-${CLANG_VERSION} \
    -DLLVM_ENABLE_RTTI=OFF \
    -DLLVM_EXTERNAL_LIT="$(which lit)" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -GNinja

ninja
ninja install

complete "${PREFIX}" "${FULLNAME}" "${OUTPUT}"
