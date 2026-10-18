`timescale 1ns/1ns
// pipeline register -> fetch | decode
// PC is carried as PW bits (instruction memory is 2 KB, so PC[10:0] is all that exists)

module pl_reg_fd #(parameter PW = 11) (
    input               clk, stall, clr,
    input      [31:0]   InstrF,
    input      [PW-1:0] PCF,
    output reg [31:0]   InstrD,
    output reg [PW-1:0] PCD,
    output reg          ValidD        // 0 = bubble, 1 = real fetched instruction
);

initial begin
    InstrD = 0; PCD = 0; ValidD = 0;
end

always @(posedge clk) begin
    if (clr) begin
        InstrD <= 0; PCD <= 0; ValidD <= 1'b0;
    end else if (!stall) begin
        InstrD <= InstrF; PCD <= PCF; ValidD <= 1'b1;
    end
end

endmodule
