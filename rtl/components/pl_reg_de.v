`timescale 1ns/1ns
// pipeline register -> decode | execute
// Only the control bits and PCE are cleared on a flush/reset: a bubble just needs
// all side-effect controls at 0, the data fields are don't-care. PCE is cleared
// so a squashed instruction never shows up on the PCW observation port.

module pl_reg_de #(parameter PW = 11) (
    input               clk, clr,
    input      [31:0]   RD1D, RD2D, ImmExtD,
    input      [PW-1:0] PCD,
    input      [ 4:0]   Rs1D, Rs2D, RdD,
    input               RegWriteD, ResultSrcD, MemWriteD, JumpD, JalrD, BranchD,
    input      [ 3:0]   ALUControlD,
    input               ALUSrcD, ALUSrcPCD, ALUSrcZeroD,
    input      [ 2:0]   funct3D,
    input               ValidD, CsrD, EcallD, EbreakD, MretD, IllegalD,
    output reg [31:0]   RD1E, RD2E, ImmExtE,
    output reg [PW-1:0] PCE,
    output reg [ 4:0]   Rs1E, Rs2E, RdE,
    output reg          RegWriteE, ResultSrcE, MemWriteE, JumpE, JalrE, BranchE,
    output reg [ 3:0]   ALUControlE,
    output reg          ALUSrcE, ALUSrcPCE, ALUSrcZeroE,
    output reg [ 2:0]   funct3E,
    output reg          ValidE, CsrE, EcallE, EbreakE, MretE, IllegalE
);

initial begin
    RD1E = 0; RD2E = 0; ImmExtE = 0; PCE = 0;
    Rs1E = 0; Rs2E = 0; RdE = 0;
    RegWriteE = 0; ResultSrcE = 0; MemWriteE = 0; JumpE = 0; JalrE = 0; BranchE = 0;
    ALUControlE = 0; ALUSrcE = 0; ALUSrcPCE = 0; ALUSrcZeroE = 0; funct3E = 0;
    ValidE = 0; CsrE = 0; EcallE = 0; EbreakE = 0; MretE = 0; IllegalE = 0;
end

// data fields: always load
always @(posedge clk) begin
    RD1E <= RD1D; RD2E <= RD2D; ImmExtE <= ImmExtD;
    Rs1E <= Rs1D; Rs2E <= Rs2D; RdE <= RdD;
    ALUControlE <= ALUControlD; ALUSrcE <= ALUSrcD;
    ALUSrcPCE <= ALUSrcPCD; ALUSrcZeroE <= ALUSrcZeroD; funct3E <= funct3D;
end

// control fields + PC: cleared on flush / reset
always @(posedge clk) begin
    if (clr) begin
        PCE <= 0;
        RegWriteE <= 0; ResultSrcE <= 0; MemWriteE <= 0;
        JumpE <= 0; JalrE <= 0; BranchE <= 0;
        ValidE <= 0; CsrE <= 0; EcallE <= 0; EbreakE <= 0; MretE <= 0; IllegalE <= 0;
    end else begin
        PCE <= PCD;
        RegWriteE <= RegWriteD; ResultSrcE <= ResultSrcD; MemWriteE <= MemWriteD;
        JumpE <= JumpD; JalrE <= JalrD; BranchE <= BranchD;
        ValidE <= ValidD; CsrE <= CsrD; EcallE <= EcallD; EbreakE <= EbreakD;
        MretE <= MretD; IllegalE <= IllegalD;
    end
end

endmodule
