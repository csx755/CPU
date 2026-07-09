#!/usr/bin/env python3
"""Generate CSR + MRET test .dat file for Phase 1 verification."""

CSR_MSTATUS = 0x300
CSR_MTVEC   = 0x305
CSR_MEPC    = 0x341
CSR_MCAUSE  = 0x342

def csrrw(rd, csr, rs1):
    """CSRRW rd, csr, rs1"""
    return (csr << 20) | (rs1 << 15) | (1 << 12) | (rd << 7) | 0x73

def csrrs(rd, csr, rs1):
    """CSRRS rd, csr, rs1"""
    return (csr << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x73

def addi(rd, rs1, imm):
    """ADDI rd, rs1, imm (12-bit signed)"""
    return (imm & 0xFFF) << 20 | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13

def sw(rs2, rs1, offset):
    """SW rs2, offset(rs1)"""
    imm = offset & 0xFFF
    return (imm << 20) | (rs1 << 15) | (2 << 12) | (rs2 << 20) | (3 << 7) | 0x23
    # S-type: imm[11:5] at [31:25], rs2 at [24:20], rs1 at [19:15], f3 at [14:12], imm[4:0] at [11:7], op at [6:0]

def sw_re(rs2, rs1, offset):
    """SW rs2, offset(rs1) — correct encoding"""
    imm = offset & 0xFFF
    imm_11_5 = (imm >> 5) & 0x7F
    imm_4_0  = imm & 0x1F
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | (imm_4_0 << 7) | 0x23

def jal(rd, offset):
    """JAL rd, offset"""
    # UJ-type encoding
    imm = offset & 0x1FFFFE  # 21-bit signed, bit[0]=0
    b20    = (imm >> 20) & 1
    b10_1  = (imm >> 1)  & 0x3FF
    b11    = (imm >> 11) & 1
    b19_12 = (imm >> 12) & 0xFF
    return (b20 << 31) | (b10_1 << 21) | (b11 << 20) | (b19_12 << 12) | (rd << 7) | 0x6F

def mret():
    """MRET instruction"""
    return 0x30200073

def lui(rd, imm):
    """LUI rd, imm[31:12]"""
    return (imm & 0xFFFFF000) | (rd << 7) | 0x37

def addi_li(rd, imm):
    """Load immediate: LUI + ADDI sequence.
    Returns tuple of (lui_instr, addi_instr).
    Actually simpler: just use LUI for upper 20 bits, ADDI for lower 12.
    """
    upper = (imm >> 12) & 0xFFFFF
    lower = imm & 0xFFF
    # If lower has sign bit set, increment upper (ADDI sign-extends)
    if lower & 0x800:
        upper = (upper + 1) & 0xFFFFF
    lui_instr  = (upper << 12) | (rd << 7) | 0x37
    addi_instr = (lower & 0xFFF) << 20 | (rd << 15) | (0 << 12) | (rd << 7) | 0x13
    return lui_instr, addi_instr

def load32(rd, val):
    """Load 32-bit immediate into rd. Returns list of instructions."""
    instrs = []
    # Check if value fits in 12-bit signed
    if -2048 <= val < 2048:
        instrs.append(addi(rd, 0, val))
        return instrs
    # LUI + ADDI pair
    upper = (val >> 12) & 0xFFFFF
    lower = val & 0xFFF
    # ADDI sign-extends: if lower has bit 11=1, upper needs +1
    if lower & 0x800:
        upper = (upper + 1) & 0xFFFFF
    if upper != 0:
        instrs.append(lui(rd, upper << 12))
    if lower != 0 or upper == 0:
        instrs.append(addi(rd, rd if upper else 0, lower))
    return instrs

# ============================================================
# Test program
# ============================================================
prog = []

# Test 1: CSRRW read mcause (should be 0)
prog.append(csrrw(1, CSR_MCAUSE, 0))          # x1 = mcause

# Test 2: li x2, 0x8 (MIE=1)
prog.extend(load32(2, 0x8))

# Test 3: CSRRW x3, mstatus, x2 → write mstatus=0x8, read old=0
prog.append(csrrw(3, CSR_MSTATUS, 2))          # x3 = old mstatus, mstatus = x2=8

# Test 4: CSRRW x4, mstatus, x0 → read mstatus (should be 8), no write (rs1=x0 in spec?)
# In our impl: csr_do_write = (rs1 != 0), so rs1=0 → read-only
# But we still capture the old value in x4
prog.append(csrrw(4, CSR_MSTATUS, 0))          # x4 = mstatus = 8

# Test 5: Write mepc
prog.extend(load32(5, 0x100))
prog.append(csrrw(0, CSR_MEPC, 5))             # mepc = 0x100 (rd=x0: write-only)
prog.append(csrrw(6, CSR_MEPC, 0))             # x6 = mepc = 0x100

# Test 6: Write mtvec
prog.extend(load32(7, 0x200))
prog.append(csrrw(0, CSR_MTVEC, 7))            # mtvec = 0x200
prog.append(csrrw(8, CSR_MTVEC, 0))            # x8 = mtvec = 0x200

# Store results to DM[0..16]
prog.append(sw_re(1, 0, 0))                    # DM[0]  = x1 (mcause → 0)
prog.append(sw_re(3, 0, 4))                    # DM[4]  = x3 (old mstatus → 0)
prog.append(sw_re(4, 0, 8))                    # DM[8]  = x4 (mstatus → 8)
prog.append(sw_re(6, 0, 12))                   # DM[12] = x6 (mepc → 0x100)
prog.append(sw_re(8, 0, 16))                   # DM[16] = x8 (mtvec → 0x200)

# Test 7: MRET
# Load mret_target address into x9
# mret_target will be at a specific address in the program
# Count current instructions to get the target address
mret_target_addr = len(prog) * 4  # bytes from start
# We need to add 2 more instructions before the target:
#   la x9, mret_target (2 instructions: lui + addi)
#   mret
# After mret we'll have the skipped instruction and then the target

# Let me recalculate more carefully
base = len(prog)  # current instruction count = 15 or so
# After these SW instructions:
#   lui + addi for x9 = 2 instructions
#   csrrw to set mepc = 1 instruction
#   mret = 1 instruction
#   skipped li x10, 0xBAD (2 instructions) = total in "skipped" block
#   mret_target label: li x10, 0x1234 (2 instructions)
#   sw x10, 20(x0) (1 instruction)
# So: base + 2 + 1 + 1 = base + 4 for mret, then + 4 for skipped, target at base + 4 + 4 = base + 8

# Actually let me just calculate the absolute address
# The testbench will load this at PC=0
# base_prog_end = len(prog) * 4  (address after existing instructions)
# Then: la x9 → 2 instructions → +8 bytes
#       csrrw → 1 instruction  → +4 bytes
#       mret  → 1 instruction  → +4 bytes
#       skip  → 2 instructions → +8 bytes (0xBAD)
#       target: at +8 from mret → base_prog_end + 24

target_offset = 20  # bytes: la(1) + csrrw(1) + mret(1) + skipped(2) = 5 instrs = 20 bytes
prog.extend(load32(9, (len(prog) * 4) + target_offset))
prog.append(csrrw(0, CSR_MEPC, 9))             # mepc = mret_target address
prog.append(mret())                             # jump to mret_target
# These should be skipped:
prog.extend(load32(10, 0xBAD))                 # x10 = 0xBAD (should be skipped)
# mret_target:
prog.extend(load32(10, 0x1234))                # x10 = 0x1234
prog.append(sw_re(10, 0, 20))                   # DM[20] = x10 = 0x1234

# End: infinite loop to allow verification
# jal x0, 0 (jump to self)
prog.append(jal(0, 0))

# ============================================================
# Write .dat file
# ============================================================
print(f"Generated {len(prog)} instructions")
for i, instr in enumerate(prog):
    print(f"  [{i*4:03X}] = {instr:08X}")

import os
out_path = os.path.join(os.path.dirname(__file__), "csr_test.dat")
with open(out_path, "w") as f:
    for instr in prog:
        f.write(f"{instr:08X}\n")

print(f"\nWrote {len(prog)} words to csr_test.dat")
print("Expected results:")
print(f"  DM[0x00] = 0x00000000 (mcause reset)")
print(f"  DM[0x04] = 0x00000000 (old mstatus)")
print(f"  DM[0x08] = 0x00000008 (mstatus after write)")
print(f"  DM[0x0C] = 0x00000100 (mepc)")
print(f"  DM[0x10] = 0x00000200 (mtvec)")
print(f"  DM[0x14] = 0x00001234 (MRET target reached)")
