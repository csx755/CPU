// soc_slim_tb — 精简 SoC 仿真, 不含 SSeg7/Multi_8CH32/SPIO/Counter_x
// 仅验证 CPU + MIO_BUS + dm_ctrl + RAM_B/ROM 核心数据路径
`timescale 1ns / 1ps

module soc_slim_tb();

    reg clk, rstn;
    reg [4:0] btn_i;
    reg [15:0] sw_i;

    // ── 全局复位 ──
    wire rst = ~rstn;

    // ── Enter (简化: 直连) ──
    wire [4:0] BTN_OK = btn_i;
    wire [15:0] SW_OK = sw_i;

    // ── Clk_CPU: 仿真用, 直接从 clk 分频 (绕过 clk_div 32-bit 计数器加速仿真) ──
    reg Clk_CPU;
    reg [2:0] cpu_div;
    always @(posedge clk or posedge rst) begin
        if (rst)        {Clk_CPU, cpu_div} <= 4'b0;
        else            {Clk_CPU, cpu_div} <= {1'b0, cpu_div} + 1'b1;
    end

    // ── SCPU ──
    wire [31:0] PC, Addr_out, Data_out, inst_in, Data_in;
    wire mem_w;
    wire [2:0] dm_ctrl_s;
    SCPU U_SCPU (.clk(Clk_CPU), .reset(rst), .MIO_ready(1'b1), .inst_in(inst_in), .Data_in(Data_in),
                 .INT(1'b0), .mem_w(mem_w), .CPU_MIO(), .PC_out(PC), .Addr_out(Addr_out),
                 .Data_out(Data_out), .dm_ctrl(dm_ctrl_s));

    // ── ROM (行为模型) ──
    ROM U_ROM (.a(PC[11:2]), .spo(inst_in));

    // ── MIO_BUS ──
    wire [31:0] CPU2IO, ram_data_in, Cpu_data4bus;
    wire [9:0] ram_addr;
    wire GPIOFO, GPIOEO, counter_we, data_ram_we;
    MIO_BUS U_MIO_BUS (
        .clk(clk), .rst(rst), .BTN(BTN_OK), .SW(SW_OK), .PC(PC),
        .mem_w(mem_w), .Cpu_data2bus(Data_out), .addr_bus(Addr_out),
        .ram_data_out(douta), .led_out(16'd0), .counter_out(32'd0),
        .counter0_out(1'b0), .counter1_out(1'b0), .counter2_out(1'b0),
        .Cpu_data4bus(Cpu_data4bus), .ram_data_in(ram_data_in),
        .ram_addr(ram_addr), .data_ram_we(data_ram_we),
        .GPIOf0000000_we(GPIOFO), .GPIOe0000000_we(GPIOEO),
        .counter_we(counter_we), .Peripheral_in(CPU2IO)
    );

    // ── dm_ctrl ──
    wire [31:0] Data_write_to_dm;
    wire [3:0] wea_mem;
    dm_ctrl U_dm_ctrl (
        .mem_w(mem_w), .Addr_in(Addr_out), .Data_write(ram_data_in),
        .dm_ctrl(dm_ctrl_s), .Data_read_from_dm(Cpu_data4bus),
        .Data_read(Data_in), .Data_write_to_dm(Data_write_to_dm), .wea_mem(wea_mem)
    );

    // ── RAM_B (行为模型) ──
    wire [31:0] douta;
    RAM_B U_RAM_B (.clka(~clk), .wea(wea_mem), .addra(ram_addr),
                   .dina(Data_write_to_dm), .douta(douta));

    // ================================================================
    // Test
    // ================================================================
    initial clk = 1'b0;
    always #50 clk = ~clk;   // 10MHz (仿真加速)

    function [31:0] read_ram(input [9:0] addr);
        read_ram = U_RAM_B.mem[addr];
    endfunction

    integer tick, prev_tick_pc;
    initial begin
        clk = 0; rstn = 0; btn_i = 0; sw_i = 0; tick = 0;

        #200 rstn = 1'b1;
        sw_i[2] = 1'b0;
        #200;
        prev_tick_pc = 0;

        $display("=== Slim SoC Simulation ===");

        repeat(100) begin
            @(posedge clk);
            tick = tick + 1;
        end
        $display("  100 clk cycles, PC=0x%08X inst=0x%08X", PC, inst_in);

        repeat(100) begin
            @(posedge clk);
            tick = tick + 1;
        end
        $display("  200 clk cycles, PC=0x%08X inst=0x%08X", PC, inst_in);

        repeat(200) begin
            @(posedge clk);
            tick = tick + 1;
        end
        $display("  400 clk cycles, PC=0x%08X inst=0x%08X", PC, inst_in);
        $display("  RAM[0]=0x%08X RAM[1]=0x%08X RAM[3]=0x%08X",
                 read_ram(10'd0), read_ram(10'd1), read_ram(10'd3));

        repeat(400) begin
            @(posedge clk);
            tick = tick + 1;
        end

        $display("\n=== Final State ===");
        $display("PC=0x%08X inst=0x%08X", PC, inst_in);
        $display("RAM[0]=0x%08X (expect 0xEF)", read_ram(10'd0));
        $display("RAM[1]=0x%08X", read_ram(10'd1));
        $display("RAM[3]=0x%08X (LW reload)", read_ram(10'd3));

        if (read_ram(10'd0) == 32'h000000EF)
            $display("[PASS]");
        else
            $display("[FAIL]");

        $finish;
    end

endmodule
