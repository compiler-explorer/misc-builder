#!/bin/bash

set -ex
source common.sh

VERSION=$1

URL=https://github.com/micropython/micropython.git
REPO=micropython

LAST_REVISION="${3:-}"

if [[ $VERSION == 'preview' ]]; then
    REVISION="micropython-preview-$(date +%Y%m%d)"
else
    REVISION="micropython-${VERSION}"
fi;

FULLNAME="${REVISION}.tar.xz"
OUTPUT="$2/${FULLNAME}"

DEST="/opt/compiler-explorer/${REVISION}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

if [[ $VERSION == 'preview' ]]; then
    git clone --depth 1 "${URL}" "${REPO}"
else
    git clone --depth 1 "${URL}" -b "v${VERSION}" "${REPO}"
fi;

(
    cd "${REPO}"
    set +u
    source tools/ci.sh
    ci_unix_standard_build
)

mkdir -p "${DEST}" "${DEST}/bin" "${DEST}/tools" "${DEST}/py" "${DEST}/lib"
cp "${REPO}/mpy-cross/build/mpy-cross" "${DEST}/bin/mpy-cross"
cp "${REPO}/ports/unix/build-standard/micropython" "${DEST}/bin/micropython"
cp "${REPO}/tools/mpy-tool.py" "${DEST}/tools/mpy-tool.py"
cp "${REPO}/py/makeqstrdata.py" "${DEST}/py/makeqstrdata.py"

cp $(ldd "${DEST}/bin/mpy-cross" "${DEST}/bin/micropython" | grep -E  '=> /' | grep -Ev 'lib(pthread|c|dl|rt|m).so' | awk '{print $3}') "${DEST}/lib"
patchelf --set-rpath '$ORIGIN/../lib' "${DEST}/bin/mpy-cross" "${DEST}/bin/micropython"

complete "${DEST}" "${FULLNAME}" "${OUTPUT}"
