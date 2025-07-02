#!/bin/bash

## $1 : version
## $2 : destination: a directory
## $3 : last revision: a revision descriptor which may be fetched from the cache.

set -exu
source common.sh

ROOT=$(pwd)
VERSION=$1

BRANCH=${VERSION}
REVISION=${VERSION}

FULLNAME=nix-${VERSION}.tar.xz
OUTPUT=${ROOT}/${FULLNAME}
LAST_REVISION="${3:-}"

if [[ -d "${2}" ]]; then
   OUTPUT=$2/${FULLNAME}
else
   OUTPUT=${2-$OUTPUT}
fi

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

nix \
    --experimental-features 'nix-command flakes' \
    build --impure \
    github:nixos/nix/${VERSION}#hydraJobs.buildStatic.nix-everything.x86_64-linux

# the nix executable is a symlink so we copy it to get the actual binary bits
mkdir output
cp result/bin/nix output/

complete output "nix-${VERSION}" "${OUTPUT}"
