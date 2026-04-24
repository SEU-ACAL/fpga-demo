/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/

`timescale 1ns/1ps

module data_mover #(
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
  input            clk                  , // input    
  input            rst_p                , // input
  //
  input            split_des_fifo_empty ,
  output           split_des_fifo_rd    ,
  input  [144 : 0] split_des_fifo_rdata , // {ctrl[3:0], len[12:0], src_addr[63:0], dst_addr[63:0]}
  //
  output           dma_end              ,
  output           des_blk_end          , // do not use
  output           des_end              , // do not use
  output           des_usr_intr         ,
  output           dma_flush_intr       ,
  // 
  output [10:0] dbg_data_mover_fsm_status ,
  output [31:0] dbg_data_mover_aw_cnt     ,
  output [31:0] dbg_data_mover_w_cnt      ,
  output [31:0] dbg_data_mover_ar_cnt     ,
  output [31:0] dbg_data_mover_r_cnt      ,

  // AXI to PCIe intf for data writing
  output [M0_AXI_ID_W-1     : 0] m0_axi_awid     , // wr addr
  output [M0_AXI_ADDR_W-1   : 0] m0_axi_awaddr   ,   
  output [7                 : 0] m0_axi_awlen    ,
  output [2                 : 0] m0_axi_awsize   ,
  output [1                 : 0] m0_axi_awburst  ,
  output                         m0_axi_awlock   , 
  output [3                 : 0] m0_axi_awcache  , 
  output [2                 : 0] m0_axi_awprot   , 
  output [3                 : 0] m0_axi_awqos    , 
  output                         m0_axi_awvalid  ,
  input                          m0_axi_awready  ,
  output [M0_AXI_DATA_W-1   : 0] m0_axi_wdata    , // wr data
  output [M0_AXI_DATA_W/8-1 : 0] m0_axi_wstrb    ,
  output                         m0_axi_wlast    ,
  output                         m0_axi_wvalid   ,
  input                          m0_axi_wready   ,
  input  [M0_AXI_ID_W-1     : 0] m0_axi_bid      , // wr res   bid and bresp are not used
  input  [1                 : 0] m0_axi_bresp    ,
  input                          m0_axi_bvalid   ,
  output                         m0_axi_bready   ,
  output [M0_AXI_ID_W-1     : 0] m0_axi_arid     , // rd addr
  output [M0_AXI_ADDR_W-1   : 0] m0_axi_araddr   ,
  output [7                 : 0] m0_axi_arlen    ,
  output [2                 : 0] m0_axi_arsize   ,
  output [1                 : 0] m0_axi_arburst  ,
  output                         m0_axi_arlock   , 
  output [3                 : 0] m0_axi_arcache  , 
  output [2                 : 0] m0_axi_arprot   , 
  output [3                 : 0] m0_axi_arqos    , 
  output                         m0_axi_arvalid  ,
  input                          m0_axi_arready  ,
  input  [M0_AXI_ID_W-1     : 0] m0_axi_rid      , // rd data  rid and rresp are not used
  input  [M0_AXI_DATA_W-1   : 0] m0_axi_rdata    ,
  input  [1                 : 0] m0_axi_rresp    ,
  input  [0                 : 0] m0_axi_rlast    ,
  input                          m0_axi_rvalid   ,
  output                         m0_axi_rready   ,
  // AXI to memory intf for data reading
  output [M1_AXI_ID_W-1     : 0] m1_axi_awid     , // wr addr
  output [M1_AXI_ADDR_W-1   : 0] m1_axi_awaddr   ,   
  output [7                 : 0] m1_axi_awlen    ,
  output [2                 : 0] m1_axi_awsize   ,
  output [1                 : 0] m1_axi_awburst  ,
  output                         m1_axi_awlock   , 
  output [3                 : 0] m1_axi_awcache  , 
  output [2                 : 0] m1_axi_awprot   , 
  output [3                 : 0] m1_axi_awqos    , 
  output                         m1_axi_awvalid  ,
  input                          m1_axi_awready  ,
  output [M1_AXI_DATA_W-1   : 0] m1_axi_wdata    , // wr data
  output [M1_AXI_DATA_W/8-1 : 0] m1_axi_wstrb    ,
  output                         m1_axi_wlast    ,
  output                         m1_axi_wvalid   ,
  input                          m1_axi_wready   ,
  input  [M1_AXI_ID_W-1     : 0] m1_axi_bid      , // wr res   bid and bresp are not used
  input  [1                 : 0] m1_axi_bresp    ,
  input                          m1_axi_bvalid   ,
  output                         m1_axi_bready   ,
  output [M1_AXI_ID_W-1     : 0] m1_axi_arid     , // rd addr
  output [M1_AXI_ADDR_W-1   : 0] m1_axi_araddr   ,
  output [7                 : 0] m1_axi_arlen    ,
  output [2                 : 0] m1_axi_arsize   ,
  output [1                 : 0] m1_axi_arburst  ,
  output                         m1_axi_arlock   , 
  output [3                 : 0] m1_axi_arcache  , 
  output [2                 : 0] m1_axi_arprot   , 
  output [3                 : 0] m1_axi_arqos    , 
  output                         m1_axi_arvalid  ,
  input                          m1_axi_arready  ,
  input  [M1_AXI_ID_W-1     : 0] m1_axi_rid      , // rd data  rid and rresp are not used
  input  [M1_AXI_DATA_W-1   : 0] m1_axi_rdata    ,
  input  [1                 : 0] m1_axi_rresp    ,
  input  [0                 : 0] m1_axi_rlast    ,
  input                          m1_axi_rvalid   ,
  output                         m1_axi_rready   

) ;

// if DMA_DIR is "WDMA_E2R", data will be read from m1 and write to m0; 
// otherwise, data will be read from m0 and write to m1

localparam USER_INTR_DLY = 64;

function automatic int log2 (input int n);
    if (n <=1) return 1; // abort function
    log2 = 0;
    while (n > 1) begin
        n = n/2;
        log2++;
    end
endfunction

logic        usr_intr_int1  ;
logic        dma_end_int    ;
logic        des_blk_end_int;
logic        des_end_int    ;
logic [3 :0] ctrl       ;
logic [12:0] length_int ;
logic [7 :0] length     ;
logic [63:0] src_addr   ; 
logic [63:0] dst_addr   ; 

logic        awvalid;
logic        arvalid;

logic        ostd_fifo_full  ;
logic [10:0] ostd_fifo_wdata ;
logic        ostd_fifo_wr    ;
logic        ostd_fifo_empty ;
logic [10:0] ostd_fifo_rdata ;
logic        ostd_fifo_rd    ;

logic        usr_intr_int2;
logic        usr_intr_ostd;
logic [4 :0] length_int_ostd;
logic [4 :0] dst_addr_ostd;

logic           rdata_sfifo_pfull ; 
logic           rdata_sfifo_full  ; 
logic           rdata_sfifo_wr    ;
logic [256 : 0] rdata_sfifo_wdata ; 
logic           rdata_sfifo_empty ; 
logic           rdata_sfifo_rd    ;
logic [256 : 0] rdata_sfifo_rdata ; 

logic         ostd_out; // read command
logic         ostd_in; // rlast comes back
logic [7 : 0] ostd_cnt;

logic         rlast_in;
logic         rlast_out;
logic [7 : 0] rlast_cnt;
logic         rdata_out_req;
logic         rdata_out_ack;

logic           axi_rlast;
logic [255 : 0] axi_rdata;

logic [USER_INTR_DLY-1:0] des_usr_intr_dly = 'b0;

typedef enum logic [2:0] {
    IDLE       ,
    SRC_RD     ,
    WAIT_RLAST ,
    DST_WR     ,
    WAIT_WLAST    
}state_t;

state_t cstate, nstate;

logic        src_arready;
logic        dst_awready;

logic [31:0] wstrb;
logic [31:0] wstrb_int;

logic wlast;

assign {ctrl, length_int, src_addr, dst_addr} = split_des_fifo_rdata; // length_int is real length, not length minus one

assign usr_intr_int1 = ctrl[0];
assign dma_end_int = ctrl[1];
assign des_blk_end_int = ctrl[2];
assign des_end_int = ctrl[3];

assign length = length_int[12:5] + |length_int[4:0] - 1;

always_ff @(posedge clk) begin
    if (rst_p) cstate <= IDLE;
    else cstate <= nstate;
end

// use pipeline(AXI outstanding) to improve bandwidth
// NOTE that PCIe rq_intf constraint: tvalid must not de-asserted before tlast.
always_comb begin
    nstate = cstate;
    case(cstate)
        IDLE       : if (split_des_fifo_empty) nstate = IDLE; 
                     else if (ostd_fifo_full) nstate = IDLE;
                     else nstate = DST_WR;
        DST_WR     : if (split_des_fifo_empty) nstate = IDLE;
                     else if (ostd_fifo_full) nstate = DST_WR;
                     else if (dst_awready) nstate = SRC_RD;
                     else nstate = DST_WR;
        SRC_RD     : if (ostd_fifo_full) nstate = SRC_RD;
                     else if (src_arready) 
                         if (split_des_fifo_empty) nstate = IDLE; // Never comes here
                         else if (dma_end_int | des_blk_end_int) nstate = IDLE;
                         else nstate = DST_WR;
                     else nstate = SRC_RD;
        default    : nstate = IDLE;
    endcase
end

assign split_des_fifo_rd = (cstate == SRC_RD) & src_arready & ~split_des_fifo_empty & ~ostd_fifo_full;

assign awvalid = cstate == DST_WR & ~ostd_fifo_full;
assign arvalid = cstate == SRC_RD & ~ostd_fifo_full;

assign dma_end = dma_end_int & ostd_cnt == 'd1 & ostd_in & ~ostd_out && cstate == IDLE;
assign des_blk_end = des_blk_end_int & ostd_cnt == 'd1 & ostd_in & ~ostd_out;
assign des_end = split_des_fifo_rd & des_end_int;
assign usr_intr_int2 = des_end & usr_intr_int1;

// outstanding counter
generate if (DMA_DIR == "WDMA_E2R") begin // M1 will only read; M0 will only write
  assign ostd_out = m1_axi_arvalid & m1_axi_arready;
end else begin // M1 will only write; M0 will only read
  assign ostd_out = m0_axi_arvalid & m0_axi_arready;
end endgenerate

assign ostd_in = rdata_sfifo_wr & rdata_sfifo_wdata[256]; 

always_ff @(posedge clk) begin
    if (rst_p) ostd_cnt <= 'b0;
    else case({ostd_out, ostd_in})
        2'b10 : ostd_cnt <= ostd_cnt + 'd1;
        2'b01 : ostd_cnt <= ostd_cnt - 'd1;
    endcase
end

// read data buffer
// read data will be assigned to AXI write data channel
// wvalid must keep high during the burst
generate if (DMA_DIR == "WDMA_E2R") begin // M1 will only read; M0 will only write
  assign m1_axi_rready     = ~rdata_sfifo_full;
  assign rdata_sfifo_wr    = m1_axi_rvalid & ~rdata_sfifo_full;
  assign rdata_sfifo_wdata = {m1_axi_rlast, m1_axi_rdata};
  assign m0_axi_rready = 1'b1;
end else begin // M1 will only write; M0 will only read
  assign m0_axi_rready     = ~rdata_sfifo_full;
  assign rdata_sfifo_wr    = m0_axi_rvalid & ~rdata_sfifo_full;
  assign rdata_sfifo_wdata = {m0_axi_rlast, m0_axi_rdata};
  assign m1_axi_rready = 1'b1;
end endgenerate

sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto"  ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"  ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 64      ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 257     ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 27      )   // DECIMAL  3 - 4194301
) rdata_sfifo ( 
    .clk       ( clk               ) ,
    .srst      ( rst_p             ) ,
    .full      ( rdata_sfifo_full  ) , // not used, only for error detedt
    .din       ( rdata_sfifo_wdata ) ,
    .wr_en     ( rdata_sfifo_wr    ) ,
    .empty     ( rdata_sfifo_empty ) ,
    .dout      ( rdata_sfifo_rdata ) ,
    .rd_en     ( rdata_sfifo_rd    ) ,
    .prog_full ( rdata_sfifo_pfull )
) ; 

assign {axi_rlast, axi_rdata} = rdata_sfifo_rdata;

assign rlast_in = ostd_in;
assign rlast_out = rdata_sfifo_rd & axi_rlast;
always_ff @(posedge clk) begin
    if (rst_p) rlast_cnt <= 'b0;
    else case({rlast_in, rlast_out})
        2'b10 : rlast_cnt <= rlast_cnt + 'd1;
        2'b01 : rlast_cnt <= rlast_cnt - 'd1;
    endcase
end
assign rdata_out_req = rlast_cnt > 'd0 & ~rdata_sfifo_empty;

generate if (DMA_DIR == "WDMA_E2R") begin // M1 will only read; M0 will only write
  assign rdata_out_ack = m0_axi_wready;
end else begin // M1 will only write; M0 will only read
  assign rdata_out_ack = m1_axi_wready;
end endgenerate

assign rdata_sfifo_rd = rdata_out_req & rdata_out_ack;

// Use FIFO to store address and length for supporting outstanding AXI read
assign ostd_fifo_wr = split_des_fifo_rd;
assign ostd_fifo_wdata = {usr_intr_int2, length_int[4:0], dst_addr[4:0]};
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto"  ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"  ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 16      ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 11      ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 11      )   // DECIMAL  3 - 4194301
) axi_rd_ostd_fifo ( 
    .clk       ( clk             ) ,
    .srst      ( rst_p           ) ,
    .full      ( ostd_fifo_full  ) ,
    .din       ( ostd_fifo_wdata ) ,
    .wr_en     ( ostd_fifo_wr    ) ,
    .empty     ( ostd_fifo_empty ) ,
    .dout      ( ostd_fifo_rdata ) ,
    .rd_en     ( ostd_fifo_rd    ) ,
    .prog_full (                 )
) ;
assign wlast = rdata_sfifo_rd & axi_rlast;
assign ostd_fifo_rd = ~ostd_fifo_empty & wlast;
assign {usr_intr_ostd, length_int_ostd, dst_addr_ostd} = ostd_fifo_rdata;
assign wstrb_int = 32'hffffffff >> (~length_int_ostd + 5'd1);
assign wstrb = wstrb_int << dst_addr_ostd;

always_ff @(posedge clk) begin
    des_usr_intr_dly <= {des_usr_intr_dly[USER_INTR_DLY-2:0], ostd_fifo_rd & usr_intr_ostd};
end

assign des_usr_intr = des_usr_intr_dly[USER_INTR_DLY-1];

// --- flush read logic --- //
logic flush_arvalid;
logic flush_aready;
logic flush_start;
logic flush_standy;
logic [31:0]flush_aw_cnt;
logic [31:0]flush_b_cnt;

generate if (DMA_DIR == "WDMA_E2R") begin
    always_ff @(posedge clk) begin
        if (rst_p) flush_aw_cnt <= 16'd0;
        else if(m0_axi_awready && m0_axi_awvalid)flush_aw_cnt <= flush_aw_cnt + 1'b1;
    end
end
else begin
    always_ff @(posedge clk) begin
        if (rst_p) flush_aw_cnt <= 16'd0;
        else if(m1_axi_awready && m1_axi_awvalid)flush_aw_cnt <= flush_aw_cnt + 1'b1;
    end
end endgenerate

generate if (DMA_DIR == "WDMA_E2R") begin
    always_ff @(posedge clk) begin
        if (rst_p) flush_b_cnt <= 16'd0;
        else if(m0_axi_bready && m0_axi_bvalid)flush_b_cnt <= flush_b_cnt + 1'b1;
    end
end
else begin
    always_ff @(posedge clk) begin
        if (rst_p) flush_b_cnt <= 16'd0;
        else if(m1_axi_bready && m1_axi_bvalid)flush_b_cnt <= flush_b_cnt + 1'b1;
    end    
end endgenerate


assign flush_aready = DMA_DIR == "WDMA_E2R" ? m0_axi_arready : m1_axi_arready;


always_ff @(posedge clk) begin
    if (rst_p) flush_standy <= 1'b0;
    else if(dma_end) flush_standy <= 1'b1;
    else if(flush_start) flush_standy <= 1'b0;
end

assign  flush_start = flush_standy && (flush_aw_cnt == flush_b_cnt); //waiting last data

always_ff @(posedge clk) begin
    if (rst_p) flush_arvalid <= 1'b0;
    else if (flush_start) flush_arvalid <= 1'b1;
    else if (flush_aready) flush_arvalid <= 1'b0;
    else;
end

logic flush_rvalid;
logic flush_rready;
logic flush_rlast;
logic flush_read_done;

assign flush_rvalid = DMA_DIR == "WDMA_E2R" ? m0_axi_rvalid : m1_axi_rvalid;
assign flush_rready = DMA_DIR == "WDMA_E2R" ? m0_axi_rready : m1_axi_rready;
assign flush_rlast = DMA_DIR == "WDMA_E2R" ? m0_axi_rlast : m1_axi_rlast;

always_ff @(posedge clk) begin
    if (rst_p) flush_read_done <= 1'b0;
    else if (flush_rready & flush_rvalid & flush_rlast) flush_read_done <= 1'b1;
    else flush_read_done <= 1'b0;
end

assign dma_flush_intr = flush_read_done;

// AXI m1
generate if (DMA_DIR == "WDMA_E2R") begin // M1 will only read; M0 will only write
    // M1 read
    assign m1_axi_arvalid = arvalid                ;
    assign m1_axi_araddr  = src_addr               ;
    assign m1_axi_arlen   = length                 ;
    assign src_arready    = m1_axi_arready         ;
    // M0 write
    assign m0_axi_awvalid = awvalid                ;
    assign m0_axi_awaddr  = dst_addr               ;
    assign m0_axi_awlen   = length                 ;
    assign dst_awready    = m0_axi_awready         ;
    // M1 read to M0 write
    assign m0_axi_wvalid  = rdata_out_req          ;
    assign m0_axi_wdata   = axi_rdata              ; 
    assign m0_axi_wlast   = axi_rlast              ;
    assign m0_axi_wstrb   = axi_rlast ? wstrb : '1 ; 
    // M1 write fixed at zeros
    assign m1_axi_awvalid = 'b0;
    assign m1_axi_awaddr  = 'b0;
    assign m1_axi_awlen   = 'b0;
    assign m1_axi_wvalid  = 'b0;
    assign m1_axi_wdata   = 'b0;
    assign m1_axi_wstrb   = 'b0;
    assign m1_axi_wlast   = 'b0;
    // M0 read fixed at zeros
    assign m0_axi_arvalid = flush_arvalid;
    assign m0_axi_araddr  = dst_addr;
    assign m0_axi_arlen   = 'b0;

end else begin // M1 will only write; M0 will only read
    // M0 read
    assign m0_axi_arvalid = arvalid                ;
    assign m0_axi_araddr  = src_addr               ;
    assign m0_axi_arlen   = length                 ;
    assign src_arready    = m0_axi_arready         ;
    // M1 write
    assign m1_axi_awvalid = awvalid                ;
    assign m1_axi_awaddr  = dst_addr               ;
    assign m1_axi_awlen   = length                 ;
    assign dst_awready    = m1_axi_awready         ;
    // M0 read to M1 write
    assign m1_axi_wvalid  = rdata_out_req          ;
    assign m1_axi_wdata   = axi_rdata              ;
    assign m1_axi_wlast   = axi_rlast              ;
    assign m1_axi_wstrb   = axi_rlast ? wstrb : '1 ;
    // M0 write fixed at zeros
    assign m0_axi_awvalid = 'b0;
    assign m0_axi_awaddr  = 'b0;
    assign m0_axi_awlen   = 'b0;
    assign m0_axi_wvalid  = 'b0;
    assign m0_axi_wdata   = 'b0; 
    assign m0_axi_wlast   = 'b0;
    assign m0_axi_wstrb   = 'b0; 
    // M1 read fixed at zeros
    assign m1_axi_arvalid = flush_arvalid;
    assign m1_axi_araddr  = dst_addr;     
    assign m1_axi_arlen   = 'b0;    
    
end endgenerate

// ---------- Fixed output ---------- //
assign m0_axi_bready   = 'b1                   ; // Never block write response
assign m0_axi_awid     = 'b0                   ; // Unused
assign m0_axi_awburst  = 'b01                  ; // INCR
assign m0_axi_awuser   = 'b0                   ; // Unused
assign m0_axi_awregion = 'b0                   ; // Unused
assign m0_axi_awlock   = 'b00                  ; // Normal access
assign m0_axi_awcache  = 'b0010                ; // Normal Non-cacheable Non-bufferable
assign m0_axi_awprot   = 'b000                 ; // data/secure/Unprivileged access
assign m0_axi_awqos    = 'b0                   ; // Unused
assign m0_axi_wuser    = 'b0                   ; // Unused
assign m0_axi_awsize   = log2(M0_AXI_DATA_W/8) ; // Never use narrow transfer
assign m0_axi_arid     = 'b0                   ; // Unused
assign m0_axi_arburst  = 'b01                  ; // INCR
assign m0_axi_arregion = 'b0                   ; // Unused
assign m0_axi_arlock   = 'b0                   ; // Unused
assign m0_axi_arcache  = 'b0010                ; // Unused
assign m0_axi_arprot   = 'b0                   ; // Unused
assign m0_axi_arqos    = 'b0                   ; // Unused
assign m0_axi_arsize   = log2(M0_AXI_DATA_W/8) ; // Never use narrow transfer

assign m1_axi_bready   = 'b1                   ; // Never block write response
assign m1_axi_awid     = 'b0                   ; // Unused
assign m1_axi_awburst  = 'b01                  ; // INCR
assign m1_axi_awuser   = 'b0                   ; // Unused
assign m1_axi_awregion = 'b0                   ; // Unused
assign m1_axi_awlock   = 'b00                  ; // Normal access
assign m1_axi_awcache  = 'b0010                ; // Normal Non-cacheable Non-bufferable
assign m1_axi_awprot   = 'b000                 ; // data/secure/Unprivileged access
assign m1_axi_awqos    = 'b0                   ; // Unused
assign m1_axi_wuser    = 'b0                   ; // Unused
assign m1_axi_awsize   = log2(M1_AXI_DATA_W/8) ; // Never use narrow transfer
assign m1_axi_arid     = 'b0                   ; // Unused
assign m1_axi_arburst  = 'b01                  ; // INCR
assign m1_axi_arregion = 'b0                   ; // Unused
assign m1_axi_arlock   = 'b0                   ; // Unused
assign m1_axi_arcache  = 'b0010                ; // Unused
assign m1_axi_arprot   = 'b0                   ; // Unused
assign m1_axi_arqos    = 'b0                   ; // Unused
assign m1_axi_arsize   = log2(M1_AXI_DATA_W/8) ; // Never use narrow transfer

// --- for debug ---//

logic [31:0] aw_cnt ;
logic [31:0] w_cnt  ;
logic [31:0] ar_cnt ;
logic [31:0] r_cnt  ;

always_ff @(posedge clk) begin
    if (rst_p) aw_cnt <= 'b0; else if (awvalid & dst_awready)                                       aw_cnt <= aw_cnt + 'b1; else;
    if (rst_p) w_cnt  <= 'b0; else if (rdata_out_req & rdata_out_ack & axi_rlast)                   w_cnt  <= w_cnt  + 'b1; else;
    if (rst_p) ar_cnt <= 'b0; else if (arvalid & src_arready)                                       ar_cnt <= ar_cnt + 'b1; else;
    if (rst_p) r_cnt  <= 'b0; else if (rdata_sfifo_wr & ~rdata_sfifo_full & rdata_sfifo_wdata[256]) r_cnt  <= r_cnt  + 'b1; else;
end

assign dbg_data_mover_aw_cnt = aw_cnt;
assign dbg_data_mover_w_cnt  = w_cnt ;
assign dbg_data_mover_ar_cnt = ar_cnt;
assign dbg_data_mover_r_cnt  = r_cnt ;


assign dbg_data_mover_fsm_status = {rdata_sfifo_empty, rdata_sfifo_full, split_des_fifo_empty, ostd_fifo_full, dst_awready, src_arready, dma_end_int, des_blk_end_int, cstate};


/*
logic [7:0] burst_cnt;
logic       burst_err;

(* keep = "true" *) logic [M0_AXI_ADDR_W-1   : 0] axi_awaddr   ;   
(* keep = "true" *) logic [7                 : 0] axi_awlen    ;
(* keep = "true" *) logic                         axi_awvalid  ;
(* keep = "true" *) logic                         axi_awready  ;
(* keep = "true" *) logic [M0_AXI_DATA_W-1   : 0] axi_wdata    ; 
(* keep = "true" *) logic [M0_AXI_DATA_W/8-1 : 0] axi_wstrb    ;
(* keep = "true" *) logic                         axi_wlast    ;
(* keep = "true" *) logic                         axi_wvalid   ;
(* keep = "true" *) logic                         axi_wready   ;

assign axi_awaddr   = m1_axi_awaddr ;   
assign axi_awlen    = m1_axi_awlen  ;
assign axi_awvalid  = m1_axi_awvalid;
assign axi_awready  = m1_axi_awready;
assign axi_wdata    = m1_axi_wdata  ; 
assign axi_wstrb    = m1_axi_wstrb  ;
assign axi_wlast    = m1_axi_wlast  ;
assign axi_wvalid   = m1_axi_wvalid ;
assign axi_wready   = m1_axi_wready ;

always_ff @(posedge clk) begin
    if (rst_p) burst_cnt <= 'b0;
    else if (axi_wvalid & axi_wready & axi_wlast) burst_cnt <= 'b0;
    else if (axi_wvalid & axi_wready) burst_cnt <= burst_cnt + 'b1;
    else;
end

assign burst_err = axi_wvalid & axi_wready & axi_wlast & burst_cnt != 'd15; // This for fixed burst length debug

generate if (DMA_DIR != "WDMA_E2R" & DEBUG_ON == "TRUE") begin
    ila_dma_data_mover ila_dma_data_mover_i(
        .clk     ( clk          ) ,
        .probe0  ( axi_awvalid  ) ,
        .probe1  ( axi_awready  ) ,
        .probe2  ( axi_awaddr   ) , // 64 
        .probe3  ( axi_awlen    ) , // 8
        .probe4  ( axi_wvalid   ) ,
        .probe5  ( axi_wready   ) ,
        .probe6  ( axi_wdata    ) , // 256
        .probe7  ( axi_wstrb    ) , // 32
        .probe8  ( axi_wlast    ) ,
        .probe9  ( burst_err    ) 
    );
end endgenerate
*/

endmodule
