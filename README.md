### Miscellaneous tool build scripts

The repository is part of the [Compiler Explorer](https://godbolt.org/) project. It builds
the docker images used to build some of the more...esoteric...tools used on the site.

For example, it builds the 6502 compiler.

# Testing locally

Note: make sure you `chmod +x build/build-yourcompiler.sh` first

```
sudo docker build -t miscbuilder .
sudo docker run miscbuilder ./build-yourcompiler.sh trunk
```
