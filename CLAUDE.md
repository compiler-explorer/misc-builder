# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This repository is part of the [Compiler Explorer](https://godbolt.org/) project. It builds Docker images used to create binary packages for various compilers and tools that are more difficult to build or have special requirements. These built tools are then used on the Compiler Explorer website.

## Architecture

The repository follows a consistent pattern:
- Each tool/compiler has its own `Dockerfile.{toolname}` (e.g., `Dockerfile.nix`, `Dockerfile.misc`)
- Each tool has a corresponding directory with build scripts (e.g., `nix/build.sh`, `misc/build-*.sh`)
- All build scripts use `common.sh` for shared functionality
- GitHub Actions builds and pushes Docker images to Docker Hub as `compilerexplorer/{toolname}-builder:latest`

## Key Commands

### Building and Testing Locally

```bash
# Build a Docker image for a specific tool (replace 'nix' with desired tool)
docker build -t builder -f Dockerfile.nix .

# Run a build script (example for nix); mounting `/tmp/out` as /build in the container, and outputting there
docker run --rm -v/tmp/out:/build builder ./build.sh 2.29.0 /build

# For debugging - start an interactive shell
docker run -it --rm builder bash
```

### Common Build Script Parameters

Most build scripts follow this pattern:
```bash
./build.sh <version> <output-directory> [optional-last-revision]
```

- `version`: The version/tag/branch to build
- `output-directory`: Where to place the resulting tar.xz file
- `optional-last-revision`: Previous revision (for skip detection)

## Build Process

1. Build scripts output metadata:
   - `ce-build-revision:` - The revision being built
   - `ce-build-output:` - Output file path
   - `ce-build-status:` - OK, SKIPPED, or error

2. The `common.sh` provides:
   - `initialise`: Sets up build, checks if already built
   - `complete`: Creates the final tar.xz archive
   - `get_remote_revision`: Gets git revision from remote

3. Output format: `{toolname}-{version}.tar.xz` containing the built binaries

## Adding New Tools

1. Create `Dockerfile.{toolname}` based on existing patterns
2. Create `{toolname}/build.sh` script
3. Add the new tool to `.github/workflows/build.yml` matrix
4. Ensure build script is executable: `chmod +x {toolname}/build.sh`

## Special Notes

- The `misc` Dockerfile contains multiple unrelated tools (legacy structure being split up)
- Some tools like `heaptrack` have both x86_64 and arm64 builds
- Build outputs are tar.xz archives with XZ compression using all available threads
