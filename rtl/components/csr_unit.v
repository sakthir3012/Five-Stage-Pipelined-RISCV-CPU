`timescale 1ns/1ns
// csr_unit.v - machine-mode CSR file, trap entry and mret (lives in the Execute stage)
//
// Implemented CSRs
//   0x300 mstatus  (MIE bit3, MPIE bit7, MPP hard-wired 11)   0x301 misa (RV32I, read-only)
//   0x305 mtvec    (direct mode)   0x340 mscratch   0x341 mepc   0x342 mcause   0x343 mtval
//   0xB00/0xB80 mcycle/mcycleh     0xB02/0xB82 minstret/minstreth   (read/write)
//   0xC00/0xC80 cycle/cycleh   0xC01/0xC81 time/timeh   0xC02/0xC82 instret/instreth (read-only)
//   0xF11-0xF14 mvendorid, marchid, mimpid, mhartid (read-only, 0)
// An access to any other CSR, or a write to a read-only CSR, is an illegal instruction.

module csr_unit #(parameter [31:0] MTVEC_RESET = 32'h0000_0400) (
    input         clk, reset,
    // CSR instruction in Execute
    input         csr_op,
    input  [ 2:0] funct3,
    input  [11:0] csr_addr,
    input  [31:0] rs1_val,
    input  [ 4:0] rs1_idx,
    // trap / return from Execute
    input         trap_en, mret_en,
    input  [31:0] trap_pc, trap_cause,
    input         retire,                 // an instruction completes in Execute
    output [31:0] rdata,
    output        csr_illegal,
    output [31:0] mtvec_o, mepc_o,
    // debug view for the board LEDs
    input  [ 2:0] dbg_sel,
    output reg [31:0] dbg_out
);

reg [31:2] mtvec = MTVEC_RESET[31:2];
reg [31:2] mepc  = 30'b0;
reg [31:0] mscratch = 32'b0, mcause = 32'b0, mtval = 32'b0;
reg        mie = 1'b0, mpie = 1'b0;
reg [63:0] mcycle = 64'b0, minstret = 64'b0;

wire [31:0] mstatus = {19'b0, 2'b11, 3'b000, mpie, 3'b000, mie, 3'b000};

// ---------------- read ----------------
reg        known;
reg [31:0] rd_val;
always @(*) begin
    known  = 1'b1;
    rd_val = 32'b0;
    case (csr_addr)
        12'h300: rd_val = mstatus;
        12'h301: rd_val = 32'h4000_0100;                 // misa: RV32, "I"
        12'h305: rd_val = {mtvec, 2'b00};
        12'h340: rd_val = mscratch;
        12'h341: rd_val = {mepc, 2'b00};
        12'h342: rd_val = mcause;
        12'h343: rd_val = mtval;
        12'hB00, 12'hC00, 12'hC01: rd_val = mcycle[31:0];
        12'hB80, 12'hC80, 12'hC81: rd_val = mcycle[63:32];
        12'hB02, 12'hC02:          rd_val = minstret[31:0];
        12'hB82, 12'hC82:          rd_val = minstret[63:32];
        12'hF11, 12'hF12, 12'hF13, 12'hF14: rd_val = 32'b0;
        default: known = 1'b0;
    endcase
end
assign rdata = rd_val;

// ---------------- write value ----------------
wire [1:0]  op    = funct3[1:0];                         // 01 rw, 10 rs, 11 rc
wire [31:0] src   = funct3[2] ? {27'b0, rs1_idx} : rs1_val;
wire [31:0] wval  = (op == 2'b01) ? src :
                    (op == 2'b10) ? (rd_val | src) : (rd_val & ~src);
wire write_attempt = (op == 2'b01) | (rs1_idx != 5'd0);
wire read_only     = (csr_addr[11:10] == 2'b11);

assign csr_illegal = csr_op & (~known | (write_attempt & read_only));
wire csr_we = csr_op & ~csr_illegal & write_attempt;

assign mtvec_o = {mtvec, 2'b00};
assign mepc_o  = {mepc, 2'b00};

// ---------------- update ----------------
always @(posedge clk) begin
    if (reset) begin
        mtvec <= MTVEC_RESET[31:2]; mepc <= 30'b0;
        mscratch <= 32'b0; mcause <= 32'b0; mtval <= 32'b0;
        mie <= 1'b0; mpie <= 1'b0;
        mcycle <= 64'b0; minstret <= 64'b0;
    end else begin
        mcycle <= mcycle + 64'd1;
        if (retire) minstret <= minstret + 64'd1;

        if (csr_we) begin
            case (csr_addr)
                12'h300: begin mie <= wval[3]; mpie <= wval[7]; end
                12'h305: mtvec    <= wval[31:2];
                12'h340: mscratch <= wval;
                12'h341: mepc     <= wval[31:2];
                12'h342: mcause   <= wval;
                12'h343: mtval    <= wval;
                12'hB00: mcycle[31:0]    <= wval;
                12'hB80: mcycle[63:32]   <= wval;
                12'hB02: minstret[31:0]  <= wval;
                12'hB82: minstret[63:32] <= wval;
                default: ;
            endcase
        end

        if (trap_en) begin
            mepc   <= trap_pc[31:2];
            mcause <= trap_cause;
            mtval  <= 32'b0;
            mpie   <= mie;
            mie    <= 1'b0;
        end else if (mret_en) begin
            mie  <= mpie;
            mpie <= 1'b1;
        end
    end
end

// ---------------- LED debug view ----------------
always @(*) begin
    case (dbg_sel)
        3'd0:    dbg_out = {mepc, 2'b00};
        3'd1:    dbg_out = mcause;
        3'd2:    dbg_out = minstret[31:0];
        3'd3:    dbg_out = mstatus;
        3'd4:    dbg_out = {mtvec, 2'b00};
        3'd5:    dbg_out = mscratch;
        3'd6:    dbg_out = mcycle[31:0];
        default: dbg_out = mtval;
    endcase
end

endmodule
