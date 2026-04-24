`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/03/2023 06:24:32 PM
// Design Name: 
// Module Name: prbs_create
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module prbs_create(
input clk,
input rst,
input [255:0] prbs_mode_seed,
input prbs_en,
output [255:0] prbs_data
    );

reg [256 :1]            lfsr_q;
reg [255 :0]            prbs;

always @ (posedge clk) begin
  if(rst) begin
    lfsr_q <=  prbs_mode_seed;
  end else if(prbs_en) begin
    lfsr_q[256] <=  lfsr_q[256] ^ lfsr_q[255];
    lfsr_q[255] <=  lfsr_q[254];
    lfsr_q[254] <=  lfsr_q[255] ^ lfsr_q[253];
    lfsr_q[253] <=  lfsr_q[256] ^ lfsr_q[252];
    lfsr_q[252:2] <=  lfsr_q[251:1];
    lfsr_q[1] <=  lfsr_q[256];
  end
end
assign prbs_data = prbs;
always @(lfsr_q[256:1]) begin
  prbs = lfsr_q[256:1];
end

endmodule
