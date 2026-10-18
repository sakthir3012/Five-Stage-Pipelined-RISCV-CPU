`timescale 1ns/1ns
// pipeline register -> execute | memory
// Only the side-effect controls are reset; data fields just follow the pipeline.

module pl_reg_em #(parameter PW = 11) (
    input               clk, clr,
    input      [31:0]   ExResultE, WriteDataE,
    input      [PW-1:0] PCE,
    input      [ 4:0]   RdE,
    input               RegWriteE, ResultSrcE, MemWriteE,
    input      [ 2:0]   funct3E,
    output reg [31:0]   ExResultM, WriteDataM,
    output reg [PW-1:0] PCM,
    output reg [ 4:0]   RdM,
    output reg          RegWriteM, ResultSrcM, MemWriteM,
    output reg [ 2:0]   funct3M
);

initial begin
    ExResultM = 0; WriteDataM = 0; PCM = 0; RdM = 0;
    RegWriteM = 0; ResultSrcM = 0; MemWriteM = 0; funct3M = 0;
end

always @(posedge clk) begin
    ExResultM <= ExResultE; WriteDataM <= WriteDataE; PCM <= PCE; RdM <= RdE;
    funct3M <= funct3E;
end

always @(posedge clk) begin
    if (clr) begin
        RegWriteM <= 0; ResultSrcM <= 0; MemWriteM <= 0;
    end else begin
        RegWriteM <= RegWriteE; ResultSrcM <= ResultSrcE; MemWriteM <= MemWriteE;
    end
end

endmodule
