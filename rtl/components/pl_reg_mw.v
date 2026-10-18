`timescale 1ns/1ns
// pipeline register -> memory | writeback
// Load data is NOT registered here any more: the synchronous data RAM already
// holds it for the Writeback cycle. funct3 is carried so Writeback can pick the
// right byte/half and extend it.

module pl_reg_mw #(parameter PW = 11) (
    input               clk, clr,
    input      [31:0]   ALUResultM, WriteDataM,
    input      [PW-1:0] PCM,
    input      [ 4:0]   RdM,
    input      [ 2:0]   funct3M,
    input               RegWriteM, ResultSrcM,
    output reg [31:0]   ALUResultW, WriteDataW,
    output reg [PW-1:0] PCW,
    output reg [ 4:0]   RdW,
    output reg [ 2:0]   funct3W,
    output reg          RegWriteW, ResultSrcW
);

initial begin
    ALUResultW = 0; WriteDataW = 0; PCW = 0; RdW = 0; funct3W = 0;
    RegWriteW = 0; ResultSrcW = 0;
end

always @(posedge clk) begin
    ALUResultW <= ALUResultM; WriteDataW <= WriteDataM;
    PCW <= PCM; RdW <= RdM; funct3W <= funct3M;
end

always @(posedge clk) begin
    if (clr) begin
        RegWriteW <= 0; ResultSrcW <= 0;
    end else begin
        RegWriteW <= RegWriteM; ResultSrcW <= ResultSrcM;
    end
end

endmodule
