`timescale 1ns/1ns

// instr_mem.v - instruction memory

module instr_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 512,
   parameter INIT_FILE = "rv32i_test.mem") (
    input       [ADDR_WIDTH-1:0] instr_addr,
    output      [DATA_WIDTH-1:0] instr
);

// array of 64 32-bit words or instructions
reg [DATA_WIDTH-1:0] instr_ram [0:MEM_SIZE-1];

integer n;
initial begin
    for (n = 0; n < MEM_SIZE; n = n + 1) instr_ram[n] = 32'b0;
    $readmemh(INIT_FILE, instr_ram);
end

// word-aligned memory access
// combinational read logic
assign instr = instr_ram[instr_addr[31:2]];

endmodule

