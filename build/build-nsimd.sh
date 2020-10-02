#!/bin/bash

set -ex

ROOT=$PWD
VERSION=$1

FULLNAME=nsimd-${VERSION}
OUTPUT=${ROOT}/${FULLNAME}.tar.xz
S3OUTPUT=
if [[ $2 =~ ^s3:// ]]; then
    S3OUTPUT=$2
else
    if [[ -d "${2}" ]]; then
        OUTPUT=$2/${FULLNAME}.tar.xz
    else
        OUTPUT=${2-$OUTPUT}
    fi
fi

mkdir -p /opt/compiler-explorer/arm64
pushd /opt/compiler-explorer
curl -sL https://s3.amazonaws.com/compiler-explorer/opt/gcc-10.2.0.tar.xz | tar Jxf -
curl -sL https://compiler-explorer.s3.amazonaws.com/opt/arm64-gcc-8.2.0.tar.xz | tar Jxf - -C arm64
popd

git clone --depth 1 --single-branch -b "${VERSION}" https://github.com/agenium-scale/nsimd.git
cd nsimd

python3 egg/hatch.py -l
bash scripts/setup.sh

mkdir build
cd build

PREFIX=/opt/compiler-explorer/libs/nsimd/${VERSION}

## x86_64
COMP_ROOT=/opt/compiler-explorer/gcc-10.2.0
CCOMP=${COMP_ROOT}/bin/gcc
CPPCOMP=${COMP_ROOT}/bin/g++

../nstools/bin/nsconfig .. -Dbuild_library_only=true -Dsimd=avx512_skylake \
                            -prefix=${PREFIX}/x86_64 \
                            -Ggnumake \
                            -ccomp=gcc,"${CCOMP}",10.2.0,x86_64 \
                            -cppcomp=gcc,"${CPPCOMP}",10.2.0,x86_64
make
make install

## CUDA
../nstools/bin/nsconfig .. -Dbuild_library_only=true -Dsimd=cuda \
                            -prefix=${PREFIX}/cuda \
                            -Ggnumake \
                            -ccomp=gcc,"${CCOMP}",10.2.0,x86_64 \
                            -cppcomp=gcc,"${CPPCOMP}",10.2.0,x86_64
make
make install

## ARM64
COMP_ROOT=/opt/compiler-explorer/arm64/gcc-8.2.0/aarch64-unknown-linux-gnu/bin
CCOMP=${COMP_ROOT}/aarch64-unknown-linux-gnu-gcc
CPPCOMP=${COMP_ROOT}/aarch64-unknown-linux-gnu-g++

../nstools/bin/nsconfig .. -Dbuild_library_only=true -Dsimd=aarch64 \
                            -prefix=${PREFIX}/aarch64 \
                            -Ggnumake \
                            -ccomp=gcc,"${CCOMP}",8.2.0,aarch64 \
                            -cppcomp=gcc,"${CPPCOMP}",8.2.0,aarch64
make
make install

# Don't try to compress the binaries as they don't like it

export XZ_DEFAULTS="-T 0"
tar Jcf ${OUTPUT} --transform "s,^./,./${FULLNAME}/," -C ${PREFIX} .

if [[ ! -z "${S3OUTPUT}" ]]; then
    s3cmd put --rr ${OUTPUT} ${S3OUTPUT}
fi
