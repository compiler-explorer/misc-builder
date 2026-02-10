#!/bin/bash
# perl/build.sh $VERSION /outdir $OPTREVISION
# $VERSION can be a released version or one of the perl development
# branches, including "blead" (aka trunk), maint-5.xx

set -ex
source common.sh

ROOT=$(pwd)
VERSION=$1
# determine build revision
LAST_REVISION="${3:-}"

SRCURL=https://www.cpan.org/src/5.0/
GITURL=https://github.com/Perl/perl5.git

SRCDIR="${ROOT}/perl"
[ -e "${SRCDIR}" ] && rm -rf "${SRCDIR}"

# use git for blead (aka trunk) or maint and CPAN for releases
# I doubt maint will be used
case $VERSION in
blead|maint-*)
    BRANCH=${VERSION}
    VERSION=${VERSION}-$(date +%Y%m%d)

    # Setup perl checkout
    git clone --depth 1 --single-branch -b "${BRANCH}" "${GITURL}" "${SRCDIR}"

    REF="heads/${BRANCH}"
    REVISION=$(get_remote_revision "${GITURL}" "${REF}")
    ;;
*)
    BASENAME="perl-$VERSION"
    FILE="${BASENAME}.tar.gz"
    ARCHIVEURL="${SRCURL}${FILE}"
    cd "${ROOT}"

    [ -e "${FILE}" ] && rm "${FILE}"
    curl -o "${FILE}" "${ARCHIVEURL}"

    # creates perl-X.XX.X aka $BASENAME
    [ -e "${BASENAME}" ] && rm -rf "${BASENAME}"
    tar xzf "${FILE}"
    mv "${BASENAME}" "${SRCDIR}"

    # patches older perls to build on modern systems
    perl -MDevel::PatchPerl -e 'Devel::PatchPerl->patch_source(@ARGV)' \
         "${VERSION}" "${SRCDIR}"
    REVISION="${VERSION}"
    ;;
esac

FULLNAME=perl-${VERSION}
if [[ -d "${2}" ]]; then
   OUTPUT=$2/${FULLNAME}.tar.xz
else
   OUTPUT=${2-$OUTPUT}
fi
initialise "${REVISION}" "${OUTPUT}" "${LAST_REVISION}"

STAGING_DIR=/opt/compiler-explorer/${FULLNAME}
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# Configure build
# modern perls can use -Dmksymlinks to do an out of
# tree build, but I don't trust it for older perls
#
# -de - -d use defaults, -e don't prompt to build Makefile etc
# -s (silent) is also common here but may make diagnosis harder
# -Dusedevel - required to build blead, harmless for other builds except
#   it sets -Dversiononly
# -Uversiononly - installs a "perl" binary, not just perl$VERSION
# -Dusethreads - enable threads, commonly set by vendors
# -Dman1dir=none -Dman3dir=none - don't install man pages
# -Duseshrplib - build libperl as a shared library
# -Dlibperl - name of libperl shared object (otherwise just libperl.so)
cd "${SRCDIR}"
./Configure \
    -de \
    -Dusedevel \
    -Uversiononly \
    -Dprefix="${STAGING_DIR}" \
    -Dusethreads \
    -Dman1dir=none \
    -Dman3dir=none \
    -Duseshrplib \
    -Dlibperl=libperl-${VERSION}.so

# Build and install artifacts
make -j $(nproc)
make install

# delete installed pod, perldiag.pod is used by diagnostics.pm
find "${STAGING_DIR}" -name '*.pod' ! -name perldiag.pod -print0 | xargs -0 rm --

# make sure it works
"${STAGING_DIR}/bin/perl" -V

complete "${STAGING_DIR}" "${FULLNAME}" "${OUTPUT}"
