set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir debug_normal.tcl]

#hw_server -release;design -close

#source [file join $script_dir debug_normal_16G.tcl]

#hw_server -release;design -close

#source [file join $script_dir debug_backdoor_0p5G.tcl]

exit 

