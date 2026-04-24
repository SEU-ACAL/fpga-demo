/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

`define RQ_INTF_NO_FSM

module rq_intf (
  // clock and reset
  input            user_clk           , // input    
  input            user_reset         , // input 
  // R
  output [255 : 0] s_axis_rq_tdata    , // output [255 : 0] 
  output [7   : 0] s_axis_rq_tkeep    , // output [7   : 0] 
  output           s_axis_rq_tlast    , // output           
  input            s_axis_rq_tready   , // input   
  output [59  : 0] s_axis_rq_tuser    , // output [59  : 0]
  output           s_axis_rq_tvalid   , // output           
  // Connect to rqrc_tlp_proc
  input            rq_tlp_fifo_req    ,
  output           rq_tlp_fifo_rd     ,
  input  [275 : 0] rq_tlp_fifo_rdata  , // {eop, addr_offset[2:0], last_be[3:0], first_be[3:0], tkeep[7:0], data[255:0]}  

  output [31:0] dbg_rqintf_tlp_out_cnt
  
) ;

`ifdef RQ_INTF_NO_FSM

// --- No FSM style--- // 

assign s_axis_rq_tvalid = rq_tlp_fifo_req ;
assign s_axis_rq_tdata  = {256{s_axis_rq_tvalid}} & rq_tlp_fifo_rdata[255 -: 256] ;
assign s_axis_rq_tlast  = s_axis_rq_tvalid & rq_tlp_fifo_rdata[275] ;
assign s_axis_rq_tkeep  = {8{s_axis_rq_tvalid}} & rq_tlp_fifo_rdata[263 -: 8] ;
                         
assign s_axis_rq_tuser[7:0]   = {8{s_axis_rq_tvalid}} & rq_tlp_fifo_rdata[271 -: 8] ;   
assign s_axis_rq_tuser[10:8]  = rq_tlp_fifo_rdata[274:272]; // addr offset    
assign s_axis_rq_tuser[11]    = 1'b0; // discontinue            
assign s_axis_rq_tuser[59:12] = 48'b0 ;

assign rq_tlp_fifo_rd = rq_tlp_fifo_req & s_axis_rq_tready;

`else

// --- FSM style--- // 

localparam REQ_NUM = 1;

logic [REQ_NUM-1 : 0] grant ;
logic [REQ_NUM-1 : 0] eop   ;

typedef enum logic[1:0] {
    IDLE     ,
    GRANT0   
} sch_t ;

sch_t cstate, nstate;

// FSM
always_ff @(posedge user_clk) begin
    if (user_reset) begin
        cstate <= IDLE ;
    end else begin
        cstate <= nstate ;
    end
end

always_comb begin // RR schedule
    nstate = IDLE ;
    case(cstate)
        IDLE    : if (rq_tlp_fifo_req) nstate = GRANT0 ;
                  else nstate = IDLE ;
        GRANT0  : if (eop[0] & s_axis_rq_tready) nstate = IDLE ;
                  else nstate = GRANT0 ;
        default : nstate = IDLE ;
    endcase
end

assign eop[0] = rq_tlp_fifo_rdata[275] ;

assign grant[0] = cstate == GRANT0 ;

assign rq_tlp_fifo_rd = grant[0] & s_axis_rq_tready;

assign s_axis_rq_tvalid = |grant ;

assign s_axis_rq_tdata = {256{grant[0]}} & rq_tlp_fifo_rdata[255 -: 256] ;

assign s_axis_rq_tlast = grant[0] & eop[0] ;

assign s_axis_rq_tkeep = {8{grant[0]}} & rq_tlp_fifo_rdata[263 -: 8] ;
                         
assign s_axis_rq_tuser[7:0] = {8{grant[0]}} & rq_tlp_fifo_rdata[271 -: 8] ;   

assign s_axis_rq_tuser[10:8] = rq_tlp_fifo_rdata[274:272]; // addr offset    

assign s_axis_rq_tuser[11] = 1'b0; // discontinue            
                         
assign s_axis_rq_tuser[59:12] = 48'b0 ;   

`endif


// --- for debug --- //

logic [31 : 0] rqintf_tlp_out_cnt;

always_ff @(posedge user_clk) begin
    if (user_reset) rqintf_tlp_out_cnt <= 'b0;
    else if (s_axis_rq_tvalid & s_axis_rq_tready & s_axis_rq_tlast) rqintf_tlp_out_cnt <= rqintf_tlp_out_cnt + 'b1;
    else;
end

assign dbg_rqintf_tlp_out_cnt = rqintf_tlp_out_cnt;


endmodule
