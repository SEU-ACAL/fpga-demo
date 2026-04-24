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


module dut(s2h_out1,q_out,rstn,clk, dut_done);
    parameter WIDTH1=32;
    output bit [WIDTH1-1:0] s2h_out1;
    input bit clk;
    input rstn;
    output bit [7:0] q_out;
    output dut_done ;

    reg [7:0] dut_done_cnt = 0;
    reg       func1_toggle = 0;
    reg       func1_toggle_dly = 0;



    always@(posedge clk) begin 
        func1_toggle_dly <= func1_toggle ;
    end 

    always@(posedge clk) begin 
        if(rstn == 0) begin 
            dut_done_cnt <= 'd0;
        end else begin 
            if(func1_toggle_dly != func1_toggle) begin 
                dut_done_cnt <= dut_done_cnt + 1 ;
            end 
        end 
    end 
    assign dut_done = dut_done_cnt >= 4;



    import "DPI-C" context function void func_touch (output bit [7:0] s2h_data_out0); // c-code no return value ( if q_out=10 xxx)
    bit [7:0] s2h_data_out0;
    bit reset_byC;
    
    export "DPI-C" function func_get_rtl_value;

    function void func_get_rtl_value(output bit [WIDTH1-1:0] o1, output bit [WIDTH1-1:0] o2);
        o1 = s2h_out1;
        o2 = q_out;
    endfunction

    
    //q_out
    always@(posedge clk ) begin
        if (~rstn  || reset_byC)
           q_out<=0;
        else begin
            if (q_out==255)
               q_out<= 0;
            else q_out<=q_out+1;
          end
     end
     wire [7:0]s2h_data;
     wire [31:0]s2h_out;
     assign s2h_data = s2h_data_out0;

     always  @(posedge clk ) begin
         if(rstn == 0) begin 
         end else begin 
            if (&q_out[2:0])begin
                func_touch(s2h_data_out0); 
                func1_toggle <= ~func1_toggle ;
            end    
        end 
    end

     assign s2h_out = {4{s2h_data_out0[7:0]}};
     assign s2h_out1 = 'd2023;

endmodule
