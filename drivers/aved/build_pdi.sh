#!/usr/bin/env bash
# build_pdi.sh — Build the V80 AVED design PDI from source.
# Requires Vivado 2024.1 + SMBus IP (manual download from xilinx.com).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
AVED_DIR="${AVED_DIR:-$ROOT_DIR/AVED}"
DESIGN="${DESIGN:-amd_v80_gen5x8_25.1}"
HW_DIR="${HW_DIR:-$AVED_DIR/hw/$DESIGN}"
SMBUS_IP_DIR="$HW_DIR/src/iprepo/smbus_v1_1"
EXPECTED_VIVADO="2024.2"

if [[ ! -d "$HW_DIR" ]]; then
  echo "[build-pdi] ERROR: hw source not found at $HW_DIR"
  echo "[build-pdi] hint: run ./clone_aved.sh first"
  exit 1
fi

# ── Vivado check ─────────────────────────────────────────────────────────────
# Auto-source settings64.sh if VIVADO_SETTINGS is set
# if [[ -n "${VIVADO_SETTINGS:-}" ]]; then
#   if [[ ! -f "$VIVADO_SETTINGS" ]]; then
#     echo "[build-pdi] ERROR: VIVADO_SETTINGS not found: $VIVADO_SETTINGS"
#     exit 1
#   fi
#   echo "[build-pdi] sourcing $VIVADO_SETTINGS"
#   # shellcheck disable=SC1090
#   source "$VIVADO_SETTINGS"
# fi

if ! command -v vivado >/dev/null 2>&1; then
  echo "[build-pdi] ERROR: vivado not in PATH"
  echo "[build-pdi] hint: source /tools/Xilinx/Vivado/$EXPECTED_VIVADO/settings64.sh"
  echo "[build-pdi]    or: VIVADO_SETTINGS=/path/to/settings64.sh ./build_pdi.sh"
  exit 1
fi
# vivado -version output: "vivado v2024.1 (64-bit)" — extract the v2024.1 token
VIVADO_VER="$(vivado -version 2>/dev/null | awk 'tolower($1)=="vivado" {gsub(/^v/, "", $2); print $2; exit}')"
echo "[build-pdi] vivado version: ${VIVADO_VER:-unknown}"
if [[ -z "$VIVADO_VER" ]]; then
  echo "[build-pdi] ERROR: failed to parse vivado version"
  exit 1
fi
if [[ "$VIVADO_VER" != "$EXPECTED_VIVADO"* ]]; then
  echo "[build-pdi] WARNING: expected $EXPECTED_VIVADO, got $VIVADO_VER"
  echo "[build-pdi]          AVED 24.1 is verified only with $EXPECTED_VIVADO"
fi

# ── SMBus IP check ───────────────────────────────────────────────────────────
if [[ ! -d "$SMBUS_IP_DIR" ]] || [[ -z "$(ls -A "$SMBUS_IP_DIR" 2>/dev/null)" ]]; then
  cat <<EOF
[build-pdi] ERROR: SMBus IP missing at:
              $SMBUS_IP_DIR

  Manual step required:
    1. Download SMBus IP from https://www.xilinx.com/member/v80.html
       (requires AMD account, look for "smbus_v1_1")
    2. Extract into: $SMBUS_IP_DIR/
       Sibling iprepo dirs (cmd_queue_v2_0, hw_discovery_v1_0, ...) already present.
    3. Re-run this script.
EOF
  exit 1
fi

# ── bootgen / python3 check ──────────────────────────────────────────────────
need() {
  command -v "$1" >/dev/null 2>&1 || { echo "[build-pdi] ERROR: missing: $1"; exit 1; }
}
need bootgen
need python3

# ── Build ────────────────────────────────────────────────────────────────────
echo "[build-pdi] starting full AVED build (HW + FW + FPT + PDI). this takes hours."
echo "[build-pdi] cwd: $HW_DIR"
( cd "$HW_DIR" && ./build_all.sh )

PDI_OUT="$HW_DIR/$DESIGN.pdi"
if [[ ! -f "$PDI_OUT" ]]; then
  echo "[build-pdi] ERROR: PDI not produced: $PDI_OUT"
  echo "[build-pdi] check log: $HW_DIR/build/vivado.log"
  exit 1
fi

echo ""
echo "[build-pdi] PASS — PDI: $PDI_OUT"
echo "[build-pdi] next: AVED_PDI=$PDI_OUT ./install_aved.sh"
