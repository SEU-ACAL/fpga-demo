#!/usr/bin/env tclsh

design .
hw_server .
download
#set_vrm -on -relocation
#source /build/testcase_data/vdbg/mfb/relocationdownload.tcl

puts "run tester"
set pid_c [exec csh ./run_c_test.csh &]
puts "C id: $pid_c"
set fi [open pid.vvac w+]
puts $fi $pid_c
close $fi

puts "run 20000 rclk"
run 20000rclk
puts "test finish"
#exit
