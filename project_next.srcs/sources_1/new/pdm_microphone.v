`timescale 1ns / 1ps

// =============================================================================
// pdm_microphone.v — PDM 麦克风输入模块 (Nexys A7 板载, 计数器版)
// =============================================================================
//   M_CLK  → 2MHz 时钟输出
//   M_DATA ← PDM 数据输入
//   M_LRSEL → 0 (左声道)
//
//   解调: 256-bit 窗口计数器 (8bit分辨率, ~7.8kHz采样率)
//   输出: 10位PCM (0~1023, 中心值512)
//   gain: 0=1x, 1=2x, 2=4x, 3=8x, 4=16x
// =============================================================================

module pdm_microphone (
    input             clk,        // 100MHz
    input             rst,
    input             M_DATA,
    output reg        M_CLK,
    output            M_LRSEL,
    input      [2:0]  gain,       // 增益控制
    output reg [9:0]  mic_sample
);

    // ===== M_CLK: 100MHz → 2MHz =====
    reg [5:0] clk_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt <= 0;
            M_CLK   <= 0;
        end else if (clk_cnt >= 24) begin
            clk_cnt <= 0;
            M_CLK   <= ~M_CLK;
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end

    assign M_LRSEL = 1'b0;

    // ===== M_CLK 上升沿检测 =====
    wire m_clk_rise = (clk_cnt == 24) && (M_CLK == 0);

    // ===== PDM 计数器解调: 256-bit 窗口 =====
    reg [7:0] bit_cnt;
    reg [7:0] ones_cnt;
    reg [7:0] ones_latch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bit_cnt    <= 0;
            ones_cnt   <= 0;
            ones_latch <= 0;
        end else if (m_clk_rise) begin
            if (bit_cnt == 8'd255) begin
                ones_latch <= (M_DATA) ? ones_cnt + 8'd1 : ones_cnt;
                ones_cnt   <= (M_DATA) ? 8'd1 : 8'd0;
                bit_cnt    <= 8'd0;
            end else begin
                if (M_DATA)
                    ones_cnt <= ones_cnt + 8'd1;
                bit_cnt <= bit_cnt + 8'd1;
            end
        end
    end

    // ===== 去直流 + 增益 + 映射到10位 =====
    wire signed [8:0]  dc_removed = {1'b0, ones_latch} - 9'sd128;
    wire signed [12:0] gained = dc_removed * $signed({1'b0, 3'd1, gain[1:0]});
    wire signed [12:0] final_val = gain[2] ? {gained[11:0], 1'b0} : gained;
    wire signed [13:0] result = final_val + 14'sd512;

    always @(posedge clk or posedge rst) begin
        if (rst)
            mic_sample <= 10'd512;
        else if (result[13])
            mic_sample <= 10'd0;
        else if (result > 14'sd1023)
            mic_sample <= 10'd1023;
        else
            mic_sample <= result[9:0];
    end

endmodule
