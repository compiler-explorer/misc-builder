#!/bin/bash

## $1 : version, currently rustc_cg_gcc does not have any and only uses master branch.
## $2 : destination: a directory or S3 path (eg. s3://...)
## $3 : last revision (as mangled below) successfully build (optional)

set -e

ROOT=$PWD
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

GCC_REVISION=$(git ls-remote --heads "${GCC_URL}" "refs/heads/${GCC_BRANCH}" | cut -f 1)
CG_GCC_REVISION=$(git ls-remote --heads "${CG_GCC_URL}" "refs/heads/${CG_GCC_BRANCH}" | cut -f 1)

REVISION="cggcc-${CG_GCC_REVISION}-gcc-${GCC_REVISION}"
echo "ce-build-revision:${REVISION}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

FULLNAME=rustc-cg-gcc-${VERSION}-$(date +%Y%m%d)

OUTPUT=${ROOT}/${FULLNAME}.tar.xz
S3OUTPUT=
if [[ $2 =~ ^s3:// ]]; then
    S3OUTPUT=$2
else
    if [[ -d "${2}" ]]; then
        OUTPUT=$2/${FULLNAME}.tar.xz
    else
        OUTPUT=${2-$OUTPUT}
    fi
fi

## From now, no unset variable
set -u

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

## Download rustup and install it in a local dir
## Installs :
## - minimal profile
## - the required build-deps from RUSTUP_COMP_BUILD_DEPS (-c *)
## - version taken from rust-toolchain file

RUSTUP_COMP_BUILD_DEPS=(rust-src rustc-dev llvm-tools-preview)

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- --profile minimal \
         -c "$(printf '%s\n' "$(IFS=,; printf '%s' "${RUSTUP_COMP_BUILD_DEPS[*]}")")" \
         --no-modify-path \
         -y \
         --default-toolchain  "$(cat rustc_codegen_gcc/rust-toolchain)"

source  "$PWD/rustup/env"

##
## Prepare rustc_cg_gcc
##
pushd rustc_codegen_gcc

# where the libgccjit.so will be installed
echo "$PREFIX/lib"  > gcc_path

./build_sysroot/prepare_sysroot_src.sh
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
./build.sh --release
popd

##
## Everything should be correctly build
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
## Simple sanity checks:
## - check for assembly output
## - check for correct exec output

echo "fn main() -> Result<(), &'static str> { Ok(()) }" > /tmp/test.rs
./toolroot/bin/rustc -Cpanic=abort -Zcodegen-backend=librustc_codegen_gcc.so  --sysroot toolroot/sysroot --emit asm -o test.s  /tmp/test.rs
test test.s

./toolroot/bin/rustc -Cpanic=abort -Zcodegen-backend=librustc_codegen_gcc.so --sysroot toolroot/sysroot /tmp/test.rs
./test

# Don't try to compress the binaries as they don't like it
pushd toolroot

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./${FULLNAME}/," ./

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi
