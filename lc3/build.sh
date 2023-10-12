#!/bin/bash

set -ex
source common.sh
export PATH="$PATH":"$HOME"/.cargo/bin
source $HOME/.cargo/env

VERSION=$1
if [[ "${VERSION}" = "trunk" ]]; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=main
else
    BRANCH=V${VERSION}
fi

URL=https://github.com/xavierrouth/lc3-compiler

FULLNAME=C-LC3-Compiler-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="C-LC3-Compiler-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DIR=$(pwd)/lc3-compiler
BUILD=${DIR}/target/release

git clone --depth 1 -b "${BRANCH}" "${URL}" "${DIR}"

cd $DIR
cargo build --release
mkdir -p "${PREFIX}"

cp "${BUILD}/lc3-compile" "${PREFIX}"

complete "${PREFIX}" "C-LC3-Compiler-${VERSION}" "${OUTPUT}"
