#!/bin/bash

set -euxo pipefail
source common.sh

VERSION="${1}"
OUTPUT_DIR="${2}"
LAST_REVISION="${3:-}"

REPOSITORY_URL="https://github.com/tenstorrent/sfpi"
RELEASE_URL="${REPOSITORY_URL}/releases/download/${VERSION}/sfpi_${VERSION}_x86_64_debian.txz"
FULLNAME="sfpi-${VERSION}"
OUTPUT="${OUTPUT_DIR}/${FULLNAME}.tar.xz"

TAG_REVISION=$(get_remote_revision "${REPOSITORY_URL}" "tags/${VERSION}")

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

RELEASE_ARCHIVE="${WORK_DIR}/sfpi.txz"
curl --fail --location --silent --show-error \
    --output "${RELEASE_ARCHIVE}" \
    "${RELEASE_URL}"

# Include the release asset digest in the revision. Git tags are expected to be
# immutable, but GitHub release assets can be replaced without moving the tag.
ASSET_REVISION=$(sha256sum "${RELEASE_ARCHIVE}" | cut -d' ' -f1)
REVISION="${TAG_REVISION}-${ASSET_REVISION}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

EXTRACT_DIR="${WORK_DIR}/extract"
mkdir -p "${EXTRACT_DIR}"
tar -xJf "${RELEASE_ARCHIVE}" -C "${EXTRACT_DIR}"

CC1PLUS=$(find "${EXTRACT_DIR}" \( -type f -o -type l \) \
    -path '*/compiler/libexec/gcc/riscv-tt-elf/*/cc1plus' \
    -print -quit)
if [[ -z "${CC1PLUS}" ]]; then
    echo "Unable to find the SFPI cc1plus executable in the release archive" >&2
    exit 1
fi

# Use the directory containing compiler/ as the root of the CE package,
# regardless of whether the upstream archive has a top-level directory.
STAGING_DIR="${CC1PLUS%%/compiler/*}"
RUNTIME_DIR="$(dirname "${CC1PLUS}")/ce-runtime"
mkdir -p "${RUNTIME_DIR}"

# Bundle non-glibc runtime dependencies from the controlled builder image.
# These are copied by value rather than as absolute symlinks.
while read -r dependency; do
    case "$(basename "${dependency}")" in
        libc.so.*|libdl.so.*|libm.so.*|libpthread.so.*|librt.so.*|ld-linux-*.so.*)
            continue
            ;;
    esac
    cp -L "${dependency}" "${RUNTIME_DIR}/$(basename "${dependency}")"
done < <(ldd "${CC1PLUS}" | awk '/=> \// {print $3}' | sort -u)

# Let bundled libraries resolve any bundled transitive dependencies beside
# themselves instead of falling back to the CE host.
for library in "${RUNTIME_DIR}"/*.so.*; do
    patchelf --set-rpath '$ORIGIN' "${library}"
done

patchelf --set-rpath '$ORIGIN/ce-runtime' "${CC1PLUS}"

LDD_OUTPUT=$(ldd "${CC1PLUS}")
if grep -q 'not found' <<<"${LDD_OUTPUT}"; then
    echo "${LDD_OUTPUT}" >&2
    exit 1
fi

for library in "${RUNTIME_DIR}"/*.so.*; do
    if ! grep -Fq "${RUNTIME_DIR}/$(basename "${library}")" <<<"${LDD_OUTPUT}"; then
        echo "Bundled library is not selected by cc1plus: ${library}" >&2
        exit 1
    fi
done

"${CC1PLUS}" --version

DRIVER="${STAGING_DIR}/compiler/bin/riscv-tt-elf-g++"
if [[ -x "${DRIVER}" ]]; then
    "${DRIVER}" --version
fi

complete "${STAGING_DIR}" "${FULLNAME}" "${OUTPUT}"
