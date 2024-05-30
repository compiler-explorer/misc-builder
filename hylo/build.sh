#!/bin/bash

## $1 : version
## $2 : destination: a directory
## $3 : last revision: a revision descriptor which may be fetched from the cache.

set -exu
source common.sh

ROOT=$(pwd)
VERSION=$1
URL="https://github.com/hylo-lang/hylo"

if echo "${VERSION}" | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=main
    REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
else
    BRANCH=${VERSION}
    REVISION=$(get_remote_revision "${URL}" "tags/${BRANCH}")
fi

FULLNAME=hylo-${VERSION}.tar.xz
OUTPUT=${ROOT}/${FULLNAME}
LAST_REVISION="${3:-}"

if [[ -d "${2}" ]]; then
   OUTPUT=$2/${FULLNAME}
else
   OUTPUT=${2-$OUTPUT}
fi

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

rm -rf "hylo-${VERSION}"
git clone -q --depth 1 --single-branch --recursive -b "${BRANCH}" "${URL}" "hylo-${VERSION}"

cd "hylo-${VERSION}"
swift package resolve
.build/checkouts/Swifty-LLVM/Tools/make-pkgconfig.sh /usr/local/lib/pkgconfig/llvm.pc
./Tools/set-hc-version.sh
swift build --static-swift-stdlib -c release --product hc

# Copy all shared object dependencies into the release directory to create a hermetic build, per
# Compiler Explorer requirements. Update rpath for these objects to $ORIGIN.
# To ensure we only muck with rpaths for these objects, do this work in a temporary directory.
# This code copied and modified from compiler-explorer/cobol-builder/build/build.sh
mkdir -p .build/release/ce_temp_dir
# Note: Use grep to omit virtual shared dynamic objects.
cp $(ldd ".build/release/hc" | grep -E  '=> /' | grep -Ev 'lib(pthread|c|dl|rt).so' | awk '{print $3}') .build/release/ce_temp_dir/
patchelf --set-rpath '$ORIGIN' $(find .build/release/ce_temp_dir/ -name \*.so\*)
mv .build/release/ce_temp_dir/* .build/release
# Note: No need to update rpath for `hc` itself, as it is already $ORIGIN by default.
rmdir .build/release/ce_temp_dir/

# Remove Swifty build artifacts not required to run
rm -rf .build/release/*.build
rm -rf .build/release/*.product
rm -rf .build/release/*.swiftdoc
rm -rf .build/release/*.swiftmodule
rm -rf .build/release/*.swiftsourceinfo
rm -rf .build/release/ModuleCache
rm .build/release/description.json

complete .build/release/ "hylo-${VERSION}" "${OUTPUT}"
