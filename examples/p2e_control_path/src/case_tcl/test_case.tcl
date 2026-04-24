design ../../vcom
puts "open design!" 
hw_server . 
puts "hw_server .!"

download
puts [clock format [clock seconds] -format {%b. %d, %Y %I:%M:%S %p}]
puts "get_time [get_time]"
puts "get_value rstn [get_value rstn]"
force rstn 0
puts "get_value rstn [get_value rstn]"
run 10rclk
puts "run 10rclk"
puts "get_time [get_time]"
force rstn 1
puts "get_value rstn [get_value rstn]"

