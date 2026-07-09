`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 顶层模块 - 打地鼠游戏系统 (Nexys A7-100T)
// 集成: RISC-V CPU + PS2键盘 + VGA色块显示
//
// 不依赖字体ROM，使用 vga_display 色块模式
// VGA: 640x480, 80x60 色块, 12位色深
//////////////////////////////////////////////////////////////////////////////////

module top(
    input rstn,
    input [4:0] btn_i,
    input [15:0] sw_i,
    input clk,
    // PS2
    input PS2C,
    input PS2D,
    // VGA
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output vga_hsync,
    output vga_vsync,
    // 数码管
    output [7:0] disp_an_o,
    output [7:0] disp_seg_o,
    // LED
    output [15:0] led_o
);

    wire rst;
    wire IO_clk;
    wire Clk_CPU;
    wire [31:0] clkdiv;
    assign rst = ~rstn;
    assign IO_clk = ~Clk_CPU;

    // ======== CPU 信号 ========
    wire [31:0] Addr_out, Data_out, PC_out, Data_read;
    wire [31:0] Cpu_data4bus, Peripheral_in, ram_data_in;
    wire [31:0] spo, douta, Data_write_to_dm, counter_out;
    wire [2:0] dm_ctrl;
    wire [9:0] ram_addr;
    wire [3:0] wea_mem;
    wire mem_w, CPU_MIO, MIO_ready, INT;
    wire data_ram_we, GPIOe0000000_we, GPIOf0000000_we;
    wire counter_we;
    wire [1:0] counter_set;
    wire [13:0] GPIOf0;
    wire [31:0] Disp_num;
    wire [7:0] LE_out, point_out;
    wire [15:0] LED_out;
    wire counter0_OUT, counter1_OUT, counter2_OUT;
    wire [4:0] BTN_out;
    wire [15:0] SW_out;

    // ======== PS2 信号 ========
    wire [7:0] ps2_key;
    wire ps2_ready;
    wire [31:0] ps2_scancode;

    // ======== VGA 显存信号 ========
    wire vram_we;
    wire [12:0] vram_cpu_addr;
    wire [11:0] vram_cpu_din, vram_cpu_dout;

    // ======== 中断源 ========
    wire [6:0] int_sources;
    assign int_sources[0] = counter0_OUT;
    assign int_sources[1] = |BTN_out;
    assign int_sources[6:2] = 5'b0;
    assign MIO_ready = CPU_MIO;
    assign INT = counter0_OUT;

    // ======== CPU ========
    SCPU U1_SCPU(
        .Data_in(Data_read), .INT(INT), .MIO_ready(MIO_ready),
        .clk(Clk_CPU), .inst_in(spo), .reset(rst),
        .Addr_out(Addr_out), .CPU_MIO(CPU_MIO), .Data_out(Data_out),
        .PC_out(PC_out), .DMType(dm_ctrl), .mem_w(mem_w),
        .int_sources(int_sources)
    );

    // ======== 指令 ROM ========
    ROM_D U2_ROMD(.a(PC_out[11:2]), .spo(spo));

    // ======== 数据存储控制器 ========
    dm_ctrl U3_dm_controller(
        .Addr_in(Addr_out), .Data_read_from_dm(Cpu_data4bus),
        .Data_write(ram_data_in), .dm_ctrl(dm_ctrl), .mem_w(mem_w),
        .Data_read(Data_read), .Data_write_to_dm(Data_write_to_dm),
        .wea_mem(wea_mem)
    );

    // ======== 数据 RAM ========
    RAM_B U3_RAM_B(
        .addra(ram_addr), .clka(~clk), .dina(Data_write_to_dm),
        .wea(wea_mem), .douta(douta)
    );

    // ======== IO 总线 (带 PS2 + VRAM) ========
    MIO_BUS U4_MIO_BUS(
        .clk(clk), .rst(rst), .BTN(BTN_out), .Cpu_data2bus(Data_out),
        .SW(SW_out), .PC(PC_out), .addr_bus(Addr_out),
        .counter_out(counter_out), .counter0_out(counter0_OUT),
        .counter1_out(counter1_OUT), .counter2_out(counter2_OUT),
        .led_out(LED_out), .mem_w(mem_w), .ram_data_out(douta),
        .Cpu_data4bus(Cpu_data4bus),
        .GPIOe0000000_we(GPIOe0000000_we),
        .GPIOf0000000_we(GPIOf0000000_we),
        .Peripheral_in(Peripheral_in), .counter_we(counter_we),
        .data_ram_we(data_ram_we), .ram_addr(ram_addr),
        .ram_data_in(ram_data_in),
        .ps2_key(ps2_key), .ps2_ready(ps2_ready),
        .vram_dout(vram_cpu_dout), .vram_we(vram_we),
        .vram_addr(vram_cpu_addr), .vram_din(vram_cpu_din)
    );

    // ======== PS2 键盘 ========
    PS2IO U_PS2(
        .io_read_clk(Clk_CPU), .clk(clk), .rst(rst),
        .PS2C(PS2C), .PS2D(PS2D), .RD(1'b1),
        .testkey(), .Scancode(ps2_scancode),
        .key(ps2_key), .PS2Ready(ps2_ready)
    );

    // ======== VGA 显示 (色块模式，自带时序+VRAM) ========
    vga_display U_VGA(
        .clk_100m(clk), .rst(rst),
        .cpu_we(vram_we), .cpu_addr(vram_cpu_addr),
        .cpu_din(vram_cpu_din), .cpu_dout(vram_cpu_dout),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b),
        .vga_hsync(vga_hsync), .vga_vsync(vga_vsync)
    );

    // ======== 数码管 ========
    Multi_8CH32 U5_Multi_8CH32(
        .clk(IO_clk), .rst(rst), .EN(GPIOe0000000_we),
        .Switch(SW_out[7:5]),
        .point_in({clkdiv[31:0], clkdiv[31:0]}),
        .LES(64'hffffffff_ffffffff),
        .data0(Peripheral_in), .data1({1'b0, 1'b0, PC_out[31:2]}),
        .data2(spo), .data3(counter_out), .data4(Addr_out),
        .data5(Data_out), .data6(Cpu_data4bus), .data7(PC_out),
        .point_out(point_out), .LE_out(LE_out), .Disp_num(Disp_num)
    );

    SSeg7 U6_SSeg7(
        .clk(clk), .rst(rst), .SW0(SW_out[0]), .flash(clkdiv[10]),
        .Hexs(Disp_num), .point(point_out), .LES(LE_out),
        .seg_an(disp_an_o), .seg_sout(disp_seg_o)
    );

    // ======== LED ========
    SPIO U7_SPIO(
        .clk(IO_clk), .rst(rst), .EN(GPIOf0000000_we),
        .P_Data(Peripheral_in), .LED_out(LED_out),
        .counter_set(counter_set), .led(led_o), .GPIOf0(GPIOf0)
    );

    // ======== 时钟分频 ========
    clk_div U8_clk_div(
        .clk(clk), .rst(rst), .SW2(SW_out[2]),
        .Clk_CPU(Clk_CPU), .clkdiv(clkdiv)
    );

    // ======== 定时器 ========
    Counter_x U9_Counter_x(
        .clk(IO_clk), .rst(rst),
        .clk0(clkdiv[6]), .clk1(clkdiv[9]), .clk2(clkdiv[11]),
        .counter_we(counter_we), .counter_val(Peripheral_in),
        .counter_ch(counter_set),
        .counter0_OUT(counter0_OUT), .counter1_OUT(counter1_OUT),
        .counter2_OUT(counter2_OUT), .counter_out(counter_out)
    );

    // ======== 按键/开关 ========
    Enter U10_Enter(
        .clk(clk), .BTN(btn_i), .SW(sw_i),
        .BTN_out(BTN_out), .SW_out(SW_out)
    );

endmodule
