// ultimate_tb — RV32I 流水线终极验收测试
// 覆盖: 转发/阻塞/分支冲刷/JAL/JALR/双源Forward/移位截断/byte-half/x0保护/嵌套调用
// 编译: cd code/sim && iverilog -o ult -I ../rtl ../rtl/*.v ultimate_tb.v && vvp -n ult
`timescale 1ns / 1ps
`include "ctrl_encode_def.v"

module ultimate_tb();
    reg clk, rst;
    wire [31:0] inst_in, Data_in;
    wire mem_w;
    wire [31:0] PC, Addr_out, Data_out;
    wire [2:0] dm_ctrl;

    SCPU_pipelined U_P (
        .clk(clk), .reset(rst), .MIO_ready(1'b1),
        .inst_in(inst_in), .Data_in(Data_in), .INT(1'b0),
        .mem_w(mem_w), .CPU_MIO(), .PC_out(PC),
        .Addr_out(Addr_out), .Data_out(Data_out), .dm_ctrl(dm_ctrl),
        .reg_sel(5'd0), .reg_data()
    );

    // ---- ROM: 1024 words, loaded from .dat ----
    reg [31:0] rom [0:1023];
    integer i;
    initial begin
        $readmemh("ultimate_test.dat", rom);
    end
    assign inst_in = rom[PC[11:2]];

    // ---- Data Memory ----
    dm U_DM (
        .clk(clk), .DMWr(mem_w),
        .addr(Addr_out[8:0]), .din(Data_out),
        .dout(Data_in), .DMType(dm_ctrl)
    );

    // ---- Clock ----
    always #50 clk = ~clk;

    // ---- Simulation ----
    localparam BASE = 32'h040;          // result base address (word index = 16)
    localparam BASE_IDX = BASE >> 2;    // = 16
    localparam MAX_CYCLES = 4000;
    localparam LOOP_PC = 32'h30C;       // end: j end (infinite loop)

    integer cycle, err, loop_cnt;
    reg done;

    // ---- Verification task ----
    task check;
        input [31:0] byte_off;
        input [31:0] expected;
        input [255:0] desc;
        begin
            if (U_DM.dmem[BASE_IDX + (byte_off >> 2)] !== expected) begin
                $display("[FAIL] DM[0x%04X] = %08X, expect %08X | %0s",
                    BASE + byte_off,
                    U_DM.dmem[BASE_IDX + (byte_off >> 2)],
                    expected, desc);
                err = err + 1;
            end else begin
                $display("[PASS] %0s", desc);
            end
        end
    endtask

    initial begin
        clk = 0; rst = 1; cycle = 0; err = 0; done = 0; loop_cnt = 0;
        #200 rst = 0;

        $display("=== RV32I Pipeline Ultimate Test ===\n");
        $display("BASE=0x%04X (word_idx=%0d)", BASE, BASE_IDX);
    end

    // Monitor: detect infinite loop for early stop
    always @(posedge clk) begin
        if (!rst) begin
            cycle <= cycle + 1;

            if (cycle >= MAX_CYCLES && !done) begin
                done = 1;
                $display("\n[MAX_CYCLES=%0d reached, starting verification]", MAX_CYCLES);
                #10 run_checks();
            end

            // Early stop: detect stuck at end loop
            if (PC === LOOP_PC) begin
                loop_cnt <= loop_cnt + 1;
            end else begin
                loop_cnt <= 0;
            end

            if (loop_cnt >= 16 && !done) begin
                done = 1;
                $display("\n[Early stop at cycle=%0d, PC stuck at %h]", cycle, PC);
                #10 run_checks();
            end
        end
    end

    task run_checks;
        begin
            $display("\n=== Verification Results ===");

            $display("\n-- 1. Forwarding Chain --");
            check(32'h00, 32'h0000000A, "Fwd chain: x1=5+3=8, x2=8+2=10");

            $display("\n-- 2. Load-Use Hazard --");
            check(32'h04, 32'h12345679, "Load-Use: lw+addi stall, 0x12345678+1");

            $display("\n-- 3. Load+Branch Hazard --");
            check(32'h08, 32'h0000600D, "Ld+Br: beq x7,x6 taken, x8=0x600D");

            $display("\n-- 4. Forward Priority (EX/MEM >MEM/WB) --");
            check(32'h0C, 32'h00000006, "FwdPri: x10=x9+x0=6 (EX/MEM fwd)");

            $display("\n-- 5. Store Data Forwarding --");
            check(32'h10, 32'h00000006, "StoreFwd: DM[BASE+16]=6");
            check(32'h14, 32'h00000006, "StoreReLd: DM[BASE+20]=6");

            $display("\n-- 6. Branch NOT-taken --");
            check(32'h18, 32'h00000100, "BEQ NT: DM[24]=0x100");
            check(32'h1C, 32'h00000400, "BNE T: DM[28]=0x400");
            check(32'h20, 32'h00000500, "BNE NT: DM[32]=0x500");
            check(32'h24, 32'h00000800, "BLT T: DM[36]=0x800");
            check(32'h28, 32'h00000900, "BLT NT: DM[40]=0x900");
            check(32'h2C, 32'h00000111, "BGE NT: DM[44]=0x111");
            check(32'h30, 32'h00000333, "BLTU NT: DM[48]=0x333");
            check(32'h34, 32'h00000555, "BGEU NT: DM[52]=0x555");

            $display("\n-- 7. Branch TAKEN + Flush --");
            check(32'h38, 32'h00000000, "BEQ always: flushed 0xBAD→DM=0");
            check(32'h3C, 32'h00000888, "BGE T: DM[60]=0x888");
            check(32'h40, 32'h00000AAA, "BLTU T: DM[64]=0xAAA");
            check(32'h44, 32'h00000CCC, "BGEU T: DM[68]=0xCCC");

            $display("\n-- 8. BEQ taken (real regs) --");
            check(32'h48, 32'h0000BEEF, "BEQ reg: x1==x2 (0xA5A5), x3=0xBEEF");

            $display("\n-- 9. Dual-Source Forward --");
            check(32'h4C, 32'h00000046, "DualFwd: x6=x4(35)+x5(35)=70");

            $display("\n-- 10. Shift Truncation B[4:0] --");
            check(32'h50, 32'h80000000, "SLL shift32: 0x80000000<<0=0x80000000");
            check(32'h54, 32'h80000000, "SRL shift32: 0x80000000>>0=0x80000000");
            check(32'h58, 32'h80000000, "SRA shift32: 0x80000000>>>0=0x80000000");
            check(32'h5C, 32'h00000000, "SLL shift33: 0x80000000<<1=0");
            check(32'h60, 32'h40000000, "SRL shift33: 0x80000000>>1=0x40000000");
            check(32'h64, 32'hC0000000, "SRA shift33: 0x80000000>>>1=0xC0000000");

            $display("\n-- 11. SB/SH + LB/LH/LBU/LHU --");
            check(32'h68, 32'hFFFFFFAB, "LB sign-ext 0xAB");
            check(32'h6C, 32'h000000AB, "LBU zero-ext 0xAB");
            check(32'h70, 32'h00001234, "LH sign-ext 0x1234");
            check(32'h74, 32'h00001234, "LHU zero-ext 0x1234");

            $display("\n-- 12. x0 Write-Protect --");
            check(32'h78, 32'h0000DEAD, "x0 protection: DM[120]=0xDEAD");
            check(32'h7C, 32'h00000000, "x0+x0→x9=0: DM[124]=0");

            $display("\n-- 13. JAL Link + Nested Calls --");
            $write("JAL link addr: DM[0x%04X] = %08X ... ", BASE+128, U_DM.dmem[BASE_IDX + 32]);
            if (U_DM.dmem[BASE_IDX + 32] !== 32'h0) begin
                $display("[PASS] JAL link addr non-zero (PC+4)");
            end else begin
                $display("[FAIL] JAL link addr is zero!");
                err = err + 1;
            end
            check(32'h84, 32'h00000123, "After JAL: x12=0x123");
            check(32'h88, 32'h000000AA, "func1: x13=0xAA");
            check(32'h8C, 32'h000000BB, "func1 after func2: x15=0xBB");
            check(32'h90, 32'h000000CC, "func2: x16=0xCC");

            $display("\n==========================================");
            if (err == 0)
                $display("=== ALL TESTS PASSED ===");
            else
                $display("=== %0d FAILURES ===", err);
            $display("==========================================");
            $finish;
        end
    endtask

endmodule
