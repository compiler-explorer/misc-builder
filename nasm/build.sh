#!/bin/bash

set -ex
source common.sh

VERSION=$1

URL=https://www.nasm.us/pub/nasm/releasebuilds/${VERSION}/nasm-${VERSION}.tar.xz

FULLNAME=nasm-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="nasm-${VERSION}"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DIR=$(pwd)/build

mkdir "${DIR}"
cd "${DIR}"
curl -sL "${URL}" | tar Jxf - --strip-components 1

if [[ -e include/nasmlib.h ]]; then
  sed -i 's/void pure_func seg_init(void);/void seg_init(void);/' include/nasmlib.h
fi
./configure "--prefix=${PREFIX}"
make "-j$(nproc)" install

complete "${PREFIX}" "nasm-${VERSION}" "${OUTPUT}"
