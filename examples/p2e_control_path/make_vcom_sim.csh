#!/bin/csh -f
source ./setup.env.csh
#source /build/daily/centos-x86/hpe/xepic/24.01.00/d114/tools/gcc-8.3.0/enable.csh
#PV6:
cd $CASE_HOME/vcom_sim/
make cmp
cd $CASE_HOME/
#PV6:find_string "simv up to date"
