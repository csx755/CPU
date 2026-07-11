`timescale 1ns / 1ps

// =============================================================================
// audio_mixer.v — 音频混合模块 (伴奏 + 麦克风)
// =============================================================================
//   输入:
//     accompaniment [9:0] — 伴奏信号 (0~1023, 中心值512)
//     microphone    [9:0] — 麦克风信号 (0~1023, 中心值512)
//     vol_acc [2:0]       — 伴奏音量 (0=静音, 7=100%)
//     vol_mic [2:0]       — 麦克风音量 (0=静音, 7=100%)
//
//   输出:
//     mixed [9:0]         — 混合后信号 (0~1023, 中心值512)
//
//   原理:
//     1. 将无符号转换为有符号 (减去中心值512)
//     2. 分别乘以音量系数
//     3. 饱和加法
//     4. 转换回无符号
// =============================================================================

module audio_mixer (
    input             clk,
    input             rst,
    input      [9:0]  accompaniment,  // 伴奏输入
    input      [9:0]  microphone,     // 麦克风输入
    input      [2:0]  vol_acc,        // 伴奏音量 (0-7)
    input      [2:0]  vol_mic,        // 麦克风音量 (0-7)
    output reg [9:0]  mixed           // 混合输出
);

    // ===== 音量系数计算 =====
    // vol=0: 0%, vol=1: 12.5%, vol=2: 25%, ..., vol=7: 87.5%
    // 系数 = vol / 8, 用移位实现

    wire signed [10:0] acc_signed = {1'b0, accompaniment} - 11'd512;
    wire signed [10:0] mic_signed = {1'b0, microphone} - 11'd512;

    // 伴奏乘以音量
    wire signed [13:0] acc_vol = acc_signed * $signed({1'b0, vol_acc});
    // 麦克风乘以音量
    wire signed [13:0] mic_vol = mic_signed * $signed({1'b0, vol_mic});

    // ===== 混合 (饱和加法) =====
    wire signed [14:0] sum = {acc_vol[13], acc_vol} + {mic_vol[13], mic_vol};

    // ===== 输出处理 =====
    // sum 范围: -4096 ~ +4095 (15位有符号)
    // 需要映射到 0 ~ 1023 (10位无符号)
    // sum / 8 + 512

    wire signed [14:0] adjusted = sum >>> 3;  // 除以8
    wire signed [11:0] result = adjusted[11:0] + 12'd512;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mixed <= 10'd512;
        end else begin
            // 饱和处理
            if (result[11])  // 负数
                mixed <= 10'd0;
            else if (result > 12'd1023)
                mixed <= 10'd1023;
            else
                mixed <= result[9:0];
        end
    end

endmodule
