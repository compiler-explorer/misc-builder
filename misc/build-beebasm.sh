#!/bin/bash

set -ex
source common.sh

VERSION=$1
if [[ "${VERSION}" = "trunk" ]]; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
else
    BRANCH=v${VERSION}
fi

URL=https://github.com/stardot/beebasm

FULLNAME=beebasm-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="beebasm-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DIR=$(pwd)/beebasm
BUILD=$(pwd)/build
git clone --depth 1 -b "${BRANCH}" "${URL}" "${DIR}"

cmake -S "${DIR}" -B "${BUILD}" -DCMAKE_BUILD_TYPE=Release -GNinja
ninja -C "${BUILD}"
mkdir -p "${PREFIX}"
cp "${BUILD}/beebasm" "${PREFIX}"

complete "${PREFIX}" "beebasm-${VERSION}" "${OUTPUT}"
