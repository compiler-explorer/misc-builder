#!/bin/bash 


opam switch create 4.14.1
eval `opam env`
opam install coq=8.15.2
opam install menhir


VERSION=$(curl -Ss  "https://api.github.com/repos/AbsInt/CompCert/tags" | sed -ne 's/^[ \t]*"name": "//; s/",//p' | head -n 1)
URL="https://github.com/AbsInt/CompCert/archive/${VERSION}.tar.gz"


wget ${URL} 

tar zxf ${VERSION}.tar.gz

cd CompCert-*
./configure x86_64-linux
make

opam 

echo "ce-build-status:OK"
