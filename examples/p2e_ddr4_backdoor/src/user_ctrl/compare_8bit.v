module compare_8bit(
input clk,
input rst,
input wstrb,
input [7:0] data_a,
input [7:0] data_b,
input data_en,
output diff
    );
assign diff = result;

reg  result;

always @ (posedge clk) begin
  if(rst) begin
    result <=  0;
  end 
  else if(data_en & wstrb) begin
    if(data_a != data_b)begin
        result <= 1;
    end
    else begin
        result <= 0;
    end
  end
  else begin
     result <= 0;
  end
end

endmodule