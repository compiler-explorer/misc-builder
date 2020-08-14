#!/bin/bash

set -ex

VERSION=$1
if echo ${VERSION} | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=envfixes
else
    BRANCH=V${VERSION}
fi

OUTPUT=/root/tendra-${VERSION}.tar.xz
S3OUTPUT=""
if echo $2 | grep s3://; then
    S3OUTPUT=$2
else
    OUTPUT=${2-/root/tendra-${VERSION}.tar.xz}
fi

PREFIX_BOOTSTRAP=$(pwd)/prefix/bootstrap
PREFIX_REBUILD=$(pwd)/prefix/rebuild

DIR=$(pwd)/tendra
git clone --depth 1 -b ${BRANCH} https://github.com/partouf/tendra.git ${DIR}

# no -j (currently breaks)
pmake -C ${DIR} TARGETARCH=x32_64 OBJ_BPREFIX=${PREFIX_BOOTSTRAP}

# this seems to ignore libcver somewhere?
#pmake -C ${DIR} TARGETARCH=x32_64 OBJ_REBUILD=${PREFIX_REBUILD} bootstrap-rebuild

export XZ_DEFAULTS="-T 0"
tar Jcf ${OUTPUT} --transform "s,^./,./tendra-${VERSION}/," -C ${PREFIX_BOOTSTRAP} .

if [[ ! -z "${S3OUTPUT}" ]]; then
    s3cmd put --rr ${OUTPUT} ${S3OUTPUT}
fi
