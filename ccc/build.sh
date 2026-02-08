#!/bin/bash

## $1 : version (only "main" supported)
## $2 : destination directory
## $3 : last revision successfully built

set -ex
source common.sh
source "$HOME/.cargo/env"

VERSION="${1}"
LAST_REVISION="${3:-}"

if [[ "${VERSION}" != "main" ]]; then
    echo "Only support building main"
    exit 1
fi

URL="https://github.com/anthropics/claudes-c-compiler.git"
BRANCH="main"
REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")

FULLNAME=ccc-${VERSION}-$(date +%Y%m%d)
OUTPUT=$(realpath "$2/${FULLNAME}.tar.xz")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

git clone --depth 1 "${URL}" --branch "${BRANCH}"
cd claudes-c-compiler

cargo build --release

# Install binaries into a clean directory
mkdir -p /tmp/ccc-install
cp target/release/ccc target/release/ccc-x86 target/release/ccc-arm \
   target/release/ccc-riscv target/release/ccc-i686 /tmp/ccc-install/
# Include the standard headers shipped with ccc
if [[ -d include ]]; then
    cp -r include /tmp/ccc-install/
fi

complete /tmp/ccc-install "${FULLNAME}" "${OUTPUT}"
