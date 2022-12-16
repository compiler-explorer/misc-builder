#!/bin/bash

## $1 : version
## $2 : destination: a directory or S3 path (eg. s3://...)
## $3 : last revision successfully build

set -ex
ROOT=$(pwd)
VERSION="$1"
LAST_REVISION="$3"

if [[ -z "${VERSION}" ]]; then
    echo Please pass a version to this script
    exit
fi

if echo "${VERSION}" | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    URL=https://git.kernel.org/pub/scm/devel/pahole/pahole.git
    BRANCH=master
else
	echo "Versions other than trunk are not currently supported"
	exit 1
fi

ELFUTILS_VERSION=0.188

FULLNAME=pahole-${VERSION}.tar.xz
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

PAHOLE_REVISION=$(git ls-remote --heads ${URL} refs/heads/${BRANCH} | cut -f 1)
REVISION="pahole-${JAKT_REVISION}-elfutils-${ELFUTILS_VERSION}"

echo "ce-build-revision:${REVISION}"
echo "ce-build-output:${OUTPUT}"

if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
    echo "ce-build-status:SKIPPED"
    exit
fi

STAGING_DIR=${ROOT}/staging
export PATH=${PATH}:/cmake/bin

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

ELFUTILS_BUILD=${ROOT}/elfutils
rm -rf "${ELFUTILS_BUILD}"
mkdir -p "${ELFUTILS_BUILD}"
curl -sL "https://sourceware.org/elfutils/ftp/$ELFUTILS_VERSION/elfutils-$ELFUTILS_VERSION.tar.bz2" | tar jxf - --strip-components 1 -C "${ELFUTILS_BUILD}"
pushd "${ELFUTILS_BUILD}"
./configure "--prefix=${STAGING_DIR}" --program-prefix="eu-" --enable-deterministic-archives --disable-debuginfod --disable-libdebuginfod
make "-j$(nproc)"
make install
popd

SUBDIR=build
rm -rf "${SUBDIR}"
git clone -q --depth 1 --recursive --single-branch -b "${BRANCH}" "${URL}" "${SUBDIR}"

cd "${SUBDIR}"

cmake -B build -GNinja -DCMAKE_INSTALL_PREFIX:PATH="${STAGING_DIR}" \
    -D__LIB=lib \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=TRUE \
    .
cmake --build build --target install

export XZ_DEFAULTS="-T 0"
tar Jcf "${OUTPUT}" --transform "s,^./,./pahole-${VERSION}/," -C "${STAGING_DIR}" .

if [[ -n "${S3OUTPUT}" ]]; then
    aws s3 cp --storage-class REDUCED_REDUNDANCY "${OUTPUT}" "${S3OUTPUT}"
fi

echo "ce-build-status:OK"
