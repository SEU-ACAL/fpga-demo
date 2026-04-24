#!/bin/csh -f
sleep 30
set c = 0
set f = $argv[1]
set j = "TEST FINISHED"
while $c == 0
  if (-s $f) then
    echo "[INFO] `date` @ Scanning file $f for keywords $j"
    set c = `grep -c "$j" $f`
    sleep 5
  else
    echo "[INFO] `date` @ Not found file $f"
    break
  endif
end
echo "[INFO] `date` @ Found in file $f with keywords $j"
