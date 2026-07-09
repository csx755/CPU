#!/usr/bin/env python3
"""Test program generator with address tracking."""
import os, json
SIM = os.path.dirname(os.path.abspath(__file__))

class Asm:
    def __init__(self):
        self.words = []  # list of ints
        self.labels = {}  # name -> address (byte)

    def emit(self, val, label=None):
        if isinstance(val, str): val = int(val, 16)
        if label: self.labels[label] = len(self.words) * 4
        self.words.append(val)

    def addi(self, rd, rs1, imm, label=None):
        self.emit(((imm&0xFFF)<<20)|(rs1<<15)|(rd<<7)|0x13, label)
    def csrrw(self, rd, csr, rs1, label=None):
        self.emit((csr<<20)|(rs1<<15)|(1<<12)|(rd<<7)|0x73, label)
    def csrrs(self, rd, csr, rs1, label=None):
        self.emit((csr<<20)|(rs1<<15)|(2<<12)|(rd<<7)|0x73, label)
    def csrrc(self, rd, csr, rs1, label=None):
        self.emit((csr<<20)|(rs1<<15)|(3<<12)|(rd<<7)|0x73, label)
    def sw(self, rs2, rs1, off, label=None):
        i = off & 0xFFF
        self.emit(((i>>5)&0x7F)<<25|(rs2<<20)|(rs1<<15)|(2<<12)|((i&0x1F)<<7)|0x23, label)
    def lw(self, rd, rs1, off, label=None):
        self.emit(((off&0xFFF)<<20)|(rs1<<15)|(2<<12)|(rd<<7)|0x03, label)
    def lui(self, rd, imm20, label=None):
        self.emit(((imm20&0xFFFFF)<<12)|(rd<<7)|0x37, label)
    def nop(self, label=None): self.addi(0,0,0,label)
    def mret(self, label=None): self.emit(0x30200073, label)
    def jal(self, rd, target_or_offset, label=None):
        # target_or_offset can be label name (str) or raw offset (int)
        if isinstance(target_or_offset, str):
            self._jumps.append(('jal', len(self.words), target_or_offset, rd))
            self.emit(0, label)  # placeholder
        else:
            self.emit(self._jal_instr(rd, target_or_offset), label)
    def _jal_instr(self, rd, off):
        imm = off & 0x1FFFFE
        return ( ((imm>>20)&1)<<31 | ((imm>>1)&0x3FF)<<21 | ((imm>>11)&1)<<20 |
                 ((imm>>12)&0xFF)<<12 | (rd<<7) | 0x6F )

    def write(self, name):
        # Resolve jumps to labels
        for typ, idx, target, rd in self._jumps:
            off = self.labels[target] - idx * 4
            self.words[idx] = self._jal_instr(rd, off)
        path = os.path.join(SIM, name)
        with open(path, 'w') as f:
            for w in self.words:
                f.write(f"{w:08X}\n")
        print(f"  {name}: {len(self.words)} words, labels: {list(self.labels.keys())}")

    def __enter__(self): self._jumps = []; return self
    def __exit__(self, *a): pass

    def label_addr(self, name):
        return self.labels[name]

# ==============================================================
print("=== Generating tests ===\n")

# CSR-001
with Asm() as a:
    a.csrrw(1, 0x342, 0)      # x1 = mcause
    a.addi(2, 0, 8)
    a.csrrw(1, 0x300, 2)       # x1=old(0), mstatus=8
    a.csrrw(3, 0x300, 0)       # x3=8
    a.sw(1, 0, 0)
    a.sw(3, 0, 4)
    a.jal(0, 4)                # jump to PC+4 = NOP → halt
a.write("csr_001.dat")

# CSR-003: CSR RAW Hazard
with Asm() as a:
    a.addi(1, 0, 8)
    a.csrrw(0, 0x300, 1)       # mstatus=8
    a.csrrw(2, 0x300, 0)       # x2=8
    a.sw(2, 0, 0)
    a.jal(0, 4)
a.write("csr_003.dat")

# MRET-001: MRET jump to target
with Asm() as a:
    a.lui(1, 0x1, "target")    # target label at lui
    a.lui(2, 0)                # placeholder
a.write("tmp.dat")
# simpler: use jal directly to get the offset right
# Actually let me use absolute PC targeting
with Asm() as a:
    a.jal(0, 16)               # jump over → target at PC=16 (0x10)
    a.addi(2, 0, 0xBAD)        # skipped if jal works
    a.addi(1, 0, 0x10)         # x1 = 16 (target addr)
    a.csrrw(0, 0x341, 1)       # mepc = 16
    a.mret()                    # jump to 0x10
    a.addi(2, 0, 0xBAD)        # flushed (at 0x10)
    a.addi(2, 0, 0x1234)       # at 0x14 <- WRONG, 0x10 + 4 = 0x14 but need lui+addi
a.write("mret_001.dat")
# OK, this is also getting wrong. Let me just fix the existing approach for now.

print("\nDone")
