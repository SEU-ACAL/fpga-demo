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

module cq_tlp_filter (
  // clock and reset
  input                        user_clk         , // input   
  input                        user_reset       , // input 
  // CQ 
  input       [255        : 0] s_axis_cq_tdata  , // input  [255 : 0] 
  input       [7          : 0] s_axis_cq_tkeep  , // input  [7   : 0] 
  input                        s_axis_cq_tlast  , // input            
  output                       s_axis_cq_tready , // output           
  input       [41         : 0] s_axis_cq_tuser  , // input  [41  : 0] 
  input                        s_axis_cq_tvalid , // input   
  // After filter
  output                       m_axis_cq_tvalid , // output
  input                        m_axis_cq_tready , // input
  output      [255        : 0] m_axis_cq_tdata  , // output [255 : 0]
  output      [7          : 0] m_axis_cq_tkeep  , // output [7   : 0]
  output                       m_axis_cq_tlast  , // output
  output      [41         : 0] m_axis_cq_tuser  , // input  [41  : 0]

  // for mmr
  output logic                 cq_tlp_vld       ,
  output logic                 cq_tlp_invld       

) ;

localparam REQ_TYPE_MWR = 4'b0001 ;
localparam REQ_TYPE_MRD = 4'b0000 ;

logic           invld_req_type ;
logic           invld_tlp      ;
logic           drop_tlp       ;

// Filter, drop invalid TLP, write valid TLP into FIFO

assign invld_req_type = ~(s_axis_cq_tdata[78:75] inside {REQ_TYPE_MWR, REQ_TYPE_MRD}) & s_axis_cq_tuser[40];

always_ff @(posedge user_clk) begin
    if (user_reset) begin
        invld_tlp <= 1'b0 ;
    end else if (s_axis_cq_tvalid & s_axis_cq_tready & s_axis_cq_tlast) begin
        invld_tlp <= 1'b0 ;
    end else if (s_axis_cq_tvalid & s_axis_cq_tready & invld_req_type) begin
        invld_tlp <= 1'b1 ;
    end else ;
end

assign drop_tlp = invld_req_type | invld_tlp ;

// output

assign m_axis_cq_tvalid = s_axis_cq_tvalid & ~drop_tlp ;
assign s_axis_cq_tready = m_axis_cq_tready ;
assign m_axis_cq_tdata  = s_axis_cq_tdata  ;
assign m_axis_cq_tkeep  = s_axis_cq_tkeep  ;
assign m_axis_cq_tlast  = s_axis_cq_tlast  ;
assign m_axis_cq_tuser  = s_axis_cq_tuser  ;


always_ff @(posedge user_clk) begin
    cq_tlp_invld <= s_axis_cq_tvalid & s_axis_cq_tready & s_axis_cq_tuser[40] & ~(s_axis_cq_tdata[78:75] inside {REQ_TYPE_MWR, REQ_TYPE_MRD}) ;
    cq_tlp_vld   <= s_axis_cq_tvalid & s_axis_cq_tready & s_axis_cq_tuser[40] & (s_axis_cq_tdata[78:75] inside {REQ_TYPE_MWR, REQ_TYPE_MRD}) ;
end


endmodule
