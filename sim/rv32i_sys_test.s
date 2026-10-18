# Zicsr / trap test (assembled by gen_sys_test.py; mtvec is set to 0x100)
addi x1, x0, 256                   # 0x000  10000093
csrrw x0, mtvec, 1                 # 0x004  30509073
csrrs x2, mtvec, 0                 # 0x008  30502173
csrrwi x3, mscratch, 21            # 0x00c  340ad1f3
csrrs x4, mscratch, 0              # 0x010  34002273
csrrsi x5, mscratch, 10            # 0x014  340562f3
csrrci x6, mscratch, 5             # 0x018  3402f373
csrrs x7, mscratch, 0              # 0x01c  340023f3
csrrs x8, misa, 0                  # 0x020  30102473
csrrs x9, mstatus, 0               # 0x024  300024f3
csrrsi x0, mstatus, 8              # 0x028  30046073
fence iorw, iorw                   # 0x02c  0ff0000f
fence.i                            # 0x030  0000100f
addi x10, x0, 1                    # 0x034  00100513
ecall                              # 0x038  00000073
addi x11, x0, 2                    # 0x03c  00200593
ebreak                             # 0x040  00100073
addi x12, x0, 3                    # 0x044  00300613
.word 0  (illegal)                 # 0x048  00000000
addi x13, x0, 4                    # 0x04c  00400693
addi x14, x0, 77                   # 0x050  04d00713
csrrw x14, 0x7ff, 0                # 0x054  7ff01773
addi x15, x0, 5                    # 0x058  00500793
addi x16, x0, 99                   # 0x05c  06300813
csrrwi x16, mhartid, 1             # 0x060  f140d873
addi x17, x0, 55                   # 0x064  03700893
csrrs x17, mhartid, 0              # 0x068  f14028f3
csrrs x18, mstatus, 0              # 0x06c  30002973
csrrs x19, instret, 0              # 0x070  c02029f3
csrrs x26, mcycle, 0               # 0x074  b0002d73
add x25, x20, x0                   # 0x078  000a0cb3
jal x0, done                       # 0x07c  0000006f
addi x20, x20, 1                   # 0x100  001a0a13
csrrs x21, mcause, 0               # 0x104  34202af3
sw x21, 0(x22)                     # 0x108  015b2023
csrrs x23, mepc, 0                 # 0x10c  34102bf3
sw x23, 4(x22)                     # 0x110  017b2223
csrrs x24, mstatus, 0              # 0x114  30002c73
sw x24, 8(x22)                     # 0x118  018b2423
addi x22, x22, 12                  # 0x11c  00cb0b13
addi x23, x23, 4                   # 0x120  004b8b93
csrrw x0, mepc, 23                 # 0x124  341b9073
mret                               # 0x128  30200073
