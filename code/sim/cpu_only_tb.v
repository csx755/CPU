// cpu_only_tb — 单独测试 SCPU (排除外设干扰)
`timescale 1ns / 1ps

module cpu_only_tb();

    reg clk, rst;
    reg [31:0] inst_in;
    wire [31:0] Data_in;
    reg INT;
    wire mem_w, PC_out_zero;
    wire [31:0] PC_out, Addr_out, Data_out;
    wire [2:0] dm_ctrl;
    wire [31:0] PC;

    assign PC = PC_out;

    SCPU U_SCPU (
        .clk(clk), .reset(rst), .MIO_ready(1'b1), .inst_in(inst_in), .Data_in(Data_in), .INT(INT),
        .mem_w(mem_w), .CPU_MIO(), .PC_out(PC_out), .Addr_out(Addr_out),
        .Data_out(Data_out), .dm_ctrl(dm_ctrl)
    );

    // 简易指令 ROM
    reg [31:0] rom [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) rom[i] = 32'h00000000;
        // 简单测试: ADDI x5, x0, 0xEF; 然后 SW x5, 0(x3)
        // 先用 gp(x3)=0, 先 lui/addi 建立 gp
        rom[0] = 32'h00000193;  // addi x3, x0, 0     → gp=0
        rom[1] = 32'h0ef00293;  // addi x5, x0, 239   → t0=0xEF
        rom[2] = 32'h0051a023;  // sw   x5, 0(x3)     → mem[0]=t0
        rom[3] = 32'h00002283;  // lw   x5, 0(x0)     → t0=mem[0]
        rom[4] = 32'h0000006f;  // jal  x0, 0         → infinite loop
    end

    // 简易数据 RAM (128×32)
    reg [31:0] ram [0:127];
    wire [6:0] ram_word_addr = Addr_out[8:2];

    // 组合读
    wire [31:0] ram_dout;
    assign ram_dout = ram[ram_word_addr];

    // 同步写 (带字节使能, 简化版: 只支持 word)
    always @(posedge clk) begin
        if (mem_w) ram[ram_word_addr] <= Data_out;
    end

    // Load 数据选择
    assign Data_in = ram_dout;

    // 取指
    always @(*) inst_in = rom[PC[8:2]];

    always #50 clk = ~clk;  // 10MHz

    integer tick;
    initial begin
        clk = 0; rst = 1; INT = 0; tick = 0;

        #200 rst = 0;
        $display("=== CPU-only test ===");

        repeat(50) begin
            @(posedge clk);
            tick = tick + 1;
            if (mem_w)
                $display("[%0d] STORE PC=0x%X Addr=0x%X Data=0x%X",
                         tick, PC_out, Addr_out, Data_out);
        end

        $display("ram[0] = 0x%08X (expect 0xEF)", ram[0]);
        $display("ram[1] = 0x%08X (expect 0xEF from LW)", ram[1]);
        $finish;
    end

endmodule
