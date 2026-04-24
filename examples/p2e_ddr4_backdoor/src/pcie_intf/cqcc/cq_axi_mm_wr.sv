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

//`include "../../defines_parameters/glbl_param.sv"

module cq_axi_mm_wr #(
    parameter          DEBUG_ON         = "FALSE"                  , // "FALSE" or "TRUE"
    
    parameter integer  BAR_ID           = 0                        ,
    
    parameter [31 : 0] SUB_BAR_L        = 0                        ,
    parameter [31 : 0] SUB_BAR_H        = 0                        ,

	parameter integer  C_M_AXI_ID_W	    = 1                        ,
	parameter integer  C_M_AXI_ADDR_W   = 64                       ,
	parameter integer  C_M_AXI_DATA_W   = 256                      ,
	parameter integer  C_M_AXI_AWUSER_W = 0                        ,
	parameter integer  C_M_AXI_WUSER_W  = 0                        ,
	parameter integer  C_M_AXI_ARUSER_W = 0                        ,
	parameter integer  C_M_AXI_RUSER_W  = 0                        ,
	parameter integer  C_M_AXI_BUSER_W  = 0                        ,
    parameter          C_M_BASE_ADDR	= {{C_M_AXI_ADDR_W}{1'b0}} 

)(
  // clock and reset
  input            user_clk                      , // input    
  input            user_reset                    , // input 
  // Connect to cq_intf 
  (* MARK_DEBUG="true" *)input            cq_des_fifo_empty             ,
  (* MARK_DEBUG="true" *)input  [135 : 0] cq_des_fifo_rdata             , // {tuser[7:0], data[127:0]}
  (* MARK_DEBUG="true" *)output           cq_des_fifo_rd                ,
  (* MARK_DEBUG="true" *)input            cq_data_fifo_empty            ,
  (* MARK_DEBUG="true" *)input  [291 : 0] cq_data_fifo_rdata            , // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
  (* MARK_DEBUG="true" *)output           cq_data_fifo_rd               ,
  // for mmr
  output           cq_local_mem_wr_error         ,
  // Write address and write data channel
  input                           m_axi_aclk     , // Not used
  input                           m_axi_aresetn  , // Not used
  output [C_M_AXI_ID_W-1     : 0] m_axi_awid     , // wr addr
  output [C_M_AXI_ADDR_W-1   : 0] m_axi_awaddr   ,   
  output [7                  : 0] m_axi_awlen    ,
  output [2                  : 0] m_axi_awsize   ,
  output [1                  : 0] m_axi_awburst  ,
  output [C_M_AXI_AWUSER_W-1 : 0] m_axi_awuser   ,
  output                          m_axi_awvalid  ,
  input                           m_axi_awready  ,
  output [3                  : 0] m_axi_awregion , // Unused
  output                          m_axi_awlock   , // Unused
  output [3                  : 0] m_axi_awcache  , // Unused
  output [2                  : 0] m_axi_awprot   , // Unused
  output [3                  : 0] m_axi_awqos    , // Unused
  output [C_M_AXI_DATA_W-1   : 0] m_axi_wdata    , // wr data
  output [C_M_AXI_DATA_W/8-1 : 0] m_axi_wstrb    ,
  output                          m_axi_wlast    ,
  output [C_M_AXI_WUSER_W-1  : 0] m_axi_wuser    ,
  output                          m_axi_wvalid   ,
  input                           m_axi_wready   ,
  input  [C_M_AXI_ID_W-1     : 0] m_axi_bid      , // wr res
  input  [1                  : 0] m_axi_bresp    ,
  input  [C_M_AXI_BUSER_W-1  : 0] m_axi_buser    ,
  input                           m_axi_bvalid   ,
  output                          m_axi_bready   

) ;

function automatic int log2 (input int n);
    if (n <=1) return 1; // abort function
    log2 = 0;
    while (n > 1) begin
        n = n/2;
        log2++;
    end
endfunction

localparam SLVERR = 2'b10 ;
localparam DECERR = 2'b10 ;

localparam REQ_TYPE_MWR = 4'b0001 ;
localparam REQ_TYPE_MRD = 4'b0000 ;

logic [127 : 0] des_des         ;
logic [7   : 0] des_tuser       ;
logic [61  : 0] des_address     ;
logic [10  : 0] des_dw_num      ;
logic [10  : 0] des_dw_num_shift;
logic [3   : 0] des_req_type    ;
logic [2   : 0] des_bar_id      ;

logic [2   : 0] data_bar_id     ;
logic           data_eop        ;
logic [31  : 0] data_tuser      ;
logic [255 : 0] data_data       ;

logic           sub_bar_hit     ;
logic           sub_bar_hit_dly ;

// --- Write address channel --- //
// cq_des_fifo_rdata[135:0] : {tuser[7:0], data[127:0]}
assign {des_tuser, des_des} = cq_des_fifo_rdata;
assign des_address  = des_des[63:2];
assign des_dw_num   = des_des[74:64];
assign des_req_type = des_des[78:75];
assign des_bar_id   = des_des[114:112];

assign des_dw_num_shift = des_dw_num + m_axi_awaddr[4:2] ;

assign sub_bar_hit = (SUB_BAR_H == SUB_BAR_L) ? 1'b1 : 
                     (m_axi_awaddr[31:0] < SUB_BAR_H & m_axi_awaddr[31:0] >= SUB_BAR_L) ? 1'b1 : 1'b0;
                     
always_ff @(posedge user_clk) begin
    sub_bar_hit_dly <= sub_bar_hit;
end                     

//assign m_axi_awvalid  = ~cq_des_fifo_empty & des_bar_id == BAR_ID & des_req_type == REQ_TYPE_MWR; 
assign m_axi_awvalid  = ~cq_des_fifo_empty & des_bar_id == BAR_ID & des_req_type == REQ_TYPE_MWR & sub_bar_hit; 
assign m_axi_awaddr   = {des_address, 2'b0} + C_M_BASE_ADDR ; // address has been calculated based on first_be in cq_intf.sv
assign m_axi_awlen    = des_dw_num_shift[10:3] + |des_dw_num_shift[2:0] - 'd1 ; // acture length = axlen + 'd1

assign cq_des_fifo_rd = m_axi_awvalid & m_axi_awready;

// --- Write data channel --- //
// cq_data_fifo_rdata[291 : 0] : {bar_id[2:0], tlast, tuser[39:8], data[255:0]}

assign {data_bar_id, data_eop, data_tuser, data_data} = cq_data_fifo_rdata;

//assign m_axi_wvalid = ~cq_data_fifo_empty & data_bar_id == BAR_ID;
assign m_axi_wvalid = ~cq_data_fifo_empty & data_bar_id == BAR_ID & sub_bar_hit_dly;
assign m_axi_wdata  = data_data;
assign m_axi_wstrb  = data_tuser;
assign m_axi_wlast  = data_eop;

assign cq_data_fifo_rd = m_axi_wvalid & m_axi_wready;

// --- write response channel --- //
assign cq_local_mem_wr_error = m_axi_bvalid & (m_axi_bresp inside {SLVERR, DECERR}) ;

// ---------- Fixed output ---------- //
assign m_axi_bready   = 'b1    ; // Never block write response
assign m_axi_awid     = 'b0    ; // Unused
assign m_axi_awburst  = 'b01   ; // INCR
assign m_axi_awuser   = 'b0    ; // Unused
assign m_axi_awregion = 'b0    ; // Unused
assign m_axi_awlock   = 'b00   ; // Normal access
assign m_axi_awcache  = 'b0010 ; // Normal Non-cacheable Non-bufferable
assign m_axi_awprot   = 'b000  ; // data/secure/Unprivileged access
assign m_axi_awqos    = 'b0    ; // Unused
assign m_axi_wuser    = 'b0    ; // Unused
assign m_axi_awsize   = log2(C_M_AXI_DATA_W/8)  ; // Never use narrow transfer


endmodule
