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

curl -sL https://github.com/python/cpython/archive/refs/tags/v${VERSION}.tar.gz | tar zxf -

SSL_PREFIX=/root/ssl
SSL_VERSION=3.3.2
curl -sL https://github.com/openssl/openssl/releases/download/openssl-${SSL_VERSION}/openssl-${SSL_VERSION}.tar.gz | tar zxf -
pushd openssl-${SSL_VERSION}
./Configure --prefix=${SSL_PREFIX}
make -j$(nproc)
make install_sw
popd

# Python seems to hardcode ssldir/lib and not ssldir/lib64
ln -s lib64 ${SSL_PREFIX}/lib

# The rpath below seems to not quite "take"
export LD_LIBRARY_PATH=${SSL_PREFIX}/lib64

DEST=/root/python

pushd cpython-${VERSION}
./configure \
    --prefix=${DEST} \
    --with-openssl=${SSL_PREFIX} \
    --with-openssl-rpath=${SSL_PREFIX}/lib64 \
    --without-pymalloc \
    --enable-optimizations

make -j$(nproc)
make install
popd

# delete tests and static libraries to save disk space
find ${DEST} -type d -name test -exec rm -rf {} +
find ${DEST} -type f -name '*.a' -delete

PYTHON_SO_DIR=${DEST}/lib/python*/lib-dynload

# copy SSL and any other system dependencies like libffi etc
DEPS=$(env LD_LIBRARY_PATH=${SSL_PREFIX}/lib64 ldd ${PYTHON_SO_DIR}/*.so | grep ' => /' | grep -Ev 'lib(pthread|c|dl|rt)\.so' | awk '{ print $3 }' | sort | uniq)
cp ${DEPS} ${PYTHON_SO_DIR}/

# Patch all the SOs to look in their own directory.
patchelf --set-rpath \$ORIGIN ${PYTHON_SO_DIR}/*.so

# strip executables
find ${DEST} -type f -perm /u+x -exec strip -d {} \;

complete "${DEST}" "${FULLNAME}" "${OUTPUT}"
