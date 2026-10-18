`timescale 1ns/1ns
// hazard_unit.v - forwarding, load-use stall and branch flush (combinational)

module hazard_unit (
    input  [4:0] Rs1D, Rs2D,
    input  [4:0] Rs1E, Rs2E, RdE,
    input  [4:0] RdM, RdW,
    input        RegWriteM, RegWriteW,
    input        ResultSrcE0,          // instruction in Execute is a load
    input        PCSrcE,               // branch / jump taken in Execute
    output [1:0] ForwardAE, ForwardBE, // 00 regfile, 01 ResultW, 10 ALUResultM
    output       StallF, StallD,
    output       FlushD, FlushE
);

wire fwdA_M = RegWriteM && (RdM != 5'd0) && (RdM == Rs1E);
wire fwdA_W = RegWriteW && (RdW != 5'd0) && (RdW == Rs1E);
wire fwdB_M = RegWriteM && (RdM != 5'd0) && (RdM == Rs2E);
wire fwdB_W = RegWriteW && (RdW != 5'd0) && (RdW == Rs2E);

assign ForwardAE = fwdA_M ? 2'b10 : (fwdA_W ? 2'b01 : 2'b00);
assign ForwardBE = fwdB_M ? 2'b10 : (fwdB_W ? 2'b01 : 2'b00);

wire lwStall = ResultSrcE0 && (RdE != 5'd0) && ((RdE == Rs1D) || (RdE == Rs2D));

assign StallF = lwStall;
assign StallD = lwStall;
assign FlushD = PCSrcE;
assign FlushE = lwStall | PCSrcE;

endmodule
