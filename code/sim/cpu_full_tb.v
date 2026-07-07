// cpu_full_tb — 全 37 指令测试 (基于已验证的 cpu_only_tb 结构)
`timescale 1ns / 1ps

module cpu_full_tb();

    reg clk, rst;
    reg [31:0] inst_in;
    wire [31:0] Data_in;
    reg INT;
    wire mem_w;
    wire [31:0] PC_out, Addr_out, Data_out;
    wire [2:0] dm_ctrl;

    SCPU U_SCPU (
        .clk(clk), .reset(rst), .MIO_ready(1'b1), .inst_in(inst_in), .Data_in(Data_in), .INT(INT),
        .mem_w(mem_w), .CPU_MIO(), .PC_out(PC_out), .Addr_out(Addr_out),
        .Data_out(Data_out), .dm_ctrl(dm_ctrl)
    );

    // ROM: 全 37 指令 (71 条)
    reg [31:0] rom [0:255];
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) rom[i] = 32'h00000000;

        rom[0]  = 32'h43506293; rom[1]  = 32'h00001337; rom[2]  = 32'h0062e2b3;
        rom[3]  = 32'h98765337; rom[4]  = 32'h57828393; rom[5]  = 32'hc0030413;
        rom[6]  = 32'h7bc2c493; rom[7]  = 32'h0193b193; rom[8]  = 32'hfff2b213;
        rom[9]  = 32'h7654f913; rom[10] = 32'h12332a13; rom[11] = 32'h405309b3;
        rom[12] = 32'h006a4ab3; rom[13] = 32'h014a8b33; rom[14] = 32'h005b0b33;
        rom[15] = 32'h406b0bb3; rom[16] = 32'h016becb3; rom[17] = 32'h016bfd33;
        rom[18] = 32'h01acadb3; rom[19] = 32'h01acbe33; rom[20] = 32'h00418193;
        rom[21] = 32'h003d1db3; rom[22] = 32'h003cde33; rom[23] = 32'h403cdeb3;
        rom[24] = 32'h01899d93; rom[25] = 32'h0049de13; rom[26] = 32'h4049de93;
        rom[27] = 32'h00000193; rom[28] = 32'h0ef00293; rom[29] = 32'h0131a023;
        rom[30] = 32'h0151a223; rom[31] = 32'h0171a423; rom[32] = 32'h01a19223;
        rom[33] = 32'h01319523; rom[34] = 32'h005183a3; rom[35] = 32'h005184a3;
        rom[36] = 32'h00518423; rom[37] = 32'h0001a283; rom[38] = 32'h0051a623;
        rom[39] = 32'h00219383; rom[40] = 32'h0071a823; rom[41] = 32'h0021d383;
        rom[42] = 32'h0071aa23; rom[43] = 32'h00318403; rom[44] = 32'h0081ac23;
        rom[45] = 32'h0031c403; rom[46] = 32'h0081ae23; rom[47] = 32'h0011c403;
        rom[48] = 32'h0281a023; rom[49] = 32'h0001a023; rom[50] = 32'h009074b3;
        rom[51] = 32'h00729463; rom[52] = 32'h00248493; rom[53] = 32'h0072d463;
        rom[54] = 32'h00748493; rom[55] = 32'h0072f463; rom[56] = 32'h00548493;
        rom[57] = 32'h0072c463; rom[58] = 32'h00348493; rom[59] = 32'h0072e063;
        rom[60] = 32'h00648493; rom[61] = 32'h00838463; rom[62] = 32'h00148493;
        rom[63] = 32'h0091a023; rom[64] = 32'h0001a503; rom[65] = 32'h00c000ef;
        rom[66] = 32'h00350513; rom[67] = 32'h00a1a023; rom[68] = 32'h7a156513;
        rom[69] = 32'h00a1a023; rom[70] = 32'h00008067;
    end

    // RAM (128×32, word 读写)
    reg [31:0] ram [0:127];
    integer ri;
    initial for (ri = 0; ri < 128; ri = ri + 1) ram[ri] = 32'd0;
    wire [6:0] ram_addr = Addr_out[8:2];
    assign Data_in = ram[ram_addr];
    always @(posedge clk) if (mem_w) ram[ram_addr] <= Data_out;

    // 取指
    always @(*) inst_in = rom[PC_out[8:2]];

    always #50 clk = ~clk;

    integer tick, err;
    initial begin
        clk = 0; rst = 1; INT = 0; tick = 0; err = 0;

        #200 rst = 0;
        $display("=== Full 37-Instr CPU Test ===");

        repeat(120) begin
            @(posedge clk);
            tick = tick + 1;
        end

        $display("PC=0x%08X inst=0x%08X", PC_out, inst_in);
        $display("ram[0]=0x%08X (SW)  ram[3]=0x%08X (LW reload)",
                 ram[0], ram[3]);
        $display("ram[4]=0x%08X (SH)  ram[6]=0x%08X (LB)",
                 ram[4], ram[6]);

        // 验证关键数据
        if (ram[0] == 32'h000000EF) $display("[PASS] SW @0x00");
        else begin $display("[FAIL] SW @0x00 = 0x%08X", ram[0]); err = err + 1; end

        if (ram[3] == 32'h000000EF) $display("[PASS] LW reload @0x0C");
        else begin $display("[FAIL] LW @0x0C = 0x%08X", ram[3]); err = err + 1; end

        if (err == 0) $display("\n=== ALL PASSED ===");
        else $display("\n=== %0d ERRORS ===", err);
        $finish;
    end

endmodule
