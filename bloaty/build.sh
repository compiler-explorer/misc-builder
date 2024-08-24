#!/bin/bash

set -ex
source common.sh

VERSION=$1

URL=https://github.com/google/bloaty/releases/download/v${VERSION}/bloaty-${VERSION}.tar.bz2

FULLNAME=bloaty-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="bloaty-${VERSION}"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DIR=$(pwd)/build

mkdir "${DIR}"
cd "${DIR}"
curl -sL "${URL}" | tar jxf - --strip-components 1

mkdir build
cd build
# For unknown reasons the `--install-prefix` didn't work so I added the -DCMAKE_INSTALL_PREFIX too
cmake --install-prefix "${PREFIX}" -DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" -GNinja "${DIR}"
cmake --build .
cmake --install .

complete "${PREFIX}" "bloaty-${VERSION}" "${OUTPUT}"
