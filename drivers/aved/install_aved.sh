#!/usr/bin/env bash
# install_aved.sh — Install AMI driver, optionally flash design PDI.
# Steps:
#   1. Unload conflicting drivers (qdma_pf, old ami)
#   2. Insmod the freshly built ami.ko
#   3. (Optional) Flash AVED PDI via ami_tool, then PCIe rescan
#   4. Verify 10ee:50b5 (QDMA PF1) appears
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
AVED_DIR="${AVED_DIR:-$ROOT_DIR/AVED}"
AMI_DIR="${AMI_DIR:-$AVED_DIR/sw/AMI}"
DRV_KO="${DRV_KO:-$AMI_DIR/driver/ami.ko}"
AMI_TOOL="${AMI_TOOL:-$AMI_DIR/app/build/ami_tool}"

# Auto-discover prebuilt PDI on this host if AVED_PDI not set
if [[ -z "${AVED_PDI:-}" ]]; then
  AVED_PDI="$(ls /opt/amd/aved/*/design.pdi 2>/dev/null | head -1 || true)"
fi

# ── 1. Unload conflicting drivers ────────────────────────────────────────────
for mod in qdma_pf qdma_vf qdma ami; do
  if lsmod | awk -v m="$mod" '$1==m{found=1} END{exit !found}'; then
    echo "[install] removing $mod"
    sudo rmmod "$mod"
  fi
done

# ── 2. Load freshly built ami.ko ─────────────────────────────────────────────
if [[ ! -f "$DRV_KO" ]]; then
  echo "[install] ERROR: ami.ko not found: $DRV_KO"
  echo "[install] hint: run ./build_ami.sh first"
  exit 1
fi
echo "[install] loading $DRV_KO"
sudo insmod "$DRV_KO"

# Bind ami driver to the management PF (10ee:50b4)
MGMT_BUS="$(lspci -D -d 10ee:50b4 2>/dev/null | awk 'NR==1{print $1}')"
if [[ -n "$MGMT_BUS" ]] && [[ -d /sys/bus/pci/drivers/ami ]]; then
  if [[ ! -e "/sys/bus/pci/drivers/ami/$MGMT_BUS" ]]; then
    echo "[install] binding ami to $MGMT_BUS"
    echo "10ee 50b4" | sudo tee /sys/bus/pci/drivers/ami/new_id >/dev/null 2>&1 || true
    echo "$MGMT_BUS" | sudo tee /sys/bus/pci/drivers/ami/bind >/dev/null 2>&1 || true
  fi
fi

# Wait briefly for /dev nodes
sleep 1

# ── 3. Verify ami_tool runs on this host ─────────────────────────────────────
if [[ -x "$AMI_TOOL" ]]; then
  echo "[install] ami_tool sanity:"
  "$AMI_TOOL" --version 2>&1 || true
  echo ""
  echo "[install] ami_tool overview:"
  sudo "$AMI_TOOL" overview 2>&1 || true
fi

# ── 4. Optionally flash PDI ──────────────────────────────────────────────────
if [[ -n "$AVED_PDI" ]]; then
  if [[ ! -f "$AVED_PDI" ]]; then
    echo "[install] ERROR: PDI not found: $AVED_PDI"
    exit 1
  fi
  echo "[install] using PDI: $AVED_PDI"
  if [[ ! -x "$AMI_TOOL" ]]; then
    echo "[install] ERROR: ami_tool not built; cannot flash PDI"
    exit 1
  fi
  if [[ -z "$MGMT_BUS" ]]; then
    echo "[install] ERROR: no V80 management PF (10ee:50b4) found; cannot flash PDI"
    exit 1
  fi
  echo "[install] flashing PDI: $AVED_PDI → $MGMT_BUS"
  echo "[install] this takes >10 minutes; do NOT interrupt"
  sudo "$AMI_TOOL" cfgmem_program -d "$MGMT_BUS" -t primary -i "$AVED_PDI" -p 0 -y

  echo "[install] cold-reboot or PCIe rescan needed to enumerate new PFs"
  echo "[install] attempting hot rescan..."
  sudo sh -c 'echo 1 > /sys/bus/pci/rescan' || true
  sleep 2
else
  echo "[install] skip PDI flash (set AVED_PDI=/path/to/design.pdi to enable)"
fi

# ── 5. Verify QDMA PF1 (50b5) appears ────────────────────────────────────────
echo ""
echo "[install] === final state ==="
lspci -d 10ee: -nn || true

if lspci -d 10ee:50b5 2>/dev/null | grep -q .; then
  echo ""
  echo "[install] PASS — V80 QDMA PF1 (10ee:50b5) is visible"
  echo "[install] next: cd ../qdma && sudo ./install_qdma.sh"
else
  echo ""
  echo "[install] WARNING — QDMA PF1 (10ee:50b5) still not visible"
  echo "[install] possible causes:"
  echo "  - PDI not flashed (set AVED_PDI and re-run)"
  echo "  - PDI flashed but cold reboot required (warm rescan often insufficient)"
  echo "  - AVED design used does not enable QDMA on PF1"
fi
