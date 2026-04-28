# DDR4 Front-door and Back-door Access Example

set script_dir [file dirname [file normalize [info script]]]

design .
hw_server .
set_phc_vol -id 0.0 -bank 3,4,5 -voltage 1.2
download

# Initialize
force user_rst 1
force test_start 0
force test_start_read 0
force user_write_addr 'd0
force user_burst_len 'd64
force user_burst_num 'd100
force user_wstrb 'hffffffff
run 100rclk
force user_rst 0

set addr_begin 0
set addr_end [expr 64 * 32 * 100 - 1]

run -nowait
after 2000
stop

puts "DDR init: [get_value c0_init_calib_complete]"

# Front-door write
puts "========== Front-door Write =========="
force test_start 1
run -nowait
after 5000
stop
puts "Write error: [get_value axi_user_ctrl_pbrs_inst.check_err]"

# Front-door read
puts "========== Front-door Read =========="
force test_start_read 1
run -nowait
after 5000
stop
puts "Read error: [get_value axi_user_ctrl_pbrs_inst.check_err]"

# Back-door write
puts "========== Back-door Write =========="
memory -write -fpga 0.A -channel 0 -file [file join $script_dir backdoor_write.ref]

# Back-door read
puts "========== Back-door Read =========="
memory -read -fpga 0.A -channel 0 -file [file join $script_dir backdoor_read.result] -start 0 -end 9999

exit
