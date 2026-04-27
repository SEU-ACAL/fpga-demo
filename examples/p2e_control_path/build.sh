#!/bin/bash
set -euo pipefail
# ============================================================================
# FPGA P2E (Place and Route to Emulation) Complete Flow Script
# ============================================================================
# This script runs the complete FPGA design flow from synthesis to board debug
#
# Flow stages:
#   1. Environment setup
#   2. Synthesis (vvac + vsyn)
#   3. System build (vcom)
#   4. C build (sed + cmake)
#   5. Place & Route (PNR)
#   6. Board debug (vdbg)
#
# Usage: ./build.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/out}"

# ============================================================================
# Step 1: Environment Setup
# ============================================================================
source "$SCRIPT_DIR/sourceme.sh"

# Verify required commands are available
command -v vsyn >/dev/null || { echo "Error: vsyn not found"; exit 1; }
command -v vcom >/dev/null || { echo "Error: vcom not found"; exit 1; }
command -v vvac >/dev/null || { echo "Error: vvac not found"; exit 1; }

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

# ============================================================================
# Step 2: Synthesis - VVAC and VSYN
# ============================================================================
make -C "$SCRIPT_DIR" vvac
make -C "$SCRIPT_DIR" vsyn

# ============================================================================
# Step 3: System Build - Compile design with VCOM
# ============================================================================
make -C "$SCRIPT_DIR" vcom

# ============================================================================
# Step 4: C Build - Generate and compile C tester
# ============================================================================
# Run sed script to generate files
"$SCRIPT_DIR/sed.sh"

# Build C tester with cmake
cd "$CASE_HOME/src/c_src/build"
cmake ..
make
cd "$OUT_DIR"

# ============================================================================
# Step 5: Place and Route - FPGA implementation
# ============================================================================
test -d "$SCRIPT_DIR/fpgaCompDir" || { echo "Error: fpgaCompDir not found"; exit 1; }
make -C "$SCRIPT_DIR/fpgaCompDir" all
