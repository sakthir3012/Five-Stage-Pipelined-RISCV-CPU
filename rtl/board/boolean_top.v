`timescale 1ns/1ns
// boolean_top.v - RealDigital Boolean Board (Spartan-7 XC7S50) wrapper for pl_riscv_cpu
//
// Board controls
//   btn[0]      : RESET (hold; also auto-reset at power-up)
//   btn[1]      : STEP  (one CPU clock per press, when sw[15] = 0)
//   sw[15]      : 1 = free-run, 0 = single-step with btn[1]
//   sw[14:13]   : run speed  00 ~3 Hz | 01 ~48 Hz | 1x full speed (6.25 MHz)
//   sw[3]       : 0 = pipeline view (below), 1 = CSR view (below)
//   sw[4]       : 0 = show bits [15:0], 1 = show bits [31:16] (CSR view only)
//   sw[2:0]     : what the 16 LEDs show
//                 000 PCW[15:0]        (PC of the instruction in Writeback)
//                 001 Result[15:0]     (value being written back)
//                 010 Result[31:16]
//                 011 ALUResultW[15:0]
//                 100 ALUResultW[31:16]
//                 101 WriteDataW[15:0]
//                 110 ReadData[15:0]   (data memory output)
//                 111 cycle counter    (CPU clocks since reset)
//               CSR view (sw[3]=1):
//                 000 mepc   001 mcause   010 minstret   011 mstatus
//                 100 mtvec  101 mscratch 110 mcycle     111 mtval
//
// The CPU is clocked through a BUFGCE so it only ticks when `ce` is high.
// A hold-off counter guarantees >= 16 board clocks (100 MHz) between CPU clock edges.

module boolean_top #(parameter PROGRAM = "rv32i_test.mem") (
    input         clk,           // 100 MHz
    input  [15:0] sw,
    input  [ 3:0] btn,
    output reg [15:0] led
);

// ---------------- reset: button + power-up, stretched ----------------
reg [1:0] rst_sync = 2'b11;
always @(posedge clk) rst_sync <= {rst_sync[0], btn[0]};

reg [5:0] rst_cnt = 6'd40;               // non-zero at power-up -> starts in reset
always @(posedge clk) begin
    if (rst_sync[1])         rst_cnt <= 6'd40;
    else if (rst_cnt != 6'd0) rst_cnt <= rst_cnt - 6'd1;
end

reg reset_r = 1'b1;
always @(posedge clk) reset_r <= (rst_cnt != 6'd0);

// ---------------- debounced single-step button ----------------
reg [1:0]  b1_sync = 2'b00;
reg [19:0] b1_cnt  = 20'd0;              // ~10 ms
reg        b1_stable = 1'b0, b1_prev = 1'b0;
always @(posedge clk) begin
    b1_sync <= {b1_sync[0], btn[1]};
    if (b1_sync[1] == b1_stable) b1_cnt <= 20'd0;
    else begin
        b1_cnt <= b1_cnt + 20'd1;
        if (&b1_cnt) b1_stable <= b1_sync[1];
    end
    b1_prev <= b1_stable;
end
wire step_pulse = b1_stable & ~b1_prev;

// ---------------- free-run ticks ----------------
reg [24:0] tick_cnt = 25'd0;
always @(posedge clk) tick_cnt <= tick_cnt + 25'd1;

wire slow_tick = &tick_cnt;              // 2^25 clocks ~ 0.34 s
wire med_tick  = &tick_cnt[20:0];        // 2^21 clocks ~ 21 ms
// sw[14:13]: 00 slow, 01 medium, 10/11 full speed
wire run_tick_sel = (sw[14:13] == 2'b00) ? slow_tick :
                    (sw[14:13] == 2'b01) ? med_tick  : 1'b1;

wire ce_raw = reset_r | (sw[15] ? run_tick_sel : step_pulse);

// ---------------- hold-off: at least 16 clocks between CPU edges ----------------
reg [3:0] hold = 4'd0;
reg       ce   = 1'b0;
always @(posedge clk) begin
    ce <= 1'b0;
    if (hold != 4'd0) hold <= hold - 4'd1;
    else if (ce_raw) begin
        ce   <= 1'b1;
        hold <= 4'd15;
    end
end

wire cpu_clk;
BUFGCE u_cpu_gate (.I(clk), .CE(ce), .O(cpu_clk));

// ---------------- the processor ----------------
wire [31:0] pcw, res, aluw, wdw, rd;

wire [31:0] dbg;

pl_riscv_cpu #(.INIT_FILE(PROGRAM)) u_core (
    .clk(cpu_clk), .reset(reset_r),
    .Ext_MemWrite(1'b0), .Ext_WriteData(32'b0), .Ext_DataAdr(32'b0),
    .MemWrite(), .WriteData(), .DataAdr(), .ReadData(rd),
    .PCW(pcw), .Result(res), .ALUResultW(aluw), .WriteDataW(wdw),
    .DbgSel(sw[2:0]), .DbgOut(dbg)
);

reg [15:0] cyc = 16'd0;
always @(posedge cpu_clk) begin
    if (reset_r) cyc <= 16'd0;
    else         cyc <= cyc + 16'd1;
end

// ---------------- LED display ----------------
always @(*) begin
    if (sw[3]) led = sw[4] ? dbg[31:16] : dbg[15:0];
    else case (sw[2:0])
        3'd0:    led = pcw[15:0];
        3'd1:    led = res[15:0];
        3'd2:    led = res[31:16];
        3'd3:    led = aluw[15:0];
        3'd4:    led = aluw[31:16];
        3'd5:    led = wdw[15:0];
        3'd6:    led = rd[15:0];
        default: led = cyc;
    endcase
end

endmodule
