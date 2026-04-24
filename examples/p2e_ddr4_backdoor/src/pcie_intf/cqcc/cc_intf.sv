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

module cc_intf #(
    parameter         DEBUG_ON   = "FALSE" , // "FALSE" or "TRUE"
    parameter integer BAR_NUM_M1 = 2         // BAR number minus one
)(
  // clock and reset
  input            user_clk                            , // input    
  input            user_reset                          , // input 
  input            soft_rstp                           , // input
  // CC 
   (* MARK_DEBUG="true" *)output [255 : 0] s_axis_cc_tdata                     , // output [255 : 0] 
   (* MARK_DEBUG="true" *)output [7   : 0] s_axis_cc_tkeep                     , // output [7   : 0] 
   (* MARK_DEBUG="true" *)output           s_axis_cc_tlast                     , // output           
   (* MARK_DEBUG="true" *)input            s_axis_cc_tready                    , // input  
   (* MARK_DEBUG="true" *)output [32  : 0] s_axis_cc_tuser                     , // output [32  : 0] 
   (* MARK_DEBUG="true" *)output           s_axis_cc_tvalid                    , // output  
  // for status counter
  output           cc_tlp_vld                          , // output
  output           cc_tlp_invld                        , // output 
  // Connect to cqcc_tlp_proc
  input            cc_tlp_fifo_req[0:BAR_NUM_M1]       , // request when stored the whole TLP
  input            cc_tlp_fifo_empty[0:BAR_NUM_M1]     , // Unused
  output           cc_tlp_fifo_rd[0:BAR_NUM_M1]        ,
  input  [266 : 0] cc_tlp_fifo_rdata[0:BAR_NUM_M1]  

) ;

// Schedule based on attribute in descriptor. Strict ordering is not supportted now

logic [BAR_NUM_M1 : 0] grant ;
logic [BAR_NUM_M1 : 0] eop   ;

typedef enum logic[1:0] {
    IDLE     ,
    GRANT0   ,
    GRANT1   ,
    GRANT2   
} sch_t ;

sch_t cstate, nstate;

assign eop[0] = cc_tlp_fifo_rdata[0][265] ;
assign eop[1] = cc_tlp_fifo_rdata[1][265] ;
assign eop[2] = cc_tlp_fifo_rdata[2][265] ;

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
        IDLE    : if (cc_tlp_fifo_req[0]) nstate = GRANT0 ;
                  else if (cc_tlp_fifo_req[1]) nstate = GRANT1 ;
                  else if (cc_tlp_fifo_req[2]) nstate = GRANT2 ;
                  else nstate = IDLE ;
        GRANT0  : if (eop[0] & s_axis_cc_tready)
                     if (cc_tlp_fifo_req[1]) nstate = GRANT1 ;
                     else if (cc_tlp_fifo_req[2]) nstate = GRANT2 ;
                     //else if (cc_tlp_fifo_req[0]) nstate = GRANT0 ;
                     else nstate = IDLE ;
                  else nstate = GRANT0 ;
        GRANT1  : if (eop[1] & s_axis_cc_tready)
                     if (cc_tlp_fifo_req[2]) nstate = GRANT2 ;
                     else if (cc_tlp_fifo_req[0]) nstate = GRANT0 ;
                     //else if (cc_tlp_fifo_req[1]) nstate = GRANT1 ;
                     else nstate = IDLE ;
                  else nstate = GRANT1 ;
        GRANT2  : if (eop[2] & s_axis_cc_tready)
                     if (cc_tlp_fifo_req[0]) nstate = GRANT0 ;
                     else if (cc_tlp_fifo_req[1]) nstate = GRANT1 ;
                     //else if (cc_tlp_fifo_req[2]) nstate = GRANT2 ;
                     else nstate = IDLE ;
                  else nstate = GRANT2 ;
        default : nstate = IDLE ;
    endcase
end

assign grant[0] = cstate == GRANT0 ;
assign grant[1] = cstate == GRANT1 ;
assign grant[2] = cstate == GRANT2 ;

assign cc_tlp_fifo_rd[0] = grant[0] & s_axis_cc_tready;
assign cc_tlp_fifo_rd[1] = grant[1] & s_axis_cc_tready;
assign cc_tlp_fifo_rd[2] = grant[2] & s_axis_cc_tready;

assign s_axis_cc_tvalid = |grant ;

assign s_axis_cc_tdata = {256{grant[0]}} & cc_tlp_fifo_rdata[0][255 -: 256] |
                         {256{grant[1]}} & cc_tlp_fifo_rdata[1][255 -: 256] |
                         {256{grant[2]}} & cc_tlp_fifo_rdata[2][255 -: 256] ;

assign s_axis_cc_tlast = grant[0] & eop[0] |
                         grant[1] & eop[1] |
                         grant[2] & eop[2] ;

assign s_axis_cc_tkeep = {8{grant[0]}} & cc_tlp_fifo_rdata[0][263 -: 8] |
                         {8{grant[1]}} & cc_tlp_fifo_rdata[1][263 -: 8] |
                         {8{grant[2]}} & cc_tlp_fifo_rdata[2][263 -: 8] ; 
                         
assign s_axis_cc_tuser[0] = grant[0] & cc_tlp_fifo_rdata[0][264] |
                            grant[1] & cc_tlp_fifo_rdata[1][264] |
                            grant[2] & cc_tlp_fifo_rdata[2][264] ;                         
                         
assign s_axis_cc_tuser[32:1] = 'b0 ;    

// ---------- for counters ---------- //

assign cc_tlp_vld = s_axis_cc_tvalid & s_axis_cc_tready & s_axis_cc_tlast;

assign cc_tlp_invld = 1'b0; 

// ---------- Debug signals --------- //
/*
generate if (DEBUG_ON == "TRUE") begin

(* keep = "true" *) logic [255        : 0] debug_s_axis_cc_tdata     ; // output [255 : 0] 
(* keep = "true" *) logic [7          : 0] debug_s_axis_cc_tkeep     ; // output [7   : 0] 
(* keep = "true" *) logic                  debug_s_axis_cc_tlast     ; // output           
(* keep = "true" *) logic                  debug_s_axis_cc_tready    ; // input  
(* keep = "true" *) logic                  debug_s_axis_cc_tuser     ; // output [32  : 0] 
(* keep = "true" *) logic                  debug_s_axis_cc_tvalid    ; // output  
(* keep = "true" *) logic [BAR_NUM_M1 : 0] debug_cc_tlp_fifo_req     ; // request when stored the whole TLP
(* keep = "true" *) logic [BAR_NUM_M1 : 0] debug_cc_tlp_fifo_empty   ; // Unused
(* keep = "true" *) logic [BAR_NUM_M1 : 0] debug_cc_tlp_fifo_rd      ;

(* keep = "true" *) logic           vio_rst                     ;
(* keep = "true" *) logic [31  : 0] debug_cnt_cc_tlast  = 'd0   ;

assign debug_s_axis_cc_tdata      = s_axis_cc_tdata      ; // output [255 : 0] 
assign debug_s_axis_cc_tkeep      = s_axis_cc_tkeep      ; // output [7   : 0] 
assign debug_s_axis_cc_tlast      = s_axis_cc_tlast      ; // output           
assign debug_s_axis_cc_tready     = s_axis_cc_tready     ; // input  
assign debug_s_axis_cc_tuser      = s_axis_cc_tuser[0]   ; // output [32  : 0] 
assign debug_s_axis_cc_tvalid     = s_axis_cc_tvalid     ; // output  
assign debug_cc_tlp_fifo_req[0]   = cc_tlp_fifo_req[0]   ; // request when stored the whole TLP
assign debug_cc_tlp_fifo_req[1]   = cc_tlp_fifo_req[1]   ; // request when stored the whole TLP
assign debug_cc_tlp_fifo_req[2]   = cc_tlp_fifo_req[2]   ; // request when stored the whole TLP
assign debug_cc_tlp_fifo_empty[0] = cc_tlp_fifo_empty[0] ; // Unused
assign debug_cc_tlp_fifo_empty[1] = cc_tlp_fifo_empty[1] ; // Unused
assign debug_cc_tlp_fifo_empty[2] = cc_tlp_fifo_empty[2] ; // Unused
assign debug_cc_tlp_fifo_rd[0]    = cc_tlp_fifo_rd[0]    ;
assign debug_cc_tlp_fifo_rd[1]    = cc_tlp_fifo_rd[1]    ;
assign debug_cc_tlp_fifo_rd[2]    = cc_tlp_fifo_rd[2]    ;

always_ff @(posedge user_clk) begin
    if (vio_rst) debug_cnt_cc_tlast <= 'd0;
    else if (debug_s_axis_cc_tvalid & debug_s_axis_cc_tready & debug_s_axis_cc_tlast) debug_cnt_cc_tlast <= debug_cnt_cc_tlast + 'd1;
    else;
end

vio_rst vio_rst_0(
  .clk        ( user_clk ),
  .probe_out0 ( vio_rst  )
);

ila_cc_intf ila_cc_intf_inst(
    .clk     ( user_clk                ) ,
    .probe0  ( debug_s_axis_cc_tdata   ) , // [255 : 0]          
    .probe1  ( debug_s_axis_cc_tkeep   ) , // [7   : 0]          
    .probe2  ( debug_s_axis_cc_tlast   ) , // 
    .probe3  ( debug_s_axis_cc_tready  ) , // 
    .probe4  ( debug_s_axis_cc_tuser   ) , //       
    .probe5  ( debug_s_axis_cc_tvalid  ) , //          
    .probe6  ( debug_cc_tlp_fifo_req   ) , // 
    .probe7  ( debug_cc_tlp_fifo_empty ) , //     
    .probe8  ( debug_cc_tlp_fifo_rd    ) , //    
    .probe9  ( debug_cnt_cc_tlast      )   // [31 : 0]           
) ;

end endgenerate
*/                                       

endmodule
