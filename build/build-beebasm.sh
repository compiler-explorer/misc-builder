#!/bin/bash

set -ex

ROOT=$(pwd)
VERSION=$1
if echo ${VERSION} | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
else
    BRANCH=v${VERSION}
fi

URL=https://github.com/stardot/beebasm

FULLNAME=beebasm-${VERSION}.tar.xz
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

BEEBASM_REVISION=$(git ls-remote --heads ${URL} refs/heads/${BRANCH} | cut -f 1)
REVISION="beebasm-${BEEBASM_REVISION}"
LAST_REVISION="${3}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

PREFIX=$(pwd)/prefix
DIR=$(pwd)/beebasm
git clone --depth 1 -b ${BRANCH} ${URL} ${DIR}

cd ${DIR}/src
make all
mkdir -p ${PREFIX}
cd ..
cp beebasm ${PREFIX}

export XZ_DEFAULTS="-T 0"
tar Jcf ${OUTPUT} --transform "s,^./,./beebasm-${VERSION}/," -C ${PREFIX} .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
