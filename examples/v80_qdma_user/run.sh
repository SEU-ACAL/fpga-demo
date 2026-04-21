#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -z "${QDMA_USER_DEV:-}" ]]; then
  QDMA_USER_DEV="$(ls /dev/qdma*-user 2>/dev/null | head -1 || true)"
fi

if [[ -z "${QDMA_USER_DEV:-}" ]]; then
  echo "[run] ERROR: no qdma user device found"
  echo "[run] hint: set QDMA_USER_DEV=/dev/qdma00000-user"
  exit 1
fi

if [[ ! -e "$QDMA_USER_DEV" ]]; then
  echo "[run] ERROR: device node does not exist: $QDMA_USER_DEV"
  exit 1
fi

echo "[run] using device: $QDMA_USER_DEV"
if [[ ! -r "$QDMA_USER_DEV" || ! -w "$QDMA_USER_DEV" ]]; then
  echo "[run] permissions missing, trying sudo chmod..."
  sudo chmod a+rw "$QDMA_USER_DEV"
fi

if [[ ! -r "$QDMA_USER_DEV" || ! -w "$QDMA_USER_DEV" ]]; then
  echo "[run] ERROR: still no read/write permission: $QDMA_USER_DEV"
  exit 1
fi

python3 "${SCRIPT_DIR}/test_user.py" \
  --dev "$QDMA_USER_DEV" \
  --offset 0x0 \
  --count 64

echo "[run] PASS"
