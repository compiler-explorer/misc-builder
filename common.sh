#!/bin/bash Please-source-me

# Common utilities and setup for builds

get_remote_revision() {
    local URL="$1"
    local BRANCH="$2"
    local REVISION
    REVISION=$(git ls-remote --tags --heads "${URL}" "refs/${BRANCH}" | cut -f 1)
    [[ -z "$REVISION" ]] && exit 255
    echo "$REVISION"
}
