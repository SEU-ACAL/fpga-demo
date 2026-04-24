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

`timescale 1ns/1ps

module pcie3_intr_intf (
 
  input            user_clk                 ,
  input            user_reset               ,

  input  [31  : 0] user_interrupt_req       , // Input            From DMA Engine.
  input            pcie_err_fatal           , //                  From PCIe core
  output [31  : 0] cfg_interrupt_msi_int    , // output [31  : 0] 
  input  [3   : 0] cfg_interrupt_msi_enable , // input            High means MSI interrupt enabled
  input            cfg_interrupt_msi_sent   , // input           
  input            cfg_interrupt_msi_fail     // input     
  
) ;





reg [31:0] r_cfg_interrupt_msi_int ;

always @(posedge user_clk)
	if (user_reset) begin
		r_cfg_interrupt_msi_int <= 32'h0;
    end else begin
		if ( user_interrupt_req ) begin
			r_cfg_interrupt_msi_int <= 32'h1;
		end else begin
			r_cfg_interrupt_msi_int <= 32'h0;
		end
    end
assign  cfg_interrupt_msi_int= r_cfg_interrupt_msi_int  ;








endmodule 

