# Control Path Example - Basic signal control and monitoring

set script_dir [file dirname [file normalize [info script]]]

design .
hw_server .
download

puts "========== Reset Control =========="
# Assert reset
force rstn 0
puts "Reset asserted: [get_value rstn]"

run 10rclk

# Deassert reset
force rstn 1
puts "Reset deasserted: [get_value rstn]"

run 100rclk

puts "========== Test Complete =========="

exit
