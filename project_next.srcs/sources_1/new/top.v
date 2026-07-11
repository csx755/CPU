

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/07/06 15:10:47
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
/*
module top(
    input rstn,
    input  [4:0]btn_i,
    input [15:0]sw_i,
    input clk,
    output [7:0]disp_an_o,
    output [7:0]disp_seg_o,
    output [15:0]led_o
    );

    //U1
    wire [31:0]Addr_out;
    wire CPU_MIO;
    wire [31:0]Data_out;
    wire [31:0]PC_out;
    wire [2:0]dm_ctrl;
    wire mem_w;
    wire MIO_ready;
    wire INT;
    wire rst;
    wire IO_clk;

    //U2
    wire [31:0]spo;

    //U3_R
    wire [31:0]douta;

    //U3_C
    wire [31:0]Data_read;
    wire [31:0]Data_write_to_dm;
    wire [3:0]wea_mem;

    //U4
    wire [31:0]Cpu_data4bus;
    wire GPIOe0000000_we;
    wire GPIOf0000000_we;
    wire [31:0]Peripheral_in;
    wire counter_we;
    wire [9:0]ram_addr;
    wire [31:0]ram_data_in;
    wire data_ram_we;

    //U5
    wire [31:0]Disp_num;
    wire [7:0]LE_out;
    wire [7:0]point_out;

    //U6
    //wire lopt

    //U7
    wire [15:0]LED_out;
    wire [1:0]counter_set;
    wire [13:0]GPIOf0;

    //U8
    wire Clk_CPU;
    wire [31:0]clkdiv;

    //U9
    wire counter0_OUT;
    wire counter1_OUT;
    wire counter2_OUT;
    wire [31:0]counter_out;

    //U10
    wire [4:0]BTN_out;
    wire [15:0]SW_out;
    
    assign MIO_ready = CPU_MIO;
    assign INT = counter0_OUT;
    assign rst = ~rstn;
    assign IO_clk = ~Clk_CPU;

    SCPU U1_SCPU(
        .Data_in(Data_read),
        .INT(INT),
        .MIO_ready(MIO_ready),
        .clk(Clk_CPU),
        .inst_in(spo),
        .reset(rst),
        .Addr_out(Addr_out),
        .CPU_MIO(CPU_MIO),
        .Data_out(Data_out),
        .PC_out(PC_out),
        .dm_ctrl(dm_ctrl),
        .mem_w(mem_w)
    );

    ROM_D U2_ROMD(
        .a(PC_out[11:2]),
        .spo(spo)
    );

  
    dm_controller U3_dm_controller(
        .Addr_in(Addr_out),
        .Data_read_from_dm(Cpu_data4bus),
        .Data_write(ram_data_in),
        .dm_ctrl(dm_ctrl),
        .mem_w(mem_w),
        .Data_read(Data_read),
        .Data_write_to_dm(Data_write_to_dm),
        .wea_mem(wea_mem)
    );

    RAM_B U3_RAM_B(
        .addra(ram_addr),
        .clka(~clk),
        .dina(Data_write_to_dm),
        .wea(wea_mem),
        .douta(douta)
    );

    MIO_BUS U4_MIO_BUS(
        .BTN(BTN_out),
        .Cpu_data2bus(Data_out),
        .SW(SW_out),
        .PC(PC_out),
        .addr_bus(Addr_out),
        .clk(clk),
        .counter_out(counter_out),
        .counter0_out(counter0_OUT),
        .counter1_out(counter1_OUT),
        .counter2_out(counter2_OUT),
        .led_out(LED_out),
        .mem_w(mem_w),
        .ram_data_out(douta),
        .rst(rst),
        .Cpu_data4bus(Cpu_data4bus),
        .GPIOe0000000_we(GPIOe0000000_we),
        .GPIOf0000000_we(GPIOf0000000_we),
        .Peripheral_in(Peripheral_in),
        .counter_we(counter_we),
        .data_ram_we(data_ram_we),
        .ram_addr(ram_addr),
        .ram_data_in(ram_data_in) 
    );

    Multi_8CH32 U5_Multi_8CH32(
        .clk(IO_clk),
        .rst(rst),
        .EN(GPIOe0000000_we),
        .Switch(SW_out[7:5]),
        .point_in({clkdiv[31:0], clkdiv[31:0]}),
        .LES(64'hffffffff_ffffffff),
        .data0(Peripheral_in),
        .data1({1'b0, 1'b0, PC_out[31:2]}),
        .data2(spo),
        .data3(counter_out),
        .data4(Addr_out),
        .data5(Data_out),
        .data6(Cpu_data4bus),
        .data7(PC_out),
        .point_out(point_out),
        .LE_out(LE_out),
        .Disp_num(Disp_num)
    );

    SSeg7 U6_SSeg7(
        .clk(clk),
        .rst(rst),
        .SW0(SW_out[0]),
        .flash(clkdiv[10]),
        .Hexs(Disp_num),
        .point(point_out), 
        .LES(LE_out),
        .seg_an(disp_an_o),
        .seg_sout(disp_seg_o)
    );

    SPIO U7_SPIO(
        .clk(IO_clk),
        .rst(rst),
        .EN(GPIOf0000000_we),
        .P_Data(Peripheral_in),
        .LED_out(LED_out),
        .counter_set(counter_set),
        .led(led_o),
        .GPIOf0(GPIOf0)
    );

    clk_div U8_clk_div(
        .clk(clk),
        .rst(rst),
        .SW2(SW_out[2]),
        .Clk_CPU(Clk_CPU),
        .clkdiv(clkdiv)
    );

    Counter_x U9_Counter_x(
        .clk(IO_clk),
        .rst(rst),   
        .clk0(clkdiv[6]),
        .clk1(clkdiv[9]),
        .clk2(clkdiv[11]),
        .counter_we(counter_we),
        .counter_val(Peripheral_in),
        .counter_ch(counter_set),
        .counter0_OUT(counter0_OUT),
        .counter1_OUT(counter1_OUT),
        .counter2_OUT(counter2_OUT),
        .counter_out(counter_out)
    );

    Enter U10_Enter(
        .clk(clk),
        .BTN(btn_i),
        .SW(sw_i),
        .BTN_out(BTN_out),
        .SW_out(SW_out)
    );


endmodule
*/


module top(
    input rstn,
    input  [4:0]btn_i,
    input [15:0]sw_i,
    input clk,
    output [7:0]disp_an_o,
    output [7:0]disp_seg_o,
    output [15:0]led_o,
    inout PS2C,
    inout PS2D,
    output AUD_PWM,
    output AUD_SD,
    // 麦克风接口
    output M_CLK,
    input  M_DATA,
    output M_LRSEL,
    // VGA 接口
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output       vga_hsync,
    output       vga_vsync
    );

    //U1
    wire [31:0]Addr_out;
    wire CPU_MIO;
    wire [31:0]Data_out;
    wire [31:0]PC_out;
    wire [2:0]dm_ctrl;
    wire mem_w;
    wire MIO_ready;
    wire INT;
    wire rst;
    wire IO_clk;

    //U2
    wire [31:0]spo;

    //U3_R
    wire [31:0]douta;

    //U3_C
    wire [31:0]Data_read;
    wire [31:0]Data_write_to_dm;
    wire [3:0]wea_mem;

    //U4
    wire [31:0]Cpu_data4bus;
    wire GPIOe0000000_we;
    wire GPIOf0000000_we;
    wire [31:0]Peripheral_in;
    wire counter_we;
    wire [9:0]ram_addr;
    wire [31:0]ram_data_in;
    wire data_ram_we;

    //U5
    wire [31:0]Disp_num;
    wire [7:0]LE_out;
    wire [7:0]point_out;

    //U6
    //wire lopt

    //U7
    wire [15:0]LED_out;
    wire [1:0]counter_set;
    wire [13:0]GPIOf0;

    //U8
    wire Clk_CPU;
    wire [31:0]clkdiv;

    //U9
    wire counter0_OUT;
    wire counter1_OUT;
    wire counter2_OUT;
    wire [31:0]counter_out;

    //U10
    wire [4:0]BTN_out;
    wire [15:0]SW_out;
    
    // PS2 Keyboard
    wire [7:0] ps2_key;
    wire [31:0] ps2_scancode;
    wire ps2_ready;
    wire ps2_rd;

    PS2IO U_PS2IO(
        .clk(clk),
        .rst(rst),
        .PS2C(PS2C),
        .PS2D(PS2D),
        .RD(ps2_rd),
        .testkey(ps2_key),
        .Scancode(ps2_scancode),
        .key(),
        .PS2Ready(ps2_ready)
    );

    assign ps2_rd = (Addr_out == 32'hD0000000) & ~mem_w;

    wire [31:0] Data_to_CPU;
    assign Data_to_CPU = (Addr_out[31:28] == 4'b1101) ? {24'b0, ps2_key} : Data_read;

    // ===== DDS 正弦波音频发生器 =====
    // 写 0xB0000000 = 32位频率字, 0=静音
    reg [31:0] freq_reg;
    wire [9:0] sine_sample;

    always @(posedge clk or posedge rst) begin
        if (rst)
            freq_reg <= 0;
        else if (mem_w && Addr_out == 32'hB0000000)
            freq_reg <= Data_out[31:0];
    end

    // ===== 歌词索引寄存器 =====
    // 写 0xC0000000 = 5位歌词索引 (0-24)
    reg [4:0] lyric_reg;
    always @(posedge clk or posedge rst) begin
        if (rst)
            lyric_reg <= 0;
        else if (mem_w && Addr_out == 32'hC0000000)
            lyric_reg <= Data_out[4:0];
    end

    tone_gen u_tone_gen(
        .clk(clk),
        .rst(rst),
        .freq_word(freq_reg),
        .sample(sine_sample)
    );

    // ===== 钢琴包络发生器 =====
    wire gate = (freq_reg != 0);
    wire [7:0] env_out;

    piano_env u_env(
        .clk(clk),
        .rst(rst),
        .gate(gate),
        .attack_rate(8'd5),     // ~5ms 起音
        .body_hold(8'd20),      // ~320ms 保持
        .tail_rate(8'd3),       // ~100ms 衰减
        .noise_level(8'd0),     // 不加噪声
        .env_out(env_out),
        .cf_weight(),
        .table_sel_a(),
        .table_sel_b(),
        .noise_en(),
        .noise_gain()
    );

    // ===== 包络乘法: (sine - 512) * env / 256 + 512 =====
    wire signed [10:0] sine_signed = {1'b0, sine_sample} - 11'd512;
    wire signed [18:0] product = sine_signed * $signed({1'b0, env_out});
    wire [9:0] enveloped = 10'd512 + product[17:8];

    // ===== 音量控制: SW[15:13] (3位, 8级) =====
    wire [2:0] vol = SW_out[15:13];
    wire [9:0] volume_shifted;
    assign volume_shifted = (vol == 3'd0) ? 10'd512 :           // 静音
                            (vol == 3'd1) ? enveloped >> 4 :    // 6.25%
                            (vol == 3'd2) ? enveloped >> 3 :    // 12.5%
                            (vol == 3'd3) ? enveloped >> 2 :    // 25%
                            (vol == 3'd4) ? enveloped >> 1 :    // 50%
                                            enveloped;           // 100%

    // ===== 低通滤波器 (伴奏) =====
    wire [9:0] filtered_acc;

    lpf u_lpf_acc(
        .clk(clk),
        .rst(rst),
        .audio_in(volume_shifted),
        .cutoff_val(5'd4),      // ~3.9kHz 截止
        .audio_out(filtered_acc)
    );

    // ===== PDM 麦克风输入 =====
    wire [9:0] mic_sample;

    pdm_microphone u_mic(
        .clk(clk),
        .rst(rst),
        .M_DATA(M_DATA),
        .M_CLK(M_CLK),
        .M_LRSEL(M_LRSEL),
        .gain(SW_out[9:7]),
        .mic_sample(mic_sample)
    );

    // ===== 麦克风混响 (50ms延迟, 30%反馈, 50/50干湿) =====
    wire [9:0] filtered_mic;

    reverb u_reverb(
        .clk(clk),
        .rst(rst),
        .audio_in(mic_sample),
        .audio_out(filtered_mic)
    );

    // ===== 音频混合 =====
    // SW[15:13] = 伴奏音量, SW[12:10] = 麦克风音量
    wire [2:0] vol_acc = SW_out[15:13];
    wire [2:0] vol_mic = SW_out[12:10];
    wire [9:0] mixed_audio;

    audio_mixer u_mixer(
        .clk(clk),
        .rst(rst),
        .accompaniment(filtered_acc),
        .microphone(filtered_mic),
        .vol_acc(vol_acc),
        .vol_mic(vol_mic),
        .mixed(mixed_audio)
    );

    // ===== 10位 PWM 输出 =====
    reg [9:0] pwm_cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) pwm_cnt <= 0;
        else     pwm_cnt <= pwm_cnt + 1'b1;
    end

    assign AUD_PWM = (pwm_cnt < mixed_audio) ? 1'b1 : 1'b0;
    assign AUD_SD  = 1'b1;  // 使能板载功放

    assign MIO_ready = CPU_MIO;
    // 修复：只用 ps2_ready 作为中断源
    // counter0_OUT 在复位后几乎立刻变高（计数器从0递减溢出），
    // 会导致中断风暴，CPU 永远卡在中断里
    assign INT = ps2_ready;
    assign rst = ~rstn;
    assign IO_clk = ~Clk_CPU;

    SCPU U1_SCPU(
        .Data_in(Data_to_CPU),
        .INT(INT),
        .MIO_ready(MIO_ready),
        .clk(Clk_CPU),
        .inst_in(spo),
        .reset(rst),
        .Addr_out(Addr_out),
        .CPU_MIO(CPU_MIO),
        .Data_out(Data_out),
        .PC_out(PC_out),
        .DMType(dm_ctrl),
        //.dm_ctrl(dm_ctrl),
        .mem_w(mem_w)
    );

    ROM_D U2_ROMD(
        .a(PC_out[15:2]),
        .spo(spo)
    );


    dm_ctrl U3_dm_controller(
        .Addr_in(Addr_out),
        .Data_read_from_dm(Cpu_data4bus),
        .Data_write(ram_data_in),
        .dm_ctrl(dm_ctrl),
        .mem_w(mem_w),
        .Data_read(Data_read),
        .Data_write_to_dm(Data_write_to_dm),
        .wea_mem(wea_mem)
    );

    RAM_B U3_RAM_B(
        .addra(ram_addr),
        .clka(~clk),
        .dina(Data_write_to_dm),
        .wea(wea_mem),
        .douta(douta)
    );

    MIO_BUS U4_MIO_BUS(
        .BTN(BTN_out),
        .Cpu_data2bus(Data_out),
        .SW(SW_out),
        .PC(PC_out),
        .addr_bus(Addr_out),
        .clk(clk),
        .counter_out(counter_out),
        .counter0_out(counter0_OUT),
        .counter1_out(counter1_OUT),
        .counter2_out(counter2_OUT),
        .led_out(LED_out),
        .mem_w(mem_w),
        .ram_data_out(douta),
        .rst(rst),
        .Cpu_data4bus(Cpu_data4bus),
        .GPIOe0000000_we(GPIOe0000000_we),
        .GPIOf0000000_we(GPIOf0000000_we),
        .Peripheral_in(Peripheral_in),
        .counter_we(counter_we),
        .data_ram_we(data_ram_we),
        .ram_addr(ram_addr),
        .ram_data_in(ram_data_in) 
    );

    Multi_8CH32 U5_Multi_8CH32(
        .clk(IO_clk),
        .rst(rst),
        .EN(GPIOe0000000_we),
        .Switch(SW_out[7:5]),
        .point_in({clkdiv[31:0], clkdiv[31:0]}),
        .LES(64'hffffffff_ffffffff),
        .data0(Peripheral_in),
        .data1({1'b0, 1'b0, PC_out[31:2]}),
        .data2(spo),
        .data3(counter_out),
        .data4(Addr_out),
        .data5(Data_out),
        .data6(Cpu_data4bus),
        .data7(PC_out),
        .point_out(point_out),
        .LE_out(LE_out),
        .Disp_num(Disp_num)
    );

    SSeg7 U6_SSeg7(
        .clk(clk),
        .rst(rst),
        .SW0(SW_out[0]),
        .flash(clkdiv[10]),
        .Hexs(Disp_num),
        .point(point_out), 
        .LES(LE_out),
        .seg_an(disp_an_o),
        .seg_sout(disp_seg_o)
    );

    SPIO U7_SPIO(
        .clk(IO_clk),
        .rst(rst),
        .EN(GPIOf0000000_we),
        .P_Data(Peripheral_in),
        .LED_out(LED_out),
        .counter_set(counter_set),
        .led(led_o),
        .GPIOf0(GPIOf0)
    );

    clk_div U8_clk_div(
        .clk(clk),
        .rst(rst),
        .SW2(SW_out[2]),
        .Clk_CPU(Clk_CPU),
        .clkdiv(clkdiv)
    );

    Counter_x U9_Counter_x(
        .clk(IO_clk),
        .rst(rst),   
        .clk0(clkdiv[6]),
        .clk1(clkdiv[9]),
        .clk2(clkdiv[11]),
        .counter_we(counter_we),
        .counter_val(Peripheral_in),
        .counter_ch(counter_set),
        .counter0_OUT(counter0_OUT),
        .counter1_OUT(counter1_OUT),
        .counter2_OUT(counter2_OUT),
        .counter_out(counter_out)
    );

    Enter U10_Enter(
        .clk(clk),
        .BTN(btn_i),
        .SW(sw_i),
        .BTN_out(BTN_out),
        .SW_out(SW_out)
    );



    // ===== VGA 状态显示 =====
    vga_display u_vga(
        .clk      (clk),
        .rst      (rst),
        .vol_acc  (SW_out[15:13]),
        .vol_mic  (SW_out[12:10]),
        .mic_gain (SW_out[9:7]),
        .lyric_idx(lyric_reg),
        .vga_r    (vga_r),
        .vga_g    (vga_g),
        .vga_b    (vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync)
    );

endmodule

