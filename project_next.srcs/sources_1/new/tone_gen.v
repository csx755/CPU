`timescale 1ns / 1ps

// DDS 正弦波采样发生器
// freq_word = 相位步长 (32位, 100MHz时钟)
//   输出频率 = freq_word * 100MHz / 2^32
// 正弦表: 256点 x 10位, 输出 0~1023 (中心值512)
// PWM 生成移到 top.v

module tone_gen(
    input             clk,
    input             rst,
    input      [31:0] freq_word,
    output reg [9:0]  sample
);

    // ===== 32位相位累加器 =====
    reg [31:0] phase;
    always @(posedge clk or posedge rst) begin
        if (rst) phase <= 0;
        else     phase <= phase + freq_word;
    end

    // ===== 正弦查找表 (256点, 10位输出) =====
    // sine[i] = round(512 + 511 * sin(2*pi*i/256))
    // 用 phase[31:24] 索引 (高8位)
    always @(*) begin
        case (phase[31:24])
            8'h00: sample = 10'd512; 8'h01: sample = 10'd525;
            8'h02: sample = 10'd537; 8'h03: sample = 10'd550;
            8'h04: sample = 10'd562; 8'h05: sample = 10'd575;
            8'h06: sample = 10'd587; 8'h07: sample = 10'd599;
            8'h08: sample = 10'd612; 8'h09: sample = 10'd624;
            8'h0A: sample = 10'd636; 8'h0B: sample = 10'd648;
            8'h0C: sample = 10'd660; 8'h0D: sample = 10'd672;
            8'h0E: sample = 10'd684; 8'h0F: sample = 10'd696;
            8'h10: sample = 10'd708; 8'h11: sample = 10'd719;
            8'h12: sample = 10'd730; 8'h13: sample = 10'd742;
            8'h14: sample = 10'd753; 8'h15: sample = 10'd764;
            8'h16: sample = 10'd775; 8'h17: sample = 10'd785;
            8'h18: sample = 10'd796; 8'h19: sample = 10'd806;
            8'h1A: sample = 10'd816; 8'h1B: sample = 10'd826;
            8'h1C: sample = 10'd836; 8'h1D: sample = 10'd846;
            8'h1E: sample = 10'd855; 8'h1F: sample = 10'd864;
            8'h20: sample = 10'd873; 8'h21: sample = 10'd882;
            8'h22: sample = 10'd891; 8'h23: sample = 10'd899;
            8'h24: sample = 10'd907; 8'h25: sample = 10'd915;
            8'h26: sample = 10'd922; 8'h27: sample = 10'd930;
            8'h28: sample = 10'd937; 8'h29: sample = 10'd944;
            8'h2A: sample = 10'd950; 8'h2B: sample = 10'd957;
            8'h2C: sample = 10'd963; 8'h2D: sample = 10'd968;
            8'h2E: sample = 10'd974; 8'h2F: sample = 10'd979;
            8'h30: sample = 10'd984; 8'h31: sample = 10'd989;
            8'h32: sample = 10'd993; 8'h33: sample = 10'd997;
            8'h34: sample = 10'd1001; 8'h35: sample = 10'd1004;
            8'h36: sample = 10'd1008; 8'h37: sample = 10'd1011;
            8'h38: sample = 10'd1013; 8'h39: sample = 10'd1015;
            8'h3A: sample = 10'd1017; 8'h3B: sample = 10'd1019;
            8'h3C: sample = 10'd1021; 8'h3D: sample = 10'd1022;
            8'h3E: sample = 10'd1022; 8'h3F: sample = 10'd1023;
            8'h40: sample = 10'd1023; 8'h41: sample = 10'd1023;
            8'h42: sample = 10'd1022; 8'h43: sample = 10'd1022;
            8'h44: sample = 10'd1021; 8'h45: sample = 10'd1019;
            8'h46: sample = 10'd1017; 8'h47: sample = 10'd1015;
            8'h48: sample = 10'd1013; 8'h49: sample = 10'd1011;
            8'h4A: sample = 10'd1008; 8'h4B: sample = 10'd1004;
            8'h4C: sample = 10'd1001; 8'h4D: sample = 10'd997;
            8'h4E: sample = 10'd993; 8'h4F: sample = 10'd989;
            8'h50: sample = 10'd984; 8'h51: sample = 10'd979;
            8'h52: sample = 10'd974; 8'h53: sample = 10'd968;
            8'h54: sample = 10'd963; 8'h55: sample = 10'd957;
            8'h56: sample = 10'd950; 8'h57: sample = 10'd944;
            8'h58: sample = 10'd937; 8'h59: sample = 10'd930;
            8'h5A: sample = 10'd922; 8'h5B: sample = 10'd915;
            8'h5C: sample = 10'd907; 8'h5D: sample = 10'd899;
            8'h5E: sample = 10'd891; 8'h5F: sample = 10'd882;
            8'h60: sample = 10'd873; 8'h61: sample = 10'd864;
            8'h62: sample = 10'd855; 8'h63: sample = 10'd846;
            8'h64: sample = 10'd836; 8'h65: sample = 10'd826;
            8'h66: sample = 10'd816; 8'h67: sample = 10'd806;
            8'h68: sample = 10'd796; 8'h69: sample = 10'd785;
            8'h6A: sample = 10'd775; 8'h6B: sample = 10'd764;
            8'h6C: sample = 10'd753; 8'h6D: sample = 10'd742;
            8'h6E: sample = 10'd730; 8'h6F: sample = 10'd719;
            8'h70: sample = 10'd708; 8'h71: sample = 10'd696;
            8'h72: sample = 10'd684; 8'h73: sample = 10'd672;
            8'h74: sample = 10'd660; 8'h75: sample = 10'd648;
            8'h76: sample = 10'd636; 8'h77: sample = 10'd624;
            8'h78: sample = 10'd612; 8'h79: sample = 10'd599;
            8'h7A: sample = 10'd587; 8'h7B: sample = 10'd575;
            8'h7C: sample = 10'd562; 8'h7D: sample = 10'd550;
            8'h7E: sample = 10'd537; 8'h7F: sample = 10'd525;
            8'h80: sample = 10'd512; 8'h81: sample = 10'd499;
            8'h82: sample = 10'd487; 8'h83: sample = 10'd474;
            8'h84: sample = 10'd462; 8'h85: sample = 10'd449;
            8'h86: sample = 10'd437; 8'h87: sample = 10'd425;
            8'h88: sample = 10'd412; 8'h89: sample = 10'd400;
            8'h8A: sample = 10'd388; 8'h8B: sample = 10'd376;
            8'h8C: sample = 10'd364; 8'h8D: sample = 10'd352;
            8'h8E: sample = 10'd340; 8'h8F: sample = 10'd328;
            8'h90: sample = 10'd316; 8'h91: sample = 10'd305;
            8'h92: sample = 10'd294; 8'h93: sample = 10'd282;
            8'h94: sample = 10'd271; 8'h95: sample = 10'd260;
            8'h96: sample = 10'd249; 8'h97: sample = 10'd239;
            8'h98: sample = 10'd228; 8'h99: sample = 10'd218;
            8'h9A: sample = 10'd208; 8'h9B: sample = 10'd198;
            8'h9C: sample = 10'd188; 8'h9D: sample = 10'd178;
            8'h9E: sample = 10'd169; 8'h9F: sample = 10'd160;
            8'hA0: sample = 10'd151; 8'hA1: sample = 10'd142;
            8'hA2: sample = 10'd133; 8'hA3: sample = 10'd125;
            8'hA4: sample = 10'd117; 8'hA5: sample = 10'd109;
            8'hA6: sample = 10'd102; 8'hA7: sample = 10'd94;
            8'hA8: sample = 10'd87;  8'hA9: sample = 10'd80;
            8'hAA: sample = 10'd74;  8'hAB: sample = 10'd67;
            8'hAC: sample = 10'd61;  8'hAD: sample = 10'd56;
            8'hAE: sample = 10'd50;  8'hAF: sample = 10'd45;
            8'hB0: sample = 10'd40;  8'hB1: sample = 10'd35;
            8'hB2: sample = 10'd31;  8'hB3: sample = 10'd27;
            8'hB4: sample = 10'd23;  8'hB5: sample = 10'd20;
            8'hB6: sample = 10'd16;  8'hB7: sample = 10'd13;
            8'hB8: sample = 10'd11;  8'hB9: sample = 10'd9;
            8'hBA: sample = 10'd7;   8'hBB: sample = 10'd5;
            8'hBC: sample = 10'd3;   8'hBD: sample = 10'd2;
            8'hBE: sample = 10'd2;   8'hBF: sample = 10'd1;
            8'hC0: sample = 10'd1;   8'hC1: sample = 10'd1;
            8'hC2: sample = 10'd2;   8'hC3: sample = 10'd2;
            8'hC4: sample = 10'd3;   8'hC5: sample = 10'd5;
            8'hC6: sample = 10'd7;   8'hC7: sample = 10'd9;
            8'hC8: sample = 10'd11;  8'hC9: sample = 10'd13;
            8'hCA: sample = 10'd16;  8'hCB: sample = 10'd20;
            8'hCC: sample = 10'd23;  8'hCD: sample = 10'd27;
            8'hCE: sample = 10'd31;  8'hCF: sample = 10'd35;
            8'hD0: sample = 10'd40;  8'hD1: sample = 10'd45;
            8'hD2: sample = 10'd50;  8'hD3: sample = 10'd56;
            8'hD4: sample = 10'd61;  8'hD5: sample = 10'd67;
            8'hD6: sample = 10'd74;  8'hD7: sample = 10'd80;
            8'hD8: sample = 10'd87;  8'hD9: sample = 10'd94;
            8'hDA: sample = 10'd102; 8'hDB: sample = 10'd109;
            8'hDC: sample = 10'd117; 8'hDD: sample = 10'd125;
            8'hDE: sample = 10'd133; 8'hDF: sample = 10'd142;
            8'hE0: sample = 10'd151; 8'hE1: sample = 10'd160;
            8'hE2: sample = 10'd169; 8'hE3: sample = 10'd178;
            8'hE4: sample = 10'd188; 8'hE5: sample = 10'd198;
            8'hE6: sample = 10'd208; 8'hE7: sample = 10'd218;
            8'hE8: sample = 10'd228; 8'hE9: sample = 10'd239;
            8'hEA: sample = 10'd249; 8'hEB: sample = 10'd260;
            8'hEC: sample = 10'd271; 8'hED: sample = 10'd282;
            8'hEE: sample = 10'd294; 8'hEF: sample = 10'd305;
            8'hF0: sample = 10'd316; 8'hF1: sample = 10'd328;
            8'hF2: sample = 10'd340; 8'hF3: sample = 10'd352;
            8'hF4: sample = 10'd364; 8'hF5: sample = 10'd376;
            8'hF6: sample = 10'd388; 8'hF7: sample = 10'd400;
            8'hF8: sample = 10'd412; 8'hF9: sample = 10'd425;
            8'hFA: sample = 10'd437; 8'hFB: sample = 10'd449;
            8'hFC: sample = 10'd462; 8'hFD: sample = 10'd474;
            8'hFE: sample = 10'd487; 8'hFF: sample = 10'd499;
        endcase
    end

endmodule
