set_false_path -from [get_clocks -of_objects [get_pins u_sys_ctrl_top/u_normal_probe_top/ddr4_chip0/mic_ddr/ddr4_0_i/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0]] -to [get_clocks -of_objects [get_pins u_sys_ctrl_top/pcie_top_i/pcie3_ep/pcie3_ultrascale_ep_inst/inst/pcie4c_uscale_plus_ep_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O]]


set_false_path -from [get_clocks -of_objects [get_pins u_sys_ctrl_top/pcie_top_i/pcie3_ep/pcie3_ultrascale_ep_inst/inst/pcie4c_uscale_plus_ep_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_coreclk/O]] -to [get_clocks -of_objects [get_pins u_sys_ctrl_top/pcie_top_i/pcie3_ep/pcie3_ultrascale_ep_inst/inst/pcie4c_uscale_plus_ep_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O]]

set_false_path -from [get_clocks root_clock_free] -to [get_clocks -of_objects [get_pins u_sys_ctrl_top/u_normal_probe_top/ddr4_chip0/mic_ddr/ddr4_0_i/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0]]

set_false_path -from [get_clocks -of_objects [get_pins u_sys_ctrl_top/pcie_top_i/pcie3_ep/pcie3_ultrascale_ep_inst/inst/pcie4c_uscale_plus_ep_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O]] -to [get_clocks -of_objects [get_pins u_sys_ctrl_top/u_normal_probe_top/ddr4_chip0/mic_ddr/ddr4_0_i/inst/u_ddr4_infrastructure/gen_mmcme4.u_mmcme_adv_inst/CLKOUT0]]

set_false_path -from [get_clocks -of_objects [get_pins u_sys_ctrl_top/pcie_top_i/pcie3_ep/pcie3_ultrascale_ep_inst/inst/pcie4c_uscale_plus_ep_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_userclk/O]] -to [get_clocks -of_objects [get_pins u_sys_ctrl_top/pcie_top_i/pcie3_ep/pcie3_ultrascale_ep_inst/inst/pcie4c_uscale_plus_ep_gt_top_i/diablo_gt.diablo_gt_phy_wrapper/phy_clk_i/bufg_gt_coreclk/O]]
