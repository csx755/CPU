//////////////////////////////////////////////////////////////////////////////////
// MIO_BUS 模块 - IO 总线控制器
// 支持: RAM, GPIO(LED), Seg7数码管, BTN/SW, PS2键盘, VRAM显存
//
// 地址映射:
//   F0000000~FFFFFFFF: GPIO (LED输出, 读LED状态)
//   E0000000~EFFFFFFF: Seg7数码管 (写) / BTN&SW (读)
//   D0000000~DFFFFFFF: PS2键盘扫描码 (只读)
//   C0000000~CFFFFFFF: VRAM显存 (读写)
//   其他: 数据RAM
//////////////////////////////////////////////////////////////////////////////////

module MIO_BUS(
    input clk,
    input rst,
    input [4:0] BTN,           // 按钮
    input [15:0] SW,           // 开关
    input mem_w,               // 写内存
    input [31:0] Cpu_data2bus, // CPU 写出数据
    input [31:0] addr_bus,     // 地址总线
    input [31:0] ram_data_out, // RAM 输出数据
    input [15:0] led_out,
    input [31:0] counter_out,
    input counter0_out,
    input counter1_out,
    input counter2_out,
    input [31:0] PC,
    
    // PS2 键盘接口
    input [7:0] ps2_key,       // PS2 键盘扫描码
    input ps2_ready,           // PS2 有新数据
    
    // VRAM 接口
    input [15:0] vram_dout,    // VRAM 读出数据
    output reg vram_we,        // VRAM 写使能
    output reg [12:0] vram_addr, // VRAM 地址
    output reg [15:0] vram_din,  // VRAM 写入数据
    
    output reg [31:0] Cpu_data4bus,  // 送往 CPU 的数据
    output reg [31:0] ram_data_in,   // 写入 RAM 的数据
    output reg [9:0] ram_addr,       // RAM 地址
    output reg data_ram_we,
    output reg GPIOf0000000_we,
    output reg GPIOe0000000_we,
    output reg counter_we,
    output reg [31:0] Peripheral_in
);

    always @(*) begin
        Cpu_data4bus = 0;
        ram_data_in = 0;
        ram_addr = 0;
        data_ram_we = 0;
        GPIOf0000000_we = 0;
        GPIOe0000000_we = 0;
        counter_we = 0;
        Peripheral_in = 0;
        vram_we = 0;
        vram_addr = 0;
        vram_din = 0;
        
        case (addr_bus[31:28])
            4'b1111: begin // GPIO Address F0000000~FFFFFFFF
                Cpu_data4bus = {14'b00000000000000, led_out, 2'b00};
                data_ram_we = 0;
                GPIOf0000000_we = mem_w;
                Peripheral_in = Cpu_data2bus;
            end
            
            4'b1110: begin // Seg7 E0000000~EFFFFFFF // BTN & SW
                GPIOe0000000_we = mem_w;
                Peripheral_in = Cpu_data2bus;
                data_ram_we = mem_w;
                Cpu_data4bus = {11'b00000000000, BTN, SW};
            end
            
            4'b1101: begin // PS2 键盘 D0000000~DFFFFFFF (只读)
                // 读取 PS2 键盘扫描码
                // bit[7:0] = 当前扫描码
                // bit[8]   = 有新数据标志
                Cpu_data4bus = {23'b0, ps2_ready, ps2_key};
                data_ram_we = 0;
            end
            
            4'b1100: begin // VRAM 显存 C0000000~CFFFFFFF (读写)
                // 地址: addr_bus[12:0] = VRAM 地址 (0~4095)
                // 数据: Cpu_data2bus[15:0] = 写入数据
                vram_addr = addr_bus[12:0];
                vram_din = Cpu_data2bus[15:0];
                vram_we = mem_w;
                Cpu_data4bus = {16'b0, vram_dout};
                data_ram_we = 0;
            end
            
            default: begin // 数据RAM
                Cpu_data4bus = ram_data_out;
                ram_data_in = Cpu_data2bus;
                ram_addr = addr_bus[11:2];
                data_ram_we = mem_w;
            end
        endcase
    end

endmodule
