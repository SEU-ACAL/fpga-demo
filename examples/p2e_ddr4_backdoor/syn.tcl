set RTL_PATH ../rtl
set TECHNOLOGY VIRTEX-ULTRASCALEPLUS-FPGAS
set PART XCVU19P
set PACKAGE FSVA3824
set GRADE -1-e
set TOP_NAME pcie3_ddr4
set INCLUDE_PATH ./

puts "##########################################"
puts " Rtl path is: $RTL_PATH"
puts " Fpga tech is: $TECHNOLOGY"
puts " Fpga part is: $PART"
puts " Fpga package is: $PACKAGE"
puts " Fpga grade is: $GRADE"
puts " Top name is: $TOP_NAME"
puts " Include path is: $INCLUDE_PATH"
puts "##########################################"

source synplify_run.tcl.src
add_file_lst ./flist.lst 1




set_option -technology $TECHNOLOGY
set_option -part $PART
set_option -package $PACKAGE
set_option -grade $GRADE
set_option -top_module $TOP_NAME
set_option -include_path $INCLUDE_PATH
set_option -write_verilog 1
set_option -use_vivado 1
set_option -multi_file_compilation_unit 1
set_option -auto_infer_blackbox  0
set_option -disable_io_insertion 1
set_option -looplimit 16000

project -result_file "$TOP_NAME.vm"
project -run
