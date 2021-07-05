#!/bin/bash

set -exu

RUNTIME_VERSION="6.0.0-preview.5.21301.5"


git clone --single-branch --depth 1 -b v$RUNTIME_VERSION "https://github.com/dotnet/runtime.git"
cd runtime

./build.sh clr --clang12 --checked
