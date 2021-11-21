#!/bin/bash

set -ex

ROOT=$(pwd)
VERSION=$1

ROOTURL=http://www.erlang.org/download/

if [[ -z "${VERSION}" ]]; then
    echo Please pass a version to this script
    exit
fi

if echo "${VERSION}" | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    URL=https://github.com/erlang/otp
    BRANCH=master
else
    URL=https://github.com/erlang/otp
    BRANCH=OTP-${VERSION}
fi

FULLNAME=erlang-${VERSION}.tar.xz
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

ERLANG_REVISION=$(git ls-remote --heads ${URL} refs/heads/${BRANCH} | cut -f 1)
REVISION="erlang-${ERLANG_REVISION}"
LAST_REVISION="${3}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

SUBDIR=erlang-${VERSION}
STAGING_DIR=/opt/compiler-explorer/erlang-${VERSION}

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

rm -rf "${SUBDIR}"
git clone -q --depth 1 --single-branch -b "${BRANCH}" "${URL}" "${SUBDIR}"

cd "${SUBDIR}"
./configure --prefix="${STAGING_DIR}" --without-termcap
make
make install

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${SUBDIR}/," -C "${STAGING_DIR}" .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
