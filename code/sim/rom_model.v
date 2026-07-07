// ROM — 指令存储器行为模型 (替代 Vivado Distributed Memory Generator IP)
// 1024 × 32-bit, 异步读, Test_37_Instr8 初始化
module ROM (
    input  [9:0]   a,      // 字地址
    output [31:0]  spo     // 指令输出
);

    reg [31:0] mem [0:1023];

    // 异步读
    assign spo = mem[a];

    // 初始化: Test_37_Instr8 (37 条 RV32I 全覆盖)
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'h00000000;

        // 机器码来自 code/sim/Test_37_Instr8.coe
        mem[0]  = 32'h43506293;  // addi  t0, x0, 0x435
        mem[1]  = 32'h00001337;  // lui   t1, 0x1
        mem[2]  = 32'h0062e2b3;  // or    t0, t0, t1
        mem[3]  = 32'h98765337;  // lui   t1, 0x98765
        mem[4]  = 32'h57828393;  // addi  t2, t0, 0x578
        mem[5]  = 32'hc0030413;  // addi  s0, t1, -1024
        mem[6]  = 32'h7bc2c493;  // xori  s1, t0, 0x7bc
        mem[7]  = 32'h0193b193;  // sltiu gp, t2, 25
        mem[8]  = 32'hfff2b213;  // slti  tp, t0, -1
        mem[9]  = 32'h7654f913;  // andi  s2, s1, 0x765
        mem[10] = 32'h12332a13;  // slli  s4, t1, 18
        mem[11] = 32'h405309b3;  // sub   s3, t1, t0
        mem[12] = 32'h006a4ab3;  // xor   s5, s4, t1
        mem[13] = 32'h014a8b33;  // add   s6, s5, s4
        mem[14] = 32'h005b0b33;  // add   s6, s6, t0
        mem[15] = 32'h406b0bb3;  // sub   s7, s6, t1
        mem[16] = 32'h016becb3;  // or    s9, s7, s6
        mem[17] = 32'h016bfd33;  // and   s10, s7, s6
        mem[18] = 32'h01acadb3;  // slt   s11, s9, s10
        mem[19] = 32'h01acbe33;  // sltu  t3, s9, s10
        mem[20] = 32'h00418193;  // addi  gp, gp, 4
        mem[21] = 32'h003d1db3;  // sll   s11, s10, gp
        mem[22] = 32'h003cde33;  // srl   t3, s9, gp
        mem[23] = 32'h403cdeb3;  // sra   t4, s9, gp
        mem[24] = 32'h01899d93;  // slli  s11, s3, 24
        mem[25] = 32'h0049de13;  // srli  t3, s3, 4
        mem[26] = 32'h4049de93;  // srai  t4, s3, 4

        // 基地址建立 + Store 测试
        mem[27] = 32'h00000193;  // addi  gp, x0, 0   → gp = 0
        mem[28] = 32'h0ef00293;  // addi  t0, x0, 239 → t0 = 0xEF
        mem[29] = 32'h0131a023;  // sw    t0, 0(gp)   → [0x000] = 0xEF
        mem[30] = 32'h0151a223;  // sw    t0, 4(gp)   → [0x004] = 0xEF
        mem[31] = 32'h0171a423;  // sw    t0, 8(gp)   → [0x008] = 0xEF
        mem[32] = 32'h01a19223;  // sh    t0, 4(gp)   → [0x004] halfword
        mem[33] = 32'h01319523;  // sh    t0, 10(gp)  → [0x00A] halfword
        mem[34] = 32'h005183a3;  // sb    t0, 7(gp)   → [0x007] byte
        mem[35] = 32'h005184a3;  // sb    t0, 9(gp)   → [0x009] byte
        mem[36] = 32'h00518423;  // sb    t0, 8(gp)   → [0x008] byte

        // Load 测试
        mem[37] = 32'h0001a283;  // lw    t0, 0(gp)   → t0 = [0x000]
        mem[38] = 32'h0051a623;  // sw    t0, 12(gp)  → [0x00C] = t0
        mem[39] = 32'h00219383;  // lh    t2, 2(gp)   → t2 = signed half @ [0x002]
        mem[40] = 32'h0071a823;  // sw    t2, 16(gp)  → [0x010] = t2
        mem[41] = 32'h0021d383;  // lhu   t2, 2(gp)   → unsigned half
        mem[42] = 32'h0071aa23;  // sw    t2, 20(gp)  → [0x014] = t2
        mem[43] = 32'h00318403;  // lb    s0, 3(gp)   → signed byte @ [0x003]
        mem[44] = 32'h0081ac23;  // sw    s0, 24(gp)  → [0x018] = s0
        mem[45] = 32'h0031c403;  // lbu   s0, 3(gp)   → unsigned byte @ [0x003]
        mem[46] = 32'h0081ae23;  // sw    s0, 28(gp)  → [0x01C] = s0
        mem[47] = 32'h0011c403;  // lbu   s0, 1(gp)   → [0x001]

        mem[48] = 32'h0281a023;  // sw    t0, 32(gp)
        mem[49] = 32'h0001a023;  // sw    x0, 0(gp)   → [0x000] = 0

        // Branch 测试
        mem[50] = 32'h009074b3;  // and   s1, x0, s1  → s1=0, Zero=1
        mem[51] = 32'h00729463;  // bne   t0, t2, +8
        mem[52] = 32'h00248493;  // addi  s1, s1, 2
        mem[53] = 32'h0072d463;  // bge   t0, t2, +8
        mem[54] = 32'h00748493;  // addi  s1, s1, 7
        mem[55] = 32'h0072f463;  // bgeu  t0, t2, +8
        mem[56] = 32'h00548493;  // addi  s1, s1, 5
        mem[57] = 32'h0072c463;  // blt   t0, t2, +8
        mem[58] = 32'h00348493;  // addi  s1, s1, 3
        mem[59] = 32'h0072e063;  // bltu  t0, t2, +8
        mem[60] = 32'h00648493;  // addi  s1, s1, 6
        mem[61] = 32'h00838463;  // beq   t2, s0, +8
        mem[62] = 32'h00148493;  // addi  s1, s1, 1
        mem[63] = 32'h0091a023;  // sw    s1, 0(gp)   → save s1 result

        // JAL / JALR 测试
        mem[64] = 32'h0001a503;  // lw    a0, 0(gp)
        mem[65] = 32'h00c000ef;  // jal   ra, +12     → PC+12, ra=PC+4
        mem[66] = 32'h00350513;  // addi  a0, a0, 3
        mem[67] = 32'h00a1a023;  // sw    a0, 0(gp)   → save
        mem[68] = 32'h7a156513;  // addi  a0, a0, 0x7a1 (skipped by jal)
        mem[69] = 32'h00a1a023;  // sw    a0, 0(gp)   → save
        mem[70] = 32'h00008067;  // jalr  x0, ra, 0  → return, infinite loop
    end

endmodule
