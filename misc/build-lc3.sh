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

URL=https://github.com/xavierrouth/C-LC3-Compiler

FULLNAME=C-LC3-Compiler-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="C-LC3-Compiler-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DIR=$(pwd)/C-LC3-Compiler
BUILD=${DIR}/build

git clone --recurse-submodules --depth 1 -b "${BRANCH}" "${URL}" "${DIR}"

mkdir "${BUILDDIR}"
cd "${BUILDDIR}"
cmake ..
make
mkdir -p "${PREFIX}"

cp "${BUILD}/lc3-compile" "${PREFIX}"

complete "${PREFIX}" "C-LC3-Compiler-${VERSION}" "${OUTPUT}"
