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

fetch() {
    # We've had so many problems with pipes on the admin box. This is terrible,
    # but is reliable. I tried using buffer(1) and mbuffer(1), but they didn't
    # work either.
    local temp="$(mktemp)"
    curl -s ${http_proxy:+--proxy $http_proxy} -L "$*" -o "$temp"
    cat "$temp"
    rm "$temp"
}

install_cuda() {
    local URL=$1
    mkdir -p cuda
    pushd cuda
    local DIR=$(pwd)/$2
    if [[ ! -d ${DIR} ]]; then
        rm -rf /tmp/cuda
        mkdir -p /tmp/cuda
        fetch ${URL} >/tmp/cuda/combined.sh
        sh /tmp/cuda/combined.sh --extract=/tmp/cuda
        local LINUX=$(ls -1 /tmp/cuda/cuda-linux.$2*.run 2>/dev/null || true)
        if [[ -f ${LINUX} ]]; then
            ${LINUX} --prefix=${DIR} -noprompt -nosymlink -no-man-page
        else
            # As of CUDA 10.1, the toolkit is already extracted here.
            mv /tmp/cuda/cuda-toolkit ${DIR}
        fi
        rm -rf /tmp/cuda
    fi
    popd
}

mkdir -p /opt/compiler-explorer/arm
mkdir -p /opt/compiler-explorer/arm64
pushd /opt/compiler-explorer
curl -sL https://s3.amazonaws.com/compiler-explorer/opt/gcc-6.1.0.tar.xz | tar Jxf -
curl -sL https://s3.amazonaws.com/compiler-explorer/opt/gcc-10.2.0.tar.xz | tar Jxf -
curl -sL https://compiler-explorer.s3.amazonaws.com/opt/arm-gcc-8.2.0.tar.xz | tar Jxf - -C arm
curl -sL https://compiler-explorer.s3.amazonaws.com/opt/arm64-gcc-8.2.0.tar.xz | tar Jxf - -C arm64
install_cuda https://developer.nvidia.com/compute/cuda/9.1/Prod/local_installers/cuda_9.1.85_387.26_linux 9.1.85
popd

git clone --depth 1 --single-branch -b "${VERSION}" https://github.com/agenium-scale/nsimd.git
cd nsimd

python3 egg/hatch.py -l
bash scripts/setup.sh

mkdir build
cd build

PREFIX=/opt/compiler-explorer/libs/nsimd/${VERSION}

## x86_64
export PATH=/opt/compiler-explorer/gcc-10.2.0/bin:${PATH}
../nstools/bin/nsconfig .. -Dbuild_library_only=true -Dsimd=avx512_skylake \
                        -prefix=${PREFIX}/x86_64 \
                        -Ggnumake \
                        -suite=gcc
make
make install

## CUDA
export PATH=/opt/compiler-explorer/cuda/9.1.85/bin:/opt/compiler-explorer/gcc-6.1.0/bin:${PATH}
../nstools/bin/nsconfig .. -Dbuild_library_only=true -Dsimd=cuda \
                            -prefix=${PREFIX}/cuda \
                            -Ggnumake \
                            -Dstatic_libstdcpp=true \
                            -suite=cuda
make
make install

## ARM32 (armel)
COMP_ROOT=/opt/compiler-explorer/arm/gcc-8.2.0/arm-unknown-linux-gnueabi/bin
CCOMP=${COMP_ROOT}/arm-unknown-linux-gnueabi-gcc
CPPCOMP=${COMP_ROOT}/arm-unknown-linux-gnueabi-g++

../nstools/bin/nsconfig .. -Dbuild_library_only=true -Dsimd=neon128 \
                            -prefix=${PREFIX}/arm/neon128 \
                            -Ggnumake \
                            -comp=cc,gcc,"${CCOMP}",8.2.0,armel \
                            -comp=c++,gcc,"${CPPCOMP}",8.2.0,armel
make
make install

## ARM64
COMP_ROOT=/opt/compiler-explorer/arm64/gcc-8.2.0/aarch64-unknown-linux-gnu/bin
CCOMP=${COMP_ROOT}/aarch64-unknown-linux-gnu-gcc
CPPCOMP=${COMP_ROOT}/aarch64-unknown-linux-gnu-g++

../nstools/bin/nsconfig .. -Dbuild_library_only=true -Dsimd=aarch64 \
                            -prefix=${PREFIX}/arm/aarch64 \
                            -Ggnumake \
                            -comp=cc,gcc,"${CCOMP}",8.2.0,aarch64 \
                            -comp=c++,gcc,"${CPPCOMP}",8.2.0,aarch64
make
make install

# Don't try to compress the binaries as they don't like it

export XZ_DEFAULTS="-T 0"
tar Jcf ${OUTPUT} --transform "s,^./,./${FULLNAME}/," -C ${PREFIX} .

if [[ ! -z "${S3OUTPUT}" ]]; then
    s3cmd put --rr ${OUTPUT} ${S3OUTPUT}
fi
