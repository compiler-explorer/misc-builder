#!/usr/bin/env bash

## $1 : version (master/x.xx)
## $2 : Arch
## $3 : destination: a directory or S3 path (eg. s3://...)
## $4 : Last revision successfully build (optional)

set -exu
source common.sh

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

FULLNAME=CompCert-${ARCH}-${VERSION}
OUTPUT=$3/ccomp-${VERSION}-${ARCH}.tar.xz

REVISION=$(get_remote_revision "${URL}" "${BRANCH}")
initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

# The path to compcert will be hardcoded in a config file (share/compcert.ini).
# This makes the compiler not relocatable without editing this file beforehand.
OPT=/opt/compiler-explorer/compcert
STAGING_DIR=${OPT}/${FULLNAME}

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

rm -rf "compcert-${ARCH}-${VERSION}"
git clone "${URL}" "compcert-${ARCH}-${VERSION}"

cd "compcert-${ARCH}-${VERSION}"
eval "$(opam env)"
./configure "${ARCH}-linux" -prefix "${STAGING_DIR}"
make "-j$(nproc)"
make install

complete "${STAGING_DIR}" "${FULLNAME}" "${OUTPUT}"
