#!/usr/bin/env bash
# build_ami.sh — Build AMI driver (ami.ko) + ami_tool from source.
# Uses local GLIBC, fixes the "GLIBC_2.33 not found" issue from prebuilt debs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
AVED_DIR="${AVED_DIR:-$ROOT_DIR/AVED}"
AMI_DIR="${AMI_DIR:-$AVED_DIR/sw/AMI}"

if [[ ! -d "$AMI_DIR" ]]; then
  echo "[build] ERROR: AMI source not found at $AMI_DIR"
  echo "[build] hint: run ./clone_aved.sh first"
  exit 1
fi

# ── Dependency checks ────────────────────────────────────────────────────────
need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[build] ERROR: missing dependency: $1"
    exit 1
  fi
}
need gcc
need make
need cmake

KHDR="/lib/modules/$(uname -r)/build"
if [[ ! -d "$KHDR" ]]; then
  echo "[build] ERROR: kernel headers not found: $KHDR"
  echo "[build] hint: sudo apt install linux-headers-$(uname -r)"
  exit 1
fi

# ── Build ────────────────────────────────────────────────────────────────────
# AMI build script must run from sw/AMI/ as cwd
echo "[build] building AMI driver + API + ami_tool in $AMI_DIR"
( cd "$AMI_DIR" && ./scripts/build.sh )

# ── Verify outputs ───────────────────────────────────────────────────────────
DRV_KO="$AMI_DIR/driver/ami.ko"
APP_BIN="$AMI_DIR/app/build/ami_tool"
API_LIB="$AMI_DIR/api/build/libami.a"

for f in "$DRV_KO" "$APP_BIN" "$API_LIB"; do
  if [[ ! -f "$f" ]]; then
    echo "[build] ERROR: expected artifact missing: $f"
    exit 1
  fi
done

echo ""
echo "[build] PASS — artifacts:"
echo "  driver:   $DRV_KO"
echo "  ami_tool: $APP_BIN"
echo "  libami:   $API_LIB"
echo ""
echo "[build] next: ./install_aved.sh   # to load driver + flash PDI"
