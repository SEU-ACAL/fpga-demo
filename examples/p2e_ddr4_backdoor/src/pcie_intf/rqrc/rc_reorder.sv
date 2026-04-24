/* Copyright (c) 2020-2022 by XEPIC Co., Ltd.*/
`timescale 1ns/1ps

module rc_reorder #(
    parameter  DEBUG_ON  = "FALSE"  // "FALSE" or "TRUE"
)(
  // clock and reset
  input                  user_clk           , // input    
  input                  user_reset         , // input 
  // Connect to rc_intf
  output logic [15  : 0] release_tag        ,
  input                  tag_buffer_wr      ,
  input        [262 : 0] tag_buffer_wdata   , // {tag[3:0], req_completed, func_id[1:0], data[255:0]}  
  // connect to rqrc_tlp_proc/rc_data_fifo
  input                  rc_data_fifo_full  , // only for debug
  input                  rc_data_fifo_pfull ,
  output                 rc_data_fifo_wr    ,
  output       [258 : 0] rc_data_fifo_wdata , // {eop, func_id[1:0], data[255:0]}
  
  output       [31  : 0] dbg_rcreorder_opkt_cnt ,
  output       [15  : 0] dbg_rcreorder_tag       
      
) ;

localparam RAM_PERFORMANCE = "HIGH_PERFORMANCE";

logic [3  : 0] tag_in       ;
logic          cmpl_in      ;
logic [3  : 0] tag_out      ;
logic          cmpl_out     ;
logic          cmpl_out_dly1;
logic          cmpl_out_dly2;

logic [4  : 0] tag_addra[0:15];
//logic [4  : 0] tag_addrb[0:15];

logic [15 : 0] cmpl_detected;

logic [8  : 0] addra       ;
logic [8  : 0] addrb       ;
logic [8  : 0] addrb_int   ;
logic [8  : 0] addrb_offset;
logic [262: 0] dina        ;
logic          wea         ;
logic          enb         ;
logic          enb_dly1    ;
logic          enb_dly2    ;
logic [262: 0] doutb       ;
logic          dout_vld    ;

logic [3  : 0] sch_cnt ;

assign dina = tag_buffer_wdata;

assign wea = tag_buffer_wr;

assign tag_in = dina[262:259];

assign cmpl_in = dina[258];

// each tag has 1024 bytes buffer. In rq_tlp_gen.sv, cfg_max_req_num is set no more then 1024 bytes.
// tag-0 located in 0    ~ 31
// tag-1 located in 32   ~ 63
// tag-n located in n*32 ~ n*32+31
assign addra = {9{tag_in == 4'd0 }} & (tag_addra[0]  + 9'd0  ) |
               {9{tag_in == 4'd1 }} & (tag_addra[1]  + 9'd32 ) |
               {9{tag_in == 4'd2 }} & (tag_addra[2]  + 9'd64 ) |
               {9{tag_in == 4'd3 }} & (tag_addra[3]  + 9'd96 ) |
               {9{tag_in == 4'd4 }} & (tag_addra[4]  + 9'd128) |
               {9{tag_in == 4'd5 }} & (tag_addra[5]  + 9'd160) |
               {9{tag_in == 4'd6 }} & (tag_addra[6]  + 9'd192) |
               {9{tag_in == 4'd7 }} & (tag_addra[7]  + 9'd224) |
               {9{tag_in == 4'd8 }} & (tag_addra[8]  + 9'd256) |
               {9{tag_in == 4'd9 }} & (tag_addra[9]  + 9'd288) |
               {9{tag_in == 4'd10}} & (tag_addra[10] + 9'd320) |
               {9{tag_in == 4'd11}} & (tag_addra[11] + 9'd352) |
               {9{tag_in == 4'd12}} & (tag_addra[12] + 9'd384) |
               {9{tag_in == 4'd13}} & (tag_addra[13] + 9'd416) |
               {9{tag_in == 4'd14}} & (tag_addra[14] + 9'd448) |
               {9{tag_in == 4'd15}} & (tag_addra[15] + 9'd480) ;             
genvar i;
generate for (i = 0; i < 16; i++) begin
    always_ff @(posedge user_clk) begin
        if (user_reset) tag_addra[i] <= 'd0;
        else if (wea & i == tag_in) tag_addra[i] <= tag_addra[i] + 'd1;
        //else if (dout_vld & i == tag_out & cmpl_out) tag_addra[i] <= 'd0;
        else if (rc_data_fifo_wr & i == tag_out & cmpl_out) tag_addra[i] <= 'd0;
        else;
    end

    always_ff @(posedge user_clk) begin
        if (user_reset) release_tag[i] <= 1'b0;
        //else if (dout_vld & i == tag_out & cmpl_out) release_tag[i] <= 1'b1;
        else if (rc_data_fifo_wr & i == tag_out & cmpl_out) release_tag[i] <= 1'b1;
        else release_tag[i] <= 1'b0;
    end    
    
    always_ff @(posedge user_clk) begin
        if (user_reset) cmpl_detected[i] <= 1'b0;
        else if (wea & cmpl_in & i == tag_in) cmpl_detected[i] <= 1'b1;
        //else if (dout_vld & cmpl_out & i == tag_out) cmpl_detected[i] <= 1'b0;
        else if (rc_data_fifo_wr & cmpl_out & i == tag_out) cmpl_detected[i] <= 1'b0;
        else;
    end       
    
    //assign tag_buffer_busy[i]  = ~(tag_addra[i]  == 'd0);     
end endgenerate

assign tag_out  = doutb[262:259];

assign cmpl_out = doutb[258];

always_ff @(posedge user_clk) begin
    //cmpl_out_dly1 <= cmpl_out & dout_vld;
    cmpl_out_dly1 <= cmpl_out & rc_data_fifo_wr;
    cmpl_out_dly2 <= cmpl_out_dly1;
end

always_ff @(posedge user_clk) begin
    if (user_reset) addrb_int <= 'd0;
    //else if (enb & cmpl_out) addrb_int <= 'd0;
    else if (rc_data_fifo_wr & cmpl_out) addrb_int <= 'd0;
    else if (enb) addrb_int <= addrb_int + 'd1;
    else;
end  

assign addrb_offset = sch_cnt << 5;

// schedule tag buffers.
// tag buffers must be read in fixed order.
always_ff @(posedge user_clk) begin
    if (user_reset) sch_cnt <= 'd0;
    //else if (enb & cmpl_out) sch_cnt <= sch_cnt + 'd1;
    else if (rc_data_fifo_wr & cmpl_out) sch_cnt <= sch_cnt + 'd1;
    else;
end

assign enb = cmpl_detected[sch_cnt] & ~rc_data_fifo_pfull;

assign addrb = addrb_int + addrb_offset;

//  Xilinx Simple Dual Port Single Clock RAM
xilinx_ram_sdp #(
  .RAM_WIDTH       ( 263             ) , // Specify RAM data width
  .RAM_DEPTH       ( 512             ) , // Specify RAM depth (number of entries)
  .RAM_PERFORMANCE ( RAM_PERFORMANCE )   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
) reorder_buffer (
  .addra ( addra      ) ,   // Write address bus, width determined from RAM_DEPTH
  .addrb ( addrb      ) ,   // Read address bus, width determined from RAM_DEPTH
  .dina  ( dina       ) ,   // RAM input data, width determined from RAM_WIDTH
  .clka  ( user_clk   ) ,   // Clock
  .wea   ( wea        ) ,   // Write enable
  .enb   ( enb        ) ,	// Read Enable, for additional power savings, disable when not in use
  .rstb  ( user_reset ) ,   // Output reset (does not affect memory contents)
  .regceb( 1'b1       ) ,   // Output register enable
  .doutb ( doutb      )     // RAM output data, width determined from RAM_WIDTH
);

always_ff @(posedge user_clk) begin
    enb_dly1 <= enb ;
    enb_dly2 <= enb_dly1;
end

generate if (RAM_PERFORMANCE == "LOW_LATENCY") begin
    assign dout_vld = enb_dly1;
end else begin
    assign dout_vld = enb_dly2;
end endgenerate

generate if (RAM_PERFORMANCE == "LOW_LATENCY") begin
    assign rc_data_fifo_wr = dout_vld & ~cmpl_out_dly1;
end else begin
    assign rc_data_fifo_wr = dout_vld & ~cmpl_out_dly1 & ~cmpl_out_dly2;
end endgenerate

assign rc_data_fifo_wdata = doutb[258:0];

// --- for debug --- //
logic [31:0] opkt_cnt;

always_ff @(posedge user_clk) begin
    if (user_reset) opkt_cnt <= 'b0;
    else if (rc_data_fifo_wr & ~rc_data_fifo_full) opkt_cnt <= opkt_cnt + 'b1;
    else;
end

assign dbg_rcreorder_opkt_cnt = opkt_cnt;
assign dbg_rcreorder_tag = release_tag;


logic [3  : 0] tag_out_dly1 ;
logic [3  : 0] tag_out_dly2 ;

always_ff @(posedge user_clk) begin
    tag_out_dly1 <= tag_out ;
    tag_out_dly2 <= tag_out_dly1;
end

logic [7:0] burst_cnt;
logic       burst_err;

always_ff @(posedge user_clk) begin
    if (user_reset) burst_cnt <= 'b0;
    else if (rc_data_fifo_wr & rc_data_fifo_wdata[258]) burst_cnt <= 'b0;
    else if (rc_data_fifo_wr) burst_cnt <= burst_cnt + 'b1;
    else;
end

assign burst_err = rc_data_fifo_wr & rc_data_fifo_wdata[258] & burst_cnt != 'd15; // for fixed length debug

// --- ILA --- //
/*
generate if (DEBUG_ON == "TRUE") begin

(* keep = "true" *) logic           ila_rc_data_fifo_full  ;
(* keep = "true" *) logic           ila_rc_data_fifo_pfull ;
(* keep = "true" *) logic           ila_rc_data_fifo_wr    ;
(* keep = "true" *) logic [255 : 0] ila_rc_data_fifo_wdata ;
(* keep = "true" *) logic           ila_rc_data_fifo_eop   ;

(* keep = "true" *) logic           ila_tag_buffer_wr      ;
(* keep = "true" *) logic [255 : 0] ila_tag_buffer_wdata   ; // {tag[3:0], req_completed, func_id[1:0], data[255:0]}  
(* keep = "true" *) logic [3   : 0] ila_tag_buffer_tag_in  ;
(* keep = "true" *) logic           ila_tag_buffer_cmpl    ;

assign ila_rc_data_fifo_full  = rc_data_fifo_full  ;
assign ila_rc_data_fifo_pfull = rc_data_fifo_pfull ;
assign ila_rc_data_fifo_wr    = rc_data_fifo_wr    ;
assign ila_rc_data_fifo_wdata = rc_data_fifo_wdata[255:0];
assign ila_rc_data_fifo_eop   = rc_data_fifo_wdata[258];

assign ila_tag_buffer_wr     = tag_buffer_wr;
assign ila_tag_buffer_wdata  = tag_buffer_wdata[255:0];
assign ila_tag_buffer_tag_in = tag_buffer_wdata[262:259];
assign ila_tag_buffer_cmpl   = tag_buffer_wdata[258];

ila_rcreorder ila_rcreorder_i(
    .clk     ( user_clk               ) ,                
    .probe0  ( ila_rc_data_fifo_full  ) , // 
    .probe1  ( ila_rc_data_fifo_pfull ) , // 
    .probe2  ( ila_rc_data_fifo_wr    ) , //
    .probe3  ( ila_rc_data_fifo_wdata ) , // 256  
    .probe4  ( ila_rc_data_fifo_eop   ) , // 
    .probe5  ( burst_cnt              ) , // 8
    .probe6  ( burst_err              ) , //  
    .probe7  ( tag_out                ) , // 4
    .probe8  ( ila_tag_buffer_wr      ) , //
    .probe9  ( ila_tag_buffer_wdata   ) , // 256
    .probe10 ( ila_tag_buffer_tag_in  ) , // 4
    .probe11 ( ila_tag_buffer_cmpl    )   //
);

end endgenerate
*/

endmodule // rc_reorder
