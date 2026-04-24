`timescale 1ns/10ps

module axi_reg
(

		 dwdma_start   ,  
		 drdma_start   ,  
		 ddma_saddr    ,  
		 ddma_daddr    ,  
		 ddma_len      ,  


	 	clk,
		rstn,

		// AXI write address channel
		i_awaddr,
		i_awid,
		i_awlen,
		i_awvalid,
		o_awready,

		// AXI write data channel
		i_wdata,
		i_wid,
		i_wstrb,
		i_wlast,
		i_wvalid,
		o_wready,
		o_bresp,
		o_bid,
		o_bvalid,
		i_bready,

		// AXI read address channel
		i_araddr,
		i_arid,
		i_arlen,
		i_arvalid,
		o_arready,

		// AXI read data channel
		o_rdata,
		o_rid,
		o_rresp,
		o_rlast,
		o_rvalid,
		i_rready
);

parameter  AXI_ID_WIDTH   = 4;
parameter  AXI_DATA_WIDTH = 256;
parameter  AXI_ADDR_WIDTH = 15;               //1024 level of 256
parameter  AXI_STRB_WIDTH = AXI_DATA_WIDTH>>3; //write byte strb
parameter  AXI_BYTE_NUM   = 5;  //log2 of AXI_STRB_WIDTH


input           clk;
input           rstn;

// AXI write address channel
input   [AXI_ADDR_WIDTH-1:0]  i_awaddr      ;
input   [AXI_ID_WIDTH-1:0]    i_awid        ;
input   [3:0]                 i_awlen       ;
input                         i_awvalid     ;
output                        o_awready     ;

// AXI write data channel
input   [AXI_DATA_WIDTH-1:0]      i_wdata       ;
input   [AXI_ID_WIDTH-1:0]    i_wid         ;
input   [AXI_STRB_WIDTH-1:0]    i_wstrb       ;
input                         i_wlast       ;
input                         i_wvalid      ;
output                        o_wready      ;
output  [AXI_ID_WIDTH-1:0]    o_bid         ;
output  [1:0]                 o_bresp       ;
output                        o_bvalid      ;
input                         i_bready      ;

// AXI read address channel
input   [AXI_ADDR_WIDTH-1:0]  i_araddr      ;
input   [AXI_ID_WIDTH-1:0]    i_arid        ;
input   [3:0]                 i_arlen       ;
input                         i_arvalid     ;
output                        o_arready     ;

// AXI read data channel
output  [AXI_DATA_WIDTH-1:0]      o_rdata       ;
output  [AXI_ID_WIDTH-1:0]    o_rid         ;
output  [1:0]                 o_rresp       ;
output                        o_rlast       ;
output                        o_rvalid      ;
input                         i_rready      ;



output           dwdma_start  ;
output           drdma_start  ;
output [63  : 0] ddma_saddr   ;
output [63  : 0] ddma_daddr   ;
output [31  : 0] ddma_len     ;







parameter      ST_R_IDLE = 2'd0;
parameter      ST_R_READ = 2'd1;
parameter      ST_R_END  = 2'd2;
parameter      ST_R_WAIT  = 2'd3;

parameter      ST_W_IDLE  = 2'd0;
parameter      ST_W_WRITE = 2'd1;
parameter      ST_W_END   = 2'd2;

reg     [1:0]                  r_cs     ;
reg     [1:0]                  r_ns     ;
reg     [1:0]                  w_cs     ;
reg     [1:0]                  w_ns     ;

reg           dwdma_start  ;
reg           drdma_start  ;
reg [63  : 0] ddma_saddr   ;
reg [63  : 0] ddma_daddr   ;
reg [31  : 0] ddma_len     ;






reg     [3:0]                  rdcnt    ;
wire                           last_rd  ;
reg     [AXI_ADDR_WIDTH-1:0]   araddr   ;
reg     [3:0]                  arlen    ;
reg     [AXI_ID_WIDTH-1:0]     arid     ;

reg     [3:0]                  wdcnt    ;
reg     [AXI_ADDR_WIDTH-1:0]   awaddr   ;
reg     [3:0]                  awlen    ;
reg     [AXI_ID_WIDTH-1:0]     awid     ;

wire    [AXI_DATA_WIDTH-1:0]   o_rdata  ;
wire    [AXI_ADDR_WIDTH-1:0]   rd_addr  ;

wire   [AXI_ADDR_WIDTH-1:0]    rd_addr  ;
wire   [AXI_ID_WIDTH-1:0]      o_rid    ;
wire   [1:0]                   o_rresp  ;
wire                           o_rlast  ;
wire                           o_rvalid ;


assign rd_addr = araddr + (rdcnt<<AXI_BYTE_NUM);
assign last_rd = rdcnt == arlen;

assign o_rresp   = 2'b00;
assign o_rvalid  = (r_cs==ST_R_READ);
assign o_arready  = (r_cs==ST_R_IDLE);
assign o_rlast   = o_rvalid & last_rd;
assign o_rid     = arid;

always@(posedge clk or negedge rstn) begin
	if (!rstn) begin
		r_cs <= ST_R_IDLE;
	end else begin
		r_cs <= r_ns;
	end
end

always@(*) begin

	r_ns = r_cs;

	case (r_cs)
		ST_R_IDLE : r_ns = (i_arvalid & o_arready) ? ST_R_WAIT : r_cs;
		ST_R_WAIT : r_ns = ST_R_READ;
		ST_R_READ : r_ns = (o_rvalid & i_rready & last_rd) ? ST_R_END : r_cs;
		ST_R_END  : r_ns = ST_R_IDLE;
	endcase
end

always@(posedge clk or negedge rstn) begin
	if (!rstn) begin
		rdcnt <= 4'd0;
	end else if (o_rvalid & i_rready) begin
		if (last_rd) begin
			rdcnt <= 4'd0;
		end else begin
			rdcnt <= rdcnt + 1'b1;
		end
	end
end

always@(posedge clk) begin
	if (i_arvalid & o_arready) begin
		araddr <= i_araddr;
                arlen  <= i_arlen ;
		arid   <= i_arid  ;
	end
end


//------------------------------------------------------------------------------------------------

wire    last_wr;
wire    wr_en;
wire [AXI_ADDR_WIDTH-1:0] wr_addr;
wire    o_awready;
assign last_wr = wdcnt == awlen;
assign wr_addr = awaddr + (wdcnt<<AXI_BYTE_NUM);
assign wr_en = i_wvalid && o_wready;

assign o_wready  = (w_cs==ST_W_WRITE);
assign o_awready  = (w_cs==ST_W_IDLE);
assign o_bresp   = 2'b00;
assign o_bid     = awid;
assign o_bvalid  = (w_cs==ST_W_END);


always@(posedge clk or negedge rstn) begin
	if (!rstn) begin
		w_cs <= ST_W_IDLE;
	end else begin
		w_cs <= w_ns;
	end
end

always@(*) begin
	w_ns = w_cs;
	case (w_cs)
		ST_W_IDLE  : w_ns = (i_awvalid & o_awready) ? ST_W_WRITE : w_cs;
		ST_W_WRITE : w_ns = (i_wvalid & o_wready & last_wr) ? ST_W_END : w_cs;
		ST_W_END   : w_ns = (o_bvalid & i_bready) ? ST_W_IDLE : w_cs;
	endcase
end

always@(posedge clk or negedge rstn) begin
	if (!rstn) begin
		wdcnt <=  'd0;
	end else if (i_wvalid & o_wready) begin
		if (last_wr) begin
			wdcnt <=  'd0;
		end else begin
			wdcnt <= wdcnt + 1'b1;
		end
	end
end

always@(posedge clk) begin
	if (i_awvalid & o_awready) begin
		awaddr <= i_awaddr;
                awlen  <= i_awlen;;
		awid   <= i_awid;
	end
end



xilinx_ram_tdp u0_bram_tdp(
    .clka   ( clk    ) , // input
    .rsta   ( 0    ) , // input
    .rstb   ( 0    ) , // input
    .regcea ( 1'b0   ) , // input
    .regceb ( 1'b0   ) , // input
    .ena    ( 1'b1    ) , // input
    .wea    ( i_wstrb&{32{wr_en}}    ) , // input
    .addra  ( wr_addr[AXI_ADDR_WIDTH-1:AXI_BYTE_NUM]  ) , // input
    .dina   ( i_wdata   ) , // input
    .douta  (    ) , // output
    .enb    ( 1'b1    ) , // input
    .web    (      ) , // input
    .addrb  ( rd_addr[AXI_ADDR_WIDTH-1:AXI_BYTE_NUM]  ) , // input
    .dinb   (     ) , // input
    .doutb  ( o_rdata  )   // output
);


always@(posedge clk) begin
	if (wr_en & (wr_addr==0)&i_wdata[0]) 
		dwdma_start<=1'b1 ;
	else
		dwdma_start<=1'b0 ;
end

always@(posedge clk) begin
	if (wr_en & (wr_addr==8'h20)&i_wdata[0]) 
		drdma_start<=1'b1 ;
	else
		drdma_start<=1'b0 ;
end

always@(posedge clk) begin
	if (wr_en & (wr_addr==8'h40)) 
		ddma_saddr[31:0]<=i_wdata[31  : 0] ;
end

always@(posedge clk) begin
	if (wr_en & (wr_addr==8'h60)) 
		ddma_saddr[63:32]<=i_wdata[31  : 0] ;
end

always@(posedge clk) begin
	if (wr_en & (wr_addr==8'h80)) 
		ddma_daddr[31:0]<=i_wdata[31  : 0];
end

always@(posedge clk) begin
	if (wr_en & (wr_addr==8'ha0)) 
		ddma_daddr[63:32]<=i_wdata[31  : 0];
end

always@(posedge clk) begin
	if (wr_en & (wr_addr==8'hc0)) 
		ddma_len<=i_wdata[31  : 0] ;
end



endmodule
