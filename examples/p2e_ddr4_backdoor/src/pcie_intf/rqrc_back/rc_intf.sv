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

module rc_intf (
  // clock and reset
  input            user_clk             , // input    
  input            user_reset           , // input 
  // RC 
  input  [255 : 0] m_axis_rc_tdata      , // input  [255 : 0] 
  input  [7   : 0] m_axis_rc_tkeep      , // input  [7   : 0] 
  input            m_axis_rc_tlast      , // input            
  output           m_axis_rc_tready     , // output           
  input  [74  : 0] m_axis_rc_tuser      , // input  [74  : 0] 
  input            m_axis_rc_tvalid     , // input     
  // Connect to rqrc_tlp_proc
  input            rdma_data_fifo_full  ,
  output           rdma_data_fifo_wr    ,
  output [289 : 0] rdma_data_fifo_wdata , // {sop, eop, data, strobe}  
  // Interrupt 
  output           wdma_error           ,
  output           rdma_error           
    
) ;

// Normally we don't read data from Host, to simplize logic, this module will be implemented simple.


assign m_axis_rc_tready     = 'b0 ; 
assign rdma_data_fifo_wr    = 'b0 ; 
assign rdma_data_fifo_wdata = 'b0 ;
assign wdma_error           = 'b0 ; 
assign rdma_error           = 'b0 ;  


endmodule
