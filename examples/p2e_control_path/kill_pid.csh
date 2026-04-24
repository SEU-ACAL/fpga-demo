#!/bin/csh -f
#cd vcom_sim
#sed -i 's#+WAVE.*#+WAVE > ../vcom_sim.log \& echo $$! > ../pid.vcomsim#' ./Makefile
#make sim
#tmux send -t vcom_sim3 'C-C' Enter
#tmux send -t vcom_sim3 'exit' Enter
#tmux kill-session -t vcom_sim3

foreach i (`seq 1 3`)
  foreach j (`cat pid.*`)
    ps $j
    if (`ps $j | wc -l` > 1) then
      kill  $j
      echo "Killing job $j"
    endif
  end
  echo "----- Trial no. $i done -----"
  sleep 1
end
