// =============================================================================
// Enter — 按键/开关输入模块
// 功能：按键消抖 + 开关直通，替换原 Enter.edf 黑盒
// =============================================================================

module Enter(
    input           clk,            // 100MHz 系统时钟
    input  [4:0]    BTN,            // 5 个按键输入 (板子 btn_i)
    input  [15:0]   SW,             // 16 个拨码开关 (板子 sw_i)
    output [4:0]    BTN_out,        // 消抖后按键 → MIO_BUS.BTN
    output [15:0]   SW_out          // 直通开关 → MIO_BUS.SW
);

// =============================================================================
// 拨码开关：直通 (无弹跳)
// =============================================================================
assign SW_out = SW;

// =============================================================================
// 按键消抖：饱和计数器法
// 阈值 ≈ 10ms @ 100MHz → 20-bit 计数器
// =============================================================================
localparam DEBOUNCE_MAX = 20'd1_000_000;

reg [19:0] debounce_cnt [0:4];  // 5 个独立计数器
reg [4:0]  btn_stable;          // 消抖后稳定值

integer i;
always @(posedge clk) begin
    for (i = 0; i < 5; i = i + 1) begin
        if (BTN[i]) begin
            // 按键按下：计数到阈值后确认
            if (debounce_cnt[i] < DEBOUNCE_MAX)
                debounce_cnt[i] <= debounce_cnt[i] + 1'b1;
            else
                btn_stable[i] <= 1'b1;
        end else begin
            // 按键释放：立即清零
            debounce_cnt[i] <= 20'b0;
            btn_stable[i]  <= 1'b0;
        end
    end
end

assign BTN_out = btn_stable;

endmodule
