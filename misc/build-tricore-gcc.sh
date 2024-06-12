#!/bin/bash

set -ex

ROOT=$(pwd)
VERSION=$1
LAST_REVISION="${3}"

if echo ${VERSION} | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=main
else
    # currently only version 11.3.1 is available
    VERSION='11.3.1'
    BRANCH=main
fi

URL=https://github.com/EEESlab/tricore-gcc-toolchain-11.3.0.git

FULLNAME=tricore-gcc-${VERSION}.tar.xz
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

REVISION=$(git ls-remote --heads "${URL}" "refs/heads/${BRANCH}" | cut -f 1)
echo "ce-build-revision:${REVISION}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

PREFIX=$(pwd)/tricore-gcc-${VERSION}/INSTALL
DIR=$(pwd)/tricore-gcc-${VERSION}
rm -rf ${DIR}
git clone -q --recursive --depth 1 -b ${BRANCH} ${URL} ${DIR}

echo "Downloading prerequisites"
pushd ${DIR}/tricore-gcc
if [[ -f ./contrib/download_prerequisites ]]; then
    ./contrib/download_prerequisites
fi
popd

cd ${DIR}
./build-toolchain --all

export XZ_DEFAULTS="-T 0"
tar Jcf ${OUTPUT} --transform "s,^./,./tricore-gcc-${VERSION}/," -C ${PREFIX} .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"