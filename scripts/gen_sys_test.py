import sys, re
OUT = sys.argv[1]            # project root
CSR = dict(mstatus=0x300, misa=0x301, mtvec=0x305, mscratch=0x340, mepc=0x341, mcause=0x342,
           instret=0xC02, mcycle=0xB00, mhartid=0xF14)
def R(op,f7,rs2,rs1,f3,rd): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def I(op,imm,rs1,f3,rd):    return ((imm&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def S(imm,rs2,rs1,f3):      return (((imm>>5)&0x7F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|0x23
def J(rd,off):
    o=off&0x1FFFFF
    return (((o>>20)&1)<<31)|(((o>>1)&0x3FF)<<21)|(((o>>11)&1)<<20)|(((o>>12)&0xFF)<<12)|(rd<<7)|0x6F
prog=[]   # (addr, word, text)
def emit(addr,w,t): prog.append((addr,w&0xFFFFFFFF,t))
a=0
def put(w,t):
    global a; emit(a,w,t); a+=4
def addi(rd,rs,imm): put(I(0x13,imm,rs,0,rd), f"addi x{rd}, x{rs}, {imm}")
def add(rd,a1,b): put(R(0x33,0,b,a1,0,rd), f"add x{rd}, x{a1}, x{b}")
def csr(kind,rd,name,src):
    f3={'rw':1,'rs':2,'rc':3,'rwi':5,'rsi':6,'rci':7}[kind]
    addr=CSR[name] if isinstance(name,str) else name
    put((addr<<20)|(src<<15)|(f3<<12)|(rd<<7)|0x73, f"csr{kind} x{rd}, {name if isinstance(name,str) else hex(name)}, {src}")
def sw(rs2,imm,rs1): put(S(imm,rs2,rs1,2), f"sw x{rs2}, {imm}(x{rs1})")

# ------------------ main program ------------------
addi(1,0,0x100)
csr('rw',0,'mtvec',1)
csr('rs',2,'mtvec',0)          # x2  = 0x100
csr('rwi',3,'mscratch',21)     # x3  = 0
csr('rs',4,'mscratch',0)       # x4  = 21
csr('rsi',5,'mscratch',10)     # x5  = 21, mscratch = 31
csr('rci',6,'mscratch',5)      # x6  = 31, mscratch = 26
csr('rs',7,'mscratch',0)       # x7  = 26
csr('rs',8,'misa',0)           # x8  = 0x40000100
csr('rs',9,'mstatus',0)        # x9  = 0x1800
csr('rsi',0,'mstatus',8)       # MIE = 1
put(0x0FF0000F,"fence iorw, iorw")
put(0x0000100F,"fence.i")
addi(10,0,1)                   # x10 = 1
ECALL_PC=a; put(0x00000073,"ecall")            # trap 1, cause 11
addi(11,0,2)                   # x11 = 2
EBREAK_PC=a; put(0x00100073,"ebreak")          # trap 2, cause 3
addi(12,0,3)                   # x12 = 3
ILL1_PC=a; put(0x00000000,".word 0  (illegal)") # trap 3, cause 2
addi(13,0,4)                   # x13 = 4
addi(14,0,77)
BADCSR_PC=a; csr('rw',14,0x7FF,0)              # trap 4, x14 must stay 77
addi(15,0,5)                   # x15 = 5
addi(16,0,99)
ROW_PC=a; csr('rwi',16,'mhartid',1)            # trap 5 (write to read-only), x16 stays 99
addi(17,0,55)
csr('rs',17,'mhartid',0)       # legal read -> x17 = 0
csr('rs',18,'mstatus',0)       # x18 = 0x1888 (MIE=1, MPIE=1 after mrets)
csr('rs',19,'instret',0)       # x19 > 0
csr('rs',26,'mcycle',0)        # x26 > 0
add(25,20,0)                   # x25 = trap count = 5
DONE_PC=a; put(J(0,0),"jal x0, done")
assert a < 0x100
# ------------------ trap handler @0x100 ------------------
a=0x100
addi(20,20,1)
csr('rs',21,'mcause',0)
sw(21,0,22)
csr('rs',23,'mepc',0)
sw(23,4,22)
csr('rs',24,'mstatus',0)
sw(24,8,22)
addi(22,22,12)
addi(23,23,4)
csr('rw',0,'mepc',23)
put(0x30200073,"mret")

# ------------------ write .mem ------------------
words={}
for ad,w,t in prog: words[ad//4]=w
n=max(words)+1
with open(f"{OUT}/sim/rv32i_sys_test.mem","w") as f:
    for i in range(n): f.write(f"{words.get(i,0):08x}\n")
with open(f"{OUT}/sim/rv32i_sys_test.s","w") as f:
    f.write("# Zicsr / trap test (assembled by gen_sys_test.py; mtvec is set to 0x100)\n")
    for ad,w,t in prog: f.write(f"{t:<34} # 0x{ad:03x}  {w:08x}\n")

# ------------------ reference model (ISS) ------------------
regs=[0]*32; pc=0; mem={}
st=dict(mtvec=0x400, mepc=0, mcause=0, mscratch=0, mie=0, mpie=0, instret=0)
code={ad:w for ad,w,t in prog}
log=[]
def dec_illegal(w): return w==0
def mstatus(): return (3<<11)|(st['mpie']<<7)|(st['mie']<<3)
def csr_read(addr):
    m={0x300:mstatus(),0x301:0x40000100,0x305:st['mtvec'],0x340:st['mscratch'],0x341:st['mepc'],0x342:st['mcause'],
       0xC02:st['instret'],0xB00:1,0xF14:0}
    return m.get(addr)
steps=0
while True:
    steps+=1; assert steps<5000
    w=code.get(pc,0)
    op=w&0x7F; rd=(w>>7)&31; f3=(w>>12)&7; rs1=(w>>15)&31; rs2=(w>>20)&31; imm=(w>>20)
    def trap(cause):
        global pc
        st['mepc']=pc; st['mcause']=cause; st['mpie']=st['mie']; st['mie']=0; pc=st['mtvec']
    if w==0: trap(2); continue
    if w==0x73: trap(11); continue
    if w==0x00100073: trap(3); continue
    if w==0x30200073: st['mie']=st['mpie']; st['mpie']=1; pc=st['mepc']; st['instret']+=1; continue
    if op==0x13 and f3==0:
        v=(regs[rs1]+((imm^0x800)-0x800))&0xFFFFFFFF
        if rd: regs[rd]=v
    elif op==0x33 and f3==0:
        v=(regs[rs1]+regs[rs2])&0xFFFFFFFF
        if rd: regs[rd]=v
    elif op==0x23:
        o=(((w>>25)<<5)|((w>>7)&31)); o=(o^0x800)-0x800
        mem[((regs[rs1]+o)&0xFFFFFFFF)//4]=regs[rs2]
    elif op==0x0F: pass
    elif op==0x6F:
        if w==J(0,0): break
    elif op==0x73:
        addr=imm; old=csr_read(addr)
        write = (f3&3)==1 or rs1!=0
        ro = (addr>>10)==3
        if old is None or (write and ro): trap(2); continue
        src = rs1 if f3&4 else regs[rs1]
        k=f3&3
        new = src if k==1 else (old|src) if k==2 else (old&~src)&0xFFFFFFFF
        if rd: regs[rd]=old
        if write:
            if addr==0x300: st['mie']=(new>>3)&1; st['mpie']=(new>>7)&1
            elif addr==0x305: st['mtvec']=new&~3
            elif addr==0x340: st['mscratch']=new
            elif addr==0x341: st['mepc']=new&~3
            elif addr==0x342: st['mcause']=new
    else: raise Exception(hex(w))
    st['instret']+=1; pc+=4
exp_regs={i:regs[i] for i in (1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,20,22,25)}
print("ISS regs:",{k:hex(v) for k,v in exp_regs.items()})
nlog=exp_regs[20]*3
exp_mem=[mem[i] for i in range(nlog)]
print("ISS log:",[hex(x) for x in exp_mem])

# ------------------ testbench ------------------
lines=[]
for r,v in exp_regs.items(): lines.append(f"    check_reg({r}, 32'h{v:08x});")
for i,v in enumerate(exp_mem): lines.append(f"    check_mem({i}, 32'h{v:08x});")
tb=f"""`timescale 1ns/1ns
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
localparam DONE_PC = 32'h{DONE_PC:x};

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
        got = {{uut.datamem.lane3[w], uut.datamem.lane2[w], uut.datamem.lane1[w], uut.datamem.lane0[w]}};
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
{chr(10).join(lines)}
        if (uut.rvcpu.dp.rf.bank1[19] == 0) begin $display("FAIL instret is zero"); errors = errors + 1; end
        if (uut.rvcpu.dp.rf.bank1[26] == 0) begin $display("FAIL mcycle is zero");  errors = errors + 1; end
        if (errors == 0) $display("SYSTEM TEST PASSED: Zicsr, ecall, ebreak, mret, fence, illegal-instruction traps all correct");
        else             $display("SYSTEM TEST FAILED: %0d error(s)", errors);
        $finish;
    end
    if (t > 3000) begin $display("TIMEOUT: program never reached its final jal"); $finish; end
end
endmodule
"""
open(f"{OUT}/sim/tb_system.v","w").write(tb)
print("DONE_PC",hex(DONE_PC), "words", n)
