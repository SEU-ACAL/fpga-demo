#export VCS_HOME = /nfs/tools/softwares/synopsys/installed_new/vcs-mx/R-2020.12-SP1/
export VVAC_DEBUG_NETLIST = vvac_top.mid.sv
export XEPIC_FNL_USE_PORT_NAME = 1

all_vcs:dir so_vcs comp_vcs run_vcs

dir:
	ln -rsf ../dut_rtl/dut_src  ./
	ln -rsf ../c_src        ./
	rm -rf tmpdir 
	mkdir tmpdir 
	ln -rsf Makefile  ./tmpdir 
	ln -rsf ./dut_src ./tmpdir
	ln -rsf ./c_src   ./tmpdir
	ln -rsf ./vcs_tb.sv  ./tmpdir
	ln -rsf ./ucli_dumpwave  ./tmpdir
	

clean:
	rm -rf tmpdir

so_vcs:
	cd tmpdir && rm -rf lib*.so; gcc -fPIC -lstdc++ -g -m64 -shared -DCLI  -I${VCS_HOME}/include ./c_src/vcs_main.cc -o libdpic_vcs.so
	
comp_vcs:
	cd tmpdir && vcs -lca  -top vcs_tb -full64 -sverilog -debug_access+rwc +vcs+initreg+random  -kdb \
	+incdir+./dut_src \
	+define+RTL_SIM   \
	-F ./dut_src/flist.lst   ./vcs_tb.sv \
	-l elaborate.vcs.log  -timescale=1ns/1ps 

run_vcs:
	cd tmpdir && ./simv +vcs+initreg+0  -ucli  -do ../run.do -sv_lib libdpic_vcs  | tee run.vcs.log

wave:
	#verdi -simBin ./simv  -ssf board.fsdb &
	cd tmpdir && verdi -simBin ./simv  -ssf board.fsdb &


