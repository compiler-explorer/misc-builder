#!/bin/bash Please-source-me

# Common utilities and setup for builds

set -euo pipefail

# get_remote_revision GITURL BRANCH
get_remote_revision() {
    local URL="$1"
    local BRANCH="$2"
    local REVISION
    REVISION=$(git ls-remote --tags --heads "${URL}" "refs/${BRANCH}" | cut -f 1)
    [[ -z "$REVISION" ]] && exit 255
    echo "$REVISION"
}

# compress_output <source folder> <name to be extracted as> <dest tar.xz file>
compress_output() {
    local SOURCE="$1"
    local FULLNAME="$2"
    local OUTPUT="$3"

    env XZ_DEFAULTS="-T 0" tar Jcf "${OUTPUT}" --transform "s,^./,./${FULLNAME}/," -C "${SOURCE}" .
}

# initialise REVISION OUTPUT_FILENAME
initialise() {
    local REVISION="$1"
    local OUTPUT="$2"
    echo "ce-build-revision:${REVISION}"
    echo "ce-build-output:${OUTPUT}"   
}

# skip_if_built REVISION PREV_REVISION
skip_if_built() {
    if [[ "${REVISION}" == "${LAST_REVISION}" ]]; then
        echo "ce-build-status:SKIPPED"
        exit
    fi
}

complete_ok() {
    echo "ce-build-status:OK"
}