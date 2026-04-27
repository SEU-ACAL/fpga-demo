#!/bin/bash
sleep 30
c=0
f=$1
j="TEST FINISHED"
while [ "$c" -eq 0 ]; do
  if [ -s "$f" ]; then
    echo "[INFO] $(date) @ Scanning file $f for keywords $j"
    c=$(grep -c "$j" "$f")
    sleep 5
  else
    echo "[INFO] $(date) @ Not found file $f"
    break
  fi
done
echo "[INFO] $(date) @ Found in file $f with keywords $j"
