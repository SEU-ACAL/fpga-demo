/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

module dma_wrapper #(
    parameter         DEBUG_ON        = "FALSE"                 , // "FALSE" or "TRUE"
    parameter         HAC_MODE        = 2'b10                   ,
    parameter integer M0_AXI_ID_W     = 4                       , // Master0 for PCIe AXI interface
    parameter integer M0_AXI_ADDR_W   = 64                      ,
    parameter integer M0_AXI_DATA_W   = 256                     ,
    parameter         M0_BASE_ADDR    = {{M0_AXI_ADDR_W}{1'b0}} ,
    parameter integer M1_AXI_ID_W     = 1                       , // Master1 for memory AXI interface
    parameter integer M1_AXI_ADDR_W   = 64                      ,
    parameter integer M1_AXI_DATA_W   = 256                     ,
    parameter         M1_BASE_ADDR    = {{M1_AXI_ADDR_W}{1'b0}}  
)(  
  // clock and reset
  input           user_clk                        , // input    
  input           user_reset                      , // input 
  input           soft_rstp                       , 
  // PCIe Configuration status
  input  [1  : 0] cfg_max_payload                 , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
  input  [2  : 0] cfg_max_read_req                , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
  input           cfg_rcb_status                  , // input            0 - 64B; 1 - 128B

  input [1:0]      intr_mode                       ,
  input [63:0]     dma_tlp_bar0_addr                   , 


  // DMA registers
  // wdma is dma write operation, data will be transfered from endpoint to root(e2r).
  // rdma is dma read operation, data will be transfered from root to endpoint(r2e).
  input           wdma_start                      , // dma start pulse. 
  input  [63 : 0] wdma_des_addr                   , // dma initial descriptor address
  input  [7  : 0] wdma_adj_des_num                , // adjacent descriptor number
  input           rdma_start                      , 
  input  [63 : 0] rdma_des_addr                   , 
  input  [7  : 0] rdma_adj_des_num                , 
  input           dwdma_start                     , // direct DMA write
  input           drdma_start                     , // direct DMA read
  input  [63 : 0] ddma_saddr                      , // direct DMA source address
  input  [63 : 0] ddma_daddr                      , // direct DMA destination address
  input  [31 : 0] ddma_len                        , // direct DMA length minus one in byte
  // status info, Connect to pcie interrupt intf or registers 
  output          wdma_dma_end                    ,
  output          wdma_des_blk_end                ,
  output          wdma_des_end                    ,
  output          wdma_des_usr_intr               ,
  output          wdma_flush_intr                 ,
  output          rdma_dma_end                    ,
  output          rdma_des_blk_end                ,
  output          rdma_des_end                    , 
  output          rdma_des_usr_intr               , 
  output          rdma_flush_intr                  ,
  output          wdma_done                       ,    
  output          wdma_busy                       ,
  output          rdma_done                       ,    
  output          rdma_busy                       ,
  output [7  : 0] dma_fifo_status                 ,           
  output [7  : 0] dma_fifo_error                  ,   
  output [17 : 0] dbg_wdma_engine_status          , 
  output [31 : 0] dbg_wdma_cnt                    , 
  output [31 : 0] dbg_wdma_des_blk_cnt            , 
  output [31 : 0] dbg_wdma_des_cnt                ,
  output [31 : 0] dbg_wdma_des_split_rd_des_cnt   ,
  output [31 : 0] dbg_wdma_data_mover_aw_cnt      ,
  output [31 : 0] dbg_wdma_data_mover_w_cnt       ,
  output [31 : 0] dbg_wdma_data_mover_ar_cnt      ,
  output [31 : 0] dbg_wdma_data_mover_r_cnt       ,
  output [17 : 0] dbg_rdma_engine_status          , 
  output [31 : 0] dbg_rdma_cnt                    , 
  output [31 : 0] dbg_rdma_des_blk_cnt            , 
  output [31 : 0] dbg_rdma_des_cnt                ,
  output [31 : 0] dbg_rdma_des_split_rd_des_cnt   ,
  output [31 : 0] dbg_rdma_data_mover_aw_cnt      ,
  output [31 : 0] dbg_rdma_data_mover_w_cnt       ,
  output [31 : 0] dbg_rdma_data_mover_ar_cnt      ,
  output [31 : 0] dbg_rdma_data_mover_r_cnt       ,
  // AXI-MM-master-0, Connect to pcie3_tlp_intf/rqrc_intf  
  output [M0_AXI_ID_W-1     : 0] m0_axi_awid     , // wr addr
  output [M0_AXI_ADDR_W-1   : 0] m0_axi_awaddr   ,   
  output [7                 : 0] m0_axi_awlen    ,
  output [2                 : 0] m0_axi_awsize   ,
  output [1                 : 0] m0_axi_awburst  ,
  output                         m0_axi_awvalid  ,
  input                          m0_axi_awready  ,
  output                         m0_axi_awlock   , 
  output [3                 : 0] m0_axi_awcache  , 
  output [2                 : 0] m0_axi_awprot   , 
  output [3                 : 0] m0_axi_awqos    , 
  output [M0_AXI_DATA_W-1   : 0] m0_axi_wdata    , // wr data
  output [M0_AXI_DATA_W/8-1 : 0] m0_axi_wstrb    ,
  output                         m0_axi_wlast    ,
  output                         m0_axi_wvalid   ,
  input                          m0_axi_wready   ,
  input  [M0_AXI_ID_W-1     : 0] m0_axi_bid      , // wr res
  input  [1                 : 0] m0_axi_bresp    ,
  input                          m0_axi_bvalid   ,
  output                         m0_axi_bready   ,
  output [M0_AXI_ID_W-1     : 0] m0_axi_arid     , // rd addr
  output [M0_AXI_ADDR_W-1   : 0] m0_axi_araddr   ,
  output [7                 : 0] m0_axi_arlen    ,
  output [2                 : 0] m0_axi_arsize   ,
  output [1                 : 0] m0_axi_arburst  ,
  output                         m0_axi_arvalid  ,
  input                          m0_axi_arready  ,
  output                         m0_axi_arlock   , 
  output [3                 : 0] m0_axi_arcache  , 
  output [2                 : 0] m0_axi_arprot   , 
  output [3                 : 0] m0_axi_arqos    , 
  input  [M0_AXI_ID_W-1     : 0] m0_axi_rid      , // rd data
  input  [M0_AXI_DATA_W-1   : 0] m0_axi_rdata    ,
  input  [1                 : 0] m0_axi_rresp    ,
  input  [0                 : 0] m0_axi_rlast    ,
  input                          m0_axi_rvalid   ,
  output                         m0_axi_rready   , 
  // AXI-MM-master-1, Connect to local memory(BRAM or DDR) 
  output [M1_AXI_ID_W-1     : 0] m1_axi_awid     , // wr addr
  output [M1_AXI_ADDR_W-1   : 0] m1_axi_awaddr   ,   
  output [7                 : 0] m1_axi_awlen    ,
  output [2                 : 0] m1_axi_awsize   ,
  output [1                 : 0] m1_axi_awburst  ,
  output                         m1_axi_awvalid  ,
  input                          m1_axi_awready  ,
  output                         m1_axi_awlock   , 
  output [3                 : 0] m1_axi_awcache  , 
  output [2                 : 0] m1_axi_awprot   , 
  output [3                 : 0] m1_axi_awqos    , 
  output [M1_AXI_DATA_W-1   : 0] m1_axi_wdata    , // wr data
  output [M1_AXI_DATA_W/8-1 : 0] m1_axi_wstrb    ,
  output                         m1_axi_wlast    ,
  output                         m1_axi_wvalid   ,
  input                          m1_axi_wready   ,
  input  [M1_AXI_ID_W-1     : 0] m1_axi_bid      , // wr res
  input  [1                 : 0] m1_axi_bresp    ,
  input                          m1_axi_bvalid   ,
  output                         m1_axi_bready   ,
  output [M1_AXI_ID_W-1     : 0] m1_axi_arid     , // rd addr
  output [M1_AXI_ADDR_W-1   : 0] m1_axi_araddr   ,
  output [7                 : 0] m1_axi_arlen    ,
  output [2                 : 0] m1_axi_arsize   ,
  output [1                 : 0] m1_axi_arburst  ,
  output                         m1_axi_arvalid  ,
  input                          m1_axi_arready  ,
  output                         m1_axi_arlock   , 
  output [3                 : 0] m1_axi_arcache  , 
  output [2                 : 0] m1_axi_arprot   , 
  output [3                 : 0] m1_axi_arqos    , 
  input  [M1_AXI_ID_W-1     : 0] m1_axi_rid      , // rd data
  input  [M1_AXI_DATA_W-1   : 0] m1_axi_rdata    ,
  input  [1                 : 0] m1_axi_rresp    ,
  input  [0                 : 0] m1_axi_rlast    ,
  input                          m1_axi_rvalid   ,
  output                         m1_axi_rready   

) ;

logic  [2  : 0] cfg_max_read_req_int;

logic          rst_p                ;

logic [0  : 0] wdma_des_axi_awid    ;                       
logic [63 : 0] wdma_des_axi_awaddr  ;                         
logic [7  : 0] wdma_des_axi_awlen   ;                        
logic [2  : 0] wdma_des_axi_awsize  ;                         
logic [1  : 0] wdma_des_axi_awburst ;                          
logic          wdma_des_axi_awlock  ;                                   
logic [3  : 0] wdma_des_axi_awcache ;                          
logic [2  : 0] wdma_des_axi_awprot  ;                         
logic [3  : 0] wdma_des_axi_awqos   ;                        
logic          wdma_des_axi_awvalid ;                           
logic          wdma_des_axi_awready ;                           
logic [255: 0] wdma_des_axi_wdata   ;                        
logic [31 : 0] wdma_des_axi_wstrb   ;                        
logic          wdma_des_axi_wlast   ;                         
logic          wdma_des_axi_wvalid  ;                          
logic          wdma_des_axi_wready  ;                          
logic [0  : 0] wdma_des_axi_bid     ;                      
logic [1  : 0] wdma_des_axi_bresp   ;                        
logic          wdma_des_axi_bvalid  ;                          
logic          wdma_des_axi_bready  ;                          
logic [0  : 0] wdma_des_axi_arid    ;                       
logic [63 : 0] wdma_des_axi_araddr  ;                         
logic [7  : 0] wdma_des_axi_arlen   ;                        
logic [2  : 0] wdma_des_axi_arsize  ;                         
logic [1  : 0] wdma_des_axi_arburst ;                          
logic          wdma_des_axi_arlock  ;                          
logic [3  : 0] wdma_des_axi_arcache ;                          
logic [2  : 0] wdma_des_axi_arprot  ;                         
logic [3  : 0] wdma_des_axi_arqos   ;                        
logic          wdma_des_axi_arvalid ;                           
logic          wdma_des_axi_arready ;                           
logic [0  : 0] wdma_des_axi_rid     ;                      
logic [255: 0] wdma_des_axi_rdata   ;                        
logic [1  : 0] wdma_des_axi_rresp   ;                        
logic          wdma_des_axi_rlast   ;                                
logic          wdma_des_axi_rvalid  ;                                  
logic          wdma_des_axi_rready  ; 

logic [0  : 0] wdma_data_axi_awid    ;                       
logic [63 : 0] wdma_data_axi_awaddr  ;                         
logic [7  : 0] wdma_data_axi_awlen   ;                        
logic [2  : 0] wdma_data_axi_awsize  ;                         
logic [1  : 0] wdma_data_axi_awburst ;                          
logic          wdma_data_axi_awlock  ;                                   
logic [3  : 0] wdma_data_axi_awcache ;                          
logic [2  : 0] wdma_data_axi_awprot  ;                         
logic [3  : 0] wdma_data_axi_awqos   ;                        
logic          wdma_data_axi_awvalid ;                           
logic          wdma_data_axi_awready ;                           
logic [255: 0] wdma_data_axi_wdata   ;                        
logic [31 : 0] wdma_data_axi_wstrb   ;                        
logic          wdma_data_axi_wlast   ;                         
logic          wdma_data_axi_wvalid  ;                          
logic          wdma_data_axi_wready  ;                          
logic [0  : 0] wdma_data_axi_bid     ;                      
logic [1  : 0] wdma_data_axi_bresp   ;                        
logic          wdma_data_axi_bvalid  ;                          
logic          wdma_data_axi_bready  ;                          
logic [0  : 0] wdma_data_axi_arid    ;                       
logic [63 : 0] wdma_data_axi_araddr  ;                         
logic [7  : 0] wdma_data_axi_arlen   ;                        
logic [2  : 0] wdma_data_axi_arsize  ;                         
logic [1  : 0] wdma_data_axi_arburst ;                          
logic          wdma_data_axi_arlock  ;                          
logic [3  : 0] wdma_data_axi_arcache ;                          
logic [2  : 0] wdma_data_axi_arprot  ;                         
logic [3  : 0] wdma_data_axi_arqos   ;                        
logic          wdma_data_axi_arvalid ;                           
logic          wdma_data_axi_arready ;                           
logic [0  : 0] wdma_data_axi_rid     ;                      
logic [255: 0] wdma_data_axi_rdata   ;                        
logic [1  : 0] wdma_data_axi_rresp   ;                        
logic          wdma_data_axi_rlast   ;                                 
logic          wdma_data_axi_rvalid  ;                                   
logic          wdma_data_axi_rready  ; 

logic [0  : 0] rdma_des_axi_awid    ;                       
logic [63 : 0] rdma_des_axi_awaddr  ;                         
logic [7  : 0] rdma_des_axi_awlen   ;                        
logic [2  : 0] rdma_des_axi_awsize  ;                         
logic [1  : 0] rdma_des_axi_awburst ;                          
logic          rdma_des_axi_awlock  ;                                   
logic [3  : 0] rdma_des_axi_awcache ;                          
logic [2  : 0] rdma_des_axi_awprot  ;                         
logic [3  : 0] rdma_des_axi_awqos   ;                        
logic          rdma_des_axi_awvalid ;                           
logic          rdma_des_axi_awready ;                           
logic [255: 0] rdma_des_axi_wdata   ;                        
logic [31 : 0] rdma_des_axi_wstrb   ;                        
logic          rdma_des_axi_wlast   ;                         
logic          rdma_des_axi_wvalid  ;                          
logic          rdma_des_axi_wready  ;                          
logic [0  : 0] rdma_des_axi_bid     ;                      
logic [1  : 0] rdma_des_axi_bresp   ;                        
logic          rdma_des_axi_bvalid  ;                          
logic          rdma_des_axi_bready  ;                          
logic [0  : 0] rdma_des_axi_arid    ;                       
logic [63 : 0] rdma_des_axi_araddr  ;                         
logic [7  : 0] rdma_des_axi_arlen   ;                        
logic [2  : 0] rdma_des_axi_arsize  ;                         
logic [1  : 0] rdma_des_axi_arburst ;                          
logic          rdma_des_axi_arlock  ;                          
logic [3  : 0] rdma_des_axi_arcache ;                          
logic [2  : 0] rdma_des_axi_arprot  ;                         
logic [3  : 0] rdma_des_axi_arqos   ;                        
logic          rdma_des_axi_arvalid ;                           
logic          rdma_des_axi_arready ;                           
logic [0  : 0] rdma_des_axi_rid     ;                      
logic [255: 0] rdma_des_axi_rdata   ;                        
logic [1  : 0] rdma_des_axi_rresp   ;                        
logic          rdma_des_axi_rlast   ;                                 
logic          rdma_des_axi_rvalid  ;                                   
logic          rdma_des_axi_rready  ; 

logic [0  : 0] rdma_data_axi_awid    ;                       
logic [63 : 0] rdma_data_axi_awaddr  ;                         
logic [7  : 0] rdma_data_axi_awlen   ;                        
logic [2  : 0] rdma_data_axi_awsize  ;                         
logic [1  : 0] rdma_data_axi_awburst ;                          
logic          rdma_data_axi_awlock  ;                                   
logic [3  : 0] rdma_data_axi_awcache ;                          
logic [2  : 0] rdma_data_axi_awprot  ;                         
logic [3  : 0] rdma_data_axi_awqos   ;                        
logic          rdma_data_axi_awvalid ;                           
logic          rdma_data_axi_awready ;                           
logic [255: 0] rdma_data_axi_wdata   ;                        
logic [31 : 0] rdma_data_axi_wstrb   ;                        
logic          rdma_data_axi_wlast   ;                         
logic          rdma_data_axi_wvalid  ;                          
logic          rdma_data_axi_wready  ;                          
logic [0  : 0] rdma_data_axi_bid     ;                      
logic [1  : 0] rdma_data_axi_bresp   ;                        
logic          rdma_data_axi_bvalid  ;                          
logic          rdma_data_axi_bready  ;                          
logic [0  : 0] rdma_data_axi_arid    ;                       
logic [63 : 0] rdma_data_axi_araddr  ;                         
logic [7  : 0] rdma_data_axi_arlen   ;                        
logic [2  : 0] rdma_data_axi_arsize  ;                         
logic [1  : 0] rdma_data_axi_arburst ;                          
logic          rdma_data_axi_arlock  ;                          
logic [3  : 0] rdma_data_axi_arcache ;                          
logic [2  : 0] rdma_data_axi_arprot  ;                         
logic [3  : 0] rdma_data_axi_arqos   ;                        
logic          rdma_data_axi_arvalid ;                           
logic          rdma_data_axi_arready ;                           
logic [0  : 0] rdma_data_axi_rid     ;                      
logic [255: 0] rdma_data_axi_rdata   ;                        
logic [1  : 0] rdma_data_axi_rresp   ;                        
logic          rdma_data_axi_rlast   ;                                  
logic          rdma_data_axi_rvalid  ;                                    
logic          rdma_data_axi_rready  ; 

logic [M1_AXI_ID_W-1     : 0] m10_axi_arid     ; // rd addr
logic [M1_AXI_ADDR_W-1   : 0] m10_axi_araddr   ;
logic [7                 : 0] m10_axi_arlen    ;
logic [2                 : 0] m10_axi_arsize   ;
logic [1                 : 0] m10_axi_arburst  ;
logic                         m10_axi_arvalid  ;
logic                         m10_axi_arready  ;
logic                         m10_axi_arlock   ; 
logic [3                 : 0] m10_axi_arcache  ; 
logic [2                 : 0] m10_axi_arprot   ; 
logic [3                 : 0] m10_axi_arqos    ; 
logic [M1_AXI_ID_W-1     : 0] m10_axi_rid      ; // rd data
logic [M1_AXI_DATA_W-1   : 0] m10_axi_rdata    ;
logic [1                 : 0] m10_axi_rresp    ;
logic [0                 : 0] m10_axi_rlast    ;
logic                         m10_axi_rvalid   ;
logic                         m10_axi_rready   ;

logic [M1_AXI_ID_W-1     : 0] m11_axi_arid     ; // rd addr
logic [M1_AXI_ADDR_W-1   : 0] m11_axi_araddr   ;
logic [7                 : 0] m11_axi_arlen    ;
logic [2                 : 0] m11_axi_arsize   ;
logic [1                 : 0] m11_axi_arburst  ;
logic                         m11_axi_arvalid  ;
logic                         m11_axi_arready  ;
logic                         m11_axi_arlock   ; 
logic [3                 : 0] m11_axi_arcache  ; 
logic [2                 : 0] m11_axi_arprot   ; 
logic [3                 : 0] m11_axi_arqos    ; 
logic [M1_AXI_ID_W-1     : 0] m11_axi_rid      ; // rd data
logic [M1_AXI_DATA_W-1   : 0] m11_axi_rdata    ;
logic [1                 : 0] m11_axi_rresp    ;
logic [0                 : 0] m11_axi_rlast    ;
logic                         m11_axi_rvalid   ;
logic                         m11_axi_rready   ;

logic [M0_AXI_ADDR_W-1   : 0] m0_axi_awaddr_int;
logic [M0_AXI_ADDR_W-1   : 0] m0_axi_araddr_int;



logic [M0_AXI_ID_W-1  : 0] m0_axi_rid_int;
logic                      m0_axi_arready_int;
logic                      m0_axi_rready_int;

assign rst_p = user_reset | soft_rstp;

// wdma channel will only read data from local memory
dma_engine #(
    .DEBUG_ON        ( DEBUG_ON      ) ,
    .DMA_DIR         ( "WDMA_E2R"    ) ,
    .M0_AXI_ID_W     ( 1             ) ,
    .M0_AXI_ADDR_W   ( M0_AXI_ADDR_W ) ,
    .M0_AXI_DATA_W   ( M0_AXI_DATA_W ) ,
    .M0_BASE_ADDR    ( M0_BASE_ADDR  ) ,
    .M1_AXI_ID_W     ( 1             ) ,
    .M1_AXI_ADDR_W   ( M1_AXI_ADDR_W ) ,
    .M1_AXI_DATA_W   ( M1_AXI_DATA_W ) ,
    .M1_BASE_ADDR    ( M1_BASE_ADDR  )     
)wdma_e2r(
    .clk              ( user_clk              ) , // input    
    .rst_p            ( rst_p                 ) , // input 
    .cfg_max_payload  ( cfg_max_payload       ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
    .cfg_max_read_req ( cfg_max_read_req      ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
    .cfg_rcb_status   ( cfg_rcb_status        ) , // input            0 - 64B; 1 - 128B
    .dma_start        ( wdma_start            ) , // input            dma start pulse. 
    .dma_des_addr     ( wdma_des_addr         ) , // input [63 : 0]   dma initial descriptor address
    .dma_adj_des_num  ( wdma_adj_des_num      ) , // input [7  : 0]   adjacent descriptor number
    .ddma_start       ( dwdma_start           ) , // input            direct DMA start
    .ddma_saddr       ( ddma_saddr            ) , // input  [63 : 0]  direct DMA source address
    .ddma_daddr       ( ddma_daddr            ) , // input  [63 : 0]  direct DMA destination address
    .ddma_len         ( ddma_len              ) , // input  [31 : 0]  direct DMA length minus one in byte
    .dma_end          ( wdma_dma_end          ) , // output
    .des_blk_end      ( wdma_des_blk_end      ) , // output
    .des_end          ( wdma_des_end          ) , // output
    .des_usr_intr     ( wdma_des_usr_intr     ) , // output
    .dma_flush_intr   ( wdma_flush_intr        ) ,
    .dma_done         ( wdma_done             ) , // output
    .dma_busy         ( wdma_busy             ) , // output
    .fifo_status      ( dma_fifo_status[3:0]  ) , // output [3  : 0] {split_des_fifo_full, split_des_fifo_empty, des_fifo_full, des_fifo_empty}
    .fifo_error       ( dma_fifo_error[3:0]   ) , // output [3  : 0] {split_des_fifo_werr, split_des_fifo_rerr, des_fifo_werr, des_fifo_rerr}
    .dbg_dma_engine_status    ( dbg_wdma_engine_status        ) , 
    .dbg_dma_cnt              ( dbg_wdma_cnt                  ) , 
    .dbg_des_blk_cnt          ( dbg_wdma_des_blk_cnt          ) , 
    .dbg_des_cnt              ( dbg_wdma_des_cnt              ) ,
    .dbg_des_split_rd_des_cnt ( dbg_wdma_des_split_rd_des_cnt ) ,
    .dbg_data_mover_aw_cnt    ( dbg_wdma_data_mover_aw_cnt    ) ,
    .dbg_data_mover_w_cnt     ( dbg_wdma_data_mover_w_cnt     ) ,
    .dbg_data_mover_ar_cnt    ( dbg_wdma_data_mover_ar_cnt    ) ,
    .dbg_data_mover_r_cnt     ( dbg_wdma_data_mover_r_cnt     ) ,

    .data_axi_awid    ( m0_axi_awid    ) , // output [0  : 0]                      
    .data_axi_awaddr  ( m0_axi_awaddr  ) , // output [63 : 0]                        
    .data_axi_awlen   ( m0_axi_awlen   ) , // output [7  : 0]                       
    .data_axi_awsize  ( m0_axi_awsize  ) , // output [2  : 0]                        
    .data_axi_awburst ( m0_axi_awburst ) , // output [1  : 0]                         
    .data_axi_awlock  ( m0_axi_awlock  ) , // output                                 
    .data_axi_awcache ( m0_axi_awcache ) , // output [3  : 0]                         
    .data_axi_awprot  ( m0_axi_awprot  ) , // output [2  : 0]                        
    .data_axi_awqos   ( m0_axi_awqos   ) , // output [3  : 0]                       
    .data_axi_awvalid ( m0_axi_awvalid ) , // output                                  
    .data_axi_awready ( m0_axi_awready ) , // input                                   
    .data_axi_wdata   ( m0_axi_wdata   ) , // output [255: 0]                       
    .data_axi_wstrb   ( m0_axi_wstrb   ) , // output [31 : 0]                       
    .data_axi_wlast   ( m0_axi_wlast   ) , // output                                
    .data_axi_wvalid  ( m0_axi_wvalid  ) , // output                                 
    .data_axi_wready  ( m0_axi_wready  ) , // input                                  
    .data_axi_bid     ( m0_axi_bid     ) , // input  [0  : 0]                     
    .data_axi_bresp   ( m0_axi_bresp   ) , // input  [1  : 0]                       
    .data_axi_bvalid  ( m0_axi_bvalid  ) , // input                                  
    .data_axi_bready  ( m0_axi_bready  ) , // output 
	
    .data_axi_arid    (      ) , // output [0  : 0]                      
    .data_axi_araddr  (      ) , // output [63 : 0]                        
    .data_axi_arlen   (      ) , // output [7  : 0]                       
    .data_axi_arsize  (      ) , // output [2  : 0]                        
    .data_axi_arburst (      ) , // output [1  : 0]                         
    .data_axi_arlock  (      ) , // output                                 
    .data_axi_arcache (      ) , // output [3  : 0]                         
    .data_axi_arprot  (      ) , // output [2  : 0]                        
    .data_axi_arqos   (      ) , // output [3  : 0]                       
    .data_axi_arvalid (      ) , // output                                  
    .data_axi_arready (  'b1 ) , // input                                   
    .data_axi_rid     (  'b0 ) , // input  [0  : 0]                     
    .data_axi_rdata   (  'b0 ) , // input  [255: 0]                       
    .data_axi_rresp   (  'b0 ) , // input  [1  : 0]                       
    .data_axi_rlast   (  'b0 ) , // input                                 
    .data_axi_rvalid  (  'b0 ) , // input                                  
    .data_axi_rready  (      ) , // output   
    // AXI to memory intf for data reading
    .mem_axi_awid     (     ) , // output [0  : 0]                      
    .mem_axi_awaddr   (     ) , // output [63 : 0]                        
    .mem_axi_awlen    (     ) , // output [7  : 0]                       
    .mem_axi_awsize   (     ) , // output [2  : 0]                        
    .mem_axi_awburst  (     ) , // output [1  : 0]                         
    .mem_axi_awlock   (     ) , // output                                 
    .mem_axi_awcache  (     ) , // output [3  : 0]                         
    .mem_axi_awprot   (     ) , // output [2  : 0]                        
    .mem_axi_awqos    (     ) , // output [3  : 0]                       
    .mem_axi_awvalid  (     ) , // output                                  
    .mem_axi_awready  ( 'b1 ) , // input                                   
    .mem_axi_wdata    (     ) , // output [255: 0]                       
    .mem_axi_wstrb    (     ) , // output [31 : 0]                       
    .mem_axi_wlast    (     ) , // output                                
    .mem_axi_wvalid   (     ) , // output                                 
    .mem_axi_wready   ( 'b1 ) , // input                                  
    .mem_axi_bid      ( 'b0 ) , // input  [0  : 0]                     
    .mem_axi_bresp    ( 'b0 ) , // input  [1  : 0]                       
    .mem_axi_bvalid   ( 'b0 ) , // input                                  
    .mem_axi_bready   (     ) , // output 
    .mem_axi_arid     ( m1_axi_arid    ) , // output [0  : 0]                      
    .mem_axi_araddr   ( m1_axi_araddr  ) , // output [63 : 0]                        
    .mem_axi_arlen    ( m1_axi_arlen   ) , // output [7  : 0]                       
    .mem_axi_arsize   ( m1_axi_arsize  ) , // output [2  : 0]                        
    .mem_axi_arburst  ( m1_axi_arburst ) , // output [1  : 0]                         
    .mem_axi_arlock   ( m1_axi_arlock  ) , // output                                 
    .mem_axi_arcache  ( m1_axi_arcache ) , // output [3  : 0]                         
    .mem_axi_arprot   ( m1_axi_arprot  ) , // output [2  : 0]                        
    .mem_axi_arqos    ( m1_axi_arqos   ) , // output [3  : 0]                       
    .mem_axi_arvalid  ( m1_axi_arvalid ) , // output                                  
    .mem_axi_arready  ( m1_axi_arready ) , // input                                   
    .mem_axi_rid      ( m1_axi_rid     ) , // input  [0  : 0]                     
    .mem_axi_rdata    ( m1_axi_rdata   ) , // input  [255: 0]                       
    .mem_axi_rresp    ( m1_axi_rresp   ) , // input  [1  : 0]                       
    .mem_axi_rlast    ( m1_axi_rlast   ) , // input                                 
    .mem_axi_rvalid   ( m1_axi_rvalid  ) , // input                                  
    .mem_axi_rready   ( m1_axi_rready  )   // output   
);


// rdma channel will only write data to local memory
//hac will convert rq to cq,so the max split len is cfg_max_payload
assign cfg_max_read_req_int = (intr_mode == HAC_MODE)? {1'b0,cfg_max_payload} : cfg_max_read_req;

dma_engine #(
    .DEBUG_ON        ( DEBUG_ON      ) ,
    .DMA_DIR         ( "RDMA_R2E"    ) ,
    .M0_AXI_ID_W     ( 1             ) ,
    .M0_AXI_ADDR_W   ( M0_AXI_ADDR_W ) ,
    .M0_AXI_DATA_W   ( M0_AXI_DATA_W ) ,
    .M0_BASE_ADDR    ( M0_BASE_ADDR  ) ,
    .M1_AXI_ID_W     ( 1             ) ,
    .M1_AXI_ADDR_W   ( M1_AXI_ADDR_W ) ,
    .M1_AXI_DATA_W   ( M1_AXI_DATA_W ) ,
    .M1_BASE_ADDR    ( M1_BASE_ADDR  )     
)rdma_r2e(
    .clk              ( user_clk              ) , // input    
    .rst_p            ( rst_p                 ) , // input 
    .cfg_max_payload  ( cfg_max_payload       ) , // input [1   : 0]  2'd0 - 128B; 2'd1 - 256B; 2'd2 - 512B; 2'd3 - 1024B
    .cfg_max_read_req ( cfg_max_read_req_int  ) , // input [2   : 0]  3'd0 - 128B; 3'd1 - 256B; 3'd2 - 512B; 3'd3 - 1024B; 3'd4 - 2048B; 3'd5 - 4096B
    .cfg_rcb_status   ( cfg_rcb_status        ) , // input            0 - 64B; 1 - 128B
    .dma_start        ( rdma_start            ) , // input            dma start pulse. 
    .dma_des_addr     ( rdma_des_addr         ) , // input [63 : 0]   dma initial descriptor address
    .dma_adj_des_num  ( rdma_adj_des_num      ) , // input [7  : 0]   adjacent descriptor number
    .ddma_start       ( drdma_start           ) , // input            direct DMA start
    .ddma_saddr       ( ddma_saddr            ) , // input  [63 : 0]  direct DMA source address
    .ddma_daddr       ( ddma_daddr            ) , // input  [63 : 0]  direct DMA destination address
    .ddma_len         ( ddma_len              ) , // input  [31 : 0]  direct DMA length minus one in byte
    .dma_end          ( rdma_dma_end          ) , // output
    .des_blk_end      ( rdma_des_blk_end      ) , // output
    .des_end          ( rdma_des_end          ) , // output  
    .des_usr_intr     ( rdma_des_usr_intr     ) , // output 
    .dma_flush_intr   ( rdma_flush_intr       ) ,
    .dma_done         ( rdma_done             ) , // output
    .dma_busy         ( rdma_busy             ) , // output
    .fifo_status      ( dma_fifo_status[7:4]  ) , // output [3  : 0] {split_des_fifo_full, split_des_fifo_empty, des_fifo_full, des_fifo_empty}
    .fifo_error       ( dma_fifo_error[7:4]   ) , // output [3  : 0] {split_des_fifo_werr, split_des_fifo_rerr, des_fifo_werr, des_fifo_rerr}
    .dbg_dma_engine_status    ( dbg_rdma_engine_status        ) , 
    .dbg_dma_cnt              ( dbg_rdma_cnt                  ) , 
    .dbg_des_blk_cnt          ( dbg_rdma_des_blk_cnt          ) , 
    .dbg_des_cnt              ( dbg_rdma_des_cnt              ) ,
    .dbg_des_split_rd_des_cnt ( dbg_rdma_des_split_rd_des_cnt ) ,
    .dbg_data_mover_aw_cnt    ( dbg_rdma_data_mover_aw_cnt    ) ,
    .dbg_data_mover_w_cnt     ( dbg_rdma_data_mover_w_cnt     ) ,
    .dbg_data_mover_ar_cnt    ( dbg_rdma_data_mover_ar_cnt    ) ,
    .dbg_data_mover_r_cnt     ( dbg_rdma_data_mover_r_cnt     ) ,
    // AXI to PCIe intf for data writing
    .data_axi_awid    (      ) , // output [0  : 0]                      
    .data_axi_awaddr  (      ) , // output [63 : 0]                        
    .data_axi_awlen   (      ) , // output [7  : 0]                       
    .data_axi_awsize  (      ) , // output [2  : 0]                        
    .data_axi_awburst (      ) , // output [1  : 0]                         
    .data_axi_awlock  (      ) , // output                                 
    .data_axi_awcache (      ) , // output [3  : 0]                         
    .data_axi_awprot  (      ) , // output [2  : 0]                        
    .data_axi_awqos   (      ) , // output [3  : 0]                       
    .data_axi_awvalid (      ) , // output                                  
    .data_axi_awready (  'b1 ) , // input                                   
    .data_axi_wdata   (      ) , // output [255: 0]                       
    .data_axi_wstrb   (      ) , // output [31 : 0]                       
    .data_axi_wlast   (      ) , // output                                
    .data_axi_wvalid  (      ) , // output                                 
    .data_axi_wready  (  'b1 ) , // input                                  
    .data_axi_bid     (  'b0 ) , // input  [0  : 0]                     
    .data_axi_bresp   (  'b0 ) , // input  [1  : 0]                       
    .data_axi_bvalid  (  'b0 ) , // input                                  
    .data_axi_bready  (      ) , // output
	
    .data_axi_arid    ( m0_axi_arid    ) , // output [0  : 0]                      
    .data_axi_araddr  ( m0_axi_araddr  ) , // output [63 : 0]                        
    .data_axi_arlen   ( m0_axi_arlen   ) , // output [7  : 0]                       
    .data_axi_arsize  ( m0_axi_arsize  ) , // output [2  : 0]                        
    .data_axi_arburst ( m0_axi_arburst ) , // output [1  : 0]                         
    .data_axi_arlock  ( m0_axi_arlock  ) , // output                                 
    .data_axi_arcache ( m0_axi_arcache ) , // output [3  : 0]                         
    .data_axi_arprot  ( m0_axi_arprot  ) , // output [2  : 0]                        
    .data_axi_arqos   ( m0_axi_arqos   ) , // output [3  : 0]                       
    .data_axi_arvalid ( m0_axi_arvalid ) , // output                                  
    .data_axi_arready ( m0_axi_arready ) , // input                                   
    .data_axi_rid     ( m0_axi_rid     ) , // input  [0  : 0]                     
    .data_axi_rdata   ( m0_axi_rdata   ) , // input  [255: 0]                       
    .data_axi_rresp   ( m0_axi_rresp   ) , // input  [1  : 0]                       
    .data_axi_rlast   ( m0_axi_rlast   ) , // input                                 
    .data_axi_rvalid  ( m0_axi_rvalid  ) , // input                                  
    .data_axi_rready  ( m0_axi_rready  ) , // output   
    // AXI to memory intf for data reading
    .mem_axi_awid     ( m1_axi_awid    ) , // output [0  : 0]                      
    .mem_axi_awaddr   ( m1_axi_awaddr  ) , // output [63 : 0]                        
    .mem_axi_awlen    ( m1_axi_awlen   ) , // output [7  : 0]                       
    .mem_axi_awsize   ( m1_axi_awsize  ) , // output [2  : 0]                        
    .mem_axi_awburst  ( m1_axi_awburst ) , // output [1  : 0]                         
    .mem_axi_awlock   ( m1_axi_awlock  ) , // output                                 
    .mem_axi_awcache  ( m1_axi_awcache ) , // output [3  : 0]                         
    .mem_axi_awprot   ( m1_axi_awprot  ) , // output [2  : 0]                        
    .mem_axi_awqos    ( m1_axi_awqos   ) , // output [3  : 0]                       
    .mem_axi_awvalid  ( m1_axi_awvalid ) , // output                                  
    .mem_axi_awready  ( m1_axi_awready ) , // input                                   
    .mem_axi_wdata    ( m1_axi_wdata   ) , // output [255: 0]                       
    .mem_axi_wstrb    ( m1_axi_wstrb   ) , // output [31 : 0]                       
    .mem_axi_wlast    ( m1_axi_wlast   ) , // output                                
    .mem_axi_wvalid   ( m1_axi_wvalid  ) , // output                                 
    .mem_axi_wready   ( m1_axi_wready  ) , // input                                  
    .mem_axi_bid      ( m1_axi_bid     ) , // input  [0  : 0]                     
    .mem_axi_bresp    ( m1_axi_bresp   ) , // input  [1  : 0]                       
    .mem_axi_bvalid   ( m1_axi_bvalid  ) , // input                                  
    .mem_axi_bready   ( m1_axi_bready  ) , // output                                 
    .mem_axi_arid     (     ) , // output [0  : 0]                      
    .mem_axi_araddr   (     ) , // output [63 : 0]                        
    .mem_axi_arlen    (     ) , // output [7  : 0]                       
    .mem_axi_arsize   (     ) , // output [2  : 0]                        
    .mem_axi_arburst  (     ) , // output [1  : 0]                         
    .mem_axi_arlock   (     ) , // output                                 
    .mem_axi_arcache  (     ) , // output [3  : 0]                         
    .mem_axi_arprot   (     ) , // output [2  : 0]                        
    .mem_axi_arqos    (     ) , // output [3  : 0]                       
    .mem_axi_arvalid  (     ) , // output                                  
    .mem_axi_arready  ( 'b1 ) , // input                                   
    .mem_axi_rid      ( 'b0 ) , // input  [0  : 0]                     
    .mem_axi_rdata    ( 'b0 ) , // input  [255: 0]                       
    .mem_axi_rresp    ( 'b0 ) , // input  [1  : 0]                       
    .mem_axi_rlast    ( 'b0 ) , // input                                 
    .mem_axi_rvalid   ( 'b0 ) , // input                                  
    .mem_axi_rready   (     )   // output 
);

/*
axi_interconnect_rtl_4sto1m axi_interconnect_rtl_4sto1m_i (
    .INTERCONNECT_ACLK    ( user_clk ) , // input                                     
    .INTERCONNECT_ARESETN ( ~rst_p   ) , // input                                        
    .S00_AXI_ARESET_OUT_N ( ) , // output                                       
    .S01_AXI_ARESET_OUT_N ( ) , // output                                       
    .S02_AXI_ARESET_OUT_N ( ) , // output                                       
    .S03_AXI_ARESET_OUT_N ( ) , // output                                       
    .M00_AXI_ARESET_OUT_N ( ) , // output   
    // s0                                    
    .S00_AXI_ACLK    ( user_clk              ) , // input                                
    .S00_AXI_AWID    ( wdma_des_axi_awid     ) , // input  [0  : 0]                      
    .S00_AXI_AWADDR  ( wdma_des_axi_awaddr   ) , // input  [63 : 0]                        
    .S00_AXI_AWLEN   ( wdma_des_axi_awlen    ) , // input  [7  : 0]                       
    .S00_AXI_AWSIZE  ( wdma_des_axi_awsize   ) , // input  [2  : 0]                        
    .S00_AXI_AWBURST ( wdma_des_axi_awburst  ) , // input  [1  : 0]                         
    .S00_AXI_AWLOCK  ( wdma_des_axi_awlock   ) , // input                                  
    .S00_AXI_AWCACHE ( wdma_des_axi_awcache  ) , // input  [3  : 0]                         
    .S00_AXI_AWPROT  ( wdma_des_axi_awprot   ) , // input  [2  : 0]                        
    .S00_AXI_AWQOS   ( wdma_des_axi_awqos    ) , // input  [3  : 0]                       
    .S00_AXI_AWVALID ( wdma_des_axi_awvalid  ) , // input                                   
    .S00_AXI_AWREADY ( wdma_des_axi_awready  ) , // output                                  
    .S00_AXI_WDATA   ( wdma_des_axi_wdata    ) , // input  [255: 0]                       
    .S00_AXI_WSTRB   ( wdma_des_axi_wstrb    ) , // input  [31 : 0]                       
    .S00_AXI_WLAST   ( wdma_des_axi_wlast    ) , // input                                 
    .S00_AXI_WVALID  ( wdma_des_axi_wvalid   ) , // input                                  
    .S00_AXI_WREADY  ( wdma_des_axi_wready   ) , // output                                 
    .S00_AXI_BID     ( wdma_des_axi_bid      ) , // output [0  : 0]                     
    .S00_AXI_BRESP   ( wdma_des_axi_bresp    ) , // output [1  : 0]                       
    .S00_AXI_BVALID  ( wdma_des_axi_bvalid   ) , // output                                 
    .S00_AXI_BREADY  ( wdma_des_axi_bready   ) , // input                                  
    .S00_AXI_ARID    ( wdma_des_axi_arid     ) , // input  [0  : 0]                      
    .S00_AXI_ARADDR  ( wdma_des_axi_araddr   ) , // input  [63 : 0]                        
    .S00_AXI_ARLEN   ( wdma_des_axi_arlen    ) , // input  [7  : 0]                       
    .S00_AXI_ARSIZE  ( wdma_des_axi_arsize   ) , // input  [2  : 0]                        
    .S00_AXI_ARBURST ( wdma_des_axi_arburst  ) , // input  [1  : 0]                         
    .S00_AXI_ARLOCK  ( wdma_des_axi_arlock   ) , // input                                  
    .S00_AXI_ARCACHE ( wdma_des_axi_arcache  ) , // input  [3  : 0]                         
    .S00_AXI_ARPROT  ( wdma_des_axi_arprot   ) , // input  [2  : 0]                        
    .S00_AXI_ARQOS   ( wdma_des_axi_arqos    ) , // input  [3  : 0]                       
    .S00_AXI_ARVALID ( wdma_des_axi_arvalid  ) , // input                                   
    .S00_AXI_ARREADY ( wdma_des_axi_arready  ) , // output                                  
    .S00_AXI_RID     ( wdma_des_axi_rid      ) , // output [0  : 0]                     
    .S00_AXI_RDATA   ( wdma_des_axi_rdata    ) , // output [255: 0]                       
    .S00_AXI_RRESP   ( wdma_des_axi_rresp    ) , // output [1  : 0]                       
    .S00_AXI_RLAST   ( wdma_des_axi_rlast    ) , // output                                
    .S00_AXI_RVALID  ( wdma_des_axi_rvalid   ) , // output                                 
    .S00_AXI_RREADY  ( wdma_des_axi_rready   ) , // input  
    // s1
    .S01_AXI_ACLK    ( user_clk              ) , // input                                
    .S01_AXI_AWID    ( wdma_data_axi_awid    ) , // input  [0  : 0]                      
    .S01_AXI_AWADDR  ( wdma_data_axi_awaddr  ) , // input  [63 : 0]                        
    .S01_AXI_AWLEN   ( wdma_data_axi_awlen   ) , // input  [7  : 0]                       
    .S01_AXI_AWSIZE  ( wdma_data_axi_awsize  ) , // input  [2  : 0]                        
    .S01_AXI_AWBURST ( wdma_data_axi_awburst ) , // input  [1  : 0]                         
    .S01_AXI_AWLOCK  ( wdma_data_axi_awlock  ) , // input                                  
    .S01_AXI_AWCACHE ( wdma_data_axi_awcache ) , // input  [3  : 0]                         
    .S01_AXI_AWPROT  ( wdma_data_axi_awprot  ) , // input  [2  : 0]                        
    .S01_AXI_AWQOS   ( wdma_data_axi_awqos   ) , // input  [3  : 0]                       
    .S01_AXI_AWVALID ( wdma_data_axi_awvalid ) , // input                                   
    .S01_AXI_AWREADY ( wdma_data_axi_awready ) , // output                                  
    .S01_AXI_WDATA   ( wdma_data_axi_wdata   ) , // input  [255: 0]                       
    .S01_AXI_WSTRB   ( wdma_data_axi_wstrb   ) , // input  [31 : 0]                       
    .S01_AXI_WLAST   ( wdma_data_axi_wlast   ) , // input                                 
    .S01_AXI_WVALID  ( wdma_data_axi_wvalid  ) , // input                                  
    .S01_AXI_WREADY  ( wdma_data_axi_wready  ) , // output                                 
    .S01_AXI_BID     ( wdma_data_axi_bid     ) , // output [0  : 0]                     
    .S01_AXI_BRESP   ( wdma_data_axi_bresp   ) , // output [1  : 0]                       
    .S01_AXI_BVALID  ( wdma_data_axi_bvalid  ) , // output                                 
    .S01_AXI_BREADY  ( wdma_data_axi_bready  ) , // input                                  
    .S01_AXI_ARID    ( wdma_data_axi_arid    ) , // input  [0  : 0]                      
    .S01_AXI_ARADDR  ( wdma_data_axi_araddr  ) , // input  [63 : 0]                        
    .S01_AXI_ARLEN   ( wdma_data_axi_arlen   ) , // input  [7  : 0]                       
    .S01_AXI_ARSIZE  ( wdma_data_axi_arsize  ) , // input  [2  : 0]                        
    .S01_AXI_ARBURST ( wdma_data_axi_arburst ) , // input  [1  : 0]                         
    .S01_AXI_ARLOCK  ( wdma_data_axi_arlock  ) , // input                                  
    .S01_AXI_ARCACHE ( wdma_data_axi_arcache ) , // input  [3  : 0]                         
    .S01_AXI_ARPROT  ( wdma_data_axi_arprot  ) , // input  [2  : 0]                        
    .S01_AXI_ARQOS   ( wdma_data_axi_arqos   ) , // input  [3  : 0]                       
    .S01_AXI_ARVALID ( wdma_data_axi_arvalid ) , // input                                   
    .S01_AXI_ARREADY ( wdma_data_axi_arready ) , // output                                  
    .S01_AXI_RID     ( wdma_data_axi_rid     ) , // output [0  : 0]                     
    .S01_AXI_RDATA   ( wdma_data_axi_rdata   ) , // output [255: 0]                       
    .S01_AXI_RRESP   ( wdma_data_axi_rresp   ) , // output [1  : 0]                       
    .S01_AXI_RLAST   ( wdma_data_axi_rlast   ) , // output                                
    .S01_AXI_RVALID  ( wdma_data_axi_rvalid  ) , // output                                 
    .S01_AXI_RREADY  ( wdma_data_axi_rready  ) , // input    
    // s2
    .S02_AXI_ACLK    ( user_clk              ) , // input                                
    .S02_AXI_AWID    ( rdma_des_axi_awid     ) , // input  [0  : 0]                      
    .S02_AXI_AWADDR  ( rdma_des_axi_awaddr   ) , // input  [63 : 0]                        
    .S02_AXI_AWLEN   ( rdma_des_axi_awlen    ) , // input  [7  : 0]                       
    .S02_AXI_AWSIZE  ( rdma_des_axi_awsize   ) , // input  [2  : 0]                        
    .S02_AXI_AWBURST ( rdma_des_axi_awburst  ) , // input  [1  : 0]                         
    .S02_AXI_AWLOCK  ( rdma_des_axi_awlock   ) , // input                                  
    .S02_AXI_AWCACHE ( rdma_des_axi_awcache  ) , // input  [3  : 0]                         
    .S02_AXI_AWPROT  ( rdma_des_axi_awprot   ) , // input  [2  : 0]                        
    .S02_AXI_AWQOS   ( rdma_des_axi_awqos    ) , // input  [3  : 0]                       
    .S02_AXI_AWVALID ( rdma_des_axi_awvalid  ) , // input                                   
    .S02_AXI_AWREADY ( rdma_des_axi_awready  ) , // output                                  
    .S02_AXI_WDATA   ( rdma_des_axi_wdata    ) , // input  [255: 0]                       
    .S02_AXI_WSTRB   ( rdma_des_axi_wstrb    ) , // input  [31 : 0]                       
    .S02_AXI_WLAST   ( rdma_des_axi_wlast    ) , // input                                 
    .S02_AXI_WVALID  ( rdma_des_axi_wvalid   ) , // input                                  
    .S02_AXI_WREADY  ( rdma_des_axi_wready   ) , // output                                 
    .S02_AXI_BID     ( rdma_des_axi_bid      ) , // output [0  : 0]                     
    .S02_AXI_BRESP   ( rdma_des_axi_bresp    ) , // output [1  : 0]                       
    .S02_AXI_BVALID  ( rdma_des_axi_bvalid   ) , // output                                 
    .S02_AXI_BREADY  ( rdma_des_axi_bready   ) , // input                                  
    .S02_AXI_ARID    ( rdma_des_axi_arid     ) , // input  [0  : 0]                      
    .S02_AXI_ARADDR  ( rdma_des_axi_araddr   ) , // input  [63 : 0]                        
    .S02_AXI_ARLEN   ( rdma_des_axi_arlen    ) , // input  [7  : 0]                       
    .S02_AXI_ARSIZE  ( rdma_des_axi_arsize   ) , // input  [2  : 0]                        
    .S02_AXI_ARBURST ( rdma_des_axi_arburst  ) , // input  [1  : 0]                         
    .S02_AXI_ARLOCK  ( rdma_des_axi_arlock   ) , // input                                  
    .S02_AXI_ARCACHE ( rdma_des_axi_arcache  ) , // input  [3  : 0]                         
    .S02_AXI_ARPROT  ( rdma_des_axi_arprot   ) , // input  [2  : 0]                        
    .S02_AXI_ARQOS   ( rdma_des_axi_arqos    ) , // input  [3  : 0]                       
    .S02_AXI_ARVALID ( rdma_des_axi_arvalid  ) , // input                                   
    .S02_AXI_ARREADY ( rdma_des_axi_arready  ) , // output                                  
    .S02_AXI_RID     ( rdma_des_axi_rid      ) , // output [0  : 0]                     
    .S02_AXI_RDATA   ( rdma_des_axi_rdata    ) , // output [255: 0]                       
    .S02_AXI_RRESP   ( rdma_des_axi_rresp    ) , // output [1  : 0]                       
    .S02_AXI_RLAST   ( rdma_des_axi_rlast    ) , // output                                
    .S02_AXI_RVALID  ( rdma_des_axi_rvalid   ) , // output                                 
    .S02_AXI_RREADY  ( rdma_des_axi_rready   ) , // input    
    // s3
    .S03_AXI_ACLK    ( user_clk              ) , // input                                
    .S03_AXI_AWID    ( rdma_data_axi_awid    ) , // input  [0  : 0]                      
    .S03_AXI_AWADDR  ( rdma_data_axi_awaddr  ) , // input  [63 : 0]                        
    .S03_AXI_AWLEN   ( rdma_data_axi_awlen   ) , // input  [7  : 0]                       
    .S03_AXI_AWSIZE  ( rdma_data_axi_awsize  ) , // input  [2  : 0]                        
    .S03_AXI_AWBURST ( rdma_data_axi_awburst ) , // input  [1  : 0]                         
    .S03_AXI_AWLOCK  ( rdma_data_axi_awlock  ) , // input                                  
    .S03_AXI_AWCACHE ( rdma_data_axi_awcache ) , // input  [3  : 0]                         
    .S03_AXI_AWPROT  ( rdma_data_axi_awprot  ) , // input  [2  : 0]                        
    .S03_AXI_AWQOS   ( rdma_data_axi_awqos   ) , // input  [3  : 0]                       
    .S03_AXI_AWVALID ( rdma_data_axi_awvalid ) , // input                                   
    .S03_AXI_AWREADY ( rdma_data_axi_awready ) , // output                                  
    .S03_AXI_WDATA   ( rdma_data_axi_wdata   ) , // input  [255: 0]                       
    .S03_AXI_WSTRB   ( rdma_data_axi_wstrb   ) , // input  [31 : 0]                       
    .S03_AXI_WLAST   ( rdma_data_axi_wlast   ) , // input                                 
    .S03_AXI_WVALID  ( rdma_data_axi_wvalid  ) , // input                                  
    .S03_AXI_WREADY  ( rdma_data_axi_wready  ) , // output                                 
    .S03_AXI_BID     ( rdma_data_axi_bid     ) , // output [0  : 0]                     
    .S03_AXI_BRESP   ( rdma_data_axi_bresp   ) , // output [1  : 0]                       
    .S03_AXI_BVALID  ( rdma_data_axi_bvalid  ) , // output                                 
    .S03_AXI_BREADY  ( rdma_data_axi_bready  ) , // input                                  
    .S03_AXI_ARID    ( rdma_data_axi_arid    ) , // input  [0  : 0]                      
    .S03_AXI_ARADDR  ( rdma_data_axi_araddr  ) , // input  [63 : 0]                        
    .S03_AXI_ARLEN   ( rdma_data_axi_arlen   ) , // input  [7  : 0]                       
    .S03_AXI_ARSIZE  ( rdma_data_axi_arsize  ) , // input  [2  : 0]                        
    .S03_AXI_ARBURST ( rdma_data_axi_arburst ) , // input  [1  : 0]                         
    .S03_AXI_ARLOCK  ( rdma_data_axi_arlock  ) , // input                                  
    .S03_AXI_ARCACHE ( rdma_data_axi_arcache ) , // input  [3  : 0]                         
    .S03_AXI_ARPROT  ( rdma_data_axi_arprot  ) , // input  [2  : 0]                        
    .S03_AXI_ARQOS   ( rdma_data_axi_arqos   ) , // input  [3  : 0]                       
    .S03_AXI_ARVALID ( rdma_data_axi_arvalid ) , // input                                   
    .S03_AXI_ARREADY ( rdma_data_axi_arready ) , // output                                  
    .S03_AXI_RID     ( rdma_data_axi_rid     ) , // output [0  : 0]                     
    .S03_AXI_RDATA   ( rdma_data_axi_rdata   ) , // output [255: 0]                       
    .S03_AXI_RRESP   ( rdma_data_axi_rresp   ) , // output [1  : 0]                       
    .S03_AXI_RLAST   ( rdma_data_axi_rlast   ) , // output                                
    .S03_AXI_RVALID  ( rdma_data_axi_rvalid  ) , // output                                 
    .S03_AXI_RREADY  ( rdma_data_axi_rready  ) , // input 
    // m0 
    .M00_AXI_ACLK    ( user_clk           ) , // input                                
    .M00_AXI_AWID    ( m0_axi_awid        ) , // output [3  : 0]                      
    .M00_AXI_AWADDR  ( m0_axi_awaddr_int  ) , // output [63 : 0]                        
    .M00_AXI_AWLEN   ( m0_axi_awlen       ) , // output [7  : 0]                       
    .M00_AXI_AWSIZE  ( m0_axi_awsize      ) , // output [2  : 0]                        
    .M00_AXI_AWBURST ( m0_axi_awburst     ) , // output [1  : 0]                         
    .M00_AXI_AWLOCK  ( m0_axi_awlock      ) , // output                                 
    .M00_AXI_AWCACHE ( m0_axi_awcache     ) , // output [3  : 0]                         
    .M00_AXI_AWPROT  ( m0_axi_awprot      ) , // output [2  : 0]                        
    .M00_AXI_AWQOS   ( m0_axi_awqos       ) , // output [3  : 0]                       
    .M00_AXI_AWVALID ( m0_axi_awvalid     ) , // output                                  
    .M00_AXI_AWREADY ( m0_axi_awready     ) , // input                                   
    .M00_AXI_WDATA   ( m0_axi_wdata       ) , // output [255: 0]                       
    .M00_AXI_WSTRB   ( m0_axi_wstrb       ) , // output [31 : 0]                       
    .M00_AXI_WLAST   ( m0_axi_wlast       ) , // output                                
    .M00_AXI_WVALID  ( m0_axi_wvalid      ) , // output                                 
    .M00_AXI_WREADY  ( m0_axi_wready      ) , // input                                  
    .M00_AXI_BID     ( m0_axi_bid         ) , // input  [3  : 0]                     
    .M00_AXI_BRESP   ( m0_axi_bresp       ) , // input  [1  : 0]                       
    .M00_AXI_BVALID  ( m0_axi_bvalid      ) , // input                                  
    .M00_AXI_BREADY  ( m0_axi_bready      ) , // output                                 
    .M00_AXI_ARID    ( m0_axi_arid        ) , // output [3  : 0]                      
    .M00_AXI_ARADDR  ( m0_axi_araddr_int  ) , // output [63 : 0]                        
    .M00_AXI_ARLEN   ( m0_axi_arlen       ) , // output [7  : 0]                       
    .M00_AXI_ARSIZE  ( m0_axi_arsize      ) , // output [2  : 0]                        
    .M00_AXI_ARBURST ( m0_axi_arburst     ) , // output [1  : 0]                         
    .M00_AXI_ARLOCK  ( m0_axi_arlock      ) , // output                                 
    .M00_AXI_ARCACHE ( m0_axi_arcache     ) , // output [3  : 0]                         
    .M00_AXI_ARPROT  ( m0_axi_arprot      ) , // output [2  : 0]                        
    .M00_AXI_ARQOS   ( m0_axi_arqos       ) , // output [3  : 0]                       
    .M00_AXI_ARVALID ( m0_axi_arvalid     ) , // output                                  
    .M00_AXI_ARREADY ( m0_axi_arready_int ) , // input                                   
    .M00_AXI_RID     ( m0_axi_rid_int     ) , // input  [3  : 0]                     
    .M00_AXI_RDATA   ( m0_axi_rdata       ) , // input  [255: 0]                       
    .M00_AXI_RRESP   ( m0_axi_rresp       ) , // input  [1  : 0]                       
    .M00_AXI_RLAST   ( m0_axi_rlast       ) , // input                                 
    .M00_AXI_RVALID  ( m0_axi_rvalid      ) , // input                                  
    .M00_AXI_RREADY  ( m0_axi_rready_int  )   // output                                
);


axi_crossbar_2sto1m inst_axi_crossbar (
  .aclk                 (user_clk),                  // input wire aclk
  .aresetn              (~rst_p  ),               // input wire aresetn
  .s_axi_awid           (),          // input wire [1 : 0] s_axi_awid
  .s_axi_awaddr         (),      // input wire [127 : 0] s_axi_awaddr
  .s_axi_awlen          (),        // input wire [15 : 0] s_axi_awlen
  .s_axi_awsize         (),      // input wire [5 : 0] s_axi_awsize
  .s_axi_awburst        (),    // input wire [3 : 0] s_axi_awburst
  .s_axi_awlock         (),      // input wire [1 : 0] s_axi_awlock
  .s_axi_awcache        (),    // input wire [7 : 0] s_axi_awcache
  .s_axi_awprot         (),      // input wire [5 : 0] s_axi_awprot
  .s_axi_awqos          (),        // input wire [7 : 0] s_axi_awqos
  .s_axi_awvalid        (2'b0),    // input wire [1 : 0] s_axi_awvalid
  .s_axi_awready        (),    // output wire [1 : 0] s_axi_awready
  .s_axi_wdata          (),        // input wire [511 : 0] s_axi_wdata
  .s_axi_wstrb          (),        // input wire [63 : 0] s_axi_wstrb
  .s_axi_wlast          (),        // input wire [1 : 0] s_axi_wlast
  .s_axi_wvalid         (2'b0),      // input wire [1 : 0] s_axi_wvalid
  .s_axi_wready         (),      // output wire [1 : 0] s_axi_wready
  .s_axi_bid            (),            // output wire [1 : 0] s_axi_bid
  .s_axi_bresp          (),        // output wire [3 : 0] s_axi_bresp
  .s_axi_bvalid         (),      // output wire [1 : 0] s_axi_bvalid
  .s_axi_bready         (),      // input wire [1 : 0] s_axi_bready
  .s_axi_arid           ({m11_axi_arid    ,m10_axi_arid    }),        // input wire [1 : 0] s_axi_arid
  .s_axi_araddr         ({m11_axi_araddr  ,m10_axi_araddr  }),      // input wire [127 : 0] s_axi_araddr
  .s_axi_arlen          ({m11_axi_arlen   ,m10_axi_arlen   }),     // input wire [15 : 0] s_axi_arlen
  .s_axi_arsize         ({m11_axi_arsize  ,m10_axi_arsize  }),    // input wire [5 : 0] s_axi_arsize
  .s_axi_arburst        ({m11_axi_arburst ,m10_axi_arburst }),   // input wire [3 : 0] s_axi_arburst
  .s_axi_arlock         ({m11_axi_arlock  ,m10_axi_arlock  }),    // input wire [1 : 0] s_axi_arlock
  .s_axi_arcache        ({m11_axi_arcache ,m10_axi_arcache }),   // input wire [7 : 0] s_axi_arcache
  .s_axi_arprot         ({m11_axi_arprot  ,m10_axi_arprot  }),    // input wire [5 : 0] s_axi_arprot
  .s_axi_arqos          ({m11_axi_arqos   ,m10_axi_arqos   }),     // input wire [7 : 0] s_axi_arqos
  .s_axi_arvalid        ({m11_axi_arvalid ,m10_axi_arvalid }),   // input wire [1 : 0] s_axi_arvalid
  .s_axi_arready        ({m11_axi_arready ,m10_axi_arready }),   // output wire [1 : 0] s_axi_arready
  .s_axi_rid            ({m11_axi_rid     ,m10_axi_rid     }),       // output wire [1 : 0] s_axi_rid
  .s_axi_rdata          ({m11_axi_rdata   ,m10_axi_rdata   }),     // output wire [511 : 0] s_axi_rdata
  .s_axi_rresp          ({m11_axi_rresp   ,m10_axi_rresp   }),     // output wire [3 : 0] s_axi_rresp
  .s_axi_rlast          ({m11_axi_rlast   ,m10_axi_rlast   }),     // output wire [1 : 0] s_axi_rlast
  .s_axi_rvalid         ({m11_axi_rvalid  ,m10_axi_rvalid  }),    // output wire [1 : 0] s_axi_rvalid
  .s_axi_rready         ({m11_axi_rready  ,m10_axi_rready  }),    // input wire [1 : 0] s_axi_rready
  .m_axi_awid           (),          // output wire [0 : 0] m_axi_awid
  .m_axi_awaddr         (),      // output wire [63 : 0] m_axi_awaddr
  .m_axi_awlen          (),        // output wire [7 : 0] m_axi_awlen
  .m_axi_awsize         (),      // output wire [2 : 0] m_axi_awsize
  .m_axi_awburst        (),    // output wire [1 : 0] m_axi_awburst
  .m_axi_awlock         (),      // output wire [0 : 0] m_axi_awlock
  .m_axi_awcache        (),    // output wire [3 : 0] m_axi_awcache
  .m_axi_awprot         (),      // output wire [2 : 0] m_axi_awprot
  .m_axi_awregion       (),  // output wire [3 : 0] m_axi_awregion
  .m_axi_awqos          (),        // output wire [3 : 0] m_axi_awqos
  .m_axi_awvalid        (),    // output wire [0 : 0] m_axi_awvalid
  .m_axi_awready        (1'b0),    // input wire [0 : 0] m_axi_awready
  .m_axi_wdata          (),        // output wire [255 : 0] m_axi_wdata
  .m_axi_wstrb          (),        // output wire [31 : 0] m_axi_wstrb
  .m_axi_wlast          (),        // output wire [0 : 0] m_axi_wlast
  .m_axi_wvalid         (),      // output wire [0 : 0] m_axi_wvalid
  .m_axi_wready         (1'b0),      // input wire [0 : 0] m_axi_wready
  .m_axi_bid            (),            // input wire [0 : 0] m_axi_bid
  .m_axi_bresp          (),        // input wire [1 : 0] m_axi_bresp
  .m_axi_bvalid         (1'b0),      // input wire [0 : 0] m_axi_bvalid
  .m_axi_bready         (),      // output wire [0 : 0] m_axi_bready
  .m_axi_arid           (m1_axi_arid   ),      // output wire [0 : 0] m_axi_arid
  .m_axi_araddr         (m1_axi_araddr ),    // output wire [63 : 0] m_axi_araddr
  .m_axi_arlen          (m1_axi_arlen  ),     // output wire [7 : 0] m_axi_arlen
  .m_axi_arsize         (m1_axi_arsize ),    // output wire [2 : 0] m_axi_arsize
  .m_axi_arburst        (m1_axi_arburst),   // output wire [1 : 0] m_axi_arburst
  .m_axi_arlock         (m1_axi_arlock ),    // output wire [0 : 0] m_axi_arlock
  .m_axi_arcache        (m1_axi_arcache),   // output wire [3 : 0] m_axi_arcache
  .m_axi_arprot         (m1_axi_arprot ),    // output wire [2 : 0] m_axi_arprot
  .m_axi_arregion       (), // output wire [3 : 0] m_axi_arregion
  .m_axi_arqos          (m1_axi_arqos  ),     // output wire [3 : 0] m_axi_arqos
  .m_axi_arvalid        (m1_axi_arvalid),   // output wire [0 : 0] m_axi_arvalid
  .m_axi_arready        (m1_axi_arready),   // input wire [0 : 0] m_axi_arready
  .m_axi_rid            (m1_axi_rid    ),       // input wire [0 : 0] m_axi_rid
  .m_axi_rdata          (m1_axi_rdata  ),     // input wire [255 : 0] m_axi_rdata
  .m_axi_rresp          (m1_axi_rresp  ),     // input wire [1 : 0] m_axi_rresp
  .m_axi_rlast          (m1_axi_rlast  ),     // input wire [0 : 0] m_axi_rlast
  .m_axi_rvalid         (m1_axi_rvalid ),    // input wire [0 : 0] m_axi_rvalid
  .m_axi_rready         (m1_axi_rready )   // output wire [0 : 0] m_axi_rready
);

assign m0_axi_awaddr =  (intr_mode == HAC_MODE)?dma_tlp_bar0_addr + m0_axi_awaddr_int[20:0] : m0_axi_awaddr_int;
assign m0_axi_araddr =  (intr_mode == HAC_MODE)?dma_tlp_bar0_addr + m0_axi_araddr_int[20:0] : m0_axi_araddr_int;

*/




/*
assign m0_axi_arready_int = m0_axi_arready;
assign m0_axi_rready      = m0_axi_rready_int;
assign m0_axi_rid_int     = m0_axi_rid;
*/
// ---------- store AXI ID in local FIFO  ---------- //
// This requires that all read data comes back in strict order

logic axi_id_fifo_full;
logic axi_id_fifo_wr;

logic axi_id_fifo_empty;
logic axi_id_fifo_rd;

assign axi_id_fifo_wr = m0_axi_arvalid & m0_axi_arready;
assign axi_id_fifo_rd = m0_axi_rvalid & m0_axi_rready & m0_axi_rlast;

assign m0_axi_arready_int = m0_axi_arready & ~axi_id_fifo_full;
// assign m0_axi_rready = m0_axi_rready_int & ~axi_id_fifo_empty;

sync_fifo_gen #(
    .FIFO_MEMORY_TYPE  ( "auto"      ) , // String   "auto", "block", "distributed", "ultra"
    .READ_MODE         ( "fwft"      ) , // String   "std", "fwft"
    .FIFO_WRITE_DEPTH  ( 32          ) , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
    .DATA_WIDTH        ( M0_AXI_ID_W )   // DECIMAL  1 - 4096
) axi_id_fifo ( 
    .clk       ( user_clk          ) ,
    .srst      ( user_reset        ) ,
    .full      ( axi_id_fifo_full  ) ,
    .din       ( m0_axi_arid       ) ,
    .wr_en     ( axi_id_fifo_wr    ) ,
    .empty     ( axi_id_fifo_empty ) ,
    .dout      ( m0_axi_rid_int    ) ,
    .rd_en     ( axi_id_fifo_rd    ) ,
    .prog_full (                   )
) ;

`ifdef DMA_DEBUG

(* mark_debug = "true" *) logic                         ila_dma_user_reset        ;  
(* mark_debug = "true" *) logic                         ila_dma_soft_rstp         ; 
(* mark_debug = "true" *) logic                         ila_dma_wdma_start        ; // trigger  
(* mark_debug = "true" *) logic [63                : 0] ila_dma_wdma_des_addr     ; 
(* mark_debug = "true" *) logic [7                 : 0] ila_dma_wdma_adj_des_num  ; 
(* mark_debug = "true" *) logic                         ila_dma_rdma_start        ; // trigger
(* mark_debug = "true" *) logic [63                : 0] ila_dma_rdma_des_addr     ; 
(* mark_debug = "true" *) logic [7                 : 0] ila_dma_rdma_adj_des_num  ; 
(* mark_debug = "true" *) logic                         ila_dma_dwdma_start       ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_drdma_start       ; // trigger
(* mark_debug = "true" *) logic [63                : 0] ila_dma_ddma_saddr        ; 
(* mark_debug = "true" *) logic [63                : 0] ila_dma_ddma_daddr        ; 
(* mark_debug = "true" *) logic [31                : 0] ila_dma_ddma_len          ; 
(* mark_debug = "true" *) logic                         ila_dma_wdma_dma_end      ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_wdma_des_blk_end  ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_wdma_des_end      ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_wdma_des_usr_intr ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_rdma_dma_end      ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_rdma_des_blk_end  ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_rdma_des_end      ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_rdma_des_usr_intr ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_wdma_done         ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_wdma_busy         ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_rdma_done         ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_rdma_busy         ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_wdma_flush_intr         ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_rdma_flush_intr         ; // trigger
(* mark_debug = "true" *) logic [7                 : 0] ila_dma_dma_fifo_status   ;           
(* mark_debug = "true" *) logic [7                 : 0] ila_dma_dma_fifo_error    ;   
(* mark_debug = "true" *) logic [M0_AXI_ADDR_W-1   : 0] ila_dma_m0_axi_awaddr     ;   
(* mark_debug = "true" *) logic [7                 : 0] ila_dma_m0_axi_awlen      ;
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_awvalid    ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_awready    ; // trigger
(* mark_debug = "true" *) logic [M0_AXI_DATA_W-1   : 0] ila_dma_m0_axi_wdata      ; 
(* mark_debug = "true" *) logic [M0_AXI_DATA_W/8-1 : 0] ila_dma_m0_axi_wstrb      ;
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_wlast      ;
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_wvalid     ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_wready     ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_bvalid     ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_bready     ; // trigger
(* mark_debug = "true" *) logic [M0_AXI_ADDR_W-1   : 0] ila_dma_m0_axi_araddr     ;
(* mark_debug = "true" *) logic [7                 : 0] ila_dma_m0_axi_arlen      ;
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_arvalid    ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_arready    ; // trigger
(* mark_debug = "true" *) logic [M0_AXI_DATA_W-1   : 0] ila_dma_m0_axi_rdata      ;
(* mark_debug = "true" *) logic [0                 : 0] ila_dma_m0_axi_rlast      ;
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_rvalid     ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m0_axi_rready     ; // trigger
(* mark_debug = "true" *) logic [M1_AXI_ADDR_W-1   : 0] ila_dma_m1_axi_awaddr     ;   
(* mark_debug = "true" *) logic [7                 : 0] ila_dma_m1_axi_awlen      ;
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_awvalid    ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_awready    ; // trigger
(* mark_debug = "true" *) logic [M1_AXI_DATA_W-1   : 0] ila_dma_m1_axi_wdata      ; 
(* mark_debug = "true" *) logic [M1_AXI_DATA_W/8-1 : 0] ila_dma_m1_axi_wstrb      ;
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_wlast      ;
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_wvalid     ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_wready     ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_bvalid     ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_bready     ; // trigger
(* mark_debug = "true" *) logic [M1_AXI_ADDR_W-1   : 0] ila_dma_m1_axi_araddr     ;
(* mark_debug = "true" *) logic [7                 : 0] ila_dma_m1_axi_arlen      ;
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_arvalid    ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_arready    ; // trigger
(* mark_debug = "true" *) logic [M1_AXI_DATA_W-1   : 0] ila_dma_m1_axi_rdata      ;
(* mark_debug = "true" *) logic [0                 : 0] ila_dma_m1_axi_rlast      ;
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_rvalid     ; // trigger
(* mark_debug = "true" *) logic                         ila_dma_m1_axi_rready     ; // trigger

assign ila_dma_user_reset        = user_reset        ;  
assign ila_dma_soft_rstp         = soft_rstp         ; 
assign ila_dma_wdma_start        = wdma_start        ; // trigger  
assign ila_dma_wdma_des_addr     = wdma_des_addr     ; 
assign ila_dma_wdma_adj_des_num  = wdma_adj_des_num  ; 
assign ila_dma_rdma_start        = rdma_start        ; // trigger
assign ila_dma_rdma_des_addr     = rdma_des_addr     ; 
assign ila_dma_rdma_adj_des_num  = rdma_adj_des_num  ; 
assign ila_dma_dwdma_start       = dwdma_start       ; // trigger
assign ila_dma_drdma_start       = drdma_start       ; // trigger
assign ila_dma_ddma_saddr        = ddma_saddr        ; 
assign ila_dma_ddma_daddr        = ddma_daddr        ; 
assign ila_dma_ddma_len          = ddma_len          ; 
assign ila_dma_wdma_dma_end      = wdma_dma_end      ; // trigger
assign ila_dma_wdma_des_blk_end  = wdma_des_blk_end  ; // trigger
assign ila_dma_wdma_des_end      = wdma_des_end      ; // trigger
assign ila_dma_wdma_des_usr_intr = wdma_des_usr_intr ; // trigger
assign ila_dma_rdma_dma_end      = rdma_dma_end      ; // trigger
assign ila_dma_rdma_des_blk_end  = rdma_des_blk_end  ; // trigger
assign ila_dma_rdma_des_end      = rdma_des_end      ; // trigger
assign ila_dma_rdma_des_usr_intr = rdma_des_usr_intr ; // trigger
assign ila_dma_wdma_done         = wdma_done         ; // trigger
assign ila_dma_wdma_busy         = wdma_busy         ; // trigger
assign ila_dma_rdma_done         = rdma_done         ; // trigger
assign ila_dma_rdma_busy         = rdma_busy         ; // trigger
assign ila_dma_wdma_flush_intr   = wdma_flush_intr   ;
assign ila_dma_rdma_flush_intr   = rdma_flush_intr   ;
assign ila_dma_dma_fifo_status   = dma_fifo_status   ;           
assign ila_dma_dma_fifo_error    = dma_fifo_error    ;   
assign ila_dma_m0_axi_awaddr     = m0_axi_awaddr     ;   
assign ila_dma_m0_axi_awlen      = m0_axi_awlen      ;
assign ila_dma_m0_axi_awvalid    = m0_axi_awvalid    ; // trigger
assign ila_dma_m0_axi_awready    = m0_axi_awready    ; // trigger
assign ila_dma_m0_axi_wdata      = m0_axi_wdata      ; 
assign ila_dma_m0_axi_wstrb      = m0_axi_wstrb      ;
assign ila_dma_m0_axi_wlast      = m0_axi_wlast      ;
assign ila_dma_m0_axi_wvalid     = m0_axi_wvalid     ; // trigger
assign ila_dma_m0_axi_wready     = m0_axi_wready     ; // trigger
assign ila_dma_m0_axi_bvalid     = m0_axi_bvalid     ; // trigger
assign ila_dma_m0_axi_bready     = m0_axi_bready     ; // trigger
assign ila_dma_m0_axi_araddr     = m0_axi_araddr     ;
assign ila_dma_m0_axi_arlen      = m0_axi_arlen      ;
assign ila_dma_m0_axi_arvalid    = m0_axi_arvalid    ; // trigger
assign ila_dma_m0_axi_arready    = m0_axi_arready    ; // trigger
assign ila_dma_m0_axi_rdata      = m0_axi_rdata      ;
assign ila_dma_m0_axi_rlast      = m0_axi_rlast      ;
assign ila_dma_m0_axi_rvalid     = m0_axi_rvalid     ; // trigger
assign ila_dma_m0_axi_rready     = m0_axi_rready     ; // trigger
assign ila_dma_m1_axi_awaddr     = m1_axi_awaddr     ;   
assign ila_dma_m1_axi_awlen      = m1_axi_awlen      ;
assign ila_dma_m1_axi_awvalid    = m1_axi_awvalid    ; // trigger
assign ila_dma_m1_axi_awready    = m1_axi_awready    ; // trigger
assign ila_dma_m1_axi_wdata      = m1_axi_wdata      ; 
assign ila_dma_m1_axi_wstrb      = m1_axi_wstrb      ;
assign ila_dma_m1_axi_wlast      = m1_axi_wlast      ;
assign ila_dma_m1_axi_wvalid     = m1_axi_wvalid     ; // trigger
assign ila_dma_m1_axi_wready     = m1_axi_wready     ; // trigger
assign ila_dma_m1_axi_bvalid     = m1_axi_bvalid     ; // trigger
assign ila_dma_m1_axi_bready     = m1_axi_bready     ; // trigger
assign ila_dma_m1_axi_araddr     = m1_axi_araddr     ;
assign ila_dma_m1_axi_arlen      = m1_axi_arlen      ;
assign ila_dma_m1_axi_arvalid    = m1_axi_arvalid    ; // trigger
assign ila_dma_m1_axi_arready    = m1_axi_arready    ; // trigger
assign ila_dma_m1_axi_rdata      = m1_axi_rdata      ;
assign ila_dma_m1_axi_rlast      = m1_axi_rlast      ;
assign ila_dma_m1_axi_rvalid     = m1_axi_rvalid     ; // trigger
assign ila_dma_m1_axi_rready     = m1_axi_rready     ; // trigger


`endif


endmodule
