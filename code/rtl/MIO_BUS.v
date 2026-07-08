// MIO_BUS — 存储器映射 IO 总线 (老师方案: addr_bus[31:28] 粗粒度解码)
//
// 地址范围:
//   0xFxxxxxxx → GPIO 外设 (SPIO + Counter + SW + BTN)
//   0xExxxxxxxx → Seg7 显示外设 (Multi_8CH32 + BTN/SW 读回)
//   其他 → RAM
//
// 写使能: 粗粒度范围解码 (老师方案)
//   GPIOf0000000_we = 所有 0xF 范围写 (SPIO 使能)
//   GPIOe0000000_we = 所有 0xE 范围写 (Multi_8CH32 使能)
//   counter_we      = 0xF 范围 + 子地址 0x08 (counter 写使能)
//
// 读回格式: 老师原版格式
//   0xF 默认 → {14'b0, led_out, 2'b00}
//   0xE      → {11'b0, BTN, SW}
//
// 子地址 (addr_bus[7:0] 在 0xF 范围内):
//   0x08 → Counter, 0x10 → SW, 0x14 → BTN
//
// 注意: 写 0xF0000008 (counter) 同时置位 GPIOf0000000_we (SPIO),
//       程序需保证 P_Data 对 SPIO 无害。

module MIO_BUS (
    input  wire         clk, rst,
    input  wire [31:0]  addr_bus, Cpu_data2bus, ram_data_out, PC,
    input  wire [15:0]  SW,
    input  wire [4:0]   BTN,
    input  wire         mem_w,
    input  wire [15:0]  led_out,
    input  wire [31:0]  counter_out,
    input  wire         counter0_out, counter1_out, counter2_out,
    output wire [31:0]  Cpu_data4bus, ram_data_in, Peripheral_in,
    output wire [9:0]   ram_addr,
    output wire         data_ram_we, GPIOf0000000_we, GPIOe0000000_we, counter_we
);

    //-------------- 地址范围解码 (粗粒度) --------------
    wire [3:0] addr_range = addr_bus[31:28];
    wire       is_GPIO    = (addr_range == 4'b1111);  // 0xFxxxxxxx
    wire       is_DISP    = (addr_range == 4'b1110);  // 0xExxxxxxxx

    //-------------- 写使能 (粗粒度 + 子地址) --------------
    assign GPIOf0000000_we = is_GPIO & mem_w;                     // 所有 0xF 写→SPIO
    assign GPIOe0000000_we = is_DISP & mem_w;                     // 所有 0xE 写→Multi8CH32
    assign data_ram_we     = (~is_GPIO & ~is_DISP) & mem_w;       // 非外设范围→RAM
    assign counter_we      = is_GPIO & (addr_bus[7:0] == 8'h08) & mem_w;  // 0xF 内子地址

    //-------------- 数据通路 (组合逻辑) --------------
    assign ram_data_in   = Cpu_data2bus;
    assign ram_addr      = addr_bus[11:2];
    assign Peripheral_in = Cpu_data2bus;

    //-------------- 读数据回送 (组合逻辑) --------------
    wire [31:0] counter_data = {counter_out[31:3], counter2_out, counter1_out, counter0_out};
    reg  [31:0] Cpu_data4bus_r;

    always @(*) begin
        case (addr_range)
            4'b1111: begin  // 0xF: GPIO 外设
                if      (addr_bus[7:0] == 8'h10)    Cpu_data4bus_r = {16'b0, SW};
                else if (addr_bus[7:0] == 8'h14)    Cpu_data4bus_r = {27'b0, BTN};
                else if (addr_bus[7:0] == 8'h08)    Cpu_data4bus_r = counter_data;
                else                                Cpu_data4bus_r = {14'b0, led_out, 2'b00};  // 老师格式
            end
            4'b1110: begin  // 0xE: Seg7 显示 (BTN+SW 合并回读)
                Cpu_data4bus_r = {11'b0, BTN, SW};  // 老师合并格式
            end
            default: begin  // RAM
                Cpu_data4bus_r = ram_data_out;
            end
        endcase
    end

    assign Cpu_data4bus = Cpu_data4bus_r;

endmodule
