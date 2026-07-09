#!/usr/bin/env python3
"""Generate remaining test programs with correct encodings."""
import os
SIM = "d:/Desktop/study_computer/vivado/code/sim"

def ADDI(rd, rs1, imm): return (imm&0xFFF)<<20 | rs1<<15 | rd<<7 | 0x13
def CSRRW(rd, csr, rs1): return csr<<20 | rs1<<15 | 1<<12 | rd<<7 | 0x73
def CSRRS(rd, csr, rs1): return csr<<20 | rs1<<15 | 2<<12 | rd<<7 | 0x73
def CSRRC(rd, csr, rs1): return csr<<20 | rs1<<15 | 3<<12 | rd<<7 | 0x73
def SW(rs2, rs1, off):
    i = off & 0xFFF; return (i>>5&0x7F)<<25 | rs2<<20 | rs1<<15 | 2<<12 | (i&0x1F)<<7 | 0x23
def LUI(rd, imm20): return (imm20&0xFFFFF)<<12 | rd<<7 | 0x37
def JAL(rd, off):
    i = off & 0x1FFFFE
    return ((i>>20)&1)<<31 | ((i>>1)&0x3FF)<<21 | ((i>>11)&1)<<20 | ((i>>12)&0xFF)<<12 | rd<<7 | 0x6F
def JALR_I(rd, rs1, imm12): return (imm12&0xFFF)<<20 | rs1<<15 | 0<<12 | rd<<7 | 0x67
def LW(rd, rs1, off): return (off&0xFFF)<<20 | rs1<<15 | 2<<12 | rd<<7 | 0x03
def NOP(): return ADDI(0,0,0)

def w(name, instrs, desc=""):
    with open(os.path.join(SIM, name), 'w') as f:
        for i in instrs: f.write(f"{i:08X}\n")
    print(f"  {name}: {len(instrs)} instrs {desc}")

# ===== COR-011: JALR LSB auto-clear =====
# jalr x0, x1, 0 where x1 = 0x21 → should clear LSB and jump to 0x20
# Target at 0x20 = index 8. Indices: 0=ADDI,1=JALR,2=ADDI(0xBAD),3-7=NOPs,8+=target
w("cor_011.dat", [
    ADDI(1, 0, 0x21),          # x1 = 0x21, PC=0x00
    JALR_I(0, 1, 0),           # PC = (0+0x21)&~1 = 0x20, PC=0x04
    ADDI(2, 0, 0xBAD),         # flushed, PC=0x08
    NOP(),NOP(),NOP(),NOP(),NOP(),  # padding indices 3-7 (PC=0x0C..0x1C)
    LUI(2, 1),                 # target at index 8, PC=0x20: x2 = 0x1000
    ADDI(2, 2, 0x234),         # x2 = 0x1234
    SW(2, 0, 0),               # DM[0] = 0x1234
    JAL(0, 4),
], "JALR LSB clear")

# ===== REGR-001: JALR + INT concurrent =====
# JALR in ID when INT fires: INT should win, JALR flushed
w("regr_001.dat", [
    ADDI(1, 0, 24),            # x1 = 24 = 0x18 (mtvec)
    CSRRW(0, 0x305, 1),        # mtvec = 0x18
    ADDI(2, 0, 8),
    CSRRW(0, 0x300, 2),        # MIE=1
    ADDI(1, 0, 0x30),          # x1 = 0x30 (JALR target)
    JALR_I(0, 1, 0),           # jalr x0, 0(x1) → TB fires INT here
    ADDI(2, 0, 0xBAD),
    # handler at 0x18
    CSRRW(5, 0x342, 0),        # x5 = mcause
    SW(5, 0, 0x28),            # DM[10] = mcause
    0x30200073,                # mret
    # JALR target at 0x30 (never reached if INT fires)
    ADDI(2, 0, 0x1234),
    SW(2, 0, 0),               # DM[0] = 0x1234 (if JALR succeeds, bad)
    JAL(0, 4),
], "JALR+INT concurrent")

# ===== REGR-002: CSR Forward =====
# Same as CSR-003 but explicitly for regression
w("regr_002.dat", [
    ADDI(1, 0, 8),
    CSRRW(0, 0x300, 1),        # mstatus = 8
    CSRRW(2, 0x300, 0),        # x2 = mstatus (should be 8 via forward)
    SW(2, 0, 0),               # DM[0] = 8
    JAL(0, 4),
], "CSR Forward regression")

# ===== COR-009: INT sustained high =====
# INT stays high for 100 cycles, verify only 1 accept during handler
w("cor_009.dat", [
    ADDI(1, 0, 20),            # x1 = 20 = 0x14 (mtvec)
    CSRRW(0, 0x305, 1),        # mtvec = 0x14
    ADDI(2, 0, 8),
    CSRRW(0, 0x300, 2),        # MIE=1
    ADDI(3, 0, 0x123),
    SW(3, 0, 0x10),            # DM[4] = 0x123
    JAL(0, -4),                # loop
    # handler at 0x14
    ADDI(5, 0, 0),             # counter = 0
    ADDI(5, 5, 1),             # counter++ (each re-entry)
    SW(5, 0, 0x20),            # DM[8] = entry count
    CSRRW(6, 0x342, 0),        # x6 = mcause
    SW(6, 0, 0x28),            # DM[10] = mcause
    ADDI(3, 3, 1),             # x3++
    0x30200073,                # mret (INT still high → might re-enter)
    JAL(0, 4),
], "INT sustained high")

print("\n=== Done ===")
