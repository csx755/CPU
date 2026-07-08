// cpu_testac_final_tb — SCPU 纯信号级验证 (无 ROM/RAM 模块)
// 逐周期检查 mem_w / Addr_out / Data_out / dm_ctrl, 不匹配立即 $fatal
`timescale 1ns / 1ps

module cpu_testac_final_tb();

    reg clk, rst;
    reg [31:0] inst_in, Data_in;
    wire [31:0] PC, Addr_out, Data_out;
    wire mem_w;
    wire [2:0] dm_ctrl;

    SCPU U_SCPU (
        .clk(clk), .reset(rst), .MIO_ready(1'b1),
        .inst_in(inst_in), .Data_in(Data_in), .INT(1'b0),
        .mem_w(mem_w), .CPU_MIO(), .PC_out(PC),
        .Addr_out(Addr_out), .Data_out(Data_out), .dm_ctrl(dm_ctrl),
        .reg_sel(5'd0), .reg_data()
    );

    // ---- 指令编码函数 ----
    function [31:0] R; input [6:0] f7; input [4:0] r2,r1; input [2:0] f3; input [4:0] rd;
        begin R = {f7, r2, r1, f3, rd, 7'b0110011}; end
    endfunction
    function [31:0] I; input [11:0] imm; input [4:0] r1; input [2:0] f3; input [4:0] rd;
        begin I = {imm, r1, f3, rd, 7'b0010011}; end
    endfunction
    function [31:0] IL; input [11:0] imm; input [4:0] r1; input [2:0] f3; input [4:0] rd;
        begin IL = {imm, r1, f3, rd, 7'b0000011}; end
    endfunction
    function [31:0] S; input [11:0] imm; input [4:0] r2,r1; input [2:0] f3;
        begin S = {imm[11:5], r2, r1, f3, imm[4:0], 7'b0100011}; end
    endfunction
    function [31:0] B; input [31:0] byte_off; input [4:0] r2,r1; input [2:0] f3;
        begin B = {byte_off[12], byte_off[10:5], r2, r1, f3, byte_off[4:1], byte_off[11], 7'b1100011}; end
    endfunction
    function [31:0] U; input [31:0] imm_full; input [4:0] rd;
        begin U = {imm_full[31:12], rd, 7'b0110111}; end
    endfunction
    function [31:0] UA; input [31:0] imm_full; input [4:0] rd;
        begin UA = {imm_full[31:12], rd, 7'b0010111}; end
    endfunction
    function [31:0] J; input [31:0] byte_off; input [4:0] rd;
        begin J = {byte_off[20], byte_off[10:1], byte_off[11], byte_off[19:12], rd, 7'b1101111}; end
    endfunction
    function [31:0] JR; input [31:0] imm_full; input [4:0] r1; input [4:0] rd;
        begin JR = {imm_full[11:0], r1, 3'b000, rd, 7'b1100111}; end
    endfunction

    // label 地址
    localparam L1=8'h90, L2=8'hA0, L3=8'hAC, L4=8'hBC, L5=8'hC8, L6=8'hD8, L7=8'hE4, HALT=8'hEC;

    // ---- 取指: 按 PC 返回指令 (无 ROM 模块) ----
    always @(*) begin
        case (PC)
            8'h00: inst_in = U(32'h12345000, 1);
            8'h04: inst_in = UA(32'h01000000, 2);
            8'h08: inst_in = I(12'h7FF, 0, 3'b000, 3);
            8'h0C: inst_in = I(12'h800, 3, 3'b010, 4);
            8'h10: inst_in = I(-12'd1, 3, 3'b011, 5);
            8'h14: inst_in = I(-12'd1, 3, 3'b100, 6);
            8'h18: inst_in = I(12'h100, 3, 3'b110, 7);
            8'h1C: inst_in = I(12'h0F0, 3, 3'b111, 8);
            8'h20: inst_in = I({7'b0, 4'd4}, 3, 3'b001, 9);
            8'h24: inst_in = I({7'b0, 2'd2}, 3, 3'b101, 10);
            8'h28: inst_in = I({1'b0, 6'b100000, 4'd4}, 6, 3'b101, 11);
            8'h2C: inst_in = R(0, 9, 3, 3'b000, 12);
            8'h30: inst_in = R(7'h20, 3, 9, 3'b000, 13);
            8'h34: inst_in = R(0, 4, 3, 3'b001, 14);
            8'h38: inst_in = R(0, 9, 3, 3'b010, 15);
            8'h3C: inst_in = R(0, 9, 3, 3'b011, 16);
            8'h40: inst_in = R(0, 12, 3, 3'b100, 17);
            8'h44: inst_in = R(0, 4, 9, 3'b101, 18);
            8'h48: inst_in = R(7'h20, 4, 6, 3'b101, 19);
            8'h4C: inst_in = R(0, 12, 3, 3'b110, 20);
            8'h50: inst_in = R(0, 12, 3, 3'b111, 21);
            8'h54: inst_in = I(12'h100, 0, 3'b000, 22);
            8'h58: inst_in = I(12'h0AB, 0, 3'b000, 23);
            8'h5C: inst_in = I(12'h234, 0, 3'b000, 24);
            8'h60: inst_in = I(-12'd1, 0, 3'b000, 25);
            8'h64: inst_in = S(12'h000, 12, 22, 3'b010);
            8'h68: inst_in = S(12'h004, 24, 22, 3'b001);
            8'h6C: inst_in = S(12'h008, 23, 22, 3'b000);
            8'h70: inst_in = IL(12'h000, 22, 3'b010, 26);
            8'h74: inst_in = IL(12'h004, 22, 3'b001, 27);
            8'h78: inst_in = IL(12'h004, 22, 3'b101, 28);
            8'h7C: inst_in = IL(12'h008, 22, 3'b000, 29);
            8'h80: inst_in = IL(12'h008, 22, 3'b100, 30);
            8'h84: inst_in = B((L1-8'h84), 12, 26, 3'b000);
            8'h88: inst_in = I(0,0,0,0);
            8'h8C: inst_in = I(0,0,0,0);
            8'h90: inst_in = B((L2-8'h90), 28, 27, 3'b001);
            8'h94: inst_in = I(0,0,0,0);
            8'h98: inst_in = B((L2-8'h98), 26, 27, 3'b001);
            8'h9C: inst_in = I(0,0,0,0);
            8'hA0: inst_in = B((L3-8'hA0), 26, 27, 3'b100);
            8'hA4: inst_in = I(0,0,0,0);
            8'hA8: inst_in = I(0,0,0,0);
            8'hAC: inst_in = B((L4-8'hAC), 26, 27, 3'b101);
            8'hB0: inst_in = I(0,0,0,0);
            8'hB4: inst_in = B((L4-8'hB4), 27, 27, 3'b101);
            8'hB8: inst_in = I(0,0,0,0);
            8'hBC: inst_in = B((L5-8'hBC), 25, 27, 3'b110);
            8'hC0: inst_in = I(0,0,0,0);
            8'hC4: inst_in = I(0,0,0,0);
            8'hC8: inst_in = B((L6-8'hC8), 25, 27, 3'b111);
            8'hCC: inst_in = I(0,0,0,0);
            8'hD0: inst_in = B((L6-8'hD0), 27, 26, 3'b111);
            8'hD4: inst_in = I(0,0,0,0);
            8'hD8: inst_in = J((L7-8'hD8), 31);
            8'hDC: inst_in = I(0,0,0,0);
            8'hE0: inst_in = I(0,0,0,0);
            8'hE4: inst_in = JR(16, 31, 0);   // JALR x0, 16(x31) → x31+16=0xDC+16=0xEC (HALT)
            8'hE8: inst_in = I(0,0,0,0);
            8'hEC: inst_in = J(0, 0);          // HALT loop
            default: inst_in = I(0,0,0,0); // NOP
        endcase
    end

    // ---- 简易 DM 行为模型 (只为本测试的 3 个 store / 5 个 load 服务) ----
    reg [31:0] dm [0:127];
    integer di;
    initial for (di=0; di<128; di=di+1) dm[di] = 32'hxxxxxxxx;

    // Data_in 驱动: 模拟 DM 读行为
    wire [8:0] dm_byte_addr = Addr_out[8:0];
    always @(*) begin
        case (dm_ctrl)
            3'b000: Data_in = dm[dm_byte_addr[8:2]];                    // LW
            3'b001: begin                                               // LH
                if (dm_byte_addr[1])
                    Data_in = {{16{dm[dm_byte_addr[8:2]][31]}}, dm[dm_byte_addr[8:2]][31:16]};
                else
                    Data_in = {{16{dm[dm_byte_addr[8:2]][15]}}, dm[dm_byte_addr[8:2]][15:0]};
            end
            3'b010: begin                                               // LHU
                if (dm_byte_addr[1])
                    Data_in = {16'b0, dm[dm_byte_addr[8:2]][31:16]};
                else
                    Data_in = {16'b0, dm[dm_byte_addr[8:2]][15:0]};
            end
            3'b011: begin                                               // LB
                case (dm_byte_addr[1:0])
                    2'b00: Data_in = {{24{dm[dm_byte_addr[8:2]][7]}},  dm[dm_byte_addr[8:2]][7:0]};
                    2'b01: Data_in = {{24{dm[dm_byte_addr[8:2]][15]}}, dm[dm_byte_addr[8:2]][15:8]};
                    2'b10: Data_in = {{24{dm[dm_byte_addr[8:2]][23]}}, dm[dm_byte_addr[8:2]][23:16]};
                    2'b11: Data_in = {{24{dm[dm_byte_addr[8:2]][31]}}, dm[dm_byte_addr[8:2]][31:24]};
                endcase
            end
            3'b100: begin                                               // LBU
                case (dm_byte_addr[1:0])
                    2'b00: Data_in = {24'b0, dm[dm_byte_addr[8:2]][7:0]};
                    2'b01: Data_in = {24'b0, dm[dm_byte_addr[8:2]][15:8]};
                    2'b10: Data_in = {24'b0, dm[dm_byte_addr[8:2]][23:16]};
                    2'b11: Data_in = {24'b0, dm[dm_byte_addr[8:2]][31:24]};
                endcase
            end
            default: Data_in = dm[dm_byte_addr[8:2]];
        endcase
    end

    // DM 写入: 在 posedge clk 时更新
    always @(posedge clk) begin
        if (mem_w) begin
            case (dm_ctrl)
                3'b000: dm[dm_byte_addr[8:2]] <= Data_out;              // SW
                3'b001: begin                                           // SH
                    if (dm_byte_addr[1])
                        dm[dm_byte_addr[8:2]][31:16] <= Data_out[15:0];
                    else
                        dm[dm_byte_addr[8:2]][15:0] <= Data_out[15:0];
                end
                3'b011: begin                                           // SB
                    case (dm_byte_addr[1:0])
                        2'b00: dm[dm_byte_addr[8:2]][7:0]   <= Data_out[7:0];
                        2'b01: dm[dm_byte_addr[8:2]][15:8]  <= Data_out[7:0];
                        2'b10: dm[dm_byte_addr[8:2]][23:16] <= Data_out[7:0];
                        2'b11: dm[dm_byte_addr[8:2]][31:24] <= Data_out[7:0];
                    endcase
                end
                default: dm[dm_byte_addr[8:2]] <= Data_out;
            endcase
        end
    end

    // ---- 时钟 + 逐周期检查 ----
    always #50 clk = ~clk;

    // 检查宏: 不匹配立即 $fatal
    `define CHECK(cond, msg) \
        if (!(cond)) begin \
            $display("[FATAL] Cycle %0d PC=0x%02X: %s", cycle, PC, msg); \
            $display("  Addr_out=%08X Data_out=%08X mem_w=%b dm_ctrl=%b", Addr_out, Data_out, mem_w, dm_ctrl); \
            $fatal; \
        end

    integer cycle;
    reg [31:0] pc_history [0:63];
    integer pci;

    initial begin
        clk = 0; rst = 1; cycle = 0;
        for (pci=0; pci<64; pci=pci+1) pc_history[pci] = 32'hDEAD_BEEF;
        pci = 0;

        #200 rst = 0;
        $display("=== SCPU Signal-Level Test (no ROM/RAM modules) ===\n");
        $display("Cycle | PC   | mem_w | Addr_out   | Data_out   | dm_ctrl | Check");
        $display("------|------|-------|------------|------------|---------|------");
    end

    always @(posedge clk) begin
        if (rst) begin
            // reset 期间不检查
        end else begin
            cycle = cycle + 1;
            pc_history[pci] = PC; pci = pci + 1;
            $write("%5d | 0x%02X | %b     | 0x%08X | 0x%08X | %b  |",
                   cycle, PC, mem_w, Addr_out, Data_out, dm_ctrl);

            case (PC)
                // ---- 初始化阶段: no memory ops ----
                8'h00: `CHECK(!mem_w, "LUI: mem_w should be 0")
                8'h04: `CHECK(!mem_w, "AUIPC: mem_w should be 0")
                8'h08: `CHECK(!mem_w, "ADDI: mem_w should be 0")
                8'h0C: `CHECK(!mem_w, "SLTI: mem_w should be 0")
                8'h10: `CHECK(!mem_w, "SLTIU: mem_w should be 0")
                8'h14: `CHECK(!mem_w, "XORI: mem_w should be 0")
                8'h18: `CHECK(!mem_w, "ORI: mem_w should be 0")
                8'h1C: `CHECK(!mem_w, "ANDI: mem_w should be 0")
                8'h20: `CHECK(!mem_w, "SLLI: mem_w should be 0")
                8'h24: `CHECK(!mem_w, "SRLI: mem_w should be 0")
                8'h28: `CHECK(!mem_w, "SRAI: mem_w should be 0")
                8'h2C: `CHECK(!mem_w, "ADD: mem_w should be 0")
                8'h30: `CHECK(!mem_w, "SUB: mem_w should be 0")
                8'h34: `CHECK(!mem_w, "SLL: mem_w should be 0")
                8'h38: `CHECK(!mem_w, "SLT: mem_w should be 0")
                8'h3C: `CHECK(!mem_w, "SLTU: mem_w should be 0")
                8'h40: `CHECK(!mem_w, "XOR: mem_w should be 0")
                8'h44: `CHECK(!mem_w, "SRL: mem_w should be 0")
                8'h48: `CHECK(!mem_w, "SRA: mem_w should be 0")
                8'h4C: `CHECK(!mem_w, "OR: mem_w should be 0")
                8'h50: `CHECK(!mem_w, "AND: mem_w should be 0")
                8'h54: `CHECK(!mem_w, "ADDI x22: mem_w should be 0")
                8'h58: `CHECK(!mem_w, "ADDI x23: mem_w should be 0")
                8'h5C: `CHECK(!mem_w, "ADDI x24: mem_w should be 0")
                8'h60: `CHECK(!mem_w, "ADDI x25: mem_w should be 0")

                // ---- Store 阶段 ----
                8'h64: begin
                    `CHECK(mem_w,         "SW: mem_w should be 1")
                    `CHECK(dm_ctrl==3'b000,"SW: dm_ctrl should be 000")
                    `CHECK(Addr_out==32'h100, "SW: Addr_out should be 0x100")
                    $write(" SW OK addr=0x%X data=0x%X", Addr_out, Data_out);
                end
                8'h68: begin
                    `CHECK(mem_w,         "SH: mem_w should be 1")
                    `CHECK(dm_ctrl==3'b001,"SH: dm_ctrl should be 001")
                    `CHECK(Addr_out==32'h104, "SH: Addr_out should be 0x104")
                    $write(" SH OK");
                end
                8'h6C: begin
                    `CHECK(mem_w,         "SB: mem_w should be 1")
                    `CHECK(dm_ctrl==3'b011,"SB: dm_ctrl should be 011")
                    `CHECK(Addr_out==32'h108, "SB: Addr_out should be 0x108")
                    $write(" SB OK");
                end

                // ---- Load 阶段 ----
                8'h70: begin
                    `CHECK(!mem_w, "LW: mem_w should be 0")
                    `CHECK(dm_ctrl==3'b000, "LW: dm_ctrl should be 000")
                    $write(" LW OK");
                end
                8'h74: begin
                    `CHECK(!mem_w, "LH: mem_w should be 0")
                    `CHECK(dm_ctrl==3'b001, "LH: dm_ctrl should be 001")
                    $write(" LH OK");
                end
                8'h78: begin
                    `CHECK(!mem_w, "LHU: mem_w should be 0")
                    `CHECK(dm_ctrl==3'b010, "LHU: dm_ctrl should be 010")
                    $write(" LHU OK");
                end
                8'h7C: begin
                    `CHECK(!mem_w, "LB: mem_w should be 0")
                    `CHECK(dm_ctrl==3'b011, "LB: dm_ctrl should be 011")
                    $write(" LB OK");
                end
                8'h80: begin
                    `CHECK(!mem_w, "LBU: mem_w should be 0")
                    `CHECK(dm_ctrl==3'b100, "LBU: dm_ctrl should be 100")
                    $write(" LBU OK");
                end

                // ---- 分支: 只检查不产生 spurious mem_w ----
                8'h84: `CHECK(!mem_w, "BEQ: mem_w should be 0")
                8'h88: `CHECK(!mem_w, "NOP(88): mem_w should be 0")
                8'h8C: `CHECK(!mem_w, "NOP(8C): mem_w should be 0")
                8'h90: `CHECK(!mem_w, "BNE(not taken): mem_w should be 0")
                8'h94: `CHECK(!mem_w, "NOP(94): mem_w should be 0")
                8'h98: `CHECK(!mem_w, "BNE(taken): mem_w should be 0")
                8'h9C: `CHECK(!mem_w, "NOP(9C): mem_w should be 0")
                8'hA0: `CHECK(!mem_w, "BLT: mem_w should be 0")
                8'hA4: `CHECK(!mem_w, "NOP(A4): mem_w should be 0")
                8'hA8: `CHECK(!mem_w, "NOP(A8): mem_w should be 0")
                8'hAC: `CHECK(!mem_w, "BGE(not taken): mem_w should be 0")
                8'hB0: `CHECK(!mem_w, "NOP(B0): mem_w should be 0")
                8'hB4: `CHECK(!mem_w, "BGE(taken): mem_w should be 0")
                8'hB8: `CHECK(!mem_w, "NOP(B8): mem_w should be 0")
                8'hBC: `CHECK(!mem_w, "BLTU: mem_w should be 0")
                8'hC0: `CHECK(!mem_w, "NOP(C0): mem_w should be 0")
                8'hC4: `CHECK(!mem_w, "NOP(C4): mem_w should be 0")
                8'hC8: `CHECK(!mem_w, "BGEU(not taken): mem_w should be 0")
                8'hCC: `CHECK(!mem_w, "NOP(CC): mem_w should be 0")
                8'hD0: `CHECK(!mem_w, "BGEU(taken): mem_w should be 0")
                8'hD4: `CHECK(!mem_w, "NOP(D4): mem_w should be 0")

                // ---- JAL + JALR ----
                8'hD8: `CHECK(!mem_w, "JAL: mem_w should be 0")
                8'hDC: `CHECK(!mem_w, "NOP(DC): mem_w should be 0")
                8'hE0: `CHECK(!mem_w, "NOP(E0): mem_w should be 0")
                8'hE4: `CHECK(!mem_w, "JALR: mem_w should be 0")
                8'hE8: `CHECK(!mem_w, "NOP(E8): mem_w should be 0")

                // ---- HALT loop ----
                8'hEC: begin
                    `CHECK(!mem_w, "HALT: mem_w should be 0")
                    $display("\n=== HALT reached — all signals correct ===");
                    $display("PC trace (%0d instructions):", cycle);
                    for (pci=0; pci<cycle; pci=pci+1)
                        $display("  %0d: 0x%08X", pci, pc_history[pci]);
                    $display("\nStore verification:");
                    $display("  SW @0x100 -> DM[%0d] = 0x%08X", 9'h100>>2, dm[9'h100>>2]);
                    $display("  SH @0x104 -> DM[%0d] = 0x%08X", 9'h104>>2, dm[9'h104>>2]);
                    $display("  SB @0x108 -> DM[%0d] = 0x%08X", 9'h108>>2, dm[9'h108>>2]);
                    $finish;
                end

                default: begin
                    $display("[FATAL] Unexpected PC=0x%08X at cycle %0d", PC, cycle);
                    $fatal;
                end
            endcase
            $display(" ✓");
        end
    end

    // 超时保护
    initial begin
        #100000;
        $display("[FATAL] Timeout — CPU stuck or unexpected PC");
        $fatal;
    end

endmodule
