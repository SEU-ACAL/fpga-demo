# QDMA user BAR block design placeholder.
# Why placeholder:
# 1) QDMA integration is platform-dependent.
# 2) V80 flow should start from AVED base design.
# 3) This example focuses on host-side /dev/qdma*-user usage.

if {![info exists proj_dir]} {
  error "proj_dir must be set before sourcing create_bd.tcl"
}

set bd_name qdma_user_bd
create_bd_design $bd_name

set qdma_ip_defs [get_ipdefs -all xilinx.com:ip:qdma:*]
if {[llength $qdma_ip_defs] == 0} {
  error "QDMA IP not found in current Vivado catalog. Install matching platform/IP first."
}

puts "INFO: Found QDMA IP defs: $qdma_ip_defs"
puts "INFO: This repository example does not generate a standalone QDMA BD."
puts "INFO: Use AVED project as baseline and integrate your user BAR map there."
puts "INFO: Host usage is implemented in test_user.py and run.sh."
