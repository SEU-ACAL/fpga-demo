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

module cq_tlp_split #(
	parameter          BAR_ID      = 3'b0 ,
    parameter [31 : 0] SUB_BAR_L   = 0    ,
    parameter [31 : 0] SUB_BAR_H   = 0   
)(
  // clock and reset
  input                  user_clk           , // input    
  input                  user_reset         , // input 
  // Configuration status
  input        [1   : 0] cfg_max_payload    , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  input        [2   : 0] cfg_max_read_req   , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  input                  cfg_rcb_status     , // input            1 - 128B; 0 - 64B
  // Connect to cq_intf 
  input                  cq_des_fifo_empty  ,
  input        [135 : 0] cq_des_fifo_rdata  , // {tuser[7:0], data[127:0]}
  output                 cq_des_fifo_rd     ,
  // Connect to cq_des_split_fifo
  input                  prog_full          ,
  output logic           wr_en              ,
  output logic [128 : 0] din                  // {attr, tc, tag, req_id, addr_type, byte_remain, dw_consume, dw_consume_shift, nxt_addr}
) ;

localparam SLVERR = 2'b10 ;
localparam DECERR = 2'b10 ;

localparam REQ_TYPE_MWR = 4'b0001 ;
localparam REQ_TYPE_MRD = 4'b0000 ;

logic [1   : 0] cfg_max_payload_int ;

logic [10  : 0] max_pld_size  ; // max payload size in byte
logic [10  : 0] max_pld_size_dw;


logic [7   : 0] tuser          ;
logic [3   : 0] first_be       ;
logic [3   : 0] first_be_invert;
logic [3   : 0] last_be        ;
logic [127 : 0] descriptor     ;
logic [1   : 0] addr_type      ;
logic [61  : 0] address        ;
logic [10  : 0] dword_cnt      ;
logic [3   : 0] req_type       ;
logic [15  : 0] req_id         ;
logic [7   : 0] tag            ;
logic [2   : 0] bar_id         ;
logic [2   : 0] tc             ;
logic [2   : 0] attr           ;

typedef enum logic[1:0] {
    IDLE     ,
    FIRST    ,
    MIDDLE   ,
    LAST
} split_state_t ;
split_state_t cstate, nstate ;

logic           bar_func_hit       ; // Asserted when bar_id matches BAR_ID and req_type is memory write.

logic [63  : 0] saddr              ;
logic [10  : 0] dw_cnt             ;

logic           split_en    = 1'b0 ;
logic [10  : 0] dw_consume         ;
logic [10  : 0] dw_consume_shift   ;
logic [10  : 0] dw_remain = 'd0    ;
logic [63  : 0] nxt_addr    = 'b0  ;
logic           wr_en_int          ;

logic           sub_bar_hit        ;

always_ff @(posedge user_clk) begin
    cfg_max_payload_int <= cfg_max_payload ;
end

always_ff @(posedge user_clk) begin
    max_pld_size <= {11{cfg_max_payload_int == 2'd0}} & 11'd128  |
                    {11{cfg_max_payload_int == 2'd1}} & 11'd256  |
                    {11{cfg_max_payload_int == 2'd2}} & 11'd512  |
                    {11{cfg_max_payload_int == 2'd3}} & 11'd1024 ;
end

assign max_pld_size_dw = {2'b0, max_pld_size[10:2]};

// {tuser[7:0], data[127:0]}
assign {tuser, descriptor} = cq_des_fifo_rdata;

assign first_be = tuser[3:0]  ;
assign last_be  = tuser[7:4]  ;

assign first_be_invert = ~first_be ;

assign addr_type  = 2'b0                ; // AT is used for virtualization.
assign saddr      = descriptor[63:0]    ;
assign dw_cnt     = descriptor[74:64]   ;
assign req_type   = descriptor[78:75]   ;
assign req_id     = descriptor[95:80]   ;
assign tag        = descriptor[103:96]  ;
assign bar_id     = descriptor[114:112] ;
assign tc         = descriptor[123:121] ;
assign attr       = descriptor[126:124] ;

// Check bar id and request type
assign bar_func_hit = ~cq_des_fifo_empty & bar_id == BAR_ID & req_type == REQ_TYPE_MRD ;

assign sub_bar_hit = (SUB_BAR_H == SUB_BAR_L) ? 1'b1 : 
                     (saddr[31:0] < SUB_BAR_H & saddr[31:0] >= SUB_BAR_L) ? 1'b1 : 1'b0;

// FSM 
always_ff @(posedge user_clk) begin
    if (user_reset) begin
        cstate <= IDLE ;
    end else begin
        cstate <= nstate ;
    end
end

always_comb begin
    nstate = IDLE ;
    case(cstate)
        IDLE     : if (prog_full) nstate = IDLE ;
        		   else if (bar_func_hit & dw_cnt > max_pld_size_dw & sub_bar_hit) nstate = FIRST ;
                   else if (bar_func_hit & dw_cnt <= max_pld_size_dw & sub_bar_hit) nstate = LAST ;
        FIRST    : if (prog_full) nstate = FIRST ;
        		   else if (dw_remain > max_pld_size_dw) nstate = MIDDLE ;
        		   else nstate = LAST ;
        MIDDLE   : if (prog_full) nstate = MIDDLE ;
        		   else if (dw_remain > max_pld_size_dw) nstate = MIDDLE ;
                   else nstate = LAST ;
        LAST     : if (prog_full) nstate = LAST ;
        		   else nstate = IDLE ;
    endcase
end

assign cq_des_fifo_rd = cstate == LAST & ~prog_full & ~cq_des_fifo_empty;

assign wr_en_int = cstate inside {FIRST, MIDDLE} & ~prog_full & ~cq_des_fifo_empty;

// cfg_rcb_status : 1 - 128B; 0 - 64B
// To simplify design, always align to n*128Byte RCB  
always_ff @(posedge user_clk) begin
    if (bar_func_hit & cstate == IDLE & dw_cnt <= max_pld_size_dw) begin // no split
    	dw_remain <= 'b0 ;
    end else if (bar_func_hit & cstate == IDLE & dw_cnt > max_pld_size_dw) begin // split
        dw_remain <= dw_cnt - max_pld_size_dw + saddr[6:2];
    end else if (wr_en_int & nstate != LAST) begin
        dw_remain <= dw_remain - max_pld_size_dw ;
    end else if (wr_en_int & nstate == LAST) begin
    	dw_remain <= 'd0 ;
    end else ;
end

always_ff @(posedge user_clk) begin
	if (cstate == IDLE & bar_func_hit & dw_cnt > max_pld_size_dw) begin
		split_en <= 1'b1 ;
	end else if (cstate == LAST) begin
		split_en <= 1'b0 ;
	end else ;
end

always_ff @(posedge user_clk) begin
    if (nstate == FIRST) begin
        dw_consume <= max_pld_size_dw - saddr[6:2] ; // RCB concern
    end else if (nstate == MIDDLE) begin
        dw_consume <= max_pld_size_dw ;
    end else if (nstate == LAST & split_en) begin // split last
        dw_consume <= dw_remain ;
    end else begin // no split
        dw_consume <= dw_cnt ;
    end
end
					  					  
always_ff @(posedge user_clk) begin
    if (bar_func_hit & cstate == IDLE) begin
        //nxt_addr <= saddr + first_be_invert[0] + first_be_invert[1] + first_be_invert[2] + first_be_invert[3];
        case(first_be)
            4'b??10 : nxt_addr <= saddr + 2'd1;
            4'b?100 : nxt_addr <= saddr + 2'd2;
            4'b1000 : nxt_addr <= saddr + 2'd3;
            default : nxt_addr <= saddr;
        endcase
    end else if (wr_en_int) begin
        nxt_addr <= nxt_addr + max_pld_size - nxt_addr[6:0] ;
    end else ;
end

assign dw_consume_shift = dw_consume + nxt_addr[4:2];

always_ff @(posedge user_clk) begin
    wr_en <= cq_des_fifo_rd | wr_en_int ;
end

always_ff @(posedge user_clk) begin
    din <= {129{cq_des_fifo_rd | wr_en_int}} & {attr, tc, tag, req_id, addr_type, dw_remain, dw_consume, dw_consume_shift, nxt_addr} ;
end


endmodule
