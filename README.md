### Miscellaneous tool build scripts

The repository is part of the [Compiler Explorer](https://godbolt.org/) project. It builds
the docker images used to build some of the more...esoteric...tools used on the site.

For example, it builds the 6502 compiler.

It's in the process of being broken into smaller docker files, and/or separate repos as appropriate.
What "as appropriate" means is still being worked on. Each dockerfile is for one group of related
things, building a `XXX-builder` for the `Dockerfile.XXX` file. The `misc` Dockerfile itself is
for the super misc-y things that really only are one-off, though that's still being split up.

If you add a new Dockerfile, you'll need to edit the matrix in the `.github/workflows/build.yml` file.

# Testing locally

Note: make sure you `chmod +x yourlanguage/build-yourcompiler.sh` first.

```shell
# Building the Docker image with tag `builder`
docker build -t builder -f Dockerfile.misc .

# Running the build script in the container directly
docker run --rm -v/tmp/out:/build builder ./build-yourcompiler.sh trunk /build

# Alternative to running the build script 
#  (It first starts a bash terminal inside the container, so it's easier for debugging.)
docker run -t -i miscbuilder bash
./build-yourcompiler.sh trunk /build
```

> Note: Different compiler builder scripts may require different command line arguments, check your script for details.