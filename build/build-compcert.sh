#!/bin/bash

## $1 : version (master/x.xx)
## $2 : Arch
## $3 : destination: a directory or S3 path (eg. s3://...)
## $4 : Last revision successfully build (optional)

set -ex

ROOT=$PWD
VERSION="${1}"
ARCH="${2}"
LAST_REVISION="${4-}"
if [[ "${VERSION}" == "master" ]]; then
    VERSION=master-$(date +%Y%m%d)
    BRANCH=heads/master
else 
    BRANCH="tags/v${VERSION}"
fi

URL="https://github.com/AbsInt/CompCert.git"

BASENAME=ccomp-${VERSION}-${ARCH}
FULLNAME=${BASENAME}.tar.xz
OUTPUT=${ROOT}/${FULLNAME}
S3OUTPUT=
if [[ $3 =~ ^s3:// ]]; then
    S3OUTPUT=$3
else
    if [[ -d "${3}" ]]; then
        OUTPUT=$3/${FULLNAME}
    else
        OUTPUT=${3-$OUTPUT}
    fi
fi

REVISION=$(git ls-remote --tags --heads "${URL}" "refs/${BRANCH}" | cut -f 1)
echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

OPT=/opt/compiler-explorer
STAGING_DIR=${OPT}/CompCert-${ARCH}-${VERSION}

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

rm -rf "compcert-${ARCH}-${VERSION}"
git clone "${URL}" "compcert-${ARCH}-${VERSION}"

cd "compcert-${ARCH}-${VERSION}"
eval `opam env`
./configure "${ARCH}-linux" -prefix "${STAGING_DIR}"
make
make install

export XZ_DEFAULTS="-T 0"
tar Jcf ${OUTPUT} --transform "s,^./,./CompCert-${ARCH}-${VERSION}/," -C "${STAGING_DIR}" .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"


