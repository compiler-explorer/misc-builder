#!/bin/bash
SVN_BASEURL="https://svn.cs.ru.nl/repos"

if [ $# -ne 3 ]; then
	echo "Usage: $0 <package name> <os name> <architecture name>"
	exit 1
fi

PACKAGE=$1
OS=$2
ARCH=$3

mkdir -p src

if [ -e $PACKAGE/$OS-$ARCH/svn-sources.txt ]; then
	tr -d '\r' < $PACKAGE/$OS-$ARCH/svn-sources.txt | while read repo branch; do
		
		if [ ! -e src/$repo-`basename $branch` ]; then
			echo "Checking out svn repo: $repo / $branch"
            svn checkout -r HEAD -q $SVN_BASEURL/$repo/$branch src/$repo-`basename $branch`
		else
			echo "Skipping svn repo: $repo / $branch"
		fi
	done
fi

if [ -e $PACKAGE/$OS-$ARCH/git-sources.txt ]; then
	tr -d '\r' < $PACKAGE/$OS-$ARCH/git-sources.txt | while read url branch; do
		dir="src/$(basename $url)-$branch"
		if [ ! -e $dir ]; then
			echo "Cloning git repo: $url / $branch"
            git clone --recursive --depth 1 -b $branch $url.git $dir
		else
			echo "Skipping git repo: $url / $branch"
		fi
	done
fi
