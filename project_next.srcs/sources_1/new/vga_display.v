`timescale 1ns / 1ps

// =============================================================================
// vga_display.v — VGA 状态显示模块 (640×480 @ 60Hz)
// =============================================================================
//   上半部分: 三个条形图 (伴奏音量/麦克风音量/麦克风增益)
//   下半部分: 歌曲信息 + 实时歌词 (16×16中文字库)
//
//   依赖: VGA_Scan.v, font.mem (8×8 ASCII), hzk16_custom.mem (16×16中文)
//          lyrics_offset.mem, lyrics_chars.mem
// =============================================================================

module vga_display (
    input             clk,        // 100MHz
    input             rst,
    input      [2:0]  vol_acc,
    input      [2:0]  vol_mic,
    input      [2:0]  mic_gain,
    input      [4:0]  lyric_idx,  // 当前歌词索引 (0-24)
    output     [3:0]  vga_r,
    output     [3:0]  vga_g,
    output     [3:0]  vga_b,
    output            vga_hsync,
    output            vga_vsync
);

    // ===== 25MHz 分频 =====
    reg [1:0] clk_div;
    always @(posedge clk or posedge rst) begin
        if (rst) clk_div <= 2'd0;
        else     clk_div <= clk_div + 2'd1;
    end
    wire clk_25 = clk_div[1];

    // ===== VGA 时序 =====
    wire [8:0] row;
    wire [9:0] col;
    wire       active;

    VGA_Scan u_scan(
        .clk    (clk_25),
        .rst    (rst),
        .row    (row),
        .col    (col),
        .Active (active),
        .HSYNC  (vga_hsync),
        .VSYNC  (vga_vsync)
    );

    // =====================================================================
    // ROM 实例化
    // =====================================================================

    // --- ASCII 字库 (8×8) ---
    reg [7:0] ascii_rom [0:1023];
    initial $readmemh("font.mem", ascii_rom);

    // --- 中文字库 (16×16, 134字 × 32 words = 4288) ---
    reg [15:0] hzk_rom [0:4287];
    initial $readmemh("hzk16_custom.mem", hzk_rom);

    // --- 歌词偏移表 (25条 × 2: start, len) ---
    reg [15:0] lrc_off [0:49];
    initial $readmemh("lyrics_offset.mem", lrc_off);

    // --- 歌词字符索引 (185个) ---
    reg [15:0] lrc_chr [0:184];
    initial $readmemh("lyrics_chars.mem", lrc_chr);

    // =====================================================================
    // 布局常量
    // =====================================================================
    localparam BAR_X  = 10'd80;
    localparam BAR_W  = 10'd400;
    localparam BAR_H  = 9'd24;
    localparam VAL_X  = 10'd500;

    localparam R1_LY = 9'd80;   localparam R1_BY = 9'd100;
    localparam R2_LY = 9'd160;  localparam R2_BY = 9'd180;
    localparam R3_LY = 9'd240;  localparam R3_BY = 9'd260;

    // 中文显示区域
    localparam InfoY = 9'd310;  // 歌曲信息起始Y (2行×16px=32px)
    localparam LrcY  = 9'd355;  // 歌词显示起始Y (2行×16px=32px)

    // =====================================================================
    // 条形图区域判定
    // =====================================================================
    wire in_title    = (row >= 9'd20)  && (row < 9'd36)  && (col >= 10'd224) && (col < 10'd416);
    wire in_r1_lbl   = (row >= R1_LY)  && (row < R1_LY+8) && (col >= BAR_X) && (col < BAR_X+80);
    wire in_r2_lbl   = (row >= R2_LY)  && (row < R2_LY+8) && (col >= BAR_X) && (col < BAR_X+56);
    wire in_r3_lbl   = (row >= R3_LY)  && (row < R3_LY+8) && (col >= BAR_X) && (col < BAR_X+64);

    wire in_r1_val   = (row >= R1_BY+8'd8) && (row < R1_BY+8'd16) && (col >= VAL_X) && (col < VAL_X+10'd24);
    wire in_r2_val   = (row >= R2_BY+8'd8) && (row < R2_BY+8'd16) && (col >= VAL_X) && (col < VAL_X+10'd24);
    wire in_r3_val   = (row >= R3_BY+8'd8) && (row < R3_BY+8'd16) && (col >= VAL_X) && (col < VAL_X+10'd24);

    wire in_bar1 = (row >= R1_BY) && (row < R1_BY+BAR_H) && (col >= BAR_X) && (col < BAR_X+BAR_W);
    wire in_bar2 = (row >= R2_BY) && (row < R2_BY+BAR_H) && (col >= BAR_X) && (col < BAR_X+BAR_W);
    wire in_bar3 = (row >= R3_BY) && (row < R3_BY+BAR_H) && (col >= BAR_X) && (col < BAR_X+BAR_W);

    // =====================================================================
    // 条形图宽度
    // =====================================================================
    function [9:0] bar_width;
        input [2:0] lv;
        case (lv)
            3'd0: bar_width = 10'd0;   3'd1: bar_width = 10'd57;
            3'd2: bar_width = 10'd114;  3'd3: bar_width = 10'd171;
            3'd4: bar_width = 10'd228;  3'd5: bar_width = 10'd285;
            3'd6: bar_width = 10'd342;  3'd7: bar_width = 10'd400;
        endcase
    endfunction

    wire [9:0] bw1 = bar_width(vol_acc);
    wire [9:0] bw2 = bar_width(vol_mic);
    wire [9:0] bw3 = bar_width(mic_gain);

    wire in_b1_fill = in_bar1 && ((col - BAR_X) < bw1);
    wire in_b2_fill = in_bar2 && ((col - BAR_X) < bw2);
    wire in_b3_fill = in_bar3 && ((col - BAR_X) < bw3);

    wire in_b1_bdr = in_bar1 && (
        (row==R1_BY) || (row==R1_BY+BAR_H-1) || (col==BAR_X) || (col==BAR_X+BAR_W-1));
    wire in_b2_bdr = in_bar2 && (
        (row==R2_BY) || (row==R2_BY+BAR_H-1) || (col==BAR_X) || (col==BAR_X+BAR_W-1));
    wire in_b3_bdr = in_bar3 && (
        (row==R3_BY) || (row==R3_BY+BAR_H-1) || (col==BAR_X) || (col==BAR_X+BAR_W-1));

    // =====================================================================
    // ASCII 字符选择 (条形图标签/数值)
    // =====================================================================
    reg [6:0] char_code;
    reg [2:0] frow, fbit;

    always @(*) begin
        char_code = 7'h20;
        frow = row[2:0];
        fbit = col[2:0];

        if (in_title) begin
            frow = row[3:1]; fbit = col[4:1];
            case ((col - 10'd224) >> 4)
                4'd0:char_code=7'h41; 4'd1:char_code=7'h55; 4'd2:char_code=7'h44;
                4'd3:char_code=7'h49; 4'd4:char_code=7'h4F; 4'd5:char_code=7'h20;
                4'd6:char_code=7'h53; 4'd7:char_code=7'h54; 4'd8:char_code=7'h41;
                4'd9:char_code=7'h54; 4'd10:char_code=7'h55; 4'd11:char_code=7'h53;
                default:char_code=7'h20;
            endcase
        end
        else if (in_r1_lbl) begin
            case (col[9:3] - 7'd10)
                4'd0:char_code=7'h41; 4'd1:char_code=7'h43; 4'd2:char_code=7'h43;
                4'd3:char_code=7'h4F; 4'd4:char_code=7'h4D; 4'd5:char_code=7'h50;
                4'd6:char_code=7'h20; 4'd7:char_code=7'h56; 4'd8:char_code=7'h4F;
                4'd9:char_code=7'h4C; default:char_code=7'h20;
            endcase
        end
        else if (in_r2_lbl) begin
            case (col[9:3] - 7'd10)
                4'd0:char_code=7'h4D; 4'd1:char_code=7'h49; 4'd2:char_code=7'h43;
                4'd3:char_code=7'h20; 4'd4:char_code=7'h56; 4'd5:char_code=7'h4F;
                4'd6:char_code=7'h4C; default:char_code=7'h20;
            endcase
        end
        else if (in_r3_lbl) begin
            case (col[9:3] - 7'd10)
                4'd0:char_code=7'h4D; 4'd1:char_code=7'h49; 4'd2:char_code=7'h43;
                4'd3:char_code=7'h20; 4'd4:char_code=7'h47; 4'd5:char_code=7'h41;
                4'd6:char_code=7'h49; 4'd7:char_code=7'h4E; default:char_code=7'h20;
            endcase
        end
        else if (in_r1_val) begin
            if      (col[4:3]==2'd0) char_code = {4'h3, vol_acc};
            else if (col[4:3]==2'd1) char_code = 7'h2F;
            else                      char_code = 7'h37;
        end
        else if (in_r2_val) begin
            if      (col[4:3]==2'd0) char_code = {4'h3, vol_mic};
            else if (col[4:3]==2'd1) char_code = 7'h2F;
            else                      char_code = 7'h37;
        end
        else if (in_r3_val) begin
            if      (col[4:3]==2'd0) char_code = {4'h3, mic_gain};
            else if (col[4:3]==2'd1) char_code = 7'h2F;
            else                      char_code = 7'h37;
        end
    end

    wire [7:0] ascii_data = ascii_rom[{char_code, frow}];
    wire       ascii_px   = ascii_data[~fbit];

    // =====================================================================
    // 中文歌词渲染
    // =====================================================================

    // --- 区域判定 ---
    wire in_info = (row >= InfoY) && (row < InfoY+9'd32) && (col >= 10'd40) && (col < 10'd560);
    wire in_lrc  = (row >= LrcY)  && (row < LrcY+9'd32)  && (col >= 10'd40) && (col < 10'd560);
    wire in_cn   = in_info || in_lrc;

    // --- 字符内坐标 ---
    wire [3:0] cn_r = row[3:0];  // 字符内行 (0-15)
    wire [3:0] cn_c = col[3:0];  // 字符内列 (0-15)

    // --- 哪一行字符 (0=上, 1=下) ---
    wire cn_row0 = in_info ? (row < InfoY + 9'd16) : (row < LrcY + 9'd16);

    // --- 第几列字符 ---
    wire [5:0] cn_col_idx = (col - 10'd40) >> 4;  // /16

    // --- 歌曲信息字符索引 (硬编码) ---
    reg [6:0] info_idx;
    always @(*) begin
        info_idx = 7'd0;
        if (in_info) begin
            if (cn_row0) begin
                // 第1行: "《牵丝戏》银临"
                case (cn_col_idx)
                    6'd0:  info_idx = 7'd0;    // 《
                    6'd1:  info_idx = 7'd13;   // 牵
                    6'd2:  info_idx = 7'd8;    // 丝
                    6'd3:  info_idx = 7'd70;   // 戏
                    6'd4:  info_idx = 7'd1;    // 》
                    6'd5:  info_idx = 7'd131;  // 银
                    6'd6:  info_idx = 7'd9;    // 临
                    default: info_idx = 7'd0;
                endcase
            end else begin
                // 第2行: "作词曲银临编灰原穷"
                case (cn_col_idx)
                    6'd0:  info_idx = 7'd19;   // 作
                    6'd1:  info_idx = 7'd123;  // 词
                    6'd2:  info_idx = 7'd80;   // 曲
                    6'd3:  info_idx = 7'd131;  // 银
                    6'd4:  info_idx = 7'd9;    // 临
                    6'd5:  info_idx = 7'd112;  // 编
                    6'd6:  info_idx = 7'd95;   // 灰
                    6'd7:  info_idx = 7'd105;  // 穷
                    default: info_idx = 7'd0;
                endcase
            end
        end
    end

    // --- 歌词字符索引 (从ROM读取) ---
    wire [15:0] lrc_start = lrc_off[{lyric_idx, 1'b0}];  // start
    wire [15:0] lrc_len   = lrc_off[{lyric_idx, 1'b1}];  // len

    wire [5:0] lrc_pos = (col - 10'd40) >> 4;  // 当前是第几个字符
    wire       lrc_valid = in_lrc && cn_row0 && (lrc_pos < lrc_len[5:0]);

    wire [7:0] lrc_chr_addr = lrc_start[7:0] + lrc_pos[5:0];
    wire [6:0] lrc_chr_idx  = (lrc_chr_addr < 8'd185) ? lrc_chr[lrc_chr_addr][6:0] : 7'd0;

    // --- 选择字符索引 ---
    wire [6:0] sel_idx = in_info ? info_idx : lrc_chr_idx;

    // --- 中文字库查找 ---
    // addr = sel_idx * 32 + cn_r
    wire [12:0] hzk_addr = {sel_idx, 5'b0} + {8'd0, cn_r};
    wire [15:0] hzk_data = hzk_rom[hzk_addr[11:0]];

    wire cn_px = hzk_data[~cn_c[3:0]];

    // =====================================================================
    // 颜色生成
    // =====================================================================
    function [11:0] bar_color;
        input [2:0] lv;
        case (lv)
            3'd0, 3'd1, 3'd2: bar_color = 12'h0B0;
            3'd3, 3'd4:       bar_color = 12'hCC0;
            3'd5, 3'd6, 3'd7: bar_color = 12'hC30;
            default:          bar_color = 12'h0B0;
        endcase
    endfunction

    reg [11:0] px;
    always @(*) begin
        if (!active)
            px = 12'h000;
        else if (in_title && ascii_px)
            px = 12'hFFF;
        else if ((in_r1_lbl|in_r2_lbl|in_r3_lbl) && ascii_px)
            px = 12'h0FF;
        else if ((in_r1_val|in_r2_val|in_r3_val) && ascii_px)
            px = 12'hFFF;
        else if (in_b1_bdr|in_b2_bdr|in_b3_bdr)
            px = 12'h666;
        else if (in_b1_fill) px = bar_color(vol_acc);
        else if (in_b2_fill) px = bar_color(vol_mic);
        else if (in_b3_fill) px = bar_color(mic_gain);
        else if (in_bar1|in_bar2|in_bar3)
            px = 12'h111;
        // 中文歌词 (白色)
        else if (in_cn && cn_px)
            px = 12'hFFF;
        // 中文区域背景
        else if (in_cn)
            px = 12'h011;
        // 整体背景
        else
            px = 12'h013;
    end

    // ===== 输出寄存 =====
    reg [3:0] rr, gg, bb;
    always @(posedge clk_25 or posedge rst) begin
        if (rst) {rr,gg,bb} <= 12'd0;
        else     {rr,gg,bb} <= px;
    end

    assign vga_r = active ? rr : 4'd0;
    assign vga_g = active ? gg : 4'd0;
    assign vga_b = active ? bb : 4'd0;

endmodule
