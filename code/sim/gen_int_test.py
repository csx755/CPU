#!/usr/bin/env python3
"""Generate INT test .dat for Phase 3. Tests: INT→mepc/mcause→handler→MRET→return."""

CSR_MSTATUS = 0x300
CSR_MTVEC   = 0x305
CSR_MEPC    = 0x341
CSR_MCAUSE  = 0x342

def csrrw(rd, csr, rs1):
    return (csr << 20) | (rs1 << 15) | (1 << 12) | (rd << 7) | 0x73

def addi(rd, rs1, imm):
    return (imm & 0xFFF) << 20 | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13

def lui(rd, imm20):
    return (imm20 << 12) | (rd << 7) | 0x37

def sw(rs2, rs1, offset):
    imm = offset & 0xFFF
    return ((imm >> 5) & 0x7F) << 25 | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 0x1F) << 7) | 0x23

def jal(rd, offset):
    imm = offset & 0x1FFFFE
    return ((imm >> 20) & 1) << 31 | ((imm >> 1) & 0x3FF) << 21 | ((imm >> 11) & 1) << 20 | ((imm >> 12) & 0xFF) << 12 | (rd << 7) | 0x6F

def load32(rd, val):
    instrs = []
    if -2048 <= val < 2048:
        instrs.append(addi(rd, 0, val))
        return instrs
    upper = (val >> 12) & 0xFFFFF
    lower = val & 0xFFF
    if lower & 0x800:
        upper = (upper + 1) & 0xFFFFF
    instrs.append(lui(rd, upper))
    instrs.append(addi(rd, rd, lower & 0xFFF))
    return instrs

prog = []

# ===== Init: mtvec = handler =====
# Handler will start at index 8 (PC=0x20). We'll pad to reach that.
# First, write init code:
prog.extend(load32(1, 0x20))             # x1 = handler PC (0x20)
prog.append(csrrw(0, CSR_MTVEC, 1))      # mtvec = 0x20

# Enable interrupts
prog.append(addi(2, 0, 0x8))             # x2 = MIE bit
prog.append(csrrw(0, CSR_MSTATUS, 2))    # mstatus.MIE = 1

# Pre-interrupt marker
prog.append(addi(3, 0, 0x123))           # x3 = 0x123
prog.append(sw(3, 0, 0x10))              # DM[0x10] = 0x123

# Loop: wait for interrupt
loop_pc = len(prog) * 4                   # save loop PC for jal target
prog.append(jal(0, -4))                   # infinite loop (jump back to sw)

# ===== Pad to index 8 =====
while len(prog) < 8:
    prog.append(addi(0, 0, 0))

# ===== Handler at index 8 (PC=0x20) =====
handler_pc = len(prog) * 4

# Save x5 (t0), x6 (t1)
prog.append(sw(5, 0, 0x20))              # DM[0x20] = x5
prog.append(sw(6, 0, 0x24))              # DM[0x24] = x6

# Read mcause → x5, store to DM
prog.append(csrrw(5, CSR_MCAUSE, 0))     # x5 = mcause
prog.append(sw(5, 0, 0x28))              # DM[0x28] = mcause

# Read mepc → x6, store to DM
prog.append(csrrw(6, CSR_MEPC, 0))       # x6 = mepc
prog.append(sw(6, 0, 0x2C))              # DM[0x2C] = mepc

# Handler work: increment x3
prog.append(addi(3, 3, 1))               # x3++
prog.append(sw(3, 0, 0x30))              # DM[0x30] = x3 (post-int)

# Restore, MRET
prog.append(0x30200073)                   # mret

# After MRET: infinite loop (safety)
prog.append(jal(0, 0))

# ===== Write =====
import os, sys
out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "int_test.dat")
with open(out_path, "w") as f:
    for instr in prog:
        f.write(f"{instr:08X}\n")

print(f"Generated {len(prog)} instructions, handler at PC=0x{handler_pc:04X}")
for i, instr in enumerate(prog):
    lbl = " ← handler" if i * 4 == handler_pc else ""
    print(f"  [{i*4:03X}] = {instr:08X}{lbl}")
print(f"\nExpected: DM[0x10]=0x123, DM[0x28]=0x8000000B, DM[0x30]=0x124")
