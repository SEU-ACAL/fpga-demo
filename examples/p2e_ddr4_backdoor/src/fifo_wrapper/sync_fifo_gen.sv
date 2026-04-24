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

module sync_fifo_gen #(
      parameter         FIFO_MEMORY_TYPE  = "auto"  , // String   "auto", "block", "distributed", "ultra"
      parameter         READ_MODE         = "fwft"  , // String   "std", "fwft"
      parameter integer FIFO_WRITE_DEPTH  = 16      , // DECIMAL  16 ~ 4194304, must be power of two. NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.
      parameter integer DATA_WIDTH        = 32      , // DECIMAL  1 - 4096
      parameter integer PROG_FULL_THRESH  = 10        // DECIMAL  3 - 4194301
) (

    input                       clk       ,
    input                       srst      , // Must be synchronous to wr_clk
    output                      full      ,
    input  [DATA_WIDTH - 1 : 0] din       ,
    input                       wr_en     ,
    output                      empty     ,
    output [DATA_WIDTH - 1 : 0] dout      ,
    input                       rd_en     ,
    output                      prog_full 

) ;

function automatic int log2 (input int n);
    if (n <=1) return 1; // abort function
    log2 = 0;
    while (n > 1) begin
        n = n/2;
        log2++;
    end
endfunction
parameter  CNT_WIDTH    =   log2 (FIFO_WRITE_DEPTH) ;

logic   [CNT_WIDTH:0]   data_cnt  ;
logic   [CNT_WIDTH:0]   data_cnt_delay  ;
logic   [CNT_WIDTH:0]   data_cnt_delay2  ;
logic   [DATA_WIDTH-1:0]  mem [FIFO_WRITE_DEPTH-1:0]  ;
logic   [CNT_WIDTH-1:0]   wr_point  ;
logic   [CNT_WIDTH-1:0]   rd_point  ;
logic   [DATA_WIDTH - 1 : 0] rd_data      ;

always @  (posedge clk or posedge srst)
begin
	if(srst) begin
			data_cnt<='b0   ;
	end	else begin
			if(wr_en&!rd_en&!full)
				data_cnt<=data_cnt+1'b1   ;
			else if(rd_en&!empty&!wr_en)
				data_cnt<=data_cnt-1'b1   ;
			else
				data_cnt<=data_cnt ;	
		end
end

always @  (posedge clk or posedge srst)
begin
	if(srst) begin
			 data_cnt_delay<='b0 ;
	end	else begin
			data_cnt_delay<=data_cnt;
		end
end

always @  (posedge clk or posedge srst)
begin
	if(srst) begin
			 data_cnt_delay2<='b0 ;
	end	else begin
			data_cnt_delay2<=data_cnt_delay;
		end
end





always @  (posedge clk or posedge srst)
begin
	if(srst) begin
			wr_point<='b0   ;
	end	else begin
			if(wr_en)
				wr_point<=wr_point+1'b1   ;
			else
				wr_point<=wr_point ;	
		end
end

always @  (posedge clk or posedge srst)
begin
	if(srst) begin
			rd_point<='b0   ;
	end	else begin
			if(rd_en)
				rd_point<=rd_point+1'b1   ;
			else
				rd_point<=rd_point ;	
		end
end

	
always @ (posedge clk )
if(wr_en) 
   mem[wr_point]<=din ;
	
	
	
	
	






assign dout=mem[rd_point]  ;
	 
assign full = (data_cnt>=FIFO_WRITE_DEPTH)?1:0 ;
assign empty = ((data_cnt==0)|(data_cnt_delay==0)|(data_cnt_delay2==0))?1:0 ;
assign prog_full =(data_cnt>=PROG_FULL_THRESH)?1:0 ;



endmodule













