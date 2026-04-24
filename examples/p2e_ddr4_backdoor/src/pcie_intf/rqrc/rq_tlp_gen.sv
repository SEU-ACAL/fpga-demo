/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

module rq_tlp_gen (  
  // clock and reset
  input            user_clk              , // input    
  input            user_reset            , // input 
  
  input  [15  : 0] release_tag           , // only used when request is memory read
  
  input            rq_des_fifo_empty     ,
  input  [86  : 0] rq_des_fifo_rdata     , // {wrrd, id[1:0], dw_cnt[10:0], add_offset[2:0], last_be[3:0], first_be[3:0], addr[61:0]}
  output           rq_des_fifo_rd        , 
  input            rq_data_fifo_req      , // Not used in RQ interface
  input  [256 : 0] rq_data_fifo_rdata    , // {eop, data[255:0]}, eop is used for generate req
  output           rq_data_fifo_rd       ,

  input            rq_tlp_fifo_full      ,
  output [275 : 0] rq_tlp_fifo_wdata     , // {eop, add_offset[2:0], last_be[3:0], first_be[3:0], tkeep[7:0], data[255:0]}
  output           rq_tlp_fifo_wr        ,

  output [31:0] dbg_rqtlpgen_rd_wdes_cnt,
  output [31:0] dbg_rqtlpgen_rd_rdes_cnt,
  output [17:0] dbg_rqtlpgen_fsm_status  

) ;

logic [127:0] rq_des      ;
logic [3  :0] req_type    ;
logic [2  :0] func_id     ;
logic [10 :0] dw_cnt      ;
logic [10 :0] dw_cnt_shift;
logic [2  :0] add_offset  ;
logic [3  :0] first_be    ;
logic [3  :0] last_be     ;
logic [61 :0] addr        ;
logic [5  :0] tag         ;
logic [3  :0] tag_wreq    ; // tag for write request
logic [3  :0] tag_rreq    ; // tag for read request
logic [7  :0] tkeep_int   ;
logic [7  :0] tkeep       ;

logic wdes_rq_des_fifo_rd;
logic rdes_rq_des_fifo_rd;

logic wdes_rq_tlp_fifo_wr;
logic rdes_rq_tlp_fifo_wr;

logic [19 :0] tctrl;
logic [255:0] tdata;

logic [15 :0] tag_buffer_busy;

logic         tag_available;

typedef enum logic[2:0] {
    IDLE      ,
    WDES      ,
    RDES      ,
    DATA_MID  ,  
    DATA_LAST  
} tlp_gen_t;

tlp_gen_t cstate, nstate;

logic [10  : 0] axis_beat_num;
logic [10  : 0] axis_beat_cnt;

assign req_type = {3'b0, rq_des_fifo_rdata[86]};
//assign func_id = {1'b0, rq_des_fifo_rdata[85:84]}; 
assign func_id = 'b0; // func_id is not used, all functions/agents store ID(AXI ID) in local memory. 
assign dw_cnt = rq_des_fifo_rdata[83 -: 11];
assign add_offset = rq_des_fifo_rdata[72 : 70];
assign last_be = rq_des_fifo_rdata[69 : 66];
assign first_be = rq_des_fifo_rdata[65 : 62];
assign addr = rq_des_fifo_rdata[61 : 0];

always_ff @(posedge user_clk) begin
    if (user_reset) tag_rreq <= 'd0;
    else if (rq_des_fifo_rd & ~rq_des_fifo_empty & ~req_type[0]) tag_rreq <= tag_rreq + 'd1;
    else;
end

assign tag_wreq = 'b0;  // For MWr Req, fix tag to 0

assign tag = {6{req_type[0]}} & {1'b0, 1'b0, tag_wreq} | {6{~req_type[0]}} & {1'b0, 1'b0, tag_rreq}; 

// read tag management
genvar i;
generate for (i = 0; i < 16; i++) begin
    always_ff @(posedge user_clk) begin
        if (user_reset) tag_buffer_busy[i] <= 1'b0;
        else if (rdes_rq_tlp_fifo_wr & i == tag) tag_buffer_busy[i] <= 1'b1;
        else if (release_tag[i]) tag_buffer_busy[i] <= 1'b0;
        else;
    end
end endgenerate

assign tag_available = ~tag_buffer_busy[tag_rreq];

assign dw_cnt_shift = dw_cnt + add_offset;

always_comb begin
    case(dw_cnt_shift[2:0])
        'd1     : tkeep_int = 8'h01;
        'd2     : tkeep_int = 8'h03;
        'd3     : tkeep_int = 8'h07;
        'd4     : tkeep_int = 8'h0f;
        'd5     : tkeep_int = 8'h1f;
        'd6     : tkeep_int = 8'h3f;
        'd7     : tkeep_int = 8'h7f;
        default : tkeep_int = 8'hff;
    endcase 
end

assign rq_des = { 1'b0            , // 127     Force ECRC.
                  3'b0            , // 126:124 Attributes. 
                  3'b0            , // 123:121 Transaction Class. 
                  1'b0            , // 120     Requester ID Enable.
                  16'b0           , // 119:104 Completer ID. Only used for configuration requests and messages
                  {2'b0, tag}     , // 103:96  Tag
                  8'b0            , // 95:88   requester bus number
                  {5'b0, func_id} , // 87:80   function number
                  1'b0            , // 79      poisoned request
                  req_type        , // 78:75   request type
                  dw_cnt          , // 74:64   Dword count
                  addr            , // 63:2    address
                  2'b0              // 1:0     address type
                } ;

assign axis_beat_num = dw_cnt_shift[10:3] + |dw_cnt_shift[2:0];

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
        IDLE      : if (~rq_des_fifo_empty & ~rq_tlp_fifo_full & ~req_type[0] & tag_available) nstate = RDES ;
                    else if (~rq_des_fifo_empty & ~rq_tlp_fifo_full & req_type[0]) nstate = WDES ; // If it is AXI write, descriptor will be write into FIFO at data eop cycle.
                    //else if (~rq_des_fifo_empty & ~rq_tlp_fifo_full & req_type[0] & rq_data_fifo_req) nstate = WDES ; // rq_data_fifo_req is not necessary
                    else nstate = IDLE ;      
        RDES      : nstate = IDLE ; // Will not generate back-to-back TLP 
        WDES      : if (axis_beat_num > 'd1) nstate = DATA_MID ;
                    else nstate = DATA_LAST ;
        DATA_MID  : if (axis_beat_cnt > 'd1) nstate = DATA_MID ;
                    else if(~rq_tlp_fifo_full) nstate = DATA_LAST ;
                    else nstate = DATA_MID;
        DATA_LAST : if(~rq_tlp_fifo_full) nstate = IDLE ; // Will not generate back-to-back TLP
                    else nstate = DATA_LAST;
        default   : nstate = IDLE ;
    endcase
end

always_ff @(posedge user_clk) begin
    if (cstate == IDLE & ~rq_des_fifo_empty & ~rq_tlp_fifo_full) axis_beat_cnt <= axis_beat_num;
    else if (wdes_rq_tlp_fifo_wr) axis_beat_cnt <= axis_beat_cnt - 'd1 ;
    else ;
end

assign wdes_rq_des_fifo_rd = cstate == DATA_LAST & ~rq_tlp_fifo_full;

assign rdes_rq_des_fifo_rd = cstate == RDES ;

assign rq_des_fifo_rd = wdes_rq_des_fifo_rd | rdes_rq_des_fifo_rd;

assign rq_data_fifo_rd = cstate inside {DATA_MID, DATA_LAST} & ~rq_tlp_fifo_full;

assign wdes_rq_tlp_fifo_wr = cstate inside {WDES, DATA_MID, DATA_LAST} & ~rq_tlp_fifo_full;

assign rdes_rq_tlp_fifo_wr = cstate == RDES & ~rq_tlp_fifo_full;

assign rq_tlp_fifo_wr = wdes_rq_tlp_fifo_wr | rdes_rq_tlp_fifo_wr;

assign tkeep = {8{cstate == DATA_LAST}} & tkeep_int | {8{cstate != DATA_LAST}} & {{4{rq_des_fifo_rdata[86]}}, 4'hf} ;

assign tctrl = {cstate == DATA_LAST | cstate == RDES, add_offset[2:0], last_be[3:0], first_be[3:0], tkeep[7:0]} ;

assign tdata = {256{cstate == WDES | cstate == RDES}} & {128'b0, rq_des} | {256{cstate == DATA_MID | cstate == DATA_LAST}} & rq_data_fifo_rdata[255 : 0];

assign rq_tlp_fifo_wdata = {tctrl, tdata} ; // {eop, add_offset[2:0], last_be[3:0], first_be[3:0], tkeep[7:0], data[255:0]}

// --- for debug --- //
logic [31:0] rqtlpgen_rd_wdes_cnt;
logic [31:0] rqtlpgen_rd_rdes_cnt;

always_ff @(posedge user_clk) begin
    if (user_reset) rqtlpgen_rd_wdes_cnt <= 'b0; else if (wdes_rq_des_fifo_rd) rqtlpgen_rd_wdes_cnt <= rqtlpgen_rd_wdes_cnt + 'b1; else;
    if (user_reset) rqtlpgen_rd_rdes_cnt <= 'b0; else if (rdes_rq_des_fifo_rd) rqtlpgen_rd_rdes_cnt <= rqtlpgen_rd_rdes_cnt + 'b1; else;
end

assign dbg_rqtlpgen_rd_wdes_cnt = rqtlpgen_rd_wdes_cnt;
assign dbg_rqtlpgen_rd_rdes_cnt = rqtlpgen_rd_rdes_cnt;

assign dbg_rqtlpgen_fsm_status = {axis_beat_num, rq_des_fifo_empty, rq_tlp_fifo_full, req_type[0], tag_available, cstate}; // 11 + 1+1+1+1 + 3 

endmodule
