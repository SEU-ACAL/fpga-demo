#!/bin/bash
#cd vcom_sim
#sed -i 's#+WAVE.*#+WAVE > ../vcom_sim.log \& echo $$! > ../pid.vcomsim#' ./Makefile
#make sim
#tmux send -t vcom_sim3 'C-C' Enter
#tmux send -t vcom_sim3 'exit' Enter
#tmux kill-session -t vcom_sim3

for i in $(seq 1 3); do
  for j in $(cat pid.*); do
    ps $j
    if [ $(ps $j | wc -l) -gt 1 ]; then
      kill  $j
      echo "Killing job $j"
    fi
  done
  echo "----- Trial no. $i done -----"
  sleep 1
done
