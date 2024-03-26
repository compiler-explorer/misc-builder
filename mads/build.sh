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

URL=https://github.com/tebe6502/Mad-Pascal

FULLNAME=madpas-compiler-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="madpas-compiler-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DCU=$(pwd)/dcu
DIR=$(pwd)/madpas-compiler

git clone --depth 1 -b "${BRANCH}" "${URL}" "${DIR}"

mkdir -p "${DCU}"
mkdir -p "${PREFIX}/bin"

cd $DIR

/opt/compiler-explorer/fpc-3.2.2.x86_64-linux/bin/fpc @/opt/compiler-explorer/fpc/fpc.cfg -Mdelphi -vh -O3 "-FE${PREFIX}/bin" "-FU${DCU}" src/mp.pas

cp -Rf base "${PREFIX}/base"
cp -Rf lib "${PREFIX}/lib"
mkdir -p "${PREFIX}/src"
cp -Rf src/targets "${PREFIX}/src/targets"
mkdir -p "${PREFIX}/blibs"
cp -Rf blibs/*.pas "${PREFIX}/blibs"
mkdir -p "${PREFIX}/dlibs"
cp -Rf dlibs/*.pas "${PREFIX}/dlibs"

complete "${PREFIX}" "madpas-compiler-${VERSION}" "${OUTPUT}"
