#!/bin/bash

## $1 : version, currently rustc_cg_gcc does not have any and only uses master branch.
## $2 : destination: a directory
## $3 : last revision (as mangled below) successfully build (optional)

set -eu
source common.sh

VERSION="${1}"
LAST_REVISION="${3-}"

if [[ "${VERSION}" != "master" ]]; then
    echo "Only support building master"
    exit 1
fi

GCC_URL="https://github.com/antoyo/gcc.git"
GCC_BRANCH="master"

CG_GCC_BRANCH="master"
CG_GCC_URL="https://github.com/rust-lang/rustc_codegen_gcc.git"

GCC_REVISION=$(get_remote_revision "${GCC_URL}" "heads/${GCC_BRANCH}")
CG_GCC_REVISION=$(get_remote_revision "${CG_GCC_URL}" "heads/${CG_GCC_BRANCH}")

BASENAME=rustc-cg-gcc-${VERSION}-$(date +%Y%m%d)
FULLNAME=${BASENAME}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="cggcc-${CG_GCC_REVISION}-gcc-${GCC_REVISION}"
initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

OUTPUT=$(realpath "${OUTPUT}")

# Needed because the later y.sh will call "git am" and this needs user info.
git config --global user.email "nope@nope.com"
git config --global user.name "John Nope"

rm -rf  build-rustc-cg-gcc
mkdir -p build-rustc-cg-gcc

pushd build-rustc-cg-gcc
PREFIX=$(pwd)/gcc-install

export CARGO_HOME=$PWD/rustup
export RUSTUP_HOME=$PWD/rustup

export PATH=$RUSTUP_HOME/bin:$PATH

## Download rustc_cg_gcc
git clone --depth 1 "${CG_GCC_URL}" --branch "${CG_GCC_BRANCH}"

## Download rustup and install it in a local dir
## Installs :
## - minimal profile
## - the required build-deps from RUSTUP_COMP_BUILD_DEPS (-c *)
## - version taken from rust-toolchain file

RUSTUP_COMP_BUILD_DEPS=( $(grep components rustc_codegen_gcc/rust-toolchain | sed 's/components = \[\(.*\)\]/\1/' | tr -d '",' ) )

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- --profile minimal \
         -c "$(printf '%s\n' "$(IFS=,; printf '%s' "${RUSTUP_COMP_BUILD_DEPS[*]}")")" \
         --no-modify-path \
         -y \
         --default-toolchain  "$(grep channel rustc_codegen_gcc/rust-toolchain | sed 's/channel = "\(.*\)"/\1/')"

source  "$PWD/rustup/env"

pushd rustc_codegen_gcc


# Do default config, as described in the "Quick start" guide on the project's
# page.
cp config.example.toml config.toml

./y.sh prepare

# This may fail because it can't find libgccjit that it downloads itself....
./y.sh build --sysroot --release || true

# So restart it after the failed execution.
# Following y.sh needs to find the libgccjit that is getting downloaded
SO_PATH=$(find -name "libgccjit.so")
LIBRARY_PATH=$(dirname "$PWD"/"$SO_PATH")
LD_LIBRARY_PATH=$(dirname "$PWD"/"$SO_PATH")
export LIBRARY_PATH

# ... this one should work.
./y.sh build --sysroot --release

popd

##
## Before packaging, remove build deps
##

for c in "${RUSTUP_COMP_BUILD_DEPS[@]}"
do
    rustup component remove "$c"
done

##
## Package everything together:
## - the rustc toolchain from rustup
## - libgccjit
## - librustc_codegen_gcc
## - sysroot

mkdir -p toolroot

# rustc toolchain
mv rustup/toolchains/*/* toolroot/

# libgccjit
find -name "libgccjit.so" -exec mv {} toolroot/lib ';'

pushd toolroot/lib
ln -s libgccjit.so libgccjit.so.0
popd

# cg_gcc backend
mv ./rustc_codegen_gcc/target/release/librustc_codegen_gcc.so toolroot/lib

# sysroot
mv ./rustc_codegen_gcc/build/build_sysroot/sysroot toolroot/

##
## Fixup RPATH for the librustc_codegen_gcc.so so it can find libgccjit
##
## FIXME: when we bump the ubuntu image, patchelf will accept '--add-rpath'.
## probably better if RPATH is used at some point by upstream.
patchelf --set-rpath '$ORIGIN/' toolroot/lib/librustc_codegen_gcc.so

##
## Simple sanity checks:
## - check for assembly output
## - check for correct exec output

echo "fn main() -> Result<(), &'static str> { Ok(()) }" > /tmp/test.rs

(export LD_LIBRARY_PATH="$PWD/toolroot/lib";
 export LIBRARY_PATH="$PWD/toolroot/lib";
 ./toolroot/bin/rustc -Zcodegen-backend="$PWD/toolroot/lib/librustc_codegen_gcc.so"  --sysroot toolroot/sysroot --emit asm -o test.s  /tmp/test.rs)
test test.s

(export LD_LIBRARY_PATH="$PWD/toolroot/lib";
 export LIBRARY_PATH="$PWD/toolroot/lib";
./toolroot/bin/rustc -Zcodegen-backend="$PWD/toolroot/lib/librustc_codegen_gcc.so" --sysroot toolroot/sysroot /tmp/test.rs)
./test

# Don't try to compress the binaries as they don't like it
complete toolroot "${BASENAME}" "${OUTPUT}"
