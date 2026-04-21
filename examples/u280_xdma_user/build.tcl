if { $argc < 2 } {
  puts "Usage: build.tcl <output_dir> <part>"
  exit 1
}

set output_dir [lindex $argv 0]
set part_name  [lindex $argv 1]
file mkdir $output_dir
set proj_dir [file normalize "$output_dir/project"]
set proj_name xdma_user_build

create_project $proj_name $proj_dir -part $part_name -force
set_property board_part xilinx.com:au280:part0:1.1 [current_project]
set_property target_language Verilog [current_project]
set_param general.maxThreads 32

set script_dir [file normalize [file dirname [info script]]]
source "${script_dir}/create_bd.tcl"

update_compile_order -fileset sources_1

set top_name xdma_user_bd_wrapper
synth_design -top $top_name -part $part_name
opt_design
place_design
route_design

write_bitstream -force "$output_dir/${top_name}.bit"
puts "BITSTREAM_DONE $output_dir/${top_name}.bit"
