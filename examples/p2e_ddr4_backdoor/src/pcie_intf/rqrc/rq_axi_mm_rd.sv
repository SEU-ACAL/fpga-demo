/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

module rq_axi_mm_rd #(
    parameter integer S_AXI_ID_W   = 4   , // Slave
    parameter integer S_AXI_ADDR_W = 64  ,
    parameter integer S_AXI_DATA_W = 256 
)(  
  // clock and reset
  input                         user_clk           , // input    
  input                         user_reset         , // input 
  // AXI-MM-slave     
  input                         s_axi_aclk         , // Unused
  input                         s_axi_aresetn      , // Unused
  input  [S_AXI_ID_W-1     : 0] s_axi_arid         , // rd addr
  input  [S_AXI_ADDR_W-1   : 0] s_axi_araddr       ,
  input  [7                : 0] s_axi_arlen        ,
  input  [2                : 0] s_axi_arsize       ,
  input  [1                : 0] s_axi_arburst      ,
  input  [3                : 0] s_axi_arregion     , // Unused
  input                         s_axi_arlock       , // Unused
  input  [3                : 0] s_axi_arcache      , // Unused
  input  [2                : 0] s_axi_arprot       , // Unused
  input  [3                : 0] s_axi_arqos        , // Unused
  input                         s_axi_arvalid      ,
  output                        s_axi_arready      ,
  output [S_AXI_ID_W-1     : 0] s_axi_rid          , // rd data
  output [S_AXI_DATA_W-1   : 0] s_axi_rdata        ,
  output [1                : 0] s_axi_rresp        ,
  output                        s_axi_rlast        ,
  output                        s_axi_rvalid       ,
  input                         s_axi_rready       ,
  
  output                        rdes_valid         , //         
  output [86               : 0] rdes               , // {wrrd, id[1:0], dw_cnt[10:0], add_offset[2:0], last_be[3:0], first_be[3:0], addr[61:0]}
  input                         rq_des_fifo_full   , // 
  input                         rq_data_fifo_empty  ,//this signal is used to ensure that the read of dma flush is completed after the write
  
  input                         rc_data_fifo_empty ,               
  input  [258              : 0] rc_data_fifo_rdata , // {eop, func_id[1:0], data[255:0]}
  output                        rc_data_fifo_rd    ,
  
  output [31 : 0] dbg_rq_raxi_ar_cnt ,
  output [31 : 0] dbg_rq_raxi_r_cnt  
            
      
) ;

localparam WRRD = 0;

logic [1 :0] id        ;
logic [10:0] dw_cnt    ;
logic [2 :0] add_offset;
logic [3 :0] first_be  ;
logic [3 :0] last_be   ;
logic [61:0] addr      ;

assign id = s_axi_arid[1:0];

assign dw_cnt = (s_axi_arlen + 1) << 3;

assign add_offset = 'b0;

assign first_be = 4'hf;

assign last_be = dw_cnt > 'd1 ? 4'hf : 4'h0;    

assign addr = s_axi_araddr[63:2];

assign rdes_valid = s_axi_arvalid & s_axi_arready;

assign rdes = {WRRD, id[1:0], dw_cnt[10:0], add_offset[2:0], last_be[3:0], first_be[3:0], addr[61:0]};

assign s_axi_arready = rq_data_fifo_empty && ~rq_des_fifo_full;//this signal is used to ensure that the read of dma flush is completed after the write

assign rc_data_fifo_rd = ~rc_data_fifo_empty & s_axi_rready;

assign s_axi_rvalid = ~rc_data_fifo_empty;

assign s_axi_rlast = rc_data_fifo_rdata[258];

assign s_axi_rid   = {2'b0, rc_data_fifo_rdata[257:256]};

assign s_axi_rdata = rc_data_fifo_rdata[255:0];

assign s_axi_rresp = 2'b0;

// --- for debug --- //

logic [31:0] ar_cnt;
logic [31:0] r_cnt;

always_ff @(posedge user_clk) begin
    if (user_reset) ar_cnt <= 'b0; else if (s_axi_arvalid & s_axi_arready)             ar_cnt <= ar_cnt + 'b1; else;
    if (user_reset) r_cnt  <= 'b0; else if (s_axi_rvalid & s_axi_rready & s_axi_rlast) r_cnt  <= r_cnt  + 'b1; else;
end

assign dbg_rq_raxi_ar_cnt = ar_cnt;
assign dbg_rq_raxi_r_cnt  = r_cnt ;



endmodule
