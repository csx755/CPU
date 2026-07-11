`timescale 1ns / 1ps

// =============================================================================
// reverb.v — 简单混响效果器
// =============================================================================
//   原理: 环形缓冲区延迟线 + 反馈
//   固定参数:
//     延迟: 400 samples @ 7812Hz ≈ 50ms
//     反馈: 0.3 (feedback_shift = 2, 即 >>2)
//     干湿: 50/50
//
//   mixed = dry + wet
//   wet = delay_buf[wr_ptr] + delay_buf[wr_ptr] >> 2 (反馈)
// =============================================================================

module reverb (
    input             clk,
    input             rst,
    input      [9:0]  audio_in,    // 0~1023, 中心值512
    output reg [9:0]  audio_out    // 0~1023, 中心值512
);

    // ===== 延迟线参数 =====
    localparam DELAY_LEN = 400;  // 50ms @ 7812Hz
    localparam LOG2_DELAY = 9;   // ceil(log2(400))

    // ===== 环形缓冲区 =====
    reg [9:0] delay_buf [0:DELAY_LEN-1];
    reg [LOG2_DELAY-1:0] wr_ptr;

    // ===== 读指针: 延迟400个样本 =====
    wire [LOG2_DELAY-1:0] rd_ptr = wr_ptr - 9'd400;

    // ===== 读取延迟信号 =====
    wire [9:0] delayed = delay_buf[rd_ptr];

    // ===== 写入: 当前输入 + 延迟信号的反馈 =====
    // feedback = delayed >> 2 (30%反馈)
    wire [9:0] feedback = {2'd0, delayed[9:2]};
    // 写入值 = 输入 + 反馈, 饱和
    wire [10:0] wr_sum = {1'd0, audio_in} + {1'd0, feedback};
    wire [9:0] wr_data = (wr_sum[10]) ? 10'd1023 : wr_sum[9:0];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
        end else begin
            delay_buf[wr_ptr] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // ===== 输出: 原声 + 延迟信号, 50/50 混合 =====
    // mixed = (audio_in + delayed) / 2
    wire [10:0] mix_sum = {1'd0, audio_in} + {1'd0, delayed};

    always @(posedge clk or posedge rst) begin
        if (rst)
            audio_out <= 10'd512;
        else
            audio_out <= mix_sum[10:1];  // 右移1位 = 除以2
    end

endmodule
