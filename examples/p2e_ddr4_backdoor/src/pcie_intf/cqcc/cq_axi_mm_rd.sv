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

module cq_axi_mm_rd #(
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
  // Configuration status
  input  [1   : 0] cfg_max_payload               , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  input  [2   : 0] cfg_max_read_req              , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  input            cfg_rcb_status                , // input            1 - 128B; 0 - 64B
  // Connect to cq_intf 
  input            cq_des_fifo_empty             ,
  input  [135 : 0] cq_des_fifo_rdata             , // {tuser[7:0], data[127:0]}
  output           cq_des_fifo_rd                ,
  // Connect to cc_intf
  input            cc_cmpl_des_fifo_full         ,
  output           cc_cmpl_des_fifo_wr           ,
  output [60  : 0] cc_cmpl_des_fifo_wdata        , // {attr, tc, tag, req_id, addr_type, dw_remain, dw_consume, nxt_addr[6:0]} 
  input            cc_cmpl_data_fifo_full        , // 
  output           cc_cmpl_data_fifo_wr          ,
  output [257 : 0] cc_cmpl_data_fifo_wdata       , // {eop, error, data}
  input            cc_tlp_fifo_pfull             ,
  // fifo status
  output logic    cq_des_split_fifo_werr         ,
  // read address and read data channel
  input                           m_axi_aclk     , // Not used
  input                           m_axi_aresetn  , // Not used
  output [C_M_AXI_ID_W-1     : 0] m_axi_arid     , // rd addr
  output [C_M_AXI_ADDR_W-1   : 0] m_axi_araddr   ,
  output [7                  : 0] m_axi_arlen    ,
  output [2                  : 0] m_axi_arsize   ,
  output [1                  : 0] m_axi_arburst  ,
  output [C_M_AXI_ARUSER_W-1 : 0] m_axi_aruser   ,
  output                          m_axi_arvalid  ,
  input                           m_axi_arready  ,
  output [3                  : 0] m_axi_arregion , // Unused
  output                          m_axi_arlock   , // Unused
  output [3                  : 0] m_axi_arcache  , // Unused
  output [2                  : 0] m_axi_arprot   , // Unused
  output [3                  : 0] m_axi_arqos    , // Unused
  input  [C_M_AXI_ID_W-1     : 0] m_axi_rid      , // rd data
  input  [C_M_AXI_DATA_W-1   : 0] m_axi_rdata    ,
  input  [1                  : 0] m_axi_rresp    ,
  input                           m_axi_rlast    ,
  input  [C_M_AXI_RUSER_W-1  : 0] m_axi_ruser    ,
  input                           m_axi_rvalid   ,
  output                          m_axi_rready   

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

logic           full         ; 
logic           prog_full    ;
logic [128 : 0] din          ; 
logic           wr_en        ; 
logic           wr_en_int    ;
logic           empty        ; 
logic [128 : 0] dout         ; 
logic           rd_en        ; 

logic [2   : 0] attr             ;
logic [2   : 0] tc               ;
logic [7   : 0] tag              ;
logic [15  : 0] req_id           ;
logic [1   : 0] addr_type        ;
logic [10  : 0] dw_remain        ;
logic [10  : 0] dw_consume       ;
logic [10  : 0] dw_consume_shift ;
logic [63  : 0] nxt_addr         ;

logic           rdata_vld    ;
logic           rdata_vld_dly;
logic           rlast        ;
logic           rresp_err    ;

cq_tlp_split #(
    .BAR_ID    ( BAR_ID    ) ,
    .SUB_BAR_L ( SUB_BAR_L ) ,
    .SUB_BAR_H ( SUB_BAR_H ) 
)cq_des_split(
  .user_clk          ( user_clk          ) , // input    
  .user_reset        ( user_reset        ) , // input 
  .cfg_max_payload   ( cfg_max_payload   ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  .cfg_max_read_req  ( cfg_max_read_req  ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  .cfg_rcb_status    ( cfg_rcb_status    ) , // input            1 - 128B; 0 - 64B
  .cq_des_fifo_empty ( cq_des_fifo_empty ) ,
  .cq_des_fifo_rdata ( cq_des_fifo_rdata ) , // {tuser[7:0], data[127:0]}
  .cq_des_fifo_rd    ( cq_des_fifo_rd    ) ,
  .prog_full         ( prog_full         ) ,
  .wr_en             ( wr_en             ) ,
  .din               ( din               )       
) ;

// {attr, tc, tag, req_id, addr_type, byte_remain, dw_consume, dw_consume_shift, nxt_addr}
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "distributed" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"        ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 16            ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 129           ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 11            )   // DECIMAL  3 - 4194301
) cq_des_split_fifo_16x129bits (
    .clk       ( user_clk   ) ,
    .srst      ( user_reset ) ,
    .full      ( full       ) ,
    .din       ( din        ) ,
    .wr_en     ( wr_en      ) ,
    .empty     ( empty      ) ,
    .dout      ( dout       ) ,
    .rd_en     ( rd_en      ) ,
    .prog_full ( prog_full  )
) ;

// dw_consume_shift is calculated in split module
assign {attr, tc, tag, req_id, addr_type, dw_remain, dw_consume, dw_consume_shift, nxt_addr} = dout ;
assign rd_en = m_axi_arvalid & m_axi_arready ;

assign cc_cmpl_des_fifo_wr    = m_axi_arvalid & m_axi_arready ;
assign cc_cmpl_des_fifo_wdata = {attr, tc, tag, req_id, addr_type, dw_remain, dw_consume, nxt_addr[6:0]} ;

assign m_axi_arvalid = ~empty & ~cc_cmpl_des_fifo_full & ~cc_tlp_fifo_pfull ;
assign m_axi_araddr  = nxt_addr ;
assign m_axi_arlen   = dw_consume_shift[10:3] + |dw_consume_shift[2:0] - 'd1 ; // acture length = axlen + 'd1
assign m_axi_rready  = ~cc_cmpl_data_fifo_full ;

always_ff @(posedge user_clk) begin  
    if (user_reset) begin
        rresp_err <= 1'b0 ;
    end else if (m_axi_rvalid & m_axi_rready & m_axi_rlast) begin
        rresp_err <= 1'b0 ;
    end else if (m_axi_rvalid & m_axi_rready & m_axi_rresp inside {SLVERR, DECERR}) begin
        rresp_err <= 1'b1 ;
    end else ;
end

assign rlast  = m_axi_rlast & m_axi_rvalid & m_axi_rready ;

assign cc_cmpl_data_fifo_wr = m_axi_rvalid & m_axi_rready ; 

assign cc_cmpl_data_fifo_wdata = {rlast, rresp_err, {(256-C_M_AXI_DATA_W){1'b0}}, m_axi_rdata} ;

// --- FIFO status --- //
always_ff @(posedge user_clk) begin
    if (user_reset) cq_des_split_fifo_werr <= 1'b0;
    else if (wr_en & full) cq_des_split_fifo_werr <= 1'b1;
    else ;
end

// ---------- Fixed output ---------- //
assign m_axi_arid     = 'b0    ; //
assign m_axi_arburst  = 'b01   ;
assign m_axi_aruser   = 'b0    ;
assign m_axi_arregion = 'b0    ; // Unused
assign m_axi_arlock   = 'b0    ; // Unused
assign m_axi_arcache  = 'b0010 ; // Unused
assign m_axi_arprot   = 'b0    ; // Unused
assign m_axi_arqos    = 'b0    ; // Unused
assign m_axi_arsize   = log2(C_M_AXI_DATA_W/8)  ; // Never use narrow transfer


endmodule
