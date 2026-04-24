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

module rq_intf (
  // clock and reset
  input            user_clk             , // input    
  input            user_reset           , // input 
  // RQ 
  output [255 : 0] s_axis_rq_tdata      , // output [255 : 0] 
  output [7   : 0] s_axis_rq_tkeep      , // output [7   : 0] 
  output           s_axis_rq_tlast      , // output           
  input            s_axis_rq_tready     , // input   
  output [59  : 0] s_axis_rq_tuser      , // output [59  : 0] 
  output           s_axis_rq_tvalid     , // output           
  // Connect to rqrc_tlp_proc
  input            wdma_des_fifo_empty  , // write DMA channel descriptor FIFO
  output           wdma_des_fifo_rd     ,
  input  [104 : 0] wdma_des_fifo_rdata  , // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
  input            wdma_data_fifo_req   , // write DMA channel data FIFO
  output           wdma_data_fifo_rd    ,
  input  [255 : 0] wdma_data_fifo_rdata ,
  input            rdma_des_fifo_empty  , // read DMA channel descriptor FIFO
  output           rdma_des_fifo_rd     ,
  input  [104 : 0] rdma_des_fifo_rdata    // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
  
) ;

// Insert Tag for each scheduled request


assign s_axis_rq_tdata   = 'b0 ; // output [255 : 0] 
assign s_axis_rq_tkeep   = 'b0 ; // output [7   : 0] 
assign s_axis_rq_tlast   = 'b0 ; // output            
assign s_axis_rq_tuser   = 'b0 ; // output [59  : 0] 
assign s_axis_rq_tvalid  = 'b0 ; // output           
assign wdma_des_fifo_rd  = 'b0 ;
assign wdma_data_fifo_rd = 'b0 ;
assign rdma_des_fifo_rd  = 'b0 ;


endmodule
