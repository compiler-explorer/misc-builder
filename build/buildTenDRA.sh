#!/bin/bash

set -ex

VERSION=$1
if echo ${VERSION} | grep 'trunk'; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=main
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

PREFIX=$(pwd)/prefix
DIR=$(pwd)/tendra
git clone --depth 1 -b ${BRANCH} https://github.com/tendra/tendra.git ${DIR}

# no -j (currently breaks)
pmake -C ${DIR} TARGETARCH=x32_64 LIBCVER=GLIBC2_31
pmake -C ${DIR} TARGETARCH=x32_64 bootstrap-rebuild
# todo after this point...
pmake -C ${DIR} PREFIX=${PREFIX} install

export XZ_DEFAULTS="-T 0"
tar Jcf ${OUTPUT} --transform "s,^./,./tendra-${VERSION}/," -C ${PREFIX} .

if [[ ! -z "${S3OUTPUT}" ]]; then
    s3cmd put --rr ${OUTPUT} ${S3OUTPUT}
fi
