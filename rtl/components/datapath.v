`timescale 1ns/1ns
// datapath.v - 5-stage pipelined datapath (Fetch, Decode, Execute, Memory, Writeback)
//
// Area-oriented version:
//   * data memory and register file are synchronous (block RAM)
//   * load data is picked/extended in Writeback straight from the RAM output
//   * PC is carried as PW=11 bits (2 KB instruction memory); the 32-bit PC/PCW
//     ports are zero-extended

module datapath (
    input         clk, reset,
    // control signals generated in Decode
    input         ResultSrcD, ALUSrcD, RegWriteD, MemWriteD, BranchD, JumpD, JalrD,
    input         ALUSrcPCD, ALUSrcZeroD,
    input  [2:0]  ImmSrcD,
    input  [3:0]  ALUControlD,
    // debug view of the CSR file (board LEDs)
    input  [2:0]  DbgSel,
    output [31:0] DbgOut,
    // instruction memory
    output [31:0] PC,
    input  [31:0] Instr,
    output [31:0] InstrD,
    // data memory
    output        MemWriteM,
    output [31:0] Mem_WrAddr, Mem_WrData,
    input  [31:0] ReadData,          // synchronous: valid in the Writeback cycle
    output [ 2:0] MemFunct3,
    // observation ports
    output [31:0] Result,
    output [31:0] PCW, ALUResultW, WriteDataW
);

localparam PW = 11;

// ---------------- Fetch ----------------
wire [PW-1:0] PCr, PCPlus4F, PCNextF, PCTargetE;
wire          PCSrcE, StallF, StallD, FlushD, FlushE;

assign PC       = {{(32-PW){1'b0}}, PCr};
assign PCPlus4F = PCr + {{(PW-3){1'b0}}, 3'd4};

mux2 #(PW)      pcmux (PCPlus4F, PCTargetE, PCSrcE, PCNextF);
reset_ff #(PW)  pcreg (clk, reset, StallF, PCNextF, PCr);

// ---------------- IF/ID ----------------
wire [PW-1:0] PCD;
wire          ValidD;

pl_reg_fd #(PW) plfd (
    .clk(clk), .stall(StallD), .clr(FlushD | reset),
    .InstrF(Instr), .PCF(PCr),
    .InstrD(InstrD), .PCD(PCD), .ValidD(ValidD)
);

// ---------------- Decode ----------------
wire [ 4:0] Rs1D = InstrD[19:15];
wire [ 4:0] Rs2D = InstrD[24:20];
wire [ 4:0] RdD  = InstrD[11:7];
wire [31:0] RD1D, RD2D, ImmExtD;

wire        RegWriteW;
wire [ 4:0] RdW;
wire [31:0] ResultW;

// The RAM-based register file needs the read address one cycle early: take it
// from the instruction being fetched, or from the held instruction on a stall.
wire [4:0] RfAddr1 = StallD ? InstrD[19:15] : Instr[19:15];
wire [4:0] RfAddr2 = StallD ? InstrD[24:20] : Instr[24:20];

reg_file rf (
    .clk(clk), .wr_en(RegWriteW),
    .rd_addr1(RfAddr1), .rd_addr2(RfAddr2),
    .cur_addr1(Rs1D),   .cur_addr2(Rs2D),
    .wr_addr(RdW), .wr_data(ResultW),
    .rd_data1(RD1D), .rd_data2(RD2D)
);

imm_extend ext (InstrD[31:7], ImmSrcD, ImmExtD);

// SYSTEM / illegal-instruction decode
wire CsrD, EcallD, EbreakD, MretD, IllegalD;
decode_check dchk (
    .valid(ValidD), .op(InstrD[6:0]), .f3(InstrD[14:12]),
    .f7(InstrD[31:25]), .f12(InstrD[31:20]),
    .is_csr(CsrD), .is_ecall(EcallD), .is_ebreak(EbreakD),
    .is_mret(MretD), .illegal(IllegalD)
);

// ---------------- ID/EX ----------------
wire [31:0]   RD1E, RD2E, ImmExtE;
wire [PW-1:0] PCE;
wire [ 4:0]   Rs1E, Rs2E, RdE;
wire          RegWriteE, ResultSrcE, MemWriteE, JumpE, JalrE, BranchE;
wire [ 3:0]   ALUControlE;
wire          ALUSrcE, ALUSrcPCE, ALUSrcZeroE;
wire          ValidE, CsrE, EcallE, EbreakE, MretE, IllegalE;
wire [ 2:0]   funct3E;

pl_reg_de #(PW) plde (
    .clk(clk), .clr(FlushE | reset),
    .RD1D(RD1D), .RD2D(RD2D), .ImmExtD(ImmExtD), .PCD(PCD),
    .Rs1D(Rs1D), .Rs2D(Rs2D), .RdD(RdD),
    .RegWriteD(RegWriteD | CsrD), .ResultSrcD(ResultSrcD), .MemWriteD(MemWriteD),
    .JumpD(JumpD), .JalrD(JalrD), .BranchD(BranchD),
    .ALUControlD(ALUControlD), .ALUSrcD(ALUSrcD),
    .ALUSrcPCD(ALUSrcPCD), .ALUSrcZeroD(ALUSrcZeroD),
    .funct3D(InstrD[14:12]),
    .ValidD(ValidD), .CsrD(CsrD), .EcallD(EcallD), .EbreakD(EbreakD),
    .MretD(MretD), .IllegalD(IllegalD),
    .RD1E(RD1E), .RD2E(RD2E), .ImmExtE(ImmExtE), .PCE(PCE),
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE),
    .RegWriteE(RegWriteE), .ResultSrcE(ResultSrcE), .MemWriteE(MemWriteE),
    .JumpE(JumpE), .JalrE(JalrE), .BranchE(BranchE),
    .ALUControlE(ALUControlE), .ALUSrcE(ALUSrcE),
    .ALUSrcPCE(ALUSrcPCE), .ALUSrcZeroE(ALUSrcZeroE),
    .funct3E(funct3E),
    .ValidE(ValidE), .CsrE(CsrE), .EcallE(EcallE), .EbreakE(EbreakE),
    .MretE(MretE), .IllegalE(IllegalE)
);

// ---------------- Execute ----------------
wire [ 1:0]   ForwardAE, ForwardBE;
wire [31:0]   ExResultM;
wire [31:0]   SrcAFwd, WriteDataE, SrcAE, SrcBE, ALUResultE, ExResultE;
wire [31:0]   PCE32 = {{(32-PW){1'b0}}, PCE};
wire [PW-1:0] PCBranchE;
wire [PW:0]   PCPlus4E;
wire          ZeroE;

mux3 #(32) fwdamux (RD1E, ResultW, ExResultM, ForwardAE, SrcAFwd);
mux3 #(32) fwdbmux (RD2E, ResultW, ExResultM, ForwardBE, WriteDataE);

// lui uses 0 + imm, auipc uses pc + imm
assign SrcAE = ALUSrcPCE ? PCE32 : (SrcAFwd & {32{~ALUSrcZeroE}});

mux2 #(32) srcbmux (WriteDataE, ImmExtE, ALUSrcE, SrcBE);

alu u_alu (SrcAE, SrcBE, ALUControlE, ALUResultE, ZeroE);

// ---- machine-mode CSRs, traps and mret (all handled in Execute, so they are precise:
//      older instructions finish, younger ones are flushed like a taken branch) ----
wire [31:0] CsrRdata, MtvecV, MepcV, TrapCause;
wire        CsrIllegal;
wire        TrapE = EcallE | EbreakE | IllegalE | CsrIllegal;
assign TrapCause = (IllegalE | CsrIllegal) ? 32'd2 :      // illegal instruction
                   EbreakE                  ? 32'd3 :      // breakpoint
                                              32'd11;      // ecall from M-mode

csr_unit csr (
    .clk(clk), .reset(reset),
    .csr_op(CsrE), .funct3(funct3E), .csr_addr(ImmExtE[11:0]),
    .rs1_val(SrcAFwd), .rs1_idx(Rs1E),
    .trap_en(TrapE), .mret_en(MretE),
    .trap_pc(PCE32), .trap_cause(TrapCause),
    .retire(ValidE & ~TrapE),
    .rdata(CsrRdata), .csr_illegal(CsrIllegal),
    .mtvec_o(MtvecV), .mepc_o(MepcV),
    .dbg_sel(DbgSel), .dbg_out(DbgOut)
);

assign PCPlus4E  = {1'b0, PCE} + {{(PW-2){1'b0}}, 3'd4};
assign PCBranchE = PCE + ImmExtE[PW-1:0];

assign PCTargetE = TrapE ? MtvecV[PW-1:0] :
                   MretE ? MepcV[PW-1:0]  :
                   JalrE ? {ALUResultE[PW-1:1], 1'b0} : PCBranchE;
assign PCSrcE    = TrapE | MretE | (BranchE & ZeroE) | JumpE | JalrE;
// csr ops write the old CSR value; jal / jalr write PC+4; everything else writes the ALU result
assign ExResultE = CsrE ? CsrRdata :
                   (JumpE | JalrE) ? {{(31-PW){1'b0}}, PCPlus4E} : ALUResultE;

// ---------------- EX/MEM ----------------
wire [31:0]   WriteDataM;
wire [PW-1:0] PCM;
wire [ 4:0]   RdM;
wire          RegWriteM, ResultSrcM;
wire [ 2:0]   funct3M;

pl_reg_em #(PW) plem (
    .clk(clk), .clr(reset),
    .ExResultE(ExResultE), .WriteDataE(WriteDataE), .PCE(PCE), .RdE(RdE),
    .RegWriteE(RegWriteE & ~TrapE), .ResultSrcE(ResultSrcE), .MemWriteE(MemWriteE & ~TrapE),
    .funct3E(funct3E),
    .ExResultM(ExResultM), .WriteDataM(WriteDataM), .PCM(PCM), .RdM(RdM),
    .RegWriteM(RegWriteM), .ResultSrcM(ResultSrcM), .MemWriteM(MemWriteM),
    .funct3M(funct3M)
);

// ---------------- Memory ----------------
// data_mem handles sb/sh/sw with byte-lane enables; loads are read as a full
// word and picked/extended in Writeback.
assign MemFunct3  = funct3M;
assign Mem_WrAddr = ExResultM;
assign Mem_WrData = WriteDataM;

// ---------------- MEM/WB ----------------
wire          ResultSrcW;
wire [PW-1:0] PCWr;
wire [ 2:0]   funct3W;

pl_reg_mw #(PW) plmw (
    .clk(clk), .clr(reset),
    .ALUResultM(ExResultM), .WriteDataM(WriteDataM), .PCM(PCM),
    .RdM(RdM), .funct3M(funct3M), .RegWriteM(RegWriteM), .ResultSrcM(ResultSrcM),
    .ALUResultW(ALUResultW), .WriteDataW(WriteDataW), .PCW(PCWr),
    .RdW(RdW), .funct3W(funct3W), .RegWriteW(RegWriteW), .ResultSrcW(ResultSrcW)
);

assign PCW = {{(32-PW){1'b0}}, PCWr};

// ---------------- Writeback ----------------
// funct3W: 000 lb, 001 lh, 010 lw, 100 lbu, 101 lhu
reg  [ 7:0] byteW;
always @(*) begin
    case (ALUResultW[1:0])
        2'b00:   byteW = ReadData[ 7: 0];
        2'b01:   byteW = ReadData[15: 8];
        2'b10:   byteW = ReadData[23:16];
        default: byteW = ReadData[31:24];
    endcase
end
wire [15:0] halfW = ALUResultW[1] ? ReadData[31:16] : ReadData[15:0];

wire [31:0] LoadW = (funct3W[1:0] == 2'b00) ? {{24{~funct3W[2] & byteW[7]}},  byteW} :
                    (funct3W[1:0] == 2'b01) ? {{16{~funct3W[2] & halfW[15]}}, halfW} :
                                              ReadData;

mux2 #(32) resultmux (ALUResultW, LoadW, ResultSrcW, ResultW);
assign Result = ResultW;

// ---------------- Hazard unit ----------------
hazard_unit hu (
    .Rs1D(Rs1D), .Rs2D(Rs2D),
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE),
    .RdM(RdM), .RegWriteM(RegWriteM),
    .RdW(RdW), .RegWriteW(RegWriteW),
    .ResultSrcE0(ResultSrcE & ~TrapE),
    .PCSrcE(PCSrcE),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE),
    .StallF(StallF), .StallD(StallD),
    .FlushD(FlushD), .FlushE(FlushE)
);

endmodule
