// /* Copyright (c) 2020 XEPIC Corporation Limited */
// /*This work is free work: you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2.0 of the License, or (at your option) any later version.
//
// This work is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.*/
//
// This design is based on Xilinx PCIe IP "UlraScale FPGA Integrated Block for PCI Express 4.4"
// AXIs-ST width is fixed at 256bits. So when Lane width is x8 or x4, Please use 256bits AXIS-ST interface
// x8 or x4 lane width is not supported now.
// ------------------------------------ //

`timescale 1ns/1ps

module pcie3_ddr4 #( 
    parameter EXT_PIPE_SIM = "FALSE" , // "FALSE" or "TRUE"
    parameter DEBUG_ON     = "FALSE" , // "FALSE" or "TRUE"

    parameter CARD         = "MIC"   , // "MIC" or "KCU105"
    parameter DDR_BG_W     = CARD == "MIC" ? 2 : 1

)(
  /*
  input             g1clk_100m_p         ,
  input             g1clk_100m_n         , 

	output            db1_ddr4_en_vtt     ,
	output            db1_ddr4_en_vddq    ,
	output            db1_ddr4_en_vcc2v5  ,
	input             db1_power_good      ,

  input             c0_sys_clk_p       ,
  input             c0_sys_clk_n       ,
  output            c0_ddr4_act_n      ,
  output [16: 0]    c0_ddr4_adr        ,
  output [1 : 0]    c0_ddr4_ba         ,
  output [1 : 0]    c0_ddr4_bg         ,
  output [1 : 0]    c0_ddr4_cke        ,
  output [1 : 0]    c0_ddr4_odt        ,
  output [1 : 0]    c0_ddr4_cs_n       ,
  output [1 : 0]    c0_ddr4_ck_t       ,
  output [1 : 0]    c0_ddr4_ck_c       ,
  output            c0_ddr4_reset_n    ,
  inout  [7 : 0]    c0_ddr4_dm_dbi_n   ,
  inout  [63: 0]    c0_ddr4_dq         ,
  inout  [7 : 0]    c0_ddr4_dqs_c      ,
  inout  [7 : 0]    c0_ddr4_dqs_t      , 
  */
  input     user_clk,   
  output top_sig ,
  output check_err,
  output [31:0] w_check_cnt,
  output [31:0] w_check_err_cnt,
  input [33:0] user_write_addr,
  input [7:0] user_burst_len,
  input [31:0] user_burst_num,
  input test_start,
  input user_rst,
  input [31:0] user_wstrb,
  output [39:0] write_axi_clk_cnt,
  output [39:0] read_axi_clk_cnt,
  output [39:0] write_time_clk_cnt,
  output [39:0] read_time_clk_cnt ,
  input test_start_read       
											 
) ;
//wire test_start;
//wire top_sig;

 logic   c0_init_calib_complete     ;
 logic   ddr_clk                    ;



wire sys_clk_100m ;
wire gclk_100m ;
/*
IBUFDS IBUFDS_inst (
      .O                                (sys_clk_100m   ), // 1-bit output: Buffer output
      .I                                (g1clk_100m_p    ), // 1-bit input: Diff_p buffer input (connect directly to top-level port)
      .IB                               (g1clk_100m_n    )  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
   );
   
BUFG clkout1_buf
   (.O   (gclk_100m),
    .I   (sys_clk_100m));

*/

	
localparam integer C_M_AXI_ID_WIDTH = 11;
localparam integer C_M_AXI_BURST_LEN = 63;
localparam integer C_M_TARGET_SLAVE_BASE_ADDR = 32'h00000000;
localparam integer C_M_AXI_ADDR_WIDTH = 64;
localparam integer C_M_AXI_DATA_WIDTH = 256;
localparam integer C_M_AXI_AWUSER_WIDTH = 0;
localparam integer C_M_AXI_WUSER_WIDTH = 0;
localparam integer C_M_AXI_RUSER_WIDTH = 0;
localparam integer C_M_AXI_ARUSER_WIDTH = 0;
localparam integer  C_M_AXI_BUSER_WIDTH = 0;


localparam integer C_M2_AXI_ID_W     = 11                         ; // Master-2
localparam integer C_M2_AXI_ADDR_W   = 64                         ;
localparam integer C_M2_AXI_DATA_W   = 256                        ;
localparam integer C_M2_AXI_AWUSER_W = 0                          ;
localparam integer C_M2_AXI_WUSER_W  = 0                          ;
localparam integer C_M2_AXI_ARUSER_W = 0                          ;
localparam integer C_M2_AXI_RUSER_W  = 0                          ;
localparam integer C_M2_AXI_BUSER_W  = 0                          ;
localparam         C_M2_BASE_ADDR    = {{C_M2_AXI_ADDR_W}{1'b0}}  ;






logic [C_M2_AXI_ID_W-1     : 0] mem_a_axi_awid      ; // wr addr
logic [C_M2_AXI_ADDR_W-1   : 0] mem_a_axi_awaddr_int;
logic [C_M2_AXI_ADDR_W-1   : 0] mem_a_axi_awaddr    ;
logic [7                   : 0] mem_a_axi_awlen     ;
logic [2                   : 0] mem_a_axi_awsize    ;
logic [1                   : 0] mem_a_axi_awburst   ;
logic [C_M2_AXI_AWUSER_W-1 : 0] mem_a_axi_awuser    ;
logic                           mem_a_axi_awvalid   ;
logic                           mem_a_axi_awready   ;
logic [3                   : 0] mem_a_axi_awregion  ; // Unused
logic                           mem_a_axi_awlock    ; // Unused
logic [3                   : 0] mem_a_axi_awcache   ; // Unused
logic [2                   : 0] mem_a_axi_awprot    ; // Unused
logic [3                   : 0] mem_a_axi_awqos     ; // Unused
logic [C_M2_AXI_DATA_W-1   : 0] mem_a_axi_wdata     ; // wr data
logic [C_M2_AXI_DATA_W/8-1 : 0] mem_a_axi_wstrb     ;
logic                           mem_a_axi_wlast     ;
logic [C_M2_AXI_WUSER_W-1  : 0] mem_a_axi_wuser     ;
logic                           mem_a_axi_wvalid    ;
logic                           mem_a_axi_wready    ;
logic [C_M2_AXI_ID_W-1     : 0] mem_a_axi_bid       ; // wr res
logic [1                   : 0] mem_a_axi_bresp     ;
logic [C_M2_AXI_BUSER_W-1  : 0] mem_a_axi_buser     ;
logic                           mem_a_axi_bvalid    ;
logic                           mem_a_axi_bready    ;
logic [C_M2_AXI_ID_W-1     : 0] mem_a_axi_arid      ; // rd addr
logic [C_M2_AXI_ADDR_W-1   : 0] mem_a_axi_araddr_int;
logic [C_M2_AXI_ADDR_W-1   : 0] mem_a_axi_araddr    ;
logic [7                   : 0] mem_a_axi_arlen     ;
logic [2                   : 0] mem_a_axi_arsize    ;
logic [1                   : 0] mem_a_axi_arburst   ;
logic [C_M2_AXI_ARUSER_W-1 : 0] mem_a_axi_aruser    ;
logic                           mem_a_axi_arvalid   ;
logic                           mem_a_axi_arready   ;
logic [3                   : 0] mem_a_axi_arregion  ; // Unused
logic                           mem_a_axi_arlock    ; // Unused
logic [3                   : 0] mem_a_axi_arcache   ; // Unused
logic [2                   : 0] mem_a_axi_arprot    ; // Unused
logic [3                   : 0] mem_a_axi_arqos     ; // Unused
logic [C_M2_AXI_ID_W-1     : 0] mem_a_axi_rid       ; // rd data
logic [C_M2_AXI_DATA_W-1   : 0] mem_a_axi_rdata     ;
logic [1                   : 0] mem_a_axi_rresp     ;
logic                           mem_a_axi_rlast     ;
logic [C_M2_AXI_RUSER_W-1  : 0] mem_a_axi_ruser     ;
logic                           mem_a_axi_rvalid    ;
logic                           mem_a_axi_rready    ;








/*
ddr4_wrapper ddr4_chip0 (
    .sys_rstn                ( 1'b1                       ), // reset from soft_rstp
    .c0_sys_clk_p           ( c0_sys_clk_p              ),
    .c0_sys_clk_n           ( c0_sys_clk_n              ),
    .axi_clk   (user_clk  ),
// --------- P2 MODIFICATION END ---------- //

    .c0_ddr4_act_n          ( c0_ddr4_act_n             ),
    .c0_ddr4_adr            ( c0_ddr4_adr               ),
    .c0_ddr4_ba             ( c0_ddr4_ba                ),
    .c0_ddr4_bg             ( c0_ddr4_bg                ),
    .c0_ddr4_cke            ( c0_ddr4_cke               ),
    .c0_ddr4_odt            ( c0_ddr4_odt               ),
    .c0_ddr4_cs_n           ( c0_ddr4_cs_n              ),
    .c0_ddr4_ck_t           ( c0_ddr4_ck_t              ),
    .c0_ddr4_ck_c           ( c0_ddr4_ck_c              ),
    .c0_ddr4_reset_n        ( c0_ddr4_reset_n           ),
    .c0_ddr4_dm_dbi_n       ( c0_ddr4_dm_dbi_n          ),
    .c0_ddr4_dq             ( c0_ddr4_dq                ),
    .c0_ddr4_dqs_c          ( c0_ddr4_dqs_c             ),
    .c0_ddr4_dqs_t          ( c0_ddr4_dqs_t             ),
    .c0_init_calib_complete ( c0_init_calib_complete    ),
    .c0_ddr4_ui_clk         ( ddr_clk                   ),

    

 
 
	
	
	

    .s0_ddr4_s_axi_awid     ( mem_a_axi_awid            ),  //////
    .s0_ddr4_s_axi_awaddr   ( mem_a_axi_awaddr          ),  //////
    .s0_ddr4_s_axi_awlen    ( mem_a_axi_awlen           ),  //////
    .s0_ddr4_s_axi_awsize   ( mem_a_axi_awsize          ),  //////
    .s0_ddr4_s_axi_awburst  ( mem_a_axi_awburst         ),  //////
    .s0_ddr4_s_axi_awlock   ( mem_a_axi_awlock          ),  //////
    .s0_ddr4_s_axi_awcache  ( mem_a_axi_awcache         ),  //////
    .s0_ddr4_s_axi_awprot   ( mem_a_axi_awprot          ),  //////
    .s0_ddr4_s_axi_awqos    ( mem_a_axi_awqos           ),  //////
    .s0_ddr4_s_axi_awvalid  ( mem_a_axi_awvalid         ),  //////
    .s0_ddr4_s_axi_awready  ( mem_a_axi_awready         ),  //////
    .s0_ddr4_s_axi_wdata    ( mem_a_axi_wdata           ),  //////
    .s0_ddr4_s_axi_wstrb    ( mem_a_axi_wstrb           ),  //////
    .s0_ddr4_s_axi_wlast    ( mem_a_axi_wlast           ),  //////
    .s0_ddr4_s_axi_wvalid   ( mem_a_axi_wvalid          ),  //////
    .s0_ddr4_s_axi_wready   ( mem_a_axi_wready          ),  //////
    .s0_ddr4_s_axi_bready   ( mem_a_axi_bready          ),  //////
    .s0_ddr4_s_axi_bid      ( mem_a_axi_bid             ),  //////
    .s0_ddr4_s_axi_bresp    ( mem_a_axi_bresp           ),  //////
    .s0_ddr4_s_axi_bvalid   ( mem_a_axi_bvalid          ),  //////															//////		 
    .s0_ddr4_s_axi_arid     ( mem_a_axi_arid    ),          //////
    .s0_ddr4_s_axi_araddr   ( mem_a_axi_araddr          ),  //////
    .s0_ddr4_s_axi_arlen    ( mem_a_axi_arlen           ),  //////
    .s0_ddr4_s_axi_arsize   ( mem_a_axi_arsize          ),  //////
    .s0_ddr4_s_axi_arburst  ( mem_a_axi_arburst         ),  //////
    .s0_ddr4_s_axi_arlock   ( mem_a_axi_arlock          ),  //////
    .s0_ddr4_s_axi_arcache  ( mem_a_axi_arcache         ),  //////
    .s0_ddr4_s_axi_arprot   ( mem_a_axi_arprot          ),  //////
    .s0_ddr4_s_axi_arqos    ( mem_a_axi_arqos           ),  //////
    .s0_ddr4_s_axi_arvalid  ( mem_a_axi_arvalid         ),  //////
    .s0_ddr4_s_axi_arready  ( mem_a_axi_arready         ),  //////
    .s0_ddr4_s_axi_rready   ( mem_a_axi_rready          ),  //////
    .s0_ddr4_s_axi_rid      ( mem_a_axi_rid             ),  //////
    .s0_ddr4_s_axi_rdata    ( mem_a_axi_rdata           ),  //////
    .s0_ddr4_s_axi_rresp    ( mem_a_axi_rresp           ),  //////
    .s0_ddr4_s_axi_rlast    ( mem_a_axi_rlast           ),  //////
    .s0_ddr4_s_axi_rvalid   ( mem_a_axi_rvalid          )   //////
    
);	
	
	*/


wire [C_M_AXI_ID_WIDTH-1 : 0]        M_AXI_AWID      ;
wire [C_M_AXI_ADDR_WIDTH-1 : 0]      M_AXI_AWADDR    ;
wire [7 : 0]                         M_AXI_AWLEN     ;
wire [2 : 0]                         M_AXI_AWSIZE    ;
wire [1 : 0]                         M_AXI_AWBURST   ;
wire                                 M_AXI_AWLOCK    ;
wire [3 : 0]                         M_AXI_AWCACHE   ;
wire [2 : 0]                         M_AXI_AWPROT    ;
wire [3 : 0]                         M_AXI_AWQOS     ;
wire [C_M_AXI_AWUSER_WIDTH-1 : 0]    M_AXI_AWUSER    ;
wire                                 M_AXI_AWVALID   ;
wire                                 M_AXI_AWREADY  ;
                                                     
wire [C_M_AXI_DATA_WIDTH-1 : 0]      M_AXI_WDATA     ;
wire [C_M_AXI_DATA_WIDTH/8-1 : 0]    M_AXI_WSTRB     ;
wire                                 M_AXI_WLAST     ;
wire [C_M_AXI_WUSER_WIDTH-1 : 0]     M_AXI_WUSER     ;
wire                                 M_AXI_WVALID    ;
wire                                 M_AXI_WREADY   ;
                                                     
wire [C_M_AXI_ID_WIDTH-1 : 0]        M_AXI_BID      ;
wire [1 : 0]                         M_AXI_BRESP    ;
wire [C_M_AXI_BUSER_WIDTH-1 : 0]     M_AXI_BUSER    ;
wire                                 M_AXI_BVALID   ;
wire                                 M_AXI_BREADY    ;
                                                     
wire [C_M_AXI_ID_WIDTH-1 : 0]        M_AXI_ARID      ;
wire [C_M_AXI_ADDR_WIDTH-1 : 0]      M_AXI_ARADDR    ;
wire [7 : 0]                         M_AXI_ARLEN     ;
wire [2 : 0]                         M_AXI_ARSIZE    ;
wire [1 : 0]                         M_AXI_ARBURST   ;
wire                                 M_AXI_ARLOCK    ;
wire [3 : 0]                         M_AXI_ARCACHE   ;
wire [2 : 0]                         M_AXI_ARPROT    ;
wire [3 : 0]                         M_AXI_ARQOS     ;
wire [C_M_AXI_ARUSER_WIDTH-1 : 0]    M_AXI_ARUSER    ;
wire                                 M_AXI_ARVALID   ;
wire                                 M_AXI_ARREADY  ;
                                                     
wire [C_M_AXI_ID_WIDTH-1 : 0]        M_AXI_RID      ;
wire [C_M_AXI_DATA_WIDTH-1 : 0]      M_AXI_RDATA    ;
wire [1 : 0]                         M_AXI_RRESP    ;
wire                                 M_AXI_RLAST    ;
wire [C_M_AXI_RUSER_WIDTH-1 : 0]     M_AXI_RUSER    ;
wire                                 M_AXI_RVALID   ;
wire                                 M_AXI_RREADY    ;



axi_user_ctrl_pbrs#(
    .C_M_TARGET_SLAVE_BASE_ADDR	 (C_M_TARGET_SLAVE_BASE_ADDR),
		.C_M_AXI_BURST_LEN	         (C_M_AXI_BURST_LEN),
		.C_M_AXI_ID_WIDTH	         (C_M_AXI_ID_WIDTH),
		.C_M_AXI_ADDR_WIDTH	         (C_M_AXI_ADDR_WIDTH),
		.C_M_AXI_DATA_WIDTH	         (C_M_AXI_DATA_WIDTH),
		.C_M_AXI_AWUSER_WIDTH	     (C_M_AXI_AWUSER_WIDTH),
		.C_M_AXI_ARUSER_WIDTH	     (C_M_AXI_ARUSER_WIDTH),
		.C_M_AXI_WUSER_WIDTH	     (C_M_AXI_WUSER_WIDTH),
		.C_M_AXI_RUSER_WIDTH	     (C_M_AXI_RUSER_WIDTH),
		.C_M_AXI_BUSER_WIDTH	     (C_M_AXI_BUSER_WIDTH) 
)
axi_user_ctrl_pbrs_inst(
    .M_AXI_ACLK     (user_clk)      ,
		.M_AXI_ARESETN  (~user_rst)         ,

		.M_AXI_AWID     (M_AXI_AWID   ),
		.M_AXI_AWADDR   (M_AXI_AWADDR ),
		.M_AXI_AWLEN    (M_AXI_AWLEN  ),
		.M_AXI_AWSIZE   (M_AXI_AWSIZE ),
		.M_AXI_AWBURST  (M_AXI_AWBURST),
		.M_AXI_AWLOCK   (M_AXI_AWLOCK ),
		.M_AXI_AWCACHE  (M_AXI_AWCACHE),
		.M_AXI_AWPROT   (M_AXI_AWPROT ),
		.M_AXI_AWQOS    (M_AXI_AWQOS  ),
		.M_AXI_AWVALID  (M_AXI_AWVALID),
		.M_AXI_AWREADY  (M_AXI_AWREADY),
    .M_AXI_AWUSER   (M_AXI_AWUSER ),

		.M_AXI_WDATA     (M_AXI_WDATA ),
		.M_AXI_WSTRB     (M_AXI_WSTRB ),
		.M_AXI_WLAST     (M_AXI_WLAST ),
		.M_AXI_WVALID    (M_AXI_WVALID),
		.M_AXI_WREADY    (M_AXI_WREADY),
    .M_AXI_WUSER     (M_AXI_WUSER ),

		.M_AXI_BID      (M_AXI_BID   ) ,
		.M_AXI_BRESP    (M_AXI_BRESP ) ,
		.M_AXI_BVALID   (M_AXI_BVALID) ,
		.M_AXI_BREADY   (M_AXI_BREADY) ,
    .M_AXI_BUSER    (M_AXI_BUSER ) ,

		.M_AXI_ARID     (M_AXI_ARID   ) ,
		.M_AXI_ARADDR   (M_AXI_ARADDR ) ,
		.M_AXI_ARLEN    (M_AXI_ARLEN  ) ,
		.M_AXI_ARSIZE   (M_AXI_ARSIZE ) ,
		.M_AXI_ARBURST  (M_AXI_ARBURST) ,
		.M_AXI_ARLOCK   (M_AXI_ARLOCK ) ,
		.M_AXI_ARCACHE  (M_AXI_ARCACHE) ,
		.M_AXI_ARPROT   (M_AXI_ARPROT ) ,
		.M_AXI_ARQOS    (M_AXI_ARQOS  ) ,
		.M_AXI_ARVALID  (M_AXI_ARVALID) ,
		.M_AXI_ARREADY  (M_AXI_ARREADY) ,
    .M_AXI_ARUSER   (M_AXI_ARUSER ) ,

		.M_AXI_RREADY    (M_AXI_RREADY),
		.M_AXI_RID       (M_AXI_RID   ),
		.M_AXI_RDATA     (M_AXI_RDATA ),
		.M_AXI_RRESP     (M_AXI_RRESP ),
		.M_AXI_RLAST     (M_AXI_RLAST ),
		.M_AXI_RVALID    (M_AXI_RVALID),
    .M_AXI_RUSER     (M_AXI_RUSER ),
    .c0_init_calib_complete(c0_init_calib_complete),
    .test_start(test_start),
    .test_start_read(test_start_read),
    .top_sig(top_sig),
    .user_write_addr(user_write_addr),
    .user_burst_len(user_burst_len),
    .user_burst_num(user_burst_num),
    .w_check_cnt(w_check_cnt),
    .w_check_err_cnt(w_check_err_cnt),
    .check_err(check_err),
    .user_wstrb(user_wstrb),
    .write_axi_clk_cnt(write_axi_clk_cnt),
    .read_axi_clk_cnt(read_axi_clk_cnt),
    .write_time_clk_cnt(write_time_clk_cnt),
    .read_time_clk_cnt(read_time_clk_cnt)
);


xepic_ddr4_dc1 chip0_wrapper (
    .sys_rstn               ( 1'b1                      ),   // reset from soft_rstp
	 .gclk_100m				( ),
	
    .axi_clk   				(user_clk  					),
    
    .c0_init_calib_complete ( c0_init_calib_complete    ),
    .s0_ddr4_s_axi_awid     ( M_AXI_AWID            ),  //////
    .s0_ddr4_s_axi_awaddr   ( M_AXI_AWADDR          ),  //////
    .s0_ddr4_s_axi_awlen    ( M_AXI_AWLEN           ),  //////
    .s0_ddr4_s_axi_awsize   ( M_AXI_AWSIZE          ),  //////
    .s0_ddr4_s_axi_awburst  ( M_AXI_AWBURST         ),  //////
    .s0_ddr4_s_axi_awlock   ( M_AXI_AWLOCK          ),  //////
    .s0_ddr4_s_axi_awcache  ( M_AXI_AWCACHE         ),  //////
    .s0_ddr4_s_axi_awprot   ( M_AXI_AWPROT          ),  //////
    .s0_ddr4_s_axi_awqos    ( M_AXI_AWQOS           ),  //////
    .s0_ddr4_s_axi_awvalid  ( M_AXI_AWVALID         ),  //////
    .s0_ddr4_s_axi_awready  ( M_AXI_AWREADY         ),  //////
    .s0_ddr4_s_axi_wdata    ( M_AXI_WDATA           ),  //////
    .s0_ddr4_s_axi_wstrb    ( M_AXI_WSTRB           ),  //////
    .s0_ddr4_s_axi_wlast    ( M_AXI_WLAST           ),  //////
    .s0_ddr4_s_axi_wvalid   ( M_AXI_WVALID          ),  //////
    .s0_ddr4_s_axi_wready   ( M_AXI_WREADY          ),  //////
    .s0_ddr4_s_axi_bready   ( M_AXI_BREADY          ),  //////
    .s0_ddr4_s_axi_bid      ( M_AXI_BID             ),  //////
    .s0_ddr4_s_axi_bresp    ( M_AXI_BRESP           ),  //////
    .s0_ddr4_s_axi_bvalid   ( M_AXI_BVALID          ),  //////															//////
    .s0_ddr4_s_axi_arid     ( M_AXI_ARID    ),          //////
    .s0_ddr4_s_axi_araddr   ( M_AXI_ARADDR          ),  //////
    .s0_ddr4_s_axi_arlen    ( M_AXI_ARLEN           ),  //////
    .s0_ddr4_s_axi_arsize   ( M_AXI_ARSIZE          ),  //////
    .s0_ddr4_s_axi_arburst  ( M_AXI_ARBURST         ),  //////
    .s0_ddr4_s_axi_arlock   ( M_AXI_ARLOCK          ),  //////
    .s0_ddr4_s_axi_arcache  ( M_AXI_ARCACHE         ),  //////
    .s0_ddr4_s_axi_arprot   ( M_AXI_ARPROT          ),  //////
    .s0_ddr4_s_axi_arqos    ( M_AXI_ARQOS           ),  //////
    .s0_ddr4_s_axi_arvalid  ( M_AXI_ARVALID         ),  //////
    .s0_ddr4_s_axi_arready  ( M_AXI_ARREADY         ),  //////
    .s0_ddr4_s_axi_rready   ( M_AXI_RREADY         ),  //////
    .s0_ddr4_s_axi_rid      ( M_AXI_RID            ),  //////
    .s0_ddr4_s_axi_rdata    ( M_AXI_RDATA          ),  //////
    .s0_ddr4_s_axi_rresp    ( M_AXI_RRESP          ),  //////
    .s0_ddr4_s_axi_rlast    ( M_AXI_RLAST          ),  //////
    .s0_ddr4_s_axi_rvalid   ( M_AXI_RVALID         )   //////																			
)/* synthesis syn_noprune=1 */   ;	

endmodule
