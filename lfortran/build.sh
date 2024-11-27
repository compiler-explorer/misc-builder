#!/bin/bash

set -euo pipefail
source common.sh

VERSION="${1}"
LAST_REVISION="${3-}"

URL="https://github.com/lfortran/lfortran.git"
if [[ "${VERSION}" == trunk ]]; then
  VERSION=trunk-$(date +%Y%m%d)
  BRANCH=main
  REMOTE=heads/main
else
  BRANCH=v"${VERSION}"
  REMOTE=tags/${BRANCH}
fi

FULLNAME=lfortran-${VERSION}
OUTPUT=$2/${FULLNAME}.tar.xz
REVISION=$(get_remote_revision "${URL}" "${REMOTE}")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

OUTPUT=$(realpath "${OUTPUT}")

git clone "${URL}" --depth=1 "--branch=${BRANCH}"
cd lfortran
./build_release.sh
DEST=$(realpath inst)

complete "${DEST}" "${FULLNAME}" "${OUTPUT}"
