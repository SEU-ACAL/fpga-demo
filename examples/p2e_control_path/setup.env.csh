#!/bin/csh -f
unsetenv P2E_V2_TEST 
unsetenv VCOM_TEST_DIP
#unsetenv FARM_CMD


setenv CASE_HOME `pwd`

setenv TBSERVER_ETC $CASE_HOME/vvacDir/runtimeDir/
#setenv XPSKIP_VRM_CTL 1

setenv VVAC_GEN  $CASE_HOME/vvacDir/vvac_by_mod/
setenv top_module  xepic_vvac_top
setenv VVAC_WORK_DIR  $CASE_HOME/vvacDir/
#setenv VVAC_HOME /build/daily/centos-x86/vvac/xepic/24.01.00/latest/
unsetenv GALAXSIM_HOME
setenv NEWBACKDOOR 1
#setenv PATH /usr/bin:$PATH
#setenv VCS_CC /usr/bin/gcc
setenv CC /build/daily/centos-x86/hpe/xepic/26.06.00/latest/tools/gcc-8.3.0/gcc-8.3.0/bin/gcc
