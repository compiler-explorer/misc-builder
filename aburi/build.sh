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
SDK_SDK="MacOSX26.4.sdk"

ABURI_REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
SDK_REVISION=$(get_remote_revision "${SDK_REPO}" "${SDK_BRANCH}")
REVISION="${ABURI_REVISION}_sdk-${SDK_REVISION}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

# Build aburi
git clone --depth 1 "${URL}" --branch "${BRANCH}" aburi-source
cmake -S aburi-source -B aburi-source/build -DCMAKE_BUILD_TYPE=Release -DLLVM_DIR=/usr/lib/llvm-18/lib/cmake/llvm
cmake --build aburi-source/build -j"$(nproc)"

# Fetch macOS SDK headers
git clone --depth 1 --filter=blob:none --sparse "${SDK_REPO}" macos-sdk-repo
git -C macos-sdk-repo sparse-checkout set "${SDK_SDK}/usr/include"

# Stage
STAGING_DIR="${PWD}/stage"
mkdir -p "${STAGING_DIR}/bin"
mkdir -p "${STAGING_DIR}/macos-sdk"
cp aburi-source/build/aburi "${STAGING_DIR}/bin/"
cp -a "macos-sdk-repo/${SDK_SDK}" "${STAGING_DIR}/macos-sdk/"

complete "${STAGING_DIR}" "${FULLNAME}" "${OUTPUT}"
