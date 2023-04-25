#!/bin/bash

set -ex
source common.sh

PROJNAME=clean
URL=https://gitlab.science.ru.nl/clean-and-itasks/clean-build.git

VERSION=$1

if [[ "${VERSION}" != "trunk" ]]; then
    echo "Only support building trunk"
    exit 1
fi

VERSION=trunk-$(date +%Y%m%d)
BRANCH=master

CHECKURL2=https://gitlab.science.ru.nl/clean-and-itasks/clean-libraries.git
CHECKURL3=https://gitlab.science.ru.nl/clean-compiler-and-rts/compiler.git
CHECKURL4=https://gitlab.science.ru.nl/clean-and-itasks/clm.git

REVISION1=$(get_remote_revision "${URL}" "heads/${BRANCH}")
REVISION2=$(get_remote_revision "${CHECKURL2}" "heads/master")
REVISION3=$(get_remote_revision "${CHECKURL3}" "heads/master")
REVISION4=$(get_remote_revision "${CHECKURL4}" "heads/master")
REVISION=${REVISION1}-${REVISION2}-${REVISION3}-${REVISION4}

PROJVERSION=${PROJNAME}-${VERSION}
OUTPUT=$2/${PROJVERSION}.tar.xz
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

STARTDIR=$(pwd)
DIR=${STARTDIR}/${PROJNAME}
git clone --depth 1 -b ${BRANCH} ${URL} ${DIR}

export CLEANDATE="$(date +%Y-%m-%d)"

PREFIX=/root/clean/target/clean-classic
cd ${DIR}

# download and install Clean 3.1
./clean-classic/linux-x64/setup.sh
# download sources and build
./clean-classic/linux-x64/build.sh

complete "${PREFIX}" "${PROJVERSION}" "${OUTPUT}"
