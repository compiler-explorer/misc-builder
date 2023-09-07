#!/bin/bash

## $1 : version
## $2 : destination: a directory

set -eu
source common.sh

VERSION="${1}"
LAST_REVISION="${3-}"

URL="https://github.com/hylo-lang/hyloc"

if echo "${VERSION}" | grep 'trunk'; then
   VERSION=trunk-$(date +%Y%m%d)
   BRANCH=main
   REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
else
   BRANCH=v${VERSION}
   REVISION=$(get_remote_revision "${URL}" "tags/${BRANCH}")
fi

FULLNAME=hylo-${VERSION}
OUTPUT=$2/hylo/${FULLNAME}.tar.xz
mkdir "$(dirname ${OUTPUT})"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

OUTPUT=$(realpath "${OUTPUT}")

BUILD_DEST=/opt/compiler-explorer/hylo/hylo-${VERSION}
mkdir -p "$(dirname "${BUILD_DEST}")"
git clone "${URL}" --depth=1 "--branch=${BRANCH}" "${BUILD_DEST}"

pushd "${BUILD_DEST}"

swift package resolve
.build/checkouts/Swifty-LLVM/Tools/make-pkgconfig.sh /usr/local/lib/pkgconfig/llvm.pc
export PKG_CONFIG_PATH=$PWD:/usr/lib/x86_64-linux-gnu/
swift build -c release

complete .build/release/* "${FULLNAME}" "${OUTPUT}"

popd
