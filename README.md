### Miscellaneous tool build scripts

The repository is part of the [Compiler Explorer](https://godbolt.org/) project. It builds
the docker images used to build some of the more...esoteric...tools used on the site.

For example, it builds the 6502 compiler.

It's in the process of being broken into smaller docker files, and/or separate repos as appropriate.
What "as appropriate" means is stlil being workde on. Each dockerfile is for one group of related
things, building a `XXX-builder` for the `Dockerfile.XXX` file. The `misc` Dockerfile itself is
for the super misc-y things that really only are one-off, though that's still being split up.

# Testing locally

Note: make sure you `chmod +x build/build-yourcompiler.sh` first

```
docker build -t builder -f Dockerfile.misc .
docker run --rm -v/tmp/out:/build builder ./build-yourcompiler.sh trunk /build
```

### Alternative to run (for better debugging)

* `docker run -t -i miscbuilder bash`
* `./build-yourcompiler.sh trunk`
