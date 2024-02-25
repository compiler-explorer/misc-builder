#!/usr/bin/env bash

set -exu
source common.sh

VERSION="$1"

ROOT=$(pwd)
FULLNAME=pythran-${VERSION}.tar.xz
OUTPUT=${ROOT}/${FULLNAME}

if [[ -d "${2}" ]]; then
   OUTPUT=$2/${FULLNAME}
else
   OUTPUT=${2-$OUTPUT}
fi

STAGING_DIR="/opt/compiler-explorer/pythran/pythran-${VERSION}"

conda init

eval "$(conda shell.bash hook)"
conda activate base

conda install conda-build -y
conda deactivate

PACKAGES="gcc_linux-64 \
    gxx_linux-64 \
    libgfortran-ng \
    libgfortran5 \
    libgcc-ng \
    libgomp \
    libstdcxx-ng"

pushd /root/scratch
conda build .
popd

mkdir -p $(dirname "$STAGING_DIR")

conda create -y -p "$STAGING_DIR"

## This may need some fine tuning if pythran bumps its dep on gcc from 13.2 to
## something different.

for P in $PACKAGES; do
    conda install -y --use-local "$P=13.2.0=external*" -p "$STAGING_DIR"
done

conda install -y -c conda-forge pythran="$VERSION" -p "$STAGING_DIR"

complete "${STAGING_DIR}" "pythran-${VERSION}" "${OUTPUT}"
