#!/bin/bash

set -ex

VERSION=$1
OS=linux
if echo ${VERSION} | grep -q 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=main
else
    BRANCH="${VERSION}"
    if [[ "${VERSION:1:1}" -lt 8 ]]; then OS=Linux; fi
fi

URL=https://github.com/dotnet/runtime.git

FULLNAME=dotnet-${VERSION}.tar.xz
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

DOTNET_REVISION=$(git ls-remote --heads ${URL} refs/heads/${BRANCH} | cut -f 1)
REVISION="dotnet-${DOTNET_REVISION}"
LAST_REVISION="${3}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

DIR=$(pwd)/dotnet/runtime

git clone --depth 1 -b ${BRANCH} ${URL} ${DIR}
cd ${DIR}

commit="$(git rev-parse HEAD)"
echo "HEAD is at: $commit"

CORE_ROOT=artifacts/tests/coreclr/"${OS}".x64.Release/Tests/Core_Root

# Build everything in Release mode
./build.sh Clr+Libs -c Release --ninja -ci -p:OfficialBuildId=$(date +%Y%m%d)-99

# Build Checked JIT compilers (only Checked JITs are able to print codegen)
./build.sh Clr.AllJits -c Checked --ninja
cd src/tests

# Generate CORE_ROOT for Release
./build.sh Release generatelayoutonly
cd ../..

# Write version info for .NET 6 (it doesn't have crossgen2 --version)
echo "${VERSION:1}+${commit}" > ${CORE_ROOT}/version.txt

# Copy Checked JITs to CORE_ROOT
cp artifacts/bin/coreclr/"${OS}".x64.Checked/libclrjit*.so "${CORE_ROOT}"
cp artifacts/bin/coreclr/"${OS}".x64.Checked/libclrjit*.so "${CORE_ROOT}"/crossgen2

# Copy the bootstrapping .NET SDK, needed for 'dotnet build'
# Exclude the pdbs as when they are present, when running on Linux we get:
# Error: Image is either too small or contains an invalid byte offset or count.
# System.BadImageFormatException: Image is either too small or contains an invalid byte offset or count.

cd ${DIR}
mv .dotnet/ ${CORE_ROOT}/
cd ${CORE_ROOT}/..
XZ_OPT=-2 tar Jcf ${OUTPUT} --exclude \*.pdb --transform "s,^./,./dotnet-${VERSION}/," -C Core_Root .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
