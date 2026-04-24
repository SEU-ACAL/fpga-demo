#!/bin/csh -f
source ./setup.env.csh
#source /build/daily/centos-x86/hpe/xepic/24.01.00/d114/tools/gcc-8.3.0/enable.csh
#PV7:
cd $CASE_HOME/vcom_sim
make run > $CASE_HOME/run.vcom_sim.log & echo $! > $CASE_HOME/pid.vcomsim  &
cd $CASE_HOME/
#PV7:simple_check
