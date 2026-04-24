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

`timescale 1ns/1ps

module pcie3_tlp_intf #(
    parameter         DEBUG_ON          = "FALSE"                    , // "FALSE" or "TRUE"
    
    parameter integer BAR_NUM_M1        = 2                          , // BAR number minus one

	parameter integer C_M0_AXI_ID_W	    = 1                          , // Master-0, for mmr
	parameter integer C_M0_AXI_ADDR_W	= 12                         ,
	parameter integer C_M0_AXI_DATA_W	= 256                        ,
	parameter integer C_M0_AXI_AWUSER_W = 0                          ,
	parameter integer C_M0_AXI_WUSER_W  = 0                          ,
	parameter integer C_M0_AXI_ARUSER_W = 0                          ,
	parameter integer C_M0_AXI_RUSER_W  = 0                          ,
	parameter integer C_M0_AXI_BUSER_W  = 0                          ,
    parameter         C_M0_BASE_ADDR	= {{C_M0_AXI_ADDR_W}{1'b0}}  ,
	parameter integer C_M1_AXI_ID_W	    = 1                          , // Master-1
	parameter integer C_M1_AXI_ADDR_W	= 64                         ,
	parameter integer C_M1_AXI_DATA_W	= 256                        ,
	parameter integer C_M1_AXI_AWUSER_W = 0                          ,
	parameter integer C_M1_AXI_WUSER_W  = 0                          ,
	parameter integer C_M1_AXI_ARUSER_W = 0                          ,
	parameter integer C_M1_AXI_RUSER_W  = 0                          ,
	parameter integer C_M1_AXI_BUSER_W  = 0                          ,
    parameter         C_M1_BASE_ADDR	= {{C_M1_AXI_ADDR_W}{1'b0}}  ,
	parameter integer C_M2_AXI_ID_W	    = 1                          , // Master-2
	parameter integer C_M2_AXI_ADDR_W	= 64                         ,
	parameter integer C_M2_AXI_DATA_W	= 256                        ,
	parameter integer C_M2_AXI_AWUSER_W = 0                          ,
	parameter integer C_M2_AXI_WUSER_W  = 0                          ,
	parameter integer C_M2_AXI_ARUSER_W = 0                          ,
	parameter integer C_M2_AXI_RUSER_W  = 0                          ,
	parameter integer C_M2_AXI_BUSER_W  = 0                          ,
    parameter         C_M2_BASE_ADDR	= {{C_M2_AXI_ADDR_W}{1'b0}}  ,
	parameter integer C_S_AXI_ID_W	    = 1                          , // Slave-0
	parameter integer C_S_AXI_ADDR_W	= 64                         ,
	parameter integer C_S_AXI_DATA_W	= 256                        ,
	parameter integer C_S_AXI_AWUSER_W  = 0                          ,
	parameter integer C_S_AXI_WUSER_W   = 0                          ,
	parameter integer C_S_AXI_ARUSER_W  = 0                          ,
	parameter integer C_S_AXI_RUSER_W   = 0                          ,
	parameter integer C_S_AXI_BUSER_W   = 0                          ,
    parameter         C_S_BASE_ADDR	    = {{C_S_AXI_ADDR_W}{1'b0}}       

)(  
  // clock and reset
  input            user_clk                        , // input    
  input            user_reset                      , // input 
  input            soft_rstp                       , // input
  // Configuration status
  input  [1   : 0] cfg_max_payload                 , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  input  [2   : 0] cfg_max_read_req                , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  input            cfg_rcb_status                  , // input            1 - 128B; 0 - 64B
  // RQ/RC 
  output [255 : 0] s_axis_rq_tdata                 , // output [255 : 0] 
  output [7   : 0] s_axis_rq_tkeep                 , // output [7   : 0] 
  output           s_axis_rq_tlast                 , // output           
  input            s_axis_rq_tready                , // input  
  output [59  : 0] s_axis_rq_tuser                 , // output [59  : 0] 
  output           s_axis_rq_tvalid                , // output           
  input  [255 : 0] m_axis_rc_tdata                 , // input  [255 : 0] 
  input  [7   : 0] m_axis_rc_tkeep                 , // input  [7   : 0] 
  input            m_axis_rc_tlast                 , // input            
  output           m_axis_rc_tready                , // output           
  input  [74  : 0] m_axis_rc_tuser                 , // input  [74  : 0] 
  input            m_axis_rc_tvalid                , // input     
  // CQ/CC 
  input  [255 : 0] m_axis_cq_tdata                 , // input  [255 : 0] 
  input  [7   : 0] m_axis_cq_tkeep                 , // input  [7   : 0] 
  input            m_axis_cq_tlast                 , // input            
  output           m_axis_cq_tready                , // output           
  input  [41  : 0] m_axis_cq_tuser                 , // input  [41  : 0] 
  input            m_axis_cq_tvalid                , // input            
  output [255 : 0] s_axis_cc_tdata                 , // output [255 : 0] 
  output [7   : 0] s_axis_cc_tkeep                 , // output [7   : 0] 
  output           s_axis_cc_tlast                 , // output           
  input            s_axis_cc_tready                , // input 
  output [32  : 0] s_axis_cc_tuser                 , // output [32  : 0] 
  output           s_axis_cc_tvalid                , // output
  // Connect to memory maped registers
  output [21  : 0] tlp_intf_fifo_status            , // fifo status
  output [21  : 0] tlp_intf_fifo_error             ,
  output           cc_tlp_vld                      ,
  output           cc_tlp_invld                    , // When read data from local memory encountered errors
  output           rq_tlp_vld                      ,
  output           rq_tlp_invld                    ,
  output           rc_tlp_vld                      ,
  output           rc_tlp_invld                    ,
  output           wdma_error                      ,
  output           rdma_error                      ,
  output [127 : 0] cq_cc_fifo_werr                 ,
  // --- AXI-MM-master-0 --- //
  input                            m0_axi_aclk     , // Not used
  input                            m0_axi_aresetn  , // Not used
  output [C_M0_AXI_ID_W-1     : 0] m0_axi_awid     , // wr addr
  output [C_M0_AXI_ADDR_W-1   : 0] m0_axi_awaddr   ,   
  output [7                   : 0] m0_axi_awlen    ,
  output [2                   : 0] m0_axi_awsize   ,
  output [1                   : 0] m0_axi_awburst  ,
  output [C_M0_AXI_AWUSER_W-1 : 0] m0_axi_awuser   ,
  output                           m0_axi_awvalid  ,
  input                            m0_axi_awready  ,
  output [3                   : 0] m0_axi_awregion , // Unused
  output                           m0_axi_awlock   , // Unused
  output [3                   : 0] m0_axi_awcache  , // Unused
  output [2                   : 0] m0_axi_awprot   , // Unused
  output [3                   : 0] m0_axi_awqos    , // Unused
  output [C_M0_AXI_DATA_W-1   : 0] m0_axi_wdata    , // wr data
  output [C_M0_AXI_DATA_W/8-1 : 0] m0_axi_wstrb    ,
  output                           m0_axi_wlast    ,
  output [C_M0_AXI_WUSER_W-1  : 0] m0_axi_wuser    ,
  output                           m0_axi_wvalid   ,
  input                            m0_axi_wready   ,
  input  [C_M0_AXI_ID_W-1     : 0] m0_axi_bid      , // wr res
  input  [1                   : 0] m0_axi_bresp    ,
  input  [C_M0_AXI_BUSER_W-1  : 0] m0_axi_buser    ,
  input                            m0_axi_bvalid   ,
  output                           m0_axi_bready   ,
  output [C_M0_AXI_ID_W-1     : 0] m0_axi_arid     , // rd addr
  output [C_M0_AXI_ADDR_W-1   : 0] m0_axi_araddr   ,
  output [7                   : 0] m0_axi_arlen    ,
  output [2                   : 0] m0_axi_arsize   ,
  output [1                   : 0] m0_axi_arburst  ,
  output [C_M0_AXI_ARUSER_W-1 : 0] m0_axi_aruser   ,
  output                           m0_axi_arvalid  ,
  input                            m0_axi_arready  ,
  output [3                   : 0] m0_axi_arregion , // Unused
  output                           m0_axi_arlock   , // Unused
  output [3                   : 0] m0_axi_arcache  , // Unused
  output [2                   : 0] m0_axi_arprot   , // Unused
  output [3                   : 0] m0_axi_arqos    , // Unused
  input  [C_M0_AXI_ID_W-1     : 0] m0_axi_rid      , // rd data
  input  [C_M0_AXI_DATA_W-1   : 0] m0_axi_rdata    ,
  input  [1                   : 0] m0_axi_rresp    ,
  input                            m0_axi_rlast    ,
  input  [C_M0_AXI_RUSER_W-1  : 0] m0_axi_ruser    ,
  input                            m0_axi_rvalid   ,
  output                           m0_axi_rready   , 
  // --- AXI-MM-master-1 --- //
  input                            m1_axi_aclk     , // Not used
  input                            m1_axi_aresetn  , // Not used
  output [C_M1_AXI_ID_W-1     : 0] m1_axi_awid     , // wr addr
  output [C_M1_AXI_ADDR_W-1   : 0] m1_axi_awaddr   ,   
  output [7                   : 0] m1_axi_awlen    ,
  output [2                   : 0] m1_axi_awsize   ,
  output [1                   : 0] m1_axi_awburst  ,
  output [C_M1_AXI_AWUSER_W-1 : 0] m1_axi_awuser   ,
  output                           m1_axi_awvalid  ,
  input                            m1_axi_awready  ,
  output [3                   : 0] m1_axi_awregion , // Unused
  output                           m1_axi_awlock   , // Unused
  output [3                   : 0] m1_axi_awcache  , // Unused
  output [2                   : 0] m1_axi_awprot   , // Unused
  output [3                   : 0] m1_axi_awqos    , // Unused
  output [C_M1_AXI_DATA_W-1   : 0] m1_axi_wdata    , // wr data
  output [C_M1_AXI_DATA_W/8-1 : 0] m1_axi_wstrb    ,
  output                           m1_axi_wlast    ,
  output [C_M1_AXI_WUSER_W-1  : 0] m1_axi_wuser    ,
  output                           m1_axi_wvalid   ,
  input                            m1_axi_wready   ,
  input  [C_M1_AXI_ID_W-1     : 0] m1_axi_bid      , // wr res
  input  [1                   : 0] m1_axi_bresp    ,
  input  [C_M1_AXI_BUSER_W-1  : 0] m1_axi_buser    ,
  input                            m1_axi_bvalid   ,
  output                           m1_axi_bready   ,
  output [C_M1_AXI_ID_W-1     : 0] m1_axi_arid     , // rd addr
  output [C_M1_AXI_ADDR_W-1   : 0] m1_axi_araddr   ,
  output [7                   : 0] m1_axi_arlen    ,
  output [2                   : 0] m1_axi_arsize   ,
  output [1                   : 0] m1_axi_arburst  ,
  output [C_M1_AXI_ARUSER_W-1 : 0] m1_axi_aruser   ,
  output                           m1_axi_arvalid  ,
  input                            m1_axi_arready  ,
  output [3                   : 0] m1_axi_arregion , // Unused
  output                           m1_axi_arlock   , // Unused
  output [3                   : 0] m1_axi_arcache  , // Unused
  output [2                   : 0] m1_axi_arprot   , // Unused
  output [3                   : 0] m1_axi_arqos    , // Unused
  input  [C_M1_AXI_ID_W-1     : 0] m1_axi_rid      , // rd data
  input  [C_M1_AXI_DATA_W-1   : 0] m1_axi_rdata    ,
  input  [1                   : 0] m1_axi_rresp    ,
  input                            m1_axi_rlast    ,
  input  [C_M1_AXI_RUSER_W-1  : 0] m1_axi_ruser    ,
  input                            m1_axi_rvalid   ,
  output                           m1_axi_rready   ,
  // --- AXI-MM-master-2 --- //
  input                            m2_axi_aclk     , // Not used
  input                            m2_axi_aresetn  , // Not used
  output [C_M2_AXI_ID_W-1     : 0] m2_axi_awid     , // wr addr
  output [C_M2_AXI_ADDR_W-1   : 0] m2_axi_awaddr   ,   
  output [7                   : 0] m2_axi_awlen    ,
  output [2                   : 0] m2_axi_awsize   ,
  output [1                   : 0] m2_axi_awburst  ,
  output [C_M2_AXI_AWUSER_W-1 : 0] m2_axi_awuser   ,
  output                           m2_axi_awvalid  ,
  input                            m2_axi_awready  ,
  output [3                   : 0] m2_axi_awregion , // Unused
  output                           m2_axi_awlock   , // Unused
  output [3                   : 0] m2_axi_awcache  , // Unused
  output [2                   : 0] m2_axi_awprot   , // Unused
  output [3                   : 0] m2_axi_awqos    , // Unused
  output [C_M2_AXI_DATA_W-1   : 0] m2_axi_wdata    , // wr data
  output [C_M2_AXI_DATA_W/8-1 : 0] m2_axi_wstrb    ,
  output                           m2_axi_wlast    ,
  output [C_M2_AXI_WUSER_W-1  : 0] m2_axi_wuser    ,
  output                           m2_axi_wvalid   ,
  input                            m2_axi_wready   ,
  input  [C_M2_AXI_ID_W-1     : 0] m2_axi_bid      , // wr res
  input  [1                   : 0] m2_axi_bresp    ,
  input  [C_M2_AXI_BUSER_W-1  : 0] m2_axi_buser    ,
  input                            m2_axi_bvalid   ,
  output                           m2_axi_bready   ,
  output [C_M2_AXI_ID_W-1     : 0] m2_axi_arid     , // rd addr
  output [C_M2_AXI_ADDR_W-1   : 0] m2_axi_araddr   ,
  output [7                   : 0] m2_axi_arlen    ,
  output [2                   : 0] m2_axi_arsize   ,
  output [1                   : 0] m2_axi_arburst  ,
  output [C_M2_AXI_ARUSER_W-1 : 0] m2_axi_aruser   ,
  output                           m2_axi_arvalid  ,
  input                            m2_axi_arready  ,
  output [3                   : 0] m2_axi_arregion , // Unused
  output                           m2_axi_arlock   , // Unused
  output [3                   : 0] m2_axi_arcache  , // Unused
  output [2                   : 0] m2_axi_arprot   , // Unused
  output [3                   : 0] m2_axi_arqos    , // Unused
  input  [C_M2_AXI_ID_W-1     : 0] m2_axi_rid      , // rd data
  input  [C_M2_AXI_DATA_W-1   : 0] m2_axi_rdata    ,
  input  [1                   : 0] m2_axi_rresp    ,
  input                            m2_axi_rlast    ,
  input  [C_M2_AXI_RUSER_W-1  : 0] m2_axi_ruser    ,
  input                            m2_axi_rvalid   ,
  output                           m2_axi_rready   , 
  // AXI-MM-slave0     
  input                            s_axi_aclk      , // Unused
  input                            s_axi_aresetn   , // Unused
  input  [C_S_AXI_ID_W-1      : 0] s_axi_awid      , // wr addr
  input  [C_S_AXI_ADDR_W-1    : 0] s_axi_awaddr    ,
  input  [7                   : 0] s_axi_awlen     ,
  input  [2                   : 0] s_axi_awsize    ,
  input  [1                   : 0] s_axi_awburst   ,
  input  [3                   : 0] s_axi_awregion  , // Unused
  input                            s_axi_awlock    , // Unused
  input  [3                   : 0] s_axi_awcache   , // Unused
  input  [2                   : 0] s_axi_awprot    , // Unused
  input  [3                   : 0] s_axi_awqos     , // Unused
  input  [C_S_AXI_AWUSER_W-1  : 0] s_axi_awuser    , 
  input                            s_axi_awvalid   ,
  output                           s_axi_awready   ,
  input  [C_S_AXI_DATA_W-1    : 0] s_axi_wdata     , // wr data
  input  [C_S_AXI_DATA_W/8-1  : 0] s_axi_wstrb     ,
  input                            s_axi_wlast     ,
  input  [C_S_AXI_WUSER_W-1   : 0] s_axi_wuser     ,
  input                            s_axi_wvalid    ,
  output                           s_axi_wready    ,
  output [C_S_AXI_ID_W-1      : 0] s_axi_bid       , // wr res
  output [1                   : 0] s_axi_bresp     ,
  output [C_S_AXI_BUSER_W-1   : 0] s_axi_buser     ,
  output                           s_axi_bvalid    ,
  input                            s_axi_bready    ,
  input  [C_S_AXI_ID_W-1      : 0] s_axi_arid      , // rd addr
  input  [C_S_AXI_ADDR_W-1    : 0] s_axi_araddr    ,
  input  [7                   : 0] s_axi_arlen     ,
  input  [2                   : 0] s_axi_arsize    ,
  input  [1                   : 0] s_axi_arburst   ,
  input  [3                   : 0] s_axi_arregion  , // Unused
  input                            s_axi_arlock    , // Unused
  input  [3                   : 0] s_axi_arcache   , // Unused
  input  [2                   : 0] s_axi_arprot    , // Unused
  input  [3                   : 0] s_axi_arqos     , // Unused
  input  [C_S_AXI_ARUSER_W-1  : 0] s_axi_aruser    ,
  input                            s_axi_arvalid   ,
  output                           s_axi_arready   ,
  output [C_S_AXI_ID_W-1      : 0] s_axi_rid       , // rd data
  output [C_S_AXI_DATA_W-1    : 0] s_axi_rdata     ,
  output [1                   : 0] s_axi_rresp     ,
  output                           s_axi_rlast     ,
  output [C_S_AXI_RUSER_W-1   : 0] s_axi_ruser     ,
  output                           s_axi_rvalid    ,
  input                            s_axi_rready    
      
) ;

// ---------------------------------------- //
//               Declarations               //
// ---------------------------------------- //

assign tlp_intf_fifo_status = 'b0  ;
assign tlp_intf_fifo_error  = 'b0  ;

assign rq_tlp_vld   = 'b0 ;
assign rq_tlp_invld = 'b0 ;
assign rc_tlp_vld   = 'b0 ;
assign rc_tlp_invld = 'b0 ;

cqcc_intf #(
    .DEBUG_ON          ( DEBUG_ON          ) ,
    .BAR_NUM_M1        ( BAR_NUM_M1        ) ,
	.C_M0_AXI_ID_W	   ( C_M0_AXI_ID_W	   ) , // Master-0
	.C_M0_AXI_ADDR_W   ( C_M0_AXI_ADDR_W   ) ,
	.C_M0_AXI_DATA_W   ( C_M0_AXI_DATA_W   ) ,
	.C_M0_AXI_AWUSER_W ( C_M0_AXI_AWUSER_W ) ,
	.C_M0_AXI_WUSER_W  ( C_M0_AXI_WUSER_W  ) ,
	.C_M0_AXI_ARUSER_W ( C_M0_AXI_ARUSER_W ) ,
	.C_M0_AXI_RUSER_W  ( C_M0_AXI_RUSER_W  ) ,
	.C_M0_AXI_BUSER_W  ( C_M0_AXI_BUSER_W  ) ,
    .C_M0_BASE_ADDR	   ( C_M0_BASE_ADDR	   ) ,
	.C_M1_AXI_ID_W	   ( C_M1_AXI_ID_W	   ) , // Master-1
	.C_M1_AXI_ADDR_W   ( C_M1_AXI_ADDR_W   ) ,
	.C_M1_AXI_DATA_W   ( C_M1_AXI_DATA_W   ) ,
	.C_M1_AXI_AWUSER_W ( C_M1_AXI_AWUSER_W ) ,
	.C_M1_AXI_WUSER_W  ( C_M1_AXI_WUSER_W  ) ,
	.C_M1_AXI_ARUSER_W ( C_M1_AXI_ARUSER_W ) ,
	.C_M1_AXI_RUSER_W  ( C_M1_AXI_RUSER_W  ) ,
	.C_M1_AXI_BUSER_W  ( C_M1_AXI_BUSER_W  ) ,
    .C_M1_BASE_ADDR	   ( C_M1_BASE_ADDR	   ) ,
	.C_M2_AXI_ID_W	   ( C_M2_AXI_ID_W	   ) , // Master-2
	.C_M2_AXI_ADDR_W   ( C_M2_AXI_ADDR_W   ) ,
	.C_M2_AXI_DATA_W   ( C_M2_AXI_DATA_W   ) ,
	.C_M2_AXI_AWUSER_W ( C_M2_AXI_AWUSER_W ) ,
	.C_M2_AXI_WUSER_W  ( C_M2_AXI_WUSER_W  ) ,
	.C_M2_AXI_ARUSER_W ( C_M2_AXI_ARUSER_W ) ,
	.C_M2_AXI_RUSER_W  ( C_M2_AXI_RUSER_W  ) ,
	.C_M2_AXI_BUSER_W  ( C_M2_AXI_BUSER_W  ) ,
    .C_M2_BASE_ADDR	   ( C_M2_BASE_ADDR	   ) 
) cqcc_intf_inst (
  .user_clk         ( user_clk         ) , // input    
  .user_reset       ( user_reset       ) , // input
  .soft_rstp        ( soft_rstp        ) , // input 
  .cfg_max_payload  ( cfg_max_payload  ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  .cfg_max_read_req ( cfg_max_read_req ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  .cfg_rcb_status   ( cfg_rcb_status   ) , // input
  .m_axis_cq_tdata  ( m_axis_cq_tdata  ) , // input  [255 : 0] 
  .m_axis_cq_tkeep  ( m_axis_cq_tkeep  ) , // input  [7   : 0] 
  .m_axis_cq_tlast  ( m_axis_cq_tlast  ) , // input            
  .m_axis_cq_tready ( m_axis_cq_tready ) , // output           
  .m_axis_cq_tuser  ( m_axis_cq_tuser  ) , // input  [41  : 0] 
  .m_axis_cq_tvalid ( m_axis_cq_tvalid ) , // input            
  .s_axis_cc_tdata  ( s_axis_cc_tdata  ) , // output [255 : 0] 
  .s_axis_cc_tkeep  ( s_axis_cc_tkeep  ) , // output [7   : 0] 
  .s_axis_cc_tlast  ( s_axis_cc_tlast  ) , // output           
  .s_axis_cc_tready ( s_axis_cc_tready ) , // input   
  .s_axis_cc_tuser  ( s_axis_cc_tuser  ) , // output [32  : 0] 
  .s_axis_cc_tvalid ( s_axis_cc_tvalid ) , // output  
  .cc_tlp_vld       ( cc_tlp_vld       ) , // output
  .cc_tlp_invld     ( cc_tlp_invld     ) , // output 
  .m0_axi_aclk      ( m0_axi_aclk      ) , // Not used
  .m0_axi_aresetn   ( m0_axi_aresetn   ) , // Not used
  .m0_axi_awid      ( m0_axi_awid      ) , // wr addr
  .m0_axi_awaddr    ( m0_axi_awaddr    ) ,   
  .m0_axi_awlen     ( m0_axi_awlen     ) ,
  .m0_axi_awsize    ( m0_axi_awsize    ) ,
  .m0_axi_awburst   ( m0_axi_awburst   ) ,
  .m0_axi_awuser    ( m0_axi_awuser    ) ,
  .m0_axi_awvalid   ( m0_axi_awvalid   ) ,
  .m0_axi_awready   ( m0_axi_awready   ) ,
  .m0_axi_awregion  ( m0_axi_awregion  ) , // Unused
  .m0_axi_awlock    ( m0_axi_awlock    ) , // Unused
  .m0_axi_awcache   ( m0_axi_awcache   ) , // Unused
  .m0_axi_awprot    ( m0_axi_awprot    ) , // Unused
  .m0_axi_awqos     ( m0_axi_awqos     ) , // Unused
  .m0_axi_wdata     ( m0_axi_wdata     ) , // wr data
  .m0_axi_wstrb     ( m0_axi_wstrb     ) ,
  .m0_axi_wlast     ( m0_axi_wlast     ) ,
  .m0_axi_wuser     ( m0_axi_wuser     ) ,
  .m0_axi_wvalid    ( m0_axi_wvalid    ) ,
  .m0_axi_wready    ( m0_axi_wready    ) ,
  .m0_axi_bid       ( m0_axi_bid       ) , // wr res
  .m0_axi_bresp     ( m0_axi_bresp     ) ,
  .m0_axi_buser     ( m0_axi_buser     ) ,
  .m0_axi_bvalid    ( m0_axi_bvalid    ) ,
  .m0_axi_bready    ( m0_axi_bready    ) ,
  .m0_axi_arid      ( m0_axi_arid      ) , // rd addr
  .m0_axi_araddr    ( m0_axi_araddr    ) ,
  .m0_axi_arlen     ( m0_axi_arlen     ) ,
  .m0_axi_arsize    ( m0_axi_arsize    ) ,
  .m0_axi_arburst   ( m0_axi_arburst   ) ,
  .m0_axi_aruser    ( m0_axi_aruser    ) ,
  .m0_axi_arvalid   ( m0_axi_arvalid   ) ,
  .m0_axi_arready   ( m0_axi_arready   ) ,
  .m0_axi_arregion  ( m0_axi_arregion  ) , // Unused
  .m0_axi_arlock    ( m0_axi_arlock    ) , // Unused
  .m0_axi_arcache   ( m0_axi_arcache   ) , // Unused
  .m0_axi_arprot    ( m0_axi_arprot    ) , // Unused
  .m0_axi_arqos     ( m0_axi_arqos     ) , // Unused
  .m0_axi_rid       ( m0_axi_rid       ) , // rd data
  .m0_axi_rdata     ( m0_axi_rdata     ) ,
  .m0_axi_rresp     ( m0_axi_rresp     ) ,
  .m0_axi_rlast     ( m0_axi_rlast     ) ,
  .m0_axi_ruser     ( m0_axi_ruser     ) ,
  .m0_axi_rvalid    ( m0_axi_rvalid    ) ,
  .m0_axi_rready    ( m0_axi_rready    ) , 
  .m1_axi_aclk      ( m1_axi_aclk      ) , // Not used
  .m1_axi_aresetn   ( m1_axi_aresetn   ) , // Not used
  .m1_axi_awid      ( m1_axi_awid      ) , // wr addr
  .m1_axi_awaddr    ( m1_axi_awaddr    ) ,   
  .m1_axi_awlen     ( m1_axi_awlen     ) ,
  .m1_axi_awsize    ( m1_axi_awsize    ) ,
  .m1_axi_awburst   ( m1_axi_awburst   ) ,
  .m1_axi_awuser    ( m1_axi_awuser    ) ,
  .m1_axi_awvalid   ( m1_axi_awvalid   ) ,
  .m1_axi_awready   ( m1_axi_awready   ) ,
  .m1_axi_awregion  ( m1_axi_awregion  ) , // Unused
  .m1_axi_awlock    ( m1_axi_awlock    ) , // Unused
  .m1_axi_awcache   ( m1_axi_awcache   ) , // Unused
  .m1_axi_awprot    ( m1_axi_awprot    ) , // Unused
  .m1_axi_awqos     ( m1_axi_awqos     ) , // Unused
  .m1_axi_wdata     ( m1_axi_wdata     ) , // wr data
  .m1_axi_wstrb     ( m1_axi_wstrb     ) ,
  .m1_axi_wlast     ( m1_axi_wlast     ) ,
  .m1_axi_wuser     ( m1_axi_wuser     ) ,
  .m1_axi_wvalid    ( m1_axi_wvalid    ) ,
  .m1_axi_wready    ( m1_axi_wready    ) ,
  .m1_axi_bid       ( m1_axi_bid       ) , // wr res
  .m1_axi_bresp     ( m1_axi_bresp     ) ,
  .m1_axi_buser     ( m1_axi_buser     ) ,
  .m1_axi_bvalid    ( m1_axi_bvalid    ) ,
  .m1_axi_bready    ( m1_axi_bready    ) ,
  .m1_axi_arid      ( m1_axi_arid      ) , // rd addr
  .m1_axi_araddr    ( m1_axi_araddr    ) ,
  .m1_axi_arlen     ( m1_axi_arlen     ) ,
  .m1_axi_arsize    ( m1_axi_arsize    ) ,
  .m1_axi_arburst   ( m1_axi_arburst   ) ,
  .m1_axi_aruser    ( m1_axi_aruser    ) ,
  .m1_axi_arvalid   ( m1_axi_arvalid   ) ,
  .m1_axi_arready   ( m1_axi_arready   ) ,
  .m1_axi_arregion  ( m1_axi_arregion  ) , // Unused
  .m1_axi_arlock    ( m1_axi_arlock    ) , // Unused
  .m1_axi_arcache   ( m1_axi_arcache   ) , // Unused
  .m1_axi_arprot    ( m1_axi_arprot    ) , // Unused
  .m1_axi_arqos     ( m1_axi_arqos     ) , // Unused
  .m1_axi_rid       ( m1_axi_rid       ) , // rd data
  .m1_axi_rdata     ( m1_axi_rdata     ) ,
  .m1_axi_rresp     ( m1_axi_rresp     ) ,
  .m1_axi_rlast     ( m1_axi_rlast     ) ,
  .m1_axi_ruser     ( m1_axi_ruser     ) ,
  .m1_axi_rvalid    ( m1_axi_rvalid    ) ,
  .m1_axi_rready    ( m1_axi_rready    ) , 
  .m2_axi_aclk      ( m2_axi_aclk      ) , // Not used
  .m2_axi_aresetn   ( m2_axi_aresetn   ) , // Not used
  .m2_axi_awid      ( m2_axi_awid      ) , // wr addr
  .m2_axi_awaddr    ( m2_axi_awaddr    ) ,   
  .m2_axi_awlen     ( m2_axi_awlen     ) ,
  .m2_axi_awsize    ( m2_axi_awsize    ) ,
  .m2_axi_awburst   ( m2_axi_awburst   ) ,
  .m2_axi_awuser    ( m2_axi_awuser    ) ,
  .m2_axi_awvalid   ( m2_axi_awvalid   ) ,
  .m2_axi_awready   ( m2_axi_awready   ) ,
  .m2_axi_awregion  ( m2_axi_awregion  ) , // Unused
  .m2_axi_awlock    ( m2_axi_awlock    ) , // Unused
  .m2_axi_awcache   ( m2_axi_awcache   ) , // Unused
  .m2_axi_awprot    ( m2_axi_awprot    ) , // Unused
  .m2_axi_awqos     ( m2_axi_awqos     ) , // Unused
  .m2_axi_wdata     ( m2_axi_wdata     ) , // wr data
  .m2_axi_wstrb     ( m2_axi_wstrb     ) ,
  .m2_axi_wlast     ( m2_axi_wlast     ) ,
  .m2_axi_wuser     ( m2_axi_wuser     ) ,
  .m2_axi_wvalid    ( m2_axi_wvalid    ) ,
  .m2_axi_wready    ( m2_axi_wready    ) ,
  .m2_axi_bid       ( m2_axi_bid       ) , // wr res
  .m2_axi_bresp     ( m2_axi_bresp     ) ,
  .m2_axi_buser     ( m2_axi_buser     ) ,
  .m2_axi_bvalid    ( m2_axi_bvalid    ) ,
  .m2_axi_bready    ( m2_axi_bready    ) ,
  .m2_axi_arid      ( m2_axi_arid      ) , // rd addr
  .m2_axi_araddr    ( m2_axi_araddr    ) ,
  .m2_axi_arlen     ( m2_axi_arlen     ) ,
  .m2_axi_arsize    ( m2_axi_arsize    ) ,
  .m2_axi_arburst   ( m2_axi_arburst   ) ,
  .m2_axi_aruser    ( m2_axi_aruser    ) ,
  .m2_axi_arvalid   ( m2_axi_arvalid   ) ,
  .m2_axi_arready   ( m2_axi_arready   ) ,
  .m2_axi_arregion  ( m2_axi_arregion  ) , // Unused
  .m2_axi_arlock    ( m2_axi_arlock    ) , // Unused
  .m2_axi_arcache   ( m2_axi_arcache   ) , // Unused
  .m2_axi_arprot    ( m2_axi_arprot    ) , // Unused
  .m2_axi_arqos     ( m2_axi_arqos     ) , // Unused
  .m2_axi_rid       ( m2_axi_rid       ) , // rd data
  .m2_axi_rdata     ( m2_axi_rdata     ) ,
  .m2_axi_rresp     ( m2_axi_rresp     ) ,
  .m2_axi_rlast     ( m2_axi_rlast     ) ,
  .m2_axi_ruser     ( m2_axi_ruser     ) ,
  .m2_axi_rvalid    ( m2_axi_rvalid    ) ,
  .m2_axi_rready    ( m2_axi_rready    ) ,
  .cq_cc_fifo_werr  ( cq_cc_fifo_werr  )

) ;


rqrc_intf #(
	.S_AXI_ID_W	  ( C_S_AXI_ID_W	 ) , // Slave      
	.S_AXI_ADDR_W   ( C_S_AXI_ADDR_W   ) ,             
	.S_AXI_DATA_W   ( C_S_AXI_DATA_W   ) ,             
    .S_BASE_ADDR	  ( C_S_BASE_ADDR	 )
) rqrc_intf_inst (  
  .user_clk         ( user_clk         ) , // input    
  .user_reset       ( user_reset       ) , // input 
  .s_axis_rq_tdata  ( s_axis_rq_tdata  ) , // output [255 : 0] 
  .s_axis_rq_tkeep  ( s_axis_rq_tkeep  ) , // output [7   : 0] 
  .s_axis_rq_tlast  ( s_axis_rq_tlast  ) , // output           
  .s_axis_rq_tready ( s_axis_rq_tready ) , // input  
  .s_axis_rq_tuser  ( s_axis_rq_tuser  ) , // output [59  : 0] 
  .s_axis_rq_tvalid ( s_axis_rq_tvalid ) , // output           
  .m_axis_rc_tdata  ( m_axis_rc_tdata  ) , // input  [255 : 0] 
  .m_axis_rc_tkeep  ( m_axis_rc_tkeep  ) , // input  [7   : 0] 
  .m_axis_rc_tlast  ( m_axis_rc_tlast  ) , // input            
  .m_axis_rc_tready ( m_axis_rc_tready ) , // output           
  .m_axis_rc_tuser  ( m_axis_rc_tuser  ) , // input  [74  : 0] 
  .m_axis_rc_tvalid ( m_axis_rc_tvalid ) , // input 
  // .wdma_error       ( wdma_error       ) , // output 
  // .rdma_error       ( rdma_error       ) , // output
  .s_axi_aclk       ( s_axi_aclk       ) , // Unused    // s_axi_aclk     , //
  .s_axi_aresetn    ( s_axi_aresetn    ) , // Unused    // s_axi_aresetn  , //
  .s_axi_awid       ( s_axi_awid       ) , // wr addr   // s_axi_awid     , //
  .s_axi_awaddr     ( s_axi_awaddr     ) ,              // s_axi_awaddr   ,
  .s_axi_awlen      ( s_axi_awlen      ) ,              // s_axi_awlen    ,
  .s_axi_awsize     ( s_axi_awsize     ) ,              // s_axi_awsize   ,
  .s_axi_awburst    ( s_axi_awburst    ) ,              // s_axi_awburst  ,
  .s_axi_awregion   ( s_axi_awregion   ) , // Unused    // s_axi_awregion , //
  .s_axi_awlock     ( s_axi_awlock     ) , // Unused    // s_axi_awlock   , //
  .s_axi_awcache    ( s_axi_awcache    ) , // Unused    // s_axi_awcache  , //
  .s_axi_awprot     ( s_axi_awprot     ) , // Unused    // s_axi_awprot   , //
  .s_axi_awqos      ( s_axi_awqos      ) , // Unused    // s_axi_awqos    , //
  // .s_axi_awuser     ( s_axi_awuser     ) ,              // s_axi_awvalid  ,
  .s_axi_awvalid    ( s_axi_awvalid    ) ,              // s_axi_awready  ,
  .s_axi_awready    ( s_axi_awready    ) ,              // s_axi_wdata    , //
  .s_axi_wdata      ( s_axi_wdata      ) , // wr data   // s_axi_wstrb    ,
  .s_axi_wstrb      ( s_axi_wstrb      ) ,              // s_axi_wlast    ,
  .s_axi_wlast      ( s_axi_wlast      ) ,              // s_axi_wvalid   ,
  // .s_axi_wuser      ( s_axi_wuser      ) ,              // s_axi_wready   ,
  .s_axi_wvalid     ( s_axi_wvalid     ) ,              // s_axi_bid      , //
  .s_axi_wready     ( s_axi_wready     ) ,              // s_axi_bresp    ,
  .s_axi_bid        ( s_axi_bid        ) , // wr res    // s_axi_bvalid   ,
  .s_axi_bresp      ( s_axi_bresp      ) ,              // s_axi_bready   ,
  // .s_axi_buser      ( s_axi_buser      ) ,              // s_axi_arid     , //
  .s_axi_bvalid     ( s_axi_bvalid     ) ,              // s_axi_araddr   ,
  .s_axi_bready     ( s_axi_bready     ) ,              // s_axi_arlen    ,
  .s_axi_arid       ( s_axi_arid       ) , // rd addr   // s_axi_arsize   ,
  .s_axi_araddr     ( s_axi_araddr     ) ,              // s_axi_arburst  ,
  .s_axi_arlen      ( s_axi_arlen      ) ,              // s_axi_arregion , //
  .s_axi_arsize     ( s_axi_arsize     ) ,              // s_axi_arlock   , //
  .s_axi_arburst    ( s_axi_arburst    ) ,              // s_axi_arcache  , //
  .s_axi_arregion   ( s_axi_arregion   ) , // Unused    // s_axi_arprot   , //
  .s_axi_arlock     ( s_axi_arlock     ) , // Unused    // s_axi_arqos    , //
  .s_axi_arcache    ( s_axi_arcache    ) , // Unused    // s_axi_arvalid  ,
  .s_axi_arprot     ( s_axi_arprot     ) , // Unused    // s_axi_arready  ,
  .s_axi_arqos      ( s_axi_arqos      ) , // Unused    // s_axi_rid      , //
  // .s_axi_aruser     ( s_axi_aruser     ) ,              // s_axi_rdata    ,
  .s_axi_arvalid    ( s_axi_arvalid    ) ,              // s_axi_rresp    ,
  .s_axi_arready    ( s_axi_arready    ) ,              // s_axi_rlast    ,
  .s_axi_rid        ( s_axi_rid        ) , // rd data   // s_axi_rvalid   ,
  .s_axi_rdata      ( s_axi_rdata      ) ,              // s_axi_rready   ,
  .s_axi_rresp      ( s_axi_rresp      ) ,              //
  .s_axi_rlast      ( s_axi_rlast      ) ,              //
  // .s_axi_ruser      ( s_axi_ruser      ) ,              //
  .s_axi_rvalid     ( s_axi_rvalid     ) ,              //
  .s_axi_rready     ( s_axi_rready     )                //
      
) ;


endmodule
