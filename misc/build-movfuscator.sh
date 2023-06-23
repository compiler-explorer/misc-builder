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

URL=https://github.com/xoreaxeaxeax/movfuscator.git

FULLNAME=movfuscator-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="movfuscator-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DIR=$(pwd)/movfuscator

git clone "${URL}" "${DIR}"

cd "${DIR}"

./build.sh

mkdir -p "${PREFIX}"
mv build "${PREFIX}/build"

complete "${PREFIX}" "movfuscator-${VERSION}" "${OUTPUT}"
