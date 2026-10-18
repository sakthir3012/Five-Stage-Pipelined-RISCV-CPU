`timescale 1ns/1ns
// main_decoder.v - main decoder (pipelined: outputs are the Decode-stage controls)

module main_decoder (
    input  [6:0] op,
    output       ResultSrc,
    output       MemWrite, Branch, ALUSrc,
    output       RegWrite, Jump, Jalr,
    output [2:0] ImmSrc,
    output [1:0] ALUOp,
    output       ALUSrcPC, ALUSrcZero
);

reg [13:0] controls;

always @(*) begin
    case (op)
        // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump_Jalr_ALUSrcPC_ALUSrcZero
        7'b0000011: controls = 14'b1_000_1_0_1_0_00_0_0_0_0; // loads
        7'b0100011: controls = 14'b0_001_1_1_0_0_00_0_0_0_0; // stores
        7'b0110011: controls = 14'b1_000_0_0_0_0_10_0_0_0_0; // R-type
        7'b1100011: controls = 14'b0_010_0_0_0_1_01_0_0_0_0; // branches
        7'b0010011: controls = 14'b1_000_1_0_0_0_10_0_0_0_0; // I-type ALU
        7'b1101111: controls = 14'b1_011_0_0_0_0_00_1_0_0_0; // jal
        7'b1100111: controls = 14'b1_000_1_0_0_0_00_0_1_0_0; // jalr
        7'b0110111: controls = 14'b1_100_1_0_0_0_00_0_0_0_1; // lui   (0 + imm)
        7'b0010111: controls = 14'b1_100_1_0_0_0_00_0_0_1_0; // auipc (pc + imm)
        default:    controls = 14'b0_000_0_0_0_0_00_0_0_0_0; // bubble / unknown
    endcase
end

assign {RegWrite, ImmSrc, ALUSrc, MemWrite, ResultSrc, Branch, ALUOp, Jump, Jalr, ALUSrcPC, ALUSrcZero} = controls;

endmodule
