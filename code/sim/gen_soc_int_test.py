#!/usr/bin/env python3
"""Generate SoC interrupt test .coe for Vivado ROM IP.
Tests: Counter_x -> INT -> CPU handler -> MRET -> main loop resume.
Avoids JAL link (known bug: rd=0 only for JAL)."""

CSR_MTVEC, CSR_MSTATUS, CSR_MEPC, CSR_MCAUSE = 0x305, 0x300, 0x341, 0x342

def M(op, rd=0, rs1=0, rs2=0, f3=0, f7=0, imm=0):
    """Generic instruction encoder."""
    return (imm << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op

def ADDI(rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (rd << 7) | 0x13

def LUI(rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37

def SW(rs2, rs1, off):
    i = off & 0xFFF
    return ((i>>5&0x7F)<<25) | (rs2<<20) | (rs1<<15) | (2<<12) | ((i&0x1F)<<7) | 0x23

def CSRRW(rd, csr, rs1):
    return (csr << 20) | (rs1 << 15) | (1 << 12) | (rd << 7) | 0x73

def MRET():
    return 0x30200073

def JAL_X0(off):
    """jal x0, offset (unconditional jump, no link)"""
    i = off & 0x1FFFFE
    return ((i>>20&1)<<31) | ((i>>1&0x3FF)<<21) | ((i>>11&1)<<20) | ((i>>12&0xFF)<<12) | 0x6F

def LI(rd, val):
    """Load 32-bit immediate. Returns list of 1 or 2 instructions."""
    v = val & 0xFFFFFFFF
    if v >= 0x80000000: v -= 0x100000000
    if -2048 <= v <= 2047:
        return [ADDI(rd, 0, v & 0xFFF)]
    # LUI + ADDI
    upper = ((v + 0x800) >> 12) & 0xFFFFF
    lower = v - (upper << 12)
    instrs = [LUI(rd, upper)]
    if lower != 0: instrs.append(ADDI(rd, rd, lower & 0xFFF))
    return instrs

prog = []
# ====== REGISTER MAP ======
# x2(sp)=0x800, x5=t0=handler_pc, x6=t1=temp, x7=t2=temp
# x10=a0=0xF0000000 (GPIO base), x11=a1=0xF0000008 (counter)
# x12=a2=LED pattern (loop counter)
# x20=s4=store area base, x21=s5=mcause, x22=s6=mepc
# x24=s8=interrupt count

# ---- Init (0x00) ----
prog.extend(LI(2, 0x800))                       # [0-1] sp = 0x800

# Set mtvec to handler (will fill after knowing handler PC)
HANDLER_IDX_SLOT = len(prog)                     # remember where mtvec setup goes
prog.append(0)                                    # [2] placeholder for LI part 1
prog.append(0)                                    # [3] placeholder for LI part 2
prog.append(CSRRW(0, CSR_MTVEC, 5))              # [4] mtvec = x5

# Enable interrupts
prog.append(ADDI(6, 0, 8))                       # [5] x6 = MIE bit
prog.append(CSRRW(0, CSR_MSTATUS, 6))            # [6] mstatus.MIE = 1

# Pre-interrupt marker
prog.extend(LI(7, 0x1234))                       # [7-8] x7 = 0x1234
prog.append(ADDI(8, 0, 0))                       # [9] x8 = 0
prog.append(SW(7, 8, 0))                         # [10] RAM[0] = 0x1234

# GPIO + Counter setup
prog.extend(LI(10, 0xF0000000))                  # [11] x10 = GPIO base (LUI only)
prog.append(ADDI(11, 10, 8))                     # [12] x11 = 0xF0000008 (counter)
prog.append(ADDI(9, 0, 8))                       # [13] x9 = 8 (fast counter val)
prog.append(SW(9, 11, 0))                        # [14] Counter0 = 8 -> INT in ~10us

# LED pattern init
prog.extend(LI(12, 0xAA00))                      # [15-16] x12 = 0xAA00

# ---- Main Loop ----
MAIN_LOOP = len(prog) * 4
prog.append(SW(12, 10, 0))                       # [17] LED = x12
prog.append(ADDI(12, 12, 0x10))                  # [18] x12 += 0x10
prog.append(SW(12, 10, 4))                       # [19] LED+4 = x12 (pattern++)
prog.extend(LI(13, 0xE0000000))                  # [20] x13 = 0xE0000000 (display)
prog.append(SW(12, 13, 0))                       # [21] Disp = x12
prog.append(SW(12, 8, 4))                        # [22] RAM[1] = x12 (heartbeat)
off = MAIN_LOOP - len(prog) * 4
prog.append(JAL_X0(off))                         # [23] loop forever

# ---- Handler (pad to next 8-instr boundary) ----
while len(prog) % 8 != 0:
    prog.append(ADDI(0, 0, 0))                   # NOP padding
# prog = 24 instrs at this point (divisible by 8)
HANDLER_PC = len(prog) * 4                        # = 0x60

# ---- Now fill mtvec setup ----
li_handler = LI(5, HANDLER_PC)                    # x5 = handler PC
prog[HANDLER_IDX_SLOT] = li_handler[0]
prog[HANDLER_IDX_SLOT + 1] = li_handler[1] if len(li_handler) > 1 else ADDI(5, 0, HANDLER_PC)

# ---- Handler (at HANDLER_PC) ----
prog.extend(LI(20, 0x20))                        # x20 = RAM save base

# Save mcause to RAM[8]
prog.append(CSRRW(21, CSR_MCAUSE, 0))            # x21 = mcause
prog.append(SW(21, 20, 0))                       # RAM[8] = mcause

# Save mepc to RAM[9]
prog.append(CSRRW(22, CSR_MEPC, 0))              # x22 = mepc
prog.append(SW(22, 20, 4))                       # RAM[9] = mepc

# Increment interrupt count -> RAM[0x30]
prog.extend(LI(23, 0x30))
prog.append(ADDI(24, 24, 1))                     # x24++ (starts at 0)
prog.append(SW(24, 23, 0))                       # RAM[12] = int count

# LED interrupt indicator
prog.extend(LI(25, 0xBEEF))
prog.append(SW(25, 10, 0))                       # LED = 0xBEEF

# Display interrupt indicator
prog.append(SW(25, 13, 0))                       # Disp = 0xBEEF

# Reload counter to clear INT (longer period for next)
prog.extend(LI(26, 80))                          # ~100us
prog.append(SW(26, 11, 0))                       # Counter0 = 80

# MRET
prog.append(MRET())

# Safety net
prog.append(JAL_X0(0))

# ==== Write .coe ====
import os
out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "soc_int_test.coe")
with open(out_path, "w") as f:
    f.write("memory_initialization_radix=16;\nmemory_initialization_vector=\n")
    for i, inst in enumerate(prog):
        comma = "," if i < len(prog) - 1 else ";"
        f.write(f"{inst:08X}{comma}\n")

print(f"Total: {len(prog)} instructions, Handler at PC=0x{HANDLER_PC:03X}")
for i, inst in enumerate(prog):
    tag = ""
    if i * 4 == HANDLER_PC: tag = " <<< HANDLER"
    elif i * 4 == MAIN_LOOP: tag = " <<< MAIN_LOOP"
    print(f"  [{i*4:03X}] {inst:08X}{tag}")
