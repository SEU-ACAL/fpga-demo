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

module cqcc_tlp_proc #(
    parameter          DEBUG_ON         = "FALSE"                  , // "FALSE" or "TRUE"
    
    parameter integer  BAR_ID           = 0                        ,
    
    parameter [31 : 0] SUB_BAR_L        = 0                        ,
    parameter [31 : 0] SUB_BAR_H        = 0                        ,

	parameter integer  C_M_AXI_ID_W	    = 1                        ,
	parameter integer  C_M_AXI_ADDR_W   = 64                       ,
	parameter integer  C_M_AXI_DATA_W   = 256                      ,
	parameter integer  C_M_AXI_AWUSER_W = 0                        ,
	parameter integer  C_M_AXI_WUSER_W  = 0                        ,
	parameter integer  C_M_AXI_ARUSER_W = 0                        ,
	parameter integer  C_M_AXI_RUSER_W  = 0                        ,
	parameter integer  C_M_AXI_BUSER_W  = 0                        ,
    parameter          C_M_BASE_ADDR	= {{C_M_AXI_ADDR_W}{1'b0}} 

)(
  // clock and reset
  input            user_clk                      , // input    
  input            user_reset                    , // input 
  // Configuration status
  input  [1   : 0] cfg_max_payload               , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  input  [2   : 0] cfg_max_read_req              , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  input            cfg_rcb_status                , // input            1 - 128B; 0 - 64B
  // Connect to cq_intf 
  input            cq_des_fifo_empty             ,
  input  [135 : 0] cq_des_fifo_rdata             , // {tuser[7:0], data[127:0]}
  output           cq_des_fifo_rd                ,
  input            cq_data_fifo_empty            ,
  input  [291 : 0] cq_data_fifo_rdata            , // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
  output           cq_data_fifo_rd               ,
  // Connect to cc_intf
  output           cc_tlp_fifo_req               , // request when stored the whole TLP
  output           cc_tlp_fifo_empty             ,
  input            cc_tlp_fifo_rd                ,
  output [266 : 0] cc_tlp_fifo_rdata             ,
  // for mmr
  output [7   : 0] fifo_werr                     ,
  // --- AXI-MM-master --- //
  input                           m_axi_aclk     , // Not used
  input                           m_axi_aresetn  , // Not used
  output [C_M_AXI_ID_W-1     : 0] m_axi_awid     , // wr addr
  output [C_M_AXI_ADDR_W-1   : 0] m_axi_awaddr   ,   
  output [7                  : 0] m_axi_awlen    ,
  output [2                  : 0] m_axi_awsize   ,
  output [1                  : 0] m_axi_awburst  ,
  output [C_M_AXI_AWUSER_W-1 : 0] m_axi_awuser   ,
  output                          m_axi_awvalid  ,
  input                           m_axi_awready  ,
  output [3                  : 0] m_axi_awregion , // Unused
  output                          m_axi_awlock   , // Unused
  output [3                  : 0] m_axi_awcache  , // Unused
  output [2                  : 0] m_axi_awprot   , // Unused
  output [3                  : 0] m_axi_awqos    , // Unused
  output [C_M_AXI_DATA_W-1   : 0] m_axi_wdata    , // wr data
  output [C_M_AXI_DATA_W/8-1 : 0] m_axi_wstrb    ,
  output                          m_axi_wlast    ,
  output [C_M_AXI_WUSER_W-1  : 0] m_axi_wuser    ,
  output                          m_axi_wvalid   ,
  input                           m_axi_wready   ,
  input  [C_M_AXI_ID_W-1     : 0] m_axi_bid      , // wr res
  input  [1                  : 0] m_axi_bresp    ,
  input  [C_M_AXI_BUSER_W-1  : 0] m_axi_buser    ,
  input                           m_axi_bvalid   ,
  output                          m_axi_bready   ,
  output [C_M_AXI_ID_W-1     : 0] m_axi_arid     , // rd addr
  output [C_M_AXI_ADDR_W-1   : 0] m_axi_araddr   ,
  output [7                  : 0] m_axi_arlen    ,
  output [2                  : 0] m_axi_arsize   ,
  output [1                  : 0] m_axi_arburst  ,
  output [C_M_AXI_ARUSER_W-1 : 0] m_axi_aruser   ,
  output                          m_axi_arvalid  ,
  input                           m_axi_arready  ,
  output [3                  : 0] m_axi_arregion , // Unused
  output                          m_axi_arlock   , // Unused
  output [3                  : 0] m_axi_arcache  , // Unused
  output [2                  : 0] m_axi_arprot   , // Unused
  output [3                  : 0] m_axi_arqos    , // Unused
  input  [C_M_AXI_ID_W-1     : 0] m_axi_rid      , // rd data
  input  [C_M_AXI_DATA_W-1   : 0] m_axi_rdata    ,
  input  [1                  : 0] m_axi_rresp    ,
  input                           m_axi_rlast    ,
  input  [C_M_AXI_RUSER_W-1  : 0] m_axi_ruser    ,
  input                           m_axi_rvalid   ,
  output                          m_axi_rready   

) ;

logic           cc_cmpl_des_fifo_full   ;
logic           cc_cmpl_des_fifo_pfull  ;
logic           cc_cmpl_des_fifo_wr     ;
logic [60  : 0] cc_cmpl_des_fifo_wdata  ; // {laddr[6:0], tag[7:0], req_id[15:0], tc[2:0], attr[2:0], dw_cnt[10:0], byte_cnt[12:0]}
logic           cc_cmpl_des_fifo_empty  ;
logic           cc_cmpl_des_fifo_rd     ;
logic [60  : 0] cc_cmpl_des_fifo_rdata  ; // {laddr[6:0], tag[7:0], req_id[15:0], tc[2:0], attr[2:0], dw_cnt[10:0], byte_cnt[12:0]}

logic           cc_cmpl_data_fifo_full  ; // 
logic           cc_cmpl_data_fifo_pfull ;
logic           cc_cmpl_data_fifo_wr    ;
logic [257 : 0] cc_cmpl_data_fifo_wdata ; // {eop, error, data} 
logic           cc_cmpl_data_fifo_empty ;
logic           cc_cmpl_data_fifo_rd    ;
logic [257 : 0] cc_cmpl_data_fifo_rdata ;

logic           wch_cq_des_fifo_rd      ; // AXI-MM write channel read
logic           rch_cq_des_fifo_rd      ; // AXI-MM read channel read

logic           cc_tlp_fifo_full        ;
logic           cc_tlp_fifo_wr          ;
logic [266 : 0] cc_tlp_fifo_wdata       ;
logic           cc_tlp_fifo_pfull       ;

logic           cc_cmpl_data_fifo_eop_in  ;
logic           cc_cmpl_data_fifo_eop_out ;
logic [3   : 0] cc_cmpl_data_fifo_eop_cnt ;
logic           cc_cmpl_data_fifo_req     ;

logic           cc_tlp_fifo_eop_in      ;
logic           cc_tlp_fifo_eop_out     ;
logic [8   : 0] cc_tlp_fifo_eop_cnt     ;

assign cq_des_fifo_rd = wch_cq_des_fifo_rd | rch_cq_des_fifo_rd ;

cq_axi_mm_wr #(
    .DEBUG_ON         ( DEBUG_ON         ) ,
    .BAR_ID           ( BAR_ID           ) ,
    .SUB_BAR_L        ( SUB_BAR_L        ) ,
    .SUB_BAR_H        ( SUB_BAR_H        ) ,
	.C_M_AXI_ID_W	  ( C_M_AXI_ID_W	 ) ,
	.C_M_AXI_ADDR_W   ( C_M_AXI_ADDR_W   ) ,
	.C_M_AXI_DATA_W   ( C_M_AXI_DATA_W   ) ,
	.C_M_AXI_AWUSER_W ( C_M_AXI_AWUSER_W ) ,
	.C_M_AXI_WUSER_W  ( C_M_AXI_WUSER_W  ) ,
	.C_M_AXI_ARUSER_W ( C_M_AXI_ARUSER_W ) ,
	.C_M_AXI_RUSER_W  ( C_M_AXI_RUSER_W  ) ,
	.C_M_AXI_BUSER_W  ( C_M_AXI_BUSER_W  ) ,
    .C_M_BASE_ADDR	  ( C_M_BASE_ADDR	 )
) wr_channel (
  .user_clk              ( user_clk              ) , // input    
  .user_reset            ( user_reset            ) , // input 
  .cq_des_fifo_empty     ( cq_des_fifo_empty     ) ,
  .cq_des_fifo_rdata     ( cq_des_fifo_rdata     ) , // {tuser[7:0], data[127:0]}
  .cq_des_fifo_rd        ( wch_cq_des_fifo_rd    ) , // psfifo read is logic OR of every BAR channel's read
  .cq_data_fifo_empty    ( cq_data_fifo_empty    ) ,
  .cq_data_fifo_rdata    ( cq_data_fifo_rdata    ) , // {bar_id[2:0], tlast, tuser[39:8], data[255:0]}
  .cq_data_fifo_rd       ( cq_data_fifo_rd       ) , // psfifo read is logic OR of every BAR channel's read
  .cq_local_mem_wr_error ( cq_local_mem_wr_error ) ,
  .m_axi_aclk            ( m_axi_aclk            ) , // Not used
  .m_axi_aresetn         ( m_axi_aresetn         ) , // Not used
  .m_axi_awid            ( m_axi_awid            ) , // wr addr
  .m_axi_awaddr          ( m_axi_awaddr          ) ,   
  .m_axi_awlen           ( m_axi_awlen           ) ,
  .m_axi_awsize          ( m_axi_awsize          ) ,
  .m_axi_awburst         ( m_axi_awburst         ) ,
  .m_axi_awuser          ( m_axi_awuser          ) ,
  .m_axi_awvalid         ( m_axi_awvalid         ) ,
  .m_axi_awready         ( m_axi_awready         ) ,
  .m_axi_awregion        ( m_axi_awregion        ) , // Unused
  .m_axi_awlock          ( m_axi_awlock          ) , // Unused
  .m_axi_awcache         ( m_axi_awcache         ) , // Unused
  .m_axi_awprot          ( m_axi_awprot          ) , // Unused
  .m_axi_awqos           ( m_axi_awqos           ) , // Unused
  .m_axi_wdata           ( m_axi_wdata           ) , // wr data
  .m_axi_wstrb           ( m_axi_wstrb           ) ,
  .m_axi_wlast           ( m_axi_wlast           ) ,
  .m_axi_wuser           ( m_axi_wuser           ) ,
  .m_axi_wvalid          ( m_axi_wvalid          ) ,
  .m_axi_wready          ( m_axi_wready          ) ,
  .m_axi_bid             ( m_axi_bid             ) , // wr res
  .m_axi_bresp           ( m_axi_bresp           ) ,
  .m_axi_buser           ( m_axi_buser           ) ,
  .m_axi_bvalid          ( m_axi_bvalid          ) ,
  .m_axi_bready          ( m_axi_bready          ) 
) ;

cq_axi_mm_rd #(
    .DEBUG_ON         ( DEBUG_ON         ) ,
    .BAR_ID           ( BAR_ID           ) ,
    .SUB_BAR_L        ( SUB_BAR_L        ) ,
    .SUB_BAR_H        ( SUB_BAR_H        ) ,
	.C_M_AXI_ID_W	  ( C_M_AXI_ID_W	 ) ,
	.C_M_AXI_ADDR_W   ( C_M_AXI_ADDR_W   ) ,
	.C_M_AXI_DATA_W   ( C_M_AXI_DATA_W   ) ,
	.C_M_AXI_AWUSER_W ( C_M_AXI_AWUSER_W ) ,
	.C_M_AXI_WUSER_W  ( C_M_AXI_WUSER_W  ) ,
	.C_M_AXI_ARUSER_W ( C_M_AXI_ARUSER_W ) ,
	.C_M_AXI_RUSER_W  ( C_M_AXI_RUSER_W  ) ,
	.C_M_AXI_BUSER_W  ( C_M_AXI_BUSER_W  ) ,
    .C_M_BASE_ADDR	  ( C_M_BASE_ADDR	 ) 
) rd_channel (
  .user_clk                ( user_clk                ) , // input    
  .user_reset              ( user_reset              ) , // input 
  .cfg_max_payload         ( cfg_max_payload         ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  .cfg_max_read_req        ( cfg_max_read_req        ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  .cfg_rcb_status          ( cfg_rcb_status          ) , // input            1 - 128B; 0 - 64B
  .cq_des_fifo_empty       ( cq_des_fifo_empty       ) ,
  .cq_des_fifo_rdata       ( cq_des_fifo_rdata       ) , // {tuser[7:0], data[127:0]}
  .cq_des_fifo_rd          ( rch_cq_des_fifo_rd      ) , // psfifo read is logic OR of every BAR channel's read
  .cc_cmpl_des_fifo_full   ( cc_cmpl_des_fifo_pfull  ) ,
  .cc_cmpl_des_fifo_wr     ( cc_cmpl_des_fifo_wr     ) ,
  .cc_cmpl_des_fifo_wdata  ( cc_cmpl_des_fifo_wdata  ) , //
  .cc_cmpl_data_fifo_full  ( cc_cmpl_data_fifo_pfull ) , //
  .cc_cmpl_data_fifo_wr    ( cc_cmpl_data_fifo_wr    ) ,
  .cc_cmpl_data_fifo_wdata ( cc_cmpl_data_fifo_wdata ) ,
  .cc_tlp_fifo_pfull       ( cc_tlp_fifo_pfull       ) , 
  .cq_des_split_fifo_werr  ( cq_des_split_fifo_werr  ) ,
  .m_axi_aclk              ( m_axi_aclk              ) , // Not used
  .m_axi_aresetn           ( m_axi_aresetn           ) , // Not used
  .m_axi_arid              ( m_axi_arid              ) , // rd addr
  .m_axi_araddr            ( m_axi_araddr            ) ,
  .m_axi_arlen             ( m_axi_arlen             ) ,
  .m_axi_arsize            ( m_axi_arsize            ) ,
  .m_axi_arburst           ( m_axi_arburst           ) ,
  .m_axi_aruser            ( m_axi_aruser            ) ,
  .m_axi_arvalid           ( m_axi_arvalid           ) ,
  .m_axi_arready           ( m_axi_arready           ) ,
  .m_axi_arregion          ( m_axi_arregion          ) , // Unused
  .m_axi_arlock            ( m_axi_arlock            ) , // Unused
  .m_axi_arcache           ( m_axi_arcache           ) , // Unused
  .m_axi_arprot            ( m_axi_arprot            ) , // Unused
  .m_axi_arqos             ( m_axi_arqos             ) , // Unused
  .m_axi_rid               ( m_axi_rid               ) , // rd data
  .m_axi_rdata             ( m_axi_rdata             ) ,
  .m_axi_rresp             ( m_axi_rresp             ) ,
  .m_axi_rlast             ( m_axi_rlast             ) ,
  .m_axi_ruser             ( m_axi_ruser             ) ,
  .m_axi_rvalid            ( m_axi_rvalid            ) ,
  .m_axi_rready            ( m_axi_rready            )        

) ;

// Change to async clk: wr clock is m_axi_aclk. read ck is user_clk
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "distributed" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"        ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 16            ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 61            ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 10            )   // DECIMAL  3 - 4194301
) cc_cmpl_des_fifo_16x61bits ( // {laddr[6:0], tag[7:0], req_id[15:0], tc[2:0], attr[2:0], dw_cnt[10:0], byte_cnt[12:0]}
    .clk       ( user_clk               ) ,
    .srst      ( user_reset             ) ,
    .full      ( cc_cmpl_des_fifo_full  ) ,
    .din       ( cc_cmpl_des_fifo_wdata ) ,
    .wr_en     ( cc_cmpl_des_fifo_wr    ) ,
    .empty     ( cc_cmpl_des_fifo_empty ) ,
    .dout      ( cc_cmpl_des_fifo_rdata ) ,
    .rd_en     ( cc_cmpl_des_fifo_rd    ) ,
    .prog_full ( cc_cmpl_des_fifo_pfull )
) ;

// Change to async clk: wr clock is m_axi_aclk. read ck is user_clk
// {eop, error, data[255:0]}
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "distributed" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"        ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 16            ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 258           ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 10            )   // DECIMAL  3 - 4194301
) cc_cmpl_data_fifo_16x258bits ( 
    .clk              ( user_clk                ) ,
    .srst             ( user_reset              ) ,
    .full             ( cc_cmpl_data_fifo_full  ) ,
    .din              ( cc_cmpl_data_fifo_wdata ) ,
    .wr_en            ( cc_cmpl_data_fifo_wr    ) ,
    .empty            ( cc_cmpl_data_fifo_empty ) ,
    .dout             ( cc_cmpl_data_fifo_rdata ) ,
    .rd_en            ( cc_cmpl_data_fifo_rd    ) ,
    .prog_full        ( cc_cmpl_data_fifo_pfull ) 
) ;

assign cc_cmpl_data_fifo_eop_in  = cc_cmpl_data_fifo_wr & ~cc_cmpl_data_fifo_full  & cc_cmpl_data_fifo_wdata[257] ;
assign cc_cmpl_data_fifo_eop_out = cc_cmpl_data_fifo_rd & ~cc_cmpl_data_fifo_empty & cc_cmpl_data_fifo_rdata[257] ;

always_ff @(posedge user_clk) begin
    if (user_reset) begin
        cc_cmpl_data_fifo_eop_cnt <= 'd0 ;
    end else begin
        case({cc_cmpl_data_fifo_eop_in, cc_cmpl_data_fifo_eop_out})
            2'b10 : cc_cmpl_data_fifo_eop_cnt <= cc_cmpl_data_fifo_eop_cnt + 'd1 ;
            2'b01 : cc_cmpl_data_fifo_eop_cnt <= cc_cmpl_data_fifo_eop_cnt - 'd1 ;
            default : ;
        endcase
    end
end

// And ~empty is necessary when Cmpl is very short.
// Otherwise req could be asserted when FIFO is still empty because FIFo has read latency.
assign cc_cmpl_data_fifo_req = cc_cmpl_data_fifo_eop_cnt > 'd0 & ~cc_cmpl_data_fifo_empty ;

// Make sure that data will not interrupt during TLP generation
// Otherwise when rlast received, use req to start the FSM
cc_tlp_gen #(
    .DEBUG_ON ( DEBUG_ON ) ,
    .BAR_ID   ( BAR_ID   )
)cc_tlp(
    .user_clk                ( user_clk                ) , // input    
    .user_reset              ( user_reset              ) , // input
    .cc_cmpl_des_fifo_empty  ( cc_cmpl_des_fifo_empty  ) ,
    .cc_cmpl_des_fifo_rd     ( cc_cmpl_des_fifo_rd     ) ,
    .cc_cmpl_des_fifo_rdata  ( cc_cmpl_des_fifo_rdata  ) , // 
    .cc_cmpl_data_fifo_empty ( cc_cmpl_data_fifo_empty ) ,
    .cc_cmpl_data_fifo_req   ( cc_cmpl_data_fifo_req   ) ,
    .cc_cmpl_data_fifo_rd    ( cc_cmpl_data_fifo_rd    ) ,
    .cc_cmpl_data_fifo_rdata ( cc_cmpl_data_fifo_rdata ) ,
    .cc_tlp_fifo_full        ( cc_tlp_fifo_full        ) ,
    .cc_tlp_fifo_wr          ( cc_tlp_fifo_wr          ) ,
    .cc_tlp_fifo_wdata       ( cc_tlp_fifo_wdata       ) 
) ;

sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "block"       ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"        ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 512           ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 267           ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 464           )   // DECIMAL  3 - 4194301
) cc_tlp_fifo_512x267bits ( // {sop, eop, error, tkeep[7:0], data[255:0]}
    .clk              ( user_clk          ) ,
    .srst             ( user_reset        ) ,
    .full             ( cc_tlp_fifo_full  ) ,
    .din              ( cc_tlp_fifo_wdata ) ,
    .wr_en            ( cc_tlp_fifo_wr    ) ,
    .empty            ( cc_tlp_fifo_empty ) ,
    .dout             ( cc_tlp_fifo_rdata ) ,
    .rd_en            ( cc_tlp_fifo_rd    ) ,
    .prog_full        ( cc_tlp_fifo_pfull ) 
) ;

assign cc_tlp_fifo_eop_in  = cc_tlp_fifo_wr & ~cc_tlp_fifo_full  & cc_tlp_fifo_wdata[265] ;
assign cc_tlp_fifo_eop_out = cc_tlp_fifo_rd & ~cc_tlp_fifo_empty & cc_tlp_fifo_rdata[265] ;

always_ff @(posedge user_clk) begin
    if (user_reset) begin
        cc_tlp_fifo_eop_cnt <= 'd0 ;
    end else begin
        case({cc_tlp_fifo_eop_in, cc_tlp_fifo_eop_out})
            2'b10 : cc_tlp_fifo_eop_cnt <= cc_tlp_fifo_eop_cnt + 'd1 ;
            2'b01 : cc_tlp_fifo_eop_cnt <= cc_tlp_fifo_eop_cnt - 'd1 ;
            default : ;
        endcase
    end
end

// And ~empty is necessary when Cmpl is very short.
// Otherwise req could be asserted when FIFO is still empty because FIFo has read latency.
assign cc_tlp_fifo_req = cc_tlp_fifo_eop_cnt > 'd0 & ~cc_tlp_fifo_empty ;

// --- FIFO status --- //
logic cc_cmpl_des_fifo_werr;
logic cc_cmpl_data_fifo_werr;
logic cc_tlp_fifo_werr;

always_ff @(posedge user_clk) begin
    if (user_reset) cc_cmpl_des_fifo_werr <= 1'b0;
    else if (cc_cmpl_des_fifo_wr & cc_cmpl_des_fifo_full) cc_cmpl_des_fifo_werr <= 1'b1;
    else ;
end

always_ff @(posedge user_clk) begin
    if (user_reset) cc_cmpl_data_fifo_werr <= 1'b0;
    else if (cc_cmpl_data_fifo_wr & cc_cmpl_data_fifo_full) cc_cmpl_data_fifo_werr <= 1'b1;
    else ;
end

always_ff @(posedge user_clk) begin
    if (user_reset) cc_tlp_fifo_werr <= 1'b0;
    else if (cc_tlp_fifo_wr & cc_tlp_fifo_full) cc_tlp_fifo_werr <= 1'b1;
    else ;
end

assign fifo_werr = {3'b0,
                    cq_local_mem_wr_error  ,
                    cq_des_split_fifo_werr ,
                    cc_cmpl_des_fifo_werr  ,
                    cc_cmpl_data_fifo_werr ,
                    cc_tlp_fifo_werr       } ;

// ---------- Debug signals --------- //
/*                    
generate if (BAR_ID == 2) begin

logic [31 : 0] cc_cmpl_data_fifo_in_tlast_cnt ;

logic [31 : 0] cc_tlp_gen_in_tlast_cnt ;
logic [31 : 0] cc_tlp_gen_out_tlast_cnt ;

always_ff @(posedge user_clk) begin
    if (user_reset) cc_cmpl_data_fifo_in_tlast_cnt <= 'b0;
    else if (cc_cmpl_data_fifo_wr & cc_cmpl_data_fifo_wdata[257]) cc_cmpl_data_fifo_in_tlast_cnt <= cc_cmpl_data_fifo_in_tlast_cnt + 1'b1;
    else ;
end

always_ff @(posedge user_clk) begin
    if (user_reset) cc_tlp_gen_in_tlast_cnt <= 'b0;
    else if (cc_cmpl_data_fifo_rd & ~cc_cmpl_data_fifo_empty & cc_cmpl_data_fifo_rdata[257]) cc_tlp_gen_in_tlast_cnt <= cc_tlp_gen_in_tlast_cnt + 1'b1;
    else ;
end

always_ff @(posedge user_clk) begin
    if (user_reset) cc_tlp_gen_out_tlast_cnt <= 'b0;
    else if (cc_tlp_fifo_wr & ~cc_tlp_fifo_full & cc_tlp_fifo_wdata[265]) cc_tlp_gen_out_tlast_cnt <= cc_tlp_gen_out_tlast_cnt + 1'b1;
    else ;
end

ila_tlp_gen ila_tlp_gen_inst(
    .clk     ( user_clk                   ) ,
    .probe0  ( cc_tlp_gen_in_tlast_cnt    ) , // 32      
    .probe1  ( cc_tlp_gen_out_tlast_cnt   )   // 32        
     
              
) ;
                   
end endgenerate
*/

endmodule
