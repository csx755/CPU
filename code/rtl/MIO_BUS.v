module MIO_BUS (
    input  wire         clk, rst,   // clk/rst 暂未使用 (全组合逻辑)

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

    //-------------- 地址解码 --------------
    wire is_RAM        = (addr_bus[31:12] == 20'h0) && (addr_bus[11:0] < 12'h1000); // 0x00000 ~ 0x00FFF
    wire is_SPIO       = (addr_bus == 32'hFFFF_F000);
    wire is_Multi8CH32 = (addr_bus == 32'hFFFF_F004);
    wire is_Counter    = (addr_bus == 32'hFFFF_F008);
    wire is_SW         = (addr_bus == 32'hFFFF_F010);
    wire is_BTN        = (addr_bus == 32'hFFFF_F014);

    //-------------- RAM 接口（组合逻辑） --------------
    assign ram_addr    = addr_bus[11:2];
    assign data_ram_we = is_RAM && mem_w;
    assign ram_data_in = Cpu_data2bus;

    //-------------- 外设写接口 --------------
    assign Peripheral_in    = Cpu_data2bus;
    assign GPIOf0000000_we  = is_SPIO       && mem_w;
    assign GPIOe0000000_we  = is_Multi8CH32 && mem_w;
    assign counter_we       = is_Counter    && mem_w;

    //-------------- CPU 读数据多路选择（组合逻辑） --------------
    // 读 Counter 时，返回 {counter_out[31:3], counter2_out, counter1_out, counter0_out}
    wire [31:0] counter_data = {counter_out[31:3], counter2_out, counter1_out, counter0_out};

    assign Cpu_data4bus = is_RAM     ? ram_data_out             :
                          is_SPIO    ? {16'b0, led_out}         :
                          is_Counter ? counter_data             :
                          is_SW      ? {16'b0, SW}              :
                          is_BTN     ? {27'b0, BTN}             :
                                        32'b0;                  // 默认0

endmodule