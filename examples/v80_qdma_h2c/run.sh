#!/usr/bin/env bash
# run.sh — V80 QDMA DMA H2C/C2H write/read test.
# Sets up MM queues, runs DMA transfer test, cleans up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── 1. Discover QDMA PF ──────────────────────────────────────────────────────
# V80 QDMA PCI ID: 10ee:50b5 (CPM5 hardened, PF1)
if [[ -z "${BUS_ID:-}" ]]; then
  BUS_ID="$(lspci -D -d 10ee:50b5 2>/dev/null | head -1 | awk '{print $1}')"
fi
if [[ -z "${BUS_ID:-}" ]]; then
  BUS_ID="$(lspci -D -d 10ee: 2>/dev/null | head -1 | awk '{print $1}')"
fi
if [[ -z "${BUS_ID:-}" ]]; then
  echo "[run] ERROR: no QDMA PCIe device found. Set BUS_ID env var."
  exit 1
fi
echo "[run] target BDF: $BUS_ID"

# ── 2. Derive QDMA device name ───────────────────────────────────────────────
# QDMA device name: qdmaXXXXX from BDF (strip domain, colons, dots)
# e.g., 0000:21:00.1 → qdma21001
if [[ -z "${QDMA_DEV:-}" ]]; then
  QDMA_DEV="qdma$(echo "$BUS_ID" | sed 's/^[0-9a-f]*://; s/[:\.]//g')"
fi
echo "[run] QDMA device: $QDMA_DEV"

# ── 3. Set qmax ──────────────────────────────────────────────────────────────
QMAX_PATH="/sys/bus/pci/devices/$BUS_ID/qdma/qmax"
if [[ ! -e "$QMAX_PATH" ]]; then
  echo "[run] ERROR: qmax not found: $QMAX_PATH"
  echo "[run] hint: is the QDMA driver loaded and bound to $BUS_ID?"
  exit 1
fi

QMAX="${QMAX:-2}"
echo "[run] setting qmax=$QMAX"
echo "$QMAX" | sudo tee "$QMAX_PATH" >/dev/null

# ── 4. Add + start MM queues ─────────────────────────────────────────────────
QUEUE_H2C="${QUEUE_H2C:-0}"
QUEUE_C2H="${QUEUE_C2H:-1}"

echo "[run] adding queue $QUEUE_H2C (H2C, MM mode)"
sudo dma-ctl "${QDMA_DEV}" q add idx "$QUEUE_H2C" mode mm dir h2c
echo "[run] starting queue $QUEUE_H2C"
sudo dma-ctl "${QDMA_DEV}" q start idx "$QUEUE_H2C" dir h2c

echo "[run] adding queue $QUEUE_C2H (C2H, MM mode)"
sudo dma-ctl "${QDMA_DEV}" q add idx "$QUEUE_C2H" mode mm dir c2h
echo "[run] starting queue $QUEUE_C2H"
sudo dma-ctl "${QDMA_DEV}" q start idx "$QUEUE_C2H" dir c2h

# ── 5. Cleanup trap ──────────────────────────────────────────────────────────
cleanup() {
  echo "[run] cleaning up queues..."
  sudo dma-ctl "${QDMA_DEV}" q stop idx "$QUEUE_H2C" dir h2c 2>/dev/null || true
  sudo dma-ctl "${QDMA_DEV}" q del idx "$QUEUE_H2C" dir h2c 2>/dev/null || true
  sudo dma-ctl "${QDMA_DEV}" q stop idx "$QUEUE_C2H" dir c2h 2>/dev/null || true
  sudo dma-ctl "${QDMA_DEV}" q del idx "$QUEUE_C2H" dir c2h 2>/dev/null || true
}
trap cleanup EXIT

# ── 6. Fix permissions & run test ─────────────────────────────────────────────
H2C_DEV="/dev/${QDMA_DEV}-MM-${QUEUE_H2C}"
C2H_DEV="/dev/${QDMA_DEV}-MM-${QUEUE_C2H}"

for dev in "$H2C_DEV" "$C2H_DEV"; do
  if [[ ! -e "$dev" ]]; then
    echo "[run] ERROR: device not found: $dev"
    echo "[run] hint: check dma-ctl ${QDMA_DEV} q list"
    exit 1
  fi
done

sudo chmod a+rw "$H2C_DEV" "$C2H_DEV"
echo "[run] devices ready: $H2C_DEV / $C2H_DEV"

DMA_SIZE="${DMA_SIZE:-4096}"
DMA_OFFSET="${DMA_OFFSET:-0x0}"

echo "[run] running H2C/C2H DMA test (size=$DMA_SIZE, offset=$DMA_OFFSET)..."
python3 "${SCRIPT_DIR}/test_h2c.py" \
  --h2c "$H2C_DEV" --c2h "$C2H_DEV" \
  --offset "$DMA_OFFSET" --size "$DMA_SIZE"

echo "[run] PASS"
