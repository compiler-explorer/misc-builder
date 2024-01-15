#!/bin/bash

## $1 : version
## $2 : destination: a directory
## $3 : last revision: a revision descriptor which may be fetched from the cache.

set -exu
source common.sh

ROOT=$(pwd)
VERSION=$1
URL="https://github.com/trailofbits/vast"

if echo "${VERSION}" | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
    REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
else
    BRANCH=${VERSION}
    REVISION=$(get_remote_revision "${URL}" "tags/${BRANCH}")
fi

FULLNAME=vast-${VERSION}.tar.xz
OUTPUT=${ROOT}/${FULLNAME}
LAST_REVISION="${3:-}"

if [[ -d "${2}" ]]; then
   OUTPUT=$2/${FULLNAME}
else
   OUTPUT=${2-$OUTPUT}
fi

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

STAGING_DIR=/opt/compiler-explorer/vast-${VERSION}

rm -rf "vast-${VERSION}"
git clone -q --depth 1 --recursive --single-branch -b "${BRANCH}" "${URL}" "vast-${VERSION}"

cd "vast-${VERSION}"

cmake --preset ninja-multi-default \
  --toolchain ./cmake/lld.toolchain.cmake \
  --install-prefix "${STAGING_DIR}" \
  -DLLVM_EXTERNAL_LIT=/usr/local/bin/lit \
  -DCMAKE_INSTALL_RPATH:PATH="\$ORIGIN/../lib" \
  -DCMAKE_PREFIX_PATH="/usr/lib/llvm-17;/usr/lib/llvm-17/lib/cmake/mlir;/usr/lib/llvm-17/lib/cmake/clang"

cmake --build --preset ninja-rel
cmake --install ./builds/ninja-multi-default

# Copy all shared object dependencies into the release directory to create a hermetic build, per
# Compiler Explorer requirements. Update rpath for these objects to $ORIGIN.
# To ensure we only muck with rpaths for these objects, do this work in a temporary directory.
# This code copied and modified from compiler-explorer/cobol-builder/build/build.sh
cp $(ldd "${STAGING_DIR}/bin/vast-front" | grep -E  '=> /' | grep -Ev 'lib(pthread|c|dl|rt).so' | awk '{print $3}') "${STAGING_DIR}/lib"
patchelf --set-rpath '$ORIGIN/../lib' $(find ${STAGING_DIR}/lib/ -name \*.so\*)

complete "${STAGING_DIR}" "vast-${VERSION}" "${OUTPUT}"
