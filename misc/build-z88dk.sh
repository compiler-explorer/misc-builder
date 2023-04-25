#!/bin/bash

set -ex
source common.sh

VERSION=$1
if echo ${VERSION} | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
else
    BRANCH=v${VERSION}
fi

URL=https://github.com/z88dk/z88dk.git

FULLNAME=z88dk-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

GIT_REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
REVISION="z88dk-${GIT_REVISION}"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

pip3 install conan==1.59.0

PREFIX=$(pwd)/prefix
DIR=$(pwd)/z88dk
export BUILD_SDCC=1
export BUILD_SDCC_HTTP=1 

mkdir -p ${PREFIX}

git clone --branch ${BRANCH} --depth 1 --recursive ${URL} ${DIR}

cd ${DIR}

echo -e "[requires]\nboost/1.79.0\n[generators]\npkg_config\n" > ./conanfile.txt
conan install .
ls -l
export PKG_CONFIG_PATH=/usr/lib/pkgconfig:${DIR}
export CXXFLAGS=$(pkg-config boost --cflags)

./build.sh -i ${PREFIX}
make install DESTDIR=${PREFIX}

complete "${PREFIX}" "${FULLNAME}" "${OUTPUT}"
