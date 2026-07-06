# Wave 2 Test Assembler
def R(f7,rs2,rs1,f3,rd,op=0b0110011): return (f7<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def I(imm,rs1,f3,rd,op): return ((imm&0xFFF)<<20)|(rs1<<15)|(f3<<12)|(rd<<7)|op
def S(imm,rs2,rs1,f3): return ((imm>>5&0x7F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((imm&0x1F)<<7)|0b0100011
def SB(off,rs2,rs1,f3): return ((off>>12&1)<<31)|((off>>5&0x3F)<<25)|(rs2<<20)|(rs1<<15)|(f3<<12)|((off>>1&0xF)<<8)|((off>>11&1)<<7)|0b1100011
def U(imm,rd,op): return ((imm&0xFFFFF)<<12)|(rd<<7)|op

r0=0; r1=1; r2=2; r3=3; r4=4; r5=5; r6=6; r7=7; r8=8; r9=9
r10=10; r11=11; r12=12; r13=13; r14=14; r15=15; r16=16; r17=17; r18=18; r19=19

tests = []

# Init
tests.append(U(0x12345, r1, 0b0110111))        # LUI x1, 0x12345
tests.append(I(0x678, r1, 0b000, r1, 0b0010011)) # ADDI x1,x1,0x678
tests.append(U(0, r3, 0b0010111))               # AUIPC x3, 0
tests.append(I(10, r0, 0b110, r5, 0b0010011))   # ORI x5, x0, 10
tests.append(I(20, r0, 0b110, r6, 0b0010011))   # ORI x6, x0, 20
tests.append(I(5, r0, 0b110, r7, 0b0010011))    # ORI x7, x0, 5
tests.append(U(0x80000, r4, 0b0110111))         # LUI x4, 0x80000

# R-type tests
tests.append(R(0, r7, r5, 0b001, r8))            # SLL x8, x5, x7  (10<<5=0x140)
tests.append(R(0, r7, r4, 0b101, r9))            # SRL x9, x4, x7  (0x80000000>>5)
tests.append(R(0b0100000, r7, r4, 0b101, r10))   # SRA x10, x4, x7 (arithmetic>>)
tests.append(R(0, r6, r5, 0b100, r11))           # XOR x11, x5, x6 (10^20=30)
tests.append(R(0, r5, r5, 0b100, r12))           # XOR x12, x5, x5 (self=0)

# Branch tests: all "should branch" cases
# BNE: 10!=20 → branch
tests.append(I(1, r0, 0b110, r13, 0b0010011))   # ori x13=1 (pass)
tests.append(SB(8, r6, r5, 0b001))               # bne x5,x6,+8
tests.append(I(0, r0, 0b000, r13, 0b0010011))    # addi x13=0 (FAIL, skipped)

# BEQ: 10!=20 → NOT branch, fall through
tests.append(I(0, r0, 0b110, r14, 0b0010011))   # ori x14=0 (before branch)
tests.append(SB(8, r6, r5, 0b000))               # beq x5,x6,+8 (NOT taken)
tests.append(I(1, r0, 0b110, r14, 0b0010011))    # ori x14=1 (reached, pass)

# BLT: 10<20 → branch
tests.append(I(2, r0, 0b110, r15, 0b0010011))   # ori x15=2
tests.append(SB(8, r6, r5, 0b100))               # blt x5,x6,+8
tests.append(I(0, r0, 0b000, r15, 0b0010011))    # (skipped)

# BGE: 20>=10 → branch
tests.append(I(3, r0, 0b110, r16, 0b0010011))   # ori x16=3
tests.append(SB(8, r5, r6, 0b101))               # bge x6,x5,+8
tests.append(I(0, r0, 0b000, r16, 0b0010011))    # (skipped)

# BLTU: 10 < 0x80000000 unsigned → branch
tests.append(I(4, r0, 0b110, r17, 0b0010011))   # ori x17=4
tests.append(SB(8, r4, r5, 0b110))               # bltu x5,x4,+8
tests.append(I(0, r0, 0b000, r17, 0b0010011))    # (skipped)

# BGEU: 20 >= 10 unsigned → branch
tests.append(I(5, r0, 0b110, r18, 0b0010011))   # ori x18=5
tests.append(SB(8, r5, r6, 0b111))               # bgeu x6,x5,+8
tests.append(I(0, r0, 0b000, r18, 0b0010011))    # (skipped)

# Store results
sw_data = [
    (r1, 0), (r3, 4), (r8, 8), (r9, 12), (r10, 16),
    (r11, 20), (r12, 24), (r13, 28), (r14, 32),
    (r15, 36), (r16, 40), (r17, 44), (r18, 48),
]
for rs2, off in sw_data:
    tests.append(S(off, rs2, r0, 0b010))

# End loop
tests.append(SB(0, r0, r0, 0b000))

# Write .dat
with open('Test_Wave2.dat','w') as f:
    for c in tests:
        f.write(f'0x{c:08X}\n')

# Write .asm
labels = [
    'lui x1, 0x12345',
    'addi x1, x1, 0x678',
    'auipc x3, 0',
    'ori x5, x0, 10',
    'ori x6, x0, 20',
    'ori x7, x0, 5',
    'lui x4, 0x80000',
    'sll x8, x5, x7',
    'srl x9, x4, x7',
    'sra x10, x4, x7',
    'xor x11, x5, x6',
    'xor x12, x5, x5',
    'BNE: ori x13,1 (pass)',
    'bne x5,x6,+8',
    'addi x13,0 (fail,skipped)',
    'BEQ: ori x14,0',
    'beq x5,x6,+8',
    'ori x14,1 (reached=pass)',
    'BLT: ori x15,2 (pass)',
    'blt x5,x6,+8',
    'addi x15,0 (fail,skipped)',
    'BGE: ori x16,3 (pass)',
    'bge x6,x5,+8',
    'addi x16,0 (fail,skipped)',
    'BLTU: ori x17,4 (pass)',
    'bltu x5,x4,+8',
    'addi x17,0 (fail,skipped)',
    'BGEU: ori x18,5 (pass)',
    'bgeu x6,x5,+8',
    'addi x18,0 (fail,skipped)',
]
for i in range(len(tests)):
    name = labels[i] if i < len(labels) else f'sw{sw_data[i-len(labels)]}'
    print(f'// 0x{i*4:02X}: 0x{tests[i]:08X}  {name}')

print(f'Total: {len(tests)} instructions')
print('Expected: x1=0x12345678, x3=AUIPC, x8=0x140, x9=0x04000000, x10=0xFC000000')
print('x11=30, x12=0, x13=1, x14=1, x15=2, x16=3, x17=4, x18=5')
