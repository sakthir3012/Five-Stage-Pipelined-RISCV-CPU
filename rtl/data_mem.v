`timescale 1ns/1ns

// data_mem.v - data memory (64 x 32-bit), built from four 64x8 byte lanes so
//              Quartus maps it onto Xilinx block RAM instead of flip-flops.
//
// * write : synchronous, byte-lane enables decoded from funct3 (sb/sh/sw)
// * read  : synchronous - the 32-bit word at wr_addr appears on rd_data_mem
//           ONE CYCLE AFTER the address is presented (i.e. in the Writeback
//           stage for a load that is in Memory). Byte/half selection and
//           sign/zero extension are done in the datapath.

module data_mem #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 32, MEM_SIZE = 64) (
    input       clk, wr_en,
    input [2:0] funct3,
    input       [ADDR_WIDTH-1:0] wr_addr, wr_data,
    output      [DATA_WIDTH-1:0] rd_data_mem
);

(* ram_style = "block" *) reg [7:0] lane0 [0:MEM_SIZE-1];
(* ram_style = "block" *) reg [7:0] lane1 [0:MEM_SIZE-1];
(* ram_style = "block" *) reg [7:0] lane2 [0:MEM_SIZE-1];
(* ram_style = "block" *) reg [7:0] lane3 [0:MEM_SIZE-1];

reg [7:0] q0, q1, q2, q3;

wire [5:0] word_addr = wr_addr[7:2];          // 64 words

// byte enables: 00 sb, 01 sh, 10 sw
reg [3:0] be;
always @(*) begin
    case (funct3[1:0])
        2'b00:   be = 4'b0001 << wr_addr[1:0];
        2'b01:   be = wr_addr[1] ? 4'b1100 : 4'b0011;
        2'b10:   be = 4'b1111;
        default: be = 4'b0000;
    endcase
end

// replicate store data into the lanes that are enabled
wire [31:0] wd = (funct3[1:0] == 2'b00) ? {4{wr_data[7:0]}}  :
                 (funct3[1:0] == 2'b01) ? {2{wr_data[15:0]}} : wr_data;

always @(posedge clk) begin
    if (wr_en && be[0]) lane0[word_addr] <= wd[ 7: 0];
    if (wr_en && be[1]) lane1[word_addr] <= wd[15: 8];
    if (wr_en && be[2]) lane2[word_addr] <= wd[23:16];
    if (wr_en && be[3]) lane3[word_addr] <= wd[31:24];
    q0 <= lane0[word_addr];
    q1 <= lane1[word_addr];
    q2 <= lane2[word_addr];
    q3 <= lane3[word_addr];
end

assign rd_data_mem = {q3, q2, q1, q0};

endmodule
