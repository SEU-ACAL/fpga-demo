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

module rqrc_intf #(
	parameter integer C_S_AXI_ID_W	   = 1                        , // Slave
	parameter integer C_S_AXI_ADDR_W   = 64                       ,
	parameter integer C_S_AXI_DATA_W   = 256                      ,
	parameter integer C_S_AXI_AWUSER_W = 0                        ,
	parameter integer C_S_AXI_WUSER_W  = 0                        ,
	parameter integer C_S_AXI_ARUSER_W = 0                        ,
	parameter integer C_S_AXI_RUSER_W  = 0                        ,
	parameter integer C_S_AXI_BUSER_W  = 0                        ,
    parameter         C_S_BASE_ADDR	   = {{C_S_AXI_ADDR_W}{1'b0}} 
)(  
  // clock and reset
  input            user_clk                      , // input    
  input            user_reset                    , // input 
  // RQ/RC 
  output [255 : 0] s_axis_rq_tdata               , // output [255 : 0] 
  output [7   : 0] s_axis_rq_tkeep               , // output [7   : 0] 
  output           s_axis_rq_tlast               , // output           
  input            s_axis_rq_tready              , // input  
  output [59  : 0] s_axis_rq_tuser               , // output [59  : 0] 
  output           s_axis_rq_tvalid              , // output           
  input  [255 : 0] m_axis_rc_tdata               , // input  [255 : 0] 
  input  [7   : 0] m_axis_rc_tkeep               , // input  [7   : 0] 
  input            m_axis_rc_tlast               , // input            
  output           m_axis_rc_tready              , // output           
  input  [74  : 0] m_axis_rc_tuser               , // input  [74  : 0] 
  input            m_axis_rc_tvalid              , // input  
  // Interrupt 
  output           wdma_error                    ,
  output           rdma_error                    ,
  // AXI-MM-slave   
  input                           s_axi_aclk     , // Unused
  input                           s_axi_aresetn  , // Unused
  input  [C_S_AXI_ID_W-1     : 0] s_axi_awid     , // wr addr
  input  [C_S_AXI_ADDR_W-1   : 0] s_axi_awaddr   ,
  input  [7                  : 0] s_axi_awlen    ,
  input  [2                  : 0] s_axi_awsize   ,
  input  [1                  : 0] s_axi_awburst  ,
  input  [3                  : 0] s_axi_awregion , // Unused
  input                           s_axi_awlock   , // Unused
  input  [3                  : 0] s_axi_awcache  , // Unused
  input  [2                  : 0] s_axi_awprot   , // Unused
  input  [3                  : 0] s_axi_awqos    , // Unused
  input  [C_S_AXI_AWUSER_W-1 : 0] s_axi_awuser   , 
  input                           s_axi_awvalid  ,
  output                          s_axi_awready  ,
  input  [C_S_AXI_DATA_W-1   : 0] s_axi_wdata    , // wr data
  input  [C_S_AXI_DATA_W/8-1 : 0] s_axi_wstrb    ,
  input                           s_axi_wlast    ,
  input  [C_S_AXI_WUSER_W-1  : 0] s_axi_wuser    ,
  input                           s_axi_wvalid   ,
  output                          s_axi_wready   ,
  output [C_S_AXI_ID_W-1     : 0] s_axi_bid      , // wr res
  output [1                  : 0] s_axi_bresp    ,
  output [C_S_AXI_BUSER_W-1  : 0] s_axi_buser    ,
  output                          s_axi_bvalid   ,
  input                           s_axi_bready   ,
  input  [C_S_AXI_ID_W-1     : 0] s_axi_arid     , // rd addr
  input  [C_S_AXI_ADDR_W-1   : 0] s_axi_araddr   ,
  input  [7                  : 0] s_axi_arlen    ,
  input  [2                  : 0] s_axi_arsize   ,
  input  [1                  : 0] s_axi_arburst  ,
  input  [3                  : 0] s_axi_arregion , // Unused
  input                           s_axi_arlock   , // Unused
  input  [3                  : 0] s_axi_arcache  , // Unused
  input  [2                  : 0] s_axi_arprot   , // Unused
  input  [3                  : 0] s_axi_arqos    , // Unused
  input  [C_S_AXI_ARUSER_W-1 : 0] s_axi_aruser   ,
  input                           s_axi_arvalid  ,
  output                          s_axi_arready  ,
  output [C_S_AXI_ID_W-1     : 0] s_axi_rid      , // rd data
  output [C_S_AXI_DATA_W-1   : 0] s_axi_rdata    ,
  output [1                  : 0] s_axi_rresp    ,
  output                          s_axi_rlast    ,
  output [C_S_AXI_RUSER_W-1  : 0] s_axi_ruser    ,
  output                          s_axi_rvalid   ,
  input                           s_axi_rready   
      
) ;

logic           wdma_des_fifo_empty  ;
logic           wdma_des_fifo_rd     ;
logic [104 : 0] wdma_des_fifo_rdata  ; // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}

logic           wdma_data_fifo_req   ;
logic           wdma_data_fifo_rd    ;
logic [255 : 0] wdma_data_fifo_rdata ;

logic           rdma_des_fifo_empty  ;
logic           rdma_des_fifo_rd     ;
logic [104 : 0] rdma_des_fifo_rdata  ; // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}

logic           rdma_data_fifo_full  ;
logic           rdma_data_fifo_wr    ;
logic [289 : 0] rdma_data_fifo_wdata ; // {sop, eop, data, strobe}


rq_intf rq_intf_inst(
  .user_clk             ( user_clk             ) , // input    
  .user_reset           ( user_reset           ) , // input 
  .s_axis_rq_tdata      ( s_axis_rq_tdata      ) , // output [255 : 0] 
  .s_axis_rq_tkeep      ( s_axis_rq_tkeep      ) , // output [7   : 0] 
  .s_axis_rq_tlast      ( s_axis_rq_tlast      ) , // output           
  .s_axis_rq_tready     ( s_axis_rq_tready     ) , // input   
  .s_axis_rq_tuser      ( s_axis_rq_tuser      ) , // output [59  : 0] 
  .s_axis_rq_tvalid     ( s_axis_rq_tvalid     ) , // output           
  .wdma_des_fifo_empty  ( wdma_des_fifo_empty  ) ,
  .wdma_des_fifo_rd     ( wdma_des_fifo_rd     ) ,
  .wdma_des_fifo_rdata  ( wdma_des_fifo_rdata  ) , // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
  .wdma_data_fifo_req   ( wdma_data_fifo_req   ) ,
  .wdma_data_fifo_rd    ( wdma_data_fifo_rd    ) ,
  .wdma_data_fifo_rdata ( wdma_data_fifo_rdata ) ,
  .rdma_des_fifo_empty  ( rdma_des_fifo_empty  ) ,
  .rdma_des_fifo_rd     ( rdma_des_fifo_rd     ) ,
  .rdma_des_fifo_rdata  ( rdma_des_fifo_rdata  )   // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
) ;


rc_intf rc_intf_inst(
  .user_clk             ( user_clk             ) , // input    
  .user_reset           ( user_reset           ) , // input 
  .m_axis_rc_tdata      ( m_axis_rc_tdata      ) , // input  [255 : 0] 
  .m_axis_rc_tkeep      ( m_axis_rc_tkeep      ) , // input  [7   : 0] 
  .m_axis_rc_tlast      ( m_axis_rc_tlast      ) , // input            
  .m_axis_rc_tready     ( m_axis_rc_tready     ) , // output           
  .m_axis_rc_tuser      ( m_axis_rc_tuser      ) , // input  [74  : 0] 
  .m_axis_rc_tvalid     ( m_axis_rc_tvalid     ) , // input     
  .rdma_data_fifo_full  ( rdma_data_fifo_full  ) ,
  .rdma_data_fifo_wr    ( rdma_data_fifo_wr    ) ,
  .rdma_data_fifo_wdata ( rdma_data_fifo_wdata ) , // {sop, eop, data, strobe}   
  .wdma_error           ( wdma_error           ) , // output 
  .rdma_error           ( rdma_error           )   // output

) ;


rqrc_tlp_proc #(
	.C_S_AXI_ID_W	  ( C_S_AXI_ID_W	 ) , 
	.C_S_AXI_ADDR_W   ( C_S_AXI_ADDR_W   ) ,
	.C_S_AXI_DATA_W   ( C_S_AXI_DATA_W   ) ,
	.C_S_AXI_AWUSER_W ( C_S_AXI_AWUSER_W ) ,
	.C_S_AXI_WUSER_W  ( C_S_AXI_WUSER_W  ) ,
	.C_S_AXI_ARUSER_W ( C_S_AXI_ARUSER_W ) ,
	.C_S_AXI_RUSER_W  ( C_S_AXI_RUSER_W  ) ,
	.C_S_AXI_BUSER_W  ( C_S_AXI_BUSER_W  ) ,
    .C_S_BASE_ADDR	  ( C_S_BASE_ADDR	 ) 
) rqrc_tlp_proc_dma_channel (  
  .user_clk             ( user_clk             ) , // input    
  .user_reset           ( user_reset           ) , // input 
  .wdma_des_fifo_empty  ( wdma_des_fifo_empty  ) , // write DMA channel descriptor FIFO
  .wdma_des_fifo_rd     ( wdma_des_fifo_rd     ) ,
  .wdma_des_fifo_rdata  ( wdma_des_fifo_rdata  ) , // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
  .wdma_data_fifo_req   ( wdma_data_fifo_req   ) , // write DMA channel data FIFO
  .wdma_data_fifo_rd    ( wdma_data_fifo_rd    ) ,
  .wdma_data_fifo_rdata ( wdma_data_fifo_rdata ) ,
  .rdma_des_fifo_empty  ( rdma_des_fifo_empty  ) , // read DMA channel descriptor FIFO
  .rdma_des_fifo_rd     ( rdma_des_fifo_rd     ) ,
  .rdma_des_fifo_rdata  ( rdma_des_fifo_rdata  ) , // {addr[63:2], DW_cnt[10:0], Req_id[15:0], Cmpl_id[15:0]}
  .rdma_data_fifo_full  ( rdma_data_fifo_full  ) ,
  .rdma_data_fifo_wr    ( rdma_data_fifo_wr    ) ,
  .rdma_data_fifo_wdata ( rdma_data_fifo_wdata ) , // {sop, eop, data, strobe}
  .s_axi_aclk           ( s_axi_aclk           ) , // Unused
  .s_axi_aresetn        ( s_axi_aresetn        ) , // Unused
  .s_axi_awid           ( s_axi_awid           ) , // wr addr
  .s_axi_awaddr         ( s_axi_awaddr         ) ,
  .s_axi_awlen          ( s_axi_awlen          ) ,
  .s_axi_awsize         ( s_axi_awsize         ) ,
  .s_axi_awburst        ( s_axi_awburst        ) ,
  .s_axi_awregion       ( s_axi_awregion       ) , // Unused
  .s_axi_awlock         ( s_axi_awlock         ) , // Unused
  .s_axi_awcache        ( s_axi_awcache        ) , // Unused
  .s_axi_awprot         ( s_axi_awprot         ) , // Unused
  .s_axi_awqos          ( s_axi_awqos          ) , // Unused
  .s_axi_awuser         ( s_axi_awuser         ) , 
  .s_axi_awvalid        ( s_axi_awvalid        ) ,
  .s_axi_awready        ( s_axi_awready        ) ,
  .s_axi_wdata          ( s_axi_wdata          ) , // wr data
  .s_axi_wstrb          ( s_axi_wstrb          ) ,
  .s_axi_wlast          ( s_axi_wlast          ) ,
  .s_axi_wuser          ( s_axi_wuser          ) ,
  .s_axi_wvalid         ( s_axi_wvalid         ) ,
  .s_axi_wready         ( s_axi_wready         ) ,
  .s_axi_bid            ( s_axi_bid            ) , // wr res
  .s_axi_bresp          ( s_axi_bresp          ) ,
  .s_axi_buser          ( s_axi_buser          ) ,
  .s_axi_bvalid         ( s_axi_bvalid         ) ,
  .s_axi_bready         ( s_axi_bready         ) ,
  .s_axi_arid           ( s_axi_arid           ) , // rd addr
  .s_axi_araddr         ( s_axi_araddr         ) ,
  .s_axi_arlen          ( s_axi_arlen          ) ,
  .s_axi_arsize         ( s_axi_arsize         ) ,
  .s_axi_arburst        ( s_axi_arburst        ) ,
  .s_axi_arregion       ( s_axi_arregion       ) , // Unused
  .s_axi_arlock         ( s_axi_arlock         ) , // Unused
  .s_axi_arcache        ( s_axi_arcache        ) , // Unused
  .s_axi_arprot         ( s_axi_arprot         ) , // Unused
  .s_axi_arqos          ( s_axi_arqos          ) , // Unused
  .s_axi_aruser         ( s_axi_aruser         ) ,
  .s_axi_arvalid        ( s_axi_arvalid        ) ,
  .s_axi_arready        ( s_axi_arready        ) ,
  .s_axi_rid            ( s_axi_rid            ) , // rd data
  .s_axi_rdata          ( s_axi_rdata          ) ,
  .s_axi_rresp          ( s_axi_rresp          ) ,
  .s_axi_rlast          ( s_axi_rlast          ) ,
  .s_axi_ruser          ( s_axi_ruser          ) ,
  .s_axi_rvalid         ( s_axi_rvalid         ) ,
  .s_axi_rready         ( s_axi_rready         )            
      
) ;




endmodule
