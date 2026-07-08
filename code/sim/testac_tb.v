// testac_tb — 加载 testac.coe (转 .dat), SCPU 直连, 打 PC 轨迹
// 用法: sw_i[6]=1 对应 Cpu_data4bus 通道, 本文主要看 PC 变化
// 编译: iverilog -o testac_sim -I ../rtl ../rtl/*.v testac_tb.v
// 运行: vvp -n testac_sim
`timescale 1ns / 1ps

module testac_tb();

    reg clk, rst;
    reg [31:0] inst_in;
    wire [31:0] Data_in;
    wire mem_w;
    wire [31:0] PC, Addr_out, Data_out;
    wire [2:0] dm_ctrl;

    SCPU U_SCPU (
        .clk(clk), .reset(rst), .MIO_ready(1'b1),
        .inst_in(inst_in), .Data_in(Data_in), .INT(1'b0),
        .mem_w(mem_w), .CPU_MIO(), .PC_out(PC),
        .Addr_out(Addr_out), .Data_out(Data_out), .dm_ctrl(dm_ctrl),
        .reg_sel(5'd0), .reg_data()
    );

    // ROM: 1024 x 32-bit, 从 .dat 加载
    reg [31:0] rom [0:1023];
    integer rom_i;
    initial begin
        for (rom_i = 0; rom_i < 1024; rom_i = rom_i + 1)
            rom[rom_i] = 32'h00000013; // NOP fill
        $readmemh("testac.dat", rom);
    end
    assign inst_in = rom[PC[11:2]];

    // 简易 DM: word 读写 (与 testac.coe 预期一致, 主要用到 0x000~0xFFF 范围)
    reg [31:0] dmem [0:1023];
    integer dm_i;
    initial for (dm_i = 0; dm_i < 1024; dm_i = dm_i + 1) dmem[dm_i] = 32'd0;
    wire [9:0] dm_word_addr = Addr_out[11:2];
    assign Data_in = dmem[dm_word_addr];
    always @(posedge clk) if (mem_w) dmem[dm_word_addr] <= Data_out;

    always #50 clk = ~clk;

    // ---- 主仿真 ----
    integer cycle;
    integer total;
    initial begin
        clk = 0; rst = 1; cycle = 0;
        total = 3000;  // 3000 周期, 覆盖多次循环
        #200 rst = 0;
        $display("=== testac.coe SCPU Trace (SW[6]=1) ===\n");
        $display(" Cycle | PC     | inst      | mem_w | Addr_out   | Data_out");
        $display("-------|--------|-----------|-------|------------|----------");
    end

    always @(posedge clk) begin
        if (!rst) begin
            cycle = cycle + 1;
            $display(" %5d | 0x%04X | 0x%08X | %b     | 0x%08X | 0x%08X",
                     cycle, PC, inst_in, mem_w, Addr_out, Data_out);
            if (cycle >= total) begin
                $display("\n=== Done %0d cycles, Final PC=0x%04X ===", cycle, PC);
                $finish;
            end
        end
    end

endmodule
