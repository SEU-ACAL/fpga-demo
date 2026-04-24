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
// 

`timescale 1ns/1ps

module cqcc_intf #(
    parameter         DEBUG_ON          = "FALSE"                    , // "FALSE" or "TRUE"
    
    parameter integer BAR_NUM_M1        = 2                          , // BAR number minus one

	parameter integer C_M0_AXI_ID_W	    = 1                          , // Master-0, for mmr
	parameter integer C_M0_AXI_ADDR_W	= 12                         ,
	parameter integer C_M0_AXI_DATA_W	= 32                         ,
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
    parameter         C_M2_BASE_ADDR	= {{C_M2_AXI_ADDR_W}{1'b0}}  

)(
  // clock and reset
  input            user_clk                        , // input    
  input            user_reset                      , // input 
  input            soft_rstp                       , // input
  // Configuration status
  input  [1   : 0] cfg_max_payload                 , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  input  [2   : 0] cfg_max_read_req                , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  input            cfg_rcb_status                  , // input            1 - 128B; 0 - 64B
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
  // for status counter
  output           cc_tlp_vld                      , // output
  output           cc_tlp_invld                    , // output 
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
  output [127                 : 0] cq_cc_fifo_werr

) ;

logic                  cq_des_fifo_empty   ;
logic [135        : 0] cq_des_fifo_rdata   ; // {tuser[7:0], data[127:0]}
logic [BAR_NUM_M1 : 0] cq_des_fifo_rd      ; // psfifo read is logic OR of every BAR channel's read
logic                  cq_data_fifo_empty  ;
logic [291        : 0] cq_data_fifo_rdata  ; // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
logic [BAR_NUM_M1 : 0] cq_data_fifo_rd     ; // psfifo read is logic OR of every BAR channel's read

logic                  cc_tlp_fifo_req[0:BAR_NUM_M1]    ; // request when stored the whole TLP
logic                  cc_tlp_fifo_empty[0:BAR_NUM_M1]  ;
logic                  cc_tlp_fifo_rd[0:BAR_NUM_M1]     ;
logic [266        : 0] cc_tlp_fifo_rdata[0:BAR_NUM_M1]  ;

logic [7          : 0] bar_fifo_werr[0:BAR_NUM_M1];

cq_intf #(
    .DEBUG_ON  ( DEBUG_ON   ) ,
    .BAR_NUM_M1( BAR_NUM_M1 )
)cq(
  .user_clk           ( user_clk           ) , // input    
  .user_reset         ( user_reset         ) , // input 
  .m_axis_cq_tdata    ( m_axis_cq_tdata    ) , // input  [255 : 0] 
  .m_axis_cq_tkeep    ( m_axis_cq_tkeep    ) , // input  [7   : 0] 
  .m_axis_cq_tlast    ( m_axis_cq_tlast    ) , // input            
  .m_axis_cq_tready   ( m_axis_cq_tready   ) , // output           
  .m_axis_cq_tuser    ( m_axis_cq_tuser    ) , // input  [41  : 0] 
  .m_axis_cq_tvalid   ( m_axis_cq_tvalid   ) , // input  
  .cq_des_fifo_empty  ( cq_des_fifo_empty  ) ,
  .cq_des_fifo_rdata  ( cq_des_fifo_rdata  ) , // {tuser[7:0], data[127:0]}
  .cq_des_fifo_rd     ( cq_des_fifo_rd     ) , // psfifo read is logic OR of every BAR channel's read
  .cq_data_fifo_empty ( cq_data_fifo_empty ) ,
  .cq_data_fifo_rdata ( cq_data_fifo_rdata ) , // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
  .cq_data_fifo_rd    ( cq_data_fifo_rd    )   // psfifo read is logic OR of every BAR channel's read
) ;

cc_intf #(
    .DEBUG_ON  ( DEBUG_ON   ) ,
    .BAR_NUM_M1( BAR_NUM_M1 )
)cc(
  .user_clk              ( user_clk             ) , // input    
  .user_reset            ( user_reset           ) , // input 
  .soft_rstp             ( soft_rstp            ) , // input
  .s_axis_cc_tdata       ( s_axis_cc_tdata      ) , // output [255 : 0] 
  .s_axis_cc_tkeep       ( s_axis_cc_tkeep      ) , // output [7   : 0] 
  .s_axis_cc_tlast       ( s_axis_cc_tlast      ) , // output           
  .s_axis_cc_tready      ( s_axis_cc_tready     ) , // input  
  .s_axis_cc_tuser       ( s_axis_cc_tuser      ) , // output [32  : 0] 
  .s_axis_cc_tvalid      ( s_axis_cc_tvalid     ) , // output  
  .cc_tlp_vld            ( cc_tlp_vld           ) , // output
  .cc_tlp_invld          ( cc_tlp_invld         ) , // output
  .cc_tlp_fifo_req       ( cc_tlp_fifo_req      ) ,
  .cc_tlp_fifo_empty     ( cc_tlp_fifo_empty    ) , 
  .cc_tlp_fifo_rd        ( cc_tlp_fifo_rd       ) ,
  .cc_tlp_fifo_rdata     ( cc_tlp_fifo_rdata    ) 
) ;

// BAR 0 channel, for register access
cqcc_tlp_proc #(
    .DEBUG_ON         ( DEBUG_ON          ) , 
    .BAR_ID           ( 0                 ) ,
    .SUB_BAR_L        ( 0                 ) ,
    .SUB_BAR_H        ( 0                 ) ,
	.C_M_AXI_ID_W	  ( C_M0_AXI_ID_W	  ) ,
	.C_M_AXI_ADDR_W   ( C_M0_AXI_ADDR_W   ) ,
	.C_M_AXI_DATA_W   ( C_M0_AXI_DATA_W   ) ,
	.C_M_AXI_AWUSER_W ( C_M0_AXI_AWUSER_W ) ,
	.C_M_AXI_WUSER_W  ( C_M0_AXI_WUSER_W  ) ,
	.C_M_AXI_ARUSER_W ( C_M0_AXI_ARUSER_W ) ,
	.C_M_AXI_RUSER_W  ( C_M0_AXI_RUSER_W  ) ,
	.C_M_AXI_BUSER_W  ( C_M0_AXI_BUSER_W  ) ,
    .C_M_BASE_ADDR	  ( C_M0_BASE_ADDR	  )
) tlp_proc_bar_0 (
  .user_clk              ( user_clk              ) , // input    
  .user_reset            ( user_reset            ) , // input 
  .cfg_max_payload       ( cfg_max_payload       ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  .cfg_max_read_req      ( cfg_max_read_req      ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  .cfg_rcb_status        ( cfg_rcb_status        ) , // input
  .cq_des_fifo_empty     ( cq_des_fifo_empty     ) ,
  .cq_des_fifo_rdata     ( cq_des_fifo_rdata     ) , // {tuser[7:0], data[127:0]}  
  .cq_data_fifo_empty    ( cq_data_fifo_empty    ) ,
  .cq_data_fifo_rdata    ( cq_data_fifo_rdata    ) , // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
  .cq_des_fifo_rd        ( cq_des_fifo_rd   [0]  ) , // psfifo read is logic OR of every BAR channel's read
  .cq_data_fifo_rd       ( cq_data_fifo_rd  [0]  ) , // psfifo read is logic OR of every BAR channel's read
  .cc_tlp_fifo_req       ( cc_tlp_fifo_req  [0]  ) , // request when stored the whole TLP
  .cc_tlp_fifo_empty     ( cc_tlp_fifo_empty[0]  ) ,
  .cc_tlp_fifo_rd        ( cc_tlp_fifo_rd   [0]  ) ,
  .cc_tlp_fifo_rdata     ( cc_tlp_fifo_rdata[0]  ) , 
  .m_axi_aclk            ( m0_axi_aclk           ) , // Not used
  .m_axi_aresetn         ( m0_axi_aresetn        ) , // Not used
  .m_axi_awid            ( m0_axi_awid           ) , // wr addr
  .m_axi_awaddr          ( m0_axi_awaddr         ) ,   
  .m_axi_awlen           ( m0_axi_awlen          ) ,
  .m_axi_awsize          ( m0_axi_awsize         ) ,
  .m_axi_awburst         ( m0_axi_awburst        ) ,
  .m_axi_awuser          ( m0_axi_awuser         ) ,
  .m_axi_awvalid         ( m0_axi_awvalid        ) ,
  .m_axi_awready         ( m0_axi_awready        ) ,
  .m_axi_awregion        ( m0_axi_awregion       ) , // Unused
  .m_axi_awlock          ( m0_axi_awlock         ) , // Unused
  .m_axi_awcache         ( m0_axi_awcache        ) , // Unused
  .m_axi_awprot          ( m0_axi_awprot         ) , // Unused
  .m_axi_awqos           ( m0_axi_awqos          ) , // Unused
  .m_axi_wdata           ( m0_axi_wdata          ) , // wr data
  .m_axi_wstrb           ( m0_axi_wstrb          ) ,
  .m_axi_wlast           ( m0_axi_wlast          ) ,
  .m_axi_wuser           ( m0_axi_wuser          ) ,
  .m_axi_wvalid          ( m0_axi_wvalid         ) ,
  .m_axi_wready          ( m0_axi_wready         ) ,
  .m_axi_bid             ( m0_axi_bid            ) , // wr res
  .m_axi_bresp           ( m0_axi_bresp          ) ,
  .m_axi_buser           ( m0_axi_buser          ) ,
  .m_axi_bvalid          ( m0_axi_bvalid         ) ,
  .m_axi_bready          ( m0_axi_bready         ) ,
  .m_axi_arid            ( m0_axi_arid           ) , // rd addr
  .m_axi_araddr          ( m0_axi_araddr         ) ,
  .m_axi_arlen           ( m0_axi_arlen          ) ,
  .m_axi_arsize          ( m0_axi_arsize         ) ,
  .m_axi_arburst         ( m0_axi_arburst        ) ,
  .m_axi_aruser          ( m0_axi_aruser         ) ,
  .m_axi_arvalid         ( m0_axi_arvalid        ) ,
  .m_axi_arready         ( m0_axi_arready        ) ,
  .m_axi_arregion        ( m0_axi_arregion       ) , // Unused
  .m_axi_arlock          ( m0_axi_arlock         ) , // Unused
  .m_axi_arcache         ( m0_axi_arcache        ) , // Unused
  .m_axi_arprot          ( m0_axi_arprot         ) , // Unused
  .m_axi_arqos           ( m0_axi_arqos          ) , // Unused
  .m_axi_rid             ( m0_axi_rid            ) , // rd data
  .m_axi_rdata           ( m0_axi_rdata          ) ,
  .m_axi_rresp           ( m0_axi_rresp          ) ,
  .m_axi_rlast           ( m0_axi_rlast          ) ,
  .m_axi_ruser           ( m0_axi_ruser          ) ,
  .m_axi_rvalid          ( m0_axi_rvalid         ) ,
  .m_axi_rready          ( m0_axi_rready         ) ,
  .fifo_werr             ( bar_fifo_werr[0]      ) 
) ;

// BAR 1 channel, for local memory-1 access
cqcc_tlp_proc #(
    .DEBUG_ON         ( DEBUG_ON          ) , 
    .BAR_ID           ( 2                 ) ,
    .SUB_BAR_L        ( 0                 ) ,
    .SUB_BAR_H        ( 0                 ) ,
	.C_M_AXI_ID_W	  ( C_M1_AXI_ID_W	  ) ,
	.C_M_AXI_ADDR_W   ( C_M1_AXI_ADDR_W   ) ,
	.C_M_AXI_DATA_W   ( C_M1_AXI_DATA_W   ) ,
	.C_M_AXI_AWUSER_W ( C_M1_AXI_AWUSER_W ) ,
	.C_M_AXI_WUSER_W  ( C_M1_AXI_WUSER_W  ) ,
	.C_M_AXI_ARUSER_W ( C_M1_AXI_ARUSER_W ) ,
	.C_M_AXI_RUSER_W  ( C_M1_AXI_RUSER_W  ) ,
	.C_M_AXI_BUSER_W  ( C_M1_AXI_BUSER_W  ) ,
    .C_M_BASE_ADDR	  ( C_M1_BASE_ADDR	  )
) tlp_proc_bar_1 (
  .user_clk              ( user_clk              ) , // input    
  .user_reset            ( user_reset            ) , // input 
  .cfg_max_payload       ( cfg_max_payload       ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  .cfg_max_read_req      ( cfg_max_read_req      ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  .cfg_rcb_status        ( cfg_rcb_status        ) , // input
  .cq_des_fifo_empty     ( cq_des_fifo_empty     ) ,
  .cq_des_fifo_rdata     ( cq_des_fifo_rdata     ) , // {tuser[7:0], data[127:0]}  
  .cq_data_fifo_empty    ( cq_data_fifo_empty    ) ,
  .cq_data_fifo_rdata    ( cq_data_fifo_rdata    ) , // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
  .cq_des_fifo_rd        ( cq_des_fifo_rd   [1]  ) , // psfifo read is logic OR of every BAR channel's read
  .cq_data_fifo_rd       ( cq_data_fifo_rd  [1]  ) , // psfifo read is logic OR of every BAR channel's read
  .cc_tlp_fifo_req       ( cc_tlp_fifo_req  [1]  ) , // request when stored the whole TLP
  .cc_tlp_fifo_empty     ( cc_tlp_fifo_empty[1]  ) ,
  .cc_tlp_fifo_rd        ( cc_tlp_fifo_rd   [1]  ) ,
  .cc_tlp_fifo_rdata     ( cc_tlp_fifo_rdata[1]  ) , 
  .m_axi_aclk            ( m1_axi_aclk           ) , // Not used
  .m_axi_aresetn         ( m1_axi_aresetn        ) , // Not used
  .m_axi_awid            ( m1_axi_awid           ) , // wr addr
  .m_axi_awaddr          ( m1_axi_awaddr         ) ,   
  .m_axi_awlen           ( m1_axi_awlen          ) ,
  .m_axi_awsize          ( m1_axi_awsize         ) ,
  .m_axi_awburst         ( m1_axi_awburst        ) ,
  .m_axi_awuser          ( m1_axi_awuser         ) ,
  .m_axi_awvalid         ( m1_axi_awvalid        ) ,
  .m_axi_awready         ( m1_axi_awready        ) ,
  .m_axi_awregion        ( m1_axi_awregion       ) , // Unused
  .m_axi_awlock          ( m1_axi_awlock         ) , // Unused
  .m_axi_awcache         ( m1_axi_awcache        ) , // Unused
  .m_axi_awprot          ( m1_axi_awprot         ) , // Unused
  .m_axi_awqos           ( m1_axi_awqos          ) , // Unused
  .m_axi_wdata           ( m1_axi_wdata          ) , // wr data
  .m_axi_wstrb           ( m1_axi_wstrb          ) ,
  .m_axi_wlast           ( m1_axi_wlast          ) ,
  .m_axi_wuser           ( m1_axi_wuser          ) ,
  .m_axi_wvalid          ( m1_axi_wvalid         ) ,
  .m_axi_wready          ( m1_axi_wready         ) ,
  .m_axi_bid             ( m1_axi_bid            ) , // wr res
  .m_axi_bresp           ( m1_axi_bresp          ) ,
  .m_axi_buser           ( m1_axi_buser          ) ,
  .m_axi_bvalid          ( m1_axi_bvalid         ) ,
  .m_axi_bready          ( m1_axi_bready         ) ,
  .m_axi_arid            ( m1_axi_arid           ) , // rd addr
  .m_axi_araddr          ( m1_axi_araddr         ) ,
  .m_axi_arlen           ( m1_axi_arlen          ) ,
  .m_axi_arsize          ( m1_axi_arsize         ) ,
  .m_axi_arburst         ( m1_axi_arburst        ) ,
  .m_axi_aruser          ( m1_axi_aruser         ) ,
  .m_axi_arvalid         ( m1_axi_arvalid        ) ,
  .m_axi_arready         ( m1_axi_arready        ) ,
  .m_axi_arregion        ( m1_axi_arregion       ) , // Unused
  .m_axi_arlock          ( m1_axi_arlock         ) , // Unused
  .m_axi_arcache         ( m1_axi_arcache        ) , // Unused
  .m_axi_arprot          ( m1_axi_arprot         ) , // Unused
  .m_axi_arqos           ( m1_axi_arqos          ) , // Unused
  .m_axi_rid             ( m1_axi_rid            ) , // rd data
  .m_axi_rdata           ( m1_axi_rdata          ) ,
  .m_axi_rresp           ( m1_axi_rresp          ) ,
  .m_axi_rlast           ( m1_axi_rlast          ) ,
  .m_axi_ruser           ( m1_axi_ruser          ) ,
  .m_axi_rvalid          ( m1_axi_rvalid         ) ,
  .m_axi_rready          ( m1_axi_rready         ) ,
  .fifo_werr             ( bar_fifo_werr[1]      )   
) ;

// BAR 2 channel, for local memory-2 access
cqcc_tlp_proc #(
    .DEBUG_ON         ( DEBUG_ON          ) , 
    .BAR_ID           ( 4                 ) ,
    .SUB_BAR_L        ( 0                 ) ,
    .SUB_BAR_H        ( 0                 ) ,
	.C_M_AXI_ID_W	  ( C_M2_AXI_ID_W	  ) ,
	.C_M_AXI_ADDR_W   ( C_M2_AXI_ADDR_W   ) ,
	.C_M_AXI_DATA_W   ( C_M2_AXI_DATA_W   ) ,
	.C_M_AXI_AWUSER_W ( C_M2_AXI_AWUSER_W ) ,
	.C_M_AXI_WUSER_W  ( C_M2_AXI_WUSER_W  ) ,
	.C_M_AXI_ARUSER_W ( C_M2_AXI_ARUSER_W ) ,
	.C_M_AXI_RUSER_W  ( C_M2_AXI_RUSER_W  ) ,
	.C_M_AXI_BUSER_W  ( C_M2_AXI_BUSER_W  ) ,
    .C_M_BASE_ADDR	  ( C_M2_BASE_ADDR	  )
) tlp_proc_bar_2 (
  .user_clk              ( user_clk              ) , // input    
  .user_reset            ( user_reset            ) , // input 
  .cfg_max_payload       ( cfg_max_payload       ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  .cfg_max_read_req      ( cfg_max_read_req      ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  .cfg_rcb_status        ( cfg_rcb_status        ) , // input
  .cq_des_fifo_empty     ( cq_des_fifo_empty     ) ,
  .cq_des_fifo_rdata     ( cq_des_fifo_rdata     ) , // {tuser[7:0], data[127:0]}  
  .cq_data_fifo_empty    ( cq_data_fifo_empty    ) ,
  .cq_data_fifo_rdata    ( cq_data_fifo_rdata    ) , // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
  .cq_des_fifo_rd        ( cq_des_fifo_rd   [2]  ) , // psfifo read is logic OR of every BAR channel's read
  .cq_data_fifo_rd       ( cq_data_fifo_rd  [2]  ) , // psfifo read is logic OR of every BAR channel's read
  .cc_tlp_fifo_req       ( cc_tlp_fifo_req  [2]  ) , // request when stored the whole TLP
  .cc_tlp_fifo_empty     ( cc_tlp_fifo_empty[2]  ) ,
  .cc_tlp_fifo_rd        ( cc_tlp_fifo_rd   [2]  ) ,
  .cc_tlp_fifo_rdata     ( cc_tlp_fifo_rdata[2]  ) ,
  .m_axi_aclk            ( m2_axi_aclk           ) , // Not used
  .m_axi_aresetn         ( m2_axi_aresetn        ) , // Not used
  .m_axi_awid            ( m2_axi_awid           ) , // wr addr
  .m_axi_awaddr          ( m2_axi_awaddr         ) ,   
  .m_axi_awlen           ( m2_axi_awlen          ) ,
  .m_axi_awsize          ( m2_axi_awsize         ) ,
  .m_axi_awburst         ( m2_axi_awburst        ) ,
  .m_axi_awuser          ( m2_axi_awuser         ) ,
  .m_axi_awvalid         ( m2_axi_awvalid        ) ,
  .m_axi_awready         ( m2_axi_awready        ) ,
  .m_axi_awregion        ( m2_axi_awregion       ) , // Unused
  .m_axi_awlock          ( m2_axi_awlock         ) , // Unused
  .m_axi_awcache         ( m2_axi_awcache        ) , // Unused
  .m_axi_awprot          ( m2_axi_awprot         ) , // Unused
  .m_axi_awqos           ( m2_axi_awqos          ) , // Unused
  .m_axi_wdata           ( m2_axi_wdata          ) , // wr data
  .m_axi_wstrb           ( m2_axi_wstrb          ) ,
  .m_axi_wlast           ( m2_axi_wlast          ) ,
  .m_axi_wuser           ( m2_axi_wuser          ) ,
  .m_axi_wvalid          ( m2_axi_wvalid         ) ,
  .m_axi_wready          ( m2_axi_wready         ) ,
  .m_axi_bid             ( m2_axi_bid            ) , // wr res
  .m_axi_bresp           ( m2_axi_bresp          ) ,
  .m_axi_buser           ( m2_axi_buser          ) ,
  .m_axi_bvalid          ( m2_axi_bvalid         ) ,
  .m_axi_bready          ( m2_axi_bready         ) ,
  .m_axi_arid            ( m2_axi_arid           ) , // rd addr
  .m_axi_araddr          ( m2_axi_araddr         ) ,
  .m_axi_arlen           ( m2_axi_arlen          ) ,
  .m_axi_arsize          ( m2_axi_arsize         ) ,
  .m_axi_arburst         ( m2_axi_arburst        ) ,
  .m_axi_aruser          ( m2_axi_aruser         ) ,
  .m_axi_arvalid         ( m2_axi_arvalid        ) ,
  .m_axi_arready         ( m2_axi_arready        ) ,
  .m_axi_arregion        ( m2_axi_arregion       ) , // Unused
  .m_axi_arlock          ( m2_axi_arlock         ) , // Unused
  .m_axi_arcache         ( m2_axi_arcache        ) , // Unused
  .m_axi_arprot          ( m2_axi_arprot         ) , // Unused
  .m_axi_arqos           ( m2_axi_arqos          ) , // Unused
  .m_axi_rid             ( m2_axi_rid            ) , // rd data
  .m_axi_rdata           ( m2_axi_rdata          ) ,
  .m_axi_rresp           ( m2_axi_rresp          ) ,
  .m_axi_rlast           ( m2_axi_rlast          ) ,
  .m_axi_ruser           ( m2_axi_ruser          ) ,
  .m_axi_rvalid          ( m2_axi_rvalid         ) ,
  .m_axi_rready          ( m2_axi_rready         ) ,
  .fifo_werr             ( bar_fifo_werr[2]      )      
) ;

assign cq_cc_fifo_werr = {104'b0,
                          bar_fifo_werr[0],
                          bar_fifo_werr[1],
                          bar_fifo_werr[2]};


/*
generate if (DEBUG_ON == "TRUE") begin
ila_fifo_status ila_fifo_status_i(
    .clk     ( user_clk                   ) ,
    .probe0  ( bar_fifo_werr[0][3:0]      ) , // [3 : 0]        
    .probe1  ( bar_fifo_werr[1][3:0]      ) , // [3 : 0]      
    .probe2  ( bar_fifo_werr[2][3:0]      )   // [3 : 0]
              
) ;
end endgenerate
*/

endmodule
