#!/bin/bash

## $1 : version
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

URL="https://github.com/KhronosGroup/SPIRV-Tools.git"
BRANCH="master"

FULLNAME=SPIRV-Tools-${VERSION}-$(date +%Y%m%d)
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

REVISION=$(git ls-remote --heads "${URL}" "refs/heads/${BRANCH}" | cut -f 1)
echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

## From now, no unset variable
set -u

OUTPUT=$(realpath "${OUTPUT}")

export PATH=${PATH}:/cmake/bin

git clone --depth 1 "${URL}" --branch "${BRANCH}"
pushd SPIRV-Tools

./utils/git-sync-deps

mkdir build
cmake -S . -B build -G "Unix Makefiles"
cmake --build build --parallel $(nproc)

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${FULLNAME}/," ./

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

popd

echo "ce-build-status:OK"
