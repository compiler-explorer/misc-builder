#!/bin/bash

## $1 : version
## $2 : destination: a directory or S3 path (eg. s3://...)

set -ex

ROOT=$PWD
VERSION="${1}"
ROCM_VERSION=rocm-${VERSION}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FULLNAME=hip-amd-${ROCM_VERSION}
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

echo "ce-build-revision:${VERSION}"
echo "ce-build-output:${OUTPUT}"

## From now, no unset variable
set -u

OUTPUT=$(realpath "${OUTPUT}")

OPT=/opt/compiler-explorer
COMP=${OPT}/clang-rocm-${VERSION}
DEST=${OPT}/libs/rocm/${VERSION}

export PATH=${PATH}:/cmake/bin

# comgr
curl -sL https://github.com/RadeonOpenCompute/ROCm-CompilerSupport/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
pushd ROCm-CompilerSupport-${ROCM_VERSION}
cmake -Slib/comgr -Bbuild -DCMAKE_BUILD_TYPE=Release \
  -GNinja \
  -DCMAKE_PREFIX_PATH="${COMP}" \
  -DCMAKE_INSTALL_PREFIX="${DEST}"
ninja -C build
ninja -C build install
popd

# roct-thunk-interface
curl -sL https://github.com/RadeonOpenCompute/ROCT-Thunk-Interface/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
pushd ROCT-Thunk-Interface-${ROCM_VERSION}
cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release \
  -GNinja \
  -DCMAKE_INSTALL_PREFIX="${DEST}"
ninja -C build
ninja -C build install
popd

# rocr-runtime
curl -sL https://github.com/RadeonOpenCompute/ROCR-Runtime/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
pushd ROCR-Runtime-${ROCM_VERSION}
cmake -Ssrc -Bbuild \
  -GNinja \
  -DCMAKE_PREFIX_PATH="${COMP};${DEST}" \
  -DCMAKE_INSTALL_PREFIX="${DEST}"
ninja -C build
ninja -C build install
popd

# hip
git clone --depth 1 https://github.com/ROCm-Developer-Tools/hipamd.git -b ${ROCM_VERSION}
curl -sL https://github.com/ROCm-Developer-Tools/ROCclr/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
curl -sL https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
curl -sL https://github.com/ROCm-Developer-Tools/HIP/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
pushd hipamd
for PATCH_FILE in "${SCRIPT_DIR}"/patches/hipamd-${ROCM_VERSION}-*; do
  if [ -e "${PATCH_FILE}" ]; then
    patch -p1 < "${PATCH_FILE}"
  fi
done
mkdir build
pushd build
cmake -S.. -B. -DCMAKE_BUILD_TYPE=Release \
  -GNinja \
  -DHIP_COMMON_DIR="${ROOT}/HIP-${ROCM_VERSION}" \
  -DAMD_OPENCL_PATH="${ROOT}/ROCm-OpenCL-Runtime-${ROCM_VERSION}" \
  -DROCCLR_PATH="${ROOT}/ROCclr-${ROCM_VERSION}" \
  -DCMAKE_PREFIX_PATH="${COMP};${DEST}" \
  -DCMAKE_INSTALL_PREFIX="${DEST}"
ninja
ninja install
popd # build
popd # hipamd

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${FULLNAME}/," -C "${DEST}" .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
