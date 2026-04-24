module dut_top(clk );
    input bit clk;
    reg arstn = 1;
    reg [3:0] arstn_cnt = 0;
    always@(posedge clk) begin 
        if(arstn_cnt == 4'hf) begin 
            arstn_cnt <= 4'hf;
            arstn <= 'd1;
        end else begin 
            arstn_cnt <= arstn_cnt + 1;
            arstn <= 'd0;
        end 
    end 

    parameter  CYCLE_RESET_START = 16 ;
    parameter  CYCLE_RESET_END   = CYCLE_RESET_START +8 ;


    reg dut_rstn = 0 ;
    reg [15:0] cycle_cnt = 'd0 ;

    wire dut_done ;
    reg  dut_done_reg ;

    
    assign flag_done = dut_done_reg ; 
 reg d_flag_done = 0; 
 wire ris_flag_done; 
 always@(posedge clk) 
     d_flag_done<= flag_done; 
 
 assign ris_flag_done = ~d_flag_done & flag_done; 


    always@(posedge clk) begin 
        if(arstn == 0) begin 
            dut_done_reg <= 'd0;
        end else begin 
            if(dut_done == 1) dut_done_reg <= 'd1;
        end
    end 
    import "DPI-C" context function void dut_notice (input bit [31:0] h2s_data);  
    // dut_notice used to info SW //

    always@(posedge clk) begin 
        if(arstn == 0) begin 
            dut_rstn <= 0;
            cycle_cnt <= 0;
        end else begin 
            if(cycle_cnt == CYCLE_RESET_START  ) begin 
                dut_rstn <= 0;
            end if(cycle_cnt == CYCLE_RESET_END  ) begin 
                dut_rstn <= 1;
            end if(dut_done == 1  ) begin 
                dut_rstn <= 0;
            end 
            
            if(cycle_cnt == 16'hffff) begin 
                cycle_cnt <= cycle_cnt ;
            end else begin 
                cycle_cnt <= cycle_cnt  + 1;
            end
        end 

        if(ris_flag_done) begin 
            dut_notice(cycle_cnt);
        end 
    end 


    dut u_dut (
        .clk (clk) ,
        .rstn (dut_rstn),
        .dut_done (dut_done)
    );
endmodule

