/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

module rqrc_tlp_proc #(
    parameter integer S_AXI_ID_W   = 4                      , // Slave
    parameter integer S_AXI_ADDR_W = 64                     ,
    parameter integer S_AXI_DATA_W = 256                    ,
    parameter         S_BASE_ADDR  = {{S_AXI_ADDR_W}{1'b0}} 
)(  
  // clock and reset
  input            user_clk              , // input    
  input            user_reset            , // input 
  // Connect to rq_intf
  output           rq_tlp_fifo_req       ,
  input            rq_tlp_fifo_rd        ,
  output [275 : 0] rq_tlp_fifo_rdata     ,  // {eop, add_offset[2:0], last_be[3:0], first_be[3:0], tkeep[7:0], data[255:0]}
  // Connect to rc_reorder
  output           rc_data_fifo_full     ,
  output           rc_data_fifo_pfull    ,
  input            rc_data_fifo_wr       ,
  input  [258 : 0] rc_data_fifo_wdata    , // {eop, func_id[1:0], data[255:0]}
  input  [15  : 0] release_tag           ,
  // AXI-MM-slave     
  input                         s_axi_aclk     , // Unused
  input                         s_axi_aresetn  , // Unused
  input  [S_AXI_ID_W-1     : 0] s_axi_awid     , // wr addr
  input  [S_AXI_ADDR_W-1   : 0] s_axi_awaddr   ,
  input  [7                : 0] s_axi_awlen    ,
  input  [2                : 0] s_axi_awsize   ,
  input  [1                : 0] s_axi_awburst  ,
  input  [3                : 0] s_axi_awregion , // Unused
  input                         s_axi_awlock   , // Unused
  input  [3                : 0] s_axi_awcache  , // Unused
  input  [2                : 0] s_axi_awprot   , // Unused
  input  [3                : 0] s_axi_awqos    , // Unused
  input                         s_axi_awvalid  ,
  output                        s_axi_awready  ,
  input  [S_AXI_DATA_W-1   : 0] s_axi_wdata    , // wr data
  input  [S_AXI_DATA_W/8-1 : 0] s_axi_wstrb    ,
  input                         s_axi_wlast    ,
  input                         s_axi_wvalid   ,
  output                        s_axi_wready   ,
  output [S_AXI_ID_W-1     : 0] s_axi_bid      , // wr res
  output [1                : 0] s_axi_bresp    ,
  output                        s_axi_bvalid   ,
  input                         s_axi_bready   ,
  input  [S_AXI_ID_W-1     : 0] s_axi_arid     , // rd addr
  input  [S_AXI_ADDR_W-1   : 0] s_axi_araddr   ,
  input  [7                : 0] s_axi_arlen    ,
  input  [2                : 0] s_axi_arsize   ,
  input  [1                : 0] s_axi_arburst  ,
  input  [3                : 0] s_axi_arregion , // Unused
  input                         s_axi_arlock   , // Unused
  input  [3                : 0] s_axi_arcache  , // Unused
  input  [2                : 0] s_axi_arprot   , // Unused
  input  [3                : 0] s_axi_arqos    , // Unused
  input                         s_axi_arvalid  ,
  output                        s_axi_arready  ,
  output [S_AXI_ID_W-1     : 0] s_axi_rid      , // rd data
  output [S_AXI_DATA_W-1   : 0] s_axi_rdata    ,
  output [1                : 0] s_axi_rresp    ,
  output                        s_axi_rlast    ,
  output                        s_axi_rvalid   ,
  input                         s_axi_rready   ,

  output [31 : 0] dbg_rq_waxi_aw_cnt ,
  output [31 : 0] dbg_rq_waxi_w_cnt  ,
  output [31 : 0] dbg_rq_raxi_ar_cnt ,
  output [31 : 0] dbg_rq_raxi_r_cnt  ,
  output [31 : 0] dbg_rqtlpgen_rd_wdes_cnt,
  output [31 : 0] dbg_rqtlpgen_rd_rdes_cnt,
  output [31 : 0] dbg_rqrctlpproc_tlp_out_cnt,
  output [15 : 0] dbg_rqrctlpproc_tlp_status1,
  output [31 : 0] dbg_rqrctlpproc_tlp_status2
      
) ;

logic         wdes_valid  ;          
logic [86 :0] wdes        ; 

logic         wdata_valid ;
logic [256:0] wdata       ;
                     
logic         rdes_valid  ;        
logic [86 :0] rdes        ; 

logic         rq_des_fifo_busy  ;

logic         rq_des_fifo_full  ;
logic [86 :0] rq_des_fifo_wdata ; // {wrrd, id[1:0], dw_cnt[10:0], add_offset[2:0], last_be[3:0], first_be[3:0], addr[61:0]}
logic         rq_des_fifo_wr    ;
logic         rq_des_fifo_empty ;
logic [86 :0] rq_des_fifo_rdata ;
logic         rq_des_fifo_rd    ;
logic         rq_des_fifo_pfull ;

logic         rq_data_fifo_full  ;
logic [256:0] rq_data_fifo_wdata ;
logic         rq_data_fifo_wr    ;
logic         rq_data_fifo_empty ;
logic [256:0] rq_data_fifo_rdata ;
logic         rq_data_fifo_rd    ;
logic         rq_data_fifo_pfull ;

logic         rq_tlp_fifo_full   ;
logic [275:0] rq_tlp_fifo_wdata  ; // {eop, add_offset[2:0], first_be[3:0], last_be[3:0], tkeep[7:0], data[255:0]}
logic         rq_tlp_fifo_wr     ;   
logic         rq_tlp_fifo_empty  ;
logic         rq_tlp_fifo_pfull  ;

logic         rc_data_fifo_empty ;
logic [258:0] rc_data_fifo_rdata ;
logic         rc_data_fifo_rd    ;

logic         rq_data_fifo_eop_in  ;
logic         rq_data_fifo_eop_out ;
logic [3  :0] rq_data_fifo_eop_cnt ;
logic         rq_data_fifo_req     ;

logic         rq_tlp_fifo_eop_in   ;
logic         rq_tlp_fifo_eop_out  ;
logic [7  :0] rq_tlp_fifo_eop_cnt  ;

logic [5  :0] dbg_rq_waxi_fifo_status;

logic [17 :0] dbg_rqtlpgen_fsm_status;


rq_axi_mm_wr #(
    .S_AXI_ID_W   ( S_AXI_ID_W   ) , 
    .S_AXI_ADDR_W ( S_AXI_ADDR_W ) ,
    .S_AXI_DATA_W ( S_AXI_DATA_W ) 
)wr_channel(
  .user_clk          ( user_clk          ) ,
  .user_reset        ( user_reset        ) ,
  .s_axi_aclk        ( s_axi_aclk        ) , // Unused
  .s_axi_aresetn     ( s_axi_aresetn     ) , // Unused
  .s_axi_awid        ( s_axi_awid        ) , // wr addr
  .s_axi_awaddr      ( s_axi_awaddr      ) ,
  .s_axi_awlen       ( s_axi_awlen       ) ,
  .s_axi_awsize      ( s_axi_awsize      ) ,
  .s_axi_awburst     ( s_axi_awburst     ) ,
  .s_axi_awregion    ( s_axi_awregion    ) , // Unused
  .s_axi_awlock      ( s_axi_awlock      ) , // Unused
  .s_axi_awcache     ( s_axi_awcache     ) , // Unused
  .s_axi_awprot      ( s_axi_awprot      ) , // Unused
  .s_axi_awqos       ( s_axi_awqos       ) , // Unused
  .s_axi_awvalid     ( s_axi_awvalid     ) ,
  .s_axi_awready     ( s_axi_awready     ) ,
  .s_axi_wdata       ( s_axi_wdata       ) , // wr data
  .s_axi_wstrb       ( s_axi_wstrb       ) ,
  .s_axi_wlast       ( s_axi_wlast       ) ,
  .s_axi_wvalid      ( s_axi_wvalid      ) ,
  .s_axi_wready      ( s_axi_wready      ) ,
  .s_axi_bid         ( s_axi_bid         ) , // wr res
  .s_axi_bresp       ( s_axi_bresp       ) ,
  .s_axi_bvalid      ( s_axi_bvalid      ) ,
  .s_axi_bready      ( s_axi_bready      ) ,
  .wdes_valid        ( wdes_valid        ) , // output         
  .wdes              ( wdes              ) , // output [86 :0] 
  .rq_des_fifo_full  ( rq_des_fifo_full  ) , // input          
  .wdata_valid       ( wdata_valid       ) , // output         
  .wdata             ( wdata             ) , // output [256:0] 
  .rq_data_fifo_full ( rq_data_fifo_full ) , // input       
  .dbg_rq_waxi_aw_cnt      ( dbg_rq_waxi_aw_cnt      ) ,
  .dbg_rq_waxi_w_cnt       ( dbg_rq_waxi_w_cnt       ) ,
  .dbg_rq_waxi_fifo_status ( dbg_rq_waxi_fifo_status )

);

rq_axi_mm_rd #(
    .S_AXI_ID_W   ( S_AXI_ID_W   ) , 
    .S_AXI_ADDR_W ( S_AXI_ADDR_W ) ,
    .S_AXI_DATA_W ( S_AXI_DATA_W ) 
)rd_channel(
  .user_clk           ( user_clk           ) ,
  .user_reset         ( user_reset         ) ,
  .s_axi_aclk         ( s_axi_aclk         ) , // Unused
  .s_axi_aresetn      ( s_axi_aresetn      ) , // Unused
  .s_axi_arid         ( s_axi_arid         ) , // rd addr
  .s_axi_araddr       ( s_axi_araddr       ) ,
  .s_axi_arlen        ( s_axi_arlen        ) ,
  .s_axi_arsize       ( s_axi_arsize       ) ,
  .s_axi_arburst      ( s_axi_arburst      ) ,
  .s_axi_arregion     ( s_axi_arregion     ) , // Unused
  .s_axi_arlock       ( s_axi_arlock       ) , // Unused
  .s_axi_arcache      ( s_axi_arcache      ) , // Unused
  .s_axi_arprot       ( s_axi_arprot       ) , // Unused
  .s_axi_arqos        ( s_axi_arqos        ) , // Unused
  .s_axi_arvalid      ( s_axi_arvalid      ) ,
  .s_axi_arready      ( s_axi_arready      ) ,
  .s_axi_rid          ( s_axi_rid          ) , // rd data
  .s_axi_rdata        ( s_axi_rdata        ) ,
  .s_axi_rresp        ( s_axi_rresp        ) ,
  .s_axi_rlast        ( s_axi_rlast        ) ,
  .s_axi_rvalid       ( s_axi_rvalid       ) ,
  .s_axi_rready       ( s_axi_rready       ) ,
  .rdes_valid         ( rdes_valid         ) , // output         
  .rdes               ( rdes               ) , // output [86 :0] 
  .rq_des_fifo_full   ( rq_des_fifo_busy   ) , // input    
  .rq_data_fifo_empty ( rq_data_fifo_empty ) , // input  //this signal is used to ensure that the read of dma flush is completed after the write 
  .rc_data_fifo_empty ( rc_data_fifo_empty ) , // input            
  .rc_data_fifo_rdata ( rc_data_fifo_rdata ) , // input  [258 : 0] 
  .rc_data_fifo_rd    ( rc_data_fifo_rd    ) , // output    
  .dbg_rq_raxi_ar_cnt ( dbg_rq_raxi_ar_cnt ) ,
  .dbg_rq_raxi_r_cnt  ( dbg_rq_raxi_r_cnt  ) 
       
);

assign rq_des_fifo_busy = rq_des_fifo_full | wdes_valid; // AXI write has higher priority

assign rq_des_fifo_wr = wdes_valid | rdes_valid;
assign rq_des_fifo_wdata = {87{wdes_valid}} & wdes | {87{rdes_valid}} & rdes;

sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto"  ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"  ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 32      ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 87      ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 10      )   // DECIMAL  3 - 4194301
) rq_des_fifo_32x87bits ( // {wrrd, id[1:0], dw_cnt[10:0], add_offset[2:0], last_be[3:0], first_be[3:0], addr[61:0]}
    .clk       ( user_clk          ) ,
    .srst      ( user_reset        ) ,
    .full      ( rq_des_fifo_full  ) ,
    .din       ( rq_des_fifo_wdata ) ,
    .wr_en     ( rq_des_fifo_wr    ) ,
    .empty     ( rq_des_fifo_empty ) ,
    .dout      ( rq_des_fifo_rdata ) ,
    .rd_en     ( rq_des_fifo_rd    ) ,
    .prog_full ( rq_des_fifo_pfull )
) ;

assign rq_data_fifo_wr = wdata_valid;
assign rq_data_fifo_wdata = wdata;

sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft" ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 32     ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 257    ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 10     )   // DECIMAL  3 - 4194301
) rq_data_fifo_32x257bits ( // {eop, data[255:0]}
    .clk       ( user_clk           ) ,
    .srst      ( user_reset         ) ,
    .full      ( rq_data_fifo_full  ) ,
    .din       ( rq_data_fifo_wdata ) ,
    .wr_en     ( rq_data_fifo_wr    ) ,
    .empty     ( rq_data_fifo_empty ) ,
    .dout      ( rq_data_fifo_rdata ) ,
    .rd_en     ( rq_data_fifo_rd    ) ,
    .prog_full ( rq_data_fifo_pfull )
) ;

assign rq_data_fifo_eop_in  = rq_data_fifo_wr & ~rq_data_fifo_full  & rq_data_fifo_wdata[256] ;
assign rq_data_fifo_eop_out = rq_data_fifo_rd & ~rq_data_fifo_empty & rq_data_fifo_rdata[256] ;

always_ff @(posedge user_clk) begin
    if (user_reset) begin
        rq_data_fifo_eop_cnt <= 'd0 ;
    end else begin
        case({rq_data_fifo_eop_in, rq_data_fifo_eop_out})
            2'b10 : rq_data_fifo_eop_cnt <= rq_data_fifo_eop_cnt + 'd1 ;
            2'b01 : rq_data_fifo_eop_cnt <= rq_data_fifo_eop_cnt - 'd1 ;
            default : ;
        endcase
    end
end
// And ~empty is necessary when Cmpl is very short.
// Otherwise req could be asserted when FIFO is still empty because FIFo has read latency.
assign rq_data_fifo_req = rq_data_fifo_eop_cnt > 'd0 & ~rq_data_fifo_empty ; // Unused

rq_tlp_gen rq_tlp(
    .user_clk           ( user_clk           ) , // input    
    .user_reset         ( user_reset         ) , // input 
    .release_tag        ( release_tag        ) , // input  [15 :0]
    .rq_des_fifo_empty  ( rq_des_fifo_empty  ) , // input         
    .rq_des_fifo_rdata  ( rq_des_fifo_rdata  ) , // input  [86 :0]
    .rq_des_fifo_rd     ( rq_des_fifo_rd     ) , // output        
    .rq_data_fifo_req   ( rq_data_fifo_req   ) , // input         
    .rq_data_fifo_rdata ( rq_data_fifo_rdata ) , // input  [256:0]
    .rq_data_fifo_rd    ( rq_data_fifo_rd    ) , // output        
    .rq_tlp_fifo_full   ( rq_tlp_fifo_full   ) , // input         
    .rq_tlp_fifo_wdata  ( rq_tlp_fifo_wdata  ) , // output [275:0]
    .rq_tlp_fifo_wr     ( rq_tlp_fifo_wr     ) , // output  
    .dbg_rqtlpgen_rd_wdes_cnt ( dbg_rqtlpgen_rd_wdes_cnt ) ,
    .dbg_rqtlpgen_rd_rdes_cnt ( dbg_rqtlpgen_rd_rdes_cnt ) ,
    .dbg_rqtlpgen_fsm_status  ( dbg_rqtlpgen_fsm_status  )     
);


sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft" ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 32     ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 276    ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 10     )   // DECIMAL  3 - 4194301
) rq_tlp_fifo_32x276bits ( // {eop, add_offset[2:0], last_be[3:0], first_be[3:0], tkeep[7:0], data[255:0]}
    .clk       ( user_clk          ) ,
    .srst      ( user_reset        ) ,
    .full      ( rq_tlp_fifo_full  ) ,
    .din       ( rq_tlp_fifo_wdata ) ,
    .wr_en     ( rq_tlp_fifo_wr    ) ,
    .empty     ( rq_tlp_fifo_empty ) ,
    .dout      ( rq_tlp_fifo_rdata ) ,
    .rd_en     ( rq_tlp_fifo_rd    ) ,
    .prog_full ( rq_tlp_fifo_pfull )
) ;

assign rq_tlp_fifo_eop_in  = rq_tlp_fifo_wr & ~rq_tlp_fifo_full  & rq_tlp_fifo_wdata[275] ;
assign rq_tlp_fifo_eop_out = rq_tlp_fifo_rd & ~rq_tlp_fifo_empty & rq_tlp_fifo_rdata[275] ;

always_ff @(posedge user_clk) begin
    if (user_reset) begin
        rq_tlp_fifo_eop_cnt <= 'd0 ;
    end else begin
        case({rq_tlp_fifo_eop_in, rq_tlp_fifo_eop_out})
            2'b10 : rq_tlp_fifo_eop_cnt <= rq_tlp_fifo_eop_cnt + 'd1 ;
            2'b01 : rq_tlp_fifo_eop_cnt <= rq_tlp_fifo_eop_cnt - 'd1 ;
            default : ;
        endcase
    end
end

// And ~empty is necessary when Cmpl is very short.
// Otherwise req could be asserted when FIFO is still empty because FIFo has read latency.
assign rq_tlp_fifo_req = rq_tlp_fifo_eop_cnt > 'd0 & ~rq_tlp_fifo_empty ;

// This FIFO is necessary.
// The previous RAM has one or two clock read latency.
// prog_full is used to handle it.
sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto" ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft" ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 32     ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( 259    ) , // DECIMAL  1 - 4096
    .PROG_FULL_THRESH  ( 27     )   // DECIMAL  3 - 4194301
) rc_data_fifo( // {eop, func_id[1:0], data[255:0]}
    .clk       ( user_clk           ) ,
    .srst      ( user_reset         ) ,
    .full      ( rc_data_fifo_full  ) ,
    .din       ( rc_data_fifo_wdata ) ,
    .wr_en     ( rc_data_fifo_wr    ) ,
    .empty     ( rc_data_fifo_empty ) ,
    .dout      ( rc_data_fifo_rdata ) ,
    .rd_en     ( rc_data_fifo_rd    ) ,
    .prog_full ( rc_data_fifo_pfull )
) ;

// --- for debug --- //

logic rq_data_fifo_rerr;
logic rq_des_fifo_rerr;
logic rq_tlp_fifo_werr;
logic rq_tlp_fifo_rerr;
logic rc_data_fifo_werr;

logic [31:0] rqrctlpproc_tlp_out_cnt;

always_ff @(posedge user_clk) begin
    if (user_reset) rq_data_fifo_rerr <= 1'b0; else if (rq_data_fifo_rd & rq_data_fifo_empty) rq_data_fifo_rerr <= 1'b1; else;
    if (user_reset) rq_des_fifo_rerr  <= 1'b0; else if (rq_des_fifo_rd & rq_des_fifo_empty)   rq_des_fifo_rerr  <= 1'b1; else;
    if (user_reset) rq_tlp_fifo_werr  <= 1'b0; else if (rq_tlp_fifo_wr & rq_tlp_fifo_full)    rq_tlp_fifo_werr  <= 1'b1; else;
    if (user_reset) rq_tlp_fifo_rerr  <= 1'b0; else if (rq_tlp_fifo_rd & rq_tlp_fifo_empty)   rq_tlp_fifo_rerr  <= 1'b1; else;
    if (user_reset) rc_data_fifo_werr <= 1'b0; else if (rc_data_fifo_wr & rc_data_fifo_full)  rc_data_fifo_werr <= 1'b1; else;    
end

always_ff @(posedge user_clk) begin
    if (user_reset) rqrctlpproc_tlp_out_cnt <= 'b0;
    else if (rq_tlp_fifo_rd & ~rq_tlp_fifo_empty & rq_tlp_fifo_rdata[275]) rqrctlpproc_tlp_out_cnt <= rqrctlpproc_tlp_out_cnt + 'b1;
    else;
end

assign dbg_rqrctlpproc_tlp_out_cnt = rqrctlpproc_tlp_out_cnt;

assign dbg_rqrctlpproc_tlp_status1 = {rq_des_fifo_full, rq_des_fifo_empty, 
                                      rq_data_fifo_full, rq_data_fifo_empty, 
                                      rq_tlp_fifo_full, rq_tlp_fifo_empty, 
                                      rc_data_fifo_full, rc_data_fifo_empty,
                                      1'b0, rq_data_fifo_rerr,
                                      1'b0, rq_des_fifo_rerr,
                                      rq_tlp_fifo_werr, rq_tlp_fifo_rerr,
                                      rc_data_fifo_werr, 1'b0};

assign dbg_rqrctlpproc_tlp_status2 = {4'b0, {2'b0, dbg_rqtlpgen_fsm_status}, {2'b0,dbg_rq_waxi_fifo_status}}; // 4 + 20 + 8


endmodule
