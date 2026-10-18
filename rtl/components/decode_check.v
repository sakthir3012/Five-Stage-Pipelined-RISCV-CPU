`timescale 1ns/1ns
// decode_check.v - classifies the instruction in Decode.
//   * flags SYSTEM instructions (CSR ops, ecall, ebreak, mret)
//   * flags ILLEGAL encodings (unknown opcode or invalid funct3/funct7)
// "valid" is 0 for pipeline bubbles, which are never illegal.
// fence / fence.i / wfi are legal and behave as no-ops (single hart, no caches).

module decode_check (
    input        valid,
    input  [6:0] op,
    input  [2:0] f3,
    input  [6:0] f7,
    input  [11:0] f12,
    output reg   is_csr, is_ecall, is_ebreak, is_mret, illegal
);

always @(*) begin
    is_csr = 1'b0; is_ecall = 1'b0; is_ebreak = 1'b0; is_mret = 1'b0; illegal = 1'b0;
    if (valid) begin
        case (op)
            7'b0110111, 7'b0010111, 7'b1101111: ;                       // lui, auipc, jal
            7'b1100111: illegal = (f3 != 3'b000);                       // jalr
            7'b1100011: illegal = (f3 == 3'b010) | (f3 == 3'b011);      // branches
            7'b0000011: illegal = ~((f3 == 3'b000) | (f3 == 3'b001) | (f3 == 3'b010) |
                                    (f3 == 3'b100) | (f3 == 3'b101));   // loads
            7'b0100011: illegal = f3[2] | (f3[1:0] == 2'b11);           // stores
            7'b0010011: begin                                           // ALU immediate
                if (f3 == 3'b001)      illegal = (f7 != 7'b0000000);                          // slli
                else if (f3 == 3'b101) illegal = (f7 != 7'b0000000) & (f7 != 7'b0100000);     // srli/srai
            end
            7'b0110011: illegal = (f7 != 7'b0000000) &                  // ALU register
                                  ~((f7 == 7'b0100000) & ((f3 == 3'b000) | (f3 == 3'b101)));
            7'b0001111: illegal = (f3[2:1] != 2'b00);                   // fence (000), fence.i (001)
            7'b1110011: begin                                           // SYSTEM
                if (f3 == 3'b000) begin
                    case (f12)
                        12'h000: is_ecall  = 1'b1;
                        12'h001: is_ebreak = 1'b1;
                        12'h302: is_mret   = 1'b1;
                        12'h105: ;                                      // wfi -> nop
                        default: illegal   = 1'b1;
                    endcase
                end else if (f3 == 3'b100) illegal = 1'b1;
                else                       is_csr  = 1'b1;
            end
            default: illegal = 1'b1;
        endcase
    end
end

endmodule
