`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 简易 VGA 显示模块 (色块模式)
// 不依赖字体 ROM，直接按 8x8 像素块输出颜色
//
// 显示分辨率: 640x480
// 色块分辨率: 80x60 (每个色块 8x8 像素)
// 颜色深度:   12 位 (4R + 4G + 4B)
//
// CPU 通过写 VRAM 设置每个色块的颜色
// VGA 扫描时从 VRAM 读取颜色输出
//////////////////////////////////////////////////////////////////////////////////

module vga_display(
    input clk_100m,       // 100MHz 系统时钟
    input rst,
    
    // CPU 写端口
    input        cpu_we,       // CPU 写使能
    input  [12:0] cpu_addr,    // CPU 地址 (0~4799)
    input  [11:0] cpu_din,     // CPU 写入颜色 (RGBI)
    output [11:0] cpu_dout,    // CPU 读出颜色
    
    // VGA 输出
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output vga_hsync,
    output vga_vsync
);

    // ======== 时钟分频: 100MHz → 25MHz ========
    reg [1:0] clk_cnt = 0;
    wire clk_25m;
    always @(posedge clk_100m or posedge rst) begin
        if (rst) clk_cnt <= 0;
        else clk_cnt <= clk_cnt + 1;
    end
    assign clk_25m = clk_cnt[1];  // 25MHz

    // ======== VGA 扫描时序 ========
    reg [9:0] h_count = 0;  // 水平计数器 (0~799)
    reg [9:0] v_count = 0;  // 垂直计数器 (0~524)
    reg h_active = 0;
    reg v_active = 0;
    reg h_sync_r = 0;
    reg v_sync_r = 0;

    // 水平时序: 同步95 + 后沿48 + 有效640 + 前沿16 = 799
    always @(posedge clk_25m or posedge rst) begin
        if (rst) begin
            h_count <= 0;
            h_sync_r <= 0;
            h_active <= 0;
        end else begin
            h_count <= h_count + 1;
            case (h_count)
                10'd95:  h_sync_r <= 1;
                10'd143: h_active <= 1;
                10'd783: h_active <= 0;
                10'd799: begin
                    h_count <= 0;
                    h_sync_r <= 0;
                end
                default: ;
            endcase
        end
    end

    // 垂直时序: 同步2 + 后沿33 + 有效480 + 前沿10 = 524
    always @(posedge clk_25m or posedge rst) begin
        if (rst) begin
            v_count <= 0;
            v_sync_r <= 0;
            v_active <= 0;
        end else if (h_count == 10'd799) begin
            if (v_count == 10'd524)
                v_count <= 0;
            else
                v_count <= v_count + 1;
            case (v_count)
                10'd1:   v_sync_r <= 1;
                10'd35:  v_active <= 1;
                10'd515: v_active <= 0;
                10'd524: v_sync_r <= 0;
                default: ;
            endcase
        end
    end

    wire active = h_active & v_active;
    
    // 有效像素坐标 (0~639, 0~479)
    wire [9:0] pixel_x = h_count - 10'd144;
    wire [8:0] pixel_y = v_count - 10'd36;

    // ======== 色块地址计算 ========
    // 每个色块 8x8 像素 → 80列 x 60行
    wire [6:0] block_col = pixel_x[9:3];  // 0~79
    wire [5:0] block_row = pixel_y[8:3];  // 0~59
    
    // VRAM 地址 = row * 80 + col
    wire [12:0] vga_addr = {1'b0, block_row, 3'b000} +  // row * 8
                           {1'b0, block_row, 1'b0, 1'b0} + // row * 4 (合计 row*12, 不对)
                           {5'b0, block_col};
    // 简化: row * 80 + col
    // 80 = 64 + 16 = 2^6 + 2^4
    // row * 80 = row * 64 + row * 16 = {row, 6'b0} + {row, 4'b0}
    wire [12:0] vga_addr_calc = {1'b0, block_row, 6'b0} + {1'b0, block_row, 4'b0} + {6'b0, block_col};

    // ======== 双口 VRAM ========
    // 端口 A: CPU 写 (100MHz 域)
    // 端口 B: VGA 读 (25MHz 域)
    reg [11:0] vram [0:4799];  // 80*60 = 4800 个色块

    // CPU 写端口
    reg [11:0] cpu_dout_r;
    always @(posedge clk_100m) begin
        if (cpu_we)
            vram[cpu_addr] <= cpu_din;
        cpu_dout_r <= vram[cpu_addr];
    end
    assign cpu_dout = cpu_dout_r;

    // VGA 读端口
    reg [11:0] vga_color;
    always @(posedge clk_25m) begin
        vga_color <= vram[vga_addr_calc];
    end

    // ======== VGA 输出 ========
    assign vga_r = active ? vga_color[11:8] : 4'h0;
    assign vga_g = active ? vga_color[7:4]  : 4'h0;
    assign vga_b = active ? vga_color[3:0]  : 4'h0;
    assign vga_hsync = h_sync_r;
    assign vga_vsync = v_sync_r;

endmodule
