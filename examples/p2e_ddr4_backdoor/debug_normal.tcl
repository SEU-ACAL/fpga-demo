design .
hw_server .
set_phc_vol -id 0.0 -bank 3,4,5 -voltage 1.2
download
puts "rst rtl"
force user_rst 1
force test_start 0
force test_start_read 0
force user_write_addr 'd0
force user_burst_len 'd64
force user_burst_num 'd2
force user_wstrb 'hffffffff
run 100rclk
force user_rst 0
set user_write_addr_t 0
set user_burst_len_t 64
set user_burst_num_t 2
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

force test_start 1

set clk_loop 3000
set clk_loop_rclk [expr $clk_loop * 2]
set_trace_size  $clk_loop_rclk rclk

tracedb -enable
tracedb -open result -xedb -overwrite
#trace_signals -add M_AXI_AWADDR M_AXI_AWVALID M_AXI_AWREADY M_AXI_WDATA  M_AXI_WLAST M_AXI_WVALID M_AXI_WREADY  M_AXI_BID M_AXI_BRESP M_AXI_BVALID   M_AXI_ARADDR M_AXI_ARVALID M_AXI_ARREADY M_AXI_ARLEN   M_AXI_RREADY M_AXI_RDATA M_AXI_RLAST M_AXI_RVALID 
trace_signals -add *
run 6000 rclk
tracedb -upload
tracedb -disable
tracedb -close

force test_start_read 1
run -nowait
after 2000
stop


get_register 0 0 0x480
puts "after 2s"
set tmp_init_complete [get_value c0_init_calib_complete]
puts "c0_init_calib_complete:$tmp_init_complete"
set tmp [get_value axi_user_ctrl_pbrs_inst.r_read_state]
puts "r_read_state:$tmp"
set tmp [get_value axi_user_ctrl_pbrs_inst.r_write_state]
puts "r_write_state:$tmp"
set tmp [get_value axi_user_ctrl_pbrs_inst.r_read_end]
puts "r_read_end:$tmp"
set tmp_check_err [get_value axi_user_ctrl_pbrs_inst.check_err]
puts "check_err:$tmp_check_err"
set tmp [get_value %d w_check_cnt]
puts "w_check_cnt:$tmp  goleden:$read_clk_num"
set tmp [get_value %d w_check_err_cnt]
puts "w_check_err_cnt:$tmp"
set tmp [get_value %d axi_user_ctrl_pbrs_inst.r_m_axi_araddr_tmp]
puts "r_m_axi_araddr_tmp:$tmp addr_end: $addr_end"
set tmp [get_value %d axi_user_ctrl_pbrs_inst.r_m_axi_awaddr_tmp]
puts "r_m_axi_awaddr_tmp:$tmp addr_end: $addr_end"
set tmp_init_complete_golden 'b1
set tmp_check_err_golden 'b0
set fi [open axi_wr.result w+]
if {$tmp_init_complete == $tmp_init_complete_golden && $tmp_check_err == $tmp_check_err_golden} {
  puts "AXI WR TEST 1 SUCCESS! ADDR:$user_write_addr_t  LEN_BYTE:$len_byte"
  puts $fi "AXI WR TEST 1 SUCCESS! ADDR:$user_write_addr_t  LEN_BYTE:$len_byte"
} else {
  puts "AXI WR TEST 2 FAIL! ADDR:$user_write_addr_t  LEN_BYTE:$len_byte"  
  puts $fi "AXI WR TEST 2 FAIL! ADDR:$user_write_addr_t  LEN_BYTE:$len_byte"
}
puts "memory backdoor: 1"
memory -read  -fpga 0.A -channel 0 -file check_point1.result -start $addr_begin -end $addr_end


puts "rst rtl"
force user_rst 1
force test_start 0
force test_start_read 0
force user_write_addr 'd409600
force user_burst_len 'd64
force user_burst_num 'd20000
force user_wstrb 'hffffffff
run 100rclk
force user_rst 0
set user_write_addr_t 409600
set user_burst_len_t 64
set user_burst_num_t 20000
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

force test_start 1
run -nowait
after 2000
stop

force test_start_read 1
run -nowait
after 2000
stop

get_register 0 0 0x480
puts "after 2s"
set tmp_init_complete [get_value c0_init_calib_complete]
puts "c0_init_calib_complete:$tmp_init_complete"
set tmp [get_value axi_user_ctrl_pbrs_inst.r_read_state]
puts "r_read_state:$tmp"
set tmp [get_value axi_user_ctrl_pbrs_inst.r_write_state]
puts "r_write_state:$tmp"
set tmp [get_value axi_user_ctrl_pbrs_inst.r_read_end]
puts "r_read_end:$tmp"
set tmp_check_err [get_value axi_user_ctrl_pbrs_inst.check_err]
puts "check_err:$tmp_check_err"
set tmp [get_value %d w_check_cnt]
puts "w_check_cnt:$tmp  goleden:$read_clk_num"
set tmp [get_value %d w_check_err_cnt]
puts "w_check_err_cnt:$tmp"
set tmp [get_value %d axi_user_ctrl_pbrs_inst.r_m_axi_araddr_tmp]
puts "r_m_axi_araddr_tmp:$tmp addr_end: $addr_end"
set tmp [get_value %d axi_user_ctrl_pbrs_inst.r_m_axi_awaddr_tmp]
puts "r_m_axi_awaddr_tmp:$tmp addr_end: $addr_end"
set tmp_init_complete_golden 'b1
set tmp_check_err_golden 'b0
if {$tmp_init_complete == $tmp_init_complete_golden && $tmp_check_err == $tmp_check_err_golden} {
  puts "AXI WR TEST 2 SUCCESS! ADDR:$user_write_addr_t  LEN_BYTE:$len_byte"
  puts $fi "AXI WR TEST 2 SUCCESS! ADDR:$user_write_addr_t  LEN_BYTE:$len_byte"
} else {
  puts "AXI WR TEST 2 FAIL! ADDR:$user_write_addr_t  LEN_BYTE:$len_byte"  
  puts $fi "AXI WR TEST 2 FAIL! ADDR:$user_write_addr_t  LEN_BYTE:$len_byte" 
}
close $fi
puts "memory backdoor: read 2"
memory -read  -fpga 0.A -channel 0 -file check_point4.result -start $addr_begin -end $addr_end
#memory -read  -fpga 0.A -channel 0 -file check_point4.result -start 0 -end 40959999


memory -write -fpga 0.A -channel 0 -file check_point2.ref
memory -read  -fpga 0.A -channel 0 -file check_point2.result -start 0 -end 9999998
memory -write -fpga 0.A -channel 0 -file check_point3.ref
memory -read  -fpga 0.A -channel 0 -file check_point3.result -start 0 -end 599999998


puts "test finish"
after 1000
#exit
