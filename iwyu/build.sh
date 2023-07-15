#!/bin/bash

set -exu
source common.sh

ROOT=$(pwd)
VERSION=$1
CLANGVERSION=16.0.0

if echo "${VERSION}" | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    URL=https://github.com/include-what-you-use/include-what-you-use
    BRANCH=master
    REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
else
    URL=https://github.com/include-what-you-use/include-what-you-use
    BRANCH=${VERSION}
    REVISION=$(get_remote_revision "${URL}" "tags/${BRANCH}")
    if [[ $VERSION == "0.12" ]]; then
        CLANGVERSION=8.0.0
    fi
fi

FULLNAME=iwyu-${VERSION}.tar.xz
OUTPUT=${ROOT}/${FULLNAME}
S3OUTPUT=
if [[ $2 =~ ^s3:// ]]; then
    S3OUTPUT=$2
else
    if [[ -d "${2}" ]]; then
        OUTPUT=$2/${FULLNAME}
    else
        OUTPUT=${2-$OUTPUT}
    fi
fi

LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

STAGING_DIR=/opt/compiler-explorer/iwyu-${VERSION}

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

rm -rf "iwyu-${VERSION}"
git clone -q --depth 1 --single-branch -b "${BRANCH}" "${URL}" "iwyu-${VERSION}"

cd "iwyu-${VERSION}"
mkdir build
cd build
cmake --install-prefix "${STAGING_DIR}" "-DCMAKE_PREFIX_PATH=/opt/compiler-explorer/clang-${CLANGVERSION}" -GNinja ..
cmake --build .
cmake --install .

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./iwyu-${VERSION}/," -C "${STAGING_DIR}" .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
