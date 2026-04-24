// 1 set bold ;2 set half-brighe;   4 set underscore   5 set blinking 
// 30 set black , 31 set red , 32 set green , 33 set brown, 34 set blue, 35 set magenta, 36 set cyan 
`define DISPLAY_GREEN             $write("%c[1;32m",27);
`define DISPLAY_RED               $write("%c[1;31m",27);
`define DISPLAY_BLUE              $write("%c[1;34m",27);
`define DISPLAY_BROWN             $write("%c[1;33m",27);
`define DISPLAY_CLEAR             $write("%c[0m",27);
`define DISPLAY_BLINKING_GREEN    $write("%c[5;32m",27);
`define DISPLAY_BLINKING_RED      $write("%c[5;31m",27);
`define DISPLAY_BLINKING_BLUE     $write("%c[5;34m",27);
`define DISPLAY_BLINKING_BROWN    $write("%c[5;33m",27);


module vcs_tb ();
    import "DPI-C" context task init_ctb();
    export "DPI-C" task waitNCycles;

    reg uck = 0;
    reg rstn = 0;
    reg [31:0] uck_cnt = 0;
    always begin
        #5 uck = ~uck;
    end
    always@(posedge uck) begin 
        uck_cnt <= uck_cnt + 1;
     ///`DISPLAY_GREEN $display("%t, uck toggle %d", $time, uck_cnt); `DISPLAY_CLEAR
    end 

    task waitNCycles(int n);
        repeat (n) @(posedge uck);
     ///`DISPLAY_GREEN $display("%t, run %d cycles", $time, n); `DISPLAY_CLEAR
    endtask
     
`ifdef VVAC_RTL_SIM 
    vvac_top vvac_top(
        .clk (uck )//,
        //.arstn (rstn)
    );
`else 
    dut_top dut_top(
        .clk (uck )//,
        //.arstn (rstn)
    );
`endif 
    
    
    initial begin 
        uck = 0;
        rstn = 0 ;
        `DISPLAY_GREEN $display("%t, rstn %d", $time,rstn); `DISPLAY_CLEAR
        repeat (10) @(posedge uck);
        rstn = 1 ;
        `DISPLAY_GREEN $display("%t, rstn %d", $time,rstn); `DISPLAY_CLEAR
        repeat (1000) @(posedge uck);
        #1 $stop ;
    end 
  
    initial begin 
        #10ns;
        @(posedge rstn);
        `DISPLAY_GREEN $display("%t, before call init_ctb", $time); `DISPLAY_CLEAR
        init_ctb();
        $stop;
    end 
  
      

endmodule 
