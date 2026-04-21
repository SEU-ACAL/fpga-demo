#!/usr/bin/env bash
# run.sh — Flash XDMA+BRAM bitstream onto AU280, PCIe hot-reset, reload driver, run H2C test.
# Run as normal user; sudo is used only for privileged operations.
# Handles multi-card setups (multiple AU280s).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
BIT="${BUILD_DIR}/xdma_bram_bd_wrapper.bit"
LTX="${BUILD_DIR}/xdma_bram_bd_wrapper.ltx"
PROGRAM_TCL="${SCRIPT_DIR}/../../scripts/program_fpga.tcl"
HW_SERVER="${HW_SERVER:-localhost:3121}"

# ── Detect target BDF BEFORE touching anything ──────────────────────────────
# Priority: env BUS_ID > sysfs (xdma loaded) > lspci (driver unloaded).
if [[ -z "${BUS_ID:-}" ]]; then
    BUS_ID="$(basename "$(readlink /sys/class/xdma/xdma0_h2c_0/device 2>/dev/null)" 2>/dev/null || echo "")"
fi
if [[ -z "$BUS_ID" ]]; then
    BUS_ID="$(lspci -d 10ee: -D 2>/dev/null | head -1 | awk '{print $1}')"
fi
if [[ -z "$BUS_ID" ]]; then
    echo "[run] ERROR: no Xilinx PCIe device found. Set BUS_ID env var."
    exit 1
fi
echo "[run] target BDF: $BUS_ID"

# ── 1. Unload XDMA driver ───────────────────────────────────────────────────
echo "[run] unloading xdma driver..."
sudo rmmod xdma 2>/dev/null || true

# ── 2. Remove target PCIe device ────────────────────────────────────────────
echo "[run] removing PCIe device $BUS_ID..."
if [[ -e "/sys/bus/pci/devices/$BUS_ID" ]]; then
    sudo sh -c "echo 1 > /sys/bus/pci/devices/$BUS_ID/remove"
    sleep 1
fi

# ── 3. Flash bitstream via JTAG ─────────────────────────────────────────────
echo "[run] programming bitstream: $BIT"
if [[ ! -f "$BIT" ]]; then
    echo "[run] ERROR: bitstream not found. Build first:"
    echo "  vivado -mode batch -source build.tcl -tclargs ./build xcu280-fsvh2892-2L-e"
    exit 1
fi
PROBES_ARG=""
[[ -f "$LTX" ]] && PROBES_ARG="-probes_path $LTX"
vivado -mode batch -source "$PROGRAM_TCL" \
    -tclargs -bitstream_path "$BIT" $PROBES_ARG -hw_server "$HW_SERVER"

# ── 4. PCIe rescan ──────────────────────────────────────────────────────────
echo "[run] waiting for FPGA to stabilize..."
sleep 3

# Blacklist xdma during rescan to prevent udev auto-loading it mid-probe.
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

# ── 5. Reload XDMA driver ──────────────────────────────────────────────────
echo "[run] loading xdma driver (poll_mode=1)..."
if lsmod | grep -q '^xdma'; then
    for i in 1 2 3 4 5; do sudo rmmod xdma 2>/dev/null && break; sleep 1; done
fi
XDMA_KO="$(find /lib/modules/"$(uname -r)" -name 'xdma.ko' 2>/dev/null | head -1)"
if [[ -z "$XDMA_KO" ]]; then
    echo "[run] ERROR: xdma.ko not found in /lib/modules/$(uname -r)"
    exit 1
fi
sudo insmod "$XDMA_KO" poll_mode=1
sleep 1

# ── 6. Find which xdma index got our BDF ────────────────────────────────────
XDMA_DEV=""
for dev in /sys/class/xdma/xdma*_h2c_0/device; do
    [[ -e "$dev" ]] || continue
    if [[ "$(basename "$(readlink "$dev")")" == "$BUS_ID" ]]; then
        XDMA_DEV="$(basename "$(dirname "$dev")" | sed 's/_h2c_0//')"
        break
    fi
done
if [[ -z "$XDMA_DEV" ]]; then
    echo "[run] ERROR: cannot find xdma device for $BUS_ID"
    for dev in /sys/class/xdma/xdma*_h2c_0/device; do
        [[ -e "$dev" ]] && echo "  $(basename "$(dirname "$dev")" | sed 's/_h2c_0//') -> $(basename "$(readlink "$dev")")"
    done
    exit 1
fi
echo "[run] $BUS_ID bound as $XDMA_DEV"

# ── 7. Fix permissions & run test ───────────────────────────────────────────
sudo chmod a+rw /dev/${XDMA_DEV}_* 2>/dev/null || true

H2C="/dev/${XDMA_DEV}_h2c_0"
C2H="/dev/${XDMA_DEV}_c2h_0"
if [[ ! -e "$H2C" ]]; then
    echo "[run] ERROR: $H2C not found"
    exit 1
fi
echo "[run] devices ready: $H2C / $C2H"

echo "[run] running H2C write/read test..."
python3 "${SCRIPT_DIR}/test_h2c.py" --h2c "$H2C" --c2h "$C2H" --offset 0x0 --size 4096
echo "[run] PASS"
