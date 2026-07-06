// Nexys4 A7-100T 板级顶层模块
// 功能：拨码开关选寄存器，数码管+LED 显示寄存器值
//
// 外设映射：
//   sw[4:0]  → 选择要显示的寄存器号
//   sw[14]   → 0=连续慢速(~2Hz), 1=按钮单步
//   sw[15]   → 系统复位 (与 btnC OR)
//   led[15:0] → 显示 reg_data[15:0]
//   8位7段数码管 → 显示 reg_data[31:0] (8个十六进制数字)

module nexys4_top(
    input         clk,             // 100MHz 板载时钟
    input         rstn,            // CPU 复位按钮 (低有效)
    input  [15:0] sw_i,            // 16 个拨码开关
    output [15:0] led_o,           // 16 个 LED
    output [7:0]  disp_seg_o,      // 7段数码管段码 (CA-CG+DP)
    output [7:0]  disp_an_o        // 7段数码管位选 (AN0-AN7)
);

    // === 时钟分频 ===
    // 扫描时钟: 100MHz / 2^13 ≈ 12kHz
    reg [12:0] scan_cnt;
    wire scan_clk;
    always @(posedge clk) scan_cnt <= scan_cnt + 1;
    assign scan_clk = scan_cnt[12];

    // CPU 时钟: 慢速 2Hz → 分频器
    wire cpu_clk;
    wire rst_cpu = sw_i[15] | (~rstn);  // sw[15]或按钮均可复位

    clk_div U_CLKDIV(
        .clk_100mhz(clk),
        .rst(rst_cpu),
        .step_mode(sw_i[14]),
        .step_btn(sw_i[14]),  // sw[14]作为模式切换(低=慢速,高=单步)
        .cpu_clk(cpu_clk)
    );

    // === CPU 核心 ===
    wire [31:0] reg_data;
    wire [31:0] PC, instr;

    sccomp U_SCCOMP(
        .clk(cpu_clk),
        .rstn(~rst_cpu),          // sccomp 内部 rst = ~rstn
        .reg_sel(sw_i[4:0]),
        .reg_data(reg_data),
        .PC(PC),
        .instr(instr)
    );

    // === 数码管显示 ===
    seg7_display U_SEG7(
        .clk(scan_clk),
        .rst(rst_cpu),
        .data(reg_data),
        .seg(disp_seg_o),
        .an(disp_an_o)
    );

    // === LED 显示 ===
    assign led_o = reg_data[15:0];

endmodule
