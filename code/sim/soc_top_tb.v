// soc_top_tb — Vivado 仿真: sw_i[6]=1, 观察 PC 轨迹
// 用法: Vivado 中设为 Simulation Source, 与 soc_top + IP 一起仿真
// 运行: Tcl 中 run -all (或指定时长 run 10ms)
`timescale 1ns / 1ps

module soc_top_tb();

    reg         clk, rstn;
    reg  [4:0]  btn_i;
    reg  [15:0] sw_i;
    wire [7:0]  disp_an_o, disp_seg_o;
    wire [15:0] led_o;

    soc_top U_SOC (
        .clk(clk), .rstn(rstn), .btn_i(btn_i), .sw_i(sw_i),
        .disp_an_o(disp_an_o), .disp_seg_o(disp_seg_o), .led_o(led_o)
    );

    // ---- 100MHz 时钟 ----
    initial clk = 0;
    always #5 clk = ~clk;   // T=10ns, 100MHz

    // ---- 仿真主体 ----
    integer cycle;
    reg [31:0] prev_pc;

    initial begin
        // 初始化
        rstn    = 1'b0;
        btn_i   = 5'b0;
        sw_i    = 16'b0;
        cycle   = 0;
        prev_pc = 32'hffff_ffff;

        // sw_i[6]=1, 其余为 0
        // → SW[7:5]=010 → Multi_8CH32 channel 2 = inst_in
        // → SW[2]=0 → Clk_CPU = 6.25MHz (快时钟)
        // → SW[0]=0 → 文本模式
        sw_i[6] = 1'b1;

        // 复位释放
        #200 rstn = 1'b1;

        $display("============================================");
        $display(" soc_top simulation — testac.coe");
        $display(" sw_i[6]=1 (SW[7:5]=010 → inst_in channel)");
        $display(" CPU clock = 6.25MHz");
        $display("============================================");
        $display("");
        $display(" Cycle | Time        | PC       | inst_in   | mem_w | Addr_out  ");
        $display("-------|-------------|----------|-----------|-------|-----------");
    end

    // ---- 每 CPU 周期打印 PC / 指令 ----
    always @(posedge U_SOC.Clk_CPU) begin
        if (rstn) begin
            cycle = cycle + 1;
            if (U_SOC.PC != prev_pc || U_SOC.mem_w) begin
                $display(" %5d | %12t | 0x%06X | 0x%08X | %b     | 0x%08X",
                         cycle, $time, U_SOC.PC, U_SOC.inst_in,
                         U_SOC.mem_w, U_SOC.Addr_out);
                prev_pc = U_SOC.PC;
            end
        end
    end

    // ---- 长时间运行 / 无限循环 ----
    // 在 Vivado Tcl 中用 run -all 或 run 10ms 控制
    // 这里设一个很大的超时 (100ms = 100M 周期, 约 1000 万条 CPU 指令 @ 100MHz/2^4)

    // 如果需要在仿真器看到 Disp_num (数码管显示值):
    // 可在 Vivado wave window 中观察:
    //   U_SOC.PC          — 完整 PC
    //   U_SOC.inst_in     — 当前指令
    //   U_SOC.Addr_out    — ALU 输出 / 访存地址
    //   U_SOC.Data_out    — 写数据
    //   U_SOC.Data_in     — 读数据
    //   U_SOC.mem_w       — DM 写使能
    //   U_SOC.Disp_num    — 数码管显示值 (8 位十六进制)

endmodule
