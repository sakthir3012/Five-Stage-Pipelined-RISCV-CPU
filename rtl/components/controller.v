`timescale 1ns/1ns
// controller.v - controller for the pipelined RISC-V CPU (used in Decode)

module controller (
    input  [6:0] op,
    input  [2:0] funct3,
    input        funct7b5,
    output       ResultSrc,
    output       MemWrite,
    output       ALUSrc,
    output       RegWrite, Branch, Jump, Jalr,
    output [2:0] ImmSrc,
    output [3:0] ALUControl,
    output       ALUSrcPC, ALUSrcZero
);

wire [1:0] ALUOp;

main_decoder md (op, ResultSrc, MemWrite, Branch, ALUSrc,
                 RegWrite, Jump, Jalr, ImmSrc, ALUOp, ALUSrcPC, ALUSrcZero);

alu_decoder  ad (op[5], funct3, funct7b5, ALUOp, ALUControl);

endmodule
