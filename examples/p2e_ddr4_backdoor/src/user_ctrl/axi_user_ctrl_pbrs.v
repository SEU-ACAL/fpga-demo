`timescale 1ns / 1ps


module axi_user_ctrl_pbrs#(
    	parameter  C_M_TARGET_SLAVE_BASE_ADDR	= 32'h00000000,
		parameter integer C_M_AXI_BURST_LEN	    = 63,
		parameter integer C_M_AXI_ID_WIDTH	    = 11,
		parameter integer C_M_AXI_ADDR_WIDTH	= 64,
		parameter integer C_M_AXI_DATA_WIDTH	= 256,
		parameter integer C_M_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M_AXI_BUSER_WIDTH	= 0 
)(
        input  wire                                  M_AXI_ACLK      ,
		input  wire                                  M_AXI_ARESETN   ,

		output wire [C_M_AXI_ID_WIDTH-1 : 0]        M_AXI_AWID      ,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0]      M_AXI_AWADDR    ,
		output wire [7 : 0]                         M_AXI_AWLEN     ,
		output wire [2 : 0]                         M_AXI_AWSIZE    ,
		output wire [1 : 0]                         M_AXI_AWBURST   ,
		output wire                                 M_AXI_AWLOCK    ,
		output wire [3 : 0]                         M_AXI_AWCACHE   ,
		output wire [2 : 0]                         M_AXI_AWPROT    ,
		output wire [3 : 0]                         M_AXI_AWQOS     ,
		output wire [C_M_AXI_AWUSER_WIDTH-1 : 0]    M_AXI_AWUSER    ,
		output wire                                 M_AXI_AWVALID   ,
		input  wire                                  M_AXI_AWREADY   ,

		output wire [C_M_AXI_DATA_WIDTH-1 : 0]      M_AXI_WDATA     ,
		output wire [C_M_AXI_DATA_WIDTH/8-1 : 0]    M_AXI_WSTRB     ,
		output wire                                 M_AXI_WLAST     ,
		output wire [C_M_AXI_WUSER_WIDTH-1 : 0]     M_AXI_WUSER     ,
		output wire                                 M_AXI_WVALID    ,
		input  wire                                  M_AXI_WREADY    ,

		input  wire [C_M_AXI_ID_WIDTH-1 : 0]         M_AXI_BID       ,
		input  wire [1 : 0]                          M_AXI_BRESP     ,
		input  wire [C_M_AXI_BUSER_WIDTH-1 : 0]      M_AXI_BUSER     ,
		input  wire                                  M_AXI_BVALID    ,
		output wire                                 M_AXI_BREADY    ,

		output wire [C_M_AXI_ID_WIDTH-1 : 0]        M_AXI_ARID      ,
		output wire [C_M_AXI_ADDR_WIDTH-1 : 0]      M_AXI_ARADDR    ,
		output wire [7 : 0]                         M_AXI_ARLEN     ,
		output wire [2 : 0]                         M_AXI_ARSIZE    ,
		output wire [1 : 0]                         M_AXI_ARBURST   ,
		output wire                                 M_AXI_ARLOCK    ,
		output wire [3 : 0]                         M_AXI_ARCACHE   ,
		output wire [2 : 0]                         M_AXI_ARPROT    ,
		output wire [3 : 0]                         M_AXI_ARQOS     ,
		output wire [C_M_AXI_ARUSER_WIDTH-1 : 0]    M_AXI_ARUSER    ,
		output wire                                 M_AXI_ARVALID   ,
		input  wire                                  M_AXI_ARREADY   ,

		input  wire [C_M_AXI_ID_WIDTH-1 : 0]         M_AXI_RID       ,
		input  wire [C_M_AXI_DATA_WIDTH-1 : 0]       M_AXI_RDATA     ,
		input  wire [1 : 0]                          M_AXI_RRESP     ,
		input  wire                                  M_AXI_RLAST     ,
		input  wire [C_M_AXI_RUSER_WIDTH-1 : 0]      M_AXI_RUSER     ,
		input  wire                                  M_AXI_RVALID    ,
		output wire                                 M_AXI_RREADY     ,
		input wire c0_init_calib_complete,
		input wire test_start,
        input wire test_start_read,
        input [33:0] user_write_addr,
        input [7:0] user_burst_len,
        input [31:0] user_burst_num,
        input [31:0] user_wstrb,
        output [31:0] w_check_cnt,
        output [31:0] w_check_err_cnt,
        output wire top_sig,
        output check_err,
        output reg [39:0] write_axi_clk_cnt,
        output reg [39:0] read_axi_clk_cnt,
        output reg [39:0] write_time_clk_cnt,
        output reg [39:0] read_time_clk_cnt
        
);
reg [31:0] r_check_err_cnt;
reg r_check_err ;
assign top_sig = r_read_end ;
assign check_err = r_check_err;
assign w_check_cnt = r_check_cnt;
assign w_check_err_cnt = r_check_err_cnt;

wire [7:0] C_M_AXI_BURST_LEN_tmp;
//assign C_M_AXI_BURST_LEN_tmp =C_M_AXI_BURST_LEN;
assign C_M_AXI_BURST_LEN_tmp = user_burst_len - 1;

function integer clogb2(input integer number);
begin
    for(clogb2 = 0 ; number > 0 ; clogb2 = clogb2 + 1 )
        number = number >> 1;
    end
endfunction
parameter DATA_LEN = 100;
parameter DATA_ADDR = 100;
parameter   P_ST_IDLE        = 'd0 ,

            P_ST_WRITE_START = 'd1 ,
            P_ST_WRITE_TRANS = 'd2 ,
            P_ST_WRITE_END   = 'd3 ,

            P_ST_READ_START  = 'd4 ,
            P_ST_READ_TRANS  = 'd5 ,
            P_ST_READ_END    = 'd6 ,
            P_ST_READ_WAIT    = 'd7 ;

reg [7:0]  r_st_current_write    ;
reg [7:0]  r_st_next_write       ;

reg [7:0]  r_st_current_read     ;
reg [7:0]  r_st_next_read        ;

reg  [C_M_AXI_ADDR_WIDTH - 1 : 0] r_m_axi_awaddr        ;
reg                               r_m_axi_awvalid       ;
reg  [C_M_AXI_DATA_WIDTH - 1 : 0] r_m_axi_wdata         ;
reg                               r_m_axi_wlast         ;
reg                               r_m_axi_wvalid        ;
reg  [C_M_AXI_ADDR_WIDTH - 1 : 0] r_m_axi_araddr        ;
reg                               r_m_axi_arvalid       ;
reg                               r_m_axi_rready        ;
reg                               r_write_start         ;
reg                               r_read_start          ;
reg [7:0]                         r_burst_cnt           ;
reg [C_M_AXI_DATA_WIDTH - 1 : 0]  r_axi_read_data       ;

wire   w_system_rst                                     ;
wire   w_write_last                                     ;


assign M_AXI_AWID    = 'd0                              ;
assign M_AXI_AWLEN   =  C_M_AXI_BURST_LEN_tmp               ;
//assign M_AXI_AWSIZE  =  clogb2(C_M_AXI_DATA_WIDTH/8 -1) ;
assign M_AXI_AWSIZE  =  5 ;
assign M_AXI_AWBURST =  2'b01                           ;
assign M_AXI_AWLOCK  =  'd0                             ;
assign M_AXI_AWCACHE =  4'b0000                         ;
assign M_AXI_AWPROT  =  'd0                             ;
assign M_AXI_AWQOS   =  'd0                             ;
assign M_AXI_AWUSER  =    0                          ;
assign M_AXI_AWADDR  = r_m_axi_awaddr ;
assign M_AXI_AWVALID = r_m_axi_awvalid                  ;

assign M_AXI_WSTRB   = user_wstrb      ;


wire [255:0] prbs_data_write;
wire prbs_en_write;
reg [2:0] r_write_state;
//reg r_write_start;
reg [15:0]r_write_cnt;
reg r_write_end;
reg [2:0] r_read_state;
//reg r_write_start;
reg [15:0]r_read_cnt;
reg r_read_end;

assign M_AXI_WDATA   = prbs_data_write;
assign M_AXI_WUSER   = 'd0                              ;

//assign M_AXI_WDATA   = 0;

assign M_AXI_WLAST   = ((r_write_cnt == C_M_AXI_BURST_LEN_tmp) && M_AXI_WVALID && M_AXI_WREADY) ? 1 : 0 ; 

assign M_AXI_WVALID  = r_m_axi_wvalid                   ;

assign M_AXI_BREADY  = 1'b1                             ; 

assign M_AXI_ARID    = 'd0                              ;

assign M_AXI_ARADDR  = r_m_axi_araddr;

assign M_AXI_ARLEN   = C_M_AXI_BURST_LEN_tmp                ;


//assign M_AXI_ARSIZE  = clogb2(C_M_AXI_DATA_WIDTH/8 -1)  ;
assign M_AXI_ARSIZE  = 5  ;
assign M_AXI_ARBURST = 2'b01                            ;
assign M_AXI_ARLOCK  = 'd0                              ;
assign M_AXI_ARCACHE = 4'b0010                          ;
assign M_AXI_ARPROT  = 'd0                              ;
assign M_AXI_ARQOS   = 'd0                              ;
assign M_AXI_ARUSER  = 'd0                              ;
assign M_AXI_ARVALID = r_m_axi_arvalid                  ;


assign M_AXI_RREADY  = r_m_axi_rready                   ;

assign w_system_rst  = ~M_AXI_ARESETN                   ;
assign w_write_last  = M_AXI_WVALID && M_AXI_WREADY     ;

reg [31:0] write_burst_cnt;
reg  [C_M_AXI_ADDR_WIDTH - 1 : 0] r_m_axi_awaddr_tmp        ;
reg write_valid;
always@(posedge M_AXI_ACLK)begin
    if(w_system_rst) begin
        r_write_state <= 3'd0;
        r_write_cnt <= 16'd0;
        r_m_axi_awvalid <= 0;
        r_m_axi_awaddr <= 0;
        r_m_axi_wvalid <= 0;
        r_write_end <= 0;
        r_m_axi_wdata <= 0;
        write_burst_cnt <= 32'd0;
        r_m_axi_awaddr_tmp <= user_write_addr;
        write_valid <= 0;
    end
    else begin
        case(r_write_state)
        3'd0:begin
            r_m_axi_wvalid <= 0; 
            r_m_axi_awvalid <= 0;
            r_write_end <= 0;
            if(c0_init_calib_complete && test_start)begin
                r_write_state <= 3'd1;
                 
            end
            else begin
                r_write_state <= r_write_state;
            end
        end
        3'd1:begin
            write_valid <= 1;
            if(M_AXI_AWREADY)begin
                r_m_axi_awvalid <= 1;
                r_m_axi_awaddr <= r_m_axi_awaddr_tmp;
                r_write_state <= 3'd2;
            end
            else begin
                r_write_state <= r_write_state;
            end
        end
        3'd2:begin
            r_m_axi_awvalid <= 0;
            r_m_axi_wvalid <= 1;
            if(M_AXI_WREADY && r_m_axi_wvalid)begin
                r_write_cnt <= r_write_cnt + 1;
                r_m_axi_wdata <= r_write_cnt;
                if(r_write_cnt == C_M_AXI_BURST_LEN_tmp-1)begin
                    r_write_state <= 3'd3;
                end
                else begin
                    r_write_state <= r_write_state;
                end
            end
        end
        3'd3:begin
            if(M_AXI_WREADY)begin
                r_write_cnt <= r_write_cnt + 1;
                r_m_axi_wvalid <= 0;
                r_write_state <= 3'd4;
            end
            else begin
                r_m_axi_wvalid <= 1;
                r_write_state <= r_write_state;
            end
        end
        3'd4:begin
            r_write_cnt <= 0;
            if(M_AXI_BVALID)begin
                r_write_state <= 3'd5;
            end
            else begin
                r_write_state <= r_write_state;
            end
        end
        3'd5:begin
            r_write_state <= 3'd6;
            write_burst_cnt <= write_burst_cnt + 1;
        end
        3'd6:begin
            
            if(write_burst_cnt == user_burst_num)begin
                r_write_state <= 3'd7;
                r_write_end <= 1;
            end
            else begin
                r_write_state <= 1;
                r_m_axi_awaddr_tmp <= r_m_axi_awaddr_tmp + {user_burst_len,5'd0};
            end
        end
        3'd7:begin
            write_valid <= 0;
            r_write_state <= r_write_state;
            r_write_end <= 1;
        end
        endcase
    end
end

reg [31:0] read_burst_cnt;
reg  [C_M_AXI_ADDR_WIDTH - 1 : 0] r_m_axi_araddr_tmp        ;
reg read_valid;
always@(posedge M_AXI_ACLK)begin
    if(w_system_rst) begin
        r_read_state <= 3'd0;
        r_read_cnt <= 16'd0;
        r_m_axi_arvalid <= 0;
        r_m_axi_araddr <= 0;
        r_m_axi_rready <= 0;
        r_read_end <= 0;
        r_m_axi_araddr_tmp <= user_write_addr;
        read_burst_cnt <= 0;
        read_valid <= 0;
    end
    else begin
        case(r_read_state)
        3'd0:begin
            r_m_axi_rready <= 0; 
            r_m_axi_arvalid <= 0;
            r_read_end <= 0;
            read_valid <= 0;
            if(test_start_read)begin
                r_read_state <= 3'd1;
            end
            else begin
                r_read_state <= r_read_state;
            end
        end
        3'd1:begin
            read_valid <= 1;
            if(M_AXI_ARREADY)begin
                r_m_axi_arvalid <= 1;
                r_m_axi_araddr <= r_m_axi_araddr_tmp;
                r_read_state <= 3'd2;
            end
            else begin
                r_read_state <= r_read_state;
            end
        end
        3'd2:begin
            r_m_axi_arvalid <= 0;
            r_m_axi_rready <= 1;
            if(M_AXI_RVALID && r_m_axi_rready)begin
                r_read_cnt <= r_read_cnt + 1;
                if(r_read_cnt == C_M_AXI_BURST_LEN_tmp-1)begin
                    r_read_state <= 3'd3;
                end
                else begin
                    r_read_state <= r_read_state;
                end
            end
        end
        3'd3:begin
            if(M_AXI_RVALID && M_AXI_RLAST)begin
                r_read_cnt <= r_read_cnt + 1;
                r_m_axi_rready <= 0;
                r_read_state <= 3'd4;
                read_burst_cnt <= read_burst_cnt + 1;
            end
            else begin
                r_m_axi_rready <= 1;
                r_read_state <= r_read_state;
            end
        end
        3'd4:begin
            r_read_cnt <= 0;
            if(read_burst_cnt == user_burst_num)begin
                r_read_state <= 3'd5;
            end
            else begin
                r_read_state <= 3'd0;
                r_m_axi_araddr_tmp <= r_m_axi_araddr_tmp + {user_burst_len,5'd0};
            end
        end
        3'd5:begin
            read_valid <= 0;
            r_read_end <= 1;
            r_read_state <= r_read_state;
        end
        endcase
    end
end



always@(posedge M_AXI_ACLK)begin
    if(w_system_rst) begin
        write_axi_clk_cnt <= 0;
    end
    else begin
        if( M_AXI_WREADY && M_AXI_WVALID) begin
            write_axi_clk_cnt <= write_axi_clk_cnt + 1;
        end
        else begin
            write_axi_clk_cnt <= write_axi_clk_cnt;
        end
    end
end
always@(posedge M_AXI_ACLK)begin
    if(w_system_rst) begin
        read_axi_clk_cnt <= 0;
    end
    else begin
        if(M_AXI_RREADY && M_AXI_RVALID) begin
            read_axi_clk_cnt <= read_axi_clk_cnt + 1;
        end
        else begin
            read_axi_clk_cnt <= read_axi_clk_cnt;
        end
    end
end



always@(posedge M_AXI_ACLK)begin
    if(w_system_rst) begin
        read_time_clk_cnt <= 0;
    end
    else begin
        if(read_valid) begin
            read_time_clk_cnt <= read_time_clk_cnt + 1;
        end
        else begin
            read_time_clk_cnt <= read_time_clk_cnt;
        end
    end
end

always@(posedge M_AXI_ACLK)begin
    if(w_system_rst) begin
        write_time_clk_cnt <= 0;
    end
    else begin
        if(write_valid) begin
            write_time_clk_cnt <= write_time_clk_cnt + 1;
        end
        else begin
            write_time_clk_cnt <= write_time_clk_cnt;
        end
    end
end




wire [255:0] prbs_compare_data = prbs_data_read;
wire [31:0] w_check_diff;
wire data_en;

assign data_en = M_AXI_RREADY & M_AXI_RVALID;
genvar i;
generate
    for(i = 0;i<32;i=i+1)begin
        
        compare_8bit compare_8bit_inst(
            .clk(M_AXI_ACLK),
            .rst(w_system_rst),
            .wstrb(user_wstrb[i]),
            .data_a(M_AXI_RDATA[8*i+:8]),
            .data_b(prbs_compare_data[8*i+:8]),
            .data_en(data_en),
            .diff(w_check_diff[i])
        );
        
    end
endgenerate

reg data_en_d1;

always@(posedge M_AXI_ACLK)begin
    data_en_d1 <= data_en;
end


reg [31:0] r_check_cnt;
always@(posedge M_AXI_ACLK)begin
    if(w_system_rst) begin
        r_check_err_cnt <= 0;
        r_check_err <= 0;
        r_check_cnt <= 32'd0;
    end
    else begin
        if(data_en_d1)begin
            if(w_check_diff != 32'd0) begin
                r_check_err_cnt <= r_check_err_cnt +1;
                r_check_err <= 1;
            end
            else begin
                r_check_err_cnt <= r_check_err_cnt;
                r_check_err <= r_check_err;
            end
            r_check_cnt <= r_check_cnt + 1;
        end
        else begin
            r_check_err_cnt <= r_check_err_cnt;
            r_check_err <= r_check_err;
            r_check_cnt <= r_check_cnt;
        end
    end
end


assign prbs_en_write = M_AXI_WVALID & M_AXI_WREADY;
prbs_create prbs_create_write
(
.clk(M_AXI_ACLK),
.rst(w_system_rst),
.prbs_mode_seed(256'h1234_5678_abcd_a5a5_1111_2222_3333_4343_5555_6666_7777_8888_9999_aaaa_bbbb_cccc),
.prbs_en(prbs_en_write),
.prbs_data(prbs_data_write)
);
wire [255:0] prbs_data_read;
wire prbs_en_read;
assign prbs_en_read = M_AXI_RREADY & M_AXI_RVALID;
prbs_create prbs_create_read
(
.clk(M_AXI_ACLK),
.rst(w_system_rst),
.prbs_mode_seed(256'h1234_5678_abcd_a5a5_1111_2222_3333_4343_5555_6666_7777_8888_9999_aaaa_bbbb_cccc),
.prbs_en(prbs_en_read),
.prbs_data(prbs_data_read)
);

endmodule
