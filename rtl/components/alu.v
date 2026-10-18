`timescale 1ns/1ns
// alu.v - ALU with ONE shared adder/subtractor and ONE shared shifter.
// Control codes and branch encodings are identical to the original ALU
// (branch ops return 0 when the branch is taken, so Zero == taken).

module alu #(parameter WIDTH = 32) (
    input [WIDTH-1:0] a, b,
    input [3:0] alu_ctrl,
    output reg [WIDTH-1:0] alu_out,
    output zero
);

// ---------------- shared add / subtract ----------------
wire             sub     = (alu_ctrl != 4'b0000);          // everything but ADD subtracts
wire [WIDTH-1:0] bx      = b ^ {WIDTH{sub}};
wire [WIDTH+1:0] addsub  = {1'b0, a, 1'b1} + {1'b0, bx, sub};   // carry-in = sub
wire [WIDTH-1:0] sum     = addsub[WIDTH:1];
wire             carry   = addsub[WIDTH+1];

wire eq  = (sum == {WIDTH{1'b0}});                          // a == b   (when sub)
wire ltu = ~carry;                                          // a <  b   unsigned
wire lt  = (a[WIDTH-1] ^ b[WIDTH-1]) ? a[WIDTH-1] : sum[WIDTH-1];  // a < b signed

// ---------------- shared shifter (right shifter + bit reversal for SLL) ----------------
wire left  = (alu_ctrl == 4'b0111);
wire arith = (alu_ctrl == 4'b1001);

reg [WIDTH-1:0] a_rev, sh_rev;
wire signed [WIDTH:0] sh_ext;
wire signed [WIDTH:0] sh_res;
wire [WIDTH-1:0]      sh_r;
wire [WIDTH-1:0]      sh_in;
integer k1, k2;

always @(*) begin
    for (k1 = 0; k1 < WIDTH; k1 = k1 + 1) a_rev[k1] = a[WIDTH-1-k1];
end

assign sh_in  = left ? a_rev : a;
assign sh_ext = {(arith & a[WIDTH-1]), sh_in};
assign sh_res = sh_ext >>> b[4:0];
assign sh_r   = sh_res[WIDTH-1:0];

always @(*) begin
    for (k2 = 0; k2 < WIDTH; k2 = k2 + 1) sh_rev[k2] = sh_r[WIDTH-1-k2];
end

wire [WIDTH-1:0] sh_out = left ? sh_rev : sh_r;

// ---------------- result select ----------------
always @(*) begin
    case (alu_ctrl)
        4'b0000: alu_out = sum;                                  // ADD
        4'b0001: alu_out = sum;                                  // SUB
        4'b0010: alu_out = a & b;                                // AND
        4'b0011: alu_out = a | b;                                // OR
        4'b0100: alu_out = a ^ b;                                // XOR
        4'b0101: alu_out = {{(WIDTH-1){1'b0}}, lt};              // SLT
        4'b0110: alu_out = {{(WIDTH-1){1'b0}}, ltu};             // SLTU
        4'b0111: alu_out = sh_out;                               // SLL
        4'b1000: alu_out = sh_out;                               // SRL
        4'b1001: alu_out = sh_out;                               // SRA

        4'b1010: alu_out = {{(WIDTH-1){1'b0}}, ~eq};             // BEQ  (0 = taken)
        4'b1011: alu_out = {{(WIDTH-1){1'b0}},  eq};             // BNE
        4'b1100: alu_out = {{(WIDTH-1){1'b0}}, ~lt};             // BLT
        4'b1101: alu_out = {{(WIDTH-1){1'b0}},  lt};             // BGE
        4'b1110: alu_out = {{(WIDTH-1){1'b0}}, ~ltu};            // BLTU
        4'b1111: alu_out = {{(WIDTH-1){1'b0}},  ltu};            // BGEU

        default: alu_out = {WIDTH{1'b0}};
    endcase
end

assign zero = (alu_out == {WIDTH{1'b0}});

endmodule
