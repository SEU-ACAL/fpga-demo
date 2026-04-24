/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

module rqrc_intf #(
    parameter         DEBUG_ON     = "FALSE"                  , // "FALSE" or "TRUE"
    parameter integer S_AXI_ID_W   = 4                        , // Slave
    parameter integer S_AXI_ADDR_W = 64                       ,
    parameter integer S_AXI_DATA_W = 256                      ,
    parameter         S_BASE_ADDR   = {{S_AXI_ADDR_W}{1'b0}} 
)(  
  // clock and reset
  input                         user_clk         , // input    
  input                         user_reset       , // input 
  // RQ/RC 
  output [255              : 0] s_axis_rq_tdata  , // output [255 : 0] 
  output [7                : 0] s_axis_rq_tkeep  , // output [7   : 0] 
  output                        s_axis_rq_tlast  , // output           
  input                         s_axis_rq_tready , // input  
  output [59               : 0] s_axis_rq_tuser  , // output [59  : 0]
  output                        s_axis_rq_tvalid , // output           
  input  [255              : 0] m_axis_rc_tdata  , // input  [255 : 0] 
  input  [7                : 0] m_axis_rc_tkeep  , // input  [7   : 0] 
  input                         m_axis_rc_tlast  , // input            
  output                        m_axis_rc_tready , // output   
  input  [74               : 0] m_axis_rc_tuser  , // input  [74  : 0]         
  input                         m_axis_rc_tvalid , // input  
  // Interrupt 

  // AXI-MM-slave   
  input                         s_axi_aclk       , // Unused
  input                         s_axi_aresetn    , // Unused
  input  [S_AXI_ID_W-1     : 0] s_axi_awid       , // wr addr
  input  [S_AXI_ADDR_W-1   : 0] s_axi_awaddr     ,
  input  [7                : 0] s_axi_awlen      ,
  input  [2                : 0] s_axi_awsize     ,
  input  [1                : 0] s_axi_awburst    ,
  input  [3                : 0] s_axi_awregion   , // Unused
  input                         s_axi_awlock     , // Unused
  input  [3                : 0] s_axi_awcache    , // Unused
  input  [2                : 0] s_axi_awprot     , // Unused
  input  [3                : 0] s_axi_awqos      , // Unused
  input                         s_axi_awvalid    ,
  output                        s_axi_awready    ,
  input  [S_AXI_DATA_W-1   : 0] s_axi_wdata      , // wr data
  input  [S_AXI_DATA_W/8-1 : 0] s_axi_wstrb      ,
  input                         s_axi_wlast      ,
  input                         s_axi_wvalid     ,
  output                        s_axi_wready     ,
  output [S_AXI_ID_W-1     : 0] s_axi_bid        , // wr res
  output [1                : 0] s_axi_bresp      ,
  output                        s_axi_bvalid     ,
  input                         s_axi_bready     ,
  input  [S_AXI_ID_W-1     : 0] s_axi_arid       , // rd addr
  input  [S_AXI_ADDR_W-1   : 0] s_axi_araddr     ,
  input  [7                : 0] s_axi_arlen      ,
  input  [2                : 0] s_axi_arsize     ,
  input  [1                : 0] s_axi_arburst    ,
  input  [3                : 0] s_axi_arregion   , // Unused
  input                         s_axi_arlock     , // Unused
  input  [3                : 0] s_axi_arcache    , // Unused
  input  [2                : 0] s_axi_arprot     , // Unused
  input  [3                : 0] s_axi_arqos      , // Unused
  input                         s_axi_arvalid    ,
  output                        s_axi_arready    ,
  output [S_AXI_ID_W-1     : 0] s_axi_rid        , // rd data
  output [S_AXI_DATA_W-1   : 0] s_axi_rdata      ,
  output [1                : 0] s_axi_rresp      ,
  output                        s_axi_rlast      ,
  output                        s_axi_rvalid     ,
  input                         s_axi_rready     ,

  output [31 : 0] dbg_rq_waxi_aw_cnt          ,
  output [31 : 0] dbg_rq_waxi_w_cnt           ,
  output [31 : 0] dbg_rq_raxi_ar_cnt          ,
  output [31 : 0] dbg_rq_raxi_r_cnt           ,
  output [31 : 0] dbg_rqtlpgen_rd_wdes_cnt    ,
  output [31 : 0] dbg_rqtlpgen_rd_rdes_cnt    ,
  output [31 : 0] dbg_rqrctlpproc_tlp_out_cnt ,
  output [15 : 0] dbg_rqrctlpproc_tlp_status1 ,
  output [31 : 0] dbg_rqrctlpproc_tlp_status2 ,
  output [31 : 0] dbg_rqintf_tlp_out_cnt      ,
  output [31 : 0] dbg_rcintf_vldpkt_cnt       ,
  output [31 : 0] dbg_rcintf_pkt_cnt          ,   
  output [31 : 0] dbg_rcreorder_opkt_cnt      ,
  output [15 : 0] dbg_rcreorder_tag             

) ;

logic           rq_tlp_fifo_req    ;
logic           rq_tlp_fifo_rd     ;
logic [275 : 0] rq_tlp_fifo_rdata  ; // {eop, addr_offset[2:0], last_be[3:0], first_be[3:0], tkeep[7:0], data[255:0]}  

logic [15  : 0] release_tag       ;
logic           tag_buffer_wr     ;
logic [262 : 0] tag_buffer_wdata  ;  // {tag[3:0], req_completed, func_id[1:0], data[255:0]}

logic           rc_data_fifo_full  ;
logic           rc_data_fifo_pfull ;
logic           rc_data_fifo_wr    ;
logic [258 : 0] rc_data_fifo_wdata ; // {eop, func_id[1:0], data[255:0]}

rq_intf rq_intf_inst(
  .user_clk          ( user_clk             ) , // input    
  .user_reset        ( user_reset           ) , // input 
  .s_axis_rq_tdata   ( s_axis_rq_tdata      ) , // output [255 : 0] 
  .s_axis_rq_tkeep   ( s_axis_rq_tkeep      ) , // output [7   : 0] 
  .s_axis_rq_tlast   ( s_axis_rq_tlast      ) , // output           
  .s_axis_rq_tready  ( s_axis_rq_tready     ) , // input  
  .s_axis_rq_tuser   ( s_axis_rq_tuser      ) , // output [59  : 0]  
  .s_axis_rq_tvalid  ( s_axis_rq_tvalid     ) , // output           
  .rq_tlp_fifo_req   ( rq_tlp_fifo_req      ) , // input
  .rq_tlp_fifo_rd    ( rq_tlp_fifo_rd       ) , // output
  .rq_tlp_fifo_rdata ( rq_tlp_fifo_rdata    ) , // input  [275 : 0]
  .dbg_rqintf_tlp_out_cnt ( dbg_rqintf_tlp_out_cnt )
) ;
/*
logic [255 : 0] m_axis_rc_tdata_sim  ; // input  [255 : 0] 
logic [7   : 0] m_axis_rc_tkeep_sim  ; // input  [7   : 0] 
logic           m_axis_rc_tlast_sim  ; // input            
logic           m_axis_rc_tready_sim ; // output   
logic [74  : 0] m_axis_rc_tuser_sim  ; // input  [74  : 0]         
logic           m_axis_rc_tvalid_sim ; // input  
logic [7:0] hack_cnt;

assign m_axis_rc_tready = m_axis_rc_tready_sim;

assign m_axis_rc_tvalid_sim = m_axis_rc_tvalid;
assign m_axis_rc_tlast_sim = m_axis_rc_tlast;

assign m_axis_rc_tdata_sim = hack_cnt == 'd0 ? 'h00700000840200000 : 'h89000000000000000000000000000048355aa000f;
assign m_axis_rc_tkeep_sim = 'hff;
assign m_axis_rc_tuser_sim = hack_cnt == 'd0 ? 'h100000000 : 'h0ffffffff;

always_ff @(posedge user_clk) begin
    if (user_reset) hack_cnt <= 'd0;
    else if (m_axis_rc_tvalid & m_axis_rc_tready & m_axis_rc_tlast) hack_cnt <= 'd0;
    else if (m_axis_rc_tvalid & m_axis_rc_tready) hack_cnt <= hack_cnt + 'd1;
    else;
end
*/
rc_intf rc_intf_inst(
  .user_clk           ( user_clk             ) , // input    
  .user_reset         ( user_reset           ) , // input 
  
  .m_axis_rc_tdata    ( m_axis_rc_tdata      ) , // input  [255 : 0] 
  .m_axis_rc_tkeep    ( m_axis_rc_tkeep      ) , // input  [7   : 0] 
  .m_axis_rc_tlast    ( m_axis_rc_tlast      ) , // input            
  .m_axis_rc_tready   ( m_axis_rc_tready     ) , // output   
  .m_axis_rc_tuser    ( m_axis_rc_tuser      ) , // input  [74  : 0]         
  .m_axis_rc_tvalid   ( m_axis_rc_tvalid     ) , // input  
  /*
  .m_axis_rc_tdata    ( m_axis_rc_tdata_sim  ) , // input  [255 : 0] 
  .m_axis_rc_tkeep    ( m_axis_rc_tkeep_sim  ) , // input  [7   : 0] 
  .m_axis_rc_tlast    ( m_axis_rc_tlast_sim  ) , // input            
  .m_axis_rc_tready   ( m_axis_rc_tready_sim ) , // output   
  .m_axis_rc_tuser    ( m_axis_rc_tuser_sim  ) , // input  [74  : 0]         
  .m_axis_rc_tvalid   ( m_axis_rc_tvalid_sim ) , // input    
  */
  .tag_buffer_wr      ( tag_buffer_wr        ) , // output          
  .tag_buffer_wdata   ( tag_buffer_wdata     ) , // output [262 : 0]  {tag[3:0], req_completed, func_id[1:0], data[255:0]}
  .dbg_rcintf_vldpkt_cnt ( dbg_rcintf_vldpkt_cnt ) ,
  .dbg_rcintf_pkt_cnt    ( dbg_rcintf_pkt_cnt    ) 
) ;

rc_reorder #(
    .DEBUG_ON ( DEBUG_ON )
)rc_reorder_inst(
  .user_clk           ( user_clk           ) , // input                
  .user_reset         ( user_reset         ) , // input             
  .release_tag        ( release_tag        ) , // output [15 : 0]       
  .tag_buffer_wr      ( tag_buffer_wr      ) , // input             
  .tag_buffer_wdata   ( tag_buffer_wdata   ) , // input  [262 : 0]   {tag[3:0], req_completed, func_id[1:0], data[255:0]} 
  .rc_data_fifo_full  ( rc_data_fifo_full  ) , // input
  .rc_data_fifo_pfull ( rc_data_fifo_pfull ) , // input             
  .rc_data_fifo_wr    ( rc_data_fifo_wr    ) , // output            
  .rc_data_fifo_wdata ( rc_data_fifo_wdata ) , // output [258 : 0]   {eop, func_id[1:0], data[255:0]}
  .dbg_rcreorder_opkt_cnt ( dbg_rcreorder_opkt_cnt ) ,
  .dbg_rcreorder_tag      ( dbg_rcreorder_tag      )  

) ;

rqrc_tlp_proc #(
    .S_AXI_ID_W   ( S_AXI_ID_W   ) , 
    .S_AXI_ADDR_W ( S_AXI_ADDR_W ) ,
    .S_AXI_DATA_W ( S_AXI_DATA_W ) ,
    .S_BASE_ADDR  ( S_BASE_ADDR  ) 
) rqrc_tlp_proc_0 (  
  .user_clk          ( user_clk             ) , // input    
  .user_reset        ( user_reset           ) , // input 
  .s_axi_aclk        ( s_axi_aclk           ) , // Unused
  .s_axi_aresetn     ( s_axi_aresetn        ) , // Unused
  .s_axi_awid        ( s_axi_awid           ) , // wr addr
  .s_axi_awaddr      ( s_axi_awaddr         ) ,
  .s_axi_awlen       ( s_axi_awlen          ) ,
  .s_axi_awsize      ( s_axi_awsize         ) ,
  .s_axi_awburst     ( s_axi_awburst        ) ,
  .s_axi_awregion    ( s_axi_awregion       ) , // Unused
  .s_axi_awlock      ( s_axi_awlock         ) , // Unused
  .s_axi_awcache     ( s_axi_awcache        ) , // Unused
  .s_axi_awprot      ( s_axi_awprot         ) , // Unused
  .s_axi_awqos       ( s_axi_awqos          ) , // Unused
  .s_axi_awvalid     ( s_axi_awvalid        ) ,
  .s_axi_awready     ( s_axi_awready        ) ,
  .s_axi_wdata       ( s_axi_wdata          ) , // wr data
  .s_axi_wstrb       ( s_axi_wstrb          ) ,
  .s_axi_wlast       ( s_axi_wlast          ) ,
  .s_axi_wvalid      ( s_axi_wvalid         ) ,
  .s_axi_wready      ( s_axi_wready         ) ,
  .s_axi_bid         ( s_axi_bid            ) , // wr res
  .s_axi_bresp       ( s_axi_bresp          ) ,
  .s_axi_bvalid      ( s_axi_bvalid         ) ,
  .s_axi_bready      ( s_axi_bready         ) ,
  .s_axi_arid        ( s_axi_arid           ) , // rd addr
  .s_axi_araddr      ( s_axi_araddr         ) ,
  .s_axi_arlen       ( s_axi_arlen          ) ,
  .s_axi_arsize      ( s_axi_arsize         ) ,
  .s_axi_arburst     ( s_axi_arburst        ) ,
  .s_axi_arregion    ( s_axi_arregion       ) , // Unused
  .s_axi_arlock      ( s_axi_arlock         ) , // Unused
  .s_axi_arcache     ( s_axi_arcache        ) , // Unused
  .s_axi_arprot      ( s_axi_arprot         ) , // Unused
  .s_axi_arqos       ( s_axi_arqos          ) , // Unused
  .s_axi_arvalid     ( s_axi_arvalid        ) ,
  .s_axi_arready     ( s_axi_arready        ) ,
  .s_axi_rid         ( s_axi_rid            ) , // rd data
  .s_axi_rdata       ( s_axi_rdata          ) ,
  .s_axi_rresp       ( s_axi_rresp          ) ,
  .s_axi_rlast       ( s_axi_rlast          ) ,
  .s_axi_rvalid      ( s_axi_rvalid         ) ,
  .s_axi_rready      ( s_axi_rready         ) ,
  .release_tag       ( release_tag          ) , // input [15 : 0]
  .rq_tlp_fifo_req   ( rq_tlp_fifo_req      ) , // output
  .rq_tlp_fifo_rd    ( rq_tlp_fifo_rd       ) , // input
  .rq_tlp_fifo_rdata ( rq_tlp_fifo_rdata    ) , // output [275:0]     
  .rc_data_fifo_pfull( rc_data_fifo_pfull   ) , // output
  .rc_data_fifo_wr   ( rc_data_fifo_wr      ) , // input
  .rc_data_fifo_wdata( rc_data_fifo_wdata   ) , // input {eop, func_id[1:0], data[255:0]}   
  .dbg_rq_waxi_aw_cnt          ( dbg_rq_waxi_aw_cnt          ) ,
  .dbg_rq_waxi_w_cnt           ( dbg_rq_waxi_w_cnt           ) ,
  .dbg_rq_raxi_ar_cnt          ( dbg_rq_raxi_ar_cnt          ) ,
  .dbg_rq_raxi_r_cnt           ( dbg_rq_raxi_r_cnt           ) ,
  .dbg_rqtlpgen_rd_wdes_cnt    ( dbg_rqtlpgen_rd_wdes_cnt    ) ,
  .dbg_rqtlpgen_rd_rdes_cnt    ( dbg_rqtlpgen_rd_rdes_cnt    ) ,
  .dbg_rqrctlpproc_tlp_out_cnt ( dbg_rqrctlpproc_tlp_out_cnt ) ,
  .dbg_rqrctlpproc_tlp_status1 ( dbg_rqrctlpproc_tlp_status1 ) ,
  .dbg_rqrctlpproc_tlp_status2 ( dbg_rqrctlpproc_tlp_status2 ) 
    
) ;




endmodule
