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

rm -rf  build-rustc-cg-gcc
mkdir -p build-rustc-cg-gcc

pushd build-rustc-cg-gcc
PREFIX=$(pwd)/gcc-install

export CARGO_HOME=$PWD/rustup
export RUSTUP_HOME=$PWD/rustup

export PATH=$RUSTUP_HOME/bin:$PATH

## Download rustc_cg_gcc
git clone --depth 1 "${CG_GCC_URL}" --branch "${CG_GCC_BRANCH}"

pushd rustc_codegen_gcc
git clone https://github.com/llvm/llvm-project llvm --depth 1 --single-branch
export RUST_COMPILER_RT_ROOT="$PWD/llvm/compiler-rt"
popd

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

##
## Prepare rustc_cg_gcc
##
pushd rustc_codegen_gcc

# where the libgccjit.so will be installed
echo "$PREFIX/lib"  > gcc_path

popd

##
## Build customized GCC with libgccjit
##

git clone --depth 1 "${GCC_URL}" --branch "${GCC_BRANCH}"

# clean
rm -rf gcc-build  gcc-install
mkdir -p gcc-build gcc-install

echo "Downloading prerequisites"
pushd gcc
./contrib/download_prerequisites
popd

pushd gcc-build
LANGUAGES=jit,c++
PKGVERSION="Compiler-Explorer-Build-${REVISION}"

CONFIG=("--enable-checking=release"
        "--enable-host-shared"
        "--build=x86_64-linux-gnu"
        "--host=x86_64-linux-gnu"
        "--target=x86_64-linux-gnu"
        "--disable-bootstrap"
        "--enable-multiarch"
        "--with-abi=m64"
        "--with-multilib-list=m32,m64,mx32"
        "--enable-multilib"
        "--enable-clocale=gnu"
        "--enable-languages=${LANGUAGES}"
        "--enable-ld=yes"
        "--enable-gold=yes"
        "--enable-libstdcxx-debug"
        "--enable-libstdcxx-time=yes"
        "--enable-linker-build-id"
        "--enable-lto"
        "--enable-plugins"
        "--enable-threads=posix"
        "--with-pkgversion=\"${PKGVERSION}\""
## this is needed for all libs (gmp, mpfr, …) to be PIC so as to not cause issue
## when they are statically linked in the libgccjit.so
        "--with-pic")

../gcc/configure --prefix="${PREFIX}" "${CONFIG[@]}"

make -j"$(nproc)"
make -j"$(nproc)" install-strip
popd

##
## Back to rustc_cg_gcc for building
##
pushd rustc_codegen_gcc
./prepare_build.sh

## Temporary fix, see
## https://github.com/compiler-explorer/compiler-explorer/issues/4715. This
## causes all the crates to be built with panic=abort, so any unwinding will be
## doomed :(
CG_RUSTFLAGS=-Cpanic=abort \
    ./build.sh --release

popd

##
## Everything should be correctly built
##

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
mv ./gcc-install/lib/libgccjit.so* toolroot/lib

# cg_gcc backend
mv ./rustc_codegen_gcc/target/release/librustc_codegen_gcc.so toolroot/lib

# sysroot
mv ./rustc_codegen_gcc/build_sysroot/sysroot toolroot/

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
./toolroot/bin/rustc -Cpanic=abort -Zcodegen-backend=librustc_codegen_gcc.so  --sysroot toolroot/sysroot --emit asm -o test.s  /tmp/test.rs
test test.s

./toolroot/bin/rustc -Cpanic=abort -Zcodegen-backend=librustc_codegen_gcc.so --sysroot toolroot/sysroot /tmp/test.rs
./test

# Don't try to compress the binaries as they don't like it
complete toolroot "${BASENAME}" "${OUTPUT}"
