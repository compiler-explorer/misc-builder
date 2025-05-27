#!/bin/bash

set -euxo pipefail
source common.sh

VERSION="${1}"
LAST_REVISION="${3-}"

if [[ "${VERSION}" != "nightly" ]]; then
    echo "Only support building nightly"
    exit 1
fi

BASENAME=miri-${VERSION}-$(date +%Y%m%d)
FULLNAME="${BASENAME}.tar.xz"
OUTPUT=$2/${FULLNAME}

REVISION=${BASENAME}
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

# update infra
pushd /opt/compiler-explorer/infra
git pull
make ce
popd

/opt/compiler-explorer/infra/bin/ce_install --enable nightly install compilers/rust/newer/nightly nightly

RUST=/opt/compiler-explorer/rust-miri-${VERSION}

mv /opt/compiler-explorer/rust-nightly ${RUST}

# put `rustup` on `$PATH`
source .cargo/env

rustup toolchain link miri ${RUST}
rustup default miri

export MIRI_SYSROOT=${RUST}/miri-sysroot

for manifest_path in ${RUST}/lib/rustlib/manifest-rust-std-*; do
    cargo miri setup --target=${manifest_path#*/manifest-rust-std-} --verbose
done

complete "${RUST}" "rust-miri-${VERSION}" "${OUTPUT}"
