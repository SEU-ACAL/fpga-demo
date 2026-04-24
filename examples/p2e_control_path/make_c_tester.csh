#!/bin/csh -f
source ./setup.env.csh
#source /build/daily/centos-x86/hpe/xepic/24.01.00/d114/tools/gcc-8.3.0/enable.csh
cd $CASE_HOME/src/c_src/build
cmake ..
make
cd $CASE_HOME/
