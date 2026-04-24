design .
hw_server .
set_phc_vol -id 0.0 -bank 3,4,5 -voltage 1.2
download
set channel 0
set fi [open front_door_16G_test.result w+]

puts "rst rtl"
force user_rst 1
force test_start 0
force test_start_read 0
force user_write_addr 'd0
force user_burst_len 'd128
force user_burst_num 'd4194304
force user_wstrb 'hffffffff
run 100rclk
force user_rst 0
set user_write_addr_t 0
set user_burst_len_t 128
set user_burst_num_t 4194304
set addr_begin $user_write_addr_t
set addr_end [expr $user_write_addr_t + $user_burst_len_t * 32 * $user_burst_num_t - 1]
set read_clk_num [expr $user_burst_len_t * $user_burst_num_t]
set len_byte [expr $read_clk_num * 32]
run -nowait
puts "run nowait"
after 2000
stop
set tmp [get_value c0_init_calib_complete]
puts "c0_init_calib_complete:$tmp"

puts "===== front door write 16G ====="
puts $fi "===== front door write 16G ====="
force test_start 1
run -nowait
after 60000
stop

set tmp [get_value write_axi_clk_cnt]
puts "write_axi_clk_cnt: $tmp"
puts $fi "write_axi_clk_cnt: $tmp"

set tmp [get_value read_axi_clk_cnt]
puts "read_axi_clk_cnt: $tmp"
puts $fi "read_axi_clk_cnt: $tmp"

set tmp [get_value write_time_clk_cnt]
puts "write_time_clk_cnt: $tmp"

set tmp [get_value read_time_clk_cnt]
puts "read_time_clk_cnt: $tmp"

set tmp [get_value axi_user_ctrl_pbrs_inst.r_read_state]
puts "axi_user_ctrl_pbrs_inst.r_read_state: $tmp"

set tmp [get_value axi_user_ctrl_pbrs_inst.r_write_state]
puts "axi_user_ctrl_pbrs_inst.r_write_state: $tmp"

set tmp [get_value axi_user_ctrl_pbrs_inst.check_err]
puts "axi_user_ctrl_pbrs_inst.check_err: $tmp"
puts $fi "axi_user_ctrl_pbrs_inst.check_err: $tmp"

set tmp [get_value w_check_err_cnt]
puts "w_check_err_cnt: $tmp"
puts $fi "w_check_err_cnt: $tmp"

set tmp [get_value w_check_cnt]
puts "w_check_cnt: $tmp"
puts $fi "w_check_cnt: $tmp"

set tmp [get_value w_check_cnt]
puts "w_check_cnt: $tmp"
puts $fi "w_check_cnt: $tmp"

set tmp [get_value %d axi_user_ctrl_pbrs_inst.r_m_axi_araddr_tmp]
puts "r_m_axi_araddr_tmp:$tmp addr_end: $addr_end"
puts $fi "r_m_axi_araddr_tmp:$tmp addr_end: $addr_end"

set tmp [get_value %d axi_user_ctrl_pbrs_inst.r_m_axi_awaddr_tmp]
puts "r_m_axi_awaddr_tmp:$tmp addr_end: $addr_end"
puts $fi "r_m_axi_awaddr_tmp:$tmp addr_end: $addr_end"

puts "===== front door read ====="
puts $fi "===== front door read ====="

force test_start_read 1
run -nowait
after 60000
stop

set tmp [get_value write_axi_clk_cnt]
puts "write_axi_clk_cnt: $tmp"
puts $fi "write_axi_clk_cnt: $tmp"

set tmp [get_value read_axi_clk_cnt]
puts "read_axi_clk_cnt: $tmp"
puts $fi "read_axi_clk_cnt: $tmp"

set tmp [get_value write_time_clk_cnt]
puts "write_time_clk_cnt: $tmp"

set tmp [get_value read_time_clk_cnt]
puts "read_time_clk_cnt: $tmp"

set tmp [get_value axi_user_ctrl_pbrs_inst.r_read_state]
puts "axi_user_ctrl_pbrs_inst.r_read_state: $tmp"

set tmp [get_value axi_user_ctrl_pbrs_inst.r_write_state]
puts "axi_user_ctrl_pbrs_inst.r_write_state: $tmp"

set tmp [get_value axi_user_ctrl_pbrs_inst.check_err]
puts "axi_user_ctrl_pbrs_inst.check_err: $tmp"
puts $fi "axi_user_ctrl_pbrs_inst.check_err: $tmp"

set tmp [get_value w_check_err_cnt]
puts "w_check_err_cnt: $tmp"
puts $fi "w_check_err_cnt: $tmp"

set tmp [get_value w_check_cnt]
puts "w_check_cnt: $tmp"
puts $fi "w_check_cnt: $tmp"

set tmp [get_value w_check_cnt]
puts "w_check_cnt: $tmp"
puts $fi "w_check_cnt: $tmp"

set tmp [get_value %d axi_user_ctrl_pbrs_inst.r_m_axi_araddr_tmp]
puts "r_m_axi_araddr_tmp:$tmp addr_end: $addr_end"
puts $fi "r_m_axi_araddr_tmp:$tmp addr_end: $addr_end"

set tmp [get_value %d axi_user_ctrl_pbrs_inst.r_m_axi_awaddr_tmp]
puts "r_m_axi_awaddr_tmp:$tmp addr_end: $addr_end"
puts $fi "r_m_axi_awaddr_tmp:$tmp addr_end: $addr_end"

close $fi

puts "===== back door read ====="
set addr_begin 0
set addr_end 0
set len 10000
set addr_incr 2147483648
for {set a 0} {$a<8} {incr a} {
    set addr_begin [expr $a * $addr_incr]
    set addr_end  [expr $addr_begin + $len]
    puts "read all_0 data idx:$a  addr_begin:$addr_begin  addr_end:$addr_end  len:$len"
    memory -read  -fpga 0.A -channel $channel -file back_door_read_$a.result -start $addr_begin -end $addr_end
}
set addr_end 17179869183
set addr_begin [expr $addr_end - 10000]
set len 10000
puts "read all_0 data idx:last  addr_begin:$addr_begin  addr_end:$addr_end  len:$len"
memory -read  -fpga 0.A -channel $channel -file back_door_read_8.result -start $addr_begin -end $addr_end

puts "test finish"
after 1000
#exit
