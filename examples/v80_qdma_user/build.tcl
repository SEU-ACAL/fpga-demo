if { $argc < 2 } {
  puts "Usage: build.tcl <output_dir> <part>"
  exit 1
}

set output_dir [lindex $argv 0]
set part_name  [lindex $argv 1]
file mkdir $output_dir
set proj_dir [file normalize "$output_dir/project"]
set proj_name qdma_user_build

create_project $proj_name $proj_dir -part $part_name -force
set_property board_part xilinx.com:au280:part0:1.1 [current_project]
set_property target_language Verilog [current_project]
set_param general.maxThreads 32

set script_dir [file normalize [file dirname [info script]]]
source "${script_dir}/create_bd.tcl"

puts "INFO: QDMA user example is host-side focused."
puts "INFO: For V80/AU280 QDMA data plane, start from AVED base design."
puts "INFO: This script creates a placeholder project and exits intentionally."
