#!/bin/bash

set -ex

ROOT=$(pwd)
VERSION=$1

if echo "${VERSION}" | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    URL=git://repo.or.cz/tinycc.git
    BRANCH=mob
else
    MAJOR=$(echo "${VERSION}" | grep -oE '^[0-9]+')
    MAJOR_MINOR_BUILD=$(echo "${VERSION}" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')
    MINOR=$(echo "${MAJOR_MINOR_BUILD}" | cut -d. -f2)
    BUILD=$(echo "${MAJOR_MINOR_BUILD}" | cut -d. -f3)
    VERSION_UNDERSCORES="${MAJOR}_${MINOR}_${BUILD}"
    URL=git://repo.or.cz/tinycc.git
    BRANCH=release_${VERSION_UNDERSCORES}
fi

OUTPUT=/root/tinycc-${VERSION}.tar.xz
S3OUTPUT=""
if echo "$2" | grep s3://; then
    S3OUTPUT=$2
else
    OUTPUT=${2-/root/tinycc-${VERSION}.tar.xz}
fi

TINYCC_REVISION=$(git ls-remote --heads ${URL} refs/heads/${BRANCH} | cut -f 1)
REVISION="tinycc-${TINYCC_REVISION}"
LAST_REVISION="${3}"

echo "ce-build-revision:${REVISION}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

STAGING_DIR=/opt/compiler-explorer/tinycc-${VERSION}

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

rm -rf "tinycc-${VERSION}"
git clone -q --depth 1 --single-branch -b "${BRANCH}" "${URL}" "tinycc-${VERSION}"

cd "tinycc-${VERSION}"
./configure --prefix="${STAGING_DIR}"
make
make install

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./tinycc-${VERSION}/," -C "${STAGING_DIR}" .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi
