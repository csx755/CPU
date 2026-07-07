// dump_tb — 打印前 20 个周期的 Addr_out 和 inst_in
`timescale 1ns / 1ps

module dump_tb();

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
        $display("=== 前20周期 Addr_out(ALU结果) & inst_in(指令) ===");
        $display("周�?  PC      Addr_out    inst_in");
        $display("----------------------------------------");

        repeat(25) begin
            @(posedge clk);
            tick = tick + 1;
            $display("%2d  %h  %h  %h", tick, PC, Addr_out, inst_in);
        end

        $display("\n=== Done ===");
        $finish;
    end

endmodule
