#!/bin/bash

## $1 : version, currently cproc does not have any and only uses master branch.
## $2 : destination: a directory or S3 path (eg. s3://...)
## $3 : last revision successfully build (optional)

set -ex

ROOT=$PWD
VERSION="${1}"
LAST_REVISION="${3-}"

if [[ "${VERSION}" != "master" ]]; then
    echo "Only support building master"
    exit 1
fi

URL="https://github.com/michaelforney/cproc.git"
BRANCH="master"

BASENAME=cproc-${VERSION}-$(date +%Y%m%d)
FULLNAME=${BASENAME}.tar.xz
OUTPUT=${ROOT}/${FULLNAME}
S3OUTPUT=
if [[ $2 =~ ^s3:// ]]; then
    S3OUTPUT=$2
else
    if [[ -d "${2}" ]]; then
        OUTPUT=$2/${FULLNAME}
    else
        OUTPUT=${2-$OUTPUT}
    fi
fi

REVISION=$(git ls-remote --heads "${URL}" "refs/heads/${BRANCH}" | cut -f 1)
echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

## From now, no unset variable
set -u

OUTPUT=$(realpath "${OUTPUT}")

rm -rf  build-cproc
mkdir -p build-cproc

pushd build-cproc

git clone --depth 1 "${URL}" --branch "${BRANCH}"
pushd cproc

## Temporary (hopefully) patch to support basic --version
##
## The following 2 lines are needed on virgin system where nothing is
## configured. git really needs something here, or it will fail. Even using
## --author is not enough.
git config user.email || git config user.email "none@example.com"
git config user.name || git config user.name "None"

git am ../../cproc-version.patch

./configure

git submodule update --init --recursive
make -j"$(nproc)" qbe
PATH=$PWD/qbe/obj:$PATH

make -j"$(nproc)"
make install DESTDIR="$PWD/root" BINDIR=/bin

pushd qbe
make install DESTDIR="$PWD/../root" BINDIR=/bin
popd

pushd root

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${BASENAME}/," ./

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

popd
popd
echo "ce-build-status:OK"
