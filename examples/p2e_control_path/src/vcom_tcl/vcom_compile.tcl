set top_module $env(top_module)
design_read -netlist ./${top_module}.vm 
design_read -netlist $env(VSYN_HOME)/share/verilog/vtech_vivado_vcom.v
design_load -top ${top_module} 
registers_visibility -effort low

design_edit_option -add {host_channel hac}

#vvac_cfg_map -dir ../vsy./vvacDir/
vvac_cfg_map -dir ./vvacDir
emulator_spec -add {file   ./hw-config.hdf}  
create_clock -sigName ${top_module}.clk -frequency 100Mhz

#memory_options -add {force_refresh_area OFF}
#memory_access -add {dut_top.sp_ram.sp_array}

#write_net -add ${top_module}.clk
#write_net -add {rstn}

write_net  -add {dut_top.dut_done}
write_net  -add {dut_top.arstn}

read_net -add {dut_top.dut_rstn}
read_net -add {dut_top.cycle_cnt}
read_net -add {dut_top.dut_done}
read_net  -add {dut_top.u_dut.dut_done}
read_net  -add {dut_top.u_dut.dut_done_cnt}
read_net  -add {dut_top.u_dut.func1_toggle}
read_net  -add {dut_top.u_dut.func1_toggle_dly}
read_net  -add {dut_top.u_dut.q_out}
read_net  -add {dut_top.u_dut.s2h_out}
read_net  -add {dut_top.u_dut.s2h_data}

emulator_util -add {default 0}
emulator_util -add {0.A 50}
dump_clock_region_ports
set_dr_mode -add enable
design_edit
design_generation
