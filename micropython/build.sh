#!/bin/bash

set -ex
source common.sh

VERSION=$1
VARIANT=standard

URL=https://github.com/micropython/micropython.git
REPO=/tmp/micropython

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

make -C "${REPO}/ports/unix" submodules
make -C "${REPO}/ports/unix" deplibs

(
    cd "${REPO}"
    set +u
    source tools/ci.sh

    make ${MAKEOPTS} -C mpy-cross
    make ${MAKEOPTS} -C ports/unix VARIANT=${VARIANT}

    ci_unix_build_ffi_lib_helper gcc
)

(
    cd "${REPO}/lib/micropython-lib/"
    set +u
    source tools/ci.sh

    PACKAGE_INDEX_PATH="${DEST}/mip" ci_build_packages_compile_index
)

mkdir -p "${DEST}" "${DEST}/bin" "${DEST}/tools" "${DEST}/py" "${DEST}/lib"
cp "${REPO}/mpy-cross/build/mpy-cross" "${DEST}/bin/mpy-cross"
cp "${REPO}/ports/unix/build-${VARIANT}/micropython" "${DEST}/bin/micropython"
cp "${REPO}/tools/mpy-tool.py" "${DEST}/tools/mpy-tool.py"
cp "${REPO}/py/makeqstrdata.py" "${DEST}/py/makeqstrdata.py"

cp $(ldd "${DEST}/bin/mpy-cross" "${DEST}/bin/micropython" | grep -E  '=> /' | grep -Ev 'lib(pthread|c|dl|rt|m).so' | awk '{print $3}') "${DEST}/lib"
patchelf --set-rpath '$ORIGIN/../lib' "${DEST}/bin/mpy-cross" "${DEST}/bin/micropython"

complete "${DEST}" "${REVISION}" "${OUTPUT}"
