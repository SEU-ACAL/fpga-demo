#!/bin/csh -f
source ./setup.env.csh
#source /build/daily/centos-x86/hpe/xepic/24.01.00/d114/tools/gcc-8.3.0/enable.csh
#PV8:
cd $CASE_HOME/src/c_src/build/
./tester >& $CASE_HOME/run.tester.log & echo $! >> $CASE_HOME/pid.tester &
cd $CASE_HOME/
#PV8:simple_check
sleep 6s
