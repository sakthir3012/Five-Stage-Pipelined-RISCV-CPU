`timescale 1ns/1ns
// tb_system.v - self-checking test of fence/fence.i, Zicsr, ecall, ebreak, mret,
// illegal-instruction traps and CSR access checks.  Program: sim/rv32i_sys_test.mem
// (generated with an assembler + reference model; expected values come from that model).
module tb_system;
reg clk = 0, reset = 1;
always #5 clk = ~clk;

wire [31:0] WriteData, DataAdr, ReadData, PCW, Result, ALUResultW, WriteDataW, DbgOut;
wire MemWrite;

pl_riscv_cpu #(.INIT_FILE("rv32i_sys_test.mem")) uut (
    .clk(clk), .reset(reset),
    .Ext_MemWrite(1'b0), .Ext_WriteData(32'b0), .Ext_DataAdr(32'b0),
    .MemWrite(MemWrite), .WriteData(WriteData), .DataAdr(DataAdr), .ReadData(ReadData),
    .PCW(PCW), .Result(Result), .ALUResultW(ALUResultW), .WriteDataW(WriteDataW),
    .DbgSel(3'd0), .DbgOut(DbgOut)
);

integer errors = 0, t = 0;
localparam DONE_PC = 32'h7c;

task check_reg(input integer r, input [31:0] exp);
    reg [31:0] got;
    begin
        got = uut.rvcpu.dp.rf.bank1[r];
        if (got !== exp) begin
            $display("FAIL x%0d = %h, expected %h", r, got, exp);
            errors = errors + 1;
        end else $display("ok   x%0d = %h", r, got);
    end
endtask

task check_mem(input integer w, input [31:0] exp);
    reg [31:0] got;
    begin
        got = {uut.datamem.lane3[w], uut.datamem.lane2[w], uut.datamem.lane1[w], uut.datamem.lane0[w]};
        if (got !== exp) begin
            $display("FAIL trap-log[%0d] = %h, expected %h", w, got, exp);
            errors = errors + 1;
        end else $display("ok   trap-log[%0d] = %h", w, got);
    end
endtask

initial begin #12 reset = 0; end

always @(negedge clk) begin
    t = t + 1;
    if (PCW === DONE_PC) begin
        #20;   // let the last writes land
        $display("--- program reached its final jal, checking results ---");
    check_reg(1, 32'h00000100);
    check_reg(2, 32'h00000100);
    check_reg(3, 32'h00000000);
    check_reg(4, 32'h00000015);
    check_reg(5, 32'h00000015);
    check_reg(6, 32'h0000001f);
    check_reg(7, 32'h0000001a);
    check_reg(8, 32'h40000100);
    check_reg(9, 32'h00001800);
    check_reg(10, 32'h00000001);
    check_reg(11, 32'h00000002);
    check_reg(12, 32'h00000003);
    check_reg(13, 32'h00000004);
    check_reg(14, 32'h0000004d);
    check_reg(15, 32'h00000005);
    check_reg(16, 32'h00000063);
    check_reg(17, 32'h00000000);
    check_reg(18, 32'h00001888);
    check_reg(20, 32'h00000005);
    check_reg(22, 32'h0000003c);
    check_reg(25, 32'h00000005);
    check_mem(0, 32'h0000000b);
    check_mem(1, 32'h00000038);
    check_mem(2, 32'h00001880);
    check_mem(3, 32'h00000003);
    check_mem(4, 32'h00000040);
    check_mem(5, 32'h00001880);
    check_mem(6, 32'h00000002);
    check_mem(7, 32'h00000048);
    check_mem(8, 32'h00001880);
    check_mem(9, 32'h00000002);
    check_mem(10, 32'h00000054);
    check_mem(11, 32'h00001880);
    check_mem(12, 32'h00000002);
    check_mem(13, 32'h00000060);
    check_mem(14, 32'h00001880);
        if (uut.rvcpu.dp.rf.bank1[19] == 0) begin $display("FAIL instret is zero"); errors = errors + 1; end
        if (uut.rvcpu.dp.rf.bank1[26] == 0) begin $display("FAIL mcycle is zero");  errors = errors + 1; end
        if (errors == 0) $display("SYSTEM TEST PASSED: Zicsr, ecall, ebreak, mret, fence, illegal-instruction traps all correct");
        else             $display("SYSTEM TEST FAILED: %0d error(s)", errors);
        $finish;
    end
    if (t > 3000) begin $display("TIMEOUT: program never reached its final jal"); $finish; end
end
endmodule
