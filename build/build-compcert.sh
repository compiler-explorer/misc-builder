
#!/bin/bash

set -ex

ROOT=$(pwd)
VERSION=$(curl -Ss  "https://api.github.com/repos/AbsInt/CompCert/tags" | sed -ne 's/^[ \t]*"name": "//; s/",//p' | head -n 1)

opam init --disable-sandboxing -n
opam install coq=8.15.2 --yes
opam install menhir --yes
eval `opam env`

URL="https://github.com/AbsInt/CompCert.git"
DIR=${ROOT}/CompCert

OPT=/opt/compiler-explorer

rm -rf ${DIR}
git clone -b ${VERSION} ${URL} ${DIR}

cd ${DIR}

ARCHS=("ppc" "arm" "rv32" "rv64" "aarch64" "x86_64" "x86_32")
for ARCH in "${ARCHS[@]}"; do
    BIN_PREFIX=${OPT}/compcert-${VERSION}/${ARCH}/
    mkdir -p ${BIN_PREFIX}
    ./configure ${ARCH}-linux -prefix ${BIN_PREFIX}
    make
    make install
done

echo "ce-build-status:OK"


