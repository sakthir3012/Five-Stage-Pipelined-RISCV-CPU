`timescale 1ns/1ns
// riscv_cpu.v - 5-stage pipelined RISC-V CPU

module riscv_cpu (
    input         clk, reset,
    output [31:0] PC,
    input  [31:0] Instr,
    output        MemWrite,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,
    output [31:0] Result,
    output [ 2:0] funct3,
    output [31:0] PCW, ALUResultW, WriteDataW,
    input  [ 2:0] DbgSel,
    output [31:0] DbgOut
);

wire        ResultSrc, ALUSrc, RegWrite, Branch, Jump, Jalr, ALUSrcPC, ALUSrcZero;
wire        MemWrite_D;
wire [2:0]  ImmSrc;
wire [3:0]  ALUControl;
wire [31:0] InstrD;

controller c (InstrD[6:0], InstrD[14:12], InstrD[30],
              ResultSrc, MemWrite_D, ALUSrc,
              RegWrite, Branch, Jump, Jalr, ImmSrc, ALUControl,
              ALUSrcPC, ALUSrcZero);

datapath dp (
    .clk(clk), .reset(reset),
    .ResultSrcD(ResultSrc), .ALUSrcD(ALUSrc), .RegWriteD(RegWrite),
    .MemWriteD(MemWrite_D), .BranchD(Branch), .JumpD(Jump), .JalrD(Jalr),
    .ALUSrcPCD(ALUSrcPC), .ALUSrcZeroD(ALUSrcZero),
    .ImmSrcD(ImmSrc), .ALUControlD(ALUControl),
    .PC(PC), .Instr(Instr), .InstrD(InstrD),
    .MemWriteM(MemWrite),
    .Mem_WrAddr(Mem_WrAddr), .Mem_WrData(Mem_WrData),
    .ReadData(ReadData), .MemFunct3(funct3),
    .Result(Result), .PCW(PCW), .ALUResultW(ALUResultW), .WriteDataW(WriteDataW),
    .DbgSel(DbgSel), .DbgOut(DbgOut)
);

endmodule
