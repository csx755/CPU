

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

    // ======== 中断源连接 ========
    wire [6:0] int_sources;
    assign int_sources[0] = counter0_OUT;  // 定时器中断
    assign int_sources[1] = |BTN_out;      // 按键中断（任意按键按下）
    assign int_sources[6:2] = 5'b0;        // 其他中断源（预留）
    
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
        .DMType(dm_ctrl),
        .mem_w(mem_w),
        .int_sources(int_sources)
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

    // ======== 中断源连接 ========
    wire [6:0] int_sources;
    assign int_sources[0] = counter0_OUT;  // 定时器中断
    assign int_sources[1] = |BTN_out;      // 按键中断（任意按键按下）
    assign int_sources[6:2] = 5'b0;        // 其他中断源（预留）
    
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
        .DMType(dm_ctrl),
        .mem_w(mem_w),
        .int_sources(int_sources)
    );

    ROM_D U2_ROMD(
        .a(PC_out[11:2]),
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


endmodule

