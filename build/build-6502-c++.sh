#!/bin/bash

set -ex

ROOT=$(pwd)
VERSION=$1
if echo ${VERSION} | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
else
    BRANCH=V${VERSION}
fi

URL=https://github.com/lefticus/6502-cpp.git

FULLNAME=6502-c++-${VERSION}.tar.xz
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

GIT_REVISION=$(git ls-remote --heads ${URL} refs/heads/${BRANCH} | cut -f 1)
REVISION="6502-c++-${GIT_REVISION}"
LAST_REVISION="${3}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

PREFIX=$(pwd)/prefix
DIR=$(pwd)/6502-c++
BUILDDIR=${DIR}/build

OPT=/opt/compiler-explorer
GXXPATH=/opt/compiler-explorer/gcc-12.1.0

git clone ${URL} ${DIR}

mkdir ${BUILDDIR}
cd ${BUILDDIR}

CXX=${GXXPATH}/bin/g++ cmake ..
make 6502-c++

patchelf --set-rpath /opt/compiler-explorer/gcc-12.1.0/lib64 bin/6502-c++

mkdir -p ${PREFIX}/6502-c++
mv bin ${PREFIX}/6502-c++/bin

export XZ_DEFAULTS="-T 0"
tar Jcf ${OUTPUT} --transform "s,^./,./6502-c++-${VERSION}/," -C ${PREFIX} .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
