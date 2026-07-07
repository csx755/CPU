// SSeg7 单元仿真 — 验证文本/图形模式
`timescale 1ns / 1ps

module SSeg7_tb();

    reg         clk, rst, SW0, flash;
    reg  [31:0] Hexs;
    reg  [7:0]  point, LES;
    wire [7:0]  seg_an, seg_sout;

    SSeg7 U_SSEG7 (
        .clk(clk), .rst(rst),
        .SW0(SW0), .flash(flash),
        .Hexs(Hexs), .point(point), .LES(LES),
        .seg_an(seg_an), .seg_sout(seg_sout)
    );

    integer i;

    initial begin
        clk   = 1'b0;
        rst   = 1'b1;
        SW0   = 1'b0;
        flash = 1'b0;
        Hexs  = 32'h12345678;
        point = 8'h00;
        LES   = 8'hFF;

        #100 rst = 1'b0;

        // 文本模式跑 1000 个时钟看 7 段输出
        #10000;

        // 切图形模式
        SW0 = 1'b1;
        #50000;

        // 闪灯测试
        flash = 1'b1;
        #5000;
        flash = 1'b0;

        #10000;
        $finish;
    end

    // 1MHz 时钟
    always #500 clk = ~clk;

    // 监控输出
    always @(negedge clk) begin
        if (seg_an == 8'b11111110) begin
            $display("t=%0t digit0: seg=%b", $time, seg_sout);
        end
    end

endmodule
