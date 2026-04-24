/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

module dma_engine #(
    parameter         DEBUG_ON        = "FALSE"                 , // "FALSE" or "TRUE"
    parameter         DMA_DIR         = "WDMA_E2R"              ,
    parameter integer M0_AXI_ID_W     = 1                       , // Master-0
    parameter integer M0_AXI_ADDR_W   = 64                      ,
    parameter integer M0_AXI_DATA_W   = 256                     ,
    parameter         M0_BASE_ADDR    = {{M0_AXI_ADDR_W}{1'b0}} ,
    parameter integer M1_AXI_ID_W     = 1                       , // Master-1
    parameter integer M1_AXI_ADDR_W   = 64                      ,
    parameter integer M1_AXI_DATA_W   = 256                     ,
    parameter         M1_BASE_ADDR    = {{M1_AXI_ADDR_W}{1'b0}}  
)(  
  // clock and reset
  input           clk                             , // input    
  input           rst_p                           ,
  // Configuration status
  input  [1  : 0] cfg_max_payload                 , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  input  [2  : 0] cfg_max_read_req                , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  input           cfg_rcb_status                  , // input            0 - 64B; 1 - 128B
  // DMA registers
  input           dma_start                       , // dma start pulse. 
  input  [63 : 0] dma_des_addr                    , // dma initial description address
  input  [7  : 0] dma_adj_des_num                 , // adjacent description number
  input           ddma_start                      , // direct DMA start pulse
  input  [63 : 0] ddma_saddr                      , // direct DMA source address
  input  [63 : 0] ddma_daddr                      , // direct DMA destination address
  input  [31 : 0] ddma_len                        , // direct DMA length minus one in byte
  // status info
  output          dma_end                         ,
  output          des_blk_end                     ,
  output          des_end                         ,
  output          des_usr_intr                    ,
  output          dma_flush_intr                  ,
  output          dma_done                        , 
  output          dma_busy                        , 
  output [3  : 0] fifo_status                     , // {split_des_fifo_full, split_des_fifo_empty, des_fifo_full, des_fifo_empty}
  output [3  : 0] fifo_error                      , // {split_des_fifo_werr, split_des_fifo_rerr, des_fifo_werr, des_fifo_rerr}
  output [17 : 0] dbg_dma_engine_status           , 
  output [31 : 0] dbg_dma_cnt                     , 
  output [31 : 0] dbg_des_blk_cnt                 , 
  output [31 : 0] dbg_des_cnt                     ,
  output [31 : 0] dbg_des_split_rd_des_cnt        ,
  output [31 : 0] dbg_data_mover_aw_cnt           ,
  output [31 : 0] dbg_data_mover_w_cnt            ,
  output [31 : 0] dbg_data_mover_ar_cnt           ,
  output [31 : 0] dbg_data_mover_r_cnt            ,  

  // AXI to PCIe intf for descriptor fetching
  output [M0_AXI_ID_W-1     : 0] des_axi_awid     , // wr addr
  output [M0_AXI_ADDR_W-1   : 0] des_axi_awaddr   ,   
  output [7                 : 0] des_axi_awlen    ,
  output [2                 : 0] des_axi_awsize   ,
  output [1                 : 0] des_axi_awburst  ,
  output                         des_axi_awlock   , 
  output [3                 : 0] des_axi_awcache  , 
  output [2                 : 0] des_axi_awprot   , 
  output [3                 : 0] des_axi_awqos    , 
  output                         des_axi_awvalid  ,
  input                          des_axi_awready  ,
  output [M0_AXI_DATA_W-1   : 0] des_axi_wdata    , // wr data
  output [M0_AXI_DATA_W/8-1 : 0] des_axi_wstrb    ,
  output                         des_axi_wlast    ,
  output                         des_axi_wvalid   ,
  input                          des_axi_wready   ,
  input  [M0_AXI_ID_W-1     : 0] des_axi_bid      , // wr res
  input  [1                 : 0] des_axi_bresp    ,
  input                          des_axi_bvalid   ,
  output                         des_axi_bready   ,
  output [M0_AXI_ID_W-1     : 0] des_axi_arid     , // rd addr
  output [M0_AXI_ADDR_W-1   : 0] des_axi_araddr   ,
  output [7                 : 0] des_axi_arlen    ,
  output [2                 : 0] des_axi_arsize   ,
  output [1                 : 0] des_axi_arburst  ,
  output                         des_axi_arlock   , 
  output [3                 : 0] des_axi_arcache  , 
  output [2                 : 0] des_axi_arprot   , 
  output [3                 : 0] des_axi_arqos    , 
  output                         des_axi_arvalid  ,
  input                          des_axi_arready  ,
  input  [M0_AXI_ID_W-1     : 0] des_axi_rid      , // rd data
  input  [M0_AXI_DATA_W-1   : 0] des_axi_rdata    ,
  input  [1                 : 0] des_axi_rresp    ,
  input  [0                 : 0] des_axi_rlast    ,
  input                          des_axi_rvalid   ,
  output                         des_axi_rready   ,
  // AXI to PCIe intf for data writing
  output [M0_AXI_ID_W-1     : 0] data_axi_awid     , // wr addr
  output [M0_AXI_ADDR_W-1   : 0] data_axi_awaddr   ,   
  output [7                 : 0] data_axi_awlen    ,
  output [2                 : 0] data_axi_awsize   ,
  output [1                 : 0] data_axi_awburst  ,
  output                         data_axi_awlock   , 
  output [3                 : 0] data_axi_awcache  , 
  output [2                 : 0] data_axi_awprot   , 
  output [3                 : 0] data_axi_awqos    , 
  output                         data_axi_awvalid  ,
  input                          data_axi_awready  ,
  output [M0_AXI_DATA_W-1   : 0] data_axi_wdata    , // wr data
  output [M0_AXI_DATA_W/8-1 : 0] data_axi_wstrb    ,
  output                         data_axi_wlast    ,
  output                         data_axi_wvalid   ,
  input                          data_axi_wready   ,
  input  [M0_AXI_ID_W-1     : 0] data_axi_bid      , // wr res
  input  [1                 : 0] data_axi_bresp    ,
  input                          data_axi_bvalid   ,
  output                         data_axi_bready   ,
  output [M0_AXI_ID_W-1     : 0] data_axi_arid     , // rd addr
  output [M0_AXI_ADDR_W-1   : 0] data_axi_araddr   ,
  output [7                 : 0] data_axi_arlen    ,
  output [2                 : 0] data_axi_arsize   ,
  output [1                 : 0] data_axi_arburst  ,
  output                         data_axi_arlock   , 
  output [3                 : 0] data_axi_arcache  , 
  output [2                 : 0] data_axi_arprot   , 
  output [3                 : 0] data_axi_arqos    , 
  output                         data_axi_arvalid  ,
  input                          data_axi_arready  ,
  input  [M0_AXI_ID_W-1     : 0] data_axi_rid      , // rd data
  input  [M0_AXI_DATA_W-1   : 0] data_axi_rdata    ,
  input  [1                 : 0] data_axi_rresp    ,
  input  [0                 : 0] data_axi_rlast    ,
  input                          data_axi_rvalid   ,
  output                         data_axi_rready   ,
  // AXI to memory intf for data reading
  output [M1_AXI_ID_W-1     : 0] mem_axi_awid     , // wr addr
  output [M1_AXI_ADDR_W-1   : 0] mem_axi_awaddr   ,   
  output [7                 : 0] mem_axi_awlen    ,
  output [2                 : 0] mem_axi_awsize   ,
  output [1                 : 0] mem_axi_awburst  ,
  output                         mem_axi_awlock   , 
  output [3                 : 0] mem_axi_awcache  , 
  output [2                 : 0] mem_axi_awprot   , 
  output [3                 : 0] mem_axi_awqos    , 
  output                         mem_axi_awvalid  ,
  input                          mem_axi_awready  ,
  output [M1_AXI_DATA_W-1   : 0] mem_axi_wdata    , // wr data
  output [M1_AXI_DATA_W/8-1 : 0] mem_axi_wstrb    ,
  output                         mem_axi_wlast    ,
  output                         mem_axi_wvalid   ,
  input                          mem_axi_wready   ,
  input  [M1_AXI_ID_W-1     : 0] mem_axi_bid      , // wr res
  input  [1                 : 0] mem_axi_bresp    ,
  input                          mem_axi_bvalid   ,
  output                         mem_axi_bready   ,
  output [M1_AXI_ID_W-1     : 0] mem_axi_arid     , // rd addr
  output [M1_AXI_ADDR_W-1   : 0] mem_axi_araddr   ,
  output [7                 : 0] mem_axi_arlen    ,
  output [2                 : 0] mem_axi_arsize   ,
  output [1                 : 0] mem_axi_arburst  ,
  output                         mem_axi_arlock   , 
  output [3                 : 0] mem_axi_arcache  , 
  output [2                 : 0] mem_axi_arprot   , 
  output [3                 : 0] mem_axi_arqos    , 
  output                         mem_axi_arvalid  ,
  input                          mem_axi_arready  ,
  input  [M1_AXI_ID_W-1     : 0] mem_axi_rid      , // rd data
  input  [M1_AXI_DATA_W-1   : 0] mem_axi_rdata    ,
  input  [1                 : 0] mem_axi_rresp    ,
  input  [0                 : 0] mem_axi_rlast    ,
  input                          mem_axi_rvalid   ,
  output                         mem_axi_rready   

) ;

logic           des_fifo_wr_sg        ;
logic [162 : 0] des_fifo_wdata_sg     ;
logic           des_fifo_wr_direct    ;
logic [162 : 0] des_fifo_wdata_direct ;

logic           des_fifo_full  ;
logic           des_fifo_pfull ;
logic           des_fifo_wr    ;
logic [162 : 0] des_fifo_wdata ;
logic           des_fifo_empty ;
logic           des_fifo_rd    ;
logic [162 : 0] des_fifo_rdata ;

logic           split_des_fifo_full  ;
logic           split_des_fifo_pfull ;
logic           split_des_fifo_wr    ;
logic [144 : 0] split_des_fifo_wdata ;
logic           split_des_fifo_empty ;
logic           split_des_fifo_rd    ;
logic [144 : 0] split_des_fifo_rdata ;

logic           dma_start_dly        ;
logic           dma_start_int        ;

logic           ddma_start_dly       ;
logic           ddma_start_int       ;

logic           ddma_busy            ;
logic           ddma_done            ;

logic           sgdma_done           ;
logic           sgdma_busy           ;

logic           dma_done_i           ;
logic           dma_busy_i           ;

logic [3  : 0] dbg_des_fetch_fsm         ;
logic [2  : 0] dbg_des_split_status      ;
logic [10 : 0] dbg_data_mover_fsm_status ;

assign dbg_dma_engine_status = {dbg_des_fetch_fsm, dbg_des_split_status, dbg_data_mover_fsm_status};

always_ff @(posedge clk) begin
    dma_start_dly <= dma_start;
end
assign dma_start_int = dma_start & ~dma_start_dly;

always_ff @(posedge clk) begin
    ddma_start_dly <= ddma_start;
end
assign ddma_start_int = ddma_start & ~ddma_start_dly;

always_ff @(posedge clk) begin
    des_fifo_wr_direct    <= ddma_start_int;
    des_fifo_wdata_direct <= {1'b1, 1'b1, 1'b1, ddma_len, ddma_saddr, ddma_daddr};
end

always_ff @(posedge clk) begin
    if (rst_p) ddma_busy <= 1'b0;
    //else if (des_fifo_wr_direct) ddma_busy <= 1'b1;
    else if (ddma_start_int) ddma_busy <= 1'b1;
    else if (ddma_done) ddma_busy <= 1'b0;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) ddma_done <= 1'b0;
    //else if (des_fifo_wr_direct) ddma_done <= 1'b0;
    else if (ddma_start_int) ddma_done <= 1'b0;
    else if (dma_end & ddma_busy) ddma_done <= 1'b1;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) dma_busy_i <= 1'b0;
    else if (ddma_start_int | dma_start_int) dma_busy_i <= 1'b1;
    else if (dma_flush_intr) dma_busy_i <= 1'b0;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) dma_done_i <= 1'b0;
    else if (ddma_start_int | dma_start_int) dma_done_i <= 1'b0;
    else if (dma_flush_intr) dma_done_i <= 1'b1;
    else;
end

assign dma_busy = dma_busy_i;
assign dma_done = dma_done_i;

/*
// ---------- SIM ---------- //
logic  [M0_AXI_ID_W-1    : 0] des_axi_rid_sim      ; // rd data   rid is not used.
logic  [M0_AXI_DATA_W-1  : 0] des_axi_rdata_sim    ;
logic  [1                : 0] des_axi_rresp_sim    ;
logic  [0                : 0] des_axi_rlast_sim    ; // rlast is not used because descriptor has last inside
logic                         des_axi_rvalid_sim   ;

logic [15:0] des_magic_sim   ;
logic [7 :0] des_nxt_adj_sim ;
logic [7 :0] des_ctrl_sim    ;
logic [31:0] des_len_sim     ;
logic [63:0] des_src_addr_sim;
logic [63:0] des_dst_addr_sim;
logic [63:0] des_nxt_addr_sim;
logic [16:0] des_addr_sim    ;

generate if (DMA_DIR == "WDMA_E2R") begin

assign des_axi_rdata_sim = { des_nxt_addr_sim ,  
                             des_dst_addr_sim ,  
                             des_src_addr_sim ,  
                             des_len_sim      ,  
                             des_magic_sim    ,
                             des_nxt_adj_sim  ,
                             des_ctrl_sim     } ;

// case 5
initial begin
    des_nxt_addr_sim = 'b0;
    des_dst_addr_sim = 'b0;
    des_src_addr_sim = 'b0;
    des_len_sim      = 'd255;
    des_magic_sim    = 'h55aa;
    des_nxt_adj_sim  = 'b0;
    des_ctrl_sim     = 'b0;
    des_axi_rlast_sim = 'b0;
    des_axi_rvalid_sim = 'b0;
    @(posedge dma_start_int);
    repeat (5) @(posedge clk);
    des_axi_rvalid_sim <= 1'b1;
    des_axi_rlast_sim  <= 1'b0;
    des_nxt_adj_sim    <= 'b0;
    des_ctrl_sim       <= 'h8;
    des_src_addr_sim   <= 'h0;
    des_dst_addr_sim   <= 'h890000000;
    des_nxt_addr_sim   <= 'h0;
    @(posedge clk);
    des_axi_rvalid_sim <= 1'b1;
    des_axi_rlast_sim  <= 1'b1;
    des_nxt_adj_sim    <= 'b1;
    des_ctrl_sim       <= 'hc;
    des_src_addr_sim   <= 'h80;
    des_dst_addr_sim   <= 'h890000080;
    des_nxt_addr_sim   <= 'h880000080;   
    @(posedge clk);
    des_axi_rvalid_sim <= 1'b0;
    des_axi_rlast_sim  <= 1'b0;
    
    repeat (500) @(posedge clk);
    des_axi_rvalid_sim <= 1'b1;
    des_axi_rlast_sim  <= 1'b0;
    des_nxt_adj_sim    <= 'b0;
    des_ctrl_sim       <= 'h8;
    des_src_addr_sim   <= 'h100;
    des_dst_addr_sim   <= 'h890000100;
    des_nxt_addr_sim   <= 'h0;
    @(posedge clk);
    des_axi_rvalid_sim <= 1'b1;
    des_axi_rlast_sim  <= 1'b1;
    des_nxt_adj_sim    <= 'b1;
    des_ctrl_sim       <= 'hd;
    des_src_addr_sim   <= 'h180;
    des_dst_addr_sim   <= 'h890000180;
    des_nxt_addr_sim   <= 'h0;   
    @(posedge clk);
    des_axi_rvalid_sim <= 1'b0;
    des_axi_rlast_sim  <= 1'b0;    
end
                           
                            
// case 4
assign des_magic_sim = 16'h5a5a;
assign des_nxt_adj_sim = 'b0;   
assign des_nxt_addr_sim = 'b0;    
assign des_dst_addr_sim = 64'h890000000 + des_addr_sim;
assign des_src_addr_sim = des_addr_sim; 
assign des_len_sim = 'd127;   

assign des_axi_rid_sim = 'b0;  
assign des_axi_rresp_sim = 'b0;    

initial begin
    des_axi_rlast_sim  = 'b0;
    des_axi_rvalid_sim = 'b0;
    des_ctrl_sim       = 'b0;
    des_addr_sim       = 'b0;
    @(posedge dma_start_int);
    repeat (5) @(posedge clk);
    des_axi_rvalid_sim <= 1'b1;
    des_addr_sim       <= 'b0;
    des_ctrl_sim       <= 'h8;    
    repeat (15) begin
        @(posedge clk);
        des_axi_rvalid_sim <= 1'b1;
        des_addr_sim       <= des_addr_sim + 'h80;
        des_ctrl_sim       <= 'h8;
    end
    @(posedge clk);
    des_axi_rvalid_sim <= 1'b0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    des_axi_rvalid_sim <= 1'b1;
    des_addr_sim       <= des_addr_sim + 'h80;
    des_ctrl_sim       <= 'hd;    
    des_axi_rlast_sim  <= 1'b1;
    @(posedge clk);
    des_axi_rvalid_sim <= 1'b0;
end

end endgenerate

*/
/*
des_fetch #(
    .DEBUG_ON     ( DEBUG_ON      ) ,
    .DMA_DIR      ( DMA_DIR       ) ,
    .M_AXI_ID_W   ( M0_AXI_ID_W   ) ,
    .M_AXI_ADDR_W ( M0_AXI_ADDR_W ) ,
    .M_AXI_DATA_W ( M0_AXI_DATA_W ) ,
    .M_BASE_ADDR  ( M0_BASE_ADDR  ) 
)des_fetch_i(
    .clk              ( clk              ) , // input
    .rst_p            ( rst_p            ) , // input    
    .cfg_max_payload  ( cfg_max_payload  ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
    .cfg_max_read_req ( cfg_max_read_req ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
    .cfg_rcb_status   ( cfg_rcb_status   ) , // input            0 - 64B; 1 - 128B
    .dma_start        ( dma_start_int    ) , // input            dma start pulse. 
    .dma_des_addr     ( dma_des_addr     ) , // input [63 : 0]   dma initial descriptor address
    .dma_adj_des_num  ( dma_adj_des_num  ) , // input [7  : 0]   adjacent descriptor number
    .data_move_end    ( dma_end          ) , // input
    .dma_done         ( sgdma_done       ) , // output
    .dma_busy         ( sgdma_busy       ) , // output
    // debug signals
    .dbg_des_fetch_fsm( dbg_des_fetch_fsm) ,
    .dbg_dma_cnt      ( dbg_dma_cnt      ) , 
    .dbg_des_blk_cnt  ( dbg_des_blk_cnt  ) , 
    .dbg_des_cnt      ( dbg_des_cnt      ) ,
    // AXI to PCIe intf for descriptor fetching
    .des_axi_awid     ( des_axi_awid     ) , // output [0  : 0]                      
    .des_axi_awaddr   ( des_axi_awaddr   ) , // output [63 : 0]                        
    .des_axi_awlen    ( des_axi_awlen    ) , // output [7  : 0]                       
    .des_axi_awsize   ( des_axi_awsize   ) , // output [2  : 0]                        
    .des_axi_awburst  ( des_axi_awburst  ) , // output [1  : 0]                         
    .des_axi_awlock   ( des_axi_awlock   ) , // output                                 
    .des_axi_awcache  ( des_axi_awcache  ) , // output [3  : 0]                         
    .des_axi_awprot   ( des_axi_awprot   ) , // output [2  : 0]                        
    .des_axi_awqos    ( des_axi_awqos    ) , // output [3  : 0]                       
    .des_axi_awvalid  ( des_axi_awvalid  ) , // output                                  
    .des_axi_awready  ( des_axi_awready  ) , // input                                   
    .des_axi_wdata    ( des_axi_wdata    ) , // output [255: 0]                       
    .des_axi_wstrb    ( des_axi_wstrb    ) , // output [31 : 0]                       
    .des_axi_wlast    ( des_axi_wlast    ) , // output                                
    .des_axi_wvalid   ( des_axi_wvalid   ) , // output                                 
    .des_axi_wready   ( des_axi_wready   ) , // input                                  
    .des_axi_bid      ( des_axi_bid      ) , // input  [0  : 0]                     
    .des_axi_bresp    ( des_axi_bresp    ) , // input  [1  : 0]                       
    .des_axi_bvalid   ( des_axi_bvalid   ) , // input                                  
    .des_axi_bready   ( des_axi_bready   ) , // output                                 
    .des_axi_arid     ( des_axi_arid     ) , // output [0  : 0]                      
    .des_axi_araddr   ( des_axi_araddr   ) , // output [63 : 0]                        
    .des_axi_arlen    ( des_axi_arlen    ) , // output [7  : 0]                       
    .des_axi_arsize   ( des_axi_arsize   ) , // output [2  : 0]                        
    .des_axi_arburst  ( des_axi_arburst  ) , // output [1  : 0]                         
    .des_axi_arlock   ( des_axi_arlock   ) , // output                                 
    .des_axi_arcache  ( des_axi_arcache  ) , // output [3  : 0]                         
    .des_axi_arprot   ( des_axi_arprot   ) , // output [2  : 0]                        
    .des_axi_arqos    ( des_axi_arqos    ) , // output [3  : 0]                       
    .des_axi_arvalid  ( des_axi_arvalid  ) , // output                                  
    .des_axi_arready  ( des_axi_arready  ) , // input                                   
    .des_axi_rid      ( des_axi_rid      ) , // input  [0  : 0]                     
    .des_axi_rdata    ( des_axi_rdata    ) , // input  [255: 0]                       
    .des_axi_rresp    ( des_axi_rresp    ) , // input  [1  : 0]                       
    .des_axi_rlast    ( des_axi_rlast    ) , // input                                 
    .des_axi_rvalid   ( des_axi_rvalid   ) , // input    
//    .des_axi_rid      ( des_axi_rid_sim      ) , // input  [0  : 0]                     
//    .des_axi_rdata    ( des_axi_rdata_sim    ) , // input  [255: 0]                       
//    .des_axi_rresp    ( des_axi_rresp_sim    ) , // input  [1  : 0]                       
//    .des_axi_rlast    ( des_axi_rlast_sim    ) , // input                                 
//    .des_axi_rvalid   ( des_axi_rvalid_sim   ) , // input                                
    .des_axi_rready   ( des_axi_rready   ) , // output
    // intf to des_fifo
    .des_fifo_pfull   ( des_fifo_pfull   ) , // input
    .des_fifo_full    ( des_fifo_full    ) , // input
   // .des_fifo_wr      ( des_fifo_wr_sg   ) , // output
    .des_fifo_wdata   ( des_fifo_wdata_sg)   // output [162: 0]
);
*/
assign  des_fifo_wr_sg =0  ;
assign des_fifo_wr    =des_fifo_wr_direct;

assign des_fifo_wdata = des_fifo_wdata_direct; // des_fifo_wr_sg has higher priority

sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "block" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"  ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 512     ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 163     ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 384     )   // DECIMAL  3 - 4194301
) des_fifo ( // {usr_intr, des_eop, des_len[31:0], des_src_addr[63:0], des_dst_addr[63:0]}
    .clk       ( clk            ) ,
    .srst      ( rst_p          ) ,
    .full      ( des_fifo_full  ) ,
    .din       ( des_fifo_wdata ) ,
    .wr_en     ( des_fifo_wr    ) ,
    .empty     ( des_fifo_empty ) ,
    .dout      ( des_fifo_rdata ) ,
    .rd_en     ( des_fifo_rd    ) ,
    .prog_full ( des_fifo_pfull )
) ;

des_split #(
    .DEBUG_ON ( DEBUG_ON ) ,
    .DMA_DIR  ( DMA_DIR  )
)des_split_i(
    .clk                      ( clk                      ) , // input
    .rst_p                    ( rst_p                    ) , // input    
    .cfg_max_payload          ( cfg_max_payload          ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
    .cfg_max_read_req         ( cfg_max_read_req         ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
    .cfg_rcb_status           ( cfg_rcb_status           ) , // input            0 - 64B; 1 - 128B    
    .des_fifo_empty           ( des_fifo_empty           ) , // input
    .des_fifo_rdata           ( des_fifo_rdata           ) , // input [161 : 0]  {usr_intr, dma_end, des_block_end, des_len[31:0], des_src_addr[63:0], des_dst_addr[63:0]}
    .des_fifo_rd              ( des_fifo_rd              ) , // output
    .split_des_fifo_pfull     ( split_des_fifo_pfull     ) , // input
    .split_des_fifo_wr        ( split_des_fifo_wr        ) , // output
    .split_des_fifo_wdata     ( split_des_fifo_wdata     ) , // output
    .dbg_des_split_status     ( dbg_des_split_status     ) ,
    .dbg_des_split_rd_des_cnt ( dbg_des_split_rd_des_cnt )   

);

sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "distributed" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"        ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 16            ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 145           ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 11            )   // DECIMAL  3 - 4194301
) split_des_fifo ( // {ctrl[3:0], len[12:0], src_addr[63:0], dst_addr[63:0]}
    .clk       ( clk                  ) ,
    .srst      ( rst_p                ) ,
    .full      ( split_des_fifo_full  ) ,
    .din       ( split_des_fifo_wdata ) ,
    .wr_en     ( split_des_fifo_wr    ) ,
    .empty     ( split_des_fifo_empty ) ,
    .dout      ( split_des_fifo_rdata ) ,
    .rd_en     ( split_des_fifo_rd    ) ,
    .prog_full ( split_des_fifo_pfull )
) ;

data_mover #(
    .DEBUG_ON        ( DEBUG_ON      ) ,
    .DMA_DIR         ( DMA_DIR       ) ,
    .M0_AXI_ID_W     ( 1             ) ,
    .M0_AXI_ADDR_W   ( M0_AXI_ADDR_W ) ,
    .M0_AXI_DATA_W   ( M0_AXI_DATA_W ) ,
    .M0_BASE_ADDR    ( M0_BASE_ADDR  ) ,
    .M1_AXI_ID_W     ( 1             ) ,
    .M1_AXI_ADDR_W   ( M1_AXI_ADDR_W ) ,
    .M1_AXI_DATA_W   ( M1_AXI_DATA_W ) ,
    .M1_BASE_ADDR    ( M1_BASE_ADDR  )  
)data_mover_i(
    .clk                  ( clk                  ) , // input
    .rst_p                ( rst_p                ) , // input    
    .split_des_fifo_empty ( split_des_fifo_empty ) , // input
    .split_des_fifo_rdata ( split_des_fifo_rdata ) , // input
    .split_des_fifo_rd    ( split_des_fifo_rd    ) , // output
    .dma_end              ( dma_end              ) , // output
    .des_blk_end          ( des_blk_end          ) , // output
    .des_end              ( des_end              ) , // output
    .des_usr_intr         ( des_usr_intr         ) , // output
    .dma_flush_intr       ( dma_flush_intr       ) , // output
    //
    .dbg_data_mover_fsm_status ( dbg_data_mover_fsm_status ) ,
    .dbg_data_mover_aw_cnt     ( dbg_data_mover_aw_cnt     ) ,
    .dbg_data_mover_w_cnt      ( dbg_data_mover_w_cnt      ) ,
    .dbg_data_mover_ar_cnt     ( dbg_data_mover_ar_cnt     ) ,
    .dbg_data_mover_r_cnt      ( dbg_data_mover_r_cnt      ) ,
    // AXI to PCIe intf for data writing
    .m0_axi_awid    ( data_axi_awid    ) , // output [0  : 0]                      
    .m0_axi_awaddr  ( data_axi_awaddr  ) , // output [63 : 0]                        
    .m0_axi_awlen   ( data_axi_awlen   ) , // output [7  : 0]                       
    .m0_axi_awsize  ( data_axi_awsize  ) , // output [2  : 0]                        
    .m0_axi_awburst ( data_axi_awburst ) , // output [1  : 0]                         
    .m0_axi_awlock  ( data_axi_awlock  ) , // output                                 
    .m0_axi_awcache ( data_axi_awcache ) , // output [3  : 0]                         
    .m0_axi_awprot  ( data_axi_awprot  ) , // output [2  : 0]                        
    .m0_axi_awqos   ( data_axi_awqos   ) , // output [3  : 0]                       
    .m0_axi_awvalid ( data_axi_awvalid ) , // output                                  
    .m0_axi_awready ( data_axi_awready ) , // input                                   
    .m0_axi_wdata   ( data_axi_wdata   ) , // output [255: 0]                       
    .m0_axi_wstrb   ( data_axi_wstrb   ) , // output [31 : 0]                       
    .m0_axi_wlast   ( data_axi_wlast   ) , // output                                
    .m0_axi_wvalid  ( data_axi_wvalid  ) , // output                                 
    .m0_axi_wready  ( data_axi_wready  ) , // input                                  
    .m0_axi_bid     ( data_axi_bid     ) , // input  [0  : 0]                     
    .m0_axi_bresp   ( data_axi_bresp   ) , // input  [1  : 0]                       
    .m0_axi_bvalid  ( data_axi_bvalid  ) , // input                                  
    .m0_axi_bready  ( data_axi_bready  ) , // output                                 
    .m0_axi_arid    ( data_axi_arid    ) , // output [0  : 0]                      
    .m0_axi_araddr  ( data_axi_araddr  ) , // output [63 : 0]                        
    .m0_axi_arlen   ( data_axi_arlen   ) , // output [7  : 0]                       
    .m0_axi_arsize  ( data_axi_arsize  ) , // output [2  : 0]                        
    .m0_axi_arburst ( data_axi_arburst ) , // output [1  : 0]                         
    .m0_axi_arlock  ( data_axi_arlock  ) , // output                                 
    .m0_axi_arcache ( data_axi_arcache ) , // output [3  : 0]                         
    .m0_axi_arprot  ( data_axi_arprot  ) , // output [2  : 0]                        
    .m0_axi_arqos   ( data_axi_arqos   ) , // output [3  : 0]                       
    .m0_axi_arvalid ( data_axi_arvalid ) , // output                                  
    .m0_axi_arready ( data_axi_arready ) , // input                                   
    .m0_axi_rid     ( data_axi_rid     ) , // input  [0  : 0]                     
    .m0_axi_rdata   ( data_axi_rdata   ) , // input  [255: 0]                       
    .m0_axi_rresp   ( data_axi_rresp   ) , // input  [1  : 0]                       
    .m0_axi_rlast   ( data_axi_rlast   ) , // input                                 
    .m0_axi_rvalid  ( data_axi_rvalid  ) , // input                                  
    .m0_axi_rready  ( data_axi_rready  ) , // output   
    // AXI to memory intf for data reading
    .m1_axi_awid    ( mem_axi_awid     ) , // output [0  : 0]                      
    .m1_axi_awaddr  ( mem_axi_awaddr   ) , // output [63 : 0]                        
    .m1_axi_awlen   ( mem_axi_awlen    ) , // output [7  : 0]                       
    .m1_axi_awsize  ( mem_axi_awsize   ) , // output [2  : 0]                        
    .m1_axi_awburst ( mem_axi_awburst  ) , // output [1  : 0]                         
    .m1_axi_awlock  ( mem_axi_awlock   ) , // output                                 
    .m1_axi_awcache ( mem_axi_awcache  ) , // output [3  : 0]                         
    .m1_axi_awprot  ( mem_axi_awprot   ) , // output [2  : 0]                        
    .m1_axi_awqos   ( mem_axi_awqos    ) , // output [3  : 0]                       
    .m1_axi_awvalid ( mem_axi_awvalid  ) , // output                                  
    .m1_axi_awready ( mem_axi_awready  ) , // input                                   
    .m1_axi_wdata   ( mem_axi_wdata    ) , // output [255: 0]                       
    .m1_axi_wstrb   ( mem_axi_wstrb    ) , // output [31 : 0]                       
    .m1_axi_wlast   ( mem_axi_wlast    ) , // output                                
    .m1_axi_wvalid  ( mem_axi_wvalid   ) , // output                                 
    .m1_axi_wready  ( mem_axi_wready   ) , // input                                  
    .m1_axi_bid     ( mem_axi_bid      ) , // input  [0  : 0]                     
    .m1_axi_bresp   ( mem_axi_bresp    ) , // input  [1  : 0]                       
    .m1_axi_bvalid  ( mem_axi_bvalid   ) , // input                                  
    .m1_axi_bready  ( mem_axi_bready   ) , // output                                 
    .m1_axi_arid    ( mem_axi_arid     ) , // output [0  : 0]                      
    .m1_axi_araddr  ( mem_axi_araddr   ) , // output [63 : 0]                        
    .m1_axi_arlen   ( mem_axi_arlen    ) , // output [7  : 0]                       
    .m1_axi_arsize  ( mem_axi_arsize   ) , // output [2  : 0]                        
    .m1_axi_arburst ( mem_axi_arburst  ) , // output [1  : 0]                         
    .m1_axi_arlock  ( mem_axi_arlock   ) , // output                                 
    .m1_axi_arcache ( mem_axi_arcache  ) , // output [3  : 0]                         
    .m1_axi_arprot  ( mem_axi_arprot   ) , // output [2  : 0]                        
    .m1_axi_arqos   ( mem_axi_arqos    ) , // output [3  : 0]                       
    .m1_axi_arvalid ( mem_axi_arvalid  ) , // output                                  
    .m1_axi_arready ( mem_axi_arready  ) , // input                                   
    .m1_axi_rid     ( mem_axi_rid      ) , // input  [0  : 0]                     
    .m1_axi_rdata   ( mem_axi_rdata    ) , // input  [255: 0]                       
    .m1_axi_rresp   ( mem_axi_rresp    ) , // input  [1  : 0]                       
    .m1_axi_rlast   ( mem_axi_rlast    ) , // input                                 
    .m1_axi_rvalid  ( mem_axi_rvalid   ) , // input                                  
    .m1_axi_rready  ( mem_axi_rready   )   // output 
);

// --- for debug --- //

logic des_fifo_werr;
logic des_fifo_rerr;

logic split_des_fifo_werr;
logic split_des_fifo_rerr;

always_ff @(posedge clk) begin
    if (rst_p) des_fifo_werr <= 1'b0;
    else if (des_fifo_wr & des_fifo_full) des_fifo_werr <= 1'b1;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) des_fifo_rerr <= 1'b0;
    else if (des_fifo_rd & des_fifo_empty) des_fifo_rerr <= 1'b1;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) split_des_fifo_werr <= 1'b0;
    else if (split_des_fifo_wr & split_des_fifo_full) split_des_fifo_werr <= 1'b1;
    else;
end

always_ff @(posedge clk) begin
    if (rst_p) split_des_fifo_rerr <= 1'b0;
    else if (split_des_fifo_rd & split_des_fifo_empty) split_des_fifo_rerr <= 1'b1;
    else;
end

assign fifo_status = {split_des_fifo_full, split_des_fifo_empty, des_fifo_full, des_fifo_empty};
assign fifo_error  = {split_des_fifo_werr, split_des_fifo_rerr, des_fifo_werr, des_fifo_rerr};



endmodule
