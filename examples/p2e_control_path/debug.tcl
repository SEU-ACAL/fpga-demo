# Control Path Example - Basic signal control and monitoring

set script_dir [file dirname [file normalize [info script]]]
set rst_sig "dut_top.arstn"

design .
hw_server .
download

puts "========== Reset Control =========="
# Assert reset
force $rst_sig 0
puts "Reset asserted: [get_value $rst_sig]"

run 10rclk

# Deassert reset
force $rst_sig 1
puts "Reset deasserted: [get_value $rst_sig]"

run 100rclk

puts "========== Test Complete =========="

exit
