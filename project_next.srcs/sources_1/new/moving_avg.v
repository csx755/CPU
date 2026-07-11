`timescale 1ns / 1ps

// =============================================================================
// moving_avg.v — 移动平均滤波器
// =============================================================================
//   对最近 N 个样本取平均，平滑波形去噪
//   N=16 时截止频率 ≈ fs/(2*N) ≈ 976Hz
//   N=32 时截止频率 ≈ fs/(2*N) ≈ 488Hz
//
//   实现: 环形缓冲区 + 累加器
//   每次新样本进来: sum = sum + new - oldest
//   输出: sum / N (右移 log2(N) 位)
// =============================================================================

module moving_avg #(
    parameter N = 16,              // 平均窗口大小 (必须是2的幂)
    parameter LOG2_N = 4           // log2(N)
)(
    input             clk,
    input             rst,
    input      [9:0]  audio_in,    // 0~1023
    output reg [9:0]  audio_out    // 0~1023
);

    // ===== 环形缓冲区 =====
    reg [9:0] buffer [0:N-1];
    reg [LOG2_N-1:0] wr_ptr;

    // ===== 累加器 (足够位宽防止溢出) =====
    // 最大值 = 1023 * N, 需要 10 + LOG2_N 位
    reg [9+LOG2_N:0] sum;

    // ===== 上一次移出的值 =====
    wire [9:0] oldest = buffer[wr_ptr];

    // ===== 更新逻辑 =====
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
        end else begin
            // 写入新样本
            buffer[wr_ptr] <= audio_in;
            // 更新累加器: sum = sum + new - old
            sum <= sum + {10'd0, audio_in} - {10'd0, oldest};
            // 移动指针
            wr_ptr <= wr_ptr + 1;
        end
    end

    // ===== 输出: 右移取平均 =====
    always @(posedge clk or posedge rst) begin
        if (rst)
            audio_out <= 10'd512;
        else
            audio_out <= sum[9+LOG2_N:LOG2_N];
    end

endmodule
