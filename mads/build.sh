#!/bin/bash

set -ex
source common.sh

VERSION=$1
if [[ "${VERSION}" = "trunk" ]]; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH1=master
    BRANCH2=master
else
    echo "Versioned build not supported"
    return 1
fi

URL1=https://github.com/tebe6502/Mad-Assembler
URL2=https://github.com/tebe6502/Mad-Pascal

FULLNAME=madpas-compiler-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION1="$(get_remote_revision "${URL1}" "heads/${BRANCH1}")"
REVISION2="$(get_remote_revision "${URL2}" "heads/${BRANCH2}")"

REVISION="madpas-compiler-${REVISION1}-${REVISION2}"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix

DCU1=$(pwd)/dcu1
DCU2=$(pwd)/dcu2

DIR1=$(pwd)/madpas-assembler
DIR2=$(pwd)/madpas-compiler

mkdir -p "${DCU1}"
mkdir -p "${DCU2}"

mkdir -p "${PREFIX}/bin"

git clone --depth 1 -b "${BRANCH1}" "${URL1}" "${DIR1}"

cd "$DIR1"
/opt/compiler-explorer/fpc-3.2.2.x86_64-linux/bin/fpc @/opt/compiler-explorer/fpc/fpc.cfg -Mdelphi -vh -O3 "-FE${PREFIX}/bin" "-FU${DCU1}" mads.pas

git clone --depth 1 -b "${BRANCH2}" "${URL2}" "${DIR2}"

cd "$DIR2"
/opt/compiler-explorer/fpc-3.2.2.x86_64-linux/bin/fpc @/opt/compiler-explorer/fpc/fpc.cfg -Mdelphi -vh -O3 "-FE${PREFIX}/bin" "-FU${DCU2}" src/mp.pas

cp -Rf base "${PREFIX}/base"
cp -Rf lib "${PREFIX}/lib"
mkdir -p "${PREFIX}/src"
cp -Rf src/targets "${PREFIX}/src/targets"
mkdir -p "${PREFIX}/blibs"
cp -Rf blibs/*.pas "${PREFIX}/blibs"
mkdir -p "${PREFIX}/dlibs"
cp -Rf dlibs/*.pas "${PREFIX}/dlibs"

complete "${PREFIX}" "madpas-compiler-${VERSION}" "${OUTPUT}"
