#!/bin/bash

set -ex
source common.sh

VERSION=$1
if [[ "${VERSION}" = "trunk" ]]; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=main
else
    BRANCH=${VERSION}
fi

URL=https://github.com/Norcroft/ncc-ng

FULLNAME=ncc-ng-${VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz

REVISION="ncc-ng-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DIR=$(pwd)/ncc-ng

git clone --depth 1 -b "${BRANCH}" "${URL}" "${DIR}"

cd "${DIR}"
make all      # builds ncc and n++ (ARM backend)
# TODO: Thumb compilers (ntcc, nt++) fail to build due to missing TOOLVER_TCC in toolver.h
# Uncomment when upstream fixes: make ntcc nt++

mkdir -p "${PREFIX}/bin"
cp bin/* "${PREFIX}/bin/"

complete "${PREFIX}" "${FULLNAME}" "${OUTPUT}"
