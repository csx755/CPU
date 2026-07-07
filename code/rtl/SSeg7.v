// SSeg7 — 8位7段数码管驱动
//   文本模式(SW0=0): Hexs[31:0] → 8位十六进制, 无调光, 高亮度
//   图形模式(SW0=1): 64位跑马灯, flash PWM 调光
// 端口兼容原 SSeg7 接口
// 扫描预分频: 100MHz / 2^17 ≈ 763Hz/位, 95Hz 完整刷新
module SSeg7(
    input           clk,            // 100MHz 系统时钟
    input           rst,            // 复位 (高有效)
    input           SW0,            // 0=文本(十六进制), 1=图形(跑马灯)
    input           flash,          // PWM 调光 (暂未使用)
    input  [31:0]   Hexs,           // 文本模式: 32-bit 数据
    input  [7:0]    point,          // 小数点控制
    input  [7:0]    LES,            // 位使能
    output [7:0]    seg_an,         // 位选 (AN0-AN7, 低有效)
    output [7:0]    seg_sout        // 段码 (CA-CG+DP, 低有效, 共阳极)
);

    // === 4-bit → 7-seg 共阳极段码 (低有效) ===
    function [7:0] hex2seg(input [3:0] h);
        case (h)
            4'h0: hex2seg = 8'b11000000;  // 0
            4'h1: hex2seg = 8'b11111001;  // 1
            4'h2: hex2seg = 8'b10100100;  // 2
            4'h3: hex2seg = 8'b10110000;  // 3
            4'h4: hex2seg = 8'b10011001;  // 4
            4'h5: hex2seg = 8'b10010010;  // 5
            4'h6: hex2seg = 8'b10000010;  // 6
            4'h7: hex2seg = 8'b11111000;  // 7
            4'h8: hex2seg = 8'b10000000;  // 8
            4'h9: hex2seg = 8'b10010000;  // 9
            4'hA: hex2seg = 8'b10001000;  // A
            4'hB: hex2seg = 8'b10000011;  // b
            4'hC: hex2seg = 8'b11000110;  // C
            4'hD: hex2seg = 8'b10100001;  // d
            4'hE: hex2seg = 8'b10000110;  // E
            4'hF: hex2seg = 8'b10001110;  // F
            default: hex2seg = 8'b11111111; // 全灭
        endcase
    endfunction

    // === 图形模式: 64位跑马灯 ===
    reg [63:0] chasing;             // 64位 = 8数码管 × 8段
    reg [24:0] shift_timer;         // 移位计时器 (25-bit)

    // 移位速度: 2^25 / 100MHz ≈ 0.34s/步, ~3步/秒
    wire shift_tick;
    assign shift_tick = (shift_timer == 25'd0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            chasing     <= {1'b0, 63'h0000000000000001}; // 初始: 最低段亮
            shift_timer <= 25'd0;
        end else if (SW0) begin
            shift_timer <= shift_timer + 1;
            if (shift_tick)
                chasing <= {chasing[62:0], chasing[63]};  // 左移
        end else begin
            shift_timer <= 25'd0;
        end
    end

    // === 动态扫描 (双速率: 扫描预分频 + Flash PWM 独立) ===
    reg [16:0] scan_timer;          // 扫描预分频: 2^17 → 763Hz/位
    reg [2:0]  digit;               // 当前位号 (0-7)
    reg [7:0]  content_an, content_seg; // "意图"内容 (不含 PWM 调光)
    reg [7:0]  seg_an_reg, seg_reg;
    reg        sw0_sampled;

    assign seg_an   = seg_an_reg;
    assign seg_sout = seg_reg;

    // 将 64-bit chasing 按当前 digit 提取 → 段码 (取反: 1=亮→低有效0)
    reg [7:0] graphic_seg;
    always @(*) begin
        case (digit)
            3'd0: graphic_seg = ~chasing[7:0];
            3'd1: graphic_seg = ~chasing[15:8];
            3'd2: graphic_seg = ~chasing[23:16];
            3'd3: graphic_seg = ~chasing[31:24];
            3'd4: graphic_seg = ~chasing[39:32];
            3'd5: graphic_seg = ~chasing[47:40];
            3'd6: graphic_seg = ~chasing[55:48];
            3'd7: graphic_seg = ~chasing[63:56];
            default: graphic_seg = 8'b11111111;
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_timer  <= 17'd0;
            digit       <= 3'b0;
            content_an  <= 8'b11111111;
            content_seg <= 8'b11111111;
            seg_an_reg  <= 8'b11111111;
            seg_reg     <= 8'b11111111;
            sw0_sampled <= 1'b0;
        end else begin
            // ---- 扫描预分频 ----
            scan_timer <= scan_timer + 1;

            // 扫描边界: 切换位号 + 计算新位的内容
            if (scan_timer == 17'd0) begin
                digit <= digit + 1;

                if (LES[digit] == 1'b0) begin
                    content_an  <= 8'b11111111;
                    content_seg <= 8'b11111111;
                end else if (sw0_sampled) begin
                    // 图形模式: 跑马灯内容
                    content_an  <= ~(8'b1 << digit);
                    content_seg <= graphic_seg;
                end else begin
                    // 文本模式: 十六进制内容
                    content_an  <= ~(8'b1 << digit);
                    case (digit)
                        3'd0: content_seg <= hex2seg(Hexs[3:0]);
                        3'd1: content_seg <= hex2seg(Hexs[7:4]);
                        3'd2: content_seg <= hex2seg(Hexs[11:8]);
                        3'd3: content_seg <= hex2seg(Hexs[15:12]);
                        3'd4: content_seg <= hex2seg(Hexs[19:16]);
                        3'd5: content_seg <= hex2seg(Hexs[23:20]);
                        3'd6: content_seg <= hex2seg(Hexs[27:24]);
                        3'd7: content_seg <= hex2seg(Hexs[31:28]);
                        default: content_seg <= 8'b11111111;
                    endcase
                    // 小数点暂禁用 (point_in 接 clkdiv 导致频闪)
                end
            end

            // 每完整一轮扫描采样一次 SW0
            if (digit == 3'd0 && scan_timer == 17'd0)
                sw0_sampled <= SW0;

            // ---- 输出: 无 PWM 调光, 文本/图形均 100% 亮度 ----
            seg_an_reg <= content_an;
            seg_reg    <= content_seg;
        end
    end

endmodule
