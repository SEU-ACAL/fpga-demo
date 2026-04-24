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

module cc_tlp_gen #(
    parameter DEBUG_ON       = "FALSE"  , // "FALSE" or "TRUE"
    parameter integer BAR_ID = 0          
)(

    input                  user_clk                , // input    
    input                  user_reset              , // input

    input                  cc_cmpl_des_fifo_empty  , 
    output                 cc_cmpl_des_fifo_rd     ,
    input        [60  : 0] cc_cmpl_des_fifo_rdata  , // {laddr[6:0], tag[7:0], req_id[15:0], tc[2:0], attr[2:0], dw_cnt[10:0], byte_cnt[12:0]}
    input                  cc_cmpl_data_fifo_req   ,
    input                  cc_cmpl_data_fifo_empty ,
    output                 cc_cmpl_data_fifo_rd    ,
    input        [257 : 0] cc_cmpl_data_fifo_rdata , // {eop, error, data[255:0]}
    
    input                  cc_tlp_fifo_full        , // Unused, Flow control in <cq_axi_mm_rd> will make sure that FIFO will not overflow
    output logic           cc_tlp_fifo_wr          ,
    output logic [266 : 0] cc_tlp_fifo_wdata         // {sop, eop, error, tkeep, data[255:0]}, maybe sop is not used

) ;

// This module could be split and add pipeline if necesary

logic [2   : 0] attr            ;
logic [2   : 0] tc              ;
logic [7   : 0] tag             ;
logic [15  : 0] req_id          ;
logic [1   : 0] addr_type       ;
logic [10  : 0] dw_remain       ;
logic [10  : 0] dw_consume      ;
logic [6   : 0] lower_addr      ;
logic [95  : 0] cc_cmpl_des     ;

logic [12  : 0] dw_cnt          ;
logic [12  : 0] byte_cnt        ;
logic [6   : 0] tlp_beat_num    ;
logic [6   : 0] tlp_beat_remain ;
logic [10  : 0] dw_shift        ;
logic [7   : 0] tkeep           ;
logic [7   : 0] tkeep_int       ;

logic           tlast           ;
logic           discontinue     ;

logic [10  : 0] axis_beat_num   ;
logic [10  : 0] axis_beat_cnt   ;

// for pipeline 
logic           cc_tlp_fifo_wr_int1     ;
logic           cc_tlp_fifo_wr_int2     ;
logic [266 : 0] cc_tlp_fifo_wdata_int1  ; // {sop, eop, error, tkeep, data[255:0]}, maybe sop is not used
logic [266 : 0] cc_tlp_fifo_wdata_int2  ;

typedef enum logic[1:0] {
    IDLE      ,
    DES       ,
    DATA_MID  ,  
    DATA_LAST  
} tlp_gen_t ;

tlp_gen_t cstate, nstate ;

logic [10  : 0] tctrl          ;
logic [255 : 0] tdata          ;

assign {attr, tc, tag, req_id, addr_type, dw_remain, dw_consume, lower_addr} = cc_cmpl_des_fifo_rdata ;
assign dw_cnt  = dw_consume + dw_remain ;
assign byte_cnt = {dw_cnt[10:0], 2'b0};

assign cc_cmpl_des = { 1'b0       , // 95    Force ECRC.
                       attr       , // 94:92 Attributes. Copied from CQ TLP
                       tc         , // 91:89 Transaction Class. copied from CQ TLP
                       1'b1       , // 88    Completer ID Enable.
                       8'b0       , // 87:80 Completer Bus Number. Unused
                       8'b0       , // 79:72 Target Function/Device Number. For EP, 79:75 is RSV; 74:72 is function number
                       tag        , // 71:64 Tag. Copied from CQ TLP
                       req_id     , // 63:48 Requester ID. Copied from CQ TLP
                       1'b0       , // 47    RSV
                       1'b0       , // 46    Poisoned Completion. Unused, use discontinue to indicate read data error.
                       3'b0       , // 45:43 Completion Status.
                       dw_consume , // 42:32 Indicate size of the payload of the current packet in Dwords.
                       2'b0       , // 31:30 RSV
                       1'b0       , // 29    Locked Read Completion
                       byte_cnt   , // 28:16 Indicate the remaining number of bytes required to complete the Request, including the number of bytes returned with the Completion.
                       6'b0       , // 15:10 RSV
                       addr_type  , // 9:8   Address type. Copied from CQ TLP
                       1'b0       , // 7     RSV
                       lower_addr   // 6:0   Lower address. For RCB reason.
                     } ;

assign dw_shift = dw_consume[10:0] + lower_addr[4:2];

assign axis_beat_num = dw_shift[10:3] + |dw_shift[2:0];

always_comb begin // tkeep is always 8'hff except the last beat 
    case(dw_shift[2:0]) 
        'd1     : tkeep_int = 8'h01 ;
        'd2     : tkeep_int = 8'h03 ;
        'd3     : tkeep_int = 8'h07 ;
        'd4     : tkeep_int = 8'h0f ;
        'd5     : tkeep_int = 8'h1f ;
        'd6     : tkeep_int = 8'h3f ;
        'd7     : tkeep_int = 8'h7f ;
        default : tkeep_int = 8'hff ;
    endcase
end

assign {tlast, discontinue} = cc_cmpl_data_fifo_rdata[257 -: 2] ;

// FSM
always_ff @(posedge user_clk) begin
    if (user_reset) begin
        cstate <= IDLE ;
    end else begin
        cstate <= nstate ;
    end
end

// Make sure that data will not interrupt during TLP generation
// Otherwise when rlast received, use req to start the FSM
always_comb begin
    nstate = IDLE ;
    case(cstate)
        IDLE      : //if (cc_cmpl_data_fifo_empty) nstate = IDLE ;
                    if (~cc_cmpl_data_fifo_req) nstate = IDLE ;
                    else nstate = DES ;                  
        DES       : if (axis_beat_num > 'd1) nstate = DATA_MID ;
                    else nstate = DATA_LAST ;
        DATA_MID  : if (axis_beat_cnt > 'd1) nstate = DATA_MID ;
                    else nstate = DATA_LAST ;
        DATA_LAST : nstate = IDLE ;
        default   : nstate = IDLE ;
    endcase
end

always_ff @(posedge user_clk) begin
    //if (cstate == IDLE & ~cc_cmpl_data_fifo_empty) axis_beat_cnt <= axis_beat_num;
    if (cstate == IDLE & cc_cmpl_data_fifo_req) axis_beat_cnt <= axis_beat_num;
    else if (cc_tlp_fifo_wr_int1) axis_beat_cnt <= axis_beat_cnt - 'd1 ;
    else ;
end

assign cc_cmpl_des_fifo_rd = cstate == DATA_LAST ;

//assign cc_cmpl_data_fifo_rd = cstate inside {DATA_MID, DATA_LAST} & ~cc_cmpl_data_fifo_empty;

//assign cc_tlp_fifo_wr_int1 = cstate inside {DES, DATA_MID, DATA_LAST} & ~cc_cmpl_data_fifo_empty;

assign cc_cmpl_data_fifo_rd = cstate inside {DATA_MID, DATA_LAST} ;

assign cc_tlp_fifo_wr_int1 = cstate inside {DES, DATA_MID, DATA_LAST} ;

assign tkeep = {8{cstate == DATA_LAST}} & tkeep_int | {8{cstate != DATA_LAST}} & 8'hff ;

assign tctrl = {cstate == DES, cstate == DATA_LAST, discontinue, tkeep} ;

assign tdata = {256{cstate == DES}} & {160'b0, cc_cmpl_des} | {256{cstate != DES}} & cc_cmpl_data_fifo_rdata[255 : 0];

assign cc_tlp_fifo_wdata_int1 = {tctrl, tdata} ;

always_ff @(posedge user_clk) begin
    cc_tlp_fifo_wr_int2    <= cc_tlp_fifo_wr_int1 ;
    cc_tlp_fifo_wdata_int2 <= cc_tlp_fifo_wdata_int1 ;
end

always_ff @(posedge user_clk) begin
    cc_tlp_fifo_wr    <= cc_tlp_fifo_wr_int2 ;
    cc_tlp_fifo_wdata <= cc_tlp_fifo_wdata_int2 ;
end

// --- for debug --- //
// synthesis translate_off
logic           debug_sop   ;
logic           debug_eop   ;
logic           debug_disc  ;
logic [255 : 0] debug_tdata ;
logic [7   : 0] debug_tkeep ;
logic [31  : 0] debug_dw0   ;
logic [31  : 0] debug_dw1   ;
logic [31  : 0] debug_dw2   ;
logic [31  : 0] debug_dw3   ;
logic [31  : 0] debug_dw4   ;
logic [31  : 0] debug_dw5   ;
logic [31  : 0] debug_dw6   ;
logic [31  : 0] debug_dw7   ;

assign {debug_sop, debug_eop, debug_disc, debug_tkeep, debug_tdata} = cc_tlp_fifo_wdata_int1 ;

assign debug_dw0 = debug_tdata[1*32-1 -: 32] ;
assign debug_dw1 = debug_tdata[2*32-1 -: 32] ;
assign debug_dw2 = debug_tdata[3*32-1 -: 32] ;
assign debug_dw3 = debug_tdata[4*32-1 -: 32] ;
assign debug_dw4 = debug_tdata[5*32-1 -: 32] ;
assign debug_dw5 = debug_tdata[6*32-1 -: 32] ;
assign debug_dw6 = debug_tdata[7*32-1 -: 32] ;
assign debug_dw7 = debug_tdata[8*32-1 -: 32] ;
// synthesis translate_on


// ---------- Debug signals --------- //
                    
generate if (DEBUG_ON == "TRUE" & BAR_ID == 2) begin

logic [31 : 0] tlast_in_cnt;
logic [31 : 0] tlast_out_cnt;

always_ff @(posedge user_clk) begin
    if (user_reset) tlast_in_cnt <= 'd0;
    else if (cc_cmpl_data_fifo_rd & cc_cmpl_data_fifo_rdata[257]) tlast_in_cnt <= tlast_in_cnt + 'd1;
    else;
end

always_ff @(posedge user_clk) begin
    if (user_reset) tlast_out_cnt <= 'd0;
    else if (cc_tlp_fifo_wr_int1 & cc_tlp_fifo_wdata_int1[265]) tlast_out_cnt <= tlast_out_cnt + 'd1;
    else;
end

ila_tlp_gen_1 ila_tlp_gen_1_inst(
    .clk     ( user_clk                    ) ,
    .probe0  ( axis_beat_num               ) , // 11      
    .probe1  ( axis_beat_cnt               ) , // 11        
    .probe2  ( cstate                      ) , // 2       
    .probe3  ( nstate                      ) , // 2  
    .probe4  ( cc_tlp_fifo_wr_int1         ) ,
    .probe5  ( cc_tlp_fifo_wdata_int1[265] ) ,     
    .probe6  ( cc_tlp_fifo_full            ) ,
    .probe7  ( tlast_in_cnt                ) , // 32
    .probe8  ( tlast_out_cnt               ) , // 32
    .probe9  ( cc_cmpl_data_fifo_empty     ) ,
    .probe10 ( cc_cmpl_data_fifo_req       ) 
              
) ;
                   
end endgenerate

endmodule
