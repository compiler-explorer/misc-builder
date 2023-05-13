#!/bin/bash

## $1 : version
## $2 : destination: a directory

set -eu
source common.sh
source $HOME/.cargo/env

VERSION="${1}"
LAST_REVISION="${3-}"

URL="https://github.com/torvalds/linux.git"
if [ "${VERSION}" -eq "trunk" ]; then
  VERSION=trunk-$(date +%Y%m%d)
  BRANCH=master
  REMOTE=heads/master
else
  BRANCH=v"${VERSION}"
  REMOTE=tags/${BRANCH}
fi

FULLNAME=rust-linux-${VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz
REVISION=$(get_remote_revision "${URL}" "${REMOTE}")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

OUTPUT=$(realpath "${OUTPUT}")

# we assume we don't need to patch the kernel (ie we fix the RUSTC_BOOTSTRAP=1 issue)
BUILD_DEST=/opt/compiler-explorer/linux-rust/${VERSION}  # Currently needs to be same as the ultimate destination
mkdir -p "$(dirname "${BUILD_DEST}")"
git clone "${URL}" --depth=1 "--branch=${BRANCH}" "${BUILD_DEST}"

pushd "${BUILD_DEST}"

rustup default "$(scripts/min-tool-version.sh rustc)"
rustup component add rust-src
$HOME/.cargo/bin/cargo install --locked --version "$(scripts/min-tool-version.sh bindgen)" bindgen

make --jobs="$(nproc)" ARCH-x86_64 LLVM=1 defconfig rust.config prepare

DEST=/root/linux-out
mkdir "${DEST}"
cp --parents \
      ./rust/*.rmeta \
      ./rust/*.so \
      ./include/generated/rustc_cfg \
      ./scripts/target.json \
      "${DEST}"
popd

complete "${DEST}" "${FULLNAME}" "${OUTPUT}"
