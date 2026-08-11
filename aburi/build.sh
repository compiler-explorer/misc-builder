#!/bin/bash

## $1 : version: the upstream branch to build (defaults to "godbolt")
## $2 : destination: a directory
## $3 : last revision successfully built

set -ex
source common.sh

VERSION="${1:-godbolt}"
LAST_REVISION="${3-}"

URL="https://github.com/serjective/aburi.git"
BRANCH="${VERSION}"

REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")

FULLNAME=aburi-${VERSION}-$(date +%Y%m%d)
OUTPUT=$(realpath "$2/${FULLNAME}.tar.xz")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

STAGING_DIR="${PWD}/stage"

git clone --depth 1 "${URL}" --branch "${BRANCH}" aburi-source

# Three things this configure line has to get right:
#
# * Clang, not gcc. Adinkra is aburi's own C++ standard library and needs a Clang
#   host compiler; CMakeLists.txt only *warns* and silently turns Adinkra off for
#   anything else, so a gcc build succeeds and ships a compiler with no working
#   hosted C++. Checked for real after the install below.
# * libdir "lib". The driver looks for its builtin headers at a hardcoded
#   <prefix>/lib/aburi/builtin_headers, which GNUInstallDirs' Debian multiarch
#   default would miss.
# * --as-needed. Debian's LLVMSupport target names /usr/lib/.../libz3.so in its
#   interface link libraries, so without this aburi gets a DT_NEEDED on
#   libz3.so.4 despite referencing no Z3 symbol, and won't start on a host that
#   hasn't got it.
cmake -S aburi-source -B aburi-source/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang-22 \
    -DCMAKE_CXX_COMPILER=clang++-22 \
    -DLLVM_DIR=/usr/lib/llvm-22/lib/cmake/llvm \
    -DCMAKE_INSTALL_PREFIX="${STAGING_DIR}" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,--as-needed
cmake --build aburi-source/build -j"$(nproc)"

# Install rather than copying the binary out of the build tree: the driver
# resolves its builtin headers and Adinkra relative to its own location, so it
# only works from a proper <prefix>/bin + <prefix>/lib + <prefix>/include layout.
cmake --install aburi-source/build

# Aburi's Adinkra links end with an unconditional "-lc++abi", so libc++abi is a
# runtime dependency of every hosted C++ program it builds and CE's hosts have
# not got one. Ship the shared build beside Adinkra: the static libc++abi.a
# collides with Adinkra's own operator-new handlers, so it has to be the .so.
cp -a /usr/lib/x86_64-linux-gnu/libc++abi.so* "${STAGING_DIR}/lib/"

# Prove Adinkra really made it in, rather than trusting a configure step whose
# opt-out is only a warning. No macOS SDK is staged: for a Linux target aburi
# takes its C headers from the host root and its C++ headers from Adinkra, and
# an explicit --sysroot would in fact switch Adinkra back off.
test -d "${STAGING_DIR}/lib/aburi/builtin_headers"
test -f "${STAGING_DIR}/include/adinkra/c++/v1/vector"
test -f "${STAGING_DIR}/lib/libadinkra.a"
"${STAGING_DIR}/bin/aburi" --version

# Everything listed here has to exist on CE's hosts.
objdump -p "${STAGING_DIR}/bin/aburi" | grep NEEDED

complete "${STAGING_DIR}" "${FULLNAME}" "${OUTPUT}"
