`timescale 1ns/1ns
// reg_file.v - register file (32 x 32-bit) built for block RAM.
//
// Two RAM copies give two read ports. Reads are synchronous: the address is
// presented one cycle early (rd_addr*, taken from the instruction being
// fetched, or from the held instruction on a stall) and the data shows up in
// the Decode cycle. Writes happen on the rising edge from Writeback.
//
// Because a block RAM returns OLD data for a same-edge write, two bypasses
// recreate the "write-then-read" behaviour of the old negedge register file:
//   * hit*/wd_q   : the producer wrote on the same edge the read address was
//                   captured (it was in Writeback one cycle earlier)
//   * cur_hit*    : the producer is in Writeback during this Decode cycle
// x0 always reads as zero.

module reg_file #(parameter DATA_WIDTH = 32) (
    input       clk,
    input       wr_en,
    input       [4:0] rd_addr1, rd_addr2,     // next-cycle read addresses
    input       [4:0] cur_addr1, cur_addr2,   // registers read by the instr in Decode now
    input       [4:0] wr_addr,
    input       [DATA_WIDTH-1:0] wr_data,
    output      [DATA_WIDTH-1:0] rd_data1, rd_data2
);

(* ram_style = "distributed" *) reg [DATA_WIDTH-1:0] bank1 [0:31];
(* ram_style = "distributed" *) reg [DATA_WIDTH-1:0] bank2 [0:31];
reg [DATA_WIDTH-1:0] q1, q2, wd_q;
reg                  hit1, hit2;

integer i;
initial begin
    for (i = 0; i < 32; i = i + 1) begin
        bank1[i] = 0;
        bank2[i] = 0;
    end
    q1 = 0; q2 = 0; wd_q = 0; hit1 = 0; hit2 = 0;
end

wire we = wr_en && (wr_addr != 5'd0);

always @(posedge clk) begin
    if (we) begin
        bank1[wr_addr] <= wr_data;
        bank2[wr_addr] <= wr_data;
    end
    q1   <= bank1[rd_addr1];
    q2   <= bank2[rd_addr2];
    hit1 <= we && (wr_addr == rd_addr1);
    hit2 <= we && (wr_addr == rd_addr2);
    wd_q <= wr_data;
end

wire cur_hit1 = we && (wr_addr == cur_addr1);
wire cur_hit2 = we && (wr_addr == cur_addr2);

assign rd_data1 = (cur_addr1 == 5'd0) ? {DATA_WIDTH{1'b0}} :
                  cur_hit1            ? wr_data :
                  hit1                ? wd_q    : q1;
assign rd_data2 = (cur_addr2 == 5'd0) ? {DATA_WIDTH{1'b0}} :
                  cur_hit2            ? wr_data :
                  hit2                ? wd_q    : q2;

endmodule
