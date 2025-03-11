#!/bin/bash

set -exu
source common.sh
source $HOME/.cargo/env

## $1 : version, like v0.9 (tag) or master (branch)
## $2 : destination: a directory or S3 path (eg. s3://...)
## $3 : last revision successfully built (optional)

VERSION=$1

# TODO: Add support for building tagged releases.
if [[ "${VERSION}" != "master" ]]; then
    echo "Only support building master"
    exit 1
fi

VERSION=master-$(date +%Y%m%d)
BRANCH=master

URL=https://github.com/immunant/c2rust

FULLNAME=c2rust-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="c2rust-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

OUT=$(pwd)/out
DIR=$(pwd)/c2rust
BUILD=${DIR}/target/release

git clone --depth 1 -b "${BRANCH}" "${URL}" "${DIR}"

cd $DIR
rustup toolchain install
cargo build --release
mkdir -p "${OUT}"

cp "${BUILD}/c2rust" "${BUILD}/c2rust-transpile" "${OUT}"

# Copy all dependency .so files into the output dir and then set the RPATH to
# $ORIGIN so that the local version gets used instead of whatever is insalled
# globally.
cp $(ldd "${OUT}"/* | grep -E  '=> /' | grep -Ev 'lib(pthread|c|dl|rt)\.so' | awk '{print $3}' | uniq) "${OUT}"
patchelf --set-rpath '$ORIGIN' $"$OUT"/*

complete "${OUT}" "c2rust-${VERSION}" "${OUTPUT}"
