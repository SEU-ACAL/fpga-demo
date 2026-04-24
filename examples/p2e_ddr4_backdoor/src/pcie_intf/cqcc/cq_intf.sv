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

//`include "../../defines_parameters/glbl_param.sv"

module cq_intf #(
    parameter         DEBUG_ON   = "FALSE" , // "FALSE" or "TRUE"
    parameter integer BAR_NUM_M1 = 2         // BAR number minus one
    
)(
  // clock and reset
  input                        user_clk           , // input    
   (* MARK_DEBUG="true" *)input                        user_reset         , // input 
  // CQ, user_clk domain
   (* MARK_DEBUG="true" *)input       [255        : 0] m_axis_cq_tdata    , // input  [255 : 0] 
   (* MARK_DEBUG="true" *)input       [7          : 0] m_axis_cq_tkeep    , // input  [7   : 0] 
   (* MARK_DEBUG="true" *)input                        m_axis_cq_tlast    , // input            
   (* MARK_DEBUG="true" *)output                       m_axis_cq_tready   , // output           
   (* MARK_DEBUG="true" *)input       [41         : 0] m_axis_cq_tuser    , // input  [41  : 0] 
   (* MARK_DEBUG="true" *)input                        m_axis_cq_tvalid   , // input   
  // Connect to cqcc_tlp_proc, axi_aclk domain
  output                       cq_des_fifo_empty  ,
  output      [135        : 0] cq_des_fifo_rdata  , // {tuser[7:0], data[127:0]}
  input       [BAR_NUM_M1 : 0] cq_des_fifo_rd     , // psfifo read is logic OR of every BAR channel's read
  output                       cq_data_fifo_empty ,
  output      [291        : 0] cq_data_fifo_rdata , // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
  input       [BAR_NUM_M1 : 0] cq_data_fifo_rd      // psfifo read is logic OR of every BAR channel's read
) ;

localparam REQ_TYPE_MWR = 4'b0001 ;
localparam REQ_TYPE_MRD = 4'b0000 ;

logic [127 : 0] descriptor             ;
logic [63  : 0] address                ;
logic [63  : 0] address_masked         ;
logic [5   : 0] bar_apt                ; // BAR aperture
logic [63  : 0] addr_mask              ; 

(* MARK_DEBUG="true" *)logic           cq_des_fifo_wr;
(* MARK_DEBUG="true" *)logic [135 : 0] cq_des_fifo_wdata;
(* MARK_DEBUG="true" *)logic           cq_des_fifo_prog_full;

(* MARK_DEBUG="true" *)logic           cq_data_fifo_wr;
(* MARK_DEBUG="true" *)logic [291 : 0] cq_data_fifo_wdata;
(* MARK_DEBUG="true" *)logic           cq_data_fifo_prog_full;

logic [2 : 0] bar_id;
logic [2 : 0] bar_id_latch = 'b0 ;

assign descriptor = m_axis_cq_tdata[127:0];
assign address = {descriptor[63:2], 2'b0};

assign bar_apt = descriptor[120:115];
assign addr_mask = {64{1'b1}} >> (64 - bar_apt);

assign address_masked = address & addr_mask ;

assign bar_id = m_axis_cq_tdata[114:112];

always_ff @(posedge user_clk) begin
    if (m_axis_cq_tvalid & m_axis_cq_tready & m_axis_cq_tuser[40])
        bar_id_latch <= bar_id;
    else ;
end

assign m_axis_cq_tready = ~cq_des_fifo_prog_full & ~cq_data_fifo_prog_full ;

assign cq_des_fifo_wr = m_axis_cq_tvalid & m_axis_cq_tready & m_axis_cq_tuser[40];
assign cq_des_fifo_wdata = {m_axis_cq_tuser[7:0], m_axis_cq_tdata[127:64], address_masked}; // AT is used for virtualization.

assign cq_data_fifo_wr = m_axis_cq_tvalid & m_axis_cq_tready & ~m_axis_cq_tuser[40];
assign cq_data_fifo_wdata = {bar_id_latch, m_axis_cq_tlast, m_axis_cq_tuser[39:8], m_axis_cq_tdata};

// {tuser[7:0], data[127:0]}, total width is 136bits
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "distributed" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"        ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 16            ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 136           ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 11            )   // DECIMAL  3 - 4194301
) cq_des_fifo_16x136bits (
    .clk       ( user_clk              ) ,
    .srst      ( user_reset            ) ,
    .full      (                       ) ,
    .din       ( cq_des_fifo_wdata     ) ,
    .wr_en     ( cq_des_fifo_wr        ) ,
    .empty     ( cq_des_fifo_empty     ) ,
    .dout      ( cq_des_fifo_rdata     ) ,
    .rd_en     ( cq_des_fifo_rd_en     ) ,
    .prog_full ( cq_des_fifo_prog_full )
) ;

// {bar_id[2:0], tlast, tuser[39:8], data[255:0]}, total width is 292
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "distributed" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"        ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 16            ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 292           ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 11            )   // DECIMAL  3 - 4194301
) cq_data_fifo_16x292bits (
    .clk       ( user_clk               ) ,
    .srst      ( user_reset             ) ,
    .full      (                        ) ,
    .din       ( cq_data_fifo_wdata     ) ,
    .wr_en     ( cq_data_fifo_wr        ) ,
    .empty     ( cq_data_fifo_empty     ) ,
    .dout      ( cq_data_fifo_rdata     ) ,
    .rd_en     ( cq_data_fifo_rd_en     ) ,
    .prog_full ( cq_data_fifo_prog_full )
) ;

// Change des/data FIFO to async clk: wr clock is user_clk. read ck is m_axi_aclk.
// Then the whole design can work when PCIe clock is different with axi_mm clock.

assign cq_des_fifo_rd_en  = |cq_des_fifo_rd  ;
assign cq_data_fifo_rd_en = |cq_data_fifo_rd ;

// ---------- Debug signals --------- //
/*
generate if (DEBUG_ON == "TRUE") begin

(* keep = "true" *) logic [255        : 0] debug_m_axis_cq_tdata    ; // input  [255 : 0] 
(* keep = "true" *) logic [7          : 0] debug_m_axis_cq_tkeep    ; // input  [7   : 0] 
(* keep = "true" *) logic                  debug_m_axis_cq_tlast    ; // input            
(* keep = "true" *) logic                  debug_m_axis_cq_tready   ; // output           
(* keep = "true" *) logic [41         : 0] debug_m_axis_cq_tuser    ; // input  [41  : 0] 
(* keep = "true" *) logic                  debug_m_axis_cq_tvalid   ; // input   
(* keep = "true" *) logic                  debug_cq_des_fifo_empty  ;
(* keep = "true" *) logic [135        : 0] debug_cq_des_fifo_rdata  ; // {tuser[7:0], data[127:0]}
(* keep = "true" *) logic [BAR_NUM_M1 : 0] debug_cq_des_fifo_rd     ; // psfifo read is logic OR of every BAR channel's read
(* keep = "true" *) logic                  debug_cq_data_fifo_empty ;
(* keep = "true" *) logic [291        : 0] debug_cq_data_fifo_rdata ; // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
(* keep = "true" *) logic [BAR_NUM_M1 : 0] debug_cq_data_fifo_rd    ; // psfifo read is logic OR of every BAR channel's read

(* keep = "true" *) logic           debug_cq_des_fifo_wr         ;
(* keep = "true" *) logic [135 : 0] debug_cq_des_fifo_wdata      ;
(* keep = "true" *) logic           debug_cq_des_fifo_prog_full  ;
(* keep = "true" *) logic           debug_cq_data_fifo_wr        ;
(* keep = "true" *) logic [291 : 0] debug_cq_data_fifo_wdata     ;
(* keep = "true" *) logic           debug_cq_data_fifo_prog_full ;
(* keep = "true" *) logic [2   : 0] debug_bar_id                 ;

assign debug_m_axis_cq_tdata        = m_axis_cq_tdata    ; // input  [255 : 0] 
assign debug_m_axis_cq_tkeep        = m_axis_cq_tkeep    ; // input  [7   : 0] 
assign debug_m_axis_cq_tlast        = m_axis_cq_tlast    ; // input            
assign debug_m_axis_cq_tready       = m_axis_cq_tready   ; // output           
assign debug_m_axis_cq_tuser        = m_axis_cq_tuser    ; // input  [41  : 0] 
assign debug_m_axis_cq_tvalid       = m_axis_cq_tvalid   ; // input   
assign debug_cq_des_fifo_empty      = cq_des_fifo_empty  ;
assign debug_cq_des_fifo_rdata      = cq_des_fifo_rdata  ; // {tuser[7:0], data[127:0]}
assign debug_cq_des_fifo_rd         = cq_des_fifo_rd     ; // psfifo read is logic OR of every BAR channel's read
assign debug_cq_data_fifo_empty     = cq_data_fifo_empty ;
assign debug_cq_data_fifo_rdata     = cq_data_fifo_rdata ; // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
assign debug_cq_data_fifo_rd        = cq_data_fifo_rd    ; // psfifo read is logic OR of every BAR channel's read
assign debug_cq_des_fifo_wr         = cq_des_fifo_wr         ;
assign debug_cq_des_fifo_wdata      = cq_des_fifo_wdata      ;
assign debug_cq_des_fifo_prog_full  = cq_des_fifo_prog_full  ;
assign debug_cq_data_fifo_wr        = cq_data_fifo_wr        ;
assign debug_cq_data_fifo_wdata     = cq_data_fifo_wdata     ;
assign debug_cq_data_fifo_prog_full = cq_data_fifo_prog_full ;
assign debug_bar_id                 = bar_id                 ;

ila_cq_intf ila_cq_intf_inst(
    .clk     ( user_clk                     ) ,
    .probe0  ( debug_m_axis_cq_tdata        ) , // [255 : 0]          
    .probe1  ( debug_m_axis_cq_tkeep        ) , // [7   : 0]          
    .probe2  ( debug_m_axis_cq_tlast        ) , // 
    .probe3  ( debug_m_axis_cq_tready       ) , // 
    .probe4  ( debug_m_axis_cq_tuser        ) , // [41  : 0]         
    .probe5  ( debug_m_axis_cq_tvalid       ) , //          
    .probe6  ( debug_cq_des_fifo_empty      ) , // 
    .probe7  ( debug_cq_des_fifo_rdata      ) , // [135 : 0]         
    .probe8  ( debug_cq_des_fifo_rd         ) , // [2   : 0]
    .probe9  ( debug_cq_data_fifo_empty     ) , //
    .probe10 ( debug_cq_data_fifo_rdata     ) , // [291 : 0]         
    .probe11 ( debug_cq_data_fifo_rd        ) , // [2   : 0]
    .probe12 ( debug_cq_des_fifo_wr         ) , //
    .probe13 ( debug_cq_des_fifo_wdata      ) , // [135 : 0]           
    .probe14 ( debug_cq_des_fifo_prog_full  ) , // 
    .probe15 ( debug_cq_data_fifo_wr        ) , // 
    .probe16 ( debug_cq_data_fifo_wdata     ) , // [291 : 0]         
    .probe17 ( debug_cq_data_fifo_prog_full ) , //      
    .probe18 ( debug_bar_id                 )   // [2   : 0]                 
) ;

end endgenerate
*/

endmodule
