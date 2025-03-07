#!/bin/bash

## $1 : version
## $2 : destination: a directory

set -eu
source common.sh

VERSION="${1}"
ROCM_VERSION=rocm-${VERSION}
FULLNAME=hip-amd-${ROCM_VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [[ "${VERSION}" =~ ([0-9]+)\.([0-9]+)\.[^.]+ ]]; then
    ROCM_MAJOR=${BASH_REMATCH[1]}
    ROCM_MINOR=${BASH_REMATCH[2]}
    ROCM_MAJOR_MINOR=$(( ROCM_MAJOR * 100 + ROCM_MINOR ))
fi

initialise "${VERSION}" "${OUTPUT}"

OUTPUT=$(realpath "${OUTPUT}")

OPT=/opt/compiler-explorer

# update infra
pushd ${OPT}/infra
git pull
make ce
popd

# install the clang-rocm compiler that matches the version
${OPT}/infra/bin/ce_install install "clang-rocm ${VERSION}"

COMP=${OPT}/clang-rocm-${VERSION}
DEST=${OPT}/libs/rocm/${VERSION}

rm -rf llvm-project-$ROCM_VERSION ROCm-Device-Libs-$ROCM_VERSION ROCm-CompilerSupport-$ROCM_VERSION HIPCC-$ROCM_VERSION
if (( ROCM_MAJOR_MINOR < 601 )); then
    curl -sL https://github.com/ROCm/ROCm-Device-Libs/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
    curl -sL https://github.com/ROCm/ROCm-CompilerSupport/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
    curl -sL https://github.com/ROCm/HIPCC/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
else
    git clone --depth 1 --single-branch -b "$ROCM_VERSION" "https://github.com/ROCm/llvm-project.git" "llvm-project-$ROCM_VERSION"
    ln -fs llvm-project-$ROCM_VERSION/amd/device-libs ROCm-Device-Libs-$ROCM_VERSION
    mkdir -p ROCm-CompilerSupport-$ROCM_VERSION/lib
    ln -fs ../../llvm-project-$ROCM_VERSION/amd/comgr ROCm-CompilerSupport-$ROCM_VERSION/lib/comgr
    ln -fs llvm-project-$ROCM_VERSION/amd/hipcc HIPCC-$ROCM_VERSION
fi

# ROCm-Device-Libs
pushd ROCm-Device-Libs-${ROCM_VERSION}
for PATCH_FILE in "${SCRIPT_DIR}"/patches/ROCm-Device-Libs-${ROCM_VERSION}-*; do
  if [ -e "${PATCH_FILE}" ]; then
    patch -p1 < "${PATCH_FILE}"
  fi
done
cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release \
  -GNinja \
  -DCMAKE_PREFIX_PATH="${COMP}" \
  -DCMAKE_INSTALL_PREFIX="${COMP}"
ninja -C build
ninja -C build install
mkdir -p "$DEST"
cp -r "$COMP"/amdgcn "$DEST"
popd

# comgr
pushd ROCm-CompilerSupport-${ROCM_VERSION}
cmake -Slib/comgr -Bbuild -DCMAKE_BUILD_TYPE=Release \
  -GNinja \
  -DBUILD_TESTING=OFF \
  -DCMAKE_PREFIX_PATH="${COMP}" \
  -DCMAKE_INSTALL_PREFIX="${DEST}"
ninja -C build
ninja -C build install
popd

# hipcc
pushd HIPCC-${ROCM_VERSION}
cmake -S. -Bbuild \
  -GNinja \
  -DCMAKE_PREFIX_PATH="${COMP};${DEST}" \
  -DCMAKE_INSTALL_PREFIX="${DEST}"
ninja -C build
ninja -C build install
popd

# roct-thunk-interface
if (( ROCM_MAJOR_MINOR < 603 )); then
  curl -sL https://github.com/ROCm/ROCT-Thunk-Interface/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
  pushd ROCT-Thunk-Interface-${ROCM_VERSION}
  cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release \
    -GNinja \
    -DCMAKE_INSTALL_PREFIX="${DEST}"
  ninja -C build
  ninja -C build install
  popd
fi

# rocr-runtime
curl -sL https://github.com/ROCm/ROCR-Runtime/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
pushd ROCR-Runtime-${ROCM_VERSION}
if (( ROCM_MAJOR_MINOR < 603 )); then
  SRC=src
else
  SRC=.
fi
cmake -S${SRC} -Bbuild \
  -GNinja \
  -DCMAKE_PREFIX_PATH="${COMP};${DEST}" \
  -DCMAKE_INSTALL_PREFIX="${DEST}"
ninja -C build
ninja -C build install
popd


# hip
if (( ROCM_MAJOR_MINOR >= 507 )); then
  curl -sL https://github.com/ROCm/clr/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
else
  git clone --depth 1 https://github.com/ROCm/hipamd.git -b ${ROCM_VERSION}
  curl -sL https://github.com/ROCm/ROCclr/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
  curl -sL https://github.com/ROCm/ROCm-OpenCL-Runtime/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz
fi
curl -sL https://github.com/ROCm/HIP/archive/refs/tags/${ROCM_VERSION}.tar.gz | tar xz

if (( ROCM_MAJOR_MINOR >= 507 )); then
  pushd clr-${ROCM_VERSION}
  for PATCH_FILE in "${SCRIPT_DIR}"/patches/hipamd-${ROCM_VERSION}-*; do
  if [ -e "${PATCH_FILE}" ]; then
    patch -p1 < "${PATCH_FILE}"
  fi
  done
  mkdir -p build
  pushd build
  cmake -S.. -B. -DCMAKE_BUILD_TYPE=Release \
    -GNinja \
    -DHIP_COMMON_DIR="${SCRIPT_DIR}/HIP-${ROCM_VERSION}" \
    -DCLR_BUILD_HIP=ON \
    -DCLR_BUILD_OCL=OFF \
    -DCMAKE_PREFIX_PATH="${COMP};${DEST}" \
    -DCMAKE_INSTALL_PREFIX="${DEST}" \
    -DUSE_PROF_API=OFF \
    -DHIP_PLATFORM=amd \
    -DHIPCC_BIN_DIR="${DEST}/bin"

else
  pushd hipamd
  for PATCH_FILE in "${SCRIPT_DIR}"/patches/hipamd-${ROCM_VERSION}-*; do
    if [ -e "${PATCH_FILE}" ]; then
      patch -p1 < "${PATCH_FILE}"
    fi
  done
  mkdir -p build
  pushd build
  cmake -S.. -B. -DCMAKE_BUILD_TYPE=Release \
    -GNinja \
    -DHIP_COMMON_DIR="${SCRIPT_DIR}/HIP-${ROCM_VERSION}" \
    -DAMD_OPENCL_PATH="${SCRIPT_DIR}/ROCm-OpenCL-Runtime-${ROCM_VERSION}" \
    -DROCCLR_PATH="${SCRIPT_DIR}/ROCclr-${ROCM_VERSION}" \
    -DCMAKE_PREFIX_PATH="${COMP};${DEST}" \
    -DCMAKE_INSTALL_PREFIX="${DEST}" \
    -DUSE_PROF_API=OFF
fi
ninja
ninja install
popd # build
popd # hipamd

complete "${DEST}" "${FULLNAME}" "${OUTPUT}"
