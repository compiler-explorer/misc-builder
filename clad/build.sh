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
CLANG_VERSION=18.1.0

FULLNAME=clad-${VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz

REVISION="$(get_remote_revision "${URL}" "${REMOTE}")"

REVISION="clad-${REVISION}"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
LLVM=$(pwd)/llvm
BUILD=$(pwd)/build
SOURCE=$(pwd)/clad

git clone --depth 1 -b llvmorg-${CLANG_VERSION} https://github.com/llvm/llvm-project.git "${LLVM}"
git clone --depth 1 -b "${BRANCH}" "${URL}" "${SOURCE}"

mkdir "${BUILD}"
cd "${BUILD}"
cmake "${LLVM}/llvm" \
    -DLLVM_ENABLE_PROJECTS=clang \
    -DLLVM_EXTERNAL_PROJECTS=clad \
    -DLLVM_EXTERNAL_CLAD_SOURCE_DIR=${SOURCE} \
    -DCMAKE_BUILD_TYPE="Release" \
    -DLLVM_TARGETS_TO_BUILD=host \
    -DLLVM_INSTALL_UTILS=ON \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    -GNinja

ninja clang-headers
ninja clad
ninja install-clad

complete "${PREFIX}" "${FULLNAME}" "${OUTPUT}"
