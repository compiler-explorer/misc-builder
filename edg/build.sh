#!/bin/bash

## $1 : version: a release tag (e.g. 7.0), "trunk" for the main branch, or a
##      fork identifier for a different fork
## $2 : destination: a directory
## $3 : last revision successfully built

set -ex
source common.sh

VERSION="${1}"
LAST_REVISION="${3-}"

URL="https://github.com/edgcpp/compiler.git"

case $VERSION in
trunk)
    BRANCH=main
    REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
    FULLNAME=edg-${VERSION}-$(date +%Y%m%d)
    ;;
notadragon-contracts-p3850)
    URL="https://github.com/notadragon/edgcpp_compiler.git"
    BRANCH=contracts-p3850
    REVISION=$(get_remote_revision "${URL}" "heads/${BRANCH}")
    FULLNAME=edg-${VERSION}-$(date +%Y%m%d)
    ;;
*)
    BRANCH="${VERSION}"
    REVISION=$(get_remote_revision "${URL}" "tags/${BRANCH}")
    FULLNAME=edg-${VERSION}
    ;;
esac

OUTPUT=$(realpath "$2/${FULLNAME}.tar.xz")

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

STAGING_DIR="${PWD}/stage"
SOURCE_DIR="${PWD}/edg-source"
BUILD_DIR="${SOURCE_DIR}/build/gcc-release"

git clone --depth 1 "${URL}" --branch "${BRANCH}" "${SOURCE_DIR}"

# EDG_BASE only needs to hold an edg_eccp_config at configure time; the packages
# get their own base from edg-pack-cpfe-ce below. Only the x86-64 runtime library
# is built: the other targets need 32-bit and cross headers we don't use.
# EDG_GCC_VER_SCRAPE tells that config which gcc it is driving (as HACKING.md
# does); left unset it assumes gcc 14 and passes flags our gcc lacks.
export EDG_BASE="${SOURCE_DIR}/bases/docker/dev-env/gcc"
EDG_GCC_VER_SCRAPE=$("${SOURCE_DIR}/dev_tools/bin/edg-scrape-compiler" gcc version)
export EDG_GCC_VER_SCRAPE
# edg-pack-cpfe-ce and the installer's shim both expect the runtime library as
# libedgrt.a; left unset, the build names it libC.a (edgcpp/compiler discussion #16).
export EDG_RUNTIME_LIB=edgrt
(cd "${SOURCE_DIR}" && cmake --preset linux-gcc-release -DEDG_CPP_RT_LIBS=linux_x86_64)
cmake --build "${BUILD_DIR}" -j"$(nproc)"
cmake --build "${BUILD_DIR}" --target edg-cpp-rt -j"$(nproc)"

# One package per mode, as EDG used to send us. The experimental headers go in
# the gcc package so <experimental/meta> works with --set_flag reflection.
pack() {
    local MODE="$1"
    local TAG="$2"
    shift 2
    mkdir -p "${STAGING_DIR}/${MODE}"
    (cd "${STAGING_DIR}" && PYTHONPATH="${SOURCE_DIR}/dev_tools/pylibs" python3 \
        "${SOURCE_DIR}/dev_tools/bin/edg-pack-cpfe-ce" "$@" "${MODE}" "${VERSION}" "${TAG}" \
        "${SOURCE_DIR}" "${BUILD_DIR}")
    tar xzf "${STAGING_DIR}/edg-${MODE}-${VERSION}.tar.gz" -C "${STAGING_DIR}/${MODE}"
    rm "${STAGING_DIR}/edg-${MODE}-${VERSION}.tar.gz"
}
pack gcc "EDG ${VERSION} (GNU mode)" --add-experimental-headers
pack default "EDG ${VERSION}"

# The installer runs these at install time against the backend gcc.
mkdir -p "${STAGING_DIR}/tools"
cp "${SOURCE_DIR}/dev_tools/bin/edg-scrape-compiler" "${SOURCE_DIR}/util/make_predef_macro_table" "${STAGING_DIR}/tools/"
echo "${REVISION}" > "${STAGING_DIR}/REVISION"

complete "${STAGING_DIR}" "${FULLNAME}" "${OUTPUT}"
