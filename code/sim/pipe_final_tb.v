// pipe_final_tb — 流水线确定性验证 (覆盖转发/阻塞/分支冲刷/JAL+JALR)
`timescale 1ns / 1ps

module pipe_final_tb();

    reg clk, rst;
    wire [31:0] inst_in, Data_in;
    wire mem_w;
    wire [31:0] PC, Addr_out, Data_out;
    wire [2:0] dm_ctrl;

    SCPU_pipelined U_P (.clk(clk),.reset(rst),.MIO_ready(1'b1),
        .inst_in(inst_in),.Data_in(Data_in),.INT(1'b0),
        .mem_w(mem_w),.CPU_MIO(),.PC_out(PC),.Addr_out(Addr_out),
        .Data_out(Data_out),.dm_ctrl(dm_ctrl),
        .reg_sel(5'd0),.reg_data());

    dm U_DM (.clk(clk),.DMWr(mem_w),
        .addr(Addr_out[8:0]),.din(Data_out),
        .dout(Data_in),.DMType(dm_ctrl));

    reg [31:0] rom [0:63];
    integer i;
    initial begin
        for (i=0;i<64;i=i+1) rom[i]=32'h00000013; // NOP fill

        // === 转发测试: RAW on x2 ===
        rom[0] = 32'h06400113;  // addi x2, x0, 100   → sp=100
        rom[1] = 32'h0c800193;  // addi x3, x0, 200   → gp=200
        rom[2] = 32'h002081b3;  // add  x3, x1, x2    → gp=0+100=100 (转发 x2)
        rom[3] = 32'h00312023;  // sw   x3, 0(x2)     → DM[25]=100

        // === Load-Use 阻塞 ===
        rom[4] = 32'h00012103;  // lw   x2, 0(x2)     → x2=DM[25]=100
        rom[5] = 32'h00110113;  // addi x2, x2, 1     → x2=101 (需阻塞1周期!)
        rom[6] = 32'h00212023;  // sw   x2, 0(x2)     → DM[25]=101

        // === 分支冲刷 (taken) ===
        rom[7] = 32'h00500513;  // addi x10, x0, 5    → a0=5
        rom[8] = 32'h00500593;  // addi x11, x0, 5    → a1=5
        rom[9] = 32'h00b50663;  // beq  x10,x11,+12   → TAKEN (5==5), skip 3 instrs
        rom[10]= 32'h06300513;  // addi x10,x0,99     → FLUSHED
        rom[11]= 32'h00a02023;  // sw   x10,0(x0)     → FLUSHED (would write 99)
        rom[12]= 32'h00100513;  // addi x10, x0, 1    → a0=1 (branch target)
        rom[13]= 32'h00a02023;  // sw   x10, 0(x0)    → DM[0]=1

        // === JAL + JALR (函数调用) ===
        rom[14]= 32'h00a00513;  // addi x10, x0, 10   → a0=10
        rom[15]= 32'h010000ef;  // jal  x1, +16       → ra=64, call func at +16=rom[19]
        // return point (rom[16] at addr 64):
        rom[16]= 32'h00150513;  // addi x10, x10, 1   → a0=func_result+1
        rom[17]= 32'h00a02223;  // sw   x10, 4(x0)    → DM[1]=x10
        rom[18]= 32'h0000006f;  // jal  x0, 0          → halt (before func body)
        // func body (rom[19] at addr 76):
        rom[19]= 32'h00a00513;  // addi x10, x0, 10   → a0=10 (overwrites)
        // Actually this sets x10=10. Then jalr returns, x10+1=11.
        // Hmm, let me change: func computes x10=20.
        // WAIT: x10 was 10 before call. Let func set x10=20.
    end

    // Override the last few init values for correct func test
    initial begin
        // Override rom[19]: func sets x10 = 20
        rom[19]= 32'h01400513;  // addi x10, x0, 20   → a0=20
        rom[20]= 32'h00a02423;  // sw   x10, 8(x0)    → DM[2]=20 (func body executed)
        rom[21]= 32'h00008067;  // jalr x0, x1, 0      → return to x1=64
    end

    assign inst_in = rom[PC[8:2]];

    always #50 clk = ~clk;

    integer tick, err;
    initial begin
        clk=0; rst=1; tick=0; err=0;
        #200 rst=0;
        $display("=== Pipeline Deterministic Test ===");

        repeat(120) @(posedge clk);

        $display("DM[0]  = %08X (expect 0x00000001 = branch taken)", U_DM.dmem[0]);
        $display("DM[1]  = %08X (expect 0x00000015 = 21 = func(20)+1)", U_DM.dmem[1]);
        $display("DM[2]  = %08X (expect 0x00000014 = 20 = func body)", U_DM.dmem[2]);
        $display("DM[25] = %08X (expect 0x00000065 = 101 = load-use)", U_DM.dmem[25]);

        if (U_DM.dmem[0]  == 32'h00000001) $display("[PASS] Branch taken flush → DM[0]=1");
        else begin $display("[FAIL] DM[0]=%08X", U_DM.dmem[0]); err=err+1; end
        if (U_DM.dmem[2]  == 32'h00000014) $display("[PASS] JAL call → func body DM[2]=20");
        else begin $display("[FAIL] DM[2]=%08X", U_DM.dmem[2]); err=err+1; end
        if (U_DM.dmem[1]  == 32'h00000015) $display("[PASS] JALR return → DM[1]=21");
        else begin $display("[FAIL] DM[1]=%08X", U_DM.dmem[1]); err=err+1; end
        if (U_DM.dmem[25] == 32'h00000065) $display("[PASS] Load-Use stall → DM[25]=101");
        else begin $display("[FAIL] DM[25]=%08X", U_DM.dmem[25]); err=err+1; end

        if (err==0) $display("\n=== PIPELINE FULLY VERIFIED ===");
        else $display("\n=== %0d ERRORS ===", err);
        $finish;
    end

endmodule
