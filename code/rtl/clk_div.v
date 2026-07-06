// 时钟分频器：100MHz → ~2Hz (慢速) / 按钮单步
module clk_div(
    input  clk_100mhz,       // 100MHz 板载时钟
    input  rst,
    input  step_mode,        // 0=连续慢速, 1=按钮单步
    input  step_btn,         // 单步按钮
    output cpu_clk           // CPU 时钟
);
    // 100MHz → 2Hz: 50,000,000 分频 → 26-bit 计数器
    reg [25:0] counter;
    wire slow_clk;
    assign slow_clk = counter[25];  // 最高位 ≈ 1.49Hz

    always @(posedge clk_100mhz or posedge rst) begin
        if (rst)
            counter <= 26'b0;
        else
            counter <= counter + 1;
    end

    // 模式选择
    assign cpu_clk = step_mode ? step_btn : slow_clk;

endmodule
