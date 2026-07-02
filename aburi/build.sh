#!/bin/bash

set -ex
source common.sh

VERSION="${1}"
LAST_REVISION="${3-}"

if [[ "${VERSION}" != "atta-mills" ]]; then
    echo "Only support building atta-mills branch"
    exit 1
fi

FULLNAME=aburi-${VERSION}
OUTPUT=$(realpath "$2/${FULLNAME}.tar.xz")

URL="https://github.com/serjective/aburi.git"
BRANCH="atta-mills"
SDK_REPO="https://github.com/alexey-lysiuk/macos-sdk.git"
SDK_BRANCH="heads/main"

ABURI_REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
SDK_REVISION=$(get_remote_revision "${SDK_REPO}" "${SDK_BRANCH}")
REVISION="${ABURI_REVISION}_sdk-${SDK_REVISION}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

# Build aburi
git clone --depth 1 "${URL}" --branch "${BRANCH}" aburi-source
cmake -S aburi-source -B aburi-source/build -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
cmake --build aburi-source/build -j"$(nproc)"

# Fetch macOS SDK headers. Pick the newest MacOSX*.sdk the repo currently ships
# rather than pinning a version: upstream rolls forward (e.g. 26.4 -> 26.5) and a
# hardcoded name silently breaks this build the moment it's removed.
git clone --depth 1 --filter=blob:none --sparse "${SDK_REPO}" macos-sdk-repo
SDK_SDK=$(git -C macos-sdk-repo ls-tree -d --name-only HEAD | grep -E '^MacOSX[0-9.]+\.sdk$' | sort -V | tail -1)
if [[ -z "${SDK_SDK}" ]]; then
    echo "No MacOSX*.sdk directory found in ${SDK_REPO}" >&2
    exit 1
fi
echo "Using macOS SDK: ${SDK_SDK}"
git -C macos-sdk-repo sparse-checkout set "${SDK_SDK}/usr/include"

# Stage. Install the SDK to a fixed, version-independent path (macos-sdk/) so the
# compiler's --sysroot never changes when the SDK version rolls forward.
STAGING_DIR="${PWD}/stage"
mkdir -p "${STAGING_DIR}/bin"
mkdir -p "${STAGING_DIR}/macos-sdk"
cp aburi-source/build/aburi "${STAGING_DIR}/bin/"
cp -a "macos-sdk-repo/${SDK_SDK}/." "${STAGING_DIR}/macos-sdk/"

complete "${STAGING_DIR}" "${FULLNAME}" "${OUTPUT}"
