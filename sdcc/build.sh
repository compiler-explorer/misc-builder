#!/usr/bin/env bash

## $1 : version (only "trunk" supported)
## $2 : destination directory
## $3 : last revision successfully built

set -ex
source common.sh

VERSION="${1}"
LAST_REVISION="${3:-}"

if [[ "${VERSION}" != "trunk" ]]; then
    echo "Only support building trunk"
    exit 1
fi

URL="https://git.code.sf.net/p/sdcc/git-mirror"
BRANCH="trunk"
REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")

FULLNAME=sdcc-${VERSION}-$(date +%Y%m%d)
OUTPUT=$(realpath "$2/${FULLNAME}.tar.xz")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

# The git-svn-id in the commit message gives the version string its svn revision
git clone --depth 1 "${URL}" --branch "${BRANCH}" sdcc
cd sdcc

./configure --prefix=/usr/local --disable-ucsim --disable-sdcdb
make -j"$(nproc)"
make install DESTDIR=/tmp/sdcc-install

complete /tmp/sdcc-install/usr/local "${FULLNAME}" "${OUTPUT}"
