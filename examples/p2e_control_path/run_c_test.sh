#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/out}"

cd "$OUT_DIR/src/c_src/build"
./tester >& "$OUT_DIR/run.tester.log" &
echo $! > "$OUT_DIR/pid.tester"
cd "$OUT_DIR"
