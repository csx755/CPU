// trace_tb — 输出 1000 条指令执行跟踪，与 testac模拟.txt 对照
`timescale 1ns / 1ps

module trace_tb();

    reg clk, rst;
    wire [31:0] PC, Addr_out, Data_out, inst_in, Data_in;
    wire mem_w;
    wire [2:0] dm_ctrl;

    SCPU U_SCPU (
        .clk(clk), .reset(rst), .MIO_ready(1'b1), .inst_in(inst_in), .Data_in(Data_in),
        .INT(1'b0), .mem_w(mem_w), .CPU_MIO(), .PC_out(PC), .Addr_out(Addr_out),
        .Data_out(Data_out), .dm_ctrl(dm_ctrl),
        .reg_sel(5'd0), .reg_data()
    );

    ROM U_ROM (.a(PC[11:2]), .spo(inst_in));

    // 数据存储器 — 使用 dm.v 支持 byte/halfword/word 读写 (SB/SH/LB/LH/LBU/LHU)
    dm U_DM (
        .clk(clk),
        .DMWr(mem_w),
        .addr(Addr_out[8:0]),   // 字节地址 (512B 范围)
        .din(Data_out),
        .dout(Data_in),
        .DMType(dm_ctrl)
    );

    always #50 clk = ~clk;  // 10MHz

    integer tick;
    reg [31:0] last_pc;
    reg loop_detected;

    initial begin
        clk = 0; rst = 1; tick = 0; last_pc = 0; loop_detected = 0;
        #200 rst = 0;
        $display("=== 1000 条指令执行跟踪 ===");
        $display("格式: 周期 PC(instr#) inst_hex 对应testac模拟.txt行号");
        $display("========================================");

        repeat(1000) begin
            @(posedge clk);
            tick = tick + 1;

            // 计算对应 testac模拟.txt 的指令序号 (PC>>2)
            // 检测 PC 重复 (可能陷入死循环)
            if (tick > 2 && last_pc == PC) begin
                if (!loop_detected) begin
                    $display("*** 警告: PC 连续重复! PC=%h, 周期=%0d ***", PC, tick);
                    loop_detected = 1;
                end
            end else begin
                loop_detected = 0;
            end
            last_pc = PC;

            // 输出格式: 周期 PC instr inst_in
            $display("%0d %h %h", tick, PC, inst_in);
        end

        $display("\n=== 1000 条指令执行完成 ===");
        $display("PC=%h", PC);
        $finish;
    end

endmodule
