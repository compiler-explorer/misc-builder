#!/bin/bash

## $1 : version (master/x.xx)
## $2 : Arch
## $3 : destination: a directory or S3 path (eg. s3://...)
## $4 : Last revision successfully build (optional)

set -exu

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
OUTPUT=$3/${FULLNAME}

REVISION=$(git ls-remote --tags --heads "${URL}" "refs/${BRANCH}" | cut -f 1)
[[ -z "$REVISION" ]] && exit 255

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

# The path to compcert will be hardcoded in a config file (share/compcert.ini).
# This makes the compiler not relocatable without editing this file beforehand.
OPT=/opt/compiler-explorer/compcert
STAGING_DIR=${OPT}/CompCert-${ARCH}-${VERSION}

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

rm -rf "compcert-${ARCH}-${VERSION}"
git clone "${URL}" "compcert-${ARCH}-${VERSION}"

cd "compcert-${ARCH}-${VERSION}"
eval "$(opam env)"
./configure "${ARCH}-linux" -prefix "${STAGING_DIR}"
make "-j$(nproc)"
make install

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./CompCert-${ARCH}-${VERSION}/," -C "${STAGING_DIR}" .

echo "ce-build-status:OK"


