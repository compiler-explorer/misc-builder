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
# Note: Seems to be whitespace-sensitive
cat > 1.patch << XXX
diff --git a/movfuscator/host.c b/movfuscator/host.c
index 36f9b26..82c1528 100644
--- a/movfuscator/host.c
+++ b/movfuscator/host.c
@@ -1,4 +1,5 @@
 #include <string.h>
+#include <stdlib.h>
 
 #ifndef LCCDIR
 #define LCCDIR "/usr/local/lib/lcc/"
@@ -50,6 +51,20 @@ char *include[]={
 	0 
 };
 
+__attribute__((constructor))
+static void init_include_dirs() {
+    char buf[256];
+    strcpy(buf, "-I");
+    strncat(buf, getenv("MOVBUILDDIR"), 255);
+    strncat(buf, "/include", 255);
+    include[0] = strdup(buf);
+    
+    strcpy(buf, "-I");
+    strncat(buf, getenv("MOVBUILDDIR"), 255);
+    strncat(buf, "/gcc/include", 255);
+    include[1] = strdup(buf);
+}
+
 char *com[]={
 	LCCDIR "rcc",
 	"-target=x86/mov",
@@ -59,6 +74,15 @@ char *com[]={
 	0
 };
 
+__attribute__((constructor))
+static void init_com() {
+    char buf[256];
+    strcpy(buf, "-I");
+    strncat(buf, getenv("MOVBUILDDIR"), 255);
+    strncat(buf, "/include", 255);
+    com[0] = strdup(buf);
+}
+
 char *as[]={
 	"/usr/bin/as",
 	"--32",
@@ -90,6 +114,34 @@ char *ld[]={
 	0
 };
 
+__attribute__((constructor))
+static void init_ld() {
+    char buf[256];
+    strcpy(buf, "-L");
+    strncat(buf, getenv("MOVBUILDDIR"), 255);
+    ld[5] = strdup(buf);
+    
+    strcpy(buf, "-L");
+    strncat(buf, getenv("MOVBUILDDIR"), 255);
+    strncat(buf, "/gcc/32", 255);
+    ld[6] = strdup(buf);
+    
+    strcpy(buf, "");
+    strncat(buf, getenv("MOVBUILDDIR"), 255);
+    strncat(buf, "/crt0.o", 255);
+    ld[10] = strdup(buf);
+    
+    strcpy(buf, "");
+    strncat(buf, getenv("MOVBUILDDIR"), 255);
+    strncat(buf, "/crtf.o", 255);
+    ld[13] = strdup(buf);
+    
+    strcpy(buf, "");
+    strncat(buf, getenv("MOVBUILDDIR"), 255);
+    strncat(buf, "/crtd.o", 255);
+    ld[14] = strdup(buf);
+}
+
 int option(char* arg) 
 {
 	if (strcmp(arg, "-g")==0) {
XXX

git apply 1.patch

./build.sh

mkdir -p "${PREFIX}"
mv build "${PREFIX}/build"

complete "${PREFIX}" "movfuscator-${VERSION}" "${OUTPUT}"
