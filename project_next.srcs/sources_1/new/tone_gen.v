`timescale 1ns / 1ps

// PWM 音频发生器
// 输入：频率控制字（半周期计数值）
// 输出：PWM 方波
//
// 音符频率表（100MHz 时钟）：
//   C4=261.63Hz → 191106    D4=293.66Hz → 170294
//   E4=329.63Hz → 151686    F4=349.23Hz → 143168
//   G4=392.00Hz → 127551    A4=440.00Hz → 113636
//   B4=493.88Hz → 101240    C5=523.25Hz →  95554
//   D5=587.33Hz →  85147    E5=659.25Hz →  75842

module tone_gen(
    input        clk,       // 100MHz 系统时钟
    input        rst,
    input [16:0] freq_div,  // 半周期计数值（0=静音）
    output reg   tone       // PWM 输出
);

    reg [16:0] counter;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            tone    <= 0;
        end else if (freq_div == 0) begin
            // freq_div=0 表示静音
            counter <= 0;
            tone    <= 0;
        end else if (counter >= freq_div) begin
            counter <= 0;
            tone    <= ~tone;
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
