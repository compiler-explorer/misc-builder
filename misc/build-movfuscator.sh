#!/bin/bash

set -ex
source common.sh

VERSION=$1
if [[ "${VERSION}" = "trunk" ]]; then
    VERSION=trunk-$(date +%Y%m%d)
    BRANCH=master
else
    BRANCH=V${VERSION}
fi

URL=https://github.com/xoreaxeaxeax/movfuscator.git

FULLNAME=movfuscator-${VERSION}.tar.xz
OUTPUT=$2/${FULLNAME}

REVISION="movfuscator-$(get_remote_revision "${URL}" "heads/${BRANCH}")"
LAST_REVISION="${3:-}"

initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

PREFIX=$(pwd)/prefix
DIR=$(pwd)/movfuscator

git clone "${URL}" "${DIR}"

cd "${DIR}"

# Fix include paths that are baked into the binary
cat > 1.patch << XXX
diff --git a/movfuscator/host.c b/movfuscator/host.c
index 36f9b26..b837acc 100644
--- a/movfuscator/host.c
+++ b/movfuscator/host.c
@@ -1,4 +1,5 @@
 #include <string.h>
+#include <stdlib.h>

 #ifndef LCCDIR
 #define LCCDIR "/usr/local/lib/lcc/"
@@ -50,6 +51,17 @@ char *include[]={
        0
 };

+__attribute__((constructor))
+static void init_include_dirs() {
+       char buf[256];
+       strcpy(buf, "-I");
+       strncat(buf, getenv("MOVINCLUDE"), 255);
+       include[0] = strdup(buf);
+       strcpy(buf, "-I");
+        strncat(buf, getenv("MOVGCCINCLUDE"), 255);
+       include[1] = strdup(buf);
+}
+
 char *com[]={
        LCCDIR "rcc",
        "-target=x86/mov",
XXX

git apply 1.patch

./build.sh

mkdir -p "${PREFIX}"
mv build "${PREFIX}/build"

complete "${PREFIX}" "movfuscator-${VERSION}" "${OUTPUT}"
