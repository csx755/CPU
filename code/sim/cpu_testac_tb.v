// cpu_testac_tb — testac.coe CPU 仿真
`timescale 1ns / 1ps

module cpu_testac_tb();

    reg clk, rst;
    wire [31:0] PC, Addr_out, Data_out, inst_in, Data_in;
    wire mem_w;
    wire [2:0] dm_ctrl;

    SCPU U_SCPU (
        .clk(clk), .reset(rst), .MIO_ready(1'b1), .inst_in(inst_in), .Data_in(Data_in),
        .INT(1'b0), .mem_w(mem_w), .CPU_MIO(), .PC_out(PC), .Addr_out(Addr_out),
        .Data_out(Data_out), .dm_ctrl(dm_ctrl),
        .reg_sel(5'd0), .reg_data()
    );

    ROM U_ROM (.a(PC[11:2]), .spo(inst_in));

    // 数据存储器 — 使用 dm.v 支持 byte/halfword/word 读写 (SB/SH/LB/LH/LBU/LHU)
    dm U_DM (
        .clk(clk),
        .DMWr(mem_w),
        .addr(Addr_out[8:0]),   // 字节地址 (512B 范围)
        .din(Data_out),
        .dout(Data_in),
        .DMType(dm_ctrl)
    );

    always #50 clk = ~clk;  // 10MHz

    integer tick;
    initial begin
        clk = 0; rst = 1; tick = 0;

        #200 rst = 0;
        $display("=== testac CPU Test ===");

        repeat(300) begin
            @(posedge clk);
            tick = tick + 1;
            if (mem_w)
                $display("STORE T=%0d PC=%h addr=%h data=%h", tick, PC, Addr_out, Data_out);
        end

        $display("\n=== Done T=%0d PC=%h ===", tick, PC);
        $display("DM[0]=%h DM[1]=%h DM[2]=%h", U_DM.dmem[0], U_DM.dmem[1], U_DM.dmem[2]);
        $finish;
    end

endmodule
