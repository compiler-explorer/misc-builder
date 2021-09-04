#!/bin/bash

set -ex

PROJNAME=clean
URL=https://gitlab.science.ru.nl/clean-and-itasks/clean-build.git

VERSION=$1
if echo ${VERSION} | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
    LAST_REVISION="${3}"

    CHECKURL2=https://gitlab.science.ru.nl/clean-and-itasks/clean-libraries.git
    CHECKURL3=https://gitlab.science.ru.nl/clean-compiler-and-rts/compiler.git
    CHECKURL4=https://gitlab.science.ru.nl/clean-and-itasks/clm.git

    REVISION1=$(git ls-remote --heads "${URL}" "refs/heads/${BRANCH}" | cut -f 1)
    REVISION2=$(git ls-remote --heads "${CHECKURL2}" "refs/heads/master" | cut -f 1)
    REVISION3=$(git ls-remote --heads "${CHECKURL3}" "refs/heads/master" | cut -f 1)
    REVISION4=$(git ls-remote --heads "${CHECKURL4}" "refs/heads/master" | cut -f 1)
    REVISION=${REVISION1}-${REVISION2}-${REVISION3}-${REVISION4}
    echo "ce-build-revision:${REVISION}"

    if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
        echo "ce-build-status:SKIPPED"
        exit
    fi
else
    echo "Only builds trunk"
    exit
fi

PROJVERSION=${PROJNAME}-${VERSION}

OUTPUT=/root/${PROJVERSION}.tar.xz
S3OUTPUT=""
if echo $2 | grep s3://; then
    S3OUTPUT=$2
else
    OUTPUT=${2-/root/${PROJVERSION}.tar.xz}
fi

STARTDIR=$(pwd)
DIR=${STARTDIR}/${PROJNAME}
git clone --depth 1 -b ${BRANCH} ${URL} ${DIR}

export CLEANDATE="$(date +%Y-%m-%d)"

PREFIX=/root/clean/build
cd ${DIR}

./generic/cleanup.sh
./generic/setup.sh clean-bundle-complete linux x64
${STARTDIR}/custom-clean-fetch.sh clean-bundle-complete linux x64
./generic/build.sh clean-bundle-complete linux x64

export XZ_DEFAULTS="-T 0"

tar Jcf ${OUTPUT} --transform "s,^./,./${PROJVERSION}/," -C ${PREFIX}/clean .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi
