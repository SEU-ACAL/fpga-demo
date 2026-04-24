/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/

`timescale 1ns/1ps

module des_split #(
    parameter DEBUG_ON = "FALSE"     , // "FALSE" or "TRUE"
    parameter DMA_DIR  = "WDMA_E2R" 
)(  
  // clock and reset
  input            clk                  , // input    
  input            rst_p                , // input
  // Configuration status
  input  [1   : 0] cfg_max_payload      , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  input  [2   : 0] cfg_max_read_req     , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  input            cfg_rcb_status       , // input 0 - 64B; 1 - 128B RCB is only used in read split completion, not used in this module
  //
  input            des_fifo_empty       ,
  output           des_fifo_rd          ,
  input  [162 : 0] des_fifo_rdata       , // {usr_intr, dma_end, des_blk_end, des_len[31:0], des_src_addr[63:0], des_dst_addr[63:0]}
  //
  input                  split_des_fifo_pfull ,
  output logic           split_des_fifo_wr    ,
  output logic [144 : 0] split_des_fifo_wdata ,  // {ctrl[3:0], len[12:0], src_addr[63:0], dst_addr[63:0]}

  output [2 :0] dbg_des_split_status ,
  output [31:0] dbg_des_split_rd_des_cnt         

) ;

/*
  This module will divide descriptor into multiple AXI burst base on below constraint:
    1, AXI burst must not larger than cfg_max_payload/cfg_max_read_req
    2, AXI burst must not crossing 4KB boundary on sorce memory.
    3, AXI burst must not crossing 4KB boundary on destination memory.
*/

logic [1 : 0] cfg_max_payload_int ;
logic [2 : 0] cfg_max_read_req_int;
logic [10: 0] cfg_max_payload_len ;
logic [12: 0] cfg_max_read_req_len;
logic [12: 0] cfg_len             ;

logic        usr_intr       ;
logic        usr_intr_int   ;
logic        dma_end        ;
logic        dma_end_int    ;
logic        des_blk_end    ;
logic        des_blk_end_int;
logic        des_end        ;
logic [31:0] des_len_int    ;
logic [32:0] des_len        ;
logic [63:0] des_src_addr   ;
logic [63:0] des_dst_addr   ;

logic [63:0] src_addr_int  ;
logic        src_addr_c    ;
logic [63:0] dst_addr_int  ;
logic        dst_addr_c    ;
logic [31:0] len_remain_int;
logic        len_remain_c  ;

logic [12:0] len_to_4kb_boundary;

logic [63:0] src_addr  ; 
logic [63:0] dst_addr  ; 
logic [32:0] len_remain;
logic [12:0] addr_step ;

logic split_busy;
logic split_end;

logic           split_des_fifo_wr_int;
logic [144 : 0] split_des_fifo_wdata_int;

always_ff @(posedge clk) begin
    cfg_max_payload_int  <= cfg_max_payload ;
    cfg_max_read_req_int <= cfg_max_read_req;
end

always_ff @(posedge clk) begin
    cfg_max_payload_len <= {11{cfg_max_payload_int == 2'd0}} & 'd128 | 
                           {11{cfg_max_payload_int == 2'd1}} & 'd256 |
                           {11{cfg_max_payload_int == 2'd2}} & 'd512 |
                           {11{cfg_max_payload_int == 2'd3}} & 'd1024;
end

always_ff @(posedge clk) begin
    cfg_max_read_req_len <= {13{cfg_max_read_req_int == 3'd0}} & 'd128 |
                            {13{cfg_max_read_req_int == 3'd1}} & 'd256 |
                            {13{cfg_max_read_req_int == 3'd2}} & 'd512 |
                            {13{cfg_max_read_req_int == 3'd3}} & 'd1024|
                            {13{cfg_max_read_req_int == 3'd4}} & 'd2048|
                            {13{cfg_max_read_req_int == 3'd5}} & 'd4096; 
end

generate if (DMA_DIR == "WDMA_E2R") begin
    always_ff @(posedge clk) begin
        cfg_len <= {2'b0, cfg_max_payload_len};
    end
end else begin
    always_ff @(posedge clk) begin
        cfg_len <= cfg_max_read_req_len;
    end
end endgenerate

assign {usr_intr_int, dma_end_int, des_blk_end_int, des_len_int, des_src_addr, des_dst_addr} = des_fifo_rdata;

assign des_len = des_len_int + 'd1;

// Divide descriptor into multiple AXI burst.

always_ff @(posedge clk) begin
    if (rst_p) split_busy <= 1'b0;
    else if (~des_fifo_empty & ~split_busy) split_busy <= 1'b1;
    else if (split_end & ~split_des_fifo_pfull) split_busy <= 1'b0;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) {src_addr_c, src_addr_int[12:0]} <= 'd0;      
    else if (~des_fifo_empty & ~split_busy) {src_addr_c, src_addr_int[12:0]} <= {1'b0, des_src_addr[12:0]}; // reload
    else if (split_des_fifo_wr_int) {src_addr_c, src_addr_int[12:0]} <= src_addr_int[12:0] + addr_step[12:0];
    else;
end
always_ff @(posedge clk) begin
    if (rst_p) src_addr_int[63:13] <= 'd0;      
    else if (~des_fifo_empty & ~split_busy) src_addr_int[63:13] <= des_src_addr[63:13]; // reload
    else if (split_des_fifo_wr_int & src_addr_c) src_addr_int[63:13] <= src_addr_int[63:13] + 1'b1;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) {dst_addr_c, dst_addr_int[12:0]} <= 'd0;      
    else if (~des_fifo_empty & ~split_busy) {dst_addr_c, dst_addr_int[12:0]} <= {1'b0, des_dst_addr[12:0]}; // reload
    else if (split_des_fifo_wr_int) {dst_addr_c, dst_addr_int[12:0]} <= dst_addr_int[12:0] + addr_step[12:0];
    else;
end
always_ff @(posedge clk) begin
    if (rst_p) dst_addr_int[63:13] <= 'd0;      
    else if (~des_fifo_empty & ~split_busy) dst_addr_int[63:13] <= des_dst_addr[63:13]; // reload
    else if (split_des_fifo_wr_int & dst_addr_c) dst_addr_int[63:13] <= dst_addr_int[63:13] + 1'b1;
    else;
end
                          
always_ff @(posedge clk) begin
    if (rst_p) {len_remain_c, len_remain_int[12:0]} <= 'd0;        
    else if (~des_fifo_empty & ~split_busy) {len_remain_c, len_remain_int[12:0]} <= des_len[12:0] ; // reload
    else if (split_des_fifo_wr_int) {len_remain_c, len_remain_int[12:0]} <= len_remain[12:0] - addr_step[12:0];
    else;
end
always_ff @(posedge clk) begin
    if (rst_p) len_remain_int[31:13] <= 'd0;      
    else if (~des_fifo_empty & ~split_busy) len_remain_int[31:13] <= des_len[31:13]; // reload
    else if (split_des_fifo_wr_int & len_remain_c) len_remain_int[31:13] <= len_remain_int[31:13] - 1'b1;
    else;
end

assign dst_addr = {dst_addr_int[63:13] + dst_addr_c, dst_addr_int[12:0]};
assign src_addr = {src_addr_int[63:13] + src_addr_c, src_addr_int[12:0]};
assign len_remain = {len_remain_int[31:13] - len_remain_c, len_remain_int[12:0]};

assign len_to_4kb_boundary = {13{src_addr[11:0] >  dst_addr[11:0]}} & (13'hfff - src_addr[11:0] + 13'd1) |
                             {13{src_addr[11:0] <= dst_addr[11:0]}} & (13'hfff - dst_addr[11:0] + 13'd1) ;

assign addr_step = {13{len_remain <= cfg_len & len_remain <= len_to_4kb_boundary}} & len_remain[12:0] |
                   {13{cfg_len <= len_remain & cfg_len <= len_to_4kb_boundary}} & cfg_len |
                   {13{len_to_4kb_boundary <= cfg_len & len_to_4kb_boundary <= len_remain}} & len_to_4kb_boundary;                             

assign split_end = len_remain <= len_to_4kb_boundary & len_remain <= cfg_len & ~des_fifo_empty;

// FIFO read/write generate

assign des_fifo_rd = split_busy & ~split_des_fifo_pfull & split_end;

assign split_des_fifo_wr_int = split_busy & ~split_des_fifo_pfull;

assign dma_end = dma_end_int & des_fifo_rd;

assign des_blk_end = des_blk_end_int & des_fifo_rd;

assign des_end = des_fifo_rd;

assign usr_intr = des_end & usr_intr_int;

generate if (DMA_DIR == "WDMA_E2R") begin
    assign split_des_fifo_wdata_int = {{des_end, des_blk_end, dma_end, usr_intr}, addr_step, src_addr, dst_addr};
end else begin
    assign split_des_fifo_wdata_int = {{des_end, des_blk_end, dma_end, usr_intr}, addr_step, src_addr, dst_addr};
end endgenerate

// output register
always_ff @(posedge clk) begin
    split_des_fifo_wr    <= split_des_fifo_wr_int;
    split_des_fifo_wdata <= split_des_fifo_wdata_int;
end


// --- only for debug --- //

logic [31:0] des_cnt; 

logic [3 :0] split_ctrl     ;
logic [12:0] step_len       ;
logic [63:0] src_addr_start ;              
logic [63:0] dst_addr_start ;   
logic        split_fifo_wren;      

logic [63:0] src_addr_end  ;
logic [63:0] dst_addr_end  ;
logic        src_cross_4kb ;
logic        dst_cross_4kb ;
logic        cross_4kb_err ;

logic split_des_fifo_wr_dly;

always_ff @(posedge clk) begin
    if (rst_p) des_cnt <= 'b0;
    else if (des_fifo_rd & ~des_fifo_empty) des_cnt <= des_cnt + 'd1;
    else;
end

assign {split_ctrl, step_len, src_addr_start, dst_addr_start} = split_des_fifo_wdata;

always_ff @(posedge clk) begin
    split_des_fifo_wr_dly <= split_des_fifo_wr;
    src_addr_end <= src_addr_start + step_len - 'd1;
    dst_addr_end <= dst_addr_start + step_len - 'd1;
end

always_ff @(posedge clk) begin
    src_cross_4kb <= (src_addr_end[11:0] < src_addr_start[11:0]) & split_des_fifo_wr_dly;
    dst_cross_4kb <= (dst_addr_end[11:0] < dst_addr_start[11:0]) & split_des_fifo_wr_dly;
end

always_ff @(posedge clk) begin
    if (rst_p) cross_4kb_err <= 1'b0;
    else if (src_cross_4kb | dst_cross_4kb) cross_4kb_err <= 1'b1;
    else;
end

assign dbg_des_split_status = {cross_4kb_err, split_busy, split_end};
assign dbg_des_split_rd_des_cnt = des_cnt;

/*
// AXI crossing 4KB boundary monitor
(* keep = "true" *) logic [3 :0] split_ctrl     ;
(* keep = "true" *) logic [12:0] step_len       ;
(* keep = "true" *) logic [63:0] src_addr_start ;              
(* keep = "true" *) logic [63:0] dst_addr_start ;   
(* keep = "true" *) logic        split_fifo_wren;      

assign {split_ctrl, step_len, src_addr_start, dst_addr_start} = split_des_fifo_wdata;
assign split_fifo_wren = split_des_fifo_wr;

generate if (DMA_DIR == "WDMA_E2R" & DEBUG_ON == "TRUE") begin
    ila_dma_des_split ila_dma_des_split_i(
        .clk      ( clk                  ) ,
        .probe0   ( split_des_fifo_pfull ) , //
        .probe1   ( split_fifo_wren      ) , //   
        .probe2   ( split_ctrl           ) , //  4
        .probe3   ( step_len             ) , //  13
        .probe4   ( src_addr_start       ) , //  64
        .probe5   ( dst_addr_start       )   //  64
    );
end endgenerate
*/

endmodule
