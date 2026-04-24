vvac:
	rm -rf config_dir && cp -rf ./src/config_dir  ./
	vvac -bc  -f ./src/dut_rtl/dut_src/flist.lst     -top dut_top  | tee vvac.log
	#vgen2 -d ${CASE_HOME}/vvacDir/runtime.dbdir | tee vgen2.log

vsyn:
	vsyn -F ./vvacDir/vvac_by_mod/filelist -top xepic_vvac_top -o xepic_vvac_top.vm  | tee vsyn.log
vcom:
	vcom  ./src/vcom_tcl/vcom_compile.tcl 
	#dumpDB | tee dumpDB.log

clean:
	rm -rf *.db *.v *.txt   *.json   *.rpt   *.f  fpgaCompDir   *.dbg  vcomMemDir vvac_by_mod work_lib vcom_sim  
	rm -rf FUN_GROUP_MEM_INFO STA_Reports  vcom.*  vvac


####Below for PV flow ###
do_csh:
	rm -rf *.csh
	python3 /nfs/projects/pv/autoTest/crs/master/regressionsystem/lib/utils/hvg_scripts/others/checkist/main.py -p True -w ./

log_vvac:
	rm -rf ./case.result
	python3 /nfs/projects/pv/autoTest/crs/master/regressionsystem/lib/utils/hvg_scripts/others/checkist/generate_origin_run_log.py -m run

	
