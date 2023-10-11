#!/bin/bash

## $1 : version
## $2 : destination: a directory
## $3 : last revision: a revision descriptor which may be fetched from the cache.

set -exu
source common.sh

ROOT=$(pwd)
VERSION=$1
URL="https://github.com/hylo-lang/hyloc"

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
git clone -q --depth 1 --single-branch -b "${BRANCH}" "${URL}" "hylo-${VERSION}"

cd "hylo-${VERSION}"
swift package resolve
.build/checkouts/Swifty-LLVM/Tools/make-pkgconfig.sh /usr/local/lib/pkgconfig/llvm.pc
swift build --static-swift-stdlib -c release --product hc

mkdir -p .build/release/lib
# Copy dependent libraries into sibling `lib` directory. Update rpath to point to `lib`.
# This code copied and modified from compiler-explorer/cobol-builder/build/build.sh
# REVIEW: Why did the cobol version remove pthread and libc?
cp $(ldd ".build/release/hc" | grep -E  '=> /' | awk '{print $3}') .build/release/lib/
patchelf --set-rpath '$ORIGIN/lib' $(find .build/release/lib/ -name \*.so\*)
# REVIEW: Why _doesn't_ cobol change rpath for the binary itself? Should we?
patchelf --set-rpath '$ORIGIN/lib' .build/release/hc

complete .build/release/ "${FULLNAME}" "${OUTPUT}"
