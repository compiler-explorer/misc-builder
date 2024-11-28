#!/bin/bash

set -euo pipefail
source common.sh

VERSION="${1}"
LAST_REVISION="${3-}"

URL="https://github.com/lfortran/lfortran.git"
if [[ "${VERSION}" == trunk ]]; then
  VERSION=trunk-$(date +%Y%m%d)
  BRANCH=main
  REMOTE=heads/main
else
  BRANCH=v"${VERSION}"
  REMOTE=tags/${BRANCH}
fi

FULLNAME=lfortran-${VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz
REVISION=$(get_remote_revision "${URL}" "${REMOTE}")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

git clone "${URL}" --depth=1 "--branch=${BRANCH}"

OUTPUT=$(realpath "${OUTPUT}")
DEST=$(realpath prefix)
SOURCE=$(realpath lfortran)

mkdir build
cmake \
    -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS_RELEASE="-Wall -Wextra -O3 -funroll-loops -DNDEBUG" \
    -DWITH_LLVM=yes \
    -DLFORTRAN_BUILD_ALL=yes \
    -DWITH_STACKTRACE=no \
    -DWITH_RUNTIME_STACKTRACE=yes \
    -DCMAKE_INSTALL_PREFIX="${DEST}" \
    -DCMAKE_INSTALL_LIBDIR=share/lfortran/lib \
    -Bbuild \
    -S"${SOURCE}"
ninja -C build
ninja -C build install

mkdir "${DEST}/lib"

# Copy all shared object dependencies into the release directory to create a hermetic build, per
# Compiler Explorer requirements. Update rpath for these objects to $ORIGIN.
cp $(ldd "${DEST}/bin/lfortran" | grep -E  '=> /' | grep -Ev 'lib(pthread|c|dl|rt).so' | awk '{print $3}') "${DEST}/lib"
patchelf --set-rpath '$ORIGIN/../lib' "${DEST}/bin/lfortran"

complete "${DEST}" "${FULLNAME}" "${OUTPUT}"
