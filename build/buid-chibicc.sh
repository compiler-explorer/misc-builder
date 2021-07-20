#!/bin/bash

## $1 : version, chibicc does not have any and only uses main branch.
## $2 : destination: a directory or S3 path (eg. s3://...)
## $3 : last revision successfully build

set -ex

ROOT=$PWD
VERSION="${1}"
LAST_REVISION="${3}"

if [[ "${VERSION}" != "main" ]]; then
    echo "Only support building main"
    exit 1
fi

URL="https://github.com/rui314/chibicc.git"
BRANCH="main"

REVISION=$(git ls-remote --heads "${URL}" "refs/heads/${BRANCH}" | cut -f 1)
echo "ce-build-revision:${REVISION}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

FULLNAME=chibicc-${VERSION}-$(date +%Y%m%d)

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

rm -rf  build-chibicc
mkdir -p build-chibicc

pushd build-chibicc

git clone --depth 1 "${URL}" --branch "${BRANCH}"
pushd chibicc

make chibicc -j"$(nproc)"

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${FULLNAME}/," ./

if [[ -n "${S3OUTPUT}" ]]; then
    s3cmd put --rr "${OUTPUT}" "${S3OUTPUT}"
fi
popd
popd
