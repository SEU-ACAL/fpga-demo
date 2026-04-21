#!/usr/bin/env bash
# clone_aved.sh — Clone Xilinx/AVED at the V80 24.1 release tag.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
AVED_DIR="${AVED_DIR:-$ROOT_DIR/AVED}"
AVED_REPO="${AVED_REPO:-https://github.com/Xilinx/AVED.git}"
AVED_TAG="${AVED_TAG:-amd_v80_gen5x8_25.1_xbtest_20251113}"

if [[ -d "$AVED_DIR/.git" ]]; then
  echo "[clone] AVED already cloned at $AVED_DIR"
  echo "[clone] current tag/branch: $(git -C "$AVED_DIR" describe --tags --always 2>/dev/null || echo unknown)"
  exit 0
fi

echo "[clone] cloning $AVED_REPO @ $AVED_TAG → $AVED_DIR"
git clone --depth 1 -b "$AVED_TAG" "$AVED_REPO" "$AVED_DIR"

echo "[clone] done. tree:"
ls "$AVED_DIR"
