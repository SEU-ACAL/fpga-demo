set cur_path [pwd]
puts "cur_path: ${cur_path}"
set project_dir "$::env(PROJECT_DIR)"
#set nnmf_path "/build/testcase_data/big_files_do_not_sumbit_to_git/NNMF_pcie3_ddr4_emode_pmode/netlist_macro_packages"
set nnmf_path "$::env(HPE_HOME)/netlist_macro_packages"
#set nnmf_path "/build/testcase_data/big_files_do_not_sumbit_to_git/NNMF/netlist_macro_packages_P2_emode_noOBUF_FixXDC/netlist_macro_packages"
design_read -netlist ./rev_1/pcie3_ddr4.vm
netlistmacro -instance pcie3_ddr4.chip0_wrapper -package ${nnmf_path}/xepic_ddr4_dc1 -location 0.A -channel 0

design_load -top pcie3_ddr4

emulator_spec -add "file ${project_dir}/hw-config.hdf"
emulator_util -add {default 70}



read_net -add {pcie3_ddr4.axi_user_ctrl_pbrs_inst.r_read_state}
read_net -add {pcie3_ddr4.axi_user_ctrl_pbrs_inst.r_write_state}
read_net -add {axi_user_ctrl_pbrs_inst.r_read_end}
read_net -add {axi_user_ctrl_pbrs_inst.top_sig}
read_net -add {check_err}
read_net -add {axi_user_ctrl_pbrs_inst.check_err}
read_net -add {pcie3_ddr4.c0_init_calib_complete}
read_net -add {top_sig}
read_net -add {w_check_cnt}
read_net -add {w_check_err_cnt}
read_net -add {axi_user_ctrl_pbrs_inst.r_write_cnt}
read_net -add {axi_user_ctrl_pbrs_inst.r_read_cnt}
read_net -add {axi_user_ctrl_pbrs_inst.r_m_axi_araddr_tmp}
read_net -add {axi_user_ctrl_pbrs_inst.r_m_axi_awaddr_tmp}
read_net -add {axi_user_ctrl_pbrs_inst.w_check_diff}

write_net -add {test_start}
write_net -add {user_rst}
write_net -add {user_write_addr}
write_net -add {user_burst_len}
write_net -add {user_burst_num}
write_net -add {user_wstrb}


trace_net -add {M_AXI_AWID   }
trace_net -add {M_AXI_AWADDR }
trace_net -add {M_AXI_AWLEN  }
trace_net -add {M_AXI_AWSIZE }
trace_net -add {M_AXI_AWBURST}
trace_net -add {M_AXI_AWLOCK }
trace_net -add {M_AXI_AWCACHE}
trace_net -add {M_AXI_AWPROT }
trace_net -add {M_AXI_AWQOS  }
trace_net -add {M_AXI_AWVALID}
trace_net -add {M_AXI_AWREADY}

trace_net -add {M_AXI_WDATA }
trace_net -add {M_AXI_WSTRB }
trace_net -add {M_AXI_WLAST }
trace_net -add {M_AXI_WVALID}
trace_net -add {M_AXI_WREADY}

trace_net -add {M_AXI_BID   }
trace_net -add {M_AXI_BRESP }
trace_net -add {M_AXI_BVALID}
trace_net -add {M_AXI_BREADY}
trace_net -add {M_AXI_BUSER }

trace_net -add {M_AXI_ARID   }
trace_net -add {M_AXI_ARADDR }
trace_net -add {M_AXI_ARLEN  }
trace_net -add {M_AXI_ARSIZE }
trace_net -add {M_AXI_ARBURST}
trace_net -add {M_AXI_ARLOCK }
trace_net -add {M_AXI_ARCACHE}
trace_net -add {M_AXI_ARPROT }
trace_net -add {M_AXI_ARQOS  }
trace_net -add {M_AXI_ARVALID}
trace_net -add {M_AXI_ARREADY}

trace_net -add {M_AXI_RREADY}
trace_net -add {M_AXI_RID   }
trace_net -add {M_AXI_RDATA }
trace_net -add {M_AXI_RRESP }
trace_net -add {M_AXI_RLAST }
trace_net -add {M_AXI_RVALID}

create_clock -sig_name  pcie3_ddr4.user_clk -frequency 10Mhz


design_edit

design_generation

