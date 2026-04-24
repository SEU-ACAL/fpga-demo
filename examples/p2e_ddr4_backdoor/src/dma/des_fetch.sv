/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

module des_fetch #(
    parameter         DEBUG_ON     = "FALSE"                , // "FALSE" or "TRUE"
    parameter         DMA_DIR      = "WDMA_E2R"             ,
    parameter integer M_AXI_ID_W   = 1                      , 
    parameter integer M_AXI_ADDR_W = 64                     ,
    parameter integer M_AXI_DATA_W = 256                    ,
    parameter         M_BASE_ADDR  = {{M_AXI_ADDR_W}{1'b0}}  
)(  
  // clock and reset
  input            clk              , // input    
  input            rst_p            , // input
  // Configuration status. RCB abd Max payload will not be used in this module
  input  [1   : 0] cfg_max_payload  , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  input            cfg_rcb_status   , // input            0 - 64B; 1 - 128B     
  input  [2   : 0] cfg_max_read_req , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  // DMA registers
  input            dma_start        , // dma start pulse. 
  input  [63  : 0] dma_des_addr     , // dma initial description address
  input  [7   : 0] dma_adj_des_num  , // adjacent description number. Each descriptor is 256bits(32bytes)
  // descriptor fifo
  input            des_fifo_pfull   ,
  input            des_fifo_full    ,
  output           des_fifo_wr      ,
  output [162 : 0] des_fifo_wdata   , // {usr_intr, dma_end, des_block_end, des_len[31:0], des_src_addr[63:0], des_dst_addr[63:0]}
  //
  input            data_move_end    ,
  output logic     dma_done         ,
  output logic     dma_busy         ,
  // for debug
  output [3   : 0] dbg_des_fetch_fsm,
  output [31  : 0] dbg_dma_cnt      , 
  output [31  : 0] dbg_des_blk_cnt  , 
  output [31  : 0] dbg_des_cnt      ,
  // AXI to PCIe intf for descriptor fetching
  output [M_AXI_ID_W-1     : 0] des_axi_awid     , // wr addr  
  output [M_AXI_ADDR_W-1   : 0] des_axi_awaddr   ,   
  output [7                : 0] des_axi_awlen    ,
  output [2                : 0] des_axi_awsize   ,
  output [1                : 0] des_axi_awburst  ,
  output                        des_axi_awlock   , 
  output [3                : 0] des_axi_awcache  , 
  output [2                : 0] des_axi_awprot   , 
  output [3                : 0] des_axi_awqos    , 
  output                        des_axi_awvalid  ,
  input                         des_axi_awready  ,
  output [M_AXI_DATA_W-1   : 0] des_axi_wdata    , // wr data
  output [M_AXI_DATA_W/8-1 : 0] des_axi_wstrb    ,
  output                        des_axi_wlast    ,
  output                        des_axi_wvalid   ,
  input                         des_axi_wready   ,
  input  [M_AXI_ID_W-1     : 0] des_axi_bid      , // wr res    
  input  [1                : 0] des_axi_bresp    ,
  input                         des_axi_bvalid   ,
  output                        des_axi_bready   ,
  output [M_AXI_ID_W-1     : 0] des_axi_arid     , // rd addr
  output [M_AXI_ADDR_W-1   : 0] des_axi_araddr   ,
  output [7                : 0] des_axi_arlen    ,
  output [2                : 0] des_axi_arsize   ,
  output [1                : 0] des_axi_arburst  ,
  output                        des_axi_arlock   , 
  output [3                : 0] des_axi_arcache  , 
  output [2                : 0] des_axi_arprot   , 
  output [3                : 0] des_axi_arqos    , 
  output                        des_axi_arvalid  ,
  input                         des_axi_arready  ,
  input  [M_AXI_ID_W-1     : 0] des_axi_rid      , // rd data   rid is not used.
  input  [M_AXI_DATA_W-1   : 0] des_axi_rdata    ,
  input  [1                : 0] des_axi_rresp    ,
  input  [0                : 0] des_axi_rlast    , // rlast is not used because descriptor has last inside
  input                         des_axi_rvalid   ,
  output                        des_axi_rready    

) ;

// PCIe TLP and AXI operation 4KB boundary crossing issue doesn't exist in this module.
// Because descriptor is in fixed length of 32byte and every decsriptor block will not cross 4KB memory boundary.

function automatic int log2 (input int n);
    if (n <=1) return 1; // abort function
    log2 = 0;
    while (n > 1) begin
        n = n/2;
        log2++;
    end
endfunction

logic [2 :0] cfg_max_read_req_int ;
logic        dma_start_int1       ;
logic [63:0] dma_des_addr_int1    ;
logic [7 :0] dma_adj_des_num_int1 ;   
logic        dma_start_int2       = 'b0;
logic [63:0] dma_des_addr_int2    = 'b0;
logic [7 :0] dma_adj_des_num_int2 = 'b0;   

logic [7:0] max_rd_des_num; // Max read descriptor number
logic [8:0] rd_des_num    ; // read descriptor number, this is adjacent descriptor number plus one
logic [8:0] rd_des_remain ;

logic [15:0] des_magic   ;
logic [7 :0] des_nxt_adj ;
logic [7 :0] des_ctrl    ;
logic [31:0] des_len     ;
logic [63:0] des_src_addr;
logic [63:0] des_dst_addr;
logic [63:0] des_nxt_addr;

logic        usr_intr;

logic        dma_end      ;
logic        des_block_end;
logic        des_dma_start;

typedef enum logic [1:0] {
    IDLE ,
    MID  ,
    LAST    
}state_t;

state_t cstate, nstate;

always_ff @(posedge clk) begin
    cfg_max_read_req_int <= cfg_max_read_req > 'd3 ? 'd3 : cfg_max_read_req; // limitation based on RC re-order buffer size
end

// initial descriptor fecth FSM is started by DMA registers
// the rest descriptor block will be read from CPU storage according descriptors already fetched
always_ff @(posedge clk) begin
    dma_start_int1       <= dma_start | des_dma_start;
    dma_des_addr_int1    <= {64{dma_start}} & dma_des_addr   | {64{des_dma_start}} & des_nxt_addr;
    dma_adj_des_num_int1 <= {8{dma_start}} & dma_adj_des_num | {8{des_dma_start}} & des_nxt_adj;
end

always_ff @(posedge clk) begin
    if (dma_start_int1) dma_start_int2 <= 1'b1;
    else if (~des_fifo_pfull) dma_start_int2 <= 1'b0;
    else;
end

// latch des_addr and adj_des_num
always_ff @(posedge clk) begin
    if (dma_start_int1) begin
        dma_des_addr_int2    <= dma_des_addr_int1;
        dma_adj_des_num_int2 <= dma_adj_des_num_int1;
    end else; 
end 

/*  
cfg_max_read_req - byte number - descriptor number(each descriptor is 256bits, that is 32byte)
    3'd0         -    128      -      4  
    3'd1         -    256      -      8
    3'd2         -    512      -      16
    3'd3         -    1024     -      32
    3'd4         -    2048     -      64
    3'd5         -    4096     -      128
*/
assign max_rd_des_num = {8{cfg_max_read_req_int == 3'd0}} & 'd4  |
                        {8{cfg_max_read_req_int == 3'd1}} & 'd8  |
                        {8{cfg_max_read_req_int == 3'd2}} & 'd16 |
                        {8{cfg_max_read_req_int == 3'd3}} & 'd32 |
                        {8{cfg_max_read_req_int == 3'd4}} & 'd64 |
                        {8{cfg_max_read_req_int == 3'd5}} & 'd128 ;

assign rd_des_num = dma_adj_des_num_int2 + 'd1;

// FSM to divide rd_des_num into multiple max_rd_des_num if necessary.
always_ff @(posedge clk) begin
    if (rst_p) cstate <= IDLE;
    else cstate <= nstate;
end

always_comb begin
    nstate = cstate;
    case(cstate)
        IDLE : if (des_fifo_pfull) nstate = IDLE;
               else if (dma_start_int2 & rd_des_num > max_rd_des_num) nstate = MID;
               else if (dma_start_int2 & rd_des_num <= max_rd_des_num) nstate = LAST;
               else nstate = IDLE;
        MID  : if (des_fifo_pfull | ~des_axi_arready) nstate = MID; // If descriptor FIFO is almost full or axi read address channel block happens, keep FSM unchanged
               else if ((rd_des_remain - max_rd_des_num) > max_rd_des_num) nstate = MID;
               else nstate = LAST;
        LAST : if (des_fifo_pfull | ~des_axi_arready) nstate = LAST;
               else nstate = IDLE;
    endcase
end

always_ff @(posedge clk) begin
    if (rst_p) rd_des_remain <= 'd0;
    else if (dma_start_int2) rd_des_remain <= rd_des_num; // reload
    else if (des_axi_arvalid & des_axi_arready & ~des_fifo_pfull) rd_des_remain <= rd_des_remain - max_rd_des_num;
    else;
end

// read address
// software should make sure that one description block will not cross 4KB boundary!
assign des_axi_arvalid = cstate inside {MID, LAST};
assign des_axi_araddr = dma_des_addr_int2 + ((rd_des_num - rd_des_remain) << 5);
assign des_axi_arlen = {8{cstate == LAST}} & (rd_des_remain[7:0] - 1) | {8{cstate == MID}} & (max_rd_des_num - 1);

// read data
assign des_axi_rready = ~des_fifo_full;
assign des_fifo_wr    = des_axi_rvalid & des_axi_rready;

assign { des_nxt_addr ,  
         des_dst_addr ,  
         des_src_addr ,  
         des_len      ,  
         des_magic    ,
         des_nxt_adj  ,
         des_ctrl     } = des_axi_rdata;

// stop at last descriptor
assign dma_end = des_axi_rlast & des_ctrl[2] & des_ctrl[0]; 

assign des_block_end = des_axi_rlast & des_ctrl[2];

assign usr_intr = des_ctrl[1];

assign des_fifo_wdata = {usr_intr, dma_end, des_block_end, des_len, des_src_addr, des_dst_addr};

// Get information of next descriptor block 
// no stop and no completed at the last descriptor will restart FSM to fetch new descriptors
assign des_dma_start = des_ctrl[2] & ~des_ctrl[0] & des_axi_rvalid & des_axi_rready; 

always_ff @(posedge clk) begin
    if (rst_p) dma_done <= 1'b0;
    else if (dma_start) dma_done <= 1'b0;
    else if (dma_busy & data_move_end) dma_done <= 1'b1;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) dma_busy <= 1'b0;
    else if (dma_start) dma_busy <= 1'b1;
    else if (data_move_end) dma_busy <= 1'b0;
    else;
end

// write address and write data
// This module will not use write address and write data channel.
// Only read address and read data channel will be used.
assign des_axi_awaddr  = 'b0 ;   
assign des_axi_awlen   = 'b0 ;
assign des_axi_awvalid = 'b0 ;
assign des_axi_wdata   = 'b0 ; 
assign des_axi_wstrb   = 'b0 ;
assign des_axi_wlast   = 'b0 ;
assign des_axi_wvalid  = 'b0 ;

// ---------- Fixed output ---------- //
assign des_axi_bready   = 'b1                  ; // Never block write response
assign des_axi_awid     = 'b0                  ; // Unused
assign des_axi_awburst  = 'b01                 ; // INCR
assign des_axi_awuser   = 'b0                  ; // Unused
assign des_axi_awregion = 'b0                  ; // Unused
assign des_axi_awlock   = 'b00                 ; // Normal access
assign des_axi_awcache  = 'b0010               ; // Normal Non-cacheable Non-bufferable
assign des_axi_awprot   = 'b000                ; // data/secure/Unprivileged access
assign des_axi_awqos    = 'b0                  ; // Unused
assign des_axi_wuser    = 'b0                  ; // Unused
assign des_axi_awsize   = log2(M_AXI_DATA_W/8) ; // Never use narrow transfer
assign des_axi_arid     = 'b0                  ; // Unused
assign des_axi_arburst  = 'b01                 ; // INCR
assign des_axi_arregion = 'b0                  ; // Unused
assign des_axi_arlock   = 'b0                  ; // Unused
assign des_axi_arcache  = 'b0010               ; // Unused
assign des_axi_arprot   = 'b0                  ; // Unused
assign des_axi_arqos    = 'b0                  ; // Unused
assign des_axi_arsize   = log2(M_AXI_DATA_W/8) ; // Never use narrow transfer

// --- For debug --- //

logic [31:0] dma_cnt; 
logic [31:0] des_blk_cnt; 
logic [31:0] des_cnt; 

always_ff @(posedge clk) begin
    if (rst_p) dma_cnt <= 'b0;
    else if (dma_start & ~dma_busy) dma_cnt <= dma_cnt + 'd1;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) des_blk_cnt <= 'b0;
    else if (dma_start & ~dma_busy) des_blk_cnt <= 'b0;
    else if (des_fifo_wr & des_block_end) des_blk_cnt <= des_blk_cnt + 'd1;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) des_cnt <= 'b0;
    else if (dma_start & ~dma_busy) des_cnt <= 'b0;
    else if (des_fifo_wr) des_cnt <= des_cnt + 'd1;
    else;
end

assign dbg_des_fetch_fsm = {des_fifo_pfull, des_axi_arready, cstate};

assign dbg_dma_cnt = dma_cnt;
assign dbg_des_blk_cnt = des_blk_cnt;
assign dbg_des_cnt = des_cnt;


// --- ILA --- //
/*
generate if (DMA_DIR != "WDMA_E2R" & DEBUG_ON == "TRUE") begin

(* keep = "true" *) logic        ila_des_fifo_wr ;
(* keep = "true" *) logic [15:0] ila_des_magic   ;
(* keep = "true" *) logic [7 :0] ila_des_nxt_adj ;
(* keep = "true" *) logic [3 :0] ila_des_ctrl    ;
(* keep = "true" *) logic [31:0] ila_des_len     ;
(* keep = "true" *) logic [63:0] ila_des_src_addr;
(* keep = "true" *) logic [63:0] ila_des_dst_addr;
(* keep = "true" *) logic [63:0] ila_des_nxt_addr;

assign ila_des_fifo_wr  =  des_fifo_wr  ;
assign ila_des_magic    =  des_magic    ;
assign ila_des_nxt_adj  =  des_nxt_adj  ;
assign ila_des_ctrl     =  des_ctrl[3:0];
assign ila_des_len      =  des_len      ;
assign ila_des_src_addr =  des_src_addr ;
assign ila_des_dst_addr =  des_dst_addr ;
assign ila_des_nxt_addr =  des_nxt_addr ;


    ila_dma_des_fetch ila_dma_des_fetch_i(
        .clk      ( clk               ) ,
        .probe0   ( dma_start         ) , //   
        .probe1   ( dma_des_addr      ) , //  64 
        .probe2   ( dma_adj_des_num   ) , //  8
        .probe3   ( dma_busy          ) , //
        .probe4   ( data_move_end     ) , //
        .probe5   ( dma_done          ) , //
        .probe6   ( ila_des_fifo_wr   ) , //
        .probe7   ( ila_des_magic     ) , // 16
        .probe8   ( ila_des_nxt_adj   ) , // 8
        .probe9   ( ila_des_ctrl      ) , // 4
        .probe10  ( ila_des_len       ) , // 32
        .probe11  ( ila_des_src_addr  ) , // 64
        .probe12  ( ila_des_dst_addr  ) , // 64
        .probe13  ( ila_des_nxt_addr  ) , // 64
        .probe14  ( dma_cnt     ) , // 32
        .probe15  ( des_blk_cnt ) , // 32
        .probe16  ( des_cnt     )   // 32
    );
end endgenerate
*/

endmodule
