#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="${SRC_DIR:-$ROOT_DIR/dma_ip_drivers}"
REPO_URL="${REPO_URL:-https://github.com/Xilinx/dma_ip_drivers.git}"
REPO_REF="master"
VENDOR_ID="10ee"
# Known QDMA device IDs (searched first during auto-detection)
# V80 CPM5 QDMA = 50b5, common soft-IP QDMA IDs follow
KNOWN_QDMA_DEV_IDS="${KNOWN_QDMA_DEV_IDS:-50b5}"
PCI_IDS="${PCI_IDS:-$SRC_DIR/QDMA/linux-kernel/driver/src/pci_ids.h}"
KMOD_DIR="${KMOD_DIR:-$SRC_DIR/QDMA/linux-kernel}"
KO_PATH="${KO_PATH:-$KMOD_DIR/bin/qdma-pf.ko}"

if ! command -v lspci >/dev/null 2>&1; then
  echo "[install] ERROR: lspci not found"
  exit 1
fi

if [[ -z "${BUS_ID:-}" ]]; then
  # Try known QDMA device IDs first (e.g., V80 0x50b5)
  for _did in $KNOWN_QDMA_DEV_IDS; do
    BUS_ID="$(lspci -D -d ${VENDOR_ID}:${_did} 2>/dev/null | awk 'NR==1{print $1}')"
    [[ -n "$BUS_ID" ]] && break
  done
fi
if [[ -z "${BUS_ID:-}" ]]; then
  # Fall back to any Xilinx PCIe device
  BUS_ID="$(lspci -D -d ${VENDOR_ID}: | awk 'NR==1{print $1}')"
fi
if [[ -z "${BUS_ID:-}" ]]; then
  echo "[install] ERROR: no Xilinx PCIe device found"
  exit 1
fi

PCI_ID_PAIR="$(lspci -n -s "$BUS_ID" | awk 'NR==1{print tolower($3)}')"
if [[ -z "$PCI_ID_PAIR" || "$PCI_ID_PAIR" != *:* ]]; then
  echo "[install] ERROR: failed to parse PCI device id for $BUS_ID"
  exit 1
fi
PCI_VENDOR="${PCI_ID_PAIR%%:*}"
DEV_ID="${PCI_ID_PAIR##*:}"
if [[ "$PCI_VENDOR" != "$VENDOR_ID" ]]; then
  echo "[install] ERROR: unexpected vendor id 0x$PCI_VENDOR for $BUS_ID"
  exit 1
fi

echo "[install] target: $BUS_ID (device id 0x$DEV_ID)"

if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "[install] cloning dma_ip_drivers to $SRC_DIR"
  git clone "$REPO_URL" "$SRC_DIR"
fi

echo "[install] checkout $REPO_REF"
git -C "$SRC_DIR" fetch --all --tags
git -C "$SRC_DIR" checkout "$REPO_REF"

if [[ ! -f "$PCI_IDS" ]]; then
  echo "[install] ERROR: pci ids file not found: $PCI_IDS"
  exit 1
fi

if ! grep -Eqi "PCI_DEVICE\\(0x10ee,\\s*0x${DEV_ID}\\)" "$PCI_IDS"; then
  echo "[install] patching PCI id 0x$DEV_ID into $PCI_IDS"
  if [[ "$(awk '/^\s*\{0,\}\s*$/{n++} END{print n+0}' "$PCI_IDS")" -ne 1 ]]; then
    echo "[install] ERROR: expected exactly one '{0,}' sentinel in $PCI_IDS"
    exit 1
  fi
  awk -v devid="$DEV_ID" '
    /^\s*\{0,\}\s*$/ && !done {
      printf "\t{ PCI_DEVICE(0x10ee, 0x%s), }, /* auto-added */\n", devid;
      done = 1;
    }
    { print }
    END {
      if (!done) {
        exit 2;
      }
    }
  ' "$PCI_IDS" > "${PCI_IDS}.tmp"
  mv "${PCI_IDS}.tmp" "$PCI_IDS"
else
  echo "[install] PCI id 0x$DEV_ID already present"
fi

if [[ ! -f "$KMOD_DIR/Makefile" ]]; then
  echo "[install] ERROR: qdma kernel driver Makefile not found: $KMOD_DIR/Makefile"
  exit 1
fi

echo "[install] building in $KMOD_DIR"
make -C "$KMOD_DIR" clean
make -C "$KMOD_DIR" MODULE=mod_pf SKIP_STACK_VALIDATION=1 -j1 driver

if [[ ! -f "$KO_PATH" ]]; then
  echo "[install] ERROR: qdma module not found: $KO_PATH"
  exit 1
fi
echo "[install] module: $KO_PATH"

if lsmod | awk '$1=="ami"{found=1} END{exit !found}'; then
  echo "[install] removing ami"
  sudo rmmod ami
fi
if lsmod | awk '$1=="qdma_vf"{found=1} END{exit !found}'; then
  echo "[install] removing qdma_vf"
  sudo rmmod qdma_vf
fi
if lsmod | awk '$1=="qdma_pf"{found=1} END{exit !found}'; then
  echo "[install] removing qdma_pf"
  sudo rmmod qdma_pf
fi
if lsmod | awk '$1=="qdma"{found=1} END{exit !found}'; then
  echo "[install] removing qdma"
  sudo rmmod qdma
fi

echo "[install] loading qdma module"
sudo insmod "$KO_PATH"

if [[ -d "/sys/bus/pci/drivers/qdma-pf" ]]; then
  DRV_DIR="/sys/bus/pci/drivers/qdma-pf"
elif [[ -d "/sys/bus/pci/drivers/qdma" ]]; then
  DRV_DIR="/sys/bus/pci/drivers/qdma"
else
  echo "[install] ERROR: qdma driver sysfs entry not found"
  exit 1
fi

if [[ ! -e "/sys/bus/pci/devices/$BUS_ID" ]]; then
  echo "[install] ERROR: missing sysfs node for $BUS_ID"
  exit 1
fi
if [[ -e "/sys/bus/pci/devices/$BUS_ID/driver" ]]; then
  CUR_DRV="$(basename "$(readlink "/sys/bus/pci/devices/$BUS_ID/driver")")"
  if [[ "$CUR_DRV" != "$(basename "$DRV_DIR")" ]]; then
    echo "[install] unbinding $BUS_ID from $CUR_DRV"
    echo "$BUS_ID" | sudo tee "/sys/bus/pci/devices/$BUS_ID/driver/unbind" >/dev/null
  fi
fi

if [[ ! -e "$DRV_DIR/new_id" ]]; then
  echo "[install] ERROR: missing new_id node: $DRV_DIR/new_id"
  exit 1
fi
if [[ ! -e "$DRV_DIR/bind" ]]; then
  echo "[install] ERROR: missing bind node: $DRV_DIR/bind"
  exit 1
fi

echo "${VENDOR_ID} ${DEV_ID}" | sudo tee "$DRV_DIR/new_id" >/dev/null
echo "$BUS_ID" | sudo tee "$DRV_DIR/bind" >/dev/null

echo "[install] verify driver bind"
lspci -nnk -s "$BUS_ID"

echo "[install] verify devices"
if ! ls /dev/qdma* >/dev/null 2>&1; then
  echo "[install] ERROR: /dev/qdma* not found after bind"
  exit 1
fi
ls /dev/qdma*

echo "[install] done"
