/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

// Outstanding is supported:  awlen, s_axi_awaddr and s_axi_awid are latched 
// to calculate dw_cnt, generate address and func_id at wdata tlast cycle.

module rq_axi_mm_wr #(
    parameter integer S_AXI_ID_W   = 4   , // Slave
    parameter integer S_AXI_ADDR_W = 64  ,
    parameter integer S_AXI_DATA_W = 256 
)(  
  // clock and reset
  input                               user_clk       , // input    
  input                               user_reset     , // input 
  // AXI-MM-slave     
  input                               s_axi_aclk     , // Unused
  input                               s_axi_aresetn  , // Unused
  input        [S_AXI_ID_W-1     : 0] s_axi_awid     , // wr addr
  input        [S_AXI_ADDR_W-1   : 0] s_axi_awaddr   ,
  input        [7                : 0] s_axi_awlen    ,
  input        [2                : 0] s_axi_awsize   ,
  input        [1                : 0] s_axi_awburst  ,
  input        [3                : 0] s_axi_awregion , // Unused
  input                               s_axi_awlock   , // Unused
  input        [3                : 0] s_axi_awcache  , // Unused
  input        [2                : 0] s_axi_awprot   , // Unused
  input        [3                : 0] s_axi_awqos    , // Unused
  input                               s_axi_awvalid  ,
  output                              s_axi_awready  ,
  input        [S_AXI_DATA_W-1   : 0] s_axi_wdata    , // wr data
  input        [S_AXI_DATA_W/8-1 : 0] s_axi_wstrb    ,
  input                               s_axi_wlast    ,
  input                               s_axi_wvalid   ,
  output                              s_axi_wready   ,
  output       [S_AXI_ID_W-1     : 0] s_axi_bid      , // wr res
  output       [1                : 0] s_axi_bresp    ,
  output                              s_axi_bvalid   ,
  input                               s_axi_bready   ,

  output                              wdes_valid        ,          
  output       [86               : 0] wdes              , // {wrrd, id[1:0], dw_cnt[10:0], add_offset[2:0], last_be[3:0], first_be[3:0], addr[61:0]}  
  input                               rq_des_fifo_full  ,          
  output                              wdata_valid       ,          
  output       [256              : 0] wdata             , // {eop, data[255:0]}  
  input                               rq_data_fifo_full ,
  
  output [31 : 0] dbg_rq_waxi_aw_cnt ,
  output [31 : 0] dbg_rq_waxi_w_cnt  ,
  output [5  : 0] dbg_rq_waxi_fifo_status
 
      
) ;

localparam WRRD = 1;

localparam ID_W = S_AXI_ID_W;

logic [10:0] dw_cnt    ;
logic [2 :0] add_offset;
logic [3 :0] first_be  ;
logic [3 :0] last_be   ;
logic [61:0] addr      ;

logic           waddr_sfifo_full  ;
logic           waddr_sfifo_wr    ;
logic [71  : 0] waddr_sfifo_wdata ;
logic           waddr_sfifo_empty ;
logic           waddr_sfifo_rd    ;
logic [71  : 0] waddr_sfifo_rdata ; 

logic           wres_sfifo_full  ;
logic           wres_sfifo_wr    ;
logic [ID_W-1:0]wres_sfifo_wdata ;
logic           wres_sfifo_empty ;
logic           wres_sfifo_rd    ;
logic [ID_W-1:0]wres_sfifo_rdata ;

logic           wlast_sfifo_full  ;
logic           wlast_sfifo_wr    ;
logic           wlast_sfifo_empty ;
logic           wlast_sfifo_rd    ;

logic           wdata_sfifo_full  ;
logic           wdata_sfifo_wr    ;
logic [288 : 0] wdata_sfifo_wdata ; 
logic           wdata_sfifo_empty ;
logic           wdata_sfifo_rd    ;
logic [288 : 0] wdata_sfifo_rdata ; 

logic [7  :0] awlen;
logic [63 :0] awaddr;
logic [255:0] wdata_int;
logic [31 :0] wstrb;
logic         wlast;


// write address channel
assign s_axi_awready = ~waddr_sfifo_full & ~wres_sfifo_full;
assign waddr_sfifo_wr = s_axi_awvalid & s_axi_awready;
assign waddr_sfifo_wdata = {s_axi_awlen, s_axi_awaddr};
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto"  ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"  ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 16      ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 72      ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 11      )   // DECIMAL  3 - 4194301
) waddr_sfifo ( 
    .clk       ( user_clk          ) ,
    .srst      ( user_reset        ) ,
    .full      ( waddr_sfifo_full  ) ,
    .din       ( waddr_sfifo_wdata ) ,
    .wr_en     ( waddr_sfifo_wr    ) ,
    .empty     ( waddr_sfifo_empty ) ,
    .dout      ( waddr_sfifo_rdata ) ,
    .rd_en     ( waddr_sfifo_rd    ) ,
    .prog_full (                   )
) ;

assign {awlen, awaddr} = waddr_sfifo_rdata;

// write response channel
// To make sure that response won't be dropped during outstanding write even s_axi_bready is low
// A 1bit FIFO is used to store write operation
assign wres_sfifo_wr = waddr_sfifo_wr;
assign wres_sfifo_wdata = s_axi_awid;
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto"  ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"  ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 16      ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( ID_W    ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 11      )   // DECIMAL  3 - 4194301
) wres_sfifo ( 
    .clk       ( user_clk         ) ,
    .srst      ( user_reset       ) ,
    .full      ( wres_sfifo_full  ) ,
    .din       ( wres_sfifo_wdata ) ,
    .wr_en     ( wres_sfifo_wr    ) ,
    .empty     ( wres_sfifo_empty ) ,
    .dout      ( wres_sfifo_rdata ) ,
    .rd_en     ( wres_sfifo_rd    ) ,
    .prog_full (                  )
) ;
assign wres_sfifo_rd = s_axi_bvalid & s_axi_bready;

assign wlast_sfifo_wr = s_axi_wvalid & s_axi_wready & s_axi_wlast;
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto"  ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"  ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 32      ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 1       ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 11      )   // DECIMAL  3 - 4194301
) wlast_sfifo ( 
    .clk       ( user_clk          ) ,
    .srst      ( user_reset        ) ,
    .full      ( wlast_sfifo_full  ) ,
    .din       ( 1'b1              ) ,
    .wr_en     ( wlast_sfifo_wr    ) ,
    .empty     ( wlast_sfifo_empty ) ,
    .dout      (                   ) ,
    .rd_en     ( wlast_sfifo_rd    ) ,
    .prog_full (                   )
) ;
assign wlast_sfifo_rd = s_axi_bvalid & s_axi_bready;

assign s_axi_bvalid = ~wres_sfifo_empty & ~wlast_sfifo_empty;
assign s_axi_bid = wres_sfifo_rdata;
assign s_axi_bresp = 'b0;

// write data channel
assign s_axi_wready = ~wdata_sfifo_full & ~wlast_sfifo_full;
assign wdata_sfifo_wr = s_axi_wvalid & s_axi_wready;
assign wdata_sfifo_wdata = {s_axi_wdata[255:0], s_axi_wstrb[31:0], s_axi_wlast};
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto"  ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"  ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 32      ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 289     ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 11      )   // DECIMAL  3 - 4194301
) wdata_sfifo ( 
    .clk       ( user_clk          ) ,
    .srst      ( user_reset        ) ,
    .full      ( wdata_sfifo_full  ) ,
    .din       ( wdata_sfifo_wdata ) ,
    .wr_en     ( wdata_sfifo_wr    ) ,
    .empty     ( wdata_sfifo_empty ) ,
    .dout      ( wdata_sfifo_rdata ) ,
    .rd_en     ( wdata_sfifo_rd    ) ,
    .prog_full (                   )
) ;

assign {wdata_int, wstrb, wlast} = wdata_sfifo_rdata;

// control logic
assign wdata_sfifo_rd = ~rq_des_fifo_full & ~rq_data_fifo_full & ~wdata_sfifo_empty & ~waddr_sfifo_empty;

assign waddr_sfifo_rd = wdata_sfifo_rd & wlast; // dw_cnt is calculated at wlast cycle.

assign wdata_valid = wdata_sfifo_rd;

assign wdes_valid = waddr_sfifo_rd;

// genereta wdes
assign dw_cnt = (awlen << 3) + |wstrb[31:28] + |wstrb[27:24] + |wstrb[23:20] + |wstrb[19:16] +
                               |wstrb[15:12] + |wstrb[11:8]  + |wstrb[7:4]   + |wstrb[3:0];
assign add_offset = awaddr[4:2];
assign first_be = 4'hf;
assign last_be = dw_cnt > 'd1 ? 4'hf : 4'h0;
assign addr = awaddr[63:2];
assign wdes = {WRRD, 2'b0, dw_cnt[10:0], add_offset[2:0], last_be[3:0], first_be[3:0], addr[61:0]};

// generate wdata
assign wdata = {wlast, wdata_int};

// --- for debug --- //

logic [31:0] aw_cnt;
logic [31:0] w_cnt;

always_ff @(posedge user_clk) begin
    if (user_reset) aw_cnt <= 'b0; else if (s_axi_awvalid & s_axi_awready)             aw_cnt <= aw_cnt + 'b1; else;
    if (user_reset) w_cnt  <= 'b0; else if (s_axi_wvalid & s_axi_wready & s_axi_wlast) w_cnt  <= w_cnt  + 'b1; else;
end

assign dbg_rq_waxi_aw_cnt = aw_cnt;
assign dbg_rq_waxi_w_cnt  = w_cnt ;

assign dbg_rq_waxi_fifo_status = {waddr_sfifo_full, waddr_sfifo_empty, wres_sfifo_full, wres_sfifo_empty, wdata_sfifo_full, wdata_sfifo_empty};


endmodule
