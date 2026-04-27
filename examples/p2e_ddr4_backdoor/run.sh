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
command -v vdbg >/dev/null
test -d "$OUT_DIR"
cd "$OUT_DIR"

# ============================================================================
# Step 5: Board Debug - Load bitstream and run on board
# ============================================================================
test -f "$SCRIPT_DIR/debug.tcl"
vdbg "$SCRIPT_DIR/debug.tcl"

