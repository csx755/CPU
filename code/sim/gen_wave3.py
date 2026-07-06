# Wave 3 Test: SLT,SLTU,LB,LH,LBU,LHU,SB,SH (fixed immediates)
def R(f7,rs2,rs1,f3,rd): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|0b0110011
def I(imm,rs1,f3,rd,op): return ((imm&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def S(imm,rs2,rs1,f3): return ((imm>>5&0x7F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|0b0100011
def SB(off,rs2,rs1,f3): return ((off>>12&1)<<31)|((off>>5&0x3F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((off>>1&0xF)<<8)|((off>>11&1)<<7)|0b1100011
r0=0;r1=1;r2=2;r3=3;r4=4;r5=5;r6=6;r7=7;r8=8;r9=9
r10=10;r11=11;r12=12;r13=13;r14=14;r15=15;r16=16;r17=17;r18=18;r19=19
r20=20;r21=21;r22=22;r23=23;r24=24;r25=25;r26=26;r27=27;r28=28

codes = []
# === Init memory with known patterns (use 12-bit ORI safe values) ===
codes.append(I(0x078, r0, 0b110, r1, 0b0010011))  # ori x1,0x078 (12-bit safe)
codes.append(I(0x234, r0, 0b110, r2, 0b0010011))  # ori x2,0x234 (positive half)
codes.append(I(0x7AB, r0, 0b110, r3, 0b0010011))  # ori x3,0x7AB
# For negative halfword: use 0xFAB which sign-extends to 0xFFFFFAB
# 0xFAB = 1111_1010_1011, bit11=1 → sign ext to 0xFFFFFAB
codes.append(I(0xFAB, r0, 0b110, r4, 0b0010011))  # x4=0xFFFFFAB
# For negative byte: 0xF8 (bit11=1?)
# 0xF8 = 0b1111_1000, bit11=1 → sign ext to 0xFFFFFFF8
# Actually let me use a value where lower byte is 0x80
# 0x780 = 0111_1000_0000, bit11=0 → positive; byte=0x80 at offset 1
# Let me use: ori x5, 0x780 → x5=0x780; sw → mem[0]=0x780; lb from offset1 gets 0x07

# Simpler approach: use multiple ORI+SW to build known memory patterns

# mem[0:3] = 0x00000078 (byte at [0]=0x78, [1]=0x00)
codes.append(S(0, r1, r0, 0b010))    # sw x1, 0(x0)  mem[0:3]=0x00000078

# mem[4:7] = 0x00001234 → use LUI+ORI to build
# Actually, let me just use values that fit in 12-bit ORI
# Halfword at mem[4:5] = 0x234 (positive)
codes.append(S(4, r2, r0, 0b010))    # sw x2, 4(x0)  mem[4:7]=0x00000234

# mem[8:11] = word whose halfword at [8:9] is negative
# 0xFAB sign extends to 0xFFFFFAB, SW gives mem[8:11]=0xFFFFFAB
codes.append(S(8, r4, r0, 0b010))    # sw x4, 8(x0)  mem[8:11]=0x00FFFAB?

# Wait, 0xFAB → ORI sign extends: bit11=1 → 0xFFFFFAB
# SW x4,8(x0) → dmem[2] = 0xFFFFFAB
# mem[8:9] = 0x0FAB? No, word = 0xFFFFFAB.
# Byte at addr 8 (offset 0 of dmem[2]): 0xAB
# Byte at addr 9: 0x0F? No, 0xFFFFFAB in little-endian:
# addr 8: 0xAB, addr 9: 0x0F, addr 10: 0xFF, addr 11: 0xFF
# Actually, in the DM implementation, byte_off=0 gives dmem[word][7:0],
# byte_off=1 gives dmem[word][15:8], etc.
# For dmem[2] = 32'h00FFFFAB (since 0xFFFFFAB extends to 32'h00FFFFAB? No...)

# Wait, 0xFAB = 12'hFAB. Sign extend: {{20{1'b1}}, 12'hFAB} = 32'hFFFFFAB.
# SW writes this full 32-bit value to dmem[2].

# LH from address 8: reads halfword at byte_off=0 → dmem[2][15:0] = 16'hFFAB
# FFAB sign-extended = 0xFFFFFFAB... wait that's 16-bit with MSB=1
# Actually 0xFFFFFAB in hex: that's 0_FFFF_FAB which is 28 bits.
# Let me use a proper value. How about 0xFAB (12-bit).
# ORI sign extends to 32'hFFFFFAB = 0x000FFFFF? No.
# 32'hFFFFFAB = 0x0FFF_FFAB

# Hmm, this is getting confusing. Let me use simpler values.

# Let me just SW with clear values and test:
# mem[4:7] = 0x00000234 → LH→0x0234(positive), LHU→0x0234
# mem[8:11] = use a known negative halfword pattern

# For negative half: I need bit15=1 in the halfword.
# Let me use LUI to build 0xFFFF8000, then use LH. But LUI needs careful opcode too.
# Actually, ORI with 12-bit value where bit11=1 gives upper bits as 1s:
# ori x4, x0, 0xFAB → x4 = 0xFFFFFAB
# SW x4, 8(x0) → dmem[2] = 0xFFFFFAB... wait that's still only 28-bit.
# 0xFFFFFAB in 32-bit: 0x0FFF_FFAB. No wait.

# OK: 12'hFAB = 12'b1111_1010_1011
# Sign extension: {20{1'b1}, 12'hFAB} = 32'hFFFFFAB
# 0xFFFFFAB = 0 binary: 0000_1111_1111_1111_1111_1010_1011? No.
# 32'hFFFFFAB = 0x0FFF_FFAB. Hmm let me just count:
# FFFFFAB is 7 hex digits = 28 bits. But 32 bits would be 0FFF_FFAB.

# Actually sign extension pads to full 32 bits:
# {20{1'b1}} = 20 bits of 1s = 0xFFFFF
# So: {0xFFFFF, 0xFAB} = 0xFFFF_FAB = 0x0FFF_FFAB. Yes, this is 32'h0FFF_FFAB.
# mem[8:9] = 0xFFAB → LH gives 0xFFFFFFAB (sign-extend from bit15=1)

# Actually I just realized: 0xFFFFFAB has 7 hex digits, which is 28 bits.
# Extended to 32: 0x0FFFFFFAB? No.
# 20 bits of 1's = 0xFFFFF (5 hex digits)
# 12 bits of FAB (3 hex digits)
# Combined: 0xFFFFF << 12 | 0xFAB = 0xFFFF_F000 + 0xFAB = 0xFFFF_FFAB? No.
# {20{1'b1}} is 20 bits of 1s. In Verilog this would be 20'b111... = 0xFFFFF.
# {20{1'b1}, 12'hFAB} = {0xFFFFF, 0xFAB} = 32'hFFFF_FFAB? No.
# 0xFFFFF is 20 bits (5 hex digits): F_FFFF. Combined with 12-bit 0xFAB:
# Concatenation: {0xF_FFFF, 0xFAB}? No, bit concatenation:
# Upper 20 bits = 0xF_FFFF = 20'b1111_1111_1111_1111_1111
# Lower 12 bits = 0xFAB = 12'b1111_1010_1011
# Total 32 bits = 0xFFFF_FAB
# That's still only 7 hex digits? No!
# 0xFFFFF = F_FFFF (5 hex digits, 20 bits)
# Concatenated with FAB (3 hex digits, 12 bits):
# 0xF_FFFF_FAB = that's 8 hex digits: 0x0FFF_FFAB? No.
# FFFFF (binary): 1111_1111_1111_1111_1111
# FAB (binary):    1111_1010_1011
# Combined: 1111_1111_1111_1111_1111_1111_1010_1011
# = 1111_1111_1111_1111_1111_1111_1010_1011
# = 0xFFFF_FFAB

# OK so 0xFFFF_FFAB is 8 hex digits = 32 bits.
# mem[8:11] = 0xFFFFFFAB
# Wait that's still not right. Let me recalculate:
# 1111_1111_1111_1111_1111_1111_1010_1011
# Group in 4: 1111 1111 1111 1111 1111 1111 1010 1011
# = 0xFFFFFFAB (8 hex digits)

# Actually that doesn't look right either. Let me just do it in Python:
# 0xFFFFF << 12 | 0xFAB = ?
# 0xFFFFF = 1048575
# 1048575 << 12 = 4293918720
# 4293918720 | 0xFAB = 4293918720 | 4011 = 4293918731
# hex(4293918731) = 0xFFFFFAB... wait:
# 4293918731 in hex: 0xFFF_FFAB → that's 8 hex digits? No:
# 0xFFFFFFAB?

# Actually: 4293918731 decimal.
# hex(4293918731):
# 4293918731 / 16^7 = 4293918731 / 268435456 = 15 = F
# remainder = 4293918731 - 15*268435456 = 4293918731 - 4026531840 = 267386891
# 267386891 / 16^6 = 267386891 / 16777216 = 15 = F
# remainder = 267386891 - 15*16777216 = 267386891 - 251658240 = 15728651
# 15728651 / 16^5 = 15728651 / 1048576 = 15 = F
# remainder = 15728651 - 15*1048576 = 15728651 - 15728640 = 11
# 11 / 16^4 = 11 / 65536 = 0
# 11 / 16^3 = 11 / 4096 = 0
# 11 / 16^2 = 11 / 256 = 0
# 11 / 16^1 = 11 / 16 = 0
# 11 / 16^0 = 11 = B

# So hex = 0x0FFF_FFAB? That's:
# F, F, F, 0, 0, 0, 0, B
# = 0xFFF0000B? No, I need to order from MSB:
# digit 7: F
# digit 6: F
# digit 5: F
# digit 4: 0
# digit 3: 0
# digit 2: 0
# digit 1: 0
# digit 0: B
# = 0xFFF0000B

# Hmm wait, let me use Python properly:
# 0xFFFFF << 12 = 0xFFFFF000
# 0xFFFFF000 | 0xFAB = 0xFFFFFAB
# 0xFFFFFAB in 32 bits: 0x0FFFFFFAB? No...
# 0xFFFFFAB has 7 hex digits and no leading zeros needed.
# Actually in a 32-bit context: 0x0FFF_FFAB.

# OK I'm spending too much time on this. Let me just use values that are easier to understand.
# Use 0xFAB as a 12-bit ORI immediate:
# x4 = 0xFFFFFAB (sign extended)
# SW x4 → dmem[2] gets this value
# In little-endian byte order: byte[0]=0xAB, byte[1]=0xFF, byte[2]=0xFF, byte[3]=0x0F
# LH from addr 8: reads bytes[0:1] = 0xFFAB → sign extend: 0xFFFFFFAB
# LHU from addr 8: reads 0xFFAB → zero extend: 0x0000FFAB

# But wait, DM byte ordering in my implementation:
# byte_off=0 → dmem[word][7:0] = lowest byte
# byte_off=1 → dmem[word][15:8]
# etc.
# This is little-endian.

# For dmem[2] = 0x0FFF_FFAB (32-bit hex):
# Actually: 0xFFF_FFAB = 0x0FFF_FFAB
# dmem[2][7:0] = 0xAB
# dmem[2][15:8] = 0xFF
# dmem[2][23:16] = 0xFF
# dmem[2][31:24] = 0x0F

# LH addr 8 (byte_off=0): reads dmem[2][15:0] = 0xFFAB
# Sign extend (bit15=1): 0xFFFFFFAB
# Correct!

# LHU addr 8: reads 0xFFAB
# Zero extend: 0x0000FFAB
# Correct!

# LH addr 4 (byte_off=0 of dmem[1]): dmem[1] = 0x00000234
# dmem[1][15:0] = 0x0234 → LH: 0x00000234
# Correct!

# Now, let me update the test with correct expectations:
# x18 LH(4): read 0x0234 → 0x00000234 = 564
# x19 LH(8): read 0xFFAB → 0xFFFFFFAB = -85? No, 0xFFFFFFAB signed = -85
#   0xFFFFFFAB = -85 in decimal
# x20 LHU(8): read 0xFFAB → 0x0000FFAB = 65451
# x21 LHU(4): read 0x0234 → 0x00000234 = 564

# SB test:
# First SW x0 to clear mem[16:19]
# then SB x22=0xA5 to addr 16
# then LW from addr 16 → should be 0xA5

# SH test:
# First SW x0 to clear mem[20:23]
# then SH x24=0x7EF to addr 20
# then LW from addr 20 → should be 0x7EF

codes.append(S(8, r4, r0, 0b010))    # sw x4, 8(x0)

# === SLT/SLTU ===
codes.append(I(10, r0, 0b110, r5, 0b0010011))
codes.append(I(20, r0, 0b110, r6, 0b0010011))
codes.append(I((-1)&0xFFF, r0, 0b000, r7, 0b0010011))  # addi x7,-1
codes.append(R(0, r6, r5, 0b010, r8))
codes.append(R(0, r5, r6, 0b010, r9))
codes.append(R(0, r5, r7, 0b010, r10))
codes.append(R(0, r7, r5, 0b011, r11))
codes.append(R(0, r5, r7, 0b011, r12))

# === LB/LBU ===
codes.append(I(0, r0, 0b000, r13, 0b0000011))    # lb x13, 0(x0) → 0x78=120
codes.append(I(0, r0, 0b100, r17, 0b0000011))    # lbu x17,0(x0) → 0x78=120
# For negative byte: we need a byte with bit7=1.
# mem[0] = 0x78 (bit7=0, positive). Let me use a different address.
# Actually, let me keep existing test. LB and LBU both read 0x78 from mem[0].
# To test negative, use mem[8] (dmem[2][7:0] = 0xAB, bit7=1):
codes.append(I(8, r0, 0b000, r14, 0b0000011))    # lb x14, 8(x0) → 0xFFFFFFAB = -85
codes.append(I(8, r0, 0b100, r16, 0b0000011))    # lbu x16,8(x0) → 0xAB = 171
codes.append(I(9, r0, 0b000, r15, 0b0000011))    # lb x15, 9(x0) → mem[9]=0xFF → -1

# === LH/LHU ===
codes.append(I(4, r0, 0b001, r18, 0b0000011))    # lh x18, 4(x0) → 0x0234 = 564
codes.append(I(8, r0, 0b001, r19, 0b0000011))    # lh x19, 8(x0) → 0xFFFFFFAB = -85
codes.append(I(8, r0, 0b101, r20, 0b0000011))    # lhu x20,8(x0) → 0xFFAB = 65451
codes.append(I(4, r0, 0b101, r21, 0b0000011))    # lhu x21,4(x0) → 0x0234 = 564

# === SB/SH ===
# Clear memory with SW x0 first
codes.append(S(16, r0, r0, 0b010))                # sw x0,16(x0) → clear mem[16:19]
codes.append(S(20, r0, r0, 0b010))                # sw x0,20(x0) → clear mem[20:23]
codes.append(I(0xA5, r0, 0b110, r22, 0b0010011)) # x22=0xA5 (165)
codes.append(S(16, r22, r0, 0b000))               # sb x22,16(x0)
codes.append(I(0x7EF, r0, 0b110, r24, 0b0010011))# x24=0x7EF (2031)
codes.append(S(20, r24, r0, 0b001))               # sh x24,20(x0)
codes.append(I(16, r0, 0b010, r23, 0b0000011))   # lw x23,16(x0) → 0xA5=165
codes.append(I(20, r0, 0b010, r25, 0b0000011))   # lw x25,20(x0) → 0x7EF=2031

# Store results
sw_regs = [r8,r9,r10,r11,r12, r13,r14,r15,r16,r17, r18,r19,r20,r21, r23,r25]
sw_base = 32
for i, rs in enumerate(sw_regs):
    codes.append(S(sw_base + i*4, rs, r0, 0b010))

codes.append(SB(0, r0, r0, 0b000))

# Write .dat
with open('Test_Wave3.dat','w') as f:
    for c in codes:
        f.write(f'0x{c:08X}\n')

print(f'Done: {len(codes)} instructions')
# Expected values for testbench
print('# x8=1 x9=0 x10=1 x11=1 x12=0 (SLT/SLTU)')
print('# x13=120(0x78) x14=-85 x15=-1 x16=171 x17=120 (LB/LBU)')
print('# x18=564(0x234) x19=-85 x20=65451(0xFFAB) x21=564 (LH/LHU)')
print('# x23=165(0xA5) x25=2031(0x7EF) (SB/SH)')
