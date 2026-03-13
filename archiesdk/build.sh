#!/bin/bash

set -ex
source common.sh

VERSION=$1
LAST_REVISION="${3:-}"

REVISION="archiesdk-gcc-${VERSION}"
FULLNAME="${REVISION}.tar.xz"
OUTPUT="$2/${FULLNAME}"

REPO=/tmp/archiesdk
DEST="/opt/compiler-explorer/${REVISION}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

git clone --depth 1 https://gitlab.com/_targz/archiesdk.git "${REPO}"

cd "${REPO}"

# Build just the GCC cross-compiler (not the full SDK libraries)
./build.sh gcc

# The built compiler ends up in tools/bin/ within the SDK
mkdir -p "${DEST}/bin"

# Copy the cross-compiler toolchain binaries
cp tools/bin/arm-archie-* "${DEST}/bin/"

# Copy any support libraries the compiler needs (libgcc etc.)
if [ -d tools/lib ]; then
    cp -r tools/lib "${DEST}/"
fi
if [ -d tools/libexec ]; then
    cp -r tools/libexec "${DEST}/"
fi

# Copy the target-specific headers and libraries needed for compilation
if [ -d tools/arm-archie ]; then
    cp -r tools/arm-archie "${DEST}/"
fi

complete "${DEST}" "${REVISION}" "${OUTPUT}"
