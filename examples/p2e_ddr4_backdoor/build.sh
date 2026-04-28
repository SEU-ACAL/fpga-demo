#!/bin/bash
set -euo pipefail
# ============================================================================
# FPGA P2E (Place and Route to Emulation) Complete Flow Script
# ============================================================================
# This script runs the complete FPGA design flow from synthesis to board debug
#
# Flow stages:
#   1. Environment setup
#   2. Synthesis (vsyn)
#   3. System build (vcom)
#   4. Place & Route (PNR)
#   5. Board debug (vdbg)
#
# Usage: ./run_p2e.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/out}"

# Source environment variables (HPEC_HOME, VIVADO_PATH, licenses, etc.)
source "$SCRIPT_DIR/sourceme.sh"
command -v vsyn >/dev/null
command -v vcom >/dev/null
mkdir -p "$OUT_DIR"
export PROJECT_DIR="$SCRIPT_DIR"

FLIST_ABS="$OUT_DIR/flist.abs.lst"
awk -v root="$SCRIPT_DIR" '{
  if ($0 ~ /^[[:space:]]*#/ || $0 ~ /^[[:space:]]*$/) {
    print $0
  } else if ($0 ~ /^\.\//) {
    print root "/" substr($0, 3)
  } else {
    print $0
  }
}' "$SCRIPT_DIR/flist.lst" > "$FLIST_ABS"
cd "$OUT_DIR"

# ============================================================================
# Step 2: Synthesis - Convert RTL to netlist
# ============================================================================
vsyn -f "$FLIST_ABS" -t pcie3_ddr4 -o rev_1/pcie3_ddr4.vm

# ============================================================================
# Step 3: System Build - Compile design with VCOM
# ============================================================================
export __XEPIC_NEW_NETLIST_MACRO_FLOW=1
vcom "$SCRIPT_DIR/vcom_compile.tcl"

# ============================================================================
# Step 4: Place and Route - FPGA implementation
# ============================================================================
test -d fpgaCompDir
make -C fpgaCompDir all

