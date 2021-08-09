#!/bin/bash

## $1 : version, clspv does not have any and only uses master branch.
## $2 : destination: a directory or S3 path (eg. s3://...)
## $3 : last revision successfully build

set -ex

ROOT=$PWD
VERSION="${1}"
LAST_REVISION="${3}"

if [[ "${VERSION}" != "master" ]]; then
    echo "Only support building master"
    exit 1
fi

URL="https://github.com/google/clspv.git"
BRANCH="master"

REVISION=$(git ls-remote --heads "${URL}" "refs/heads/${BRANCH}" | cut -f 1)
echo "ce-build-revision:${REVISION}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

FULLNAME=clspv-${VERSION}-$(date +%Y%m%d)

OUTPUT=${ROOT}/${FULLNAME}.tar.xz
S3OUTPUT=
if [[ $2 =~ ^s3:// ]]; then
    S3OUTPUT=$2
else
    if [[ -d "${2}" ]]; then
        OUTPUT=$2/${FULLNAME}.tar.xz
    else
        OUTPUT=${2-$OUTPUT}
    fi
fi

## From now, no unset variable
set -u

OUTPUT=$(realpath "${OUTPUT}")
STAGING_DIR=/opt/compiler-explorer/clspv-master

mkdir -p "${STAGING_DIR}"

git clone --depth 1 "${URL}" --branch "${BRANCH}"
pushd clspv

python3 utils/fetch_sources.py

mkdir build
cmake -S . -B build -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="${STAGING_DIR}"
cmake --build build --parallel $(nproc)

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${FULLNAME}/," -C "./${STAGING_DIR}" .

if [[ -n "${S3OUTPUT}" ]]; then
    s3cmd put --rr "${OUTPUT}" "${S3OUTPUT}"
fi
popd
