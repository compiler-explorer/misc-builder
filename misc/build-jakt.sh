#!/bin/bash

## $1 : version
## $2 : destination: a directory or S3 path (eg. s3://...)
## $3 : last revision successfully build

# Make sure cargo is in PATH
export PATH="$PATH":"$HOME"/.cargo/bin

set -ex
ROOT=$(pwd)
VERSION="$1"
LAST_REVISION="$3"

if [[ -z "${VERSION}" ]]; then
    echo Please pass a version to this script
    exit
fi

if echo "${VERSION}" | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    URL=https://github.com/SerenityOS/jakt
    BRANCH=main
else
	echo "Versions other than trunk are not currently supported"
	exit 1
fi

FULLNAME=jakt-${VERSION}.tar.xz
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

JAKT_REVISION=$(git ls-remote --heads ${URL} refs/heads/${BRANCH} | cut -f 1)
REVISION="jakt-${JAKT_REVISION}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

SUBDIR=jakt-${VERSION}
STAGING_DIR=/opt/compiler-explorer/jakt-${VERSION}
GXXPATH=/opt/compiler-explorer/gcc-12.1.0
export PATH=${PATH}:/cmake/bin

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

rm -rf "${SUBDIR}"
git clone -q --depth 1 --single-branch -b "${BRANCH}" "${URL}" "${SUBDIR}"

cd "${SUBDIR}"

CXX=${GXXPATH}/bin/g++ cmake -B build -GNinja
cmake --build build

cd build
mv bin "${STAGING_DIR}/"
mv lib "${STAGING_DIR}/"
mv include "${STAGING_DIR}/"
mv ../runtime "${STAGING_DIR}/"
mv ../.clang-format "${STAGING_DIR}/"

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${SUBDIR}/," -C "${STAGING_DIR}" .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
