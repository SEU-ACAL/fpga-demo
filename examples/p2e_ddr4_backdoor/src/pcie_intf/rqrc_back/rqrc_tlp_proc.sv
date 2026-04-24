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

module rqrc_tlp_proc #(
	parameter integer C_S_AXI_ID_W	   = 1                        , // Slave
	parameter integer C_S_AXI_ADDR_W   = 64                       ,
	parameter integer C_S_AXI_DATA_W   = 256                      ,
	parameter integer C_S_AXI_AWUSER_W = 0                        ,
	parameter integer C_S_AXI_WUSER_W  = 0                        ,
	parameter integer C_S_AXI_ARUSER_W = 0                        ,
	parameter integer C_S_AXI_RUSER_W  = 0                        ,
	parameter integer C_S_AXI_BUSER_W  = 0                        ,
    parameter         C_S_BASE_ADDR	   = {{C_S_AXI_ADDR_W}{1'b0}} 
)(  
  // clock and reset
  input            user_clk                      , // input    
  input            user_reset                    , // input 
  // Connect to rq_intf
  output           wdma_des_fifo_empty           , // write DMA channel descriptor FIFO
  input            wdma_des_fifo_rd              ,
  output [104 : 0] wdma_des_fifo_rdata           , // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
  output           wdma_data_fifo_req            , // write DMA channel data FIFO
  input            wdma_data_fifo_rd             ,
  output [255 : 0] wdma_data_fifo_rdata          ,
  output           rdma_des_fifo_empty           , // read DMA channel descriptor FIFO
  input            rdma_des_fifo_rd              ,
  output [104 : 0] rdma_des_fifo_rdata           , // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
  // Connect to rc_intf
  output           rdma_data_fifo_full           ,
  input            rdma_data_fifo_wr             ,
  input  [289 : 0] rdma_data_fifo_wdata          , // {sop, eop, data, strobe}
  // AXI-MM-slave     
  input                           s_axi_aclk     , // Unused
  input                           s_axi_aresetn  , // Unused
  input  [C_S_AXI_ID_W-1     : 0] s_axi_awid     , // wr addr
  input  [C_S_AXI_ADDR_W-1   : 0] s_axi_awaddr   ,
  input  [7                  : 0] s_axi_awlen    ,
  input  [2                  : 0] s_axi_awsize   ,
  input  [1                  : 0] s_axi_awburst  ,
  input  [3                  : 0] s_axi_awregion , // Unused
  input                           s_axi_awlock   , // Unused
  input  [3                  : 0] s_axi_awcache  , // Unused
  input  [2                  : 0] s_axi_awprot   , // Unused
  input  [3                  : 0] s_axi_awqos    , // Unused
  input  [C_S_AXI_AWUSER_W-1 : 0] s_axi_awuser   , 
  input                           s_axi_awvalid  ,
  output                          s_axi_awready  ,
  input  [C_S_AXI_DATA_W-1   : 0] s_axi_wdata    , // wr data
  input  [C_S_AXI_DATA_W/8-1 : 0] s_axi_wstrb    ,
  input                           s_axi_wlast    ,
  input  [C_S_AXI_WUSER_W-1  : 0] s_axi_wuser    ,
  input                           s_axi_wvalid   ,
  output                          s_axi_wready   ,
  output [C_S_AXI_ID_W-1     : 0] s_axi_bid      , // wr res
  output [1                  : 0] s_axi_bresp    ,
  output [C_S_AXI_BUSER_W-1  : 0] s_axi_buser    ,
  output                          s_axi_bvalid   ,
  input                           s_axi_bready   ,
  input  [C_S_AXI_ID_W-1     : 0] s_axi_arid     , // rd addr
  input  [C_S_AXI_ADDR_W-1   : 0] s_axi_araddr   ,
  input  [7                  : 0] s_axi_arlen    ,
  input  [2                  : 0] s_axi_arsize   ,
  input  [1                  : 0] s_axi_arburst  ,
  input  [3                  : 0] s_axi_arregion , // Unused
  input                           s_axi_arlock   , // Unused
  input  [3                  : 0] s_axi_arcache  , // Unused
  input  [2                  : 0] s_axi_arprot   , // Unused
  input  [3                  : 0] s_axi_arqos    , // Unused
  input  [C_S_AXI_ARUSER_W-1 : 0] s_axi_aruser   ,
  input                           s_axi_arvalid  ,
  output                          s_axi_arready  ,
  output [C_S_AXI_ID_W-1     : 0] s_axi_rid      , // rd data
  output [C_S_AXI_DATA_W-1   : 0] s_axi_rdata    ,
  output [1                  : 0] s_axi_rresp    ,
  output                          s_axi_rlast    ,
  output [C_S_AXI_RUSER_W-1  : 0] s_axi_ruser    ,
  output                          s_axi_rvalid   ,
  input                           s_axi_rready  
      
) ;

assign wdma_des_fifo_empty  = 'b0 ; // write DMA channel descriptor FIFO
assign wdma_des_fifo_rdata  = 'b0 ; // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
assign wdma_data_fifo_req   = 'b0 ; // write DMA channel data FIFO
assign wdma_data_fifo_rdata = 'b0 ;
assign rdma_des_fifo_empty  = 'b0 ; // read DMA channel descriptor FIFO
assign rdma_des_fifo_rdata  = 'b0 ; // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
assign rdma_data_fifo_full  = 'b0 ;
assign s_axi_awready        = 'b0 ;
assign s_axi_wready         = 'b0 ;
assign s_axi_bid            = 'b0 ; // wr res
assign s_axi_bresp          = 'b0 ;
assign s_axi_buser          = 'b0 ;
assign s_axi_bvalid         = 'b0 ;
assign s_axi_arready        = 'b0 ;
assign s_axi_rid            = 'b0 ; // rd data
assign s_axi_rdata          = 'b0 ;
assign s_axi_rresp          = 'b0 ;
assign s_axi_rlast          = 'b0 ;
assign s_axi_ruser          = 'b0 ;
assign s_axi_rvalid         = 'b0 ;


endmodule
