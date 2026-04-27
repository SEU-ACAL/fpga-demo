#!/bin/bash
set -euo pipefail


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

