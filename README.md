# Five-Stage Pipelined RISC-V CPU

A Verilog-based five-stage pipelined processor developed in AMD Vivado 2026.1 for the RealDigital Boolean Board (Spartan-7).

The design includes pipeline hazard handling, forwarding, machine-mode CSR operations, and trap handling. The supplied instruction-level and system-level simulation testbenches pass in Vivado.

**Project status:** Instruction-level and system-level simulations passed; bitstream generation completed in AMD Vivado 2026.1. On-board functional validation and complete RV32I compliance have not yet been verified.

## ISA coverage
| Group | Instructions |
|---|---|
| Upper imm / jumps | lui, auipc, jal, jalr |
| Branches | beq, bne, blt, bge, bltu, bgeu |
| Loads / stores | lb, lh, lw, lbu, lhu, sb, sh, sw |
| ALU | addi, slti, sltiu, xori, ori, andi, slli, srli, srai, add, sub, sll, slt, sltu, xor, srl, sra, or, and |
| Memory ordering | fence, fence.i (legal no-ops: single hart, no caches) |
| System | ecall, ebreak, mret, wfi (no-op) |
| Zicsr | csrrw, csrrs, csrrc, csrrwi, csrrsi, csrrci |

Not included: M/A/C extensions, interrupts, user/supervisor modes, misaligned-access traps.

## Machine-mode features
- **Precise traps in the Execute stage**: older instructions finish, younger ones are flushed (like a taken branch),
  `mepc` = address of the trapping instruction, PC <- `mtvec`. `mret` returns to `mepc`.
- **Causes**: 2 illegal instruction, 3 breakpoint (ebreak), 11 ecall from M-mode.
- **Illegal-instruction detection** (`decode_check.v`): unknown opcodes, invalid funct3/funct7, reserved SYSTEM
  encodings. Access to an unimplemented CSR or a write to a read-only CSR also traps. A trapping instruction has
  no side effects (no register write, no store).
- **CSRs** (`csr_unit.v`): mstatus (MIE/MPIE/MPP), misa, mtvec, mscratch, mepc, mcause, mtval,
  mcycle/mcycleh, minstret/minstreth (read/write), cycle/time/instret (+h) read-only shadows,
  mvendorid/marchid/mimpid/mhartid (0).

## Layout
- `rtl/` top (`pl_riscv_cpu.v`), `riscv_cpu.v`, `instr_mem.v`, `data_mem.v`
- `rtl/components/` datapath, controller, ALU, hazard unit, pipeline registers, reg file, **csr_unit**, **decode_check**
- `rtl/board/boolean_top.v` Boolean Board wrapper; `constraints/boolean_board.xdc` pin map (xc7s50csga324-1)
- `sim/tb.v` original 38-check test (`rv32i_test.mem`); `sim/tb_system.v` new test (`rv32i_sys_test.mem`);
  `sim/tb_boolean.v` board-wrapper test
- `scripts/create_project.tcl` builds the project; `scripts/gen_sys_test.py` regenerates the system test
  (mini assembler + reference model that produced the expected values in tb_system.v)

## Simulate
1. `source scripts/create_project.tcl` in the Vivado Tcl console (after `cd` to this folder).
2. Run Simulation > Behavioral. Default top is `tb` (original test): expect `No errors encountered`.
3. System test: in the Tcl console run
   `set_property top tb_system [get_filesets sim_1]` then `launch_simulation`.
   Expect `SYSTEM TEST PASSED ...`. Each register / trap-log check prints `ok` or `FAIL`.

## FPGA Implementation Status

The design targets the RealDigital Boolean Board (Spartan-7). Bitstream generation has been completed using AMD Vivado 2026.1. On-board programming and functional validation are documented separately as pending until verified.

| Control | Function |
|---|---|
| btn[0] | Reset (also auto at power-up) |
| btn[1] | Single step when sw[15]=0 |
| sw[15] | 1 = free-run, 0 = single-step |
| sw[14:13] | Speed: 00 ~3 Hz, 01 ~48 Hz, 1x full speed |
| sw[3]=0, sw[2:0] | Pipeline view: 0 PCW, 1 Result lo, 2 Result hi, 3 ALU lo, 4 ALU hi, 5 WriteData, 6 ReadData, 7 cycle count |
| sw[3]=1, sw[2:0] | CSR view: 0 mepc, 1 mcause, 2 minstret, 3 mstatus, 4 mtvec, 5 mscratch, 6 mcycle, 7 mtval |
| sw[4] | In CSR view: 0 = bits [15:0], 1 = bits [31:16] |

To run the system test on the board change `parameter PROGRAM` in `boolean_top.v` to `"rv32i_sys_test.mem"`.
After it finishes, CSR view mcause (sw[3]=1, sw[2:0]=001) shows 2, mstatus shows 0x1888, mepc shows 0x60.

## Notes
- Instruction memory 512 words (2 KB, PC is 11 bits); data memory 64 words.
- The CPU clock is gated (BUFGCE), edges >= 160 ns apart; the XDC times it as a 100 ns clock.
- `$readmemh` path is relative; if simulation can't find a .mem file copy it to
  `vivado_proj/pl_riscv_cpu.sim/sim_1/behav/xsim/`.
- Unused leftovers kept from the original project: `adder.v`, `branching_unit.v`, `mux4.v`.
