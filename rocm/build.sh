#!/bin/bash

## $1 : version
## $2 : destination: a directory

set -eu
source common.sh

VERSION="${1}"
ROCM_VERSION=rocm-${VERSION}
FULLNAME=hip-amd-${ROCM_VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz

initialise "${VERSION}" "${OUTPUT}"

OUTPUT=$(realpath "${OUTPUT}")

OPT=/opt/compiler-explorer
${OPT}/infra/bin/ce_install install "clang-rocm ${VERSION}"
COMP=${OPT}/clang-rocm-${VERSION}
DEST=${OPT}/libs/rocm/${VERSION}

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
if [ "$VERSION" == "5.7.0" ]; then
  curl -sL https://github.com/ROCm-Developer-Tools/clr/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
else
  git clone --depth 1 https://github.com/ROCm-Developer-Tools/hipamd.git -b ${ROCM_VERSION}
  curl -sL https://github.com/ROCm-Developer-Tools/ROCclr/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
  curl -sL https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
fi
curl -sL https://github.com/ROCm-Developer-Tools/HIP/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz

if [ "$VERSION" == "5.7.0" ]; then
  pushd clr-${ROCM_VERSION}/hipamd
  mkdir build
  pushd build
  cmake -S.. -B. -DCMAKE_BUILD_TYPE=Release \
    -GNinja \
    -DHIP_COMMON_DIR="${ROOT}/HIP-${ROCM_VERSION}" \
    -DAMD_OPENCL_PATH="${ROOT}/clr-${ROCM_VERSION}/opencl" \
    -DROCCLR_PATH="${ROOT}/clr-${ROCM_VERSION}/rocclr" \
    -DCMAKE_PREFIX_PATH="${COMP};${DEST}" \
    -DCMAKE_INSTALL_PREFIX="${DEST}" \
    -DUSE_PROF_API=OFF
else
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
    -DCMAKE_INSTALL_PREFIX="${DEST}" \
    -DUSE_PROF_API=OFF
fi
ninja
ninja install
popd # build
popd # hipamd

complete "${DEST}" "${FULLNAME}" "${OUTPUT}"
