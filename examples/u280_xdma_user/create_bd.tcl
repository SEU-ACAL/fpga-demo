# XDMA User BAR (AXI-Lite) Block Design — minimal test.
# XDMA M_AXI_LITE (32b) → AXI BRAM Controller → BRAM.
# Host accesses via /dev/xdma0_user (MMIO read/write, no DMA engine).
if {![info exists proj_dir]} {
  error "proj_dir must be set before sourcing create_bd.tcl"
}

set bd_name xdma_user_bd
create_bd_design $bd_name

# ── XDMA IP ──────────────────────────────────────────────────────────────────
create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.1 xdma_0
set_property -dict [list \
  CONFIG.PCIE_BOARD_INTERFACE        {pci_express_x16} \
  CONFIG.SYS_RST_N_BOARD_INTERFACE   {pcie_perstn} \
  CONFIG.axilite_master_en           {true} \
  CONFIG.axilite_master_size         {32} \
  CONFIG.pf0_msix_cap_pba_bir        {BAR_1} \
  CONFIG.pf0_msix_cap_table_bir      {BAR_1} \
  CONFIG.xdma_axi_intf_mm            {AXI_Memory_Mapped} \
  CONFIG.xdma_rnum_chnl              {1} \
  CONFIG.xdma_wnum_chnl              {1} \
] [get_bd_cells xdma_0]

# ── AXI BRAM Controller (32-bit AXI-Lite slave) ─────────────────────────────
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram
set_property -dict [list \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.SINGLE_PORT_BRAM {1} \
  CONFIG.PROTOCOL {AXI4LITE} \
] [get_bd_cells axi_bram]

# ── BRAM ─────────────────────────────────────────────────────────────────────
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 bram_0
set_property -dict [list \
  CONFIG.Memory_Type {Single_Port_RAM} \
  CONFIG.Write_Width_A {32} \
  CONFIG.Read_Width_A {32} \
  CONFIG.Write_Depth_A {1024} \
] [get_bd_cells bram_0]

# ── External ports ───────────────────────────────────────────────────────────
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x16
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk
set_property -dict [list CONFIG.FREQ_HZ {100000000}] [get_bd_intf_ports pcie_refclk]
create_bd_port -dir I -type rst pcie_perstn
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports pcie_perstn]

# ── PCIe refclk buffer ───────────────────────────────────────────────────────
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0
set_property -dict [list \
  CONFIG.C_BUF_TYPE {IBUFDSGTE} \
  CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} \
  CONFIG.USE_BOARD_FLOW {true} \
] [get_bd_cells util_ds_buf_0]

# ── Clock/reset wiring ──────────────────────────────────────────────────────
connect_bd_intf_net [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_DS_ODIV2] [get_bd_pins xdma_0/sys_clk]
connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT]      [get_bd_pins xdma_0/sys_clk_gt]
connect_bd_net [get_bd_ports pcie_perstn] [get_bd_pins xdma_0/sys_rst_n]
connect_bd_intf_net [get_bd_intf_ports pci_express_x16] [get_bd_intf_pins xdma_0/pcie_mgt]

connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins axi_bram/s_axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins axi_bram/s_axi_aresetn]

# ── Data path: XDMA M_AXI_LITE → axi_bram_ctrl → BRAM ──────────────────────
connect_bd_intf_net [get_bd_intf_pins xdma_0/M_AXI_LITE] [get_bd_intf_pins axi_bram/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_bram/BRAM_PORTA] [get_bd_intf_pins bram_0/BRAM_PORTA]

# ── Address mapping: BRAM at 0x0, 4 KiB ─────────────────────────────────────
assign_bd_address \
  -offset 0x00000000 \
  -range 0x00001000 \
  -target_address_space [get_bd_addr_spaces xdma_0/M_AXI_LITE] \
  [get_bd_addr_segs axi_bram/S_AXI/Mem0] \
  -force

# ── IRQ tie-off ──────────────────────────────────────────────────────────────
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 irq_const
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {0}] [get_bd_cells irq_const]
connect_bd_net [get_bd_pins irq_const/dout] [get_bd_pins xdma_0/usr_irq_req]

validate_bd_design
save_bd_design

set bd_file [get_files "${proj_dir}/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd"]
set_property synth_checkpoint_mode None $bd_file
generate_target all $bd_file
export_ip_user_files -of_objects $bd_file -no_script -sync -force -quiet
make_wrapper -files $bd_file -top -import
