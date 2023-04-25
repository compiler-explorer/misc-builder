#!/bin/bash

## $1 : version, chibicc does not have any and only uses main branch.
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

URL="https://github.com/rui314/chibicc.git"
BRANCH="main"
REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")

FULLNAME=chibicc-${VERSION}-$(date +%Y%m%d)
OUTPUT=$(realpath "$2/${FULLNAME}.tar.xz")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

git clone --depth 1 "${URL}" --branch "${BRANCH}"

make -C chibicc chibicc -j"$(nproc)"

complete chibicc "${FULLNAME}" "${OUTPUT}" 
