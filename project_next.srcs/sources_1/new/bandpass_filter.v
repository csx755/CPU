`timescale 1ns / 1ps

// =============================================================================
// bandpass_filter.v — 带通滤波器 (100Hz ~ 3500Hz, 人声频段)
// =============================================================================
//   一阶高通 (100Hz) + 一阶低通 (3500Hz) 级联
//   高通: 去掉低频嗡嗡/直流偏移/桌面振动
//   低通: 去掉高频噪声
//
//   fs ≈ 7812 Hz (2MHz / 256)
//   alpha_hp = round(100 / 7812 * 65536) ≈ 839
//   alpha_lp = round(3500 / 7812 * 65536) ≈ 29361
// =============================================================================

module bandpass_filter (
    input             clk,
    input             rst,
    input      [9:0]  audio_in,    // 0~1023, 中心值512
    output reg [9:0]  audio_out    // 0~1023, 中心值512
);

    // ===== 转为有符号 (减去中心值) =====
    wire signed [10:0] x = {1'b0, audio_in} - 11'd512;

    // ===== 高通滤波器: fc ≈ 100Hz =====
    localparam signed [15:0] ALPHA_HP = 16'sd839;

    reg signed [25:0] y_hp;  // Q10.16

    wire signed [25:0] diff_hp = {x, 16'd0} - y_hp;
    wire signed [41:0] update_hp = diff_hp * ALPHA_HP;

    always @(posedge clk or posedge rst) begin
        if (rst)
            y_hp <= 0;
        else
            y_hp <= y_hp + update_hp[41:16];
    end

    wire signed [10:0] hp_out = y_hp[25:16];

    // ===== 低通滤波器: fc ≈ 3500Hz =====
    localparam signed [15:0] ALPHA_LP = 16'sd29361;

    reg signed [25:0] y_lp;  // Q10.16

    wire signed [25:0] diff_lp = {hp_out, 16'd0} - y_lp;
    wire signed [41:0] update_lp = diff_lp * ALPHA_LP;

    always @(posedge clk or posedge rst) begin
        if (rst)
            y_lp <= 0;
        else
            y_lp <= y_lp + update_lp[41:16];
    end

    // ===== 输出: 转回无符号 + 饱和 =====
    wire signed [10:0] bp_out = y_lp[25:16];
    wire signed [11:0] result = bp_out + 12'sd512;

    always @(posedge clk or posedge rst) begin
        if (rst)
            audio_out <= 10'd512;
        else if (result[11])
            audio_out <= 10'd0;
        else if (result > 12'sd1023)
            audio_out <= 10'd1023;
        else
            audio_out <= result[9:0];
    end

endmodule
