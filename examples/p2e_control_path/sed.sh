#!/usr/bin/env bash

#if [[ $# -lt 1 ]]; then
#    echo "usuage:"
#    echo "        setup.sh <absolute path_to_case>"
#    exit -1
#fi

PWD=`pwd`
PWD_PATH=${PWD//\//\\\/}
#Step1  C_SRC 
cp $CASE_HOME/src/c_src/template.vvac_main.cc   $CASE_HOME/src/c_src/vvac_main.cc
cp $CASE_HOME/src/c_src/template.CMakeLists.txt $CASE_HOME/src/c_src/CMakeLists.txt 
cp $CASE_HOME/src/c_src/template.vmri.json      $CASE_HOME/src/c_src/vmri.json
cp $CASE_HOME/src/c_src/template.tbserver.toml  $CASE_HOME/vvacDir/tbserver.toml

sed -i "s#YOUR_CASE_HOME#$CASE_HOME/#g"              $CASE_HOME/src/c_src/vvac_main.cc
sed -i "s#YOUR_CASE_HOME#$CASE_HOME/#g"              $CASE_HOME/src/c_src/CMakeLists.txt 
sed -i "s#YOUR_CASE_HOME.vcom_sim#$CASE_HOME/#g"     $CASE_HOME/src/c_src/vmri.json      
sed -i "s#YOUR_CASE_HOME#$CASE_HOME/#g"              $CASE_HOME/vvacDir/tbserver.toml

sed -i "s#YOUR_FPGA_ID#0#g"                          $CASE_HOME/src/c_src/vvac_main.cc

rm -rf   $CASE_HOME/src/c_src/build
mkdir -p $CASE_HOME/src/c_src/build
cp $CASE_HOME/src/c_src/vmri.json $CASE_HOME/src/c_src/build


#Step2  vcom_sim 
if test -e $CASE_HOME/vcom_sim/Makefile.default ; then
    echo "ABC 0"
    cp $CASE_HOME/vcom_sim/Makefile.default     $CASE_HOME/vcom_sim/Makefile
fi


if [ -e $CASE_HOME/vcom_sim/Makefile ] ; then 
    cp $CASE_HOME/vcom_sim/Makefile                 $CASE_HOME/vcom_sim/Makefile.default
    sed -i "s#vcs.cmp_part.log#vcs.cmp_part.log /home/pingh/dbg_ip_top.sv#g" $CASE_HOME/vcom_sim/Makefile
    sed -i "s#vcs.elab.log#vcs.elab.log  -debug_region+cell#g" $CASE_HOME/vcom_sim/Makefile
    sed -i "s#libhw -ucli.*#libhw -ucli -do ../ucli_dumpwave  +DONE_FILE=\$\(CASE_HOME\)/vcom_sim/c_code_done.txt  +warn=noSTASKW_CO  | tee run.vcs.log#g" $CASE_HOME/vcom_sim/Makefile
    sed -i "s#-ssf .*#-ssf board.fsdb#g" $CASE_HOME/vcom_sim/Makefile
    sed -i "s#\.\/simv .vcs#rm -rf run.vcs.log c_code_done.txt \&\& ./simv +vcs#g" $CASE_HOME/vcom_sim/Makefile
    #sed -i "s#kdb#kdb -lca -simprofile #g" $CASE_HOME/vcom_sim/Makefile
    #sed -i "s#noSTASKW_CO #noSTASKW_CO -simprofile time #g" $CASE_HOME/vcom_sim/Makefile
fi

