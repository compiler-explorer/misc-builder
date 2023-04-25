#!/bin/bash

## $1 : version, clspv does not have any and only uses main branch.
## $2 : destination: a directory
## $3 : last revision successfully build

set -ex
source common.sh

VERSION="${1}"
LAST_REVISION="${3:-}"

if [[ "${VERSION}" != "main" ]]; then
    echo "Only support building main"
    exit 1
fi

URL="https://github.com/google/clspv.git"
BRANCH="main"

REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
FULLNAME=clspv-${VERSION}-$(date +%Y%m%d)
OUTPUT=$2/${FULLNAME}.tar.xz

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

OUTPUT=$(realpath "${OUTPUT}")
STAGING_DIR=/opt/compiler-explorer/clspv-main

mkdir -p "${STAGING_DIR}"

git clone --depth 1 "${URL}" --branch "${BRANCH}"
cd clspv

python3 utils/fetch_sources.py --shallow

mkdir build
cmake -S . -B build -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH="${STAGING_DIR}"
cmake --build build --parallel $(nproc)
cmake --install build

complete "${STAGING_DIR}" "${FULLNAME}" "${OUTPUT}"
