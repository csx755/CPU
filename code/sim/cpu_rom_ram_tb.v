// cpu_rom_ram_tb — SCPU + ROM + RAM 直连 (不含 MIO_BUS/dm_ctrl)
// 验证 37 指令数据路径, CPU 以固定频率运行
`timescale 1ns / 1ps

module cpu_rom_ram_tb();

    reg clk, rst;
    wire [31:0] PC, Addr_out, Data_out, inst_in, Data_in;
    wire mem_w;
    wire [2:0] dm_ctrl;

    SCPU U_SCPU (.clk(clk), .reset(rst), .MIO_ready(1'b1), .inst_in(inst_in), .Data_in(Data_in),
                 .INT(1'b0), .mem_w(mem_w), .CPU_MIO(), .PC_out(PC), .Addr_out(Addr_out),
                 .Data_out(Data_out), .dm_ctrl(dm_ctrl));

    // ROM (行为模型)
    ROM U_ROM (.a(PC[11:2]), .spo(inst_in));

    // 简易 RAM (128×32, word 读写)
    reg [31:0] ram [0:127];
    integer ram_init_i;
    initial for (ram_init_i = 0; ram_init_i < 128; ram_init_i = ram_init_i + 1)
        ram[ram_init_i] = 32'd0;
    wire [6:0] ram_addr = Addr_out[8:2];
    wire [31:0] ram_dout;
    assign ram_dout = ram[ram_addr];

    // Load: 只支持 word (简化)
    assign Data_in = ram_dout;

    // Store: 同步写
    always @(posedge clk) if (mem_w) ram[ram_addr] <= Data_out;

    always #50 clk = ~clk;  // 10MHz

    function [31:0] read_ram(input [6:0] a);
        read_ram = ram[a];
    endfunction

    integer tick;
    initial begin
        clk = 0; rst = 1; tick = 0;

        #200 rst = 0;
        $display("=== CPU + ROM + RAM (37 instr) ===");

        repeat(10) begin @(posedge clk); tick = tick + 1; end
        $display("  10: PC=0x%08X", PC);
        repeat(10) begin @(posedge clk); tick = tick + 1; end
        $display("  20: PC=0x%08X", PC);
        repeat(10) begin @(posedge clk); tick = tick + 1; end
        $display("  30: PC=0x%08X", PC);
        repeat(10) begin @(posedge clk); tick = tick + 1; end
        $display("  40: PC=0x%08X mem_w=%b Data_out=0x%08X", PC, mem_w, Data_out);

        $display("\n=== Final State ===");
        $display("PC=0x%08X inst=0x%08X", PC, inst_in);
        $display("ram[0]=0x%08X (expect 0xEF)", read_ram(7'd0));
        $display("ram[1]=0x%08X", read_ram(7'd1));
        $display("ram[3]=0x%08X", read_ram(7'd3));

        if (read_ram(7'd0) == 32'h000000EF) $display("[PASS]");
        else $display("[FAIL]");

        $finish;
    end

endmodule
