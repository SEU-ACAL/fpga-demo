# Control Path Example - Basic signal control and monitoring

set script_dir [file dirname [file normalize [info script]]]
set rst_sig "dut_top.arstn"

design .
hw_server .
download

puts "========== Starting C Tester =========="
# Start C tester in background
set pid_c [exec bash $script_dir/run_c_test.sh &]
puts "C tester PID: $pid_c"

puts "========== Reset Control =========="
# Assert reset
force $rst_sig 0
puts "Reset asserted: [get_value $rst_sig]"

run 10rclk

# Deassert reset
force $rst_sig 1
puts "Reset deasserted: [get_value $rst_sig]"

# Run longer to allow C program to complete
puts "========== Running Test =========="
run 20000rclk

puts "========== Test Complete =========="

exit
