#!/bin/bash

set -exu
source common.sh

ROOT=$(pwd)
VERSION=$1
FULLNAME=python-${VERSION}
OUTPUT=${ROOT}/${FULLNAME}.tar.xz
LAST_REVISION="${3:-}"

if [[ -d "${2}" ]]; then
   OUTPUT=$2/${FULLNAME}.tar.xz
else
   OUTPUT=${2-$OUTPUT}
fi

REVISION="python-${VERSION}"
initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

DEST=/root/built

curl -sL https://www.python.org/ftp/python/${VERSION}/Python-${VERSION}.tgz | tar zxf -
pushd Python-${VERSION}
./configure \
    --prefix=${DEST} \
    --enable-optimizations \
    --without-pymalloc

make -j$(nproc)
make install
popd

# strip executables
find ${DEST} -type f -perm /u+x -exec strip -d {} \;

# delete tests and static libraries to save disk space
find ${DEST} -type d -name test -exec rm -rf {} +
find ${DEST} -type f -name *.a -delete

complete "${DEST}" "${FULLNAME}" "${OUTPUT}"
