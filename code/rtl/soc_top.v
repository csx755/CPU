// =============================================================================
// soc_top — 单周期 CPU SoC 顶层模块
// 基于 schematic (1).pdf, 接口文档见 doc/12_SoC接口文档.md
// Nexys4 A7-100T (xc7a100tcsg324-1)
// =============================================================================

module soc_top(
    input           clk,            // 100MHz 板载时钟 (pin E3)
    input           rstn,           // 复位按钮, 低有效 (pin C12)
    input  [4:0]    btn_i,          // 5 个按键
    input  [15:0]   sw_i,           // 16 个拨码开关
    output [7:0]    disp_an_o,      // 数码管位选
    output [7:0]    disp_seg_o,     // 数码管段码
    output [15:0]   led_o           // 16 个 LED
);

// =============================================================================
// 全局复位 (低→高)
// =============================================================================
wire rst;
assign rst = ~rstn;

// =============================================================================
// Enter — 按键/开关输入 (TODO: 消抖)
// =============================================================================
wire [4:0]  BTN_OK;
wire [15:0] SW_OK;

Enter U_Enter (
    .clk        (clk),
    .BTN        (btn_i),
    .SW         (sw_i),
    .BTN_out    (BTN_OK),
    .SW_out     (SW_OK)
);

// =============================================================================
// clk_div — 时钟分频器
// =============================================================================
wire [31:0] clkdiv;
wire        Clk_CPU;

clk_div U_clk_div (
    .clk        (clk),
    .rst        (rst),
    .SW2        (SW_OK[2]),         // SW2 控制频率: 0=6.25MHz, 1=2.98Hz
    .clkdiv     (clkdiv),
    .Clk_CPU    (Clk_CPU)
);

// =============================================================================
// SCPU — 单周期 CPU (老师 .edf 黑盒)
// =============================================================================
// SCPU 中间信号
wire [31:0] PC, Addr_out, Data_out;
wire [31:0] inst_in, Data_in;
wire        mem_w;
wire [2:0]  dm_ctrl;
wire        CPU_MIO, MIO_ready;

// CPU_MIO ↔ MIO_ready 自环
assign MIO_ready = CPU_MIO;

SCPU U_SCPU (
    .clk        (Clk_CPU),
    .reset      (rst),
    .MIO_ready  (MIO_ready),
    .inst_in    (inst_in),
    .Data_in    (Data_in),
    .INT        (counter0_out),     // 计数器0溢出 → CPU中断
    .mem_w      (mem_w),
    .PC_out     (PC),
    .Addr_out   (Addr_out),
    .Data_out   (Data_out),
    .dm_ctrl    (dm_ctrl),
    .CPU_MIO    (CPU_MIO)
);

// =============================================================================
// ROM — 指令存储器 (Distributed Memory Generator IP, 1024×32-bit)
// =============================================================================
ROM U_ROM_D (
    .a          (PC[11:2]),         // 字地址 (1024 字 = 4KB)
    .spo        (inst_in)           // 指令输出 [31:0]
);

// =============================================================================
// RAM_B — 数据存储器 (Block Memory Generator IP, 1024×32-bit)
// =============================================================================
wire [31:0] douta, dina;
wire [3:0]  wea_mem;

RAM_B U_RAM_B (
    .clka       (Clk_CPU),          // 时钟
    .ena        (1'b1),             // 始终使能
    .wea        (wea_mem),          // 字节写使能 [3:0]
    .addra      (ram_addr),         // 字地址
    .dina       (dina),             // 写数据
    .douta      (douta)             // 读数据
);

// =============================================================================
// MIO_BUS — 存储器映射 IO 总线 (老师 .edf 黑盒)
// =============================================================================
wire [31:0] CPU2IO;                 // Peripheral_in → 外设数据
wire [31:0] ram_data_in;            // dm_controller.Data_write
wire [9:0]  ram_addr;               // RAM_B.addra
wire [31:0] counter_out;            // 计数器当前值
wire        counter0_out, counter1_out, counter2_out;
wire [15:0] LED_out;                // LED 状态反馈
wire        GPIOFO, GPIOEO;         // 外设写使能
wire        counter_we;
wire        data_ram_we;            // wea_mio
wire [31:0] Cpu_data4bus;           // → dm_controller.Data_read_from_dm

MIO_BUS U_MIO_BUS (
    .clk                (Clk_CPU),
    .rst                (rst),
    .BTN                (BTN_OK),
    .SW                 (SW_OK),
    .PC                 (PC),
    .mem_w              (mem_w),
    .Cpu_data2bus       (Data_out),
    .addr_bus           (Addr_out),
    .ram_data_out       (douta),
    .led_out            (LED_out),
    .counter_out        (counter_out),
    .counter0_out       (counter0_out),
    .counter1_out       (counter1_out),
    .counter2_out       (counter2_out),
    .Cpu_data4bus       (Cpu_data4bus),
    .ram_data_in        (ram_data_in),
    .ram_addr           (ram_addr),
    .data_ram_we        (data_ram_we),      // → wea_mio (中间信号)
    .GPIOf0000000_we    (GPIOFO),           // → SPIO.EN
    .GPIOe0000000_we    (GPIOEO),           // → Multi_8CH32.EN
    .counter_we         (counter_we),
    .Peripheral_in      (CPU2IO)
);

// =============================================================================
// dm_controller — 数据存储器访问控制器 (老师 .edf 黑盒)
// =============================================================================
wire [31:0] Data_write_to_dm;

dm_controller U_dm_controller (
    .mem_w                  (mem_w),
    .Addr_in                (Addr_out),
    .Data_write             (ram_data_in),      // ← MIO_BUS.ram_data_in
    .dm_ctrl                (dm_ctrl),
    .Data_read_from_dm      (Cpu_data4bus),     // ← MIO_BUS.Cpu_data4bus
    .Data_read              (Data_in),          // → SCPU.Data_in (+ 扇出)
    .Data_write_to_dm       (Data_write_to_dm), // → RAM_B.dina
    .wea_mem                (wea_mem)           // → RAM_B.wea
);

// RAM_B 数据连接
assign dina = Data_write_to_dm;

// =============================================================================
// Counter_x — 3 通道计数器
// =============================================================================
wire [1:0]  counter_ch;
wire        counter0_OUT, counter1_OUT, counter2_OUT;

Counter_x U_Counter_x (
    .clk            (Clk_CPU),
    .rst            (rst),
    .clk0           (clkdiv[25]),
    .clk1           (clkdiv[28]),
    .clk2           (clkdiv[30]),
    .counter_we     (counter_we),
    .counter_val    (CPU2IO),
    .counter_ch     (counter_ch),
    .counter0_OUT   (counter0_OUT),
    .counter1_OUT   (counter1_OUT),
    .counter2_OUT   (counter2_OUT),
    .counter_out    (counter_out)
);

// 计数器输出 → MIO_BUS
assign counter0_out = counter0_OUT;
assign counter1_out = counter1_OUT;
assign counter2_out = counter2_OUT;

// =============================================================================
// SPIO — LED 外设控制器 (老师 .edf 黑盒)
// =============================================================================
SPIO U_SPIO (
    .clk            (Clk_CPU),
    .rst            (rst),
    .EN             (GPIOFO),          // ← MIO_BUS.GPIOf0000000_we
    .P_Data         (CPU2IO),          // ← MIO_BUS.Peripheral_in
    .counter_set    (counter_ch),      // → Counter_x.counter_ch
    .LED_out        (LED_out),         // → MIO_BUS.led_out
    .led            (led_o),           // → 板子 led_o[15:0]
    .GPIOf0         ()                 // 悬空
);

// =============================================================================
// Multi_8CH32 — 8 通道显示多路选择器 (老师 .edf 黑盒)
// =============================================================================
wire [31:0] Disp_num;
wire [7:0]  point_out, LE_out;

Multi_8CH32 U_Multi_8CH32 (
    .clk            (Clk_CPU),
    .rst            (rst),
    .EN             (GPIOEO),          // ← MIO_BUS.GPIOe0000000_we
    .Switch         (SW_OK[7:5]),      // SW[7:5] 选择通道
    .point_in       ({clkdiv, clkdiv}),// [已知问题] 32→64 位宽不匹配,复制拼接
    .LES            (64'h0000_0000_0000_0000),  // 接地
    .data0          (CPU2IO),          // 外设数据
    .data1          ({2'b0, PC[31:2]}),// PC 字地址
    .data2          (inst_in),         // 当前指令
    .data3          (counter_out),     // 计数器值
    .data4          (Addr_out),        // ALU 地址
    .data5          (Data_out),        // 写数据
    .data6          (Data_in),         // Load 数据
    .data7          (PC),              // PC 完整值
    .point_out      (point_out),
    .LE_out         (LE_out),
    .Disp_num       (Disp_num)
);

// =============================================================================
// SSeg7 — 7 段数码管驱动 (老师 .edf 黑盒)
// =============================================================================
SSeg7 U_SSeg7 (
    .clk            (clkdiv[16]),      // 扫描时钟 ≈ 762Hz (100MHz/2^17)
    .rst            (rst),
    .SW0            (clkdiv[0]),       // 显示模式自动翻转
    .flash          (clkdiv[10]),      // 闪烁控制
    .Hexs           (Disp_num),        // ← Multi_8CH32.Disp_num
    .point          (point_out),
    .LES            (LE_out),
    .seg_an         (disp_an_o),       // → 板子
    .seg_sout       (disp_seg_o)       // → 板子
);

endmodule
