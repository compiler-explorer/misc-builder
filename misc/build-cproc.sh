#!/usr/bin/env bash

## $1 : version, currently cproc does not have any and only uses master branch.
## $2 : destination: a directory
## $3 : last revision successfully build (optional)

set -ex
source common.sh

VERSION="${1}"
LAST_REVISION="${3-}"

if [[ "${VERSION}" != "master" ]]; then
    echo "Only support building master"
    exit 1
fi

URL="https://git.sr.ht/~mcf/cproc"
BRANCH="master"
QBE_URL="git://c9x.me/qbe.git"
QBE_BRANCH="master"

CPROC_REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
QBE_REVISION=$(get_remote_revision "${QBE_URL}" "heads/${QBE_BRANCH}")
REVISION="${CPROC_REVISION}_qbe-${QBE_REVISION}"

FULLNAME=cproc-${VERSION}-$(date +%Y%m%d)
OUTPUT=$(realpath "$2/${FULLNAME}.tar.xz")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

DESTDIR="${PWD}/stage"

git clone --depth 1 "${URL}" --branch "${BRANCH}"
pushd cproc
./configure
make -j"$(nproc)" install DESTDIR="${DESTDIR}" BINDIR=/bin
popd

git clone --depth 1 "${QBE_URL}" --branch "${QBE_BRANCH}"
make -C qbe -j"$(nproc)" install DESTDIR="${DESTDIR}" BINDIR=/bin

complete "${DESTDIR}" "${FULLNAME}" "${OUTPUT}"
