`timescale 1ns/1ps
// Optional: runs the board wrapper at full speed and checks the final jal result.
module tb_boolean;
reg clk = 0;
always #5 clk = ~clk;
reg  [15:0] sw  = 16'hC000;      // run, full speed
reg  [ 3:0] btn = 4'b0001;       // reset held
wire [15:0] led;
integer t = 0;
reg done = 0;

boolean_top dut (.clk(clk), .sw(sw), .btn(btn), .led(led));

initial begin #300 btn[0] = 0; end

always @(negedge clk) begin
    t = t + 1;
    if (!done && dut.pcw == 32'h138) begin
        done = 1;
        if (dut.res === 32'h13C) $display("PASS: jal reached, Result = 0x13C");
        else                     $display("FAIL: jal Result = %h (expected 13C)", dut.res);
        $finish;
    end
    if (t > 200000) begin $display("TIMEOUT: PC never reached 0x138"); $finish; end
end
endmodule
