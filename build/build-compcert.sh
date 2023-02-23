#!/bin/bash 

set -e

opam init --disasable-sandboxing -n
opam install coq=8.15.2 --yes
opam install menhir --yes
eval `opam env`


VERSION=$(curl -Ss  "https://api.github.com/repos/AbsInt/CompCert/tags" | sed -ne 's/^[ \t]*"name": "//; s/",//p' | head -n 1)
URL="https://github.com/AbsInt/CompCert/archive/${VERSION}.tar.gz"

wget ${URL} 

tar zxf ${VERSION}.tar.gz

cd CompCert-*

./configure x86_64-linux
make 
make install

echo "ce-build-status:OK"
