#!/usr/bin/env bash
# jtag_flash.sh — Flash V80 design PDI via JTAG / Vivado program_flash.
#
# When AMI/AMC version mismatch prevents the in-band flash path, use this
# out-of-band route: USB-JTAG cable → hw_server → program_flash writes the
# design PDI directly to OSPI flash, then a power cycle boots the new design.
#
# Prerequisites:
#   - V80 USB-JTAG cable connected (look for /dev/ttyUSB*, usually 4 of them)
#   - Vivado 2024.1 sourced (or set VIVADO_SETTINGS=/path/to/settings64.sh)
#   - design.pdi  + v80_initialization.pdi from an AVED deployment archive
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Inputs ───────────────────────────────────────────────────────────────────
# Auto-discover prebuilt PDIs on /opt/amd/aved if not overridden
if [[ -z "${AVED_PDI:-}" ]]; then
  AVED_PDI="$(ls /opt/amd/aved/*/design.pdi 2>/dev/null | head -1 || true)"
fi
if [[ -z "${INIT_PDI:-}" ]]; then
  INIT_PDI="$(ls /opt/amd/aved/*/flash_setup/v80_initialization.pdi 2>/dev/null | head -1 || true)"
fi
HW_SERVER_URL="${HW_SERVER_URL:-tcp:localhost:3121}"
FLASH_TYPE="${FLASH_TYPE:-ospi-x8-single}"

# ── Vivado env ───────────────────────────────────────────────────────────────
if [[ -n "${VIVADO_SETTINGS:-}" && -f "$VIVADO_SETTINGS" ]]; then
  echo "[jtag] sourcing $VIVADO_SETTINGS"
  # shellcheck disable=SC1090
  source "$VIVADO_SETTINGS"
fi

for tool in program_flash hw_server; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "[jtag] ERROR: $tool not in PATH"
    echo "[jtag] hint: source /data0/tools/Xilinx/Vivado/2024.1/settings64.sh"
    echo "[jtag]    or: VIVADO_SETTINGS=/path/to/settings64.sh ./jtag_flash.sh"
    exit 1
  fi
done

# ── Validate inputs ──────────────────────────────────────────────────────────
if [[ -z "$AVED_PDI" || ! -f "$AVED_PDI" ]]; then
  echo "[jtag] ERROR: design PDI not found"
  echo "[jtag] hint: AVED_PDI=/opt/amd/aved/.../design.pdi $0"
  exit 1
fi
if [[ -z "$INIT_PDI" || ! -f "$INIT_PDI" ]]; then
  echo "[jtag] ERROR: v80_initialization.pdi not found"
  echo "[jtag] hint: INIT_PDI=/opt/amd/aved/.../flash_setup/v80_initialization.pdi $0"
  exit 1
fi

echo "[jtag] design PDI : $AVED_PDI"
echo "[jtag] init PDI   : $INIT_PDI"
echo "[jtag] flash type : $FLASH_TYPE"
echo "[jtag] hw_server  : $HW_SERVER_URL"

# ── JTAG cable check ─────────────────────────────────────────────────────────
if ! ls /dev/ttyUSB* >/dev/null 2>&1; then
  echo "[jtag] WARNING: no /dev/ttyUSB* found — is the USB-JTAG cable plugged in?"
fi

# ── Start hw_server if not running ───────────────────────────────────────────
HW_SERVER_PID=""
cleanup() {
  if [[ -n "$HW_SERVER_PID" ]] && kill -0 "$HW_SERVER_PID" 2>/dev/null; then
    echo "[jtag] stopping hw_server (pid $HW_SERVER_PID)"
    kill "$HW_SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if ! pgrep -x hw_server >/dev/null 2>&1; then
  echo "[jtag] starting hw_server in background"
  # Don't use -d (daemon mode) — that forks and leaves us with a stale PID.
  # Background with & so we keep the real PID for cleanup.
  nohup hw_server >/tmp/hw_server.log 2>&1 &
  HW_SERVER_PID=$!
  sleep 3
  if ! kill -0 "$HW_SERVER_PID" 2>/dev/null; then
    echo "[jtag] ERROR: hw_server died — see /tmp/hw_server.log"
    exit 1
  fi
else
  echo "[jtag] hw_server already running (pid $(pgrep -x hw_server))"
fi

# ── Flash OSPI ───────────────────────────────────────────────────────────────
echo ""
echo "[jtag] === programming OSPI flash ==="
echo "[jtag] this takes 10-20 minutes; do NOT interrupt"
echo ""

program_flash \
  -f "$AVED_PDI" \
  -flash_type "$FLASH_TYPE" \
  -pdi "$INIT_PDI" \
  -url "$HW_SERVER_URL" \
  -verify

echo ""
echo "[jtag] === flash programming complete ==="
echo ""
echo "[jtag] NEXT STEPS:"
echo "  1. Cold-reboot the host (full power cycle, not just warm reboot)"
echo "  2. After boot, verify QDMA PF1 is enumerated:"
echo "       lspci -d 10ee:50b5"
echo "  3. Re-bind the new ami driver:"
echo "       ./install_aved.sh   # (without AVED_PDI; just loads driver)"
echo "  4. Then run examples/v80_qdma_*/run.sh"
