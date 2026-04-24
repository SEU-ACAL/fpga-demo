/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

module rc_intf (
  // clock and reset
  input            user_clk          , // input    
  input            user_reset        , // input 
  // RC intf
  input  [255 : 0] m_axis_rc_tdata   , // input  [255 : 0] 
  input  [7   : 0] m_axis_rc_tkeep   , // input  [7   : 0] 
  input            m_axis_rc_tlast   , // input            
  output           m_axis_rc_tready  , // output           
  input  [74  : 0] m_axis_rc_tuser   , // input  [74  : 0] 
  input            m_axis_rc_tvalid  , // input     
  // Connect to tag buffers
  output           tag_buffer_wr     ,
  output [262 : 0] tag_buffer_wdata  , // {tag[3:0], req_completed, func_id[1:0], data[255:0]}

  output [31  : 0] dbg_rcintf_vldpkt_cnt ,
  output [31  : 0] dbg_rcintf_pkt_cnt      
    
) ;

logic       sop_des;

logic [3:0] tag        = 'b0;
logic       completed  = 'b0;
logic [2:0] id         = 'b0;
logic [3:0] error_code = 'b0;

logic       drop_cmpl;

assign sop_des = m_axis_rc_tuser[32];

always_ff @(posedge user_clk) begin
    if (m_axis_rc_tvalid & m_axis_rc_tready & sop_des) begin
        error_code <= m_axis_rc_tdata[15:12];
        completed  <= m_axis_rc_tdata[30];
        tag        <= m_axis_rc_tdata[67:64];
        id         <= m_axis_rc_tdata[50:48]; // req_id field
    end else;
end

assign drop_cmpl = error_code != 4'b0;

assign m_axis_rc_tready = 1'b1; // Tag management in rq_tlp_gen assure that tag_buffer will never overflow

assign tag_buffer_wr = m_axis_rc_tvalid & ~sop_des & ~drop_cmpl;

assign tag_buffer_wdata = {tag, completed & m_axis_rc_tlast, id[1:0], m_axis_rc_tdata};

// --- for debug --- //
logic [31:0] vldpkt_cnt;
logic [31:0] pkt_cnt;

always_ff @(posedge user_clk) begin
    if (user_reset) vldpkt_cnt <= 'b0;
    else if (tag_buffer_wr) vldpkt_cnt <= vldpkt_cnt + 'b1;
    else;
end

always_ff @(posedge user_clk) begin
    if (user_reset) pkt_cnt <= 'b0;
    else if (m_axis_rc_tvalid & m_axis_rc_tready & sop_des) pkt_cnt <= pkt_cnt + 'b1;
    else;
end

assign dbg_rcintf_vldpkt_cnt = vldpkt_cnt;
assign dbg_rcintf_pkt_cnt    = pkt_cnt;


logic        debug_rsv4            ;
logic [2 :0] debug_attr            ;
logic [2 :0] debug_tc              ;
logic        debug_rsv3            ;
logic [15:0] debug_compl_id        ;
logic [7 :0] debug_tag             ;
logic [15:0] debug_req_id          ;
logic        debug_rsv2            ;
logic        debug_poisoned_compl  ;
logic [2 :0] debug_compl_status    ;
logic [10:0] debug_dw_cnt          ;
logic        debug_rsv1            ;
logic        debug_req_complted    ;
logic        debug_locked_rd_compl ;
logic [12:0] debug_byte_cnt        ;
logic [3 :0] debug_error_code      ;
logic [11:0] debug_lower_addr      ;

always_ff @(posedge user_clk) begin
    if (m_axis_rc_tvalid & m_axis_rc_tready & sop_des) 
        { debug_rsv4            ,
          debug_attr            ,
          debug_tc              ,
          debug_rsv3            ,
          debug_compl_id        ,
          debug_tag             ,
          debug_req_id          ,
          debug_rsv2            ,
          debug_poisoned_compl  ,
          debug_compl_status    ,
          debug_dw_cnt          ,
          debug_rsv1            ,
          debug_req_complted    ,
          debug_locked_rd_compl ,
          debug_byte_cnt        ,
          debug_error_code      ,
          debug_lower_addr      } <= m_axis_rc_tdata[95:0];
    else;
end


endmodule
