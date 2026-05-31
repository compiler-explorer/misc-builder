#!/bin/bash

set -ex
source common.sh

VERSION=$1

URL=https://www.lua.org/ftp/lua-${VERSION}.tar.gz

FULLNAME=lua-${VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz

REVISION="lua-${VERSION}"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

STAGING_DIR=/opt/compiler-explorer/${FULLNAME}
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

BUILD_DIR=$(pwd)/build
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"
curl -sL "${URL}" | tar zxf - --strip-components 1

# posix is supported by every released Lua version and avoids the readline
# dependency of the linux target; lua/luac are still fully functional.
make -j"$(nproc)" posix
make INSTALL_TOP="${STAGING_DIR}" install

# Sanity-check the built binaries.
"${STAGING_DIR}/bin/lua" -v
"${STAGING_DIR}/bin/luac" -v

complete "${STAGING_DIR}" "${FULLNAME}" "${OUTPUT}"
