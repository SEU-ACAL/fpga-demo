#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/out}"

# Source environment variables
source "$SCRIPT_DIR/sourceme.sh"
command -v vsyn >/dev/null || { echo "Error: vsyn not found"; exit 1; }
command -v vcom >/dev/null || { echo "Error: vcom not found"; exit 1; }
command -v vvac >/dev/null || { echo "Error: vvac not found"; exit 1; }

mkdir -p "$OUT_DIR"
export PROJECT_DIR="$SCRIPT_DIR"

# Change to out directory for all build operations
cd "$OUT_DIR"

# Copy necessary source files
cp -rf "$SCRIPT_DIR/src" .
cp "$SCRIPT_DIR/hw-config.hdf" .

# ============================================================================
# Step 1: VVAC - Generate VVAC wrapper
# ============================================================================
echo "Running VVAC..."
rm -rf config_dir && cp -rf ./src/config_dir ./
vvac -bc -f ./src/dut_rtl/dut_src/flist.lst -top dut_top | tee vvac.log


# ============================================================================
# Step 2: VSYN - Synthesis
# ============================================================================
echo "Running VSYN..."
vsyn -F ./vvacDir/vvac_by_mod/filelist -top xepic_vvac_top -o xepic_vvac_top.vm | tee vsyn.log

# ============================================================================
# Step 3: VCOM - System build
# ============================================================================
echo "Running VCOM..."
export __XEPIC_NEW_NETLIST_MACRO_FLOW=1
vcom "$SCRIPT_DIR/src/vcom_tcl/vcom_compile.tcl"

# ============================================================================
# Step 4: C Build - Generate and compile C tester
# ============================================================================
echo "Running sed script..."
bash "$SCRIPT_DIR/sed.sh"

echo "Building C tester..."
mkdir -p "$OUT_DIR/src/c_src/build"
cd "$OUT_DIR/src/c_src/build"
cmake ..
make
cd "$OUT_DIR"

# ============================================================================
# Step 5: PNR - Place and Route
# ============================================================================
echo "Running PNR..."
test -d fpgaCompDir || { echo "Error: fpgaCompDir not found"; exit 1; }
make -C fpgaCompDir all

echo "Build complete. Output in: $OUT_DIR"
