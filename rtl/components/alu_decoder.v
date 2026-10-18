`timescale 1ns/1ns
// alu_decoder.v - logic for ALU decoder

module alu_decoder (
    input            opb5,
    input [2:0]      funct3,
    input            funct7b5,
    input [1:0]      ALUOp,
    output reg [3:0] ALUControl
);

always @(*) begin
    case (ALUOp)
        2'b00: ALUControl = 4'b0000;                       // add
        2'b01: begin                                       // branches
            case (funct3)
                3'b000:  ALUControl = 4'b1010;             // beq
                3'b001:  ALUControl = 4'b1011;             // bne
                3'b100:  ALUControl = 4'b1100;             // blt
                3'b101:  ALUControl = 4'b1101;             // bge
                3'b110:  ALUControl = 4'b1110;             // bltu
                3'b111:  ALUControl = 4'b1111;             // bgeu
                default: ALUControl = 4'b0001;
            endcase
        end
        default: begin                                     // R-type / I-type ALU
            case (funct3)
                3'b000:  ALUControl = (funct7b5 & opb5) ? 4'b0001 : 4'b0000; // sub / add
                3'b001:  ALUControl = 4'b0111;             // sll
                3'b010:  ALUControl = 4'b0101;             // slt
                3'b011:  ALUControl = 4'b0110;             // sltu
                3'b100:  ALUControl = 4'b0100;             // xor
                3'b101:  ALUControl = funct7b5 ? 4'b1001 : 4'b1000; // sra / srl
                3'b110:  ALUControl = 4'b0011;             // or
                3'b111:  ALUControl = 4'b0010;             // and
                default: ALUControl = 4'b0000;
            endcase
        end
    endcase
end

endmodule
