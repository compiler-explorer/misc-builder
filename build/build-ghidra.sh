#!/bin/bash
set -e

# SUDO_PREFIX="sudo"
SUDO_PREFIX=""

# install binutils and zlib
echo "Installing binutils and zlib..."
$SUDO_PREFIX apt-get update && $SUDO_PREFIX apt-get install -y binutils-dev zlib1g-dev

# clone Ghidra fork into /opt/ghidra if it does not already exist
echo "Cloning Ghidra fork into /opt/ghidra..."
if [ ! -d "/opt/ghidra" ]; then
    $SUDO_PREFIX git clone https://github.com/nimashoghi/ghidra.git /opt/ghidra
fi

# build ghidra decompiler
echo "Building ghidra decompiler..."
DECOMPILER_SRC_DIR="/opt/ghidra/Ghidra/Features/Decompiler/src/decompile/cpp"
pushd $DECOMPILER_SRC_DIR
make -j
make -j decomp_opt
make -j sleigh_opt
popd

# copy decompiler ('decomp_opt') and sleigh compiler ('sleigh_opt') into /usr/local/bin
echo "Copying decompiler ('decomp_opt') and sleigh compiler ('sleigh_opt') into /usr/local/bin..."
$SUDO_PREFIX cp $DECOMPILER_SRC_DIR/decomp_opt /usr/local/bin/ghidra_decomp
$SUDO_PREFIX cp $DECOMPILER_SRC_DIR/sleigh_opt /usr/local/bin/ghidra_sleigh

# for the supported architectures, use the sleigh compiler to generate the sleigh .sla files
# supported architectures: x86, x86-64
echo "Generating sleigh .sla files for supported architectures..."
SUPPORTED_ARCHS=("x86/data/languages/x86" "x86/data/languages/x86-64")
PROCESSORS_BASE_DIR="/opt/ghidra/Ghidra/Processors"
for ARCH in "${SUPPORTED_ARCHS[@]}"
do
    echo "Generating $ARCH..."
    $SUDO_PREFIX ghidra_sleigh $PROCESSORS_BASE_DIR/$ARCH.slaspec
done

# Move the compiled Processors folder to /usr/local/share/ghidra/Ghidra/Processors
echo "Moving the compiled Processors folder to /usr/local/share/ghidra/..."
$SUDO_PREFIX mkdir -p /usr/local/share/ghidra/Ghidra
$SUDO_PREFIX cp -r $PROCESSORS_BASE_DIR /usr/local/share/ghidra/Ghidra/

echo "Done!"
