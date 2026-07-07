module SPIO (
    input  wire         clk,        // ~Clk_CPU
    input  wire         rst,        // 高有效复位
    input  wire         EN,         // 写使能 (来自 MIO_BUS)
    input  wire [31:0]  P_Data,     // 外设数据总线
    output reg  [1:0]   counter_set,// 计数器通道选择
    output wire [15:0]  LED_out,    // LED 状态读回
    output reg  [15:0]  led,        // LED 实际输出
    output wire [13:0]  GPIOf0      // 预留 GPIO (恒0)
);

    assign LED_out = led;
    assign GPIOf0  = 14'b0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            led         <= 16'd0;
            counter_set <= 2'd0;
        end else if (EN) begin
            led         <= P_Data[15:0];
            counter_set <= P_Data[17:16];
        end
    end

endmodule
