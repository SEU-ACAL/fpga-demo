#!/usr/bin/env bash
# run.sh — Flash XDMA User BAR bitstream, PCIe hot-reset, reload driver, run MMIO test.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
BIT="${BUILD_DIR}/xdma_user_bd_wrapper.bit"
PROGRAM_TCL="${SCRIPT_DIR}/../../scripts/program_fpga.tcl"
HW_SERVER="${HW_SERVER:-localhost:3121}"

# ── Detect target BDF ───────────────────────────────────────────────────────
if [[ -z "${BUS_ID:-}" ]]; then
    BUS_ID="$(basename "$(readlink /sys/class/xdma/xdma0_user/device 2>/dev/null)" 2>/dev/null || echo "")"
fi
if [[ -z "$BUS_ID" ]]; then
    BUS_ID="$(lspci -d 10ee: -D 2>/dev/null | head -1 | awk '{print $1}')"
fi
if [[ -z "$BUS_ID" ]]; then
    echo "[run] ERROR: no Xilinx PCIe device found. Set BUS_ID env var."
    exit 1
fi
echo "[run] target BDF: $BUS_ID"

# ── 1. Unload driver ────────────────────────────────────────────────────────
echo "[run] unloading xdma driver..."
sudo rmmod xdma 2>/dev/null || true

# ── 2. Remove PCIe device ───────────────────────────────────────────────────
echo "[run] removing PCIe device $BUS_ID..."
if [[ -e "/sys/bus/pci/devices/$BUS_ID" ]]; then
    sudo sh -c "echo 1 > /sys/bus/pci/devices/$BUS_ID/remove"
    sleep 1
fi

# ── 3. Flash bitstream ──────────────────────────────────────────────────────
echo "[run] programming bitstream: $BIT"
if [[ ! -f "$BIT" ]]; then
    echo "[run] ERROR: bitstream not found. Build first:"
    echo "  vivado -mode batch -source build.tcl -tclargs ./build xcu280-fsvh2892-2L-e"
    exit 1
fi
vivado -mode batch -source "$PROGRAM_TCL" \
    -tclargs -bitstream_path "$BIT" -hw_server "$HW_SERVER"

# ── 4. PCIe rescan ──────────────────────────────────────────────────────────
echo "[run] waiting for FPGA to stabilize..."
sleep 3

BLACKLIST="/etc/modprobe.d/tmp-xdma-blacklist.conf"
sudo sh -c "echo 'blacklist xdma' > $BLACKLIST"
trap 'sudo rm -f "$BLACKLIST"' EXIT

echo "[run] rescanning PCIe bus..."
sudo sh -c "echo 1 > /sys/bus/pci/rescan"
sleep 2

sudo rm -f "$BLACKLIST"
trap - EXIT

if [[ ! -e "/sys/bus/pci/devices/$BUS_ID" ]]; then
    echo "[run] ERROR: device $BUS_ID did not reappear after rescan"
    exit 1
fi
echo "[run] device $BUS_ID is back"

# ── 5. Reload driver ────────────────────────────────────────────────────────
echo "[run] loading xdma driver (poll_mode=1)..."
if lsmod | grep -q '^xdma'; then
    for i in 1 2 3 4 5; do sudo rmmod xdma 2>/dev/null && break; sleep 1; done
fi
XDMA_KO="$(find /lib/modules/"$(uname -r)" -name 'xdma.ko' 2>/dev/null | head -1)"
if [[ -z "$XDMA_KO" ]]; then
    echo "[run] ERROR: xdma.ko not found"
    exit 1
fi
sudo insmod "$XDMA_KO" poll_mode=1
sleep 1

# ── 6. Find xdma device for our BDF ─────────────────────────────────────────
XDMA_DEV=""
for dev in /sys/class/xdma/xdma*_user/device; do
    [[ -e "$dev" ]] || continue
    if [[ "$(basename "$(readlink "$dev")")" == "$BUS_ID" ]]; then
        XDMA_DEV="$(basename "$(dirname "$dev")" | sed 's/_user//')"
        break
    fi
done
if [[ -z "$XDMA_DEV" ]]; then
    echo "[run] ERROR: cannot find xdma user device for $BUS_ID"
    exit 1
fi
echo "[run] $BUS_ID bound as $XDMA_DEV"

# ── 7. Run test ─────────────────────────────────────────────────────────────
USER_DEV="/dev/${XDMA_DEV}_user"
sudo chmod a+rw "$USER_DEV" 2>/dev/null || true

if [[ ! -e "$USER_DEV" ]]; then
    echo "[run] ERROR: $USER_DEV not found"
    exit 1
fi
echo "[run] device ready: $USER_DEV"

echo "[run] running User BAR MMIO test..."
python3 "${SCRIPT_DIR}/test_user.py" --dev "$USER_DEV" --offset 0x0 --count 64
echo "[run] PASS"
