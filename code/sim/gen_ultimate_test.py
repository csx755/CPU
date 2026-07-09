#!/usr/bin/env python3
"""生成 RV32I 流水线终极验收测试的 .dat 机器码
地址调整: 基址 0x300→0x040, 暂存区 0x200→0x080, SB区0x400→0x100
"""
from __future__ import annotations

# ==================== 寄存器 ====================
def rn(s):
    if isinstance(s, int): return s & 0x1F
    regs = {'x0':0,'x1':1,'x2':2,'x3':3,'x4':4,'x5':5,'x6':6,'x7':7,
            'x8':8,'x9':9,'x10':10,'x11':11,'x12':12,'x13':13,'x14':14,'x15':15,
            'x16':16,'x17':17,'x18':18,'x19':19,'x20':20,'x21':21,'x22':22,
            'x23':23,'x24':24,'x25':25,'x26':26,'x27':27,'x28':28,'x29':29,
            'x30':30,'x31':31,
            'zero':0,'ra':1,'sp':2,'gp':3,'tp':4,'t0':5,'t1':6,'t2':7,
            's0':8,'s1':9,'a0':10,'a1':11,'a2':12,'a3':13,'a4':14,'a5':15,
            'a6':16,'a7':17,'s2':18,'s3':19,'s4':20,'s5':21,'s6':22,'s7':23,
            's8':24,'s9':25,'s10':26,'s11':27,'t3':28,'t4':29,'t5':30,'t6':31}
    return regs[s.strip().lower()]

# ==================== 指令编码 ====================
def R(f7, rs2, rs1, f3, rd):
    return ((f7 & 0x7F) << 25) | ((rn(rs2) & 0x1F) << 20) | ((rn(rs1) & 0x1F) << 15) | \
           ((f3 & 0x7) << 12) | ((rn(rd) & 0x1F) << 7) | 0b0110011

def I(imm, rs1, f3, rd):
    return ((imm & 0xFFF) << 20) | ((rn(rs1) & 0x1F) << 15) | ((f3 & 0x7) << 12) | \
           ((rn(rd) & 0x1F) << 7) | 0b0010011

def IL(imm, rs1, f3, rd):
    return ((imm & 0xFFF) << 20) | ((rn(rs1) & 0x1F) << 15) | ((f3 & 0x7) << 12) | \
           ((rn(rd) & 0x1F) << 7) | 0b0000011

def S(imm, rs2, rs1, f3):
    i = imm & 0xFFF
    return (((i >> 5) & 0x7F) << 25) | ((rn(rs2) & 0x1F) << 20) | \
           ((rn(rs1) & 0x1F) << 15) | ((f3 & 0x7) << 12) | \
           ((i & 0x1F) << 7) | 0b0100011

def B(off, rs2, rs1, f3):
    """off = signed byte offset from branch PC"""
    b = off & 0x1FFE
    return (((b >> 12) & 1) << 31) | (((b >> 5) & 0x3F) << 25) | \
           ((rn(rs2) & 0x1F) << 20) | ((rn(rs1) & 0x1F) << 15) | \
           ((f3 & 0x7) << 12) | (((b >> 1) & 0xF) << 8) | \
           (((b >> 11) & 1) << 7) | 0b1100011

def U(imm32, rd):
    """imm32 = full 32-bit, bits[31:12] go to instruction"""
    return (imm32 & 0xFFFFF000) | ((rn(rd) & 0x1F) << 7) | 0b0110111

def J(off, rd):
    j = off & 0x1FFFFF
    return (((j >> 20) & 1) << 31) | (((j >> 1) & 0x3FF) << 21) | \
           (((j >> 11) & 1) << 20) | (((j >> 12) & 0xFF) << 12) | \
           ((rn(rd) & 0x1F) << 7) | 0b1101111

def JALR_enc(rs1, rd, imm=0):
    """JALR: I-type format, opcode 0b1100111 (0x67)"""
    return ((imm & 0xFFF) << 20) | ((rn(rs1) & 0x1F) << 15) | \
           (0 << 12) | ((rn(rd) & 0x1F) << 7) | 0b1100111

def NOP():
    return I(0, 0, 0, 0)

# ==================== LI 伪指令 ====================
def li(rd, imm32):
    """返回 list: 1 或 2 条指令"""
    # 转为有符号 int32
    v = imm32 & 0xFFFFFFFF
    if v >= 0x80000000:
        v = v - 0x100000000
    if -2048 <= v <= 2047:
        return [I(v & 0xFFF, 0, 0, rd)]
    # LUI + ADDI
    upper = (v + 0x800) >> 12       # 21-bit but only need 20
    upper_20 = upper & 0xFFFFF
    lui_imm = (upper_20 << 12) & 0xFFFFF000
    lower = v - (upper << 12)       # value contributed by ADDI
    insts = [U(lui_imm, rd)]
    if lower != 0:
        insts.append(I(lower & 0xFFF, rd, 0, rd))
    return insts

# ==================== 汇编器 (两遍) ====================
class Asm:
    def __init__(self):
        self.lines = []   # [(pc, type, *args, comment)]
        self.labels = {}
        self.pc = 0

    def label(self, name):
        self.labels[name] = self.pc

    def _add(self, typ, args, comment):
        self.lines.append((self.pc, typ, args, comment))
        self.pc += 4

    def emit_R(self, f7, rs2, rs1, f3, rd, comment=""):
        self._add('R', (f7, rs2, rs1, f3, rd), comment)

    def emit_I(self, imm, rs1, f3, rd, comment=""):
        self._add('I', (imm, rs1, f3, rd), comment)

    def emit_IL(self, imm, rs1, f3, rd, comment=""):
        self._add('IL', (imm, rs1, f3, rd), comment)

    def emit_S(self, imm, rs2, rs1, f3, comment=""):
        self._add('S', (imm, rs2, rs1, f3), comment)

    def emit_U(self, imm32, rd, comment=""):
        self._add('U', (imm32, rd), comment)

    def emit_JALR(self, rs1, rd, imm=0, comment=""):
        self._add('JALR', (rs1, rd, imm), comment)

    def emit_LI(self, rd, imm, comment=""):
        """li 伪指令, 可能展开为 2 条"""
        insts = li(rd, imm)
        for inst in insts:
            # 直接存编码后的值
            self.lines.append((self.pc, 'RAW', inst, comment))
            self.pc += 4

    def emit_B(self, target, rs2, rs1, f3, comment=""):
        self._add('B', (target, rs2, rs1, f3), comment)

    def emit_J(self, target, rd=0, comment=""):
        self._add('J', (target, rd), comment)

    def NOP(self):
        self._add('RAW', NOP(), "")

    def resolve(self):
        """回填标签, 返回 [(addr, inst32, comment)]"""
        out = []
        for pc, typ, args, comment in self.lines:
            if typ == 'RAW':
                out.append((pc, args, comment))  # args 就是编码后的指令
            elif typ == 'R':
                f7, rs2, rs1, f3, rd = args
                out.append((pc, R(f7, rs2, rs1, f3, rd), comment))
            elif typ == 'I':
                imm, rs1, f3, rd = args
                out.append((pc, I(imm, rs1, f3, rd), comment))
            elif typ == 'IL':
                imm, rs1, f3, rd = args
                out.append((pc, IL(imm, rs1, f3, rd), comment))
            elif typ == 'S':
                imm, rs2, rs1, f3 = args
                out.append((pc, S(imm, rs2, rs1, f3), comment))
            elif typ == 'U':
                imm32, rd = args
                out.append((pc, U(imm32, rd), comment))
            elif typ == 'B':
                target, rs2, rs1, f3 = args
                tgt_pc = self.labels[target]
                off = tgt_pc - pc
                out.append((pc, B(off, rs2, rs1, f3), comment))
            elif typ == 'J':
                target, rd = args
                tgt_pc = self.labels[target]
                off = tgt_pc - pc
                out.append((pc, J(off, rd), comment))
            elif typ == 'JALR':
                rs1, rd, imm = args
                out.append((pc, JALR_enc(rs1, rd, imm), comment))
            else:
                raise ValueError(f"Unknown type: {typ}")
        return out

    def write_dat(self, path, fill_to=1024):
        prog = self.resolve()
        mem = [0x00000013] * fill_to
        for addr, inst, _ in prog:
            idx = addr >> 2
            if idx < fill_to:
                mem[idx] = inst
        with open(path, 'w') as f:
            for inst in mem:
                f.write(f"{inst:08X}\n")
        print(f"[OK] {path}: {len(prog)} instructions (including pseudo), {fill_to} words")
        return prog


# ==================== 测试程序 ====================
def build():
    a = Asm()

    # 基址调整: 0x300→0x040, 0x200→0x080, 0x400→0x100
    BASE = 0x040
    SCR  = 0x080
    SBAREA = 0x100

    # ===== 初始化 =====
    a.emit_LI(31, BASE,           "# x31 = BASE (result area)")

    # ===== 1. 连续前递链 =====
    a.emit_LI(1, 5,               "# x1 = 5")
    a.emit_I(3, 1, 0, 1,          "# addi x1,x1,3 → x1=8")
    a.emit_I(2, 1, 0, 2,          "# addi x2,x1,2 → x2=10")
    a.emit_S(0, 2, 31, 2,         "# DM[BASE+0] = 10")

    # ===== 2. Load-Use 冒险 =====
    a.emit_LI(3, SCR,             "# x3 = SCR")
    a.emit_LI(4, 0x12345678,      "# x4 = 0x12345678")
    a.emit_S(0, 4, 3, 2,          "# sw x4, 0(x3)")
    a.emit_IL(0, 3, 2, 5,         "# lw x5, 0(x3)")
    a.emit_I(1, 5, 0, 5,          "# addi x5,x5,1 → need stall+forward")
    a.emit_S(4, 5, 31, 2,         "# DM[BASE+4] = 0x12345679")

    # ===== 3. Load + Branch 冒险 =====
    a.emit_LI(6, 3,               "# x6 = 3")
    a.emit_S(0, 6, 3, 2,          "# sw x6, 0(x3)")
    a.emit_IL(0, 3, 2, 7,         "# lw x7, 0(x3)")
    a.emit_B('lb_ok', 6, 7, 0,    "# beq x7,x6,lb_ok → TAKEN")
    a.emit_LI(8, 0xBAD,           "# x8=0xBAD (flushed)")
    a.emit_S(8, 8, 31, 2,         "# (flushed)")
    a.emit_J('lb_fail', comment="# j lb_fail")
    a.label('lb_ok')
    a.emit_LI(8, 0x600D,          "# x8 = 0x600D")
    a.emit_S(8, 8, 31, 2,         "# DM[BASE+8] = 0x600D")
    a.label('lb_fail')

    # ===== 4. Forward优先级 (EX/MEM vs MEM/WB) =====
    a.emit_LI(9, 1,               "# x9 = 1")
    a.emit_I(2, 9, 0, 9,          "# addi x9,x9,2 → 3")
    a.emit_I(3, 9, 0, 9,          "# addi x9,x9,3 → 6")
    a.emit_R(0, 0, 9, 0, 10,      "# add x10,x9,x0 → 6")
    a.emit_S(12, 10, 31, 2,       "# DM[BASE+12] = 6")

    # ===== 5. Store 数据前递 =====
    a.emit_LI(11, 1,              "# x11 = 1")
    a.emit_I(2, 11, 0, 11,        "# addi x11,2 → 3")
    a.emit_I(3, 11, 0, 11,        "# addi x11,3 → 6")
    a.emit_S(16, 11, 31, 2,       "# sw x11,16(x31)")
    a.emit_IL(16, 31, 2, 12,      "# lw x12,16(x31)")
    a.emit_S(20, 12, 31, 2,       "# DM[BASE+16]=6, DM[BASE+20]=6")

    # ===== 6. 分支 NOT-taken =====
    # BEQ not-taken: 3==5? false
    a.emit_LI(13, 3)
    a.emit_LI(14, 5)
    a.emit_B('skip0', 14, 13, 0,  "# beq x13,x14,skip0 → NOT taken")
    a.emit_LI(15, 0x100)
    a.emit_S(24, 15, 31, 2,       "# DM[BASE+24]=0x100")
    a.emit_J('next0')
    a.label('skip0')
    a.emit_LI(15, 0x200,          "# (flushed)")
    a.label('next0')

    # BNE taken: 3!=5
    a.emit_B('skip0b', 14, 13, 1, "# bne x13,x14,skip0b → TAKEN")
    a.emit_LI(16, 0x300,          "# (flushed)")
    a.emit_J('next0b', comment="# (flushed)")
    a.label('skip0b')
    a.emit_LI(16, 0x400)
    a.emit_S(28, 16, 31, 2,       "# DM[BASE+28]=0x400")
    a.label('next0b')

    # BNE not-taken: 3!=3? false
    a.emit_LI(13, 3)
    a.emit_B('skip0c', 13, 13, 1, "# bne x13,x13,skip0c → NOT taken")
    a.emit_LI(17, 0x500)
    a.emit_S(32, 17, 31, 2,       "# DM[BASE+32]=0x500")
    a.emit_J('next0c')
    a.label('skip0c')
    a.emit_LI(17, 0x600,          "# (flushed)")
    a.label('next0c')

    # BLT taken: 3<5
    a.emit_LI(13, 3)
    a.emit_LI(14, 5)
    a.emit_B('skip0d', 14, 13, 4, "# blt x13,x14,skip0d → TAKEN")
    a.emit_LI(18, 0x700,          "# (flushed)")
    a.emit_J('next0d', comment="# (flushed)")
    a.label('skip0d')
    a.emit_LI(18, 0x800)
    a.emit_S(36, 18, 31, 2,       "# DM[BASE+36]=0x800")
    a.label('next0d')

    # BLT not-taken: 5<3? false
    a.emit_LI(13, 5)
    a.emit_LI(14, 3)
    a.emit_B('skip0e', 14, 13, 4, "# blt x13,x14,skip0e → NOT taken")
    a.emit_LI(19, 0x900)
    a.emit_S(40, 19, 31, 2,       "# DM[BASE+40]=0x900")
    a.emit_J('next0e')
    a.label('skip0e')
    a.emit_LI(19, 0xA00,          "# (flushed)")
    a.label('next0e')

    # BGE not-taken: 3>=5? false
    a.emit_LI(13, 3)
    a.emit_LI(14, 5)
    a.emit_B('skip1', 14, 13, 5,  "# bge x13,x14,skip1 → NOT taken")
    a.emit_LI(20, 0x111)
    a.emit_S(44, 20, 31, 2,       "# DM[BASE+44]=0x111")
    a.emit_J('next1')
    a.label('skip1')
    a.emit_LI(20, 0x222,          "# (flushed)")
    a.label('next1')

    # BLTU not-taken: 5<1? false
    a.emit_LI(13, 5)
    a.emit_LI(14, 1)
    a.emit_B('skip2', 14, 13, 6,  "# bltu x13,x14,skip2 → NOT taken")
    a.emit_LI(21, 0x333)
    a.emit_S(48, 21, 31, 2,       "# DM[BASE+48]=0x333")
    a.emit_J('next2')
    a.label('skip2')
    a.emit_LI(21, 0x444,          "# (flushed)")
    a.label('next2')

    # BGEU not-taken: 1>=5? false
    a.emit_LI(13, 1)
    a.emit_LI(14, 5)
    a.emit_B('skip3', 14, 13, 7,  "# bgeu x13,x14,skip3 → NOT taken")
    a.emit_LI(22, 0x555)
    a.emit_S(52, 22, 31, 2,       "# DM[BASE+52]=0x555")
    a.emit_J('next3')
    a.label('skip3')
    a.emit_LI(22, 0x666,          "# (flushed)")
    a.label('next3')

    # ===== 7. 分支 TAKEN + Flush =====
    # BEQ x0,x0 always taken
    a.emit_LI(23, 0xBAD)
    a.emit_B('L_taken', 0, 0, 0,  "# beq x0,x0,L_taken → ALWAYS TAKEN")
    a.emit_S(56, 23, 31, 2,       "# (flushed - 0xBAD not stored)")
    a.label('L_taken')
    a.emit_IL(56, 31, 2, 24,      "# lw x24,56(x31) → reads 0")
    a.emit_S(56, 24, 31, 2,       "# DM[BASE+56]=0")

    # BGE taken: 5>=3
    a.emit_LI(13, 5)
    a.emit_LI(14, 3)
    a.emit_B('skip4', 14, 13, 5,  "# bge x13,x14,skip4 → TAKEN")
    a.emit_LI(25, 0x777,          "# (flushed)")
    a.emit_J('next4', comment="# (flushed)")
    a.label('skip4')
    a.emit_LI(25, 0x888)
    a.emit_S(60, 25, 31, 2,       "# DM[BASE+60]=0x888")
    a.label('next4')

    # BLTU taken: 1<5
    a.emit_LI(13, 1)
    a.emit_LI(14, 5)
    a.emit_B('skip5', 14, 13, 6,  "# bltu x13,x14,skip5 → TAKEN")
    a.emit_LI(26, 0x999,          "# (flushed)")
    a.emit_J('next5', comment="# (flushed)")
    a.label('skip5')
    a.emit_LI(26, 0xAAA)
    a.emit_S(64, 26, 31, 2,       "# DM[BASE+64]=0xAAA")
    a.label('next5')

    # BGEU taken: 5>=1
    a.emit_LI(13, 5)
    a.emit_LI(14, 1)
    a.emit_B('skip6', 14, 13, 7,  "# bgeu x13,x14,skip6 → TAKEN")
    a.emit_LI(27, 0xBBB,          "# (flushed)")
    a.emit_J('next6', comment="# (flushed)")
    a.label('skip6')
    a.emit_LI(27, 0xCCC)
    a.emit_S(68, 27, 31, 2,       "# DM[BASE+68]=0xCCC")
    a.label('next6')

    # ===== 8. BEQ taken (真实寄存器比较, 非零相等) =====
    a.emit_LI(1, 0xA5A5)
    a.emit_LI(2, 0xA5A5)
    a.emit_B('beq_taken', 2, 1, 0,"# beq x1,x2,beq_taken → TAKEN (both 0xA5A5)")
    a.emit_LI(3, 0xDEAD,          "# (flushed)")
    a.emit_S(72, 3, 31, 2,        "# (flushed)")
    a.emit_J('beq_done', comment="# (flushed)")
    a.label('beq_taken')
    a.emit_LI(3, 0xBEEF)
    a.emit_S(72, 3, 31, 2,        "# DM[BASE+72]=0xBEEF")
    a.label('beq_done')

    # ===== 9. 双源 Forward (rs1,rs2 同时前递) =====
    a.emit_LI(4, 10)
    a.emit_I(20, 4, 0, 4,         "# addi x4,x4,20 → 30 (EX/MEM)")
    a.emit_I(5, 4, 0, 4,          "# addi x4,x4,5 → 35 (EX/MEM), 旧值30在MEM/WB")
    a.emit_I(0, 4, 0, 5,          "# addi x5,x4,0 → 35 (rs1从EX/MEM转发)")
    a.emit_R(0, 5, 4, 0, 6,       "# add x6,x4,x5 → 70 (rs1,rs2双源转发)")
    a.emit_S(76, 6, 31, 2,        "# DM[BASE+76]=70 (0x46)")

    # ===== 10. 移位量截断 (B[4:0]) =====
    # x28 = 0x80000000, 用 shift=32 → B[4:0]=0 → 不移
    a.emit_LI(28, 0x80000000,     "# x28 = 0x80000000")
    a.emit_LI(29, 32,             "# x29 = 32 → B[4:0] = 0")
    # sll: f7=0x00, f3=0x01
    a.emit_R(0x00, 29, 28, 1, 30, "# sll x30,x28,x29 → 不移 → 0x80000000")
    a.emit_S(80, 30, 31, 2,       "# DM[BASE+80]=0x80000000")
    # srl: f7=0x00, f3=0x05
    a.emit_R(0x00, 29, 28, 5, 30, "# srl x30,x28,x29 → 不移 → 0x80000000")
    a.emit_S(84, 30, 31, 2,       "# DM[BASE+84]=0x80000000")
    # sra: f7=0x20, f3=0x05
    a.emit_R(0x20, 29, 28, 5, 30, "# sra x30,x28,x29 → 不移 → 0x80000000")
    a.emit_S(88, 30, 31, 2,       "# DM[BASE+88]=0x80000000")

    # x29 = 33 → B[4:0] = 1 → 移1位
    a.emit_LI(29, 33,             "# x29 = 33 → B[4:0] = 1")
    a.emit_R(0x00, 29, 28, 1, 30, "# sll x30,x28,x29 → 左移1 → 0x00000000")
    a.emit_S(92, 30, 31, 2,       "# DM[BASE+92]=0x00000000")
    a.emit_R(0x00, 29, 28, 5, 30, "# srl x30,x28,x29 → 逻辑右移1 → 0x40000000")
    a.emit_S(96, 30, 31, 2,       "# DM[BASE+96]=0x40000000")
    a.emit_R(0x20, 29, 28, 5, 30, "# sra x30,x28,x29 → 算术右移1 → 0xC0000000")
    a.emit_S(100, 30, 31, 2,      "# DM[BASE+100]=0xC0000000")

    # ===== 11. SB/SH + LB/LH/LBU/LHU =====
    a.emit_LI(1, SBAREA,          "# x1 = SBAREA")
    a.emit_LI(2, 0xAB,            "# x2 = 0xAB")
    a.emit_S(0, 2, 1, 0,          "# sb x2,0(x1) → byte 0xAB at [0x100]")
    a.emit_IL(0, 1, 0, 3,         "# lb x3,0(x1) → 0xFFFFFFAB")
    a.emit_S(104, 3, 31, 2,       "# DM[BASE+104]=0xFFFFFFAB")
    a.emit_IL(0, 1, 4, 4,         "# lbu x4,0(x1) → 0x000000AB")
    a.emit_S(108, 4, 31, 2,       "# DM[BASE+108]=0x000000AB")

    a.emit_LI(5, 0x1234,          "# x5 = 0x1234")
    a.emit_S(2, 5, 1, 1,          "# sh x5,2(x1) → half 0x1234 at [0x102]")
    a.emit_IL(2, 1, 1, 6,         "# lh x6,2(x1) → 0x00001234")
    a.emit_S(112, 6, 31, 2,       "# DM[BASE+112]=0x00001234")
    a.emit_IL(2, 1, 5, 7,         "# lhu x7,2(x1) → 0x00001234")
    a.emit_S(116, 7, 31, 2,       "# DM[BASE+116]=0x00001234")

    # ===== 12. x0 不可写 + 参与运算 =====
    a.emit_LI(8, 123,             "# x8 = 123")
    a.emit_I(5, 8, 0, 0,          "# addi x0,x8,5 → x0 MUST STAY 0")
    a.emit_R(0, 0, 0, 0, 9,       "# add x9,x0,x0 → x9 = 0")
    a.emit_B('fail_x0', 0, 0, 1,  "# bne x0,x0,fail_x0 → NEVER taken, fall to success")
    # success path (fall-through):
    a.emit_LI(10, 0xDEAD,         "# x10 = 0xDEAD")
    a.emit_S(120, 10, 31, 2,      "# DM[BASE+120]=0xDEAD")
    a.emit_S(124, 9, 31, 2,       "# DM[BASE+124]=0 (x9=x0+x0)")
    a.emit_J('x0_done')
    a.label('fail_x0')
    a.emit_LI(10, 0xBEEF,         "# (flushed: never reached)")
    a.emit_S(120, 10, 31, 2,      "# (flushed)")
    a.label('x0_done')

    # ===== 13. JAL 链接地址 + 嵌套调用 =====
    a.emit_J('func1', 11,         "# jal x11, func1 → x11 = return addr")
    a.label('ret_main')
    a.emit_S(128, 11, 31, 2,      "# DM[BASE+128] = PC+4 (link addr)")
    a.emit_LI(12, 0x123,          "# x12 = 0x123")
    a.emit_S(132, 12, 31, 2,      "# DM[BASE+132] = 0x123")
    a.emit_J('end', comment="# j end")

    a.label('func1')
    a.emit_LI(13, 0xAA,           "# x13 = 0xAA")
    a.emit_S(136, 13, 31, 2,      "# DM[BASE+136] = 0xAA")
    a.emit_J('func2', 14,         "# jal x14, func2")
    a.label('ret_func1')
    a.emit_LI(15, 0xBB,           "# x15 = 0xBB")
    a.emit_S(140, 15, 31, 2,      "# DM[BASE+140] = 0xBB")
    a.emit_JALR(11, 0, 0,         "# jalr x0,0(x11) → return to ret_main")
    a.NOP()                         # padding: absorb wrong-path after JALR
    a.NOP()                         # padding: absorb wrong-path after JALR

    a.label('func2')
    a.emit_LI(16, 0xCC,           "# x16 = 0xCC")
    a.emit_S(144, 16, 31, 2,      "# DM[BASE+144] = 0xCC")
    a.emit_JALR(14, 0, 0,         "# jalr x0,0(x14) → return to ret_func1")
    a.NOP()                         # padding: absorb wrong-path after JALR
    a.NOP()                         # padding: absorb wrong-path after JALR

    a.label('end')
    a.emit_J('end', comment="# infinite loop: end: j end")

    return a


if __name__ == '__main__':
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else 'ultimate_test.dat'
    a = build()
    prog = a.write_dat(out)

    # Print listing
    print("\n=== Listing ===")
    for addr, inst, comment in prog:
        cmt = f"  ; {comment}" if comment else ""
        print(f"  {addr:04X}: {inst:08X}{cmt}")

    # Print expected values
    print("\n=== Expected DM values ===")
    BASE = 0x040
    expected = {
        0:   0x0000000A,
        4:   0x12345679,
        8:   0x0000600D,
        12:  0x00000006,
        16:  0x00000006,
        20:  0x00000006,
        24:  0x00000100,
        28:  0x00000400,
        32:  0x00000500,
        36:  0x00000800,
        40:  0x00000900,
        44:  0x00000111,
        48:  0x00000333,
        52:  0x00000555,
        56:  0x00000000,
        60:  0x00000888,
        64:  0x00000AAA,
        68:  0x00000CCC,
        72:  0x0000BEEF,
        76:  0x00000046,
        80:  0x80000000,
        84:  0x80000000,
        88:  0x80000000,
        92:  0x00000000,
        96:  0x40000000,
        100: 0xC0000000,
        104: 0xFFFFFFAB,
        108: 0x000000AB,
        112: 0x00001234,
        116: 0x00001234,
        120: 0x0000DEAD,
        124: 0x00000000,
        # 128: JAL link addr (dynamic), skip check
        132: 0x00000123,
        136: 0x000000AA,
        140: 0x000000BB,
        144: 0x000000CC,
    }
    for off, val in sorted(expected.items()):
        print(f"  DM[0x{BASE+off:03X}] = 0x{val:08X}")
    print(f"  DM[0x{BASE+128:03X}] = (JAL link addr, check separately)")
